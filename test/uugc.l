; test/uugc.l -- test/proof/rocq/gc.v as uu proof terms: the minor is sound under a complete
; write barrier, its work is bounded by the nursery, its cheney drain an exact fixpoint.
; uu has no user inductives: a list is a length and nested pairs, Reach is step-indexed

; --- lists over any type: grec computes on a cons by sigma eta ---
(test
 (defn gvec (pi A UU n nat UU)
   (lam A n (nat_rect (lam q UU) unit (lam j r (total2 x A r)) n)))
 (defn glist (pi A UU UU) (lam A (total2 n nat (gvec A n))))
 (defn gnil (pi A UU (glist A)) (lam A (tpair 0 tt)))
 (defn gcons (pi A UU x A l (glist A) (glist A))
   (lam A x l (tpair (succ (pr1 l)) (tpair x (pr2 l)))))
 (defn grec
   (pi A UU P (pi l (glist A) UU) pn (P (gnil A))
       pc (pi x A t (glist A) ih (P t) (P (gcons A x t)))
       l (glist A) (P l))
   (lam A P pn pc l
     ((nat_rect (lam q (pi v (gvec A q) (P (tpair q v))))
        (lam v (unit_rect (lam u (P (tpair 0 u))) pn v))
        (lam j ih v (pc (pr1 v) (tpair j (pr2 v)) (ih (pr2 v))))
        (pr1 l))
      (pr2 l))))
 (defn gif (pi A UU c bool x A y A A) (lam A c x y (bool_rect (lam q A) x y c)))
 (defn gapp (pi A UU l (glist A) m (glist A) (glist A))
   (lam A l m (grec A (lam q (glist A)) m (lam x t ih (gcons A x ih)) l)))
 (defn gdest
   (pi b bool P (pi c bool UU)
       f (pi e (paths bool b true) (P true))
       g (pi e (paths bool b false) (P false))
       (P b))
   (lam b P f g ((bool_rect (lam c (pi e (paths bool b c) (P c))) f g b) (idpath b))))
 (defn gneg (pi T UU UU) (lam T (pi x T empty))))

; --- the model: an object is an address and its out-edges, a region a list of them ---
(test
 (defn gnl UU (glist nat))
 (defn gobj UU (total2 a nat gnl))
 (defn greg UU (glist gobj))
 (defn gnatb (pi a nat b nat bool)
   (lam a b (coprod_rect (lam c bool) (lam e true) (lam ne false) (isdeceqnat a b))))
 (defn gedges (pi a nat r greg gnl)
   (lam a r (grec gobj (lam q gnl) (gnil nat)
     (lam o t ih (gif gnl (gnatb a (pr1 o)) (pr2 o) ih)) r)))
 (defn gin (pi b nat l gnl UU)
   (lam b l (grec nat (lam q UU) empty (lam x t ih (coprod (paths nat x b) ih)) l)))
 (defn gfst (pi r greg gnl)
   (lam r (grec gobj (lam q gnl) (gnil nat) (lam o t ih (gcons nat (pr1 o) ih)) r)))
 (defn gpresent (pi a nat r greg UU) (lam a r (gin a (gfst r))))
 (defn gany (pi a nat l gnl bool)
   (lam a l (grec nat (lam q bool) false (lam x t ih (gif bool (gnatb a x) true ih)) l)))
 (defn gpresentb (pi a nat r greg bool) (lam a r (gany a (gfst r))))
 (defn gfilter (pi f (pi x nat bool) l gnl gnl)
   (lam f l (grec nat (lam q gnl) (gnil nat)
     (lam x t ih (gif gnl (f x) (gcons nat x ih) ih)) l)))
 (defn gflat (pi f (pi x nat gnl) l gnl gnl)
   (lam f l (grec nat (lam q gnl) (gnil nat) (lam x t ih (gapp nat (f x) ih)) l)))
 ; reachability, an absent object a dead end: a seed at step 0, an edge from step n at step n+1
 (defn greachn (pi r greg s gnl n nat a nat UU)
   (lam r s n (nat_rect (lam q (pi a nat UU))
     (lam a (gin a s))
     (lam j ih b (total2 a nat (total2 x (ih a) (gin b (gedges a r)))))
     n)))
 (defn greach (pi r greg s gnl a nat UU) (lam r s a (total2 n nat (greachn r s n a))))
 (defn gyoung (pi nur greg roots gnl gnl) (lam nur roots (gfilter (lam a (gpresentb a nur)) roots)))
 (defn gremyoung (pi nur greg old greg rem gnl gnl)
   (lam nur old rem (gflat (lam oa (gfilter (lam y (gpresentb y nur)) (gedges oa old))) rem)))
 (defn gseeds (pi nur greg old greg rem gnl roots gnl gnl)
   (lam nur old rem roots (gapp nat (gyoung nur roots) (gremyoung nur old rem))))
 (defn gremcomplete (pi nur greg old greg rem gnl UU)
   (lam nur old rem (pi a nat y nat h (gpresent a old) i (gin y (gedges a old)) j (gpresent y nur) (gin a rem))))
 (defn gdisjoint (pi nur greg old greg UU)
   (lam nur old (pi a nat h (gpresent a nur) (gneg (gpresent a old))))))

