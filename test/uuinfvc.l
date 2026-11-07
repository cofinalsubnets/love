; test/uuinfvc.l -- laid by src/love/compress/inf.l, `make mx`. edit that file.
; the ledger: what inf_rundt's theorem leaves open, each with who answers for it
; gw: the word is 32 bits or more -- every target
; gn: n + 8 fits a word: the input is in memory, not at the top of it -- every caller
; go: out nonzero holds cap bytes -- every caller
; gcap gcf: cap + 266 fits a word -- every caller
; gnd: cap + nd fits a word -- every caller
; caller: (inflate s n): a string's length, cap the hint or INF_MAX, out a string or NULL -- gz.c
; caller: inflate_raw: the efi slot's image, cap its stated size -- uefi/slot.c
; caller: inflate_raw: a carried tree entry -- archive/srctree.c
; caller: inflate_raw: a carried text -- cats.c
; caller: inflate_raw, inflate_dict: an image's dictionary and pages -- love.c
; caller: inflate_raw: an idat, cap its filtered size -- quay/png.c
; caller: inflate_raw: a layer's run -- snap.c
; link: struct inf_tabs and lens hold what co-arrays and dyn's arrays say; the same file, unchecked -- inf.l
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
 (defcx inf-fill (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gb (inf-le bc0 64)) (gs (inf-shiftok bc0 ip0 n)) (ga (inf-bits-inv ip0 cons0 bc0)) )
; i1-1
 (defvc inf-vc-fill-i1-1 (under inf-fill (inf-lt (add ip0 8) (inf-pow w)))
   (given inf-fill (inf-lelt (add ip0 8) (add n 8) (inf-pow w) (inf-addr ip0 n 8 gi) gn)))
; a1-1
 (defvc inf-vc-fill-a1-1 (under inf-fill (pi g1 (inf-le (add ip0 8) n) (inf-le (add ip0 8) n)))
   (given inf-fill (lam g1 g1)))
; a1-2
 (defvc inf-vc-fill-a1-2 (under inf-fill (pi g1 (inf-le (add ip0 8) n) (inf-lt bc0 64)))
   (given inf-fill (lam g1 (inf-lelts bc0 63 ((inf-shiftfill bc0 ip0 n gs g1))))))
; a2-1
 (defvc inf-vc-fill-a2-1 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le (inf-div8 bc0) 7)))
   (given inf-fill (lam g1 bba1 (inf-div8le bc0 ((inf-shiftfill bc0 ip0 n gs g1))))))
; a2-2
 (defvc inf-vc-fill-a2-2 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-lt (add ip0 (natminus 7 (inf-div8 bc0))) (inf-pow w))))
   (given inf-fill (lam g1 bba1 (inf-lelt ((add ip0 ((natminus 7 (inf-div8 bc0))))) n (inf-pow w) (inf-letrans ((add ip0 ((natminus 7 (inf-div8 bc0))))) (add ip0 8) n ((inf-addl ip0 ((natminus 7 (inf-div8 bc0))) 8 (inf-letrans ((natminus 7 (inf-div8 bc0))) 7 8 (inf-suble 7 (inf-div8 bc0)) (idpath false)))) g1) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn))))))
; a3-1
 (defvc inf-vc-fill-a3-1 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le bc0 63)))
   (given inf-fill (lam g1 bba1 ((inf-shiftfill bc0 ip0 n gs g1)))))
; a3-2
 (defvc inf-vc-fill-a3-2 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-lt (add 56 (inf-mod 8 bc0)) (inf-pow w))))
   (given inf-fill (lam g1 bba1 (inf-wlit (add 56 (inf-mod 8 bc0)) w gw ((inf-addl 56 (inf-mod 8 bc0) 8 (inf-ltle (inf-mod 8 bc0) 8 (inf-modlt 7 bc0))))))))
; end-1
 (defvc inf-vc-fill-end-1 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le (add ip0 (natminus 7 (inf-div8 bc0))) n)))
   (given inf-fill (lam g1 bba1 (inf-letrans ((add ip0 ((natminus 7 (inf-div8 bc0))))) (add ip0 8) n ((inf-addl ip0 ((natminus 7 (inf-div8 bc0))) 8 (inf-letrans ((natminus 7 (inf-div8 bc0))) 7 8 (inf-suble 7 (inf-div8 bc0)) (idpath false)))) g1))))
; end-2
 (defvc inf-vc-fill-end-2 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le (add 56 (inf-mod 8 bc0)) 64)))
   (given inf-fill (lam g1 bba1 ((inf-addl 56 (inf-mod 8 bc0) 8 (inf-ltle (inf-mod 8 bc0) 8 (inf-modlt 7 bc0)))))))
; end-3
 (defvc inf-vc-fill-end-3 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-shiftok (add 56 (inf-mod 8 bc0)) (add ip0 (natminus 7 (inf-div8 bc0))) n)))
   (given inf-fill (lam g1 bba1 (inf-shiftwide bc0 ((add ip0 ((natminus 7 (inf-div8 bc0))))) n))))
; end-4
 (defvc inf-vc-fill-end-4 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-bits-inv (add ip0 (natminus 7 (inf-div8 bc0))) cons0 (add 56 (inf-mod 8 bc0)))))
   (given inf-fill (lam g1 bba1 (inf-fillw ip0 cons0 bc0 ((inf-shiftfill bc0 ip0 n gs g1)) ga))))
; end-5
 (defvc inf-vc-fill-end-5 (under inf-fill (pi g1 (inf-le (add ip0 8) n) bba1 nat (inf-le cons0 cons0)))
   (given inf-fill (lam g1 bba1 (inf-refl cons0))))
; w1e-1
 (defvc inf-vc-fill-w1e-1 (under inf-fill (pi g1 (inf-lt n (add ip0 8)) (inf-le ip0 n)))
   (given inf-fill (lam g1 gi)))
; w1e-2
 (defvc inf-vc-fill-w1e-2 (under inf-fill (pi g1 (inf-lt n (add ip0 8)) (inf-le bc0 64)))
   (given inf-fill (lam g1 gb)))
; w1e-3
 (defvc inf-vc-fill-w1e-3 (under inf-fill (pi g1 (inf-lt n (add ip0 8)) (inf-lt n (add ip0 8))))
   (given inf-fill (lam g1 g1)))
; w1e-4
 (defvc inf-vc-fill-w1e-4 (under inf-fill (pi g1 (inf-lt n (add ip0 8)) (inf-bits-inv ip0 cons0 bc0)))
   (given inf-fill (lam g1 ga)))
 (defcx inf-fill-w1 inf-fill (g1 (inf-lt n (add ip0 8))) (ip nat) (bc nat) (bb nat) (j1 (inf-le ip n)) (j2 (inf-le bc 64)) (j3 (inf-lt n (add ip 8))) (j4 (inf-bits-inv ip cons0 bc)) )
; end-6
 (defvc inf-vc-fill-end-6 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-lt 56 bc) (inf-le ip n)))
   (given inf-fill-w1 (lam w1 g2 j1)))
; end-7
 (defvc inf-vc-fill-end-7 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-lt 56 bc) (inf-le bc 64)))
   (given inf-fill-w1 (lam w1 g2 j2)))
; end-8
 (defvc inf-vc-fill-end-8 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-lt 56 bc) (inf-shiftok bc ip n)))
   (given inf-fill-w1 (lam w1 g2 (ii2 j3))))
; end-9
 (defvc inf-vc-fill-end-9 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-lt 56 bc) (inf-bits-inv ip cons0 bc)))
   (given inf-fill-w1 (lam w1 g2 j4)))
; end-10
 (defvc inf-vc-fill-end-10 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-lt 56 bc) (inf-le cons0 cons0)))
   (given inf-fill-w1 (lam w1 g2 (inf-refl cons0))))
; b2-1
 (defvc inf-vc-fill-b2-1 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 56) (inf-lt ip n)))
   (given inf-fill-w1 (lam w1 g2 w1)))
; b2-2
 (defvc inf-vc-fill-b2-2 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 56) (inf-lt bc 64)))
   (given inf-fill-w1 (lam w1 g2 (inf-lelt bc 56 64 g2 (idpath true)))))
; b3-1
 (defvc inf-vc-fill-b3-1 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 56) bbb2 nat (inf-lt (add ip 1) (inf-pow w))))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-lelt ((add ip 1)) n (inf-pow w) (inf-lt1 ip n w1) ((inf-lelt n (add n 8) (inf-pow w) (inf-leaddr n 8) gn))))))
; b4-1
 (defvc inf-vc-fill-b4-1 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 56) bbb2 nat (inf-lt (add bc 8) (inf-pow w))))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-wlit (add bc 8) w gw ((inf-addr bc 56 8 g2))))))
; w1b-1
 (defvc inf-vc-fill-w1b-1 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 56) bbb2 nat (inf-le (add ip 1) n)))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-lt1 ip n w1))))
; w1b-2
 (defvc inf-vc-fill-w1b-2 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 56) bbb2 nat (inf-le (add bc 8) 64)))
   (given inf-fill-w1 (lam w1 g2 bbb2 ((inf-addr bc 56 8 g2)))))
; w1b-3
 (defvc inf-vc-fill-w1b-3 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 56) bbb2 nat (inf-lt n (add (add ip 1) 8))))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-lttrans n (add ip 8) (add ((add ip 1)) 8) j3 (inf-addr ip ((add ip 1)) 8 (inf-leaddr ip 1))))))
; w1b-4
 (defvc inf-vc-fill-w1b-4 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 56) bbb2 nat (inf-bits-inv (add ip 1) cons0 (add bc 8))))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-fill1b ip cons0 bc j4))))
; w1b-5
 (defvc inf-vc-fill-w1b-5 (under inf-fill-w1 (pi w1 (inf-lt ip n) g2 (inf-le bc 56) bbb2 nat (inf-lt (natminus n (add ip 1)) (natminus n ip))))
   (given inf-fill-w1 (lam w1 g2 bbb2 (inf-subfall1 n ip w1))))
; end-11
 (defvc inf-vc-fill-end-11 (under inf-fill-w1 (pi w1 (inf-le n ip) (inf-le ip n)))
   (given inf-fill-w1 (lam w1 j1)))
; end-12
 (defvc inf-vc-fill-end-12 (under inf-fill-w1 (pi w1 (inf-le n ip) (inf-le bc 64)))
   (given inf-fill-w1 (lam w1 j2)))
; end-13
 (defvc inf-vc-fill-end-13 (under inf-fill-w1 (pi w1 (inf-le n ip) (inf-shiftok bc ip n)))
   (given inf-fill-w1 (lam w1 (ii2 j3))))
; end-14
 (defvc inf-vc-fill-end-14 (under inf-fill-w1 (pi w1 (inf-le n ip) (inf-bits-inv ip cons0 bc)))
   (given inf-fill-w1 (lam w1 j4)))
; end-15
 (defvc inf-vc-fill-end-15 (under inf-fill-w1 (pi w1 (inf-le n ip) (inf-le cons0 cons0)))
   (given inf-fill-w1 (lam w1 (inf-refl cons0))))
 (defcx inf-take (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gb (inf-le bc0 64)) (gs (inf-shiftok bc0 ip0 n)) (ga (inf-bits-inv ip0 cons0 bc0)) (k nat) (gk (inf-le k 13)) )
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
 (defvc inf-vc-take-c1-4 (under inf-take (inf-le bc0 64))
   (given inf-take gb))
; c1-5
 (defvc inf-vc-take-c1-5 (under inf-take (inf-shiftok bc0 ip0 n))
   (given inf-take gs))
; c1-6
 (defvc inf-vc-take-c1-6 (under inf-take (inf-bits-inv ip0 cons0 bc0))
   (given inf-take ga))
 (defcx inf-take-c1 inf-take (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e2 (inf-le bcc1 64)) (c1e3 (inf-shiftok bcc1 ipc1 n)) (c1e4 (inf-bits-inv ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
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
   (given inf-take-c1 (lam g1 bbd2 (inf-wlit ((natminus bcc1 k)) w gw (inf-letrans ((natminus bcc1 k)) bcc1 64 (inf-suble bcc1 k) c1e2)))))
; r2-1
 (defvc inf-vc-take-r2-1 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-le ipc1 n)))
   (given inf-take-c1 (lam g1 bbd2 c1e1)))
; r2-2
 (defvc inf-vc-take-r2-2 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-le (natminus bcc1 k) 64)))
   (given inf-take-c1 (lam g1 bbd2 (inf-letrans ((natminus bcc1 k)) bcc1 64 (inf-suble bcc1 k) c1e2))))
; r2-3
 (defvc inf-vc-take-r2-3 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-shiftok (natminus bcc1 k) ipc1 n)))
   (given inf-take-c1 (lam g1 bbd2 (inf-shifttake bcc1 ipc1 n k c1e3))))
; r2-4
 (defvc inf-vc-take-r2-4 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-bits-inv ipc1 (add consc1 k) (natminus bcc1 k))))
   (given inf-take-c1 (lam g1 bbd2 (inf-take ipc1 consc1 bcc1 k g1 c1e4))))
; r2-5
 (defvc inf-vc-take-r2-5 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-le cons0 (add consc1 k))))
   (given inf-take-c1 (lam g1 bbd2 (inf-letrans cons0 consc1 ((add consc1 k)) c1e5 (inf-leaddr consc1 k)))))
; r2-6
 (defvc inf-vc-take-r2-6 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-le (add cons0 k) (add consc1 k))))
   (given inf-take-c1 (lam g1 bbd2 (inf-addr cons0 consc1 k c1e5))))
; r2-7
 (defvc inf-vc-take-r2-7 (under inf-take-c1 (pi g1 (inf-le k bcc1) bbd2 nat (inf-lt (inf-mod (inf-pow k) bbc1) (inf-pow k))))
   (given inf-take-c1 (lam g1 bbd2 (inf-masklt bbc1 k))))
 (defcx inf-sym (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gb (inf-le bc0 64)) (gs (inf-shiftok bc0 ip0 n)) (ga (inf-bits-inv ip0 cons0 bc0)) (Cn (pi i nat nat)) (Sy (pi i nat nat)) (Tb (pi i nat nat)) (m nat) (h nat) (root nat) (hc (pi i nat (inf-lt (Cn i) (inf-pow h)))) (hs (pi i nat (inf-lt (Sy i) (inf-pow h)))) (gh (inf-le h 16)) (gm (inf-lt m (inf-pow w))) (gt (inf-le (inf-sum Cn 15 1) m)) (gr (inf-le root 15)) )
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
 (defvc inf-vc-sym-c1-4 (under inf-sym (inf-le bc0 64))
   (given inf-sym gb))
; c1-5
 (defvc inf-vc-sym-c1-5 (under inf-sym (inf-shiftok bc0 ip0 n))
   (given inf-sym gs))
; c1-6
 (defvc inf-vc-sym-c1-6 (under inf-sym (inf-bits-inv ip0 cons0 bc0))
   (given inf-sym ga))
 (defcx inf-sym-c1 inf-sym (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (c1e1 (inf-le ipc1 n)) (c1e2 (inf-le bcc1 64)) (c1e3 (inf-shiftok bcc1 ipc1 n)) (c1e4 (inf-bits-inv ipc1 consc1 bcc1)) (c1e5 (inf-le cons0 consc1)) )
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
 (defcx inf-sym-c3 inf-sym-c1 (ed1 nat) (g1 (paths nat ed1 0)) (xw0 nat) (w0e1 (inf-lt xw0 (inf-pow w))) )
 (defcx inf-sym-c2 inf-sym-c1 (ed1 nat) (ei1 nat) )
; d2-1
 (defvc inf-vc-sym-d2-1 (under inf-sym-c2 (inf-lt 4 64))
   (given inf-sym-c2 (idpath true)))
; d3-1
 (defvc inf-vc-sym-d3-1 (under inf-sym-c2 (pi syd2 nat (inf-lt (inf-mod 16 ei1) (inf-pow w))))
   (given inf-sym-c2 (lam syd2 (inf-wlit ((inf-mod 16 ei1)) w gw (inf-letrans ((inf-mod 16 ei1)) 15 64 ((inf-ltsle ((inf-mod 16 ei1)) 15 (inf-modlt 15 ei1))) (idpath false))))))
; d4-1
 (defvc inf-vc-sym-d4-1 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) (inf-lt (inf-mod 16 ei1) 64)))
   (given inf-sym-c2 (lam syd2 g2 (inf-lelt ((inf-mod 16 ei1)) 15 64 ((inf-ltsle ((inf-mod 16 ei1)) 15 (inf-modlt 15 ei1))) (idpath true)))))
; d5-1
 (defvc inf-vc-sym-d5-1 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-le (inf-mod 16 ei1) bcc1)))
   (given inf-sym-c2 (lam syd2 g2 bbd4 g2)))
; d5-2
 (defvc inf-vc-sym-d5-2 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-lt (natminus bcc1 (inf-mod 16 ei1)) (inf-pow w))))
   (given inf-sym-c2 (lam syd2 g2 bbd4 (inf-wlit ((natminus bcc1 ((inf-mod 16 ei1)))) w gw (inf-letrans ((natminus bcc1 ((inf-mod 16 ei1)))) bcc1 64 (inf-suble bcc1 ((inf-mod 16 ei1))) c1e2)))))
