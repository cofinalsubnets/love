// a64's local-exec loads and stores at every width, their tprel_lo12_nc in the access
	.section .tdata,"awT",@progbits
	.p2align 4
tv:	.quad 0x0807060504030201, 0x100f0e0d0c0b0a09
	.text
	.globl tls_ldst
	.p2align 2
// tls_ldst(out): out[0..4] the byte, half, word, double and the quad's high half, then the
// byte stored back plus one
tls_ldst:
	mrs x9, tpidr_el0
	add x8, x9, :tprel_hi12:tv
	ldrb w1, [x8, :tprel_lo12_nc:tv]
	str x1, [x0]
	add x8, x9, :tprel_hi12:tv+2
	ldrh w1, [x8, :tprel_lo12_nc:tv+2]
	str x1, [x0, 8]
	add x8, x9, :tprel_hi12:tv+4
	ldr w1, [x8, :tprel_lo12_nc:tv+4]
	str x1, [x0, 16]
	add x8, x9, :tprel_hi12:tv+8
	ldr x1, [x8, :tprel_lo12_nc:tv+8]
	str x1, [x0, 24]
	add x8, x9, :tprel_hi12:tv
	ldr q0, [x8, :tprel_lo12_nc:tv]
	mov x1, v0.d[1]
	str x1, [x0, 32]
	add x8, x9, :tprel_hi12:tv
	ldrb w1, [x8, :tprel_lo12_nc:tv]
	add w1, w1, 1
	strb w1, [x8, :tprel_lo12_nc:tv]
	ret
