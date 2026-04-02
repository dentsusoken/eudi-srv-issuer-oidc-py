#!/bin/bash
# EUDIW Python Issuer - Certificate Setup Script
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/certs"
PARENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --cloud フラグの解析
CLOUD=false
for arg in "$@"; do
  if [ "$arg" = "--cloud" ]; then
    CLOUD=true
  fi
done

echo "=== Creating certificate directories ==="
mkdir -p "$CERTS_DIR/trusted_cas" "$CERTS_DIR/privKey" "$CERTS_DIR/tls" "$CERTS_DIR/verifier"

if [ "$CLOUD" = false ]; then
  # ----------------------------------------------------------------
  # TLS 証明書の生成 (mkcert)
  # ----------------------------------------------------------------
  echo "=== Generating TLS certificate with mkcert ==="
  if ! command -v mkcert &>/dev/null; then
    echo "  ERROR: mkcert not found. Install with: brew install mkcert"
    exit 1
  fi

  mkcert -install || true
  mkcert \
    -cert-file "$CERTS_DIR/tls/localhost+2.pem" \
    -key-file  "$CERTS_DIR/tls/localhost+2-key.pem" \
    localhost 127.0.0.1 ::1

  # ----------------------------------------------------------------
  # iOS Simulator に mkcert CA を登録
  # ----------------------------------------------------------------
  echo "=== Registering mkcert CA with iOS Simulator ==="
  MKCERT_CA="$(mkcert -CAROOT)/rootCA.pem"
  if xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
    xcrun simctl keychain booted add-root-cert "$MKCERT_CA"
    echo "  Registered to booted simulator"
  else
    echo "  WARNING: No booted iOS Simulator found. Run manually after launching Simulator:"
    echo "    xcrun simctl keychain booted add-root-cert \"$MKCERT_CA\""
  fi
fi

# ----------------------------------------------------------------
# ログ用ディレクトリの作成
# ----------------------------------------------------------------
echo "=== Creating log directories ==="
mkdir -p /tmp/log_dev /tmp/oidc_log_dev /tmp/issuer_frontend/log_dev

# ----------------------------------------------------------------
# IACA (root CA) 鍵 + 証明書
# ----------------------------------------------------------------
echo "=== Generating IACA (root CA) key and certificate ==="
openssl ecparam -genkey -name prime256v1 -noout \
  -out "$CERTS_DIR/privKey/IACA_UT_key.pem"

openssl req -new -x509 -key "$CERTS_DIR/privKey/IACA_UT_key.pem" \
  -out "$CERTS_DIR/trusted_cas/IACA_UT.pem" \
  -days 3650 \
  -subj "/CN=PID Issuer CA - UT 01/O=EUDI Wallet Reference Implementation/C=UT" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -not_before 20250101000000Z

# ----------------------------------------------------------------
# DS (Document Signing) 鍵 + IACA で署名した証明書
# ----------------------------------------------------------------
echo "=== Generating DS (Document Signing) key and certificate ==="
openssl ecparam -genkey -name prime256v1 -noout \
  -out "$CERTS_DIR/privKey/PID-DS-0001_UT.pem"

openssl req -new -key "$CERTS_DIR/privKey/PID-DS-0001_UT.pem" \
  -out /tmp/ds_ut.csr \
  -subj "/CN=PID DS - 0002/O=EUDI Wallet Reference Implementation/C=UT"

openssl x509 -req -in /tmp/ds_ut.csr \
  -CA "$CERTS_DIR/trusted_cas/IACA_UT.pem" \
  -CAkey "$CERTS_DIR/privKey/IACA_UT_key.pem" \
  -CAcreateserial \
  -out /tmp/ds_ut_cert.pem \
  -days 3650 \
  -not_before 20250101000000Z \
  -extfile <(printf "basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature")

openssl x509 -in /tmp/ds_ut_cert.pem -outform DER \
  -out "$CERTS_DIR/trusted_cas/PID-DS-0001_UT_cert.der"

rm -f /tmp/ds_ut.csr /tmp/ds_ut_cert.pem "$CERTS_DIR/trusted_cas/IACA_UT.srl"

# ----------------------------------------------------------------
# Nonce 用 RSA 鍵
# ----------------------------------------------------------------
echo "=== Generating Nonce RSA key ==="
openssl genrsa -out "$CERTS_DIR/privKey/nonce_rsa2048.pem" 2048