; r2-1
 (defvc inf-vc-sym-r2-1 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-le ipc1 n)))
   (given inf-sym-c2 (lam syd2 g2 bbd4 c1e1)))
; r2-2
 (defvc inf-vc-sym-r2-2 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-le (natminus bcc1 (inf-mod 16 ei1)) 64)))
   (given inf-sym-c2 (lam syd2 g2 bbd4 (inf-letrans ((natminus bcc1 ((inf-mod 16 ei1)))) bcc1 64 (inf-suble bcc1 ((inf-mod 16 ei1))) c1e2))))
; r2-3
 (defvc inf-vc-sym-r2-3 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-shiftok (natminus bcc1 (inf-mod 16 ei1)) ipc1 n)))
   (given inf-sym-c2 (lam syd2 g2 bbd4 (inf-shifttake bcc1 ipc1 n ((inf-mod 16 ei1)) c1e3))))
; r2-4
 (defvc inf-vc-sym-r2-4 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-bits-inv ipc1 (add consc1 (inf-mod 16 ei1)) (natminus bcc1 (inf-mod 16 ei1)))))
   (given inf-sym-c2 (lam syd2 g2 bbd4 (inf-take ipc1 consc1 bcc1 ((inf-mod 16 ei1)) g2 c1e4))))
; r2-5
 (defvc inf-vc-sym-r2-5 (under inf-sym-c2 (pi syd2 nat g2 (inf-le (inf-mod 16 ei1) bcc1) bbd4 nat (inf-le cons0 (add consc1 (inf-mod 16 ei1)))))
   (given inf-sym-c2 (lam syd2 g2 bbd4 (inf-letrans cons0 consc1 (add consc1 ((inf-mod 16 ei1))) c1e5 (inf-leaddr consc1 ((inf-mod 16 ei1)))))))
 (defcx inf-stored (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gb (inf-le bc0 64)) (gs (inf-shiftok bc0 ip0 n)) (ga (inf-bits-inv ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) )
; d1-1
 (defvc inf-vc-stored-d1-1 (under inf-stored (inf-lt (inf-mod 8 bc0) (inf-pow w)))
   (given inf-stored (inf-wlit ((inf-mod 8 bc0)) w gw (inf-letrans ((inf-mod 8 bc0)) 8 64 ((inf-ltle ((inf-mod 8 bc0)) 8 (inf-modlt 7 bc0))) (idpath false)))))
; d2-1
 (defvc inf-vc-stored-d2-1 (under inf-stored (inf-lt (inf-mod 8 bc0) 64))
   (given inf-stored (inf-lttrans ((inf-mod 8 bc0)) 8 64 (inf-modlt 7 bc0) (idpath false))))
; d3-1
 (defvc inf-vc-stored-d3-1 (under inf-stored (pi bbd2 nat (inf-le (inf-mod 8 bc0) bc0)))
   (given inf-stored (lam bbd2 (inf-modle8 bc0))))
; d3-2
 (defvc inf-vc-stored-d3-2 (under inf-stored (pi bbd2 nat (inf-lt (natminus bc0 (inf-mod 8 bc0)) (inf-pow w))))
   (given inf-stored (lam bbd2 (inf-wlit ((natminus bc0 ((inf-mod 8 bc0)))) w gw ((inf-letrans ((natminus bc0 ((inf-mod 8 bc0)))) bc0 64 (inf-suble bc0 ((inf-mod 8 bc0))) gb))))))
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
 (defvc inf-vc-stored-r5-2 (under inf-stored-c1 (pi bbd11 nat (inf-le 0 64)))
   (given inf-stored-c1 (lam bbd11 (idpath false))))
; r5-3
 (defvc inf-vc-stored-r5-3 (under inf-stored-c1 (pi bbd11 nat (inf-shiftok 0 (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) n)))
   (given inf-stored-c1 (lam bbd11 (ii1 (idpath false)))))
; r5-4
 (defvc inf-vc-stored-r5-4 (under inf-stored-c1 (pi bbd11 nat (inf-bits-inv (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7) (inf-by8 (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7)) 0)))
   (given inf-stored-c1 (lam bbd11 (pathsinv0 nat (add (inf-by8 ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7)))) 0) (inf-by8 ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7)))) (natplusr0 (inf-by8 ((add ((add ((natminus ip0 ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))))) 4)) (lnd7)))))))))
; r5-5
 (defvc inf-vc-stored-r5-5 (under inf-stored-c1 (pi bbd11 nat (inf-le cons0 (inf-by8 (add (add (natminus ip0 (inf-div8 (natminus bc0 (inf-mod 8 bc0)))) 4) lnd7)))))
   (given inf-stored-c1 (lam bbd11 (inf-storedc ip0 cons0 ((inf-mod 8 bc0)) ((inf-div8 ((natminus bc0 ((inf-mod 8 bc0)))))) 4 (lnd7) ((inf-dropinv ip0 cons0 bc0 ga))))))
; r5-6
 (defvc inf-vc-stored-r5-6 (under inf-stored-c1 (pi bbd11 nat (inf-le (add op0 lnd7) cap)))
   (given inf-stored-c1 (lam bbd11 ((inf-roomle op0 cap (lnd7) g4 gop)))))
; r5-7
 (defvc inf-vc-stored-r5-7 (under inf-stored-c1 (pi bbd11 nat (inf-le op0 (add op0 lnd7))))
   (given inf-stored-c1 (lam bbd11 (inf-leaddr op0 (lnd7)))))
 (defcx inf-copy (w nat) (l nat) (d nat) (op nat) (out nat) (oc nat) (cap nat) (nd nat) (gw (inf-le 32 w)) (gd (inf-lt d (inf-pow w))) (ga (inf-le d (add op nd))) (gb (inf-le (add op l) cap)) (gz (inf-lt 0 out)) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) )
; s1-1
 (defvc inf-vc-copy-s1-1 (under inf-copy (pi g1 (inf-lt op d) (inf-lt l (inf-pow w))))
   (given inf-copy (lam g1 ((inf-lelt l cap (inf-pow w) (inf-letrans l (add op l) cap (inf-leaddl l op) gb) ((inf-lelt cap (add cap 8) (inf-pow w) (inf-leaddr cap 8) gcap)))))))
; j1-1
 (defvc inf-vc-copy-j1-1 (under inf-copy (pi g1 (inf-lt op d) (inf-le op d)))
   (given inf-copy (lam g1 (inf-ltle op d g1))))
; s2-1
 (defvc inf-vc-copy-s2-1 (under inf-copy (pi g1 (inf-lt op d) g2 (inf-lt (natminus d op) l) (inf-le op d)))
   (given inf-copy (lam g1 g2 (inf-ltle op d g1))))
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
   (given inf-copy-c2 (inf-ltle op d g1)))
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
   (given inf-fixed-c5 (inf-wlit vj3 w gw (inf-letrans vj3 15 64 b3 (idpath false)))))
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
   (given inf-fixed-c1-w2 (lam w2 (inf-wlit (succ i) w gw (inf-letrans (succ i) 30 64 (inf-ltsu i 30 w2) (idpath false))))))
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
 (defcx inf-dyn (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gb (inf-le bc0 64)) (gs (inf-shiftok bc0 ip0 n)) (ga (inf-bits-inv ip0 cons0 bc0)) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (Ob (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) )
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
 (defvc inf-vc-dyn-t1-4 (under inf-dyn (inf-le bc0 64))
   (given inf-dyn gb))
; t1-5
 (defvc inf-vc-dyn-t1-5 (under inf-dyn (inf-shiftok bc0 ip0 n))
   (given inf-dyn gs))
; t1-6
 (defvc inf-vc-dyn-t1-6 (under inf-dyn (inf-bits-inv ip0 cons0 bc0))
   (given inf-dyn ga))
; t1-7
 (defvc inf-vc-dyn-t1-7 (under inf-dyn (inf-le 5 13))
   (given inf-dyn (idpath false)))
 (defcx inf-dyn-c1 inf-dyn (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e2 (inf-le bct1 64)) (t1e3 (inf-shiftok bct1 ipt1 n)) (t1e4 (inf-bits-inv ipt1 const1 bct1)) (t1e5 (inf-le cons0 const1)) (t1e6 (inf-le (add cons0 5) const1)) (t1e7 (inf-lt xt1 (inf-pow 5))) )
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
 (defvc inf-vc-dyn-t2-4 (under inf-dyn-c1 (inf-le bct1 64))
   (given inf-dyn-c1 t1e2))
; t2-5
 (defvc inf-vc-dyn-t2-5 (under inf-dyn-c1 (inf-shiftok bct1 ipt1 n))
   (given inf-dyn-c1 t1e3))
; t2-6
 (defvc inf-vc-dyn-t2-6 (under inf-dyn-c1 (inf-bits-inv ipt1 const1 bct1))
   (given inf-dyn-c1 t1e4))
; t2-7
 (defvc inf-vc-dyn-t2-7 (under inf-dyn-c1 (inf-le 5 13))
   (given inf-dyn-c1 (idpath false)))
 (defcx inf-dyn-c2 inf-dyn-c1 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (xt2 nat) (t2e1 (inf-le ipt2 n)) (t2e2 (inf-le bct2 64)) (t2e3 (inf-shiftok bct2 ipt2 n)) (t2e4 (inf-bits-inv ipt2 const2 bct2)) (t2e5 (inf-le const1 const2)) (t2e6 (inf-le (add const1 5) const2)) (t2e7 (inf-lt xt2 (inf-pow 5))) )
; s2-1
 (defvc inf-vc-dyn-s2-1 (under inf-dyn-c2 (inf-lt (add xt2 1) (inf-pow w)))
   (given inf-dyn-c2 (inf-wlit ((add xt2 1)) w gw (inf-letrans ((add xt2 1)) 32 64 ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7))) (idpath false)))))
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
 (defvc inf-vc-dyn-t3-4 (under inf-dyn-c2 (inf-le bct2 64))
   (given inf-dyn-c2 t2e2))
; t3-5
 (defvc inf-vc-dyn-t3-5 (under inf-dyn-c2 (inf-shiftok bct2 ipt2 n))
   (given inf-dyn-c2 t2e3))
; t3-6
 (defvc inf-vc-dyn-t3-6 (under inf-dyn-c2 (inf-bits-inv ipt2 const2 bct2))
   (given inf-dyn-c2 t2e4))
; t3-7
 (defvc inf-vc-dyn-t3-7 (under inf-dyn-c2 (inf-le 4 13))
   (given inf-dyn-c2 (idpath false)))
 (defcx inf-dyn-c3 inf-dyn-c2 (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e2 (inf-le bct3 64)) (t3e3 (inf-shiftok bct3 ipt3 n)) (t3e4 (inf-bits-inv ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e6 (inf-le (add const2 4) const3)) (t3e7 (inf-lt xt3 (inf-pow 4))) )
; s3-1
 (defvc inf-vc-dyn-s3-1 (under inf-dyn-c3 (inf-lt (add xt3 4) (inf-pow w)))
   (given inf-dyn-c3 (inf-wlit ((add xt3 4)) w gw (inf-letrans ((add xt3 4)) 19 64 ((inf-addr xt3 15 4 (inf-ltsle xt3 15 t3e7))) (idpath false)))))
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
 (defvc inf-vc-dyn-w1e-5 (under inf-dyn-c3 (inf-le bct3 64))
   (given inf-dyn-c3 t3e2))
; w1e-6
 (defvc inf-vc-dyn-w1e-6 (under inf-dyn-c3 (inf-shiftok bct3 ipt3 n))
   (given inf-dyn-c3 t3e3))
; w1e-7
 (defvc inf-vc-dyn-w1e-7 (under inf-dyn-c3 (inf-bits-inv ipt3 const3 bct3))
   (given inf-dyn-c3 t3e4))
; w1e-8
 (defvc inf-vc-dyn-w1e-8 (under inf-dyn-c3 (inf-le cons0 const3))
   (given inf-dyn-c3 ((inf-letrans cons0 const2 const3 (inf-letrans cons0 const1 const2 t1e5 t2e5) t3e5))))
 (defcx inf-dyn-c3-w1 inf-dyn-c3 (i nat) (Cl (pi j nat nat)) (x nat) (ip nat) (bc nat) (bb nat) (cons nat) (a1 (inf-le i (add xt3 4))) (a2 (pi k nat (inf-le (Cl k) 15))) (a3 (inf-le (add xt3 4) 19)) (r1 (inf-le ip n)) (r2 (inf-le bc 64)) (r3 (inf-shiftok bc ip n)) (r4 (inf-bits-inv ip cons bc)) (r5 (inf-le cons0 cons)) )
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
 (defvc inf-vc-dyn-t4-4 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-le bc 64)))
   (given inf-dyn-c3-w1 (lam w1 r2)))
; t4-5
 (defvc inf-vc-dyn-t4-5 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-shiftok bc ip n)))
   (given inf-dyn-c3-w1 (lam w1 r3)))
; t4-6
 (defvc inf-vc-dyn-t4-6 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-bits-inv ip cons bc)))
   (given inf-dyn-c3-w1 (lam w1 r4)))
; t4-7
 (defvc inf-vc-dyn-t4-7 (under inf-dyn-c3-w1 (pi w1 (inf-lt i (add xt3 4)) (inf-le 3 13)))
   (given inf-dyn-c3-w1 (lam w1 (idpath false))))
 (defcx inf-dyn-c14 inf-dyn-c3-w1 (w1 (inf-lt i (add xt3 4))) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e2 (inf-le bct4 64)) (t4e3 (inf-shiftok bct4 ipt4 n)) (t4e4 (inf-bits-inv ipt4 const4 bct4)) (t4e5 (inf-le cons const4)) (t4e6 (inf-le (add cons 3) const4)) (t4e7 (inf-lt xt4 (inf-pow 3))) )
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
   (given inf-dyn-c14 (inf-wlit (succ i) w gw (inf-letrans (succ i) 19 64 (inf-ltsu i 19 (inf-lttrans i ((add xt3 4)) 19 w1 a3)) (idpath false)))))
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
 (defvc inf-vc-dyn-w1b-6 (under inf-dyn-c14 (inf-le bct4 64))
   (given inf-dyn-c14 t4e2))
; w1b-7
 (defvc inf-vc-dyn-w1b-7 (under inf-dyn-c14 (inf-shiftok bct4 ipt4 n))
   (given inf-dyn-c14 t4e3))
; w1b-8
 (defvc inf-vc-dyn-w1b-8 (under inf-dyn-c14 (inf-bits-inv ipt4 const4 bct4))
   (given inf-dyn-c14 t4e4))
; w1b-9
 (defvc inf-vc-dyn-w1b-9 (under inf-dyn-c14 (inf-le cons0 const4))
   (given inf-dyn-c14 (inf-letrans cons0 cons const4 r5 t4e5)))
; w1b-10
 (defvc inf-vc-dyn-w1b-10 (under inf-dyn-c14 (inf-lt (natminus (add xt3 4) (succ i)) (natminus (add xt3 4) i)))
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
 (defvc inf-vc-dyn-w2e-4 (under inf-dyn-c4 (inf-le bc 64))
   (given inf-dyn-c4 r2))
; w2e-5
 (defvc inf-vc-dyn-w2e-5 (under inf-dyn-c4 (inf-shiftok bc ip n))
   (given inf-dyn-c4 r3))
; w2e-6
 (defvc inf-vc-dyn-w2e-6 (under inf-dyn-c4 (inf-bits-inv ip cons bc))
   (given inf-dyn-c4 r4))
; w2e-7
 (defvc inf-vc-dyn-w2e-7 (under inf-dyn-c4 (inf-le cons0 cons))
   (given inf-dyn-c4 r5))
 (defcx inf-dyn-c4-w2 inf-dyn-c4 (i nat) (Lz (pi j nat nat)) (x nat) (ip nat) (bc nat) (bb nat) (cons nat) (prev nat) (b1 (inf-le prev 15)) (b2 (pi j nat (inf-le (Lz j) 15))) (r1 (inf-le ip n)) (r2 (inf-le bc 64)) (r3 (inf-shiftok bc ip n)) (r4 (inf-bits-inv ip cons bc)) (r5 (inf-le cons0 cons)) )
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
 (defvc inf-vc-dyn-t5-4 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le bc 64)))
   (given inf-dyn-c4-w2 (lam w2 r2)))
; t5-5
 (defvc inf-vc-dyn-t5-5 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-shiftok bc ip n)))
   (given inf-dyn-c4-w2 (lam w2 r3)))
; t5-6
 (defvc inf-vc-dyn-t5-6 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-bits-inv ip cons bc)))
   (given inf-dyn-c4-w2 (lam w2 r4)))
; t5-7
 (defvc inf-vc-dyn-t5-7 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (pi i nat (inf-lt (Ccc2 i) (inf-pow h)))))
   (given inf-dyn-c4-w2 (lam w2 c2e1)))
