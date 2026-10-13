(* test/proof/rocq/gcsize.v -- the collector's SIZING, as numbers: how big the major pool
   gets. gc.v proves a collection loses nothing and copies once; this file is about space.

   The model is src/love/gc.c's sizing with no budget and every allocation granted:
     N  the nursery (g->len), which no rule here changes
     M  the major pool's size (g->major_len), U its occupancy (major_hp - major_base)
     K  the pool's step (g->major0)
   a collection is a major when the pool lacks room for a whole nursery's promotion
   (please: major_free < len + req0 + 16, req0 taken as 0), else a minor. a major sizes
   its to-space for the worst case, every word of the pool and the nursery surviving
   (gen_major: need = used + young; want = need + slack + need/4 + 16, slack = len + 16;
   rounded up to a whole step), and leaves the pool holding the survivors. a minor
   promotes what survives the nursery into the pool.

   The mutator is the adversary: its live set never passes L, and each minor promotes p
   words that are dead by the next major -- a frame's temporaries caught alive at a
   minor. Under it the pool grows at every major and without bound
   (current_policy_unbounded), though nothing it holds stays live: a major sizes the pool
   from its occupancy just before the copy, and the pool is only ever collected when that
   occupancy is within a nursery of all of it.

   Written by Claude (Anthropic), the Opus 5.5 model. *)

From Stdlib Require Import PeanoNat Lia Wf_nat Bool.

Record st := { N : nat; M : nat; U : nat }.

Section Sizing.
Variable K : nat.                     (* the step, love_major0 *)
Hypothesis K_pos : 0 < K.

(* the pool lacks room for a nursery's promotion: please's forcing test *)
Definition forced (s : st) : bool := M s <? U s + N s + 16.

