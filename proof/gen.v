(* proof/gen.v -- GENERATED from test/spec.l by tools/spec2coq.l. Do not edit;
   regenerate with `make test_gen`. Each integer-comparison corpus assert is
   translated to Coq, with its source assert shown in the comment above it.
   The proofs are `vm_compute. reflexivity.`: every goal is a CLOSED computation,
   so vm_compute RUNS both sides (Coq's bytecode VM -- fast even on bignums like
   2^64) to a normal form, and reflexivity checks the two results are identical.
   A church numeral n applied to x is x ** n (the `app` model). *)
From Stdlib Require Import ZArith.
Open Scope Z_scope.
Definition app (n x : Z) : Z := Z.pow x n.

(* (1 = (0 5)) *)
Theorem gen_1 : (Z.eqb 1 (app 0 5)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (1 5)) *)
Theorem gen_2 : (Z.eqb 5 (app 1 5)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (1 = (0 0)) *)
Theorem gen_3 : (Z.eqb 1 (app 0 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (7 = (0 0 7)) *)
Theorem gen_4 : (Z.eqb 7 (app (app 0 0) 7)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (8 = (3 2)) *)
Theorem gen_5 : (Z.eqb 8 (app 3 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (262144 = (2 3 4)) *)
Theorem gen_6 : (Z.eqb 262144 (app (app 2 3) 4)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! 0)) *)
Theorem gen_7 : (Z.leb 0 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! 0)) *)
Theorem gen_8 : (Z.leb 0 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! -5)) *)
Theorem gen_9 : (Z.leb (-5) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (!! 5)) *)
Theorem gen_10 : (negb (Z.leb 5 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (0 = (mono ($ 0))) *)
Theorem gen_11 : (Z.eqb 0 (Z.max 0 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* ((64 2) = 2 * (63 2)) *)
Theorem gen_12 : (Z.eqb (app 64 2) (Z.mul 2 (app 63 2))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = 1 + 2) *)
Theorem gen_13 : (Z.eqb 3 (Z.add 1 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (2 = (// 5 2)) *)
Theorem gen_14 : (Z.eqb 2 (Z.quot 5 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (1 = 5 % 2) *)
Theorem gen_15 : (Z.eqb 1 (Z.rem 5 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (-2 = (// -5 2)) *)
Theorem gen_16 : (Z.eqb (-2) (Z.quot (-5) 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (-2 = (^ 1 -1)) *)
Theorem gen_17 : (Z.eqb (-2) (Z.lxor 1 (-1))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (15 = 8 | 4 | 2 | 1) *)
Theorem gen_18 : (Z.eqb 15 (Z.lor 8 (Z.lor 4 (Z.lor 2 1)))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (abs -5)) *)
Theorem gen_19 : (Z.eqb 5 (Z.abs (-5))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (1024 = (10 2)) *)
Theorem gen_20 : (Z.eqb 1024 (app 10 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (21 = (gcd 1071 462)) *)
Theorem gen_21 : (Z.eqb 21 (Z.gcd 1071 462)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (27 = (3 3)) *)
Theorem gen_22 : (Z.eqb 27 (app 3 3)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (7625597484987 = (3 3 3)) *)
Theorem gen_23 : (Z.eqb 7625597484987 (app (app 3 3) 3)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (16 = (2 2 2)) *)
Theorem gen_24 : (Z.eqb 16 (app (app 2 2) 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (65536 = (2 2 2 2)) *)
Theorem gen_25 : (Z.eqb 65536 (app (app (app 2 2) 2) 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (0 = 0) *)
Theorem gen_26 : (Z.eqb 0 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (0 = (mono ($ 0))) *)
Theorem gen_27 : (Z.eqb 0 (Z.max 0 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! 0)) *)
Theorem gen_28 : (Z.leb 0 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (abs -5)) *)
Theorem gen_29 : (Z.eqb 5 (Z.abs (-5))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (42 = (mono ($ 42))) *)
Theorem gen_30 : (Z.eqb 42 (Z.max 0 42)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (!! 5)) *)
Theorem gen_31 : (negb (Z.leb 5 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = 1 + 2) *)
Theorem gen_32 : (Z.eqb 3 (Z.add 1 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (7 = 1 + 2 * 3) *)
Theorem gen_33 : (Z.eqb 7 (Z.add 1 (Z.mul 2 3))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (mono (| -5))) *)
Theorem gen_34 : (Z.eqb 5 (Z.abs (-5))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = (+ 1 2)) *)
Theorem gen_35 : (Z.eqb 3 (Z.add 1 2)) = true.  Proof. vm_compute. reflexivity. Qed.

(* 35 theorems generated from 464 asserts seen *)
