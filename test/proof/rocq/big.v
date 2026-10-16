(* big.v -- the bignum lane's reference: stdlib Z, extracted, with a proven
   decimal codec across the process boundary. love: // is Z.quot, % is Z.rem *)

From Stdlib Require Import ZArith Decimal DecimalString DecimalZ String Ascii.
Open Scope Z_scope.

Definition print (z : Z) : string := DecimalString.NilZero.string_of_int (Z.to_int z).
Definition parse (s : string) : option Z :=
  option_map Z.of_int (DecimalString.NilZero.int_of_string s).

(* Z.to_int is normal, so never digitless: NilZero.isi's side conditions *)
Lemma to_int_no_nil (z : Z) :
  Z.to_int z <> Decimal.Pos Decimal.Nil /\ Z.to_int z <> Decimal.Neg Decimal.Nil.
Proof.
  assert (E : Z.to_int z = Decimal.norm (Z.to_int z)).
  { pose proof (DecimalZ.to_of (Z.to_int z)) as H.
    rewrite (DecimalZ.of_to z) in H. exact H. }
  rewrite E. destruct (Z.to_int z) as [u|u]; cbn; unfold Decimal.unorm;
    destruct (Decimal.nzhead u); split; discriminate.
Qed.

(* what the oracle prints, it re-reads exactly *)
Theorem parse_print (z : Z) : parse (print z) = Some z.
Proof.
  unfold parse, print.
  destruct (to_int_no_nil z) as [H1 H2].
  rewrite (DecimalString.NilZero.isi _ H1 H2). cbn.
  now rewrite DecimalZ.of_to.
Qed.

(* stdlib laws, named so the audit covers the ops too *)
Theorem quot_rem_law : forall a b, b <> 0 -> a = b * Z.quot a b + Z.rem a b.
Proof. intros a b Hb. now apply Z.quot_rem. Qed.

Theorem gcd_law : forall a b,
  (Z.gcd a b | a) /\ (Z.gcd a b | b) /\ 0 <= Z.gcd a b.
Proof.
  intros; repeat split;
    [apply Z.gcd_divide_l | apply Z.gcd_divide_r | apply Z.gcd_nonneg].
Qed.

Print Assumptions parse_print.   (* must stay "Closed under the global context" *)
Print Assumptions quot_rem_law.
Print Assumptions gcd_law.

(* --- extraction --- Z stays binary, no native-int mapping: an independent rep *)
From Stdlib Require Import Extraction ExtrOcamlString.
Extraction Language OCaml.
Set Extraction Output Directory ".".
Definition zadd := Z.add.    Definition zsub := Z.sub.    Definition zmul := Z.mul.
Definition zquot := Z.quot.  Definition zrem := Z.rem.    Definition zgcd := Z.gcd.
Definition zabs := Z.abs.    Definition zltb := Z.ltb.
Extraction "bigref.ml" parse print zadd zsub zmul zquot zrem zgcd zabs zltb.
