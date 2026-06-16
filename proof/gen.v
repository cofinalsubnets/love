(* proof/gen.v -- GENERATED from test/spec.l by tools/spec2coq.l. Do not edit;
   regenerate with `make test_gen`. Each integer-comparison corpus assert is
   translated to Coq, with its source assert shown in the comment above it.
   The proofs are `vm_compute. reflexivity.`: every goal is a CLOSED computation,
   so vm_compute RUNS both sides (Coq's bytecode VM -- fast even on bignums like
   2^64) to a normal form, and reflexivity checks the two results are identical.
   A church numeral n applied to x is x ** n (`app`); a list/string nets the
   sum of its elements/bytes (`asum`); $ is max(0,net), tally the count. *)
From Stdlib Require Import ZArith List.
Import ListNotations.
Open Scope Z_scope.
Definition app (n x : Z) : Z := Z.pow x n.
Definition asum  : list Z -> Z := fold_right Z.add 0.
Definition aprod : list Z -> Z := fold_right Z.mul 1.
Definition amax (l:list Z):Z := match l with nil=>0 | x::xs=>fold_right Z.max x xs end.
Definition amin (l:list Z):Z := match l with nil=>0 | x::xs=>fold_right Z.min x xs end.
Definition iota (n:Z) : list Z := map Z.of_nat (seq 0 (Z.to_nat n)).
Fixpoint leqb (a b:list Z):bool := match a,b with nil,nil=>true | x::a',y::b'=>andb (Z.eqb x y) (leqb a' b') | _,_=>false end.
Fixpoint vadd (a b:list Z):list Z := match a,b with x::a',y::b'=>(x+y)::vadd a' b' | _,_=>nil end.
Definition vscale (c:Z):list Z->list Z := map (Z.mul c).
Definition vquot (c:Z):list Z->list Z := map (fun e=>Z.quot e c).
Definition srep (n:nat) (s:list Z):list Z := concat (repeat s n).
Fixpoint hget (m:list (Z*Z)) (k d:Z):Z := match m with nil=>d | p::m' => if Z.eqb k (fst p) then snd p else hget m' k d end.
Inductive value := Vz | Vflo | Vcx | Vstr | Vsym | Vpair | Vmap | Varr | Vbot.
Definition fixp  v := match v with Vz   => true | _ => false end.
Definition flop  v := match v with Vflo => true | _ => false end.
Definition comp  v := match v with Vcx  => true | _ => false end.
Definition strp  v := match v with Vstr => true | _ => false end.
Definition symp  v := match v with Vsym => true | _ => false end.
Definition twop  v := match v with Vpair=> true | _ => false end.
Definition mapp  v := match v with Vmap => true | _ => false end.
Definition arrp  v := match v with Varr => true | _ => false end.
Definition intp  v := match v with Vz   => true | _ => false end.
Definition nump  v := match v with Vz|Vflo|Vcx|Varr => true | _ => false end.
Definition packp v := match v with Vflo|Vcx|Varr => true | _ => false end.
Definition atomp v := match v with Vpair => false | _ => true end.
Definition lamp  v := match v with Vz|Vbot => false | _ => true end.
Definition band  v : Z := match v with Vz|Vflo|Vcx|Varr => 0 | Vstr => 1 | Vsym => 2 | Vpair => 3 | Vmap => 4 | Vbot => 9 end.

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
(* (mono (! "")) *)
Theorem gen_8 : (Z.leb (asum []) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! -5)) *)
Theorem gen_9 : (Z.leb (-5) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (!! 5)) *)
Theorem gen_10 : (negb (Z.leb 5 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (!! "x")) *)
Theorem gen_11 : (negb (Z.leb (asum [120]) 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (0 = (mono ($ 0))) *)
Theorem gen_12 : (Z.eqb 0 (Z.max 0 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (fixp 5) *)
Theorem gen_13 : (fixp Vz) = true.  Proof. vm_compute. reflexivity. Qed.
(* (twop '(1 2)) *)
Theorem gen_14 : (twop Vpair) = true.  Proof. vm_compute. reflexivity. Qed.
(* (strp "hi") *)
Theorem gen_15 : (strp Vstr) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'x) *)
Theorem gen_16 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mapp (hash 1 2)) *)
Theorem gen_17 : (mapp Vmap) = true.  Proof. vm_compute. reflexivity. Qed.
(* (flop 1.5) *)
Theorem gen_18 : (flop Vflo) = true.  Proof. vm_compute. reflexivity. Qed.
(* (comp i) *)
Theorem gen_19 : (comp Vcx) = true.  Proof. vm_compute. reflexivity. Qed.
(* (arrp (tuple 1 2 3)) *)
Theorem gen_20 : (arrp Varr) = true.  Proof. vm_compute. reflexivity. Qed.
(* (packp 1.5) *)
Theorem gen_21 : (packp Vflo) = true.  Proof. vm_compute. reflexivity. Qed.
(* (nump 1.5) *)
Theorem gen_22 : (nump Vflo) = true.  Proof. vm_compute. reflexivity. Qed.
(* (nump i) *)
Theorem gen_23 : (nump Vcx) = true.  Proof. vm_compute. reflexivity. Qed.
(* (nump (62 2)) *)
Theorem gen_24 : (nump Vz) = true.  Proof. vm_compute. reflexivity. Qed.
(* (intp (62 2)) *)
Theorem gen_25 : (intp Vz) = true.  Proof. vm_compute. reflexivity. Qed.
(* (atomp 'x) *)
Theorem gen_26 : (atomp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (atomp '(1)))) *)
Theorem gen_27 : (negb (atomp Vpair)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (lamp '(1)) *)
Theorem gen_28 : (lamp Vpair) = true.  Proof. vm_compute. reflexivity. Qed.
(* (lamp "s") *)
Theorem gen_29 : (lamp Vstr) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (lamp 5))) *)
Theorem gen_30 : (negb (lamp Vz)) = true.  Proof. vm_compute. reflexivity. Qed.
(* ((64 2) = 2 * (63 2)) *)
Theorem gen_31 : (Z.eqb (app 64 2) (Z.mul 2 (app 63 2))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = 1 + 2) *)
Theorem gen_32 : (Z.eqb 3 (Z.add 1 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (2 = (// 5 2)) *)
Theorem gen_33 : (Z.eqb 2 (Z.quot 5 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (1 = 5 % 2) *)
Theorem gen_34 : (Z.eqb 1 (Z.rem 5 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (-2 = (// -5 2)) *)
Theorem gen_35 : (Z.eqb (-2) (Z.quot (-5) 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'inf) *)
Theorem gen_36 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'nan) *)
Theorem gen_37 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'ieee-nan) *)
Theorem gen_38 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (-2 = (^ 1 -1)) *)
Theorem gen_39 : (Z.eqb (-2) (Z.lxor 1 (-1))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (15 = 8 | 4 | 2 | 1) *)
Theorem gen_40 : (Z.eqb 15 (Z.lor 8 (Z.lor 4 (Z.lor 2 1)))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (1 < "a") *)
Theorem gen_41 : (Z.ltb (band Vz) (band Vstr)) = true.  Proof. vm_compute. reflexivity. Qed.
(* ("a" < 'x) *)
Theorem gen_42 : (Z.ltb (band Vstr) (band Vsym)) = true.  Proof. vm_compute. reflexivity. Qed.
(* ('x < '(0)) *)
Theorem gen_43 : (Z.ltb (band Vsym) (band Vpair)) = true.  Proof. vm_compute. reflexivity. Qed.
(* ('(0) < (hash 1 10)) *)
Theorem gen_44 : (Z.ltb (band Vpair) (band Vmap)) = true.  Proof. vm_compute. reflexivity. Qed.
(* ("abcd" = "ab" + "cd") *)
Theorem gen_45 : (leqb [97;98;99;100] ([97;98] ++ [99;100])) = true.  Proof. vm_compute. reflexivity. Qed.
(* ("ababab" = "ab" * 3) *)
Theorem gen_46 : (leqb [97;98;97;98;97;98] (srep (Z.to_nat 3) [97;98])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (abs -5)) *)
Theorem gen_47 : (Z.eqb 5 (Z.abs (-5))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (fixp (abs -5)) *)
Theorem gen_48 : (fixp Vz) = true.  Proof. vm_compute. reflexivity. Qed.
(* (1024 = (10 2)) *)
Theorem gen_49 : (Z.eqb 1024 (app 10 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (21 = (gcd 1071 462)) *)
Theorem gen_50 : (Z.eqb 21 (Z.gcd 1071 462)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (27 = (3 3)) *)
Theorem gen_51 : (Z.eqb 27 (app 3 3)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (7625597484987 = (3 3 3)) *)
Theorem gen_52 : (Z.eqb 7625597484987 (app (app 3 3) 3)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (16 = (2 2 2)) *)
Theorem gen_53 : (Z.eqb 16 (app (app 2 2) 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (65536 = (2 2 2 2)) *)
Theorem gen_54 : (Z.eqb 65536 (app (app (app 2 2) 2) 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (comp 5))) *)
Theorem gen_55 : (negb (comp Vz)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (iota 0))) *)
Theorem gen_56 : (Z.leb (asum (iota 0)) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (iota -1))) *)
Theorem gen_57 : (Z.leb (asum (iota (-1))) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (4950 = (asum (iota 100))) *)
Theorem gen_58 : (Z.eqb 4950 (asum (iota 100))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (294 = (mono ($ "abc"))) *)
Theorem gen_59 : (Z.eqb 294 (Z.max 0 (asum [97;98;99]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = (tally "abc")) *)
Theorem gen_60 : (Z.eqb 3 (Z.of_nat (length [97;98;99]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (abs -5)) *)
Theorem gen_61 : (Z.eqb 5 (Z.abs (-5))) = true.  Proof. vm_compute. reflexivity. Qed.
(* ("abcd" = (+ "ab" "cd")) *)
Theorem gen_62 : (leqb [97;98;99;100] ([97;98] ++ [99;100])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mapp (hash ())) *)
Theorem gen_63 : (mapp Vmap) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (mapp 5))) *)
Theorem gen_64 : (negb (mapp Vz)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (532 = (mono ($ "hello"))) *)
Theorem gen_65 : (Z.eqb 532 (Z.max 0 (asum [104;101;108;108;111]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (tally "hello")) *)
Theorem gen_66 : (Z.eqb 5 (Z.of_nat (length [104;101;108;108;111]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (42 = (mono ($ 42))) *)
Theorem gen_67 : (Z.eqb 42 (Z.max 0 42)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (!! 5)) *)
Theorem gen_68 : (negb (Z.leb 5 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'ab') *)
Theorem gen_69 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = 1 + 2) *)
Theorem gen_70 : (Z.eqb 3 (Z.add 1 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (7 = 1 + 2 * 3) *)
Theorem gen_71 : (Z.eqb 7 (Z.add 1 (Z.mul 2 3))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (mono (| -5))) *)
Theorem gen_72 : (Z.eqb 5 (Z.abs (-5))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = (+ 1 2)) *)
Theorem gen_73 : (Z.eqb 3 (Z.add 1 2)) = true.  Proof. vm_compute. reflexivity. Qed.

(* 73 theorems generated from 465 asserts seen *)
