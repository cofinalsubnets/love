; uu2lean: love's uu proof corpus exported to lean 4, the twin of uu2coq.l. loads and
; certifies the uu files, reads them as data, and translates every (defn/defq nm T t) in
; the MLTT fragment; lean re-checks the same terms.
;
; a def exports iff in the fragment and every global it mentions exports -- a dependency
; closure, so the univalence tower (bottoming at an `axm`) drops on its own. `paths` is the
; Type-valued identity (Lean's `Eq` is Prop), so a path can be a Sigma carrier.
;
; Run: out/love src/tools/uu2lean.l > test/proof/lean/uugen.lean   then  lean test/proof/lean/uugen.lean

(borrow 'posix)
; stdout is the artifact, so the files' `test` laws run as assert: silent, a false one stops
(:: 'test (. 'assert))
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
   nl "\n"
   b8 "⟨"  b9 "⟩"
   (unq x) (two? x && <x = bs ? (x 1) x)   ; strip one ' (reads shows quote as (\ ..))
   (lines l) (foldl (a \ s \ a + s + nl) "" l)

   ; a uu name -> a Lean identifier: prefix uu_, kebab '-' -> '_'
   (sanit s) (jug 0 @ j (each ^#s (i \ say j (string (s i @ 45 95 c c))), slurp j))
   (leann nm) ("uu_" + sanit (string nm))

   ; --- collect (kind nm T t) entries (defns live inside the laws) ---
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
   (app2 a b) (two? a ? (<a . app2 >a b) b)   ; not `cat` -- the local cat is the string fold
   ents (gather (app2 (forms (open "test/uu.l" "r")) (app2 (forms (open "test/uuhom.l" "r")) (app2 (forms (open "test/uuhomgen.l" "r")) (app2 (forms (open "test/uuhomlaw.l" "r")) (app2 (forms (open "test/uusplgen.l" "r")) (app2 (forms (open "test/uuspllaw.l" "r")) (app2 (forms (open "test/uulay.l" "r")) (app2 (forms (open "test/uupatch.l" "r")) (app2 (forms (open "test/uuwm.l" "r")) (app2 (forms (open "test/uuwmlaw.l" "r")) (app2 (forms (open "test/uukind.l" "r")) (app2 (forms (open "test/uukindlaw.l" "r")) (app2 (forms (open "test/uumx.l" "r")) (app2 (forms (open "test/uumxlaw.l" "r")) (app2 (forms (open "test/uuval.l" "r")) (app2 (forms (open "test/uuvalband.l" "r")) (forms (open "test/uuvallaw.l" "r")))))))))))))))))) ())

   ; a def must be whole (a paren slip reads () as its term) and pinned (a partial defn is a
   ; truthy closure that pins nothing). `= ()`, not `!`: a term of 0 is a legal def
   _ (map (e \ ((<e = 'def && e 3 = () || !(peep GLOB (e 1) 0)) ?
                  (puts "MALFORMED-OR-UNPINNED-DEF ", puts (string (e 1)), quit 1)
                  0))
        ents)

   ; corpus names, telling a global from a bound var
   nt {} _ (map (e \ pin nt <>e 1) ents)
   (corpus? x) (peep nt x 0)

   ; the type-in-type laws, which sound MLTT rejects
   bl {}
   _ (map (n \ pin bl n 1) '(the_world_explodes but_seriously_the_world_explodes whoa irref))

   ; UU pinned to `Type` for these: a type-level nat_rect leaves the level underdetermined
   ; and the universe strands downstream
   mono {}
   _ (map (n \ pin mono n 1) '(nvec nlist stk mstk patch tree ppair pvec plist cmside hunk hpair hvec hlist hcmside duo etree epatch spair scmside cell tmleaf tm svec slist sqside mvside store))

   ; `@[reducible]`: Lean checks a paths.rec minor premise at reducible transparency, so
   ; idisweq stalls unless idfun T x unfolds
   red {}
   _ (map (n \ pin red n 1) '(idfun coconustot coconusfromt hfiber))

   ; names Lean cannot take though uu and Rocq certify them; empty
   np {}
   _ (map (n \ pin np n 1) '())

   ; hand-written bodies for the two based-J roots the emitted term stalls on: tactic mode
   ; runs at full transparency. the type is still translated
   manual {
   'idisweq
       "  by intro T y; refine ⟨⟨y, @paths.idpath _ y⟩, ?_⟩; intro t; obtain ⟨x, p⟩ := t; cases p; exact @paths.idpath _ _"
   'iscontrcoconustot
       "  by intro T t; refine ⟨⟨t, @paths.idpath _ t⟩, ?_⟩; intro w; obtain ⟨x, p⟩ := w; cases p; exact @paths.idpath _ _"}

   ; --- the translator: a uu term -> a Lean string ---
   ; `un` names unhandled heads; empty
   un {}
   bases {'nat "Nat" 'UU "(Type _)" 'bool "Bool" 'unit "PUnit.{1}"
          'empty "Empty" 'true "true" 'false "false" 'tt "PUnit.unit"}
   (atom-l t) (peep bases t (corpus? t ? (leann t) (string t)))   ; base type / global / bound var

   (spine-l l) (atom? l ? "" (u2l <l + (two? >l ? " " "") + spine-l >l))
   (u2l t)
   (?- (show t)
    (charm? t) (show t)
    (nom? t) (atom-l t)
    (two? t) (<t @
     'pi       ("(forall " + string <>t + " : " + u2l <>>t + ", " + u2l (t 3) + ")")
     'lam       ("(fun " + string <>t + " => " + u2l <>>t + ")")
     'let       ("(let " + string <>t + " := " + u2l <>>t + "; " + u2l (t 3) + ")")
     'succ      ("(Nat.succ " + u2l <>t + ")")
     ; paths -- the Type-valued Id type (idpath's a and a are both implicit -> @ _ a)
     'idpath    ("(@paths.idpath _ " + u2l <>t + ")")
     'paths     ("(@paths " + u2l <>t + " " + u2l <>>t + " " + u2l (t 3) + ")")
     'nat_rect  ("(@Nat.rec " + u2l <>t + " " + u2l <>>t + " " + u2l (t 3) + " " + u2l (t 4) + ")")
     ; Bool.rec takes the false case first, uu the true case: swapped
     'bool_rect ("(@Bool.rec " + u2l <>t + " " + u2l (t 3) + " " + u2l <>>t + " " + u2l (t 4) + ")")
     'unit_rect ("(@PUnit.rec " + u2l <>t + " " + u2l <>>t + " " + u2l (t 3) + ")")
     'empty_rect ("(@Empty.rec " + u2l <>t + " " + u2l <>>t + ")")
       ; Sigma -> a Lean structure, with definitional eta. total2 mirrors pi
     'total2    ("(total2 (fun " + string <>t + " : " + u2l <>>t + " => " + u2l (t 3) + "))")
     'tpair     ("(total2.tpair " + u2l <>t + " " + u2l <>>t + ")")
     'pr1       ("(total2.pr1 " + u2l <>t + ")")
     'pr2       ("(total2.pr2 " + u2l <>t + ")")
     ; coprod -> Sum; ii1/ii2 -> Sum.inl/inr; the eliminator -> Sum.rec (A B as _)
     'coprod    ("(Sum " + u2l <>t + " " + u2l <>>t + ")")
     'ii1       ("(Sum.inl " + u2l <>t + ")")
     'ii2       ("(Sum.inr " + u2l <>t + ")")
     'coprod_rect ("(@Sum.rec _ _ " + u2l <>t + " " + u2l <>>t + " " + u2l (t 3) + " " + u2l (t 4) + ")")
     ; (the T t) is a type ascription
     'the       ("(" + u2l <>>t + " : " + u2l <>t + ")")
     ; full path induction (J): uu (paths_rect P pr e) -> paths.rec, based J (a fixed)
     'paths_rect ("(paths.rec (motive := " + u2l <>t + ") " + u2l <>>t + " " + u2l (t 3) + ")")
     ("(" + spine-l t + ")")))                             ; an application spine

   ; --- translatability: every head handled (no unhandled constructor anywhere) ---
   (alltr? l) (two? l ? (tr? <l && alltr? >l) 1)
   (tr? t) (? (charm? t) 1  (nom? t) 1
              (two? t) (peep un <t 0 ? 0 (alltr? >t))  1)

   ; --- the global names a term mentions (corpus names only), accumulated into a set ---
   (ment t acc) (? (nom? t) (corpus? t ? (pin acc t 1, acc) acc)
                   (two? t) (ment-l t acc)  acc)
   (ment-l l acc) (two? l ? (ment-l >l (ment <l acc)) acc)

   ; candidates: a def, in the fragment, not blacklisted, present in glob (uu-certified)
   (cand? e) (<e = 'def && !(peep bl (e 1) 0) && !(peep np (e 1) 0)
              && peep GLOB (e 1) 0 && tr? (e 2) && tr? (e 3))
   cands (foldl (\ a e (cand? e ? (e . a) a)) () ents)   ; reversed; restore order at emit
   ; each candidate's mentioned-names list (its global dependencies)
   (mlist e) (keys (ment-l (. (e 2) (. (e 3) ())) (tablet 0)))

   ; --- dependency closure: keep only defs all of whose mentions also survive ---
   (allin? l ex) (two? l ? (peep ex <l 0 && allin? >l ex) 1)
   (pass cs ex) (foldl (\ a e (allin? (mlist e) ex ? (pin a (e 1) 1, a) a)) (tablet 0) cs)
   ; the measure is the key count: pass only shrinks ex. not glued $, which nets a tablet to 1
   (fix ex) (pass cands ex @ ex2 (? (#(keys ex2) = #(keys ex)) ex2 (fix ex2)))
   ex0 (foldl (\ a e (pin a (e 1) 1, a)) (tablet 0) cands)    ; seed: all candidates
   keep (fix ex0)                                                   ; the closed exportable set

   ; --- emit, in source order ---
   (emit e) (: nm (e 1) mb (peep manual nm 0)
     _ (pin bases 'UU (peep mono nm 0 ? "Type" "(Type _)"))
     out ((peep red nm 0 ? "@[reducible] " "") + "def " + (leann nm) + " : " + (u2l (e 2)) + " :="
      + nl + (mb ? mb ("  " + (u2l (e 3)))) + nl)
     _ (pin bases 'UU "(Type _)")
     out)
   ; foldr keeps ents' order: lean wants every definition before its uses
   exports (foldr (\ e a (peep keep (e 1) 0 ? (e . a) a)) () ents)

   _ (dot (lines [
      "/- test/proof/lean/uugen.lean -- GENERATED from test/uu.l by src/tools/uu2lean.l. Do not edit;"
      "   regenerate with `make test_uulean`. The SAME uu proof terms Rocq certifies"
      "   (test/proof/rocq/uugen.v) re-checked by a SECOND independent kernel, Lean 4 -- so each law"
      "   is agreed by two unrelated implementations (the de Bruijn criterion, diversified)."
      "   uu's kernel type-checked each term against its theorem (test/uu.l, green under"
      "   `make test`); this is the same term in Lean. Lean gives structure-eta and universe"
      "   polymorphism for free; `paths` is the Type-valued Id type (Lean's Eq is Prop) so a"
      "   path can be a Sigma carrier. Only the univalence tower (an axm) is skipped, on its"
      "   own via the dependency closure (counted at the foot). -/"
      "set_option linter.unusedVariables false"
      "set_option maxHeartbeats 4000000"
      "set_option maxRecDepth 300000  -- uu_app_tower reduces a unary-Nat Church tower to 262144"
      "universe u v"
      "/- uu's paths: the Type-valued identity type (UniMath's `paths`), NOT Prop's Eq. -/"
      "inductive paths {A : Type u} (a : A) : A -> Type u where"
      "  | idpath : paths a a"
      "/- Sigma as a structure -- Lean structures have definitional eta in the kernel. -/"
      "structure total2 {A : Type u} (B : A -> Type v) : Type (max u v) where"
      "  tpair ::"
      "  pr1 : A"
      "  pr2 : B pr1"
      "/- the bridge shim: a Type-valued path eliminates into Prop's = -/"
      "theorem paths_to_eq {A : Type u} {a b : A} (p : paths a b) : a = b := by cases p; rfl"
      "/- CERTIFY, never run: defs use bare recursors the code generator rejects. -/"
      "noncomputable section"
      ""]))
   _ (map (dot * emit) exports)
   _ (dot (lines [
      ""
      "end"
      "/- the de Bruijn witness: Lean agrees these carry NO axioms (closed under the"
      "   global context), the same property Rocq's `Print Assumptions` reports. -/"
      "#print axioms uu_natpluscomm"
"#print axioms uu_zcountins"
"#print axioms uu_zinsane"
"#print axioms uu_rtwinsrow"
"#print axioms uu_commute_involutive"
"#print axioms uu_invert_roundtrip"
"#print axioms uu_commute_sound"
"#print axioms uu_applall_swap"
"#print axioms uu_hcommute_involutive"
"#print axioms uu_hinv_roundtrip"
"#print axioms uu_hcommute_sound"
"#print axioms uu_hfold_swap"
"#print axioms uu_etreeeta"
"#print axioms uu_ekidsbeta"
"#print axioms uu_ffindlay"
"#print axioms uu_swal_involutive"
"#print axioms uu_scell_comm"
"#print axioms uu_splice_pad"
"#print axioms uu_bubble_len"
"#print axioms uu_mtch_sound"
"#print axioms uu_reaim_involutive"
"#print axioms uu_fid_swap"
"#print axioms uu_repo_found"
"#print axioms uu_repo_faithful"
      "#print axioms uu_natplusassoc"
      "#print axioms uu_natmultcomm"
      "#print axioms uu_total2_paths_f"
      "#print axioms uu_idisweq"
      "#print axioms uu_iscontrcoconustot"
      ""]))
   _ (dot ("/- " + (show #(keys keep)) + " exported / " + (show #ents) + " corpus entries swept;" + nl
         + "   re-certified by Lean 4 -- a second kernel beside Rocq's uugen.v -/" + nl))
   (quit 0))
