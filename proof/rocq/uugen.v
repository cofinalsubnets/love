(* proof/rocq/uugen.v -- GENERATED from test/uu.l by tools/uu2coq.l. Do not edit;
   regenerate with `make test_uugen`. uu's kernel type-checked each term below
   against its theorem (test/uu.l, green under `make test`); this is the SAME term
   translated to Gallina, which coqc re-checks -- the independent second witness,
   and the universe filter uu's type-in-type kernel lacks. Only the MLTT primitives
   are mapped (nat/bool/unit/empty + recursors, paths<->a Type-valued Id type + J-match,
   Sigma<->a primitive-projection total2 record with eta, coprod<->sum); only the
   univalence tower (an axm) is skipped, on its own via the dependency closure
   (counted at the foot). *)
From Stdlib Require Import PeanoNat.
Set Warnings "-notation-overridden,-abstract-large-number".
(* universe polymorphism -- the faithful encoding of uu's structures (large Sigmas like
   wfs/hProp reuse total2 AT the universe of UU). It does NOT re-enable type-in-type:
   Type@{i} : Type@{i+1} stays strict, so the cheats below are still rightly rejected. *)
Set Universe Polymorphism.
Set Polymorphic Inductive Cumulativity.  (* Prop-valued paths flow into Type carriers *)
(* uu's Sigma has definitional eta; the faithful Coq target is a primitive-projection
   record (eta in the kernel, axiom-free), NOT stdlib sigT (no eta). pr1/pr2/tpair
   mirror uu's own vocabulary; coprod stays stdlib sum (no eta needed). *)
Set Primitive Projections.
Record total2 {A : Type} (B : A -> Type) : Type := tpair { pr1 : A ; pr2 : B pr1 }.
Unset Primitive Projections.
Arguments tpair {A B} _ _.  Arguments pr1 {A B} _.  Arguments pr2 {A B} _.
(* uu's paths is the Type-valued identity type (UniMath's `paths`), NOT Prop's eq:
   a path can be a Sigma CARRIER (an element of UU), as in the hProp-valued nat order.
   paths_to_eq (below) bridges it back to Coq's = for the Nat.* headline laws. *)
Inductive paths {A : Type} (a : A) : A -> Type := idpath : paths a a.

Definition uu_idfun : (forall T : Type, (forall x : T, T)) :=
  (fun T => (fun x => x)).
Definition uu_funcomp : (forall X : Type, (forall Y : Type, (forall Z : Type, (forall f : (forall x : X, Y), (forall g : (forall y : Y, Z), (forall x : X, Z)))))) :=
  (fun X => (fun Y => (fun Z => (fun f => (fun g => (fun x => (g (f x)))))))).
Definition uu_iscontr : (forall T : Type, Type) :=
  (fun T => (total2 (fun c : T => (forall t : T, (@paths T t c))))).
Definition uu_hfiber : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall y : Y, Type)))) :=
  (fun X => (fun Y => (fun f => (fun y => (total2 (fun x : X => (@paths Y (f x) y))))))).
Definition uu_isweq : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), Type))) :=
  (fun X => (fun Y => (fun f => (forall y : Y, (uu_iscontr (uu_hfiber X Y f y)))))).
Definition uu_weq : (forall X : Type, (forall Y : Type, Type)) :=
  (fun X => (fun Y => (total2 (fun f : (forall x : X, Y) => (uu_isweq X Y f))))).
Definition uu_transportf : (forall A : Type, (forall P : (forall x : A, Type), (forall a : A, (forall b : A, (forall e : (@paths A a b), (forall p : (P a), (P b))))))) :=
  (fun A => (fun P => (fun a => (fun b => (fun e => (match e as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (forall p : (P a), (P bp)))) bp0 ep0) with idpath _ => (fun p => p) end)))))).
Definition uu_pathsinv0 : (forall A : Type, (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths A b a))))) :=
  (fun A => (fun a => (fun b => (fun e => (match e as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (@paths A bp a))) bp0 ep0) with idpath _ => (idpath a) end))))).
Definition uu_pathscomp0 : (forall A : Type, (forall a : A, (forall b : A, (forall c : A, (forall e1 : (@paths A a b), (forall e2 : (@paths A b c), (@paths A a c))))))) :=
  (fun A => (fun a => (fun b => (fun c => (fun e1 => (fun e2 => ((match e1 as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (forall q : (@paths A bp c), (@paths A a c)))) bp0 ep0) with idpath _ => (fun q => q) end) e2))))))).
Definition uu_maponpaths : (forall A : Type, (forall B : Type, (forall f : (forall x : A, B), (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths B (f a) (f b)))))))) :=
  (fun A => (fun B => (fun f => (fun a => (fun b => (fun e => (match e as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (@paths B (f a) (f bp)))) bp0 ep0) with idpath _ => (idpath (f a)) end))))))).
Definition uu_uu_unitpath : (forall u : unit, (@paths unit u tt)) :=
  (fun u => (unit_rect (fun v => (@paths unit v tt)) (idpath tt) u)).
Definition uu_iscontrunit : (uu_iscontr unit) :=
  (tpair tt (fun t => (uu_uu_unitpath t))).
Definition uu_proofirrelevancecontr : (forall X : Type, (forall i : (uu_iscontr X), (forall x : X, (forall y : X, (@paths X x y))))) :=
  (fun X => (fun i => (fun x => (fun y => (uu_pathscomp0 X x (pr1 i) y ((pr2 i) x) (uu_pathsinv0 X y (pr1 i) ((pr2 i) y))))))).
Definition uu_fromempty : (forall P : Type, (forall e : Empty_set, P)) :=
  (fun P => (fun e => (Empty_set_rect (fun x => P) e))).
Definition uu_negb : (forall b : bool, bool) :=
  (fun b => (bool_rect (fun x => bool) false true b)).
Definition uu_add : (forall n : nat, (forall m : nat, nat)) :=
  (fun n => (fun m => (nat_rect (fun x => nat) m (fun k => (fun r => (S r))) n))).
Definition uu_uu_two_plus_two : (@paths nat (uu_add 2 2) 4) :=
  (idpath 4).
Definition uu_uu_negb_true : (@paths bool (uu_negb true) false) :=
  (idpath false).
Definition uu_uu_fromsum : (forall v : (sum nat bool), nat) :=
  (fun v => (sum_rect (fun x => nat) (fun a => a) (fun b => (bool_rect (fun x => nat) 1 0 b)) v)).
Definition uu_uu_fromsum_ii2 : (@paths nat (uu_uu_fromsum (inr true)) 1) :=
  (idpath 1).
Definition uu_idisweq : (forall T : Type, (uu_isweq T T (uu_idfun T))) :=
  (fun T => (fun y => (tpair (tpair y (idpath y)) (fun t => (match (pr2 t) as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (@paths (uu_hfiber T T (uu_idfun T) bp) (tpair (pr1 t) ep) (tpair bp (idpath bp))))) bp0 ep0) with idpath _ => (idpath (tpair (pr1 t) (idpath (pr1 t)))) end))))).
Definition uu_idweq : (forall T : Type, (uu_weq T T)) :=
  (fun T => (tpair (fun x => x) (uu_idisweq T))).
Definition uu_eqweqmap : (forall X : Type, (forall Y : Type, (forall e : (@paths Type X Y), (uu_weq X Y)))) :=
  (fun X => (fun Y => (fun e => (match e as ep0 in (paths _ bp0) return ((fun Yp => (fun ep => (uu_weq X Yp))) bp0 ep0) with idpath _ => (uu_idweq X) end)))).
Definition uu_uu_eqweqmap_idpath : (forall X : Type, (@paths (uu_weq X X) (uu_eqweqmap X X (idpath X)) (uu_idweq X))) :=
  (fun X => (idpath (uu_idweq X))).
Definition uu_invmap : (forall X : Type, (forall Y : Type, (forall w : (uu_weq X Y), (forall y : Y, X)))) :=
  (fun X => (fun Y => (fun w => (fun y => (pr1 (pr1 ((pr2 w) y))))))).
Definition uu_homotweqinvweq : (forall X : Type, (forall Y : Type, (forall w : (uu_weq X Y), (forall y : Y, (@paths Y ((pr1 w) (uu_invmap X Y w y)) y))))) :=
  (fun X => (fun Y => (fun w => (fun y => (pr2 (pr1 ((pr2 w) y))))))).
Definition uu_isaprop : (forall X : Type, Type) :=
  (fun X => (forall x : X, (forall y : X, (uu_iscontr (@paths X x y))))).
Definition uu_isaset : (forall X : Type, Type) :=
  (fun X => (forall x : X, (forall y : X, (uu_isaprop (@paths X x y))))).
Definition uu_isofhlevel : (forall n : nat, (forall X : Type, Type)) :=
  (fun n => (nat_rect (fun q => (forall X : Type, Type)) uu_iscontr (fun k => (fun rec => (fun X => (forall x : X, (forall y : X, (rec (@paths X x y))))))) n)).
Definition uu_uu_isaprop_is_level1 : (forall X : Type, (@paths Type (uu_isaprop X) (uu_isofhlevel 1 X))) :=
  (fun X => (idpath (uu_isaprop X))).
Definition uu_uu_isaset_is_level2 : (forall X : Type, (@paths Type (uu_isaset X) (uu_isofhlevel 2 X))) :=
  (fun X => (idpath (uu_isaset X))).
Definition uu_hProp : Type :=
  (total2 (fun X : Type => (uu_isaprop X))).
Definition uu_hSet : Type :=
  (total2 (fun X : Type => (uu_isaset X))).
Definition uu_ishinh_UU : (forall X : Type, Type) :=
  (fun X => (forall P : uu_hProp, (forall f : (forall x : X, (pr1 P)), (pr1 P)))).
Definition uu_hinhpr : (forall X : Type, (forall x : X, (uu_ishinh_UU X))) :=
  (fun X => (fun x => (fun P => (fun f => (f x))))).
Definition uu_hinhuniv : (forall X : Type, (forall P : uu_hProp, (forall f : (forall x : X, (pr1 P)), (forall w : (uu_ishinh_UU X), (pr1 P))))) :=
  (fun X => (fun P => (fun f => (fun w => (w P f))))).
Definition uu_total2_paths_f : (forall A : Type, (forall P : (forall x : A, Type), (forall s : (total2 (fun x : A => (P x))), (forall sp : (total2 (fun x : A => (P x))), (forall p : (@paths A (pr1 s) (pr1 sp)), (forall q : (@paths (P (pr1 sp)) (uu_transportf A P (pr1 s) (pr1 sp) p (pr2 s)) (pr2 sp)), (@paths (total2 (fun x : A => (P x))) s sp))))))) :=
  (fun A => (fun P => (fun s => (fun sp => (fun p => (fun q => ((match p as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (forall qp : (P bp), (forall qe : (@paths (P bp) (uu_transportf A P (pr1 s) bp ep (pr2 s)) qp), (@paths (total2 (fun x : A => (P x))) s (tpair bp qp)))))) bp0 ep0) with idpath _ => (fun qp => (fun qe => (match qe as ep0 in (paths _ bp0) return ((fun qpp => (fun e2 => (@paths (total2 (fun x : A => (P x))) s (tpair (pr1 s) qpp)))) bp0 ep0) with idpath _ => (idpath s) end))) end) (pr2 sp) q))))))).
Definition uu_homotinvweqweq : (forall X : Type, (forall Y : Type, (forall w : (uu_weq X Y), (forall x : X, (@paths X (uu_invmap X Y w ((pr1 w) x)) x))))) :=
  (fun X => (fun Y => (fun w => (fun x => (uu_pathsinv0 X x (uu_invmap X Y w ((pr1 w) x)) (uu_maponpaths (uu_hfiber X Y (pr1 w) ((pr1 w) x)) X (fun t => (pr1 t)) (tpair x (idpath ((pr1 w) x))) (pr1 ((pr2 w) ((pr1 w) x))) ((pr2 ((pr2 w) ((pr1 w) x))) (tpair x (idpath ((pr1 w) x)))))))))).
Definition uu_isweqtoempty : (forall X : Type, (forall f : (forall x : X, Empty_set), (uu_isweq X Empty_set f))) :=
  (fun X => (fun f => (fun y => (Empty_set_rect (fun e => (uu_iscontr (uu_hfiber X Empty_set f e))) y)))).
Definition uu_weqtoempty : (forall X : Type, (forall f : (forall x : X, Empty_set), (uu_weq X Empty_set))) :=
  (fun X => (fun f => (tpair f (uu_isweqtoempty X f)))).
Definition uu_nopathstruetofalse : (forall e : (@paths bool true false), Empty_set) :=
  (fun e => (uu_transportf bool (fun b => (bool_rect (fun x => Type) unit Empty_set b)) true false e tt)).
Definition uu_nopathsfalsetotrue : (forall e : (@paths bool false true), Empty_set) :=
  (fun e => (uu_transportf bool (fun b => (bool_rect (fun x => Type) Empty_set unit b)) false true e tt)).
Definition uu_pathscomp0rid : (forall A : Type, (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths (@paths A a b) (uu_pathscomp0 A a b b e (idpath b)) e))))) :=
  (fun A => (fun a => (fun b => (fun e => (match e as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (@paths (@paths A a bp) (uu_pathscomp0 A a bp bp ep (idpath bp)) ep))) bp0 ep0) with idpath _ => (idpath (idpath a)) end))))).
Definition uu_pathsinv0r : (forall A : Type, (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths (@paths A a a) (uu_pathscomp0 A a b a e (uu_pathsinv0 A a b e)) (idpath a)))))) :=
  (fun A => (fun a => (fun b => (fun e => (match e as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (@paths (@paths A a a) (uu_pathscomp0 A a bp a ep (uu_pathsinv0 A a bp ep)) (idpath a)))) bp0 ep0) with idpath _ => (idpath (idpath a)) end))))).
