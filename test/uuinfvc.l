; test/uuinfvc.l -- laid by src/love/compress/inf.l, `make mx`. edit that file.
(test
 (defcx inf-walk (Cn (pi i nat nat)) (Sy (pi i nat nat)) (bit (pi i nat nat)) (n nat) (h nat) (w nat) (b1 (pi i nat (inf-le (bit i) 1))) (hc (pi i nat (inf-lt (Cn i) (inf-pow h)))) (hs (pi i nat (inf-lt (Sy i) (inf-pow h)))) (gh (inf-le h 16)) (gw (inf-le 31 w)) (gn (inf-lt n (inf-pow w))) (gs (inf-le (inf-sum Cn 15 1) n)) )
; w1e-1
 (defq inf-vc-walk-w1e-1 (under inf-walk (inf-le 1 1))
   (given inf-walk (idpath false)))
; w1e-2
 (defq inf-vc-walk-w1e-2 (under inf-walk (inf-le 0 0))
   (given inf-walk (idpath false)))
; w1e-3
 (defq inf-vc-walk-w1e-3 (under inf-walk (inf-le (add 0 2) (inf-pow 1)))
   (given inf-walk (idpath false)))
; w1e-4
 (defq inf-vc-walk-w1e-4 (under inf-walk (paths nat (inf-mod 2 0) 0))
   (given inf-walk (idpath 0)))
; w1e-5
 (defq inf-vc-walk-w1e-5 (under inf-walk (inf-le (add 0 (inf-sum Cn (natminus 16 1) 1)) n))
   (given inf-walk gs))
 (defcx inf-walk-w1 inf-walk (l nat) (index nat) (first nat) (code nat) (i1 (inf-le 1 l)) (i2 (inf-le first code)) (i3 (inf-le (add code 2) (inf-pow l))) (i4 (paths nat (inf-mod 2 code) 0)) (i5 (inf-le (add index (inf-sum Cn (natminus 16 l) l)) n)) )
; s1-1
 (defq inf-vc-walk-s1-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-le 1 l)))
   (given inf-walk-w1 (lam w1 i1)))
; s1-2
 (defq inf-vc-walk-s1-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (natminus l 1) 64)))
   (given inf-walk-w1 (lam w1 (inf-lelt (natminus l 1) l 64 (inf-suble l 1) (inf-lttrans l 16 64 w1 (idpath false))))))
; s1-3
 (defq inf-vc-walk-s1-3 (under inf-walk-w1 (pi w1 (inf-lt l 16) (paths nat (inf-mod 2 code) 0)))
   (given inf-walk-w1 (lam w1 i4)))
; s1-4
 (defq inf-vc-walk-s1-4 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (bit (natminus l 1)) 2)))
   (given inf-walk-w1 (lam w1 (inf-lelts ((bit (natminus l 1))) 1 (b1 (natminus l 1))))))
; s1-5
 (defq inf-vc-walk-s1-5 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (add code (bit (natminus l 1))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 ((inf-powfit ((add code ((bit (natminus l 1))))) l w ((inf-wor code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)) ((inf-lew l w w1 gw)))))))
; s2-1
 (defq inf-vc-walk-s2-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt l 16)))
   (given inf-walk-w1 (lam w1 w1)))
; s2-2
 (defq inf-vc-walk-s2-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (Cn l) (inf-pow w))))
   (given inf-walk-w1 (lam w1 ((inf-powfit (Cn l) h w (hc l) ((istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw))))))))
; s3-1
 (defq inf-vc-walk-s3-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (add code (bit (natminus l 1))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 ((inf-powfit ((add code ((bit (natminus l 1))))) l w ((inf-wor code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)) ((inf-lew l w w1 gw)))))))
; s3-2
 (defq inf-vc-walk-s3-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (Cn l) (inf-pow w))))
   (given inf-walk-w1 (lam w1 ((inf-powfit (Cn l) h w (hc l) ((istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw))))))))
; s4-1
 (defq inf-vc-walk-s4-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-le first (add code (bit (natminus l 1))))))
   (given inf-walk-w1 (lam w1 g3 ((istransnatleh first code ((add code ((bit (natminus l 1))))) i2 (inf-leaddr code ((bit (natminus l 1)))))))))
; s4-2
 (defq inf-vc-walk-s4-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (add index (natminus (add code (bit (natminus l 1))) first)) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lttrans ((add index (natminus ((add code ((bit (natminus l 1))))) first))) n (inf-pow w) ((inf-lttrans ((add index (natminus ((add code ((bit (natminus l 1))))) first))) (add index (Cn l)) n (inf-ltaddl index (natminus ((add code ((bit (natminus l 1))))) first) (Cn l) (inf-subshort first ((add code ((bit (natminus l 1))))) (Cn l) ((istransnatleh first code ((add code ((bit (natminus l 1))))) i2 (inf-leaddr code ((bit (natminus l 1)))))) g3)) ((inf-sumhead Cn 16 l index n w1 i5)))) (inf-ltle n (inf-pow w) gn)))))
