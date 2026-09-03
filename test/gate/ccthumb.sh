#!/bin/sh
# test/gate/ccthumb.sh -- the C battery on the DEVICE CPUs: every test/cc/*.c built by
# `mooncc -t thumb1|thumb2`, run on qemu's Cortex-M, and required to answer exactly what
# arm-none-eabi-gcc answers for the same source on the same machine.
#
# WHY A SECOND ORACLE. ccarch.sh pins arm64 and riscv64 against the x86-64 build, which
# works because those are LP64 like x64 and run under qemu-USER. The thumb family is
# M-profile: no MMU, no Linux, no qemu-user lane at all, and ILP32 besides -- so x64
# cannot be the reference (a program reading `sizeof(long)` is not wrong to differ) and
# there is no hosted process to run. Both problems have the same answer: build the same
# source with the cross gcc for the same machine and compare. Same ISA, same ABI, same
# startup, one compiler differs -- which is thumb.sh's shape, over the whole battery
# instead of a hand-written lane.
#
# What this catches that nothing else did: gen.l's cgzero strode 8 bytes per store on a
# target whose store is 4, so a partly-spelled local aggregate kept every other word of
# the frame; and objsecs3 told the linker 4-byte section grain whatever the stream asked,
# so every aligned(N) global landed off its boundary. Both were live on every board port,
# both compiled clean, and both are invisible to a 64-bit run.
#
# THREE LISTS, EACH ASSERTED, because they refuse for three different reasons and folding
# them is how a gate starts lying:
#   refuse   mooncc has no lane -- nonzero exit, no signal, the diagnostic names the file.
#            the day a lane lands the build succeeds, this fails, and the name comes off.
#   hosted   the program wants a hosted environment -- printf, malloc, gcc's emutls for a
#            _Thread_local, or a header (sys/mman.h) the bare-metal sysroot has no copy
#            of. at least one of the two builds must therefore FAIL to produce a binary,
#            at compile or at link. a program that stops needing one gets noticed the same
#            way a new refusal does.
#   narrow   the program assumes a 64-bit `long`, so its answers do not carry to ILP32
#            (a union of double with `unsigned long`, a `:40` bit-field). the reference
#            compiler is asked, and it must AGREE that the source does not build or that
#            we cannot both be right -- see the note beside each name.
#
# ⚠ exit codes are 8 bits and stdout needs a libc, so this compares the CODE alone. Every
# program in test/cc returns a count of passing checks, which is what makes that enough --
# but unlike thumb.sh, the wants belong to the programs and cannot be chosen clear of the
# codes a death wears: 43-dispatch legitimately answers 131, which is 128+3 read as a
# signal. So a fault is read off QEMU'S OWN OUTPUT instead. These binaries carry no libc
# and print nothing, so anything on that stream is the machine's register dump and
# `qemu: fatal` is its first line. 124 stays timeout's, which no program returns.
# NOT set -e: the checks report their own failures with context.
#
# usage: ccthumb.sh TARGET OUTDIR LOVE     (TARGET: thumb1 | thumb2)
set -u

tgt=$1
ho=$2
m=$3

case $tgt in
  thumb1) name=test_ccthumb1; cpu="-mcpu=cortex-m0 -mthumb"; acpu=cortex-m0; afpu=""
          mach=microbit    ; vfp=0 ;;
  thumb2) name=test_ccthumb2; cpu="-mcpu=cortex-m7 -mthumb -mfloat-abi=hard -mfpu=fpv5-d16"
          acpu=cortex-m7   ; afpu=fpv5-d16 ; mach=mps2-an500 ; vfp=1 ;;
  *) echo "ccthumb.sh: unknown target $tgt" >&2; exit 1 ;;
esac

fail() { echo "FAIL $name: $*" >&2; exit 1; }
moonrun() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }

