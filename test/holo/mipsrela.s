# o32 REL fields for holo's link, laid by llvm-mc or GNU as: each address twice, by a %hi/%lo pair
# (its addend in the two fields) and by a .word, against a global (relbig, mipsrel.c's) and a local
# (relloc, which the assembler turns into .bss plus an offset); sixteen offsets a page apart, so
# whatever the base some cross the low half's carry. reljal reaches a local by R_MIPS_26, its
# target in the field
	.set noreorder
	.bss
	.align 4
relloc:	.space 0x20000

	.text
	.globl relhi
relhi:	sll $4, $4, 4			# relhi(i): probe i's address, by its pair
	lui $2, %hi(relprobe)
	addiu $2, $2, %lo(relprobe)
	addu $2, $2, $4
	jr $2
	nop
relprobe:
	.irp k, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
	lui $2, %hi(relbig + 0x1000 * \k + 0x7ff8)
	jr $31
	addiu $2, $2, %lo(relbig + 0x1000 * \k + 0x7ff8)
	nop
	.endr
	.irp k, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
	lui $2, %hi(relloc + 0x1000 * \k + 0x7ff8)
	jr $31
	addiu $2, $2, %lo(relloc + 0x1000 * \k + 0x7ff8)
	nop
	.endr

	.globl reljal
reljal:	addiu $sp, $sp, -8		# reljal(): relfar's answer, 26
	sw $31, 4($sp)
	jal relfar
	nop
	lw $31, 4($sp)
	jr $31
	addiu $sp, $sp, 8
	.space 64
relfar:	jr $31
	li $2, 26

	.data
	.globl relwd
relwd:
	.irp k, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
	.word relbig + 0x1000 * \k + 0x7ff8
	.endr
	.irp k, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
	.word relloc + 0x1000 * \k + 0x7ff8
	.endr
