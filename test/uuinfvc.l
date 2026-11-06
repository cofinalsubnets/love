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
(test
 (defn inf-tlb (pi k nat nat) (lam k (add (inf-tv 0 3 k) (add (inf-tv 1 4 k) (add (inf-tv 2 5 k) (add (inf-tv 3 6 k) (add (inf-tv 4 7 k) (add (inf-tv 5 8 k) (add (inf-tv 6 9 k) (add (inf-tv 7 10 k) (add (inf-tv 8 11 k) (add (inf-tv 9 13 k) (add (inf-tv 10 15 k) (add (inf-tv 11 17 k) (add (inf-tv 12 19 k) (add (inf-tv 13 23 k) (add (inf-tv 14 27 k) (add (inf-tv 15 31 k) (add (inf-tv 16 35 k) (add (inf-tv 17 43 k) (add (inf-tv 18 51 k) (add (inf-tv 19 59 k) (add (inf-tv 20 67 k) (add (inf-tv 21 83 k) (add (inf-tv 22 99 k) (add (inf-tv 23 115 k) (add (inf-tv 24 131 k) (add (inf-tv 25 163 k) (add (inf-tv 26 195 k) (add (inf-tv 27 227 k) (inf-tv 28 258 k)))))))))))))))))))))))))))))))
 (defn inf-tle (pi k nat nat) (lam k (add (inf-tv 0 0 k) (add (inf-tv 1 0 k) (add (inf-tv 2 0 k) (add (inf-tv 3 0 k) (add (inf-tv 4 0 k) (add (inf-tv 5 0 k) (add (inf-tv 6 0 k) (add (inf-tv 7 0 k) (add (inf-tv 8 1 k) (add (inf-tv 9 1 k) (add (inf-tv 10 1 k) (add (inf-tv 11 1 k) (add (inf-tv 12 2 k) (add (inf-tv 13 2 k) (add (inf-tv 14 2 k) (add (inf-tv 15 2 k) (add (inf-tv 16 3 k) (add (inf-tv 17 3 k) (add (inf-tv 18 3 k) (add (inf-tv 19 3 k) (add (inf-tv 20 4 k) (add (inf-tv 21 4 k) (add (inf-tv 22 4 k) (add (inf-tv 23 4 k) (add (inf-tv 24 5 k) (add (inf-tv 25 5 k) (add (inf-tv 26 5 k) (add (inf-tv 27 5 k) (inf-tv 28 0 k)))))))))))))))))))))))))))))))
 (defn inf-tdb (pi k nat nat) (lam k (add (inf-tv 0 1 k) (add (inf-tv 1 2 k) (add (inf-tv 2 3 k) (add (inf-tv 3 4 k) (add (inf-tv 4 5 k) (add (inf-tv 5 7 k) (add (inf-tv 6 9 k) (add (inf-tv 7 13 k) (add (inf-tv 8 17 k) (add (inf-tv 9 25 k) (add (inf-tv 10 33 k) (add (inf-tv 11 49 k) (add (inf-tv 12 65 k) (add (inf-tv 13 97 k) (add (inf-tv 14 129 k) (add (inf-tv 15 193 k) (add (inf-tv 16 257 k) (add (inf-tv 17 385 k) (add (inf-tv 18 513 k) (add (inf-tv 19 769 k) (add (inf-tv 20 1025 k) (add (inf-tv 21 1537 k) (add (inf-tv 22 2049 k) (add (inf-tv 23 3073 k) (add (inf-tv 24 4097 k) (add (inf-tv 25 6145 k) (add (inf-tv 26 8193 k) (add (inf-tv 27 12289 k) (add (inf-tv 28 16385 k) (inf-tv 29 24577 k))))))))))))))))))))))))))))))))
 (defn inf-tde (pi k nat nat) (lam k (add (inf-tv 0 0 k) (add (inf-tv 1 0 k) (add (inf-tv 2 0 k) (add (inf-tv 3 0 k) (add (inf-tv 4 1 k) (add (inf-tv 5 1 k) (add (inf-tv 6 2 k) (add (inf-tv 7 2 k) (add (inf-tv 8 3 k) (add (inf-tv 9 3 k) (add (inf-tv 10 4 k) (add (inf-tv 11 4 k) (add (inf-tv 12 5 k) (add (inf-tv 13 5 k) (add (inf-tv 14 6 k) (add (inf-tv 15 6 k) (add (inf-tv 16 7 k) (add (inf-tv 17 7 k) (add (inf-tv 18 8 k) (add (inf-tv 19 8 k) (add (inf-tv 20 9 k) (add (inf-tv 21 9 k) (add (inf-tv 22 10 k) (add (inf-tv 23 10 k) (add (inf-tv 24 11 k) (add (inf-tv 25 11 k) (add (inf-tv 26 12 k) (add (inf-tv 27 12 k) (add (inf-tv 28 13 k) (inf-tv 29 13 k))))))))))))))))))))))))))))))))
 (defn inf-tob (pi k nat nat) (lam k (add (inf-tv 0 16 k) (add (inf-tv 1 17 k) (add (inf-tv 2 18 k) (add (inf-tv 3 0 k) (add (inf-tv 4 8 k) (add (inf-tv 5 7 k) (add (inf-tv 6 9 k) (add (inf-tv 7 6 k) (add (inf-tv 8 10 k) (add (inf-tv 9 5 k) (add (inf-tv 10 11 k) (add (inf-tv 11 4 k) (add (inf-tv 12 12 k) (add (inf-tv 13 3 k) (add (inf-tv 14 13 k) (add (inf-tv 15 2 k) (add (inf-tv 16 14 k) (add (inf-tv 17 1 k) (inf-tv 18 15 k)))))))))))))))))))))
 (defcx inf-walk (Cn (pi i nat nat)) (Sy (pi i nat nat)) (bit (pi i nat nat)) (n nat) (h nat) (w nat) (b1 (pi i nat (inf-le (bit i) 1))) (hc (pi i nat (inf-lt (Cn i) (inf-pow h)))) (hs (pi i nat (inf-lt (Sy i) (inf-pow h)))) (gh (inf-le h 16)) (gw (inf-le 31 w)) (gn (inf-lt n (inf-pow w))) (gs (inf-le (inf-sum Cn 15 1) n)) )
; w1e-1
 (defvc inf-vc-walk-w1e-1 (under inf-walk (inf-le 1 1))
   (given inf-walk (idpath false)))
; w1e-2
 (defvc inf-vc-walk-w1e-2 (under inf-walk (inf-le 0 0))
   (given inf-walk (idpath false)))
; w1e-3
 (defvc inf-vc-walk-w1e-3 (under inf-walk (inf-le (add 0 2) (inf-pow 1)))
   (given inf-walk (idpath false)))
; w1e-4
 (defvc inf-vc-walk-w1e-4 (under inf-walk (paths nat (inf-mod 2 0) 0))
   (given inf-walk (idpath 0)))
; w1e-5
 (defvc inf-vc-walk-w1e-5 (under inf-walk (inf-le (add 0 (inf-sum Cn (natminus 16 1) 1)) n))
   (given inf-walk gs))
 (defcx inf-walk-w1 inf-walk (l nat) (index nat) (first nat) (code nat) (i1 (inf-le 1 l)) (i2 (inf-le first code)) (i3 (inf-le (add code 2) (inf-pow l))) (i4 (paths nat (inf-mod 2 code) 0)) (i5 (inf-le (add index (inf-sum Cn (natminus 16 l) l)) n)) )
; s1-1
 (defvc inf-vc-walk-s1-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-le 1 l)))
   (given inf-walk-w1 (lam w1 i1)))
; s1-2
 (defvc inf-vc-walk-s1-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (natminus l 1) 64)))
   (given inf-walk-w1 (lam w1 (inf-lelt (natminus l 1) l 64 (inf-suble l 1) (inf-lttrans l 16 64 w1 (idpath false))))))
; s1-3
 (defvc inf-vc-walk-s1-3 (under inf-walk-w1 (pi w1 (inf-lt l 16) (paths nat (inf-mod 2 code) 0)))
   (given inf-walk-w1 (lam w1 i4)))
; s1-4
 (defvc inf-vc-walk-s1-4 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (bit (natminus l 1)) 2)))
   (given inf-walk-w1 (lam w1 (inf-lelts ((bit (natminus l 1))) 1 (b1 (natminus l 1))))))
; s1-5
 (defvc inf-vc-walk-s1-5 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (add code (bit (natminus l 1))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 ((inf-powfit ((add code ((bit (natminus l 1))))) l w ((inf-wor code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)) ((inf-lew l w w1 gw)))))))
; s2-1
 (defvc inf-vc-walk-s2-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt l 16)))
   (given inf-walk-w1 (lam w1 w1)))
; s2-2
 (defvc inf-vc-walk-s2-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (Cn l) (inf-pow w))))
   (given inf-walk-w1 (lam w1 ((inf-powfit (Cn l) h w (hc l) ((istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw))))))))
; s3-1
 (defvc inf-vc-walk-s3-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (add code (bit (natminus l 1))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 ((inf-powfit ((add code ((bit (natminus l 1))))) l w ((inf-wor code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)) ((inf-lew l w w1 gw)))))))
; s3-2
 (defvc inf-vc-walk-s3-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) (inf-lt (Cn l) (inf-pow w))))
   (given inf-walk-w1 (lam w1 ((inf-powfit (Cn l) h w (hc l) ((istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw))))))))
; s4-1
 (defvc inf-vc-walk-s4-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-le first (add code (bit (natminus l 1))))))
   (given inf-walk-w1 (lam w1 g3 ((istransnatleh first code ((add code ((bit (natminus l 1))))) i2 (inf-leaddr code ((bit (natminus l 1)))))))))
; s4-2
 (defvc inf-vc-walk-s4-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (add index (natminus (add code (bit (natminus l 1))) first)) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lttrans ((add index (natminus ((add code ((bit (natminus l 1))))) first))) n (inf-pow w) ((inf-lttrans ((add index (natminus ((add code ((bit (natminus l 1))))) first))) (add index (Cn l)) n (inf-ltaddl index (natminus ((add code ((bit (natminus l 1))))) first) (Cn l) (inf-subshort first ((add code ((bit (natminus l 1))))) (Cn l) ((istransnatleh first code ((add code ((bit (natminus l 1))))) i2 (inf-leaddr code ((bit (natminus l 1)))))) g3)) ((inf-sumhead Cn 16 l index n w1 i5)))) (inf-ltle n (inf-pow w) gn)))))
; s4-3
 (defvc inf-vc-walk-s4-3 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (add index (natminus (add code (bit (natminus l 1))) first)) n)))
   (given inf-walk-w1 (lam w1 g3 ((inf-lttrans ((add index (natminus ((add code ((bit (natminus l 1))))) first))) (add index (Cn l)) n (inf-ltaddl index (natminus ((add code ((bit (natminus l 1))))) first) (Cn l) (inf-subshort first ((add code ((bit (natminus l 1))))) (Cn l) ((istransnatleh first code ((add code ((bit (natminus l 1))))) i2 (inf-leaddr code ((bit (natminus l 1)))))) g3)) ((inf-sumhead Cn 16 l index n w1 i5)))))))
; s4-4
 (defvc inf-vc-walk-s4-4 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (Sy (add index (natminus (add code (bit (natminus l 1))) first))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-powfit ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))) h w (hs ((add index (natminus ((add code ((bit (natminus l 1))))) first)))) ((istransnatleh h 16 w gh (istransnatleh 16 31 w (idpath false) gw)))))))
; s4-5
 (defvc inf-vc-walk-s4-5 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (inf-by16 (Sy (add index (natminus (add code (bit (natminus l 1))) first)))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt (inf-by16 ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))) (add (inf-by16 ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))) l) (inf-pow w) (inf-leaddr (inf-by16 ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))) l) ((inf-by16or ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))) l h w (hs ((add index (natminus ((add code ((bit (natminus l 1))))) first)))) w1 gh gw))))))
; s4-6
 (defvc inf-vc-walk-s4-6 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt l (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lttrans l 16 (inf-pow w) w1 (inf-powle 4 w (istransnatleh 4 31 w (idpath false) gw))))))
; s4-7
 (defvc inf-vc-walk-s4-7 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (paths nat (inf-mod 16 (inf-by16 (Sy (add index (natminus (add code (bit (natminus l 1))) first))))) 0)))
   (given inf-walk-w1 (lam w1 g3 (inf-by16low ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first)))))))))
; s4-8
 (defvc inf-vc-walk-s4-8 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt l 16)))
   (given inf-walk-w1 (lam w1 g3 w1)))
; s4-9
 (defvc inf-vc-walk-s4-9 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-lt (add code (bit (natminus l 1))) (add first (Cn l))) (inf-lt (add (inf-by16 (Sy (add index (natminus (add code (bit (natminus l 1))) first)))) l) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 ((inf-by16or ((Sy ((add index (natminus ((add code ((bit (natminus l 1))))) first))))) l h w (hs ((add index (natminus ((add code ((bit (natminus l 1))))) first)))) w1 gh gw)))))
; s5-1
 (defvc inf-vc-walk-s5-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (add index (Cn l)) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt (add index (Cn l)) n (inf-pow w) ((inf-sumhead Cn 16 l index n w1 i5)) gn))))
; s6-1
 (defvc inf-vc-walk-s6-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (add first (Cn l)) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt ((add first (Cn l))) ((add code ((bit (natminus l 1))))) (inf-pow w) g3 ((inf-powfit ((add code ((bit (natminus l 1))))) l w ((inf-wor code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)) ((inf-lew l w w1 gw))))))))
; s6-2
 (defvc inf-vc-walk-s6-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (add (add first (Cn l)) (add first (Cn l))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt (add ((add first (Cn l))) ((add first (Cn l)))) ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (inf-pow w) (inf-dbl ((add first (Cn l))) ((add code ((bit (natminus l 1))))) g3) ((inf-powfit ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (succ l) w (inf-lttrans ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (add ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) 2) (inf-pow (succ l)) (inf-lt2 ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1)))))))) ((inf-wsh code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3))) (istransnatleh (succ l) 16 w (inf-ltsu l 16 w1) (istransnatleh 16 31 w (idpath false) gw))))))))
; s7-1
 (defvc inf-vc-walk-s7-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1)))) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 ((inf-powfit ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (succ l) w (inf-lttrans ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) (add ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1))))))) 2) (inf-pow (succ l)) (inf-lt2 ((add ((add code ((bit (natminus l 1))))) ((add code ((bit (natminus l 1)))))))) ((inf-wsh code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3))) (istransnatleh (succ l) 16 w (inf-ltsu l 16 w1) (istransnatleh 16 31 w (idpath false) gw)))))))
; w1b-1
 (defvc inf-vc-walk-w1b-1 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (succ l) (inf-pow w))))
   (given inf-walk-w1 (lam w1 g3 (inf-lelt (succ l) 16 (inf-pow w) (inf-ltsu l 16 w1) (inf-lttrans 16 32 (inf-pow w) (idpath true) (inf-powle 5 w (istransnatleh 5 31 w (idpath false) gw)))))))
; w1b-2
 (defvc inf-vc-walk-w1b-2 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-le 1 (succ l))))
   (given inf-walk-w1 (lam w1 g3 (idpath false))))
; w1b-3
 (defvc inf-vc-walk-w1b-3 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-le (add (add first (Cn l)) (add first (Cn l))) (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1)))))))
   (given inf-walk-w1 (lam w1 g3 (inf-dbl ((add first (Cn l))) ((add code ((bit (natminus l 1))))) g3))))
; w1b-4
 (defvc inf-vc-walk-w1b-4 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-le (add (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1)))) 2) (inf-pow (succ l)))))
   (given inf-walk-w1 (lam w1 g3 ((inf-wsh code ((bit (natminus l 1))) (inf-pow l) (b1 (natminus l 1)) i3)))))
; w1b-5
 (defvc inf-vc-walk-w1b-5 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (paths nat (inf-mod 2 (add (add code (bit (natminus l 1))) (add code (bit (natminus l 1))))) 0)))
   (given inf-walk-w1 (lam w1 g3 (inf-moddbl ((add code ((bit (natminus l 1)))))))))
; w1b-6
 (defvc inf-vc-walk-w1b-6 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-le (add (add index (Cn l)) (inf-sum Cn (natminus 16 (succ l)) (succ l))) n)))
   (given inf-walk-w1 (lam w1 g3 (inf-sumnext Cn 16 l index n w1 i5))))
; w1b-7
 (defvc inf-vc-walk-w1b-7 (under inf-walk-w1 (pi w1 (inf-lt l 16) g3 (inf-le (add first (Cn l)) (add code (bit (natminus l 1)))) (inf-lt (natminus 16 (succ l)) (natminus 16 l))))
   (given inf-walk-w1 (lam w1 g3 (inf-subfall 16 l w1))))
 (defcx inf-build (Ln (pi k nat nat)) (nsym nat) (root nat) (q nat) (u nat) (w nat) (hl (pi k nat g (inf-lt k nsym) (inf-le (Ln k) 15))) (gn (inf-lt nsym q)) (gu (inf-le (inf-by16 q) u)) (gv (inf-le u (inf-pow w))) (gr (inf-le root 15)) (gw (inf-le 32 w)) (gc (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) )
; d0-1
 (defvc inf-vc-build-d0-1 (under inf-build (inf-lt root 32))
   (given inf-build (inf-lelt root 15 32 gr (idpath true))))
; d0-2
 (defvc inf-vc-build-d0-2 (under inf-build (inf-lt (inf-pow root) (inf-pow w)))
   (given inf-build (inf-powlt root w ((inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) ((istransnatleh 16 32 w (idpath false) gw))))))))
; w1e-1
 (defvc inf-vc-build-w1e-1 (under inf-build (inf-le 0 nsym))
   (given inf-build (idpath false)))
; w1e-2
 (defvc inf-vc-build-w1e-2 (under inf-build (pi k nat (paths nat (inf-zero k) (inf-count Ln k 0))))
   (given inf-build (lam k (idpath 0))))
 (defcx inf-build-w1 inf-build (i nat) (Cn (pi j nat nat)) (a1 (inf-le i nsym)) (a2 (pi k nat (paths nat (Cn k) (inf-count Ln k i)))) )
; s1-1
 (defvc inf-vc-build-s1-1 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt i nsym)))
   (given inf-build-w1 (lam w1 w1)))
; s1-2
 (defvc inf-vc-build-s1-2 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (Ln i) 16)))
   (given inf-build-w1 (lam w1 (inf-lelts ((Ln i)) 15 (hl i w1)))))
; s1-3
 (defvc inf-vc-build-s1-3 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (add (Cn (Ln i)) 1) (inf-pow w))))
   (given inf-build-w1 (lam w1 (inf-lelt (add ((Cn ((Ln i)))) 1) nsym (inf-pow w) ((inf-lt1 ((Cn ((Ln i)))) nsym (inf-lelt ((Cn ((Ln i)))) i nsym ((inf-letr (inf-count Ln ((Ln i)) i) ((Cn ((Ln i)))) i (pathsinv0 nat ((Cn ((Ln i)))) (inf-count Ln ((Ln i)) i) (a2 ((Ln i)))) (inf-cntle Ln ((Ln i)) i))) w1))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; s1-4
 (defvc inf-vc-build-s1-4 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (add (Cn (Ln i)) 1) u)))
   (given inf-build-w1 (lam w1 (inf-lelt (add ((Cn ((Ln i)))) 1) nsym u ((inf-lt1 ((Cn ((Ln i)))) nsym (inf-lelt ((Cn ((Ln i)))) i nsym ((inf-letr (inf-count Ln ((Ln i)) i) ((Cn ((Ln i)))) i (pathsinv0 nat ((Cn ((Ln i)))) (inf-count Ln ((Ln i)) i) (a2 ((Ln i)))) (inf-cntle Ln ((Ln i)) i))) w1))) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))))))
; w1b-1
 (defvc inf-vc-build-w1b-1 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1 (lam w1 (inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w1) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w1b-2
 (defvc inf-vc-build-w1b-2 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-le (succ i) nsym)))
   (given inf-build-w1 (lam w1 (inf-ltsu i nsym w1))))
; w1b-3
 (defvc inf-vc-build-w1b-3 (under inf-build-w1 (pi w1 (inf-lt i nsym) (pi k nat (paths nat ((inf-upd Cn (Ln i) (add (Cn (Ln i)) 1)) k) (inf-count Ln k (succ i))))))
   (given inf-build-w1 (lam w1 (lam k (inf-cntstep Ln Cn i a2 k)))))
; w1b-4
 (defvc inf-vc-build-w1b-4 (under inf-build-w1 (pi w1 (inf-lt i nsym) (inf-lt (natminus nsym (succ i)) (natminus nsym i))))
   (given inf-build-w1 (lam w1 (inf-subfall nsym i w1))))
; c5-1
 (defvc inf-vc-build-c5-1 (under inf-build-w1 (pi w1 (inf-le nsym i) (inf-lt 0 16)))
   (given inf-build-w1 (lam w1 (idpath true))))
; c5-2
 (defvc inf-vc-build-c5-2 (under inf-build-w1 (pi w1 (inf-le nsym i) (inf-lt 0 u)))
   (given inf-build-w1 (lam w1 (inf-lelt 0 nsym u (idpath false) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))))))
; ka-1
 (defvc inf-vc-build-ka-1 (under inf-build-w1 (pi w1 (inf-le nsym i) (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym)))))
   (given inf-build-w1 (lam w1 (lam k g (inf-hk Cn Ln i nsym a1 w1 a2 k g)))))
; kb-1
 (defvc inf-vc-build-kb-1 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1)))))
   (given inf-build-w1 (lam w1 hk (lam o (inf-sumcong ((inf-upd Cn 0 0)) (lam v (inf-count Ln v nsym)) hk o 1 (idpath false))))))
; kc-1
 (defvc inf-vc-build-kc-1 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym))))
   (given inf-build-w1 (lam w1 hk hs (lam o (inf-letr ((inf-sum (lam v (inf-count Ln v nsym)) o 1)) ((inf-sum ((inf-upd Cn 0 0)) o 1)) nsym (pathsinv0 nat ((inf-sum ((inf-upd Cn 0 0)) o 1)) ((inf-sum (lam v (inf-count Ln v nsym)) o 1)) (hs o)) (inf-sumcount Ln o 1 nsym))))))
; w2e-1
 (defvc inf-vc-build-w2e-1 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym)) (inf-le 1 1)))
   (given inf-build-w1 (lam w1 hk hs hb (idpath false))))
; w2e-2
 (defvc inf-vc-build-w2e-2 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym)) (inf-le 1 15)))
   (given inf-build-w1 (lam w1 hk hs hb (idpath false))))
; w2e-3
 (defvc inf-vc-build-w2e-3 (under inf-build-w1 (pi w1 (inf-le nsym i) hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym))) hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1))) hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym)) (pi o nat g (inf-lt o 1) (paths nat (inf-zero (succ o)) (inf-sum (inf-upd Cn 0 0) o 1)))))
   (given inf-build-w1 (lam w1 hk hs hb (lam o g (inf-o1 ((inf-upd Cn 0 0)) o g)))))
 (defcx inf-build-w1-w2 inf-build-w1 (w1 (inf-le nsym i)) (hk (pi k nat g (inf-le 1 k) (paths nat ((inf-upd Cn 0 0) k) (inf-count Ln k nsym)))) (hs (pi o nat (paths nat (inf-sum (inf-upd Cn 0 0) o 1) (inf-sum (lam v (inf-count Ln v nsym)) o 1)))) (hb (pi o nat (inf-le (inf-sum (inf-upd Cn 0 0) o 1) nsym))) (l nat) (Of (pi j nat nat)) (b1 (inf-le 1 l)) (b2 (inf-le l 15)) (b3 (pi o nat g (inf-lt o l) (paths nat (Of (succ o)) (inf-sum (inf-upd Cn 0 0) o 1)))) )
; s2-1
 (defvc inf-vc-build-s2-1 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (add l 1) (inf-pow w))))
   (given inf-build-w1-w2 (lam w2 (inf-small (add l 1) w (inf-letrans (add l 1) 15 w (inf-lt1 l 15 w2) ((istransnatleh 15 32 w (idpath false) gw)))))))
; s2-2
 (defvc inf-vc-build-s2-2 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (add l 1) 16)))
   (given inf-build-w1-w2 (lam w2 (inf-lelts (add l 1) 15 (inf-lt1 l 15 w2)))))
; s2-3
 (defvc inf-vc-build-s2-3 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt l 16)))
   (given inf-build-w1-w2 (lam w2 (inf-lttrans l 15 16 w2 (idpath false)))))
; s2-4
 (defvc inf-vc-build-s2-4 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (add (Of l) ((inf-upd Cn 0 0) l)) (inf-pow w))))
   (given inf-build-w1-w2 (lam w2 (inf-lelt (add (Of l) ((((inf-upd Cn 0 0)) l))) nsym (inf-pow w) (inf-letr (inf-sum ((inf-upd Cn 0 0)) l 1) (add (Of l) ((((inf-upd Cn 0 0)) l))) nsym (pathsinv0 nat (add (Of l) ((((inf-upd Cn 0 0)) l))) (inf-sum ((inf-upd Cn 0 0)) l 1) (inf-sumlast ((inf-upd Cn 0 0)) Of l b1 b3)) (hb l)) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w2b-1
 (defvc inf-vc-build-w2b-1 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (succ l) (inf-pow w))))
   (given inf-build-w1-w2 (lam w2 (inf-small (succ l) w (inf-letrans (succ l) 15 w (inf-ltsu l 15 w2) ((istransnatleh 15 32 w (idpath false) gw)))))))
; w2b-2
 (defvc inf-vc-build-w2b-2 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-le 1 (succ l))))
   (given inf-build-w1-w2 (lam w2 (idpath false))))
; w2b-3
 (defvc inf-vc-build-w2b-3 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-le (succ l) 15)))
   (given inf-build-w1-w2 (lam w2 (inf-ltsu l 15 w2))))
; w2b-4
 (defvc inf-vc-build-w2b-4 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (pi o nat g (inf-lt o (succ l)) (paths nat ((inf-upd Of (add l 1) (add (Of l) ((inf-upd Cn 0 0) l))) (succ o)) (inf-sum (inf-upd Cn 0 0) o 1)))))
   (given inf-build-w1-w2 (lam w2 (lam o g (inf-ofstep ((inf-upd Cn 0 0)) Of l b1 b3 o g)))))
; w2b-5
 (defvc inf-vc-build-w2b-5 (under inf-build-w1-w2 (pi w2 (inf-lt l 15) (inf-lt (natminus 15 (succ l)) (natminus 15 l))))
   (given inf-build-w1-w2 (lam w2 (inf-subfall 15 l w2))))
; w3e-1
 (defvc inf-vc-build-w3e-1 (under inf-build-w1-w2 (pi w2 (inf-le 15 l) (inf-le 0 nsym)))
   (given inf-build-w1-w2 (lam w2 (idpath false))))
; w3e-2
 (defvc inf-vc-build-w3e-2 (under inf-build-w1-w2 (pi w2 (inf-le 15 l) (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) 0))))))
   (given inf-build-w1-w2 (lam w2 (lam o g (pathscomp0 nat (Of (succ o)) ((inf-sum ((inf-upd Cn 0 0)) o 1)) (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) 0) (b3 o (inf-lttrans o 15 l g w2)) (pathsinv0 nat (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) 0) ((inf-sum ((inf-upd Cn 0 0)) o 1)) (natplusr0 ((inf-sum ((inf-upd Cn 0 0)) o 1)))))))))
; w3e-3
 (defvc inf-vc-build-w3e-3 (under inf-build-w1-w2 (pi w2 (inf-le 15 l) (pi k nat (inf-lt (inf-zero k) q))))
   (given inf-build-w1-w2 (lam w2 (lam k (inf-lelt 0 nsym q (idpath false) gn)))))
 (defcx inf-build-w1-w2-w3 inf-build-w1-w2 (w2 (inf-le 15 l)) (i nat) (Of (pi j nat nat)) (Sy (pi j nat nat)) (e1 (inf-le i nsym)) (e2 (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) i))))) (e3 (pi k nat (inf-lt (Sy k) q))) )
; s3-1
 (defvc inf-vc-build-s3-1 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) (inf-lt i nsym)))
   (given inf-build-w1-w2-w3 (lam w3 w3)))
; s4-1
 (defvc inf-vc-build-s4-1 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt i nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 w3)))
; s4-2
 (defvc inf-vc-build-s4-2 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (Ln i) 16)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelts ((Ln i)) 15 (hl i w3)))))
; s4-3
 (defvc inf-vc-build-s4-3 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (Of (Ln i)) nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 ((inf-ofs Ln ((inf-upd Cn 0 0)) Of nsym i w3 e2 hs ((Ln i)) (idpath ((Ln i))) g3 (hl i w3))))))
; s4-4
 (defvc inf-vc-build-s4-4 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt i u)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lttrans i nsym u w3 (inf-ltle nsym u ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu))))))))
; s5-1
 (defvc inf-vc-build-s5-1 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt i nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 w3)))
; s5-2
 (defvc inf-vc-build-s5-2 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (Ln i) 16)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelts ((Ln i)) 15 (hl i w3)))))
; s5-3
 (defvc inf-vc-build-s5-3 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (add (Of (Ln i)) 1) (inf-pow w))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelt (add (Of ((Ln i))) 1) nsym (inf-pow w) (inf-lt1 (Of ((Ln i))) nsym ((inf-ofs Ln ((inf-upd Cn 0 0)) Of nsym i w3 e2 hs ((Ln i)) (idpath ((Ln i))) g3 (hl i w3)))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w3b-1
 (defvc inf-vc-build-w3b-1 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w3) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w3b-2
 (defvc inf-vc-build-w3b-2 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-le (succ i) nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-ltsu i nsym w3))))
; w3b-3
 (defvc inf-vc-build-w3b-3 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (pi o nat g (inf-lt o 15) (paths nat ((inf-upd Of (Ln i) (add (Of (Ln i)) 1)) (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) (succ i)))))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (lam o g (inf-fillstep Of Ln i ((inf-sum ((inf-upd Cn 0 0)) o 1)) o (e2 o g))))))
; w3b-4
 (defvc inf-vc-build-w3b-4 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (pi k nat (inf-lt ((inf-upd Sy (Of (Ln i)) i) k) q))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (lam k (inf-uplt Sy (Of ((Ln i))) i q e3 (inf-lttrans i nsym q w3 (inf-ltle nsym q gn)) k)))))
; w3b-5
 (defvc inf-vc-build-w3b-5 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (inf-lt 0 (Ln i)) (inf-lt (natminus nsym (succ i)) (natminus nsym i))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-subfall nsym i w3))))
; w3b-6
 (defvc inf-vc-build-w3b-6 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-lelt (succ i) nsym (inf-pow w) (inf-ltsu i nsym w3) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w3b-7
 (defvc inf-vc-build-w3b-7 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (inf-le (succ i) nsym)))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-ltsu i nsym w3))))
; w3b-8
 (defvc inf-vc-build-w3b-8 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum (inf-upd Cn 0 0) o 1) (inf-count Ln (succ o) (succ i)))))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (lam o g (pathscomp0 nat (Of (succ o)) (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) ((inf-count Ln (succ o) i))) (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) ((inf-count Ln (succ o) (succ i)))) (e2 o g) (maponpaths nat nat (lam z (add ((inf-sum ((inf-upd Cn 0 0)) o 1)) z)) ((inf-count Ln (succ o) i)) ((inf-count Ln (succ o) (succ i))) (pathsinv0 nat ((inf-count Ln (succ o) (succ i))) ((inf-count Ln (succ o) i)) (inf-fillzero Ln i o g3))))))))
; w3b-9
 (defvc inf-vc-build-w3b-9 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (pi k nat (inf-lt (Sy k) q))))
   (given inf-build-w1-w2-w3 (lam w3 g3 e3)))
; w3b-10
 (defvc inf-vc-build-w3b-10 (under inf-build-w1-w2-w3 (pi w3 (inf-lt i nsym) g3 (paths nat (Ln i) 0) (inf-lt (natminus nsym (succ i)) (natminus nsym i))))
   (given inf-build-w1-w2-w3 (lam w3 g3 (inf-subfall nsym i w3))))
; w4e-1
 (defvc inf-vc-build-w4e-1 (under inf-build-w1-w2-w3 (pi w3 (inf-le nsym i) (inf-le 1 1)))
   (given inf-build-w1-w2-w3 (lam w3 (idpath false))))
; w4e-2
 (defvc inf-vc-build-w4e-2 (under inf-build-w1-w2-w3 (pi w3 (inf-le nsym i) (inf-le (add 0 (inf-sum (inf-upd Cn 0 0) (natminus 16 1) 1)) nsym)))
   (given inf-build-w1-w2-w3 (lam w3 (hb 15))))
; w4e-3
 (defvc inf-vc-build-w4e-3 (under inf-build-w1-w2-w3 (pi w3 (inf-le nsym i) (inf-le (add 0 0) (inf-dk 0 1))))
   (given inf-build-w1-w2-w3 (lam w3 (idpath false))))
 (defcx inf-build-w1-w2-w3-w4 inf-build-w1-w2-w3 (w3 (inf-le nsym i)) (l nat) (i nat) (Tb (pi j nat nat)) (idx nat) (code nat) (h1 (inf-le 1 l)) (h2 (inf-le (add idx (inf-sum (inf-upd Cn 0 0) (natminus 16 l) l)) nsym)) (h3 (inf-le (add code code) (inf-dk idx l))) )
; w5e-1
 (defvc inf-vc-build-w5e-1 (under inf-build-w1-w2-w3-w4 (pi w4 (inf-lt l 16) (inf-le 0 ((inf-upd Cn 0 0) l))))
   (given inf-build-w1-w2-w3-w4 (lam w4 (idpath false))))
; w5e-2
 (defvc inf-vc-build-w5e-2 (under inf-build-w1-w2-w3-w4 (pi w4 (inf-lt l 16) (inf-le (add (add idx (natminus ((inf-upd Cn 0 0) l) 0)) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)))
   (given inf-build-w1-w2-w3-w4 (lam w4 (inf-idxenter ((inf-upd Cn 0 0)) l idx nsym w4 h2))))
; w5e-3
 (defvc inf-vc-build-w5e-3 (under inf-build-w1-w2-w3-w4 (pi w4 (inf-lt l 16) (inf-le (add code code) (inf-dk idx l))))
   (given inf-build-w1-w2-w3-w4 (lam w4 h3)))
 (defcx inf-build-w1-w2-w3-w4-w5 inf-build-w1-w2-w3-w4 (w4 (inf-lt l 16)) (i nat) (Tb (pi j nat nat)) (idx nat) (code nat) (j1 (inf-le i ((inf-upd Cn 0 0) l))) (j2 (inf-le (add (add idx (natminus ((inf-upd Cn 0 0) l) i)) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)) (j3 (inf-le (add code code) (inf-dk idx l))) )
; w5h-1
 (defvc inf-vc-build-w5h-1 (under inf-build-w1-w2-w3-w4-w5 (inf-lt l 16))
   (given inf-build-w1-w2-w3-w4-w5 w4))
; d1-1
 (defvc inf-vc-build-d1-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) (inf-lt idx nsym)))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2)))))
; d1-2
 (defvc inf-vc-build-d1-2 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) (inf-lt (Sy idx) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-lttrans ((Sy idx)) q (inf-pow w) (e3 idx) ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))
; d1-3
 (defvc inf-vc-build-d1-3 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) (inf-lt 0 (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-powpos w))))
; s6-1
 (defvc inf-vc-build-s6-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) (inf-lt (add idx 1) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-lelt ((add idx 1)) nsym (inf-pow w) (inf-lt1 idx nsym ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false))))))))))
; w6e-1
 (defvc inf-vc-build-w6e-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-le l root) (inf-le 0 l)))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 (idpath false))))
; w6e-2
 (defvc inf-vc-build-w6e-2 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-le l root) (inf-lt 0 (inf-pow 0))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 (idpath true))))
 (defcx inf-build-w1-w2-w3-w4-w5-w6 inf-build-w1-w2-w3-w4-w5 (w5 (inf-lt i ((inf-upd Cn 0 0) l))) (g7 (inf-le l root)) (b nat) (rev nat) (m1 (inf-le b l)) (m2 (inf-lt rev (inf-pow b))) )
; s8-1
 (defvc inf-vc-build-s8-1 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (add rev rev) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-powfit (add rev rev) (succ b) w (inf-dblfit rev (inf-pow b) m2) ((inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 ((inf-ltsu b l w6)) ((inf-ltsle l 15 w4))) ((istransnatleh 15 32 w (idpath false) gw))))))))
; s8-2
 (defvc inf-vc-build-s8-2 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt b 32)))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-lttrans b l 32 w6 (inf-ltle l 32 (inf-lttrans l 16 32 w4 (idpath false)))))))
; s8-3
 (defvc inf-vc-build-s8-3 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (paths nat (inf-mod 2 (add rev rev)) 0)))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-moddbl rev))))
; s8-4
 (defvc inf-vc-build-s8-4 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (inf-sb code b) 2)))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 ((inf-modlt 1 (inf-shr code b))))))
; s8-5
 (defvc inf-vc-build-s8-5 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (add (add rev rev) (inf-sb code b)) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-powfit (add (add rev rev) ((inf-sb code b))) (succ b) w ((inf-revstep rev (inf-pow b) ((inf-sb code b)) m2 ((inf-modlt 1 (inf-shr code b))))) ((inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 ((inf-ltsu b l w6)) ((inf-ltsle l 15 w4))) ((istransnatleh 15 32 w (idpath false) gw))))))))
; w6b-1
 (defvc inf-vc-build-w6b-1 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (succ b) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-small (succ b) w ((inf-letrans (succ b) 15 w (inf-letrans (succ b) l 15 ((inf-ltsu b l w6)) ((inf-ltsle l 15 w4))) ((istransnatleh 15 32 w (idpath false) gw))))))))
; w6b-2
 (defvc inf-vc-build-w6b-2 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-le (succ b) l)))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 ((inf-ltsu b l w6)))))
; w6b-3
 (defvc inf-vc-build-w6b-3 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (add (add rev rev) (inf-sb code b)) (inf-pow (succ b)))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 ((inf-revstep rev (inf-pow b) ((inf-sb code b)) m2 ((inf-modlt 1 (inf-shr code b))))))))
; w6b-4
 (defvc inf-vc-build-w6b-4 (under inf-build-w1-w2-w3-w4-w5-w6 (pi w6 (inf-lt b l) (inf-lt (natminus l (succ b)) (natminus l b))))
   (given inf-build-w1-w2-w3-w4-w5-w6 (lam w6 (inf-subfall l b w6))))
 (defcx inf-build-w1-w2-w3-w4-w5-w6-w7 inf-build-w1-w2-w3-w4-w5-w6 (w6 (inf-le l b)) (j nat) (Tb (pi j nat nat)) )
; s9-1
 (defvc inf-vc-build-s9-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) (inf-lt j (inf-pow root))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 w7)))
; s10-1
 (defvc inf-vc-build-s10-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt j (inf-pow root))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 w7)))
; s10-2
 (defvc inf-vc-build-s10-2 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (inf-by16 (Sy idx)) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-lelt (inf-by16 ((Sy idx))) ((add (inf-by16 ((Sy idx))) l)) (inf-pow w) (inf-leaddr (inf-by16 ((Sy idx))) l) ((inf-lttrans ((add (inf-by16 ((Sy idx))) l)) (inf-by16 q) (inf-pow w) ((inf-entry ((Sy idx)) l q (e3 idx) w4)) (inf-letrans (inf-by16 q) u (inf-pow w) gu gv)))))))
; s10-3
 (defvc inf-vc-build-s10-3 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (paths nat (inf-mod 16 (inf-by16 (Sy idx))) 0)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-by16low ((Sy idx))))))
; s10-4
 (defvc inf-vc-build-s10-4 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt l 16)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 w4)))
; s10-5
 (defvc inf-vc-build-s10-5 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (add (inf-by16 (Sy idx)) l) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-lttrans ((add (inf-by16 ((Sy idx))) l)) (inf-by16 q) (inf-pow w) ((inf-entry ((Sy idx)) l q (e3 idx) w4)) (inf-letrans (inf-by16 q) u (inf-pow w) gu gv))))))
; s10-6
 (defvc inf-vc-build-s10-6 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (add (inf-by16 (Sy idx)) l) u)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-lttrans ((add (inf-by16 ((Sy idx))) l)) (inf-by16 q) u ((inf-entry ((Sy idx)) l q (e3 idx) w4)) gu))))
; w7b-1
 (defvc inf-vc-build-w7b-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt l 32)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-lttrans l 16 32 w4 (idpath false)))))
; w7b-2
 (defvc inf-vc-build-w7b-2 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (inf-pow l) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-powlt l w ((inf-lttrans l 16 w w4 ((istransnatleh 16 32 w (idpath false) gw))))))))
; w7b-3
 (defvc inf-vc-build-w7b-3 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (add j (inf-pow l)) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-powfit (add j (inf-pow l)) (succ root) w (inf-tabstep j l root w7 g7) (inf-ltsu root w ((inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) ((istransnatleh 16 32 w (idpath false) gw)))))))))))
; w7b-4
 (defvc inf-vc-build-w7b-4 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (paths nat (Tb j) 0) (inf-lt (natminus (inf-pow root) (add j (inf-pow l))) (natminus (inf-pow root) j))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-subby j (inf-pow root) (inf-pow l) w7 (inf-powpos l))))))
; w7b-5
 (defvc inf-vc-build-w7b-5 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (inf-lt 0 (Tb j)) (inf-lt l 32)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-lttrans l 16 32 w4 (idpath false)))))
; w7b-6
 (defvc inf-vc-build-w7b-6 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (inf-lt 0 (Tb j)) (inf-lt (inf-pow l) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 (inf-powlt l w ((inf-lttrans l 16 w w4 ((istransnatleh 16 32 w (idpath false) gw))))))))
; w7b-7
 (defvc inf-vc-build-w7b-7 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (inf-lt 0 (Tb j)) (inf-lt (add j (inf-pow l)) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-powfit (add j (inf-pow l)) (succ root) w (inf-tabstep j l root w7 g7) (inf-ltsu root w ((inf-lelt root 15 w gr (inf-lttrans 15 16 w (idpath true) ((istransnatleh 16 32 w (idpath false) gw)))))))))))
; w7b-8
 (defvc inf-vc-build-w7b-8 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-lt j (inf-pow root)) g9 (inf-lt 0 (Tb j)) (inf-lt (natminus (inf-pow root) (add j (inf-pow l))) (natminus (inf-pow root) j))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 g9 ((inf-subby j (inf-pow root) (inf-pow l) w7 (inf-powpos l))))))
; s11-1
 (defvc inf-vc-build-s11-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-lt (add code 1) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-lelt ((add code 1)) (inf-dk ((add idx 1)) l) (inf-pow w) (inf-letrans ((add code 1)) (add ((add code 1)) ((add code 1))) (inf-dk ((add idx 1)) l) (inf-leaddr ((add code 1)) ((add code 1))) ((inf-code2 code idx l h1 j3))) ((inf-lelt (inf-dk ((add idx 1)) l) (inf-dk q l) (inf-pow w) (inf-dkmono ((add idx 1)) q l (inf-letrans ((add idx 1)) nsym q (inf-lt1 idx nsym ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))) (inf-ltle nsym q gn))) (gc l ((inf-ltsle l 15 w4))))))))))
; w5b-1
 (defvc inf-vc-build-w5b-1 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-lelt (succ i) nsym (inf-pow w) (inf-letrans (succ i) ((((inf-upd Cn 0 0)) l)) nsym (inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5) ((inf-letr (inf-count Ln l nsym) ((((inf-upd Cn 0 0)) l)) nsym (pathsinv0 nat ((((inf-upd Cn 0 0)) l)) (inf-count Ln l nsym) (hk l h1)) (inf-cntle Ln l nsym)))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))))))
; w5b-2
 (defvc inf-vc-build-w5b-2 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-le (succ i) ((inf-upd Cn 0 0) l))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5)))))
; w5b-3
 (defvc inf-vc-build-w5b-3 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-le (add (add (add idx 1) (natminus ((inf-upd Cn 0 0) l) (succ i))) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-idxstep idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2)))))
; w5b-4
 (defvc inf-vc-build-w5b-4 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-le (add (add code 1) (add code 1)) (inf-dk (add idx 1) l))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-code2 code idx l h1 j3)))))
; w5b-5
 (defvc inf-vc-build-w5b-5 (under inf-build-w1-w2-w3-w4-w5-w6-w7 (pi w7 (inf-le (inf-pow root) j) (inf-lt (natminus ((inf-upd Cn 0 0) l) (succ i)) (natminus ((inf-upd Cn 0 0) l) i))))
   (given inf-build-w1-w2-w3-w4-w5-w6-w7 (lam w7 ((inf-subfall ((((inf-upd Cn 0 0)) l)) i w5)))))
; s11-2
 (defvc inf-vc-build-s11-2 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-lt (add code 1) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-lelt ((add code 1)) (inf-dk ((add idx 1)) l) (inf-pow w) (inf-letrans ((add code 1)) (add ((add code 1)) ((add code 1))) (inf-dk ((add idx 1)) l) (inf-leaddr ((add code 1)) ((add code 1))) ((inf-code2 code idx l h1 j3))) ((inf-lelt (inf-dk ((add idx 1)) l) (inf-dk q l) (inf-pow w) (inf-dkmono ((add idx 1)) q l (inf-letrans ((add idx 1)) nsym q (inf-lt1 idx nsym ((inf-idxin idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2))) (inf-ltle nsym q gn))) (gc l ((inf-ltsle l 15 w4))))))))))
; w5b-6
 (defvc inf-vc-build-w5b-6 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-lt (succ i) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-lelt (succ i) nsym (inf-pow w) (inf-letrans (succ i) ((((inf-upd Cn 0 0)) l)) nsym (inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5) ((inf-letr (inf-count Ln l nsym) ((((inf-upd Cn 0 0)) l)) nsym (pathsinv0 nat ((((inf-upd Cn 0 0)) l)) (inf-count Ln l nsym) (hk l h1)) (inf-cntle Ln l nsym)))) ((inf-lttrans nsym q (inf-pow w) gn ((inf-ltle q (inf-pow w) (gc 0 (idpath false)))))))))))
; w5b-7
 (defvc inf-vc-build-w5b-7 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-le (succ i) ((inf-upd Cn 0 0) l))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-ltsu i ((((inf-upd Cn 0 0)) l)) w5)))))
; w5b-8
 (defvc inf-vc-build-w5b-8 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-le (add (add (add idx 1) (natminus ((inf-upd Cn 0 0) l) (succ i))) (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-idxstep idx ((((inf-upd Cn 0 0)) l)) i ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym w5 j2)))))
; w5b-9
 (defvc inf-vc-build-w5b-9 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-le (add (add code 1) (add code 1)) (inf-dk (add idx 1) l))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-code2 code idx l h1 j3)))))
; w5b-10
 (defvc inf-vc-build-w5b-10 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-lt i ((inf-upd Cn 0 0) l)) g7 (inf-lt root l) (inf-lt (natminus ((inf-upd Cn 0 0) l) (succ i)) (natminus ((inf-upd Cn 0 0) l) i))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 g7 ((inf-subfall ((((inf-upd Cn 0 0)) l)) i w5)))))
; s12-1
 (defvc inf-vc-build-s12-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-lt (add code code) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-lelt (add code code) (inf-dk idx l) (inf-pow w) j3 (inf-lelt (inf-dk idx l) (inf-dk q l) (inf-pow w) (inf-dkmono idx q l ((inf-letrans idx nsym q (inf-letrans idx (add idx ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l)))) nsym (inf-leaddr idx ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l)))) (inf-idxout idx (natminus ((((inf-upd Cn 0 0)) l)) i) ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym j2)) (inf-ltle nsym q gn)))) (gc l ((inf-ltsle l 15 w4))))))))
; w4b-1
 (defvc inf-vc-build-w4b-1 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-lt (succ l) (inf-pow w))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-small (succ l) w (inf-letrans (succ l) 16 w (inf-ltsu l 16 w4) ((istransnatleh 16 32 w (idpath false) gw)))))))
; w4b-2
 (defvc inf-vc-build-w4b-2 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-le 1 (succ l))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (idpath false))))
; w4b-3
 (defvc inf-vc-build-w4b-3 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-le (add idx (inf-sum (inf-upd Cn 0 0) (natminus 16 (succ l)) (succ l))) nsym)))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-idxout idx (natminus ((((inf-upd Cn 0 0)) l)) i) ((inf-sum ((inf-upd Cn 0 0)) (natminus 16 (succ l)) (succ l))) nsym j2))))
; w4b-4
 (defvc inf-vc-build-w4b-4 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-le (add (add code code) (add code code)) (inf-dk idx (succ l)))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-dbl (add code code) (inf-dk idx l) j3))))
; w4b-5
 (defvc inf-vc-build-w4b-5 (under inf-build-w1-w2-w3-w4-w5 (pi w5 (inf-le ((inf-upd Cn 0 0) l) i) (inf-lt (natminus 16 (succ l)) (natminus 16 l))))
   (given inf-build-w1-w2-w3-w4-w5 (lam w5 (inf-subfall 16 l w4))))
; end-1
 (defvc inf-vc-build-end-1 (under inf-build-w1-w2-w3-w4 (pi w4 (inf-le 16 l) (pi z nat (inf-lt ((inf-upd Cn 0 0) z) u))))
   (given inf-build-w1-w2-w3-w4 (lam w4 (inf-cphi ((inf-upd Cn 0 0)) Ln nsym u hk (inf-lelt 0 nsym u (idpath false) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))) ((inf-lttrans nsym q u gn (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu)))))))
; end-2
 (defvc inf-vc-build-end-2 (under inf-build-w1-w2-w3-w4 (pi w4 (inf-le 16 l) (pi z nat (inf-lt (Sy z) u))))
   (given inf-build-w1-w2-w3-w4 (lam w4 (lam z (inf-lttrans (Sy z) q u (e3 z) (inf-letrans q (inf-by16 q) u (inf-leby16 q) gu))))))
; end-3
 (defvc inf-vc-build-end-3 (under inf-build-w1-w2-w3-w4 (pi w4 (inf-le 16 l) (inf-le (inf-sum (inf-upd Cn 0 0) 15 1) nsym)))
   (given inf-build-w1-w2-w3-w4 (lam w4 (hb 15))))
 (defcx inf-fill (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) )
; i1-1
 (defvc inf-vc-fill-i1-1 (under inf-fill (inf-lt (add ip0 8) (inf-pow w)))
   (given inf-fill (inf-lelt (add ip0 8) (add n 8) (inf-pow w) (inf-addr ip0 n 8 gi) gn)))
; a1-1
 (defvc inf-vc-fill-a1-1 (under inf-fill (pi g1 (inf-le (add ip0 8) n) (inf-le (add ip0 8) n)))
   (given inf-fill (lam g1 g1)))
; a1-2
 (defvc inf-vc-fill-a1-2 (under inf-fill (pi g1 (inf-le (add ip0 8) n) (inf-lt bc0 64)))
   (given inf-fill (lam g1 (inf-lelts bc0 63 (gs)))))
; a2-1
 (defvc inf-vc-fill-a2-1 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le (inf-div8 bc0) 7)))
   (given inf-fill (lam g1 bba1 (inf-div8le bc0 (gs)))))
; a2-2
 (defvc inf-vc-fill-a2-2 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-lt (add ip0 (natminus 7 (inf-div8 bc0))) (inf-pow w))))
   (given inf-fill (lam g1 bba1 (inf-lelt ((add ip0 ((natminus 7 (inf-div8 bc0))))) n (inf-pow w) (inf-letrans ((add ip0 ((natminus 7 (inf-div8 bc0))))) (add ip0 8) n ((inf-addl ip0 ((natminus 7 (inf-div8 bc0))) 8 (inf-letrans ((natminus 7 (inf-div8 bc0))) 7 8 (inf-suble 7 (inf-div8 bc0)) (idpath false)))) g1) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn))))))
; a3-1
 (defvc inf-vc-fill-a3-1 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le bc0 63)))
   (given inf-fill (lam g1 bba1 gs)))
; a3-2
 (defvc inf-vc-fill-a3-2 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-lt (add 56 (inf-mod 8 bc0)) (inf-pow w))))
   (given inf-fill (lam g1 bba1 (inf-wlit (add 56 (inf-mod 8 bc0)) w gw (inf-or56 bc0)))))
; end-1
 (defvc inf-vc-fill-end-1 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le (add ip0 (natminus 7 (inf-div8 bc0))) n)))
   (given inf-fill (lam g1 bba1 (inf-letrans ((add ip0 ((natminus 7 (inf-div8 bc0))))) (add ip0 8) n ((inf-addl ip0 ((natminus 7 (inf-div8 bc0))) 8 (inf-letrans ((natminus 7 (inf-div8 bc0))) 7 8 (inf-suble 7 (inf-div8 bc0)) (idpath false)))) g1))))
; end-2
 (defvc inf-vc-fill-end-2 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le (add 56 (inf-mod 8 bc0)) 63)))
   (given inf-fill (lam g1 bba1 (inf-or56 bc0))))
; end-3
 (defvc inf-vc-fill-end-3 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-bits-inv carry (add ip0 (natminus 7 (inf-div8 bc0))) cons0 (add 56 (inf-mod 8 bc0)))))
   (given inf-fill (lam g1 bba1 (inf-fillw carry ip0 cons0 bc0 (gs) ga))))
; end-4
 (defvc inf-vc-fill-end-4 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le cons0 cons0)))
   (given inf-fill (lam g1 bba1 (inf-refl cons0))))
; w1e-1
 (defvc inf-vc-fill-w1e-1 (under inf-fill (pi g1 (inf-lt n (add ip0 8)) (inf-le ip0 n)))
   (given inf-fill (lam g1 gi)))
; w1e-2
 (defvc inf-vc-fill-w1e-2 (under inf-fill (pi g1 (inf-lt n (add ip0 8)) (inf-le bc0 63)))
   (given inf-fill (lam g1 gs)))
; w1e-3
 (defvc inf-vc-fill-w1e-3 (under inf-fill (pi g1 (inf-lt n (add ip0 8)) (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-fill (lam g1 ga)))
 (defcx inf-fill-w1 inf-fill (g1 (inf-lt n (add ip0 8))) (ip nat) (bc nat) (bb nat) (j1 (inf-le ip n)) (j3 (inf-le bc 63)) (j4 (inf-bits-inv carry ip cons0 bc)) )
; end-5
 (defvc inf-vc-fill-end-5 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-lt 55 bc) (inf-le ip n)))
   (given inf-fill-w1 (lam w1 g2 j1)))
; end-6
 (defvc inf-vc-fill-end-6 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-lt 55 bc) (inf-le bc 63)))
   (given inf-fill-w1 (lam w1 g2 j3)))
; end-7
 (defvc inf-vc-fill-end-7 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-lt 55 bc) (inf-bits-inv carry ip cons0 bc)))
   (given inf-fill-w1 (lam w1 g2 j4)))
; end-8
 (defvc inf-vc-fill-end-8 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-lt 55 bc) (inf-le cons0 cons0)))
   (given inf-fill-w1 (lam w1 g2 (inf-refl cons0))))
; b2-1
 (defvc inf-vc-fill-b2-1 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 55) (inf-lt ip n)))
   (given inf-fill-w1 (lam w1 g2 w1)))
; b2-2
 (defvc inf-vc-fill-b2-2 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 55) (inf-lt bc 64)))
   (given inf-fill-w1 (lam w1 g2 (inf-lelt bc 55 64 g2 (idpath true)))))
; b3-1
 (defvc inf-vc-fill-b3-1 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 55) bbb2 nat (inf-lt (add ip 1) (inf-pow w))))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-lelt ((add ip 1)) n (inf-pow w) (inf-lt1 ip n w1) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn))))))
; b4-1
 (defvc inf-vc-fill-b4-1 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 55) bbb2 nat (inf-lt (add bc 8) (inf-pow w))))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-wlit (add bc 8) w gw ((inf-addr bc 55 8 g2))))))
; w1b-1
 (defvc inf-vc-fill-w1b-1 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 55) bbb2 nat (inf-le (add ip 1) n)))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-lt1 ip n w1))))
; w1b-2
 (defvc inf-vc-fill-w1b-2 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 55) bbb2 nat (inf-le (add bc 8) 63)))
   (given inf-fill-w1 (lam w1 g2 bbb2 ((inf-addr bc 55 8 g2)))))
; w1b-3
 (defvc inf-vc-fill-w1b-3 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 55) bbb2 nat (inf-bits-inv carry (add ip 1) cons0 (add bc 8))))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-fill1b carry ip cons0 bc j4))))
; w1b-4
 (defvc inf-vc-fill-w1b-4 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 55) bbb2 nat (inf-lt (natminus n (add ip 1)) (natminus n ip))))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-subfall1 n ip w1))))
; end-9
 (defvc inf-vc-fill-end-9 (under inf-fill-w1 (pi w1 (inf-le n ip) (inf-le ip n)))
   (given inf-fill-w1 (lam w1 j1)))
; end-10
 (defvc inf-vc-fill-end-10 (under inf-fill-w1 (pi w1 (inf-le n ip) (inf-le bc 63)))
   (given inf-fill-w1 (lam w1 j3)))
; end-11
 (defvc inf-vc-fill-end-11 (under inf-fill-w1 (pi w1 (inf-le n ip) (inf-bits-inv carry ip cons0 bc)))
   (given inf-fill-w1 (lam w1 j4)))
; end-12
 (defvc inf-vc-fill-end-12 (under inf-fill-w1 (pi w1 (inf-le n ip) (inf-le cons0 cons0)))
   (given inf-fill-w1 (lam w1 (inf-refl cons0))))
 (defcx inf-take (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (k nat) (gk (inf-le k 13)) )
; c1-1
 (defvc inf-vc-take-c1-1 (under inf-take (inf-le 32 w))
   (given inf-take gw))
; c1-2
 (defvc inf-vc-take-c1-2 (under inf-take (inf-lt (add n 8) (inf-pow w)))
   (given inf-take gn))
; c1-3
 (defvc inf-vc-take-c1-3 (under inf-take (inf-le ip0 n))
   (given inf-take gi))
; c1-4
 (defvc inf-vc-take-c1-4 (under inf-take (inf-le bc0 63))
   (given inf-take gs))
; c1-5
 (defvc inf-vc-take-c1-5 (under inf-take (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-take ga))
 (defcx inf-take-c1 inf-take (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
; r1-1
 (defvc inf-vc-take-r1-1 (under inf-take-c1 (pi g1 (inf-lt bcc1 k) (inf-le ipc1 n)))
   (given inf-take-c1 (lam g1 c1e1)))
; r1-2
 (defvc inf-vc-take-r1-2 (under inf-take-c1 (pi g1 (inf-lt bcc1 k) (inf-le bcc1 63)))
   (given inf-take-c1 (lam g1 c1e3)))
; r1-3
 (defvc inf-vc-take-r1-3 (under inf-take-c1 (pi g1 (inf-lt bcc1 k) (inf-bits-inv carry ipc1 consc1 bcc1)))
   (given inf-take-c1 (lam g1 c1e4)))
; r1-4
 (defvc inf-vc-take-r1-4 (under inf-take-c1 (pi g1 (inf-lt bcc1 k) (inf-le cons0 consc1)))
   (given inf-take-c1 (lam g1 c1e5)))
; d1-1
 (defvc inf-vc-take-d1-1 (under inf-take-c1 (pi g1 (inf-le k bcc1) (inf-lt k 32)))
   (given inf-take-c1 (lam g1 ((inf-lttrans k 16 32 (inf-lelts k 15 (inf-letrans k 13 15 gk (idpath false))) (idpath false))))))
; d1-2
 (defvc inf-vc-take-d1-2 (under inf-take-c1 (pi g1 (inf-le k bcc1) (inf-lt (inf-mod (inf-pow k) bbc1) (inf-pow w))))
   (given inf-take-c1 (lam g1 (inf-powfit ((inf-mod (inf-pow k) bbc1)) k w (inf-masklt bbc1 k) (inf-letrans k 13 w gk (inf-letrans 13 32 w (idpath false) gw))))))
; d2-1
 (defvc inf-vc-take-d2-1 (under inf-take-c1 (pi g1 (inf-le k bcc1) (inf-lt k 64)))
   (given inf-take-c1 (lam g1 (inf-lttrans k 16 64 (inf-lelts k 15 (inf-letrans k 13 15 gk (idpath false))) (idpath false)))))
; d3-1
 (defvc inf-vc-take-d3-1 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-le k bcc1)))
   (given inf-take-c1 (lam g1 bbd2 g1)))
; d3-2
 (defvc inf-vc-take-d3-2 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-lt (natminus bcc1 k) (inf-pow w))))
   (given inf-take-c1 (lam g1 bbd2 (inf-wlit ((natminus bcc1 k)) w gw (inf-letrans ((natminus bcc1 k)) bcc1 63 (inf-suble bcc1 k) c1e3)))))
; r2-1
 (defvc inf-vc-take-r2-1 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-le ipc1 n)))
   (given inf-take-c1 (lam g1 bbd2 c1e1)))
; r2-2
 (defvc inf-vc-take-r2-2 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-le (natminus bcc1 k) 63)))
   (given inf-take-c1 (lam g1 bbd2 (inf-sub63 bcc1 k c1e3))))
; r2-3
 (defvc inf-vc-take-r2-3 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-bits-inv carry ipc1 (add consc1 k) (natminus bcc1 k))))
   (given inf-take-c1 (lam g1 bbd2 (inf-take carry ipc1 consc1 bcc1 k g1 c1e4))))
; r2-4
 (defvc inf-vc-take-r2-4 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-le cons0 (add consc1 k))))
   (given inf-take-c1 (lam g1 bbd2 (inf-letrans cons0 consc1 ((add consc1 k)) c1e5 (inf-leaddr consc1 k)))))
; r2-5
 (defvc inf-vc-take-r2-5 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-le (add cons0 k) (add consc1 k))))
   (given inf-take-c1 (lam g1 bbd2 (inf-addr cons0 consc1 k c1e5))))
; r2-6
 (defvc inf-vc-take-r2-6 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-lt (inf-mod (inf-pow k) bbc1) (inf-pow k))))
   (given inf-take-c1 (lam g1 bbd2 (inf-masklt bbc1 k))))
 (defcx inf-sym (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Cn (pi i nat nat)) (Sy (pi i nat nat)) (Tb (pi i nat nat)) (m nat) (h nat) (root nat) (hc (pi i nat (inf-lt (Cn i) (inf-pow h)))) (hs (pi i nat (inf-lt (Sy i) (inf-pow h)))) (gh (inf-le h 16)) (gm (inf-lt m (inf-pow w))) (gt (inf-le (inf-sum Cn 15 1) m)) (gr (inf-le root 15)) )
; c1-1
 (defvc inf-vc-sym-c1-1 (under inf-sym (inf-le 32 w))
   (given inf-sym gw))
; c1-2
 (defvc inf-vc-sym-c1-2 (under inf-sym (inf-lt (add n 8) (inf-pow w)))
   (given inf-sym gn))
; c1-3
 (defvc inf-vc-sym-c1-3 (under inf-sym (inf-le ip0 n))
   (given inf-sym gi))
; c1-4
 (defvc inf-vc-sym-c1-4 (under inf-sym (inf-le bc0 63))
   (given inf-sym gs))
; c1-5
 (defvc inf-vc-sym-c1-5 (under inf-sym (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-sym ga))
 (defcx inf-sym-c1 inf-sym (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
; d1-1
 (defvc inf-vc-sym-d1-1 (under inf-sym-c1 (inf-lt root 32))
   (given inf-sym-c1 ((inf-lttrans root 16 32 (inf-lelts root 15 gr) (idpath false)))))
; d1-2
 (defvc inf-vc-sym-d1-2 (under inf-sym-c1 (inf-lt (inf-mod (inf-pow root) bbc1) (inf-pow root)))
   (given inf-sym-c1 (inf-masklt bbc1 root)))
; w0-1
 (defvc inf-vc-sym-w0-1 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) (pi i nat (inf-le ((inf-sb bbc1) i) 1))))
   (given inf-sym-c1 (lam ed1 g1 (lam i (inf-ltsle (inf-sb bbc1 i) 1 (inf-modlt 1 (inf-shr bbc1 i)))))))
; w0-2
 (defvc inf-vc-sym-w0-2 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) (pi i nat (inf-lt (Cn i) (inf-pow h)))))
   (given inf-sym-c1 (lam ed1 g1 hc)))
; w0-3
 (defvc inf-vc-sym-w0-3 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) (pi i nat (inf-lt (Sy i) (inf-pow h)))))
   (given inf-sym-c1 (lam ed1 g1 hs)))
; w0-4
 (defvc inf-vc-sym-w0-4 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) (inf-le h 16)))
   (given inf-sym-c1 (lam ed1 g1 gh)))
; w0-5
 (defvc inf-vc-sym-w0-5 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) (inf-le 31 w)))
   (given inf-sym-c1 (lam ed1 g1 (inf-letrans 31 32 w (idpath false) gw))))
; w0-6
 (defvc inf-vc-sym-w0-6 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) (inf-lt m (inf-pow w))))
   (given inf-sym-c1 (lam ed1 g1 gm)))
; w0-7
 (defvc inf-vc-sym-w0-7 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) (inf-le (inf-sum Cn 15 1) m)))
   (given inf-sym-c1 (lam ed1 g1 gt)))
; w0s-1
 (defvc inf-vc-sym-w0s-1 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) xw0 nat (inf-le ipc1 n)))
   (given inf-sym-c1 (lam ed1 g1 xw0 c1e1)))
; w0s-2
 (defvc inf-vc-sym-w0s-2 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) xw0 nat (inf-le bcc1 63)))
   (given inf-sym-c1 (lam ed1 g1 xw0 c1e3)))
; w0s-3
 (defvc inf-vc-sym-w0s-3 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) xw0 nat (inf-bits-inv carry ipc1 consc1 bcc1)))
   (given inf-sym-c1 (lam ed1 g1 xw0 c1e4)))
; w0s-4
 (defvc inf-vc-sym-w0s-4 (under inf-sym-c1 (pi ed1 nat g1 (paths nat ed1 0) xw0 nat (inf-le cons0 consc1)))
   (given inf-sym-c1 (lam ed1 g1 xw0 c1e5)))
 (defcx inf-sym-c3 inf-sym-c1 (ed1 nat) (g1 (paths nat ed1 0)) (xw0 nat) (w0e1 (inf-lt xw0 (inf-pow w))) )
 (defcx inf-sym-c2 inf-sym-c1 (ed1 nat) (ei1 nat) )
; d2-1
 (defvc inf-vc-sym-d2-1 (under inf-sym-c2 (inf-lt 4 64))
   (given inf-sym-c2 (idpath true)))
; d3-1
 (defvc inf-vc-sym-d3-1 (under inf-sym-c2 (pi syd2 nat (inf-lt (inf-mod 16 ei1) (inf-pow w))))
   (given inf-sym-c2 (lam syd2 (inf-wlit ((inf-mod 16 ei1)) w gw (inf-letrans ((inf-mod 16 ei1)) 15 63 ((inf-ltsle ((inf-mod 16 ei1)) 15 (inf-modlt 15 ei1))) (idpath false))))))
; r1-1
 (defvc inf-vc-sym-r1-1 (under inf-sym-c2 (pi syd2 nat g2 (inf-lt bcc1 (inf-mod 16 ei1)) (inf-le ipc1 n)))
   (given inf-sym-c2 (lam syd2 g2 c1e1)))
; r1-2
 (defvc inf-vc-sym-r1-2 (under inf-sym-c2 (pi syd2 nat g2 (inf-lt bcc1 (inf-mod 16 ei1)) (inf-le bcc1 63)))
   (given inf-sym-c2 (lam syd2 g2 c1e3)))
; r1-3
 (defvc inf-vc-sym-r1-3 (under inf-sym-c2 (pi syd2 nat g2 (inf-lt bcc1 (inf-mod 16 ei1)) (inf-bits-inv carry ipc1 consc1 bcc1)))
   (given inf-sym-c2 (lam syd2 g2 c1e4)))
; r1-4
 (defvc inf-vc-sym-r1-4 (under inf-sym-c2 (pi syd2 nat g2 (inf-lt bcc1 (inf-mod 16 ei1)) (inf-le cons0 consc1)))
   (given inf-sym-c2 (lam syd2 g2 c1e5)))
; d4-1
 (defvc inf-vc-sym-d4-1 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) (inf-lt (inf-mod 16 ei1) 64)))
   (given inf-sym-c2 (lam syd2 g2 (inf-lelt ((inf-mod 16 ei1)) 15 64 ((inf-ltsle ((inf-mod 16 ei1)) 15 (inf-modlt 15 ei1))) (idpath true)))))
; d5-1
 (defvc inf-vc-sym-d5-1 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-le (inf-mod 16 ei1) bcc1)))
   (given inf-sym-c2 (lam syd2 g2 bbd4 g2)))
; d5-2
 (defvc inf-vc-sym-d5-2 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-lt (natminus bcc1 (inf-mod 16 ei1)) (inf-pow w))))
   (given inf-sym-c2 (lam syd2 g2 bbd4 (inf-wlit ((natminus bcc1 ((inf-mod 16 ei1)))) w gw (inf-letrans ((natminus bcc1 ((inf-mod 16 ei1)))) bcc1 63 (inf-suble bcc1 ((inf-mod 16 ei1))) c1e3)))))
; r2-1
 (defvc inf-vc-sym-r2-1 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-le ipc1 n)))
   (given inf-sym-c2 (lam syd2 g2 bbd4 c1e1)))
; r2-2
 (defvc inf-vc-sym-r2-2 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-le (natminus bcc1 (inf-mod 16 ei1)) 63)))
   (given inf-sym-c2 (lam syd2 g2 bbd4 (inf-sub63 bcc1 ((inf-mod 16 ei1)) c1e3))))
; r2-3
 (defvc inf-vc-sym-r2-3 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-bits-inv carry ipc1 (add consc1 (inf-mod 16 ei1)) (natminus bcc1 (inf-mod 16 ei1)))))
   (given inf-sym-c2 (lam syd2 g2 bbd4 (inf-take carry ipc1 consc1 bcc1 ((inf-mod 16 ei1)) g2 c1e4))))
; r2-4
 (defvc inf-vc-sym-r2-4 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-le cons0 (add consc1 (inf-mod 16 ei1)))))
   (given inf-sym-c2 (lam syd2 g2 bbd4 (inf-letrans cons0 consc1 (add consc1 ((inf-mod 16 ei1))) c1e5 (inf-leaddr consc1 ((inf-mod 16 ei1)))))))
 (defcx inf-stored (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv 0 ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) )
; d1-1
 (defvc inf-vc-stored-d1-1 (under inf-stored (inf-lt (inf-mod 8 bc0) (inf-pow w)))
   (given inf-stored (inf-wlit ((inf-mod 8 bc0)) w gw (inf-letrans ((inf-mod 8 bc0)) 8 63 ((inf-ltle ((inf-mod 8 bc0)) 8 (inf-modlt 7 bc0))) (idpath false)))))
; d2-1
 (defvc inf-vc-stored-d2-1 (under inf-stored (inf-lt (inf-mod 8 bc0) 64))
   (given inf-stored (inf-lttrans ((inf-mod 8 bc0)) 8 64 (inf-modlt 7 bc0) (idpath false))))
; d3-1
 (defvc inf-vc-stored-d3-1 (under inf-stored (pi bbd2 nat (inf-le (inf-mod 8 bc0) bc0)))
   (given inf-stored (lam bbd2 (inf-modle8 bc0))))
; d3-2
 (defvc inf-vc-stored-d3-2 (under inf-stored (pi bbd2 nat (inf-lt (natminus bc0 (inf-mod 8 bc0)) (inf-pow w))))
   (given inf-stored (lam bbd2 (inf-wlit ((natminus bc0 ((inf-mod 8 bc0)))) w gw ((inf-letrans ((natminus bc0 ((inf-mod 8 bc0)))) bc0 63 (inf-suble bc0 ((inf-mod 8 bc0))) gs))))))
; d5-1
 (defvc inf-vc-stored-d5-1 (under inf-stored (pi bbd2 nat (inf-le (inf-div8 (natminus bc0 (inf-mod 8 bc0))) ip0)))
   (given inf-stored (lam bbd2 ((inf-pos ip0 ((add cons0 ((inf-mod 8 bc0)))) ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))) ((inf-dropinv ip0 cons0 bc0 ga)))))))
; d5-2
 (defvc inf-vc-stored-d5-2 (under inf-stored (pi bbd2 nat (inf-lt (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) (inf-pow w))))
   (given inf-stored (lam bbd2 (inf-lelt ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) n (inf-pow w) ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn))))))
; i1-1
 (defvc inf-vc-stored-i1-1 (under inf-stored (pi bbd2 nat (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) (inf-pow w))))
   (given inf-stored (lam bbd2 ((inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn)))))
; d6-1
 (defvc inf-vc-stored-d6-1 (under inf-stored (pi bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 2) n)))
   (given inf-stored (lam bbd2 g1 (inf-letrans (add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2) ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) n (inf-addl ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2 4 (idpath false)) g1))))
; d8-1
 (defvc inf-vc-stored-d8-1 (under inf-stored (pi bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 2) (inf-pow w))))
   (given inf-stored (lam bbd2 g1 x16d6 lnd7 (inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn))))
; d8-2
 (defvc inf-vc-stored-d8-2 (under inf-stored (pi bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat (inf-le (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 2) 2) n)))
   (given inf-stored (lam bbd2 g1 x16d6 lnd7 (inf-letr ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (add (add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2) 2) n (pathsinv0 nat (add (add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2) 2) ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (natplusassoc ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 2 2)) g1))))
; i3-1
 (defvc inf-vc-stored-i3-1 (under inf-stored (pi bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat nld8 nat g2 unit (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) (inf-pow w))))
   (given inf-stored (lam bbd2 g1 x16d6 lnd7 nld8 g2 ((inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn)))))
; i3-2
 (defvc inf-vc-stored-i3-2 (under inf-stored (pi bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat nld8 nat g2 unit (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n)))
   (given inf-stored (lam bbd2 g1 x16d6 lnd7 nld8 g2 g1)))
; i4-1
 (defvc inf-vc-stored-i4-1 (under inf-stored (pi bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat nld8 nat g2 unit g3 (inf-le lnd7 (natminus n (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4))) (inf-le op0 cap)))
   (given inf-stored (lam bbd2 g1 x16d6 lnd7 nld8 g2 g3 gop)))
; m1-1
 (defvc inf-vc-stored-m1-1 (under inf-stored (pi bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat nld8 nat g2 unit g3 (inf-le lnd7 (natminus n (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4))) g4 (inf-le lnd7 (natminus cap op0)) g5 (inf-lt 0 out) (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) (inf-pow w))))
   (given inf-stored (lam bbd2 g1 x16d6 lnd7 nld8 g2 g3 g4 g5 ((inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn)))))
; m1-2
 (defvc inf-vc-stored-m1-2 (under inf-stored (pi bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat nld8 nat g2 unit g3 (inf-le lnd7 (natminus n (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4))) g4 (inf-le lnd7 (natminus cap op0)) g5 (inf-lt 0 out) (inf-le (add op0 lnd7) oc)))
   (given inf-stored (lam bbd2 g1 x16d6 lnd7 nld8 g2 g3 g4 g5 (inf-letl (add op0 (lnd7)) cap oc (pathsinv0 nat oc cap (go g5)) ((inf-roomle op0 cap (lnd7) g4 gop))))))
; m1-3
 (defvc inf-vc-stored-m1-3 (under inf-stored (pi bbd2 nat g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n) x16d6 nat lnd7 nat nld8 nat g2 unit g3 (inf-le lnd7 (natminus n (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4))) g4 (inf-le lnd7 (natminus cap op0)) g5 (inf-lt 0 out) (inf-le (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) n)))
   (given inf-stored (lam bbd2 g1 x16d6 lnd7 nld8 g2 g3 g4 g5 ((inf-roomle ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) n (lnd7) g3 g1)))))
 (defcx inf-stored-c1 inf-stored (bbd2 nat) (g1 (inf-le (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) n)) (x16d6 nat) (lnd7 nat) (nld8 nat) (g2 unit) (g3 (inf-le lnd7 (natminus n (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4)))) (g4 (inf-le lnd7 (natminus cap op0))) )
; d9-1
 (defvc inf-vc-stored-d9-1 (under inf-stored-c1 (inf-lt (add op0 lnd7) (inf-pow w)))
   (given inf-stored-c1 (inf-lelt (add op0 (lnd7)) cap (inf-pow w) ((inf-roomle op0 cap (lnd7) g4 gop)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))
; d10-1
 (defvc inf-vc-stored-d10-1 (under inf-stored-c1 (inf-lt (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) (inf-pow w)))
   (given inf-stored-c1 ((inf-nfit ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4 n w ((inf-letrans ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) ip0 n (inf-suble ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0))))))) gi)) (idpath false) gn))))
; d10-2
 (defvc inf-vc-stored-d10-2 (under inf-stored-c1 (inf-lt (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) (inf-pow w)))
   (given inf-stored-c1 (inf-lelt ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7))) n (inf-pow w) ((inf-roomle ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) n (lnd7) g3 g1)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))))
; d12-1
 (defvc inf-vc-stored-d12-1 (under inf-stored-c1 (pi bbd11 nat (inf-lt 0 (inf-pow w))))
   (given inf-stored-c1 (lam bbd11 (inf-powpos w))))
; r5-1
 (defvc inf-vc-stored-r5-1 (under inf-stored-c1 (pi bbd11 nat (inf-le (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) n)))
   (given inf-stored-c1 (lam bbd11 ((inf-roomle ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) n (lnd7) g3 g1)))))
; r5-2
 (defvc inf-vc-stored-r5-2 (under inf-stored-c1 (pi bbd11 nat (inf-le 0 63)))
   (given inf-stored-c1 (lam bbd11 (idpath false))))
; r5-3
 (defvc inf-vc-stored-r5-3 (under inf-stored-c1 (pi bbd11 nat (inf-bits-inv 0 (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) (inf-by8 (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7)) 0)))
   (given inf-stored-c1 (lam bbd11 (pathsinv0 nat (add (inf-by8 ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7)))) 0) (inf-by8 ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7)))) (natplusr0 (inf-by8 ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7)))))))))
; r5-4
 (defvc inf-vc-stored-r5-4 (under inf-stored-c1 (pi bbd11 nat (inf-le cons0 (inf-by8 (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7)))))
   (given inf-stored-c1 (lam bbd11 (inf-storedc ip0 cons0 ((inf-mod 8 bc0)) ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))) 4 (lnd7) ((inf-dropinv ip0 cons0 bc0 ga))))))
; r5-5
 (defvc inf-vc-stored-r5-5 (under inf-stored-c1 (pi bbd11 nat (inf-le (add op0 lnd7) cap)))
   (given inf-stored-c1 (lam bbd11 ((inf-roomle op0 cap (lnd7) g4 gop)))))
; r5-6
 (defvc inf-vc-stored-r5-6 (under inf-stored-c1 (pi bbd11 nat (inf-le op0 (add op0 lnd7))))
   (given inf-stored-c1 (lam bbd11 (inf-leaddr op0 (lnd7)))))
 (defcx inf-copy (w nat) (l nat) (d nat) (op nat) (out nat) (oc nat) (cap nat) (nd nat) (gw (inf-le 32 w)) (gd (inf-lt d (inf-pow w))) (ga (inf-le d (add op nd))) (gb (inf-le (add op l) cap)) (gz (inf-lt 0 out)) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) )
; s1-1
 (defvc inf-vc-copy-s1-1 (under inf-copy (pi g1 (inf-lt op d) (inf-lt l (inf-pow w))))
   (given inf-copy (lam g1 ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))))
; j1-1
 (defvc inf-vc-copy-j1-1 (under inf-copy (pi g1 (inf-lt op d) (inf-le op d)))
   (given inf-copy (lam g1 (inf-letrans op d d (inf-ltle op d g1) (inf-refl d)))))
; s2-1
 (defvc inf-vc-copy-s2-1 (under inf-copy (pi g1 (inf-lt op d) g2 (inf-lt (natminus d op) l) (inf-le op d)))
   (given inf-copy (lam g1 g2 (inf-letrans op d d (inf-ltle op d g1) (inf-refl d)))))
; s2-2
 (defvc inf-vc-copy-s2-2 (under inf-copy (pi g1 (inf-lt op d) g2 (inf-lt (natminus d op) l) (inf-lt (natminus d op) (inf-pow w))))
   (given inf-copy (lam g1 g2 (inf-lelt (natminus d op) d (inf-pow w) (inf-suble d op) gd))))
; j1j-1
 (defvc inf-vc-copy-j1j-1 (under inf-copy (pi g1 (inf-lt op d) g2 (inf-lt (natminus d op) l) (paths nat (natminus d op) (inf-h d op l))))
   (given inf-copy (lam g1 g2 (inf-htt d op l g2))))
; j1j-2
 (defvc inf-vc-copy-j1j-2 (under inf-copy (pi g1 (inf-lt op d) g2 (inf-le l (natminus d op)) (paths nat l (inf-h d op l))))
   (given inf-copy (lam g1 g2 (inf-hff d op l g2))))
 (defcx inf-copy-c2 inf-copy (g1 (inf-lt op d)) (mj1 nat) (f1 (paths nat mj1 (inf-h d op l))) )
; m1-1
 (defvc inf-vc-copy-m1-1 (under inf-copy-c2 (inf-le op d))
   (given inf-copy-c2 (inf-letrans op d d (inf-ltle op d g1) (inf-refl d))))
; m1-2
 (defvc inf-vc-copy-m1-2 (under inf-copy-c2 (inf-le (natminus d op) nd))
   (given inf-copy-c2 (inf-dnowrap d op nd ga)))
; m1-3
 (defvc inf-vc-copy-m1-3 (under inf-copy-c2 (inf-le (add op mj1) oc))
   (given inf-copy-c2 (inf-letrans (add op mj1) (add op l) oc (inf-addl op mj1 l ((inf-letr (inf-h d op l) mj1 l ((pathsinv0 nat mj1 (inf-h d op l) f1)) (inf-hlel d op l)))) ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))))
; m1-4
 (defvc inf-vc-copy-m1-4 (under inf-copy-c2 (inf-le (add (natminus nd (natminus d op)) mj1) nd))
   (given inf-copy-c2 (inf-letr (add (natminus nd (natminus d op)) (inf-h d op l)) (add (natminus nd (natminus d op)) mj1) nd (maponpaths nat nat (lam z (add (natminus nd (natminus d op)) z)) (inf-h d op l) mj1 ((pathsinv0 nat mj1 (inf-h d op l) f1))) (inf-dr d op l nd ga))))
; w1e-1
 (defvc inf-vc-copy-w1e-1 (under inf-copy-c2 (inf-le mj1 mj1))
   (given inf-copy-c2 (inf-refl mj1)))
 (defcx inf-copy-c2-w1 inf-copy-c2 (k nat) (a1 (inf-le mj1 k)) )
; p1-1
 (defvc inf-vc-copy-p1-1 (under inf-copy-c2-w1 (pi w1 (inf-lt k l) (inf-lt (add op k) (inf-pow w))))
   (given inf-copy-c2-w1 (lam w1 (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op l) cap (inf-ltle (add op k) (add op l) (inf-ltaddl op k l w1)) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; p1-2
 (defvc inf-vc-copy-p1-2 (under inf-copy-c2-w1 (pi w1 (inf-lt k l) (inf-lt (add op k) oc)))
   (given inf-copy-c2-w1 (lam w1 (inf-cw op k l oc w1 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))))))
; p1-3
 (defvc inf-vc-copy-p1-3 (under inf-copy-c2-w1 (pi w1 (inf-lt k l) (inf-le d (add op k))))
   (given inf-copy-c2-w1 (lam w1 (inf-dknowrap d op l k (inf-ltle op d g1) (inf-letr mj1 (inf-h d op l) k f1 a1) w1))))
; p1-4
 (defvc inf-vc-copy-p1-4 (under inf-copy-c2-w1 (pi w1 (inf-lt k l) (inf-lt (natminus (add op k) d) oc)))
   (given inf-copy-c2-w1 (lam w1 (inf-lelt (natminus (add op k) d) (add op k) oc (inf-suble (add op k) d) (inf-cw op k l oc w1 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))))))
; w1b-1
 (defvc inf-vc-copy-w1b-1 (under inf-copy-c2-w1 (pi w1 (inf-lt k l) (inf-lt (succ k) (inf-pow w))))
   (given inf-copy-c2-w1 (lam w1 (inf-lelt (succ k) l (inf-pow w) (inf-ltsu k l w1) ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))))
; w1b-2
 (defvc inf-vc-copy-w1b-2 (under inf-copy-c2-w1 (pi w1 (inf-lt k l) (inf-le mj1 (succ k))))
   (given inf-copy-c2-w1 (lam w1 (inf-letrans mj1 k (succ k) a1 (inf-ltle k (succ k) (inf-ltself k))))))
; w1b-3
 (defvc inf-vc-copy-w1b-3 (under inf-copy-c2-w1 (pi w1 (inf-lt k l) (inf-lt (natminus l (succ k)) (natminus l k))))
   (given inf-copy-c2-w1 (lam w1 (inf-subfall l k w1))))
; w2e-1
 (defvc inf-vc-copy-w2e-1 (under inf-copy (pi g1 (inf-le d op) g3 (inf-le 8 d) (inf-le 0 l)))
   (given inf-copy (lam g1 g3 (idpath false))))
 (defcx inf-copy-w2 inf-copy (g1 (inf-le d op)) (g3 (inf-le 8 d)) (k nat) (a2 (inf-le k l)) )
; w2h-1
 (defvc inf-vc-copy-w2h-1 (under inf-copy-w2 (inf-lt (add k 8) (inf-pow w)))
   (given inf-copy-w2 (inf-nfit k 8 cap w (inf-letrans k l cap a2 (inf-letrans l (add op l) cap (inf-leaddl l op) gb)) (idpath false) gcap)))
; p2-1
 (defvc inf-vc-copy-p2-1 (under inf-copy-w2 (pi w2 (inf-le (add k 8) l) (inf-lt (add op k) (inf-pow w))))
   (given inf-copy-w2 (lam w2 (inf-lelt (add op k) (add op l) (inf-pow w) (inf-addl op k l (inf-letrans k (add k 8) l (inf-leaddr k 8) w2)) (inf-lelt (add op l) cap (inf-pow w) gb ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))))
; p2-2
 (defvc inf-vc-copy-p2-2 (under inf-copy-w2 (pi w2 (inf-le (add k 8) l) (inf-le (add (add op k) 8) oc)))
   (given inf-copy-w2 (lam w2 (inf-letrans (add (add op k) 8) (add op l) oc (inf-letr (add op (add k 8)) (add (add op k) 8) (add op l) (pathsinv0 nat (add (add op k) 8) (add op (add k 8)) (natplusassoc op k 8)) (inf-addl op (add k 8) l w2)) ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))))))
; p2-3
 (defvc inf-vc-copy-p2-3 (under inf-copy-w2 (pi w2 (inf-le (add k 8) l) (inf-le d (add op k))))
   (given inf-copy-w2 (lam w2 ((inf-letrans d op (add op k) g1 (inf-leaddr op k))))))
; p2-4
 (defvc inf-vc-copy-p2-4 (under inf-copy-w2 (pi w2 (inf-le (add k 8) l) (inf-le (add (natminus (add op k) d) 8) oc)))
   (given inf-copy-w2 (lam w2 (inf-letrans (add (natminus (add op k) d) 8) (add (add op k) 8) oc (inf-addr (natminus (add op k) d) (add op k) 8 (inf-suble (add op k) d)) (inf-letrans (add (add op k) 8) (add op l) oc (inf-letr (add op (add k 8)) (add (add op k) 8) (add op l) (pathsinv0 nat (add (add op k) 8) (add op (add k 8)) (natplusassoc op k 8)) (inf-addl op (add k 8) l w2)) ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))))))
; s3-1
 (defvc inf-vc-copy-s3-1 (under inf-copy-w2 (pi w2 (inf-le (add k 8) l) (inf-lt (add k 8) (inf-pow w))))
   (given inf-copy-w2 (lam w2 (inf-nfit k 8 cap w (inf-letrans k l cap a2 (inf-letrans l (add op l) cap (inf-leaddl l op) gb)) (idpath false) gcap))))
; w2b-1
 (defvc inf-vc-copy-w2b-1 (under inf-copy-w2 (pi w2 (inf-le (add k 8) l) (inf-le (add k 8) l)))
   (given inf-copy-w2 (lam w2 w2)))
; w2b-2
 (defvc inf-vc-copy-w2b-2 (under inf-copy-w2 (pi w2 (inf-le (add k 8) l) (inf-lt (natminus l (add k 8)) (natminus l k))))
   (given inf-copy-w2 (lam w2 (inf-subby k l 8 (inf-lttrans k (add k 8) l (inf-ltaddpos k 8 (idpath true)) w2) (idpath true)))))
; j2j-1
 (defvc inf-vc-copy-j2j-1 (under inf-copy-w2 (pi w2 (inf-lt l (add k 8)) (inf-le k l)))
   (given inf-copy-w2 (lam w2 a2)))
; j2j-2
 (defvc inf-vc-copy-j2j-2 (under inf-copy (pi g1 (inf-le d op) g3 unit (inf-le 0 l)))
   (given inf-copy (lam g1 g3 (idpath false))))
 (defcx inf-copy-c1 inf-copy (g1 (inf-le d op)) (kj2 nat) (f3 (inf-le kj2 l)) )
; w3e-1
 (defvc inf-vc-copy-w3e-1 (under inf-copy-c1 (inf-le kj2 l))
   (given inf-copy-c1 f3))
 (defcx inf-copy-c1-w3 inf-copy-c1 (k nat) (a3 (inf-le k l)) )
; p3-1
 (defvc inf-vc-copy-p3-1 (under inf-copy-c1-w3 (pi w3 (inf-lt k l) (inf-lt (add op k) (inf-pow w))))
   (given inf-copy-c1-w3 (lam w3 (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op l) cap (inf-ltle (add op k) (add op l) (inf-ltaddl op k l w3)) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; p3-2
 (defvc inf-vc-copy-p3-2 (under inf-copy-c1-w3 (pi w3 (inf-lt k l) (inf-lt (add op k) oc)))
   (given inf-copy-c1-w3 (lam w3 (inf-cw op k l oc w3 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb))))))
; p3-3
 (defvc inf-vc-copy-p3-3 (under inf-copy-c1-w3 (pi w3 (inf-lt k l) (inf-le d (add op k))))
   (given inf-copy-c1-w3 (lam w3 ((inf-letrans d op (add op k) g1 (inf-leaddr op k))))))
; p3-4
 (defvc inf-vc-copy-p3-4 (under inf-copy-c1-w3 (pi w3 (inf-lt k l) (inf-lt (natminus (add op k) d) oc)))
   (given inf-copy-c1-w3 (lam w3 (inf-lelt (natminus (add op k) d) (add op k) oc (inf-suble (add op k) d) (inf-cw op k l oc w3 ((inf-letl (add op l) cap oc (pathsinv0 nat oc cap (go gz)) gb)))))))
; s4-1
 (defvc inf-vc-copy-s4-1 (under inf-copy-c1-w3 (pi w3 (inf-lt k l) (inf-lt (add k 1) (inf-pow w))))
   (given inf-copy-c1-w3 (lam w3 (inf-lelt (add k 1) l (inf-pow w) (inf-lt1 k l w3) ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))))
; w3b-1
 (defvc inf-vc-copy-w3b-1 (under inf-copy-c1-w3 (pi w3 (inf-lt k l) (inf-le (add k 1) l)))
   (given inf-copy-c1-w3 (lam w3 (inf-lt1 k l w3))))
; w3b-2
 (defvc inf-vc-copy-w3b-2 (under inf-copy-c1-w3 (pi w3 (inf-lt k l) (inf-lt (natminus l (add k 1)) (natminus l k))))
   (given inf-copy-c1-w3 (lam w3 (inf-subfall1 l k w3))))
 (defcx inf-fixed (w nat) (u nat) (gw (inf-le 32 w)) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) )
; w1e-1
 (defvc inf-vc-fixed-w1e-1 (under inf-fixed (inf-le 0 288))
   (given inf-fixed (idpath false)))
; w1e-2
 (defvc inf-vc-fixed-w1e-2 (under inf-fixed (pi k nat (inf-le (inf-zero k) 15)))
   (given inf-fixed (lam k (idpath false))))
 (defcx inf-fixed-w1 inf-fixed (i nat) (Lz (pi j nat nat)) (a1 (inf-le i 288)) (a2 (pi k nat (inf-le (Lz k) 15))) )
; s0-1
 (defvc inf-vc-fixed-s0-1 (under inf-fixed-w1 (pi w1 (inf-lt i 288) (inf-lt 8 (inf-pow w))))
   (given inf-fixed-w1 (lam w1 (inf-wlit 8 w gw (idpath false)))))
; s1-1
 (defvc inf-vc-fixed-s1-1 (under inf-fixed-w1 (pi w1 (inf-lt i 288) g1 (inf-le 144 i) (inf-lt 9 (inf-pow w))))
   (given inf-fixed-w1 (lam w1 g1 (inf-wlit 9 w gw (idpath false)))))
; j1j-1
 (defvc inf-vc-fixed-j1j-1 (under inf-fixed-w1 (pi w1 (inf-lt i 288) g1 (inf-le 144 i) (inf-le 9 15)))
   (given inf-fixed-w1 (lam w1 g1 (idpath false))))
; j1j-2
 (defvc inf-vc-fixed-j1j-2 (under inf-fixed-w1 (pi w1 (inf-lt i 288) g1 (inf-lt i 144) (inf-le 8 15)))
   (given inf-fixed-w1 (lam w1 g1 (idpath false))))
 (defcx inf-fixed-c3 inf-fixed-w1 (w1 (inf-lt i 288)) (vj1 nat) (b1 (inf-le vj1 15)) )
; s2-1
 (defvc inf-vc-fixed-s2-1 (under inf-fixed-c3 (pi g2 (inf-le 256 i) (inf-lt 7 (inf-pow w))))
   (given inf-fixed-c3 (lam g2 (inf-wlit 7 w gw (idpath false)))))
; j2j-1
 (defvc inf-vc-fixed-j2j-1 (under inf-fixed-c3 (pi g2 (inf-le 256 i) (inf-le 7 15)))
   (given inf-fixed-c3 (lam g2 (idpath false))))
; j2j-2
 (defvc inf-vc-fixed-j2j-2 (under inf-fixed-c3 (pi g2 (inf-lt i 256) (inf-le vj1 15)))
   (given inf-fixed-c3 (lam g2 b1)))
 (defcx inf-fixed-c4 inf-fixed-c3 (vj2 nat) (b2 (inf-le vj2 15)) )
; s3-1
 (defvc inf-vc-fixed-s3-1 (under inf-fixed-c4 (pi g3 (inf-le 280 i) (inf-lt 8 (inf-pow w))))
   (given inf-fixed-c4 (lam g3 (inf-wlit 8 w gw (idpath false)))))
; j3j-1
 (defvc inf-vc-fixed-j3j-1 (under inf-fixed-c4 (pi g3 (inf-le 280 i) (inf-le 8 15)))
   (given inf-fixed-c4 (lam g3 (idpath false))))
; j3j-2
 (defvc inf-vc-fixed-j3j-2 (under inf-fixed-c4 (pi g3 (inf-lt i 280) (inf-le vj2 15)))
   (given inf-fixed-c4 (lam g3 b2)))
 (defcx inf-fixed-c5 inf-fixed-c4 (vj3 nat) (b3 (inf-le vj3 15)) )
; s4-1
 (defvc inf-vc-fixed-s4-1 (under inf-fixed-c5 (inf-lt i 320))
   (given inf-fixed-c5 (inf-lttrans i 288 320 w1 (idpath false))))
; s4-2
 (defvc inf-vc-fixed-s4-2 (under inf-fixed-c5 (inf-lt vj3 (inf-pow w)))
   (given inf-fixed-c5 (inf-wlit vj3 w gw (inf-letrans vj3 15 63 b3 (idpath false)))))
; w1b-1
 (defvc inf-vc-fixed-w1b-1 (under inf-fixed-c5 (inf-lt (succ i) (inf-pow w)))
   (given inf-fixed-c5 (inf-lelt (succ i) 288 (inf-pow w) (inf-ltsu i 288 w1) (inf-wfit288 w gw))))
; w1b-2
 (defvc inf-vc-fixed-w1b-2 (under inf-fixed-c5 (inf-le (succ i) 288))
   (given inf-fixed-c5 (inf-ltsu i 288 w1)))
; w1b-3
 (defvc inf-vc-fixed-w1b-3 (under inf-fixed-c5 (pi k nat (inf-le ((inf-upd Lz i vj3) k) 15)))
   (given inf-fixed-c5 (inf-updle Lz i vj3 15 a2 b3)))
; w1b-4
 (defvc inf-vc-fixed-w1b-4 (under inf-fixed-c5 (inf-lt (natminus 288 (succ i)) (natminus 288 i)))
   (given inf-fixed-c5 (inf-subfall 288 i w1)))
; c1-1
 (defvc inf-vc-fixed-c1-1 (under inf-fixed-w1 (pi w1 (inf-le 288 i) (pi k nat g (inf-lt k 288) (inf-le (Lz k) 15))))
   (given inf-fixed-w1 (lam w1 (lam k g (a2 k)))))
; c1-2
 (defvc inf-vc-fixed-c1-2 (under inf-fixed-w1 (pi w1 (inf-le 288 i) (inf-lt 288 q)))
   (given inf-fixed-w1 (lam w1 ((inf-lttrans 288 320 q (idpath true) (inf-ltle 320 q gq2))))))
; c1-3
 (defvc inf-vc-fixed-c1-3 (under inf-fixed-w1 (pi w1 (inf-le 288 i) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-fixed-w1 (lam w1 gq)))
; c1-4
 (defvc inf-vc-fixed-c1-4 (under inf-fixed-w1 (pi w1 (inf-le 288 i) (inf-le (inf-pow h) (inf-pow w))))
   (given inf-fixed-w1 (lam w1 ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))))
; c1-5
 (defvc inf-vc-fixed-c1-5 (under inf-fixed-w1 (pi w1 (inf-le 288 i) (inf-le LROOT 15)))
   (given inf-fixed-w1 (lam w1 gl)))
; c1-6
 (defvc inf-vc-fixed-c1-6 (under inf-fixed-w1 (pi w1 (inf-le 288 i) (inf-le 32 w)))
   (given inf-fixed-w1 (lam w1 gw)))
; c1-7
 (defvc inf-vc-fixed-c1-7 (under inf-fixed-w1 (pi w1 (inf-le 288 i) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-fixed-w1 (lam w1 gk)))
 (defcx inf-fixed-c1 inf-fixed-w1 (w1 (inf-le 288 i)) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (c1e1 (pi z nat (inf-lt (Lcc1 z) (inf-pow h)))) (c1e2 (pi z nat (inf-lt (Lsc1 z) (inf-pow h)))) (c1e3 (inf-le (inf-sum Lcc1 15 1) 288)) )
; w2e-1
 (defvc inf-vc-fixed-w2e-1 (under inf-fixed-c1 (inf-le 0 30))
   (given inf-fixed-c1 (idpath false)))
; w2e-2
 (defvc inf-vc-fixed-w2e-2 (under inf-fixed-c1 (pi k nat (inf-le (Lz k) 15)))
   (given inf-fixed-c1 a2))
 (defcx inf-fixed-c1-w2 inf-fixed-c1 (i nat) (Lz (pi j nat nat)) (a3 (inf-le i 30)) (a4 (pi k nat (inf-le (Lz k) 15))) )
; s5-1
 (defvc inf-vc-fixed-s5-1 (under inf-fixed-c1-w2 (pi w2 (inf-lt i 30) (inf-lt i 320)))
   (given inf-fixed-c1-w2 (lam w2 (inf-lttrans i 30 320 w2 (idpath false)))))
; s5-2
 (defvc inf-vc-fixed-s5-2 (under inf-fixed-c1-w2 (pi w2 (inf-lt i 30) (inf-lt 5 (inf-pow w))))
   (given inf-fixed-c1-w2 (lam w2 (inf-wlit 5 w gw (idpath false)))))
; w2b-1
 (defvc inf-vc-fixed-w2b-1 (under inf-fixed-c1-w2 (pi w2 (inf-lt i 30) (inf-lt (succ i) (inf-pow w))))
   (given inf-fixed-c1-w2 (lam w2 (inf-wlit (succ i) w gw (inf-letrans (succ i) 30 63 (inf-ltsu i 30 w2) (idpath false))))))
; w2b-2
 (defvc inf-vc-fixed-w2b-2 (under inf-fixed-c1-w2 (pi w2 (inf-lt i 30) (inf-le (succ i) 30)))
   (given inf-fixed-c1-w2 (lam w2 (inf-ltsu i 30 w2))))
; w2b-3
 (defvc inf-vc-fixed-w2b-3 (under inf-fixed-c1-w2 (pi w2 (inf-lt i 30) (pi k nat (inf-le ((inf-upd Lz i 5) k) 15))))
   (given inf-fixed-c1-w2 (lam w2 (inf-updle Lz i 5 15 a4 (idpath false)))))
; w2b-4
 (defvc inf-vc-fixed-w2b-4 (under inf-fixed-c1-w2 (pi w2 (inf-lt i 30) (inf-lt (natminus 30 (succ i)) (natminus 30 i))))
   (given inf-fixed-c1-w2 (lam w2 (inf-subfall 30 i w2))))
; c2-1
 (defvc inf-vc-fixed-c2-1 (under inf-fixed-c1-w2 (pi w2 (inf-le 30 i) (pi k nat g (inf-lt k 30) (inf-le (Lz k) 15))))
   (given inf-fixed-c1-w2 (lam w2 (lam k g (a4 k)))))
; c2-2
 (defvc inf-vc-fixed-c2-2 (under inf-fixed-c1-w2 (pi w2 (inf-le 30 i) (inf-lt 30 q)))
   (given inf-fixed-c1-w2 (lam w2 ((inf-lttrans 30 320 q (idpath true) (inf-ltle 320 q gq2))))))
; c2-3
 (defvc inf-vc-fixed-c2-3 (under inf-fixed-c1-w2 (pi w2 (inf-le 30 i) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-fixed-c1-w2 (lam w2 gq)))
; c2-4
 (defvc inf-vc-fixed-c2-4 (under inf-fixed-c1-w2 (pi w2 (inf-le 30 i) (inf-le (inf-pow h) (inf-pow w))))
   (given inf-fixed-c1-w2 (lam w2 ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))))
; c2-5
 (defvc inf-vc-fixed-c2-5 (under inf-fixed-c1-w2 (pi w2 (inf-le 30 i) (inf-le DROOT 15)))
   (given inf-fixed-c1-w2 (lam w2 gd)))
; c2-6
 (defvc inf-vc-fixed-c2-6 (under inf-fixed-c1-w2 (pi w2 (inf-le 30 i) (inf-le 32 w)))
   (given inf-fixed-c1-w2 (lam w2 gw)))
; c2-7
 (defvc inf-vc-fixed-c2-7 (under inf-fixed-c1-w2 (pi w2 (inf-le 30 i) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-fixed-c1-w2 (lam w2 gk)))
 (defcx inf-fixed-c2 inf-fixed-c1-w2 (w2 (inf-le 30 i)) (Dcc2 (pi j nat nat)) (Dsc2 (pi j nat nat)) (Dtc2 (pi j nat nat)) (c2e1 (pi z nat (inf-lt (Dcc2 z) (inf-pow h)))) (c2e2 (pi z nat (inf-lt (Dsc2 z) (inf-pow h)))) (c2e3 (inf-le (inf-sum Dcc2 15 1) 30)) )
; end-1
 (defvc inf-vc-fixed-end-1 (under inf-fixed-c2 (pi k nat (inf-lt (Lcc1 k) (inf-pow h))))
   (given inf-fixed-c2 c1e1))
; end-2
 (defvc inf-vc-fixed-end-2 (under inf-fixed-c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow h))))
   (given inf-fixed-c2 c1e2))
; end-3
 (defvc inf-vc-fixed-end-3 (under inf-fixed-c2 (inf-le (inf-sum Lcc1 15 1) 288))
   (given inf-fixed-c2 c1e3))
; end-4
 (defvc inf-vc-fixed-end-4 (under inf-fixed-c2 (inf-le 288 288))
   (given inf-fixed-c2 (idpath false)))
; end-5
 (defvc inf-vc-fixed-end-5 (under inf-fixed-c2 (pi k nat (inf-lt (Dcc2 k) (inf-pow h))))
   (given inf-fixed-c2 c2e1))
; end-6
 (defvc inf-vc-fixed-end-6 (under inf-fixed-c2 (pi k nat (inf-lt (Dsc2 k) (inf-pow h))))
   (given inf-fixed-c2 c2e2))
; end-7
 (defvc inf-vc-fixed-end-7 (under inf-fixed-c2 (inf-le (inf-sum Dcc2 15 1) 30))
   (given inf-fixed-c2 c2e3))
; end-8
 (defvc inf-vc-fixed-end-8 (under inf-fixed-c2 (inf-le 30 32))
   (given inf-fixed-c2 (idpath false)))
 (defcx inf-dyn (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Ob (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) )
; t1-1
 (defvc inf-vc-dyn-t1-1 (under inf-dyn (inf-le 32 w))
   (given inf-dyn gw))
; t1-2
 (defvc inf-vc-dyn-t1-2 (under inf-dyn (inf-lt (add n 8) (inf-pow w)))
   (given inf-dyn gn))
; t1-3
 (defvc inf-vc-dyn-t1-3 (under inf-dyn (inf-le ip0 n))
   (given inf-dyn gi))
; t1-4
 (defvc inf-vc-dyn-t1-4 (under inf-dyn (inf-le bc0 63))
   (given inf-dyn gs))
; t1-5
 (defvc inf-vc-dyn-t1-5 (under inf-dyn (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-dyn ga))
; t1-6
 (defvc inf-vc-dyn-t1-6 (under inf-dyn (inf-le 5 13))
   (given inf-dyn (idpath false)))
 (defcx inf-dyn-c1 inf-dyn (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons0 const1)) (t1e6 (inf-le (add cons0 5) const1)) (t1e7 (inf-lt xt1 (inf-pow 5))) )
; s1-1
 (defvc inf-vc-dyn-s1-1 (under inf-dyn-c1 (inf-lt (add xt1 257) (inf-pow w)))
   (given inf-dyn-c1 (inf-lelt ((add xt1 257)) 288 (inf-pow w) ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) (inf-wfit288 w gw))))
; t2-1
 (defvc inf-vc-dyn-t2-1 (under inf-dyn-c1 (inf-le 32 w))
   (given inf-dyn-c1 gw))
; t2-2
 (defvc inf-vc-dyn-t2-2 (under inf-dyn-c1 (inf-lt (add n 8) (inf-pow w)))
   (given inf-dyn-c1 gn))
; t2-3
 (defvc inf-vc-dyn-t2-3 (under inf-dyn-c1 (inf-le ipt1 n))
   (given inf-dyn-c1 t1e1))
; t2-4
 (defvc inf-vc-dyn-t2-4 (under inf-dyn-c1 (inf-le bct1 63))
   (given inf-dyn-c1 t1e3))
; t2-5
 (defvc inf-vc-dyn-t2-5 (under inf-dyn-c1 (inf-bits-inv carry ipt1 const1 bct1))
   (given inf-dyn-c1 t1e4))
; t2-6
 (defvc inf-vc-dyn-t2-6 (under inf-dyn-c1 (inf-le 5 13))
   (given inf-dyn-c1 (idpath false)))
 (defcx inf-dyn-c2 inf-dyn-c1 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le const1 const2)) (t2e6 (inf-le (add const1 5) const2)) (t2e7 (inf-lt xt2 (inf-pow 5))) )
; s2-1
 (defvc inf-vc-dyn-s2-1 (under inf-dyn-c2 (inf-lt (add xt2 1) (inf-pow w)))
   (given inf-dyn-c2 (inf-wlit ((add xt2 1)) w gw (inf-letrans ((add xt2 1)) 32 63 ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))) (idpath false)))))
; t3-1
 (defvc inf-vc-dyn-t3-1 (under inf-dyn-c2 (inf-le 32 w))
   (given inf-dyn-c2 gw))
; t3-2
 (defvc inf-vc-dyn-t3-2 (under inf-dyn-c2 (inf-lt (add n 8) (inf-pow w)))
   (given inf-dyn-c2 gn))
; t3-3
 (defvc inf-vc-dyn-t3-3 (under inf-dyn-c2 (inf-le ipt2 n))
   (given inf-dyn-c2 t2e1))
; t3-4
 (defvc inf-vc-dyn-t3-4 (under inf-dyn-c2 (inf-le bct2 63))
   (given inf-dyn-c2 t2e3))
; t3-5
 (defvc inf-vc-dyn-t3-5 (under inf-dyn-c2 (inf-bits-inv carry ipt2 const2 bct2))
   (given inf-dyn-c2 t2e4))
; t3-6
 (defvc inf-vc-dyn-t3-6 (under inf-dyn-c2 (inf-le 4 13))
   (given inf-dyn-c2 (idpath false)))
 (defcx inf-dyn-c3 inf-dyn-c2 (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e6 (inf-le (add const2 4) const3)) (t3e7 (inf-lt xt3 (inf-pow 4))) )
; s3-1
 (defvc inf-vc-dyn-s3-1 (under inf-dyn-c3 (inf-lt (add xt3 4) (inf-pow w)))
   (given inf-dyn-c3 (inf-wlit ((add xt3 4)) w gw (inf-letrans ((add xt3 4)) 19 63 ((inf-addr xt3 15 4 (inf-ltsle xt3 15 t3e7))) (idpath false)))))
; w1e-1
 (defvc inf-vc-dyn-w1e-1 (under inf-dyn-c3 (inf-le 0 (add xt3 4)))
   (given inf-dyn-c3 (idpath false)))
; w1e-2
 (defvc inf-vc-dyn-w1e-2 (under inf-dyn-c3 (pi k nat (inf-le (inf-zero k) 15)))
   (given inf-dyn-c3 (lam k (idpath false))))
; w1e-3
 (defvc inf-vc-dyn-w1e-3 (under inf-dyn-c3 (inf-le (add xt3 4) 19))
   (given inf-dyn-c3 ((inf-addr xt3 15 4 (inf-ltsle xt3 15 t3e7)))))
; w1e-4
 (defvc inf-vc-dyn-w1e-4 (under inf-dyn-c3 (inf-le ipt3 n))
   (given inf-dyn-c3 t3e1))
; w1e-5
 (defvc inf-vc-dyn-w1e-5 (under inf-dyn-c3 (inf-le bct3 63))
   (given inf-dyn-c3 t3e3))
; w1e-6
 (defvc inf-vc-dyn-w1e-6 (under inf-dyn-c3 (inf-bits-inv carry ipt3 const3 bct3))
   (given inf-dyn-c3 t3e4))
; w1e-7
 (defvc inf-vc-dyn-w1e-7 (under inf-dyn-c3 (inf-le cons0 const3))
   (given inf-dyn-c3 ((inf-letrans cons0 const2 const3 (inf-letrans cons0 const1 const2 t1e5 t2e5) t3e5))))
 (defcx inf-dyn-c3-w1 inf-dyn-c3 (i nat) (Cl (pi j nat nat)) (x nat) (ip nat) (bc nat) (bb nat) (cons nat) (a1 (inf-le i (add xt3 4))) (a2 (pi k nat (inf-le (Cl k) 15))) (a3 (inf-le (add xt3 4) 19)) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) )
; t4-1
 (defvc inf-vc-dyn-t4-1 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-le 32 w)))
   (given inf-dyn-c3-w1 (lam w1 gw)))
; t4-2
 (defvc inf-vc-dyn-t4-2 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-lt (add n 8) (inf-pow w))))
   (given inf-dyn-c3-w1 (lam w1 gn)))
; t4-3
 (defvc inf-vc-dyn-t4-3 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-le ip n)))
   (given inf-dyn-c3-w1 (lam w1 r1)))
; t4-4
 (defvc inf-vc-dyn-t4-4 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-le bc 63)))
   (given inf-dyn-c3-w1 (lam w1 r3)))
; t4-5
 (defvc inf-vc-dyn-t4-5 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-bits-inv carry ip cons bc)))
   (given inf-dyn-c3-w1 (lam w1 r4)))
; t4-6
 (defvc inf-vc-dyn-t4-6 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-le 3 13)))
   (given inf-dyn-c3-w1 (lam w1 (idpath false))))
 (defcx inf-dyn-c14 inf-dyn-c3-w1 (w1 (inf-lt i (add xt3 4))) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le cons const4)) (t4e6 (inf-le (add cons 3) const4)) (t4e7 (inf-lt xt4 (inf-pow 3))) )
; s4-1
 (defvc inf-vc-dyn-s4-1 (under inf-dyn-c14 (inf-lt i 19))
   (given inf-dyn-c14 (inf-lttrans i ((add xt3 4)) 19 w1 a3)))
; s4-2
 (defvc inf-vc-dyn-s4-2 (under inf-dyn-c14 (inf-lt (Ob i) 19))
   (given inf-dyn-c14 (hord i (inf-lttrans i ((add xt3 4)) 19 w1 a3))))
; s4-3
 (defvc inf-vc-dyn-s4-3 (under inf-dyn-c14 (inf-lt xt4 (inf-pow w)))
   (given inf-dyn-c14 (inf-lttrans xt4 8 (inf-pow w) t4e7 (inf-powle 3 w (inf-letrans 3 32 w (idpath false) gw)))))
; w1b-1
 (defvc inf-vc-dyn-w1b-1 (under inf-dyn-c14 (inf-lt (succ i) (inf-pow w)))
   (given inf-dyn-c14 (inf-wlit (succ i) w gw (inf-letrans (succ i) 19 63 (inf-ltsu i 19 (inf-lttrans i ((add xt3 4)) 19 w1 a3)) (idpath false)))))
; w1b-2
 (defvc inf-vc-dyn-w1b-2 (under inf-dyn-c14 (inf-le (succ i) (add xt3 4)))
   (given inf-dyn-c14 (inf-ltsu i ((add xt3 4)) w1)))
; w1b-3
 (defvc inf-vc-dyn-w1b-3 (under inf-dyn-c14 (pi k nat (inf-le ((inf-upd Cl (Ob i) xt4) k) 15)))
   (given inf-dyn-c14 (inf-updle Cl (Ob i) xt4 15 a2 (inf-letrans xt4 8 15 (inf-ltle xt4 8 t4e7) (idpath false)))))
; w1b-4
 (defvc inf-vc-dyn-w1b-4 (under inf-dyn-c14 (inf-le (add xt3 4) 19))
   (given inf-dyn-c14 a3))
; w1b-5
 (defvc inf-vc-dyn-w1b-5 (under inf-dyn-c14 (inf-le ipt4 n))
   (given inf-dyn-c14 t4e1))
; w1b-6
 (defvc inf-vc-dyn-w1b-6 (under inf-dyn-c14 (inf-le bct4 63))
   (given inf-dyn-c14 t4e3))
; w1b-7
 (defvc inf-vc-dyn-w1b-7 (under inf-dyn-c14 (inf-bits-inv carry ipt4 const4 bct4))
   (given inf-dyn-c14 t4e4))
; w1b-8
 (defvc inf-vc-dyn-w1b-8 (under inf-dyn-c14 (inf-le cons0 const4))
   (given inf-dyn-c14 (inf-letrans cons0 cons const4 r5 t4e5)))
; w1b-9
 (defvc inf-vc-dyn-w1b-9 (under inf-dyn-c14 (inf-lt (natminus (add xt3 4) (succ i)) (natminus (add xt3 4) i)))
   (given inf-dyn-c14 (inf-subfall ((add xt3 4)) i w1)))
; c2-1
 (defvc inf-vc-dyn-c2-1 (under inf-dyn-c3-w1 (pi w1 (inf-le (add xt3 4) i) (pi k nat g (inf-lt k 19) (inf-le (Cl k) 15))))
   (given inf-dyn-c3-w1 (lam w1 (lam k g (a2 k)))))
; c2-2
 (defvc inf-vc-dyn-c2-2 (under inf-dyn-c3-w1 (pi w1 (inf-le (add xt3 4) i) (inf-lt 19 q)))
   (given inf-dyn-c3-w1 (lam w1 (inf-lttrans 19 320 q (idpath true) ((inf-ltle 320 q gq2))))))
; c2-3
 (defvc inf-vc-dyn-c2-3 (under inf-dyn-c3-w1 (pi w1 (inf-le (add xt3 4) i) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-dyn-c3-w1 (lam w1 gq)))
; c2-4
 (defvc inf-vc-dyn-c2-4 (under inf-dyn-c3-w1 (pi w1 (inf-le (add xt3 4) i) (inf-le (inf-pow h) (inf-pow w))))
   (given inf-dyn-c3-w1 (lam w1 ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))))
; c2-5
 (defvc inf-vc-dyn-c2-5 (under inf-dyn-c3-w1 (pi w1 (inf-le (add xt3 4) i) (inf-le CROOT 15)))
   (given inf-dyn-c3-w1 (lam w1 gc)))
; c2-6
 (defvc inf-vc-dyn-c2-6 (under inf-dyn-c3-w1 (pi w1 (inf-le (add xt3 4) i) (inf-le 32 w)))
   (given inf-dyn-c3-w1 (lam w1 gw)))
; c2-7
 (defvc inf-vc-dyn-c2-7 (under inf-dyn-c3-w1 (pi w1 (inf-le (add xt3 4) i) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-dyn-c3-w1 (lam w1 gk)))
 (defcx inf-dyn-c4 inf-dyn-c3-w1 (w1 (inf-le (add xt3 4) i)) (Ccc2 (pi j nat nat)) (Csc2 (pi j nat nat)) (Ctc2 (pi j nat nat)) (c2e1 (pi z nat (inf-lt (Ccc2 z) (inf-pow h)))) (c2e2 (pi z nat (inf-lt (Csc2 z) (inf-pow h)))) (c2e3 (inf-le (inf-sum Ccc2 15 1) 19)) )
; s5-1
 (defvc inf-vc-dyn-s5-1 (under inf-dyn-c4 (inf-lt (add (add xt1 257) (add xt2 1)) (inf-pow w)))
   (given inf-dyn-c4 (inf-lelt (add ((add xt1 257)) ((add xt2 1))) 320 (inf-pow w) ((inf-add2 ((add xt1 257)) 288 ((add xt2 1)) 32 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))))) ((inf-lelt 320 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))))
; s5b-1
 (defvc inf-vc-dyn-s5b-1 (under inf-dyn-c4 (inf-lt 0 (inf-pow w)))
   (given inf-dyn-c4 (inf-wlit 0 w gw (idpath false))))
; w2e-1
 (defvc inf-vc-dyn-w2e-1 (under inf-dyn-c4 (inf-le 0 15))
   (given inf-dyn-c4 (idpath false)))
; w2e-2
 (defvc inf-vc-dyn-w2e-2 (under inf-dyn-c4 (pi j nat (inf-le (inf-zero j) 15)))
   (given inf-dyn-c4 (lam j (idpath false))))
; w2e-3
 (defvc inf-vc-dyn-w2e-3 (under inf-dyn-c4 (inf-le ip n))
   (given inf-dyn-c4 r1))
; w2e-4
 (defvc inf-vc-dyn-w2e-4 (under inf-dyn-c4 (inf-le bc 63))
   (given inf-dyn-c4 r3))
; w2e-5
 (defvc inf-vc-dyn-w2e-5 (under inf-dyn-c4 (inf-bits-inv carry ip cons bc))
   (given inf-dyn-c4 r4))
; w2e-6
 (defvc inf-vc-dyn-w2e-6 (under inf-dyn-c4 (inf-le cons0 cons))
   (given inf-dyn-c4 r5))
 (defcx inf-dyn-c4-w2 inf-dyn-c4 (i nat) (Lz (pi j nat nat)) (x nat) (ip nat) (bc nat) (bb nat) (cons nat) (prev nat) (b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) )
; t5-1
 (defvc inf-vc-dyn-t5-1 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le 32 w)))
   (given inf-dyn-c4-w2 (lam w2 gw)))
; t5-2
 (defvc inf-vc-dyn-t5-2 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-lt (add n 8) (inf-pow w))))
   (given inf-dyn-c4-w2 (lam w2 gn)))
; t5-3
 (defvc inf-vc-dyn-t5-3 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le ip n)))
   (given inf-dyn-c4-w2 (lam w2 r1)))
; t5-4
 (defvc inf-vc-dyn-t5-4 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le bc 63)))
   (given inf-dyn-c4-w2 (lam w2 r3)))
; t5-5
 (defvc inf-vc-dyn-t5-5 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-bits-inv carry ip cons bc)))
   (given inf-dyn-c4-w2 (lam w2 r4)))
; t5-6
 (defvc inf-vc-dyn-t5-6 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (pi i nat (inf-lt (Ccc2 i) (inf-pow h)))))
   (given inf-dyn-c4-w2 (lam w2 c2e1)))
; t5-7
 (defvc inf-vc-dyn-t5-7 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (pi i nat (inf-lt (Csc2 i) (inf-pow h)))))
   (given inf-dyn-c4-w2 (lam w2 c2e2)))
; t5-8
 (defvc inf-vc-dyn-t5-8 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le h 16)))
   (given inf-dyn-c4-w2 (lam w2 gh)))
; t5-9
 (defvc inf-vc-dyn-t5-9 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-lt 19 (inf-pow w))))
   (given inf-dyn-c4-w2 (lam w2 (inf-wlit 19 w gw (idpath false)))))
; t5-10
 (defvc inf-vc-dyn-t5-10 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le (inf-sum Ccc2 15 1) 19)))
   (given inf-dyn-c4-w2 (lam w2 c2e3)))
; t5-11
 (defvc inf-vc-dyn-t5-11 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le CROOT 15)))
   (given inf-dyn-c4-w2 (lam w2 gc)))
 (defcx inf-dyn-c5 inf-dyn-c4-w2 (w2 (inf-lt i (add (add xt1 257) (add xt2 1)))) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (syt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv carry ipt5 const5 bct5)) (t5e5 (inf-le cons const5)) )
; s6-1
 (defvc inf-vc-dyn-s6-1 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-lt 1 (inf-pow w))))
   (given inf-dyn-c5 (lam g1 (inf-wlit 1 w gw (idpath false)))))
; s7-1
 (defvc inf-vc-dyn-s7-1 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-lt syt5 (inf-pow w))))
   (given inf-dyn-c5 (lam g1 (inf-wlit syt5 w gw (inf-letrans syt5 16 63 (inf-ltle syt5 16 g1) (idpath false))))))
; j1j-1
 (defvc inf-vc-dyn-j1j-1 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-lt 0 1)))
   (given inf-dyn-c5 (lam g1 (idpath true))))
; j1j-2
 (defvc inf-vc-dyn-j1j-2 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-le 1 138)))
   (given inf-dyn-c5 (lam g1 (idpath false))))
; j1j-3
 (defvc inf-vc-dyn-j1j-3 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-le syt5 15)))
   (given inf-dyn-c5 (lam g1 (inf-ltsle syt5 15 g1))))
; j1j-4
 (defvc inf-vc-dyn-j1j-4 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-le ipt5 n)))
   (given inf-dyn-c5 (lam g1 t5e1)))
; j1j-5
 (defvc inf-vc-dyn-j1j-5 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-le bct5 63)))
   (given inf-dyn-c5 (lam g1 t5e3)))
; j1j-6
 (defvc inf-vc-dyn-j1j-6 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-bits-inv carry ipt5 const5 bct5)))
   (given inf-dyn-c5 (lam g1 t5e4)))
; j1j-7
 (defvc inf-vc-dyn-j1j-7 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-le cons0 const5)))
   (given inf-dyn-c5 (lam g1 (inf-letrans cons0 cons const5 r5 t5e5))))
; t6-1
 (defvc inf-vc-dyn-t6-1 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-le 32 w)))
   (given inf-dyn-c5 (lam g1 g2 g3 gw)))
; t6-2
 (defvc inf-vc-dyn-t6-2 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-lt (add n 8) (inf-pow w))))
   (given inf-dyn-c5 (lam g1 g2 g3 gn)))
; t6-3
 (defvc inf-vc-dyn-t6-3 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-le ipt5 n)))
   (given inf-dyn-c5 (lam g1 g2 g3 t5e1)))
; t6-4
 (defvc inf-vc-dyn-t6-4 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-le bct5 63)))
   (given inf-dyn-c5 (lam g1 g2 g3 t5e3)))
; t6-5
 (defvc inf-vc-dyn-t6-5 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-bits-inv carry ipt5 const5 bct5)))
   (given inf-dyn-c5 (lam g1 g2 g3 t5e4)))
; t6-6
 (defvc inf-vc-dyn-t6-6 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-le 2 13)))
   (given inf-dyn-c5 (lam g1 g2 g3 (idpath false))))
 (defcx inf-dyn-c11 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-le syt5 16)) (ipt6 nat) (bct6 nat) (bbt6 nat) (const6 nat) (xt6 nat) (t6e1 (inf-le ipt6 n)) (t6e3 (inf-le bct6 63)) (t6e4 (inf-bits-inv carry ipt6 const6 bct6)) (t6e5 (inf-le const5 const6)) (t6e6 (inf-le (add const5 2) const6)) (t6e7 (inf-lt xt6 (inf-pow 2))) )
; s8-1
 (defvc inf-vc-dyn-s8-1 (under inf-dyn-c11 (inf-lt (add xt6 3) (inf-pow w)))
   (given inf-dyn-c11 (inf-wlit (add xt6 3) w gw (inf-letrans (add xt6 3) 6 63 ((inf-addr xt6 3 3 (inf-ltsle xt6 3 t6e7))) (idpath false)))))
; s9-1
 (defvc inf-vc-dyn-s9-1 (under inf-dyn-c11 (inf-lt prev (inf-pow w)))
   (given inf-dyn-c11 (inf-wlit prev w gw (inf-letrans prev 15 63 b1 (idpath false)))))
; j2j-1
 (defvc inf-vc-dyn-j2j-1 (under inf-dyn-c11 (inf-lt 0 (add xt6 3)))
   (given inf-dyn-c11 (inf-pos3 xt6 3 (idpath true))))
; j2j-2
 (defvc inf-vc-dyn-j2j-2 (under inf-dyn-c11 (inf-le (add xt6 3) 138))
   (given inf-dyn-c11 (inf-letrans (add xt6 3) 6 138 ((inf-addr xt6 3 3 (inf-ltsle xt6 3 t6e7))) (idpath false))))
; j2j-3
 (defvc inf-vc-dyn-j2j-3 (under inf-dyn-c11 (inf-le prev 15))
   (given inf-dyn-c11 b1))
; j2j-4
 (defvc inf-vc-dyn-j2j-4 (under inf-dyn-c11 (inf-le ipt6 n))
   (given inf-dyn-c11 t6e1))
; j2j-5
 (defvc inf-vc-dyn-j2j-5 (under inf-dyn-c11 (inf-le bct6 63))
   (given inf-dyn-c11 t6e3))
; j2j-6
 (defvc inf-vc-dyn-j2j-6 (under inf-dyn-c11 (inf-bits-inv carry ipt6 const6 bct6))
   (given inf-dyn-c11 t6e4))
; j2j-7
 (defvc inf-vc-dyn-j2j-7 (under inf-dyn-c11 (inf-le cons0 const6))
   (given inf-dyn-c11 (inf-letrans cons0 const5 const6 (inf-letrans cons0 cons const5 r5 t5e5) t6e5)))
; t7-1
 (defvc inf-vc-dyn-t7-1 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-le 32 w)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 gw)))
; t7-2
 (defvc inf-vc-dyn-t7-2 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-lt (add n 8) (inf-pow w))))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 gn)))
; t7-3
 (defvc inf-vc-dyn-t7-3 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-le ipt5 n)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e1)))
; t7-4
 (defvc inf-vc-dyn-t7-4 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-le bct5 63)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e3)))
; t7-5
 (defvc inf-vc-dyn-t7-5 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-bits-inv carry ipt5 const5 bct5)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e4)))
; t7-6
 (defvc inf-vc-dyn-t7-6 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-le 3 13)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 (idpath false))))
 (defcx inf-dyn-c10 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-lt 16 syt5)) (g4 (inf-le syt5 17)) (ipt7 nat) (bct7 nat) (bbt7 nat) (const7 nat) (xt7 nat) (t7e1 (inf-le ipt7 n)) (t7e3 (inf-le bct7 63)) (t7e4 (inf-bits-inv carry ipt7 const7 bct7)) (t7e5 (inf-le const5 const7)) (t7e6 (inf-le (add const5 3) const7)) (t7e7 (inf-lt xt7 (inf-pow 3))) )
; s10-1
 (defvc inf-vc-dyn-s10-1 (under inf-dyn-c10 (inf-lt (add xt7 3) (inf-pow w)))
   (given inf-dyn-c10 (inf-wlit (add xt7 3) w gw (inf-letrans (add xt7 3) 10 63 ((inf-addr xt7 7 3 (inf-ltsle xt7 7 t7e7))) (idpath false)))))
; j3j-1
 (defvc inf-vc-dyn-j3j-1 (under inf-dyn-c10 (inf-lt 0 (add xt7 3)))
   (given inf-dyn-c10 (inf-pos3 xt7 3 (idpath true))))
; j3j-2
 (defvc inf-vc-dyn-j3j-2 (under inf-dyn-c10 (inf-le (add xt7 3) 138))
   (given inf-dyn-c10 (inf-letrans (add xt7 3) 10 138 ((inf-addr xt7 7 3 (inf-ltsle xt7 7 t7e7))) (idpath false))))
; j3j-3
 (defvc inf-vc-dyn-j3j-3 (under inf-dyn-c10 (inf-le ipt7 n))
   (given inf-dyn-c10 t7e1))
; j3j-4
 (defvc inf-vc-dyn-j3j-4 (under inf-dyn-c10 (inf-le bct7 63))
   (given inf-dyn-c10 t7e3))
; j3j-5
 (defvc inf-vc-dyn-j3j-5 (under inf-dyn-c10 (inf-bits-inv carry ipt7 const7 bct7))
   (given inf-dyn-c10 t7e4))
; j3j-6
 (defvc inf-vc-dyn-j3j-6 (under inf-dyn-c10 (inf-le cons0 const7))
   (given inf-dyn-c10 (inf-letrans cons0 const5 const7 (inf-letrans cons0 cons const5 r5 t5e5) t7e5)))
; t8-1
 (defvc inf-vc-dyn-t8-1 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-le 32 w)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 gw)))
; t8-2
 (defvc inf-vc-dyn-t8-2 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-lt (add n 8) (inf-pow w))))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 gn)))
; t8-3
 (defvc inf-vc-dyn-t8-3 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-le ipt5 n)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e1)))
; t8-4
 (defvc inf-vc-dyn-t8-4 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-le bct5 63)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e3)))
; t8-5
 (defvc inf-vc-dyn-t8-5 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-bits-inv carry ipt5 const5 bct5)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e4)))
; t8-6
 (defvc inf-vc-dyn-t8-6 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-le 7 13)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 (idpath false))))
 (defcx inf-dyn-c9 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-lt 16 syt5)) (g4 (inf-lt 17 syt5)) (ipt8 nat) (bct8 nat) (bbt8 nat) (const8 nat) (xt8 nat) (t8e1 (inf-le ipt8 n)) (t8e3 (inf-le bct8 63)) (t8e4 (inf-bits-inv carry ipt8 const8 bct8)) (t8e5 (inf-le const5 const8)) (t8e6 (inf-le (add const5 7) const8)) (t8e7 (inf-lt xt8 (inf-pow 7))) )
; s11-1
 (defvc inf-vc-dyn-s11-1 (under inf-dyn-c9 (inf-lt (add xt8 11) (inf-pow w)))
   (given inf-dyn-c9 (inf-lelt (add xt8 11) 512 (inf-pow w) (inf-letrans (add xt8 11) 138 512 ((inf-addr xt8 127 11 (inf-ltsle xt8 127 t8e7))) (idpath false)) (inf-lttrans 512 1024 (inf-pow w) (idpath true) (inf-powle 10 w (inf-letrans 10 32 w (idpath false) gw))))))
; j3j-7
 (defvc inf-vc-dyn-j3j-7 (under inf-dyn-c9 (inf-lt 0 (add xt8 11)))
   (given inf-dyn-c9 (inf-pos3 xt8 11 (idpath true))))
; j3j-8
 (defvc inf-vc-dyn-j3j-8 (under inf-dyn-c9 (inf-le (add xt8 11) 138))
   (given inf-dyn-c9 ((inf-addr xt8 127 11 (inf-ltsle xt8 127 t8e7)))))
; j3j-9
 (defvc inf-vc-dyn-j3j-9 (under inf-dyn-c9 (inf-le ipt8 n))
   (given inf-dyn-c9 t8e1))
; j3j-10
 (defvc inf-vc-dyn-j3j-10 (under inf-dyn-c9 (inf-le bct8 63))
   (given inf-dyn-c9 t8e3))
; j3j-11
 (defvc inf-vc-dyn-j3j-11 (under inf-dyn-c9 (inf-bits-inv carry ipt8 const8 bct8))
   (given inf-dyn-c9 t8e4))
; j3j-12
 (defvc inf-vc-dyn-j3j-12 (under inf-dyn-c9 (inf-le cons0 const8))
   (given inf-dyn-c9 (inf-letrans cons0 const5 const8 (inf-letrans cons0 cons const5 r5 t5e5) t8e5)))
 (defcx inf-dyn-c8 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-lt 16 syt5)) (xj3 nat) (ipj3 nat) (bcj3 nat) (bbj3 nat) (consj3 nat) (rrj3 nat) (f1 (inf-lt 0 rrj3)) (f2 (inf-le rrj3 138)) (r1 (inf-le ipj3 n)) (r3 (inf-le bcj3 63)) (r4 (inf-bits-inv carry ipj3 consj3 bcj3)) (r5 (inf-le cons0 consj3)) )
; s12-1
 (defvc inf-vc-dyn-s12-1 (under inf-dyn-c8 (inf-lt 0 (inf-pow w)))
   (given inf-dyn-c8 (inf-wlit 0 w gw (idpath false))))
; j2j-8
 (defvc inf-vc-dyn-j2j-8 (under inf-dyn-c8 (inf-lt 0 rrj3))
   (given inf-dyn-c8 f1))
; j2j-9
 (defvc inf-vc-dyn-j2j-9 (under inf-dyn-c8 (inf-le rrj3 138))
   (given inf-dyn-c8 f2))
; j2j-10
 (defvc inf-vc-dyn-j2j-10 (under inf-dyn-c8 (inf-le 0 15))
   (given inf-dyn-c8 (idpath false)))
; j2j-11
 (defvc inf-vc-dyn-j2j-11 (under inf-dyn-c8 (inf-le ipj3 n))
   (given inf-dyn-c8 r1))
; j2j-12
 (defvc inf-vc-dyn-j2j-12 (under inf-dyn-c8 (inf-le bcj3 63))
   (given inf-dyn-c8 r3))
; j2j-13
 (defvc inf-vc-dyn-j2j-13 (under inf-dyn-c8 (inf-bits-inv carry ipj3 consj3 bcj3))
   (given inf-dyn-c8 r4))
; j2j-14
 (defvc inf-vc-dyn-j2j-14 (under inf-dyn-c8 (inf-le cons0 consj3))
   (given inf-dyn-c8 r5))
 (defcx inf-dyn-c7 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (xj2 nat) (ipj2 nat) (bcj2 nat) (bbj2 nat) (consj2 nat) (rrj2 nat) (vj2 nat) (f3 (inf-lt 0 rrj2)) (f4 (inf-le rrj2 138)) (f5 (inf-le vj2 15)) (r1 (inf-le ipj2 n)) (r3 (inf-le bcj2 63)) (r4 (inf-bits-inv carry ipj2 consj2 bcj2)) (r5 (inf-le cons0 consj2)) )
; j1j-8
 (defvc inf-vc-dyn-j1j-8 (under inf-dyn-c7 (inf-lt 0 rrj2))
   (given inf-dyn-c7 f3))
; j1j-9
 (defvc inf-vc-dyn-j1j-9 (under inf-dyn-c7 (inf-le rrj2 138))
   (given inf-dyn-c7 f4))
; j1j-10
 (defvc inf-vc-dyn-j1j-10 (under inf-dyn-c7 (inf-le vj2 15))
   (given inf-dyn-c7 f5))
; j1j-11
 (defvc inf-vc-dyn-j1j-11 (under inf-dyn-c7 (inf-le ipj2 n))
   (given inf-dyn-c7 r1))
; j1j-12
 (defvc inf-vc-dyn-j1j-12 (under inf-dyn-c7 (inf-le bcj2 63))
   (given inf-dyn-c7 r3))
; j1j-13
 (defvc inf-vc-dyn-j1j-13 (under inf-dyn-c7 (inf-bits-inv carry ipj2 consj2 bcj2))
   (given inf-dyn-c7 r4))
; j1j-14
 (defvc inf-vc-dyn-j1j-14 (under inf-dyn-c7 (inf-le cons0 consj2))
   (given inf-dyn-c7 r5))
 (defcx inf-dyn-c6 inf-dyn-c5 (rrj1 nat) (vj1 nat) (xj1 nat) (ipj1 nat) (bcj1 nat) (bbj1 nat) (consj1 nat) (f6 (inf-lt 0 rrj1)) (f7 (inf-le rrj1 138)) (f8 (inf-le vj1 15)) (r1 (inf-le ipj1 n)) (r3 (inf-le bcj1 63)) (r4 (inf-bits-inv carry ipj1 consj1 bcj1)) (r5 (inf-le cons0 consj1)) )
; w3e-1
 (defvc inf-vc-dyn-w3e-1 (under inf-dyn-c6 (inf-le 0 rrj1))
   (given inf-dyn-c6 (idpath false)))
; w3e-2
 (defvc inf-vc-dyn-w3e-2 (under inf-dyn-c6 (pi j nat (inf-le (Lz j) 15)))
   (given inf-dyn-c6 b2))
 (defcx inf-dyn-c6-w3 inf-dyn-c6 (k nat) (Lz (pi j nat nat)) (c1 (inf-le k rrj1)) (c2 (pi j nat (inf-le (Lz j) 15))) )
; i2-1
 (defvc inf-vc-dyn-i2-1 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) (inf-lt (add i k) (inf-pow w))))
   (given inf-dyn-c6-w3 (lam w3 (inf-lelt (add i k) 458 (inf-pow w) ((inf-add2 i 320 k 138 ((inf-letrans i (add ((add xt1 257)) ((add xt2 1))) 320 (inf-ltle i (add ((add xt1 257)) ((add xt2 1))) w2) ((inf-add2 ((add xt1 257)) 288 ((add xt2 1)) 32 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))))))) (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7))) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; s13-1
 (defvc inf-vc-dyn-s13-1 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-lt (add i k) 320) (inf-lt (add i k) (inf-pow w))))
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-lelt (add i k) 458 (inf-pow w) ((inf-add2 i 320 k 138 ((inf-letrans i (add ((add xt1 257)) ((add xt2 1))) 320 (inf-ltle i (add ((add xt1 257)) ((add xt2 1))) w2) ((inf-add2 ((add xt1 257)) 288 ((add xt2 1)) 32 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))))))) (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7))) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; s13-2
 (defvc inf-vc-dyn-s13-2 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-lt (add i k) 320) (inf-lt (add i k) 320)))
   (given inf-dyn-c6-w3 (lam w3 g5 g5)))
; s13-3
 (defvc inf-vc-dyn-s13-3 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-lt (add i k) 320) (inf-lt vj1 (inf-pow w))))
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false))))))
; w3b-1
 (defvc inf-vc-dyn-w3b-1 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-lt (add i k) 320) (inf-lt (succ k) (inf-pow w))))
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-lelt (succ k) 138 (inf-pow w) ((inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7)) ((inf-lelt 138 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; w3b-2
 (defvc inf-vc-dyn-w3b-2 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-lt (add i k) 320) (inf-le (succ k) rrj1)))
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-ltsu k rrj1 w3))))
; w3b-3
 (defvc inf-vc-dyn-w3b-3 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-lt (add i k) 320) (pi j nat (inf-le ((inf-upd Lz (add i k) vj1) j) 15))))
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-updle Lz (add i k) vj1 15 c2 f8))))
; w3b-4
 (defvc inf-vc-dyn-w3b-4 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-lt (add i k) 320) (inf-lt (natminus rrj1 (succ k)) (natminus rrj1 k))))
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-subfall rrj1 k w3))))
; w3b-5
 (defvc inf-vc-dyn-w3b-5 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-le 320 (add i k)) (inf-lt (succ k) (inf-pow w))))
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-lelt (succ k) 138 (inf-pow w) ((inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7)) ((inf-lelt 138 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; w3b-6
 (defvc inf-vc-dyn-w3b-6 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-le 320 (add i k)) (inf-le (succ k) rrj1)))
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-ltsu k rrj1 w3))))
; w3b-7
 (defvc inf-vc-dyn-w3b-7 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-le 320 (add i k)) (pi j nat (inf-le (Lz j) 15))))
   (given inf-dyn-c6-w3 (lam w3 g5 c2)))
; w3b-8
 (defvc inf-vc-dyn-w3b-8 (under inf-dyn-c6-w3 (pi w3 (inf-lt k rrj1) g5 (inf-le 320 (add i k)) (inf-lt (natminus rrj1 (succ k)) (natminus rrj1 k))))
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-subfall rrj1 k w3))))
; s14-1
 (defvc inf-vc-dyn-s14-1 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-lt (add i rrj1) (inf-pow w))))
   (given inf-dyn-c6-w3 (lam w3 (inf-lelt (add i rrj1) 458 (inf-pow w) (inf-add2 i 320 rrj1 138 ((inf-letrans i (add ((add xt1 257)) ((add xt2 1))) 320 (inf-ltle i (add ((add xt1 257)) ((add xt2 1))) w2) ((inf-add2 ((add xt1 257)) 288 ((add xt2 1)) 32 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))))))) f7) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; s15-1
 (defvc inf-vc-dyn-s15-1 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-lt vj1 (inf-pow w))))
   (given inf-dyn-c6-w3 (lam w3 (inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false))))))
; w2b-1
 (defvc inf-vc-dyn-w2b-1 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-le vj1 15)))
   (given inf-dyn-c6-w3 (lam w3 f8)))
; w2b-2
 (defvc inf-vc-dyn-w2b-2 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (pi j nat (inf-le (Lz j) 15))))
   (given inf-dyn-c6-w3 (lam w3 c2)))
; w2b-3
 (defvc inf-vc-dyn-w2b-3 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-le ipj1 n)))
   (given inf-dyn-c6-w3 (lam w3 r1)))
; w2b-4
 (defvc inf-vc-dyn-w2b-4 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-le bcj1 63)))
   (given inf-dyn-c6-w3 (lam w3 r3)))
; w2b-5
 (defvc inf-vc-dyn-w2b-5 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-bits-inv carry ipj1 consj1 bcj1)))
   (given inf-dyn-c6-w3 (lam w3 r4)))
; w2b-6
 (defvc inf-vc-dyn-w2b-6 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-le cons0 consj1)))
   (given inf-dyn-c6-w3 (lam w3 r5)))
; w2b-7
 (defvc inf-vc-dyn-w2b-7 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-lt (natminus (add (add xt1 257) (add xt2 1)) (add i rrj1)) (natminus (add (add xt1 257) (add xt2 1)) i))))
   (given inf-dyn-c6-w3 (lam w3 (inf-subby i (add ((add xt1 257)) ((add xt2 1))) rrj1 w2 f6))))
; c4-1
 (defvc inf-vc-dyn-c4-1 (under inf-dyn-c4-w2 (pi w2 (inf-le (add (add xt1 257) (add xt2 1)) i) (pi k nat g (inf-lt k (add xt1 257)) (inf-le (Lz k) 15))))
   (given inf-dyn-c4-w2 (lam w2 (lam k g (b2 k)))))
; c4-2
 (defvc inf-vc-dyn-c4-2 (under inf-dyn-c4-w2 (pi w2 (inf-le (add (add xt1 257) (add xt2 1)) i) (inf-lt (add xt1 257) q)))
   (given inf-dyn-c4-w2 (lam w2 (inf-lelt ((add xt1 257)) 288 q ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7))) (inf-lttrans 288 320 q (idpath true) ((inf-ltle 320 q gq2)))))))
; c4-3
 (defvc inf-vc-dyn-c4-3 (under inf-dyn-c4-w2 (pi w2 (inf-le (add (add xt1 257) (add xt2 1)) i) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-dyn-c4-w2 (lam w2 gq)))
; c4-4
 (defvc inf-vc-dyn-c4-4 (under inf-dyn-c4-w2 (pi w2 (inf-le (add (add xt1 257) (add xt2 1)) i) (inf-le (inf-pow h) (inf-pow w))))
   (given inf-dyn-c4-w2 (lam w2 ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))))
; c4-5
 (defvc inf-vc-dyn-c4-5 (under inf-dyn-c4-w2 (pi w2 (inf-le (add (add xt1 257) (add xt2 1)) i) (inf-le LROOT 15)))
   (given inf-dyn-c4-w2 (lam w2 gl)))
; c4-6
 (defvc inf-vc-dyn-c4-6 (under inf-dyn-c4-w2 (pi w2 (inf-le (add (add xt1 257) (add xt2 1)) i) (inf-le 32 w)))
   (given inf-dyn-c4-w2 (lam w2 gw)))
; c4-7
 (defvc inf-vc-dyn-c4-7 (under inf-dyn-c4-w2 (pi w2 (inf-le (add (add xt1 257) (add xt2 1)) i) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-dyn-c4-w2 (lam w2 gk)))
 (defcx inf-dyn-c12 inf-dyn-c4-w2 (w2 (inf-le (add (add xt1 257) (add xt2 1)) i)) (Lcc4 (pi j nat nat)) (Lsc4 (pi j nat nat)) (Ltc4 (pi j nat nat)) (c4e1 (pi z nat (inf-lt (Lcc4 z) (inf-pow h)))) (c4e2 (pi z nat (inf-lt (Lsc4 z) (inf-pow h)))) (c4e3 (inf-le (inf-sum Lcc4 15 1) (add xt1 257))) )
; c5-1
 (defvc inf-vc-dyn-c5-1 (under inf-dyn-c12 (pi k nat g (inf-lt k (add xt2 1)) (inf-le ((inf-shift Lz (add xt1 257)) k) 15)))
   (given inf-dyn-c12 (lam k g (b2 (add ((add xt1 257)) k)))))
; c5-2
 (defvc inf-vc-dyn-c5-2 (under inf-dyn-c12 (inf-lt (add xt2 1) q))
   (given inf-dyn-c12 (inf-lelt ((add xt2 1)) 32 q ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))) (inf-lttrans 32 320 q (idpath true) ((inf-ltle 320 q gq2))))))
; c5-3
 (defvc inf-vc-dyn-c5-3 (under inf-dyn-c12 (inf-le (inf-by16 q) (inf-pow h)))
   (given inf-dyn-c12 gq))
; c5-4
 (defvc inf-vc-dyn-c5-4 (under inf-dyn-c12 (inf-le (inf-pow h) (inf-pow w)))
   (given inf-dyn-c12 ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))
; c5-5
 (defvc inf-vc-dyn-c5-5 (under inf-dyn-c12 (inf-le DROOT 15))
   (given inf-dyn-c12 gd))
; c5-6
 (defvc inf-vc-dyn-c5-6 (under inf-dyn-c12 (inf-le 32 w))
   (given inf-dyn-c12 gw))
; c5-7
 (defvc inf-vc-dyn-c5-7 (under inf-dyn-c12 (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))))
   (given inf-dyn-c12 gk))
 (defcx inf-dyn-c13 inf-dyn-c12 (Dcc5 (pi j nat nat)) (Dsc5 (pi j nat nat)) (Dtc5 (pi j nat nat)) (c5e1 (pi z nat (inf-lt (Dcc5 z) (inf-pow h)))) (c5e2 (pi z nat (inf-lt (Dsc5 z) (inf-pow h)))) (c5e3 (inf-le (inf-sum Dcc5 15 1) (add xt2 1))) )
; r2-1
 (defvc inf-vc-dyn-r2-1 (under inf-dyn-c13 (inf-le ip n))
   (given inf-dyn-c13 r1))
; r2-2
 (defvc inf-vc-dyn-r2-2 (under inf-dyn-c13 (inf-le bc 63))
   (given inf-dyn-c13 r3))
; r2-3
 (defvc inf-vc-dyn-r2-3 (under inf-dyn-c13 (inf-bits-inv carry ip cons bc))
   (given inf-dyn-c13 r4))
; r2-4
 (defvc inf-vc-dyn-r2-4 (under inf-dyn-c13 (inf-le cons0 cons))
   (given inf-dyn-c13 r5))
; r2-5
 (defvc inf-vc-dyn-r2-5 (under inf-dyn-c13 (pi k nat (inf-lt (Lcc4 k) (inf-pow h))))
   (given inf-dyn-c13 c4e1))
; r2-6
 (defvc inf-vc-dyn-r2-6 (under inf-dyn-c13 (pi k nat (inf-lt (Lsc4 k) (inf-pow h))))
   (given inf-dyn-c13 c4e2))
; r2-7
 (defvc inf-vc-dyn-r2-7 (under inf-dyn-c13 (inf-le (inf-sum Lcc4 15 1) (add xt1 257)))
   (given inf-dyn-c13 c4e3))
; r2-8
 (defvc inf-vc-dyn-r2-8 (under inf-dyn-c13 (inf-le (add xt1 257) 288))
   (given inf-dyn-c13 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7)))))
; r2-9
 (defvc inf-vc-dyn-r2-9 (under inf-dyn-c13 (pi k nat (inf-lt (Dcc5 k) (inf-pow h))))
   (given inf-dyn-c13 c5e1))
; r2-10
 (defvc inf-vc-dyn-r2-10 (under inf-dyn-c13 (pi k nat (inf-lt (Dsc5 k) (inf-pow h))))
   (given inf-dyn-c13 c5e2))
; r2-11
 (defvc inf-vc-dyn-r2-11 (under inf-dyn-c13 (inf-le (inf-sum Dcc5 15 1) (add xt2 1)))
   (given inf-dyn-c13 c5e3))
; r2-12
 (defvc inf-vc-dyn-r2-12 (under inf-dyn-c13 (inf-le (add xt2 1) 32))
   (given inf-dyn-c13 ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7)))))
 (defcx inf-fast (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gcf (inf-lt (add cap 266) (inf-pow w))) (Lt (pi k nat nat)) (Dt (pi k nat nat)) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (h nat) (LROOT nat) (DROOT nat) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16)) (gz (inf-lt 0 out)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) )
; w1e-1
 (defvc inf-vc-fast-w1e-1 (under inf-fast (inf-le ip0 n))
   (given inf-fast gi))
; w1e-2
 (defvc inf-vc-fast-w1e-2 (under inf-fast (inf-le bc0 63))
   (given inf-fast gs))
; w1e-3
 (defvc inf-vc-fast-w1e-3 (under inf-fast (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-fast ga))
; w1e-4
 (defvc inf-vc-fast-w1e-4 (under inf-fast (inf-le cons0 cons0))
   (given inf-fast (inf-refl cons0)))
; w1e-5
 (defvc inf-vc-fast-w1e-5 (under inf-fast (inf-le op0 op0))
   (given inf-fast (inf-refl op0)))
; w1e-6
 (defvc inf-vc-fast-w1e-6 (under inf-fast (inf-le op0 cap))
   (given inf-fast gop))
 (defcx inf-fast-w1 inf-fast (ans nat) (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (j1 (inf-le ip n)) (j3 (inf-le bc 63)) (j4 (inf-bits-inv carry ip cons bc)) (j5 (inf-le cons0 cons)) (j6 (inf-le op0 op)) (j7 (inf-le op cap)) )
; w1h-1
 (defvc inf-vc-fast-w1h-1 (under inf-fast-w1 (inf-lt (add op 266) (inf-pow w)))
   (given inf-fast-w1 (inf-lelt (add op 266) (add cap 266) (inf-pow w) (inf-addr op cap 266 j7) gcf)))
; i2-1
 (defvc inf-vc-fast-i2-1 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) (inf-lt (add ip 8) (inf-pow w))))
   (given inf-fast-w1 (lam w1 g1 (inf-lelt (add ip 8) (add n 8) (inf-pow w) (inf-addr ip n 8 j1) gn))))
; r4-1
 (defvc inf-vc-fast-r4-1 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-le ip n)))
   (given inf-fast-w1 (lam w1 g1 g2 j1)))
; r4-2
 (defvc inf-vc-fast-r4-2 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-le bc 63)))
   (given inf-fast-w1 (lam w1 g1 g2 j3)))
; r4-3
 (defvc inf-vc-fast-r4-3 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-bits-inv carry ip cons bc)))
   (given inf-fast-w1 (lam w1 g1 g2 j4)))
; r4-4
 (defvc inf-vc-fast-r4-4 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-le cons0 cons)))
   (given inf-fast-w1 (lam w1 g1 g2 j5)))
; r4-5
 (defvc inf-vc-fast-r4-5 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-le op cap)))
   (given inf-fast-w1 (lam w1 g1 g2 j7)))
; r4-6
 (defvc inf-vc-fast-r4-6 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-le op0 op)))
   (given inf-fast-w1 (lam w1 g1 g2 j6)))
; f1-1
 (defvc inf-vc-fast-f1-1 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) (inf-le (add ip 8) n)))
   (given inf-fast-w1 (lam w1 g1 g2 g2)))
; f1-2
 (defvc inf-vc-fast-f1-2 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) (inf-lt bc 64)))
   (given inf-fast-w1 (lam w1 g1 g2 (inf-lttrans bc 15 64 g1 (idpath false)))))
; f2-1
 (defvc inf-vc-fast-f2-1 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-le (inf-div8 bc) 7)))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-div8le bc ((inf-letrans bc 15 63 (inf-ltle bc 15 g1) (idpath false)))))))
; f2-2
 (defvc inf-vc-fast-f2-2 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-lt (add ip (natminus 7 (inf-div8 bc))) (inf-pow w))))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-lelt ((add ip ((natminus 7 (inf-div8 bc))))) n (inf-pow w) ((inf-letrans ((add ip ((natminus 7 (inf-div8 bc))))) (add ip 8) n (inf-addl ip ((natminus 7 (inf-div8 bc))) 8 (inf-letrans ((natminus 7 (inf-div8 bc))) 7 8 (inf-suble 7 (inf-div8 bc)) (idpath false))) g2)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn))))))
; f3-1
 (defvc inf-vc-fast-f3-1 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-le bc 63)))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 j3)))
; f3-2
 (defvc inf-vc-fast-f3-2 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-lt (add 56 (inf-mod 8 bc)) (inf-pow w))))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-wlit (add 56 (inf-mod 8 bc)) w gw (inf-or56 bc)))))
; i1j-1
 (defvc inf-vc-fast-i1j-1 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-le (add ip (natminus 7 (inf-div8 bc))) n)))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 ((inf-letrans ((add ip ((natminus 7 (inf-div8 bc))))) (add ip 8) n (inf-addl ip ((natminus 7 (inf-div8 bc))) 8 (inf-letrans ((natminus 7 (inf-div8 bc))) 7 8 (inf-suble 7 (inf-div8 bc)) (idpath false))) g2)))))
; i1j-2
 (defvc inf-vc-fast-i1j-2 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-le (add 56 (inf-mod 8 bc)) 63)))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-or56 bc))))
; i1j-3
 (defvc inf-vc-fast-i1j-3 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-bits-inv carry (add ip (natminus 7 (inf-div8 bc))) cons (add 56 (inf-mod 8 bc)))))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-fillw carry ip cons bc ((inf-letrans bc 15 63 (inf-ltle bc 15 g1) (idpath false))) j4))))
; i1j-4
 (defvc inf-vc-fast-i1j-4 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-le 15 (add 56 (inf-mod 8 bc)))))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-letrans 15 56 (add 56 (inf-mod 8 bc)) (idpath false) (inf-leaddr 56 (inf-mod 8 bc))))))
; i1j-5
 (defvc inf-vc-fast-i1j-5 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc) (inf-le ip n)))
   (given inf-fast-w1 (lam w1 g1 j1)))
; i1j-6
 (defvc inf-vc-fast-i1j-6 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc) (inf-le bc 63)))
   (given inf-fast-w1 (lam w1 g1 j3)))
; i1j-7
 (defvc inf-vc-fast-i1j-7 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc) (inf-bits-inv carry ip cons bc)))
   (given inf-fast-w1 (lam w1 g1 j4)))
; i1j-8
 (defvc inf-vc-fast-i1j-8 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc) (inf-le 15 bc)))
   (given inf-fast-w1 (lam w1 g1 g1)))
 (defcx inf-fast-c1 inf-fast-w1 (w1 (inf-le (add op 266) cap)) (bbi1 nat) (ipi1 nat) (bci1 nat) (h1 (inf-le ipi1 n)) (h3 (inf-le bci1 63)) (h4 (inf-bits-inv carry ipi1 cons bci1)) (h5 (inf-le 15 bci1)) )
; d1-1
 (defvc inf-vc-fast-d1-1 (under inf-fast-c1 (inf-lt LROOT 32))
   (given inf-fast-c1 (inf-lelt LROOT 15 32 gl (idpath true))))
; d1-2
 (defvc inf-vc-fast-d1-2 (under inf-fast-c1 (inf-lt (inf-mod (inf-pow LROOT) bbi1) (inf-pow LROOT)))
   (given inf-fast-c1 (inf-masklt bbi1 LROOT)))
; r4-7
 (defvc inf-vc-fast-r4-7 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 h1)))
; r4-8
 (defvc inf-vc-fast-r4-8 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le bci1 63)))
   (given inf-fast-c1 (lam ed1 g3 h3)))
; r4-9
 (defvc inf-vc-fast-r4-9 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-bits-inv carry ipi1 cons bci1)))
   (given inf-fast-c1 (lam ed1 g3 h4)))
; r4-10
 (defvc inf-vc-fast-r4-10 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le cons0 cons)))
   (given inf-fast-c1 (lam ed1 g3 j5)))
; r4-11
 (defvc inf-vc-fast-r4-11 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le op cap)))
   (given inf-fast-c1 (lam ed1 g3 j7)))
; r4-12
 (defvc inf-vc-fast-r4-12 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le op0 op)))
   (given inf-fast-c1 (lam ed1 g3 j6)))
; d2-1
 (defvc inf-vc-fast-d2-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) (inf-lt 4 64)))
   (given inf-fast-c1 (lam ed1 g3 (idpath true))))
; d3-1
 (defvc inf-vc-fast-d3-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) (inf-lt (inf-mod 16 ed1) 64)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 ((inf-lttrans ((inf-mod 16 ed1)) 16 64 ((inf-modlt 15 ed1)) (idpath false))))))
; d4-1
 (defvc inf-vc-fast-d4-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le (inf-mod 16 ed1) bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5)))))
; d4-2
 (defvc inf-vc-fast-d4-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-lt (natminus bci1 (inf-mod 16 ed1)) (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-wlit ((natminus bci1 ((inf-mod 16 ed1)))) w gw (inf-letrans ((natminus bci1 ((inf-mod 16 ed1)))) bci1 63 (inf-suble bci1 ((inf-mod 16 ed1))) h3)))))
; p1-1
 (defvc inf-vc-fast-p1-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-lt op oc)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 ((inf-lttrans op cap oc ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))))))
; p1-2
 (defvc inf-vc-fast-p1-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-lt syd2 256)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 g4)))
; s1-1
 (defvc inf-vc-fast-s1-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-lt (add op 1) (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-lelt (add op 1) cap (inf-pow w) (inf-lt1 op cap ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; w1b-1
 (defvc inf-vc-fast-w1b-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 h1)))
; w1b-2
 (defvc inf-vc-fast-w1b-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le (natminus bci1 (inf-mod 16 ed1)) 63)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-sub63 bci1 ((inf-mod 16 ed1)) h3))))
; w1b-3
 (defvc inf-vc-fast-w1b-3 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-bits-inv carry ipi1 (add cons (inf-mod 16 ed1)) (natminus bci1 (inf-mod 16 ed1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-take carry ipi1 cons bci1 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5)) h4))))
; w1b-4
 (defvc inf-vc-fast-w1b-4 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le cons0 (add cons (inf-mod 16 ed1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1)))))))
; w1b-5
 (defvc inf-vc-fast-w1b-5 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le op0 (add op 1))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-letrans op0 op (add op 1) j6 (inf-leaddr op 1)))))
; w1b-6
 (defvc inf-vc-fast-w1b-6 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le (add op 1) cap)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-lt1 op cap ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1))))))
; w1b-7
 (defvc inf-vc-fast-w1b-7 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-lt (natminus cap (add op 1)) (natminus cap op))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-subfall1 cap op ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1))))))
; d6-1
 (defvc inf-vc-fast-d6-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) (inf-lt (inf-mod 16 ed1) 64)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 ((inf-lttrans ((inf-mod 16 ed1)) 16 64 ((inf-modlt 15 ed1)) (idpath false))))))
; d7-1
 (defvc inf-vc-fast-d7-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le (inf-mod 16 ed1) bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5)))))
; d7-2
 (defvc inf-vc-fast-d7-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-lt (natminus bci1 (inf-mod 16 ed1)) (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-wlit ((natminus bci1 ((inf-mod 16 ed1)))) w gw (inf-letrans ((natminus bci1 ((inf-mod 16 ed1)))) bci1 63 (inf-suble bci1 ((inf-mod 16 ed1))) h3)))))
; s2-1
 (defvc inf-vc-fast-s2-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-lt 1 (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-wlit 1 w gw (idpath false)))))
; r4-13
 (defvc inf-vc-fast-r4-13 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 h1)))
; r4-14
 (defvc inf-vc-fast-r4-14 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le (natminus bci1 (inf-mod 16 ed1)) 63)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-sub63 bci1 ((inf-mod 16 ed1)) h3))))
; r4-15
 (defvc inf-vc-fast-r4-15 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-bits-inv carry ipi1 (add cons (inf-mod 16 ed1)) (natminus bci1 (inf-mod 16 ed1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-take carry ipi1 cons bci1 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5)) h4))))
; r4-16
 (defvc inf-vc-fast-r4-16 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le cons0 (add cons (inf-mod 16 ed1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1)))))))
; r4-17
 (defvc inf-vc-fast-r4-17 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le op cap)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 j7)))
; r4-18
 (defvc inf-vc-fast-r4-18 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le op0 op)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 j6)))
; r1-1
 (defvc inf-vc-fast-r1-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-lt 285 syd2) (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 h1)))
; r1-2
 (defvc inf-vc-fast-r1-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-lt 285 syd2) (inf-le bci1 63)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 h3)))
; r1-3
 (defvc inf-vc-fast-r1-3 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-lt 285 syd2) (inf-bits-inv carry ipi1 cons bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 h4)))
; r1-4
 (defvc inf-vc-fast-r1-4 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-lt 285 syd2) (inf-le cons0 cons)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 j5)))
; r1-5
 (defvc inf-vc-fast-r1-5 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-lt 285 syd2) (inf-le op cap)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 j7)))
; r1-6
 (defvc inf-vc-fast-r1-6 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-lt 285 syd2) (inf-le op0 op)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 j6)))
; i8-1
 (defvc inf-vc-fast-i8-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) (inf-lt (add ipi1 8) (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 (inf-lelt (add ipi1 8) (add n 8) (inf-pow w) (inf-addr ipi1 n 8 h1) gn))))
; r4-19
 (defvc inf-vc-fast-r4-19 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 h1)))
; r4-20
 (defvc inf-vc-fast-r4-20 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le bci1 63)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 h3)))
; r4-21
 (defvc inf-vc-fast-r4-21 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-bits-inv carry ipi1 cons bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 h4)))
; r4-22
 (defvc inf-vc-fast-r4-22 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le cons0 cons)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 j5)))
; r4-23
 (defvc inf-vc-fast-r4-23 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le op cap)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 j7)))
; r4-24
 (defvc inf-vc-fast-r4-24 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le op0 op)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 j6)))
; f4-1
 (defvc inf-vc-fast-f4-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) (inf-le (add ipi1 8) n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 g8)))
; f4-2
 (defvc inf-vc-fast-f4-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) (inf-lt bci1 64)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 (inf-lttrans bci1 48 64 g7 (idpath false)))))
; f5-1
 (defvc inf-vc-fast-f5-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-le (inf-div8 bci1) 7)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-div8le bci1 ((inf-letrans bci1 48 63 (inf-ltle bci1 48 g7) (idpath false)))))))
; f5-2
 (defvc inf-vc-fast-f5-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-lt (add ipi1 (natminus 7 (inf-div8 bci1))) (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-lelt ((add ipi1 ((natminus 7 (inf-div8 bci1))))) n (inf-pow w) ((inf-letrans ((add ipi1 ((natminus 7 (inf-div8 bci1))))) (add ipi1 8) n (inf-addl ipi1 ((natminus 7 (inf-div8 bci1))) 8 (inf-letrans ((natminus 7 (inf-div8 bci1))) 7 8 (inf-suble 7 (inf-div8 bci1)) (idpath false))) g8)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn))))))
; f6-1
 (defvc inf-vc-fast-f6-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-le bci1 63)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 h3)))
; f6-2
 (defvc inf-vc-fast-f6-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-lt (add 56 (inf-mod 8 bci1)) (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-wlit (add 56 (inf-mod 8 bci1)) w gw (inf-or56 bci1)))))
; i7j-1
 (defvc inf-vc-fast-i7j-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-le (add ipi1 (natminus 7 (inf-div8 bci1))) n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 ((inf-letrans ((add ipi1 ((natminus 7 (inf-div8 bci1))))) (add ipi1 8) n (inf-addl ipi1 ((natminus 7 (inf-div8 bci1))) 8 (inf-letrans ((natminus 7 (inf-div8 bci1))) 7 8 (inf-suble 7 (inf-div8 bci1)) (idpath false))) g8)))))
; i7j-2
 (defvc inf-vc-fast-i7j-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-le (add 56 (inf-mod 8 bci1)) 63)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-or56 bci1))))
; i7j-3
 (defvc inf-vc-fast-i7j-3 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-bits-inv carry (add ipi1 (natminus 7 (inf-div8 bci1))) cons (add 56 (inf-mod 8 bci1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-fillw carry ipi1 cons bci1 ((inf-letrans bci1 48 63 (inf-ltle bci1 48 g7) (idpath false))) h4))))
; i7j-4
 (defvc inf-vc-fast-i7j-4 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-le 48 (add 56 (inf-mod 8 bci1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-letrans 48 56 (add 56 (inf-mod 8 bci1)) (idpath false) (inf-leaddr 56 (inf-mod 8 bci1))))))
; i7j-5
 (defvc inf-vc-fast-i7j-5 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1) (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 h1)))
; i7j-6
 (defvc inf-vc-fast-i7j-6 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1) (inf-le bci1 63)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 h3)))
; i7j-7
 (defvc inf-vc-fast-i7j-7 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1) (inf-bits-inv carry ipi1 cons bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 h4)))
; i7j-8
 (defvc inf-vc-fast-i7j-8 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1) (inf-le 48 bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g7)))
 (defcx inf-fast-c2 inf-fast-c1 (ed1 nat) (g3 (inf-lt 0 ed1)) (syd2 nat) (g4 (inf-le 256 syd2)) (g5 (inf-lt 256 syd2)) (g6 (inf-le syd2 285)) (bbi7 nat) (ipi7 nat) (bci7 nat) (m1 (inf-le ipi7 n)) (m3 (inf-le bci7 63)) (m4 (inf-bits-inv carry ipi7 cons bci7)) (m5 (inf-le 48 bci7)) )
; d9-1
 (defvc inf-vc-fast-d9-1 (under inf-fast-c2 (inf-le 257 syd2))
   (given inf-fast-c2 ((inf-ltsu 256 syd2 g5))))
; d9-2
 (defvc inf-vc-fast-d9-2 (under inf-fast-c2 (inf-lt (natminus syd2 257) 29))
   (given inf-fast-c2 ((inf-lidx syd2 g6))))
; d9-3
 (defvc inf-vc-fast-d9-3 (under inf-fast-c2 (inf-lt (Le (natminus syd2 257)) (inf-pow w)))
   (given inf-fast-c2 (inf-wlit ((Le ((natminus syd2 257)))) w gw (inf-letrans ((Le ((natminus syd2 257)))) 5 63 ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) (idpath false)))))
; d10-1
 (defvc inf-vc-fast-d10-1 (under inf-fast-c2 (inf-lt (add (inf-mod 16 ed1) (Le (natminus syd2 257))) (inf-pow w)))
   (given inf-fast-c2 (inf-wlit (add ((inf-mod 16 ed1)) ((Le ((natminus syd2 257))))) w gw (inf-letrans (add ((inf-mod 16 ed1)) ((Le ((natminus syd2 257))))) 20 63 (inf-add2 ((inf-mod 16 ed1)) 15 ((Le ((natminus syd2 257)))) 5 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6))))) (idpath false)))))
; d10-2
 (defvc inf-vc-fast-d10-2 (under inf-fast-c2 (inf-lt (add (inf-mod 16 ed1) (Le (natminus syd2 257))) 64))
   (given inf-fast-c2 (inf-lelt (add ((inf-mod 16 ed1)) ((Le ((natminus syd2 257))))) 20 64 (inf-add2 ((inf-mod 16 ed1)) 15 ((Le ((natminus syd2 257)))) 5 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6))))) (idpath true))))
; d11-1
 (defvc inf-vc-fast-d11-1 (under inf-fast-c2 (pi yd10 nat (inf-lt DROOT 32)))
   (given inf-fast-c2 (lam yd10 (inf-lelt DROOT 15 32 gd (idpath true)))))
; d11-2
 (defvc inf-vc-fast-d11-2 (under inf-fast-c2 (pi yd10 nat (inf-lt (inf-mod (inf-pow DROOT) yd10) (inf-pow DROOT))))
   (given inf-fast-c2 (lam yd10 (inf-masklt yd10 DROOT))))
; r4-25
 (defvc inf-vc-fast-r4-25 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le ipi7 n)))
   (given inf-fast-c2 (lam yd10 fd11 g9 m1)))
; r4-26
 (defvc inf-vc-fast-r4-26 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le bci7 63)))
   (given inf-fast-c2 (lam yd10 fd11 g9 m3)))
; r4-27
 (defvc inf-vc-fast-r4-27 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-bits-inv carry ipi7 cons bci7)))
   (given inf-fast-c2 (lam yd10 fd11 g9 m4)))
; r4-28
 (defvc inf-vc-fast-r4-28 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le cons0 cons)))
   (given inf-fast-c2 (lam yd10 fd11 g9 j5)))
; r4-29
 (defvc inf-vc-fast-r4-29 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le op cap)))
   (given inf-fast-c2 (lam yd10 fd11 g9 j7)))
; r4-30
 (defvc inf-vc-fast-r4-30 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le op0 op)))
   (given inf-fast-c2 (lam yd10 fd11 g9 j6)))
; d12-1
 (defvc inf-vc-fast-d12-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) (inf-lt (inf-mod 16 ed1) 64)))
   (given inf-fast-c2 (lam yd10 fd11 g9 ((inf-lttrans ((inf-mod 16 ed1)) 16 64 ((inf-modlt 15 ed1)) (idpath false))))))
; d13-1
 (defvc inf-vc-fast-d13-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat (inf-le (inf-mod 16 ed1) bci7)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5))))))
; d13-2
 (defvc inf-vc-fast-d13-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat (inf-lt (natminus bci7 (inf-mod 16 ed1)) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 (inf-wlit ((natminus bci7 ((inf-mod 16 ed1)))) w gw (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3)))))
; d15-1
 (defvc inf-vc-fast-d15-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat (inf-le 257 syd2)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 ((inf-ltsu 256 syd2 g5)))))
; d15-2
 (defvc inf-vc-fast-d15-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat (inf-lt (natminus syd2 257) 29)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 ((inf-lidx syd2 g6)))))
; d15-3
 (defvc inf-vc-fast-d15-3 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat (inf-lt (Le (natminus syd2 257)) 32)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 (inf-lelt ((Le ((natminus syd2 257)))) 5 32 ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) (idpath true)))))
; d15-4
 (defvc inf-vc-fast-d15-4 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat (inf-lt (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 ((inf-lelt ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-pow w) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) ((inf-lelt 258 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))))))
; d16-1
 (defvc inf-vc-fast-d16-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat (inf-lt (Le (natminus syd2 257)) 64)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 (inf-lelt ((Le ((natminus syd2 257)))) 5 64 ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) (idpath true)))))
; d17-1
 (defvc inf-vc-fast-d17-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat (inf-le (Le (natminus syd2 257)) (natminus bci7 (inf-mod 16 ed1)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 ((inf-fastb1 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) m5)))))
; d17-2
 (defvc inf-vc-fast-d17-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat (inf-lt (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 (inf-wlit ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) w gw (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3))))))
; d19-1
 (defvc inf-vc-fast-d19-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat (inf-lt (inf-mod 16 fd11) 64)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 (inf-lttrans ((inf-mod 16 fd11)) 16 64 ((inf-modlt 15 fd11)) (idpath false)))))
; d20-1
 (defvc inf-vc-fast-d20-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat (inf-le (inf-mod 16 fd11) (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5)))))
; d20-2
 (defvc inf-vc-fast-d20-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat (inf-lt (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 (inf-wlit ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) w gw (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 63 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3)))))))
; d22-1
 (defvc inf-vc-fast-d22-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat (inf-lt 4 64)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 (idpath true))))
; r2-1
 (defvc inf-vc-fast-r2-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-lt 29 syd22) (inf-le ipi7 n)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 m1)))
; r2-2
 (defvc inf-vc-fast-r2-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-lt 29 syd22) (inf-le (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) 63)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 (inf-letrans (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) 63 (inf-suble (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (inf-letrans (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (natminus bci7 (inf-mod 16 ed1)) 63 (inf-suble (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-letrans (natminus bci7 (inf-mod 16 ed1)) bci7 63 (inf-suble bci7 (inf-mod 16 ed1)) m3))))))
; r2-3
 (defvc inf-vc-fast-r2-3 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-lt 29 syd22) (inf-bits-inv carry ipi7 (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 (inf-take carry ipi7 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)) ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5)) (inf-take carry ipi7 ((add cons ((inf-mod 16 ed1)))) ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))) ((inf-fastb1 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) m5)) (inf-take carry ipi7 cons bci7 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5))) m4))))))
; r2-4
 (defvc inf-vc-fast-r2-4 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-lt 29 syd22) (inf-le cons0 (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 (inf-letrans cons0 (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (inf-letrans cons0 (add cons (inf-mod 16 ed1)) (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-letrans cons0 cons (add cons (inf-mod 16 ed1)) j5 (inf-leaddr cons (inf-mod 16 ed1))) (inf-leaddr (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257)))) (inf-leaddr (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11))))))
; r2-5
 (defvc inf-vc-fast-r2-5 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-lt 29 syd22) (inf-le op cap)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 j7)))
; r2-6
 (defvc inf-vc-fast-r2-6 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-lt 29 syd22) (inf-le op0 op)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 j6)))
; d23-1
 (defvc inf-vc-fast-d23-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) (inf-lt syd22 30)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 ((inf-lelts syd22 29 g10)))))
; d23-2
 (defvc inf-vc-fast-d23-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) (inf-lt (De syd22) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 (inf-wlit ((De syd22)) w gw (inf-letrans ((De syd22)) 13 63 ((hde syd22 ((inf-lelts syd22 29 g10)))) (idpath false))))))
; d24-1
 (defvc inf-vc-fast-d24-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) (inf-lt syd22 30)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 ((inf-lelts syd22 29 g10)))))
; d24-2
 (defvc inf-vc-fast-d24-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) (inf-lt (De syd22) 32)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 (inf-lelt ((De syd22)) 13 32 ((hde syd22 ((inf-lelts syd22 29 g10)))) (idpath true)))))
; d24-3
 (defvc inf-vc-fast-d24-3 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) (inf-lt (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 ((inf-powfit ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) h w ((inf-baseadd (Db syd22) ((De syd22)) bbd19 (inf-pow h) (hdb syd22 ((inf-lelts syd22 29 g10))))) (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))))
; d25-1
 (defvc inf-vc-fast-d25-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) (inf-lt (De syd22) 64)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 (inf-lelt ((De syd22)) 13 64 ((hde syd22 ((inf-lelts syd22 29 g10)))) (idpath true)))))
; d26-1
 (defvc inf-vc-fast-d26-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat (inf-le (De syd22) (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 ((inf-fastb3 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) ((De syd22)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) ((hde syd22 ((inf-lelts syd22 29 g10)))) m5)))))
; d26-2
 (defvc inf-vc-fast-d26-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat (inf-lt (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 (inf-wlit ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) w gw (inf-letrans ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) 63 (inf-suble ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))) (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 63 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3))))))))
; i12-1
 (defvc inf-vc-fast-i12-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-lt (add op nd) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 (inf-lelt (add op nd) (add cap nd) (inf-pow w) (inf-addr op cap nd j7) gnd))))
; r3-1
 (defvc inf-vc-fast-r3-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-lt (add op nd) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-le ipi7 n)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 m1)))
; r3-2
 (defvc inf-vc-fast-r3-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-lt (add op nd) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-le (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) 63)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 (inf-letrans ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) 63 (inf-suble ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))) (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 63 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3)))))))
; r3-3
 (defvc inf-vc-fast-r3-3 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-lt (add op nd) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-bits-inv carry ipi7 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 (inf-take carry ipi7 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)) ((inf-fastb3 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) ((De syd22)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) ((hde syd22 ((inf-lelts syd22 29 g10)))) m5)) (inf-take carry ipi7 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)) ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5)) (inf-take carry ipi7 ((add cons ((inf-mod 16 ed1)))) ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))) ((inf-fastb1 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) m5)) (inf-take carry ipi7 cons bci7 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5))) m4)))))))
; r3-4
 (defvc inf-vc-fast-r3-4 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-lt (add op nd) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-le cons0 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 (inf-letrans cons0 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((add ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) (inf-letrans cons0 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-letrans cons0 ((add cons ((inf-mod 16 ed1)))) ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1)))) (inf-leaddr ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-leaddr ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-leaddr ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))))))
; r3-5
 (defvc inf-vc-fast-r3-5 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-lt (add op nd) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-le op cap)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 j7)))
; r3-6
 (defvc inf-vc-fast-r3-6 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-lt (add op nd) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-le op0 op)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 j6)))
; s3-1
 (defvc inf-vc-fast-s3-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) (inf-lt (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 ((inf-lelt ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-pow w) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) ((inf-lelt 258 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))))))
; j8-1
 (defvc inf-vc-fast-j8-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) (inf-le op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 (inf-letrans op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (inf-ltle op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) g11) (inf-refl (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))))))
; s4-1
 (defvc inf-vc-fast-s4-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) g13 (inf-lt (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 g13 (inf-letrans op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (inf-ltle op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) g11) (inf-refl (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))))))
; s4-2
 (defvc inf-vc-fast-s4-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) g13 (inf-lt (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 g13 (inf-lelt (natminus ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) (inf-pow w) (inf-suble ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op) ((inf-powfit ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) h w ((inf-baseadd (Db syd22) ((De syd22)) bbd19 (inf-pow h) (hdb syd22 ((inf-lelts syd22 29 g10))))) (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))))
; j8j-1
 (defvc inf-vc-fast-j8j-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) g13 (inf-lt (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (paths nat (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (inf-h (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 g13 (inf-htt ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) g13))))
; j8j-2
 (defvc inf-vc-fast-j8j-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) g13 (inf-le (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (paths nat (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (inf-h (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 g13 (inf-hff ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) g13))))
 (defcx inf-fast-c6 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))) (g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd))) (ddj8 nat) (f7 (paths nat ddj8 (inf-h (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))))) )
; m6-1
 (defvc inf-vc-fast-m6-1 (under inf-fast-c6 (inf-le op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))))
   (given inf-fast-c6 (inf-letrans op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (inf-ltle op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) g11) (inf-refl (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))))))
; m6-2
 (defvc inf-vc-fast-m6-2 (under inf-fast-c6 (inf-le (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) nd))
   (given inf-fast-c6 (inf-dnowrap ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op nd g12)))
; m6-3
 (defvc inf-vc-fast-m6-3 (under inf-fast-c6 (inf-le (add op ddj8) oc))
   (given inf-fast-c6 (inf-letrans (add op ddj8) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) oc (inf-addl op ddj8 ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) ((inf-letr (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) ddj8 ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) ((pathsinv0 nat ddj8 (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) f7)) (inf-hlel ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))))))) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))))))
; m6-4
 (defvc inf-vc-fast-m6-4 (under inf-fast-c6 (inf-le (add (natminus nd (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) ddj8) nd))
   (given inf-fast-c6 (inf-letr (add (natminus nd (natminus ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op)) (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))))) (add (natminus nd (natminus ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op)) ddj8) nd (maponpaths nat nat (lam z (add (natminus nd (natminus ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op)) z)) (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) ddj8 ((pathsinv0 nat ddj8 (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) f7))) (inf-dr ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) nd g12))))
; w2e-1
 (defvc inf-vc-fast-w2e-1 (under inf-fast-c6 (inf-le ddj8 ddj8))
   (given inf-fast-c6 (inf-refl ddj8)))
 (defcx inf-fast-c6-w2 inf-fast-c6 (k nat) (a1 (inf-le ddj8 k)) )
; p2-1
 (defvc inf-vc-fast-p2-1 (under inf-fast-c6-w2 (pi w2 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (add op k) (inf-pow w))))
   (given inf-fast-c6-w2 (lam w2 (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-ltle (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w2)) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; p2-2
 (defvc inf-vc-fast-p2-2 (under inf-fast-c6-w2 (pi w2 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (add op k) oc)))
   (given inf-fast-c6-w2 (lam w2 (inf-cw op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) oc w2 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))))))))
; p2-3
 (defvc inf-vc-fast-p2-3 (under inf-fast-c6-w2 (pi w2 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op k))))
   (given inf-fast-c6-w2 (lam w2 (inf-dknowrap ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) k (inf-ltle op ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) g11) (inf-letr ddj8 (inf-h ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) k f7 a1) w2))))
; p2-4
 (defvc inf-vc-fast-p2-4 (under inf-fast-c6-w2 (pi w2 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (natminus (add op k) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) oc)))
   (given inf-fast-c6-w2 (lam w2 (inf-lelt (natminus (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (add op k) oc (inf-suble (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (inf-cw op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) oc w2 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))))))))
; w2b-1
 (defvc inf-vc-fast-w2b-1 (under inf-fast-c6-w2 (pi w2 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (succ k) (inf-pow w))))
   (given inf-fast-c6-w2 (lam w2 (inf-lelt (succ k) ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (inf-pow w) (inf-ltsu k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w2) ((inf-lelt ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-pow w) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) ((inf-lelt 258 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))))
; w2b-2
 (defvc inf-vc-fast-w2b-2 (under inf-fast-c6-w2 (pi w2 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le ddj8 (succ k))))
   (given inf-fast-c6-w2 (lam w2 (inf-letrans ddj8 k (succ k) a1 (inf-ltle k (succ k) (inf-ltself k))))))
; w2b-3
 (defvc inf-vc-fast-w2b-3 (under inf-fast-c6-w2 (pi w2 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (succ k)) (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) k))))
   (given inf-fast-c6-w2 (lam w2 (inf-subfall ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) k w2))))
; s5-1
 (defvc inf-vc-fast-s5-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (inf-lt 0 (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 (inf-wlit 0 w gw (idpath false)))))
; w3e-1
 (defvc inf-vc-fast-w3e-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) g14 (inf-le 8 (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-le 0 (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g14 (idpath false))))
 (defcx inf-fast-c2-w3 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (g14 (inf-le 8 (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))) (k nat) (a2 (inf-le k (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7))) )
; p3-1
 (defvc inf-vc-fast-p3-1 (under inf-fast-c2-w3 (pi w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (add op k) (inf-pow w))))
   (given inf-fast-c2-w3 (lam w3 (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-ltle (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3)) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; p3-2
 (defvc inf-vc-fast-p3-2 (under inf-fast-c2-w3 (pi w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add (add op k) 8) oc)))
   (given inf-fast-c2-w3 (lam w3 ((inf-letl (add (add op k) 8) cap oc (pathsinv0 nat oc cap (go gz)) (inf-fastw op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (add op k) cap (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) w1))))))
; p3-3
 (defvc inf-vc-fast-p3-3 (under inf-fast-c2-w3 (pi w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op k))))
   (given inf-fast-c2-w3 (lam w3 ((inf-letrans ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op (add op k) g11 (inf-leaddr op k))))))
; p3-4
 (defvc inf-vc-fast-p3-4 (under inf-fast-c2-w3 (pi w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add (natminus (add op k) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) 8) oc)))
   (given inf-fast-c2-w3 (lam w3 (inf-letrans (add (natminus (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) 8) (add (add op k) 8) oc (inf-addr (natminus (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (add op k) 8 (inf-suble (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))))) ((inf-letl (add (add op k) 8) cap oc (pathsinv0 nat oc cap (go gz)) (inf-fastw op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (add op k) cap (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) w1)))))))
; s6-1
 (defvc inf-vc-fast-s6-1 (under inf-fast-c2-w3 (pi w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (add k 8) (inf-pow w))))
   (given inf-fast-c2-w3 (lam w3 (inf-lelt (add k 8) 266 (inf-pow w) (inf-addr k 258 8 (inf-letrans k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-ltle k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))))) ((inf-lelt 266 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; w3b-1
 (defvc inf-vc-fast-w3b-1 (under inf-fast-c2-w3 (pi w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add k 8) (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7))))
   (given inf-fast-c2-w3 (lam w3 (inf-step8 k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w3))))
; w3b-2
 (defvc inf-vc-fast-w3b-2 (under inf-fast-c2-w3 (pi w3 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (add k 8)) (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) k))))
   (given inf-fast-c2-w3 (lam w3 (inf-subby k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 8 w3 (idpath true)))))
; w4e-1
 (defvc inf-vc-fast-w4e-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) g14 unit g15 unit (inf-le 0 (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g14 g15 (idpath false))))
 (defcx inf-fast-c2-w4 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (g14 unit) (g15 unit) (k nat) (a3 (inf-le k (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7))) )
; p4-1
 (defvc inf-vc-fast-p4-1 (under inf-fast-c2-w4 (pi w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (add op k) (inf-pow w))))
   (given inf-fast-c2-w4 (lam w4 (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-ltle (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w4)) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; p4-2
 (defvc inf-vc-fast-p4-2 (under inf-fast-c2-w4 (pi w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add (add op k) 8) oc)))
   (given inf-fast-c2-w4 (lam w4 ((inf-letl (add (add op k) 8) cap oc (pathsinv0 nat oc cap (go gz)) (inf-fastw op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (add op k) cap (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w4) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) w1))))))
; p4-3
 (defvc inf-vc-fast-p4-3 (under inf-fast-c2-w4 (pi w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)))
   (given inf-fast-c2-w4 (lam w4 g11)))
; p4-4
 (defvc inf-vc-fast-p4-4 (under inf-fast-c2-w4 (pi w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (natminus op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) oc)))
   (given inf-fast-c2-w4 (lam w4 (inf-lelt (natminus op ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) op oc (inf-suble op ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) ((inf-lttrans op cap oc ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))))))))
; s7-1
 (defvc inf-vc-fast-s7-1 (under inf-fast-c2-w4 (pi w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (add k 8) (inf-pow w))))
   (given inf-fast-c2-w4 (lam w4 (inf-lelt (add k 8) 266 (inf-pow w) (inf-addr k 258 8 (inf-letrans k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-ltle k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w4) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))))) ((inf-lelt 266 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; w4b-1
 (defvc inf-vc-fast-w4b-1 (under inf-fast-c2-w4 (pi w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add k 8) (add (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) 7))))
   (given inf-fast-c2-w4 (lam w4 (inf-step8 k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w4))))
; w4b-2
 (defvc inf-vc-fast-w4b-2 (under inf-fast-c2-w4 (pi w4 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (add k 8)) (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) k))))
   (given inf-fast-c2-w4 (lam w4 (inf-subby k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 8 w4 (idpath true)))))
; w5e-1
 (defvc inf-vc-fast-w5e-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) g14 unit g15 unit (inf-le 0 (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g14 g15 (idpath false))))
 (defcx inf-fast-c2-w5 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (g14 unit) (g15 unit) (k nat) (a4 (inf-le k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))) )
; p5-1
 (defvc inf-vc-fast-p5-1 (under inf-fast-c2-w5 (pi w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (add op k) (inf-pow w))))
   (given inf-fast-c2-w5 (lam w5 (inf-lelt (add op k) cap (inf-pow w) (inf-letrans (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-ltle (add op k) (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (inf-ltaddl op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w5)) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; p5-2
 (defvc inf-vc-fast-p5-2 (under inf-fast-c2-w5 (pi w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (add op k) oc)))
   (given inf-fast-c2-w5 (lam w5 (inf-cw op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) oc w5 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))))))))
; p5-3
 (defvc inf-vc-fast-p5-3 (under inf-fast-c2-w5 (pi w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op k))))
   (given inf-fast-c2-w5 (lam w5 ((inf-letrans ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19))) op (add op k) g11 (inf-leaddr op k))))))
; p5-4
 (defvc inf-vc-fast-p5-4 (under inf-fast-c2-w5 (pi w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (natminus (add op k) (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) oc)))
   (given inf-fast-c2-w5 (lam w5 (inf-lelt (natminus (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (add op k) oc (inf-suble (add op k) ((add (Db syd22) (inf-mod (inf-pow ((De syd22))) bbd19)))) (inf-cw op k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) oc w5 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap oc ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap))))))))))
; s8-1
 (defvc inf-vc-fast-s8-1 (under inf-fast-c2-w5 (pi w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (add k 1) (inf-pow w))))
   (given inf-fast-c2-w5 (lam w5 (inf-lelt (add k 1) ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (inf-pow w) (inf-lt1 k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w5) ((inf-lelt ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-pow w) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) ((inf-lelt 258 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))))
; w5b-1
 (defvc inf-vc-fast-w5b-1 (under inf-fast-c2-w5 (pi w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le (add k 1) (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))))
   (given inf-fast-c2-w5 (lam w5 (inf-lt1 k ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) w5))))
; w5b-2
 (defvc inf-vc-fast-w5b-2 (under inf-fast-c2-w5 (pi w5 (inf-lt k (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-lt (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (add k 1)) (natminus (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) k))))
   (given inf-fast-c2-w5 (lam w5 (inf-subfall1 ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) k w5))))
 (defcx inf-fast-c5 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (g14 unit) (kj10 nat) )
 (defcx inf-fast-c4 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) (g11 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op)) (kj9 nat) )
 (defcx inf-fast-c3 inf-fast-c2 (yd10 nat) (fd11 nat) (g9 (inf-lt 0 fd11)) (bbd12 nat) (bbd16 nat) (bbd19 nat) (syd22 nat) (g10 (inf-le syd22 29)) (bbd25 nat) )
; s9-1
 (defvc inf-vc-fast-s9-1 (under inf-fast-c3 (inf-lt (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-pow w)))
   (given inf-fast-c3 ((inf-lelt (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) cap (inf-pow w) ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; w1b-8
 (defvc inf-vc-fast-w1b-8 (under inf-fast-c3 (inf-le ipi7 n))
   (given inf-fast-c3 m1))
; w1b-9
 (defvc inf-vc-fast-w1b-9 (under inf-fast-c3 (inf-le (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) 63))
   (given inf-fast-c3 (inf-letrans ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) 63 (inf-suble ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))) (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 63 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 63 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 63 (inf-suble bci7 ((inf-mod 16 ed1))) m3))))))
; w1b-10
 (defvc inf-vc-fast-w1b-10 (under inf-fast-c3 (inf-bits-inv carry ipi7 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22))))
   (given inf-fast-c3 (inf-take carry ipi7 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)) ((inf-fastb3 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) ((De syd22)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) ((hde syd22 ((inf-lelts syd22 29 g10)))) m5)) (inf-take carry ipi7 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)) ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5)) (inf-take carry ipi7 ((add cons ((inf-mod 16 ed1)))) ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))) ((inf-fastb1 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) m5)) (inf-take carry ipi7 cons bci7 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5))) m4))))))
; w1b-11
 (defvc inf-vc-fast-w1b-11 (under inf-fast-c3 (inf-le cons0 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22))))
   (given inf-fast-c3 (inf-letrans cons0 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((add ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) (inf-letrans cons0 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-letrans cons0 ((add cons ((inf-mod 16 ed1)))) ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1)))) (inf-leaddr ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-leaddr ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-leaddr ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))))))
; w1b-12
 (defvc inf-vc-fast-w1b-12 (under inf-fast-c3 (inf-le op0 (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))))
   (given inf-fast-c3 (inf-letrans op0 op (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) j6 (inf-leaddr op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))))))
; w1b-13
 (defvc inf-vc-fast-w1b-13 (under inf-fast-c3 (inf-le (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) cap))
   (given inf-fast-c3 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))))
; w1b-14
 (defvc inf-vc-fast-w1b-14 (under inf-fast-c3 (inf-lt (natminus cap (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))) (natminus cap op)))
   (given inf-fast-c3 (inf-subby op cap ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1)) ((inf-lttrans 0 3 ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (idpath true) (inf-letrans 3 (Lb ((natminus syd2 257))) ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (hlc ((natminus syd2 257)) ((inf-lidx syd2 g6))) (inf-leaddr (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))))))))
; r4-31
 (defvc inf-vc-fast-r4-31 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le ip n)))
   (given inf-fast-w1 (lam w1 j1)))
; r4-32
 (defvc inf-vc-fast-r4-32 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le bc 63)))
   (given inf-fast-w1 (lam w1 j3)))
; r4-33
 (defvc inf-vc-fast-r4-33 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-bits-inv carry ip cons bc)))
   (given inf-fast-w1 (lam w1 j4)))
; r4-34
 (defvc inf-vc-fast-r4-34 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le cons0 cons)))
   (given inf-fast-w1 (lam w1 j5)))
; r4-35
 (defvc inf-vc-fast-r4-35 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le op cap)))
   (given inf-fast-w1 (lam w1 j7)))
; r4-36
 (defvc inf-vc-fast-r4-36 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le op0 op)))
   (given inf-fast-w1 (lam w1 j6)))
 (defcx inf-block (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gcf (inf-lt (add cap 266) (inf-pow w))) (Lc (pi k nat nat)) (Ls (pi k nat nat)) (Lt (pi k nat nat)) (Dc (pi k nat nat)) (Ds (pi k nat nat)) (Dt (pi k nat nat)) (lm nat) (dm nat) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (h nat) (LROOT nat) (DROOT nat) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16)) (c1 (pi k nat (inf-lt (Lc k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc 15 1) lm)) (c4 (inf-le lm 288)) (c5 (pi k nat (inf-lt (Dc k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc 15 1) dm)) (c8 (inf-le dm 32)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) )
; w1e-1
 (defvc inf-vc-block-w1e-1 (under inf-block (inf-le ip0 n))
   (given inf-block gi))
; w1e-2
 (defvc inf-vc-block-w1e-2 (under inf-block (inf-le bc0 63))
   (given inf-block gs))
; w1e-3
 (defvc inf-vc-block-w1e-3 (under inf-block (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-block ga))
; w1e-4
 (defvc inf-vc-block-w1e-4 (under inf-block (inf-le cons0 cons0))
   (given inf-block (inf-refl cons0)))
; w1e-5
 (defvc inf-vc-block-w1e-5 (under inf-block (inf-le op0 op0))
   (given inf-block (inf-refl op0)))
; w1e-6
 (defvc inf-vc-block-w1e-6 (under inf-block (inf-le op0 cap))
   (given inf-block gop))
 (defcx inf-block-w1 inf-block (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (j1 (inf-le ip n)) (j3 (inf-le bc 63)) (j4 (inf-bits-inv carry ip cons bc)) (j5 (inf-le cons0 cons)) (j6 (inf-le op0 op)) (j7 (inf-le op cap)) )
; i2-1
 (defvc inf-vc-block-i2-1 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) (inf-lt (add ip 8) (inf-pow w))))
   (given inf-block-w1 (lam w1 o0 eo g1 (inf-lelt (add ip 8) (add n 8) (inf-pow w) (inf-addr ip n 8 j1) gn))))
; i3-1
 (defvc inf-vc-block-i3-1 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) (inf-lt (add op 266) (inf-pow w))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 (inf-lelt (add op 266) (add cap 266) (inf-pow w) (inf-addr op cap 266 j7) gcf))))
; t1-1
 (defvc inf-vc-block-t1-1 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le 32 w)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gw)))
; t1-2
 (defvc inf-vc-block-t1-2 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add n 8) (inf-pow w))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gn)))
; t1-3
 (defvc inf-vc-block-t1-3 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j1)))
; t1-4
 (defvc inf-vc-block-t1-4 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le bc 63)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j3)))
; t1-5
 (defvc inf-vc-block-t1-5 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-bits-inv carry ip cons bc)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j4)))
; t1-6
 (defvc inf-vc-block-t1-6 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 go)))
; t1-7
 (defvc inf-vc-block-t1-7 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add cap 8) (inf-pow w))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gcap)))
; t1-8
 (defvc inf-vc-block-t1-8 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le op cap)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j7)))
; t1-9
 (defvc inf-vc-block-t1-9 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add cap nd) (inf-pow w))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gnd)))
; t1-10
 (defvc inf-vc-block-t1-10 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add cap 266) (inf-pow w))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gcf)))
; t1-11
 (defvc inf-vc-block-t1-11 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le LROOT 15)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gl)))
; t1-12
 (defvc inf-vc-block-t1-12 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le DROOT 15)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gd)))
; t1-13
 (defvc inf-vc-block-t1-13 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le h 16)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gh)))
; t1-14
 (defvc inf-vc-block-t1-14 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt 0 out)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 g1)))
; t1-15
 (defvc inf-vc-block-t1-15 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hle)))
; t1-16
 (defvc inf-vc-block-t1-16 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hlb)))
; t1-17
 (defvc inf-vc-block-t1-17 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hlc)))
; t1-18
 (defvc inf-vc-block-t1-18 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 30) (inf-le (De k) 13))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hde)))
; t1-19
 (defvc inf-vc-block-t1-19 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hdb)))
 (defcx inf-block-c9 inf-block-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (g1 (inf-lt 0 out)) (g2 (inf-le (add ip 8) n)) (g3 (inf-le (add op 266) cap)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (opt1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e8 (inf-le opt1 cap)) (t1e9 (inf-le op opt1)) )
; r6-1
 (defvc inf-vc-block-r6-1 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le ipt1 n)))
   (given inf-block-c9 (lam g4 t1e1)))
; r6-2
 (defvc inf-vc-block-r6-2 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le bct1 63)))
   (given inf-block-c9 (lam g4 t1e3)))
; r6-3
 (defvc inf-vc-block-r6-3 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-block-c9 (lam g4 t1e4)))
; r6-4
 (defvc inf-vc-block-r6-4 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le cons0 const1)))
   (given inf-block-c9 (lam g4 (inf-letrans cons0 cons const1 j5 t1e5))))
; r6-5
 (defvc inf-vc-block-r6-5 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le opt1 cap)))
   (given inf-block-c9 (lam g4 t1e8)))
; r6-6
 (defvc inf-vc-block-r6-6 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le op0 opt1)))
   (given inf-block-c9 (lam g4 (inf-letrans op0 op opt1 j6 t1e9))))
; i1j-1
 (defvc inf-vc-block-i1j-1 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le ipt1 n)))
   (given inf-block-c9 (lam g4 t1e1)))
; i1j-2
 (defvc inf-vc-block-i1j-2 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le bct1 63)))
   (given inf-block-c9 (lam g4 t1e3)))
; i1j-3
 (defvc inf-vc-block-i1j-3 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-block-c9 (lam g4 t1e4)))
; i1j-4
 (defvc inf-vc-block-i1j-4 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le cons0 const1)))
   (given inf-block-c9 (lam g4 (inf-letrans cons0 cons const1 j5 t1e5))))
; i1j-5
 (defvc inf-vc-block-i1j-5 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le o0 opt1)))
   (given inf-block-c9 (lam g4 (inf-letrans o0 op opt1 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))) t1e9))))
; i1j-6
 (defvc inf-vc-block-i1j-6 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le opt1 cap)))
   (given inf-block-c9 (lam g4 t1e8)))
; i1j-7
 (defvc inf-vc-block-i1j-7 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j1)))
; i1j-8
 (defvc inf-vc-block-i1j-8 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le bc 63)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j3)))
; i1j-9
 (defvc inf-vc-block-i1j-9 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-bits-inv carry ip cons bc)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j4)))
; i1j-10
 (defvc inf-vc-block-i1j-10 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le cons0 cons)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j5)))
; i1j-11
 (defvc inf-vc-block-i1j-11 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le o0 op)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))))))
; i1j-12
 (defvc inf-vc-block-i1j-12 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le op cap)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j7)))
; i1j-13
 (defvc inf-vc-block-i1j-13 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j1)))
; i1j-14
 (defvc inf-vc-block-i1j-14 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le bc 63)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j3)))
; i1j-15
 (defvc inf-vc-block-i1j-15 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-bits-inv carry ip cons bc)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j4)))
; i1j-16
 (defvc inf-vc-block-i1j-16 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le cons0 cons)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j5)))
; i1j-17
 (defvc inf-vc-block-i1j-17 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le o0 op)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))))))
; i1j-18
 (defvc inf-vc-block-i1j-18 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le op cap)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j7)))
; i1j-19
 (defvc inf-vc-block-i1j-19 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 j1)))
; i1j-20
 (defvc inf-vc-block-i1j-20 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le bc 63)))
   (given inf-block-w1 (lam w1 o0 eo g1 j3)))
; i1j-21
 (defvc inf-vc-block-i1j-21 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-bits-inv carry ip cons bc)))
   (given inf-block-w1 (lam w1 o0 eo g1 j4)))
; i1j-22
 (defvc inf-vc-block-i1j-22 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le cons0 cons)))
   (given inf-block-w1 (lam w1 o0 eo g1 j5)))
; i1j-23
 (defvc inf-vc-block-i1j-23 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le o0 op)))
   (given inf-block-w1 (lam w1 o0 eo g1 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))))))
; i1j-24
 (defvc inf-vc-block-i1j-24 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le op cap)))
   (given inf-block-w1 (lam w1 o0 eo g1 j7)))
 (defcx inf-block-c1 inf-block-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (ipi1 nat) (bci1 nat) (bbi1 nat) (consi1 nat) (opi1 nat) (k1 (inf-le ipi1 n)) (k3 (inf-le bci1 63)) (k4 (inf-bits-inv carry ipi1 consi1 bci1)) (k5 (inf-le cons0 consi1)) (k6 (inf-le o0 opi1)) (k7 (inf-le opi1 cap)) )
; t2-1
 (defvc inf-vc-block-t2-1 (under inf-block-c1 (inf-le 32 w))
   (given inf-block-c1 gw))
; t2-2
 (defvc inf-vc-block-t2-2 (under inf-block-c1 (inf-lt (add n 8) (inf-pow w)))
   (given inf-block-c1 gn))
; t2-3
 (defvc inf-vc-block-t2-3 (under inf-block-c1 (inf-le ipi1 n))
   (given inf-block-c1 k1))
; t2-4
 (defvc inf-vc-block-t2-4 (under inf-block-c1 (inf-le bci1 63))
   (given inf-block-c1 k3))
; t2-5
 (defvc inf-vc-block-t2-5 (under inf-block-c1 (inf-bits-inv carry ipi1 consi1 bci1))
   (given inf-block-c1 k4))
; t2-6
 (defvc inf-vc-block-t2-6 (under inf-block-c1 (pi i nat (inf-lt (Lc i) (inf-pow h))))
   (given inf-block-c1 c1))
; t2-7
 (defvc inf-vc-block-t2-7 (under inf-block-c1 (pi i nat (inf-lt (Ls i) (inf-pow h))))
   (given inf-block-c1 c2))
; t2-8
 (defvc inf-vc-block-t2-8 (under inf-block-c1 (inf-le h 16))
   (given inf-block-c1 gh))
; t2-9
 (defvc inf-vc-block-t2-9 (under inf-block-c1 (inf-lt lm (inf-pow w)))
   (given inf-block-c1 (inf-lelt lm 288 (inf-pow w) c4 (inf-wfit288 w gw))))
; t2-10
 (defvc inf-vc-block-t2-10 (under inf-block-c1 (inf-le (inf-sum Lc 15 1) lm))
   (given inf-block-c1 c3))
; t2-11
 (defvc inf-vc-block-t2-11 (under inf-block-c1 (inf-le LROOT 15))
   (given inf-block-c1 gl))
 (defcx inf-block-c2 inf-block-c1 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (syt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le consi1 const2)) )
; p1-1
 (defvc inf-vc-block-p1-1 (under inf-block-c2 (pi g5 (inf-lt syt2 256) g6 (inf-lt opi1 cap) g7 (inf-lt 0 out) (inf-lt opi1 oc)))
   (given inf-block-c2 (lam g5 g6 g7 (inf-lttrans opi1 cap oc g6 (inf-letl cap cap oc (pathsinv0 nat oc cap (go g7)) (inf-refl cap))))))
; p1-2
 (defvc inf-vc-block-p1-2 (under inf-block-c2 (pi g5 (inf-lt syt2 256) g6 (inf-lt opi1 cap) g7 (inf-lt 0 out) (inf-lt syt2 256)))
   (given inf-block-c2 (lam g5 g6 g7 g5)))
 (defcx inf-block-c8 inf-block-c2 (g5 (inf-lt syt2 256)) (g6 (inf-lt opi1 cap)) )
; s1-1
 (defvc inf-vc-block-s1-1 (under inf-block-c8 (inf-lt (add opi1 1) (inf-pow w)))
   (given inf-block-c8 (inf-lelt (add opi1 1) cap (inf-pow w) (inf-lt1 opi1 cap g6) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))
; w1b-1
 (defvc inf-vc-block-w1b-1 (under inf-block-c8 (inf-le ipt2 n))
   (given inf-block-c8 t2e1))
; w1b-2
 (defvc inf-vc-block-w1b-2 (under inf-block-c8 (inf-le bct2 63))
   (given inf-block-c8 t2e3))
; w1b-3
 (defvc inf-vc-block-w1b-3 (under inf-block-c8 (inf-bits-inv carry ipt2 const2 bct2))
   (given inf-block-c8 t2e4))
; w1b-4
 (defvc inf-vc-block-w1b-4 (under inf-block-c8 (inf-le cons0 const2))
   (given inf-block-c8 (inf-letrans cons0 consi1 const2 k5 t2e5)))
; w1b-5
 (defvc inf-vc-block-w1b-5 (under inf-block-c8 (inf-le op0 (add opi1 1)))
   (given inf-block-c8 (inf-letrans op0 opi1 (add opi1 1) ((inf-letrans op0 op opi1 j6 ((inf-letr o0 op opi1 eo k6)))) (inf-leaddr opi1 1))))
; w1b-6
 (defvc inf-vc-block-w1b-6 (under inf-block-c8 (inf-le (add opi1 1) cap))
   (given inf-block-c8 (inf-lt1 opi1 cap g6)))
; w1b-7
 (defvc inf-vc-block-w1b-7 (under inf-block-c8 (inf-lt (natminus cap (add opi1 1)) (natminus cap op)))
   (given inf-block-c8 (inf-subfrom op opi1 cap 1 ((inf-letr o0 op opi1 eo k6)) g6 (idpath true))))
; r6-7
 (defvc inf-vc-block-r6-7 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le ipt2 n)))
   (given inf-block-c2 (lam g5 g8 t2e1)))
; r6-8
 (defvc inf-vc-block-r6-8 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le bct2 63)))
   (given inf-block-c2 (lam g5 g8 t2e3)))
; r6-9
 (defvc inf-vc-block-r6-9 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-block-c2 (lam g5 g8 t2e4)))
; r6-10
 (defvc inf-vc-block-r6-10 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le cons0 const2)))
   (given inf-block-c2 (lam g5 g8 (inf-letrans cons0 consi1 const2 k5 t2e5))))
; r6-11
 (defvc inf-vc-block-r6-11 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le opi1 cap)))
   (given inf-block-c2 (lam g5 g8 k7)))
; r6-12
 (defvc inf-vc-block-r6-12 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le op0 opi1)))
   (given inf-block-c2 (lam g5 g8 ((inf-letrans op0 op opi1 j6 ((inf-letr o0 op opi1 eo k6)))))))
; s2-1
 (defvc inf-vc-block-s2-1 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-le 257 syt2)))
   (given inf-block-c2 (lam g5 g8 g9 (inf-ltsu 256 syt2 g8))))
; s2-2
 (defvc inf-vc-block-s2-2 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-lt (natminus syt2 257) 29)))
   (given inf-block-c2 (lam g5 g8 g9 ((inf-lidx syt2 g9)))))
; s2-3
 (defvc inf-vc-block-s2-3 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-lt (Lb (natminus syt2 257)) (inf-pow w))))
   (given inf-block-c2 (lam g5 g8 g9 (inf-lelt (Lb ((natminus syt2 257))) 259 (inf-pow w) (inf-letrans (Lb ((natminus syt2 257))) (add (Lb ((natminus syt2 257))) (inf-pow ((Le ((natminus syt2 257)))))) 259 (inf-leaddr (Lb ((natminus syt2 257))) (inf-pow ((Le ((natminus syt2 257)))))) ((hlb ((natminus syt2 257)) ((inf-lidx syt2 g9))))) (inf-lelt 259 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))))
; t3-1
 (defvc inf-vc-block-t3-1 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-le 32 w)))
   (given inf-block-c2 (lam g5 g8 g9 gw)))
; t3-2
 (defvc inf-vc-block-t3-2 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-lt (add n 8) (inf-pow w))))
   (given inf-block-c2 (lam g5 g8 g9 gn)))
; t3-3
 (defvc inf-vc-block-t3-3 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-le ipt2 n)))
   (given inf-block-c2 (lam g5 g8 g9 t2e1)))
; t3-4
 (defvc inf-vc-block-t3-4 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-le bct2 63)))
   (given inf-block-c2 (lam g5 g8 g9 t2e3)))
; t3-5
 (defvc inf-vc-block-t3-5 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-block-c2 (lam g5 g8 g9 t2e4)))
; t3-6
 (defvc inf-vc-block-t3-6 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-le (Le (natminus syt2 257)) 13)))
   (given inf-block-c2 (lam g5 g8 g9 (inf-letrans ((Le ((natminus syt2 257)))) 5 13 (hle ((natminus syt2 257)) ((inf-lidx syt2 g9))) (idpath false)))))
 (defcx inf-block-c3 inf-block-c2 (g5 (inf-le 256 syt2)) (g8 (inf-lt 256 syt2)) (g9 (inf-le syt2 285)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e6 (inf-le (add const2 (Le (natminus syt2 257))) const3)) (t3e7 (inf-lt xt3 (inf-pow (Le (natminus syt2 257))))) )
; s3-1
 (defvc inf-vc-block-s3-1 (under inf-block-c3 (inf-lt (add (Lb (natminus syt2 257)) xt3) (inf-pow w)))
   (given inf-block-c3 (inf-lttrans ((add (Lb ((natminus syt2 257))) xt3)) 259 (inf-pow w) ((inf-basele (Lb ((natminus syt2 257))) ((Le ((natminus syt2 257)))) xt3 259 t3e7 ((hlb ((natminus syt2 257)) ((inf-lidx syt2 g9)))))) (inf-ltle 259 (inf-pow w) (inf-lelt 259 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))))
; t4-1
 (defvc inf-vc-block-t4-1 (under inf-block-c3 (inf-le 32 w))
   (given inf-block-c3 gw))
; t4-2
 (defvc inf-vc-block-t4-2 (under inf-block-c3 (inf-lt (add n 8) (inf-pow w)))
   (given inf-block-c3 gn))
; t4-3
 (defvc inf-vc-block-t4-3 (under inf-block-c3 (inf-le ipt3 n))
   (given inf-block-c3 t3e1))
; t4-4
 (defvc inf-vc-block-t4-4 (under inf-block-c3 (inf-le bct3 63))
   (given inf-block-c3 t3e3))
; t4-5
 (defvc inf-vc-block-t4-5 (under inf-block-c3 (inf-bits-inv carry ipt3 const3 bct3))
   (given inf-block-c3 t3e4))
; t4-6
 (defvc inf-vc-block-t4-6 (under inf-block-c3 (pi i nat (inf-lt (Dc i) (inf-pow h))))
   (given inf-block-c3 c5))
; t4-7
 (defvc inf-vc-block-t4-7 (under inf-block-c3 (pi i nat (inf-lt (Ds i) (inf-pow h))))
   (given inf-block-c3 c6))
; t4-8
 (defvc inf-vc-block-t4-8 (under inf-block-c3 (inf-le h 16))
   (given inf-block-c3 gh))
; t4-9
 (defvc inf-vc-block-t4-9 (under inf-block-c3 (inf-lt dm (inf-pow w)))
   (given inf-block-c3 (inf-wlit dm w gw (inf-letrans dm 32 63 c8 (idpath false)))))
; t4-10
 (defvc inf-vc-block-t4-10 (under inf-block-c3 (inf-le (inf-sum Dc 15 1) dm))
   (given inf-block-c3 c7))
; t4-11
 (defvc inf-vc-block-t4-11 (under inf-block-c3 (inf-le DROOT 15))
   (given inf-block-c3 gd))
 (defcx inf-block-c4 inf-block-c3 (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (sdt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le const3 const4)) )
; s4-1
 (defvc inf-vc-block-s4-1 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-lt sdt4 30)))
   (given inf-block-c4 (lam g10 ((inf-lelts sdt4 29 g10)))))
; s4-2
 (defvc inf-vc-block-s4-2 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-lt (Db sdt4) (inf-pow w))))
   (given inf-block-c4 (lam g10 (inf-lttrans (Db sdt4) (inf-pow h) (inf-pow w) (inf-lttrans (Db sdt4) (add (Db sdt4) (inf-pow ((De sdt4)))) (inf-pow h) (inf-ltaddpos (Db sdt4) (inf-pow ((De sdt4))) (inf-powpos ((De sdt4)))) (hdb sdt4 ((inf-lelts sdt4 29 g10)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))))
; t5-1
 (defvc inf-vc-block-t5-1 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-le 32 w)))
   (given inf-block-c4 (lam g10 gw)))
; t5-2
 (defvc inf-vc-block-t5-2 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-lt (add n 8) (inf-pow w))))
   (given inf-block-c4 (lam g10 gn)))
; t5-3
 (defvc inf-vc-block-t5-3 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-le ipt4 n)))
   (given inf-block-c4 (lam g10 t4e1)))
; t5-4
 (defvc inf-vc-block-t5-4 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-le bct4 63)))
   (given inf-block-c4 (lam g10 t4e3)))
; t5-5
 (defvc inf-vc-block-t5-5 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-bits-inv carry ipt4 const4 bct4)))
   (given inf-block-c4 (lam g10 t4e4)))
; t5-6
 (defvc inf-vc-block-t5-6 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-le (De sdt4) 13)))
   (given inf-block-c4 (lam g10 (hde sdt4 ((inf-lelts sdt4 29 g10))))))
 (defcx inf-block-c5 inf-block-c4 (g10 (inf-le sdt4 29)) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (yt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv carry ipt5 const5 bct5)) (t5e5 (inf-le const4 const5)) (t5e6 (inf-le (add const4 (De sdt4)) const5)) (t5e7 (inf-lt yt5 (inf-pow (De sdt4)))) )
; s5-1
 (defvc inf-vc-block-s5-1 (under inf-block-c5 (inf-lt (add (Db sdt4) yt5) (inf-pow w)))
   (given inf-block-c5 ((inf-lttrans ((add (Db sdt4) yt5)) (inf-pow h) (inf-pow w) (inf-basele (Db sdt4) ((De sdt4)) yt5 (inf-pow h) t5e7 (hdb sdt4 ((inf-lelts sdt4 29 g10)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))))
; i11-1
 (defvc inf-vc-block-i11-1 (under inf-block-c5 (inf-lt (add opi1 nd) (inf-pow w)))
   (given inf-block-c5 (inf-lelt (add opi1 nd) (add cap nd) (inf-pow w) (inf-addr opi1 cap nd k7) gnd)))
; i12-1
 (defvc inf-vc-block-i12-1 (under inf-block-c5 (pi g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)) (inf-le opi1 cap)))
   (given inf-block-c5 (lam g11 k7)))
; c1-1
 (defvc inf-vc-block-c1-1 (under inf-block-c5 (pi g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)) g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1)) g13 (inf-lt 0 out) (inf-le 32 w)))
   (given inf-block-c5 (lam g11 g12 g13 gw)))
; c1-2
 (defvc inf-vc-block-c1-2 (under inf-block-c5 (pi g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)) g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1)) g13 (inf-lt 0 out) (inf-lt (add (Db sdt4) yt5) (inf-pow w))))
   (given inf-block-c5 (lam g11 g12 g13 ((inf-lttrans ((add (Db sdt4) yt5)) (inf-pow h) (inf-pow w) (inf-basele (Db sdt4) ((De sdt4)) yt5 (inf-pow h) t5e7 (hdb sdt4 ((inf-lelts sdt4 29 g10)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))))))
; c1-3
 (defvc inf-vc-block-c1-3 (under inf-block-c5 (pi g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)) g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1)) g13 (inf-lt 0 out) (inf-le (add (Db sdt4) yt5) (add opi1 nd))))
   (given inf-block-c5 (lam g11 g12 g13 g11)))
; c1-4
 (defvc inf-vc-block-c1-4 (under inf-block-c5 (pi g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)) g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1)) g13 (inf-lt 0 out) (inf-le (add opi1 (add (Lb (natminus syt2 257)) xt3)) cap)))
   (given inf-block-c5 (lam g11 g12 g13 ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7)))))
; c1-5
 (defvc inf-vc-block-c1-5 (under inf-block-c5 (pi g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)) g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1)) g13 (inf-lt 0 out) (inf-lt 0 out)))
   (given inf-block-c5 (lam g11 g12 g13 g13)))
; c1-6
 (defvc inf-vc-block-c1-6 (under inf-block-c5 (pi g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)) g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1)) g13 (inf-lt 0 out) (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-block-c5 (lam g11 g12 g13 go)))
; c1-7
 (defvc inf-vc-block-c1-7 (under inf-block-c5 (pi g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd)) g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1)) g13 (inf-lt 0 out) (inf-lt (add cap 8) (inf-pow w))))
   (given inf-block-c5 (lam g11 g12 g13 gcap)))
 (defcx inf-block-c7 inf-block-c5 (g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd))) (g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1))) (g13 (inf-lt 0 out)) )
 (defcx inf-block-c6 inf-block-c5 (g11 (inf-le (add (Db sdt4) yt5) (add opi1 nd))) (g12 (inf-le (add (Lb (natminus syt2 257)) xt3) (natminus cap opi1))) )
; s6-1
 (defvc inf-vc-block-s6-1 (under inf-block-c6 (inf-lt (add opi1 (add (Lb (natminus syt2 257)) xt3)) (inf-pow w)))
   (given inf-block-c6 (inf-lelt (add opi1 ((add (Lb ((natminus syt2 257))) xt3))) cap (inf-pow w) ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))
; w1b-8
 (defvc inf-vc-block-w1b-8 (under inf-block-c6 (inf-le ipt5 n))
   (given inf-block-c6 t5e1))
; w1b-9
 (defvc inf-vc-block-w1b-9 (under inf-block-c6 (inf-le bct5 63))
   (given inf-block-c6 t5e3))
; w1b-10
 (defvc inf-vc-block-w1b-10 (under inf-block-c6 (inf-bits-inv carry ipt5 const5 bct5))
   (given inf-block-c6 t5e4))
; w1b-11
 (defvc inf-vc-block-w1b-11 (under inf-block-c6 (inf-le cons0 const5))
   (given inf-block-c6 (inf-letrans cons0 const4 const5 (inf-letrans cons0 const3 const4 (inf-letrans cons0 const2 const3 (inf-letrans cons0 consi1 const2 k5 t2e5) t3e5) t4e5) t5e5)))
; w1b-12
 (defvc inf-vc-block-w1b-12 (under inf-block-c6 (inf-le op0 (add opi1 (add (Lb (natminus syt2 257)) xt3))))
   (given inf-block-c6 (inf-letrans op0 opi1 (add opi1 ((add (Lb ((natminus syt2 257))) xt3))) ((inf-letrans op0 op opi1 j6 ((inf-letr o0 op opi1 eo k6)))) (inf-leaddr opi1 ((add (Lb ((natminus syt2 257))) xt3))))))
; w1b-13
 (defvc inf-vc-block-w1b-13 (under inf-block-c6 (inf-le (add opi1 (add (Lb (natminus syt2 257)) xt3)) cap))
   (given inf-block-c6 ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7))))
; w1b-14
 (defvc inf-vc-block-w1b-14 (under inf-block-c6 (inf-lt (natminus cap (add opi1 (add (Lb (natminus syt2 257)) xt3))) (natminus cap op)))
   (given inf-block-c6 (inf-subfrom op opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) ((inf-letr o0 op opi1 eo k6)) ((inf-lttrans opi1 (add opi1 ((add (Lb ((natminus syt2 257))) xt3))) cap (inf-ltaddpos opi1 ((add (Lb ((natminus syt2 257))) xt3)) ((inf-lttrans 0 3 ((add (Lb ((natminus syt2 257))) xt3)) (idpath true) (inf-letrans 3 (Lb ((natminus syt2 257))) ((add (Lb ((natminus syt2 257))) xt3)) (hlc ((natminus syt2 257)) ((inf-lidx syt2 g9))) (inf-leaddr (Lb ((natminus syt2 257))) xt3))))) ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7)))) ((inf-lttrans 0 3 ((add (Lb ((natminus syt2 257))) xt3)) (idpath true) (inf-letrans 3 (Lb ((natminus syt2 257))) ((add (Lb ((natminus syt2 257))) xt3)) (hlc ((natminus syt2 257)) ((inf-lidx syt2 g9))) (inf-leaddr (Lb ((natminus syt2 257))) xt3)))))))
 (defcx inf-go (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv 0 ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (gcf (inf-lt (add cap 266) (inf-pow w))) (Ob (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) )
; w1e-1
 (defvc inf-vc-go-w1e-1 (under inf-go (inf-le ip0 n))
   (given inf-go gi))
; w1e-2
 (defvc inf-vc-go-w1e-2 (under inf-go (inf-le bc0 63))
   (given inf-go gs))
; w1e-3
 (defvc inf-vc-go-w1e-3 (under inf-go (inf-bits-inv 0 ip0 cons0 bc0))
   (given inf-go ga))
; w1e-4
 (defvc inf-vc-go-w1e-4 (under inf-go (inf-le op0 cap))
   (given inf-go gop))
 (defcx inf-go-w1 inf-go (last nat) (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (Lc (pi j nat nat)) (Ls (pi j nat nat)) (Lt (pi j nat nat)) (Dc (pi j nat nat)) (Ds (pi j nat nat)) (Dt (pi j nat nat)) (lm nat) (dm nat) (j1 (inf-le ip n)) (j3 (inf-le bc 63)) (j4 (inf-bits-inv 0 ip cons bc)) (j7 (inf-le op cap)) )
; t1-1
 (defvc inf-vc-go-t1-1 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-le 32 w)))
   (given inf-go-w1 (lam w1 c0 ec gw)))
; t1-2
 (defvc inf-vc-go-t1-2 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-lt (add n 8) (inf-pow w))))
   (given inf-go-w1 (lam w1 c0 ec gn)))
; t1-3
 (defvc inf-vc-go-t1-3 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-le ip n)))
   (given inf-go-w1 (lam w1 c0 ec j1)))
; t1-4
 (defvc inf-vc-go-t1-4 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-le bc 63)))
   (given inf-go-w1 (lam w1 c0 ec j3)))
; t1-5
 (defvc inf-vc-go-t1-5 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-bits-inv 0 ip cons bc)))
   (given inf-go-w1 (lam w1 c0 ec j4)))
; t1-6
 (defvc inf-vc-go-t1-6 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-le 1 13)))
   (given inf-go-w1 (lam w1 c0 ec (idpath false))))
 (defcx inf-go-c1 inf-go-w1 (w1 (paths nat last 0)) (c0 nat) (ec (paths nat c0 cons)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (lastt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv 0 ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e6 (inf-le (add cons 1) const1)) (t1e7 (inf-lt lastt1 (inf-pow 1))) )
; t2-1
 (defvc inf-vc-go-t2-1 (under inf-go-c1 (inf-le 32 w))
   (given inf-go-c1 gw))
; t2-2
 (defvc inf-vc-go-t2-2 (under inf-go-c1 (inf-lt (add n 8) (inf-pow w)))
   (given inf-go-c1 gn))
; t2-3
 (defvc inf-vc-go-t2-3 (under inf-go-c1 (inf-le ipt1 n))
   (given inf-go-c1 t1e1))
; t2-4
 (defvc inf-vc-go-t2-4 (under inf-go-c1 (inf-le bct1 63))
   (given inf-go-c1 t1e3))
; t2-5
 (defvc inf-vc-go-t2-5 (under inf-go-c1 (inf-bits-inv 0 ipt1 const1 bct1))
   (given inf-go-c1 t1e4))
; t2-6
 (defvc inf-vc-go-t2-6 (under inf-go-c1 (inf-le 2 13))
   (given inf-go-c1 (idpath false)))
 (defcx inf-go-c2 inf-go-c1 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (typt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv 0 ipt2 const2 bct2)) (t2e5 (inf-le const1 const2)) (t2e6 (inf-le (add const1 2) const2)) (t2e7 (inf-lt typt2 (inf-pow 2))) )
; t3-1
 (defvc inf-vc-go-t3-1 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-le 32 w)))
   (given inf-go-c2 (lam g1 gw)))
; t3-2
 (defvc inf-vc-go-t3-2 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-lt (add n 8) (inf-pow w))))
   (given inf-go-c2 (lam g1 gn)))
; t3-3
 (defvc inf-vc-go-t3-3 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-le ipt2 n)))
   (given inf-go-c2 (lam g1 t2e1)))
; t3-4
 (defvc inf-vc-go-t3-4 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-le bct2 63)))
   (given inf-go-c2 (lam g1 t2e3)))
; t3-5
 (defvc inf-vc-go-t3-5 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-bits-inv 0 ipt2 const2 bct2)))
   (given inf-go-c2 (lam g1 t2e4)))
; t3-6
 (defvc inf-vc-go-t3-6 (under inf-go-c2 (pi g1 (paths nat typt2 0) (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-go-c2 (lam g1 go)))
; t3-7
 (defvc inf-vc-go-t3-7 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-lt (add cap 8) (inf-pow w))))
   (given inf-go-c2 (lam g1 gcap)))
; t3-8
 (defvc inf-vc-go-t3-8 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-le op cap)))
   (given inf-go-c2 (lam g1 j7)))
; t3-9
 (defvc inf-vc-go-t3-9 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-lt (add cap nd) (inf-pow w))))
   (given inf-go-c2 (lam g1 gnd)))
 (defcx inf-go-c7 inf-go-c2 (g1 (paths nat typt2 0)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (opt3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv 0 ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e8 (inf-le opt3 cap)) (t3e9 (inf-le op opt3)) )
; w1b-1
 (defvc inf-vc-go-w1b-1 (under inf-go-c7 (inf-le ipt3 n))
   (given inf-go-c7 t3e1))
; w1b-2
 (defvc inf-vc-go-w1b-2 (under inf-go-c7 (inf-le bct3 63))
   (given inf-go-c7 t3e3))
; w1b-3
 (defvc inf-vc-go-w1b-3 (under inf-go-c7 (inf-bits-inv 0 ipt3 const3 bct3))
   (given inf-go-c7 t3e4))
; w1b-4
 (defvc inf-vc-go-w1b-4 (under inf-go-c7 (inf-le opt3 cap))
   (given inf-go-c7 t3e8))
; w1b-5
 (defvc inf-vc-go-w1b-5 (under inf-go-c7 (inf-lt (natminus (inf-by8 n) const3) (natminus (inf-by8 n) cons)))
   (given inf-go-c7 (inf-consfall 0 ipt3 const3 bct3 n cons t3e4 t3e1 (inf-lttrans cons (add cons 1) const3 ((inf-ltaddpos cons 1 (idpath true))) (inf-letrans (add cons 1) const2 const3 (inf-letrans (add cons 1) const1 const2 t1e6 t2e5) t3e5)))))
; c1-1
 (defvc inf-vc-go-c1-1 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-le typt2 1) (inf-le 32 w)))
   (given inf-go-c2 (lam g1 g2 g3 gw)))
; c1-2
 (defvc inf-vc-go-c1-2 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-le typt2 1) (inf-le h 16)))
   (given inf-go-c2 (lam g1 g2 g3 gh)))
; c1-3
 (defvc inf-vc-go-c1-3 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-le typt2 1) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-go-c2 (lam g1 g2 g3 gq)))
; c1-4
 (defvc inf-vc-go-c1-4 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-le typt2 1) (inf-lt 320 q)))
   (given inf-go-c2 (lam g1 g2 g3 gq2)))
; c1-5
 (defvc inf-vc-go-c1-5 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-le typt2 1) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-go-c2 (lam g1 g2 g3 gk)))
; c1-6
 (defvc inf-vc-go-c1-6 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-le typt2 1) (inf-le LROOT 15)))
   (given inf-go-c2 (lam g1 g2 g3 gl)))
; c1-7
 (defvc inf-vc-go-c1-7 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-le typt2 1) (inf-le DROOT 15)))
   (given inf-go-c2 (lam g1 g2 g3 gd)))
; c1-8
 (defvc inf-vc-go-c1-8 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-le typt2 1) (inf-le CROOT 15)))
   (given inf-go-c2 (lam g1 g2 g3 gc)))
 (defcx inf-go-c6 inf-go-c2 (g1 (inf-lt 0 typt2)) (g2 (inf-lt typt2 3)) (g3 (inf-le typt2 1)) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) )
; i3j-1
 (defvc inf-vc-go-i3j-1 (under inf-go-c6 (inf-le ipt2 n))
   (given inf-go-c6 t2e1))
; i3j-2
 (defvc inf-vc-go-i3j-2 (under inf-go-c6 (inf-le bct2 63))
   (given inf-go-c6 t2e3))
; i3j-3
 (defvc inf-vc-go-i3j-3 (under inf-go-c6 (inf-bits-inv 0 ipt2 const2 bct2))
   (given inf-go-c6 t2e4))
; i3j-4
 (defvc inf-vc-go-i3j-4 (under inf-go-c6 (inf-le const2 const2))
   (given inf-go-c6 (inf-refl const2)))
; i3j-5
 (defvc inf-vc-go-i3j-5 (under inf-go-c6 (pi k nat (inf-lt (Lcc1 k) (inf-pow h))))
   (given inf-go-c6 c1c1))
; i3j-6
 (defvc inf-vc-go-i3j-6 (under inf-go-c6 (pi k nat (inf-lt (Lsc1 k) (inf-pow h))))
   (given inf-go-c6 c1c2))
; i3j-7
 (defvc inf-vc-go-i3j-7 (under inf-go-c6 (inf-le (inf-sum Lcc1 15 1) lmc1))
   (given inf-go-c6 c1c3))
; i3j-8
 (defvc inf-vc-go-i3j-8 (under inf-go-c6 (inf-le lmc1 288))
   (given inf-go-c6 c1c4))
; i3j-9
 (defvc inf-vc-go-i3j-9 (under inf-go-c6 (pi k nat (inf-lt (Dcc1 k) (inf-pow h))))
   (given inf-go-c6 c1c5))
; i3j-10
 (defvc inf-vc-go-i3j-10 (under inf-go-c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h))))
   (given inf-go-c6 c1c6))
; i3j-11
 (defvc inf-vc-go-i3j-11 (under inf-go-c6 (inf-le (inf-sum Dcc1 15 1) dmc1))
   (given inf-go-c6 c1c7))
; i3j-12
 (defvc inf-vc-go-i3j-12 (under inf-go-c6 (inf-le dmc1 32))
   (given inf-go-c6 c1c8))
; t4-1
 (defvc inf-vc-go-t4-1 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le 32 w)))
   (given inf-go-c2 (lam g1 g2 g3 gw)))
; t4-2
 (defvc inf-vc-go-t4-2 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-lt (add n 8) (inf-pow w))))
   (given inf-go-c2 (lam g1 g2 g3 gn)))
; t4-3
 (defvc inf-vc-go-t4-3 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le ipt2 n)))
   (given inf-go-c2 (lam g1 g2 g3 t2e1)))
; t4-4
 (defvc inf-vc-go-t4-4 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le bct2 63)))
   (given inf-go-c2 (lam g1 g2 g3 t2e3)))
; t4-5
 (defvc inf-vc-go-t4-5 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-bits-inv 0 ipt2 const2 bct2)))
   (given inf-go-c2 (lam g1 g2 g3 t2e4)))
; t4-6
 (defvc inf-vc-go-t4-6 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le h 16)))
   (given inf-go-c2 (lam g1 g2 g3 gh)))
; t4-7
 (defvc inf-vc-go-t4-7 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-go-c2 (lam g1 g2 g3 gq)))
; t4-8
 (defvc inf-vc-go-t4-8 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-lt 320 q)))
   (given inf-go-c2 (lam g1 g2 g3 gq2)))
; t4-9
 (defvc inf-vc-go-t4-9 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-go-c2 (lam g1 g2 g3 gk)))
; t4-10
 (defvc inf-vc-go-t4-10 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le LROOT 15)))
   (given inf-go-c2 (lam g1 g2 g3 gl)))
; t4-11
 (defvc inf-vc-go-t4-11 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le DROOT 15)))
   (given inf-go-c2 (lam g1 g2 g3 gd)))
; t4-12
 (defvc inf-vc-go-t4-12 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le CROOT 15)))
   (given inf-go-c2 (lam g1 g2 g3 gc)))
; t4-13
 (defvc inf-vc-go-t4-13 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))))
   (given inf-go-c2 (lam g1 g2 g3 hord)))
 (defcx inf-go-c5 inf-go-c2 (g1 (inf-lt 0 typt2)) (g2 (inf-lt typt2 3)) (g3 (inf-lt 1 typt2)) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (Lct4 (pi j nat nat)) (Lst4 (pi j nat nat)) (Ltt4 (pi j nat nat)) (Dct4 (pi j nat nat)) (Dst4 (pi j nat nat)) (Dtt4 (pi j nat nat)) (lmt4 nat) (dmt4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv 0 ipt4 const4 bct4)) (t4e5 (inf-le const2 const4)) (t4c1 (pi k nat (inf-lt (Lct4 k) (inf-pow h)))) (t4c2 (pi k nat (inf-lt (Lst4 k) (inf-pow h)))) (t4c3 (inf-le (inf-sum Lct4 15 1) lmt4)) (t4c4 (inf-le lmt4 288)) (t4c5 (pi k nat (inf-lt (Dct4 k) (inf-pow h)))) (t4c6 (pi k nat (inf-lt (Dst4 k) (inf-pow h)))) (t4c7 (inf-le (inf-sum Dct4 15 1) dmt4)) (t4c8 (inf-le dmt4 32)) )
; i3j-13
 (defvc inf-vc-go-i3j-13 (under inf-go-c5 (inf-le ipt4 n))
   (given inf-go-c5 t4e1))
; i3j-14
 (defvc inf-vc-go-i3j-14 (under inf-go-c5 (inf-le bct4 63))
   (given inf-go-c5 t4e3))
; i3j-15
 (defvc inf-vc-go-i3j-15 (under inf-go-c5 (inf-bits-inv 0 ipt4 const4 bct4))
   (given inf-go-c5 t4e4))
; i3j-16
 (defvc inf-vc-go-i3j-16 (under inf-go-c5 (inf-le const2 const4))
   (given inf-go-c5 t4e5))
; i3j-17
 (defvc inf-vc-go-i3j-17 (under inf-go-c5 (pi k nat (inf-lt (Lct4 k) (inf-pow h))))
   (given inf-go-c5 t4c1))
; i3j-18
 (defvc inf-vc-go-i3j-18 (under inf-go-c5 (pi k nat (inf-lt (Lst4 k) (inf-pow h))))
   (given inf-go-c5 t4c2))
; i3j-19
 (defvc inf-vc-go-i3j-19 (under inf-go-c5 (inf-le (inf-sum Lct4 15 1) lmt4))
   (given inf-go-c5 t4c3))
; i3j-20
 (defvc inf-vc-go-i3j-20 (under inf-go-c5 (inf-le lmt4 288))
   (given inf-go-c5 t4c4))
; i3j-21
 (defvc inf-vc-go-i3j-21 (under inf-go-c5 (pi k nat (inf-lt (Dct4 k) (inf-pow h))))
   (given inf-go-c5 t4c5))
; i3j-22
 (defvc inf-vc-go-i3j-22 (under inf-go-c5 (pi k nat (inf-lt (Dst4 k) (inf-pow h))))
   (given inf-go-c5 t4c6))
; i3j-23
 (defvc inf-vc-go-i3j-23 (under inf-go-c5 (inf-le (inf-sum Dct4 15 1) dmt4))
   (given inf-go-c5 t4c7))
; i3j-24
 (defvc inf-vc-go-i3j-24 (under inf-go-c5 (inf-le dmt4 32))
   (given inf-go-c5 t4c8))
 (defcx inf-go-c3 inf-go-c2 (g1 (inf-lt 0 typt2)) (g2 (inf-lt typt2 3)) (Lci3 (pi j nat nat)) (Lsi3 (pi j nat nat)) (Lti3 (pi j nat nat)) (Dci3 (pi j nat nat)) (Dsi3 (pi j nat nat)) (Dti3 (pi j nat nat)) (lmi3 nat) (dmi3 nat) (ipi3 nat) (bci3 nat) (bbi3 nat) (consi3 nat) (k1 (inf-le ipi3 n)) (k3 (inf-le bci3 63)) (k4 (inf-bits-inv 0 ipi3 consi3 bci3)) (k5 (inf-le const2 consi3)) (c1 (pi k nat (inf-lt (Lci3 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Lsi3 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lci3 15 1) lmi3)) (c4 (inf-le lmi3 288)) (c5 (pi k nat (inf-lt (Dci3 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Dsi3 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dci3 15 1) dmi3)) (c8 (inf-le dmi3 32)) )
; t5-1
 (defvc inf-vc-go-t5-1 (under inf-go-c3 (inf-le 32 w))
   (given inf-go-c3 gw))
; t5-2
 (defvc inf-vc-go-t5-2 (under inf-go-c3 (inf-lt (add n 8) (inf-pow w)))
   (given inf-go-c3 gn))
; t5-3
 (defvc inf-vc-go-t5-3 (under inf-go-c3 (inf-le ipi3 n))
   (given inf-go-c3 k1))
; t5-4
 (defvc inf-vc-go-t5-4 (under inf-go-c3 (inf-le bci3 63))
   (given inf-go-c3 k3))
; t5-5
 (defvc inf-vc-go-t5-5 (under inf-go-c3 (inf-bits-inv 0 ipi3 consi3 bci3))
   (given inf-go-c3 k4))
; t5-6
 (defvc inf-vc-go-t5-6 (under inf-go-c3 (pi g (inf-lt 0 out) (paths nat oc cap)))
   (given inf-go-c3 go))
; t5-7
 (defvc inf-vc-go-t5-7 (under inf-go-c3 (inf-lt (add cap 8) (inf-pow w)))
   (given inf-go-c3 gcap))
; t5-8
 (defvc inf-vc-go-t5-8 (under inf-go-c3 (inf-le op cap))
   (given inf-go-c3 j7))
; t5-9
 (defvc inf-vc-go-t5-9 (under inf-go-c3 (inf-lt (add cap nd) (inf-pow w)))
   (given inf-go-c3 gnd))
; t5-10
 (defvc inf-vc-go-t5-10 (under inf-go-c3 (inf-lt (add cap 266) (inf-pow w)))
   (given inf-go-c3 gcf))
; t5-11
 (defvc inf-vc-go-t5-11 (under inf-go-c3 (inf-le LROOT 15))
   (given inf-go-c3 gl))
; t5-12
 (defvc inf-vc-go-t5-12 (under inf-go-c3 (inf-le DROOT 15))
   (given inf-go-c3 gd))
; t5-13
 (defvc inf-vc-go-t5-13 (under inf-go-c3 (inf-le h 16))
   (given inf-go-c3 gh))
; t5-14
 (defvc inf-vc-go-t5-14 (under inf-go-c3 (pi k nat (inf-lt (Lci3 k) (inf-pow h))))
   (given inf-go-c3 c1))
; t5-15
 (defvc inf-vc-go-t5-15 (under inf-go-c3 (pi k nat (inf-lt (Lsi3 k) (inf-pow h))))
   (given inf-go-c3 c2))
; t5-16
 (defvc inf-vc-go-t5-16 (under inf-go-c3 (inf-le (inf-sum Lci3 15 1) lmi3))
   (given inf-go-c3 c3))
; t5-17
 (defvc inf-vc-go-t5-17 (under inf-go-c3 (inf-le lmi3 288))
   (given inf-go-c3 c4))
; t5-18
 (defvc inf-vc-go-t5-18 (under inf-go-c3 (pi k nat (inf-lt (Dci3 k) (inf-pow h))))
   (given inf-go-c3 c5))
; t5-19
 (defvc inf-vc-go-t5-19 (under inf-go-c3 (pi k nat (inf-lt (Dsi3 k) (inf-pow h))))
   (given inf-go-c3 c6))
; t5-20
 (defvc inf-vc-go-t5-20 (under inf-go-c3 (inf-le (inf-sum Dci3 15 1) dmi3))
   (given inf-go-c3 c7))
; t5-21
 (defvc inf-vc-go-t5-21 (under inf-go-c3 (inf-le dmi3 32))
   (given inf-go-c3 c8))
; t5-22
 (defvc inf-vc-go-t5-22 (under inf-go-c3 (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
   (given inf-go-c3 hle))
; t5-23
 (defvc inf-vc-go-t5-23 (under inf-go-c3 (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
   (given inf-go-c3 hlb))
; t5-24
 (defvc inf-vc-go-t5-24 (under inf-go-c3 (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
   (given inf-go-c3 hlc))
; t5-25
 (defvc inf-vc-go-t5-25 (under inf-go-c3 (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
   (given inf-go-c3 hde))
; t5-26
 (defvc inf-vc-go-t5-26 (under inf-go-c3 (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))))
   (given inf-go-c3 hdb))
 (defcx inf-go-c4 inf-go-c3 (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (opt5 nat) (xt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv 0 ipt5 const5 bct5)) (t5e5 (inf-le consi3 const5)) (t5e8 (inf-le opt5 cap)) (t5e9 (inf-le op opt5)) )
; w1b-6
 (defvc inf-vc-go-w1b-6 (under inf-go-c4 (inf-le ipt5 n))
   (given inf-go-c4 t5e1))
; w1b-7
 (defvc inf-vc-go-w1b-7 (under inf-go-c4 (inf-le bct5 63))
   (given inf-go-c4 t5e3))
; w1b-8
 (defvc inf-vc-go-w1b-8 (under inf-go-c4 (inf-bits-inv 0 ipt5 const5 bct5))
   (given inf-go-c4 t5e4))
; w1b-9
 (defvc inf-vc-go-w1b-9 (under inf-go-c4 (inf-le opt5 cap))
   (given inf-go-c4 t5e8))
; w1b-10
 (defvc inf-vc-go-w1b-10 (under inf-go-c4 (inf-lt (natminus (inf-by8 n) const5) (natminus (inf-by8 n) cons)))
   (given inf-go-c4 (inf-consfall 0 ipt5 const5 bct5 n cons t5e4 t5e1 (inf-lttrans cons (add cons 1) const5 ((inf-ltaddpos cons 1 (idpath true))) (inf-letrans (add cons 1) consi3 const5 (inf-letrans (add cons 1) const2 consi3 (inf-letrans (add cons 1) const1 const2 t1e6 t2e5) k5) t5e5)))))
 (defcx inf-top (In (pi k nat nat)) (n nat) (w nat) (out nat) (oc nat) (cap nat) (nd nat) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (gw (inf-le 32 w)) (go (pi g (inf-lt 0 out) (paths nat oc cap))) )
; c1-1
 (defvc inf-vc-top-c1-1 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-le 32 w)))
   (given inf-top (lam g1 g2 g3 gw)))
; c1-2
 (defvc inf-vc-top-c1-2 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-lt (add n 8) (inf-pow w))))
   (given inf-top (lam g1 g2 g3 g1)))
; c1-3
 (defvc inf-vc-top-c1-3 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-le 0 n)))
   (given inf-top (lam g1 g2 g3 (idpath false))))
; c1-4
 (defvc inf-vc-top-c1-4 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-le 0 63)))
   (given inf-top (lam g1 g2 g3 (idpath false))))
; c1-5
 (defvc inf-vc-top-c1-5 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-bits-inv 0 0 0 0)))
   (given inf-top (lam g1 g2 g3 (idpath 0))))
; c1-6
 (defvc inf-vc-top-c1-6 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-top (lam g1 g2 g3 go)))
; c1-7
 (defvc inf-vc-top-c1-7 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-lt (add cap 8) (inf-pow w))))
   (given inf-top (lam g1 g2 g3 (inf-lelt (add cap 8) (add cap 266) (inf-pow w) (inf-addl cap 8 266 (idpath false)) g2))))
; c1-8
 (defvc inf-vc-top-c1-8 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-le 0 cap)))
   (given inf-top (lam g1 g2 g3 (idpath false))))
; c1-9
 (defvc inf-vc-top-c1-9 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-lt (add cap nd) (inf-pow w))))
   (given inf-top (lam g1 g2 g3 g3)))
; c1-10
 (defvc inf-vc-top-c1-10 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-le 16 16)))
   (given inf-top (lam g1 g2 g3 (idpath false))))
; c1-11
 (defvc inf-vc-top-c1-11 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-le (inf-by16 (inf-pow 12)) (inf-pow 16))))
   (given inf-top (lam g1 g2 g3 inf-topq)))
; c1-12
 (defvc inf-vc-top-c1-12 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-lt 320 (inf-pow 12))))
   (given inf-top (lam g1 g2 g3 (idpath true))))
; c1-13
 (defvc inf-vc-top-c1-13 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (pi k nat g (inf-le k 15) (inf-lt (inf-dk (inf-pow 12) k) (inf-pow w)))))
   (given inf-top (lam g1 g2 g3 (inf-topk w gw))))
; c1-14
 (defvc inf-vc-top-c1-14 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-le 12 15)))
   (given inf-top (lam g1 g2 g3 (idpath false))))
; c1-15
 (defvc inf-vc-top-c1-15 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-le 9 15)))
   (given inf-top (lam g1 g2 g3 (idpath false))))
; c1-16
 (defvc inf-vc-top-c1-16 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-le 7 15)))
   (given inf-top (lam g1 g2 g3 (idpath false))))
; c1-17
 (defvc inf-vc-top-c1-17 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (inf-lt (add cap 266) (inf-pow w))))
   (given inf-top (lam g1 g2 g3 g2)))
; c1-18
 (defvc inf-vc-top-c1-18 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (pi k nat g (inf-lt k 19) (inf-lt (inf-tob k) 19))))
   (given inf-top (lam g1 g2 g3 (lam k g (inf-lelts (inf-tob k) 18 (inf-anyno (lam j (natgtb (inf-tob j) 18)) 19 (idpath false) k g))))))
; c1-19
 (defvc inf-vc-top-c1-19 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (pi k nat g (inf-lt k 29) (inf-le (inf-tle k) 5))))
   (given inf-top (lam g1 g2 g3 (inf-anyno (lam j (natgtb (inf-tle j) 5)) 29 (idpath false)))))
; c1-20
 (defvc inf-vc-top-c1-20 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (pi k nat g (inf-lt k 29) (inf-le (add (inf-tlb k) (inf-pow (inf-tle k))) 259))))
   (given inf-top (lam g1 g2 g3 (inf-anyno (lam j (natgtb (add (inf-tlb j) (inf-pow (inf-tle j))) 259)) 29 (idpath false)))))
; c1-21
 (defvc inf-vc-top-c1-21 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (pi k nat g (inf-lt k 29) (inf-le 3 (inf-tlb k)))))
   (given inf-top (lam g1 g2 g3 (inf-anyno (lam j (natgtb 3 (inf-tlb j))) 29 (idpath false)))))
; c1-22
 (defvc inf-vc-top-c1-22 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (pi k nat g (inf-lt k 30) (inf-le (inf-tde k) 13))))
   (given inf-top (lam g1 g2 g3 (inf-anyno (lam j (natgtb (inf-tde j) 13)) 30 (idpath false)))))
; c1-23
 (defvc inf-vc-top-c1-23 (under inf-top (pi g1 (inf-lt (add n 8) (inf-pow w)) g2 (inf-lt (add cap 266) (inf-pow w)) g3 (inf-lt (add cap nd) (inf-pow w)) (pi k nat g (inf-lt k 30) (inf-le (add (inf-tdb k) (inf-pow (inf-tde k))) (inf-pow 16)))))
   (given inf-top (lam g1 g2 g3 (inf-anyno (lam j (natgtb (add (inf-tdb j) (inf-pow (inf-tde j))) (inf-pow 16))) 30 (idpath false)))))
 (defcx inf-top-c1 inf-top (g1 (inf-lt (add n 8) (inf-pow w))) (g2 (inf-lt (add cap 266) (inf-pow w))) (g3 (inf-lt (add cap nd) (inf-pow w))) (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (opc1 nat) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (xc1 nat) )
 (defcx inf-sy1 (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Cn (pi i nat nat)) (Sy (pi i nat nat)) (Tb (pi i nat nat)) (m nat) (h nat) (root nat) (hc (pi i nat (inf-lt (Cn i) (inf-pow h)))) (hs (pi i nat (inf-lt (Sy i) (inf-pow h)))) (gh (inf-le h 16)) (gm (inf-lt m (inf-pow w))) (gt (inf-le (inf-sum Cn 15 1) m)) (gr (inf-le root 15)) )
; c1-1
 (defvc inf-vc-sy1-c1-1 (under inf-sy1 (inf-le 32 w))
   (given inf-sy1 gw))
; c1-2
 (defvc inf-vc-sy1-c1-2 (under inf-sy1 (inf-lt (add n 8) (inf-pow w)))
   (given inf-sy1 gn))
; c1-3
 (defvc inf-vc-sy1-c1-3 (under inf-sy1 (inf-le ip0 n))
   (given inf-sy1 gi))
; c1-4
 (defvc inf-vc-sy1-c1-4 (under inf-sy1 (inf-le bc0 63))
   (given inf-sy1 gs))
; c1-5
 (defvc inf-vc-sy1-c1-5 (under inf-sy1 (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-sy1 ga))
 (defcx inf-sy1-c1 inf-sy1 (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
; r1-1
 (defvc inf-vc-sy1-r1-1 (under inf-sy1-c1 (pi g1 (inf-lt bcc1 15) g2 (inf-lt 0 n) (inf-le ipc1 n)))
   (given inf-sy1-c1 (lam g1 g2 c1e1)))
; r1-2
 (defvc inf-vc-sy1-r1-2 (under inf-sy1-c1 (pi g1 (inf-lt bcc1 15) g2 (inf-lt 0 n) (inf-le bcc1 63)))
   (given inf-sy1-c1 (lam g1 g2 c1e3)))
; r1-3
 (defvc inf-vc-sy1-r1-3 (under inf-sy1-c1 (pi g1 (inf-lt bcc1 15) g2 (inf-lt 0 n) (inf-bits-inv carry ipc1 consc1 bcc1)))
   (given inf-sy1-c1 (lam g1 g2 c1e4)))
; r1-4
 (defvc inf-vc-sy1-r1-4 (under inf-sy1-c1 (pi g1 (inf-lt bcc1 15) g2 (inf-lt 0 n) (inf-le cons0 consc1)))
   (given inf-sy1-c1 (lam g1 g2 c1e5)))
; t1-1
 (defvc inf-vc-sy1-t1-1 (under inf-sy1-c1 (inf-le 32 w))
   (given inf-sy1-c1 gw))
; t1-2
 (defvc inf-vc-sy1-t1-2 (under inf-sy1-c1 (inf-lt (add n 8) (inf-pow w)))
   (given inf-sy1-c1 gn))
; t1-3
 (defvc inf-vc-sy1-t1-3 (under inf-sy1-c1 (inf-le ipc1 n))
   (given inf-sy1-c1 c1e1))
; t1-4
 (defvc inf-vc-sy1-t1-4 (under inf-sy1-c1 (inf-le bcc1 63))
   (given inf-sy1-c1 c1e3))
; t1-5
 (defvc inf-vc-sy1-t1-5 (under inf-sy1-c1 (inf-bits-inv carry ipc1 consc1 bcc1))
   (given inf-sy1-c1 c1e4))
; t1-6
 (defvc inf-vc-sy1-t1-6 (under inf-sy1-c1 (pi i nat (inf-lt (Cn i) (inf-pow h))))
   (given inf-sy1-c1 hc))
; t1-7
 (defvc inf-vc-sy1-t1-7 (under inf-sy1-c1 (pi i nat (inf-lt (Sy i) (inf-pow h))))
   (given inf-sy1-c1 hs))
; t1-8
 (defvc inf-vc-sy1-t1-8 (under inf-sy1-c1 (inf-le h 16))
   (given inf-sy1-c1 gh))
; t1-9
 (defvc inf-vc-sy1-t1-9 (under inf-sy1-c1 (inf-lt m (inf-pow w)))
   (given inf-sy1-c1 gm))
; t1-10
 (defvc inf-vc-sy1-t1-10 (under inf-sy1-c1 (inf-le (inf-sum Cn 15 1) m))
   (given inf-sy1-c1 gt))
; t1-11
 (defvc inf-vc-sy1-t1-11 (under inf-sy1-c1 (inf-le root 15))
   (given inf-sy1-c1 gr))
; t1s-1
 (defvc inf-vc-sy1-t1s-1 (under inf-sy1-c1 (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le consc1 const1) (inf-le ipt1 n)))
   (given inf-sy1-c1 (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e1)))
; t1s-2
 (defvc inf-vc-sy1-t1s-2 (under inf-sy1-c1 (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le consc1 const1) (inf-le bct1 63)))
   (given inf-sy1-c1 (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e3)))
; t1s-3
 (defvc inf-vc-sy1-t1s-3 (under inf-sy1-c1 (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le consc1 const1) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-sy1-c1 (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e4)))
; t1s-4
 (defvc inf-vc-sy1-t1s-4 (under inf-sy1-c1 (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le consc1 const1) (inf-le cons0 const1)))
   (given inf-sy1-c1 (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 (inf-letrans cons0 consc1 const1 c1e5 t1e5))))
 (defcx inf-sy1-c2 inf-sy1-c1 (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le consc1 const1)) )
; r2-1
 (defvc inf-vc-sy1-r2-1 (under inf-sy1-c2 (inf-le ipt1 n))
   (given inf-sy1-c2 t1e1))
; r2-2
 (defvc inf-vc-sy1-r2-2 (under inf-sy1-c2 (inf-le bct1 63))
   (given inf-sy1-c2 t1e3))
; r2-3
 (defvc inf-vc-sy1-r2-3 (under inf-sy1-c2 (inf-bits-inv carry ipt1 const1 bct1))
   (given inf-sy1-c2 t1e4))
; r2-4
 (defvc inf-vc-sy1-r2-4 (under inf-sy1-c2 (inf-le cons0 const1))
   (given inf-sy1-c2 (inf-letrans cons0 consc1 const1 c1e5 t1e5)))
 (defcx inf-sthead (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (last0 nat) (mode0 nat) (stage0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) )
; t1-1
 (defvc inf-vc-sthead-t1-1 (under inf-sthead (inf-le 32 w))
   (given inf-sthead gw))
; t1-2
 (defvc inf-vc-sthead-t1-2 (under inf-sthead (inf-lt (add n 8) (inf-pow w)))
   (given inf-sthead gn))
; t1-3
 (defvc inf-vc-sthead-t1-3 (under inf-sthead (inf-le ip0 n))
   (given inf-sthead gi))
; t1-4
 (defvc inf-vc-sthead-t1-4 (under inf-sthead (inf-le bc0 63))
   (given inf-sthead gs))
; t1-5
 (defvc inf-vc-sthead-t1-5 (under inf-sthead (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-sthead ga))
; t1-6
 (defvc inf-vc-sthead-t1-6 (under inf-sthead (inf-le 3 13))
   (given inf-sthead (idpath false)))
; t1s-1
 (defvc inf-vc-sthead-t1s-1 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le ipt1 n)))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e1)))
; t1s-2
 (defvc inf-vc-sthead-t1s-2 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le bct1 63)))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e3)))
; t1s-3
 (defvc inf-vc-sthead-t1s-3 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e4)))
; t1s-4
 (defvc inf-vc-sthead-t1s-4 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le cons0 const1)))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e5)))
; t1s-5
 (defvc inf-vc-sthead-t1s-5 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c1)))
; t1s-6
 (defvc inf-vc-sthead-t1s-6 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c2)))
; t1s-7
 (defvc inf-vc-sthead-t1s-7 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c3)))
; t1s-8
 (defvc inf-vc-sthead-t1s-8 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le lm0 288)))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c4)))
; t1s-9
 (defvc inf-vc-sthead-t1s-9 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c5)))
; t1s-10
 (defvc inf-vc-sthead-t1s-10 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c6)))
; t1s-11
 (defvc inf-vc-sthead-t1s-11 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c7)))
; t1s-12
 (defvc inf-vc-sthead-t1s-12 (under inf-sthead (pi ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le dm0 32)))
   (given inf-sthead (lam ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c8)))
 (defcx inf-sthead-c1 inf-sthead (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons0 const1)) (t1e6 (inf-le (add cons0 3) const1)) (t1e7 (inf-lt xt1 (inf-pow 3))) )
; d2-1
 (defvc inf-vc-sthead-d2-1 (under inf-sthead-c1 (pi lastd1 nat (inf-lt 1 64)))
   (given inf-sthead-c1 (lam lastd1 (idpath true))))
; d3-1
 (defvc inf-vc-sthead-d3-1 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) (inf-lt (inf-mod 8 bct1) (inf-pow w))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 (inf-wlit (inf-mod 8 bct1) w gw (inf-letrans (inf-mod 8 bct1) 7 63 (inf-ltsle (inf-mod 8 bct1) 7 (inf-modlt 7 bct1)) (idpath false))))))
; d4a-1
 (defvc inf-vc-sthead-d4a-1 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) (inf-lt (inf-mod 8 bct1) 64)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 (inf-lelts (inf-mod 8 bct1) 63 (inf-letrans (inf-mod 8 bct1) 7 63 (inf-ltsle (inf-mod 8 bct1) 7 (inf-modlt 7 bct1)) (idpath false))))))
; d4b-1
 (defvc inf-vc-sthead-d4b-1 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat (inf-le (inf-mod 8 bct1) bct1)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a (inf-modle8 bct1))))
; d4b-2
 (defvc inf-vc-sthead-d4b-2 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat (inf-lt (natminus bct1 (inf-mod 8 bct1)) (inf-pow w))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a (inf-wlit (natminus bct1 (inf-mod 8 bct1)) w gw (inf-letrans (natminus bct1 (inf-mod 8 bct1)) bct1 63 (inf-suble bct1 (inf-mod 8 bct1)) t1e3)))))
; r2-1
 (defvc inf-vc-sthead-r2-1 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (inf-le ipt1 n)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 t1e1)))
; r2-2
 (defvc inf-vc-sthead-r2-2 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (inf-le (natminus bct1 (inf-mod 8 bct1)) 63)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 (inf-letrans (natminus bct1 (inf-mod 8 bct1)) bct1 63 (inf-suble bct1 (inf-mod 8 bct1)) t1e3))))
; r2-3
 (defvc inf-vc-sthead-r2-3 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (inf-bits-inv carry ipt1 (add const1 (inf-mod 8 bct1)) (natminus bct1 (inf-mod 8 bct1)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 (inf-take carry ipt1 const1 bct1 (inf-mod 8 bct1) (inf-letrans (inf-mod 8 bct1) bct1 bct1 (inf-modle8 bct1) (inf-refl bct1)) t1e4))))
; r2-4
 (defvc inf-vc-sthead-r2-4 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (inf-le cons0 (add const1 (inf-mod 8 bct1)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 (inf-letrans cons0 const1 (add const1 (inf-mod 8 bct1)) t1e5 (inf-leaddr const1 (inf-mod 8 bct1))))))
; r2-5
 (defvc inf-vc-sthead-r2-5 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 c1)))
; r2-6
 (defvc inf-vc-sthead-r2-6 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 c2)))
; r2-7
 (defvc inf-vc-sthead-r2-7 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 c3)))
; r2-8
 (defvc inf-vc-sthead-r2-8 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (inf-le lm0 288)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 c4)))
; r2-9
 (defvc inf-vc-sthead-r2-9 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 c5)))
; r2-10
 (defvc inf-vc-sthead-r2-10 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 c6)))
; r2-11
 (defvc inf-vc-sthead-r2-11 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 c7)))
; r2-12
 (defvc inf-vc-sthead-r2-12 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (inf-le dm0 32)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 c8)))
; r2-13
 (defvc inf-vc-sthead-r2-13 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (paths nat typd2 0) bbd4a nat moded5 nat (inf-le (add cons0 3) (add const1 (inf-mod 8 bct1)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 bbd4a moded5 (inf-letrans (add cons0 3) const1 (add const1 (inf-mod 8 bct1)) t1e6 (inf-leaddr const1 (inf-mod 8 bct1))))))
; r1-1
 (defvc inf-vc-sthead-r1-1 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (inf-le ipt1 n)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 t1e1)))
; r1-2
 (defvc inf-vc-sthead-r1-2 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (inf-le bct1 63)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 t1e3)))
; r1-3
 (defvc inf-vc-sthead-r1-3 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 t1e4)))
; r1-4
 (defvc inf-vc-sthead-r1-4 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (inf-le cons0 const1)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 t1e5)))
; r1-5
 (defvc inf-vc-sthead-r1-5 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 c1)))
; r1-6
 (defvc inf-vc-sthead-r1-6 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 c2)))
; r1-7
 (defvc inf-vc-sthead-r1-7 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 c3)))
; r1-8
 (defvc inf-vc-sthead-r1-8 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (inf-le lm0 288)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 c4)))
; r1-9
 (defvc inf-vc-sthead-r1-9 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 c5)))
; r1-10
 (defvc inf-vc-sthead-r1-10 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 c6)))
; r1-11
 (defvc inf-vc-sthead-r1-11 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 c7)))
; r1-12
 (defvc inf-vc-sthead-r1-12 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-le 3 typd2) (inf-le dm0 32)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 c8)))
; c1-1
 (defvc inf-vc-sthead-c1-1 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-le typd2 1) (inf-le 32 w)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 gw)))
; c1-2
 (defvc inf-vc-sthead-c1-2 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-le typd2 1) (inf-le h 16)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 gh)))
; c1-3
 (defvc inf-vc-sthead-c1-3 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-le typd2 1) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 gq)))
; c1-4
 (defvc inf-vc-sthead-c1-4 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-le typd2 1) (inf-lt 320 q)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 gq2)))
; c1-5
 (defvc inf-vc-sthead-c1-5 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-le typd2 1) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 gk)))
; c1-6
 (defvc inf-vc-sthead-c1-6 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-le typd2 1) (inf-le LROOT 15)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 gl)))
; c1-7
 (defvc inf-vc-sthead-c1-7 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-le typd2 1) (inf-le DROOT 15)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 gd)))
; c1-8
 (defvc inf-vc-sthead-c1-8 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-le typd2 1) (inf-le CROOT 15)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 gc)))
 (defcx inf-sthead-c2 inf-sthead-c1 (lastd1 nat) (typd2 nat) (g1 (inf-lt 0 typd2)) (g2 (inf-lt typd2 3)) (g3 (inf-le typd2 1)) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) )
; r2-14
 (defvc inf-vc-sthead-r2-14 (under inf-sthead-c2 (pi moded6 nat staged7 nat (inf-le ipt1 n)))
   (given inf-sthead-c2 (lam moded6 staged7 t1e1)))
; r2-15
 (defvc inf-vc-sthead-r2-15 (under inf-sthead-c2 (pi moded6 nat staged7 nat (inf-le bct1 63)))
   (given inf-sthead-c2 (lam moded6 staged7 t1e3)))
; r2-16
 (defvc inf-vc-sthead-r2-16 (under inf-sthead-c2 (pi moded6 nat staged7 nat (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-sthead-c2 (lam moded6 staged7 t1e4)))
; r2-17
 (defvc inf-vc-sthead-r2-17 (under inf-sthead-c2 (pi moded6 nat staged7 nat (inf-le cons0 const1)))
   (given inf-sthead-c2 (lam moded6 staged7 t1e5)))
; r2-18
 (defvc inf-vc-sthead-r2-18 (under inf-sthead-c2 (pi moded6 nat staged7 nat (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))))
   (given inf-sthead-c2 (lam moded6 staged7 c1c1)))
; r2-19
 (defvc inf-vc-sthead-r2-19 (under inf-sthead-c2 (pi moded6 nat staged7 nat (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))))
   (given inf-sthead-c2 (lam moded6 staged7 c1c2)))
; r2-20
 (defvc inf-vc-sthead-r2-20 (under inf-sthead-c2 (pi moded6 nat staged7 nat (inf-le (inf-sum Lcc1 15 1) lmc1)))
   (given inf-sthead-c2 (lam moded6 staged7 c1c3)))
; r2-21
 (defvc inf-vc-sthead-r2-21 (under inf-sthead-c2 (pi moded6 nat staged7 nat (inf-le lmc1 288)))
   (given inf-sthead-c2 (lam moded6 staged7 c1c4)))
; r2-22
 (defvc inf-vc-sthead-r2-22 (under inf-sthead-c2 (pi moded6 nat staged7 nat (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))))
   (given inf-sthead-c2 (lam moded6 staged7 c1c5)))
; r2-23
 (defvc inf-vc-sthead-r2-23 (under inf-sthead-c2 (pi moded6 nat staged7 nat (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))))
   (given inf-sthead-c2 (lam moded6 staged7 c1c6)))
; r2-24
 (defvc inf-vc-sthead-r2-24 (under inf-sthead-c2 (pi moded6 nat staged7 nat (inf-le (inf-sum Dcc1 15 1) dmc1)))
   (given inf-sthead-c2 (lam moded6 staged7 c1c7)))
; r2-25
 (defvc inf-vc-sthead-r2-25 (under inf-sthead-c2 (pi moded6 nat staged7 nat (inf-le dmc1 32)))
   (given inf-sthead-c2 (lam moded6 staged7 c1c8)))
; r2-26
 (defvc inf-vc-sthead-r2-26 (under inf-sthead-c2 (pi moded6 nat staged7 nat (inf-le (add cons0 3) const1)))
   (given inf-sthead-c2 (lam moded6 staged7 t1e6)))
; r2-27
 (defvc inf-vc-sthead-r2-27 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (inf-le ipt1 n)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 t1e1)))
; r2-28
 (defvc inf-vc-sthead-r2-28 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (inf-le bct1 63)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 t1e3)))
; r2-29
 (defvc inf-vc-sthead-r2-29 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 t1e4)))
; r2-30
 (defvc inf-vc-sthead-r2-30 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (inf-le cons0 const1)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 t1e5)))
; r2-31
 (defvc inf-vc-sthead-r2-31 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 c1)))
; r2-32
 (defvc inf-vc-sthead-r2-32 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 c2)))
; r2-33
 (defvc inf-vc-sthead-r2-33 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 c3)))
; r2-34
 (defvc inf-vc-sthead-r2-34 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (inf-le lm0 288)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 c4)))
; r2-35
 (defvc inf-vc-sthead-r2-35 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 c5)))
; r2-36
 (defvc inf-vc-sthead-r2-36 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 c6)))
; r2-37
 (defvc inf-vc-sthead-r2-37 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 c7)))
; r2-38
 (defvc inf-vc-sthead-r2-38 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (inf-le dm0 32)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 c8)))
; r2-39
 (defvc inf-vc-sthead-r2-39 (under inf-sthead-c1 (pi lastd1 nat typd2 nat g1 (inf-lt 0 typd2) g2 (inf-lt typd2 3) g3 (inf-lt 1 typd2) moded8 nat (inf-le (add cons0 3) const1)))
   (given inf-sthead-c1 (lam lastd1 typd2 g1 g2 g3 moded8 t1e6)))
 (defcx inf-stlen (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (rem0 nat) (mode0 nat) )
; c1-1
 (defvc inf-vc-stlen-c1-1 (under inf-stlen (inf-le 32 w))
   (given inf-stlen gw))
; c1-2
 (defvc inf-vc-stlen-c1-2 (under inf-stlen (inf-lt (add n 8) (inf-pow w)))
   (given inf-stlen gn))
; c1-3
 (defvc inf-vc-stlen-c1-3 (under inf-stlen (inf-le ip0 n))
   (given inf-stlen gi))
; c1-4
 (defvc inf-vc-stlen-c1-4 (under inf-stlen (inf-le bc0 63))
   (given inf-stlen gs))
; c1-5
 (defvc inf-vc-stlen-c1-5 (under inf-stlen (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-stlen ga))
 (defcx inf-stlen-c1 inf-stlen (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
; r1-1
 (defvc inf-vc-stlen-r1-1 (under inf-stlen-c1 (pi g1 (inf-lt bcc1 32) (inf-le ipc1 n)))
   (given inf-stlen-c1 (lam g1 c1e1)))
; r1-2
 (defvc inf-vc-stlen-r1-2 (under inf-stlen-c1 (pi g1 (inf-lt bcc1 32) (inf-le bcc1 63)))
   (given inf-stlen-c1 (lam g1 c1e3)))
; r1-3
 (defvc inf-vc-stlen-r1-3 (under inf-stlen-c1 (pi g1 (inf-lt bcc1 32) (inf-bits-inv carry ipc1 consc1 bcc1)))
   (given inf-stlen-c1 (lam g1 c1e4)))
; r1-4
 (defvc inf-vc-stlen-r1-4 (under inf-stlen-c1 (pi g1 (inf-lt bcc1 32) (inf-le cons0 consc1)))
   (given inf-stlen-c1 (lam g1 c1e5)))
; d1-1
 (defvc inf-vc-stlen-d1-1 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) (inf-lt 16 32)))
   (given inf-stlen-c1 (lam g1 (idpath true))))
; d2-1
 (defvc inf-vc-stlen-d2-1 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat (inf-lt 16 64)))
   (given inf-stlen-c1 (lam g1 lnd1 (idpath true))))
; d3-1
 (defvc inf-vc-stlen-d3-1 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat (inf-lt 16 32)))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 (idpath true))))
; r2-1
 (defvc inf-vc-stlen-r2-1 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit (inf-le ipc1 n)))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 c1e1)))
; r2-2
 (defvc inf-vc-stlen-r2-2 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit (inf-le bcc1 63)))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 c1e3)))
; r2-3
 (defvc inf-vc-stlen-r2-3 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit (inf-bits-inv carry ipc1 consc1 bcc1)))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 c1e4)))
; r2-4
 (defvc inf-vc-stlen-r2-4 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit (inf-le cons0 consc1)))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 c1e5)))
; d4a-1
 (defvc inf-vc-stlen-d4a-1 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit (inf-lt 32 64)))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 (idpath true))))
; d4b-1
 (defvc inf-vc-stlen-d4b-1 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit bbd4a nat (inf-le 32 bcc1)))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 bbd4a g1)))
; d4b-2
 (defvc inf-vc-stlen-d4b-2 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit bbd4a nat (inf-lt (natminus bcc1 32) (inf-pow w))))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 bbd4a (inf-wlit (natminus bcc1 32) w gw (inf-letrans (natminus bcc1 32) bcc1 63 (inf-suble bcc1 32) c1e3)))))
; r3-1
 (defvc inf-vc-stlen-r3-1 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit bbd4a nat remd5 nat moded6 nat (inf-le ipc1 n)))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 bbd4a remd5 moded6 c1e1)))
; r3-2
 (defvc inf-vc-stlen-r3-2 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit bbd4a nat remd5 nat moded6 nat (inf-le (natminus bcc1 32) 63)))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 bbd4a remd5 moded6 (inf-letrans (natminus bcc1 32) bcc1 63 (inf-suble bcc1 32) c1e3))))
; r3-3
 (defvc inf-vc-stlen-r3-3 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit bbd4a nat remd5 nat moded6 nat (inf-bits-inv carry ipc1 (add consc1 32) (natminus bcc1 32))))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 bbd4a remd5 moded6 (inf-take carry ipc1 consc1 bcc1 32 g1 c1e4))))
; r3-4
 (defvc inf-vc-stlen-r3-4 (under inf-stlen-c1 (pi g1 (inf-le 32 bcc1) lnd1 nat yd2 nat nld3 nat g2 unit bbd4a nat remd5 nat moded6 nat (inf-le cons0 (add consc1 32))))
   (given inf-stlen-c1 (lam g1 lnd1 yd2 nld3 g2 bbd4a remd5 moded6 (inf-letrans cons0 consc1 (add consc1 32) c1e5 (inf-leaddr consc1 32)))))
 (defcx inf-sttab (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Cl0 (pi k nat nat)) (a2 (pi k nat (inf-le (Cl0 k) 15))) (hlit0 nat) (hdist0 nat) (hclen0 nat) (i0 nat) (mode0 nat) )
; c1-1
 (defvc inf-vc-sttab-c1-1 (under inf-sttab (inf-le 32 w))
   (given inf-sttab gw))
; c1-2
 (defvc inf-vc-sttab-c1-2 (under inf-sttab (inf-lt (add n 8) (inf-pow w)))
   (given inf-sttab gn))
; c1-3
 (defvc inf-vc-sttab-c1-3 (under inf-sttab (inf-le ip0 n))
   (given inf-sttab gi))
; c1-4
 (defvc inf-vc-sttab-c1-4 (under inf-sttab (inf-le bc0 63))
   (given inf-sttab gs))
; c1-5
 (defvc inf-vc-sttab-c1-5 (under inf-sttab (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-sttab ga))
 (defcx inf-sttab-c1 inf-sttab (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv carry ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
; r1-1
 (defvc inf-vc-sttab-r1-1 (under inf-sttab-c1 (pi g1 (inf-lt bcc1 14) (inf-le ipc1 n)))
   (given inf-sttab-c1 (lam g1 c1e1)))
; r1-2
 (defvc inf-vc-sttab-r1-2 (under inf-sttab-c1 (pi g1 (inf-lt bcc1 14) (inf-le bcc1 63)))
   (given inf-sttab-c1 (lam g1 c1e3)))
; r1-3
 (defvc inf-vc-sttab-r1-3 (under inf-sttab-c1 (pi g1 (inf-lt bcc1 14) (inf-bits-inv carry ipc1 consc1 bcc1)))
   (given inf-sttab-c1 (lam g1 c1e4)))
; r1-4
 (defvc inf-vc-sttab-r1-4 (under inf-sttab-c1 (pi g1 (inf-lt bcc1 14) (inf-le cons0 consc1)))
   (given inf-sttab-c1 (lam g1 c1e5)))
; r1-5
 (defvc inf-vc-sttab-r1-5 (under inf-sttab-c1 (pi g1 (inf-lt bcc1 14) (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-sttab-c1 (lam g1 a2)))
; d1-1
 (defvc inf-vc-sttab-d1-1 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) (inf-lt 5 32)))
   (given inf-sttab-c1 (lam g1 (idpath true))))
; d1-2
 (defvc inf-vc-sttab-d1-2 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) (inf-lt (add (inf-mod (inf-pow 5) bbc1) 257) (inf-pow w))))
   (given inf-sttab-c1 (lam g1 (inf-lelt (add ((inf-mod (inf-pow 5) bbc1)) 257) 288 (inf-pow w) (inf-addr ((inf-mod (inf-pow 5) bbc1)) 31 257 (inf-ltsle ((inf-mod (inf-pow 5) bbc1)) 31 (inf-masklt bbc1 5))) (inf-wfit288 w gw)))))
; d2-1
 (defvc inf-vc-sttab-d2-1 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat (inf-lt 5 64)))
   (given inf-sttab-c1 (lam g1 hlitd1 (idpath true))))
; d3-1
 (defvc inf-vc-sttab-d3-1 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat (inf-lt 5 32)))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 (idpath true))))
; d3-2
 (defvc inf-vc-sttab-d3-2 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat (inf-lt (add (inf-mod (inf-pow 5) yd2) 1) (inf-pow w))))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 (inf-wlit (add ((inf-mod (inf-pow 5) yd2)) 1) w gw (inf-letrans (add ((inf-mod (inf-pow 5) yd2)) 1) 32 63 (inf-addr ((inf-mod (inf-pow 5) yd2)) 31 1 (inf-ltsle ((inf-mod (inf-pow 5) yd2)) 31 (inf-masklt yd2 5))) (idpath false))))))
; d4-1
 (defvc inf-vc-sttab-d4-1 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat (inf-lt 10 64)))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 (idpath true))))
; d5-1
 (defvc inf-vc-sttab-d5-1 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat (inf-lt 4 32)))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 (idpath true))))
; d5-2
 (defvc inf-vc-sttab-d5-2 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat (inf-lt (add (inf-mod (inf-pow 4) yd4) 4) (inf-pow w))))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 (inf-wlit (add ((inf-mod (inf-pow 4) yd4)) 4) w gw (inf-letrans (add ((inf-mod (inf-pow 4) yd4)) 4) 19 63 (inf-addr ((inf-mod (inf-pow 4) yd4)) 15 4 (inf-ltsle ((inf-mod (inf-pow 4) yd4)) 15 (inf-masklt yd4 4))) (idpath false))))))
; d6a-1
 (defvc inf-vc-sttab-d6a-1 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat (inf-lt 14 64)))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 hclend5 (idpath true))))
; d6b-1
 (defvc inf-vc-sttab-d6b-1 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat bbd6a nat (inf-le 14 bcc1)))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 hclend5 bbd6a g1)))
; d6b-2
 (defvc inf-vc-sttab-d6b-2 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat bbd6a nat (inf-lt (natminus bcc1 14) (inf-pow w))))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 hclend5 bbd6a (inf-wlit (natminus bcc1 14) w gw (inf-letrans (natminus bcc1 14) bcc1 63 (inf-suble bcc1 14) c1e3)))))
; r2-1
 (defvc inf-vc-sttab-r2-1 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat bbd6a nat id7 nat moded8 nat (inf-le ipc1 n)))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 hclend5 bbd6a id7 moded8 c1e1)))
; r2-2
 (defvc inf-vc-sttab-r2-2 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat bbd6a nat id7 nat moded8 nat (inf-le (natminus bcc1 14) 63)))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 hclend5 bbd6a id7 moded8 (inf-letrans (natminus bcc1 14) bcc1 63 (inf-suble bcc1 14) c1e3))))
; r2-3
 (defvc inf-vc-sttab-r2-3 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat bbd6a nat id7 nat moded8 nat (inf-bits-inv carry ipc1 (add consc1 14) (natminus bcc1 14))))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 hclend5 bbd6a id7 moded8 (inf-take carry ipc1 consc1 bcc1 14 g1 c1e4))))
; r2-4
 (defvc inf-vc-sttab-r2-4 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat bbd6a nat id7 nat moded8 nat (inf-le cons0 (add consc1 14))))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 hclend5 bbd6a id7 moded8 (inf-letrans cons0 consc1 (add consc1 14) c1e5 (inf-leaddr consc1 14)))))
; r2-5
 (defvc inf-vc-sttab-r2-5 (under inf-sttab-c1 (pi g1 (inf-le 14 bcc1) hlitd1 nat yd2 nat hdistd3 nat yd4 nat hclend5 nat bbd6a nat id7 nat moded8 nat (pi k nat (inf-le (inf-zero k) 15))))
   (given inf-sttab-c1 (lam g1 hlitd1 yd2 hdistd3 yd4 hclend5 bbd6a id7 moded8 (lam k (idpath false)))))
 (defcx inf-stcl (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hclen nat) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (a2 (pi k nat (inf-le (Cl0 k) 15))) (b2 (pi j nat (inf-le (Lz0 j) 15))) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (i0 nat) (prev0 nat) (stage0 nat) (mode0 nat) (b1 (inf-le prev0 15)) )
; r0-1
 (defvc inf-vc-stcl-r0-1 (under inf-stcl (pi g0 (inf-lt 19 hclen) (inf-le ip0 n)))
   (given inf-stcl (lam g0 gi)))
; r0-2
 (defvc inf-vc-stcl-r0-2 (under inf-stcl (pi g0 (inf-lt 19 hclen) (inf-le bc0 63)))
   (given inf-stcl (lam g0 gs)))
; r0-3
 (defvc inf-vc-stcl-r0-3 (under inf-stcl (pi g0 (inf-lt 19 hclen) (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-stcl (lam g0 ga)))
; r0-4
 (defvc inf-vc-stcl-r0-4 (under inf-stcl (pi g0 (inf-lt 19 hclen) (inf-le cons0 cons0)))
   (given inf-stcl (lam g0 (inf-refl cons0))))
; r0-5
 (defvc inf-vc-stcl-r0-5 (under inf-stcl (pi g0 (inf-lt 19 hclen) (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-stcl (lam g0 d1)))
; r0-6
 (defvc inf-vc-stcl-r0-6 (under inf-stcl (pi g0 (inf-lt 19 hclen) (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-stcl (lam g0 d2)))
; r0-7
 (defvc inf-vc-stcl-r0-7 (under inf-stcl (pi g0 (inf-lt 19 hclen) (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-stcl (lam g0 d3)))
; r0-8
 (defvc inf-vc-stcl-r0-8 (under inf-stcl (pi g0 (inf-lt 19 hclen) (inf-le prev0 15)))
   (given inf-stcl (lam g0 b1)))
; r0-9
 (defvc inf-vc-stcl-r0-9 (under inf-stcl (pi g0 (inf-lt 19 hclen) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-stcl (lam g0 b2)))
; r0-10
 (defvc inf-vc-stcl-r0-10 (under inf-stcl (pi g0 (inf-lt 19 hclen) (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-stcl (lam g0 a2)))
; w1e-1
 (defvc inf-vc-stcl-w1e-1 (under inf-stcl (pi g0 (inf-le hclen 19) (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-stcl (lam g0 a2)))
; w1e-2
 (defvc inf-vc-stcl-w1e-2 (under inf-stcl (pi g0 (inf-le hclen 19) (inf-le ip0 n)))
   (given inf-stcl (lam g0 gi)))
; w1e-3
 (defvc inf-vc-stcl-w1e-3 (under inf-stcl (pi g0 (inf-le hclen 19) (inf-le bc0 63)))
   (given inf-stcl (lam g0 gs)))
; w1e-4
 (defvc inf-vc-stcl-w1e-4 (under inf-stcl (pi g0 (inf-le hclen 19) (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-stcl (lam g0 ga)))
; w1e-5
 (defvc inf-vc-stcl-w1e-5 (under inf-stcl (pi g0 (inf-le hclen 19) (inf-le cons0 cons0)))
   (given inf-stcl (lam g0 (inf-refl cons0))))
 (defcx inf-stcl-w1 inf-stcl (g0 (inf-le hclen 19)) (ip nat) (bc nat) (bb nat) (cons nat) (Cl (pi j nat nat)) (i nat) (a2 (pi k nat (inf-le (Cl k) 15))) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) )
; t1-1
 (defvc inf-vc-stcl-t1-1 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) (inf-le 32 w)))
   (given inf-stcl-w1 (lam w1 gw)))
; t1-2
 (defvc inf-vc-stcl-t1-2 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) (inf-lt (add n 8) (inf-pow w))))
   (given inf-stcl-w1 (lam w1 gn)))
; t1-3
 (defvc inf-vc-stcl-t1-3 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) (inf-le ip n)))
   (given inf-stcl-w1 (lam w1 r1)))
; t1-4
 (defvc inf-vc-stcl-t1-4 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) (inf-le bc 63)))
   (given inf-stcl-w1 (lam w1 r3)))
; t1-5
 (defvc inf-vc-stcl-t1-5 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) (inf-bits-inv carry ip cons bc)))
   (given inf-stcl-w1 (lam w1 r4)))
; t1-6
 (defvc inf-vc-stcl-t1-6 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) (inf-le 3 13)))
   (given inf-stcl-w1 (lam w1 (idpath false))))
; t1s-1
 (defvc inf-vc-stcl-t1s-1 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le ipt1 n)))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e1)))
; t1s-2
 (defvc inf-vc-stcl-t1s-2 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le bct1 63)))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e3)))
; t1s-3
 (defvc inf-vc-stcl-t1s-3 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e4)))
; t1s-4
 (defvc inf-vc-stcl-t1s-4 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le cons0 const1)))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 (inf-letrans cons0 cons const1 r5 t1e5))))
; t1s-5
 (defvc inf-vc-stcl-t1s-5 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 d1)))
; t1s-6
 (defvc inf-vc-stcl-t1s-6 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 d2)))
; t1s-7
 (defvc inf-vc-stcl-t1s-7 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 d3)))
; t1s-8
 (defvc inf-vc-stcl-t1s-8 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le prev0 15)))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 b1)))
; t1s-9
 (defvc inf-vc-stcl-t1s-9 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 b2)))
; t1s-10
 (defvc inf-vc-stcl-t1s-10 (under inf-stcl-w1 (pi w1 (inf-lt i hclen) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (pi k nat (inf-le (Cl k) 15))))
   (given inf-stcl-w1 (lam w1 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 a2)))
 (defcx inf-stcl-c1 inf-stcl-w1 (w1 (inf-lt i hclen)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e6 (inf-le (add cons 3) const1)) (t1e7 (inf-lt xt1 (inf-pow 3))) )
; s1-1
 (defvc inf-vc-stcl-s1-1 (under inf-stcl-c1 (inf-lt i 19))
   (given inf-stcl-c1 ((inf-lttrans i hclen 19 w1 g0))))
; s1-2
 (defvc inf-vc-stcl-s1-2 (under inf-stcl-c1 (inf-lt (Ob i) 19))
   (given inf-stcl-c1 (hord i ((inf-lttrans i hclen 19 w1 g0)))))
; s1-3
 (defvc inf-vc-stcl-s1-3 (under inf-stcl-c1 (inf-lt xt1 (inf-pow w)))
   (given inf-stcl-c1 (inf-lttrans xt1 8 (inf-pow w) t1e7 (inf-powle 3 w (inf-letrans 3 32 w (idpath false) gw)))))
; s2-1
 (defvc inf-vc-stcl-s2-1 (under inf-stcl-c1 (inf-lt (add i 1) (inf-pow w)))
   (given inf-stcl-c1 (inf-wlit (add i 1) w gw (inf-letrans (add i 1) 19 63 (inf-lt1 i 19 ((inf-lttrans i hclen 19 w1 g0))) (idpath false)))))
; w1b-1
 (defvc inf-vc-stcl-w1b-1 (under inf-stcl-c1 (pi k nat (inf-le ((inf-upd Cl (Ob i) xt1) k) 15)))
   (given inf-stcl-c1 (inf-updle Cl (Ob i) xt1 15 a2 (inf-letrans xt1 8 15 (inf-ltle xt1 8 t1e7) (idpath false)))))
; w1b-2
 (defvc inf-vc-stcl-w1b-2 (under inf-stcl-c1 (inf-le ipt1 n))
   (given inf-stcl-c1 t1e1))
; w1b-3
 (defvc inf-vc-stcl-w1b-3 (under inf-stcl-c1 (inf-le bct1 63))
   (given inf-stcl-c1 t1e3))
; w1b-4
 (defvc inf-vc-stcl-w1b-4 (under inf-stcl-c1 (inf-bits-inv carry ipt1 const1 bct1))
   (given inf-stcl-c1 t1e4))
; w1b-5
 (defvc inf-vc-stcl-w1b-5 (under inf-stcl-c1 (inf-le cons0 const1))
   (given inf-stcl-c1 (inf-letrans cons0 cons const1 r5 t1e5)))
; w1b-6
 (defvc inf-vc-stcl-w1b-6 (under inf-stcl-c1 (inf-lt (natminus hclen (add i 1)) (natminus hclen i)))
   (given inf-stcl-c1 (inf-subfall1 hclen i w1)))
; c1-1
 (defvc inf-vc-stcl-c1-1 (under inf-stcl-w1 (pi w1 (inf-le hclen i) (pi k nat g (inf-lt k 19) (inf-le (Cl k) 15))))
   (given inf-stcl-w1 (lam w1 (lam k g (a2 k)))))
; c1-2
 (defvc inf-vc-stcl-c1-2 (under inf-stcl-w1 (pi w1 (inf-le hclen i) (inf-lt 19 q)))
   (given inf-stcl-w1 (lam w1 (inf-lttrans 19 320 q (idpath true) (inf-ltle 320 q gq2)))))
; c1-3
 (defvc inf-vc-stcl-c1-3 (under inf-stcl-w1 (pi w1 (inf-le hclen i) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-stcl-w1 (lam w1 gq)))
; c1-4
 (defvc inf-vc-stcl-c1-4 (under inf-stcl-w1 (pi w1 (inf-le hclen i) (inf-le (inf-pow h) (inf-pow w))))
   (given inf-stcl-w1 (lam w1 ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))))
; c1-5
 (defvc inf-vc-stcl-c1-5 (under inf-stcl-w1 (pi w1 (inf-le hclen i) (inf-le CROOT 15)))
   (given inf-stcl-w1 (lam w1 gc)))
; c1-6
 (defvc inf-vc-stcl-c1-6 (under inf-stcl-w1 (pi w1 (inf-le hclen i) (inf-le 32 w)))
   (given inf-stcl-w1 (lam w1 gw)))
; c1-7
 (defvc inf-vc-stcl-c1-7 (under inf-stcl-w1 (pi w1 (inf-le hclen i) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-stcl-w1 (lam w1 gk)))
 (defcx inf-stcl-c2 inf-stcl-w1 (w1 (inf-le hclen i)) (Ccc1 (pi j nat nat)) (Csc1 (pi j nat nat)) (Ctc1 (pi j nat nat)) (c1e1 (pi z nat (inf-lt (Ccc1 z) (inf-pow h)))) (c1e2 (pi z nat (inf-lt (Csc1 z) (inf-pow h)))) (c1e3 (inf-le (inf-sum Ccc1 15 1) 19)) )
; d2-1
 (defvc inf-vc-stcl-d2-1 (under inf-stcl-c2 (pi id1 nat (inf-lt 0 (inf-pow w))))
   (given inf-stcl-c2 (lam id1 (inf-wlit 0 w gw (idpath false)))))
; r2-1
 (defvc inf-vc-stcl-r2-1 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (inf-le ip n)))
   (given inf-stcl-c2 (lam id1 staged3 moded4 r1)))
; r2-2
 (defvc inf-vc-stcl-r2-2 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (inf-le bc 63)))
   (given inf-stcl-c2 (lam id1 staged3 moded4 r3)))
; r2-3
 (defvc inf-vc-stcl-r2-3 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (inf-bits-inv carry ip cons bc)))
   (given inf-stcl-c2 (lam id1 staged3 moded4 r4)))
; r2-4
 (defvc inf-vc-stcl-r2-4 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (inf-le cons0 cons)))
   (given inf-stcl-c2 (lam id1 staged3 moded4 r5)))
; r2-5
 (defvc inf-vc-stcl-r2-5 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (pi k nat (inf-lt (Ccc1 k) (inf-pow h)))))
   (given inf-stcl-c2 (lam id1 staged3 moded4 c1e1)))
; r2-6
 (defvc inf-vc-stcl-r2-6 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (pi k nat (inf-lt (Csc1 k) (inf-pow h)))))
   (given inf-stcl-c2 (lam id1 staged3 moded4 c1e2)))
; r2-7
 (defvc inf-vc-stcl-r2-7 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (inf-le (inf-sum Ccc1 15 1) 19)))
   (given inf-stcl-c2 (lam id1 staged3 moded4 c1e3)))
; r2-8
 (defvc inf-vc-stcl-r2-8 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (inf-le 0 15)))
   (given inf-stcl-c2 (lam id1 staged3 moded4 (idpath false))))
; r2-9
 (defvc inf-vc-stcl-r2-9 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (pi j nat (inf-le (inf-zero j) 15))))
   (given inf-stcl-c2 (lam id1 staged3 moded4 (lam j (idpath false)))))
; r2-10
 (defvc inf-vc-stcl-r2-10 (under inf-stcl-c2 (pi id1 nat staged3 nat moded4 nat (pi k nat (inf-le (Cl k) 15))))
   (given inf-stcl-c2 (lam id1 staged3 moded4 a2)))
 (defcx inf-stln (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Cc (pi k nat nat)) (Cs (pi k nat nat)) (Ct (pi k nat nat)) (d1 (pi k nat (inf-lt (Cc k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc 15 1) 19)) (Lz0 (pi k nat nat)) (hlit nat) (hdist nat) (b2 (pi j nat (inf-le (Lz0 j) 15))) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (mode0 nat) (b1 (inf-le prev0 15)) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) )
; r0-1
 (defvc inf-vc-stln-r0-1 (under inf-stln (pi g0 (inf-lt 288 hlit) (inf-le ip0 n)))
   (given inf-stln (lam g0 gi)))
; r0-2
 (defvc inf-vc-stln-r0-2 (under inf-stln (pi g0 (inf-lt 288 hlit) (inf-le bc0 63)))
   (given inf-stln (lam g0 gs)))
; r0-3
 (defvc inf-vc-stln-r0-3 (under inf-stln (pi g0 (inf-lt 288 hlit) (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-stln (lam g0 ga)))
; r0-4
 (defvc inf-vc-stln-r0-4 (under inf-stln (pi g0 (inf-lt 288 hlit) (inf-le cons0 cons0)))
   (given inf-stln (lam g0 (inf-refl cons0))))
; r0-5
 (defvc inf-vc-stln-r0-5 (under inf-stln (pi g0 (inf-lt 288 hlit) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stln (lam g0 c1)))
; r0-6
 (defvc inf-vc-stln-r0-6 (under inf-stln (pi g0 (inf-lt 288 hlit) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stln (lam g0 c2)))
; r0-7
 (defvc inf-vc-stln-r0-7 (under inf-stln (pi g0 (inf-lt 288 hlit) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stln (lam g0 c3)))
; r0-8
 (defvc inf-vc-stln-r0-8 (under inf-stln (pi g0 (inf-lt 288 hlit) (inf-le lm0 288)))
   (given inf-stln (lam g0 c4)))
; r0-9
 (defvc inf-vc-stln-r0-9 (under inf-stln (pi g0 (inf-lt 288 hlit) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stln (lam g0 c5)))
; r0-10
 (defvc inf-vc-stln-r0-10 (under inf-stln (pi g0 (inf-lt 288 hlit) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stln (lam g0 c6)))
; r0-11
 (defvc inf-vc-stln-r0-11 (under inf-stln (pi g0 (inf-lt 288 hlit) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stln (lam g0 c7)))
; r0-12
 (defvc inf-vc-stln-r0-12 (under inf-stln (pi g0 (inf-lt 288 hlit) (inf-le dm0 32)))
   (given inf-stln (lam g0 c8)))
; r0-13
 (defvc inf-vc-stln-r0-13 (under inf-stln (pi g0 (inf-lt 288 hlit) (inf-le prev0 15)))
   (given inf-stln (lam g0 b1)))
; r0-14
 (defvc inf-vc-stln-r0-14 (under inf-stln (pi g0 (inf-lt 288 hlit) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-stln (lam g0 b2)))
; r00-1
 (defvc inf-vc-stln-r00-1 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (inf-le ip0 n)))
   (given inf-stln (lam g0 g00 gi)))
; r00-2
 (defvc inf-vc-stln-r00-2 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (inf-le bc0 63)))
   (given inf-stln (lam g0 g00 gs)))
; r00-3
 (defvc inf-vc-stln-r00-3 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-stln (lam g0 g00 ga)))
; r00-4
 (defvc inf-vc-stln-r00-4 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (inf-le cons0 cons0)))
   (given inf-stln (lam g0 g00 (inf-refl cons0))))
; r00-5
 (defvc inf-vc-stln-r00-5 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stln (lam g0 g00 c1)))
; r00-6
 (defvc inf-vc-stln-r00-6 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stln (lam g0 g00 c2)))
; r00-7
 (defvc inf-vc-stln-r00-7 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stln (lam g0 g00 c3)))
; r00-8
 (defvc inf-vc-stln-r00-8 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (inf-le lm0 288)))
   (given inf-stln (lam g0 g00 c4)))
; r00-9
 (defvc inf-vc-stln-r00-9 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stln (lam g0 g00 c5)))
; r00-10
 (defvc inf-vc-stln-r00-10 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stln (lam g0 g00 c6)))
; r00-11
 (defvc inf-vc-stln-r00-11 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stln (lam g0 g00 c7)))
; r00-12
 (defvc inf-vc-stln-r00-12 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (inf-le dm0 32)))
   (given inf-stln (lam g0 g00 c8)))
; r00-13
 (defvc inf-vc-stln-r00-13 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (inf-le prev0 15)))
   (given inf-stln (lam g0 g00 b1)))
; r00-14
 (defvc inf-vc-stln-r00-14 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-lt 32 hdist) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-stln (lam g0 g00 b2)))
; s0-1
 (defvc inf-vc-stln-s0-1 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-le hdist 32) (inf-lt (add hlit hdist) (inf-pow w))))
   (given inf-stln (lam g0 g00 (inf-lelt (add hlit hdist) 320 (inf-pow w) ((inf-add2 hlit 288 hdist 32 g0 g00)) ((inf-lelt 320 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; w1e-1
 (defvc inf-vc-stln-w1e-1 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-le hdist 32) (inf-le prev0 15)))
   (given inf-stln (lam g0 g00 b1)))
; w1e-2
 (defvc inf-vc-stln-w1e-2 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-le hdist 32) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-stln (lam g0 g00 b2)))
; w1e-3
 (defvc inf-vc-stln-w1e-3 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-le hdist 32) (inf-le ip0 n)))
   (given inf-stln (lam g0 g00 gi)))
; w1e-4
 (defvc inf-vc-stln-w1e-4 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-le hdist 32) (inf-le bc0 63)))
   (given inf-stln (lam g0 g00 gs)))
; w1e-5
 (defvc inf-vc-stln-w1e-5 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-le hdist 32) (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-stln (lam g0 g00 ga)))
; w1e-6
 (defvc inf-vc-stln-w1e-6 (under inf-stln (pi g0 (inf-le hlit 288) g00 (inf-le hdist 32) (inf-le cons0 cons0)))
   (given inf-stln (lam g0 g00 (inf-refl cons0))))
 (defcx inf-stln-w1 inf-stln (g0 (inf-le hlit 288)) (g00 (inf-le hdist 32)) (ip nat) (bc nat) (bb nat) (cons nat) (Lz (pi j nat nat)) (i nat) (prev nat) (stage nat) (sy nat) (b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) )
; t1-1
 (defvc inf-vc-stln-t1-1 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (inf-le 32 w)))
   (given inf-stln-w1 (lam w1 g2 gw)))
; t1-2
 (defvc inf-vc-stln-t1-2 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (inf-lt (add n 8) (inf-pow w))))
   (given inf-stln-w1 (lam w1 g2 gn)))
; t1-3
 (defvc inf-vc-stln-t1-3 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (inf-le ip n)))
   (given inf-stln-w1 (lam w1 g2 r1)))
; t1-4
 (defvc inf-vc-stln-t1-4 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (inf-le bc 63)))
   (given inf-stln-w1 (lam w1 g2 r3)))
; t1-5
 (defvc inf-vc-stln-t1-5 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (inf-bits-inv carry ip cons bc)))
   (given inf-stln-w1 (lam w1 g2 r4)))
; t1-6
 (defvc inf-vc-stln-t1-6 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (pi i nat (inf-lt (Cc i) (inf-pow h)))))
   (given inf-stln-w1 (lam w1 g2 d1)))
; t1-7
 (defvc inf-vc-stln-t1-7 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (pi i nat (inf-lt (Cs i) (inf-pow h)))))
   (given inf-stln-w1 (lam w1 g2 d2)))
; t1-8
 (defvc inf-vc-stln-t1-8 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (inf-le h 16)))
   (given inf-stln-w1 (lam w1 g2 gh)))
; t1-9
 (defvc inf-vc-stln-t1-9 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (inf-lt 19 (inf-pow w))))
   (given inf-stln-w1 (lam w1 g2 (inf-wlit 19 w gw (idpath false)))))
; t1-10
 (defvc inf-vc-stln-t1-10 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (inf-le (inf-sum Cc 15 1) 19)))
   (given inf-stln-w1 (lam w1 g2 d3)))
; t1-11
 (defvc inf-vc-stln-t1-11 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) (inf-le CROOT 15)))
   (given inf-stln-w1 (lam w1 g2 gc)))
; t1s-1
 (defvc inf-vc-stln-t1s-1 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le ipt1 n)))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e1)))
; t1s-2
 (defvc inf-vc-stln-t1s-2 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le bct1 63)))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e3)))
; t1s-3
 (defvc inf-vc-stln-t1s-3 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 t1e4)))
; t1s-4
 (defvc inf-vc-stln-t1s-4 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le cons0 const1)))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 (inf-letrans cons0 cons const1 r5 t1e5))))
; t1s-5
 (defvc inf-vc-stln-t1s-5 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c1)))
; t1s-6
 (defvc inf-vc-stln-t1s-6 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c2)))
; t1s-7
 (defvc inf-vc-stln-t1s-7 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c3)))
; t1s-8
 (defvc inf-vc-stln-t1s-8 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le lm0 288)))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c4)))
; t1s-9
 (defvc inf-vc-stln-t1s-9 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c5)))
; t1s-10
 (defvc inf-vc-stln-t1s-10 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c6)))
; t1s-11
 (defvc inf-vc-stln-t1s-11 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c7)))
; t1s-12
 (defvc inf-vc-stln-t1s-12 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le dm0 32)))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 c8)))
; t1s-13
 (defvc inf-vc-stln-t1s-13 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (inf-le prev 15)))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 b1)))
; t1s-14
 (defvc inf-vc-stln-t1s-14 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (paths nat stage 0) ipt1 nat bct1 nat bbt1 nat const1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) (pi j nat (inf-le (Lz j) 15))))
   (given inf-stln-w1 (lam w1 g2 ipt1 bct1 bbt1 const1 xt1 t1e1 t1e3 t1e4 t1e5 b2)))
 (defcx inf-stln-c8 inf-stln-w1 (w1 (inf-lt i (add hlit hdist))) (g2 (paths nat stage 0)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) )
; j0j-1
 (defvc inf-vc-stln-j0j-1 (under inf-stln-c8 (pi syd1 nat staged2 nat (inf-le ipt1 n)))
   (given inf-stln-c8 (lam syd1 staged2 t1e1)))
; j0j-2
 (defvc inf-vc-stln-j0j-2 (under inf-stln-c8 (pi syd1 nat staged2 nat (inf-le bct1 63)))
   (given inf-stln-c8 (lam syd1 staged2 t1e3)))
; j0j-3
 (defvc inf-vc-stln-j0j-3 (under inf-stln-c8 (pi syd1 nat staged2 nat (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-stln-c8 (lam syd1 staged2 t1e4)))
; j0j-4
 (defvc inf-vc-stln-j0j-4 (under inf-stln-c8 (pi syd1 nat staged2 nat (inf-le cons0 const1)))
   (given inf-stln-c8 (lam syd1 staged2 (inf-letrans cons0 cons const1 r5 t1e5))))
; j0j-5
 (defvc inf-vc-stln-j0j-5 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (inf-lt 0 stage) (inf-le ip n)))
   (given inf-stln-w1 (lam w1 g2 r1)))
; j0j-6
 (defvc inf-vc-stln-j0j-6 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (inf-lt 0 stage) (inf-le bc 63)))
   (given inf-stln-w1 (lam w1 g2 r3)))
; j0j-7
 (defvc inf-vc-stln-j0j-7 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (inf-lt 0 stage) (inf-bits-inv carry ip cons bc)))
   (given inf-stln-w1 (lam w1 g2 r4)))
; j0j-8
 (defvc inf-vc-stln-j0j-8 (under inf-stln-w1 (pi w1 (inf-lt i (add hlit hdist)) g2 (inf-lt 0 stage) (inf-le cons0 cons)))
   (given inf-stln-w1 (lam w1 g2 r5)))
 (defcx inf-stln-c1 inf-stln-w1 (w1 (inf-lt i (add hlit hdist))) (ipj0 nat) (bcj0 nat) (bbj0 nat) (consj0 nat) (syj0 nat) (stagej0 nat) (r1 (inf-le ipj0 n)) (r3 (inf-le bcj0 63)) (r4 (inf-bits-inv carry ipj0 consj0 bcj0)) (r5 (inf-le cons0 consj0)) )
; s1-1
 (defvc inf-vc-stln-s1-1 (under inf-stln-c1 (pi g3 (inf-lt syj0 16) (inf-lt 1 (inf-pow w))))
   (given inf-stln-c1 (lam g3 (inf-wlit 1 w gw (idpath false)))))
; s2-1
 (defvc inf-vc-stln-s2-1 (under inf-stln-c1 (pi g3 (inf-lt syj0 16) (inf-lt syj0 (inf-pow w))))
   (given inf-stln-c1 (lam g3 (inf-wlit syj0 w gw (inf-letrans syj0 16 63 (inf-ltle syj0 16 g3) (idpath false))))))
; j1j-1
 (defvc inf-vc-stln-j1j-1 (under inf-stln-c1 (pi g3 (inf-lt syj0 16) (inf-lt 0 1)))
   (given inf-stln-c1 (lam g3 (idpath true))))
; j1j-2
 (defvc inf-vc-stln-j1j-2 (under inf-stln-c1 (pi g3 (inf-lt syj0 16) (inf-le 1 138)))
   (given inf-stln-c1 (lam g3 (idpath false))))
; j1j-3
 (defvc inf-vc-stln-j1j-3 (under inf-stln-c1 (pi g3 (inf-lt syj0 16) (inf-le syj0 15)))
   (given inf-stln-c1 (lam g3 (inf-ltsle syj0 15 g3))))
; j1j-4
 (defvc inf-vc-stln-j1j-4 (under inf-stln-c1 (pi g3 (inf-lt syj0 16) (inf-le ipj0 n)))
   (given inf-stln-c1 (lam g3 r1)))
; j1j-5
 (defvc inf-vc-stln-j1j-5 (under inf-stln-c1 (pi g3 (inf-lt syj0 16) (inf-le bcj0 63)))
   (given inf-stln-c1 (lam g3 r3)))
; j1j-6
 (defvc inf-vc-stln-j1j-6 (under inf-stln-c1 (pi g3 (inf-lt syj0 16) (inf-bits-inv carry ipj0 consj0 bcj0)))
   (given inf-stln-c1 (lam g3 r4)))
; j1j-7
 (defvc inf-vc-stln-j1j-7 (under inf-stln-c1 (pi g3 (inf-lt syj0 16) (inf-le cons0 consj0)))
   (given inf-stln-c1 (lam g3 r5)))
; r1-1
 (defvc inf-vc-stln-r1-1 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (inf-le ipj0 n)))
   (given inf-stln-c1 (lam g3 g4 r1)))
; r1-2
 (defvc inf-vc-stln-r1-2 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (inf-le bcj0 63)))
   (given inf-stln-c1 (lam g3 g4 r3)))
; r1-3
 (defvc inf-vc-stln-r1-3 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (inf-bits-inv carry ipj0 consj0 bcj0)))
   (given inf-stln-c1 (lam g3 g4 r4)))
; r1-4
 (defvc inf-vc-stln-r1-4 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (inf-le cons0 consj0)))
   (given inf-stln-c1 (lam g3 g4 r5)))
; r1-5
 (defvc inf-vc-stln-r1-5 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 c1)))
; r1-6
 (defvc inf-vc-stln-r1-6 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 c2)))
; r1-7
 (defvc inf-vc-stln-r1-7 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stln-c1 (lam g3 g4 c3)))
; r1-8
 (defvc inf-vc-stln-r1-8 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (inf-le lm0 288)))
   (given inf-stln-c1 (lam g3 g4 c4)))
; r1-9
 (defvc inf-vc-stln-r1-9 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 c5)))
; r1-10
 (defvc inf-vc-stln-r1-10 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 c6)))
; r1-11
 (defvc inf-vc-stln-r1-11 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stln-c1 (lam g3 g4 c7)))
; r1-12
 (defvc inf-vc-stln-r1-12 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (inf-le dm0 32)))
   (given inf-stln-c1 (lam g3 g4 c8)))
; r1-13
 (defvc inf-vc-stln-r1-13 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (inf-le prev 15)))
   (given inf-stln-c1 (lam g3 g4 b1)))
; r1-14
 (defvc inf-vc-stln-r1-14 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-lt 18 syj0) (pi j nat (inf-le (Lz j) 15))))
   (given inf-stln-c1 (lam g3 g4 b2)))
; t2-1
 (defvc inf-vc-stln-t2-1 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) (inf-le 32 w)))
   (given inf-stln-c1 (lam g3 g4 g5 gw)))
; t2-2
 (defvc inf-vc-stln-t2-2 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) (inf-lt (add n 8) (inf-pow w))))
   (given inf-stln-c1 (lam g3 g4 g5 gn)))
; t2-3
 (defvc inf-vc-stln-t2-3 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) (inf-le ipj0 n)))
   (given inf-stln-c1 (lam g3 g4 g5 r1)))
; t2-4
 (defvc inf-vc-stln-t2-4 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) (inf-le bcj0 63)))
   (given inf-stln-c1 (lam g3 g4 g5 r3)))
; t2-5
 (defvc inf-vc-stln-t2-5 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) (inf-bits-inv carry ipj0 consj0 bcj0)))
   (given inf-stln-c1 (lam g3 g4 g5 r4)))
; t2-6
 (defvc inf-vc-stln-t2-6 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) (inf-le 2 13)))
   (given inf-stln-c1 (lam g3 g4 g5 (idpath false))))
; t2s-1
 (defvc inf-vc-stln-t2s-1 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (inf-le ipt2 n)))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 t2e1)))
; t2s-2
 (defvc inf-vc-stln-t2s-2 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (inf-le bct2 63)))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 t2e3)))
; t2s-3
 (defvc inf-vc-stln-t2s-3 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 t2e4)))
; t2s-4
 (defvc inf-vc-stln-t2s-4 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (inf-le cons0 const2)))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 (inf-letrans cons0 consj0 const2 r5 t2e5))))
; t2s-5
 (defvc inf-vc-stln-t2s-5 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 c1)))
; t2s-6
 (defvc inf-vc-stln-t2s-6 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 c2)))
; t2s-7
 (defvc inf-vc-stln-t2s-7 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 c3)))
; t2s-8
 (defvc inf-vc-stln-t2s-8 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (inf-le lm0 288)))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 c4)))
; t2s-9
 (defvc inf-vc-stln-t2s-9 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 c5)))
; t2s-10
 (defvc inf-vc-stln-t2s-10 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 c6)))
; t2s-11
 (defvc inf-vc-stln-t2s-11 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 c7)))
; t2s-12
 (defvc inf-vc-stln-t2s-12 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (inf-le dm0 32)))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 c8)))
; t2s-13
 (defvc inf-vc-stln-t2s-13 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (inf-le prev 15)))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 b1)))
; t2s-14
 (defvc inf-vc-stln-t2s-14 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-le syj0 16) ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj0 const2) (pi j nat (inf-le (Lz j) 15))))
   (given inf-stln-c1 (lam g3 g4 g5 ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 b2)))
 (defcx inf-stln-c7 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (g5 (inf-le syj0 16)) (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le consj0 const2)) (t2e6 (inf-le (add consj0 2) const2)) (t2e7 (inf-lt xt2 (inf-pow 2))) )
; s3-1
 (defvc inf-vc-stln-s3-1 (under inf-stln-c7 (inf-lt (add xt2 3) (inf-pow w)))
   (given inf-stln-c7 (inf-wlit (add xt2 3) w gw (inf-letrans (add xt2 3) 6 63 ((inf-addr xt2 3 3 (inf-ltsle xt2 3 t2e7))) (idpath false)))))
; s4-1
 (defvc inf-vc-stln-s4-1 (under inf-stln-c7 (inf-lt prev (inf-pow w)))
   (given inf-stln-c7 (inf-wlit prev w gw (inf-letrans prev 15 63 b1 (idpath false)))))
; j2j-1
 (defvc inf-vc-stln-j2j-1 (under inf-stln-c7 (inf-lt 0 (add xt2 3)))
   (given inf-stln-c7 (inf-pos3 xt2 3 (idpath true))))
; j2j-2
 (defvc inf-vc-stln-j2j-2 (under inf-stln-c7 (inf-le (add xt2 3) 138))
   (given inf-stln-c7 (inf-letrans (add xt2 3) 6 138 ((inf-addr xt2 3 3 (inf-ltsle xt2 3 t2e7))) (idpath false))))
; j2j-3
 (defvc inf-vc-stln-j2j-3 (under inf-stln-c7 (inf-le prev 15))
   (given inf-stln-c7 b1))
; j2j-4
 (defvc inf-vc-stln-j2j-4 (under inf-stln-c7 (inf-le ipt2 n))
   (given inf-stln-c7 t2e1))
; j2j-5
 (defvc inf-vc-stln-j2j-5 (under inf-stln-c7 (inf-le bct2 63))
   (given inf-stln-c7 t2e3))
; j2j-6
 (defvc inf-vc-stln-j2j-6 (under inf-stln-c7 (inf-bits-inv carry ipt2 const2 bct2))
   (given inf-stln-c7 t2e4))
; j2j-7
 (defvc inf-vc-stln-j2j-7 (under inf-stln-c7 (inf-le cons0 const2))
   (given inf-stln-c7 (inf-letrans cons0 consj0 const2 r5 t2e5)))
; t3-1
 (defvc inf-vc-stln-t3-1 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) (inf-le 32 w)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 gw)))
; t3-2
 (defvc inf-vc-stln-t3-2 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) (inf-lt (add n 8) (inf-pow w))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 gn)))
; t3-3
 (defvc inf-vc-stln-t3-3 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) (inf-le ipj0 n)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 r1)))
; t3-4
 (defvc inf-vc-stln-t3-4 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) (inf-le bcj0 63)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 r3)))
; t3-5
 (defvc inf-vc-stln-t3-5 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) (inf-bits-inv carry ipj0 consj0 bcj0)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 r4)))
; t3-6
 (defvc inf-vc-stln-t3-6 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) (inf-le 3 13)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 (idpath false))))
; t3s-1
 (defvc inf-vc-stln-t3s-1 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (inf-le ipt3 n)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 t3e1)))
; t3s-2
 (defvc inf-vc-stln-t3s-2 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (inf-le bct3 63)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 t3e3)))
; t3s-3
 (defvc inf-vc-stln-t3s-3 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (inf-bits-inv carry ipt3 const3 bct3)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 t3e4)))
; t3s-4
 (defvc inf-vc-stln-t3s-4 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (inf-le cons0 const3)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 (inf-letrans cons0 consj0 const3 r5 t3e5))))
; t3s-5
 (defvc inf-vc-stln-t3s-5 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 c1)))
; t3s-6
 (defvc inf-vc-stln-t3s-6 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 c2)))
; t3s-7
 (defvc inf-vc-stln-t3s-7 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 c3)))
; t3s-8
 (defvc inf-vc-stln-t3s-8 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (inf-le lm0 288)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 c4)))
; t3s-9
 (defvc inf-vc-stln-t3s-9 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 c5)))
; t3s-10
 (defvc inf-vc-stln-t3s-10 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 c6)))
; t3s-11
 (defvc inf-vc-stln-t3s-11 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 c7)))
; t3s-12
 (defvc inf-vc-stln-t3s-12 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (inf-le dm0 32)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 c8)))
; t3s-13
 (defvc inf-vc-stln-t3s-13 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (inf-le prev 15)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 b1)))
; t3s-14
 (defvc inf-vc-stln-t3s-14 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-le syj0 17) ipt3 nat bct3 nat bbt3 nat const3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj0 const3) (pi j nat (inf-le (Lz j) 15))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt3 bct3 bbt3 const3 xt3 t3e1 t3e3 t3e4 t3e5 b2)))
 (defcx inf-stln-c6 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (g5 (inf-lt 16 syj0)) (g6 (inf-le syj0 17)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le consj0 const3)) (t3e6 (inf-le (add consj0 3) const3)) (t3e7 (inf-lt xt3 (inf-pow 3))) )
; s5-1
 (defvc inf-vc-stln-s5-1 (under inf-stln-c6 (inf-lt (add xt3 3) (inf-pow w)))
   (given inf-stln-c6 (inf-wlit (add xt3 3) w gw (inf-letrans (add xt3 3) 10 63 ((inf-addr xt3 7 3 (inf-ltsle xt3 7 t3e7))) (idpath false)))))
; j3j-1
 (defvc inf-vc-stln-j3j-1 (under inf-stln-c6 (inf-lt 0 (add xt3 3)))
   (given inf-stln-c6 (inf-pos3 xt3 3 (idpath true))))
; j3j-2
 (defvc inf-vc-stln-j3j-2 (under inf-stln-c6 (inf-le (add xt3 3) 138))
   (given inf-stln-c6 (inf-letrans (add xt3 3) 10 138 ((inf-addr xt3 7 3 (inf-ltsle xt3 7 t3e7))) (idpath false))))
; j3j-3
 (defvc inf-vc-stln-j3j-3 (under inf-stln-c6 (inf-le ipt3 n))
   (given inf-stln-c6 t3e1))
; j3j-4
 (defvc inf-vc-stln-j3j-4 (under inf-stln-c6 (inf-le bct3 63))
   (given inf-stln-c6 t3e3))
; j3j-5
 (defvc inf-vc-stln-j3j-5 (under inf-stln-c6 (inf-bits-inv carry ipt3 const3 bct3))
   (given inf-stln-c6 t3e4))
; j3j-6
 (defvc inf-vc-stln-j3j-6 (under inf-stln-c6 (inf-le cons0 const3))
   (given inf-stln-c6 (inf-letrans cons0 consj0 const3 r5 t3e5)))
; t4-1
 (defvc inf-vc-stln-t4-1 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) (inf-le 32 w)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 gw)))
; t4-2
 (defvc inf-vc-stln-t4-2 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) (inf-lt (add n 8) (inf-pow w))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 gn)))
; t4-3
 (defvc inf-vc-stln-t4-3 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) (inf-le ipj0 n)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 r1)))
; t4-4
 (defvc inf-vc-stln-t4-4 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) (inf-le bcj0 63)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 r3)))
; t4-5
 (defvc inf-vc-stln-t4-5 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) (inf-bits-inv carry ipj0 consj0 bcj0)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 r4)))
; t4-6
 (defvc inf-vc-stln-t4-6 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) (inf-le 7 13)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 (idpath false))))
; t4s-1
 (defvc inf-vc-stln-t4s-1 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (inf-le ipt4 n)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 t4e1)))
; t4s-2
 (defvc inf-vc-stln-t4s-2 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (inf-le bct4 63)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 t4e3)))
; t4s-3
 (defvc inf-vc-stln-t4s-3 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (inf-bits-inv carry ipt4 const4 bct4)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 t4e4)))
; t4s-4
 (defvc inf-vc-stln-t4s-4 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (inf-le cons0 const4)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 (inf-letrans cons0 consj0 const4 r5 t4e5))))
; t4s-5
 (defvc inf-vc-stln-t4s-5 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 c1)))
; t4s-6
 (defvc inf-vc-stln-t4s-6 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 c2)))
; t4s-7
 (defvc inf-vc-stln-t4s-7 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 c3)))
; t4s-8
 (defvc inf-vc-stln-t4s-8 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (inf-le lm0 288)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 c4)))
; t4s-9
 (defvc inf-vc-stln-t4s-9 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 c5)))
; t4s-10
 (defvc inf-vc-stln-t4s-10 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 c6)))
; t4s-11
 (defvc inf-vc-stln-t4s-11 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 c7)))
; t4s-12
 (defvc inf-vc-stln-t4s-12 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (inf-le dm0 32)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 c8)))
; t4s-13
 (defvc inf-vc-stln-t4s-13 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (inf-le prev 15)))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 b1)))
; t4s-14
 (defvc inf-vc-stln-t4s-14 (under inf-stln-c1 (pi g3 (inf-le 16 syj0) g4 (inf-le syj0 18) g5 (inf-lt 16 syj0) g6 (inf-lt 17 syj0) ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj0 const4) (pi j nat (inf-le (Lz j) 15))))
   (given inf-stln-c1 (lam g3 g4 g5 g6 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 b2)))
 (defcx inf-stln-c5 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (g5 (inf-lt 16 syj0)) (g6 (inf-lt 17 syj0)) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le consj0 const4)) (t4e6 (inf-le (add consj0 7) const4)) (t4e7 (inf-lt xt4 (inf-pow 7))) )
; s6-1
 (defvc inf-vc-stln-s6-1 (under inf-stln-c5 (inf-lt (add xt4 11) (inf-pow w)))
   (given inf-stln-c5 (inf-lelt (add xt4 11) 512 (inf-pow w) (inf-letrans (add xt4 11) 138 512 ((inf-addr xt4 127 11 (inf-ltsle xt4 127 t4e7))) (idpath false)) (inf-lttrans 512 1024 (inf-pow w) (idpath true) (inf-powle 10 w (inf-letrans 10 32 w (idpath false) gw))))))
; j3j-7
 (defvc inf-vc-stln-j3j-7 (under inf-stln-c5 (inf-lt 0 (add xt4 11)))
   (given inf-stln-c5 (inf-pos3 xt4 11 (idpath true))))
; j3j-8
 (defvc inf-vc-stln-j3j-8 (under inf-stln-c5 (inf-le (add xt4 11) 138))
   (given inf-stln-c5 ((inf-addr xt4 127 11 (inf-ltsle xt4 127 t4e7)))))
; j3j-9
 (defvc inf-vc-stln-j3j-9 (under inf-stln-c5 (inf-le ipt4 n))
   (given inf-stln-c5 t4e1))
; j3j-10
 (defvc inf-vc-stln-j3j-10 (under inf-stln-c5 (inf-le bct4 63))
   (given inf-stln-c5 t4e3))
; j3j-11
 (defvc inf-vc-stln-j3j-11 (under inf-stln-c5 (inf-bits-inv carry ipt4 const4 bct4))
   (given inf-stln-c5 t4e4))
; j3j-12
 (defvc inf-vc-stln-j3j-12 (under inf-stln-c5 (inf-le cons0 const4))
   (given inf-stln-c5 (inf-letrans cons0 consj0 const4 r5 t4e5)))
 (defcx inf-stln-c4 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (g5 (inf-lt 16 syj0)) (ipj3 nat) (bcj3 nat) (bbj3 nat) (consj3 nat) (rrj3 nat) (f1 (inf-lt 0 rrj3)) (f2 (inf-le rrj3 138)) (r1 (inf-le ipj3 n)) (r3 (inf-le bcj3 63)) (r4 (inf-bits-inv carry ipj3 consj3 bcj3)) (r5 (inf-le cons0 consj3)) )
; s7-1
 (defvc inf-vc-stln-s7-1 (under inf-stln-c4 (inf-lt 0 (inf-pow w)))
   (given inf-stln-c4 (inf-wlit 0 w gw (idpath false))))
; j2j-8
 (defvc inf-vc-stln-j2j-8 (under inf-stln-c4 (inf-lt 0 rrj3))
   (given inf-stln-c4 f1))
; j2j-9
 (defvc inf-vc-stln-j2j-9 (under inf-stln-c4 (inf-le rrj3 138))
   (given inf-stln-c4 f2))
; j2j-10
 (defvc inf-vc-stln-j2j-10 (under inf-stln-c4 (inf-le 0 15))
   (given inf-stln-c4 (idpath false)))
; j2j-11
 (defvc inf-vc-stln-j2j-11 (under inf-stln-c4 (inf-le ipj3 n))
   (given inf-stln-c4 r1))
; j2j-12
 (defvc inf-vc-stln-j2j-12 (under inf-stln-c4 (inf-le bcj3 63))
   (given inf-stln-c4 r3))
; j2j-13
 (defvc inf-vc-stln-j2j-13 (under inf-stln-c4 (inf-bits-inv carry ipj3 consj3 bcj3))
   (given inf-stln-c4 r4))
; j2j-14
 (defvc inf-vc-stln-j2j-14 (under inf-stln-c4 (inf-le cons0 consj3))
   (given inf-stln-c4 r5))
 (defcx inf-stln-c3 inf-stln-c1 (g3 (inf-le 16 syj0)) (g4 (inf-le syj0 18)) (ipj2 nat) (bcj2 nat) (bbj2 nat) (consj2 nat) (rrj2 nat) (vj2 nat) (f3 (inf-lt 0 rrj2)) (f4 (inf-le rrj2 138)) (f5 (inf-le vj2 15)) (r1 (inf-le ipj2 n)) (r3 (inf-le bcj2 63)) (r4 (inf-bits-inv carry ipj2 consj2 bcj2)) (r5 (inf-le cons0 consj2)) )
; j1j-8
 (defvc inf-vc-stln-j1j-8 (under inf-stln-c3 (inf-lt 0 rrj2))
   (given inf-stln-c3 f3))
; j1j-9
 (defvc inf-vc-stln-j1j-9 (under inf-stln-c3 (inf-le rrj2 138))
   (given inf-stln-c3 f4))
; j1j-10
 (defvc inf-vc-stln-j1j-10 (under inf-stln-c3 (inf-le vj2 15))
   (given inf-stln-c3 f5))
; j1j-11
 (defvc inf-vc-stln-j1j-11 (under inf-stln-c3 (inf-le ipj2 n))
   (given inf-stln-c3 r1))
; j1j-12
 (defvc inf-vc-stln-j1j-12 (under inf-stln-c3 (inf-le bcj2 63))
   (given inf-stln-c3 r3))
; j1j-13
 (defvc inf-vc-stln-j1j-13 (under inf-stln-c3 (inf-bits-inv carry ipj2 consj2 bcj2))
   (given inf-stln-c3 r4))
; j1j-14
 (defvc inf-vc-stln-j1j-14 (under inf-stln-c3 (inf-le cons0 consj2))
   (given inf-stln-c3 r5))
 (defcx inf-stln-c2 inf-stln-c1 (rrj1 nat) (vj1 nat) (ipj1 nat) (bcj1 nat) (bbj1 nat) (consj1 nat) (f6 (inf-lt 0 rrj1)) (f7 (inf-le rrj1 138)) (f8 (inf-le vj1 15)) (r1 (inf-le ipj1 n)) (r3 (inf-le bcj1 63)) (r4 (inf-bits-inv carry ipj1 consj1 bcj1)) (r5 (inf-le cons0 consj1)) )
; w3e-1
 (defvc inf-vc-stln-w3e-1 (under inf-stln-c2 (inf-le 0 rrj1))
   (given inf-stln-c2 (idpath false)))
; w3e-2
 (defvc inf-vc-stln-w3e-2 (under inf-stln-c2 (pi j nat (inf-le (Lz j) 15)))
   (given inf-stln-c2 b2))
 (defcx inf-stln-c2-w3 inf-stln-c2 (k nat) (Lz (pi j nat nat)) (c1 (inf-le k rrj1)) (c2 (pi j nat (inf-le (Lz j) 15))) )
; i2-1
 (defvc inf-vc-stln-i2-1 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) (inf-lt (add i k) (inf-pow w))))
   (given inf-stln-c2-w3 (lam w3 (inf-lelt (add i k) 458 (inf-pow w) ((inf-add2 i 320 k 138 ((inf-letrans i (add hlit hdist) 320 (inf-ltle i (add hlit hdist) w1) ((inf-add2 hlit 288 hdist 32 g0 g00)))) (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7))) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; s8-1
 (defvc inf-vc-stln-s8-1 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-lt (add i k) 320) (inf-lt (add i k) (inf-pow w))))
   (given inf-stln-c2-w3 (lam w3 g7 (inf-lelt (add i k) 458 (inf-pow w) ((inf-add2 i 320 k 138 ((inf-letrans i (add hlit hdist) 320 (inf-ltle i (add hlit hdist) w1) ((inf-add2 hlit 288 hdist 32 g0 g00)))) (inf-letrans k rrj1 138 (inf-ltle k rrj1 w3) f7))) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; s8-2
 (defvc inf-vc-stln-s8-2 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-lt (add i k) 320) (inf-lt (add i k) 320)))
   (given inf-stln-c2-w3 (lam w3 g7 g7)))
; s8-3
 (defvc inf-vc-stln-s8-3 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-lt (add i k) 320) (inf-lt vj1 (inf-pow w))))
   (given inf-stln-c2-w3 (lam w3 g7 (inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false))))))
; w3b-1
 (defvc inf-vc-stln-w3b-1 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-lt (add i k) 320) (inf-lt (succ k) (inf-pow w))))
   (given inf-stln-c2-w3 (lam w3 g7 (inf-lelt (succ k) 138 (inf-pow w) ((inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7)) ((inf-lelt 138 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; w3b-2
 (defvc inf-vc-stln-w3b-2 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-lt (add i k) 320) (inf-le (succ k) rrj1)))
   (given inf-stln-c2-w3 (lam w3 g7 (inf-ltsu k rrj1 w3))))
; w3b-3
 (defvc inf-vc-stln-w3b-3 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-lt (add i k) 320) (pi j nat (inf-le ((inf-upd Lz (add i k) vj1) j) 15))))
   (given inf-stln-c2-w3 (lam w3 g7 (inf-updle Lz (add i k) vj1 15 c2 f8))))
; w3b-4
 (defvc inf-vc-stln-w3b-4 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-lt (add i k) 320) (inf-lt (natminus rrj1 (succ k)) (natminus rrj1 k))))
   (given inf-stln-c2-w3 (lam w3 g7 (inf-subfall rrj1 k w3))))
; w3b-5
 (defvc inf-vc-stln-w3b-5 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-le 320 (add i k)) (inf-lt (succ k) (inf-pow w))))
   (given inf-stln-c2-w3 (lam w3 g7 (inf-lelt (succ k) 138 (inf-pow w) ((inf-letrans (succ k) rrj1 138 (inf-ltsu k rrj1 w3) f7)) ((inf-lelt 138 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; w3b-6
 (defvc inf-vc-stln-w3b-6 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-le 320 (add i k)) (inf-le (succ k) rrj1)))
   (given inf-stln-c2-w3 (lam w3 g7 (inf-ltsu k rrj1 w3))))
; w3b-7
 (defvc inf-vc-stln-w3b-7 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-le 320 (add i k)) (pi j nat (inf-le (Lz j) 15))))
   (given inf-stln-c2-w3 (lam w3 g7 c2)))
; w3b-8
 (defvc inf-vc-stln-w3b-8 (under inf-stln-c2-w3 (pi w3 (inf-lt k rrj1) g7 (inf-le 320 (add i k)) (inf-lt (natminus rrj1 (succ k)) (natminus rrj1 k))))
   (given inf-stln-c2-w3 (lam w3 g7 (inf-subfall rrj1 k w3))))
; s9-1
 (defvc inf-vc-stln-s9-1 (under inf-stln-c2-w3 (pi w3 (inf-le rrj1 k) (inf-lt (add i rrj1) (inf-pow w))))
   (given inf-stln-c2-w3 (lam w3 (inf-lelt (add i rrj1) 458 (inf-pow w) (inf-add2 i 320 rrj1 138 ((inf-letrans i (add hlit hdist) 320 (inf-ltle i (add hlit hdist) w1) ((inf-add2 hlit 288 hdist 32 g0 g00)))) f7) ((inf-lelt 458 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; s10-1
 (defvc inf-vc-stln-s10-1 (under inf-stln-c2-w3 (pi w3 (inf-le rrj1 k) (inf-lt vj1 (inf-pow w))))
   (given inf-stln-c2-w3 (lam w3 (inf-wlit vj1 w gw (inf-letrans vj1 15 63 f8 (idpath false))))))
; w1b-1
 (defvc inf-vc-stln-w1b-1 (under inf-stln-c2-w3 (pi w3 (inf-le rrj1 k) staged3 nat (inf-le vj1 15)))
   (given inf-stln-c2-w3 (lam w3 staged3 f8)))
; w1b-2
 (defvc inf-vc-stln-w1b-2 (under inf-stln-c2-w3 (pi w3 (inf-le rrj1 k) staged3 nat (pi j nat (inf-le (Lz j) 15))))
   (given inf-stln-c2-w3 (lam w3 staged3 c2)))
; w1b-3
 (defvc inf-vc-stln-w1b-3 (under inf-stln-c2-w3 (pi w3 (inf-le rrj1 k) staged3 nat (inf-le ipj1 n)))
   (given inf-stln-c2-w3 (lam w3 staged3 r1)))
; w1b-4
 (defvc inf-vc-stln-w1b-4 (under inf-stln-c2-w3 (pi w3 (inf-le rrj1 k) staged3 nat (inf-le bcj1 63)))
   (given inf-stln-c2-w3 (lam w3 staged3 r3)))
; w1b-5
 (defvc inf-vc-stln-w1b-5 (under inf-stln-c2-w3 (pi w3 (inf-le rrj1 k) staged3 nat (inf-bits-inv carry ipj1 consj1 bcj1)))
   (given inf-stln-c2-w3 (lam w3 staged3 r4)))
; w1b-6
 (defvc inf-vc-stln-w1b-6 (under inf-stln-c2-w3 (pi w3 (inf-le rrj1 k) staged3 nat (inf-le cons0 consj1)))
   (given inf-stln-c2-w3 (lam w3 staged3 r5)))
; w1b-7
 (defvc inf-vc-stln-w1b-7 (under inf-stln-c2-w3 (pi w3 (inf-le rrj1 k) staged3 nat (inf-lt (natminus (add hlit hdist) (add i rrj1)) (natminus (add hlit hdist) i))))
   (given inf-stln-c2-w3 (lam w3 staged3 (inf-subby i (add hlit hdist) rrj1 w1 f6))))
; c4-1
 (defvc inf-vc-stln-c4-1 (under inf-stln-w1 (pi w1 (inf-le (add hlit hdist) i) (pi k nat g (inf-lt k hlit) (inf-le (Lz k) 15))))
   (given inf-stln-w1 (lam w1 (lam k g (b2 k)))))
; c4-2
 (defvc inf-vc-stln-c4-2 (under inf-stln-w1 (pi w1 (inf-le (add hlit hdist) i) (inf-lt hlit q)))
   (given inf-stln-w1 (lam w1 (inf-lelt hlit 288 q g0 (inf-lttrans 288 320 q (idpath true) ((inf-ltle 320 q gq2)))))))
; c4-3
 (defvc inf-vc-stln-c4-3 (under inf-stln-w1 (pi w1 (inf-le (add hlit hdist) i) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-stln-w1 (lam w1 gq)))
; c4-4
 (defvc inf-vc-stln-c4-4 (under inf-stln-w1 (pi w1 (inf-le (add hlit hdist) i) (inf-le (inf-pow h) (inf-pow w))))
   (given inf-stln-w1 (lam w1 ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw)))))))
; c4-5
 (defvc inf-vc-stln-c4-5 (under inf-stln-w1 (pi w1 (inf-le (add hlit hdist) i) (inf-le LROOT 15)))
   (given inf-stln-w1 (lam w1 gl)))
; c4-6
 (defvc inf-vc-stln-c4-6 (under inf-stln-w1 (pi w1 (inf-le (add hlit hdist) i) (inf-le 32 w)))
   (given inf-stln-w1 (lam w1 gw)))
; c4-7
 (defvc inf-vc-stln-c4-7 (under inf-stln-w1 (pi w1 (inf-le (add hlit hdist) i) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-stln-w1 (lam w1 gk)))
 (defcx inf-stln-c9 inf-stln-w1 (w1 (inf-le (add hlit hdist) i)) (Lcc4 (pi j nat nat)) (Lsc4 (pi j nat nat)) (Ltc4 (pi j nat nat)) (c4e1 (pi z nat (inf-lt (Lcc4 z) (inf-pow h)))) (c4e2 (pi z nat (inf-lt (Lsc4 z) (inf-pow h)))) (c4e3 (inf-le (inf-sum Lcc4 15 1) hlit)) )
; c5-1
 (defvc inf-vc-stln-c5-1 (under inf-stln-c9 (pi k nat g (inf-lt k hdist) (inf-le ((inf-shift Lz hlit) k) 15)))
   (given inf-stln-c9 (lam k g (b2 (add hlit k)))))
; c5-2
 (defvc inf-vc-stln-c5-2 (under inf-stln-c9 (inf-lt hdist q))
   (given inf-stln-c9 (inf-lelt hdist 32 q g00 (inf-lttrans 32 320 q (idpath true) ((inf-ltle 320 q gq2))))))
; c5-3
 (defvc inf-vc-stln-c5-3 (under inf-stln-c9 (inf-le (inf-by16 q) (inf-pow h)))
   (given inf-stln-c9 gq))
; c5-4
 (defvc inf-vc-stln-c5-4 (under inf-stln-c9 (inf-le (inf-pow h) (inf-pow w)))
   (given inf-stln-c9 ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))
; c5-5
 (defvc inf-vc-stln-c5-5 (under inf-stln-c9 (inf-le DROOT 15))
   (given inf-stln-c9 gd))
; c5-6
 (defvc inf-vc-stln-c5-6 (under inf-stln-c9 (inf-le 32 w))
   (given inf-stln-c9 gw))
; c5-7
 (defvc inf-vc-stln-c5-7 (under inf-stln-c9 (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))))
   (given inf-stln-c9 gk))
 (defcx inf-stln-c10 inf-stln-c9 (Dcc5 (pi j nat nat)) (Dsc5 (pi j nat nat)) (Dtc5 (pi j nat nat)) (c5e1 (pi z nat (inf-lt (Dcc5 z) (inf-pow h)))) (c5e2 (pi z nat (inf-lt (Dsc5 z) (inf-pow h)))) (c5e3 (inf-le (inf-sum Dcc5 15 1) hdist)) )
; r2-1
 (defvc inf-vc-stln-r2-1 (under inf-stln-c10 (pi moded6 nat staged7 nat (inf-le ip n)))
   (given inf-stln-c10 (lam moded6 staged7 r1)))
; r2-2
 (defvc inf-vc-stln-r2-2 (under inf-stln-c10 (pi moded6 nat staged7 nat (inf-le bc 63)))
   (given inf-stln-c10 (lam moded6 staged7 r3)))
; r2-3
 (defvc inf-vc-stln-r2-3 (under inf-stln-c10 (pi moded6 nat staged7 nat (inf-bits-inv carry ip cons bc)))
   (given inf-stln-c10 (lam moded6 staged7 r4)))
; r2-4
 (defvc inf-vc-stln-r2-4 (under inf-stln-c10 (pi moded6 nat staged7 nat (inf-le cons0 cons)))
   (given inf-stln-c10 (lam moded6 staged7 r5)))
; r2-5
 (defvc inf-vc-stln-r2-5 (under inf-stln-c10 (pi moded6 nat staged7 nat (pi k nat (inf-lt (Lcc4 k) (inf-pow h)))))
   (given inf-stln-c10 (lam moded6 staged7 c4e1)))
; r2-6
 (defvc inf-vc-stln-r2-6 (under inf-stln-c10 (pi moded6 nat staged7 nat (pi k nat (inf-lt (Lsc4 k) (inf-pow h)))))
   (given inf-stln-c10 (lam moded6 staged7 c4e2)))
; r2-7
 (defvc inf-vc-stln-r2-7 (under inf-stln-c10 (pi moded6 nat staged7 nat (inf-le (inf-sum Lcc4 15 1) hlit)))
   (given inf-stln-c10 (lam moded6 staged7 c4e3)))
; r2-8
 (defvc inf-vc-stln-r2-8 (under inf-stln-c10 (pi moded6 nat staged7 nat (inf-le hlit 288)))
   (given inf-stln-c10 (lam moded6 staged7 g0)))
; r2-9
 (defvc inf-vc-stln-r2-9 (under inf-stln-c10 (pi moded6 nat staged7 nat (pi k nat (inf-lt (Dcc5 k) (inf-pow h)))))
   (given inf-stln-c10 (lam moded6 staged7 c5e1)))
; r2-10
 (defvc inf-vc-stln-r2-10 (under inf-stln-c10 (pi moded6 nat staged7 nat (pi k nat (inf-lt (Dsc5 k) (inf-pow h)))))
   (given inf-stln-c10 (lam moded6 staged7 c5e2)))
; r2-11
 (defvc inf-vc-stln-r2-11 (under inf-stln-c10 (pi moded6 nat staged7 nat (inf-le (inf-sum Dcc5 15 1) hdist)))
   (given inf-stln-c10 (lam moded6 staged7 c5e3)))
; r2-12
 (defvc inf-vc-stln-r2-12 (under inf-stln-c10 (pi moded6 nat staged7 nat (inf-le hdist 32)))
   (given inf-stln-c10 (lam moded6 staged7 g00)))
; r2-13
 (defvc inf-vc-stln-r2-13 (under inf-stln-c10 (pi moded6 nat staged7 nat (inf-le prev 15)))
   (given inf-stln-c10 (lam moded6 staged7 b1)))
; r2-14
 (defvc inf-vc-stln-r2-14 (under inf-stln-c10 (pi moded6 nat staged7 nat (pi j nat (inf-le (Lz j) 15))))
   (given inf-stln-c10 (lam moded6 staged7 b2)))
 (defcx inf-ststo (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gz (inf-lt 0 out)) (last nat) (rem0 nat) (mode0 nat) )
; w1e-1
 (defvc inf-vc-ststo-w1e-1 (under inf-ststo (pi g0 (inf-lt 0 rem0) (inf-le ip0 n)))
   (given inf-ststo (lam g0 gi)))
; w1e-2
 (defvc inf-vc-ststo-w1e-2 (under inf-ststo (pi g0 (inf-lt 0 rem0) (inf-le bc0 63)))
   (given inf-ststo (lam g0 gs)))
; w1e-3
 (defvc inf-vc-ststo-w1e-3 (under inf-ststo (pi g0 (inf-lt 0 rem0) (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-ststo (lam g0 ga)))
; w1e-4
 (defvc inf-vc-ststo-w1e-4 (under inf-ststo (pi g0 (inf-lt 0 rem0) (inf-le cons0 cons0)))
   (given inf-ststo (lam g0 (inf-refl cons0))))
; w1e-5
 (defvc inf-vc-ststo-w1e-5 (under inf-ststo (pi g0 (inf-lt 0 rem0) (inf-le op0 op0)))
   (given inf-ststo (lam g0 (inf-refl op0))))
; w1e-6
 (defvc inf-vc-ststo-w1e-6 (under inf-ststo (pi g0 (inf-lt 0 rem0) (inf-le op0 cap)))
   (given inf-ststo (lam g0 gop)))
 (defcx inf-ststo-w1 inf-ststo (g0 (inf-lt 0 rem0)) (bc nat) (bb nat) (cons nat) (op nat) (rem nat) (r1 (inf-le ip0 n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip0 cons bc)) (r5 (inf-le cons0 cons)) (o1 (inf-le op0 op)) (o2 (inf-le op cap)) )
; j0j-1
 (defvc inf-vc-ststo-j0j-1 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-lt bc 8) (inf-le ip0 n)))
   (given inf-ststo-w1 (lam w1 g1 r1)))
; j0j-2
 (defvc inf-vc-ststo-j0j-2 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-lt bc 8) (inf-le bc 63)))
   (given inf-ststo-w1 (lam w1 g1 r3)))
; j0j-3
 (defvc inf-vc-ststo-j0j-3 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-lt bc 8) (inf-bits-inv carry ip0 cons bc)))
   (given inf-ststo-w1 (lam w1 g1 r4)))
; j0j-4
 (defvc inf-vc-ststo-j0j-4 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-lt bc 8) (inf-le cons0 cons)))
   (given inf-ststo-w1 (lam w1 g1 r5)))
; j0j-5
 (defvc inf-vc-ststo-j0j-5 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-lt bc 8) (inf-le op0 op)))
   (given inf-ststo-w1 (lam w1 g1 o1)))
; j0j-6
 (defvc inf-vc-ststo-j0j-6 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-lt bc 8) (inf-le op cap)))
   (given inf-ststo-w1 (lam w1 g1 o2)))
; r6-1
 (defvc inf-vc-ststo-r6-1 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-le cap op) (inf-le ip0 n)))
   (given inf-ststo-w1 (lam w1 g1 g2 r1)))
; r6-2
 (defvc inf-vc-ststo-r6-2 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-le cap op) (inf-le bc 63)))
   (given inf-ststo-w1 (lam w1 g1 g2 r3)))
; r6-3
 (defvc inf-vc-ststo-r6-3 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-le cap op) (inf-bits-inv carry ip0 cons bc)))
   (given inf-ststo-w1 (lam w1 g1 g2 r4)))
; r6-4
 (defvc inf-vc-ststo-r6-4 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-le cap op) (inf-le cons0 cons)))
   (given inf-ststo-w1 (lam w1 g1 g2 r5)))
; r6-5
 (defvc inf-vc-ststo-r6-5 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-le cap op) (inf-le op cap)))
   (given inf-ststo-w1 (lam w1 g1 g2 o2)))
; r6-6
 (defvc inf-vc-ststo-r6-6 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-le cap op) (inf-le op0 op)))
   (given inf-ststo-w1 (lam w1 g1 g2 o1)))
; p1-1
 (defvc inf-vc-ststo-p1-1 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) (inf-lt op oc)))
   (given inf-ststo-w1 (lam w1 g1 g2 (inf-lttrans op cap oc g2 ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))))))
; p1-2
 (defvc inf-vc-ststo-p1-2 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) (inf-lt (inf-mod 256 bb) 256)))
   (given inf-ststo-w1 (lam w1 g1 g2 (inf-lelts (inf-mod 256 bb) 255 (inf-letrans (inf-mod 256 bb) 255 255 (inf-ltsle (inf-mod 256 bb) 255 (inf-modlt 255 bb)) (inf-refl 255))))))
; s1-1
 (defvc inf-vc-ststo-s1-1 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) (inf-lt (add op 1) (inf-pow w))))
   (given inf-ststo-w1 (lam w1 g1 g2 (inf-lelt (add op 1) cap (inf-pow w) ((inf-lt1 op cap g2)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; d1a-1
 (defvc inf-vc-ststo-d1a-1 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) (inf-lt 8 64)))
   (given inf-ststo-w1 (lam w1 g1 g2 (idpath true))))
; d1b-1
 (defvc inf-vc-ststo-d1b-1 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-le 8 bc)))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a g1)))
; d1b-2
 (defvc inf-vc-ststo-d1b-2 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-lt (natminus bc 8) (inf-pow w))))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a (inf-wlit (natminus bc 8) w gw (inf-letrans (natminus bc 8) bc 63 (inf-suble bc 8) r3)))))
; s2-1
 (defvc inf-vc-ststo-s2-1 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-le 1 rem)))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a (inf-ltsu 0 rem w1))))
; w1b-1
 (defvc inf-vc-ststo-w1b-1 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-le ip0 n)))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a r1)))
; w1b-2
 (defvc inf-vc-ststo-w1b-2 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-le (natminus bc 8) 63)))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a (inf-letrans (natminus bc 8) bc 63 (inf-suble bc 8) r3))))
; w1b-3
 (defvc inf-vc-ststo-w1b-3 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-bits-inv carry ip0 (add cons 8) (natminus bc 8))))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a (inf-take carry ip0 cons bc 8 g1 r4))))
; w1b-4
 (defvc inf-vc-ststo-w1b-4 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-le cons0 (add cons 8))))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a (inf-letrans cons0 cons (add cons 8) r5 (inf-leaddr cons 8)))))
; w1b-5
 (defvc inf-vc-ststo-w1b-5 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-le op0 (add op 1))))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a (inf-letrans op0 op (add op 1) o1 (inf-leaddr op 1)))))
; w1b-6
 (defvc inf-vc-ststo-w1b-6 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-le (add op 1) cap)))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a ((inf-lt1 op cap g2)))))
; w1b-7
 (defvc inf-vc-ststo-w1b-7 (under inf-ststo-w1 (pi w1 (inf-lt 0 rem) g1 (inf-le 8 bc) g2 (inf-lt op cap) bbd1a nat (inf-lt (natminus rem 1) rem)))
   (given inf-ststo-w1 (lam w1 g1 g2 bbd1a (inf-dec1 rem w1))))
; j0j-7
 (defvc inf-vc-ststo-j0j-7 (under inf-ststo-w1 (pi w1 (paths nat rem 0) (inf-le ip0 n)))
   (given inf-ststo-w1 (lam w1 r1)))
; j0j-8
 (defvc inf-vc-ststo-j0j-8 (under inf-ststo-w1 (pi w1 (paths nat rem 0) (inf-le bc 63)))
   (given inf-ststo-w1 (lam w1 r3)))
; j0j-9
 (defvc inf-vc-ststo-j0j-9 (under inf-ststo-w1 (pi w1 (paths nat rem 0) (inf-bits-inv carry ip0 cons bc)))
   (given inf-ststo-w1 (lam w1 r4)))
; j0j-10
 (defvc inf-vc-ststo-j0j-10 (under inf-ststo-w1 (pi w1 (paths nat rem 0) (inf-le cons0 cons)))
   (given inf-ststo-w1 (lam w1 r5)))
; j0j-11
 (defvc inf-vc-ststo-j0j-11 (under inf-ststo-w1 (pi w1 (paths nat rem 0) (inf-le op0 op)))
   (given inf-ststo-w1 (lam w1 o1)))
; j0j-12
 (defvc inf-vc-ststo-j0j-12 (under inf-ststo-w1 (pi w1 (paths nat rem 0) (inf-le op cap)))
   (given inf-ststo-w1 (lam w1 o2)))
; j0j-13
 (defvc inf-vc-ststo-j0j-13 (under inf-ststo (pi g0 (paths nat rem0 0) (inf-le ip0 n)))
   (given inf-ststo (lam g0 gi)))
; j0j-14
 (defvc inf-vc-ststo-j0j-14 (under inf-ststo (pi g0 (paths nat rem0 0) (inf-le bc0 63)))
   (given inf-ststo (lam g0 gs)))
; j0j-15
 (defvc inf-vc-ststo-j0j-15 (under inf-ststo (pi g0 (paths nat rem0 0) (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-ststo (lam g0 ga)))
; j0j-16
 (defvc inf-vc-ststo-j0j-16 (under inf-ststo (pi g0 (paths nat rem0 0) (inf-le cons0 cons0)))
   (given inf-ststo (lam g0 (inf-refl cons0))))
; j0j-17
 (defvc inf-vc-ststo-j0j-17 (under inf-ststo (pi g0 (paths nat rem0 0) (inf-le op0 op0)))
   (given inf-ststo (lam g0 (inf-refl op0))))
; j0j-18
 (defvc inf-vc-ststo-j0j-18 (under inf-ststo (pi g0 (paths nat rem0 0) (inf-le op0 cap)))
   (given inf-ststo (lam g0 gop)))
 (defcx inf-ststo-c1 inf-ststo (opj0 nat) (bbj0 nat) (bcj0 nat) (consj0 nat) (remj0 nat) (r1 (inf-le ip0 n)) (r3 (inf-le bcj0 63)) (r4 (inf-bits-inv carry ip0 consj0 bcj0)) (r5 (inf-le cons0 consj0)) (o1 (inf-le op0 opj0)) (o2 (inf-le opj0 cap)) )
; s3-1
 (defvc inf-vc-ststo-s3-1 (under inf-ststo-c1 (pi g3 (inf-lt 0 remj0) bbd2 nat (inf-le ip0 n)))
   (given inf-ststo-c1 (lam g3 bbd2 r1)))
; s3-2
 (defvc inf-vc-ststo-s3-2 (under inf-ststo-c1 (pi g3 (inf-lt 0 remj0) bbd2 nat (inf-lt (natminus n ip0) (inf-pow w))))
   (given inf-ststo-c1 (lam g3 bbd2 (inf-lelt (natminus n ip0) (add n 8) (inf-pow w) (inf-letrans (natminus n ip0) n (add n 8) (inf-letrans (natminus n ip0) n n (inf-suble n ip0) (inf-refl n)) (inf-leaddr n 8)) gn))))
; s4-1
 (defvc inf-vc-ststo-s4-1 (under inf-ststo-c1 (pi g3 (inf-lt 0 remj0) bbd2 nat g4 (inf-lt remj0 (natminus n ip0)) (inf-lt remj0 (inf-pow w))))
   (given inf-ststo-c1 (lam g3 bbd2 g4 (inf-lelt remj0 (add n 8) (inf-pow w) (inf-letrans remj0 n (add n 8) (inf-letrans remj0 (natminus n ip0) n (inf-ltle remj0 (natminus n ip0) g4) (inf-letrans (natminus n ip0) n n (inf-suble n ip0) (inf-refl n))) (inf-leaddr n 8)) gn))))
; j2j-1
 (defvc inf-vc-ststo-j2j-1 (under inf-ststo-c1 (pi g3 (inf-lt 0 remj0) bbd2 nat g4 (inf-lt remj0 (natminus n ip0)) (inf-le remj0 remj0)))
   (given inf-ststo-c1 (lam g3 bbd2 g4 (inf-refl remj0))))
; j2j-2
 (defvc inf-vc-ststo-j2j-2 (under inf-ststo-c1 (pi g3 (inf-lt 0 remj0) bbd2 nat g4 (inf-lt remj0 (natminus n ip0)) (inf-le remj0 (natminus n ip0))))
   (given inf-ststo-c1 (lam g3 bbd2 g4 (inf-letrans remj0 (natminus n ip0) (natminus n ip0) (inf-ltle remj0 (natminus n ip0) g4) (inf-refl (natminus n ip0))))))
; j2j-3
 (defvc inf-vc-ststo-j2j-3 (under inf-ststo-c1 (pi g3 (inf-lt 0 remj0) bbd2 nat g4 (inf-le (natminus n ip0) remj0) (inf-le (natminus n ip0) remj0)))
   (given inf-ststo-c1 (lam g3 bbd2 g4 g4)))
; j2j-4
 (defvc inf-vc-ststo-j2j-4 (under inf-ststo-c1 (pi g3 (inf-lt 0 remj0) bbd2 nat g4 (inf-le (natminus n ip0) remj0) (inf-le (natminus n ip0) (natminus n ip0))))
   (given inf-ststo-c1 (lam g3 bbd2 g4 (inf-refl (natminus n ip0)))))
 (defcx inf-ststo-c3 inf-ststo-c1 (g3 (inf-lt 0 remj0)) (bbd2 nat) (kj2 nat) (f1 (inf-le kj2 remj0)) (f2 (inf-le kj2 (natminus n ip0))) )
; j3-1
 (defvc inf-vc-ststo-j3-1 (under inf-ststo-c3 (inf-le opj0 cap))
   (given inf-ststo-c3 o2))
; s5-1
 (defvc inf-vc-ststo-s5-1 (under inf-ststo-c3 (pi g5 (inf-lt (natminus cap opj0) kj2) (inf-le opj0 cap)))
   (given inf-ststo-c3 (lam g5 o2)))
; s5-2
 (defvc inf-vc-ststo-s5-2 (under inf-ststo-c3 (pi g5 (inf-lt (natminus cap opj0) kj2) (inf-lt (natminus cap opj0) (inf-pow w))))
   (given inf-ststo-c3 (lam g5 (inf-lelt (natminus cap opj0) (add n 8) (inf-pow w) (inf-letrans (natminus cap opj0) n (add n 8) (inf-letrans (natminus cap opj0) kj2 n (inf-ltle (natminus cap opj0) kj2 g5) (inf-letrans kj2 (natminus n ip0) n f2 (inf-letrans (natminus n ip0) n n (inf-suble n ip0) (inf-refl n)))) (inf-leaddr n 8)) gn))))
; j3j-1
 (defvc inf-vc-ststo-j3j-1 (under inf-ststo-c3 (pi g5 (inf-lt (natminus cap opj0) kj2) (inf-le (natminus cap opj0) remj0)))
   (given inf-ststo-c3 (lam g5 (inf-letrans (natminus cap opj0) kj2 remj0 (inf-ltle (natminus cap opj0) kj2 g5) f1))))
; j3j-2
 (defvc inf-vc-ststo-j3j-2 (under inf-ststo-c3 (pi g5 (inf-lt (natminus cap opj0) kj2) (inf-le (natminus cap opj0) (natminus n ip0))))
   (given inf-ststo-c3 (lam g5 (inf-letrans (natminus cap opj0) kj2 (natminus n ip0) (inf-ltle (natminus cap opj0) kj2 g5) f2))))
; j3j-3
 (defvc inf-vc-ststo-j3j-3 (under inf-ststo-c3 (pi g5 (inf-lt (natminus cap opj0) kj2) (inf-le (natminus cap opj0) (natminus cap opj0))))
   (given inf-ststo-c3 (lam g5 (inf-refl (natminus cap opj0)))))
; j3j-4
 (defvc inf-vc-ststo-j3j-4 (under inf-ststo-c3 (pi g5 (inf-le kj2 (natminus cap opj0)) (inf-le kj2 remj0)))
   (given inf-ststo-c3 (lam g5 f1)))
; j3j-5
 (defvc inf-vc-ststo-j3j-5 (under inf-ststo-c3 (pi g5 (inf-le kj2 (natminus cap opj0)) (inf-le kj2 (natminus n ip0))))
   (given inf-ststo-c3 (lam g5 f2)))
; j3j-6
 (defvc inf-vc-ststo-j3j-6 (under inf-ststo-c3 (pi g5 (inf-le kj2 (natminus cap opj0)) (inf-le kj2 (natminus cap opj0))))
   (given inf-ststo-c3 (lam g5 g5)))
 (defcx inf-ststo-c4 inf-ststo-c3 (kj3 nat) (f3 (inf-le kj3 remj0)) (f4 (inf-le kj3 (natminus n ip0))) (f5 (inf-le kj3 (natminus cap opj0))) )
; m1-1
 (defvc inf-vc-ststo-m1-1 (under inf-ststo-c4 (inf-le (add opj0 kj3) oc))
   (given inf-ststo-c4 (inf-letl (add opj0 kj3) cap oc (pathsinv0 nat oc cap (go gz)) ((inf-roomle opj0 cap kj3 f5 o2)))))
; m1-2
 (defvc inf-vc-ststo-m1-2 (under inf-ststo-c4 (inf-le (add ip0 kj3) n))
   (given inf-ststo-c4 ((inf-roomle ip0 n kj3 f4 gi))))
; s6-1
 (defvc inf-vc-ststo-s6-1 (under inf-ststo-c4 (inf-lt (add opj0 kj3) (inf-pow w)))
   (given inf-ststo-c4 (inf-lelt (add opj0 kj3) cap (inf-pow w) ((inf-roomle opj0 cap kj3 f5 o2)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))
; s7-1
 (defvc inf-vc-ststo-s7-1 (under inf-ststo-c4 (inf-lt (add ip0 kj3) (inf-pow w)))
   (given inf-ststo-c4 (inf-lelt (add ip0 kj3) n (inf-pow w) ((inf-roomle ip0 n kj3 f4 gi)) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn)))))
; s8-1
 (defvc inf-vc-ststo-s8-1 (under inf-ststo-c4 (inf-le kj3 remj0))
   (given inf-ststo-c4 f3))
; r7-1
 (defvc inf-vc-ststo-r7-1 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-lt (add ip0 kj3) n) (inf-le (add ip0 kj3) n)))
   (given inf-ststo-c4 (lam g6 g7 (inf-letrans (add ip0 kj3) n n (inf-ltle (add ip0 kj3) n g7) (inf-refl n)))))
; r7-2
 (defvc inf-vc-ststo-r7-2 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-lt (add ip0 kj3) n) (inf-le bcj0 63)))
   (given inf-ststo-c4 (lam g6 g7 r3)))
; r7-3
 (defvc inf-vc-ststo-r7-3 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-lt (add ip0 kj3) n) (inf-bits-inv carry (add ip0 kj3) (add consj0 (inf-by8 kj3)) bcj0)))
   (given inf-ststo-c4 (lam g6 g7 (inf-advb carry ip0 consj0 bcj0 kj3 r4))))
; r7-4
 (defvc inf-vc-ststo-r7-4 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-lt (add ip0 kj3) n) (inf-le cons0 (add consj0 (inf-by8 kj3)))))
   (given inf-ststo-c4 (lam g6 g7 (inf-letrans cons0 consj0 (add consj0 (inf-by8 kj3)) r5 (inf-leaddr consj0 (inf-by8 kj3))))))
; r7-5
 (defvc inf-vc-ststo-r7-5 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-lt (add ip0 kj3) n) (inf-le (add opj0 kj3) cap)))
   (given inf-ststo-c4 (lam g6 g7 ((inf-roomle opj0 cap kj3 f5 o2)))))
; r7-6
 (defvc inf-vc-ststo-r7-6 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-lt (add ip0 kj3) n) (inf-le op0 (add opj0 kj3))))
   (given inf-ststo-c4 (lam g6 g7 (inf-letrans op0 opj0 (add opj0 kj3) o1 (inf-leaddr opj0 kj3)))))
; r8-1
 (defvc inf-vc-ststo-r8-1 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-le n (add ip0 kj3)) (inf-le (add ip0 kj3) n)))
   (given inf-ststo-c4 (lam g6 g7 ((inf-roomle ip0 n kj3 f4 gi)))))
; r8-2
 (defvc inf-vc-ststo-r8-2 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-le n (add ip0 kj3)) (inf-le bcj0 63)))
   (given inf-ststo-c4 (lam g6 g7 r3)))
; r8-3
 (defvc inf-vc-ststo-r8-3 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-le n (add ip0 kj3)) (inf-bits-inv carry (add ip0 kj3) (add consj0 (inf-by8 kj3)) bcj0)))
   (given inf-ststo-c4 (lam g6 g7 (inf-advb carry ip0 consj0 bcj0 kj3 r4))))
; r8-4
 (defvc inf-vc-ststo-r8-4 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-le n (add ip0 kj3)) (inf-le cons0 (add consj0 (inf-by8 kj3)))))
   (given inf-ststo-c4 (lam g6 g7 (inf-letrans cons0 consj0 (add consj0 (inf-by8 kj3)) r5 (inf-leaddr consj0 (inf-by8 kj3))))))
; r8-5
 (defvc inf-vc-ststo-r8-5 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-le n (add ip0 kj3)) (inf-le (add opj0 kj3) cap)))
   (given inf-ststo-c4 (lam g6 g7 ((inf-roomle opj0 cap kj3 f5 o2)))))
; r8-6
 (defvc inf-vc-ststo-r8-6 (under inf-ststo-c4 (pi g6 (inf-lt 0 (natminus remj0 kj3)) g7 (inf-le n (add ip0 kj3)) (inf-le op0 (add opj0 kj3))))
   (given inf-ststo-c4 (lam g6 g7 (inf-letrans op0 opj0 (add opj0 kj3) o1 (inf-leaddr opj0 kj3)))))
; j1j-1
 (defvc inf-vc-ststo-j1j-1 (under inf-ststo-c4 (pi g6 (paths nat (natminus remj0 kj3) 0) (inf-le (add ip0 kj3) n)))
   (given inf-ststo-c4 (lam g6 ((inf-roomle ip0 n kj3 f4 gi)))))
; j1j-2
 (defvc inf-vc-ststo-j1j-2 (under inf-ststo-c4 (pi g6 (paths nat (natminus remj0 kj3) 0) (inf-le bcj0 63)))
   (given inf-ststo-c4 (lam g6 r3)))
; j1j-3
 (defvc inf-vc-ststo-j1j-3 (under inf-ststo-c4 (pi g6 (paths nat (natminus remj0 kj3) 0) (inf-bits-inv carry (add ip0 kj3) (add consj0 (inf-by8 kj3)) bcj0)))
   (given inf-ststo-c4 (lam g6 (inf-advb carry ip0 consj0 bcj0 kj3 r4))))
; j1j-4
 (defvc inf-vc-ststo-j1j-4 (under inf-ststo-c4 (pi g6 (paths nat (natminus remj0 kj3) 0) (inf-le cons0 (add consj0 (inf-by8 kj3)))))
   (given inf-ststo-c4 (lam g6 (inf-letrans cons0 consj0 (add consj0 (inf-by8 kj3)) r5 (inf-leaddr consj0 (inf-by8 kj3))))))
; j1j-5
 (defvc inf-vc-ststo-j1j-5 (under inf-ststo-c4 (pi g6 (paths nat (natminus remj0 kj3) 0) (inf-le op0 (add opj0 kj3))))
   (given inf-ststo-c4 (lam g6 (inf-letrans op0 opj0 (add opj0 kj3) o1 (inf-leaddr opj0 kj3)))))
; j1j-6
 (defvc inf-vc-ststo-j1j-6 (under inf-ststo-c4 (pi g6 (paths nat (natminus remj0 kj3) 0) (inf-le (add opj0 kj3) cap)))
   (given inf-ststo-c4 (lam g6 ((inf-roomle opj0 cap kj3 f5 o2)))))
; j1j-7
 (defvc inf-vc-ststo-j1j-7 (under inf-ststo-c1 (pi g3 (paths nat remj0 0) (inf-le ip0 n)))
   (given inf-ststo-c1 (lam g3 r1)))
; j1j-8
 (defvc inf-vc-ststo-j1j-8 (under inf-ststo-c1 (pi g3 (paths nat remj0 0) (inf-le bcj0 63)))
   (given inf-ststo-c1 (lam g3 r3)))
; j1j-9
 (defvc inf-vc-ststo-j1j-9 (under inf-ststo-c1 (pi g3 (paths nat remj0 0) (inf-bits-inv carry ip0 consj0 bcj0)))
   (given inf-ststo-c1 (lam g3 r4)))
; j1j-10
 (defvc inf-vc-ststo-j1j-10 (under inf-ststo-c1 (pi g3 (paths nat remj0 0) (inf-le cons0 consj0)))
   (given inf-ststo-c1 (lam g3 r5)))
; j1j-11
 (defvc inf-vc-ststo-j1j-11 (under inf-ststo-c1 (pi g3 (paths nat remj0 0) (inf-le op0 opj0)))
   (given inf-ststo-c1 (lam g3 o1)))
; j1j-12
 (defvc inf-vc-ststo-j1j-12 (under inf-ststo-c1 (pi g3 (paths nat remj0 0) (inf-le opj0 cap)))
   (given inf-ststo-c1 (lam g3 o2)))
 (defcx inf-ststo-c2 inf-ststo-c1 (bbj1 nat) (opj1 nat) (ipj1 nat) (consj1 nat) (remj1 nat) (r1 (inf-le ipj1 n)) (r3 (inf-le bcj0 63)) (r4 (inf-bits-inv carry ipj1 consj1 bcj0)) (r5 (inf-le cons0 consj1)) (o1 (inf-le op0 opj1)) (o2 (inf-le opj1 cap)) )
; r9-1
 (defvc inf-vc-ststo-r9-1 (under inf-ststo-c2 (pi ge1 (inf-lt 0 last) modee1a nat (inf-le ipj1 n)))
   (given inf-ststo-c2 (lam ge1 modee1a r1)))
; r9-2
 (defvc inf-vc-ststo-r9-2 (under inf-ststo-c2 (pi ge1 (inf-lt 0 last) modee1a nat (inf-le bcj0 63)))
   (given inf-ststo-c2 (lam ge1 modee1a r3)))
; r9-3
 (defvc inf-vc-ststo-r9-3 (under inf-ststo-c2 (pi ge1 (inf-lt 0 last) modee1a nat (inf-bits-inv carry ipj1 consj1 bcj0)))
   (given inf-ststo-c2 (lam ge1 modee1a r4)))
; r9-4
 (defvc inf-vc-ststo-r9-4 (under inf-ststo-c2 (pi ge1 (inf-lt 0 last) modee1a nat (inf-le cons0 consj1)))
   (given inf-ststo-c2 (lam ge1 modee1a r5)))
; r9-5
 (defvc inf-vc-ststo-r9-5 (under inf-ststo-c2 (pi ge1 (inf-lt 0 last) modee1a nat (inf-le opj1 cap)))
   (given inf-ststo-c2 (lam ge1 modee1a o2)))
; r9-6
 (defvc inf-vc-ststo-r9-6 (under inf-ststo-c2 (pi ge1 (inf-lt 0 last) modee1a nat (inf-le op0 opj1)))
   (given inf-ststo-c2 (lam ge1 modee1a o1)))
; r9-7
 (defvc inf-vc-ststo-r9-7 (under inf-ststo-c2 (pi ge1 (paths nat last 0) modee1b nat (inf-le ipj1 n)))
   (given inf-ststo-c2 (lam ge1 modee1b r1)))
; r9-8
 (defvc inf-vc-ststo-r9-8 (under inf-ststo-c2 (pi ge1 (paths nat last 0) modee1b nat (inf-le bcj0 63)))
   (given inf-ststo-c2 (lam ge1 modee1b r3)))
; r9-9
 (defvc inf-vc-ststo-r9-9 (under inf-ststo-c2 (pi ge1 (paths nat last 0) modee1b nat (inf-bits-inv carry ipj1 consj1 bcj0)))
   (given inf-ststo-c2 (lam ge1 modee1b r4)))
; r9-10
 (defvc inf-vc-ststo-r9-10 (under inf-ststo-c2 (pi ge1 (paths nat last 0) modee1b nat (inf-le cons0 consj1)))
   (given inf-ststo-c2 (lam ge1 modee1b r5)))
; r9-11
 (defvc inf-vc-ststo-r9-11 (under inf-ststo-c2 (pi ge1 (paths nat last 0) modee1b nat (inf-le opj1 cap)))
   (given inf-ststo-c2 (lam ge1 modee1b o2)))
; r9-12
 (defvc inf-vc-ststo-r9-12 (under inf-ststo-c2 (pi ge1 (paths nat last 0) modee1b nat (inf-le op0 opj1)))
   (given inf-ststo-c2 (lam ge1 modee1b o1)))
 (defcx inf-stsy (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gcf (inf-lt (add cap 266) (inf-pow w))) (Lc (pi k nat nat)) (Ls (pi k nat nat)) (Lt (pi k nat nat)) (Dc (pi k nat nat)) (Ds (pi k nat nat)) (Dt (pi k nat nat)) (lm nat) (dm nat) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (h nat) (LROOT nat) (DROOT nat) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16)) (c1 (pi k nat (inf-lt (Lc k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc 15 1) lm)) (c4 (inf-le lm 288)) (c5 (pi k nat (inf-lt (Dc k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc 15 1) dm)) (c8 (inf-le dm 32)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (gz (inf-lt 0 out)) (last nat) (mode0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) )
; w1e-1
 (defvc inf-vc-stsy-w1e-1 (under inf-stsy (inf-le ip0 n))
   (given inf-stsy gi))
; w1e-2
 (defvc inf-vc-stsy-w1e-2 (under inf-stsy (inf-le bc0 63))
   (given inf-stsy gs))
; w1e-3
 (defvc inf-vc-stsy-w1e-3 (under inf-stsy (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-stsy ga))
; w1e-4
 (defvc inf-vc-stsy-w1e-4 (under inf-stsy (inf-le cons0 cons0))
   (given inf-stsy (inf-refl cons0)))
; w1e-5
 (defvc inf-vc-stsy-w1e-5 (under inf-stsy (inf-le op0 op0))
   (given inf-stsy (inf-refl op0)))
; w1e-6
 (defvc inf-vc-stsy-w1e-6 (under inf-stsy (inf-le op0 cap))
   (given inf-stsy gop))
 (defcx inf-stsy-w1 inf-stsy (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (mode nat) (stage nat) (sy nat) (len nat) (dist nat) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) (o1 (inf-le op0 op)) (o2 (inf-le op cap)) )
; i1-1
 (defvc inf-vc-stsy-i1-1 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) (inf-lt (add ip 8) (inf-pow w))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 (inf-lelt (add ip 8) (add n 8) (inf-pow w) (inf-addr ip n 8 r1) gn))))
; i3-1
 (defvc inf-vc-stsy-i3-1 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) (inf-lt (add op 266) (inf-pow w))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 (inf-lelt (add op 266) (add cap 266) (inf-pow w) (inf-addr op cap 266 o2) gcf))))
; t1-1
 (defvc inf-vc-stsy-t1-1 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le 32 w)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 gw)))
; t1-2
 (defvc inf-vc-stsy-t1-2 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add n 8) (inf-pow w))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 gn)))
; t1-3
 (defvc inf-vc-stsy-t1-3 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le ip n)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 r1)))
; t1-4
 (defvc inf-vc-stsy-t1-4 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le bc 63)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 r3)))
; t1-5
 (defvc inf-vc-stsy-t1-5 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-bits-inv carry ip cons bc)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 r4)))
; t1-6
 (defvc inf-vc-stsy-t1-6 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 go)))
; t1-7
 (defvc inf-vc-stsy-t1-7 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add cap 8) (inf-pow w))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 gcap)))
; t1-8
 (defvc inf-vc-stsy-t1-8 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le op cap)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 o2)))
; t1-9
 (defvc inf-vc-stsy-t1-9 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add cap nd) (inf-pow w))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 gnd)))
; t1-10
 (defvc inf-vc-stsy-t1-10 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add cap 266) (inf-pow w))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 gcf)))
; t1-11
 (defvc inf-vc-stsy-t1-11 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le LROOT 15)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 gl)))
; t1-12
 (defvc inf-vc-stsy-t1-12 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le DROOT 15)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 gd)))
; t1-13
 (defvc inf-vc-stsy-t1-13 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le h 16)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 gh)))
; t1-14
 (defvc inf-vc-stsy-t1-14 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt 0 out)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 gz)))
; t1-15
 (defvc inf-vc-stsy-t1-15 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 hle)))
; t1-16
 (defvc inf-vc-stsy-t1-16 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 hlb)))
; t1-17
 (defvc inf-vc-stsy-t1-17 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 hlc)))
; t1-18
 (defvc inf-vc-stsy-t1-18 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 30) (inf-le (De k) 13))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 hde)))
; t1-19
 (defvc inf-vc-stsy-t1-19 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 hdb)))
; t1s-1
 (defvc inf-vc-stsy-t1s-1 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op opt1) (inf-le ipt1 n)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 ipt1 bct1 bbt1 const1 opt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1e1)))
; t1s-2
 (defvc inf-vc-stsy-t1s-2 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op opt1) (inf-le bct1 63)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 ipt1 bct1 bbt1 const1 opt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1e3)))
; t1s-3
 (defvc inf-vc-stsy-t1s-3 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op opt1) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 ipt1 bct1 bbt1 const1 opt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1e4)))
; t1s-4
 (defvc inf-vc-stsy-t1s-4 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op opt1) (inf-le cons0 const1)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 ipt1 bct1 bbt1 const1 opt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 (inf-letrans cons0 cons const1 r5 t1e5))))
; t1s-5
 (defvc inf-vc-stsy-t1s-5 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op opt1) (inf-le opt1 cap)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 ipt1 bct1 bbt1 const1 opt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1e8)))
; t1s-6
 (defvc inf-vc-stsy-t1s-6 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op opt1) (inf-le op0 opt1)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 ipt1 bct1 bbt1 const1 opt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 (inf-letrans op0 op opt1 o1 t1e9))))
 (defcx inf-stsy-c11 inf-stsy-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (g0 (paths nat stage 0)) (g1 (inf-le (add ip 8) n)) (g3 (inf-le (add op 266) cap)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (opt1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e8 (inf-le opt1 cap)) (t1e9 (inf-le op opt1)) )
; r0-1
 (defvc inf-vc-stsy-r0-1 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (inf-lt 0 last) modee1a nat (inf-le ipt1 n)))
   (given inf-stsy-c11 (lam g4 ge1 modee1a t1e1)))
; r0-2
 (defvc inf-vc-stsy-r0-2 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (inf-lt 0 last) modee1a nat (inf-le bct1 63)))
   (given inf-stsy-c11 (lam g4 ge1 modee1a t1e3)))
; r0-3
 (defvc inf-vc-stsy-r0-3 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (inf-lt 0 last) modee1a nat (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-stsy-c11 (lam g4 ge1 modee1a t1e4)))
; r0-4
 (defvc inf-vc-stsy-r0-4 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (inf-lt 0 last) modee1a nat (inf-le cons0 const1)))
   (given inf-stsy-c11 (lam g4 ge1 modee1a (inf-letrans cons0 cons const1 r5 t1e5))))
; r0-5
 (defvc inf-vc-stsy-r0-5 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (inf-lt 0 last) modee1a nat (inf-le opt1 cap)))
   (given inf-stsy-c11 (lam g4 ge1 modee1a t1e8)))
; r0-6
 (defvc inf-vc-stsy-r0-6 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (inf-lt 0 last) modee1a nat (inf-le op0 opt1)))
   (given inf-stsy-c11 (lam g4 ge1 modee1a (inf-letrans op0 op opt1 o1 t1e9))))
; r0-7
 (defvc inf-vc-stsy-r0-7 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (paths nat last 0) modee1b nat (inf-le ipt1 n)))
   (given inf-stsy-c11 (lam g4 ge1 modee1b t1e1)))
; r0-8
 (defvc inf-vc-stsy-r0-8 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (paths nat last 0) modee1b nat (inf-le bct1 63)))
   (given inf-stsy-c11 (lam g4 ge1 modee1b t1e3)))
; r0-9
 (defvc inf-vc-stsy-r0-9 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (paths nat last 0) modee1b nat (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-stsy-c11 (lam g4 ge1 modee1b t1e4)))
; r0-10
 (defvc inf-vc-stsy-r0-10 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (paths nat last 0) modee1b nat (inf-le cons0 const1)))
   (given inf-stsy-c11 (lam g4 ge1 modee1b (inf-letrans cons0 cons const1 r5 t1e5))))
; r0-11
 (defvc inf-vc-stsy-r0-11 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (paths nat last 0) modee1b nat (inf-le opt1 cap)))
   (given inf-stsy-c11 (lam g4 ge1 modee1b t1e8)))
; r0-12
 (defvc inf-vc-stsy-r0-12 (under inf-stsy-c11 (pi g4 (inf-lt 0 xt1) ge1 (paths nat last 0) modee1b nat (inf-le op0 opt1)))
   (given inf-stsy-c11 (lam g4 ge1 modee1b (inf-letrans op0 op opt1 o1 t1e9))))
; i1j-1
 (defvc inf-vc-stsy-i1j-1 (under inf-stsy-c11 (pi g4 (paths nat xt1 0) (inf-le ipt1 n)))
   (given inf-stsy-c11 (lam g4 t1e1)))
; i1j-2
 (defvc inf-vc-stsy-i1j-2 (under inf-stsy-c11 (pi g4 (paths nat xt1 0) (inf-le bct1 63)))
   (given inf-stsy-c11 (lam g4 t1e3)))
; i1j-3
 (defvc inf-vc-stsy-i1j-3 (under inf-stsy-c11 (pi g4 (paths nat xt1 0) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-stsy-c11 (lam g4 t1e4)))
; i1j-4
 (defvc inf-vc-stsy-i1j-4 (under inf-stsy-c11 (pi g4 (paths nat xt1 0) (inf-le cons0 const1)))
   (given inf-stsy-c11 (lam g4 (inf-letrans cons0 cons const1 r5 t1e5))))
; i1j-5
 (defvc inf-vc-stsy-i1j-5 (under inf-stsy-c11 (pi g4 (paths nat xt1 0) (inf-le o0 opt1)))
   (given inf-stsy-c11 (lam g4 (inf-letrans o0 op opt1 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))) t1e9))))
; i1j-6
 (defvc inf-vc-stsy-i1j-6 (under inf-stsy-c11 (pi g4 (paths nat xt1 0) (inf-le opt1 cap)))
   (given inf-stsy-c11 (lam g4 t1e8)))
; i1j-7
 (defvc inf-vc-stsy-i1j-7 (under inf-stsy-c11 (pi g4 (paths nat xt1 0) (inf-le op0 opt1)))
   (given inf-stsy-c11 (lam g4 (inf-letrans op0 op opt1 o1 t1e9))))
; i1j-8
 (defvc inf-vc-stsy-i1j-8 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le ip n)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 r1)))
; i1j-9
 (defvc inf-vc-stsy-i1j-9 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le bc 63)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 r3)))
; i1j-10
 (defvc inf-vc-stsy-i1j-10 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-bits-inv carry ip cons bc)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 r4)))
; i1j-11
 (defvc inf-vc-stsy-i1j-11 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le cons0 cons)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 r5)))
; i1j-12
 (defvc inf-vc-stsy-i1j-12 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le o0 op)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))))))
; i1j-13
 (defvc inf-vc-stsy-i1j-13 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le op cap)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 o2)))
; i1j-14
 (defvc inf-vc-stsy-i1j-14 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le op0 op)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 g3 o1)))
; i1j-15
 (defvc inf-vc-stsy-i1j-15 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-lt n (add ip 8)) (inf-le ip n)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 r1)))
; i1j-16
 (defvc inf-vc-stsy-i1j-16 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-lt n (add ip 8)) (inf-le bc 63)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 r3)))
; i1j-17
 (defvc inf-vc-stsy-i1j-17 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-lt n (add ip 8)) (inf-bits-inv carry ip cons bc)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 r4)))
; i1j-18
 (defvc inf-vc-stsy-i1j-18 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-lt n (add ip 8)) (inf-le cons0 cons)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 r5)))
; i1j-19
 (defvc inf-vc-stsy-i1j-19 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-lt n (add ip 8)) (inf-le o0 op)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))))))
; i1j-20
 (defvc inf-vc-stsy-i1j-20 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-lt n (add ip 8)) (inf-le op cap)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 o2)))
; i1j-21
 (defvc inf-vc-stsy-i1j-21 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (paths nat stage 0) g1 (inf-lt n (add ip 8)) (inf-le op0 op)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 g1 o1)))
 (defcx inf-stsy-c9 inf-stsy-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (g0 (paths nat stage 0)) (ipi1 nat) (bci1 nat) (bbi1 nat) (consi1 nat) (opi1 nat) (modei1 nat) (k1 (inf-le ipi1 n)) (k3 (inf-le bci1 63)) (k4 (inf-bits-inv carry ipi1 consi1 bci1)) (k5 (inf-le cons0 consi1)) (k6 (inf-le o0 opi1)) (k7 (inf-le opi1 cap)) (k8 (inf-le op0 opi1)) )
; t2-1
 (defvc inf-vc-stsy-t2-1 (under inf-stsy-c9 (inf-le 32 w))
   (given inf-stsy-c9 gw))
; t2-2
 (defvc inf-vc-stsy-t2-2 (under inf-stsy-c9 (inf-lt (add n 8) (inf-pow w)))
   (given inf-stsy-c9 gn))
; t2-3
 (defvc inf-vc-stsy-t2-3 (under inf-stsy-c9 (inf-le ipi1 n))
   (given inf-stsy-c9 k1))
; t2-4
 (defvc inf-vc-stsy-t2-4 (under inf-stsy-c9 (inf-le bci1 63))
   (given inf-stsy-c9 k3))
; t2-5
 (defvc inf-vc-stsy-t2-5 (under inf-stsy-c9 (inf-bits-inv carry ipi1 consi1 bci1))
   (given inf-stsy-c9 k4))
; t2-6
 (defvc inf-vc-stsy-t2-6 (under inf-stsy-c9 (pi i nat (inf-lt (Lc i) (inf-pow h))))
   (given inf-stsy-c9 c1))
; t2-7
 (defvc inf-vc-stsy-t2-7 (under inf-stsy-c9 (pi i nat (inf-lt (Ls i) (inf-pow h))))
   (given inf-stsy-c9 c2))
; t2-8
 (defvc inf-vc-stsy-t2-8 (under inf-stsy-c9 (inf-le h 16))
   (given inf-stsy-c9 gh))
; t2-9
 (defvc inf-vc-stsy-t2-9 (under inf-stsy-c9 (inf-lt lm (inf-pow w)))
   (given inf-stsy-c9 (inf-lelt lm 288 (inf-pow w) c4 (inf-wfit288 w gw))))
; t2-10
 (defvc inf-vc-stsy-t2-10 (under inf-stsy-c9 (inf-le (inf-sum Lc 15 1) lm))
   (given inf-stsy-c9 c3))
; t2-11
 (defvc inf-vc-stsy-t2-11 (under inf-stsy-c9 (inf-le LROOT 15))
   (given inf-stsy-c9 gl))
; t2s-1
 (defvc inf-vc-stsy-t2s-1 (under inf-stsy-c9 (pi ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consi1 const2) (inf-le ipt2 n)))
   (given inf-stsy-c9 (lam ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 t2e1)))
; t2s-2
 (defvc inf-vc-stsy-t2s-2 (under inf-stsy-c9 (pi ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consi1 const2) (inf-le bct2 63)))
   (given inf-stsy-c9 (lam ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 t2e3)))
; t2s-3
 (defvc inf-vc-stsy-t2s-3 (under inf-stsy-c9 (pi ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consi1 const2) (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-stsy-c9 (lam ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 t2e4)))
; t2s-4
 (defvc inf-vc-stsy-t2s-4 (under inf-stsy-c9 (pi ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consi1 const2) (inf-le cons0 const2)))
   (given inf-stsy-c9 (lam ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 (inf-letrans cons0 consi1 const2 k5 t2e5))))
; t2s-5
 (defvc inf-vc-stsy-t2s-5 (under inf-stsy-c9 (pi ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consi1 const2) (inf-le opi1 cap)))
   (given inf-stsy-c9 (lam ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 k7)))
; t2s-6
 (defvc inf-vc-stsy-t2s-6 (under inf-stsy-c9 (pi ipt2 nat bct2 nat bbt2 nat const2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consi1 const2) (inf-le op0 opi1)))
   (given inf-stsy-c9 (lam ipt2 bct2 bbt2 const2 xt2 t2e1 t2e3 t2e4 t2e5 k8)))
 (defcx inf-stsy-c10 inf-stsy-c9 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le consi1 const2)) )
; i0j-1
 (defvc inf-vc-stsy-i0j-1 (under inf-stsy-c10 (pi syd1 nat g5 (inf-lt xt2 256) staged2 nat (inf-le ipt2 n)))
   (given inf-stsy-c10 (lam syd1 g5 staged2 t2e1)))
; i0j-2
 (defvc inf-vc-stsy-i0j-2 (under inf-stsy-c10 (pi syd1 nat g5 (inf-lt xt2 256) staged2 nat (inf-le bct2 63)))
   (given inf-stsy-c10 (lam syd1 g5 staged2 t2e3)))
; i0j-3
 (defvc inf-vc-stsy-i0j-3 (under inf-stsy-c10 (pi syd1 nat g5 (inf-lt xt2 256) staged2 nat (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-stsy-c10 (lam syd1 g5 staged2 t2e4)))
; i0j-4
 (defvc inf-vc-stsy-i0j-4 (under inf-stsy-c10 (pi syd1 nat g5 (inf-lt xt2 256) staged2 nat (inf-le cons0 const2)))
   (given inf-stsy-c10 (lam syd1 g5 staged2 (inf-letrans cons0 consi1 const2 k5 t2e5))))
; i0j-5
 (defvc inf-vc-stsy-i0j-5 (under inf-stsy-c10 (pi syd1 nat g5 (inf-lt xt2 256) staged2 nat (inf-le o0 opi1)))
   (given inf-stsy-c10 (lam syd1 g5 staged2 k6)))
; i0j-6
 (defvc inf-vc-stsy-i0j-6 (under inf-stsy-c10 (pi syd1 nat g5 (inf-lt xt2 256) staged2 nat (inf-le opi1 cap)))
   (given inf-stsy-c10 (lam syd1 g5 staged2 k7)))
; i0j-7
 (defvc inf-vc-stsy-i0j-7 (under inf-stsy-c10 (pi syd1 nat g5 (inf-lt xt2 256) staged2 nat (inf-le op0 opi1)))
   (given inf-stsy-c10 (lam syd1 g5 staged2 k8)))
; r1-1
 (defvc inf-vc-stsy-r1-1 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (inf-lt 0 last) modee2a nat (inf-le ipt2 n)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2a t2e1)))
; r1-2
 (defvc inf-vc-stsy-r1-2 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (inf-lt 0 last) modee2a nat (inf-le bct2 63)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2a t2e3)))
; r1-3
 (defvc inf-vc-stsy-r1-3 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (inf-lt 0 last) modee2a nat (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2a t2e4)))
; r1-4
 (defvc inf-vc-stsy-r1-4 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (inf-lt 0 last) modee2a nat (inf-le cons0 const2)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2a (inf-letrans cons0 consi1 const2 k5 t2e5))))
; r1-5
 (defvc inf-vc-stsy-r1-5 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (inf-lt 0 last) modee2a nat (inf-le opi1 cap)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2a k7)))
; r1-6
 (defvc inf-vc-stsy-r1-6 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (inf-lt 0 last) modee2a nat (inf-le op0 opi1)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2a (inf-letrans op0 op opi1 o1 ((inf-letr o0 op opi1 eo k6))))))
; r1-7
 (defvc inf-vc-stsy-r1-7 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (paths nat last 0) modee2b nat (inf-le ipt2 n)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2b t2e1)))
; r1-8
 (defvc inf-vc-stsy-r1-8 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (paths nat last 0) modee2b nat (inf-le bct2 63)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2b t2e3)))
; r1-9
 (defvc inf-vc-stsy-r1-9 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (paths nat last 0) modee2b nat (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2b t2e4)))
; r1-10
 (defvc inf-vc-stsy-r1-10 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (paths nat last 0) modee2b nat (inf-le cons0 const2)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2b (inf-letrans cons0 consi1 const2 k5 t2e5))))
; r1-11
 (defvc inf-vc-stsy-r1-11 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (paths nat last 0) modee2b nat (inf-le opi1 cap)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2b k7)))
; r1-12
 (defvc inf-vc-stsy-r1-12 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-le xt2 256) ge2 (paths nat last 0) modee2b nat (inf-le op0 opi1)))
   (given inf-stsy-c10 (lam syd1 g5 g6 ge2 modee2b (inf-letrans op0 op opi1 o1 ((inf-letr o0 op opi1 eo k6))))))
; i0j-8
 (defvc inf-vc-stsy-i0j-8 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-lt 256 xt2) staged3 nat (inf-le ipt2 n)))
   (given inf-stsy-c10 (lam syd1 g5 g6 staged3 t2e1)))
; i0j-9
 (defvc inf-vc-stsy-i0j-9 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-lt 256 xt2) staged3 nat (inf-le bct2 63)))
   (given inf-stsy-c10 (lam syd1 g5 g6 staged3 t2e3)))
; i0j-10
 (defvc inf-vc-stsy-i0j-10 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-lt 256 xt2) staged3 nat (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-stsy-c10 (lam syd1 g5 g6 staged3 t2e4)))
; i0j-11
 (defvc inf-vc-stsy-i0j-11 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-lt 256 xt2) staged3 nat (inf-le cons0 const2)))
   (given inf-stsy-c10 (lam syd1 g5 g6 staged3 (inf-letrans cons0 consi1 const2 k5 t2e5))))
; i0j-12
 (defvc inf-vc-stsy-i0j-12 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-lt 256 xt2) staged3 nat (inf-le o0 opi1)))
   (given inf-stsy-c10 (lam syd1 g5 g6 staged3 k6)))
; i0j-13
 (defvc inf-vc-stsy-i0j-13 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-lt 256 xt2) staged3 nat (inf-le opi1 cap)))
   (given inf-stsy-c10 (lam syd1 g5 g6 staged3 k7)))
; i0j-14
 (defvc inf-vc-stsy-i0j-14 (under inf-stsy-c10 (pi syd1 nat g5 (inf-le 256 xt2) g6 (inf-lt 256 xt2) staged3 nat (inf-le op0 opi1)))
   (given inf-stsy-c10 (lam syd1 g5 g6 staged3 k8)))
; i0j-15
 (defvc inf-vc-stsy-i0j-15 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (inf-lt 0 stage) (inf-le ip n)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 r1)))
; i0j-16
 (defvc inf-vc-stsy-i0j-16 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (inf-lt 0 stage) (inf-le bc 63)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 r3)))
; i0j-17
 (defvc inf-vc-stsy-i0j-17 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (inf-lt 0 stage) (inf-bits-inv carry ip cons bc)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 r4)))
; i0j-18
 (defvc inf-vc-stsy-i0j-18 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (inf-lt 0 stage) (inf-le cons0 cons)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 r5)))
; i0j-19
 (defvc inf-vc-stsy-i0j-19 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (inf-lt 0 stage) (inf-le o0 op)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))))))
; i0j-20
 (defvc inf-vc-stsy-i0j-20 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (inf-lt 0 stage) (inf-le op cap)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 o2)))
; i0j-21
 (defvc inf-vc-stsy-i0j-21 (under inf-stsy-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g0 (inf-lt 0 stage) (inf-le op0 op)))
   (given inf-stsy-w1 (lam w1 o0 eo g0 o1)))
 (defcx inf-stsy-c1 inf-stsy-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (ipi0 nat) (bci0 nat) (bbi0 nat) (consi0 nat) (opi0 nat) (modei0 nat) (syi0 nat) (stagei0 nat) (k1 (inf-le ipi0 n)) (k3 (inf-le bci0 63)) (k4 (inf-bits-inv carry ipi0 consi0 bci0)) (k5 (inf-le cons0 consi0)) (k6 (inf-le o0 opi0)) (k7 (inf-le opi0 cap)) (k8 (inf-le op0 opi0)) )
; r2-1
 (defvc inf-vc-stsy-r2-1 (under inf-stsy-c1 (pi g7 unit g8 (inf-le cap opi0) (inf-le ipi0 n)))
   (given inf-stsy-c1 (lam g7 g8 k1)))
; r2-2
 (defvc inf-vc-stsy-r2-2 (under inf-stsy-c1 (pi g7 unit g8 (inf-le cap opi0) (inf-le bci0 63)))
   (given inf-stsy-c1 (lam g7 g8 k3)))
; r2-3
 (defvc inf-vc-stsy-r2-3 (under inf-stsy-c1 (pi g7 unit g8 (inf-le cap opi0) (inf-bits-inv carry ipi0 consi0 bci0)))
   (given inf-stsy-c1 (lam g7 g8 k4)))
; r2-4
 (defvc inf-vc-stsy-r2-4 (under inf-stsy-c1 (pi g7 unit g8 (inf-le cap opi0) (inf-le cons0 consi0)))
   (given inf-stsy-c1 (lam g7 g8 k5)))
; r2-5
 (defvc inf-vc-stsy-r2-5 (under inf-stsy-c1 (pi g7 unit g8 (inf-le cap opi0) (inf-le opi0 cap)))
   (given inf-stsy-c1 (lam g7 g8 k7)))
; r2-6
 (defvc inf-vc-stsy-r2-6 (under inf-stsy-c1 (pi g7 unit g8 (inf-le cap opi0) (inf-le op0 opi0)))
   (given inf-stsy-c1 (lam g7 g8 k8)))
; r3-1
 (defvc inf-vc-stsy-r3-1 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-lt 255 syi0) (inf-le ipi0 n)))
   (given inf-stsy-c1 (lam g7 g8 g9 k1)))
; r3-2
 (defvc inf-vc-stsy-r3-2 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-lt 255 syi0) (inf-le bci0 63)))
   (given inf-stsy-c1 (lam g7 g8 g9 k3)))
; r3-3
 (defvc inf-vc-stsy-r3-3 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-lt 255 syi0) (inf-bits-inv carry ipi0 consi0 bci0)))
   (given inf-stsy-c1 (lam g7 g8 g9 k4)))
; r3-4
 (defvc inf-vc-stsy-r3-4 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-lt 255 syi0) (inf-le cons0 consi0)))
   (given inf-stsy-c1 (lam g7 g8 g9 k5)))
; r3-5
 (defvc inf-vc-stsy-r3-5 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-lt 255 syi0) (inf-le opi0 cap)))
   (given inf-stsy-c1 (lam g7 g8 g9 k7)))
; r3-6
 (defvc inf-vc-stsy-r3-6 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-lt 255 syi0) (inf-le op0 opi0)))
   (given inf-stsy-c1 (lam g7 g8 g9 k8)))
; p1-1
 (defvc inf-vc-stsy-p1-1 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) (inf-lt opi0 oc)))
   (given inf-stsy-c1 (lam g7 g8 g9 (inf-lttrans opi0 cap oc g8 ((inf-letl cap cap oc (pathsinv0 nat oc cap (go gz)) (inf-refl cap)))))))
; p1-2
 (defvc inf-vc-stsy-p1-2 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) (inf-lt syi0 256)))
   (given inf-stsy-c1 (lam g7 g8 g9 (inf-lelts syi0 255 g9))))
; s1-1
 (defvc inf-vc-stsy-s1-1 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) (inf-lt (add opi0 1) (inf-pow w))))
   (given inf-stsy-c1 (lam g7 g8 g9 (inf-lelt (add opi0 1) cap (inf-pow w) (inf-lt1 opi0 cap g8) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap))))))
; w1b-1
 (defvc inf-vc-stsy-w1b-1 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) staged4 nat (inf-le ipi0 n)))
   (given inf-stsy-c1 (lam g7 g8 g9 staged4 k1)))
; w1b-2
 (defvc inf-vc-stsy-w1b-2 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) staged4 nat (inf-le bci0 63)))
   (given inf-stsy-c1 (lam g7 g8 g9 staged4 k3)))
; w1b-3
 (defvc inf-vc-stsy-w1b-3 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) staged4 nat (inf-bits-inv carry ipi0 consi0 bci0)))
   (given inf-stsy-c1 (lam g7 g8 g9 staged4 k4)))
; w1b-4
 (defvc inf-vc-stsy-w1b-4 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) staged4 nat (inf-le cons0 consi0)))
   (given inf-stsy-c1 (lam g7 g8 g9 staged4 k5)))
; w1b-5
 (defvc inf-vc-stsy-w1b-5 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) staged4 nat (inf-le op0 (add opi0 1))))
   (given inf-stsy-c1 (lam g7 g8 g9 staged4 (inf-letrans op0 opi0 (add opi0 1) ((inf-letrans op0 op opi0 o1 ((inf-letr o0 op opi0 eo k6)))) (inf-leaddr opi0 1)))))
; w1b-6
 (defvc inf-vc-stsy-w1b-6 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) staged4 nat (inf-le (add opi0 1) cap)))
   (given inf-stsy-c1 (lam g7 g8 g9 staged4 (inf-lt1 opi0 cap g8))))
; w1b-7
 (defvc inf-vc-stsy-w1b-7 (under inf-stsy-c1 (pi g7 unit g8 (inf-lt opi0 cap) g9 (inf-le syi0 255) staged4 nat (inf-lt (natminus cap (add opi0 1)) (natminus cap op))))
   (given inf-stsy-c1 (lam g7 g8 g9 staged4 (inf-subfrom op opi0 cap 1 ((inf-letr o0 op opi0 eo k6)) g8 (idpath true)))))
; r4-1
 (defvc inf-vc-stsy-r4-1 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-lt syi0 257) (inf-le ipi0 n)))
   (given inf-stsy-c1 (lam g7 g10 g11 k1)))
; r4-2
 (defvc inf-vc-stsy-r4-2 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-lt syi0 257) (inf-le bci0 63)))
   (given inf-stsy-c1 (lam g7 g10 g11 k3)))
; r4-3
 (defvc inf-vc-stsy-r4-3 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-lt syi0 257) (inf-bits-inv carry ipi0 consi0 bci0)))
   (given inf-stsy-c1 (lam g7 g10 g11 k4)))
; r4-4
 (defvc inf-vc-stsy-r4-4 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-lt syi0 257) (inf-le cons0 consi0)))
   (given inf-stsy-c1 (lam g7 g10 g11 k5)))
; r4-5
 (defvc inf-vc-stsy-r4-5 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-lt syi0 257) (inf-le opi0 cap)))
   (given inf-stsy-c1 (lam g7 g10 g11 k7)))
; r4-6
 (defvc inf-vc-stsy-r4-6 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-lt syi0 257) (inf-le op0 opi0)))
   (given inf-stsy-c1 (lam g7 g10 g11 k8)))
; r5-1
 (defvc inf-vc-stsy-r5-1 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-lt 285 syi0) (inf-le ipi0 n)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 k1)))
; r5-2
 (defvc inf-vc-stsy-r5-2 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-lt 285 syi0) (inf-le bci0 63)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 k3)))
; r5-3
 (defvc inf-vc-stsy-r5-3 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-lt 285 syi0) (inf-bits-inv carry ipi0 consi0 bci0)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 k4)))
; r5-4
 (defvc inf-vc-stsy-r5-4 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-lt 285 syi0) (inf-le cons0 consi0)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 k5)))
; r5-5
 (defvc inf-vc-stsy-r5-5 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-lt 285 syi0) (inf-le opi0 cap)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 k7)))
; r5-6
 (defvc inf-vc-stsy-r5-6 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-lt 285 syi0) (inf-le op0 opi0)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 k8)))
; s2-1
 (defvc inf-vc-stsy-s2-1 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) (inf-le 257 syi0)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 g11)))
; s2-2
 (defvc inf-vc-stsy-s2-2 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) (inf-lt (natminus syi0 257) 29)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 ((inf-lidx syi0 g12)))))
; s2-3
 (defvc inf-vc-stsy-s2-3 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) (inf-lt (Lb (natminus syi0 257)) (inf-pow w))))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 (inf-lelt (Lb ((natminus syi0 257))) 259 (inf-pow w) (inf-letrans (Lb ((natminus syi0 257))) (add (Lb ((natminus syi0 257))) (inf-pow ((Le ((natminus syi0 257)))))) 259 (inf-leaddr (Lb ((natminus syi0 257))) (inf-pow ((Le ((natminus syi0 257)))))) ((hlb ((natminus syi0 257)) ((inf-lidx syi0 g12))))) ((inf-lelt 259 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; t3-1
 (defvc inf-vc-stsy-t3-1 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) (inf-le 32 w)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 gw)))
; t3-2
 (defvc inf-vc-stsy-t3-2 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) (inf-lt (add n 8) (inf-pow w))))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 gn)))
; t3-3
 (defvc inf-vc-stsy-t3-3 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) (inf-le ipi0 n)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 k1)))
; t3-4
 (defvc inf-vc-stsy-t3-4 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) (inf-le bci0 63)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 k3)))
; t3-5
 (defvc inf-vc-stsy-t3-5 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) (inf-bits-inv carry ipi0 consi0 bci0)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 k4)))
; t3-6
 (defvc inf-vc-stsy-t3-6 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) (inf-le (Le (natminus syi0 257)) 13)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 (inf-letrans ((Le ((natminus syi0 257)))) 5 13 (hle ((natminus syi0 257)) ((inf-lidx syi0 g12))) (idpath false)))))
; t3s-1
 (defvc inf-vc-stsy-t3s-1 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) ipt3 nat bct3 nat bbt3 nat const3 nat yt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consi0 const3) (inf-le ipt3 n)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 ipt3 bct3 bbt3 const3 yt3 t3e1 t3e3 t3e4 t3e5 t3e1)))
; t3s-2
 (defvc inf-vc-stsy-t3s-2 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) ipt3 nat bct3 nat bbt3 nat const3 nat yt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consi0 const3) (inf-le bct3 63)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 ipt3 bct3 bbt3 const3 yt3 t3e1 t3e3 t3e4 t3e5 t3e3)))
; t3s-3
 (defvc inf-vc-stsy-t3s-3 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) ipt3 nat bct3 nat bbt3 nat const3 nat yt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consi0 const3) (inf-bits-inv carry ipt3 const3 bct3)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 ipt3 bct3 bbt3 const3 yt3 t3e1 t3e3 t3e4 t3e5 t3e4)))
; t3s-4
 (defvc inf-vc-stsy-t3s-4 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) ipt3 nat bct3 nat bbt3 nat const3 nat yt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consi0 const3) (inf-le cons0 const3)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 ipt3 bct3 bbt3 const3 yt3 t3e1 t3e3 t3e4 t3e5 (inf-letrans cons0 consi0 const3 k5 t3e5))))
; t3s-5
 (defvc inf-vc-stsy-t3s-5 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) ipt3 nat bct3 nat bbt3 nat const3 nat yt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consi0 const3) (inf-le opi0 cap)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 ipt3 bct3 bbt3 const3 yt3 t3e1 t3e3 t3e4 t3e5 k7)))
; t3s-6
 (defvc inf-vc-stsy-t3s-6 (under inf-stsy-c1 (pi g7 unit g10 unit g11 (inf-le 257 syi0) g12 (inf-le syi0 285) ipt3 nat bct3 nat bbt3 nat const3 nat yt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consi0 const3) (inf-le op0 opi0)))
   (given inf-stsy-c1 (lam g7 g10 g11 g12 ipt3 bct3 bbt3 const3 yt3 t3e1 t3e3 t3e4 t3e5 k8)))
 (defcx inf-stsy-c8 inf-stsy-c1 (g7 unit) (g10 unit) (g11 (inf-le 257 syi0)) (g12 (inf-le syi0 285)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (yt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le consi0 const3)) (t3e6 (inf-le (add consi0 (Le (natminus syi0 257))) const3)) (t3e7 (inf-lt yt3 (inf-pow (Le (natminus syi0 257))))) )
; d5-1
 (defvc inf-vc-stsy-d5-1 (under inf-stsy-c8 (inf-lt (add (Lb (natminus syi0 257)) yt3) (inf-pow w)))
   (given inf-stsy-c8 (inf-lttrans ((add (Lb ((natminus syi0 257))) yt3)) 259 (inf-pow w) ((inf-basele (Lb ((natminus syi0 257))) ((Le ((natminus syi0 257)))) yt3 259 t3e7 ((hlb ((natminus syi0 257)) ((inf-lidx syi0 g12)))))) (inf-ltle 259 (inf-pow w) ((inf-lelt 259 512 (inf-pow w) (idpath false) ((inf-wnine w gw))))))))
; j1j-1
 (defvc inf-vc-stsy-j1j-1 (under inf-stsy-c8 (pi lend5 nat staged6 nat (inf-le ipt3 n)))
   (given inf-stsy-c8 (lam lend5 staged6 t3e1)))
; j1j-2
 (defvc inf-vc-stsy-j1j-2 (under inf-stsy-c8 (pi lend5 nat staged6 nat (inf-le bct3 63)))
   (given inf-stsy-c8 (lam lend5 staged6 t3e3)))
; j1j-3
 (defvc inf-vc-stsy-j1j-3 (under inf-stsy-c8 (pi lend5 nat staged6 nat (inf-bits-inv carry ipt3 const3 bct3)))
   (given inf-stsy-c8 (lam lend5 staged6 t3e4)))
; j1j-4
 (defvc inf-vc-stsy-j1j-4 (under inf-stsy-c8 (pi lend5 nat staged6 nat (inf-le cons0 const3)))
   (given inf-stsy-c8 (lam lend5 staged6 (inf-letrans cons0 consi0 const3 k5 t3e5))))
; j1j-5
 (defvc inf-vc-stsy-j1j-5 (under inf-stsy-c1 (pi g7 unit g10 unit (inf-le ipi0 n)))
   (given inf-stsy-c1 (lam g7 g10 k1)))
; j1j-6
 (defvc inf-vc-stsy-j1j-6 (under inf-stsy-c1 (pi g7 unit g10 unit (inf-le bci0 63)))
   (given inf-stsy-c1 (lam g7 g10 k3)))
; j1j-7
 (defvc inf-vc-stsy-j1j-7 (under inf-stsy-c1 (pi g7 unit g10 unit (inf-bits-inv carry ipi0 consi0 bci0)))
   (given inf-stsy-c1 (lam g7 g10 k4)))
; j1j-8
 (defvc inf-vc-stsy-j1j-8 (under inf-stsy-c1 (pi g7 unit g10 unit (inf-le cons0 consi0)))
   (given inf-stsy-c1 (lam g7 g10 k5)))
 (defcx inf-stsy-c2 inf-stsy-c1 (g7 unit) (ipj1 nat) (bcj1 nat) (bbj1 nat) (consj1 nat) (lenj1 nat) (stagej1 nat) (m1 (inf-le ipj1 n)) (m3 (inf-le bcj1 63)) (m4 (inf-bits-inv carry ipj1 consj1 bcj1)) (m5 (inf-le cons0 consj1)) )
; t4-1
 (defvc inf-vc-stsy-t4-1 (under inf-stsy-c2 (pi g13 unit (inf-le 32 w)))
   (given inf-stsy-c2 (lam g13 gw)))
; t4-2
 (defvc inf-vc-stsy-t4-2 (under inf-stsy-c2 (pi g13 unit (inf-lt (add n 8) (inf-pow w))))
   (given inf-stsy-c2 (lam g13 gn)))
; t4-3
 (defvc inf-vc-stsy-t4-3 (under inf-stsy-c2 (pi g13 unit (inf-le ipj1 n)))
   (given inf-stsy-c2 (lam g13 m1)))
; t4-4
 (defvc inf-vc-stsy-t4-4 (under inf-stsy-c2 (pi g13 unit (inf-le bcj1 63)))
   (given inf-stsy-c2 (lam g13 m3)))
; t4-5
 (defvc inf-vc-stsy-t4-5 (under inf-stsy-c2 (pi g13 unit (inf-bits-inv carry ipj1 consj1 bcj1)))
   (given inf-stsy-c2 (lam g13 m4)))
; t4-6
 (defvc inf-vc-stsy-t4-6 (under inf-stsy-c2 (pi g13 unit (pi i nat (inf-lt (Dc i) (inf-pow h)))))
   (given inf-stsy-c2 (lam g13 c5)))
; t4-7
 (defvc inf-vc-stsy-t4-7 (under inf-stsy-c2 (pi g13 unit (pi i nat (inf-lt (Ds i) (inf-pow h)))))
   (given inf-stsy-c2 (lam g13 c6)))
; t4-8
 (defvc inf-vc-stsy-t4-8 (under inf-stsy-c2 (pi g13 unit (inf-le h 16)))
   (given inf-stsy-c2 (lam g13 gh)))
; t4-9
 (defvc inf-vc-stsy-t4-9 (under inf-stsy-c2 (pi g13 unit (inf-lt dm (inf-pow w))))
   (given inf-stsy-c2 (lam g13 (inf-wlit dm w gw (inf-letrans dm 32 63 c8 (idpath false))))))
; t4-10
 (defvc inf-vc-stsy-t4-10 (under inf-stsy-c2 (pi g13 unit (inf-le (inf-sum Dc 15 1) dm)))
   (given inf-stsy-c2 (lam g13 c7)))
; t4-11
 (defvc inf-vc-stsy-t4-11 (under inf-stsy-c2 (pi g13 unit (inf-le DROOT 15)))
   (given inf-stsy-c2 (lam g13 gd)))
; t4s-1
 (defvc inf-vc-stsy-t4s-1 (under inf-stsy-c2 (pi g13 unit ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj1 const4) (inf-le ipt4 n)))
   (given inf-stsy-c2 (lam g13 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 t4e1)))
; t4s-2
 (defvc inf-vc-stsy-t4s-2 (under inf-stsy-c2 (pi g13 unit ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj1 const4) (inf-le bct4 63)))
   (given inf-stsy-c2 (lam g13 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 t4e3)))
; t4s-3
 (defvc inf-vc-stsy-t4s-3 (under inf-stsy-c2 (pi g13 unit ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj1 const4) (inf-bits-inv carry ipt4 const4 bct4)))
   (given inf-stsy-c2 (lam g13 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 t4e4)))
; t4s-4
 (defvc inf-vc-stsy-t4s-4 (under inf-stsy-c2 (pi g13 unit ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj1 const4) (inf-le cons0 const4)))
   (given inf-stsy-c2 (lam g13 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 (inf-letrans cons0 consj1 const4 m5 t4e5))))
; t4s-5
 (defvc inf-vc-stsy-t4s-5 (under inf-stsy-c2 (pi g13 unit ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj1 const4) (inf-le opi0 cap)))
   (given inf-stsy-c2 (lam g13 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 k7)))
; t4s-6
 (defvc inf-vc-stsy-t4s-6 (under inf-stsy-c2 (pi g13 unit ipt4 nat bct4 nat bbt4 nat const4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj1 const4) (inf-le op0 opi0)))
   (given inf-stsy-c2 (lam g13 ipt4 bct4 bbt4 const4 xt4 t4e1 t4e3 t4e4 t4e5 k8)))
 (defcx inf-stsy-c7 inf-stsy-c2 (g13 unit) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le consj1 const4)) )
; j2j-1
 (defvc inf-vc-stsy-j2j-1 (under inf-stsy-c7 (pi syd7 nat staged8 nat (inf-le ipt4 n)))
   (given inf-stsy-c7 (lam syd7 staged8 t4e1)))
; j2j-2
 (defvc inf-vc-stsy-j2j-2 (under inf-stsy-c7 (pi syd7 nat staged8 nat (inf-le bct4 63)))
   (given inf-stsy-c7 (lam syd7 staged8 t4e3)))
; j2j-3
 (defvc inf-vc-stsy-j2j-3 (under inf-stsy-c7 (pi syd7 nat staged8 nat (inf-bits-inv carry ipt4 const4 bct4)))
   (given inf-stsy-c7 (lam syd7 staged8 t4e4)))
; j2j-4
 (defvc inf-vc-stsy-j2j-4 (under inf-stsy-c7 (pi syd7 nat staged8 nat (inf-le cons0 const4)))
   (given inf-stsy-c7 (lam syd7 staged8 (inf-letrans cons0 consj1 const4 m5 t4e5))))
; j2j-5
 (defvc inf-vc-stsy-j2j-5 (under inf-stsy-c2 (pi g13 unit (inf-le ipj1 n)))
   (given inf-stsy-c2 (lam g13 m1)))
; j2j-6
 (defvc inf-vc-stsy-j2j-6 (under inf-stsy-c2 (pi g13 unit (inf-le bcj1 63)))
   (given inf-stsy-c2 (lam g13 m3)))
; j2j-7
 (defvc inf-vc-stsy-j2j-7 (under inf-stsy-c2 (pi g13 unit (inf-bits-inv carry ipj1 consj1 bcj1)))
   (given inf-stsy-c2 (lam g13 m4)))
; j2j-8
 (defvc inf-vc-stsy-j2j-8 (under inf-stsy-c2 (pi g13 unit (inf-le cons0 consj1)))
   (given inf-stsy-c2 (lam g13 m5)))
 (defcx inf-stsy-c3 inf-stsy-c2 (ipj2 nat) (bcj2 nat) (bbj2 nat) (consj2 nat) (syj2 nat) (stagej2 nat) (n1 (inf-le ipj2 n)) (n3 (inf-le bcj2 63)) (n4 (inf-bits-inv carry ipj2 consj2 bcj2)) (n5 (inf-le cons0 consj2)) )
; r6-1
 (defvc inf-vc-stsy-r6-1 (under inf-stsy-c3 (pi g14 unit g15 (inf-lt 29 syj2) (inf-le ipj2 n)))
   (given inf-stsy-c3 (lam g14 g15 n1)))
; r6-2
 (defvc inf-vc-stsy-r6-2 (under inf-stsy-c3 (pi g14 unit g15 (inf-lt 29 syj2) (inf-le bcj2 63)))
   (given inf-stsy-c3 (lam g14 g15 n3)))
; r6-3
 (defvc inf-vc-stsy-r6-3 (under inf-stsy-c3 (pi g14 unit g15 (inf-lt 29 syj2) (inf-bits-inv carry ipj2 consj2 bcj2)))
   (given inf-stsy-c3 (lam g14 g15 n4)))
; r6-4
 (defvc inf-vc-stsy-r6-4 (under inf-stsy-c3 (pi g14 unit g15 (inf-lt 29 syj2) (inf-le cons0 consj2)))
   (given inf-stsy-c3 (lam g14 g15 n5)))
; r6-5
 (defvc inf-vc-stsy-r6-5 (under inf-stsy-c3 (pi g14 unit g15 (inf-lt 29 syj2) (inf-le opi0 cap)))
   (given inf-stsy-c3 (lam g14 g15 k7)))
; r6-6
 (defvc inf-vc-stsy-r6-6 (under inf-stsy-c3 (pi g14 unit g15 (inf-lt 29 syj2) (inf-le op0 opi0)))
   (given inf-stsy-c3 (lam g14 g15 k8)))
; s3-1
 (defvc inf-vc-stsy-s3-1 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) (inf-lt syj2 30)))
   (given inf-stsy-c3 (lam g14 g15 (inf-lelts syj2 29 g15))))
; s3-2
 (defvc inf-vc-stsy-s3-2 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) (inf-lt (Db syj2) (inf-pow w))))
   (given inf-stsy-c3 (lam g14 g15 (inf-lttrans (Db syj2) (inf-pow h) (inf-pow w) (inf-lttrans (Db syj2) (add (Db syj2) (inf-pow ((De syj2)))) (inf-pow h) (inf-ltaddpos (Db syj2) (inf-pow ((De syj2))) (inf-powpos ((De syj2)))) (hdb syj2 ((inf-lelts syj2 29 g15)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))))
; t5-1
 (defvc inf-vc-stsy-t5-1 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) (inf-le 32 w)))
   (given inf-stsy-c3 (lam g14 g15 gw)))
; t5-2
 (defvc inf-vc-stsy-t5-2 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) (inf-lt (add n 8) (inf-pow w))))
   (given inf-stsy-c3 (lam g14 g15 gn)))
; t5-3
 (defvc inf-vc-stsy-t5-3 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) (inf-le ipj2 n)))
   (given inf-stsy-c3 (lam g14 g15 n1)))
; t5-4
 (defvc inf-vc-stsy-t5-4 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) (inf-le bcj2 63)))
   (given inf-stsy-c3 (lam g14 g15 n3)))
; t5-5
 (defvc inf-vc-stsy-t5-5 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) (inf-bits-inv carry ipj2 consj2 bcj2)))
   (given inf-stsy-c3 (lam g14 g15 n4)))
; t5-6
 (defvc inf-vc-stsy-t5-6 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) (inf-le (De syj2) 13)))
   (given inf-stsy-c3 (lam g14 g15 (hde syj2 ((inf-lelts syj2 29 g15))))))
; t5s-1
 (defvc inf-vc-stsy-t5s-1 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) ipt5 nat bct5 nat bbt5 nat const5 nat yt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj2 const5) (inf-le ipt5 n)))
   (given inf-stsy-c3 (lam g14 g15 ipt5 bct5 bbt5 const5 yt5 t5e1 t5e3 t5e4 t5e5 t5e1)))
; t5s-2
 (defvc inf-vc-stsy-t5s-2 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) ipt5 nat bct5 nat bbt5 nat const5 nat yt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj2 const5) (inf-le bct5 63)))
   (given inf-stsy-c3 (lam g14 g15 ipt5 bct5 bbt5 const5 yt5 t5e1 t5e3 t5e4 t5e5 t5e3)))
; t5s-3
 (defvc inf-vc-stsy-t5s-3 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) ipt5 nat bct5 nat bbt5 nat const5 nat yt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj2 const5) (inf-bits-inv carry ipt5 const5 bct5)))
   (given inf-stsy-c3 (lam g14 g15 ipt5 bct5 bbt5 const5 yt5 t5e1 t5e3 t5e4 t5e5 t5e4)))
; t5s-4
 (defvc inf-vc-stsy-t5s-4 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) ipt5 nat bct5 nat bbt5 nat const5 nat yt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj2 const5) (inf-le cons0 const5)))
   (given inf-stsy-c3 (lam g14 g15 ipt5 bct5 bbt5 const5 yt5 t5e1 t5e3 t5e4 t5e5 (inf-letrans cons0 consj2 const5 n5 t5e5))))
; t5s-5
 (defvc inf-vc-stsy-t5s-5 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) ipt5 nat bct5 nat bbt5 nat const5 nat yt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj2 const5) (inf-le opi0 cap)))
   (given inf-stsy-c3 (lam g14 g15 ipt5 bct5 bbt5 const5 yt5 t5e1 t5e3 t5e4 t5e5 k7)))
; t5s-6
 (defvc inf-vc-stsy-t5s-6 (under inf-stsy-c3 (pi g14 unit g15 (inf-le syj2 29) ipt5 nat bct5 nat bbt5 nat const5 nat yt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj2 const5) (inf-le op0 opi0)))
   (given inf-stsy-c3 (lam g14 g15 ipt5 bct5 bbt5 const5 yt5 t5e1 t5e3 t5e4 t5e5 k8)))
 (defcx inf-stsy-c6 inf-stsy-c3 (g14 unit) (g15 (inf-le syj2 29)) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (yt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv carry ipt5 const5 bct5)) (t5e5 (inf-le consj2 const5)) (t5e6 (inf-le (add consj2 (De syj2)) const5)) (t5e7 (inf-lt yt5 (inf-pow (De syj2)))) )
; d9-1
 (defvc inf-vc-stsy-d9-1 (under inf-stsy-c6 (inf-lt (add (Db syj2) yt5) (inf-pow w)))
   (given inf-stsy-c6 ((inf-lttrans ((add (Db syj2) yt5)) (inf-pow h) (inf-pow w) (inf-basele (Db syj2) ((De syj2)) yt5 (inf-pow h) t5e7 (hdb syj2 ((inf-lelts syj2 29 g15)))) ((inf-powle h w (inf-letrans h 16 w gh (inf-letrans 16 32 w (idpath false) gw))))))))
; j3j-1
 (defvc inf-vc-stsy-j3j-1 (under inf-stsy-c6 (pi distd9 nat staged10 nat (inf-le ipt5 n)))
   (given inf-stsy-c6 (lam distd9 staged10 t5e1)))
; j3j-2
 (defvc inf-vc-stsy-j3j-2 (under inf-stsy-c6 (pi distd9 nat staged10 nat (inf-le bct5 63)))
   (given inf-stsy-c6 (lam distd9 staged10 t5e3)))
; j3j-3
 (defvc inf-vc-stsy-j3j-3 (under inf-stsy-c6 (pi distd9 nat staged10 nat (inf-bits-inv carry ipt5 const5 bct5)))
   (given inf-stsy-c6 (lam distd9 staged10 t5e4)))
; j3j-4
 (defvc inf-vc-stsy-j3j-4 (under inf-stsy-c6 (pi distd9 nat staged10 nat (inf-le cons0 const5)))
   (given inf-stsy-c6 (lam distd9 staged10 (inf-letrans cons0 consj2 const5 n5 t5e5))))
; j3j-5
 (defvc inf-vc-stsy-j3j-5 (under inf-stsy-c3 (pi g14 unit (inf-le ipj2 n)))
   (given inf-stsy-c3 (lam g14 n1)))
; j3j-6
 (defvc inf-vc-stsy-j3j-6 (under inf-stsy-c3 (pi g14 unit (inf-le bcj2 63)))
   (given inf-stsy-c3 (lam g14 n3)))
; j3j-7
 (defvc inf-vc-stsy-j3j-7 (under inf-stsy-c3 (pi g14 unit (inf-bits-inv carry ipj2 consj2 bcj2)))
   (given inf-stsy-c3 (lam g14 n4)))
; j3j-8
 (defvc inf-vc-stsy-j3j-8 (under inf-stsy-c3 (pi g14 unit (inf-le cons0 consj2)))
   (given inf-stsy-c3 (lam g14 n5)))
 (defcx inf-stsy-c4 inf-stsy-c3 (ipj3 nat) (bcj3 nat) (bbj3 nat) (consj3 nat) (distj3 nat) (stagej3 nat) (q1 (inf-le ipj3 n)) (q3 (inf-le bcj3 63)) (q4 (inf-bits-inv carry ipj3 consj3 bcj3)) (q5 (inf-le cons0 consj3)) )
; i13-1
 (defvc inf-vc-stsy-i13-1 (under inf-stsy-c4 (inf-lt 15 32))
   (given inf-stsy-c4 (idpath true)))
; i13-2
 (defvc inf-vc-stsy-i13-2 (under inf-stsy-c4 (inf-lt (inf-pow 15) (inf-pow w)))
   (given inf-stsy-c4 ((inf-powlt 15 w (inf-lttrans 15 16 w (idpath true) (inf-letrans 16 32 w (idpath false) gw))))))
; r7-1
 (defvc inf-vc-stsy-r7-1 (under inf-stsy-c4 (pi g16 (inf-lt (inf-pow 15) distj3) (inf-le ipj3 n)))
   (given inf-stsy-c4 (lam g16 q1)))
; r7-2
 (defvc inf-vc-stsy-r7-2 (under inf-stsy-c4 (pi g16 (inf-lt (inf-pow 15) distj3) (inf-le bcj3 63)))
   (given inf-stsy-c4 (lam g16 q3)))
; r7-3
 (defvc inf-vc-stsy-r7-3 (under inf-stsy-c4 (pi g16 (inf-lt (inf-pow 15) distj3) (inf-bits-inv carry ipj3 consj3 bcj3)))
   (given inf-stsy-c4 (lam g16 q4)))
; r7-4
 (defvc inf-vc-stsy-r7-4 (under inf-stsy-c4 (pi g16 (inf-lt (inf-pow 15) distj3) (inf-le cons0 consj3)))
   (given inf-stsy-c4 (lam g16 q5)))
; r7-5
 (defvc inf-vc-stsy-r7-5 (under inf-stsy-c4 (pi g16 (inf-lt (inf-pow 15) distj3) (inf-le opi0 cap)))
   (given inf-stsy-c4 (lam g16 k7)))
; r7-6
 (defvc inf-vc-stsy-r7-6 (under inf-stsy-c4 (pi g16 (inf-lt (inf-pow 15) distj3) (inf-le op0 opi0)))
   (given inf-stsy-c4 (lam g16 k8)))
; i14-1
 (defvc inf-vc-stsy-i14-1 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) (inf-lt (add opi0 nd) (inf-pow w))))
   (given inf-stsy-c4 (lam g16 (inf-lelt (add opi0 nd) (add cap nd) (inf-pow w) (inf-addr opi0 cap nd k7) gnd))))
; r8-1
 (defvc inf-vc-stsy-r8-1 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-lt (add opi0 nd) distj3) (inf-le ipj3 n)))
   (given inf-stsy-c4 (lam g16 g17 q1)))
; r8-2
 (defvc inf-vc-stsy-r8-2 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-lt (add opi0 nd) distj3) (inf-le bcj3 63)))
   (given inf-stsy-c4 (lam g16 g17 q3)))
; r8-3
 (defvc inf-vc-stsy-r8-3 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-lt (add opi0 nd) distj3) (inf-bits-inv carry ipj3 consj3 bcj3)))
   (given inf-stsy-c4 (lam g16 g17 q4)))
; r8-4
 (defvc inf-vc-stsy-r8-4 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-lt (add opi0 nd) distj3) (inf-le cons0 consj3)))
   (given inf-stsy-c4 (lam g16 g17 q5)))
; r8-5
 (defvc inf-vc-stsy-r8-5 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-lt (add opi0 nd) distj3) (inf-le opi0 cap)))
   (given inf-stsy-c4 (lam g16 g17 k7)))
; r8-6
 (defvc inf-vc-stsy-r8-6 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-lt (add opi0 nd) distj3) (inf-le op0 opi0)))
   (given inf-stsy-c4 (lam g16 g17 k8)))
; r9-1
 (defvc inf-vc-stsy-r9-1 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (paths nat lenj1 0) (inf-le ipj3 n)))
   (given inf-stsy-c4 (lam g16 g17 g18 q1)))
; r9-2
 (defvc inf-vc-stsy-r9-2 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (paths nat lenj1 0) (inf-le bcj3 63)))
   (given inf-stsy-c4 (lam g16 g17 g18 q3)))
; r9-3
 (defvc inf-vc-stsy-r9-3 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (paths nat lenj1 0) (inf-bits-inv carry ipj3 consj3 bcj3)))
   (given inf-stsy-c4 (lam g16 g17 g18 q4)))
; r9-4
 (defvc inf-vc-stsy-r9-4 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (paths nat lenj1 0) (inf-le cons0 consj3)))
   (given inf-stsy-c4 (lam g16 g17 g18 q5)))
; r9-5
 (defvc inf-vc-stsy-r9-5 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (paths nat lenj1 0) (inf-le opi0 cap)))
   (given inf-stsy-c4 (lam g16 g17 g18 k7)))
; r9-6
 (defvc inf-vc-stsy-r9-6 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (paths nat lenj1 0) (inf-le op0 opi0)))
   (given inf-stsy-c4 (lam g16 g17 g18 k8)))
; i16-1
 (defvc inf-vc-stsy-i16-1 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) (inf-le opi0 cap)))
   (given inf-stsy-c4 (lam g16 g17 g18 k7)))
; r10-1
 (defvc inf-vc-stsy-r10-1 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-lt (natminus cap opi0) lenj1) (inf-le ipj3 n)))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 q1)))
; r10-2
 (defvc inf-vc-stsy-r10-2 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-lt (natminus cap opi0) lenj1) (inf-le bcj3 63)))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 q3)))
; r10-3
 (defvc inf-vc-stsy-r10-3 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-lt (natminus cap opi0) lenj1) (inf-bits-inv carry ipj3 consj3 bcj3)))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 q4)))
; r10-4
 (defvc inf-vc-stsy-r10-4 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-lt (natminus cap opi0) lenj1) (inf-le cons0 consj3)))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 q5)))
; r10-5
 (defvc inf-vc-stsy-r10-5 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-lt (natminus cap opi0) lenj1) (inf-le opi0 cap)))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 k7)))
; r10-6
 (defvc inf-vc-stsy-r10-6 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-lt (natminus cap opi0) lenj1) (inf-le op0 opi0)))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 k8)))
; c1-1
 (defvc inf-vc-stsy-c1-1 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-le lenj1 (natminus cap opi0)) (inf-le 32 w)))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 gw)))
; c1-2
 (defvc inf-vc-stsy-c1-2 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-le lenj1 (natminus cap opi0)) (inf-lt distj3 (inf-pow w))))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 (inf-lelt distj3 (inf-pow 15) (inf-pow w) g16 ((inf-powlt 15 w (inf-lttrans 15 16 w (idpath true) (inf-letrans 16 32 w (idpath false) gw))))))))
; c1-3
 (defvc inf-vc-stsy-c1-3 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-le lenj1 (natminus cap opi0)) (inf-le distj3 (add opi0 nd))))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 g17)))
; c1-4
 (defvc inf-vc-stsy-c1-4 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-le lenj1 (natminus cap opi0)) (inf-le (add opi0 lenj1) cap)))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 ((inf-roomle opi0 cap lenj1 g19 k7)))))
; c1-5
 (defvc inf-vc-stsy-c1-5 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-le lenj1 (natminus cap opi0)) (inf-lt 0 out)))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 gz)))
; c1-6
 (defvc inf-vc-stsy-c1-6 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-le lenj1 (natminus cap opi0)) (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 go)))
; c1-7
 (defvc inf-vc-stsy-c1-7 (under inf-stsy-c4 (pi g16 (inf-le distj3 (inf-pow 15)) g17 (inf-le distj3 (add opi0 nd)) g18 (inf-lt 0 lenj1) g19 (inf-le lenj1 (natminus cap opi0)) (inf-lt (add cap 8) (inf-pow w))))
   (given inf-stsy-c4 (lam g16 g17 g18 g19 gcap)))
 (defcx inf-stsy-c5 inf-stsy-c4 (g16 (inf-le distj3 (inf-pow 15))) (g17 (inf-le distj3 (add opi0 nd))) (g18 (inf-lt 0 lenj1)) (g19 (inf-le lenj1 (natminus cap opi0))) )
; s4-1
 (defvc inf-vc-stsy-s4-1 (under inf-stsy-c5 (inf-lt (add opi0 lenj1) (inf-pow w)))
   (given inf-stsy-c5 (inf-lelt (add opi0 lenj1) cap (inf-pow w) ((inf-roomle opi0 cap lenj1 g19 k7)) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))
; w1b-8
 (defvc inf-vc-stsy-w1b-8 (under inf-stsy-c5 (pi staged11 nat (inf-le ipj3 n)))
   (given inf-stsy-c5 (lam staged11 q1)))
; w1b-9
 (defvc inf-vc-stsy-w1b-9 (under inf-stsy-c5 (pi staged11 nat (inf-le bcj3 63)))
   (given inf-stsy-c5 (lam staged11 q3)))
; w1b-10
 (defvc inf-vc-stsy-w1b-10 (under inf-stsy-c5 (pi staged11 nat (inf-bits-inv carry ipj3 consj3 bcj3)))
   (given inf-stsy-c5 (lam staged11 q4)))
; w1b-11
 (defvc inf-vc-stsy-w1b-11 (under inf-stsy-c5 (pi staged11 nat (inf-le cons0 consj3)))
   (given inf-stsy-c5 (lam staged11 q5)))
; w1b-12
 (defvc inf-vc-stsy-w1b-12 (under inf-stsy-c5 (pi staged11 nat (inf-le op0 (add opi0 lenj1))))
   (given inf-stsy-c5 (lam staged11 (inf-letrans op0 opi0 (add opi0 lenj1) ((inf-letrans op0 op opi0 o1 ((inf-letr o0 op opi0 eo k6)))) (inf-leaddr opi0 lenj1)))))
; w1b-13
 (defvc inf-vc-stsy-w1b-13 (under inf-stsy-c5 (pi staged11 nat (inf-le (add opi0 lenj1) cap)))
   (given inf-stsy-c5 (lam staged11 ((inf-roomle opi0 cap lenj1 g19 k7)))))
; w1b-14
 (defvc inf-vc-stsy-w1b-14 (under inf-stsy-c5 (pi staged11 nat (inf-lt (natminus cap (add opi0 lenj1)) (natminus cap op))))
   (given inf-stsy-c5 (lam staged11 (inf-subfrom op opi0 cap lenj1 ((inf-letr o0 op opi0 eo k6)) ((inf-lttrans opi0 (add opi0 lenj1) cap (inf-ltaddpos opi0 lenj1 g18) ((inf-roomle opi0 cap lenj1 g19 k7)))) g18))))
 (defcx inf-strest (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (gcf (inf-lt (add cap 266) (inf-pow w))) (gz (inf-lt 0 out)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (last0 nat) (rem0 nat) (hclen0 nat) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) (mode0 nat) (hlit0 nat) (hdist0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (b1 (inf-le prev0 15)) (b2 (pi j nat (inf-le (Lz0 j) 15))) (a2 (pi k nat (inf-le (Cl0 k) 15))) )
; t1-1
 (defvc inf-vc-strest-t1-1 (under inf-strest (pi g1 unit (inf-le 32 w)))
   (given inf-strest (lam g1 gw)))
; t1-2
 (defvc inf-vc-strest-t1-2 (under inf-strest (pi g1 unit (inf-lt (add n 8) (inf-pow w))))
   (given inf-strest (lam g1 gn)))
; t1-3
 (defvc inf-vc-strest-t1-3 (under inf-strest (pi g1 unit (inf-le ip0 n)))
   (given inf-strest (lam g1 gi)))
; t1-4
 (defvc inf-vc-strest-t1-4 (under inf-strest (pi g1 unit (inf-le bc0 63)))
   (given inf-strest (lam g1 gs)))
; t1-5
 (defvc inf-vc-strest-t1-5 (under inf-strest (pi g1 unit (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-strest (lam g1 ga)))
; t1s-1
 (defvc inf-vc-strest-t1s-1 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le ipt1 n)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 t1e1)))
; t1s-2
 (defvc inf-vc-strest-t1s-2 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le bct1 63)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 t1e3)))
; t1s-3
 (defvc inf-vc-strest-t1s-3 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 t1e4)))
; t1s-4
 (defvc inf-vc-strest-t1s-4 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le cons0 const1)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 t1e5)))
; t1s-5
 (defvc inf-vc-strest-t1s-5 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le op0 cap)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 gop)))
; t1s-6
 (defvc inf-vc-strest-t1s-6 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le op0 op0)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 (inf-refl op0))))
; t1s-7
 (defvc inf-vc-strest-t1s-7 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 c1)))
; t1s-8
 (defvc inf-vc-strest-t1s-8 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 c2)))
; t1s-9
 (defvc inf-vc-strest-t1s-9 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 c3)))
; t1s-10
 (defvc inf-vc-strest-t1s-10 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le lm0 288)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 c4)))
; t1s-11
 (defvc inf-vc-strest-t1s-11 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 c5)))
; t1s-12
 (defvc inf-vc-strest-t1s-12 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 c6)))
; t1s-13
 (defvc inf-vc-strest-t1s-13 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 c7)))
; t1s-14
 (defvc inf-vc-strest-t1s-14 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le dm0 32)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 c8)))
; t1s-15
 (defvc inf-vc-strest-t1s-15 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 d1)))
; t1s-16
 (defvc inf-vc-strest-t1s-16 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 d2)))
; t1s-17
 (defvc inf-vc-strest-t1s-17 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 d3)))
; t1s-18
 (defvc inf-vc-strest-t1s-18 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (inf-le prev0 15)))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 b1)))
; t1s-19
 (defvc inf-vc-strest-t1s-19 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 b2)))
; t1s-20
 (defvc inf-vc-strest-t1s-20 (under inf-strest (pi g1 unit ipt1 nat bct1 nat bbt1 nat const1 nat remt1 nat modet1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-strest (lam g1 ipt1 bct1 bbt1 const1 remt1 modet1 xt1 t1e1 t1e3 t1e4 t1e5 a2)))
 (defcx inf-strest-c12 inf-strest (g1 unit) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (remt1 nat) (modet1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons0 const1)) )
; j1j-1
 (defvc inf-vc-strest-j1j-1 (under inf-strest-c12 (inf-le ipt1 n))
   (given inf-strest-c12 t1e1))
; j1j-2
 (defvc inf-vc-strest-j1j-2 (under inf-strest-c12 (inf-le bct1 63))
   (given inf-strest-c12 t1e3))
; j1j-3
 (defvc inf-vc-strest-j1j-3 (under inf-strest-c12 (inf-bits-inv carry ipt1 const1 bct1))
   (given inf-strest-c12 t1e4))
; j1j-4
 (defvc inf-vc-strest-j1j-4 (under inf-strest-c12 (inf-le cons0 const1))
   (given inf-strest-c12 t1e5))
; j1j-5
 (defvc inf-vc-strest-j1j-5 (under inf-strest (pi g1 unit (inf-le ip0 n)))
   (given inf-strest (lam g1 gi)))
; j1j-6
 (defvc inf-vc-strest-j1j-6 (under inf-strest (pi g1 unit (inf-le bc0 63)))
   (given inf-strest (lam g1 gs)))
; j1j-7
 (defvc inf-vc-strest-j1j-7 (under inf-strest (pi g1 unit (inf-bits-inv carry ip0 cons0 bc0)))
   (given inf-strest (lam g1 ga)))
; j1j-8
 (defvc inf-vc-strest-j1j-8 (under inf-strest (pi g1 unit (inf-le cons0 cons0)))
   (given inf-strest (lam g1 (inf-refl cons0))))
 (defcx inf-strest-c1 inf-strest (ipj1 nat) (bcj1 nat) (bbj1 nat) (consj1 nat) (remj1 nat) (modej1 nat) (r1 (inf-le ipj1 n)) (r3 (inf-le bcj1 63)) (r4 (inf-bits-inv carry ipj1 consj1 bcj1)) (r5 (inf-le cons0 consj1)) )
; t2-1
 (defvc inf-vc-strest-t2-1 (under inf-strest-c1 (pi g2 unit (inf-le 32 w)))
   (given inf-strest-c1 (lam g2 gw)))
; t2-2
 (defvc inf-vc-strest-t2-2 (under inf-strest-c1 (pi g2 unit (inf-lt (add n 8) (inf-pow w))))
   (given inf-strest-c1 (lam g2 gn)))
; t2-3
 (defvc inf-vc-strest-t2-3 (under inf-strest-c1 (pi g2 unit (inf-le ipj1 n)))
   (given inf-strest-c1 (lam g2 r1)))
; t2-4
 (defvc inf-vc-strest-t2-4 (under inf-strest-c1 (pi g2 unit (inf-le bcj1 63)))
   (given inf-strest-c1 (lam g2 r3)))
; t2-5
 (defvc inf-vc-strest-t2-5 (under inf-strest-c1 (pi g2 unit (inf-bits-inv carry ipj1 consj1 bcj1)))
   (given inf-strest-c1 (lam g2 r4)))
; t2-6
 (defvc inf-vc-strest-t2-6 (under inf-strest-c1 (pi g2 unit (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-strest-c1 (lam g2 go)))
; t2-7
 (defvc inf-vc-strest-t2-7 (under inf-strest-c1 (pi g2 unit (inf-lt (add cap 8) (inf-pow w))))
   (given inf-strest-c1 (lam g2 gcap)))
; t2-8
 (defvc inf-vc-strest-t2-8 (under inf-strest-c1 (pi g2 unit (inf-le op0 cap)))
   (given inf-strest-c1 (lam g2 gop)))
; t2-9
 (defvc inf-vc-strest-t2-9 (under inf-strest-c1 (pi g2 unit (inf-lt (add cap nd) (inf-pow w))))
   (given inf-strest-c1 (lam g2 gnd)))
; t2-10
 (defvc inf-vc-strest-t2-10 (under inf-strest-c1 (pi g2 unit (inf-lt 0 out)))
   (given inf-strest-c1 (lam g2 gz)))
; t2s-1
 (defvc inf-vc-strest-t2s-1 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le ipt2 n)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 t2e1)))
; t2s-2
 (defvc inf-vc-strest-t2s-2 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le bct2 63)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 t2e3)))
; t2s-3
 (defvc inf-vc-strest-t2s-3 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 t2e4)))
; t2s-4
 (defvc inf-vc-strest-t2s-4 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le cons0 const2)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 (inf-letrans cons0 consj1 const2 r5 t2e5))))
; t2s-5
 (defvc inf-vc-strest-t2s-5 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le opt2 cap)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 t2e8)))
; t2s-6
 (defvc inf-vc-strest-t2s-6 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le op0 opt2)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 t2e9)))
; t2s-7
 (defvc inf-vc-strest-t2s-7 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 c1)))
; t2s-8
 (defvc inf-vc-strest-t2s-8 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 c2)))
; t2s-9
 (defvc inf-vc-strest-t2s-9 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 c3)))
; t2s-10
 (defvc inf-vc-strest-t2s-10 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le lm0 288)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 c4)))
; t2s-11
 (defvc inf-vc-strest-t2s-11 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 c5)))
; t2s-12
 (defvc inf-vc-strest-t2s-12 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 c6)))
; t2s-13
 (defvc inf-vc-strest-t2s-13 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 c7)))
; t2s-14
 (defvc inf-vc-strest-t2s-14 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le dm0 32)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 c8)))
; t2s-15
 (defvc inf-vc-strest-t2s-15 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 d1)))
; t2s-16
 (defvc inf-vc-strest-t2s-16 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 d2)))
; t2s-17
 (defvc inf-vc-strest-t2s-17 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 d3)))
; t2s-18
 (defvc inf-vc-strest-t2s-18 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (inf-le prev0 15)))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 b1)))
; t2s-19
 (defvc inf-vc-strest-t2s-19 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 b2)))
; t2s-20
 (defvc inf-vc-strest-t2s-20 (under inf-strest-c1 (pi g2 unit ipt2 nat bct2 nat bbt2 nat const2 nat opt2 nat remt2 nat modet2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le consj1 const2) t2e8 (inf-le opt2 cap) t2e9 (inf-le op0 opt2) (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-strest-c1 (lam g2 ipt2 bct2 bbt2 const2 opt2 remt2 modet2 xt2 t2e1 t2e3 t2e4 t2e5 t2e8 t2e9 a2)))
 (defcx inf-strest-c11 inf-strest-c1 (g2 unit) (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (opt2 nat) (remt2 nat) (modet2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le consj1 const2)) (t2e8 (inf-le opt2 cap)) (t2e9 (inf-le op0 opt2)) )
; j2j-1
 (defvc inf-vc-strest-j2j-1 (under inf-strest-c11 (inf-le ipt2 n))
   (given inf-strest-c11 t2e1))
; j2j-2
 (defvc inf-vc-strest-j2j-2 (under inf-strest-c11 (inf-le bct2 63))
   (given inf-strest-c11 t2e3))
; j2j-3
 (defvc inf-vc-strest-j2j-3 (under inf-strest-c11 (inf-bits-inv carry ipt2 const2 bct2))
   (given inf-strest-c11 t2e4))
; j2j-4
 (defvc inf-vc-strest-j2j-4 (under inf-strest-c11 (inf-le cons0 const2))
   (given inf-strest-c11 (inf-letrans cons0 consj1 const2 r5 t2e5)))
; j2j-5
 (defvc inf-vc-strest-j2j-5 (under inf-strest-c11 (inf-le op0 opt2))
   (given inf-strest-c11 t2e9))
; j2j-6
 (defvc inf-vc-strest-j2j-6 (under inf-strest-c11 (inf-le opt2 cap))
   (given inf-strest-c11 t2e8))
; j2j-7
 (defvc inf-vc-strest-j2j-7 (under inf-strest-c1 (pi g2 unit (inf-le ipj1 n)))
   (given inf-strest-c1 (lam g2 r1)))
; j2j-8
 (defvc inf-vc-strest-j2j-8 (under inf-strest-c1 (pi g2 unit (inf-le bcj1 63)))
   (given inf-strest-c1 (lam g2 r3)))
; j2j-9
 (defvc inf-vc-strest-j2j-9 (under inf-strest-c1 (pi g2 unit (inf-bits-inv carry ipj1 consj1 bcj1)))
   (given inf-strest-c1 (lam g2 r4)))
; j2j-10
 (defvc inf-vc-strest-j2j-10 (under inf-strest-c1 (pi g2 unit (inf-le cons0 consj1)))
   (given inf-strest-c1 (lam g2 r5)))
; j2j-11
 (defvc inf-vc-strest-j2j-11 (under inf-strest-c1 (pi g2 unit (inf-le op0 op0)))
   (given inf-strest-c1 (lam g2 (inf-refl op0))))
; j2j-12
 (defvc inf-vc-strest-j2j-12 (under inf-strest-c1 (pi g2 unit (inf-le op0 cap)))
   (given inf-strest-c1 (lam g2 gop)))
 (defcx inf-strest-c2 inf-strest-c1 (ipj2 nat) (bcj2 nat) (bbj2 nat) (consj2 nat) (opj2 nat) (remj2 nat) (modej2 nat) (r1 (inf-le ipj2 n)) (r3 (inf-le bcj2 63)) (r4 (inf-bits-inv carry ipj2 consj2 bcj2)) (r5 (inf-le cons0 consj2)) (o1 (inf-le op0 opj2)) (o2 (inf-le opj2 cap)) )
; t3-1
 (defvc inf-vc-strest-t3-1 (under inf-strest-c2 (pi g3 unit (inf-le 32 w)))
   (given inf-strest-c2 (lam g3 gw)))
; t3-2
 (defvc inf-vc-strest-t3-2 (under inf-strest-c2 (pi g3 unit (inf-lt (add n 8) (inf-pow w))))
   (given inf-strest-c2 (lam g3 gn)))
; t3-3
 (defvc inf-vc-strest-t3-3 (under inf-strest-c2 (pi g3 unit (inf-le ipj2 n)))
   (given inf-strest-c2 (lam g3 r1)))
; t3-4
 (defvc inf-vc-strest-t3-4 (under inf-strest-c2 (pi g3 unit (inf-le bcj2 63)))
   (given inf-strest-c2 (lam g3 r3)))
; t3-5
 (defvc inf-vc-strest-t3-5 (under inf-strest-c2 (pi g3 unit (inf-bits-inv carry ipj2 consj2 bcj2)))
   (given inf-strest-c2 (lam g3 r4)))
; t3-6
 (defvc inf-vc-strest-t3-6 (under inf-strest-c2 (pi g3 unit (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-strest-c2 (lam g3 a2)))
; t3s-1
 (defvc inf-vc-strest-t3s-1 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le ipt3 n)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 t3e1)))
; t3s-2
 (defvc inf-vc-strest-t3s-2 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le bct3 63)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 t3e3)))
; t3s-3
 (defvc inf-vc-strest-t3s-3 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-bits-inv carry ipt3 const3 bct3)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 t3e4)))
; t3s-4
 (defvc inf-vc-strest-t3s-4 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le cons0 const3)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 (inf-letrans cons0 consj2 const3 r5 t3e5))))
; t3s-5
 (defvc inf-vc-strest-t3s-5 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le opj2 cap)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 o2)))
; t3s-6
 (defvc inf-vc-strest-t3s-6 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le op0 opj2)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 o1)))
; t3s-7
 (defvc inf-vc-strest-t3s-7 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 c1)))
; t3s-8
 (defvc inf-vc-strest-t3s-8 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 c2)))
; t3s-9
 (defvc inf-vc-strest-t3s-9 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 c3)))
; t3s-10
 (defvc inf-vc-strest-t3s-10 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le lm0 288)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 c4)))
; t3s-11
 (defvc inf-vc-strest-t3s-11 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 c5)))
; t3s-12
 (defvc inf-vc-strest-t3s-12 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 c6)))
; t3s-13
 (defvc inf-vc-strest-t3s-13 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 c7)))
; t3s-14
 (defvc inf-vc-strest-t3s-14 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le dm0 32)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 c8)))
; t3s-15
 (defvc inf-vc-strest-t3s-15 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 d1)))
; t3s-16
 (defvc inf-vc-strest-t3s-16 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 d2)))
; t3s-17
 (defvc inf-vc-strest-t3s-17 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 d3)))
; t3s-18
 (defvc inf-vc-strest-t3s-18 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le prev0 15)))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 b1)))
; t3s-19
 (defvc inf-vc-strest-t3s-19 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 b2)))
; t3s-20
 (defvc inf-vc-strest-t3s-20 (under inf-strest-c2 (pi g3 unit ipt3 nat bct3 nat bbt3 nat const3 nat Clt3 (pi j nat nat) hlitt3 nat hdistt3 nat hclent3 nat it3 nat modet3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le consj2 const3) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-le (Clt3 k) 15))))
   (given inf-strest-c2 (lam g3 ipt3 bct3 bbt3 const3 Clt3 hlitt3 hdistt3 hclent3 it3 modet3 xt3 t3e1 t3e3 t3e4 t3e5 t3a2 t3a2)))
 (defcx inf-strest-c10 inf-strest-c2 (g3 unit) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (Clt3 (pi j nat nat)) (hlitt3 nat) (hdistt3 nat) (hclent3 nat) (it3 nat) (modet3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le consj2 const3)) (t3a2 (pi k nat (inf-le (Clt3 k) 15))) )
; j3j-1
 (defvc inf-vc-strest-j3j-1 (under inf-strest-c10 (inf-le ipt3 n))
   (given inf-strest-c10 t3e1))
; j3j-2
 (defvc inf-vc-strest-j3j-2 (under inf-strest-c10 (inf-le bct3 63))
   (given inf-strest-c10 t3e3))
; j3j-3
 (defvc inf-vc-strest-j3j-3 (under inf-strest-c10 (inf-bits-inv carry ipt3 const3 bct3))
   (given inf-strest-c10 t3e4))
; j3j-4
 (defvc inf-vc-strest-j3j-4 (under inf-strest-c10 (inf-le cons0 const3))
   (given inf-strest-c10 (inf-letrans cons0 consj2 const3 r5 t3e5)))
; j3j-5
 (defvc inf-vc-strest-j3j-5 (under inf-strest-c10 (pi k nat (inf-le (Clt3 k) 15)))
   (given inf-strest-c10 t3a2))
; j3j-6
 (defvc inf-vc-strest-j3j-6 (under inf-strest-c2 (pi g3 unit (inf-le ipj2 n)))
   (given inf-strest-c2 (lam g3 r1)))
; j3j-7
 (defvc inf-vc-strest-j3j-7 (under inf-strest-c2 (pi g3 unit (inf-le bcj2 63)))
   (given inf-strest-c2 (lam g3 r3)))
; j3j-8
 (defvc inf-vc-strest-j3j-8 (under inf-strest-c2 (pi g3 unit (inf-bits-inv carry ipj2 consj2 bcj2)))
   (given inf-strest-c2 (lam g3 r4)))
; j3j-9
 (defvc inf-vc-strest-j3j-9 (under inf-strest-c2 (pi g3 unit (inf-le cons0 consj2)))
   (given inf-strest-c2 (lam g3 r5)))
; j3j-10
 (defvc inf-vc-strest-j3j-10 (under inf-strest-c2 (pi g3 unit (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-strest-c2 (lam g3 a2)))
 (defcx inf-strest-c3 inf-strest-c2 (ipj3 nat) (bcj3 nat) (bbj3 nat) (consj3 nat) (Clj3 (pi j nat nat)) (hlitj3 nat) (hdistj3 nat) (hclenj3 nat) (ij3 nat) (modej3 nat) (r1 (inf-le ipj3 n)) (r3 (inf-le bcj3 63)) (r4 (inf-bits-inv carry ipj3 consj3 bcj3)) (r5 (inf-le cons0 consj3)) (a2 (pi k nat (inf-le (Clj3 k) 15))) )
; t4-1
 (defvc inf-vc-strest-t4-1 (under inf-strest-c3 (pi g4 unit (inf-le 32 w)))
   (given inf-strest-c3 (lam g4 gw)))
; t4-2
 (defvc inf-vc-strest-t4-2 (under inf-strest-c3 (pi g4 unit (inf-lt (add n 8) (inf-pow w))))
   (given inf-strest-c3 (lam g4 gn)))
; t4-3
 (defvc inf-vc-strest-t4-3 (under inf-strest-c3 (pi g4 unit (inf-le ipj3 n)))
   (given inf-strest-c3 (lam g4 r1)))
; t4-4
 (defvc inf-vc-strest-t4-4 (under inf-strest-c3 (pi g4 unit (inf-le bcj3 63)))
   (given inf-strest-c3 (lam g4 r3)))
; t4-5
 (defvc inf-vc-strest-t4-5 (under inf-strest-c3 (pi g4 unit (inf-bits-inv carry ipj3 consj3 bcj3)))
   (given inf-strest-c3 (lam g4 r4)))
; t4-6
 (defvc inf-vc-strest-t4-6 (under inf-strest-c3 (pi g4 unit (inf-le h 16)))
   (given inf-strest-c3 (lam g4 gh)))
; t4-7
 (defvc inf-vc-strest-t4-7 (under inf-strest-c3 (pi g4 unit (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-strest-c3 (lam g4 gq)))
; t4-8
 (defvc inf-vc-strest-t4-8 (under inf-strest-c3 (pi g4 unit (inf-lt 320 q)))
   (given inf-strest-c3 (lam g4 gq2)))
; t4-9
 (defvc inf-vc-strest-t4-9 (under inf-strest-c3 (pi g4 unit (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-strest-c3 (lam g4 gk)))
; t4-10
 (defvc inf-vc-strest-t4-10 (under inf-strest-c3 (pi g4 unit (inf-le LROOT 15)))
   (given inf-strest-c3 (lam g4 gl)))
; t4-11
 (defvc inf-vc-strest-t4-11 (under inf-strest-c3 (pi g4 unit (inf-le DROOT 15)))
   (given inf-strest-c3 (lam g4 gd)))
; t4-12
 (defvc inf-vc-strest-t4-12 (under inf-strest-c3 (pi g4 unit (inf-le CROOT 15)))
   (given inf-strest-c3 (lam g4 gc)))
; t4-13
 (defvc inf-vc-strest-t4-13 (under inf-strest-c3 (pi g4 unit (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))))
   (given inf-strest-c3 (lam g4 hord)))
; t4-14
 (defvc inf-vc-strest-t4-14 (under inf-strest-c3 (pi g4 unit (pi k nat (inf-le (Clj3 k) 15))))
   (given inf-strest-c3 (lam g4 a2)))
; t4-15
 (defvc inf-vc-strest-t4-15 (under inf-strest-c3 (pi g4 unit (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-strest-c3 (lam g4 b2)))
; t4-16
 (defvc inf-vc-strest-t4-16 (under inf-strest-c3 (pi g4 unit (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 d1)))
; t4-17
 (defvc inf-vc-strest-t4-17 (under inf-strest-c3 (pi g4 unit (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 d2)))
; t4-18
 (defvc inf-vc-strest-t4-18 (under inf-strest-c3 (pi g4 unit (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-strest-c3 (lam g4 d3)))
; t4-19
 (defvc inf-vc-strest-t4-19 (under inf-strest-c3 (pi g4 unit (inf-le prev0 15)))
   (given inf-strest-c3 (lam g4 b1)))
; t4s-1
 (defvc inf-vc-strest-t4s-1 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le ipt4 n)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 t4e1)))
; t4s-2
 (defvc inf-vc-strest-t4s-2 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le bct4 63)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 t4e3)))
; t4s-3
 (defvc inf-vc-strest-t4s-3 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-bits-inv carry ipt4 const4 bct4)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 t4e4)))
; t4s-4
 (defvc inf-vc-strest-t4s-4 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le cons0 const4)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 (inf-letrans cons0 consj3 const4 r5 t4e5))))
; t4s-5
 (defvc inf-vc-strest-t4s-5 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le opj2 cap)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 o2)))
; t4s-6
 (defvc inf-vc-strest-t4s-6 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le op0 opj2)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 o1)))
; t4s-7
 (defvc inf-vc-strest-t4s-7 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 c1)))
; t4s-8
 (defvc inf-vc-strest-t4s-8 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 c2)))
; t4s-9
 (defvc inf-vc-strest-t4s-9 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 c3)))
; t4s-10
 (defvc inf-vc-strest-t4s-10 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le lm0 288)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 c4)))
; t4s-11
 (defvc inf-vc-strest-t4s-11 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 c5)))
; t4s-12
 (defvc inf-vc-strest-t4s-12 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 c6)))
; t4s-13
 (defvc inf-vc-strest-t4s-13 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 c7)))
; t4s-14
 (defvc inf-vc-strest-t4s-14 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le dm0 32)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 c8)))
; t4s-15
 (defvc inf-vc-strest-t4s-15 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (pi k nat (inf-lt (Cct4 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 t4d1)))
; t4s-16
 (defvc inf-vc-strest-t4s-16 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (pi k nat (inf-lt (Cst4 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 t4d2)))
; t4s-17
 (defvc inf-vc-strest-t4s-17 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le (inf-sum Cct4 15 1) 19)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 t4d3)))
; t4s-18
 (defvc inf-vc-strest-t4s-18 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (inf-le prevt4 15)))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 t4b1)))
; t4s-19
 (defvc inf-vc-strest-t4s-19 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (pi j nat (inf-le (Lzt4 j) 15))))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 t4b2)))
; t4s-20
 (defvc inf-vc-strest-t4s-20 (under inf-strest-c3 (pi g4 unit ipt4 nat bct4 nat bbt4 nat const4 nat Clt4 (pi j nat nat) Lzt4 (pi j nat nat) Cst4 (pi j nat nat) Ctt4 (pi j nat nat) Cct4 (pi j nat nat) it4 nat prevt4 nat staget4 nat modet4 nat xt4 nat t4e1 (inf-le ipt4 n) t4e3 (inf-le bct4 63) t4e4 (inf-bits-inv carry ipt4 const4 bct4) t4e5 (inf-le consj3 const4) t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h))) t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h))) t4d3 (inf-le (inf-sum Cct4 15 1) 19) t4b1 (inf-le prevt4 15) t4b2 (pi j nat (inf-le (Lzt4 j) 15)) t4a2 (pi k nat (inf-le (Clt4 k) 15)) (pi k nat (inf-le (Clt4 k) 15))))
   (given inf-strest-c3 (lam g4 ipt4 bct4 bbt4 const4 Clt4 Lzt4 Cst4 Ctt4 Cct4 it4 prevt4 staget4 modet4 xt4 t4e1 t4e3 t4e4 t4e5 t4d1 t4d2 t4d3 t4b1 t4b2 t4a2 t4a2)))
 (defcx inf-strest-c9 inf-strest-c3 (g4 unit) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (Clt4 (pi j nat nat)) (Lzt4 (pi j nat nat)) (Cst4 (pi j nat nat)) (Ctt4 (pi j nat nat)) (Cct4 (pi j nat nat)) (it4 nat) (prevt4 nat) (staget4 nat) (modet4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e3 (inf-le bct4 63)) (t4e4 (inf-bits-inv carry ipt4 const4 bct4)) (t4e5 (inf-le consj3 const4)) (t4d1 (pi k nat (inf-lt (Cct4 k) (inf-pow h)))) (t4d2 (pi k nat (inf-lt (Cst4 k) (inf-pow h)))) (t4d3 (inf-le (inf-sum Cct4 15 1) 19)) (t4b1 (inf-le prevt4 15)) (t4b2 (pi j nat (inf-le (Lzt4 j) 15))) (t4a2 (pi k nat (inf-le (Clt4 k) 15))) )
; j4j-1
 (defvc inf-vc-strest-j4j-1 (under inf-strest-c9 (inf-le ipt4 n))
   (given inf-strest-c9 t4e1))
; j4j-2
 (defvc inf-vc-strest-j4j-2 (under inf-strest-c9 (inf-le bct4 63))
   (given inf-strest-c9 t4e3))
; j4j-3
 (defvc inf-vc-strest-j4j-3 (under inf-strest-c9 (inf-bits-inv carry ipt4 const4 bct4))
   (given inf-strest-c9 t4e4))
; j4j-4
 (defvc inf-vc-strest-j4j-4 (under inf-strest-c9 (inf-le cons0 const4))
   (given inf-strest-c9 (inf-letrans cons0 consj3 const4 r5 t4e5)))
; j4j-5
 (defvc inf-vc-strest-j4j-5 (under inf-strest-c9 (pi k nat (inf-lt (Cct4 k) (inf-pow h))))
   (given inf-strest-c9 t4d1))
; j4j-6
 (defvc inf-vc-strest-j4j-6 (under inf-strest-c9 (pi k nat (inf-lt (Cst4 k) (inf-pow h))))
   (given inf-strest-c9 t4d2))
; j4j-7
 (defvc inf-vc-strest-j4j-7 (under inf-strest-c9 (inf-le (inf-sum Cct4 15 1) 19))
   (given inf-strest-c9 t4d3))
; j4j-8
 (defvc inf-vc-strest-j4j-8 (under inf-strest-c9 (inf-le prevt4 15))
   (given inf-strest-c9 t4b1))
; j4j-9
 (defvc inf-vc-strest-j4j-9 (under inf-strest-c9 (pi j nat (inf-le (Lzt4 j) 15)))
   (given inf-strest-c9 t4b2))
; j4j-10
 (defvc inf-vc-strest-j4j-10 (under inf-strest-c9 (pi k nat (inf-le (Clt4 k) 15)))
   (given inf-strest-c9 t4a2))
; j4j-11
 (defvc inf-vc-strest-j4j-11 (under inf-strest-c3 (pi g4 unit (inf-le ipj3 n)))
   (given inf-strest-c3 (lam g4 r1)))
; j4j-12
 (defvc inf-vc-strest-j4j-12 (under inf-strest-c3 (pi g4 unit (inf-le bcj3 63)))
   (given inf-strest-c3 (lam g4 r3)))
; j4j-13
 (defvc inf-vc-strest-j4j-13 (under inf-strest-c3 (pi g4 unit (inf-bits-inv carry ipj3 consj3 bcj3)))
   (given inf-strest-c3 (lam g4 r4)))
; j4j-14
 (defvc inf-vc-strest-j4j-14 (under inf-strest-c3 (pi g4 unit (inf-le cons0 consj3)))
   (given inf-strest-c3 (lam g4 r5)))
; j4j-15
 (defvc inf-vc-strest-j4j-15 (under inf-strest-c3 (pi g4 unit (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 d1)))
; j4j-16
 (defvc inf-vc-strest-j4j-16 (under inf-strest-c3 (pi g4 unit (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-strest-c3 (lam g4 d2)))
; j4j-17
 (defvc inf-vc-strest-j4j-17 (under inf-strest-c3 (pi g4 unit (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-strest-c3 (lam g4 d3)))
; j4j-18
 (defvc inf-vc-strest-j4j-18 (under inf-strest-c3 (pi g4 unit (inf-le prev0 15)))
   (given inf-strest-c3 (lam g4 b1)))
; j4j-19
 (defvc inf-vc-strest-j4j-19 (under inf-strest-c3 (pi g4 unit (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-strest-c3 (lam g4 b2)))
; j4j-20
 (defvc inf-vc-strest-j4j-20 (under inf-strest-c3 (pi g4 unit (pi k nat (inf-le (Clj3 k) 15))))
   (given inf-strest-c3 (lam g4 a2)))
 (defcx inf-strest-c4 inf-strest-c3 (ipj4 nat) (bcj4 nat) (bbj4 nat) (consj4 nat) (Clj4 (pi j nat nat)) (Lzj4 (pi j nat nat)) (Csj4 (pi j nat nat)) (Ctj4 (pi j nat nat)) (Ccj4 (pi j nat nat)) (ij4 nat) (prevj4 nat) (stagej4 nat) (modej4 nat) (r1 (inf-le ipj4 n)) (r3 (inf-le bcj4 63)) (r4 (inf-bits-inv carry ipj4 consj4 bcj4)) (r5 (inf-le cons0 consj4)) (d1 (pi k nat (inf-lt (Ccj4 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Csj4 k) (inf-pow h)))) (d3 (inf-le (inf-sum Ccj4 15 1) 19)) (b1 (inf-le prevj4 15)) (b2 (pi j nat (inf-le (Lzj4 j) 15))) (a2 (pi k nat (inf-le (Clj4 k) 15))) )
; t5-1
 (defvc inf-vc-strest-t5-1 (under inf-strest-c4 (pi g5 unit (inf-le 32 w)))
   (given inf-strest-c4 (lam g5 gw)))
; t5-2
 (defvc inf-vc-strest-t5-2 (under inf-strest-c4 (pi g5 unit (inf-lt (add n 8) (inf-pow w))))
   (given inf-strest-c4 (lam g5 gn)))
; t5-3
 (defvc inf-vc-strest-t5-3 (under inf-strest-c4 (pi g5 unit (inf-le ipj4 n)))
   (given inf-strest-c4 (lam g5 r1)))
; t5-4
 (defvc inf-vc-strest-t5-4 (under inf-strest-c4 (pi g5 unit (inf-le bcj4 63)))
   (given inf-strest-c4 (lam g5 r3)))
; t5-5
 (defvc inf-vc-strest-t5-5 (under inf-strest-c4 (pi g5 unit (inf-bits-inv carry ipj4 consj4 bcj4)))
   (given inf-strest-c4 (lam g5 r4)))
; t5-6
 (defvc inf-vc-strest-t5-6 (under inf-strest-c4 (pi g5 unit (inf-le h 16)))
   (given inf-strest-c4 (lam g5 gh)))
; t5-7
 (defvc inf-vc-strest-t5-7 (under inf-strest-c4 (pi g5 unit (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-strest-c4 (lam g5 gq)))
; t5-8
 (defvc inf-vc-strest-t5-8 (under inf-strest-c4 (pi g5 unit (inf-lt 320 q)))
   (given inf-strest-c4 (lam g5 gq2)))
; t5-9
 (defvc inf-vc-strest-t5-9 (under inf-strest-c4 (pi g5 unit (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-strest-c4 (lam g5 gk)))
; t5-10
 (defvc inf-vc-strest-t5-10 (under inf-strest-c4 (pi g5 unit (inf-le LROOT 15)))
   (given inf-strest-c4 (lam g5 gl)))
; t5-11
 (defvc inf-vc-strest-t5-11 (under inf-strest-c4 (pi g5 unit (inf-le DROOT 15)))
   (given inf-strest-c4 (lam g5 gd)))
; t5-12
 (defvc inf-vc-strest-t5-12 (under inf-strest-c4 (pi g5 unit (inf-le CROOT 15)))
   (given inf-strest-c4 (lam g5 gc)))
; t5-13
 (defvc inf-vc-strest-t5-13 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Ccj4 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 d1)))
; t5-14
 (defvc inf-vc-strest-t5-14 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Csj4 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 d2)))
; t5-15
 (defvc inf-vc-strest-t5-15 (under inf-strest-c4 (pi g5 unit (inf-le (inf-sum Ccj4 15 1) 19)))
   (given inf-strest-c4 (lam g5 d3)))
; t5-16
 (defvc inf-vc-strest-t5-16 (under inf-strest-c4 (pi g5 unit (pi j nat (inf-le (Lzj4 j) 15))))
   (given inf-strest-c4 (lam g5 b2)))
; t5-17
 (defvc inf-vc-strest-t5-17 (under inf-strest-c4 (pi g5 unit (inf-le prevj4 15)))
   (given inf-strest-c4 (lam g5 b1)))
; t5-18
 (defvc inf-vc-strest-t5-18 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 c1)))
; t5-19
 (defvc inf-vc-strest-t5-19 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 c2)))
; t5-20
 (defvc inf-vc-strest-t5-20 (under inf-strest-c4 (pi g5 unit (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-strest-c4 (lam g5 c3)))
; t5-21
 (defvc inf-vc-strest-t5-21 (under inf-strest-c4 (pi g5 unit (inf-le lm0 288)))
   (given inf-strest-c4 (lam g5 c4)))
; t5-22
 (defvc inf-vc-strest-t5-22 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 c5)))
; t5-23
 (defvc inf-vc-strest-t5-23 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 c6)))
; t5-24
 (defvc inf-vc-strest-t5-24 (under inf-strest-c4 (pi g5 unit (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-strest-c4 (lam g5 c7)))
; t5-25
 (defvc inf-vc-strest-t5-25 (under inf-strest-c4 (pi g5 unit (inf-le dm0 32)))
   (given inf-strest-c4 (lam g5 c8)))
; t5s-1
 (defvc inf-vc-strest-t5s-1 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le ipt5 n)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5e1)))
; t5s-2
 (defvc inf-vc-strest-t5s-2 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le bct5 63)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5e3)))
; t5s-3
 (defvc inf-vc-strest-t5s-3 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-bits-inv carry ipt5 const5 bct5)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5e4)))
; t5s-4
 (defvc inf-vc-strest-t5s-4 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le cons0 const5)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 (inf-letrans cons0 consj4 const5 r5 t5e5))))
; t5s-5
 (defvc inf-vc-strest-t5s-5 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le opj2 cap)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 o2)))
; t5s-6
 (defvc inf-vc-strest-t5s-6 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le op0 opj2)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 o1)))
; t5s-7
 (defvc inf-vc-strest-t5s-7 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (pi k nat (inf-lt (Lct5 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5c1)))
; t5s-8
 (defvc inf-vc-strest-t5s-8 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (pi k nat (inf-lt (Lst5 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5c2)))
; t5s-9
 (defvc inf-vc-strest-t5s-9 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le (inf-sum Lct5 15 1) lmt5)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5c3)))
; t5s-10
 (defvc inf-vc-strest-t5s-10 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le lmt5 288)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5c4)))
; t5s-11
 (defvc inf-vc-strest-t5s-11 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (pi k nat (inf-lt (Dct5 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5c5)))
; t5s-12
 (defvc inf-vc-strest-t5s-12 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (pi k nat (inf-lt (Dst5 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5c6)))
; t5s-13
 (defvc inf-vc-strest-t5s-13 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le (inf-sum Dct5 15 1) dmt5)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5c7)))
; t5s-14
 (defvc inf-vc-strest-t5s-14 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le dmt5 32)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5c8)))
; t5s-15
 (defvc inf-vc-strest-t5s-15 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (pi k nat (inf-lt (Ccj4 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 d1)))
; t5s-16
 (defvc inf-vc-strest-t5s-16 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (pi k nat (inf-lt (Csj4 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 d2)))
; t5s-17
 (defvc inf-vc-strest-t5s-17 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le (inf-sum Ccj4 15 1) 19)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 d3)))
; t5s-18
 (defvc inf-vc-strest-t5s-18 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (inf-le prevt5 15)))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5b1)))
; t5s-19
 (defvc inf-vc-strest-t5s-19 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (pi j nat (inf-le (Lzt5 j) 15))))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 t5b2)))
; t5s-20
 (defvc inf-vc-strest-t5s-20 (under inf-strest-c4 (pi g5 unit ipt5 nat bct5 nat bbt5 nat const5 nat Lct5 (pi j nat nat) Lst5 (pi j nat nat) Ltt5 (pi j nat nat) Dct5 (pi j nat nat) Dst5 (pi j nat nat) Dtt5 (pi j nat nat) lmt5 nat dmt5 nat Lzt5 (pi j nat nat) it5 nat prevt5 nat staget5 nat syt5 nat modet5 nat xt5 nat t5e1 (inf-le ipt5 n) t5e3 (inf-le bct5 63) t5e4 (inf-bits-inv carry ipt5 const5 bct5) t5e5 (inf-le consj4 const5) t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h))) t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h))) t5c3 (inf-le (inf-sum Lct5 15 1) lmt5) t5c4 (inf-le lmt5 288) t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h))) t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h))) t5c7 (inf-le (inf-sum Dct5 15 1) dmt5) t5c8 (inf-le dmt5 32) t5b1 (inf-le prevt5 15) t5b2 (pi j nat (inf-le (Lzt5 j) 15)) (pi k nat (inf-le (Clj4 k) 15))))
   (given inf-strest-c4 (lam g5 ipt5 bct5 bbt5 const5 Lct5 Lst5 Ltt5 Dct5 Dst5 Dtt5 lmt5 dmt5 Lzt5 it5 prevt5 staget5 syt5 modet5 xt5 t5e1 t5e3 t5e4 t5e5 t5c1 t5c2 t5c3 t5c4 t5c5 t5c6 t5c7 t5c8 t5b1 t5b2 a2)))
 (defcx inf-strest-c8 inf-strest-c4 (g5 unit) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (Lct5 (pi j nat nat)) (Lst5 (pi j nat nat)) (Ltt5 (pi j nat nat)) (Dct5 (pi j nat nat)) (Dst5 (pi j nat nat)) (Dtt5 (pi j nat nat)) (lmt5 nat) (dmt5 nat) (Lzt5 (pi j nat nat)) (it5 nat) (prevt5 nat) (staget5 nat) (syt5 nat) (modet5 nat) (xt5 nat) (t5e1 (inf-le ipt5 n)) (t5e3 (inf-le bct5 63)) (t5e4 (inf-bits-inv carry ipt5 const5 bct5)) (t5e5 (inf-le consj4 const5)) (t5c1 (pi k nat (inf-lt (Lct5 k) (inf-pow h)))) (t5c2 (pi k nat (inf-lt (Lst5 k) (inf-pow h)))) (t5c3 (inf-le (inf-sum Lct5 15 1) lmt5)) (t5c4 (inf-le lmt5 288)) (t5c5 (pi k nat (inf-lt (Dct5 k) (inf-pow h)))) (t5c6 (pi k nat (inf-lt (Dst5 k) (inf-pow h)))) (t5c7 (inf-le (inf-sum Dct5 15 1) dmt5)) (t5c8 (inf-le dmt5 32)) (t5b1 (inf-le prevt5 15)) (t5b2 (pi j nat (inf-le (Lzt5 j) 15))) )
; j5j-1
 (defvc inf-vc-strest-j5j-1 (under inf-strest-c8 (inf-le ipt5 n))
   (given inf-strest-c8 t5e1))
; j5j-2
 (defvc inf-vc-strest-j5j-2 (under inf-strest-c8 (inf-le bct5 63))
   (given inf-strest-c8 t5e3))
; j5j-3
 (defvc inf-vc-strest-j5j-3 (under inf-strest-c8 (inf-bits-inv carry ipt5 const5 bct5))
   (given inf-strest-c8 t5e4))
; j5j-4
 (defvc inf-vc-strest-j5j-4 (under inf-strest-c8 (inf-le cons0 const5))
   (given inf-strest-c8 (inf-letrans cons0 consj4 const5 r5 t5e5)))
; j5j-5
 (defvc inf-vc-strest-j5j-5 (under inf-strest-c8 (pi k nat (inf-lt (Lct5 k) (inf-pow h))))
   (given inf-strest-c8 t5c1))
; j5j-6
 (defvc inf-vc-strest-j5j-6 (under inf-strest-c8 (pi k nat (inf-lt (Lst5 k) (inf-pow h))))
   (given inf-strest-c8 t5c2))
; j5j-7
 (defvc inf-vc-strest-j5j-7 (under inf-strest-c8 (inf-le (inf-sum Lct5 15 1) lmt5))
   (given inf-strest-c8 t5c3))
; j5j-8
 (defvc inf-vc-strest-j5j-8 (under inf-strest-c8 (inf-le lmt5 288))
   (given inf-strest-c8 t5c4))
; j5j-9
 (defvc inf-vc-strest-j5j-9 (under inf-strest-c8 (pi k nat (inf-lt (Dct5 k) (inf-pow h))))
   (given inf-strest-c8 t5c5))
; j5j-10
 (defvc inf-vc-strest-j5j-10 (under inf-strest-c8 (pi k nat (inf-lt (Dst5 k) (inf-pow h))))
   (given inf-strest-c8 t5c6))
; j5j-11
 (defvc inf-vc-strest-j5j-11 (under inf-strest-c8 (inf-le (inf-sum Dct5 15 1) dmt5))
   (given inf-strest-c8 t5c7))
; j5j-12
 (defvc inf-vc-strest-j5j-12 (under inf-strest-c8 (inf-le dmt5 32))
   (given inf-strest-c8 t5c8))
; j5j-13
 (defvc inf-vc-strest-j5j-13 (under inf-strest-c8 (inf-le prevt5 15))
   (given inf-strest-c8 t5b1))
; j5j-14
 (defvc inf-vc-strest-j5j-14 (under inf-strest-c8 (pi j nat (inf-le (Lzt5 j) 15)))
   (given inf-strest-c8 t5b2))
; j5j-15
 (defvc inf-vc-strest-j5j-15 (under inf-strest-c4 (pi g5 unit (inf-le ipj4 n)))
   (given inf-strest-c4 (lam g5 r1)))
; j5j-16
 (defvc inf-vc-strest-j5j-16 (under inf-strest-c4 (pi g5 unit (inf-le bcj4 63)))
   (given inf-strest-c4 (lam g5 r3)))
; j5j-17
 (defvc inf-vc-strest-j5j-17 (under inf-strest-c4 (pi g5 unit (inf-bits-inv carry ipj4 consj4 bcj4)))
   (given inf-strest-c4 (lam g5 r4)))
; j5j-18
 (defvc inf-vc-strest-j5j-18 (under inf-strest-c4 (pi g5 unit (inf-le cons0 consj4)))
   (given inf-strest-c4 (lam g5 r5)))
; j5j-19
 (defvc inf-vc-strest-j5j-19 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 c1)))
; j5j-20
 (defvc inf-vc-strest-j5j-20 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 c2)))
; j5j-21
 (defvc inf-vc-strest-j5j-21 (under inf-strest-c4 (pi g5 unit (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-strest-c4 (lam g5 c3)))
; j5j-22
 (defvc inf-vc-strest-j5j-22 (under inf-strest-c4 (pi g5 unit (inf-le lm0 288)))
   (given inf-strest-c4 (lam g5 c4)))
; j5j-23
 (defvc inf-vc-strest-j5j-23 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 c5)))
; j5j-24
 (defvc inf-vc-strest-j5j-24 (under inf-strest-c4 (pi g5 unit (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-strest-c4 (lam g5 c6)))
; j5j-25
 (defvc inf-vc-strest-j5j-25 (under inf-strest-c4 (pi g5 unit (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-strest-c4 (lam g5 c7)))
; j5j-26
 (defvc inf-vc-strest-j5j-26 (under inf-strest-c4 (pi g5 unit (inf-le dm0 32)))
   (given inf-strest-c4 (lam g5 c8)))
; j5j-27
 (defvc inf-vc-strest-j5j-27 (under inf-strest-c4 (pi g5 unit (inf-le prevj4 15)))
   (given inf-strest-c4 (lam g5 b1)))
; j5j-28
 (defvc inf-vc-strest-j5j-28 (under inf-strest-c4 (pi g5 unit (pi j nat (inf-le (Lzj4 j) 15))))
   (given inf-strest-c4 (lam g5 b2)))
 (defcx inf-strest-c5 inf-strest-c4 (ipj5 nat) (bcj5 nat) (bbj5 nat) (consj5 nat) (Lcj5 (pi j nat nat)) (Lsj5 (pi j nat nat)) (Ltj5 (pi j nat nat)) (Dcj5 (pi j nat nat)) (Dsj5 (pi j nat nat)) (Dtj5 (pi j nat nat)) (lmj5 nat) (dmj5 nat) (Lzj5 (pi j nat nat)) (ij5 nat) (prevj5 nat) (stagej5 nat) (syj5 nat) (modej5 nat) (r1 (inf-le ipj5 n)) (r3 (inf-le bcj5 63)) (r4 (inf-bits-inv carry ipj5 consj5 bcj5)) (r5 (inf-le cons0 consj5)) (c1 (pi k nat (inf-lt (Lcj5 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Lsj5 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lcj5 15 1) lmj5)) (c4 (inf-le lmj5 288)) (c5 (pi k nat (inf-lt (Dcj5 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Dsj5 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dcj5 15 1) dmj5)) (c8 (inf-le dmj5 32)) (b1 (inf-le prevj5 15)) (b2 (pi j nat (inf-le (Lzj5 j) 15))) )
; t6-1
 (defvc inf-vc-strest-t6-1 (under inf-strest-c5 (pi g6 unit (inf-le 32 w)))
   (given inf-strest-c5 (lam g6 gw)))
; t6-2
 (defvc inf-vc-strest-t6-2 (under inf-strest-c5 (pi g6 unit (inf-lt (add n 8) (inf-pow w))))
   (given inf-strest-c5 (lam g6 gn)))
; t6-3
 (defvc inf-vc-strest-t6-3 (under inf-strest-c5 (pi g6 unit (inf-le ipj5 n)))
   (given inf-strest-c5 (lam g6 r1)))
; t6-4
 (defvc inf-vc-strest-t6-4 (under inf-strest-c5 (pi g6 unit (inf-le bcj5 63)))
   (given inf-strest-c5 (lam g6 r3)))
; t6-5
 (defvc inf-vc-strest-t6-5 (under inf-strest-c5 (pi g6 unit (inf-bits-inv carry ipj5 consj5 bcj5)))
   (given inf-strest-c5 (lam g6 r4)))
; t6-6
 (defvc inf-vc-strest-t6-6 (under inf-strest-c5 (pi g6 unit (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-strest-c5 (lam g6 go)))
; t6-7
 (defvc inf-vc-strest-t6-7 (under inf-strest-c5 (pi g6 unit (inf-lt (add cap 8) (inf-pow w))))
   (given inf-strest-c5 (lam g6 gcap)))
; t6-8
 (defvc inf-vc-strest-t6-8 (under inf-strest-c5 (pi g6 unit (inf-le opj2 cap)))
   (given inf-strest-c5 (lam g6 o2)))
; t6-9
 (defvc inf-vc-strest-t6-9 (under inf-strest-c5 (pi g6 unit (inf-lt (add cap nd) (inf-pow w))))
   (given inf-strest-c5 (lam g6 gnd)))
; t6-10
 (defvc inf-vc-strest-t6-10 (under inf-strest-c5 (pi g6 unit (inf-lt (add cap 266) (inf-pow w))))
   (given inf-strest-c5 (lam g6 gcf)))
; t6-11
 (defvc inf-vc-strest-t6-11 (under inf-strest-c5 (pi g6 unit (inf-le LROOT 15)))
   (given inf-strest-c5 (lam g6 gl)))
; t6-12
 (defvc inf-vc-strest-t6-12 (under inf-strest-c5 (pi g6 unit (inf-le DROOT 15)))
   (given inf-strest-c5 (lam g6 gd)))
; t6-13
 (defvc inf-vc-strest-t6-13 (under inf-strest-c5 (pi g6 unit (inf-le h 16)))
   (given inf-strest-c5 (lam g6 gh)))
; t6-14
 (defvc inf-vc-strest-t6-14 (under inf-strest-c5 (pi g6 unit (pi k nat (inf-lt (Lcj5 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 c1)))
; t6-15
 (defvc inf-vc-strest-t6-15 (under inf-strest-c5 (pi g6 unit (pi k nat (inf-lt (Lsj5 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 c2)))
; t6-16
 (defvc inf-vc-strest-t6-16 (under inf-strest-c5 (pi g6 unit (inf-le (inf-sum Lcj5 15 1) lmj5)))
   (given inf-strest-c5 (lam g6 c3)))
; t6-17
 (defvc inf-vc-strest-t6-17 (under inf-strest-c5 (pi g6 unit (inf-le lmj5 288)))
   (given inf-strest-c5 (lam g6 c4)))
; t6-18
 (defvc inf-vc-strest-t6-18 (under inf-strest-c5 (pi g6 unit (pi k nat (inf-lt (Dcj5 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 c5)))
; t6-19
 (defvc inf-vc-strest-t6-19 (under inf-strest-c5 (pi g6 unit (pi k nat (inf-lt (Dsj5 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 c6)))
; t6-20
 (defvc inf-vc-strest-t6-20 (under inf-strest-c5 (pi g6 unit (inf-le (inf-sum Dcj5 15 1) dmj5)))
   (given inf-strest-c5 (lam g6 c7)))
; t6-21
 (defvc inf-vc-strest-t6-21 (under inf-strest-c5 (pi g6 unit (inf-le dmj5 32)))
   (given inf-strest-c5 (lam g6 c8)))
; t6-22
 (defvc inf-vc-strest-t6-22 (under inf-strest-c5 (pi g6 unit (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))))
   (given inf-strest-c5 (lam g6 hle)))
; t6-23
 (defvc inf-vc-strest-t6-23 (under inf-strest-c5 (pi g6 unit (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))))
   (given inf-strest-c5 (lam g6 hlb)))
; t6-24
 (defvc inf-vc-strest-t6-24 (under inf-strest-c5 (pi g6 unit (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))))
   (given inf-strest-c5 (lam g6 hlc)))
; t6-25
 (defvc inf-vc-strest-t6-25 (under inf-strest-c5 (pi g6 unit (pi k nat g (inf-lt k 30) (inf-le (De k) 13))))
   (given inf-strest-c5 (lam g6 hde)))
; t6-26
 (defvc inf-vc-strest-t6-26 (under inf-strest-c5 (pi g6 unit (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 hdb)))
; t6-27
 (defvc inf-vc-strest-t6-27 (under inf-strest-c5 (pi g6 unit (inf-lt 0 out)))
   (given inf-strest-c5 (lam g6 gz)))
; t6s-1
 (defvc inf-vc-strest-t6s-1 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le ipt6 n)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 t6e1)))
; t6s-2
 (defvc inf-vc-strest-t6s-2 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le bct6 63)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 t6e3)))
; t6s-3
 (defvc inf-vc-strest-t6s-3 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-bits-inv carry ipt6 const6 bct6)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 t6e4)))
; t6s-4
 (defvc inf-vc-strest-t6s-4 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le cons0 const6)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 (inf-letrans cons0 consj5 const6 r5 t6e5))))
; t6s-5
 (defvc inf-vc-strest-t6s-5 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le opt6 cap)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 t6e8)))
; t6s-6
 (defvc inf-vc-strest-t6s-6 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le op0 opt6)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 (inf-letrans op0 opj2 opt6 o1 t6e9))))
; t6s-7
 (defvc inf-vc-strest-t6s-7 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (pi k nat (inf-lt (Lcj5 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 c1)))
; t6s-8
 (defvc inf-vc-strest-t6s-8 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (pi k nat (inf-lt (Lsj5 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 c2)))
; t6s-9
 (defvc inf-vc-strest-t6s-9 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le (inf-sum Lcj5 15 1) lmj5)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 c3)))
; t6s-10
 (defvc inf-vc-strest-t6s-10 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le lmj5 288)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 c4)))
; t6s-11
 (defvc inf-vc-strest-t6s-11 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (pi k nat (inf-lt (Dcj5 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 c5)))
; t6s-12
 (defvc inf-vc-strest-t6s-12 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (pi k nat (inf-lt (Dsj5 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 c6)))
; t6s-13
 (defvc inf-vc-strest-t6s-13 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le (inf-sum Dcj5 15 1) dmj5)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 c7)))
; t6s-14
 (defvc inf-vc-strest-t6s-14 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le dmj5 32)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 c8)))
; t6s-15
 (defvc inf-vc-strest-t6s-15 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (pi k nat (inf-lt (Ccj4 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 d1)))
; t6s-16
 (defvc inf-vc-strest-t6s-16 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (pi k nat (inf-lt (Csj4 k) (inf-pow h)))))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 d2)))
; t6s-17
 (defvc inf-vc-strest-t6s-17 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le (inf-sum Ccj4 15 1) 19)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 d3)))
; t6s-18
 (defvc inf-vc-strest-t6s-18 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (inf-le prevj5 15)))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 b1)))
; t6s-19
 (defvc inf-vc-strest-t6s-19 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (pi j nat (inf-le (Lzj5 j) 15))))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 b2)))
; t6s-20
 (defvc inf-vc-strest-t6s-20 (under inf-strest-c5 (pi g6 unit ipt6 nat bct6 nat bbt6 nat const6 nat opt6 nat modet6 nat staget6 nat syt6 nat lent6 nat distt6 nat xt6 nat t6e1 (inf-le ipt6 n) t6e3 (inf-le bct6 63) t6e4 (inf-bits-inv carry ipt6 const6 bct6) t6e5 (inf-le consj5 const6) t6e8 (inf-le opt6 cap) t6e9 (inf-le opj2 opt6) (pi k nat (inf-le (Clj4 k) 15))))
   (given inf-strest-c5 (lam g6 ipt6 bct6 bbt6 const6 opt6 modet6 staget6 syt6 lent6 distt6 xt6 t6e1 t6e3 t6e4 t6e5 t6e8 t6e9 a2)))
 (defcx inf-strest-c7 inf-strest-c5 (g6 unit) (ipt6 nat) (bct6 nat) (bbt6 nat) (const6 nat) (opt6 nat) (modet6 nat) (staget6 nat) (syt6 nat) (lent6 nat) (distt6 nat) (xt6 nat) (t6e1 (inf-le ipt6 n)) (t6e3 (inf-le bct6 63)) (t6e4 (inf-bits-inv carry ipt6 const6 bct6)) (t6e5 (inf-le consj5 const6)) (t6e8 (inf-le opt6 cap)) (t6e9 (inf-le opj2 opt6)) )
; j6j-1
 (defvc inf-vc-strest-j6j-1 (under inf-strest-c7 (inf-le ipt6 n))
   (given inf-strest-c7 t6e1))
; j6j-2
 (defvc inf-vc-strest-j6j-2 (under inf-strest-c7 (inf-le bct6 63))
   (given inf-strest-c7 t6e3))
; j6j-3
 (defvc inf-vc-strest-j6j-3 (under inf-strest-c7 (inf-bits-inv carry ipt6 const6 bct6))
   (given inf-strest-c7 t6e4))
; j6j-4
 (defvc inf-vc-strest-j6j-4 (under inf-strest-c7 (inf-le cons0 const6))
   (given inf-strest-c7 (inf-letrans cons0 consj5 const6 r5 t6e5)))
; j6j-5
 (defvc inf-vc-strest-j6j-5 (under inf-strest-c7 (inf-le op0 opt6))
   (given inf-strest-c7 (inf-letrans op0 opj2 opt6 o1 t6e9)))
; j6j-6
 (defvc inf-vc-strest-j6j-6 (under inf-strest-c7 (inf-le opt6 cap))
   (given inf-strest-c7 t6e8))
; j6j-7
 (defvc inf-vc-strest-j6j-7 (under inf-strest-c5 (pi g6 unit (inf-le ipj5 n)))
   (given inf-strest-c5 (lam g6 r1)))
; j6j-8
 (defvc inf-vc-strest-j6j-8 (under inf-strest-c5 (pi g6 unit (inf-le bcj5 63)))
   (given inf-strest-c5 (lam g6 r3)))
; j6j-9
 (defvc inf-vc-strest-j6j-9 (under inf-strest-c5 (pi g6 unit (inf-bits-inv carry ipj5 consj5 bcj5)))
   (given inf-strest-c5 (lam g6 r4)))
; j6j-10
 (defvc inf-vc-strest-j6j-10 (under inf-strest-c5 (pi g6 unit (inf-le cons0 consj5)))
   (given inf-strest-c5 (lam g6 r5)))
; j6j-11
 (defvc inf-vc-strest-j6j-11 (under inf-strest-c5 (pi g6 unit (inf-le op0 opj2)))
   (given inf-strest-c5 (lam g6 o1)))
; j6j-12
 (defvc inf-vc-strest-j6j-12 (under inf-strest-c5 (pi g6 unit (inf-le opj2 cap)))
   (given inf-strest-c5 (lam g6 o2)))
 (defcx inf-strest-c6 inf-strest-c5 (ipj6 nat) (bcj6 nat) (bbj6 nat) (consj6 nat) (opj6 nat) (modej6 nat) (stagej6 nat) (syj6 nat) (lenj6 nat) (distj6 nat) (r1 (inf-le ipj6 n)) (r3 (inf-le bcj6 63)) (r4 (inf-bits-inv carry ipj6 consj6 bcj6)) (r5 (inf-le cons0 consj6)) (o1 (inf-le op0 opj6)) (o2 (inf-le opj6 cap)) )
; r1-1
 (defvc inf-vc-strest-r1-1 (under inf-strest-c6 (inf-le ipj6 n))
   (given inf-strest-c6 r1))
; r1-2
 (defvc inf-vc-strest-r1-2 (under inf-strest-c6 (inf-le bcj6 63))
   (given inf-strest-c6 r3))
; r1-3
 (defvc inf-vc-strest-r1-3 (under inf-strest-c6 (inf-bits-inv carry ipj6 consj6 bcj6))
   (given inf-strest-c6 r4))
; r1-4
 (defvc inf-vc-strest-r1-4 (under inf-strest-c6 (inf-le cons0 consj6))
   (given inf-strest-c6 r5))
; r1-5
 (defvc inf-vc-strest-r1-5 (under inf-strest-c6 (inf-le opj6 cap))
   (given inf-strest-c6 o2))
; r1-6
 (defvc inf-vc-strest-r1-6 (under inf-strest-c6 (inf-le op0 opj6))
   (given inf-strest-c6 o1))
; r1-7
 (defvc inf-vc-strest-r1-7 (under inf-strest-c6 (pi k nat (inf-lt (Lcj5 k) (inf-pow h))))
   (given inf-strest-c6 c1))
; r1-8
 (defvc inf-vc-strest-r1-8 (under inf-strest-c6 (pi k nat (inf-lt (Lsj5 k) (inf-pow h))))
   (given inf-strest-c6 c2))
; r1-9
 (defvc inf-vc-strest-r1-9 (under inf-strest-c6 (inf-le (inf-sum Lcj5 15 1) lmj5))
   (given inf-strest-c6 c3))
; r1-10
 (defvc inf-vc-strest-r1-10 (under inf-strest-c6 (inf-le lmj5 288))
   (given inf-strest-c6 c4))
; r1-11
 (defvc inf-vc-strest-r1-11 (under inf-strest-c6 (pi k nat (inf-lt (Dcj5 k) (inf-pow h))))
   (given inf-strest-c6 c5))
; r1-12
 (defvc inf-vc-strest-r1-12 (under inf-strest-c6 (pi k nat (inf-lt (Dsj5 k) (inf-pow h))))
   (given inf-strest-c6 c6))
; r1-13
 (defvc inf-vc-strest-r1-13 (under inf-strest-c6 (inf-le (inf-sum Dcj5 15 1) dmj5))
   (given inf-strest-c6 c7))
; r1-14
 (defvc inf-vc-strest-r1-14 (under inf-strest-c6 (inf-le dmj5 32))
   (given inf-strest-c6 c8))
; r1-15
 (defvc inf-vc-strest-r1-15 (under inf-strest-c6 (pi k nat (inf-lt (Ccj4 k) (inf-pow h))))
   (given inf-strest-c6 d1))
; r1-16
 (defvc inf-vc-strest-r1-16 (under inf-strest-c6 (pi k nat (inf-lt (Csj4 k) (inf-pow h))))
   (given inf-strest-c6 d2))
; r1-17
 (defvc inf-vc-strest-r1-17 (under inf-strest-c6 (inf-le (inf-sum Ccj4 15 1) 19))
   (given inf-strest-c6 d3))
; r1-18
 (defvc inf-vc-strest-r1-18 (under inf-strest-c6 (inf-le prevj5 15))
   (given inf-strest-c6 b1))
; r1-19
 (defvc inf-vc-strest-r1-19 (under inf-strest-c6 (pi j nat (inf-le (Lzj5 j) 15)))
   (given inf-strest-c6 b2))
; r1-20
 (defvc inf-vc-strest-r1-20 (under inf-strest-c6 (pi k nat (inf-le (Clj4 k) 15)))
   (given inf-strest-c6 a2))
 (defcx inf-ststep (In (pi k nat nat)) (n nat) (w nat) (carry nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gs (inf-le bc0 63)) (ga (inf-bits-inv carry ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (gcf (inf-lt (add cap 266) (inf-pow w))) (gz (inf-lt 0 out)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (last0 nat) (rem0 nat) (hclen0 nat) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) (mode0 nat) (hlit0 nat) (hdist0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (b1 (inf-le prev0 15)) (b2 (pi j nat (inf-le (Lz0 j) 15))) (a2 (pi k nat (inf-le (Cl0 k) 15))) )
; t1-1
 (defvc inf-vc-ststep-t1-1 (under inf-ststep (inf-le 32 w))
   (given inf-ststep gw))
; t1-2
 (defvc inf-vc-ststep-t1-2 (under inf-ststep (inf-lt (add n 8) (inf-pow w)))
   (given inf-ststep gn))
; t1-3
 (defvc inf-vc-ststep-t1-3 (under inf-ststep (inf-le ip0 n))
   (given inf-ststep gi))
; t1-4
 (defvc inf-vc-ststep-t1-4 (under inf-ststep (inf-le bc0 63))
   (given inf-ststep gs))
; t1-5
 (defvc inf-vc-ststep-t1-5 (under inf-ststep (inf-bits-inv carry ip0 cons0 bc0))
   (given inf-ststep ga))
; t1-6
 (defvc inf-vc-ststep-t1-6 (under inf-ststep (pi g (inf-lt 0 out) (paths nat oc cap)))
   (given inf-ststep go))
; t1-7
 (defvc inf-vc-ststep-t1-7 (under inf-ststep (inf-lt (add cap 8) (inf-pow w)))
   (given inf-ststep gcap))
; t1-8
 (defvc inf-vc-ststep-t1-8 (under inf-ststep (inf-le op0 cap))
   (given inf-ststep gop))
; t1-9
 (defvc inf-vc-ststep-t1-9 (under inf-ststep (inf-lt (add cap nd) (inf-pow w)))
   (given inf-ststep gnd))
; t1-10
 (defvc inf-vc-ststep-t1-10 (under inf-ststep (inf-le h 16))
   (given inf-ststep gh))
; t1-11
 (defvc inf-vc-ststep-t1-11 (under inf-ststep (inf-le (inf-by16 q) (inf-pow h)))
   (given inf-ststep gq))
; t1-12
 (defvc inf-vc-ststep-t1-12 (under inf-ststep (inf-lt 320 q))
   (given inf-ststep gq2))
; t1-13
 (defvc inf-vc-ststep-t1-13 (under inf-ststep (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))))
   (given inf-ststep gk))
; t1-14
 (defvc inf-vc-ststep-t1-14 (under inf-ststep (inf-le LROOT 15))
   (given inf-ststep gl))
; t1-15
 (defvc inf-vc-ststep-t1-15 (under inf-ststep (inf-le DROOT 15))
   (given inf-ststep gd))
; t1-16
 (defvc inf-vc-ststep-t1-16 (under inf-ststep (inf-le CROOT 15))
   (given inf-ststep gc))
; t1-17
 (defvc inf-vc-ststep-t1-17 (under inf-ststep (inf-lt (add cap 266) (inf-pow w)))
   (given inf-ststep gcf))
; t1-18
 (defvc inf-vc-ststep-t1-18 (under inf-ststep (inf-lt 0 out))
   (given inf-ststep gz))
; t1-19
 (defvc inf-vc-ststep-t1-19 (under inf-ststep (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)))
   (given inf-ststep hord))
; t1-20
 (defvc inf-vc-ststep-t1-20 (under inf-ststep (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
   (given inf-ststep hle))
; t1-21
 (defvc inf-vc-ststep-t1-21 (under inf-ststep (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
   (given inf-ststep hlb))
; t1-22
 (defvc inf-vc-ststep-t1-22 (under inf-ststep (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
   (given inf-ststep hlc))
; t1-23
 (defvc inf-vc-ststep-t1-23 (under inf-ststep (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
   (given inf-ststep hde))
; t1-24
 (defvc inf-vc-ststep-t1-24 (under inf-ststep (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))))
   (given inf-ststep hdb))
; t1-25
 (defvc inf-vc-ststep-t1-25 (under inf-ststep (pi k nat (inf-lt (Lc0 k) (inf-pow h))))
   (given inf-ststep c1))
; t1-26
 (defvc inf-vc-ststep-t1-26 (under inf-ststep (pi k nat (inf-lt (Ls0 k) (inf-pow h))))
   (given inf-ststep c2))
; t1-27
 (defvc inf-vc-ststep-t1-27 (under inf-ststep (inf-le (inf-sum Lc0 15 1) lm0))
   (given inf-ststep c3))
; t1-28
 (defvc inf-vc-ststep-t1-28 (under inf-ststep (inf-le lm0 288))
   (given inf-ststep c4))
; t1-29
 (defvc inf-vc-ststep-t1-29 (under inf-ststep (pi k nat (inf-lt (Dc0 k) (inf-pow h))))
   (given inf-ststep c5))
; t1-30
 (defvc inf-vc-ststep-t1-30 (under inf-ststep (pi k nat (inf-lt (Ds0 k) (inf-pow h))))
   (given inf-ststep c6))
; t1-31
 (defvc inf-vc-ststep-t1-31 (under inf-ststep (inf-le (inf-sum Dc0 15 1) dm0))
   (given inf-ststep c7))
; t1-32
 (defvc inf-vc-ststep-t1-32 (under inf-ststep (inf-le dm0 32))
   (given inf-ststep c8))
; t1-33
 (defvc inf-vc-ststep-t1-33 (under inf-ststep (pi k nat (inf-lt (Cc0 k) (inf-pow h))))
   (given inf-ststep d1))
; t1-34
 (defvc inf-vc-ststep-t1-34 (under inf-ststep (pi k nat (inf-lt (Cs0 k) (inf-pow h))))
   (given inf-ststep d2))
; t1-35
 (defvc inf-vc-ststep-t1-35 (under inf-ststep (inf-le (inf-sum Cc0 15 1) 19))
   (given inf-ststep d3))
; t1-36
 (defvc inf-vc-ststep-t1-36 (under inf-ststep (inf-le prev0 15))
   (given inf-ststep b1))
; t1-37
 (defvc inf-vc-ststep-t1-37 (under inf-ststep (pi j nat (inf-le (Lz0 j) 15)))
   (given inf-ststep b2))
; t1-38
 (defvc inf-vc-ststep-t1-38 (under inf-ststep (pi k nat (inf-le (Cl0 k) 15)))
   (given inf-ststep a2))
; t1s-1
 (defvc inf-vc-ststep-t1s-1 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le ipt1 n)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1e1)))
; t1s-2
 (defvc inf-vc-ststep-t1s-2 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le bct1 63)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1e3)))
; t1s-3
 (defvc inf-vc-ststep-t1s-3 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-bits-inv carry ipt1 const1 bct1)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1e4)))
; t1s-4
 (defvc inf-vc-ststep-t1s-4 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le cons0 const1)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1e5)))
; t1s-5
 (defvc inf-vc-ststep-t1s-5 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le opt1 cap)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1e8)))
; t1s-6
 (defvc inf-vc-ststep-t1s-6 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le op0 opt1)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1e9)))
; t1s-7
 (defvc inf-vc-ststep-t1s-7 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (pi k nat (inf-lt (Lct1 k) (inf-pow h)))))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1c1)))
; t1s-8
 (defvc inf-vc-ststep-t1s-8 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (pi k nat (inf-lt (Lst1 k) (inf-pow h)))))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1c2)))
; t1s-9
 (defvc inf-vc-ststep-t1s-9 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le (inf-sum Lct1 15 1) lmt1)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1c3)))
; t1s-10
 (defvc inf-vc-ststep-t1s-10 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le lmt1 288)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1c4)))
; t1s-11
 (defvc inf-vc-ststep-t1s-11 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (pi k nat (inf-lt (Dct1 k) (inf-pow h)))))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1c5)))
; t1s-12
 (defvc inf-vc-ststep-t1s-12 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (pi k nat (inf-lt (Dst1 k) (inf-pow h)))))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1c6)))
; t1s-13
 (defvc inf-vc-ststep-t1s-13 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le (inf-sum Dct1 15 1) dmt1)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1c7)))
; t1s-14
 (defvc inf-vc-ststep-t1s-14 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le dmt1 32)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1c8)))
; t1s-15
 (defvc inf-vc-ststep-t1s-15 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (pi k nat (inf-lt (Cct1 k) (inf-pow h)))))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1d1)))
; t1s-16
 (defvc inf-vc-ststep-t1s-16 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (pi k nat (inf-lt (Cst1 k) (inf-pow h)))))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1d2)))
; t1s-17
 (defvc inf-vc-ststep-t1s-17 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le (inf-sum Cct1 15 1) 19)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1d3)))
; t1s-18
 (defvc inf-vc-ststep-t1s-18 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (inf-le prevt1 15)))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1b1)))
; t1s-19
 (defvc inf-vc-ststep-t1s-19 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (pi j nat (inf-le (Lzt1 j) 15))))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1b2)))
; t1s-20
 (defvc inf-vc-ststep-t1s-20 (under inf-ststep (pi ipt1 nat bct1 nat bbt1 nat const1 nat opt1 nat Lct1 (pi j nat nat) Lst1 (pi j nat nat) Ltt1 (pi j nat nat) Dct1 (pi j nat nat) Dst1 (pi j nat nat) Dtt1 (pi j nat nat) lmt1 nat dmt1 nat Clt1 (pi j nat nat) Lzt1 (pi j nat nat) Cst1 (pi j nat nat) Ctt1 (pi j nat nat) Cct1 (pi j nat nat) lastt1 nat remt1 nat hclent1 nat it1 nat prevt1 nat staget1 nat syt1 nat lent1 nat distt1 nat modet1 nat hlitt1 nat hdistt1 nat xt1 nat t1e1 (inf-le ipt1 n) t1e3 (inf-le bct1 63) t1e4 (inf-bits-inv carry ipt1 const1 bct1) t1e5 (inf-le cons0 const1) t1e8 (inf-le opt1 cap) t1e9 (inf-le op0 opt1) t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))) t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h))) t1c3 (inf-le (inf-sum Lct1 15 1) lmt1) t1c4 (inf-le lmt1 288) t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h))) t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h))) t1c7 (inf-le (inf-sum Dct1 15 1) dmt1) t1c8 (inf-le dmt1 32) t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))) t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h))) t1d3 (inf-le (inf-sum Cct1 15 1) 19) t1b1 (inf-le prevt1 15) t1b2 (pi j nat (inf-le (Lzt1 j) 15)) t1a2 (pi k nat (inf-le (Clt1 k) 15)) (pi k nat (inf-le (Clt1 k) 15))))
   (given inf-ststep (lam ipt1 bct1 bbt1 const1 opt1 Lct1 Lst1 Ltt1 Dct1 Dst1 Dtt1 lmt1 dmt1 Clt1 Lzt1 Cst1 Ctt1 Cct1 lastt1 remt1 hclent1 it1 prevt1 staget1 syt1 lent1 distt1 modet1 hlitt1 hdistt1 xt1 t1e1 t1e3 t1e4 t1e5 t1e8 t1e9 t1c1 t1c2 t1c3 t1c4 t1c5 t1c6 t1c7 t1c8 t1d1 t1d2 t1d3 t1b1 t1b2 t1a2 t1a2)))
 (defcx inf-ststep-c1 inf-ststep (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (opt1 nat) (Lct1 (pi j nat nat)) (Lst1 (pi j nat nat)) (Ltt1 (pi j nat nat)) (Dct1 (pi j nat nat)) (Dst1 (pi j nat nat)) (Dtt1 (pi j nat nat)) (lmt1 nat) (dmt1 nat) (Clt1 (pi j nat nat)) (Lzt1 (pi j nat nat)) (Cst1 (pi j nat nat)) (Ctt1 (pi j nat nat)) (Cct1 (pi j nat nat)) (lastt1 nat) (remt1 nat) (hclent1 nat) (it1 nat) (prevt1 nat) (staget1 nat) (syt1 nat) (lent1 nat) (distt1 nat) (modet1 nat) (hlitt1 nat) (hdistt1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e3 (inf-le bct1 63)) (t1e4 (inf-bits-inv carry ipt1 const1 bct1)) (t1e5 (inf-le cons0 const1)) (t1e8 (inf-le opt1 cap)) (t1e9 (inf-le op0 opt1)) (t1c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h)))) (t1c2 (pi k nat (inf-lt (Lst1 k) (inf-pow h)))) (t1c3 (inf-le (inf-sum Lct1 15 1) lmt1)) (t1c4 (inf-le lmt1 288)) (t1c5 (pi k nat (inf-lt (Dct1 k) (inf-pow h)))) (t1c6 (pi k nat (inf-lt (Dst1 k) (inf-pow h)))) (t1c7 (inf-le (inf-sum Dct1 15 1) dmt1)) (t1c8 (inf-le dmt1 32)) (t1d1 (pi k nat (inf-lt (Cct1 k) (inf-pow h)))) (t1d2 (pi k nat (inf-lt (Cst1 k) (inf-pow h)))) (t1d3 (inf-le (inf-sum Cct1 15 1) 19)) (t1b1 (inf-le prevt1 15)) (t1b2 (pi j nat (inf-le (Lzt1 j) 15))) (t1a2 (pi k nat (inf-le (Clt1 k) 15))) )
; w1e-1
 (defvc inf-vc-ststep-w1e-1 (under inf-ststep-c1 (inf-le ipt1 n))
   (given inf-ststep-c1 t1e1))
; w1e-2
 (defvc inf-vc-ststep-w1e-2 (under inf-ststep-c1 (inf-le bct1 63))
   (given inf-ststep-c1 t1e3))
; w1e-3
 (defvc inf-vc-ststep-w1e-3 (under inf-ststep-c1 (inf-bits-inv carry ipt1 const1 bct1))
   (given inf-ststep-c1 t1e4))
; w1e-4
 (defvc inf-vc-ststep-w1e-4 (under inf-ststep-c1 (inf-le cons0 const1))
   (given inf-ststep-c1 t1e5))
; w1e-5
 (defvc inf-vc-ststep-w1e-5 (under inf-ststep-c1 (inf-le op0 opt1))
   (given inf-ststep-c1 t1e9))
; w1e-6
 (defvc inf-vc-ststep-w1e-6 (under inf-ststep-c1 (inf-le opt1 cap))
   (given inf-ststep-c1 t1e8))
; w1e-7
 (defvc inf-vc-ststep-w1e-7 (under inf-ststep-c1 (pi k nat (inf-lt (Lct1 k) (inf-pow h))))
   (given inf-ststep-c1 t1c1))
; w1e-8
 (defvc inf-vc-ststep-w1e-8 (under inf-ststep-c1 (pi k nat (inf-lt (Lst1 k) (inf-pow h))))
   (given inf-ststep-c1 t1c2))
; w1e-9
 (defvc inf-vc-ststep-w1e-9 (under inf-ststep-c1 (inf-le (inf-sum Lct1 15 1) lmt1))
   (given inf-ststep-c1 t1c3))
; w1e-10
 (defvc inf-vc-ststep-w1e-10 (under inf-ststep-c1 (inf-le lmt1 288))
   (given inf-ststep-c1 t1c4))
; w1e-11
 (defvc inf-vc-ststep-w1e-11 (under inf-ststep-c1 (pi k nat (inf-lt (Dct1 k) (inf-pow h))))
   (given inf-ststep-c1 t1c5))
; w1e-12
 (defvc inf-vc-ststep-w1e-12 (under inf-ststep-c1 (pi k nat (inf-lt (Dst1 k) (inf-pow h))))
   (given inf-ststep-c1 t1c6))
; w1e-13
 (defvc inf-vc-ststep-w1e-13 (under inf-ststep-c1 (inf-le (inf-sum Dct1 15 1) dmt1))
   (given inf-ststep-c1 t1c7))
; w1e-14
 (defvc inf-vc-ststep-w1e-14 (under inf-ststep-c1 (inf-le dmt1 32))
   (given inf-ststep-c1 t1c8))
; w1e-15
 (defvc inf-vc-ststep-w1e-15 (under inf-ststep-c1 (pi k nat (inf-lt (Cct1 k) (inf-pow h))))
   (given inf-ststep-c1 t1d1))
; w1e-16
 (defvc inf-vc-ststep-w1e-16 (under inf-ststep-c1 (pi k nat (inf-lt (Cst1 k) (inf-pow h))))
   (given inf-ststep-c1 t1d2))
; w1e-17
 (defvc inf-vc-ststep-w1e-17 (under inf-ststep-c1 (inf-le (inf-sum Cct1 15 1) 19))
   (given inf-ststep-c1 t1d3))
; w1e-18
 (defvc inf-vc-ststep-w1e-18 (under inf-ststep-c1 (inf-le prevt1 15))
   (given inf-ststep-c1 t1b1))
; w1e-19
 (defvc inf-vc-ststep-w1e-19 (under inf-ststep-c1 (pi j nat (inf-le (Lzt1 j) 15)))
   (given inf-ststep-c1 t1b2))
; w1e-20
 (defvc inf-vc-ststep-w1e-20 (under inf-ststep-c1 (pi k nat (inf-le (Clt1 k) 15)))
   (given inf-ststep-c1 t1a2))
 (defcx inf-ststep-c1-w1 inf-ststep-c1 (x nat) (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (Lc (pi j nat nat)) (Ls (pi j nat nat)) (Lt (pi j nat nat)) (Dc (pi j nat nat)) (Ds (pi j nat nat)) (Dt (pi j nat nat)) (lm nat) (dm nat) (Cl (pi j nat nat)) (Lz (pi j nat nat)) (Cs (pi j nat nat)) (Ct (pi j nat nat)) (Cc (pi j nat nat)) (last nat) (rem nat) (hclen nat) (i nat) (prev nat) (stage nat) (sy nat) (len nat) (dist nat) (mode nat) (hlit nat) (hdist nat) (r1 (inf-le ip n)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv carry ip cons bc)) (r5 (inf-le cons0 cons)) (o1 (inf-le op0 op)) (o2 (inf-le op cap)) (c1 (pi k nat (inf-lt (Lc k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc 15 1) lm)) (c4 (inf-le lm 288)) (c5 (pi k nat (inf-lt (Dc k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc 15 1) dm)) (c8 (inf-le dm 32)) (d1 (pi k nat (inf-lt (Cc k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc 15 1) 19)) (b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))) (a2 (pi k nat (inf-le (Cl k) 15))) )
; t2-1
 (defvc inf-vc-ststep-t2-1 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le 32 w)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec gw)))
; t2-2
 (defvc inf-vc-ststep-t2-2 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-lt (add n 8) (inf-pow w))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec gn)))
; t2-3
 (defvc inf-vc-ststep-t2-3 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le ip n)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec r1)))
; t2-4
 (defvc inf-vc-ststep-t2-4 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le bc 63)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec r3)))
; t2-5
 (defvc inf-vc-ststep-t2-5 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-bits-inv carry ip cons bc)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec r4)))
; t2-6
 (defvc inf-vc-ststep-t2-6 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le h 16)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec gh)))
; t2-7
 (defvc inf-vc-ststep-t2-7 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec gq)))
; t2-8
 (defvc inf-vc-ststep-t2-8 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-lt 320 q)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec gq2)))
; t2-9
 (defvc inf-vc-ststep-t2-9 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec gk)))
; t2-10
 (defvc inf-vc-ststep-t2-10 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le LROOT 15)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec gl)))
; t2-11
 (defvc inf-vc-ststep-t2-11 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le DROOT 15)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec gd)))
; t2-12
 (defvc inf-vc-ststep-t2-12 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le CROOT 15)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec gc)))
; t2-13
 (defvc inf-vc-ststep-t2-13 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (pi k nat (inf-lt (Lc k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec c1)))
; t2-14
 (defvc inf-vc-ststep-t2-14 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (pi k nat (inf-lt (Ls k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec c2)))
; t2-15
 (defvc inf-vc-ststep-t2-15 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le (inf-sum Lc 15 1) lm)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec c3)))
; t2-16
 (defvc inf-vc-ststep-t2-16 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le lm 288)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec c4)))
; t2-17
 (defvc inf-vc-ststep-t2-17 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (pi k nat (inf-lt (Dc k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec c5)))
; t2-18
 (defvc inf-vc-ststep-t2-18 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (pi k nat (inf-lt (Ds k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec c6)))
; t2-19
 (defvc inf-vc-ststep-t2-19 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le (inf-sum Dc 15 1) dm)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec c7)))
; t2-20
 (defvc inf-vc-ststep-t2-20 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) (inf-le dm 32)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec c8)))
; t2s-1
 (defvc inf-vc-ststep-t2s-1 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le ipt2 n)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2e1)))
; t2s-2
 (defvc inf-vc-ststep-t2s-2 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le bct2 63)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2e3)))
; t2s-3
 (defvc inf-vc-ststep-t2s-3 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-bits-inv carry ipt2 const2 bct2)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2e4)))
; t2s-4
 (defvc inf-vc-ststep-t2s-4 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le cons0 const2)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 (inf-letrans cons0 cons const2 r5 t2e5))))
; t2s-5
 (defvc inf-vc-ststep-t2s-5 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le op cap)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 o2)))
; t2s-6
 (defvc inf-vc-ststep-t2s-6 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le op0 op)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 o1)))
; t2s-7
 (defvc inf-vc-ststep-t2s-7 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (pi k nat (inf-lt (Lct2 k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2c1)))
; t2s-8
 (defvc inf-vc-ststep-t2s-8 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (pi k nat (inf-lt (Lst2 k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2c2)))
; t2s-9
 (defvc inf-vc-ststep-t2s-9 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le (inf-sum Lct2 15 1) lmt2)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2c3)))
; t2s-10
 (defvc inf-vc-ststep-t2s-10 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le lmt2 288)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2c4)))
; t2s-11
 (defvc inf-vc-ststep-t2s-11 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (pi k nat (inf-lt (Dct2 k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2c5)))
; t2s-12
 (defvc inf-vc-ststep-t2s-12 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (pi k nat (inf-lt (Dst2 k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2c6)))
; t2s-13
 (defvc inf-vc-ststep-t2s-13 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le (inf-sum Dct2 15 1) dmt2)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2c7)))
; t2s-14
 (defvc inf-vc-ststep-t2s-14 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le dmt2 32)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 t2c8)))
; t2s-15
 (defvc inf-vc-ststep-t2s-15 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (pi k nat (inf-lt (Cc k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 d1)))
; t2s-16
 (defvc inf-vc-ststep-t2s-16 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (pi k nat (inf-lt (Cs k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 d2)))
; t2s-17
 (defvc inf-vc-ststep-t2s-17 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le (inf-sum Cc 15 1) 19)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 d3)))
; t2s-18
 (defvc inf-vc-ststep-t2s-18 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (inf-le prev 15)))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 b1)))
; t2s-19
 (defvc inf-vc-ststep-t2s-19 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (pi j nat (inf-le (Lz j) 15))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 b2)))
; t2s-20
 (defvc inf-vc-ststep-t2s-20 (under inf-ststep-c1-w1 (pi w1 (paths nat mode 0) c0 nat ec (paths nat c0 cons) ipt2 nat bct2 nat bbt2 nat const2 nat Lct2 (pi j nat nat) Lst2 (pi j nat nat) Ltt2 (pi j nat nat) Dct2 (pi j nat nat) Dst2 (pi j nat nat) Dtt2 (pi j nat nat) lmt2 nat dmt2 nat lastt2 nat modet2 nat staget2 nat xt2 nat t2e1 (inf-le ipt2 n) t2e3 (inf-le bct2 63) t2e4 (inf-bits-inv carry ipt2 const2 bct2) t2e5 (inf-le cons const2) t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h))) t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))) t2c3 (inf-le (inf-sum Lct2 15 1) lmt2) t2c4 (inf-le lmt2 288) t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h))) t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h))) t2c7 (inf-le (inf-sum Dct2 15 1) dmt2) t2c8 (inf-le dmt2 32) (pi k nat (inf-le (Cl k) 15))))
   (given inf-ststep-c1-w1 (lam w1 c0 ec ipt2 bct2 bbt2 const2 Lct2 Lst2 Ltt2 Dct2 Dst2 Dtt2 lmt2 dmt2 lastt2 modet2 staget2 xt2 t2e1 t2e3 t2e4 t2e5 t2c1 t2c2 t2c3 t2c4 t2c5 t2c6 t2c7 t2c8 a2)))
 (defcx inf-ststep-c2 inf-ststep-c1-w1 (w1 (paths nat mode 0)) (c0 nat) (ec (paths nat c0 cons)) (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (Lct2 (pi j nat nat)) (Lst2 (pi j nat nat)) (Ltt2 (pi j nat nat)) (Dct2 (pi j nat nat)) (Dst2 (pi j nat nat)) (Dtt2 (pi j nat nat)) (lmt2 nat) (dmt2 nat) (lastt2 nat) (modet2 nat) (staget2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e3 (inf-le bct2 63)) (t2e4 (inf-bits-inv carry ipt2 const2 bct2)) (t2e5 (inf-le cons const2)) (t2c1 (pi k nat (inf-lt (Lct2 k) (inf-pow h)))) (t2c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h)))) (t2c3 (inf-le (inf-sum Lct2 15 1) lmt2)) (t2c4 (inf-le lmt2 288)) (t2c5 (pi k nat (inf-lt (Dct2 k) (inf-pow h)))) (t2c6 (pi k nat (inf-lt (Dst2 k) (inf-pow h)))) (t2c7 (inf-le (inf-sum Dct2 15 1) dmt2)) (t2c8 (inf-le dmt2 32)) (t2e6 (inf-le (add cons 3) const2)) )
; t3-1
 (defvc inf-vc-ststep-t3-1 (under inf-ststep-c2 (inf-le 32 w))
   (given inf-ststep-c2 gw))
; t3-2
 (defvc inf-vc-ststep-t3-2 (under inf-ststep-c2 (inf-lt (add n 8) (inf-pow w)))
   (given inf-ststep-c2 gn))
; t3-3
 (defvc inf-vc-ststep-t3-3 (under inf-ststep-c2 (inf-le ipt2 n))
   (given inf-ststep-c2 t2e1))
; t3-4
 (defvc inf-vc-ststep-t3-4 (under inf-ststep-c2 (inf-le bct2 63))
   (given inf-ststep-c2 t2e3))
; t3-5
 (defvc inf-vc-ststep-t3-5 (under inf-ststep-c2 (inf-bits-inv carry ipt2 const2 bct2))
   (given inf-ststep-c2 t2e4))
; t3-6
 (defvc inf-vc-ststep-t3-6 (under inf-ststep-c2 (pi g (inf-lt 0 out) (paths nat oc cap)))
   (given inf-ststep-c2 go))
; t3-7
 (defvc inf-vc-ststep-t3-7 (under inf-ststep-c2 (inf-lt (add cap 8) (inf-pow w)))
   (given inf-ststep-c2 gcap))
; t3-8
 (defvc inf-vc-ststep-t3-8 (under inf-ststep-c2 (inf-le op cap))
   (given inf-ststep-c2 o2))
; t3-9
 (defvc inf-vc-ststep-t3-9 (under inf-ststep-c2 (inf-lt (add cap nd) (inf-pow w)))
   (given inf-ststep-c2 gnd))
; t3-10
 (defvc inf-vc-ststep-t3-10 (under inf-ststep-c2 (inf-le h 16))
   (given inf-ststep-c2 gh))
; t3-11
 (defvc inf-vc-ststep-t3-11 (under inf-ststep-c2 (inf-le (inf-by16 q) (inf-pow h)))
   (given inf-ststep-c2 gq))
; t3-12
 (defvc inf-vc-ststep-t3-12 (under inf-ststep-c2 (inf-lt 320 q))
   (given inf-ststep-c2 gq2))
; t3-13
 (defvc inf-vc-ststep-t3-13 (under inf-ststep-c2 (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))))
   (given inf-ststep-c2 gk))
; t3-14
 (defvc inf-vc-ststep-t3-14 (under inf-ststep-c2 (inf-le LROOT 15))
   (given inf-ststep-c2 gl))
; t3-15
 (defvc inf-vc-ststep-t3-15 (under inf-ststep-c2 (inf-le DROOT 15))
   (given inf-ststep-c2 gd))
; t3-16
 (defvc inf-vc-ststep-t3-16 (under inf-ststep-c2 (inf-le CROOT 15))
   (given inf-ststep-c2 gc))
; t3-17
 (defvc inf-vc-ststep-t3-17 (under inf-ststep-c2 (inf-lt (add cap 266) (inf-pow w)))
   (given inf-ststep-c2 gcf))
; t3-18
 (defvc inf-vc-ststep-t3-18 (under inf-ststep-c2 (inf-lt 0 out))
   (given inf-ststep-c2 gz))
; t3-19
 (defvc inf-vc-ststep-t3-19 (under inf-ststep-c2 (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)))
   (given inf-ststep-c2 hord))
; t3-20
 (defvc inf-vc-ststep-t3-20 (under inf-ststep-c2 (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
   (given inf-ststep-c2 hle))
; t3-21
 (defvc inf-vc-ststep-t3-21 (under inf-ststep-c2 (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
   (given inf-ststep-c2 hlb))
; t3-22
 (defvc inf-vc-ststep-t3-22 (under inf-ststep-c2 (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
   (given inf-ststep-c2 hlc))
; t3-23
 (defvc inf-vc-ststep-t3-23 (under inf-ststep-c2 (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
   (given inf-ststep-c2 hde))
; t3-24
 (defvc inf-vc-ststep-t3-24 (under inf-ststep-c2 (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))))
   (given inf-ststep-c2 hdb))
; t3-25
 (defvc inf-vc-ststep-t3-25 (under inf-ststep-c2 (pi k nat (inf-lt (Lct2 k) (inf-pow h))))
   (given inf-ststep-c2 t2c1))
; t3-26
 (defvc inf-vc-ststep-t3-26 (under inf-ststep-c2 (pi k nat (inf-lt (Lst2 k) (inf-pow h))))
   (given inf-ststep-c2 t2c2))
; t3-27
 (defvc inf-vc-ststep-t3-27 (under inf-ststep-c2 (inf-le (inf-sum Lct2 15 1) lmt2))
   (given inf-ststep-c2 t2c3))
; t3-28
 (defvc inf-vc-ststep-t3-28 (under inf-ststep-c2 (inf-le lmt2 288))
   (given inf-ststep-c2 t2c4))
; t3-29
 (defvc inf-vc-ststep-t3-29 (under inf-ststep-c2 (pi k nat (inf-lt (Dct2 k) (inf-pow h))))
   (given inf-ststep-c2 t2c5))
; t3-30
 (defvc inf-vc-ststep-t3-30 (under inf-ststep-c2 (pi k nat (inf-lt (Dst2 k) (inf-pow h))))
   (given inf-ststep-c2 t2c6))
; t3-31
 (defvc inf-vc-ststep-t3-31 (under inf-ststep-c2 (inf-le (inf-sum Dct2 15 1) dmt2))
   (given inf-ststep-c2 t2c7))
; t3-32
 (defvc inf-vc-ststep-t3-32 (under inf-ststep-c2 (inf-le dmt2 32))
   (given inf-ststep-c2 t2c8))
; t3-33
 (defvc inf-vc-ststep-t3-33 (under inf-ststep-c2 (pi k nat (inf-lt (Cc k) (inf-pow h))))
   (given inf-ststep-c2 d1))
; t3-34
 (defvc inf-vc-ststep-t3-34 (under inf-ststep-c2 (pi k nat (inf-lt (Cs k) (inf-pow h))))
   (given inf-ststep-c2 d2))
; t3-35
 (defvc inf-vc-ststep-t3-35 (under inf-ststep-c2 (inf-le (inf-sum Cc 15 1) 19))
   (given inf-ststep-c2 d3))
; t3-36
 (defvc inf-vc-ststep-t3-36 (under inf-ststep-c2 (inf-le prev 15))
   (given inf-ststep-c2 b1))
; t3-37
 (defvc inf-vc-ststep-t3-37 (under inf-ststep-c2 (pi j nat (inf-le (Lz j) 15)))
   (given inf-ststep-c2 b2))
; t3-38
 (defvc inf-vc-ststep-t3-38 (under inf-ststep-c2 (pi k nat (inf-le (Cl k) 15)))
   (given inf-ststep-c2 a2))
; t3s-1
 (defvc inf-vc-ststep-t3s-1 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le ipt3 n)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3e1)))
; t3s-2
 (defvc inf-vc-ststep-t3s-2 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le bct3 63)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3e3)))
; t3s-3
 (defvc inf-vc-ststep-t3s-3 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-bits-inv carry ipt3 const3 bct3)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3e4)))
; t3s-4
 (defvc inf-vc-ststep-t3s-4 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le cons0 const3)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 (inf-letrans cons0 cons const3 r5 (inf-letrans cons const2 const3 t2e5 t3e5)))))
; t3s-5
 (defvc inf-vc-ststep-t3s-5 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le opt3 cap)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3e8)))
; t3s-6
 (defvc inf-vc-ststep-t3s-6 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le op0 opt3)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 (inf-letrans op0 op opt3 o1 t3e9))))
; t3s-7
 (defvc inf-vc-ststep-t3s-7 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Lct3 k) (inf-pow h)))))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3c1)))
; t3s-8
 (defvc inf-vc-ststep-t3s-8 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Lst3 k) (inf-pow h)))))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3c2)))
; t3s-9
 (defvc inf-vc-ststep-t3s-9 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le (inf-sum Lct3 15 1) lmt3)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3c3)))
; t3s-10
 (defvc inf-vc-ststep-t3s-10 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le lmt3 288)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3c4)))
; t3s-11
 (defvc inf-vc-ststep-t3s-11 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Dct3 k) (inf-pow h)))))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3c5)))
; t3s-12
 (defvc inf-vc-ststep-t3s-12 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Dst3 k) (inf-pow h)))))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3c6)))
; t3s-13
 (defvc inf-vc-ststep-t3s-13 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le (inf-sum Dct3 15 1) dmt3)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3c7)))
; t3s-14
 (defvc inf-vc-ststep-t3s-14 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le dmt3 32)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3c8)))
; t3s-15
 (defvc inf-vc-ststep-t3s-15 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Cct3 k) (inf-pow h)))))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3d1)))
; t3s-16
 (defvc inf-vc-ststep-t3s-16 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-lt (Cst3 k) (inf-pow h)))))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3d2)))
; t3s-17
 (defvc inf-vc-ststep-t3s-17 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le (inf-sum Cct3 15 1) 19)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3d3)))
; t3s-18
 (defvc inf-vc-ststep-t3s-18 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (inf-le prevt3 15)))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3b1)))
; t3s-19
 (defvc inf-vc-ststep-t3s-19 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi j nat (inf-le (Lzt3 j) 15))))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3b2)))
; t3s-20
 (defvc inf-vc-ststep-t3s-20 (under inf-ststep-c2 (pi ipt3 nat bct3 nat bbt3 nat const3 nat opt3 nat Lct3 (pi j nat nat) Lst3 (pi j nat nat) Ltt3 (pi j nat nat) Dct3 (pi j nat nat) Dst3 (pi j nat nat) Dtt3 (pi j nat nat) lmt3 nat dmt3 nat Clt3 (pi j nat nat) Lzt3 (pi j nat nat) Cst3 (pi j nat nat) Ctt3 (pi j nat nat) Cct3 (pi j nat nat) lastt3 nat remt3 nat hclent3 nat it3 nat prevt3 nat staget3 nat syt3 nat lent3 nat distt3 nat modet3 nat hlitt3 nat hdistt3 nat xt3 nat t3e1 (inf-le ipt3 n) t3e3 (inf-le bct3 63) t3e4 (inf-bits-inv carry ipt3 const3 bct3) t3e5 (inf-le const2 const3) t3e8 (inf-le opt3 cap) t3e9 (inf-le op opt3) t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h))) t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h))) t3c3 (inf-le (inf-sum Lct3 15 1) lmt3) t3c4 (inf-le lmt3 288) t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h))) t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h))) t3c7 (inf-le (inf-sum Dct3 15 1) dmt3) t3c8 (inf-le dmt3 32) t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h))) t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h))) t3d3 (inf-le (inf-sum Cct3 15 1) 19) t3b1 (inf-le prevt3 15) t3b2 (pi j nat (inf-le (Lzt3 j) 15)) t3a2 (pi k nat (inf-le (Clt3 k) 15)) (pi k nat (inf-le (Clt3 k) 15))))
   (given inf-ststep-c2 (lam ipt3 bct3 bbt3 const3 opt3 Lct3 Lst3 Ltt3 Dct3 Dst3 Dtt3 lmt3 dmt3 Clt3 Lzt3 Cst3 Ctt3 Cct3 lastt3 remt3 hclent3 it3 prevt3 staget3 syt3 lent3 distt3 modet3 hlitt3 hdistt3 xt3 t3e1 t3e3 t3e4 t3e5 t3e8 t3e9 t3c1 t3c2 t3c3 t3c4 t3c5 t3c6 t3c7 t3c8 t3d1 t3d2 t3d3 t3b1 t3b2 t3a2 t3a2)))
 (defcx inf-ststep-c3 inf-ststep-c2 (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (opt3 nat) (Lct3 (pi j nat nat)) (Lst3 (pi j nat nat)) (Ltt3 (pi j nat nat)) (Dct3 (pi j nat nat)) (Dst3 (pi j nat nat)) (Dtt3 (pi j nat nat)) (lmt3 nat) (dmt3 nat) (Clt3 (pi j nat nat)) (Lzt3 (pi j nat nat)) (Cst3 (pi j nat nat)) (Ctt3 (pi j nat nat)) (Cct3 (pi j nat nat)) (lastt3 nat) (remt3 nat) (hclent3 nat) (it3 nat) (prevt3 nat) (staget3 nat) (syt3 nat) (lent3 nat) (distt3 nat) (modet3 nat) (hlitt3 nat) (hdistt3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e3 (inf-le bct3 63)) (t3e4 (inf-bits-inv carry ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e8 (inf-le opt3 cap)) (t3e9 (inf-le op opt3)) (t3c1 (pi k nat (inf-lt (Lct3 k) (inf-pow h)))) (t3c2 (pi k nat (inf-lt (Lst3 k) (inf-pow h)))) (t3c3 (inf-le (inf-sum Lct3 15 1) lmt3)) (t3c4 (inf-le lmt3 288)) (t3c5 (pi k nat (inf-lt (Dct3 k) (inf-pow h)))) (t3c6 (pi k nat (inf-lt (Dst3 k) (inf-pow h)))) (t3c7 (inf-le (inf-sum Dct3 15 1) dmt3)) (t3c8 (inf-le dmt3 32)) (t3d1 (pi k nat (inf-lt (Cct3 k) (inf-pow h)))) (t3d2 (pi k nat (inf-lt (Cst3 k) (inf-pow h)))) (t3d3 (inf-le (inf-sum Cct3 15 1) 19)) (t3b1 (inf-le prevt3 15)) (t3b2 (pi j nat (inf-le (Lzt3 j) 15))) (t3a2 (pi k nat (inf-le (Clt3 k) 15))) )
; w1b-1
 (defvc inf-vc-ststep-w1b-1 (under inf-ststep-c3 (inf-le ipt3 n))
   (given inf-ststep-c3 t3e1))
; w1b-2
 (defvc inf-vc-ststep-w1b-2 (under inf-ststep-c3 (inf-le bct3 63))
   (given inf-ststep-c3 t3e3))
; w1b-3
 (defvc inf-vc-ststep-w1b-3 (under inf-ststep-c3 (inf-bits-inv carry ipt3 const3 bct3))
   (given inf-ststep-c3 t3e4))
; w1b-4
 (defvc inf-vc-ststep-w1b-4 (under inf-ststep-c3 (inf-le cons0 const3))
   (given inf-ststep-c3 (inf-letrans cons0 cons const3 r5 (inf-letrans cons const2 const3 t2e5 t3e5))))
; w1b-5
 (defvc inf-vc-ststep-w1b-5 (under inf-ststep-c3 (inf-le op0 opt3))
   (given inf-ststep-c3 (inf-letrans op0 op opt3 o1 t3e9)))
; w1b-6
 (defvc inf-vc-ststep-w1b-6 (under inf-ststep-c3 (inf-le opt3 cap))
   (given inf-ststep-c3 t3e8))
; w1b-7
 (defvc inf-vc-ststep-w1b-7 (under inf-ststep-c3 (pi k nat (inf-lt (Lct3 k) (inf-pow h))))
   (given inf-ststep-c3 t3c1))
; w1b-8
 (defvc inf-vc-ststep-w1b-8 (under inf-ststep-c3 (pi k nat (inf-lt (Lst3 k) (inf-pow h))))
   (given inf-ststep-c3 t3c2))
; w1b-9
 (defvc inf-vc-ststep-w1b-9 (under inf-ststep-c3 (inf-le (inf-sum Lct3 15 1) lmt3))
   (given inf-ststep-c3 t3c3))
; w1b-10
 (defvc inf-vc-ststep-w1b-10 (under inf-ststep-c3 (inf-le lmt3 288))
   (given inf-ststep-c3 t3c4))
; w1b-11
 (defvc inf-vc-ststep-w1b-11 (under inf-ststep-c3 (pi k nat (inf-lt (Dct3 k) (inf-pow h))))
   (given inf-ststep-c3 t3c5))
; w1b-12
 (defvc inf-vc-ststep-w1b-12 (under inf-ststep-c3 (pi k nat (inf-lt (Dst3 k) (inf-pow h))))
   (given inf-ststep-c3 t3c6))
; w1b-13
 (defvc inf-vc-ststep-w1b-13 (under inf-ststep-c3 (inf-le (inf-sum Dct3 15 1) dmt3))
   (given inf-ststep-c3 t3c7))
; w1b-14
 (defvc inf-vc-ststep-w1b-14 (under inf-ststep-c3 (inf-le dmt3 32))
   (given inf-ststep-c3 t3c8))
; w1b-15
 (defvc inf-vc-ststep-w1b-15 (under inf-ststep-c3 (pi k nat (inf-lt (Cct3 k) (inf-pow h))))
   (given inf-ststep-c3 t3d1))
; w1b-16
 (defvc inf-vc-ststep-w1b-16 (under inf-ststep-c3 (pi k nat (inf-lt (Cst3 k) (inf-pow h))))
   (given inf-ststep-c3 t3d2))
; w1b-17
 (defvc inf-vc-ststep-w1b-17 (under inf-ststep-c3 (inf-le (inf-sum Cct3 15 1) 19))
   (given inf-ststep-c3 t3d3))
; w1b-18
 (defvc inf-vc-ststep-w1b-18 (under inf-ststep-c3 (inf-le prevt3 15))
   (given inf-ststep-c3 t3b1))
; w1b-19
 (defvc inf-vc-ststep-w1b-19 (under inf-ststep-c3 (pi j nat (inf-le (Lzt3 j) 15)))
   (given inf-ststep-c3 t3b2))
; w1b-20
 (defvc inf-vc-ststep-w1b-20 (under inf-ststep-c3 (pi k nat (inf-le (Clt3 k) 15)))
   (given inf-ststep-c3 t3a2))
; w1b-21
 (defvc inf-vc-ststep-w1b-21 (under inf-ststep-c3 (inf-lt (natminus (add carry (inf-by8 n)) const3) (natminus (add carry (inf-by8 n)) cons)))
   (given inf-ststep-c3 (inf-consfall carry ipt3 const3 bct3 n cons t3e4 t3e1 (inf-lttrans cons (add cons 3) const3 (inf-ltaddpos cons 3 (idpath true)) (inf-letrans (add cons 3) const2 const3 t2e6 t3e5)))))
; r1-1
 (defvc inf-vc-ststep-r1-1 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le ip n)))
   (given inf-ststep-c1-w1 (lam w1 r1)))
; r1-2
 (defvc inf-vc-ststep-r1-2 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le bc 63)))
   (given inf-ststep-c1-w1 (lam w1 r3)))
; r1-3
 (defvc inf-vc-ststep-r1-3 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-bits-inv carry ip cons bc)))
   (given inf-ststep-c1-w1 (lam w1 r4)))
; r1-4
 (defvc inf-vc-ststep-r1-4 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le cons0 cons)))
   (given inf-ststep-c1-w1 (lam w1 r5)))
; r1-5
 (defvc inf-vc-ststep-r1-5 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le op cap)))
   (given inf-ststep-c1-w1 (lam w1 o2)))
; r1-6
 (defvc inf-vc-ststep-r1-6 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le op0 op)))
   (given inf-ststep-c1-w1 (lam w1 o1)))
; r1-7
 (defvc inf-vc-ststep-r1-7 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (pi k nat (inf-lt (Lc k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c1)))
; r1-8
 (defvc inf-vc-ststep-r1-8 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (pi k nat (inf-lt (Ls k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c2)))
; r1-9
 (defvc inf-vc-ststep-r1-9 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le (inf-sum Lc 15 1) lm)))
   (given inf-ststep-c1-w1 (lam w1 c3)))
; r1-10
 (defvc inf-vc-ststep-r1-10 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le lm 288)))
   (given inf-ststep-c1-w1 (lam w1 c4)))
; r1-11
 (defvc inf-vc-ststep-r1-11 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (pi k nat (inf-lt (Dc k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c5)))
; r1-12
 (defvc inf-vc-ststep-r1-12 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (pi k nat (inf-lt (Ds k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 c6)))
; r1-13
 (defvc inf-vc-ststep-r1-13 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le (inf-sum Dc 15 1) dm)))
   (given inf-ststep-c1-w1 (lam w1 c7)))
; r1-14
 (defvc inf-vc-ststep-r1-14 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le dm 32)))
   (given inf-ststep-c1-w1 (lam w1 c8)))
; r1-15
 (defvc inf-vc-ststep-r1-15 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (pi k nat (inf-lt (Cc k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 d1)))
; r1-16
 (defvc inf-vc-ststep-r1-16 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (pi k nat (inf-lt (Cs k) (inf-pow h)))))
   (given inf-ststep-c1-w1 (lam w1 d2)))
; r1-17
 (defvc inf-vc-ststep-r1-17 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le (inf-sum Cc 15 1) 19)))
   (given inf-ststep-c1-w1 (lam w1 d3)))
; r1-18
 (defvc inf-vc-ststep-r1-18 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (inf-le prev 15)))
   (given inf-ststep-c1-w1 (lam w1 b1)))
; r1-19
 (defvc inf-vc-ststep-r1-19 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (pi j nat (inf-le (Lz j) 15))))
   (given inf-ststep-c1-w1 (lam w1 b2)))
; r1-20
 (defvc inf-vc-ststep-r1-20 (under inf-ststep-c1-w1 (pi w1 (inf-lt 0 mode) (pi k nat (inf-le (Cl k) 15))))
   (given inf-ststep-c1-w1 (lam w1 a2)))
 (defcx inf-stkeep (w nat) (op nat) (oc nat) (hlen0 nat) (lw nat) (lim nat) (gw (inf-le 32 w)) (gop (inf-le op oc)) (hww (inf-le lw lim)) (hs (inf-le (succ lw) lim)) (hm (inf-lt lim 31)) (gh (inf-le hlen0 (inf-pow lim))) )
; i1-1
 (defvc inf-vc-stkeep-i1-1 (under inf-stkeep (inf-lt lw 32))
   (given inf-stkeep (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))
; i1-2
 (defvc inf-vc-stkeep-i1-2 (under inf-stkeep (inf-lt (inf-pow lw) (inf-pow w)))
   (given inf-stkeep (inf-lelt (inf-pow lw) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lw) (inf-pow lim) (inf-pow lim) (inf-powle lw lim hww) (inf-refl (inf-pow lim))) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false))))))
; m1-1
 (defvc inf-vc-stkeep-m1-1 (under inf-stkeep (pi g1 (inf-le (inf-pow lw) op) (inf-lt lw 32)))
   (given inf-stkeep (lam g1 (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))))
; m1-2
 (defvc inf-vc-stkeep-m1-2 (under inf-stkeep (pi g1 (inf-le (inf-pow lw) op) (inf-lt (inf-pow lw) (inf-pow w))))
   (given inf-stkeep (lam g1 (inf-lelt (inf-pow lw) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lw) (inf-pow lim) (inf-pow lim) (inf-powle lw lim hww) (inf-refl (inf-pow lim))) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; m1-3
 (defvc inf-vc-stkeep-m1-3 (under inf-stkeep (pi g1 (inf-le (inf-pow lw) op) (inf-le (inf-pow lw) op)))
   (given inf-stkeep (lam g1 g1)))
; m1-4
 (defvc inf-vc-stkeep-m1-4 (under inf-stkeep (pi g1 (inf-le (inf-pow lw) op) (inf-le (add 0 (inf-pow lw)) (inf-pow lim))))
   (given inf-stkeep (lam g1 ((inf-powle lw lim hww)))))
; m1-5
 (defvc inf-vc-stkeep-m1-5 (under inf-stkeep (pi g1 (inf-le (inf-pow lw) op) (inf-le (add (natminus op (inf-pow lw)) (inf-pow lw)) oc)))
   (given inf-stkeep (lam g1 (inf-letrans (add (natminus op (inf-pow lw)) (inf-pow lw)) op oc (inf-subfit op (inf-pow lw) g1) gop))))
; d1-1
 (defvc inf-vc-stkeep-d1-1 (under inf-stkeep (pi g1 (inf-le (inf-pow lw) op) (inf-lt lw 32)))
   (given inf-stkeep (lam g1 (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))))
; d1-2
 (defvc inf-vc-stkeep-d1-2 (under inf-stkeep (pi g1 (inf-le (inf-pow lw) op) (inf-lt (inf-pow lw) (inf-pow w))))
   (given inf-stkeep (lam g1 (inf-lelt (inf-pow lw) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lw) (inf-pow lim) (inf-pow lim) (inf-powle lw lim hww) (inf-refl (inf-pow lim))) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; j1-1
 (defvc inf-vc-stkeep-j1-1 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) (inf-lt lim 32)))
   (given inf-stkeep (lam g1 (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))
; j1-2
 (defvc inf-vc-stkeep-j1-2 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) (inf-lt (inf-pow lim) (inf-pow w))))
   (given inf-stkeep (lam g1 (inf-lelt (inf-pow lim) (inf-pow lim) (inf-pow w) (inf-refl (inf-pow lim)) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; j1-3
 (defvc inf-vc-stkeep-j1-3 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) (inf-lt (add hlen0 op) (inf-pow w))))
   (given inf-stkeep (lam g1 (inf-fitlim w lim hlen0 op gw hm gh (inf-letrans op (inf-pow lw) (inf-pow lim) (inf-ltle op (inf-pow lw) g1) (inf-letrans (inf-pow lw) (inf-pow lim) (inf-pow lim) (inf-powle lw lim hww) (inf-refl (inf-pow lim))))))))
; j2-1
 (defvc inf-vc-stkeep-j2-1 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) (inf-lt lw 32)))
   (given inf-stkeep (lam g1 g2 (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))))
; j2-2
 (defvc inf-vc-stkeep-j2-2 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) (inf-lt (inf-pow lw) (inf-pow w))))
   (given inf-stkeep (lam g1 g2 (inf-lelt (inf-pow lw) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lw) (inf-pow lim) (inf-pow lim) (inf-powle lw lim hww) (inf-refl (inf-pow lim))) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; j2j-1
 (defvc inf-vc-stkeep-j2j-1 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) g3 (inf-lt hlen0 (inf-pow lw)) (inf-le hlen0 hlen0)))
   (given inf-stkeep (lam g1 g2 g3 (inf-refl hlen0))))
; j2j-2
 (defvc inf-vc-stkeep-j2j-2 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) g3 (inf-lt hlen0 (inf-pow lw)) (inf-le hlen0 (inf-pow lw))))
   (given inf-stkeep (lam g1 g2 g3 (inf-letrans hlen0 (inf-pow lw) (inf-pow lw) (inf-ltle hlen0 (inf-pow lw) g3) (inf-refl (inf-pow lw))))))
; d3-1
 (defvc inf-vc-stkeep-d3-1 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) g3 (inf-le (inf-pow lw) hlen0) (inf-lt lw 32)))
   (given inf-stkeep (lam g1 g2 g3 (inf-lelts lw 31 (inf-letrans lw lim 31 hww (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))))
; d3-2
 (defvc inf-vc-stkeep-d3-2 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) g3 (inf-le (inf-pow lw) hlen0) (inf-lt (inf-pow lw) (inf-pow w))))
   (given inf-stkeep (lam g1 g2 g3 (inf-lelt (inf-pow lw) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lw) hlen0 (inf-pow lim) g3 gh) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; j2j-3
 (defvc inf-vc-stkeep-j2j-3 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) g3 (inf-le (inf-pow lw) hlen0) (inf-le (inf-pow lw) hlen0)))
   (given inf-stkeep (lam g1 g2 g3 g3)))
; j2j-4
 (defvc inf-vc-stkeep-j2j-4 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) g2 (inf-lt (inf-pow lim) (add hlen0 op)) g3 (inf-le (inf-pow lw) hlen0) (inf-le (inf-pow lw) (inf-pow lw))))
   (given inf-stkeep (lam g1 g2 g3 (inf-refl (inf-pow lw)))))
 (defcx inf-stkeep-c2 inf-stkeep (g1 (inf-lt op (inf-pow lw))) (g2 (inf-lt (inf-pow lim) (add hlen0 op))) (kj2 nat) (a1 (inf-le kj2 hlen0)) (a2 (inf-le kj2 (inf-pow lw))) )
; m2-1
 (defvc inf-vc-stkeep-m2-1 (under inf-stkeep-c2 (inf-le kj2 hlen0))
   (given inf-stkeep-c2 a1))
; m2-2
 (defvc inf-vc-stkeep-m2-2 (under inf-stkeep-c2 (inf-le (add 0 kj2) (inf-pow lim)))
   (given inf-stkeep-c2 (inf-letrans kj2 (inf-pow lw) (inf-pow lim) a2 ((inf-powle lw lim hww)))))
; m2-3
 (defvc inf-vc-stkeep-m2-3 (under inf-stkeep-c2 (inf-le (add (natminus hlen0 kj2) kj2) (inf-pow lim)))
   (given inf-stkeep-c2 (inf-letrans (add (natminus hlen0 kj2) kj2) hlen0 (inf-pow lim) (inf-subfit hlen0 kj2 a1) gh)))
; j1j-1
 (defvc inf-vc-stkeep-j1j-1 (under inf-stkeep-c2 (inf-le (add kj2 op) (inf-pow lim)))
   (given inf-stkeep-c2 (inf-letrans (add kj2 op) (inf-pow (succ lw)) (inf-pow lim) (inf-powdbl lw kj2 op a2 (inf-ltle op (inf-pow lw) g1)) (inf-powle (succ lw) lim hs))))
; j1j-2
 (defvc inf-vc-stkeep-j1j-2 (under inf-stkeep (pi g1 (inf-lt op (inf-pow lw)) g2 (inf-le (add hlen0 op) (inf-pow lim)) (inf-le (add hlen0 op) (inf-pow lim))))
   (given inf-stkeep (lam g1 g2 g2)))
 (defcx inf-stkeep-c1 inf-stkeep (g1 (inf-lt op (inf-pow lw))) (hlenj1 nat) (a3 (inf-le (add hlenj1 op) (inf-pow lim))) )
; m3-1
 (defvc inf-vc-stkeep-m3-1 (under inf-stkeep-c1 (inf-le (add hlenj1 op) (inf-pow lim)))
   (given inf-stkeep-c1 a3))
; m3-2
 (defvc inf-vc-stkeep-m3-2 (under inf-stkeep-c1 (inf-le (add 0 op) oc))
   (given inf-stkeep-c1 gop))
; d5-1
 (defvc inf-vc-stkeep-d5-1 (under inf-stkeep-c1 (inf-lt (add hlenj1 op) (inf-pow w)))
   (given inf-stkeep-c1 (inf-lelt (add hlenj1 op) (inf-pow lim) (inf-pow w) a3 (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false))))))
 (defcx inf-stfeed (nin nat) (out0 nat) (oc0 nat) (cap0 nat) (nd0 nat) (hlen0 nat) (lim nat) (lw nat) (lh nat) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hll (inf-le lh lim)) (hww (inf-le lw lh)) (hsw (inf-le (succ lw) lh)) (hlh (inf-lt lh 31)) (hf (inf-le (succ (succ (succ lh))) lim)) (h12 (inf-le 12 lh)) (In (pi k nat nat)) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gs (inf-le bc0 63)) (op0 nat) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (last0 nat) (rem0 nat) (hclen0 nat) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) (mode0 nat) (hlit0 nat) (hdist0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (b1 (inf-le prev0 15)) (b2 (pi j nat (inf-le (Lz0 j) 15))) (a2 (pi k nat (inf-le (Cl0 k) 15))) )
; r1-1
 (defvc inf-vc-stfeed-r1-1 (under inf-stfeed (pi g1 unit (inf-le 0 nin)))
   (given inf-stfeed (lam g1 (idpath false))))
; r1-2
 (defvc inf-vc-stfeed-r1-2 (under inf-stfeed (pi g1 unit (inf-le bc0 63)))
   (given inf-stfeed (lam g1 gs)))
; r1-3
 (defvc inf-vc-stfeed-r1-3 (under inf-stfeed (pi g1 unit (inf-le 0 0)))
   (given inf-stfeed (lam g1 (idpath false))))
; r1-4
 (defvc inf-vc-stfeed-r1-4 (under inf-stfeed (pi g1 unit (pi g (inf-lt 0 0) (paths nat 0 0))))
   (given inf-stfeed (lam g1 (lam g (idpath 0)))))
; r1-5
 (defvc inf-vc-stfeed-r1-5 (under inf-stfeed (pi g1 unit (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 c1)))
; r1-6
 (defvc inf-vc-stfeed-r1-6 (under inf-stfeed (pi g1 unit (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 c2)))
; r1-7
 (defvc inf-vc-stfeed-r1-7 (under inf-stfeed (pi g1 unit (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stfeed (lam g1 c3)))
; r1-8
 (defvc inf-vc-stfeed-r1-8 (under inf-stfeed (pi g1 unit (inf-le lm0 288)))
   (given inf-stfeed (lam g1 c4)))
; r1-9
 (defvc inf-vc-stfeed-r1-9 (under inf-stfeed (pi g1 unit (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 c5)))
; r1-10
 (defvc inf-vc-stfeed-r1-10 (under inf-stfeed (pi g1 unit (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 c6)))
; r1-11
 (defvc inf-vc-stfeed-r1-11 (under inf-stfeed (pi g1 unit (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stfeed (lam g1 c7)))
; r1-12
 (defvc inf-vc-stfeed-r1-12 (under inf-stfeed (pi g1 unit (inf-le dm0 32)))
   (given inf-stfeed (lam g1 c8)))
; r1-13
 (defvc inf-vc-stfeed-r1-13 (under inf-stfeed (pi g1 unit (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 d1)))
; r1-14
 (defvc inf-vc-stfeed-r1-14 (under inf-stfeed (pi g1 unit (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 d2)))
; r1-15
 (defvc inf-vc-stfeed-r1-15 (under inf-stfeed (pi g1 unit (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-stfeed (lam g1 d3)))
; r1-16
 (defvc inf-vc-stfeed-r1-16 (under inf-stfeed (pi g1 unit (inf-le prev0 15)))
   (given inf-stfeed (lam g1 b1)))
; r1-17
 (defvc inf-vc-stfeed-r1-17 (under inf-stfeed (pi g1 unit (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-stfeed (lam g1 b2)))
; r1-18
 (defvc inf-vc-stfeed-r1-18 (under inf-stfeed (pi g1 unit (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-stfeed (lam g1 a2)))
; i2-1
 (defvc inf-vc-stfeed-i2-1 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) (inf-lt lh 32)))
   (given inf-stfeed (lam g1 (inf-lelts lh 31 (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))))
; i2-2
 (defvc inf-vc-stfeed-i2-2 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) (inf-lt (inf-pow lh) (inf-pow w))))
   (given inf-stfeed (lam g1 (inf-lelt (inf-pow lh) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim))) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; r2-1
 (defvc inf-vc-stfeed-r2-1 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (inf-le 0 nin)))
   (given inf-stfeed (lam g1 g2 (idpath false))))
; r2-2
 (defvc inf-vc-stfeed-r2-2 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (inf-le bc0 63)))
   (given inf-stfeed (lam g1 g2 gs)))
; r2-3
 (defvc inf-vc-stfeed-r2-3 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (inf-le 0 0)))
   (given inf-stfeed (lam g1 g2 (idpath false))))
; r2-4
 (defvc inf-vc-stfeed-r2-4 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (pi g (inf-lt 0 0) (paths nat 0 0))))
   (given inf-stfeed (lam g1 g2 (lam g (idpath 0)))))
; r2-5
 (defvc inf-vc-stfeed-r2-5 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 g2 c1)))
; r2-6
 (defvc inf-vc-stfeed-r2-6 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 g2 c2)))
; r2-7
 (defvc inf-vc-stfeed-r2-7 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stfeed (lam g1 g2 c3)))
; r2-8
 (defvc inf-vc-stfeed-r2-8 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (inf-le lm0 288)))
   (given inf-stfeed (lam g1 g2 c4)))
; r2-9
 (defvc inf-vc-stfeed-r2-9 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 g2 c5)))
; r2-10
 (defvc inf-vc-stfeed-r2-10 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 g2 c6)))
; r2-11
 (defvc inf-vc-stfeed-r2-11 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stfeed (lam g1 g2 c7)))
; r2-12
 (defvc inf-vc-stfeed-r2-12 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (inf-le dm0 32)))
   (given inf-stfeed (lam g1 g2 c8)))
; r2-13
 (defvc inf-vc-stfeed-r2-13 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 g2 d1)))
; r2-14
 (defvc inf-vc-stfeed-r2-14 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-stfeed (lam g1 g2 d2)))
; r2-15
 (defvc inf-vc-stfeed-r2-15 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-stfeed (lam g1 g2 d3)))
; r2-16
 (defvc inf-vc-stfeed-r2-16 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (inf-le prev0 15)))
   (given inf-stfeed (lam g1 g2 b1)))
; r2-17
 (defvc inf-vc-stfeed-r2-17 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-stfeed (lam g1 g2 b2)))
; r2-18
 (defvc inf-vc-stfeed-r2-18 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-lt (inf-pow lh) hlen0) (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-stfeed (lam g1 g2 a2)))
; j1-1
 (defvc inf-vc-stfeed-j1-1 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) (inf-lt lw 32)))
   (given inf-stfeed (lam g1 g2 (inf-lelts lw 31 (inf-letrans lw lh 31 hww (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))))
; j1-2
 (defvc inf-vc-stfeed-j1-2 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) (inf-lt (inf-pow lw) (inf-pow w))))
   (given inf-stfeed (lam g1 g2 (inf-lelt (inf-pow lw) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lw) (inf-pow lh) (inf-pow lim) (inf-powle lw lh hww) (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim)))) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; j1j-1
 (defvc inf-vc-stfeed-j1j-1 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) g3 (inf-lt hlen0 (inf-pow lw)) (inf-le hlen0 hlen0)))
   (given inf-stfeed (lam g1 g2 g3 (inf-refl hlen0))))
; j1j-2
 (defvc inf-vc-stfeed-j1j-2 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) g3 (inf-lt hlen0 (inf-pow lw)) (inf-le hlen0 (inf-pow lw))))
   (given inf-stfeed (lam g1 g2 g3 (inf-letrans hlen0 (inf-pow lw) (inf-pow lw) (inf-ltle hlen0 (inf-pow lw) g3) (inf-refl (inf-pow lw))))))
; d5-1
 (defvc inf-vc-stfeed-d5-1 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) g3 (inf-le (inf-pow lw) hlen0) (inf-lt lw 32)))
   (given inf-stfeed (lam g1 g2 g3 (inf-lelts lw 31 (inf-letrans lw lh 31 hww (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))))
; d5-2
 (defvc inf-vc-stfeed-d5-2 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) g3 (inf-le (inf-pow lw) hlen0) (inf-lt (inf-pow lw) (inf-pow w))))
   (given inf-stfeed (lam g1 g2 g3 (inf-lelt (inf-pow lw) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lw) hlen0 (inf-pow lim) g3 (inf-letrans hlen0 (inf-pow lh) (inf-pow lim) g2 (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim))))) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; j1j-3
 (defvc inf-vc-stfeed-j1j-3 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) g3 (inf-le (inf-pow lw) hlen0) (inf-le (inf-pow lw) hlen0)))
   (given inf-stfeed (lam g1 g2 g3 g3)))
; j1j-4
 (defvc inf-vc-stfeed-j1j-4 (under inf-stfeed (pi g1 (inf-lt (add nin 8) (inf-pow w)) g2 (inf-le hlen0 (inf-pow lh)) g3 (inf-le (inf-pow lw) hlen0) (inf-le (inf-pow lw) (inf-pow lw))))
   (given inf-stfeed (lam g1 g2 g3 (inf-refl (inf-pow lw)))))
 (defcx inf-stfeed-c1 inf-stfeed (g1 (inf-lt (add nin 8) (inf-pow w))) (g2 (inf-le hlen0 (inf-pow lh))) (ndj1 nat) (n1 (inf-le ndj1 hlen0)) (n2 (inf-le ndj1 (inf-pow lw))) )
; v1-1
 (defvc inf-vc-stfeed-v1-1 (under inf-stfeed-c1 (inf-le ndj1 hlen0))
   (given inf-stfeed-c1 n1))
; v1-2
 (defvc inf-vc-stfeed-v1-2 (under inf-stfeed-c1 (inf-le (add (natminus hlen0 ndj1) ndj1) (inf-pow lh)))
   (given inf-stfeed-c1 (inf-letrans (add (natminus hlen0 ndj1) ndj1) hlen0 (inf-pow lh) (inf-subfit hlen0 ndj1 n1) g2)))
; j2-1
 (defvc inf-vc-stfeed-j2-1 (under inf-stfeed-c1 (inf-lt lh 32))
   (given inf-stfeed-c1 (inf-lelts lh 31 (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))
; j2-2
 (defvc inf-vc-stfeed-j2-2 (under inf-stfeed-c1 (inf-lt (inf-pow lh) (inf-pow w)))
   (given inf-stfeed-c1 (inf-lelt (inf-pow lh) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim))) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false))))))
; d8-1
 (defvc inf-vc-stfeed-d8-1 (under inf-stfeed-c1 (pi g4 (inf-le nin (inf-pow lh)) (inf-lt (add nin nin) (inf-pow w))))
   (given inf-stfeed-c1 (lam g4 (inf-fitlim w lim nin nin gw hm (inf-letrans nin (inf-pow lh) (inf-pow lim) g4 (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim)))) (inf-letrans nin (inf-pow lh) (inf-pow lim) g4 (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim))))))))
; d8-2
 (defvc inf-vc-stfeed-d8-2 (under inf-stfeed-c1 (pi g4 (inf-le nin (inf-pow lh)) (inf-lt (add (add nin nin) (add nin nin)) (inf-pow w))))
   (given inf-stfeed-c1 (lam g4 (inf-lelt ((add (add nin nin) (add nin nin))) (inf-pow lim) (inf-pow w) ((inf-four lh lim nin g4 hf)) ((inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false))))))))
; d8-3
 (defvc inf-vc-stfeed-d8-3 (under inf-stfeed-c1 (pi g4 (inf-le nin (inf-pow lh)) (inf-lt 12 32)))
   (given inf-stfeed-c1 (lam g4 (idpath true))))
; d8-4
 (defvc inf-vc-stfeed-d8-4 (under inf-stfeed-c1 (pi g4 (inf-le nin (inf-pow lh)) (inf-lt (inf-pow 12) (inf-pow w))))
   (given inf-stfeed-c1 (lam g4 (inf-wpow w 12 gw (idpath true)))))
; d8-5
 (defvc inf-vc-stfeed-d8-5 (under inf-stfeed-c1 (pi g4 (inf-le nin (inf-pow lh)) (inf-lt (add (add (add nin nin) (add nin nin)) (inf-pow 12)) (inf-pow w))))
   (given inf-stfeed-c1 (lam g4 (inf-fitlim w lim ((add (add nin nin) (add nin nin))) (inf-pow 12) gw hm ((inf-four lh lim nin g4 hf)) (inf-powle 12 lim (inf-letrans 12 lh lim h12 hll))))))
; j2j-1
 (defvc inf-vc-stfeed-j2j-1 (under inf-stfeed-c1 (pi g4 (inf-le nin (inf-pow lh)) (inf-le (add (add (add nin nin) (add nin nin)) (inf-pow 12)) (inf-pow lim))))
   (given inf-stfeed-c1 (lam g4 (inf-fourp lh lim nin (inf-pow 12) g4 (inf-powle 12 lh h12) hf))))
; j2j-2
 (defvc inf-vc-stfeed-j2j-2 (under inf-stfeed-c1 (pi g4 (inf-le nin (inf-pow lh)) (inf-lt 0 (add (add (add nin nin) (add nin nin)) (inf-pow 12)))))
   (given inf-stfeed-c1 (lam g4 (inf-lttrans 0 (inf-pow 12) (add ((add (add nin nin) (add nin nin))) (inf-pow 12)) (inf-powpos 12) (inf-leaddl (inf-pow 12) ((add (add nin nin) (add nin nin))))))))
; d10-1
 (defvc inf-vc-stfeed-d10-1 (under inf-stfeed-c1 (pi g4 (inf-lt (inf-pow lh) nin) (inf-lt lh 32)))
   (given inf-stfeed-c1 (lam g4 (inf-lelts lh 31 (inf-letrans lh lim 31 hll (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))))
; d10-2
 (defvc inf-vc-stfeed-d10-2 (under inf-stfeed-c1 (pi g4 (inf-lt (inf-pow lh) nin) (inf-lt (inf-pow lh) (inf-pow w))))
   (given inf-stfeed-c1 (lam g4 (inf-lelt (inf-pow lh) (inf-pow lim) (inf-pow w) (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim))) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; j2j-3
 (defvc inf-vc-stfeed-j2j-3 (under inf-stfeed-c1 (pi g4 (inf-lt (inf-pow lh) nin) (inf-le (inf-pow lh) (inf-pow lim))))
   (given inf-stfeed-c1 (lam g4 (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim))))))
; j2j-4
 (defvc inf-vc-stfeed-j2j-4 (under inf-stfeed-c1 (pi g4 (inf-lt (inf-pow lh) nin) (inf-lt 0 (inf-pow lh))))
   (given inf-stfeed-c1 (lam g4 (inf-powpos lh))))
 (defcx inf-stfeed-c2 inf-stfeed-c1 (capj2 nat) (n3 (inf-le capj2 (inf-pow lim))) (n5 (inf-lt 0 capj2)) )
; r3-1
 (defvc inf-vc-stfeed-r3-1 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (inf-le 0 nin)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 (idpath false))))
; r3-2
 (defvc inf-vc-stfeed-r3-2 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (inf-le bc0 63)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 gs)))
; r3-3
 (defvc inf-vc-stfeed-r3-3 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (inf-le 0 capj2)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 (idpath false))))
; r3-4
 (defvc inf-vc-stfeed-r3-4 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 g6)))
; r3-5
 (defvc inf-vc-stfeed-r3-5 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c1)))
; r3-6
 (defvc inf-vc-stfeed-r3-6 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c2)))
; r3-7
 (defvc inf-vc-stfeed-r3-7 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c3)))
; r3-8
 (defvc inf-vc-stfeed-r3-8 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (inf-le lm0 288)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c4)))
; r3-9
 (defvc inf-vc-stfeed-r3-9 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c5)))
; r3-10
 (defvc inf-vc-stfeed-r3-10 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c6)))
; r3-11
 (defvc inf-vc-stfeed-r3-11 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c7)))
; r3-12
 (defvc inf-vc-stfeed-r3-12 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (inf-le dm0 32)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c8)))
; r3-13
 (defvc inf-vc-stfeed-r3-13 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 d1)))
; r3-14
 (defvc inf-vc-stfeed-r3-14 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 d2)))
; r3-15
 (defvc inf-vc-stfeed-r3-15 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 d3)))
; r3-16
 (defvc inf-vc-stfeed-r3-16 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (inf-le prev0 15)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 b1)))
; r3-17
 (defvc inf-vc-stfeed-r3-17 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 b2)))
; r3-18
 (defvc inf-vc-stfeed-r3-18 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (paths nat outn4 0) (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 a2)))
; w1e-1
 (defvc inf-vc-stfeed-w1e-1 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le 0 nin)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 (idpath false))))
; w1e-2
 (defvc inf-vc-stfeed-w1e-2 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le bc0 63)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 gs)))
; w1e-3
 (defvc inf-vc-stfeed-w1e-3 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-bits-inv (add cons0 bc0) 0 cons0 bc0)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 (natplusr0 (add cons0 bc0)))))
; w1e-4
 (defvc inf-vc-stfeed-w1e-4 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le cons0 cons0)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 (inf-refl cons0))))
; w1e-5
 (defvc inf-vc-stfeed-w1e-5 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le 0 capj2)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 (idpath false))))
; w1e-6
 (defvc inf-vc-stfeed-w1e-6 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le capj2 (inf-pow lim))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 n3)))
; w1e-7
 (defvc inf-vc-stfeed-w1e-7 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-lt 0 outn4)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 g7)))
; w1e-8
 (defvc inf-vc-stfeed-w1e-8 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 g6)))
; w1e-9
 (defvc inf-vc-stfeed-w1e-9 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-lt 0 capj2)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 n5)))
; w1e-10
 (defvc inf-vc-stfeed-w1e-10 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (pi k nat (inf-lt (Lc0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c1)))
; w1e-11
 (defvc inf-vc-stfeed-w1e-11 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (pi k nat (inf-lt (Ls0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c2)))
; w1e-12
 (defvc inf-vc-stfeed-w1e-12 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le (inf-sum Lc0 15 1) lm0)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c3)))
; w1e-13
 (defvc inf-vc-stfeed-w1e-13 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le lm0 288)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c4)))
; w1e-14
 (defvc inf-vc-stfeed-w1e-14 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (pi k nat (inf-lt (Dc0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c5)))
; w1e-15
 (defvc inf-vc-stfeed-w1e-15 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (pi k nat (inf-lt (Ds0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c6)))
; w1e-16
 (defvc inf-vc-stfeed-w1e-16 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le (inf-sum Dc0 15 1) dm0)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c7)))
; w1e-17
 (defvc inf-vc-stfeed-w1e-17 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le dm0 32)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 c8)))
; w1e-18
 (defvc inf-vc-stfeed-w1e-18 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (pi k nat (inf-lt (Cc0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 d1)))
; w1e-19
 (defvc inf-vc-stfeed-w1e-19 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (pi k nat (inf-lt (Cs0 k) (inf-pow h)))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 d2)))
; w1e-20
 (defvc inf-vc-stfeed-w1e-20 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le (inf-sum Cc0 15 1) 19)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 d3)))
; w1e-21
 (defvc inf-vc-stfeed-w1e-21 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (inf-le prev0 15)))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 b1)))
; w1e-22
 (defvc inf-vc-stfeed-w1e-22 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (pi j nat (inf-le (Lz0 j) 15))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 b2)))
; w1e-23
 (defvc inf-vc-stfeed-w1e-23 (under inf-stfeed-c2 (pi outn4 nat ocn4 nat g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2)) g7 (inf-lt 0 outn4) (pi k nat (inf-le (Cl0 k) 15))))
   (given inf-stfeed-c2 (lam outn4 ocn4 g6 g7 a2)))
 (defcx inf-stfeed-c2-w1 inf-stfeed-c2 (outn4 nat) (ocn4 nat) (g6 (pi g (inf-lt 0 outn4) (paths nat ocn4 capj2))) (g7 (inf-lt 0 outn4)) (out nat) (oc nat) (cap nat) (op nat) (ip nat) (bc nat) (bb nat) (cons nat) (Lc (pi j nat nat)) (Ls (pi j nat nat)) (Lt (pi j nat nat)) (Dc (pi j nat nat)) (Ds (pi j nat nat)) (Dt (pi j nat nat)) (lm nat) (dm nat) (Cl (pi j nat nat)) (Lz (pi j nat nat)) (Cs (pi j nat nat)) (Ct (pi j nat nat)) (Cc (pi j nat nat)) (last nat) (rem nat) (hclen nat) (i nat) (prev nat) (stage nat) (sy nat) (len nat) (dist nat) (mode nat) (hlit nat) (hdist nat) (r1 (inf-le ip nin)) (r3 (inf-le bc 63)) (r4 (inf-bits-inv (add cons0 bc0) ip cons bc)) (r5 (inf-le cons0 cons)) (o2 (inf-le op cap)) (k1 (inf-le cap (inf-pow lim))) (k2 (inf-lt 0 out)) (k3 (pi g (inf-lt 0 out) (paths nat oc cap))) (k6 (inf-lt 0 cap)) (c1 (pi k nat (inf-lt (Lc k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc 15 1) lm)) (c4 (inf-le lm 288)) (c5 (pi k nat (inf-lt (Dc k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc 15 1) dm)) (c8 (inf-le dm 32)) (d1 (pi k nat (inf-lt (Cc k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc 15 1) 19)) (b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))) (a2 (pi k nat (inf-le (Cl k) 15))) )
; c1-1
 (defvc inf-vc-stfeed-c1-1 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le 32 w)))
   (given inf-stfeed-c2-w1 (lam w1 gw)))
; c1-2
 (defvc inf-vc-stfeed-c1-2 (under inf-stfeed-c2-w1 (pi w1 unit (inf-lt (add nin 8) (inf-pow w))))
   (given inf-stfeed-c2-w1 (lam w1 g1)))
; c1-3
 (defvc inf-vc-stfeed-c1-3 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le ip nin)))
   (given inf-stfeed-c2-w1 (lam w1 r1)))
; c1-4
 (defvc inf-vc-stfeed-c1-4 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le bc 63)))
   (given inf-stfeed-c2-w1 (lam w1 r3)))
; c1-5
 (defvc inf-vc-stfeed-c1-5 (under inf-stfeed-c2-w1 (pi w1 unit (inf-bits-inv (add cons0 bc0) ip cons bc)))
   (given inf-stfeed-c2-w1 (lam w1 r4)))
; c1-6
 (defvc inf-vc-stfeed-c1-6 (under inf-stfeed-c2-w1 (pi w1 unit (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-stfeed-c2-w1 (lam w1 k3)))
; c1-7
 (defvc inf-vc-stfeed-c1-7 (under inf-stfeed-c2-w1 (pi w1 unit (inf-lt (add cap 8) (inf-pow w))))
   (given inf-stfeed-c2-w1 (lam w1 (inf-fitlim w lim cap 8 gw hm k1 (inf-letrans 8 (inf-pow 9) (inf-pow lim) (idpath false) (inf-letrans (inf-pow 9) (inf-pow lim) (inf-pow lim) (inf-powle 9 lim (inf-letrans 9 19 lim (idpath false) hl)) (inf-refl (inf-pow lim))))))))
; c1-8
 (defvc inf-vc-stfeed-c1-8 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le op cap)))
   (given inf-stfeed-c2-w1 (lam w1 o2)))
; c1-9
 (defvc inf-vc-stfeed-c1-9 (under inf-stfeed-c2-w1 (pi w1 unit (inf-lt (add cap ndj1) (inf-pow w))))
   (given inf-stfeed-c2-w1 (lam w1 (inf-fitlim w lim cap ndj1 gw hm k1 (inf-letrans ndj1 (inf-pow lw) (inf-pow lim) n2 (inf-letrans (inf-pow lw) (inf-pow lh) (inf-pow lim) (inf-powle lw lh hww) (inf-letrans (inf-pow lh) (inf-pow lim) (inf-pow lim) (inf-powle lh lim hll) (inf-refl (inf-pow lim)))))))))
; c1-10
 (defvc inf-vc-stfeed-c1-10 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le h 16)))
   (given inf-stfeed-c2-w1 (lam w1 gh)))
; c1-11
 (defvc inf-vc-stfeed-c1-11 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-stfeed-c2-w1 (lam w1 gq)))
; c1-12
 (defvc inf-vc-stfeed-c1-12 (under inf-stfeed-c2-w1 (pi w1 unit (inf-lt 320 q)))
   (given inf-stfeed-c2-w1 (lam w1 gq2)))
; c1-13
 (defvc inf-vc-stfeed-c1-13 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-stfeed-c2-w1 (lam w1 gk)))
; c1-14
 (defvc inf-vc-stfeed-c1-14 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le LROOT 15)))
   (given inf-stfeed-c2-w1 (lam w1 gl)))
; c1-15
 (defvc inf-vc-stfeed-c1-15 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le DROOT 15)))
   (given inf-stfeed-c2-w1 (lam w1 gd)))
; c1-16
 (defvc inf-vc-stfeed-c1-16 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le CROOT 15)))
   (given inf-stfeed-c2-w1 (lam w1 gc)))
; c1-17
 (defvc inf-vc-stfeed-c1-17 (under inf-stfeed-c2-w1 (pi w1 unit (inf-lt (add cap 266) (inf-pow w))))
   (given inf-stfeed-c2-w1 (lam w1 (inf-fitlim w lim cap 266 gw hm k1 (inf-letrans 266 (inf-pow 9) (inf-pow lim) (idpath false) (inf-letrans (inf-pow 9) (inf-pow lim) (inf-pow lim) (inf-powle 9 lim (inf-letrans 9 19 lim (idpath false) hl)) (inf-refl (inf-pow lim))))))))
; c1-18
 (defvc inf-vc-stfeed-c1-18 (under inf-stfeed-c2-w1 (pi w1 unit (inf-lt 0 out)))
   (given inf-stfeed-c2-w1 (lam w1 k2)))
; c1-19
 (defvc inf-vc-stfeed-c1-19 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))))
   (given inf-stfeed-c2-w1 (lam w1 hord)))
; c1-20
 (defvc inf-vc-stfeed-c1-20 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))))
   (given inf-stfeed-c2-w1 (lam w1 hle)))
; c1-21
 (defvc inf-vc-stfeed-c1-21 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))))
   (given inf-stfeed-c2-w1 (lam w1 hlb)))
; c1-22
 (defvc inf-vc-stfeed-c1-22 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))))
   (given inf-stfeed-c2-w1 (lam w1 hlc)))
; c1-23
 (defvc inf-vc-stfeed-c1-23 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat g (inf-lt k 30) (inf-le (De k) 13))))
   (given inf-stfeed-c2-w1 (lam w1 hde)))
; c1-24
 (defvc inf-vc-stfeed-c1-24 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))))
   (given inf-stfeed-c2-w1 (lam w1 hdb)))
; c1-25
 (defvc inf-vc-stfeed-c1-25 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat (inf-lt (Lc k) (inf-pow h)))))
   (given inf-stfeed-c2-w1 (lam w1 c1)))
; c1-26
 (defvc inf-vc-stfeed-c1-26 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat (inf-lt (Ls k) (inf-pow h)))))
   (given inf-stfeed-c2-w1 (lam w1 c2)))
; c1-27
 (defvc inf-vc-stfeed-c1-27 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le (inf-sum Lc 15 1) lm)))
   (given inf-stfeed-c2-w1 (lam w1 c3)))
; c1-28
 (defvc inf-vc-stfeed-c1-28 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le lm 288)))
   (given inf-stfeed-c2-w1 (lam w1 c4)))
; c1-29
 (defvc inf-vc-stfeed-c1-29 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat (inf-lt (Dc k) (inf-pow h)))))
   (given inf-stfeed-c2-w1 (lam w1 c5)))
; c1-30
 (defvc inf-vc-stfeed-c1-30 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat (inf-lt (Ds k) (inf-pow h)))))
   (given inf-stfeed-c2-w1 (lam w1 c6)))
; c1-31
 (defvc inf-vc-stfeed-c1-31 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le (inf-sum Dc 15 1) dm)))
   (given inf-stfeed-c2-w1 (lam w1 c7)))
; c1-32
 (defvc inf-vc-stfeed-c1-32 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le dm 32)))
   (given inf-stfeed-c2-w1 (lam w1 c8)))
; c1-33
 (defvc inf-vc-stfeed-c1-33 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat (inf-lt (Cc k) (inf-pow h)))))
   (given inf-stfeed-c2-w1 (lam w1 d1)))
; c1-34
 (defvc inf-vc-stfeed-c1-34 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat (inf-lt (Cs k) (inf-pow h)))))
   (given inf-stfeed-c2-w1 (lam w1 d2)))
; c1-35
 (defvc inf-vc-stfeed-c1-35 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le (inf-sum Cc 15 1) 19)))
   (given inf-stfeed-c2-w1 (lam w1 d3)))
; c1-36
 (defvc inf-vc-stfeed-c1-36 (under inf-stfeed-c2-w1 (pi w1 unit (inf-le prev 15)))
   (given inf-stfeed-c2-w1 (lam w1 b1)))
; c1-37
 (defvc inf-vc-stfeed-c1-37 (under inf-stfeed-c2-w1 (pi w1 unit (pi j nat (inf-le (Lz j) 15))))
   (given inf-stfeed-c2-w1 (lam w1 b2)))
; c1-38
 (defvc inf-vc-stfeed-c1-38 (under inf-stfeed-c2-w1 (pi w1 unit (pi k nat (inf-le (Cl k) 15))))
   (given inf-stfeed-c2-w1 (lam w1 a2)))
 (defcx inf-stfeed-c3 inf-stfeed-c2-w1 (w1 unit) (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (opc1 nat) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (Clc1 (pi j nat nat)) (Lzc1 (pi j nat nat)) (Csc1 (pi j nat nat)) (Ctc1 (pi j nat nat)) (Ccc1 (pi j nat nat)) (lastc1 nat) (remc1 nat) (hclenc1 nat) (ic1 nat) (prevc1 nat) (stagec1 nat) (syc1 nat) (lenc1 nat) (distc1 nat) (modec1 nat) (hlitc1 nat) (hdistc1 nat) (xc1 nat) (c1e1 (inf-le ipc1 nin)) (c1e3 (inf-le bcc1 63)) (c1e4 (inf-bits-inv (add cons0 bc0) ipc1 consc1 bcc1)) (c1e5 (inf-le cons consc1)) (c1e8 (inf-le opc1 cap)) (c1e9 (inf-le op opc1)) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) (c1d1 (pi k nat (inf-lt (Ccc1 k) (inf-pow h)))) (c1d2 (pi k nat (inf-lt (Csc1 k) (inf-pow h)))) (c1d3 (inf-le (inf-sum Ccc1 15 1) 19)) (c1b1 (inf-le prevc1 15)) (c1b2 (pi j nat (inf-le (Lzc1 j) 15))) (c1a2 (pi k nat (inf-le (Clc1 k) 15))) )
; c2-1
 (defvc inf-vc-stfeed-c2-1 (under inf-stfeed-c3 (pi g9 unit (inf-le 32 w)))
   (given inf-stfeed-c3 (lam g9 gw)))
; c2-2
 (defvc inf-vc-stfeed-c2-2 (under inf-stfeed-c3 (pi g9 unit (inf-le opc1 oc)))
   (given inf-stfeed-c3 (lam g9 ((inf-letl opc1 cap oc (pathsinv0 nat oc cap (k3 k2)) c1e8)))))
; c2-3
 (defvc inf-vc-stfeed-c2-3 (under inf-stfeed-c3 (pi g9 unit (inf-le lw lh)))
   (given inf-stfeed-c3 (lam g9 hww)))
; c2-4
 (defvc inf-vc-stfeed-c2-4 (under inf-stfeed-c3 (pi g9 unit (inf-le (succ lw) lh)))
   (given inf-stfeed-c3 (lam g9 hsw)))
; c2-5
 (defvc inf-vc-stfeed-c2-5 (under inf-stfeed-c3 (pi g9 unit (inf-lt lh 31)))
   (given inf-stfeed-c3 (lam g9 hlh)))
; c2-6
 (defvc inf-vc-stfeed-c2-6 (under inf-stfeed-c3 (pi g9 unit (inf-le hlen0 (inf-pow lh))))
   (given inf-stfeed-c3 (lam g9 g2)))
 (defcx inf-stfeed-c7 inf-stfeed-c3 (g9 unit) (hlenc2 nat) )
; r4-1
 (defvc inf-vc-stfeed-r4-1 (under inf-stfeed-c7 (inf-le ipc1 nin))
   (given inf-stfeed-c7 c1e1))
; r4-2
 (defvc inf-vc-stfeed-r4-2 (under inf-stfeed-c7 (inf-le bcc1 63))
   (given inf-stfeed-c7 c1e3))
; r4-3
 (defvc inf-vc-stfeed-r4-3 (under inf-stfeed-c7 (inf-le opc1 cap))
   (given inf-stfeed-c7 c1e8))
; r4-4
 (defvc inf-vc-stfeed-r4-4 (under inf-stfeed-c7 (pi g (inf-lt 0 out) (paths nat oc cap)))
   (given inf-stfeed-c7 k3))
; r4-5
 (defvc inf-vc-stfeed-r4-5 (under inf-stfeed-c7 (pi k nat (inf-lt (Lcc1 k) (inf-pow h))))
   (given inf-stfeed-c7 c1c1))
; r4-6
 (defvc inf-vc-stfeed-r4-6 (under inf-stfeed-c7 (pi k nat (inf-lt (Lsc1 k) (inf-pow h))))
   (given inf-stfeed-c7 c1c2))
; r4-7
 (defvc inf-vc-stfeed-r4-7 (under inf-stfeed-c7 (inf-le (inf-sum Lcc1 15 1) lmc1))
   (given inf-stfeed-c7 c1c3))
; r4-8
 (defvc inf-vc-stfeed-r4-8 (under inf-stfeed-c7 (inf-le lmc1 288))
   (given inf-stfeed-c7 c1c4))
; r4-9
 (defvc inf-vc-stfeed-r4-9 (under inf-stfeed-c7 (pi k nat (inf-lt (Dcc1 k) (inf-pow h))))
   (given inf-stfeed-c7 c1c5))
; r4-10
 (defvc inf-vc-stfeed-r4-10 (under inf-stfeed-c7 (pi k nat (inf-lt (Dsc1 k) (inf-pow h))))
   (given inf-stfeed-c7 c1c6))
; r4-11
 (defvc inf-vc-stfeed-r4-11 (under inf-stfeed-c7 (inf-le (inf-sum Dcc1 15 1) dmc1))
   (given inf-stfeed-c7 c1c7))
; r4-12
 (defvc inf-vc-stfeed-r4-12 (under inf-stfeed-c7 (inf-le dmc1 32))
   (given inf-stfeed-c7 c1c8))
; r4-13
 (defvc inf-vc-stfeed-r4-13 (under inf-stfeed-c7 (pi k nat (inf-lt (Ccc1 k) (inf-pow h))))
   (given inf-stfeed-c7 c1d1))
; r4-14
 (defvc inf-vc-stfeed-r4-14 (under inf-stfeed-c7 (pi k nat (inf-lt (Csc1 k) (inf-pow h))))
   (given inf-stfeed-c7 c1d2))
; r4-15
 (defvc inf-vc-stfeed-r4-15 (under inf-stfeed-c7 (inf-le (inf-sum Ccc1 15 1) 19))
   (given inf-stfeed-c7 c1d3))
; r4-16
 (defvc inf-vc-stfeed-r4-16 (under inf-stfeed-c7 (inf-le prevc1 15))
   (given inf-stfeed-c7 c1b1))
; r4-17
 (defvc inf-vc-stfeed-r4-17 (under inf-stfeed-c7 (pi j nat (inf-le (Lzc1 j) 15)))
   (given inf-stfeed-c7 c1b2))
; r4-18
 (defvc inf-vc-stfeed-r4-18 (under inf-stfeed-c7 (pi k nat (inf-le (Clc1 k) 15)))
   (given inf-stfeed-c7 c1a2))
; i6-1
 (defvc inf-vc-stfeed-i6-1 (under inf-stfeed-c3 (pi g9 unit (inf-lt lim 32)))
   (given inf-stfeed-c3 (lam g9 (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))
; i6-2
 (defvc inf-vc-stfeed-i6-2 (under inf-stfeed-c3 (pi g9 unit (inf-lt (inf-pow lim) (inf-pow w))))
   (given inf-stfeed-c3 (lam g9 (inf-lelt (inf-pow lim) (inf-pow lim) (inf-pow w) (inf-refl (inf-pow lim)) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; c2-7
 (defvc inf-vc-stfeed-c2-7 (under inf-stfeed-c3 (pi g9 unit g10 (inf-le (inf-pow lim) cap) (inf-le 32 w)))
   (given inf-stfeed-c3 (lam g9 g10 gw)))
; c2-8
 (defvc inf-vc-stfeed-c2-8 (under inf-stfeed-c3 (pi g9 unit g10 (inf-le (inf-pow lim) cap) (inf-le opc1 oc)))
   (given inf-stfeed-c3 (lam g9 g10 ((inf-letl opc1 cap oc (pathsinv0 nat oc cap (k3 k2)) c1e8)))))
; c2-9
 (defvc inf-vc-stfeed-c2-9 (under inf-stfeed-c3 (pi g9 unit g10 (inf-le (inf-pow lim) cap) (inf-le lw lh)))
   (given inf-stfeed-c3 (lam g9 g10 hww)))
; c2-10
 (defvc inf-vc-stfeed-c2-10 (under inf-stfeed-c3 (pi g9 unit g10 (inf-le (inf-pow lim) cap) (inf-le (succ lw) lh)))
   (given inf-stfeed-c3 (lam g9 g10 hsw)))
; c2-11
 (defvc inf-vc-stfeed-c2-11 (under inf-stfeed-c3 (pi g9 unit g10 (inf-le (inf-pow lim) cap) (inf-lt lh 31)))
   (given inf-stfeed-c3 (lam g9 g10 hlh)))
; c2-12
 (defvc inf-vc-stfeed-c2-12 (under inf-stfeed-c3 (pi g9 unit g10 (inf-le (inf-pow lim) cap) (inf-le hlen0 (inf-pow lh))))
   (given inf-stfeed-c3 (lam g9 g10 g2)))
 (defcx inf-stfeed-c6 inf-stfeed-c3 (g9 unit) (g10 (inf-le (inf-pow lim) cap)) (hlenc2 nat) )
; r4-19
 (defvc inf-vc-stfeed-r4-19 (under inf-stfeed-c6 (inf-le ipc1 nin))
   (given inf-stfeed-c6 c1e1))
; r4-20
 (defvc inf-vc-stfeed-r4-20 (under inf-stfeed-c6 (inf-le bcc1 63))
   (given inf-stfeed-c6 c1e3))
; r4-21
 (defvc inf-vc-stfeed-r4-21 (under inf-stfeed-c6 (inf-le opc1 cap))
   (given inf-stfeed-c6 c1e8))
; r4-22
 (defvc inf-vc-stfeed-r4-22 (under inf-stfeed-c6 (pi g (inf-lt 0 out) (paths nat oc cap)))
   (given inf-stfeed-c6 k3))
; r4-23
 (defvc inf-vc-stfeed-r4-23 (under inf-stfeed-c6 (pi k nat (inf-lt (Lcc1 k) (inf-pow h))))
   (given inf-stfeed-c6 c1c1))
; r4-24
 (defvc inf-vc-stfeed-r4-24 (under inf-stfeed-c6 (pi k nat (inf-lt (Lsc1 k) (inf-pow h))))
   (given inf-stfeed-c6 c1c2))
; r4-25
 (defvc inf-vc-stfeed-r4-25 (under inf-stfeed-c6 (inf-le (inf-sum Lcc1 15 1) lmc1))
   (given inf-stfeed-c6 c1c3))
; r4-26
 (defvc inf-vc-stfeed-r4-26 (under inf-stfeed-c6 (inf-le lmc1 288))
   (given inf-stfeed-c6 c1c4))
; r4-27
 (defvc inf-vc-stfeed-r4-27 (under inf-stfeed-c6 (pi k nat (inf-lt (Dcc1 k) (inf-pow h))))
   (given inf-stfeed-c6 c1c5))
; r4-28
 (defvc inf-vc-stfeed-r4-28 (under inf-stfeed-c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h))))
   (given inf-stfeed-c6 c1c6))
; r4-29
 (defvc inf-vc-stfeed-r4-29 (under inf-stfeed-c6 (inf-le (inf-sum Dcc1 15 1) dmc1))
   (given inf-stfeed-c6 c1c7))
; r4-30
 (defvc inf-vc-stfeed-r4-30 (under inf-stfeed-c6 (inf-le dmc1 32))
   (given inf-stfeed-c6 c1c8))
; r4-31
 (defvc inf-vc-stfeed-r4-31 (under inf-stfeed-c6 (pi k nat (inf-lt (Ccc1 k) (inf-pow h))))
   (given inf-stfeed-c6 c1d1))
; r4-32
 (defvc inf-vc-stfeed-r4-32 (under inf-stfeed-c6 (pi k nat (inf-lt (Csc1 k) (inf-pow h))))
   (given inf-stfeed-c6 c1d2))
; r4-33
 (defvc inf-vc-stfeed-r4-33 (under inf-stfeed-c6 (inf-le (inf-sum Ccc1 15 1) 19))
   (given inf-stfeed-c6 c1d3))
; r4-34
 (defvc inf-vc-stfeed-r4-34 (under inf-stfeed-c6 (inf-le prevc1 15))
   (given inf-stfeed-c6 c1b1))
; r4-35
 (defvc inf-vc-stfeed-r4-35 (under inf-stfeed-c6 (pi j nat (inf-le (Lzc1 j) 15)))
   (given inf-stfeed-c6 c1b2))
; r4-36
 (defvc inf-vc-stfeed-r4-36 (under inf-stfeed-c6 (pi k nat (inf-le (Clc1 k) 15)))
   (given inf-stfeed-c6 c1a2))
; j3-1
 (defvc inf-vc-stfeed-j3-1 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) (inf-lt lim 32)))
   (given inf-stfeed-c3 (lam g9 g10 (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))
; j3-2
 (defvc inf-vc-stfeed-j3-2 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) (inf-lt (inf-pow lim) (inf-pow w))))
   (given inf-stfeed-c3 (lam g9 g10 (inf-lelt (inf-pow lim) (inf-pow lim) (inf-pow w) (inf-refl (inf-pow lim)) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; j3-3
 (defvc inf-vc-stfeed-j3-3 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) (inf-le cap (inf-pow lim))))
   (given inf-stfeed-c3 (lam g9 g10 k1)))
; d11-1
 (defvc inf-vc-stfeed-d11-1 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-lt cap (natminus (inf-pow lim) cap)) (inf-lt (add cap cap) (inf-pow w))))
   (given inf-stfeed-c3 (lam g9 g10 g11 (inf-lelt (add cap cap) (inf-pow lim) (inf-pow w) ((inf-roomle cap (inf-pow lim) cap (inf-ltle cap (natminus (inf-pow lim) cap) g11) k1)) ((inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false))))))))
; j3j-1
 (defvc inf-vc-stfeed-j3j-1 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-lt cap (natminus (inf-pow lim) cap)) (inf-lt cap (add cap cap))))
   (given inf-stfeed-c3 (lam g9 g10 g11 (inf-ltdbl cap k6))))
; j3j-2
 (defvc inf-vc-stfeed-j3j-2 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-lt cap (natminus (inf-pow lim) cap)) (inf-le (add cap cap) (inf-pow lim))))
   (given inf-stfeed-c3 (lam g9 g10 g11 ((inf-roomle cap (inf-pow lim) cap (inf-ltle cap (natminus (inf-pow lim) cap) g11) k1)))))
; d12-1
 (defvc inf-vc-stfeed-d12-1 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-le (natminus (inf-pow lim) cap) cap) (inf-lt lim 32)))
   (given inf-stfeed-c3 (lam g9 g10 g11 (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))
; d12-2
 (defvc inf-vc-stfeed-d12-2 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-le (natminus (inf-pow lim) cap) cap) (inf-lt (inf-pow lim) (inf-pow w))))
   (given inf-stfeed-c3 (lam g9 g10 g11 (inf-lelt (inf-pow lim) (inf-pow lim) (inf-pow w) (inf-refl (inf-pow lim)) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; j3j-3
 (defvc inf-vc-stfeed-j3j-3 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-le (natminus (inf-pow lim) cap) cap) (inf-lt cap (inf-pow lim))))
   (given inf-stfeed-c3 (lam g9 g10 g11 g10)))
; j3j-4
 (defvc inf-vc-stfeed-j3j-4 (under inf-stfeed-c3 (pi g9 unit g10 (inf-lt cap (inf-pow lim)) g11 (inf-le (natminus (inf-pow lim) cap) cap) (inf-le (inf-pow lim) (inf-pow lim))))
   (given inf-stfeed-c3 (lam g9 g10 g11 (inf-refl (inf-pow lim)))))
 (defcx inf-stfeed-c4 inf-stfeed-c3 (g9 unit) (g10 (inf-lt cap (inf-pow lim))) (ncapj3 nat) (k4 (inf-lt cap ncapj3)) (k5 (inf-le ncapj3 (inf-pow lim))) )
; c2-13
 (defvc inf-vc-stfeed-c2-13 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (paths nat nbn5 0) (inf-le 32 w)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 gw)))
; c2-14
 (defvc inf-vc-stfeed-c2-14 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (paths nat nbn5 0) (inf-le opc1 oc)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 ((inf-letl opc1 cap oc (pathsinv0 nat oc cap (k3 k2)) c1e8)))))
; c2-15
 (defvc inf-vc-stfeed-c2-15 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (paths nat nbn5 0) (inf-le lw lh)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 hww)))
; c2-16
 (defvc inf-vc-stfeed-c2-16 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (paths nat nbn5 0) (inf-le (succ lw) lh)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 hsw)))
; c2-17
 (defvc inf-vc-stfeed-c2-17 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (paths nat nbn5 0) (inf-lt lh 31)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 hlh)))
; c2-18
 (defvc inf-vc-stfeed-c2-18 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (paths nat nbn5 0) (inf-le hlen0 (inf-pow lh))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 g2)))
 (defcx inf-stfeed-c5 inf-stfeed-c4 (nbn5 nat) (nocn5 nat) (g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3))) (g13 (paths nat nbn5 0)) (hlenc2 nat) )
; r4-37
 (defvc inf-vc-stfeed-r4-37 (under inf-stfeed-c5 (inf-le ipc1 nin))
   (given inf-stfeed-c5 c1e1))
; r4-38
 (defvc inf-vc-stfeed-r4-38 (under inf-stfeed-c5 (inf-le bcc1 63))
   (given inf-stfeed-c5 c1e3))
; r4-39
 (defvc inf-vc-stfeed-r4-39 (under inf-stfeed-c5 (inf-le opc1 cap))
   (given inf-stfeed-c5 c1e8))
; r4-40
 (defvc inf-vc-stfeed-r4-40 (under inf-stfeed-c5 (pi g (inf-lt 0 out) (paths nat oc cap)))
   (given inf-stfeed-c5 k3))
; r4-41
 (defvc inf-vc-stfeed-r4-41 (under inf-stfeed-c5 (pi k nat (inf-lt (Lcc1 k) (inf-pow h))))
   (given inf-stfeed-c5 c1c1))
; r4-42
 (defvc inf-vc-stfeed-r4-42 (under inf-stfeed-c5 (pi k nat (inf-lt (Lsc1 k) (inf-pow h))))
   (given inf-stfeed-c5 c1c2))
; r4-43
 (defvc inf-vc-stfeed-r4-43 (under inf-stfeed-c5 (inf-le (inf-sum Lcc1 15 1) lmc1))
   (given inf-stfeed-c5 c1c3))
; r4-44
 (defvc inf-vc-stfeed-r4-44 (under inf-stfeed-c5 (inf-le lmc1 288))
   (given inf-stfeed-c5 c1c4))
; r4-45
 (defvc inf-vc-stfeed-r4-45 (under inf-stfeed-c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow h))))
   (given inf-stfeed-c5 c1c5))
; r4-46
 (defvc inf-vc-stfeed-r4-46 (under inf-stfeed-c5 (pi k nat (inf-lt (Dsc1 k) (inf-pow h))))
   (given inf-stfeed-c5 c1c6))
; r4-47
 (defvc inf-vc-stfeed-r4-47 (under inf-stfeed-c5 (inf-le (inf-sum Dcc1 15 1) dmc1))
   (given inf-stfeed-c5 c1c7))
; r4-48
 (defvc inf-vc-stfeed-r4-48 (under inf-stfeed-c5 (inf-le dmc1 32))
   (given inf-stfeed-c5 c1c8))
; r4-49
 (defvc inf-vc-stfeed-r4-49 (under inf-stfeed-c5 (pi k nat (inf-lt (Ccc1 k) (inf-pow h))))
   (given inf-stfeed-c5 c1d1))
; r4-50
 (defvc inf-vc-stfeed-r4-50 (under inf-stfeed-c5 (pi k nat (inf-lt (Csc1 k) (inf-pow h))))
   (given inf-stfeed-c5 c1d2))
; r4-51
 (defvc inf-vc-stfeed-r4-51 (under inf-stfeed-c5 (inf-le (inf-sum Ccc1 15 1) 19))
   (given inf-stfeed-c5 c1d3))
; r4-52
 (defvc inf-vc-stfeed-r4-52 (under inf-stfeed-c5 (inf-le prevc1 15))
   (given inf-stfeed-c5 c1b1))
; r4-53
 (defvc inf-vc-stfeed-r4-53 (under inf-stfeed-c5 (pi j nat (inf-le (Lzc1 j) 15)))
   (given inf-stfeed-c5 c1b2))
; r4-54
 (defvc inf-vc-stfeed-r4-54 (under inf-stfeed-c5 (pi k nat (inf-le (Clc1 k) 15)))
   (given inf-stfeed-c5 c1a2))
; m1-1
 (defvc inf-vc-stfeed-m1-1 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le (add 0 opc1) nocn5)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 (inf-letl opc1 ncapj3 nocn5 (pathsinv0 nat nocn5 ncapj3 (g12 g13)) (inf-letrans opc1 cap ncapj3 c1e8 (inf-ltle cap ncapj3 k4))))))
; m1-2
 (defvc inf-vc-stfeed-m1-2 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le (add 0 opc1) oc)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 ((inf-letl opc1 cap oc (pathsinv0 nat oc cap (k3 k2)) c1e8)))))
; w1b-1
 (defvc inf-vc-stfeed-w1b-1 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le ipc1 nin)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1e1)))
; w1b-2
 (defvc inf-vc-stfeed-w1b-2 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le bcc1 63)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1e3)))
; w1b-3
 (defvc inf-vc-stfeed-w1b-3 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-bits-inv (add cons0 bc0) ipc1 consc1 bcc1)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1e4)))
; w1b-4
 (defvc inf-vc-stfeed-w1b-4 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le cons0 consc1)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 (inf-letrans cons0 cons consc1 r5 c1e5))))
; w1b-5
 (defvc inf-vc-stfeed-w1b-5 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le opc1 ncapj3)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 (inf-letrans opc1 cap ncapj3 c1e8 (inf-letrans cap ncapj3 ncapj3 (inf-ltle cap ncapj3 k4) (inf-refl ncapj3))))))
; w1b-6
 (defvc inf-vc-stfeed-w1b-6 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le ncapj3 (inf-pow lim))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 k5)))
; w1b-7
 (defvc inf-vc-stfeed-w1b-7 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-lt 0 nbn5)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 g13)))
; w1b-8
 (defvc inf-vc-stfeed-w1b-8 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 g12)))
; w1b-9
 (defvc inf-vc-stfeed-w1b-9 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-lt 0 ncapj3)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 (inf-lttrans 0 cap ncapj3 k6 (inf-ltle cap ncapj3 k4)))))
; w1b-10
 (defvc inf-vc-stfeed-w1b-10 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1c1)))
; w1b-11
 (defvc inf-vc-stfeed-w1b-11 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1c2)))
; w1b-12
 (defvc inf-vc-stfeed-w1b-12 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le (inf-sum Lcc1 15 1) lmc1)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1c3)))
; w1b-13
 (defvc inf-vc-stfeed-w1b-13 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le lmc1 288)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1c4)))
; w1b-14
 (defvc inf-vc-stfeed-w1b-14 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1c5)))
; w1b-15
 (defvc inf-vc-stfeed-w1b-15 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1c6)))
; w1b-16
 (defvc inf-vc-stfeed-w1b-16 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le (inf-sum Dcc1 15 1) dmc1)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1c7)))
; w1b-17
 (defvc inf-vc-stfeed-w1b-17 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le dmc1 32)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1c8)))
; w1b-18
 (defvc inf-vc-stfeed-w1b-18 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (pi k nat (inf-lt (Ccc1 k) (inf-pow h)))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1d1)))
; w1b-19
 (defvc inf-vc-stfeed-w1b-19 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (pi k nat (inf-lt (Csc1 k) (inf-pow h)))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1d2)))
; w1b-20
 (defvc inf-vc-stfeed-w1b-20 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le (inf-sum Ccc1 15 1) 19)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1d3)))
; w1b-21
 (defvc inf-vc-stfeed-w1b-21 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-le prevc1 15)))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1b1)))
; w1b-22
 (defvc inf-vc-stfeed-w1b-22 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (pi j nat (inf-le (Lzc1 j) 15))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1b2)))
; w1b-23
 (defvc inf-vc-stfeed-w1b-23 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (pi k nat (inf-le (Clc1 k) 15))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 c1a2)))
; w1b-24
 (defvc inf-vc-stfeed-w1b-24 (under inf-stfeed-c4 (pi nbn5 nat nocn5 nat g12 (pi g (inf-lt 0 nbn5) (paths nat nocn5 ncapj3)) g13 (inf-lt 0 nbn5) (inf-lt (natminus (inf-pow lim) ncapj3) (natminus (inf-pow lim) cap))))
   (given inf-stfeed-c4 (lam nbn5 nocn5 g12 g13 (inf-subdown (inf-pow lim) cap ncapj3 k4 k5))))
 (defcx inf-st0 (In (pi k nat nat)) (nin nat) (w nat) (gw (inf-le 32 w)) )
; c1-1
 (defvc inf-vc-st0-c1-1 (under inf-st0 (inf-le 19 30))
   (given inf-st0 (idpath false)))
; c1-2
 (defvc inf-vc-st0-c1-2 (under inf-st0 (inf-lt 30 31))
   (given inf-st0 (idpath true)))
; c1-3
 (defvc inf-vc-st0-c1-3 (under inf-st0 (inf-le 16 30))
   (given inf-st0 (idpath false)))
; c1-4
 (defvc inf-vc-st0-c1-4 (under inf-st0 (inf-le 15 16))
   (given inf-st0 (idpath false)))
; c1-5
 (defvc inf-vc-st0-c1-5 (under inf-st0 (inf-le (succ 15) 16))
   (given inf-st0 (idpath false)))
; c1-6
 (defvc inf-vc-st0-c1-6 (under inf-st0 (inf-lt 16 31))
   (given inf-st0 (idpath true)))
; c1-7
 (defvc inf-vc-st0-c1-7 (under inf-st0 (inf-le (succ (succ (succ 16))) 30))
   (given inf-st0 (idpath false)))
; c1-8
 (defvc inf-vc-st0-c1-8 (under inf-st0 (inf-le 12 16))
   (given inf-st0 (idpath false)))
; c1-9
 (defvc inf-vc-st0-c1-9 (under inf-st0 (inf-le 32 w))
   (given inf-st0 gw))
; c1-10
 (defvc inf-vc-st0-c1-10 (under inf-st0 (inf-le 0 63))
   (given inf-st0 (idpath false)))
; c1-11
 (defvc inf-vc-st0-c1-11 (under inf-st0 (inf-le 16 16))
   (given inf-st0 (idpath false)))
; c1-12
 (defvc inf-vc-st0-c1-12 (under inf-st0 (inf-le (inf-by16 (inf-pow 12)) (inf-pow 16)))
   (given inf-st0 inf-topq))
; c1-13
 (defvc inf-vc-st0-c1-13 (under inf-st0 (inf-lt 320 (inf-pow 12)))
   (given inf-st0 (idpath true)))
; c1-14
 (defvc inf-vc-st0-c1-14 (under inf-st0 (pi k nat g (inf-le k 15) (inf-lt (inf-dk (inf-pow 12) k) (inf-pow w))))
   (given inf-st0 (inf-topk w gw)))
; c1-15
 (defvc inf-vc-st0-c1-15 (under inf-st0 (inf-le 12 15))
   (given inf-st0 (idpath false)))
; c1-16
 (defvc inf-vc-st0-c1-16 (under inf-st0 (inf-le 9 15))
   (given inf-st0 (idpath false)))
; c1-17
 (defvc inf-vc-st0-c1-17 (under inf-st0 (inf-le 7 15))
   (given inf-st0 (idpath false)))
; c1-18
 (defvc inf-vc-st0-c1-18 (under inf-st0 (pi k nat g (inf-lt k 19) (inf-lt (inf-tob k) 19)))
   (given inf-st0 (lam k g (inf-lelts (inf-tob k) 18 (inf-anyno (lam j (natgtb (inf-tob j) 18)) 19 (idpath false) k g)))))
; c1-19
 (defvc inf-vc-st0-c1-19 (under inf-st0 (pi k nat g (inf-lt k 29) (inf-le (inf-tle k) 5)))
   (given inf-st0 (inf-anyno (lam j (natgtb (inf-tle j) 5)) 29 (idpath false))))
; c1-20
 (defvc inf-vc-st0-c1-20 (under inf-st0 (pi k nat g (inf-lt k 29) (inf-le (add (inf-tlb k) (inf-pow (inf-tle k))) 259)))
   (given inf-st0 (inf-anyno (lam j (natgtb (add (inf-tlb j) (inf-pow (inf-tle j))) 259)) 29 (idpath false))))
; c1-21
 (defvc inf-vc-st0-c1-21 (under inf-st0 (pi k nat g (inf-lt k 29) (inf-le 3 (inf-tlb k))))
   (given inf-st0 (inf-anyno (lam j (natgtb 3 (inf-tlb j))) 29 (idpath false))))
; c1-22
 (defvc inf-vc-st0-c1-22 (under inf-st0 (pi k nat g (inf-lt k 30) (inf-le (inf-tde k) 13)))
   (given inf-st0 (inf-anyno (lam j (natgtb (inf-tde j) 13)) 30 (idpath false))))
; c1-23
 (defvc inf-vc-st0-c1-23 (under inf-st0 (pi k nat g (inf-lt k 30) (inf-le (add (inf-tdb k) (inf-pow (inf-tde k))) (inf-pow 16))))
   (given inf-st0 (inf-anyno (lam j (natgtb (add (inf-tdb j) (inf-pow (inf-tde j))) (inf-pow 16))) 30 (idpath false))))
; c1-24
 (defvc inf-vc-st0-c1-24 (under inf-st0 (pi k nat (inf-lt (inf-zero k) (inf-pow 16))))
   (given inf-st0 (lam k (inf-powpos 16))))
; c1-25
 (defvc inf-vc-st0-c1-25 (under inf-st0 (inf-le (inf-sum inf-zero 15 1) 0))
   (given inf-st0 (idpath false)))
; c1-26
 (defvc inf-vc-st0-c1-26 (under inf-st0 (inf-le 0 288))
   (given inf-st0 (idpath false)))
; c1-27
 (defvc inf-vc-st0-c1-27 (under inf-st0 (inf-le 0 32))
   (given inf-st0 (idpath false)))
; c1-28
 (defvc inf-vc-st0-c1-28 (under inf-st0 (inf-le (inf-sum inf-zero 15 1) 19))
   (given inf-st0 (idpath false)))
; c1-29
 (defvc inf-vc-st0-c1-29 (under inf-st0 (inf-le 0 15))
   (given inf-st0 (idpath false)))
; c1-30
 (defvc inf-vc-st0-c1-30 (under inf-st0 (pi j nat (inf-le (inf-zero j) 15)))
   (given inf-st0 (lam j (idpath false))))
; c1-31
 (defvc inf-vc-st0-c1-31 (under inf-st0 (pi k nat (inf-le (inf-zero k) 15)))
   (given inf-st0 (lam k (idpath false))))
 (defcx inf-st0-c1 inf-st0 (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (opc1 nat) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (Clc1 (pi j nat nat)) (Lzc1 (pi j nat nat)) (Csc1 (pi j nat nat)) (Ctc1 (pi j nat nat)) (Ccc1 (pi j nat nat)) (lastc1 nat) (remc1 nat) (hclenc1 nat) (ic1 nat) (prevc1 nat) (stagec1 nat) (syc1 nat) (lenc1 nat) (distc1 nat) (modec1 nat) (hlitc1 nat) (hdistc1 nat) (outc1 nat) (occ1 nat) (capc1 nat) (ndc1 nat) (hlenc1 nat) (c1e1 (inf-le ipc1 nin)) (c1e3 (inf-le bcc1 63)) (c1e8 (inf-le opc1 capc1)) (c1eg (pi g (inf-lt 0 outc1) (paths nat occ1 capc1))) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow 16)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow 16)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow 16)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow 16)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) (c1d1 (pi k nat (inf-lt (Ccc1 k) (inf-pow 16)))) (c1d2 (pi k nat (inf-lt (Csc1 k) (inf-pow 16)))) (c1d3 (inf-le (inf-sum Ccc1 15 1) 19)) (c1b1 (inf-le prevc1 15)) (c1b2 (pi j nat (inf-le (Lzc1 j) 15))) (c1a2 (pi k nat (inf-le (Clc1 k) 15))) )
 (defcx inf-stn (nin nat) (out0 nat) (oc0 nat) (cap0 nat) (nd0 nat) (hlen0 nat) (lim nat) (lw nat) (lh nat) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hll (inf-le lh lim)) (hww (inf-le lw lh)) (hsw (inf-le (succ lw) lh)) (hlh (inf-lt lh 31)) (hf (inf-le (succ (succ (succ lh))) lim)) (h12 (inf-le 12 lh)) (In (pi k nat nat)) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gs (inf-le bc0 63)) (op0 nat) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Cl0 (pi k nat nat)) (Lz0 (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (Ob (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) (last0 nat) (rem0 nat) (hclen0 nat) (i0 nat) (prev0 nat) (stage0 nat) (sy0 nat) (len0 nat) (dist0 nat) (mode0 nat) (hlit0 nat) (hdist0 nat) (c1 (pi k nat (inf-lt (Lc0 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls0 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc0 15 1) lm0)) (c4 (inf-le lm0 288)) (c5 (pi k nat (inf-lt (Dc0 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds0 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc0 15 1) dm0)) (c8 (inf-le dm0 32)) (d1 (pi k nat (inf-lt (Cc0 k) (inf-pow h)))) (d2 (pi k nat (inf-lt (Cs0 k) (inf-pow h)))) (d3 (inf-le (inf-sum Cc0 15 1) 19)) (b1 (inf-le prev0 15)) (b2 (pi j nat (inf-le (Lz0 j) 15))) (a2 (pi k nat (inf-le (Cl0 k) 15))) (In2 (pi k nat nat)) (nin2 nat) )
; c1-1
 (defvc inf-vc-stn-c1-1 (under inf-stn (inf-le 19 lim))
   (given inf-stn hl))
; c1-2
 (defvc inf-vc-stn-c1-2 (under inf-stn (inf-lt lim 31))
   (given inf-stn hm))
; c1-3
 (defvc inf-vc-stn-c1-3 (under inf-stn (inf-le lh lim))
   (given inf-stn hll))
; c1-4
 (defvc inf-vc-stn-c1-4 (under inf-stn (inf-le lw lh))
   (given inf-stn hww))
; c1-5
 (defvc inf-vc-stn-c1-5 (under inf-stn (inf-le (succ lw) lh))
   (given inf-stn hsw))
; c1-6
 (defvc inf-vc-stn-c1-6 (under inf-stn (inf-lt lh 31))
   (given inf-stn hlh))
; c1-7
 (defvc inf-vc-stn-c1-7 (under inf-stn (inf-le (succ (succ (succ lh))) lim))
   (given inf-stn hf))
; c1-8
 (defvc inf-vc-stn-c1-8 (under inf-stn (inf-le 12 lh))
   (given inf-stn h12))
; c1-9
 (defvc inf-vc-stn-c1-9 (under inf-stn (inf-le 32 w))
   (given inf-stn gw))
; c1-10
 (defvc inf-vc-stn-c1-10 (under inf-stn (inf-le bc0 63))
   (given inf-stn gs))
; c1-11
 (defvc inf-vc-stn-c1-11 (under inf-stn (inf-le h 16))
   (given inf-stn gh))
; c1-12
 (defvc inf-vc-stn-c1-12 (under inf-stn (inf-le (inf-by16 q) (inf-pow h)))
   (given inf-stn gq))
; c1-13
 (defvc inf-vc-stn-c1-13 (under inf-stn (inf-lt 320 q))
   (given inf-stn gq2))
; c1-14
 (defvc inf-vc-stn-c1-14 (under inf-stn (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))))
   (given inf-stn gk))
; c1-15
 (defvc inf-vc-stn-c1-15 (under inf-stn (inf-le LROOT 15))
   (given inf-stn gl))
; c1-16
 (defvc inf-vc-stn-c1-16 (under inf-stn (inf-le DROOT 15))
   (given inf-stn gd))
; c1-17
 (defvc inf-vc-stn-c1-17 (under inf-stn (inf-le CROOT 15))
   (given inf-stn gc))
; c1-18
 (defvc inf-vc-stn-c1-18 (under inf-stn (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)))
   (given inf-stn hord))
; c1-19
 (defvc inf-vc-stn-c1-19 (under inf-stn (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
   (given inf-stn hle))
; c1-20
 (defvc inf-vc-stn-c1-20 (under inf-stn (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
   (given inf-stn hlb))
; c1-21
 (defvc inf-vc-stn-c1-21 (under inf-stn (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
   (given inf-stn hlc))
; c1-22
 (defvc inf-vc-stn-c1-22 (under inf-stn (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
   (given inf-stn hde))
; c1-23
 (defvc inf-vc-stn-c1-23 (under inf-stn (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))))
   (given inf-stn hdb))
; c1-24
 (defvc inf-vc-stn-c1-24 (under inf-stn (pi k nat (inf-lt (Lc0 k) (inf-pow h))))
   (given inf-stn c1))
; c1-25
 (defvc inf-vc-stn-c1-25 (under inf-stn (pi k nat (inf-lt (Ls0 k) (inf-pow h))))
   (given inf-stn c2))
; c1-26
 (defvc inf-vc-stn-c1-26 (under inf-stn (inf-le (inf-sum Lc0 15 1) lm0))
   (given inf-stn c3))
; c1-27
 (defvc inf-vc-stn-c1-27 (under inf-stn (inf-le lm0 288))
   (given inf-stn c4))
; c1-28
 (defvc inf-vc-stn-c1-28 (under inf-stn (pi k nat (inf-lt (Dc0 k) (inf-pow h))))
   (given inf-stn c5))
; c1-29
 (defvc inf-vc-stn-c1-29 (under inf-stn (pi k nat (inf-lt (Ds0 k) (inf-pow h))))
   (given inf-stn c6))
; c1-30
 (defvc inf-vc-stn-c1-30 (under inf-stn (inf-le (inf-sum Dc0 15 1) dm0))
   (given inf-stn c7))
; c1-31
 (defvc inf-vc-stn-c1-31 (under inf-stn (inf-le dm0 32))
   (given inf-stn c8))
; c1-32
 (defvc inf-vc-stn-c1-32 (under inf-stn (pi k nat (inf-lt (Cc0 k) (inf-pow h))))
   (given inf-stn d1))
; c1-33
 (defvc inf-vc-stn-c1-33 (under inf-stn (pi k nat (inf-lt (Cs0 k) (inf-pow h))))
   (given inf-stn d2))
; c1-34
 (defvc inf-vc-stn-c1-34 (under inf-stn (inf-le (inf-sum Cc0 15 1) 19))
   (given inf-stn d3))
; c1-35
 (defvc inf-vc-stn-c1-35 (under inf-stn (inf-le prev0 15))
   (given inf-stn b1))
; c1-36
 (defvc inf-vc-stn-c1-36 (under inf-stn (pi j nat (inf-le (Lz0 j) 15)))
   (given inf-stn b2))
; c1-37
 (defvc inf-vc-stn-c1-37 (under inf-stn (pi k nat (inf-le (Cl0 k) 15)))
   (given inf-stn a2))
 (defcx inf-stn-c1 inf-stn (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (opc1 nat) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) (Clc1 (pi j nat nat)) (Lzc1 (pi j nat nat)) (Csc1 (pi j nat nat)) (Ctc1 (pi j nat nat)) (Ccc1 (pi j nat nat)) (lastc1 nat) (remc1 nat) (hclenc1 nat) (ic1 nat) (prevc1 nat) (stagec1 nat) (syc1 nat) (lenc1 nat) (distc1 nat) (modec1 nat) (hlitc1 nat) (hdistc1 nat) (outc1 nat) (occ1 nat) (capc1 nat) (ndc1 nat) (hlenc1 nat) (c1e1 (inf-le ipc1 nin)) (c1e3 (inf-le bcc1 63)) (c1e8 (inf-le opc1 capc1)) (c1eg (pi g (inf-lt 0 outc1) (paths nat occ1 capc1))) (c1c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow h)))) (c1c2 (pi k nat (inf-lt (Lsc1 k) (inf-pow h)))) (c1c3 (inf-le (inf-sum Lcc1 15 1) lmc1)) (c1c4 (inf-le lmc1 288)) (c1c5 (pi k nat (inf-lt (Dcc1 k) (inf-pow h)))) (c1c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h)))) (c1c7 (inf-le (inf-sum Dcc1 15 1) dmc1)) (c1c8 (inf-le dmc1 32)) (c1d1 (pi k nat (inf-lt (Ccc1 k) (inf-pow h)))) (c1d2 (pi k nat (inf-lt (Csc1 k) (inf-pow h)))) (c1d3 (inf-le (inf-sum Ccc1 15 1) 19)) (c1b1 (inf-le prevc1 15)) (c1b2 (pi j nat (inf-le (Lzc1 j) 15))) (c1a2 (pi k nat (inf-le (Clc1 k) 15))) )
; c2-1
 (defvc inf-vc-stn-c2-1 (under inf-stn-c1 (inf-le 19 lim))
   (given inf-stn-c1 hl))
; c2-2
 (defvc inf-vc-stn-c2-2 (under inf-stn-c1 (inf-lt lim 31))
   (given inf-stn-c1 hm))
; c2-3
 (defvc inf-vc-stn-c2-3 (under inf-stn-c1 (inf-le lh lim))
   (given inf-stn-c1 hll))
; c2-4
 (defvc inf-vc-stn-c2-4 (under inf-stn-c1 (inf-le lw lh))
   (given inf-stn-c1 hww))
; c2-5
 (defvc inf-vc-stn-c2-5 (under inf-stn-c1 (inf-le (succ lw) lh))
   (given inf-stn-c1 hsw))
; c2-6
 (defvc inf-vc-stn-c2-6 (under inf-stn-c1 (inf-lt lh 31))
   (given inf-stn-c1 hlh))
; c2-7
 (defvc inf-vc-stn-c2-7 (under inf-stn-c1 (inf-le (succ (succ (succ lh))) lim))
   (given inf-stn-c1 hf))
; c2-8
 (defvc inf-vc-stn-c2-8 (under inf-stn-c1 (inf-le 12 lh))
   (given inf-stn-c1 h12))
; c2-9
 (defvc inf-vc-stn-c2-9 (under inf-stn-c1 (inf-le 32 w))
   (given inf-stn-c1 gw))
; c2-10
 (defvc inf-vc-stn-c2-10 (under inf-stn-c1 (inf-le bcc1 63))
   (given inf-stn-c1 c1e3))
; c2-11
 (defvc inf-vc-stn-c2-11 (under inf-stn-c1 (inf-le h 16))
   (given inf-stn-c1 gh))
; c2-12
 (defvc inf-vc-stn-c2-12 (under inf-stn-c1 (inf-le (inf-by16 q) (inf-pow h)))
   (given inf-stn-c1 gq))
; c2-13
 (defvc inf-vc-stn-c2-13 (under inf-stn-c1 (inf-lt 320 q))
   (given inf-stn-c1 gq2))
; c2-14
 (defvc inf-vc-stn-c2-14 (under inf-stn-c1 (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w))))
   (given inf-stn-c1 gk))
; c2-15
 (defvc inf-vc-stn-c2-15 (under inf-stn-c1 (inf-le LROOT 15))
   (given inf-stn-c1 gl))
; c2-16
 (defvc inf-vc-stn-c2-16 (under inf-stn-c1 (inf-le DROOT 15))
   (given inf-stn-c1 gd))
; c2-17
 (defvc inf-vc-stn-c2-17 (under inf-stn-c1 (inf-le CROOT 15))
   (given inf-stn-c1 gc))
; c2-18
 (defvc inf-vc-stn-c2-18 (under inf-stn-c1 (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19)))
   (given inf-stn-c1 hord))
; c2-19
 (defvc inf-vc-stn-c2-19 (under inf-stn-c1 (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
   (given inf-stn-c1 hle))
; c2-20
 (defvc inf-vc-stn-c2-20 (under inf-stn-c1 (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
   (given inf-stn-c1 hlb))
; c2-21
 (defvc inf-vc-stn-c2-21 (under inf-stn-c1 (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
   (given inf-stn-c1 hlc))
; c2-22
 (defvc inf-vc-stn-c2-22 (under inf-stn-c1 (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
   (given inf-stn-c1 hde))
; c2-23
 (defvc inf-vc-stn-c2-23 (under inf-stn-c1 (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))))
   (given inf-stn-c1 hdb))
; c2-24
 (defvc inf-vc-stn-c2-24 (under inf-stn-c1 (pi k nat (inf-lt (Lcc1 k) (inf-pow h))))
   (given inf-stn-c1 c1c1))
; c2-25
 (defvc inf-vc-stn-c2-25 (under inf-stn-c1 (pi k nat (inf-lt (Lsc1 k) (inf-pow h))))
   (given inf-stn-c1 c1c2))
; c2-26
 (defvc inf-vc-stn-c2-26 (under inf-stn-c1 (inf-le (inf-sum Lcc1 15 1) lmc1))
   (given inf-stn-c1 c1c3))
; c2-27
 (defvc inf-vc-stn-c2-27 (under inf-stn-c1 (inf-le lmc1 288))
   (given inf-stn-c1 c1c4))
; c2-28
 (defvc inf-vc-stn-c2-28 (under inf-stn-c1 (pi k nat (inf-lt (Dcc1 k) (inf-pow h))))
   (given inf-stn-c1 c1c5))
; c2-29
 (defvc inf-vc-stn-c2-29 (under inf-stn-c1 (pi k nat (inf-lt (Dsc1 k) (inf-pow h))))
   (given inf-stn-c1 c1c6))
; c2-30
 (defvc inf-vc-stn-c2-30 (under inf-stn-c1 (inf-le (inf-sum Dcc1 15 1) dmc1))
   (given inf-stn-c1 c1c7))
; c2-31
 (defvc inf-vc-stn-c2-31 (under inf-stn-c1 (inf-le dmc1 32))
   (given inf-stn-c1 c1c8))
; c2-32
 (defvc inf-vc-stn-c2-32 (under inf-stn-c1 (pi k nat (inf-lt (Ccc1 k) (inf-pow h))))
   (given inf-stn-c1 c1d1))
; c2-33
 (defvc inf-vc-stn-c2-33 (under inf-stn-c1 (pi k nat (inf-lt (Csc1 k) (inf-pow h))))
   (given inf-stn-c1 c1d2))
; c2-34
 (defvc inf-vc-stn-c2-34 (under inf-stn-c1 (inf-le (inf-sum Ccc1 15 1) 19))
   (given inf-stn-c1 c1d3))
; c2-35
 (defvc inf-vc-stn-c2-35 (under inf-stn-c1 (inf-le prevc1 15))
   (given inf-stn-c1 c1b1))
; c2-36
 (defvc inf-vc-stn-c2-36 (under inf-stn-c1 (pi j nat (inf-le (Lzc1 j) 15)))
   (given inf-stn-c1 c1b2))
; c2-37
 (defvc inf-vc-stn-c2-37 (under inf-stn-c1 (pi k nat (inf-le (Clc1 k) 15)))
   (given inf-stn-c1 c1a2))
 (defcx inf-stn-c2 inf-stn-c1 (ipc2 nat) (bcc2 nat) (bbc2 nat) (consc2 nat) (opc2 nat) (Lcc2 (pi j nat nat)) (Lsc2 (pi j nat nat)) (Ltc2 (pi j nat nat)) (Dcc2 (pi j nat nat)) (Dsc2 (pi j nat nat)) (Dtc2 (pi j nat nat)) (lmc2 nat) (dmc2 nat) (Clc2 (pi j nat nat)) (Lzc2 (pi j nat nat)) (Csc2 (pi j nat nat)) (Ctc2 (pi j nat nat)) (Ccc2 (pi j nat nat)) (lastc2 nat) (remc2 nat) (hclenc2 nat) (ic2 nat) (prevc2 nat) (stagec2 nat) (syc2 nat) (lenc2 nat) (distc2 nat) (modec2 nat) (hlitc2 nat) (hdistc2 nat) (outc2 nat) (occ2 nat) (capc2 nat) (ndc2 nat) (hlenc2 nat) (c2e1 (inf-le ipc2 nin2)) (c2e3 (inf-le bcc2 63)) (c2e8 (inf-le opc2 capc2)) (c2eg (pi g (inf-lt 0 outc2) (paths nat occ2 capc2))) (c2c1 (pi k nat (inf-lt (Lcc2 k) (inf-pow h)))) (c2c2 (pi k nat (inf-lt (Lsc2 k) (inf-pow h)))) (c2c3 (inf-le (inf-sum Lcc2 15 1) lmc2)) (c2c4 (inf-le lmc2 288)) (c2c5 (pi k nat (inf-lt (Dcc2 k) (inf-pow h)))) (c2c6 (pi k nat (inf-lt (Dsc2 k) (inf-pow h)))) (c2c7 (inf-le (inf-sum Dcc2 15 1) dmc2)) (c2c8 (inf-le dmc2 32)) (c2d1 (pi k nat (inf-lt (Ccc2 k) (inf-pow h)))) (c2d2 (pi k nat (inf-lt (Csc2 k) (inf-pow h)))) (c2d3 (inf-le (inf-sum Ccc2 15 1) 19)) (c2b1 (inf-le prevc2 15)) (c2b2 (pi j nat (inf-le (Lzc2 j) 15))) (c2a2 (pi k nat (inf-le (Clc2 k) 15))) )
 )
