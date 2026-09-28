#!/usr/bin/env bash
# Запись полосы вокруг выреза: ./record.sh <сценарий> [секунды]
set -euo pipefail
name="${1:?укажи имя сценария, см. scenarios.md}"
secs="${2:-4}"
dir="$(cd "$(dirname "$0")" && pwd)/recordings"
mkdir -p "$dir"

# ширина главного экрана в пунктах
screen_w=$(osascript -e 'tell application "Finder" to get item 3 of (get bounds of window of desktop)')
w=700 h=140
x=$(( (screen_w - w) / 2 ))

echo "Запись «${name}»: ${secs} с, область ${w}x${h} pt с x=$x. Старт через 1 с…"
sleep 1
screencapture -v -k -V "$secs" -R "$x,0,$w,$h" "$dir/$name.mov"
echo "Готово: $dir/$name.mov"
