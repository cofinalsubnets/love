# test/gate/m16rt.sh -- real mode for a gate under qemu-system-i386, dotted after cclib.sh. no BIOS: the
# reset vector in a 64K rom copies the program to 0x8000 in ram, the stack below it. the answer goes
# out the debug port, and every qemu reads </dev/null
# m16_board DIR: skips without the tools, lays DIR/start.o run.o rt.o link.ld m16run.sh, and blink
m16_board() {
  for tool in qemu-system-i386 ld gcc; do
    have $tool || gate_skip "$name: no $tool, skipped"
  done
  printf '#include <stdio.h>\nint main(void){puts("ok");return 0;}\n' > "$1/probe.c"
  gcc -m32 -w -o "$1/probe" "$1/probe.c" > /dev/null 2>&1 && [ "$("$1/probe")" = ok ] \
    || gate_skip "$name: skipped (gcc -m32 cannot build and run a hello here)"
  cat > "$1/start.S" <<'START'
.code16
.section .start,"ax"
.global _start
_start:
  calll run
  outb %al, $0xe9
  xorb %al, %al
  outb %al, $0xf4
1: hlt
  jmp 1b
.section .reset,"ax"
stub:
  cli
  xorw %ax, %ax
  movw %ax, %ss
  movw $0x8000, %sp
  movw %ax, %es
  movl %cr0, %eax
  andl $0xfffffffb, %eax
  orl $2, %eax
  movl %eax, %cr0
  movl %cr4, %eax
  orl $0x600, %eax
  movl %eax, %cr4
  fninit
  movw $0xf000, %ax
  movw %ax, %ds
  xorw %si, %si
  movw $0x8000, %di
  movw $0x4000, %cx
  cld
  rep movsw
  xorw %ax, %ax
  movw %ax, %ds
  ljmpw $0, $_start
.org 0xf0
  ljmpw $0xf000, $0xff00
.org 0x100
START
  cat > "$1/link.ld" <<'LINK'
SECTIONS
{
  .prog 0x8000 : AT(0xf0000) { *(.start) *(.text*) *(.rodata*) *(.data*) *(.bss*) *(COMMON) BYTE(0) }
  .rom 0xff00 : AT(0xfff00) { *(.reset) }
  /DISCARD/ : { *(.note*) *(.comment) *(.eh_frame*) }
}
LINK
  cat > "$1/m16run.sh" <<'RUN'
rm -f "$1.dbg"
qemu-system-i386 -M isapc -cpu coreduo -display none -no-reboot -bios "$1" -debugcon "file:$1.dbg" \
  -device isa-debug-exit,iobase=0xf4,iosize=1 < /dev/null 2> /dev/null
[ -s "$1.dbg" ] || { echo "qemu: fatal: no answer from real mode"; exit 125; }
exit $(od -An -tu1 "$1.dbg")
RUN
  # main is renamed cc_main for `run`, argc what a hosted reference sees; mem* and strcmp are the floor a compiler may call
  { echo 'int cc_main(int, char **);'
    echo 'static char *av[] = { "a.out", 0 };'
    echo 'int run(void){ return cc_main(1, av); }'
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
  } > "$1/run.c"
  gcc -m32 -c "$1/start.S" -o "$1/start.o" || fail "as start.S"
  gcc -m16 -ffreestanding -fno-pic -fno-stack-protector -fcf-protection=none -O1 -c "$1/run.c" -o "$1/run.o" || fail "gcc run.c"
  moonrun -m16 -c -o "$1/rt.o" src/apps/moon/lib/rt.c || fail "mooncc rt.c"
  m16d=$1
  blink() { ld -m elf_i386 -T "$m16d/link.ld" --oformat binary "$m16d/start.o" "$m16d/run.o" "$1" "$m16d/rt.o" -o "$2"; }
}
