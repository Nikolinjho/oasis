#!/usr/bin/env bash
# Установка одной рабочей копии: ./Scripts/install.sh [debug|release]
# Собирает .app, гасит запущенные копии и нативный Alcove, кладёт бандл в ~/Applications и запускает его.
# Копия в ~/Applications — единственная, которую стоит держать: разрешения, Launch at Login
# и ссылки alcove-analog:// привязаны к bundle id, и с несколькими копиями система путает, какую открыть
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
TARGET="$HOME/Applications/AlcoveAnalog.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

./Scripts/bundle.sh "$CONFIG"

# два острова над вырезом мешают друг другу
osascript -e 'quit app "Alcove"' 2>/dev/null || true
pkill -f "AlcoveAnalog.app/Contents/MacOS/AlcoveAnalog" 2>/dev/null || true
sleep 0.5

mkdir -p "$HOME/Applications"
rm -rf "$TARGET"
ditto build/AlcoveAnalog.app "$TARGET"

# LaunchServices должен знать установленную копию, а не сборку из build/
"$LSREGISTER" -f "$TARGET"
"$LSREGISTER" -u "$PWD/build/AlcoveAnalog.app" 2>/dev/null || true

open "$TARGET"
echo "Установлено: $TARGET"
