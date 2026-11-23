#!/bin/sh
# rzf.sh -- instructions a frame inside rz_*, in millions: a 22-frame run less a 2-frame run,
# sampled every million and summed over the rz_ symbols, over 20. the one definition ccmeter's
# raster row and ccraster both read
#   ./rzf.sh binary script var     var is the env name the script takes its frame count by
set -u
R=$(cd "$(dirname "$0")/.." && pwd)
W=$R/out/ccmeter
mkdir -p "$W"
for n in 2 22; do
 env "$3=$n" LOVE_THREADS=1 perf record -q -e instructions:u -c 1000000 -o "$W/rz.data" "$1" "$2" > /dev/null 2>&1
 perf report -i "$W/rz.data" --stdio --sort sym -q -n 2>/dev/null | awk '$NF ~ /^rz_/ {s += $2} END {print s + 0}' > "$W/rz-$n"
done
echo $(( ($(cat "$W/rz-22") - $(cat "$W/rz-2")) / 20 ))
