/- proof/lean/uugen.lean -- GENERATED from test/uu.l by tools/uu2lean.l. Do not edit;
   regenerate with `make test_uulean`. The SAME uu proof terms Rocq certifies
   (proof/rocq/uugen.v) re-checked by a SECOND independent kernel, Lean 4 -- so each law
   is agreed by two unrelated implementations (the de Bruijn criterion, diversified).
   uu's kernel type-checked each term against its theorem (test/uu.l, green under
   `make test`); this is the same term in Lean. Lean gives structure-eta and universe
   polymorphism for free; `paths` is the Type-valued Id type (Lean's Eq is Prop) so a
   path can be a Sigma carrier. Only the univalence tower (an axm) is skipped, on its
   own via the dependency closure (counted at the foot). -/
set_option linter.unusedVariables false
set_option maxHeartbeats 4000000
set_option maxRecDepth 300000  -- uu_app_tower reduces a unary-Nat Church tower to 262144
universe u v
/- uu's paths: the Type-valued identity type (UniMath's `paths`), NOT Prop's Eq. -/
inductive paths {A : Type u} (a : A) : A -> Type u where
  | idpath : paths a a
/- Sigma as a structure -- Lean structures have definitional eta in the kernel. -/
structure total2 {A : Type u} (B : A -> Type v) : Type (max u v) where
  tpair ::
  pr1 : A
  pr2 : B pr1
/- the bridge shim: a Type-valued path eliminates into Prop's = -/
theorem paths_to_eq {A : Type u} {a b : A} (p : paths a b) : a = b := by cases p; rfl
/- CERTIFY, never run: defs use bare recursors the code generator rejects. -/
noncomputable section

@[reducible] def uu_idfun : (forall T : (Type _), (forall x : T, T)) :=
  (fun T => (fun x => x))
def uu_funcomp : (forall X : (Type _), (forall Y : (Type _), (forall Z : (Type _), (forall f : (forall x : X, Y), (forall g : (forall y : Y, Z), (forall x : X, Z)))))) :=
  (fun X => (fun Y => (fun Z => (fun f => (fun g => (fun x => (g (f x))))))))
def uu_iscontr : (forall T : (Type _), (Type _)) :=
  (fun T => (total2 (fun c : T => (forall t : T, (@paths T t c)))))
@[reducible] def uu_hfiber : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall y : Y, (Type _))))) :=
  (fun X => (fun Y => (fun f => (fun y => (total2 (fun x : X => (@paths Y (f x) y)))))))
def uu_isweq : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (Type _)))) :=
  (fun X => (fun Y => (fun f => (forall y : Y, (uu_iscontr (uu_hfiber X Y f y))))))
def uu_weq : (forall X : (Type _), (forall Y : (Type _), (Type _))) :=
  (fun X => (fun Y => (total2 (fun f : (forall x : X, Y) => (uu_isweq X Y f)))))
def uu_transportf : (forall A : (Type _), (forall P : (forall x : A, (Type _)), (forall a : A, (forall b : A, (forall e : (@paths A a b), (forall p : (P a), (P b))))))) :=
  (fun A => (fun P => (fun a => (fun b => (fun e => (paths.rec (motive := (fun bp => (fun ep => (forall p : (P a), (P bp))))) (fun p => p) e))))))
def uu_pathsinv0 : (forall A : (Type _), (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths A b a))))) :=
  (fun A => (fun a => (fun b => (fun e => (paths.rec (motive := (fun bp => (fun ep => (@paths A bp a)))) (@paths.idpath _ a) e)))))
def uu_pathscomp0 : (forall A : (Type _), (forall a : A, (forall b : A, (forall c : A, (forall e1 : (@paths A a b), (forall e2 : (@paths A b c), (@paths A a c))))))) :=
  (fun A => (fun a => (fun b => (fun c => (fun e1 => (fun e2 => ((paths.rec (motive := (fun bp => (fun ep => (forall q : (@paths A bp c), (@paths A a c))))) (fun q => q) e1) e2)))))))
def uu_maponpaths : (forall A : (Type _), (forall B : (Type _), (forall f : (forall x : A, B), (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths B (f a) (f b)))))))) :=
  (fun A => (fun B => (fun f => (fun a => (fun b => (fun e => (paths.rec (motive := (fun bp => (fun ep => (@paths B (f a) (f bp))))) (@paths.idpath _ (f a)) e)))))))
def uu_uu_unitpath : (forall u : PUnit, (@paths PUnit u PUnit.unit)) :=
  (fun u => (@PUnit.rec (fun v => (@paths PUnit v PUnit.unit)) (@paths.idpath _ PUnit.unit) u))
def uu_iscontrunit : (uu_iscontr PUnit) :=
  (total2.tpair PUnit.unit (fun t => (uu_uu_unitpath t)))
def uu_proofirrelevancecontr : (forall X : (Type _), (forall i : (uu_iscontr X), (forall x : X, (forall y : X, (@paths X x y))))) :=
  (fun X => (fun i => (fun x => (fun y => (uu_pathscomp0 X x (total2.pr1 i) y ((total2.pr2 i) x) (uu_pathsinv0 X y (total2.pr1 i) ((total2.pr2 i) y)))))))
def uu_fromempty : (forall P : (Type _), (forall e : Empty, P)) :=
  (fun P => (fun e => (@Empty.rec (fun x => P) e)))
def uu_negb : (forall b : Bool, Bool) :=
  (fun b => (@Bool.rec (fun x => Bool) true false b))
def uu_add : (forall n : Nat, (forall m : Nat, Nat)) :=
  (fun n => (fun m => (@Nat.rec (fun x => Nat) m (fun k => (fun r => (Nat.succ r))) n)))
def uu_uu_two_plus_two : (@paths Nat (uu_add 2 2) 4) :=
  (@paths.idpath _ 4)
def uu_uu_negb_true : (@paths Bool (uu_negb true) false) :=
  (@paths.idpath _ false)
def uu_uu_fromsum : (forall v : (Sum Nat Bool), Nat) :=
  (fun v => (@Sum.rec _ _ (fun x => Nat) (fun a => a) (fun b => (@Bool.rec (fun x => Nat) 0 1 b)) v))
def uu_uu_fromsum_ii2 : (@paths Nat (uu_uu_fromsum (Sum.inr true)) 1) :=
  (@paths.idpath _ 1)
def uu_idisweq : (forall T : (Type _), (uu_isweq T T (uu_idfun T))) :=
  by intro T y; refine ⟨⟨y, @paths.idpath _ y⟩, ?_⟩; intro t; obtain ⟨x, p⟩ := t; cases p; exact @paths.idpath _ _
def uu_idweq : (forall T : (Type _), (uu_weq T T)) :=
  (fun T => (total2.tpair (fun x => x) (uu_idisweq T)))
def uu_eqweqmap : (forall X : (Type _), (forall Y : (Type _), (forall e : (@paths (Type _) X Y), (uu_weq X Y)))) :=
  (fun X => (fun Y => (fun e => (paths.rec (motive := (fun Yp => (fun ep => (uu_weq X Yp)))) (uu_idweq X) e))))
def uu_uu_eqweqmap_idpath : (forall X : (Type _), (@paths (uu_weq X X) (uu_eqweqmap X X (@paths.idpath _ X)) (uu_idweq X))) :=
  (fun X => (@paths.idpath _ (uu_idweq X)))
def uu_invmap : (forall X : (Type _), (forall Y : (Type _), (forall w : (uu_weq X Y), (forall y : Y, X)))) :=
  (fun X => (fun Y => (fun w => (fun y => (total2.pr1 (total2.pr1 ((total2.pr2 w) y)))))))
def uu_homotweqinvweq : (forall X : (Type _), (forall Y : (Type _), (forall w : (uu_weq X Y), (forall y : Y, (@paths Y ((total2.pr1 w) (uu_invmap X Y w y)) y))))) :=
  (fun X => (fun Y => (fun w => (fun y => (total2.pr2 (total2.pr1 ((total2.pr2 w) y)))))))
def uu_isaprop : (forall X : (Type _), (Type _)) :=
  (fun X => (forall x : X, (forall y : X, (uu_iscontr (@paths X x y)))))
def uu_isaset : (forall X : (Type _), (Type _)) :=
  (fun X => (forall x : X, (forall y : X, (uu_isaprop (@paths X x y)))))
def uu_isofhlevel : (forall n : Nat, (forall X : (Type _), (Type _))) :=
  (fun n => (@Nat.rec (fun q => (forall X : (Type _), (Type _))) uu_iscontr (fun k => (fun rec => (fun X => (forall x : X, (forall y : X, (rec (@paths X x y))))))) n))
def uu_uu_isaprop_is_level1 : (forall X : (Type _), (@paths (Type _) (uu_isaprop X) (uu_isofhlevel 1 X))) :=
  (fun X => (@paths.idpath _ (uu_isaprop X)))
def uu_uu_isaset_is_level2 : (forall X : (Type _), (@paths (Type _) (uu_isaset X) (uu_isofhlevel 2 X))) :=
  (fun X => (@paths.idpath _ (uu_isaset X)))
def uu_hProp : (Type _) :=
  (total2 (fun X : (Type _) => (uu_isaprop X)))
def uu_hSet : (Type _) :=
  (total2 (fun X : (Type _) => (uu_isaset X)))
def uu_ishinh_UU : (forall X : (Type _), (Type _)) :=
  (fun X => (forall P : uu_hProp, (forall f : (forall x : X, (total2.pr1 P)), (total2.pr1 P))))
def uu_hinhpr : (forall X : (Type _), (forall x : X, (uu_ishinh_UU X))) :=
  (fun X => (fun x => (fun P => (fun f => (f x)))))
def uu_hinhuniv : (forall X : (Type _), (forall P : uu_hProp, (forall f : (forall x : X, (total2.pr1 P)), (forall w : (uu_ishinh_UU X), (total2.pr1 P))))) :=
  (fun X => (fun P => (fun f => (fun w => (w P f)))))
def uu_total2_paths_f : (forall A : (Type _), (forall P : (forall x : A, (Type _)), (forall s : (total2 (fun x : A => (P x))), (forall sp : (total2 (fun x : A => (P x))), (forall p : (@paths A (total2.pr1 s) (total2.pr1 sp)), (forall q : (@paths (P (total2.pr1 sp)) (uu_transportf A P (total2.pr1 s) (total2.pr1 sp) p (total2.pr2 s)) (total2.pr2 sp)), (@paths (total2 (fun x : A => (P x))) s sp))))))) :=
  (fun A => (fun P => (fun s => (fun sp => (fun p => (fun q => ((paths.rec (motive := (fun bp => (fun ep => (forall qp : (P bp), (forall qe : (@paths (P bp) (uu_transportf A P (total2.pr1 s) bp ep (total2.pr2 s)) qp), (@paths (total2 (fun x : A => (P x))) s (total2.tpair bp qp))))))) (fun qp => (fun qe => (paths.rec (motive := (fun qpp => (fun e2 => (@paths (total2 (fun x : A => (P x))) s (total2.tpair (total2.pr1 s) qpp))))) (@paths.idpath _ s) qe))) p) (total2.pr2 sp) q)))))))
def uu_homotinvweqweq : (forall X : (Type _), (forall Y : (Type _), (forall w : (uu_weq X Y), (forall x : X, (@paths X (uu_invmap X Y w ((total2.pr1 w) x)) x))))) :=
  (fun X => (fun Y => (fun w => (fun x => (uu_pathsinv0 X x (uu_invmap X Y w ((total2.pr1 w) x)) (uu_maponpaths (uu_hfiber X Y (total2.pr1 w) ((total2.pr1 w) x)) X (fun t => (total2.pr1 t)) (total2.tpair x (@paths.idpath _ ((total2.pr1 w) x))) (total2.pr1 ((total2.pr2 w) ((total2.pr1 w) x))) ((total2.pr2 ((total2.pr2 w) ((total2.pr1 w) x))) (total2.tpair x (@paths.idpath _ ((total2.pr1 w) x))))))))))
def uu_isweqtoempty : (forall X : (Type _), (forall f : (forall x : X, Empty), (uu_isweq X Empty f))) :=
  (fun X => (fun f => (fun y => (@Empty.rec (fun e => (uu_iscontr (uu_hfiber X Empty f e))) y))))
def uu_weqtoempty : (forall X : (Type _), (forall f : (forall x : X, Empty), (uu_weq X Empty))) :=
  (fun X => (fun f => (total2.tpair f (uu_isweqtoempty X f))))
def uu_nopathstruetofalse : (forall e : (@paths Bool true false), Empty) :=
  (fun e => (uu_transportf Bool (fun b => (@Bool.rec (fun x => (Type _)) Empty PUnit b)) true false e PUnit.unit))
def uu_nopathsfalsetotrue : (forall e : (@paths Bool false true), Empty) :=
  (fun e => (uu_transportf Bool (fun b => (@Bool.rec (fun x => (Type _)) PUnit Empty b)) false true e PUnit.unit))
def uu_pathscomp0rid : (forall A : (Type _), (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths (@paths A a b) (uu_pathscomp0 A a b b e (@paths.idpath _ b)) e))))) :=
  (fun A => (fun a => (fun b => (fun e => (paths.rec (motive := (fun bp => (fun ep => (@paths (@paths A a bp) (uu_pathscomp0 A a bp bp ep (@paths.idpath _ bp)) ep)))) (@paths.idpath _ (@paths.idpath _ a)) e)))))
def uu_pathsinv0r : (forall A : (Type _), (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths (@paths A a a) (uu_pathscomp0 A a b a e (uu_pathsinv0 A a b e)) (@paths.idpath _ a)))))) :=
  (fun A => (fun a => (fun b => (fun e => (paths.rec (motive := (fun bp => (fun ep => (@paths (@paths A a a) (uu_pathscomp0 A a bp a ep (uu_pathsinv0 A a bp ep)) (@paths.idpath _ a))))) (@paths.idpath _ (@paths.idpath _ a)) e)))))
def uu_pathsinv0l : (forall A : (Type _), (forall a : A, (forall b : A, (forall e : (@paths A a b), (@paths (@paths A b b) (uu_pathscomp0 A b a b (uu_pathsinv0 A a b e) e) (@paths.idpath _ b)))))) :=
  (fun A => (fun a => (fun b => (fun e => (paths.rec (motive := (fun bp => (fun ep => (@paths (@paths A bp bp) (uu_pathscomp0 A bp a bp (uu_pathsinv0 A a bp ep) ep) (@paths.idpath _ bp))))) (@paths.idpath _ (@paths.idpath _ a)) e)))))
def uu_iscontrretract : (forall X : (Type _), (forall Y : (Type _), (forall p : (forall x : X, Y), (forall s : (forall y : Y, X), (forall eps : (forall y : Y, (@paths Y (p (s y)) y)), (forall is : (uu_iscontr X), (uu_iscontr Y))))))) :=
  (fun X => (fun Y => (fun p => (fun s => (fun eps => (fun is => (total2.tpair (p (total2.pr1 is)) (fun t => (uu_pathscomp0 Y t (p (s t)) (p (total2.pr1 is)) (uu_pathsinv0 Y (p (s t)) t (eps t)) (uu_maponpaths X Y p (s t) (total2.pr1 is) ((total2.pr2 is) (s t))))))))))))
