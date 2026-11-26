#!/bin/sh
# test/gate/abi.sh -- calls between mooncc and gcc, clang on x64, both ways, by test/cc/abi/gen.l.
# the peers linked by theirs (glibc) and one set by ours (moonlibc); objects call f*, ck and keep only.
# what mooncc is known to do otherwise is x64.expect, held line for line: a new one or a lost one is red.
# usage: abi.sh OUTDIR LOVE [N] [SEED]
. test/gate/skip.sh
set -u

ho=$1 m=$2 n=${3:-200} seed=${4:-1}
name=test_abi src=test/cc/abi d=$1/abi
for c in gcc clang nm; do command -v $c >/dev/null 2>&1 || gate_skip "$name: no $c, skipped"; done
[ "`uname -m`" = x86_64 ] || gate_skip "$name: not x64, skipped"
rm -rf "$d"; mkdir -p "$d"
echo "ABI $d"
fl="-w -Wno-psabi -O2 -fno-pie -fno-stack-protector"
die() { echo "FAIL $name: $*"; exit 1; }
peer() { $1 $fl -c "$2.c" -o "$2.$1.o" || die "$1 $2"; }
moon() { "$m" mooncc -c "$1.c" -o "$1.moon.o" 2> "$1.err"; }
# what an object leaves undefined, beyond the calls it is for
calls() { nm -u "$1" | awk '{print $2}' | /usr/bin/grep -vE '^(f[0-9]+|ck|keep|G|V|W|memcpy|memset)$'; }
# run GROUP CALLER CALLEE: 0 right, 1 wrong
run() {
  gcc -no-pie -Wl,--defsym=run=run_$1,--defsym=ncalls=$((2*cnt)) $d/report.o $d/$1-caller.$2.o $d/$1-callee.$3.o -o $d/t 2>/dev/null || die "link $1 $2 $3"
  timeout 20 $d/t > $d/$1.$2.$3.out 2>/dev/null
}
cnt() { /usr/bin/grep -c '^static void t' "$d/$1-caller.c"; }

cp $src/report.c "$d" || die copy
"$m" $src/gen.l $src/x64.expect $seed $n "$d" || die gen.l
gcc -w -O1 -fno-pie -c $d/report.c -o $d/report.o || die report
for g in fix va; do
  for s in caller callee; do
    f=$d/$g-$s
    moon $f || { cat $f.err; die "mooncc $f"; }
    peer gcc $f; peer clang $f
    c=`calls $f.moon.o`; [ -z "$c" ] || die "$f calls $c"
  done
done

bad=0
for g in fix va; do
  cnt=`cnt $g`
  for p in gcc clang; do
    for w in "moon $p" "$p moon" "$p $p" "moon moon"; do
      run $g $w || { bad=1; echo "FAIL $name: $g, caller and callee $w"; head -5 $d/$g.`echo $w | tr ' ' .`.out; }
    done
  done
  run $g gcc clang || die "control: gcc and clang differ on $g"
  # the same set by our linker and libc
  ( cd "$d" && "$m" mooncc "-DRUN=run_$g" "-DNCK=$((2*cnt))" report.c $g-caller.moon.o $g-callee.gcc.o -o t.$g ) || die "our link of $g"
  $d/t.$g > $d/$g.ours.out || { bad=1; echo "FAIL $name: $g by our linker"; head -5 $d/$g.ours.out; }
done

# what a signature cannot see: saved registers, alignment, al, va_list handed over, callbacks, setjmp
cp $src/seam-m.c $src/seam-p.c $d
moon $d/seam-m || { cat $d/seam-m.err; die seam-m; }
c=`nm -u $d/seam-m.moon.o | awk '{print $2}' | /usr/bin/grep -v '^p_'`; [ -z "$c" ] || die "seam calls $c"
for p in gcc clang; do
  peer $p $d/seam-m; $p $fl -DLIVE=232 -c $d/seam-p.c -o $d/seam-p.$p.o || die "$p seam-p"
  $p $fl -DLIVE=232 -DHELD -c $d/seam-p.c -o $d/seam-h.$p.o || die "$p seam-p"
  for w in moon $p; do
    h=p; [ $w = moon ] && h=h
    gcc -no-pie $d/seam-$h.$p.o $d/seam-m.$w.o -o $d/t 2>/dev/null || die "link seam $p $w"
    timeout 20 $d/t > $d/seam.$p.$w.out 2>/dev/null || { bad=1; echo "FAIL $name: seam, $w under $p"; head -5 $d/seam.$p.$w.out; }
  done
done

# judge GROUP KIND TAG: what compiles, and with which peers it is right both ways
judge() {
  local f=$d/$1 a b p r=
  cnt=`cnt $1`
  moon $f-caller; a=$?; moon $f-callee; b=$?
  case "$a$b" in
    00) ;;
    01) /usr/bin/grep -q 'no lane for this va_arg on x64' $f-callee.err && echo "$3refuse $2" || echo "other $1 `tail -n1 $f-callee.err`"; return ;;
    11) /usr/bin/grep -q 'no lane for' $f-caller.err && /usr/bin/grep -q 'no lane for' $f-callee.err && echo "$3pass $2" || echo "other $1 `tail -n1 $f-callee.err`"; return ;;
    *) echo "other $1 $a$b `cat $f-caller.err $f-callee.err | tail -n1`"; return ;;
  esac
  for p in gcc clang; do
    peer $p $f-caller; peer $p $f-callee
    run $1 $p $p || die "control: $p with itself on $1"
    run $1 moon $p && run $1 $p moon && r="$r $p"
  done
  run $1 moon moon || echo "self $1"
  case "$r" in '') echo "$3wrong $2" ;; ' gcc clang') echo "$3right $2" ;; *) echo "$3split $2$r" ;; esac
}
for k in `cat $d/refuse`; do judge vax_$k $k va; done > $d/seen
for k in `cat $d/odd`; do judge odd_$k $k ''; done >> $d/seen

# sizes, alignments, member offsets, ours against each peer's
cat > $d/lay.c <<'X'
#include <stdio.h>
typedef unsigned long ul;
typedef union { ul u; float f; double d; } cell;
#include "report.h"
extern const ul lay[];
int main(void) { for (int i = 0; i < (int)(sizeof lays / sizeof *lays); i++) printf("%s|%ld\n", lays[i], (long)lay[i]); }
X
moon $d/layout || { cat $d/layout.err; die layout; }
peer gcc $d/layout; peer clang $d/layout
for c in moon gcc clang; do gcc -w -no-pie $d/lay.c $d/layout.$c.o -o $d/lay && $d/lay > $d/lay.$c || die "layout $c"; done
cmp -s $d/lay.gcc $d/lay.clang || die "control: gcc and clang lay differently"
paste -d'|' $d/lay.moon $d/lay.gcc | awk -F'|' '$2 != $4 {print "layout " $1 " " $2 " " $4}' >> $d/seen

sort $d/seen > $d/seen.s
/usr/bin/grep -v '^#' $src/x64.expect | sort > $d/want.s
diff $d/want.s $d/seen.s || { echo "FAIL $name: < x64.expect, > seen"; bad=1; }
[ $bad = 0 ] && echo "ok $name: `cnt fix` fixed and `cnt va` variadic signatures right both ways, `wc -l < $d/want.s` known differences as listed"
exit $bad
