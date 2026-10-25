#!/bin/sh
# test/gate/cc32.sh -- the C battery on a 32-bit linux target: every test/cc/*.c built whole
# by `mooncc -t TARGET` (moonlibc, mksys's leaf, our linker) must answer, stdout and exit,
# plain and -Os, what the target's gcc answers. arm runs under qemu-arm against
# arm-none-eabi-gcc's newlib over semihosting; i386 runs natively against gcc -m32, sse2
# doubles as mooncc does them. the lists, each asserted:
#   refuse  mooncc has no lane: it refuses, by name, without a signal
#   wide    not C on ilp32 (a static assert, a bit-field past its type): both refuse
#   narrow  assumes a 64-bit long: the reference fails it, ours runs it to an exit
#   w128    __int128, which the target's gcc has no lane for: the host gcc's build of the same
#           source, run here, is the reference (the programs keep to a 64-bit long long)
#   hosted  newlib's gaps, or gcc's thumb frames read otherwise: ours runs it to an exit
# usage: cc32.sh TARGET OUTDIR LOVE     (TARGET: arm | i386)
. test/gate/skip.sh
. test/gate/cclib.sh
set -u

tgt=$1
ho=$2
m=$3
narrow="105-fneg 144-gnubuiltins 152-rotate 266-vaarg-struct"
case $tgt in
  arm)  name=test_ccarm; ref=arm-none-eabi-gcc; run=qemu-arm; gopt=-O1
        refuse="161-enumwide"
        w128="111-int128 151-w128fuzz 314-u128union"
        wide="68-static-assert 120-bfinit"
        hosted="72-quals 125-widelit 150-alloc 160-rangeinit 297-frameaddr 298-malloc-wrap 300-aligned-alloc 301-free-checks"
        gref() { arm-none-eabi-gcc -mcpu=cortex-a53 -mthumb -mfloat-abi=hard -mfpu=fp-armv8 --specs=rdimon.specs "$@"; }
        for tool in arm-none-eabi-gcc qemu-arm; do have $tool || gate_skip "$name: no $tool, skipped"; done ;;
  i386) name=test_cci386; ref="gcc -m32"; run=; gopt="-msse2 -mfpmath=sse"
        refuse="111-int128 151-w128fuzz 314-u128union"
        w128=
        wide="68-static-assert 120-bfinit 161-enumwide"
        hosted=
        gref() { gcc -m32 "$@"; }
        [ "$(uname -m)" = x86_64 ] || gate_skip "$name: skipped (runs i386 binaries natively on x86-64)" ;;
  *) echo "cc32.sh: unknown target $tgt" >&2; exit 1 ;;
esac

d=$ho/cc-$tgt
rm -rf "$d"
mkdir -p "$d"
printf '#include <stdio.h>\nint main(void){puts("ok");return 0;}\n' > "$d/probe.c"
gref -o "$d/probe" "$d/probe.c" > /dev/null 2>&1 && [ "$($run "$d/probe")" = ok ] \
  || gate_skip "$name: skipped ($ref cannot build and run a hello here)"

n=0; nref=0; nnar=0; nhost=0; nwide=0
for f in test/cc/*.c; do
  b=$(basename "$f" .c)
  case " $refuse " in
    *" $b "*) refused "$d/$b.tlog" "$f" -t $tgt -o "$d/$b.t" "$f"; nref=$((nref + 1)); continue ;;
  esac
  case " $wide " in
    *" $b "*)
      gref -w -o "$d/$b.g" "$f" > "$d/$b.glog" 2>&1 \
        && fail "$b: $ref builds a program listed as wide -- take it off the list"
      refused "$d/$b.tlog" "$f" -t $tgt -o "$d/$b.t" "$f"; nwide=$((nwide + 1)); continue ;;
  esac
  hl=0
  case " $hosted " in *" $b "*) hl=1 ;; esac
  if [ $hl = 0 ]; then
    case " $w128 " in
      *" $b "*)
        cc -w -O1 -o "$d/$b.g" "$f" > "$d/$b.glog" 2>&1 \
          || { cat "$d/$b.glog" >&2; fail "$b: the host cc could not build it"; }
        (cd "$d" && timeout 60 "./$b.g" > "$b.gout" 2>&1; echo $? > "$b.grc") ;;
      *)
        # shellcheck disable=SC2086  # $gopt is a word list
        gref $gopt -w -o "$d/$b.g" "$f" -lm > "$d/$b.glog" 2>&1 \
          || { cat "$d/$b.glog" >&2; fail "$b: $ref could not build it"; }
        (cd "$d" && timeout 60 $run "./$b.g" > "$b.gout" 2>&1; echo $? > "$b.grc") ;;
    esac
    rg=$(cat "$d/$b.grc")
  fi
  for os in t s; do
    fl=; [ $os = s ] && fl=-Os
    moonrun -t $tgt $fl -o "$d/$b.$os" "$f" > "$d/$b.${os}log" 2>&1 \
      || { cat "$d/$b.${os}log" >&2; fail "$b: mooncc -t $tgt $fl could not build it"; }
    (cd "$d" && timeout 60 $run "./$b.$os" > "$b.${os}out" 2>&1; echo $? > "$b.${os}rc")
    rt=$(cat "$d/$b.${os}rc")
    [ "$rt" -ne 124 ] || fail "$b: our binary ($fl) timed out"
    case " $narrow " in *" $b "*) nar=1 ;; *) nar=0 ;; esac
    if [ $hl = 1 ] || [ $nar = 1 ]; then
      [ $hl = 1 ] || [ "$rg" -ne 0 ] || fail "$b: $ref passes a program listed as narrow -- take it off the list"
      [ "$rt" -lt 128 ] || fail "$b: our binary ($fl) died on a signal ($rt)"
      continue
    fi
    [ "$rt" = "$rg" ] || fail "$b: exit $rt ($fl), $ref answers $rg"
    cmp -s "$d/$b.gout" "$d/$b.${os}out" || { diff "$d/$b.gout" "$d/$b.${os}out" | head -20 >&2; fail "$b: stdout ($fl) differs from $ref's"; }
  done
  if [ $hl = 1 ]; then nhost=$((nhost + 1))
  elif [ $nar = 1 ]; then nnar=$((nnar + 1))
  else n=$((n + 1)); fi
done

# i386: abi386/host.c by mooncc linked with gcc's peer.c, each calling the other, -mregparm 0..3
if [ $tgt = i386 ]; then
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
fi
echo "$name: $n programs answer as $ref does, built plain and -Os, $nnar narrow and $nhost hosted ones run to an exit, $nwide wide ones refused by both, $nref refused"
