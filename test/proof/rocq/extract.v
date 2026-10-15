(* extract.v -- the oracle's reference normalizer, built on spec.v's subst and
   extracted. ai's strategy: n-ary closures, cbv, weak, saturating *)

Require Import spec.
From Stdlib Require Import List.
Import ListNotations.

(* leading-lambda count = ai closure arity *)
Fixpoint arity (t : tm) : nat :=
  match t with Lam b => S (arity b) | _ => 0 end.

(* re-apply a spine of arg values, left to right *)
Definition rebuild (t : tm) (args : list tm) : tm :=
  fold_left (fun acc a => App acc a) args t.

(* fire n unary betas (t is a Lam of arity >= n); subst is spec.v's *)
Fixpoint apply_n (t : tm) (args : list tm) (n : nat) : tm :=
  match n, args, t with
  | S n', a :: rest, Lam b => apply_n (subst 0 a b) rest n'
  | _, _, _ => t
  end.

(* CBV / n-ary / weak / saturating evaluation, fuel-bounded *)
Fixpoint evs (fuel : nat) (t : tm) (args : list tm) : tm :=
  match fuel with
  | 0 => rebuild t args
  | S f =>
    match t with
    | App g a => let av := evs f a [] in evs f g (av :: args)
    | Lam b =>
        match args with
        | [] => t
        | _ => if Nat.ltb (length args) (arity t)
               then rebuild t args
               else evs f (apply_n t (firstn (arity t) args) (arity t))
                          (skipn (arity t) args)
        end
    | Var _ => rebuild t args
    end
  end.

Definition nf (fuel : nat) (t : tm) : tm := evs fuel t [].

(* nf's one beta step (apply_n -> subst 0 a b) is spec.v's st_beta *)
Theorem beta_is_step : forall b a, step (App (Lam b) a) (subst 0 a b).
Proof. intros; apply st_beta. Qed.

Print Assumptions beta_is_step.   (* must stay "Closed under the global context" *)

(* --- extraction --- nat -> int: the proofs stay over nat, the mapping is trusted *)
From Stdlib Require Import Extraction.
Extraction Language OCaml.
(* the .ml lands beside this file *)
Set Extraction Output Directory ".".
Extract Inductive nat => "int"
  [ "0" "(fun x -> x + 1)" ]
  "(fun zero succ n -> if n = 0 then zero () else succ (n - 1))".
Extract Inductive bool => "bool" [ "true" "false" ].
Extract Inlined Constant Nat.ltb => "(<)".
Extraction "normalizer.ml" nf arity.