; t5-8
 (defvc inf-vc-dyn-t5-8 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (pi i nat (inf-lt (Csc2 i) (inf-pow h)))))
   (given inf-dyn-c4-w2 (lam w2 c2e2)))
; t5-9
 (defvc inf-vc-dyn-t5-9 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le h 16)))
   (given inf-dyn-c4-w2 (lam w2 gh)))
; t5-10
 (defvc inf-vc-dyn-t5-10 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-lt 19 (inf-pow w))))
   (given inf-dyn-c4-w2 (lam w2 (inf-wlit 19 w gw (idpath false)))))
; t5-11
 (defvc inf-vc-dyn-t5-11 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le (inf-sum Ccc2 15 1) 19)))
   (given inf-dyn-c4-w2 (lam w2 c2e3)))
; t5-12
 (defvc inf-vc-dyn-t5-12 (under inf-dyn-c4-w2 (pi w2 (inf-lt i (add (add xt1 257) (add xt2 1))) (inf-le CROOT 15)))
   (given inf-dyn-c4-w2 (lam w2 gc)))
 (defcx inf-dyn-c5 inf-dyn-c4-w2 (w2 (inf-lt i (add (add xt1 257) (add xt2 1)))) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (syt5 nat) (t5e1 (inf-le ipt5 n)) (t5e2 (inf-le bct5 64)) (t5e3 (inf-shiftok bct5 ipt5 n)) (t5e4 (inf-bits-inv ipt5 const5 bct5)) (t5e5 (inf-le cons const5)) )
; s6-1
 (defvc inf-vc-dyn-s6-1 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-lt 1 (inf-pow w))))
   (given inf-dyn-c5 (lam g1 (inf-wlit 1 w gw (idpath false)))))
; s7-1
 (defvc inf-vc-dyn-s7-1 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-lt syt5 (inf-pow w))))
   (given inf-dyn-c5 (lam g1 (inf-wlit syt5 w gw (inf-letrans syt5 16 64 (inf-ltle syt5 16 g1) (idpath false))))))
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
 (defvc inf-vc-dyn-j1j-5 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-le bct5 64)))
   (given inf-dyn-c5 (lam g1 t5e2)))
; j1j-6
 (defvc inf-vc-dyn-j1j-6 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-shiftok bct5 ipt5 n)))
   (given inf-dyn-c5 (lam g1 t5e3)))
; j1j-7
 (defvc inf-vc-dyn-j1j-7 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-bits-inv ipt5 const5 bct5)))
   (given inf-dyn-c5 (lam g1 t5e4)))
; j1j-8
 (defvc inf-vc-dyn-j1j-8 (under inf-dyn-c5 (pi g1 (inf-lt syt5 16) (inf-le cons0 const5)))
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
 (defvc inf-vc-dyn-t6-4 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-le bct5 64)))
   (given inf-dyn-c5 (lam g1 g2 g3 t5e2)))
; t6-5
 (defvc inf-vc-dyn-t6-5 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-shiftok bct5 ipt5 n)))
   (given inf-dyn-c5 (lam g1 g2 g3 t5e3)))
; t6-6
 (defvc inf-vc-dyn-t6-6 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-bits-inv ipt5 const5 bct5)))
   (given inf-dyn-c5 (lam g1 g2 g3 t5e4)))
; t6-7
 (defvc inf-vc-dyn-t6-7 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-le syt5 16) (inf-le 2 13)))
   (given inf-dyn-c5 (lam g1 g2 g3 (idpath false))))
 (defcx inf-dyn-c11 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-le syt5 16)) (ipt6 nat) (bct6 nat) (bbt6 nat) (const6 nat) (xt6 nat) (t6e1 (inf-le ipt6 n)) (t6e2 (inf-le bct6 64)) (t6e3 (inf-shiftok bct6 ipt6 n)) (t6e4 (inf-bits-inv ipt6 const6 bct6)) (t6e5 (inf-le const5 const6)) (t6e6 (inf-le (add const5 2) const6)) (t6e7 (inf-lt xt6 (inf-pow 2))) )
; s8-1
 (defvc inf-vc-dyn-s8-1 (under inf-dyn-c11 (inf-lt (add xt6 3) (inf-pow w)))
   (given inf-dyn-c11 (inf-wlit (add xt6 3) w gw (inf-letrans (add xt6 3) 6 64 ((inf-addr xt6 3 3 (inf-ltsle xt6 3 t6e7))) (idpath false)))))
; s9-1
 (defvc inf-vc-dyn-s9-1 (under inf-dyn-c11 (inf-lt prev (inf-pow w)))
   (given inf-dyn-c11 (inf-wlit prev w gw (inf-letrans prev 15 64 b1 (idpath false)))))
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
 (defvc inf-vc-dyn-j2j-5 (under inf-dyn-c11 (inf-le bct6 64))
   (given inf-dyn-c11 t6e2))
; j2j-6
 (defvc inf-vc-dyn-j2j-6 (under inf-dyn-c11 (inf-shiftok bct6 ipt6 n))
   (given inf-dyn-c11 t6e3))
; j2j-7
 (defvc inf-vc-dyn-j2j-7 (under inf-dyn-c11 (inf-bits-inv ipt6 const6 bct6))
   (given inf-dyn-c11 t6e4))
; j2j-8
 (defvc inf-vc-dyn-j2j-8 (under inf-dyn-c11 (inf-le cons0 const6))
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
 (defvc inf-vc-dyn-t7-4 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-le bct5 64)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e2)))
; t7-5
 (defvc inf-vc-dyn-t7-5 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-shiftok bct5 ipt5 n)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e3)))
; t7-6
 (defvc inf-vc-dyn-t7-6 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-bits-inv ipt5 const5 bct5)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e4)))
; t7-7
 (defvc inf-vc-dyn-t7-7 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-le syt5 17) (inf-le 3 13)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 (idpath false))))
 (defcx inf-dyn-c10 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-lt 16 syt5)) (g4 (inf-le syt5 17)) (ipt7 nat) (bct7 nat) (bbt7 nat) (const7 nat) (xt7 nat) (t7e1 (inf-le ipt7 n)) (t7e2 (inf-le bct7 64)) (t7e3 (inf-shiftok bct7 ipt7 n)) (t7e4 (inf-bits-inv ipt7 const7 bct7)) (t7e5 (inf-le const5 const7)) (t7e6 (inf-le (add const5 3) const7)) (t7e7 (inf-lt xt7 (inf-pow 3))) )
; s10-1
 (defvc inf-vc-dyn-s10-1 (under inf-dyn-c10 (inf-lt (add xt7 3) (inf-pow w)))
   (given inf-dyn-c10 (inf-wlit (add xt7 3) w gw (inf-letrans (add xt7 3) 10 64 ((inf-addr xt7 7 3 (inf-ltsle xt7 7 t7e7))) (idpath false)))))
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
 (defvc inf-vc-dyn-j3j-4 (under inf-dyn-c10 (inf-le bct7 64))
   (given inf-dyn-c10 t7e2))
; j3j-5
 (defvc inf-vc-dyn-j3j-5 (under inf-dyn-c10 (inf-shiftok bct7 ipt7 n))
   (given inf-dyn-c10 t7e3))
; j3j-6
 (defvc inf-vc-dyn-j3j-6 (under inf-dyn-c10 (inf-bits-inv ipt7 const7 bct7))
   (given inf-dyn-c10 t7e4))
; j3j-7
 (defvc inf-vc-dyn-j3j-7 (under inf-dyn-c10 (inf-le cons0 const7))
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
 (defvc inf-vc-dyn-t8-4 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-le bct5 64)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e2)))
; t8-5
 (defvc inf-vc-dyn-t8-5 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-shiftok bct5 ipt5 n)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e3)))
; t8-6
 (defvc inf-vc-dyn-t8-6 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-bits-inv ipt5 const5 bct5)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 t5e4)))
; t8-7
 (defvc inf-vc-dyn-t8-7 (under inf-dyn-c5 (pi g1 (inf-le 16 syt5) g2 (inf-le syt5 18) g3 (inf-lt 16 syt5) g4 (inf-lt 17 syt5) (inf-le 7 13)))
   (given inf-dyn-c5 (lam g1 g2 g3 g4 (idpath false))))
 (defcx inf-dyn-c9 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-lt 16 syt5)) (g4 (inf-lt 17 syt5)) (ipt8 nat) (bct8 nat) (bbt8 nat) (const8 nat) (xt8 nat) (t8e1 (inf-le ipt8 n)) (t8e2 (inf-le bct8 64)) (t8e3 (inf-shiftok bct8 ipt8 n)) (t8e4 (inf-bits-inv ipt8 const8 bct8)) (t8e5 (inf-le const5 const8)) (t8e6 (inf-le (add const5 7) const8)) (t8e7 (inf-lt xt8 (inf-pow 7))) )
; s11-1
 (defvc inf-vc-dyn-s11-1 (under inf-dyn-c9 (inf-lt (add xt8 11) (inf-pow w)))
   (given inf-dyn-c9 (inf-lelt (add xt8 11) 512 (inf-pow w) (inf-letrans (add xt8 11) 138 512 ((inf-addr xt8 127 11 (inf-ltsle xt8 127 t8e7))) (idpath false)) (inf-lttrans 512 1024 (inf-pow w) (idpath true) (inf-powle 10 w (inf-letrans 10 32 w (idpath false) gw))))))
; j3j-8
 (defvc inf-vc-dyn-j3j-8 (under inf-dyn-c9 (inf-lt 0 (add xt8 11)))
   (given inf-dyn-c9 (inf-pos3 xt8 11 (idpath true))))
; j3j-9
 (defvc inf-vc-dyn-j3j-9 (under inf-dyn-c9 (inf-le (add xt8 11) 138))
   (given inf-dyn-c9 ((inf-addr xt8 127 11 (inf-ltsle xt8 127 t8e7)))))
; j3j-10
 (defvc inf-vc-dyn-j3j-10 (under inf-dyn-c9 (inf-le ipt8 n))
   (given inf-dyn-c9 t8e1))
; j3j-11
 (defvc inf-vc-dyn-j3j-11 (under inf-dyn-c9 (inf-le bct8 64))
   (given inf-dyn-c9 t8e2))
; j3j-12
 (defvc inf-vc-dyn-j3j-12 (under inf-dyn-c9 (inf-shiftok bct8 ipt8 n))
   (given inf-dyn-c9 t8e3))
; j3j-13
 (defvc inf-vc-dyn-j3j-13 (under inf-dyn-c9 (inf-bits-inv ipt8 const8 bct8))
   (given inf-dyn-c9 t8e4))
; j3j-14
 (defvc inf-vc-dyn-j3j-14 (under inf-dyn-c9 (inf-le cons0 const8))
   (given inf-dyn-c9 (inf-letrans cons0 const5 const8 (inf-letrans cons0 cons const5 r5 t5e5) t8e5)))
 (defcx inf-dyn-c8 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (g3 (inf-lt 16 syt5)) (xj3 nat) (ipj3 nat) (bcj3 nat) (bbj3 nat) (consj3 nat) (rrj3 nat) (f1 (inf-lt 0 rrj3)) (f2 (inf-le rrj3 138)) (r1 (inf-le ipj3 n)) (r2 (inf-le bcj3 64)) (r3 (inf-shiftok bcj3 ipj3 n)) (r4 (inf-bits-inv ipj3 consj3 bcj3)) (r5 (inf-le cons0 consj3)) )
; s12-1
 (defvc inf-vc-dyn-s12-1 (under inf-dyn-c8 (inf-lt 0 (inf-pow w)))
   (given inf-dyn-c8 (inf-wlit 0 w gw (idpath false))))
; j2j-9
 (defvc inf-vc-dyn-j2j-9 (under inf-dyn-c8 (inf-lt 0 rrj3))
   (given inf-dyn-c8 f1))
; j2j-10
 (defvc inf-vc-dyn-j2j-10 (under inf-dyn-c8 (inf-le rrj3 138))
   (given inf-dyn-c8 f2))
; j2j-11
 (defvc inf-vc-dyn-j2j-11 (under inf-dyn-c8 (inf-le 0 15))
   (given inf-dyn-c8 (idpath false)))
; j2j-12
 (defvc inf-vc-dyn-j2j-12 (under inf-dyn-c8 (inf-le ipj3 n))
   (given inf-dyn-c8 r1))
; j2j-13
 (defvc inf-vc-dyn-j2j-13 (under inf-dyn-c8 (inf-le bcj3 64))
   (given inf-dyn-c8 r2))
; j2j-14
 (defvc inf-vc-dyn-j2j-14 (under inf-dyn-c8 (inf-shiftok bcj3 ipj3 n))
   (given inf-dyn-c8 r3))
; j2j-15
 (defvc inf-vc-dyn-j2j-15 (under inf-dyn-c8 (inf-bits-inv ipj3 consj3 bcj3))
   (given inf-dyn-c8 r4))
; j2j-16
 (defvc inf-vc-dyn-j2j-16 (under inf-dyn-c8 (inf-le cons0 consj3))
   (given inf-dyn-c8 r5))
 (defcx inf-dyn-c7 inf-dyn-c5 (g1 (inf-le 16 syt5)) (g2 (inf-le syt5 18)) (xj2 nat) (ipj2 nat) (bcj2 nat) (bbj2 nat) (consj2 nat) (rrj2 nat) (vj2 nat) (f3 (inf-lt 0 rrj2)) (f4 (inf-le rrj2 138)) (f5 (inf-le vj2 15)) (r1 (inf-le ipj2 n)) (r2 (inf-le bcj2 64)) (r3 (inf-shiftok bcj2 ipj2 n)) (r4 (inf-bits-inv ipj2 consj2 bcj2)) (r5 (inf-le cons0 consj2)) )
; j1j-9
 (defvc inf-vc-dyn-j1j-9 (under inf-dyn-c7 (inf-lt 0 rrj2))
   (given inf-dyn-c7 f3))
; j1j-10
 (defvc inf-vc-dyn-j1j-10 (under inf-dyn-c7 (inf-le rrj2 138))
   (given inf-dyn-c7 f4))
; j1j-11
 (defvc inf-vc-dyn-j1j-11 (under inf-dyn-c7 (inf-le vj2 15))
   (given inf-dyn-c7 f5))
; j1j-12
 (defvc inf-vc-dyn-j1j-12 (under inf-dyn-c7 (inf-le ipj2 n))
   (given inf-dyn-c7 r1))
; j1j-13
 (defvc inf-vc-dyn-j1j-13 (under inf-dyn-c7 (inf-le bcj2 64))
   (given inf-dyn-c7 r2))
; j1j-14
 (defvc inf-vc-dyn-j1j-14 (under inf-dyn-c7 (inf-shiftok bcj2 ipj2 n))
   (given inf-dyn-c7 r3))
; j1j-15
 (defvc inf-vc-dyn-j1j-15 (under inf-dyn-c7 (inf-bits-inv ipj2 consj2 bcj2))
   (given inf-dyn-c7 r4))
; j1j-16
 (defvc inf-vc-dyn-j1j-16 (under inf-dyn-c7 (inf-le cons0 consj2))
   (given inf-dyn-c7 r5))
 (defcx inf-dyn-c6 inf-dyn-c5 (rrj1 nat) (vj1 nat) (xj1 nat) (ipj1 nat) (bcj1 nat) (bbj1 nat) (consj1 nat) (f6 (inf-lt 0 rrj1)) (f7 (inf-le rrj1 138)) (f8 (inf-le vj1 15)) (r1 (inf-le ipj1 n)) (r2 (inf-le bcj1 64)) (r3 (inf-shiftok bcj1 ipj1 n)) (r4 (inf-bits-inv ipj1 consj1 bcj1)) (r5 (inf-le cons0 consj1)) )
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
   (given inf-dyn-c6-w3 (lam w3 g5 (inf-wlit vj1 w gw (inf-letrans vj1 15 64 f8 (idpath false))))))
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
   (given inf-dyn-c6-w3 (lam w3 (inf-wlit vj1 w gw (inf-letrans vj1 15 64 f8 (idpath false))))))
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
 (defvc inf-vc-dyn-w2b-4 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-le bcj1 64)))
   (given inf-dyn-c6-w3 (lam w3 r2)))
; w2b-5
 (defvc inf-vc-dyn-w2b-5 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-shiftok bcj1 ipj1 n)))
   (given inf-dyn-c6-w3 (lam w3 r3)))
; w2b-6
 (defvc inf-vc-dyn-w2b-6 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-bits-inv ipj1 consj1 bcj1)))
   (given inf-dyn-c6-w3 (lam w3 r4)))
; w2b-7
 (defvc inf-vc-dyn-w2b-7 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-le cons0 consj1)))
   (given inf-dyn-c6-w3 (lam w3 r5)))
