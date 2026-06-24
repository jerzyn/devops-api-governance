#!/usr/bin/env bash
# Pre-render d2 diagrams to PNG for sharp display in presenterm.
# Live +render upscales low-res bitmaps in the terminal; baked PNGs at high
# scale are downscaled instead, which stays crisp.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIAGRAMS="${ROOT}/diagrams"
SCALE="${D2_SCALE:-4}"

if ! command -v d2 >/dev/null 2>&1; then
  echo "d2 not found on PATH — install via presentation/install-d2.sh or go install" >&2
  exit 1
fi

for src in "${DIAGRAMS}"/*.d2; do
  [ -f "$src" ] || continue
  base="$(basename "$src" .d2)"
  out="${DIAGRAMS}/${base}.png"
  echo "Rendering ${base} (scale=${SCALE}) ..."
  d2 --scale "${SCALE}" --theme 200 "$src" "$out"
done

echo "Done."
