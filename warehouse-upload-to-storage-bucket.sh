#!/bin/bash

PATH_TO_IDENTITY_KEYPAIR="/home/sol/validator-keypair.json"

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

#shellcheck source=./configure-metrics.sh
source "$here"/configure-metrics.sh

if [[ -z $STORAGE_BUCKET ]]; then
  echo STORAGE_BUCKET environment variable not defined
  exit 1
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

while true; do
  # Look for new ledger fragments from `warehouse.sh`
  for new_ledger in /home/sol/ledger/"$STORAGE_BUCKET".inbox/*; do
    mkdir -p /home/sol/ledger/"$STORAGE_BUCKET"
    mv $new_ledger /home/sol/ledger/"$STORAGE_BUCKET"
  done

  # Check for rocksdb/ directories and compress them
  # for rocksdb in /home/sol/ledger/"$STORAGE_BUCKET"/*/rocksdb; do
  #   SECONDS=
  #   (
  #     cd "$(dirname "$rocksdb")"
  #     declare archive_dir=$PWD

      # if [[ -n $GOOGLE_APPLICATION_CREDENTIALS ]]; then
      #   if [[ ! -f "$archive_dir"/.bigtable ]]; then
      #     echo "Uploading $archive_dir to BigTable"
      #     SECONDS=

      #     # --allow-missing-metadata
      #     while ! /bin/timeout 48h solana-ledger-tool --ledger "$archive_dir" bigtable upload; do
      #       echo "bigtable upload failed..."
      #       datapoint_error bigtable-upload-failure
      #       /bin/sleep 30
      #     done
      #     /bin/touch "$archive_dir"/.bigtable
      #     echo Ledger upload to bigtable took $SECONDS seconds
      #     datapoint bigtable-upload-complete "duration_secs=$SECONDS"
      #   fi
      # fi

  #     echo "Creating rocksdb.tar.bz2 in $archive_dir"
  #     /bin/rm -rf rocksdb.tar.bz2
  #     /bin/tar -cvjSf rocksdb.tar.bz2 rocksdb
  #     /bin/rm -rf rocksdb
  #     echo "$archive_dir/rocksdb.tar.bz2 created in $SECONDS seconds"
  # #   )
  #   datapoint created-rocksdb-tar-bz2 "duration_secs=$SECONDS"
  # done

  if [[ ! -d /home/sol/ledger/"$STORAGE_BUCKET" ]]; then
    echo "Nothing to upload, /home/sol/ledger/$STORAGE_BUCKET does not exist"
    /bin/sleep 60m
    continue
  fi

  killall gsutil || true

  SECONDS=
  (

	 set -x
	  while ! /bin/timeout 8h gsutil -m rsync -r /home/sol/ledger/"$STORAGE_BUCKET" gs://"$STORAGE_BUCKET"/; do
		  exit 1
	    echo "gsutil rsync failed..."
	    datapoint_error gsutil-rsync-failure
	    /bin/sleep 30
	  done
  )
  echo Ledger upload to storage bucket took $SECONDS seconds
  datapoint ledger-upload-complete "duration_secs=$SECONDS"
  /bin/rm -rf /home/sol/ledger/"$STORAGE_BUCKET"
done