def uu_hfibershomotftog : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall g : (forall x : X, Y), (forall h : (forall x : X, (@paths Y (f x) (g x))), (forall y : Y, (forall t : (uu_hfiber X Y f y), (uu_hfiber X Y g y)))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun h => (fun y => (fun t => (total2.tpair (total2.pr1 t) (uu_pathscomp0 Y (g (total2.pr1 t)) (f (total2.pr1 t)) y (uu_pathsinv0 Y (f (total2.pr1 t)) (g (total2.pr1 t)) (h (total2.pr1 t))) (total2.pr2 t))))))))))
def uu_hfibershomotgtof : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall g : (forall x : X, Y), (forall h : (forall x : X, (@paths Y (f x) (g x))), (forall y : Y, (forall t : (uu_hfiber X Y g y), (uu_hfiber X Y f y)))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun h => (fun y => (fun t => (total2.tpair (total2.pr1 t) (uu_pathscomp0 Y (f (total2.pr1 t)) (g (total2.pr1 t)) y (h (total2.pr1 t)) (total2.pr2 t))))))))))
def uu_iscontrpathsinunit : (forall x : PUnit, (forall y : PUnit, (uu_iscontr (@paths PUnit x y)))) :=
  (fun x => (fun y => (total2.tpair (uu_pathscomp0 PUnit x PUnit.unit y (uu_uu_unitpath x) (uu_pathsinv0 PUnit y PUnit.unit (uu_uu_unitpath y))) (fun e => (paths.rec (motive := (fun yp => (fun ep => (@paths (@paths PUnit x yp) ep (uu_pathscomp0 PUnit x PUnit.unit yp (uu_uu_unitpath x) (uu_pathsinv0 PUnit yp PUnit.unit (uu_uu_unitpath yp))))))) (uu_pathsinv0 (@paths PUnit x x) (uu_pathscomp0 PUnit x PUnit.unit x (uu_uu_unitpath x) (uu_pathsinv0 PUnit x PUnit.unit (uu_uu_unitpath x))) (@paths.idpath _ x) (uu_pathsinv0r PUnit x PUnit.unit (uu_uu_unitpath x))) e)))))
def uu_isapropunit : (uu_isaprop PUnit) :=
  uu_iscontrpathsinunit
def uu_path_assoc : (forall A : (Type _), (forall a : A, (forall b : A, (forall c : A, (forall d : A, (forall e1 : (@paths A a b), (forall e2 : (@paths A b c), (forall e3 : (@paths A c d), (@paths (@paths A a d) (uu_pathscomp0 A a b d e1 (uu_pathscomp0 A b c d e2 e3)) (uu_pathscomp0 A a c d (uu_pathscomp0 A a b c e1 e2) e3)))))))))) :=
  (fun A => (fun a => (fun b => (fun c => (fun d => (fun e1 => (fun e2 => (fun e3 => ((paths.rec (motive := (fun bp => (fun ep => (forall q2 : (@paths A bp c), (forall q3 : (@paths A c d), (@paths (@paths A a d) (uu_pathscomp0 A a bp d ep (uu_pathscomp0 A bp c d q2 q3)) (uu_pathscomp0 A a c d (uu_pathscomp0 A a bp c ep q2) q3))))))) (fun q2 => (fun q3 => (@paths.idpath _ (uu_pathscomp0 A a c d q2 q3)))) e1) e2 e3)))))))))
def uu_uu_pathsinv0comp : (forall A : (Type _), (forall a : A, (forall b : A, (forall c : A, (forall p : (@paths A a b), (forall q : (@paths A b c), (@paths (@paths A b c) (uu_pathscomp0 A b a c (uu_pathsinv0 A a b p) (uu_pathscomp0 A a b c p q)) q))))))) :=
  (fun A => (fun a => (fun b => (fun c => (fun p => (fun q => ((paths.rec (motive := (fun bp => (fun ep => (forall qq : (@paths A bp c), (@paths (@paths A bp c) (uu_pathscomp0 A bp a c (uu_pathsinv0 A a bp ep) (uu_pathscomp0 A a bp c ep qq)) qq))))) (fun qq => (@paths.idpath _ qq)) p) q)))))))
def uu_uu_transportf_paths_Fl : (forall A : (Type _), (forall B : (Type _), (forall f : (forall x : A, B), (forall b : B, (forall x1 : A, (forall x2 : A, (forall p : (@paths A x1 x2), (forall e : (@paths B (f x1) b), (@paths (@paths B (f x2) b) (uu_transportf A (fun x => (@paths B (f x) b)) x1 x2 p e) (uu_pathscomp0 B (f x2) (f x1) b (uu_pathsinv0 B (f x1) (f x2) (uu_maponpaths A B f x1 x2 p)) e)))))))))) :=
  (fun A => (fun B => (fun f => (fun b => (fun x1 => (fun x2 => (fun p => (fun e => (paths.rec (motive := (fun xp => (fun pp => (@paths (@paths B (f xp) b) (uu_transportf A (fun x => (@paths B (f x) b)) x1 xp pp e) (uu_pathscomp0 B (f xp) (f x1) b (uu_pathsinv0 B (f x1) (f xp) (uu_maponpaths A B f x1 xp pp)) e))))) (@paths.idpath _ e) p)))))))))
def uu_iscontrhfiberl1 : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall g : (forall x : X, Y), (forall h : (forall x : X, (@paths Y (f x) (g x))), (forall y : Y, (forall is : (uu_iscontr (uu_hfiber X Y f y)), (uu_iscontr (uu_hfiber X Y g y))))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun h => (fun y => (fun is => (uu_iscontrretract (uu_hfiber X Y f y) (uu_hfiber X Y g y) (uu_hfibershomotftog X Y f g h y) (uu_hfibershomotgtof X Y f g h y) (fun t => (uu_total2_paths_f X (fun x => (@paths Y (g x) y)) ((uu_hfibershomotftog X Y f g h y) ((uu_hfibershomotgtof X Y f g h y) t)) t (@paths.idpath _ (total2.pr1 t)) (uu_uu_pathsinv0comp Y (f (total2.pr1 t)) (g (total2.pr1 t)) y (h (total2.pr1 t)) (total2.pr2 t)))) is))))))))
def uu_isweqhomot : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall g : (forall x : X, Y), (forall h : (forall x : X, (@paths Y (f x) (g x))), (forall is : (uu_isweq X Y f), (uu_isweq X Y g))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun h => (fun is => (fun y => (uu_iscontrhfiberl1 X Y f g h y (is y)))))))))
def uu_isweq_iso : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall g : (forall y : Y, X), (forall egf : (forall x : X, (@paths X (g (f x)) x)), (forall efg : (forall y : Y, (@paths Y (f (g y)) y)), (uu_isweq X Y f))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun egf => (fun efg => (fun y => (uu_iscontrretract (uu_hfiber Y Y (fun yp => (f (g yp))) y) (uu_hfiber X Y f y) (fun t => (total2.tpair (g (total2.pr1 t)) (total2.pr2 t))) (fun t => (total2.tpair (f (total2.pr1 t)) (uu_pathscomp0 Y (f (g (f (total2.pr1 t)))) (f (total2.pr1 t)) y (uu_maponpaths X Y f (g (f (total2.pr1 t))) (total2.pr1 t) (egf (total2.pr1 t))) (total2.pr2 t)))) (fun t => (uu_total2_paths_f X (fun x => (@paths Y (f x) y)) (total2.tpair (g (f (total2.pr1 t))) (uu_pathscomp0 Y (f (g (f (total2.pr1 t)))) (f (total2.pr1 t)) y (uu_maponpaths X Y f (g (f (total2.pr1 t))) (total2.pr1 t) (egf (total2.pr1 t))) (total2.pr2 t))) t (egf (total2.pr1 t)) (uu_pathscomp0 (@paths Y (f (total2.pr1 t)) y) (uu_transportf X (fun x => (@paths Y (f x) y)) (g (f (total2.pr1 t))) (total2.pr1 t) (egf (total2.pr1 t)) (uu_pathscomp0 Y (f (g (f (total2.pr1 t)))) (f (total2.pr1 t)) y (uu_maponpaths X Y f (g (f (total2.pr1 t))) (total2.pr1 t) (egf (total2.pr1 t))) (total2.pr2 t))) (uu_pathscomp0 Y (f (total2.pr1 t)) (f (g (f (total2.pr1 t)))) y (uu_pathsinv0 Y (f (g (f (total2.pr1 t)))) (f (total2.pr1 t)) (uu_maponpaths X Y f (g (f (total2.pr1 t))) (total2.pr1 t) (egf (total2.pr1 t)))) (uu_pathscomp0 Y (f (g (f (total2.pr1 t)))) (f (total2.pr1 t)) y (uu_maponpaths X Y f (g (f (total2.pr1 t))) (total2.pr1 t) (egf (total2.pr1 t))) (total2.pr2 t))) (total2.pr2 t) (uu_uu_transportf_paths_Fl X Y f y (g (f (total2.pr1 t))) (total2.pr1 t) (egf (total2.pr1 t)) (uu_pathscomp0 Y (f (g (f (total2.pr1 t)))) (f (total2.pr1 t)) y (uu_maponpaths X Y f (g (f (total2.pr1 t))) (total2.pr1 t) (egf (total2.pr1 t))) (total2.pr2 t))) (uu_uu_pathsinv0comp Y (f (g (f (total2.pr1 t)))) (f (total2.pr1 t)) y (uu_maponpaths X Y f (g (f (total2.pr1 t))) (total2.pr1 t) (egf (total2.pr1 t))) (total2.pr2 t))))) (uu_iscontrhfiberl1 Y Y (uu_idfun Y) (fun yp => (f (g yp))) (fun yp => (uu_pathsinv0 Y (f (g yp)) yp (efg yp))) y (uu_idisweq Y y))))))))))
def uu_isweqinvmap : (forall X : (Type _), (forall Y : (Type _), (forall w : (uu_weq X Y), (uu_isweq Y X (fun y => (uu_invmap X Y w y)))))) :=
  (fun X => (fun Y => (fun w => (uu_isweq_iso Y X (fun y => (uu_invmap X Y w y)) (total2.pr1 w) (uu_homotweqinvweq X Y w) (uu_homotinvweqweq X Y w)))))
def uu_invweq : (forall X : (Type _), (forall Y : (Type _), (forall w : (uu_weq X Y), (uu_weq Y X)))) :=
  (fun X => (fun Y => (fun w => (total2.tpair (fun y => (uu_invmap X Y w y)) (uu_isweqinvmap X Y w)))))
def uu_uu_isweqnegb : (uu_isweq Bool Bool uu_negb) :=
  (uu_isweq_iso Bool Bool uu_negb uu_negb (fun b => (@Bool.rec (fun bp => (@paths Bool (uu_negb (uu_negb bp)) bp)) (@paths.idpath _ false) (@paths.idpath _ true) b)) (fun b => (@Bool.rec (fun bp => (@paths Bool (uu_negb (uu_negb bp)) bp)) (@paths.idpath _ false) (@paths.idpath _ true) b)))
def uu_uu_weqnegb : (uu_weq Bool Bool) :=
  (total2.tpair uu_negb uu_uu_isweqnegb)
def uu_twooutof3c : (forall X : (Type _), (forall Y : (Type _), (forall Z : (Type _), (forall f : (forall x : X, Y), (forall g : (forall y : Y, Z), (forall isf : (uu_isweq X Y f), (forall isg : (uu_isweq Y Z g), (uu_isweq X Z (fun x => (g (f x))))))))))) :=
  (fun X => (fun Y => (fun Z => (fun f => (fun g => (fun isf => (fun isg => (uu_isweq_iso X Z (fun x => (g (f x))) (fun z => (uu_invmap X Y (total2.tpair f isf) (uu_invmap Y Z (total2.tpair g isg) z))) (fun x => (uu_pathscomp0 X (uu_invmap X Y (total2.tpair f isf) (uu_invmap Y Z (total2.tpair g isg) (g (f x)))) (uu_invmap X Y (total2.tpair f isf) (f x)) x (uu_maponpaths Y X (fun yy => (uu_invmap X Y (total2.tpair f isf) yy)) (uu_invmap Y Z (total2.tpair g isg) (g (f x))) (f x) (uu_homotinvweqweq Y Z (total2.tpair g isg) (f x))) (uu_homotinvweqweq X Y (total2.tpair f isf) x))) (fun z => (uu_pathscomp0 Z (g (f (uu_invmap X Y (total2.tpair f isf) (uu_invmap Y Z (total2.tpair g isg) z)))) (g (uu_invmap Y Z (total2.tpair g isg) z)) z (uu_maponpaths Y Z g (f (uu_invmap X Y (total2.tpair f isf) (uu_invmap Y Z (total2.tpair g isg) z))) (uu_invmap Y Z (total2.tpair g isg) z) (uu_homotweqinvweq X Y (total2.tpair f isf) (uu_invmap Y Z (total2.tpair g isg) z))) (uu_homotweqinvweq Y Z (total2.tpair g isg) z)))))))))))
def uu_weqcomp : (forall X : (Type _), (forall Y : (Type _), (forall Z : (Type _), (forall w1 : (uu_weq X Y), (forall w2 : (uu_weq Y Z), (uu_weq X Z)))))) :=
  (fun X => (fun Y => (fun Z => (fun w1 => (fun w2 => (total2.tpair (fun x => ((total2.pr1 w2) ((total2.pr1 w1) x))) (uu_twooutof3c X Y Z (total2.pr1 w1) (total2.pr1 w2) (total2.pr2 w1) (total2.pr2 w2))))))))
def uu_boolascoprod : (uu_weq Bool (Sum PUnit PUnit)) :=
  (total2.tpair (fun b => (@Bool.rec (fun q => (Sum PUnit PUnit)) (Sum.inr PUnit.unit) (Sum.inl PUnit.unit) b)) (uu_isweq_iso Bool (Sum PUnit PUnit) (fun b => (@Bool.rec (fun q => (Sum PUnit PUnit)) (Sum.inr PUnit.unit) (Sum.inl PUnit.unit) b)) (fun c => (@Sum.rec _ _ (fun q => Bool) (fun u => true) (fun u => false) c)) (fun b => (@Bool.rec (fun bp => (@paths Bool (@Sum.rec _ _ (fun q => Bool) (fun u => true) (fun u => false) (@Bool.rec (fun q => (Sum PUnit PUnit)) (Sum.inr PUnit.unit) (Sum.inl PUnit.unit) bp)) bp)) (@paths.idpath _ false) (@paths.idpath _ true) b)) (fun c => (@Sum.rec _ _ (fun cp => (@paths (Sum PUnit PUnit) (@Bool.rec (fun q => (Sum PUnit PUnit)) (Sum.inr PUnit.unit) (Sum.inl PUnit.unit) (@Sum.rec _ _ (fun q => Bool) (fun u => true) (fun u => false) cp)) cp)) (fun u => (uu_maponpaths PUnit (Sum PUnit PUnit) (fun uu => (Sum.inl uu)) PUnit.unit u (uu_pathsinv0 PUnit u PUnit.unit (uu_uu_unitpath u)))) (fun u => (uu_maponpaths PUnit (Sum PUnit PUnit) (fun uu => (Sum.inr uu)) PUnit.unit u (uu_pathsinv0 PUnit u PUnit.unit (uu_uu_unitpath u)))) c))))
