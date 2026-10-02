#!/usr/bin/env bash
# Установка одной рабочей копии: ./Scripts/install.sh [debug|release]
# Собирает .app, гасит запущенные копии и нативный Alcove, кладёт бандл в ~/Applications и запускает его.
# Копия в ~/Applications — единственная, которую стоит держать: разрешения, Launch at Login
# и ссылки oasis:// привязаны к bundle id, и с несколькими копиями система путает, какую открыть
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
TARGET="$HOME/Applications/Oasis.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

./Scripts/bundle.sh "$CONFIG"

# два острова над вырезом мешают друг другу
osascript -e 'quit app "Alcove"' 2>/dev/null || true
pkill -f "Oasis.app/Contents/MacOS/Oasis" 2>/dev/null || true
# миграция после переименования Alcove Analog → Oasis: старая копия тоже гасится и удаляется ниже,
# иначе в ~/Applications остаются две копии (правило одной установленной копии)
OLD_TARGET="$HOME/Applications/AlcoveAnalog.app"
pkill -f "AlcoveAnalog.app/Contents/MacOS/AlcoveAnalog" 2>/dev/null || true
# ждём выхода старой копии: stop() адаптера занимает до 0.5 с, иначе два острова живут одновременно
for _ in $(seq 1 30); do
    pgrep -f "Oasis.app/Contents/MacOS/Oasis" >/dev/null \
        || pgrep -f "AlcoveAnalog.app/Contents/MacOS/AlcoveAnalog" >/dev/null || break
    sleep 0.1
done

if [ -d "$OLD_TARGET" ]; then
    "$LSREGISTER" -u "$OLD_TARGET" 2>/dev/null || true
    rm -rf "$OLD_TARGET"
fi

mkdir -p "$HOME/Applications"
rm -rf "$TARGET"
ditto build/Oasis.app "$TARGET"

# LaunchServices должен знать установленную копию, а не сборку из build/
"$LSREGISTER" -f "$TARGET"
"$LSREGISTER" -u "$PWD/build/Oasis.app" 2>/dev/null || true

open "$TARGET"
echo "Установлено: $TARGET"
