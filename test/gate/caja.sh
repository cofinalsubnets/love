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
# paragraphs (apps/caja/par.l, tex.web parts 38-43 and the main loop): test/caja/pars.l says
# its pages as -ini TeX with hyphen.tex's patterns and as caja's tokens, the same way. fixed
# pages pin plain TeX's settings, raggedright, looseness, hanging indentation, \parshape and
# the emergency pass; seeded random pages draw the parameters and the text, which mixes
# English, punctuation, explicit hyphens and discretionaries, penalties, kerns, glue, rules
# and font changes. cajalig (test/caja/cajalig.pl, through pltotf) has every ligature op,
# kerns and both boundary characters.
#
# skips where TeX Live is missing; takes the love binary as $1.
set -e

love=${1:-out/love}
[ -x "$love" ] || { echo "caja: no $love -- run 'make host'"; exit 1; }
for t in tex kpsewhich pltotf; do
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

hy=$(kpsewhich hyphen.tex) || true
[ -n "$hy" ] || { echo "caja: no hyphen.tex, skipped"; exit 0; }
pltotf test/caja/cajalig.pl "$w/cajalig.tfm" >/dev/null 2>&1 || fail "pltotf refused test/caja/cajalig.pl"

# run SCRIPT SEED N ARGS..: the script's pages through TeX and through caja
run() {
  s=$1; seed=$2; n=$3; shift 3
  "$L" test/caja/$s.l "$w/ours" $seed $n "$@" || fail "$s.l died (seed $seed)"
  ( cd "$w" && cp ours.tex t.tex && tex -ini -interaction=batchmode t.tex >/dev/null 2>&1 ) || true
  [ -s "$w/t.dvi" ] || fail "TeX wrote no DVI ($s, seed $seed)"
  cmp -s "$w/t.dvi" "$w/ours.dvi" || {
    cmp "$w/t.dvi" "$w/ours.dvi" || true
    fail "caja's DVI differs from TeX's ($s, seed $seed, $n random pages)"
  }
  rm -f "$w/t.dvi" "$w/ours.dvi"
}

run boxes 1 0 $fonts
run boxes 20260928 600 $fonts
echo "  caja: boxes -- the fixed pages and 600 random ones, DVI identical to TeX's"
run pars 1 0 "$hy" $fonts "$w/cajalig.tfm"
run pars 20260928 400 "$hy" $fonts "$w/cajalig.tfm"
echo "  caja: paragraphs -- the fixed pages and 400 random ones, DVI identical to TeX's"
echo "  caja: ok"