@[reducible] def uu_coconusfromt : (forall T : (Type _), (forall t : T, (Type _))) :=
  (fun T => (fun t => (total2 (fun tp : T => (@paths T t tp)))))
def uu_iscontrcoconusfromt : (forall T : (Type _), (forall t : T, (uu_iscontr (uu_coconusfromt T t)))) :=
  (fun T => (fun t => (total2.tpair (total2.tpair t (@paths.idpath _ t)) (fun w => (paths.rec (motive := (fun bp => (fun ep => (@paths (uu_coconusfromt T t) (total2.tpair bp ep) (total2.tpair t (@paths.idpath _ t)))))) (@paths.idpath _ (total2.tpair t (@paths.idpath _ t))) (total2.pr2 w))))))
def uu_invproofirrelevance : (forall X : (Type _), (forall h : (forall x : X, (forall y : X, (@paths X x y))), (uu_isaprop X))) :=
  (fun X => (fun h => (fun x => (fun y => (total2.tpair (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (h x x)) (h x y)) (fun p => (paths.rec (motive := (fun yp => (fun pp => (@paths (@paths X x yp) pp (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (h x x)) (h x yp)))))) (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (h x x)) (h x x)) (@paths.idpath _ x) (uu_pathsinv0l X x x (h x x))) p)))))))
def uu_negpaths0sx : (forall k : Nat, (forall e : (@paths Nat 0 (Nat.succ k)), Empty)) :=
  (fun k => (fun e => (uu_transportf Nat (fun n => (@Nat.rec (fun q => (Type _)) PUnit (fun m => (fun r => Empty)) n)) 0 (Nat.succ k) e PUnit.unit)))
def uu_negpathssx0 : (forall k : Nat, (forall e : (@paths Nat (Nat.succ k) 0), Empty)) :=
  (fun k => (fun e => (uu_transportf Nat (fun n => (@Nat.rec (fun q => (Type _)) Empty (fun m => (fun r => PUnit)) n)) (Nat.succ k) 0 e PUnit.unit)))
def uu_isdeceqbool : (forall x : Bool, (forall y : Bool, (Sum (@paths Bool x y) (forall e : (@paths Bool x y), Empty)))) :=
  (fun x => (fun y => ((@Bool.rec (fun xp => (forall yy : Bool, (Sum (@paths Bool xp yy) (forall e : (@paths Bool xp yy), Empty)))) (fun yy => (@Bool.rec (fun yp => (Sum (@paths Bool false yp) (forall e : (@paths Bool false yp), Empty))) (Sum.inl (@paths.idpath _ false)) (Sum.inr uu_nopathsfalsetotrue) yy)) (fun yy => (@Bool.rec (fun yp => (Sum (@paths Bool true yp) (forall e : (@paths Bool true yp), Empty))) (Sum.inr uu_nopathstruetofalse) (Sum.inl (@paths.idpath _ true)) yy)) x) y)))
def uu_isaproppathsfromisolated : (forall X : (Type _), (forall x : X, (forall is : (forall y : X, (Sum (@paths X x y) (forall e : (@paths X x y), Empty))), (forall y : X, (uu_isaprop (@paths X x y)))))) :=
  (fun X => (fun x => (fun is => (fun y => (uu_invproofirrelevance (@paths X x y) (fun p => (fun q => (uu_pathscomp0 (@paths X x y) p (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@Sum.rec _ _ (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f p))) (is y))) q (paths.rec (motive := (fun yp => (fun pp => (@paths (@paths X x yp) pp (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@Sum.rec _ _ (fun d => (@paths X x yp)) (fun e => e) (fun f => (uu_fromempty (@paths X x yp) (f pp))) (is yp))))))) (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@paths.idpath _ x) (uu_pathsinv0l X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x)))) p) (uu_pathscomp0 (@paths X x y) (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@Sum.rec _ _ (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f p))) (is y))) (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@Sum.rec _ _ (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f q))) (is y))) q (uu_maponpaths (@paths X x y) (@paths X x y) (fun r => (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) r)) (@Sum.rec _ _ (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f p))) (is y)) (@Sum.rec _ _ (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f q))) (is y)) (@Sum.rec _ _ (fun d => (@paths (@paths X x y) (@Sum.rec _ _ (fun d2 => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f p))) d) (@Sum.rec _ _ (fun d2 => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f q))) d))) (fun e => (@paths.idpath _ e)) (fun f => (uu_fromempty (@paths (@paths X x y) (uu_fromempty (@paths X x y) (f p)) (uu_fromempty (@paths X x y) (f q))) (f p))) (is y))) (uu_pathsinv0 (@paths X x y) q (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@Sum.rec _ _ (fun d => (@paths X x y)) (fun e => e) (fun f => (uu_fromempty (@paths X x y) (f q))) (is y))) (paths.rec (motive := (fun yp => (fun pp => (@paths (@paths X x yp) pp (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@Sum.rec _ _ (fun d => (@paths X x yp)) (fun e => e) (fun f => (uu_fromempty (@paths X x yp) (f pp))) (is yp))))))) (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x))) (@paths.idpath _ x) (uu_pathsinv0l X x x (@Sum.rec _ _ (fun d => (@paths X x x)) (fun e => e) (fun f => (uu_fromempty (@paths X x x) (f (@paths.idpath _ x)))) (is x)))) q)))))))))))
def uu_isasetifdeceq : (forall X : (Type _), (forall dec : (forall x : X, (forall y : X, (Sum (@paths X x y) (forall e : (@paths X x y), Empty)))), (uu_isaset X))) :=
  (fun X => (fun dec => (fun x => (fun y => (uu_isaproppathsfromisolated X x (dec x) y)))))
def uu_isasetbool : (uu_isaset Bool) :=
  (uu_isasetifdeceq Bool uu_isdeceqbool)
def uu_isdeceqnat : (forall x : Nat, (forall y : Nat, (Sum (@paths Nat x y) (forall e : (@paths Nat x y), Empty)))) :=
  (fun x => (fun y => ((@Nat.rec (fun xp => (forall yy : Nat, (Sum (@paths Nat xp yy) (forall e : (@paths Nat xp yy), Empty)))) (fun yy => (@Nat.rec (fun yp => (Sum (@paths Nat 0 yp) (forall e : (@paths Nat 0 yp), Empty))) (Sum.inl (@paths.idpath _ 0)) (fun m => (fun r => (Sum.inr (uu_negpaths0sx m)))) yy)) (fun k => (fun IH => (fun yy => (@Nat.rec (fun yp => (Sum (@paths Nat (Nat.succ k) yp) (forall e : (@paths Nat (Nat.succ k) yp), Empty))) (Sum.inr (uu_negpathssx0 k)) (fun m => (fun r2 => (@Sum.rec _ _ (fun d => (Sum (@paths Nat (Nat.succ k) (Nat.succ m)) (forall e : (@paths Nat (Nat.succ k) (Nat.succ m)), Empty))) (fun e => (Sum.inl (uu_maponpaths Nat Nat (fun n => (Nat.succ n)) k m e))) (fun f => (Sum.inr (fun e2 => (f (uu_maponpaths Nat Nat (fun n => (@Nat.rec (fun q => Nat) 0 (fun a => (fun r3 => a)) n)) (Nat.succ k) (Nat.succ m) e2))))) (IH m)))) yy)))) x) y)))
def uu_isasetnat : (uu_isaset Nat) :=
  (uu_isasetifdeceq Nat uu_isdeceqnat)
def uu_transportb : (forall A : (Type _), (forall P : (forall x : A, (Type _)), (forall a : A, (forall b : A, (forall e : (@paths A a b), (forall p : (P b), (P a))))))) :=
  (fun A => (fun P => (fun a => (fun b => (fun e => (uu_transportf A P b a (uu_pathsinv0 A a b e)))))))
def uu_isweqtransportf : (forall A : (Type _), (forall P : (forall x : A, (Type _)), (forall a : A, (forall b : A, (forall e : (@paths A a b), (uu_isweq (P a) (P b) (uu_transportf A P a b e))))))) :=
  (fun A => (fun P => (fun a => (fun b => (fun e => (paths.rec (motive := (fun bp => (fun ep => (uu_isweq (P a) (P bp) (uu_transportf A P a bp ep))))) (uu_idisweq (P a)) e))))))
def uu_isweqtransportb : (forall A : (Type _), (forall P : (forall x : A, (Type _)), (forall a : A, (forall b : A, (forall e : (@paths A a b), (uu_isweq (P b) (P a) (uu_transportb A P a b e))))))) :=
  (fun A => (fun P => (fun a => (fun b => (fun e => (uu_isweqtransportf A P b a (uu_pathsinv0 A a b e)))))))
def uu_invmaponpathsweq : (forall X : (Type _), (forall Y : (Type _), (forall w : (uu_weq X Y), (forall x : X, (forall xp : X, (forall e : (@paths Y ((total2.pr1 w) x) ((total2.pr1 w) xp)), (@paths X x xp))))))) :=
  (fun X => (fun Y => (fun w => (fun x => (fun xp => (fun e => (uu_pathscomp0 X x (uu_invmap X Y w ((total2.pr1 w) x)) xp (uu_pathsinv0 X (uu_invmap X Y w ((total2.pr1 w) x)) x (uu_homotinvweqweq X Y w x)) (uu_pathscomp0 X (uu_invmap X Y w ((total2.pr1 w) x)) (uu_invmap X Y w ((total2.pr1 w) xp)) xp (uu_maponpaths Y X (fun y => (uu_invmap X Y w y)) ((total2.pr1 w) x) ((total2.pr1 w) xp) e) (uu_homotinvweqweq X Y w xp)))))))))
def uu_iscontrweqb : (forall X : (Type _), (forall Y : (Type _), (forall w : (uu_weq X Y), (forall is : (uu_iscontr Y), (uu_iscontr X))))) :=
  (fun X => (fun Y => (fun w => (fun is => (uu_iscontrretract Y X (fun y => (uu_invmap X Y w y)) (total2.pr1 w) (uu_homotinvweqweq X Y w) is)))))
def uu_pathsspace : (forall T : (Type _), (Type _)) :=
  (fun T => (total2 (fun x : T => (uu_coconusfromt T x))))
def uu_pathsspacetriple : (forall T : (Type _), (forall t1 : T, (forall t2 : T, (forall e : (@paths T t1 t2), (uu_pathsspace T))))) :=
  (fun T => (fun t1 => (fun t2 => (fun e => (total2.tpair t1 (total2.tpair t2 e))))))
def uu_deltap : (forall T : (Type _), (forall t : T, (uu_pathsspace T))) :=
  (fun T => (fun t => (total2.tpair t (total2.tpair t (@paths.idpath _ t)))))
def uu_isweqdeltap : (forall T : (Type _), (uu_isweq T (uu_pathsspace T) (uu_deltap T))) :=
  (fun T => (uu_isweq_iso T (uu_pathsspace T) (uu_deltap T) (fun z => (total2.pr1 z)) (fun t => (@paths.idpath _ t)) (fun z => (uu_total2_paths_f T (fun x => (uu_coconusfromt T x)) (uu_deltap T (total2.pr1 z)) z (@paths.idpath _ (total2.pr1 z)) (uu_pathsinv0 (uu_coconusfromt T (total2.pr1 z)) (total2.pr2 z) (total2.tpair (total2.pr1 z) (@paths.idpath _ (total2.pr1 z))) ((total2.pr2 (uu_iscontrcoconusfromt T (total2.pr1 z))) (total2.pr2 z)))))))
def uu_natplusr0 : (forall n : Nat, (@paths Nat (uu_add n 0) n)) :=
  (fun n => (@Nat.rec (fun m => (@paths Nat (uu_add m 0) m)) (@paths.idpath _ 0) (fun k => (fun IH => (uu_maponpaths Nat Nat (fun m => (Nat.succ m)) (uu_add k 0) k IH))) n))
def uu_uu_let_demo : (@paths Nat (let two := 2; (uu_add two two)) 4) :=
  (@paths.idpath _ 4)
def uu_toforallpaths : (forall T : (Type _), (forall P : (forall t : T, (Type _)), (forall f : (forall t : T, (P t)), (forall g : (forall t : T, (P t)), (forall e : (@paths (forall t : T, (P t)) f g), (forall t : T, (@paths (P t) (f t) (g t)))))))) :=
  (fun T => (fun P => (fun f => (fun g => (fun e => (fun t => (uu_maponpaths (forall tq : T, (P tq)) (P t) (fun h => (h t)) f g e)))))))
@[reducible] def uu_coconustot : (forall T : (Type _), (forall t : T, (Type _))) :=
  (fun T => (fun t => (total2 (fun tp : T => (@paths T tp t)))))
def uu_iscontrcoconustot : (forall T : (Type _), (forall t : T, (uu_iscontr (uu_coconustot T t)))) :=
  by intro T t; refine ⟨⟨t, @paths.idpath _ t⟩, ?_⟩; intro w; obtain ⟨x, p⟩ := w; cases p; exact @paths.idpath _ _
def uu_isweqpr1 : (forall X : (Type _), (forall P : (forall x : X, (Type _)), (forall is : (forall x : X, (uu_iscontr (P x))), (uu_isweq (total2 (fun x : X => (P x))) X (fun s => (total2.pr1 s)))))) :=
  (fun X => (fun P => (fun is => (uu_isweq_iso (total2 (fun x : X => (P x))) X (fun s => (total2.pr1 s)) (fun x => (total2.tpair x (total2.pr1 (is x)))) (fun s => (uu_total2_paths_f X P (total2.tpair (total2.pr1 s) (total2.pr1 (is (total2.pr1 s)))) s (@paths.idpath _ (total2.pr1 s)) (uu_pathsinv0 (P (total2.pr1 s)) (total2.pr2 s) (total2.pr1 (is (total2.pr1 s))) ((total2.pr2 (is (total2.pr1 s))) (total2.pr2 s))))) (fun x => (@paths.idpath _ x))))))
def uu_isweqcontrcontr : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall isx : (uu_iscontr X), (forall isy : (uu_iscontr Y), (uu_isweq X Y f)))))) :=
  (fun X => (fun Y => (fun f => (fun isx => (fun isy => (uu_isweq_iso X Y f (fun y => (total2.pr1 isx)) (fun x => (uu_proofirrelevancecontr X isx (total2.pr1 isx) x)) (fun y => (uu_proofirrelevancecontr Y isy (f (total2.pr1 isx)) y))))))))
def uu_wf : (forall Flse : (Type _), (forall T : (Type _), (Type _))) :=
  (fun Flse => (fun T => (total2 (fun lt : (forall x : T, (forall y : T, (Type _))) => (total2 (fun tr : (forall x : T, (forall y : T, (forall z : T, (forall p : (lt x y), (forall q : (lt y z), (lt x z)))))) => (forall h : (forall n : Nat, T), (forall ds : (forall n : Nat, (lt (h (Nat.succ n)) (h n))), Flse))))))))