(* gen_major's ask, the nursery full when the collection was asked for *)
Definition ceil_step (w : nat) : nat := (w + K - 1) / K * K.
Definition grown (s : st) : nat :=
  let need := U s + N s in Nat.max K (ceil_step (need + (N s + 16) + need / 4 + 16)).

(* one collection: a major keeps the L live words, a minor promotes p *)
Definition step (L p : nat) (s : st) : st :=
  if forced s then {| N := N s; M := grown s; U := L |}
  else {| N := N s; M := M s; U := U s + p |}.

Fixpoint iter (n : nat) (f : st -> st) (x : st) : st :=
  match n with 0 => x | S n' => iter n' f (f x) end.

Lemma iter_succ : forall n f x, iter (Datatypes.S n) f x = iter n f (f x).
Proof. reflexivity. Qed.

Lemma iter_add : forall a b f x, iter (a + b) f x = iter b f (iter a f x).
Proof. induction a; intros; simpl; auto. Qed.

Lemma ceil_step_ge : forall w, w <= ceil_step w.
Proof.
  intros w. unfold ceil_step.
  pose proof (Nat.div_mod (w + K - 1) K ltac:(lia)) as H.
  pose proof (Nat.mod_upper_bound (w + K - 1) K ltac:(lia)).
  rewrite Nat.mul_comm. lia.
Qed.

(* a major asks for more than the whole pool it collects: its ask starts from the
   occupancy, which forced puts within a nursery and 16 of M *)
Theorem major_grows : forall s, forced s = true -> M s < grown s.
Proof.
  intros s H. unfold forced in H. apply Nat.ltb_lt in H.
  unfold grown. pose proof (ceil_step_ge (U s + N s + (N s + 16) + (U s + N s) / 4 + 16)). lia.
Qed.

(* what the run keeps: the live words sit in the pool, the pool holds what it holds, the
   nursery stays the size it was *)
Definition inv (L N0 : nat) (s : st) : Prop := L <= U s /\ U s <= M s /\ N s = N0.

Lemma step_inv : forall L p N0 s, p <= N0 -> inv L N0 s -> inv L N0 (step L p s).
Proof.
  intros L p N0 s Hp [H1 [H2 H3]]. unfold step.
  destruct (forced s) eqn:F; unfold inv; simpl.
  - pose proof (major_grows s F). lia.
  - unfold forced in F. apply Nat.ltb_ge in F. lia.
Qed.

Lemma iter_inv : forall L p N0 n s, p <= N0 -> inv L N0 s -> inv L N0 (iter n (step L p) s).
Proof. induction n; intros; simpl; auto using step_inv. Qed.

(* the pool never shrinks: a minor keeps M, a major grows it *)
Lemma step_mono : forall L p s, M s <= M (step L p s).
Proof.
  intros. unfold step. destruct (forced s) eqn:F; simpl; auto.
  pose proof (major_grows s F). lia.
Qed.

(* from any state, a major comes: each minor closes the room left by p >= 1, so some
   later collection is forced, and it grows the pool *)
Lemma some_growth : forall L p N0 s, 1 <= p -> p <= N0 -> inv L N0 s ->
  exists k, M s < M (iter k (step L p) s).
Proof.
  intros L p N0 s Hp HpN Hi.
  remember (M s - U s) as gap eqn:Hg. revert s Hi Hg.
  induction gap as [gap IH] using lt_wf_ind. intros s Hi Hg.
  destruct (forced s) eqn:F.
  - exists 1. simpl. unfold step. rewrite F. simpl. apply major_grows. exact F.
  - assert (Hs : step L p s = {| N := N s; M := M s; U := U s + p |}).
    { unfold step. rewrite F. reflexivity. }
    destruct Hi as [H1 [H2 H3]]. unfold forced in F. apply Nat.ltb_ge in F.
    destruct (IH (M s - (U s + p)) ltac:(lia) {| N := N s; M := M s; U := U s + p |})
      as [k Hk]; [unfold inv; simpl; lia | simpl; reflexivity |].
    exists (Datatypes.S k). rewrite iter_succ, Hs. simpl in Hk. exact Hk.
Qed.

(* THE RATCHET: a mutator with at most L live words, any L, and a pool that passes every
   bound. nothing it promotes outlives a major, and the pool still grows at each one *)
Theorem current_policy_unbounded : forall L p N0 M0, 1 <= p -> p <= N0 -> L <= M0 ->
  forall B, exists n,
    B < M (iter n (step L p) {| N := N0; M := M0; U := L |}).
Proof.
  intros L p N0 M0 Hp HpN HL.
  set (s0 := {| N := N0; M := M0; U := L |}).
  assert (Hi0 : inv L N0 s0) by (unfold inv, s0; simpl; lia).
  assert (G : forall j, exists n, M s0 + j <= M (iter n (step L p) s0)).
  { induction j as [|j [n Hn]].
    - exists 0. simpl. lia.
    - destruct (some_growth L p N0 (iter n (step L p) s0) Hp HpN (iter_inv L p N0 n s0 HpN Hi0)) as [k Hk].
      exists (n + k). rewrite iter_add. lia. }
  intros B. destruct (G (Datatypes.S B)) as [n Hn]. exists n. lia.
Qed.

(* and the live set never passes L: every major leaves exactly L *)
Theorem current_policy_live_bounded : forall L p N0 M0 n, p <= N0 -> L <= M0 ->
  forall s, s = iter n (step L p) {| N := N0; M := M0; U := L |} -> L <= U s /\ N s = N0.
Proof.
  intros L p N0 M0 n HpN HL s ->.
  destruct (iter_inv L p N0 n {| N := N0; M := M0; U := L |} HpN ltac:(unfold inv; simpl; lia)) as [H1 [_ H3]].
  auto.
Qed.

End Sizing.

(* --- the same policy under a budget B: the pool climbs to the budget's share whatever
   the live set. the share is half of what the nursery leaves (major_share); at it the major
   comes a nursery early (at_share); an ask past the share takes the share in whole steps,
   or the tight size if that is more (gen_major's clamp); and a pool that holds the worst
   case keeps its size. the nursery is the adversary's to keep: its own rule leaves it while
   a minor's promotion stays under 1/ratio of it and the budget's nursery cap is above it ---
*)
Section Budget.
Variables K B n0 : nat.
Hypothesis K_pos : 0 < K.

Definition ceil_k (w : nat) : nat := (w + K - 1) / K * K.
Definition share (s : st) : nat := (B - N s) / 2.
Definition share_k (s : st) : nat := share s / K * K.
Definition early (s : st) : bool := B <? 2 * (M s + K) + n0.
Definition forcedb (s : st) : bool := M s <? U s + (if early s then 2 else 1) * N s + 16.
Definition needb (s : st) : nat := U s + N s.
Definition need_k (s : st) : nat := Nat.max K (ceil_k (needb s)).
Definition askb (s : st) : nat := Nat.max K (ceil_k (needb s + (N s + 16) + needb s / 4 + 16)).
Definition clamped (s : st) : nat :=
  if share s <? askb s then (if need_k s <? share s then share_k s else need_k s) else askb s.
Definition keptb (s : st) : nat :=
  if (needb s <=? M s) && (clamped s <? M s) then M s else clamped s.
Definition stepb (L p : nat) (s : st) : st :=
  if forcedb s then {| N := N s; M := keptb s; U := L |}
  else {| N := N s; M := M s; U := U s + p |}.

Lemma ceil_k_ge : forall w, w <= ceil_k w.
Proof.
  intros w. unfold ceil_k.
  pose proof (Nat.div_mod (w + K - 1) K ltac:(lia)) as H.
  pose proof (Nat.mod_upper_bound (w + K - 1) K ltac:(lia)).
  rewrite Nat.mul_comm. lia.
Qed.

Lemma share_k_le : forall s, share_k s <= share s.
Proof.
  intros s. unfold share_k. pose proof (Nat.div_mod (share s) K ltac:(lia)).
  rewrite Nat.mul_comm. lia.
Qed.

Lemma kept_ge : forall s, clamped s <= keptb s.
Proof. intros s. unfold keptb. destruct ((needb s <=? M s) && (clamped s <? M s)) eqn:E; [|lia].
  apply andb_true_iff in E as [_ E]. apply Nat.ltb_lt in E. lia. Qed.

(* a major below the share either grows the pool or takes it to the share *)
Lemma major_climbs : forall s, forcedb s = true -> M s < keptb s \/ share_k s <= keptb s.
Proof.
  intros s F. pose proof (kept_ge s).
  unfold forcedb in F. apply Nat.ltb_lt in F.
  assert (Ha : M s < askb s).
  { unfold askb, needb. pose proof (ceil_k_ge (U s + N s + (N s + 16) + (U s + N s) / 4 + 16)).
    destruct (early s); lia. }
  unfold clamped in H. destruct (share s <? askb s) eqn:E1.
  - destruct (need_k s <? share s) eqn:E2.
    + right. lia.
    + right. apply Nat.ltb_ge in E2. pose proof (share_k_le s). lia.
  - left. lia.
Qed.

Definition invb (L N0 : nat) (s : st) : Prop := L <= U s /\ U s <= M s /\ N s = N0.

Lemma kept_holds : forall L s, L <= U s -> L <= share_k s -> L <= keptb s.
Proof.
  intros L s H Hs. pose proof (kept_ge s). unfold clamped in H0.
  assert (L <= askb s) by (unfold askb, needb; pose proof (ceil_k_ge (U s + N s + (N s + 16) + (U s + N s) / 4 + 16)); lia).
  assert (L <= need_k s) by (unfold need_k, needb; pose proof (ceil_k_ge (U s + N s)); lia).
  destruct (share s <? askb s), (need_k s <? share s); lia.
Qed.

(* the share is the nursery's alone: a run that keeps the nursery keeps it *)
Definition sk (N0 : nat) : nat := (B - N0) / 2 / K * K.
Lemma share_k_sk : forall s, share_k s = sk (N s).
Proof. reflexivity. Qed.

Lemma stepb_inv : forall L p N0 s, p <= N0 -> L <= sk N0 -> invb L N0 s -> invb L N0 (stepb L p s).
Proof.
  intros L p N0 s Hp Hk [H1 [H2 H3]]. unfold stepb.
  destruct (forcedb s) eqn:F; unfold invb; simpl.
  - pose proof (kept_holds L s H1 ltac:(rewrite share_k_sk, H3; exact Hk)). lia.
  - unfold forcedb in F. apply Nat.ltb_ge in F. destruct (early s); lia.
Qed.

Lemma iterb_inv : forall L p N0 n s, p <= N0 -> L <= sk N0 -> invb L N0 s -> invb L N0 (iter n (stepb L p) s).
Proof. induction n; intros; simpl; auto using stepb_inv. Qed.

Lemma climb_some : forall L p N0 s, 1 <= p -> p <= N0 -> L <= sk N0 -> invb L N0 s ->
  exists k, M s < M (iter k (stepb L p) s) \/ sk N0 <= M (iter k (stepb L p) s).
Proof.
  intros L p N0 s Hp HpN Hk Hi.
  remember (M s - U s) as gap eqn:Hg. revert s Hi Hg.
  induction gap as [gap IH] using lt_wf_ind. intros s Hi Hg.
  destruct (forcedb s) eqn:F.
  - exists 1. simpl. unfold stepb. rewrite F. simpl.
    destruct Hi as [_ [_ H3]]. rewrite <- H3, <- share_k_sk. apply major_climbs. exact F.
  - assert (Hs : stepb L p s = {| N := N s; M := M s; U := U s + p |}).
    { unfold stepb. rewrite F. reflexivity. }
    destruct Hi as [H1 [H2 H3]]. unfold forcedb in F. apply Nat.ltb_ge in F.
    assert (U s + p <= M s) by (destruct (early s); lia).
    destruct (IH (M s - (U s + p)) ltac:(lia) {| N := N s; M := M s; U := U s + p |})
      as [k Hk']; [unfold invb; simpl; lia | simpl; reflexivity |].
    exists (Datatypes.S k). rewrite iter_succ, Hs. simpl in Hk'. exact Hk'.
Qed.

(* THE RATCHET UNDER A BUDGET: the pool reaches the budget's share, in whole steps, for
   every live set the share can hold -- however small *)
Theorem budget_ratchet : forall L p N0 M0, 1 <= p -> p <= N0 -> L <= sk N0 -> L <= M0 ->
  exists n, sk N0 <= M (iter n (stepb L p) {| N := N0; M := M0; U := L |}).
Proof.
  intros L p N0 M0 Hp HpN Hk HL.
  assert (G : forall d s, invb L N0 s -> sk N0 - M s = d ->
             exists n, sk N0 <= M (iter n (stepb L p) s)).
  { induction d as [d IH] using lt_wf_ind. intros s Hi Hd.
    destruct (Nat.le_gt_cases (sk N0) (M s)) as [Hle | Hgt].
    - exists 0. simpl. exact Hle.
    - destruct (climb_some L p N0 s Hp HpN Hk Hi) as [k [Hk1 | Hk2]].
      + destruct (IH (sk N0 - M (iter k (stepb L p) s)) ltac:(lia) (iter k (stepb L p) s)
                    (iterb_inv L p N0 k s HpN Hk Hi) eq_refl) as [n Hn].
        exists (k + n). rewrite iter_add. exact Hn.
      + exists k. exact Hk2. }
  apply (G (sk N0 - M0) {| N := N0; M := M0; U := L |}); [unfold invb; simpl; lia | reflexivity].
Qed.

(* ..and so the footprint, both halves and the nursery, comes within two steps of B *)
Theorem budget_footprint : forall N0 m, N0 <= B -> sk N0 <= m -> B <= 2 * m + N0 + 2 * K + 1.
Proof.
  intros N0 m HN H. unfold sk in H.
  pose proof (Nat.div_mod (B - N0) 2 ltac:(lia)). pose proof (Nat.mod_upper_bound (B - N0) 2 ltac:(lia)).
  pose proof (Nat.div_mod ((B - N0) / 2) K ltac:(lia)). pose proof (Nat.mod_upper_bound ((B - N0) / 2) K ltac:(lia)).
  rewrite Nat.mul_comm in H. lia.
Qed.

End Budget.

(* --- the new rule: the pool sized from what SURVIVED, not from what it held. a major
   copies into a to-space that holds the worst case, every word of the pool and the nursery
   surviving -- target of need, which is more than need -- and after the copy the pool is
   target of the survivors: the survivors, f = fn / fd of them again, and room for a
   nursery's promotion, in whole steps. the nursery may change size at a minor, to no more than
   max n0 (q V), q = qn / qd, V the last major's survivors, and only to a size whose promotion the
   pool still has room for. the mutator chooses every survivor count, promotion and
   nursery size the rules allow; its live set never passes L ---
*)
Record st2 := { N2 : nat; M2 : nat; U2 : nat; V2 : nat }.

Section New.
Variables K n0 qn qd fn fd : nat.
Hypothesis K_pos : 0 < K.
Hypothesis fd_pos : 0 < fd.
(* f = fn / fd: the room a major leaves past its survivors, as a share of them *)
Definition more (v : nat) : nat := v * fn / fd.
(* q = qn / qd: the nursery's ceiling, as a share of the survivors *)
Definition nurse (v : nat) : nat := v * qn / qd.

Definition ceil_n (w : nat) : nat := (w + K - 1) / K * K.
Definition target (n v : nat) : nat := Nat.max K (ceil_n (v + more v + n + 16)).
Definition forced2 (s : st2) : bool := M2 s <? U2 s + N2 s + 16.
Definition ncap (s : st2) : nat := Nat.max n0 (nurse (V2 s)).
(* the to-space a major copies into: the worst case's target *)
Definition to_space (s : st2) (young : nat) : nat := target (N2 s) (U2 s + young).

Inductive step2 (L : nat) : st2 -> st2 -> Prop :=
| major2 : forall s young v, forced2 s = true -> young <= N2 s -> v <= U2 s + young -> v <= L ->
    step2 L s {| N2 := N2 s; M2 := target (N2 s) v; U2 := v; V2 := v |}
| minor2 : forall s p n', forced2 s = false -> p <= N2 s ->
    (n' = N2 s \/ (n0 <= n' /\ n' <= ncap s /\ U2 s + p + n' + 16 <= M2 s)) ->
    step2 L s {| N2 := n'; M2 := M2 s; U2 := U2 s + p; V2 := V2 s |}.

Inductive reach (L : nat) (s0 : st2) : st2 -> Prop :=
| reach_0 : reach L s0 s0
| reach_1 : forall s s', reach L s0 s -> step2 L s s' -> reach L s0 s'.

Lemma ceil_n_ge : forall w, w <= ceil_n w.
Proof.
  intros w. unfold ceil_n.
  pose proof (Nat.div_mod (w + K - 1) K ltac:(lia)).
  pose proof (Nat.mod_upper_bound (w + K - 1) K ltac:(lia)).
  rewrite Nat.mul_comm. lia.
Qed.

Lemma ceil_n_le : forall w, ceil_n w < w + K.
Proof.
  intros w. unfold ceil_n.
  pose proof (Nat.div_mod (w + K - 1) K ltac:(lia)).
  pose proof (Nat.mod_upper_bound (w + K - 1) K ltac:(lia)).
  rewrite Nat.mul_comm. lia.
Qed.

Lemma ceil_n_mono : forall w w', w <= w' -> ceil_n w <= ceil_n w'.
Proof.
  intros w w' H. unfold ceil_n. apply Nat.mul_le_mono_r. apply Nat.Div0.div_le_mono; lia.
Qed.

Lemma more_mono : forall v v', v <= v' -> more v <= more v'.
Proof. intros. unfold more. apply Nat.Div0.div_le_mono. apply Nat.mul_le_mono_r. exact H. Qed.

Lemma nurse_mono : forall v v', v <= v' -> nurse v <= nurse v'.
Proof. intros. unfold nurse. apply Nat.Div0.div_le_mono. apply Nat.mul_le_mono_r. exact H. Qed.

Lemma target_mono : forall n n' v v', n <= n' -> v <= v' -> target n v <= target n' v'.
Proof.
  intros n n' v v' Hn Hv. unfold target.
  pose proof (more_mono v v' Hv).
  pose proof (ceil_n_mono (v + more v + n + 16) (v' + more v' + n' + 16) ltac:(lia)). lia.
Qed.

Lemma target_ge : forall n v, v + more v + n + 16 <= target n v.
Proof. intros. unfold target. pose proof (ceil_n_ge (v + more v + n + 16)). lia. Qed.

Lemma target_le : forall n v, target n v <= v + more v + n + 16 + K.
Proof. intros. unfold target. pose proof (ceil_n_le (v + more v + n + 16)). lia. Qed.

(* the bounds a run keeps, from its start *)
Definition Nb (L : nat) (s0 : st2) : nat := Nat.max (N2 s0) (Nat.max n0 (nurse L)).
Definition Mb (L : nat) (s0 : st2) : nat := Nat.max (M2 s0) (target (Nb L s0) L).

Definition inv2 (L : nat) (s0 s : st2) : Prop :=
  N2 s <= Nb L s0 /\ V2 s <= L /\ U2 s <= M2 s /\ M2 s <= Mb L s0.

Lemma step2_inv : forall L s0 s s', inv2 L s0 s -> step2 L s s' -> inv2 L s0 s'.
Proof.
  intros L s0 s s' [HN [HV [HU HM]]] St. inversion St; subst; unfold inv2; simpl.
  - pose proof (target_ge (N2 s) v). pose proof (target_mono (N2 s) (Nb L s0) v L HN H2).
    unfold Mb. lia.
  - unfold forced2 in H. apply Nat.ltb_ge in H.
    pose proof (nurse_mono (V2 s) L HV).
    unfold ncap, Nb in *. lia.
Qed.

(* BOUNDED: every state a run reaches keeps the nursery under Nb and the pool under Mb *)
Theorem new_policy_bounded : forall L s0 s, V2 s0 <= L -> U2 s0 <= M2 s0 ->
  reach L s0 s -> inv2 L s0 s.
Proof.
  intros L s0 s HV HU R. induction R.
  - unfold inv2, Mb, Nb. lia.
  - eapply step2_inv; eauto.
Qed.

(* ..so the footprint between collections, both halves of the pool and the nursery:
   2 (1 + f) L + 3 Nb and a few steps, from a start no bigger than that *)
Theorem new_policy_footprint : forall L s0 s, V2 s0 <= L -> U2 s0 <= M2 s0 ->
  M2 s0 <= target (Nb L s0) L -> reach L s0 s ->
  2 * M2 s + N2 s <= 2 * (L + more L) + 3 * Nb L s0 + 32 + 2 * K.
Proof.
  intros L s0 s HV HU HM R. destruct (new_policy_bounded L s0 s HV HU R) as [HN [_ [_ HMs]]].
  unfold Mb in HMs. pose proof (target_le (Nb L s0) L). lia.
Qed.

(* ..and the peak, during a major: the pool, the to-space beside it, and the nursery --
   the pool's bound Mb twice, f of it again, and a few nurseries and steps *)
Theorem new_policy_peak : forall L s0 s young, V2 s0 <= L -> U2 s0 <= M2 s0 ->
  M2 s0 <= target (Nb L s0) L -> reach L s0 s -> young <= N2 s ->
  M2 s + to_space s young + N2 s
    <= 2 * target (Nb L s0) L + more (target (Nb L s0) L + Nb L s0) + 3 * Nb L s0 + 16 + K.
Proof.
  intros L s0 s young HV HU HM R Hy.
  destruct (new_policy_bounded L s0 s HV HU R) as [HN [_ [HUs HMs]]].
  unfold Mb in HMs. unfold to_space.
  assert (Hm : M2 s <= target (Nb L s0) L) by lia.
  pose proof (target_le (N2 s) (U2 s + young)).
  pose proof (more_mono (U2 s + young) (target (Nb L s0) L + Nb L s0) ltac:(lia)).
  lia.
Qed.

(* the to-space holds the worst case: everything in the pool and the nursery *)
Lemma to_space_holds : forall s young, U2 s + young <= to_space s young.
Proof. intros. unfold to_space. pose proof (target_ge (N2 s) (U2 s + young)). lia. Qed.

(* NO THRASH: a major leaves room for f of its survivors and a nursery's promotion, so
   the collection after it is a minor -- majors never come back to back -- and with the
   nursery kept, the next major waits for f of the survivors to be promoted, so its copy
   of the survivors is paid for, 1/f a word for each word promoted since *)
Theorem new_policy_room : forall L s s', step2 L s s' -> forced2 s = true ->
  more (V2 s') + N2 s' + 16 <= M2 s' - U2 s'.
Proof.
  intros L s s' St F. destruct St as [s y v F1 Hy Hv HL | s p n' F1 Hp Hn].
  - pose proof (target_ge (N2 s) v). cbn [N2 M2 U2 V2]. lia.
  - rewrite F in F1. discriminate.
Qed.

Theorem new_policy_no_back_to_back : forall L s s', step2 L s s' -> forced2 s = true ->
  forced2 s' = false.
Proof.
  intros L s s' St F. pose proof (new_policy_room L s s' St F) as R.
  destruct St as [s y v F1 Hy Hv HL | s p n' F1 Hp Hn]; cbn [N2 M2 U2 V2] in *.
  - unfold forced2. cbn [N2 M2 U2 V2]. apply Nat.ltb_ge. pose proof (target_ge (N2 s) v). lia.
  - rewrite F in F1. discriminate.
Qed.

(* --- the lone block: no spare is held. a major makes its to-space then -- the worst case and
   a nursery's promotion past it, or the last survivors' target where that is more -- copies
   into it, and gives the old block back; the pool it leaves is the survivors' target, inside
   that block. between majors the one block; at a major the old block and the new one ---
*)
Record st4 := { N4 : nat; M4 : nat; P4 : nat; U4 : nat; V4 : nat }.

Definition forced4 (s : st4) : bool := M4 s <? U4 s + N4 s + 16.
Definition ncap4 (s : st4) : nat := Nat.max n0 (nurse (V4 s)).
(* the to-space a major makes: whole steps of the worst case and a promotion, or more *)
Definition to4 (s : st4) (young : nat) : nat :=
  Nat.max (ceil_n (U4 s + young + N4 s + 16)) (target (N4 s) (V4 s)).

Inductive step4 (L : nat) : st4 -> st4 -> Prop :=
| major4 : forall s young v, forced4 s = true -> young <= N4 s -> v <= U4 s + young -> v <= L ->
    step4 L s {| N4 := N4 s; M4 := Nat.min (target (N4 s) v) (to4 s young); P4 := to4 s young;
                 U4 := v; V4 := v |}
| minor4 : forall s p n', forced4 s = false -> p <= N4 s ->
    (n' = N4 s \/ (n0 <= n' /\ n' <= ncap4 s /\ U4 s + p + n' + 16 <= M4 s)) ->
    step4 L s {| N4 := n'; M4 := M4 s; P4 := P4 s; U4 := U4 s + p; V4 := V4 s |}.

Inductive reach4 (L : nat) (s0 : st4) : st4 -> Prop :=
| reach4_0 : reach4 L s0 s0
| reach4_1 : forall s s', reach4 L s0 s -> step4 L s s' -> reach4 L s0 s'.

Definition Nb4 (L : nat) (s0 : st4) : nat := Nat.max (N4 s0) (Nat.max n0 (nurse L)).
Definition Mb4 (L : nat) (s0 : st4) : nat := Nat.max (M4 s0) (target (Nb4 L s0) L).
(* a block: the pool's bound, two nurseries and a step past it, or the start's *)
Definition Pb4 (L : nat) (s0 : st4) : nat := Nat.max (P4 s0) (Mb4 L s0 + 2 * Nb4 L s0 + 16 + K).

Definition inv4 (L : nat) (s0 s : st4) : Prop :=
  N4 s <= Nb4 L s0 /\ V4 s <= L /\ U4 s <= M4 s /\ M4 s <= Mb4 L s0 /\ M4 s <= P4 s /\ P4 s <= Pb4 L s0.

Lemma to4_holds : forall s young, U4 s + young + N4 s + 16 <= to4 s young.
Proof. intros. unfold to4. pose proof (ceil_n_ge (U4 s + young + N4 s + 16)). lia. Qed.

Lemma to4_le : forall L s0 s young, inv4 L s0 s -> young <= N4 s -> to4 s young <= Pb4 L s0.
Proof.
  intros L s0 s young [HN [HV [HU [HM [HP HPb]]]]] Hy. unfold to4, Pb4.
  pose proof (ceil_n_le (U4 s + young + N4 s + 16)).
  pose proof (target_mono (N4 s) (Nb4 L s0) (V4 s) L HN HV). unfold Mb4 in *. lia.
Qed.

Lemma step4_inv : forall L s0 s s', inv4 L s0 s -> step4 L s s' -> inv4 L s0 s'.
Proof.
  intros L s0 s s' I St. pose proof I as I'. destruct I as [HN [HV [HU [HM [HP HPb]]]]].
  destruct St as [s y v F Hy Hv HL | s p n' F Hp Hn]; unfold inv4; cbn [N4 M4 P4 U4 V4].
  - pose proof (to4_le L s0 s y I' Hy). pose proof (to4_holds s y).
    pose proof (target_ge (N4 s) v). pose proof (target_mono (N4 s) (Nb4 L s0) v L HN HL).
    unfold Mb4 in *. lia.
  - unfold forced4 in F. apply Nat.ltb_ge in F.
    pose proof (nurse_mono (V4 s) L HV). unfold ncap4, Nb4 in *. lia.
Qed.

(* BOUNDED: the nursery, the pool and the block it sits in, every state a run reaches *)
Theorem lone_bounded : forall L s0 s, V4 s0 <= L -> U4 s0 <= M4 s0 -> M4 s0 <= P4 s0 ->
  reach4 L s0 s -> inv4 L s0 s.
Proof.
  intros L s0 s HV HU HP R. induction R.
  - unfold inv4, Pb4, Mb4, Nb4. lia.
  - eapply step4_inv; eauto.
Qed.

(* THE TO-SPACE HOLDS IT: the block a major makes takes the worst case *)
Theorem lone_holds : forall s young, U4 s + young <= to4 s young.
Proof. intros. pose proof (to4_holds s young). lia. Qed.

(* the footprint: between majors the one block and the nursery; at a major the old block, the
   new one and the nursery -- no third *)
Theorem lone_footprint : forall L s0 s, V4 s0 <= L -> U4 s0 <= M4 s0 -> M4 s0 <= P4 s0 ->
  reach4 L s0 s -> P4 s + N4 s <= Pb4 L s0 + Nb4 L s0.
Proof.
  intros L s0 s HV HU HP R. destruct (lone_bounded L s0 s HV HU HP R) as [HN [_ [_ [_ [_ HPb]]]]]. lia.
Qed.

Theorem lone_peak : forall L s0 s young, V4 s0 <= L -> U4 s0 <= M4 s0 -> M4 s0 <= P4 s0 ->
  reach4 L s0 s -> young <= N4 s -> P4 s + to4 s young + N4 s <= 2 * Pb4 L s0 + Nb4 L s0.
Proof.
  intros L s0 s young HV HU HP R Hy. pose proof (lone_bounded L s0 s HV HU HP R) as I.
  pose proof (to4_le L s0 s young I Hy). destruct I as [HN [_ [_ [_ [_ HPb]]]]]. lia.
Qed.

(* NO THRASH: a major leaves room for a nursery's promotion at least, so majors never come back
   to back; and f of the survivors besides wherever their target fits the block it made *)
Theorem lone_room : forall L s s', step4 L s s' -> forced4 s = true ->
  N4 s' + 16 <= M4 s' - U4 s' /\ (target (N4 s) (V4 s') <= P4 s' -> more (V4 s') + N4 s' + 16 <= M4 s' - U4 s').
Proof.
  intros L s s' St F. destruct St as [s y v F1 Hy Hv HL | s p n' F1 Hp Hn].
  - pose proof (target_ge (N4 s) v). pose proof (to4_holds s y). cbn [N4 M4 P4 U4 V4]. lia.
  - rewrite F in F1. discriminate.
Qed.

Theorem lone_no_back_to_back : forall L s s', step4 L s s' -> forced4 s = true ->
  forced4 s' = false.
Proof.
  intros L s s' St F. pose proof (lone_room L s s' St F) as [R _].
  destruct St as [s y v F1 Hy Hv HL | s p n' F1 Hp Hn]; cbn [N4 M4 P4 U4 V4] in *.
  - unfold forced4. cbn [N4 M4 P4 U4 V4]. apply Nat.ltb_ge. lia.
  - rewrite F in F1. discriminate.
Qed.

End New.

Print Assumptions current_policy_unbounded.
Print Assumptions current_policy_live_bounded.
Print Assumptions budget_ratchet.
Print Assumptions budget_footprint.
Print Assumptions new_policy_bounded.
Print Assumptions new_policy_footprint.
Print Assumptions new_policy_peak.
Print Assumptions new_policy_no_back_to_back.
Print Assumptions lone_bounded.
Print Assumptions lone_holds.
Print Assumptions lone_footprint.
Print Assumptions lone_peak.
Print Assumptions lone_no_back_to_back.