; --- the model computes: 1 and 2 reach each other and 3; 9 is dead, 7 absent, and the drain says so ---
(test
 (defn gl2 (pi a nat b nat gnl) (lam a b (gcons nat a (gcons nat b (gnil nat)))))
 (defn gr3 greg
   (gcons gobj (tpair 1 (gcons nat 2 (gnil nat)))
     (gcons gobj (tpair 2 (gl2 1 3))
       (gcons gobj (tpair 3 (gnil nat))
         (gcons gobj (tpair 9 (gcons nat 1 (gnil nat))) (gnil gobj))))))
 (vof 0 'true = vof 0 '(gpresentb 9 gr3))
 (vof 0 'false = vof 0 '(gpresentb 7 gr3))
 ((vof 0 '(gl2 1 3)) = (vof 0 '(gedges 2 gr3)))
 ((vof 0 '(gnil nat)) = (vof 0 '(gedges 7 gr3))))

; --- reach's constructors and its induction ---
(test
 (defn gseed (pi r greg s gnl a nat h (gin a s) (greach r s a)) (lam r s a h (tpair 0 h)))
 (defn gstep (pi r greg s gnl a nat b nat h (greach r s a) i (gin b (gedges a r)) (greach r s b))
   (lam r s a b h i (tpair (succ (pr1 h)) (tpair a (tpair (pr2 h) i)))))
 (defq greachind
   (pi r greg s gnl P (pi a nat UU)
       hs (pi a nat h (gin a s) (P a))
       ht (pi a nat b nat h (greach r s a) p (P a) i (gin b (gedges a r)) (P b))
       a nat h (greach r s a) (P a))
   (lam r s P hs ht a h
     ((nat_rect (lam q (pi c nat v (greachn r s q c) (P c)))
        (lam c v (hs c v))
        (lam j ih c v (ht (pr1 v) c (tpair j (pr1 (pr2 v))) (ih (pr1 v) (pr1 (pr2 v))) (pr2 (pr2 v))))
        (pr1 h))
      a (pr2 h)))))

; --- gnatb reads as equality ---
(test
 (elfold '(gnl greg gseeds gyoung gremyoung gif gapp gedges gfst gany gpresentb gpresent gin gfilter gflat gnodup ggray gcond gdel gcheney gnatb add (gnil nat) (gcons nat)))

(elq 'gnatbeq '(pi a nat b nat h (paths bool (gnatb a b) true) (paths nat a b))
   '(lam a b (cases (isdeceqnat a b) (lam e h e) (lam ne h (absurd (nopathsfalsetotrue h))))))
 (elq 'gnatbne '(pi a nat b nat h (paths bool (gnatb a b) false) (gneg (paths nat a b)))
   '(lam a b (cases (isdeceqnat a b) (lam e h (absurd (nopathstruetofalse h))) (lam ne h ne))))
 (elq 'gnatbrefl '(pi a nat (paths bool (gnatb a a) true))
   '(lam a (cases (isdeceqnat a a) (lam e rfl) (lam ne (absurd (ne rfl))))))
 (elq 'gnatbt '(pi a nat b nat e (paths nat a b) (paths bool (gnatb a b) true))
   '(lam a b e (rw e (gnatbrefl a)))))

; --- membership: presentb reads as present, and app and filter and flat keep it ---
(test
 (elq 'gany2in '(pi a nat l gnl h (paths bool (gany a l) true) (gin a l))
   '(lam a l (ind l
      (lam h (absurd (nopathsfalsetotrue h)))
      (lam x t ih (ifb (gnatb a x)
        (lam e h (ii1 (sym (gnatbeq _ _ e))))
        (lam e h (ii2 (ih h))))))))
 (elq 'gin2any '(pi a nat l gnl h (gin a l) (paths bool (gany a l) true))
   '(lam a l (ind l
      (lam h (absurd h))
      (lam x t ih h (ifb (gnatb a x)
        (lam e rfl)
        (lam e (cases h (lam p (absurd (gnatbne _ _ e (sym p)))) (lam p (ih p)))))))))
 (elq 'ginappl '(pi b nat l gnl m gnl h (gin b l) (gin b (gapp nat l m)))
   '(lam b l m (ind l
      (lam h (absurd h))
      (lam x t ih h (cases h (lam p (ii1 p)) (lam p (ii2 (ih p))))))))
 (elq 'ginappr '(pi b nat l gnl m gnl h (gin b m) (gin b (gapp nat l m)))
   '(lam b l m h (ind l h (lam x t ih (ii2 ih)))))
 (elq 'ginappor '(pi b nat l gnl m gnl h (gin b (gapp nat l m)) (coprod (gin b l) (gin b m)))
   '(lam b l m (ind l
      (lam h (ii2 h))
      (lam x t ih h (cases h
        (lam p (ii1 (ii1 p)))
        (lam p (cases (ih p) (lam p2 (ii1 (ii2 p2))) (lam p2 (ii2 p2)))))))))
 (elq 'gfilterin '(pi f (pi x nat bool) y nat l gnl h (gin y l) hf (paths bool (f y) true) (gin y (gfilter f l)))
   '(lam f y l (ind l
      (lam h hf (absurd h))
      (lam x t ih h hf (ifb (f x)
        (lam e (cases h (lam p (ii1 p)) (lam p (ii2 (ih p hf)))))
        (lam e (cases h
          (lam p (absurd (nopathsfalsetotrue (trans (sym e) (trans (cong f p) hf)))))
          (lam p (ih p hf)))))))))
 (elq 'ginflat '(pi f (pi x nat gnl) y nat a nat l gnl h (gin a l) i (gin y (f a)) (gin y (gflat f l)))
   '(lam f y a l (ind l
      (lam h i (absurd h))
      (lam x t ih h i (cases h
        (lam p (ginappl y (f x) (gflat f t) (rw (sym p) i)))
        (lam p (ginappr y (f x) (gflat f t) (ih p i)))))))))

