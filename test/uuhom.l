; test/uuhom.l -- the composition band of love's `*` as a uu term, its monoid laws by idpath
; the binary's `=` is structural, so these laws hold there only applied; here conv is NbE.
; guard: the uu kernel must load first; fail by name if not.
(test (elem 'vof (names ())))

(test
 ; love's `*` on the top band: (homcomp f g) x = f (g x), prel's compose order
 (defn homcomp
   (pi X UU Y UU Z UU f (pi y Y Z) g (pi x X Y) x X Z)
   (lam X Y Z f g x (f (g x))))
 ; the monoid laws by idpath: units by pi-eta on the neutral f, assoc by NbE
 (defq hom-lunit
   (pi X UU Y UU f (pi x X Y) (paths (pi x X Y) (homcomp X Y Y (idfun Y) f) f))
   (lam X Y f (idpath f)))
 (defq hom-runit
   (pi X UU Y UU f (pi x X Y) (paths (pi x X Y) (homcomp X X Y f (idfun X)) f))
   (lam X Y f (idpath f)))
 (defq hom-assoc
   (pi X UU Y UU Z UU W UU f (pi z Z W) g (pi y Y Z) h (pi x X Y)
      (paths (pi x X W)
        (homcomp X Y W (homcomp Y Z W f g) h)
        (homcomp X Z W f (homcomp X Y Z g h))))
   (lam X Y Z W f g h
      (idpath (homcomp X Z W f (homcomp X Y Z g h))))))

; one composite, three lanes (vof, lof, the binary's `*`) meeting at a numeral
('(homcomp nat nat nat (lam y (succ y)) (lam x (succ (succ x))) 3) @ hc
 (test
  (6 = (vof 0 hc))
  ((vof 0 hc) = (lof hc))
  ((vof 0 hc) = (((y \ y + 1) * (x \ x + 2)) 3))))

; --- the skeleton: an object a location, the state one map; hmov carries, retracts,
; --- is invisible off its endpoints, and composes by homcomp ---
(test
 (defn hst UU (pi l nat nat))
 (defn hupd (pi l nat v nat s hst hst)
   (lam l v s q (bool_rect (lam x nat) v (s q) (nateqb q l))))
 (defn hmov (pi a nat b nat s hst hst)
   (lam a b s (hupd b (s a) s)))
 (defq hmov-carry (pi s hst (paths nat (hmov 1 0 s 0) (s 1)))
   (lam s (idpath (s 1))))
 (defq hmov-frame (pi s hst (paths nat (hmov 1 0 s 2) (s 2)))
   (lam s (idpath (s 2))))
 (defq hmov-retract (pi s hst (paths nat (hmov 0 1 (hmov 1 0 s) 1) (s 1)))
   (lam s (idpath (s 1))))
 (defq hmov-homcomp
   (pi s hst (paths nat (homcomp hst hst hst (hmov 1 2) (hmov 0 1) s 2) (s 0)))
   (lam s (idpath (s 0)))))

; --- dest.l's IR denoted: state (regs, frame, stack, sp), sp concrete so a balanced
; --- shuttle computes under a neutral state. operands: reg r = 2r, imm k = 2k+1 ---
(test
 (defn isodd (pi n nat bool)
   (lam n (nat_rect (lam q bool) false (lam k r (negb r)) n)))
 (defn half (pi n nat nat)
   (lam n (nat_rect (lam q nat) 0
             (lam k r (bool_rect (lam x nat) (succ r) r (isodd k))) n)))
 (defn mst UU (total2 r hst (total2 f hst (total2 k hst nat))))
 (defn mmk (pi r hst f hst k hst p nat mst)
   (lam r f k p (tpair r (tpair f (tpair k p)))))
 (defn mrg (pi s mst hst) (lam s (pr1 s)))
 (defn mf (pi s mst hst) (lam s (pr1 (pr2 s))))
 (defn mk (pi s mst hst) (lam s (pr1 (pr2 (pr2 s)))))
 (defn msp (pi s mst nat) (lam s (pr2 (pr2 (pr2 s)))))
 (defn rdop (pi x nat s mst nat)
   (lam x s (bool_rect (lam q nat) (half x) (mrg s (half x)) (isodd x))))
 (defn msetr (pi d nat v nat s mst mst)
   (lam d v s (mmk (hupd d v (mrg s)) (mf s) (mk s) (msp s))))
 (defn msetf (pi d nat v nat s mst mst)
   (lam d v s (mmk (mrg s) (hupd d v (mf s)) (mk s) (msp s))))
 (defn mpush (pi v nat s mst mst)
   (lam v s (mmk (mrg s) (mf s) (hupd (msp s) v (mk s)) (succ (msp s)))))
 (defn mpop (pi d nat s mst mst)
   (lam d s (mmk (hupd d (mk s (npred (msp s))) (mrg s)) (mf s) (mk s) (npred (msp s))))))

; --- opcodes: li 0, mov 1, ld 2, st 3, si 4, add 5, push 14, pop 15; the control
; --- ops denote the identity and are read only syntactically (opsof) ---
(test
 (defn istep (pi o nat d nat a nat b nat s mst mst)
   (lam o d a b s
      (bool_rect (lam q mst) (msetr (half d) (rdop a s) s)
        (bool_rect (lam q mst) (msetr (half d) (mf s (half b)) s)
          (bool_rect (lam q mst) (msetf (half a) (rdop b s) s)
            (bool_rect (lam q mst) (msetr (half d) (add (rdop a s) (rdop b s)) s)
              (bool_rect (lam q mst) (mpush (rdop d s) s)
                (bool_rect (lam q mst) (mpop (half d) s) s
                  (nateqb o 15))
                (nateqb o 14))
              (nateqb o 5))
            (orb (nateqb o 3) (nateqb o 4)))
          (nateqb o 2))
        (orb (nateqb o 0) (nateqb o 1)))))
 ; one recursive call per level: a bool_rect arm holding IH multiplies under NbE
 (defn dgo
   (pi q nat v (nvec q) m nat o nat p nat a nat s mst mst)
   (lam q (nat_rect (lam n (pi v (nvec n) m nat o nat p nat a nat s mst mst))
             (lam v m o p a s s)
             (lam k IH v m o p a s
               (let h (pr1 v)
                 (IH (pr2 v)
                   (bool_rect (lam x nat) 0 (succ m) (nateqb m 3))
                   (bool_rect (lam x nat) h o (nateqb m 0))
                   (bool_rect (lam x nat) h p (nateqb m 1))
                   (bool_rect (lam x nat) h a (nateqb m 2))
                   (bool_rect (lam x mst) (istep o p a h s) s (nateqb m 3)))))
             q)))
 (defn drun (pi l nlist s mst mst)
   (lam l s (dgo (pr1 l) (pr2 l) 0 0 0 0 s)))
 (defn opsgo (pi q nat v (nvec q) m nat nlist)
   (lam q (nat_rect (lam n (pi v (nvec n) m nat nlist))
             (lam v m nnil)
             (lam k IH v m
               (let r (IH (pr2 v) (bool_rect (lam y nat) 0 (succ m) (nateqb m 3)))
                 (bool_rect (lam x nlist) (ncons (pr1 v) r) r (nateqb m 0))))
             q)))
 (defn opsof (pi l nlist nlist) (lam l (opsgo (pr1 l) (pr2 l) 0))))

; --- pinned: li lands its immediate; the push/pop shuttle carries r0 to r1 forall states
(test
 (defq drun-li
   (pi R hst F hst K hst
      (paths nat (mrg (drun (ncons 0 (ncons 0 (ncons 15 (ncons 0 nnil)))) (mmk R F K 0)) 0) 7))
   (lam R F K (idpath 7)))
 (defq drun-shuttle
   (pi R hst F hst K hst
      (paths nat
        (mrg (drun (ncons 14 (ncons 0 (ncons 0 (ncons 0
                  (ncons 15 (ncons 2 (ncons 0 (ncons 0 nnil))))))))
                  (mmk R F K 0)) 1)
        (R 0)))
   (lam R F K (idpath (R 0)))))

; --- the stack machine: state (stack, sp, locals, seats, trace, trace count), sp and
; --- count concrete. ops (op x): pushk 0, pusha 1, pushl 2, pushs 3, setl 4, sets 5,
; --- add 6, emit 7 -- emit appends tos to the trace, its effect seen only there ---
(test
 (defn sst UU (total2 s hst (total2 p nat (total2 l hst (total2 e hst (total2 t hst nat))))))
 (defn smk (pi s hst p nat l hst e hst t hst n nat sst)
   (lam s p l e t n (tpair s (tpair p (tpair l (tpair e (tpair t n)))))))
 (defn stos (pi st sst nat) (lam st ((pr1 st) (npred (pr1 (pr2 st))))))
 (defn strn (pi st sst nat) (lam st (pr2 (pr2 (pr2 (pr2 (pr2 st)))))))
 (defn strat (pi k nat st sst nat)
   (lam k st ((pr1 (pr2 (pr2 (pr2 (pr2 st))))) k)))
 (defn sstep (pi o nat x nat A hst st sst sst)
   (lam o x A st
      (let SM (pr1 st) (let PM (pr1 (pr2 st)) (let LM (pr1 (pr2 (pr2 st)))
      (let EM (pr1 (pr2 (pr2 (pr2 st)))) (let TM (pr1 (pr2 (pr2 (pr2 (pr2 st)))))
      (let NM (pr2 (pr2 (pr2 (pr2 (pr2 st)))))
      (bool_rect (lam q sst) (smk (hupd PM x SM) (succ PM) LM EM TM NM)
        (bool_rect (lam q sst) (smk (hupd PM (A x) SM) (succ PM) LM EM TM NM)
          (bool_rect (lam q sst) (smk (hupd PM (LM x) SM) (succ PM) LM EM TM NM)
            (bool_rect (lam q sst) (smk (hupd PM (EM x) SM) (succ PM) LM EM TM NM)
              (bool_rect (lam q sst) (smk SM (npred PM) (hupd x (SM (npred PM)) LM) EM TM NM)
                (bool_rect (lam q sst) (smk SM (npred PM) LM (hupd x (SM (npred PM)) EM) TM NM)
                  (bool_rect (lam q sst)
                    (smk (hupd (npred (npred PM))
                               (add (SM (npred (npred PM))) (SM (npred PM))) SM)
                         (npred PM) LM EM TM NM)
                    (bool_rect (lam q sst) (smk SM PM LM EM (hupd NM (SM (npred PM)) TM) (succ NM)) st
                      (nateqb o 7))
                    (nateqb o 6))
                  (nateqb o 5))
                (nateqb o 4))
              (nateqb o 3))
            (nateqb o 2))
          (nateqb o 1))
        (nateqb o 0))))))))))
 ; one recursive call per level, as dgo
 (defn sgo (pi q nat v (nvec q) m nat o nat A hst st sst sst)
   (lam q (nat_rect (lam n (pi v (nvec n) m nat o nat A hst st sst sst))
             (lam v m o A st st)
             (lam k IH v m o A st
               (let h (pr1 v)
                 (IH (pr2 v)
                   (bool_rect (lam x nat) 1 0 (nateqb m 0))
                   (bool_rect (lam x nat) h o (nateqb m 0))
                   A
                   (bool_rect (lam x sst) st (sstep o h A st) (nateqb m 0)))))
             q)))
 (defn srun (pi l nlist A hst st sst sst)
   (lam l A st (sgo (pr1 l) (pr2 l) 0 0 A st))))

; --- pinned: a push lands at tos; emit writes the trace without moving the stack
(test
 (defq srun-push
   (pi A hst S hst L hst E hst T hst
      (paths nat (stos (srun (ncons 0 (ncons 7 nnil)) A (smk S 0 L E T 0))) 7))
   (lam A S L E T (idpath 7)))
 (defq srun-emit
   (pi A hst S hst L hst E hst T hst
      (paths nat (strn (srun (ncons 0 (ncons 5 (ncons 7 (ncons 0 nnil)))) A (smk S 0 L E T 0))) 1))
   (lam A S L E T (idpath 1))))
