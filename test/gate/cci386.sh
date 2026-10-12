#!/bin/sh
# test/gate/cci386.sh -- the C battery on i386: every test/cc/*.c built whole by `mooncc -t i386`
# (moonlibc, mksys's int 0x80 leaf, our linker) and run natively, must answer what gcc -m32
# answers for the same source. i386 is ilp32, so x64 is not the reference; gcc -m32 is, with
# sse2 doubles as mooncc does them (x87's wider intermediates are another answer).
#
# three lists, each asserted:
#   refuse   mooncc has no lane: nonzero exit, no signal, the diagnostic names the file.
#            the day a lane lands this fails, and the name comes off.
#   narrow   the program assumes a 64-bit long: gcc -m32 must fail it too (a nonzero exit),
#            and ours must run it to an exit, not a signal.
#   wide     ..so far that it is not C on ilp32 (a static assert, a bit-field past its type):
#            both compilers must refuse it, ours naming the file.
#
# stdout and the exit code are compared, for our build plain and at -Os (one epilogue per fn,
# the saves on push/pop). not set -e: the checks report their own failures.
# usage: cci386.sh OUTDIR LOVE
. test/gate/skip.sh
set -u

ho=$1
m=$2
name=test_cci386
refuse="100-complex 101-vla 111-int128 151-w128fuzz"
wide="68-static-assert 120-bfinit 161-enumwide"
narrow="105-fneg 144-gnubuiltins 152-rotate 266-vaarg-struct"

refused() {   # $1 the program: mooncc must refuse it, by name, without a signal
  if moonrun -t i386 -o "$d/$1.t" "$f" > "$d/$1.tlog" 2>&1; then
    fail "$1: mooncc -t i386 BUILT a program listed as refused -- take it off the list in this script"
  fi
  st=$?
  [ $st -lt 128 ] || fail "$1: mooncc died on a signal ($st) where a refusal was expected"
  grep -q "$f" "$d/$1.tlog" || { cat "$d/$1.tlog" >&2; fail "$1: the refusal does not name the file"; }
}
fail() { echo "FAIL $name: $*" >&2; exit 1; }
moonrun() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }

[ "$(uname -m)" = x86_64 ] || gate_skip "$name: skipped (runs i386 binaries natively on x86-64)"
d=$ho/cc-i386
rm -rf "$d"
mkdir -p "$d"
printf 'int main(void){return 0;}\n' > "$d/probe.c"
gcc -m32 -o "$d/probe" "$d/probe.c" > /dev/null 2>&1 && "$d/probe" \
  || gate_skip "$name: skipped (need gcc -m32 and a kernel that runs ia32)"

n=0; nref=0; nnar=0; nwide=0
for f in test/cc/*.c; do
  b=$(basename "$f" .c)
  case " $refuse " in
    *" $b "*) refused "$b"; nref=$((nref + 1)); continue ;;
  esac
  case " $wide " in
    *" $b "*)
      gcc -m32 -w -o "$d/$b.g" "$f" > "$d/$b.glog" 2>&1 \
        && fail "$b: gcc -m32 builds a program listed as wide -- take it off the list"
      refused "$b"; nwide=$((nwide + 1)); continue ;;
  esac
  gcc -m32 -msse2 -mfpmath=sse -w -o "$d/$b.g" "$f" -lm > "$d/$b.glog" 2>&1 \
    || { cat "$d/$b.glog" >&2; fail "$b: gcc -m32 could not build it"; }
  (cd "$d" && timeout 60 "./$b.g" > "$b.gout" 2>&1; echo $? > "$b.grc")
  rg=$(cat "$d/$b.grc")
  for os in t s; do
    fl=; [ $os = s ] && fl=-Os
    moonrun -t i386 $fl -o "$d/$b.$os" "$f" > "$d/$b.${os}log" 2>&1 \
      || { cat "$d/$b.${os}log" >&2; fail "$b: mooncc -t i386 $fl could not build it"; }
    (cd "$d" && timeout 60 "./$b.$os" > "$b.${os}out" 2>&1; echo $? > "$b.${os}rc")
    rt=$(cat "$d/$b.${os}rc")
    [ "$rt" -ne 124 ] || fail "$b: our binary ($fl) timed out"
    case " $narrow " in
      *" $b "*)
        [ "$rg" -ne 0 ] || fail "$b: gcc -m32 passes a program listed as narrow -- take it off the list"
        [ "$rt" -lt 128 ] || fail "$b: our binary ($fl) died on a signal ($rt)"
        continue ;;
    esac
    [ "$rt" = "$rg" ] || fail "$b: exit $rt ($fl), gcc -m32 answers $rg"
    cmp -s "$d/$b.gout" "$d/$b.${os}out" || { diff "$d/$b.gout" "$d/$b.${os}out" | head -20 >&2; fail "$b: stdout ($fl) differs from gcc -m32's"; }
  done
  case " $narrow " in *" $b "*) nnar=$((nnar + 1)); continue ;; esac
  n=$((n + 1))
done
# the register arguments across compilers: mooncc's half (test/cc/abi386/host.c) linked with
# gcc's (peer.c), each calling the other, at every -mregparm the kernel's units might ask for
for rp in 0 1 2 3; do
  gcc -m32 -mregparm=$rp -O1 -w -c -o "$d/peer$rp.o" test/cc/abi386/peer.c 2> "$d/peer.log" \
    || { cat "$d/peer.log" >&2; fail "abi386: gcc could not build peer.c at -mregparm=$rp"; }
  for fl in -O0 -Os; do
    moonrun -t i386 -mregparm=$rp $fl -c -o "$d/host$rp.o" test/cc/abi386/host.c > "$d/host.log" 2>&1 \
      || { cat "$d/host.log" >&2; fail "abi386: mooncc $fl could not build host.c at -mregparm=$rp"; }
    gcc -m32 -no-pie -o "$d/abi$rp" "$d/host$rp.o" "$d/peer$rp.o" 2> "$d/abi.log" \
      || { cat "$d/abi.log" >&2; fail "abi386: the link at -mregparm=$rp"; }
    "$d/abi$rp" > "$d/abi$rp.out" 2>&1 || { cat "$d/abi$rp.out" >&2; fail "abi386: mooncc $fl and gcc disagree at -mregparm=$rp"; }
  done
done
echo "abi386: $(tail -1 "$d/abi3.out") at each -mregparm, 0 to 3, ours plain and -Os"
echo "$name: $n programs answer as gcc -m32 does, built plain and -Os, $nnar narrow ones run to an exit, $nwide wide ones refused by both, $nref refused"