; --- edges: an absent address has none, an edge witnesses its source, an append reads through ---
(test
 (elq 'gedgesabsent '(pi a nat r greg h (gneg (gpresent a r)) (paths gnl (gedges a r) (gnil nat)))
   '(lam a r (ind r
      (lam h rfl)
      (lam o t ih h (ifb (gnatb a (pr1 o))
        (lam e (absurd (h (ii1 (sym (gnatbeq _ _ e))))))
        (lam e (ih (lam p (h (ii2 p))))))))))
 (elq 'gedgespresent '(pi a nat b nat r greg h (gin b (gedges a r)) (gpresent a r))
   '(lam a b r (ind r
      (lam h (absurd h))
      (lam o t ih (ifb (gnatb a (pr1 o))
        (lam e h (ii1 (sym (gnatbeq _ _ e))))
        (lam e h (ii2 (ih h))))))))
 (elq 'gedgesappl '(pi a nat p greg q greg h (gpresent a p) (paths gnl (gedges a (gapp gobj p q)) (gedges a p)))
   '(lam a p q (ind p
      (lam h (absurd h))
      (lam o t ih h (ifb (gnatb a (pr1 o))
        (lam e rfl)
        (lam e (cases h
          (lam m (absurd (gnatbne _ _ e (sym m))))
          (lam m (ih m)))))))))
 (elq 'gedgesappr '(pi a nat p greg q greg h (gneg (gpresent a p)) (paths gnl (gedges a (gapp gobj p q)) (gedges a q)))
   '(lam a p q (ind p
      (lam h rfl)
      (lam o t ih h (ifb (gnatb a (pr1 o))
        (lam e (absurd (h (ii1 (sym (gnatbeq _ _ e))))))
        (lam e (ih (lam m (h (ii2 m)))))))))))

; --- a complete barrier loses no live young object ---
(test
 (elq 'gindec '(pi a nat l gnl (coprod (gin a l) (gneg (gin a l))))
   '(lam a l (ifb (gany a l)
      (lam e (ii1 (gany2in _ _ e)))
      (lam e (ii2 (lam h (nopathstruetofalse (trans (sym (gin2any _ _ h)) e))))))))
 (elq 'gbarriersound '(pi nur greg old greg rem gnl roots gnl hd (gdisjoint nur old) hr (gremcomplete nur old rem)
       y nat py (gpresent y nur) ry (greach (gapp gobj nur old) roots y)
       (greach nur (gseeds nur old rem roots) y))
   '(lam nur old rem roots hd hr y py ry
     ((greachind (gapp gobj nur old) roots
       (lam a (pi p (gpresent a nur) (greach nur (gseeds nur old rem roots) a)))
       (lam a h p (gseed _ _ a (ginappl a (gyoung nur roots) (gremyoung nur old rem)
         (gfilterin (lam w (gpresentb w nur)) a roots h (gin2any a (gfst nur) p)))))
       (lam a b hra ih i p (cases (gindec a (gfst nur))
         (lam an (gstep _ _ a b (ih an) (rw (gedgesappl a nur old an) i)))
         (lam an (let j (the (gin b (gedges a old)) (rw (gedgesappr a nur old an) i))
           (gseed _ _ b (ginappr b (gyoung nur roots) (gremyoung nur old rem)
             (ginflat (lam oa (gfilter (lam w (gpresentb w nur)) (gedges oa old))) b a rem
               (hr a b (gedgespresent a b old j) j p)
               (gfilterin (lam w (gpresentb w nur)) b (gedges a old) j (gin2any b (gfst nur) p)))))))))
       y ry) py)))
 (defq gminorloses
   (pi nur greg old greg rem gnl roots gnl y nat hd (gdisjoint nur old) py (gpresent y nur)
       ry (greach (gapp gobj nur old) roots y)
       lost (gneg (greach nur (gseeds nur old rem roots) y))
       (gneg (gremcomplete nur old rem)))
   (lam nur old rem roots y hd py ry lost
     (lam hr (lost (gbarriersound nur old rem roots hd hr y py ry))))))