; w2b-8
 (defvc inf-vc-dyn-w2b-8 (under inf-dyn-c6-w3 (pi w3 (inf-le rrj1 k) (inf-lt (natminus (add (add xt1 257) (add xt2 1)) (add i rrj1)) (natminus (add (add xt1 257) (add xt2 1)) i))))
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
 (defvc inf-vc-dyn-r2-2 (under inf-dyn-c13 (inf-le bc 64))
   (given inf-dyn-c13 r2))
; r2-3
 (defvc inf-vc-dyn-r2-3 (under inf-dyn-c13 (inf-shiftok bc ip n))
   (given inf-dyn-c13 r3))
; r2-4
 (defvc inf-vc-dyn-r2-4 (under inf-dyn-c13 (inf-bits-inv ip cons bc))
   (given inf-dyn-c13 r4))
; r2-5
 (defvc inf-vc-dyn-r2-5 (under inf-dyn-c13 (inf-le cons0 cons))
   (given inf-dyn-c13 r5))
; r2-6
 (defvc inf-vc-dyn-r2-6 (under inf-dyn-c13 (pi k nat (inf-lt (Lcc4 k) (inf-pow h))))
   (given inf-dyn-c13 c4e1))
; r2-7
 (defvc inf-vc-dyn-r2-7 (under inf-dyn-c13 (pi k nat (inf-lt (Lsc4 k) (inf-pow h))))
   (given inf-dyn-c13 c4e2))
; r2-8
 (defvc inf-vc-dyn-r2-8 (under inf-dyn-c13 (inf-le (inf-sum Lcc4 15 1) (add xt1 257)))
   (given inf-dyn-c13 c4e3))
; r2-9
 (defvc inf-vc-dyn-r2-9 (under inf-dyn-c13 (inf-le (add xt1 257) 288))
   (given inf-dyn-c13 ((inf-addr xt1 31 257 (inf-ltsle xt1 31 t1e7)))))
; r2-10
 (defvc inf-vc-dyn-r2-10 (under inf-dyn-c13 (pi k nat (inf-lt (Dcc5 k) (inf-pow h))))
   (given inf-dyn-c13 c5e1))
; r2-11
 (defvc inf-vc-dyn-r2-11 (under inf-dyn-c13 (pi k nat (inf-lt (Dsc5 k) (inf-pow h))))
   (given inf-dyn-c13 c5e2))
; r2-12
 (defvc inf-vc-dyn-r2-12 (under inf-dyn-c13 (inf-le (inf-sum Dcc5 15 1) (add xt2 1)))
   (given inf-dyn-c13 c5e3))
; r2-13
 (defvc inf-vc-dyn-r2-13 (under inf-dyn-c13 (inf-le (add xt2 1) 32))
   (given inf-dyn-c13 ((inf-addr xt2 31 1 (inf-ltsle xt2 31 t2e7)))))
 (defcx inf-fast (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gb (inf-le bc0 64)) (gs (inf-shiftok bc0 ip0 n)) (ga (inf-bits-inv ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gcf (inf-lt (add cap 266) (inf-pow w))) (Lt (pi k nat nat)) (Dt (pi k nat nat)) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (h nat) (LROOT nat) (DROOT nat) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16)) (gz (inf-lt 0 out)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) )
; w1e-1
 (defvc inf-vc-fast-w1e-1 (under inf-fast (inf-le ip0 n))
   (given inf-fast gi))
; w1e-2
 (defvc inf-vc-fast-w1e-2 (under inf-fast (inf-le bc0 64))
   (given inf-fast gb))
; w1e-3
 (defvc inf-vc-fast-w1e-3 (under inf-fast (inf-shiftok bc0 ip0 n))
   (given inf-fast gs))
; w1e-4
 (defvc inf-vc-fast-w1e-4 (under inf-fast (inf-bits-inv ip0 cons0 bc0))
   (given inf-fast ga))
; w1e-5
 (defvc inf-vc-fast-w1e-5 (under inf-fast (inf-le cons0 cons0))
   (given inf-fast (inf-refl cons0)))
; w1e-6
 (defvc inf-vc-fast-w1e-6 (under inf-fast (inf-le op0 op0))
   (given inf-fast (inf-refl op0)))
; w1e-7
 (defvc inf-vc-fast-w1e-7 (under inf-fast (inf-le op0 cap))
   (given inf-fast gop))
 (defcx inf-fast-w1 inf-fast (ans nat) (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (j1 (inf-le ip n)) (j2 (inf-le bc 64)) (j3 (inf-shiftok bc ip n)) (j4 (inf-bits-inv ip cons bc)) (j5 (inf-le cons0 cons)) (j6 (inf-le op0 op)) (j7 (inf-le op cap)) )
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
 (defvc inf-vc-fast-r4-2 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-le bc 64)))
   (given inf-fast-w1 (lam w1 g1 g2 j2)))
; r4-3
 (defvc inf-vc-fast-r4-3 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-shiftok bc ip n)))
   (given inf-fast-w1 (lam w1 g1 g2 j3)))
; r4-4
 (defvc inf-vc-fast-r4-4 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-bits-inv ip cons bc)))
   (given inf-fast-w1 (lam w1 g1 g2 j4)))
; r4-5
 (defvc inf-vc-fast-r4-5 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-le cons0 cons)))
   (given inf-fast-w1 (lam w1 g1 g2 j5)))
; r4-6
 (defvc inf-vc-fast-r4-6 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-le op cap)))
   (given inf-fast-w1 (lam w1 g1 g2 j7)))
; r4-7
 (defvc inf-vc-fast-r4-7 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-lt n (add ip 8)) (inf-le op0 op)))
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
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 ((inf-letrans bc 15 63 (inf-ltle bc 15 g1) (idpath false))))))
; f3-2
 (defvc inf-vc-fast-f3-2 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-lt (add 56 (inf-mod 8 bc)) (inf-pow w))))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-wlit (add 56 (inf-mod 8 bc)) w gw ((inf-addl 56 (inf-mod 8 bc) 8 (inf-ltle (inf-mod 8 bc) 8 (inf-modlt 7 bc))))))))
; i1j-1
 (defvc inf-vc-fast-i1j-1 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-le (add ip (natminus 7 (inf-div8 bc))) n)))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 ((inf-letrans ((add ip ((natminus 7 (inf-div8 bc))))) (add ip 8) n (inf-addl ip ((natminus 7 (inf-div8 bc))) 8 (inf-letrans ((natminus 7 (inf-div8 bc))) 7 8 (inf-suble 7 (inf-div8 bc)) (idpath false))) g2)))))
; i1j-2
 (defvc inf-vc-fast-i1j-2 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-le (add 56 (inf-mod 8 bc)) 64)))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 ((inf-addl 56 (inf-mod 8 bc) 8 (inf-ltle (inf-mod 8 bc) 8 (inf-modlt 7 bc)))))))
; i1j-3
 (defvc inf-vc-fast-i1j-3 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-shiftok (add 56 (inf-mod 8 bc)) (add ip (natminus 7 (inf-div8 bc))) n)))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-shiftwide bc ((add ip ((natminus 7 (inf-div8 bc))))) n))))
; i1j-4
 (defvc inf-vc-fast-i1j-4 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-bits-inv (add ip (natminus 7 (inf-div8 bc))) cons (add 56 (inf-mod 8 bc)))))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-fillw ip cons bc ((inf-letrans bc 15 63 (inf-ltle bc 15 g1) (idpath false))) j4))))
; i1j-5
 (defvc inf-vc-fast-i1j-5 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-lt bc 15) g2 (inf-le (add ip 8) n) bbf1 nat (inf-le 15 (add 56 (inf-mod 8 bc)))))
   (given inf-fast-w1 (lam w1 g1 g2 bbf1 (inf-letrans 15 56 (add 56 (inf-mod 8 bc)) (idpath false) (inf-leaddr 56 (inf-mod 8 bc))))))
; i1j-6
 (defvc inf-vc-fast-i1j-6 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc) (inf-le ip n)))
   (given inf-fast-w1 (lam w1 g1 j1)))
; i1j-7
 (defvc inf-vc-fast-i1j-7 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc) (inf-le bc 64)))
   (given inf-fast-w1 (lam w1 g1 j2)))
; i1j-8
 (defvc inf-vc-fast-i1j-8 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc) (inf-shiftok bc ip n)))
   (given inf-fast-w1 (lam w1 g1 j3)))
; i1j-9
 (defvc inf-vc-fast-i1j-9 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc) (inf-bits-inv ip cons bc)))
   (given inf-fast-w1 (lam w1 g1 j4)))
; i1j-10
 (defvc inf-vc-fast-i1j-10 (under inf-fast-w1 (pi w1 (inf-le (add op 266) cap) g1 (inf-le 15 bc) (inf-le 15 bc)))
   (given inf-fast-w1 (lam w1 g1 g1)))
 (defcx inf-fast-c1 inf-fast-w1 (w1 (inf-le (add op 266) cap)) (bbi1 nat) (ipi1 nat) (bci1 nat) (h1 (inf-le ipi1 n)) (h2 (inf-le bci1 64)) (h3 (inf-shiftok bci1 ipi1 n)) (h4 (inf-bits-inv ipi1 cons bci1)) (h5 (inf-le 15 bci1)) )
; d1-1
 (defvc inf-vc-fast-d1-1 (under inf-fast-c1 (inf-lt LROOT 32))
   (given inf-fast-c1 (inf-lelt LROOT 15 32 gl (idpath true))))
; d1-2
 (defvc inf-vc-fast-d1-2 (under inf-fast-c1 (inf-lt (inf-mod (inf-pow LROOT) bbi1) (inf-pow LROOT)))
   (given inf-fast-c1 (inf-masklt bbi1 LROOT)))
; r4-8
 (defvc inf-vc-fast-r4-8 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 h1)))
; r4-9
 (defvc inf-vc-fast-r4-9 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le bci1 64)))
   (given inf-fast-c1 (lam ed1 g3 h2)))
; r4-10
 (defvc inf-vc-fast-r4-10 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-shiftok bci1 ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 h3)))
; r4-11
 (defvc inf-vc-fast-r4-11 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-bits-inv ipi1 cons bci1)))
   (given inf-fast-c1 (lam ed1 g3 h4)))
; r4-12
 (defvc inf-vc-fast-r4-12 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le cons0 cons)))
   (given inf-fast-c1 (lam ed1 g3 j5)))
; r4-13
 (defvc inf-vc-fast-r4-13 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le op cap)))
   (given inf-fast-c1 (lam ed1 g3 j7)))
; r4-14
 (defvc inf-vc-fast-r4-14 (under inf-fast-c1 (pi ed1 nat g3 (paths nat ed1 0) (inf-le op0 op)))
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
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-wlit ((natminus bci1 ((inf-mod 16 ed1)))) w gw (inf-letrans ((natminus bci1 ((inf-mod 16 ed1)))) bci1 64 (inf-suble bci1 ((inf-mod 16 ed1))) h2)))))
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
 (defvc inf-vc-fast-w1b-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le (natminus bci1 (inf-mod 16 ed1)) 64)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-letrans ((natminus bci1 ((inf-mod 16 ed1)))) bci1 64 (inf-suble bci1 ((inf-mod 16 ed1))) h2))))
; w1b-3
 (defvc inf-vc-fast-w1b-3 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-shiftok (natminus bci1 (inf-mod 16 ed1)) ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-shifttake bci1 ipi1 n ((inf-mod 16 ed1)) h3))))
; w1b-4
 (defvc inf-vc-fast-w1b-4 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-bits-inv ipi1 (add cons (inf-mod 16 ed1)) (natminus bci1 (inf-mod 16 ed1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-take ipi1 cons bci1 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5)) h4))))
; w1b-5
 (defvc inf-vc-fast-w1b-5 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le cons0 (add cons (inf-mod 16 ed1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1)))))))
; w1b-6
 (defvc inf-vc-fast-w1b-6 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le op0 (add op 1))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-letrans op0 op (add op 1) j6 (inf-leaddr op 1)))))
; w1b-7
 (defvc inf-vc-fast-w1b-7 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-le (add op 1) cap)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-lt1 op cap ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1))))))
; w1b-8
 (defvc inf-vc-fast-w1b-8 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-lt syd2 256) bbd3 nat (inf-lt (natminus cap (add op 1)) (natminus cap op))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 bbd3 (inf-subfall1 cap op ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1))))))
; d6-1
 (defvc inf-vc-fast-d6-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) (inf-lt (inf-mod 16 ed1) 64)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 ((inf-lttrans ((inf-mod 16 ed1)) 16 64 ((inf-modlt 15 ed1)) (idpath false))))))
; d7-1
 (defvc inf-vc-fast-d7-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le (inf-mod 16 ed1) bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5)))))
; d7-2
 (defvc inf-vc-fast-d7-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-lt (natminus bci1 (inf-mod 16 ed1)) (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-wlit ((natminus bci1 ((inf-mod 16 ed1)))) w gw (inf-letrans ((natminus bci1 ((inf-mod 16 ed1)))) bci1 64 (inf-suble bci1 ((inf-mod 16 ed1))) h2)))))
; s2-1
 (defvc inf-vc-fast-s2-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-lt 1 (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-wlit 1 w gw (idpath false)))))
; r4-15
 (defvc inf-vc-fast-r4-15 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 h1)))
; r4-16
 (defvc inf-vc-fast-r4-16 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le (natminus bci1 (inf-mod 16 ed1)) 64)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-letrans ((natminus bci1 ((inf-mod 16 ed1)))) bci1 64 (inf-suble bci1 ((inf-mod 16 ed1))) h2))))
; r4-17
 (defvc inf-vc-fast-r4-17 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-shiftok (natminus bci1 (inf-mod 16 ed1)) ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-shifttake bci1 ipi1 n ((inf-mod 16 ed1)) h3))))
; r4-18
 (defvc inf-vc-fast-r4-18 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-bits-inv ipi1 (add cons (inf-mod 16 ed1)) (natminus bci1 (inf-mod 16 ed1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-take ipi1 cons bci1 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci1 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) h5)) h4))))
; r4-19
 (defvc inf-vc-fast-r4-19 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le cons0 (add cons (inf-mod 16 ed1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1)))))))
; r4-20
 (defvc inf-vc-fast-r4-20 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le op cap)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 j7)))
; r4-21
 (defvc inf-vc-fast-r4-21 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-le syd2 256) bbd6 nat (inf-le op0 op)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 bbd6 j6)))
; i8-1
 (defvc inf-vc-fast-i8-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) (inf-lt (add ipi1 8) (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 (inf-lelt (add ipi1 8) (add n 8) (inf-pow w) (inf-addr ipi1 n 8 h1) gn))))
; r4-22
 (defvc inf-vc-fast-r4-22 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 h1)))
; r4-23
 (defvc inf-vc-fast-r4-23 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le bci1 64)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 h2)))
; r4-24
 (defvc inf-vc-fast-r4-24 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-shiftok bci1 ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 h3)))
; r4-25
 (defvc inf-vc-fast-r4-25 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-bits-inv ipi1 cons bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 h4)))
; r4-26
 (defvc inf-vc-fast-r4-26 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le cons0 cons)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 j5)))
; r4-27
 (defvc inf-vc-fast-r4-27 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le op cap)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 j7)))
; r4-28
 (defvc inf-vc-fast-r4-28 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-lt n (add ipi1 8)) (inf-le op0 op)))
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
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 ((inf-letrans bci1 48 63 (inf-ltle bci1 48 g7) (idpath false))))))
; f6-2
 (defvc inf-vc-fast-f6-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-lt (add 56 (inf-mod 8 bci1)) (inf-pow w))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-wlit (add 56 (inf-mod 8 bci1)) w gw ((inf-addl 56 (inf-mod 8 bci1) 8 (inf-ltle (inf-mod 8 bci1) 8 (inf-modlt 7 bci1))))))))
; i7j-1
 (defvc inf-vc-fast-i7j-1 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-le (add ipi1 (natminus 7 (inf-div8 bci1))) n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 ((inf-letrans ((add ipi1 ((natminus 7 (inf-div8 bci1))))) (add ipi1 8) n (inf-addl ipi1 ((natminus 7 (inf-div8 bci1))) 8 (inf-letrans ((natminus 7 (inf-div8 bci1))) 7 8 (inf-suble 7 (inf-div8 bci1)) (idpath false))) g8)))))
; i7j-2
 (defvc inf-vc-fast-i7j-2 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-le (add 56 (inf-mod 8 bci1)) 64)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 ((inf-addl 56 (inf-mod 8 bci1) 8 (inf-ltle (inf-mod 8 bci1) 8 (inf-modlt 7 bci1)))))))
; i7j-3
 (defvc inf-vc-fast-i7j-3 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-shiftok (add 56 (inf-mod 8 bci1)) (add ipi1 (natminus 7 (inf-div8 bci1))) n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-shiftwide bci1 ((add ipi1 ((natminus 7 (inf-div8 bci1))))) n))))
; i7j-4
 (defvc inf-vc-fast-i7j-4 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-bits-inv (add ipi1 (natminus 7 (inf-div8 bci1))) cons (add 56 (inf-mod 8 bci1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-fillw ipi1 cons bci1 ((inf-letrans bci1 48 63 (inf-ltle bci1 48 g7) (idpath false))) h4))))