; s4-3
 (defq inf-vc-walk-s4-3 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (add index (natminus (add code (bit (natminus l 1))) first)) n)))
   (given inf-walk-w1 (lam w1 g3 ((inf-lttrans ((add index (natminus ((add code ((bit (natminus l 1))))) first))) (add index (Cn l)) n (inf-ltaddl index (natminus ((add code ((bit (natminus l 1))))) first) (Cn l) (inf-subshort first ((add code ((bit (natminus l 1))))) (Cn l) ((istransnatleh first code ((add code ((bit (natminus l 1))))) i2 (inf-leaddr code ((bit (natminus l 1)))))) g3)) ((inf-sumhead Cn 16 l index n w1 i5)))))))
; s4-4
 (defq inf-vc-walk-s4-4 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (Sy (add index (natminus (add code (bit (natminus l 1))) first))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-powfit ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))) h w (hs ((add index (natminus ((add code ((bit (natminus l 1))))) first)))) ((istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw)))))))
; s4-5
 (defq inf-vc-walk-s4-5 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (inf-by16 (Sy (add index (natminus (add code (bit (natminus l 1))) first)))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt (inf-by16 ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))) (add (inf-by16 ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))) l) (inf-pow w) (inf-leaddr (inf-by16 ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))) l) ((inf-by16or ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))) l h w (hs ((add index (natminus ((add code ((bit (natminus l 1))))) first)))) w1 gh gw))))))
; s4-6
 (defq inf-vc-walk-s4-6 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt l (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lttrans l 16 (inf-pow w) w1 (inf-powle 4 w (istransnatleh 4 31 w (idpath false) gw))))))
; s4-7
 (defq inf-vc-walk-s4-7 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (paths nat (inf-mod 16 (inf-by16 (Sy (add index (natminus (add code (bit (natminus l 1))) first))))) 0)))
   (given inf-walk-w1 (lam w1 g3 (inf-by16low ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))))))
; s4-8
 (defq inf-vc-walk-s4-8 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt l 16)))
   (given inf-walk-w1 (lam w1 g3 w1)))
; s4-9
 (defq inf-vc-walk-s4-9 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (add (inf-by16 (Sy (add index (natminus (add code (bit (natminus l 1))) first)))) l) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 ((inf-by16or ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))) l h w (hs ((add index (natminus ((add code ((bit (natminus l 1))))) first)))) w1 gh gw)))))
; s5-1
 (defq inf-vc-walk-s5-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (add index (Cn l)) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt (add index (Cn l)) n (inf-pow w) ((inf-sumhead Cn 16 l index n w1 i5)) gn))))
; s6-1
 (defq inf-vc-walk-s6-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (add first (Cn l)) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt ((add first (Cn l))) ((add code ((bit (natminus l 1))))) (inf-pow w) g3 ((inf-powfit ((add code ((bit (natminus l 1))))) l w ((inf-wor code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)) ((inf-lew l w w1 gw))))))))
; s6-2
 (defq inf-vc-walk-s6-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (add (add first (Cn l)) (add first (Cn l))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt (add ((add first (Cn l))) ((add first (Cn l)))) ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (inf-pow w) (inf-dbl ((add first (Cn l))) ((add code ((bit (natminus l 1))))) g3) ((inf-powfit ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (succ l) w (inf-lttrans ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (add ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) 2) (inf-pow (succ l)) (inf-lt2 ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1)))))))) ((inf-wsh code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3))) (istransnatleh (succ l) 16 w (inf-ltsu l 16 w1) (istransnatleh 16 31 w (idpath false) gw))))))))
; s7-1
 (defq inf-vc-walk-s7-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1)))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 ((inf-powfit ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (succ l) w (inf-lttrans ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (add ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) 2) (inf-pow (succ l)) (inf-lt2 ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1)))))))) ((inf-wsh code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3))) (istransnatleh (succ l) 16 w (inf-ltsu l 16 w1) (istransnatleh 16 31 w (idpath false) gw)))))))
; w1b-1
 (defq inf-vc-walk-w1b-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (succ l) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt (succ l) 16 (inf-pow w) (inf-ltsu l 16 w1) (inf-lttrans 16 32 (inf-pow w) (idpath true) (inf-powle 5 w (istransnatleh 5 31 w (idpath false) gw)))))))
; w1b-2
 (defq inf-vc-walk-w1b-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-le 1 (succ l))))
   (given inf-walk-w1 (lam w1 g3 (idpath false))))
; w1b-3
 (defq inf-vc-walk-w1b-3 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-le (add (add first (Cn l)) (add first (Cn l))) (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1)))))))
   (given inf-walk-w1 (lam w1 g3 (inf-dbl ((add first (Cn l))) ((add code ((bit (natminus l 1))))) g3))))
; w1b-4
 (defq inf-vc-walk-w1b-4 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-le (add (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1)))) 2) (inf-pow (succ l)))))
   (given inf-walk-w1 (lam w1 g3 ((inf-wsh code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)))))
; w1b-5
 (defq inf-vc-walk-w1b-5 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (paths nat (inf-mod 2 (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1))))) 0)))
   (given inf-walk-w1 (lam w1 g3 (inf-moddbl ((add code ((bit (natminus l 1)))))))))
; w1b-6
 (defq inf-vc-walk-w1b-6 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-le (add (add index (Cn l)) (inf-sum Cn (natminus 16 (succ l)) (succ l))) n)))
   (given inf-walk-w1 (lam w1 g3 (inf-sumnext Cn 16 l index n w1 i5))))
