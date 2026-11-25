#!/bin/sh
# test/gate/ccbat.sh -- the C battery on a target: every test/cc/*.c built by `mooncc -t TARGET`,
# plain and -Os, must answer as its references do: our x86-64 build, the target's compiler, or
# both. the binaries are built, run as one batch ($RUN before each, on a host for a64), compared.
# the lists, each held to what it says:
#   refuse  mooncc has no lane: it refuses, by name, without a signal
#   wide    not C on ilp32 (a static assert, a bit-field past its type): both refuse
#   narrow  assumes a 64-bit long: the reference fails it, ours runs it to an exit
#   w128    __int128, which the target's gcc has no lane for: the host cc's build is the reference
#   hosted  the reference's libc has gaps, or reads frames otherwise: ours runs it to an exit
#   nolibc  no libc on the board: at least one of the two links fails
#   skip    not held to anything here: assumes a 64-bit long, or no witness
#   nogcc   held to x86-64 alone
#   gnopie  an address as an "i" operand: gcc wants no pie
# usage: ccbat.sh TARGET OUTDIR LOVE   (TARGET: a64 rv64 rv32 xtensa mips wasm arm i386 i386m16 thumb1 thumb2)
. test/gate/skip.sh
. test/gate/a64run.sh
. test/gate/cclib.sh
. test/gate/thumbrt.sh
set -u

tgt=$1
ho=$2
m=$3
name=test_cc$tgt
pretty=$tgt
x64ref=
exitonly=
mflags=
gext=
grun='$RUN'
mach=
GCC=
refuse=
wide=
narrow=
hosted=
w128=
nolibc=
skip=
nogcc=
gnopie=
d=${ho:?}/cc-$tgt
rm -rf "${d:?}"
mkdir -p "$d"

inlist() { for w in $2; do [ "$w" = "$1" ] && return 0; done; return 1; }
first() { for c in "$@"; do command -v "$c" 2>/dev/null && return 0; done; return 0; }
need() { for t in "$@"; do have "$t" || gate_skip "$name: no $t, skipped"; done; }
# a cross gcc with a static libc
gstatic() {
  gf=; inlist "$(basename "$2" .c)" "$gnopie" && gf="-fno-pie -no-pie"
  $GCC -O0 -w -static $gf -o "$1" "$2"
}
a64_via=qemu
int128s="111-int128 151-w128fuzz 314-u128union 352-u128abi 362-w128ops"
# the bare boards': what wants a libc we do not link, and what assumes a 64-bit long; gcc's arm build
# follows no frame chain past level 1, so no witness for 297
boardnolibc="callpark 356-vafnval 72-quals 110-param5 114-rmwlv 134-tentative 135-uac 142-syntax 146-declscope 147-enumscope 148-tagscope 149-paste 150-alloc 154-blockextern 158-gnukw 159-stmtexpr 160-rangeinit 162-constexpr 163-bitfields 164-switchtab 315-alloca-stack 298-malloc-wrap 115-rmwop 165-constcond 166-condconv 283-splitsexpr 228-strictalign 111-int128 151-w128fuzz 314-u128union 352-u128abi 300-aligned-alloc 301-free-checks 302-realloc-grow 303-arena-churn 304-size-classes 345-jmpsave 390-qualon 348-libcmore 353-intuint 355-cplxarg 362-w128ops"
boardskip="354-idioms 81-builtins 99-muslimage 104-u32wrap 105-fneg 120-bfinit 125-widelit 144-gnubuiltins 266-vaarg-struct 297-frameaddr"
narrow32="105-fneg 144-gnubuiltins 152-rotate 266-vaarg-struct"