; i7j-5
 (defvc inf-vc-fast-i7j-5 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-lt bci1 48) g8 (inf-le (add ipi1 8) n) bbf4 nat (inf-le 48 (add 56 (inf-mod 8 bci1)))))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g8 bbf4 (inf-letrans 48 56 (add 56 (inf-mod 8 bci1)) (idpath false) (inf-leaddr 56 (inf-mod 8 bci1))))))
; i7j-6
 (defvc inf-vc-fast-i7j-6 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1) (inf-le ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 h1)))
; i7j-7
 (defvc inf-vc-fast-i7j-7 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1) (inf-le bci1 64)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 h2)))
; i7j-8
 (defvc inf-vc-fast-i7j-8 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1) (inf-shiftok bci1 ipi1 n)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 h3)))
; i7j-9
 (defvc inf-vc-fast-i7j-9 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1) (inf-bits-inv ipi1 cons bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 h4)))
; i7j-10
 (defvc inf-vc-fast-i7j-10 (under inf-fast-c1 (pi ed1 nat g3 (inf-lt 0 ed1) syd2 nat g4 (inf-le 256 syd2) g5 (inf-lt 256 syd2) g6 (inf-le syd2 285) g7 (inf-le 48 bci1) (inf-le 48 bci1)))
   (given inf-fast-c1 (lam ed1 g3 syd2 g4 g5 g6 g7 g7)))
 (defcx inf-fast-c2 inf-fast-c1 (ed1 nat) (g3 (inf-lt 0 ed1)) (syd2 nat) (g4 (inf-le 256 syd2)) (g5 (inf-lt 256 syd2)) (g6 (inf-le syd2 285)) (bbi7 nat) (ipi7 nat) (bci7 nat) (m1 (inf-le ipi7 n)) (m2 (inf-le bci7 64)) (m3 (inf-shiftok bci7 ipi7 n)) (m4 (inf-bits-inv ipi7 cons bci7)) (m5 (inf-le 48 bci7)) )
; d9-1
 (defvc inf-vc-fast-d9-1 (under inf-fast-c2 (inf-le 257 syd2))
   (given inf-fast-c2 ((inf-ltsu 256 syd2 g5))))
; d9-2
 (defvc inf-vc-fast-d9-2 (under inf-fast-c2 (inf-lt (natminus syd2 257) 29))
   (given inf-fast-c2 ((inf-lidx syd2 g6))))
; d9-3
 (defvc inf-vc-fast-d9-3 (under inf-fast-c2 (inf-lt (Le (natminus syd2 257)) (inf-pow w)))
   (given inf-fast-c2 (inf-wlit ((Le ((natminus syd2 257)))) w gw (inf-letrans ((Le ((natminus syd2 257)))) 5 64 ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) (idpath false)))))
; d10-1
 (defvc inf-vc-fast-d10-1 (under inf-fast-c2 (inf-lt (add (inf-mod 16 ed1) (Le (natminus syd2 257))) (inf-pow w)))
   (given inf-fast-c2 (inf-wlit (add ((inf-mod 16 ed1)) ((Le ((natminus syd2 257))))) w gw (inf-letrans (add ((inf-mod 16 ed1)) ((Le ((natminus syd2 257))))) 20 64 (inf-add2 ((inf-mod 16 ed1)) 15 ((Le ((natminus syd2 257)))) 5 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6))))) (idpath false)))))
; d10-2
 (defvc inf-vc-fast-d10-2 (under inf-fast-c2 (inf-lt (add (inf-mod 16 ed1) (Le (natminus syd2 257))) 64))
   (given inf-fast-c2 (inf-lelt (add ((inf-mod 16 ed1)) ((Le ((natminus syd2 257))))) 20 64 (inf-add2 ((inf-mod 16 ed1)) 15 ((Le ((natminus syd2 257)))) 5 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6))))) (idpath true))))
; d11-1
 (defvc inf-vc-fast-d11-1 (under inf-fast-c2 (pi yd10 nat (inf-lt DROOT 32)))
   (given inf-fast-c2 (lam yd10 (inf-lelt DROOT 15 32 gd (idpath true)))))
; d11-2
 (defvc inf-vc-fast-d11-2 (under inf-fast-c2 (pi yd10 nat (inf-lt (inf-mod (inf-pow DROOT) yd10) (inf-pow DROOT))))
   (given inf-fast-c2 (lam yd10 (inf-masklt yd10 DROOT))))
; r4-29
 (defvc inf-vc-fast-r4-29 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le ipi7 n)))
   (given inf-fast-c2 (lam yd10 fd11 g9 m1)))
; r4-30
 (defvc inf-vc-fast-r4-30 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le bci7 64)))
   (given inf-fast-c2 (lam yd10 fd11 g9 m2)))
; r4-31
 (defvc inf-vc-fast-r4-31 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-shiftok bci7 ipi7 n)))
   (given inf-fast-c2 (lam yd10 fd11 g9 m3)))
; r4-32
 (defvc inf-vc-fast-r4-32 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-bits-inv ipi7 cons bci7)))
   (given inf-fast-c2 (lam yd10 fd11 g9 m4)))
; r4-33
 (defvc inf-vc-fast-r4-33 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le cons0 cons)))
   (given inf-fast-c2 (lam yd10 fd11 g9 j5)))
; r4-34
 (defvc inf-vc-fast-r4-34 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le op cap)))
   (given inf-fast-c2 (lam yd10 fd11 g9 j7)))
; r4-35
 (defvc inf-vc-fast-r4-35 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (paths nat fd11 0) (inf-le op0 op)))
   (given inf-fast-c2 (lam yd10 fd11 g9 j6)))
; d12-1
 (defvc inf-vc-fast-d12-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) (inf-lt (inf-mod 16 ed1) 64)))
   (given inf-fast-c2 (lam yd10 fd11 g9 ((inf-lttrans ((inf-mod 16 ed1)) 16 64 ((inf-modlt 15 ed1)) (idpath false))))))
; d13-1
 (defvc inf-vc-fast-d13-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat (inf-le (inf-mod 16 ed1) bci7)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5))))))
; d13-2
 (defvc inf-vc-fast-d13-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat (inf-lt (natminus bci7 (inf-mod 16 ed1)) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 (inf-wlit ((natminus bci7 ((inf-mod 16 ed1)))) w gw (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 64 (inf-suble bci7 ((inf-mod 16 ed1))) m2)))))
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
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 (inf-wlit ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) w gw (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 64 64 (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 64 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 64 (inf-suble bci7 ((inf-mod 16 ed1))) m2)) (idpath false))))))
; d19-1
 (defvc inf-vc-fast-d19-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat (inf-lt (inf-mod 16 fd11) 64)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 (inf-lttrans ((inf-mod 16 fd11)) 16 64 ((inf-modlt 15 fd11)) (idpath false)))))
; d20-1
 (defvc inf-vc-fast-d20-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat (inf-le (inf-mod 16 fd11) (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5)))))
; d20-2
 (defvc inf-vc-fast-d20-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat (inf-lt (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 (inf-wlit ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) w gw (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 64 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 64 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 64 (inf-suble bci7 ((inf-mod 16 ed1))) m2)))))))
; d22-1
 (defvc inf-vc-fast-d22-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat (inf-lt 4 64)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 (idpath true))))
; d23-1
 (defvc inf-vc-fast-d23-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) (inf-lt syd22 30)))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 ((inf-lelts syd22 29 g10)))))
; d23-2
 (defvc inf-vc-fast-d23-2 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) (inf-lt (De syd22) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 (inf-wlit ((De syd22)) w gw (inf-letrans ((De syd22)) 13 64 ((hde syd22 ((inf-lelts syd22 29 g10)))) (idpath false))))))
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
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 (inf-wlit ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) w gw (inf-letrans ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) 64 (inf-suble ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))) (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 64 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 64 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 64 (inf-suble bci7 ((inf-mod 16 ed1))) m2))))))))
; i12-1
 (defvc inf-vc-fast-i12-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) (inf-lt (add op nd) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 (inf-lelt (add op nd) (add cap nd) (inf-pow w) (inf-addr op cap nd j7) gnd))))
; s3-1
 (defvc inf-vc-fast-s3-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) (inf-lt (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)) (inf-pow w))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 ((inf-lelt ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 (inf-pow w) ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) ((inf-lelt 258 512 (inf-pow w) (idpath false) ((inf-wnine w gw)))))))))
; j8-1
 (defvc inf-vc-fast-j8-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) (inf-le op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 (inf-ltle op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) g11))))
; s4-1
 (defvc inf-vc-fast-s4-1 (under inf-fast-c2 (pi yd10 nat fd11 nat g9 (inf-lt 0 fd11) bbd12 nat bbd16 nat bbd19 nat syd22 nat g10 (inf-le syd22 29) bbd25 nat g11 (inf-lt op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19))) g12 (inf-le (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) (add op nd)) g13 (inf-lt (natminus (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) op) (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) (inf-le op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)))))
   (given inf-fast-c2 (lam yd10 fd11 g9 bbd12 bbd16 bbd19 syd22 g10 bbd25 g11 g12 g13 (inf-ltle op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) g11))))
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
   (given inf-fast-c6 (inf-ltle op (add (Db syd22) (inf-mod (inf-pow (De syd22)) bbd19)) g11)))
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
; w1b-9
 (defvc inf-vc-fast-w1b-9 (under inf-fast-c3 (inf-le ipi7 n))
   (given inf-fast-c3 m1))
; w1b-10
 (defvc inf-vc-fast-w1b-10 (under inf-fast-c3 (inf-le (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) 64))
   (given inf-fast-c3 (inf-letrans ((natminus ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) 64 (inf-suble ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))) (inf-letrans ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) 64 (inf-suble ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11))) (inf-letrans ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus bci7 ((inf-mod 16 ed1)))) 64 (inf-suble ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257))))) (inf-letrans ((natminus bci7 ((inf-mod 16 ed1)))) bci7 64 (inf-suble bci7 ((inf-mod 16 ed1))) m2))))))
; w1b-11
 (defvc inf-vc-fast-w1b-11 (under inf-fast-c3 (inf-shiftok (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) ipi7 n))
   (given inf-fast-c3 (inf-shifttake ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ipi7 n ((De syd22)) (inf-shifttake ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ipi7 n ((inf-mod 16 fd11)) (inf-shifttake ((natminus bci7 ((inf-mod 16 ed1)))) ipi7 n ((Le ((natminus syd2 257)))) (inf-shifttake bci7 ipi7 n ((inf-mod 16 ed1)) m3))))))
; w1b-12
 (defvc inf-vc-fast-w1b-12 (under inf-fast-c3 (inf-bits-inv ipi7 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22)) (natminus (natminus (natminus (natminus bci7 (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22))))
   (given inf-fast-c3 (inf-take ipi7 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((natminus ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)) ((inf-fastb3 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) ((De syd22)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) ((hde syd22 ((inf-lelts syd22 29 g10)))) m5)) (inf-take ipi7 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((natminus ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)) ((inf-fastb2 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) ((inf-mod 16 fd11)) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) ((inf-ltsle ((inf-mod 16 fd11)) 15 ((inf-modlt 15 fd11)))) m5)) (inf-take ipi7 ((add cons ((inf-mod 16 ed1)))) ((natminus bci7 ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))) ((inf-fastb1 ((inf-mod 16 ed1)) ((Le ((natminus syd2 257)))) bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) ((hle ((natminus syd2 257)) ((inf-lidx syd2 g6)))) m5)) (inf-take ipi7 cons bci7 ((inf-mod 16 ed1)) ((inf-letrans ((inf-mod 16 ed1)) 15 bci7 ((inf-ltsle ((inf-mod 16 ed1)) 15 ((inf-modlt 15 ed1)))) (inf-letrans 15 48 bci7 (idpath false) m5))) m4))))))
; w1b-13
 (defvc inf-vc-fast-w1b-13 (under inf-fast-c3 (inf-le cons0 (add (add (add (add cons (inf-mod 16 ed1)) (Le (natminus syd2 257))) (inf-mod 16 fd11)) (De syd22))))
   (given inf-fast-c3 (inf-letrans cons0 ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((add ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22)))) (inf-letrans cons0 ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-letrans cons0 ((add cons ((inf-mod 16 ed1)))) ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-letrans cons0 cons ((add cons ((inf-mod 16 ed1)))) j5 (inf-leaddr cons ((inf-mod 16 ed1)))) (inf-leaddr ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) (inf-leaddr ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) (inf-leaddr ((add ((add ((add cons ((inf-mod 16 ed1)))) ((Le ((natminus syd2 257)))))) ((inf-mod 16 fd11)))) ((De syd22))))))
; w1b-14
 (defvc inf-vc-fast-w1b-14 (under inf-fast-c3 (inf-le op0 (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))))
   (given inf-fast-c3 (inf-letrans op0 op (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) j6 (inf-leaddr op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))))))
; w1b-15
 (defvc inf-vc-fast-w1b-15 (under inf-fast-c3 (inf-le (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12))) cap))
   (given inf-fast-c3 ((inf-letrans (add op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12)))) (add op 266) cap (inf-addl op ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 266 (inf-letrans ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 266 ((inf-ltsle ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) 258 ((inf-baseadd (Lb ((natminus syd2 257))) ((Le ((natminus syd2 257)))) bbd12 259 (hlb ((natminus syd2 257)) ((inf-lidx syd2 g6))))))) (idpath false))) w1))))
; w1b-16
 (defvc inf-vc-fast-w1b-16 (under inf-fast-c3 (inf-lt (natminus cap (add op (add (Lb (natminus syd2 257)) (inf-mod (inf-pow (Le (natminus syd2 257))) bbd12)))) (natminus cap op)))
   (given inf-fast-c3 (inf-subby op cap ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) ((inf-lttrans op (add op 266) cap (inf-ltaddpos op 266 (idpath true)) w1)) ((inf-lttrans 0 3 ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (idpath true) (inf-letrans 3 (Lb ((natminus syd2 257))) ((add (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))) (hlc ((natminus syd2 257)) ((inf-lidx syd2 g6))) (inf-leaddr (Lb ((natminus syd2 257))) (inf-mod (inf-pow ((Le ((natminus syd2 257))))) bbd12))))))))
; r4-36
 (defvc inf-vc-fast-r4-36 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le ip n)))
   (given inf-fast-w1 (lam w1 j1)))
; r4-37
 (defvc inf-vc-fast-r4-37 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le bc 64)))
   (given inf-fast-w1 (lam w1 j2)))
; r4-38
 (defvc inf-vc-fast-r4-38 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-shiftok bc ip n)))
   (given inf-fast-w1 (lam w1 j3)))
; r4-39
 (defvc inf-vc-fast-r4-39 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-bits-inv ip cons bc)))
   (given inf-fast-w1 (lam w1 j4)))
; r4-40
 (defvc inf-vc-fast-r4-40 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le cons0 cons)))
   (given inf-fast-w1 (lam w1 j5)))
; r4-41
 (defvc inf-vc-fast-r4-41 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le op cap)))
   (given inf-fast-w1 (lam w1 j7)))
; r4-42
 (defvc inf-vc-fast-r4-42 (under inf-fast-w1 (pi w1 (inf-lt cap (add op 266)) (inf-le op0 op)))
   (given inf-fast-w1 (lam w1 j6)))
 (defcx inf-block (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gb (inf-le bc0 64)) (gs (inf-shiftok bc0 ip0 n)) (ga (inf-bits-inv ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (gcf (inf-lt (add cap 266) (inf-pow w))) (Lc (pi k nat nat)) (Ls (pi k nat nat)) (Lt (pi k nat nat)) (Dc (pi k nat nat)) (Ds (pi k nat nat)) (Dt (pi k nat nat)) (lm nat) (dm nat) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (h nat) (LROOT nat) (DROOT nat) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gh (inf-le h 16)) (c1 (pi k nat (inf-lt (Lc k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Ls k) (inf-pow h)))) (c3 (inf-le (inf-sum Lc 15 1) lm)) (c4 (inf-le lm 288)) (c5 (pi k nat (inf-lt (Dc k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Ds k) (inf-pow h)))) (c7 (inf-le (inf-sum Dc 15 1) dm)) (c8 (inf-le dm 32)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) )
; w1e-1
 (defvc inf-vc-block-w1e-1 (under inf-block (inf-le ip0 n))
   (given inf-block gi))
; w1e-2
 (defvc inf-vc-block-w1e-2 (under inf-block (inf-le bc0 64))
   (given inf-block gb))
; w1e-3
 (defvc inf-vc-block-w1e-3 (under inf-block (inf-shiftok bc0 ip0 n))
   (given inf-block gs))
; w1e-4
 (defvc inf-vc-block-w1e-4 (under inf-block (inf-bits-inv ip0 cons0 bc0))
   (given inf-block ga))
; w1e-5
 (defvc inf-vc-block-w1e-5 (under inf-block (inf-le cons0 cons0))
   (given inf-block (inf-refl cons0)))
; w1e-6
 (defvc inf-vc-block-w1e-6 (under inf-block (inf-le op0 op0))
   (given inf-block (inf-refl op0)))
; w1e-7
 (defvc inf-vc-block-w1e-7 (under inf-block (inf-le op0 cap))
   (given inf-block gop))
 (defcx inf-block-w1 inf-block (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (j1 (inf-le ip n)) (j2 (inf-le bc 64)) (j3 (inf-shiftok bc ip n)) (j4 (inf-bits-inv ip cons bc)) (j5 (inf-le cons0 cons)) (j6 (inf-le op0 op)) (j7 (inf-le op cap)) )
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
 (defvc inf-vc-block-t1-4 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le bc 64)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j2)))