; w1b-7
 (defq inf-vc-walk-w1b-7 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (natminus 16 (succ l)) (natminus 16 l))))
   (given inf-walk-w1 (lam w1 g3 (inf-subfall 16 l w1))))
 (defcx inf-build (Ln (pi k nat nat)) (nsym nat) (root nat) (q nat) (u nat) (w nat) (hl (pi k nat g (inf-lt k nsym) (inf-le (Ln k) 15))) (gn (inf-lt nsym q)) (gu (inf-le (inf-by16 q) u)) (gv (inf-le u (inf-pow w))) (gr (inf-le root 15)) (gw (inf-le 32 w)) (gc (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) )
; d0-1
 (defq inf-vc-build-d0-1 (under inf-build (inf-lt root 32))
   (given inf-build (inf-lelt root 15 32 gr (idpath true))))
; d0-2
 (defq inf-vc-build-d0-2 (under inf-build (inf-lt (inf-pow root) (inf-pow w)))
   (given inf-build (inf-powlt root w ((inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) ((istransnatleh 16 32 w (idpath false) gw))))))))
; w1e-1
 (defq inf-vc-build-w1e-1 (under inf-build (inf-le 0 nsym))
   (given inf-build (idpath false)))
; w1e-2
 (defq inf-vc-build-w1e-2 (under inf-build (pi k nat (paths nat (inf-zero k) (inf-count Ln k 0))))
   (given inf-build (lam k (idpath 0))))
 (defcx inf-build-w1 inf-build (i nat) (Cn (pi j nat nat)) (a1 (inf-le i nsym)) (a2 (pi k nat (paths nat (Cn k) (inf-count Ln k i)))) )
; s1-1
 (defq inf-vc-build-s1-1 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt i nsym)))
   (given inf-build-w1 (lam w1 w1)))
; s1-2
 (defq inf-vc-build-s1-2 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (Ln i) 16)))
   (given inf-build-w1 (lam w1 (inf-lelts ((Ln i)) 15 (hl i w1)))))
; s1-3
 (defq inf-vc-build-s1-3 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (add (Cn (Ln i)) 1) (inf-pow w))))
   (given inf-build-w1 (lam w1 (inf-lelt (add ((Cn ((Ln i)))) 1) nsym (inf-pow w) ((inf-lt1 ((Cn ((Ln i)))) nsym (inf-lelt ((Cn ((Ln i)))) i nsym ((inf-letr (inf-count Ln ((Ln i)) i) ((Cn ((Ln i)))) i (pathsinv0 nat ((Cn ((Ln i)))) (inf-count Ln ((Ln i)) i) (a2 ((Ln i)))) (inf-cntle Ln ((Ln i)) i))) w1))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; s1-4
 (defq inf-vc-build-s1-4 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (add (Cn (Ln i)) 1) u)))
   (given inf-build-w1 (lam w1 (inf-lelt (add ((Cn ((Ln i)))) 1) nsym u ((inf-lt1 ((Cn ((Ln i)))) nsym (inf-lelt ((Cn ((Ln i)))) i nsym ((inf-letr (inf-count Ln ((Ln i)) i) ((Cn ((Ln i)))) i (pathsinv0 nat ((Cn ((Ln i)))) (inf-count Ln ((Ln i)) i) (a2 ((Ln i)))) (inf-cntle Ln ((Ln i)) i))) w1))) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))))))
; w1b-1
 (defq inf-vc-build-w1b-1 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1 (lam w1 (inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w1) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w1b-2
 (defq inf-vc-build-w1b-2 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-le (succ i) nsym)))
   (given inf-build-w1 (lam w1 (inf-ltsu i nsym w1))))
; w1b-3
 (defq inf-vc-build-w1b-3 (under inf-build-w1 (pi w1 (inf-lt i nsym) (pi k nat (paths nat ((inf-upd Cn (Ln i) (add (Cn (Ln i)) 1)) k) (inf-count Ln k (succ i))))))
   (given inf-build-w1 (lam w1 (lam k (inf-cntstep Ln Cn i a2 k)))))
; w1b-4
 (defq inf-vc-build-w1b-4 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (natminus nsym (succ i)) (natminus nsym i))))
   (given inf-build-w1 (lam w1 (inf-subfall nsym i w1))))
; c5-1
 (defq inf-vc-build-c5-1 (under inf-build-w1 (pi w1 (inf-le nsym i) (inf-lt 0 16)))
   (given inf-build-w1 (lam w1 (idpath true))))
; c5-2
 (defq inf-vc-build-c5-2 (under inf-build-w1 (pi w1 (inf-le nsym i) (inf-lt 0 u)))
   (given inf-build-w1 (lam w1 (inf-lelt 0 nsym u (idpath false) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))))))
; ka-1
 (defq inf-vc-build-ka-1 (under inf-build-w1 (pi w1 (inf-le nsym i) (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym)))))
   (given inf-build-w1 (lam w1 (lam k g (inf-hk Cn Ln i nsym a1 w1 a2 k g)))))