case $tgt in
  a64)
    a64_how "$m"
    [ -n "$a64_via" ] || gate_skip "$name: skipped (need qemu-aarch64 or an a64 host)"
    x64ref=1
    GCC=${AARCH64_CC:-}
    [ -n "$GCC" ] || GCC=$(first aarch64-linux-gnu-gcc a64-nerves-linux-gnu-gcc)
    [ -n "$GCC" ] || GCC=$(ls /usr/local/data/*/.nerves/artifacts/nerves_toolchain_a64*/bin/a64-nerves-linux-gnu-gcc 2>/dev/null | head -1)
    gnopie="181-asmaddr 242-asmprel64"
    # gcc 16 lays a64's frame record under the locals, and its frame chain above level 0 is its own
    nogcc="160-rangeinit 297-frameaddr"
    gref() { gstatic "$@"; } ;;
  rv64)
    a64_qemu=$(first qemu-riscv64)
    [ -n "$a64_qemu" ] || gate_skip "$name: skipped (need qemu-riscv64)"
    x64ref=1
    GCC=${RISCV64_CC:-}
    [ -n "$GCC" ] || GCC=$(first riscv64-linux-gnu-gcc riscv64-unknown-linux-gnu-gcc riscv64-unknown-elf-gcc)
    refuse="297-frameaddr"
    gref() { gstatic "$@"; } ;;
  wasm)
    NODE=$(first node)
    [ -n "$NODE" ] || gate_skip "$name: skipped (need node)"
    a64_qemu="$NODE $PWD/src/inle/wasm/loader.js"
    x64ref=1
    GCC=${EMCC:-$(first emcc)}
    [ -n "$GCC" ] || [ ! -x /usr/lib/emscripten/emcc ] || GCC=/usr/lib/emscripten/emcc
    grun=$NODE
    gext=.js
    # return addresses, frame chains and label values live off linear memory
    refuse="160-rangeinit 229-labelvalue 256-inline-retaddr 297-frameaddr"
    # clang lacks __builtin_*_overflow_p, emcc's malloc aborts where C answers NULL, its
    # aligned_alloc keeps C11's size rule, its __divsc3 isn't libgcc's
    nogcc="268-overflow-p 298-malloc-wrap 300-aligned-alloc 280-cxf-fuzz"
    gref() { "$GCC" -sMEMORY64=1 -O0 -w -o "$1" "$2"; } ;;
  arm)
    need arm-none-eabi-gcc qemu-arm
    a64_qemu=qemu-arm
    GCC=arm-none-eabi-gcc
    refuse="161-enumwide 364-w128float"
    w128=$int128s
    wide="68-static-assert 120-bfinit"
    narrow=$narrow32
    hosted="72-quals 125-widelit 150-alloc 160-rangeinit 297-frameaddr 298-malloc-wrap 300-aligned-alloc 301-free-checks 348-libcmore"
    gref() { arm-none-eabi-gcc -mcpu=cortex-a53 -mthumb -mfloat-abi=hard -mfpu=fp-armv8 --specs=rdimon.specs -O1 -w -o "$1" "$2" -lm; } ;;
  i386m16)
    . test/gate/m16rt.sh
    m16_board "$d"
    a64_qemu="sh $(cd "$d" && pwd)/m16run.sh"
    pretty="qemu real mode"
    GCC="gcc -m32"
    grun=
    exitonly=1
    mflags="-Dmain=cc_main -c"
    refuse="$int128s 364-w128float"
    wide="68-static-assert 120-bfinit 161-enumwide"
    narrow=$narrow32
    # the boards' lists, a hosted reference building them all; past the 32K board; a libgcc complex
    # divide (no 16-bit libgcc); sections the rom script lays nowhere
    skip="$boardskip $boardnolibc 215-tablerows 216-namedvarargs 261-overflow-types 351-far-index 100-complex 280-cxf-fuzz 250-nullcmp-static 336-flexinit-section"
    gref() { gcc -m32 -msse2 -mfpmath=sse -O0 -w -o "$1" "$2" -lm; } ;;
  i386)
    a64_qemu=
    GCC="gcc -m32"
    refuse="$int128s 364-w128float"
    wide="68-static-assert 120-bfinit 161-enumwide"
    narrow=$narrow32
    gref() { gcc -m32 -msse2 -mfpmath=sse -w -o "$1" "$2" -lm; } ;;
  rv32)
    # the esp32-c6's isa under qemu-riscv32's user mode: no libc, _start exits by ecall. ours is
    # mooncc's bare link with rt.c; clang's build is the witness, by ld.lld over rv32sf.c's libgcc names
    for tool in clang ld.lld qemu-riscv32; do have $tool || gate_skip "$name: no $tool, skipped"; done
    a64_qemu=qemu-riscv32
    pretty=qemu-riscv32
    GCC=clang
    exitonly=1
    mflags="-os none -Dmain=cc_main -c"
    refuse="$int128s 364-w128float 297-frameaddr 395-asmwide"
    wide="68-static-assert 120-bfinit 161-enumwide"
    narrow="105-fneg 144-gnubuiltins 266-vaarg-struct"
    # no libc on the board, and no libgcc: what a link of either side cannot close
    nolibc="callpark 100-complex 110-param5 114-rmwlv 115-rmwop 134-tentative 135-uac 146-declscope 147-enumscope
      148-tagscope 149-paste 150-alloc 154-blockextern 158-gnukw 159-stmtexpr 160-rangeinit 162-constexpr
      163-bitfields 164-switchtab 165-constcond 166-condconv 178-toplevelasm 228-strictalign 280-cxf-fuzz
      283-splitsexpr 298-malloc-wrap 300-aligned-alloc 301-free-checks 302-realloc-grow 303-arena-churn
      304-size-classes 315-alloca-stack 345-jmpsave 348-libcmore 353-intuint 354-idioms 355-cplxarg
      356-vafnval 390-qualon"
    # clang refuses these here; it folds a long shifted past 31 as gcc does not (152, 378), and a
    # _Thread_local of its own wants a tp the board never sets (142)
    nogcc="72-quals 95-libcfill 140-fsuffix 176-cleanup 268-overflow-p 269-builtin-alloca 308-negnan
      311-coldsplit 315-rgnnest 375-splitcall 380-initcover 383-vfpimm 385-packedinit 142-syntax
      152-rotate 378-extbounds"
    rvf="--target=riscv32-unknown-elf -march=rv32imac -mabi=ilp32 -mno-relax"
    # main(argc, argv) gets a hosted run's 1 and its name, so an argc a program reads is no register's leftover
    { echo 'int cc_main(int, char **);'
      echo 'int main(void){ static char n[] = "t", *av[] = { n, 0 }; return cc_main(1, av); }'
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
    { echo 'int main(void);'
      echo 'void _start(void){ int r = main();'
      echo ' __asm__ volatile("mv a0, %0\n\tli a7, 93\n\tecall" :: "r"(r) : "a0", "a7"); for (;;); }'
    } > "$d/start.c"
    moonrun -t rv32 -os none -c -o "$d/run.o" "$d/run.c" || fail "mooncc run.c"
    moonrun -t rv32 -os none -c -o "$d/start.o" "$d/start.c" || fail "mooncc start.c"
    moonrun -t rv32 -os none -c -o "$d/rt.o" src/apps/moon/lib/rt.c || fail "mooncc rt.c"
    clang $rvf -O1 -ffreestanding -fno-builtin -c "$d/run.c" -o "$d/run.cc.o" || fail "clang run.c"
    clang $rvf -O1 -ffreestanding -c "$d/start.c" -o "$d/start.cc.o" || fail "clang start.c"
    moonrun -t rv32 -os none -c -o "$d/sf.o" test/gate/rv32sf.c || fail "mooncc rv32sf.c"
    blink() { moonrun -t rv32 -os none -nostdlib -Ttext 0x10000 -o "$2" "$d/start.o" "$1" "$d/run.o" "$d/rt.o"; }
    gref() {
      clang $rvf -O0 -w -ffreestanding -Dmain=cc_main -c "$2" -o "$1.o" \
        && ld.lld -o "$1" "$d/start.cc.o" "$d/run.cc.o" "$1.o" "$d/sf.o" "$d/rt.o"
    } ;;
  mips)
    # gwen's routers' isa, big-endian mips32r2 o32, under qemu-mips's 24Kc: bare as rv32's, _start
    # exits by syscall 4001. clang's build is the witness, linked by ld.lld over rv32sf.c's libgcc
    # names and rt.c, both mooncc's: clang's code calls ours across o32
    for tool in clang ld.lld qemu-mips; do have $tool || gate_skip "$name: no $tool, skipped"; done
    a64_qemu="qemu-mips -cpu 24Kc"
    pretty=qemu-mips
    GCC=clang
    exitonly=1
    mflags="-os none -Dmain=cc_main -c"
    # no gas dialect: a target asm refuses
    refuse="$int128s 364-w128float 297-frameaddr 327-bcp-splice 357-asmoutaddr 395-asmwide"
    wide="68-static-assert 120-bfinit 161-enumwide"
    narrow="105-fneg 144-gnubuiltins 266-vaarg-struct"
    nolibc="callpark 100-complex 110-param5 114-rmwlv 115-rmwop 134-tentative 135-uac 146-declscope 147-enumscope
      148-tagscope 149-paste 150-alloc 154-blockextern 158-gnukw 159-stmtexpr 160-rangeinit 162-constexpr
      163-bitfields 164-switchtab 165-constcond 166-condconv 228-strictalign 280-cxf-fuzz
      283-splitsexpr 298-malloc-wrap 300-aligned-alloc 301-free-checks 302-realloc-grow 303-arena-churn
      304-size-classes 315-alloca-stack 345-jmpsave 348-libcmore 353-intuint 354-idioms 355-cplxarg
      356-vafnval 390-qualon"
    nogcc="72-quals 95-libcfill 140-fsuffix 176-cleanup 268-overflow-p 269-builtin-alloca 308-negnan
      311-coldsplit 315-rgnnest 375-splitcall 380-initcover 383-vfpimm 385-packedinit 142-syntax
      152-rotate 378-extbounds"
    mpf="--target=mips-unknown-elf -march=mips32r2 -msoft-float -mno-abicalls -fno-pic -G0"   # no gp: no small data
    { echo 'int cc_main(int, char **);'
      echo 'int main(void){ static char n[] = "t", *av[] = { n, 0 }; return cc_main(1, av); }'
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
    # exit's status in a0 (holo's r2), 4001 in v0 (r0)
    { echo 'int main(void);'
      echo 'void _start(void){ int r = main();'
      echo ' __attribute__((holo)) asm volatile("mov r2, %0\n\tli r0, 4001\n\tsys" :: "r"(r) : "r0", "r2"); for (;;); }'
    } > "$d/start.c"
    { echo 'int main(void);'
      echo 'void _start(void){ int r = main();'
      echo ' __asm__ volatile("move $4, %0\n\tli $2, 4001\n\tsyscall" :: "r"(r) : "$2", "$4"); for (;;); }'
    } > "$d/ccstart.c"
    moonrun -t mips -os none -c -o "$d/run.o" "$d/run.c" || fail "mooncc run.c"
    moonrun -t mips -os none -c -o "$d/start.o" "$d/start.c" || fail "mooncc start.c"
    moonrun -t mips -os none -c -o "$d/rt.o" src/apps/moon/lib/rt.c || fail "mooncc rt.c"
    moonrun -t mips -os none -c -o "$d/sf.o" test/gate/rv32sf.c || fail "mooncc rv32sf.c"
    clang $mpf -O1 -ffreestanding -fno-builtin -c "$d/run.c" -o "$d/run.cc.o" || fail "clang run.c"
    clang $mpf -O1 -ffreestanding -c "$d/ccstart.c" -o "$d/start.cc.o" || fail "clang start.c"
    blink() { moonrun -t mips -os none -nostdlib -Ttext 0x400000 -o "$2" "$d/start.o" "$1" "$d/run.o" "$d/rt.o"; }
    gref() {
      clang $mpf -O0 -w -ffreestanding -Dmain=cc_main -c "$2" -o "$1.o" \
        && ld.lld -e _start -Ttext=0x400000 -o "$1" "$d/start.cc.o" "$d/run.cc.o" "$1.o" "$d/sf.o" "$d/rt.o"
    } ;;
  xtensa)
    # the esp32's lx6 under qemu-xtensa's user mode (dc233c: no mul32_high, which moon leaves be),
    # bare as rv32's. no xtensa clang: the witness is our rv32 build, ILP32 with an unsigned char
    # as xtensa is, on qemu-riscv32, itself held to clang by test_ccrv32
    for tool in qemu-xtensa qemu-riscv32; do have $tool || gate_skip "$name: no $tool, skipped"; done
    a64_qemu="qemu-xtensa -cpu dc233c"
    pretty=qemu-xtensa
    GCC="mooncc -t rv32"
    grun=qemu-riscv32
    exitonly=1
    mflags="-os none -Dmain=cc_main -c"
    # no inline atomics yet (s32c1i): a __sync builtin refuses, as v6-M's; no gas dialect, so a
    # target asm refuses
    refuse="$int128s 364-w128float 297-frameaddr 129-sync 327-bcp-splice 357-asmoutaddr 395-asmwide"
    wide="68-static-assert 120-bfinit 161-enumwide"
    # a 64-bit long assumed, past an ILP32 word: a shift by 63 and the like, no answer to hold;
    # 180 takes riscv's template on the reference and none here
    skip="105-fneg 144-gnubuiltins 266-vaarg-struct 152-rotate 180-asmsections"
    nolibc="callpark 100-complex 110-param5 114-rmwlv 115-rmwop 134-tentative 135-uac 146-declscope 147-enumscope
      148-tagscope 149-paste 150-alloc 154-blockextern 158-gnukw 159-stmtexpr 160-rangeinit 162-constexpr
      163-bitfields 164-switchtab 165-constcond 166-condconv 228-strictalign 280-cxf-fuzz
      283-splitsexpr 298-malloc-wrap 300-aligned-alloc 301-free-checks 302-realloc-grow 303-arena-churn
      304-size-classes 315-alloca-stack 345-jmpsave 348-libcmore 353-intuint 354-idioms 355-cplxarg
      356-vafnval 390-qualon"
    { echo 'int cc_main(int, char **);'
      echo 'int main(void){ static char n[] = "t", *av[] = { n, 0 }; return cc_main(1, av); }'
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
    # exit_group is 119, its argument in a6 (holo's r4, the frame base: no clobber names it; the call never returns)
    { echo 'int main(void);'
      echo 'void _start(void){ int r = main();'
      echo ' __attribute__((holo)) asm volatile("mov r4, %0\n\tli r0, 119\n\tsys" :: "r"(r) : "r0"); for (;;); }'
    } > "$d/start.c"
    moonrun -t xtensa -c -o "$d/run.o" "$d/run.c" || fail "mooncc run.c"
    moonrun -t xtensa -c -o "$d/start.o" "$d/start.c" || fail "mooncc start.c"
    moonrun -t xtensa -c -o "$d/rt.o" src/apps/moon/lib/rt.c || fail "mooncc rt.c"
    blink() { moonrun -t xtensa -nostdlib -Ttext 0x10000 -o "$2" "$d/start.o" "$1" "$d/run.o" "$d/rt.o"; }
    { echo 'int main(void);'
      echo 'void _start(void){ int r = main();'
      echo ' __asm__ volatile("mv a0, %0\n\tli a7, 93\n\tecall" :: "r"(r) : "a0", "a7"); for (;;); }'
    } > "$d/rvstart.c"
    moonrun -t rv32 -os none -c -o "$d/rvstart.o" "$d/rvstart.c" || fail "mooncc -t rv32 rvstart.c"
    moonrun -t rv32 -os none -c -o "$d/rvrun.o" "$d/run.c" || fail "mooncc -t rv32 run.c"
    moonrun -t rv32 -os none -c -o "$d/rvrt.o" src/apps/moon/lib/rt.c || fail "mooncc -t rv32 rt.c"
    gref() {
      moonrun -t rv32 -os none -Dmain=cc_main -c -o "$1.o" "$2" \
        && moonrun -t rv32 -os none -nostdlib -Ttext 0x10000 -o "$1" "$d/rvstart.o" "$1.o" "$d/rvrun.o" "$d/rvrt.o"
    } ;;
  thumb1|thumb2)
    thumb_board $tgt "$d"
    if [ $tgt = thumb1 ]; then
      refuse="68-static-assert $int128s 364-w128float 129-sync 161-enumwide"
    else
      refuse="68-static-assert 364-w128float 161-enumwide"
    fi
    a64_qemu="qemu-system-arm -M $mach -semihosting -nographic -kernel"
    pretty="qemu $mach"
    GCC=arm-none-eabi-gcc
    exitonly=1
    mflags="-Dmain=cc_main -c"
    nolibc=$boardnolibc
    skip=$boardskip
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
    arm-none-eabi-gcc $cpu -ffreestanding -O2 -c "$d/run.c" -o "$d/run.o" || fail "gcc run.c"
    blink() { arm-none-eabi-ld -T "$d/link.ld" "$d/start.o" "$d/run.o" "$1" "$lg" -o "$2"; }
    gref() {
      arm-none-eabi-gcc $cpu -O0 -w -ffreestanding -Dmain=cc_main -c "$2" -o "$1.o" && blink "$1.o" "$1"
    } ;;
  *) echo "ccbat.sh: unknown target $tgt" >&2; exit 1 ;;
