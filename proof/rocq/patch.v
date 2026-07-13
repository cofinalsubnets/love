(* proof/patch.v -- the PATCH GROUPOID, the first slice machine-checked in Rocq.

   The design lives in doc/proto/patch.l (the runnable toy + the argument that a
   distribution, a namespace, and a repo state are ONE algebra of selectable sets,
   with COMMUTE the primitive underneath). That toy DEMONSTRATES the laws at
   runtime; this file upgrades demonstrate toward PROVE -- the commute laws as
   theorems in a consistent metatheory.

   Scope: the NAMED-SLOT model -- a tree is a total map (key -> value), a patch is
   a single slot-change carrying its context (old -> new). This is darcs's "file
   of named lines" abstraction, where commutation is the CLEAN case (independent
   patches touch different slots and do not shift). Proven here, axiom-free:
     (L1) commute is involutive           commute_involutive
     (L2) inverse round-trips (in ctx)    invert_roundtrip
     (L3a) independent patches are        commute_sound  (the semantic heart:
           order-free                       reordering independent patches
                                            preserves the tree -- what MAKES
                                            merge/cherry-pick sound)
     (L3b) a FRONTIER is stable under      aponl_swap    (a whole patch list is
           reordering independent patches   invariant under an adjacent swap of
                                            independent patches -- the
                                            reproducibility tie: a frontier's
                                            MEANING does not depend on pull order,
                                            so its content-hash is a sound identity)

   The SECOND slice (the positional rung, opened 2026-07-12) is proven below the
   named-slot section: HUNKS over a sequence, where a commuted q' is a genuine
   re-aim -- its index slides by the other hunk's length delta -- and touching
   hunks refuse to commute (strict: a seam has no canonical order once inserts
   land on it; adjacency would break L1). Same four laws, same axiom-free rule:
     (L1) hcommute_involutive   (L3a) hcommute_sound (under the honest contexts
     (L2) hinv_roundtrip              -- validity pins the seams; nothing shifted
     (L3b) hfold_swap                 in the named model, so it needed none)
   Sequences are lists, so equality here is PLAIN list equality -- the pointwise
   discipline below is only for the tree (function) model.

   The THIRD slice (the conflictor rung, same day) closes commute's refusal
   gap: a real merge RECORDS instead of refusing. The state enlarges (pijul's
   move, not darcs 1.x's exotic patch algebra) -- a conflicted slot holds a
   CLASH, the shared base plus a canonically-ordered rival set -- and merge
   (pull, factoring through merge1) is total. Its laws, same axiom-free rule:
     (M1) pull_merge_comm   rivals land the same cell either order, from ANY
                            starting slot (so three-way convergence is M1 twice)
     (M2) pull_idem         pulling a patch again settles
     (M3) pull_records      the cell keeps the base AND both rivals
     (M4) pull_fold_swap    a frontier is stable under ANY adjacent swap --
                            independent OR conflicting: pull order is dead
     (M5) resolve_roundtrip a resolution is an ordinary patch off the cell,
                            and unpulling it returns the clash
   The FOURTH slice (the identity rung, same day): a version IS its patch set.
   Per-patch content hashes fold through cins -- the same canonical set that
   carries a clash's rivals -- so the identity quotients by exactly what the
   semantics proved dead and nothing more:
     (H1) fid_swap  order-free   (the aponl_swap / pull_fold_swap face)
     (H2) fid_dup   multiplicity-free  (the pull_idem face)
   The FIFTH slice (the tree lift, 2026-07-13): a hunk gets a PATH, and the
   shift algebra climbs the levels -- four commute lanes by path relation,
   with a genuine PATH re-aim at the crossing:
     (L1) tcommute_involutive  (the algebra half; the tree APPLY laws are
          asserted in the .l -- their crossing-level core IS splice_after/
          before_comm with singleton hunks -- and join the uu-term rung)
   The SIXTH slice (the content-rewrite rung, same day): the swallow refusal
   opens -- a shallow patch that MOVES the subtree a deep patch edited
   commutes by rewriting its context THROUGH the content (undo the deep edit
   in both sides, re-aim at the survivor's seat, occurrence guards keeping
   the match canonical). Proven at ELEMENT grain (the deep edit as "at seat
   j, a becomes b"; the rose-tree unit walk stays in the .l):
     (L1) swal_involutive  (through the groupoid inverse -- exactly the .l's
          mirror lane wiring, so involution is the algebra, not a re-check)
   The SEVENTH slice (the clash-segments rung, same day): the conflictor
   cell lifted to sequences -- pijul's graggle corner. Overlapping / touching
   / same-seam rivals collapse the union hull of their base spans to ONE
   clash element, the BUBBLE; rivals are segments, cins-canonical by content
   hash; a rival extending past a landed bubble WIDENS it over the union
   hull (the same day's second half). Proven at hash grain:
     (M1) scell_comm   the bubble forgets arrival order (min/max + cins_comm)
     (--)  splice_pad  padding commutes with rendering -- a rival padded up
           when the bubble widens IS the rival rendered over the wide hull,
           so mixed-span arrival order is dead too
     (--)  bubble_len  one seat, rival sizes nowhere in the merged length --
           downstream seats determinate before anyone resolves
   The EIGHTH slice (the metavariable rung, same day): patches grow
   variables and become rewrite RULES -- the unifier takes the application
   seat (valid matches, apon instantiates), and the schematic swallow
   commutes with the rule UNCHANGED: the variable abstracts the content, so
   form six's rewrite-through vanishes into address algebra. Proven in the
   lane's two halves:
     (--)  mtch_sound        matching is SOUND: a pattern instantiated with
           its own bindings reproduces the ground term (non-linear patterns
           bind consistently -- the kanren move, on cap/cup cells)
     (L1)  reaim_involutive  the deep patch's seat re-aim (olds seat -> news
           seat, prefix surgery) swaps home
   Still deliberately out (the next rung): schematic-vs-schematic commute --
   two overlapping REWRITE RULES are critical-pair confluence territory, a
   different theorem set.

   Method note, matching gc.v / spec.v house rule: NO Axiom, NO Admitted, NO
   classical / funext escape hatch. Trees are functions, so equality of trees is
   POINTWISE (forall k, ...) throughout -- we never assume functional
   extensionality; every theorem quantifies the key.

   PROVENANCE -- this file is SCAFFOLDING, not the destination. It is hand-authored
   (spec.v tier), and a hand-authored proof model DRIFTS from the code it mirrors
   -- the lesson wm2uu already banked when it retired the hand StackSet model for a
   generated-and-gated one. The house pattern is: the ai implementation is the
   source of truth; the Rocq/Lean is EMITTED and drift-gated. Two rungs get us
   there. (1) An executable ai spec (test/patch.l) states the model + laws as
   asserts, green under `make test` -- the drift anchor. (2) The laws are
   universally quantified structural theorems, so tools/spec2coq.l (which only
   discharges CLOSED computations by vm_compute) can witness ground INSTANCES but
   cannot prove the forall; the real generator is the uu route -- encode L1..L3b as
   uu proof TERMS and let tools/uu2coq.l + tools/uu2lean.l emit them into BOTH
   kernels (as uugen.v / uugen.lean already do for ~200 laws). The named-slot model
   FITS uu's MLTT: pointwise equality (no funext), decidable Nat.eqb case-splits (no
   classical), list induction for the frontier. When that lands, this .v is
   DELETED. Until then it pins the theorem statements and proves the slice is real.

   Written by Claude (Anthropic), the Opus 4.8 model; the positional slice by
   Claude Fable 5. *)

From Stdlib Require Import PeanoNat List Lia.
Import ListNotations.

(* ============================================================ *)
(* the model: a named-slot tree and a context-carrying patch    *)
(* ============================================================ *)

(* A tree is a total map key -> value; both are nat. A missing slot is not a
   special case here -- a total map is the mathematical closure of the .l's
   "missing slot reads 0". *)
Definition tree := nat -> nat.

(* A patch touches one slot, carrying its context: it changes pk from pa to pb.
   The context (pa) is what makes a patch BELONG somewhere -- not a bare diff. *)
Record patch := mk { pk : nat ; pa : nat ; pb : nat }.

(* apon: lay a patch's new value at its slot (the .l's apon). *)
Definition apon (t : tree) (p : patch) : tree :=
  fun k => if Nat.eqb k (pk p) then pb p else t k.

(* valid: a patch belongs on t iff its context matches the current value. *)
Definition valid (t : tree) (p : patch) : bool := Nat.eqb (t (pk p)) (pa p).

(* invert: every patch has an inverse -- unpull is apply-the-inverse. *)
Definition invert (p : patch) : patch := mk (pk p) (pb p) (pa p).

