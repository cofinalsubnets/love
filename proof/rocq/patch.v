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

   Still deliberately out (the next rungs): the TREE lift (a path per hunk), and
   CONFLICTORS -- the `None` branch of commute already models the partial merge,
   but the pushout/confluence law for the general structural case wants the
   rewrite/unifier machinery (wev, boxfix, kanren) and its own file. The full
   merge-as-pushout (L3 in the .l header) is that slice; the semantic core it
   rests on is proven below.

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