; --- the pause bound: survivors never outnumber the nursery, and old does not appear ---
(test
 (defn gnodup (pi l gnl UU)
   (lam l (grec nat (lam q UU) unit (lam x t ih (total2 u (gneg (gin x t)) ih)) l)))
 (defn gincl (pi l gnl m gnl UU) (lam l m (pi y nat h (gin y l) (gin y m))))
 (defn gdel (pi x nat m gnl gnl)
   (lam x m (grec nat (lam q gnl) (gnil nat)
     (lam z t ih (gif gnl (gnatb x z) t (gcons nat z ih))) m)))
 (elq 'gdellen '(pi x nat m gnl h (gin x m) (paths nat (pr1 m) (succ (pr1 (gdel x m)))))
   '(lam x m (ind m
      (lam h (absurd h))
      (lam z t ih h (ifb (gnatb x z)
        (lam e rfl)
        (lam e (cases h
          (lam p (absurd (gnatbne _ _ e (sym p))))
          (lam p (cong (lam n (succ n)) (ih p))))))))))
 (elq 'gdelin '(pi x nat y nat ne (gneg (paths nat y x)) m gnl h (gin y m) (gin y (gdel x m)))
   '(lam x y ne m (ind m
      (lam h h)
      (lam z t ih h (ifb (gnatb x z)
        (lam e (cases h (lam p (absurd (ne (sym (trans (gnatbeq _ _ e) p))))) (lam p p)))
        (lam e (cases h (lam p (ii1 p)) (lam p (ii2 (ih p))))))))))
 (elq 'gpigeon '(pi l gnl nd (gnodup l) m gnl inc (gincl l m) (paths bool (natgtb (pr1 l) (pr1 m)) false))
   '(lam l (ind l
      (lam nd m inc rfl)
      (lam x t ih nd m inc
        (rw (sym (gdellen x m (inc x (ii1 rfl))))
          (ih (pr2 nd) (gdel x m)
            (lam y hy (gdelin x y (lam p ((pr1 nd) (rw p hy))) m (inc y (ii2 hy))))))))))
 (elq 'gfstlen '(pi r greg (paths nat (pr1 (gfst r)) (pr1 r)))
   '(lam r (ind r rfl (lam o t ih (cong (lam n (succ n)) ih)))))
 (defn gpromoted (pi nur greg seeds gnl y nat UU)
   (lam nur seeds y (total2 u (gpresent y nur) (greach nur seeds y))))
 (elq 'gminorbounded '(pi nur greg seeds gnl l gnl nd (gnodup l) all (pi y nat h (gin y l) (gpromoted nur seeds y))
       (paths bool (natgtb (pr1 l) (pr1 nur)) false))
   '(lam nur seeds l nd all (rw (gfstlen nur) (gpigeon l nd (gfst nur) (lam y h (pr1 (all y h))))))))

; --- tenured growth that keeps no pointer into the nursery leaves the survivors the same ---
(test
 (elq 'gfilternone '(pi f (pi x nat bool) es gnl h (pi y nat i (gin y es) (paths bool (f y) false))
       (paths gnl (gfilter f es) (gnil nat)))
   '(lam f es (ind es
      (lam h rfl)
      (lam x t ih h (ifb (f x)
        (lam e (absurd (nopathstruetofalse (trans (sym e) (h x (ii1 rfl))))))
        (lam e (ih (lam y i (h y (ii2 i))))))))))
 (elq 'gflatext '(pi f (pi x nat gnl) g (pi x nat gnl) l gnl h (pi x nat i (gin x l) (paths gnl (f x) (g x)))
       (paths gnl (gflat f l) (gflat g l)))
   '(lam f g l (ind l
      (lam h rfl)
      (lam x t ih h (trans
        (cong (lam w (gapp nat w (gflat f t))) (h x (ii1 rfl)))
        (cong (lam w (gapp nat (g x) w)) (ih (lam y i (h y (ii2 i))))))))))
 (defn gtenureblind (pi nur greg ext greg UU)
   (lam nur ext (pi a nat y nat i (gin y (gedges a ext)) (gneg (gpresent y nur)))))
 (elq 'gseedsblind '(pi nur greg old greg ext greg rem gnl roots gnl hb (gtenureblind nur ext)
       (paths gnl (gseeds nur (gapp gobj old ext) rem roots) (gseeds nur old rem roots)))
   '(lam nur old ext rem roots hb
     (cong (lam w (gapp nat (gyoung nur roots) w))
       (gflatext
         (lam oa (gfilter (lam w (gpresentb w nur)) (gedges oa (gapp gobj old ext))))
         (lam oa (gfilter (lam w (gpresentb w nur)) (gedges oa old)))
         rem
         (lam oa i (cases (gindec oa (gfst old))
           (lam hp (cong (gfilter (lam w (gpresentb w nur))) (gedgesappl oa old ext hp)))
           (lam hq (trans
             (cong (gfilter (lam w (gpresentb w nur))) (gedgesappr oa old ext hq))
             (trans
               (gfilternone (lam w (gpresentb w nur)) (gedges oa ext)
                 (lam y hy (ifb (gpresentb y nur)
                   (lam e (absurd (hb oa y hy (gany2in _ _ e))))
                   (lam e rfl))))
               (sym (cong (gfilter (lam w (gpresentb w nur))) (gedgesabsent oa old hq))))))))))))
 (defn giff (pi A UU B UU UU) (lam A B (total2 f (pi a A B) (pi b B A))))
 (elq 'gminorflat '(pi nur greg old greg ext greg rem gnl roots gnl y nat hb (gtenureblind nur ext)
       (giff (gpromoted nur (gseeds nur (gapp gobj old ext) rem roots) y)
             (gpromoted nur (gseeds nur old rem roots) y)))
   '(lam nur old ext rem roots y hb (tpair
     (lam h (rw (gseedsblind nur old ext rem roots hb) h))
     (lam h (rw (sym (gseedsblind nur old ext rem roots hb)) h))))))

