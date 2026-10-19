#!/bin/sh
# test/gate/l0stress.sh -- the stress love0 over the whole corpus: c0's pass, the egg it
# bootstraps, then the egg's pass, each answering the normal love0's count (hours)
# usage: l0stress.sh TREE   from the tree's root, with out/love0, out/gcs0/love0 and out/lib/corpus.list
set -u
[ $# -ge 1 ] || { echo "usage: l0stress.sh TREE"; exit 2; }
cd "$1" || exit 2
w=out/l0stress
esc=$(printf '\033')
fail() { echo "FAIL l0stress: $*"; exit 1; }
for b in out/love0 out/gcs0/love0; do [ -x $b ] || fail "no $b"; done
[ -s out/lib/corpus.list ] || fail "no out/lib/corpus.list"
rm -rf $w; mkdir -p $w
t0=$(date +%s)
LOVE_NO_IMAGE= out/love0 > $w/n.out 2>&1 < /dev/null; echo $? > $w/n.rc
LOVE_NO_IMAGE= out/gcs0/love0 > $w/s.out 2>&1 < /dev/null; echo $? > $w/s.rc
cnts() { sed -n 's/^\([0-9][0-9]*\) tests pass in .*/\1/p' $w/$1.out | tr '\n' ' '; }
say() { sed "s/$esc\[32m\.$esc\[0m//g" $w/$1.out | grep -v '^$' | tail -15; }
for h in n s; do
  [ "$(cat $w/$h.rc)" = 0 ] && [ $(grep -c 'tests pass' $w/$h.out) = 2 ] || { say $h; fail "the $h love0's two passes"; }
done
[ "$(cnts s)" = "$(cnts n)" ] || fail "the stress love0 counts $(cnts s), the normal $(cnts n)"
echo "l0stress: ok, both passes $(cnts s)($(( $(date +%s) - t0 )) s)"
