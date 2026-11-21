# a pic object's local got fields for holo's link: sixteen %got/%lo pairs against a local (relgloc,
# which the assembler turns into .bss plus an offset in the GOT16 field), a page apart so some cross
# the low half's carry, each beside a .word of the same address. relgot(i) answers probe i's
	.set noreorder
	.bss
	.align 4
relgloc: .space 0x20000

	.text
	.globl relgot
relgot:	lui $28, %hi(_gp_disp)		# gp from $t9, as a pic function's
	addiu $28, $28, %lo(_gp_disp)
	addu $28, $28, $25
	lw $2, %got(relgtab)($28)
	addiu $2, $2, %lo(relgtab)
	sll $4, $4, 4
	addu $2, $2, $4
	jr $2
	nop
relgtab:
	.irp k, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
	lw $2, %got(relgloc + 0x1000 * \k + 0x7ff8)($28)
	jr $31
	addiu $2, $2, %lo(relgloc + 0x1000 * \k + 0x7ff8)
	nop
	.endr

	.data
	.globl relgwd
relgwd:
	.irp k, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
	.word relgloc + 0x1000 * \k + 0x7ff8
	.endr