; --- graying: a present, unseen target goes gray, and counts as seen for the next edge ---
(test
 (defn gcond (pi r greg s gnl b nat bool)
   (lam r s b (andb (gpresentb b r) (negb (gany b s)))))
 (defn ggray (pi r greg s gnl es gnl gnl)
   (lam r s es
     ((grec nat (lam q (pi c gnl gnl))
        (lam c (gnil nat))
        (lam b t ih c (gif gnl (gcond r c b) (gcons nat b (ih (gcons nat b c))) (ih c)))
        es)
      s)))
 (elq 'gcondp '(pi r greg s gnl e nat h (paths bool (gcond r s e) true) (gpresent e r))
   '(lam r s e (ifb (gpresentb e r)
     (lam x h (gany2in _ _ x))
     (lam x h (absurd (nopathsfalsetotrue h))))))
 (elq 'gcondn '(pi r greg s gnl e nat h (paths bool (gcond r s e) true) (gneg (gin e s)))
   '(lam r s e (ifb (gpresentb e r)
     (lam x (ifb (gany e s)
       (lam y h (absurd (nopathsfalsetotrue h)))
       (lam y h hin (nopathstruetofalse (trans (sym (gin2any _ _ hin)) y)))))
     (lam x h (absurd (nopathsfalsetotrue h))))))
 (elq 'gnotany '(pi a nat l gnl h (gneg (gin a l)) (paths bool (gany a l) false))
   '(lam a l h (ifb (gany a l) (lam e (absurd (h (gany2in _ _ e)))) (lam e rfl))))
 (elq 'gcondt '(pi r greg s gnl e nat hp (gpresent e r) hq (gneg (gin e s)) (paths bool (gcond r s e) true))
   '(lam r s e hp hq (trans
     (cong (lam w (andb w (negb (gany e s)))) (gin2any e (gfst r) hp))
     (cong negb (gnotany e s hq)))))
 (elq 'gcondf '(pi r greg s gnl e nat h (paths bool (gcond r s e) false) hp (gpresent e r) (gin e s))
   '(lam r s e h hp (cases (gindec e s)
     (lam i i)
     (lam n (absurd (nopathstruetofalse (trans (sym (gcondt r s e hp n)) h)))))))
 (elq 'gcondno '(pi r greg s gnl e nat h (coprod (paths bool (gpresentb e r) false) (gin e s))
       (paths bool (gcond r s e) false))
   '(lam r s e h (cases h
     (lam p (cong (lam w (andb w (negb (gany e s)))) p))
     (lam i (ifb (gpresentb e r) (lam x (cong negb (gin2any e s i))) (lam x rfl))))))
 (elq 'ggraysub '(pi r greg s gnl es gnl b nat h (gin b (ggray r s es)) (gin b es))
   '(lam r s es b (rev s (ind es
     (lam c h h)
     (lam e t ih c (ifb (gcond r c e)
       (lam x h (cases h (lam p (ii1 p)) (lam p (ii2 (ih (gcons nat e c) p)))))
       (lam x h (ii2 (ih c h)))))))))
 (elq 'ggraypresent '(pi r greg s gnl es gnl b nat h (gin b (ggray r s es)) (gpresent b r))
   '(lam r s es b (rev s (ind es
     (lam c h (absurd h))
     (lam e t ih c (ifb (gcond r c e)
       (lam x h (cases h (lam p (rw p (gcondp r c e x))) (lam p (ih (gcons nat e c) p))))
       (lam x h (ih c h))))))))
 (elq 'ggraynew '(pi r greg s gnl es gnl b nat h (gin b (ggray r s es)) (gneg (gin b s)))
   '(lam r s es b (rev s (ind es
     (lam c h (absurd h))
     (lam e t ih c (ifb (gcond r c e)
       (lam x h (cases h (lam p (rw p (gcondn r c e x))) (lam p (lam i (ih (gcons nat e c) p (ii2 i))))))
       (lam x h (ih c h))))))))
 (elq 'ggraynodup '(pi r greg s gnl es gnl (gnodup (ggray r s es)))
   '(lam r s es (rev s (ind es
     (lam c tt)
     (lam e t ih c (ifb (gcond r c e)
       (lam x (tpair (lam i (ggraynew r (gcons nat e c) t e i (ii1 rfl))) (ih (gcons nat e c))))
       (lam x (ih c))))))))
 (elq 'ggraycovers '(pi r greg es gnl s gnl b nat h (gin b es) hp (gpresent b r)
       (coprod (gin b s) (gin b (ggray r s es))))
   '(lam r es s b (rev s (ind es
     (lam c h hp (absurd h))
     (lam e t ih c (ifb (gcond r c e)
       (lam x h hp (cases h
         (lam p (ii2 (ii1 p)))
         (lam p (cases (ih (gcons nat e c) p hp)
           (lam i (cases i (lam m (ii2 (ii1 m))) (lam m (ii1 m))))
           (lam g (ii2 (ii2 g)))))))
       (lam x h hp (cases h
         (lam p (ii1 (rw p (gcondf r c e x (rw (sym p) hp)))))
         (lam p (ih c p hp))))))))))
 (elq 'ggraynone '(pi r greg es gnl s gnl h (pi b nat i (gin b es) (coprod (paths bool (gpresentb b r) false) (gin b s)))
       (paths gnl (ggray r s es) (gnil nat)))
   '(lam r es s (rev s (ind es
     (lam c h rfl)
     (lam e t ih c h
       (rw (sym (gcondno r c e (h e (ii1 rfl)))) (ih c (lam b i (h b (ii2 i)))))))))))

