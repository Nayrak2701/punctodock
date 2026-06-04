#!/bin/bash
#
# setup_signing.sh — creates a STABLE self-signed code-signing identity for PunctoDock
# so the Accessibility (TCC) permission is NOT lost on every Xcode build.
#
# Background:
#   Ad-hoc signed builds (the Xcode default with no team) use the binary's cdhash as
#   their "designated requirement". Every build => new cdhash => macOS TCC sees a
#   "different" app and the granted permission no longer matches. A fixed certificate
#   identity makes the requirement depend on the (constant) certificate instead, so the
#   permission stays valid across all builds.
#
# Idempotent: does nothing if the identity already exists.
#
set -euo pipefail

IDENTITY="PunctoDock Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "✓ Identity '$IDENTITY' already exists — nothing to do."
    security find-identity -p codesigning | grep "$IDENTITY"
    exit 0
fi

echo "→ Creating self-signed code-signing certificate '$IDENTITY' ..."

cat > "$TMP/cert.cnf" <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions = v3
prompt = no
[ dn ]
CN = PunctoDock Self-Signed
[ v3 ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# IMPORTANT: use the system LibreSSL (/usr/bin/openssl) — the macOS 'security' tool
# reads its PKCS12 format reliably (Homebrew OpenSSL 3 produces a MAC that 'security'
# cannot verify).
/usr/bin/openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -config "$TMP/cert.cnf"

/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout pass:punctodock -name "$IDENTITY"

# -A: any app (including codesign) may use the key without prompting
# -T /usr/bin/codesign: explicitly add codesign to the ACL
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P punctodock -T /usr/bin/codesign -A

echo ""
echo "✓ Identity created:"
security find-identity -p codesigning | grep "$IDENTITY"
echo ""
echo "Next steps:"
echo "  1) python3 generate_xcodeproj.py   (uses CODE_SIGN_IDENTITY='$IDENTITY')"
echo "  2) Build & run in Xcode"
echo "  3) Grant Accessibility ONCE — it then persists across all builds."
