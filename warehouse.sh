#!/bin/bash

PATH_TO_LEDGER_DIR="/home/sol/ledger"
PATH_TO_LEDGER_SNAPSHOT_DIR="/home/sol/ledger/snapshots"
PATH_TO_IDENTITY_KEYPAIR="/home/sol/validator-keypair.json"
PATH_TO_LOGS="/home/sol/log/validator.log"

ledger_dir=$PATH_TO_LEDGER_DIR
ledger_snapshots_dir=$PATH_TO_LEDGER_SNAPSHOT_DIR

# |touch /home/sol/solana-bigtable/warehouse-exit-signal| will trigger a clean shutdown
exit_signal_file=/home/sol/solana-bigtable/warehouse-exit-signal

# |touch /home/sol/solana-bigtable/warehouse-no-archive| to prevent the node from archiving even when it's time
no_archive_signal_file=/home/sol/solana-bigtable/warehouse-no-archive

set -x
set -e
shopt -s nullglob

here=$(dirname "$0")

panic() {
  echo "error: $*" >&2
  exit 1
}

#shellcheck source=/dev/null
source /home/sol/solana-bigtable/service-env.sh

#shellcheck source=/dev/null
source /home/sol/solana-bigtable/service-env-warehouse.sh

# Delete any zero-length snapshots that can cause validator startup to fail
find "$ledger_snapshots_dir" -name 'snapshot-*' -size 0 -print -exec rm {} \; || true

#shellcheck source=./configure-metrics.sh
source "$here"/configure-metrics.sh

if [[ -z $ENTRYPOINT ]]; then
  echo ENTRYPOINT environment variable not defined
  exit 1
fi

if [[ -z $EXPECTED_GENESIS_HASH ]]; then
  echo EXPECTED_GENESIS_HASH environment variable not defined
  exit 1
fi

# if [[ -z $EXPECTED_SHRED_VERSION ]]; then
#   echo EXPECTED_SHRED_VERSION environment variable not defined
#   exit 1
# fi

if [[ -z $STORAGE_BUCKET ]]; then
  echo STORAGE_BUCKET environment variable not defined
  exit 1
fi

if [[ -z $RPC_URL ]]; then
  echo RPC_URL environment variable not defined
  exit 1
fi

# MINIMUM_MINUTES_BETWEEN_ARCHIVE=720 is useful to define in devnet's service-env.sh
# since the devnet epochs are so short
if [[ -z $MINIMUM_MINUTES_BETWEEN_ARCHIVE ]]; then
  MINIMUM_MINUTES_BETWEEN_ARCHIVE=2
fi

if [[ -f $exit_signal_file ]]; then
  echo $exit_signal_file present, refusing to start
  exit 0
fi

identity_keypair=$PATH_TO_IDENTITY_KEYPAIR
identity_pubkey=$(solana-keygen pubkey "$identity_keypair")

datapoint_error() {
  declare event=$1
  declare args=$2

  declare comma=
  if [[ -n $args ]]; then
    comma=,
  fi

  $metricsWriteDatapoint "infra-warehouse-node,host_id=$identity_pubkey error=1,event=\"$event\"$comma$args"
}

datapoint() {
  declare event=$1
  declare args=$2

  declare comma=
  if [[ -n $args ]]; then
    comma=,
  fi

  $metricsWriteDatapoint "infra-warehouse-node,host_id=$identity_pubkey error=0,event=\"$event\"$comma$args"
}


args=(
  --dynamic-port-range 8002-8024
  --entrypoint "$ENTRYPOINT"
  --expected-genesis-hash "$EXPECTED_GENESIS_HASH"
  --gossip-port 8001
  --rpc-port 8899
  --rpc-bind-address 0.0.0.0
  --full-rpc-api
  --identity "$identity_keypair"
  --ledger "$ledger_dir"
  --log $PATH_TO_LOGS
  --no-voting
  --skip-poh-verify
  --enable-rpc-transaction-history
  --no-port-check
  --no-untrusted-rpc
  --wal-recovery-mode skip_any_corrupted_record 
  --init-complete-file /home/sol/.init-complete
  --snapshots "$ledger_snapshots_dir"
  --limit-ledger-size 80000000
  
  
  
)

