#RESTART=1 # Update the below block before uncommenting this line
if [[ -n "$RESTART" ]]; then
        WAIT_FOR_SUPERMAJORITY=0
        EXPECTED_BANK_HASH=74vc9eZcqavjLQYohoi3vGjrXtMCsNQCwTwUU77ZGgvL
fi
EXPECTED_SHRED_VERSION=""
EXPECTED_GENESIS_HASH=EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG
TRUSTED_VALIDATOR_PUBKEYS=(
   dv2eQHeP4RFrJZ6UeiZWoc3XTtmtZCUKxxCApCDcRNV
   dv3qDFk1DTF36Z62bNvrCXe9sKATA6xvVy6A798xxAS
   dv1ZAGvdsz5hHLwWXsVnM94hWf1pjbKVau1QVkaMJ92
   dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB)
export SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=devnet,u=scratch_writer,p=topsecret
#Replace the below with a full path that includes both Solana's binary and generic system binaries
#Do not enter PATH=$PATH if you're planning to run the script as systemctl
PATH="/home/sol/.local/share/solana/install/active_release/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
MINIMUM_MINUTES_BETWEEN_ARCHIVE=1
RPC_URL=http://api.devnet.solana.com/
ENTRYPOINT_HOST=devnet.solana.com
ENTRYPOINT_PORT=8001
ENTRYPOINT=entrypoint.devnet.solana.com:8001
ENTRYPOINTS=(
  entrypoint.devnet.solana.com:8001
  entrypoint2.devnet.solana.com:8001
  entrypoint3.devnet.solana.com:8001
  entrypoint4.devnet.solana.com:8001
)
export RUST_BACKTRACE=1
export LimitNOFILE=1000000
export GOOGLE_APPLICATION_CREDENTIALS="/home/sol/zeeveops-55b1c31155ae.json"
ENABLE_BPF_JIT=1
ENABLE_CPI_AND_LOG_STORAGE=1