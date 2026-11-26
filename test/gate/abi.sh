#!/bin/sh
# test/gate/abi.sh -- calls between mooncc and gcc, clang on x64, i386 or a64, both ways, by test/cc/abi/gen.l.
# the peers linked by theirs (glibc) and one set by ours (moonlibc); objects call f*, ck and keep only.
# every binary is linked first and run as one batch: here, or for a64 on an a64 host, else qemu (a64run.sh).
# what mooncc is known to do otherwise is TARGET.expect, held line for line: a new one or a lost one is red.
# usage: abi.sh OUTDIR LOVE TARGET [N] [SEED]
. test/gate/skip.sh
set -u

ho=$1 m=$2 t=$3 n=${4:-200} seed=${5:-1}
src=test/cc/abi d=$1/abi-$t
case $t in
  x64) name=test_abi gcc=gcc clang=clang ld="gcc -no-pie" nm=nm tf= ;;
  i386) name=test_abi_i386 gcc="gcc -m32" clang="clang -m32" ld="gcc -m32 -no-pie" nm=nm tf="-t i386" ;;
  a64) name=test_abi_a64 gcc=aarch64-linux-gnu-gcc clang="clang --target=aarch64-linux-gnu" ld="aarch64-linux-gnu-gcc -static" nm=aarch64-linux-gnu-nm tf="-t a64" ;;
  *) echo "FAIL abi.sh: no target $t"; exit 1 ;;
esac
for c in ${gcc%% *} clang $nm; do command -v $c >/dev/null 2>&1 || gate_skip "$name: no $c, skipped"; done
[ "`uname -m`" = x86_64 ] || gate_skip "$name: not an x64 box, skipped"
if [ $t = a64 ]; then
  . test/gate/a64run.sh
  a64_how "$m"
  [ -n "$a64_via" ] || gate_skip "$name: no a64 host and no qemu-aarch64, skipped"
