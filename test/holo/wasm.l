; test/holo/wasm.l -- rung 0 of the wasm lane (doc/misc/plan/moon-wasm.md): a module laid by
; core/holo/wasm.l off hand-built forms, written to out/.holo.wasm for test/holo/wasm.mjs
; to validate and RUN under an engine that is not ours. what it claims: a memory64 module with
; an import, a table, a data segment, i64 arithmetic, a 64-bit address store and load, a
; call_indirect -- one function laid by hand the way rung 1 lays every function (a label
; local, one loop, one br_table, each label's body ending in a branch back to the top), and
; five lowered from holo's IR by wasm-fn, rung 1 itself.
; run: cat core/holo/holo.l core/holo/wasm.l test/holo/wasm.l | out/love

(use 'holo)

(: ;; sum 0..n by dispatch loop. locals: 0 n, 1 the label (i32), 2 acc, 3 i.
   ;; from inside the innermost block the depths are B0 0, B1 1, B2 2, the loop 3, the exit 4;
   ;; falling out of block k runs label k's body, and label 3 is the default: the exit.
   sum-body
    '((i32.const 0) (local.set 1)
      (block) (loop) (block) (block) (block)
      (local.get 1) (br_table (0 1 2) 4)
      (end)                                                   ; label 0: init
      (i64.const 0) (local.set 3) (i64.const 0) (local.set 2) (i32.const 1) (local.set 1) (br 2)
      (end)                                                   ; label 1: test i > n
      (local.get 3) (local.get 0) (i64.gt_s)
      (if) (i32.const 3) (local.set 1) (else) (i32.const 2) (local.set 1) (end) (br 1)
      (end)                                                   ; label 2: acc += i, i++
      (local.get 2) (local.get 3) (i64.add) (local.set 2)
      (local.get 3) (i64.const 1) (i64.add) (local.set 3)
      (i32.const 1) (local.set 1) (br 0)
      (end) (end)
      (local.get 2))
   ;; rung 1: the same shapes off holo's IR through wasm-fn -- a counted loop, recursion
   ;; through call (r3 and r4 survive the calls: a callee's locals are its own), labels that
   ;; fall through, the sized memory ops with a negative displacement and a scaled index,
   ;; and the flags: signed and unsigned sets, test, and a compare of two computed values.
   isum-ir '((li r1 0) (li r2 0)
             (label top) (cmp r2 r0) (br gt done) (add r1 r1 r2) (inc r2) (jmp top)
             (label done) (mov r0 r1) (ret))
   fib-ir '((cmp r0 2) (br lt base)
            (mov r3 r0) (sub r0 r0 1) (call fib) (mov r4 r0) (sub r0 r3 2) (call fib) (add r0 r0 r4) (ret)
            (label base) (ret))
   classify-ir '((cmp r0 0) (br lt neg) (br eq zero) (li r0 1) (ret)
                 (label neg) (li r0 -1) (ret)
                 (label zero) (li r0 0)
                 (label end) (ret))
   memops-ir '((li r1 -1) (st4 r0 0 r1) (ld4 r2 r0 0) (ldu4 r3 r0 0)      ; -1 and 4294967295 off one word
               (lea r4 r0 16) (st r4 -8 r3) (ld r5 r0 8)                   ; [base+8] through a negative displacement
               (li r6 3) (li r7 100) (stx r0 r6 8 0 r7) (ldx r8 r0 r6 8 0) ; [base+3*8]
               (add r0 r2 r3) (add r0 r0 r5) (add r0 r0 r8) (ret))       ; -1 + 2*4294967295 + 100
   bits-ir '((cmp r0 r1) (set below r2) (set lt r3)
             (test r0 r1) (set ne r6)
             (udiv r4 r0 2) (mov r5 r0) (shr r5 1) (cmp r4 r5) (set eq r9)
             (imul r3 r3 10) (imul r6 r6 100) (imul r9 r9 1000)
             (add r0 r2 r3) (add r0 r0 r6) (add r0 r0 r9) (ret))
   env {'fib '(fn 8 1)}
   (irfn ty prog n) (: f (wasm-fn prog n env) [ty <f >f])
   m {'types '(((i64 i64) (i64))                           ; 0: (i64 i64) -> i64
               ((i64) (i64))                                ; 1: i64 -> i64
               (() ()))                                     ; 2: () -> ()
      'imports '(("env" "sys" (func 1)))                    ; func 0
      'funcs [[0 () '((local.get 0) (local.get 1) (i64.add))]                 ; 1 add
              [1 '((1 i32) (2 i64)) sum-body]                                  ; 2 sum
              [1 () '((local.get 0) (i64.load 3 0))]                           ; 3 peek
              [0 () '((local.get 0) (local.get 1) (i64.store 3 0) (local.get 1))]   ; 4 poke
              [0 () '((local.get 0) (local.get 1) (i32.const 0) (call_indirect 0 0))]   ; 5 call2, through the table
              [2 () '((i64.const 7) (call 0) (drop))]                          ; 6 start
              (irfn 1 isum-ir 1)                                               ; 7 isum
              (irfn 1 fib-ir 1)                                                ; 8 fib
              (irfn 1 classify-ir 1)                                           ; 9 classify
              (irfn 1 memops-ir 1)                                             ; 10 memops
              (irfn 0 bits-ir 2)]                                              ; 11 bits
      'table 1 'elem '(1)
      'memory '(1 4)
      'data '((8 104 105))                                  ; "hi" at 8
      'exports '(("add" func 1) ("sum" func 2) ("peek" func 3) ("poke" func 4) ("call2" func 5) ("mem" memory 0)
                 ("isum" func 7) ("fib" func 8) ("classify" func 9) ("memops" func 10) ("bits" func 11))
      'start 6}
   _ (wasm-write "out/.holo.wasm" m)
   _ (puts ("test/holo/wasm: wrote out/.holo.wasm, " + show (tally (wasm-emit m)) + " bytes\n"))

   ;; rung 2, the type law, as a second module laid whole by wasm-program: the double lane
   ;; (doubles travel as their bits through r0), the float conditions after ucomisd packed as
   ;; bits, a float image narrowed and stored, the saturating conversions, and the overflow
   ;; flags -- adds/subs with vs, and mulo's branch. every answer is checked under node.
   dsum-ir '((xorpd f0 f0) (li r2 0)                                  ; sum 0..n as doubles, the bits back
             (label top) (cmp r2 r0) (br gt done) (cvtsi2sd f1 r2) (addsd f0 f1) (inc r2) (jmp top)
             (label done) (movqrx r0 f0) (ret))
   dops-ir '((movqxr f0 r0) (movqxr f1 r1)                            ; a*b - a/b
             (movsd f2 f0) (mulsd f2 f1) (movsd f3 f0) (divsd f3 f1) (subsd f2 f3) (movqrx r0 f2) (ret))
   dcmp-ir '((movqxr f0 r0) (movqxr f1 r1) (ucomisd f0 f1)            ; the eight conditions, bit i
            (set above r2) (set be r3) (set ae r4) (set below r5) (set eq r6) (set ne r7) (set p r8) (set np r9)
            (shl r3 1) (shl r4 2) (shl r5 3) (shl r6 4) (shl r7 5) (shl r8 6) (shl r9 7)
            (or r0 r2 r3) (or r0 r0 r4) (or r0 r0 r5) (or r0 r0 r6) (or r0 r0 r7) (or r0 r0 r8) (or r0 r0 r9) (ret))
   dabs-ir '((movqxr f0 r0) (xorpd f1 f1) (ucomisd f0 f1) (br ae pos) (subsd f1 f0) (movsd f0 f1)
             (label pos) (movqrx r0 f0) (ret))
   dcvt-ir '((cvtsi2sd f0 r0) (cvttsd2si r1 f0)                        ; n -> double -> n
             (cvtui2sd f1 r0) (cvttsd2ui r2 f1)                        ; n as unsigned, and back (saturating)
             (add r0 r1 r2) (ret))
   fimg-ir '((movqxr f0 r1) (cvtsd2ss f0 f0) (stss r0 0 f0)           ; the single's image at [base]
             (movqrx r1 f0) (zx4 r1) (st r0 8 r1)                      ; and its bits, off movqrx, at [base+8]
             (ldss f1 r0 0) (cvtss2sd f1 f1) (movqrx r0 f1) (ret))     ; widened back: the rounded double's bits
   addo-ir '((adds r0 r0 r1) (br vs ovf) (ret) (label ovf) (li r0 7777) (ret))
   subo-ir '((subs r0 r0 r1) (br vs ovf) (ret) (label ovf) (li r0 7777) (ret))
   mulo-ir '((mulo r0 r0 r1 r2 ovf) (ret) (label ovf) (li r0 7777) (ret))
   ;; a test after a ucomisd hands the flags back to the ALU: (bits & 1) with two equal reals
   fthen-ir '((movqxr f0 r0) (movqxr f1 r0) (ucomisd f0 f1) (test r1 1) (set ne r0) (ret))
   p {'fns [['dsum 1 dsum-ir] ['dops 2 dops-ir] ['dcmp 2 dcmp-ir] ['dabs 1 dabs-ir] ['dcvt 1 dcvt-ir]
            ['fimg 2 fimg-ir] ['addo 2 addo-ir] ['subo 2 subo-ir] ['mulo 2 mulo-ir] ['fthen 2 fthen-ir]]
      'exports '(dsum dops dcmp dabs dcvt fimg addo subo mulo fthen)}
   m2 (wasm-program p)
   _ (wasm-write "out/.holo2.wasm" m2)
   _ (puts ("test/holo/wasm: wrote out/.holo2.wasm, " + show (tally (wasm-emit m2)) + " bytes\n"))

   ;; rung 3, the environment: a mock of the artifact's face for port/wasm/loader.js --
   ;; the verbs the page calls, over the one import, __ai_sys with linux's numbers. [16] is the
   ;; out buffer's length and 4096 the buffer; [24] the bump pointer malloc rides; ai_init asks
   ;; the clock (228) and the kernel probe (20, which must say linux: -EBADF); ai_eval copies
   ;; its text into the buffer and write(1)s it; ai_grow mmaps a page and lands a word on it.
   malloc-ir '((li r1 24) (ld r2 r1 0) (add r3 r2 r0) (add r3 r3 15) (and r3 r3 -16) (st r1 0 r3) (mov r0 r2) (ret))
   free-ir '((ret))
   init-ir '((li r0 228) (li r1 1) (li r2 32) (call __ai_sys) (mov r3 r0)
             (li r0 20) (li r1 -1) (call __ai_sys) (cmp r0 -9) (br ne bad) (mov r0 r3) (ret)
             (label bad) (li r0 1) (ret))
   eval-ir '((li r1 16) (ld r2 r1 0)
             (label top) (ldu1 r3 r0 0) (cmp r3 0) (br eq done)
             (li r4 4096) (add r4 r4 r2) (st1 r4 0 r3) (inc r2) (inc r0) (jmp top)
             (label done) (st r1 0 r2)
             (li r0 1) (li r1 1) (li r2 4096) (li r3 16) (ld r3 r3 0) (call __ai_sys)
             (li r0 0) (ret))
   optr-ir '((li r0 4096) (ret))
   olen-ir '((li r1 16) (ld r0 r1 0) (ret))
   oreset-ir '((li r1 16) (li r2 0) (st r1 0 r2) (li r0 0) (ret))
   exit-ir '((mov r1 r0) (li r0 231) (call __ai_sys) (ret))
   grow-ir '((li r0 9) (li r1 0) (li r2 65536) (li r3 3) (li r4 34) (li r5 -1) (li r6 0) (call __ai_sys)
             (mov r1 r0) (li r2 77) (st r1 0 r2) (ld r0 r1 0) (ret))
   p3 {'imports '(("env" "__ai_sys" 7))
       'fns [['malloc 1 malloc-ir] ['free 1 free-ir] ['ai_init 0 init-ir] ['ai_eval 1 eval-ir]
             ['ai_out_ptr 0 optr-ir] ['ai_out_len 0 olen-ir] ['ai_out_reset 0 oreset-ir]
             ['ai_exit 1 exit-ir] ['ai_grow 0 grow-ir]]
       'exports '(malloc free ai_init ai_eval ai_out_ptr ai_out_len ai_out_reset ai_exit ai_grow)
       'memory '(2 8)
       'data '((24 0 0 1 0 0 0 0 0))}                     ; the bump pointer starts at 65536
   m3 (wasm-program p3)
   _ (wasm-write "out/.holo3.wasm" m3)
   _ (puts ("test/holo/wasm: wrote out/.holo3.wasm, " + show (tally (wasm-emit m3)) + " bytes\n"))
   0)