; kb-1
 (defq inf-vc-build-kb-1 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1)))))
   (given inf-build-w1 (lam w1 hk (lam o (inf-sumcong ((inf-upd Cn 0 0)) (lam v (inf-count Ln v nsym)) hk o 1 (idpath false))))))
; kc-1
 (defq inf-vc-build-kc-1 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym))))
   (given inf-build-w1 (lam w1 hk hs (lam o (inf-letr ((inf-sum (lam v (inf-count Ln v nsym)) o 1)) ((inf-sum ((inf-upd Cn 0 0)) o 1)) nsym (pathsinv0 nat ((inf-sum ((inf-upd Cn 0 0)) o 1)) ((inf-sum (lam v (inf-count Ln v nsym)) o 1)) (hs o)) (inf-sumcount Ln o 1 nsym))))))
; w2e-1
 (defq inf-vc-build-w2e-1 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym)) (inf-le 1 1)))
   (given inf-build-w1 (lam w1 hk hs hb (idpath false))))
; w2e-2
 (defq inf-vc-build-w2e-2 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym)) (inf-le 1 15)))
   (given inf-build-w1 (lam w1 hk hs hb (idpath false))))
; w2e-3
 (defq inf-vc-build-w2e-3 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym)) (pi o nat g (inf-lt o 1) (paths nat (inf-zero (succ o)) (inf-sum (inf-upd Cn 0 0) o 1)))))
   (given inf-build-w1 (lam w1 hk hs hb (lam o g (inf-o1 ((inf-upd Cn 0 0)) o g)))))
 (defcx inf-build-w1-w2 inf-build-w1 (w1 (inf-le nsym i)) (hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym)))) (hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1)))) (hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym))) (l nat) (Of (pi j nat nat)) (b1 (inf-le 1 l)) (b2 (inf-le l 15)) (b3 (pi o nat g (inf-lt o l) (paths nat (Of (succ o)) (inf-sum (inf-upd Cn 0 0) o 1)))) )
; s2-1
 (defq inf-vc-build-s2-1 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (add l 1) (inf-pow w))))
   (given inf-build-w1-w2 (lam w2 (inf-small (add l 1) w (inf-letrans (add l 1) 15 w (inf-lt1 l 15 w2) ((istransnatleh 15 32 w (idpath false) gw)))))))
; s2-2
 (defq inf-vc-build-s2-2 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (add l 1) 16)))
   (given inf-build-w1-w2 (lam w2 (inf-lelts (add l 1) 15 (inf-lt1 l 15 w2)))))
; s2-3
 (defq inf-vc-build-s2-3 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt l 16)))
   (given inf-build-w1-w2 (lam w2 (inf-lttrans l 15 16 w2 (idpath false)))))
; s2-4
 (defq inf-vc-build-s2-4 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (add (Of l) ((inf-upd Cn 0 0) l)) (inf-pow w))))
   (given inf-build-w1-w2 (lam w2 (inf-lelt (add (Of l) ((((inf-upd Cn 0 0)) l))) nsym (inf-pow w) (inf-letr (inf-sum ((inf-upd Cn 0 0)) l 1) (add (Of l) ((((inf-upd Cn 0 0)) l))) nsym (pathsinv0 nat (add (Of l) ((((inf-upd Cn 0 0)) l))) (inf-sum ((inf-upd Cn 0 0)) l 1) (inf-sumlast ((inf-upd Cn 0 0)) Of l b1 b3)) (hb l)) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w2b-1
 (defq inf-vc-build-w2b-1 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (succ l) (inf-pow w))))
   (given inf-build-w1-w2 (lam w2 (inf-small (succ l) w (inf-letrans (succ l) 15 w (inf-ltsu l 15 w2) ((istransnatleh 15 32 w (idpath false) gw)))))))
; w2b-2
 (defq inf-vc-build-w2b-2 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-le 1 (succ l))))
   (given inf-build-w1-w2 (lam w2 (idpath false))))
; w2b-3
 (defq inf-vc-build-w2b-3 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-le (succ l) 15)))
   (given inf-build-w1-w2 (lam w2 (inf-ltsu l 15 w2))))
; w2b-4
 (defq inf-vc-build-w2b-4 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (pi o nat g (inf-lt o (succ l)) (paths nat ((inf-upd Of (add l 1) (add (Of l) ((inf-upd Cn 0 0) l))) (succ o)) (inf-sum (inf-upd Cn 0 0) o 1)))))
   (given inf-build-w1-w2 (lam w2 (lam o g (inf-ofstep ((inf-upd Cn 0 0)) Of l b1 b3 o g)))))
; w2b-5
 (defq inf-vc-build-w2b-5 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (natminus 15 (succ l)) (natminus 15 l))))
   (given inf-build-w1-w2 (lam w2 (inf-subfall 15 l w2))))
; w3e-1
 (defq inf-vc-build-w3e-1 (under inf-build-w1-w2 (pi w2 (inf-le 15 l) (inf-le 0 nsym)))
   (given inf-build-w1-w2 (lam w2 (idpath false))))