Definition uu_pathsinv0l : (forall A : Type, (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths (@paths A b b) (uu_pathscomp0 A b a b (uu_pathsinv0 A a b e) e) (idpath b)))))) :=
  (fun A => (fun a => (fun b => (fun e => (match e as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (@paths (@paths A bp bp) (uu_pathscomp0 A bp a bp (uu_pathsinv0 A a bp ep) ep) (idpath bp)))) bp0 ep0) with idpath _ => (idpath (idpath a)) end))))).
Definition uu_iscontrretract : (forall X : Type, (forall Y : Type, (forall p : (forall x : X, Y), (forall s : (forall y : Y, X), (forall eps : (forall y : Y, (@paths Y (p (s y)) y)), (forall is : (uu_iscontr X), (uu_iscontr Y))))))) :=
  (fun X => (fun Y => (fun p => (fun s => (fun eps => (fun is => (tpair (p (pr1 is)) (fun t => (uu_pathscomp0 Y t (p (s t)) (p (pr1 is)) (uu_pathsinv0 Y (p (s t)) t (eps t)) (uu_maponpaths X Y p (s t) (pr1 is) ((pr2 is) (s t)))))))))))).
Definition uu_hfibershomotftog : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall g : (forall x : X, Y), (forall h : (forall x : X, (@paths Y (f x) (g x))), (forall y : Y, (forall t : (uu_hfiber X Y f y), (uu_hfiber X Y g y)))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun h => (fun y => (fun t => (tpair (pr1 t) (uu_pathscomp0 Y (g (pr1 t)) (f (pr1 t)) y (uu_pathsinv0 Y (f (pr1 t)) (g (pr1 t)) (h (pr1 t))) (pr2 t)))))))))).
Definition uu_hfibershomotgtof : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall g : (forall x : X, Y), (forall h : (forall x : X, (@paths Y (f x) (g x))), (forall y : Y, (forall t : (uu_hfiber X Y g y), (uu_hfiber X Y f y)))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun h => (fun y => (fun t => (tpair (pr1 t) (uu_pathscomp0 Y (f (pr1 t)) (g (pr1 t)) y (h (pr1 t)) (pr2 t)))))))))).
Definition uu_iscontrpathsinunit : (forall x : unit, (forall y : unit, (uu_iscontr (@paths unit x y)))) :=
  (fun x => (fun y => (tpair (uu_pathscomp0 unit x tt y (uu_uu_unitpath x) (uu_pathsinv0 unit y tt (uu_uu_unitpath y))) (fun e => (match e as ep0 in (paths _ bp0) return ((fun yp => (fun ep => (@paths (@paths unit x yp) ep (uu_pathscomp0 unit x tt yp (uu_uu_unitpath x) (uu_pathsinv0 unit yp tt (uu_uu_unitpath yp)))))) bp0 ep0) with idpath _ => (uu_pathsinv0 (@paths unit x x) (uu_pathscomp0 unit x tt x (uu_uu_unitpath x) (uu_pathsinv0 unit x tt (uu_uu_unitpath x))) (idpath x) (uu_pathsinv0r unit x tt (uu_uu_unitpath x))) end))))).
Definition uu_isapropunit : (uu_isaprop unit) :=
  uu_iscontrpathsinunit.
Definition uu_path_assoc : (forall A : Type, (forall a : A, (forall b : A, (forall c : A, (forall d : A, (forall e1 : (@paths A a b), (forall e2 : (@paths A b c), (forall e3 : (@paths A c d), (@paths (@paths A a d) (uu_pathscomp0 A a b d e1 (uu_pathscomp0 A b c d e2 e3)) (uu_pathscomp0 A a c d (uu_pathscomp0 A a b c e1 e2) e3)))))))))) :=
  (fun A => (fun a => (fun b => (fun c => (fun d => (fun e1 => (fun e2 => (fun e3 => ((match e1 as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (forall q2 : (@paths A bp c), (forall q3 : (@paths A c d), (@paths (@paths A a d) (uu_pathscomp0 A a bp d ep (uu_pathscomp0 A bp c d q2 q3)) (uu_pathscomp0 A a c d (uu_pathscomp0 A a bp c ep q2) q3)))))) bp0 ep0) with idpath _ => (fun q2 => (fun q3 => (idpath (uu_pathscomp0 A a c d q2 q3)))) end) e2 e3))))))))).
Definition uu_uu_pathsinv0comp : (forall A : Type, (forall a : A, (forall b : A, (forall c : A, (forall p : (@paths A a b), (forall q : (@paths A b c), (@paths (@paths A b c) (uu_pathscomp0 A b a c (uu_pathsinv0 A a b p) (uu_pathscomp0 A a b c p q)) q))))))) :=
  (fun A => (fun a => (fun b => (fun c => (fun p => (fun q => ((match p as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (forall qq : (@paths A bp c), (@paths (@paths A bp c) (uu_pathscomp0 A bp a c (uu_pathsinv0 A a bp ep) (uu_pathscomp0 A a bp c ep qq)) qq)))) bp0 ep0) with idpath _ => (fun qq => (idpath qq)) end) q))))))).
Definition uu_uu_transportf_paths_Fl : (forall A : Type, (forall B : Type, (forall f : (forall x : A, B), (forall b : B, (forall x1 : A, (forall x2 : A, (forall p : (@paths A x1 x2), (forall e : (@paths B (f x1) b), (@paths (@paths B (f x2) b) (uu_transportf A (fun x => (@paths B (f x) b)) x1 x2 p e) (uu_pathscomp0 B (f x2) (f x1) b (uu_pathsinv0 B (f x1) (f x2) (uu_maponpaths A B f x1 x2 p)) e)))))))))) :=
  (fun A => (fun B => (fun f => (fun b => (fun x1 => (fun x2 => (fun p => (fun e => (match p as ep0 in (paths _ bp0) return ((fun xp => (fun pp => (@paths (@paths B (f xp) b) (uu_transportf A (fun x => (@paths B (f x) b)) x1 xp pp e) (uu_pathscomp0 B (f xp) (f x1) b (uu_pathsinv0 B (f x1) (f xp) (uu_maponpaths A B f x1 xp pp)) e)))) bp0 ep0) with idpath _ => (idpath e) end))))))))).
Definition uu_iscontrhfiberl1 : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall g : (forall x : X, Y), (forall h : (forall x : X, (@paths Y (f x) (g x))), (forall y : Y, (forall is : (uu_iscontr (uu_hfiber X Y f y)), (uu_iscontr (uu_hfiber X Y g y))))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun h => (fun y => (fun is => (uu_iscontrretract (uu_hfiber X Y f y) (uu_hfiber X Y g y) (uu_hfibershomotftog X Y f g h y) (uu_hfibershomotgtof X Y f g h y) (fun t => (uu_total2_paths_f X (fun x => (@paths Y (g x) y)) ((uu_hfibershomotftog X Y f g h y) ((uu_hfibershomotgtof X Y f g h y) t)) t (idpath (pr1 t)) (uu_uu_pathsinv0comp Y (f (pr1 t)) (g (pr1 t)) y (h (pr1 t)) (pr2 t)))) is)))))))).
Definition uu_isweqhomot : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall g : (forall x : X, Y), (forall h : (forall x : X, (@paths Y (f x) (g x))), (forall is : (uu_isweq X Y f), (uu_isweq X Y g))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun h => (fun is => (fun y => (uu_iscontrhfiberl1 X Y f g h y (is y))))))))).
Definition uu_isweq_iso : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall g : (forall y : Y, X), (forall egf : (forall x : X, (@paths X (g (f x)) x)), (forall efg : (forall y : Y, (@paths Y (f (g y)) y)), (uu_isweq X Y f))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun egf => (fun efg => (fun y => (uu_iscontrretract (uu_hfiber Y Y (fun yp => (f (g yp))) y) (uu_hfiber X Y f y) (fun t => (tpair (g (pr1 t)) (pr2 t))) (fun t => (tpair (f (pr1 t)) (uu_pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y (uu_maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t))) (pr2 t)))) (fun t => (uu_total2_paths_f X (fun x => (@paths Y (f x) y)) (tpair (g (f (pr1 t))) (uu_pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y (uu_maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t))) (pr2 t))) t (egf (pr1 t)) (uu_pathscomp0 (@paths Y (f (pr1 t)) y) (uu_transportf X (fun x => (@paths Y (f x) y)) (g (f (pr1 t))) (pr1 t) (egf (pr1 t)) (uu_pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y (uu_maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t))) (pr2 t))) (uu_pathscomp0 Y (f (pr1 t)) (f (g (f (pr1 t)))) y (uu_pathsinv0 Y (f (g (f (pr1 t)))) (f (pr1 t)) (uu_maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t)))) (uu_pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y (uu_maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t))) (pr2 t))) (pr2 t) (uu_uu_transportf_paths_Fl X Y f y (g (f (pr1 t))) (pr1 t) (egf (pr1 t)) (uu_pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y (uu_maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t))) (pr2 t))) (uu_uu_pathsinv0comp Y (f (g (f (pr1 t)))) (f (pr1 t)) y (uu_maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t))) (pr2 t))))) (uu_iscontrhfiberl1 Y Y (uu_idfun Y) (fun yp => (f (g yp))) (fun yp => (uu_pathsinv0 Y (f (g yp)) yp (efg yp))) y (uu_idisweq Y y)))))))))).
Definition uu_isweqinvmap : (forall X : Type, (forall Y : Type, (forall w : (uu_weq X Y), (uu_isweq Y X (fun y => (uu_invmap X Y w y)))))) :=
  (fun X => (fun Y => (fun w => (uu_isweq_iso Y X (fun y => (uu_invmap X Y w y)) (pr1 w) (uu_homotweqinvweq X Y w) (uu_homotinvweqweq X Y w))))).
Definition uu_invweq : (forall X : Type, (forall Y : Type, (forall w : (uu_weq X Y), (uu_weq Y X)))) :=
  (fun X => (fun Y => (fun w => (tpair (fun y => (uu_invmap X Y w y)) (uu_isweqinvmap X Y w))))).
Definition uu_uu_isweqnegb : (uu_isweq bool bool uu_negb) :=
  (uu_isweq_iso bool bool uu_negb uu_negb (fun b => (bool_rect (fun bp => (@paths bool (uu_negb (uu_negb bp)) bp)) (idpath true) (idpath false) b)) (fun b => (bool_rect (fun bp => (@paths bool (uu_negb (uu_negb bp)) bp)) (idpath true) (idpath false) b))).
Definition uu_uu_weqnegb : (uu_weq bool bool) :=
  (tpair uu_negb uu_uu_isweqnegb).
Definition uu_twooutof3c : (forall X : Type, (forall Y : Type, (forall Z : Type, (forall f : (forall x : X, Y), (forall g : (forall y : Y, Z), (forall isf : (uu_isweq X Y f), (forall isg : (uu_isweq Y Z g), (uu_isweq X Z (fun x => (g (f x))))))))))) :=
  (fun X => (fun Y => (fun Z => (fun f => (fun g => (fun isf => (fun isg => (uu_isweq_iso X Z (fun x => (g (f x))) (fun z => (uu_invmap X Y (tpair f isf) (uu_invmap Y Z (tpair g isg) z))) (fun x => (uu_pathscomp0 X (uu_invmap X Y (tpair f isf) (uu_invmap Y Z (tpair g isg) (g (f x)))) (uu_invmap X Y (tpair f isf) (f x)) x (uu_maponpaths Y X (fun yy => (uu_invmap X Y (tpair f isf) yy)) (uu_invmap Y Z (tpair g isg) (g (f x))) (f x) (uu_homotinvweqweq Y Z (tpair g isg) (f x))) (uu_homotinvweqweq X Y (tpair f isf) x))) (fun z => (uu_pathscomp0 Z (g (f (uu_invmap X Y (tpair f isf) (uu_invmap Y Z (tpair g isg) z)))) (g (uu_invmap Y Z (tpair g isg) z)) z (uu_maponpaths Y Z g (f (uu_invmap X Y (tpair f isf) (uu_invmap Y Z (tpair g isg) z))) (uu_invmap Y Z (tpair g isg) z) (uu_homotweqinvweq X Y (tpair f isf) (uu_invmap Y Z (tpair g isg) z))) (uu_homotweqinvweq Y Z (tpair g isg) z))))))))))).
Definition uu_weqcomp : (forall X : Type, (forall Y : Type, (forall Z : Type, (forall w1 : (uu_weq X Y), (forall w2 : (uu_weq Y Z), (uu_weq X Z)))))) :=
  (fun X => (fun Y => (fun Z => (fun w1 => (fun w2 => (tpair (fun x => ((pr1 w2) ((pr1 w1) x))) (uu_twooutof3c X Y Z (pr1 w1) (pr1 w2) (pr2 w1) (pr2 w2)))))))).
Definition uu_boolascoprod : (uu_weq bool (sum unit unit)) :=
  (tpair (fun b => (bool_rect (fun q => (sum unit unit)) (inl tt) (inr tt) b)) (uu_isweq_iso bool (sum unit unit) (fun b => (bool_rect (fun q => (sum unit unit)) (inl tt) (inr tt) b)) (fun c => (sum_rect (fun q => bool) (fun u => true) (fun u => false) c)) (fun b => (bool_rect (fun bp => (@paths bool (sum_rect (fun q => bool) (fun u => true) (fun u => false) (bool_rect (fun q => (sum unit unit)) (inl tt) (inr tt) bp)) bp)) (idpath true) (idpath false) b)) (fun c => (sum_rect (fun cp => (@paths (sum unit unit) (bool_rect (fun q => (sum unit unit)) (inl tt) (inr tt) (sum_rect (fun q => bool) (fun u => true) (fun u => false) cp)) cp)) (fun u => (uu_maponpaths unit (sum unit unit) (fun uu => (inl uu)) tt u (uu_pathsinv0 unit u tt (uu_uu_unitpath u)))) (fun u => (uu_maponpaths unit (sum unit unit) (fun uu => (inr uu)) tt u (uu_pathsinv0 unit u tt (uu_uu_unitpath u)))) c)))).
Definition uu_coconusfromt : (forall T : Type, (forall t : T, Type)) :=
  (fun T => (fun t => (total2 (fun tp : T => (@paths T t tp))))).
