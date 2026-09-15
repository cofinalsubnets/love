; wasm fuzz -- random holo IR lowered by wasm-fn, run under node, every answer held to what
; the program means. the other lanes read their bytes back through a foreign disassembler;
; wasm has none in the tree and none on most boxes (no wabt, and llvm-mc does not disassemble
; a module), so the second opinion here is the ENGINE: v8 decodes and runs what we laid, and
; a wrong immediate or a mis-lowered shift stops being a plausible number.
;
; the model is the point. every op is simulated over an unsigned 64-bit register file with
; wasm's own semantics -- shr_u against shr_s, i64.mul wrapping, div_u -- so the expectation
; comes from the instruction's MEANING and not from a second run of our own code.
; run: cat love/holo/holo.l love/holo/wasm.l love/holo/wasmfn.l test/holo/fuzz/wasm.l | out/love

(borrow 'holo)
(borrow 'posix)

(: M64 18446744073709551616
   H64 9223372036854775808
   (mask64 x) (% ((% x M64) + M64) M64)
   (sgn64 u) (u >= H64 ? (u - M64) u)                 ; the answer node hands back is signed
   (pow2 k) ((: (go i a) (i = k ? a (go (i + 1) (2 * a)))) 0 1)

   RS (tablet 0)                                      ; the boxed RNG, fuzz.l's shape
   (rseed s) (pin RS 0 (wheel s))
   (rnd n) (: r (random (peep RS 0 0) n) _ (pin RS 0 >r) <r)
   (rint a b) (a + rnd (b - a + 1))
   (pick l) (l (rnd #l))
   (coin _) (rnd 2)

   regs '(r0 r1 r2 r3 r4 r5 r6 r7)                    ; r0 is the parameter and the answer
   bins '(add sub imul and or xor)
   shifts '(shl shr sar)
   unas '(neg not inc dec)
   ; the edges a random draw never finds: the fixnum boundary, both word ends, the sign bit
   imms [0 1 -1 2 255 65536 4294967295 2147483647 -2147483648
         4611686018427387903 4611686018427387904 9223372036854775807 -9223372036854775808]
   (imm _) (coin 0 ? (pick imms) (rint -1000 1000))
   (src _) (coin 0 ? (pick regs) (imm 0))

   ; ---- one instruction, in the operand shapes wasmfn's arms actually take ----
   ; binary is 3-operand (dest, two values); a shift is 2-operand and in place; the unaries
   ; likewise. udiv's divisor is a nonzero immediate: i64.div_u TRAPS on zero, and a trap is
   ; not a wrong answer, it is a dead module.
   (gen-op _)
    (: k (rnd 12) d (pick regs)
       (? (k < 5) [(pick bins) d (src 0) (src 0)]
          (k < 9) [(pick shifts) d (rint 1 63)]      ; a zero shift asserts nothing
          (k < 11) [(pick unas) d]
          ['udiv d (src 0) (rint 1 1000)]))

   ; ---- the model: wasm's semantics, over unsigned 64-bit words ----
   (rd rf o) (elem o regs ? (peep rf o 0) (mask64 o))
   (alu op a b)
    (? (op = 'add)  (mask64 (a + b))
       (op = 'sub)  (mask64 (a - b))
       (op = 'imul) (mask64 (a * b))
       (op = 'and)  (a & b)
       (op = 'or)   (a | b)
       (op = 'xor)  (a ^ b)
       (b = 0 ? 0 (a // b)))                          ; div_u; the generator keeps b nonzero
   (shift op a k)
    (: s (% k 64) v (a >> s)
       (? (op = 'shl) (mask64 (a << s))
          (op = 'shr) v                                ; shr_u
          (a >= H64 && s > 0 ? (v | (M64 - pow2 (64 - s))) v)))   ; shr_s sign-extends
   (una op a)
    (? (op = 'neg) (mask64 (0 - a))
       (op = 'not) (a ^ (M64 - 1))
       (op = 'inc) (mask64 (a + 1))
       (mask64 (a - 1)))
   (step rf ins)
    (: op (ins 0) d (ins 1)
       (? (op = 'ret)                  rf
          (op = 'li || op = 'mov)      (pin rf d (rd rf (ins 2)))
          (elem op bins || op = 'udiv) (pin rf d (alu op (rd rf (ins 2)) (rd rf (ins 3))))
          (elem op shifts)             (pin rf d (shift op (peep rf d 0) (ins 2)))
          (elem op unas)               (pin rf d (una op (peep rf d 0)))
          (scare ("wasmfuzz: the model has no arm for " + show op))))
   (run prog x) (: rf (foldl step (pin (tablet 0) 'r0 (mask64 x)) prog)
                   (sgn64 (peep rf 'r0 0)))

   ; r1..r7 are loaded before anything reads them: an undefined register is the generator's
   ; bug, not the lowering's, and it would read as a disagreement all the same.
   (gen-prog n)
    (: pre (map (\ r ['li r (imm 0)]) (cup regs))
       body ((: (go i a) (i = n ? (rev a) (go (i + 1) (gen-op 0 . a)))) 0 ())
       (pre + body + [['mov 'r0 (pick regs)] ['ret]]))

   ev (getenv "FUZZ_N")
   N (ev && #ev > 0 ? (int ev) 120)
   sd (getenv "FUZZ_SEED")
   _ (rseed (sd && #sd > 0 ? (int sd) 20250910))
   progs (map (\ _ (gen-prog (rint 4 14))) ^N)
   ; three inputs per program: both word ends and one ordinary value, so a lowering that
   ; only breaks on a sign bit has somewhere to show
   args [(0 - H64) (0 - 1) (0 - 12345678901234567) 7 4294967296 (H64 - 1)]

   m {'types '(((i64) (i64)))
      'funcs (map (\ p (: f (wasm-fn p 1 {}) [0 <f >f])) progs)
      'memory '(1 4)
      'exports (map (\ i [("f" + show i) 'func i]) ^N)}
   _ (wasm-write "out/.wasmfuzz.wasm" m)

   ; the expectations, as json for the runner: name, argument, the answer the model says
   (row i x) ("{\"name\":\"f" + show i + "\",\"arg\":\"" + show x
              + "\",\"want\":\"" + show (run (progs i) x) + "\"}")
   rows (cats (map (\ i (map (\ x (row i x)) args)) ^N))
   q (open "out/.wasmfuzz.json" "w")
   _ (say q ("[" + (foldl (\ a r (a = "" ? r (a + "," + r))) "" rows) + "]\n"))
   _ (close q)
   (puts ("wasmfuzz: " + show N + " programs, " + show (tally rows) + " calls, "
          + show (tally (wasm-emit m)) + " bytes\n")))