; w3e-2
 (defq inf-vc-build-w3e-2 (under inf-build-w1-w2 (pi w2 (inf-le 15 l) (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) 0))))))
   (given inf-build-w1-w2 (lam w2 (lam o g (pathscomp0 nat (Of (succ o)) ((inf-sum ((inf-upd Cn 0 0)) o 1)) (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) 0) (b3 o (inf-lttrans o 15 l g w2)) (pathsinv0 nat (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) 0) ((inf-sum ((inf-upd Cn 0 0)) o 1)) (natplusr0 ((inf-sum ((inf-upd Cn 0 0)) o 1)))))))))
; w3e-3
 (defq inf-vc-build-w3e-3 (under inf-build-w1-w2 (pi w2 (inf-le 15 l) (pi k nat (inf-lt (inf-zero k) q))))
   (given inf-build-w1-w2 (lam w2 (lam k (inf-lelt 0 nsym q (idpath false) gn)))))
 (defcx inf-build-w1-w2-w3 inf-build-w1-w2 (w2 (inf-le 15 l)) (i nat) (Of (pi j nat nat)) (Sy (pi j nat nat)) (e1 (inf-le i nsym)) (e2 (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) i))))) (e3 (pi k nat (inf-lt (Sy k) q))) )
; s3-1
 (defq inf-vc-build-s3-1 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) (inf-lt i nsym)))
   (given inf-build-w1-w2-w3 (lam w3 w3)))
; s4-1
 (defq inf-vc-build-s4-1 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt i nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 w3)))
; s4-2
 (defq inf-vc-build-s4-2 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (Ln i) 16)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelts ((Ln i)) 15 (hl i w3)))))
; s4-3
 (defq inf-vc-build-s4-3 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (Of (Ln i)) nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 ((inf-ofs Ln ((inf-upd Cn 0 0)) Of nsym i w3 e2 hs ((Ln i)) (idpath ((Ln i))) g3 (hl i w3))))))
; s4-4
 (defq inf-vc-build-s4-4 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt i u)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lttrans i nsym u w3 (inf-ltle nsym u ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu))))))))
; s5-1
 (defq inf-vc-build-s5-1 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt i nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 w3)))
; s5-2
 (defq inf-vc-build-s5-2 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (Ln i) 16)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelts ((Ln i)) 15 (hl i w3)))))
; s5-3
 (defq inf-vc-build-s5-3 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (add (Of (Ln i)) 1) (inf-pow w))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelt (add (Of ((Ln i))) 1) nsym (inf-pow w) (inf-lt1 (Of ((Ln i))) nsym ((inf-ofs Ln ((inf-upd Cn 0 0)) Of nsym i w3 e2 hs ((Ln i)) (idpath ((Ln i))) g3 (hl i w3)))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w3b-1
 (defq inf-vc-build-w3b-1 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w3) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w3b-2
 (defq inf-vc-build-w3b-2 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-le (succ i) nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-ltsu i nsym w3))))
; w3b-3
 (defq inf-vc-build-w3b-3 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (pi o nat g (inf-lt o 15) (paths nat ((inf-upd Of (Ln i) (add (Of (Ln i)) 1)) (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) (succ i)))))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (lam o g (inf-fillstep Of Ln i ((inf-sum ((inf-upd Cn 0 0)) o 1)) o (e2 o g))))))
; w3b-4
 (defq inf-vc-build-w3b-4 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (pi k nat (inf-lt ((inf-upd Sy (Of (Ln i)) i) k) q))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (lam k (inf-uplt Sy (Of ((Ln i))) i q e3 (inf-lttrans i nsym q w3 (inf-ltle nsym q gn)) k)))))
; w3b-5
 (defq inf-vc-build-w3b-5 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (natminus nsym (succ i)) (natminus nsym i))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-subfall nsym i w3))))
; w3b-6
 (defq inf-vc-build-w3b-6 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w3) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w3b-7
 (defq inf-vc-build-w3b-7 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (inf-le (succ i) nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-ltsu i nsym w3))))
; w3b-8
 (defq inf-vc-build-w3b-8 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) (succ i)))))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (lam o g (pathscomp0 nat (Of (succ o)) (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) ((inf-count Ln (succ o) i))) (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) ((inf-count Ln (succ o) (succ i)))) (e2 o g) (maponpaths nat nat (lam z (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) z)) ((inf-count Ln (succ o) i)) ((inf-count Ln (succ o) (succ i))) (pathsinv0 nat ((inf-count Ln (succ o) (succ i))) ((inf-count Ln (succ o) i)) (inf-fillzero Ln i o g3))))))))
; w3b-9
 (defq inf-vc-build-w3b-9 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (pi k nat (inf-lt (Sy k) q))))
   (given inf-build-w1-w2-w3 (lam w3 g3 e3)))
; w3b-10
 (defq inf-vc-build-w3b-10 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (inf-lt (natminus nsym (succ i)) (natminus nsym i))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-subfall nsym i w3))))
; w4e-1
 (defq inf-vc-build-w4e-1 (under inf-build-w1-w2-w3 (pi w3 (inf-le nsym i) (inf-le 1 1)))
   (given inf-build-w1-w2-w3 (lam w3 (idpath false))))