if ! [[ $(solana --version) =~ \ 1\.10\.[0-9]+ ]]; then
  if [[ -n $ENABLE_BPF_JIT ]]; then
    args+=(--bpf-jit)
  fi
  if [[ -n $DISABLE_ACCOUNTSDB_CACHE ]]; then
    args+=(--no-accounts-db-caching)
  fi
  if [[ -n $ENABLE_CPI_AND_LOG_STORAGE ]]; then
    args+=(--enable-cpi-and-log-storage)
  fi
  for entrypoint in "${ENTRYPOINTS[@]}"; do
    args+=(--entrypoint "$entrypoint")
  done
fi

for tv in "${TRUSTED_VALIDATOR_PUBKEYS[@]}"; do
  [[ $tv = "$identity_pubkey" ]] || args+=(--trusted-validator "$tv")
done

 #if [[ -d "$ledger_dir" ]]; thens
  #args+=(--no-genesis-fetch)
#fi

 if [[ -d "$ledger_snapshots_dir" ]]; then
   args+=(--no-snapshot-fetch)
fi

if [[ -w /home/sol/accounts/ ]]; then
  args+=(--accounts /home/sol/accounts)
fi

if [[ -n $GOOGLE_APPLICATION_CREDENTIALS ]]; then
  args+=(--enable-bigtable-ledger-upload)
fi

if [[ -n $EXPECTED_SHRED_VERSION ]]; then
  args+=(--expected-shred-version "$EXPECTED_SHRED_VERSION")
fi

if [[ -n $SNAPSHOT_COMPRESSION ]]; then
  args+=(--snapshot-compression "$SNAPSHOT_COMPRESSION")
fi

for hard_fork in "${HARD_FORKS[@]}"; do
  args+=(--hard-fork "$hard_fork")
done

if [[ -n "$EXPECTED_BANK_HASH" ]]; then
  args+=(--expected-bank-hash "$EXPECTED_BANK_HASH")
  if [[ -n "$WAIT_FOR_SUPERMAJORITY" ]]; then
    args+=(--wait-for-supermajority "$WAIT_FOR_SUPERMAJORITY")
  fi
elif [[ -n "$WAIT_FOR_SUPERMAJORITY" ]]; then
  echo "WAIT_FOR_SUPERMAJORITY requires EXPECTED_BANK_HASH be specified as well!" 1>&2
  exit 1
fi

pid=
kill_node() {
  # Note: do not echo anything from this function to ensure $pid is actually
  # killed when stdout/stderr are redirected
  set +ex
  if [[ -n $pid ]]; then
    declare _pid=$pid
    pid=
    kill "$_pid" || true
    wait "$_pid" || true
  fi
}
kill_node_and_exit() {
  kill_node
  exit
}
trap 'kill_node_and_exit' INT TERM ERR

get_latest_snapshot() {
  declare dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    
    #panic "get_latest_snapshot: not a directory: $dir"
  fi

  find "$dir" -name snapshot-\*.tar\* | sort -ns | tail -n1
}

get_snapshot_slot() {
  declare snapshot="$1"

  snapshot="$(basename "$snapshot")"
  snapshot="${snapshot#snapshot-}"
  snapshot="${snapshot%-*}"
  echo "$snapshot"
}

archive_snapshot_slot=invalid
last_archive_epoch=invalid
minutes_since_last_ledger_archive=invalid

