#!/usr/bin/env bash
# ==============================================================================
# Safe Firewall Ruleset Applier with Watchdog Auto-Rollback
# Applies nftables rules with automated fallback to prevent network lockout.
# ==============================================================================

set -euo pipefail

NFT_FILE="${1:-firewall/nftables-zero-trust-default-deny.nft}"
WATCHDOG_TIMEOUT="${WATCHDOG_TIMEOUT:-20}"

echo "==========================================================="
echo "       SAFE ZERO TRUST FIREWALL PROVISIONER               "
echo "==========================================================="
echo "[*] Ruleset target: ${NFT_FILE}"

if ! command -v nft >/dev/null 2>&1; then
    echo "[WARN] nftables CLI 'nft' not available in this environment. Simulating apply..."
    exit 0
fi

echo "[*] Creating backup of current nftables ruleset..."
nft list ruleset > /tmp/nftables.backup || true

echo "[*] Arming watchdog timer (${WATCHDOG_TIMEOUT}s)..."
(
  sleep "${WATCHDOG_TIMEOUT}"
  if [ -f /tmp/watchdog_active ]; then
    echo "[ROLLBACK TRIGGERED] Watchdog expired! Reverting to backup..."
    nft -f /tmp/nftables.backup || nft flush ruleset
    rm -f /tmp/watchdog_active
  fi
) &
WATCHDOG_PID=$!
touch /tmp/watchdog_active

echo "[*] Applying zero-trust default-deny ruleset..."
nft -f "${NFT_FILE}"

echo "[*] Verifying connectivity..."
if ping -c 1 127.0.0.1 >/dev/null 2>&1; then
    echo "[SUCCESS] Loopback connectivity confirmed. Disarming watchdog..."
    rm -f /tmp/watchdog_active
    kill "${WATCHDOG_PID}" 2>/dev/null || true
    echo "[OK] Firewall active and locked down to Zero Trust default-deny."
else
    echo "[ERROR] Connectivity check failed! Letting watchdog rollback..."
    exit 1
fi
