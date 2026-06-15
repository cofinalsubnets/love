; spec2coq: generate Coq from test/spec.l, in ai.
;
; A slice of the .l -> .v pipeline (see proof/spec.v, the hand-written laws).
; Each top-level (assert ..) operand is run through `opfix` (the compiler's own
; factor pass -- infix to prefix, precedence and currying resolved) and, when it
; is an INTEGER comparison whose operands are integer-valued (church-numeral
; applications and the integer operators + - * // % & | ^), becomes a Coq bool
; theorem  <pred> = true  over the model app n x = x ** n, closed by computation.
; Everything else (floats, strings, the predicates, the general laws) is SKIPPED
; and COUNTED -- never silently dropped (the trailing comment reports coverage).
; Modeled over Z, not nat: (3 3 3) = 3^27 would blow up unary-nat vm_compute.
; Reads test/spec.l, writes Coq to `out`.  Run: out/host/ai tools/spec2coq.l > proof/gen.v

(: (cat l) (foldl (+) "" l)                            ; join a list of strings

   ; read a file's top-level forms as DATA (the reader strips ; comments)
   (forms path) (: q (open path "r") e (mint 0)
                   ((: (g acc) (: r (read q e) (? (= e r) (rev acc) (g (cons r acc))))) ()))

   (e2 l) (cap (cup l))  (e3 l) (cap (cup (cup l)))     ; 2nd, 3rd of a list
   ; exactly three elements? (STRUCTURAL twop, never `!`: '(0) nets zero)
   (len3? x) (&& (twop x) (twop (cup x)) (twop (cup (cup x))) (! (twop (cup (cup (cup x))))))
   ; opfix wraps an operator form one layer ((f) == f); unwrap a 1-element list
   (unwrap r) (? (&& (twop r) (! (twop (cup r)))) (cap r) r)
   (fix1 x) (unwrap (opfix x))

   ; an integer binary operator symbol -> its Coq function (prefix), else 0
   (binop h) (? (idp h '+) "Z.add"  (idp h '-) "Z.sub"  (idp h '*) "Z.mul"
                (idp h '//) "Z.quot" (idp h '%) "Z.rem"  (idp h 'gcd) "Z.gcd"
                (idp h '&) "Z.land"  (idp h '|) "Z.lor"  (idp h '^) "Z.lxor"  0)
   bs (intern "\\")                                     ; the quote symbol \ (for '(..) z-list data)
   (zlist? l) (? (twop l) (&& (fixp (cap l)) (zlist? (cup l))) (idp l ()))  ; PROPER fixnum list (ends in (), not any atom)
   (qlist? x) (&& (twop x) (idp (cap x) bs) (un2? x) (zlist? (e2 x)))  ; '(1 2 3): \ + a z-list, EXACTLY 2 (a lambda is 3+)
   (arrv? x)  (&& (twop x) (idp (cap x) 'tuple) (zlist? (cup x)))      ; @(1 2 3) = (tuple 1 2 3): a z-array
   (ajotv? x) (&& (twop x) (idp (cap x) 'ajot) (un2? x) (intv? (e2 x)))  ; (ajot n): the z-array 0..n-1
   (listv? x) (| (qlist? x) (| (strp x) (| (arrv? x) (ajotv? x))))     ; list/array-valued
   (un2? x) (&& (twop (cup x)) (! (twop (cup (cup x))))) ; a 2-element (op arg) form
   ; the list reducers: net/asum -> sum, tally/alen -> count, amax/amin/aprod
   (lop? h) (| (idp h 'net) (| (idp h 'asum) (| (idp h 'tally) (| (idp h 'alen)
              (| (idp h 'amax) (| (idp h 'amin) (idp h 'aprod)))))))
   ; translate a list/array-valued term to a Coq `list Z`
   (joinl l) (? (twop l) (cat (L (tv (cap l)) (? (twop (cup l)) ";" "") (joinl (cup l)))) "")
   (joinb s i) (? (< i (tally s)) (cat (L (show (s i)) (? (< (+ 1 i) (tally s)) ";" "") (joinb s (+ 1 i)))) "")
   (tl x) (? (qlist? x)  (cat (L "[" (joinl (e2 x)) "]"))
             (arrv? x)   (cat (L "[" (joinl (cup x)) "]"))    ; tuple: the elements are the cup
             (ajotv? x)  (cat (L "(ajot " (tv (e2 x)) ")"))   ; the Coq ajot model
             (strp x)    (cat (L "[" (joinb x 0) "]"))  "[]")

   ; integer-valued term? a fixnum, an operator tree, or a numeral-application spine
   (intv? x) (? (fixp x) 1
                (twop x) (: h (cap x)
                            (? (binop h)     (&& (len3? x) (intv? (e2 x)) (intv? (e3 x)))
                               (idp h 'sat)   (&& (un2? x) (| (intv? (e2 x)) (listv? (e2 x))))
                               (lop? h)       (&& (un2? x) (listv? (e2 x)))
                               (idp h 'abs)   (&& (un2? x) (intv? (e2 x)))
                               (fixp h) (allv? x)
                               0))
                0)
   (allv? l) (? (twop l) (&& (intv? (cap l)) (allv? (cup l))) (! (twop l)))

   ; translate an integer-valued term to a Coq Z expression
   (tv x) (? (fixp x) (? (< x 0) (cat (L "(" (show x) ")")) (show x))  ; parens: `Z.eqb -2` parses as subtraction
             (: h (cap x) b (binop h)
                (? b (cat (L "(" b " " (tv (e2 x)) " " (tv (e3 x)) ")"))   ; (Z.add a b) / (Z.gcd a b)
                   (idp h 'sat)   (? (listv? (e2 x)) (cat (L "(Z.max 0 (asum " (tl (e2 x)) "))"))
                                     (cat (L "(Z.max 0 " (tv (e2 x)) ")")))  ; $list / $int
                   (| (idp h 'net) (idp h 'asum))   (cat (L "(asum " (tl (e2 x)) ")"))   ; +list / asum -- the sum
                   (| (idp h 'tally) (idp h 'alen)) (cat (L "(Z.of_nat (length " (tl (e2 x)) "))"))  ; count
                   (idp h 'amax)  (cat (L "(amax " (tl (e2 x)) ")"))
                   (idp h 'amin)  (cat (L "(amin " (tl (e2 x)) ")"))
                   (idp h 'aprod) (cat (L "(aprod " (tl (e2 x)) ")"))
                   (idp h 'abs)   (cat (L "(Z.abs " (tv (e2 x)) ")"))
                   (spine (tv h) (cup x)))))                                ; (app .. ..) spine
   (spine acc rest) (? (twop rest)
                       (spine (cat (L "(app " acc " " (tv (cap rest)) ")")) (cup rest)) acc)

   ; translate a top-level predicate to a Coq bool, or 0 if not translatable.
   ; `!` factors to `nilp`: (nilp x) is the bit "x is nothing" (x <= 0 for integers);
   ; (nilp (nilp x)) is `!!x`, x truthy -- the negation of the inner bit.
   (tp f) (? (! (twop f)) 0
             (: h (cap f)
                (? (idp h 'nilp) (: a (e2 f)
                                   (? (intv? a)  (cat (L "(Z.leb " (tv a) " 0)"))
                                      (listv? a) (cat (L "(Z.leb (asum " (tl a) ") 0)"))  ; !list: net <= 0
                                      (: p (tp a) (? p (cat (L "(negb " p ")")) 0))))
                   (! (len3? f)) 0
                   (! (&& (intv? (e2 f)) (intv? (e3 f)))) 0
                   (idp h '=)  (cat (L "(Z.eqb " (tv (e2 f)) " " (tv (e3 f)) ")"))
                   (idp h '<)  (cat (L "(Z.ltb " (tv (e2 f)) " " (tv (e3 f)) ")"))
                   (idp h '<=) (cat (L "(Z.leb " (tv (e2 f)) " " (tv (e3 f)) ")"))
                   (idp h '>)  (cat (L "(Z.ltb " (tv (e3 f)) " " (tv (e2 f)) ")"))
                   (idp h '>=) (cat (L "(Z.leb " (tv (e3 f)) " " (tv (e2 f)) ")"))
                   0)))

   ; the original assert (infix, as in spec.l) shown above each theorem
   (thm n f s) (cat (L "(* " (show f) " *)" (string 10)
                       "Theorem gen_" (show n) " : " s " = true.  Proof. vm_compute. reflexivity. Qed." (string 10)))

   nt (tablet 0) ns (tablet 0)                          ; translated / seen counters
   (bump b) (pin b 0 (+ 1 (peep b 0 0)))
   (scan ops) (? (! ops) 0
                 (: f (cap ops) _ (bump ns) s (tp (fix1 f))
                    _ (? s (: _ (bump nt) (. (thm (peep nt 0 0) f s))) 0)
                    (scan (cup ops))))
   (walk fs) (? (! fs) 0
                (: f (cap fs)
                   _ (? (&& (twop f) (idp (cap f) 'assert)) (scan (cup f)) 0)
                   (walk (cup fs))))

   _ (. (cat (L
     "(* proof/gen.v -- GENERATED from test/spec.l by tools/spec2coq.l. Do not edit;" (string 10)
     "   regenerate with `make test_gen`. Each integer-comparison corpus assert is" (string 10)
     "   translated to Coq, with its source assert shown in the comment above it." (string 10)
     "   The proofs are `vm_compute. reflexivity.`: every goal is a CLOSED computation," (string 10)
     "   so vm_compute RUNS both sides (Coq's bytecode VM -- fast even on bignums like" (string 10)
     "   2^64) to a normal form, and reflexivity checks the two results are identical." (string 10)
     "   A church numeral n applied to x is x ** n (`app`); a list/string nets the" (string 10)
     "   sum of its elements/bytes (`asum`); $ is max(0,net), tally the count. *)" (string 10)
     "From Stdlib Require Import ZArith List." (string 10)
     "Import ListNotations." (string 10)
     "Open Scope Z_scope." (string 10)
     "Definition app (n x : Z) : Z := Z.pow x n." (string 10)
     "Definition asum  : list Z -> Z := fold_right Z.add 0." (string 10)
     "Definition aprod : list Z -> Z := fold_right Z.mul 1." (string 10)
     "Definition amax (l:list Z):Z := match l with nil=>0 | x::xs=>fold_right Z.max x xs end." (string 10)
     "Definition amin (l:list Z):Z := match l with nil=>0 | x::xs=>fold_right Z.min x xs end." (string 10)
     "Definition ajot (n:Z) : list Z := map Z.of_nat (seq 0 (Z.to_nat n))." (string 10) (string 10))))
   _ (walk (forms "test/spec.l"))
   _ (. (cat (L (string 10) "(* " (show (peep nt 0 0)) " theorems generated from "
                (show (peep ns 0 0)) " asserts seen *)" (string 10))))
   (exit 0))
