#!/usr/bin/env bash
# Скачивает SwiftLint фиксированной версии в Vendor/swiftlint: ./Scripts/fetch-swiftlint.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.65.1"
# sha256 portable_swiftlint.zip из релиза 0.65.1 (digest в GitHub API релиза)
SHA256="c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"
OUT="Vendor/swiftlint"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL -o "$TMP/swiftlint.zip" \
    "https://github.com/realm/SwiftLint/releases/download/$VERSION/portable_swiftlint.zip"
echo "$SHA256  $TMP/swiftlint.zip" | shasum -a 256 -c --status \
    || { echo "sha256 не совпал: архив SwiftLint $VERSION подменён или битый" >&2; exit 1; }
unzip -q "$TMP/swiftlint.zip" -d "$TMP/unzipped"

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$TMP/unzipped/swiftlint" "$TMP/unzipped/LICENSE" "$OUT/"
chmod +x "$OUT/swiftlint"
echo "$VERSION" > "$OUT/VERSION"
echo "swiftlint $("$OUT/swiftlint" version)"
