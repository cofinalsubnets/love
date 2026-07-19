; spec2coq: generate Coq from test/spec.l, in ai.
;
; The GENERATED half of the verification (see proof/rocq/spec.v for the hand-written
; LAWS -- the half a generator structurally can't do). Each top-level (assert ..)
; operand is `opfix`-factored (infix -> prefix) and translated to a Coq theorem
; closed by vm_compute, over two models that together cover every EXACT, computable
; domain in the corpus:
;   * COMPUTATIONAL (Z / list Z / assoc lists) for value equalities: church
;     numerals (app), the integer algebra (+ - * // % & | ^, comparisons), nilp /
;     sat / abs / gcd, lists / strings / arrays (asum/amax/.., iota), array-valued
;     = (broadcast / append / repeat), hashes & peep.
;   * a KIND lattice (value tags) for the type predicates (fixp/chainp/strp/..) and
;     the band order (symbol < string < number < chain < map).
; Left to the hand-written laws: the float/complex tier (not vm_compute-able, the
; honest misses) and the universally-quantified LAWS. Untranslatable asserts are
; SKIPPED and COUNTED -- never silently dropped (the trailing comment reports it).
; Z not nat: (3 3 3) = 3^27 would blow up unary-nat vm_compute.
; Reads test/spec.l, writes Coq to `out`.  Run: out/host/love tools/spec2coq.l > proof/rocq/gen.v

(: (join l) (foldl (+) "" l)                           ; join a list of strings with + (was `cat`, which shadowed the global dyadic cat)

   ; read a file's top-level forms as DATA (the reader strips ; comments)
   (forms path) (: q (open path "r") e (mint 0)
                   ((: (g acc) (: r (sound q e) (? (= e r) (rev acc) (g (link r acc))))) ()))

   (e2 l) (cap (cup l))  (e3 l) (cap (cup (cup l)))  (e4 l) (cap (cup (cup (cup l))))  ; 2nd 3rd 4th
   ; exactly three elements? (STRUCTURAL chainp, never `!`: '(0) nets zero)
   (len3? x) (&& (two? x) (two? (cup x)) (two? (cup (cup x))) (! (two? (cup (cup (cup x))))))
   ; opfix wraps an operator form one layer ((f) == f); unwrap a 1-element list
   (unwrap r) (? (&& (two? r) (! (two? (cup r)))) (cap r) r)
   (fix1 x) (unwrap (opfix x))

   ; an integer binary operator symbol -> its Coq function (prefix), else 0
   (binop h) (? (id? h '+) "Z.add"  (id? h '-) "Z.sub"  (id? h '*) "Z.mul"
                (id? h '//) "Z.quot" (id? h '%) "Z.rem"  (id? h 'gcd) "Z.gcd"
                (id? h '&) "Z.land"  (id? h '|) "Z.lor"  (id? h '^) "Z.lxor"  0)
   bs (intern "\\")                                     ; the quote symbol \ (for '(..) z-list data)
   (zlist? l) (? (two? l) (&& (charm? (cap l)) (zlist? (cup l))) (id? l ()))  ; PROPER fixnum list (ends in (), not any atom)
   (qlist? x) (&& (two? x) (id? (cap x) bs) (un2? x) (zlist? (e2 x)))  ; '(1 2 3): \ + a z-list, EXACTLY 2 (a lambda is 3+)
   (arrv? x)  (&& (two? x) (id? (cap x) 'tuple) (zlist? (cup x)))      ; @(1 2 3) = (tuple 1 2 3): a z-array
   (iotav? x) (&& (two? x) (id? (cap x) 'iota) (un2? x) (intv? (e2 x)))  ; (iota n): the z-array 0..n-1
   (un2? x) (&& (two? (cup x)) (! (two? (cup (cup x))))) ; a 2-element (op arg) form
   ; the KIND of a collection value -- arrays BROADCAST elementwise, lists APPEND
   (arr? x) (| (arrv? x) (| (iotav? x)
              (&& (two? x) (len3? x) (: h (cap x)
                 (? (id? h '+) (&& (arr? (e2 x)) (arr? (e3 x)))
                    (| (id? h '*) (id? h '//)) (&& (arr? (e2 x)) (intv? (e3 x))) 0)))))
   (lst? x) (| (qlist? x) (| (string? x)
              (&& (two? x) (len3? x) (: h (cap x)
                 (? (id? h '+) (&& (| (lst? (e2 x)) (intv? (e2 x))) (lst? (e3 x)))  ; append / scalar prepend
                    (id? h '*) (&& (lst? (e2 x)) (intv? (e3 x))) 0)))))             ; repeat
   (listv? x) (| (arr? x) (lst? x))                     ; any collection value
   ; the list reducers (ai surface -> coq): net -> asum, prod -> aprod, max/min, tally -> count
   (lop? h) (| (id? h 'net) (| (id? h 'prod) (| (id? h 'tally) (| (id? h 'max) (id? h 'min)))))
   ; a hash literal #(k v ..) = (hash k v ..): an assoc list of fixnum chains (EVEN count)
   (even? l) (? (two? l) (! (even? (cup l))) 1)
   (hashv? x) (&& (two? x) (id? (cap x) 'hash) (zlist? (cup x)) (even? (cup x)))
   (len4? x) (&& (two? x) (two? (cup x)) (two? (cup (cup x)))
                 (two? (cup (cup (cup x)))) (! (two? (cup (cup (cup (cup x)))))))
   (chains l) (? (&& (two? l) (two? (cup l)))
               ("(" + (tv (cap l)) + ", " + (tv (e2 l)) + ")" + (? (two? (cup (cup l))) ";" "") + (chains (cup (cup l)))) "")
   (th x) ("[" + (chains (cup x)) + "]")             ; #(1 10 2 20) -> [(1, 10);(2, 20)]
   ; translate a collection value to a Coq `list Z`
   (joinl l) (? (two? l) ((tv (cap l)) + (? (two? (cup l)) ";" "") + (joinl (cup l))) "")
   (joinb s i) (? (< i (tally s)) ((show (s i)) + (? (< (+ 1 i) (tally s)) ";" "") + (joinb s (+ 1 i))) "")
   (tl x) (? (qlist? x)  ("[" + (joinl (e2 x)) + "]")
             (arrv? x)   ("[" + (joinl (cup x)) + "]")    ; tuple: the elements are the cup
             (iotav? x)  ("(iotaZ " + (tv (e2 x)) + ")")   ; spec.v's iota, Z-arg face
             (string? x)    ("[" + (joinb x 0) + "]")
             (: h (cap x)                                     ; the broadcast / append / repeat ops
                (? (id? h '+)  (? (arr? x)        ("(vaddt " + (tl (e2 x)) + " " + (tl (e3 x)) + ")")
                                  (intv? (e2 x))  ("(" + (tv (e2 x)) + " :: " + (tl (e3 x)) + ")")  ; scalar prepend
                                  ("(" + (tl (e2 x)) + " ++ " + (tl (e3 x)) + ")"))                ; list append
                   (id? h '*)  (? (arr? x) ("(vscale " + (tv (e3 x)) + " " + (tl (e2 x)) + ")")     ; array scale
                                  ("(srep (Z.to_nat " + (tv (e3 x)) + ") " + (tl (e2 x)) + ")"))    ; list repeat
                   (id? h '//) ("(vquot " + (tv (e3 x)) + " " + (tl (e2 x)) + ")")  "[]")))

   ; integer-valued term? a fixnum, an operator tree, or a numeral-application spine
   (intv? x) (? (charm? x) 1
                (two? x) (: h (cap x)
                            (? (binop h)     (&& (len3? x) (intv? (e2 x)) (intv? (e3 x)))
                               (id? h 'sat)   (&& (un2? x) (| (intv? (e2 x)) (| (listv? (e2 x)) (hashv? (e2 x)))))
                               (id? h 'peep)  (&& (len4? x) (| (hashv? (e2 x)) (listv? (e2 x))) (intv? (e3 x)) (intv? (e4 x)))
                               (lop? h)       (&& (un2? x) (listv? (e2 x)))
                               (id? h 'abs)   (&& (un2? x) (intv? (e2 x)))
                               (hashv? h)     (&& (un2? x) (intv? (e2 x)))   ; (#(..) k) map lookup
                               (charm? h) (allv? x)
                               0))
                0)
   (allv? l) (? (two? l) (&& (intv? (cap l)) (allv? (cup l))) (! (two? l)))
   ; a CLOSED +/-/* tree of numeric literals: evaluable with no free vars, so we can
   ; check its actual value. the Coq model has only Vz (fixnum) for integers -- no big
   ; kind -- so an expr that OVERFLOWS a charm (e.g. (* 2 2^61) = 2^62) is unmodellable
   ; for a charm? test and must skip, not masquerade as Vz. (used by tk below.)
   (concrete-int? x) (? (two? x) (&& (len3? x) (member? (cap x) '(+ - *))
                                     (concrete-int? (e2 x)) (concrete-int? (e3 x)))
                          (&& (! (nom? x)) (! (two? x))))

   ; translate an integer-valued term to a Coq Z expression
   (tv x) (? (charm? x) (? (< x 0) ("(" + (show x) + ")") (show x))  ; parens: `Z.eqb -2` parses as subtraction
             (: h (cap x) b (binop h)
                (? b ("(" + b + " " + (tv (e2 x)) + " " + (tv (e3 x)) + ")")   ; (Z.add a b) / (Z.gcd a b)
                   (id? h 'sat)   (? (hashv? (e2 x)) ("(Z.of_nat (length " + (th (e2 x)) + "))")  ; $hash = key count
                                     (listv? (e2 x)) ("(Z.max 0 (asum " + (tl (e2 x)) + "))")
                                     ("(Z.max 0 " + (tv (e2 x)) + ")"))  ; $list / $int
                   (id? h 'net)   ("(asum " + (tl (e2 x)) + ")")   ; net/+list -- the sum
                   (id? h 'tally) ("(Z.of_nat (length " + (tl (e2 x)) + "))")  ; count
                   (id? h 'max)  ("(amax " + (tl (e2 x)) + ")")
                   (id? h 'min)  ("(amin " + (tl (e2 x)) + ")")
                   (id? h 'prod) ("(aprod " + (tl (e2 x)) + ")")
                   (id? h 'abs)   ("(Z.abs " + (tv (e2 x)) + ")")
                   (id? h 'peep)  (? (hashv? (e2 x)) ("(hget " + (th (e2 x)) + " " + (tv (e3 x)) + " " + (tv (e4 x)) + ")")
                                     ("(nth (Z.to_nat " + (tv (e3 x)) + ") " + (tl (e2 x)) + " " + (tv (e4 x)) + ")"))  ; hash lookup / array index
                   (hashv? h)     ("(hget " + (th h) + " " + (tv (e2 x)) + " 0)")  ; (#(..) k) -- lookup, default 0
                   (spine (tv h) (cup x)))))                                ; (app .. ..) spine
   (spine acc rest) (? (two? rest)
                       (spine ("(appZ " + acc + " " + (tv (cap rest)) + ")") (cup rest)) acc)

   ; the KIND tag of a literal (syntactic) for the type predicates; "Vbot" if untaggable
   (tk x) (? (intv? x) (? (&& (concrete-int? x) (! (charm? (ev x)))) "Vbot" "Vz")  ; a concrete overflow (big) is unmodellable -> skip
             (gem? x) "Vflo"  (string? x) "Vstr"  (id? x 'i) "Vcx"
             (two? x) (: h (cap x)
                        (? (id? h bs) (tkq (e2 x))                     ; '(..) or 'x
                           (id? h 'twin) "Vcx"                         ; ~(re im)
                           (id? h 'hash) "Vmap"                        ; #(..)
                           (| (id? h 'tuple) (id? h 'iota)) "Varr"     ; @(..) / (iota n)
                           "Vbot"))
             "Vbot")
   (tkq q) (? (nom? q) "Vsym" (two? q) "Vpair" (charm? q) "Vz" "Vbot")   ; the quoted datum's kind
   (kpred h) (? (id? h 'charm?) "fixp" (id? h 'gem?) "flop" (id? h 'twin?) "comp"
                (id? h 'string?) "strp" (id? h 'nom?) "nomp" (id? h 'name?) "namep" (id? h 'two?) "chainp"
                (id? h 'book?) "tabp" (id? h 'set?) "setp" (id? h 'constellation?) "nump"
                (id? h 'whole?) "whole" (id? h 'atom?) "atomp" (id? h 'packp) "packp"
                (id? h 'lit?) "lamp" 0)
   ; cross-kind ORDER: symbol<string<number<chain<map by band; same band stays value/lex
   (ordop? h) (| (id? h '<) (| (id? h '<=) (| (id? h '>) (id? h '>=))))
   (litband x) (: t (tk x)
                 (? (= t "Vbot") -1
                    (= t "Vsym") 0 (= t "Vstr") 1
                    (| (= t "Vz") (| (= t "Vflo") (| (= t "Vcx") (= t "Varr")))) 2
                    (= t "Vpair") 3 (= t "Vmap") 4  9))
   (xband? f) (&& (len3? f) (ordop? (cap f)) (>= (litband (e2 f)) 0) (>= (litband (e3 f)) 0)
                  (! (= (litband (e2 f)) (litband (e3 f)))))           ; both tagged, DIFFERENT bands
   (xband f) (: h (cap f) a ("(vband " + (tk (e2 f)) + ")") b ("(vband " + (tk (e3 f)) + ")")
               (? (id? h '<)  ("(Z.ltb " + a + " " + b + ")")  (id? h '<=) ("(Z.leb " + a + " " + b + ")")
                  (id? h '>)  ("(Z.ltb " + b + " " + a + ")")  ("(Z.leb " + b + " " + a + ")")))

   ; translate a top-level predicate to a Coq bool, or 0 if not translatable.
   ; `!` factors to `nilp`: (nil? x) is the bit "x is nothing" (x <= 0 for integers);
   ; (nil? (nil? x)) is `!!x`, x truthy -- the negation of the inner bit.
   (tp f) (? (! (two? f)) 0
             (: h (cap f)
                (? (id? h 'nil?) (: a (e2 f)
                                   (? (intv? a)  ("(Z.leb " + (tv a) + " 0)")
                                      (listv? a) ("(Z.leb (asum " + (tl a) + ") 0)")  ; !list: net <= 0
                                      (: p (tp a) (? p ("(negb " + p + ")") 0))))
                   (kpred h)  (: t (tk (e2 f)) (? (= t "Vbot") 0 ("(" + (kpred h) + " " + t + ")")))  ; (charm? 5), (two? '(..))..
                   (! (len3? f)) 0
                   (id? h '=) (? (&& (intv? (e2 f)) (intv? (e3 f)))   ("(Z.eqb " + (tv (e2 f)) + " " + (tv (e3 f)) + ")")
                                 (&& (listv? (e2 f)) (listv? (e3 f))) ("(leqb " + (tl (e2 f)) + " " + (tl (e3 f)) + ")")  ; list/array =
                                 0)
                   (xband? f) (xband f)                               ; cross-kind ordering: symbol<string<number<chain<map
                   (! (&& (intv? (e2 f)) (intv? (e3 f)))) 0           ; the within-band ORDERING ops below stay integer-only
                   (id? h '<)  ("(Z.ltb " + (tv (e2 f)) + " " + (tv (e3 f)) + ")")
                   (id? h '<=) ("(Z.leb " + (tv (e2 f)) + " " + (tv (e3 f)) + ")")
                   (id? h '>)  ("(Z.ltb " + (tv (e3 f)) + " " + (tv (e2 f)) + ")")
                   (id? h '>=) ("(Z.leb " + (tv (e3 f)) + " " + (tv (e2 f)) + ")")
                   0)))

   ; the original assert (infix, as in spec.l) shown above each theorem
   (thm n f s) ("(* " + (show f) + " *)" + (string 10) + "Theorem gen_" + (show n) + " : " + s + " = true.  Proof. vm_compute. reflexivity. Qed." + (string 10))

   nt (tablet 0) ns (tablet 0)                          ; translated / seen counters
   (bump b) (pin b 0 (+ 1 (peep b 0 0)))
   (walkops ops) (? (! ops) 0
                 (: f (cap ops) _ (bump ns) s (tp (fix1 f))
                    _ (? s (: _ (bump nt) (. (thm (peep nt 0 0) f s)))
                           (say err ("  UNMODELED: " + (show f) + (string 10))))   ; LOUD: an assert the generator can't translate -> never proved
                    (walkops (cup ops))))
   (walk fs) (? (! fs) 0
                (: f (cap fs)
                   _ (? (&& (two? f) (id? (cap f) 'assert)) (walkops (cup f)) 0)
                   (walk (cup fs))))

   _ (. (join `(
     "(* proof/rocq/gen.v -- GENERATED from test/spec.l by tools/spec2coq.l. Do not edit;" (string 10)
     "   regenerate with `make test_gen`. Each integer-comparison corpus assert is" (string 10)
     "   translated to Coq, with its source assert shown in the comment above it." (string 10)
     "   The proofs are `vm_compute. reflexivity.`: every goal is a CLOSED computation," (string 10)
     "   so vm_compute RUNS both sides (Coq's bytecode VM -- fast even on bignums like" (string 10)
     "   2^64) to a normal form, and reflexivity checks the two results are identical." (string 10)
     "   A church numeral n applied to x is x ** n (`appZ`); a list/string nets the" (string 10)
     "   sum of its elements/bytes (`asum`). The MODEL IS SHARED: this file imports" (string 10)
     "   proof/rocq/spec.v and checks against ITS definitions -- appZ/asum/aprod/amax/vscale/srep" (string 10)
     "   verbatim, iotaZ the Z-arg face, app_appZ proving appZ IS the nat `app` -- so the" (string 10)
     "   generated instances and the hand-written LAWS speak one model. The defs below are" (string 10)
     "   gen-only (no spec.v twin): amin, leqb, the TOTAL vaddt (spec.v's vadd is option-" (string 10)
     "   valued for its shape-mismatch law), vquot, hget, and the syntactic kind lattice. *)" (string 10)
     "From Stdlib Require Import ZArith List." (string 10)
     "Require Import spec." (string 10)
     "Import ListNotations." (string 10)
     "Open Scope Z_scope." (string 10)
     "Definition amin (l:list Z):Z := match l with nil=>0 | x::xs=>fold_right Z.min x xs end." (string 10)
     "Fixpoint leqb (a b:list Z):bool := match a,b with nil,nil=>true | x::a',y::b'=>andb (Z.eqb x y) (leqb a' b') | _,_=>false end." (string 10)
     "Fixpoint vaddz (a b:list Z):list Z := match a,b with x::a',y::b'=>(x+y)::vaddz a' b' | _,_=>nil end." (string 10)
     ; ai adds galaxies ELEMENTWISE only at equal length; a length mismatch answers () (net 0). the
     ; length guard makes the model faithful (a truncating vaddt would net the common prefix -- wrong).
     "Definition vaddt (a b:list Z):list Z := if Nat.eqb (length a) (length b) then vaddz a b else nil." (string 10)
     "Definition vquot (c:Z):list Z->list Z := map (fun e=>Z.quot e c)." (string 10)
     "Fixpoint hget (m:list (Z*Z)) (k d:Z):Z := match m with nil=>d | p::m' => if Z.eqb k (fst p) then snd p else hget m' k d end." (string 10)
     ; the KIND lattice: a value's tag, for the type predicates (a literal's kind is syntactic; vkind/vband avoid spec.v's value/band)
     "Inductive vkind := Vz | Vflo | Vcx | Vstr | Vsym | Vpair | Vmap | Varr | Vbot." (string 10)
     "Definition fixp  v := match v with Vz   => true | _ => false end." (string 10)
     "Definition flop  v := match v with Vflo => true | _ => false end." (string 10)
     "Definition comp  v := match v with Vcx  => true | _ => false end." (string 10)
     "Definition strp  v := match v with Vstr => true | _ => false end." (string 10)
     "Definition nomp  v := match v with Vsym => true | _ => false end." (string 10)
     "Definition namep v := match v with Vsym => true | _ => false end." (string 10)
     "Definition chainp  v := match v with Vpair=> true | _ => false end." (string 10)
     "Definition tabp  v := match v with Vmap => true | _ => false end." (string 10)
     "Definition setp  v := match v with Varr => true | _ => false end." (string 10)
     "Definition whole   v := match v with Vz   => true | _ => false end." (string 10)
     "Definition nump  v := match v with Vz|Vflo|Vcx|Varr => true | _ => false end." (string 10)
     "Definition packp v := match v with Vflo|Vcx|Varr => true | _ => false end." (string 10)
     "Definition atomp v := match v with Vpair => false | _ => true end." (string 10)
     "Definition lamp  v := match v with Vmap => true | _ => false end." (string 10)   ; lit? = the top region (map + the unmodeled fns/hots); among modeled kinds only Vmap qualifies
     "Definition vband v : Z := match v with Vsym => 0 | Vstr => 1 | Vz|Vflo|Vcx|Varr => 2 | Vpair => 3 | Vmap => 4 | Vbot => 9 end." (string 10) (string 10))))
   _ (say err ("spec2coq: UNMODELED asserts (seen but never proved) --" + (string 10)))
   _ (walk (forms "test/spec.l"))
   _ (. ((string 10) + "(* " + (show (peep nt 0 0)) + " theorems generated from " + (show (peep ns 0 0)) + " asserts seen *)" + (string 10)))
   _ (say err ("spec2coq: " + (show (peep nt 0 0)) + " translated, " + (show (- (peep ns 0 0) (peep nt 0 0))) + " UNMODELED, of " + (show (peep ns 0 0)) + " asserts seen" + (string 10)))
   (quit 0))
