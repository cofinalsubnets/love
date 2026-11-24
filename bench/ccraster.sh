#!/bin/sh
# ccraster.sh -- mooncc's codegen against gcc's on lore's rasterizer (raster.c's facets): the
# same frames drawn by out/love (mooncc) and out/love0 (gcc -O2). the sums must agree (a
# divergence is a miscompile); then instructions a frame inside rz_* (rzf.sh: the C alone, the
# love side of a frame left out) and ms a frame (the band). a development instrument, not a gate.
#   ./ccraster.sh [frames]     5 default
set -u
R=$(cd "$(dirname "$0")/.." && pwd)
N=${1:-5}
command -v perf >/dev/null || { echo "ccraster: perf not on PATH" >&2; exit 1; }
run() { # binary reps -> "sum ms"
 RASTER_REPS=$2 LOVE_BUDGET_MB=1024 "$1" "$R/bench/raster.l" 2>&1 | sed -E 's/.*sum ([0-9-]+) ms ([0-9]+).*/\1 \2/'; }
for b in love love0; do
 set -- $(run "$R/out/$b" "$N"); sum=$1 ms=$2
 echo "$b sum $sum rz M/frame $("$R/bench/rzf.sh" "$R/out/$b" "$R/bench/raster.l" RASTER_REPS) ms/frame $ms"
done | tee "$R/out/.ccraster.txt"
s1=$(awk 'NR==1{print $3}' "$R/out/.ccraster.txt"); s2=$(awk 'NR==2{print $3}' "$R/out/.ccraster.txt")
[ "$s1" = "$s2" ] || { echo "ccraster: the sums differ" >&2; exit 1; }
