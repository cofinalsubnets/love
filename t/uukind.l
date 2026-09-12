; t/uukind.l -- generated from t/proto/kinds.l by u/kinds2uu.l. Do
; not edit; refresh with `make uukind`. The abstract kinds-lattice join (and
; its num? guard) compiled into uu over a nat-coded carrier, kind = its rank
; (str the branch off the spine). t/uukindlaw.l proves the semilattice laws
; of these terms at corpus time -- a law-breaking kinds.l edit fails a check.
; Substrate: t/uu.l (natgtb / nateqb / andb / bool_rect).
; a name is emitted per code, so t/uukindlaw.l cites a kind rather than its rank:
; the ranks are kinds.l's to renumber, and a law spelling one as an integer would
; go on passing about a different kind.
(test
 (defn ukbot nat 0)
 (defn ukcharm nat 1)
 (defn ukwhole nat 2)
 (defn ukreal nat 3)
 (defn ukcplx nat 4)
 (defn uktop nat 5)
 (defn ukstr nat 6)
 (defn numq
   (pi k nat bool)
   (lam k (let r k (andb (natgtb r 0) (natgtb 5 r)))))
 (defn kjoin
   (pi a nat (pi b nat nat))
   (lam a (lam b (bool_rect (lam gx nat) b (bool_rect (lam gx nat) a (bool_rect (lam gx nat) a (bool_rect (lam gx nat) (bool_rect (lam gx nat) b a (natgtb b a)) 5 (andb (numq a) (numq b))) (nateqb a b)) (nateqb b 0)) (nateqb a 0))))))
(: uk-codes '(0 1 2 3 4 5 6))
