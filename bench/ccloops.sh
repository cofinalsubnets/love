#!/bin/sh
# ccloops.sh -- mooncc's codegen against gcc's on the loop shapes of bench/loops.c: the
# elementwise, reduction, gather, select and stencil kernels rove's tray math runs through.
# Every kernel's checksum is compared first (a divergence is a miscompile), then each lane
# is read by perf: retired instructions (the meter -- deterministic) and cycles (the band --
# a small loop swings +-25% run to run on layout and cache state). gcc runs twice: -O2, and
# -O2 without the vectorizer, the honest ceiling for a scalar backend. x86-64 only.
#   ./ccloops.sh [reps]          reps of the 4096-element kernel per lane, 2000 default
#   MCC=moon0 ./ccloops.sh       compile through love0 + mooncc0.image (the 4 s gen.l cycle)
# A development instrument, not a gate; the binaries land in out/bench/.
set -u
R=$(cd "$(dirname "$0")/.." && pwd)
D=$R/out/bench
REPS=${1:-2000}
mkdir -p "$D"
[ "$(uname -m)" = x86_64 ] || { echo "ccloops: x86-64 only (mooncc emits x64)" >&2; exit 1; }
command -v perf >/dev/null || { echo "ccloops: perf not on PATH" >&2; exit 1; }
kernels="fadd iadd fsel isel fmask fmin imax fsum isum dot fmaxr all gather map1 floor hash 2d stride bcast poly bytes"
case "${MCC:-image}" in
 moon0) ( cd "$R" && out/love0 wake out/mooncc0.image mooncc -o "$D/loops.moon" bench/loops.c ) ;;
 *)     ( cd "$R" && LOVE_NO_IMAGE= out/love mooncc -o "$D/loops.moon" bench/loops.c ) ;;
esac || { echo "ccloops: mooncc failed" >&2; exit 1; }
gcc -O2 -w -o "$D/loops.gcc" "$R/bench/loops.c" || exit 1
gcc -O2 -w -fno-tree-vectorize -o "$D/loops.gccnv" "$R/bench/loops.c" || exit 1
meter() { # binary kernel -> "insns cycles"
 perf stat -x, -e instructions:u,cycles:u -o "$D/.perf" "$1" "$2" "$REPS" >/dev/null 2>&1
 awk -F, '/instructions/{i=$1} /cycles/{c=$1} END{print i, c}' "$D/.perf"; }
bad=0
for k in $kernels; do
 m=$("$D/loops.moon" "$k" 3); g=$("$D/loops.gcc" "$k" 3)
 [ "$m" = "$g" ] || { echo "$k: DIVERGES  moon=[$m] gcc=[$g]"; bad=1; }
done
printf "%-8s %12s %12s %12s %7s %7s %7s\n" kernel moon-insn gcc-insn moon-cyc i-ratio c-ratio nv-cyc
for k in $kernels; do
 set -- $(meter "$D/loops.moon" "$k"); mi=$1; mc=$2
 set -- $(meter "$D/loops.gcc" "$k"); gi=$1; gc=$2
 set -- $(meter "$D/loops.gccnv" "$k"); nc=$2
 awk -v k="$k" -v mi="$mi" -v gi="$gi" -v mc="$mc" -v gc="$gc" -v nc="$nc" \
  'BEGIN{printf "%-8s %12d %12d %12d %7.2f %7.2f %7.2f\n", k, mi, gi, mc, mi/gi, mc/gc, mc/nc}'
done
exit $bad
