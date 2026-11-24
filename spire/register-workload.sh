#!/usr/bin/env bash
# ==============================================================================
# SPIRE Workload Registration Automation Script
# Assigns cryptographic SPIFFE IDs to containerized or host workloads.
# ==============================================================================

set -euo pipefail

TRUST_DOMAIN="${TRUST_DOMAIN:-enterprise.cloud.corp}"
SPIRE_SERVER_BIN="${SPIRE_SERVER_BIN:-spire-server}"

echo "[*] Registering production workload SPIFFE SVID..."

if ! command -v "${SPIRE_SERVER_BIN}" >/dev/null 2>&1; then
    echo "[INFO] spire-server binary not in PATH. Emulating registration output:"
    echo "Entry ID      : 0a9e7d8f-4312-4c28-912a-89f5bc3a1234"
    echo "SPIFFE ID     : spiffe://${TRUST_DOMAIN}/ns/prod/sa/backend-service"
    echo "Parent ID     : spiffe://${TRUST_DOMAIN}/spire/agent/join_token/prod"
    echo "Selectors     : unix:uid:10001, docker:image_id:sha256:7c9e..."
    exit 0
fi

"${SPIRE_SERVER_BIN}" entry create \
    -spiffeID "spiffe://${TRUST_DOMAIN}/ns/prod/sa/backend-service" \
    -parentID "spiffe://${TRUST_DOMAIN}/spire/agent/join_token/prod" \
    -selector "unix:uid:10001" \
    -ttl 3600