(* commute: the ONE primitive. p;q -> q;p (partial: None when they collide on a
   slot -- a dependency). In this named model the swapped pair is (q,p) unchanged;
   the structural slice is where q' becomes a real re-aim. *)
Definition commute (p q : patch) : option (patch * patch) :=
  if Nat.eqb (pk p) (pk q) then None else Some (q, p).

(* aponl: fold a whole frontier (patch list) onto a tree. *)
Definition aponl (t : tree) (ps : list patch) : tree := fold_left apon ps t.

(* ============================================================ *)
(* (L1) commute is involutive                                   *)
(* ============================================================ *)

(* commute p q = (q',p')  =>  commute q' p' = (p,q). Reordering back is the same
   op -- the groupoid's swap is self-inverse. *)
Theorem commute_involutive : forall p q q' p',
  commute p q = Some (q', p') -> commute q' p' = Some (p, q).
Proof.
  intros p q q' p' H. unfold commute in *.
  destruct (Nat.eqb (pk p) (pk q)) eqn:E; [discriminate|].
  injection H as Hq Hp; subst q' p'.
  destruct (Nat.eqb (pk q) (pk p)) eqn:E2; [|reflexivity].
  apply Nat.eqb_eq in E2. apply Nat.eqb_neq in E. congruence.
Qed.

(* ============================================================ *)
(* (L2) inverse round-trips, in context                         *)
(* ============================================================ *)

(* If p belongs on t (valid), then applying p and then its inverse restores t
   -- pointwise. This is the groupoid inverse law, the honest (context-checked)
   version: without validity the old value is not recoverable. *)
Theorem invert_roundtrip : forall t p, valid t p = true ->
  forall k, apon (apon t p) (invert p) k = t k.
Proof.
  intros t p Hv k. unfold valid in Hv. apply Nat.eqb_eq in Hv.
  unfold apon, invert. simpl.
  destruct (Nat.eqb k (pk p)) eqn:E.
  - apply Nat.eqb_eq in E. subst k. symmetry. exact Hv.
  - reflexivity.
Qed.

(* ============================================================ *)
(* (L3a) independent patches are order-free -- the semantic core *)
(* ============================================================ *)

(* The raw form: distinct slots => the two application orders agree pointwise. *)
Lemma apon_comm : forall p q, pk p <> pk q ->
  forall t k, apon (apon t p) q k = apon (apon t q) p k.
Proof.
  intros p q H t k. unfold apon.
  destruct (Nat.eqb k (pk q)) eqn:Eq; destruct (Nat.eqb k (pk p)) eqn:Ep;
    try reflexivity.
  apply Nat.eqb_eq in Eq; apply Nat.eqb_eq in Ep; congruence.
Qed.

(* Tied to commute: a successful commute WITNESSES order-freedom. This is the law
   that makes merge and cherry-pick sound -- pulling p then q, or q then p, lands
   the same tree exactly when they commute. *)
Theorem commute_sound : forall p q,
  commute p q = Some (q, p) ->
  forall t k, apon (apon t p) q k = apon (apon t q) p k.
Proof.
  intros p q Hc. apply apon_comm. unfold commute in Hc.
  destruct (Nat.eqb (pk p) (pk q)) eqn:E; [discriminate|].
  apply Nat.eqb_neq in E. exact E.
Qed.

(* ============================================================ *)
(* (L3b) a frontier is stable under reordering independent patches *)
(* ============================================================ *)

(* Pointwise congruence for a single apon, then for a whole fold: applying the
   same patch list to pointwise-equal trees keeps them pointwise-equal. This is
   the lift that carries a local swap through the rest of the frontier. *)
Lemma apon_ext : forall t1 t2 p, (forall k, t1 k = t2 k) ->
  forall k, apon t1 p k = apon t2 p k.
Proof.
  intros t1 t2 p H k. unfold apon. destruct (Nat.eqb k (pk p)); auto.
Qed.

Lemma fold_apon_ext : forall ps t1 t2, (forall k, t1 k = t2 k) ->
  forall k, fold_left apon ps t1 k = fold_left apon ps t2 k.
Proof.
  induction ps as [|p ps IH]; intros t1 t2 H k; simpl.
  - apply H.
  - apply IH. intro k'. apply apon_ext. exact H.
Qed.

(* THE frontier theorem: a patch list is invariant (pointwise) under swapping any
   two adjacent INDEPENDENT patches. By induction on the general Permutation this
   lifts to "any reordering of a pairwise-independent frontier yields the same
   tree" -- the standard bubble-sort argument, the next slice. What that buys the
   distribution: a frontier's MEANING is order-free, so identifying a version by
   the (unordered) content-hash of its patch set is SOUND -- the reproducibility
   claim, resting here rather than on trust. *)
Theorem aponl_swap : forall pre p q post t,
  pk p <> pk q ->
  forall k, aponl t (pre ++ p :: q :: post) k = aponl t (pre ++ q :: p :: post) k.
Proof.
  intros pre p q post t Hpq k. unfold aponl.
  rewrite !fold_left_app. cbn [fold_left].
  apply fold_apon_ext. intro k'. apply apon_comm. exact Hpq.
Qed.

(* ============================================================ *)
(* the POSITIONAL slice: hunks over a sequence -- commute RE-AIMS *)
(* ============================================================ *)

(* Mirror of test/patch.l's second form. A state is a SEQUENCE of forms (nat
   stands in for a form), a patch a HUNK: at index hpos the segment hold (its
   context -- a hunk BELONGS somewhere) becomes hnew. Named slots never shift;
   hunks DO: commuting past an unequal-length hunk moves the other's index by
   the length delta, so the swapped patch is a genuine re-aim. *)

Record hunk := mkh { hpos : nat ; hold : list nat ; hnew : list nat }.

(* splice: replace the c elements at i with n (firstn/skipn are total, so
   splice is too -- validity is what pins it to the honest region). *)
Definition splice (s : list nat) (i c : nat) (n : list nat) : list nat :=
  firstn i s ++ n ++ skipn (i + c) s.

Definition hap (s : list nat) (p : hunk) : list nat :=
  splice s (hpos p) (length (hold p)) (hnew p).

(* hvalid: the context matches AND the hunk is in range. The bound is what
   keeps L2 honest: an out-of-range insert still splices (at the end), but its
   inverse aims past the end -- the round-trip would lie without it. *)
Definition hvalid (s : list nat) (p : hunk) : Prop :=
  hpos p + length (hold p) <= length s /\
  firstn (length (hold p)) (skipn (hpos p) s) = hold p.

Definition hinv (p : hunk) : hunk := mkh (hpos p) (hnew p) (hold p).

(* hcommute: p;q -> q';p'. q strictly PAST p's news slides BACK by p's delta;
   q strictly BEFORE slides p FORWARD by q's delta. Overlap OR touch is None
   (STRICT: two inserts on one seam have no canonical order -- allowing
   adjacency breaks involutivity). The nat subtractions never truncate: each
   branch's guard supplies the needed slack. *)
Definition hcommute (p q : hunk) : option (hunk * hunk) :=
  if hpos p + length (hnew p) <? hpos q
  then Some (mkh (hpos q + length (hold p) - length (hnew p)) (hold q) (hnew q), p)
  else if hpos q + length (hold q) <? hpos p
  then Some (q, mkh (hpos p + length (hnew q) - length (hold q)) (hold p) (hnew p))
  else None.

(* ============================================================ *)
(* (L1) hcommute is involutive                                  *)
(* ============================================================ *)

Theorem hcommute_involutive : forall p q q' p',
  hcommute p q = Some (q', p') -> hcommute q' p' = Some (p, q).
Proof.
  intros [i o1 n1] [j o2 n2] q' p' H. unfold hcommute in *. simpl in *.
  destruct (i + length n1 <? j) eqn:E1.
  - (* q was strictly after: it slid back; the reverse takes the BEFORE branch *)
    injection H as <- <-. simpl. apply Nat.ltb_lt in E1.
    destruct (j + length o1 - length n1 + length n2 <? i) eqn:F1.
    + apply Nat.ltb_lt in F1. lia.
    + destruct (i + length o1 <? j + length o1 - length n1) eqn:F2.
      * replace (j + length o1 - length n1 + length n1 - length o1)
          with j by lia. reflexivity.
      * apply Nat.ltb_ge in F2. lia.
  - destruct (j + length o2 <? i) eqn:E2; [|discriminate].
    (* q was strictly before: p slid forward; the reverse takes the AFTER branch *)
    injection H as <- <-. simpl. apply Nat.ltb_lt in E2.
    destruct (j + length n2 <? i + length n2 - length o2) eqn:F1.
    + replace (i + length n2 - length o2 + length o2 - length n2)
        with i by lia. reflexivity.
    + apply Nat.ltb_ge in F1. lia.
Qed.

(* ============================================================ *)
(* splice algebra: the three little lemmas everything rides     *)
(* ============================================================ *)

Lemma firstn_len_app : forall (a b : list nat), firstn (length a) (a ++ b) = a.
Proof.
  intros. rewrite firstn_app, firstn_all, Nat.sub_diag. simpl. apply app_nil_r.
Qed.

Lemma skipn_len_app : forall (a b : list nat), skipn (length a) (a ++ b) = b.
Proof.
  intros. rewrite skipn_app, skipn_all, Nat.sub_diag. reflexivity.
Qed.

(* splice, aimed exactly at a decomposed middle: the ONE computation rule. *)
Lemma splice_at : forall (P o rest n : list nat) i c,
  i = length P -> c = length o ->
  splice (P ++ o ++ rest) i c n = P ++ n ++ rest.
Proof.
  intros P o rest n i c -> ->. unfold splice.
  rewrite firstn_len_app. f_equal. f_equal.
  rewrite skipn_app, skipn_all2 by lia.
  replace (length P + length o - length P) with (length o) by lia.
  apply skipn_len_app.
Qed.

(* every sequence splits at (i, c) -- unconditional; validity is what names
   the middle piece. *)
Lemma seg_decompose : forall (s : list nat) i c,
  s = firstn i s ++ firstn c (skipn i s) ++ skipn (i + c) s.
Proof.
  intros. rewrite (Nat.add_comm i c), <- skipn_skipn.
  rewrite firstn_skipn, firstn_skipn. reflexivity.
Qed.

(* ============================================================ *)
(* (L2) inverse round-trips, in context                         *)
(* ============================================================ *)

Theorem hinv_roundtrip : forall s p, hvalid s p -> hap (hap s p) (hinv p) = s.
Proof.
  intros s [i o n] [Hb Hc]. unfold hap, hinv; simpl in *.
  pose proof (seg_decompose s i (length o)) as Hs. rewrite Hc in Hs.
  assert (HA : length (firstn i s) = i) by (apply firstn_length_le; lia).
  rewrite Hs at 1.
  rewrite (splice_at _ _ _ _ _ _ (eq_sym HA) eq_refl).
  rewrite (splice_at _ _ _ _ _ _ (eq_sym HA) eq_refl).
  symmetry. exact Hs.
Qed.

(* ============================================================ *)
(* (L3a) hcommute is SOUND: the re-aimed order lands the same   *)
(* sequence -- the semantic heart, now with genuine shifting    *)
(* ============================================================ *)

(* The AFTER branch: q aims strictly past p's news, so on the way out it slides
   BACK by p's delta. Both orders decompose s into A ++ o1 ++ M ++ o2 ++ Z and
   land A ++ n1 ++ M ++ n2 ++ Z. *)
Lemma splice_after_comm : forall s i o1 n1 j o2 n2,
  i + length n1 < j ->
  i + length o1 <= length s ->
  firstn (length o1) (skipn i s) = o1 ->
  j + length o2 <= length (splice s i (length o1) n1) ->
  firstn (length o2) (skipn j (splice s i (length o1) n1)) = o2 ->
  splice (splice s i (length o1) n1) j (length o2) n2
  = splice (splice s (j + length o1 - length n1) (length o2) n2) i (length o1) n1.
Proof.
  intros s i o1 n1 j o2 n2 Hlt Hb1 Hc1 Hb2 Hc2.
  pose proof (seg_decompose s i (length o1)) as Hs. rewrite Hc1 in Hs.
  set (A := firstn i s) in *. set (W := skipn (i + length o1) s) in *.
  assert (HA : length A = i) by (apply firstn_length_le; lia).
  assert (E1 : splice s i (length o1) n1 = A ++ n1 ++ W).
  { rewrite Hs. apply splice_at; [lia | reflexivity]. }
  set (k := j - (i + length n1)).
  assert (Hj : j = i + length n1 + k) by (unfold k; lia).
  assert (HW1 : length (splice s i (length o1) n1) = i + length n1 + length W).
  { rewrite E1, !length_app. lia. }
  assert (Hskip : skipn j (splice s i (length o1) n1) = skipn k W).
  { rewrite E1, Hj, app_assoc, skipn_app, skipn_all2
      by (rewrite length_app; lia).
    simpl. f_equal. rewrite length_app. lia. }
  assert (Hc2' : firstn (length o2) (skipn k W) = o2)
    by (rewrite <- Hskip; exact Hc2).
  assert (Hbk : k + length o2 <= length W) by lia.
  pose proof (seg_decompose W k (length o2)) as HW. rewrite Hc2' in HW.
  set (M := firstn k W) in *. set (Z := skipn (k + length o2) W) in *.
  assert (HM : length M = k) by (apply firstn_length_le; lia).
  rewrite E1, Hs, HW.
  (* lay every splice on its exact seam, then it is pure reassociation *)
  replace (A ++ n1 ++ M ++ o2 ++ Z) with ((A ++ n1 ++ M) ++ o2 ++ Z)
    by (now rewrite <- !app_assoc).
  replace (A ++ o1 ++ M ++ o2 ++ Z) with ((A ++ o1 ++ M) ++ o2 ++ Z)
    by (now rewrite <- !app_assoc).
  assert (SA1 : splice ((A ++ n1 ++ M) ++ o2 ++ Z) j (length o2) n2
              = (A ++ n1 ++ M) ++ n2 ++ Z).
  { apply splice_at; [rewrite !length_app; lia | reflexivity]. }
  assert (SA2 : splice ((A ++ o1 ++ M) ++ o2 ++ Z)
                       (j + length o1 - length n1) (length o2) n2
              = (A ++ o1 ++ M) ++ n2 ++ Z).
  { apply splice_at; [rewrite !length_app; lia | reflexivity]. }
  rewrite SA1, SA2.
  replace ((A ++ o1 ++ M) ++ n2 ++ Z) with (A ++ o1 ++ (M ++ n2 ++ Z))
    by (now rewrite <- !app_assoc).
  assert (SA3 : splice (A ++ o1 ++ (M ++ n2 ++ Z)) i (length o1) n1
              = A ++ n1 ++ (M ++ n2 ++ Z)).
  { apply splice_at; [lia | reflexivity]. }
  rewrite SA3. now rewrite <- !app_assoc.
Qed.

(* The BEFORE branch: q aims strictly ahead of p, so p is the one that slides
   (FORWARD by q's delta). Here s decomposes as B ++ o2 ++ C ++ o1 ++ W. *)
Lemma splice_before_comm : forall s i o1 n1 j o2 n2,
  j + length o2 < i ->
  i + length o1 <= length s ->
  firstn (length o1) (skipn i s) = o1 ->
  firstn (length o2) (skipn j (splice s i (length o1) n1)) = o2 ->
  splice (splice s i (length o1) n1) j (length o2) n2
  = splice (splice s j (length o2) n2) (i + length n2 - length o2) (length o1) n1.
Proof.
  intros s i o1 n1 j o2 n2 Hlt Hb1 Hc1 Hc2.
  pose proof (seg_decompose s i (length o1)) as Hs. rewrite Hc1 in Hs.
  set (A := firstn i s) in *. set (W := skipn (i + length o1) s) in *.
  assert (HA : length A = i) by (apply firstn_length_le; lia).
  assert (E1 : splice s i (length o1) n1 = A ++ n1 ++ W).
  { rewrite Hs. apply splice_at; [lia | reflexivity]. }
  assert (Hskip : skipn j (splice s i (length o1) n1) = skipn j A ++ (n1 ++ W)).
  { rewrite E1, skipn_app. replace (j - length A) with 0 by lia. reflexivity. }
  assert (Hc2' : firstn (length o2) (skipn j A) = o2).
  { rewrite Hskip, firstn_app in Hc2.
    replace (length o2 - length (skipn j A)) with 0 in Hc2
      by (rewrite length_skipn; lia).
    simpl in Hc2. rewrite app_nil_r in Hc2. exact Hc2. }
  pose proof (seg_decompose A j (length o2)) as HAd. rewrite Hc2' in HAd.
  set (B := firstn j A) in *. set (C := skipn (j + length o2) A) in *.
  assert (HB : length B = j) by (apply firstn_length_le; lia).
  assert (HC : length C = i - (j + length o2)).
  { unfold C. rewrite length_skipn. lia. }
  rewrite E1, Hs, HAd.
  replace ((B ++ o2 ++ C) ++ n1 ++ W) with (B ++ o2 ++ (C ++ n1 ++ W))
    by (now rewrite <- !app_assoc).
  replace ((B ++ o2 ++ C) ++ o1 ++ W) with (B ++ o2 ++ (C ++ o1 ++ W))
    by (now rewrite <- !app_assoc).
  assert (SB1 : splice (B ++ o2 ++ (C ++ n1 ++ W)) j (length o2) n2
              = B ++ n2 ++ (C ++ n1 ++ W)).
  { apply splice_at; [lia | reflexivity]. }
  assert (SB2 : splice (B ++ o2 ++ (C ++ o1 ++ W)) j (length o2) n2
              = B ++ n2 ++ (C ++ o1 ++ W)).
  { apply splice_at; [lia | reflexivity]. }
  rewrite SB1, SB2.
  replace (B ++ n2 ++ (C ++ o1 ++ W)) with ((B ++ n2 ++ C) ++ o1 ++ W)
    by (now rewrite <- !app_assoc).
  assert (SB3 : splice ((B ++ n2 ++ C) ++ o1 ++ W)
                       (i + length n2 - length o2) (length o1) n1
              = (B ++ n2 ++ C) ++ n1 ++ W).
  { apply splice_at; [rewrite !length_app; lia | reflexivity]. }
  rewrite SB3. now rewrite <- !app_assoc.
Qed.

(* Tied to hcommute: a successful commute WITNESSES order-freedom, in the honest
   contexts (p belongs on s; q belongs after p). The named-slot commute_sound
   needed no validity -- nothing shifted; here the contexts pin the seams. *)
Theorem hcommute_sound : forall p q q' p' s,
  hcommute p q = Some (q', p') ->
  hvalid s p -> hvalid (hap s p) q ->
  hap (hap s p) q = hap (hap s q') p'.
Proof.
  intros [i o1 n1] [j o2 n2] q' p' s Hcm [Hb1 Hc1] [Hb2 Hc2].
  unfold hcommute in Hcm. unfold hap in *. simpl in *.
  destruct (i + length n1 <? j) eqn:E1.
  - apply Nat.ltb_lt in E1. injection Hcm as <- <-. simpl.
    now apply splice_after_comm.
  - destruct (j + length o2 <? i) eqn:E2; [|discriminate].
    apply Nat.ltb_lt in E2. injection Hcm as <- <-. simpl.
    now apply splice_before_comm.
Qed.

(* ============================================================ *)
(* (L3b) a frontier is stable under the adjacent re-aimed swap  *)
(* ============================================================ *)

(* States are plain lists, so once the two-patch prefix agrees the rest of the
   frontier folds identically -- the reproducibility tie with real shifting. *)
Theorem hfold_swap : forall p q q' p' s post,
  hcommute p q = Some (q', p') ->
  hvalid s p -> hvalid (hap s p) q ->
  fold_left hap (p :: q :: post) s = fold_left hap (q' :: p' :: post) s.
Proof.
  intros p q q' p' s post Hcm Hv1 Hv2. simpl. f_equal.
  now apply hcommute_sound.
Qed.

(* ============================================================ *)
(* the CONFLICTOR slice: merge RECORDS, and the state enlarges  *)
(* ============================================================ *)

(* Mirror of test/patch.l's third form, on the lawful region (the .l's pull is
   value-generic; here values are nat -- the models agree wherever the co-valid
   discipline holds, and both no-op on cell-shaped breaches). commute REFUSES a
   dependency; merge may not, so the STATE enlarges (pijul's move, not darcs
   1.x's exotic patch algebra): a conflicted slot holds a CLASH -- the shared
   base plus a canonically-ordered SET of rivals -- making merge total,
   symmetric, and associative by construction. A clash is a first-class VALUE,
   so a resolution is an ordinary patch whose old value is the cell, and the
   groupoid laws ride along (resolve_roundtrip). *)

Inductive slot :=
  | Plain (v : nat)
  | Clash (base : nat) (rivals : list nat).

Definition stree := nat -> slot.

Record spatch := mks { sk : nat ; sa : slot ; sb : slot }.

(* the canonical rival set: sorted insert with dedup. cins_comm is what makes
   merge order-free; cins_absorb is what lets a settled edit rejoin harmlessly. *)
Fixpoint cins (x : nat) (l : list nat) : list nat :=
  match l with
  | [] => [x]
  | h :: t => if x =? h then l else if x <? h then x :: l else h :: cins x t
  end.

Fixpoint eqb_list (a b : list nat) : bool :=
  match a, b with
  | [], [] => true
  | x :: xs, y :: ys => (x =? y) && eqb_list xs ys
  | _, _ => false
  end.

Definition slot_eqb (a b : slot) : bool :=
  match a, b with
  | Plain u, Plain v => u =? v
  | Clash u us, Clash v vs => (u =? v) && eqb_list us vs
  | _, _ => false
  end.

Lemma eqb_list_refl : forall l, eqb_list l l = true.
Proof. induction l; simpl; auto. rewrite Nat.eqb_refl. auto. Qed.

Lemma eqb_list_true : forall a b, eqb_list a b = true -> a = b.
Proof.
  induction a as [|x xs IH]; destruct b; simpl; try discriminate; auto.
  intros H. apply andb_prop in H as [H1 H2]. apply Nat.eqb_eq in H1.
  f_equal; auto.
Qed.

Lemma slot_eqb_refl : forall s, slot_eqb s s = true.
Proof.
  destruct s; simpl; [apply Nat.eqb_refl|].
  rewrite Nat.eqb_refl, eqb_list_refl. reflexivity.
Qed.

Lemma slot_eqb_true : forall a b, slot_eqb a b = true -> a = b.
Proof.
  destruct a, b; simpl; try discriminate; intros H.
  - apply Nat.eqb_eq in H. now subst.
  - apply andb_prop in H as [H1 H2]. apply Nat.eqb_eq in H1.
    apply eqb_list_true in H2. now subst.
Qed.

Ltac creduce :=
  repeat (first
    [ rewrite Nat.eqb_refl
    | match goal with
      | H : ?a <> ?b |- context [?a =? ?b] =>
          rewrite (proj2 (Nat.eqb_neq a b) H)
      | H : ?b <> ?a |- context [?a =? ?b] =>
          rewrite (proj2 (Nat.eqb_neq a b) (not_eq_sym H))
      | |- context [?a =? ?b] => rewrite (proj2 (Nat.eqb_neq a b)) by lia
      | |- context [?a <? ?b] => rewrite (proj2 (Nat.ltb_lt a b)) by lia
      | |- context [?a <? ?b] => rewrite (proj2 (Nat.ltb_ge a b)) by lia
      end
    | progress simpl ]).

Lemma cins_comm : forall x y l, cins x (cins y l) = cins y (cins x l).
Proof.
  intros x y l. induction l as [|h t IH]; simpl.
  - destruct (Nat.eqb_spec x y) as [->|N]; [now rewrite Nat.eqb_refl|].
    destruct (Nat.ltb_spec x y); destruct (Nat.ltb_spec y x);
      try lia; creduce; reflexivity.
  - destruct (Nat.eqb_spec y h) as [->|Nyh]; destruct (Nat.eqb_spec x h) as [->|Nxh].
    + reflexivity.
    + destruct (Nat.ltb_spec x h); creduce; reflexivity.
    + destruct (Nat.ltb_spec y h); creduce; reflexivity.
    + destruct (Nat.ltb_spec y h) as [Ly|Ly]; destruct (Nat.ltb_spec x h) as [Lx|Lx].
      * destruct (Nat.eqb_spec x y) as [->|Nxy]; [creduce; reflexivity|].
        destruct (Nat.ltb_spec x y); creduce; reflexivity.
      * creduce; reflexivity.
      * creduce; reflexivity.
      * creduce. now rewrite IH.
Qed.

(* a settled rival rejoins harmlessly: insert dedups. *)
Lemma cins_absorb : forall x l, cins x (cins x l) = cins x l.
Proof.
  intros x l. induction l as [|h t IH]; simpl.
  - now rewrite Nat.eqb_refl.
  - destruct (Nat.eqb_spec x h) as [->|N].
    + simpl. now rewrite Nat.eqb_refl.
    + destruct (Nat.ltb_spec x h); creduce; [reflexivity|now rewrite IH].
Qed.

(* merge1: the one-slot merge -- pull factors through it. Lane order mirrors
   the .l: context matches / same edit settles / join the rivals / a rival
   landed first / breach no-ops. *)
Definition merge1 (v old new : slot) : slot :=
  if slot_eqb v old then new
  else if slot_eqb v new then v
  else match v, old, new with
       | Clash base rs, Plain a, Plain b =>
           if base =? a then Clash a (cins b rs) else v
       | Plain w, Plain a, Plain b => Clash a (cins b [w])
       | _, _, _ => v
       end.

(* pull: TOTAL merge-application (the .l's pull). It trusts the co-valid
   discipline -- every pulled patch reads the shared base or a rival of it;
   `valid`-style honesty stays with a lone patch's application. *)
Definition pull (t : stree) (p : spatch) : stree :=
  fun k => if k =? sk p then merge1 (t (sk p)) (sa p) (sb p) else t k.

Definition sinv (p : spatch) : spatch := mks (sk p) (sb p) (sa p).

Lemma pull_other : forall t p k, k <> sk p -> pull t p k = t k.
Proof.
  intros t p k H. unfold pull.
  destruct (Nat.eqb_spec k (sk p)); congruence.
Qed.

Lemma pull_at : forall t p, pull t p (sk p) = merge1 (t (sk p)) (sa p) (sb p).
Proof. intros. unfold pull. now rewrite Nat.eqb_refl. Qed.

(* different slots never interact: the rung-1 independence face, on pull. *)
Lemma pull_indep_comm : forall t p q, sk p <> sk q ->
  forall k, pull (pull t p) q k = pull (pull t q) p k.
Proof.
  intros t p q H k.
  destruct (Nat.eqb_spec k (sk p)) as [->|Np].
  - rewrite (pull_other _ q) by congruence.
    rewrite !pull_at. f_equal. now rewrite pull_other by congruence.
  - destruct (Nat.eqb_spec k (sk q)) as [->|Nq].
    + rewrite (pull_other _ p (sk q)) by congruence.
      rewrite !pull_at. f_equal. now rewrite pull_other by congruence.
    + rewrite !pull_other by congruence. reflexivity.
Qed.

(* ============================================================ *)
(* (M1) merge is SYMMETRIC -- for ANY starting slot             *)
(* ============================================================ *)

(* The heart of the rung: two rivals off one base land the same cell whichever
   is pulled first -- for an ARBITRARY slot value v (the shared base, a rival
   already landed, a clash already open, or a breach that no-ops). No
   hypothesis on v means three-way convergence is just this law twice. *)
(* the leaf grinder: on literal rival lists everything reduces to nat
   comparisons -- destruct them all, prune by lia, close by reflexivity. *)
Ltac cfin :=
  repeat (first
    [ reflexivity | lia | congruence
    | progress simpl
    | progress subst
    | rewrite Nat.eqb_refl
    | match goal with
      | |- context [?a =? ?b] => destruct (Nat.eqb_spec a b)
      | |- context [?a <? ?b] => destruct (Nat.ltb_spec a b)
      end ]).

Lemma merge1_comm : forall v a b c, b <> a -> c <> a ->
  merge1 (merge1 v (Plain a) (Plain b)) (Plain a) (Plain c)
  = merge1 (merge1 v (Plain a) (Plain c)) (Plain a) (Plain b).
Proof.
  intros v a b c Hba Hca.
  destruct (Nat.eqb_spec b c) as [->|Nbc]; [reflexivity|].
  destruct v as [w|base rs]; unfold merge1; simpl.
  - (* a plain slot: the base, a rival already landed, or one of the two
       edits (settled on one side, deduped on the other) -- on literal lists
       it all grinds down to comparisons *)
    destruct (Nat.eqb_spec w a) as [->|Nwa]; creduce; [cfin|].
    destruct (Nat.eqb_spec w b) as [->|Nwb]; creduce; [cfin|].
    destruct (Nat.eqb_spec w c) as [->|Nwc]; creduce; cfin.
  - (* a clash already open: join twice, either order -- or a breach no-op *)
    destruct (Nat.eqb_spec base a) as [->|Nba2]; creduce.
    + now rewrite cins_comm.
    + reflexivity.
Qed.

Theorem pull_merge_comm : forall t p q a b c, sk p = sk q ->
  sa p = Plain a -> sb p = Plain b -> sa q = Plain a -> sb q = Plain c ->
  b <> a -> c <> a ->
  forall k, pull (pull t p) q k = pull (pull t q) p k.
Proof.
  intros t p q a b c Hk Hap Hbp Haq Hbq Hba Hca k.
  destruct (Nat.eqb_spec k (sk p)) as [->|N].
  - rewrite Hk, !pull_at, <- Hk, !pull_at, Hk, !pull_at.
    rewrite Hap, Hbp, Haq, Hbq. now apply merge1_comm.
  - rewrite !pull_other by congruence. reflexivity.
Qed.

(* ============================================================ *)
(* (M2) the settled lanes: pulling is idempotent                *)
(* ============================================================ *)

Lemma merge1_idem : forall v o n, merge1 (merge1 v o n) o n = merge1 v o n.
Proof.
  intros v o n. unfold merge1 at 2 3.
  destruct (slot_eqb v o) eqn:Evo.
  - (* context matched: pulling again settles on the new value *)
    unfold merge1. destruct (slot_eqb n o) eqn:Eno; [reflexivity|].
    now rewrite slot_eqb_refl.
  - destruct (slot_eqb v n) eqn:Evn.
    + (* already settled: unchanged *)
      unfold merge1. now rewrite Evo, Evn.
    + destruct v as [w|base rs]; destruct o as [a|oa ors]; destruct n as [b|na nrs];
        simpl in Evo, Evn; unfold merge1; simpl; rewrite ?Evo, ?Evn;
        try reflexivity.
      * (* plain/plain/plain: the freshly opened cell re-absorbs b *)
        cfin.
      * (* clash/plain/plain: a joined set absorbs the repeat; a breach no-ops *)
        destruct (Nat.eqb_spec base a) as [->|Nba]; simpl;
          rewrite ?Nat.eqb_refl, ?Evo, ?Evn; simpl.
        -- f_equal. apply cins_absorb.
        -- creduce. reflexivity.
Qed.

Theorem pull_idem : forall t p k, pull (pull t p) p k = pull t p k.
Proof.
  intros t p k. destruct (Nat.eqb_spec k (sk p)) as [->|N].
  - rewrite !pull_at. apply merge1_idem.
  - rewrite !pull_other by congruence. reflexivity.
Qed.

(* ============================================================ *)
(* (M3) a conflict is HONEST: base + both rivals, recorded      *)
(* ============================================================ *)

Theorem pull_records : forall t p q a b c, sk p = sk q ->
  sa p = Plain a -> sb p = Plain b -> sa q = Plain a -> sb q = Plain c ->
  t (sk p) = Plain a -> b <> a -> c <> b ->
  pull (pull t p) q (sk q) = Clash a (cins c [b]).
Proof.
  intros t p q a b c Hk Hap Hbp Haq Hbq Ht Hba Hcb.
  rewrite pull_at, <- Hk, pull_at, Ht, Hap, Hbp, Haq, Hbq.
  unfold merge1; simpl. rewrite Nat.eqb_refl. simpl. creduce. reflexivity.
Qed.

(* ============================================================ *)
(* (M5) RESOLUTION is just a patch: the groupoid rides along    *)
(* ============================================================ *)

Lemma merge1_resolve : forall o n, merge1 (merge1 o o n) n o = o.
Proof.
  intros. unfold merge1. rewrite slot_eqb_refl. cbn.
  now rewrite slot_eqb_refl.
Qed.

Theorem resolve_roundtrip : forall t p, t (sk p) = sa p ->
  forall k, pull (pull t p) (sinv p) k = t k.
Proof.
  intros t p Ht k. destruct (Nat.eqb_spec k (sk p)) as [->|N].
  - unfold sinv, pull; simpl. rewrite Nat.eqb_refl, Ht.
    apply merge1_resolve.
  - rewrite !pull_other by (simpl; congruence). reflexivity.
Qed.

(* ============================================================ *)
(* (M4) a frontier is stable under ANY adjacent swap --         *)
(* independent OR conflicting: merge closed the refusal gap     *)
(* ============================================================ *)

Lemma pull_ext : forall t1 t2 p, (forall k, t1 k = t2 k) ->
  forall k, pull t1 p k = pull t2 p k.
Proof.
  intros t1 t2 p H k. unfold pull.
  destruct (k =? sk p); [now rewrite H | apply H].
Qed.

Lemma fold_pull_ext : forall ps t1 t2, (forall k, t1 k = t2 k) ->
  forall k, fold_left pull ps t1 k = fold_left pull ps t2 k.
Proof.
  induction ps as [|p ps IH]; intros t1 t2 H k; simpl.
  - apply H.
  - apply IH. intro k'. now apply pull_ext.
Qed.

(* THE frontier theorem of this rung: swapping two adjacent patches never
   changes the merged tree -- different slots commute (rung 1's L3b face), and
   same-slot RIVALS now converge instead of refusing. Pull order is dead as a
   semantic input; the (unordered) patch set is the whole story. *)
Theorem pull_fold_swap : forall pre p q post t,
  (sk p <> sk q \/
   exists a b c, sa p = Plain a /\ sb p = Plain b /\ sa q = Plain a /\
                 sb q = Plain c /\ b <> a /\ c <> a) ->
  forall k, fold_left pull (pre ++ p :: q :: post) t k
          = fold_left pull (pre ++ q :: p :: post) t k.
Proof.
  intros pre p q post t H k.
  rewrite !fold_left_app. cbn [fold_left].
  apply fold_pull_ext. intro k'.
  destruct H as [H | (a & b & c & Hap & Hbp & Haq & Hbq & Hba & Hca)].
  - now apply pull_indep_comm.
  - destruct (Nat.eqb_spec (sk p) (sk q)) as [E|E].
    + now apply (pull_merge_comm _ _ _ a b c).
    + now apply pull_indep_comm.
Qed.

(* ============================================================ *)
(* the IDENTITY slice: a version IS its patch set               *)
(* ============================================================ *)

(* Mirror of test/patch.l's fourth form, on the lawful part. The .l hashes
   each patch's printed form (engineering -- djb2 today, a real digest when
   the store lands) and folds the hashes through cins, the same canonical set
   that carries a clash's rivals; the scalar name is one more hash on top.
   The LAWS live on the canonical list: the identity forgets exactly what the
   semantics proved dead -- order (aponl_swap / pull_fold_swap) and repetition
   (pull_idem) -- and nothing more (fid IS the set; distinct sets stay
   distinct up to the engineering hash). *)

Definition fid (hs : list nat) : list nat :=
  fold_left (fun acc h => cins h acc) hs [].

(* (H1) order-free: any adjacent swap, one canonical set. *)
Theorem fid_swap : forall pre a b post,
  fid (pre ++ a :: b :: post) = fid (pre ++ b :: a :: post).
Proof.
  intros. unfold fid. rewrite !fold_left_app. cbn [fold_left].
  f_equal. apply cins_comm.
Qed.

(* (H2) multiplicity-free: a repeated patch names the same version. *)
Theorem fid_dup : forall pre a post,
  fid (pre ++ a :: a :: post) = fid (pre ++ a :: post).
Proof.
  intros. unfold fid. rewrite !fold_left_app. cbn [fold_left].
  f_equal. apply cins_absorb.
Qed.

(* ============================================================ *)
(* the TREE-LIFT slice: a hunk gets a PATH -- the postcode      *)
(* ============================================================ *)

(* Mirror of test/patch.l's fifth form, the algebra half. A patch is a hunk
   plus a PATH to the sequence it splices; the load-bearing fact is that a
   deep patch never changes an ancestor's length, so only same-sequence
   patches shift INDICES while a shallow splice re-aims a deeper patch's path
   COMPONENT at the crossing. tcommute has four lanes by path relation. The
   elements stay abstract (Section variable): L1 is pure path/index algebra.

   The tree APPLY laws (L2/L3 at tree grain) are asserted in the .l; their
   crossing-level semantic core is ALREADY the proven splice_after_comm /
   splice_before_comm with singleton hunks (editing inside element j IS
   splice s j 1 [x]), and the remaining rose-tree plumbing joins the uu-term
   encoding rung rather than growing this scaffold. *)

Section TreeLift.
Variable A : Type.

Record tpatch := mkt
  { tpath : list nat ; ti : nat ; tho : list A ; thn : list A }.

Fixpoint setidx (p : list nat) (d v : nat) : list nat :=
  match p, d with
  | _ :: rest, 0 => v :: rest
  | h :: rest, S d' => h :: setidx rest d' v
  | [], _ => []
  end.

(* how two paths sit: same sequence / q deeper (crossing at child j, depth d)
   / p deeper / diverged. d accumulates the shared-prefix length, so it is the
   ABSOLUTE index of the crossing component -- what setidx re-aims. *)
Inductive prel := Same | InQ (j d : nat) | InP (j d : nat) | Apart.

Fixpoint rel (P Q : list nat) (d : nat) : prel :=
  match P, Q with
  | [], [] => Same
  | [], j :: _ => InQ j d
  | j :: _, [] => InP j d
  | a :: P', b :: Q' => if a =? b then rel P' Q' (S d) else Apart
  end.

Definition tcommute (p q : tpatch) : option (tpatch * tpatch) :=
  let ip := ti p in let o1 := length (tho p) in let n1 := length (thn p) in
  let iq := ti q in let o2 := length (tho q) in let n2 := length (thn q) in
  match rel (tpath p) (tpath q) 0 with
  | Same =>
      if ip + n1 <? iq
      then Some (mkt (tpath q) (iq + o1 - n1) (tho q) (thn q), p)
      else if iq + o2 <? ip
      then Some (q, mkt (tpath p) (ip + n2 - o2) (tho p) (thn p))
      else None
  | InQ j d =>
      if j <? ip then Some (q, p)
      else if ip + n1 <=? j
      then Some (mkt (setidx (tpath q) d (j + o1 - n1)) iq (tho q) (thn q), p)
      else None
  | InP j d =>
      if j <? iq then Some (q, p)
      else if iq + o2 <=? j
      then Some (q, mkt (setidx (tpath p) d (j + n2 - o2)) ip (tho p) (thn p))
      else None
  | Apart => Some (q, p)
  end.

(* --- the rel/setidx lemma kit --- *)

Lemma rel_same_eq : forall P Q d, rel P Q d = Same -> P = Q.
Proof.
  induction P as [|a P IH]; destruct Q as [|b Q]; simpl; intros d H;
    try discriminate; auto.
  destruct (Nat.eqb_spec a b); [subst; f_equal; eauto | discriminate].
Qed.

Lemma rel_refl : forall P d, rel P P d = Same.
Proof.
  induction P; simpl; intros; [reflexivity|]. now rewrite Nat.eqb_refl.
Qed.

Lemma rel_apart_sym : forall P Q d, rel P Q d = Apart -> rel Q P d = Apart.
Proof.
  induction P as [|a P IH]; destruct Q as [|b Q]; simpl; intros d H;
    try discriminate.
  destruct (Nat.eqb_spec a b); destruct (Nat.eqb_spec b a);
    subst; try congruence; eauto.
Qed.

Lemma rel_inq_flip : forall P Q d0 j d,
  rel P Q d0 = InQ j d -> rel Q P d0 = InP j d.
Proof.
  induction P as [|a P IH]; destruct Q as [|b Q]; simpl; intros d0 j d H;
    try discriminate.
  - now injection H as <- <-.
  - destruct (Nat.eqb_spec a b); destruct (Nat.eqb_spec b a);
      subst; try congruence; eauto.
Qed.

Lemma rel_inp_flip : forall P Q d0 j d,
  rel P Q d0 = InP j d -> rel Q P d0 = InQ j d.
Proof.
  induction P as [|a P IH]; destruct Q as [|b Q]; simpl; intros d0 j d H;
    try discriminate.
  - now injection H as <- <-.
  - destruct (Nat.eqb_spec a b); destruct (Nat.eqb_spec b a);
      subst; try congruence; eauto.
Qed.

Lemma rel_inq_ge : forall P Q d0 j d, rel P Q d0 = InQ j d -> d0 <= d.
Proof.
  induction P as [|a P IH]; destruct Q as [|b Q]; simpl; intros d0 j d H;
    try discriminate.
  - injection H as <- <-. lia.
  - destruct (Nat.eqb_spec a b); [|discriminate].
    specialize (IH _ _ _ _ H). lia.
Qed.

(* re-aiming the crossing component keeps the relation, with the new j... *)
Lemma rel_inq_setidx : forall P Q d0 j d v,
  rel P Q d0 = InQ j d -> rel (setidx Q (d - d0) v) P d0 = InP v d.
Proof.
  induction P as [|a P IH]; destruct Q as [|b Q]; simpl; intros d0 j d v H;
    try discriminate.
  - injection H as <- <-. rewrite Nat.sub_diag. reflexivity.
  - destruct (Nat.eqb_spec a b); [subst|discriminate].
    pose proof (rel_inq_ge _ _ _ _ _ H).
    replace (d - d0) with (S (d - S d0)) by lia. simpl.
    rewrite Nat.eqb_refl. eauto.
Qed.

(* ...and putting the ORIGINAL component back is the identity. *)
Lemma setidx_self : forall P Q d0 j d,
  rel P Q d0 = InQ j d -> setidx Q (d - d0) j = Q.
Proof.
  induction P as [|a P IH]; destruct Q as [|b Q]; simpl; intros d0 j d H;
    try discriminate.
  - injection H as <- <-. rewrite Nat.sub_diag. reflexivity.
  - destruct (Nat.eqb_spec a b); [subst|discriminate].
    pose proof (rel_inq_ge _ _ _ _ _ H).
    replace (d - d0) with (S (d - S d0)) by lia. simpl.
    f_equal. eauto.
Qed.

Lemma setidx_setidx : forall Q d v w,
  setidx (setidx Q d v) d w = setidx Q d w.
Proof.
  induction Q as [|b Q IH]; destruct d; simpl; intros; try reflexivity.
  now rewrite IH.
Qed.

(* (L1) tcommute is involutive -- the four lanes swap home, including the
   PATH re-aim (the crossing component slides back exactly). *)
Theorem tcommute_involutive : forall p q q' p',
  tcommute p q = Some (q', p') -> tcommute q' p' = Some (p, q).
Proof.
  intros [P ip o1 n1] [Q iq o2 n2] q' p' H.
  unfold tcommute in *; simpl in *.
  destruct (rel P Q 0) eqn:R.
  - (* Same: rung 2's arithmetic, paths riding *)
    pose proof (rel_same_eq _ _ _ R) as ->.
    destruct (ip + length n1 <? iq) eqn:E1.
    + injection H as <- <-; simpl. apply Nat.ltb_lt in E1.
      rewrite rel_refl.
      destruct (iq + length o1 - length n1 + length n2 <? ip) eqn:F1.
      * apply Nat.ltb_lt in F1. lia.
      * destruct (ip + length o1 <? iq + length o1 - length n1) eqn:F2.
        -- replace (iq + length o1 - length n1 + length n1 - length o1)
             with iq by lia. reflexivity.
        -- apply Nat.ltb_ge in F2. lia.
    + destruct (iq + length o2 <? ip) eqn:E2; [|discriminate].
      injection H as <- <-; simpl. apply Nat.ltb_lt in E2.
      rewrite rel_refl.
      destruct (iq + length n2 <? ip + length n2 - length o2) eqn:F1.
      * replace (ip + length n2 - length o2 + length o2 - length n2)
          with ip by lia. reflexivity.
      * apply Nat.ltb_ge in F1. lia.
  - (* InQ: q is deeper; either untouched or its path component slid back *)
    destruct (j <? ip) eqn:E1.
    + injection H as <- <-; simpl.
      rewrite (rel_inq_flip _ _ _ _ _ R), E1. reflexivity.
    + destruct (ip + length n1 <=? j) eqn:E2; [|discriminate].
      injection H as <- <-; simpl.
      apply Nat.ltb_ge in E1. apply Nat.leb_le in E2.
      pose proof (rel_inq_setidx _ _ _ _ _ (j + length o1 - length n1) R) as RS.
      pose proof (setidx_self _ _ _ _ _ R) as SS.
      rewrite Nat.sub_0_r in RS, SS. rewrite RS.
      destruct (j + length o1 - length n1 <? ip) eqn:F1.
      * apply Nat.ltb_lt in F1. lia.
      * destruct (ip + length o1 <=? j + length o1 - length n1) eqn:F2.
        -- rewrite setidx_setidx.
           replace (j + length o1 - length n1 + length n1 - length o1)
             with j by lia.
           rewrite SS. reflexivity.
        -- apply Nat.leb_gt in F2. lia.
  - (* InP: p is deeper; mirror *)
    destruct (j <? iq) eqn:E1.
    + injection H as <- <-; simpl.
      rewrite (rel_inp_flip _ _ _ _ _ R), E1. reflexivity.
    + destruct (iq + length o2 <=? j) eqn:E2; [|discriminate].
      injection H as <- <-; simpl.
      apply Nat.ltb_ge in E1. apply Nat.leb_le in E2.
      pose proof (rel_inp_flip _ _ _ _ _ R) as RQ.
      pose proof (rel_inq_setidx _ _ _ _ _ (j + length n2 - length o2) RQ) as RS.
      pose proof (setidx_self _ _ _ _ _ RQ) as SS.
      rewrite Nat.sub_0_r in RS, SS.
      apply rel_inp_flip in RS. rewrite RS.
      destruct (j + length n2 - length o2 <? iq) eqn:F1.
      * apply Nat.ltb_lt in F1. lia.
      * destruct (iq + length n2 <=? j + length n2 - length o2) eqn:F2.
        -- rewrite setidx_setidx.
           replace (j + length n2 - length o2 + length o2 - length n2)
             with j by lia.
           rewrite SS. reflexivity.
        -- apply Nat.leb_gt in F2. lia.
  - (* Apart: disjoint subtrees ride untouched *)
    injection H as <- <-; simpl.
    rewrite (rel_apart_sym _ _ _ R). reflexivity.
Qed.

End TreeLift.

(* ============================================================ *)
(* the CONTENT-REWRITE slice: the swallow commutes              *)
(* ============================================================ *)

(* Mirror of test/patch.l's sixth form, the L1 core at ELEMENT grain: the deep
   edit collapsed to "at seat j, element a becomes b" (the unit walk's
   rose-tree descent and the apply laws stay asserted in the .l and join the
   uu-term rung). What is genuinely NEW in this lane -- the four occurrence
   guards that make the context rewrite canonical BOTH ways -- is pure
   occurrence/replace algebra over one sequence, proven here: swal composed
   with itself through the groupoid inverse is the identity, which is exactly
   how the .l rides it (the inq mirror inverts in and out, so ONE core serves
   both directions and L1 falls out of the algebra). *)

Section Swallow.
Variable A : Type.
Hypothesis Aeq : forall x y : A, {x = y} + {x <> y}.

(* the shallow patch: a hunk over a sequence of elements *)
Record wpatch := mkw { wi : nat ; wo : list A ; wn : list A }.
(* the deep patch at element grain: at seat j, element a becomes b *)
Record epatch := mke { ej : nat ; ea : A ; eb : A }.

Definition winv (p : wpatch) : wpatch := mkw (wi p) (wn p) (wo p).
Definition einv (p : epatch) : epatch := mke (ej p) (eb p) (ea p).

Fixpoint occ (x : A) (l : list A) : nat :=
  match l with
  | [] => 0
  | h :: t => (if Aeq h x then 1 else 0) + occ x t
  end.

(* first occurrence -- the guards pin occ to 1, so "first" is "the" *)
Fixpoint ffind (x : A) (l : list A) : nat :=
  match l with
  | [] => 0
  | h :: t => if Aeq h x then 0 else S (ffind x t)
  end.

(* lay value v at seat k (the .l's tlay, element grain) *)
Fixpoint lay (l : list A) (k : nat) (v : A) : list A :=
  match l, k with
  | [], _ => []
  | _ :: t, 0 => v :: t
  | h :: t, S k' => h :: lay t k' v
  end.

(* the deep-first swallow commute: dp ran first, so sp's olds carry its
   effect (element b at seat ej); undo it in BOTH of sp's sides, re-aim dp
   at the survivor's seat in the news. the guards, as in the .l: context
   matches, the post state exactly once on each side, the pre state on
   neither. *)
Definition swal (dp : epatch) (sp : wpatch) : option (wpatch * epatch) :=
  let off := ej dp - wi sp in
  let O := wo sp in let N := wn sp in
  if wi sp <=? ej dp then if ej dp <? wi sp + length O then
    match nth_error O off with
    | Some el =>
        if Aeq el (eb dp) then
          if occ (eb dp) O =? 1 then if occ (ea dp) O =? 0 then
          if occ (eb dp) N =? 1 then if occ (ea dp) N =? 0
          then let m := ffind (eb dp) N in
               Some (mkw (wi sp) (lay O off (ea dp)) (lay N m (ea dp)),
                     mke (wi sp + m) (ea dp) (eb dp))
          else None else None else None else None
        else None
    | None => None
    end
  else None else None.

(* --- the occurrence/replace lemma kit --- *)

Lemma lay_length : forall l k v, length (lay l k v) = length l.
Proof. induction l; destruct k; simpl; auto. Qed.

Lemma occ_pos_ffind_lt : forall x l, 0 < occ x l -> ffind x l < length l.
Proof.
  intros x; induction l as [|h t IH]; simpl; intros H; [lia|].
  destruct (Aeq h x); [lia|]. simpl in H. specialize (IH H). lia.
Qed.

Lemma nth_ffind : forall x l, 0 < occ x l -> nth_error l (ffind x l) = Some x.
Proof.
  intros x; induction l as [|h t IH]; simpl; intros H; [lia|].
  destruct (Aeq h x); simpl; [now subst | apply IH; lia].
Qed.

Lemma nth_lay : forall l k v, k < length l -> nth_error (lay l k v) k = Some v.
Proof.
  induction l as [|h t IH]; destruct k; simpl; intros v H; try lia; auto.
  apply IH; lia.
Qed.

Lemma lay_lay : forall l k v w, lay (lay l k v) k w = lay l k w.
Proof.
  induction l as [|h t IH]; destruct k; simpl; intros; auto. now rewrite IH.
Qed.

Lemma lay_id : forall l k v, nth_error l k = Some v -> lay l k v = l.
Proof.
  induction l as [|h t IH]; destruct k; simpl; intros v H; try discriminate.
  - now injection H as ->.
  - now rewrite IH.
Qed.

(* laying x over a non-x seat gains exactly one occurrence of x... *)
Lemma occ_lay_in : forall l k x u, nth_error l k = Some u -> u <> x ->
  occ x (lay l k x) = S (occ x l).
Proof.
  induction l as [|h t IH]; destruct k; simpl; intros x u H NE; try discriminate.
  - injection H as ->. destruct (Aeq x x); [|congruence].
    destruct (Aeq u x); [congruence|]. reflexivity.
  - destruct (Aeq h x); simpl; now rewrite (IH _ _ _ H NE).
Qed.

(* ...and laying non-x over an x seat loses exactly one. *)
Lemma occ_lay_out : forall l k x v, nth_error l k = Some x -> v <> x ->
  occ x l = S (occ x (lay l k v)).
Proof.
  induction l as [|h t IH]; destruct k; simpl; intros x v H NE; try discriminate.
  - injection H as ->. destruct (Aeq x x); [|congruence].
    destruct (Aeq v x); [congruence|]. reflexivity.
  - destruct (Aeq h x); simpl; now rewrite <- (IH _ _ _ H NE).
Qed.

(* where x occurs NOWHERE, laying it in pins ffind to the seat. *)
Lemma ffind_lay : forall l k x, occ x l = 0 -> k < length l ->
  ffind x (lay l k x) = k.
Proof.
  induction l as [|h t IH]; destruct k; simpl; intros x H L; try lia.
  - destruct (Aeq x x); [auto|congruence].
  - destruct (Aeq h x) in H; [lia|].
    destruct (Aeq h x); [congruence|]. rewrite IH; lia.
Qed.

(* (L1) the swallow commute is involutive THROUGH THE GROUPOID INVERSE --
   invert both patches, swal again, and the originals come home (inverted:
   un-inverting them is the .l's mirror wrap-up). *)
Theorem swal_involutive : forall dp sp sp' dp',
  swal dp sp = Some (sp', dp') ->
  swal (einv dp') (winv sp') = Some (winv sp, einv dp).
Proof.
  intros [j a b] [i O N] sp' dp' H.
  unfold swal in H; simpl in H.
  destruct (i <=? j) eqn:LE; [|discriminate].
  destruct (j <? i + length O) eqn:LT; [|discriminate].
  apply Nat.leb_le in LE. apply Nat.ltb_lt in LT.
  destruct (nth_error O (j - i)) as [el|] eqn:EL; [|discriminate].
  destruct (Aeq el b) as [->|]; [|discriminate].
  destruct (occ b O =? 1) eqn:G1; [|discriminate].
  destruct (occ a O =? 0) eqn:G2; [|discriminate].
  destruct (occ b N =? 1) eqn:G3; [|discriminate].
  destruct (occ a N =? 0) eqn:G4; [|discriminate].
  apply Nat.eqb_eq in G1, G2, G3, G4.
  injection H as <- <-.
  assert (NEab : a <> b) by (intros ->; lia).
  assert (NEba : b <> a) by (intros ->; lia).
  assert (Fm : ffind b N < length N) by (apply occ_pos_ffind_lt; lia).
  assert (Nm : nth_error N (ffind b N) = Some b) by (apply nth_ffind; lia).
  assert (Hji : j - i < length O) by lia.
  unfold swal, winv, einv; simpl.
  rewrite lay_length.
  replace (i <=? i + ffind b N) with true by (symmetry; apply Nat.leb_le; lia).
  replace (i + ffind b N <? i + length N) with true
    by (symmetry; apply Nat.ltb_lt; lia).
  simpl. replace (i + ffind b N - i) with (ffind b N) by lia.
  rewrite (nth_lay N (ffind b N) a Fm).
  destruct (Aeq a a); [|congruence].
  assert (OA1 : occ a (lay N (ffind b N) a) = 1)
    by (rewrite (occ_lay_in _ _ _ _ Nm NEba); lia).
  assert (OB0 : occ b (lay N (ffind b N) a) = 0)
    by (pose proof (occ_lay_out _ _ _ _ Nm NEab); lia).
  assert (OA1' : occ a (lay O (j - i) a) = 1)
    by (rewrite (occ_lay_in _ _ _ _ EL NEba); lia).
  assert (OB0' : occ b (lay O (j - i) a) = 0)
    by (pose proof (occ_lay_out _ _ _ _ EL NEab); lia).
  rewrite OA1, OB0, OA1', OB0'. simpl.
  rewrite (ffind_lay O (j - i) a G2 Hji).
  rewrite lay_lay, (lay_id N _ b Nm), lay_lay, (lay_id O _ b EL).
  replace (i + (j - i)) with j by lia.
  reflexivity.
Qed.

End Swallow.

(* ============================================================ *)
(* the CLASH-SEGMENTS slice: the bubble at hash grain           *)
(* ============================================================ *)

(* Mirror of test/patch.l's seventh form, the cell algebra: two co-valid
   hunks whose spans overlap (or touch, or share a seam) collapse the UNION
   HULL of their base spans to one clash cell -- the hull segment plus each
   rival rendered as the hull with its hunk laid inside, the rival set
   cins-canonical by content hash (the .l's hval; the identity slice already
   rides the same move). Symmetry is min/max algebra plus cins_comm; the
   join/absorb faces of pull's lane ARE cins_comm/cins_absorb, audited above.
   The state-level M laws stay asserted in the .l (a cell is a first-class
   ELEMENT there; here sequences are bare nat lists), queued for the uu rung. *)

Section ClashSeg.
Variable hash : list nat -> nat.

Definition sseg (s : list nat) (i n : nat) : list nat := firstn n (skipn i s).
Definition ulo (p q : hunk) : nat := Nat.min (hpos p) (hpos q).
Definition uhi (p q : hunk) : nat :=
  Nat.max (hpos p + length (hold p)) (hpos q + length (hold q)).

(* render a rival: the hull with the hunk laid inside *)
Definition rend (s0 : list nat) (lo hi : nat) (r : hunk) : list nat :=
  splice (sseg s0 lo (hi - lo)) (hpos r - lo) (length (hold r)) (hnew r).

(* the cell content: hull base + the rival set *)
Definition scell (s0 : list nat) (p q : hunk) : list nat * list nat :=
  (sseg s0 (ulo p q) (uhi p q - ulo p q),
   cins (hash (rend s0 (ulo p q) (uhi p q) p))
        (cins (hash (rend s0 (ulo p q) (uhi p q) q)) [])).

(* (M1 at cell grain) creation is SYMMETRIC: the hull forgets which span
   came first, the rival set forgets which rival did. *)
Theorem scell_comm : forall s0 p q, scell s0 p q = scell s0 q p.
Proof.
  intros s0 p q. unfold scell, ulo, uhi.
  rewrite (Nat.min_comm (hpos p) (hpos q)).
  rewrite (Nat.max_comm (hpos p + length (hold p))
                        (hpos q + length (hold q))).
  f_equal. apply cins_comm.
Qed.

(* the WIDENING law: padding COMMUTES with rendering. a rival is a splice
   into its hull; pad the hull on both sides and the same splice lands one
   pad further in -- so a rival rendered over a narrow hull, padded up when
   the bubble widens, IS the rival rendered over the wide hull directly.
   this is what makes mixed-span arrival order dead: whichever pair bubbles
   first, the third widens to the same cell (the .l's pull join lane). *)
Theorem splice_pad : forall (pl pr b n : list nat) i c,
  i + c <= length b ->
  pl ++ splice b i c n ++ pr = splice (pl ++ b ++ pr) (length pl + i) c n.
Proof.
  intros pl pr b n i c H. unfold splice.
  rewrite firstn_app, skipn_app.
  assert (FP : firstn (length pl + i) pl = pl) by (apply firstn_all2; lia).
  assert (SP : skipn (length pl + i + c) pl = []) by (apply skipn_all2; lia).
  rewrite FP, SP.
  replace (length pl + i - length pl) with i by lia.
  replace (length pl + i + c - length pl) with (i + c) by lia.
  rewrite firstn_app, skipn_app.
  replace (i - length b) with 0 by lia.
  replace (i + c - length b) with 0 by lia.
  simpl. rewrite app_nil_r.
  now rewrite <- !app_assoc.
Qed.

(* the BUBBLE law: the conflicted hull contracts to ONE seat, so the merged
   length reads off the hull alone -- no rival size anywhere in the formula:
   every downstream seat is determinate before anyone resolves. *)
Theorem bubble_len : forall s0 p q x,
  uhi p q <= length s0 ->
  length (splice s0 (ulo p q) (uhi p q - ulo p q) [x])
    = S (length s0 - (uhi p q - ulo p q)).
Proof.
  intros s0 p q x H.
  assert (LOHI : ulo p q <= uhi p q).
  { unfold ulo, uhi.
    pose proof (Nat.le_min_l (hpos p) (hpos q)).
    pose proof (Nat.le_max_l (hpos p + length (hold p))
                             (hpos q + length (hold q))).
    lia. }
  unfold splice.
  rewrite !length_app, length_firstn, length_skipn. simpl. lia.
Qed.

End ClashSeg.

(* ============================================================ *)
(* the METAVARIABLE slice: matching sound, the re-aim swaps home *)
(* ============================================================ *)

(* Mirror of test/patch.l's eighth form, in its two genuinely new halves.
   Terms are cons-cells with atoms and metavariables -- exactly the .l's
   grain (mtch walks cap/cup). The unifier half: one-sided matching threads
   a substitution, a non-linear pattern binds consistently or fails, and
   MATCHING IS SOUND -- a pattern instantiated with its own bindings
   reproduces the ground term (what valid/apon lean on). The commute half:
   the schematic swallow re-aims a deep patch from the variable's olds seat
   to its news seat by prefix surgery, the rule itself riding unchanged --
   involutive at address grain. The rose-tree bind/mvat plumbing stays
   asserted in the .l, queued with the rest for the uu-term rung. *)

Section MetaVar.

Inductive term : Type :=
  | Atom (n : nat)
  | MV (x : nat)
  | Cell (a b : term).

Definition sub := list (nat * term).

Fixpoint teq (a b : term) : bool :=
  match a, b with
  | Atom n, Atom m => n =? m
  | MV x, MV y => x =? y
  | Cell a1 b1, Cell a2 b2 => andb (teq a1 a2) (teq b1 b2)
  | _, _ => false
  end.

Fixpoint sasq (v : nat) (s : sub) : option term :=
  match s with
  | [] => None
  | (k, t) :: r => if k =? v then Some t else sasq v r
  end.

Fixpoint mtch (p g : term) (s : sub) : option sub :=
  match p with
  | MV x => match sasq x s with
            | Some t => if teq t g then Some s else None
            | None => Some ((x, g) :: s)
            end
  | Atom n => match g with
              | Atom m => if n =? m then Some s else None
              | _ => None
              end
  | Cell a b => match g with
                | Cell ga gb => match mtch a ga s with
                                | Some s2 => mtch b gb s2
                                | None => None
                                end
                | _ => None
                end
  end.

Fixpoint inst (p : term) (s : sub) : term :=
  match p with
  | MV x => match sasq x s with Some t => t | None => MV x end
  | Atom n => Atom n
  | Cell a b => Cell (inst a s) (inst b s)
  end.

Lemma teq_eq : forall a b, teq a b = true -> a = b.
Proof.
  induction a; destruct b; simpl; intros H; try discriminate.
  - apply Nat.eqb_eq in H. now subst.
  - apply Nat.eqb_eq in H. now subst.
  - destruct (teq a1 b1) eqn:E1; [|discriminate]. simpl in H.
    now rewrite (IHa1 _ E1), (IHa2 _ H).
Qed.

(* bindings only GROW: what a match step bound stays bound, unchanged *)
Lemma mtch_mono : forall p g s s', mtch p g s = Some s' ->
  forall v t, sasq v s = Some t -> sasq v s' = Some t.
Proof.
  induction p; intros g s s' H v t A; simpl in H.
  - destruct g; try discriminate. destruct (n =? n0); [|discriminate].
    now injection H as <-.
  - destruct (sasq x s) eqn:E.
    + destruct (teq t0 g); [|discriminate]. now injection H as <-.
    + injection H as <-. simpl. destruct (x =? v) eqn:F; [|assumption].
      apply Nat.eqb_eq in F. subst. congruence.
  - destruct g; try discriminate.
    destruct (mtch p1 g1 s) eqn:E; [|discriminate].
    eapply IHp2; [eassumption|]. eapply IHp1; eassumption.
Qed.

(* MATCHING IS SOUND, under any extension of the bindings it produced --
   the strengthening that lets the Cell case ride mtch_mono. *)
Lemma mtch_sound_ext : forall p g s s' s2,
  mtch p g s = Some s' ->
  (forall v t, sasq v s' = Some t -> sasq v s2 = Some t) ->
  inst p s2 = g.
Proof.
  induction p; intros g s s' s2 H X; simpl in *.
  - destruct g; try discriminate.
    destruct (n =? n0) eqn:E; [|discriminate].
    apply Nat.eqb_eq in E. now subst.
  - destruct (sasq x s) eqn:E.
    + destruct (teq t g) eqn:T; [|discriminate].
      injection H as <-. apply teq_eq in T. subst.
      now rewrite (X x g E).
    + injection H as <-.
      assert (A : sasq x ((x, g) :: s) = Some g)
        by (simpl; now rewrite Nat.eqb_refl).
      now rewrite (X x g A).
  - destruct g; try discriminate.
    destruct (mtch p1 g1 s) eqn:E; [|discriminate].
    f_equal.
    + eapply IHp1; [exact E|]. intros v t A. apply X.
      eapply mtch_mono; eauto.
    + eapply IHp2; [exact H|]. exact X.
Qed.

Theorem mtch_sound : forall p g s',
  mtch p g [] = Some s' -> inst p s' = g.
Proof. intros p g s' H. eapply mtch_sound_ext; eauto. Qed.

(* the RE-AIM at address grain: the schematic swallow moves a deep patch's
   path from the variable's olds seat to its news seat -- prefix surgery,
   the rule itself riding unchanged. Swapping the seats back is home: the
   .l's L1 for the metavariable lane. *)
Definition reaim (a b p : list nat) : list nat := b ++ skipn (length a) p.

Theorem reaim_involutive : forall a b rest,
  reaim b a (reaim a b (a ++ rest)) = a ++ rest.
Proof.
  intros. unfold reaim. now rewrite !skipn_len_app.
Qed.

End MetaVar.

(* the axiom audit: every law closed under the global context -- no Axiom, no
   Admitted, no classical/funext escape hatch, in EITHER slice. *)
Print Assumptions commute_involutive.  (* L1, named slots *)
Print Assumptions invert_roundtrip.    (* L2, named slots *)
Print Assumptions commute_sound.       (* L3a, named slots *)
Print Assumptions aponl_swap.          (* L3b, named slots *)
Print Assumptions hcommute_involutive. (* L1, hunks -- the re-aim swaps home *)
Print Assumptions hinv_roundtrip.      (* L2, hunks -- in range, in context *)
Print Assumptions hcommute_sound.      (* L3a, hunks -- the shifted orders agree *)
Print Assumptions hfold_swap.          (* L3b, hunks -- the frontier tie *)
Print Assumptions pull_merge_comm.     (* M1, clash -- rivals land one cell *)
Print Assumptions pull_idem.           (* M2, clash -- pulling settles *)
Print Assumptions pull_records.        (* M3, clash -- base + both rivals kept *)
Print Assumptions pull_fold_swap.      (* M4, clash -- pull order is dead *)
Print Assumptions resolve_roundtrip.   (* M5, clash -- resolution unpulls *)
Print Assumptions fid_swap.            (* H1, identity -- order-free *)
Print Assumptions fid_dup.             (* H2, identity -- multiplicity-free *)
Print Assumptions swal_involutive.     (* L1, content-rewrite -- the swallow
                                          swaps home through the inverse *)
Print Assumptions scell_comm.          (* M1, clash segments -- the bubble
                                          forgets arrival order *)
Print Assumptions bubble_len.          (* the bubble law -- one seat, rival
                                          sizes nowhere in the length *)
Print Assumptions splice_pad.          (* the widening law -- padding commutes
                                          with rendering *)
Print Assumptions mtch_sound.          (* the unifier law -- a pattern
                                          instantiated with its own bindings
                                          reproduces the ground term *)
Print Assumptions reaim_involutive.    (* L1, metavariables -- the seat
                                          re-aim swaps home *)
Print Assumptions tcommute_involutive. (* L1, tree -- four lanes, path re-aim *)