prepare_archive_location() {
  # If a current archive directory does not exist, create it and save the latest
  # snapshot in it (if not at genesis)
  if [[ ! -d /home/sol/ledger/ledger-archive ]]; then
    mkdir -p /home/sol/ledger/ledger-archive
    declare archive_snapshot
    archive_snapshot=$(get_latest_snapshot "$ledger_snapshots_dir")
    if [[ -n "$archive_snapshot" ]]; then
      ln "$archive_snapshot"/home/sol/ledger/ledger-archive
    fi
  fi

  # Determine the current archive slot
  declare archive_snapshot
  archive_snapshot=$(get_latest_snapshot /home/sol/ledger/ledger-archive)
  if [[ -n "$archive_snapshot" ]]; then
    archive_snapshot_slot=$(get_snapshot_slot "$archive_snapshot")
  else
    archive_snapshot_slot=0
  fi

  minutes_since_last_ledger_archive=0
}

prepare_archive_location

while true; do
  rm -f /home/sol/.init-complete

  solana-validator "${args[@]}" &
  pid=$!
  datapoint validator-started

  echo "pid: $pid"

  caught_up=false
  initialized=false
  SECONDS=
  while true; do
    if [[ -z $pid ]] || ! kill -0 "$pid"; then
      datapoint_error unexpected-validator-exit

      # cool down for a minute before restarting to avoid a tight restart loop
      # if there's a failure very early in the validator boot
      sleep 60

      break  # validator exited unexpectedly, restart it
    fi

    if ! $initialized; then
      if [[ ! -f /home/sol/.init-complete ]]; then
        echo "waiting for node to initialize..."
        if [[ $SECONDS -gt 600 ]]; then
          datapoint_error validator-not-initialized
          SECONDS=
        fi
        sleep 10
        continue
      fi
      echo Validator has initialized
      datapoint validator-initialized
      initialized=true
    fi

    if ! $caught_up; then
      if ! timeout 15m solana catchup --url "$RPC_URL" "$identity_pubkey" http://127.0.0.1:8899; then
        echo "catchup failed..."
        if [[ $SECONDS -gt 600 ]]; then
          datapoint_error validator-not-caught-up
          SECONDS=
        fi
        sleep 60
        continue
      fi
      echo Validator has caught up
      datapoint validator-caught-up
      caught_up=true
    fi

    last_archive_epoch=$(cat /home/sol/ledger/ledger-archive/epoch || true)
    if [[ -z "$last_archive_epoch" ]]; then
      if ! solana --url "$RPC_URL" epoch > /home/sol/ledger/ledger-archive/epoch; then
        datapoint_error failed-to-set-epoch
        sleep 10
      fi
      continue
    fi

    sleep 60

    current_epoch=""
    for _ in $(seq 1 10); do
      current_epoch=$(solana --url "$RPC_URL" epoch || true)
      if [[ -n "$current_epoch" ]]; then
        break
      fi
      sleep 2
    done

#     if [[ -z "$current_epoch" ]]; then
#       datapoint_error failed-to-get-epoch
#       continue
#     fi
#       # [[ $current_epoch == "$last_archive_epoch" ]] ||
#     if [[ -f $exit_signal_file ]]; then
#       echo "$exit_signal_file present, forcing ledger archive for epoch $current_epoch"
#     else
#       if ((minutes_since_last_ledger_archive < $MINIMUM_MINUTES_BETWEEN_ARCHIVE)) || 
#         [[ $current_epoch == "$last_archive_epoch" ]] || [[ -f $no_archive_signal_file ]]; then
#         ((++minutes_since_last_ledger_archive))
#         # Every hour while waiting for the next epoch, emit a metric and verify/archive a snapshot
#         if ((minutes_since_last_ledger_archive % 60 == 0)); then
#           echo "Current epoch: $current_epoch"
#           if [[ -f $no_archive_signal_file ]]; then
#             echo "Archiving disabled due to $no_archive_signal_file"
#           fi

#           datapoint waiting-to-archive "minutes_since=$minutes_since_last_ledger_archive"

#           latest_snapshot=$(get_latest_snapshot "$ledger_snapshots_dir")
#           if [[ -n $latest_snapshot ]]; then
#             latest_snapshot_slot=$(get_snapshot_slot "$latest_snapshot")