# ----------------------------------------------------------------
# Credential Request 用 EC 鍵
# ----------------------------------------------------------------
echo "=== Generating Credential Request EC key ==="
openssl ecparam -genkey -name prime256v1 -noout \
  -out "$CERTS_DIR/privKey/credential_request.pem"

# ----------------------------------------------------------------
# metadata_config_local.json の JWK を新しい公開鍵で更新
# ----------------------------------------------------------------
echo "=== Updating metadata_config_local.json with new EC public key ==="
python3 - <<PYEOF
import sys, json, base64, hashlib, subprocess

key_file  = "$CERTS_DIR/privKey/credential_request.pem"
meta_file = "$PARENT_DIR/eudi-srv-web-issuing-eudiw-py/app/metadata_config/metadata_config_local.json"

result = subprocess.run(
    ["openssl", "ec", "-in", key_file, "-pubout", "-outform", "DER"],
    capture_output=True, check=True
)
raw_pub = result.stdout[-65:]
assert raw_pub[0] == 4, "Unexpected EC key format"

def b64url(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

x = b64url(raw_pub[1:33])
y = b64url(raw_pub[33:65])

thumb_input = json.dumps({"crv":"P-256","kty":"EC","x":x,"y":y},
                          sort_keys=True, separators=(",",":"))
kid = b64url(hashlib.sha256(thumb_input.encode()).digest())

with open(meta_file) as f:
    metadata = json.load(f)

key = metadata["credential_request_encryption"]["jwks"]["keys"][0]
key["x"], key["y"], key["kid"] = x, y, kid

with open(meta_file, "w") as f:
    json.dump(metadata, f, indent=3)

print(f"  kid={kid}")
PYEOF

# ----------------------------------------------------------------
# Verifier JAR 署名用証明書チェーン (root → intermediate → verifier, ES256)
# ----------------------------------------------------------------
echo "=== Generating Verifier JAR signing certificate chain (ES256) ==="
VTMP=$(mktemp -d)
trap 'rm -rf "$VTMP"' EXIT

# Root CA
openssl ecparam -name prime256v1 -genkey -noout -out "$VTMP/root.key"
openssl req -new -x509 -key "$VTMP/root.key" -out "$VTMP/root.crt" -days 36500 \
  -subj "/CN=root" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

# Intermediate CA
openssl ecparam -name prime256v1 -genkey -noout -out "$VTMP/intermediate.key"
openssl req -new -key "$VTMP/intermediate.key" -out "$VTMP/intermediate.csr" \
  -subj "/CN=intermediate"
openssl x509 -req -in "$VTMP/intermediate.csr" \
  -CA "$VTMP/root.crt" -CAkey "$VTMP/root.key" -CAcreateserial \
  -out "$VTMP/intermediate.crt" -days 36500 \
  -extfile <(printf "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectAltName=DNS:intermediate\nissuerAltName=DNS:intermediate")

# Verifier cert
openssl ecparam -name prime256v1 -genkey -noout -out "$VTMP/verifier.key"
openssl req -new -key "$VTMP/verifier.key" -out "$VTMP/verifier.csr" \
  -subj "/CN=verifier"
openssl x509 -req -in "$VTMP/verifier.csr" \
  -CA "$VTMP/intermediate.crt" -CAkey "$VTMP/intermediate.key" -CAcreateserial \
  -out "$VTMP/verifier.crt" -days 36500 \
  -extfile <(printf "subjectAltName=DNS:localhost,DNS:verifier\nbasicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature")

# PKCS12 → JKS
openssl pkcs12 -export \
  -in "$VTMP/verifier.crt" \
  -inkey "$VTMP/verifier.key" \
  -certfile <(cat "$VTMP/intermediate.crt" "$VTMP/root.crt") \
  -name verifier \
  -out "$VTMP/keystore.p12" \
  -passout pass:keystore

keytool -importkeystore \
  -srckeystore "$VTMP/keystore.p12" -srcstoretype PKCS12 -srcstorepass keystore \
  -destkeystore "$CERTS_DIR/verifier/keystore.jks" -deststoretype JKS \
  -deststorepass keystore -destkeypass verifier \
  -noprompt

rm -rf "$VTMP"
echo "  Generated: certs/verifier/keystore.jks"

echo ""
echo "=== Done ==="
echo ""
echo "--- certs/privKey/ ---"
ls -1 "$CERTS_DIR/privKey/"
echo ""
echo "--- certs/trusted_cas/ ---"
ls -1 "$CERTS_DIR/trusted_cas/"
