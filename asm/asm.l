; asm -- a tiny ASSEMBLER over a neutral, low-level IR, written in ai. the IR is a flat list of
; instruction forms (a RISC-ish three-address surface over abstract registers r0..r14 + sp); a
; BACKEND lowers each form to machine-code bytes. this file is the arch-NEUTRAL half: the IR shape,
; the two-pass layout (assign addresses, then resolve label-relative fixups), the backend registry,
; and the byte/hex plumbing every target shares. two backends ride on it -- asm/x64.l (x86-64) and
; asm/arm64.l (aarch64) -- and a third drops in the same way: pin a `lower`/`patch` pair under a
; target name and the driver below never changes. load with `-l asm/asm.l -l asm/x64.l` (and/or
; `-l asm/arm64.l`); the gate is asm/asmtest.l.
;
; the IR (each form a list, the head an op symbol):
;   (label name)            ; a named address (emits no bytes)
;   (li d imm)              ; d <- immediate
;   (mov d s)              ; d <- s            (register move)
;   (add d a b) (sub ..)   ; d <- a OP b       b a register OR an immediate; also and/or/xor/imul
;   (neg d) (not d) (inc d) (dec d)            ; in-place unary
;   (cmp a b)              ; set flags from a - b
;   (ld d base off)        ; d <- [base+off]   (64-bit load)
;   (st base off s)        ; [base+off] <- s   (64-bit store)
;   (lea d base off)       ; d <- base+off     (address arithmetic)
;   (ldx d base ix sc dp)  ; d <- [base + ix*sc + dp]   (sc in 1/2/4/8)
;   (stx base ix sc dp s)  ; [base + ix*sc + dp] <- s
;   (leax d base ix sc dp) ; d <- base + ix*sc + dp
;   (shl/shr/sar/rol/ror d c)                  ; shift / rotate d in place by immediate count c
;   (test a b)             ; set flags from a AND b
;   (div d a b) (rem d a b t)                  ; signed truncating quotient / remainder; t a scratch (arm64 rem; x86 ignores)
;   (push s) (pop d)
;   (jmp label) (br cond label)                ; cond: eq ne lt le gt ge below above ae be s ns vs vc
;   (jmpr d)                                   ; indirect: jump to the address in register d
;   (adds d a b) (subs d a b)                  ; like add/sub but SET FLAGS -- pair with (br vs/vc ..)
;   (mulo d a b t lbl)                         ; d <- a*b (low 64); branch to lbl on signed overflow; t a scratch (clobbered)
;   (set cond d)                               ; d <- (cond holds) ? 1 : 0, from the last cmp's flags
;   (call label) (ret) (sys)                   ; sys = syscall/svc
;   (nop) (trap)
;   -- SSE2 double lane (x86-64 only; the float glaze): xmm registers f0..f15 --
;   (addsd/mulsd/subsd/divsd d s) etc.         ; reg-reg packed/scalar double ops (see x64-sse)
;   (ucomisd a b)                              ; compare doubles, set flags
;   (cvtsi2sd f g) (movqxr f g) (movqrx g f)   ; int->double ; gp<->xmm bit moves
;   (stsd base disp f) (ldsd f base disp)      ; movsd [base+disp]<->xmm  (spill / box store)
;
; a register operand is a SYMBOL (r0..); an immediate is a NUMBER -- `reg?` tells them apart, so the
; ALU ops take a register or an immediate in the same slot with no syntax. the abstract register
; file is what makes the IR neutral: each backend maps r0..r14/sp onto its own encoding.