fi
rm -rf "$d"; mkdir -p "$d/b" "$d/res"
echo "ABI $d${a64_via:+ (run by $a64_via)}"
fl="-w -Wno-psabi -O2 -fno-pie -fno-stack-protector"
die() { echo "FAIL $name: $*"; exit 1; }
# a peer needs its target's libc
echo 'int main(void) { return 0; }' > $d/probe.c
$gcc -c $d/probe.c -o $d/probe.o 2>/dev/null && $ld $d/probe.o -o $d/probe 2>/dev/null || gate_skip "$name: $ld links nothing, skipped"
pc() { [ $1 = gcc ] && echo "$gcc" || echo "$clang"; }
peer() { `pc $1` $fl -c "$2.c" -o "$2.$1.o" || die "$1 $2"; }
moon() { "$m" mooncc $tf -c "$1.c" -o "$1.moon.o" 2> "$1.err"; }
# what an object leaves undefined, beyond the calls it is for
calls() { $nm -u "$1" | awk '{print $2}' | /usr/bin/grep -vE '^(f[0-9]+|ck|keep|G|V|W|memcpy|memset)$'; }
cnt() { /usr/bin/grep -c '^static void t' "$d/$1-caller.c"; }
# bin NAME LINK..: a binary for the batch. pair GROUP CALLER CALLEE: one group's calls, NAME GROUP.CALLER.CALLEE
jobs=
bin() { j=$1; shift; "$@" -o $d/b/$j 2>/dev/null || die "link $j"; jobs="$jobs $j"; }
pair() { bin $1.$2.$3 $ld -Wl,--defsym=run=run_$1,--defsym=ncalls=$((2*`cnt $1`)) $d/report.o $d/$1-caller.$2.o $d/$1-callee.$3.o; }
runall() {
  if [ $t = a64 ]; then
    a64_jobs $d/a64
    for j in $jobs; do cp $d/b/$j $d/a64/; a64_job $j "timeout 20 \$RUN ./$j"; done
    a64_run $d/a64 || die "the a64 batch"
    cp $d/a64/res/*.out $d/a64/res/*.rc $d/res/
  else
    for j in $jobs; do ( cd $d/b && timeout 20 ./$j < /dev/null > $d/res/$j.out 2>&1; echo $? > $d/res/$j.rc ); done
  fi
}
ok() { [ "`cat $d/res/$1.rc 2>/dev/null`" = 0 ]; }
said() { head -5 $d/res/$1.out; }

cp $src/report.c "$d" || die copy
"$m" $src/gen.l $t $src/$t.expect $seed $n "$d" || die gen.l
$gcc -w -O1 -fno-pie -c $d/report.c -o $d/report.o || die report
for g in fix va; do
  for s in caller callee; do
    f=$d/$g-$s
    moon $f || { cat $f.err; die "mooncc $f"; }
    peer gcc $f; peer clang $f
    c=`calls $f.moon.o`; [ -z "$c" ] || die "$f calls $c"
  done
  for p in gcc clang; do for w in "moon $p" "$p moon" "$p $p" "moon moon"; do pair $g $w; done; done
  pair $g gcc clang
  # the same set by our linker and libc, with gcc's runtime for its object (a64's long double is soft)
  ( cd "$d" && "$m" mooncc $tf "-DRUN=run_$g" "-DNCK=$((2*`cnt $g`))" report.c $g-caller.moon.o $g-callee.gcc.o `$gcc -print-libgcc-file-name` -o b/$g.ours ) || die "our link of $g"
  jobs="$jobs $g.ours"
done

# what a signature cannot see: saved registers, alignment, al, va_list handed over, callbacks, setjmp
cp $src/seam-m.c $src/seam-p.c $d
moon $d/seam-m || { cat $d/seam-m.err; die seam-m; }
c=`$nm -u $d/seam-m.moon.o | awk '{print $2}' | /usr/bin/grep -v '^p_'`; [ -z "$c" ] || die "seam calls $c"
for p in gcc clang; do
  peer $p $d/seam-m; `pc $p` $fl -DLIVE=232 -c $d/seam-p.c -o $d/seam-p.$p.o || die "$p seam-p"
  `pc $p` $fl -DLIVE=232 -DHELD -c $d/seam-p.c -o $d/seam-h.$p.o || die "$p seam-p"
  for w in moon $p; do
    h=p; [ $w = moon ] && h=h
    bin seam.$p.$w $ld $d/seam-$h.$p.o $d/seam-m.$w.o
  done
done

# what compiles of a group: KIND TAG lines for refusals, else its pairings join the batch
built=
build() {
  local f=$d/$1 a b p
  moon $f-caller; a=$?; moon $f-callee; b=$?
  case "$a$b" in
    00) ;;
    01) /usr/bin/grep -q "no lane for this va_arg on $t" $f-callee.err && echo "$3refuse $2" || echo "other $1 `tail -n1 $f-callee.err`"; return ;;
    11) /usr/bin/grep -q 'no lane for' $f-caller.err && /usr/bin/grep -q 'no lane for' $f-callee.err && echo "$3pass $2" || echo "other $1 `tail -n1 $f-callee.err`"; return ;;
    10) /usr/bin/grep -q 'no lane for' $f-caller.err && echo "$3pass $2" || echo "other $1 `tail -n1 $f-caller.err`"; return ;;
    *) echo "other $1 $a$b `cat $f-caller.err $f-callee.err | tail -n1`"; return ;;
  esac
  for p in gcc clang; do
    peer $p $f-caller; peer $p $f-callee
    pair $1 $p $p; pair $1 moon $p; pair $1 $p moon
  done
  pair $1 moon moon
  built="$built $1:$2:$3"
}
# judge GROUP KIND TAG: with which peers it is right both ways
judge() {
  local r= p
  for p in gcc clang; do
    ok $1.$p.$p || die "control: $p with itself on $1"
    ok $1.moon.$p && ok $1.$p.moon && r="$r $p"
  done
  ok $1.moon.moon || echo "self $1"
  case "$r" in '') echo "${3-}wrong $2" ;; ' gcc clang') echo "${3-}right $2" ;; *) echo "${3-}split $2$r" ;; esac
}
: > $d/seen
for k in `cat $d/refuse`; do build vax_$k $k va >> $d/seen; done
for k in `cat $d/odd`; do build odd_$k $k '' >> $d/seen; done

# sizes, alignments, member offsets, ours against each peer's
cat > $d/lay.c <<'X'
#include <stdio.h>
typedef unsigned long long ul;
typedef union { ul u; float f; double d; } cell;
#include "report.h"
extern const ul lay[];
int main(void) { for (int i = 0; i < (int)(sizeof lays / sizeof *lays); i++) printf("%s|%ld\n", lays[i], (long)lay[i]); }
X
moon $d/layout || { cat $d/layout.err; die layout; }
peer gcc $d/layout; peer clang $d/layout
$gcc -w -c $d/lay.c -o $d/lay.o || die lay.c
for c in moon gcc clang; do bin lay.$c $ld $d/lay.o $d/layout.$c.o; done

runall

bad=0
for g in fix va; do
  for p in gcc clang; do
    for w in "moon $p" "$p moon" "$p $p" "moon moon"; do
      j=$g.`echo $w | tr ' ' .`
      ok $j || { bad=1; echo "FAIL $name: $g, caller and callee $w"; said $j; }
    done
  done
  ok $g.gcc.clang || die "control: gcc and clang differ on $g"
  ok $g.ours || { bad=1; echo "FAIL $name: $g by our linker"; said $g.ours; }
done
for p in gcc clang; do
  for w in moon $p; do ok seam.$p.$w || { bad=1; echo "FAIL $name: seam, $w under $p"; said seam.$p.$w; }; done
done
for x in $built; do judge `echo $x | tr ':' ' '`; done >> $d/seen
for c in moon gcc clang; do ok lay.$c || die "layout $c"; done
cmp -s $d/res/lay.gcc.out $d/res/lay.clang.out || die "control: gcc and clang lay differently"
paste -d'|' $d/res/lay.moon.out $d/res/lay.gcc.out | awk -F'|' '$2 != $4 {print "layout " $1 " " $2 " " $4}' >> $d/seen

sort $d/seen > $d/seen.s
/usr/bin/grep -v '^#' $src/$t.expect | sort > $d/want.s
diff $d/want.s $d/seen.s || { echo "FAIL $name: < $t.expect, > seen"; bad=1; }
[ $bad = 0 ] && echo "ok $name: `cnt fix` fixed and `cnt va` variadic signatures right both ways, `wc -l < $d/want.s` known differences as listed"
exit $bad