for tool in arm-none-eabi-gcc arm-none-eabi-ld qemu-system-arm; do
  command -v $tool > /dev/null 2>&1 || {
    echo "$name: no arm-none-eabi toolchain / qemu-system-arm, skipped"; exit 0; }
done

# ⚠ ONE RUN'S WORTH: a failing case keeps its objects and elfs, which is the only time
# anyone wants them; clearing at the start rather than the end is what bounds the pile.
d=$ho/cc-$tgt
rm -rf "$d"
mkdir -p "$d"

echo "CCTHUMB $d"

# the startup is thumb.sh's -- vector table, `bl run`, then semihosting SYS_EXIT_EXTENDED
# carrying run()'s answer out as the process exit code -- flash and the 16 KiB SRAM
# window exactly as that gate spells them. ⚠ the initial SP is a real address on this
# machine and not a size to raise at will: 0x20040000 is off the end of the M7 board's
# SRAM, and every program then faults before its first instruction, both compilers' alike
# -- which reads as agreement on a crash and says nothing. Hence the check below. A VFP target must enable CP10/CP11
# in CPACR first or the first float instruction UsageFaults.
{ echo '.syntax unified'
  echo ".cpu $acpu"
  [ -n "$afpu" ] && echo ".fpu $afpu"
  echo '.thumb'
  echo '.section .vectors,"a"'; echo '.word 0x20004000'; echo '.word _start+1'
  echo '.text'; echo '.thumb_func'; echo '.global _start'; echo '_start:'
  if [ "$vfp" = 1 ]; then
    echo '  ldr r0, =0xE000ED88'; echo '  ldr r1, [r0]'; echo '  orr r1, r1, #0xF00000'
    echo '  str r1, [r0]'; echo '  dsb'; echo '  isb'
  fi
  echo '  bl run'; echo '  ldr r1, =0x20026'; echo '  push {r0}'; echo '  push {r1}'
  echo '  mov r1, sp'; echo '  movs r0, #0x20'; echo '  bkpt 0xAB'; echo '  b .'
} > "$d/start.S"

{ echo 'MEMORY'; echo '{'
  echo '  FLASH (rx) : ORIGIN = 0, LENGTH = 1M'
  echo '  RAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 16K'; echo '}'
  echo 'SECTIONS'; echo '{'
  echo '  .text : { KEEP(*(.vectors)) *(.text*) *(.rodata*) } > FLASH'
  echo '  .data : { *(.data*) } > RAM'
  echo '  .bss : { *(.bss*) *(COMMON) } > RAM'; echo '}'
} > "$d/link.ld"

# main is renamed so the startup's `run` can call it: the battery's programs all define
# main and return their count. memset/memcpy/memmove are the freestanding floor C11 lets
# an implementation call for aggregate copies -- gcc emits a memset for `struct s = { 0 }`
# where our cgzero lays stores -- so they belong to the harness, not to a libc.
{ echo 'int cc_main(void);'
  echo 'int run(void){ return cc_main(); }'
  echo 'void *memset(void *p, int c, unsigned long n){'
  echo ' unsigned char *q = p; while (n--) *q++ = (unsigned char) c; return p; }'
  echo 'void *memcpy(void *a, const void *b, unsigned long n){'
  echo ' unsigned char *x = a; const unsigned char *y = b; while (n--) *x++ = *y++; return a; }'
  echo 'void *memmove(void *a, const void *b, unsigned long n){'
  echo ' unsigned char *x = a; const unsigned char *y = b;'
  echo ' if (x < y) { while (n--) *x++ = *y++; }'
  echo ' else { x += n; y += n; while (n--) *--x = *--y; } return a; }'
} > "$d/run.c"

# shellcheck disable=SC2086  # $cpu is a deliberate word list
arm-none-eabi-gcc $cpu -c "$d/start.S" -o "$d/start.o" || fail "as start.S"
arm-none-eabi-gcc $cpu -ffreestanding -O2 -c "$d/run.c" -o "$d/run.o" || fail "gcc run.c"
lg=$(arm-none-eabi-gcc $cpu -print-libgcc-file-name)