def uu_wfs : (forall Flse : (Type _), (Type _)) :=
  (fun Flse => (total2 (fun T : (Type _) => (uu_wf Flse T))))
def uu_uset : (forall Flse : (Type _), (forall w : (uu_wfs Flse), (Type _))) :=
  (fun Flse => (fun w => (total2.pr1 w)))
def uu_uord : (forall Flse : (Type _), (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (forall y : (uu_uset Flse w), (Type _))))) :=
  (fun Flse => (fun w => (total2.pr1 (total2.pr2 w))))
def uu_trans : (forall Flse : (Type _), (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (forall y : (uu_uset Flse w), (forall z : (uu_uset Flse w), (forall p : (uu_uord Flse w x y), (forall q : (uu_uord Flse w y z), (uu_uord Flse w x z)))))))) :=
  (fun Flse => (fun w => (total2.pr1 (total2.pr2 (total2.pr2 w)))))
def uu_wfp : (forall Flse : (Type _), (forall w : (uu_wfs Flse), (forall h : (forall n : Nat, (uu_uset Flse w)), (forall ds : (forall n : Nat, (uu_uord Flse w (h (Nat.succ n)) (h n))), Flse)))) :=
  (fun Flse => (fun w => (total2.pr2 (total2.pr2 (total2.pr2 w)))))
def uu_wfs_wf_uord : (forall Flse : (Type _), (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), (Type _)))) :=
  (fun Flse => (fun v => (fun w => (total2 (fun f : (forall x : (uu_uset Flse v), (uu_uset Flse w)) => (total2 (fun hm : (forall x : (uu_uset Flse v), (forall y : (uu_uset Flse v), (forall p : (uu_uord Flse v x y), (uu_uord Flse w (f x) (f y))))) => (total2 (fun y : (uu_uset Flse w) => (forall x : (uu_uset Flse v), (uu_uord Flse w (f x) y)))))))))))
def uu_ufun : (forall Flse : (Type _), (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), (forall a : (uu_wfs_wf_uord Flse v w), (forall x : (uu_uset Flse v), (uu_uset Flse w)))))) :=
  (fun Flse => (fun v => (fun w => (fun a => (total2.pr1 a)))))
def uu_homo : (forall Flse : (Type _), (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), (forall a : (uu_wfs_wf_uord Flse v w), (forall x : (uu_uset Flse v), (forall y : (uu_uset Flse v), (forall p : (uu_uord Flse v x y), (uu_uord Flse w ((total2.pr1 a) x) ((total2.pr1 a) y))))))))) :=
  (fun Flse => (fun v => (fun w => (fun a => (total2.pr1 (total2.pr2 a))))))
def uu_domi : (forall Flse : (Type _), (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), (forall a : (uu_wfs_wf_uord Flse v w), (uu_uset Flse w))))) :=
  (fun Flse => (fun v => (fun w => (fun a => (total2.pr1 (total2.pr2 (total2.pr2 a)))))))
def uu_domicom : (forall Flse : (Type _), (forall v : (uu_wfs Flse), (forall w : (uu_wfs Flse), (forall a : (uu_wfs_wf_uord Flse v w), (forall x : (uu_uset Flse v), (uu_uord Flse w ((total2.pr1 a) x) (total2.pr1 (total2.pr2 (total2.pr2 a))))))))) :=
  (fun Flse => (fun v => (fun w => (fun a => (total2.pr2 (total2.pr2 (total2.pr2 a)))))))
def uu_wfs_wf_trans : (forall Flse : (Type _), (forall x : (uu_wfs Flse), (forall y : (uu_wfs Flse), (forall z : (uu_wfs Flse), (forall f : (uu_wfs_wf_uord Flse x y), (forall g : (uu_wfs_wf_uord Flse y z), (uu_wfs_wf_uord Flse x z))))))) :=
  (fun Flse => (fun x => (fun y => (fun z => (fun f => (fun g => (total2.tpair (fun a => ((total2.pr1 g) ((total2.pr1 f) a))) (total2.tpair (fun x0 => (fun y0 => (fun pp => (uu_homo Flse y z g ((total2.pr1 f) x0) ((total2.pr1 f) y0) (uu_homo Flse x y f x0 y0 pp))))) (total2.tpair (uu_domi Flse y z g) (fun x0 => (uu_trans Flse z ((total2.pr1 g) ((total2.pr1 f) x0)) ((total2.pr1 g) (uu_domi Flse x y f)) (uu_domi Flse y z g) (uu_homo Flse y z g ((total2.pr1 f) x0) (uu_domi Flse x y f) (uu_domicom Flse x y f x0)) (uu_domicom Flse y z g (uu_domi Flse x y f)))))))))))))
def uu_wfs_wf_wfp_shift : (forall Flse : (Type _), (forall f : (forall n : Nat, (uu_wfs Flse)), (forall b : (forall n : Nat, (uu_wfs_wf_uord Flse (f (Nat.succ n)) (f n))), (forall n : Nat, (forall a : (uu_uset Flse (f n)), (uu_uset Flse (f 0))))))) :=
  (fun Flse => (fun f => (fun b => (fun n => (@Nat.rec (fun m => (forall a : (uu_uset Flse (f m)), (uu_uset Flse (f 0)))) (fun a => a) (fun m => (fun IH => (fun x => (IH ((total2.pr1 (b m)) x))))) n)))))
def uu_wfs_wf_wfp_seq : (forall Flse : (Type _), (forall f : (forall n : Nat, (uu_wfs Flse)), (forall b : (forall n : Nat, (uu_wfs_wf_uord Flse (f (Nat.succ n)) (f n))), (forall n : Nat, (uu_uset Flse (f 0)))))) :=
  (fun Flse => (fun f => (fun b => (fun n => ((uu_wfs_wf_wfp_shift Flse f b n) (uu_domi Flse (f (Nat.succ n)) (f n) (b n)))))))
def uu_wfs_wf_wfp_compshift : (forall Flse : (Type _), (forall f : (forall n : Nat, (uu_wfs Flse)), (forall b : (forall n : Nat, (uu_wfs_wf_uord Flse (f (Nat.succ n)) (f n))), (forall n : Nat, (forall x : (uu_uset Flse (f n)), (forall y : (uu_uset Flse (f n)), (forall p : (uu_uord Flse (f n) x y), (uu_uord Flse (f 0) ((uu_wfs_wf_wfp_shift Flse f b n) x) ((uu_wfs_wf_wfp_shift Flse f b n) y))))))))) :=
  (fun Flse => (fun f => (fun b => (fun n => (@Nat.rec (fun m => (forall x : (uu_uset Flse (f m)), (forall y : (uu_uset Flse (f m)), (forall p : (uu_uord Flse (f m) x y), (uu_uord Flse (f 0) ((uu_wfs_wf_wfp_shift Flse f b m) x) ((uu_wfs_wf_wfp_shift Flse f b m) y)))))) (fun x => (fun y => (fun p => p))) (fun m => (fun IH => (fun x => (fun y => (fun p => (IH ((total2.pr1 (b m)) x) ((total2.pr1 (b m)) y) (uu_homo Flse (f (Nat.succ m)) (f m) (b m) x y p))))))) n)))))
def uu_wfs_wf_wfp_desc : (forall Flse : (Type _), (forall f : (forall n : Nat, (uu_wfs Flse)), (forall b : (forall n : Nat, (uu_wfs_wf_uord Flse (f (Nat.succ n)) (f n))), (forall n : Nat, (uu_uord Flse (f 0) (uu_wfs_wf_wfp_seq Flse f b (Nat.succ n)) (uu_wfs_wf_wfp_seq Flse f b n)))))) :=
  (fun Flse => (fun f => (fun b => (fun n => (uu_wfs_wf_wfp_compshift Flse f b n ((total2.pr1 (b n)) (uu_domi Flse (f (Nat.succ (Nat.succ n))) (f (Nat.succ n)) (b (Nat.succ n)))) (uu_domi Flse (f (Nat.succ n)) (f n) (b n)) (uu_domicom Flse (f (Nat.succ n)) (f n) (b n) (uu_domi Flse (f (Nat.succ (Nat.succ n))) (f (Nat.succ n)) (b (Nat.succ n)))))))))
def uu_wfs_wf : (forall Flse : (Type _), (uu_wf Flse (uu_wfs Flse))) :=
  (fun Flse => (total2.tpair (uu_wfs_wf_uord Flse) (total2.tpair (uu_wfs_wf_trans Flse) (fun h => (fun b => (uu_wfp Flse (h 0) (uu_wfs_wf_wfp_seq Flse h b) (uu_wfs_wf_wfp_desc Flse h b)))))))
def uu_wfs_wf_t : (forall Flse : (Type _), (uu_wfs Flse)) :=
  (fun Flse => (total2.tpair (uu_wfs Flse) (uu_wfs_wf Flse)))
def uu_maxi_fun : (forall Flse : (Type _), (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (uu_wfs Flse)))) :=
  (fun Flse => (fun w => (fun x => (total2.tpair (total2 (fun y : (uu_uset Flse w) => (uu_uord Flse w y x))) (total2.tpair (fun a => (fun bb => (uu_uord Flse w (total2.pr1 a) (total2.pr1 bb)))) (total2.tpair (fun x0 => (fun y0 => (fun z0 => (fun p => (fun q => (uu_trans Flse w (total2.pr1 x0) (total2.pr1 y0) (total2.pr1 z0) p q)))))) (fun h => (fun b => (uu_wfp Flse w (fun n => (total2.pr1 (h n))) b)))))))))
def uu_maxi_homo : (forall Flse : (Type _), (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (forall y : (uu_uset Flse w), (forall p : (uu_uord Flse w x y), (uu_wfs_wf_uord Flse (uu_maxi_fun Flse w x) (uu_maxi_fun Flse w y))))))) :=
  (fun Flse => (fun w => (fun x => (fun y => (fun p => (total2.tpair (fun z => (total2.tpair (total2.pr1 z) (uu_trans Flse w (total2.pr1 z) x y (total2.pr2 z) p))) (total2.tpair (fun x0 => (fun y0 => (fun q => q))) (total2.tpair (total2.tpair x p) (fun x0 => (total2.pr2 x0))))))))))
def uu_maxidom : (forall Flse : (Type _), (forall w : (uu_wfs Flse), (forall x : (uu_uset Flse w), (uu_wfs_wf_uord Flse (uu_maxi_fun Flse w x) w)))) :=
  (fun Flse => (fun w => (fun x => (total2.tpair (fun z => (total2.pr1 z)) (total2.tpair (fun x0 => (fun y0 => (fun p => p))) (total2.tpair x (fun x0 => (total2.pr2 x0))))))))
def uu_maxi : (forall Flse : (Type _), (forall w : (uu_wfs Flse), (uu_wfs_wf_uord Flse w (uu_wfs_wf_t Flse)))) :=
  (fun Flse => (fun w => (total2.tpair (uu_maxi_fun Flse w) (total2.tpair (uu_maxi_homo Flse w) (total2.tpair w (uu_maxidom Flse w))))))
def uu_isapropempty : (uu_isaprop Empty) :=
  (fun x => (fun y => (uu_fromempty (uu_iscontr (@paths Empty x y)) x)))
def uu_isapropifcontr : (forall X : (Type _), (forall is : (uu_iscontr X), (uu_isaprop X))) :=
  (fun X => (fun is => (fun x => (fun y => (total2.tpair (uu_pathscomp0 X x (total2.pr1 is) y ((total2.pr2 is) x) (uu_pathsinv0 X y (total2.pr1 is) ((total2.pr2 is) y))) (fun e => (paths.rec (motive := (fun yp => (fun ep => (@paths (@paths X x yp) ep (uu_pathscomp0 X x (total2.pr1 is) yp ((total2.pr2 is) x) (uu_pathsinv0 X yp (total2.pr1 is) ((total2.pr2 is) yp))))))) (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x (total2.pr1 is) x ((total2.pr2 is) x) (uu_pathsinv0 X x (total2.pr1 is) ((total2.pr2 is) x))) (@paths.idpath _ x) (uu_pathsinv0r X x (total2.pr1 is) ((total2.pr2 is) x))) e)))))))
def uu_iscontraprop1 : (forall X : (Type _), (forall ip : (uu_isaprop X), (forall x : X, (uu_iscontr X)))) :=
  (fun X => (fun ip => (fun x => (total2.tpair x (fun t => (total2.pr1 (ip t x)))))))
def uu_isapropdirprod : (forall A : (Type _), (forall B : (Type _), (forall ipa : (uu_isaprop A), (forall ipb : (uu_isaprop B), (uu_isaprop (total2 (fun q : A => B))))))) :=
  (fun A => (fun B => (fun ipa => (fun ipb => (uu_invproofirrelevance (total2 (fun q : A => B)) (fun x => (fun y => (uu_total2_paths_f A (fun q => B) x y (total2.pr1 (ipa (total2.pr1 x) (total2.pr1 y))) (total2.pr1 (ipb (uu_transportf A (fun q => B) (total2.pr1 x) (total2.pr1 y) (total2.pr1 (ipa (total2.pr1 x) (total2.pr1 y))) (total2.pr2 x)) (total2.pr2 y)))))))))))
def uu_htrue : uu_hProp :=
  (total2.tpair PUnit uu_isapropunit)
def uu_hfalse : uu_hProp :=
  (total2.tpair Empty uu_isapropempty)
def uu_hconj : (forall P : uu_hProp, (forall Q : uu_hProp, uu_hProp)) :=
  (fun P => (fun Q => (total2.tpair (total2 (fun q : (total2.pr1 P) => (total2.pr1 Q))) (uu_isapropdirprod (total2.pr1 P) (total2.pr1 Q) (total2.pr2 P) (total2.pr2 Q)))))
def uu_uu_htrue_demo : (total2.pr1 uu_htrue) :=
  PUnit.unit
def uu_uu_hconj_demo : (total2.pr1 (uu_hconj uu_htrue uu_htrue)) :=
  (total2.tpair PUnit.unit PUnit.unit)
def uu_uu_squash_demo : (total2.pr1 uu_htrue) :=
  (uu_hinhuniv PUnit uu_htrue (fun u => u) (uu_hinhpr PUnit PUnit.unit))
def uu_hrel : (forall X : (Type _), (Type _)) :=
  (fun X => (forall x : X, (forall y : X, uu_hProp)))
def uu_istrans : (forall X : (Type _), (forall R : (uu_hrel X), (Type _))) :=
  (fun X => (fun R => (forall x1 : X, (forall x2 : X, (forall x3 : X, (forall r1 : (total2.pr1 (R x1 x2)), (forall r2 : (total2.pr1 (R x2 x3)), (total2.pr1 (R x1 x3)))))))))
def uu_isrefl : (forall X : (Type _), (forall R : (uu_hrel X), (Type _))) :=
  (fun X => (fun R => (forall x : X, (total2.pr1 (R x x)))))
