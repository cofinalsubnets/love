; spec2coq: generate Coq from test/spec.l, in ai.
;
; The GENERATED half of the verification (see rocq/spec.v for the hand-written
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
; Reads test/spec.l, writes Coq to `out`.  Run: out/host/ai tools/spec2coq.l > rocq/gen.v

(: (cat l) (foldl (+) "" l)                            ; join a list of strings

   ; read a file's top-level forms as DATA (the reader strips ; comments)
   (forms path) (: q (open path "r") e (mint 0)
                   ((: (g acc) (: r (read q e) (? (= e r) (rev acc) (g (link r acc))))) ()))

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
               (cat (L "(" (tv (cap l)) ", " (tv (e2 l)) ")" (? (two? (cup (cup l))) ";" "") (chains (cup (cup l))))) "")
   (th x) (cat (L "[" (chains (cup x)) "]"))             ; #(1 10 2 20) -> [(1, 10);(2, 20)]
   ; translate a collection value to a Coq `list Z`
   (joinl l) (? (two? l) (cat (L (tv (cap l)) (? (two? (cup l)) ";" "") (joinl (cup l)))) "")
   (joinb s i) (? (< i (tally s)) (cat (L (show (s i)) (? (< (+ 1 i) (tally s)) ";" "") (joinb s (+ 1 i)))) "")
   (tl x) (? (qlist? x)  (cat (L "[" (joinl (e2 x)) "]"))
             (arrv? x)   (cat (L "[" (joinl (cup x)) "]"))    ; tuple: the elements are the cup
             (iotav? x)  (cat (L "(iota " (tv (e2 x)) ")"))   ; the Coq iota model
             (string? x)    (cat (L "[" (joinb x 0) "]"))
             (: h (cap x)                                     ; the broadcast / append / repeat ops
                (? (id? h '+)  (? (arr? x)        (cat (L "(vadd " (tl (e2 x)) " " (tl (e3 x)) ")"))
                                  (intv? (e2 x))  (cat (L "(" (tv (e2 x)) " :: " (tl (e3 x)) ")"))  ; scalar prepend
                                  (cat (L "(" (tl (e2 x)) " ++ " (tl (e3 x)) ")")))                ; list append
                   (id? h '*)  (? (arr? x) (cat (L "(vscale " (tv (e3 x)) " " (tl (e2 x)) ")"))     ; array scale
                                  (cat (L "(srep (Z.to_nat " (tv (e3 x)) ") " (tl (e2 x)) ")")))    ; list repeat
                   (id? h '//) (cat (L "(vquot " (tv (e3 x)) " " (tl (e2 x)) ")"))  "[]")))

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

   ; translate an integer-valued term to a Coq Z expression
   (tv x) (? (charm? x) (? (< x 0) (cat (L "(" (show x) ")")) (show x))  ; parens: `Z.eqb -2` parses as subtraction
             (: h (cap x) b (binop h)
                (? b (cat (L "(" b " " (tv (e2 x)) " " (tv (e3 x)) ")"))   ; (Z.add a b) / (Z.gcd a b)
                   (id? h 'sat)   (? (hashv? (e2 x)) (cat (L "(Z.of_nat (length " (th (e2 x)) "))"))  ; $hash = key count
                                     (listv? (e2 x)) (cat (L "(Z.max 0 (asum " (tl (e2 x)) "))"))
                                     (cat (L "(Z.max 0 " (tv (e2 x)) ")")))  ; $list / $int
                   (id? h 'net)   (cat (L "(asum " (tl (e2 x)) ")"))   ; net/+list -- the sum
                   (id? h 'tally) (cat (L "(Z.of_nat (length " (tl (e2 x)) "))"))  ; count
                   (id? h 'max)  (cat (L "(amax " (tl (e2 x)) ")"))
                   (id? h 'min)  (cat (L "(amin " (tl (e2 x)) ")"))
                   (id? h 'prod) (cat (L "(aprod " (tl (e2 x)) ")"))
                   (id? h 'abs)   (cat (L "(Z.abs " (tv (e2 x)) ")"))
                   (id? h 'peep)  (? (hashv? (e2 x)) (cat (L "(hget " (th (e2 x)) " " (tv (e3 x)) " " (tv (e4 x)) ")"))
                                     (cat (L "(nth (Z.to_nat " (tv (e3 x)) ") " (tl (e2 x)) " " (tv (e4 x)) ")")))  ; hash lookup / array index
                   (hashv? h)     (cat (L "(hget " (th h) " " (tv (e2 x)) " 0)"))  ; (#(..) k) -- lookup, default 0
                   (spine (tv h) (cup x)))))                                ; (app .. ..) spine
   (spine acc rest) (? (two? rest)
                       (spine (cat (L "(app " acc " " (tv (cap rest)) ")")) (cup rest)) acc)

   ; the KIND tag of a literal (syntactic) for the type predicates; "Vbot" if untaggable
   (tk x) (? (intv? x) "Vz"  (gem? x) "Vflo"  (string? x) "Vstr"  (id? x 'i) "Vcx"
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
   (xband f) (: h (cap f) a (cat (L "(band " (tk (e2 f)) ")")) b (cat (L "(band " (tk (e3 f)) ")"))
               (? (id? h '<)  (cat (L "(Z.ltb " a " " b ")"))  (id? h '<=) (cat (L "(Z.leb " a " " b ")"))
                  (id? h '>)  (cat (L "(Z.ltb " b " " a ")"))  (cat (L "(Z.leb " b " " a ")"))))

   ; translate a top-level predicate to a Coq bool, or 0 if not translatable.
   ; `!` factors to `nilp`: (nil? x) is the bit "x is nothing" (x <= 0 for integers);
   ; (nil? (nil? x)) is `!!x`, x truthy -- the negation of the inner bit.
   (tp f) (? (! (two? f)) 0
             (: h (cap f)
                (? (id? h 'nil?) (: a (e2 f)
                                   (? (intv? a)  (cat (L "(Z.leb " (tv a) " 0)"))
                                      (listv? a) (cat (L "(Z.leb (asum " (tl a) ") 0)"))  ; !list: net <= 0
                                      (: p (tp a) (? p (cat (L "(negb " p ")")) 0))))
                   (kpred h)  (: t (tk (e2 f)) (? (= t "Vbot") 0 (cat (L "(" (kpred h) " " t ")"))))  ; (charm? 5), (two? '(..))..
                   (! (len3? f)) 0
                   (id? h '=) (? (&& (intv? (e2 f)) (intv? (e3 f)))   (cat (L "(Z.eqb " (tv (e2 f)) " " (tv (e3 f)) ")"))
                                 (&& (listv? (e2 f)) (listv? (e3 f))) (cat (L "(leqb " (tl (e2 f)) " " (tl (e3 f)) ")"))  ; list/array =
                                 0)
                   (xband? f) (xband f)                               ; cross-kind ordering: symbol<string<number<chain<map
                   (! (&& (intv? (e2 f)) (intv? (e3 f)))) 0           ; the within-band ORDERING ops below stay integer-only
                   (id? h '<)  (cat (L "(Z.ltb " (tv (e2 f)) " " (tv (e3 f)) ")"))
                   (id? h '<=) (cat (L "(Z.leb " (tv (e2 f)) " " (tv (e3 f)) ")"))
                   (id? h '>)  (cat (L "(Z.ltb " (tv (e3 f)) " " (tv (e2 f)) ")"))
                   (id? h '>=) (cat (L "(Z.leb " (tv (e3 f)) " " (tv (e2 f)) ")"))
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
                   _ (? (&& (two? f) (id? (cap f) 'assert)) (scan (cup f)) 0)
                   (walk (cup fs))))

   _ (. (cat (L
     "(* rocq/gen.v -- GENERATED from test/spec.l by tools/spec2coq.l. Do not edit;" (string 10)
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
     "Definition iota (n:Z) : list Z := map Z.of_nat (seq 0 (Z.to_nat n))." (string 10)
     "Fixpoint leqb (a b:list Z):bool := match a,b with nil,nil=>true | x::a',y::b'=>andb (Z.eqb x y) (leqb a' b') | _,_=>false end." (string 10)
     "Fixpoint vadd (a b:list Z):list Z := match a,b with x::a',y::b'=>(x+y)::vadd a' b' | _,_=>nil end." (string 10)
     "Definition vscale (c:Z):list Z->list Z := map (Z.mul c)." (string 10)
     "Definition vquot (c:Z):list Z->list Z := map (fun e=>Z.quot e c)." (string 10)
     "Definition srep (n:nat) (s:list Z):list Z := concat (repeat s n)." (string 10)
     "Fixpoint hget (m:list (Z*Z)) (k d:Z):Z := match m with nil=>d | p::m' => if Z.eqb k (fst p) then snd p else hget m' k d end." (string 10)
     ; the KIND lattice: a value's tag, for the type predicates (a literal's kind is syntactic)
     "Inductive value := Vz | Vflo | Vcx | Vstr | Vsym | Vpair | Vmap | Varr | Vbot." (string 10)
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
     "Definition band  v : Z := match v with Vsym => 0 | Vstr => 1 | Vz|Vflo|Vcx|Varr => 2 | Vpair => 3 | Vmap => 4 | Vbot => 9 end." (string 10) (string 10))))
   _ (walk (forms "test/spec.l"))
   _ (. (cat (L (string 10) "(* " (show (peep nt 0 0)) " theorems generated from "
                (show (peep ns 0 0)) " asserts seen *)" (string 10))))
   (nap 0))
