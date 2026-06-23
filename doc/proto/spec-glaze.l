; spec-glaze.l: the 1st Futamura projection COMPOSED with the native lane -- the win interp-spec.l
; measured and the in-compiler unfold missed, captured IN the pipeline.
;
; interp-spec.l clocks a ~6.5x gap between INTERPRETING a program and running its straight-line residual;
; doc/proto/mix.l shows an OFFLINE partial evaluator closing it (~8x). this shows the glaze recognizer
; `autospec` (ai/glaze/auto.l) closing it AUTOMATICALLY: a recursive interpreter ev1 applied to a STATIC
; program P (a const-bound quoted AST) plus a DYNAMIC input is specialized by mix -- the dispatch and the
; AST navigation fold away to P's straight-line arithmetic (the Horner residual) -- and the residual loop
; then NATIVES through autogroup. so `ev` runs an interpreter-over-static-data loop as compiled code;
; `base-ev` interprets it (full ev1 dispatch every iteration). same answer, the dispatch overhead gone.
;
; the composition is the point: autospec REMOVES interpretation (rewrite level), the glaze NATIVES the
; residual (codegen level) -- mix downstreams into the same first-order fragment fib/tak/strscan ride.
;
; RUN (x86-64 host; needs the `nat` nif): the glaze is -l-loaded, so prepend it:
;   cat ai/glaze/emit.l ai/glaze/auto.l doc/proto/spec-glaze.l | out/host/ai
; (a strict `assert` self-gates correctness; the timing prints to err.)

(: prog '(: (ev1 nd x) (? (id? (cap nd) 'lit) (caup nd)  (id? (cap nd) 'var) x
                          (id? (cap nd) 'add) (+ (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))
                          (id? (cap nd) 'mul) (* (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))  0)
             P '(add (mul (add (mul (add (mul (lit 2) (var)) (lit 3)) (var)) (lit 5)) (var)) (lit 7))  ; Horner of 2x^3+3x^2+5x+7
             ; the % keeps the accumulator and each P(.) in int64 -> the loop stays PURELY native (no
             ; bignum deopt), so the timing reflects native code vs interpretation, nothing else.
             (run n) ((: (go i a) (? (< i n) (go (+ i 1) (% (+ a (ev1 P (% i 97))) 1000000007)) a)) 0 0)  run)
   natrun (ev prog)               ; glaze on: autospec specializes ev1->P, the residual loop natives
   intrun (base-ev prog)          ; glaze off: the plain interpreter, full ev1 dispatch per iteration

   ; --- correctness: the specialized native computes the SAME function as the interpreter ---
   _ (assert (= (natrun 1000)  (intrun 1000))  "specialized native == interpreted (n=1000)")
   _ (assert (= (natrun 12345) (intrun 12345)) "specialized native == interpreted (n=12345)")

   ; --- the win: time both over a big loop ---
   N 5000000
   _ (natrun 5) _ (intrun 5)      ; warm the compile cache (first call compiles)
   t0 (clock 0)  rnat (natrun N)  t1 (clock 0)  rint (intrun N)  t2 (clock 0)
   dn (- t1 t0)  di (- t2 t1)
   _ (say err "spec-glaze: N=") _ (say err (show N))
   _ (say err "  native(autospec) ") _ (say err (show dn)) _ (say err "ms")
   _ (say err "  interp ") _ (say err (show di)) _ (say err "ms")
   _ (say err "  speedup ~") _ (say err (show (/ di (? (< dn 1) 1 dn)))) _ (say err "x")
   _ (say err "  (match=") _ (say err (show (= rnat rint))) _ (say err ")\n")
   (. ";; doc/proto/spec-glaze.l: interpreter specialized to native via autospec -- correct AND faster\n"))
