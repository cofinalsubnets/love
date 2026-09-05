; a64 -- the a64 backend for the neutral assembler (src/core/holo/holo.l), the second target. it shows
; the IR really is arch-neutral: the driver, the IR forms, the text front-end and the ELF linker are
; all untouched -- this file just pins a {lower,patch} pair under 'a64. every word
; here was checked against llvm-mc (--show-encoding) and llvm-objdump.
;
; a64 is a joy to target: fixed 32-bit little-endian instructions, native three-address ALU, 31
; gprs. so the IR's (add d a b) maps one-to-one -- no two-address dance like x86 needed. the register
; file is the obvious one: r0..r14 -> x0..x14, sp -> the stack pointer (encoding 31). the awkward bit
; is branches: the pc-relative offset is a bitfield inside the instruction word, not a run of bytes,
; so a fixup carries the base opcode word in its `aux` slot and `patch` ors the offset in.
;
; immediates: add/sub/cmp take a 12-bit immediate directly (a negative one flips the opcode). the
; logical ops (and/or/xor) and multiply have no simple immediate form (they need bitmask-immediate
; encoding / a scratch register), so an immediate there raises rather than emit wrong bytes -- put
; the value in a register. load after holo.l.

(module 'holo
(: ;; -- registers: r0..r14 -> x0..x14, sp -> 31 (the SP/XZR slot; we only use 31 as SP). x16 (IP0) is
   ;;    an unnamed scratch the indexed stores borrow. `lr` (x30) and `fp` (x29) are exposed by name so
   ;;    a callee that makes nested calls can spill its return address (BL clobbers x30) -- a64-only,
   ;;    no x86 analogue (CALL/RET there keep the return address on the stack implicitly). --
   ;; abstract number = hardware x-number (identity). r19..r28 are the callee-saved bank -- a glaze's
   ;; args + OVF anchor live here so they survive nested `bl` (call) sites.
   ;; x16 (IP0) is both nameable and borrowed: the indexed stores and the far-memory lane
   ;; materialize their address in it (a64-far below), so it holds nothing across those. mooncc
   ;; never asks for it, which is why the borrow is invisible there -- a hand-written lay that names
   ;; r16 must keep its own value out of the way of an `stx`/`ldx` or a beyond-12-bit ld/st.
   a64-regs (tabof
        [('sp >< 31) ('fp >< 29) ('lr >< 30)
          ('r0 >< 0) ('r1 >< 1) ('r2 >< 2) ('r3 >< 3)  ('r4 >< 4)
          ('r5 >< 5) ('r6 >< 6) ('r7 >< 7) ('r8 >< 8)  ('r9 >< 9)
          ('r10 >< 10) ('r11 >< 11) ('r12 >< 12) ('r13 >< 13) ('r14 >< 14) ('r15 >< 15)
           ; x16/x17 (the veneer scratch IP0/IP1) and x18 (the platform register)
           ; are sayable but never allocated -- mooncc names its own file (gen.l)
           ; and asks for none of them. the kernel's irq path does: it saves
           ; x0..x18 because the interrupted code is compiler output free to hold
           ; a live value in any caller-saved register, this trio included.
          ('r16 >< 16) ('r17 >< 17) ('r18 >< 18)
          ('r19 >< 19) ('r20 >< 20) ('r21 >< 21) ('r22 >< 22) ('r23 >< 23) ('r24 >< 24)
          ('r25 >< 25) ('r26 >< 26) ('r27 >< 27) ('r28 >< 28)])

   ;; -- ALU: op -> (reg-reg base word . imm base word | 0 if no immediate form). the row
   ;; list stays bound: the emitter tablet below pins the group off it. --
   a64-alu-rows
        [('add >< [0x8B000000 0x91000000]) ('sub >< [0xCB000000 0xD1000000])
          ('and >< [0x8A000000 0]) ('or >< [0xAA000000 0]) ('xor >< [0xCA000000 0])
          ('adds >< [0xAB000000 0xB1000000]) ('subs >< [0xEB000000 0xF1000000])]      ; the S-variant: set nzcv
   a64-alu (tabof a64-alu-rows)

   ;; -- condition codes: IR name -> the a64 cond field (B.cond bits[3:0]). --
   a64-cc (tabof
        [('eq >< 0) ('ne >< 1) ('ae >< 2) ('below >< 3) ('s >< 4) ('ns >< 5)
          ('vs >< 6) ('vc >< 7)
           ; p/np (x86 parity: ucomisd's unordered bit) alias vs/vc -- FCMP
           ; parks unordered in V, and nothing else here reads p/np
          ('p >< 6) ('np >< 7)
          ('above >< 8) ('be >< 9) ('ge >< 10) ('lt >< 11) ('gt >< 12) ('le >< 13)])

   (rn r) (look a64-regs r 'badreg)
   (reg-eq a b) (rn a = rn b)       ; own the name: a free read here would leak onto x64's register file

   ;; (li d imm): movz the low 16 bits, then movk each higher nonzero 16-bit lane (hw = lane index). the
   ;; lane extract is //% not &/>> -- a movz constant can be a full 64-bit word >= 2^63 (a BIGNUM in love,
   ;; e.g. the map hash mult), on which `&` drops the high limb (cf. le64). negatives normalize into [0,2^64).
   (a64-lane u k) ((u // k 65536) % 65536)                                     ; the k-th 16-bit lane (65536^k via (k 65536))
   ;; the immediate must be a number. every other operand slot is a register
   ;; name and refuses a stranger through `rn` (badreg), but an immediate slot
   ;; takes arithmetic on whatever arrives -- and a symbol survives that
   ;; arithmetic, so `(li r6 a-tbl)` in a quoted IR block (where the name never
   ;; evaluated) assembled quietly to the wrong constant. one lit-check turns
   ;; the whole class into a scare at the instruction that has it.
   (a64-li d imm)
      (: _ (? (constellation? imm) 0 (scare 'badimm imm))
         dn (rn d) u (? (imm < 0) (imm + 18446744073709551616) imm)
         l0 (a64-lane u 0) l1 (a64-lane u 1) l2 (a64-lane u 2) l3 (a64-lane u 3)
         (catall [
           (le32 (0xD2800000 | ((l0 << 5) | dn)))                               ; movz d, l0
           (? (l1 = 0) () (le32 (0xF2800000 | ((1 << 21) | ((l1 << 5) | dn)))))   ; movk d, l1, lsl 16
           (? (l2 = 0) () (le32 (0xF2800000 | ((2 << 21) | ((l2 << 5) | dn)))))   ; movk d, l2, lsl 32
           (? (l3 = 0) () (le32 (0xF2800000 | ((3 << 21) | ((l3 << 5) | dn)))))]))  ; movk d, l3, lsl 48

   ;; mov is ORR against XZR -- and encoding 31 in that form reads as the zero register, not the
   ;; stack pointer, so `(mov r9 sp)` would quietly assemble as `orr x9, xzr, xzr` (x9 <- 0). the
   ;; SP move is `add Xd, Xn, #0` instead, which is exactly `(lea d s 0)`; the guard sends you
   ;; there rather than emit the wrong register. (kernel code moves SP by name -- see spsel.)
   (a64-mov d s) (: dn (rn d) sn (rn s)
      _ (? ((dn = 31) || (sn = 31)) (scare 'a64-mov-sp [d s]) 0)
      (le32 (0xAA0003E0 | ((sn << 16) | dn))))                                       ; orr d, xzr, s

   ;; ALU. register form is the native three-address; immediate is add/sub only.
   ;; the register form is the shifted-register one, where encoding 31 is xzr in
   ;; every slot -- so `(sub sp sp r0)` assembles as `neg xzr, x0`: the stack pointer
   ;; untouched, the answer discarded, in silence. (the form that means SP is
   ;; add/sub extended-register, which no IR op spells.) the mov guard's sibling, and
   ;; louder for it -- mov at least had nowhere else to go, this one lies. move sp
   ;; with `lea` (add #0) and do the arithmetic in a plain register: mksys's
   ;; __sigsetjmp and moon's VLA lane both stage that way.
   (alu-rrr base d a b) (: dn (rn d) an (rn a) bn (rn b)
      _ (? ((dn = 31) || (an = 31) || (bn = 31)) (scare 'a64-alu-sp [d a b]) 0)
      (le32 (base | ((bn << 16) | ((an << 5) | dn)))))
   (alu-rri base d a imm) (: dn (rn d) an (rn a) (le32 (base | ((imm << 10) | ((an << 5) | dn)))))
   ;; a 12-bit immediate rides one instruction; up to 24 bits splits into the
   ;; shifted-by-12 form plus the low half (add/sub only -- a C-sized frame).
   (a64-addsub-imm op d a imm)                              ; a negative immediate flips the op (add<->sub, adds<->subs)
      (: pos  (? (imm < 0) (0 - imm) imm)
         fop  (? (imm < 0) (? (op = 'add) 'sub (op = 'sub) 'add (op = 'adds) 'subs 'adds) op)
         base ((peep a64-alu fop 0) 1)                   ; the (flipped) op's immediate base word (slot 1 of its alu row)
         (? (pos <= 4095) (alu-rri base d a pos)
            ((pos <= 16777215) && member? fop '(add sub))     ; hi12 shifted (LSL #12, bit 22), then the low tail off d
             (catall [(alu-rri (base | 0x400000) d a (pos >> 12))                    ; (the S-forms stay single: a split
                       (? ((pos % 4096) = 0) () (alu-rri base d d (pos % 4096)))])    ;  would read the tail's flags)
            (scare 'imm12-range imm)))
   ;; a logical (bitmask) immediate -> the N:immr:imms field packed at bits [22:10]: any rotated run
   ;; of ones replicated over a 2/4/8/16/32/64-bit element. 0, -1 and a two-run pattern have no
   ;; encoding at all and raise -- materialize those into a register instead.
   ;; ⚠ bit tests, never a 64-bit mask: (1 << 63) - 1 leaves fixnum range and & on the big misreads.
   (bmbit v k)  ((v >> k) & 1)
   (bmones v i) ((: (go k) (? ((i + k) = 64 || 0 = (bmbit v (i + k))) k (go (k + 1)))) 0)
   (bmctz v)    ((: (go k) (? (k = 64 || 1 = (bmbit v k)) k (go (k + 1)))) 0)
   (bmclo v)    ((: (go k) (? (k = 64 || 0 = (bmbit v (63 - k))) k (go (k + 1)))) 0)
   (bmrun? v)   (? (v = 0) 0 (: i (bmctz v) n (bmones v i) ((i + n) = 64 || 0 = (v >> (i + n)))))
   (bmelem v)   ((: (go e) (? (e = 2) 2 (: h (e // 2) m ((1 << h) - 1)
                                            (? ((v & m) = ((v >> h) & m)) (go h) e)))) 64)
   (bitmask-field imm)
      (? (imm = 0 || imm = -1) (scare 'a64-bitmask-imm imm)
         (: e (bmelem imm)
            m (? (e = 64) -1 ((1 << e) - 1))
            v (imm & m)
            r (? (bmrun? v) (: i (bmctz v) [i (bmones v i)])
                 (: w (v | (m ^ -1))                         ; the run wraps the element: ask of its complement
                    (? (bmrun? (w ^ -1))
                       (: c (bmclo w) [(64 - c) (c + (bmones w 0) - (64 - e))])
                       ())))
            (? (= () r) (scare 'a64-bitmask-imm imm)
               (: i <r
                  ct <>r
                  immr ((e - i) & (e - 1))
                  nimms ((((e - 1) ^ -1) << 1) | (ct - 1))    ; the size prefix, then imms = ones-1
                  n (((nimms >> 6) & 1) ^ 1)
                  ((n << 22) | ((immr << 16) | ((nimms & 0x3f) << 10)))))))
   (a64-logimm-base op) (? (op = 'and) 0x92000000 (op = 'or) 0xB2000000 (op = 'xor) 0xD2000000 (scare 'badlog op))
   (a64-logical-imm op d a b) (: dn (rn d) an (rn a) (le32 (a64-logimm-base op | (bitmask-field b | ((an << 5) | dn)))))
   (a64-aluop op d a b)
      (: meta (peep a64-alu op 0) rrb (meta 0) rib (meta 1)
         (? (reg? b)    (alu-rrr rrb d a b)
            (rib = 0)   (a64-logical-imm op d a b)               ; and/or/xor #imm via the bitmask encoder
            (a64-addsub-imm op d a b)))

   (a64-cmp a b)                                            ; subs xzr, a, b   /   cmp imm (cmn if neg)
      (: an (rn a)
         (? (reg? b) (: bn (rn b) (le32 (0xEB00001F | ((bn << 16) | (an << 5)))))
            (: pos (? (b < 0) (0 - b) b) base (? (b < 0) 0xB100001F 0xF100001F)
               _ (? (pos <= 4095) 0 (scare 'imm12-range b))
               (le32 (base | ((pos << 10) | (an << 5)))))))

   (a64-imul d a b)                                         ; madd d, a, b, xzr  (= mul); no imm form
      (? (reg? b) (: dn (rn d) an (rn a) bn (rn b) (le32 (0x9B007C00 | ((bn << 16) | ((an << 5) | dn)))))
         (scare 'a64-mul-imm ['imul d a b]))

   ;; loads/stores: LDR/STR scaled (offset a multiple of 8, unsigned) else LDUR/STUR unscaled (signed
   ;; 9-bit) else the far lane -- the offset materializes in x16 (IP0, outside the IR file) and the
   ;; access rides [x16, #0]; a C frame's slots run past +-256 routinely. lea is just add-immediate
   ;; (a64 has no lea).
   (a64-far ubase dt bn off)                               ; x16 = bn +- |off|, then op Rt, [x16, #0]
      (: u (? (off < 0) (0 - off) off)
         l0 (u % 65536) l1 (u // 65536)
         _ (? (u < 4294967296) 0 (scare 'mem-range off))
         _ (? (bn = 16) (scare 'far-base-x16 off) 0)         ; the base would be clobbered mid-build
         _ (? (bn = 31) (scare 'far-base-sp off) 0)          ; shifted-reg add reads Rn=31 as XZR, not SP
         (catall [
           (le32 (0xD2800000 | ((l0 << 5) | 16)))                                    ; movz x16, l0
           (? (l1 = 0) () (le32 (0xF2A00000 | ((l1 << 5) | 16))))                    ; movk x16, l1, lsl 16
           (le32 ((? (off < 0) 0xCB000000 0x8B000000) | ((16 << 16) | ((bn << 5) | 16))))    ; add/sub x16, base, x16
           (le32 (ubase | ((16 << 5) | dt)))]))                                      ; op Rt, [x16, #0]
   ;; one memory core, encodings in hand: LDR/STR scaled imm12 (units = the access width)
   ;; else LDUR/STUR unscaled imm9 else the far x16 build. every face -- word, sized,
   ;; fp -- is a spelling of it.
   (a64-mem-raw lbase ubase sc dt bn off)
      (? ((0 = (off % sc)) && (off >= 0) && ((off // sc) <= 4095))
         (le32 (ubase | (((off // sc) << 10) | ((bn << 5) | dt))))
         (? ((off >= -256) && (off <= 255))
            (le32 (lbase | (((off & 511) << 12) | ((bn << 5) | dt))))
            (a64-far ubase dt bn off)))
   (a64-mem-r lbase ubase dt bn off) (a64-mem-raw lbase ubase 8 dt bn off)   ; word units (the x16-based stores)
   (a64-mem lbase ubase d base off) (a64-mem-r lbase ubase (rn d) (rn base) off)
   (a64-ld d base off)   (a64-mem 0xF8400000 0xF9400000 d base off)
   (a64-st base off s)   (a64-mem 0xF8000000 0xF9000000 s base off)
   (a64-mem-sz lbase ubase sc d base off) (a64-mem-raw lbase ubase sc (rn d) (rn base) off)
   (a64-ld1 d base off) (a64-mem-sz 0x38800000 0x39800000 1 d base off)   ; ldrsb/ldursb Xt
   (a64-ld2 d base off) (a64-mem-sz 0x78800000 0x79800000 2 d base off)   ; ldrsh/ldursh Xt
   (a64-ld4 d base off) (a64-mem-sz 0xB8800000 0xB9800000 4 d base off)   ; ldrsw/ldursw Xt
   (a64-ldu1 d base off) (a64-mem-sz 0x38400000 0x39400000 1 d base off)  ; ldrb/ldurb Wt (zero-extends to Xt)
   (a64-ldu2 d base off) (a64-mem-sz 0x78400000 0x79400000 2 d base off)  ; ldrh/ldurh Wt
   (a64-ldu4 d base off) (a64-mem-sz 0xB8400000 0xB9400000 4 d base off)  ; ldr/ldur Wt (32-bit, zero-extends)
   (a64-st1 base off s) (a64-mem-sz 0x38000000 0x39000000 1 s base off)   ; strb/sturb Wt
   (a64-st2 base off s) (a64-mem-sz 0x78000000 0x79000000 2 s base off)   ; strh/sturh Wt
   (a64-st4 base off s) (a64-mem-sz 0xB8000000 0xB9000000 4 s base off)   ; str/stur Wt
   (a64-sx w d)                                             ; sbfm: sxtb/sxth/sxtw Xd, Wd
      (: dn (rn d)
         base (? (w = 1) 0x93401C00 (w = 2) 0x93403C00 0x93407C00)
         (le32 (base | ((dn << 5) | dn))))
   (a64-zx w d)                                             ; ubfm: uxtb/uxth Xd, Xd (w=4 clears bits 32..63)
      (: dn (rn d)
         base (? (w = 1) 0xD3401C00 (w = 2) 0xD3403C00 0xD3407C00)
         (le32 (base | ((dn << 5) | dn))))
   (a64-shiftv op d c)                                      ; lslv/lsrv/asrv Xd, Xd, Xc -- count pinned to r1 (the IR contract)
      (: _ (? (reg-eq c 'r1) 0 (scare 'shiftv-count-not-r1 [op d c]))
         _ (? (reg-eq d 'r1) (scare 'shiftv-dst-is-r1 [op d c]) 0)
         dn (rn d) cn (rn c)
         base (? (op = 'shlv) 0x9AC02000 (op = 'shrv) 0x9AC02400 (op = 'sarv) 0x9AC02800
                 (op = 'rorv) 0x9AC02C00 0x1AC02C00)         ; rorv4: the W form, count mod 32
         (le32 (base | ((cn << 16) | ((dn << 5) | dn)))))
   (a64-lea d base off)  (a64-addsub-imm 'add d base off)

   (a64-push s) (: st (rn s) (le32 (0xF81F0FE0 | st)))      ; str s, [sp, #-16]!
   (a64-pop  d) (: dt (rn d) (le32 (0xF84107E0 | dt)))      ; ldr d, [sp], #16

   (a64-neg d) (: dt (rn d) (le32 (0xCB0003E0 | ((dt << 16) | dt))))   ; sub d, xzr, d
   (a64-not d) (: dt (rn d) (le32 (0xAA2003E0 | ((dt << 16) | dt))))   ; orn d, xzr, d (mvn)
   (a64-inc d) (a64-addsub-imm 'add d d 1)
   (a64-dec d) (a64-addsub-imm 'sub d d 1)

   ;; control: B/BL carry a 26-bit offset (bits[25:0]); B.cond a 19-bit one (bits[23:5]). the offset
   ;; is pc-relative to the instruction's own address, in units of 4. the fix is the whole word.
   (a64-jmp  label)    [(fix 4 'b26 label 0x14000000)]
   (a64-call label)    [(fix 4 'b26 label 0x94000000)]
   ;; la: adrp + ADD -- the page-relative pair (+-4GB), one fixup each. adr alone
   ;; (+-1MB, and the patch masks silently) can't span love.c-scale images, and the
   ;; pair is what the ELF reloc vocabulary speaks (PG_HI21 + ABS_LO12_NC), so the
   ;; .o path rides the same lowering as the exe/native one.
   (a64-la d label)    (: dn (rn d)
                            [(fix 4 'adrp21 label (0x90000000 | dn))
                              (fix 4 'addlo12 label (0x91000000 | ((dn << 5) | dn)))])
   ;; lar: adr -- a BYTE pc-relative address (+-1MB), one fixup, translation-invariant (imm = target-site,
   ;; unlike la's page-relative adrp which is only correct at a page-aligned load). the near-label choice for
   ;; a code address inside a runtime-mmap'd w^x blob (the glaze's call-out resume point) -- a cask offset is
   ;; word- not page-aligned, so adrp+ADD would compute the wrong page. x86's la (rip-rel lea) is already this.
   (a64-lar d label)   (: dn (rn d) [(fix 4 'adr21 label (0x10000000 | dn))])
   ;; lia: the label's absolute (linked) address in d. la and lar both answer where
   ;; the label is running -- both are pc-relative, which is exactly right until the
   ;; two disagree, and in the kernel's bring-up they do: the image is linked high
   ;; and runs low until the MMU comes on, so the hop into the high mapping needs
   ;; the address the linker assigned, not the one the pc implies. that address is
   ;; a full 64-bit word, so it rides an inline literal (what `ldr xd, =sym`
   ;; assembles to) rather than an immediate:
   ;;   ldr xd, .+8    ; imm19 = 2, the literal two words ahead
   ;;   b   .+12       ; imm26 = 3, step over it
   ;;   .quad label    ; an abs64 fixup -- never resolvable in a .o, always a reloc
   ;; the two offsets are constants of the shape, so this needs no labels of its
   ;; own and no gensym. x86-64 says the same thing in one movabs.
   ;; put an ('align 8) in front of it. the literal sits at site+8, so it is
   ;; 8-byte aligned only when the site is, and an emitter cannot know its own
   ;; address. a 4-mod-8 literal is an unaligned 8-byte load: permitted on Normal
   ;; memory while sctlr.a is clear, and an Alignment fault on Device memory
   ;; whatever sctlr says -- which is exactly what the world looks like before
   ;; the MMU comes on, where a boot stub is most likely to want this.
   (a64-lia d label)   (: dn (rn d)
                            (le32 (0x58000040 | dn)         ; ldr xd, .+8
                             + le32 0x14000003              ; b .+12
                             + [(fix 8 'abs64 label 0)]))
   (a64-br cond label) (: cc (look a64-cc cond 'badcc)
                            [(fix 4 'b19 label (0x54000000 | cc))])
   ;; jmpr: BR Xn -- branch to the address held in a register (the glaze's Continue / deopt tail).
   (a64-jmpr d) (: dn (rn d) (le32 (0xD61F0000 | (dn << 5))))
   ;; callr: blr Xn -- call the address held in a register (a call through a function pointer),
   ;; linking x30. same field as BR with bit 21 set.
   (a64-callr d) (: dn (rn d) (le32 (0xD63F0000 | (dn << 5))))
   ;; mulo: d <- a*b (low 64); branch to lbl on signed overflow. a64 has no flag-setting multiply,
   ;; so detect it directly: smulh t,a,b is the high 64 bits of the signed product; the result fits a
   ;; signed 64 iff that high half equals the sign-extension of the low half. so mul d,a,b ; CMP t, d
   ;; asr #63 (== SUBS xzr, t, d, asr#63) ; B.ne lbl. smulh runs first (before MUL overwrites d), so
   ;; the scratch `t` must differ from a, b, and d.
   (a64-mulo d a b t lbl)
      (: dn (rn d) an (rn a) bn (rn b) tn (rn t)
         (catall [(le32 (0x9B407C00 | ((bn << 16) | ((an << 5) | tn))))    ; smulh t, a, b   (high 64)
                   (le32 (0x9B007C00 | ((bn << 16) | ((an << 5) | dn))))    ; mul   d, a, b   (low 64)
                   (le32 (0xEB80FC1F | ((dn << 16) | (tn << 5))))           ; subs  xzr, t, d, asr #63  (cmp)
                   [(fix 4 'b19 lbl 0x54000001)]]))                        ; b.ne  lbl
   ;; set: d <- (cond) ? 1 : 0  --  cset Xd, cond = csinc Xd, xzr, xzr, invert(cond); inverting a
   ;; cond is XOR 1 (the A64 cond encoding pairs eq/ne, vs/vc, lt/ge, gt/le on bit 0).
   (a64-set cond d)
      (: cc (look a64-cc cond 'badcc) dn (rn d)
         (le32 (0x9A9F07E0 | (((cc ^ 1) << 12) | dn))))
   ;; shifts/rotates by an immediate (the tag math -- sar/shr by 1; the map hash's rol by 32). LSL/lsr
   ;; are ubfm, asr is sbfm, ror is extr Xd,Xn,Xn,#c; rol #c = ror #(64-c) (a64 has no ROL).
   (a64-shift op d c)
      (: dn (rn d)
         (? (op = 'shl) (le32 (0xD3400000 | ((((64 - c) & 63) << 16) | (((63 - c) << 10) | ((dn << 5) | dn)))))   ; lsl = ubfm immr=(-c)&63, imms=63-c
            (op = 'shr) (le32 (0xD3400000 | ((c << 16) | ((63 << 10) | ((dn << 5) | dn)))))                        ; lsr = ubfm immr=c, imms=63
            (op = 'sar) (le32 (0x93400000 | ((c << 16) | ((63 << 10) | ((dn << 5) | dn)))))                        ; asr = sbfm immr=c, imms=63
            (op = 'ror) (le32 (0x93C00000 | ((dn << 16) | ((c << 10) | ((dn << 5) | dn)))))                        ; ror = extr Rm=Rn=d, imms=c
            (op = 'rol) (le32 (0x93C00000 | ((dn << 16) | ((((64 - c) & 63) << 10) | ((dn << 5) | dn)))))          ; rol #c = ror #(64-c)
            (op = 'ror4) (le32 (0x13800000 | ((dn << 16) | ((c << 10) | ((dn << 5) | dn)))))                       ; the W form (sf=0 N=0): writes zero-extend
            (scare 'badshift op)))
   ;; test a, b -> tst = ands XZR, a, b (set NZCV from a AND b). a register, or a bitmask immediate
   ;; (the map probe's `test r0 1` low-bit/gap check) via the bitmask encoder; Rd = xzr (31).
   (a64-test a b)
      (? (reg? b) (: an (rn a) bn (rn b) (le32 (0xEA00001F | ((bn << 16) | (an << 5)))))
         (: an (rn a) (le32 (0xF200001F | (bitmask-field b | (an << 5))))))     ; ands xzr, a, #imm
   ;; signed division: sdiv is clean three-address. remainder = a - (a/b)*b via msub and a scratch t
   ;; (clobbered, != a, b -- SDIV writes t before MSUB re-reads a, b). caller guards b != 0.
   (a64-div d a b)   (: dn (rn d) an (rn a) bn (rn b) (le32 (0x9AC00C00 | ((bn << 16) | ((an << 5) | dn)))))   ; sdiv d, a, b
   (a64-rem d a b t)
      (: dn (rn d) an (rn a) bn (rn b) tn (rn t)
         (catall [(le32 (0x9AC00C00 | ((bn << 16) | ((an << 5) | tn))))                    ; sdiv t, a, b
                   (le32 (0x9B008000 | ((bn << 16) | ((an << 10) | ((tn << 5) | dn)))))]))   ; msub d, t, b, a  ->  a - t*b
   (a64-udiv d a b)  (: dn (rn d) an (rn a) bn (rn b) (le32 (0x9AC00800 | ((bn << 16) | ((an << 5) | dn)))))   ; udiv d, a, b
   (a64-urem d a b t)
      (: dn (rn d) an (rn a) bn (rn b) tn (rn t)
         (catall [(le32 (0x9AC00800 | ((bn << 16) | ((an << 5) | tn))))                    ; udiv t, a, b
                   (le32 (0x9B008000 | ((bn << 16) | ((an << 10) | ((tn << 5) | dn)))))]))   ; msub d, t, b, a
   ;; -- the 128-bit pair kit (moon's i128/u128): a wide value rides hi x2 : lo x0, the left operand
   ;; of a binop staged in a 16-byte cell at [sp] lo / [sp+8] hi, or -- the r-twins -- in two pool
   ;; registers. each op is one IR form, so no pass can part a carry pair: adc/sbc read the flags the
   ;; instruction before them set. x16/x17 are the borrowed scratch, the contract the far-memory lane
   ;; already holds (mooncc allocates neither). a64's three-address ALU says all of this without
   ;; x86's two-address dance -- the awkward halves are the divide (there is no wide one) and the
   ;; variable shifts (a count reads MOD 64, so both bands compute and CSEL picks). --
   a64-wldp (le32 0xA94047F0)                                                 ; ldp x16, x17, [sp]: x16 = left lo, x17 = left hi
   (a64-w3 base d n m)    (le32 (base | ((m << 16) | ((n << 5) | d))))        ; op Xd, Xn, Xm
   (a64-w4 base d n m a)  (le32 (base | ((m << 16) | ((a << 10) | ((n << 5) | d)))))    ; madd/msub Xd,Xn,Xm,Xa -- extr's imms shares the Ra field
   (a64-wsel d n m cond)  (: cc (look a64-cc cond 'badcc)                   ; csel Xd, Xn, Xm, cond
                               (le32 (0x9A800000 | ((m << 16) | ((cc << 12) | ((n << 5) | d))))))
   (a64-wmov d m)         (a64-w3 0xAA000000 d 31 m)                        ; mov Xd, Xm (orr from xzr)
   (a64-wshi op d n c)                                                        ; lsl/lsr/asr Xd, Xn, #c -- a64-shift's three-address twin
      (? (op = 'shl) (le32 (0xD3400000 | ((((64 - c) & 63) << 16) | (((63 - c) << 10) | ((n << 5) | d)))))
         (op = 'shr) (le32 (0xD3400000 | ((c << 16) | ((63 << 10) | ((n << 5) | d)))))
         (le32 (0x93400000 | ((c << 16) | ((63 << 10) | ((n << 5) | d))))))
   (a64-a128 sp9) (a64-wldp + (a64-w3 0xAB000000 0 0 16 + a64-w3 0x9A000000 2 2 17))    ; adds x0,x0,x16; adc x2,x2,x17
   (a64-s128 sp9) (a64-wldp + (a64-w3 0xEB000000 0 16 0 + a64-w3 0xDA000000 2 17 2))    ; subs x0,x16,x0; sbc x2,x17,x2
   (a64-mw128 sp9) (le32 0xF94003F0                                           ; ldr x16,[sp] -- the widening product needs the low word alone
                      + (a64-w3 0x9BC07C00 2 0 16 + a64-w3 0x9B007C00 0 0 16))   ; umulh x2,x0,x16; mul x0,x0,x16
   (a64-m128 sp9)                                                             ; the low 128 of left * right: both cross terms onto the widening product
      (a64-wldp + (a64-w3 0x9B007C00 17 17 0                                ; mul   x17, x17, x0        Lhi*Rlo
       + (a64-w4 0x9B000000 17 16 2 17                                        ; madd  x17, x16, x2, x17    + Llo*Rhi
       + (a64-w3 0x9BC07C00 2 16 0                                            ; umulh x2, x16, x0
       + (a64-w3 0x8B000000 2 2 17 + a64-w3 0x9B007C00 0 16 0)))))          ; add x2,x2,x17; mul x0,x16,x0
   ;; (c128 cond sp) / (c128r cond rl rh): 0/1 <- (LEFT cond RIGHT). eq/ne fold both halves through
   ;; XOR; the ordered relations run the borrow chain and read nzcv off the high sbcs; gt/above/le/be
   ;; reverse the subtraction and read the flipped relation.
   (a64-w128cc cond chain rsub zch)
      (? (member? cond '(eq ne))       (zch + a64-set cond 'r0)
         (member? cond '(lt below ge ae)) (chain + a64-set cond 'r0)
         (cond = 'gt)    (rsub + a64-set 'lt 'r0)
         (cond = 'above) (rsub + a64-set 'below 'r0)
         (cond = 'le)    (rsub + a64-set 'ge 'r0)
         (cond = 'be)    (rsub + a64-set 'ae 'r0)
         (scare 'badcc128 cond))
   (a64-c128 cond sp9)
      (a64-wldp + a64-w128cc cond
         (a64-cmp 'r16 'r0 + a64-w3 0xFA000000 31 17 2)                     ; cmp x16,x0; sbcs xzr,x17,x2   (L-R)
         (a64-cmp 'r0 'r16 + a64-w3 0xFA000000 31 2 17)                     ; cmp x0,x16; sbcs xzr,x2,x17   (R-L)
         (a64-w3 0xCA000000 16 16 0 + (a64-w3 0xCA000000 17 17 2            ; eor x16,x16,x0; eor x17,x17,x2
          + (a64-w3 0xAA000000 16 16 17 + a64-cmp 'r16 0))))                ; orr x16,x16,x17; cmp x16,#0
   ;; the 128/64 divide pair (u128 numerator in the cell, u64 divisor on the protocol lo). a64
   ;; has no wide divide, so the high half rides udiv/msub -- leaving a remainder below the divisor --
   ;; and the low half a 64-step restoring shift. the cell, spent by the ldp, parks the high quotient.
   ;; ccmp carries the doubling's own carry-out into the comparison: a remainder under a divisor past
   ;; 2^63 still leaves 64 bits when it doubles. d = 0 answers all ones and does not trap (x86 faults);
   ;; C leaves it undefined either way.
   a64-divloop
      (le32 0xF241023F + (le32 0x93D0FE31 + (le32 0xD37FFA10                    ; tst x17,#1<<63; extr x17,x17,x16,#63; lsl x16,x16,#1
       + (le32 0xFA400222 + (le32 0xCB000222                                    ; ccmp x17,x0,#2,eq (force C on the carry-out); sub x2,x17,x0
       + (a64-wsel 17 2 17 'ae + (le32 0x9A903610                             ; csel x17,x2,x17,hs; cinc x16,x16,hs  (the quotient bit)
       + (le32 0xF1000421 + le32 0x54FFFF01))))))))                             ; subs x1,x1,#1; b.ne -8
   a64-divpre
      (a64-wldp + (le32 0x9AC00A22 + (le32 0x9B00C451                         ; udiv x2,x17,x0; msub x17,x2,x0,x17 -> the remainder
       + (le32 0xF90003E2 + (le32 0xD2800801 + a64-divloop)))))               ; str x2,[sp] (park the high quotient); mov x1,#64
   (a64-dv128 sp9) (a64-divpre + (a64-wmov 0 16 + le32 0xF94003E2))       ; the low quotient off x16, the high back off the cell
   (a64-rm128 sp9) (a64-divpre + (a64-wmov 0 17 + a64-wmov 2 31))       ; the remainder, high half 0 (rem < d)
   ;; the pair shifts by a constant: extr is the funnel (x86's SHLD/SHRD). at 64 and past it the
   ;; halves just move -- a shift by 0 is that move -- and sar floods the sign. c = 0 lays nothing:
   ;; extr has no #64 field, and gen folds that count away before it reaches here.
   (a64-shl128 c)
      (? (c = 0) ()
         (c < 64) (a64-w4 0x93C00000 2 2 0 (64 - c) + a64-wshi 'shl 0 0 c)  ; extr x2,x2,x0,#64-c; lsl x0,x0,#c
         (a64-wshi 'shl 2 0 (c - 64) + a64-wmov 0 31))                      ; lsl x2,x0,#c-64; x0 = 0
   (a64-shr128 c)
      (? (c = 0) ()
         (c < 64) (a64-w4 0x93C00000 0 2 0 c + a64-wshi 'shr 2 2 c)         ; extr x0,x2,x0,#c; lsr x2,x2,#c
         (a64-wshi 'shr 0 2 (c - 64) + a64-wmov 2 31))                      ; lsr x0,x2,#c-64; x2 = 0
   (a64-sar128 c)
      (? (c = 0) ()
         (c < 64) (a64-w4 0x93C00000 0 2 0 c + a64-wshi 'sar 2 2 c)         ; extr x0,x2,x0,#c; asr x2,x2,#c
         (a64-wshi 'sar 0 2 (c - 64) + a64-wshi 'sar 2 2 63))               ; asr x0,x2,#c-64; the sign flood
   ;; the pair shifts by a register count (x1, the IR's pinned count register; 0..127 exact). a
   ;; variable shift reads its count mod 64, so both bands compute and csel on hs picks the crossed
   ;; one. c = 0 needs its own guard: the co-shift by 64-c degenerates to a shift by 0, which keeps
   ;; the whole word where it should contribute none.
   a64-shl128v
      (a64-w3 0xCB000000 16 31 1                                              ; neg  x16, x1        (= 64-c mod 64)
       + (a64-w3 0x9AC02400 16 0 16                                           ; lsr  x16, x0, x16
       + (a64-w3 0x9AC02000 17 2 1                                            ; lsl  x17, x2, x1
       + (a64-w3 0xAA000000 17 17 16                                          ; orr  x17, x17, x16
       + (a64-cmp 'r1 0 + (a64-wsel 17 2 17 'eq                             ; c = 0: the high half is unmoved
       + (a64-addsub-imm 'sub 'r16 'r1 64 + (a64-w3 0x9AC02000 16 0 16      ; sub x16,x1,#64; lsl x16,x0,x16
       + (a64-cmp 'r1 64 + (a64-wsel 2 16 17 'ae                            ; csel x2, x16, x17, hs
       + (a64-w3 0x9AC02000 0 0 1 + a64-wsel 0 31 0 'ae)))))))))))           ; lsl x0,x0,x1; csel x0,xzr,x0,hs
   a64-shr128v
      (a64-w3 0xCB000000 16 31 1                                              ; neg  x16, x1
       + (a64-w3 0x9AC02000 16 2 16                                           ; lsl  x16, x2, x16
       + (a64-w3 0x9AC02400 17 0 1                                            ; lsr  x17, x0, x1
       + (a64-w3 0xAA000000 17 17 16                                          ; orr  x17, x17, x16
       + (a64-cmp 'r1 0 + (a64-wsel 17 0 17 'eq                             ; c = 0: the low half is unmoved
       + (a64-addsub-imm 'sub 'r16 'r1 64 + (a64-w3 0x9AC02400 16 2 16      ; sub x16,x1,#64; lsr x16,x2,x16
       + (a64-cmp 'r1 64 + (a64-wsel 0 16 17 'ae                            ; csel x0, x16, x17, hs
       + (a64-w3 0x9AC02400 2 2 1 + a64-wsel 2 31 2 'ae)))))))))))           ; lsr x2,x2,x1; csel x2,xzr,x2,hs
   a64-sar128v
      (a64-w3 0xCB000000 16 31 1                                              ; neg  x16, x1
       + (a64-w3 0x9AC02000 16 2 16                                           ; lsl  x16, x2, x16
       + (a64-w3 0x9AC02400 17 0 1                                            ; lsr  x17, x0, x1   (the low half shifts in logically)
       + (a64-w3 0xAA000000 17 17 16                                          ; orr  x17, x17, x16
       + (a64-cmp 'r1 0 + (a64-wsel 17 0 17 'eq
       + (a64-addsub-imm 'sub 'r16 'r1 64 + (a64-w3 0x9AC02800 16 2 16      ; sub x16,x1,#64; asr x16,x2,x16
       + (a64-cmp 'r1 64 + (a64-wsel 0 16 17 'ae
       + (a64-wshi 'sar 17 2 63 + (a64-w3 0x9AC02800 2 2 1                  ; the sign flood, then asr x2,x2,x1
       + a64-wsel 2 17 2 'ae))))))))))))                                       ; csel x2, x17, x2, hs
   ;; the register twins: the left pair rides two pool registers (rl lo : rh hi) instead of the cell,
   ;; the right keeps the x2:x0 protocol -- one form each, so the carry pair still can't part. the
   ;; answer lands on the protocol without touching rl/rh (x86's subtract has to go through them).
   (a64-a128r rl rh) (: l (rn rl) h (rn rh)
      (a64-w3 0xAB000000 0 0 l + a64-w3 0x9A000000 2 2 h))                  ; adds x0,x0,rl; adc x2,x2,rh
   (a64-s128r rl rh) (: l (rn rl) h (rn rh)
      (a64-w3 0xEB000000 0 l 0 + a64-w3 0xDA000000 2 h 2))                  ; subs x0,rl,x0; sbc x2,rh,x2
   (a64-mw128r rl) (: l (rn rl)
      (a64-w3 0x9BC07C00 2 0 l + a64-w3 0x9B007C00 0 0 l))                  ; umulh x2,x0,rl; mul x0,x0,rl
   (a64-m128r rl rh) (: l (rn rl) h (rn rh)
      (a64-w3 0x9B007C00 16 h 0                                               ; mul   x16, rh, x0        Lhi*Rlo
       + (a64-w4 0x9B000000 16 l 2 16                                         ; madd  x16, rl, x2, x16    + Llo*Rhi
       + (a64-w3 0x9BC07C00 2 l 0                                             ; umulh x2, rl, x0
       + (a64-w3 0x8B000000 2 2 16 + a64-w3 0x9B007C00 0 l 0)))))           ; add x2,x2,x16; mul x0,rl,x0
   (a64-c128r cond rl rh) (: l (rn rl) h (rn rh)
      (a64-w128cc cond
         (a64-cmp rl 'r0 + a64-w3 0xFA000000 31 h 2)                        ; cmp rl,x0; sbcs xzr,rh,x2
         (a64-cmp 'r0 rl + a64-w3 0xFA000000 31 2 h)                        ; cmp x0,rl; sbcs xzr,x2,rh
         (a64-w3 0xCA000000 16 l 0 + (a64-w3 0xCA000000 17 h 2
          + (a64-w3 0xAA000000 16 16 17 + a64-cmp 'r16 0)))))
   a64-sx128  (a64-wshi 'sar 2 0 63)                                        ; asr x2, x0, #63 -- the sign fills the high half
   a64-n128   (a64-w3 0xEB000000 0 31 0 + a64-w3 0xDA000000 2 31 2)       ; negs x0,x0; ngc x2,x2
   a64-inc128 (a64-addsub-imm 'adds 'r0 'r0 1 + a64-w3 0x9A000000 2 2 31) ; adds x0,x0,#1; adc x2,x2,xzr
   a64-dec128 (a64-addsub-imm 'subs 'r0 'r0 1 + a64-w3 0xDA000000 2 2 31) ; subs x0,x0,#1; sbc x2,x2,xzr

   ;; indexed addressing: a64 has no [base + ix*scale + disp] single insn, so synthesize. ADD makes
   ;; base + ix*scale (LSL #log2 scale); ldx/leax borrow the dest as the address temp, stx uses x16 (IP0,
   ;; outside the r0..r14 file, so it never clashes with an IR register).
   (a64-shiftamt scale) (? (scale = 1) 0 (scale = 2) 1 (scale = 4) 2 (scale = 8) 3 (scare 'badscale scale))
   (a64-addsh dn bn ixn amt) (le32 (0x8B000000 | ((ixn << 16) | ((amt << 10) | ((bn << 5) | dn)))))   ; add Xdn, Xbn, Xixn, lsl #amt
   (a64-ldx d base index scale disp)
      (: dn (rn d) (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale)) (a64-ld d d disp)]))
   (a64-leax d base index scale disp)
      (: dn (rn d) (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale)) (? (disp = 0) () (a64-addsub-imm 'add d d disp))]))
   (a64-stx base index scale disp s)
      (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale))                ; add x16, base, index lsl #amt
                (a64-mem-r 0xF8000000 0xF9000000 (rn s) 16 disp)])                          ; str s, [x16, #disp]
   ;; byte indexed load/store (the string/cask/map byte lanes). LDRB zero-extends to W (clearing the top
   ;; 32 of X, == x86 movzx); strb stores the low byte. disp is a raw BYTE offset (no scaling), unsigned
   ;; 12-bit. Same address synthesis as ldx/stx: ldxb borrows the dest as the address temp, stxb uses x16.
   (a64-ldxb d base index scale disp)                                                       ; d = (byte)[base + index*scale + disp]
      (: dn (rn d) (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale))     ; add Xd, base, index lsl #amt
                            (le32 (0x39400000 | ((disp << 10) | ((dn << 5) | dn))))]))          ; ldrb Wd, [Xd, #disp]
   (a64-stxb base index scale disp s)                                                       ; [base + index*scale + disp] = (byte)s
      (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale))                  ; add x16, base, index lsl #amt
                (le32 (0x39000000 | ((disp << 10) | ((16 << 5) | rn s))))])                    ; strb Ws, [x16, #disp]

   ;; -- scalar-double FP (the float glaze lane). f0..f15 -> v0..v15 (d-register view), a separate file
   ;;    from the gprs. the IR carries the SSE mnemonics (addsd/movsd/...) two-address (d = op(d,s)); we
   ;;    map each to the a64 scalar-double form, repeating d as the first source where a64 is
   ;;    three-address. type=01 (double) throughout; every word was objdump-checked.
   a64-fregs (fregs 32)                                                                      ; f0..f31 -> 0..31 (v16+ = the pure
                                                                                               ; temps: no arg, no callee-saved half)
   (frn r) (look a64-fregs r 'badfreg)
   a64-fp3 (tabof                                                                            ; SSE arith mnemonic -> the scalar-double base word (Dd = Dn OP Dm)
        [('addsd >< 0x1E602800) ('subsd >< 0x1E603800) ('mulsd >< 0x1E600800) ('divsd >< 0x1E601800)])
   (a64-fp3op op d s) (: dn (frn d) sn (frn s) (le32 (peep a64-fp3 op 0 | ((sn << 16) | ((dn << 5) | dn)))))     ; Dd = Dd OP Ds
   (a64-fmov  d s) (: dn (frn d) sn (frn s) (le32 (0x1E604000 | ((sn << 5) | dn))))           ; fmov Dd, Ds
   (a64-fcmp  a b) (: an (frn a) bn (frn b) (le32 (0x1E602000 | ((bn << 16) | (an << 5)))))   ; FCMP Da, Db (sets NZCV; unordered -> VS)
   (a64-scvtf d g) (: dn (frn d) gn (rn g) (le32 (0x9E620000 | ((gn << 5) | dn))))            ; scvtf Dd, Xg  (signed int -> double)
   (a64-fcvtzs g d) (: gn (rn g) dn (frn d) (le32 (0x9E780000 | ((dn << 5) | gn))))           ; fcvtzs Xg, Dd  (double -> signed int, toward zero)
   (a64-fmovxr d g) (: dn (frn d) gn (rn g) (le32 (0x9E670000 | ((gn << 5) | dn))))           ; fmov Dd, Xg   (gpr bits -> fpr)  == movqxr
   (a64-fmovrx g d) (: gn (rn g) dn (frn d) (le32 (0x9E660000 | ((dn << 5) | gn))))           ; fmov Xg, Dd   (fpr -> gpr bits)  == movqrx
   ;; fp memory takes the same three lanes as the integer ops -- a64-mem-raw with the
   ;; V=1 base words.
   (a64-fst base disp s) (a64-mem-raw 0xFC000000 0xFD000000 8 (frn s) (rn base) disp)   ; STR/STUR Ds, [base, #disp]
   (a64-fld d base disp) (a64-mem-raw 0xFC400000 0xFD400000 8 (frn d) (rn base) disp)   ; LDR/LDUR Dd, [base, #disp]
   ;; the 4-byte single lane (the C `float` slot): widen/narrow via fcvt, load/store an S-register (disp a multiple of 4).
   (a64-fcvt-widen  d s) (: dn (frn d) sn (frn s) (le32 (0x1E22C000 | ((sn << 5) | dn))))            ; fcvt Dd, Ss  (single -> double)  == cvtss2sd
   (a64-fcvt-narrow d s) (: dn (frn d) sn (frn s) (le32 (0x1E624000 | ((sn << 5) | dn))))            ; fcvt Sd, Ds  (double -> single)  == cvtsd2ss
   (a64-fsts base disp s) (a64-mem-raw 0xBC000000 0xBD000000 4 (frn s) (rn base) disp)  ; STR/STUR Ss, [base, #disp]
   (a64-flds d base disp) (a64-mem-raw 0xBC400000 0xBD400000 4 (frn d) (rn base) disp)  ; LDR/LDUR Sd, [base, #disp]
   (a64-xorpd d s) (: dn (frn d) sn (frn s) (le32 (0x2E201C00 | ((sn << 16) | ((dn << 5) | dn)))))   ; eor Vd.8B, Vd.8B, Vs.8B (zero a double when d==s; the grid's fvar-init)

   ;; -- the system lane: what a kernel says and a userland never does. every word below was
   ;; taken from `llvm-mc -triple=a64 --show-encoding`, and test/holo/golden.l keeps them there.
   ;;
   ;; MRS/MSR and the sys family (tlbi/ic/dc/at) are one encoding wearing four faces: the fixed
   ;; head 1101010100, an L bit (1 = read), and a 16-bit selector op0:op1:crn:crm:op2 sitting at
   ;; [20:5]. so `sreg` packs that selector once and everything below just ors it in -- a system
   ;; register is its selector with op0 = 2 or 3, a sys operation the same shape with op0 = 1.
   ;; the table is the ~score the kernel touches, and it grows: one row is one instruction.
   (sreg o0 o1 cn cm o2) ((o0 << 19) | ((o1 << 16) | ((cn << 12) | ((cm << 8) | (o2 << 5)))))
   a64-sysregs (tabof
        [('sctlr_el1 >< sreg 3 0 1 0 0) ('cpacr_el1 >< sreg 3 0 1 0 2)
          ('ttbr0_el1 >< sreg 3 0 2 0 0) ('ttbr1_el1 >< sreg 3 0 2 0 1)
          ('tcr_el1 >< sreg 3 0 2 0 2)
          ('spsr_el1 >< sreg 3 0 4 0 0) ('elr_el1 >< sreg 3 0 4 0 1)
          ('currentel >< sreg 3 0 4 2 2)
          ('esr_el1 >< sreg 3 0 5 2 0) ('far_el1 >< sreg 3 0 6 0 0)
          ('par_el1 >< sreg 3 0 7 4 0) ('mair_el1 >< sreg 3 0 10 2 0)
          ('vbar_el1 >< sreg 3 0 12 0 0) ('mpidr_el1 >< sreg 3 0 0 0 5)
          ('ctr_el0 >< sreg 3 3 0 0 1)
          ('cntfrq_el0 >< sreg 3 3 14 0 0) ('cntpct_el0 >< sreg 3 3 14 0 1)
          ('cntp_tval_el0 >< sreg 3 3 14 2 0) ('cntp_ctl_el0 >< sreg 3 3 14 2 1)])
   (a64-sysreg nm) (look a64-sysregs nm 'badsysreg)
   (a64-mrs d nm) (le32 (0xD5200000 | (a64-sysreg nm | rn d)))         ; MRS Xd, <reg>
   (a64-msr nm s) (le32 (0xD5000000 | (a64-sysreg nm | rn s)))         ; MSR <reg>, Xs

   ;; MSR (immediate): a pstate field, not a register -- op1/op2 name the field and the 4-bit
   ;; immediate rides crm. this is how interrupts mask (daifset/daifclr) and how the stack
   ;; pointer is chosen (spsel).
   a64-pstate (tabof [('spsel >< '(0 5)) ('daifset >< '(3 6)) ('daifclr >< '(3 7))])
   (a64-msri fld imm)
      (: r (peep a64-pstate fld ())
         _ (? (two? r) 0 (scare 'badpstate fld))
         _ (? ((imm >= 0) && (imm <= 15)) 0 (scare 'a64-pstate-imm imm))
         (le32 (0xD500401F | ((<r << 16) | ((imm << 8) | (<>r << 5))))))

   ;; barriers. one option table (the shareability domain) under all three; isb takes only sy,
   ;; so it is nullary here.
   a64-barrier-opts (tabof
        [('oshld >< 1) ('oshst >< 2) ('osh >< 3) ('nshld >< 5) ('nshst >< 6) ('nsh >< 7)
          ('ishld >< 9) ('ishst >< 10) ('ish >< 11) ('ld >< 13) ('st >< 14) ('sy >< 15)])
   (a64-barrier base opt) (le32 (base | (look a64-barrier-opts opt 'badbarrier << 8)))
   (a64-dsb opt) (a64-barrier 0xD503309F opt)
   (a64-dmb opt) (a64-barrier 0xD50330BF opt)

   ;; the sys operations. one table per instruction, because the operand namespaces are only
   ;; almost disjoint (dc ivac vs ic ivau) and a silent cross-read would emit the wrong cache
   ;; op. the whole-system forms take no register: spell that operand `zr` (Rt = 31 = XZR).
   a64-tlbi-ops (tabof
        [('vmalle1 >< sreg 1 0 8 7 0) ('vmalle1is >< sreg 1 0 8 3 0)
          ('vae1 >< sreg 1 0 8 7 1) ('vae1is >< sreg 1 0 8 3 1)
          ('aside1is >< sreg 1 0 8 3 2) ('alle1 >< sreg 1 4 8 7 4)])
   a64-ic-ops (tabof [('iallu >< sreg 1 0 7 5 0) ('ivau >< sreg 1 3 7 5 1)])
   a64-dc-ops (tabof
        [('ivac >< sreg 1 0 7 6 1) ('zva >< sreg 1 3 7 4 1) ('cvac >< sreg 1 3 7 10 1)
          ('cvau >< sreg 1 3 7 11 1) ('civac >< sreg 1 3 7 14 1)])
   a64-at-ops (tabof [('s1e1r >< sreg 1 0 7 8 0) ('s1e1w >< sreg 1 0 7 8 1)])
   (a64-sysrt t) (? (= t 'zr) 31 (rn t))
   (a64-sys tab bad op t) (le32 (0xD5000000 | (look tab op bad | a64-sysrt t)))

   ;; exception generation: one shape, Dxxx | (imm16 << 5) | ll. `dbrk` is a64's hlt -- the
   ;; debugger halt (hlt #0xf000 is the semihosting call), named apart from x86's `hlt`, which
   ;; stops the core and is a different instruction entirely. udf is the permanently-undefined
   ;; word, all zeros, and takes no head at all.
   (a64-exc base imm)
      (: _ (? ((imm >= 0) && (imm <= 65535)) 0 (scare 'a64-exc-imm imm))
         (le32 (base | (imm << 5))))
   (a64-udf imm) (: _ (? ((imm >= 0) && (imm <= 65535)) 0 (scare 'a64-exc-imm imm)) (le32 imm))

   ;; the dispatch: an emitter tablet (shapes in holo.l's ir-arity), rows partial-applied,
   ;; nullaries their words outright, `raw` the identity. the alu group pins off its rows.
   a64-emitters (emsof
        [('li >< a64-li) ('mov >< a64-mov) ('cmp >< a64-cmp) ('imul >< a64-imul)
          ('ld >< a64-ld) ('st >< a64-st)
          ('ld1 >< a64-ld1) ('ld2 >< a64-ld2) ('ld4 >< a64-ld4)
          ('st1 >< a64-st1) ('st2 >< a64-st2) ('st4 >< a64-st4)
          ('ldu1 >< a64-ldu1) ('ldu2 >< a64-ldu2) ('ldu4 >< a64-ldu4)
          ('sx1 >< a64-sx 1) ('sx2 >< a64-sx 2) ('sx4 >< a64-sx 4)
          ('zx1 >< a64-zx 1) ('zx2 >< a64-zx 2) ('zx4 >< a64-zx 4)
          ('shlv >< a64-shiftv 'shlv) ('shrv >< a64-shiftv 'shrv) ('sarv >< a64-shiftv 'sarv)
          ('rorv >< a64-shiftv 'rorv) ('rorv4 >< a64-shiftv 'rorv4)
          ('shl >< a64-shift 'shl) ('shr >< a64-shift 'shr) ('sar >< a64-shift 'sar)
          ('rol >< a64-shift 'rol) ('ror >< a64-shift 'ror) ('ror4 >< a64-shift 'ror4)
          ('lea >< a64-lea) ('lean >< a64-lea)           ; a consumed lea (x64 tells them apart for the escape gate)
          ('push >< a64-push) ('pop >< a64-pop)
          ('neg >< a64-neg) ('not >< a64-not) ('inc >< a64-inc) ('dec >< a64-dec)
          ('jmp >< a64-jmp) ('br >< a64-br) ('jmpr >< a64-jmpr) ('callr >< a64-callr)
          ('mulo >< a64-mulo) ('set >< a64-set) ('test >< a64-test)
          ('div >< a64-div) ('rem >< a64-rem) ('udiv >< a64-udiv) ('urem >< a64-urem)
          ('a128 >< a64-a128) ('s128 >< a64-s128)                ; -- the 128-bit pair kit --
          ('m128 >< a64-m128) ('mw128 >< a64-mw128)
          ('a128r >< a64-a128r) ('s128r >< a64-s128r) ('m128r >< a64-m128r)
          ('mw128r >< a64-mw128r) ('c128r >< a64-c128r) ('c128 >< a64-c128)
          ('shl128 >< a64-shl128) ('shr128 >< a64-shr128) ('sar128 >< a64-sar128)
          ('shl128v >< a64-shl128v) ('shr128v >< a64-shr128v) ('sar128v >< a64-sar128v)
          ('dv128 >< a64-dv128) ('rm128 >< a64-rm128)
          ('sx128 >< a64-sx128) ('n128 >< a64-n128)
          ('inc128 >< a64-inc128) ('dec128 >< a64-dec128)
          ('ldx >< a64-ldx) ('stx >< a64-stx) ('leax >< a64-leax)
          ('ldxb >< a64-ldxb) ('stxb >< a64-stxb)
          ('call >< a64-call) ('la >< a64-la) ('lar >< a64-lar) ('lia >< a64-lia)
          ('movsd >< a64-fmov)                             ; -- scalar-double FP --
          ('addsd >< a64-fp3op 'addsd) ('subsd >< a64-fp3op 'subsd)
          ('mulsd >< a64-fp3op 'mulsd) ('divsd >< a64-fp3op 'divsd)
          ('ucomisd >< a64-fcmp) ('cvtsi2sd >< a64-scvtf) ('cvttsd2si >< a64-fcvtzs)
          ('movqxr >< a64-fmovxr) ('movqrx >< a64-fmovrx)
          ('stsd >< a64-fst) ('ldsd >< a64-fld) ('stss >< a64-fsts) ('ldss >< a64-flds)
          ('cvtss2sd >< a64-fcvt-widen) ('cvtsd2ss >< a64-fcvt-narrow)
          ('xorpd >< a64-xorpd)                            ; zero a double (d==s)
          ('raw >< 1)
          ('mrs >< a64-mrs) ('msr >< a64-msr) ('msri >< a64-msri)    ; -- the system lane --
          ('dsb >< a64-dsb) ('dmb >< a64-dmb)
          ('tlbi >< a64-sys a64-tlbi-ops 'badtlbi)
          ('ic >< a64-sys a64-ic-ops 'badic)
          ('dc >< a64-sys a64-dc-ops 'baddc)
          ('at >< a64-sys a64-at-ops 'badat)
          ('brk >< a64-exc 0xD4200000) ('dbrk >< a64-exc 0xD4400000)        ; brk #imm / hlt #imm (the debugger halt)
          ('hvc >< a64-exc 0xD4000002) ('smc >< a64-exc 0xD4000003)
          ('udf >< a64-udf)
          ('isb >< le32 0xD5033FDF)                          ; isb sy
          ('wfi >< le32 0xD503207F) ('wfe >< le32 0xD503205F)
          ('eret >< le32 0xD69F03E0)
          ('ret >< le32 0xD65F03C0)                          ; ret x30
          ('sys >< le32 0xD4000001)                          ; svc #0
           ; svc with an immediate, which netbsd/aarch64 requires: it takes the
           ; syscall number from the instruction, not a register, and offers no
           ; indirect door (SYS_syscall and SYS___syscall both SIGSYS there). So
           ; a runtime number is only reachable through a table of these.
          ('svcn >< a64-exc 0xD4000001)                    ; svc #imm
          ('nop >< le32 0xD503201F)
          ('trap >< le32 0xD4200000)])                       ; brk #0
   _ (foldl (\ _ p (emrow a64-emitters <p (a64-aluop <p))) 0 a64-alu-rows)
   (a64-lower ins) (: f lower-via (? (lit? f) (f a64-emitters ins) (scare 'holo-bake-stale 'lower-via)))

   ;; a relocation: the offset is (target - site)/4, ored into the base word `aux`.
   (a64-patch kind target site width aux)
      (: rb (target - site)
         rel (rb // 4)
         (? (kind = 'b26) (le32 (aux | (rel & 67108863)))             ; 26-bit field, bits[25:0]
            (kind = 'b19) (le32 (aux | ((rel & 524287) << 5)))        ; 19-bit field, bits[23:5]
            (kind = 'adrp21) (: pg ((target // 4096) - (site // 4096))   ; adrp: page delta, immlo[30:29] immhi[23:5]
                                (le32 (aux | (((pg & 3) << 29) | (((pg >> 2) & 524287) << 5)))))
            (kind = 'addlo12) (le32 (aux | ((target % 4096) << 10)))  ; ADD #imm12: the target's low 12 (site-free)
            (kind = 'adr21) (: rb ((target - site) & 2097151)            ; adr: BYTE pc-rel, low 21 bits (two's comp); immlo[30:29] immhi[23:5]
                               (le32 (aux | (((rb & 3) << 29) | ((rb >> 2) << 5)))))
            (kind = 'abs64) (le64 (target + aux))                    ; an 8-byte absolute address; aux = the byte addend (&arr[i] = label + offset)
            (scare 'badfix kind)))

   a64 (tablet 0)
   _ (pin a64 'lower a64-lower)
   _ (pin a64 'patch a64-patch)
   _ (pin a64 'nop '(31 32 3 213))           ; the ('align n) filler unit: NOP d503201f LE
   (defbackend 'a64 a64))
) ; module 'holo