def uu_issymm : (forall X : (Type _), (forall R : (uu_hrel X), (Type _))) :=
  (fun X => (fun R => (forall x1 : X, (forall x2 : X, (forall r : (total2.pr1 (R x1 x2)), (total2.pr1 (R x2 x1)))))))
def uu_iseqrel : (forall X : (Type _), (forall R : (uu_hrel X), (Type _))) :=
  (fun X => (fun R => (total2 (fun q : (uu_istrans X R) => (total2 (fun q2 : (uu_isrefl X R) => (uu_issymm X R)))))))
def uu_eqrel : (forall X : (Type _), (Type _)) :=
  (fun X => (total2 (fun R : (uu_hrel X) => (uu_iseqrel X R))))
def uu_eqreltrans : (forall X : (Type _), (forall E : (uu_eqrel X), (uu_istrans X (total2.pr1 E)))) :=
  (fun X => (fun E => (total2.pr1 (total2.pr2 E))))
def uu_eqrelrefl : (forall X : (Type _), (forall E : (uu_eqrel X), (uu_isrefl X (total2.pr1 E)))) :=
  (fun X => (fun E => (total2.pr1 (total2.pr2 (total2.pr2 E)))))
def uu_eqrelsymm : (forall X : (Type _), (forall E : (uu_eqrel X), (uu_issymm X (total2.pr1 E)))) :=
  (fun X => (fun E => (total2.pr2 (total2.pr2 (total2.pr2 E)))))
def uu_hsubtype : (forall X : (Type _), (Type _)) :=
  (fun X => (forall x : X, uu_hProp))
def uu_carrier : (forall X : (Type _), (forall A : (uu_hsubtype X), (Type _))) :=
  (fun X => (fun A => (total2 (fun x : X => (total2.pr1 (A x))))))
def uu_iseqclass : (forall X : (Type _), (forall R : (uu_hrel X), (forall A : (uu_hsubtype X), (Type _)))) :=
  (fun X => (fun R => (fun A => (total2 (fun q : (uu_ishinh_UU (uu_carrier X A)) => (total2 (fun q2 : (forall x1 : X, (forall x2 : X, (forall r : (total2.pr1 (R x1 x2)), (forall a : (total2.pr1 (A x1)), (total2.pr1 (A x2)))))) => (forall x1 : X, (forall x2 : X, (forall a1 : (total2.pr1 (A x1)), (forall a2 : (total2.pr1 (A x2)), (total2.pr1 (R x1 x2)))))))))))))
def uu_eqax0 : (forall X : (Type _), (forall R : (uu_hrel X), (forall A : (uu_hsubtype X), (forall is : (uu_iseqclass X R A), (uu_ishinh_UU (uu_carrier X A)))))) :=
  (fun X => (fun R => (fun A => (fun is => (total2.pr1 is)))))
def uu_eqax1 : (forall X : (Type _), (forall R : (uu_hrel X), (forall A : (uu_hsubtype X), (forall is : (uu_iseqclass X R A), (forall x1 : X, (forall x2 : X, (forall r : (total2.pr1 (R x1 x2)), (forall a : (total2.pr1 (A x1)), (total2.pr1 (A x2)))))))))) :=
  (fun X => (fun R => (fun A => (fun is => (total2.pr1 (total2.pr2 is))))))
def uu_eqax2 : (forall X : (Type _), (forall R : (uu_hrel X), (forall A : (uu_hsubtype X), (forall is : (uu_iseqclass X R A), (forall x1 : X, (forall x2 : X, (forall a1 : (total2.pr1 (A x1)), (forall a2 : (total2.pr1 (A x2)), (total2.pr1 (R x1 x2)))))))))) :=
  (fun X => (fun R => (fun A => (fun is => (total2.pr2 (total2.pr2 is))))))
def uu_setquot : (forall X : (Type _), (forall R : (uu_hrel X), (Type _))) :=
  (fun X => (fun R => (total2 (fun A : (uu_hsubtype X) => (uu_iseqclass X R A)))))
def uu_setquotpr : (forall X : (Type _), (forall E : (uu_eqrel X), (forall x0 : X, (uu_setquot X (total2.pr1 E))))) :=
  (fun X => (fun E => (fun x0 => (total2.tpair (fun x => ((total2.pr1 E) x0 x)) (total2.tpair (uu_hinhpr (uu_carrier X (fun x => ((total2.pr1 E) x0 x))) (total2.tpair x0 (uu_eqrelrefl X E x0))) (total2.tpair (fun x1 => (fun x2 => (fun r => (fun a => (uu_eqreltrans X E x0 x1 x2 a r))))) (fun x1 => (fun x2 => (fun a1 => (fun a2 => (uu_eqreltrans X E x1 x0 x2 (uu_eqrelsymm X E x0 x1 a1) a2)))))))))))
def uu_isweqimplimpl : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall g : (forall y : Y, X), (forall ipx : (uu_isaprop X), (forall ipy : (uu_isaprop Y), (uu_isweq X Y f))))))) :=
  (fun X => (fun Y => (fun f => (fun g => (fun ipx => (fun ipy => (uu_isweq_iso X Y f g (fun x => (total2.pr1 (ipx (g (f x)) x))) (fun y => (total2.pr1 (ipy (f (g y)) y))))))))))
def uu_image : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (Type _)))) :=
  (fun X => (fun Y => (fun f => (total2 (fun y : Y => (uu_ishinh_UU (uu_hfiber X Y f y)))))))
def uu_prtoimage : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall x : X, (uu_image X Y f))))) :=
  (fun X => (fun Y => (fun f => (fun x => (total2.tpair (f x) (uu_hinhpr (uu_hfiber X Y f (f x)) (total2.tpair x (@paths.idpath _ (f x)))))))))
def uu_isapropsubtype : (forall X : (Type _), (forall A : (uu_hsubtype X), (forall is : (forall x1 : X, (forall x2 : X, (forall a1 : (total2.pr1 (A x1)), (forall a2 : (total2.pr1 (A x2)), (@paths X x1 x2))))), (uu_isaprop (uu_carrier X A))))) :=
  (fun X => (fun A => (fun is => (uu_invproofirrelevance (uu_carrier X A) (fun c1 => (fun c2 => (uu_total2_paths_f X (fun x => (total2.pr1 (A x))) c1 c2 (is (total2.pr1 c1) (total2.pr1 c2) (total2.pr2 c1) (total2.pr2 c2)) (total2.pr1 ((total2.pr2 (A (total2.pr1 c2))) (uu_transportf X (fun x => (total2.pr1 (A x))) (total2.pr1 c1) (total2.pr1 c2) (is (total2.pr1 c1) (total2.pr1 c2) (total2.pr2 c1) (total2.pr2 c2)) (total2.pr2 c1)) (total2.pr2 c2))))))))))
def uu_uu_trivrel : (uu_eqrel Bool) :=
  (total2.tpair (fun x => (fun y => uu_htrue)) (total2.tpair (fun x1 => (fun x2 => (fun x3 => (fun r1 => (fun r2 => PUnit.unit))))) (total2.tpair (fun x => PUnit.unit) (fun x1 => (fun x2 => (fun r => PUnit.unit))))))
def uu_uu_pathscollapse : (forall X : (Type _), (forall x : X, (forall PF : (forall y : X, (Type _)), (forall s : (forall y : X, (forall e : (@paths X x y), (PF y))), (forall p : (forall y : X, (forall q : (PF y), (@paths X x y))), (forall ip : (forall y : X, (uu_isaprop (PF y))), (forall y : X, (uu_isaprop (@paths X x y))))))))) :=
  (fun X => (fun x => (fun PF => (fun s => (fun p => (fun ip => (fun y => (uu_invproofirrelevance (@paths X x y) (fun e1 => (fun e2 => (uu_pathscomp0 (@paths X x y) e1 (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (@paths.idpath _ x)))) (p y (s y e1))) e2 (paths.rec (motive := (fun yp => (fun ep => (@paths (@paths X x yp) ep (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (p x (s x (@paths.idpath _ x)))) (p yp (s yp ep))))))) (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (p x (s x (@paths.idpath _ x)))) (p x (s x (@paths.idpath _ x)))) (@paths.idpath _ x) (uu_pathsinv0l X x x (p x (s x (@paths.idpath _ x))))) e1) (uu_pathscomp0 (@paths X x y) (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (@paths.idpath _ x)))) (p y (s y e1))) (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (@paths.idpath _ x)))) (p y (s y e2))) e2 (uu_maponpaths (@paths X x y) (@paths X x y) (fun r => (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (@paths.idpath _ x)))) r)) (p y (s y e1)) (p y (s y e2)) (uu_maponpaths (PF y) (@paths X x y) (p y) (s y e1) (s y e2) (total2.pr1 ((ip y) (s y e1) (s y e2))))) (uu_pathsinv0 (@paths X x y) e2 (uu_pathscomp0 X x x y (uu_pathsinv0 X x x (p x (s x (@paths.idpath _ x)))) (p y (s y e2))) (paths.rec (motive := (fun yp => (fun ep => (@paths (@paths X x yp) ep (uu_pathscomp0 X x x yp (uu_pathsinv0 X x x (p x (s x (@paths.idpath _ x)))) (p yp (s yp ep))))))) (uu_pathsinv0 (@paths X x x) (uu_pathscomp0 X x x x (uu_pathsinv0 X x x (p x (s x (@paths.idpath _ x)))) (p x (s x (@paths.idpath _ x)))) (@paths.idpath _ x) (uu_pathsinv0l X x x (p x (s x (@paths.idpath _ x))))) e2))))))))))))))
def uu_natplusl0 : (forall n : Nat, (@paths Nat (uu_add 0 n) n)) :=
  (fun n => (@paths.idpath _ n))
def uu_natplusnsm : (forall n : Nat, (forall m : Nat, (@paths Nat (uu_add n (Nat.succ m)) (uu_add (Nat.succ n) m)))) :=
  (fun n => (fun m => (@Nat.rec (fun q => (@paths Nat (uu_add q (Nat.succ m)) (uu_add (Nat.succ q) m))) (@paths.idpath _ (Nat.succ m)) (fun k => (fun IH => (uu_maponpaths Nat Nat (fun w => (Nat.succ w)) (uu_add k (Nat.succ m)) (uu_add (Nat.succ k) m) IH))) n)))
def uu_natpluscomm : (forall n : Nat, (forall m : Nat, (@paths Nat (uu_add n m) (uu_add m n)))) :=
  (fun n => (fun m => (@Nat.rec (fun q => (@paths Nat (uu_add q m) (uu_add m q))) (uu_pathsinv0 Nat (uu_add m 0) m (uu_natplusr0 m)) (fun k => (fun IH => (uu_pathscomp0 Nat (uu_add (Nat.succ k) m) (uu_add (Nat.succ m) k) (uu_add m (Nat.succ k)) (uu_maponpaths Nat Nat (fun w => (Nat.succ w)) (uu_add k m) (uu_add m k) IH) (uu_pathsinv0 Nat (uu_add m (Nat.succ k)) (uu_add (Nat.succ m) k) (uu_natplusnsm m k))))) n)))
def uu_natplusassoc : (forall n : Nat, (forall m : Nat, (forall k : Nat, (@paths Nat (uu_add (uu_add n m) k) (uu_add n (uu_add m k)))))) :=
  (fun n => (fun m => (fun k => (@Nat.rec (fun q => (@paths Nat (uu_add (uu_add q m) k) (uu_add q (uu_add m k)))) (@paths.idpath _ (uu_add m k)) (fun j => (fun IH => (uu_maponpaths Nat Nat (fun w => (Nat.succ w)) (uu_add (uu_add j m) k) (uu_add j (uu_add m k)) IH))) n))))
def uu_mul : (forall n : Nat, (forall m : Nat, Nat)) :=
  (fun n => (fun m => (@Nat.rec (fun q => Nat) 0 (fun p => (fun pm => (uu_add pm m))) n)))
def uu_natmult0n : (forall n : Nat, (@paths Nat (uu_mul 0 n) 0)) :=
  (fun n => (@paths.idpath _ 0))
def uu_natmultn0 : (forall n : Nat, (@paths Nat (uu_mul n 0) 0)) :=
  (fun n => (@Nat.rec (fun q => (@paths Nat (uu_mul q 0) 0)) (@paths.idpath _ 0) (fun p => (fun IH => (uu_pathscomp0 Nat (uu_add (uu_mul p 0) 0) (uu_mul p 0) 0 (uu_natplusr0 (uu_mul p 0)) IH))) n))
def uu_hinhfun : (forall X : (Type _), (forall Y : (Type _), (forall f : (forall x : X, Y), (forall w : (uu_ishinh_UU X), (uu_ishinh_UU Y))))) :=
  (fun X => (fun Y => (fun f => (fun w => (fun P => (fun g => (w P (fun x => (g (f x))))))))))
def uu_hinhand : (forall X : (Type _), (forall Y : (Type _), (forall w1 : (uu_ishinh_UU X), (forall w2 : (uu_ishinh_UU Y), (uu_ishinh_UU (total2 (fun q : X => Y))))))) :=
  (fun X => (fun Y => (fun w1 => (fun w2 => (fun P => (fun g => (w1 P (fun x => (w2 P (fun y => (g (total2.tpair x y))))))))))))
def uu_multsnm : (forall n : Nat, (forall m : Nat, (@paths Nat (uu_mul (Nat.succ n) m) (uu_add m (uu_mul n m))))) :=
  (fun n => (fun m => (uu_natpluscomm (uu_mul n m) m)))
def uu_multnsm : (forall n : Nat, (forall m : Nat, (@paths Nat (uu_mul n (Nat.succ m)) (uu_add n (uu_mul n m))))) :=
  (fun n => (fun m => (@Nat.rec (fun q => (@paths Nat (uu_mul q (Nat.succ m)) (uu_add q (uu_mul q m)))) (@paths.idpath _ 0) (fun k => (fun IH => (uu_pathscomp0 Nat (uu_mul (Nat.succ k) (Nat.succ m)) (uu_add (uu_add k (uu_mul k m)) (Nat.succ m)) (uu_add (Nat.succ k) (uu_mul (Nat.succ k) m)) (uu_maponpaths Nat Nat (fun w => (uu_add w (Nat.succ m))) (uu_mul k (Nat.succ m)) (uu_add k (uu_mul k m)) IH) (uu_pathscomp0 Nat (uu_add (uu_add k (uu_mul k m)) (Nat.succ m)) (uu_add k (uu_add (uu_mul k m) (Nat.succ m))) (uu_add (Nat.succ k) (uu_mul (Nat.succ k) m)) (uu_natplusassoc k (uu_mul k m) (Nat.succ m)) (uu_pathscomp0 Nat (uu_add k (uu_add (uu_mul k m) (Nat.succ m))) (uu_add k (uu_add (Nat.succ (uu_mul k m)) m)) (uu_add (Nat.succ k) (uu_mul (Nat.succ k) m)) (uu_maponpaths Nat Nat (fun w => (uu_add k w)) (uu_add (uu_mul k m) (Nat.succ m)) (uu_add (Nat.succ (uu_mul k m)) m) (uu_natplusnsm (uu_mul k m) m)) (uu_natplusnsm k (uu_add (uu_mul k m) m))))))) n)))