Definition uu_iscontrcoconusfromt : (forall T : Type, (forall t : T, (uu_iscontr (uu_coconusfromt T t)))) :=
  (fun T => (fun t => (tpair (tpair t (idpath t)) (fun w => (match (pr2 w) as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (@paths (uu_coconusfromt T t) (tpair bp ep) (tpair t (idpath t))))) bp0 ep0) with idpath _ => (idpath (tpair t (idpath t))) end))))).
Definition uu_invproofirrelevance : (forall X : Type, (forall h : (forall x : X, (forall y : X, (@paths X x y))), (uu_isaprop X))) :=
  (fun X => (fun h => (fun x => (fun y => (tpair (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (h x x)) (h x y)) (fun p => (match p as ep0 in (paths _ bp0) return ((fun yp => (fun pp => (@paths (@paths X x yp) pp (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (h x x)) (h x yp))))) bp0 ep0) with idpath _ => (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (h x x)) (h x x)) (idpath x) (uu_pathsinv0l X x x (h x x))) end))))))).
Definition uu_negpaths0sx : (forall k : nat, (forall e : (@paths nat 0 (S k)), Empty_set)) :=
  (fun k => (fun e => (uu_transportf nat (fun n => (nat_rect (fun q => Type) unit (fun m => (fun r => Empty_set)) n)) 0 (S k) e tt))).
Definition uu_negpathssx0 : (forall k : nat, (forall e : (@paths nat (S k) 0), Empty_set)) :=
  (fun k => (fun e => (uu_transportf nat (fun n => (nat_rect (fun q => Type) Empty_set (fun m => (fun r => unit)) n)) (S k) 0 e tt))).
Definition uu_isdeceqbool : (forall x : bool, (forall y : bool, (sum (@paths bool x y) (forall e : (@paths bool x y), Empty_set)))) :=
  (fun x => (fun y => ((bool_rect (fun xp => (forall yy : bool, (sum (@paths bool xp yy) (forall e : (@paths bool xp yy), Empty_set)))) (fun yy => (bool_rect (fun yp => (sum (@paths bool true yp) (forall e : (@paths bool true yp), Empty_set))) (inl (idpath true)) (inr uu_nopathstruetofalse) yy)) (fun yy => (bool_rect (fun yp => (sum (@paths bool false yp) (forall e : (@paths bool false yp), Empty_set))) (inr uu_nopathsfalsetotrue) (inl (idpath false)) yy)) x) y))).
Definition uu_isaproppathsfromisolated : (forall X : Type, (forall x : X, (forall is : (forall y : X, (sum (@paths X x y) (forall e : (@paths X x y), Empty_set))), (forall y : X, (uu_isaprop (@paths X x y)))))) :=
  (fun X => (fun x => (fun is => (fun y => (uu_invproofirrelevance (@paths X x y) (fun p => (fun q => (uu_pathscomp0 (@paths X x y) p (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (sum_rect (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f p))) (is y))) q (match p as ep0 in (paths _ bp0) return ((fun yp => (fun pp => (@paths (@paths X x yp) pp (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (sum_rect (fun d => (@paths X x yp)) (fun e => e) (fun f => (uu_fromempty (@paths X x yp) (f pp))) (is yp)))))) bp0 ep0) with idpath _ => (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (idpath x) (uu_pathsinv0l X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x)))) end) (uu_pathscomp0 (@paths X x y) (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (sum_rect (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f p))) (is y))) (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (sum_rect (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f q))) (is y))) q (uu_maponpaths (@paths X x y) (@paths X x y) (fun r => (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) r)) (sum_rect (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f p))) (is y)) (sum_rect (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f q))) (is y)) (sum_rect (fun d => (@paths (@paths X x y) (sum_rect (fun d2 => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f p))) d) (sum_rect (fun d2 => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f q))) d))) (fun e => (idpath e)) (fun f => (uu_fromempty (@paths (@paths X x y) (uu_fromempty (@paths X x y) (f p)) (uu_fromempty (@paths X x y) (f q))) (f p))) (is y))) (uu_pathsinv0 (@paths X x y) q (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (sum_rect (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f q))) (is y))) (match q as ep0 in (paths _ bp0) return ((fun yp => (fun pp => (@paths (@paths X x yp) pp (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (sum_rect (fun d => (@paths X x yp)) (fun e => e) (fun f => (uu_fromempty (@paths X x yp) (f pp))) (is yp)))))) bp0 ep0) with idpath _ => (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x))) (idpath x) (uu_pathsinv0l X x x (sum_rect (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (idpath x)))) (is x)))) end))))))))))).
Definition uu_isasetifdeceq : (forall X : Type, (forall dec : (forall x : X, (forall y : X, (sum (@paths X x y) (forall e : (@paths X x y), Empty_set)))), (uu_isaset X))) :=
  (fun X => (fun dec => (fun x => (fun y => (uu_isaproppathsfromisolated X x (dec x) y))))).
Definition uu_isasetbool : (uu_isaset bool) :=
  (uu_isasetifdeceq bool uu_isdeceqbool).
Definition uu_isdeceqnat : (forall x : nat, (forall y : nat, (sum (@paths nat x y) (forall e : (@paths nat x y), Empty_set)))) :=
  (fun x => (fun y => ((nat_rect (fun xp => (forall yy : nat, (sum (@paths nat xp yy) (forall e : (@paths nat xp yy), Empty_set)))) (fun yy => (nat_rect (fun yp => (sum (@paths nat 0 yp) (forall e : (@paths nat 0 yp), Empty_set))) (inl (idpath 0)) (fun m => (fun r => (inr (uu_negpaths0sx m)))) yy)) (fun k => (fun IH => (fun yy => (nat_rect (fun yp => (sum (@paths nat (S k) yp) (forall e : (@paths nat (S k) yp), Empty_set))) (inr (uu_negpathssx0 k)) (fun m => (fun r2 => (sum_rect (fun d => (sum (@paths nat (S k) (S m)) (forall e : (@paths nat (S k) (S m)), Empty_set))) (fun e => (inl (uu_maponpaths nat nat (fun n => (S n)) k m e))) (fun f => (inr (fun e2 => (f (uu_maponpaths nat nat (fun n => (nat_rect (fun q => nat) 0 (fun a => (fun r3 => a)) n)) (S k) (S m) e2))))) (IH m)))) yy)))) x) y))).
Definition uu_isasetnat : (uu_isaset nat) :=
  (uu_isasetifdeceq nat uu_isdeceqnat).
Definition uu_transportb : (forall A : Type, (forall P : (forall x : A, Type), (forall a : A, (forall b : A, (forall e : (@paths A a b), (forall p : (P b), (P a))))))) :=
  (fun A => (fun P => (fun a => (fun b => (fun e => (uu_transportf A P b a (uu_pathsinv0 A a b e))))))).
Definition uu_isweqtransportf : (forall A : Type, (forall P : (forall x : A, Type), (forall a : A, (forall b : A, (forall e : (@paths A a b), (uu_isweq (P a) (P b) (uu_transportf A P a b e))))))) :=
  (fun A => (fun P => (fun a => (fun b => (fun e => (match e as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (uu_isweq (P a) (P bp) (uu_transportf A P a bp ep)))) bp0 ep0) with idpath _ => (uu_idisweq (P a)) end)))))).
Definition uu_isweqtransportb : (forall A : Type, (forall P : (forall x : A, Type), (forall a : A, (forall b : A, (forall e : (@paths A a b), (uu_isweq (P b) (P a) (uu_transportb A P a b e))))))) :=
  (fun A => (fun P => (fun a => (fun b => (fun e => (uu_isweqtransportf A P b a (uu_pathsinv0 A a b e))))))).
Definition uu_invmaponpathsweq : (forall X : Type, (forall Y : Type, (forall w : (uu_weq X Y), (forall x : X, (forall xp : X, (forall e : (@paths Y ((pr1 w) x) ((pr1 w) xp)), (@paths X x xp))))))) :=
  (fun X => (fun Y => (fun w => (fun x => (fun xp => (fun e => (uu_pathscomp0 X x (uu_invmap X Y w ((pr1 w) x)) xp (uu_pathsinv0 X (uu_invmap X Y w ((pr1 w) x)) x (uu_homotinvweqweq X Y w x)) (uu_pathscomp0 X (uu_invmap X Y w ((pr1 w) x)) (uu_invmap X Y w ((pr1 w) xp)) xp (uu_maponpaths Y X (fun y => (uu_invmap X Y w y)) ((pr1 w) x) ((pr1 w) xp) e) (uu_homotinvweqweq X Y w xp))))))))).
Definition uu_iscontrweqb : (forall X : Type, (forall Y : Type, (forall w : (uu_weq X Y), (forall is : (uu_iscontr Y), (uu_iscontr X))))) :=
  (fun X => (fun Y => (fun w => (fun is => (uu_iscontrretract Y X (fun y => (uu_invmap X Y w y)) (pr1 w) (uu_homotinvweqweq X Y w) is))))).
Definition uu_pathsspace : (forall T : Type, Type) :=
  (fun T => (total2 (fun x : T => (uu_coconusfromt T x)))).
Definition uu_pathsspacetriple : (forall T : Type, (forall t1 : T, (forall t2 : T, (forall e : (@paths T t1 t2), (uu_pathsspace T))))) :=
  (fun T => (fun t1 => (fun t2 => (fun e => (tpair t1 (tpair t2 e)))))).
Definition uu_deltap : (forall T : Type, (forall t : T, (uu_pathsspace T))) :=
  (fun T => (fun t => (tpair t (tpair t (idpath t))))).
Definition uu_isweqdeltap : (forall T : Type, (uu_isweq T (uu_pathsspace T) (uu_deltap T))) :=
  (fun T => (uu_isweq_iso T (uu_pathsspace T) (uu_deltap T) (fun z => (pr1 z)) (fun t => (idpath t)) (fun z => (uu_total2_paths_f T (fun x => (uu_coconusfromt T x)) (uu_deltap T (pr1 z)) z (idpath (pr1 z)) (uu_pathsinv0 (uu_coconusfromt T (pr1 z)) (pr2 z) (tpair (pr1 z) (idpath (pr1 z))) ((pr2 (uu_iscontrcoconusfromt T (pr1 z))) (pr2 z))))))).
Definition uu_natplusr0 : (forall n : nat, (@paths nat (uu_add n 0) n)) :=
  (fun n => (nat_rect (fun m => (@paths nat (uu_add m 0) m)) (idpath 0) (fun k => (fun IH => (uu_maponpaths nat nat (fun m => (S m)) (uu_add k 0) k IH))) n)).
Definition uu_uu_let_demo : (@paths nat (let two := 2 in (uu_add two two)) 4) :=
  (idpath 4).
Definition uu_toforallpaths : (forall T : Type, (forall P : (forall t : T, Type), (forall f : (forall t : T, (P t)), (forall g : (forall t : T, (P t)), (forall e : (@paths (forall t : T, (P t)) f g), (forall t : T, (@paths (P t) (f t) (g t)))))))) :=
  (fun T => (fun P => (fun f => (fun g => (fun e => (fun t => (uu_maponpaths (forall tq : T, (P tq)) (P t) (fun h => (h t)) f g e))))))).
Definition uu_coconustot : (forall T : Type, (forall t : T, Type)) :=
  (fun T => (fun t => (total2 (fun tp : T => (@paths T tp t))))).
Definition uu_iscontrcoconustot : (forall T : Type, (forall t : T, (uu_iscontr (uu_coconustot T t)))) :=
  (fun T => (fun t => (tpair (tpair t (idpath t)) (fun w => (match (pr2 w) as ep0 in (paths _ bp0) return ((fun bp => (fun ep => (@paths (uu_coconustot T bp) (tpair (pr1 w) ep) (tpair bp (idpath bp))))) bp0 ep0) with idpath _ => (idpath (tpair (pr1 w) (idpath (pr1 w)))) end))))).
Definition uu_isweqpr1 : (forall X : Type, (forall P : (forall x : X, Type), (forall is : (forall x : X, (uu_iscontr (P x))), (uu_isweq (total2 (fun x : X => (P x))) X (fun s => (pr1 s)))))) :=
  (fun X => (fun P => (fun is => (uu_isweq_iso (total2 (fun x : X => (P x))) X (fun s => (pr1 s)) (fun x => (tpair x (pr1 (is x)))) (fun s => (uu_total2_paths_f X P (tpair (pr1 s) (pr1 (is (pr1 s)))) s (idpath (pr1 s)) (uu_pathsinv0 (P (pr1 s)) (pr2 s) (pr1 (is (pr1 s))) ((pr2 (is (pr1 s))) (pr2 s))))) (fun x => (idpath x)))))).
Definition uu_isweqcontrcontr : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall isx : (uu_iscontr X), (forall isy : (uu_iscontr Y), (uu_isweq X Y f)))))) :=
  (fun X => (fun Y => (fun f => (fun isx => (fun isy => (uu_isweq_iso X Y f (fun y => (pr1 isx)) (fun x => (uu_proofirrelevancecontr X isx (pr1 isx) x)) (fun y => (uu_proofirrelevancecontr Y isy (f (pr1 isx)) y)))))))).
Definition uu_wf : (forall Flse : Type, (forall T : Type, Type)) :=
  (fun Flse => (fun T => (total2 (fun lt : (forall x : T, (forall y : T, Type)) => (total2 (fun tr : (forall x : T, (forall y : T, (forall z : T, (forall p : (lt x y), (forall q : (lt y z), (lt x z)))))) => (forall h : (forall n : nat, T), (forall ds : (forall n : nat, (lt (h (S n)) (h n))), Flse)))))))).
Definition uu_wfs : (forall Flse : Type, Type) :=
  (fun Flse => (total2 (fun T : Type => (uu_wf Flse T)))).
Definition uu_uset : (forall Flse : Type, (forall w : (uu_wfs Flse), Type)) :=
  (fun Flse => (fun w => (pr1 w))).
Definition uu_uord : (forall Flse : Type, (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (forall y : (uu_uset Flse w), Type)))) :=
  (fun Flse => (fun w => (pr1 (pr2 w)))).