#             if [[ $latest_snapshot_slot = "$last_known_good_snapshot_slot" ]]; then
#               # Problem!  No new snapshot in the last hour
#               datapoint_error snapshot-stuck "slot=$latest_snapshot_slot"
#             else
#               # Archive the hourly snapshot
#               mkdir -p /home/sol/ledger/ledger-archive/hourly
#               ln -f "$latest_snapshot" /home/sol/ledger/ledger-archive/hourly/

#               # Sanity check: ensure the snapshot verifies
#               echo "Verifying snapshot for $latest_snapshot_slot: $latest_snapshot"
#               rm -rf /home/sol/ledger/snapshot-check
#               mkdir /home/sol/ledger/snapshot-check
#               ln -s "$ledger_dir"/genesis.bin /home/sol/ledger/snapshot-check/
#               ln "$latest_snapshot" /home/sol/ledger/snapshot-check/
#               if solana-ledger-tool --ledger /home/sol/ledger/snapshot-check verify; then
#                 datapoint snapshot-verification-ok "slot=$latest_snapshot_slot"
#                 last_known_good_snapshot_slot=$latest_snapshot_slot
#               else
#                 datapoint_error snapshot-verification-failed "slot=$latest_snapshot_slot"
#               fi
#             fi
#           fi
#         fi
#         continue
#       else
#         echo "Time to archive.  Current epoch:$current_epoch, last archive epoch: $last_archive_epoch"
#       fi
#     fi

#     latest_snapshot=$(get_latest_snapshot "$ledger_snapshots_dir")
#     if [[ -z $latest_snapshot ]]; then
#       echo "Validator has not produced a snapshot yet"
#       datapoint_error snapshot-missing
#       continue
#     fi
#     latest_snapshot_slot=$(get_snapshot_slot "$latest_snapshot")
#     echo "Latest snapshot: slot $latest_snapshot_slot: $latest_snapshot"

#     if [[ "$archive_snapshot_slot" = "$latest_snapshot_slot" ]]; then
#       echo "Validator has not produced a new snapshot yet"
#       datapoint_error stale-snapshot
#       continue
#     fi

#     echo Killing the node
#     datapoint validator-terminated
#     kill_node

#     echo "Archiving snapshot from $archive_snapshot_slot and subsequent ledger"
#     SECONDS=
#     (
#       set -x
#       solana-ledger-tool --ledger "$ledger_dir" bounds | tee /home/sol/ledger/ledger-archive/bounds.txt
#       solana-ledger-tool --version | tee /home/sol/ledger/ledger-archive/version.txt
#     )
#     ledger_bounds="$(cat /home/sol/ledger/ledger-archive/bounds.txt)"
#     datapoint ledger-archived "label=\"$archive_snapshot_slot\",duration_secs=$SECONDS,bounds=\"$ledger_bounds\""

#     mv "$ledger_dir"/rocksdb /home/sol/ledger/ledger-archive/

#     mkdir -p /home/sol/ledger/"$STORAGE_BUCKET".inbox
#     mv /home/sol/ledger/ledger-archive /home/sol/ledger/"$STORAGE_BUCKET".inbox/"$archive_snapshot_slot"

#     # Clean out the ledger directory from all artifacts other than genesis and
#     # the snapshot archives, so the warehouse node restarts cleanly from its
#     # last snapshot
    
    
#     rm -rf "$ledger_dir"/accounts "$ledger_snapshots_dir"/snapshot

#     # Remove the tower state to avoid a panic on validator restart due to the manual
#     # manipulation of the ledger directory
#     rm -f "$ledger_dir"/tower*.bin

#     # Prepare for next archive
    
#     rm -rf /home/sol/ledger/ledger-archive
#     prepare_archive_location

#     if [[ -f $exit_signal_file ]]; then
#       echo $exit_signal_file present, exiting
#       exit 0
#     fi

    break
  done
done
