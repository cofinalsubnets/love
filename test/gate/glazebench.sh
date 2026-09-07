#!/bin/sh
# test/gate/glazebench.sh -- the glaze pays on the benches, through the lanes a user runs.
#
# every other glaze gate hands `(ev '..)` a form it spelled itself, so two things passed a
# green test_slow: the driver evaluating through the egg's interpreter (post.l's stream
# shell calling ev directly, which is baked before the glaze rebinds it), and a bench
# spelled in a way the recognizers do not read ((re ~ im) once the twin sigil moved).
# so this runs the bench sources AS SPELLED -- bench/bench.l + bench/benches/<b>.l, the
# cat `make bench` runs -- glazed and under LOVE_NO_GLAZE=1, by stdin and by file in
# turn, and holds each ratio to a floor set near a third of the healthy speedup. the two
# runs are back to back on one machine, so load cancels; only the ratio is read. a driver
# on the egg's interpreter reads as x1 on every row, and so does a LOVE_NO_GLAZE that stopped
# switching anything off -- either is a red, not a quiet table.
#
# usage: sh test/gate/glazebench.sh LOVE ARCH
set -u
love=${1:-out/love} arch=${2:-x64}
d=out/.glazebench && mkdir -p $d
[ -d bench/benches ] || { echo "glazebench: skipped (no bench/ in this tree)"; exit 0; }
fails=0

# <bench> <floor>: the glazed run must be at least <floor> times faster than LOVE_NO_GLAZE=1.
# the float-grid (mandelbrot) and cask-fill (strcat) lanes emit for x64 only.
# measured 2026-09-07 on x64: fib x12 tak x9 deforest x36 primes x16 strscan x10 hash x3.5 tree x7
# bintrees x7 closure x84 mandelbrot x165 strcat x49 -- the floors sit near a third. hash and
# bintrees run low because the amble's restart law declines their `(+ acc (f x))` loops.
roster='fib 4 tak 3 deforest 12 primes 5 strscan 3 hash 2 tree 2.5 bintrees 2 closure 25'
[ $arch = x64 ] && roster="$roster mandelbrot 50 strcat 15"

msit() {  # <lane> <bench> <env words..> -> the bench's ms per iteration through that lane
  lane=$1 b=$2; shift 2
  if [ $lane = stdin ]; then
    cat bench/bench.l bench/benches/$b.l | BENCH_LANG=love "$@" "$love" 2>/dev/null
  else
    cat bench/bench.l bench/benches/$b.l > $d/$b.l
    BENCH_LANG=love "$@" "$love" $d/$b.l </dev/null 2>/dev/null
  fi | awk 'NF == 5 { printf "%.4f", $4 / $3 }'
}

lane=stdin
set -- $roster
while [ $# -ge 2 ]; do
  b=$1 floor=$2; shift 2
  g=$(msit $lane $b env)
  i=$(msit $lane $b env LOVE_NO_GLAZE=1)
  ok=$(awk -v g="$g" -v i="$i" -v f="$floor" 'BEGIN { print (g > 0 && i > 0 && g * f <= i) ? 1 : 0 }')
  ratio=$(awk -v g="$g" -v i="$i" 'BEGIN { if (g > 0 && i > 0) printf "%.1f", i / g; else print "-" }')
  printf '  %-11s %-5s glazed %9s  interp %9s  x%-6s floor %s%s\n' $b $lane "${g:-none}" "${i:-none}" "$ratio" "$floor" "$([ $ok = 1 ] || echo '  FAIL')"
  [ $ok = 1 ] || fails=$((fails+1))
  if [ $lane = stdin ]; then lane=file; else lane=stdin; fi
done

[ $fails -eq 0 ] || { echo "FAIL glazebench: $fails lane(s) below the floor -- the glaze is not paying where it did"; exit 1; }
echo "glazebench: ok -- the benches glaze through the driver, as spelled"
