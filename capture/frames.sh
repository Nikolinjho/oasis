#!/usr/bin/env bash
# Нарезка записи на кадры и контактный лист: ./frames.sh recordings/<сценарий>.mov [fps листа]
set -euo pipefail
src="${1:?укажи файл записи}"
sheet_fps="${2:-30}"
name="$(basename "${src%.*}")"
out="$(cd "$(dirname "$0")" && pwd)/frames/$name"
rm -rf "$out" && mkdir -p "$out"

ffmpeg -loglevel error -i "$src" "$out/%04d.png"
total=$(ls "$out" | wc -l | tr -d ' ')
fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$src")

# контактный лист: кадры с шагом 1/sheet_fps, по 4 в ряд, слева направо и сверху вниз
ffmpeg -loglevel error -i "$src" \
  -vf "fps=${sheet_fps},scale=480:-1,tile=4x12:padding=4:color=gray" \
  -frames:v 1 "$out/contact.png"

echo "$name: $total кадров при $fps fps → $out (контактный лист: contact.png)"
