(* patch.v -- the patch groupoid: the hand-proven slices of test/patch.l's model.
   no Axiom, no Admitted, no classical or funext: trees are functions, so tree
   equality is pointwise (forall k) throughout. *)

From Stdlib Require Import PeanoNat List Lia.
Import ListNotations.

(* --- hunks and splice --- *)

(* a state is a sequence (nat stands in for a form); at hpos, hold becomes hnew *)

Record hunk := mkh { hpos : nat ; hold : list nat ; hnew : list nat }.

(* replace the c elements at i with n; total, validity pins the honest region *)
Definition splice (s : list nat) (i c : nat) (n : list nat) : list nat :=
  firstn i s ++ n ++ skipn (i + c) s.

(* --- splice algebra --- *)

Lemma firstn_len_app : forall (a b : list nat), firstn (length a) (a ++ b) = a.
Proof.
  intros. rewrite firstn_app, firstn_all, Nat.sub_diag. simpl. apply app_nil_r.
Qed.

Lemma skipn_len_app : forall (a b : list nat), skipn (length a) (a ++ b) = b.
Proof.
  intros. rewrite skipn_app, skipn_all, Nat.sub_diag. reflexivity.
Qed.

(* splice aimed exactly at a decomposed middle: the one computation rule *)
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

(* every sequence splits at (i, c) *)
Lemma seg_decompose : forall (s : list nat) i c,
  s = firstn i s ++ firstn c (skipn i s) ++ skipn (i + c) s.
Proof.
  intros. rewrite (Nat.add_comm i c), <- skipn_skipn.
  rewrite firstn_skipn, firstn_skipn. reflexivity.
Qed.
(* --- the conflictor slice: merge records a clash --- *)

(* a conflicted slot holds the shared base plus a canonical rival set *)

Inductive slot :=
  | Plain (v : nat)
  | Clash (base : nat) (rivals : list nat).

Definition stree := nat -> slot.

Record spatch := mks { sk : nat ; sa : slot ; sb : slot }.

(* the canonical rival set: sorted insert with dedup *)
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

(* a settled rival rejoins harmlessly *)
Lemma cins_absorb : forall x l, cins x (cins x l) = cins x l.
Proof.
  intros x l. induction l as [|h t IH]; simpl.
  - now rewrite Nat.eqb_refl.
  - destruct (Nat.eqb_spec x h) as [->|N].
    + simpl. now rewrite Nat.eqb_refl.
    + destruct (Nat.ltb_spec x h); creduce; [reflexivity|now rewrite IH].
Qed.

