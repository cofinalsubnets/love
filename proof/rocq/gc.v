(* proof/rocq/gc.v -- the generational MINOR is SOUND: under a complete write barrier,
   no live young object is lost.

   This is the Coq counterpart of doc/proto/gengc.l, the runnable ai model of the
   nursery+old collector. That model's load-bearing self-check is assert (3b): an
   old->young edge recorded WITHOUT the remembered-set entry lets a minor wrongly
   reap a live young object -- it reproduces, by construction, the exact bug a
   missing write barrier is. spec.l DEMONSTRATES; this file PROVES: the barrier is
   not just necessary on one example but sufficient in general -- if every old->young
   edge is remembered, the minor's nursery scan reaches every young object the
   mutator can reach (`barrier_sound`), so a young object the minor loses witnesses
   an INCOMPLETE barrier (`minor_loses_only_if_barrier_incomplete`, 3b's converse).

   The same split the rest of the tree uses: prove the MODEL here, keep the C
   connected by the differential oracle (the corpus runs byte-identical with the
   minor firing) and by gen_audit (0 unremembered edges across the corpus, the
   empirical form of rem_complete). A proof that love.c's pointer code REFINES this
   model is the larger separate effort doc/gengc.md flags.

   Universe-checked Rocq: the world does not explode here (cf. spec.v's preamble),
   so the theorems are unconditional.

   Written by Claude (Anthropic), the Opus 4.8 model. *)

From Stdlib Require Import List PeanoNat Bool.
Import ListNotations.

(* ============================================================ *)
(* the model -- mirrors doc/proto/gengc.l                       *)
(* ============================================================ *)

(* a heap object is (addr . out-edges): its identity and the addresses it points
   at. a REGION (the nursery, the old space) is a list of such objects. *)
Definition addr := nat.
Definition region := list (addr * list addr).

(* the out-edges of address [a] in region [r] -- the first object carrying that
   addr (bump allocation never reuses one, but first-match is total regardless). *)
Fixpoint edges (a : addr) (r : region) : list addr :=
  match r with
  | [] => []
  | (b, es) :: t => if Nat.eqb a b then es else edges a t
  end.

(* membership: [a] names an object in [r]. [present] is the Prop, [presentb] the
   boolean the Seeds list filters with. *)
Definition present (a : addr) (r : region) : Prop := In a (map fst r).
Definition presentb (a : addr) (r : region) : bool := existsb (Nat.eqb a) (map fst r).

(* reachability WITHIN a region's graph from a seed set: a seed is reached; an
   edge out of a reached object reaches its target. (an edge to an absent object
   is a dead end -- its [edges] are []. matches the proto's reach1.) *)
Inductive Reach (r : region) (seeds : list addr) : addr -> Prop :=
| R_seed : forall a, In a seeds -> Reach r seeds a
| R_step : forall a b, Reach r seeds a -> In b (edges a r) -> Reach r seeds b.

(* the MINOR's seeds (the proto's `young-roots`): the roots that point into the
   nursery, plus the young addresses held by a REMEMBERED old object. everything
   young not so reached is dead and is reclaimed. *)
Definition young_root (nur : region) (roots : list addr) : list addr :=
  filter (fun a => presentb a nur) roots.
Definition rem_young (nur old : region) (rem : list addr) : list addr :=
  flat_map (fun oa => filter (fun y => presentb y nur) (edges oa old)) rem.
Definition Seeds (nur old : region) (rem roots : list addr) : list addr :=
  young_root nur roots ++ rem_young nur old rem.

(* the WRITE-BARRIER invariant: every old->young edge has its source remembered.
   (gen_audit checks exactly this on the real heap; here it is the hypothesis.) *)
Definition rem_complete (nur old : region) (rem : list addr) : Prop :=
  forall a y, present a old -> In y (edges a old) -> present y nur -> In a rem.

(* the two regions hold disjoint addresses -- generation is read from the address
   (ai carries no per-object age bit), so an address is young XOR old. *)
Definition disjoint (nur old : region) : Prop :=
  forall a, present a nur -> ~ present a old.

(* ============================================================ *)
(* lemmas on edges / membership                                 *)
(* ============================================================ *)

Lemma presentb_present : forall a r, presentb a r = true <-> present a r.
Proof.
  intros a r. unfold presentb, present. rewrite existsb_exists. split.
  - intros [x [Hin Heq]]. apply Nat.eqb_eq in Heq. subst x. exact Hin.
  - intros Hin. exists a. split; [exact Hin | apply Nat.eqb_refl].
Qed.

(* an absent address has no edges *)
Lemma edges_absent : forall a r, ~ present a r -> edges a r = [].
Proof.
  intros a r. induction r as [| [b es] t IH]; intros Hnp.
  - reflexivity.
  - simpl. destruct (Nat.eqb a b) eqn:Hab.
    + apply Nat.eqb_eq in Hab. subst b. exfalso. apply Hnp. left. reflexivity.
    + apply IH. intro Hp. apply Hnp. right. exact Hp.
Qed.

(* ... so an outgoing edge witnesses the source is present *)
Lemma edges_present : forall a b r, In b (edges a r) -> present a r.
Proof.
  intros a b r Hin.
  destruct (in_dec Nat.eq_dec a (map fst r)) as [Hp | Hnp].
  - exact Hp.
  - rewrite (edges_absent a r Hnp) in Hin. inversion Hin.
Qed.

(* edges read past an append: the first matching object wins, so a present source
   resolves in the left region, an absent one falls through to the right. *)
Lemma edges_app_left : forall a r1 r2, present a r1 -> edges a (r1 ++ r2) = edges a r1.
Proof.
  intros a r1 r2. induction r1 as [| [b es] t IH]; intros Hp.
  - inversion Hp.
  - simpl. destruct (Nat.eqb a b) eqn:Hab.
    + reflexivity.
    + apply IH. unfold present in *. simpl in Hp.
      destruct Hp as [Heq | Hp].
      * apply Nat.eqb_neq in Hab. subst b. exfalso. apply Hab. reflexivity.
      * exact Hp.
Qed.

Lemma edges_app_right : forall a r1 r2, ~ present a r1 -> edges a (r1 ++ r2) = edges a r2.
Proof.
  intros a r1 r2. induction r1 as [| [b es] t IH]; intros Hnp.
  - reflexivity.
  - simpl. destruct (Nat.eqb a b) eqn:Hab.
    + apply Nat.eqb_eq in Hab. subst b. exfalso. apply Hnp. left. reflexivity.
    + apply IH. intro Hp. apply Hnp. right. exact Hp.
Qed.

(* ============================================================ *)
(* the theorem: a complete barrier loses no live young object   *)
(* ============================================================ *)

(* Under [rem_complete], every YOUNG address the mutator can reach in the whole
   heap (nur ++ old) from the roots is reached by the MINOR's nursery scan from
   [Seeds]. The minor promotes exactly the young objects in that scan, so this says
   no live young object is collected -- the barrier is SUFFICIENT, not merely
   necessary-on-one-example (3b). *)
Theorem barrier_sound :
  forall nur old rem roots,
    disjoint nur old ->
    rem_complete nur old rem ->
    forall y, present y nur ->
      Reach (nur ++ old) roots y ->
      Reach nur (Seeds nur old rem roots) y.
Proof.
  intros nur old rem roots Hdisj Hrem.
  (* generalize over every reached address, conditioned on its being young *)
  assert (H : forall a, Reach (nur ++ old) roots a ->
                        present a nur -> Reach nur (Seeds nur old rem roots) a).
  { intros a HR. induction HR as [a Hin | a b HRa IHa Hedge]; intros Hpres.
    - (* a is a seed root, and young -> it is a young_root, hence a Seed *)
      apply R_seed. unfold Seeds. apply in_or_app. left.
      unfold young_root. apply filter_In. split.
      + exact Hin.
      + apply presentb_present. exact Hpres.
    - (* edge a -> b with b young. split on a's generation. *)
      destruct (in_dec Nat.eq_dec a (map fst nur)) as [Hanur | Hanur].
      + (* a young: the edge lives in the nursery graph; step there via the IH *)
        rewrite (edges_app_left a nur old Hanur) in Hedge.
        eapply R_step.
        * apply IHa. exact Hanur.
        * exact Hedge.
      + (* a old: a->b is an old->young edge, so the barrier remembered a *)
        rewrite (edges_app_right a nur old Hanur) in Hedge.
        assert (Haold : present a old) by (eapply edges_present; exact Hedge).
        assert (Hain : In a rem) by (apply (Hrem a b); assumption).
        apply R_seed. unfold Seeds. apply in_or_app. right.
        unfold rem_young. apply in_flat_map. exists a. split.
        * exact Hain.
        * apply filter_In. split; [exact Hedge | apply presentb_present; exact Hpres].
  }
  intros y Hpres HR. apply H; assumption.
Qed.

(* The contrapositive -- exactly the lesson of the proto's assert (3b): if the
   minor LOSES a live young object (it is young, the mutator can reach it, yet the
   nursery scan misses it), the remembered set MUST have been incomplete -- some
   old->young edge went unrecorded. A correct barrier is the only thing standing
   between the generational minor and silent heap corruption. *)
Corollary minor_loses_only_if_barrier_incomplete :
  forall nur old rem roots y,
    disjoint nur old ->
    present y nur ->
    Reach (nur ++ old) roots y ->
    ~ Reach nur (Seeds nur old rem roots) y ->
    ~ rem_complete nur old rem.
Proof.
  intros nur old rem roots y Hdisj Hpres HR Hlost Hrc.
  apply Hlost. apply barrier_sound; assumption.
Qed.

(* axiom-free, like the rest of proof/rocq/: both results are closed under the global
   context (no Axiom, no Admitted, no classical/funext escape hatch). *)
Print Assumptions barrier_sound.
Print Assumptions minor_loses_only_if_barrier_incomplete.