# -- the three lists, per target. see the header for what each one asserts. --
# ⚠ refuse is tested FIRST, so a name may sit in both: 135-uac wants printf, and on
# thumb2 the compiler refuses it before the libc question is reached at all.
hosted="72-quals 110-param5 114-rmwlv 134-tentative 135-uac 142-syntax 146-declscope
        147-enumscope 148-tagscope 149-paste 150-alloc 154-blockextern"
# each name, and what it assumes: 81 puts 2^62 in a `long`; 99 and 104 shift a
# `unsigned long` by 32 or more, which is undefined once long is 32 bits; 105 unions a
# double with one and reads bit 63; 120 asks for a `:40` bit-field (gcc REFUSES it here,
# rightly); 125 wants char32_t to be the type of a U"" literal, which it is not on this
# ABI. gcc is the witness for each -- it either refuses the source or answers differently
# for the program's reason.
narrow="81-builtins 99-muslimage 104-u32wrap 105-fneg 120-bfinit 125-widelit"

case $tgt in
  thumb2) refuse="67-varargs-double 68-static-assert 71-varargs-sysv 80-manyargs 85-aggval
                  88-varargs-overflow 97-muslrungs 100-complex 101-vla 102-bigstruct
                  111-int128 115-rmwop 117-vastruct 128-bswap 129-sync 133-popcount
                  135-uac 144-gnubuiltins 151-w128fuzz" ;;
  # ⚠ the two lists are NOT the same list: v6-M takes 80-manyargs and 135-uac where
  # ARMv7E-M refuses them, and refuses 82-znvalue where thumb2 takes it. the composite
  # rows do not move together (doc/misc/moon-c-gaps), so neither do these.
  thumb1) refuse="67-varargs-double 68-static-assert 71-varargs-sysv 82-znvalue 85-aggval
                  88-varargs-overflow 97-muslrungs 100-complex 101-vla 102-bigstruct
                  111-int128 115-rmwop 117-vastruct 128-bswap 129-sync 133-popcount
                  144-gnubuiltins 151-w128fuzz" ;;
esac

inlist() { for w in $2; do [ "$w" = "$1" ] && return 0; done; return 1; }