esac
[ "$(uname -m)" = x86_64 ] || [ -z "$x64ref" ] || gate_skip "$name: skipped (the reference build is native x86-64)"
[ "$(uname -m)" = x86_64 ] || { [ "$tgt" != i386 ] && [ "$tgt" != i386m16 ]; } || gate_skip "$name: skipped (runs i386 binaries natively on x86-64)"
case $tgt in
  arm|i386)
    printf '#include <stdio.h>\nint main(void){puts("ok");return 0;}\n' > "$d/probe.c"
    gref "$d/probe" "$d/probe.c" > /dev/null 2>&1 && [ "$($a64_qemu "$d/probe")" = ok ] \
      || gate_skip "$name: skipped ($GCC cannot build and run a hello here)" ;;
esac
where=$([ "$a64_via" = host ] && echo "on an a64 host" || echo "on $pretty")

# a program's own flags, off its first line: /* mooncc -t ARCH: FLAGS */; x64 builds without
tflags() { sed -n "1s|^/\* mooncc -t $tgt: \(.*\) \*/\$|\1|p" "$1"; }
# ours: compile $2 to $1 with flags $3.., a board's object linked
ours() {
  o=$1; f=$2; shift 2
  moonrun -t "$tgt" $mflags $(tflags "$f") "$@" -o "$o" "$f" || return 1
  [ -z "$exitonly" ] || { mv "$o" "$o.o" && blink "$o.o" "$o"; }
}

