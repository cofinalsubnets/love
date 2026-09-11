#!/bin/sh
# t/gate/glass.sh -- the framebuffer console's grid, end to end. a size in REAL pixels and
# a scale go into the machine (i/wasm/arch.c's k_start), and rows and columns come back
# out of winsize (t/kernel/glass.l) after kmain has settled them. what each boot should
# answer is worked out HERE and not read off the kernel, so the law gets two readings: an
# 8x16 face at `scale` pixels a glyph pixel, and the scale itself either the door's or the
# largest that still leaves 80 columns and 24 rows.
# skips whole without node. NOT set -e: each boot reports its own failure with context.
#
# usage: glass.sh NODE MODULE IMAGE LOG
set -u

node=$1
wasm=$2
image=$3
log=$4
name=test_glass
bad=0

# one boot: glass FB SCALE WANT. an empty FB is headless -- no framebuffer, no grid, and
# winsize answers the same nom a host gives for a stdout that is not a tty.
glass() {
  fbarg=""
  [ -n "$1" ] && fbarg="--fb $1"
  scarg=""
  [ -n "$2" ] && scarg="--scale $2"
  INLE_RAM=256 "$node" i/wasm/inle.mjs $fbarg $scarg --image "$image" "$wasm" \
    t/kernel/glass.l < /dev/null > "$log" 2>&1
  got=$(grep '^glass ' "$log" | head -n 1)
  if [ "$got" = "$3" ]; then
    echo "  ${1:-headless}${2:+ scale $2}: $3"
  else
    echo "FAIL $name: ${1:-headless}${2:+ scale $2} answered '$got', wanted '$3'" >&2
    tail -n 5 "$log" >&2
    bad=1
  fi
}

# 1280x800: scale 2 is the largest that still leaves 80 columns (1280/16) and 24 rows
# (800/32 = 25), so the console is the 80x25 a 640x400 screen used to be -- at twice the
# pixels, which is the whole of "sharp".
glass 1280x800 "" "glass 25 80"
# ..and the door may say otherwise: scale 1 is the bitmap as drawn, four times the cells.
glass 1280x800 1 "glass 50 160"
# a 4K screen: scale 5, the last that keeps 24 rows (2160/80 = 27), for 3840/40 = 96
# columns. the old law would have answered 480x135 cells of 8x16 text -- a screen nobody
# can read, and what every metal seat on a dense framebuffer got.
glass 3840x2160 "" "glass 27 96"
glass "" "" "glass none enotty"

[ $bad = 0 ] || exit 1
echo "  glass: ok -- real pixels in, rows and columns out"