def uu_natmultcomm : (forall n : Nat, (forall m : Nat, (@paths Nat (uu_mul n m) (uu_mul m n)))) :=
  (fun n => (fun m => (@Nat.rec (fun q => (@paths Nat (uu_mul q m) (uu_mul m q))) (uu_pathsinv0 Nat (uu_mul m 0) 0 (uu_natmultn0 m)) (fun k => (fun IH => (uu_pathscomp0 Nat (uu_mul (Nat.succ k) m) (uu_add m (uu_mul k m)) (uu_mul m (Nat.succ k)) (uu_multsnm k m) (uu_pathscomp0 Nat (uu_add m (uu_mul k m)) (uu_add m (uu_mul m k)) (uu_mul m (Nat.succ k)) (uu_maponpaths Nat Nat (fun w => (uu_add m w)) (uu_mul k m) (uu_mul m k) IH) (uu_pathsinv0 Nat (uu_mul m (Nat.succ k)) (uu_add m (uu_mul m k)) (uu_multnsm m k)))))) n)))
def uu_natrdistr : (forall n : Nat, (forall m : Nat, (forall k : Nat, (@paths Nat (uu_mul (uu_add n m) k) (uu_add (uu_mul n k) (uu_mul m k)))))) :=
  (fun n => (fun m => (fun k => (@Nat.rec (fun q => (@paths Nat (uu_mul (uu_add q m) k) (uu_add (uu_mul q k) (uu_mul m k)))) (@paths.idpath _ (uu_mul m k)) (fun j => (fun IH => (uu_pathscomp0 Nat (uu_mul (uu_add (Nat.succ j) m) k) (uu_add (uu_add (uu_mul j k) (uu_mul m k)) k) (uu_add (uu_mul (Nat.succ j) k) (uu_mul m k)) (uu_maponpaths Nat Nat (fun w => (uu_add w k)) (uu_mul (uu_add j m) k) (uu_add (uu_mul j k) (uu_mul m k)) IH) (uu_pathscomp0 Nat (uu_add (uu_add (uu_mul j k) (uu_mul m k)) k) (uu_add (uu_mul j k) (uu_add (uu_mul m k) k)) (uu_add (uu_mul (Nat.succ j) k) (uu_mul m k)) (uu_natplusassoc (uu_mul j k) (uu_mul m k) k) (uu_pathscomp0 Nat (uu_add (uu_mul j k) (uu_add (uu_mul m k) k)) (uu_add (uu_mul j k) (uu_add k (uu_mul m k))) (uu_add (uu_mul (Nat.succ j) k) (uu_mul m k)) (uu_maponpaths Nat Nat (fun w => (uu_add (uu_mul j k) w)) (uu_add (uu_mul m k) k) (uu_add k (uu_mul m k)) (uu_natpluscomm (uu_mul m k) k)) (uu_pathsinv0 Nat (uu_add (uu_add (uu_mul j k) k) (uu_mul m k)) (uu_add (uu_mul j k) (uu_add k (uu_mul m k))) (uu_natplusassoc (uu_mul j k) k (uu_mul m k)))))))) n))))
def uu_natldistr : (forall m : Nat, (forall k : Nat, (forall n : Nat, (@paths Nat (uu_mul n (uu_add m k)) (uu_add (uu_mul n m) (uu_mul n k)))))) :=
  (fun m => (fun k => (fun n => (@Nat.rec (fun q => (@paths Nat (uu_mul n (uu_add q k)) (uu_add (uu_mul n q) (uu_mul n k)))) (uu_maponpaths Nat Nat (fun w => (uu_add w (uu_mul n k))) 0 (uu_mul n 0) (uu_pathsinv0 Nat (uu_mul n 0) 0 (uu_natmultn0 n))) (fun j => (fun IH => (uu_pathscomp0 Nat (uu_mul n (uu_add (Nat.succ j) k)) (uu_add n (uu_mul n (uu_add j k))) (uu_add (uu_mul n (Nat.succ j)) (uu_mul n k)) (uu_multnsm n (uu_add j k)) (uu_pathscomp0 Nat (uu_add n (uu_mul n (uu_add j k))) (uu_add n (uu_add (uu_mul n j) (uu_mul n k))) (uu_add (uu_mul n (Nat.succ j)) (uu_mul n k)) (uu_maponpaths Nat Nat (fun w => (uu_add n w)) (uu_mul n (uu_add j k)) (uu_add (uu_mul n j) (uu_mul n k)) IH) (uu_pathscomp0 Nat (uu_add n (uu_add (uu_mul n j) (uu_mul n k))) (uu_add (uu_add n (uu_mul n j)) (uu_mul n k)) (uu_add (uu_mul n (Nat.succ j)) (uu_mul n k)) (uu_pathsinv0 Nat (uu_add (uu_add n (uu_mul n j)) (uu_mul n k)) (uu_add n (uu_add (uu_mul n j) (uu_mul n k))) (uu_natplusassoc n (uu_mul n j) (uu_mul n k))) (uu_maponpaths Nat Nat (fun w => (uu_add w (uu_mul n k))) (uu_add n (uu_mul n j)) (uu_mul n (Nat.succ j)) (uu_pathsinv0 Nat (uu_mul n (Nat.succ j)) (uu_add n (uu_mul n j)) (uu_multnsm n j)))))))) m))))
def uu_natmultassoc : (forall n : Nat, (forall m : Nat, (forall k : Nat, (@paths Nat (uu_mul (uu_mul n m) k) (uu_mul n (uu_mul m k)))))) :=
  (fun n => (fun m => (fun k => (@Nat.rec (fun q => (@paths Nat (uu_mul (uu_mul q m) k) (uu_mul q (uu_mul m k)))) (@paths.idpath _ 0) (fun j => (fun IH => (uu_pathscomp0 Nat (uu_mul (uu_mul (Nat.succ j) m) k) (uu_add (uu_mul (uu_mul j m) k) (uu_mul m k)) (uu_mul (Nat.succ j) (uu_mul m k)) (uu_natrdistr (uu_mul j m) m k) (uu_maponpaths Nat Nat (fun w => (uu_add w (uu_mul m k))) (uu_mul (uu_mul j m) k) (uu_mul j (uu_mul m k)) IH)))) n))))
def uu_natmultl1 : (forall n : Nat, (@paths Nat (uu_mul 1 n) n)) :=
  (fun n => (@paths.idpath _ n))
def uu_natmultr1 : (forall n : Nat, (@paths Nat (uu_mul n 1) n)) :=
  (fun n => (uu_pathscomp0 Nat (uu_mul n 1) (uu_mul 1 n) n (uu_natmultcomm n 1) (uu_natmultl1 n)))
def uu_uu_app : (forall n : Nat, (forall x : Nat, Nat)) :=
  (fun n => (fun x => (@Nat.rec (fun q => Nat) 1 (fun p => (fun r => (uu_mul x r))) n)))
def uu_uu_app_const1 : (forall x : Nat, (@paths Nat (uu_uu_app 0 x) 1)) :=
  (fun x => (@paths.idpath _ 1))
def uu_uu_app_ident : (forall x : Nat, (@paths Nat (uu_uu_app 1 x) x)) :=
  (fun x => (uu_natmultr1 x))
def uu_uu_app_const_of_const : (forall x : Nat, (@paths Nat (uu_uu_app (uu_uu_app 0 0) x) x)) :=
  (fun x => (uu_natmultr1 x))
def uu_uu_app_3_2 : (@paths Nat (uu_uu_app 3 2) 8) :=
  (@paths.idpath _ 8)
def uu_uu_app_tower : (@paths Nat (uu_uu_app (uu_uu_app 2 3) 4) 262144) :=
  (@paths.idpath _ 262144)
def uu_natgtb : (forall n : Nat, (forall m : Nat, Bool)) :=
  (fun n => (@Nat.rec (fun q => (forall m : Nat, Bool)) (fun m => false) (fun k => (fun IH => (fun m => (@Nat.rec (fun r => Bool) true (fun j => (fun u => (IH j))) m)))) n))
def uu_natgth : (forall n : Nat, (forall m : Nat, uu_hProp)) :=
  (fun n => (fun m => (total2.tpair (@paths Bool (uu_natgtb n m) true) (uu_isasetbool (uu_natgtb n m) true))))
def uu_negnatgth0n : (forall n : Nat, (forall g : (@paths Bool (uu_natgtb 0 n) true), Empty)) :=
  (fun n => (fun g => (uu_nopathsfalsetotrue g)))
def uu_natgthsnn : (forall n : Nat, (@paths Bool (uu_natgtb (Nat.succ n) n) true)) :=
  (fun n => (@Nat.rec (fun q => (@paths Bool (uu_natgtb (Nat.succ q) q) true)) (@paths.idpath _ true) (fun k => (fun IH => IH)) n))
def uu_natgthsn0 : (forall n : Nat, (@paths Bool (uu_natgtb (Nat.succ n) 0) true)) :=
  (fun n => (@paths.idpath _ true))
def uu_negnatgth0tois0 : (forall n : Nat, (forall ng : (forall g : (@paths Bool (uu_natgtb n 0) true), Empty), (@paths Nat n 0))) :=
  (fun n => (@Nat.rec (fun q => (forall ng : (forall g : (@paths Bool (uu_natgtb q 0) true), Empty), (@paths Nat q 0))) (fun ng => (@paths.idpath _ 0)) (fun k => (fun IH => (fun ng => (uu_fromempty (@paths Nat (Nat.succ k) 0) (ng (uu_natgthsn0 k)))))) n))
def uu_nat1gthtois0 : (forall n : Nat, (forall g : (@paths Bool (uu_natgtb 1 n) true), (@paths Nat n 0))) :=
  (fun n => (@Nat.rec (fun q => (forall g : (@paths Bool (uu_natgtb 1 q) true), (@paths Nat q 0))) (fun g => (@paths.idpath _ 0)) (fun k => (fun IH => (fun g => (uu_fromempty (@paths Nat (Nat.succ k) 0) (uu_negnatgth0n k g))))) n))
def uu_istransnatgth : (forall n : Nat, (forall m : Nat, (forall k : Nat, (forall g : (@paths Bool (uu_natgtb n m) true), (forall h : (@paths Bool (uu_natgtb m k) true), (@paths Bool (uu_natgtb n k) true)))))) :=
  (fun n => (@Nat.rec (fun q => (forall m : Nat, (forall k : Nat, (forall g : (@paths Bool (uu_natgtb q m) true), (forall h : (@paths Bool (uu_natgtb m k) true), (@paths Bool (uu_natgtb q k) true)))))) (fun m => (fun k => (fun g => (fun h => (uu_fromempty (@paths Bool (uu_natgtb 0 k) true) (uu_negnatgth0n m g)))))) (fun p => (fun IHn => (fun m => (@Nat.rec (fun r => (forall k : Nat, (forall g : (@paths Bool (uu_natgtb (Nat.succ p) r) true), (forall h : (@paths Bool (uu_natgtb r k) true), (@paths Bool (uu_natgtb (Nat.succ p) k) true))))) (fun k => (fun g => (fun h => (uu_fromempty (@paths Bool (uu_natgtb (Nat.succ p) k) true) (uu_negnatgth0n k h))))) (fun q => (fun u => (fun k => (@Nat.rec (fun s => (forall g : (@paths Bool (uu_natgtb (Nat.succ p) (Nat.succ q)) true), (forall h : (@paths Bool (uu_natgtb (Nat.succ q) s) true), (@paths Bool (uu_natgtb (Nat.succ p) s) true)))) (fun g => (fun h => (@paths.idpath _ true))) (fun j => (fun v => (fun g => (fun h => (IHn q j g h))))) k)))) m)))) n))
def uu_isirreflnatgth : (forall n : Nat, (forall g : (@paths Bool (uu_natgtb n n) true), Empty)) :=
  (fun n => (@Nat.rec (fun q => (forall g : (@paths Bool (uu_natgtb q q) true), Empty)) (fun g => (uu_negnatgth0n 0 g)) (fun k => (fun IH => IH)) n))
def uu_isasymmnatgth : (forall n : Nat, (forall m : Nat, (forall g : (@paths Bool (uu_natgtb n m) true), (forall h : (@paths Bool (uu_natgtb m n) true), Empty)))) :=
  (fun n => (fun m => (fun g => (fun h => (uu_isirreflnatgth n (uu_istransnatgth n m n g h))))))
def uu_natgthandplusl : (forall n : Nat, (forall m : Nat, (forall k : Nat, (forall g : (@paths Bool (uu_natgtb n m) true), (@paths Bool (uu_natgtb (uu_add k n) (uu_add k m)) true))))) :=
  (fun n => (fun m => (fun k => (fun g => (@Nat.rec (fun q => (@paths Bool (uu_natgtb (uu_add q n) (uu_add q m)) true)) g (fun p => (fun IH => IH)) k)))))
def uu_natgthandplusr : (forall n : Nat, (forall m : Nat, (forall k : Nat, (forall g : (@paths Bool (uu_natgtb n m) true), (@paths Bool (uu_natgtb (uu_add n k) (uu_add m k)) true))))) :=
  (fun n => (fun m => (fun k => (fun g => (uu_pathscomp0 Bool (uu_natgtb (uu_add n k) (uu_add m k)) (uu_natgtb (uu_add k n) (uu_add k m)) true (uu_pathscomp0 Bool (uu_natgtb (uu_add n k) (uu_add m k)) (uu_natgtb (uu_add k n) (uu_add m k)) (uu_natgtb (uu_add k n) (uu_add k m)) (uu_maponpaths Nat Bool (fun w => (uu_natgtb w (uu_add m k))) (uu_add n k) (uu_add k n) (uu_natpluscomm n k)) (uu_maponpaths Nat Bool (fun w => (uu_natgtb (uu_add k n) w)) (uu_add m k) (uu_add k m) (uu_natpluscomm m k))) (uu_natgthandplusl n m k g))))))
def uu_natgthandmultl : (forall n : Nat, (forall m : Nat, (forall k : Nat, (forall g : (@paths Bool (uu_natgtb n m) true), (@paths Bool (uu_natgtb (uu_mul (Nat.succ k) n) (uu_mul (Nat.succ k) m)) true))))) :=
  (fun n => (fun m => (fun k => (fun g => (@Nat.rec (fun q => (@paths Bool (uu_natgtb (uu_mul (Nat.succ q) n) (uu_mul (Nat.succ q) m)) true)) g (fun p => (fun IH => (uu_istransnatgth (uu_add (uu_mul (Nat.succ p) n) n) (uu_add (uu_mul (Nat.succ p) m) n) (uu_add (uu_mul (Nat.succ p) m) m) (uu_natgthandplusr (uu_mul (Nat.succ p) n) (uu_mul (Nat.succ p) m) n IH) (uu_natgthandplusl n m (uu_mul (Nat.succ p) m) g)))) k)))))
def uu_natlth : (forall n : Nat, (forall m : Nat, uu_hProp)) :=
  (fun n => (fun m => (uu_natgth m n)))
