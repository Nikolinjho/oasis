#!/usr/bin/env bash
# Сборка .app: ./Scripts/bundle.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
APP="build/AlcoveAnalog.app"
IDENTITY="Alcove Analog Dev"
ADAPTER="Vendor/mediaremote-adapter"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/AlcoveAnalog"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AlcoveAnalog"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ -d "$ADAPTER" ]; then
    cp -R "$ADAPTER/MediaRemoteAdapter.framework" "$ADAPTER/mediaremote-adapter.pl" "$APP/Contents/Resources/"
else
    echo "Нет $ADAPTER: музыки не будет, запусти Scripts/fetch-adapter.sh" >&2
fi

# звуки Alcove: только для локальной сборки, в git их нет (assets/ в .gitignore)
# в worktree папки assets нет: по умолчанию берём из основного клона
SOUNDS="${ALCOVE_ASSETS:-$HOME/alcove-analog/assets}/sounds"
if [ -d "$SOUNDS" ]; then
    mkdir -p "$APP/Contents/Resources/Sounds"
    cp "$SOUNDS/event.caf" "$SOUNDS/low-battery.caf" "$SOUNDS/low-power.caf" "$APP/Contents/Resources/Sounds/"
else
    echo "Нет $SOUNDS: уведомления будут без звука" >&2
fi

if security find-identity -p codesigning | grep -q "$IDENTITY"; then
    SIGN="$IDENTITY"
else
    echo "Нет сертификата «$IDENTITY», подписываю ad-hoc: разрешения будут слетать" >&2
    SIGN="-"
fi

# вложенный фреймворк подписываем первым, иначе codesign не примет бандл
if [ -d "$APP/Contents/Resources/MediaRemoteAdapter.framework" ]; then
    codesign --force --sign "$SIGN" "$APP/Contents/Resources/MediaRemoteAdapter.framework"
fi
codesign --force --sign "$SIGN" "$APP"
echo "Собрано: $APP ($CONFIG, подпись: $SIGN)"
