#!/usr/bin/env bash
# Сборка .app: ./Scripts/bundle.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
APP="build/Oasis.app"
IDENTITY="Oasis Dev"
ADAPTER="Vendor/mediaremote-adapter"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Oasis"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Oasis"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# иконка приложения и template-значок menu bar (исходники и генератор — design/oasis-icon)
cp -R Resources/YandexMusic "$APP/Contents/Resources/"
cp Resources/AppIcon.icns Resources/MenuBarIcon.png Resources/MenuBarIcon@2x.png "$APP/Contents/Resources/"

if [ -d "$ADAPTER" ]; then
    cp -R "$ADAPTER/MediaRemoteAdapter.framework" "$ADAPTER/mediaremote-adapter.pl" "$APP/Contents/Resources/"
else
    echo "Нет $ADAPTER: источник System недоступен, запусти Scripts/fetch-adapter.sh" >&2
fi

# звуки Alcove: только для локальной сборки, в git их нет (assets/ в .gitignore)
# в worktree папки assets нет: по умолчанию берём из основного клона
SOUNDS="${ALCOVE_ASSETS:-$HOME/oasis/assets}/sounds"
if [ -d "$SOUNDS" ]; then
    mkdir -p "$APP/Contents/Resources/Sounds"
    cp "$SOUNDS/event.caf" "$SOUNDS/chime.caf" "$SOUNDS/low-battery.caf" "$SOUNDS/low-power.caf" "$APP/Contents/Resources/Sounds/"
else
    echo "Нет $SOUNDS: уведомления будут без звука" >&2
fi

# знак Claude из установленного приложения, в git чужой логотип не хранится
CLAUDE_ICON="${ALCOVE_CLAUDE_ICON:-/Applications/Claude.app/Contents/Resources/TrayIconTemplate@3x.png}"
mkdir -p "$APP/Contents/Resources/Icons"
if [ -f "$CLAUDE_ICON" ]; then
    cp "$CLAUDE_ICON" "$APP/Contents/Resources/Icons/claude.png"
else
    echo "Нет $CLAUDE_ICON: у Claude будет SF Symbol sparkle" >&2
fi

# явное подключение из настроек копирует скрипт в Application Support
cp Scripts/claude-statusline.py "$APP/Contents/Resources/claude-statusline.py"

# иконка Meet для пункта Join в меню: из бандла Alcove (assets/images), в git её нет
IMAGES="${ALCOVE_ASSETS:-$HOME/oasis/assets}/images"
if [ -f "$IMAGES/GoogleMeetAppIcon18x18.png" ]; then
    mkdir -p "$APP/Contents/Resources/Icons"
    cp "$IMAGES/GoogleMeetAppIcon18x18.png" "$APP/Contents/Resources/Icons/google-meet.png"
else
    echo "Нет $IMAGES/GoogleMeetAppIcon18x18.png: у Join будет SF Symbol video.fill" >&2
fi

if security find-identity -p codesigning | grep -q "$IDENTITY"; then
    SIGN="$IDENTITY"
else
    echo "Нет сертификата «${IDENTITY}», подписываю ad-hoc: разрешения будут слетать" >&2
    SIGN="-"
fi

# вложенный фреймворк подписываем первым, иначе codesign не примет бандл
if [ -d "$APP/Contents/Resources/MediaRemoteAdapter.framework" ]; then
    codesign --force --sign "$SIGN" "$APP/Contents/Resources/MediaRemoteAdapter.framework"
fi
codesign --force --sign "$SIGN" "$APP"
echo "Собрано: $APP ($CONFIG, подпись: $SIGN)"