def uu_natleh : (forall n : Nat, (forall m : Nat, uu_hProp)) :=
  (fun n => (fun m => (total2.tpair (@paths Bool (uu_natgtb n m) false) (uu_isasetbool (uu_natgtb n m) false))))
def uu_natgeh : (forall n : Nat, (forall m : Nat, uu_hProp)) :=
  (fun n => (fun m => (uu_natleh m n)))
def uu_natgthorleh : (forall n : Nat, (forall m : Nat, (Sum (@paths Bool (uu_natgtb n m) true) (@paths Bool (uu_natgtb n m) false)))) :=
  (fun n => (fun m => (@Bool.rec (fun b => (Sum (@paths Bool b true) (@paths Bool b false))) (Sum.inr (@paths.idpath _ false)) (Sum.inl (@paths.idpath _ true)) (uu_natgtb n m))))
def uu_isreflnatleh : (forall n : Nat, (@paths Bool (uu_natgtb n n) false)) :=
  (fun n => (@Nat.rec (fun q => (@paths Bool (uu_natgtb q q) false)) (@paths.idpath _ false) (fun k => (fun IH => IH)) n))
def uu_istransnatleh : (forall n : Nat, (forall m : Nat, (forall k : Nat, (forall g : (@paths Bool (uu_natgtb n m) false), (forall h : (@paths Bool (uu_natgtb m k) false), (@paths Bool (uu_natgtb n k) false)))))) :=
  (fun n => (@Nat.rec (fun q => (forall m : Nat, (forall k : Nat, (forall g : (@paths Bool (uu_natgtb q m) false), (forall h : (@paths Bool (uu_natgtb m k) false), (@paths Bool (uu_natgtb q k) false)))))) (fun m => (fun k => (fun g => (fun h => (@paths.idpath _ false))))) (fun p => (fun IHn => (fun m => (@Nat.rec (fun r => (forall k : Nat, (forall g : (@paths Bool (uu_natgtb (Nat.succ p) r) false), (forall h : (@paths Bool (uu_natgtb r k) false), (@paths Bool (uu_natgtb (Nat.succ p) k) false))))) (fun k => (fun g => (fun h => (uu_fromempty (@paths Bool (uu_natgtb (Nat.succ p) k) false) (uu_nopathstruetofalse g))))) (fun q => (fun u => (fun k => (@Nat.rec (fun s => (forall g : (@paths Bool (uu_natgtb (Nat.succ p) (Nat.succ q)) false), (forall h : (@paths Bool (uu_natgtb (Nat.succ q) s) false), (@paths Bool (uu_natgtb (Nat.succ p) s) false)))) (fun g => (fun h => (uu_fromempty (@paths Bool (uu_natgtb (Nat.succ p) 0) false) (uu_nopathstruetofalse h)))) (fun j => (fun v => (fun g => (fun h => (IHn q j g h))))) k)))) m)))) n))
def uu_isantisymmnatleh : (forall n : Nat, (forall m : Nat, (forall g : (@paths Bool (uu_natgtb n m) false), (forall h : (@paths Bool (uu_natgtb m n) false), (@paths Nat n m))))) :=
  (fun n => (@Nat.rec (fun q => (forall m : Nat, (forall g : (@paths Bool (uu_natgtb q m) false), (forall h : (@paths Bool (uu_natgtb m q) false), (@paths Nat q m))))) (fun m => (@Nat.rec (fun r => (forall g : (@paths Bool (uu_natgtb 0 r) false), (forall h : (@paths Bool (uu_natgtb r 0) false), (@paths Nat 0 r)))) (fun g => (fun h => (@paths.idpath _ 0))) (fun mp => (fun u => (fun g => (fun h => (uu_fromempty (@paths Nat 0 (Nat.succ mp)) (uu_nopathstruetofalse h)))))) m)) (fun p => (fun IHn => (fun m => (@Nat.rec (fun r => (forall g : (@paths Bool (uu_natgtb (Nat.succ p) r) false), (forall h : (@paths Bool (uu_natgtb r (Nat.succ p)) false), (@paths Nat (Nat.succ p) r)))) (fun g => (fun h => (uu_fromempty (@paths Nat (Nat.succ p) 0) (uu_nopathstruetofalse g)))) (fun q => (fun u => (fun g => (fun h => (uu_maponpaths Nat Nat (fun w => (Nat.succ w)) p q (IHn q g h)))))) m)))) n))
def uu_natlehtonegnatgth : (forall n : Nat, (forall m : Nat, (forall p : (@paths Bool (uu_natgtb n m) false), (forall q : (@paths Bool (uu_natgtb n m) true), Empty)))) :=
  (fun n => (fun m => (fun p => (fun q => (uu_nopathstruetofalse (uu_pathscomp0 Bool true (uu_natgtb n m) false (uu_pathsinv0 Bool (uu_natgtb n m) true q) p))))))
def uu_negnatgthtoleh : (forall n : Nat, (forall m : Nat, (forall ng : (forall q : (@paths Bool (uu_natgtb n m) true), Empty), (@paths Bool (uu_natgtb n m) false)))) :=
  (fun n => (fun m => (fun ng => ((@Bool.rec (fun b => (forall g : (forall q : (@paths Bool b true), Empty), (@paths Bool b false))) (fun g => (@paths.idpath _ false)) (fun g => (uu_fromempty (@paths Bool true false) (g (@paths.idpath _ true)))) (uu_natgtb n m)) ng))))
def uu_natlthtoleh : (forall n : Nat, (forall m : Nat, (forall g : (@paths Bool (uu_natgtb m n) true), (@paths Bool (uu_natgtb n m) false)))) :=
  (fun n => (fun m => (fun g => (uu_negnatgthtoleh n m (fun q => (uu_isasymmnatgth n m q g))))))
def uu_natminus : (forall n : Nat, (forall m : Nat, Nat)) :=
  (fun n => (@Nat.rec (fun x => (forall m : Nat, Nat)) (fun m => 0) (fun k => (fun IH => (fun m => (@Nat.rec (fun y => Nat) (Nat.succ k) (fun j => (fun u => (IH j))) m)))) n))
def uu_natminus0n : (forall n : Nat, (@paths Nat (uu_natminus 0 n) 0)) :=
  (fun n => (@paths.idpath _ 0))
def uu_natminusn0 : (forall n : Nat, (@paths Nat (uu_natminus n 0) n)) :=
  (fun n => (@Nat.rec (fun q => (@paths Nat (uu_natminus q 0) q)) (@paths.idpath _ 0) (fun k => (fun IH => (@paths.idpath _ (Nat.succ k)))) n))
def uu_natminusnn : (forall n : Nat, (@paths Nat (uu_natminus n n) 0)) :=
  (fun n => (@Nat.rec (fun q => (@paths Nat (uu_natminus q q) 0)) (@paths.idpath _ 0) (fun k => (fun IH => IH)) n))
def uu_natlehsucc : (forall a : Nat, (forall k : Nat, (forall g : (@paths Bool (uu_natgtb a k) false), (@paths Bool (uu_natgtb a (Nat.succ k)) false)))) :=
  (fun a => (@Nat.rec (fun q => (forall k : Nat, (forall g : (@paths Bool (uu_natgtb q k) false), (@paths Bool (uu_natgtb q (Nat.succ k)) false)))) (fun k => (fun g => (@paths.idpath _ false))) (fun a' => (fun IH => (fun k => (@Nat.rec (fun r => (forall g : (@paths Bool (uu_natgtb (Nat.succ a') r) false), (@paths Bool (uu_natgtb (Nat.succ a') (Nat.succ r)) false))) (fun g => (uu_fromempty (@paths Bool (uu_natgtb (Nat.succ a') (Nat.succ 0)) false) (uu_nopathstruetofalse g))) (fun k' => (fun u => (fun g => (IH k' g)))) k)))) a))
def uu_natminusleh : (forall n : Nat, (forall m : Nat, (@paths Bool (uu_natgtb (uu_natminus n m) n) false))) :=
  (fun n => (@Nat.rec (fun q => (forall m : Nat, (@paths Bool (uu_natgtb (uu_natminus q m) q) false))) (fun m => (@paths.idpath _ false)) (fun k => (fun IHn => (fun m => (@Nat.rec (fun r => (@paths Bool (uu_natgtb (uu_natminus (Nat.succ k) r) (Nat.succ k)) false)) (uu_isreflnatleh k) (fun j => (fun u => (uu_natlehsucc (uu_natminus k j) k (IHn j)))) m)))) n))
def uu_natminusplusnmm : (forall n : Nat, (forall m : Nat, (forall h : (@paths Bool (uu_natgtb m n) false), (@paths Nat (uu_add (uu_natminus n m) m) n)))) :=
  (fun n => (@Nat.rec (fun q => (forall m : Nat, (forall h : (@paths Bool (uu_natgtb m q) false), (@paths Nat (uu_add (uu_natminus q m) m) q)))) (fun m => (@Nat.rec (fun r => (forall h : (@paths Bool (uu_natgtb r 0) false), (@paths Nat (uu_add (uu_natminus 0 r) r) 0))) (fun h => (@paths.idpath _ 0)) (fun m' => (fun u => (fun h => (uu_fromempty (@paths Nat (uu_add (uu_natminus 0 (Nat.succ m')) (Nat.succ m')) 0) (uu_nopathstruetofalse h))))) m)) (fun n' => (fun IHn => (fun m => (@Nat.rec (fun r => (forall h : (@paths Bool (uu_natgtb r (Nat.succ n')) false), (@paths Nat (uu_add (uu_natminus (Nat.succ n') r) r) (Nat.succ n')))) (fun h => (uu_natplusr0 (Nat.succ n'))) (fun m' => (fun u => (fun h => (uu_pathscomp0 Nat (uu_add (uu_natminus (Nat.succ n') (Nat.succ m')) (Nat.succ m')) (uu_add (Nat.succ (uu_natminus n' m')) m') (Nat.succ n') (uu_natplusnsm (uu_natminus n' m') m') (uu_maponpaths Nat Nat (fun w => (Nat.succ w)) (uu_add (uu_natminus n' m') m') n' (IHn m' h)))))) m)))) n))
def uu_natlehandminusl : (forall n : Nat, (forall m : Nat, (forall k : Nat, (forall h : (@paths Bool (uu_natgtb n m) false), (@paths Bool (uu_natgtb (uu_natminus n k) (uu_natminus m k)) false))))) :=
  (fun n => (@Nat.rec (fun q => (forall m : Nat, (forall k : Nat, (forall h : (@paths Bool (uu_natgtb q m) false), (@paths Bool (uu_natgtb (uu_natminus q k) (uu_natminus m k)) false))))) (fun m => (fun k => (fun h => (@paths.idpath _ false)))) (fun n' => (fun IHn => (fun m => (@Nat.rec (fun mr => (forall k : Nat, (forall h : (@paths Bool (uu_natgtb (Nat.succ n') mr) false), (@paths Bool (uu_natgtb (uu_natminus (Nat.succ n') k) (uu_natminus mr k)) false)))) (fun k => (fun h => (uu_fromempty (@paths Bool (uu_natgtb (uu_natminus (Nat.succ n') k) (uu_natminus 0 k)) false) (uu_nopathstruetofalse h)))) (fun m' => (fun um => (fun k => (@Nat.rec (fun kr => (forall h : (@paths Bool (uu_natgtb (Nat.succ n') (Nat.succ m')) false), (@paths Bool (uu_natgtb (uu_natminus (Nat.succ n') kr) (uu_natminus (Nat.succ m') kr)) false))) (fun h => h) (fun k' => (fun uk => (fun h => (IHn m' k' h)))) k)))) m)))) n))