r=$d/run
a64_jobs "$r"
nref=0; nwide=0; nnar=0; nhost=0; nlibc=0; nskip=0
progs=
for f in test/cc/*.c; do
  b=$(basename "$f" .c)
  if inlist "$b" "$refuse"; then
    refused "$d/$b.tlog" "$f" -t "$tgt" $mflags -o "$d/$b.t" "$f"
    nref=$((nref + 1)); continue
  fi
  if inlist "$b" "$wide"; then
    gref "$d/$b.g" "$f" > "$d/$b.glog" 2>&1 && fail "$b: $GCC builds a program listed as wide -- take it off the list"
    refused "$d/$b.tlog" "$f" -t "$tgt" -o "$d/$b.t" "$f"
    nwide=$((nwide + 1)); continue
  fi
  if inlist "$b" "$skip"; then nskip=$((nskip + 1)); continue; fi
  if inlist "$b" "$nolibc"; then
    ours "$d/$b.t" "$f" > "$d/$b.tlog" 2>&1 && gref "$d/$b.g" "$f" > "$d/$b.glog" 2>&1 \
      && fail "$b: listed as nolibc, but both sides built and linked freestanding -- take it off the list"
    nlibc=$((nlibc + 1)); continue
  fi

  if [ -n "$x64ref" ]; then
    moonrun -o "$d/$b.x" "$f" > "$d/$b.xlog" 2>&1 \
      || { cat "$d/$b.xlog" >&2; fail "$b: mooncc could not build the x86-64 reference"; }
    timeout 60 "$d/$b.x" > "$d/$b.xout" 2>&1; echo $? > "$d/$b.xrc"
  fi

  for os in t s; do
    fl=; [ $os = s ] && fl=-Os
    ours "$r/$b.$os" "$f" $fl > "$d/$b.${os}log" 2>&1 \
      || { cat "$d/$b.${os}log" >&2; fail "$b: mooncc -t $tgt $fl could not build it -- a new refusal, or a name for refuse="; }
    a64_job "$b.$os" "timeout 60 \$RUN ./$b.$os"
  done

  if inlist "$b" "$w128"; then
    cc -w -O1 -o "$r/$b.g" "$f" > "$d/$b.glog" 2>&1 || { cat "$d/$b.glog" >&2; fail "$b: the host cc could not build it"; }
    a64_job "$b.g" "timeout 60 ./$b.g"
  elif [ -n "$GCC" ] && ! inlist "$b" "$nogcc $hosted"; then
    gref "$r/$b.g$gext" "$f" > "$d/$b.glog" 2>&1 \
      || { cat "$d/$b.glog" >&2; fail "$b: $GCC could not build it"; }
    a64_job "$b.g" "timeout 60 $grun ./$b.g$gext"
  fi
  progs="$progs $b"
done

# what a target holds beside the battery
if [ $tgt = rv32 ]; then
  # a bare link answers __bss_start__/__bss_end__ with its .bss, which a board's startup clears
  cat > "$d/bssb.c" <<'EOF'
extern char __bss_start__[], __bss_end__[];
static int zs[16];
static char tail;
int cc_main(void) {
  if ((char *) zs < __bss_start__ || &tail >= __bss_end__) return 1;
  if (__bss_end__ - __bss_start__ < (long) sizeof zs + 1) return 2;
  return zs[3] + tail ? 3 : 42;
}
EOF
  ours "$r/bssb.t" "$d/bssb.c" > "$d/bssb.log" 2>&1 \
    || { cat "$d/bssb.log" >&2; fail "bss: mooncc's bare link could not answer the .bss brackets"; }
  a64_job bssb.t "timeout 60 \$RUN ./bssb.t"
fi
if [ $tgt = a64 ]; then
  # the packed program again under -mstrict-align
  moonrun -t a64 -mstrict-align -o "$r/sa279.t" test/cc/279-packed-bitfield.c > "$d/sa279.log" 2>&1 \
    || { cat "$d/sa279.log" >&2; fail "strict-align: mooncc could not build 279-packed-bitfield.c"; }
  a64_job sa279.t "timeout 60 \$RUN ./sa279.t"

  # abi64/host.c by mooncc linked with clang's peer.c, each calling the other
  command -v clang > /dev/null 2>&1 || gate_skip "$name: no clang for the abi64 half"
  clang --target=aarch64-linux-gnu -O2 -ffreestanding -fno-stack-protector -c -o "$d/peer.o" test/cc/abi64/peer.c 2> "$d/peer.log" \
    || { cat "$d/peer.log" >&2; fail "abi64: clang could not build peer.c"; }
  moonrun -t a64 -o "$r/abi64.t" test/cc/abi64/host.c "$d/peer.o" > "$d/abi64.log" 2>&1 \
    || { cat "$d/abi64.log" >&2; fail "abi64: mooncc could not build or link host.c"; }
  a64_job abi64.t "timeout 60 \$RUN ./abi64.t"
  # __int128 across them: the even register pair, the 16-aligned stack pair
  clang --target=aarch64-linux-gnu -O2 -ffreestanding -fno-stack-protector -c -o "$d/peer128.o" test/cc/abi128/peer.c 2> "$d/peer128.log" \
    || { cat "$d/peer128.log" >&2; fail "abi128: clang could not build peer.c"; }
  moonrun -t a64 -o "$r/abi128.t" test/cc/abi128/host.c "$d/peer128.o" > "$d/abi128.log" 2>&1 \
    || { cat "$d/abi128.log" >&2; fail "abi128: mooncc could not build or link host.c"; }
  a64_job abi128.t "timeout 60 \$RUN ./abi128.t"
  # thread-locals: clang's at -O0 and -O2 under mooncc's link and moonlibc's threads, a
  # program calling no libc, and every load and store width's offset (ldst64.s)
  clang --target=aarch64-linux-gnu -fno-pie -c -o "$d/tlsd.o" test/cc/tls/defs.c 2> "$d/tls.log" \
    || { cat "$d/tls.log" >&2; fail "tls: clang could not build defs.c"; }
  for o in 0 2; do
    clang --target=aarch64-linux-gnu -O$o -fno-pie -c -o "$d/tlsp$o.o" test/cc/tls/peer.c 2> "$d/tls.log" \
      || { cat "$d/tls.log" >&2; fail "tls: clang -O$o could not build peer.c"; }
    moonrun -t a64 -no-pie -Wl,-z,noexecstack -o "$r/tls$o.t" test/cc/tls/host.c "$d/tlsp$o.o" "$d/tlsd.o" > "$d/tls.log" 2>&1 \
      || { cat "$d/tls.log" >&2; fail "tls: mooncc could not link clang -O$o's thread-locals"; }
    a64_job tls$o.t "timeout 60 \$RUN ./tls$o.t"
  done
  moonrun -t a64 -o "$r/tlsb.t" test/cc/tls/bare.c "$d/tlsp2.o" "$d/tlsd.o" > "$d/tls.log" 2>&1 \
    || { cat "$d/tls.log" >&2; fail "tls: mooncc could not link bare.c"; }
  a64_job tlsb.t "timeout 60 \$RUN ./tlsb.t"
  clang --target=aarch64-linux-gnu -c -o "$d/ldst64.o" test/cc/tls/ldst64.s 2> "$d/tls.log" \
    || { cat "$d/tls.log" >&2; fail "tls: clang could not assemble ldst64.s"; }
  moonrun -t a64 -o "$r/ldst64.t" test/cc/tls/ldst64.c "$d/ldst64.o" > "$d/tls.log" 2>&1 \
    || { cat "$d/tls.log" >&2; fail "tls: mooncc could not link ldst64.s"; }
  a64_job ldst64.t "timeout 60 \$RUN ./ldst64.t"

  # the landing law, against clang on protect/units.c: each fn's landing, autiasp before
  # every exit and after every frame record's ldp, no packed access wider, the notes equal
  hc=${HEARTS_CLANG:-$HOME/.cache/hearts/llvm-22.1.8}/bin/clang
  [ -x "$hc" ] || hc=clang
  command -v llvm-objdump > /dev/null 2>&1 && command -v llvm-readelf > /dev/null 2>&1 \
    || gate_skip "$name: no llvm-objdump or llvm-readelf for the landing law"
  bp="-mbranch-protection=pac-ret+bti -mstrict-align"
  "$hc" --target=aarch64-linux-gnu -O2 $bp -c -o "$d/land.c.o" test/cc/protect/units.c 2> "$d/land.log" \
    || { cat "$d/land.log" >&2; fail "landing: clang could not build units.c"; }
  moonrun -t a64 -c $bp -o "$d/land.m.o" test/cc/protect/units.c > "$d/land.log" 2>&1 \
    || { cat "$d/land.log" >&2; fail "landing: mooncc could not build units.c"; }
  # L fn landing | W fn widest-packed-access | BAD fn why
  land() {
    llvm-objdump -dr --no-show-raw-insn "$1" | awk '
      function wd(m, ops,   r) {
        if (m ~ /^(ld|st)(u?r|ur)s?b$/ || m ~ /^ldu?rsb$/) return 1
        if (m ~ /^(ld|st)(u?r|ur)s?h$/ || m ~ /^ldu?rsh$/) return 2
        if (m ~ /^ldu?rsw$/) return 4
        r = substr(ops, 1, 1)
        return r == "x" || r == "d" ? 8 : r == "q" ? 16 : r == "h" ? 2 : r == "b" ? 1 : 4
      }
      function out() { if (fn ~ /^pk_/) print "W", fn, w }
      /^[0-9a-f]+ </ { if (fn != "") out(); fn = $2; gsub(/[<>:]/, "", fn); first = 1; pac = 0; w = 0; prev = ""; pprev = ""; ldp = 0; next }
      /R_AARCH64_JUMP26/ { if (pac && prev ~ /^b\t/ && pprev != "autiasp") print "BAD", fn, "a tail branch without autiasp"; next }
      /^ +[0-9a-f]+:/ {
        l = $0; sub(/^ +[0-9a-f]+:[ \t]+/, "", l); sub(/[ \t]*(\/\/|<).*$/, "", l)
        if (first) { c = l == "bti\tc" ? "btic" : l == "paciasp" ? "pac" : "-"; print "L", fn, c; pac = c == "pac"; first = 0 }
        if (pac && (l == "ret" || l ~ /^br\t/) && prev != "autiasp") print "BAD", fn, "an exit without autiasp: " l
        if (ldp && l != "autiasp") print "BAD", fn, "a frame record restored without autiasp"
        ldp = l ~ /^ldp\tx29, x30/
        split(l, f, "\t"); m = f[1]
        if (m ~ /^(ld|st)(u?r|p)/ && m !~ /x(r|p)$/ && match(l, /\[[a-z0-9]+/)) {
          b = substr(l, RSTART + 1, RLENGTH - 1)
          if (b != "sp" && b != "x29") { k = wd(m, f[2]); if (k > w) w = k }
        }
        pprev = prev; prev = l
      }
      END { if (fn != "") out() }'
  }
  land "$d/land.c.o" > "$d/land.c"
  land "$d/land.m.o" > "$d/land.m"
  grep '^BAD' "$d/land.m" >&2 && fail "landing: mooncc's exits (above)"
  grep '^L' "$d/land.c" | sort > "$d/land.cl"
  grep '^L' "$d/land.m" | sort > "$d/land.ml"
  cmp -s "$d/land.cl" "$d/land.ml" || { diff "$d/land.cl" "$d/land.ml" >&2; fail "landing: a fn lands where clang's does not (clang <, mooncc >)"; }
  grep '^W' "$d/land.m" | while read -r _ fn k; do
    kc=$(grep "^W $fn " "$d/land.c" | cut -d' ' -f3)
    [ "$k" -le "${kc:-0}" ] || { echo "landing: $fn reads $k bytes at once where clang reads $kc" >&2; exit 1; }
  done || fail "landing: a packed access wider than clang's"
  for s in .note.gnu.property .ARM.attributes; do
    llvm-readelf -x $s "$d/land.c.o" | grep '^ *0x' > "$d/land.cs"
    llvm-readelf -x $s "$d/land.m.o" | grep '^ *0x' > "$d/land.ms"
    [ -s "$d/land.cs" ] && cmp -s "$d/land.cs" "$d/land.ms" \
      || { diff "$d/land.cs" "$d/land.ms" >&2; fail "landing: $s differs from clang's"; }
  done
  echo "landing: $(grep -c '^L' "$d/land.m") fns land as clang $("$hc" --version | sed -n '1s/.*version //p')'s do, their exits authenticate, packed reads go by its widths, the notes match"
fi

a64_run "$r" || fail "the $pretty batch did not come back"

if [ $tgt = rv32 ]; then
  [ "$(cat "$r/res/bssb.t.rc")" -eq 42 ] || { cat "$r/res/bssb.t.out" >&2; fail "bss: a bare rv32 link answers $(cat "$r/res/bssb.t.rc") for its .bss brackets"; }
  echo "bss: a bare rv32 link brackets its own .bss with __bss_start__/__bss_end__"
  # the hosted leg: what the board cannot link runs over moonlibc on linux, held to the arm
  # build (ilp32 and an unsigned char too, itself held to gcc by test_ccarm)
  if have qemu-arm; then
    nh=0
    for b in $nolibc; do
      f=test/cc/$b.c
      moonrun -t rv32 -o "$d/$b.h" "$f" > "$d/$b.hlog" 2>&1 || { cat "$d/$b.hlog" >&2; fail "$b: a hosted rv32 link failed"; }
      moonrun -t arm -o "$d/$b.ha" "$f" > "$d/$b.halog" 2>&1 || { cat "$d/$b.halog" >&2; fail "$b: the arm witness failed to build"; }
      { timeout 60 qemu-riscv32 "$d/$b.h"; echo "rc $?"; } > "$d/$b.hout" 2>&1
      { timeout 60 qemu-arm "$d/$b.ha"; echo "rc $?"; } > "$d/$b.haout" 2>&1
      cmp -s "$d/$b.hout" "$d/$b.haout" || { diff "$d/$b.haout" "$d/$b.hout" | head -10 >&2; fail "$b: hosted rv32 and arm disagree"; }
      nh=$((nh + 1))
    done
    echo "hosted: $nh programs the board cannot link run over moonlibc on qemu-riscv32 as on arm"
  else
    gate_partly "  (the hosted rv32 leg skipped: no qemu-arm for its witness)"
  fi
fi
if [ $tgt = mips ]; then
  # the hosted leg, as rv32's: what the board cannot link, and test/libc's programs whose output
  # neither a 64-bit long nor mips's own numbers move, over moonlibc on linux, held to arm's
  if have qemu-arm; then
    nh=0
    mlibc="altstack buf cal ctype elf exec fnmatch gen line mem mstream odds opt rbuf shell sort str terrno thread"
    for b in $nolibc $mlibc; do
      f=test/cc/$b.c; [ -f "$f" ] || f=test/libc/$b.c
      moonrun -t mips -os linux -Itest/libc -o "$d/$b.h" "$f" > "$d/$b.hlog" 2>&1 || { cat "$d/$b.hlog" >&2; fail "$b: a hosted mips link failed"; }
      moonrun -t arm -Itest/libc -o "$d/$b.ha" "$f" > "$d/$b.halog" 2>&1 || { cat "$d/$b.halog" >&2; fail "$b: the arm witness failed to build"; }
      { timeout 120 qemu-mips -cpu 24Kc "$d/$b.h"; echo "rc $?"; } > "$d/$b.hout" 2>&1
      { timeout 120 qemu-arm "$d/$b.ha"; echo "rc $?"; } > "$d/$b.haout" 2>&1
      cmp -s "$d/$b.hout" "$d/$b.haout" || { diff "$d/$b.haout" "$d/$b.hout" | head -10 >&2; fail "$b: hosted mips and arm disagree"; }
      nh=$((nh + 1))
    done
    echo "hosted: $nh programs run over moonlibc on qemu-mips as on arm"
  else
    gate_partly "  (the hosted mips leg skipped: no qemu-arm for its witness)"
  fi
fi
if [ $tgt = a64 ]; then
  [ "$(cat "$r/res/sa279.t.rc")" -eq 0 ] || { cat "$r/res/sa279.t.out" >&2; fail "strict-align: 279-packed-bitfield.c answers wrong under -mstrict-align"; }
  [ "$(cat "$r/res/abi64.t.rc")" -eq 0 ] || { cat "$r/res/abi64.t.out" >&2; fail "abi64: mooncc and clang disagree on AAPCS64"; }
  tail -1 "$r/res/abi64.t.out"
  [ "$(cat "$r/res/abi128.t.rc")" -eq 0 ] || { cat "$r/res/abi128.t.out" >&2; fail "abi128: mooncc and clang disagree on AAPCS64's __int128"; }
  tail -1 "$r/res/abi128.t.out"
  for t in tls0 tls2 tlsb ldst64; do
    [ "$(cat "$r/res/$t.t.rc")" -eq 0 ] || { cat "$r/res/$t.t.out" >&2; fail "tls: $t answers $(cat "$r/res/$t.t.rc") $where"; }
  done
  readelf -lW "$r/tls2.t" | grep -q ' TLS ' || fail "tls: the a64 link laid no PT_TLS"
  echo "tls: clang's thread-locals read right $where, -O0 and -O2, two threads, no libc, every width"
fi
if [ $tgt = i386 ]; then
  # abi386/host.c by mooncc linked with gcc's peer.c, each calling the other, -mregparm 0..3
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
  # skew386: over-aligned locals under -mstack-alignment=4 at each incoming esp, and at the ABI's plain
  for rp in 0 3; do
    gcc -m32 -mregparm=$rp -O1 -w -c -o "$d/skp$rp.o" test/cc/skew386/peer.c 2> "$d/skp.log" \
      || { cat "$d/skp.log" >&2; fail "skew386: gcc could not build peer.c at -mregparm=$rp"; }
    for sa in "-mstack-alignment=4" "-DSKEWS=1"; do
      for fl in -O0 -Os; do
        moonrun -t i386 -mregparm=$rp $sa $fl -c -o "$d/skh.o" test/cc/skew386/host.c > "$d/skh.log" 2>&1 \
          || { cat "$d/skh.log" >&2; fail "skew386: mooncc $sa $fl could not build host.c at -mregparm=$rp"; }
        gcc -m32 -no-pie -o "$d/skew" "$d/skh.o" "$d/skp$rp.o" 2> "$d/skl.log" \
          || { cat "$d/skl.log" >&2; fail "skew386: the link at -mregparm=$rp"; }
        "$d/skew" > "$d/skew.out" 2>&1 || { cat "$d/skew.out" >&2; fail "skew386: mooncc $sa $fl at -mregparm=$rp"; }
      done
    done
  done
  echo "skew386: $(tail -1 "$d/skew.out"), -mstack-alignment=4 and plain, -mregparm 0 and 3"
fi
# a va_list crosses a call as the psABI has it: ours and CC's objects, each calling the other,
# linked and run. va_pair CC FLAGS..
va_pair() {
  vcc=$1; shift
  cat > "$d/.vl.c" <<'EOF'
#include <stdarg.h>
struct box { int tag; va_list ap; };
// a double by its words: no helper, no pool
static int five(double d) { union { double d; long long l; } u = {d}; return u.l == 0x4014LL << 48; }
// the other's: by value, by pointer, in a struct; mine the same here
#define TAKE(nm) long long nm(int n, va_list ap) { \
  long long t = 0; \
  for (int i = 0; i < n; i++) t = t * 10 + va_arg(ap, int); \
  t += va_arg(ap, long long); return t + (five(va_arg(ap, double)) ? 5 : 0); }
#define STEP(nm) int nm(va_list *ap) { return va_arg(*ap, int); }
#define HELD(nm) int nm(struct box *b) { return b->tag + va_arg(b->ap, int); }
#define ONCE(nm, via) long long nm(int n, va_list ap) { va_list c; va_copy(c, ap); long long r = via(n, ap) + via(n, c); va_end(c); return r; }
TAKE(P(take)) STEP(P(step)) HELD(P(held))
extern long long Q(take)(int, va_list), Q(twice)(int, va_list);
extern int Q(step)(va_list *), Q(held)(struct box *);
ONCE(P(twice), Q(take))
long long P(call)(int n, ...) {
  va_list ap, b; struct box k; k.tag = 7;
  va_start(ap, n);
  long long r = Q(take)(n, ap);                      // 528, the caller's list where it was
  if (Q(take)(n, ap) != r || Q(twice)(n, ap) != 2 * r) return -1;
  va_copy(b, ap);
  if (Q(step)(&b) != 1 || va_arg(b, int) != 2 || Q(step)(&b) != 3) return -2;
  if (va_arg(b, long long) != 400 || !five(va_arg(b, double))) return -3;
  va_copy(k.ap, ap);
  if (Q(held)(&k) != 8 || Q(held)(&k) != 9) return -4;
  va_end(k.ap), va_end(b), va_end(ap);
  return r; }
EOF
  printf '%s\n' '#define P(x) m_##x' '#define Q(x) g_##x' '#include ".vl.c"' \
    'extern long long g_call(int, ...);' \
    'int main(void) { return m_call(3, 1, 2, 3, 400LL, 5.0) == 528 && g_call(3, 1, 2, 3, 400LL, 5.0) == 528 ? 42 : 1; }' > "$d/.vm.c"
  printf '%s\n' '#define P(x) g_##x' '#define Q(x) m_##x' '#include ".vl.c"' > "$d/.vp.c"
  $vcc -c -O2 -w -ffreestanding -fno-stack-protector -fno-pic -fno-asynchronous-unwind-tables -fno-unwind-tables -o "$d/vp.o" "$d/.vp.c" || fail "va_list: ${vcc%% *} could not build the reference"
  for o in "" -O2 -Os; do
    moonrun -t $tgt $o "$@" -o "$d/vpt" "$d/.vm.c" "$d/vp.o" > "$d/vp.log" 2>&1 || { cat "$d/vp.log" >&2; fail "va_list: mooncc -t $tgt $o"; }
    timeout 60 $a64_qemu "$d/vpt"; a=$?
    [ $a -eq 42 ] || fail "va_list: $o against ${vcc%% *}'s object (got $a want 42)"
  done
  echo "va_list: ours and ${vcc%% *}'s walk each other's, -O0 -O2 -Os"
}
# the callee-saved file crosses a call whole: each shape of ours called from CC's stub, which
# fills r4-r11 and d8-d15 before and reads them after. cs_file CC FLAGS..
cs_file() {
  scc=$1; shift
  cat > "$d/.cg.c" <<'EOF'
// chk fills r4-r11 and d8-d15, calls f(x), and answers f's value only if each came back
__attribute__((naked)) int chk(int (*f)(int), int x) {
  __asm__(
    "push {r4-r11, lr}\n"
    "vpush {d8-d15}\n"
    "mov r12, r0\n"
    "mov r0, r1\n"
    "ldr r4, =0x44444444\n ldr r5, =0x55555555\n ldr r6, =0x66666666\n ldr r7, =0x77777777\n"
    "ldr r8, =0x88888888\n ldr r9, =0x99999999\n ldr r10, =0xaaaaaaaa\n ldr r11, =0xbbbbbbbb\n"
    "vmov d8, r4, r5\n vmov d9, r5, r6\n vmov d10, r6, r7\n vmov d11, r7, r8\n"
    "vmov d12, r8, r9\n vmov d13, r9, r10\n vmov d14, r10, r11\n vmov d15, r11, r4\n"
    "blx r12\n"
    "ldr r1, =0x44444444\n cmp r4, r1\n movne r2, #4\n bne 9f\n"
    "ldr r1, =0x55555555\n cmp r5, r1\n movne r2, #5\n bne 9f\n"
    "ldr r1, =0x66666666\n cmp r6, r1\n movne r2, #6\n bne 9f\n"
    "ldr r1, =0x77777777\n cmp r7, r1\n movne r2, #7\n bne 9f\n"
    "ldr r1, =0x88888888\n cmp r8, r1\n movne r2, #8\n bne 9f\n"
    "ldr r1, =0x99999999\n cmp r9, r1\n movne r2, #9\n bne 9f\n"
    "ldr r1, =0xaaaaaaaa\n cmp r10, r1\n movne r2, #10\n bne 9f\n"
    "ldr r1, =0xbbbbbbbb\n cmp r11, r1\n movne r2, #11\n bne 9f\n"
    "vmov r1, r3, d8\n cmp r1, r4\n movne r2, #108\n bne 9f\n cmp r3, r5\n movne r2, #108\n bne 9f\n"
    "vmov r1, r3, d9\n cmp r1, r5\n movne r2, #109\n bne 9f\n cmp r3, r6\n movne r2, #109\n bne 9f\n"
    "vmov r1, r3, d10\n cmp r1, r6\n movne r2, #110\n bne 9f\n cmp r3, r7\n movne r2, #110\n bne 9f\n"
    "vmov r1, r3, d11\n cmp r1, r7\n movne r2, #111\n bne 9f\n cmp r3, r8\n movne r2, #111\n bne 9f\n"
    "vmov r1, r3, d12\n cmp r1, r8\n movne r2, #112\n bne 9f\n cmp r3, r9\n movne r2, #112\n bne 9f\n"
    "vmov r1, r3, d13\n cmp r1, r9\n movne r2, #113\n bne 9f\n cmp r3, r10\n movne r2, #113\n bne 9f\n"
    "vmov r1, r3, d14\n cmp r1, r10\n movne r2, #114\n bne 9f\n cmp r3, r11\n movne r2, #114\n bne 9f\n"
    "vmov r1, r3, d15\n cmp r1, r11\n movne r2, #115\n bne 9f\n cmp r3, r4\n movne r2, #115\n bne 9f\n"
    "b 8f\n"
    "9: ldr r0, =0x0bad0000\n add r0, r0, r2\n"
    "8: vpop {d8-d15}\n"
    "pop {r4-r11, pc}\n"
    ".ltorg\n");
}
// gcc code that keeps much live across a call into mooncc's, and is called from it
extern int mid(int);
int gheavy(int a, int b, int c, int d) {
  int e = mid(a) + 1, f = mid(b) + 2, g = mid(c) + 3, h = mid(d) + 4;
  int i = mid(e) * 3, j = mid(f) * 5, k = mid(g) * 7, l = mid(h) * 11;
  double x = a * 1.5, y = b * 2.5, z = mid(c) * 0.5;
  return mid(a + b + c + d) + e + f + g + h + i + j + k + l + (int) (x + y + z); }
EOF
  cat > "$d/.cm.c" <<'EOF'
#include <setjmp.h>
int chk(int (*f)(int), int x);
int gheavy(int a, int b, int c, int d);
__attribute__((noinline)) int mid(int x) { return x + 1; }
__attribute__((noinline)) double midd(double x) { return x * 0.5; }
__attribute__((noinline)) float midf(float x) { return x * 0.25f; }
__attribute__((noinline)) int leaf(int x) { return x * 3 + 1; }
__attribute__((noinline)) int wide(int a) {
  int e = mid(a) + 1, f = mid(a + 1) + 2, g = mid(a + 2) + 3, h = mid(a + 3) + 4;
  int i = mid(e) * 3, j = mid(f) * 5, k = mid(g) * 7, l = mid(h) * 11;
  return mid(a) + e + f + g + h + i + j + k + l; }
// doubles across calls, and a double to int at the end
__attribute__((noinline)) int fwide(int a) {
  double c = midd(a) * 1.5, d = midd(a + 1) * 2.5, e = midd(c) + d, f = midd(d) - c, g = midd(e) * f, h = midd(f) + e;
  return (int) (midd(a) + c + d + e + f + g + h); }
// the four converters, each a leaf
__attribute__((noinline)) int cvd(int a) { volatile double d = a * 1.5; return (int) d; }
__attribute__((noinline)) int cvu(int a) { volatile double d = a * 2.5; return (int) (unsigned) d; }
__attribute__((noinline)) int cvf(int a) { volatile float f = a * 1.5f; return (int) f; }
__attribute__((noinline)) int cvfu(int a) { volatile float f = a * 2.5f; return (int) (unsigned) f; }
// a conversion, then a tail call; and one on only some paths, with two exits
__attribute__((noinline)) int cvtail(int a) { volatile double d = a * 3.5; int k = (int) d; return mid(k); }
__attribute__((noinline)) int cvpath(int a) {
  if (a & 1) return a + 2;
  volatile float f = a * 0.5f;
  for (int i = 0; i < 3; i++) if ((int) f == i) return i;
  return (int) f + a; }
// singles in the odd halves, homed
__attribute__((noinline)) float odd(float a, float b, float c, float d, float e) {
  float *p = &b, *q = &d; return midf(a) + *p + c + *q + e; }
__attribute__((noinline)) int cvodd(int a) { return (int) odd(a, a + 1, a + 2, a + 3, a + 4); }
// a long long from a double goes through a helper
__attribute__((noinline)) int cvll(int a) { volatile double d = a * 1e10; return (int) ((long long) d >> 20); }
__attribute__((noinline)) int big(int n) {
  int v[1500]; for (int i = 0; i < 1500; i++) v[i] = mid(i) ^ n;
  int s = 0; for (int i = 0; i < 1500; i += 97) s += v[i];
  return s + mid(n); }
__attribute__((noinline)) int vla(int n) {
  int v[n]; for (int i = 0; i < n; i++) v[i] = mid(i) * n;
  volatile double d = n * 1.5;
  int s = (int) d; for (int i = 0; i < n; i++) s += v[i];
  return s + mid(n); }
__attribute__((noinline)) int tail(int a) { int c = mid(a) + 5; return mid(c * 3); }
jmp_buf jb;
__attribute__((noinline)) void thrower(int x) { volatile double d = x * 1.5; if ((int) d > 3) longjmp(jb, x); }
__attribute__((noinline)) int sj(int a) {
  int e = mid(a) + 1, f = mid(a + 1) + 2, g = mid(a + 2) + 3, h = mid(a + 3) + 4;
  int r = setjmp(jb);
  if (!r) { thrower(mid(7)); return -1; }
  return r + e + f + g + h; }
__attribute__((noinline)) int viag(int a) { return gheavy(a, a + 1, a + 2, a + 3); }
int (*const t[])(int) = { leaf, wide, fwide, cvd, cvu, cvf, cvfu, cvtail, cvpath, cvodd, cvll, big, vla, tail, sj, viag };
int main(void) {
  for (unsigned i = 0; i < sizeof t / sizeof *t; i++) {
    int want = t[i](20 + i), got = chk(t[i], 20 + i);
    if (want != got) return 1 + i; }
  return 0; }
EOF
  $scc -c -O2 -w -ffreestanding -o "$d/cg.o" "$d/.cg.c" || fail "cs file: ${scc%% *} could not build the stub"
  for o in "" -O2 -Os -O0 -fpic; do
    moonrun -t $tgt $o "$@" -o "$d/cst" "$d/.cm.c" "$d/cg.o" > "$d/cs.log" 2>&1 || { cat "$d/cs.log" >&2; fail "cs file: mooncc -t $tgt $o"; }
    timeout 60 $a64_qemu "$d/cst"; a=$?
    [ $a -eq 0 ] || fail "cs file: $o, shape $a came back with a callee-saved register changed or a wrong value"
  done
  echo "cs file: r4-r11 and d8-d15 come back from 16 shapes under ${scc%% *}'s stub, -O0 -O2 -Os -fpic"
}
case $tgt in
  i386) va_pair "gcc -m32" ;;
  rv64) [ -z "$GCC" ] || va_pair "$GCC -mno-relax" ;;
  rv32) va_pair "clang $rvf" ;;
  mips) va_pair "clang $mpf" -os linux ;;
esac
[ $tgt != arm ] || cs_file "arm-none-eabi-gcc -mthumb -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -Wa,-mimplicit-it=thumb"
# arm's __int128 has no place past the named parameters: the va_arg and the call refuse by name;
# a fixed one, and one to an unprototyped callee, pass
case $tgt in arm|thumb2)
  printf '%s\n' 'int f(int n, ...) { __builtin_va_list a; __builtin_va_start(a, n); __int128 x = __builtin_va_arg(a, __int128); __builtin_va_end(a); return (int) x; }' > "$d/.vwa.c"
  printf '%s\n' 'int f(int n, ...); int g(__int128 x) { return f(1, x); }' > "$d/.vwc.c"
  cat > "$d/.vwf.c" <<'EOF'
int __attribute__((noinline)) fx(int n, __int128 x, int y) { return n == 1 && y == 42 && x >> 64 == 9 && (unsigned long long) x == 7; }
int old();
int main(void) {
  __int128 v = ((__int128) 9 << 64) | 7;
  int (*volatile p)(int, __int128, int) = fx;
  int (*volatile q)() = fx;
  return p(1, v, 42) && q(1, v, 42) && old(1, v, 42) ? 42 : 1; }
int old(int n, __int128 x, int y) { return fx(n, x, y); }
EOF
  for tw in $tgt $([ $tgt = thumb2 ] && echo thumb1 thumb2sp); do
    for o in "" -O2 -Os; do
      for w in vwa vwc; do
        moonrun -t $tw $o -c -o "$d/vw.o" "$d/.$w.c" > "$d/vw.log" 2>&1 && fail "va128: mooncc -t $tw $o took a variadic __int128 ($w)"
        grep -q 'no lane for' "$d/vw.log" || { cat "$d/vw.log" >&2; fail "va128: -t $tw $o $w refused without naming it"; }
        [ $tw = thumb1 ] || grep -q 'a variadic __int128' "$d/vw.log" || { cat "$d/vw.log" >&2; fail "va128: -t $tw $o $w refused for another reason"; }
      done
      [ $tw = thumb1 ] || moonrun -t $tw $o -c -o "$d/vwf.o" "$d/.vwf.c" > "$d/vw.log" 2>&1 || { cat "$d/vw.log" >&2; fail "va128: -t $tw $o a fixed __int128"; }
    done
  done
  if [ $tgt = arm ]; then
    for o in "" -O2 -Os; do
      moonrun -t arm $o -o "$d/vwt" "$d/.vwf.c" > "$d/vw.log" 2>&1 || { cat "$d/vw.log" >&2; fail "va128: the fixed ones, $o"; }
      timeout 60 qemu-arm "$d/vwt"; a=$?
      [ $a -eq 42 ] || fail "va128: $o a fixed or unprototyped __int128 (got $a want 42)"
    done
  fi
  echo "va128: a variadic __int128 refused by name, a fixed one passed" ;;
esac
if [ -n "$exitonly" ]; then
  # -ftrivial-auto-var-init=zero clears every word of a VLA and an alloca block
  cat > "$d/avz.c" <<'AVZ'
static void __attribute__((noinline)) dirty(void) { volatile char b[1024]; for (int i = 0; i < 1024; i++) b[i] = 255; }
static int __attribute__((noinline)) v(int n) { char a[n]; int s = 0; for (int i = 0; i < n; i++) s += a[i] != 0; return s; }
static int __attribute__((noinline)) h(int n) { char *a = __builtin_alloca(n); int s = 0; for (int i = 0; i < n; i++) s += a[i] != 0; return s; }
int cc_main(void) { dirty(); if (v(200)) return 1; dirty(); if (h(200)) return 2; return 0; }
AVZ
  moonrun -t "$tgt" -ftrivial-auto-var-init=zero -c -o "$d/avz.o" "$d/avz.c" > "$d/avz.log" 2>&1 \
    || { cat "$d/avz.log" >&2; fail "-ftrivial-auto-var-init=zero: mooncc could not build a VLA and an alloca"; }
  blink "$d/avz.o" "$d/avz.elf" > "$d/avz.log" 2>&1 \
    || { cat "$d/avz.log" >&2; fail "-ftrivial-auto-var-init=zero: ld could not bind our object"; }
  timeout 60 $a64_qemu "$d/avz.elf" < /dev/null > "$d/avz.out" 2>&1 \
    || fail "-ftrivial-auto-var-init=zero left a block uncleared on $mach"
fi

# does $1, ours under flag $2, answer as reference $3: its status in $4, its output in $5
same() {
  rg=$(cat "$4")
  [ "$rt" -eq "$rg" ] || { head -20 "$1" >&2; fail "$b: exit $rt ($2), $3 answers $rg"; }
  [ -n "$exitonly" ] || cmp -s "$5" "$1" || {
    echo "--- $b ($2): $3 vs ours on $pretty (first 20 differing lines) ---" >&2
    diff "$5" "$1" 2>/dev/null | head -20 >&2
    fail "$b: stdout ($2) differs from $3's"; }
}
n=0; ngcc=0
for b in $progs; do
  g=$r/res/$b.g; hasg=; [ -f "$g.rc" ] && hasg=1
  if [ -n "$hasg" ]; then
    [ "$(cat "$g.rc")" -ne 124 ] || fail "$b: $GCC's binary timed out -- the program, not us"
    ! grep -q "qemu: fatal" "$g.out" || fail "$b: $GCC's binary faulted on $mach -- the harness or the program, not our codegen"
  fi
  if inlist "$b" "$narrow"; then
    [ "$(cat "$g.rc")" -ne 0 ] || fail "$b: $GCC passes a program listed as narrow -- take it off the list"
  fi
  for os in t s; do
    fl=plain; [ $os = s ] && fl=-Os
    o=$r/res/$b.$os.out
    rt=$(cat "$r/res/$b.$os.rc" 2>/dev/null) || fail "$b: no answer from the $pretty batch"
    [ "$rt" -ne 124 ] || fail "$b: our binary ($fl) timed out $where"
    ! grep -q "qemu: fatal" "$o" || fail "$b: our binary ($fl) FAULTED ($(head -1 "$o"))"
    if inlist "$b" "$hosted $narrow"; then
      [ "$rt" -lt 128 ] || fail "$b: our binary ($fl) died on a signal ($rt)"
      continue
    fi
    [ -z "$x64ref" ] || same "$o" "$fl" "our x86-64" "$d/$b.xrc" "$d/$b.xout"
    [ -z "$hasg" ] || same "$o" "$fl" "$GCC" "$g.rc" "$g.out"
  done
  if inlist "$b" "$hosted"; then nhost=$((nhost + 1))
  elif inlist "$b" "$narrow"; then nnar=$((nnar + 1))
  else n=$((n + 1)); [ -z "$hasg" ] || ngcc=$((ngcc + 1)); fi
  # a passed case's files go (a static .g is ~3 MB); a failing one keeps them
  rm -f "${r:?}/${b:?}".* "${r:?}/res/${b:?}".* "${d:?}/${b:?}".*
done

if [ "$tgt" = arm ]; then
  # a call an android filter traps answers ENOSYS; qemu has no filter, so the signal comes by hand
  cat > "$d/.refused.c" <<'EOF'
#include <errno.h>
#include <signal.h>
#include <unistd.h>
int main(void) { return kill(getpid(), SIGSYS) == -1 && errno == ENOSYS ? 42 : 1; }
EOF
  moonrun -t arm -o "$d/refused" "$d/.refused.c" > "$d/refused.log" 2>&1 \
    || { cat "$d/refused.log" >&2; fail "refused: mooncc could not build it"; }
  qemu-arm "$d/refused"; a=$?
  [ $a -eq 42 ] || fail "refused: a trapped call did not answer ENOSYS (got $a want 42)"
  # -shared as bionic reads it; the phone is the oracle for the load
  cat > "$d/.so.c" <<'EOF'
int hook(int);
int twice(int x) { return hook(x) * 2; }
static int (*tab[2])(int) = {hook, twice};
int via(int x) { return tab[1](tab[0](x)); }
EOF
  moonrun -t arm -fpic -shared -o "$d/libso.so" "$d/.so.c" > "$d/so.log" 2>&1 \
    || { cat "$d/so.log" >&2; fail "shared: mooncc -t arm -shared"; }
  so=$(arm-none-eabi-readelf -hdr "$d/libso.so")
  for w in "ELF32" "DYN (" "(REL)" "R_ARM_GLOB_DAT" "R_ARM_RELATIVE"; do
    case $so in *"$w"*) ;; *) fail "shared: no $w in the object" ;; esac
  done
  # -fpic reaches a name it does not lay through the got: the link makes that load a nop
  # where it lays the name, an import's got slot under a system loader
  cat > "$d/.ga.c" <<'EOF'
#include <stdio.h>
extern int g_val;
extern int g_arr[4];
int bump(int);
int (*fp)(int) = bump;
int main(void) {
  int *p = &g_val, (*f)(int) = bump;
  g_arr[2] = 5;
  return *p + f(g_arr[2]) + fp(1) + (stderr != 0) == 40 + 6 + 2 + 1 ? 42 : 1; }
EOF
  printf 'int g_val = 40;\nint g_arr[4];\nint bump(int x) { return x + 1; }\n' > "$d/.gb.c"
  for o in "" -O2; do
    moonrun -t arm -fpic $o -o "$d/got" "$d/.ga.c" "$d/.gb.c" > "$d/got.log" 2>&1 \
      || { cat "$d/got.log" >&2; fail "got: mooncc -t arm -fpic $o"; }
    qemu-arm "$d/got"; a=$?
    [ $a -eq 42 ] || fail "got: -fpic $o through a relaxed got load (got $a want 42)"
  done
  moonrun -t arm -fpic -c -o "$d/ga.o" "$d/.ga.c" > "$d/got.log" 2>&1 || { cat "$d/got.log" >&2; fail "got: mooncc -c"; }
  case $(arm-none-eabi-readelf -r "$d/ga.o") in *R_ARM_GOT_PREL*) ;; *) fail "got: no R_ARM_GOT_PREL in the object" ;; esac
  # ..and an executable the system's loader runs: a pie by default, its import's address the
  # got's, no relocation in its text; the phone is the oracle for the run
  moonrun -t arm -O2 -dynamic-linker /system/bin/linker -o "$d/dx" "$d/.ga.c" "$d/.gb.c" -l:libc.so > "$d/dx.log" 2>&1 \
    || { cat "$d/dx.log" >&2; fail "dx: mooncc -t arm -dynamic-linker"; }
  dx=$(arm-none-eabi-readelf -hlrd "$d/dx")
  for w in "DYN (" "interpreter: /system/bin/linker" "R_ARM_GLOB_DAT    00000000   stderr" "Shared library: [libc.so]"; do
    case $dx in *"$w"*) ;; *) fail "dx: no $w in the executable" ;; esac
  done
  case $dx in *TEXTREL*) fail "dx: the text is relocated" ;; esac
  te=$(arm-none-eabi-readelf -SW "$d/dx" | sed -n 's/.* \.text  *PROGBITS  *\([0-9a-f]*\) [0-9a-f]* \([0-9a-f]*\) .*/\1 \2/p')
  lo=$((0x${te% *})); hi=$((lo + 0x${te#* }))
  arm-none-eabi-readelf -rW "$d/dx" | while read -r off rest; do
    case $off in [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
      [ $((0x$off)) -ge $lo ] && [ $((0x$off)) -lt $hi ] && echo "$off" ;; esac
  done > "$d/dx.tr"
  [ ! -s "$d/dx.tr" ] || fail "dx: a relocation lands in the text, at $(head -1 "$d/dx.tr")"
  # -mfloat-abi=softfp, android's abi: floats at a call in the words, both ways, held to gcc's
  # softfp object; the float file still computes
  if command -v arm-none-eabi-gcc > /dev/null 2>&1; then
    printf '%s\n' 'double mix(float a, double b, int c, float d) { return a * 2 + b + c + d; }' \
      'float half(float x) { return x / 2; }' \
      'double cb(double (*f)(double, float), double x) { return f(x, 0.5f) * 3; }' > "$d/.fp.c"
    cat > "$d/.fpm.c" <<'EOF'
extern double mix(float, double, int, float);
extern float half(float);
extern double cb(double (*)(double, float), double);
static double twice(double x, float y) { return x * 2 + y; }
int main(void) {
  double m = mix(1.5f, 2.25, 3, 0.25f);
  float h = half(5.0f);
  double c = cb(twice, 1.0);
  return m == 8.5 && h == 2.5f && c == 7.5 ? 42 : 1; }
EOF
    arm-none-eabi-gcc -c -O2 -mthumb -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp -o "$d/fp.o" "$d/.fp.c" \
      || fail "softfp: arm-none-eabi-gcc could not build the reference"
    for o in "" -O2 -Os; do
      moonrun -t arm $o -mfloat-abi=softfp -nostdlib -o "$d/fpt" "$d/.fpm.c" "$d/fp.o" > "$d/fp.log" 2>&1 \
        || { cat "$d/fp.log" >&2; fail "softfp: mooncc -t arm -mfloat-abi=softfp $o"; }
      qemu-arm "$d/fpt"; a=$?
      [ $a -eq 42 ] || fail "softfp: $o against gcc's softfp object (got $a want 42)"
    done
    case $(arm-none-eabi-readelf -h "$d/fpt") in *soft-float*) ;; *) fail "softfp: the header does not say soft-float" ;; esac
    va_pair "arm-none-eabi-gcc -mthumb -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp" -mfloat-abi=softfp -nostdlib
  fi
  moonrun -t arm -mfloat-abi=softfp -o "$d/fpr" "$d/.ga.c" "$d/.gb.c" > "$d/fpr.log" 2>&1 \
    && fail "softfp: a link that pulls moonlibc, which is hard-float, was taken"
  grep -q "softfp links with" "$d/fpr.log" || fail "softfp: the refusal: $(cat "$d/fpr.log")"
  # a static link says its stack is not executable: without pt_gnu_stack a 32-bit arm
  # kernel maps every read as exec too, for it and all it execs (selinux then refuses a gpu)
  case $(arm-none-eabi-readelf -lW "$d/got") in *"GNU_STACK"*" RW  "*) ;; *) fail "static: no PT_GNU_STACK rw" ;; esac
  echo "arm: a trapped call answers ENOSYS, -shared lays a REL object, -fpic loads through the got, -dynamic-linker lays a pie, softfp is gcc's, the stack is not exec"
fi

[ $n -gt 0 ] || fail "no programs ran from test/cc/"
say="$name: $n programs answer $where, plain and -Os"
[ -z "$x64ref" ] || say="$say, as on x86-64"
[ -z "$GCC" ] || say="$say, $ngcc as $(basename "$GCC") does"
for c in "$nref refuse" "$nwide wide-refused-by-both" "$nnar narrow" "$nhost hosted" "$nlibc want-a-libc" "$nskip skipped"; do
  case $c in 0\ *) ;; *) say="$say, $c" ;; esac
done
echo "$say"
