; test/uuinfvc.l -- laid by src/love/compress/inf.l, `make mx`. edit that file.
; the ledger: what the theorems of inf_start and inf_stfeed leave open, each with who answers for it
; gw: the word is 32 bits or more -- every target
; go: out nonzero holds cap bytes: it reaches inf_start as inf_rd's out -- every caller below
; caller: (inflate s n): out a str0 of cap, the hint or the counted length -- gz.c
; caller: inflate_raw: an idat, out at f0 in a region of cap, f0 + fsz <= cap checked there -- quay/png.c
; caller: inflate_raw: a gzip member, out from AllocatePool of the size it states -- uefi/slot.c
; caller: inflate_raw: a carried tree entry -- archive/srctree.c
; caller: inflate_raw: a carried text -- cats.c
; caller: inflate_raw, inflate_dict: an image's dictionary and pages -- love.c
; caller: inflate_raw: a layer's run -- snap.c
; alloc: alloc(0, c) answers NULL or c bytes -- inf_stfeed's alloc
; state: inflate-feed's state is zeroes or what the last feed left: a port no love can write, its size and magic checked -- gz.c
; wiring: inflate-feed lays r->t and the tables' pointers at hand, before inf_stfeed -- gz.c
; reads: inflate-feed copies op bytes of out and n - ip of the input, which inf_stfeed's ensures bound -- gz.c
; link: struct inf_tabs, lens and hist hold what the specs' arrays say; the same file, unchecked -- inf.l
; link: a spec's operation means its C: two readers of one form, compared by test_gz -- inf.l
; link: LD64 is 8 bytes little endian, an In element a byte, and a mask the sum of its bits -- fillv, takev
(test
 (defn inf-tlb (pi k nat nat) (lam k (add (inf-tv 0 3 k) (add (inf-tv 1 4 k) (add (inf-tv 2 5 k) (add (inf-tv 3 6 k) (add (inf-tv 4 7 k) (add (inf-tv 5 8 k) (add (inf-tv 6 9 k) (add (inf-tv 7 10 k) (add (inf-tv 8 11 k) (add (inf-tv 9 13 k) (add (inf-tv 10 15 k) (add (inf-tv 11 17 k) (add (inf-tv 12 19 k) (add (inf-tv 13 23 k) (add (inf-tv 14 27 k) (add (inf-tv 15 31 k) (add (inf-tv 16 35 k) (add (inf-tv 17 43 k) (add (inf-tv 18 51 k) (add (inf-tv 19 59 k) (add (inf-tv 20 67 k) (add (inf-tv 21 83 k) (add (inf-tv 22 99 k) (add (inf-tv 23 115 k) (add (inf-tv 24 131 k) (add (inf-tv 25 163 k) (add (inf-tv 26 195 k) (add (inf-tv 27 227 k) (inf-tv 28 258 k)))))))))))))))))))))))))))))))
 (defn inf-tle (pi k nat nat) (lam k (add (inf-tv 0 0 k) (add (inf-tv 1 0 k) (add (inf-tv 2 0 k) (add (inf-tv 3 0 k) (add (inf-tv 4 0 k) (add (inf-tv 5 0 k) (add (inf-tv 6 0 k) (add (inf-tv 7 0 k) (add (inf-tv 8 1 k) (add (inf-tv 9 1 k) (add (inf-tv 10 1 k) (add (inf-tv 11 1 k) (add (inf-tv 12 2 k) (add (inf-tv 13 2 k) (add (inf-tv 14 2 k) (add (inf-tv 15 2 k) (add (inf-tv 16 3 k) (add (inf-tv 17 3 k) (add (inf-tv 18 3 k) (add (inf-tv 19 3 k) (add (inf-tv 20 4 k) (add (inf-tv 21 4 k) (add (inf-tv 22 4 k) (add (inf-tv 23 4 k) (add (inf-tv 24 5 k) (add (inf-tv 25 5 k) (add (inf-tv 26 5 k) (add (inf-tv 27 5 k) (inf-tv 28 0 k)))))))))))))))))))))))))))))))
 (defn inf-tdb (pi k nat nat) (lam k (add (inf-tv 0 1 k) (add (inf-tv 1 2 k) (add (inf-tv 2 3 k) (add (inf-tv 3 4 k) (add (inf-tv 4 5 k) (add (inf-tv 5 7 k) (add (inf-tv 6 9 k) (add (inf-tv 7 13 k) (add (inf-tv 8 17 k) (add (inf-tv 9 25 k) (add (inf-tv 10 33 k) (add (inf-tv 11 49 k) (add (inf-tv 12 65 k) (add (inf-tv 13 97 k) (add (inf-tv 14 129 k) (add (inf-tv 15 193 k) (add (inf-tv 16 257 k) (add (inf-tv 17 385 k) (add (inf-tv 18 513 k) (add (inf-tv 19 769 k) (add (inf-tv 20 1025 k) (add (inf-tv 21 1537 k) (add (inf-tv 22 2049 k) (add (inf-tv 23 3073 k) (add (inf-tv 24 4097 k) (add (inf-tv 25 6145 k) (add (inf-tv 26 8193 k) (add (inf-tv 27 12289 k) (add (inf-tv 28 16385 k) (inf-tv 29 24577 k))))))))))))))))))))))))))))))))
 (defn inf-tde (pi k nat nat) (lam k (add (inf-tv 0 0 k) (add (inf-tv 1 0 k) (add (inf-tv 2 0 k) (add (inf-tv 3 0 k) (add (inf-tv 4 1 k) (add (inf-tv 5 1 k) (add (inf-tv 6 2 k) (add (inf-tv 7 2 k) (add (inf-tv 8 3 k) (add (inf-tv 9 3 k) (add (inf-tv 10 4 k) (add (inf-tv 11 4 k) (add (inf-tv 12 5 k) (add (inf-tv 13 5 k) (add (inf-tv 14 6 k) (add (inf-tv 15 6 k) (add (inf-tv 16 7 k) (add (inf-tv 17 7 k) (add (inf-tv 18 8 k) (add (inf-tv 19 8 k) (add (inf-tv 20 9 k) (add (inf-tv 21 9 k) (add (inf-tv 22 10 k) (add (inf-tv 23 10 k) (add (inf-tv 24 11 k) (add (inf-tv 25 11 k) (add (inf-tv 26 12 k) (add (inf-tv 27 12 k) (add (inf-tv 28 13 k) (inf-tv 29 13 k))))))))))))))))))))))))))))))))
 (defn inf-tob (pi k nat nat) (lam k (add (inf-tv 0 16 k) (add (inf-tv 1 17 k) (add (inf-tv 2 18 k) (add (inf-tv 3 0 k) (add (inf-tv 4 8 k) (add (inf-tv 5 7 k) (add (inf-tv 6 9 k) (add (inf-tv 7 6 k) (add (inf-tv 8 10 k) (add (inf-tv 9 5 k) (add (inf-tv 10 11 k) (add (inf-tv 11 4 k) (add (inf-tv 12 12 k) (add (inf-tv 13 3 k) (add (inf-tv 14 13 k) (add (inf-tv 15 2 k) (add (inf-tv 16 14 k) (add (inf-tv 17 1 k) (inf-tv 18 15 k)))))))))))))))))))))
 (defcx inf-walk (Cn (pi i nat nat)) (Sy (pi i nat nat)) (bit (pi i nat nat)) (n nat) (h nat) (w nat) (b1 (pi i nat (inf-le (bit i) 1))) (hc (pi i nat (inf-lt (Cn i) (inf-pow h)))) (hs (pi i nat (inf-lt (Sy i) (inf-pow h)))) (gh (inf-le h 16)) (gw (inf-le 31 w)) (gn (inf-lt n (inf-pow w))) (gs (inf-le (inf-sum Cn 15 1) n)) )
 (defvcs inf-vc-walk-w1e 1 inf-walk ()
  (inf-le 1 1) (idpath false)
  (inf-le 0 0) (idpath false)
  (inf-le (add 0 2) (inf-pow 1)) (idpath false)
  (paths nat (inf-mod 2 0) 0) (idpath 0)
  (inf-le (add 0 (inf-sum Cn (natminus 16 1) 1)) n) gs
 )
 (defcx inf-walk-w1 inf-walk (l nat) (index nat) (first nat) (code nat) (i1 (inf-le 1 l)) (i2 (inf-le first code)) (i3 (inf-le (add code 2) (inf-pow l))) (i4 (paths nat (inf-mod 2 code) 0)) (i5 (inf-le (add index (inf-sum Cn (natminus 16 l) l)) n)) )
 (defvcs inf-vc-walk-s1 1 inf-walk-w1 (w1 (inf-lt l 16))
  (inf-le 1 l) i1
  (inf-lt (natminus l 1) 64) (inf-lelt (natminus l 1) l 64 (inf-suble l 1) (inf-lttrans l 16 64 w1 (idpath false)))
  (paths nat (inf-mod 2 code) 0) i4
  (inf-lt (bit (natminus l 1)) 2) (inf-lelts ((bit (natminus l 1))) 1 (b1 (natminus l 1)))
  (inf-lt (add code (bit (natminus l 1))) (inf-pow w)) ((inf-powfit ((add code ((bit (natminus l 1))))) l w ((inf-wor code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)) ((inf-lew l w w1 gw))))
 )
 (defvcs inf-vc-walk-s2 1 inf-walk-w1 (w1 (inf-lt l 16))
  (inf-lt l 16) w1
  (inf-lt (Cn l) (inf-pow w)) ((inf-powfit (Cn l) h w (hc l) ((istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw)))))
 )
 (defvcs inf-vc-walk-s3 1 inf-walk-w1 (w1 (inf-lt l 16))
  (inf-lt (add code (bit (natminus l 1))) (inf-pow w)) ((inf-powfit ((add code ((bit (natminus l 1))))) l w ((inf-wor code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)) ((inf-lew l w w1 gw))))
  (inf-lt (Cn l) (inf-pow w)) ((inf-powfit (Cn l) h w (hc l) ((istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw)))))
 )
 (defvcs inf-vc-walk-s4 1 inf-walk-w1 (w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))))
  (inf-le first (add code (bit (natminus l 1)))) ((istransnatleh first code ((add code ((bit (natminus l 1))))) i2 (inf-leaddr code ((bit (natminus l 1))))))
  (inf-lt (add index (natminus (add code (bit (natminus l 1))) first)) (inf-pow w)) (inf-lttrans ((add index (natminus ((add code ((bit (natminus l 1))))) first))) n (inf-pow w) ((inf-lttrans ((add index (natminus ((add code ((bit (natminus l 1))))) first))) (add index (Cn l)) n (inf-ltaddl index (natminus ((add code ((bit (natminus l 1))))) first) (Cn l) (inf-subshort first ((add code ((bit (natminus l 1))))) (Cn l) ((istransnatleh first code ((add code ((bit (natminus l 1))))) i2 (inf-leaddr code ((bit (natminus l 1)))))) g3)) ((inf-sumhead Cn 16 l index n w1 i5)))) (inf-ltle n (inf-pow w) gn))
  (inf-lt (add index (natminus (add code (bit (natminus l 1))) first)) n) ((inf-lttrans ((add index (natminus ((add code ((bit (natminus l 1))))) first))) (add index (Cn l)) n (inf-ltaddl index (natminus ((add code ((bit (natminus l 1))))) first) (Cn l) (inf-subshort first ((add code ((bit (natminus l 1))))) (Cn l) ((istransnatleh first code ((add code ((bit (natminus l 1))))) i2 (inf-leaddr code ((bit (natminus l 1)))))) g3)) ((inf-sumhead Cn 16 l index n w1 i5))))
  (inf-lt (Sy (add index (natminus (add code (bit (natminus l 1))) first))) (inf-pow w)) (inf-powfit ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))) h w (hs ((add index (natminus ((add code ((bit (natminus l 1))))) first)))) ((istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw))))
  (inf-lt (inf-by16 (Sy (add index (natminus (add code (bit (natminus l 1))) first)))) (inf-pow w)) (inf-lelt (inf-by16 ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))) (add (inf-by16 ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))) l) (inf-pow w) (inf-leaddr (inf-by16 ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))) l) ((inf-by16or ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))) l h w (hs ((add index (natminus ((add code ((bit (natminus l 1))))) first)))) w1 gh gw)))
  (inf-lt l (inf-pow w)) (inf-lttrans l 16 (inf-pow w) w1 (inf-powle 4 w (istransnatleh 4 31 w (idpath false) gw)))
  (paths nat (inf-mod 16 (inf-by16 (Sy (add index (natminus (add code (bit (natminus l 1))) first))))) 0) (inf-by16low ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))))
  (inf-lt l 16) w1
  (inf-lt (add (inf-by16 (Sy (add index (natminus (add code (bit (natminus l 1))) first)))) l) (inf-pow w)) ((inf-by16or ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))) l h w (hs ((add index (natminus ((add code ((bit (natminus l 1))))) first)))) w1 gh gw))
 )
 (defvcs inf-vc-walk-s5 1 inf-walk-w1 (w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))))
  (inf-lt (add index (Cn l)) (inf-pow w)) (inf-lelt (add index (Cn l)) n (inf-pow w) ((inf-sumhead Cn 16 l index n w1 i5)) gn)
 )
 (defvcs inf-vc-walk-s6 1 inf-walk-w1 (w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))))
  (inf-lt (add first (Cn l)) (inf-pow w)) (inf-lelt ((add first (Cn l))) ((add code ((bit (natminus l 1))))) (inf-pow w) g3 ((inf-powfit ((add code ((bit (natminus l 1))))) l w ((inf-wor code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)) ((inf-lew l w w1 gw)))))
  (inf-lt (add (add first (Cn l)) (add first (Cn l))) (inf-pow w)) (inf-lelt (add ((add first (Cn l))) ((add first (Cn l)))) ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (inf-pow w) (inf-dbl ((add first (Cn l))) ((add code ((bit (natminus l 1))))) g3) ((inf-powfit ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (succ l) w (inf-lttrans ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (add ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) 2) (inf-pow (succ l)) (inf-lt2 ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1)))))))) ((inf-wsh code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3))) (istransnatleh (succ l) 16 w (inf-ltsu l 16 w1) (istransnatleh 16 31 w (idpath false) gw)))))
 )
 (defvcs inf-vc-walk-s7 1 inf-walk-w1 (w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))))
  (inf-lt (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1)))) (inf-pow w)) ((inf-powfit ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (succ l) w (inf-lttrans ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (add ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) 2) (inf-pow (succ l)) (inf-lt2 ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1)))))))) ((inf-wsh code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3))) (istransnatleh (succ l) 16 w (inf-ltsu l 16 w1) (istransnatleh 16 31 w (idpath false) gw))))
 )
 (defvcs inf-vc-walk-w1b 1 inf-walk-w1 (w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))))
  (inf-lt (succ l) (inf-pow w)) (inf-lelt (succ l) 16 (inf-pow w) (inf-ltsu l 16 w1) (inf-lttrans 16 32 (inf-pow w) (idpath true) (inf-powle 5 w (istransnatleh 5 31 w (idpath false) gw))))
  (inf-le 1 (succ l)) (idpath false)
  (inf-le (add (add first (Cn l)) (add first (Cn l))) (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1))))) (inf-dbl ((add first (Cn l))) ((add code ((bit (natminus l 1))))) g3)
  (inf-le (add (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1)))) 2) (inf-pow (succ l))) ((inf-wsh code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3))
  (paths nat (inf-mod 2 (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1))))) 0) (inf-moddbl ((add code ((bit (natminus l 1))))))
  (inf-le (add (add index (Cn l)) (inf-sum Cn (natminus 16 (succ l)) (succ l))) n) (inf-sumnext Cn 16 l index n w1 i5)
  (inf-lt (natminus 16 (succ l)) (natminus 16 l)) (inf-subfall 16 l w1)
 )
 (defcx inf-build (Ln (pi k nat nat)) (nsym nat) (root nat) (q nat) (u nat) (w nat) (hl (pi k nat g (inf-lt k nsym) (inf-le (Ln k) 15))) (gn (inf-lt nsym q)) (gu (inf-le (inf-by16 q) u)) (gv (inf-le u (inf-pow w))) (gr (inf-le root 15)) (gw (inf-le 32 w)) (gc (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) )
 (defvcs inf-vc-build-d0 1 inf-build ()
  (inf-lt root 32) (inf-lelt root 15 32 gr (idpath true))
  (inf-lt (inf-pow root) (inf-pow w)) (inf-powlt root w ((inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) ((istransnatleh 16 32 w (idpath false) gw))))))
 )
 (defvcs inf-vc-build-w1e 1 inf-build ()
  (inf-le 0 nsym) (idpath false)
  (pi k nat (paths nat (inf-zero k) (inf-count Ln k 0))) (lam k (idpath 0))
 )
 (defcx inf-build-w1 inf-build (i nat) (Cn (pi j nat nat)) (a1 (inf-le i nsym)) (a2 (pi k nat (paths nat (Cn k) (inf-count Ln k i)))) )
 (defvcs inf-vc-build-s1 1 inf-build-w1 (w1 (inf-lt i nsym))
  (inf-lt i nsym) w1
  (inf-lt (Ln i) 16) (inf-lelts ((Ln i)) 15 (hl i w1))
  (inf-lt (add (Cn (Ln i)) 1) (inf-pow w)) (inf-lelt (add ((Cn ((Ln i)))) 1) nsym (inf-pow w) ((inf-lt1 ((Cn ((Ln i)))) nsym (inf-lelt ((Cn ((Ln i)))) i nsym ((inf-letr (inf-count Ln ((Ln i)) i) ((Cn ((Ln i)))) i (pathsinv0 nat ((Cn ((Ln i)))) (inf-count Ln ((Ln i)) i) (a2 ((Ln i)))) (inf-cntle Ln ((Ln i)) i))) w1))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))
  (inf-lt (add (Cn (Ln i)) 1) u) (inf-lelt (add ((Cn ((Ln i)))) 1) nsym u ((inf-lt1 ((Cn ((Ln i)))) nsym (inf-lelt ((Cn ((Ln i)))) i nsym ((inf-letr (inf-count Ln ((Ln i)) i) ((Cn ((Ln i)))) i (pathsinv0 nat ((Cn ((Ln i)))) (inf-count Ln ((Ln i)) i) (a2 ((Ln i)))) (inf-cntle Ln ((Ln i)) i))) w1))) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu))))
 )
 (defvcs inf-vc-build-w1b 1 inf-build-w1 (w1 (inf-lt i nsym))
  (inf-lt (succ i) (inf-pow w)) (inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w1) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))
  (inf-le (succ i) nsym) (inf-ltsu i nsym w1)
  (pi k nat (paths nat ((inf-upd Cn (Ln i) (add (Cn (Ln i)) 1)) k) (inf-count Ln k (succ i)))) (lam k (inf-cntstep Ln Cn i a2 k))
  (inf-lt (natminus nsym (succ i)) (natminus nsym i)) (inf-subfall nsym i w1)
 )
 (defvcs inf-vc-build-c5 1 inf-build-w1 (w1 (inf-le nsym i))
  (inf-lt 0 16) (idpath true)
  (inf-lt 0 u) (inf-lelt 0 nsym u (idpath false) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu))))
 )
 (defvcs inf-vc-build-ka 1 inf-build-w1 (w1 (inf-le nsym i))
  (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) (lam k g (inf-hk Cn Ln i nsym a1 w1 a2 k g))
 )
 (defvcs inf-vc-build-kb 1 inf-build-w1 (w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))))
  (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) (lam o (inf-sumcong ((inf-upd Cn 0 0)) (lam v (inf-count Ln v nsym)) hk o 1 (idpath false)))
 )
 (defvcs inf-vc-build-kc 1 inf-build-w1 (w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))))
  (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym)) (lam o (inf-letr ((inf-sum (lam v (inf-count Ln v nsym)) o 1)) ((inf-sum ((inf-upd Cn 0 0)) o 1)) nsym (pathsinv0 nat ((inf-sum ((inf-upd Cn 0 0)) o 1)) ((inf-sum (lam v (inf-count Ln v nsym)) o 1)) (hs o)) (inf-sumcount Ln o 1 nsym)))
 )
 (defvcs inf-vc-build-w2e 1 inf-build-w1 (w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym)))
  (inf-le 1 1) (idpath false)
  (inf-le 1 15) (idpath false)
  (pi o nat g (inf-lt o 1) (paths nat (inf-zero (succ o)) (inf-sum (inf-upd Cn 0 0) o 1))) (lam o g (inf-o1 ((inf-upd Cn 0 0)) o g))
 )
 (defcx inf-build-w1-w2 inf-build-w1 (w1 (inf-le nsym i)) (hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym)))) (hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1)))) (hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym))) (l nat) (Of (pi j nat nat)) (b1 (inf-le 1 l)) (b2 (inf-le l 15)) (b3 (pi o nat g (inf-lt o l) (paths nat (Of (succ o)) (inf-sum (inf-upd Cn 0 0) o 1)))) )
 (defvcs inf-vc-build-s2 1 inf-build-w1-w2 (w2 (inf-lt l 15))
  (inf-lt (add l 1) (inf-pow w)) (inf-small (add l 1) w (inf-letrans (add l 1) 15 w (inf-lt1 l 15 w2) ((istransnatleh 15 32 w (idpath false) gw))))
  (inf-lt (add l 1) 16) (inf-lelts (add l 1) 15 (inf-lt1 l 15 w2))
  (inf-lt l 16) (inf-lttrans l 15 16 w2 (idpath false))
  (inf-lt (add (Of l) ((inf-upd Cn 0 0) l)) (inf-pow w)) (inf-lelt (add (Of l) ((((inf-upd Cn 0 0)) l))) nsym (inf-pow w) (inf-letr (inf-sum ((inf-upd Cn 0 0)) l 1) (add (Of l) ((((inf-upd Cn 0 0)) l))) nsym (pathsinv0 nat (add (Of l) ((((inf-upd Cn 0 0)) l))) (inf-sum ((inf-upd Cn 0 0)) l 1) (inf-sumlast ((inf-upd Cn 0 0)) Of l b1 b3)) (hb l)) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))
 )
 (defvcs inf-vc-build-w2b 1 inf-build-w1-w2 (w2 (inf-lt l 15))
  (inf-lt (succ l) (inf-pow w)) (inf-small (succ l) w (inf-letrans (succ l) 15 w (inf-ltsu l 15 w2) ((istransnatleh 15 32 w (idpath false) gw))))
  (inf-le 1 (succ l)) (idpath false)
  (inf-le (succ l) 15) (inf-ltsu l 15 w2)
  (pi o nat g (inf-lt o (succ l)) (paths nat ((inf-upd Of (add l 1) (add (Of l) ((inf-upd Cn 0 0) l))) (succ o)) (inf-sum (inf-upd Cn 0 0) o 1))) (lam o g (inf-ofstep ((inf-upd Cn 0 0)) Of l b1 b3 o g))
  (inf-lt (natminus 15 (succ l)) (natminus 15 l)) (inf-subfall 15 l w2)
 )
 (defvcs inf-vc-build-w3e 1 inf-build-w1-w2 (w2 (inf-le 15 l))
  (inf-le 0 nsym) (idpath false)
  (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) 0)))) (lam o g (pathscomp0 nat (Of (succ o)) ((inf-sum ((inf-upd Cn 0 0)) o 1)) (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) 0) (b3 o (inf-lttrans o 15 l g w2)) (pathsinv0 nat (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) 0) ((inf-sum ((inf-upd Cn 0 0)) o 1)) (natplusr0 ((inf-sum ((inf-upd Cn 0 0)) o 1))))))
  (pi k nat (inf-lt (inf-zero k) q)) (lam k (inf-lelt 0 nsym q (idpath false) gn))
 )
 (defcx inf-build-w1-w2-w3 inf-build-w1-w2 (w2 (inf-le 15 l)) (i nat) (Of (pi j nat nat)) (Sy (pi j nat nat)) (e1 (inf-le i nsym)) (e2 (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) i))))) (e3 (pi k nat (inf-lt (Sy k) q))) )
 (defvcs inf-vc-build-s3 1 inf-build-w1-w2-w3 (w3 (inf-lt i nsym))
  (inf-lt i nsym) w3
 )
 (defvcs inf-vc-build-s4 1 inf-build-w1-w2-w3 (w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)))
  (inf-lt i nsym) w3
  (inf-lt (Ln i) 16) (inf-lelts ((Ln i)) 15 (hl i w3))
  (inf-lt (Of (Ln i)) nsym) ((inf-ofs Ln ((inf-upd Cn 0 0)) Of nsym i w3 e2 hs ((Ln i)) (idpath ((Ln i))) g3 (hl i w3)))
  (inf-lt i u) (inf-lttrans i nsym u w3 (inf-ltle nsym u ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))))
 )
 (defvcs inf-vc-build-s5 1 inf-build-w1-w2-w3 (w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)))
  (inf-lt i nsym) w3
  (inf-lt (Ln i) 16) (inf-lelts ((Ln i)) 15 (hl i w3))
  (inf-lt (add (Of (Ln i)) 1) (inf-pow w)) (inf-lelt (add (Of ((Ln i))) 1) nsym (inf-pow w) (inf-lt1 (Of ((Ln i))) nsym ((inf-ofs Ln ((inf-upd Cn 0 0)) Of nsym i w3 e2 hs ((Ln i)) (idpath ((Ln i))) g3 (hl i w3)))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))
 )
 (defvcs inf-vc-build-w3b 1 inf-build-w1-w2-w3 (w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)))
  (inf-lt (succ i) (inf-pow w)) (inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w3) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))
  (inf-le (succ i) nsym) (inf-ltsu i nsym w3)
  (pi o nat g (inf-lt o 15) (paths nat ((inf-upd Of (Ln i) (add (Of (Ln i)) 1)) (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) (succ i))))) (lam o g (inf-fillstep Of Ln i ((inf-sum ((inf-upd Cn 0 0)) o 1)) o (e2 o g)))
  (pi k nat (inf-lt ((inf-upd Sy (Of (Ln i)) i) k) q)) (lam k (inf-uplt Sy (Of ((Ln i))) i q e3 (inf-lttrans i nsym q w3 (inf-ltle nsym q gn)) k))
  (inf-lt (natminus nsym (succ i)) (natminus nsym i)) (inf-subfall nsym i w3)
 )
 (defvcs inf-vc-build-w3b 6 inf-build-w1-w2-w3 (w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0))
  (inf-lt (succ i) (inf-pow w)) (inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w3) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))
  (inf-le (succ i) nsym) (inf-ltsu i nsym w3)
  (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) (succ i))))) (lam o g (pathscomp0 nat (Of (succ o)) (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) ((inf-count Ln (succ o) i))) (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) ((inf-count Ln (succ o) (succ i)))) (e2 o g) (maponpaths nat nat (lam z (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) z)) ((inf-count Ln (succ o) i)) ((inf-count Ln (succ o) (succ i))) (pathsinv0 nat ((inf-count Ln (succ o) (succ i))) ((inf-count Ln (succ o) i)) (inf-fillzero Ln i o g3)))))
  (pi k nat (inf-lt (Sy k) q)) e3
  (inf-lt (natminus nsym (succ i)) (natminus nsym i)) (inf-subfall nsym i w3)
 )
 (defvcs inf-vc-build-w4e 1 inf-build-w1-w2-w3 (w3 (inf-le nsym i))
  (inf-le 1 1) (idpath false)
  (inf-le (add 0 (inf-sum (inf-upd Cn 0 0) (natminus 16 1) 1)) nsym) (hb 15)
  (inf-le (add 0 0) (inf-dk 0 1)) (idpath false)
 )
 (defcx inf-build-w1-w2-w3-w4 inf-build-w1-w2-w3 (w3 (inf-le nsym i)) (l nat) (i nat) (Tb (pi j nat nat)) (idx nat) (code nat) (h1 (inf-le 1 l)) (h2 (inf-le (add idx (inf-sum (inf-upd Cn 0 0) (natminus 16 l) l)) nsym)) (h3 (inf-le (add code code) (inf-dk idx l))) )
 (defvcs inf-vc-build-w5e 1 inf-build-w1-w2-w3-w4 (w4 (inf-lt l 16))
  (inf-le 0 ((inf-upd Cn 0 0) l)) (idpath false)
  (inf-le (add (add idx (natminus ((inf-upd Cn 0 0) l) 0)) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym) (inf-idxenter ((inf-upd Cn 0 0)) l idx nsym w4 h2)
  (inf-le (add code code) (inf-dk idx l)) h3
 )
 (defcx inf-build-w1-w2-w3-w4-w5 inf-build-w1-w2-w3-w4 (w4 (inf-lt l 16)) (i nat) (Tb (pi j nat nat)) (idx nat) (code nat) (j1 (inf-le i ((inf-upd Cn 0 0) l))) (j2 (inf-le (add (add idx (natminus ((inf-upd Cn 0 0) l) i)) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)) (j3 (inf-le (add code code) (inf-dk idx l))) )
 (defvcs inf-vc-build-w5h 1 inf-build-w1-w2-w3-w4-w5 ()
  (inf-lt l 16) w4
 )
 (defvcs inf-vc-build-d1 1 inf-build-w1-w2-w3-w4-w5 (w5 (inf-lt i ((inf-upd Cn 0 0) l)))
  (inf-lt idx nsym) ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))
  (inf-lt (Sy idx) (inf-pow w)) (inf-lttrans ((Sy idx)) q (inf-pow w) (e3 idx) ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))
  (inf-lt 0 (inf-pow w)) (inf-powpos w)
 )
 (defvcs inf-vc-build-s6 1 inf-build-w1-w2-w3-w4-w5 (w5 (inf-lt i ((inf-upd Cn 0 0) l)))
  (inf-lt (add idx 1) (inf-pow w)) (inf-lelt ((add idx 1)) nsym (inf-pow w) (inf-lt1 idx nsym ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))
 )
 (defvcs inf-vc-build-w6e 1 inf-build-w1-w2-w3-w4-w5 (w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-le l root))
  (inf-le 0 l) (idpath false)
  (inf-lt 0 (inf-pow 0)) (idpath true)
 )
 (defcx inf-build-w1-w2-w3-w4-w5-w6 inf-build-w1-w2-w3-w4-w5 (w5 (inf-lt i ((inf-upd Cn 0 0) l))) (g7 (inf-le l root)) (b nat) (rev nat) (m1 (inf-le b l)) (m2 (inf-lt rev (inf-pow b))) )
 (defvcs inf-vc-build-s8 1 inf-build-w1-w2-w3-w4-w5-w6 (w6 (inf-lt b l))
  (inf-lt (add rev rev) (inf-pow w)) (inf-powfit (add rev rev) (succ b) w (inf-dblfit rev (inf-pow b) m2) ((inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 ((inf-ltsu b l w6)) ((inf-ltsle l 15 w4))) ((istransnatleh 15 32 w (idpath false) gw)))))
  (inf-lt b 32) (inf-lttrans b l 32 w6 (inf-ltle l 32 (inf-lttrans l 16 32 w4 (idpath false))))
  (paths nat (inf-mod 2 (add rev rev)) 0) (inf-moddbl rev)
  (inf-lt (inf-sb code b) 2) ((inf-modlt 1 (inf-shr code b)))
  (inf-lt (add (add rev rev) (inf-sb code b)) (inf-pow w)) (inf-powfit (add (add rev rev) ((inf-sb code b))) (succ b) w ((inf-revstep rev (inf-pow b) ((inf-sb code b)) m2 ((inf-modlt 1 (inf-shr code b))))) ((inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 ((inf-ltsu b l w6)) ((inf-ltsle l 15 w4))) ((istransnatleh 15 32 w (idpath false) gw)))))
 )
 (defvcs inf-vc-build-w6b 1 inf-build-w1-w2-w3-w4-w5-w6 (w6 (inf-lt b l))
  (inf-lt (succ b) (inf-pow w)) (inf-small (succ b) w ((inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 ((inf-ltsu b l w6)) ((inf-ltsle l 15 w4))) ((istransnatleh 15 32 w (idpath false) gw)))))
  (inf-le (succ b) l) ((inf-ltsu b l w6))
  (inf-lt (add (add rev rev) (inf-sb code b)) (inf-pow (succ b))) ((inf-revstep rev (inf-pow b) ((inf-sb code b)) m2 ((inf-modlt 1 (inf-shr code b)))))
  (inf-lt (natminus l (succ b)) (natminus l b)) (inf-subfall l b w6)
 )
 (defcx inf-build-w1-w2-w3-w4-w5-w6-w7 inf-build-w1-w2-w3-w4-w5-w6 (w6 (inf-le l b)) (j nat) (Tb (pi j nat nat)) )
 (defvcs inf-vc-build-s9 1 inf-build-w1-w2-w3-w4-w5-w6-w7 (w7 (inf-lt j (inf-pow root)))
  (inf-lt j (inf-pow root)) w7
 )
 (defvcs inf-vc-build-s10 1 inf-build-w1-w2-w3-w4-w5-w6-w7 (w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0))
  (inf-lt j (inf-pow root)) w7
  (inf-lt (inf-by16 (Sy idx)) (inf-pow w)) (inf-lelt (inf-by16 ((Sy idx))) ((add (inf-by16 ((Sy idx))) l)) (inf-pow w) (inf-leaddr (inf-by16 ((Sy idx))) l) ((inf-lttrans ((add (inf-by16 ((Sy idx))) l)) (inf-by16 q) (inf-pow w) ((inf-entry ((Sy idx)) l q (e3 idx) w4)) (inf-letrans (inf-by16 q) u (inf-pow w) gu gv))))
  (paths nat (inf-mod 16 (inf-by16 (Sy idx))) 0) (inf-by16low ((Sy idx)))
  (inf-lt l 16) w4
  (inf-lt (add (inf-by16 (Sy idx)) l) (inf-pow w)) ((inf-lttrans ((add (inf-by16 ((Sy idx))) l)) (inf-by16 q) (inf-pow w) ((inf-entry ((Sy idx)) l q (e3 idx) w4)) (inf-letrans (inf-by16 q) u (inf-pow w) gu gv)))
  (inf-lt (add (inf-by16 (Sy idx)) l) u) (inf-lttrans ((add (inf-by16 ((Sy idx))) l)) (inf-by16 q) u ((inf-entry ((Sy idx)) l q (e3 idx) w4)) gu)
 )
 (defvcs inf-vc-build-w7b 1 inf-build-w1-w2-w3-w4-w5-w6-w7 (w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0))
  (inf-lt l 32) (inf-lttrans l 16 32 w4 (idpath false))
  (inf-lt (inf-pow l) (inf-pow w)) (inf-powlt l w ((inf-lttrans l 16 w w4 ((istransnatleh 16 32 w (idpath false) gw)))))
  (inf-lt (add j (inf-pow l)) (inf-pow w)) ((inf-powfit (add j (inf-pow l)) (succ root) w (inf-tabstep j l root w7 g7) (inf-ltsu root w ((inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) ((istransnatleh 16 32 w (idpath false) gw))))))))
  (inf-lt (natminus (inf-pow root) (add j (inf-pow l))) (natminus (inf-pow root) j)) ((inf-subby j (inf-pow root) (inf-pow l) w7 (inf-powpos l)))
 )
 (defvcs inf-vc-build-w7b 5 inf-build-w1-w2-w3-w4-w5-w6-w7 (w7 (inf-lt j (inf-pow root)) g9 (inf-lt 0 (Tb j)))
  (inf-lt l 32) (inf-lttrans l 16 32 w4 (idpath false))
  (inf-lt (inf-pow l) (inf-pow w)) (inf-powlt l w ((inf-lttrans l 16 w w4 ((istransnatleh 16 32 w (idpath false) gw)))))
  (inf-lt (add j (inf-pow l)) (inf-pow w)) ((inf-powfit (add j (inf-pow l)) (succ root) w (inf-tabstep j l root w7 g7) (inf-ltsu root w ((inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) ((istransnatleh 16 32 w (idpath false) gw))))))))
  (inf-lt (natminus (inf-pow root) (add j (inf-pow l))) (natminus (inf-pow root) j)) ((inf-subby j (inf-pow root) (inf-pow l) w7 (inf-powpos l)))
 )
 (defvcs inf-vc-build-s11 1 inf-build-w1-w2-w3-w4-w5-w6-w7 (w7 (inf-le (inf-pow root) j))
  (inf-lt (add code 1) (inf-pow w)) ((inf-lelt ((add code 1)) (inf-dk ((add idx 1)) l) (inf-pow w) (inf-letrans ((add code 1)) (add ((add code 1)) ((add code 1))) (inf-dk ((add idx 1)) l) (inf-leaddr ((add code 1)) ((add code 1))) ((inf-code2 code idx l h1 j3))) ((inf-lelt (inf-dk ((add idx 1)) l) (inf-dk q l) (inf-pow w) (inf-dkmono ((add idx 1)) q l (inf-letrans ((add idx 1)) nsym q (inf-lt1 idx nsym ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))) (inf-ltle nsym q gn))) (gc l ((inf-ltsle l 15 w4)))))))
 )
 (defvcs inf-vc-build-w5b 1 inf-build-w1-w2-w3-w4-w5-w6-w7 (w7 (inf-le (inf-pow root) j))
  (inf-lt (succ i) (inf-pow w)) ((inf-lelt (succ i) nsym (inf-pow w) (inf-letrans (succ i) ((((inf-upd Cn 0 0)) l)) nsym (inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5) ((inf-letr (inf-count Ln l nsym) ((((inf-upd Cn 0 0)) l)) nsym (pathsinv0 nat ((((inf-upd Cn 0 0)) l)) (inf-count Ln l nsym) (hk l h1)) (inf-cntle Ln l nsym)))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))
  (inf-le (succ i) ((inf-upd Cn 0 0) l)) ((inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5))
  (inf-le (add (add (add idx 1) (natminus ((inf-upd Cn 0 0) l) (succ i))) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym) ((inf-idxstep idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))
  (inf-le (add (add code 1) (add code 1)) (inf-dk (add idx 1) l)) ((inf-code2 code idx l h1 j3))
  (inf-lt (natminus ((inf-upd Cn 0 0) l) (succ i)) (natminus ((inf-upd Cn 0 0) l) i)) ((inf-subfall ((((inf-upd Cn 0 0)) l)) i w5))
 )
 (defvcs inf-vc-build-s11 2 inf-build-w1-w2-w3-w4-w5 (w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l))
  (inf-lt (add code 1) (inf-pow w)) ((inf-lelt ((add code 1)) (inf-dk ((add idx 1)) l) (inf-pow w) (inf-letrans ((add code 1)) (add ((add code 1)) ((add code 1))) (inf-dk ((add idx 1)) l) (inf-leaddr ((add code 1)) ((add code 1))) ((inf-code2 code idx l h1 j3))) ((inf-lelt (inf-dk ((add idx 1)) l) (inf-dk q l) (inf-pow w) (inf-dkmono ((add idx 1)) q l (inf-letrans ((add idx 1)) nsym q (inf-lt1 idx nsym ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))) (inf-ltle nsym q gn))) (gc l ((inf-ltsle l 15 w4)))))))
 )
 (defvcs inf-vc-build-w5b 6 inf-build-w1-w2-w3-w4-w5 (w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l))
  (inf-lt (succ i) (inf-pow w)) ((inf-lelt (succ i) nsym (inf-pow w) (inf-letrans (succ i) ((((inf-upd Cn 0 0)) l)) nsym (inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5) ((inf-letr (inf-count Ln l nsym) ((((inf-upd Cn 0 0)) l)) nsym (pathsinv0 nat ((((inf-upd Cn 0 0)) l)) (inf-count Ln l nsym) (hk l h1)) (inf-cntle Ln l nsym)))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))
  (inf-le (succ i) ((inf-upd Cn 0 0) l)) ((inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5))
  (inf-le (add (add (add idx 1) (natminus ((inf-upd Cn 0 0) l) (succ i))) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym) ((inf-idxstep idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))
  (inf-le (add (add code 1) (add code 1)) (inf-dk (add idx 1) l)) ((inf-code2 code idx l h1 j3))
  (inf-lt (natminus ((inf-upd Cn 0 0) l) (succ i)) (natminus ((inf-upd Cn 0 0) l) i)) ((inf-subfall ((((inf-upd Cn 0 0)) l)) i w5))
 )
 (defvcs inf-vc-build-s12 1 inf-build-w1-w2-w3-w4-w5 (w5 (inf-le ((inf-upd Cn 0 0) l) i))
  (inf-lt (add code code) (inf-pow w)) (inf-lelt (add code code) (inf-dk idx l) (inf-pow w) j3 (inf-lelt (inf-dk idx l) (inf-dk q l) (inf-pow w) (inf-dkmono idx q l ((inf-letrans idx nsym q (inf-letrans idx (add idx ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l)))) nsym (inf-leaddr idx ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l)))) (inf-idxout idx (natminus ((((inf-upd Cn 0 0)) l)) i) ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym j2)) (inf-ltle nsym q gn)))) (gc l ((inf-ltsle l 15 w4)))))
 )
 (defvcs inf-vc-build-w4b 1 inf-build-w1-w2-w3-w4-w5 (w5 (inf-le ((inf-upd Cn 0 0) l) i))
  (inf-lt (succ l) (inf-pow w)) (inf-small (succ l) w (inf-letrans (succ l) 16 w (inf-ltsu l 16 w4) ((istransnatleh 16 32 w (idpath false) gw))))
  (inf-le 1 (succ l)) (idpath false)
  (inf-le (add idx (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym) (inf-idxout idx (natminus ((((inf-upd Cn 0 0)) l)) i) ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym j2)
  (inf-le (add (add code code) (add code code)) (inf-dk idx (succ l))) (inf-dbl (add code code) (inf-dk idx l) j3)
  (inf-lt (natminus 16 (succ l)) (natminus 16 l)) (inf-subfall 16 l w4)
 )
 (defvcs inf-vc-build-end 1 inf-build-w1-w2-w3-w4 (w4 (inf-le 16 l))
  (pi z nat (inf-lt ((inf-upd Cn 0 0) z) u)) (inf-cphi ((inf-upd Cn 0 0)) Ln nsym u hk (inf-lelt 0 nsym u (idpath false) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu))))
  (pi z nat (inf-lt (Sy z) u)) (lam z (inf-lttrans (Sy z) q u (e3 z) (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))
  (inf-le (inf-sum (inf-upd Cn 0 0) 15 1) nsym) (hb 15)
 )
 (defcx inf-fill (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) )
 (defvcs inf-vc-fill-i1 1 inf-fill ()
  (inf-lt (add ip0 8) (inf-pow w)) (inf-lelt (add ip0 8) (add n 8) (inf-pow w) (inf-addr ip0 n 8 gi) gn)
 )
 (defvcs inf-vc-fill-a1 1 inf-fill (g1 (inf-le (add ip0 8) n))
  (inf-le (add ip0 8) n) g1
  (inf-lt bc0 64) (inf-lelts bc0 63 (gs))
 )
 (defvcs inf-vc-fill-a2 1 inf-fill (g1 (inf-le (add ip0 8) n) bba1 nat)
  (inf-le (inf-div8 bc0) 7) (inf-div8le bc0 (gs))
  (inf-lt (add ip0 (natminus 7 (inf-div8 bc0))) (inf-pow w)) (inf-lelt ((add ip0 ((natminus 7 (inf-div8 bc0))))) n (inf-pow w) (inf-letrans ((add ip0 ((natminus 7 (inf-div8 bc0))))) (add ip0 8) n ((inf-addl ip0 ((natminus 7 (inf-div8 bc0))) 8 (inf-letrans ((natminus 7 (inf-div8 bc0))) 7 8 (inf-suble 7 (inf-div8 bc0)) (idpath false)))) g1) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))
 )
 (defvcs inf-vc-fill-a3 1 inf-fill (g1 (inf-le (add ip0 8) n) bba1 nat)
  (inf-le bc0 63) gs
  (inf-lt (add 56 (inf-mod 8 bc0)) (inf-pow w)) (inf-wlit (add 56 (inf-mod 8 bc0)) w gw (inf-or56 bc0))
 )
 (defvcs inf-vc-fill-end 1 inf-fill (g1 (inf-le (add ip0 8) n) bba1 nat)
  (inf-le (add ip0 (natminus 7 (inf-div8 bc0))) n) (inf-letrans ((add ip0 ((natminus 7 (inf-div8 bc0))))) (add ip0 8) n ((inf-addl ip0 ((natminus 7 (inf-div8 bc0))) 8 (inf-letrans ((natminus 7 (inf-div8 bc0))) 7 8 (inf-suble 7 (inf-div8 bc0)) (idpath false)))) g1)
  (inf-le (add 56 (inf-mod 8 bc0)) 63) (inf-or56 bc0)
  (inf-bits-inv carry (add ip0 (natminus 7 (inf-div8 bc0))) cons0 (add 56 (inf-mod 8 bc0))) (inf-fillw carry ip0 cons0 bc0 (gs) ga)
  (inf-le cons0 cons0) (inf-refl cons0)
 )
 (defvcs inf-vc-fill-w1e 1 inf-fill (g1 (inf-lt n (add ip0 8)))
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
 )
 (defcx inf-fill-w1 inf-fill (g1 (inf-lt n (add ip0 8))) (ip nat) (bc nat) (bb nat) (j1 (inf-le ip n)) (j3 (inf-le bc 63)) (j4 (inf-bits-inv carry ip cons0 bc)) )
 (defvcs inf-vc-fill-end 5 inf-fill-w1 (w1 (inf-lt ip n) g2 (inf-lt 55 bc))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv carry ip cons0 bc) j4
  (inf-le cons0 cons0) (inf-refl cons0)
 )
 (defvcs inf-vc-fill-b2 1 inf-fill-w1 (w1 (inf-lt ip n) g2 (inf-le bc 55))
  (inf-lt ip n) w1
  (inf-lt bc 64) (inf-lelt bc 55 64 g2 (idpath true))
 )
 (defvcs inf-vc-fill-b3 1 inf-fill-w1 (w1 (inf-lt ip n) g2 (inf-le bc 55) bbb2 nat)
  (inf-lt (add ip 1) (inf-pow w)) (inf-lelt ((add ip 1)) n (inf-pow w) (inf-lt1 ip n w1) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))
 )
 (defvcs inf-vc-fill-b4 1 inf-fill-w1 (w1 (inf-lt ip n) g2 (inf-le bc 55) bbb2 nat)
  (inf-lt (add bc 8) (inf-pow w)) (inf-wlit (add bc 8) w gw ((inf-addr bc 55 8 g2)))
 )
 (defvcs inf-vc-fill-w1b 1 inf-fill-w1 (w1 (inf-lt ip n) g2 (inf-le bc 55) bbb2 nat)
  (inf-le (add ip 1) n) (inf-lt1 ip n w1)
  (inf-le (add bc 8) 63) ((inf-addr bc 55 8 g2))
  (inf-bits-inv carry (add ip 1) cons0 (add bc 8)) (inf-fill1b carry ip cons0 bc j4)
  (inf-lt (natminus n (add ip 1)) (natminus n ip)) (inf-subfall1 n ip w1)
 )
 (defvcs inf-vc-fill-end 9 inf-fill-w1 (w1 (inf-le n ip))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv carry ip cons0 bc) j4
  (inf-le cons0 cons0) (inf-refl cons0)
 )
 (defcx inf-take (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (k nat) (gk (inf-le k 13)) )
 (defvcs inf-vc-take-c1 1 inf-take ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
 )
 (defcx inf-take-c1 inf-take (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
 (defvcs inf-vc-take-r1 1 inf-take-c1 (g1 (inf-lt bcc1 k))
  (inf-le ipc1 n) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv carry ipc1 consc1 bcc1) c1e4
  (inf-le cons0 consc1) c1e5
 )
 (defvcs inf-vc-take-d1 1 inf-take-c1 (g1 (inf-le k bcc1))
  (inf-lt k 32) ((inf-lttrans k 16 32 (inf-lelts k 15 (inf-letrans k 13 15 gk (idpath false))) (idpath false)))
  (inf-lt (inf-mod (inf-pow k) bbc1) (inf-pow w)) (inf-powfit ((inf-mod (inf-pow k) bbc1)) k w (inf-masklt bbc1 k) (inf-letrans k 13 w gk (inf-letrans 13 32 w (idpath false) gw)))
 )
 (defvcs inf-vc-take-d2 1 inf-take-c1 (g1 (inf-le k bcc1))
  (inf-lt k 64) (inf-lttrans k 16 64 (inf-lelts k 15 (inf-letrans k 13 15 gk (idpath false))) (idpath false))
 )
 (defvcs inf-vc-take-d3 1 inf-take-c1 (g1 (inf-le k bcc1) bbd2 nat)
  (inf-le k bcc1) g1
  (inf-lt (natminus bcc1 k) (inf-pow w)) (inf-wlit ((natminus bcc1 k)) w gw (inf-letrans ((natminus bcc1 k)) bcc1 63 (inf-suble bcc1 k) c1e3))
 )
 (defvcs inf-vc-take-r2 1 inf-take-c1 (g1 (inf-le k bcc1) bbd2 nat)
  (inf-le ipc1 n) c1e1
  (inf-le (natminus bcc1 k) 63) (inf-sub63 bcc1 k c1e3)
  (inf-bits-inv carry ipc1 (add consc1 k) (natminus bcc1 k)) (inf-take carry ipc1 consc1 bcc1 k g1 c1e4)
  (inf-le cons0 (add consc1 k)) (inf-letrans cons0 consc1 ((add consc1 k)) c1e5 (inf-leaddr consc1 k))
  (inf-le (add cons0 k) (add consc1 k)) (inf-addr cons0 consc1 k c1e5)
  (inf-lt (inf-mod (inf-pow k) bbc1) (inf-pow k)) (inf-masklt bbc1 k)
 )
 (defcx inf-sym (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Cn (pi i nat nat)) (Sy (pi i nat nat)) (Tb (pi i nat nat)) (m nat) (h nat) (root nat) (hc (pi i nat (inf-lt (Cn i) (inf-pow h)))) (hs (pi i nat (inf-lt (Sy i) (inf-pow h)))) (gh (inf-le h 16)) (gm (inf-lt m (inf-pow w))) (gt (inf-le (inf-sum Cn 15 1) m)) (gr (inf-le root 15)) )
 (defvcs inf-vc-sym-c1 1 inf-sym ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
 )
 (defcx inf-sym-c1 inf-sym (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
 (defvcs inf-vc-sym-d1 1 inf-sym-c1 ()
  (inf-lt root 32) ((inf-lttrans root 16 32 (inf-lelts root 15 gr) (idpath false)))
  (inf-lt (inf-mod (inf-pow root) bbc1) (inf-pow root)) (inf-masklt bbc1 root)
 )
 (defvcs inf-vc-sym-w0 1 inf-sym-c1 (ed1 nat g1 (paths nat ed1 0))
  (pi i nat (inf-le ((inf-sb bbc1) i) 1)) (lam i (inf-ltsle (inf-sb bbc1 i) 1 (inf-modlt 1 (inf-shr bbc1 i))))
  (pi i nat (inf-lt (Cn i) (inf-pow h))) hc
  (pi i nat (inf-lt (Sy i) (inf-pow h))) hs
  (inf-le h 16) gh
  (inf-le 31 w) (inf-letrans 31 32 w (idpath false) gw)
  (inf-lt m (inf-pow w)) gm
  (inf-le (inf-sum Cn 15 1) m) gt
 )
 (defvcs inf-vc-sym-w0s 1 inf-sym-c1 (ed1 nat g1 (paths nat ed1 0) xw0 nat)
  (inf-le ipc1 n) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv carry ipc1 consc1 bcc1) c1e4
  (inf-le cons0 consc1) c1e5
 )
 (defcx inf-sym-c3 inf-sym-c1 (ed1 nat) (g1 (paths nat ed1 0)) (xw0 nat) (w0e1 (inf-lt xw0 (inf-pow w))) )
 (defcx inf-sym-c2 inf-sym-c1 (ed1 nat) (ei1 nat) )
 (defvcs inf-vc-sym-d2 1 inf-sym-c2 ()
  (inf-lt 4 64) (idpath true)
 )
 (defvcs inf-vc-sym-d3 1 inf-sym-c2 (syd2 nat)
  (inf-lt (inf-mod 16 ei1) (inf-pow w)) (inf-wlit ((inf-mod 16 ei1)) w gw (inf-letrans ((inf-mod 16 ei1)) 15 63 ((inf-ltsle ((inf-mod 16 ei1)) 15 (inf-modlt 15 ei1))) (idpath false)))
 )
 (defvcs inf-vc-sym-r1 1 inf-sym-c2 (syd2 nat g2 (inf-lt bcc1 (inf-mod 16 ei1)))
  (inf-le ipc1 n) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv carry ipc1 consc1 bcc1) c1e4
  (inf-le cons0 consc1) c1e5
 )
 (defvcs inf-vc-sym-d4 1 inf-sym-c2 (syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1))
  (inf-lt (inf-mod 16 ei1) 64) (inf-lelt ((inf-mod 16 ei1)) 15 64 ((inf-ltsle ((inf-mod 16 ei1)) 15 (inf-modlt 15 ei1))) (idpath true))
 )
 (defvcs inf-vc-sym-d5 1 inf-sym-c2 (syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat)
  (inf-le (inf-mod 16 ei1) bcc1) g2
  (inf-lt (natminus bcc1 (inf-mod 16 ei1)) (inf-pow w)) (inf-wlit ((natminus bcc1 ((inf-mod 16 ei1)))) w gw (inf-letrans ((natminus bcc1 ((inf-mod 16 ei1)))) bcc1 63 (inf-suble bcc1 ((inf-mod 16 ei1))) c1e3))
 )
 (defvcs inf-vc-sym-r2 1 inf-sym-c2 (syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat)
  (inf-le ipc1 n) c1e1
  (inf-le (natminus bcc1 (inf-mod 16 ei1)) 63) (inf-sub63 bcc1 ((inf-mod 16 ei1)) c1e3)
  (inf-bits-inv carry ipc1 (add consc1 (inf-mod 16 ei1)) (natminus bcc1 (inf-mod 16 ei1))) (inf-take carry ipc1 consc1 bcc1 ((inf-mod 16 ei1)) g2 c1e4)
  (inf-le cons0 (add consc1 (inf-mod 16 ei1))) (inf-letrans cons0 consc1 (add consc1 ((inf-mod 16 ei1))) c1e5 (inf-leaddr consc1 ((inf-mod 16 ei1))))
 )
 (defcx inf-stored (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv 0 ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) )
 (defvcs inf-vc-stored-d1 1 inf-stored ()
  (inf-lt (inf-mod 8 bc0) (inf-pow w)) (inf-wlit ((inf-mod 8 bc0)) w gw (inf-letrans ((inf-mod 8 bc0)) 8 63 ((inf-ltle ((inf-mod 8 bc0)) 8 (inf-modlt 7 bc0))) (idpath false)))
 )
 (defvcs inf-vc-stored-d2 1 inf-stored ()
  (inf-lt (inf-mod 8 bc0) 64) (inf-lttrans ((inf-mod 8 bc0)) 8 64 (inf-modlt 7 bc0) (idpath false))
 )
 (defvcs inf-vc-stored-d3 1 inf-stored (bbd2 nat)
  (inf-le (inf-mod 8 bc0) bc0) (inf-modle8 bc0)
  (inf-lt (natminus bc0 (inf-mod 8 bc0)) (inf-pow w)) (inf-wlit ((natminus bc0 ((inf-mod 8 bc0)))) w gw ((inf-letrans ((natminus bc0 ((inf-mod 8 bc0)))) bc0 63 (inf-suble bc0 ((inf-mod 8 bc0))) gs)))
 )
 (defvcs inf-vc-stored-d5 1 inf-stored (bbd2 nat)
  (inf-le (inf-div8 (natminus bc0 (inf-mod 8 bc0))) ip0) ((inf-pos ip0 ((add cons0 ((inf-mod 8 bc0)))) ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))) ((inf-dropinv ip0 cons0 bc0 ga))))
  (inf-lt (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) (inf-pow w)) (inf-lelt ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) n (inf-pow w) ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))
 )
 (defvcs inf-vc-stored-i1 1 inf-stored (bbd2 nat)
  (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) (inf-pow w)) ((inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn))
 )
 (defvcs inf-vc-stored-d6 1 inf-stored (bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n))
  (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 2) n) (inf-letrans (add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2) ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) n (inf-addl ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2 4 (idpath false)) g1)
 )
 (defvcs inf-vc-stored-d8 1 inf-stored (bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat)
  (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 2) (inf-pow w)) (inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn)
  (inf-le (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 2) 2) n) (inf-letr ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (add (add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2) 2) n (pathsinv0 nat (add (add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2) 2) ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (natplusassoc ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2 2)) g1)
 )
 (defvcs inf-vc-stored-i3 1 inf-stored (bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat nld8 nat g2 unit)
  (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) (inf-pow w)) ((inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn))
  (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) g1
 )
 (defvcs inf-vc-stored-i4 1 inf-stored (bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat nld8 nat g2 unit g3 (inf-le lnd7 (natminus n (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4))))
  (inf-le op0 cap) gop
 )
 (defvcs inf-vc-stored-m1 1 inf-stored (bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat nld8 nat g2 unit g3 (inf-le lnd7 (natminus n (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4))) g4 (inf-le lnd7 (natminus cap op0)) g5 (inf-lt 0 out))
  (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) (inf-pow w)) ((inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn))
  (inf-le (add op0 lnd7) oc) (inf-letl (add op0 (lnd7)) cap oc (pathsinv0 nat oc cap (go g5)) ((inf-roomle op0 cap (lnd7) g4 gop)))
  (inf-le (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) n) ((inf-roomle ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) n (lnd7) g3 g1))
 )
 (defcx inf-stored-c1 inf-stored (bbd2 nat) (g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n)) (x16d6 nat) (lnd7 nat) (nld8 nat) (g2 unit) (g3 (inf-le lnd7 (natminus n (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4)))) (g4 (inf-le lnd7 (natminus cap op0))) )
 (defvcs inf-vc-stored-d9 1 inf-stored-c1 ()
  (inf-lt (add op0 lnd7) (inf-pow w)) (inf-lelt (add op0 (lnd7)) cap (inf-pow w) ((inf-roomle op0 cap (lnd7) g4 gop)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
 )
 (defvcs inf-vc-stored-d10 1 inf-stored-c1 ()
  (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) (inf-pow w)) ((inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn))
  (inf-lt (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) (inf-pow w)) (inf-lelt ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7))) n (inf-pow w) ((inf-roomle ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) n (lnd7) g3 g1)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))
 )
 (defvcs inf-vc-stored-d12 1 inf-stored-c1 (bbd11 nat)
  (inf-lt 0 (inf-pow w)) (inf-powpos w)
 )
 (defvcs inf-vc-stored-r5 1 inf-stored-c1 (bbd11 nat)
  (inf-le (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) n) ((inf-roomle ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) n (lnd7) g3 g1))
  (inf-le 0 63) (idpath false)
  (inf-bits-inv 0 (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) (inf-by8 (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7)) 0) (pathsinv0 nat (add (inf-by8 ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7)))) 0) (inf-by8 ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7)))) (natplusr0 (inf-by8 ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7))))))
  (inf-le cons0 (inf-by8 (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7))) (inf-storedc ip0 cons0 ((inf-mod 8 bc0)) ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))) 4 (lnd7) ((inf-dropinv ip0 cons0 bc0 ga)))
  (inf-le (add op0 lnd7) cap) ((inf-roomle op0 cap (lnd7) g4 gop))
  (inf-le op0 (add op0 lnd7)) (inf-leaddr op0 (lnd7))
 )
 (defcx inf-copy (w nat) (l nat) (d nat) (op nat) (out nat) (oc nat) (cap nat) (nd nat) (gw (inf-le 32 w)) (gd (inf-lt d (inf-pow w))) (ga (inf-le d (add op nd))) (gb (inf-le (add op l) cap)) (gz (inf-lt 0 out)) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) )
 (defvcs inf-vc-copy-s1 1 inf-copy (g1 (inf-lt op d))
  (inf-lt l (inf-pow w)) ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))
 )
 (defvcs inf-vc-copy-j1 1 inf-copy (g1 (inf-lt op d))
  (inf-le op d) (inf-letrans op d d (inf-ltle op d g1) (inf-refl d))
 )
 (defvcs inf-vc-copy-s2 1 inf-copy (g1 (inf-lt op d) g2 (inf-lt (natminus d op) l))
  (inf-le op d) (inf-letrans op d d (inf-ltle op d g1) (inf-refl d))
  (inf-lt (natminus d op) (inf-pow w)) (inf-lelt (natminus d op) d (inf-pow w) (inf-suble d op) gd)
 )
 (defvcs inf-vc-copy-j1j 1 inf-copy (g1 (inf-lt op d) g2 (inf-lt (natminus d op) l))
  (paths nat (natminus d op) (inf-h d op l)) (inf-htt d op l g2)
 )
 (defvcs inf-vc-copy-j1j 2 inf-copy (g1 (inf-lt op d) g2 (inf-le l (natminus d op)))
  (paths nat l (inf-h d op l)) (inf-hff d op l g2)
 )
 (defcx inf-copy-c2 inf-copy (g1 (inf-lt op d)) (mj1 nat) (f1 (paths nat mj1 (inf-h d op l))) )
 (defvcs inf-vc-copy-m1 1 inf-copy-c2 ()
  (inf-le op d) (inf-letrans op d d (inf-ltle op d g1) (inf-refl d))
  (inf-le (natminus d op) nd) (inf-dnowrap d op nd ga)
  (inf-le (add op mj1) oc) (inf-letrans (add op mj1) (add op l) oc (inf-addl op mj1 l ((inf-letr (inf-h d op l) mj1 l ((pathsinv0 nat mj1 (inf-h d op l) f1)) (inf-hlel d op l)))) ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))
  (inf-le (add (natminus nd (natminus d op)) mj1) nd) (inf-letr (add (natminus nd (natminus d op)) (inf-h d op l)) (add (natminus nd (natminus d op)) mj1) nd (maponpaths nat nat (lam z (add (natminus nd (natminus d op)) z)) (inf-h d op l) mj1 ((pathsinv0 nat mj1 (inf-h d op l) f1))) (inf-dr d op l nd ga))
 )
 (defvcs inf-vc-copy-w1e 1 inf-copy-c2 ()
  (inf-le mj1 mj1) (inf-refl mj1)
 )
 (defcx inf-copy-c2-w1 inf-copy-c2 (k nat) (a1 (inf-le mj1 k)) )
 (defvcs inf-vc-copy-p1 1 inf-copy-c2-w1 (w1 (inf-lt k l))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op l) cap (inf-ltle (add op k) (add op l) (inf-ltaddl op k l w1)) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
  (inf-lt (add op k) oc) (inf-cw op k l oc w1 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))
  (inf-le d (add op k)) (inf-dknowrap d op l k (inf-ltle op d g1) (inf-letr mj1 (inf-h d op l) k f1 a1) w1)
  (inf-lt (natminus (add op k) d) oc) (inf-lelt (natminus (add op k) d) (add op k) oc (inf-suble (add op k) d) (inf-cw op k l oc w1 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))))
 )
 (defvcs inf-vc-copy-w1b 1 inf-copy-c2-w1 (w1 (inf-lt k l))
  (inf-lt (succ k) (inf-pow w)) (inf-lelt (succ k) l (inf-pow w) (inf-ltsu k l w1) ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))
  (inf-le mj1 (succ k)) (inf-letrans mj1 k (succ k) a1 (inf-ltle k (succ k) (inf-ltself k)))
  (inf-lt (natminus l (succ k)) (natminus l k)) (inf-subfall l k w1)
 )
 (defvcs inf-vc-copy-w2e 1 inf-copy (g1 (inf-le d op) g3 (inf-le 8 d))
  (inf-le 0 l) (idpath false)
 )
 (defcx inf-copy-w2 inf-copy (g1 (inf-le d op)) (g3 (inf-le 8 d)) (k nat) (a2 (inf-le k l)) )
 (defvcs inf-vc-copy-w2h 1 inf-copy-w2 ()
  (inf-lt (add k 8) (inf-pow w)) (inf-nfit k 8 cap w (inf-letrans k l cap a2 (inf-letrans l (add op l) cap (inf-leaddl l op) gb)) (idpath false) gcap)
 )
 (defvcs inf-vc-copy-p2 1 inf-copy-w2 (w2 (inf-le (add k 8) l))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) (add op l) (inf-pow w) (inf-addl op k l (inf-letrans k (add k 8) l (inf-leaddr k 8) w2)) (inf-lelt (add op l) cap (inf-pow w) gb ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))
  (inf-le (add (add op k) 8) oc) (inf-letrans (add (add op k) 8) (add op l) oc (inf-letr (add op (add k 8)) (add (add op k) 8) (add op l) (pathsinv0 nat (add (add op k) 8) (add op (add k 8)) (natplusassoc op k 8)) (inf-addl op (add k 8) l w2)) ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))
  (inf-le d (add op k)) ((inf-letrans d op (add op k) g1 (inf-leaddr op k)))
  (inf-le (add (natminus (add op k) d) 8) oc) (inf-letrans (add (natminus (add op k) d) 8) (add (add op k) 8) oc (inf-addr (natminus (add op k) d) (add op k) 8 (inf-suble (add op k) d)) (inf-letrans (add (add op k) 8) (add op l) oc (inf-letr (add op (add k 8)) (add (add op k) 8) (add op l) (pathsinv0 nat (add (add op k) 8) (add op (add k 8)) (natplusassoc op k 8)) (inf-addl op (add k 8) l w2)) ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))))
 )
 (defvcs inf-vc-copy-s3 1 inf-copy-w2 (w2 (inf-le (add k 8) l))
  (inf-lt (add k 8) (inf-pow w)) (inf-nfit k 8 cap w (inf-letrans k l cap a2 (inf-letrans l (add op l) cap (inf-leaddl l op) gb)) (idpath false) gcap)
 )
 (defvcs inf-vc-copy-w2b 1 inf-copy-w2 (w2 (inf-le (add k 8) l))
  (inf-le (add k 8) l) w2
  (inf-lt (natminus l (add k 8)) (natminus l k)) (inf-subby k l 8 (inf-lttrans k (add k 8) l (inf-ltaddpos k 8 (idpath true)) w2) (idpath true))
 )
 (defvcs inf-vc-copy-j2j 1 inf-copy-w2 (w2 (inf-lt l (add k 8)))
  (inf-le k l) a2
 )
 (defvcs inf-vc-copy-j2j 2 inf-copy (g1 (inf-le d op) g3 unit)
  (inf-le 0 l) (idpath false)
 )
 (defcx inf-copy-c1 inf-copy (g1 (inf-le d op)) (kj2 nat) (f3 (inf-le kj2 l)) )
 (defvcs inf-vc-copy-w3e 1 inf-copy-c1 ()
  (inf-le kj2 l) f3
 )
 (defcx inf-copy-c1-w3 inf-copy-c1 (k nat) (a3 (inf-le k l)) )
 (defvcs inf-vc-copy-p3 1 inf-copy-c1-w3 (w3 (inf-lt k l))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op l) cap (inf-ltle (add op k) (add op l) (inf-ltaddl op k l w3)) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
  (inf-lt (add op k) oc) (inf-cw op k l oc w3 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))
  (inf-le d (add op k)) ((inf-letrans d op (add op k) g1 (inf-leaddr op k)))
  (inf-lt (natminus (add op k) d) oc) (inf-lelt (natminus (add op k) d) (add op k) oc (inf-suble (add op k) d) (inf-cw op k l oc w3 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))))
 )
 (defvcs inf-vc-copy-s4 1 inf-copy-c1-w3 (w3 (inf-lt k l))
  (inf-lt (add k 1) (inf-pow w)) (inf-lelt (add k 1) l (inf-pow w) (inf-lt1 k l w3) ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))
 )
 (defvcs inf-vc-copy-w3b 1 inf-copy-c1-w3 (w3 (inf-lt k l))
  (inf-le (add k 1) l) (inf-lt1 k l w3)
  (inf-lt (natminus l (add k 1)) (natminus l k)) (inf-subfall1 l k w3)
 )
 (defcx inf-fixed (w nat) (u nat) (gw (inf-le 32 w)) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) )
 (defvcs inf-vc-fixed-w1e 1 inf-fixed ()
  (inf-le 0 288) (idpath false)
  (pi k nat (inf-le (inf-zero k) 15)) (lam k (idpath false))
 )
 (defcx inf-fixed-w1 inf-fixed (i nat) (Lz (pi j nat nat)) (a1 (inf-le i 288)) (a2 (pi k nat (inf-le (Lz k) 15))) )
 (defvcs inf-vc-fixed-s0 1 inf-fixed-w1 (w1 (inf-lt i 288))
  (inf-lt 8 (inf-pow w)) (inf-wlit 8 w gw (idpath false))
 )
 (defvcs inf-vc-fixed-s1 1 inf-fixed-w1 (w1 (inf-lt i 288) g1 (inf-le 144 i))
  (inf-lt 9 (inf-pow w)) (inf-wlit 9 w gw (idpath false))
 )
 (defvcs inf-vc-fixed-j1j 1 inf-fixed-w1 (w1 (inf-lt i 288) g1 (inf-le 144 i))
  (inf-le 9 15) (idpath false)
 )
 (defvcs inf-vc-fixed-j1j 2 inf-fixed-w1 (w1 (inf-lt i 288) g1 (inf-lt i 144))
  (inf-le 8 15) (idpath false)
 )
 (defcx inf-fixed-c3 inf-fixed-w1 (w1 (inf-lt i 288)) (vj1 nat) (b1 (inf-le vj1 15)) )
 (defvcs inf-vc-fixed-s2 1 inf-fixed-c3 (g2 (inf-le 256 i))
  (inf-lt 7 (inf-pow w)) (inf-wlit 7 w gw (idpath false))
 )
 (defvcs inf-vc-fixed-j2j 1 inf-fixed-c3 (g2 (inf-le 256 i))
  (inf-le 7 15) (idpath false)
 )
 (defvcs inf-vc-fixed-j2j 2 inf-fixed-c3 (g2 (inf-lt i 256))
  (inf-le vj1 15) b1
 )
 (defcx inf-fixed-c4 inf-fixed-c3 (vj2 nat) (b2 (inf-le vj2 15)) )
 (defvcs inf-vc-fixed-s3 1 inf-fixed-c4 (g3 (inf-le 280 i))
  (inf-lt 8 (inf-pow w)) (inf-wlit 8 w gw (idpath false))
 )
 (defvcs inf-vc-fixed-j3j 1 inf-fixed-c4 (g3 (inf-le 280 i))
  (inf-le 8 15) (idpath false)
 )
 (defvcs inf-vc-fixed-j3j 2 inf-fixed-c4 (g3 (inf-lt i 280))
  (inf-le vj2 15) b2
 )
 (defcx inf-fixed-c5 inf-fixed-c4 (vj3 nat) (b3 (inf-le vj3 15)) )
 (defvcs inf-vc-fixed-s4 1 inf-fixed-c5 ()
  (inf-lt i 320) (inf-lttrans i 288 320 w1 (idpath false))
  (inf-lt vj3 (inf-pow w)) (inf-wlit vj3 w gw (inf-letrans vj3 15 63 b3 (idpath false)))
 )
 (defvcs inf-vc-fixed-w1b 1 inf-fixed-c5 ()
  (inf-lt (succ i) (inf-pow w)) (inf-lelt (succ i) 288 (inf-pow w) (inf-ltsu i 288 w1) (inf-wfit288 w gw))
  (inf-le (succ i) 288) (inf-ltsu i 288 w1)
  (pi k nat (inf-le ((inf-upd Lz i vj3) k) 15)) (inf-updle Lz i vj3 15 a2 b3)
  (inf-lt (natminus 288 (succ i)) (natminus 288 i)) (inf-subfall 288 i w1)
 )
 (defvcs inf-vc-fixed-c1 1 inf-fixed-w1 (w1 (inf-le 288 i))
  (pi k nat g (inf-lt k 288) (inf-le (Lz k) 15)) (lam k g (a2 k))
  (inf-lt 288 q) ((inf-lttrans 288 320 q (idpath true) (inf-ltle 320 q gq2)))
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-le (inf-pow h) (inf-pow w)) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
  (inf-le LROOT 15) gl
  (inf-le 32 w) gw
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
 )
 (defcx inf-fixed-c1 inf-fixed-w1 (w1 (inf-le 288 i)) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (c1e1 (pi z nat (inf-lt (Lcc1 z) (inf-pow h)))) (c1e2 (pi z nat (inf-lt (Lsc1 z) (inf-pow h)))) (c1e3 (inf-le (inf-sum Lcc1 15 1) 288)) )
 (defvcs inf-vc-fixed-w2e 1 inf-fixed-c1 ()
  (inf-le 0 30) (idpath false)
  (pi k nat (inf-le (Lz k) 15)) a2
 )
 (defcx inf-fixed-c1-w2 inf-fixed-c1 (i nat) (Lz (pi j nat nat)) (a3 (inf-le i 30)) (a4 (pi k nat (inf-le (Lz k) 15))) )
 (defvcs inf-vc-fixed-s5 1 inf-fixed-c1-w2 (w2 (inf-lt i 30))
  (inf-lt i 320) (inf-lttrans i 30 320 w2 (idpath false))
  (inf-lt 5 (inf-pow w)) (inf-wlit 5 w gw (idpath false))
 )
 (defvcs inf-vc-fixed-w2b 1 inf-fixed-c1-w2 (w2 (inf-lt i 30))
  (inf-lt (succ i) (inf-pow w)) (inf-wlit (succ i) w gw (inf-letrans (succ i) 30 63 (inf-ltsu i 30 w2) (idpath false)))
  (inf-le (succ i) 30) (inf-ltsu i 30 w2)
  (pi k nat (inf-le ((inf-upd Lz i 5) k) 15)) (inf-updle Lz i 5 15 a4 (idpath false))
  (inf-lt (natminus 30 (succ i)) (natminus 30 i)) (inf-subfall 30 i w2)
 )
 (defvcs inf-vc-fixed-c2 1 inf-fixed-c1-w2 (w2 (inf-le 30 i))
  (pi k nat g (inf-lt k 30) (inf-le (Lz k) 15)) (lam k g (a4 k))
  (inf-lt 30 q) ((inf-lttrans 30 320 q (idpath true) (inf-ltle 320 q gq2)))
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-le (inf-pow h) (inf-pow w)) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
  (inf-le DROOT 15) gd
  (inf-le 32 w) gw
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
 )
 (defcx inf-fixed-c2 inf-fixed-c1-w2 (w2 (inf-le 30 i)) (Dcc2 (pi j nat nat)) (Dsc2 (pi j nat nat)) (Dtc2 (pi j nat nat)) (c2e1 (pi z nat (inf-lt (Dcc2 z) (inf-pow h)))) (c2e2 (pi z nat (inf-lt (Dsc2 z) (inf-pow h)))) (c2e3 (inf-le (inf-sum Dcc2 15 1) 30)) )
 (defvcs inf-vc-fixed-end 1 inf-fixed-c2 ()
  (pi k nat (inf-lt (Lcc1 k) (inf-pow h))) c1e1
  (pi k nat (inf-lt (Lsc1 k) (inf-pow h))) c1e2
  (inf-le (inf-sum Lcc1 15 1) 288) c1e3
  (inf-le 288 288) (idpath false)
  (pi k nat (inf-lt (Dcc2 k) (inf-pow h))) c2e1
  (pi k nat (inf-lt (Dsc2 k) (inf-pow h))) c2e2
  (inf-le (inf-sum Dcc2 15 1) 30) c2e3
  (inf-le 30 32) (idpath false)
 )
 (defcx inf-dyn (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Ob (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) )
 (defvcs inf-vc-dyn-t1 1 inf-dyn ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le 5 13) (idpath false)
 )
 (defcx inf-dyn-c1 inf-dyn (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons0 const1)) (t1e6 (inf-le (add cons0 5) const1)) (t1e7 (inf-lt xt1 (inf-pow 5))) )
 (defvcs inf-vc-dyn-s1 1 inf-dyn-c1 ()
  (inf-lt (add xt1 257) (inf-pow w)) (inf-lelt ((add xt1 257)) 288 (inf-pow w) ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) (inf-wfit288 w gw))
 )
 (defvcs inf-vc-dyn-t2 1 inf-dyn-c1 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le 5 13) (idpath false)
 )
 (defcx inf-dyn-c2 inf-dyn-c1 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le const1 const2)) (t2e6 (inf-le (add const1 5) const2)) (t2e7 (inf-lt xt2 (inf-pow 5))) )
 (defvcs inf-vc-dyn-s2 1 inf-dyn-c2 ()
  (inf-lt (add xt2 1) (inf-pow w)) (inf-wlit ((add xt2 1)) w gw (inf-letrans ((add xt2 1)) 32 63 ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))) (idpath false)))
 )
 (defvcs inf-vc-dyn-t3 1 inf-dyn-c2 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le 4 13) (idpath false)
 )
 (defcx inf-dyn-c3 inf-dyn-c2 (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e6 (inf-le (add const2 4) const3)) (t3e7 (inf-lt xt3 (inf-pow 4))) )
 (defvcs inf-vc-dyn-s3 1 inf-dyn-c3 ()
  (inf-lt (add xt3 4) (inf-pow w)) (inf-wlit ((add xt3 4)) w gw (inf-letrans ((add xt3 4)) 19 63 ((inf-addr xt3 15 4 (inf-ltsle xt3 15 t3e7))) (idpath false)))
 )
 (defvcs inf-vc-dyn-w1e 1 inf-dyn-c3 ()
  (inf-le 0 (add xt3 4)) (idpath false)
  (pi k nat (inf-le (inf-zero k) 15)) (lam k (idpath false))
  (inf-le (add xt3 4) 19) ((inf-addr xt3 15 4 (inf-ltsle xt3 15 t3e7)))
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (inf-le cons0 const3) ((inf-letrans cons0 const2 const3 (inf-letrans cons0 const1 const2 t1e5 t2e5) t3e5))
 )
 (defcx inf-dyn-c3-w1 inf-dyn-c3 (i nat) (Cl (pi j nat nat)) (x nat) (ip nat) (bc nat) (bb nat) (cons nat) (a1 (inf-le i (add xt3 4))) (a2 (pi k nat (inf-le (Cl k) 15))) (a3 (inf-le (add xt3 4) 19)) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) )
 (defvcs inf-vc-dyn-t4 1 inf-dyn-c3-w1 (w1 (inf-lt i (add xt3 4)))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le 3 13) (idpath false)
 )
 (defcx inf-dyn-c14 inf-dyn-c3-w1 (w1 (inf-lt i (add xt3 4))) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le cons const4)) (t4e6 (inf-le (add cons 3) const4)) (t4e7 (inf-lt xt4 (inf-pow 3))) )
 (defvcs inf-vc-dyn-s4 1 inf-dyn-c14 ()
  (inf-lt i 19) (inf-lttrans i ((add xt3 4)) 19 w1 a3)
  (inf-lt (Ob i) 19) (hord i (inf-lttrans i ((add xt3 4)) 19 w1 a3))
  (inf-lt xt4 (inf-pow w)) (inf-lttrans xt4 8 (inf-pow w) t4e7 (inf-powle 3 w (inf-letrans 3 32 w (idpath false) gw)))
 )
 (defvcs inf-vc-dyn-w1b 1 inf-dyn-c14 ()
  (inf-lt (succ i) (inf-pow w)) (inf-wlit (succ i) w gw (inf-letrans (succ i) 19 63 (inf-ltsu i 19 (inf-lttrans i ((add xt3 4)) 19 w1 a3)) (idpath false)))
  (inf-le (succ i) (add xt3 4)) (inf-ltsu i ((add xt3 4)) w1)
  (pi k nat (inf-le ((inf-upd Cl (Ob i) xt4) k) 15)) (inf-updle Cl (Ob i) xt4 15 a2 (inf-letrans xt4 8 15 (inf-ltle xt4 8 t4e7) (idpath false)))
  (inf-le (add xt3 4) 19) a3
  (inf-le ipt4 n) t4e1
  (inf-le bct4 63) t4e3
  (inf-bits-inv carry ipt4 const4 bct4) t4e4
  (inf-le cons0 const4) (inf-letrans cons0 cons const4 r5 t4e5)
  (inf-lt (natminus (add xt3 4) (succ i)) (natminus (add xt3 4) i)) (inf-subfall ((add xt3 4)) i w1)
 )
 (defvcs inf-vc-dyn-c2 1 inf-dyn-c3-w1 (w1 (inf-le (add xt3 4) i))
  (pi k nat g (inf-lt k 19) (inf-le (Cl k) 15)) (lam k g (a2 k))
  (inf-lt 19 q) (inf-lttrans 19 320 q (idpath true) ((inf-ltle 320 q gq2)))
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-le (inf-pow h) (inf-pow w)) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
  (inf-le CROOT 15) gc
  (inf-le 32 w) gw
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
 )
 (defcx inf-dyn-c4 inf-dyn-c3-w1 (w1 (inf-le (add xt3 4) i)) (Ccc2 (pi j nat nat)) (Csc2 (pi j nat nat)) (Ctc2 (pi j nat nat)) (c2e1 (pi z nat (inf-lt (Ccc2 z) (inf-pow h)))) (c2e2 (pi z nat (inf-lt (Csc2 z) (inf-pow h)))) (c2e3 (inf-le (inf-sum Ccc2 15 1) 19)) )
 (defvcs inf-vc-dyn-s5 1 inf-dyn-c4 ()
  (inf-lt (add (add xt1 257) (add xt2 1)) (inf-pow w)) (inf-lelt (add ((add xt1 257)) ((add xt2 1))) 320 (inf-pow w) ((inf-add2 ((add xt1 257)) 288 ((add xt2 1)) 32 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))))) ((inf-lelt 320 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-dyn-s5b 1 inf-dyn-c4 ()
  (inf-lt 0 (inf-pow w)) (inf-wlit 0 w gw (idpath false))
 )
 (defvcs inf-vc-dyn-w2e 1 inf-dyn-c4 ()
  (inf-le 0 15) (idpath false)
  (pi j nat (inf-le (inf-zero j) 15)) (lam j (idpath false))
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le cons0 cons) r5
 )
 (defcx inf-dyn-c4-w2 inf-dyn-c4 (i nat) (Lz (pi j nat nat)) (x nat) (ip nat) (bc nat) (bb nat) (cons nat) (prev nat) (b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) )
 (defvcs inf-vc-dyn-t5 1 inf-dyn-c4-w2 (w2 (inf-lt i (add (add xt1 257) (add xt2 1))))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (pi i nat (inf-lt (Ccc2 i) (inf-pow h))) c2e1
  (pi i nat (inf-lt (Csc2 i) (inf-pow h))) c2e2
  (inf-le h 16) gh
  (inf-lt 19 (inf-pow w)) (inf-wlit 19 w gw (idpath false))
  (inf-le (inf-sum Ccc2 15 1) 19) c2e3
  (inf-le CROOT 15) gc
 )
 (defcx inf-dyn-c5 inf-dyn-c4-w2 (w2 (inf-lt i (add (add xt1 257) (add xt2 1)))) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (syt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv carry ipt5 const5 bct5)) (t5e5 (inf-le cons const5)) )
 (defvcs inf-vc-dyn-s6 1 inf-dyn-c5 (g1 (inf-lt syt5 16))
  (inf-lt 1 (inf-pow w)) (inf-wlit 1 w gw (idpath false))
 )
 (defvcs inf-vc-dyn-s7 1 inf-dyn-c5 (g1 (inf-lt syt5 16))
  (inf-lt syt5 (inf-pow w)) (inf-wlit syt5 w gw (inf-letrans syt5 16 63 (inf-ltle syt5 16 g1) (idpath false)))
 )
 (defvcs inf-vc-dyn-j1j 1 inf-dyn-c5 (g1 (inf-lt syt5 16))
  (inf-lt 0 1) (idpath true)
  (inf-le 1 138) (idpath false)
  (inf-le syt5 15) (inf-ltsle syt5 15 g1)
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv carry ipt5 const5 bct5) t5e4
  (inf-le cons0 const5) (inf-letrans cons0 cons const5 r5 t5e5)
 )
 (defvcs inf-vc-dyn-t6 1 inf-dyn-c5 (g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv carry ipt5 const5 bct5) t5e4
  (inf-le 2 13) (idpath false)
 )
 (defcx inf-dyn-c11 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-le syt5 16)) (ipt6 nat) (bct6 nat) (bbt6 nat) (const6 nat) (xt6 nat) (t6e1 (inf-le ipt6 n)) (t6e3 (inf-le bct6 63)) (t6e4 (inf-bits-inv carry ipt6 const6 bct6)) (t6e5 (inf-le const5 const6)) (t6e6 (inf-le (add const5 2) const6)) (t6e7 (inf-lt xt6 (inf-pow 2))) )
 (defvcs inf-vc-dyn-s8 1 inf-dyn-c11 ()
  (inf-lt (add xt6 3) (inf-pow w)) (inf-wlit (add xt6 3) w gw (inf-letrans (add xt6 3) 6 63 ((inf-addr xt6 3 3 (inf-ltsle xt6 3 t6e7))) (idpath false)))
 )
 (defvcs inf-vc-dyn-s9 1 inf-dyn-c11 ()
  (inf-lt prev (inf-pow w)) (inf-wlit prev w gw (inf-letrans prev 15 63 b1 (idpath false)))
 )
 (defvcs inf-vc-dyn-j2j 1 inf-dyn-c11 ()
  (inf-lt 0 (add xt6 3)) (inf-pos3 xt6 3 (idpath true))
  (inf-le (add xt6 3) 138) (inf-letrans (add xt6 3) 6 138 ((inf-addr xt6 3 3 (inf-ltsle xt6 3 t6e7))) (idpath false))
  (inf-le prev 15) b1
  (inf-le ipt6 n) t6e1
  (inf-le bct6 63) t6e3
  (inf-bits-inv carry ipt6 const6 bct6) t6e4
  (inf-le cons0 const6) (inf-letrans cons0 const5 const6 (inf-letrans cons0 cons const5 r5 t5e5) t6e5)
 )
 (defvcs inf-vc-dyn-t7 1 inf-dyn-c5 (g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv carry ipt5 const5 bct5) t5e4
  (inf-le 3 13) (idpath false)
 )
 (defcx inf-dyn-c10 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-lt 16 syt5)) (g4 (inf-le syt5 17)) (ipt7 nat) (bct7 nat) (bbt7 nat) (const7 nat) (xt7 nat) (t7e1 (inf-le ipt7 n)) (t7e3 (inf-le bct7 63)) (t7e4 (inf-bits-inv carry ipt7 const7 bct7)) (t7e5 (inf-le const5 const7)) (t7e6 (inf-le (add const5 3) const7)) (t7e7 (inf-lt xt7 (inf-pow 3))) )
 (defvcs inf-vc-dyn-s10 1 inf-dyn-c10 ()
  (inf-lt (add xt7 3) (inf-pow w)) (inf-wlit (add xt7 3) w gw (inf-letrans (add xt7 3) 10 63 ((inf-addr xt7 7 3 (inf-ltsle xt7 7 t7e7))) (idpath false)))
 )
 (defvcs inf-vc-dyn-j3j 1 inf-dyn-c10 ()
  (inf-lt 0 (add xt7 3)) (inf-pos3 xt7 3 (idpath true))
  (inf-le (add xt7 3) 138) (inf-letrans (add xt7 3) 10 138 ((inf-addr xt7 7 3 (inf-ltsle xt7 7 t7e7))) (idpath false))
  (inf-le ipt7 n) t7e1
  (inf-le bct7 63) t7e3
  (inf-bits-inv carry ipt7 const7 bct7) t7e4
  (inf-le cons0 const7) (inf-letrans cons0 const5 const7 (inf-letrans cons0 cons const5 r5 t5e5) t7e5)
 )
 (defvcs inf-vc-dyn-t8 1 inf-dyn-c5 (g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv carry ipt5 const5 bct5) t5e4
  (inf-le 7 13) (idpath false)
 )
 (defcx inf-dyn-c9 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-lt 16 syt5)) (g4 (inf-lt 17 syt5)) (ipt8 nat) (bct8 nat) (bbt8 nat) (const8 nat) (xt8 nat) (t8e1 (inf-le ipt8 n)) (t8e3 (inf-le bct8 63)) (t8e4 (inf-bits-inv carry ipt8 const8 bct8)) (t8e5 (inf-le const5 const8)) (t8e6 (inf-le (add const5 7) const8)) (t8e7 (inf-lt xt8 (inf-pow 7))) )
 (defvcs inf-vc-dyn-s11 1 inf-dyn-c9 ()
  (inf-lt (add xt8 11) (inf-pow w)) (inf-lelt (add xt8 11) 512 (inf-pow w) (inf-letrans (add xt8 11) 138 512 ((inf-addr xt8 127 11 (inf-ltsle xt8 127 t8e7))) (idpath false)) (inf-lttrans 512 1024 (inf-pow w) (idpath true) (inf-powle 10 w (inf-letrans 10 32 w (idpath false) gw))))
 )
 (defvcs inf-vc-dyn-j3j 7 inf-dyn-c9 ()
  (inf-lt 0 (add xt8 11)) (inf-pos3 xt8 11 (idpath true))
  (inf-le (add xt8 11) 138) ((inf-addr xt8 127 11 (inf-ltsle xt8 127 t8e7)))
  (inf-le ipt8 n) t8e1
  (inf-le bct8 63) t8e3
  (inf-bits-inv carry ipt8 const8 bct8) t8e4
  (inf-le cons0 const8) (inf-letrans cons0 const5 const8 (inf-letrans cons0 cons const5 r5 t5e5) t8e5)
 )
 (defcx inf-dyn-c8 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-lt 16 syt5)) (xj3 nat) (ipj3 nat) (bcj3 nat) (bbj3 nat) (consj3 nat) (rrj3 nat) (f1 (inf-lt 0 rrj3)) (f2 (inf-le rrj3 138)) (r1 (inf-le ipj3 n)) (r3 (inf-le bcj3 63)) (r4 (inf-bits-inv carry ipj3 consj3 bcj3)) (r5 (inf-le cons0 consj3)) )
 (defvcs inf-vc-dyn-s12 1 inf-dyn-c8 ()
  (inf-lt 0 (inf-pow w)) (inf-wlit 0 w gw (idpath false))
 )
 (defvcs inf-vc-dyn-j2j 8 inf-dyn-c8 ()
  (inf-lt 0 rrj3) f1
  (inf-le rrj3 138) f2
  (inf-le 0 15) (idpath false)
  (inf-le ipj3 n) r1
  (inf-le bcj3 63) r3
  (inf-bits-inv carry ipj3 consj3 bcj3) r4
  (inf-le cons0 consj3) r5
 )
 (defcx inf-dyn-c7 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (xj2 nat) (ipj2 nat) (bcj2 nat) (bbj2 nat) (consj2 nat) (rrj2 nat) (vj2 nat) (f3 (inf-lt 0 rrj2)) (f4 (inf-le rrj2 138)) (f5 (inf-le vj2 15)) (r1 (inf-le ipj2 n)) (r3 (inf-le bcj2 63)) (r4 (inf-bits-inv carry ipj2 consj2 bcj2)) (r5 (inf-le cons0 consj2)) )
 (defvcs inf-vc-dyn-j1j 8 inf-dyn-c7 ()
  (inf-lt 0 rrj2) f3
  (inf-le rrj2 138) f4
  (inf-le vj2 15) f5
  (inf-le ipj2 n) r1
  (inf-le bcj2 63) r3
  (inf-bits-inv carry ipj2 consj2 bcj2) r4
  (inf-le cons0 consj2) r5
 )
 (defcx inf-dyn-c6 inf-dyn-c5 (rrj1 nat) (vj1 nat) (xj1 nat) (ipj1 nat) (bcj1 nat) (bbj1 nat) (consj1 nat) (f6 (inf-lt 0 rrj1)) (f7 (inf-le rrj1 138)) (f8 (inf-le vj1 15)) (r1 (inf-le ipj1 n)) (r3 (inf-le bcj1 63)) (r4 (inf-bits-inv carry ipj1 consj1 bcj1)) (r5 (inf-le cons0 consj1)) )
 (defvcs inf-vc-dyn-w3e 1 inf-dyn-c6 ()
  (inf-le 0 rrj1) (idpath false)
  (pi j nat (inf-le (Lz j) 15)) b2
 )
 (defcx inf-dyn-c6-w3 inf-dyn-c6 (k nat) (Lz (pi j nat nat)) (c1 (inf-le k rrj1)) (c2 (pi j nat (inf-le (Lz j) 15))) )
 (defvcs inf-vc-dyn-i2 1 inf-dyn-c6-w3 (w3 (inf-lt k rrj1))
  (inf-lt (add i k) (inf-pow w)) (inf-lelt (add i k) 458 (inf-pow w) ((inf-add2 i 320 k 138 ((inf-letrans i (add ((add xt1 257)) ((add xt2 1))) 320 (inf-ltle i (add ((add xt1 257)) ((add xt2 1))) w2) ((inf-add2 ((add xt1 257)) 288 ((add xt2 1)) 32 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))))))) (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7))) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-dyn-s13 1 inf-dyn-c6-w3 (w3 (inf-lt k rrj1) g5 (inf-lt (add i k) 320))
  (inf-lt (add i k) (inf-pow w)) (inf-lelt (add i k) 458 (inf-pow w) ((inf-add2 i 320 k 138 ((inf-letrans i (add ((add xt1 257)) ((add xt2 1))) 320 (inf-ltle i (add ((add xt1 257)) ((add xt2 1))) w2) ((inf-add2 ((add xt1 257)) 288 ((add xt2 1)) 32 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))))))) (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7))) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
  (inf-lt (add i k) 320) g5
  (inf-lt vj1 (inf-pow w)) (inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false)))
 )
 (defvcs inf-vc-dyn-w3b 1 inf-dyn-c6-w3 (w3 (inf-lt k rrj1) g5 (inf-lt (add i k) 320))
  (inf-lt (succ k) (inf-pow w)) (inf-lelt (succ k) 138 (inf-pow w) ((inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7)) ((inf-lelt 138 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
  (inf-le (succ k) rrj1) (inf-ltsu k rrj1 w3)
  (pi j nat (inf-le ((inf-upd Lz (add i k) vj1) j) 15)) (inf-updle Lz (add i k) vj1 15 c2 f8)
  (inf-lt (natminus rrj1 (succ k)) (natminus rrj1 k)) (inf-subfall rrj1 k w3)
 )
 (defvcs inf-vc-dyn-w3b 5 inf-dyn-c6-w3 (w3 (inf-lt k rrj1) g5 (inf-le 320 (add i k)))
  (inf-lt (succ k) (inf-pow w)) (inf-lelt (succ k) 138 (inf-pow w) ((inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7)) ((inf-lelt 138 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
  (inf-le (succ k) rrj1) (inf-ltsu k rrj1 w3)
  (pi j nat (inf-le (Lz j) 15)) c2
  (inf-lt (natminus rrj1 (succ k)) (natminus rrj1 k)) (inf-subfall rrj1 k w3)
 )
 (defvcs inf-vc-dyn-s14 1 inf-dyn-c6-w3 (w3 (inf-le rrj1 k))
  (inf-lt (add i rrj1) (inf-pow w)) (inf-lelt (add i rrj1) 458 (inf-pow w) (inf-add2 i 320 rrj1 138 ((inf-letrans i (add ((add xt1 257)) ((add xt2 1))) 320 (inf-ltle i (add ((add xt1 257)) ((add xt2 1))) w2) ((inf-add2 ((add xt1 257)) 288 ((add xt2 1)) 32 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))))))) f7) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-dyn-s15 1 inf-dyn-c6-w3 (w3 (inf-le rrj1 k))
  (inf-lt vj1 (inf-pow w)) (inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false)))
 )
 (defvcs inf-vc-dyn-w2b 1 inf-dyn-c6-w3 (w3 (inf-le rrj1 k))
  (inf-le vj1 15) f8
  (pi j nat (inf-le (Lz j) 15)) c2
  (inf-le ipj1 n) r1
  (inf-le bcj1 63) r3
  (inf-bits-inv carry ipj1 consj1 bcj1) r4
  (inf-le cons0 consj1) r5
  (inf-lt (natminus (add (add xt1 257) (add xt2 1)) (add i rrj1)) (natminus (add (add xt1 257) (add xt2 1)) i)) (inf-subby i (add ((add xt1 257)) ((add xt2 1))) rrj1 w2 f6)
 )
 (defvcs inf-vc-dyn-c4 1 inf-dyn-c4-w2 (w2 (inf-le (add (add xt1 257) (add xt2 1)) i))
  (pi k nat g (inf-lt k (add xt1 257)) (inf-le (Lz k) 15)) (lam k g (b2 k))
  (inf-lt (add xt1 257) q) (inf-lelt ((add xt1 257)) 288 q ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) (inf-lttrans 288 320 q (idpath true) ((inf-ltle 320 q gq2))))
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-le (inf-pow h) (inf-pow w)) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
  (inf-le LROOT 15) gl
  (inf-le 32 w) gw
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
 )
 (defcx inf-dyn-c12 inf-dyn-c4-w2 (w2 (inf-le (add (add xt1 257) (add xt2 1)) i)) (Lcc4 (pi j nat nat)) (Lsc4 (pi j nat nat)) (Ltc4 (pi j nat nat)) (c4e1 (pi z nat (inf-lt (Lcc4 z) (inf-pow h)))) (c4e2 (pi z nat (inf-lt (Lsc4 z) (inf-pow h)))) (c4e3 (inf-le (inf-sum Lcc4 15 1) (add xt1 257))) )
 (defvcs inf-vc-dyn-c5 1 inf-dyn-c12 ()
  (pi k nat g (inf-lt k (add xt2 1)) (inf-le ((inf-shift Lz (add xt1 257)) k) 15)) (lam k g (b2 (add ((add xt1 257)) k)))
  (inf-lt (add xt2 1) q) (inf-lelt ((add xt2 1)) 32 q ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))) (inf-lttrans 32 320 q (idpath true) ((inf-ltle 320 q gq2))))
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-le (inf-pow h) (inf-pow w)) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
  (inf-le DROOT 15) gd
  (inf-le 32 w) gw
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
 )
 (defcx inf-dyn-c13 inf-dyn-c12 (Dcc5 (pi j nat nat)) (Dsc5 (pi j nat nat)) (Dtc5 (pi j nat nat)) (c5e1 (pi z nat (inf-lt (Dcc5 z) (inf-pow h)))) (c5e2 (pi z nat (inf-lt (Dsc5 z) (inf-pow h)))) (c5e3 (inf-le (inf-sum Dcc5 15 1) (add xt2 1))) )
 (defvcs inf-vc-dyn-r2 1 inf-dyn-c13 ()
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le cons0 cons) r5
  (pi k nat (inf-lt (Lcc4 k) (inf-pow h))) c4e1
  (pi k nat (inf-lt (Lsc4 k) (inf-pow h))) c4e2
  (inf-le (inf-sum Lcc4 15 1) (add xt1 257)) c4e3
  (inf-le (add xt1 257) 288) ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7)))
  (pi k nat (inf-lt (Dcc5 k) (inf-pow h))) c5e1
  (pi k nat (inf-lt (Dsc5 k) (inf-pow h))) c5e2
  (inf-le (inf-sum Dcc5 15 1) (add xt2 1)) c5e3
  (inf-le (add xt2 1) 32) ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7)))
 )
 (defcx inf-fast (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gcf (inf-lt (add cap 266) (inf-pow w))) (Lt (pi k nat nat)) (Dt (pi k nat nat)) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (h nat) (LROOT nat) (DROOT nat) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16)) (gz (inf-lt 0 out)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) )
 (defvcs inf-vc-fast-w1e 1 inf-fast ()
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
  (inf-le op0 op0) (inf-refl op0)
  (inf-le op0 cap) gop
 )
 (defcx inf-fast-w1 inf-fast (ans nat) (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (j1 (inf-le ip n)) (j3 (inf-le bc 63)) (j4 (inf-bits-inv carry ip cons bc)) (j5 (inf-le cons0 cons)) (j6 (inf-le op0 op)) (j7 (inf-le op cap)) )
 (defvcs inf-vc-fast-w1h 1 inf-fast-w1 ()
  (inf-lt (add op 266) (inf-pow w)) (inf-lelt (add op 266) (add cap 266) (inf-pow w) (inf-addr op cap 266 j7) gcf)
 )
 (defvcs inf-vc-fast-i2 1 inf-fast-w1 (w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15))
  (inf-lt (add ip 8) (inf-pow w)) (inf-lelt (add ip 8) (add n 8) (inf-pow w) (inf-addr ip n 8 j1) gn)
 )
 (defvcs inf-vc-fast-r4 1 inf-fast-w1 (w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv carry ip cons bc) j4
  (inf-le cons0 cons) j5
  (inf-le op cap) j7
  (inf-le op0 op) j6
 )
 (defvcs inf-vc-fast-f1 1 inf-fast-w1 (w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n))
  (inf-le (add ip 8) n) g2
  (inf-lt bc 64) (inf-lttrans bc 15 64 g1 (idpath false))
 )
 (defvcs inf-vc-fast-f2 1 inf-fast-w1 (w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat)
  (inf-le (inf-div8 bc) 7) (inf-div8le bc ((inf-letrans bc 15 63 (inf-ltle bc 15 g1) (idpath false))))
  (inf-lt (add ip (natminus 7 (inf-div8 bc))) (inf-pow w)) (inf-lelt ((add ip ((natminus 7 (inf-div8 bc))))) n (inf-pow w) ((inf-letrans ((add ip ((natminus 7 (inf-div8 bc))))) (add ip 8) n (inf-addl ip ((natminus 7 (inf-div8 bc))) 8 (inf-letrans ((natminus 7 (inf-div8 bc))) 7 8 (inf-suble 7 (inf-div8 bc)) (idpath false))) g2)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))
 )
 (defvcs inf-vc-fast-f3 1 inf-fast-w1 (w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat)
  (inf-le bc 63) j3
  (inf-lt (add 56 (inf-mod 8 bc)) (inf-pow w)) (inf-wlit (add 56 (inf-mod 8 bc)) w gw (inf-or56 bc))
 )
 (defvcs inf-vc-fast-i1j 1 inf-fast-w1 (w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat)
  (inf-le (add ip (natminus 7 (inf-div8 bc))) n) ((inf-letrans ((add ip ((natminus 7 (inf-div8 bc))))) (add ip 8) n (inf-addl ip ((natminus 7 (inf-div8 bc))) 8 (inf-letrans ((natminus 7 (inf-div8 bc))) 7 8 (inf-suble 7 (inf-div8 bc)) (idpath false))) g2))
  (inf-le (add 56 (inf-mod 8 bc)) 63) (inf-or56 bc)
  (inf-bits-inv carry (add ip (natminus 7 (inf-div8 bc))) cons (add 56 (inf-mod 8 bc))) (inf-fillw carry ip cons bc ((inf-letrans bc 15 63 (inf-ltle bc 15 g1) (idpath false))) j4)
  (inf-le 15 (add 56 (inf-mod 8 bc))) (inf-letrans 15 56 (add 56 (inf-mod 8 bc)) (idpath false) (inf-leaddr 56 (inf-mod 8 bc)))
 )
 (defvcs inf-vc-fast-i1j 5 inf-fast-w1 (w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv carry ip cons bc) j4
  (inf-le 15 bc) g1
 )
 (defcx inf-fast-c1 inf-fast-w1 (w1 (inf-le (add op 266) cap)) (bbi1 nat) (ipi1 nat) (bci1 nat) (h1 (inf-le ipi1 n)) (h3 (inf-le bci1 63)) (h4 (inf-bits-inv carry ipi1 cons bci1)) (h5 (inf-le 15 bci1)) )
 (defvcs inf-vc-fast-d1 1 inf-fast-c1 ()
  (inf-lt LROOT 32) (inf-lelt LROOT 15 32 gl (idpath true))
  (inf-lt (inf-mod (inf-pow LROOT) bbi1) (inf-pow LROOT)) (inf-masklt bbi1 LROOT)
 )
 (defvcs inf-vc-fast-r4 7 inf-fast-c1 (ed1 nat g3 (paths nat ed1 0))
  (inf-le ipi1 n) h1
  (inf-le bci1 63) h3
  (inf-bits-inv carry ipi1 cons bci1) h4
  (inf-le cons0 cons) j5
  (inf-le op cap) j7
  (inf-le op0 op) j6
 )
 (defvcs inf-vc-fast-d2 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1))
  (inf-lt 4 64) (idpath true)
 )
 (defvcs inf-vc-fast-d3 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256))
  (inf-lt (inf-mod 16 ed1) 64) ((inf-lttrans ((inf-mod 16 ed1)) 16 64 ((inf-modlt 15 ed1)) (idpath false)))
 )
 (defvcs inf-vc-fast-d4 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat)
  (inf-le (inf-mod 16 ed1) bci1) ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5))
  (inf-lt (natminus bci1 (inf-mod 16 ed1)) (inf-pow w)) (inf-wlit ((natminus bci1 ((inf-mod 16 ed1)))) w gw (inf-letrans ((natminus bci1 ((inf-mod 16 ed1)))) bci1 63 (inf-suble bci1 ((inf-mod 16 ed1))) h3))
 )
 (defvcs inf-vc-fast-p1 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat)
  (inf-lt op oc) ((inf-lttrans op cap oc ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))))
  (inf-lt syd2 256) g4
 )
 (defvcs inf-vc-fast-s1 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat)
  (inf-lt (add op 1) (inf-pow w)) (inf-lelt (add op 1) cap (inf-pow w) (inf-lt1 op cap ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
 )
 (defvcs inf-vc-fast-w1b 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat)
  (inf-le ipi1 n) h1
  (inf-le (natminus bci1 (inf-mod 16 ed1)) 63) (inf-sub63 bci1 ((inf-mod 16 ed1)) h3)
  (inf-bits-inv carry ipi1 (add cons (inf-mod 16 ed1)) (natminus bci1 (inf-mod 16 ed1))) (inf-take carry ipi1 cons bci1 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5)) h4)
  (inf-le cons0 (add cons (inf-mod 16 ed1))) (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1))))
  (inf-le op0 (add op 1)) (inf-letrans op0 op (add op 1) j6 (inf-leaddr op 1))
  (inf-le (add op 1) cap) (inf-lt1 op cap ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1)))
  (inf-lt (natminus cap (add op 1)) (natminus cap op)) (inf-subfall1 cap op ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1)))
 )
 (defvcs inf-vc-fast-d6 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256))
  (inf-lt (inf-mod 16 ed1) 64) ((inf-lttrans ((inf-mod 16 ed1)) 16 64 ((inf-modlt 15 ed1)) (idpath false)))
 )
 (defvcs inf-vc-fast-d7 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat)
  (inf-le (inf-mod 16 ed1) bci1) ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5))
  (inf-lt (natminus bci1 (inf-mod 16 ed1)) (inf-pow w)) (inf-wlit ((natminus bci1 ((inf-mod 16 ed1)))) w gw (inf-letrans ((natminus bci1 ((inf-mod 16 ed1)))) bci1 63 (inf-suble bci1 ((inf-mod 16 ed1))) h3))
 )
 (defvcs inf-vc-fast-s2 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat)
  (inf-lt 1 (inf-pow w)) (inf-wlit 1 w gw (idpath false))
 )
 (defvcs inf-vc-fast-r4 13 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat)
  (inf-le ipi1 n) h1
  (inf-le (natminus bci1 (inf-mod 16 ed1)) 63) (inf-sub63 bci1 ((inf-mod 16 ed1)) h3)
  (inf-bits-inv carry ipi1 (add cons (inf-mod 16 ed1)) (natminus bci1 (inf-mod 16 ed1))) (inf-take carry ipi1 cons bci1 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5)) h4)
  (inf-le cons0 (add cons (inf-mod 16 ed1))) (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1))))
  (inf-le op cap) j7
  (inf-le op0 op) j6
 )
 (defvcs inf-vc-fast-r1 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-lt 285 syd2))
  (inf-le ipi1 n) h1
  (inf-le bci1 63) h3
  (inf-bits-inv carry ipi1 cons bci1) h4
  (inf-le cons0 cons) j5
  (inf-le op cap) j7
  (inf-le op0 op) j6
 )
 (defvcs inf-vc-fast-i8 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48))
  (inf-lt (add ipi1 8) (inf-pow w)) (inf-lelt (add ipi1 8) (add n 8) (inf-pow w) (inf-addr ipi1 n 8 h1) gn)
 )
 (defvcs inf-vc-fast-r4 19 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)))
  (inf-le ipi1 n) h1
  (inf-le bci1 63) h3
  (inf-bits-inv carry ipi1 cons bci1) h4
  (inf-le cons0 cons) j5
  (inf-le op cap) j7
  (inf-le op0 op) j6
 )
 (defvcs inf-vc-fast-f4 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n))
  (inf-le (add ipi1 8) n) g8
  (inf-lt bci1 64) (inf-lttrans bci1 48 64 g7 (idpath false))
 )
 (defvcs inf-vc-fast-f5 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat)
  (inf-le (inf-div8 bci1) 7) (inf-div8le bci1 ((inf-letrans bci1 48 63 (inf-ltle bci1 48 g7) (idpath false))))
  (inf-lt (add ipi1 (natminus 7 (inf-div8 bci1))) (inf-pow w)) (inf-lelt ((add ipi1 ((natminus 7 (inf-div8 bci1))))) n (inf-pow w) ((inf-letrans ((add ipi1 ((natminus 7 (inf-div8 bci1))))) (add ipi1 8) n (inf-addl ipi1 ((natminus 7 (inf-div8 bci1))) 8 (inf-letrans ((natminus 7 (inf-div8 bci1))) 7 8 (inf-suble 7 (inf-div8 bci1)) (idpath false))) g8)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))
 )
 (defvcs inf-vc-fast-f6 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat)
  (inf-le bci1 63) h3
  (inf-lt (add 56 (inf-mod 8 bci1)) (inf-pow w)) (inf-wlit (add 56 (inf-mod 8 bci1)) w gw (inf-or56 bci1))
 )
 (defvcs inf-vc-fast-i7j 1 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat)
  (inf-le (add ipi1 (natminus 7 (inf-div8 bci1))) n) ((inf-letrans ((add ipi1 ((natminus 7 (inf-div8 bci1))))) (add ipi1 8) n (inf-addl ipi1 ((natminus 7 (inf-div8 bci1))) 8 (inf-letrans ((natminus 7 (inf-div8 bci1))) 7 8 (inf-suble 7 (inf-div8 bci1)) (idpath false))) g8))
  (inf-le (add 56 (inf-mod 8 bci1)) 63) (inf-or56 bci1)
  (inf-bits-inv carry (add ipi1 (natminus 7 (inf-div8 bci1))) cons (add 56 (inf-mod 8 bci1))) (inf-fillw carry ipi1 cons bci1 ((inf-letrans bci1 48 63 (inf-ltle bci1 48 g7) (idpath false))) h4)
  (inf-le 48 (add 56 (inf-mod 8 bci1))) (inf-letrans 48 56 (add 56 (inf-mod 8 bci1)) (idpath false) (inf-leaddr 56 (inf-mod 8 bci1)))
 )
 (defvcs inf-vc-fast-i7j 5 inf-fast-c1 (ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1))
  (inf-le ipi1 n) h1
  (inf-le bci1 63) h3
  (inf-bits-inv carry ipi1 cons bci1) h4
  (inf-le 48 bci1) g7
 )
 (defcx inf-fast-c2 inf-fast-c1 (ed1 nat) (g3 (inf-lt 0 ed1)) (syd2 nat) (g4 (inf-le 256 syd2)) (g5 (inf-lt 256 syd2)) (g6 (inf-le syd2 285)) (bbi7 nat) (ipi7 nat) (bci7 nat) (m1 (inf-le ipi7 n)) (m3 (inf-le bci7 63)) (m4 (inf-bits-inv carry ipi7 cons bci7)) (m5 (inf-le 48 bci7)) )
 (defvcs inf-vc-fast-d9 1 inf-fast-c2 ()
  (inf-le 257 syd2) ((inf-ltsu 256 syd2 g5))
  (inf-lt (natminus syd2 257) 29) ((inf-lidx syd2 g6))
  (inf-lt (Le (natminus syd2 257)) (inf-pow w)) (inf-wlit ((Le ((natminus syd2 257)))) w gw (inf-letrans ((Le ((natminus syd2 257)))) 5 63 ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) (idpath false)))
 )
 (defvcs inf-vc-fast-d10 1 inf-fast-c2 ()
  (inf-lt (add (inf-mod 16 ed1) (Le (natminus syd2 257))) (inf-pow w)) (inf-wlit (add ((inf-mod 16 ed1)) ((Le ((natminus syd2 257))))) w gw (inf-letrans (add ((inf-mod 16 ed1)) ((Le ((natminus syd2 257))))) 20 63 (inf-add2 ((inf-mod 16 ed1)) 15 ((Le ((natminus syd2 257)))) 5 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6))))) (idpath false)))
  (inf-lt (add (inf-mod 16 ed1) (Le (natminus syd2 257))) 64) (inf-lelt (add ((inf-mod 16 ed1)) ((Le ((natminus syd2 257))))) 20 64 (inf-add2 ((inf-mod 16 ed1)) 15 ((Le ((natminus syd2 257)))) 5 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6))))) (idpath true))
 )
 (defvcs inf-vc-fast-d11 1 inf-fast-c2 (yd10 nat)
  (inf-lt DROOT 32) (inf-lelt DROOT 15 32 gd (idpath true))
  (inf-lt (inf-mod (inf-pow DROOT) yd10) (inf-pow DROOT)) (inf-masklt yd10 DROOT)
 )
 (defvcs inf-vc-fast-r4 25 inf-fast-c2 (yd10 nat fd11 nat g9 (paths nat fd11 0))
  (inf-le ipi7 n) m1
  (inf-le bci7 63) m3
  (inf-bits-inv carry ipi7 cons bci7) m4
  (inf-le cons0 cons) j5
  (inf-le op cap) j7
  (inf-le op0 op) j6
 )
 (defvcs inf-vc-fast-d12 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11))
  (inf-lt (inf-mod 16 ed1) 64) ((inf-lttrans ((inf-mod 16 ed1)) 16 64 ((inf-modlt 15 ed1)) (idpath false)))
 )
 (defvcs inf-vc-fast-d13 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat)
  (inf-le (inf-mod 16 ed1) bci7) ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5)))
  (inf-lt (natminus bci7 (inf-mod 16 ed1)) (inf-pow w)) (inf-wlit ((natminus bci7 ((inf-mod 16 ed1)))) w gw (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3))
 )
 (defvcs inf-vc-fast-d15 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat)
  (inf-le 257 syd2) ((inf-ltsu 256 syd2 g5))
  (inf-lt (natminus syd2 257) 29) ((inf-lidx syd2 g6))
  (inf-lt (Le (natminus syd2 257)) 32) (inf-lelt ((Le ((natminus syd2 257)))) 5 32 ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) (idpath true))
  (inf-lt (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (inf-pow w)) ((inf-lelt ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-pow w) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) ((inf-lelt 258 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))
 )
 (defvcs inf-vc-fast-d16 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat)
  (inf-lt (Le (natminus syd2 257)) 64) (inf-lelt ((Le ((natminus syd2 257)))) 5 64 ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) (idpath true))
 )
 (defvcs inf-vc-fast-d17 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat)
  (inf-le (Le (natminus syd2 257)) (natminus bci7 (inf-mod 16 ed1))) ((inf-fastb1 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) m5))
  (inf-lt (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-pow w)) (inf-wlit ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) w gw (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3)))
 )
 (defvcs inf-vc-fast-d19 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat)
  (inf-lt (inf-mod 16 fd11) 64) (inf-lttrans ((inf-mod 16 fd11)) 16 64 ((inf-modlt 15 fd11)) (idpath false))
 )
 (defvcs inf-vc-fast-d20 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat)
  (inf-le (inf-mod 16 fd11) (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257)))) ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5))
  (inf-lt (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (inf-pow w)) (inf-wlit ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) w gw (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 63 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3))))
 )
 (defvcs inf-vc-fast-d22 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat)
  (inf-lt 4 64) (idpath true)
 )
 (defvcs inf-vc-fast-r2 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-lt 29 syd22))
  (inf-le ipi7 n) m1
  (inf-le (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) 63) (inf-letrans (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) 63 (inf-suble (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (inf-letrans (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (natminus bci7 (inf-mod 16 ed1)) 63 (inf-suble (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-letrans (natminus bci7 (inf-mod 16 ed1)) bci7 63 (inf-suble bci7 (inf-mod 16 ed1)) m3)))
  (inf-bits-inv carry ipi7 (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11))) (inf-take carry ipi7 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)) ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5)) (inf-take carry ipi7 ((add cons ((inf-mod 16 ed1)))) ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))) ((inf-fastb1 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) m5)) (inf-take carry ipi7 cons bci7 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5))) m4)))
  (inf-le cons0 (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11))) (inf-letrans cons0 (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (inf-letrans cons0 (add cons (inf-mod 16 ed1)) (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-letrans cons0 cons (add cons (inf-mod 16 ed1)) j5 (inf-leaddr cons (inf-mod 16 ed1))) (inf-leaddr (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257)))) (inf-leaddr (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)))
  (inf-le op cap) j7
  (inf-le op0 op) j6
 )
 (defvcs inf-vc-fast-d23 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29))
  (inf-lt syd22 30) ((inf-lelts syd22 29 g10))
  (inf-lt (De syd22) (inf-pow w)) (inf-wlit ((De syd22)) w gw (inf-letrans ((De syd22)) 13 63 ((hde syd22 ((inf-lelts syd22 29 g10)))) (idpath false)))
 )
 (defvcs inf-vc-fast-d24 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29))
  (inf-lt syd22 30) ((inf-lelts syd22 29 g10))
  (inf-lt (De syd22) 32) (inf-lelt ((De syd22)) 13 32 ((hde syd22 ((inf-lelts syd22 29 g10)))) (idpath true))
  (inf-lt (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (inf-pow w)) ((inf-powfit ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) h w ((inf-baseadd (Db syd22) ((De syd22)) bbd19 (inf-pow h) (hdb syd22 ((inf-lelts syd22 29 g10))))) (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
 )
 (defvcs inf-vc-fast-d25 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29))
  (inf-lt (De syd22) 64) (inf-lelt ((De syd22)) 13 64 ((hde syd22 ((inf-lelts syd22 29 g10)))) (idpath true))
 )
 (defvcs inf-vc-fast-d26 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat)
  (inf-le (De syd22) (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11))) ((inf-fastb3 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) ((De syd22)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) ((hde syd22 ((inf-lelts syd22 29 g10)))) m5))
  (inf-lt (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) (inf-pow w)) (inf-wlit ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) w gw (inf-letrans ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) 63 (inf-suble ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))) (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 63 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3)))))
 )
 (defvcs inf-vc-fast-i12 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))))
  (inf-lt (add op nd) (inf-pow w)) (inf-lelt (add op nd) (add cap nd) (inf-pow w) (inf-addr op cap nd j7) gnd)
 )
 (defvcs inf-vc-fast-r3 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-lt (add op nd) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))))
  (inf-le ipi7 n) m1
  (inf-le (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) 63) (inf-letrans ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) 63 (inf-suble ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))) (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 63 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3))))
  (inf-bits-inv carry ipi7 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22))) (inf-take carry ipi7 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)) ((inf-fastb3 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) ((De syd22)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) ((hde syd22 ((inf-lelts syd22 29 g10)))) m5)) (inf-take carry ipi7 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)) ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5)) (inf-take carry ipi7 ((add cons ((inf-mod 16 ed1)))) ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))) ((inf-fastb1 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) m5)) (inf-take carry ipi7 cons bci7 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5))) m4))))
  (inf-le cons0 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22))) (inf-letrans cons0 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((add ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) (inf-letrans cons0 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-letrans cons0 ((add cons ((inf-mod 16 ed1)))) ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1)))) (inf-leaddr ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-leaddr ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-leaddr ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))))
  (inf-le op cap) j7
  (inf-le op0 op) j6
 )
 (defvcs inf-vc-fast-s3 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)))
  (inf-lt (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (inf-pow w)) ((inf-lelt ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-pow w) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) ((inf-lelt 258 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))
 )
 (defvcs inf-vc-fast-j8 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)))
  (inf-le op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-letrans op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (inf-ltle op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) g11) (inf-refl (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))))
 )
 (defvcs inf-vc-fast-s4 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) g13 (inf-lt (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-le op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-letrans op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (inf-ltle op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) g11) (inf-refl (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))))
  (inf-lt (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (inf-pow w)) (inf-lelt (natminus ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) (inf-pow w) (inf-suble ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op) ((inf-powfit ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) h w ((inf-baseadd (Db syd22) ((De syd22)) bbd19 (inf-pow h) (hdb syd22 ((inf-lelts syd22 29 g10))))) (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))
 )
 (defvcs inf-vc-fast-j8j 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) g13 (inf-lt (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (paths nat (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (inf-h (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))) (inf-htt ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) g13)
 )
 (defvcs inf-vc-fast-j8j 2 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) g13 (inf-le (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)))
  (paths nat (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (inf-h (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))) (inf-hff ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) g13)
 )
 (defcx inf-fast-c6 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))) (g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd))) (ddj8 nat) (f7 (paths nat ddj8 (inf-h (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))) )
 (defvcs inf-vc-fast-m6 1 inf-fast-c6 ()
  (inf-le op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-letrans op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (inf-ltle op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) g11) (inf-refl (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))))
  (inf-le (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) nd) (inf-dnowrap ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op nd g12)
  (inf-le (add op ddj8) oc) (inf-letrans (add op ddj8) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) oc (inf-addl op ddj8 ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) ((inf-letr (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) ddj8 ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) ((pathsinv0 nat ddj8 (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) f7)) (inf-hlel ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))))))) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))))
  (inf-le (add (natminus nd (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) ddj8) nd) (inf-letr (add (natminus nd (natminus ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op)) (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))))) (add (natminus nd (natminus ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op)) ddj8) nd (maponpaths nat nat (lam z (add (natminus nd (natminus ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op)) z)) (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) ddj8 ((pathsinv0 nat ddj8 (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) f7))) (inf-dr ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) nd g12))
 )
 (defvcs inf-vc-fast-w2e 1 inf-fast-c6 ()
  (inf-le ddj8 ddj8) (inf-refl ddj8)
 )
 (defcx inf-fast-c6-w2 inf-fast-c6 (k nat) (a1 (inf-le ddj8 k)) )
 (defvcs inf-vc-fast-p2 1 inf-fast-c6-w2 (w2 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-ltle (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w2)) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
  (inf-lt (add op k) oc) (inf-cw op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) oc w2 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))))
  (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op k)) (inf-dknowrap ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) k (inf-ltle op ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) g11) (inf-letr ddj8 (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) k f7 a1) w2)
  (inf-lt (natminus (add op k) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) oc) (inf-lelt (natminus (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (add op k) oc (inf-suble (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (inf-cw op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) oc w2 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))))))
 )
 (defvcs inf-vc-fast-w2b 1 inf-fast-c6-w2 (w2 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-lt (succ k) (inf-pow w)) (inf-lelt (succ k) ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (inf-pow w) (inf-ltsu k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w2) ((inf-lelt ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-pow w) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) ((inf-lelt 258 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))))
  (inf-le ddj8 (succ k)) (inf-letrans ddj8 k (succ k) a1 (inf-ltle k (succ k) (inf-ltself k)))
  (inf-lt (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (succ k)) (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) k)) (inf-subfall ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) k w2)
 )
 (defvcs inf-vc-fast-s5 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op))
  (inf-lt 0 (inf-pow w)) (inf-wlit 0 w gw (idpath false))
 )
 (defvcs inf-vc-fast-w3e 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) g14 (inf-le 8 (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))))
  (inf-le 0 (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7)) (idpath false)
 )
 (defcx inf-fast-c2-w3 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (g14 (inf-le 8 (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))) (k nat) (a2 (inf-le k (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7))) )
 (defvcs inf-vc-fast-p3 1 inf-fast-c2-w3 (w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-ltle (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3)) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
  (inf-le (add (add op k) 8) oc) ((inf-letl (add (add op k) 8) cap oc (pathsinv0 nat oc cap (go gz)) (inf-fastw op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (add op k) cap (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) w1)))
  (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op k)) ((inf-letrans ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op (add op k) g11 (inf-leaddr op k)))
  (inf-le (add (natminus (add op k) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) 8) oc) (inf-letrans (add (natminus (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) 8) (add (add op k) 8) oc (inf-addr (natminus (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (add op k) 8 (inf-suble (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))))) ((inf-letl (add (add op k) 8) cap oc (pathsinv0 nat oc cap (go gz)) (inf-fastw op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (add op k) cap (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) w1))))
 )
 (defvcs inf-vc-fast-s6 1 inf-fast-c2-w3 (w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-lt (add k 8) (inf-pow w)) (inf-lelt (add k 8) 266 (inf-pow w) (inf-addr k 258 8 (inf-letrans k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-ltle k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))))) ((inf-lelt 266 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-fast-w3b 1 inf-fast-c2-w3 (w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-le (add k 8) (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7)) (inf-step8 k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3)
  (inf-lt (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (add k 8)) (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) k)) (inf-subby k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 8 w3 (idpath true))
 )
 (defvcs inf-vc-fast-w4e 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) g14 unit g15 unit)
  (inf-le 0 (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7)) (idpath false)
 )
 (defcx inf-fast-c2-w4 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (g14 unit) (g15 unit) (k nat) (a3 (inf-le k (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7))) )
 (defvcs inf-vc-fast-p4 1 inf-fast-c2-w4 (w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-ltle (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w4)) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
  (inf-le (add (add op k) 8) oc) ((inf-letl (add (add op k) 8) cap oc (pathsinv0 nat oc cap (go gz)) (inf-fastw op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (add op k) cap (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w4) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) w1)))
  (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) g11
  (inf-lt (natminus op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) oc) (inf-lelt (natminus op ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) op oc (inf-suble op ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) ((inf-lttrans op cap oc ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))))
 )
 (defvcs inf-vc-fast-s7 1 inf-fast-c2-w4 (w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-lt (add k 8) (inf-pow w)) (inf-lelt (add k 8) 266 (inf-pow w) (inf-addr k 258 8 (inf-letrans k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-ltle k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w4) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))))) ((inf-lelt 266 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-fast-w4b 1 inf-fast-c2-w4 (w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-le (add k 8) (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7)) (inf-step8 k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w4)
  (inf-lt (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (add k 8)) (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) k)) (inf-subby k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 8 w4 (idpath true))
 )
 (defvcs inf-vc-fast-w5e 1 inf-fast-c2 (yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) g14 unit g15 unit)
  (inf-le 0 (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (idpath false)
 )
 (defcx inf-fast-c2-w5 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (g14 unit) (g15 unit) (k nat) (a4 (inf-le k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))) )
 (defvcs inf-vc-fast-p5 1 inf-fast-c2-w5 (w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-ltle (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w5)) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
  (inf-lt (add op k) oc) (inf-cw op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) oc w5 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))))
  (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op k)) ((inf-letrans ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op (add op k) g11 (inf-leaddr op k)))
  (inf-lt (natminus (add op k) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) oc) (inf-lelt (natminus (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (add op k) oc (inf-suble (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (inf-cw op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) oc w5 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))))))
 )
 (defvcs inf-vc-fast-s8 1 inf-fast-c2-w5 (w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-lt (add k 1) (inf-pow w)) (inf-lelt (add k 1) ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (inf-pow w) (inf-lt1 k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w5) ((inf-lelt ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-pow w) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) ((inf-lelt 258 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))))
 )
 (defvcs inf-vc-fast-w5b 1 inf-fast-c2-w5 (w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))
  (inf-le (add k 1) (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt1 k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w5)
  (inf-lt (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (add k 1)) (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) k)) (inf-subfall1 ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) k w5)
 )
 (defcx inf-fast-c5 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (g14 unit) (kj10 nat) )
 (defcx inf-fast-c4 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (kj9 nat) )
 (defcx inf-fast-c3 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) )
 (defvcs inf-vc-fast-s9 1 inf-fast-c3 ()
  (inf-lt (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-pow w)) ((inf-lelt (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-pow w) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))
 )
 (defvcs inf-vc-fast-w1b 8 inf-fast-c3 ()
  (inf-le ipi7 n) m1
  (inf-le (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) 63) (inf-letrans ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) 63 (inf-suble ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))) (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 63 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3))))
  (inf-bits-inv carry ipi7 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22))) (inf-take carry ipi7 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)) ((inf-fastb3 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) ((De syd22)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) ((hde syd22 ((inf-lelts syd22 29 g10)))) m5)) (inf-take carry ipi7 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)) ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5)) (inf-take carry ipi7 ((add cons ((inf-mod 16 ed1)))) ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))) ((inf-fastb1 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) m5)) (inf-take carry ipi7 cons bci7 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5))) m4))))
  (inf-le cons0 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22))) (inf-letrans cons0 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((add ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) (inf-letrans cons0 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-letrans cons0 ((add cons ((inf-mod 16 ed1)))) ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1)))) (inf-leaddr ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-leaddr ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-leaddr ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))))
  (inf-le op0 (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))) (inf-letrans op0 op (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) j6 (inf-leaddr op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))))
  (inf-le (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) cap) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))
  (inf-lt (natminus cap (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))) (natminus cap op)) (inf-subby op cap ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1)) ((inf-lttrans 0 3 ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (idpath true) (inf-letrans 3 (Lb ((natminus syd2 257))) ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (hlc ((natminus syd2 257)) ((inf-lidx syd2 g6))) (inf-leaddr (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))))))
 )
 (defvcs inf-vc-fast-r4 31 inf-fast-w1 (w1 (inf-lt cap (add op 266)))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv carry ip cons bc) j4
  (inf-le cons0 cons) j5
  (inf-le op cap) j7
  (inf-le op0 op) j6
 )
 (defcx inf-block (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gcf (inf-lt (add cap 266) (inf-pow w))) (Lc (pi k nat nat)) (Ls (pi k nat nat)) (Lt (pi k nat nat)) (Dc (pi k nat nat)) (Ds (pi k nat nat)) (Dt (pi k nat nat)) (lm nat) (dm nat) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (h nat) (LROOT nat) (DROOT nat) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16)) (c1 (pi k nat (inf-lt (Lc k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc 15 1) lm)) (c4 (inf-le lm 288)) (c5 (pi k nat (inf-lt (Dc k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc 15 1) dm)) (c8 (inf-le dm 32)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) )
 (defvcs inf-vc-block-w1e 1 inf-block ()
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
  (inf-le op0 op0) (inf-refl op0)
  (inf-le op0 cap) gop
 )
 (defcx inf-block-w1 inf-block (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (j1 (inf-le ip n)) (j3 (inf-le bc 63)) (j4 (inf-bits-inv carry ip cons bc)) (j5 (inf-le cons0 cons)) (j6 (inf-le op0 op)) (j7 (inf-le op cap)) )
 (defvcs inf-vc-block-i2 1 inf-block-w1 (w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out))
  (inf-lt (add ip 8) (inf-pow w)) (inf-lelt (add ip 8) (add n 8) (inf-pow w) (inf-addr ip n 8 j1) gn)
 )
 (defvcs inf-vc-block-i3 1 inf-block-w1 (w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n))
  (inf-lt (add op 266) (inf-pow w)) (inf-lelt (add op 266) (add cap 266) (inf-pow w) (inf-addr op cap 266 j7) gcf)
 )
 (defvcs inf-vc-block-t1 1 inf-block-w1 (w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv carry ip cons bc) j4
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
  (inf-le op cap) j7
  (inf-lt (add cap nd) (inf-pow w)) gnd
  (inf-lt (add cap 266) (inf-pow w)) gcf
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le h 16) gh
  (inf-lt 0 out) g1
  (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)) hle
  (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)) hlb
  (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))) hlc
  (pi k nat g (inf-lt k 30) (inf-le (De k) 13)) hde
  (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))) hdb
 )
 (defcx inf-block-c9 inf-block-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (g1 (inf-lt 0 out)) (g2 (inf-le (add ip 8) n)) (g3 (inf-le (add op 266) cap)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (opt1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e8 (inf-le opt1 cap)) (t1e9 (inf-le op opt1)) )
 (defvcs inf-vc-block-r6 1 inf-block-c9 (g4 (inf-lt 0 xt1))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 j5 t1e5)
  (inf-le opt1 cap) t1e8
  (inf-le op0 opt1) (inf-letrans op0 op opt1 j6 t1e9)
 )
 (defvcs inf-vc-block-i1j 1 inf-block-c9 (g4 (paths nat xt1 0))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 j5 t1e5)
  (inf-le o0 opt1) (inf-letrans o0 op opt1 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))) t1e9)
  (inf-le opt1 cap) t1e8
 )
 (defvcs inf-vc-block-i1j 7 inf-block-w1 (w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv carry ip cons bc) j4
  (inf-le cons0 cons) j5
  (inf-le o0 op) ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op)))
  (inf-le op cap) j7
 )
 (defvcs inf-vc-block-i1j 13 inf-block-w1 (w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv carry ip cons bc) j4
  (inf-le cons0 cons) j5
  (inf-le o0 op) ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op)))
  (inf-le op cap) j7
 )
 (defvcs inf-vc-block-i1j 19 inf-block-w1 (w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv carry ip cons bc) j4
  (inf-le cons0 cons) j5
  (inf-le o0 op) ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op)))
  (inf-le op cap) j7
 )
 (defcx inf-block-c1 inf-block-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (ipi1 nat) (bci1 nat) (bbi1 nat) (consi1 nat) (opi1 nat) (k1 (inf-le ipi1 n)) (k3 (inf-le bci1 63)) (k4 (inf-bits-inv carry ipi1 consi1 bci1)) (k5 (inf-le cons0 consi1)) (k6 (inf-le o0 opi1)) (k7 (inf-le opi1 cap)) )
 (defvcs inf-vc-block-t2 1 inf-block-c1 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipi1 n) k1
  (inf-le bci1 63) k3
  (inf-bits-inv carry ipi1 consi1 bci1) k4
  (pi i nat (inf-lt (Lc i) (inf-pow h))) c1
  (pi i nat (inf-lt (Ls i) (inf-pow h))) c2
  (inf-le h 16) gh
  (inf-lt lm (inf-pow w)) (inf-lelt lm 288 (inf-pow w) c4 (inf-wfit288 w gw))
  (inf-le (inf-sum Lc 15 1) lm) c3
  (inf-le LROOT 15) gl
 )
 (defcx inf-block-c2 inf-block-c1 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (syt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le consi1 const2)) )
 (defvcs inf-vc-block-p1 1 inf-block-c2 (g5 (inf-lt syt2 256) g6 (inf-lt opi1 cap) g7 (inf-lt 0 out))
  (inf-lt opi1 oc) (inf-lttrans opi1 cap oc g6 (inf-letl cap cap oc (pathsinv0 nat oc cap (go g7)) (inf-refl cap)))
  (inf-lt syt2 256) g5
 )
 (defcx inf-block-c8 inf-block-c2 (g5 (inf-lt syt2 256)) (g6 (inf-lt opi1 cap)) )
 (defvcs inf-vc-block-s1 1 inf-block-c8 ()
  (inf-lt (add opi1 1) (inf-pow w)) (inf-lelt (add opi1 1) cap (inf-pow w) (inf-lt1 opi1 cap g6) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
 )
 (defvcs inf-vc-block-w1b 1 inf-block-c8 ()
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consi1 const2 k5 t2e5)
  (inf-le op0 (add opi1 1)) (inf-letrans op0 opi1 (add opi1 1) ((inf-letrans op0 op opi1 j6 ((inf-letr o0 op opi1 eo k6)))) (inf-leaddr opi1 1))
  (inf-le (add opi1 1) cap) (inf-lt1 opi1 cap g6)
  (inf-lt (natminus cap (add opi1 1)) (natminus cap op)) (inf-subfrom op opi1 cap 1 ((inf-letr o0 op opi1 eo k6)) g6 (idpath true))
 )
 (defvcs inf-vc-block-r6 7 inf-block-c2 (g5 (inf-le 256 syt2) g8 (inf-le syt2 256))
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consi1 const2 k5 t2e5)
  (inf-le opi1 cap) k7
  (inf-le op0 opi1) ((inf-letrans op0 op opi1 j6 ((inf-letr o0 op opi1 eo k6))))
 )
 (defvcs inf-vc-block-s2 1 inf-block-c2 (g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285))
  (inf-le 257 syt2) (inf-ltsu 256 syt2 g8)
  (inf-lt (natminus syt2 257) 29) ((inf-lidx syt2 g9))
  (inf-lt (Lb (natminus syt2 257)) (inf-pow w)) (inf-lelt (Lb ((natminus syt2 257))) 259 (inf-pow w) (inf-letrans (Lb ((natminus syt2 257))) (add (Lb ((natminus syt2 257))) (inf-pow ((Le ((natminus syt2 257)))))) 259 (inf-leaddr (Lb ((natminus syt2 257))) (inf-pow ((Le ((natminus syt2 257)))))) ((hlb ((natminus syt2 257)) ((inf-lidx syt2 g9))))) (inf-lelt 259 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))
 )
 (defvcs inf-vc-block-t3 1 inf-block-c2 (g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le (Le (natminus syt2 257)) 13) (inf-letrans ((Le ((natminus syt2 257)))) 5 13 (hle ((natminus syt2 257)) ((inf-lidx syt2 g9))) (idpath false))
 )
 (defcx inf-block-c3 inf-block-c2 (g5 (inf-le 256 syt2)) (g8 (inf-lt 256 syt2)) (g9 (inf-le syt2 285)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e6 (inf-le (add const2 (Le (natminus syt2 257))) const3)) (t3e7 (inf-lt xt3 (inf-pow (Le (natminus syt2 257))))) )
 (defvcs inf-vc-block-s3 1 inf-block-c3 ()
  (inf-lt (add (Lb (natminus syt2 257)) xt3) (inf-pow w)) (inf-lttrans ((add (Lb ((natminus syt2 257))) xt3)) 259 (inf-pow w) ((inf-basele (Lb ((natminus syt2 257))) ((Le ((natminus syt2 257)))) xt3 259 t3e7 ((hlb ((natminus syt2 257)) ((inf-lidx syt2 g9)))))) (inf-ltle 259 (inf-pow w) (inf-lelt 259 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-block-t4 1 inf-block-c3 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (pi i nat (inf-lt (Dc i) (inf-pow h))) c5
  (pi i nat (inf-lt (Ds i) (inf-pow h))) c6
  (inf-le h 16) gh
  (inf-lt dm (inf-pow w)) (inf-wlit dm w gw (inf-letrans dm 32 63 c8 (idpath false)))
  (inf-le (inf-sum Dc 15 1) dm) c7
  (inf-le DROOT 15) gd
 )
 (defcx inf-block-c4 inf-block-c3 (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (sdt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le const3 const4)) )
 (defvcs inf-vc-block-s4 1 inf-block-c4 (g10 (inf-le sdt4 29))
  (inf-lt sdt4 30) ((inf-lelts sdt4 29 g10))
  (inf-lt (Db sdt4) (inf-pow w)) (inf-lttrans (Db sdt4) (inf-pow h) (inf-pow w) (inf-lttrans (Db sdt4) (add (Db sdt4) (inf-pow ((De sdt4)))) (inf-pow h) (inf-ltaddpos (Db sdt4) (inf-pow ((De sdt4))) (inf-powpos ((De sdt4)))) (hdb sdt4 ((inf-lelts sdt4 29 g10)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))
 )
 (defvcs inf-vc-block-t5 1 inf-block-c4 (g10 (inf-le sdt4 29))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt4 n) t4e1
  (inf-le bct4 63) t4e3
  (inf-bits-inv carry ipt4 const4 bct4) t4e4
  (inf-le (De sdt4) 13) (hde sdt4 ((inf-lelts sdt4 29 g10)))
 )
 (defcx inf-block-c5 inf-block-c4 (g10 (inf-le sdt4 29)) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (yt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv carry ipt5 const5 bct5)) (t5e5 (inf-le const4 const5)) (t5e6 (inf-le (add const4 (De sdt4)) const5)) (t5e7 (inf-lt yt5 (inf-pow (De sdt4)))) )
 (defvcs inf-vc-block-s5 1 inf-block-c5 ()
  (inf-lt (add (Db sdt4) yt5) (inf-pow w)) ((inf-lttrans ((add (Db sdt4) yt5)) (inf-pow h) (inf-pow w) (inf-basele (Db sdt4) ((De sdt4)) yt5 (inf-pow h) t5e7 (hdb sdt4 ((inf-lelts sdt4 29 g10)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))
 )
 (defvcs inf-vc-block-i11 1 inf-block-c5 ()
  (inf-lt (add opi1 nd) (inf-pow w)) (inf-lelt (add opi1 nd) (add cap nd) (inf-pow w) (inf-addr opi1 cap nd k7) gnd)
 )
 (defvcs inf-vc-block-i12 1 inf-block-c5 (g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)))
  (inf-le opi1 cap) k7
 )
 (defvcs inf-vc-block-c1 1 inf-block-c5 (g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)) g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1)) g13 (inf-lt 0 out))
  (inf-le 32 w) gw
  (inf-lt (add (Db sdt4) yt5) (inf-pow w)) ((inf-lttrans ((add (Db sdt4) yt5)) (inf-pow h) (inf-pow w) (inf-basele (Db sdt4) ((De sdt4)) yt5 (inf-pow h) t5e7 (hdb sdt4 ((inf-lelts sdt4 29 g10)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))
  (inf-le (add (Db sdt4) yt5) (add opi1 nd)) g11
  (inf-le (add opi1 (add (Lb (natminus syt2 257)) xt3)) cap) ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7))
  (inf-lt 0 out) g13
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
 )
 (defcx inf-block-c7 inf-block-c5 (g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd))) (g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1))) (g13 (inf-lt 0 out)) )
 (defcx inf-block-c6 inf-block-c5 (g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd))) (g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1))) )
 (defvcs inf-vc-block-s6 1 inf-block-c6 ()
  (inf-lt (add opi1 (add (Lb (natminus syt2 257)) xt3)) (inf-pow w)) (inf-lelt (add opi1 ((add (Lb ((natminus syt2 257))) xt3))) cap (inf-pow w) ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
 )
 (defvcs inf-vc-block-w1b 8 inf-block-c6 ()
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv carry ipt5 const5 bct5) t5e4
  (inf-le cons0 const5) (inf-letrans cons0 const4 const5 (inf-letrans cons0 const3 const4 (inf-letrans cons0 const2 const3 (inf-letrans cons0 consi1 const2 k5 t2e5) t3e5) t4e5) t5e5)
  (inf-le op0 (add opi1 (add (Lb (natminus syt2 257)) xt3))) (inf-letrans op0 opi1 (add opi1 ((add (Lb ((natminus syt2 257))) xt3))) ((inf-letrans op0 op opi1 j6 ((inf-letr o0 op opi1 eo k6)))) (inf-leaddr opi1 ((add (Lb ((natminus syt2 257))) xt3))))
  (inf-le (add opi1 (add (Lb (natminus syt2 257)) xt3)) cap) ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7))
  (inf-lt (natminus cap (add opi1 (add (Lb (natminus syt2 257)) xt3))) (natminus cap op)) (inf-subfrom op opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) ((inf-letr o0 op opi1 eo k6)) ((inf-lttrans opi1 (add opi1 ((add (Lb ((natminus syt2 257))) xt3))) cap (inf-ltaddpos opi1 ((add (Lb ((natminus syt2 257))) xt3)) ((inf-lttrans 0 3 ((add (Lb ((natminus syt2 257))) xt3)) (idpath true) (inf-letrans 3 (Lb ((natminus syt2 257))) ((add (Lb ((natminus syt2 257))) xt3)) (hlc ((natminus syt2 257)) ((inf-lidx syt2 g9))) (inf-leaddr (Lb ((natminus syt2 257))) xt3))))) ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7)))) ((inf-lttrans 0 3 ((add (Lb ((natminus syt2 257))) xt3)) (idpath true) (inf-letrans 3 (Lb ((natminus syt2 257))) ((add (Lb ((natminus syt2 257))) xt3)) (hlc ((natminus syt2 257)) ((inf-lidx syt2 g9))) (inf-leaddr (Lb ((natminus syt2 257))) xt3)))))
 )
 (defcx inf-go (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv 0 ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (gcf (inf-lt (add cap 266) (inf-pow w))) (Ob (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) )
 (defvcs inf-vc-go-w1e 1 inf-go ()
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv 0 ip0 cons0 bc0) ga
  (inf-le op0 cap) gop
 )
 (defcx inf-go-w1 inf-go (last nat) (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (Lc (pi j nat nat)) (Ls (pi j nat nat)) (Lt (pi j nat nat)) (Dc (pi j nat nat)) (Ds (pi j nat nat)) (Dt (pi j nat nat)) (lm nat) (dm nat) (j1 (inf-le ip n)) (j3 (inf-le bc 63)) (j4 (inf-bits-inv 0 ip cons bc)) (j7 (inf-le op cap)) )
 (defvcs inf-vc-go-t1 1 inf-go-w1 (w1 (paths nat last 0) c0 nat ec (paths nat c0 cons))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv 0 ip cons bc) j4
  (inf-le 1 13) (idpath false)
 )
 (defcx inf-go-c1 inf-go-w1 (w1 (paths nat last 0)) (c0 nat) (ec (paths nat c0 cons)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (lastt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv 0 ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e6 (inf-le (add cons 1) const1)) (t1e7 (inf-lt lastt1 (inf-pow 1))) )
 (defvcs inf-vc-go-t2 1 inf-go-c1 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv 0 ipt1 const1 bct1) t1e4
  (inf-le 2 13) (idpath false)
 )
 (defcx inf-go-c2 inf-go-c1 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (typt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv 0 ipt2 const2 bct2)) (t2e5 (inf-le const1 const2)) (t2e6 (inf-le (add const1 2) const2)) (t2e7 (inf-lt typt2 (inf-pow 2))) )
 (defvcs inf-vc-go-t3 1 inf-go-c2 (g1 (paths nat typt2 0))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv 0 ipt2 const2 bct2) t2e4
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
  (inf-le op cap) j7
  (inf-lt (add cap nd) (inf-pow w)) gnd
 )
 (defcx inf-go-c7 inf-go-c2 (g1 (paths nat typt2 0)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (opt3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv 0 ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e8 (inf-le opt3 cap)) (t3e9 (inf-le op opt3)) )
 (defvcs inf-vc-go-w1b 1 inf-go-c7 ()
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv 0 ipt3 const3 bct3) t3e4
  (inf-le opt3 cap) t3e8
  (inf-lt (natminus (inf-by8 n) const3) (natminus (inf-by8 n) cons)) (inf-consfall 0 ipt3 const3 bct3 n cons t3e4 t3e1 (inf-lttrans cons (add cons 1) const3 ((inf-ltaddpos cons 1 (idpath true))) (inf-letrans (add cons 1) const2 const3 (inf-letrans (add cons 1) const1 const2 t1e6 t2e5) t3e5)))
 )
 (defvcs inf-vc-go-c1 1 inf-go-c2 (g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-le typt2 1))
  (inf-le 32 w) gw
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
 )
 (defcx inf-go-c6 inf-go-c2 (g1 (inf-lt 0 typt2)) (g2 (inf-lt typt2 3)) (g3 (inf-le typt2 1)) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) )
 (defvcs inf-vc-go-i3j 1 inf-go-c6 ()
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv 0 ipt2 const2 bct2) t2e4
  (inf-le const2 const2) (inf-refl const2)
  (pi k nat (inf-lt (Lcc1 k) (inf-pow h))) c1c1
  (pi k nat (inf-lt (Lsc1 k) (inf-pow h))) c1c2
  (inf-le (inf-sum Lcc1 15 1) lmc1) c1c3
  (inf-le lmc1 288) c1c4
  (pi k nat (inf-lt (Dcc1 k) (inf-pow h))) c1c5
  (pi k nat (inf-lt (Dsc1 k) (inf-pow h))) c1c6
  (inf-le (inf-sum Dcc1 15 1) dmc1) c1c7
  (inf-le dmc1 32) c1c8
 )
 (defvcs inf-vc-go-t4 1 inf-go-c2 (g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv 0 ipt2 const2 bct2) t2e4
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
  (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)) hord
 )
 (defcx inf-go-c5 inf-go-c2 (g1 (inf-lt 0 typt2)) (g2 (inf-lt typt2 3)) (g3 (inf-lt 1 typt2)) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (Lct4 (pi j nat nat)) (Lst4 (pi j nat nat)) (Ltt4 (pi j nat nat)) (Dct4 (pi j nat nat)) (Dst4 (pi j nat nat)) (Dtt4 (pi j nat nat)) (lmt4 nat) (dmt4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv 0 ipt4 const4 bct4)) (t4e5 (inf-le const2 const4)) (t4c1 (pi k nat (inf-lt (Lct4 k) (inf-pow h)))) (t4c2 (pi k nat (inf-lt (Lst4 k) (inf-pow h)))) (t4c3 (inf-le (inf-sum Lct4 15 1) lmt4)) (t4c4 (inf-le lmt4 288)) (t4c5 (pi k nat (inf-lt (Dct4 k) (inf-pow h)))) (t4c6 (pi k nat (inf-lt (Dst4 k) (inf-pow h)))) (t4c7 (inf-le (inf-sum Dct4 15 1) dmt4)) (t4c8 (inf-le dmt4 32)) )
 (defvcs inf-vc-go-i3j 13 inf-go-c5 ()
  (inf-le ipt4 n) t4e1
  (inf-le bct4 63) t4e3
  (inf-bits-inv 0 ipt4 const4 bct4) t4e4
  (inf-le const2 const4) t4e5
  (pi k nat (inf-lt (Lct4 k) (inf-pow h))) t4c1
  (pi k nat (inf-lt (Lst4 k) (inf-pow h))) t4c2
  (inf-le (inf-sum Lct4 15 1) lmt4) t4c3
  (inf-le lmt4 288) t4c4
  (pi k nat (inf-lt (Dct4 k) (inf-pow h))) t4c5
  (pi k nat (inf-lt (Dst4 k) (inf-pow h))) t4c6
  (inf-le (inf-sum Dct4 15 1) dmt4) t4c7
  (inf-le dmt4 32) t4c8
 )
 (defcx inf-go-c3 inf-go-c2 (g1 (inf-lt 0 typt2)) (g2 (inf-lt typt2 3)) (Lci3 (pi j nat nat)) (Lsi3 (pi j nat nat)) (Lti3 (pi j nat nat)) (Dci3 (pi j nat nat)) (Dsi3 (pi j nat nat)) (Dti3 (pi j nat nat)) (lmi3 nat) (dmi3 nat) (ipi3 nat) (bci3 nat) (bbi3 nat) (consi3 nat) (k1 (inf-le ipi3 n)) (k3 (inf-le bci3 63)) (k4 (inf-bits-inv 0 ipi3 consi3 bci3)) (k5 (inf-le const2 consi3)) (c1 (pi k nat (inf-lt (Lci3 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Lsi3 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lci3 15 1) lmi3)) (c4 (inf-le lmi3 288)) (c5 (pi k nat (inf-lt (Dci3 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Dsi3 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dci3 15 1) dmi3)) (c8 (inf-le dmi3 32)) )
 (defvcs inf-vc-go-t5 1 inf-go-c3 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipi3 n) k1
  (inf-le bci3 63) k3
  (inf-bits-inv 0 ipi3 consi3 bci3) k4
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
  (inf-le op cap) j7
  (inf-lt (add cap nd) (inf-pow w)) gnd
  (inf-lt (add cap 266) (inf-pow w)) gcf
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le h 16) gh
  (pi k nat (inf-lt (Lci3 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Lsi3 k) (inf-pow h))) c2
  (inf-le (inf-sum Lci3 15 1) lmi3) c3
  (inf-le lmi3 288) c4
  (pi k nat (inf-lt (Dci3 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Dsi3 k) (inf-pow h))) c6
  (inf-le (inf-sum Dci3 15 1) dmi3) c7
  (inf-le dmi3 32) c8
  (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)) hle
  (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)) hlb
  (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))) hlc
  (pi k nat g (inf-lt k 30) (inf-le (De k) 13)) hde
  (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))) hdb
 )
 (defcx inf-go-c4 inf-go-c3 (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (opt5 nat) (xt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv 0 ipt5 const5 bct5)) (t5e5 (inf-le consi3 const5)) (t5e8 (inf-le opt5 cap)) (t5e9 (inf-le op opt5)) )
 (defvcs inf-vc-go-w1b 6 inf-go-c4 ()
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv 0 ipt5 const5 bct5) t5e4
  (inf-le opt5 cap) t5e8
  (inf-lt (natminus (inf-by8 n) const5) (natminus (inf-by8 n) cons)) (inf-consfall 0 ipt5 const5 bct5 n cons t5e4 t5e1 (inf-lttrans cons (add cons 1) const5 ((inf-ltaddpos cons 1 (idpath true))) (inf-letrans (add cons 1) consi3 const5 (inf-letrans (add cons 1) const2 consi3 (inf-letrans (add cons 1) const1 const2 t1e6 t2e5) k5) t5e5)))
 )
 (defcx inf-top (In (pi k nat nat)) (n nat) (w nat) (out nat) (oc nat) (cap nat) (nd nat) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (gw (inf-le 32 w)) (go (pi g (inf-lt 0 out) (paths nat oc cap))) )
 (defvcs inf-vc-top-c1 1 inf-top (g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) g1
  (inf-le 0 n) (idpath false)
  (inf-le 0 63) (idpath false)
  (inf-bits-inv 0 0 0 0) (idpath 0)
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) (inf-lelt (add cap 8) (add cap 266) (inf-pow w) (inf-addl cap 8 266 (idpath false)) g2)
  (inf-le 0 cap) (idpath false)
  (inf-lt (add cap nd) (inf-pow w)) g3
  (inf-le 16 16) (idpath false)
  (inf-le (inf-by16 (inf-pow 12)) (inf-pow 16)) inf-topq
  (inf-lt 320 (inf-pow 12)) (idpath true)
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk (inf-pow 12) k) (inf-pow w))) (inf-topk w gw)
  (inf-le 12 15) (idpath false)
  (inf-le 9 15) (idpath false)
  (inf-le 7 15) (idpath false)
  (inf-lt (add cap 266) (inf-pow w)) g2
  (pi k nat g (inf-lt k 19) (inf-lt (inf-tob k) 19)) (lam k g (inf-lelts (inf-tob k) 18 (inf-anyno (lam j (natgtb (inf-tob j) 18)) 19 (idpath false) k g)))
  (pi k nat g (inf-lt k 29) (inf-le (inf-tle k) 5)) (inf-anyno (lam j (natgtb (inf-tle j) 5)) 29 (idpath false))
  (pi k nat g (inf-lt k 29) (inf-le (add (inf-tlb k) (inf-pow (inf-tle k))) 259)) (inf-anyno (lam j (natgtb (add (inf-tlb j) (inf-pow (inf-tle j))) 259)) 29 (idpath false))
  (pi k nat g (inf-lt k 29) (inf-le 3 (inf-tlb k))) (inf-anyno (lam j (natgtb 3 (inf-tlb j))) 29 (idpath false))
  (pi k nat g (inf-lt k 30) (inf-le (inf-tde k) 13)) (inf-anyno (lam j (natgtb (inf-tde j) 13)) 30 (idpath false))
  (pi k nat g (inf-lt k 30) (inf-le (add (inf-tdb k) (inf-pow (inf-tde k))) (inf-pow 16))) (inf-anyno (lam j (natgtb (add (inf-tdb j) (inf-pow (inf-tde j))) (inf-pow 16))) 30 (idpath false))
 )
 (defcx inf-top-c1 inf-top (g1 (inf-lt (add n 8) (inf-pow w))) (g2 (inf-lt (add cap 266) (inf-pow w))) (g3 (inf-lt (add cap nd) (inf-pow w))) (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (opc1 nat) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (xc1 nat) )
 (defcx inf-sy1 (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Cn (pi i nat nat)) (Sy (pi i nat nat)) (Tb (pi i nat nat)) (m nat) (h nat) (root nat) (hc (pi i nat (inf-lt (Cn i) (inf-pow h)))) (hs (pi i nat (inf-lt (Sy i) (inf-pow h)))) (gh (inf-le h 16)) (gm (inf-lt m (inf-pow w))) (gt (inf-le (inf-sum Cn 15 1) m)) (gr (inf-le root 15)) )
 (defvcs inf-vc-sy1-c1 1 inf-sy1 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
 )
 (defcx inf-sy1-c1 inf-sy1 (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
 (defvcs inf-vc-sy1-r1 1 inf-sy1-c1 (g1 (inf-lt bcc1 15) g2 (inf-lt 0 n))
  (inf-le ipc1 n) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv carry ipc1 consc1 bcc1) c1e4
  (inf-le cons0 consc1) c1e5
 )
 (defvcs inf-vc-sy1-t1 1 inf-sy1-c1 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipc1 n) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv carry ipc1 consc1 bcc1) c1e4
  (pi i nat (inf-lt (Cn i) (inf-pow h))) hc
  (pi i nat (inf-lt (Sy i) (inf-pow h))) hs
  (inf-le h 16) gh
  (inf-lt m (inf-pow w)) gm
  (inf-le (inf-sum Cn 15 1) m) gt
  (inf-le root 15) gr
 )
 (defvcs inf-vc-sy1-t1s 1 inf-sy1-c1 (ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le consc1 const1))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 consc1 const1 c1e5 t1e5)
 )
 (defcx inf-sy1-c2 inf-sy1-c1 (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le consc1 const1)) )
 (defvcs inf-vc-sy1-r2 1 inf-sy1-c2 ()
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 consc1 const1 c1e5 t1e5)
 )
 (defcx inf-sthead (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (last0 nat) (mode0 nat) (stage0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) )
 (defvcs inf-vc-sthead-t1 1 inf-sthead ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le 3 13) (idpath false)
 )
 (defvcs inf-vc-sthead-t1s 1 inf-sthead (ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) t1e5
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
 )
 (defcx inf-sthead-c1 inf-sthead (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons0 const1)) (t1e6 (inf-le (add cons0 3) const1)) (t1e7 (inf-lt xt1 (inf-pow 3))) )
 (defvcs inf-vc-sthead-d2 1 inf-sthead-c1 (lastd1 nat)
  (inf-lt 1 64) (idpath true)
 )
 (defvcs inf-vc-sthead-d3 1 inf-sthead-c1 (lastd1 nat typd2 nat g1 (paths nat typd2 0))
  (inf-lt (inf-mod 8 bct1) (inf-pow w)) (inf-wlit (inf-mod 8 bct1) w gw (inf-letrans (inf-mod 8 bct1) 7 63 (inf-ltsle (inf-mod 8 bct1) 7 (inf-modlt 7 bct1)) (idpath false)))
 )
 (defvcs inf-vc-sthead-d4a 1 inf-sthead-c1 (lastd1 nat typd2 nat g1 (paths nat typd2 0))
  (inf-lt (inf-mod 8 bct1) 64) (inf-lelts (inf-mod 8 bct1) 63 (inf-letrans (inf-mod 8 bct1) 7 63 (inf-ltsle (inf-mod 8 bct1) 7 (inf-modlt 7 bct1)) (idpath false)))
 )
 (defvcs inf-vc-sthead-d4b 1 inf-sthead-c1 (lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat)
  (inf-le (inf-mod 8 bct1) bct1) (inf-modle8 bct1)
  (inf-lt (natminus bct1 (inf-mod 8 bct1)) (inf-pow w)) (inf-wlit (natminus bct1 (inf-mod 8 bct1)) w gw (inf-letrans (natminus bct1 (inf-mod 8 bct1)) bct1 63 (inf-suble bct1 (inf-mod 8 bct1)) t1e3))
 )
 (defvcs inf-vc-sthead-r2 1 inf-sthead-c1 (lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat)
  (inf-le ipt1 n) t1e1
  (inf-le (natminus bct1 (inf-mod 8 bct1)) 63) (inf-letrans (natminus bct1 (inf-mod 8 bct1)) bct1 63 (inf-suble bct1 (inf-mod 8 bct1)) t1e3)
  (inf-bits-inv carry ipt1 (add const1 (inf-mod 8 bct1)) (natminus bct1 (inf-mod 8 bct1))) (inf-take carry ipt1 const1 bct1 (inf-mod 8 bct1) (inf-letrans (inf-mod 8 bct1) bct1 bct1 (inf-modle8 bct1) (inf-refl bct1)) t1e4)
  (inf-le cons0 (add const1 (inf-mod 8 bct1))) (inf-letrans cons0 const1 (add const1 (inf-mod 8 bct1)) t1e5 (inf-leaddr const1 (inf-mod 8 bct1)))
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le (add cons0 3) (add const1 (inf-mod 8 bct1))) (inf-letrans (add cons0 3) const1 (add const1 (inf-mod 8 bct1)) t1e6 (inf-leaddr const1 (inf-mod 8 bct1)))
 )
 (defvcs inf-vc-sthead-r1 1 inf-sthead-c1 (lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) t1e5
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
 )
 (defvcs inf-vc-sthead-c1 1 inf-sthead-c1 (lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-le typd2 1))
  (inf-le 32 w) gw
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
 )
 (defcx inf-sthead-c2 inf-sthead-c1 (lastd1 nat) (typd2 nat) (g1 (inf-lt 0 typd2)) (g2 (inf-lt typd2 3)) (g3 (inf-le typd2 1)) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) )
 (defvcs inf-vc-sthead-r2 14 inf-sthead-c2 (moded6 nat staged7 nat)
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) t1e5
  (pi k nat (inf-lt (Lcc1 k) (inf-pow h))) c1c1
  (pi k nat (inf-lt (Lsc1 k) (inf-pow h))) c1c2
  (inf-le (inf-sum Lcc1 15 1) lmc1) c1c3
  (inf-le lmc1 288) c1c4
  (pi k nat (inf-lt (Dcc1 k) (inf-pow h))) c1c5
  (pi k nat (inf-lt (Dsc1 k) (inf-pow h))) c1c6
  (inf-le (inf-sum Dcc1 15 1) dmc1) c1c7
  (inf-le dmc1 32) c1c8
  (inf-le (add cons0 3) const1) t1e6
 )
 (defvcs inf-vc-sthead-r2 27 inf-sthead-c1 (lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat)
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) t1e5
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le (add cons0 3) const1) t1e6
 )
 (defcx inf-stlen (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (rem0 nat) (mode0 nat) )
 (defvcs inf-vc-stlen-c1 1 inf-stlen ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
 )
 (defcx inf-stlen-c1 inf-stlen (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
 (defvcs inf-vc-stlen-r1 1 inf-stlen-c1 (g1 (inf-lt bcc1 32))
  (inf-le ipc1 n) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv carry ipc1 consc1 bcc1) c1e4
  (inf-le cons0 consc1) c1e5
 )
 (defvcs inf-vc-stlen-d1 1 inf-stlen-c1 (g1 (inf-le 32 bcc1))
  (inf-lt 16 32) (idpath true)
 )
 (defvcs inf-vc-stlen-d2 1 inf-stlen-c1 (g1 (inf-le 32 bcc1) lnd1 nat)
  (inf-lt 16 64) (idpath true)
 )
 (defvcs inf-vc-stlen-d3 1 inf-stlen-c1 (g1 (inf-le 32 bcc1) lnd1 nat yd2 nat)
  (inf-lt 16 32) (idpath true)
 )
 (defvcs inf-vc-stlen-r2 1 inf-stlen-c1 (g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit)
  (inf-le ipc1 n) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv carry ipc1 consc1 bcc1) c1e4
  (inf-le cons0 consc1) c1e5
 )
 (defvcs inf-vc-stlen-d4a 1 inf-stlen-c1 (g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit)
  (inf-lt 32 64) (idpath true)
 )
 (defvcs inf-vc-stlen-d4b 1 inf-stlen-c1 (g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit bbd4a nat)
  (inf-le 32 bcc1) g1
  (inf-lt (natminus bcc1 32) (inf-pow w)) (inf-wlit (natminus bcc1 32) w gw (inf-letrans (natminus bcc1 32) bcc1 63 (inf-suble bcc1 32) c1e3))
 )
 (defvcs inf-vc-stlen-r3 1 inf-stlen-c1 (g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit bbd4a nat remd5 nat moded6 nat)
  (inf-le ipc1 n) c1e1
  (inf-le (natminus bcc1 32) 63) (inf-letrans (natminus bcc1 32) bcc1 63 (inf-suble bcc1 32) c1e3)
  (inf-bits-inv carry ipc1 (add consc1 32) (natminus bcc1 32)) (inf-take carry ipc1 consc1 bcc1 32 g1 c1e4)
  (inf-le cons0 (add consc1 32)) (inf-letrans cons0 consc1 (add consc1 32) c1e5 (inf-leaddr consc1 32))
 )
 (defcx inf-sttab (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Cl0 (pi k nat nat)) (a2 (pi k nat (inf-le (Cl0 k) 15))) (hlit0 nat) (hdist0 nat) (hclen0 nat) (i0 nat) (mode0 nat) )
 (defvcs inf-vc-sttab-c1 1 inf-sttab ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
 )
 (defcx inf-sttab-c1 inf-sttab (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
 (defvcs inf-vc-sttab-r1 1 inf-sttab-c1 (g1 (inf-lt bcc1 14))
  (inf-le ipc1 n) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv carry ipc1 consc1 bcc1) c1e4
  (inf-le cons0 consc1) c1e5
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defvcs inf-vc-sttab-d1 1 inf-sttab-c1 (g1 (inf-le 14 bcc1))
  (inf-lt 5 32) (idpath true)
  (inf-lt (add (inf-mod (inf-pow 5) bbc1) 257) (inf-pow w)) (inf-lelt (add ((inf-mod (inf-pow 5) bbc1)) 257) 288 (inf-pow w) (inf-addr ((inf-mod (inf-pow 5) bbc1)) 31 257 (inf-ltsle ((inf-mod (inf-pow 5) bbc1)) 31 (inf-masklt bbc1 5))) (inf-wfit288 w gw))
 )
 (defvcs inf-vc-sttab-d2 1 inf-sttab-c1 (g1 (inf-le 14 bcc1) hlitd1 nat)
  (inf-lt 5 64) (idpath true)
 )
 (defvcs inf-vc-sttab-d3 1 inf-sttab-c1 (g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat)
  (inf-lt 5 32) (idpath true)
  (inf-lt (add (inf-mod (inf-pow 5) yd2) 1) (inf-pow w)) (inf-wlit (add ((inf-mod (inf-pow 5) yd2)) 1) w gw (inf-letrans (add ((inf-mod (inf-pow 5) yd2)) 1) 32 63 (inf-addr ((inf-mod (inf-pow 5) yd2)) 31 1 (inf-ltsle ((inf-mod (inf-pow 5) yd2)) 31 (inf-masklt yd2 5))) (idpath false)))
 )
 (defvcs inf-vc-sttab-d4 1 inf-sttab-c1 (g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat)
  (inf-lt 10 64) (idpath true)
 )
 (defvcs inf-vc-sttab-d5 1 inf-sttab-c1 (g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat)
  (inf-lt 4 32) (idpath true)
  (inf-lt (add (inf-mod (inf-pow 4) yd4) 4) (inf-pow w)) (inf-wlit (add ((inf-mod (inf-pow 4) yd4)) 4) w gw (inf-letrans (add ((inf-mod (inf-pow 4) yd4)) 4) 19 63 (inf-addr ((inf-mod (inf-pow 4) yd4)) 15 4 (inf-ltsle ((inf-mod (inf-pow 4) yd4)) 15 (inf-masklt yd4 4))) (idpath false)))
 )
 (defvcs inf-vc-sttab-d6a 1 inf-sttab-c1 (g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat)
  (inf-lt 14 64) (idpath true)
 )
 (defvcs inf-vc-sttab-d6b 1 inf-sttab-c1 (g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat bbd6a nat)
  (inf-le 14 bcc1) g1
  (inf-lt (natminus bcc1 14) (inf-pow w)) (inf-wlit (natminus bcc1 14) w gw (inf-letrans (natminus bcc1 14) bcc1 63 (inf-suble bcc1 14) c1e3))
 )
 (defvcs inf-vc-sttab-r2 1 inf-sttab-c1 (g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat bbd6a nat id7 nat moded8 nat)
  (inf-le ipc1 n) c1e1
  (inf-le (natminus bcc1 14) 63) (inf-letrans (natminus bcc1 14) bcc1 63 (inf-suble bcc1 14) c1e3)
  (inf-bits-inv carry ipc1 (add consc1 14) (natminus bcc1 14)) (inf-take carry ipc1 consc1 bcc1 14 g1 c1e4)
  (inf-le cons0 (add consc1 14)) (inf-letrans cons0 consc1 (add consc1 14) c1e5 (inf-leaddr consc1 14))
  (pi k nat (inf-le (inf-zero k) 15)) (lam k (idpath false))
 )
 (defcx inf-stcl (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hclen nat) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (a2 (pi k nat (inf-le (Cl0 k) 15))) (b2 (pi j nat (inf-le (Lz0 j) 15))) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (i0 nat) (prev0 nat) (stage0 nat) (mode0 nat) (b1 (inf-le prev0 15)) )
 (defvcs inf-vc-stcl-r0 1 inf-stcl (g0 (inf-lt 19 hclen))
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defvcs inf-vc-stcl-w1e 1 inf-stcl (g0 (inf-le hclen 19))
  (pi k nat (inf-le (Cl0 k) 15)) a2
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
 )
 (defcx inf-stcl-w1 inf-stcl (g0 (inf-le hclen 19)) (ip nat) (bc nat) (bb nat) (cons nat) (Cl (pi j nat nat)) (i nat) (a2 (pi k nat (inf-le (Cl k) 15))) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) )
 (defvcs inf-vc-stcl-t1 1 inf-stcl-w1 (w1 (inf-lt i hclen))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le 3 13) (idpath false)
 )
 (defvcs inf-vc-stcl-t1s 1 inf-stcl-w1 (w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 r5 t1e5)
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl k) 15)) a2
 )
 (defcx inf-stcl-c1 inf-stcl-w1 (w1 (inf-lt i hclen)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e6 (inf-le (add cons 3) const1)) (t1e7 (inf-lt xt1 (inf-pow 3))) )
 (defvcs inf-vc-stcl-s1 1 inf-stcl-c1 ()
  (inf-lt i 19) ((inf-lttrans i hclen 19 w1 g0))
  (inf-lt (Ob i) 19) (hord i ((inf-lttrans i hclen 19 w1 g0)))
  (inf-lt xt1 (inf-pow w)) (inf-lttrans xt1 8 (inf-pow w) t1e7 (inf-powle 3 w (inf-letrans 3 32 w (idpath false) gw)))
 )
 (defvcs inf-vc-stcl-s2 1 inf-stcl-c1 ()
  (inf-lt (add i 1) (inf-pow w)) (inf-wlit (add i 1) w gw (inf-letrans (add i 1) 19 63 (inf-lt1 i 19 ((inf-lttrans i hclen 19 w1 g0))) (idpath false)))
 )
 (defvcs inf-vc-stcl-w1b 1 inf-stcl-c1 ()
  (pi k nat (inf-le ((inf-upd Cl (Ob i) xt1) k) 15)) (inf-updle Cl (Ob i) xt1 15 a2 (inf-letrans xt1 8 15 (inf-ltle xt1 8 t1e7) (idpath false)))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 r5 t1e5)
  (inf-lt (natminus hclen (add i 1)) (natminus hclen i)) (inf-subfall1 hclen i w1)
 )
 (defvcs inf-vc-stcl-c1 1 inf-stcl-w1 (w1 (inf-le hclen i))
  (pi k nat g (inf-lt k 19) (inf-le (Cl k) 15)) (lam k g (a2 k))
  (inf-lt 19 q) (inf-lttrans 19 320 q (idpath true) (inf-ltle 320 q gq2))
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-le (inf-pow h) (inf-pow w)) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
  (inf-le CROOT 15) gc
  (inf-le 32 w) gw
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
 )
 (defcx inf-stcl-c2 inf-stcl-w1 (w1 (inf-le hclen i)) (Ccc1 (pi j nat nat)) (Csc1 (pi j nat nat)) (Ctc1 (pi j nat nat)) (c1e1 (pi z nat (inf-lt (Ccc1 z) (inf-pow h)))) (c1e2 (pi z nat (inf-lt (Csc1 z) (inf-pow h)))) (c1e3 (inf-le (inf-sum Ccc1 15 1) 19)) )
 (defvcs inf-vc-stcl-d2 1 inf-stcl-c2 (id1 nat)
  (inf-lt 0 (inf-pow w)) (inf-wlit 0 w gw (idpath false))
 )
 (defvcs inf-vc-stcl-r2 1 inf-stcl-c2 (id1 nat staged3 nat moded4 nat)
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le cons0 cons) r5
  (pi k nat (inf-lt (Ccc1 k) (inf-pow h))) c1e1
  (pi k nat (inf-lt (Csc1 k) (inf-pow h))) c1e2
  (inf-le (inf-sum Ccc1 15 1) 19) c1e3
  (inf-le 0 15) (idpath false)
  (pi j nat (inf-le (inf-zero j) 15)) (lam j (idpath false))
  (pi k nat (inf-le (Cl k) 15)) a2
 )
 (defcx inf-stln (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Cc (pi k nat nat)) (Cs (pi k nat nat)) (Ct (pi k nat nat)) (d1 (pi k nat (inf-lt (Cc k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc 15 1) 19)) (Lz0 (pi k nat nat)) (hlit nat) (hdist nat) (b2 (pi j nat (inf-le (Lz0 j) 15))) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (mode0 nat) (b1 (inf-le prev0 15)) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) )
 (defvcs inf-vc-stln-r0 1 inf-stln (g0 (inf-lt 288 hlit))
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
 )
 (defvcs inf-vc-stln-r00 1 inf-stln (g0 (inf-le hlit 288) g00 (inf-lt 32 hdist))
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
 )
 (defvcs inf-vc-stln-s0 1 inf-stln (g0 (inf-le hlit 288) g00 (inf-le hdist 32))
  (inf-lt (add hlit hdist) (inf-pow w)) (inf-lelt (add hlit hdist) 320 (inf-pow w) ((inf-add2 hlit 288 hdist 32 g0 g00)) ((inf-lelt 320 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-stln-w1e 1 inf-stln (g0 (inf-le hlit 288) g00 (inf-le hdist 32))
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
 )
 (defcx inf-stln-w1 inf-stln (g0 (inf-le hlit 288)) (g00 (inf-le hdist 32)) (ip nat) (bc nat) (bb nat) (cons nat) (Lz (pi j nat nat)) (i nat) (prev nat) (stage nat) (sy nat) (b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) )
 (defvcs inf-vc-stln-t1 1 inf-stln-w1 (w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (pi i nat (inf-lt (Cc i) (inf-pow h))) d1
  (pi i nat (inf-lt (Cs i) (inf-pow h))) d2
  (inf-le h 16) gh
  (inf-lt 19 (inf-pow w)) (inf-wlit 19 w gw (idpath false))
  (inf-le (inf-sum Cc 15 1) 19) d3
  (inf-le CROOT 15) gc
 )
 (defvcs inf-vc-stln-t1s 1 inf-stln-w1 (w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 r5 t1e5)
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
 )
 (defcx inf-stln-c8 inf-stln-w1 (w1 (inf-lt i (add hlit hdist))) (g2 (paths nat stage 0)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) )
 (defvcs inf-vc-stln-j0j 1 inf-stln-c8 (syd1 nat staged2 nat)
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 r5 t1e5)
 )
 (defvcs inf-vc-stln-j0j 5 inf-stln-w1 (w1 (inf-lt i (add hlit hdist)) g2 (inf-lt 0 stage))
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le cons0 cons) r5
 )
 (defcx inf-stln-c1 inf-stln-w1 (w1 (inf-lt i (add hlit hdist))) (ipj0 nat) (bcj0 nat) (bbj0 nat) (consj0 nat) (syj0 nat) (stagej0 nat) (r1 (inf-le ipj0 n)) (r3 (inf-le bcj0 63)) (r4 (inf-bits-inv carry ipj0 consj0 bcj0)) (r5 (inf-le cons0 consj0)) )
 (defvcs inf-vc-stln-s1 1 inf-stln-c1 (g3 (inf-lt syj0 16))
  (inf-lt 1 (inf-pow w)) (inf-wlit 1 w gw (idpath false))
 )
 (defvcs inf-vc-stln-s2 1 inf-stln-c1 (g3 (inf-lt syj0 16))
  (inf-lt syj0 (inf-pow w)) (inf-wlit syj0 w gw (inf-letrans syj0 16 63 (inf-ltle syj0 16 g3) (idpath false)))
 )
 (defvcs inf-vc-stln-j1j 1 inf-stln-c1 (g3 (inf-lt syj0 16))
  (inf-lt 0 1) (idpath true)
  (inf-le 1 138) (idpath false)
  (inf-le syj0 15) (inf-ltsle syj0 15 g3)
  (inf-le ipj0 n) r1
  (inf-le bcj0 63) r3
  (inf-bits-inv carry ipj0 consj0 bcj0) r4
  (inf-le cons0 consj0) r5
 )
 (defvcs inf-vc-stln-r1 1 inf-stln-c1 (g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0))
  (inf-le ipj0 n) r1
  (inf-le bcj0 63) r3
  (inf-bits-inv carry ipj0 consj0 bcj0) r4
  (inf-le cons0 consj0) r5
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
 )
 (defvcs inf-vc-stln-t2 1 inf-stln-c1 (g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj0 n) r1
  (inf-le bcj0 63) r3
  (inf-bits-inv carry ipj0 consj0 bcj0) r4
  (inf-le 2 13) (idpath false)
 )
 (defvcs inf-vc-stln-t2s 1 inf-stln-c1 (g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2))
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consj0 const2 r5 t2e5)
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
 )
 (defcx inf-stln-c7 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (g5 (inf-le syj0 16)) (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le consj0 const2)) (t2e6 (inf-le (add consj0 2) const2)) (t2e7 (inf-lt xt2 (inf-pow 2))) )
 (defvcs inf-vc-stln-s3 1 inf-stln-c7 ()
  (inf-lt (add xt2 3) (inf-pow w)) (inf-wlit (add xt2 3) w gw (inf-letrans (add xt2 3) 6 63 ((inf-addr xt2 3 3 (inf-ltsle xt2 3 t2e7))) (idpath false)))
 )
 (defvcs inf-vc-stln-s4 1 inf-stln-c7 ()
  (inf-lt prev (inf-pow w)) (inf-wlit prev w gw (inf-letrans prev 15 63 b1 (idpath false)))
 )
 (defvcs inf-vc-stln-j2j 1 inf-stln-c7 ()
  (inf-lt 0 (add xt2 3)) (inf-pos3 xt2 3 (idpath true))
  (inf-le (add xt2 3) 138) (inf-letrans (add xt2 3) 6 138 ((inf-addr xt2 3 3 (inf-ltsle xt2 3 t2e7))) (idpath false))
  (inf-le prev 15) b1
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consj0 const2 r5 t2e5)
 )
 (defvcs inf-vc-stln-t3 1 inf-stln-c1 (g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj0 n) r1
  (inf-le bcj0 63) r3
  (inf-bits-inv carry ipj0 consj0 bcj0) r4
  (inf-le 3 13) (idpath false)
 )
 (defvcs inf-vc-stln-t3s 1 inf-stln-c1 (g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3))
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (inf-le cons0 const3) (inf-letrans cons0 consj0 const3 r5 t3e5)
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
 )
 (defcx inf-stln-c6 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (g5 (inf-lt 16 syj0)) (g6 (inf-le syj0 17)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le consj0 const3)) (t3e6 (inf-le (add consj0 3) const3)) (t3e7 (inf-lt xt3 (inf-pow 3))) )
 (defvcs inf-vc-stln-s5 1 inf-stln-c6 ()
  (inf-lt (add xt3 3) (inf-pow w)) (inf-wlit (add xt3 3) w gw (inf-letrans (add xt3 3) 10 63 ((inf-addr xt3 7 3 (inf-ltsle xt3 7 t3e7))) (idpath false)))
 )
 (defvcs inf-vc-stln-j3j 1 inf-stln-c6 ()
  (inf-lt 0 (add xt3 3)) (inf-pos3 xt3 3 (idpath true))
  (inf-le (add xt3 3) 138) (inf-letrans (add xt3 3) 10 138 ((inf-addr xt3 7 3 (inf-ltsle xt3 7 t3e7))) (idpath false))
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (inf-le cons0 const3) (inf-letrans cons0 consj0 const3 r5 t3e5)
 )
 (defvcs inf-vc-stln-t4 1 inf-stln-c1 (g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj0 n) r1
  (inf-le bcj0 63) r3
  (inf-bits-inv carry ipj0 consj0 bcj0) r4
  (inf-le 7 13) (idpath false)
 )
 (defvcs inf-vc-stln-t4s 1 inf-stln-c1 (g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4))
  (inf-le ipt4 n) t4e1
  (inf-le bct4 63) t4e3
  (inf-bits-inv carry ipt4 const4 bct4) t4e4
  (inf-le cons0 const4) (inf-letrans cons0 consj0 const4 r5 t4e5)
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
 )
 (defcx inf-stln-c5 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (g5 (inf-lt 16 syj0)) (g6 (inf-lt 17 syj0)) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le consj0 const4)) (t4e6 (inf-le (add consj0 7) const4)) (t4e7 (inf-lt xt4 (inf-pow 7))) )
 (defvcs inf-vc-stln-s6 1 inf-stln-c5 ()
  (inf-lt (add xt4 11) (inf-pow w)) (inf-lelt (add xt4 11) 512 (inf-pow w) (inf-letrans (add xt4 11) 138 512 ((inf-addr xt4 127 11 (inf-ltsle xt4 127 t4e7))) (idpath false)) (inf-lttrans 512 1024 (inf-pow w) (idpath true) (inf-powle 10 w (inf-letrans 10 32 w (idpath false) gw))))
 )
 (defvcs inf-vc-stln-j3j 7 inf-stln-c5 ()
  (inf-lt 0 (add xt4 11)) (inf-pos3 xt4 11 (idpath true))
  (inf-le (add xt4 11) 138) ((inf-addr xt4 127 11 (inf-ltsle xt4 127 t4e7)))
  (inf-le ipt4 n) t4e1
  (inf-le bct4 63) t4e3
  (inf-bits-inv carry ipt4 const4 bct4) t4e4
  (inf-le cons0 const4) (inf-letrans cons0 consj0 const4 r5 t4e5)
 )
 (defcx inf-stln-c4 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (g5 (inf-lt 16 syj0)) (ipj3 nat) (bcj3 nat) (bbj3 nat) (consj3 nat) (rrj3 nat) (f1 (inf-lt 0 rrj3)) (f2 (inf-le rrj3 138)) (r1 (inf-le ipj3 n)) (r3 (inf-le bcj3 63)) (r4 (inf-bits-inv carry ipj3 consj3 bcj3)) (r5 (inf-le cons0 consj3)) )
 (defvcs inf-vc-stln-s7 1 inf-stln-c4 ()
  (inf-lt 0 (inf-pow w)) (inf-wlit 0 w gw (idpath false))
 )
 (defvcs inf-vc-stln-j2j 8 inf-stln-c4 ()
  (inf-lt 0 rrj3) f1
  (inf-le rrj3 138) f2
  (inf-le 0 15) (idpath false)
  (inf-le ipj3 n) r1
  (inf-le bcj3 63) r3
  (inf-bits-inv carry ipj3 consj3 bcj3) r4
  (inf-le cons0 consj3) r5
 )
 (defcx inf-stln-c3 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (ipj2 nat) (bcj2 nat) (bbj2 nat) (consj2 nat) (rrj2 nat) (vj2 nat) (f3 (inf-lt 0 rrj2)) (f4 (inf-le rrj2 138)) (f5 (inf-le vj2 15)) (r1 (inf-le ipj2 n)) (r3 (inf-le bcj2 63)) (r4 (inf-bits-inv carry ipj2 consj2 bcj2)) (r5 (inf-le cons0 consj2)) )
 (defvcs inf-vc-stln-j1j 8 inf-stln-c3 ()
  (inf-lt 0 rrj2) f3
  (inf-le rrj2 138) f4
  (inf-le vj2 15) f5
  (inf-le ipj2 n) r1
  (inf-le bcj2 63) r3
  (inf-bits-inv carry ipj2 consj2 bcj2) r4
  (inf-le cons0 consj2) r5
 )
 (defcx inf-stln-c2 inf-stln-c1 (rrj1 nat) (vj1 nat) (ipj1 nat) (bcj1 nat) (bbj1 nat) (consj1 nat) (f6 (inf-lt 0 rrj1)) (f7 (inf-le rrj1 138)) (f8 (inf-le vj1 15)) (r1 (inf-le ipj1 n)) (r3 (inf-le bcj1 63)) (r4 (inf-bits-inv carry ipj1 consj1 bcj1)) (r5 (inf-le cons0 consj1)) )
 (defvcs inf-vc-stln-w3e 1 inf-stln-c2 ()
  (inf-le 0 rrj1) (idpath false)
  (pi j nat (inf-le (Lz j) 15)) b2
 )
 (defcx inf-stln-c2-w3 inf-stln-c2 (k nat) (Lz (pi j nat nat)) (c1 (inf-le k rrj1)) (c2 (pi j nat (inf-le (Lz j) 15))) )
 (defvcs inf-vc-stln-i2 1 inf-stln-c2-w3 (w3 (inf-lt k rrj1))
  (inf-lt (add i k) (inf-pow w)) (inf-lelt (add i k) 458 (inf-pow w) ((inf-add2 i 320 k 138 ((inf-letrans i (add hlit hdist) 320 (inf-ltle i (add hlit hdist) w1) ((inf-add2 hlit 288 hdist 32 g0 g00)))) (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7))) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-stln-s8 1 inf-stln-c2-w3 (w3 (inf-lt k rrj1) g7 (inf-lt (add i k) 320))
  (inf-lt (add i k) (inf-pow w)) (inf-lelt (add i k) 458 (inf-pow w) ((inf-add2 i 320 k 138 ((inf-letrans i (add hlit hdist) 320 (inf-ltle i (add hlit hdist) w1) ((inf-add2 hlit 288 hdist 32 g0 g00)))) (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7))) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
  (inf-lt (add i k) 320) g7
  (inf-lt vj1 (inf-pow w)) (inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false)))
 )
 (defvcs inf-vc-stln-w3b 1 inf-stln-c2-w3 (w3 (inf-lt k rrj1) g7 (inf-lt (add i k) 320))
  (inf-lt (succ k) (inf-pow w)) (inf-lelt (succ k) 138 (inf-pow w) ((inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7)) ((inf-lelt 138 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
  (inf-le (succ k) rrj1) (inf-ltsu k rrj1 w3)
  (pi j nat (inf-le ((inf-upd Lz (add i k) vj1) j) 15)) (inf-updle Lz (add i k) vj1 15 c2 f8)
  (inf-lt (natminus rrj1 (succ k)) (natminus rrj1 k)) (inf-subfall rrj1 k w3)
 )
 (defvcs inf-vc-stln-w3b 5 inf-stln-c2-w3 (w3 (inf-lt k rrj1) g7 (inf-le 320 (add i k)))
  (inf-lt (succ k) (inf-pow w)) (inf-lelt (succ k) 138 (inf-pow w) ((inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7)) ((inf-lelt 138 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
  (inf-le (succ k) rrj1) (inf-ltsu k rrj1 w3)
  (pi j nat (inf-le (Lz j) 15)) c2
  (inf-lt (natminus rrj1 (succ k)) (natminus rrj1 k)) (inf-subfall rrj1 k w3)
 )
 (defvcs inf-vc-stln-s9 1 inf-stln-c2-w3 (w3 (inf-le rrj1 k))
  (inf-lt (add i rrj1) (inf-pow w)) (inf-lelt (add i rrj1) 458 (inf-pow w) (inf-add2 i 320 rrj1 138 ((inf-letrans i (add hlit hdist) 320 (inf-ltle i (add hlit hdist) w1) ((inf-add2 hlit 288 hdist 32 g0 g00)))) f7) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-stln-s10 1 inf-stln-c2-w3 (w3 (inf-le rrj1 k))
  (inf-lt vj1 (inf-pow w)) (inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false)))
 )
 (defvcs inf-vc-stln-w1b 1 inf-stln-c2-w3 (w3 (inf-le rrj1 k) staged3 nat)
  (inf-le vj1 15) f8
  (pi j nat (inf-le (Lz j) 15)) c2
  (inf-le ipj1 n) r1
  (inf-le bcj1 63) r3
  (inf-bits-inv carry ipj1 consj1 bcj1) r4
  (inf-le cons0 consj1) r5
  (inf-lt (natminus (add hlit hdist) (add i rrj1)) (natminus (add hlit hdist) i)) (inf-subby i (add hlit hdist) rrj1 w1 f6)
 )
 (defvcs inf-vc-stln-c4 1 inf-stln-w1 (w1 (inf-le (add hlit hdist) i))
  (pi k nat g (inf-lt k hlit) (inf-le (Lz k) 15)) (lam k g (b2 k))
  (inf-lt hlit q) (inf-lelt hlit 288 q g0 (inf-lttrans 288 320 q (idpath true) ((inf-ltle 320 q gq2))))
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-le (inf-pow h) (inf-pow w)) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
  (inf-le LROOT 15) gl
  (inf-le 32 w) gw
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
 )
 (defcx inf-stln-c9 inf-stln-w1 (w1 (inf-le (add hlit hdist) i)) (Lcc4 (pi j nat nat)) (Lsc4 (pi j nat nat)) (Ltc4 (pi j nat nat)) (c4e1 (pi z nat (inf-lt (Lcc4 z) (inf-pow h)))) (c4e2 (pi z nat (inf-lt (Lsc4 z) (inf-pow h)))) (c4e3 (inf-le (inf-sum Lcc4 15 1) hlit)) )
 (defvcs inf-vc-stln-c5 1 inf-stln-c9 ()
  (pi k nat g (inf-lt k hdist) (inf-le ((inf-shift Lz hlit) k) 15)) (lam k g (b2 (add hlit k)))
  (inf-lt hdist q) (inf-lelt hdist 32 q g00 (inf-lttrans 32 320 q (idpath true) ((inf-ltle 320 q gq2))))
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-le (inf-pow h) (inf-pow w)) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))
  (inf-le DROOT 15) gd
  (inf-le 32 w) gw
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
 )
 (defcx inf-stln-c10 inf-stln-c9 (Dcc5 (pi j nat nat)) (Dsc5 (pi j nat nat)) (Dtc5 (pi j nat nat)) (c5e1 (pi z nat (inf-lt (Dcc5 z) (inf-pow h)))) (c5e2 (pi z nat (inf-lt (Dsc5 z) (inf-pow h)))) (c5e3 (inf-le (inf-sum Dcc5 15 1) hdist)) )
 (defvcs inf-vc-stln-r2 1 inf-stln-c10 (moded6 nat staged7 nat)
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le cons0 cons) r5
  (pi k nat (inf-lt (Lcc4 k) (inf-pow h))) c4e1
  (pi k nat (inf-lt (Lsc4 k) (inf-pow h))) c4e2
  (inf-le (inf-sum Lcc4 15 1) hlit) c4e3
  (inf-le hlit 288) g0
  (pi k nat (inf-lt (Dcc5 k) (inf-pow h))) c5e1
  (pi k nat (inf-lt (Dsc5 k) (inf-pow h))) c5e2
  (inf-le (inf-sum Dcc5 15 1) hdist) c5e3
  (inf-le hdist 32) g00
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
 )
 (defcx inf-ststo (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gz (inf-lt 0 out)) (last nat) (rem0 nat) (mode0 nat) )
 (defvcs inf-vc-ststo-w1e 1 inf-ststo (g0 (inf-lt 0 rem0))
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
  (inf-le op0 op0) (inf-refl op0)
  (inf-le op0 cap) gop
 )
 (defcx inf-ststo-w1 inf-ststo (g0 (inf-lt 0 rem0)) (bc nat) (bb nat) (cons nat) (op nat) (rem nat) (r1 (inf-le ip0 n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip0 cons bc)) (r5 (inf-le cons0 cons)) (o1 (inf-le op0 op)) (o2 (inf-le op cap)) )
 (defvcs inf-vc-ststo-j0j 1 inf-ststo-w1 (w1 (inf-lt 0 rem) g1 (inf-lt bc 8))
  (inf-le ip0 n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip0 cons bc) r4
  (inf-le cons0 cons) r5
  (inf-le op0 op) o1
  (inf-le op cap) o2
 )
 (defvcs inf-vc-ststo-r6 1 inf-ststo-w1 (w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-le cap op))
  (inf-le ip0 n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip0 cons bc) r4
  (inf-le cons0 cons) r5
  (inf-le op cap) o2
  (inf-le op0 op) o1
 )
 (defvcs inf-vc-ststo-p1 1 inf-ststo-w1 (w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap))
  (inf-lt op oc) (inf-lttrans op cap oc g2 ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))
  (inf-lt (inf-mod 256 bb) 256) (inf-lelts (inf-mod 256 bb) 255 (inf-letrans (inf-mod 256 bb) 255 255 (inf-ltsle (inf-mod 256 bb) 255 (inf-modlt 255 bb)) (inf-refl 255)))
 )
 (defvcs inf-vc-ststo-s1 1 inf-ststo-w1 (w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap))
  (inf-lt (add op 1) (inf-pow w)) (inf-lelt (add op 1) cap (inf-pow w) ((inf-lt1 op cap g2)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
 )
 (defvcs inf-vc-ststo-d1a 1 inf-ststo-w1 (w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap))
  (inf-lt 8 64) (idpath true)
 )
 (defvcs inf-vc-ststo-d1b 1 inf-ststo-w1 (w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat)
  (inf-le 8 bc) g1
  (inf-lt (natminus bc 8) (inf-pow w)) (inf-wlit (natminus bc 8) w gw (inf-letrans (natminus bc 8) bc 63 (inf-suble bc 8) r3))
 )
 (defvcs inf-vc-ststo-s2 1 inf-ststo-w1 (w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat)
  (inf-le 1 rem) (inf-ltsu 0 rem w1)
 )
 (defvcs inf-vc-ststo-w1b 1 inf-ststo-w1 (w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat)
  (inf-le ip0 n) r1
  (inf-le (natminus bc 8) 63) (inf-letrans (natminus bc 8) bc 63 (inf-suble bc 8) r3)
  (inf-bits-inv carry ip0 (add cons 8) (natminus bc 8)) (inf-take carry ip0 cons bc 8 g1 r4)
  (inf-le cons0 (add cons 8)) (inf-letrans cons0 cons (add cons 8) r5 (inf-leaddr cons 8))
  (inf-le op0 (add op 1)) (inf-letrans op0 op (add op 1) o1 (inf-leaddr op 1))
  (inf-le (add op 1) cap) ((inf-lt1 op cap g2))
  (inf-lt (natminus rem 1) rem) (inf-dec1 rem w1)
 )
 (defvcs inf-vc-ststo-j0j 7 inf-ststo-w1 (w1 (paths nat rem 0))
  (inf-le ip0 n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip0 cons bc) r4
  (inf-le cons0 cons) r5
  (inf-le op0 op) o1
  (inf-le op cap) o2
 )
 (defvcs inf-vc-ststo-j0j 13 inf-ststo (g0 (paths nat rem0 0))
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
  (inf-le op0 op0) (inf-refl op0)
  (inf-le op0 cap) gop
 )
 (defcx inf-ststo-c1 inf-ststo (opj0 nat) (bbj0 nat) (bcj0 nat) (consj0 nat) (remj0 nat) (r1 (inf-le ip0 n)) (r3 (inf-le bcj0 63)) (r4 (inf-bits-inv carry ip0 consj0 bcj0)) (r5 (inf-le cons0 consj0)) (o1 (inf-le op0 opj0)) (o2 (inf-le opj0 cap)) )
 (defvcs inf-vc-ststo-s3 1 inf-ststo-c1 (g3 (inf-lt 0 remj0) bbd2 nat)
  (inf-le ip0 n) r1
  (inf-lt (natminus n ip0) (inf-pow w)) (inf-lelt (natminus n ip0) (add n 8) (inf-pow w) (inf-letrans (natminus n ip0) n (add n 8) (inf-letrans (natminus n ip0) n n (inf-suble n ip0) (inf-refl n)) (inf-leaddr n 8)) gn)
 )
 (defvcs inf-vc-ststo-s4 1 inf-ststo-c1 (g3 (inf-lt 0 remj0) bbd2 nat g4 (inf-lt remj0 (natminus n ip0)))
  (inf-lt remj0 (inf-pow w)) (inf-lelt remj0 (add n 8) (inf-pow w) (inf-letrans remj0 n (add n 8) (inf-letrans remj0 (natminus n ip0) n (inf-ltle remj0 (natminus n ip0) g4) (inf-letrans (natminus n ip0) n n (inf-suble n ip0) (inf-refl n))) (inf-leaddr n 8)) gn)
 )
 (defvcs inf-vc-ststo-j2j 1 inf-ststo-c1 (g3 (inf-lt 0 remj0) bbd2 nat g4 (inf-lt remj0 (natminus n ip0)))
  (inf-le remj0 remj0) (inf-refl remj0)
  (inf-le remj0 (natminus n ip0)) (inf-letrans remj0 (natminus n ip0) (natminus n ip0) (inf-ltle remj0 (natminus n ip0) g4) (inf-refl (natminus n ip0)))
 )
 (defvcs inf-vc-ststo-j2j 3 inf-ststo-c1 (g3 (inf-lt 0 remj0) bbd2 nat g4 (inf-le (natminus n ip0) remj0))
  (inf-le (natminus n ip0) remj0) g4
  (inf-le (natminus n ip0) (natminus n ip0)) (inf-refl (natminus n ip0))
 )
 (defcx inf-ststo-c3 inf-ststo-c1 (g3 (inf-lt 0 remj0)) (bbd2 nat) (kj2 nat) (f1 (inf-le kj2 remj0)) (f2 (inf-le kj2 (natminus n ip0))) )
 (defvcs inf-vc-ststo-j3 1 inf-ststo-c3 ()
  (inf-le opj0 cap) o2
 )
 (defvcs inf-vc-ststo-s5 1 inf-ststo-c3 (g5 (inf-lt (natminus cap opj0) kj2))
  (inf-le opj0 cap) o2
  (inf-lt (natminus cap opj0) (inf-pow w)) (inf-lelt (natminus cap opj0) (add n 8) (inf-pow w) (inf-letrans (natminus cap opj0) n (add n 8) (inf-letrans (natminus cap opj0) kj2 n (inf-ltle (natminus cap opj0) kj2 g5) (inf-letrans kj2 (natminus n ip0) n f2 (inf-letrans (natminus n ip0) n n (inf-suble n ip0) (inf-refl n)))) (inf-leaddr n 8)) gn)
 )
 (defvcs inf-vc-ststo-j3j 1 inf-ststo-c3 (g5 (inf-lt (natminus cap opj0) kj2))
  (inf-le (natminus cap opj0) remj0) (inf-letrans (natminus cap opj0) kj2 remj0 (inf-ltle (natminus cap opj0) kj2 g5) f1)
  (inf-le (natminus cap opj0) (natminus n ip0)) (inf-letrans (natminus cap opj0) kj2 (natminus n ip0) (inf-ltle (natminus cap opj0) kj2 g5) f2)
  (inf-le (natminus cap opj0) (natminus cap opj0)) (inf-refl (natminus cap opj0))
 )
 (defvcs inf-vc-ststo-j3j 4 inf-ststo-c3 (g5 (inf-le kj2 (natminus cap opj0)))
  (inf-le kj2 remj0) f1
  (inf-le kj2 (natminus n ip0)) f2
  (inf-le kj2 (natminus cap opj0)) g5
 )
 (defcx inf-ststo-c4 inf-ststo-c3 (kj3 nat) (f3 (inf-le kj3 remj0)) (f4 (inf-le kj3 (natminus n ip0))) (f5 (inf-le kj3 (natminus cap opj0))) )
 (defvcs inf-vc-ststo-m1 1 inf-ststo-c4 ()
  (inf-le (add opj0 kj3) oc) (inf-letl (add opj0 kj3) cap oc (pathsinv0 nat oc cap (go gz)) ((inf-roomle opj0 cap kj3 f5 o2)))
  (inf-le (add ip0 kj3) n) ((inf-roomle ip0 n kj3 f4 gi))
 )
 (defvcs inf-vc-ststo-s6 1 inf-ststo-c4 ()
  (inf-lt (add opj0 kj3) (inf-pow w)) (inf-lelt (add opj0 kj3) cap (inf-pow w) ((inf-roomle opj0 cap kj3 f5 o2)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
 )
 (defvcs inf-vc-ststo-s7 1 inf-ststo-c4 ()
  (inf-lt (add ip0 kj3) (inf-pow w)) (inf-lelt (add ip0 kj3) n (inf-pow w) ((inf-roomle ip0 n kj3 f4 gi)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))
 )
 (defvcs inf-vc-ststo-s8 1 inf-ststo-c4 ()
  (inf-le kj3 remj0) f3
 )
 (defvcs inf-vc-ststo-r7 1 inf-ststo-c4 (g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-lt (add ip0 kj3) n))
  (inf-le (add ip0 kj3) n) (inf-letrans (add ip0 kj3) n n (inf-ltle (add ip0 kj3) n g7) (inf-refl n))
  (inf-le bcj0 63) r3
  (inf-bits-inv carry (add ip0 kj3) (add consj0 (inf-by8 kj3)) bcj0) (inf-advb carry ip0 consj0 bcj0 kj3 r4)
  (inf-le cons0 (add consj0 (inf-by8 kj3))) (inf-letrans cons0 consj0 (add consj0 (inf-by8 kj3)) r5 (inf-leaddr consj0 (inf-by8 kj3)))
  (inf-le (add opj0 kj3) cap) ((inf-roomle opj0 cap kj3 f5 o2))
  (inf-le op0 (add opj0 kj3)) (inf-letrans op0 opj0 (add opj0 kj3) o1 (inf-leaddr opj0 kj3))
 )
 (defvcs inf-vc-ststo-r8 1 inf-ststo-c4 (g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-le n (add ip0 kj3)))
  (inf-le (add ip0 kj3) n) ((inf-roomle ip0 n kj3 f4 gi))
  (inf-le bcj0 63) r3
  (inf-bits-inv carry (add ip0 kj3) (add consj0 (inf-by8 kj3)) bcj0) (inf-advb carry ip0 consj0 bcj0 kj3 r4)
  (inf-le cons0 (add consj0 (inf-by8 kj3))) (inf-letrans cons0 consj0 (add consj0 (inf-by8 kj3)) r5 (inf-leaddr consj0 (inf-by8 kj3)))
  (inf-le (add opj0 kj3) cap) ((inf-roomle opj0 cap kj3 f5 o2))
  (inf-le op0 (add opj0 kj3)) (inf-letrans op0 opj0 (add opj0 kj3) o1 (inf-leaddr opj0 kj3))
 )
 (defvcs inf-vc-ststo-j1j 1 inf-ststo-c4 (g6 (paths nat (natminus remj0 kj3) 0))
  (inf-le (add ip0 kj3) n) ((inf-roomle ip0 n kj3 f4 gi))
  (inf-le bcj0 63) r3
  (inf-bits-inv carry (add ip0 kj3) (add consj0 (inf-by8 kj3)) bcj0) (inf-advb carry ip0 consj0 bcj0 kj3 r4)
  (inf-le cons0 (add consj0 (inf-by8 kj3))) (inf-letrans cons0 consj0 (add consj0 (inf-by8 kj3)) r5 (inf-leaddr consj0 (inf-by8 kj3)))
  (inf-le op0 (add opj0 kj3)) (inf-letrans op0 opj0 (add opj0 kj3) o1 (inf-leaddr opj0 kj3))
  (inf-le (add opj0 kj3) cap) ((inf-roomle opj0 cap kj3 f5 o2))
 )
 (defvcs inf-vc-ststo-j1j 7 inf-ststo-c1 (g3 (paths nat remj0 0))
  (inf-le ip0 n) r1
  (inf-le bcj0 63) r3
  (inf-bits-inv carry ip0 consj0 bcj0) r4
  (inf-le cons0 consj0) r5
  (inf-le op0 opj0) o1
  (inf-le opj0 cap) o2
 )
 (defcx inf-ststo-c2 inf-ststo-c1 (bbj1 nat) (opj1 nat) (ipj1 nat) (consj1 nat) (remj1 nat) (r1 (inf-le ipj1 n)) (r3 (inf-le bcj0 63)) (r4 (inf-bits-inv carry ipj1 consj1 bcj0)) (r5 (inf-le cons0 consj1)) (o1 (inf-le op0 opj1)) (o2 (inf-le opj1 cap)) )
 (defvcs inf-vc-ststo-r9 1 inf-ststo-c2 (ge1 (inf-lt 0 last) modee1a nat)
  (inf-le ipj1 n) r1
  (inf-le bcj0 63) r3
  (inf-bits-inv carry ipj1 consj1 bcj0) r4
  (inf-le cons0 consj1) r5
  (inf-le opj1 cap) o2
  (inf-le op0 opj1) o1
 )
 (defvcs inf-vc-ststo-r9 7 inf-ststo-c2 (ge1 (paths nat last 0) modee1b nat)
  (inf-le ipj1 n) r1
  (inf-le bcj0 63) r3
  (inf-bits-inv carry ipj1 consj1 bcj0) r4
  (inf-le cons0 consj1) r5
  (inf-le opj1 cap) o2
  (inf-le op0 opj1) o1
 )
 (defcx inf-stsy (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gcf (inf-lt (add cap 266) (inf-pow w))) (Lc (pi k nat nat)) (Ls (pi k nat nat)) (Lt (pi k nat nat)) (Dc (pi k nat nat)) (Ds (pi k nat nat)) (Dt (pi k nat nat)) (lm nat) (dm nat) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (h nat) (LROOT nat) (DROOT nat) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16)) (c1 (pi k nat (inf-lt (Lc k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc 15 1) lm)) (c4 (inf-le lm 288)) (c5 (pi k nat (inf-lt (Dc k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc 15 1) dm)) (c8 (inf-le dm 32)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (gz (inf-lt 0 out)) (last nat) (mode0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) )
 (defvcs inf-vc-stsy-w1e 1 inf-stsy ()
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
  (inf-le op0 op0) (inf-refl op0)
  (inf-le op0 cap) gop
 )
 (defcx inf-stsy-w1 inf-stsy (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (mode nat) (stage nat) (sy nat) (len nat) (dist nat) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) (o1 (inf-le op0 op)) (o2 (inf-le op cap)) )
 (defvcs inf-vc-stsy-i1 1 inf-stsy-w1 (w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0))
  (inf-lt (add ip 8) (inf-pow w)) (inf-lelt (add ip 8) (add n 8) (inf-pow w) (inf-addr ip n 8 r1) gn)
 )
 (defvcs inf-vc-stsy-i3 1 inf-stsy-w1 (w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n))
  (inf-lt (add op 266) (inf-pow w)) (inf-lelt (add op 266) (add cap 266) (inf-pow w) (inf-addr op cap 266 o2) gcf)
 )
 (defvcs inf-vc-stsy-t1 1 inf-stsy-w1 (w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
  (inf-le op cap) o2
  (inf-lt (add cap nd) (inf-pow w)) gnd
  (inf-lt (add cap 266) (inf-pow w)) gcf
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le h 16) gh
  (inf-lt 0 out) gz
  (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)) hle
  (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)) hlb
  (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))) hlc
  (pi k nat g (inf-lt k 30) (inf-le (De k) 13)) hde
  (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))) hdb
 )
 (defvcs inf-vc-stsy-t1s 1 inf-stsy-w1 (w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op opt1))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 r5 t1e5)
  (inf-le opt1 cap) t1e8
  (inf-le op0 opt1) (inf-letrans op0 op opt1 o1 t1e9)
 )
 (defcx inf-stsy-c11 inf-stsy-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (g0 (paths nat stage 0)) (g1 (inf-le (add ip 8) n)) (g3 (inf-le (add op 266) cap)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (opt1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e8 (inf-le opt1 cap)) (t1e9 (inf-le op opt1)) )
 (defvcs inf-vc-stsy-r0 1 inf-stsy-c11 (g4 (inf-lt 0 xt1) ge1 (inf-lt 0 last) modee1a nat)
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 r5 t1e5)
  (inf-le opt1 cap) t1e8
  (inf-le op0 opt1) (inf-letrans op0 op opt1 o1 t1e9)
 )
 (defvcs inf-vc-stsy-r0 7 inf-stsy-c11 (g4 (inf-lt 0 xt1) ge1 (paths nat last 0) modee1b nat)
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 r5 t1e5)
  (inf-le opt1 cap) t1e8
  (inf-le op0 opt1) (inf-letrans op0 op opt1 o1 t1e9)
 )
 (defvcs inf-vc-stsy-i1j 1 inf-stsy-c11 (g4 (paths nat xt1 0))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) (inf-letrans cons0 cons const1 r5 t1e5)
  (inf-le o0 opt1) (inf-letrans o0 op opt1 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))) t1e9)
  (inf-le opt1 cap) t1e8
  (inf-le op0 opt1) (inf-letrans op0 op opt1 o1 t1e9)
 )
 (defvcs inf-vc-stsy-i1j 8 inf-stsy-w1 (w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)))
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le cons0 cons) r5
  (inf-le o0 op) ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op)))
  (inf-le op cap) o2
  (inf-le op0 op) o1
 )
 (defvcs inf-vc-stsy-i1j 15 inf-stsy-w1 (w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-lt n (add ip 8)))
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le cons0 cons) r5
  (inf-le o0 op) ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op)))
  (inf-le op cap) o2
  (inf-le op0 op) o1
 )
 (defcx inf-stsy-c9 inf-stsy-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (g0 (paths nat stage 0)) (ipi1 nat) (bci1 nat) (bbi1 nat) (consi1 nat) (opi1 nat) (modei1 nat) (k1 (inf-le ipi1 n)) (k3 (inf-le bci1 63)) (k4 (inf-bits-inv carry ipi1 consi1 bci1)) (k5 (inf-le cons0 consi1)) (k6 (inf-le o0 opi1)) (k7 (inf-le opi1 cap)) (k8 (inf-le op0 opi1)) )
 (defvcs inf-vc-stsy-t2 1 inf-stsy-c9 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipi1 n) k1
  (inf-le bci1 63) k3
  (inf-bits-inv carry ipi1 consi1 bci1) k4
  (pi i nat (inf-lt (Lc i) (inf-pow h))) c1
  (pi i nat (inf-lt (Ls i) (inf-pow h))) c2
  (inf-le h 16) gh
  (inf-lt lm (inf-pow w)) (inf-lelt lm 288 (inf-pow w) c4 (inf-wfit288 w gw))
  (inf-le (inf-sum Lc 15 1) lm) c3
  (inf-le LROOT 15) gl
 )
 (defvcs inf-vc-stsy-t2s 1 inf-stsy-c9 (ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consi1 const2))
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consi1 const2 k5 t2e5)
  (inf-le opi1 cap) k7
  (inf-le op0 opi1) k8
 )
 (defcx inf-stsy-c10 inf-stsy-c9 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le consi1 const2)) )
 (defvcs inf-vc-stsy-i0j 1 inf-stsy-c10 (syd1 nat g5 (inf-lt xt2 256) staged2 nat)
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consi1 const2 k5 t2e5)
  (inf-le o0 opi1) k6
  (inf-le opi1 cap) k7
  (inf-le op0 opi1) k8
 )
 (defvcs inf-vc-stsy-r1 1 inf-stsy-c10 (syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (inf-lt 0 last) modee2a nat)
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consi1 const2 k5 t2e5)
  (inf-le opi1 cap) k7
  (inf-le op0 opi1) (inf-letrans op0 op opi1 o1 ((inf-letr o0 op opi1 eo k6)))
 )
 (defvcs inf-vc-stsy-r1 7 inf-stsy-c10 (syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (paths nat last 0) modee2b nat)
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consi1 const2 k5 t2e5)
  (inf-le opi1 cap) k7
  (inf-le op0 opi1) (inf-letrans op0 op opi1 o1 ((inf-letr o0 op opi1 eo k6)))
 )
 (defvcs inf-vc-stsy-i0j 8 inf-stsy-c10 (syd1 nat g5 (inf-le 256 xt2) g6 (inf-lt 256 xt2) staged3 nat)
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consi1 const2 k5 t2e5)
  (inf-le o0 opi1) k6
  (inf-le opi1 cap) k7
  (inf-le op0 opi1) k8
 )
 (defvcs inf-vc-stsy-i0j 15 inf-stsy-w1 (w1 unit o0 nat eo (paths nat o0 op) g0 (inf-lt 0 stage))
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le cons0 cons) r5
  (inf-le o0 op) ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op)))
  (inf-le op cap) o2
  (inf-le op0 op) o1
 )
 (defcx inf-stsy-c1 inf-stsy-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (ipi0 nat) (bci0 nat) (bbi0 nat) (consi0 nat) (opi0 nat) (modei0 nat) (syi0 nat) (stagei0 nat) (k1 (inf-le ipi0 n)) (k3 (inf-le bci0 63)) (k4 (inf-bits-inv carry ipi0 consi0 bci0)) (k5 (inf-le cons0 consi0)) (k6 (inf-le o0 opi0)) (k7 (inf-le opi0 cap)) (k8 (inf-le op0 opi0)) )
 (defvcs inf-vc-stsy-r2 1 inf-stsy-c1 (g7 unit g8 (inf-le cap opi0))
  (inf-le ipi0 n) k1
  (inf-le bci0 63) k3
  (inf-bits-inv carry ipi0 consi0 bci0) k4
  (inf-le cons0 consi0) k5
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defvcs inf-vc-stsy-r3 1 inf-stsy-c1 (g7 unit g8 (inf-lt opi0 cap) g9 (inf-lt 255 syi0))
  (inf-le ipi0 n) k1
  (inf-le bci0 63) k3
  (inf-bits-inv carry ipi0 consi0 bci0) k4
  (inf-le cons0 consi0) k5
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defvcs inf-vc-stsy-p1 1 inf-stsy-c1 (g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255))
  (inf-lt opi0 oc) (inf-lttrans opi0 cap oc g8 ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))
  (inf-lt syi0 256) (inf-lelts syi0 255 g9)
 )
 (defvcs inf-vc-stsy-s1 1 inf-stsy-c1 (g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255))
  (inf-lt (add opi0 1) (inf-pow w)) (inf-lelt (add opi0 1) cap (inf-pow w) (inf-lt1 opi0 cap g8) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
 )
 (defvcs inf-vc-stsy-w1b 1 inf-stsy-c1 (g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) staged4 nat)
  (inf-le ipi0 n) k1
  (inf-le bci0 63) k3
  (inf-bits-inv carry ipi0 consi0 bci0) k4
  (inf-le cons0 consi0) k5
  (inf-le op0 (add opi0 1)) (inf-letrans op0 opi0 (add opi0 1) ((inf-letrans op0 op opi0 o1 ((inf-letr o0 op opi0 eo k6)))) (inf-leaddr opi0 1))
  (inf-le (add opi0 1) cap) (inf-lt1 opi0 cap g8)
  (inf-lt (natminus cap (add opi0 1)) (natminus cap op)) (inf-subfrom op opi0 cap 1 ((inf-letr o0 op opi0 eo k6)) g8 (idpath true))
 )
 (defvcs inf-vc-stsy-r4 1 inf-stsy-c1 (g7 unit g10 unit g11 (inf-lt syi0 257))
  (inf-le ipi0 n) k1
  (inf-le bci0 63) k3
  (inf-bits-inv carry ipi0 consi0 bci0) k4
  (inf-le cons0 consi0) k5
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defvcs inf-vc-stsy-r5 1 inf-stsy-c1 (g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-lt 285 syi0))
  (inf-le ipi0 n) k1
  (inf-le bci0 63) k3
  (inf-bits-inv carry ipi0 consi0 bci0) k4
  (inf-le cons0 consi0) k5
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defvcs inf-vc-stsy-s2 1 inf-stsy-c1 (g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285))
  (inf-le 257 syi0) g11
  (inf-lt (natminus syi0 257) 29) ((inf-lidx syi0 g12))
  (inf-lt (Lb (natminus syi0 257)) (inf-pow w)) (inf-lelt (Lb ((natminus syi0 257))) 259 (inf-pow w) (inf-letrans (Lb ((natminus syi0 257))) (add (Lb ((natminus syi0 257))) (inf-pow ((Le ((natminus syi0 257)))))) 259 (inf-leaddr (Lb ((natminus syi0 257))) (inf-pow ((Le ((natminus syi0 257)))))) ((hlb ((natminus syi0 257)) ((inf-lidx syi0 g12))))) ((inf-lelt 259 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))
 )
 (defvcs inf-vc-stsy-t3 1 inf-stsy-c1 (g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipi0 n) k1
  (inf-le bci0 63) k3
  (inf-bits-inv carry ipi0 consi0 bci0) k4
  (inf-le (Le (natminus syi0 257)) 13) (inf-letrans ((Le ((natminus syi0 257)))) 5 13 (hle ((natminus syi0 257)) ((inf-lidx syi0 g12))) (idpath false))
 )
 (defvcs inf-vc-stsy-t3s 1 inf-stsy-c1 (g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) ipt3 nat bct3 nat bbt3 nat const3 nat yt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consi0 const3))
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (inf-le cons0 const3) (inf-letrans cons0 consi0 const3 k5 t3e5)
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defcx inf-stsy-c8 inf-stsy-c1 (g7 unit) (g10 unit) (g11 (inf-le 257 syi0)) (g12 (inf-le syi0 285)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (yt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le consi0 const3)) (t3e6 (inf-le (add consi0 (Le (natminus syi0 257))) const3)) (t3e7 (inf-lt yt3 (inf-pow (Le (natminus syi0 257))))) )
 (defvcs inf-vc-stsy-d5 1 inf-stsy-c8 ()
  (inf-lt (add (Lb (natminus syi0 257)) yt3) (inf-pow w)) (inf-lttrans ((add (Lb ((natminus syi0 257))) yt3)) 259 (inf-pow w) ((inf-basele (Lb ((natminus syi0 257))) ((Le ((natminus syi0 257)))) yt3 259 t3e7 ((hlb ((natminus syi0 257)) ((inf-lidx syi0 g12)))))) (inf-ltle 259 (inf-pow w) ((inf-lelt 259 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))
 )
 (defvcs inf-vc-stsy-j1j 1 inf-stsy-c8 (lend5 nat staged6 nat)
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (inf-le cons0 const3) (inf-letrans cons0 consi0 const3 k5 t3e5)
 )
 (defvcs inf-vc-stsy-j1j 5 inf-stsy-c1 (g7 unit g10 unit)
  (inf-le ipi0 n) k1
  (inf-le bci0 63) k3
  (inf-bits-inv carry ipi0 consi0 bci0) k4
  (inf-le cons0 consi0) k5
 )
 (defcx inf-stsy-c2 inf-stsy-c1 (g7 unit) (ipj1 nat) (bcj1 nat) (bbj1 nat) (consj1 nat) (lenj1 nat) (stagej1 nat) (m1 (inf-le ipj1 n)) (m3 (inf-le bcj1 63)) (m4 (inf-bits-inv carry ipj1 consj1 bcj1)) (m5 (inf-le cons0 consj1)) )
 (defvcs inf-vc-stsy-t4 1 inf-stsy-c2 (g13 unit)
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj1 n) m1
  (inf-le bcj1 63) m3
  (inf-bits-inv carry ipj1 consj1 bcj1) m4
  (pi i nat (inf-lt (Dc i) (inf-pow h))) c5
  (pi i nat (inf-lt (Ds i) (inf-pow h))) c6
  (inf-le h 16) gh
  (inf-lt dm (inf-pow w)) (inf-wlit dm w gw (inf-letrans dm 32 63 c8 (idpath false)))
  (inf-le (inf-sum Dc 15 1) dm) c7
  (inf-le DROOT 15) gd
 )
 (defvcs inf-vc-stsy-t4s 1 inf-stsy-c2 (g13 unit ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj1 const4))
  (inf-le ipt4 n) t4e1
  (inf-le bct4 63) t4e3
  (inf-bits-inv carry ipt4 const4 bct4) t4e4
  (inf-le cons0 const4) (inf-letrans cons0 consj1 const4 m5 t4e5)
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defcx inf-stsy-c7 inf-stsy-c2 (g13 unit) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le consj1 const4)) )
 (defvcs inf-vc-stsy-j2j 1 inf-stsy-c7 (syd7 nat staged8 nat)
  (inf-le ipt4 n) t4e1
  (inf-le bct4 63) t4e3
  (inf-bits-inv carry ipt4 const4 bct4) t4e4
  (inf-le cons0 const4) (inf-letrans cons0 consj1 const4 m5 t4e5)
 )
 (defvcs inf-vc-stsy-j2j 5 inf-stsy-c2 (g13 unit)
  (inf-le ipj1 n) m1
  (inf-le bcj1 63) m3
  (inf-bits-inv carry ipj1 consj1 bcj1) m4
  (inf-le cons0 consj1) m5
 )
 (defcx inf-stsy-c3 inf-stsy-c2 (ipj2 nat) (bcj2 nat) (bbj2 nat) (consj2 nat) (syj2 nat) (stagej2 nat) (n1 (inf-le ipj2 n)) (n3 (inf-le bcj2 63)) (n4 (inf-bits-inv carry ipj2 consj2 bcj2)) (n5 (inf-le cons0 consj2)) )
 (defvcs inf-vc-stsy-r6 1 inf-stsy-c3 (g14 unit g15 (inf-lt 29 syj2))
  (inf-le ipj2 n) n1
  (inf-le bcj2 63) n3
  (inf-bits-inv carry ipj2 consj2 bcj2) n4
  (inf-le cons0 consj2) n5
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defvcs inf-vc-stsy-s3 1 inf-stsy-c3 (g14 unit g15 (inf-le syj2 29))
  (inf-lt syj2 30) (inf-lelts syj2 29 g15)
  (inf-lt (Db syj2) (inf-pow w)) (inf-lttrans (Db syj2) (inf-pow h) (inf-pow w) (inf-lttrans (Db syj2) (add (Db syj2) (inf-pow ((De syj2)))) (inf-pow h) (inf-ltaddpos (Db syj2) (inf-pow ((De syj2))) (inf-powpos ((De syj2)))) (hdb syj2 ((inf-lelts syj2 29 g15)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))
 )
 (defvcs inf-vc-stsy-t5 1 inf-stsy-c3 (g14 unit g15 (inf-le syj2 29))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj2 n) n1
  (inf-le bcj2 63) n3
  (inf-bits-inv carry ipj2 consj2 bcj2) n4
  (inf-le (De syj2) 13) (hde syj2 ((inf-lelts syj2 29 g15)))
 )
 (defvcs inf-vc-stsy-t5s 1 inf-stsy-c3 (g14 unit g15 (inf-le syj2 29) ipt5 nat bct5 nat bbt5 nat const5 nat yt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj2 const5))
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv carry ipt5 const5 bct5) t5e4
  (inf-le cons0 const5) (inf-letrans cons0 consj2 const5 n5 t5e5)
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defcx inf-stsy-c6 inf-stsy-c3 (g14 unit) (g15 (inf-le syj2 29)) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (yt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv carry ipt5 const5 bct5)) (t5e5 (inf-le consj2 const5)) (t5e6 (inf-le (add consj2 (De syj2)) const5)) (t5e7 (inf-lt yt5 (inf-pow (De syj2)))) )
 (defvcs inf-vc-stsy-d9 1 inf-stsy-c6 ()
  (inf-lt (add (Db syj2) yt5) (inf-pow w)) ((inf-lttrans ((add (Db syj2) yt5)) (inf-pow h) (inf-pow w) (inf-basele (Db syj2) ((De syj2)) yt5 (inf-pow h) t5e7 (hdb syj2 ((inf-lelts syj2 29 g15)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))
 )
 (defvcs inf-vc-stsy-j3j 1 inf-stsy-c6 (distd9 nat staged10 nat)
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv carry ipt5 const5 bct5) t5e4
  (inf-le cons0 const5) (inf-letrans cons0 consj2 const5 n5 t5e5)
 )
 (defvcs inf-vc-stsy-j3j 5 inf-stsy-c3 (g14 unit)
  (inf-le ipj2 n) n1
  (inf-le bcj2 63) n3
  (inf-bits-inv carry ipj2 consj2 bcj2) n4
  (inf-le cons0 consj2) n5
 )
 (defcx inf-stsy-c4 inf-stsy-c3 (ipj3 nat) (bcj3 nat) (bbj3 nat) (consj3 nat) (distj3 nat) (stagej3 nat) (q1 (inf-le ipj3 n)) (q3 (inf-le bcj3 63)) (q4 (inf-bits-inv carry ipj3 consj3 bcj3)) (q5 (inf-le cons0 consj3)) )
 (defvcs inf-vc-stsy-i13 1 inf-stsy-c4 ()
  (inf-lt 15 32) (idpath true)
  (inf-lt (inf-pow 15) (inf-pow w)) ((inf-powlt 15 w (inf-lttrans 15 16 w (idpath true) (inf-letrans 16 32 w (idpath false) gw))))
 )
 (defvcs inf-vc-stsy-r7 1 inf-stsy-c4 (g16 (inf-lt (inf-pow 15) distj3))
  (inf-le ipj3 n) q1
  (inf-le bcj3 63) q3
  (inf-bits-inv carry ipj3 consj3 bcj3) q4
  (inf-le cons0 consj3) q5
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defvcs inf-vc-stsy-i14 1 inf-stsy-c4 (g16 (inf-le distj3 (inf-pow 15)))
  (inf-lt (add opi0 nd) (inf-pow w)) (inf-lelt (add opi0 nd) (add cap nd) (inf-pow w) (inf-addr opi0 cap nd k7) gnd)
 )
 (defvcs inf-vc-stsy-r8 1 inf-stsy-c4 (g16 (inf-le distj3 (inf-pow 15)) g17 (inf-lt (add opi0 nd) distj3))
  (inf-le ipj3 n) q1
  (inf-le bcj3 63) q3
  (inf-bits-inv carry ipj3 consj3 bcj3) q4
  (inf-le cons0 consj3) q5
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defvcs inf-vc-stsy-r9 1 inf-stsy-c4 (g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (paths nat lenj1 0))
  (inf-le ipj3 n) q1
  (inf-le bcj3 63) q3
  (inf-bits-inv carry ipj3 consj3 bcj3) q4
  (inf-le cons0 consj3) q5
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defvcs inf-vc-stsy-i16 1 inf-stsy-c4 (g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1))
  (inf-le opi0 cap) k7
 )
 (defvcs inf-vc-stsy-r10 1 inf-stsy-c4 (g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-lt (natminus cap opi0) lenj1))
  (inf-le ipj3 n) q1
  (inf-le bcj3 63) q3
  (inf-bits-inv carry ipj3 consj3 bcj3) q4
  (inf-le cons0 consj3) q5
  (inf-le opi0 cap) k7
  (inf-le op0 opi0) k8
 )
 (defvcs inf-vc-stsy-c1 1 inf-stsy-c4 (g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-le lenj1 (natminus cap opi0)))
  (inf-le 32 w) gw
  (inf-lt distj3 (inf-pow w)) (inf-lelt distj3 (inf-pow 15) (inf-pow w) g16 ((inf-powlt 15 w (inf-lttrans 15 16 w (idpath true) (inf-letrans 16 32 w (idpath false) gw)))))
  (inf-le distj3 (add opi0 nd)) g17
  (inf-le (add opi0 lenj1) cap) ((inf-roomle opi0 cap lenj1 g19 k7))
  (inf-lt 0 out) gz
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
 )
 (defcx inf-stsy-c5 inf-stsy-c4 (g16 (inf-le distj3 (inf-pow 15))) (g17 (inf-le distj3 (add opi0 nd))) (g18 (inf-lt 0 lenj1)) (g19 (inf-le lenj1 (natminus cap opi0))) )
 (defvcs inf-vc-stsy-s4 1 inf-stsy-c5 ()
  (inf-lt (add opi0 lenj1) (inf-pow w)) (inf-lelt (add opi0 lenj1) cap (inf-pow w) ((inf-roomle opi0 cap lenj1 g19 k7)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
 )
 (defvcs inf-vc-stsy-w1b 8 inf-stsy-c5 (staged11 nat)
  (inf-le ipj3 n) q1
  (inf-le bcj3 63) q3
  (inf-bits-inv carry ipj3 consj3 bcj3) q4
  (inf-le cons0 consj3) q5
  (inf-le op0 (add opi0 lenj1)) (inf-letrans op0 opi0 (add opi0 lenj1) ((inf-letrans op0 op opi0 o1 ((inf-letr o0 op opi0 eo k6)))) (inf-leaddr opi0 lenj1))
  (inf-le (add opi0 lenj1) cap) ((inf-roomle opi0 cap lenj1 g19 k7))
  (inf-lt (natminus cap (add opi0 lenj1)) (natminus cap op)) (inf-subfrom op opi0 cap lenj1 ((inf-letr o0 op opi0 eo k6)) ((inf-lttrans opi0 (add opi0 lenj1) cap (inf-ltaddpos opi0 lenj1 g18) ((inf-roomle opi0 cap lenj1 g19 k7)))) g18)
 )
 (defcx inf-strest (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (gcf (inf-lt (add cap 266) (inf-pow w))) (gz (inf-lt 0 out)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (last0 nat) (rem0 nat) (hclen0 nat) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) (mode0 nat) (hlit0 nat) (hdist0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (b1 (inf-le prev0 15)) (b2 (pi j nat (inf-le (Lz0 j) 15))) (a2 (pi k nat (inf-le (Cl0 k) 15))) )
 (defvcs inf-vc-strest-t1 1 inf-strest (g1 unit)
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
 )
 (defvcs inf-vc-strest-t1s 1 inf-strest (g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) t1e5
  (inf-le op0 cap) gop
  (inf-le op0 op0) (inf-refl op0)
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defcx inf-strest-c12 inf-strest (g1 unit) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (remt1 nat) (modet1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons0 const1)) )
 (defvcs inf-vc-strest-j1j 1 inf-strest-c12 ()
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) t1e5
 )
 (defvcs inf-vc-strest-j1j 5 inf-strest (g1 unit)
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (inf-le cons0 cons0) (inf-refl cons0)
 )
 (defcx inf-strest-c1 inf-strest (ipj1 nat) (bcj1 nat) (bbj1 nat) (consj1 nat) (remj1 nat) (modej1 nat) (r1 (inf-le ipj1 n)) (r3 (inf-le bcj1 63)) (r4 (inf-bits-inv carry ipj1 consj1 bcj1)) (r5 (inf-le cons0 consj1)) )
 (defvcs inf-vc-strest-t2 1 inf-strest-c1 (g2 unit)
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj1 n) r1
  (inf-le bcj1 63) r3
  (inf-bits-inv carry ipj1 consj1 bcj1) r4
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
  (inf-le op0 cap) gop
  (inf-lt (add cap nd) (inf-pow w)) gnd
  (inf-lt 0 out) gz
 )
 (defvcs inf-vc-strest-t2s 1 inf-strest-c1 (g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2))
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consj1 const2 r5 t2e5)
  (inf-le opt2 cap) t2e8
  (inf-le op0 opt2) t2e9
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defcx inf-strest-c11 inf-strest-c1 (g2 unit) (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (opt2 nat) (remt2 nat) (modet2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le consj1 const2)) (t2e8 (inf-le opt2 cap)) (t2e9 (inf-le op0 opt2)) )
 (defvcs inf-vc-strest-j2j 1 inf-strest-c11 ()
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 consj1 const2 r5 t2e5)
  (inf-le op0 opt2) t2e9
  (inf-le opt2 cap) t2e8
 )
 (defvcs inf-vc-strest-j2j 7 inf-strest-c1 (g2 unit)
  (inf-le ipj1 n) r1
  (inf-le bcj1 63) r3
  (inf-bits-inv carry ipj1 consj1 bcj1) r4
  (inf-le cons0 consj1) r5
  (inf-le op0 op0) (inf-refl op0)
  (inf-le op0 cap) gop
 )
 (defcx inf-strest-c2 inf-strest-c1 (ipj2 nat) (bcj2 nat) (bbj2 nat) (consj2 nat) (opj2 nat) (remj2 nat) (modej2 nat) (r1 (inf-le ipj2 n)) (r3 (inf-le bcj2 63)) (r4 (inf-bits-inv carry ipj2 consj2 bcj2)) (r5 (inf-le cons0 consj2)) (o1 (inf-le op0 opj2)) (o2 (inf-le opj2 cap)) )
 (defvcs inf-vc-strest-t3 1 inf-strest-c2 (g3 unit)
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj2 n) r1
  (inf-le bcj2 63) r3
  (inf-bits-inv carry ipj2 consj2 bcj2) r4
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defvcs inf-vc-strest-t3s 1 inf-strest-c2 (g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)))
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (inf-le cons0 const3) (inf-letrans cons0 consj2 const3 r5 t3e5)
  (inf-le opj2 cap) o2
  (inf-le op0 opj2) o1
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Clt3 k) 15)) t3a2
 )
 (defcx inf-strest-c10 inf-strest-c2 (g3 unit) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (Clt3 (pi j nat nat)) (hlitt3 nat) (hdistt3 nat) (hclent3 nat) (it3 nat) (modet3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le consj2 const3)) (t3a2 (pi k nat (inf-le (Clt3 k) 15))) )
 (defvcs inf-vc-strest-j3j 1 inf-strest-c10 ()
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (inf-le cons0 const3) (inf-letrans cons0 consj2 const3 r5 t3e5)
  (pi k nat (inf-le (Clt3 k) 15)) t3a2
 )
 (defvcs inf-vc-strest-j3j 6 inf-strest-c2 (g3 unit)
  (inf-le ipj2 n) r1
  (inf-le bcj2 63) r3
  (inf-bits-inv carry ipj2 consj2 bcj2) r4
  (inf-le cons0 consj2) r5
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defcx inf-strest-c3 inf-strest-c2 (ipj3 nat) (bcj3 nat) (bbj3 nat) (consj3 nat) (Clj3 (pi j nat nat)) (hlitj3 nat) (hdistj3 nat) (hclenj3 nat) (ij3 nat) (modej3 nat) (r1 (inf-le ipj3 n)) (r3 (inf-le bcj3 63)) (r4 (inf-bits-inv carry ipj3 consj3 bcj3)) (r5 (inf-le cons0 consj3)) (a2 (pi k nat (inf-le (Clj3 k) 15))) )
 (defvcs inf-vc-strest-t4 1 inf-strest-c3 (g4 unit)
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj3 n) r1
  (inf-le bcj3 63) r3
  (inf-bits-inv carry ipj3 consj3 bcj3) r4
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
  (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)) hord
  (pi k nat (inf-le (Clj3 k) 15)) a2
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
 )
 (defvcs inf-vc-strest-t4s 1 inf-strest-c3 (g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)))
  (inf-le ipt4 n) t4e1
  (inf-le bct4 63) t4e3
  (inf-bits-inv carry ipt4 const4 bct4) t4e4
  (inf-le cons0 const4) (inf-letrans cons0 consj3 const4 r5 t4e5)
  (inf-le opj2 cap) o2
  (inf-le op0 opj2) o1
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d1
  (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d2
  (inf-le (inf-sum Cct4 15 1) 19) t4d3
  (inf-le prevt4 15) t4b1
  (pi j nat (inf-le (Lzt4 j) 15)) t4b2
  (pi k nat (inf-le (Clt4 k) 15)) t4a2
 )
 (defcx inf-strest-c9 inf-strest-c3 (g4 unit) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (Clt4 (pi j nat nat)) (Lzt4 (pi j nat nat)) (Cst4 (pi j nat nat)) (Ctt4 (pi j nat nat)) (Cct4 (pi j nat nat)) (it4 nat) (prevt4 nat) (staget4 nat) (modet4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le consj3 const4)) (t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h)))) (t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h)))) (t4d3 (inf-le (inf-sum Cct4 15 1) 19)) (t4b1 (inf-le prevt4 15)) (t4b2 (pi j nat (inf-le (Lzt4 j) 15))) (t4a2 (pi k nat (inf-le (Clt4 k) 15))) )
 (defvcs inf-vc-strest-j4j 1 inf-strest-c9 ()
  (inf-le ipt4 n) t4e1
  (inf-le bct4 63) t4e3
  (inf-bits-inv carry ipt4 const4 bct4) t4e4
  (inf-le cons0 const4) (inf-letrans cons0 consj3 const4 r5 t4e5)
  (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d1
  (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d2
  (inf-le (inf-sum Cct4 15 1) 19) t4d3
  (inf-le prevt4 15) t4b1
  (pi j nat (inf-le (Lzt4 j) 15)) t4b2
  (pi k nat (inf-le (Clt4 k) 15)) t4a2
 )
 (defvcs inf-vc-strest-j4j 11 inf-strest-c3 (g4 unit)
  (inf-le ipj3 n) r1
  (inf-le bcj3 63) r3
  (inf-bits-inv carry ipj3 consj3 bcj3) r4
  (inf-le cons0 consj3) r5
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Clj3 k) 15)) a2
 )
 (defcx inf-strest-c4 inf-strest-c3 (ipj4 nat) (bcj4 nat) (bbj4 nat) (consj4 nat) (Clj4 (pi j nat nat)) (Lzj4 (pi j nat nat)) (Csj4 (pi j nat nat)) (Ctj4 (pi j nat nat)) (Ccj4 (pi j nat nat)) (ij4 nat) (prevj4 nat) (stagej4 nat) (modej4 nat) (r1 (inf-le ipj4 n)) (r3 (inf-le bcj4 63)) (r4 (inf-bits-inv carry ipj4 consj4 bcj4)) (r5 (inf-le cons0 consj4)) (d1 (pi k nat (inf-lt (Ccj4 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Csj4 k) (inf-pow h)))) (d3 (inf-le (inf-sum Ccj4 15 1) 19)) (b1 (inf-le prevj4 15)) (b2 (pi j nat (inf-le (Lzj4 j) 15))) (a2 (pi k nat (inf-le (Clj4 k) 15))) )
 (defvcs inf-vc-strest-t5 1 inf-strest-c4 (g5 unit)
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj4 n) r1
  (inf-le bcj4 63) r3
  (inf-bits-inv carry ipj4 consj4 bcj4) r4
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
  (pi k nat (inf-lt (Ccj4 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Csj4 k) (inf-pow h))) d2
  (inf-le (inf-sum Ccj4 15 1) 19) d3
  (pi j nat (inf-le (Lzj4 j) 15)) b2
  (inf-le prevj4 15) b1
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
 )
 (defvcs inf-vc-strest-t5s 1 inf-strest-c4 (g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)))
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv carry ipt5 const5 bct5) t5e4
  (inf-le cons0 const5) (inf-letrans cons0 consj4 const5 r5 t5e5)
  (inf-le opj2 cap) o2
  (inf-le op0 opj2) o1
  (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c1
  (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c2
  (inf-le (inf-sum Lct5 15 1) lmt5) t5c3
  (inf-le lmt5 288) t5c4
  (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c5
  (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c6
  (inf-le (inf-sum Dct5 15 1) dmt5) t5c7
  (inf-le dmt5 32) t5c8
  (pi k nat (inf-lt (Ccj4 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Csj4 k) (inf-pow h))) d2
  (inf-le (inf-sum Ccj4 15 1) 19) d3
  (inf-le prevt5 15) t5b1
  (pi j nat (inf-le (Lzt5 j) 15)) t5b2
  (pi k nat (inf-le (Clj4 k) 15)) a2
 )
 (defcx inf-strest-c8 inf-strest-c4 (g5 unit) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (Lct5 (pi j nat nat)) (Lst5 (pi j nat nat)) (Ltt5 (pi j nat nat)) (Dct5 (pi j nat nat)) (Dst5 (pi j nat nat)) (Dtt5 (pi j nat nat)) (lmt5 nat) (dmt5 nat) (Lzt5 (pi j nat nat)) (it5 nat) (prevt5 nat) (staget5 nat) (syt5 nat) (modet5 nat) (xt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv carry ipt5 const5 bct5)) (t5e5 (inf-le consj4 const5)) (t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h)))) (t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h)))) (t5c3 (inf-le (inf-sum Lct5 15 1) lmt5)) (t5c4 (inf-le lmt5 288)) (t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h)))) (t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h)))) (t5c7 (inf-le (inf-sum Dct5 15 1) dmt5)) (t5c8 (inf-le dmt5 32)) (t5b1 (inf-le prevt5 15)) (t5b2 (pi j nat (inf-le (Lzt5 j) 15))) )
 (defvcs inf-vc-strest-j5j 1 inf-strest-c8 ()
  (inf-le ipt5 n) t5e1
  (inf-le bct5 63) t5e3
  (inf-bits-inv carry ipt5 const5 bct5) t5e4
  (inf-le cons0 const5) (inf-letrans cons0 consj4 const5 r5 t5e5)
  (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c1
  (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c2
  (inf-le (inf-sum Lct5 15 1) lmt5) t5c3
  (inf-le lmt5 288) t5c4
  (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c5
  (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c6
  (inf-le (inf-sum Dct5 15 1) dmt5) t5c7
  (inf-le dmt5 32) t5c8
  (inf-le prevt5 15) t5b1
  (pi j nat (inf-le (Lzt5 j) 15)) t5b2
 )
 (defvcs inf-vc-strest-j5j 15 inf-strest-c4 (g5 unit)
  (inf-le ipj4 n) r1
  (inf-le bcj4 63) r3
  (inf-bits-inv carry ipj4 consj4 bcj4) r4
  (inf-le cons0 consj4) r5
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (inf-le prevj4 15) b1
  (pi j nat (inf-le (Lzj4 j) 15)) b2
 )
 (defcx inf-strest-c5 inf-strest-c4 (ipj5 nat) (bcj5 nat) (bbj5 nat) (consj5 nat) (Lcj5 (pi j nat nat)) (Lsj5 (pi j nat nat)) (Ltj5 (pi j nat nat)) (Dcj5 (pi j nat nat)) (Dsj5 (pi j nat nat)) (Dtj5 (pi j nat nat)) (lmj5 nat) (dmj5 nat) (Lzj5 (pi j nat nat)) (ij5 nat) (prevj5 nat) (stagej5 nat) (syj5 nat) (modej5 nat) (r1 (inf-le ipj5 n)) (r3 (inf-le bcj5 63)) (r4 (inf-bits-inv carry ipj5 consj5 bcj5)) (r5 (inf-le cons0 consj5)) (c1 (pi k nat (inf-lt (Lcj5 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Lsj5 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lcj5 15 1) lmj5)) (c4 (inf-le lmj5 288)) (c5 (pi k nat (inf-lt (Dcj5 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Dsj5 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dcj5 15 1) dmj5)) (c8 (inf-le dmj5 32)) (b1 (inf-le prevj5 15)) (b2 (pi j nat (inf-le (Lzj5 j) 15))) )
 (defvcs inf-vc-strest-t6 1 inf-strest-c5 (g6 unit)
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipj5 n) r1
  (inf-le bcj5 63) r3
  (inf-bits-inv carry ipj5 consj5 bcj5) r4
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
  (inf-le opj2 cap) o2
  (inf-lt (add cap nd) (inf-pow w)) gnd
  (inf-lt (add cap 266) (inf-pow w)) gcf
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le h 16) gh
  (pi k nat (inf-lt (Lcj5 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Lsj5 k) (inf-pow h))) c2
  (inf-le (inf-sum Lcj5 15 1) lmj5) c3
  (inf-le lmj5 288) c4
  (pi k nat (inf-lt (Dcj5 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Dsj5 k) (inf-pow h))) c6
  (inf-le (inf-sum Dcj5 15 1) dmj5) c7
  (inf-le dmj5 32) c8
  (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)) hle
  (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)) hlb
  (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))) hlc
  (pi k nat g (inf-lt k 30) (inf-le (De k) 13)) hde
  (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))) hdb
  (inf-lt 0 out) gz
 )
 (defvcs inf-vc-strest-t6s 1 inf-strest-c5 (g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6))
  (inf-le ipt6 n) t6e1
  (inf-le bct6 63) t6e3
  (inf-bits-inv carry ipt6 const6 bct6) t6e4
  (inf-le cons0 const6) (inf-letrans cons0 consj5 const6 r5 t6e5)
  (inf-le opt6 cap) t6e8
  (inf-le op0 opt6) (inf-letrans op0 opj2 opt6 o1 t6e9)
  (pi k nat (inf-lt (Lcj5 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Lsj5 k) (inf-pow h))) c2
  (inf-le (inf-sum Lcj5 15 1) lmj5) c3
  (inf-le lmj5 288) c4
  (pi k nat (inf-lt (Dcj5 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Dsj5 k) (inf-pow h))) c6
  (inf-le (inf-sum Dcj5 15 1) dmj5) c7
  (inf-le dmj5 32) c8
  (pi k nat (inf-lt (Ccj4 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Csj4 k) (inf-pow h))) d2
  (inf-le (inf-sum Ccj4 15 1) 19) d3
  (inf-le prevj5 15) b1
  (pi j nat (inf-le (Lzj5 j) 15)) b2
  (pi k nat (inf-le (Clj4 k) 15)) a2
 )
 (defcx inf-strest-c7 inf-strest-c5 (g6 unit) (ipt6 nat) (bct6 nat) (bbt6 nat) (const6 nat) (opt6 nat) (modet6 nat) (staget6 nat) (syt6 nat) (lent6 nat) (distt6 nat) (xt6 nat) (t6e1 (inf-le ipt6 n)) (t6e3 (inf-le bct6 63)) (t6e4 (inf-bits-inv carry ipt6 const6 bct6)) (t6e5 (inf-le consj5 const6)) (t6e8 (inf-le opt6 cap)) (t6e9 (inf-le opj2 opt6)) )
 (defvcs inf-vc-strest-j6j 1 inf-strest-c7 ()
  (inf-le ipt6 n) t6e1
  (inf-le bct6 63) t6e3
  (inf-bits-inv carry ipt6 const6 bct6) t6e4
  (inf-le cons0 const6) (inf-letrans cons0 consj5 const6 r5 t6e5)
  (inf-le op0 opt6) (inf-letrans op0 opj2 opt6 o1 t6e9)
  (inf-le opt6 cap) t6e8
 )
 (defvcs inf-vc-strest-j6j 7 inf-strest-c5 (g6 unit)
  (inf-le ipj5 n) r1
  (inf-le bcj5 63) r3
  (inf-bits-inv carry ipj5 consj5 bcj5) r4
  (inf-le cons0 consj5) r5
  (inf-le op0 opj2) o1
  (inf-le opj2 cap) o2
 )
 (defcx inf-strest-c6 inf-strest-c5 (ipj6 nat) (bcj6 nat) (bbj6 nat) (consj6 nat) (opj6 nat) (modej6 nat) (stagej6 nat) (syj6 nat) (lenj6 nat) (distj6 nat) (r1 (inf-le ipj6 n)) (r3 (inf-le bcj6 63)) (r4 (inf-bits-inv carry ipj6 consj6 bcj6)) (r5 (inf-le cons0 consj6)) (o1 (inf-le op0 opj6)) (o2 (inf-le opj6 cap)) )
 (defvcs inf-vc-strest-r1 1 inf-strest-c6 ()
  (inf-le ipj6 n) r1
  (inf-le bcj6 63) r3
  (inf-bits-inv carry ipj6 consj6 bcj6) r4
  (inf-le cons0 consj6) r5
  (inf-le opj6 cap) o2
  (inf-le op0 opj6) o1
  (pi k nat (inf-lt (Lcj5 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Lsj5 k) (inf-pow h))) c2
  (inf-le (inf-sum Lcj5 15 1) lmj5) c3
  (inf-le lmj5 288) c4
  (pi k nat (inf-lt (Dcj5 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Dsj5 k) (inf-pow h))) c6
  (inf-le (inf-sum Dcj5 15 1) dmj5) c7
  (inf-le dmj5 32) c8
  (pi k nat (inf-lt (Ccj4 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Csj4 k) (inf-pow h))) d2
  (inf-le (inf-sum Ccj4 15 1) 19) d3
  (inf-le prevj5 15) b1
  (pi j nat (inf-le (Lzj5 j) 15)) b2
  (pi k nat (inf-le (Clj4 k) 15)) a2
 )
 (defcx inf-ststep (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (gcf (inf-lt (add cap 266) (inf-pow w))) (gz (inf-lt 0 out)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (last0 nat) (rem0 nat) (hclen0 nat) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) (mode0 nat) (hlit0 nat) (hdist0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (b1 (inf-le prev0 15)) (b2 (pi j nat (inf-le (Lz0 j) 15))) (a2 (pi k nat (inf-le (Cl0 k) 15))) )
 (defvcs inf-vc-ststep-t1 1 inf-ststep ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv carry ip0 cons0 bc0) ga
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
  (inf-le op0 cap) gop
  (inf-lt (add cap nd) (inf-pow w)) gnd
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
  (inf-lt (add cap 266) (inf-pow w)) gcf
  (inf-lt 0 out) gz
  (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)) hord
  (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)) hle
  (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)) hlb
  (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))) hlc
  (pi k nat g (inf-lt k 30) (inf-le (De k) 13)) hde
  (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))) hdb
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defvcs inf-vc-ststep-t1s 1 inf-ststep (ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)))
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) t1e5
  (inf-le opt1 cap) t1e8
  (inf-le op0 opt1) t1e9
  (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c1
  (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c2
  (inf-le (inf-sum Lct1 15 1) lmt1) t1c3
  (inf-le lmt1 288) t1c4
  (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c5
  (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c6
  (inf-le (inf-sum Dct1 15 1) dmt1) t1c7
  (inf-le dmt1 32) t1c8
  (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d1
  (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d2
  (inf-le (inf-sum Cct1 15 1) 19) t1d3
  (inf-le prevt1 15) t1b1
  (pi j nat (inf-le (Lzt1 j) 15)) t1b2
  (pi k nat (inf-le (Clt1 k) 15)) t1a2
 )
 (defcx inf-ststep-c1 inf-ststep (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (opt1 nat) (Lct1 (pi j nat nat)) (Lst1 (pi j nat nat)) (Ltt1 (pi j nat nat)) (Dct1 (pi j nat nat)) (Dst1 (pi j nat nat)) (Dtt1 (pi j nat nat)) (lmt1 nat) (dmt1 nat) (Clt1 (pi j nat nat)) (Lzt1 (pi j nat nat)) (Cst1 (pi j nat nat)) (Ctt1 (pi j nat nat)) (Cct1 (pi j nat nat)) (lastt1 nat) (remt1 nat) (hclent1 nat) (it1 nat) (prevt1 nat) (staget1 nat) (syt1 nat) (lent1 nat) (distt1 nat) (modet1 nat) (hlitt1 nat) (hdistt1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons0 const1)) (t1e8 (inf-le opt1 cap)) (t1e9 (inf-le op0 opt1)) (t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h)))) (t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h)))) (t1c3 (inf-le (inf-sum Lct1 15 1) lmt1)) (t1c4 (inf-le lmt1 288)) (t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h)))) (t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h)))) (t1c7 (inf-le (inf-sum Dct1 15 1) dmt1)) (t1c8 (inf-le dmt1 32)) (t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h)))) (t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h)))) (t1d3 (inf-le (inf-sum Cct1 15 1) 19)) (t1b1 (inf-le prevt1 15)) (t1b2 (pi j nat (inf-le (Lzt1 j) 15))) (t1a2 (pi k nat (inf-le (Clt1 k) 15))) )
 (defvcs inf-vc-ststep-w1e 1 inf-ststep-c1 ()
  (inf-le ipt1 n) t1e1
  (inf-le bct1 63) t1e3
  (inf-bits-inv carry ipt1 const1 bct1) t1e4
  (inf-le cons0 const1) t1e5
  (inf-le op0 opt1) t1e9
  (inf-le opt1 cap) t1e8
  (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c1
  (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c2
  (inf-le (inf-sum Lct1 15 1) lmt1) t1c3
  (inf-le lmt1 288) t1c4
  (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c5
  (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c6
  (inf-le (inf-sum Dct1 15 1) dmt1) t1c7
  (inf-le dmt1 32) t1c8
  (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d1
  (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d2
  (inf-le (inf-sum Cct1 15 1) 19) t1d3
  (inf-le prevt1 15) t1b1
  (pi j nat (inf-le (Lzt1 j) 15)) t1b2
  (pi k nat (inf-le (Clt1 k) 15)) t1a2
 )
 (defcx inf-ststep-c1-w1 inf-ststep-c1 (x nat) (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (Lc (pi j nat nat)) (Ls (pi j nat nat)) (Lt (pi j nat nat)) (Dc (pi j nat nat)) (Ds (pi j nat nat)) (Dt (pi j nat nat)) (lm nat) (dm nat) (Cl (pi j nat nat)) (Lz (pi j nat nat)) (Cs (pi j nat nat)) (Ct (pi j nat nat)) (Cc (pi j nat nat)) (last nat) (rem nat) (hclen nat) (i nat) (prev nat) (stage nat) (sy nat) (len nat) (dist nat) (mode nat) (hlit nat) (hdist nat) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) (o1 (inf-le op0 op)) (o2 (inf-le op cap)) (c1 (pi k nat (inf-lt (Lc k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc 15 1) lm)) (c4 (inf-le lm 288)) (c5 (pi k nat (inf-lt (Dc k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc 15 1) dm)) (c8 (inf-le dm 32)) (d1 (pi k nat (inf-lt (Cc k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc 15 1) 19)) (b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))) (a2 (pi k nat (inf-le (Cl k) 15))) )
 (defvcs inf-vc-ststep-t2 1 inf-ststep-c1-w1 (w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons))
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
  (pi k nat (inf-lt (Lc k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls k) (inf-pow h))) c2
  (inf-le (inf-sum Lc 15 1) lm) c3
  (inf-le lm 288) c4
  (pi k nat (inf-lt (Dc k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds k) (inf-pow h))) c6
  (inf-le (inf-sum Dc 15 1) dm) c7
  (inf-le dm 32) c8
 )
 (defvcs inf-vc-ststep-t2s 1 inf-ststep-c1-w1 (w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32))
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (inf-le cons0 const2) (inf-letrans cons0 cons const2 r5 t2e5)
  (inf-le op cap) o2
  (inf-le op0 op) o1
  (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c1
  (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c2
  (inf-le (inf-sum Lct2 15 1) lmt2) t2c3
  (inf-le lmt2 288) t2c4
  (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c5
  (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c6
  (inf-le (inf-sum Dct2 15 1) dmt2) t2c7
  (inf-le dmt2 32) t2c8
  (pi k nat (inf-lt (Cc k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs k) (inf-pow h))) d2
  (inf-le (inf-sum Cc 15 1) 19) d3
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
  (pi k nat (inf-le (Cl k) 15)) a2
 )
 (defcx inf-ststep-c2 inf-ststep-c1-w1 (w1 (paths nat mode 0)) (c0 nat) (ec (paths nat c0 cons)) (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (Lct2 (pi j nat nat)) (Lst2 (pi j nat nat)) (Ltt2 (pi j nat nat)) (Dct2 (pi j nat nat)) (Dst2 (pi j nat nat)) (Dtt2 (pi j nat nat)) (lmt2 nat) (dmt2 nat) (lastt2 nat) (modet2 nat) (staget2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le cons const2)) (t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h)))) (t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h)))) (t2c3 (inf-le (inf-sum Lct2 15 1) lmt2)) (t2c4 (inf-le lmt2 288)) (t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h)))) (t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h)))) (t2c7 (inf-le (inf-sum Dct2 15 1) dmt2)) (t2c8 (inf-le dmt2 32)) (t2e6 (inf-le (add cons 3) const2)) )
 (defvcs inf-vc-ststep-t3 1 inf-ststep-c2 ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ipt2 n) t2e1
  (inf-le bct2 63) t2e3
  (inf-bits-inv carry ipt2 const2 bct2) t2e4
  (pi g (inf-lt 0 out) (paths nat oc cap)) go
  (inf-lt (add cap 8) (inf-pow w)) gcap
  (inf-le op cap) o2
  (inf-lt (add cap nd) (inf-pow w)) gnd
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
  (inf-lt (add cap 266) (inf-pow w)) gcf
  (inf-lt 0 out) gz
  (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)) hord
  (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)) hle
  (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)) hlb
  (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))) hlc
  (pi k nat g (inf-lt k 30) (inf-le (De k) 13)) hde
  (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))) hdb
  (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c1
  (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c2
  (inf-le (inf-sum Lct2 15 1) lmt2) t2c3
  (inf-le lmt2 288) t2c4
  (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c5
  (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c6
  (inf-le (inf-sum Dct2 15 1) dmt2) t2c7
  (inf-le dmt2 32) t2c8
  (pi k nat (inf-lt (Cc k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs k) (inf-pow h))) d2
  (inf-le (inf-sum Cc 15 1) 19) d3
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
  (pi k nat (inf-le (Cl k) 15)) a2
 )
 (defvcs inf-vc-ststep-t3s 1 inf-ststep-c2 (ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)))
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (inf-le cons0 const3) (inf-letrans cons0 cons const3 r5 (inf-letrans cons const2 const3 t2e5 t3e5))
  (inf-le opt3 cap) t3e8
  (inf-le op0 opt3) (inf-letrans op0 op opt3 o1 t3e9)
  (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c1
  (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c2
  (inf-le (inf-sum Lct3 15 1) lmt3) t3c3
  (inf-le lmt3 288) t3c4
  (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c5
  (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c6
  (inf-le (inf-sum Dct3 15 1) dmt3) t3c7
  (inf-le dmt3 32) t3c8
  (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d1
  (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d2
  (inf-le (inf-sum Cct3 15 1) 19) t3d3
  (inf-le prevt3 15) t3b1
  (pi j nat (inf-le (Lzt3 j) 15)) t3b2
  (pi k nat (inf-le (Clt3 k) 15)) t3a2
 )
 (defcx inf-ststep-c3 inf-ststep-c2 (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (opt3 nat) (Lct3 (pi j nat nat)) (Lst3 (pi j nat nat)) (Ltt3 (pi j nat nat)) (Dct3 (pi j nat nat)) (Dst3 (pi j nat nat)) (Dtt3 (pi j nat nat)) (lmt3 nat) (dmt3 nat) (Clt3 (pi j nat nat)) (Lzt3 (pi j nat nat)) (Cst3 (pi j nat nat)) (Ctt3 (pi j nat nat)) (Cct3 (pi j nat nat)) (lastt3 nat) (remt3 nat) (hclent3 nat) (it3 nat) (prevt3 nat) (staget3 nat) (syt3 nat) (lent3 nat) (distt3 nat) (modet3 nat) (hlitt3 nat) (hdistt3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e8 (inf-le opt3 cap)) (t3e9 (inf-le op opt3)) (t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h)))) (t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h)))) (t3c3 (inf-le (inf-sum Lct3 15 1) lmt3)) (t3c4 (inf-le lmt3 288)) (t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h)))) (t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h)))) (t3c7 (inf-le (inf-sum Dct3 15 1) dmt3)) (t3c8 (inf-le dmt3 32)) (t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h)))) (t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h)))) (t3d3 (inf-le (inf-sum Cct3 15 1) 19)) (t3b1 (inf-le prevt3 15)) (t3b2 (pi j nat (inf-le (Lzt3 j) 15))) (t3a2 (pi k nat (inf-le (Clt3 k) 15))) )
 (defvcs inf-vc-ststep-w1b 1 inf-ststep-c3 ()
  (inf-le ipt3 n) t3e1
  (inf-le bct3 63) t3e3
  (inf-bits-inv carry ipt3 const3 bct3) t3e4
  (inf-le cons0 const3) (inf-letrans cons0 cons const3 r5 (inf-letrans cons const2 const3 t2e5 t3e5))
  (inf-le op0 opt3) (inf-letrans op0 op opt3 o1 t3e9)
  (inf-le opt3 cap) t3e8
  (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c1
  (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c2
  (inf-le (inf-sum Lct3 15 1) lmt3) t3c3
  (inf-le lmt3 288) t3c4
  (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c5
  (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c6
  (inf-le (inf-sum Dct3 15 1) dmt3) t3c7
  (inf-le dmt3 32) t3c8
  (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d1
  (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d2
  (inf-le (inf-sum Cct3 15 1) 19) t3d3
  (inf-le prevt3 15) t3b1
  (pi j nat (inf-le (Lzt3 j) 15)) t3b2
  (pi k nat (inf-le (Clt3 k) 15)) t3a2
  (inf-lt (natminus (add carry (inf-by8 n)) const3) (natminus (add carry (inf-by8 n)) cons)) (inf-consfall carry ipt3 const3 bct3 n cons t3e4 t3e1 (inf-lttrans cons (add cons 3) const3 (inf-ltaddpos cons 3 (idpath true)) (inf-letrans (add cons 3) const2 const3 t2e6 t3e5)))
 )
 (defvcs inf-vc-ststep-r1 1 inf-ststep-c1-w1 (w1 (inf-lt 0 mode))
  (inf-le ip n) r1
  (inf-le bc 63) r3
  (inf-bits-inv carry ip cons bc) r4
  (inf-le cons0 cons) r5
  (inf-le op cap) o2
  (inf-le op0 op) o1
  (pi k nat (inf-lt (Lc k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls k) (inf-pow h))) c2
  (inf-le (inf-sum Lc 15 1) lm) c3
  (inf-le lm 288) c4
  (pi k nat (inf-lt (Dc k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds k) (inf-pow h))) c6
  (inf-le (inf-sum Dc 15 1) dm) c7
  (inf-le dm 32) c8
  (pi k nat (inf-lt (Cc k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs k) (inf-pow h))) d2
  (inf-le (inf-sum Cc 15 1) 19) d3
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
  (pi k nat (inf-le (Cl k) 15)) a2
 )
 (defcx inf-stkeep (w nat) (op nat) (oc nat) (hlen0 nat) (lw nat) (lim nat) (gw (inf-le 32 w)) (gop (inf-le op oc)) (hww (inf-le lw lim)) (hs (inf-le (succ lw) lim)) (hm (inf-lt lim 31)) (gh (inf-le hlen0 (inf-pow lim))) )
 (defvcs inf-vc-stkeep-i1 1 inf-stkeep ()
  (inf-lt lw 32) (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-lt (inf-pow lw) (inf-pow w)) (inf-wpow w lw gw (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
 )
 (defvcs inf-vc-stkeep-m1 1 inf-stkeep (g1 (inf-le (inf-pow lw) op))
  (inf-lt lw 32) (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-lt (inf-pow lw) (inf-pow w)) (inf-wpow w lw gw (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
  (inf-le (inf-pow lw) op) g1
  (inf-le (add 0 (inf-pow lw)) (inf-pow lim)) ((inf-powle lw lim hww))
  (inf-le (add (natminus op (inf-pow lw)) (inf-pow lw)) oc) (inf-letrans (add (natminus op (inf-pow lw)) (inf-pow lw)) op oc (inf-subfit op (inf-pow lw) g1) gop)
 )
 (defvcs inf-vc-stkeep-d1 1 inf-stkeep (g1 (inf-le (inf-pow lw) op))
  (inf-lt lw 32) (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-lt (inf-pow lw) (inf-pow w)) (inf-wpow w lw gw (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
 )
 (defvcs inf-vc-stkeep-j1 1 inf-stkeep (g1 (inf-lt op (inf-pow lw)))
  (inf-lt lim 32) (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))
  (inf-lt (inf-pow lim) (inf-pow w)) (inf-wpow w lim gw (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-lt (add hlen0 op) (inf-pow w)) (inf-fitlim w lim hlen0 op gw hm gh (inf-letrans op (inf-pow lw) (inf-pow lim) (inf-ltle op (inf-pow lw) g1) (inf-letrans (inf-pow lw) (inf-pow lim) (inf-pow lim) (inf-powle lw lim hww) (inf-refl (inf-pow lim)))))
 )
 (defvcs inf-vc-stkeep-j2 1 inf-stkeep (g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)))
  (inf-lt lw 32) (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-lt (inf-pow lw) (inf-pow w)) (inf-wpow w lw gw (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
 )
 (defvcs inf-vc-stkeep-j2j 1 inf-stkeep (g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) g3 (inf-lt hlen0 (inf-pow lw)))
  (inf-le hlen0 hlen0) (inf-refl hlen0)
  (inf-le hlen0 (inf-pow lw)) (inf-letrans hlen0 (inf-pow lw) (inf-pow lw) (inf-ltle hlen0 (inf-pow lw) g3) (inf-refl (inf-pow lw)))
 )
 (defvcs inf-vc-stkeep-d3 1 inf-stkeep (g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) g3 (inf-le (inf-pow lw) hlen0))
  (inf-lt lw 32) (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-lt (inf-pow lw) (inf-pow w)) (inf-wpow w lw gw (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
 )
 (defvcs inf-vc-stkeep-j2j 3 inf-stkeep (g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) g3 (inf-le (inf-pow lw) hlen0))
  (inf-le (inf-pow lw) hlen0) g3
  (inf-le (inf-pow lw) (inf-pow lw)) (inf-refl (inf-pow lw))
 )
 (defcx inf-stkeep-c2 inf-stkeep (g1 (inf-lt op (inf-pow lw))) (g2 (inf-lt (inf-pow lim) (add hlen0 op))) (kj2 nat) (a1 (inf-le kj2 hlen0)) (a2 (inf-le kj2 (inf-pow lw))) )
 (defvcs inf-vc-stkeep-m2 1 inf-stkeep-c2 ()
  (inf-le kj2 hlen0) a1
  (inf-le (add 0 kj2) (inf-pow lim)) (inf-letrans kj2 (inf-pow lw) (inf-pow lim) a2 ((inf-powle lw lim hww)))
  (inf-le (add (natminus hlen0 kj2) kj2) (inf-pow lim)) (inf-letrans (add (natminus hlen0 kj2) kj2) hlen0 (inf-pow lim) (inf-subfit hlen0 kj2 a1) gh)
 )
 (defvcs inf-vc-stkeep-j1j 1 inf-stkeep-c2 ()
  (inf-le (add kj2 op) (inf-pow lim)) (inf-letrans (add kj2 op) (inf-pow (succ lw)) (inf-pow lim) (inf-powdbl lw kj2 op a2 (inf-ltle op (inf-pow lw) g1)) (inf-powle (succ lw) lim hs))
 )
 (defvcs inf-vc-stkeep-j1j 2 inf-stkeep (g1 (inf-lt op (inf-pow lw)) g2 (inf-le (add hlen0 op) (inf-pow lim)))
  (inf-le (add hlen0 op) (inf-pow lim)) g2
 )
 (defcx inf-stkeep-c1 inf-stkeep (g1 (inf-lt op (inf-pow lw))) (hlenj1 nat) (a3 (inf-le (add hlenj1 op) (inf-pow lim))) )
 (defvcs inf-vc-stkeep-m3 1 inf-stkeep-c1 ()
  (inf-le (add hlenj1 op) (inf-pow lim)) a3
  (inf-le (add 0 op) oc) gop
 )
 (defvcs inf-vc-stkeep-d5 1 inf-stkeep-c1 ()
  (inf-lt (add hlenj1 op) (inf-pow w)) (inf-lelt (add hlenj1 op) (inf-pow lim) (inf-pow w) a3 (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false))))
 )
 (defcx inf-stfeed (nin nat) (out0 nat) (oc0 nat) (cap0 nat) (nd0 nat) (hlen0 nat) (lim nat) (lw nat) (lh nat) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hll (inf-le lh lim)) (hww (inf-le lw lh)) (hsw (inf-le (succ lw) lh)) (hlh (inf-lt lh 31)) (hf (inf-le (succ (succ (succ lh))) lim)) (h12 (inf-le 12 lh)) (In (pi k nat nat)) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gs (inf-le bc0 63)) (op0 nat) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (last0 nat) (rem0 nat) (hclen0 nat) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) (mode0 nat) (hlit0 nat) (hdist0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (b1 (inf-le prev0 15)) (b2 (pi j nat (inf-le (Lz0 j) 15))) (a2 (pi k nat (inf-le (Cl0 k) 15))) )
 (defvcs inf-vc-stfeed-r1 1 inf-stfeed (g1 unit)
  (inf-le 0 nin) (idpath false)
  (inf-le bc0 63) gs
  (inf-le 0 0) (idpath false)
  (pi g (inf-lt 0 0) (paths nat 0 0)) (lam g (idpath 0))
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defvcs inf-vc-stfeed-i2 1 inf-stfeed (g1 (inf-lt (add nin 8) (inf-pow w)))
  (inf-lt lh 32) (inf-lelts lh 31 (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-lt (inf-pow lh) (inf-pow w)) (inf-wpow w lh gw (inf-lelts lh 31 (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
 )
 (defvcs inf-vc-stfeed-r2 1 inf-stfeed (g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0))
  (inf-le 0 nin) (idpath false)
  (inf-le bc0 63) gs
  (inf-le 0 0) (idpath false)
  (pi g (inf-lt 0 0) (paths nat 0 0)) (lam g (idpath 0))
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defvcs inf-vc-stfeed-j1 1 inf-stfeed (g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)))
  (inf-lt lw 32) (inf-lelts lw 31 (inf-letrans lw lh 31 hww (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
  (inf-lt (inf-pow lw) (inf-pow w)) (inf-wpow w lw gw (inf-lelts lw 31 (inf-letrans lw lh 31 hww (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))
 )
 (defvcs inf-vc-stfeed-j1j 1 inf-stfeed (g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) g3 (inf-lt hlen0 (inf-pow lw)))
  (inf-le hlen0 hlen0) (inf-refl hlen0)
  (inf-le hlen0 (inf-pow lw)) (inf-letrans hlen0 (inf-pow lw) (inf-pow lw) (inf-ltle hlen0 (inf-pow lw) g3) (inf-refl (inf-pow lw)))
 )
 (defvcs inf-vc-stfeed-d5 1 inf-stfeed (g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) g3 (inf-le (inf-pow lw) hlen0))
  (inf-lt lw 32) (inf-lelts lw 31 (inf-letrans lw lh 31 hww (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
  (inf-lt (inf-pow lw) (inf-pow w)) (inf-wpow w lw gw (inf-lelts lw 31 (inf-letrans lw lh 31 hww (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))
 )
 (defvcs inf-vc-stfeed-j1j 3 inf-stfeed (g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) g3 (inf-le (inf-pow lw) hlen0))
  (inf-le (inf-pow lw) hlen0) g3
  (inf-le (inf-pow lw) (inf-pow lw)) (inf-refl (inf-pow lw))
 )
 (defcx inf-stfeed-c1 inf-stfeed (g1 (inf-lt (add nin 8) (inf-pow w))) (g2 (inf-le hlen0 (inf-pow lh))) (ndj1 nat) (n1 (inf-le ndj1 hlen0)) (n2 (inf-le ndj1 (inf-pow lw))) )
 (defvcs inf-vc-stfeed-v1 1 inf-stfeed-c1 ()
  (inf-le ndj1 hlen0) n1
  (inf-le (add (natminus hlen0 ndj1) ndj1) (inf-pow lh)) (inf-letrans (add (natminus hlen0 ndj1) ndj1) hlen0 (inf-pow lh) (inf-subfit hlen0 ndj1 n1) g2)
 )
 (defvcs inf-vc-stfeed-j2 1 inf-stfeed-c1 ()
  (inf-lt lh 32) (inf-lelts lh 31 (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-lt (inf-pow lh) (inf-pow w)) (inf-wpow w lh gw (inf-lelts lh 31 (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
 )
 (defvcs inf-vc-stfeed-d8 1 inf-stfeed-c1 (g4 (inf-le nin (inf-pow lh)))
  (inf-lt (add nin nin) (inf-pow w)) (inf-fitlim w lim nin nin gw hm (inf-letrans nin (inf-pow lh) (inf-pow lim) g4 (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim)))) (inf-letrans nin (inf-pow lh) (inf-pow lim) g4 (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim)))))
  (inf-lt (add (add nin nin) (add nin nin)) (inf-pow w)) (inf-lelt ((add (add nin nin) (add nin nin))) (inf-pow lim) (inf-pow w) ((inf-four lh lim nin g4 hf)) ((inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))
  (inf-lt 12 32) (idpath true)
  (inf-lt (inf-pow 12) (inf-pow w)) (inf-wpow w 12 gw (idpath true))
  (inf-lt (add (add (add nin nin) (add nin nin)) (inf-pow 12)) (inf-pow w)) (inf-fitlim w lim ((add (add nin nin) (add nin nin))) (inf-pow 12) gw hm ((inf-four lh lim nin g4 hf)) (inf-powle 12 lim (inf-letrans 12 lh lim h12 hll)))
 )
 (defvcs inf-vc-stfeed-j2j 1 inf-stfeed-c1 (g4 (inf-le nin (inf-pow lh)))
  (inf-le (add (add (add nin nin) (add nin nin)) (inf-pow 12)) (inf-pow lim)) (inf-fourp lh lim nin (inf-pow 12) g4 (inf-powle 12 lh h12) hf)
  (inf-lt 0 (add (add (add nin nin) (add nin nin)) (inf-pow 12))) (inf-lttrans 0 (inf-pow 12) (add ((add (add nin nin) (add nin nin))) (inf-pow 12)) (inf-powpos 12) (inf-leaddl (inf-pow 12) ((add (add nin nin) (add nin nin)))))
 )
 (defvcs inf-vc-stfeed-d10 1 inf-stfeed-c1 (g4 (inf-lt (inf-pow lh) nin))
  (inf-lt lh 32) (inf-lelts lh 31 (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-lt (inf-pow lh) (inf-pow w)) (inf-wpow w lh gw (inf-lelts lh 31 (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))
 )
 (defvcs inf-vc-stfeed-j2j 3 inf-stfeed-c1 (g4 (inf-lt (inf-pow lh) nin))
  (inf-le (inf-pow lh) (inf-pow lim)) (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim)))
  (inf-lt 0 (inf-pow lh)) (inf-powpos lh)
 )
 (defcx inf-stfeed-c2 inf-stfeed-c1 (capj2 nat) (n3 (inf-le capj2 (inf-pow lim))) (n5 (inf-lt 0 capj2)) )
 (defvcs inf-vc-stfeed-r3 1 inf-stfeed-c2 (outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0))
  (inf-le 0 nin) (idpath false)
  (inf-le bc0 63) gs
  (inf-le 0 capj2) (idpath false)
  (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g6
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defvcs inf-vc-stfeed-w1e 1 inf-stfeed-c2 (outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4))
  (inf-le 0 nin) (idpath false)
  (inf-le bc0 63) gs
  (inf-bits-inv (add cons0 bc0) 0 cons0 bc0) (natplusr0 (add cons0 bc0))
  (inf-le cons0 cons0) (inf-refl cons0)
  (inf-le 0 capj2) (idpath false)
  (inf-le capj2 (inf-pow lim)) n3
  (inf-lt 0 outn4) g7
  (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g6
  (inf-lt 0 capj2) n5
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defcx inf-stfeed-c2-w1 inf-stfeed-c2 (outn4 nat) (ocn4 nat) (g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2))) (g7 (inf-lt 0 outn4)) (out nat) (oc nat) (cap nat) (op nat) (ip nat) (bc nat) (bb nat) (cons nat) (Lc (pi j nat nat)) (Ls (pi j nat nat)) (Lt (pi j nat nat)) (Dc (pi j nat nat)) (Ds (pi j nat nat)) (Dt (pi j nat nat)) (lm nat) (dm nat) (Cl (pi j nat nat)) (Lz (pi j nat nat)) (Cs (pi j nat nat)) (Ct (pi j nat nat)) (Cc (pi j nat nat)) (last nat) (rem nat) (hclen nat) (i nat) (prev nat) (stage nat) (sy nat) (len nat) (dist nat) (mode nat) (hlit nat) (hdist nat) (r1 (inf-le ip nin)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv (add cons0 bc0) ip cons bc)) (r5 (inf-le cons0 cons)) (o2 (inf-le op cap)) (k1 (inf-le cap (inf-pow lim))) (k2 (inf-lt 0 out)) (k3 (pi g (inf-lt 0 out) (paths nat oc cap))) (k6 (inf-lt 0 cap)) (c1 (pi k nat (inf-lt (Lc k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc 15 1) lm)) (c4 (inf-le lm 288)) (c5 (pi k nat (inf-lt (Dc k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc 15 1) dm)) (c8 (inf-le dm 32)) (d1 (pi k nat (inf-lt (Cc k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc 15 1) 19)) (b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))) (a2 (pi k nat (inf-le (Cl k) 15))) )
 (defvcs inf-vc-stfeed-c1 1 inf-stfeed-c2-w1 (w1 unit)
  (inf-le 32 w) gw
  (inf-lt (add nin 8) (inf-pow w)) g1
  (inf-le ip nin) r1
  (inf-le bc 63) r3
  (inf-bits-inv (add cons0 bc0) ip cons bc) r4
  (pi g (inf-lt 0 out) (paths nat oc cap)) k3
  (inf-lt (add cap 8) (inf-pow w)) (inf-fitlim w lim cap 8 gw hm k1 (inf-letrans 8 (inf-pow 9) (inf-pow lim) (idpath false) (inf-letrans (inf-pow 9) (inf-pow lim) (inf-pow lim) (inf-powle 9 lim (inf-letrans 9 19 lim (idpath false) hl)) (inf-refl (inf-pow lim)))))
  (inf-le op cap) o2
  (inf-lt (add cap ndj1) (inf-pow w)) (inf-fitlim w lim cap ndj1 gw hm k1 (inf-letrans ndj1 (inf-pow lw) (inf-pow lim) n2 (inf-letrans (inf-pow lw) (inf-pow lh) (inf-pow lim) (inf-powle lw lh hww) (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim))))))
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
  (inf-lt (add cap 266) (inf-pow w)) (inf-fitlim w lim cap 266 gw hm k1 (inf-letrans 266 (inf-pow 9) (inf-pow lim) (idpath false) (inf-letrans (inf-pow 9) (inf-pow lim) (inf-pow lim) (inf-powle 9 lim (inf-letrans 9 19 lim (idpath false) hl)) (inf-refl (inf-pow lim)))))
  (inf-lt 0 out) k2
  (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)) hord
  (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)) hle
  (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)) hlb
  (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))) hlc
  (pi k nat g (inf-lt k 30) (inf-le (De k) 13)) hde
  (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))) hdb
  (pi k nat (inf-lt (Lc k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls k) (inf-pow h))) c2
  (inf-le (inf-sum Lc 15 1) lm) c3
  (inf-le lm 288) c4
  (pi k nat (inf-lt (Dc k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds k) (inf-pow h))) c6
  (inf-le (inf-sum Dc 15 1) dm) c7
  (inf-le dm 32) c8
  (pi k nat (inf-lt (Cc k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs k) (inf-pow h))) d2
  (inf-le (inf-sum Cc 15 1) 19) d3
  (inf-le prev 15) b1
  (pi j nat (inf-le (Lz j) 15)) b2
  (pi k nat (inf-le (Cl k) 15)) a2
 )
 (defcx inf-stfeed-c3 inf-stfeed-c2-w1 (w1 unit) (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (opc1 nat) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (Clc1 (pi j nat nat)) (Lzc1 (pi j nat nat)) (Csc1 (pi j nat nat)) (Ctc1 (pi j nat nat)) (Ccc1 (pi j nat nat)) (lastc1 nat) (remc1 nat) (hclenc1 nat) (ic1 nat) (prevc1 nat) (stagec1 nat) (syc1 nat) (lenc1 nat) (distc1 nat) (modec1 nat) (hlitc1 nat) (hdistc1 nat) (xc1 nat) (c1e1 (inf-le ipc1 nin)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv (add cons0 bc0) ipc1 consc1 bcc1)) (c1e5 (inf-le cons consc1)) (c1e8 (inf-le opc1 cap)) (c1e9 (inf-le op opc1)) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) (c1d1 (pi k nat (inf-lt (Ccc1 k) (inf-pow h)))) (c1d2 (pi k nat (inf-lt (Csc1 k) (inf-pow h)))) (c1d3 (inf-le (inf-sum Ccc1 15 1) 19)) (c1b1 (inf-le prevc1 15)) (c1b2 (pi j nat (inf-le (Lzc1 j) 15))) (c1a2 (pi k nat (inf-le (Clc1 k) 15))) )
 (defvcs inf-vc-stfeed-c2 1 inf-stfeed-c3 (g9 unit)
  (inf-le 32 w) gw
  (inf-le opc1 oc) ((inf-letl opc1 cap oc (pathsinv0 nat oc cap (k3 k2)) c1e8))
  (inf-le lw lh) hww
  (inf-le (succ lw) lh) hsw
  (inf-lt lh 31) hlh
  (inf-le hlen0 (inf-pow lh)) g2
 )
 (defcx inf-stfeed-c7 inf-stfeed-c3 (g9 unit) (hlenc2 nat) )
 (defvcs inf-vc-stfeed-r4 1 inf-stfeed-c7 ()
  (inf-le ipc1 nin) c1e1
  (inf-le bcc1 63) c1e3
  (inf-le opc1 cap) c1e8
  (pi g (inf-lt 0 out) (paths nat oc cap)) k3
  (pi k nat (inf-lt (Lcc1 k) (inf-pow h))) c1c1
  (pi k nat (inf-lt (Lsc1 k) (inf-pow h))) c1c2
  (inf-le (inf-sum Lcc1 15 1) lmc1) c1c3
  (inf-le lmc1 288) c1c4
  (pi k nat (inf-lt (Dcc1 k) (inf-pow h))) c1c5
  (pi k nat (inf-lt (Dsc1 k) (inf-pow h))) c1c6
  (inf-le (inf-sum Dcc1 15 1) dmc1) c1c7
  (inf-le dmc1 32) c1c8
  (pi k nat (inf-lt (Ccc1 k) (inf-pow h))) c1d1
  (pi k nat (inf-lt (Csc1 k) (inf-pow h))) c1d2
  (inf-le (inf-sum Ccc1 15 1) 19) c1d3
  (inf-le prevc1 15) c1b1
  (pi j nat (inf-le (Lzc1 j) 15)) c1b2
  (pi k nat (inf-le (Clc1 k) 15)) c1a2
 )
 (defvcs inf-vc-stfeed-i6 1 inf-stfeed-c3 (g9 unit)
  (inf-lt lim 32) (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))
  (inf-lt (inf-pow lim) (inf-pow w)) (inf-wpow w lim gw (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
 )
 (defvcs inf-vc-stfeed-c2 7 inf-stfeed-c3 (g9 unit g10 (inf-le (inf-pow lim) cap))
  (inf-le 32 w) gw
  (inf-le opc1 oc) ((inf-letl opc1 cap oc (pathsinv0 nat oc cap (k3 k2)) c1e8))
  (inf-le lw lh) hww
  (inf-le (succ lw) lh) hsw
  (inf-lt lh 31) hlh
  (inf-le hlen0 (inf-pow lh)) g2
 )
 (defcx inf-stfeed-c6 inf-stfeed-c3 (g9 unit) (g10 (inf-le (inf-pow lim) cap)) (hlenc2 nat) )
 (defvcs inf-vc-stfeed-r4 19 inf-stfeed-c6 ()
  (inf-le ipc1 nin) c1e1
  (inf-le bcc1 63) c1e3
  (inf-le opc1 cap) c1e8
  (pi g (inf-lt 0 out) (paths nat oc cap)) k3
  (pi k nat (inf-lt (Lcc1 k) (inf-pow h))) c1c1
  (pi k nat (inf-lt (Lsc1 k) (inf-pow h))) c1c2
  (inf-le (inf-sum Lcc1 15 1) lmc1) c1c3
  (inf-le lmc1 288) c1c4
  (pi k nat (inf-lt (Dcc1 k) (inf-pow h))) c1c5
  (pi k nat (inf-lt (Dsc1 k) (inf-pow h))) c1c6
  (inf-le (inf-sum Dcc1 15 1) dmc1) c1c7
  (inf-le dmc1 32) c1c8
  (pi k nat (inf-lt (Ccc1 k) (inf-pow h))) c1d1
  (pi k nat (inf-lt (Csc1 k) (inf-pow h))) c1d2
  (inf-le (inf-sum Ccc1 15 1) 19) c1d3
  (inf-le prevc1 15) c1b1
  (pi j nat (inf-le (Lzc1 j) 15)) c1b2
  (pi k nat (inf-le (Clc1 k) 15)) c1a2
 )
 (defvcs inf-vc-stfeed-j3 1 inf-stfeed-c3 (g9 unit g10 (inf-lt cap (inf-pow lim)))
  (inf-lt lim 32) (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))
  (inf-lt (inf-pow lim) (inf-pow w)) (inf-wpow w lim gw (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
  (inf-le cap (inf-pow lim)) k1
 )
 (defvcs inf-vc-stfeed-d11 1 inf-stfeed-c3 (g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-lt cap (natminus (inf-pow lim) cap)))
  (inf-lt (add cap cap) (inf-pow w)) (inf-lelt (add cap cap) (inf-pow lim) (inf-pow w) ((inf-roomle cap (inf-pow lim) cap (inf-ltle cap (natminus (inf-pow lim) cap) g11) k1)) ((inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))
 )
 (defvcs inf-vc-stfeed-j3j 1 inf-stfeed-c3 (g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-lt cap (natminus (inf-pow lim) cap)))
  (inf-lt cap (add cap cap)) (inf-ltdbl cap k6)
  (inf-le (add cap cap) (inf-pow lim)) ((inf-roomle cap (inf-pow lim) cap (inf-ltle cap (natminus (inf-pow lim) cap) g11) k1))
 )
 (defvcs inf-vc-stfeed-d12 1 inf-stfeed-c3 (g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-le (natminus (inf-pow lim) cap) cap))
  (inf-lt lim 32) (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))
  (inf-lt (inf-pow lim) (inf-pow w)) (inf-wpow w lim gw (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))
 )
 (defvcs inf-vc-stfeed-j3j 3 inf-stfeed-c3 (g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-le (natminus (inf-pow lim) cap) cap))
  (inf-lt cap (inf-pow lim)) g10
  (inf-le (inf-pow lim) (inf-pow lim)) (inf-refl (inf-pow lim))
 )
 (defcx inf-stfeed-c4 inf-stfeed-c3 (g9 unit) (g10 (inf-lt cap (inf-pow lim))) (ncapj3 nat) (k4 (inf-lt cap ncapj3)) (k5 (inf-le ncapj3 (inf-pow lim))) )
 (defvcs inf-vc-stfeed-c2 13 inf-stfeed-c4 (nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (paths nat nbn5 0))
  (inf-le 32 w) gw
  (inf-le opc1 oc) ((inf-letl opc1 cap oc (pathsinv0 nat oc cap (k3 k2)) c1e8))
  (inf-le lw lh) hww
  (inf-le (succ lw) lh) hsw
  (inf-lt lh 31) hlh
  (inf-le hlen0 (inf-pow lh)) g2
 )
 (defcx inf-stfeed-c5 inf-stfeed-c4 (nbn5 nat) (nocn5 nat) (g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3))) (g13 (paths nat nbn5 0)) (hlenc2 nat) )
 (defvcs inf-vc-stfeed-r4 37 inf-stfeed-c5 ()
  (inf-le ipc1 nin) c1e1
  (inf-le bcc1 63) c1e3
  (inf-le opc1 cap) c1e8
  (pi g (inf-lt 0 out) (paths nat oc cap)) k3
  (pi k nat (inf-lt (Lcc1 k) (inf-pow h))) c1c1
  (pi k nat (inf-lt (Lsc1 k) (inf-pow h))) c1c2
  (inf-le (inf-sum Lcc1 15 1) lmc1) c1c3
  (inf-le lmc1 288) c1c4
  (pi k nat (inf-lt (Dcc1 k) (inf-pow h))) c1c5
  (pi k nat (inf-lt (Dsc1 k) (inf-pow h))) c1c6
  (inf-le (inf-sum Dcc1 15 1) dmc1) c1c7
  (inf-le dmc1 32) c1c8
  (pi k nat (inf-lt (Ccc1 k) (inf-pow h))) c1d1
  (pi k nat (inf-lt (Csc1 k) (inf-pow h))) c1d2
  (inf-le (inf-sum Ccc1 15 1) 19) c1d3
  (inf-le prevc1 15) c1b1
  (pi j nat (inf-le (Lzc1 j) 15)) c1b2
  (pi k nat (inf-le (Clc1 k) 15)) c1a2
 )
 (defvcs inf-vc-stfeed-m1 1 inf-stfeed-c4 (nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5))
  (inf-le (add 0 opc1) nocn5) (inf-letl opc1 ncapj3 nocn5 (pathsinv0 nat nocn5 ncapj3 (g12 g13)) (inf-letrans opc1 cap ncapj3 c1e8 (inf-ltle cap ncapj3 k4)))
  (inf-le (add 0 opc1) oc) ((inf-letl opc1 cap oc (pathsinv0 nat oc cap (k3 k2)) c1e8))
 )
 (defvcs inf-vc-stfeed-w1b 1 inf-stfeed-c4 (nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5))
  (inf-le ipc1 nin) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv (add cons0 bc0) ipc1 consc1 bcc1) c1e4
  (inf-le cons0 consc1) (inf-letrans cons0 cons consc1 r5 c1e5)
  (inf-le opc1 ncapj3) (inf-letrans opc1 cap ncapj3 c1e8 (inf-letrans cap ncapj3 ncapj3 (inf-ltle cap ncapj3 k4) (inf-refl ncapj3)))
  (inf-le ncapj3 (inf-pow lim)) k5
  (inf-lt 0 nbn5) g13
  (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g12
  (inf-lt 0 ncapj3) (inf-lttrans 0 cap ncapj3 k6 (inf-ltle cap ncapj3 k4))
  (pi k nat (inf-lt (Lcc1 k) (inf-pow h))) c1c1
  (pi k nat (inf-lt (Lsc1 k) (inf-pow h))) c1c2
  (inf-le (inf-sum Lcc1 15 1) lmc1) c1c3
  (inf-le lmc1 288) c1c4
  (pi k nat (inf-lt (Dcc1 k) (inf-pow h))) c1c5
  (pi k nat (inf-lt (Dsc1 k) (inf-pow h))) c1c6
  (inf-le (inf-sum Dcc1 15 1) dmc1) c1c7
  (inf-le dmc1 32) c1c8
  (pi k nat (inf-lt (Ccc1 k) (inf-pow h))) c1d1
  (pi k nat (inf-lt (Csc1 k) (inf-pow h))) c1d2
  (inf-le (inf-sum Ccc1 15 1) 19) c1d3
  (inf-le prevc1 15) c1b1
  (pi j nat (inf-le (Lzc1 j) 15)) c1b2
  (pi k nat (inf-le (Clc1 k) 15)) c1a2
  (inf-lt (natminus (inf-pow lim) ncapj3) (natminus (inf-pow lim) cap)) (inf-subdown (inf-pow lim) cap ncapj3 k4 k5)
 )
 (defcx inf-st0 (In (pi k nat nat)) (nin nat) (w nat) (gw (inf-le 32 w)) )
 (defvcs inf-vc-st0-c1 1 inf-st0 ()
  (inf-le 19 30) (idpath false)
  (inf-lt 30 31) (idpath true)
  (inf-le 16 30) (idpath false)
  (inf-le 15 16) (idpath false)
  (inf-le (succ 15) 16) (idpath false)
  (inf-lt 16 31) (idpath true)
  (inf-le (succ (succ (succ 16))) 30) (idpath false)
  (inf-le 12 16) (idpath false)
  (inf-le 32 w) gw
  (inf-le 0 63) (idpath false)
  (inf-le 16 16) (idpath false)
  (inf-le (inf-by16 (inf-pow 12)) (inf-pow 16)) inf-topq
  (inf-lt 320 (inf-pow 12)) (idpath true)
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk (inf-pow 12) k) (inf-pow w))) (inf-topk w gw)
  (inf-le 12 15) (idpath false)
  (inf-le 9 15) (idpath false)
  (inf-le 7 15) (idpath false)
  (pi k nat g (inf-lt k 19) (inf-lt (inf-tob k) 19)) (lam k g (inf-lelts (inf-tob k) 18 (inf-anyno (lam j (natgtb (inf-tob j) 18)) 19 (idpath false) k g)))
  (pi k nat g (inf-lt k 29) (inf-le (inf-tle k) 5)) (inf-anyno (lam j (natgtb (inf-tle j) 5)) 29 (idpath false))
  (pi k nat g (inf-lt k 29) (inf-le (add (inf-tlb k) (inf-pow (inf-tle k))) 259)) (inf-anyno (lam j (natgtb (add (inf-tlb j) (inf-pow (inf-tle j))) 259)) 29 (idpath false))
  (pi k nat g (inf-lt k 29) (inf-le 3 (inf-tlb k))) (inf-anyno (lam j (natgtb 3 (inf-tlb j))) 29 (idpath false))
  (pi k nat g (inf-lt k 30) (inf-le (inf-tde k) 13)) (inf-anyno (lam j (natgtb (inf-tde j) 13)) 30 (idpath false))
  (pi k nat g (inf-lt k 30) (inf-le (add (inf-tdb k) (inf-pow (inf-tde k))) (inf-pow 16))) (inf-anyno (lam j (natgtb (add (inf-tdb j) (inf-pow (inf-tde j))) (inf-pow 16))) 30 (idpath false))
  (pi k nat (inf-lt (inf-zero k) (inf-pow 16))) (lam k (inf-powpos 16))
  (inf-le (inf-sum inf-zero 15 1) 0) (idpath false)
  (inf-le 0 288) (idpath false)
  (inf-le 0 32) (idpath false)
  (inf-le (inf-sum inf-zero 15 1) 19) (idpath false)
  (inf-le 0 15) (idpath false)
  (pi j nat (inf-le (inf-zero j) 15)) (lam j (idpath false))
  (pi k nat (inf-le (inf-zero k) 15)) (lam k (idpath false))
 )
 (defcx inf-st0-c1 inf-st0 (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (opc1 nat) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (Clc1 (pi j nat nat)) (Lzc1 (pi j nat nat)) (Csc1 (pi j nat nat)) (Ctc1 (pi j nat nat)) (Ccc1 (pi j nat nat)) (lastc1 nat) (remc1 nat) (hclenc1 nat) (ic1 nat) (prevc1 nat) (stagec1 nat) (syc1 nat) (lenc1 nat) (distc1 nat) (modec1 nat) (hlitc1 nat) (hdistc1 nat) (outc1 nat) (occ1 nat) (capc1 nat) (ndc1 nat) (hlenc1 nat) (c1e1 (inf-le ipc1 nin)) (c1e3 (inf-le bcc1 63)) (c1e8 (inf-le opc1 capc1)) (c1eg (pi g (inf-lt 0 outc1) (paths nat occ1 capc1))) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow 16)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow 16)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow 16)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow 16)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) (c1d1 (pi k nat (inf-lt (Ccc1 k) (inf-pow 16)))) (c1d2 (pi k nat (inf-lt (Csc1 k) (inf-pow 16)))) (c1d3 (inf-le (inf-sum Ccc1 15 1) 19)) (c1b1 (inf-le prevc1 15)) (c1b2 (pi j nat (inf-le (Lzc1 j) 15))) (c1a2 (pi k nat (inf-le (Clc1 k) 15))) )
 (defcx inf-stn (nin nat) (out0 nat) (oc0 nat) (cap0 nat) (nd0 nat) (hlen0 nat) (lim nat) (lw nat) (lh nat) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hll (inf-le lh lim)) (hww (inf-le lw lh)) (hsw (inf-le (succ lw) lh)) (hlh (inf-lt lh 31)) (hf (inf-le (succ (succ (succ lh))) lim)) (h12 (inf-le 12 lh)) (In (pi k nat nat)) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gs (inf-le bc0 63)) (op0 nat) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (last0 nat) (rem0 nat) (hclen0 nat) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) (mode0 nat) (hlit0 nat) (hdist0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (b1 (inf-le prev0 15)) (b2 (pi j nat (inf-le (Lz0 j) 15))) (a2 (pi k nat (inf-le (Cl0 k) 15))) (In2 (pi k nat nat)) (nin2 nat) )
 (defvcs inf-vc-stn-c1 1 inf-stn ()
  (inf-le 19 lim) hl
  (inf-lt lim 31) hm
  (inf-le lh lim) hll
  (inf-le lw lh) hww
  (inf-le (succ lw) lh) hsw
  (inf-lt lh 31) hlh
  (inf-le (succ (succ (succ lh))) lim) hf
  (inf-le 12 lh) h12
  (inf-le 32 w) gw
  (inf-le bc0 63) gs
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
  (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)) hord
  (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)) hle
  (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)) hlb
  (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))) hlc
  (pi k nat g (inf-lt k 30) (inf-le (De k) 13)) hde
  (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))) hdb
  (pi k nat (inf-lt (Lc0 k) (inf-pow h))) c1
  (pi k nat (inf-lt (Ls0 k) (inf-pow h))) c2
  (inf-le (inf-sum Lc0 15 1) lm0) c3
  (inf-le lm0 288) c4
  (pi k nat (inf-lt (Dc0 k) (inf-pow h))) c5
  (pi k nat (inf-lt (Ds0 k) (inf-pow h))) c6
  (inf-le (inf-sum Dc0 15 1) dm0) c7
  (inf-le dm0 32) c8
  (pi k nat (inf-lt (Cc0 k) (inf-pow h))) d1
  (pi k nat (inf-lt (Cs0 k) (inf-pow h))) d2
  (inf-le (inf-sum Cc0 15 1) 19) d3
  (inf-le prev0 15) b1
  (pi j nat (inf-le (Lz0 j) 15)) b2
  (pi k nat (inf-le (Cl0 k) 15)) a2
 )
 (defcx inf-stn-c1 inf-stn (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (opc1 nat) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (Clc1 (pi j nat nat)) (Lzc1 (pi j nat nat)) (Csc1 (pi j nat nat)) (Ctc1 (pi j nat nat)) (Ccc1 (pi j nat nat)) (lastc1 nat) (remc1 nat) (hclenc1 nat) (ic1 nat) (prevc1 nat) (stagec1 nat) (syc1 nat) (lenc1 nat) (distc1 nat) (modec1 nat) (hlitc1 nat) (hdistc1 nat) (outc1 nat) (occ1 nat) (capc1 nat) (ndc1 nat) (hlenc1 nat) (c1e1 (inf-le ipc1 nin)) (c1e3 (inf-le bcc1 63)) (c1e8 (inf-le opc1 capc1)) (c1eg (pi g (inf-lt 0 outc1) (paths nat occ1 capc1))) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) (c1d1 (pi k nat (inf-lt (Ccc1 k) (inf-pow h)))) (c1d2 (pi k nat (inf-lt (Csc1 k) (inf-pow h)))) (c1d3 (inf-le (inf-sum Ccc1 15 1) 19)) (c1b1 (inf-le prevc1 15)) (c1b2 (pi j nat (inf-le (Lzc1 j) 15))) (c1a2 (pi k nat (inf-le (Clc1 k) 15))) )
 (defvcs inf-vc-stn-c2 1 inf-stn-c1 ()
  (inf-le 19 lim) hl
  (inf-lt lim 31) hm
  (inf-le lh lim) hll
  (inf-le lw lh) hww
  (inf-le (succ lw) lh) hsw
  (inf-lt lh 31) hlh
  (inf-le (succ (succ (succ lh))) lim) hf
  (inf-le 12 lh) h12
  (inf-le 32 w) gw
  (inf-le bcc1 63) c1e3
  (inf-le h 16) gh
  (inf-le (inf-by16 q) (inf-pow h)) gq
  (inf-lt 320 q) gq2
  (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))) gk
  (inf-le LROOT 15) gl
  (inf-le DROOT 15) gd
  (inf-le CROOT 15) gc
  (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)) hord
  (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)) hle
  (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)) hlb
  (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))) hlc
  (pi k nat g (inf-lt k 30) (inf-le (De k) 13)) hde
  (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))) hdb
  (pi k nat (inf-lt (Lcc1 k) (inf-pow h))) c1c1
  (pi k nat (inf-lt (Lsc1 k) (inf-pow h))) c1c2
  (inf-le (inf-sum Lcc1 15 1) lmc1) c1c3
  (inf-le lmc1 288) c1c4
  (pi k nat (inf-lt (Dcc1 k) (inf-pow h))) c1c5
  (pi k nat (inf-lt (Dsc1 k) (inf-pow h))) c1c6
  (inf-le (inf-sum Dcc1 15 1) dmc1) c1c7
  (inf-le dmc1 32) c1c8
  (pi k nat (inf-lt (Ccc1 k) (inf-pow h))) c1d1
  (pi k nat (inf-lt (Csc1 k) (inf-pow h))) c1d2
  (inf-le (inf-sum Ccc1 15 1) 19) c1d3
  (inf-le prevc1 15) c1b1
  (pi j nat (inf-le (Lzc1 j) 15)) c1b2
  (pi k nat (inf-le (Clc1 k) 15)) c1a2
 )
 (defcx inf-stn-c2 inf-stn-c1 (ipc2 nat) (bcc2 nat) (bbc2 nat) (consc2 nat) (opc2 nat) (Lcc2 (pi j nat nat)) (Lsc2 (pi j nat nat)) (Ltc2 (pi j nat nat)) (Dcc2 (pi j nat nat)) (Dsc2 (pi j nat nat)) (Dtc2 (pi j nat nat)) (lmc2 nat) (dmc2 nat) (Clc2 (pi j nat nat)) (Lzc2 (pi j nat nat)) (Csc2 (pi j nat nat)) (Ctc2 (pi j nat nat)) (Ccc2 (pi j nat nat)) (lastc2 nat) (remc2 nat) (hclenc2 nat) (ic2 nat) (prevc2 nat) (stagec2 nat) (syc2 nat) (lenc2 nat) (distc2 nat) (modec2 nat) (hlitc2 nat) (hdistc2 nat) (outc2 nat) (occ2 nat) (capc2 nat) (ndc2 nat) (hlenc2 nat) (c2e1 (inf-le ipc2 nin2)) (c2e3 (inf-le bcc2 63)) (c2e8 (inf-le opc2 capc2)) (c2eg (pi g (inf-lt 0 outc2) (paths nat occ2 capc2))) (c2c1 (pi k nat (inf-lt (Lcc2 k) (inf-pow h)))) (c2c2 (pi k nat (inf-lt (Lsc2 k) (inf-pow h)))) (c2c3 (inf-le (inf-sum Lcc2 15 1) lmc2)) (c2c4 (inf-le lmc2 288)) (c2c5 (pi k nat (inf-lt (Dcc2 k) (inf-pow h)))) (c2c6 (pi k nat (inf-lt (Dsc2 k) (inf-pow h)))) (c2c7 (inf-le (inf-sum Dcc2 15 1) dmc2)) (c2c8 (inf-le dmc2 32)) (c2d1 (pi k nat (inf-lt (Ccc2 k) (inf-pow h)))) (c2d2 (pi k nat (inf-lt (Csc2 k) (inf-pow h)))) (c2d3 (inf-le (inf-sum Ccc2 15 1) 19)) (c2b1 (inf-le prevc2 15)) (c2b2 (pi j nat (inf-le (Lzc2 j) 15))) (c2a2 (pi k nat (inf-le (Clc2 k) 15))) )
 (defcx inf-lz (w nat) (l nat) (d nat) (op nat) (out nat) (oc nat) (cap nat) (nd nat) (gw (inf-le 32 w)) (gd (inf-lt d (inf-pow w))) (ga (inf-le d (add op nd))) (gb (inf-le (add op l) cap)) (gz (inf-lt 0 out)) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (O0 (pi j nat nat)) (Dd (pi j nat nat)) (gp (inf-lt 0 d)) )
 (defvcs inf-vc-lz-s1 1 inf-lz (g1 (inf-lt op d))
  (inf-lt l (inf-pow w)) ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))
 )
 (defvcs inf-vc-lz-j1 1 inf-lz (g1 (inf-lt op d))
  (inf-le op d) (inf-letrans op d d (inf-ltle op d g1) (inf-refl d))
 )
 (defvcs inf-vc-lz-s2 1 inf-lz (g1 (inf-lt op d) g2 (inf-lt (natminus d op) l))
  (inf-le op d) (inf-letrans op d d (inf-ltle op d g1) (inf-refl d))
  (inf-lt (natminus d op) (inf-pow w)) (inf-lelt (natminus d op) d (inf-pow w) (inf-suble d op) gd)
 )
 (defvcs inf-vc-lz-j1j 1 inf-lz (g1 (inf-lt op d) g2 (inf-lt (natminus d op) l))
  (paths nat (natminus d op) (inf-h d op l)) (inf-htt d op l g2)
 )
 (defvcs inf-vc-lz-j1j 2 inf-lz (g1 (inf-lt op d) g2 (inf-le l (natminus d op)))
  (paths nat l (inf-h d op l)) (inf-hff d op l g2)
 )
 (defcx inf-lz-c2 inf-lz (g1 (inf-lt op d)) (mj1 nat) (f1 (paths nat mj1 (inf-h d op l))) )
 (defvcs inf-vc-lz-m1 1 inf-lz-c2 ()
  (inf-le op d) (inf-letrans op d d (inf-ltle op d g1) (inf-refl d))
  (inf-le (natminus d op) nd) (inf-dnowrap d op nd ga)
  (inf-le (add op mj1) oc) (inf-letrans (add op mj1) (add op l) oc (inf-addl op mj1 l ((inf-letr (inf-h d op l) mj1 l ((pathsinv0 nat mj1 (inf-h d op l) f1)) (inf-hlel d op l)))) ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))
  (inf-le (add (natminus nd (natminus d op)) mj1) nd) (inf-letr (add (natminus nd (natminus d op)) (inf-h d op l)) (add (natminus nd (natminus d op)) mj1) nd (maponpaths nat nat (lam z (add (natminus nd (natminus d op)) z)) (inf-h d op l) mj1 ((pathsinv0 nat mj1 (inf-h d op l) f1))) (inf-dr d op l nd ga))
 )
 (defvcs inf-vc-lz-w1e 1 inf-lz-c2 ()
  (inf-le mj1 mj1) (inf-refl mj1)
  (inf-le mj1 l) ((inf-letr (inf-h d op l) mj1 l ((pathsinv0 nat mj1 (inf-h d op l) f1)) (inf-hlel d op l)))
  (pi ti nat ha (inf-lt ti mj1) (paths nat ((inf-blk O0 op Dd (natminus nd (natminus d op)) mj1) (add op ti)) (Dd (add (natminus nd (natminus d op)) ti)))) (lam ti ha (inf-lzdict O0 op Dd ((natminus nd (natminus d op))) mj1 ti ha))
  (pi ti nat ha (inf-lt ti mj1) hb (inf-le d (add op ti)) (paths nat ((inf-blk O0 op Dd (natminus nd (natminus d op)) mj1) (add op ti)) ((inf-blk O0 op Dd (natminus nd (natminus d op)) mj1) (natminus (add op ti) d)))) (lam ti ha hb (inf-ltnle (paths nat (inf-blk O0 op Dd ((natminus nd (natminus d op))) mj1 (add op ti)) (inf-blk O0 op Dd ((natminus nd (natminus d op))) mj1 (natminus (add op ti) d))) (add op ti) d (inf-lzpast d op mj1 ti ((inf-letr (inf-h d op l) mj1 (natminus d op) ((pathsinv0 nat mj1 (inf-h d op l) f1)) (inf-hle d op l))) g1 ha) hb))
  (pi xx nat ha (inf-lt xx op) (paths nat ((inf-blk O0 op Dd (natminus nd (natminus d op)) mj1) xx) (O0 xx))) (lam xx ha (inf-blklo O0 op Dd ((natminus nd (natminus d op))) mj1 xx ha))
  (pi xx nat ha (inf-le (add op mj1) xx) (paths nat ((inf-blk O0 op Dd (natminus nd (natminus d op)) mj1) xx) (O0 xx))) (lam xx ha (inf-blkhi O0 op Dd ((natminus nd (natminus d op))) mj1 xx ha))
 )
 (defcx inf-lz-c2-w1 inf-lz-c2 (k nat) (Ot (pi j nat nat)) (a1 (inf-le mj1 k)) (a0 (inf-le k l)) (ad (pi ti nat ha (inf-lt ti mj1) (paths nat (Ot (add op ti)) (Dd (add (natminus nd (natminus d op)) ti))))) (as (pi ti nat ha (inf-lt ti k) hb (inf-le d (add op ti)) (paths nat (Ot (add op ti)) (Ot (natminus (add op ti) d))))) (al (pi xx nat ha (inf-lt xx op) (paths nat (Ot xx) (O0 xx)))) (ah (pi xx nat ha (inf-le (add op k) xx) (paths nat (Ot xx) (O0 xx)))) )
 (defvcs inf-vc-lz-p1 1 inf-lz-c2-w1 (w1 (inf-lt k l))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op l) cap (inf-ltle (add op k) (add op l) (inf-ltaddl op k l w1)) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
  (inf-lt (add op k) oc) (inf-cw op k l oc w1 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))
  (inf-le d (add op k)) (inf-dknowrap d op l k (inf-ltle op d g1) (inf-letr mj1 (inf-h d op l) k f1 a1) w1)
  (inf-lt (natminus (add op k) d) oc) (inf-lelt (natminus (add op k) d) (add op k) oc (inf-suble (add op k) d) (inf-cw op k l oc w1 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))))
 )
 (defvcs inf-vc-lz-w1b 1 inf-lz-c2-w1 (w1 (inf-lt k l))
  (inf-lt (succ k) (inf-pow w)) (inf-lelt (succ k) l (inf-pow w) (inf-ltsu k l w1) ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))
  (inf-le mj1 (succ k)) (inf-letrans mj1 k (succ k) a1 (inf-ltle k (succ k) (inf-ltself k)))
  (inf-le (succ k) l) (inf-ltsu k l w1)
  (pi ti nat ha (inf-lt ti mj1) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 1) (add op ti)) (Dd (add (natminus nd (natminus d op)) ti)))) (lam ti ha (pathscomp0 nat (inf-blk Ot (add op k) Ot ((natminus (add op k) d)) 1 (add op ti)) (Ot (add op ti)) (Dd (add ((natminus nd (natminus d op))) ti)) (inf-blklo Ot (add op k) Ot ((natminus (add op k) d)) 1 (add op ti) (inf-ltaddl op ti k (inf-lttrans ti mj1 k ha a1))) (ad ti ha)))
  (pi ti nat ha (inf-lt ti (succ k)) hb (inf-le d (add op ti)) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 1) (add op ti)) ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 1) (natminus (add op ti) d)))) (lam ti ha hb (inf-lzself Ot op k d 1 ti ((inf-dknowrap d op l k (inf-ltle op d g1) (inf-letr mj1 (inf-h d op l) k f1 a1) w1)) ((inf-ltsu 0 d gp)) (inf-ltcong ti ti (succ k) (add k 1) (idpath ti) ((pathsinv0 nat (add k 1) (succ k) (inf-add1 k))) ha) hb as))
  (pi xx nat ha (inf-lt xx op) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 1) xx) (O0 xx))) (lam xx ha (inf-lzlo Ot O0 op k Ot ((natminus (add op k) d)) 1 xx ha (al xx ha)))
  (pi xx nat ha (inf-le (add op (succ k)) xx) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 1) xx) (O0 xx))) (lam xx ha (inf-lzhi Ot O0 op k Ot ((natminus (add op k) d)) 1 xx (inf-letr (add op (succ k)) (add op (add k 1)) xx (maponpaths nat nat (lam z (add op z)) (succ k) (add k 1) ((pathsinv0 nat (add k 1) (succ k) (inf-add1 k)))) ha) (lam z (ah xx z))))
  (inf-lt (natminus l (succ k)) (natminus l k)) (inf-subfall l k w1)
 )
 (defvcs inf-vc-lz-end 1 inf-lz-c2-w1 (w1 (inf-le l k))
  (pi ti nat ha (inf-lt ti l) hb (inf-le d (add op ti)) (paths nat (Ot (add op ti)) (Ot (natminus (add op ti) d)))) (lam ti ha hb (as ti (inf-lttrans ti l k ha w1) hb))
  (pi xx nat ha (inf-lt xx op) (paths nat (Ot xx) (O0 xx))) al
  (pi xx nat ha (inf-le (add op l) xx) (paths nat (Ot xx) (O0 xx))) (lam xx ha (ah xx (inf-letrans (add op k) (add op l) xx (inf-addl op k l a0) ha)))
  (pi ti nat ha (inf-lt ti l) hb (inf-lt (add op ti) d) (paths nat (Ot (add op ti)) (Dd (add (natminus nd (natminus d op)) ti)))) (lam ti ha hb (ad ti (inf-ltcong ti ti (inf-h d op l) mj1 (idpath ti) ((pathsinv0 nat mj1 (inf-h d op l) f1)) (inf-hgt d op l ti ha hb))))
 )
 (defvcs inf-vc-lz-w2e 1 inf-lz (g1 (inf-le d op) g3 (inf-le 8 d))
  (inf-le 0 l) (idpath false)
  (pi ti nat ha (inf-lt ti 0) hb (inf-le d (add op ti)) (paths nat (O0 (add op ti)) (O0 (natminus (add op ti) d)))) (lam ti ha hb (inf-ltnle (paths nat (O0 (add op ti)) (O0 (natminus (add op ti) d))) ti 0 ha (idpath false)))
  (pi xx nat ha (inf-lt xx op) (paths nat (O0 xx) (O0 xx))) (lam xx ha (idpath (O0 xx)))
  (pi xx nat ha (inf-le (add op 0) xx) (paths nat (O0 xx) (O0 xx))) (lam xx ha (idpath (O0 xx)))
 )
 (defcx inf-lz-w2 inf-lz (g1 (inf-le d op)) (g3 (inf-le 8 d)) (k nat) (Ot (pi j nat nat)) (a2 (inf-le k l)) (bs (pi ti nat ha (inf-lt ti k) hb (inf-le d (add op ti)) (paths nat (Ot (add op ti)) (Ot (natminus (add op ti) d))))) (bl (pi xx nat ha (inf-lt xx op) (paths nat (Ot xx) (O0 xx)))) (bh (pi xx nat ha (inf-le (add op k) xx) (paths nat (Ot xx) (O0 xx)))) )
 (defvcs inf-vc-lz-w2h 1 inf-lz-w2 ()
  (inf-lt (add k 8) (inf-pow w)) (inf-nfit k 8 cap w (inf-letrans k l cap a2 (inf-letrans l (add op l) cap (inf-leaddl l op) gb)) (idpath false) gcap)
 )
 (defvcs inf-vc-lz-p2 1 inf-lz-w2 (w2 (inf-le (add k 8) l))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) (add op l) (inf-pow w) (inf-addl op k l (inf-letrans k (add k 8) l (inf-leaddr k 8) w2)) (inf-lelt (add op l) cap (inf-pow w) gb ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))
  (inf-le (add (add op k) 8) oc) (inf-letrans (add (add op k) 8) (add op l) oc (inf-letr (add op (add k 8)) (add (add op k) 8) (add op l) (pathsinv0 nat (add (add op k) 8) (add op (add k 8)) (natplusassoc op k 8)) (inf-addl op (add k 8) l w2)) ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))
  (inf-le d (add op k)) ((inf-letrans d op (add op k) g1 (inf-leaddr op k)))
  (inf-le (add (natminus (add op k) d) 8) oc) (inf-letrans (add (natminus (add op k) d) 8) (add (add op k) 8) oc (inf-addr (natminus (add op k) d) (add op k) 8 (inf-suble (add op k) d)) (inf-letrans (add (add op k) 8) (add op l) oc (inf-letr (add op (add k 8)) (add (add op k) 8) (add op l) (pathsinv0 nat (add (add op k) 8) (add op (add k 8)) (natplusassoc op k 8)) (inf-addl op (add k 8) l w2)) ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))))
 )
 (defvcs inf-vc-lz-s3 1 inf-lz-w2 (w2 (inf-le (add k 8) l))
  (inf-lt (add k 8) (inf-pow w)) (inf-nfit k 8 cap w (inf-letrans k l cap a2 (inf-letrans l (add op l) cap (inf-leaddl l op) gb)) (idpath false) gcap)
 )
 (defvcs inf-vc-lz-w2b 1 inf-lz-w2 (w2 (inf-le (add k 8) l))
  (inf-le (add k 8) l) w2
  (pi ti nat ha (inf-lt ti (add k 8)) hb (inf-le d (add op ti)) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 8) (add op ti)) ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 8) (natminus (add op ti) d)))) (lam ti ha hb (inf-lzself Ot op k d 8 ti ((inf-letrans d op (add op k) g1 (inf-leaddr op k))) g3 ha hb bs))
  (pi xx nat ha (inf-lt xx op) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 8) xx) (O0 xx))) (lam xx ha (inf-lzlo Ot O0 op k Ot ((natminus (add op k) d)) 8 xx ha (bl xx ha)))
  (pi xx nat ha (inf-le (add op (add k 8)) xx) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 8) xx) (O0 xx))) (lam xx ha (inf-lzhi Ot O0 op k Ot ((natminus (add op k) d)) 8 xx ha (lam z (bh xx z))))
  (inf-lt (natminus l (add k 8)) (natminus l k)) (inf-subby k l 8 (inf-lttrans k (add k 8) l (inf-ltaddpos k 8 (idpath true)) w2) (idpath true))
 )
 (defvcs inf-vc-lz-j2j 1 inf-lz-w2 (w2 (inf-lt l (add k 8)))
  (inf-le k l) a2
  (pi ti nat ha (inf-lt ti k) hb (inf-le d (add op ti)) (paths nat (Ot (add op ti)) (Ot (natminus (add op ti) d)))) bs
  (pi xx nat ha (inf-lt xx op) (paths nat (Ot xx) (O0 xx))) bl
  (pi xx nat ha (inf-le (add op k) xx) (paths nat (Ot xx) (O0 xx))) bh
 )
 (defvcs inf-vc-lz-j2j 5 inf-lz (g1 (inf-le d op) g3 unit)
  (inf-le 0 l) (idpath false)
  (pi ti nat ha (inf-lt ti 0) hb (inf-le d (add op ti)) (paths nat (O0 (add op ti)) (O0 (natminus (add op ti) d)))) (lam ti ha hb (inf-ltnle (paths nat (O0 (add op ti)) (O0 (natminus (add op ti) d))) ti 0 ha (idpath false)))
  (pi xx nat ha (inf-lt xx op) (paths nat (O0 xx) (O0 xx))) (lam xx ha (idpath (O0 xx)))
  (pi xx nat ha (inf-le (add op 0) xx) (paths nat (O0 xx) (O0 xx))) (lam xx ha (idpath (O0 xx)))
 )
 (defcx inf-lz-c1 inf-lz (g1 (inf-le d op)) (Otj2 (pi j nat nat)) (kj2 nat) (f3 (inf-le kj2 l)) (fs (pi ti nat ha (inf-lt ti kj2) hb (inf-le d (add op ti)) (paths nat (Otj2 (add op ti)) (Otj2 (natminus (add op ti) d))))) (fl (pi xx nat ha (inf-lt xx op) (paths nat (Otj2 xx) (O0 xx)))) (fh (pi xx nat ha (inf-le (add op kj2) xx) (paths nat (Otj2 xx) (O0 xx)))) )
 (defvcs inf-vc-lz-w3e 1 inf-lz-c1 ()
  (inf-le kj2 l) f3
  (pi ti nat ha (inf-lt ti kj2) hb (inf-le d (add op ti)) (paths nat (Otj2 (add op ti)) (Otj2 (natminus (add op ti) d)))) fs
  (pi xx nat ha (inf-lt xx op) (paths nat (Otj2 xx) (O0 xx))) fl
  (pi xx nat ha (inf-le (add op kj2) xx) (paths nat (Otj2 xx) (O0 xx))) fh
 )
 (defcx inf-lz-c1-w3 inf-lz-c1 (Ot (pi j nat nat)) (k nat) (a3 (inf-le k l)) (cs (pi ti nat ha (inf-lt ti k) hb (inf-le d (add op ti)) (paths nat (Ot (add op ti)) (Ot (natminus (add op ti) d))))) (cl (pi xx nat ha (inf-lt xx op) (paths nat (Ot xx) (O0 xx)))) (ch (pi xx nat ha (inf-le (add op k) xx) (paths nat (Ot xx) (O0 xx)))) )
 (defvcs inf-vc-lz-p3 1 inf-lz-c1-w3 (w3 (inf-lt k l))
  (inf-lt (add op k) (inf-pow w)) (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op l) cap (inf-ltle (add op k) (add op l) (inf-ltaddl op k l w3)) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))
  (inf-lt (add op k) oc) (inf-cw op k l oc w3 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))
  (inf-le d (add op k)) ((inf-letrans d op (add op k) g1 (inf-leaddr op k)))
  (inf-lt (natminus (add op k) d) oc) (inf-lelt (natminus (add op k) d) (add op k) oc (inf-suble (add op k) d) (inf-cw op k l oc w3 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))))
 )
 (defvcs inf-vc-lz-s4 1 inf-lz-c1-w3 (w3 (inf-lt k l))
  (inf-lt (add k 1) (inf-pow w)) (inf-lelt (add k 1) l (inf-pow w) (inf-lt1 k l w3) ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))
 )
 (defvcs inf-vc-lz-w3b 1 inf-lz-c1-w3 (w3 (inf-lt k l))
  (inf-le (add k 1) l) (inf-lt1 k l w3)
  (pi ti nat ha (inf-lt ti (add k 1)) hb (inf-le d (add op ti)) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 1) (add op ti)) ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 1) (natminus (add op ti) d)))) (lam ti ha hb (inf-lzself Ot op k d 1 ti ((inf-letrans d op (add op k) g1 (inf-leaddr op k))) ((inf-ltsu 0 d gp)) ha hb cs))
  (pi xx nat ha (inf-lt xx op) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 1) xx) (O0 xx))) (lam xx ha (inf-lzlo Ot O0 op k Ot ((natminus (add op k) d)) 1 xx ha (cl xx ha)))
  (pi xx nat ha (inf-le (add op (add k 1)) xx) (paths nat ((inf-blk Ot (add op k) Ot (natminus (add op k) d) 1) xx) (O0 xx))) (lam xx ha (inf-lzhi Ot O0 op k Ot ((natminus (add op k) d)) 1 xx ha (lam z (ch xx z))))
  (inf-lt (natminus l (add k 1)) (natminus l k)) (inf-subfall1 l k w3)
 )
 (defvcs inf-vc-lz-end 5 inf-lz-c1-w3 (w3 (inf-le l k))
  (pi ti nat ha (inf-lt ti l) hb (inf-le d (add op ti)) (paths nat (Ot (add op ti)) (Ot (natminus (add op ti) d)))) (lam ti ha hb (cs ti (inf-lttrans ti l k ha w3) hb))
  (pi xx nat ha (inf-lt xx op) (paths nat (Ot xx) (O0 xx))) cl
  (pi xx nat ha (inf-le (add op l) xx) (paths nat (Ot xx) (O0 xx))) (lam xx ha (ch xx (inf-letrans (add op k) (add op l) xx (inf-addl op k l a3) ha)))
  (pi ti nat ha (inf-lt ti l) hb (inf-lt (add op ti) d) (paths nat (Ot (add op ti)) (Dd (add (natminus nd (natminus d op)) ti)))) (lam ti ha hb (inf-ltnle (paths nat (Ot (add op ti)) (Dd (add ((natminus nd (natminus d op))) ti))) (add op ti) d hb (inf-letrans d op (add op ti) g1 (inf-leaddr op ti))))
 )
 (defcx inf-fillv (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 (pi j nat nat)) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv 0 ip0 cons0 bc0)) (gx (pi j nat h (inf-lt j bc0) (paths nat (bb0 j) (inf-ib In (add cons0 j))))) (gy (pi j nat (inf-le (bb0 j) (inf-ib In (add cons0 j))))) )
 (defvcs inf-vc-fillv-i1 1 inf-fillv ()
  (inf-lt (add ip0 8) (inf-pow w)) (inf-lelt (add ip0 8) (add n 8) (inf-pow w) (inf-addr ip0 n 8 gi) gn)
 )
 (defvcs inf-vc-fillv-a1 1 inf-fillv (g1 (inf-le (add ip0 8) n))
  (inf-le (add ip0 8) n) g1
  (inf-lt bc0 64) (inf-lelts bc0 63 (gs))
 )
 (defvcs inf-vc-fillv-a2 1 inf-fillv (g1 (inf-le (add ip0 8) n))
  (inf-le (inf-div8 bc0) 7) (inf-div8le bc0 (gs))
  (inf-lt (add ip0 (natminus 7 (inf-div8 bc0))) (inf-pow w)) (inf-lelt ((add ip0 ((natminus 7 (inf-div8 bc0))))) n (inf-pow w) (inf-letrans ((add ip0 ((natminus 7 (inf-div8 bc0))))) (add ip0 8) n ((inf-addl ip0 ((natminus 7 (inf-div8 bc0))) 8 (inf-letrans ((natminus 7 (inf-div8 bc0))) 7 8 (inf-suble 7 (inf-div8 bc0)) (idpath false)))) g1) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))
 )
 (defvcs inf-vc-fillv-a3 1 inf-fillv (g1 (inf-le (add ip0 8) n))
  (inf-le bc0 63) gs
  (inf-lt (add 56 (inf-mod 8 bc0)) (inf-pow w)) (inf-wlit (add 56 (inf-mod 8 bc0)) w gw (inf-or56 bc0))
 )
 (defvcs inf-vc-fillv-end 1 inf-fillv (g1 (inf-le (add ip0 8) n))
  (inf-le (add ip0 (natminus 7 (inf-div8 bc0))) n) (inf-letrans ((add ip0 ((natminus 7 (inf-div8 bc0))))) (add ip0 8) n ((inf-addl ip0 ((natminus 7 (inf-div8 bc0))) 8 (inf-letrans ((natminus 7 (inf-div8 bc0))) 7 8 (inf-suble 7 (inf-div8 bc0)) (idpath false)))) g1)
  (inf-le (add 56 (inf-mod 8 bc0)) 63) (inf-or56 bc0)
  (inf-bits-inv 0 (add ip0 (natminus 7 (inf-div8 bc0))) cons0 (add 56 (inf-mod 8 bc0))) (inf-fillw 0 ip0 cons0 bc0 (gs) ga)
  (inf-le cons0 cons0) (inf-refl cons0)
  (pi j nat h (inf-lt j (add 56 (inf-mod 8 bc0))) (paths nat ((inf-bor bb0 (inf-bshl (inf-bld In ip0) bc0)) j) (inf-ib In (add cons0 j)))) (inf-fillx In bb0 (inf-bld In ip0) 64 cons0 bc0 (inf-by8 ip0) ga gx gy (inf-bldg In ip0) (add 56 (inf-mod 8 bc0)) (inf-letrans (add 56 (inf-mod 8 bc0)) 63 (add 64 bc0) (inf-or56 bc0) (inf-letrans 63 64 (add 64 bc0) (idpath false) (inf-leaddr 64 bc0))) (inf-letrans (add 56 (inf-mod 8 bc0)) 63 64 (inf-or56 bc0) (idpath false)))
  (pi j nat (inf-le ((inf-bor bb0 (inf-bshl (inf-bld In ip0) bc0)) j) (inf-ib In (add cons0 j)))) (inf-filly In bb0 (inf-bld In ip0) 64 cons0 bc0 (inf-by8 ip0) ga gy (inf-bldg In ip0) (inf-bldz In ip0))
  (paths nat cons0 cons0) (idpath cons0)
  (pi ha (inf-lt (add 56 (inf-mod 8 bc0)) 56) (paths nat (add ip0 (natminus 7 (inf-div8 bc0))) n)) (lam ha (inf-ltnle (paths nat ((add ip0 ((natminus 7 (inf-div8 bc0))))) n) (add 56 (inf-mod 8 bc0)) 56 ha (inf-leaddr 56 (inf-mod 8 bc0))))
 )
 (defvcs inf-vc-fillv-w1e 1 inf-fillv (g1 (inf-lt n (add ip0 8)))
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv 0 ip0 cons0 bc0) ga
  (pi j nat h (inf-lt j bc0) (paths nat (bb0 j) (inf-ib In (add cons0 j)))) gx
  (pi j nat (inf-le (bb0 j) (inf-ib In (add cons0 j)))) gy
 )
 (defcx inf-fillv-w1 inf-fillv (g1 (inf-lt n (add ip0 8))) (ip nat) (bc nat) (bb (pi j nat nat)) (j1 (inf-le ip n)) (j3 (inf-le bc 63)) (j4 (inf-bits-inv 0 ip cons0 bc)) (j5 (pi j nat h (inf-lt j bc) (paths nat (bb j) (inf-ib In (add cons0 j))))) (j6 (pi j nat (inf-le (bb j) (inf-ib In (add cons0 j))))) )
 (defvcs inf-vc-fillv-end 9 inf-fillv-w1 (w1 (inf-lt ip n) g2 (inf-lt 55 bc))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv 0 ip cons0 bc) j4
  (inf-le cons0 cons0) (inf-refl cons0)
  (pi j nat h (inf-lt j bc) (paths nat (bb j) (inf-ib In (add cons0 j)))) j5
  (pi j nat (inf-le (bb j) (inf-ib In (add cons0 j)))) j6
  (paths nat cons0 cons0) (idpath cons0)
  (pi ha (inf-lt bc 56) (paths nat ip n)) (lam ha (inf-ltnle (paths nat ip n) bc 56 ha (inf-ltsu 55 bc g2)))
 )
 (defvcs inf-vc-fillv-b2 1 inf-fillv-w1 (w1 (inf-lt ip n) g2 (inf-le bc 55))
  (inf-lt ip n) w1
  (inf-lt bc 64) (inf-lelt bc 55 64 g2 (idpath true))
 )
 (defvcs inf-vc-fillv-b3 1 inf-fillv-w1 (w1 (inf-lt ip n) g2 (inf-le bc 55))
  (inf-lt (add ip 1) (inf-pow w)) (inf-lelt ((add ip 1)) n (inf-pow w) (inf-lt1 ip n w1) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))
 )
 (defvcs inf-vc-fillv-b4 1 inf-fillv-w1 (w1 (inf-lt ip n) g2 (inf-le bc 55))
  (inf-lt (add bc 8) (inf-pow w)) (inf-wlit (add bc 8) w gw ((inf-addr bc 55 8 g2)))
 )
 (defvcs inf-vc-fillv-w1b 1 inf-fillv-w1 (w1 (inf-lt ip n) g2 (inf-le bc 55))
  (inf-le (add ip 1) n) (inf-lt1 ip n w1)
  (inf-le (add bc 8) 63) ((inf-addr bc 55 8 g2))
  (inf-bits-inv 0 (add ip 1) cons0 (add bc 8)) (inf-fill1b 0 ip cons0 bc j4)
  (pi j nat h (inf-lt j (add bc 8)) (paths nat ((inf-bor bb (inf-bshl (inf-bbyte (In ip)) bc)) j) (inf-ib In (add cons0 j)))) (inf-fillx In bb (inf-bbyte (In ip)) 8 cons0 bc (inf-by8 ip) j4 j5 j6 (inf-bytg In ip) (add bc 8) (inf-eqle (add bc 8) (add 8 bc) (natpluscomm bc 8)) (inf-letrans (add bc 8) 63 64 ((inf-addr bc 55 8 g2)) (idpath false)))
  (pi j nat (inf-le ((inf-bor bb (inf-bshl (inf-bbyte (In ip)) bc)) j) (inf-ib In (add cons0 j)))) (inf-filly In bb (inf-bbyte (In ip)) 8 cons0 bc (inf-by8 ip) j4 j6 (inf-bytg In ip) (lam r h (inf-bytz (In ip) r h)))
  (inf-lt (natminus n (add ip 1)) (natminus n ip)) (inf-subfall1 n ip w1)
 )
 (defvcs inf-vc-fillv-end 17 inf-fillv-w1 (w1 (inf-le n ip))
  (inf-le ip n) j1
  (inf-le bc 63) j3
  (inf-bits-inv 0 ip cons0 bc) j4
  (inf-le cons0 cons0) (inf-refl cons0)
  (pi j nat h (inf-lt j bc) (paths nat (bb j) (inf-ib In (add cons0 j)))) j5
  (pi j nat (inf-le (bb j) (inf-ib In (add cons0 j)))) j6
  (paths nat cons0 cons0) (idpath cons0)
  (pi ha (inf-lt bc 56) (paths nat ip n)) (lam ha (inf-ant ip n j1 w1))
 )
 (defcx inf-takev (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 (pi j nat nat)) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv 0 ip0 cons0 bc0)) (gx (pi j nat h (inf-lt j bc0) (paths nat (bb0 j) (inf-ib In (add cons0 j))))) (gy (pi j nat (inf-le (bb0 j) (inf-ib In (add cons0 j))))) (k nat) (gk (inf-le k 13)) )
 (defvcs inf-vc-takev-c1 1 inf-takev ()
  (inf-le 32 w) gw
  (inf-lt (add n 8) (inf-pow w)) gn
  (inf-le ip0 n) gi
  (inf-le bc0 63) gs
  (inf-bits-inv 0 ip0 cons0 bc0) ga
  (pi j nat h (inf-lt j bc0) (paths nat (bb0 j) (inf-ib In (add cons0 j)))) gx
  (pi j nat (inf-le (bb0 j) (inf-ib In (add cons0 j)))) gy
 )
 (defcx inf-takev-c1 inf-takev (ipc1 nat) (bcc1 nat) (bbc1 (pi j nat nat)) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv 0 ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) (c1ex (pi j nat h (inf-lt j bcc1) (paths nat (bbc1 j) (inf-ib In (add consc1 j))))) (c1ey (pi j nat (inf-le (bbc1 j) (inf-ib In (add consc1 j))))) (c1ec (paths nat consc1 cons0)) (c1ef (pi ha (inf-lt bcc1 56) (paths nat ipc1 n))) )
 (defvcs inf-vc-takev-r1 1 inf-takev-c1 (g1 (inf-lt bcc1 k))
  (inf-le ipc1 n) c1e1
  (inf-le bcc1 63) c1e3
  (inf-bits-inv 0 ipc1 consc1 bcc1) c1e4
  (inf-le cons0 consc1) c1e5
  (inf-lt (inf-by8 n) (add cons0 k)) (inf-short ipc1 n consc1 cons0 bcc1 k c1e4 (c1ef (inf-lttrans bcc1 k 56 g1 (inf-letrans k 13 56 gk (idpath false)))) c1ec g1)
 )
 (defvcs inf-vc-takev-d1 1 inf-takev-c1 (g1 (inf-le k bcc1))
  (inf-lt k 32) ((inf-lttrans k 16 32 (inf-lelts k 15 (inf-letrans k 13 15 gk (idpath false))) (idpath false)))
  (inf-lt (inf-val bbc1 k) (inf-pow w)) (inf-powfit (inf-val bbc1 k) k w (inf-vallt bbc1 k) (inf-letrans k 13 w gk (inf-letrans 13 32 w (idpath false) gw)))
 )
 (defvcs inf-vc-takev-d2 1 inf-takev-c1 (g1 (inf-le k bcc1))
  (inf-lt k 64) (inf-lttrans k 16 64 (inf-lelts k 15 (inf-letrans k 13 15 gk (idpath false))) (idpath false))
 )
 (defvcs inf-vc-takev-d3 1 inf-takev-c1 (g1 (inf-le k bcc1))
  (inf-le k bcc1) g1
  (inf-lt (natminus bcc1 k) (inf-pow w)) (inf-wlit ((natminus bcc1 k)) w gw (inf-letrans ((natminus bcc1 k)) bcc1 63 (inf-suble bcc1 k) c1e3))
 )
 (defvcs inf-vc-takev-r2 1 inf-takev-c1 (g1 (inf-le k bcc1))
  (inf-le ipc1 n) c1e1
  (inf-le (natminus bcc1 k) 63) (inf-sub63 bcc1 k c1e3)
  (inf-bits-inv 0 ipc1 (add consc1 k) (natminus bcc1 k)) (inf-take 0 ipc1 consc1 bcc1 k g1 c1e4)
  (inf-le cons0 (add consc1 k)) (inf-letrans cons0 consc1 ((add consc1 k)) c1e5 (inf-leaddr consc1 k))
  (inf-le (add cons0 k) (add consc1 k)) (inf-addr cons0 consc1 k c1e5)
  (inf-lt (inf-val bbc1 k) (inf-pow k)) (inf-vallt bbc1 k)
  (pi j nat h (inf-lt j (natminus bcc1 k)) (paths nat ((inf-bshr bbc1 k) j) (inf-ib In (add (add consc1 k) j)))) (inf-shrx In bbc1 consc1 bcc1 k g1 c1ex)
  (pi j nat (inf-le ((inf-bshr bbc1 k) j) (inf-ib In (add (add consc1 k) j)))) (inf-shry In bbc1 consc1 k c1ey)
  (paths nat (inf-val bbc1 k) (inf-get In cons0 k)) (inf-takev In bbc1 consc1 cons0 bcc1 k c1ec g1 c1ex)
  (paths nat (add consc1 k) (add cons0 k)) (maponpaths nat nat (lam z (add z k)) consc1 cons0 c1ec)
 )
 )