; t1-5
 (defvc inf-vc-block-t1-5 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-shiftok bc ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j3)))
; t1-6
 (defvc inf-vc-block-t1-6 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-bits-inv ip cons bc)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j4)))
; t1-7
 (defvc inf-vc-block-t1-7 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 go)))
; t1-8
 (defvc inf-vc-block-t1-8 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add cap 8) (inf-pow w))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gcap)))
; t1-9
 (defvc inf-vc-block-t1-9 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le op cap)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j7)))
; t1-10
 (defvc inf-vc-block-t1-10 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add cap nd) (inf-pow w))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gnd)))
; t1-11
 (defvc inf-vc-block-t1-11 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt (add cap 266) (inf-pow w))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gcf)))
; t1-12
 (defvc inf-vc-block-t1-12 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le LROOT 15)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gl)))
; t1-13
 (defvc inf-vc-block-t1-13 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le DROOT 15)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gd)))
; t1-14
 (defvc inf-vc-block-t1-14 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-le h 16)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 gh)))
; t1-15
 (defvc inf-vc-block-t1-15 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (inf-lt 0 out)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 g1)))
; t1-16
 (defvc inf-vc-block-t1-16 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hle)))
; t1-17
 (defvc inf-vc-block-t1-17 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hlb)))
; t1-18
 (defvc inf-vc-block-t1-18 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hlc)))
; t1-19
 (defvc inf-vc-block-t1-19 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 30) (inf-le (De k) 13))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hde)))
; t1-20
 (defvc inf-vc-block-t1-20 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-le (add op 266) cap) (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 hdb)))
 (defcx inf-block-c9 inf-block-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (g1 (inf-lt 0 out)) (g2 (inf-le (add ip 8) n)) (g3 (inf-le (add op 266) cap)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (opt1 nat) (xt1 nat) (t1e1 (inf-le ipt1 n)) (t1e2 (inf-le bct1 64)) (t1e3 (inf-shiftok bct1 ipt1 n)) (t1e4 (inf-bits-inv ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e8 (inf-le opt1 cap)) (t1e9 (inf-le op opt1)) )
; r6-1
 (defvc inf-vc-block-r6-1 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le ipt1 n)))
   (given inf-block-c9 (lam g4 t1e1)))
; r6-2
 (defvc inf-vc-block-r6-2 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le bct1 64)))
   (given inf-block-c9 (lam g4 t1e2)))
; r6-3
 (defvc inf-vc-block-r6-3 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-shiftok bct1 ipt1 n)))
   (given inf-block-c9 (lam g4 t1e3)))
; r6-4
 (defvc inf-vc-block-r6-4 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-bits-inv ipt1 const1 bct1)))
   (given inf-block-c9 (lam g4 t1e4)))
; r6-5
 (defvc inf-vc-block-r6-5 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le cons0 const1)))
   (given inf-block-c9 (lam g4 (inf-letrans cons0 cons const1 j5 t1e5))))
; r6-6
 (defvc inf-vc-block-r6-6 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le opt1 cap)))
   (given inf-block-c9 (lam g4 t1e8)))
; r6-7
 (defvc inf-vc-block-r6-7 (under inf-block-c9 (pi g4 (inf-lt 0 xt1) (inf-le op0 opt1)))
   (given inf-block-c9 (lam g4 (inf-letrans op0 op opt1 j6 t1e9))))
; i1j-1
 (defvc inf-vc-block-i1j-1 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le ipt1 n)))
   (given inf-block-c9 (lam g4 t1e1)))
; i1j-2
 (defvc inf-vc-block-i1j-2 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le bct1 64)))
   (given inf-block-c9 (lam g4 t1e2)))
; i1j-3
 (defvc inf-vc-block-i1j-3 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-shiftok bct1 ipt1 n)))
   (given inf-block-c9 (lam g4 t1e3)))
; i1j-4
 (defvc inf-vc-block-i1j-4 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-bits-inv ipt1 const1 bct1)))
   (given inf-block-c9 (lam g4 t1e4)))
; i1j-5
 (defvc inf-vc-block-i1j-5 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le cons0 const1)))
   (given inf-block-c9 (lam g4 (inf-letrans cons0 cons const1 j5 t1e5))))
; i1j-6
 (defvc inf-vc-block-i1j-6 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le o0 opt1)))
   (given inf-block-c9 (lam g4 (inf-letrans o0 op opt1 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))) t1e9))))
; i1j-7
 (defvc inf-vc-block-i1j-7 (under inf-block-c9 (pi g4 (paths nat xt1 0) (inf-le opt1 cap)))
   (given inf-block-c9 (lam g4 t1e8)))
; i1j-8
 (defvc inf-vc-block-i1j-8 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j1)))
; i1j-9
 (defvc inf-vc-block-i1j-9 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le bc 64)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j2)))
; i1j-10
 (defvc inf-vc-block-i1j-10 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-shiftok bc ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j3)))
; i1j-11
 (defvc inf-vc-block-i1j-11 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-bits-inv ip cons bc)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j4)))
; i1j-12
 (defvc inf-vc-block-i1j-12 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le cons0 cons)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j5)))
; i1j-13
 (defvc inf-vc-block-i1j-13 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le o0 op)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))))))
; i1j-14
 (defvc inf-vc-block-i1j-14 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-le (add ip 8) n) g3 (inf-lt cap (add op 266)) (inf-le op cap)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 g3 j7)))
; i1j-15
 (defvc inf-vc-block-i1j-15 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j1)))
; i1j-16
 (defvc inf-vc-block-i1j-16 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le bc 64)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j2)))
; i1j-17
 (defvc inf-vc-block-i1j-17 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-shiftok bc ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j3)))
; i1j-18
 (defvc inf-vc-block-i1j-18 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-bits-inv ip cons bc)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j4)))
; i1j-19
 (defvc inf-vc-block-i1j-19 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le cons0 cons)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j5)))
; i1j-20
 (defvc inf-vc-block-i1j-20 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le o0 op)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))))))
; i1j-21
 (defvc inf-vc-block-i1j-21 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (inf-lt 0 out) g2 (inf-lt n (add ip 8)) (inf-le op cap)))
   (given inf-block-w1 (lam w1 o0 eo g1 g2 j7)))
; i1j-22
 (defvc inf-vc-block-i1j-22 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 j1)))
; i1j-23
 (defvc inf-vc-block-i1j-23 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le bc 64)))
   (given inf-block-w1 (lam w1 o0 eo g1 j2)))
; i1j-24
 (defvc inf-vc-block-i1j-24 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-shiftok bc ip n)))
   (given inf-block-w1 (lam w1 o0 eo g1 j3)))
; i1j-25
 (defvc inf-vc-block-i1j-25 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-bits-inv ip cons bc)))
   (given inf-block-w1 (lam w1 o0 eo g1 j4)))
; i1j-26
 (defvc inf-vc-block-i1j-26 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le cons0 cons)))
   (given inf-block-w1 (lam w1 o0 eo g1 j5)))
; i1j-27
 (defvc inf-vc-block-i1j-27 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le o0 op)))
   (given inf-block-w1 (lam w1 o0 eo g1 ((inf-letr op o0 op (pathsinv0 nat o0 op eo) (inf-refl op))))))
; i1j-28
 (defvc inf-vc-block-i1j-28 (under inf-block-w1 (pi w1 unit o0 nat eo (paths nat o0 op) g1 (paths nat out 0) (inf-le op cap)))
   (given inf-block-w1 (lam w1 o0 eo g1 j7)))
 (defcx inf-block-c1 inf-block-w1 (w1 unit) (o0 nat) (eo (paths nat o0 op)) (ipi1 nat) (bci1 nat) (bbi1 nat) (consi1 nat) (opi1 nat) (k1 (inf-le ipi1 n)) (k2 (inf-le bci1 64)) (k3 (inf-shiftok bci1 ipi1 n)) (k4 (inf-bits-inv ipi1 consi1 bci1)) (k5 (inf-le cons0 consi1)) (k6 (inf-le o0 opi1)) (k7 (inf-le opi1 cap)) )
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
 (defvc inf-vc-block-t2-4 (under inf-block-c1 (inf-le bci1 64))
   (given inf-block-c1 k2))
; t2-5
 (defvc inf-vc-block-t2-5 (under inf-block-c1 (inf-shiftok bci1 ipi1 n))
   (given inf-block-c1 k3))
; t2-6
 (defvc inf-vc-block-t2-6 (under inf-block-c1 (inf-bits-inv ipi1 consi1 bci1))
   (given inf-block-c1 k4))
; t2-7
 (defvc inf-vc-block-t2-7 (under inf-block-c1 (pi i nat (inf-lt (Lc i) (inf-pow h))))
   (given inf-block-c1 c1))
; t2-8
 (defvc inf-vc-block-t2-8 (under inf-block-c1 (pi i nat (inf-lt (Ls i) (inf-pow h))))
   (given inf-block-c1 c2))
; t2-9
 (defvc inf-vc-block-t2-9 (under inf-block-c1 (inf-le h 16))
   (given inf-block-c1 gh))
; t2-10
 (defvc inf-vc-block-t2-10 (under inf-block-c1 (inf-lt lm (inf-pow w)))
   (given inf-block-c1 (inf-lelt lm 288 (inf-pow w) c4 (inf-wfit288 w gw))))
; t2-11
 (defvc inf-vc-block-t2-11 (under inf-block-c1 (inf-le (inf-sum Lc 15 1) lm))
   (given inf-block-c1 c3))
; t2-12
 (defvc inf-vc-block-t2-12 (under inf-block-c1 (inf-le LROOT 15))
   (given inf-block-c1 gl))
 (defcx inf-block-c2 inf-block-c1 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (syt2 nat) (t2e1 (inf-le ipt2 n)) (t2e2 (inf-le bct2 64)) (t2e3 (inf-shiftok bct2 ipt2 n)) (t2e4 (inf-bits-inv ipt2 const2 bct2)) (t2e5 (inf-le consi1 const2)) )
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
 (defvc inf-vc-block-w1b-2 (under inf-block-c8 (inf-le bct2 64))
   (given inf-block-c8 t2e2))
; w1b-3
 (defvc inf-vc-block-w1b-3 (under inf-block-c8 (inf-shiftok bct2 ipt2 n))
   (given inf-block-c8 t2e3))
; w1b-4
 (defvc inf-vc-block-w1b-4 (under inf-block-c8 (inf-bits-inv ipt2 const2 bct2))
   (given inf-block-c8 t2e4))
; w1b-5
 (defvc inf-vc-block-w1b-5 (under inf-block-c8 (inf-le cons0 const2))
   (given inf-block-c8 (inf-letrans cons0 consi1 const2 k5 t2e5)))
; w1b-6
 (defvc inf-vc-block-w1b-6 (under inf-block-c8 (inf-le op0 (add opi1 1)))
   (given inf-block-c8 (inf-letrans op0 opi1 (add opi1 1) ((inf-letrans op0 op opi1 j6 ((inf-letr o0 op opi1 eo k6)))) (inf-leaddr opi1 1))))
; w1b-7
 (defvc inf-vc-block-w1b-7 (under inf-block-c8 (inf-le (add opi1 1) cap))
   (given inf-block-c8 (inf-lt1 opi1 cap g6)))
; w1b-8
 (defvc inf-vc-block-w1b-8 (under inf-block-c8 (inf-lt (natminus cap (add opi1 1)) (natminus cap op)))
   (given inf-block-c8 (inf-subfrom op opi1 cap 1 ((inf-letr o0 op opi1 eo k6)) g6 (idpath true))))
; r6-8
 (defvc inf-vc-block-r6-8 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le ipt2 n)))
   (given inf-block-c2 (lam g5 g8 t2e1)))
; r6-9
 (defvc inf-vc-block-r6-9 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le bct2 64)))
   (given inf-block-c2 (lam g5 g8 t2e2)))
; r6-10
 (defvc inf-vc-block-r6-10 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-shiftok bct2 ipt2 n)))
   (given inf-block-c2 (lam g5 g8 t2e3)))
; r6-11
 (defvc inf-vc-block-r6-11 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-bits-inv ipt2 const2 bct2)))
   (given inf-block-c2 (lam g5 g8 t2e4)))
; r6-12
 (defvc inf-vc-block-r6-12 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le cons0 const2)))
   (given inf-block-c2 (lam g5 g8 (inf-letrans cons0 consi1 const2 k5 t2e5))))
; r6-13
 (defvc inf-vc-block-r6-13 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le opi1 cap)))
   (given inf-block-c2 (lam g5 g8 k7)))
; r6-14
 (defvc inf-vc-block-r6-14 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-le syt2 256) (inf-le op0 opi1)))
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
 (defvc inf-vc-block-t3-4 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-le bct2 64)))
   (given inf-block-c2 (lam g5 g8 g9 t2e2)))
; t3-5
 (defvc inf-vc-block-t3-5 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-shiftok bct2 ipt2 n)))
   (given inf-block-c2 (lam g5 g8 g9 t2e3)))
; t3-6
 (defvc inf-vc-block-t3-6 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-bits-inv ipt2 const2 bct2)))
   (given inf-block-c2 (lam g5 g8 g9 t2e4)))
; t3-7
 (defvc inf-vc-block-t3-7 (under inf-block-c2 (pi g5 (inf-le 256 syt2) g8 (inf-lt 256 syt2) g9 (inf-le syt2 285) (inf-le (Le (natminus syt2 257)) 13)))
   (given inf-block-c2 (lam g5 g8 g9 (inf-letrans ((Le ((natminus syt2 257)))) 5 13 (hle ((natminus syt2 257)) ((inf-lidx syt2 g9))) (idpath false)))))
 (defcx inf-block-c3 inf-block-c2 (g5 (inf-le 256 syt2)) (g8 (inf-lt 256 syt2)) (g9 (inf-le syt2 285)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e2 (inf-le bct3 64)) (t3e3 (inf-shiftok bct3 ipt3 n)) (t3e4 (inf-bits-inv ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e6 (inf-le (add const2 (Le (natminus syt2 257))) const3)) (t3e7 (inf-lt xt3 (inf-pow (Le (natminus syt2 257))))) )
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
 (defvc inf-vc-block-t4-4 (under inf-block-c3 (inf-le bct3 64))
   (given inf-block-c3 t3e2))
; t4-5
 (defvc inf-vc-block-t4-5 (under inf-block-c3 (inf-shiftok bct3 ipt3 n))
   (given inf-block-c3 t3e3))
; t4-6
 (defvc inf-vc-block-t4-6 (under inf-block-c3 (inf-bits-inv ipt3 const3 bct3))
   (given inf-block-c3 t3e4))
; t4-7
 (defvc inf-vc-block-t4-7 (under inf-block-c3 (pi i nat (inf-lt (Dc i) (inf-pow h))))
   (given inf-block-c3 c5))
; t4-8
 (defvc inf-vc-block-t4-8 (under inf-block-c3 (pi i nat (inf-lt (Ds i) (inf-pow h))))
   (given inf-block-c3 c6))
; t4-9
 (defvc inf-vc-block-t4-9 (under inf-block-c3 (inf-le h 16))
   (given inf-block-c3 gh))
; t4-10
 (defvc inf-vc-block-t4-10 (under inf-block-c3 (inf-lt dm (inf-pow w)))
   (given inf-block-c3 (inf-wlit dm w gw (inf-letrans dm 32 64 c8 (idpath false)))))
; t4-11
 (defvc inf-vc-block-t4-11 (under inf-block-c3 (inf-le (inf-sum Dc 15 1) dm))
   (given inf-block-c3 c7))
; t4-12
 (defvc inf-vc-block-t4-12 (under inf-block-c3 (inf-le DROOT 15))
   (given inf-block-c3 gd))
 (defcx inf-block-c4 inf-block-c3 (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (sdt4 nat) (t4e1 (inf-le ipt4 n)) (t4e2 (inf-le bct4 64)) (t4e3 (inf-shiftok bct4 ipt4 n)) (t4e4 (inf-bits-inv ipt4 const4 bct4)) (t4e5 (inf-le const3 const4)) )
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
 (defvc inf-vc-block-t5-4 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-le bct4 64)))
   (given inf-block-c4 (lam g10 t4e2)))
; t5-5
 (defvc inf-vc-block-t5-5 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-shiftok bct4 ipt4 n)))
   (given inf-block-c4 (lam g10 t4e3)))
; t5-6
 (defvc inf-vc-block-t5-6 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-bits-inv ipt4 const4 bct4)))
   (given inf-block-c4 (lam g10 t4e4)))
