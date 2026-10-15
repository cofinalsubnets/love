(* spec.v -- the headline laws of test/spec.l, machine-checked: the combinator, numeral and
   absence core. universe-checked, so unlike uu's type-in-type these are unconditional. *)

From Stdlib Require Import PeanoNat List.
Import ListNotations.
(* the tower's big nat literals parse via of_num_uint; silence its warning *)
Set Warnings "-abstract-large-number".

(* --- the numeral lane: (n x) = x ** n --- *)

(* a numeral is an operator: applied to a value it raises it to the n *)

Definition app (n x : nat) : nat := Nat.pow x n.

(* (0 x) = 1 -- 0 is const-1 *)
Theorem const_one : forall x, app 0 x = 1.
Proof. intro x. apply Nat.pow_0_r. Qed.

(* (1 x) = x -- 1 is the identity *)
Theorem identity : forall x, app 1 x = x.
Proof. intro x. apply Nat.pow_1_r. Qed.

(* (0 0 x) = x -- const of const is the identity: ((0 0) x) = (1 x) = x *)
Theorem const_of_const : forall x, app (app 0 0) x = x.
Proof. intro x. unfold app. rewrite Nat.pow_0_r. apply Nat.pow_1_r. Qed.

(* (3 2) = 8 -- (n x) = x ** n *)
Theorem pow_3_2 : app 3 2 = 8.
Proof. reflexivity. Qed.

(* (2 3 4) = 262144 -- the tower 4 ** (3 ** 2), left-associated *)
Theorem tower : app (app 2 3) 4 = 262144.
Proof. reflexivity. Qed.

(* (2 2 2 2) = 65536 -- tetration *)
Theorem tetration : app (app (app 2 2) 2) 2 = 65536.
Proof. reflexivity. Qed.

(* --- the function lane: (n f) iterates f n times --- *)

(* the same numeral applied to a function composes it n times; x ** n is its numeral face *)

Definition appf {A} (n : nat) (f : A -> A) : A -> A := fun x => Nat.iter n f x.

(* (2 f x) = f (f x) -- church two *)
Theorem church_two : forall (A:Type) (f:A->A) (x:A), appf 2 f x = f (f x).
Proof. reflexivity. Qed.

(* (3 (+ 1) 9) = 12 -- iterate the successor three times *)
Theorem inc_three : appf 3 S 9 = 12.
Proof. reflexivity. Qed.

(* the lanes agree: iterating multiply-by-x n times on 1 is x ** n *)
Theorem lanes_agree : forall n x, app n x = appf n (Nat.mul x) 1.
Proof.
  intros n x. unfold app, appf.
  induction n as [|n IH]; [reflexivity|].
  simpl. rewrite IH. reflexivity.
Qed.

(* --- currying and the empty form --- *)

(* application is left-associative, and (f) = f *)

Fixpoint spine (f : nat) (xs : list nat) : nat :=
  match xs with
  | []       => f
  | x :: xs' => spine (app f x) xs'
  end.

(* (f) = f -- the empty form reads its head *)
Theorem empty_form : forall f, spine f [] = f.
Proof. reflexivity. Qed.

(* f x y = (f x) y -- currying is left-to-right application *)
Theorem curry : forall f x y, spine f [x; y] = app (app f x) y.
Proof. reflexivity. Qed.

(* --- the zero point as a unit --- *)

(* an unbound name reads as the zero point Pt: const-1 as operator, absorbing as a base.
   vapp is total. *)

Inductive value := Num (n : nat) | Cx | Pt.   (* Cx stands in for i: numeric, not a nat numeral *)

Definition vapp (f a : value) : value :=
  match f, a with
  | Pt,    _      => Num 1                 (* the unit as operator: const-1 *)
  | Num _, Pt     => Pt                    (* the unit absorbs as a numeral's base *)
  | Cx,    Pt     => Pt                    (* ... i included *)
  | Num n, Num x  => Num (Nat.pow x n)     (* (n x) = x ** n, agreeing with `app` *)
  | Cx,    Num _  => Cx                    (* i applied to a numeral stays in the complex lane *)
  | Cx,    Cx     => Cx
  | Num _, Cx     => Cx
  end.

(* the unit as operator is const-1, like 0 *)
Theorem unit_is_const_one : forall a, vapp Pt a = Num 1.
Proof. reflexivity. Qed.

(* () (Pt) is distinct from 0 (Num 0), though both net 0 *)
Theorem unit_neq_zero : Pt <> Num 0.
Proof. discriminate. Qed.

(* --- totality --- *)

(* vapp is total by exhaustive match: no error constructor, no stuck state *)
Theorem total : forall f a, exists v, vapp f a = v.
Proof. intros f a. exists (vapp f a). reflexivity. Qed.

(* --- true and false: the net measure and its saturation --- *)

(* false is nothing: net <= 0. the real fragment, net : V -> Z; a link nets car + cdr,
   so a dotted tail counts. the complex net is further down. *)

From Stdlib Require Import ZArith Lia Permutation.
Open Scope Z_scope.

Inductive V := Vnum (z : Z) | Vnil | Vcons (a b : V).

Fixpoint net (v : V) : Z :=
  match v with
  | Vnum z              => z
  | Vnil                => 0
  | Vcons a b           => net a + net b    (* every link: the car and the cdr *)
  end.

(* the charm ceiling: a net that will not fit lands on the edge. 2^62-1 is the 64-bit
   width; the laws hold at any width, only the literal moves. *)
Definition maxcharm : Z := 2^62 - 1.
Theorem maxcharm_pos : 0 < maxcharm.  Proof. reflexivity. Qed.

(* $ (sat): clamp to [0, maxcharm]; an integer net makes ceil the identity *)
Definition satZ (n : Z) : Z := Z.min maxcharm (Z.max 0 n).
Definition sat (v : V) : Z := satZ (net v).
(* ! (nilp): false is nothing -- net <= 0. *)
Definition nilp (v : V) : bool := net v <=? 0.
(* !! : the truth bit -- positive green, net > 0. *)
Definition tru (v : V) : bool := 0 <? net v.

(* the invariant  !x == (0 = $x) *)
Theorem nilp_iff_sat0 : forall v, nilp v = (sat v =? 0).
Proof.
  intro v. unfold nilp, sat, satZ. pose proof maxcharm_pos as Hc.
  destruct (net v <=? 0) eqn:H.
  - apply Z.leb_le in H. symmetry. apply Z.eqb_eq. lia.
  - apply Z.leb_gt in H. symmetry. apply Z.eqb_neq. lia.
Qed.

(* $ is nonnegative, keeps a net that fits, and clamps at both ends *)
Theorem sat_nonneg : forall v, 0 <= sat v.
Proof. intro v. unfold sat, satZ. pose proof maxcharm_pos. lia. Qed.
Theorem sat_keeps  : forall v, 0 < net v -> net v <= maxcharm -> sat v = net v.
Proof. intros v H H2. unfold sat, satZ. lia. Qed.
Theorem sat_ceils  : forall v, maxcharm <= net v -> sat v = maxcharm.
Proof. intros v H. unfold sat, satZ. pose proof maxcharm_pos. lia. Qed.

(* () and 0 are distinct values, both nothing *)
Theorem nil_nothing  : nilp Vnil = true.        Proof. reflexivity. Qed.
Theorem zero_nothing : nilp (Vnum 0) = true.    Proof. reflexivity. Qed.
Theorem nil_neq_zero : Vnil <> Vnum 0.          Proof. discriminate. Qed.
Theorem sat_clamps  : forall v, net v <= 0 -> sat v = 0.
Proof. intros v H. unfold sat, satZ. pose proof maxcharm_pos. lia. Qed.

(* colours by the sign of the real net: green >= 0, red < 0, blue = 0; green and blue
   overlap at 0 *)
Definition green (v : V) := 0 <= net v.
Definition red   (v : V) := net v < 0.
Definition blue  (v : V) := net v = 0.

Theorem blue_is_green     : forall v, blue v -> green v.        Proof. unfold blue, green. lia. Qed.
Theorem green_or_red      : forall v, green v \/ red v.         Proof. intro v. unfold green, red. lia. Qed.
Theorem green_red_disjoint : forall v, ~ (green v /\ red v).    Proof. intro v. unfold green, red. lia. Qed.
(* truth is POSITIVE green: above the blue floor *)
Theorem truth_is_positive_green : forall v, tru v = true <-> (green v /\ net v <> 0).
Proof. intro v. unfold tru, green. rewrite Z.ltb_lt. lia. Qed.

(* the spine measure: a proper list nets the sum of its elements' nets *)
Definition vlist (xs : list V) : V := fold_right Vcons Vnil xs.
Fixpoint netl (xs : list V) : Z := match xs with nil => 0 | x :: xs => net x + netl xs end.

Lemma net_vlist : forall xs, net (vlist xs) = netl xs.
Proof.
  induction xs as [|x xs IH]; [reflexivity|].
  destruct xs as [|y ys].
  - simpl. lia.
  - change (vlist (x :: y :: ys)) with (Vcons x (vlist (y :: ys))).
    change (net (Vcons x (vlist (y :: ys)))) with (net x + net (vlist (y :: ys))).
    rewrite IH. reflexivity.
Qed.

(* + is the measure homomorphism: net distributes over append *)
Theorem netl_app : forall xs ys, netl (xs ++ ys) = netl xs + netl ys.
Proof. induction xs as [|x xs IH]; intro ys; simpl; [reflexivity | rewrite IH; lia]. Qed.

Theorem net_homomorphism : forall xs ys,
  net (vlist (xs ++ ys)) = net (vlist xs) + net (vlist ys).
Proof. intros xs ys. rewrite !net_vlist. apply netl_app. Qed.

(* the concrete corpus computations *)
Theorem sat_123    : sat (vlist [Vnum 1; Vnum 2; Vnum 3]) = 6.  Proof. reflexivity. Qed. (* $'(1 2 3) *)
Theorem sat_dotted : sat (Vcons (Vnum 1) (Vnum 2)) = 3.          Proof. reflexivity. Qed. (* $(cons 1 2) -- the tail counts *)
Theorem sat_dotted3 : sat (Vcons (Vnum 1) (Vcons (Vnum 2) (Vnum 3))) = 6.  Proof. reflexivity. Qed.
Theorem nil_dotted : nilp (Vcons (Vnum 0) (Vnum 2)) = false.     Proof. reflexivity. Qed. (* !(cons 0 2) -- a live tail is content *)
Theorem nothings   : nilp (vlist [Vnil; Vnil]) = true.           Proof. reflexivity. Qed. (* a product of nothings is nothing *)
Theorem net_red    : net (vlist [Vnum (-2); Vnum 1]) = -1.       Proof. reflexivity. Qed. (* +'(-2 1) -- the net is unclamped *)
Theorem red_red    : red (vlist [Vnum (-2); Vnum 1]).            Proof. reflexivity. Qed. (* ... and red *)
Theorem blue_zero  : blue (Vnum 0).                              Proof. reflexivity. Qed.

(* --- order and equality: < is a total order --- *)

(* < is a total order: bands symbol < string < number < product < map < top, one key per
   band, = its eq cell. 3 and 3.0 are one Onum; idp is not modeled. *)

Inductive O :=
  | Onum (z : Z) | Ostr (z : Z) | Osym (z : Z)
  | Oprod (z : Z) | Omap (z : Z) | Otop (z : Z).

(* the symbol band is the floor, so a point sits below every number *)
Definition band (o : O) : Z :=
  match o with Osym _ => 0 | Ostr _ => 1 | Onum _ => 2
             | Oprod _ => 3 | Omap _ => 4 | Otop _ => 5 end.
Definition key (o : O) : Z :=
  match o with Onum z | Ostr z | Osym z | Oprod z | Omap z | Otop z => z end.

(* the order, lexicographic on (band, key) -- band across kinds, key within *)
Definition lt (a b : O) : Prop := band a < band b \/ (band a = band b /\ key a < key b).
Definition le (a b : O) : Prop := lt a b \/ a = b.

(* band and key together pin a value down: Eq is genuine equality *)
Lemma eq_from_band_key : forall a b, band a = band b -> key a = key b -> a = b.
Proof. intros a b Hb Hk. destruct a, b; cbn in Hb, Hk; try discriminate Hb; f_equal; lia. Qed.

(* < is a STRICT total order: irreflexive, transitive, asymmetric, trichotomous *)
Theorem lt_irrefl : forall a, ~ lt a a.
Proof. intro a. unfold lt. lia. Qed.

Theorem lt_trans : forall a b c, lt a b -> lt b c -> lt a c.
Proof. intros a b c. unfold lt. intros [H1|[H1a H1b]] [H2|[H2a H2b]]; lia. Qed.

Theorem lt_asym : forall a b, lt a b -> ~ lt b a.
Proof. intros a b. unfold lt. intros [H1|[H1a H1b]] [H2|[H2a H2b]]; lia. Qed.

Theorem lt_trichotomy : forall a b, lt a b \/ a = b \/ lt b a.
Proof.
  intros a b. unfold lt.
  destruct (Z.lt_trichotomy (band a) (band b)) as [Hb|[Hb|Hb]].
  - left. left. exact Hb.
  - destruct (Z.lt_trichotomy (key a) (key b)) as [Hk|[Hk|Hk]].
    + left.  right. split; assumption.
    + right. left.  apply eq_from_band_key; assumption.
    + right. right. right. split; [lia | exact Hk].
  - right. right. left. exact Hb.
Qed.

(* <= is a (non-strict) total order: reflexive, transitive, antisymmetric, total *)
Theorem le_refl : forall a, le a a.
Proof. intro a. right. reflexivity. Qed.

Theorem le_trans : forall a b c, le a b -> le b c -> le a c.
Proof.
  intros a b c [H1|H1] [H2|H2]; subst; unfold le; auto.
  left. eapply lt_trans; eassumption.
Qed.

Theorem le_antisym : forall a b, le a b -> le b a -> a = b.
Proof.
  intros a b [H1|H1] [H2|H2]; subst; auto.
  exfalso. eapply lt_asym; eassumption.
Qed.

Theorem le_total : forall a b, le a b \/ le b a.
Proof.
  intros a b. destruct (lt_trichotomy a b) as [H|[H|H]].
  - left.  left. exact H.
  - left.  right. exact H.
  - right. left. exact H.
Qed.

(* the LATTICE: the band chain symbol < string < number < product < map < top *)
Theorem symbol_lt_string  : forall x y, lt (Osym x)  (Ostr y).  Proof. intros. left. cbn. lia. Qed.
Theorem string_lt_number  : forall x y, lt (Ostr x)  (Onum y).  Proof. intros. left. cbn. lia. Qed.
Theorem number_lt_product : forall x y, lt (Onum x)  (Oprod y). Proof. intros. left. cbn. lia. Qed.
Theorem product_lt_map    : forall x y, lt (Oprod x) (Omap y).  Proof. intros. left. cbn. lia. Qed.
Theorem map_lt_top        : forall x y, lt (Omap x)  (Otop y).  Proof. intros. left. cbn. lia. Qed.

(* () is a floor mint, strictly below the number 0 *)
Theorem unit_lt_zero : forall z, lt (Osym z) (Onum 0).  Proof. intros. left. cbn. lia. Qed.

(* --- comparing functions: = is alpha + structural --- *)

(* `=` on functions is alpha-equivalence: syntactic under de bruijn, so decidable. it never
   chases general beta or eta; a closure value already carries the one beta ev ran. *)

Open Scope nat_scope.
Inductive tm := Var (n : nat) | Lam (b : tm) | App (f a : tm).

Definition tm_one  : tm := Lam (Var 0).          (* (\ x x)     -- the identity *)
Definition tm_zero : tm := Lam (Lam (Var 0)).    (* (\ _ (\ x x)) = (\ _ 1) -- const-1 *)
Definition tm_plus : tm := Var 7.                (* a free operator, e.g. + *)

(* alpha-equivalence is decidable structural equality *)
Theorem alpha_dec : forall s t : tm, {s = t} + {s <> t}.
Proof. decide equality; apply Nat.eq_dec. Qed.

(* (\ x x) = (\ y y) -- alpha: bound vars by position *)
Theorem id_alpha : Lam (Var 0) = tm_one.
Proof. reflexivity. Qed.

(* (\ a b (+ a b)) = (\ x y (+ x y)) -- same de Bruijn skeleton *)
Theorem binders_by_position :
  Lam (Lam (App (App tm_plus (Var 1)) (Var 0)))
  = Lam (Lam (App (App tm_plus (Var 1)) (Var 0))).
Proof. reflexivity. Qed.

(* !((\ x x) = (\ y z)) -- a free var (Var 1) /= a bound one (Var 0) *)
Theorem free_neq_bound : tm_one <> Lam (Var 1).
Proof. discriminate. Qed.

(* const-1's body is the identity term (a term fact: runtime = never bridges a numeral) *)
Theorem zero_is_const_one : tm_zero = Lam tm_one.
Proof. reflexivity. Qed.
Theorem zero_ne_const_two : tm_zero <> Lam (Lam (Lam (Var 0))).
Proof. discriminate. Qed.
Theorem one_ne_zero : tm_one <> tm_zero.
Proof. discriminate. Qed.

(* eta is NOT bridged: (\ x (f x)) /= f *)
Theorem eta_not_bridged : Lam (App tm_plus (Var 0)) <> tm_plus.
Proof. discriminate. Qed.

(* --- reduction: what `ev` runs, not what `=` observes --- *)
(* de bruijn beta+eta, what ev runs; each theorem has a twin in test/spec.l. the examples
   close by computation, so an off-by-one in subst cannot typecheck. *)

Fixpoint shift (d c : nat) (t : tm) : tm :=
  match t with
  | Var k   => if Nat.ltb k c then Var k else Var (k + d)
  | Lam b   => Lam (shift d (S c) b)
  | App f a => App (shift d c f) (shift d c a)
  end.

Fixpoint subst (j : nat) (s t : tm) : tm :=
  match t with
  | Var k   => if Nat.eqb k j then s
               else if Nat.ltb k j then Var k else Var (k - 1)
  | Lam b   => Lam (subst (S j) (shift 1 0 s) b)
  | App f a => App (subst j s f) (subst j s a)
  end.

(* single-step beta+eta with full congruence -- the one-step rewrite ev runs *)
Inductive step : tm -> tm -> Prop :=
  | st_beta : forall b a, step (App (Lam b) a) (subst 0 a b)
  | st_eta  : forall f,   step (Lam (App (shift 1 0 f) (Var 0))) f
  | st_app1 : forall f f' a, step f f' -> step (App f a) (App f' a)
  | st_app2 : forall f a a', step a a' -> step (App f a) (App f a')
  | st_lam  : forall b b',   step b b' -> step (Lam b) (Lam b').

Inductive steps : tm -> tm -> Prop :=
  | sn_refl : forall t, steps t t
  | sn_step : forall a b c, step a b -> steps b c -> steps a c.

(* (\ x x) a ~> a -- beta on the identity, for ANY argument (spec.l: ((\ x x) 5)) *)
Theorem beta_id : forall a, step (App tm_one a) a.
Proof. intro a. exact (st_beta (Var 0) a). Qed.

(* (\ _ 1) a ~> 1 -- const-1 drops its argument (spec.l: ((\ _ 1) 9) ; up to alpha) *)
Theorem beta_const : forall a, step (App tm_zero a) tm_one.
Proof. intro a. exact (st_beta (Lam (Var 0)) a). Qed.

(* the beta bridge closure `=` observes: a held redex equals its contractum, one st_beta *)
Theorem closure_beta_bridge : forall b a, step (App (Lam b) a) (subst 0 a b).
Proof. intros. apply st_beta. Qed.

(* nested: (\ x x) ((\ x x) a) ~>* a -- the closure reduces all the way down *)
Theorem beta_nested : forall a, steps (App tm_one (App tm_one a)) a.
Proof.
  intro a.
  eapply sn_step. exact (st_beta (Var 0) (App tm_one a)).
  eapply sn_step. apply beta_id.
  apply sn_refl.
Qed.

(* the eta-reduct is Var 6, not Var 7: reduction cannot collapse them either *)
Theorem eta_redex_shifts : step (Lam (App (Var 7) (Var 0))) (Var 6).
Proof. exact (st_eta (Var 6)). Qed.

(* --- + and * are generic: the sequence monoid and repetition --- *)

(* + on sequences is the concatenation monoid; a point is +'s identity in every lane and *'s
   annihilating zero; * is repeated + by |count|; mixed-band + degenerates. *)

Open Scope Z_scope.

(* + as concatenation: the sequence monoid (assoc + identity) *)
Theorem cat_assoc : forall (A:Type) (x y z : list A), (x ++ y) ++ z = x ++ (y ++ z).
Proof. intros A x y z. induction x as [|a x IH]; simpl; [reflexivity | rewrite IH; reflexivity]. Qed.
Theorem cat_nil_l : forall (A:Type) (x : list A), [] ++ x = x.  Proof. reflexivity. Qed.
Theorem cat_nil_r : forall (A:Type) (x : list A), x ++ [] = x.
Proof. intros A x. induction x as [|a x IH]; simpl; [reflexivity | rewrite IH; reflexivity]. Qed.

(* "ab"+"cd"="abcd"; '(1 2)+'(3 4)='(1 2 3 4) *)
Theorem cat_strings : [97;98] ++ [99;100] = [97;98;99;100].    Proof. reflexivity. Qed.
Theorem cat_lists   : [1;2] ++ [3;4] = ([1;2;3;4] : list Z).    Proof. reflexivity. Qed.

(* * as repeated +: n copies concatenated *)
Definition srep {A} (n : nat) (s : list A) : list A := concat (repeat s n).

(* * IS repeated +: one more copy is one more concatenation *)
Theorem star_is_repeated_plus : forall (A:Type) (n:nat) (s:list A), srep (S n) s = s ++ srep n s.
Proof. intros. unfold srep. reflexivity. Qed.

(* an exact count acts by |count|, so smul is a monoid action of multiplicative Z *)
Definition mcount (c : Z) : nat := Z.abs_nat c.
Definition smul {A} (c : Z) (s : list A) : list A := srep (mcount c) s.

Theorem star_ab_3   : smul 3 [97;98] = [97;98;97;98;97;98].     Proof. reflexivity. Qed. (* "ab"*3 *)
Theorem star_list_2 : smul 2 [1;2] = ([1;2;1;2] : list Z).      Proof. reflexivity. Qed. (* '(1 2)*2 *)
Theorem star_neg    : smul (-3) [97;98] = [97;98;97;98;97;98].  Proof. reflexivity. Qed. (* "ab"*-3: |−3| copies *)
Theorem star_zero   : forall (A:Type) (s:list A), smul 0 s = [].     Proof. reflexivity. Qed. (* '(1 2)*0 = () *)
(* *'s identity is 1; 0 empties the kind and () annihilates *)
Theorem smul_one    : forall (A:Type) (s:list A), smul 1 s = s.
Proof. intros A s. unfold smul, srep, mcount. simpl. apply app_nil_r. Qed.

(* the action law: smul is a hom from multiplicative Z, which makes mixed * associate *)
Lemma srep_mult : forall (A:Type) (a b:nat) (s:list A), srep (a * b) s = srep a (srep b s).
Proof. intros A a b s. unfold srep. induction a as [|a IH]; simpl.
  reflexivity. rewrite repeat_app, concat_app, IH. reflexivity. Qed.
Theorem smul_hom : forall (A:Type) (a b:Z) (s:list A), smul (a * b) s = smul a (smul b s).
Proof. intros A a b s. unfold smul, mcount. rewrite Zabs2Nat.inj_mul. apply srep_mult. Qed.

(* () is +'s identity and *'s zero. mixed bands degenerate under +, which buys associativity
   over the whole carrier; sequence * sequence is the cartesian product. *)
(* a point is GNom n, n its seat in love's order; () is the mint of serial 0, GNom 0 *)
Inductive gval := GNum (z : Z) | GSeq (xs : list gval) | GNom (n : nat).
Definition GUnit := GNom 0.

Definition gplus (a b : gval) : gval :=
  match a, b with
  | GNom m,  GNom n  => GNom (Nat.max m n)          (* two points join: the greater stands *)
  | GNom _,  _       => b                           (* a point is the identity in every lane *)
  | _,       GNom _  => a
  | GNum m,  GNum n  => GNum (m + n)
  | GSeq xs, GSeq ys => GSeq (xs ++ ys)
  | GNum _,  GSeq ys => GSeq ys                    (* DEGENERATE: 5 + '(1 2) = '(1 2) *)
  | GSeq xs, GNum _  => GSeq xs
  end.

Definition gtimes (a b : gval) : gval :=
  match a, b with
  | GNom _,  _       => GUnit                      (* a point is absent under *: the zero annihilates *)
  | _,       GNom _  => GUnit
  | GNum m,  GNum n  => GNum (m * n)
  | GNum n,  GSeq ys => GSeq (srep (Z.abs_nat n) ys)             (* repeat: |count| copies *)
  | GSeq xs, GNum n  => GSeq (srep (Z.abs_nat n) xs)
  | GSeq xs, GSeq ys => GSeq (flat_map (fun x => map (fun y => GSeq [x; y]) ys) xs)  (* cartesian *)
  end.

(* the + monoid's identity, the SAME () token on either side: () + x = x = x + () *)
Theorem gunit_plus_l  : forall x, gplus GUnit x = x.   Proof. intro x; destruct x; reflexivity. Qed.
Theorem gunit_plus_r  : forall x, gplus x GUnit = x.   Proof. intro x; destruct x; cbn; try reflexivity. f_equal; lia. Qed.
(* *'s zero, that same token: () * x = () = x * () *)
Theorem gunit_times_l : forall x, gtimes GUnit x = GUnit.  Proof. intro x; destruct x; reflexivity. Qed.
Theorem gunit_times_r : forall x, gtimes x GUnit = GUnit.  Proof. intro x; destruct x; reflexivity. Qed.

(* () is not 0: on a string 0 counts to the empty kind, () annihilates *)
Theorem gzero_annihilates : forall ys, gtimes (GNum 0) (GSeq ys) = GSeq [].
Proof. intros ys. cbn. reflexivity. Qed.
Theorem gunit_ne_zero : gtimes GUnit (GSeq [GNum 1]) <> gtimes (GNum 0) (GSeq [GNum 1]).
Proof. cbv. discriminate. Qed.

(* + associates over the whole carrier, no side conditions *)
Theorem gplus_assoc : forall x y z, gplus (gplus x y) z = gplus x (gplus y z).
Proof. intros x y z. destruct x, y, z; cbn; try reflexivity.
  f_equal; lia. f_equal; apply cat_assoc. f_equal; lia. Qed.

(* the point lane: a bounded semilattice, commutative, idempotent, () the bottom *)
Theorem gnom_plus_comm : forall m n, gplus (GNom m) (GNom n) = gplus (GNom n) (GNom m).
Proof. intros. cbn. f_equal. lia. Qed.
Theorem gnom_plus_idem : forall n, gplus (GNom n) (GNom n) = GNom n.
Proof. intros. cbn. f_equal. lia. Qed.
Theorem gnom_unit_num : forall n z, gplus (GNom n) (GNum z) = GNum z /\ gplus (GNum z) (GNom n) = GNum z.
Proof. split; reflexivity. Qed.
Theorem gnom_unit_seq : forall n xs, gplus (GNom n) (GSeq xs) = GSeq xs /\ gplus (GSeq xs) (GNom n) = GSeq xs.
Proof. split; reflexivity. Qed.
Theorem gnom_times_l : forall n x, gtimes (GNom n) x = GUnit. Proof. intros n x. destruct x; reflexivity. Qed.
Theorem gnom_times_r : forall n x, gtimes x (GNom n) = GUnit. Proof. intros n x. destruct x; reflexivity. Qed.

(* * associates wherever the cartesian is not engaged; chain*chain only through tally *)
Theorem gtimes_assoc_num : forall a b c,
  gtimes (gtimes (GNum a) (GNum b)) (GNum c) = gtimes (GNum a) (gtimes (GNum b) (GNum c)).
Proof. intros. cbn. f_equal. lia. Qed.
Theorem gtimes_assoc_seq3 : forall a b s,
  gtimes (gtimes (GSeq s) (GNum a)) (GNum b) = gtimes (GSeq s) (gtimes (GNum a) (GNum b)).
Proof. intros. cbn. f_equal.
  change (smul b (smul a s) = smul (a * b) s).
  rewrite Z.mul_comm. symmetry. apply smul_hom. Qed.
Theorem gtimes_assoc_seq2 : forall a b s,
  gtimes (gtimes (GNum a) (GSeq s)) (GNum b) = gtimes (GNum a) (gtimes (GSeq s) (GNum b)).
Proof. intros. cbn. f_equal.
  change (smul b (smul a s) = smul a (smul b s)).
  rewrite <- smul_hom, <- smul_hom, Z.mul_comm. reflexivity. Qed.
Theorem gtimes_assoc_seq1 : forall a b s,
  gtimes (gtimes (GNum a) (GNum b)) (GSeq s) = gtimes (GNum a) (gtimes (GNum b) (GSeq s)).
Proof. intros. cbn. f_equal.
  change (smul (a * b) s = smul a (smul b s)). apply smul_hom. Qed.

(* list * list is the cartesian product: tally is the hom, right-distributive on the nose,
   left only up to permutation *)
Definition cart {A B} (a : list A) (b : list B) : list (A * B) :=
  flat_map (fun x => map (fun y => (x,y)) b) a.

Theorem cart_12_34 : cart [1;2] [3;4] = ([(1,3);(1,4);(2,3);(2,4)] : list (Z*Z)).
Proof. reflexivity. Qed.                                   (* '(1 2)*'(3 4) *)

(* tally is the homomorphism: length (a*b) = length a * length b *)
Theorem cart_length : forall (A B:Type) (a:list A) (b:list B),
  length (cart a b) = (length a * length b)%nat.
Proof. intros A B a b. unfold cart. induction a as [|x a IH]; simpl;
  [reflexivity | rewrite length_app, length_map, IH; reflexivity]. Qed.

(* right-distributive on the nose: (a++b)*c = a*c ++ b*c *)
Theorem cart_distr_r : forall (A B:Type) (a b:list A) (c:list B),
  cart (a ++ b) c = cart a c ++ cart b c.
Proof. intros A B a b c. unfold cart. induction a as [|x a IH]; simpl;
  [reflexivity | rewrite IH, app_assoc; reflexivity]. Qed.

(* left-distributive only UP TO PERMUTATION: a*(b++c) ~ a*b ++ a*c *)
Theorem cart_distr_l_perm : forall (A B:Type) (a:list A) (b c:list B),
  Permutation (cart a (b ++ c)) (cart a b ++ cart a c).
Proof. intros A B a b c. unfold cart. induction a as [|x a IH]; simpl.
  - apply Permutation_refl.
  - rewrite map_app. eapply Permutation_trans.
    + apply Permutation_app_head. exact IH.
    + rewrite <- !app_assoc. apply Permutation_app_head.
      rewrite !app_assoc. apply Permutation_app_tail. apply Permutation_app_comm. Qed.

(* numeral-apply composes a saturated count (floor 0, no ceiling), unlike *'s |count|;
   only the composition count saturates, not the exponent *)
Definition scount (c : Z) : nat := Z.to_nat (Z.max 0 c).
Theorem count_saturates : forall c, c <= 0 -> scount c = 0%nat.
Proof. intros c H. unfold scount. rewrite Z.max_l by lia. reflexivity. Qed.
Theorem count_keeps : forall c, 0 <= c -> Z.of_nat (scount c) = c.
Proof. intros c H. unfold scount. rewrite Z.max_r by lia. apply Z2Nat.id. lia. Qed.
Definition numap {A} (c : Z) (f : A -> A) (x : A) : A := Nat.iter (scount c) f x.

(* a non-positive count composes 0 times: the identity *)
Theorem numap_floor : forall A (c : Z) (f : A -> A) (x : A),
  c <= 0 -> numap c f x = x.
Proof. intros A c f x H. unfold numap. rewrite (count_saturates c H). reflexivity. Qed.

(* a nonnegative count agrees with the bare (n f) nat lane (appf) *)
Theorem numap_pos : forall A (n : nat) (f : A -> A) (x : A),
  numap (Z.of_nat n) f x = appf n f x.
Proof.
  intros A n f x. unfold numap, appf. f_equal.
  unfold scount. rewrite Z.max_r by lia. apply Nat2Z.id.
Qed.

(* + is the measure homomorphism, and * scales the measure by the count *)
Definition sum (s : list Z) : Z := fold_right Z.add 0 s.
Theorem sum_cat  : forall x y, sum (x ++ y) = sum x + sum y.
Proof. induction x as [|a x IH]; intro y; simpl; [reflexivity | rewrite IH; lia]. Qed.
Theorem sum_srep : forall n s, sum (srep n s) = Z.of_nat n * sum s.
Proof.
  induction n as [|n IH]; intro s.
  - cbn. ring.
  - rewrite star_is_repeated_plus, sum_cat, IH.
    replace (Z.of_nat (S n)) with (Z.of_nat n + 1) by lia. ring.
Qed.

(* a number against a string answers the string whole *)
Theorem degen_str_num : gplus (GSeq [GNum 120]) (GNum 66) = GSeq [GNum 120].
Proof. reflexivity. Qed.                                      (* "x"+66="x" *)
Theorem degen_num_str : gplus (GNum 66) (GSeq [GNum 120]) = GSeq [GNum 120].
Proof. reflexivity. Qed.                                      (* 66+"x"="x" *)

(* --- arrays: shaped, broadcasting, reductions, contraction --- *)

(* rank-1 arrays as list Z: row-major, oob reads the default, empty reductions answer units *)

Open Scope Z_scope.

(* shape metadata: cell count = product of the shape; rank = its length *)
Definition alen  (shape : list Z) : Z := fold_right Z.mul 1 shape.
Definition arank (shape : list Z) : Z := Z.of_nat (length shape).
Theorem alen_23         : alen [2;3] = 6.    Proof. reflexivity. Qed.
Theorem arank_23        : arank [2;3] = 2.   Proof. reflexivity. Qed.
Theorem alen_empty_axis : alen [0] = 0.      Proof. reflexivity. Qed. (* a 0-axis -> 0 cells *)

(* peep: indexed read, out-of-bounds -> the default (nth's own behavior) *)
Definition znth (i : Z) (v : list Z) (d : Z) : Z := nth (Z.to_nat i) v d.
Theorem peep_in  : znth 1 [10;20;30] (-1) = 20.   Proof. reflexivity. Qed.
Theorem peep_oob : znth 9 [10;20;30] (-1) = -1.   Proof. reflexivity. Qed. (* OOB -> default *)
(* row-major 2D: flat index (i,j) in a cols-wide grid = i*cols + j *)
Definition znth2 (cols i j : Z) (v : list Z) (d : Z) : Z := znth (i*cols + j) v d.
Theorem peep_22 : znth2 2 1 0 [1;2;3;4] (-1) = 3.  Proof. reflexivity. Qed. (* [1][0] in 2x2 -> vals[2]=3 *)

(* reductions, and the empty-reduction-is-the-unit law *)
Definition asum  (v : list Z)    : Z    := fold_right Z.add 0 v.
Definition aprod (v : list Z)    : Z    := fold_right Z.mul 1 v.
Definition amax  (v : list Z)    : Z    := match v with [] => 0 | x :: xs => fold_right Z.max x xs end.
Definition aall  (v : list bool) : bool := forallb (fun b => b) v.
Theorem asum_empty  : asum [] = 0.     Proof. reflexivity. Qed. (* the monoid units, as empty reductions *)
Theorem aprod_empty : aprod [] = 1.    Proof. reflexivity. Qed.
Theorem aall_empty  : aall [] = true.  Proof. reflexivity. Qed.
Theorem asum_123    : asum [10;20;30] = 60.  Proof. reflexivity. Qed.
Theorem amax_30     : amax [10;30;20] = 30.  Proof. reflexivity. Qed.

(* broadcasting: + needs conforming shapes (else nil = None); scalar-* scales *)
Fixpoint vadd (a b : list Z) : option (list Z) :=
  match a, b with
  | [], []         => Some []
  | x :: a', y :: b' => match vadd a' b' with Some r => Some ((x + y) :: r) | None => None end
  | _, _           => None
  end.
Theorem vadd_ok       : vadd [1;2;3] [10;20;30] = Some [11;22;33].  Proof. reflexivity. Qed.
Theorem vadd_mismatch : vadd [1;2;3] [1;2] = None.                 Proof. reflexivity. Qed. (* shape mismatch -> nil *)

Definition vscale (c : Z) (v : list Z) : list Z := map (Z.mul c) v.
Theorem vscale_123 : vscale 2 [1;2;3] = [2;4;6].  Proof. reflexivity. Qed.

(* + is the measure homomorphism on arrays; * scales the measure by the count *)
Lemma asum_cons : forall x v, asum (x :: v) = x + asum v.
Proof. reflexivity. Qed.
Lemma asum_app : forall a b, asum (a ++ b) = asum a + asum b.
Proof. induction a as [|x a IH]; intro b; simpl; [reflexivity | unfold asum in *; simpl; rewrite IH; lia]. Qed.
Theorem asum_vadd : forall a b r, vadd a b = Some r -> asum r = asum a + asum b.
Proof.
  induction a as [|x a IH]; intros [|y b] r H; cbn in H; try discriminate.
  - injection H as H. subst r. reflexivity.
  - destruct (vadd a b) as [r'|] eqn:E; [|discriminate].
    injection H as H. subst r. rewrite !asum_cons. rewrite (IH b r' E). lia.
Qed.
Theorem asum_vscale : forall c v, asum (vscale c v) = c * asum v.
Proof. intros c v. unfold vscale, asum. induction v as [|x v IH]; simpl; [ring | rewrite IH; ring]. Qed.

(* iota: the z-array 0..n-1, and its gauss sum *)
Definition iota (n : nat) : list Z := map Z.of_nat (seq 0 n).
Theorem iota_3 : iota 3 = [0;1;2].  Proof. reflexivity. Qed.
Theorem iota_0 : iota 0 = [].       Proof. reflexivity. Qed. (* (iota 0) empty -> nothing *)
Lemma iota_S : forall n, iota (S n) = iota n ++ [Z.of_nat n].
Proof. intro n. unfold iota. rewrite seq_S, map_app. reflexivity. Qed.
Theorem asum_iota : forall n, 2 * asum (iota n) = Z.of_nat n * (Z.of_nat n - 1).
Proof.
  induction n as [|n IH].
  - reflexivity.
  - rewrite iota_S, asum_app. cbn [asum fold_right]. rewrite Nat2Z.inj_succ. nia.
Qed.
Theorem asum_iota_100 : asum (iota 100) = 4950.  Proof. now vm_compute. Qed.

(* --- the Z lane --- *)
(* gen.v requires this file and checks over Z (3^27 would blow unary nat); app_appZ makes
   appZ and app one function *)
Definition appZ  (n x : Z) : Z := Z.pow x n.
Definition iotaZ (n : Z) : list Z := iota (Z.to_nat n).   (* iota's Z-arg face, same data *)
Theorem app_appZ : forall n x, appZ (Z.of_nat n) (Z.of_nat x) = Z.of_nat (app n x).
Proof. intros n x. unfold appZ, app. symmetry. apply Nat2Z.inj_pow. Qed.

(* contraction: the dot product (+.x), commutative; inner needs conforming length *)
Fixpoint dot (a b : list Z) : Z :=
  match a, b with x :: a', y :: b' => x * y + dot a' b' | _, _ => 0 end.
Theorem dot_123_456 : dot [1;2;3] [4;5;6] = 32.  Proof. reflexivity. Qed.
Theorem dot_comm : forall a b, dot a b = dot b a.
Proof. induction a as [|x a IH]; intros [|y b]; cbn; try reflexivity; rewrite IH; lia. Qed.

Definition inner (a b : list Z) : option Z :=
  if Nat.eqb (length a) (length b) then Some (dot a b) else None.
Theorem inner_ok       : inner [1;2;3] [4;5;6] = Some 32.  Proof. reflexivity. Qed.
Theorem inner_mismatch : inner [1;2;3] [1;2] = None.       Proof. reflexivity. Qed. (* !(inner ..) *)

(* matmul cell M[i][j] = row i of A, dotted with column j of B (row-major) *)
Definition row (i : Z) (A : list (list Z)) : list Z := nth (Z.to_nat i) A [].
Definition col (j : Z) (B : list (list Z)) : list Z := map (fun r => znth j r 0) B.
Definition mm_cell (A B : list (list Z)) (i j : Z) : Z := dot (row i A) (col j B).
Theorem matmul_cell :
  mm_cell [[1;2;3];[4;5;6]] [[7;8];[9;10];[11;12]] 1 1 = 154.
Proof. reflexivity. Qed.

(* --- strings, symbols & mints --- *)

(* a string is its bytes: index, net = byte sum, tally = count. a mint is a fresh nameless
   point, a nom is (name . mint); the symbol band is the floor. *)

Open Scope Z_scope.

(* --- strings ---
   sidx misses either way; the i < 0 guard matters, Z.to_nat sends negatives to 0 *)
Definition sidx (v : list Z) (i : Z) : option Z :=
  if i <? 0 then None else nth_error v (Z.to_nat i).
Definition tally (v : list Z) : Z := Z.of_nat (length v).
Theorem str_index     : sidx [97;98;99] 0 = Some 97. Proof. reflexivity. Qed. (* ("abc" 0) = 97 *)
Theorem str_index_oob : sidx [104;105] 9 = None.     Proof. reflexivity. Qed. (* ("hi" 9) = () *)
Theorem str_net       : asum [97;98;99] = 294.    Proof. reflexivity. Qed. (* $"abc" = 294 *)
Theorem str_tally     : tally [97;98;99] = 3.     Proof. reflexivity. Qed. (* (tally "abc") = 3 *)

(* juxtaposition: a string applied to a string concatenates; it is ++ *)
Definition sjux (s t : list Z) : list Z := s ++ t.
Theorem str_juxt      : sjux [97;98] [99;100] = [97;98;99;100]. Proof. reflexivity. Qed. (* ("ab" "cd") = "abcd" *)
Theorem str_juxt_cat  : forall s t, sjux s t = s ++ t.          Proof. reflexivity. Qed. (* agrees with `+` *)
Theorem str_juxt_unitl: forall s, sjux [] s = s.                Proof. reflexivity. Qed. (* ("" s) = s *)
Theorem str_juxt_unitr: forall s, sjux s [] = s.                Proof. intros. apply app_nil_r. Qed. (* (s "") = s *)
Theorem str_juxt_assoc: forall s t u, sjux (sjux s t) u = sjux s (sjux t u).  (* so ("a" "b" "c") joins three *)
Proof. intros. unfold sjux. now rewrite app_assoc. Qed.

(* a negative index is out of range, like one past the end *)
Theorem str_idx_neg1  : sidx [97;98;99] (-1) = None. Proof. reflexivity. Qed. (* ("abc" -1) = () *)
Theorem str_idx_neg3  : sidx [97;98;99] (-3) = None. Proof. reflexivity. Qed. (* ("abc" -3) = () *)
Theorem str_idx_neg_far : sidx [97;98;99] (-4) = None. Proof. reflexivity. Qed. (* and further out, still () *)
Theorem str_idx_total : forall v i, i < 0 -> sidx v i = None.                 (* every negative, not just these *)
Proof. intros v i H. unfold sidx. now apply Z.ltb_lt in H as E; rewrite E. Qed.

(* --- chains: index an element, juxtapose by append --- *)
Definition cidx (v : list Z) (i : Z) : option Z := sidx v i.
Definition cjux (s t : list Z) : list Z := s ++ t.
Theorem chain_idx      : cidx [7;8;9] 0 = Some 7.    Proof. reflexivity. Qed. (* ('(7 8 9) 0) = 7 *)
Theorem chain_idx_neg  : cidx [7;8;9] (-1) = None.   Proof. reflexivity. Qed. (* ('(7 8 9) -1) = (), as peep answers *)
Theorem chain_idx_oob  : cidx [7;8;9] 3 = None.      Proof. reflexivity. Qed. (* out of range -> () *)
Theorem chain_juxt     : cjux [1;2] [3;4] = [1;2;3;4].  Proof. reflexivity. Qed. (* ('(1 2) '(3 4)) *)
Theorem chain_juxt_cat : forall s t, cjux s t = s ++ t. Proof. reflexivity. Qed. (* agrees with `+` *)
(* the two sequence lanes are ONE law, read at two grains: bytes and elements *)
Theorem seq_one_law    : forall v i, cidx v i = sidx v i /\ forall s t, cjux s t = sjux s t.
Proof. intros. split. reflexivity. intros. reflexivity. Qed.

(* the NUL byte nets nothing: + is the measure homomorphism down to the bytes *)
Theorem nul_appends_free : asum [97; 0] = 97.   Proof. reflexivity. Qed. (* $(+ "a" 0) = 97 *)
Theorem all_nul_nothing  : asum [0;0;0] = 0.    Proof. reflexivity. Qed. (* an all-NUL text IS nothing *)
Theorem string_nul       : asum [0] = 0.        Proof. reflexivity. Qed. (* !(string 0) *)
Theorem string_one       : asum [1] = 1.        Proof. reflexivity. Qed. (* !!(string 1) *)

(* slice: half-open [i,j) *)
Definition slice (v : list Z) (i j : Z) : list Z := firstn (Z.to_nat (j - i)) (skipn (Z.to_nat i) v).
Theorem slice_forbidden :
  slice [102;111;114;98;105;100;100;101;110;32;112;108;97;110;101;116] 3 9
  = [98;105;100;100;101;110].   (* "forbidden planet"[3,9) = "bidden" *)
Proof. reflexivity. Qed.
Theorem slice_nul : slice [97; 0] 1 2 = [0].   (* (slice (+ "a" 0) 1 2) is the NUL -> nothing *)
Proof. reflexivity. Qed.

(* --- mints: fresh, distinct, nameless points --- *)
Inductive mint := Mint (serial : nat).
Definition mnet (_ : mint) : Z := 0.              (* materially empty: $ = 0 *)
Definition mapp {A} (_ : mint) (_ : A) : Z := 1.  (* applies const-1 *)
Definition zero_point : mint := Mint 0.           (* the face of absence (serial 0) *)

Theorem mint_empty    : forall m, mnet m = 0.           Proof. reflexivity. Qed. (* $(mint 0) = 0 *)
Theorem mint_const1   : forall m (x:Z), mapp m x = 1.   Proof. reflexivity. Qed. (* ((mint 0) 5) = 1 *)
Theorem mint_self     : forall m : mint, m = m.         Proof. reflexivity. Qed. (* itself only *)
Theorem mint_distinct : forall a b, Mint a = Mint b <-> a = b.  (* distinct iff serials agree *)
Proof. intros a b. split; [intro H; injection H; auto | intro H; subst; reflexivity]. Qed.

(* --- noms: the pair (name, mint); the mint keys same-name noms --- *)
Definition nom := (list Z * mint)%type.
(* a nom is its own kind, modeled as the abstract pair; the surface reads the name via `string` *)
Definition nom_name (n : nom) : list Z := fst n.        (* the name component *)
Definition nom_mint (n : nom) : mint  := snd n.         (* the identity component *)
Definition nom_serial (n : nom) : nat := match snd n with Mint s => s end.
Theorem nom_cap : nom_name ([120], Mint 7) = [120].   Proof. reflexivity. Qed. (* (string (nom 'x)) = "x" -- the name projection *)
Theorem nom_cup : nom_mint ([120], Mint 7) = Mint 7.  Proof. reflexivity. Qed. (* the identity (serial) component *)

Fixpoint lex_lt (a b : list Z) : Prop :=
  match a, b with
  | [], [] => False
  | [], _  => True
  | _, []  => False
  | x :: a', y :: b' => x < y \/ (x = y /\ lex_lt a' b')
  end.
Definition nom_lt (a b : nom) : Prop :=
  lex_lt (fst a) (fst b) \/ (fst a = fst b /\ (nom_serial a < nom_serial b)%nat).

(* same-name noms are DISTINCT and ordered by the mint's serial (the pair lex inherits it) *)
Theorem same_name_serial   : forall nm s1 s2, (s1 < s2)%nat -> nom_lt (nm, Mint s1) (nm, Mint s2).
Proof. intros nm s1 s2 H. right. split; [reflexivity | exact H]. Qed.
Theorem same_name_distinct : forall (nm : list Z) (s1 s2 : nat), s1 <> s2 -> (nm, Mint s1) <> (nm, Mint s2).
Proof. intros nm s1 s2 H C. apply H. injection C. auto. Qed.

(* the symbol band sits below the numbers; a bare mint sorts below a named nom *)
Theorem point_below_number : lt (Osym 5) (Onum 0).   Proof. left.  cbn. lia. Qed. (* (mint 0) < 0 *)
Theorem mint_below_nom     : lt (Osym 3) (Osym 5).   Proof. right. cbn. split; [reflexivity | lia]. Qed. (* a bare mint < a nom *)

(* --- the complex tier: gaussian integers Z[i] --- *)
(* exact complex as gaussian integers: twin re im, i = twin 0 1, ~ conjugates *)
Record Zi := twin { re : Z ; im : Z }.
Definition cadd (a b : Zi) : Zi := twin (re a + re b) (im a + im b).
Definition cmul (a b : Zi) : Zi :=
  twin (re a * re b - im a * im b) (re a * im b + im a * re b).
Definition cconj (z : Zi) : Zi := twin (re z) (- im z).
Definition I : Zi := twin 0 1.
Definition cof (r : Z) : Zi := twin r 0.

(* cbn does not unfold these definitions: unfold the ops first *)
Theorem i_squared       : cmul I I = cof (-1).               Proof. reflexivity. Qed.  (* i * i = -1 *)
Theorem conj_involution : forall z, cconj (cconj z) = z.     Proof. intros [r k]; unfold cconj; cbn; f_equal; lia. Qed. (* ~~~(2 3) = ~(2 3) *)
Theorem conj_add        : forall a b, cconj (cadd a b) = cadd (cconj a) (cconj b).
Proof. intros [ar ai] [br bi]; unfold cconj, cadd; cbn; f_equal; lia. Qed.
Theorem conj_mul        : forall a b, cconj (cmul a b) = cmul (cconj a) (cconj b).
Proof. intros [ar ai] [br bi]; unfold cconj, cmul; cbn; f_equal; ring. Qed.
Theorem real_embeds_add : forall r s, cadd (cof r) (cof s) = cof (r + s).  (* ~3 + ~5 = ~8 *)
Proof. intros; unfold cadd, cof; cbn; f_equal; lia. Qed.

(* the (re,im) lexicographic order -- matches the binary's total order on complex *)
Definition clt (a b : Zi) : Prop := re a < re b \/ (re a = re b /\ im a < im b).
Theorem i_above_zero : clt (cof 0) I.                       Proof. right; cbn; lia. Qed. (* ~(0 0) < i *)
Theorem conj_below   : forall z, im z > 0 -> clt (cconj z) z. (* (conj ~(2 3)) < ~(2 3) *)
Proof. intros [r k] H; right; unfold cconj in *; cbn in *; lia. Qed.

(* --- within a band: lexicographic order --- *)
(* the within-band refinement: lex_lt orders text and chains *)
Theorem str_lex_lt    : lex_lt [97;98;99] [97;98;100].   Proof. cbn; lia. Qed. (* "abc" < "abd" *)
Theorem str_prefix_lt : lex_lt [97;98] [97;98;99].       Proof. cbn; lia. Qed. (* "ab"  < "abc" -- a prefix is lower *)
Theorem chain_lex_lt  : lex_lt [1;2] [1;3].              Proof. cbn; lia. Qed. (* '(1 2) < '(1 3) -- same lex on element-keys *)
Theorem str_lex_irrefl : forall s, ~ lex_lt s s.
Proof. induction s as [|x s IH]; cbn; [auto | intros [H|[_ H]]; [lia | auto]]. Qed.
Theorem str_lex_trans : forall a b c, lex_lt a b -> lex_lt b c -> lex_lt a c.
Proof. induction a as [|x a IH]; intros [|y b] [|z c]; cbn; try tauto.
  intros [H1|[H1a H1b]] [H2|[H2a H2b]]; subst; try (left; lia).
  right; split; [reflexivity | eapply IH; eauto]. Qed.

(* --- the complex net: a gem nets itself --- *)
(* a complex net is itself; truth gates on the real part, not the total order: conjugation
   is an automorphism, so a pure phase is blue, while sorting keeps i and -i apart. *)
Definition cnet (z : Zi) : Zi := z.
Definition cnilp (z : Zi) : bool := re z <=? 0.
Theorem cnet_self    : forall z, cnet z = z.                Proof. reflexivity. Qed.
Theorem i_blue       : cnilp I = true.                      Proof. reflexivity. Qed. (* !i: a pure phase *)
Theorem negi_blue    : cnilp (twin 0 (-1)) = true.          Proof. reflexivity. Qed. (* !~(0 -1) *)
Theorem neg_re_false : cnilp (twin (-3) 4) = true.          Proof. reflexivity. Qed. (* !~(-3 4): re<0 *)
Theorem pos_re_true  : cnilp (twin 3 4) = false.            Proof. reflexivity. Qed. (* !!~(3 4) *)
(* conjugate-blind: i and -i agree *)
Theorem conj_blind : forall z, cnilp z = cnilp (twin (re z) (- im z)).
Proof. intro z. unfold cnilp. reflexivity. Qed.
(* phases cancel as vectors: ~(3 4) + ~(-3 4) nets ~(0 8), a pure phase, so blue *)
Theorem phase_vector_add : cadd (twin 3 4) (twin (-3) 4) = twin 0 8.  Proof. reflexivity. Qed.
Theorem phase_sum_blue   : cnilp (cadd (twin 3 4) (twin (-3) 4)) = true.  Proof. reflexivity. Qed.
(* the tie-in: cnilp agrees with the real nilp (net <= 0) on lifted reals *)
Theorem cnilp_real : forall r, cnilp (cof r) = (r <=? 0).
Proof. reflexivity. Qed.

(* --- the crew as faces of `top` --- *)
(* the apps as faces of top: source faces compose (read through feel), world faces are a
   coproduct, uniqueness stated pointwise *)
Section Faces.
  Variables Top Charm Form Out Loc Net : Type.

  (* SOURCE faces -- the charm face (read) composes THROUGH the lisp face (feel) *)
  Variable read : Charm -> Form.            (* the read face: charms -> forms *)
  Variable feel : Form  -> Top.             (* the feel face: forms -> top (the weaver) *)
  Definition source (c : Charm) : Top := feel (read c).
  Theorem source_factors : forall c, source c = feel (read c).
  Proof. reflexivity. Qed.                  (* definitional: source = feel o read, lanes meet at top *)

  (* WORLD faces -- one trunk forks; the coproduct universal property *)
  Variable bao    : Loc -> Out.             (* the local face (the shell/bridge) *)
  Variable ain : Net -> Out.             (* the net face (the cat on the wire) *)
  Definition fork (x : Loc + Net) : Out :=
    match x with inl l => bao l | inr n => ain n end.
  Theorem world_inl : forall l, fork (inl l) = bao l.     Proof. reflexivity. Qed.
  Theorem world_inr : forall n, fork (inr n) = ain n.  Proof. reflexivity. Qed.
  (* any mediating map agreeing on the injections IS fork (pointwise) -- the UP *)
  Theorem world_unique :
    forall h : Loc + Net -> Out,
      (forall l, h (inl l) = bao l) -> (forall n, h (inr n) = ain n) ->
      forall x, h x = fork x.
  Proof. intros h Hl Hr x. destruct x as [l | n]; cbn; [apply Hl | apply Hr]. Qed.

  (* the object itself: everything is top (top is vacuous) *)
  Definition is_top (_ : Top) : Prop := True.
  Theorem top_vacuous : forall x, is_top x.  Proof. intro x; unfold is_top; constructor. Qed.
End Faces.

(* --- axiom audit --- *)
(* each line must print "Closed under the global context": no axioms *)
Print Assumptions sat_clamps.        (* the net/saturation law (value side) *)
Print Assumptions app_appZ.          (* the Z lane IS the nat lane: gen.v shares this model *)
Print Assumptions numap_floor.       (* the count-law floor (count side, same $) *)
Print Assumptions gplus_assoc.       (* + associates over the whole carrier (the degenerate law) *)
Print Assumptions gunit_times_l.     (* () is +'s identity and *'s annihilating zero *)
Print Assumptions unit_lt_zero.      (* () < 0: the floor below value-false (order side) *)
Print Assumptions le_total.          (* the total order *)
Print Assumptions eta_not_bridged.   (* = is alpha+structural on source, no further *)
Print Assumptions closure_beta_bridge. (* ... but value = sees the one beta ev already ran *)
Print Assumptions beta_id.           (* the reduction layer ev runs *)
Print Assumptions cnilp_real.        (* the complex net agrees with the real one *)
Print Assumptions world_unique.      (* the i/o faces are a coproduct (faces of top) *)
Print Assumptions source_factors.    (* the source faces compose (source = feel o read) *)
