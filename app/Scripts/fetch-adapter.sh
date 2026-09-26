#!/usr/bin/env bash
# Скачивает и собирает mediaremote-adapter (BSD-3) в Vendor/mediaremote-adapter: ./Scripts/fetch-adapter.sh
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="Vendor/mediaremote-adapter"
SRC="$(mktemp -d)/mediaremote-adapter"
trap 'rm -rf "$(dirname "$SRC")"' EXIT

git clone --depth 1 https://github.com/ungive/mediaremote-adapter.git "$SRC"
cmake -S "$SRC" -B "$SRC/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$SRC/build"

SCRIPT="$(find "$SRC" -name mediaremote-adapter.pl -not -path '*/build/*' | head -1)"
[ -n "$SCRIPT" ] || { echo "не нашёл mediaremote-adapter.pl в репозитории" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$SRC/build/MediaRemoteAdapter.framework" "$OUT/"
cp "$SCRIPT" "$OUT/"
git -C "$SRC" rev-parse HEAD > "$OUT/REVISION"

# путь к фреймворку только абсолютный: относительный dlopen в системном perl не грузит
/usr/bin/perl "$OUT/mediaremote-adapter.pl" "$PWD/$OUT/MediaRemoteAdapter.framework" test
echo "адаптер работает, ревизия $(cat "$OUT/REVISION")"