(* the one-slot merge; lane order mirrors the .l's pull *)
Definition merge1 (v old new : slot) : slot :=
  if slot_eqb v old then new
  else if slot_eqb v new then v
  else match v, old, new with
       | Clash base rs, Plain a, Plain b =>
           if base =? a then Clash a (cins b rs) else v
       | Plain w, Plain a, Plain b => Clash a (cins b [w])
       | _, _, _ => v
       end.

(* total merge-application; trusts every pulled patch to read the base or a rival *)
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

(* different slots never interact *)
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

(* --- (M1) merge is symmetric, from any starting slot --- *)

(* no hypothesis on v, so three-way convergence is this law twice *)
(* on literal rival lists everything reduces to nat comparisons *)
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
  - (* a plain slot *)
    destruct (Nat.eqb_spec w a) as [->|Nwa]; creduce; [cfin|].
    destruct (Nat.eqb_spec w b) as [->|Nwb]; creduce; [cfin|].
    destruct (Nat.eqb_spec w c) as [->|Nwc]; creduce; cfin.
  - (* a clash already open, or a breach no-op *)
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

(* --- (M2) pulling is idempotent --- *)

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
      * (* the freshly opened cell re-absorbs b *)
        cfin.
      * (* a joined set absorbs the repeat; a breach no-ops *)
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

(* --- (M3) a conflict records the base and both rivals --- *)

Theorem pull_records : forall t p q a b c, sk p = sk q ->
  sa p = Plain a -> sb p = Plain b -> sa q = Plain a -> sb q = Plain c ->
  t (sk p) = Plain a -> b <> a -> c <> b ->
  pull (pull t p) q (sk q) = Clash a (cins c [b]).
Proof.
  intros t p q a b c Hk Hap Hbp Haq Hbq Ht Hba Hcb.
  rewrite pull_at, <- Hk, pull_at, Ht, Hap, Hbp, Haq, Hbq.
  unfold merge1; simpl. rewrite Nat.eqb_refl. simpl. creduce. reflexivity.
Qed.

(* --- (M5) a resolution is just a patch --- *)

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

(* --- (M4) a frontier is stable under any adjacent swap --- *)

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

(* independent or rival, an adjacent swap never changes the merged tree *)
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

(* --- the identity slice: a version is its patch set --- *)

(* patch hashes folded through cins: forgets order and repetition, nothing more *)

Definition fid (hs : list nat) : list nat :=
  fold_left (fun acc h => cins h acc) hs [].

(* (H1) order-free *)
Theorem fid_swap : forall pre a b post,
  fid (pre ++ a :: b :: post) = fid (pre ++ b :: a :: post).
Proof.
  intros. unfold fid. rewrite !fold_left_app. cbn [fold_left].
  f_equal. apply cins_comm.
Qed.

(* (H2) multiplicity-free *)
Theorem fid_dup : forall pre a post,
  fid (pre ++ a :: a :: post) = fid (pre ++ a :: post).
Proof.
  intros. unfold fid. rewrite !fold_left_app. cbn [fold_left].
  f_equal. apply cins_absorb.
Qed.

(* --- the tree-lift slice: a hunk gets a path --- *)

(* a deep patch never changes an ancestor's length, so a shallow splice
   re-aims only the deeper patch's path component at the crossing *)

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

(* how two paths sit; d is the absolute index of the crossing component *)
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

(* re-aiming the crossing keeps the relation, with the new j... *)
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

(* ...and putting the original component back is the identity *)
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

(* (L1) tcommute is involutive, path re-aim included *)
Theorem tcommute_involutive : forall p q q' p',
  tcommute p q = Some (q', p') -> tcommute q' p' = Some (p, q).
Proof.
  intros [P ip o1 n1] [Q iq o2 n2] q' p' H.
  unfold tcommute in *; simpl in *.
  destruct (rel P Q 0) eqn:R.
  - (* Same: index arithmetic *)
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
  - (* InQ: q deeper *)
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
  - (* InP: mirror *)
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
  - (* Apart: untouched *)
    injection H as <- <-; simpl.
    rewrite (rel_apart_sym _ _ _ R). reflexivity.
Qed.

End TreeLift.

(* --- the content-rewrite slice: the swallow commutes, at element grain --- *)

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

(* dp ran first: undo it in both of sp's sides, re-aim dp in the news.
   guards: post state exactly once each side, pre state on neither *)
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

(* --- occurrence/replace lemmas --- *)

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

(* laying x over a non-x seat gains one x... *)
Lemma occ_lay_in : forall l k x u, nth_error l k = Some u -> u <> x ->
  occ x (lay l k x) = S (occ x l).
Proof.
  induction l as [|h t IH]; destruct k; simpl; intros x u H NE; try discriminate.
  - injection H as ->. destruct (Aeq x x); [|congruence].
    destruct (Aeq u x); [congruence|]. reflexivity.
  - destruct (Aeq h x); simpl; now rewrite (IH _ _ _ H NE).
Qed.

(* ...and laying non-x over an x seat loses one *)
Lemma occ_lay_out : forall l k x v, nth_error l k = Some x -> v <> x ->
  occ x l = S (occ x (lay l k v)).
Proof.
  induction l as [|h t IH]; destruct k; simpl; intros x v H NE; try discriminate.
  - injection H as ->. destruct (Aeq x x); [|congruence].
    destruct (Aeq v x); [congruence|]. reflexivity.
  - destruct (Aeq h x); simpl; now rewrite <- (IH _ _ _ H NE).
Qed.

(* where x occurs nowhere, laying it in pins ffind to the seat *)
Lemma ffind_lay : forall l k x, occ x l = 0 -> k < length l ->
  ffind x (lay l k x) = k.
Proof.
  induction l as [|h t IH]; destruct k; simpl; intros x H L; try lia.
  - destruct (Aeq x x); [auto|congruence].
  - destruct (Aeq h x) in H; [lia|].
    destruct (Aeq h x); [congruence|]. rewrite IH; lia.
Qed.

(* (L1) involutive through the groupoid inverse: the originals come home inverted *)
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

(* --- the clash-segments slice: overlapping hunks collapse their union hull
   to one clash cell, rivals cins-canonical by hash --- *)

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

(* (M1 at cell grain) the cell forgets which hunk came first *)
Theorem scell_comm : forall s0 p q, scell s0 p q = scell s0 q p.
Proof.
  intros s0 p q. unfold scell, ulo, uhi.
  rewrite (Nat.min_comm (hpos p) (hpos q)).
  rewrite (Nat.max_comm (hpos p + length (hold p))
                        (hpos q + length (hold q))).
  f_equal. apply cins_comm.
Qed.

(* padding commutes with rendering: a widened bubble is the wide hull rendered directly *)
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

(* the hull contracts to one seat: merged length has no rival size in it *)
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

(* --- the metavariable slice: matching is sound, the re-aim swaps home --- *)

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

(* bindings only grow *)
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

(* sound under any extension of its bindings, so the Cell case rides mtch_mono *)
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

(* move a deep patch's path from the olds seat to the news seat *)
Definition reaim (a b p : list nat) : list nat := b ++ skipn (length a) p.

Theorem reaim_involutive : forall a b rest,
  reaim b a (reaim a b (a ++ rest)) = a ++ rest.
Proof.
  intros. unfold reaim. now rewrite !skipn_len_app.
Qed.

End MetaVar.

(* --- the critical-pairs slice: two rules meet on one tree --- *)

(* kid reads are total, junk on non-cells; the match verdicts pin the honest region *)

Section RuleCommute.

Definition kida (t : term) : term := match t with Cell a _ => a | _ => t end.
Definition kidb (t : term) : term := match t with Cell _ b => b | _ => t end.

Fixpoint gsub (p : list bool) (g : term) : term :=
  match p with
  | [] => g
  | d :: r => gsub r (if d then kida g else kidb g)
  end.

Fixpoint gput (p : list bool) (g h : term) : term :=
  match p with
  | [] => h
  | d :: r => if d then Cell (gput r (kida g) h) (kidb g)
              else Cell (kida g) (gput r (kidb g) h)
  end.

(* get-put: the write lands where the read looks *)
Lemma gsub_put : forall p g h, gsub p (gput p g h) = h.
Proof.
  induction p as [|d r IH]; intros; simpl; [reflexivity|].
  destruct d; simpl; apply IH.
Qed.

(* a put on one side of a diverging seat leaves the other's read alone *)
Lemma gsub_put_ab : forall w ra rb g h,
  gsub (w ++ false :: rb) (gput (w ++ true :: ra) g h)
  = gsub (w ++ false :: rb) g.
Proof.
  induction w as [|d w IH]; intros; simpl; [reflexivity|].
  destruct d; simpl; auto.
Qed.

Lemma gsub_put_ba : forall w ra rb g h,
  gsub (w ++ true :: ra) (gput (w ++ false :: rb) g h)
  = gsub (w ++ true :: ra) g.
Proof.
  induction w as [|d w IH]; intros; simpl; [reflexivity|].
  destruct d; simpl; auto.
Qed.

(* diverging puts commute with no re-aim: tree addresses don't shift *)
Lemma gput_comm_div : forall w ra rb g x y,
  gput (w ++ false :: rb) (gput (w ++ true :: ra) g x) y
  = gput (w ++ true :: ra) (gput (w ++ false :: rb) g y) x.
Proof.
  induction w as [|d w IH]; intros; simpl; [reflexivity|].
  destruct d; simpl; now rewrite IH.
Qed.

(* a rule applies at a seat: match the lhs there, lay the rhs instantiated *)
Definition rw (l r : term) (p : list bool) (g : term) : option term :=
  match mtch l (gsub p g) [] with
  | Some s => Some (gput p g (inst r s))
  | None => None
  end.

Definition rw2 (l1 r1 : term) (p1 : list bool)
               (l2 r2 : term) (p2 : list bool) (g : term) : option term :=
  match rw l1 r1 p1 g with
  | Some g' => rw l2 r2 p2 g'
  | None => None
  end.

(* (L3a) diverging-seat rewrites are order-free *)
Theorem rw_comm_div : forall w ra rb l1 r1 l2 r2 g s1 s2,
  mtch l1 (gsub (w ++ true :: ra) g) [] = Some s1 ->
  mtch l2 (gsub (w ++ false :: rb) g) [] = Some s2 ->
  rw2 l1 r1 (w ++ true :: ra) l2 r2 (w ++ false :: rb) g
  = rw2 l2 r2 (w ++ false :: rb) l1 r1 (w ++ true :: ra) g.
Proof.
  intros w ra rb l1 r1 l2 r2 g s1 s2 H1 H2.
  unfold rw2, rw.
  rewrite H1, H2, gsub_put_ab, gsub_put_ba, H1, H2, gput_comm_div.
  reflexivity.
Qed.

(* one seat, two rules, both orders succeed and disagree: overlap must refuse *)
Theorem cp_earned :
  rw2 (MV 0) (Atom 1) [] (MV 0) (Atom 2) [] (Atom 0)
  <> rw2 (MV 0) (Atom 2) [] (MV 0) (Atom 1) [] (Atom 0).
Proof. discriminate. Qed.

End RuleCommute.

(* the axiom audit *)
Print Assumptions pull_merge_comm.     (* M1, clash *)
Print Assumptions pull_idem.           (* M2, clash *)
Print Assumptions pull_records.        (* M3, clash *)
Print Assumptions pull_fold_swap.      (* M4, clash *)
Print Assumptions resolve_roundtrip.   (* M5, clash *)
Print Assumptions fid_swap.            (* H1, identity *)
Print Assumptions fid_dup.             (* H2, identity *)
Print Assumptions swal_involutive.     (* L1, content-rewrite *)
Print Assumptions scell_comm.          (* M1, clash segments *)
Print Assumptions bubble_len.          (* bubble law *)
Print Assumptions splice_pad.          (* widening law *)
Print Assumptions mtch_sound.          (* matching is sound *)
Print Assumptions reaim_involutive.    (* L1, metavariables *)
Print Assumptions tcommute_involutive. (* L1, tree *)
Print Assumptions rw_comm_div.         (* L3a, critical pairs *)
Print Assumptions cp_earned.           (* the critical pair *)