; w4e-2
 (defq inf-vc-build-w4e-2 (under inf-build-w1-w2-w3 (pi w3 (inf-le nsym i) (inf-le (add 0 (inf-sum (inf-upd Cn 0 0) (natminus 16 1) 1)) nsym)))
   (given inf-build-w1-w2-w3 (lam w3 (hb 15))))
; w4e-3
 (defq inf-vc-build-w4e-3 (under inf-build-w1-w2-w3 (pi w3 (inf-le nsym i) (inf-le (add 0 0) (inf-dk 0 1))))
   (given inf-build-w1-w2-w3 (lam w3 (idpath false))))
 (defcx inf-build-w1-w2-w3-w4 inf-build-w1-w2-w3 (w3 (inf-le nsym i)) (l nat) (i nat) (Tb (pi j nat nat)) (idx nat) (code nat) (h1 (inf-le 1 l)) (h2 (inf-le (add idx (inf-sum (inf-upd Cn 0 0) (natminus 16 l) l)) nsym)) (h3 (inf-le (add code code) (inf-dk idx l))) )
; w5e-1
 (defq inf-vc-build-w5e-1 (under inf-build-w1-w2-w3-w4 (pi w4 (inf-lt l 16) (inf-le 0 ((inf-upd Cn 0 0) l))))
   (given inf-build-w1-w2-w3-w4 (lam w4 (idpath false))))
; w5e-2
 (defq inf-vc-build-w5e-2 (under inf-build-w1-w2-w3-w4 (pi w4 (inf-lt l 16) (inf-le (add (add idx (natminus ((inf-upd Cn 0 0) l) 0)) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)))
   (given inf-build-w1-w2-w3-w4 (lam w4 (inf-idxenter ((inf-upd Cn 0 0)) l idx nsym w4 h2))))
; w5e-3
 (defq inf-vc-build-w5e-3 (under inf-build-w1-w2-w3-w4 (pi w4 (inf-lt l 16) (inf-le (add code code) (inf-dk idx l))))
   (given inf-build-w1-w2-w3-w4 (lam w4 h3)))
 (defcx inf-build-w1-w2-w3-w4-w5 inf-build-w1-w2-w3-w4 (w4 (inf-lt l 16)) (i nat) (Tb (pi j nat nat)) (idx nat) (code nat) (j1 (inf-le i ((inf-upd Cn 0 0) l))) (j2 (inf-le (add (add idx (natminus ((inf-upd Cn 0 0) l) i)) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)) (j3 (inf-le (add code code) (inf-dk idx l))) )
; w5h-1
 (defq inf-vc-build-w5h-1 (under inf-build-w1-w2-w3-w4-w5 (inf-lt l 16))
   (given inf-build-w1-w2-w3-w4-w5 w4))
; d1-1
 (defq inf-vc-build-d1-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) (inf-lt idx nsym)))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2)))))
; d1-2
 (defq inf-vc-build-d1-2 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) (inf-lt (Sy idx) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-lttrans ((Sy idx)) q (inf-pow w) (e3 idx) ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))
; d1-3
 (defq inf-vc-build-d1-3 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) (inf-lt 0 (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-powpos w))))
; s6-1
 (defq inf-vc-build-s6-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) (inf-lt (add idx 1) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-lelt ((add idx 1)) nsym (inf-pow w) (inf-lt1 idx nsym ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w6e-1
 (defq inf-vc-build-w6e-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-le l root) (inf-le 0 l)))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 (idpath false))))
; w6e-2
 (defq inf-vc-build-w6e-2 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-le l root) (inf-lt 0 (inf-pow 0))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 (idpath true))))
 (defcx inf-build-w1-w2-w3-w4-w5-w6 inf-build-w1-w2-w3-w4-w5 (w5 (inf-lt i ((inf-upd Cn 0 0) l))) (g7 (inf-le l root)) (b nat) (rev nat) (m1 (inf-le b l)) (m2 (inf-lt rev (inf-pow b))) )
; s8-1
 (defq inf-vc-build-s8-1 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (add rev rev) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-powfit (add rev rev) (succ b) w (inf-dblfit rev (inf-pow b) m2) ((inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 ((inf-ltsu b l w6)) ((inf-ltsle l 15 w4))) ((istransnatleh 15 32 w (idpath false) gw))))))))
; s8-2
 (defq inf-vc-build-s8-2 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt b 32)))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-lttrans b l 32 w6 (inf-ltle l 32 (inf-lttrans l 16 32 w4 (idpath false)))))))
; s8-3
 (defq inf-vc-build-s8-3 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (paths nat (inf-mod 2 (add rev rev)) 0)))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-moddbl rev))))
; s8-4
 (defq inf-vc-build-s8-4 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (inf-sb code b) 2)))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 ((inf-modlt 1 (inf-shr code b))))))
; s8-5
 (defq inf-vc-build-s8-5 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (add (add rev rev) (inf-sb code b)) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-powfit (add (add rev rev) ((inf-sb code b))) (succ b) w ((inf-revstep rev (inf-pow b) ((inf-sb code b)) m2 ((inf-modlt 1 (inf-shr code b))))) ((inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 ((inf-ltsu b l w6)) ((inf-ltsle l 15 w4))) ((istransnatleh 15 32 w (idpath false) gw))))))))
