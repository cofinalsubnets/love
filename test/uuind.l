; test/uuind.l -- uu's declared inductives: a family's recursor computes on a constructor, is
; stuck on a neutral, and a declaration that is not strictly positive is refused

; --- lists and trees: the recursor's hypothesis follows its field ---
(test
 (defind ilist (A UU) () (inil () (ilist A)) (icons (x A l (ilist A)) (ilist A)))
 (defn ilen (pi A UU l (ilist A) nat) (lam A l (ilist_rect A (lam q nat) 0 (lam x t ih (succ ih)) l)))
 (defn iapp (pi A UU l (ilist A) m (ilist A) (ilist A))
   (lam A l m (ilist_rect A (lam q (ilist A)) m (lam x t ih (icons A x ih)) l)))
 (defn il3 (ilist nat) (icons nat 1 (icons nat 2 (icons nat 3 (inil nat)))))
 (3 = vof 0 '(ilen nat il3))
 (6 = vof 0 '(ilen nat (iapp nat il3 il3)))
 (defq iappnil (pi A UU l (ilist A) (paths (ilist A) (iapp A (inil A) l) l)) (lam A l (idpath l)))
 (defq iappr (pi A UU l (ilist A) (paths (ilist A) (iapp A l (inil A)) l))
   (lam A l (ilist_rect A (lam q (paths (ilist A) (iapp A q (inil A)) q))
              (idpath (inil A))
              (lam x t ih (maponpaths (ilist A) (ilist A) (icons A x) (iapp A t (inil A)) t ih))
              l)))
 (defind itree () () (itleaf () itree) (itnode (l itree n nat r itree) itree))
 (defn isum (pi t itree nat) (lam t (itree_rect (lam q nat) 0 (lam l il n r ir (add il (add n ir))) t)))
 (6 = vof 0 '(isum (itnode (itnode itleaf 1 itleaf) 2 (itnode itleaf 3 itleaf))))
 ; uu2l runs the same recursors in love
 ([6 6] = [(lof '(ilen nat (iapp nat il3 il3))) (lof '(isum (itnode (itnode itleaf 1 itleaf) 2 (itnode itleaf 3 itleaf))))]))

; --- a field of functions: its hypothesis is a function too ---
(test
 (defind iord () () (izero () iord) (ilim (f (pi n nat iord)) iord))
 (defn ideep (pi o iord nat) (lam o (iord_rect (lam q nat) 0 (lam f ih (succ (ih 0))) o)))
 (2 = vof 0 '(ideep (ilim (lam n (ilim (lam m izero)))))))

; --- indexed families: the motive takes the indices, a constructor lands at its own ---
(test
 (defind ivec (A UU) (n nat) (ivnil () (ivec A 0)) (ivcons (k nat x A v (ivec A k)) (ivec A (succ k))))
 (defn ivlist (pi A UU n nat v (ivec A n) (ilist A))
   (lam A n v (ivec_rect A (lam m q (ilist A)) (inil A) (lam k x v ih (icons A x ih)) n v)))
 (2 = vof 0 '(ilen nat (ivlist nat 2 (ivcons nat 1 7 (ivcons nat 0 8 (ivnil nat))))))
 (defind ieven () (n nat) (iev0 () (ieven 0)) (ievss (k nat e (ieven k)) (ieven (succ (succ k)))))
 (defn ihalf (pi n nat e (ieven n) nat) (lam n e (ieven_rect (lam m q nat) 0 (lam k e ih (succ ih)) n e)))
 (2 = vof 0 '(ihalf 4 (ievss 2 (ievss 0 iev0))))
 (defq ihalfok (pi n nat e (ieven n) (paths nat (add (ihalf n e) (ihalf n e)) n))
   (lam n e (ieven_rect (lam m q (paths nat (add (ihalf m q) (ihalf m q)) m))
              (idpath 0)
              (lam k e ih (maponpaths nat nat (lam x (succ x))
                            (add (ihalf k e) (succ (ihalf k e))) (succ k)
                            (pathscomp0 nat (add (ihalf k e) (succ (ihalf k e))) (succ (add (ihalf k e) (ihalf k e))) (succ k)
                              (natplusnsm (ihalf k e) (ihalf k e))
                              (maponpaths nat nat (lam x (succ x)) (add (ihalf k e) (ihalf k e)) k ih))))
              n e))))

; --- what the kernel refuses ---
(hear (p \ e \ peep HELPC () 0 @ h (h ? (h p e) 0)))
(test
 ; a neutral list has no length to compute
 ('rejected = rejects (z \ defq ilen0 (pi A UU l (ilist A) (paths nat (ilen A l) 0)) (lam A l (idpath 0))))
 ('rejected = rejects (z \ defq ilen2 (paths nat (ilen nat (icons nat 5 (inil nat))) 2) (idpath 1)))
 ; negative, non-uniform and nested occurrences, and one in an index or a codomain's params
 ('rejected = rejects (z \ defind ineg () () (ineg0 (f (pi x ineg empty)) ineg)))
 ('rejected = rejects (z \ defind inon (A UU) () (inon0 (x (inon nat)) (inon A))))
 ('rejected = rejects (z \ defind inest () () (inest0 (x (ilist inest)) inest)))
 ('rejected = rejects (z \ defind iidx () (n nat) (iidx0 () (iidx (iidx 0)))))
 ('rejected = rejects (z \ defind ires (A UU) () (ires0 () (ires nat))))
 ; a taken name, a shadowed param, an ill-typed field
 ('rejected = rejects (z \ defind ilist () () (inil2 () ilist)))
 ('rejected = rejects (z \ defind ishad (A UU) () (ishad0 (A nat) (ishad A))))
 ('rejected = rejects (z \ defind ityp () () (ityp0 (x (succ nat)) ityp)))
 ; a family's names stay its own: an axiom at a constructor's arity would decode as one
 ('rejected = rejects (z \ axm icons (pi A UU x bool l (ilist A) (ilist A))))
 ('rejected = rejects (z \ defn ilist_rect nat 0)))
(hear test-strict)
