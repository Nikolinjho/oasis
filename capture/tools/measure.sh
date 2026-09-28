#!/usr/bin/env bash
# Трек габаритов по записи и сверка с эталоном: ./tools/measure.sh recordings/demo.mov
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
python="${PYTHON:-$here/../../.venv/bin/python3}"
src="${1:?укажи запись, например recordings/demo.mov}"
name="$(basename "${src%.*}")"
out="$here/../analysis/$name"
mkdir -p "$out"

ffprobe -v error -select_streams v:0 -show_entries frame=pts_time -of csv=p=0 "$src" > "$out/pts.txt"
IFS=x read -r width height < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$src")
if [ -z "${width:-}" ] || [ -z "${height:-}" ]; then
    echo "ffprobe не смог прочитать width/height из $src" >&2
    exit 1
fi
"$python" "$here/track.py" "$src" "$out/pts.txt" "$out/track.json" 0 "$width" "$height"
"$python" "$here/compare.py" "$out/track.json" | tee "$out/compare.txt"