Definition uu_trans : (forall Flse : Type, (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (forall y : (uu_uset Flse w), (forall z : (uu_uset Flse w), (forall p : (uu_uord Flse w x y), (forall q : (uu_uord Flse w y z), (uu_uord Flse w x z)))))))) :=
  (fun Flse => (fun w => (pr1 (pr2 (pr2 w))))).
Definition uu_wfp : (forall Flse : Type, (forall w : (uu_wfs Flse), (forall h : (forall n : nat, (uu_uset Flse w)), (forall ds : (forall n : nat, (uu_uord Flse w (h (S n)) (h n))), Flse)))) :=
  (fun Flse => (fun w => (pr2 (pr2 (pr2 w))))).
Definition uu_wfs_wf_uord : (forall Flse : Type, (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), Type))) :=
  (fun Flse => (fun v => (fun w => (total2 (fun f : (forall x : (uu_uset Flse v), (uu_uset Flse w)) => (total2 (fun hm : (forall x : (uu_uset Flse v), (forall y : (uu_uset Flse v), (forall p : (uu_uord Flse v x y), (uu_uord Flse w (f x) (f y))))) => (total2 (fun y : (uu_uset Flse w) => (forall x : (uu_uset Flse v), (uu_uord Flse w (f x) y))))))))))).
Definition uu_ufun : (forall Flse : Type, (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), (forall a : (uu_wfs_wf_uord Flse v w), (forall x : (uu_uset Flse v), (uu_uset Flse w)))))) :=
  (fun Flse => (fun v => (fun w => (fun a => (pr1 a))))).
Definition uu_homo : (forall Flse : Type, (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), (forall a : (uu_wfs_wf_uord Flse v w), (forall x : (uu_uset Flse v), (forall y : (uu_uset Flse v), (forall p : (uu_uord Flse v x y), (uu_uord Flse w ((pr1 a) x) ((pr1 a) y))))))))) :=
  (fun Flse => (fun v => (fun w => (fun a => (pr1 (pr2 a)))))).
Definition uu_domi : (forall Flse : Type, (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), (forall a : (uu_wfs_wf_uord Flse v w), (uu_uset Flse w))))) :=
  (fun Flse => (fun v => (fun w => (fun a => (pr1 (pr2 (pr2 a))))))).
Definition uu_domicom : (forall Flse : Type, (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), (forall a : (uu_wfs_wf_uord Flse v w), (forall x : (uu_uset Flse v), (uu_uord Flse w ((pr1 a) x) (pr1 (pr2 (pr2 a))))))))) :=
  (fun Flse => (fun v => (fun w => (fun a => (pr2 (pr2 (pr2 a))))))).
Definition uu_wfs_wf_trans : (forall Flse : Type, (forall x : (uu_wfs Flse), (forall y : (uu_wfs Flse), (forall z : (uu_wfs Flse), (forall f : (uu_wfs_wf_uord Flse x y), (forall g : (uu_wfs_wf_uord Flse y z), (uu_wfs_wf_uord Flse x z))))))) :=
  (fun Flse => (fun x => (fun y => (fun z => (fun f => (fun g => (tpair (fun a => ((pr1 g) ((pr1 f) a))) (tpair (fun x0 => (fun y0 => (fun pp => (uu_homo Flse y z g ((pr1 f) x0) ((pr1 f) y0) (uu_homo Flse x y f x0 y0 pp))))) (tpair (uu_domi Flse y z g) (fun x0 => (uu_trans Flse z ((pr1 g) ((pr1 f) x0)) ((pr1 g) (uu_domi Flse x y f)) (uu_domi Flse y z g) (uu_homo Flse y z g ((pr1 f) x0) (uu_domi Flse x y f) (uu_domicom Flse x y f x0)) (uu_domicom Flse y z g (uu_domi Flse x y f))))))))))))).
Definition uu_wfs_wf_wfp_shift : (forall Flse : Type, (forall f : (forall n : nat, (uu_wfs Flse)), (forall b : (forall n : nat, (uu_wfs_wf_uord Flse (f (S n)) (f n))), (forall n : nat, (forall a : (uu_uset Flse (f n)), (uu_uset Flse (f 0))))))) :=
  (fun Flse => (fun f => (fun b => (fun n => (nat_rect (fun m => (forall a : (uu_uset Flse (f m)), (uu_uset Flse (f 0)))) (fun a => a) (fun m => (fun IH => (fun x => (IH ((pr1 (b m)) x))))) n))))).
Definition uu_wfs_wf_wfp_seq : (forall Flse : Type, (forall f : (forall n : nat, (uu_wfs Flse)), (forall b : (forall n : nat, (uu_wfs_wf_uord Flse (f (S n)) (f n))), (forall n : nat, (uu_uset Flse (f 0)))))) :=
  (fun Flse => (fun f => (fun b => (fun n => ((uu_wfs_wf_wfp_shift Flse f b n) (uu_domi Flse (f (S n)) (f n) (b n))))))).
Definition uu_wfs_wf_wfp_compshift : (forall Flse : Type, (forall f : (forall n : nat, (uu_wfs Flse)), (forall b : (forall n : nat, (uu_wfs_wf_uord Flse (f (S n)) (f n))), (forall n : nat, (forall x : (uu_uset Flse (f n)), (forall y : (uu_uset Flse (f n)), (forall p : (uu_uord Flse (f n) x y), (uu_uord Flse (f 0) ((uu_wfs_wf_wfp_shift Flse f b n) x) ((uu_wfs_wf_wfp_shift Flse f b n) y))))))))) :=
  (fun Flse => (fun f => (fun b => (fun n => (nat_rect (fun m => (forall x : (uu_uset Flse (f m)), (forall y : (uu_uset Flse (f m)), (forall p : (uu_uord Flse (f m) x y), (uu_uord Flse (f 0) ((uu_wfs_wf_wfp_shift Flse f b m) x) ((uu_wfs_wf_wfp_shift Flse f b m) y)))))) (fun x => (fun y => (fun p => p))) (fun m => (fun IH => (fun x => (fun y => (fun p => (IH ((pr1 (b m)) x) ((pr1 (b m)) y) (uu_homo Flse (f (S m)) (f m) (b m) x y p))))))) n))))).
Definition uu_wfs_wf_wfp_desc : (forall Flse : Type, (forall f : (forall n : nat, (uu_wfs Flse)), (forall b : (forall n : nat, (uu_wfs_wf_uord Flse (f (S n)) (f n))), (forall n : nat, (uu_uord Flse (f 0) (uu_wfs_wf_wfp_seq Flse f b (S n)) (uu_wfs_wf_wfp_seq Flse f b n)))))) :=
  (fun Flse => (fun f => (fun b => (fun n => (uu_wfs_wf_wfp_compshift Flse f b n ((pr1 (b n)) (uu_domi Flse (f (S (S n))) (f (S n)) (b (S n)))) (uu_domi Flse (f (S n)) (f n) (b n)) (uu_domicom Flse (f (S n)) (f n) (b n) (uu_domi Flse (f (S (S n))) (f (S n)) (b (S n))))))))).
Definition uu_wfs_wf : (forall Flse : Type, (uu_wf Flse (uu_wfs Flse))) :=
  (fun Flse => (tpair (uu_wfs_wf_uord Flse) (tpair (uu_wfs_wf_trans Flse) (fun h => (fun b => (uu_wfp Flse (h 0) (uu_wfs_wf_wfp_seq Flse h b) (uu_wfs_wf_wfp_desc Flse h b))))))).
Definition uu_wfs_wf_t : (forall Flse : Type, (uu_wfs Flse)) :=
  (fun Flse => (tpair (uu_wfs Flse) (uu_wfs_wf Flse))).
Definition uu_maxi_fun : (forall Flse : Type, (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (uu_wfs Flse)))) :=
  (fun Flse => (fun w => (fun x => (tpair (total2 (fun y : (uu_uset Flse w) => (uu_uord Flse w y x))) (tpair (fun a => (fun bb => (uu_uord Flse w (pr1 a) (pr1 bb)))) (tpair (fun x0 => (fun y0 => (fun z0 => (fun p => (fun q => (uu_trans Flse w (pr1 x0) (pr1 y0) (pr1 z0) p q)))))) (fun h => (fun b => (uu_wfp Flse w (fun n => (pr1 (h n))) b))))))))).
Definition uu_maxi_homo : (forall Flse : Type, (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (forall y : (uu_uset Flse w), (forall p : (uu_uord Flse w x y), (uu_wfs_wf_uord Flse (uu_maxi_fun Flse w x) (uu_maxi_fun Flse w y))))))) :=
  (fun Flse => (fun w => (fun x => (fun y => (fun p => (tpair (fun z => (tpair (pr1 z) (uu_trans Flse w (pr1 z) x y (pr2 z) p))) (tpair (fun x0 => (fun y0 => (fun q => q))) (tpair (tpair x p) (fun x0 => (pr2 x0)))))))))).
Definition uu_maxidom : (forall Flse : Type, (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (uu_wfs_wf_uord Flse (uu_maxi_fun Flse w x) w)))) :=
  (fun Flse => (fun w => (fun x => (tpair (fun z => (pr1 z)) (tpair (fun x0 => (fun y0 => (fun p => p))) (tpair x (fun x0 => (pr2 x0)))))))).
Definition uu_maxi : (forall Flse : Type, (forall w : (uu_wfs Flse), (uu_wfs_wf_uord Flse w (uu_wfs_wf_t Flse)))) :=
  (fun Flse => (fun w => (tpair (uu_maxi_fun Flse w) (tpair (uu_maxi_homo Flse w) (tpair w (uu_maxidom Flse w)))))).
Definition uu_isapropempty : (uu_isaprop Empty_set) :=
  (fun x => (fun y => (uu_fromempty (uu_iscontr (@paths Empty_set x y)) x))).
Definition uu_isapropifcontr : (forall X : Type, (forall is : (uu_iscontr X), (uu_isaprop X))) :=
  (fun X => (fun is => (fun x => (fun y => (tpair (uu_pathscomp0 X x (pr1 is) y ((pr2 is) x) (uu_pathsinv0 X y (pr1 is) ((pr2 is) y))) (fun e => (match e as ep0 in (paths _ bp0) return ((fun yp => (fun ep => (@paths (@paths X x yp) ep (uu_pathscomp0 X x (pr1 is) yp ((pr2 is) x) (uu_pathsinv0 X yp (pr1 is) ((pr2 is) yp)))))) bp0 ep0) with idpath _ => (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x (pr1 is) x ((pr2 is) x) (uu_pathsinv0 X x (pr1 is) ((pr2 is) x))) (idpath x) (uu_pathsinv0r X x (pr1 is) ((pr2 is) x))) end))))))).
Definition uu_iscontraprop1 : (forall X : Type, (forall ip : (uu_isaprop X), (forall x : X, (uu_iscontr X)))) :=
  (fun X => (fun ip => (fun x => (tpair x (fun t => (pr1 (ip t x))))))).
Definition uu_isapropdirprod : (forall A : Type, (forall B : Type, (forall ipa : (uu_isaprop A), (forall ipb : (uu_isaprop B), (uu_isaprop (total2 (fun q : A => B))))))) :=
  (fun A => (fun B => (fun ipa => (fun ipb => (uu_invproofirrelevance (total2 (fun q : A => B)) (fun x => (fun y => (uu_total2_paths_f A (fun q => B) x y (pr1 (ipa (pr1 x) (pr1 y))) (pr1 (ipb (uu_transportf A (fun q => B) (pr1 x) (pr1 y) (pr1 (ipa (pr1 x) (pr1 y))) (pr2 x)) (pr2 y))))))))))).
Definition uu_htrue : uu_hProp :=
  (tpair unit uu_isapropunit).
Definition uu_hfalse : uu_hProp :=
  (tpair Empty_set uu_isapropempty).
Definition uu_hconj : (forall P : uu_hProp, (forall Q : uu_hProp, uu_hProp)) :=
  (fun P => (fun Q => (tpair (total2 (fun q : (pr1 P) => (pr1 Q))) (uu_isapropdirprod (pr1 P) (pr1 Q) (pr2 P) (pr2 Q))))).
Definition uu_uu_htrue_demo : (pr1 uu_htrue) :=
  tt.
Definition uu_uu_hconj_demo : (pr1 (uu_hconj uu_htrue uu_htrue)) :=
  (tpair tt tt).
Definition uu_uu_squash_demo : (pr1 uu_htrue) :=
  (uu_hinhuniv unit uu_htrue (fun u => u) (uu_hinhpr unit tt)).
Definition uu_hrel : (forall X : Type, Type) :=
  (fun X => (forall x : X, (forall y : X, uu_hProp))).
Definition uu_istrans : (forall X : Type, (forall R : (uu_hrel X), Type)) :=
  (fun X => (fun R => (forall x1 : X, (forall x2 : X, (forall x3 : X, (forall r1 : (pr1 (R x1 x2)), (forall r2 : (pr1 (R x2 x3)), (pr1 (R x1 x3))))))))).
Definition uu_isrefl : (forall X : Type, (forall R : (uu_hrel X), Type)) :=
  (fun X => (fun R => (forall x : X, (pr1 (R x x))))).
Definition uu_issymm : (forall X : Type, (forall R : (uu_hrel X), Type)) :=
  (fun X => (fun R => (forall x1 : X, (forall x2 : X, (forall r : (pr1 (R x1 x2)), (pr1 (R x2 x1))))))).
Definition uu_iseqrel : (forall X : Type, (forall R : (uu_hrel X), Type)) :=
  (fun X => (fun R => (total2 (fun q : (uu_istrans X R) => (total2 (fun q2 : (uu_isrefl X R) => (uu_issymm X R))))))).
Definition uu_eqrel : (forall X : Type, Type) :=
  (fun X => (total2 (fun R : (uu_hrel X) => (uu_iseqrel X R)))).
Definition uu_eqreltrans : (forall X : Type, (forall E : (uu_eqrel X), (uu_istrans X (pr1 E)))) :=
  (fun X => (fun E => (pr1 (pr2 E)))).
Definition uu_eqrelrefl : (forall X : Type, (forall E : (uu_eqrel X), (uu_isrefl X (pr1 E)))) :=
  (fun X => (fun E => (pr1 (pr2 (pr2 E))))).
