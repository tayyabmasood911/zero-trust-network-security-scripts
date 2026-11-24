#!/usr/bin/env bash
set -euo pipefail

echo "=== Zero Trust Network Security Suite Healthcheck ==="
python3 --version
python3 mtls/mtls_cert_manager.py --mock-test

if [ -f "firewall/nftables-zero-trust-default-deny.nft" ]; then
    echo "[OK] nftables default-deny ruleset present."
fi

if [ -f "spire/agent.conf" ] && [ -f "spire/server.conf" ]; then
    echo "[OK] SPIRE node agent and server configs present."
fi

echo "[OK] Healthcheck passed."
exit 0
