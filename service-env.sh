#RESTART=1 # Update the below block before uncommenting this line
if [[ -n "$RESTART" ]]; then
        WAIT_FOR_SUPERMAJORITY=96542804
        EXPECTED_BANK_HASH=5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d
fi
EXPECTED_SHRED_VERSION=""
EXPECTED_GENESIS_HASH=5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d
TRUSTED_VALIDATOR_PUBKEYS=(7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S)
export SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=mainnet-beta,u=mainnet-beta_write,p=password
#Replace the below with a full path that includes both Solana's binary and generic system binaries
#Do not enter PATH=$PATH if you're planning to run the script as systemctl
PATH="/home/sol/.local/share/solana/install/active_release/bin"
#MINIMUM_MINUTES_BETWEEN_ARCHIVE=1
RPC_URL=https://api.mainnet-beta.solana.com
ENTRYPOINT_HOST=mainnet-beta.solana.com
ENTRYPOINT_PORT=8001
ENTRYPOINT=mainnet-beta.solana.com:8001
ENTRYPOINTS=(
  entrypoint2.mainnet-beta.solana.com:8001
  entrypoint3.mainnet-beta.solana.com:8001
  entrypoint4.mainnet-beta.solana.com:8001
  entrypoint5.mainnet-beta.solana.com:8001
)
export RUST_BACKTRACE=1
export LimitNOFILE=1000000
export GOOGLE_APPLICATION_CREDENTIALS="/home/sol/zeeveops-55b1c31155ae.json"
ENABLE_CPI_AND_LOG_STORAGE=1