Definition uu_eqrelsymm : (forall X : Type, (forall E : (uu_eqrel X), (uu_issymm X (pr1 E)))) :=
  (fun X => (fun E => (pr2 (pr2 (pr2 E))))).
Definition uu_hsubtype : (forall X : Type, Type) :=
  (fun X => (forall x : X, uu_hProp)).
Definition uu_carrier : (forall X : Type, (forall A : (uu_hsubtype X), Type)) :=
  (fun X => (fun A => (total2 (fun x : X => (pr1 (A x)))))).
Definition uu_iseqclass : (forall X : Type, (forall R : (uu_hrel X), (forall A : (uu_hsubtype X), Type))) :=
  (fun X => (fun R => (fun A => (total2 (fun q : (uu_ishinh_UU (uu_carrier X A)) => (total2 (fun q2 : (forall x1 : X, (forall x2 : X, (forall r : (pr1 (R x1 x2)), (forall a : (pr1 (A x1)), (pr1 (A x2)))))) => (forall x1 : X, (forall x2 : X, (forall a1 : (pr1 (A x1)), (forall a2 : (pr1 (A x2)), (pr1 (R x1 x2))))))))))))).
Definition uu_eqax0 : (forall X : Type, (forall R : (uu_hrel X), (forall A : (uu_hsubtype X), (forall is : (uu_iseqclass X R A), (uu_ishinh_UU (uu_carrier X A)))))) :=
  (fun X => (fun R => (fun A => (fun is => (pr1 is))))).
Definition uu_eqax1 : (forall X : Type, (forall R : (uu_hrel X), (forall A : (uu_hsubtype X), (forall is : (uu_iseqclass X R A), (forall x1 : X, (forall x2 : X, (forall r : (pr1 (R x1 x2)), (forall a : (pr1 (A x1)), (pr1 (A x2)))))))))) :=
  (fun X => (fun R => (fun A => (fun is => (pr1 (pr2 is)))))).
Definition uu_eqax2 : (forall X : Type, (forall R : (uu_hrel X), (forall A : (uu_hsubtype X), (forall is : (uu_iseqclass X R A), (forall x1 : X, (forall x2 : X, (forall a1 : (pr1 (A x1)), (forall a2 : (pr1 (A x2)), (pr1 (R x1 x2)))))))))) :=
  (fun X => (fun R => (fun A => (fun is => (pr2 (pr2 is)))))).
Definition uu_setquot : (forall X : Type, (forall R : (uu_hrel X), Type)) :=
  (fun X => (fun R => (total2 (fun A : (uu_hsubtype X) => (uu_iseqclass X R A))))).
Definition uu_setquotpr : (forall X : Type, (forall E : (uu_eqrel X), (forall x0 : X, (uu_setquot X (pr1 E))))) :=
  (fun X => (fun E => (fun x0 => (tpair (fun x => ((pr1 E) x0 x)) (tpair (uu_hinhpr (uu_carrier X (fun x => ((pr1 E) x0 x))) (tpair x0 (uu_eqrelrefl X E x0))) (tpair (fun x1 => (fun x2 => (fun r => (fun a => (uu_eqreltrans X E x0 x1 x2 a r))))) (fun x1 => (fun x2 => (fun a1 => (fun a2 => (uu_eqreltrans X E x1 x0 x2 (uu_eqrelsymm X E x0 x1 a1) a2))))))))))).
Definition uu_isweqimplimpl : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall g : (forall y : Y, X), (forall ipx : (uu_isaprop X), (forall ipy : (uu_isaprop Y), (uu_isweq X Y f))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun ipx => (fun ipy => (uu_isweq_iso X Y f g (fun x => (pr1 (ipx (g (f x)) x))) (fun y => (pr1 (ipy (f (g y)) y)))))))))).
Definition uu_image : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), Type))) :=
  (fun X => (fun Y => (fun f => (total2 (fun y : Y => (uu_ishinh_UU (uu_hfiber X Y f y))))))).
Definition uu_prtoimage : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall x : X, (uu_image X Y f))))) :=
  (fun X => (fun Y => (fun f => (fun x => (tpair (f x) (uu_hinhpr (uu_hfiber X Y f (f x)) (tpair x (idpath (f x))))))))).
Definition uu_isapropsubtype : (forall X : Type, (forall A : (uu_hsubtype X), (forall is : (forall x1 : X, (forall x2 : X, (forall a1 : (pr1 (A x1)), (forall a2 : (pr1 (A x2)), (@paths X x1 x2))))), (uu_isaprop (uu_carrier X A))))) :=
  (fun X => (fun A => (fun is => (uu_invproofirrelevance (uu_carrier X A) (fun c1 => (fun c2 => (uu_total2_paths_f X (fun x => (pr1 (A x))) c1 c2 (is (pr1 c1) (pr1 c2) (pr2 c1) (pr2 c2)) (pr1 ((pr2 (A (pr1 c2))) (uu_transportf X (fun x => (pr1 (A x))) (pr1 c1) (pr1 c2) (is (pr1 c1) (pr1 c2) (pr2 c1) (pr2 c2)) (pr2 c1)) (pr2 c2)))))))))).
Definition uu_uu_trivrel : (uu_eqrel bool) :=
  (tpair (fun x => (fun y => uu_htrue)) (tpair (fun x1 => (fun x2 => (fun x3 => (fun r1 => (fun r2 => tt))))) (tpair (fun x => tt) (fun x1 => (fun x2 => (fun r => tt)))))).
Definition uu_uu_pathscollapse : (forall X : Type, (forall x : X, (forall PF : (forall y : X, Type), (forall s : (forall y : X, (forall e : (@paths X x y), (PF y))), (forall p : (forall y : X, (forall q : (PF y), (@paths X x y))), (forall ip : (forall y : X, (uu_isaprop (PF y))), (forall y : X, (uu_isaprop (@paths X x y))))))))) :=
  (fun X => (fun x => (fun PF => (fun s => (fun p => (fun ip => (fun y => (uu_invproofirrelevance (@paths X x y) (fun e1 => (fun e2 => (uu_pathscomp0 (@paths X x y) e1 (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (idpath x)))) (p y (s y e1))) e2 (match e1 as ep0 in (paths _ bp0) return ((fun yp => (fun ep => (@paths (@paths X x yp) ep (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (p x (s x (idpath x)))) (p yp (s yp ep)))))) bp0 ep0) with idpath _ => (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (p x (s x (idpath x)))) (p x (s x (idpath x)))) (idpath x) (uu_pathsinv0l X x x (p x (s x (idpath x))))) end) (uu_pathscomp0 (@paths X x y) (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (idpath x)))) (p y (s y e1))) (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (idpath x)))) (p y (s y e2))) e2 (uu_maponpaths (@paths X x y) (@paths X x y) (fun r => (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (idpath x)))) r)) (p y (s y e1)) (p y (s y e2)) (uu_maponpaths (PF y) (@paths X x y) (p y) (s y e1) (s y e2) (pr1 ((ip y) (s y e1) (s y e2))))) (uu_pathsinv0 (@paths X x y) e2 (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (idpath x)))) (p y (s y e2))) (match e2 as ep0 in (paths _ bp0) return ((fun yp => (fun ep => (@paths (@paths X x yp) ep (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (p x (s x (idpath x)))) (p yp (s yp ep)))))) bp0 ep0) with idpath _ => (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (p x (s x (idpath x)))) (p x (s x (idpath x)))) (idpath x) (uu_pathsinv0l X x x (p x (s x (idpath x))))) end)))))))))))))).
Definition uu_natplusl0 : (forall n : nat, (@paths nat (uu_add 0 n) n)) :=
  (fun n => (idpath n)).
Definition uu_natplusnsm : (forall n : nat, (forall m : nat, (@paths nat (uu_add n (S m)) (uu_add (S n) m)))) :=
  (fun n => (fun m => (nat_rect (fun q => (@paths nat (uu_add q (S m)) (uu_add (S q) m))) (idpath (S m)) (fun k => (fun IH => (uu_maponpaths nat nat (fun w => (S w)) (uu_add k (S m)) (uu_add (S k) m) IH))) n))).
Definition uu_natpluscomm : (forall n : nat, (forall m : nat, (@paths nat (uu_add n m) (uu_add m n)))) :=
  (fun n => (fun m => (nat_rect (fun q => (@paths nat (uu_add q m) (uu_add m q))) (uu_pathsinv0 nat (uu_add m 0) m (uu_natplusr0 m)) (fun k => (fun IH => (uu_pathscomp0 nat (uu_add (S k) m) (uu_add (S m) k) (uu_add m (S k)) (uu_maponpaths nat nat (fun w => (S w)) (uu_add k m) (uu_add m k) IH) (uu_pathsinv0 nat (uu_add m (S k)) (uu_add (S m) k) (uu_natplusnsm m k))))) n))).
Definition uu_natplusassoc : (forall n : nat, (forall m : nat, (forall k : nat, (@paths nat (uu_add (uu_add n m) k) (uu_add n (uu_add m k)))))) :=
  (fun n => (fun m => (fun k => (nat_rect (fun q => (@paths nat (uu_add (uu_add q m) k) (uu_add q (uu_add m k)))) (idpath (uu_add m k)) (fun j => (fun IH => (uu_maponpaths nat nat (fun w => (S w)) (uu_add (uu_add j m) k) (uu_add j (uu_add m k)) IH))) n)))).
Definition uu_mul : (forall n : nat, (forall m : nat, nat)) :=
  (fun n => (fun m => (nat_rect (fun q => nat) 0 (fun p => (fun pm => (uu_add pm m))) n))).
Definition uu_natmult0n : (forall n : nat, (@paths nat (uu_mul 0 n) 0)) :=
  (fun n => (idpath 0)).
Definition uu_natmultn0 : (forall n : nat, (@paths nat (uu_mul n 0) 0)) :=
  (fun n => (nat_rect (fun q => (@paths nat (uu_mul q 0) 0)) (idpath 0) (fun p => (fun IH => (uu_pathscomp0 nat (uu_add (uu_mul p 0) 0) (uu_mul p 0) 0 (uu_natplusr0 (uu_mul p 0)) IH))) n)).
Definition uu_hinhfun : (forall X : Type, (forall Y : Type, (forall f : (forall x : X, Y), (forall w : (uu_ishinh_UU X), (uu_ishinh_UU Y))))) :=
  (fun X => (fun Y => (fun f => (fun w => (fun P => (fun g => (w P (fun x => (g (f x)))))))))).
Definition uu_hinhand : (forall X : Type, (forall Y : Type, (forall w1 : (uu_ishinh_UU X), (forall w2 : (uu_ishinh_UU Y), (uu_ishinh_UU (total2 (fun q : X => Y))))))) :=
  (fun X => (fun Y => (fun w1 => (fun w2 => (fun P => (fun g => (w1 P (fun x => (w2 P (fun y => (g (tpair x y)))))))))))).
Definition uu_multsnm : (forall n : nat, (forall m : nat, (@paths nat (uu_mul (S n) m) (uu_add m (uu_mul n m))))) :=
  (fun n => (fun m => (uu_natpluscomm (uu_mul n m) m))).
Definition uu_multnsm : (forall n : nat, (forall m : nat, (@paths nat (uu_mul n (S m)) (uu_add n (uu_mul n m))))) :=
  (fun n => (fun m => (nat_rect (fun q => (@paths nat (uu_mul q (S m)) (uu_add q (uu_mul q m)))) (idpath 0) (fun k => (fun IH => (uu_pathscomp0 nat (uu_mul (S k) (S m)) (uu_add (uu_add k (uu_mul k m)) (S m)) (uu_add (S k) (uu_mul (S k) m)) (uu_maponpaths nat nat (fun w => (uu_add w (S m))) (uu_mul k (S m)) (uu_add k (uu_mul k m)) IH) (uu_pathscomp0 nat (uu_add (uu_add k (uu_mul k m)) (S m)) (uu_add k (uu_add (uu_mul k m) (S m))) (uu_add (S k) (uu_mul (S k) m)) (uu_natplusassoc k (uu_mul k m) (S m)) (uu_pathscomp0 nat (uu_add k (uu_add (uu_mul k m) (S m))) (uu_add k (uu_add (S (uu_mul k m)) m)) (uu_add (S k) (uu_mul (S k) m)) (uu_maponpaths nat nat (fun w => (uu_add k w)) (uu_add (uu_mul k m) (S m)) (uu_add (S (uu_mul k m)) m) (uu_natplusnsm (uu_mul k m) m)) (uu_natplusnsm k (uu_add (uu_mul k m) m))))))) n))).
Definition uu_natmultcomm : (forall n : nat, (forall m : nat, (@paths nat (uu_mul n m) (uu_mul m n)))) :=
  (fun n => (fun m => (nat_rect (fun q => (@paths nat (uu_mul q m) (uu_mul m q))) (uu_pathsinv0 nat (uu_mul m 0) 0 (uu_natmultn0 m)) (fun k => (fun IH => (uu_pathscomp0 nat (uu_mul (S k) m) (uu_add m (uu_mul k m)) (uu_mul m (S k)) (uu_multsnm k m) (uu_pathscomp0 nat (uu_add m (uu_mul k m)) (uu_add m (uu_mul m k)) (uu_mul m (S k)) (uu_maponpaths nat nat (fun w => (uu_add m w)) (uu_mul k m) (uu_mul m k) IH) (uu_pathsinv0 nat (uu_mul m (S k)) (uu_add m (uu_mul m k)) (uu_multnsm m k)))))) n))).