; --- append's laws, and that appending keeps nodup ---
(test
 (elq 'gapp0 '(pi l gnl (paths gnl (gapp nat l (gnil nat)) l))
   '(lam l (ind l rfl (lam x t ih (cong (lam w (gcons nat x w)) ih)))))
 (elq 'gappassoc '(pi l gnl m gnl n gnl (paths gnl (gapp nat (gapp nat l m) n) (gapp nat l (gapp nat m n))))
   '(lam l m n (ind l rfl (lam x t ih (cong (lam w (gcons nat x w)) ih)))))
 (elq 'gstepshape '(pi b gnl a nat gs gnl g gnl
       (paths gnl (gapp nat (gapp nat b (gcons nat a (gnil nat))) (gapp nat gs g))
                  (gapp nat (gapp nat b (gcons nat a gs)) g)))
   '(lam b a gs g (trans (gappassoc b (gcons nat a (gnil nat)) (gapp nat gs g)) (sym (gappassoc b (gcons nat a gs) g)))))
 (elq 'gnodupapp '(pi l gnl m gnl hl (gnodup l) hm (gnodup m) hd (pi x nat i (gin x m) (gneg (gin x l)))
       (gnodup (gapp nat l m)))
   '(lam l m (ind l
     (lam hl hm hd hm)
     (lam a t ih hl hm hd (tpair
       (lam i (cases (ginappor a t m i) (lam p ((pr1 hl) p)) (lam p (hd a p (ii1 rfl)))))
       (ih (pr2 hl) hm (lam x i j (hd x i (ii2 j)))))))))
 (elq 'glenapp '(pi l gnl m gnl (paths nat (pr1 (gapp nat l m)) (add (pr1 l) (pr1 m))))
   '(lam l m (ind l rfl (lam x t ih (cong (lam n (succ n)) ih))))))

; --- the copy loop: [] and gray matched first, so an empty answer only means an unfinished scan ---
(test
 (defn gopt UU (coprod gnl unit))
 (defn gcheney (pi r greg fuel nat black gnl gray gnl gopt)
   (lam r fuel
     (nat_rect (lam q (pi black gnl gray gnl gopt))
       (lam black gray (grec nat (lam w gopt) (ii1 black) (lam a gs ih (ii2 tt)) gray))
       (lam f rec black gray (grec nat (lam w gopt) (ii1 black)
         (lam a gs ih (rec (gapp nat black (gcons nat a (gnil nat)))
                           (gapp nat gs (ggray r (gapp nat black (gcons nat a gs)) (gedges a r)))))
         gray))
       fuel)))
 (defn gdrain (pi r greg roots gnl gopt)
   (lam r roots (gcheney r (succ (pr1 r)) (gnil nat) (ggray r (gnil nat) roots))))
 (defn gclosed (pi r greg l gnl m gnl UU)
   (lam r l m (pi b nat h (gin b l) y nat i (gin y (gedges b r)) j (gpresent y r) (gin y m))))
 (defn gall (pi P (pi a nat UU) l gnl UU) (lam P l (pi b nat h (gin b l) (P b))))
 (defn gstepok (pi r greg P (pi a nat UU) UU)
   (lam r P (pi a nat y nat p (P a) i (gin y (gedges a r)) (P y))))
 (defn gconcl (pi r greg P (pi a nat UU) l gnl res gnl UU)
   (lam r P l res
     (total2 u (gnodup res) (total2 v (gincl l res) (total2 w (gclosed r res res) (gall P res))))))
 (defn gchgoal (pi r greg P (pi a nat UU) fuel nat black gnl gray gnl res gnl UU)
   (lam r P fuel black gray res
     (pi hc (paths gopt (gcheney r fuel black gray) (ii1 res))
         nd (gnodup (gapp nat black gray))
         hcl (gclosed r black (gapp nat black gray))
         hp (gall P (gapp nat black gray))
         (gconcl r P (gapp nat black gray) res))))
 ; an empty answer is not a some, and a some gives up what it holds
 (defq gnone (pi res gnl h (paths gopt (ii2 tt) (ii1 res)) empty)
   (lam res h (transportf gopt
     (lam o (coprod_rect (lam w UU) (lam w empty) (lam w unit) o))
     (ii2 tt) (ii1 res) h tt)))
 (elq 'gsome '(pi l gnl res gnl h (paths gopt (ii1 l) (ii1 res)) (paths gnl l res))
   '(lam l res h (cong (lam o (coprod_rect (lam w gnl) (lam w w) (lam w l) o)) h)))
 (elq 'gchdone '(pi r greg P (pi a nat UU) black gnl res gnl hc (paths gopt (ii1 black) (ii1 res))
       nd (gnodup (gapp nat black (gnil nat)))
       hcl (gclosed r black (gapp nat black (gnil nat)))
       hp (gall P (gapp nat black (gnil nat)))
       (gconcl r P (gapp nat black (gnil nat)) res))
   '(lam r P black res hc nd hcl hp (let e (gapp0 black)
     (rw (gsome _ _ hc) (tpair (rw e nd) (tpair (lam y h (rw e h))
       (tpair (lam b h y i j (rw e (hcl b h y i j))) (lam b h (hp b (rw (sym e) h))))))))))
 ; one induction for every conclusion; P is unit or (greach r roots)
 (elq 'gchinv '(pi r greg P (pi a nat UU) hs (gstepok r P) fuel nat black gnl gray gnl res gnl
       (gchgoal r P fuel black gray res))
   '(lam r P hs fuel (nind fuel
     (lam black gray res (ind gray
       (lam hc nd hcl hp (gchdone r P black res hc nd hcl hp))
       (lam a gs ih hc nd hcl hp (absurd (gnone res hc)))))
     (lam f ih black gray res (ind gray
       (lam hc nd hcl hp (gchdone r P black res hc nd hcl hp))
       (lam a gs ih2 hc nd hcl hp
           (let W (gapp nat black (gcons nat a gs))
           (let G (ggray r W (gedges a r))
           (let B (gapp nat black (gcons nat a (gnil nat)))
           (let R (gapp nat gs G)
           (let e (gstepshape black a gs G)
           (let e2 (sym e)
           (let X (ih B R res hc
               (rw e2 (gnodupapp W G nd (ggraynodup r W (gedges a r)) (lam x i (ggraynew r W (gedges a r) x i))))
               (lam b hb y hy hpr (rw e2 (cases (ginappor b black (gcons nat a (gnil nat)) hb)
                 (lam bb (ginappl y W G (hcl b bb y hy hpr)))
                 (lam ba (cases ba
                   (lam pab (cases (ggraycovers r (gedges a r) W y (rw (sym pab) hy) hpr)
                     (lam g (ginappl y W G g))
                     (lam g (ginappr y W G g))))
                   (lam z (absurd z)))))))
               (lam b hb (cases (ginappor b W G (rw e hb))
                 (lam hw (hp b hw))
                 (lam hg (hs a b (hp a (ginappr a black (gcons nat a gs) (ii1 rfl)))
                   (ggraysub r W (gedges a r) b hg))))))
             (tpair (pr1 X)
               (tpair
                 (lam y h ((pr1 (pr2 X)) y (rw e2 (ginappl y W G h))))
                 (pr2 (pr2 X))))))))))))))))))