; t5-7
 (defvc inf-vc-block-t5-7 (under inf-block-c4 (pi g10 (inf-le sdt4 29) (inf-le (De sdt4) 13)))
   (given inf-block-c4 (lam g10 (hde sdt4 ((inf-lelts sdt4 29 g10))))))
 (defcx inf-block-c5 inf-block-c4 (g10 (inf-le sdt4 29)) (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (yt5 nat) (t5e1 (inf-le ipt5 n)) (t5e2 (inf-le bct5 64)) (t5e3 (inf-shiftok bct5 ipt5 n)) (t5e4 (inf-bits-inv ipt5 const5 bct5)) (t5e5 (inf-le const4 const5)) (t5e6 (inf-le (add const4 (De sdt4)) const5)) (t5e7 (inf-lt yt5 (inf-pow (De sdt4)))) )
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
; w1b-9
 (defvc inf-vc-block-w1b-9 (under inf-block-c6 (inf-le ipt5 n))
   (given inf-block-c6 t5e1))
; w1b-10
 (defvc inf-vc-block-w1b-10 (under inf-block-c6 (inf-le bct5 64))
   (given inf-block-c6 t5e2))
; w1b-11
 (defvc inf-vc-block-w1b-11 (under inf-block-c6 (inf-shiftok bct5 ipt5 n))
   (given inf-block-c6 t5e3))
; w1b-12
 (defvc inf-vc-block-w1b-12 (under inf-block-c6 (inf-bits-inv ipt5 const5 bct5))
   (given inf-block-c6 t5e4))
; w1b-13
 (defvc inf-vc-block-w1b-13 (under inf-block-c6 (inf-le cons0 const5))
   (given inf-block-c6 (inf-letrans cons0 const4 const5 (inf-letrans cons0 const3 const4 (inf-letrans cons0 const2 const3 (inf-letrans cons0 consi1 const2 k5 t2e5) t3e5) t4e5) t5e5)))
; w1b-14
 (defvc inf-vc-block-w1b-14 (under inf-block-c6 (inf-le op0 (add opi1 (add (Lb (natminus syt2 257)) xt3))))
   (given inf-block-c6 (inf-letrans op0 opi1 (add opi1 ((add (Lb ((natminus syt2 257))) xt3))) ((inf-letrans op0 op opi1 j6 ((inf-letr o0 op opi1 eo k6)))) (inf-leaddr opi1 ((add (Lb ((natminus syt2 257))) xt3))))))
; w1b-15
 (defvc inf-vc-block-w1b-15 (under inf-block-c6 (inf-le (add opi1 (add (Lb (natminus syt2 257)) xt3)) cap))
   (given inf-block-c6 ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7))))
; w1b-16
 (defvc inf-vc-block-w1b-16 (under inf-block-c6 (inf-lt (natminus cap (add opi1 (add (Lb (natminus syt2 257)) xt3))) (natminus cap op)))
   (given inf-block-c6 (inf-subfrom op opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) ((inf-letr o0 op opi1 eo k6)) ((inf-lttrans opi1 (add opi1 ((add (Lb ((natminus syt2 257))) xt3))) cap (inf-ltaddpos opi1 ((add (Lb ((natminus syt2 257))) xt3)) ((inf-lttrans 0 3 ((add (Lb ((natminus syt2 257))) xt3)) (idpath true) (inf-letrans 3 (Lb ((natminus syt2 257))) ((add (Lb ((natminus syt2 257))) xt3)) (hlc ((natminus syt2 257)) ((inf-lidx syt2 g9))) (inf-leaddr (Lb ((natminus syt2 257))) xt3))))) ((inf-roomle opi1 cap ((add (Lb ((natminus syt2 257))) xt3)) g12 k7)))) ((inf-lttrans 0 3 ((add (Lb ((natminus syt2 257))) xt3)) (idpath true) (inf-letrans 3 (Lb ((natminus syt2 257))) ((add (Lb ((natminus syt2 257))) xt3)) (hlc ((natminus syt2 257)) ((inf-lidx syt2 g9))) (inf-leaddr (Lb ((natminus syt2 257))) xt3)))))))
 (defcx inf-go (In (pi k nat nat)) (n nat) (w nat) (cons0 nat) (ip0 nat) (bc0 nat) (bb0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (gi (inf-le ip0 n)) (gb (inf-le bc0 64)) (gs (inf-shiftok bc0 ip0 n)) (ga (inf-bits-inv ip0 cons0 bc0)) (out nat) (oc nat) (cap nat) (nd nat) (op0 nat) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gop (inf-le op0 cap)) (gnd (inf-lt (add cap nd) (inf-pow w))) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (q nat) (h nat) (LROOT nat) (DROOT nat) (CROOT nat) (gh (inf-le h 16)) (gq (inf-le (inf-by16 q) (inf-pow h))) (gq2 (inf-lt 320 q)) (gk (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))) (gl (inf-le LROOT 15)) (gd (inf-le DROOT 15)) (gc (inf-le CROOT 15)) (gcf (inf-lt (add cap 266) (inf-pow w))) (Ob (pi k nat nat)) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (hord (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))) (Lb (pi k nat nat)) (Le (pi k nat nat)) (Db (pi k nat nat)) (De (pi k nat nat)) (hle (pi k nat g (inf-lt k 29) (inf-le (Le k) 5))) (hlb (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259))) (hlc (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k)))) (hde (pi k nat g (inf-lt k 30) (inf-le (De k) 13))) (hdb (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h)))) )
; w1e-1
 (defvc inf-vc-go-w1e-1 (under inf-go (inf-le ip0 n))
   (given inf-go gi))
; w1e-2
 (defvc inf-vc-go-w1e-2 (under inf-go (inf-le bc0 64))
   (given inf-go gb))
; w1e-3
 (defvc inf-vc-go-w1e-3 (under inf-go (inf-shiftok bc0 ip0 n))
   (given inf-go gs))
; w1e-4
 (defvc inf-vc-go-w1e-4 (under inf-go (inf-bits-inv ip0 cons0 bc0))
   (given inf-go ga))
; w1e-5
 (defvc inf-vc-go-w1e-5 (under inf-go (inf-le op0 cap))
   (given inf-go gop))
 (defcx inf-go-w1 inf-go (last nat) (ip nat) (bc nat) (bb nat) (cons nat) (op nat) (Lc (pi j nat nat)) (Ls (pi j nat nat)) (Lt (pi j nat nat)) (Dc (pi j nat nat)) (Ds (pi j nat nat)) (Dt (pi j nat nat)) (lm nat) (dm nat) (j1 (inf-le ip n)) (j2 (inf-le bc 64)) (j3 (inf-shiftok bc ip n)) (j4 (inf-bits-inv ip cons bc)) (j7 (inf-le op cap)) )
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
 (defvc inf-vc-go-t1-4 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-le bc 64)))
   (given inf-go-w1 (lam w1 c0 ec j2)))
; t1-5
 (defvc inf-vc-go-t1-5 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-shiftok bc ip n)))
   (given inf-go-w1 (lam w1 c0 ec j3)))
; t1-6
 (defvc inf-vc-go-t1-6 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-bits-inv ip cons bc)))
   (given inf-go-w1 (lam w1 c0 ec j4)))
; t1-7
 (defvc inf-vc-go-t1-7 (under inf-go-w1 (pi w1 (paths nat last 0) c0 nat ec (paths nat c0 cons) (inf-le 1 13)))
   (given inf-go-w1 (lam w1 c0 ec (idpath false))))
 (defcx inf-go-c1 inf-go-w1 (w1 (paths nat last 0)) (c0 nat) (ec (paths nat c0 cons)) (ipt1 nat) (bct1 nat) (bbt1 nat) (const1 nat) (lastt1 nat) (t1e1 (inf-le ipt1 n)) (t1e2 (inf-le bct1 64)) (t1e3 (inf-shiftok bct1 ipt1 n)) (t1e4 (inf-bits-inv ipt1 const1 bct1)) (t1e5 (inf-le cons const1)) (t1e6 (inf-le (add cons 1) const1)) (t1e7 (inf-lt lastt1 (inf-pow 1))) )
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
 (defvc inf-vc-go-t2-4 (under inf-go-c1 (inf-le bct1 64))
   (given inf-go-c1 t1e2))
; t2-5
 (defvc inf-vc-go-t2-5 (under inf-go-c1 (inf-shiftok bct1 ipt1 n))
   (given inf-go-c1 t1e3))
; t2-6
 (defvc inf-vc-go-t2-6 (under inf-go-c1 (inf-bits-inv ipt1 const1 bct1))
   (given inf-go-c1 t1e4))
; t2-7
 (defvc inf-vc-go-t2-7 (under inf-go-c1 (inf-le 2 13))
   (given inf-go-c1 (idpath false)))
 (defcx inf-go-c2 inf-go-c1 (ipt2 nat) (bct2 nat) (bbt2 nat) (const2 nat) (typt2 nat) (t2e1 (inf-le ipt2 n)) (t2e2 (inf-le bct2 64)) (t2e3 (inf-shiftok bct2 ipt2 n)) (t2e4 (inf-bits-inv ipt2 const2 bct2)) (t2e5 (inf-le const1 const2)) (t2e6 (inf-le (add const1 2) const2)) (t2e7 (inf-lt typt2 (inf-pow 2))) )
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
 (defvc inf-vc-go-t3-4 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-le bct2 64)))
   (given inf-go-c2 (lam g1 t2e2)))
; t3-5
 (defvc inf-vc-go-t3-5 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-shiftok bct2 ipt2 n)))
   (given inf-go-c2 (lam g1 t2e3)))
; t3-6
 (defvc inf-vc-go-t3-6 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-bits-inv ipt2 const2 bct2)))
   (given inf-go-c2 (lam g1 t2e4)))
; t3-7
 (defvc inf-vc-go-t3-7 (under inf-go-c2 (pi g1 (paths nat typt2 0) (pi g (inf-lt 0 out) (paths nat oc cap))))
   (given inf-go-c2 (lam g1 go)))
; t3-8
 (defvc inf-vc-go-t3-8 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-lt (add cap 8) (inf-pow w))))
   (given inf-go-c2 (lam g1 gcap)))
; t3-9
 (defvc inf-vc-go-t3-9 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-le op cap)))
   (given inf-go-c2 (lam g1 j7)))
; t3-10
 (defvc inf-vc-go-t3-10 (under inf-go-c2 (pi g1 (paths nat typt2 0) (inf-lt (add cap nd) (inf-pow w))))
   (given inf-go-c2 (lam g1 gnd)))
 (defcx inf-go-c7 inf-go-c2 (g1 (paths nat typt2 0)) (ipt3 nat) (bct3 nat) (bbt3 nat) (const3 nat) (opt3 nat) (xt3 nat) (t3e1 (inf-le ipt3 n)) (t3e2 (inf-le bct3 64)) (t3e3 (inf-shiftok bct3 ipt3 n)) (t3e4 (inf-bits-inv ipt3 const3 bct3)) (t3e5 (inf-le const2 const3)) (t3e8 (inf-le opt3 cap)) (t3e9 (inf-le op opt3)) )
; w1b-1
 (defvc inf-vc-go-w1b-1 (under inf-go-c7 (inf-le ipt3 n))
   (given inf-go-c7 t3e1))
; w1b-2
 (defvc inf-vc-go-w1b-2 (under inf-go-c7 (inf-le bct3 64))
   (given inf-go-c7 t3e2))
; w1b-3
 (defvc inf-vc-go-w1b-3 (under inf-go-c7 (inf-shiftok bct3 ipt3 n))
   (given inf-go-c7 t3e3))
; w1b-4
 (defvc inf-vc-go-w1b-4 (under inf-go-c7 (inf-bits-inv ipt3 const3 bct3))
   (given inf-go-c7 t3e4))
; w1b-5
 (defvc inf-vc-go-w1b-5 (under inf-go-c7 (inf-le opt3 cap))
   (given inf-go-c7 t3e8))
; w1b-6
 (defvc inf-vc-go-w1b-6 (under inf-go-c7 (inf-lt (natminus (inf-by8 n) const3) (natminus (inf-by8 n) cons)))
   (given inf-go-c7 (inf-consfall ipt3 const3 bct3 n cons t3e4 t3e1 (inf-lttrans cons (add cons 1) const3 ((inf-ltaddpos cons 1 (idpath true))) (inf-letrans (add cons 1) const2 const3 (inf-letrans (add cons 1) const1 const2 t1e6 t2e5) t3e5)))))
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
 (defvc inf-vc-go-i3j-2 (under inf-go-c6 (inf-le bct2 64))
   (given inf-go-c6 t2e2))
; i3j-3
 (defvc inf-vc-go-i3j-3 (under inf-go-c6 (inf-shiftok bct2 ipt2 n))
   (given inf-go-c6 t2e3))
; i3j-4
 (defvc inf-vc-go-i3j-4 (under inf-go-c6 (inf-bits-inv ipt2 const2 bct2))
   (given inf-go-c6 t2e4))
; i3j-5
 (defvc inf-vc-go-i3j-5 (under inf-go-c6 (inf-le const2 const2))
   (given inf-go-c6 (inf-refl const2)))
; i3j-6
 (defvc inf-vc-go-i3j-6 (under inf-go-c6 (pi k nat (inf-lt (Lcc1 k) (inf-pow h))))
   (given inf-go-c6 c1c1))
; i3j-7
 (defvc inf-vc-go-i3j-7 (under inf-go-c6 (pi k nat (inf-lt (Lsc1 k) (inf-pow h))))
   (given inf-go-c6 c1c2))
; i3j-8
 (defvc inf-vc-go-i3j-8 (under inf-go-c6 (inf-le (inf-sum Lcc1 15 1) lmc1))
   (given inf-go-c6 c1c3))
; i3j-9
 (defvc inf-vc-go-i3j-9 (under inf-go-c6 (inf-le lmc1 288))
   (given inf-go-c6 c1c4))
; i3j-10
 (defvc inf-vc-go-i3j-10 (under inf-go-c6 (pi k nat (inf-lt (Dcc1 k) (inf-pow h))))
   (given inf-go-c6 c1c5))
; i3j-11
 (defvc inf-vc-go-i3j-11 (under inf-go-c6 (pi k nat (inf-lt (Dsc1 k) (inf-pow h))))
   (given inf-go-c6 c1c6))
; i3j-12
 (defvc inf-vc-go-i3j-12 (under inf-go-c6 (inf-le (inf-sum Dcc1 15 1) dmc1))
   (given inf-go-c6 c1c7))
; i3j-13
 (defvc inf-vc-go-i3j-13 (under inf-go-c6 (inf-le dmc1 32))
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
 (defvc inf-vc-go-t4-4 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le bct2 64)))
   (given inf-go-c2 (lam g1 g2 g3 t2e2)))
; t4-5
 (defvc inf-vc-go-t4-5 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-shiftok bct2 ipt2 n)))
   (given inf-go-c2 (lam g1 g2 g3 t2e3)))
; t4-6
 (defvc inf-vc-go-t4-6 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-bits-inv ipt2 const2 bct2)))
   (given inf-go-c2 (lam g1 g2 g3 t2e4)))
; t4-7
 (defvc inf-vc-go-t4-7 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le h 16)))
   (given inf-go-c2 (lam g1 g2 g3 gh)))
; t4-8
 (defvc inf-vc-go-t4-8 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le (inf-by16 q) (inf-pow h))))
   (given inf-go-c2 (lam g1 g2 g3 gq)))
; t4-9
 (defvc inf-vc-go-t4-9 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-lt 320 q)))
   (given inf-go-c2 (lam g1 g2 g3 gq2)))
; t4-10
 (defvc inf-vc-go-t4-10 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (pi k nat g (inf-le k 15) (inf-lt (inf-dk q k) (inf-pow w)))))
   (given inf-go-c2 (lam g1 g2 g3 gk)))
; t4-11
 (defvc inf-vc-go-t4-11 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le LROOT 15)))
   (given inf-go-c2 (lam g1 g2 g3 gl)))
; t4-12
 (defvc inf-vc-go-t4-12 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le DROOT 15)))
   (given inf-go-c2 (lam g1 g2 g3 gd)))
; t4-13
 (defvc inf-vc-go-t4-13 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (inf-le CROOT 15)))
   (given inf-go-c2 (lam g1 g2 g3 gc)))