Definition uu_natrdistr : (forall n : nat, (forall m : nat, (forall k : nat, (@paths nat (uu_mul (uu_add n m) k) (uu_add (uu_mul n k) (uu_mul m k)))))) :=
  (fun n => (fun m => (fun k => (nat_rect (fun q => (@paths nat (uu_mul (uu_add q m) k) (uu_add (uu_mul q k) (uu_mul m k)))) (idpath (uu_mul m k)) (fun j => (fun IH => (uu_pathscomp0 nat (uu_mul (uu_add (S j) m) k) (uu_add (uu_add (uu_mul j k) (uu_mul m k)) k) (uu_add (uu_mul (S j) k) (uu_mul m k)) (uu_maponpaths nat nat (fun w => (uu_add w k)) (uu_mul (uu_add j m) k) (uu_add (uu_mul j k) (uu_mul m k)) IH) (uu_pathscomp0 nat (uu_add (uu_add (uu_mul j k) (uu_mul m k)) k) (uu_add (uu_mul j k) (uu_add (uu_mul m k) k)) (uu_add (uu_mul (S j) k) (uu_mul m k)) (uu_natplusassoc (uu_mul j k) (uu_mul m k) k) (uu_pathscomp0 nat (uu_add (uu_mul j k) (uu_add (uu_mul m k) k)) (uu_add (uu_mul j k) (uu_add k (uu_mul m k))) (uu_add (uu_mul (S j) k) (uu_mul m k)) (uu_maponpaths nat nat (fun w => (uu_add (uu_mul j k) w)) (uu_add (uu_mul m k) k) (uu_add k (uu_mul m k)) (uu_natpluscomm (uu_mul m k) k)) (uu_pathsinv0 nat (uu_add (uu_add (uu_mul j k) k) (uu_mul m k)) (uu_add (uu_mul j k) (uu_add k (uu_mul m k))) (uu_natplusassoc (uu_mul j k) k (uu_mul m k)))))))) n)))).
Definition uu_natldistr : (forall m : nat, (forall k : nat, (forall n : nat, (@paths nat (uu_mul n (uu_add m k)) (uu_add (uu_mul n m) (uu_mul n k)))))) :=
  (fun m => (fun k => (fun n => (nat_rect (fun q => (@paths nat (uu_mul n (uu_add q k)) (uu_add (uu_mul n q) (uu_mul n k)))) (uu_maponpaths nat nat (fun w => (uu_add w (uu_mul n k))) 0 (uu_mul n 0) (uu_pathsinv0 nat (uu_mul n 0) 0 (uu_natmultn0 n))) (fun j => (fun IH => (uu_pathscomp0 nat (uu_mul n (uu_add (S j) k)) (uu_add n (uu_mul n (uu_add j k))) (uu_add (uu_mul n (S j)) (uu_mul n k)) (uu_multnsm n (uu_add j k)) (uu_pathscomp0 nat (uu_add n (uu_mul n (uu_add j k))) (uu_add n (uu_add (uu_mul n j) (uu_mul n k))) (uu_add (uu_mul n (S j)) (uu_mul n k)) (uu_maponpaths nat nat (fun w => (uu_add n w)) (uu_mul n (uu_add j k)) (uu_add (uu_mul n j) (uu_mul n k)) IH) (uu_pathscomp0 nat (uu_add n (uu_add (uu_mul n j) (uu_mul n k))) (uu_add (uu_add n (uu_mul n j)) (uu_mul n k)) (uu_add (uu_mul n (S j)) (uu_mul n k)) (uu_pathsinv0 nat (uu_add (uu_add n (uu_mul n j)) (uu_mul n k)) (uu_add n (uu_add (uu_mul n j) (uu_mul n k))) (uu_natplusassoc n (uu_mul n j) (uu_mul n k))) (uu_maponpaths nat nat (fun w => (uu_add w (uu_mul n k))) (uu_add n (uu_mul n j)) (uu_mul n (S j)) (uu_pathsinv0 nat (uu_mul n (S j)) (uu_add n (uu_mul n j)) (uu_multnsm n j)))))))) m)))).
Definition uu_natmultassoc : (forall n : nat, (forall m : nat, (forall k : nat, (@paths nat (uu_mul (uu_mul n m) k) (uu_mul n (uu_mul m k)))))) :=
  (fun n => (fun m => (fun k => (nat_rect (fun q => (@paths nat (uu_mul (uu_mul q m) k) (uu_mul q (uu_mul m k)))) (idpath 0) (fun j => (fun IH => (uu_pathscomp0 nat (uu_mul (uu_mul (S j) m) k) (uu_add (uu_mul (uu_mul j m) k) (uu_mul m k)) (uu_mul (S j) (uu_mul m k)) (uu_natrdistr (uu_mul j m) m k) (uu_maponpaths nat nat (fun w => (uu_add w (uu_mul m k))) (uu_mul (uu_mul j m) k) (uu_mul j (uu_mul m k)) IH)))) n)))).
Definition uu_natmultl1 : (forall n : nat, (@paths nat (uu_mul 1 n) n)) :=
  (fun n => (idpath n)).
Definition uu_natmultr1 : (forall n : nat, (@paths nat (uu_mul n 1) n)) :=
  (fun n => (uu_pathscomp0 nat (uu_mul n 1) (uu_mul 1 n) n (uu_natmultcomm n 1) (uu_natmultl1 n))).
Definition uu_uu_app : (forall n : nat, (forall x : nat, nat)) :=
  (fun n => (fun x => (nat_rect (fun q => nat) 1 (fun p => (fun r => (uu_mul x r))) n))).
Definition uu_uu_app_const1 : (forall x : nat, (@paths nat (uu_uu_app 0 x) 1)) :=
  (fun x => (idpath 1)).
Definition uu_uu_app_ident : (forall x : nat, (@paths nat (uu_uu_app 1 x) x)) :=
  (fun x => (uu_natmultr1 x)).
Definition uu_uu_app_const_of_const : (forall x : nat, (@paths nat (uu_uu_app (uu_uu_app 0 0) x) x)) :=
  (fun x => (uu_natmultr1 x)).
Definition uu_uu_app_3_2 : (@paths nat (uu_uu_app 3 2) 8) :=
  (idpath 8).
Definition uu_uu_app_tower : (@paths nat (uu_uu_app (uu_uu_app 2 3) 4) 262144) :=
  (idpath 262144).
Definition uu_natgtb : (forall n : nat, (forall m : nat, bool)) :=
  (fun n => (nat_rect (fun q => (forall m : nat, bool)) (fun m => false) (fun k => (fun IH => (fun m => (nat_rect (fun r => bool) true (fun j => (fun u => (IH j))) m)))) n)).
Definition uu_natgth : (forall n : nat, (forall m : nat, uu_hProp)) :=
  (fun n => (fun m => (tpair (@paths bool (uu_natgtb n m) true) (uu_isasetbool (uu_natgtb n m) true)))).
Definition uu_negnatgth0n : (forall n : nat, (forall g : (@paths bool (uu_natgtb 0 n) true), Empty_set)) :=
  (fun n => (fun g => (uu_nopathsfalsetotrue g))).
Definition uu_natgthsnn : (forall n : nat, (@paths bool (uu_natgtb (S n) n) true)) :=
  (fun n => (nat_rect (fun q => (@paths bool (uu_natgtb (S q) q) true)) (idpath true) (fun k => (fun IH => IH)) n)).
Definition uu_natgthsn0 : (forall n : nat, (@paths bool (uu_natgtb (S n) 0) true)) :=
  (fun n => (idpath true)).
Definition uu_negnatgth0tois0 : (forall n : nat, (forall ng : (forall g : (@paths bool (uu_natgtb n 0) true), Empty_set), (@paths nat n 0))) :=
  (fun n => (nat_rect (fun q => (forall ng : (forall g : (@paths bool (uu_natgtb q 0) true), Empty_set), (@paths nat q 0))) (fun ng => (idpath 0)) (fun k => (fun IH => (fun ng => (uu_fromempty (@paths nat (S k) 0) (ng (uu_natgthsn0 k)))))) n)).
Definition uu_nat1gthtois0 : (forall n : nat, (forall g : (@paths bool (uu_natgtb 1 n) true), (@paths nat n 0))) :=
  (fun n => (nat_rect (fun q => (forall g : (@paths bool (uu_natgtb 1 q) true), (@paths nat q 0))) (fun g => (idpath 0)) (fun k => (fun IH => (fun g => (uu_fromempty (@paths nat (S k) 0) (uu_negnatgth0n k g))))) n)).
Definition uu_istransnatgth : (forall n : nat, (forall m : nat, (forall k : nat, (forall g : (@paths bool (uu_natgtb n m) true), (forall h : (@paths bool (uu_natgtb m k) true), (@paths bool (uu_natgtb n k) true)))))) :=
  (fun n => (nat_rect (fun q => (forall m : nat, (forall k : nat, (forall g : (@paths bool (uu_natgtb q m) true), (forall h : (@paths bool (uu_natgtb m k) true), (@paths bool (uu_natgtb q k) true)))))) (fun m => (fun k => (fun g => (fun h => (uu_fromempty (@paths bool (uu_natgtb 0 k) true) (uu_negnatgth0n m g)))))) (fun p => (fun IHn => (fun m => (nat_rect (fun r => (forall k : nat, (forall g : (@paths bool (uu_natgtb (S p) r) true), (forall h : (@paths bool (uu_natgtb r k) true), (@paths bool (uu_natgtb (S p) k) true))))) (fun k => (fun g => (fun h => (uu_fromempty (@paths bool (uu_natgtb (S p) k) true) (uu_negnatgth0n k h))))) (fun q => (fun u => (fun k => (nat_rect (fun s => (forall g : (@paths bool (uu_natgtb (S p) (S q)) true), (forall h : (@paths bool (uu_natgtb (S q) s) true), (@paths bool (uu_natgtb (S p) s) true)))) (fun g => (fun h => (idpath true))) (fun j => (fun v => (fun g => (fun h => (IHn q j g h))))) k)))) m)))) n)).
Definition uu_isirreflnatgth : (forall n : nat, (forall g : (@paths bool (uu_natgtb n n) true), Empty_set)) :=
  (fun n => (nat_rect (fun q => (forall g : (@paths bool (uu_natgtb q q) true), Empty_set)) (fun g => (uu_negnatgth0n 0 g)) (fun k => (fun IH => IH)) n)).
Definition uu_isasymmnatgth : (forall n : nat, (forall m : nat, (forall g : (@paths bool (uu_natgtb n m) true), (forall h : (@paths bool (uu_natgtb m n) true), Empty_set)))) :=
  (fun n => (fun m => (fun g => (fun h => (uu_isirreflnatgth n (uu_istransnatgth n m n g h)))))).
Definition uu_natgthandplusl : (forall n : nat, (forall m : nat, (forall k : nat, (forall g : (@paths bool (uu_natgtb n m) true), (@paths bool (uu_natgtb (uu_add k n) (uu_add k m)) true))))) :=
  (fun n => (fun m => (fun k => (fun g => (nat_rect (fun q => (@paths bool (uu_natgtb (uu_add q n) (uu_add q m)) true)) g (fun p => (fun IH => IH)) k))))).
Definition uu_natgthandplusr : (forall n : nat, (forall m : nat, (forall k : nat, (forall g : (@paths bool (uu_natgtb n m) true), (@paths bool (uu_natgtb (uu_add n k) (uu_add m k)) true))))) :=
  (fun n => (fun m => (fun k => (fun g => (uu_pathscomp0 bool (uu_natgtb (uu_add n k) (uu_add m k)) (uu_natgtb (uu_add k n) (uu_add k m)) true (uu_pathscomp0 bool (uu_natgtb (uu_add n k) (uu_add m k)) (uu_natgtb (uu_add k n) (uu_add m k)) (uu_natgtb (uu_add k n) (uu_add k m)) (uu_maponpaths nat bool (fun w => (uu_natgtb w (uu_add m k))) (uu_add n k) (uu_add k n) (uu_natpluscomm n k)) (uu_maponpaths nat bool (fun w => (uu_natgtb (uu_add k n) w)) (uu_add m k) (uu_add k m) (uu_natpluscomm m k))) (uu_natgthandplusl n m k g)))))).
Definition uu_natgthandmultl : (forall n : nat, (forall m : nat, (forall k : nat, (forall g : (@paths bool (uu_natgtb n m) true), (@paths bool (uu_natgtb (uu_mul (S k) n) (uu_mul (S k) m)) true))))) :=
  (fun n => (fun m => (fun k => (fun g => (nat_rect (fun q => (@paths bool (uu_natgtb (uu_mul (S q) n) (uu_mul (S q) m)) true)) g (fun p => (fun IH => (uu_istransnatgth (uu_add (uu_mul (S p) n) n) (uu_add (uu_mul (S p) m) n) (uu_add (uu_mul (S p) m) m) (uu_natgthandplusr (uu_mul (S p) n) (uu_mul (S p) m) n IH) (uu_natgthandplusl n m (uu_mul (S p) m) g)))) k))))).
Definition uu_natlth : (forall n : nat, (forall m : nat, uu_hProp)) :=
  (fun n => (fun m => (uu_natgth m n))).
Definition uu_natleh : (forall n : nat, (forall m : nat, uu_hProp)) :=
  (fun n => (fun m => (tpair (@paths bool (uu_natgtb n m) false) (uu_isasetbool (uu_natgtb n m) false)))).
Definition uu_natgeh : (forall n : nat, (forall m : nat, uu_hProp)) :=
  (fun n => (fun m => (uu_natleh m n))).
Definition uu_natgthorleh : (forall n : nat, (forall m : nat, (sum (@paths bool (uu_natgtb n m) true) (@paths bool (uu_natgtb n m) false)))) :=
  (fun n => (fun m => (bool_rect (fun b => (sum (@paths bool b true) (@paths bool b false))) (inl (idpath true)) (inr (idpath false)) (uu_natgtb n m)))).
Definition uu_isreflnatleh : (forall n : nat, (@paths bool (uu_natgtb n n) false)) :=
  (fun n => (nat_rect (fun q => (@paths bool (uu_natgtb q q) false)) (idpath false) (fun k => (fun IH => IH)) n)).
