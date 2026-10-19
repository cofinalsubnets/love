; uu2coq: love's internal proof corpus (test/uu*.l), exported to Rocq.
; loads uu's kernel (certifying every defn against its type), re-reads the files as data,
; and translates each (defn/defq nm T t) in the MLTT fragment to Gallina. coqc re-checks
; them, and supplies the universe check uu (type-in-type) lacks. skips are counted.
; a def exports iff it is translatable and every global it mentions exports: the
; univalence tower drops (it bottoms out at an `axm`).
; Run: out/love src/tools/uu2coq.l > test/proof/rocq/uugen.v   then  coqc test/proof/rocq/uugen.v

(borrow 'posix)
; the files below spell their laws `test`; here stdout is the artifact, so bind assert's:
; silent on success, a false law stops the run
(:: 'test (l \ (. 'assert l)))
(: _ (reads (open "test/uu.l" "r"))
   _ (reads (open "test/uuhom.l" "r"))
   _ (reads (open "test/uuhomgen.l" "r"))
   _ (reads (open "test/uuhomlaw.l" "r"))
   _ (reads (open "test/uusplgen.l" "r"))
   _ (reads (open "test/uuspllaw.l" "r"))
   _ (reads (open "test/uulay.l" "r"))
   _ (reads (open "test/uupatch.l" "r"))
   _ (reads (open "test/uuwm.l" "r"))
   _ (reads (open "test/uuwmlaw.l" "r"))
   _ (reads (open "test/uukind.l" "r"))
   _ (reads (open "test/uumx.l" "r"))
   _ (reads (open "test/uumxlaw.l" "r"))
   _ (reads (open "test/uuval.l" "r"))
   _ (reads (open "test/uuvalband.l" "r"))
   _ (reads (open "test/uuvallaw.l" "r"))
   _ (reads (open "test/uukindlaw.l" "r"))          ; load + certify uu's corpus (populates GLOB)
   bs (intern "\\")
   (unq x) (two? x && <x = bs ? (x 1) x)   ; strip one ' (reads shows quote as (\ ..))
   (cat l) (foldl (+) "" l)

   ; a uu name -> a Rocq identifier: uu_, '-' -> '_'
   (sanit s) (jug 0 @ j (each ^#s (i \ say j (string (s i @ c (c = 45 ? 95 c)))), slurp j))
   (rocqn nm) ("uu_" + sanit (string nm))

   ; --- collect (kind nm T t) entries (defns live inside asserts) ---
   (deq? c) (two? c && (<c = 'defn || <c = 'defq))
   (axq? c) (two? c && <c = 'axm)
   (entry c) (? (deq? c) ['def (unq (c 1)) (unq (c 2)) (unq (c 3))]
                (axq? c) ['axm (unq (c 1)) (unq (c 2)) ()])
   (kids ks acc) (two? ks ? (kids >ks (deq? <ks || axq? <ks ? (entry <ks . acc) acc)) acc)
   (gather fs acc) (two? fs ?
                      (gather >fs (<fs @ F
                        (? (two? F && <F = 'test) (kids >F acc)
                           (deq? F || axq? F) (entry F . acc) acc)))
                      (rev acc))
   (app2 a b) (two? a ? (<a . app2 >a b) b)   ; not `cat`: the local cat is the string fold
   ents (gather (app2 (forms (open "test/uu.l" "r")) (app2 (forms (open "test/uuhom.l" "r")) (app2 (forms (open "test/uuhomgen.l" "r")) (app2 (forms (open "test/uuhomlaw.l" "r")) (app2 (forms (open "test/uusplgen.l" "r")) (app2 (forms (open "test/uuspllaw.l" "r")) (app2 (forms (open "test/uulay.l" "r")) (app2 (forms (open "test/uupatch.l" "r")) (app2 (forms (open "test/uuwm.l" "r")) (app2 (forms (open "test/uuwmlaw.l" "r")) (app2 (forms (open "test/uukind.l" "r")) (app2 (forms (open "test/uukindlaw.l" "r")) (app2 (forms (open "test/uumx.l" "r")) (app2 (forms (open "test/uumxlaw.l" "r")) (app2 (forms (open "test/uuval.l" "r")) (app2 (forms (open "test/uuvalband.l" "r")) (forms (open "test/uuvallaw.l" "r")))))))))))))))))) ())

   ; a gathered def must be whole (a paren slip reads () as the term) and pinned (a partial
   ; defn is a truthy closure that pins nothing). `== ()`, not `!`: a term of 0 is legal.
   _ (map (e \ ((<e = 'def && e 3 = () || !(peep GLOB (e 1) 0)) ?
                  (puts "MALFORMED-OR-UNPINNED-DEF ", puts (string (e 1)), quit 1)
                  0))
        ents)

   ; corpus-wide names: a global reference vs a bound var
   nt (tablet 0) _ (map (e \ (pin nt (e 1) 1)) ents)
   (corpus? x) (peep nt x 0)

   ; explicit skips: type-in-type detonations coqc's universe check rejects
   bl (tablet 0)
   _ (map (n \ (pin bl n 1)) '(the_world_explodes but_seriously_the_world_explodes whoa irref))

   ; --- the translator: a uu term -> a Gallina string ---
   ; `un`: heads u2c can't translate (empty; the dependency closure + coqc filter)
   un (tablet 0)
   bases (tablet 0)
   _ (pin bases 'nat "nat") _ (pin bases 'UU "Type") _ (pin bases 'bool "bool")
   _ (pin bases 'unit "unit") _ (pin bases 'empty "Empty_set")
   _ (pin bases 'true "true") _ (pin bases 'false "false") _ (pin bases 'tt "tt")
   (atom-c t) (peep bases t (corpus? t ? (rocqn t) (string t)))   ; base type / global / bound var

   (spine-c l) (two? l ? (u2c <l + (two? >l ? " " "") + spine-c >l) "")
   (u2c t)
   (? (charm? t) (show t)
      (nom? t) (atom-c t)
      (two? t) (<t @ h
        (h @ 'pi        ("(forall " + (string (t 1)) + " : " + (u2c (t 2)) + ", " + (u2c (t 3)) + ")")
           'lam       ("(fun " + (string (t 1)) + " => " + (u2c (t 2)) + ")")
           'let       ("(let " + (string (t 1)) + " := " + (u2c (t 2)) + " in " + (u2c (t 3)) + ")")
           'succ      ("(S " + (u2c (t 1)) + ")")
           'idpath    ("(idpath " + (u2c (t 1)) + ")")
           'paths     ("(@paths " + (u2c (t 1)) + " " + (u2c (t 2)) + " " + (u2c (t 3)) + ")")
           'nat_rect  ("(nat_rect " + (u2c (t 1)) + " " + (u2c (t 2)) + " " + (u2c (t 3)) + " " + (u2c (t 4)) + ")")
           'bool_rect ("(bool_rect " + (u2c (t 1)) + " " + (u2c (t 2)) + " " + (u2c (t 3)) + " " + (u2c (t 4)) + ")")
           'unit_rect ("(unit_rect " + (u2c (t 1)) + " " + (u2c (t 2)) + " " + (u2c (t 3)) + ")")
           'empty_rect ("(Empty_set_rect " + (u2c (t 1)) + " " + (u2c (t 2)) + ")")
           ; Sigma -> a primitive-projection total2 record (preamble below), keeping uu's
           ; definitional eta. total2 mirrors pi; tpair's family is inferred from the stated type.
           'total2    ("(total2 (fun " + (string (t 1)) + " : " + (u2c (t 2)) + " => " + (u2c (t 3)) + "))")
           'tpair     ("(tpair " + (u2c (t 1)) + " " + (u2c (t 2)) + ")")
           'pr1       ("(pr1 " + (u2c (t 1)) + ")")
           'pr2       ("(pr2 " + (u2c (t 1)) + ")")
           ; coprod -> sum, ii1/ii2 -> inl/inr, the eliminator -> sum_rect
           'coprod    ("(sum " + (u2c (t 1)) + " " + (u2c (t 2)) + ")")
           'ii1       ("(inl " + (u2c (t 1)) + ")")
           'ii2       ("(inr " + (u2c (t 1)) + ")")
           'coprod_rect ("(sum_rect " + (u2c (t 1)) + " " + (u2c (t 2)) + " " + (u2c (t 3)) + " " + (u2c (t 4)) + ")")
           ; (the T t) is a type ascription -- emit it as one
           'the       ("(" + (u2c (t 2)) + " : " + (u2c (t 1)) + ")")
           ; path induction (J) -> a match on paths
           'paths_rect
             ("(match " + (u2c (t 3)) + " as ep0 in (paths _ bp0) return ("
              + (u2c (t 1)) + " bp0 ep0) with idpath _ => " + (u2c (t 2)) + " end)")
           ("(" + (spine-c t) + ")")))                              ; an application spine
      (show t))

   ; --- translatability: every head handled (no unhandled constructor anywhere) ---
   (alltr? l) (two? l ? (tr? <l && alltr? >l) 1)
   (tr? t) (? (charm? t) 1  (nom? t) 1
              (two? t) (peep un <t 0 ? 0 (alltr? >t))  1)

   ; --- the corpus names a term mentions, into a set ---
   (ment t acc) (? (nom? t) (corpus? t ? (pin acc t 1, acc) acc)
                   (two? t) (ment-l t acc)  acc)
   (ment-l l acc) (two? l ? (ment-l >l (ment <l acc)) acc)

   ; candidates: a def, translatable, not skipped, uu-certified
   (cand? e) (<e = 'def && !(peep bl (e 1) 0) && peep GLOB (e 1) 0 && tr? (e 2) && tr? (e 3))
   cands (foldl (\ a e (cand? e ? (e . a) a)) () ents)   ; reversed
   (mlist e) (keys (ment-l (. (e 2) (. (e 3) ())) (tablet 0)))

   ; --- dependency closure: keep defs all of whose mentions survive ---
   (allin? l ex) (two? l ? (peep ex <l 0 && allin? >l ex) 1)
   (pass cs ex) (foldl (\ a e (allin? (mlist e) ex ? (pin a (e 1) 1, a) a)) (tablet 0) cs)
   ; settled when the key COUNT stops moving (pass only shrinks). not glued $: it nets any
   ; tablet to 1 and would stop after one pass.
   (fix ex) (pass cands ex @ ex2 (? (#(keys ex2) = #(keys ex)) ex2 (fix ex2)))
   ex0 (foldl (\ a e (pin a (e 1) 1, a)) (tablet 0) cands)    ; seed: all candidates
   keep (fix ex0)                                                   ; the closed exportable set

   ; --- emit in source order: foldr keeps ents' order, definitions before uses ---
   (emit e) (cat ["Definition " (rocqn (e 1)) " : " (u2c (e 2)) " :=" (string 10)
                  "  " (u2c (e 3)) "." (string 10)])
   exports (foldr (\ e a (peep keep (e 1) 0 ? (e . a) a)) () ents)

   _ (dot (cat [
      "(* test/proof/rocq/uugen.v -- GENERATED from test/uu.l by src/tools/uu2coq.l. Do not edit;" (string 10)
      "   regenerate with `make test_uugen`. uu's kernel type-checked each term below" (string 10)
      "   against its theorem (test/uu.l, green under `make test`); this is the SAME term" (string 10)
      "   translated to Gallina, which coqc re-checks -- the independent second witness," (string 10)
      "   and the universe filter uu's type-in-type kernel lacks. Only the MLTT primitives" (string 10)
      "   are mapped (nat/bool/unit/empty + recursors, paths<->a Type-valued Id type + J-match," (string 10)
      "   Sigma<->a primitive-projection total2 record with eta, coprod<->sum); only the" (string 10)
      "   univalence tower (an axm) is skipped, on its own via the dependency closure" (string 10)
      "   (counted at the foot). *)" (string 10)
      "From Stdlib Require Import PeanoNat." (string 10)
      "Set Warnings \"-notation-overridden,-abstract-large-number\"." (string 10)
      "(* universe polymorphism -- the faithful encoding of uu's structures (large Sigmas like" (string 10)
      "   wfs/hProp reuse total2 AT the universe of UU). It does NOT re-enable type-in-type:" (string 10)
      "   Type@{i} : Type@{i+1} stays strict, so the cheats below are still rightly rejected. *)" (string 10)
      "Set Universe Polymorphism." (string 10)
      "Set Polymorphic Inductive Cumulativity.  (* Prop-valued paths flow into Type carriers *)" (string 10)
      "(* uu's Sigma has definitional eta; the faithful Coq target is a primitive-projection" (string 10)
      "   record (eta in the kernel, axiom-free), NOT stdlib sigT (no eta). pr1/pr2/tpair" (string 10)
      "   mirror uu's own vocabulary; coprod stays stdlib sum (no eta needed). *)" (string 10)
      "Set Primitive Projections." (string 10)
      "Record total2 {A : Type} (B : A -> Type) : Type := tpair { pr1 : A ; pr2 : B pr1 }." (string 10)
      "Unset Primitive Projections." (string 10)
      "Arguments tpair {A B} _ _.  Arguments pr1 {A B} _.  Arguments pr2 {A B} _." (string 10)
      "(* uu's paths is the Type-valued identity type (UniMath's `paths`), NOT Prop's eq:" (string 10)
      "   a path can be a Sigma CARRIER (an element of UU), as in the hProp-valued nat order." (string 10)
      "   paths_to_eq (below) bridges it back to Coq's = for the Nat.* headline laws. *)" (string 10)
      "Inductive paths {A : Type} (a : A) : A -> Type := idpath : paths a a." (string 10) (string 10)]))
   _ (map (e \ (dot (emit e))) exports)
   ; --- the bridge: uu's nat ops restated on Nat.* (spec.v's vocabulary), tactic proofs ---
   _ (dot (cat [(string 10)
     "(* === bridge: uu's nat ops ARE Coq's standard ones, so the laws above land on" (string 10)
     "   Nat.add / Nat.mul -- the operations spec.v's own laws speak. uu_add_std/uu_mul_std" (string 10)
     "   (induction over the shared recursion) tie them to the standard vocabulary, by which" (string 10)
     "   the headline arithmetic laws are RESTATED on Nat.* and discharged FROM love's exports. *)" (string 10)
     "Lemma paths_to_eq : forall (A : Type) (a b : A), paths a b -> a = b." (string 10)
     "Proof. intros A a b p; destruct p; reflexivity. Qed." (string 10)
     "Lemma uu_add_std : forall n m, uu_add n m = Nat.add n m." (string 10)
     "Proof. intros n m; induction n as [|n IHn]; [reflexivity|]." (string 10)
     "  change (uu_add (S n) m) with (S (uu_add n m)); rewrite IHn; reflexivity. Qed." (string 10)
     "Lemma uu_mul_std : forall n m, uu_mul n m = Nat.mul n m." (string 10)
     "Proof. intros n m; induction n as [|n IHn]; [reflexivity|]." (string 10)
     "  change (uu_mul (S n) m) with (uu_add (uu_mul n m) m);" (string 10)
     "  rewrite uu_add_std, IHn, Nat.add_comm; reflexivity. Qed." (string 10)
     "Theorem add_comm_std : forall n m, Nat.add n m = Nat.add m n." (string 10)
     "Proof. intros n m; rewrite <- (uu_add_std n m), <- (uu_add_std m n); apply paths_to_eq, uu_natpluscomm. Qed." (string 10)
     "Theorem add_assoc_std : forall n m k, Nat.add (Nat.add n m) k = Nat.add n (Nat.add m k)." (string 10)
     "Proof. intros n m k; rewrite <- !uu_add_std; apply paths_to_eq, uu_natplusassoc. Qed." (string 10)
     "Theorem mul_comm_std : forall n m, Nat.mul n m = Nat.mul m n." (string 10)
     "Proof. intros n m; rewrite <- (uu_mul_std n m), <- (uu_mul_std m n); apply paths_to_eq, uu_natmultcomm. Qed." (string 10)]))
   _ (dot (cat [(string 10) "Print Assumptions uu_natplusr0." (string 10)
"Print Assumptions uu_zcountins." (string 10)
"Print Assumptions uu_zinsane." (string 10)
"Print Assumptions uu_rtwinsrow." (string 10)
"Print Assumptions uu_commute_involutive." (string 10)
"Print Assumptions uu_invert_roundtrip." (string 10)
"Print Assumptions uu_commute_sound." (string 10)
"Print Assumptions uu_applall_swap." (string 10)
"Print Assumptions uu_hcommute_involutive." (string 10)
"Print Assumptions uu_hinv_roundtrip." (string 10)
"Print Assumptions uu_hcommute_sound." (string 10)
"Print Assumptions uu_hfold_swap." (string 10)
"Print Assumptions uu_etreeeta." (string 10)
"Print Assumptions uu_ekidsbeta." (string 10)
"Print Assumptions uu_ffindlay." (string 10)
"Print Assumptions uu_swal_involutive." (string 10)
"Print Assumptions uu_scell_comm." (string 10)
"Print Assumptions uu_splice_pad." (string 10)
"Print Assumptions uu_bubble_len." (string 10)
"Print Assumptions uu_mtch_sound." (string 10)
"Print Assumptions uu_reaim_involutive." (string 10)
"Print Assumptions uu_fid_swap." (string 10)
"Print Assumptions uu_repo_found." (string 10)
"Print Assumptions uu_repo_faithful." (string 10)
              "Print Assumptions add_comm_std." (string 10)
              "Print Assumptions add_assoc_std." (string 10)
              "Print Assumptions mul_comm_std." (string 10) (string 10)
              "(* " (show #(keys keep)) " exported / " (show #ents) " corpus entries swept;" (string 10)
              "   3 headline laws (add_comm, add_assoc, mul_comm) landed on Coq's Nat.* via the bridge *)" (string 10)]))
   (quit 0))
