#!/usr/bin/env bash
# ==============================================================================
# Enterprise Mutual TLS (mTLS) PKI Automation Engine
# Generates Root CA, Intermediate CA, Server, and Client Certificates with SANs
# and SPIFFE ID URIs for Zero Trust cryptographic authentication.
# ==============================================================================

set -euo pipefail

DEST_DIR="${1:-./certs}"
TRUST_DOMAIN="${2:-enterprise.cloud.corp}"
DAYS_VALID="${3:-365}"

echo "==========================================================="
echo "       ZERO TRUST mTLS CERTIFICATE GENERATION ENGINE       "
echo "==========================================================="
echo "[*] Destination:  ${DEST_DIR}"
echo "[*] Trust Domain: ${TRUST_DOMAIN}"

mkdir -p "${DEST_DIR}"

# 1. Root Certificate Authority (Root CA)
echo "[1/4] Generating Root Certificate Authority..."
openssl ecparam -name prime256v1 -genkey -noout -out "${DEST_DIR}/root-ca.key"
openssl req -new -x509 -sha256 -key "${DEST_DIR}/root-ca.key" -days 3650 \
  -subj "/C=US/O=Enterprise Zero Trust PKI/CN=Zero Trust Root CA" \
  -out "${DEST_DIR}/root-ca.crt"

# 2. Intermediate Certificate Authority (Intermediate CA)
echo "[2/4] Generating Intermediate Certificate Authority..."
openssl ecparam -name prime256v1 -genkey -noout -out "${DEST_DIR}/intermediate-ca.key"
openssl req -new -sha256 -key "${DEST_DIR}/intermediate-ca.key" \
  -subj "/C=US/O=Enterprise Zero Trust PKI/CN=Zero Trust Intermediate CA" \
  -out "${DEST_DIR}/intermediate-ca.csr"

cat <<EOF > "${DEST_DIR}/intermediate-ca.ext"
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

openssl x509 -req -in "${DEST_DIR}/intermediate-ca.csr" \
  -CA "${DEST_DIR}/root-ca.crt" -CAkey "${DEST_DIR}/root-ca.key" -CAcreateserial \
  -out "${DEST_DIR}/intermediate-ca.crt" -days 1825 -sha256 \
  -extfile "${DEST_DIR}/intermediate-ca.ext"

# Combine full trust chain
cat "${DEST_DIR}/intermediate-ca.crt" "${DEST_DIR}/root-ca.crt" > "${DEST_DIR}/ca-bundle.crt"

# 3. Server mTLS Certificate
echo "[3/4] Generating Service Server Certificate..."
openssl ecparam -name prime256v1 -genkey -noout -out "${DEST_DIR}/server.key"
openssl req -new -sha256 -key "${DEST_DIR}/server.key" \
  -subj "/C=US/O=Enterprise/CN=service.server.${TRUST_DOMAIN}" \
  -out "${DEST_DIR}/server.csr"

cat <<EOF > "${DEST_DIR}/server.ext"
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = service.server.${TRUST_DOMAIN}
DNS.2 = localhost
IP.1 = 127.0.0.1
URI.1 = spiffe://${TRUST_DOMAIN}/ns/prod/sa/backend-service
EOF

openssl x509 -req -in "${DEST_DIR}/server.csr" \
  -CA "${DEST_DIR}/intermediate-ca.crt" -CAkey "${DEST_DIR}/intermediate-ca.key" -CAcreateserial \
  -out "${DEST_DIR}/server.crt" -days "${DAYS_VALID}" -sha256 \
  -extfile "${DEST_DIR}/server.ext"

# 4. Client mTLS Certificate
echo "[4/4] Generating Workload Client Certificate..."
openssl ecparam -name prime256v1 -genkey -noout -out "${DEST_DIR}/client.key"
openssl req -new -sha256 -key "${DEST_DIR}/client.key" \
  -subj "/C=US/O=Enterprise/CN=workload.client.${TRUST_DOMAIN}" \
  -out "${DEST_DIR}/client.csr"

cat <<EOF > "${DEST_DIR}/client.ext"
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = workload.client.${TRUST_DOMAIN}
URI.1 = spiffe://${TRUST_DOMAIN}/ns/prod/sa/frontend-client
EOF

openssl x509 -req -in "${DEST_DIR}/client.csr" \
  -CA "${DEST_DIR}/intermediate-ca.crt" -CAkey "${DEST_DIR}/intermediate-ca.key" -CAcreateserial \
  -out "${DEST_DIR}/client.crt" -days "${DAYS_VALID}" -sha256 \
  -extfile "${DEST_DIR}/client.ext"

# Verification
echo "[*] Verifying certificate chain..."
openssl verify -CAfile "${DEST_DIR}/ca-bundle.crt" "${DEST_DIR}/server.crt"
openssl verify -CAfile "${DEST_DIR}/ca-bundle.crt" "${DEST_DIR}/client.crt"

echo "[SUCCESS] Zero Trust mutual TLS cryptographic certificates generated."
