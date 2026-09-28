#!/bin/sh
# test/gate/caja.sh -- caja, TeX's engine in love, held to TeX itself: its DVI byte for byte.
#
# boxes (apps/caja/box.l, tex.web parts 10, 32, 33): test/caja/boxes.l writes the same
# pages twice, as -ini TeX input and as caja's nodes; TeX's DVI and caja's must be the same
# file. the fixed pages each pin a case (glue set both ways and at every order, leaders of
# every kind in both directions, shifted and nested boxes, rules, fonts at sizes, codes past
# 127), then seeded random pages from a small grammar, enough of them that the file passes
# TeX Live's 16384-byte DVI buffer and the w/x/y/z reuse meets its flushed half.
#
# skips where TeX Live is missing; takes the love binary as $1.
set -e

love=${1:-out/love}
[ -x "$love" ] || { echo "caja: no $love -- run 'make host'"; exit 1; }
for t in tex kpsewhich; do
  command -v $t >/dev/null 2>&1 || { echo "caja: no $t (TeX Live), skipped"; exit 0; }
done
r=$(pwd)
L=$r/$love

w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL caja: $*"; exit 1; }

fonts=""
for f in cmr10 cmbx12 cmr10 cmtt10 cmsl9 ecrm1000; do
  p=$(kpsewhich $f.tfm) || true
  [ -n "$p" ] || { echo "caja: no $f.tfm, skipped"; exit 0; }
  fonts="$fonts $p"
done

boxes() {
  seed=$1; n=$2
  "$L" test/caja/boxes.l "$w/ours" $seed $n $fonts || fail "boxes.l died (seed $seed)"
  ( cd "$w" && cp ours.tex t.tex && tex -ini -interaction=batchmode t.tex >/dev/null 2>&1 ) || true
  [ -s "$w/t.dvi" ] || fail "TeX wrote no DVI (seed $seed)"
  cmp -s "$w/t.dvi" "$w/ours.dvi" || {
    cmp "$w/t.dvi" "$w/ours.dvi" || true
    fail "caja's DVI differs from TeX's (seed $seed, $n random pages)"
  }
  rm -f "$w/t.dvi" "$w/ours.dvi"
}

boxes 1 0
boxes 20260928 600
echo "  caja: boxes -- the fixed pages and 600 random ones, DVI identical to TeX's"
echo "  caja: ok"