; --- nodup bounds copies by the from-space, which closes the fuel argument ---
(test
 (elq 'gadd1 '(pi b nat (paths nat (add b 1) (succ b)))
   '(lam b (nind b rfl (lam j ih (cong (lam n (succ n)) ih)))))
 (elq 'gaddstep '(pi f nat b nat (paths nat (add f (add b 1)) (succ (add f b))))
   '(lam f b (nind f (gadd1 b) (lam j ih (cong (lam n (succ n)) ih)))))
 (elq 'ggtadd '(pi b nat g nat r nat h (paths bool (natgtb b r) true) (paths bool (natgtb (add b g) r) true))
   '(lam b g (nind b
     (lam r h (absurd (nopathsfalsetotrue h)))
     (lam j ih r (nind r (lam h rfl) (lam k u h (ih k h)))))))
 (defn gfueled (pi r greg fuel nat black gnl UU)
   (lam r fuel black (paths bool (natgtb (add fuel (pr1 black)) (pr1 r)) true)))
 (defn genough (pi r greg fuel nat black gnl gray gnl UU)
   (lam r fuel black gray
     (pi nd (gnodup (gapp nat black gray))
         inc (gincl (gapp nat black gray) (gfst r))
         lt (gfueled r fuel black)
         (total2 res gnl (paths gopt (gcheney r fuel black gray) (ii1 res))))))
 (elq 'gcheneyenough '(pi r greg fuel nat black gnl gray gnl (genough r fuel black gray))
   '(lam r fuel (nind fuel
     (lam black gray (ind gray
       (lam nd inc lt (tpair black rfl))
       (lam a gs ih nd inc lt (absurd (nopathstruetofalse (trans
         (sym (ggtadd (pr1 black) (pr1 (gcons nat a gs)) (pr1 r) lt))
         (rw (glenapp black (gcons nat a gs))
           (rw (gfstlen r) (gpigeon (gapp nat black (gcons nat a gs)) nd (gfst r) inc)))))))))
     (lam f ih black gray (ind gray
       (lam nd inc lt (tpair black rfl))
       (lam a gs ih2 nd inc lt
           (let W (gapp nat black (gcons nat a gs))
           (let G (ggray r W (gedges a r))
           (let B (gapp nat black (gcons nat a (gnil nat)))
           (let R (gapp nat gs G)
           (let e (gstepshape black a gs G)
           (let e2 (sym e)
             (ih B R
               (rw e2 (gnodupapp W G nd (ggraynodup r W (gedges a r)) (lam x i (ggraynew r W (gedges a r) x i))))
               (lam x hx (cases (ginappor x W G (rw e hx))
                 (lam h (inc x h))
                 (lam h (ggraypresent r W (gedges a r) x h))))
               (rw (sym (glenapp black (gcons nat a (gnil nat))))
                 (rw (sym (gaddstep f (pr1 black))) lt)))))))))))))))
 ; the scan pointer catches the allocation pointer
 (elq 'gdrainterminates '(pi r greg roots gnl (total2 res gnl (paths gopt (gdrain r roots) (ii1 res))))
   '(lam r roots
     (gcheneyenough r (succ (pr1 r)) (gnil nat) (ggray r (gnil nat) roots)
       (ggraynodup r (gnil nat) roots)
       (lam x h (ggraypresent r (gnil nat) roots x h))
       (transportf nat (lam w (paths bool (natgtb w (pr1 r)) true)) _ _
         (sym (maponpaths nat nat (lam n (succ n)) _ _ (natplusr0 (pr1 r))))
         (natgthsnn (pr1 r)))))))

