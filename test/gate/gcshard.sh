#!/bin/sh
# test/gate/gcshard.sh -- test_gcstress in shards, on any tree: the corpus cut into N slices a
# half, each slice behind the harness (00-init spec uu) and before zz-fin, on the stress runtime
# (hsuf=/gcs GCDBG=-DLvGcStress). the stress bake is its own job, started first: the cut, the
# normal shards and the egg half's stress shards run beside it, and the baked half's shards wake
# its image once it lands. the bake passes when its image answers and its heap, shown name by
# name, is the normal bake's -- an image does not depend on when collections fall.
# the cut is contiguous and balanced by each file's time on the normal build, read off one
# marked run of the whole corpus. a shard first passes on the normal build: the corpus is one
# scope, so a file that leans on an earlier file's binding (`;; missing NAME`, uu's
# `;; uu-unbound NAME`) carries the file that binds it, right after the harness. the normal
# shards' counts, less the harness's and the carried files' own, sum to the full run's, so a
# cut that drops an assert shows; each stress shard then answers its normal count.
#
# usage: gcshard.sh TREE [SHARDS]   SHARDS a half (GCS_SHARDS, default 4); GCS_NOBUILD=1 runs
# the binaries TREE already has; GCS_HSUF names the stress build's out suffix (default /gcs);
# MAKE the tree's make (make). the stress runtime is out$GCS_HSUF/love.raw: its bake is this
# script's, never the Makefile's
set -u
[ $# -ge 1 ] || { echo "usage: gcshard.sh TREE [SHARDS]"; exit 2; }
cd "$1" || exit 2
n=${2:-${GCS_SHARDS:-4}}
gs=${GCS_HSUF-/gcs}
w=out/gcshard
esc=$(printf '\033')
# a failure stops the bakes still running (each keeps its love's pid)
fail() { echo "FAIL gcshard: $*"; for b in bs bn; do [ -s $w/$b/pid ] && kill $(cat $w/$b/pid) 2>/dev/null; done; exit 1; }
rm -rf $w
t0=$(date +%s)
el() { echo "gcshard: $1 ($(( $(date +%s) - t0 )) s)"; }

if [ -z "${GCS_NOBUILD:-}" ]; then
  ${MAKE:-make} --no-print-directory host love0 out/mooncc0.image out/love.raw || fail "the normal build"
  ${MAKE:-make} --no-print-directory hsuf=$gs GCDBG=-DLvGcStress out$gs/love.raw out$gs/.dist-cat.l || fail "the stress runtime"
  el built
fi
for b in out/love out/love.raw out$gs/love.raw; do [ -x $b ] || fail "no $b"; done
for b in out/.dist-cat.l out$gs/.dist-cat.l; do [ -s $b ] || fail "no $b"; done
mkdir -p $w/bn $w/bs

# one run in the background: its output in $w/TAG.out, its status in $w/TAG.rc; wt waits for
# the runs job started, never the bakes
ps=
job() { tg=$1; shift; ( "$@" > $w/$tg.out 2>&1 < /dev/null; echo $? > $w/$tg.rc ) & ps="$ps $!"; }
wt() { for p in $ps; do wait $p; done; ps=; }
# a bake as the Makefile's (hotbake.sh), to a plain image file: the same relative name in its
# own directory, since the bake keeps the path it writes
hot=$PWD/src/tools/hot.prof
bake() { ( cd $w/$1 && { env LOVE_NO_IMAGE=1 LOVE_BAKE_HOT=$hot "$2" bake -l "$3" love.img > out 2>&1 < /dev/null &
                         echo $! > pid; wait $!; echo $? > rc; } ) & }
bake bs $PWD/out$gs/love.raw $PWD/out$gs/.dist-cat.l; bsp=$!
bake bn $PWD/out/love.raw $PWD/out/.dist-cat.l; bnp=$!
cnt() { sed -n 's/^\([0-9][0-9]*\) tests pass in .*/\1/p' $w/$1.out | tail -1; }
# a failed run's tail, its green dots dropped
say() { sed "s/$esc\[32m\.$esc\[0m//g" $w/$1.out | grep -v '^$' | tail -15; }
ok() { [ "$(cat $w/$1.rc)" = 0 ] && [ -n "$(cnt $1)" ] || { say $1; fail "$2"; }; }
egg="env LOVE_NO_IMAGE=1"

# the corpus as test.mk's $t lays it: the harness, then the rest in byte order, zz-fin last
pre="test/00-init.l test/spec.l test/uu.l"
fin=test/zz-fin.l
ls test/*.l | LC_ALL=C sort | grep -v -e '/00-init\.l$' -e '/spec\.l$' -e '/uu\.l$' \
  -e '/glaze-x86\.l$' -e '/glaze-hook\.l$' -e '/zz-fin\.l$' > $w/rest
mark='(do (putc 10) (puts "@@gcshard ") (putx (clock test_t0)) (putc 10))'
{ cat $pre; for f in $(cat $w/rest); do cat $f; echo; echo "$mark"; done; cat $fin; } > $w/timed.l
cat $pre $(cat $w/rest) $fin > $w/full.l
cat $pre $fin > $w/pre.l

# the full corpus (the baked half marked between files), and the harness alone
job fb out/love $w/timed.l; job fe $egg out/love.raw $w/full.l
job pb out/love $w/pre.l; job pe $egg out/love.raw $w/pre.l
wt
for h in b e; do ok f$h "the full corpus on the normal build ($h)"; ok p$h "the harness alone ($h)"; done
sed -n 's/^@@gcshard \([0-9][0-9]*\)$/\1/p' $w/fb.out > $w/clock
[ $(wc -l < $w/clock) -eq $(wc -l < $w/rest) ] || fail "the marked run lost a mark"
# contiguous slices balanced by time: a file goes to the slice its running total falls in
paste -d ' ' $w/clock $w/rest | awk -v n=$n '{ c[NR] = $1; f[NR] = $2 }
  END { t = c[NR] - c[1] + 1; for (i = 1; i <= NR; i++) { k = int((c[i] - c[1]) * n / t); if (k >= n) k = n - 1; print k, f[i] } }' > $w/cut
el "the full corpus and the cut"

# a shard: the harness, its carried files, its slice, zz-fin
lay() { cat $pre $(cat $w/c$1) $(awk -v k=$1 '$1 == k { print $2 }' $w/cut) $fin > $w/s$1.l; }
# the earliest corpus file that binds NAME at the head of a line: a letrec's, a define's, uu's (defn ..)
binder() { for f in $(cat $w/rest); do
             awk -v nm="$1" 'function at(s) { if (index(s, nm) != 1) return 0; c = substr(s, length(nm) + 1, 1); return c == " " || c == "\t" || c == ")" || c == "" }
               { s = $0; sub(/^[ \t]*\(?/, "", s); d = s; sub(/^def[a-z]* +/, "", d)
                 if (at(s) || d != s && at(d)) { x = 1; exit } }
               END { exit !x }' $f && { echo $f; return; }
           done; }
i=0
while [ $i -lt $n ]; do : > $w/c$i; lay $i; i=$((i + 1)); done
for h in b e; do
  [ $h = b ] && L=out/love || L="$egg out/love.raw"
  i=0
  while [ $i -lt $n ]; do job n$h$i $L $w/s$i.l; i=$((i + 1)); done
done
wt
# a shard that misses a binding carries its binder and runs again, both halves
i=0
while [ $i -lt $n ]; do
  r=0
  while ! { [ "$(cat $w/nb$i.rc)" = 0 ] && [ "$(cat $w/ne$i.rc)" = 0 ]; }; do
    r=$((r + 1)); [ $r -le 8 ] || break
    nm=$(cat $w/nb$i.out $w/ne$i.out | sed -n 's/.*;; \(missing\|uu-unbound\) \([^ ]*\).*/\2/p' | head -1)
    [ -n "$nm" ] || break
    f=$(binder "$nm"); [ -n "$f" ] || break
    grep -qx "$f" $w/c$i && break
    echo $f >> $w/c$i; lay $i
    echo "gcshard: shard $i carries $f (it binds $nm)"
    job nb$i out/love $w/s$i.l; job ne$i $egg out/love.raw $w/s$i.l; wt
  done
  i=$((i + 1))
done
# the carried files' own counts, a shard's harness and carries alone
i=0
while [ $i -lt $n ]; do
  [ -s $w/c$i ] && { cat $pre $(cat $w/c$i) $fin > $w/k$i.l; job kb$i out/love $w/k$i.l; job ke$i $egg out/love.raw $w/k$i.l; }
  i=$((i + 1))
done
wt
for h in b e; do
  sum=0; i=0
  while [ $i -lt $n ]; do
    ok n$h$i "shard $i on the normal build ($h)"
    sum=$((sum + $(cnt n$h$i) - $(cnt p$h)))
    [ -s $w/c$i ] && { ok k$h$i "shard $i's carried files alone ($h)"; sum=$((sum - $(cnt k$h$i) + $(cnt p$h))); }
    i=$((i + 1))
  done
  [ $((sum + $(cnt p$h))) -eq $(cnt f$h) ] \
    || fail "half $h: the shards count $((sum + $(cnt p$h))) past the harness and carries, the full run $(cnt f$h)"
  echo "gcshard: half $h: $n shards sum to the full run's $(cnt f$h)"
done
el "the shards on the normal build"

# the stress runtime's egg half wakes no image, so its shards run while the stress bake does;
# the baked half waits for the bake and wakes its image -- an image wakes only on the binary
# that baked it
i=0
while [ $i -lt $n ]; do job se$i $egg out$gs/love.raw $w/s$i.l; i=$((i + 1)); done
wait $bsp
[ "$(cat $w/bs/rc)" = 0 ] && [ -s $w/bs/love.img ] || { tail -5 $w/bs/out; fail "the stress bake"; }
el "the stress bake"
# the bake passes when its image answers on the stress runtime -- woken, not an egg boot
sm=$w/sm; ( out$gs/love.raw wake $w/bs/love.img -e '(? (elem (quote love-image) (names ())) 42 0)' > $sm.out 2>&1 < /dev/null
            echo $? > $sm.rc )
[ "$(cat $sm.rc)" = 0 ] && [ "$(cat $sm.out)" = 42 ] || { say sm; fail "the stress image's smoke run"; }
i=0
while [ $i -lt $n ]; do job sb$i out$gs/love.raw wake $w/bs/love.img $w/s$i.l; i=$((i + 1)); done
# ..and its heap is the normal bake's: each image woken by its own runtime, every global but the
# runtime's own cmdline shown in name order. both bake as love.img, so the path they keep agrees
wait $bnp
[ "$(cat $w/bn/rc)" = 0 ] && [ -s $w/bn/love.img ] || { tail -5 $w/bn/out; fail "the normal bake"; }
# each global behind its own `@@ NAME` line, since a shown value may span lines
canon='(map (n \ (, (puts "@@ ") (puts (show n)) (putc 10) (puts (show (ev n))) (putc 10))) (sort (filter (n \ n != (quote cmdline)) (names ()))))'
digest() { ( cd $1 && "$2" wake love.img -e "$canon" ); }
job dn digest $w/bn $PWD/out/love.raw; job ds digest $w/bs $PWD/out$gs/love.raw
wt
for h in b e; do
  i=0
  while [ $i -lt $n ]; do
    ok s$h$i "shard $i under stress ($h)"
    [ "$(cnt s$h$i)" = "$(cnt n$h$i)" ] || fail "shard $i ($h): $(cnt s$h$i) under stress, $(cnt n$h$i) normal"
    i=$((i + 1))
  done
done
el "the stress runtime: $n shards a half, both halves, each its normal count"
for d in dn ds; do [ "$(cat $w/$d.rc)" = 0 ] && [ -s $w/$d.out ] || { say $d; fail "the $d digest"; }; done
cmp -s $w/dn.out $w/ds.out \
  || fail "the stress image's heap differs from the normal one's, in: $(awk 'FNR == 1 { f++ } /^@@ / { n = $2; k[n] = 1; next }
                                    { v[f, n] = v[f, n] $0 "\n" } END { for (n in k) if (v[1, n] != v[2, n]) print n }' \
                                    $w/dn.out $w/ds.out | sort | head -8 | tr '\n' ' ')"
el "the stress image: it answers, and its heap is the normal image's"
echo "gcshard: ok"
