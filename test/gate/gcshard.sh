#!/bin/sh
# test/gate/gcshard.sh -- the corpus on the stress runtime, cut into N slices a half, each
# between the harness and zz-fin. the cut is contiguous, balanced by one marked normal run.
# each shard passes on the normal build first, carrying the file that binds a name it misses,
# and the shards' counts sum to the full run's; then each stress shard answers its normal
# count. the baked half wakes the normal bake's image, or with GCS_BAKE=1 a stress bake,
# whose heap must be the normal one's. $w/cost holds each file's time under stress.
# usage: gcshard.sh TREE [SHARDS]   SHARDS a half (GCS_SHARDS, default 4); GCS_NOBUILD=1 runs
# the binaries TREE already has; GCS_HSUF the stress build's out suffix (default /gcs);
# MAKE the tree's make; GCS_BAKE=1 the stress bake, this script's own. the normal build
# is the caller's (the lanes' prerequisites, `host love0 out/mooncc0.image`)
set -u
[ $# -ge 1 ] || { echo "usage: gcshard.sh TREE [SHARDS]"; exit 2; }
cd "$1" || exit 2
n=${2:-${GCS_SHARDS:-4}}
gs=${GCS_HSUF-/gcs}
sbake=${GCS_BAKE:-0}
w=out/gcshard
esc=$(printf '\033')
# a failure stops the bakes still running (each keeps its love's pid)
fail() { echo "FAIL gcshard: $*"; for b in bs bn; do [ -s $w/$b/pid ] && kill $(cat $w/$b/pid) 2>/dev/null; done; exit 1; }
rm -rf $w
t0=$(date +%s)
el() { echo "gcshard: $1 ($(( $(date +%s) - t0 )) s)"; }

if [ -z "${GCS_NOBUILD:-}" ]; then
  # only the stress builds: a make of host here relinks out/love under the other lanes
  ${MAKE:-make} --no-print-directory hsuf=$gs GCDBG=-DLvGcStress out$gs/love.raw out$gs/.dist-cat.l || fail "the stress runtime"
  ${MAKE:-make} --no-print-directory out/gcs0/love0 out/lib/corpus.list || fail "the stress love0"
  el built
fi
for b in out/love out/love.raw out$gs/love.raw out/gcs0/love0; do [ -x $b ] || fail "no $b"; done
for b in out/.dist-cat.l out$gs/.dist-cat.l; do [ -s $b ] || fail "no $b"; done
mkdir -p $w/bn $w/bs
# each stress build is one: a build that drops LvGcStress passes as a normal one, blind.
# under stress every have collects, so a small walk counts its collections in the many thousands
ng='(: _ (map (x \ [x x]) ^2000) ((gauge 0) 3))'
gcn() { env LOVE_NO_IMAGE=1 "$1" -e "$ng" 2>/dev/null | tail -1; }
n0=$(gcn out/love0); n1=$(gcn out/love.raw)
for b in out/gcs0/love0 out$gs/love.raw; do
  ns=$(gcn $b); [ $b = out/gcs0/love0 ] && nn=$n0 || nn=$n1
  [ -n "$ns" ] && [ -n "$nn" ] && [ "$ns" -gt $((100 * nn + 1000)) ] \
    || fail "$b collects $ns times on a small walk, the normal build $nn: not a stress build"
done

# a background run: $w/TAG.out and $w/TAG.rc. wt waits for the runs, never the bakes
ps=
job() { tg=$1; shift; ( "$@" > $w/$tg.out 2>&1 < /dev/null; echo $? > $w/$tg.rc ) & ps="$ps $!"; }
wt() { for p in $ps; do wait $p; done; ps=; }
# a bake as the Makefile's, to love.img in its own dir: the bake keeps the path it writes
hot=$PWD/src/tools/hot.prof calls=$(sh src/tools/hotbake.sh -k)
bake() { ( cd $w/$1 && { env LOVE_NO_IMAGE=1 LOVE_BAKE_HOT=$hot LOVE_BAKE_CALLS="$calls" "$2" bake -l "$3" love.img > out 2>&1 < /dev/null &
                         echo $! > pid; wait $!; echo $? > rc; } ) & }
[ "$sbake" = 1 ] && { bake bs $PWD/out$gs/love.raw $PWD/out$gs/.dist-cat.l; bsp=$!; }
# the stress love0 beside the bakes: its boot, then both its passes -- c0, then the egg it
# bootstraps -- over the harness and one file. its whole corpus is test_gcstress_full's (hours)
mkdir -p $w/l0/out/lib
ln -s $PWD/test $w/l0/test; ln -s $PWD/src $w/l0/src
printf './test/00-init.l ./test/spec.l ./test/uu.l ./test/bell.l ./test/zz-fin.l' > $w/l0/out/lib/corpus.list
l0=$PWD/out/gcs0/love0; ( cd $w/l0 && { $l0 > run.log 2>&1 < /dev/null; echo $? > rc; } ) & l0p=$!
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
  -e '/glaze-x86\.l$' -e '/glaze-hook\.l$' -e '/glaze-tail\.l$' -e '/zz-fin\.l$' > $w/rest
mark='(do (putc 10) (puts "@@gcshard ") (putx (clock test_t0)) (putc 10))'
{ cat $pre; for f in $(cat $w/rest); do cat $f; echo; echo "$mark"; done; cat $fin; } > $w/timed.l
cat $pre $(cat $w/rest) $fin > $w/full.l
cat $pre $fin > $w/pre.l

# the full corpus (the baked half marked between files), and the harness alone
job fb out/love $w/timed.l; job fe $egg out/love.raw $w/full.l
job pb out/love $w/pre.l; job pe $egg out/love.raw $w/pre.l
# a native hashes by its seat in the image, not its address: the two builds lay code apart
dg='(putx (map dig [negate cup atom? fraction]))'
job dgn $egg out/love.raw -e "$dg"; job dgs $egg out$gs/love.raw -e "$dg"
wt
[ "$(cat $w/dgn.out)" = "$(cat $w/dgs.out)" ] || fail "a native hashes apart in the normal and stress builds"
for h in b e; do ok f$h "the full corpus on the normal build ($h)"; ok p$h "the harness alone ($h)"; done
sed -n 's/^@@gcshard \([0-9][0-9]*\)$/\1/p' $w/fb.out > $w/clock
[ $(wc -l < $w/clock) -eq $(wc -l < $w/rest) ] || fail "the marked run lost a mark"
# contiguous slices with the least longest one, each file weighed by its baked stress ms in
# test/gate/gcshard.cost (a past run's $w/cost, copied in by hand), or else its normal clock
# times the table's median stress/normal ratio: the least cap that n greedy slices hold
paste -d ' ' $w/clock $w/rest | awk -v n=$n -v tab=test/gate/gcshard.cost '
  BEGIN { while ((getline l < tab) > 0) { split(l, p, " "); if (p[3] != "") s[p[3]] = p[2] } }
  { c[NR] = $1; f[NR] = $2; d[NR] = NR > 1 ? $1 - c[NR - 1] : $1 }
  function fits(t,   i, k, a) { k = 0; a = 0
    for (i = 1; i <= NR; i++) { if (a > 0 && a + w[i] > t) { k++; a = 0 } a += w[i] }
    return k < n }
  END { m = 0
    for (i = 1; i <= NR; i++) if ((f[i] in s) && d[i] > 0) { r[++m] = s[f[i]] / d[i]
      for (j = m; j > 1 && r[j - 1] > r[j]; j--) { x = r[j]; r[j] = r[j - 1]; r[j - 1] = x } }
    q = m ? r[int((m + 1) / 2)] : 1; W = 0; mx = 0
    for (i = 1; i <= NR; i++) { w[i] = (f[i] in s) ? s[f[i]] : d[i] * q; W += w[i]; if (w[i] > mx) mx = w[i] }
    lo = mx; hi = W
    while (hi - lo > 1) { t = int((lo + hi) / 2); if (fits(t)) hi = t; else lo = t }
    k = 0; a = 0
    for (i = 1; i <= NR; i++) { if (a > 0 && a + w[i] > hi && k < n - 1) { k++; a = 0 } a += w[i]; print k, f[i] } }' > $w/cut
el "the full corpus and the cut"

# a shard: the harness, its carried files, its slice, zz-fin
# ..and its marked twin, a mark behind each slice file, which the stress runs take
lay() { cat $pre $(cat $w/c$1) $(awk -v k=$1 '$1 == k { print $2 }' $w/cut) $fin > $w/s$1.l
        { cat $pre $(cat $w/c$1); for f in $(awk -v k=$1 '$1 == k { print $2 }' $w/cut); do cat $f; echo; echo "$mark"; done
          cat $fin; } > $w/m$1.l; }
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

# the egg half runs while the bakes do; the baked half wakes its bake's image
i=0
while [ $i -lt $n ]; do job se$i $egg out$gs/love.raw $w/m$i.l; i=$((i + 1)); done
if [ "$sbake" = 1 ]; then
  wait $bsp
  [ "$(cat $w/bs/rc)" = 0 ] && [ -s $w/bs/love.img ] || { tail -5 $w/bs/out; fail "the stress bake"; }
  el "the stress bake"
  im=$w/bs/love.img
fi
wait $bnp
[ "$(cat $w/bn/rc)" = 0 ] && [ -s $w/bn/love.img ] || { tail -5 $w/bn/out; fail "the normal bake"; }
[ "$sbake" = 1 ] || { im=$w/bn/love.img; el "the normal bake"; }
# the image answers on the stress runtime -- woken, not an egg boot
sm=$w/sm; ( out$gs/love.raw wake $im -e '(? (elem (quote love-image) (names ())) 42 0)' > $sm.out 2>&1 < /dev/null
            echo $? > $sm.rc )
[ "$(cat $sm.rc)" = 0 ] && [ "$(cat $sm.out)" = 42 ] || { say sm; fail "the stress runtime's smoke run of $im"; }
i=0
while [ $i -lt $n ]; do job sb$i out$gs/love.raw wake $im $w/m$i.l; i=$((i + 1)); done
# ..and the stress image's heap is the normal one's: every global but cmdline, in name
# order, each behind its own `@@ NAME` line
canon='(map (n \ (, (puts "@@ ") (puts (show n)) (putc 10) (puts (show (ev n))) (putc 10))) (sort (filter (n \ n != (quote cmdline)) (names ()))))'
digest() { ( cd $1 && "$2" wake love.img -e "$canon" ); }
[ "$sbake" = 1 ] && { job dn digest $w/bn $PWD/out/love.raw; job ds digest $w/bs $PWD/out$gs/love.raw; }
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
# each file's ms under stress, egg then baked, costliest first
for h in e b; do
  i=0
  while [ $i -lt $n ]; do
    awk -v k=$i '$1 == k { print $2 }' $w/cut > $w/f$i
    sed -n 's/^@@gcshard \([0-9][0-9]*\)$/\1/p' $w/s$h$i.out | awk 'NR == 1 { p = 0 } { print $1 - p; p = $1 }' | paste -d ' ' - $w/f$i
    i=$((i + 1))
  done > $w/cost$h
done
awk 'NR == FNR { e[$2] = $1; next } { print e[$2], $1, $2 }' $w/coste $w/costb | sort -k2 -rn > $w/cost
echo "gcshard: the costliest under stress (egg ms, baked ms): $(head -3 $w/cost | awk '{ printf "%s %s %s; ", $3, $1, $2 }')"
if [ "$sbake" = 1 ]; then
  for d in dn ds; do [ "$(cat $w/$d.rc)" = 0 ] && [ -s $w/$d.out ] || { say $d; fail "the $d digest"; }; done
  cmp -s $w/dn.out $w/ds.out \
    || fail "the stress image's heap differs from the normal one's, in: $(awk 'FNR == 1 { f++ } /^@@ / { n = $2; k[n] = 1; next }
                                      { v[f, n] = v[f, n] $0 "\n" } END { for (n in k) if (v[1, n] != v[2, n]) print n }' \
                                      $w/dn.out $w/ds.out | sort | head -8 | tr '\n' ' ')"
  el "the stress image: it answers, and its heap is the normal image's"
fi
# the stress love0: both passes of its small corpus, each answering in full
wait $l0p
[ "$(cat $w/l0/rc)" = 0 ] && [ "$(grep -c 'tests pass' $w/l0/run.log)" = 2 ] \
  || { sed "s/$esc\[32m\.$esc\[0m//g" $w/l0/run.log | tail -15; fail "the stress love0"; }
el "the stress love0: boot, c0 and the egg over its small corpus"
echo "gcshard: ok"