nrun=0; nref=0; nhost=0; nnar=0
for f in test/cc/*.c; do
  b=$(basename "$f" .c)

  # the target has no lane: the build must FAIL, without a signal, naming the file
  if inlist "$b" "$refuse"; then
    if moonrun -t "$tgt" -Dmain=cc_main -c "$f" "$d/$b.t.o" > "$d/$b.tlog" 2>&1; then
      fail "$b: mooncc -t $tgt BUILT a program listed as unsupported -- take it off refuse="
    fi
    st=$?
    [ $st -lt 128 ] || fail "$b: mooncc died on a signal ($st) where a refusal was expected"
    grep -q "$f" "$d/$b.tlog" \
      || { cat "$d/$b.tlog" >&2; fail "$b: the refusal does not name the file"; }
    nref=$((nref + 1)); continue
  fi

  # the program assumes a 64-bit long: its answers do not carry here, and the reference
  # compiler is the witness -- either it refuses the source outright, or it runs and the
  # two of us disagree for a reason that is the program's and not the codegen's.
  if inlist "$b" "$narrow"; then nnar=$((nnar + 1)); continue; fi

  # a runtime we do not link: the LINK must be what fails, on an undefined symbol, for
  # at least one of the two builds -- 142-syntax is gcc's side (emutls), the rest are ours
  if inlist "$b" "$hosted"; then
    hitu=0
    for k in t g; do
      if [ $k = t ]; then
        moonrun -t "$tgt" -Dmain=cc_main -c "$f" "$d/$b.$k.o" > "$d/$b.clog" 2>&1 \
          || { hitu=1; continue; }
      else
        # shellcheck disable=SC2086
        arm-none-eabi-gcc $cpu -O0 -w -ffreestanding -Dmain=cc_main -c "$f" -o "$d/$b.$k.o" \
          > "$d/$b.clog" 2>&1 || { hitu=1; continue; }
      fi
      arm-none-eabi-ld -T "$d/link.ld" "$d/start.o" "$d/run.o" "$d/$b.$k.o" "$lg" \
        -o "$d/$b.$k.elf" > "$d/$b.llog" 2>&1 || hitu=1
    done
    [ $hitu = 1 ] \
      || fail "$b: listed as hosted, but both sides built and linked freestanding -- take it off hosted="
    nhost=$((nhost + 1)); continue
  fi

  moonrun -t "$tgt" -Dmain=cc_main -c "$f" "$d/$b.t.o" > "$d/$b.tlog" 2>&1 \
    || { cat "$d/$b.tlog" >&2; fail "$b: mooncc -t $tgt could not build it -- a new refusal, or a name for refuse="; }
  # shellcheck disable=SC2086
  arm-none-eabi-gcc $cpu -O0 -w -ffreestanding -Dmain=cc_main -c "$f" -o "$d/$b.g.o" \
      > "$d/$b.glog" 2>&1 \
    || { cat "$d/$b.glog" >&2; fail "$b: the reference gcc could not build it -- narrow= is where a source gcc rejects goes"; }

  arm-none-eabi-ld -T "$d/link.ld" "$d/start.o" "$d/run.o" "$d/$b.t.o" "$lg" -o "$d/$b.t.elf" \
      > "$d/$b.llog" 2>&1 || { cat "$d/$b.llog" >&2; fail "$b: ld could not bind our object"; }
  arm-none-eabi-ld -T "$d/link.ld" "$d/start.o" "$d/run.o" "$d/$b.g.o" "$lg" -o "$d/$b.g.elf" \
      > "$d/$b.glog" 2>&1 || { cat "$d/$b.glog" >&2; fail "$b: ld could not bind gcc's object -- hosted= is where a libc-needing program goes"; }

  timeout 60 qemu-system-arm -M $mach -semihosting -nographic -kernel "$d/$b.t.elf" < /dev/null \
    > "$d/$b.tout" 2>&1; rt=$?
  timeout 60 qemu-system-arm -M $mach -semihosting -nographic -kernel "$d/$b.g.elf" < /dev/null \
    > "$d/$b.gout" 2>&1; rg=$?

  [ $rt -ne 124 ] || fail "$b: OUR binary timed out on qemu $mach"
  [ $rg -ne 124 ] || fail "$b: GCC's binary timed out on qemu $mach -- the program, not us"
  ! grep -q "qemu: fatal" "$d/$b.tout" \
    || fail "$b: our binary FAULTED on $mach ($(head -1 "$d/$b.tout")); gcc answered $rg"
  ! grep -q "qemu: fatal" "$d/$b.gout" \
    || fail "$b: GCC'S binary faulted on $mach -- the harness or the program, not our codegen"
  [ $rt -eq $rg ] || fail "$b: ours $rt, gcc $rg -- same source, same machine, one compiler"

  # ⚠ A PASSED CASE IS DEAD WEIGHT: `fail` exits, so reaching here means every leg agreed
  # and nothing downstream reads these again. A failing one keeps all of it.
  rm -f "$d/$b.t.o" "$d/$b.g.o" "$d/$b.t.elf" "$d/$b.g.elf" \
        "$d/$b.tlog" "$d/$b.glog" "$d/$b.llog" "$d/$b.tout" "$d/$b.gout"
  nrun=$((nrun + 1))
done

[ $nrun -gt 0 ] || fail "no programs ran from test/cc/"
echo "$name: $nrun programs answer on qemu $mach exactly as arm-none-eabi-gcc's build of the same source does; $nref refuse cleanly, $nhost want a libc we do not link, $nnar assume a 64-bit long"