; w6b-1
 (defq inf-vc-build-w6b-1 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (succ b) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-small (succ b) w ((inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 ((inf-ltsu b l w6)) ((inf-ltsle l 15 w4))) ((istransnatleh 15 32 w (idpath false) gw))))))))
; w6b-2
 (defq inf-vc-build-w6b-2 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-le (succ b) l)))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 ((inf-ltsu b l w6)))))
; w6b-3
 (defq inf-vc-build-w6b-3 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (add (add rev rev) (inf-sb code b)) (inf-pow (succ b)))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 ((inf-revstep rev (inf-pow b) ((inf-sb code b)) m2 ((inf-modlt 1 (inf-shr code b))))))))
; w6b-4
 (defq inf-vc-build-w6b-4 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (natminus l (succ b)) (natminus l b))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-subfall l b w6))))
 (defcx inf-build-w1-w2-w3-w4-w5-w6-w7 inf-build-w1-w2-w3-w4-w5-w6 (w6 (inf-le l b)) (j nat) (Tb (pi j nat nat)) )
; s9-1
 (defq inf-vc-build-s9-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) (inf-lt j (inf-pow root))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 w7)))
; s10-1
 (defq inf-vc-build-s10-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt j (inf-pow root))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 w7)))
; s10-2
 (defq inf-vc-build-s10-2 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (inf-by16 (Sy idx)) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-lelt (inf-by16 ((Sy idx))) ((add (inf-by16 ((Sy idx))) l)) (inf-pow w) (inf-leaddr (inf-by16 ((Sy idx))) l) ((inf-lttrans ((add (inf-by16 ((Sy idx))) l)) (inf-by16 q) (inf-pow w) ((inf-entry ((Sy idx)) l q (e3 idx) w4)) (inf-letrans (inf-by16 q) u (inf-pow w) gu gv)))))))
; s10-3
 (defq inf-vc-build-s10-3 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (paths nat (inf-mod 16 (inf-by16 (Sy idx))) 0)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-by16low ((Sy idx))))))
; s10-4
 (defq inf-vc-build-s10-4 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt l 16)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 w4)))
; s10-5
 (defq inf-vc-build-s10-5 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (add (inf-by16 (Sy idx)) l) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-lttrans ((add (inf-by16 ((Sy idx))) l)) (inf-by16 q) (inf-pow w) ((inf-entry ((Sy idx)) l q (e3 idx) w4)) (inf-letrans (inf-by16 q) u (inf-pow w) gu gv))))))
; s10-6
 (defq inf-vc-build-s10-6 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (add (inf-by16 (Sy idx)) l) u)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-lttrans ((add (inf-by16 ((Sy idx))) l)) (inf-by16 q) u ((inf-entry ((Sy idx)) l q (e3 idx) w4)) gu))))
; w7b-1
 (defq inf-vc-build-w7b-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt l 32)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-lttrans l 16 32 w4 (idpath false)))))
; w7b-2
 (defq inf-vc-build-w7b-2 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (inf-pow l) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-powlt l w ((inf-lttrans l 16 w w4 ((istransnatleh 16 32 w (idpath false) gw))))))))
; w7b-3
 (defq inf-vc-build-w7b-3 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (add j (inf-pow l)) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-powfit (add j (inf-pow l)) (succ root) w (inf-tabstep j l root w7 g7) (inf-ltsu root w ((inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) ((istransnatleh 16 32 w (idpath false) gw)))))))))))
; w7b-4
 (defq inf-vc-build-w7b-4 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (natminus (inf-pow root) (add j (inf-pow l))) (natminus (inf-pow root) j))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-subby j (inf-pow root) (inf-pow l) w7 (inf-powpos l))))))
; w7b-5
 (defq inf-vc-build-w7b-5 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (inf-lt 0 (Tb j)) (inf-lt l 32)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-lttrans l 16 32 w4 (idpath false)))))
; w7b-6
 (defq inf-vc-build-w7b-6 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (inf-lt 0 (Tb j)) (inf-lt (inf-pow l) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-powlt l w ((inf-lttrans l 16 w w4 ((istransnatleh 16 32 w (idpath false) gw))))))))
; w7b-7
 (defq inf-vc-build-w7b-7 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (inf-lt 0 (Tb j)) (inf-lt (add j (inf-pow l)) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-powfit (add j (inf-pow l)) (succ root) w (inf-tabstep j l root w7 g7) (inf-ltsu root w ((inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) ((istransnatleh 16 32 w (idpath false) gw)))))))))))
; w7b-8
 (defq inf-vc-build-w7b-8 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (inf-lt 0 (Tb j)) (inf-lt (natminus (inf-pow root) (add j (inf-pow l))) (natminus (inf-pow root) j))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-subby j (inf-pow root) (inf-pow l) w7 (inf-powpos l))))))
; s11-1
 (defq inf-vc-build-s11-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-lt (add code 1) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-lelt ((add code 1)) (inf-dk ((add idx 1)) l) (inf-pow w) (inf-letrans ((add code 1)) (add ((add code 1)) ((add code 1))) (inf-dk ((add idx 1)) l) (inf-leaddr ((add code 1)) ((add code 1))) ((inf-code2 code idx l h1 j3))) ((inf-lelt (inf-dk ((add idx 1)) l) (inf-dk q l) (inf-pow w) (inf-dkmono ((add idx 1)) q l (inf-letrans ((add idx 1)) nsym q (inf-lt1 idx nsym ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))) (inf-ltle nsym q gn))) (gc l ((inf-ltsle l 15 w4))))))))))
