(* rocq/gen.v -- GENERATED from test/spec.l by tools/spec2coq.l. Do not edit;
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
Definition ajot (n:Z) : list Z := map Z.of_nat (seq 0 (Z.to_nat n)).
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
(* ('(1 2) = '(1 2)) *)
Theorem gen_7 : (leqb [1;2] [1;2]) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! 0)) *)
Theorem gen_8 : (Z.leb 0 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! "")) *)
Theorem gen_9 : (Z.leb (asum []) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (tuple))) *)
Theorem gen_10 : (Z.leb (asum []) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! 0)) *)
Theorem gen_11 : (Z.leb 0 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! -5)) *)
Theorem gen_12 : (Z.leb (-5) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (!! 5)) *)
Theorem gen_13 : (negb (Z.leb 5 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (!! "x")) *)
Theorem gen_14 : (negb (Z.leb (asum [120]) 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! '(0 0))) *)
Theorem gen_15 : (Z.leb (asum [0;0]) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! '(0 0))) *)
Theorem gen_16 : (Z.leb (asum [0;0]) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (0 = (mono ($ '(0 0 0)))) *)
Theorem gen_17 : (Z.eqb 0 (Z.max 0 (asum [0;0;0]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! '(-5))) *)
Theorem gen_18 : (Z.leb (asum [(-5)]) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (tuple -3 -4))) *)
Theorem gen_19 : (Z.leb (asum [(-3);(-4)]) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! '(-2 1))) *)
Theorem gen_20 : (Z.leb (asum [(-2);1]) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (!! '(0 1))) *)
Theorem gen_21 : (negb (Z.leb (asum [0;1]) 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = (mono ($ '(1 0 2)))) *)
Theorem gen_22 : (Z.eqb 3 (Z.max 0 (asum [1;0;2]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (6 = (mono ($ '(1 2 3)))) *)
Theorem gen_23 : (Z.eqb 6 (Z.max 0 (asum [1;2;3]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (7 = (mono ($ (tuple 3 4)))) *)
Theorem gen_24 : (Z.eqb 7 (Z.max 0 (asum [3;4]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (1 = (mono ($ '(1)))) *)
Theorem gen_25 : (Z.eqb 1 (Z.max 0 (asum [1]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (0 = (mono ($ '(0)))) *)
Theorem gen_26 : (Z.eqb 0 (Z.max 0 (asum [0]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (0 = (mono ($ 0))) *)
Theorem gen_27 : (Z.eqb 0 (Z.max 0 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (-1 = (mono (+ '(-2 1)))) *)
Theorem gen_28 : (Z.eqb (-1) (asum [(-2);1])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (fixp 5) *)
Theorem gen_29 : (fixp Vz) = true.  Proof. vm_compute. reflexivity. Qed.
(* (twop '(1 2)) *)
Theorem gen_30 : (twop Vpair) = true.  Proof. vm_compute. reflexivity. Qed.
(* (strp "hi") *)
Theorem gen_31 : (strp Vstr) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'x) *)
Theorem gen_32 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mapp (hash 1 2)) *)
Theorem gen_33 : (mapp Vmap) = true.  Proof. vm_compute. reflexivity. Qed.
(* (flop 1.5) *)
Theorem gen_34 : (flop Vflo) = true.  Proof. vm_compute. reflexivity. Qed.
(* (comp i) *)
Theorem gen_35 : (comp Vcx) = true.  Proof. vm_compute. reflexivity. Qed.
(* (arrp (tuple 1 2 3)) *)
Theorem gen_36 : (arrp Varr) = true.  Proof. vm_compute. reflexivity. Qed.
(* (packp 1.5) *)
Theorem gen_37 : (packp Vflo) = true.  Proof. vm_compute. reflexivity. Qed.
(* (nump 1.5) *)
Theorem gen_38 : (nump Vflo) = true.  Proof. vm_compute. reflexivity. Qed.
(* (nump i) *)
Theorem gen_39 : (nump Vcx) = true.  Proof. vm_compute. reflexivity. Qed.
(* (nump (62 2)) *)
Theorem gen_40 : (nump Vz) = true.  Proof. vm_compute. reflexivity. Qed.
(* (intp (62 2)) *)
Theorem gen_41 : (intp Vz) = true.  Proof. vm_compute. reflexivity. Qed.
(* (atomp 'x) *)
Theorem gen_42 : (atomp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (atomp '(1)))) *)
Theorem gen_43 : (negb (atomp Vpair)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (lamp '(1)) *)
Theorem gen_44 : (lamp Vpair) = true.  Proof. vm_compute. reflexivity. Qed.
(* (lamp "s") *)
Theorem gen_45 : (lamp Vstr) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (lamp 5))) *)
Theorem gen_46 : (negb (lamp Vz)) = true.  Proof. vm_compute. reflexivity. Qed.
(* ((64 2) = 2 * (63 2)) *)
Theorem gen_47 : (Z.eqb (app 64 2) (Z.mul 2 (app 63 2))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = 1 + 2) *)
Theorem gen_48 : (Z.eqb 3 (Z.add 1 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (2 = (// 5 2)) *)
Theorem gen_49 : (Z.eqb 2 (Z.quot 5 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (1 = 5 % 2) *)
Theorem gen_50 : (Z.eqb 1 (Z.rem 5 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (-2 = (// -5 2)) *)
Theorem gen_51 : (Z.eqb (-2) (Z.quot (-5) 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'inf) *)
Theorem gen_52 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'nan) *)
Theorem gen_53 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'ieee-nan) *)
Theorem gen_54 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (-2 = (^ 1 -1)) *)
Theorem gen_55 : (Z.eqb (-2) (Z.lxor 1 (-1))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (15 = 8 | 4 | 2 | 1) *)
Theorem gen_56 : (Z.eqb 15 (Z.lor 8 (Z.lor 4 (Z.lor 2 1)))) = true.  Proof. vm_compute. reflexivity. Qed.
(* ("abcd" = "ab" + "cd") *)
Theorem gen_57 : (leqb [97;98;99;100] ([97;98] ++ [99;100])) = true.  Proof. vm_compute. reflexivity. Qed.
(* ('(1 2 3 4) = '(1 2) + '(3 4)) *)
Theorem gen_58 : (leqb [1;2;3;4] ([1;2] ++ [3;4])) = true.  Proof. vm_compute. reflexivity. Qed.
(* ('(5 1 2) = 5 + '(1 2)) *)
Theorem gen_59 : (leqb [5;1;2] (5 :: [1;2])) = true.  Proof. vm_compute. reflexivity. Qed.
(* ("ababab" = "ab" * 3) *)
Theorem gen_60 : (leqb [97;98;97;98;97;98] (srep (Z.to_nat 3) [97;98])) = true.  Proof. vm_compute. reflexivity. Qed.
(* ('(1 2 1 2) = '(1 2) * 2) *)
Theorem gen_61 : (leqb [1;2;1;2] (srep (Z.to_nat 2) [1;2])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (abs -5)) *)
Theorem gen_62 : (Z.eqb 5 (Z.abs (-5))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (fixp (abs -5)) *)
Theorem gen_63 : (fixp Vz) = true.  Proof. vm_compute. reflexivity. Qed.
(* (1024 = (10 2)) *)
Theorem gen_64 : (Z.eqb 1024 (app 10 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (21 = (gcd 1071 462)) *)
Theorem gen_65 : (Z.eqb 21 (Z.gcd 1071 462)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (27 = (3 3)) *)
Theorem gen_66 : (Z.eqb 27 (app 3 3)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (7625597484987 = (3 3 3)) *)
Theorem gen_67 : (Z.eqb 7625597484987 (app (app 3 3) 3)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (16 = (2 2 2)) *)
Theorem gen_68 : (Z.eqb 16 (app (app 2 2) 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (65536 = (2 2 2 2)) *)
Theorem gen_69 : (Z.eqb 65536 (app (app (app 2 2) 2) 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (comp 5))) *)
Theorem gen_70 : (negb (comp Vz)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (20 = (peep (tuple 10 20 30) 1 -1)) *)
Theorem gen_71 : (Z.eqb 20 (nth (Z.to_nat 1) [10;20;30] (-1))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (-1 = (peep (tuple 10 20 30) 9 -1)) *)
Theorem gen_72 : (Z.eqb (-1) (nth (Z.to_nat 9) [10;20;30] (-1))) = true.  Proof. vm_compute. reflexivity. Qed.
(* ((tuple 11 22 33) = (tuple 1 2 3) + (tuple 10 20 30)) *)
Theorem gen_73 : (leqb [11;22;33] (vadd [1;2;3] [10;20;30])) = true.  Proof. vm_compute. reflexivity. Qed.
(* ((tuple 2 4 6) = (tuple 1 2 3) * 2) *)
Theorem gen_74 : (leqb [2;4;6] (vscale 2 [1;2;3])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (60 = (asum (tuple 10 20 30))) *)
Theorem gen_75 : (Z.eqb 60 (asum [10;20;30])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (30 = (amax (tuple 10 30 20))) *)
Theorem gen_76 : (Z.eqb 30 (amax [10;30;20])) = true.  Proof. vm_compute. reflexivity. Qed.
(* ((tuple 0 1 2) = (ajot 3)) *)
Theorem gen_77 : (leqb [0;1;2] (ajot 3)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (ajot 0))) *)
Theorem gen_78 : (Z.leb (asum (ajot 0)) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (ajot -1))) *)
Theorem gen_79 : (Z.leb (asum (ajot (-1))) 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (4950 = (asum (ajot 100))) *)
Theorem gen_80 : (Z.eqb 4950 (asum (ajot 100))) = true.  Proof. vm_compute. reflexivity. Qed.
(* ((tuple 3 5) = (// (tuple 7 11) 2)) *)
Theorem gen_81 : (leqb [3;5] (vquot 2 [7;11])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (0 = 0) *)
Theorem gen_82 : (Z.eqb 0 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (symp 0))) *)
Theorem gen_83 : (negb (symp Vz)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (0 = (mono ($ 0))) *)
Theorem gen_84 : (Z.eqb 0 (Z.max 0 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! 0)) *)
Theorem gen_85 : (Z.leb 0 0) = true.  Proof. vm_compute. reflexivity. Qed.
(* (294 = (mono ($ "abc"))) *)
Theorem gen_86 : (Z.eqb 294 (Z.max 0 (asum [97;98;99]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = (tally "abc")) *)
Theorem gen_87 : (Z.eqb 3 (Z.of_nat (length [97;98;99]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (7 = (mono ($ (tuple 3 4)))) *)
Theorem gen_88 : (Z.eqb 7 (Z.max 0 (asum [3;4]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (abs -5)) *)
Theorem gen_89 : (Z.eqb 5 (Z.abs (-5))) = true.  Proof. vm_compute. reflexivity. Qed.
(* ("abcd" = (+ "ab" "cd")) *)
Theorem gen_90 : (leqb [97;98;99;100] ([97;98] ++ [99;100])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mapp (hash 0)) *)
Theorem gen_91 : (mapp Vmap) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (! (mapp 5))) *)
Theorem gen_92 : (negb (mapp Vz)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (532 = (mono ($ "hello"))) *)
Theorem gen_93 : (Z.eqb 532 (Z.max 0 (asum [104;101;108;108;111]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (tally "hello")) *)
Theorem gen_94 : (Z.eqb 5 (Z.of_nat (length [104;101;108;108;111]))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (42 = (mono ($ 42))) *)
Theorem gen_95 : (Z.eqb 42 (Z.max 0 42)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (mono (!! 5)) *)
Theorem gen_96 : (negb (Z.leb 5 0)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (symp 'ab') *)
Theorem gen_97 : (symp Vsym) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = 1 + 2) *)
Theorem gen_98 : (Z.eqb 3 (Z.add 1 2)) = true.  Proof. vm_compute. reflexivity. Qed.
(* (7 = 1 + 2 * 3) *)
Theorem gen_99 : (Z.eqb 7 (Z.add 1 (Z.mul 2 3))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (6 = (mono (+ '(1 2 3)))) *)
Theorem gen_100 : (Z.eqb 6 (asum [1;2;3])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (-1 = (mono (+ '(-2 1)))) *)
Theorem gen_101 : (Z.eqb (-1) (asum [(-2);1])) = true.  Proof. vm_compute. reflexivity. Qed.
(* (5 = (mono (| -5))) *)
Theorem gen_102 : (Z.eqb 5 (Z.abs (-5))) = true.  Proof. vm_compute. reflexivity. Qed.
(* (3 = (+ 1 2)) *)
Theorem gen_103 : (Z.eqb 3 (Z.add 1 2)) = true.  Proof. vm_compute. reflexivity. Qed.

(* 103 theorems generated from 464 asserts seen *)
