; holo -- an assembler over a neutral IR: a flat list of instruction forms (a RISC-ish
; three-address surface over abstract registers r0..r14 + sp) that a backend lowers to bytes.
; this file is the arch-neutral half: the IR, the two-pass layout (addresses, then label
; fixups), the backend registry, and the byte/hex plumbing. a backend pins a `lower`/`patch`
; pair under a target name. the gate is test/holo/golden.l.
;
; the IR (each form a list, the head an op symbol):
;   (label name)            ; a named address (emits no bytes)
;   (li d imm)              ; d <- immediate
;   (mov d s)              ; d <- s            (register move)
;   (add d a b) (sub ..)   ; d <- a OP b       b a register or an immediate; also and/or/xor/imul
;   (neg d) (not d) (inc d) (dec d)            ; in-place unary
;   (cmp a b)              ; set flags from a - b
;   (ld d base off)        ; d <- [base+off]   (64-bit load)
;   (st base off s)        ; [base+off] <- s   (64-bit store)
;   (ld1/ld2/ld4 d base off)                   ; sign-extending sized loads (C's char/short/int)
;   (st1/st2/st4 base off s)                   ; truncating sized stores
;   (sx1/sx2/sx4 d)                            ; sign-extend d's low 1/2/4 bytes in place (the C casts)
;   (shlv/shrv/sarv d c)   ; shift d by the count in c -- c pinned to r1 (x86's CL), d must differ
;   (lea d base off)       ; d <- base+off     (address arithmetic)
;   (ldx d base ix sc dp)  ; d <- [base + ix*sc + dp]   (sc in 1/2/4/8)
;   (stx base ix sc dp s)  ; [base + ix*sc + dp] <- s
;   (leax d base ix sc dp) ; d <- base + ix*sc + dp
;   (shl/shr/sar/rol/ror d c)                  ; shift / rotate d in place by immediate count c
;   (ror4 d c) (rorv/rorv4 d c)                ; 32-bit rotate right (imm; count via r1) + the 64-bit count form
;   (test a b)             ; set flags from a and b
;   (div d a b) (rem d a b t)                  ; signed truncating quotient / remainder; t a scratch (a64 rem; x86 ignores)
;   (push s) (pop d)
;   (jmp label) (br cond label)                ; cond: eq ne lt le gt ge below above ae be s ns vs vc
;   (jmpr d)                                   ; indirect: jump to the address in register d
;   (jmpm b off)                               ; indirect: jump to the address at [b+off] (x64)
;   (adds d a b) (subs d a b)                  ; like add/sub but set flags -- pair with (br vs/vc ..)
;   (mulo d a b t lbl)                         ; d <- a*b (low 64); branch to lbl on signed overflow; t a scratch (clobbered)
;   (set cond d)                               ; d <- (cond holds) ? 1 : 0, from the last cmp's flags
;   (call label) (callr d) (callm b o) (ret) (sys)  ; callr: through register d, callm: through memory; sys = syscall/svc
;   (la d label)           ; d <- the label's address (pc-relative; data via (label)+(raw ..))
;   (nop) (trap)
;   -- sse2 double lane (x86-64 only; the float glaze): xmm registers f0..f15 --
;   (addsd/mulsd/subsd/divsd d s) etc.         ; reg-reg packed/scalar double ops (see x64-sse)
;   (ucomisd a b)                              ; compare doubles, set flags
;   (cvtsi2sd f g) (movqxr f g) (movqrx g f)   ; int->double ; gp<->xmm bit moves
;   (stsd base disp f) (ldsd f base disp)      ; movsd [base+disp]<->xmm  (spill / box store)
;   (ldsdx f base index scale disp) (stsdx base index scale disp f)   ; the indexed twins (ldssx/stssx single)
;   (ldsdl f label)                            ; xmm <- the double at a label (pc-relative, a rodata constant)
;   (minsd d s) (maxsd d s)                    ; d <- d < s ? d : s  /  d > s ? d : s (a NaN takes s)
;   (addss .. ucomiss minss maxss) (cvtsi2ss cvtui2ss f g) (cvttss2si cvttss2ui g f)   ; the single twins
;   (movdxr f g) (movdrx g f)                  ; gp<->f bit moves of a single's 32 bits
;   (cmov cond d s)                            ; d <- s when cond holds, off the last cmp (x86-64)
;
; a register operand is a symbol (r0..), an immediate a number, so the ALU ops take either in
; the same slot. each backend maps r0..r14/sp onto its own encoding.

; the backends reopen this module under the same (module 'holo head, so a frontend cats this
; file plus the backends it wants and gets one layer.

(module 'holo
(: ;; -- bytes, little-endian. byte/le16/le32 use &/>>, exact below 2^31; le64 takes a full
   ;; 64-bit word, a bignum where `&` drops the high limb, so it slices with //%. --
   (catall ls) (foldr (+) () ls)
   (byte n)  (n & 255)
   (le16 n)  [(byte n) (byte (n >> 8))]
   (le32 n)  [(byte n) (byte (n >> 8)) (byte (n >> 16)) (byte (n >> 24))]
   (le64 n)  (u64 n @ u (map (i \ (u // i 256) % 256) ^8))
   (u64 n) (n < 0 ? (n + 18446744073709551616) n)                     ; two's-complement into [0,2^64)
   (s64 n) (n > 9223372036854775807 ? (n - 18446744073709551616) n)   ; a u64 pattern as the signed value it encodes
   ;; a 32-bit thumb instruction: two halfwords, the high one first, each little-endian
   (t32 w) (le16 (w >> 16) + le16 (w & 65535))
   ;; the wide thumb branch, byte offset o: S:J1:J2:imm10:imm11 with i1=~(J1^S), i2=~(J2^S);
   ;; hw2's base says which -- 0xd000 BL, 0x9000 B.W
   (tbw o base)
      (: imm11 (o >> 1 & 2047)  imm10 (o >> 12 & 1023)
         i2 (o >> 22 & 1)  i1 (o >> 23 & 1)  s (o >> 24 & 1)
         j1 (((i1 ^ 1) ^ s) & 1)  j2 (((i2 ^ 1) ^ s) & 1)
         (t32 ((0xF000 | (s << 10 | imm10)) << 16 | (base | (j1 << 13 | (j2 << 11 | imm11))))))
   (blank? c) (c = 32 || c = 9)                      ; a newline ends the line, so not blank
   (fits8  n) (n >= -128 && n <= 127)
   (fits32 n) (n >= -2147483648 && n <= 2147483647)
   ;; IR condition -> the 4-bit arm cond field, one encoding for a64, thumb2 and thumb1.
   ;; p/np (x86 parity: ucomisd's unordered bit) alias vs/vc: fcmp parks unordered in V
   arm-cc {'eq 0 'ne 1 'ae 2 'below 3 's 4 'ns 5 'vs 6 'vc 7 'p 6 'np 7
           'above 8 'be 9 'ge 10 'lt 11 'gt 12 'le 13}

   (reg? x)  !(constellation? x)
   (imm? x)  (constellation? x)

   ;; -- a fixup: ('fix w kind label aux) inline among the bytes, `w` bytes wide, filled in
   ;; pass two by the backend's `patch`. aux is backend scratch: a fixed-width arch keeps the
   ;; base instruction word there, x86 ignores it. --
   (fix w kind label aux) ['fix w kind label aux]
   (fix? x)   (two? x ? (<x = 'fix) 0)
   (fix-w x)  (x 1)
   (fix-k x)  (x 2)
   (fix-l x)  (x 3)
   (fix-a x)  (x 4)
   ;; an a64 address fix's aux: the word below bit 32, a signed 32-bit addend above it
   a64-afixk '(adrp21 adr21 addlo12 lo12s1 lo12s2 lo12s4 lo12s8 lo12s16 ld19)
   (afix-w aux) (aux & 4294967295)
   (afix-ad aux) ((aux >> 32) @ h (h >= 2147483648 ? (h - 4294967296) h))
   ;; a byte is 1, a fixup its width, a string a blob: its bytes verbatim as one item,
   ;; so a megabyte payload costs no cons per byte.
   (item-len x) (? (fix? x) (fix-w x) (string? x) #x 1)
   ;; -- fold a lowered chunk onto the reversed item stream -> (len . items), in one walk:
   ;; the assembler's hottest loop. --
   (revonto l items n) (!(two? l) ? (n . items)
                          (revonto >l (<l . items) (n + item-len <l)))

   ;; -- the little table kit every backend leans on: `fregs` builds the f0..fn-1 float
   ;; file, and `look` is the guarded read (a miss scares with the caller's tag). --
   (fregs n)   ({} @ t (foldl (\ _ i (pin t (intern ("f" + show i)) i)) 0 ^n, t))
   (look tab k tag) (peep tab k -1 @ e (e < 0 ? (scare tag k) e))

   ;; -- the IR's operand counts. a backend's emitter rows take exactly these operands (an
   ;; arity-0 row is its chunk), and its 'lower is lower-via over them. --
   ir-arity {'ret 0 'sys 0 'nop 0 'trap 0 'udivll 0 'uremll 0
              ; x86 port i/o, register-contracted (dx the port, al/ax/eax the datum). str, a
              ; string op by stem and width, walks rsi/rdi (by rcx under rep, a prefix like lock).
             'inb 0 'inw 0 'inl 0 'outb 0 'outw 0 'outl 0
             'cld 0
             'str 2 'rep 0 'repne 0
              ; mdig lays opcode bytes over [base+off] with a /digit, w 8 for REX.W
             'mdig 5 'fninit 0 'fnclex 0 'fwait 0 'emms 0
              ; rdig: prefix bytes, opcode bytes, a /digit, a width, and a register; movntim m <- r
             'rdig 5 'rrop 4 'movntim 4 'rdpmc 0 'invpcid 3
              ; privileged instructions. a64's sys operations take an operation name then a
              ; register, `zr` whole-system; riscv's csr pseudos write x0 into the slot they omit.
             'cli 0 'sti 0 'hlt 0 'ud2 0 'iretq 0 'swapgs 0 'pushf 0 'popf 0 'lock 0
             'rdmsr 0 'wrmsr 0 'cpuid 0 'rdtsc 0
              ; svm: the vmcb's physical address rides rax
             'vmrun 0 'vmload 0 'vmsave 0 'stgi 0 'clgi 0
              ; vmx: vmxon/vmclear/vmptrld take a memory operand (base disp, lgdt's shape) holding
              ; a physical address; vmread/vmwrite move a field to or from a gpr.
             'vmlaunch 0 'vmxoff 0
             'vmxon 2 'vmclear 2 'vmptrld 2 'sgdt 2 'sidt 2
             'vmread 2 'vmwrite 2
             'isb 0 'wfi 0 'wfe 0 'eret 0
             'int 1 'ltr 1 'dsb 1 'dmb 1 'seg 1 'bscan 4 'pause 0 'mfence 0 'lfence 0 'sfencex 0 'stc 0 'clc 0 'cmc 0 'stac 0 'clac 0 'rdpkru 0 'wrpkru 0 'xgetbv 0 'xsetbv 0 'wbinvd 0 'invd 0 'monitor 0 'mwait 0 'monitorx 0 'mwaitx 0 'rdtscp 0
             'carry 4 'alurm 5 'xaddm 4 'cmpxchgm 4 'xchgm 4 'alum 5 'unm 4 'btm 5 'testm 4
             'brk 1 'dbrk 1 'hvc 1 'smc 1 'udf 1 'svcn 1
             'ldcr 2 'stcr 2 'lddr 2 'stdr 2 'lgdt 2 'lidt 2 'invlpg 2
             'mrs 2 'msr 2 'msri 2
             'tlbi 2 'ic 2 'dc 2 'at 2
             'sret 0 'mret 0 'fence 0 'fencei 0
             'csrr 2 'csrw 2 'csrs 2 'csrc 2
             'csrwi 2 'csrsi 2 'csrci 2 'sfence 2
             'csrrw 3 'csrrs 3 'csrrc 3
             'csrrwi 3 'csrrsi 3 'csrrci 3
             'sx1 1 'sx2 1 'sx4 1 'zx1 1 'zx2 1 'zx4 1
             'frpush 0 'frpop 0              ; a64's frame record: fp and lr as one pair
             'cbr 3                          ; a64's cbz/cbnz: (cbr word reg label), the flags untouched
             'tbr 3                          ; ..and tbz/tbnz: (tbr word reg label), the bit in the word
             'afix 4                         ; ..and gas's address fixes: (afix kind word label addend)
             'push 1 'pop 1 'neg 1 'not 1 'inc 1 'dec 1 'tp 1
             'jmp 1 'jmp8 1 'jmpr 1 'jmpm 2 'jmpt 3 'callr 1 'callm 2 'call 1 'raw 1 'lapool 1
             'li 2 'mov 2 'cmp 2 'test 2 'set 2 'set1 2 'br 2 'br8 2
             'la 2 'laa 3 'lar 2 'lia 2 'ldseg 2 'pushl 1 'stseg 2 'segst 3 'segld 3 'pushseg 2 'popseg 2 'clz 2
             'shl 2 'shr 2 'sar 2 'rol 2 'ror 2 'ror4 2
             'lsl 3 'lsr 3 'asr 3 'mvn 2 'uxtb 2 'uxth 2 'uxtw 2 'sxtb 2 'sxth 2 'sxtw 2 'ubfx 4   ; the three-register twins, thumb2's ubfx
             'shlv 2 'shrv 2 'sarv 2 'rorv 2 'rorv4 2
             'movupd 2 'movsd 2 'movss 2 'movapd 2 'movhlps 2 'unpcklpd 2
             'mulpd 2 'addpd 2 'subpd 2 'divpd 2
             'mulsd 2 'addsd 2 'subsd 2 'divsd 2
             'mulss 2 'addss 2 'subss 2 'divss 2 'minss 2 'maxss 2 'ucomiss 2
             'cvtsi2ss 2 'cvtui2ss 2 'cvttss2si 2 'cvttss2ui 2 'movdxr 2 'movdrx 2
             'xorpd 2 'pcmpeqd 2 'andpd 2 'psubq 2
             'cvtss2sd 2 'cvtsd2ss 2 'ucomisd 2 'movmskpd 2
             'cvtsi2sd 2 'cvtui2sd 2 'cvttsd2si 2 'cvttsd2ui 2
             'movqxr 2 'movqrx 2
             'movsnxr 2 'movsnrx 2
             'add 3 'sub 3 'and 3 'or 3 'xor 3 'imul 3 'mulh 3 'umulh 3
             'adds 3 'subs 3 'adc 3 'adcs 3 'sbc 3 'sbcs 3 'ors 3
             'div 3 'udiv 3
             'ld 3 'st 3 'lea 3 'lean 3
             'cas 3 'cas4 3
             'ld1 3 'ld2 3 'ld4 3 'st1 3 'st2 3 'st4 3
             'si 3 'si1 3 'si2 3 'si4 3
             'cmpm 3 'cmprm 3
             'divq 1 'divl 1 'dv128 1 'rm128 1
             'a128 1 's128 1 'm128 1 'mw128 1
             'a128r 2 's128r 2 'm128r 2 'mw128r 1 'c128r 3
             'shl128 1 'shr128 1 'sar128 1 'c128 2
             'sx128 0 'n128 0 'inc128 0 'dec128 0
             'shl128v 0 'shr128v 0 'sar128v 0
             'ldu1 3 'ldu2 3 'ldu4 3
             'stsd 3 'ldsd 3 'stss 3 'ldss 3 'cmppd 3
             'rem 4 'urem 4 'umull 4 'smull 4 'mla 4
             'ldx 5 'stx 5 'leax 5 'ldxb 5 'stxb 5 'ldxw 5 'ldxsw 5 'mulo 5
             'andx4 5 'orx4 5 'xorx4 5 'andm4 3 'orm4 3 'xorm4 3 'decm 2
             'ldsdx 5 'stsdx 5 'ldssx 5 'stssx 5 'ldsdl 2
             'minsd 2 'maxsd 2 'cmov 3}
   ;; an emitter row is (arity . emitter); `emsof` builds a backend's tablet from ('op . f) pairs.
   (emsof prs) ({} @ t (foldl (\ _ p (emrow t <p >p)) 0 prs, t))
   (emrow t op f) (pin t op (look ir-arity op 'bad-op . f))
   ;; feed the emitter the form's operands; a wrong count scares, where a partial application
   ;; would lay as zero bytes.
   (feed f l n op) (? (two? l) (n < 1 ? (scare 'arity-skew op) (feed (f <l) >l (n - 1) op))
                      (n = 0) f
                      (scare 'arity-skew op))
   (lower-via ems ins)
      (: op <ins  r (peep ems op 'no)
         (r = 'no ? (scare 'bad-op op) 0,
          feed >r >ins <r op))

   ;; -- the backend registry. a backend is a tablet { 'lower 'patch }, plus 'refix where the
   ;; linker reaches in. --
   backends {}
   (defbackend name be) (pin backends name be)
   (lower-with be ins)         (peep be 'lower 0 ins)
   (patch-with be k t s w aux) (peep be 'patch 0 k t s w aux)
   ;; the linker's door onto the same encoders: a rel relocation keeps its addend (and a
   ;; movw/movt's Rd) in the field, so this takes the field's bytes and answers the re-encode.
   ;; a missing 'refix scares: a default 0 would apply as const-1 and answer a number.
   (refix-with be k bs t s w)
    (peep be 'refix () @ f (lit? f ? (f k bs t s w) (scare 'holo-no-refix k)))

   ;; -- pass one: lower each form, assign addresses, record labels -> (items . labels).
   ;; items accumulate reversed so a whole-program lay stays linear.
   ;; ('align n) pads with the backend's nop unit cycled to the exact count; the pad is never
   ;; executed, so a torn unit is harmless. --
   (pad-to be addr n)
      (: k ((n - addr % n) % n)
         unit (peep be 'nop '(144))
         (fill j u) (? (j < 1) ()
                       !(two? u) (fill j unit)
                       (<u . fill (j - 1) >u))
         (fill k unit))
   ;; (li d 0) -> (xor d d d) where the backend pins 'zeroxor and nothing reads the flags it clobbers
   (zeroidiom be ins rest)
      (<ins = 'li && ins 2 = 0 && be 'zeroxor && flagfree be rest 64 ?
         ['xor (ins 1) (ins 1) (ins 1)] ins)
   ;; the flags are free if a writer, call or ret comes before any reader within k forms. a
   ;; jump may reach an unseen reader, so it answers no; a label is transparent, as only the
   ;; fall-through carries these flags.
   (flagfree be l k)
      (k < 1 || atom? l ? 0
         (<(<l) @ o
            (? (elem o (be 'flagr)) 0
               (elem o (be 'flagw)) 1
               (elem o '(call ret sys)) 1
               (elem o '(jmp jmpr jmpm)) 0
               (flagfree be >l (k - 1)))))
   (lay prog be addr items labels)
      (!(two? prog) ? (rev items . labels)
         (<prog @ ins
            (? (<ins = 'label)
               (pin labels (ins 1) addr, lay >prog be addr items labels)
               (<ins = 'align)
               (revonto (pad-to be addr (ins 1)) items 0 @ r
                  (lay >prog be (addr + <r) >r labels))
               ; ..and in a section nothing executes, zeros: the pad is data a reader sees
               (<ins = 'dalign)
               (: r (revonto (map (i \ 0) ^((ins 1 - addr % ins 1) % ins 1)) items 0)
                  (lay >prog be (addr + <r) >r labels))
               (: r (revonto (lower-with be (zeroidiom be ins >prog)) items 0)
                  (lay >prog be (addr + <r) >r labels)))))

   ;; -- pass two: stream the items out, resolving each fixup. an unbound label in `open`
   ;; stays a fix, for the stream this blob splices into (inline asm jumping to its function). --
   (resolve items labels be addr) (resolve-open items labels be addr {})
   (resolve-open items labels be addr open)
      (atom? items ? ()
         (<items @ x
            (fix? x ?
               (labels (fix-l x) @ tgt
                  (? (imm? tgt)
                      (patch-with be (fix-k x) tgt addr (fix-w x) (fix-a x)
                       + resolve-open >items labels be (addr + fix-w x) open)
                     (peep open (fix-l x) 0) (x . resolve-open >items labels be (addr + fix-w x) open)
                     (scare 'undef-label (fix-l x))))
               (x . resolve-open >items labels be (addr + 1) open))))

   ;; -- branch relaxation fused with layout: (jmp l) / (br c l) take a short form where the
   ;; target provably fits. one pessimistic pass is sound, as distances at the all-long layout
   ;; only shrink, provided the span crosses no 'align (counted by an era pinned per label) and
   ;; the target is a label of this prog. each form lowers once. a backend opts in by pinning
   ;; 'short, (\ ins chunk rel -> bytes | ()): a shorter encoding of the jmp/br given its long
   ;; chunk and pessimistic distance, or () to keep it; any width (riscv drops a whole jal).
   ;; `longs` names labels that stay long (the object writer's weak set, kept as relocations).
   ;; local names avoid scan/rw/skip, which collide with moon/kore names in a cat'd stream. --
   (laylax prog be at0 labels longs)
      (!(lit? (peep be 'short 0)) ? (lay prog be at0 () labels)
         (: spots {} eras {}
            ;; pass one: cache each form's (len . reversed chunk); a label is (0 . ())
            (plumb p addr era acc)
               (atom? p ? (rev acc)
                  (<p @ ins
                     (? (<ins = 'label)
                        (pin spots (ins 1) addr, pin eras (ins 1) era,
                         plumb >p addr era ((0 . ()) . acc))
                        (<ins = 'align)
                        (revonto (pad-to be addr (ins 1)) () 0 @ r
                           (plumb >p (addr + <r) (era + 1) (r . acc)))
                        (: r (revonto (lower-with be (zeroidiom be ins >p)) () 0)
                           (plumb >p (addr + <r) era (r . acc))))))
            chunks (plumb prog at0 0 ())
            ;; the pessimistic address of a label this span may legally reach, or ()
            short-of (peep be 'short 0)
            (tgt-of l era)
               (spots l @ t
                  (? !(imm? t) ()
                     (peep longs l 0) ()
                     (era != peep eras l -1) ()
                     t))
            ;; pass two: pessimistic addresses (pa) decide, final ones (fa) pin labels and pads
            (stitch p cs pa fa era items)
               (atom? p ? (rev items . labels)
                  (: ins <p  k <<cs  c ><cs
                     (? (<ins = 'label)
                        (pin labels (ins 1) fa, stitch >p >cs pa fa era items)
                        (<ins = 'align)
                        (pad-to be fa (ins 1) @ pad
                           (stitch >p >cs (pa + k) (fa + tally pad) (era + 1)
                                   (rev pad + items)))
                        (elem <ins '(jmp br))
                        (: t (tgt-of (<ins = 'jmp ? (ins 1) (ins 2)) era)
                           sc (imm? t ? (short-of ins (rev c) (t - pa)))
                           (two? sc ?
                              (: r (revonto sc items 0)          ; <r counts bytes, not items
                                 (stitch >p >cs (pa + k) (fa + <r) era >r))
                              (stitch >p >cs (pa + k) (fa + k) era (c + items))))
                        (stitch >p >cs (pa + k) (fa + k) era (c + items)))))   ; c is cached reversed
            (stitch prog chunks at0 at0 0 ())))

   ;; -- assemble PROG for target -> { 'bytes 'labels }. assemble-at's `lbls` pre-binds labels
   ;; outside the blob (an address may be negative); the blob's own labels layer on top. --
   (assemble-at target prog lbls)
      (: be (backends target)
         _ (tablet? be ? () (scare 'no-backend target))
         p (lay prog be 0 () lbls)
       {'bytes (resolve <p >p be 0) 'labels >p})
   (assemble target prog) (assemble-at target prog {})
   ;; -- assemble-org: laid from org, so labels carry load addresses and an abs64 fixup resolves;
   ;; it relaxes branches (laylax), where assemble does not. --
   (assemble-org target prog org)
      (: be (backends target)
         _ (tablet? be ? () (scare 'no-backend target))
         p (laylax prog be org {} {})
       {'bytes (resolve <p >p be org) 'labels >p})
   (holo-bytes target prog) (peep (assemble target prog) 'bytes 0)   ; the bare name `holo` is the module's
   (holo-bytes-open target prog open)
      (: be (backends target)
         _ (tablet? be ? () (scare 'no-backend target))
         p (lay prog be 0 () {})
         (resolve-open <p >p be 0 open))
   (holo-bytes-at target prog org) (peep (assemble-org target prog org) 'bytes 0)
   (holo-str target prog) (string (holo-bytes target prog))
   (label-at res name)   (peep (peep res 'labels 0) name ())

   ;; -- hex, for goldens and disassembly. --
   (hex1 d)  (snip "0123456789abcdef" d (d + 1))
   (hex2 b)  (hex1 (b >> 4) + hex1 (b & 15))
   (hexs bs) (foldl (\ a b (a + hex2 b)) "" bs)
   (holo-hex target prog) (hexs (holo-bytes target prog)))
) ; module 'holo
