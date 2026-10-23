#!/bin/sh
# test/gate/ccthumb.sh -- the C battery on cortex-m: every test/cc/*.c built by
# `mooncc -t thumb1|thumb2` must exit on qemu-system-arm as arm-none-eabi-gcc's build does.
# no libc, so the exit code alone; a fault is qemu's `qemu: fatal`, since a code can look
# like a signal (43-dispatch answers 131). the lists:
#   refuse  mooncc refuses, by name, without a signal
#   hosted  wants a libc or runtime: at least one of the two links fails
#   narrow  assumes a 64-bit long: skipped
# usage: ccthumb.sh TARGET OUTDIR LOVE     (TARGET: thumb1 | thumb2)
. test/gate/skip.sh
. test/gate/cclib.sh
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


for tool in arm-none-eabi-gcc arm-none-eabi-ld qemu-system-arm; do
  command -v $tool > /dev/null 2>&1 || {
    gate_skip "$name: no arm-none-eabi toolchain / qemu-system-arm, skipped"; }
done

# cleared at the start: the last run stays for a post-mortem
d=$ho/cc-$tgt
rm -rf "$d"
mkdir -p "$d"

echo "CCTHUMB $d"

# the startup: vectors, `bl run`, semihosting SYS_EXIT_EXTENDED with run()'s answer.
# the initial sp must lie in the board's sram, or both builds fault alike; a vfp target
# enables CP10/CP11 in CPACR first
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

# main is renamed cc_main for `run`; mem* and strcmp are the floor a compiler may call
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
  echo 'int strcmp(const char *a, const char *b){'
  echo ' while (*a && *a == *b) a++, b++; return (unsigned char) *a - (unsigned char) *b; }'
} > "$d/run.c"

# shellcheck disable=SC2086  # $cpu is a deliberate word list
arm-none-eabi-gcc $cpu -c "$d/start.S" -o "$d/start.o" || fail "as start.S"
arm-none-eabi-gcc $cpu -ffreestanding -O2 -c "$d/run.c" -o "$d/run.o" || fail "gcc run.c"
lg=$(arm-none-eabi-gcc $cpu -print-libgcc-file-name)

# refuse is tested first, so a name may sit in both lists
hosted="72-quals 110-param5 114-rmwlv 134-tentative 135-uac 142-syntax 146-declscope
        147-enumscope 148-tagscope 149-paste 150-alloc 154-blockextern 158-gnukw
        159-stmtexpr 160-rangeinit 162-constexpr 163-bitfields 164-switchtab 315-alloca-stack
        298-malloc-wrap 115-rmwop 165-constcond 166-condconv 283-splitsexpr 228-strictalign
        111-int128 151-w128fuzz 314-u128union 300-aligned-alloc 301-free-checks 302-realloc-grow 303-arena-churn 304-size-classes"
narrow="81-builtins 99-muslimage 104-u32wrap 105-fneg 120-bfinit 125-widelit 144-gnubuiltins 266-vaarg-struct"
# gcc's arm build follows no frame chain past level 1, so it cannot witness 297
nowit="297-frameaddr"

case $tgt in
  thumb2) refuse="68-static-assert 161-enumwide 291-enumahead" ;;
  thumb1) refuse="67-varargs-double 88-varargs-overflow 97-muslrungs 68-static-assert 82-znvalue 85-aggval 100-complex 280-cxf-fuzz 101-vla 102-bigstruct 111-int128
                  117-vastruct 129-sync 151-w128fuzz 314-u128union 161-enumwide 228-strictalign 266-vaarg-struct 291-enumahead" ;;
esac

# v6-m's double varargs need rt.c's soft-float, which is not linked here
[ $tgt = thumb1 ] && hosted="$hosted 71-varargs-sysv"

inlist() { for w in $2; do [ "$w" = "$1" ] && return 0; done; return 1; }

nrun=0; nref=0; nhost=0; nnar=0; nwit=0
for f in test/cc/*.c; do
  b=$(basename "$f" .c)

  if inlist "$b" "$refuse"; then
    refused "$d/$b.tlog" "$f" -t "$tgt" -Dmain=cc_main -c "$f" "$d/$b.t.o"
    nref=$((nref + 1)); continue
  fi

  if inlist "$b" "$narrow"; then nnar=$((nnar + 1)); continue; fi
  if inlist "$b" "$nowit"; then nwit=$((nwit + 1)); continue; fi

  # at least one build or link fails: 142-syntax is gcc's (emutls), the rest ours
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

  # a passed case's files go; a failing one keeps them
  rm -f "$d/$b.t.o" "$d/$b.g.o" "$d/$b.t.elf" "$d/$b.g.elf" \
        "$d/$b.tlog" "$d/$b.glog" "$d/$b.llog" "$d/$b.tout" "$d/$b.gout"
  nrun=$((nrun + 1))
done

[ $nrun -gt 0 ] || fail "no programs ran from test/cc/"
echo "$name: $nrun programs answer on qemu $mach exactly as arm-none-eabi-gcc's build of the same source does; $nref refuse cleanly, $nhost want a libc we do not link, $nnar assume a 64-bit long, $nwit have no gcc witness here"