; w5b-1
 (defq inf-vc-build-w5b-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-lelt (succ i) nsym (inf-pow w) (inf-letrans (succ i) ((((inf-upd Cn 0 0)) l)) nsym (inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5) ((inf-letr (inf-count Ln l nsym) ((((inf-upd Cn 0 0)) l)) nsym (pathsinv0 nat ((((inf-upd Cn 0 0)) l)) (inf-count Ln l nsym) (hk l h1)) (inf-cntle Ln l nsym)))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))))))
; w5b-2
 (defq inf-vc-build-w5b-2 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-le (succ i) ((inf-upd Cn 0 0) l))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5)))))
; w5b-3
 (defq inf-vc-build-w5b-3 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-le (add (add (add idx 1) (natminus ((inf-upd Cn 0 0) l) (succ i))) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-idxstep idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2)))))
; w5b-4
 (defq inf-vc-build-w5b-4 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-le (add (add code 1) (add code 1)) (inf-dk (add idx 1) l))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-code2 code idx l h1 j3)))))
; w5b-5
 (defq inf-vc-build-w5b-5 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-lt (natminus ((inf-upd Cn 0 0) l) (succ i)) (natminus ((inf-upd Cn 0 0) l) i))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-subfall ((((inf-upd Cn 0 0)) l)) i w5)))))
; s11-2
 (defq inf-vc-build-s11-2 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-lt (add code 1) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-lelt ((add code 1)) (inf-dk ((add idx 1)) l) (inf-pow w) (inf-letrans ((add code 1)) (add ((add code 1)) ((add code 1))) (inf-dk ((add idx 1)) l) (inf-leaddr ((add code 1)) ((add code 1))) ((inf-code2 code idx l h1 j3))) ((inf-lelt (inf-dk ((add idx 1)) l) (inf-dk q l) (inf-pow w) (inf-dkmono ((add idx 1)) q l (inf-letrans ((add idx 1)) nsym q (inf-lt1 idx nsym ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))) (inf-ltle nsym q gn))) (gc l ((inf-ltsle l 15 w4))))))))))
; w5b-6
 (defq inf-vc-build-w5b-6 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-lelt (succ i) nsym (inf-pow w) (inf-letrans (succ i) ((((inf-upd Cn 0 0)) l)) nsym (inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5) ((inf-letr (inf-count Ln l nsym) ((((inf-upd Cn 0 0)) l)) nsym (pathsinv0 nat ((((inf-upd Cn 0 0)) l)) (inf-count Ln l nsym) (hk l h1)) (inf-cntle Ln l nsym)))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))))))
; w5b-7
 (defq inf-vc-build-w5b-7 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-le (succ i) ((inf-upd Cn 0 0) l))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5)))))
; w5b-8
 (defq inf-vc-build-w5b-8 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-le (add (add (add idx 1) (natminus ((inf-upd Cn 0 0) l) (succ i))) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-idxstep idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2)))))
; w5b-9
 (defq inf-vc-build-w5b-9 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-le (add (add code 1) (add code 1)) (inf-dk (add idx 1) l))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-code2 code idx l h1 j3)))))
; w5b-10
 (defq inf-vc-build-w5b-10 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-lt (natminus ((inf-upd Cn 0 0) l) (succ i)) (natminus ((inf-upd Cn 0 0) l) i))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-subfall ((((inf-upd Cn 0 0)) l)) i w5)))))
; s12-1
 (defq inf-vc-build-s12-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-lt (add code code) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-lelt (add code code) (inf-dk idx l) (inf-pow w) j3 (inf-lelt (inf-dk idx l) (inf-dk q l) (inf-pow w) (inf-dkmono idx q l ((inf-letrans idx nsym q (inf-letrans idx (add idx ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l)))) nsym (inf-leaddr idx ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l)))) (inf-idxout idx (natminus ((((inf-upd Cn 0 0)) l)) i) ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym j2)) (inf-ltle nsym q gn)))) (gc l ((inf-ltsle l 15 w4))))))))
; w4b-1
 (defq inf-vc-build-w4b-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-lt (succ l) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-small (succ l) w (inf-letrans (succ l) 16 w (inf-ltsu l 16 w4) ((istransnatleh 16 32 w (idpath false) gw)))))))
; w4b-2
 (defq inf-vc-build-w4b-2 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-le 1 (succ l))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (idpath false))))
; w4b-3
 (defq inf-vc-build-w4b-3 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-le (add idx (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-idxout idx (natminus ((((inf-upd Cn 0 0)) l)) i) ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym j2))))
; w4b-4
 (defq inf-vc-build-w4b-4 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-le (add (add code code) (add code code)) (inf-dk idx (succ l)))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-dbl (add code code) (inf-dk idx l) j3))))
; w4b-5
 (defq inf-vc-build-w4b-5 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-lt (natminus 16 (succ l)) (natminus 16 l))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-subfall 16 l w4))))
 )
