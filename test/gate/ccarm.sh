#!/bin/sh
# test/gate/ccarm.sh -- the C battery on linux's arm: every test/cc/*.c built whole by `mooncc -t
# arm` (moonlibc, mksys's svc leaf, our linker) and run under qemu-arm, must answer what
# arm-none-eabi-gcc answers for the same source on the same cpu. the reference is newlib over
# semihosting, which qemu-arm speaks: an arm compiler, so arm's layout and its unsigned char.
#
# four lists, each asserted:
#   refuse   mooncc has no lane: nonzero exit, no signal, the diagnostic names the file.
#            the day a lane lands this fails, and the name comes off.
#   narrow   the program assumes a 64-bit long: the reference must fail it too (a nonzero
#            exit), and ours must run it to an exit, not a signal.
#   wide     ..so far that it is not C on ilp32 (a static assert, a bit-field past its type):
#            both compilers must refuse it, ours naming the file.
#   hosted   the reference cannot speak for it: ours must still build it and run it to an
#            exit, not a signal. 72 and 125 newlib's gcc will not build; 150 newlib's
#            allocator answers short of the contract; 160 asks gcc's thumb frame address,
#            r7 at its frame's foot, what a frame base above its locals answers; 297 walks the
#            frame chain past level 1, which gcc's arm build does not follow.
#
# stdout and the exit code are compared, for our build plain and at -Os. not set -e: the
# checks report their own failures.
# usage: ccarm.sh OUTDIR LOVE
. test/gate/skip.sh
set -u

ho=$1
m=$2
name=test_ccarm
refuse="111-int128 151-w128fuzz 161-enumwide 291-enumahead"
wide="68-static-assert 120-bfinit"
narrow="105-fneg 144-gnubuiltins 152-rotate 266-vaarg-struct"
hosted="72-quals 125-widelit 150-alloc 160-rangeinit 297-frameaddr"

fail() { echo "FAIL $name: $*" >&2; exit 1; }
moonrun() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }
gccarm() { arm-none-eabi-gcc -mcpu=cortex-a53 -mthumb -mfloat-abi=hard -mfpu=fp-armv8 --specs=rdimon.specs "$@"; }

for tool in arm-none-eabi-gcc qemu-arm; do
  command -v $tool > /dev/null 2>&1 || gate_skip "$name: no $tool, skipped"
done
d=$ho/cc-arm
rm -rf "$d"
mkdir -p "$d"
printf '#include <stdio.h>\nint main(void){puts("ok");return 0;}\n' > "$d/probe.c"
gccarm -o "$d/probe" "$d/probe.c" > /dev/null 2>&1 && [ "$(qemu-arm "$d/probe")" = ok ] \
  || gate_skip "$name: skipped (arm-none-eabi-gcc has no rdimon newlib, or qemu-arm no semihosting)"

refused() {   # $1 the program: mooncc must refuse it, by name, without a signal
  if moonrun -t arm -o "$d/$1.t" "$f" > "$d/$1.tlog" 2>&1; then
    fail "$1: mooncc -t arm BUILT a program listed as refused -- take it off the list in this script"
  fi
  st=$?
  [ $st -lt 128 ] || fail "$1: mooncc died on a signal ($st) where a refusal was expected"
  grep -q "$f" "$d/$1.tlog" || { cat "$d/$1.tlog" >&2; fail "$1: the refusal does not name the file"; }
}

n=0; nref=0; nnar=0; nhost=0; nwide=0
for f in test/cc/*.c; do
  b=$(basename "$f" .c)
  case " $refuse " in
    *" $b "*) refused "$b"; nref=$((nref + 1)); continue ;;
  esac
  case " $wide " in
    *" $b "*)
      gccarm -w -o "$d/$b.g" "$f" > "$d/$b.glog" 2>&1 \
        && fail "$b: arm-none-eabi-gcc builds a program listed as wide -- take it off the list"
      refused "$b"; nwide=$((nwide + 1)); continue ;;
  esac
  ref=1
  case " $hosted " in *" $b "*) ref=0 ;; esac
  if [ $ref = 1 ]; then
    gccarm -w -O1 -o "$d/$b.g" "$f" -lm > "$d/$b.glog" 2>&1 \
      || { cat "$d/$b.glog" >&2; fail "$b: arm-none-eabi-gcc could not build it (list it as hosted?)"; }
    (cd "$d" && timeout 60 qemu-arm "./$b.g" > "$b.gout" 2>&1; echo $? > "$b.grc")
    rg=$(cat "$d/$b.grc")
  fi
  for os in t s; do
    fl=; [ $os = s ] && fl=-Os
    moonrun -t arm $fl -o "$d/$b.$os" "$f" > "$d/$b.${os}log" 2>&1 \
      || { cat "$d/$b.${os}log" >&2; fail "$b: mooncc -t arm $fl could not build it"; }
    (cd "$d" && timeout 60 qemu-arm "./$b.$os" > "$b.${os}out" 2>&1; echo $? > "$b.${os}rc")
    rt=$(cat "$d/$b.${os}rc")
    [ "$rt" -ne 124 ] || fail "$b: our binary ($fl) timed out"
    if [ $ref = 0 ]; then
      [ "$rt" -lt 128 ] || fail "$b: our binary ($fl) died on a signal ($rt)"
      continue
    fi
    case " $narrow " in
      *" $b "*)
        [ "$rg" -ne 0 ] || fail "$b: the reference passes a program listed as narrow -- take it off the list"
        [ "$rt" -lt 128 ] || fail "$b: our binary ($fl) died on a signal ($rt)"
        continue ;;
    esac
    [ "$rt" = "$rg" ] || fail "$b: exit $rt ($fl), the reference answers $rg"
    cmp -s "$d/$b.gout" "$d/$b.${os}out" || { diff "$d/$b.gout" "$d/$b.${os}out" | head -20 >&2; fail "$b: stdout ($fl) differs from the reference's"; }
  done
  [ $ref = 0 ] && { nhost=$((nhost + 1)); continue; }
  case " $narrow " in *" $b "*) nnar=$((nnar + 1)); continue ;; esac
  n=$((n + 1))
done
echo "$name: $n programs answer as arm-none-eabi-gcc does under qemu-arm, built plain and -Os, $nnar narrow and $nhost hosted ones run to an exit, $nwide wide ones refused by both, $nref refused"
