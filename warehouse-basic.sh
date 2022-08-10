export PATH="/home/sol/.local/share/solana/install/active_release/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
export GOOGLE_APPLICATION_CREDENTIALS="/home/sol/zeeveops-55b1c31155ae.json"
export SOLANA_METRICS_CONFIG="host=https://metrics.solana.com:8086,db=mainnet-beta,u=mainnet-beta_write,p=password"

solana-validator \
        --ledger /home/sol/ledger \
        --identity /home/sol/validator-keypair.json \
        --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
        --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
        --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
        --entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
        --entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
        --trusted-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
        --trusted-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
        --trusted-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
        --trusted-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
        --dynamic-port-range 8000-8024 \
        --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
        --gossip-port 8001 \
        --enable-rpc-transaction-history \
        --rpc-port 8899 \
        --rpc-bind-address 0.0.0.0 \
        --full-rpc-api \
        --log /home/sol/log/validator.log \
        --no-voting \
        --enable-bigtable-ledger-upload \
        --snapshot-compression none \
        --require-tower \
        --enable-cpi-and-log-storage \
        --no-untrusted-rpc \
        --wal-recovery-mode skip_any_corrupted_record \
        --bpf-jit \
        --accounts /home/sol/accounts \
        
        
        # --identity /home/solana/validator-keypair.json \
        # --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
        # --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
        # --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
        # --entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
        # --entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
        # --trusted-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
        # --trusted-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
        # --trusted-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
        # --trusted-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
        # --dynamic-port-range 8000-8024 \
        # --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
        # --gossip-port 8001 \
        # --enable-rpc-transaction-history \
        # --rpc-port 8899 \
        # --rpc-bind-address 127.0.0.1 \
        # --log /home/solana/logs/validator.log \
        # --no-voting \
        # --full-rpc-api \
        # --enable-rpc-transaction-history \
        # --no-untrusted-rpc \
        # --wal-recovery-mode skip_any_corrupted_record \
        # --limit-ledger-size \
        # --bpf-jit \
        # --enable-cpi-and-log-storage \
        # --accounts /home/solana/accounts \
        # --ledger /home/solana/ledger