Definition uu_istransnatleh : (forall n : nat, (forall m : nat, (forall k : nat, (forall g : (@paths bool (uu_natgtb n m) false), (forall h : (@paths bool (uu_natgtb m k) false), (@paths bool (uu_natgtb n k) false)))))) :=
  (fun n => (nat_rect (fun q => (forall m : nat, (forall k : nat, (forall g : (@paths bool (uu_natgtb q m) false), (forall h : (@paths bool (uu_natgtb m k) false), (@paths bool (uu_natgtb q k) false)))))) (fun m => (fun k => (fun g => (fun h => (idpath false))))) (fun p => (fun IHn => (fun m => (nat_rect (fun r => (forall k : nat, (forall g : (@paths bool (uu_natgtb (S p) r) false), (forall h : (@paths bool (uu_natgtb r k) false), (@paths bool (uu_natgtb (S p) k) false))))) (fun k => (fun g => (fun h => (uu_fromempty (@paths bool (uu_natgtb (S p) k) false) (uu_nopathstruetofalse g))))) (fun q => (fun u => (fun k => (nat_rect (fun s => (forall g : (@paths bool (uu_natgtb (S p) (S q)) false), (forall h : (@paths bool (uu_natgtb (S q) s) false), (@paths bool (uu_natgtb (S p) s) false)))) (fun g => (fun h => (uu_fromempty (@paths bool (uu_natgtb (S p) 0) false) (uu_nopathstruetofalse h)))) (fun j => (fun v => (fun g => (fun h => (IHn q j g h))))) k)))) m)))) n)).
Definition uu_isantisymmnatleh : (forall n : nat, (forall m : nat, (forall g : (@paths bool (uu_natgtb n m) false), (forall h : (@paths bool (uu_natgtb m n) false), (@paths nat n m))))) :=
  (fun n => (nat_rect (fun q => (forall m : nat, (forall g : (@paths bool (uu_natgtb q m) false), (forall h : (@paths bool (uu_natgtb m q) false), (@paths nat q m))))) (fun m => (nat_rect (fun r => (forall g : (@paths bool (uu_natgtb 0 r) false), (forall h : (@paths bool (uu_natgtb r 0) false), (@paths nat 0 r)))) (fun g => (fun h => (idpath 0))) (fun mp => (fun u => (fun g => (fun h => (uu_fromempty (@paths nat 0 (S mp)) (uu_nopathstruetofalse h)))))) m)) (fun p => (fun IHn => (fun m => (nat_rect (fun r => (forall g : (@paths bool (uu_natgtb (S p) r) false), (forall h : (@paths bool (uu_natgtb r (S p)) false), (@paths nat (S p) r)))) (fun g => (fun h => (uu_fromempty (@paths nat (S p) 0) (uu_nopathstruetofalse g)))) (fun q => (fun u => (fun g => (fun h => (uu_maponpaths nat nat (fun w => (S w)) p q (IHn q g h)))))) m)))) n)).
Definition uu_natlehtonegnatgth : (forall n : nat, (forall m : nat, (forall p : (@paths bool (uu_natgtb n m) false), (forall q : (@paths bool (uu_natgtb n m) true), Empty_set)))) :=
  (fun n => (fun m => (fun p => (fun q => (uu_nopathstruetofalse (uu_pathscomp0 bool true (uu_natgtb n m) false (uu_pathsinv0 bool (uu_natgtb n m) true q) p)))))).
Definition uu_negnatgthtoleh : (forall n : nat, (forall m : nat, (forall ng : (forall q : (@paths bool (uu_natgtb n m) true), Empty_set), (@paths bool (uu_natgtb n m) false)))) :=
  (fun n => (fun m => (fun ng => ((bool_rect (fun b => (forall g : (forall q : (@paths bool b true), Empty_set), (@paths bool b false))) (fun g => (uu_fromempty (@paths bool true false) (g (idpath true)))) (fun g => (idpath false)) (uu_natgtb n m)) ng)))).
Definition uu_natlthtoleh : (forall n : nat, (forall m : nat, (forall g : (@paths bool (uu_natgtb m n) true), (@paths bool (uu_natgtb n m) false)))) :=
  (fun n => (fun m => (fun g => (uu_negnatgthtoleh n m (fun q => (uu_isasymmnatgth n m q g)))))).
Definition uu_natminus : (forall n : nat, (forall m : nat, nat)) :=
  (fun n => (nat_rect (fun x => (forall m : nat, nat)) (fun m => 0) (fun k => (fun IH => (fun m => (nat_rect (fun y => nat) (S k) (fun j => (fun u => (IH j))) m)))) n)).
Definition uu_natminus0n : (forall n : nat, (@paths nat (uu_natminus 0 n) 0)) :=
  (fun n => (idpath 0)).
Definition uu_natminusn0 : (forall n : nat, (@paths nat (uu_natminus n 0) n)) :=
  (fun n => (nat_rect (fun q => (@paths nat (uu_natminus q 0) q)) (idpath 0) (fun k => (fun IH => (idpath (S k)))) n)).
Definition uu_natminusnn : (forall n : nat, (@paths nat (uu_natminus n n) 0)) :=
  (fun n => (nat_rect (fun q => (@paths nat (uu_natminus q q) 0)) (idpath 0) (fun k => (fun IH => IH)) n)).
Definition uu_natlehsucc : (forall a : nat, (forall k : nat, (forall g : (@paths bool (uu_natgtb a k) false), (@paths bool (uu_natgtb a (S k)) false)))) :=
  (fun a => (nat_rect (fun q => (forall k : nat, (forall g : (@paths bool (uu_natgtb q k) false), (@paths bool (uu_natgtb q (S k)) false)))) (fun k => (fun g => (idpath false))) (fun a' => (fun IH => (fun k => (nat_rect (fun r => (forall g : (@paths bool (uu_natgtb (S a') r) false), (@paths bool (uu_natgtb (S a') (S r)) false))) (fun g => (uu_fromempty (@paths bool (uu_natgtb (S a') (S 0)) false) (uu_nopathstruetofalse g))) (fun k' => (fun u => (fun g => (IH k' g)))) k)))) a)).
Definition uu_natminusleh : (forall n : nat, (forall m : nat, (@paths bool (uu_natgtb (uu_natminus n m) n) false))) :=
  (fun n => (nat_rect (fun q => (forall m : nat, (@paths bool (uu_natgtb (uu_natminus q m) q) false))) (fun m => (idpath false)) (fun k => (fun IHn => (fun m => (nat_rect (fun r => (@paths bool (uu_natgtb (uu_natminus (S k) r) (S k)) false)) (uu_isreflnatleh k) (fun j => (fun u => (uu_natlehsucc (uu_natminus k j) k (IHn j)))) m)))) n)).
Definition uu_natminusplusnmm : (forall n : nat, (forall m : nat, (forall h : (@paths bool (uu_natgtb m n) false), (@paths nat (uu_add (uu_natminus n m) m) n)))) :=
  (fun n => (nat_rect (fun q => (forall m : nat, (forall h : (@paths bool (uu_natgtb m q) false), (@paths nat (uu_add (uu_natminus q m) m) q)))) (fun m => (nat_rect (fun r => (forall h : (@paths bool (uu_natgtb r 0) false), (@paths nat (uu_add (uu_natminus 0 r) r) 0))) (fun h => (idpath 0)) (fun m' => (fun u => (fun h => (uu_fromempty (@paths nat (uu_add (uu_natminus 0 (S m')) (S m')) 0) (uu_nopathstruetofalse h))))) m)) (fun n' => (fun IHn => (fun m => (nat_rect (fun r => (forall h : (@paths bool (uu_natgtb r (S n')) false), (@paths nat (uu_add (uu_natminus (S n') r) r) (S n')))) (fun h => (uu_natplusr0 (S n'))) (fun m' => (fun u => (fun h => (uu_pathscomp0 nat (uu_add (uu_natminus (S n') (S m')) (S m')) (uu_add (S (uu_natminus n' m')) m') (S n') (uu_natplusnsm (uu_natminus n' m') m') (uu_maponpaths nat nat (fun w => (S w)) (uu_add (uu_natminus n' m') m') n' (IHn m' h)))))) m)))) n)).
Definition uu_natlehandminusl : (forall n : nat, (forall m : nat, (forall k : nat, (forall h : (@paths bool (uu_natgtb n m) false), (@paths bool (uu_natgtb (uu_natminus n k) (uu_natminus m k)) false))))) :=
  (fun n => (nat_rect (fun q => (forall m : nat, (forall k : nat, (forall h : (@paths bool (uu_natgtb q m) false), (@paths bool (uu_natgtb (uu_natminus q k) (uu_natminus m k)) false))))) (fun m => (fun k => (fun h => (idpath false)))) (fun n' => (fun IHn => (fun m => (nat_rect (fun mr => (forall k : nat, (forall h : (@paths bool (uu_natgtb (S n') mr) false), (@paths bool (uu_natgtb (uu_natminus (S n') k) (uu_natminus mr k)) false)))) (fun k => (fun h => (uu_fromempty (@paths bool (uu_natgtb (uu_natminus (S n') k) (uu_natminus 0 k)) false) (uu_nopathstruetofalse h)))) (fun m' => (fun um => (fun k => (nat_rect (fun kr => (forall h : (@paths bool (uu_natgtb (S n') (S m')) false), (@paths bool (uu_natgtb (uu_natminus (S n') kr) (uu_natminus (S m') kr)) false))) (fun h => h) (fun k' => (fun uk => (fun h => (IHn m' k' h)))) k)))) m)))) n)).