; --- the drain copies each once, nothing dead, nothing live lost; a second pass copies nothing ---
(test
 (elq 'gdrainsound '(pi r greg roots gnl res gnl y nat h (paths gopt (gdrain r roots) (ii1 res)) i (gin y res) (greach r roots y))
   '(lam r roots res y h i
     ((pr2 (pr2 (pr2 (gchinv r (lam a (greach r roots a)) (lam a b p j (gstep r roots a b p j))
         (succ (pr1 r)) (gnil nat) (ggray r (gnil nat) roots) res h
         (ggraynodup r (gnil nat) roots)
         (lam b j z k l (absurd j))
         (lam b j (gseed r roots b (ggraysub r (gnil nat) roots b j)))))))
      y i)))
 (elq 'gdrainunit '(pi r greg roots gnl res gnl h (paths gopt (gdrain r roots) (ii1 res))
       (gconcl r (lam a unit) (ggray r (gnil nat) roots) res))
   '(lam r roots res h
     (gchinv r (lam a unit) (lam a y p i tt) (succ (pr1 r)) (gnil nat) (ggray r (gnil nat) roots) res h
       (ggraynodup r (gnil nat) roots)
       (lam b i y j k (absurd i))
       (lam b i tt))))
 (defq gdrainonce (pi r greg roots gnl res gnl h (paths gopt (gdrain r roots) (ii1 res)) (gnodup res))
   (lam r roots res h (pr1 (gdrainunit r roots res h))))
 (elq 'gdraincomplete '(pi r greg roots gnl res gnl y nat h (paths gopt (gdrain r roots) (ii1 res))
       hr (greach r roots y) hp (gpresent y r) (gin y res))
   '(lam r roots res y h hr hp
     ((greachind r roots (lam a (pi p (gpresent a r) (gin a res)))
       (lam a i p ((pr1 (pr2 (gdrainunit r roots res h))) a
         (cases (ggraycovers r roots (gnil nat) a i p) (lam s (absurd s)) (lam g g))))
       (lam a b hra ih i p
         ((pr1 (pr2 (pr2 (gdrainunit r roots res h)))) a (ih (gedgespresent a b r i)) b i p))
       y hr) hp)))
 (elq 'gdrainsecond '(pi r greg roots gnl res gnl a nat h (paths gopt (gdrain r roots) (ii1 res)) i (gin a res)
       (paths gnl (ggray r res (gedges a r)) (gnil nat)))
   '(lam r roots res a h i
     (ggraynone r (gedges a r) res
       (lam b j (cases (gindec b (gfst r))
         (lam p (ii2 ((pr1 (pr2 (pr2 (gdrainunit r roots res h)))) a i b j p)))
         (lam n (ii1 (gnotany b (gfst r) n)))))))))

; --- the drain on the model, and what the kernel refuses of it ---
(test
 ((vof 0 '(the gopt (ii1 (gcons nat 1 (gl2 2 3))))) = (vof 0 '(gdrain gr3 (gl2 1 7))))
 ((vof 0 '(the gopt (ii2 tt))) = (vof 0 '(gcheney gr3 0 (gnil nat) (gl2 1 7))))
 ((vof 0 '(gcons nat 1 (gnil nat))) = (vof 0 '(ggray gr3 (gnil nat) (gl2 1 1))))
 ((vof 0 '(gcons nat 1 (gnil nat))) = (vof 0 '(gfilter (lam w (gpresentb w gr3)) (gl2 1 7)))))

(hear (p \ e \ peep HELPC () 0 @ h (h ? (h p e) 0)))
(test
 ('rejected = rejects (z \ defq gnofuel (paths gopt (gcheney gr3 0 (gnil nat) (gl2 1 7)) (ii1 (gnil nat))) (idpath (ii2 tt))))
 ; nothing live lost does not come free: membership needs the drain's own answer
 ('rejected = rejects (z \ defq gbadsound
   (pi r greg roots gnl res gnl y nat hr (greach r roots y) (gin y res))
   (lam r roots res y hr (fromempty (gin y res) hr)))))
(hear test-strict)