(: ;; -- a 0-based list accessor (prel has none; `nth` is not bound -- it absorbs as the zero
   ;; point). instruction forms read their operands through this. --
   (at l k) (? (= k 0) (cap l) (at (cup l) (- k 1)))

   ;; -- bytes, little-endian. the leaves a backend emits immediates with. byte/le16/le32 ride the fast
   ;; &/>> path (their inputs are offsets/imm32, always < 2^31, where & is exact). le64 must NOT: a movabs
   ;; immediate can be a full 64-bit word >= 2^63 -- a BIGNUM in ai, on which `&` is broken (the high limb
   ;; is dropped). so le64 normalizes negatives into [0,2^64) and slices with //% (both bignum-exact). --
   (catall ls) (foldr cat () ls)                     ; concat a list of byte-lists
   (byte n)  (& n 255)
   (le16 n)  (L (byte n) (byte (>> n 8)))
   (le32 n)  (L (byte n) (byte (>> n 8)) (byte (>> n 16)) (byte (>> n 24)))
   (le64 n)  (: u (? (< n 0) (+ n 18446744073709551616) n)                            ; two's-complement into [0,2^64)
              ((: (go i) (? (< i 8) (link (% (// u (i 256)) 256) (go (+ i 1))) ())) 0))   ; 8 LE bytes via //% (i 256)=256^i
   (fits8  n) (&& (>= n -128) (<= n 127))
   (fits32 n) (&& (>= n -2147483648) (<= n 2147483647))

   ;; -- a register operand is a symbol, an immediate a number. --
   (reg? x)  (! (constellation? x))
   (imm? x)  (constellation? x)

   ;; -- a FIXUP: a relocation placeholder a backend drops where a label-relative field goes. it
   ;; occupies `w` bytes in the layout; the driver fills it in pass two via the backend's `patch`.
   ;; carried inline among the bytes as ('fix w kind label aux) so length and order just fall out.
   ;; `aux` is a backend scratch value -- x86 ignores it; a fixed-width arch (aarch64) stashes the
   ;; base instruction word there, since its branch offset is a bitfield WITHIN the word, not bytes.
   (fix w kind label aux) (L 'fix w kind label aux)
   (fix? x)   (? (two? x) (= (cap x) 'fix) 0)
   (fix-w x)  (at x 1)
   (fix-k x)  (at x 2)
   (fix-l x)  (at x 3)
   (fix-a x)  (at x 4)
   (item-len x) (? (fix? x) (fix-w x) 1)              ; a byte is 1; a fixup is its field width
   (chunk-len l) (foldl (\ a x (+ a (item-len x))) 0 l)

   ;; -- the backend registry. a backend is a tablet { 'lower 'patch }. --
   backends (tablet 0)
   (defbackend name be) (pin backends name be)
   (lower-with be ins)         ((peep be 'lower 0) ins)
   (patch-with be k t s w aux) ((peep be 'patch 0) k t s w aux)

   ;; -- pass one: walk the program, lower each form, assign addresses, record labels. returns
   ;; (items . labels): the flat byte/fixup stream and a name->address tablet. --
   (lay prog be addr items labels)
      (? (! (two? prog)) (link items labels)
         (: ins (cap prog)
            (? (= (cap ins) 'label)
               (: _ (pin labels (at ins 1) addr) (lay (cup prog) be addr items labels))
               (: chunk (lower-with be ins)
                  (lay (cup prog) be (+ addr (chunk-len chunk)) (cat items chunk) labels)))))

   ;; -- pass two: stream the items out, resolving each fixup against the now-known labels. --
   (resolve items labels be addr)
      (? (! (two? items)) ()
         (: x (cap items)
            (? (fix? x)
               (: tgt (peep labels (fix-l x) ())
                  _ (? (imm? tgt) 0 (scare 'undef-label (fix-l x)))
                  bs (patch-with be (fix-k x) tgt addr (fix-w x) (fix-a x))
                  (cat bs (resolve (cup items) labels be (+ addr (fix-w x)))))
               (link x (resolve (cup items) labels be (+ addr 1))))))

   ;; -- assemble PROG for TARGET. returns a tablet { 'bytes 'labels }; `asm` is the byte-list
   ;; shortcut, `asm-str` packs them into a machine-code string, `asm-hex` shows them. --
   ;; -- assemble-at: like assemble, but `lbls` is a PRE-BOUND label tablet (name -> address). A
   ;; client that emits a blob into a larger buffer seeds the EXTERNAL targets it jumps to -- e.g.
   ;; the glaze seeds its deopt handler as `deopt -> (OVF - blob-start)`, so a `(jmp deopt)` inside
   ;; the IR resolves to a rel32 reaching code OUTSIDE the assembled blob. The blob's own labels are
   ;; layered on top by `lay`; an address may be negative (a target before the blob). --
   (assemble-at target prog lbls)
      (: be (peep backends target ())
         _ (? (book? be) 0 (scare 'no-backend target))
         p (lay prog be 0 () lbls)
         res (tablet 0)
         _ (pin res 'bytes  (resolve (cap p) (cup p) be 0))
         _ (pin res 'labels (cup p))
         res)
   (assemble target prog) (assemble-at target prog (tablet 0))
   (asm target prog)     (peep (assemble target prog) 'bytes 0)
   (asm-str target prog) (string (asm target prog))
   (label-at res name)   (peep (peep res 'labels 0) name ())

   ;; -- hex, for goldens and disassembly. --
   (hex1 d)  (snip "0123456789abcdef" d (+ d 1))
   (hex2 b)  (+ (hex1 (>> b 4)) (hex1 (& b 15)))
   (hexs bs) (foldl (\ a b (+ a (hex2 b))) "" bs)
   (asm-hex target prog) (hexs (asm target prog)))
