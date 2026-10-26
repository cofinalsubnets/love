#!/bin/sh
# test/gate/caja.sh -- caja, TeX's engine in love, held to TeX's DVI byte for byte.
# each script writes its pages twice, as -ini TeX input and as caja's own: boxes.l (fixed
# cases, then enough seeded pages to pass TeX's 16 KiB DVI buffer), pars.l (paragraphs with
# hyphen.tex; cajalig.pl has every ligature op), and docs.l (the tree's markdown and a few
# man pages, paged by \vsplit). skips without TeX Live.
# usage: caja.sh LOVE
. test/gate/skip.sh
set -e

love=${1:-out/love}
[ -x "$love" ] || { echo "caja: no $love -- run 'make host'"; exit 1; }
for t in tex kpsewhich pltotf; do
  command -v $t >/dev/null 2>&1 || gate_skip "caja: no $t (TeX Live), skipped"
done
r=$(pwd)
L=$r/$love

w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL caja: $*"; exit 1; }

fonts=""
for f in cmr10 cmbx12 cmr10 cmtt10 cmsl9 ecrm1000; do
  p=$(kpsewhich $f.tfm) || true
  [ -n "$p" ] || gate_skip "caja: no $f.tfm, skipped"
  fonts="$fonts $p"
done

hy=$(kpsewhich hyphen.tex) || true
[ -n "$hy" ] || gate_skip "caja: no hyphen.tex, skipped"
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

# the macro language: test/caja/initex's jobs through tex -ini and caja at tripman's line
# lengths, each log held to TeX's from its second line (the first is the banner and the date)
tdirs=""
for f in cmr10 cmbx12 cmtt10 cmsl10; do
  p=$(kpsewhich $f.tfm) || true
  [ -n "$p" ] || gate_skip "caja: no $f.tfm, skipped"
  tdirs="$tdirs:$(dirname "$p")"
done
i=$w/initex
jobs=""
for f in test/caja/initex/*.tex; do
  n=$(basename "$f" .tex)
  for s in tex caja; do mkdir -p "$i/$s/$n" && cp "$f" test/caja/initex/files/*.tex "$i/$s/$n/"; done
  ( cd "$i/tex/$n" && max_print_line=72 error_line=64 half_error_line=32 \
      tex -ini -interaction=batchmode $n.tex >/dev/null 2>&1 ) || true
  [ -s "$i/tex/$n/$n.log" ] || fail "TeX wrote no log for initex/$n"
  jobs="$jobs $i/caja/$n"
done
"$L" test/caja/initex.l "$r" "${tdirs#:}" $jobs || fail "initex.l died"
ni=0
for d in $jobs; do
  n=$(basename "$d")
  tail -n +2 "$i/tex/$n/$n.log" > "$i/t.log"; tail -n +2 "$d/$n.log" > "$i/c.log"
  cmp -s "$i/t.log" "$i/c.log" || { diff "$i/t.log" "$i/c.log" | head -20; fail "caja's log differs from TeX's (initex/$n)"; }
  ni=$((ni + 1))
done
echo "  caja: macros -- $ni jobs through -ini TeX's mouth and stomach, logs identical to TeX's"

dfonts=""
for f in cmr10 cmbx10 cmti10 cmtt10 cmbx12 cmbx12 cmsy10; do
  p=$(kpsewhich $f.tfm) || true
  [ -n "$p" ] || gate_skip "caja: no $f.tfm, documents skipped"
  dfonts="$dfonts $p"
done
# doc FILE: one document through the shower and through TeX
doc() {
  "$L" test/caja/docs.l "$w/doc" "$hy" $dfonts "$1" || fail "docs.l died on $1"
  ( cd "$w" && cp doc.tex d.tex && rm -f d.dvi && tex -ini -interaction=batchmode d.tex >/dev/null 2>&1 ) || true
  [ -s "$w/d.dvi" ] || fail "TeX wrote no DVI for $1"
  cmp -s "$w/d.dvi" "$w/doc.dvi" || { cmp "$w/d.dvi" "$w/doc.dvi" || true; fail "caja's DVI differs from TeX's on $1"; }
}
# the tree's own listing: an empty one is a refusal, never a pass
mds=$("$L" src/tools/selfpack.l -l | grep '\.md$')
[ -n "$mds" ] || fail "no markdown files listed (src/tools/selfpack.l -l)"
nd=0
for f in $mds; do doc "$f"; nd=$((nd + 1)); done
for m in ls grep tar sed gzip make; do
  [ -f /usr/share/man/man1/$m.1.gz ] || continue
  gzip -dc /usr/share/man/man1/$m.1.gz > "$w/$m.1" && doc "$w/$m.1" && nd=$((nd + 1))
done
echo "  caja: documents -- $nd markdown files and man pages, laid out and paged, DVI identical to TeX's"
echo "  caja: ok"
