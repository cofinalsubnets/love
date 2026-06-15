; spec2coq: generate Coq theorems from test/spec.l, in ai.
;
; The first slice of the .l -> .v pipeline (see proof/spec.v, the hand-written
; laws). Each top-level (assert ..) operand of the form (A = B) whose two sides
; are pure CHURCH-NUMERAL applications -- a fixnum, or a list of them, e.g.
; (3 2) or (2 3 4) -- becomes a Coq theorem  A = <app-spine B>  over the model
; app n x = x ** n, closed by computation (vm_compute). Everything else (strings,
; arrays, quoted data, the general laws) is SKIPPED and COUNTED, never silently
; dropped -- the trailing comment reports coverage. Reads test/spec.l, writes Coq
; to `out`. Run:  out/host/ai tools/spec2coq.l > proof/gen.v

(: (cat l) (foldl (+) "" l)                            ; join a list of strings

   ; read a file's top-level forms as DATA (the reader strips ; comments)
   (forms path) (: q (open path "r") e (mint 0)
                   ((: (g acc) (: r (read q e) (? (= e r) (rev acc) (g (cons r acc))))) ()))

   (e1 l) (cap l)  (e3 l) (cap (cup (cup l)))           ; A and B of (A = B)

   ; a pure-numeral term: a fixnum, or a list of pure-numeral terms
   (numt? x) (? (fixp x) 1 (twop x) (&& (numt? (cap x)) (numt? (cup x))) (! x) 1 0)

   ; translate a numeral term to a Coq expr: left-associated `app` spine
   (tm x) (? (fixp x) (show x) (twop x) (spine (tm (cap x)) (cup x)) "0")
   (spine acc rest) (? (twop rest)                      ; STRUCTURAL: '(0) nets 0, so `!` would wrongly drop it
                       (spine (cat (L "(app " acc " " (tm (cap rest)) ")")) (cup rest))
                       acc)

   ; is f exactly a 3-element (A = B) with both sides pure-numeral?
   (eqn? f) (&& (twop f) (twop (cup f)) (twop (cup (cup f))) (! (cup (cup (cup f))))
                (idp (cap (cup f)) '=) (numt? (e1 f)) (numt? (e3 f)))

   (thm n f) (cat (L "Theorem gen_" (show n) " : " (tm (e1 f)) " = " (tm (e3 f))
                     ".  Proof. vm_compute. reflexivity. Qed." (string 10)))

   nt (tablet 0) ns (tablet 0)                          ; translated / seen counters
   (bump b) (pin b 0 (+ 1 (peep b 0 0)))

   ; walk one assert's operands
   (scan ops) (? (! ops) 0
                 (: f (cap ops) _ (bump ns)
                    _ (? (eqn? f) (: _ (bump nt) (. (thm (peep nt 0 0) f))) 0)
                    (scan (cup ops))))
   ; walk the top-level forms, scanning each (assert ..)
   (walk fs) (? (! fs) 0
                (: f (cap fs)
                   _ (? (&& (twop f) (idp (cap f) 'assert)) (scan (cup f)) 0)
                   (walk (cup fs))))

   _ (. "From Stdlib Require Import ZArith.")  _ (. (string 10))
   _ (. "(* generated from test/spec.l by tools/spec2coq.l *)") _ (. (string 10))
   _ (. "Open Scope Z_scope.") _ (. (string 10))   ; Z (binary) not nat -- (app 3 3 3) is 3^27, a unary blowup
   _ (. "Definition app (n x : Z) : Z := Z.pow x n.") _ (. (string 10)) _ (. (string 10))
   _ (walk (forms "test/spec.l"))
   _ (. (cat (L (string 10) "(* " (show (peep nt 0 0)) " theorems generated from "
                (show (peep ns 0 0)) " asserts seen *)" (string 10))))
   (exit 0))
