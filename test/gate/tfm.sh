#!/bin/sh
# test/gate/tfm.sh -- src/apps/tfm.l against TeX Live's own programs, over every TFM installed.
#
# tfm-pl is Knuth's TFtoPL ported section for section, so tftopl is its oracle: the property
# list and the terminal lines, byte for byte. tfm-read is TeX's own font loading (tex.web
# 560-575), so TeX is its oracle: one e-TeX run \font's every file and writes each
# \fontdimen and each code's \fontcharwd/ht/dp/ic as \number, scaled points exactly, at the
# design size, an at size, a scale, and a size past 128pt where TeX scales its multiplier
# down. then the same for copies with a few bytes hit (test/gate/tfm.l's fuzz, seeded), so
# the refusals and tftopl's corrections are held too, not only the files that are fine.
#
# skips where TeX Live is missing; takes the love binary as $1.
set -e

love=${1:-out/love}
[ -x "$love" ] || { echo "tfm: no $love -- run 'make host'"; exit 1; }
for t in tftopl etex kpsewhich; do
  command -v $t >/dev/null 2>&1 || { echo "tfm: no $t (TeX Live), skipped"; exit 0; }
done
r=$(pwd)
L=$r/$love
G=$r/test/gate/tfm.l
tfms=$(kpsewhich -var-value TEXMFDIST)/fonts/tfm
[ -d "$tfms" ] || { echo "tfm: no $tfms, skipped"; exit 0; }

w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL tfm: $*"; exit 1; }

find "$tfms" -name '*.tfm' | LC_ALL=C sort > "$w/all"
n=$(wc -l < "$w/all")
[ "$n" -gt 0 ] || fail "no TFM files under $tfms"

# tfm-pl against tftopl, file by file, both streams
plcheck() {
  list=$1; dir=$2; what=$3
  mkdir -p "$dir"
  "$L" "$G" pl "$list" "$dir" || fail "tfm.l pl died on $what"
  k=0; bad=0
  while read -r f; do
    tftopl "$f" > "$dir/ref.pl" 2> "$dir/ref.msg" || true
    if ! cmp -s "$dir/ref.pl" "$dir/$k.pl" || ! cmp -s "$dir/ref.msg" "$dir/$k.msg"; then
      bad=$((bad + 1))
      [ $bad -le 3 ] && { echo "  differs from tftopl: $f"; diff "$dir/ref.pl" "$dir/$k.pl" | head -5; diff "$dir/ref.msg" "$dir/$k.msg" | head -5; }
    fi
    k=$((k + 1))
  done < "$list"
  [ $bad -eq 0 ] || fail "tfm-pl differs from tftopl on $bad of $k $what"
}

# tfm-read against TeX's loading: one e-TeX run a chunk. TeX stops at a hundred errors and
# a refused \font is one, so a list of bad files goes in ninety at a time
readcheck() {
  list=$1; size=$2; what=$3; chunk=$4
  : > "$w/ref"; : > "$w/ours"
  total=$(wc -l < "$list"); a=1
  while [ $a -le $total ]; do
    b=$((a + chunk - 1))
    sed -n "${a},${b}p" "$list" > "$w/part"
    "$L" "$G" tex "$w/part" "$size" "$w/t.tex" || fail "tfm.l tex died on $what at $size"
    ( cd "$w" && etex -ini -interaction=batchmode -etex t.tex >/dev/null 2>&1 ) || true
    grep -a '^\(F[0-9]*\(:BAD\)\?\|[PC][0-9]*:.*\)$' "$w/t.log" >> "$w/ref" || fail "e-TeX wrote nothing for $what at $size"
    "$L" "$G" read "$w/part" "$size" "$w/o1" || fail "tfm.l read died on $what at $size"
    cat "$w/o1" >> "$w/ours"
    a=$((b + 1))
  done
  if ! cmp -s "$w/ref" "$w/ours"; then
    diff "$w/ref" "$w/ours" | head -8
    fail "tfm-read differs from TeX on $what at size $size"
  fi
}

plcheck "$w/all" "$w/pl" "installed TFMs"
echo "  tfm: tfm-pl = tftopl on all $n installed TFMs"
for z in -1000 478413 -1200 9000000; do readcheck "$w/all" $z "installed TFMs" 100000; done
echo "  tfm: tfm-read = TeX's loading on all $n, at four sizes"

mkdir -p "$w/fz"
"$L" "$G" fuzz "$w/all" "$w/fz" 20260928 400 || fail "tfm.l fuzz died"
ls "$w/fz"/fz*.tfm | LC_ALL=C sort > "$w/fzl"
plcheck "$w/fzl" "$w/fzpl" "hit copies"
readcheck "$w/fzl" -1000 "hit copies" 90
nb=$(grep -c ':BAD$' "$w/ref" || true)
[ "$nb" -gt 100 ] || fail "only $nb of 400 hit copies refused -- the fuzz is too gentle to hold the refusals"
echo "  tfm: 400 hit copies alike, tftopl's corrections and TeX's $nb refusals included"
echo "  tfm: ok"