; t4-14
 (defvc inf-vc-go-t4-14 (under inf-go-c2 (pi g1 (inf-lt 0 typt2) g2 (inf-lt typt2 3) g3 (inf-lt 1 typt2) (pi k nat g (inf-lt k 19) (inf-lt (Ob k) 19))))
   (given inf-go-c2 (lam g1 g2 g3 hord)))
 (defcx inf-go-c5 inf-go-c2 (g1 (inf-lt 0 typt2)) (g2 (inf-lt typt2 3)) (g3 (inf-lt 1 typt2)) (ipt4 nat) (bct4 nat) (bbt4 nat) (const4 nat) (Lct4 (pi j nat nat)) (Lst4 (pi j nat nat)) (Ltt4 (pi j nat nat)) (Dct4 (pi j nat nat)) (Dst4 (pi j nat nat)) (Dtt4 (pi j nat nat)) (lmt4 nat) (dmt4 nat) (xt4 nat) (t4e1 (inf-le ipt4 n)) (t4e2 (inf-le bct4 64)) (t4e3 (inf-shiftok bct4 ipt4 n)) (t4e4 (inf-bits-inv ipt4 const4 bct4)) (t4e5 (inf-le const2 const4)) (t4c1 (pi k nat (inf-lt (Lct4 k) (inf-pow h)))) (t4c2 (pi k nat (inf-lt (Lst4 k) (inf-pow h)))) (t4c3 (inf-le (inf-sum Lct4 15 1) lmt4)) (t4c4 (inf-le lmt4 288)) (t4c5 (pi k nat (inf-lt (Dct4 k) (inf-pow h)))) (t4c6 (pi k nat (inf-lt (Dst4 k) (inf-pow h)))) (t4c7 (inf-le (inf-sum Dct4 15 1) dmt4)) (t4c8 (inf-le dmt4 32)) )
; i3j-14
 (defvc inf-vc-go-i3j-14 (under inf-go-c5 (inf-le ipt4 n))
   (given inf-go-c5 t4e1))
; i3j-15
 (defvc inf-vc-go-i3j-15 (under inf-go-c5 (inf-le bct4 64))
   (given inf-go-c5 t4e2))
; i3j-16
 (defvc inf-vc-go-i3j-16 (under inf-go-c5 (inf-shiftok bct4 ipt4 n))
   (given inf-go-c5 t4e3))
; i3j-17
 (defvc inf-vc-go-i3j-17 (under inf-go-c5 (inf-bits-inv ipt4 const4 bct4))
   (given inf-go-c5 t4e4))
; i3j-18
 (defvc inf-vc-go-i3j-18 (under inf-go-c5 (inf-le const2 const4))
   (given inf-go-c5 t4e5))
; i3j-19
 (defvc inf-vc-go-i3j-19 (under inf-go-c5 (pi k nat (inf-lt (Lct4 k) (inf-pow h))))
   (given inf-go-c5 t4c1))
; i3j-20
 (defvc inf-vc-go-i3j-20 (under inf-go-c5 (pi k nat (inf-lt (Lst4 k) (inf-pow h))))
   (given inf-go-c5 t4c2))
; i3j-21
 (defvc inf-vc-go-i3j-21 (under inf-go-c5 (inf-le (inf-sum Lct4 15 1) lmt4))
   (given inf-go-c5 t4c3))
; i3j-22
 (defvc inf-vc-go-i3j-22 (under inf-go-c5 (inf-le lmt4 288))
   (given inf-go-c5 t4c4))
; i3j-23
 (defvc inf-vc-go-i3j-23 (under inf-go-c5 (pi k nat (inf-lt (Dct4 k) (inf-pow h))))
   (given inf-go-c5 t4c5))
; i3j-24
 (defvc inf-vc-go-i3j-24 (under inf-go-c5 (pi k nat (inf-lt (Dst4 k) (inf-pow h))))
   (given inf-go-c5 t4c6))
; i3j-25
 (defvc inf-vc-go-i3j-25 (under inf-go-c5 (inf-le (inf-sum Dct4 15 1) dmt4))
   (given inf-go-c5 t4c7))
; i3j-26
 (defvc inf-vc-go-i3j-26 (under inf-go-c5 (inf-le dmt4 32))
   (given inf-go-c5 t4c8))
 (defcx inf-go-c3 inf-go-c2 (g1 (inf-lt 0 typt2)) (g2 (inf-lt typt2 3)) (Lci3 (pi j nat nat)) (Lsi3 (pi j nat nat)) (Lti3 (pi j nat nat)) (Dci3 (pi j nat nat)) (Dsi3 (pi j nat nat)) (Dti3 (pi j nat nat)) (lmi3 nat) (dmi3 nat) (ipi3 nat) (bci3 nat) (bbi3 nat) (consi3 nat) (k1 (inf-le ipi3 n)) (k2 (inf-le bci3 64)) (k3 (inf-shiftok bci3 ipi3 n)) (k4 (inf-bits-inv ipi3 consi3 bci3)) (k5 (inf-le const2 consi3)) (c1 (pi k nat (inf-lt (Lci3 k) (inf-pow h)))) (c2 (pi k nat (inf-lt (Lsi3 k) (inf-pow h)))) (c3 (inf-le (inf-sum Lci3 15 1) lmi3)) (c4 (inf-le lmi3 288)) (c5 (pi k nat (inf-lt (Dci3 k) (inf-pow h)))) (c6 (pi k nat (inf-lt (Dsi3 k) (inf-pow h)))) (c7 (inf-le (inf-sum Dci3 15 1) dmi3)) (c8 (inf-le dmi3 32)) )
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
 (defvc inf-vc-go-t5-4 (under inf-go-c3 (inf-le bci3 64))
   (given inf-go-c3 k2))
; t5-5
 (defvc inf-vc-go-t5-5 (under inf-go-c3 (inf-shiftok bci3 ipi3 n))
   (given inf-go-c3 k3))
; t5-6
 (defvc inf-vc-go-t5-6 (under inf-go-c3 (inf-bits-inv ipi3 consi3 bci3))
   (given inf-go-c3 k4))
; t5-7
 (defvc inf-vc-go-t5-7 (under inf-go-c3 (pi g (inf-lt 0 out) (paths nat oc cap)))
   (given inf-go-c3 go))
; t5-8
 (defvc inf-vc-go-t5-8 (under inf-go-c3 (inf-lt (add cap 8) (inf-pow w)))
   (given inf-go-c3 gcap))
; t5-9
 (defvc inf-vc-go-t5-9 (under inf-go-c3 (inf-le op cap))
   (given inf-go-c3 j7))
; t5-10
 (defvc inf-vc-go-t5-10 (under inf-go-c3 (inf-lt (add cap nd) (inf-pow w)))
   (given inf-go-c3 gnd))
; t5-11
 (defvc inf-vc-go-t5-11 (under inf-go-c3 (inf-lt (add cap 266) (inf-pow w)))
   (given inf-go-c3 gcf))
; t5-12
 (defvc inf-vc-go-t5-12 (under inf-go-c3 (inf-le LROOT 15))
   (given inf-go-c3 gl))
; t5-13
 (defvc inf-vc-go-t5-13 (under inf-go-c3 (inf-le DROOT 15))
   (given inf-go-c3 gd))
; t5-14
 (defvc inf-vc-go-t5-14 (under inf-go-c3 (inf-le h 16))
   (given inf-go-c3 gh))
; t5-15
 (defvc inf-vc-go-t5-15 (under inf-go-c3 (pi k nat (inf-lt (Lci3 k) (inf-pow h))))
   (given inf-go-c3 c1))
; t5-16
 (defvc inf-vc-go-t5-16 (under inf-go-c3 (pi k nat (inf-lt (Lsi3 k) (inf-pow h))))
   (given inf-go-c3 c2))
; t5-17
 (defvc inf-vc-go-t5-17 (under inf-go-c3 (inf-le (inf-sum Lci3 15 1) lmi3))
   (given inf-go-c3 c3))
; t5-18
 (defvc inf-vc-go-t5-18 (under inf-go-c3 (inf-le lmi3 288))
   (given inf-go-c3 c4))
; t5-19
 (defvc inf-vc-go-t5-19 (under inf-go-c3 (pi k nat (inf-lt (Dci3 k) (inf-pow h))))
   (given inf-go-c3 c5))
; t5-20
 (defvc inf-vc-go-t5-20 (under inf-go-c3 (pi k nat (inf-lt (Dsi3 k) (inf-pow h))))
   (given inf-go-c3 c6))
; t5-21
 (defvc inf-vc-go-t5-21 (under inf-go-c3 (inf-le (inf-sum Dci3 15 1) dmi3))
   (given inf-go-c3 c7))
; t5-22
 (defvc inf-vc-go-t5-22 (under inf-go-c3 (inf-le dmi3 32))
   (given inf-go-c3 c8))
; t5-23
 (defvc inf-vc-go-t5-23 (under inf-go-c3 (pi k nat g (inf-lt k 29) (inf-le (Le k) 5)))
   (given inf-go-c3 hle))
; t5-24
 (defvc inf-vc-go-t5-24 (under inf-go-c3 (pi k nat g (inf-lt k 29) (inf-le (add (Lb k) (inf-pow (Le k))) 259)))
   (given inf-go-c3 hlb))
; t5-25
 (defvc inf-vc-go-t5-25 (under inf-go-c3 (pi k nat g (inf-lt k 29) (inf-le 3 (Lb k))))
   (given inf-go-c3 hlc))
; t5-26
 (defvc inf-vc-go-t5-26 (under inf-go-c3 (pi k nat g (inf-lt k 30) (inf-le (De k) 13)))
   (given inf-go-c3 hde))
; t5-27
 (defvc inf-vc-go-t5-27 (under inf-go-c3 (pi k nat g (inf-lt k 30) (inf-le (add (Db k) (inf-pow (De k))) (inf-pow h))))
   (given inf-go-c3 hdb))
 (defcx inf-go-c4 inf-go-c3 (ipt5 nat) (bct5 nat) (bbt5 nat) (const5 nat) (opt5 nat) (xt5 nat) (t5e1 (inf-le ipt5 n)) (t5e2 (inf-le bct5 64)) (t5e3 (inf-shiftok bct5 ipt5 n)) (t5e4 (inf-bits-inv ipt5 const5 bct5)) (t5e5 (inf-le consi3 const5)) (t5e8 (inf-le opt5 cap)) (t5e9 (inf-le op opt5)) )
; w1b-7
 (defvc inf-vc-go-w1b-7 (under inf-go-c4 (inf-le ipt5 n))
   (given inf-go-c4 t5e1))
; w1b-8
 (defvc inf-vc-go-w1b-8 (under inf-go-c4 (inf-le bct5 64))
   (given inf-go-c4 t5e2))
; w1b-9
 (defvc inf-vc-go-w1b-9 (under inf-go-c4 (inf-shiftok bct5 ipt5 n))
   (given inf-go-c4 t5e3))
; w1b-10
 (defvc inf-vc-go-w1b-10 (under inf-go-c4 (inf-bits-inv ipt5 const5 bct5))
   (given inf-go-c4 t5e4))
; w1b-11
 (defvc inf-vc-go-w1b-11 (under inf-go-c4 (inf-le opt5 cap))
   (given inf-go-c4 t5e8))
; w1b-12
 (defvc inf-vc-go-w1b-12 (under inf-go-c4 (inf-lt (natminus (inf-by8 n) const5) (natminus (inf-by8 n) cons)))
   (given inf-go-c4 (inf-consfall ipt5 const5 bct5 n cons t5e4 t5e1 (inf-lttrans cons (add cons 1) const5 ((inf-ltaddpos cons 1 (idpath true))) (inf-letrans (add cons 1) consi3 const5 (inf-letrans (add cons 1) const2 consi3 (inf-letrans (add cons 1) const1 const2 t1e6 t2e5) k5) t5e5)))))
 (defcx inf-top (In (pi k nat nat)) (n nat) (w nat) (out nat) (oc nat) (cap nat) (nd nat) (Lc0 (pi k nat nat)) (Ls0 (pi k nat nat)) (Lt0 (pi k nat nat)) (Dc0 (pi k nat nat)) (Ds0 (pi k nat nat)) (Dt0 (pi k nat nat)) (lm0 nat) (dm0 nat) (Cs0 (pi k nat nat)) (Ct0 (pi k nat nat)) (Cc0 (pi k nat nat)) (gw (inf-le 32 w)) (gn (inf-lt (add n 8) (inf-pow w))) (go (pi g (inf-lt 0 out) (paths nat oc cap))) (gcap (inf-lt (add cap 8) (inf-pow w))) (gcf (inf-lt (add cap 266) (inf-pow w))) (gnd (inf-lt (add cap nd) (inf-pow w))) )
; c1-1
 (defvc inf-vc-top-c1-1 (under inf-top (inf-le 32 w))
   (given inf-top gw))
; c1-2
 (defvc inf-vc-top-c1-2 (under inf-top (inf-lt (add n 8) (inf-pow w)))
   (given inf-top gn))
; c1-3
 (defvc inf-vc-top-c1-3 (under inf-top (inf-le 0 n))
   (given inf-top (idpath false)))
; c1-4
 (defvc inf-vc-top-c1-4 (under inf-top (inf-le 0 64))
   (given inf-top (idpath false)))
; c1-5
 (defvc inf-vc-top-c1-5 (under inf-top (inf-shiftok 0 0 n))
   (given inf-top (ii1 (idpath false))))
; c1-6
 (defvc inf-vc-top-c1-6 (under inf-top (inf-bits-inv 0 0 0))
   (given inf-top (idpath 0)))
; c1-7
 (defvc inf-vc-top-c1-7 (under inf-top (pi g (inf-lt 0 out) (paths nat oc cap)))
   (given inf-top go))
; c1-8
 (defvc inf-vc-top-c1-8 (under inf-top (inf-lt (add cap 8) (inf-pow w)))
   (given inf-top gcap))
; c1-9
 (defvc inf-vc-top-c1-9 (under inf-top (inf-le 0 cap))
   (given inf-top (idpath false)))
; c1-10
 (defvc inf-vc-top-c1-10 (under inf-top (inf-lt (add cap nd) (inf-pow w)))
   (given inf-top gnd))
; c1-11
 (defvc inf-vc-top-c1-11 (under inf-top (inf-le 16 16))
   (given inf-top (idpath false)))
; c1-12
 (defvc inf-vc-top-c1-12 (under inf-top (inf-le (inf-by16 (inf-pow 12)) (inf-pow 16)))
   (given inf-top inf-topq))
; c1-13
 (defvc inf-vc-top-c1-13 (under inf-top (inf-lt 320 (inf-pow 12)))
   (given inf-top (idpath true)))
; c1-14
 (defvc inf-vc-top-c1-14 (under inf-top (pi k nat g (inf-le k 15) (inf-lt (inf-dk (inf-pow 12) k) (inf-pow w))))
   (given inf-top (inf-topk w gw)))
; c1-15
 (defvc inf-vc-top-c1-15 (under inf-top (inf-le 12 15))
   (given inf-top (idpath false)))
; c1-16
 (defvc inf-vc-top-c1-16 (under inf-top (inf-le 9 15))
   (given inf-top (idpath false)))
; c1-17
 (defvc inf-vc-top-c1-17 (under inf-top (inf-le 7 15))
   (given inf-top (idpath false)))
; c1-18
 (defvc inf-vc-top-c1-18 (under inf-top (inf-lt (add cap 266) (inf-pow w)))
   (given inf-top gcf))
; c1-19
 (defvc inf-vc-top-c1-19 (under inf-top (pi k nat g (inf-lt k 19) (inf-lt (inf-tob k) 19)))
   (given inf-top (lam k g (inf-lelts (inf-tob k) 18 (inf-anyno (lam j (natgtb (inf-tob j) 18)) 19 (idpath false) k g)))))
; c1-20
 (defvc inf-vc-top-c1-20 (under inf-top (pi k nat g (inf-lt k 29) (inf-le (inf-tle k) 5)))
   (given inf-top (inf-anyno (lam j (natgtb (inf-tle j) 5)) 29 (idpath false))))
; c1-21
 (defvc inf-vc-top-c1-21 (under inf-top (pi k nat g (inf-lt k 29) (inf-le (add (inf-tlb k) (inf-pow (inf-tle k))) 259)))
   (given inf-top (inf-anyno (lam j (natgtb (add (inf-tlb j) (inf-pow (inf-tle j))) 259)) 29 (idpath false))))
; c1-22
 (defvc inf-vc-top-c1-22 (under inf-top (pi k nat g (inf-lt k 29) (inf-le 3 (inf-tlb k))))
   (given inf-top (inf-anyno (lam j (natgtb 3 (inf-tlb j))) 29 (idpath false))))
; c1-23
 (defvc inf-vc-top-c1-23 (under inf-top (pi k nat g (inf-lt k 30) (inf-le (inf-tde k) 13)))
   (given inf-top (inf-anyno (lam j (natgtb (inf-tde j) 13)) 30 (idpath false))))
; c1-24
 (defvc inf-vc-top-c1-24 (under inf-top (pi k nat g (inf-lt k 30) (inf-le (add (inf-tdb k) (inf-pow (inf-tde k))) (inf-pow 16))))
   (given inf-top (inf-anyno (lam j (natgtb (add (inf-tdb j) (inf-pow (inf-tde j))) (inf-pow 16))) 30 (idpath false))))
 (defcx inf-top-c1 inf-top (ipc1 nat) (bcc1 nat) (bbc1 nat) (consc1 nat) (opc1 nat) (Lcc1 (pi j nat nat)) (Lsc1 (pi j nat nat)) (Ltc1 (pi j nat nat)) (Dcc1 (pi j nat nat)) (Dsc1 (pi j nat nat)) (Dtc1 (pi j nat nat)) (lmc1 nat) (dmc1 nat) )
 )
