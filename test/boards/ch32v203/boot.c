// the chip runs from 0 out of reset with no stack: the first words give it the top of
// its 10 KB of sram and go to cmain
asm(".text\n.globl _start\n_start:\n li sp, 0x20002800\n j cmain\n");
