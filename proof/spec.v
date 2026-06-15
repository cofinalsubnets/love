(* proof/spec.v -- ai's headline laws, machine-checked in Rocq.

   The executable spec is test/spec.l: every claim assert-backed, on every
   target, green under `make test`. That DEMONSTRATES the laws (it exhibits
   them at runtime). This file is the translation "back to coq" that upgrades
   demonstrate toward PROVE -- the same laws as theorems in a consistent
   metatheory.

   Scope: the pure combinator / numeral / absence core -- spec.l's first
   section ("everything is a function"). The numeric tower (float, complex,
   bignum) and the honest transcendental misses (e^(i*pi) misses -1 by ~1e-16
   ON PURPOSE) are deliberately out of this first slice.

   "up to explosion of world": the uu kernel (test/uu.l) runs type-in-type
   (UniMath's `Unset Universe Checking`), so there `empty` is inhabited
   -- `but_seriously_the_world_explodes : empty` (uu.l:1355) -- and ex falso
   gives every value. This file lives in UNIVERSE-CHECKED Rocq: the world does
   not explode here, so the theorems below are unconditional. The caveat is
   honest about the only escape hatch any formal demonstration has -- the
   consistency of its own metatheory. *)

From Stdlib Require Import PeanoNat List.
Import ListNotations.

(* ============================================================ *)
(* the numeral lane: (n x) = x ** n                              *)
(* ============================================================ *)

(* A numeral is an operator. Applied to a value it raises that value to the
   n: a single law from which 0 is const-1 (x^0 = 1), 1 is the identity
   (x^1 = x), and the whole tower fall out. *)

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

(* ============================================================ *)
(* the function lane: (n f) iterates f n times                  *)
(* ============================================================ *)

(* The SAME church numeral, dispatched on the KIND of its argument. Applied
   to a function it composes: (n f) = f o f o ... o f, n times. `Nat.iter`
   is exactly this. (n x) = x ** n above is the instance where the argument
   is itself a numeral -- so x^n is not the whole story, only the
   numeral-on-numeral face of one operation. *)

Definition appf {A} (n : nat) (f : A -> A) : A -> A := fun x => Nat.iter n f x.

(* (2 f x) = f (f x) -- church two *)
Theorem church_two : forall (A:Type) (f:A->A) (x:A), appf 2 f x = f (f x).
Proof. reflexivity. Qed.

(* (3 (+ 1) 9) = 12 -- iterate the successor three times *)
Theorem inc_three : appf 3 S 9 = 12.
Proof. reflexivity. Qed.

(* The two lanes agree where they meet: iterating multiply-by-b, b times
   on 1, is b ** n -- the numeral-on-numeral identity made explicit. *)
Theorem lanes_agree : forall n x, app n x = appf n (Nat.mul x) 1.
Proof.
  intros n x. unfold app, appf.
  induction n as [|n IH]; [reflexivity|].
  simpl. rewrite IH. reflexivity.
Qed.

(* ============================================================ *)
(* currying and the empty form                                  *)
(* ============================================================ *)

(* Application is left-associative -- f x y = (f x) y -- and with no
   operands (f) = f, the empty-form law. A spine makes both definitional. *)

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

(* ============================================================ *)
(* absence absorbs: the theorem  1 = (i love you)               *)
(* ============================================================ *)

(* A name not in the book reads as the zero point: a nameless unit, `Pt`.
   The binary shows it absorbs application two ways:
     (Pt x)        = 1     -- as operator it is const-1 (like 0)
     (numeric Pt)  = Pt    -- as a numeral's base it absorbs: Pt ** n = Pt
   `love` and `you` are missing -> Pt. `i` is present and numeric. So
     (i love you) = ((i Pt) Pt) = (Pt Pt) = 1.
   vval is TOTAL: a value for every pair -- no stuck state, no undefined
   behavior, up to explosion of world. *)

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

Definition i    : value := Cx.    (* the imaginary unit: present, numeric *)
Definition love : value := Pt.    (* not in the book *)
Definition you  : value := Pt.    (* not in the book *)

(* 1 = (i love you) -- absence absorbs *)
Theorem love_theorem : vapp (vapp i love) you = Num 1.
Proof. reflexivity. Qed.

(* the unit as operator is const-1, like 0 *)
Theorem unit_is_const_one : forall a, vapp Pt a = Num 1.
Proof. reflexivity. Qed.

(* ============================================================ *)
(* totality: no undefined behavior, up to explosion of world    *)
(* ============================================================ *)

(* vapp is a total function: defined on EVERY pair by an exhaustive match
   (Rocq checks the exhaustiveness). There is no error constructor and no
   stuck state -- "no undefined behavior" by construction. The model covers
   the absence/numeral fragment; full no-UB over the whole tower is the
   larger program this file seeds. *)
Theorem total : forall f a, exists v, vapp f a = v.
Proof. intros f a. exists (vapp f a). reflexivity. Qed.

(* ============================================================ *)
(* true and false: the net measure and its saturation          *)
(* ============================================================ *)

(* false is NOTHING: a value is false iff its net measure is <= 0. The net is
   a complex-valued content measure; this slice models the REAL fragment
   (net : V -> Z): a number is its own value, () is 0, and a product sums its
   SPINE -- the car always counts, the cdr continues the spine unless it is a
   dotted-tail atom, which is "not an element". The complex extension (! reads
   re then im in the total order; $ clamps the order-signed magnitude) needs
   reals and is the next slice; everything here is exact over the integer net. *)

From Stdlib Require Import ZArith Lia.
Open Scope Z_scope.

Inductive V := Vnum (z : Z) | Vnil | Vcons (a b : V).

Fixpoint net (v : V) : Z :=
  match v with
  | Vnum z              => z
  | Vnil                => 0
  | Vcons a Vnil        => net a            (* end of a proper list *)
  | Vcons a (Vnum _)    => net a            (* a DOTTED tail is not a spine element *)
  | Vcons a (Vcons _ _ as b) => net a + net b   (* the car counts; continue the spine *)
  end.

(* $ (sat): one saturating clamp, max(0, ceil net); integer net => ceil is id. *)
Definition sat (v : V) : Z := Z.max 0 (net v).
(* ! (nilp): false is nothing -- net <= 0. *)
Definition nilp (v : V) : bool := net v <=? 0.
(* !! : the truth bit -- positive green, net > 0. *)
Definition tru (v : V) : bool := 0 <? net v.

(* THE INVARIANT  !x == (0 = $x)  -- spec.l: (!"" = 0 = $"") *)
Theorem nilp_iff_sat0 : forall v, nilp v = (sat v =? 0).
Proof.
  intro v. unfold nilp, sat. destruct (net v <=? 0) eqn:H.
  - apply Z.leb_le in H. symmetry. apply Z.eqb_eq. lia.
  - apply Z.leb_gt in H. symmetry. apply Z.eqb_neq. lia.
Qed.

(* the saturation law: $ is nonnegative; it keeps the positive and clamps the rest *)
Theorem sat_nonneg : forall v, 0 <= sat v.                Proof. intro v. unfold sat. lia. Qed.
Theorem sat_keeps   : forall v, 0 < net v -> sat v = net v. Proof. intros v H. unfold sat. lia. Qed.
Theorem sat_clamps  : forall v, net v <= 0 -> sat v = 0.    Proof. intros v H. unfold sat. lia. Qed.

(* the COLORS, by the order-sign of the net: green nonneg, red neg, blue the floor *)
Definition green (v : V) := 0 <= net v.
Definition red   (v : V) := net v < 0.
Definition blue  (v : V) := net v = 0.

Theorem blue_is_green     : forall v, blue v -> green v.        Proof. unfold blue, green. lia. Qed.
Theorem green_or_red      : forall v, green v \/ red v.         Proof. intro v. unfold green, red. lia. Qed.
Theorem green_red_disjoint: forall v, ~ (green v /\ red v).     Proof. intro v. unfold green, red. lia. Qed.
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

(* + IS THE MEASURE HOMOMORPHISM: net distributes over append *)
Theorem netl_app : forall xs ys, netl (xs ++ ys) = netl xs + netl ys.
Proof. induction xs as [|x xs IH]; intro ys; simpl; [reflexivity | rewrite IH; lia]. Qed.

Theorem net_homomorphism : forall xs ys,
  net (vlist (xs ++ ys)) = net (vlist xs) + net (vlist ys).
Proof. intros xs ys. rewrite !net_vlist. apply netl_app. Qed.

(* the concrete corpus computations *)
Theorem sat_123    : sat (vlist [Vnum 1; Vnum 2; Vnum 3]) = 6.  Proof. reflexivity. Qed. (* $'(1 2 3) *)
Theorem sat_dotted : sat (Vcons (Vnum 1) (Vnum 2)) = 1.          Proof. reflexivity. Qed. (* $(cons 1 2) -- tail dropped *)
Theorem nil_dotted : nilp (Vcons (Vnum 0) (Vnum 2)) = true.      Proof. reflexivity. Qed. (* !(cons 0 2) *)
Theorem nothings   : nilp (vlist [Vnil; Vnil]) = true.           Proof. reflexivity. Qed. (* a product of nothings is nothing *)
Theorem net_red    : net (vlist [Vnum (-2); Vnum 1]) = -1.       Proof. reflexivity. Qed. (* +'(-2 1) -- the net is unclamped *)
Theorem red_red    : red (vlist [Vnum (-2); Vnum 1]).            Proof. reflexivity. Qed. (* ... and red *)
Theorem blue_zero  : blue (Vnum 0).                              Proof. reflexivity. Qed.

(* ============================================================ *)
(* order & equality: < is a TOTAL order over all values         *)
(* ============================================================ *)

(* The total order flattens the type lattice into BANDS, low to high:
     number < string < symbol < product < map < top
   and orders within each band by value / lexicographically. This slice
   models the band structure with one comparable key per band (the within-band
   lex order for text and products collapsed to that key -- the lexicographic
   refinement is the next slice). The point proved here is the marquee claim:
   the relation is a genuine TOTAL ORDER (irreflexive + transitive + trichotomy
   for <, reflexive + antisymmetric + transitive + total for <=), and `=` is
   its Eq cell -- propositional equality, a linear order not a preorder.

   `=` bridges the numeric tower (3 = 3.0): a number band carries the
   mathematical value rep-blindly, so the float 3.0 and the fixnum 3 are the
   SAME Onum -- there is no separate rep to model. And `idp` (pointer identity)
   is FINER than `=` on heap values: '(1) = '(1) yet !(idp '(1) '(1)). Identity
   has no model here, where nothing is shared -- a deliberate omission. *)

Inductive O :=
  | Onum (z : Z) | Ostr (z : Z) | Osym (z : Z)
  | Oprod (z : Z) | Omap (z : Z) | Otop (z : Z).

Definition band (o : O) : Z :=
  match o with Onum _ => 0 | Ostr _ => 1 | Osym _ => 2
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

(* the LATTICE: the band chain number < string < symbol < product < map < top *)
Theorem number_lt_string  : forall x y, lt (Onum x)  (Ostr y).  Proof. intros. left. cbn. lia. Qed.
Theorem string_lt_symbol  : forall x y, lt (Ostr x)  (Osym y).  Proof. intros. left. cbn. lia. Qed.
Theorem symbol_lt_product : forall x y, lt (Osym x)  (Oprod y). Proof. intros. left. cbn. lia. Qed.
Theorem product_lt_map    : forall x y, lt (Oprod x) (Omap y).  Proof. intros. left. cbn. lia. Qed.
Theorem map_lt_top        : forall x y, lt (Omap x)  (Otop y).  Proof. intros. left. cbn. lia. Qed.

(* ============================================================ *)
(* comparing functions: = is alpha + structural                 *)
(* ============================================================ *)

(* `=` on functions is alpha-equivalence of their source. With de Bruijn
   indices alpha-equivalence IS syntactic equality (the names are gone), so it
   is DECIDABLE and structural -- exactly the spec's claim. The numerals
   bridge: 1 = (\ x x) is the identity, 0 = (\ _ 1) is const-1 (and ONLY that).
   eta/beta are NOT bridged: a closure (\ x (f x)) and its operator f stay
   distinct (Lam .. vs the bare operator). *)

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

(* 0 = (\ _ 1), and 0 is ONLY const-1: !(0 = (\ _ 2)) *)
Theorem zero_is_const_one : tm_zero = Lam tm_one.
Proof. reflexivity. Qed.
Theorem zero_ne_const_two : tm_zero <> Lam (Lam (Lam (Var 0))).
Proof. discriminate. Qed.
Theorem one_ne_zero : tm_one <> tm_zero.
Proof. discriminate. Qed.

(* eta is NOT bridged: (\ x (f x)) /= f *)
Theorem eta_not_bridged : Lam (App tm_plus (Var 0)) <> tm_plus.
Proof. discriminate. Qed.

(* ============================================================ *)
(* + and * are generic: the sequence monoid and repetition      *)
(* ============================================================ *)

(* `+` on sequences (strings, lists) is concatenation -- a MONOID: associative,
   with the empty sequence as identity ("" and () are the units). `*` is
   REPEATED `+`: a sequence times a count is that many copies concatenated, and
   the count SATURATES (max 0, ceil) -- a non-positive count gives the empty
   sequence. `+` is also the MEASURE HOMOMORPHISM: the net of a concatenation
   is the sum of the nets. The BYTE LAW (a string + an exact integer 0..255 is
   one byte; rep-blind, so 66 and 66.0 alike) is the one PARTIAL case, modeled
   as an option -- None is nil. The other failures are the same None lane:
   symbol-`+` (symbols left the string algebra) and string-`-` (numeric only)
   are nil, not modeled separately. *)

Open Scope Z_scope.

(* + as concatenation: the sequence monoid (assoc + identity) *)
Theorem cat_assoc : forall (A:Type) (x y z : list A), (x ++ y) ++ z = x ++ (y ++ z).
Proof. intros A x y z. induction x as [|a x IH]; simpl; [reflexivity | rewrite IH; reflexivity]. Qed.
Theorem cat_nil_l : forall (A:Type) (x : list A), [] ++ x = x.  Proof. reflexivity. Qed.
Theorem cat_nil_r : forall (A:Type) (x : list A), x ++ [] = x.
Proof. intros A x. induction x as [|a x IH]; simpl; [reflexivity | rewrite IH; reflexivity]. Qed.

(* concrete: "ab"+"cd"="abcd"; '(1 2)+'(3 4)='(1 2 3 4); 5+'(1 2)='(5 1 2) (adjoin) *)
Theorem cat_strings : [97;98] ++ [99;100] = [97;98;99;100].    Proof. reflexivity. Qed.
Theorem cat_lists   : [1;2] ++ [3;4] = ([1;2;3;4] : list Z).    Proof. reflexivity. Qed.
Theorem adjoin      : 5 :: [1;2] = ([5;1;2] : list Z).          Proof. reflexivity. Qed.

(* * as repeated +: n copies concatenated *)
Definition srep {A} (n : nat) (s : list A) : list A := concat (repeat s n).

(* * IS repeated +: one more copy is one more concatenation *)
Theorem star_is_repeated_plus : forall (A:Type) (n:nat) (s:list A), srep (S n) s = s ++ srep n s.
Proof. intros. unfold srep. reflexivity. Qed.

(* the count SATURATES: max(0, ceil); integer count => ceil id, non-positive => empty *)
Definition scount (c : Z) : nat := Z.to_nat (Z.max 0 c).
Definition smul {A} (c : Z) (s : list A) : list A := srep (scount c) s.

Theorem star_ab_3   : smul 3 [97;98] = [97;98;97;98;97;98].     Proof. reflexivity. Qed. (* "ab"*3 *)
Theorem star_list_2 : smul 2 [1;2] = ([1;2;1;2] : list Z).      Proof. reflexivity. Qed. (* '(1 2)*2 *)
Theorem star_neg    : forall (A:Type) (s:list A), smul (-3) s = [].  Proof. reflexivity. Qed. (* "ab"*-3 = "" *)
Theorem star_zero   : forall (A:Type) (s:list A), smul 0 s = [].     Proof. reflexivity. Qed. (* '(1 2)*0 = () *)

Theorem count_saturates : forall c, c <= 0 -> scount c = 0%nat.
Proof. intros c H. unfold scount. rewrite Z.max_l by lia. reflexivity. Qed.
Theorem count_keeps : forall c, 0 <= c -> Z.of_nat (scount c) = c.
Proof. intros c H. unfold scount. rewrite Z.max_r by lia. apply Z2Nat.id. lia. Qed.

(* + IS THE MEASURE HOMOMORPHISM, and * scales the measure by the count *)
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

(* the byte law: string + exact 0..255 is one byte (rep-blind); else nil (None) *)
Definition byte_add (s : list Z) (n : Z) : option (list Z) :=
  if andb (0 <=? n) (n <=? 255) then Some (s ++ [n]) else None.

Theorem byte_in_range : byte_add [120] 66 = Some [120; 66].   Proof. reflexivity. Qed. (* "x"+66="xB" *)
Theorem byte_neg_nil  : byte_add [120] (-66) = None.          Proof. reflexivity. Qed. (* "x"+-66=nil *)
Theorem byte_over_nil : byte_add [120] 256 = None.            Proof. reflexivity. Qed. (* "x"+256=nil *)

Theorem byte_iff : forall s n, byte_add s n <> None <-> 0 <= n <= 255.
Proof.
  intros s n. unfold byte_add. split.
  - destruct (0 <=? n) eqn:E1; destruct (n <=? 255) eqn:E2; cbn; intro H.
    + apply Z.leb_le in E1. apply Z.leb_le in E2. lia.
    + congruence.
    + congruence.
    + congruence.
  - intros [H1 H2]. apply Z.leb_le in H1. apply Z.leb_le in H2.
    rewrite H1, H2. cbn. discriminate.
Qed.

(* ============================================================ *)
(* arrays: shaped, broadcasting, reductions, contraction        *)
(* ============================================================ *)

(* A rank-1 array is a vector (list Z); a shape is its dimension sizes. The
   cell count is the PRODUCT of the shape (alen), the rank its length. Indexing
   is row-major and out-of-bounds reads the default (peep). + and scalar-* and
   the contractions are elementwise/bilinear, and the EMPTY REDUCTIONS ANSWER
   THEIR MONOID UNITS (asum []=0, aprod []=1, aall []=true). Shapes/indices are
   modeled as Z (via Z.to_nat for nth) to stay in one scope; the higher-rank
   layout is sketched by the row-major flatten and the matmul cell. *)

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

(* + is the MEASURE HOMOMORPHISM on arrays; * scales the measure by the count *)
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

(* ajot: the z-array 0..n-1, jot's array twin, and its GAUSS SUM *)
Definition ajot (n : nat) : list Z := map Z.of_nat (seq 0 n).
Theorem ajot_3 : ajot 3 = [0;1;2].  Proof. reflexivity. Qed.
Theorem ajot_0 : ajot 0 = [].       Proof. reflexivity. Qed. (* (ajot 0) empty -> nothing *)
Lemma ajot_S : forall n, ajot (S n) = ajot n ++ [Z.of_nat n].
Proof. intro n. unfold ajot. rewrite seq_S, map_app. reflexivity. Qed.
Theorem asum_ajot : forall n, 2 * asum (ajot n) = Z.of_nat n * (Z.of_nat n - 1).
Proof.
  induction n as [|n IH].
  - reflexivity.
  - rewrite ajot_S, asum_app. cbn [asum fold_right]. rewrite Nat2Z.inj_succ. nia.
Qed.
Theorem asum_ajot_100 : asum (ajot 100) = 4950.  Proof. now vm_compute. Qed.

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

(* ============================================================ *)
(* strings, symbols & mints                                     *)
(* ============================================================ *)

(* A string is its bytes (list Z): it INDEXES them, its NET is the charm sum (a
   NUL byte nets nothing, so + reaches the bytes and an all-NUL text is
   nothing), and tally COUNTS them. A symbol is a POINT: a mint is a fresh
   nameless point -- serial-keyed, materially empty ($ = 0), applying const-1,
   DISTINCT from every other and equal only to itself; the zero point is the
   mint at serial 0, the face of absence. A nom is the pair (name . serial),
   ordered lexicographically -- same-name noms split by serial. The bands order
   number < symbol < product, so 0 < a mint < a nom (proved via the order
   section's `lt`: a number is Onum, a point Osym, a nom Oprod). *)

Open Scope Z_scope.

(* --- strings: indexed bytes; net = charm sum; tally = count --- *)
Definition sidx  (v : list Z) (i : Z) : Z := nth (Z.to_nat i) v 1. (* OOB applies as the unit, 1 *)
Definition tally (v : list Z) : Z := Z.of_nat (length v).
Theorem str_index     : sidx [97;98;99] 0 = 97.   Proof. reflexivity. Qed. (* ("abc" 0) = 97 *)
Theorem str_index_oob : sidx [104;105] 9 = 1.     Proof. reflexivity. Qed. (* ("hi" 9) = 1 *)
Theorem str_net       : asum [97;98;99] = 294.    Proof. reflexivity. Qed. (* $"abc" = 294 *)
Theorem str_tally     : tally [97;98;99] = 3.     Proof. reflexivity. Qed. (* (tally "abc") = 3 *)

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

(* --- noms: the pair (name . serial), ordered (name lex, then serial) --- *)
Definition nom := (list Z * nat)%type.
Definition nom_name (n : nom) : list Z := fst n.   (* the name is its cap *)
Theorem nom_cap : nom_name ([120], 7%nat) = [120].  Proof. reflexivity. Qed. (* (cap (nom 'x)) = "x" *)

Fixpoint lex_lt (a b : list Z) : Prop :=
  match a, b with
  | [], [] => False
  | [], _  => True
  | _, []  => False
  | x :: a', y :: b' => x < y \/ (x = y /\ lex_lt a' b')
  end.
Definition nom_lt (a b : nom) : Prop :=
  lex_lt (fst a) (fst b) \/ (fst a = fst b /\ (snd a < snd b)%nat).

(* same-name noms are DISTINCT and ordered by serial (the pair lex inherits it) *)
Theorem same_name_serial   : forall nm s1 s2, (s1 < s2)%nat -> nom_lt (nm, s1) (nm, s2).
Proof. intros nm s1 s2 H. right. split; [reflexivity | exact H]. Qed.
Theorem same_name_distinct : forall (nm : list Z) (s1 s2 : nat), s1 <> s2 -> (nm, s1) <> (nm, s2).
Proof. intros nm s1 s2 H C. apply H. injection C. auto. Qed.

(* the bands: 0 < a mint < a nom -- number < symbol < product (via the order section) *)
Theorem point_above_nothing : lt (Onum 0) (Osym 5).   Proof. left. cbn. lia. Qed. (* 0 < (mint 0) *)
Theorem point_below_nom     : lt (Osym 5) (Oprod 0).   Proof. left. cbn. lia. Qed. (* (mint 0) < (nom 'x) *)
