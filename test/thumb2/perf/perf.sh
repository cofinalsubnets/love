# test/thumb2/perf/perf.sh -- mooncc's thumb2sp codegen against gcc's, on qemu's M4. from the tree's root:
#   sh test/thumb2/perf/perf.sh count [moon|libgcc|gcc]   instructions per dmul, dadd, sin call, stepped by gdb
#        moon: mooncc's bench and lm.c over src rt.c; libgcc: the same over libgcc; gcc: gcc -O2 throughout
#   sh test/thumb2/perf/perf.sh diff [REV]                 src rt.c against REV's (HEAD), 160k cases bit for bit
#   sh test/thumb2/perf/perf.sh probe                      kit.c and kit2.c on thumb2sp and thumb2; 0 = held
# wants out/love, arm-none-eabi-{gcc,ld,gdb}, qemu-system-arm, and test_thumb2sp's out/thumb2sp (start.o, link.ld)
p=test/thumb2/perf
o=out/thumb2perf
d=out/thumb2sp
cpu="-mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16"
lmi="-Isrc/apps/moon/lib/moonlibc/math -Isrc/apps/moon/include"
lm=src/apps/moon/lib/moonlibc/math/lm.c
mkdir -p $o
[ -s $d/start.o ] || { echo "perf: no $d/start.o -- make test_thumb2sp first"; exit 1; }
lg=$(arm-none-eabi-gcc $cpu -print-libgcc-file-name)
mc() { LOVE_NO_IMAGE= out/love mooncc "$@"; }

# entry to return: a breakpoint on each fn's first instruction, then stepi until pc is lr's
count() {
  case ${1:-moon} in
  moon)   mc -t thumb2sp -c $p/sfbench.c $o/b.o && mc -t thumb2sp $lmi -c $lm $o/lm.o \
            && mc -t thumb2sp -c src/apps/moon/lib/rt.c $o/rt.o \
            && arm-none-eabi-ld -T $d/link.ld $d/start.o $o/b.o $o/rt.o $o/lm.o -o $o/b.elf || exit 2 ;;
  libgcc) mc -t thumb2sp -c $p/sfbench.c $o/b.o && mc -t thumb2sp $lmi -c $lm $o/lm.o \
            && arm-none-eabi-ld -T $d/link.ld $d/start.o $o/b.o $o/lm.o $lg -o $o/b.elf || exit 2 ;;
  gcc)    arm-none-eabi-gcc $cpu -O2 -ffreestanding -c $p/sfbench.c -o $o/b.o \
            && arm-none-eabi-gcc $cpu -O2 -ffreestanding $lmi -c $lm -o $o/lm.o \
            && arm-none-eabi-ld -T $d/link.ld $d/start.o $o/b.o $o/lm.o $lg -o $o/b.elf || exit 2 ;;
  *) echo "perf count: moon, libgcc or gcc"; exit 1 ;;
  esac
  { printf '%s\n' 'set pagination off' 'set arm force-mode thumb' 'set arm fallback-mode thumb' 'target remote :1234'
    for f in dm da ds; do printf 'break *(((unsigned) &%s) & ~1)\n' $f; done
    for f in dm da ds; do
      printf '%s\n' 'continue' 'set $ret = ((unsigned) $lr) & ~1' 'set $n = 0' \
        'while (((unsigned) $pc & ~1) != $ret)' 'stepi' 'set $n = $n + 1' 'end'
      printf 'printf "%s %%d\\n", $n\n' $f
    done
    echo kill; } > $o/count.gdb
  qemu-system-arm -M mps2-an386 -semihosting -nographic -kernel $o/b.elf -s -S < /dev/null > /dev/null 2>&1 &
  q=$!
  sleep 1
  arm-none-eabi-gdb -batch -nx $o/b.elf -x $o/count.gdb 2>&1 | grep -E '^(dm|da|ds) ' \
    | sed 's/^dm /dmul /; s/^da /dadd /; s/^ds /sin  /'
  kill $q 2> /dev/null
  return 0
}

# each side's helpers renamed and every other runtime symbol localized, so both link beside libgcc
rtobj() { # rtobj SRC PREFIX OUT
  ren=""
  for f in dmul dadd dsub ddiv llsl llsr lasr lmul; do ren="$ren -D__aeabi_$f=$2_$f"; done
  mc -t thumb2sp $ren -c $1 $3.o || exit 2
  cp $3.o $3.l.o
  for s in $(arm-none-eabi-nm $3.l.o | awk '$2 == "T" && ($3 ~ /^__/) {print $3}'); do
    arm-none-eabi-objcopy --localize-symbol=$s $3.l.o
  done
}
diff1() {
  git show ${1:-HEAD}:src/apps/moon/lib/rt.c > $o/rt-old.c || exit 2
  rtobj src/apps/moon/lib/rt.c moon $o/rtm
  rtobj $o/rt-old.c old $o/rto
  arm-none-eabi-gcc $cpu -O2 -ffreestanding -c $p/sfdiff.c -o $o/dh.o || exit 3
  arm-none-eabi-ld -T $d/link.ld $d/start.o $o/dh.o $o/rtm.l.o $o/rto.l.o $lg -o $o/dh.elf || exit 4
  timeout 300 qemu-system-arm -M mps2-an386 -semihosting -nographic -kernel $o/dh.elf < /dev/null
}

probe() {
  rc=0
  for t in thumb2sp thumb2; do
    case $t in
    thumb2sp) c="-mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16"; m=mps2-an386; sd=out/thumb2sp ;;
    thumb2)   c="-mcpu=cortex-m7 -mthumb -mfloat-abi=hard -mfpu=fpv5-d16"; m=mps2-an500; sd=out/thumb2 ;;
    esac
    [ -s $sd/start.o ] || { echo "perf: no $sd/start.o -- make test_$t first"; exit 1; }
    arm-none-eabi-gcc $c -c $p/kh.c -o $o/kh.o || exit 3
    for k in kit kit2; do
      mc -t $t -c $p/$k.c $o/$k.o || exit 2
      arm-none-eabi-ld -T $sd/link.ld $sd/start.o $o/kh.o $o/$k.o $(arm-none-eabi-gcc $c -print-libgcc-file-name) -o $o/$k.elf || exit 4
      timeout 20 qemu-system-arm -M $m -semihosting -nographic -kernel $o/$k.elf < /dev/null
      a=$?
      echo "$t $k: $a"
      [ $a -eq 0 ] || rc=1
    done
  done
  return $rc
}

case $1 in
count) count $2 ;;
diff) diff1 $2 ;;
probe) probe ;;
*) echo "perf.sh count [moon|libgcc|gcc] | diff [REV] | probe"; exit 1 ;;
esac
