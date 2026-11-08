# test/gate/thumbrt.sh -- a cortex-m board for a gate under qemu-system-arm, dotted after cclib.sh.
# no libc: the exit is semihosted, and every qemu reads </dev/null, or -nographic blocks without a tty
#   thumb1    cortex-m0  (v6-m, no fpu)     -M microbit
#   thumb2    cortex-m7  (v7e-m, fpv5-d16)  -M mps2-an500
#   thumb2sp  cortex-m4  (v7e-m, fpv4-sp)   -M mps2-an386
# thumb_board TARGET DIR: skips without the tools, sets cpu mach lg, lays DIR/start.o and DIR/link.ld
thumb_board() {
  case $1 in
    thumb1)   cpu="-mcpu=cortex-m0 -mthumb"; acpu=cortex-m0; afpu=; mach=microbit; vfp=0 ;;
    thumb2)   cpu="-mcpu=cortex-m7 -mthumb -mfloat-abi=hard -mfpu=fpv5-d16"
              acpu=cortex-m7; afpu=fpv5-d16; mach=mps2-an500; vfp=1 ;;
    thumb2sp) cpu="-mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16"
              acpu=cortex-m4; afpu=fpv4-sp-d16; mach=mps2-an386; vfp=1 ;;
    *) echo "thumbrt.sh: unknown target $1" >&2; exit 1 ;;
  esac
  for tool in arm-none-eabi-gcc arm-none-eabi-ld qemu-system-arm; do
    have $tool || gate_skip "$name: no arm-none-eabi toolchain / qemu-system-arm, skipped"
  done
  # the startup: vectors, `bl run`, semihosting SYS_EXIT_EXTENDED with run()'s answer. the
  # initial sp lies in the board's sram; a vfp target enables CP10/CP11 in CPACR first
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
  } > "$2/start.S"
  { echo 'MEMORY'; echo '{'
    echo '  FLASH (rx) : ORIGIN = 0, LENGTH = 1M'
    echo '  RAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 16K'; echo '}'
    echo 'SECTIONS'; echo '{'
    echo '  .text : { KEEP(*(.vectors)) *(.text*) *(.rodata*) } > FLASH'
    echo '  .data : { *(.data*) } > RAM'
    echo '  .bss : { *(.bss*) *(COMMON) } > RAM'; echo '}'
  } > "$2/link.ld"
  arm-none-eabi-gcc $cpu -c "$2/start.S" -o "$2/start.o" || fail "as start.S"
  lg=$(arm-none-eabi-gcc $cpu -print-libgcc-file-name)
}
