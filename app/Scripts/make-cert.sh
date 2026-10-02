#!/usr/bin/env bash
# Один раз создаёт самоподписанный сертификат для подписи сборок.
# Стабильная подпись нужна, чтобы macOS не сбрасывала Accessibility при каждой пересборке.
set -euo pipefail
NAME="Oasis Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Сертификат «$NAME» уже есть"
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# системный LibreSSL: его p12 без проблем импортирует security
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$tmp/cert.cnf" -keyout "$tmp/key.pem" -out "$tmp/cert.pem"

# одноразовый пароль контейнера, живёт только в переменной до конца скрипта
P12_PASS="$(uuidgen)"
export P12_PASS
/usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
    -name "$NAME" -out "$tmp/identity.p12" -passout env:P12_PASS
security import "$tmp/identity.p12" -k "$KEYCHAIN" -P "$P12_PASS" -T /usr/bin/codesign

# macOS спросит пароль пользователя, чтобы доверить сертификат для подписи кода
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$tmp/cert.pem"
echo "Готово: $(security find-identity -v -p codesigning | grep "$NAME")"
