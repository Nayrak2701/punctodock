#!/bin/bash
#
# setup_signing.sh — erstellt eine STABILE selbst-signierte Code-Signing-Identität
# für PunctoDock, damit die Bedienungshilfen-Berechtigung (Accessibility/TCC) NICHT
# bei jedem Xcode-Build verloren geht.
#
# Hintergrund:
#   Ad-hoc-signierte Builds (Xcode-Default ohne Team) haben als "designated
#   requirement" den cdhash des Binaries. Jeder Build => neuer cdhash => macOS-TCC
#   sieht eine "andere" App und die erteilte Berechtigung matcht nicht mehr.
#   Eine feste Zertifikats-Identität macht das Requirement stattdessen vom
#   (konstanten) Zertifikat abhängig => Berechtigung bleibt über alle Builds gültig.
#
# Idempotent: tut nichts, wenn die Identität bereits existiert.
#
set -euo pipefail

IDENTITY="PunctoDock Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "✓ Identität '$IDENTITY' existiert bereits — nichts zu tun."
    security find-identity -p codesigning | grep "$IDENTITY"
    exit 0
fi

echo "→ Erzeuge selbst-signiertes Code-Signing-Zertifikat '$IDENTITY' ..."

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

# WICHTIG: System-LibreSSL (/usr/bin/openssl) verwenden — dessen PKCS12-Format
# liest das macOS 'security'-Tool zuverlässig (Homebrew-OpenSSL3 erzeugt einen
# MAC, den 'security' nicht verifizieren kann).
/usr/bin/openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -config "$TMP/cert.cnf"

/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout pass:punctodock -name "$IDENTITY"

# -A: jede App (inkl. codesign) darf den Key ohne erneute Nachfrage nutzen
# -T /usr/bin/codesign: codesign explizit in die ACL
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P punctodock -T /usr/bin/codesign -A

echo ""
echo "✓ Identität angelegt:"
security find-identity -p codesigning | grep "$IDENTITY"
echo ""
echo "Nächste Schritte:"
echo "  1) python3 generate_xcodeproj.py   (nutzt CODE_SIGN_IDENTITY='$IDENTITY')"
echo "  2) In Xcode bauen & starten"
echo "  3) Bedienungshilfen EINMAL freigeben — hält danach über alle Builds."