Definition uu_natlehandminusr : (forall n : nat, (forall m : nat, (forall k : nat, (forall h : (@paths bool (uu_natgtb k m) false), (@paths bool (uu_natgtb (uu_natminus n m) (uu_natminus n k)) false))))) :=
  (fun n => (nat_rect (fun q => (forall m : nat, (forall k : nat, (forall h : (@paths bool (uu_natgtb k m) false), (@paths bool (uu_natgtb (uu_natminus q m) (uu_natminus q k)) false))))) (fun m => (fun k => (fun h => (idpath false)))) (fun n' => (fun IHn => (fun m => (nat_rect (fun mr => (forall k : nat, (forall h : (@paths bool (uu_natgtb k mr) false), (@paths bool (uu_natgtb (uu_natminus (S n') mr) (uu_natminus (S n') k)) false)))) (fun k => (nat_rect (fun kr => (forall h : (@paths bool (uu_natgtb kr 0) false), (@paths bool (uu_natgtb (uu_natminus (S n') 0) (uu_natminus (S n') kr)) false))) (fun h => (uu_isreflnatleh n')) (fun k' => (fun uk => (fun h => (uu_fromempty (@paths bool (uu_natgtb (uu_natminus (S n') 0) (uu_natminus (S n') (S k'))) false) (uu_nopathstruetofalse h))))) k)) (fun m' => (fun um => (fun k => (nat_rect (fun kr => (forall h : (@paths bool (uu_natgtb kr (S m')) false), (@paths bool (uu_natgtb (uu_natminus (S n') (S m')) (uu_natminus (S n') kr)) false))) (fun h => (uu_natlehsucc (uu_natminus n' m') n' (uu_natminusleh n' m'))) (fun k' => (fun uk => (fun h => (IHn m' k' h)))) k)))) m)))) n)).
Definition uu_nvec : (forall n : nat, Type) :=
  (fun n => (nat_rect (fun q => Type) unit (fun k => (fun r => (total2 (fun h : nat => r)))) n)).
Definition uu_nlist : Type :=
  (total2 (fun n : nat => (uu_nvec n))).
Definition uu_nnil : uu_nlist :=
  (tpair 0 tt).
Definition uu_ncons : (forall x : nat, (forall l : uu_nlist, uu_nlist)) :=
  (fun x => (fun l => (tpair (S (pr1 l)) (tpair x (pr2 l))))).
Definition uu_nlen : (forall l : uu_nlist, nat) :=
  (fun l => (pr1 l)).
Definition uu_lapp : (forall a : uu_nlist, (forall b : uu_nlist, uu_nlist)) :=
  (fun a => (fun b => ((nat_rect (fun q => (forall v : (uu_nvec q), uu_nlist)) (fun v => b) (fun k => (fun IH => (fun v => (uu_ncons (pr1 v) (IH (pr2 v)))))) (pr1 a)) (pr2 a)))).
Definition uu_lrev : (forall a : uu_nlist, uu_nlist) :=
  (fun a => ((nat_rect (fun q => (forall v : (uu_nvec q), uu_nlist)) (fun v => uu_nnil) (fun k => (fun IH => (fun v => (uu_lapp (IH (pr2 v)) (uu_ncons (pr1 v) uu_nnil))))) (pr1 a)) (pr2 a))).
Definition uu_orb : (forall a : bool, (forall b : bool, bool)) :=
  (fun a => (fun b => (bool_rect (fun x => bool) true b a))).
Definition uu_andb : (forall a : bool, (forall b : bool, bool)) :=
  (fun a => (fun b => (bool_rect (fun x => bool) b false a))).
Definition uu_nateqb : (forall n : nat, (forall m : nat, bool)) :=
  (fun n => ((nat_rect (fun q => (forall m : nat, bool)) (fun m => (nat_rect (fun q => bool) true (fun k => (fun r => false)) m)) (fun k => (fun IH => (fun m => (nat_rect (fun q => bool) false (fun j => (fun r => (IH j))) m)))) n))).
Definition uu_memb : (forall w : nat, (forall l : uu_nlist, bool)) :=
  (fun w => (fun l => ((nat_rect (fun q => (forall v : (uu_nvec q), bool)) (fun v => false) (fun k => (fun IH => (fun v => (uu_orb (uu_nateqb w (pr1 v)) (IH (pr2 v)))))) (pr1 l)) (pr2 l)))).
Definition uu_nodupb : (forall l : uu_nlist, bool) :=
  (fun l => ((nat_rect (fun q => (forall v : (uu_nvec q), bool)) (fun v => true) (fun k => (fun IH => (fun v => (uu_andb (uu_negb (uu_memb (pr1 v) (tpair k (pr2 v)))) (IH (pr2 v)))))) (pr1 l)) (pr2 l))).
Definition uu_stk : Type :=
  (total2 (fun f : nat => (total2 (fun u : uu_nlist => uu_nlist)))).
Definition uu_zmk : (forall f : nat, (forall u : uu_nlist, (forall d : uu_nlist, uu_stk))) :=
  (fun f => (fun u => (fun d => (tpair f (tpair u d))))).
Definition uu_zfoc : (forall z : uu_stk, nat) :=
  (fun z => (pr1 z)).
Definition uu_zup : (forall z : uu_stk, uu_nlist) :=
  (fun z => (pr1 (pr2 z))).
Definition uu_zdn : (forall z : uu_stk, uu_nlist) :=
  (fun z => (pr2 (pr2 z))).
Definition uu_zins : (forall w : nat, (forall z : uu_stk, uu_stk)) :=
  (fun w => (fun z => (uu_zmk w (uu_zup z) (uu_ncons (uu_zfoc z) (uu_zdn z))))).
Definition uu_zrow : (forall z : uu_stk, uu_nlist) :=
  (fun z => (uu_lapp (uu_lrev (uu_zup z)) (uu_ncons (uu_zfoc z) (uu_zdn z)))).
Definition uu_zcount : (forall z : uu_stk, nat) :=
  (fun z => (S (uu_add (uu_nlen (uu_zup z)) (uu_nlen (uu_zdn z))))).
Definition uu_zsane : (forall z : uu_stk, bool) :=
  (fun z => (uu_nodupb (uu_zrow z))).
Definition uu_zfocins : (forall w : nat, (forall z : uu_stk, (@paths nat (uu_zfoc (uu_zins w z)) w))) :=
  (fun w => (fun z => (idpath w))).
Definition uu_zcountins : (forall w : nat, (forall z : uu_stk, (@paths nat (uu_zcount (uu_zins w z)) (S (uu_zcount z))))) :=
  (fun w => (fun z => (uu_maponpaths nat nat (fun q => (S q)) (uu_add (uu_nlen (uu_zup z)) (S (uu_nlen (uu_zdn z)))) (S (uu_add (uu_nlen (uu_zup z)) (uu_nlen (uu_zdn z)))) (uu_natplusnsm (uu_nlen (uu_zup z)) (uu_nlen (uu_zdn z)))))).
Definition uu_hd0 : (forall l : uu_nlist, nat) :=
  (fun l => ((nat_rect (fun q => (forall v : (uu_nvec q), nat)) (fun v => 0) (fun k => (fun IH => (fun v => (pr1 v)))) (pr1 l)) (pr2 l))).
Definition uu_tl0 : (forall l : uu_nlist, uu_nlist) :=
  (fun l => ((nat_rect (fun q => (forall v : (uu_nvec q), uu_nlist)) (fun v => uu_nnil) (fun k => (fun IH => (fun v => (tpair k (pr2 v))))) (pr1 l)) (pr2 l))).
Definition uu_zrev : (forall z : uu_stk, uu_stk) :=
  (fun z => (uu_zmk (uu_zfoc z) (uu_zdn z) (uu_zup z))).
Definition uu_zfocup : (forall z : uu_stk, uu_stk) :=
  (fun z => (nat_rect (fun q => uu_stk) (let a := (uu_lrev (uu_ncons (uu_zfoc z) (uu_zdn z))) in (uu_zmk (uu_hd0 a) (uu_tl0 a) uu_nnil)) (fun k => (fun r => (uu_zmk (uu_hd0 (uu_zup z)) (uu_tl0 (uu_zup z)) (uu_ncons (uu_zfoc z) (uu_zdn z))))) (pr1 (uu_zup z)))).
Definition uu_zfocdn : (forall z : uu_stk, uu_stk) :=
  (fun z => (uu_zrev (uu_zfocup (uu_zrev z)))).
Definition uu_zmaster : (forall z : uu_stk, uu_stk) :=
  (fun z => (uu_zmk (uu_zfoc z) uu_nnil (uu_lapp (uu_lrev (uu_zup z)) (uu_zdn z)))).
Definition uu_zrevrev : (forall z : uu_stk, (@paths uu_stk (uu_zrev (uu_zrev z)) z)) :=
  (fun z => (idpath z)).
Definition uu_orbfalsel : (forall a : bool, (forall b : bool, (forall h : (@paths bool (uu_orb a b) false), (@paths bool a false)))) :=
  (fun a => (bool_rect (fun a2 => (forall b : bool, (forall h : (@paths bool (uu_orb a2 b) false), (@paths bool a2 false)))) (fun b => (fun h => h)) (fun b => (fun h => (idpath false))) a)).
Definition uu_orbfalser : (forall a : bool, (forall b : bool, (forall h : (@paths bool (uu_orb a b) false), (@paths bool b false)))) :=
  (fun a => (bool_rect (fun a2 => (forall b : bool, (forall h : (@paths bool (uu_orb a2 b) false), (@paths bool b false)))) (fun b => (fun h => (uu_fromempty (@paths bool b false) (uu_nopathstruetofalse h)))) (fun b => (fun h => h)) a)).
Definition uu_andbtruel : (forall a : bool, (forall b : bool, (forall h : (@paths bool (uu_andb a b) true), (@paths bool a true)))) :=
  (fun a => (bool_rect (fun a2 => (forall b : bool, (forall h : (@paths bool (uu_andb a2 b) true), (@paths bool a2 true)))) (fun b => (fun h => (idpath true))) (fun b => (fun h => (uu_fromempty (@paths bool false true) (uu_nopathstruetofalse (uu_pathsinv0 bool false true h))))) a)).
Definition uu_andbtruer : (forall a : bool, (forall b : bool, (forall h : (@paths bool (uu_andb a b) true), (@paths bool b true)))) :=
  (fun a => (bool_rect (fun a2 => (forall b : bool, (forall h : (@paths bool (uu_andb a2 b) true), (@paths bool b true)))) (fun b => (fun h => h)) (fun b => (fun h => (uu_fromempty (@paths bool b true) (uu_nopathstruetofalse (uu_pathsinv0 bool false true h))))) a)).
Definition uu_negbtrue : (forall t : bool, (forall h : (@paths bool (uu_negb t) true), (@paths bool t false))) :=
  (fun t => (bool_rect (fun t2 => (forall h : (@paths bool (uu_negb t2) true), (@paths bool t2 false))) (fun h => (uu_fromempty (@paths bool true false) (uu_nopathstruetofalse (uu_pathsinv0 bool false true h)))) (fun h => (idpath false)) t)).
Definition uu_nateqbsymm : (forall n : nat, (forall m : nat, (@paths bool (uu_nateqb n m) (uu_nateqb m n)))) :=
  (fun n => (nat_rect (fun q => (forall m : nat, (@paths bool (uu_nateqb q m) (uu_nateqb m q)))) (fun m => (nat_rect (fun j => (@paths bool (uu_nateqb 0 j) (uu_nateqb j 0))) (idpath true) (fun j => (fun r => (idpath false))) m)) (fun k => (fun IH => (fun m => (nat_rect (fun j => (@paths bool (uu_nateqb (S k) j) (uu_nateqb j (S k)))) (idpath false) (fun j => (fun r => (IH j))) m)))) n)).
Definition uu_membmid : (forall u : nat, (forall w : nat, (forall b : uu_nlist, (forall hu : (@paths bool (uu_nateqb u w) false), (forall a : uu_nlist, (forall hm : (@paths bool (uu_memb u (uu_lapp a b)) false), (@paths bool (uu_memb u (uu_lapp a (uu_ncons w b))) false))))))) :=
  (fun u => (fun w => (fun b => (fun hu => (fun a => ((nat_rect (fun q => (forall v : (uu_nvec q), (forall hm : (@paths bool (uu_memb u (uu_lapp (tpair q v) b)) false), (@paths bool (uu_memb u (uu_lapp (tpair q v) (uu_ncons w b))) false)))) (fun v => (fun hm => (uu_pathscomp0 bool (uu_memb u (uu_ncons w b)) (uu_memb u b) false (uu_maponpaths bool bool (fun t => (uu_orb t (uu_memb u b))) (uu_nateqb u w) false hu) hm))) (fun k => (fun IH => (fun v => (fun hm => (uu_pathscomp0 bool (uu_orb (uu_nateqb u (pr1 v)) (uu_memb u (uu_lapp (tpair k (pr2 v)) (uu_ncons w b)))) (uu_memb u (uu_lapp (tpair k (pr2 v)) (uu_ncons w b))) false (uu_maponpaths bool bool (fun t => (uu_orb t (uu_memb u (uu_lapp (tpair k (pr2 v)) (uu_ncons w b))))) (uu_nateqb u (pr1 v)) false (uu_orbfalsel (uu_nateqb u (pr1 v)) (uu_memb u (uu_lapp (tpair k (pr2 v)) b)) hm)) (IH (pr2 v) (uu_orbfalser (uu_nateqb u (pr1 v)) (uu_memb u (uu_lapp (tpair k (pr2 v)) b)) hm))))))) (pr1 a)) (pr2 a))))))).
Definition uu_nodupmid : (forall w : nat, (forall b : uu_nlist, (forall a : uu_nlist, (forall hm : (@paths bool (uu_memb w (uu_lapp a b)) false), (forall hs : (@paths bool (uu_nodupb (uu_lapp a b)) true), (@paths bool (uu_nodupb (uu_lapp a (uu_ncons w b))) true)))))) :=
  (fun w => (fun b => (fun a => ((nat_rect (fun q => (forall v : (uu_nvec q), (forall hm : (@paths bool (uu_memb w (uu_lapp (tpair q v) b)) false), (forall hs : (@paths bool (uu_nodupb (uu_lapp (tpair q v) b)) true), (@paths bool (uu_nodupb (uu_lapp (tpair q v) (uu_ncons w b))) true))))) (fun v => (fun hm => (fun hs => (uu_pathscomp0 bool (uu_nodupb (uu_ncons w b)) (uu_nodupb b) true (uu_maponpaths bool bool (fun t => (uu_andb (uu_negb t) (uu_nodupb b))) (uu_memb w b) false hm) hs)))) (fun k => (fun IH => (fun v => (fun hm => (fun hs => (uu_pathscomp0 bool (uu_nodupb (uu_lapp (tpair (S k) v) (uu_ncons w b))) (uu_nodupb (uu_lapp (tpair k (pr2 v)) (uu_ncons w b))) true (uu_maponpaths bool bool (fun t => (uu_andb (uu_negb t) (uu_nodupb (uu_lapp (tpair k (pr2 v)) (uu_ncons w b))))) (uu_memb (pr1 v) (uu_lapp (tpair k (pr2 v)) (uu_ncons w b))) false (uu_membmid (pr1 v) w b (uu_pathscomp0 bool (uu_nateqb (pr1 v) w) (uu_nateqb w (pr1 v)) false (uu_nateqbsymm (pr1 v) w) (uu_orbfalsel (uu_nateqb w (pr1 v)) (uu_memb w (uu_lapp (tpair k (pr2 v)) b)) hm)) (tpair k (pr2 v)) (uu_negbtrue (uu_memb (pr1 v) (uu_lapp (tpair k (pr2 v)) b)) (uu_andbtruel (uu_negb (uu_memb (pr1 v) (uu_lapp (tpair k (pr2 v)) b))) (uu_nodupb (uu_lapp (tpair k (pr2 v)) b)) hs)))) (IH (pr2 v) (uu_orbfalser (uu_nateqb w (pr1 v)) (uu_memb w (uu_lapp (tpair k (pr2 v)) b)) hm) (uu_andbtruer (uu_negb (uu_memb (pr1 v) (uu_lapp (tpair k (pr2 v)) b))) (uu_nodupb (uu_lapp (tpair k (pr2 v)) b)) hs)))))))) (pr1 a)) (pr2 a))))).
Definition uu_zinsane : (forall w : nat, (forall z : uu_stk, (forall hm : (@paths bool (uu_memb w (uu_zrow z)) false), (forall hs : (@paths bool (uu_zsane z) true), (@paths bool (uu_zsane (uu_zins w z)) true))))) :=
  (fun w => (fun z => (uu_nodupmid w (uu_ncons (uu_zfoc z) (uu_zdn z)) (uu_lrev (uu_zup z))))).

(* === bridge: uu's nat ops ARE Coq's standard ones, so the laws above land on
   Nat.add / Nat.mul -- the operations spec.v's own laws speak. uu_add_std/uu_mul_std
   (induction over the shared recursion) tie them to the standard vocabulary, by which
   the headline arithmetic laws are RESTATED on Nat.* and discharged FROM ai's exports. *)
Lemma paths_to_eq : forall (A : Type) (a b : A), paths a b -> a = b.
Proof. intros A a b p; destruct p; reflexivity. Qed.
Lemma uu_add_std : forall n m, uu_add n m = Nat.add n m.
Proof. intros n m; induction n as [|n IHn]; [reflexivity|].
  change (uu_add (S n) m) with (S (uu_add n m)); rewrite IHn; reflexivity. Qed.
Lemma uu_mul_std : forall n m, uu_mul n m = Nat.mul n m.
Proof. intros n m; induction n as [|n IHn]; [reflexivity|].
  change (uu_mul (S n) m) with (uu_add (uu_mul n m) m);
  rewrite uu_add_std, IHn, Nat.add_comm; reflexivity. Qed.
Theorem add_comm_std : forall n m, Nat.add n m = Nat.add m n.
Proof. intros n m; rewrite <- (uu_add_std n m), <- (uu_add_std m n); apply paths_to_eq, uu_natpluscomm. Qed.
Theorem add_assoc_std : forall n m k, Nat.add (Nat.add n m) k = Nat.add n (Nat.add m k).
Proof. intros n m k; rewrite <- !uu_add_std; apply paths_to_eq, uu_natplusassoc. Qed.
Theorem mul_comm_std : forall n m, Nat.mul n m = Nat.mul m n.
Proof. intros n m; rewrite <- (uu_mul_std n m), <- (uu_mul_std m n); apply paths_to_eq, uu_natmultcomm. Qed.

Print Assumptions uu_natplusr0.
Print Assumptions uu_zcountins.
Print Assumptions uu_zinsane.
Print Assumptions add_comm_std.
Print Assumptions add_assoc_std.
Print Assumptions mul_comm_std.

(* 239 exported / 289 corpus entries swept;
   3 headline laws (add_comm, add_assoc, mul_comm) landed on Coq's Nat.* via the bridge *)
