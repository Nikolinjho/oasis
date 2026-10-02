#!/usr/bin/env bash
# Форматирование и линт: ./Scripts/lint.sh — форматирует на месте и проверяет,
# ./Scripts/lint.sh --check — только проверяет (гейт перед коммитом), ненулевой выход при любом нарушении
set -euo pipefail
cd "$(dirname "$0")/.."

SWIFTLINT="Vendor/swiftlint/swiftlint"
PATHS=(Sources Tests Package.swift)

[ -x "$SWIFTLINT" ] || { echo "Нет $SWIFTLINT: запусти Scripts/fetch-swiftlint.sh" >&2; exit 1; }

case "${1:-}" in
    --check) ;;
    "") swift format format --in-place --recursive --parallel "${PATHS[@]}" ;;
    *) echo "использование: $0 [--check]" >&2; exit 2 ;;
esac

status=0
swift format lint --strict --recursive --parallel "${PATHS[@]}" || status=1
"$SWIFTLINT" lint --quiet --strict || status=1
[ "$status" -eq 0 ] && echo "lint: чисто"
exit "$status"