def uu_natlehandminusr : (forall n : Nat, (forall m : Nat, (forall k : Nat, (forall h : (@paths Bool (uu_natgtb k m) false), (@paths Bool (uu_natgtb (uu_natminus n m) (uu_natminus n k)) false))))) :=
  (fun n => (@Nat.rec (fun q => (forall m : Nat, (forall k : Nat, (forall h : (@paths Bool (uu_natgtb k m) false), (@paths Bool (uu_natgtb (uu_natminus q m) (uu_natminus q k)) false))))) (fun m => (fun k => (fun h => (@paths.idpath _ false)))) (fun n' => (fun IHn => (fun m => (@Nat.rec (fun mr => (forall k : Nat, (forall h : (@paths Bool (uu_natgtb k mr) false), (@paths Bool (uu_natgtb (uu_natminus (Nat.succ n') mr) (uu_natminus (Nat.succ n') k)) false)))) (fun k => (@Nat.rec (fun kr => (forall h : (@paths Bool (uu_natgtb kr 0) false), (@paths Bool (uu_natgtb (uu_natminus (Nat.succ n') 0) (uu_natminus (Nat.succ n') kr)) false))) (fun h => (uu_isreflnatleh n')) (fun k' => (fun uk => (fun h => (uu_fromempty (@paths Bool (uu_natgtb (uu_natminus (Nat.succ n') 0) (uu_natminus (Nat.succ n') (Nat.succ k'))) false) (uu_nopathstruetofalse h))))) k)) (fun m' => (fun um => (fun k => (@Nat.rec (fun kr => (forall h : (@paths Bool (uu_natgtb kr (Nat.succ m')) false), (@paths Bool (uu_natgtb (uu_natminus (Nat.succ n') (Nat.succ m')) (uu_natminus (Nat.succ n') kr)) false))) (fun h => (uu_natlehsucc (uu_natminus n' m') n' (uu_natminusleh n' m'))) (fun k' => (fun uk => (fun h => (IHn m' k' h)))) k)))) m)))) n))
def uu_nvec : (forall n : Nat, Type) :=
  (fun n => (@Nat.rec (fun q => Type) PUnit (fun k => (fun r => (total2 (fun h : Nat => r)))) n))
def uu_nlist : Type :=
  (total2 (fun n : Nat => (uu_nvec n)))
def uu_nnil : uu_nlist :=
  (total2.tpair 0 PUnit.unit)
def uu_ncons : (forall x : Nat, (forall l : uu_nlist, uu_nlist)) :=
  (fun x => (fun l => (total2.tpair (Nat.succ (total2.pr1 l)) (total2.tpair x (total2.pr2 l)))))
def uu_nlen : (forall l : uu_nlist, Nat) :=
  (fun l => (total2.pr1 l))
def uu_lapp : (forall a : uu_nlist, (forall b : uu_nlist, uu_nlist)) :=
  (fun a => (fun b => ((@Nat.rec (fun q => (forall v : (uu_nvec q), uu_nlist)) (fun v => b) (fun k => (fun IH => (fun v => (uu_ncons (total2.pr1 v) (IH (total2.pr2 v)))))) (total2.pr1 a)) (total2.pr2 a))))
def uu_lrev : (forall a : uu_nlist, uu_nlist) :=
  (fun a => ((@Nat.rec (fun q => (forall v : (uu_nvec q), uu_nlist)) (fun v => uu_nnil) (fun k => (fun IH => (fun v => (uu_lapp (IH (total2.pr2 v)) (uu_ncons (total2.pr1 v) uu_nnil))))) (total2.pr1 a)) (total2.pr2 a)))
def uu_orb : (forall a : Bool, (forall b : Bool, Bool)) :=
  (fun a => (fun b => (@Bool.rec (fun x => Bool) b true a)))
def uu_andb : (forall a : Bool, (forall b : Bool, Bool)) :=
  (fun a => (fun b => (@Bool.rec (fun x => Bool) false b a)))
def uu_nateqb : (forall n : Nat, (forall m : Nat, Bool)) :=
  (fun n => ((@Nat.rec (fun q => (forall m : Nat, Bool)) (fun m => (@Nat.rec (fun q => Bool) true (fun k => (fun r => false)) m)) (fun k => (fun IH => (fun m => (@Nat.rec (fun q => Bool) false (fun j => (fun r => (IH j))) m)))) n)))
def uu_memb : (forall w : Nat, (forall l : uu_nlist, Bool)) :=
  (fun w => (fun l => ((@Nat.rec (fun q => (forall v : (uu_nvec q), Bool)) (fun v => false) (fun k => (fun IH => (fun v => (uu_orb (uu_nateqb w (total2.pr1 v)) (IH (total2.pr2 v)))))) (total2.pr1 l)) (total2.pr2 l))))
def uu_nodupb : (forall l : uu_nlist, Bool) :=
  (fun l => ((@Nat.rec (fun q => (forall v : (uu_nvec q), Bool)) (fun v => true) (fun k => (fun IH => (fun v => (uu_andb (uu_negb (uu_memb (total2.pr1 v) (total2.tpair k (total2.pr2 v)))) (IH (total2.pr2 v)))))) (total2.pr1 l)) (total2.pr2 l)))
def uu_stk : Type :=
  (total2 (fun f : Nat => (total2 (fun u : uu_nlist => uu_nlist))))
def uu_zmk : (forall f : Nat, (forall u : uu_nlist, (forall d : uu_nlist, uu_stk))) :=
  (fun f => (fun u => (fun d => (total2.tpair f (total2.tpair u d)))))
def uu_zfoc : (forall z : uu_stk, Nat) :=
  (fun z => (total2.pr1 z))
def uu_zup : (forall z : uu_stk, uu_nlist) :=
  (fun z => (total2.pr1 (total2.pr2 z)))
def uu_zdn : (forall z : uu_stk, uu_nlist) :=
  (fun z => (total2.pr2 (total2.pr2 z)))
def uu_zins : (forall w : Nat, (forall z : uu_stk, uu_stk)) :=
  (fun w => (fun z => (uu_zmk w (uu_zup z) (uu_ncons (uu_zfoc z) (uu_zdn z)))))
def uu_zrow : (forall z : uu_stk, uu_nlist) :=
  (fun z => (uu_lapp (uu_lrev (uu_zup z)) (uu_ncons (uu_zfoc z) (uu_zdn z))))
def uu_zcount : (forall z : uu_stk, Nat) :=
  (fun z => (Nat.succ (uu_add (uu_nlen (uu_zup z)) (uu_nlen (uu_zdn z)))))
def uu_zsane : (forall z : uu_stk, Bool) :=
  (fun z => (uu_nodupb (uu_zrow z)))
def uu_zfocins : (forall w : Nat, (forall z : uu_stk, (@paths Nat (uu_zfoc (uu_zins w z)) w))) :=
  (fun w => (fun z => (@paths.idpath _ w)))
def uu_zcountins : (forall w : Nat, (forall z : uu_stk, (@paths Nat (uu_zcount (uu_zins w z)) (Nat.succ (uu_zcount z))))) :=
  (fun w => (fun z => (uu_maponpaths Nat Nat (fun q => (Nat.succ q)) (uu_add (uu_nlen (uu_zup z)) (Nat.succ (uu_nlen (uu_zdn z)))) (Nat.succ (uu_add (uu_nlen (uu_zup z)) (uu_nlen (uu_zdn z)))) (uu_natplusnsm (uu_nlen (uu_zup z)) (uu_nlen (uu_zdn z))))))
def uu_hd0 : (forall l : uu_nlist, Nat) :=
  (fun l => ((@Nat.rec (fun q => (forall v : (uu_nvec q), Nat)) (fun v => 0) (fun k => (fun IH => (fun v => (total2.pr1 v)))) (total2.pr1 l)) (total2.pr2 l)))
def uu_tl0 : (forall l : uu_nlist, uu_nlist) :=
  (fun l => ((@Nat.rec (fun q => (forall v : (uu_nvec q), uu_nlist)) (fun v => uu_nnil) (fun k => (fun IH => (fun v => (total2.tpair k (total2.pr2 v))))) (total2.pr1 l)) (total2.pr2 l)))
def uu_zrev : (forall z : uu_stk, uu_stk) :=
  (fun z => (uu_zmk (uu_zfoc z) (uu_zdn z) (uu_zup z)))
def uu_zfocup : (forall z : uu_stk, uu_stk) :=
  (fun z => (@Nat.rec (fun q => uu_stk) (let a := (uu_lrev (uu_ncons (uu_zfoc z) (uu_zdn z))); (uu_zmk (uu_hd0 a) (uu_tl0 a) uu_nnil)) (fun k => (fun r => (uu_zmk (uu_hd0 (uu_zup z)) (uu_tl0 (uu_zup z)) (uu_ncons (uu_zfoc z) (uu_zdn z))))) (total2.pr1 (uu_zup z))))
def uu_zfocdn : (forall z : uu_stk, uu_stk) :=
  (fun z => (uu_zrev (uu_zfocup (uu_zrev z))))
def uu_zmaster : (forall z : uu_stk, uu_stk) :=
  (fun z => (uu_zmk (uu_zfoc z) uu_nnil (uu_lapp (uu_lrev (uu_zup z)) (uu_zdn z))))
def uu_zrevrev : (forall z : uu_stk, (@paths uu_stk (uu_zrev (uu_zrev z)) z)) :=
  (fun z => (@paths.idpath _ z))
def uu_orbfalsel : (forall a : Bool, (forall b : Bool, (forall h : (@paths Bool (uu_orb a b) false), (@paths Bool a false)))) :=
  (fun a => (@Bool.rec (fun a2 => (forall b : Bool, (forall h : (@paths Bool (uu_orb a2 b) false), (@paths Bool a2 false)))) (fun b => (fun h => (@paths.idpath _ false))) (fun b => (fun h => h)) a))
def uu_orbfalser : (forall a : Bool, (forall b : Bool, (forall h : (@paths Bool (uu_orb a b) false), (@paths Bool b false)))) :=
  (fun a => (@Bool.rec (fun a2 => (forall b : Bool, (forall h : (@paths Bool (uu_orb a2 b) false), (@paths Bool b false)))) (fun b => (fun h => h)) (fun b => (fun h => (uu_fromempty (@paths Bool b false) (uu_nopathstruetofalse h)))) a))
def uu_andbtruel : (forall a : Bool, (forall b : Bool, (forall h : (@paths Bool (uu_andb a b) true), (@paths Bool a true)))) :=
  (fun a => (@Bool.rec (fun a2 => (forall b : Bool, (forall h : (@paths Bool (uu_andb a2 b) true), (@paths Bool a2 true)))) (fun b => (fun h => (uu_fromempty (@paths Bool false true) (uu_nopathstruetofalse (uu_pathsinv0 Bool false true h))))) (fun b => (fun h => (@paths.idpath _ true))) a))
def uu_andbtruer : (forall a : Bool, (forall b : Bool, (forall h : (@paths Bool (uu_andb a b) true), (@paths Bool b true)))) :=
  (fun a => (@Bool.rec (fun a2 => (forall b : Bool, (forall h : (@paths Bool (uu_andb a2 b) true), (@paths Bool b true)))) (fun b => (fun h => (uu_fromempty (@paths Bool b true) (uu_nopathstruetofalse (uu_pathsinv0 Bool false true h))))) (fun b => (fun h => h)) a))
def uu_negbtrue : (forall t : Bool, (forall h : (@paths Bool (uu_negb t) true), (@paths Bool t false))) :=
  (fun t => (@Bool.rec (fun t2 => (forall h : (@paths Bool (uu_negb t2) true), (@paths Bool t2 false))) (fun h => (@paths.idpath _ false)) (fun h => (uu_fromempty (@paths Bool true false) (uu_nopathstruetofalse (uu_pathsinv0 Bool false true h)))) t))
def uu_nateqbsymm : (forall n : Nat, (forall m : Nat, (@paths Bool (uu_nateqb n m) (uu_nateqb m n)))) :=
  (fun n => (@Nat.rec (fun q => (forall m : Nat, (@paths Bool (uu_nateqb q m) (uu_nateqb m q)))) (fun m => (@Nat.rec (fun j => (@paths Bool (uu_nateqb 0 j) (uu_nateqb j 0))) (@paths.idpath _ true) (fun j => (fun r => (@paths.idpath _ false))) m)) (fun k => (fun IH => (fun m => (@Nat.rec (fun j => (@paths Bool (uu_nateqb (Nat.succ k) j) (uu_nateqb j (Nat.succ k)))) (@paths.idpath _ false) (fun j => (fun r => (IH j))) m)))) n))
def uu_membmid : (forall u : Nat, (forall w : Nat, (forall b : uu_nlist, (forall hu : (@paths Bool (uu_nateqb u w) false), (forall a : uu_nlist, (forall hm : (@paths Bool (uu_memb u (uu_lapp a b)) false), (@paths Bool (uu_memb u (uu_lapp a (uu_ncons w b))) false))))))) :=
  (fun u => (fun w => (fun b => (fun hu => (fun a => ((@Nat.rec (fun q => (forall v : (uu_nvec q), (forall hm : (@paths Bool (uu_memb u (uu_lapp (total2.tpair q v) b)) false), (@paths Bool (uu_memb u (uu_lapp (total2.tpair q v) (uu_ncons w b))) false)))) (fun v => (fun hm => (uu_pathscomp0 Bool (uu_memb u (uu_ncons w b)) (uu_memb u b) false (uu_maponpaths Bool Bool (fun t => (uu_orb t (uu_memb u b))) (uu_nateqb u w) false hu) hm))) (fun k => (fun IH => (fun v => (fun hm => (uu_pathscomp0 Bool (uu_orb (uu_nateqb u (total2.pr1 v)) (uu_memb u (uu_lapp (total2.tpair k (total2.pr2 v)) (uu_ncons w b)))) (uu_memb u (uu_lapp (total2.tpair k (total2.pr2 v)) (uu_ncons w b))) false (uu_maponpaths Bool Bool (fun t => (uu_orb t (uu_memb u (uu_lapp (total2.tpair k (total2.pr2 v)) (uu_ncons w b))))) (uu_nateqb u (total2.pr1 v)) false (uu_orbfalsel (uu_nateqb u (total2.pr1 v)) (uu_memb u (uu_lapp (total2.tpair k (total2.pr2 v)) b)) hm)) (IH (total2.pr2 v) (uu_orbfalser (uu_nateqb u (total2.pr1 v)) (uu_memb u (uu_lapp (total2.tpair k (total2.pr2 v)) b)) hm))))))) (total2.pr1 a)) (total2.pr2 a)))))))
def uu_nodupmid : (forall w : Nat, (forall b : uu_nlist, (forall a : uu_nlist, (forall hm : (@paths Bool (uu_memb w (uu_lapp a b)) false), (forall hs : (@paths Bool (uu_nodupb (uu_lapp a b)) true), (@paths Bool (uu_nodupb (uu_lapp a (uu_ncons w b))) true)))))) :=
  (fun w => (fun b => (fun a => ((@Nat.rec (fun q => (forall v : (uu_nvec q), (forall hm : (@paths Bool (uu_memb w (uu_lapp (total2.tpair q v) b)) false), (forall hs : (@paths Bool (uu_nodupb (uu_lapp (total2.tpair q v) b)) true), (@paths Bool (uu_nodupb (uu_lapp (total2.tpair q v) (uu_ncons w b))) true))))) (fun v => (fun hm => (fun hs => (uu_pathscomp0 Bool (uu_nodupb (uu_ncons w b)) (uu_nodupb b) true (uu_maponpaths Bool Bool (fun t => (uu_andb (uu_negb t) (uu_nodupb b))) (uu_memb w b) false hm) hs)))) (fun k => (fun IH => (fun v => (fun hm => (fun hs => (uu_pathscomp0 Bool (uu_nodupb (uu_lapp (total2.tpair (Nat.succ k) v) (uu_ncons w b))) (uu_nodupb (uu_lapp (total2.tpair k (total2.pr2 v)) (uu_ncons w b))) true (uu_maponpaths Bool Bool (fun t => (uu_andb (uu_negb t) (uu_nodupb (uu_lapp (total2.tpair k (total2.pr2 v)) (uu_ncons w b))))) (uu_memb (total2.pr1 v) (uu_lapp (total2.tpair k (total2.pr2 v)) (uu_ncons w b))) false (uu_membmid (total2.pr1 v) w b (uu_pathscomp0 Bool (uu_nateqb (total2.pr1 v) w) (uu_nateqb w (total2.pr1 v)) false (uu_nateqbsymm (total2.pr1 v) w) (uu_orbfalsel (uu_nateqb w (total2.pr1 v)) (uu_memb w (uu_lapp (total2.tpair k (total2.pr2 v)) b)) hm)) (total2.tpair k (total2.pr2 v)) (uu_negbtrue (uu_memb (total2.pr1 v) (uu_lapp (total2.tpair k (total2.pr2 v)) b)) (uu_andbtruel (uu_negb (uu_memb (total2.pr1 v) (uu_lapp (total2.tpair k (total2.pr2 v)) b))) (uu_nodupb (uu_lapp (total2.tpair k (total2.pr2 v)) b)) hs)))) (IH (total2.pr2 v) (uu_orbfalser (uu_nateqb w (total2.pr1 v)) (uu_memb w (uu_lapp (total2.tpair k (total2.pr2 v)) b)) hm) (uu_andbtruer (uu_negb (uu_memb (total2.pr1 v) (uu_lapp (total2.tpair k (total2.pr2 v)) b))) (uu_nodupb (uu_lapp (total2.tpair k (total2.pr2 v)) b)) hs)))))))) (total2.pr1 a)) (total2.pr2 a)))))
def uu_zinsane : (forall w : Nat, (forall z : uu_stk, (forall hm : (@paths Bool (uu_memb w (uu_zrow z)) false), (forall hs : (@paths Bool (uu_zsane z) true), (@paths Bool (uu_zsane (uu_zins w z)) true))))) :=
  (fun w => (fun z => (uu_nodupmid w (uu_ncons (uu_zfoc z) (uu_zdn z)) (uu_lrev (uu_zup z)))))

end
/- the de Bruijn witness: Lean agrees these carry NO axioms (closed under the
   global context), the same property Rocq's `Print Assumptions` reports. -/
#print axioms uu_natpluscomm
#print axioms uu_zcountins
#print axioms uu_zinsane
#print axioms uu_natplusassoc
#print axioms uu_natmultcomm
#print axioms uu_total2_paths_f
#print axioms uu_idisweq
#print axioms uu_iscontrcoconustot

/- 239 exported / 289 corpus entries swept;
   re-certified by Lean 4 -- a second kernel beside Rocq's uugen.v -/
