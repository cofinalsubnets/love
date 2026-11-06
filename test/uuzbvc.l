; test/uuzbvc.l -- laid by src/love/compress/bz.l, `make mx`. edit that file.
; the ledger: what the theorems leave open, each with who answers for it
; pointers: bz_dblock's d, r and w -- bz2.c hands them over whole, d from alloc, r over the string, w from its caller
; sink: w's p holds oc bytes -- w is all zero, or bz2_into's out and cap (srctree.c)
; reader: br_get from bz_dec and bz_step -- n + 9 fits, i <= n + 9, k <= 64: bz2.c's framing; bz_dblock checks them for itself
; alloc: NULL or the bytes asked for -- alloc.c, as inflate's ledger has it
; word: oc fits its word, and a word read back fits -- the C type; `havw` states the second
; widths: tn <= 2^lim, ms fits -- bz-ok checks the numbers, bz.l's one binding
(test
 (defcx inf-zbw (w nat) (lim nat) (on0 nat) (oc0 nat) (gw (inf-le 32 w)) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hq (inf-le on0 oc0)) (hf (inf-lt oc0 (inf-pow w))) )
; r1-1
 (defvc inf-vc-zbw-r1-1 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit (inf-le on0 oc0)))
   (given inf-zbw (lam g1 g2 hq)))
; r1-2
 (defvc inf-vc-zbw-r1-2 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit (inf-lt oc0 (inf-pow w))))
   (given inf-zbw (lam g1 g2 hf)))
; i2-1
 (defvc inf-vc-zbw-i2-1 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit (inf-lt lim 32)))
   (given inf-zbw (lam g1 g2 (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31))))))
; i2-2
 (defvc inf-vc-zbw-i2-2 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit (inf-lt (inf-pow lim) (inf-pow w))))
   (given inf-zbw (lam g1 g2 (inf-wpow w lim gw (inf-lelts lim 31 (inf-letrans lim 31 31 (inf-ltle lim 31 hm) (inf-refl 31)))))))
; r2-1
 (defvc inf-vc-zbw-r2-1 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-le (inf-pow lim) on0) (inf-le on0 oc0)))
   (given inf-zbw (lam g1 g2 g3 hq)))
; r2-2
 (defvc inf-vc-zbw-r2-2 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-le (inf-pow lim) on0) (inf-lt oc0 (inf-pow w))))
   (given inf-zbw (lam g1 g2 g3 hf)))
; r3-1
 (defvc inf-vc-zbw-r3-1 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-lt on0 (inf-pow lim)) g4 unit (inf-le on0 oc0)))
   (given inf-zbw (lam g1 g2 g3 g4 hq)))
; r3-2
 (defvc inf-vc-zbw-r3-2 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-lt on0 (inf-pow lim)) g4 unit (inf-lt oc0 (inf-pow w))))
   (given inf-zbw (lam g1 g2 g3 g4 hf)))
; s4-1
 (defvc inf-vc-zbw-s4-1 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-lt on0 (inf-pow lim)) g4 unit g5 (paths nat oc0 0) (inf-lt 4096 (inf-pow w))))
   (given inf-zbw (lam g1 g2 g3 g4 g5 (bz-w4k w gw))))
; j2j-1
 (defvc inf-vc-zbw-j2j-1 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-lt on0 (inf-pow lim)) g4 unit g5 (paths nat oc0 0) (inf-lt on0 4096)))
   (given inf-zbw (lam g1 g2 g3 g4 g5 (bz-none on0 oc0 hq g5))))
; j2j-2
 (defvc inf-vc-zbw-j2j-2 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-lt on0 (inf-pow lim)) g4 unit g5 (paths nat oc0 0) (inf-lt 4096 (inf-pow w))))
   (given inf-zbw (lam g1 g2 g3 g4 g5 (bz-w4k w gw))))
; s5-1
 (defvc inf-vc-zbw-s5-1 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-lt on0 (inf-pow lim)) g4 unit g5 (inf-lt 0 oc0) (inf-lt (add oc0 oc0) (inf-pow w))))
   (given inf-zbw (lam g1 g2 g3 g4 g5 (inf-fitlim w lim oc0 oc0 gw hm (inf-letrans oc0 on0 (inf-pow lim) g1 (inf-letrans on0 (inf-pow lim) (inf-pow lim) (inf-ltle on0 (inf-pow lim) g3) (inf-refl (inf-pow lim)))) (inf-letrans oc0 on0 (inf-pow lim) g1 (inf-letrans on0 (inf-pow lim) (inf-pow lim) (inf-ltle on0 (inf-pow lim) g3) (inf-refl (inf-pow lim))))))))
; j2j-3
 (defvc inf-vc-zbw-j2j-3 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-lt on0 (inf-pow lim)) g4 unit g5 (inf-lt 0 oc0) (inf-lt on0 (add oc0 oc0))))
   (given inf-zbw (lam g1 g2 g3 g4 g5 (bz-dbl on0 oc0 hq g5))))
; j2j-4
 (defvc inf-vc-zbw-j2j-4 (under inf-zbw (pi g1 (inf-le oc0 on0) g2 unit g3 (inf-lt on0 (inf-pow lim)) g4 unit g5 (inf-lt 0 oc0) (inf-lt (add oc0 oc0) (inf-pow w))))
   (given inf-zbw (lam g1 g2 g3 g4 g5 (inf-fitlim w lim oc0 oc0 gw hm (inf-letrans oc0 on0 (inf-pow lim) g1 (inf-letrans on0 (inf-pow lim) (inf-pow lim) (inf-ltle on0 (inf-pow lim) g3) (inf-refl (inf-pow lim)))) (inf-letrans oc0 on0 (inf-pow lim) g1 (inf-letrans on0 (inf-pow lim) (inf-pow lim) (inf-ltle on0 (inf-pow lim) g3) (inf-refl (inf-pow lim))))))))
 (defcx inf-zbw-c2 inf-zbw (g1 (inf-le oc0 on0)) (g2 unit) (g3 (inf-lt on0 (inf-pow lim))) (g4 unit) (cj2 nat) (a1 (inf-lt on0 cj2)) (a2 (inf-lt cj2 (inf-pow w))) )
; r4-1
 (defvc inf-vc-zbw-r4-1 (under inf-zbw-c2 (pi qn1 nat on1 nat g6 (pi g (inf-lt 0 qn1) (paths nat on1 cj2)) g7 (paths nat qn1 0) (inf-le on0 oc0)))
   (given inf-zbw-c2 (lam qn1 on1 g6 g7 hq)))
; r4-2
 (defvc inf-vc-zbw-r4-2 (under inf-zbw-c2 (pi qn1 nat on1 nat g6 (pi g (inf-lt 0 qn1) (paths nat on1 cj2)) g7 (paths nat qn1 0) (inf-lt oc0 (inf-pow w))))
   (given inf-zbw-c2 (lam qn1 on1 g6 g7 hf)))
; m1-1
 (defvc inf-vc-zbw-m1-1 (under inf-zbw-c2 (pi qn1 nat on1 nat g6 (pi g (inf-lt 0 qn1) (paths nat on1 cj2)) g7 (inf-lt 0 qn1) g8 (inf-lt 0 on0) (inf-le (add 0 on0) on1)))
   (given inf-zbw-c2 (lam qn1 on1 g6 g7 g8 (bz-cle on0 on1 cj2 (g6 g7) a1))))
; m1-2
 (defvc inf-vc-zbw-m1-2 (under inf-zbw-c2 (pi qn1 nat on1 nat g6 (pi g (inf-lt 0 qn1) (paths nat on1 cj2)) g7 (inf-lt 0 qn1) g8 (inf-lt 0 on0) (inf-le (add 0 on0) oc0)))
   (given inf-zbw-c2 (lam qn1 on1 g6 g7 g8 (inf-letrans (add 0 on0) on0 oc0 (inf-refl on0) hq))))
 (defcx inf-zbw-c3 inf-zbw-c2 (qn1 nat) (on1 nat) (g6 (pi g (inf-lt 0 qn1) (paths nat on1 cj2))) (g7 (inf-lt 0 qn1)) )
; s8-1
 (defvc inf-vc-zbw-s8-1 (under inf-zbw-c3 (inf-lt cj2 (inf-pow w)))
   (given inf-zbw-c3 a2))
; j1j-1
 (defvc inf-vc-zbw-j1j-1 (under inf-zbw-c3 (inf-lt on0 cj2))
   (given inf-zbw-c3 a1))
; j1j-2
 (defvc inf-vc-zbw-j1j-2 (under inf-zbw-c3 (inf-lt cj2 (inf-pow w)))
   (given inf-zbw-c3 a2))
; j1j-3
 (defvc inf-vc-zbw-j1j-3 (under inf-zbw (pi g1 (inf-lt on0 oc0) (inf-lt on0 oc0)))
   (given inf-zbw (lam g1 g1)))
; j1j-4
 (defvc inf-vc-zbw-j1j-4 (under inf-zbw (pi g1 (inf-lt on0 oc0) (inf-lt oc0 (inf-pow w))))
   (given inf-zbw (lam g1 hf)))
 (defcx inf-zbw-c1 inf-zbw (ocj1 nat) (a3 (inf-lt on0 ocj1)) (a4 (inf-lt ocj1 (inf-pow w))) )
; p1-1
 (defvc inf-vc-zbw-p1-1 (under inf-zbw-c1 (inf-lt on0 ocj1))
   (given inf-zbw-c1 a3))
; s9-1
 (defvc inf-vc-zbw-s9-1 (under inf-zbw-c1 (inf-lt (add on0 1) (inf-pow w)))
   (given inf-zbw-c1 (inf-lelt (add on0 1) ocj1 (inf-pow w) (inf-letrans (add on0 1) ocj1 ocj1 (inf-lt1 on0 ocj1 a3) (inf-refl ocj1)) a4)))
; r5-1
 (defvc inf-vc-zbw-r5-1 (under inf-zbw-c1 (inf-le (add on0 1) ocj1))
   (given inf-zbw-c1 (inf-letrans (add on0 1) ocj1 ocj1 (inf-lt1 on0 ocj1 a3) (inf-refl ocj1))))
; r5-2
 (defvc inf-vc-zbw-r5-2 (under inf-zbw-c1 (inf-lt ocj1 (inf-pow w)))
   (given inf-zbw-c1 a4))
 (defcx inf-zbfill (In (pi x nat nat)) (n nat) (w nat) (i0 nat) (k0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 9) (inf-pow w))) (gi (inf-le i0 (add n 9))) (gk (inf-le k0 64)) )
; w1e-1
 (defvc inf-vc-zbfill-w1e-1 (under inf-zbfill (inf-le i0 (add n 9)))
   (given inf-zbfill gi))
; w1e-2
 (defvc inf-vc-zbfill-w1e-2 (under inf-zbfill (inf-le k0 64))
   (given inf-zbfill gk))
 (defcx inf-zbfill-w1 inf-zbfill (i nat) (k nat) (a1 (inf-le i (add n 9))) (a2 (inf-le k 64)) )
; h1-1
 (defvc inf-vc-zbfill-h1-1 (under inf-zbfill-w1 (pi w1 (inf-le k 56) g1 (inf-lt i n) (inf-lt i n)))
   (given inf-zbfill-w1 (lam w1 g1 g1)))
 (defcx inf-zbfill-c1 inf-zbfill-w1 (w1 (inf-le k 56)) )
; j2-1
 (defvc inf-vc-zbfill-j2-1 (under inf-zbfill-c1 (inf-lt (add n 9) (inf-pow w)))
   (given inf-zbfill-c1 gn))
; s2-1
 (defvc inf-vc-zbfill-s2-1 (under inf-zbfill-c1 (pi g2 (inf-lt i (add n 9)) (inf-lt (add i 1) (inf-pow w))))
   (given inf-zbfill-c1 (lam g2 (inf-lelt (add i 1) (add n 9) (inf-pow w) (inf-letrans (add i 1) (add n 9) (add n 9) (inf-lt1 i (add n 9) g2) (inf-refl (add n 9))) gn))))
; j2j-1
 (defvc inf-vc-zbfill-j2j-1 (under inf-zbfill-c1 (pi g2 (inf-lt i (add n 9)) (inf-le (add i 1) (add n 9))))
   (given inf-zbfill-c1 (lam g2 (inf-letrans (add i 1) (add n 9) (add n 9) (inf-lt1 i (add n 9) g2) (inf-refl (add n 9))))))
; j2j-2
 (defvc inf-vc-zbfill-j2j-2 (under inf-zbfill-c1 (pi g2 (inf-le (add n 9) i) (inf-le i (add n 9))))
   (given inf-zbfill-c1 (lam g2 a1)))
 (defcx inf-zbfill-c2 inf-zbfill-c1 (ij2 nat) (a3 (inf-le ij2 (add n 9))) )
; s3-1
 (defvc inf-vc-zbfill-s3-1 (under inf-zbfill-c2 (inf-lt (add k 8) (inf-pow w)))
   (given inf-zbfill-c2 (inf-lelt (add k 8) 1024 (inf-pow w) (inf-letrans (add k 8) 64 1024 (inf-addr k 56 8 w1) (idpath false)) (bz-w1k w gw))))
; w1b-1
 (defvc inf-vc-zbfill-w1b-1 (under inf-zbfill-c2 (inf-le ij2 (add n 9)))
   (given inf-zbfill-c2 a3))
; w1b-2
 (defvc inf-vc-zbfill-w1b-2 (under inf-zbfill-c2 (inf-le (add k 8) 64))
   (given inf-zbfill-c2 (inf-letrans (add k 8) 64 64 (inf-addr k 56 8 w1) (inf-refl 64))))
; w1b-3
 (defvc inf-vc-zbfill-w1b-3 (under inf-zbfill-c2 (inf-lt (natminus 64 (add k 8)) (natminus 64 k)))
   (given inf-zbfill-c2 (inf-subby k 64 8 (inf-lelt k 56 64 w1 (idpath true)) (idpath true))))
; end-1
 (defvc inf-vc-zbfill-end-1 (under inf-zbfill-w1 (pi w1 (inf-lt 56 k) (inf-le i (add n 9))))
   (given inf-zbfill-w1 (lam w1 a1)))
; end-2
 (defvc inf-vc-zbfill-end-2 (under inf-zbfill-w1 (pi w1 (inf-lt 56 k) (inf-le k 64)))
   (given inf-zbfill-w1 (lam w1 a2)))
; end-3
 (defvc inf-vc-zbfill-end-3 (under inf-zbfill-w1 (pi w1 (inf-lt 56 k) (inf-lt 56 k)))
   (given inf-zbfill-w1 (lam w1 w1)))
 (defcx inf-zbget (In (pi x nat nat)) (n nat) (w nat) (i0 nat) (k0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 9) (inf-pow w))) (gi (inf-le i0 (add n 9))) (gk (inf-le k0 64)) (K nat) (g1 (inf-lt 0 K)) (g2 (inf-le K 32)) )
; c1-1
 (defvc inf-vc-zbget-c1-1 (under inf-zbget (pi t1 (inf-lt k0 K) (inf-le 32 w)))
   (given inf-zbget (lam t1 gw)))
; c1-2
 (defvc inf-vc-zbget-c1-2 (under inf-zbget (pi t1 (inf-lt k0 K) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbget (lam t1 gn)))
; c1-3
 (defvc inf-vc-zbget-c1-3 (under inf-zbget (pi t1 (inf-lt k0 K) (inf-le i0 (add n 9))))
   (given inf-zbget (lam t1 gi)))
; c1-4
 (defvc inf-vc-zbget-c1-4 (under inf-zbget (pi t1 (inf-lt k0 K) (inf-le k0 64)))
   (given inf-zbget (lam t1 gk)))
 (defcx inf-zbget-c2 inf-zbget (t1 (inf-lt k0 K)) (ic1 nat) (kc1 nat) (c1e1 (inf-le ic1 (add n 9))) (c1e2 (inf-le kc1 64)) (c1e3 (inf-lt 56 kc1)) )
; j1j-1
 (defvc inf-vc-zbget-j1j-1 (under inf-zbget-c2 (inf-le K kc1))
   (given inf-zbget-c2 (inf-letrans K 32 kc1 g2 (inf-letrans 32 kc1 kc1 (inf-letrans 32 56 kc1 (idpath false) (inf-ltle 56 kc1 c1e3)) (inf-refl kc1)))))
; j1j-2
 (defvc inf-vc-zbget-j1j-2 (under inf-zbget-c2 (inf-le kc1 64))
   (given inf-zbget-c2 c1e2))
; j1j-3
 (defvc inf-vc-zbget-j1j-3 (under inf-zbget-c2 (inf-le ic1 (add n 9)))
   (given inf-zbget-c2 c1e1))
; j1j-4
 (defvc inf-vc-zbget-j1j-4 (under inf-zbget (pi t1 (inf-le K k0) (inf-le K k0)))
   (given inf-zbget (lam t1 t1)))
; j1j-5
 (defvc inf-vc-zbget-j1j-5 (under inf-zbget (pi t1 (inf-le K k0) (inf-le k0 64)))
   (given inf-zbget (lam t1 gk)))
; j1j-6
 (defvc inf-vc-zbget-j1j-6 (under inf-zbget (pi t1 (inf-le K k0) (inf-le i0 (add n 9))))
   (given inf-zbget (lam t1 gi)))
 (defcx inf-zbget-c1 inf-zbget (ij1 nat) (kj1 nat) (a1 (inf-le K kj1)) (a2 (inf-le kj1 64)) (a3 (inf-le ij1 (add n 9))) )
; d1-1
 (defvc inf-vc-zbget-d1-1 (under inf-zbget-c1 (inf-le K kj1))
   (given inf-zbget-c1 a1))
; d1-2
 (defvc inf-vc-zbget-d1-2 (under inf-zbget-c1 (inf-lt (natminus kj1 K) 64))
   (given inf-zbget-c1 (bz-sublt kj1 K 64 g1 a1 a2)))
; d1-3
 (defvc inf-vc-zbget-d1-3 (under inf-zbget-c1 (inf-lt K 64))
   (given inf-zbget-c1 (inf-lelts K 63 (inf-letrans K 32 63 g2 (idpath false)))))
; d2-1
 (defvc inf-vc-zbget-d2-1 (under inf-zbget-c1 (pi vd1 nat h1 (inf-lt vd1 (inf-pow w)) (inf-le K kj1)))
   (given inf-zbget-c1 (lam vd1 h1 a1)))
; r1-1
 (defvc inf-vc-zbget-r1-1 (under inf-zbget-c1 (pi vd1 nat h1 (inf-lt vd1 (inf-pow w)) (inf-le ij1 (add n 9))))
   (given inf-zbget-c1 (lam vd1 h1 a3)))
; r1-2
 (defvc inf-vc-zbget-r1-2 (under inf-zbget-c1 (pi vd1 nat h1 (inf-lt vd1 (inf-pow w)) (inf-le (natminus kj1 K) 64)))
   (given inf-zbget-c1 (lam vd1 h1 (inf-letrans (natminus kj1 K) kj1 64 (inf-suble kj1 K) a2))))
; r1-3
 (defvc inf-vc-zbget-r1-3 (under inf-zbget-c1 (pi vd1 nat h1 (inf-lt vd1 (inf-pow w)) (inf-lt vd1 (inf-pow w))))
   (given inf-zbget-c1 (lam vd1 h1 h1)))
 (defcx inf-zbpast (n nat) (i nat) (k nat) )
; i2-1
 (defvc inf-vc-zbpast-i2-1 (under inf-zbpast (pi g1 (inf-lt n i) (inf-le n i)))
   (given inf-zbpast (lam g1 (inf-letrans n i i (inf-ltle n i g1) (inf-refl i)))))
 (defcx inf-zbtab (Ln (pi x nat nat)) (n nat) (w nat) (lim nat) (gw (inf-le 32 w)) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (h20 (inf-le 20 lim)) (hq (inf-lt lim 30)) (hsy (inf-le n 258)) )
; s0-1
 (defvc inf-vc-zbtab-s0-1 (under inf-zbtab (inf-lt 0 (inf-pow w)))
   (given inf-zbtab (inf-wlit 0 w gw (idpath false))))
 (defcx inf-zbtab-f0 inf-zbtab (u nat) (maxl nat) )
; i0-1
 (defvc inf-vc-zbtab-i0-1 (under inf-zbtab-f0 (pi f0 (inf-lt u n) (inf-lt u 258)))
   (given inf-zbtab-f0 (lam f0 (inf-lttrans u n 258 f0 hsy))))
; h0-1
 (defvc inf-vc-zbtab-h0-1 (under inf-zbtab-f0 (pi f0 (inf-lt u n) g0 (inf-lt maxl (Ln u)) (inf-lt u 258)))
   (given inf-zbtab-f0 (lam f0 g0 (inf-lttrans u n 258 f0 hsy))))
; f0b-1
 (defvc inf-vc-zbtab-f0b-1 (under inf-zbtab-f0 (pi f0 (inf-lt u n) g0 (inf-lt maxl (Ln u)) maxlh0 nat (inf-lt (succ u) (inf-pow w))))
   (given inf-zbtab-f0 (lam f0 g0 maxlh0 (inf-lelt (succ u) 1024 (inf-pow w) (inf-letrans (succ u) n 1024 (inf-ltsu u n f0) (inf-letrans n 258 1024 hsy (idpath false))) (bz-w1k w gw)))))
; f0b-2
 (defvc inf-vc-zbtab-f0b-2 (under inf-zbtab-f0 (pi f0 (inf-lt u n) g0 (inf-lt maxl (Ln u)) maxlh0 nat (inf-lt (natminus n (succ u)) (natminus n u))))
   (given inf-zbtab-f0 (lam f0 g0 maxlh0 (inf-subfall n u f0))))
; f0b-3
 (defvc inf-vc-zbtab-f0b-3 (under inf-zbtab-f0 (pi f0 (inf-lt u n) g0 (inf-le (Ln u) maxl) (inf-lt (succ u) (inf-pow w))))
   (given inf-zbtab-f0 (lam f0 g0 (inf-lelt (succ u) 1024 (inf-pow w) (inf-letrans (succ u) n 1024 (inf-ltsu u n f0) (inf-letrans n 258 1024 hsy (idpath false))) (bz-w1k w gw)))))
; f0b-4
 (defvc inf-vc-zbtab-f0b-4 (under inf-zbtab-f0 (pi f0 (inf-lt u n) g0 (inf-le (Ln u) maxl) (inf-lt (natminus n (succ u)) (natminus n u))))
   (given inf-zbtab-f0 (lam f0 g0 (inf-subfall n u f0))))
; s1-1
 (defvc inf-vc-zbtab-s1-1 (under inf-zbtab-f0 (pi f0 (inf-le n u) (inf-lt 0 (inf-pow w))))
   (given inf-zbtab-f0 (lam f0 (inf-wlit 0 w gw (idpath false)))))
; s2-1
 (defvc inf-vc-zbtab-s2-1 (under inf-zbtab-f0 (pi f0 (inf-le n u) (inf-lt 0 (inf-pow w))))
   (given inf-zbtab-f0 (lam f0 (inf-wlit 0 w gw (idpath false)))))
; f1e-1
 (defvc inf-vc-zbtab-f1e-1 (under inf-zbtab-f0 (pi f0 (inf-le n u) (inf-le 0 (inf-pow 1))))
   (given inf-zbtab-f0 (lam f0 (idpath false))))
; f1e-2
 (defvc inf-vc-zbtab-f1e-2 (under inf-zbtab-f0 (pi f0 (inf-le n u) (inf-le 0 258)))
   (given inf-zbtab-f0 (lam f0 (idpath false))))
 (defcx inf-zbtab-f0-f1 inf-zbtab-f0 (f0 (inf-le n u)) (l nat) (t nat) (code nat) (u nat) (b1 (inf-le code (inf-pow l))) (b2 (inf-le t 258)) )
; p0-1
 (defvc inf-vc-zbtab-p0-1 (under inf-zbtab-f0-f1 (pi f1 (inf-lt l 21) (inf-lt l 22)))
   (given inf-zbtab-f0-f1 (lam f1 (inf-lelts l 21 (inf-letrans l 21 21 (inf-ltle l 21 f1) (inf-refl 21))))))
; f2e-1
 (defvc inf-vc-zbtab-f2e-1 (under inf-zbtab-f0-f1 (pi f1 (inf-lt l 21) (inf-le code (add 0 (inf-pow l)))))
   (given inf-zbtab-f0-f1 (lam f1 b1)))
; f2e-2
 (defvc inf-vc-zbtab-f2e-2 (under inf-zbtab-f0-f1 (pi f1 (inf-lt l 21) (inf-le t 258)))
   (given inf-zbtab-f0-f1 (lam f1 b2)))
 (defcx inf-zbtab-f0-f1-f2 inf-zbtab-f0-f1 (f1 (inf-lt l 21)) (u nat) (t nat) (code nat) (b3 (inf-le code (add u (inf-pow l)))) (b4 (inf-le t 258)) )
; i1-1
 (defvc inf-vc-zbtab-i1-1 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) (inf-lt u 258)))
   (given inf-zbtab-f0-f1-f2 (lam f2 (inf-lttrans u n 258 f2 hsy))))
; p1-1
 (defvc inf-vc-zbtab-p1-1 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit g2 (inf-lt t 258) (inf-lt t 258)))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 g2 g2)))
; s3-1
 (defvc inf-vc-zbtab-s3-1 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit g2 (inf-lt t 258) (inf-lt (add t 1) (inf-pow w))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 g2 (inf-lelt (add t 1) 1024 (inf-pow w) (inf-letrans (add t 1) 258 1024 (inf-lt1 t 258 g2) (idpath false)) (bz-w1k w gw)))))
; h1-1
 (defvc inf-vc-zbtab-h1-1 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit g2 (inf-lt t 258) g3 (inf-le l 10) (inf-le l 10)))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 g2 g3 g3)))
; h1-2
 (defvc inf-vc-zbtab-h1-2 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit g2 (inf-lt t 258) g3 (inf-le l 10) (inf-lt (natminus 10 l) 64)))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 g2 g3 (inf-lelts (natminus 10 l) 63 (inf-letrans (natminus 10 l) 10 63 (inf-suble 10 l) (idpath false))))))
; s4-1
 (defvc inf-vc-zbtab-s4-1 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit g2 (inf-lt t 258) g3 (inf-le l 10) loh1 nat g4 (inf-le loh1 1024) (inf-le l 10)))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 g2 g3 loh1 g4 g3)))
; s4-2
 (defvc inf-vc-zbtab-s4-2 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit g2 (inf-lt t 258) g3 (inf-le l 10) loh1 nat g4 (inf-le loh1 1024) (inf-lt (natminus 10 l) 32)))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 g2 g3 loh1 g4 (inf-lelts (natminus 10 l) 31 (inf-letrans (natminus 10 l) 10 31 (inf-suble 10 l) (idpath false))))))
; s4-3
 (defvc inf-vc-zbtab-s4-3 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit g2 (inf-lt t 258) g3 (inf-le l 10) loh1 nat g4 (inf-le loh1 1024) (inf-lt (inf-pow (natminus 10 l)) (inf-pow w))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 g2 g3 loh1 g4 (inf-wpow w (natminus 10 l) gw (inf-lelts (natminus 10 l) 31 (inf-letrans (natminus 10 l) 10 31 (inf-suble 10 l) (idpath false)))))))
; s4-4
 (defvc inf-vc-zbtab-s4-4 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit g2 (inf-lt t 258) g3 (inf-le l 10) loh1 nat g4 (inf-le loh1 1024) (inf-lt (add loh1 (inf-pow (natminus 10 l))) (inf-pow w))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 g2 g3 loh1 g4 (inf-fitlim w 10 loh1 (inf-pow (natminus 10 l)) gw (idpath true) (inf-letrans loh1 1024 (inf-pow 10) g4 (idpath false)) (inf-powle (natminus 10 l) 10 (inf-suble 10 l))))))
 (defcx inf-zbtab-f0-f1-f2-f3 inf-zbtab-f0-f1-f2 (f2 (inf-lt u n)) (g1 unit) (g2 (inf-lt t 258)) (g3 (inf-le l 10)) (loh1 nat) (g4 (inf-le loh1 1024)) (g5 (inf-le (add loh1 (inf-pow (natminus 10 l))) 1024)) (j nat) )
; p2-1
 (defvc inf-vc-zbtab-p2-1 (under inf-zbtab-f0-f1-f2-f3 (pi f3 (inf-lt j (add loh1 (inf-pow (natminus 10 l)))) (inf-lt j 1024)))
   (given inf-zbtab-f0-f1-f2-f3 (lam f3 (inf-lttrans j (add loh1 (inf-pow (natminus 10 l))) 1024 f3 g5))))
; p2-2
 (defvc inf-vc-zbtab-p2-2 (under inf-zbtab-f0-f1-f2-f3 (pi f3 (inf-lt j (add loh1 (inf-pow (natminus 10 l)))) (inf-lt 5 64)))
   (given inf-zbtab-f0-f1-f2-f3 (lam f3 (idpath true))))
; f3b-1
 (defvc inf-vc-zbtab-f3b-1 (under inf-zbtab-f0-f1-f2-f3 (pi f3 (inf-lt j (add loh1 (inf-pow (natminus 10 l)))) (inf-lt (succ j) (inf-pow w))))
   (given inf-zbtab-f0-f1-f2-f3 (lam f3 (inf-lelt (succ j) 1024 (inf-pow w) (inf-letrans (succ j) (add loh1 (inf-pow (natminus 10 l))) 1024 (inf-ltsu j (add loh1 (inf-pow (natminus 10 l))) f3) g5) (bz-w1k w gw)))))
; f3b-2
 (defvc inf-vc-zbtab-f3b-2 (under inf-zbtab-f0-f1-f2-f3 (pi f3 (inf-lt j (add loh1 (inf-pow (natminus 10 l)))) (inf-lt (natminus (add loh1 (inf-pow (natminus 10 l))) (succ j)) (natminus (add loh1 (inf-pow (natminus 10 l))) j))))
   (given inf-zbtab-f0-f1-f2-f3 (lam f3 (inf-subfall (add loh1 (inf-pow (natminus 10 l))) j f3))))
 (defcx inf-zbtab-c1 inf-zbtab-f0-f1-f2 (f2 (inf-lt u n)) (g1 unit) (g2 (inf-lt t 258)) )
; s5-1
 (defvc inf-vc-zbtab-s5-1 (under inf-zbtab-c1 (inf-lt (add code 1) (inf-pow w)))
   (given inf-zbtab-c1 (bz-cfit w lim l code u gw h20 hq f1 ((inf-letrans u n 258 (inf-ltle u n f2) hsy)) b3)))
; f2b-1
 (defvc inf-vc-zbtab-f2b-1 (under inf-zbtab-c1 (inf-lt (succ u) (inf-pow w)))
   (given inf-zbtab-c1 (inf-lelt (succ u) 1024 (inf-pow w) (inf-letrans (succ u) n 1024 (inf-ltsu u n f2) (inf-letrans n 258 1024 hsy (idpath false))) (bz-w1k w gw))))
; f2b-2
 (defvc inf-vc-zbtab-f2b-2 (under inf-zbtab-c1 (inf-le (add code 1) (add (succ u) (inf-pow l))))
   (given inf-zbtab-c1 (inf-lt1 code (add (succ u) (inf-pow l)) ((inf-lelts code (add u (inf-pow l)) b3)))))
; f2b-3
 (defvc inf-vc-zbtab-f2b-3 (under inf-zbtab-c1 (inf-le (add t 1) 258))
   (given inf-zbtab-c1 (inf-letrans (add t 1) 258 258 (inf-lt1 t 258 g2) (inf-refl 258))))
; f2b-4
 (defvc inf-vc-zbtab-f2b-4 (under inf-zbtab-c1 (inf-lt (natminus n (succ u)) (natminus n u)))
   (given inf-zbtab-c1 (inf-subfall n u f2)))
; f2b-5
 (defvc inf-vc-zbtab-f2b-5 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit (inf-lt (succ u) (inf-pow w))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 (inf-lelt (succ u) 1024 (inf-pow w) (inf-letrans (succ u) n 1024 (inf-ltsu u n f2) (inf-letrans n 258 1024 hsy (idpath false))) (bz-w1k w gw)))))
; f2b-6
 (defvc inf-vc-zbtab-f2b-6 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit (inf-le code (add (succ u) (inf-pow l)))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 (inf-ltle code (add (succ u) (inf-pow l)) ((inf-lelts code (add u (inf-pow l)) b3))))))
; f2b-7
 (defvc inf-vc-zbtab-f2b-7 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit (inf-le t 258)))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 b4)))
; f2b-8
 (defvc inf-vc-zbtab-f2b-8 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-lt u n) g1 unit (inf-lt (natminus n (succ u)) (natminus n u))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g1 (inf-subfall n u f2))))
; i5-1
 (defvc inf-vc-zbtab-i5-1 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-le n u) (inf-lt l 32)))
   (given inf-zbtab-f0-f1-f2 (lam f2 (inf-lelts l 31 (inf-letrans l 21 31 (inf-ltle l 21 f1) (idpath false))))))
; i5-2
 (defvc inf-vc-zbtab-i5-2 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-le n u) (inf-lt (inf-pow l) (inf-pow w))))
   (given inf-zbtab-f0-f1-f2 (lam f2 (inf-wpow w l gw (inf-lelts l 31 (inf-letrans l 21 31 (inf-ltle l 21 f1) (idpath false)))))))
; p3-1
 (defvc inf-vc-zbtab-p3-1 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-le n u) g6 (inf-le code (inf-pow l)) (inf-lt l 22)))
   (given inf-zbtab-f0-f1-f2 (lam f2 g6 (inf-lelts l 21 (inf-letrans l 21 21 (inf-ltle l 21 f1) (inf-refl 21))))))
; s6-1
 (defvc inf-vc-zbtab-s6-1 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-le n u) g6 (inf-le code (inf-pow l)) (inf-lt (add code code) (inf-pow w))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g6 (inf-fitlim w lim code code gw hm ((inf-letrans code (inf-pow l) (inf-pow lim) g6 (inf-powle l lim (inf-letrans l 20 lim (inf-ltsle l 20 f1) h20)))) ((inf-letrans code (inf-pow l) (inf-pow lim) g6 (inf-powle l lim (inf-letrans l 20 lim (inf-ltsle l 20 f1) h20))))))))
; f1b-1
 (defvc inf-vc-zbtab-f1b-1 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-le n u) g6 (inf-le code (inf-pow l)) (inf-lt (succ l) (inf-pow w))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g6 (inf-wlit (succ l) w gw (inf-letrans (succ l) 21 63 (inf-ltsu l 21 f1) (idpath false))))))
; f1b-2
 (defvc inf-vc-zbtab-f1b-2 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-le n u) g6 (inf-le code (inf-pow l)) (inf-le (add code code) (inf-pow (succ l)))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g6 (inf-powdbl l code code g6 g6))))
; f1b-3
 (defvc inf-vc-zbtab-f1b-3 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-le n u) g6 (inf-le code (inf-pow l)) (inf-le t 258)))
   (given inf-zbtab-f0-f1-f2 (lam f2 g6 b4)))
; f1b-4
 (defvc inf-vc-zbtab-f1b-4 (under inf-zbtab-f0-f1-f2 (pi f2 (inf-le n u) g6 (inf-le code (inf-pow l)) (inf-lt (natminus 21 (succ l)) (natminus 21 l))))
   (given inf-zbtab-f0-f1-f2 (lam f2 g6 (inf-subfall 21 l f1))))
 (defcx inf-zbsym (In (pi x nat nat)) (n nat) (w nat) (i0 nat) (k0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 9) (inf-pow w))) (gi (inf-le i0 (add n 9))) (gk (inf-le k0 64)) (Ft (pi x nat nat)) (Lm (pi x nat nat)) (Bs (pi x nat nat)) (Pm (pi x nat nat)) )
; c1-1
 (defvc inf-vc-zbsym-c1-1 (under inf-zbsym (pi g0 (inf-lt k0 32) (inf-le 32 w)))
   (given inf-zbsym (lam g0 gw)))
; c1-2
 (defvc inf-vc-zbsym-c1-2 (under inf-zbsym (pi g0 (inf-lt k0 32) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbsym (lam g0 gn)))
; c1-3
 (defvc inf-vc-zbsym-c1-3 (under inf-zbsym (pi g0 (inf-lt k0 32) (inf-le i0 (add n 9))))
   (given inf-zbsym (lam g0 gi)))
; c1-4
 (defvc inf-vc-zbsym-c1-4 (under inf-zbsym (pi g0 (inf-lt k0 32) (inf-le k0 64)))
   (given inf-zbsym (lam g0 gk)))
 (defcx inf-zbsym-c2 inf-zbsym (g0 (inf-lt k0 32)) (ic1 nat) (kc1 nat) (c1e1 (inf-le ic1 (add n 9))) (c1e2 (inf-le kc1 64)) (c1e3 (inf-lt 56 kc1)) )
; j1j-1
 (defvc inf-vc-zbsym-j1j-1 (under inf-zbsym-c2 (inf-le 32 kc1))
   (given inf-zbsym-c2 (inf-letrans 32 kc1 kc1 (inf-letrans 32 56 kc1 (idpath false) (inf-ltle 56 kc1 c1e3)) (inf-refl kc1))))
; j1j-2
 (defvc inf-vc-zbsym-j1j-2 (under inf-zbsym-c2 (inf-le kc1 64))
   (given inf-zbsym-c2 c1e2))
; j1j-3
 (defvc inf-vc-zbsym-j1j-3 (under inf-zbsym-c2 (inf-le ic1 (add n 9)))
   (given inf-zbsym-c2 c1e1))
; j1j-4
 (defvc inf-vc-zbsym-j1j-4 (under inf-zbsym (pi g0 (inf-le 32 k0) (inf-le 32 k0)))
   (given inf-zbsym (lam g0 g0)))
; j1j-5
 (defvc inf-vc-zbsym-j1j-5 (under inf-zbsym (pi g0 (inf-le 32 k0) (inf-le k0 64)))
   (given inf-zbsym (lam g0 gk)))
; j1j-6
 (defvc inf-vc-zbsym-j1j-6 (under inf-zbsym (pi g0 (inf-le 32 k0) (inf-le i0 (add n 9))))
   (given inf-zbsym (lam g0 gi)))
 (defcx inf-zbsym-c1 inf-zbsym (ij1 nat) (kj1 nat) (a1 (inf-le 32 kj1)) (a2 (inf-le kj1 64)) (a3 (inf-le ij1 (add n 9))) )
; d1-1
 (defvc inf-vc-zbsym-d1-1 (under inf-zbsym-c1 (inf-le 10 kj1))
   (given inf-zbsym-c1 (inf-letrans 10 kj1 kj1 (inf-letrans 10 32 kj1 (idpath false) a1) (inf-refl kj1))))
; d1-2
 (defvc inf-vc-zbsym-d1-2 (under inf-zbsym-c1 (inf-lt (natminus kj1 10) 64))
   (given inf-zbsym-c1 (bz-sublt kj1 10 64 (idpath true) (inf-letrans 10 kj1 kj1 (inf-letrans 10 32 kj1 (idpath false) a1) (inf-refl kj1)) a2)))
; d2-1
 (defvc inf-vc-zbsym-d2-1 (under inf-zbsym-c1 (pi vd1 nat (inf-lt (inf-mod 1024 vd1) 1024)))
   (given inf-zbsym-c1 (lam vd1 (inf-lelts (inf-mod 1024 vd1) 1023 (inf-letrans (inf-mod 1024 vd1) 1023 1023 (inf-ltsle (inf-mod 1024 vd1) 1023 (inf-modlt 1023 vd1)) (inf-refl 1023))))))
; d3-1
 (defvc inf-vc-zbsym-d3-1 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit (inf-le (inf-mod 32 fd2) kj1)))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 (inf-letrans (inf-mod 32 fd2) 31 kj1 (inf-ltsle (inf-mod 32 fd2) 31 (inf-modlt 31 fd2)) (inf-letrans 31 kj1 kj1 (inf-letrans 31 32 kj1 (idpath false) a1) (inf-refl kj1))))))
; r1-1
 (defvc inf-vc-zbsym-r1-1 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit (inf-lt 5 64)))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 (idpath true))))
; r1-2
 (defvc inf-vc-zbsym-r1-2 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit (inf-le ij1 (add n 9))))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 a3)))
; r1-3
 (defvc inf-vc-zbsym-r1-3 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit (inf-le (natminus kj1 (inf-mod 32 fd2)) 64)))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 (inf-letrans (natminus kj1 (inf-mod 32 fd2)) kj1 64 (inf-suble kj1 (inf-mod 32 fd2)) a2))))
; r2-1
 (defvc inf-vc-zbsym-r2-1 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit mh1 nat g2 (inf-lt 20 mh1) (inf-le ij1 (add n 9))))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 mh1 g2 a3)))
; r2-2
 (defvc inf-vc-zbsym-r2-2 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit mh1 nat g2 (inf-lt 20 mh1) (inf-le kj1 64)))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 mh1 g2 a2)))
; f1e-1
 (defvc inf-vc-zbsym-f1e-1 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit mh1 nat g2 (inf-le mh1 20) (inf-le 11 11)))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 mh1 g2 (idpath false))))
; f1e-2
 (defvc inf-vc-zbsym-f1e-2 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit mh1 nat g2 (inf-le mh1 20) (inf-le 32 kj1)))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 mh1 g2 a1)))
; f1e-3
 (defvc inf-vc-zbsym-f1e-3 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit mh1 nat g2 (inf-le mh1 20) (inf-le kj1 64)))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 mh1 g2 a2)))
; f1e-4
 (defvc inf-vc-zbsym-f1e-4 (under inf-zbsym-c1 (pi vd1 nat fd2 nat g1 unit mh1 nat g2 (inf-le mh1 20) (inf-le ij1 (add n 9))))
   (given inf-zbsym-c1 (lam vd1 fd2 g1 mh1 g2 a3)))
 (defcx inf-zbsym-c1-f1 inf-zbsym-c1 (vd1 nat) (fd2 nat) (g1 unit) (mh1 nat) (g2 (inf-le mh1 20)) (l nat) (k nat) (b1 (inf-le 11 l)) (b2 (inf-le 32 k)) (b3 (inf-le k 64)) (b4 (inf-le ij1 (add n 9))) )
; f1h-1
 (defvc inf-vc-zbsym-f1h-1 (under inf-zbsym-c1-f1 (inf-lt (add mh1 1) (inf-pow w)))
   (given inf-zbsym-c1-f1 (inf-wlit (add mh1 1) w gw (inf-letrans (add mh1 1) 21 63 (inf-addr mh1 20 1 g2) (idpath false)))))
; d4-1
 (defvc inf-vc-zbsym-d4-1 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) (inf-le l k)))
   (given inf-zbsym-c1-f1 (lam f1 (inf-letrans l (add mh1 1) k (inf-ltle l (add mh1 1) f1) (inf-letrans (add mh1 1) 21 k (inf-addr mh1 20 1 g2) (inf-letrans 21 k k (inf-letrans 21 32 k (idpath false) b2) (inf-refl k)))))))
; d4-2
 (defvc inf-vc-zbsym-d4-2 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) (inf-lt (natminus k l) 64)))
   (given inf-zbsym-c1-f1 (lam f1 (bz-sublt k l 64 (bz-pos l (inf-letrans 1 l l (inf-letrans 1 11 l (idpath false) b1) (inf-refl l))) (inf-letrans l (add mh1 1) k (inf-ltle l (add mh1 1) f1) (inf-letrans (add mh1 1) 21 k (inf-addr mh1 20 1 g2) (inf-letrans 21 k k (inf-letrans 21 32 k (idpath false) b2) (inf-refl k)))) b3))))
; d4-3
 (defvc inf-vc-zbsym-d4-3 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) (inf-lt l 64)))
   (given inf-zbsym-c1-f1 (lam f1 (inf-lelts l 63 (inf-letrans l (add mh1 1) 63 (inf-ltle l (add mh1 1) f1) (inf-letrans (add mh1 1) 21 63 (inf-addr mh1 20 1 g2) (idpath false)))))))
; i3-1
 (defvc inf-vc-zbsym-i3-1 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat (inf-lt l 22)))
   (given inf-zbsym-c1-f1 (lam f1 cd4 (inf-lelts l 21 (inf-letrans l (add mh1 1) 21 (inf-ltle l (add mh1 1) f1) (inf-letrans (add mh1 1) 21 21 (inf-addr mh1 20 1 g2) (inf-refl 21)))))))
; d5-1
 (defvc inf-vc-zbsym-d5-1 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-lt cd4 (Lm l)) (inf-lt l 22)))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 (inf-lelts l 21 (inf-letrans l (add mh1 1) 21 (inf-ltle l (add mh1 1) f1) (inf-letrans (add mh1 1) 21 21 (inf-addr mh1 20 1 g2) (inf-refl 21)))))))
; r3-1
 (defvc inf-vc-zbsym-r3-1 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-lt cd4 (Lm l)) td5 nat g4 (inf-le 258 td5) (inf-le ij1 (add n 9))))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 td5 g4 b4)))
; r3-2
 (defvc inf-vc-zbsym-r3-2 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-lt cd4 (Lm l)) td5 nat g4 (inf-le 258 td5) (inf-le k 64)))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 td5 g4 b3)))
; d6-1
 (defvc inf-vc-zbsym-d6-1 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-lt cd4 (Lm l)) td5 nat g4 (inf-lt td5 258) (inf-le l k)))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 td5 g4 (inf-letrans l (add mh1 1) k (inf-ltle l (add mh1 1) f1) (inf-letrans (add mh1 1) 21 k (inf-addr mh1 20 1 g2) (inf-letrans 21 k k (inf-letrans 21 32 k (idpath false) b2) (inf-refl k)))))))
; r4-1
 (defvc inf-vc-zbsym-r4-1 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-lt cd4 (Lm l)) td5 nat g4 (inf-lt td5 258) (inf-lt td5 258)))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 td5 g4 g4)))
; r4-2
 (defvc inf-vc-zbsym-r4-2 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-lt cd4 (Lm l)) td5 nat g4 (inf-lt td5 258) (inf-le ij1 (add n 9))))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 td5 g4 b4)))
; r4-3
 (defvc inf-vc-zbsym-r4-3 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-lt cd4 (Lm l)) td5 nat g4 (inf-lt td5 258) (inf-le (natminus k l) 64)))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 td5 g4 (inf-letrans (natminus k l) k 64 (inf-suble k l) b3))))
; f1b-1
 (defvc inf-vc-zbsym-f1b-1 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-le (Lm l) cd4) (inf-lt (succ l) (inf-pow w))))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 (inf-wlit (succ l) w gw (inf-letrans (succ l) (add mh1 1) 63 (inf-ltsu l (add mh1 1) f1) (inf-letrans (add mh1 1) 21 63 (inf-addr mh1 20 1 g2) (idpath false)))))))
; f1b-2
 (defvc inf-vc-zbsym-f1b-2 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-le (Lm l) cd4) (inf-le 11 (succ l))))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 (inf-letrans 11 l (succ l) b1 (inf-ltle l (succ l) (inf-lelts l l (inf-refl l)))))))
; f1b-3
 (defvc inf-vc-zbsym-f1b-3 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-le (Lm l) cd4) (inf-le 32 k)))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 b2)))
; f1b-4
 (defvc inf-vc-zbsym-f1b-4 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-le (Lm l) cd4) (inf-le k 64)))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 b3)))
; f1b-5
 (defvc inf-vc-zbsym-f1b-5 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-le (Lm l) cd4) (inf-le ij1 (add n 9))))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 b4)))
; f1b-6
 (defvc inf-vc-zbsym-f1b-6 (under inf-zbsym-c1-f1 (pi f1 (inf-lt l (add mh1 1)) cd4 nat g3 (inf-le (Lm l) cd4) (inf-lt (natminus (add mh1 1) (succ l)) (natminus (add mh1 1) l))))
   (given inf-zbsym-c1-f1 (lam f1 cd4 g3 (inf-subfall (add mh1 1) l f1))))
; r5-1
 (defvc inf-vc-zbsym-r5-1 (under inf-zbsym-c1-f1 (pi f1 (inf-le (add mh1 1) l) (inf-le ij1 (add n 9))))
   (given inf-zbsym-c1-f1 (lam f1 b4)))
; r5-2
 (defvc inf-vc-zbsym-r5-2 (under inf-zbsym-c1-f1 (pi f1 (inf-le (add mh1 1) l) (inf-le k 64)))
   (given inf-zbsym-c1-f1 (lam f1 b3)))
 (defcx inf-zbhead (In (pi x nat nat)) (n nat) (w nat) (i0 nat) (k0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 9) (inf-pow w))) (gi (inf-le i0 (add n 9))) (gk (inf-le k0 64)) (Ps (pi x nat nat)) (Ln (pi x nat nat)) (ms nat) (tl nat) (gc (inf-lt (inf-by16 (add n 9)) (inf-pow w))) (hms (inf-lt ms (inf-pow w))) (h20 (inf-le 20 tl)) (hq (inf-lt tl 30)) )
; s0-1
 (defvc inf-vc-zbhead-s0-1 (under inf-zbhead (inf-lt 0 (inf-pow w)))
   (given inf-zbhead (inf-wlit 0 w gw (idpath false))))
; c0-1
 (defvc inf-vc-zbhead-c0-1 (under inf-zbhead (inf-le 32 w))
   (given inf-zbhead gw))
; c0-2
 (defvc inf-vc-zbhead-c0-2 (under inf-zbhead (inf-lt (add n 9) (inf-pow w)))
   (given inf-zbhead gn))
; c0-3
 (defvc inf-vc-zbhead-c0-3 (under inf-zbhead (inf-le i0 (add n 9)))
   (given inf-zbhead gi))
; c0-4
 (defvc inf-vc-zbhead-c0-4 (under inf-zbhead (inf-le k0 64))
   (given inf-zbhead gk))
; c0-5
 (defvc inf-vc-zbhead-c0-5 (under inf-zbhead (inf-lt 0 16))
   (given inf-zbhead (idpath true)))
; c0-6
 (defvc inf-vc-zbhead-c0-6 (under inf-zbhead (inf-le 16 32))
   (given inf-zbhead (idpath false)))
 (defcx inf-zbhead-c1 inf-zbhead (ic0 nat) (kc0 nat) (m0c0 nat) (c0e1 (inf-le ic0 (add n 9))) (c0e2 (inf-le kc0 64)) (c0e3 (inf-lt m0c0 (inf-pow w))) )
; f1e-1
 (defvc inf-vc-zbhead-f1e-1 (under inf-zbhead-c1 (inf-le ic0 (add n 9)))
   (given inf-zbhead-c1 c0e1))
; f1e-2
 (defvc inf-vc-zbhead-f1e-2 (under inf-zbhead-c1 (inf-le kc0 64))
   (given inf-zbhead-c1 c0e2))
 (defcx inf-zbhead-c1-f1 inf-zbhead-c1 (u nat) (i nat) (k nat) (nuse nat) (f1a (inf-le i (add n 9))) (f1b (inf-le k 64)) )
; i1-1
 (defvc inf-vc-zbhead-i1-1 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) (inf-le u 15)))
   (given inf-zbhead-c1-f1 (lam f1 (inf-letrans u 15 15 (inf-ltsle u 15 f1) (inf-refl 15)))))
; i1-2
 (defvc inf-vc-zbhead-i1-2 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) (inf-lt (natminus 15 u) 32)))
   (given inf-zbhead-c1-f1 (lam f1 (inf-lelts (natminus 15 u) 31 (inf-letrans (natminus 15 u) 15 31 (inf-suble 15 u) (idpath false))))))
; c1-1
 (defvc inf-vc-zbhead-c1-1 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (inf-lt 0 (inf-sb m0c0 (natminus 15 u))) (inf-le 32 w)))
   (given inf-zbhead-c1-f1 (lam f1 g1 gw)))
; c1-2
 (defvc inf-vc-zbhead-c1-2 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (inf-lt 0 (inf-sb m0c0 (natminus 15 u))) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbhead-c1-f1 (lam f1 g1 gn)))
; c1-3
 (defvc inf-vc-zbhead-c1-3 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (inf-lt 0 (inf-sb m0c0 (natminus 15 u))) (inf-le i (add n 9))))
   (given inf-zbhead-c1-f1 (lam f1 g1 f1a)))
; c1-4
 (defvc inf-vc-zbhead-c1-4 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (inf-lt 0 (inf-sb m0c0 (natminus 15 u))) (inf-le k 64)))
   (given inf-zbhead-c1-f1 (lam f1 g1 f1b)))
; c1-5
 (defvc inf-vc-zbhead-c1-5 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (inf-lt 0 (inf-sb m0c0 (natminus 15 u))) (inf-lt 0 16)))
   (given inf-zbhead-c1-f1 (lam f1 g1 (idpath true))))
; c1-6
 (defvc inf-vc-zbhead-c1-6 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (inf-lt 0 (inf-sb m0c0 (natminus 15 u))) (inf-le 16 32)))
   (given inf-zbhead-c1-f1 (lam f1 g1 (idpath false))))
 (defcx inf-zbhead-c12 inf-zbhead-c1-f1 (f1 (inf-lt u 16)) (g1 (inf-lt 0 (inf-sb m0c0 (natminus 15 u)))) (ic1 nat) (kc1 nat) (m1c1 nat) (c1e1 (inf-le ic1 (add n 9))) (c1e2 (inf-le kc1 64)) (c1e3 (inf-lt m1c1 (inf-pow w))) )
; f2e-1
 (defvc inf-vc-zbhead-f2e-1 (under inf-zbhead-c12 (inf-le ic1 (add n 9)))
   (given inf-zbhead-c12 c1e1))
; f2e-2
 (defvc inf-vc-zbhead-f2e-2 (under inf-zbhead-c12 (inf-le kc1 64))
   (given inf-zbhead-c12 c1e2))
 (defcx inf-zbhead-c12-f2 inf-zbhead-c12 (j nat) (nuse nat) (f2a (inf-le ic1 (add n 9))) (f2b (inf-le kc1 64)) )
; i2-1
 (defvc inf-vc-zbhead-i2-1 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) (inf-le j 15)))
   (given inf-zbhead-c12-f2 (lam f2 (inf-letrans j 15 15 (inf-ltsle j 15 f2) (inf-refl 15)))))
; i2-2
 (defvc inf-vc-zbhead-i2-2 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) (inf-lt (natminus 15 j) 32)))
   (given inf-zbhead-c12-f2 (lam f2 (inf-lelts (natminus 15 j) 31 (inf-letrans (natminus 15 j) 15 31 (inf-suble 15 j) (idpath false))))))
; r0-1
 (defvc inf-vc-zbhead-r0-1 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (inf-lt 0 (inf-sb m1c1 (natminus 15 j))) g3 (inf-le 256 nuse) (inf-le ic1 (add n 9))))
   (given inf-zbhead-c12-f2 (lam f2 g2 g3 f2a)))
; r0-2
 (defvc inf-vc-zbhead-r0-2 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (inf-lt 0 (inf-sb m1c1 (natminus 15 j))) g3 (inf-le 256 nuse) (inf-le kc1 64)))
   (given inf-zbhead-c12-f2 (lam f2 g2 g3 f2b)))
; p1-1
 (defvc inf-vc-zbhead-p1-1 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (inf-lt 0 (inf-sb m1c1 (natminus 15 j))) g3 (inf-lt nuse 256) (inf-lt nuse 256)))
   (given inf-zbhead-c12-f2 (lam f2 g2 g3 g3)))
; p1-2
 (defvc inf-vc-zbhead-p1-2 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (inf-lt 0 (inf-sb m1c1 (natminus 15 j))) g3 (inf-lt nuse 256) (inf-lt 4 64)))
   (given inf-zbhead-c12-f2 (lam f2 g2 g3 (idpath true))))
; s1-1
 (defvc inf-vc-zbhead-s1-1 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (inf-lt 0 (inf-sb m1c1 (natminus 15 j))) g3 (inf-lt nuse 256) (inf-lt (add nuse 1) (inf-pow w))))
   (given inf-zbhead-c12-f2 (lam f2 g2 g3 (inf-lelt (add nuse 1) 1024 (inf-pow w) (inf-letrans (add nuse 1) 256 1024 (inf-lt1 nuse 256 g3) (idpath false)) (bz-w1k w gw)))))
; f2b-1
 (defvc inf-vc-zbhead-f2b-1 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (inf-lt 0 (inf-sb m1c1 (natminus 15 j))) g3 (inf-lt nuse 256) (inf-lt (succ j) (inf-pow w))))
   (given inf-zbhead-c12-f2 (lam f2 g2 g3 (inf-wlit (succ j) w gw (inf-letrans (succ j) 16 63 (inf-ltsu j 16 f2) (idpath false))))))
; f2b-2
 (defvc inf-vc-zbhead-f2b-2 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (inf-lt 0 (inf-sb m1c1 (natminus 15 j))) g3 (inf-lt nuse 256) (inf-le ic1 (add n 9))))
   (given inf-zbhead-c12-f2 (lam f2 g2 g3 f2a)))
; f2b-3
 (defvc inf-vc-zbhead-f2b-3 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (inf-lt 0 (inf-sb m1c1 (natminus 15 j))) g3 (inf-lt nuse 256) (inf-le kc1 64)))
   (given inf-zbhead-c12-f2 (lam f2 g2 g3 f2b)))
; f2b-4
 (defvc inf-vc-zbhead-f2b-4 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (inf-lt 0 (inf-sb m1c1 (natminus 15 j))) g3 (inf-lt nuse 256) (inf-lt (natminus 16 (succ j)) (natminus 16 j))))
   (given inf-zbhead-c12-f2 (lam f2 g2 g3 (inf-subfall 16 j f2))))
; f2b-5
 (defvc inf-vc-zbhead-f2b-5 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (paths nat (inf-sb m1c1 (natminus 15 j)) 0) (inf-lt (succ j) (inf-pow w))))
   (given inf-zbhead-c12-f2 (lam f2 g2 (inf-wlit (succ j) w gw (inf-letrans (succ j) 16 63 (inf-ltsu j 16 f2) (idpath false))))))
; f2b-6
 (defvc inf-vc-zbhead-f2b-6 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (paths nat (inf-sb m1c1 (natminus 15 j)) 0) (inf-le ic1 (add n 9))))
   (given inf-zbhead-c12-f2 (lam f2 g2 f2a)))
; f2b-7
 (defvc inf-vc-zbhead-f2b-7 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (paths nat (inf-sb m1c1 (natminus 15 j)) 0) (inf-le kc1 64)))
   (given inf-zbhead-c12-f2 (lam f2 g2 f2b)))
; f2b-8
 (defvc inf-vc-zbhead-f2b-8 (under inf-zbhead-c12-f2 (pi f2 (inf-lt j 16) g2 (paths nat (inf-sb m1c1 (natminus 15 j)) 0) (inf-lt (natminus 16 (succ j)) (natminus 16 j))))
   (given inf-zbhead-c12-f2 (lam f2 g2 (inf-subfall 16 j f2))))
; f1b-1
 (defvc inf-vc-zbhead-f1b-1 (under inf-zbhead-c12-f2 (pi f2 (inf-le 16 j) (inf-lt (succ u) (inf-pow w))))
   (given inf-zbhead-c12-f2 (lam f2 (inf-wlit (succ u) w gw (inf-letrans (succ u) 16 63 (inf-ltsu u 16 f1) (idpath false))))))
; f1b-2
 (defvc inf-vc-zbhead-f1b-2 (under inf-zbhead-c12-f2 (pi f2 (inf-le 16 j) (inf-le ic1 (add n 9))))
   (given inf-zbhead-c12-f2 (lam f2 f2a)))
; f1b-3
 (defvc inf-vc-zbhead-f1b-3 (under inf-zbhead-c12-f2 (pi f2 (inf-le 16 j) (inf-le kc1 64)))
   (given inf-zbhead-c12-f2 (lam f2 f2b)))
; f1b-4
 (defvc inf-vc-zbhead-f1b-4 (under inf-zbhead-c12-f2 (pi f2 (inf-le 16 j) (inf-lt (natminus 16 (succ u)) (natminus 16 u))))
   (given inf-zbhead-c12-f2 (lam f2 (inf-subfall 16 u f1))))
; f1b-5
 (defvc inf-vc-zbhead-f1b-5 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (paths nat (inf-sb m0c0 (natminus 15 u)) 0) (inf-lt (succ u) (inf-pow w))))
   (given inf-zbhead-c1-f1 (lam f1 g1 (inf-wlit (succ u) w gw (inf-letrans (succ u) 16 63 (inf-ltsu u 16 f1) (idpath false))))))
; f1b-6
 (defvc inf-vc-zbhead-f1b-6 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (paths nat (inf-sb m0c0 (natminus 15 u)) 0) (inf-le i (add n 9))))
   (given inf-zbhead-c1-f1 (lam f1 g1 f1a)))
; f1b-7
 (defvc inf-vc-zbhead-f1b-7 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (paths nat (inf-sb m0c0 (natminus 15 u)) 0) (inf-le k 64)))
   (given inf-zbhead-c1-f1 (lam f1 g1 f1b)))
; f1b-8
 (defvc inf-vc-zbhead-f1b-8 (under inf-zbhead-c1-f1 (pi f1 (inf-lt u 16) g1 (paths nat (inf-sb m0c0 (natminus 15 u)) 0) (inf-lt (natminus 16 (succ u)) (natminus 16 u))))
   (given inf-zbhead-c1-f1 (lam f1 g1 (inf-subfall 16 u f1))))
; r1-1
 (defvc inf-vc-zbhead-r1-1 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (paths nat nuse 0) (inf-le i (add n 9))))
   (given inf-zbhead-c1-f1 (lam f1 g4 f1a)))
; r1-2
 (defvc inf-vc-zbhead-r1-2 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (paths nat nuse 0) (inf-le k 64)))
   (given inf-zbhead-c1-f1 (lam f1 g4 f1b)))
; r2-1
 (defvc inf-vc-zbhead-r2-1 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (inf-lt 0 nuse) alphah0 nat g5 (inf-lt 258 alphah0) (inf-le i (add n 9))))
   (given inf-zbhead-c1-f1 (lam f1 g4 alphah0 g5 f1a)))
; r2-2
 (defvc inf-vc-zbhead-r2-2 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (inf-lt 0 nuse) alphah0 nat g5 (inf-lt 258 alphah0) (inf-le k 64)))
   (given inf-zbhead-c1-f1 (lam f1 g4 alphah0 g5 f1b)))
; c2-1
 (defvc inf-vc-zbhead-c2-1 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (inf-lt 0 nuse) alphah0 nat g5 (inf-le alphah0 258) (inf-le 32 w)))
   (given inf-zbhead-c1-f1 (lam f1 g4 alphah0 g5 gw)))
; c2-2
 (defvc inf-vc-zbhead-c2-2 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (inf-lt 0 nuse) alphah0 nat g5 (inf-le alphah0 258) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbhead-c1-f1 (lam f1 g4 alphah0 g5 gn)))
; c2-3
 (defvc inf-vc-zbhead-c2-3 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (inf-lt 0 nuse) alphah0 nat g5 (inf-le alphah0 258) (inf-le i (add n 9))))
   (given inf-zbhead-c1-f1 (lam f1 g4 alphah0 g5 f1a)))
; c2-4
 (defvc inf-vc-zbhead-c2-4 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (inf-lt 0 nuse) alphah0 nat g5 (inf-le alphah0 258) (inf-le k 64)))
   (given inf-zbhead-c1-f1 (lam f1 g4 alphah0 g5 f1b)))
; c2-5
 (defvc inf-vc-zbhead-c2-5 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (inf-lt 0 nuse) alphah0 nat g5 (inf-le alphah0 258) (inf-lt 0 3)))
   (given inf-zbhead-c1-f1 (lam f1 g4 alphah0 g5 (idpath true))))
; c2-6
 (defvc inf-vc-zbhead-c2-6 (under inf-zbhead-c1-f1 (pi f1 (inf-le 16 u) g4 (inf-lt 0 nuse) alphah0 nat g5 (inf-le alphah0 258) (inf-le 3 32)))
   (given inf-zbhead-c1-f1 (lam f1 g4 alphah0 g5 (idpath false))))
 (defcx inf-zbhead-c2 inf-zbhead-c1-f1 (f1 (inf-le 16 u)) (g4 (inf-lt 0 nuse)) (alphah0 nat) (g5 (inf-le alphah0 258)) (ic2 nat) (kc2 nat) (ngc2 nat) (c2e1 (inf-le ic2 (add n 9))) (c2e2 (inf-le kc2 64)) (c2e3 (inf-lt ngc2 (inf-pow w))) )
; c3-1
 (defvc inf-vc-zbhead-c3-1 (under inf-zbhead-c2 (inf-le 32 w))
   (given inf-zbhead-c2 gw))
; c3-2
 (defvc inf-vc-zbhead-c3-2 (under inf-zbhead-c2 (inf-lt (add n 9) (inf-pow w)))
   (given inf-zbhead-c2 gn))
; c3-3
 (defvc inf-vc-zbhead-c3-3 (under inf-zbhead-c2 (inf-le ic2 (add n 9)))
   (given inf-zbhead-c2 c2e1))
; c3-4
 (defvc inf-vc-zbhead-c3-4 (under inf-zbhead-c2 (inf-le kc2 64))
   (given inf-zbhead-c2 c2e2))
; c3-5
 (defvc inf-vc-zbhead-c3-5 (under inf-zbhead-c2 (inf-lt 0 15))
   (given inf-zbhead-c2 (idpath true)))
; c3-6
 (defvc inf-vc-zbhead-c3-6 (under inf-zbhead-c2 (inf-le 15 32))
   (given inf-zbhead-c2 (idpath false)))
 (defcx inf-zbhead-c3 inf-zbhead-c2 (ic3 nat) (kc3 nat) (nsc3 nat) (c3e1 (inf-le ic3 (add n 9))) (c3e2 (inf-le kc3 64)) (c3e3 (inf-lt nsc3 (inf-pow w))) )
; r3-1
 (defvc inf-vc-zbhead-r3-1 (under inf-zbhead-c3 (pi g6 (inf-lt ngc2 2) (inf-le ic3 (add n 9))))
   (given inf-zbhead-c3 (lam g6 c3e1)))
; r3-2
 (defvc inf-vc-zbhead-r3-2 (under inf-zbhead-c3 (pi g6 (inf-lt ngc2 2) (inf-le kc3 64)))
   (given inf-zbhead-c3 (lam g6 c3e2)))
; r4-1
 (defvc inf-vc-zbhead-r4-1 (under inf-zbhead-c3 (pi g6 (inf-le 2 ngc2) g7 (inf-lt 6 ngc2) (inf-le ic3 (add n 9))))
   (given inf-zbhead-c3 (lam g6 g7 c3e1)))
; r4-2
 (defvc inf-vc-zbhead-r4-2 (under inf-zbhead-c3 (pi g6 (inf-le 2 ngc2) g7 (inf-lt 6 ngc2) (inf-le kc3 64)))
   (given inf-zbhead-c3 (lam g6 g7 c3e2)))
; r5-1
 (defvc inf-vc-zbhead-r5-1 (under inf-zbhead-c3 (pi g6 (inf-le 2 ngc2) g7 (inf-le ngc2 6) g8 (paths nat nsc3 0) (inf-le ic3 (add n 9))))
   (given inf-zbhead-c3 (lam g6 g7 g8 c3e1)))
; r5-2
 (defvc inf-vc-zbhead-r5-2 (under inf-zbhead-c3 (pi g6 (inf-le 2 ngc2) g7 (inf-le ngc2 6) g8 (paths nat nsc3 0) (inf-le kc3 64)))
   (given inf-zbhead-c3 (lam g6 g7 g8 c3e2)))
 (defcx inf-zbhead-c3-f3 inf-zbhead-c3 (g6 (inf-le 2 ngc2)) (g7 (inf-le ngc2 6)) (g8 (inf-lt 0 nsc3)) (t nat) )
; p2-1
 (defvc inf-vc-zbhead-p2-1 (under inf-zbhead-c3-f3 (pi f3 (inf-lt t ngc2) (inf-lt t 6)))
   (given inf-zbhead-c3-f3 (lam f3 (inf-lttrans t ngc2 6 f3 g7))))
; f3b-1
 (defvc inf-vc-zbhead-f3b-1 (under inf-zbhead-c3-f3 (pi f3 (inf-lt t ngc2) (inf-lt (succ t) (inf-pow w))))
   (given inf-zbhead-c3-f3 (lam f3 (inf-wlit (succ t) w gw (inf-letrans (succ t) ngc2 63 (inf-ltsu t ngc2 f3) (inf-letrans ngc2 6 63 g7 (idpath false)))))))
; f3b-2
 (defvc inf-vc-zbhead-f3b-2 (under inf-zbhead-c3-f3 (pi f3 (inf-lt t ngc2) (inf-lt (natminus ngc2 (succ t)) (natminus ngc2 t))))
   (given inf-zbhead-c3-f3 (lam f3 (inf-subfall ngc2 t f3))))
; f4e-1
 (defvc inf-vc-zbhead-f4e-1 (under inf-zbhead-c3-f3 (pi f3 (inf-le ngc2 t) (inf-le ic3 (add n 9))))
   (given inf-zbhead-c3-f3 (lam f3 c3e1)))
; f4e-2
 (defvc inf-vc-zbhead-f4e-2 (under inf-zbhead-c3-f3 (pi f3 (inf-le ngc2 t) (inf-le kc3 64)))
   (given inf-zbhead-c3-f3 (lam f3 c3e2)))
 (defcx inf-zbhead-c3-f3-f4 inf-zbhead-c3-f3 (f3 (inf-le ngc2 t)) (u nat) (i nat) (k nat) (f4a (inf-le i (add n 9))) (f4b (inf-le k 64)) )
; s2-1
 (defvc inf-vc-zbhead-s2-1 (under inf-zbhead-c3-f3-f4 (pi f4 (inf-lt u nsc3) (inf-lt 0 (inf-pow w))))
   (given inf-zbhead-c3-f3-f4 (lam f4 (inf-wlit 0 w gw (idpath false)))))
; w1e-1
 (defvc inf-vc-zbhead-w1e-1 (under inf-zbhead-c3-f3-f4 (pi f4 (inf-lt u nsc3) (inf-le i (add n 9))))
   (given inf-zbhead-c3-f3-f4 (lam f4 f4a)))
; w1e-2
 (defvc inf-vc-zbhead-w1e-2 (under inf-zbhead-c3-f3-f4 (pi f4 (inf-lt u nsc3) (inf-le k 64)))
   (given inf-zbhead-c3-f3-f4 (lam f4 f4b)))
; w1e-3
 (defvc inf-vc-zbhead-w1e-3 (under inf-zbhead-c3-f3-f4 (pi f4 (inf-lt u nsc3) (inf-lt 0 ngc2)))
   (given inf-zbhead-c3-f3-f4 (lam f4 (bz-pos ngc2 (inf-letrans 1 ngc2 ngc2 (inf-letrans 1 2 ngc2 (idpath false) g6) (inf-refl ngc2))))))
 (defcx inf-zbhead-c3-f3-f4-w1 inf-zbhead-c3-f3-f4 (f4 (inf-lt u nsc3)) (j nat) (i nat) (k nat) (w1a (inf-le i (add n 9))) (w1b (inf-le k 64)) (w1c (inf-lt j ngc2)) )
; c4-1
 (defvc inf-vc-zbhead-c4-1 (under inf-zbhead-c3-f3-f4-w1 (pi w1 unit (inf-le 32 w)))
   (given inf-zbhead-c3-f3-f4-w1 (lam w1 gw)))
; c4-2
 (defvc inf-vc-zbhead-c4-2 (under inf-zbhead-c3-f3-f4-w1 (pi w1 unit (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbhead-c3-f3-f4-w1 (lam w1 gn)))
; c4-3
 (defvc inf-vc-zbhead-c4-3 (under inf-zbhead-c3-f3-f4-w1 (pi w1 unit (inf-le i (add n 9))))
   (given inf-zbhead-c3-f3-f4-w1 (lam w1 w1a)))
; c4-4
 (defvc inf-vc-zbhead-c4-4 (under inf-zbhead-c3-f3-f4-w1 (pi w1 unit (inf-le k 64)))
   (given inf-zbhead-c3-f3-f4-w1 (lam w1 w1b)))
; c4-5
 (defvc inf-vc-zbhead-c4-5 (under inf-zbhead-c3-f3-f4-w1 (pi w1 unit (inf-lt 0 1)))
   (given inf-zbhead-c3-f3-f4-w1 (lam w1 (idpath true))))
; c4-6
 (defvc inf-vc-zbhead-c4-6 (under inf-zbhead-c3-f3-f4-w1 (pi w1 unit (inf-le 1 32)))
   (given inf-zbhead-c3-f3-f4-w1 (lam w1 (idpath false))))
 (defcx inf-zbhead-c11 inf-zbhead-c3-f3-f4-w1 (w1 unit) (ic4 nat) (kc4 nat) (bc4 nat) (c4e1 (inf-le ic4 (add n 9))) (c4e2 (inf-le kc4 64)) (c4e3 (inf-lt bc4 (inf-pow w))) )
; h1-1
 (defvc inf-vc-zbhead-h1-1 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) (inf-lt j 6)))
   (given inf-zbhead-c11 (lam g9 (inf-lttrans j ngc2 6 w1c g7))))
; m2-1
 (defvc inf-vc-zbhead-m2-1 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat (inf-le (add 1 j) 6)))
   (given inf-zbhead-c11 (lam g9 vh1 (inf-letrans (add 1 j) ngc2 6 (inf-ltsu j ngc2 w1c) g7))))
; m2-2
 (defvc inf-vc-zbhead-m2-2 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat (inf-le (add 0 j) 6)))
   (given inf-zbhead-c11 (lam g9 vh1 (inf-letrans (add 0 j) j 6 (inf-refl j) (inf-letrans j ngc2 6 (inf-ltle j ngc2 w1c) g7)))))
; p3-1
 (defvc inf-vc-zbhead-p3-1 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat (inf-lt 0 6)))
   (given inf-zbhead-c11 (lam g9 vh1 (idpath true))))
; p4-1
 (defvc inf-vc-zbhead-p4-1 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat g11 (inf-lt u ms) (inf-lt u ms)))
   (given inf-zbhead-c11 (lam g9 vh1 g11 g11)))
; f4b-1
 (defvc inf-vc-zbhead-f4b-1 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat g11 (inf-lt u ms) (inf-lt (succ u) (inf-pow w))))
   (given inf-zbhead-c11 (lam g9 vh1 g11 (inf-lelt (succ u) nsc3 (inf-pow w) (inf-letrans (succ u) nsc3 nsc3 (inf-ltsu u nsc3 f4) (inf-refl nsc3)) c3e3))))
; f4b-2
 (defvc inf-vc-zbhead-f4b-2 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat g11 (inf-lt u ms) (inf-le ic4 (add n 9))))
   (given inf-zbhead-c11 (lam g9 vh1 g11 c4e1)))
; f4b-3
 (defvc inf-vc-zbhead-f4b-3 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat g11 (inf-lt u ms) (inf-le kc4 64)))
   (given inf-zbhead-c11 (lam g9 vh1 g11 c4e2)))
; f4b-4
 (defvc inf-vc-zbhead-f4b-4 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat g11 (inf-lt u ms) (inf-lt (natminus nsc3 (succ u)) (natminus nsc3 u))))
   (given inf-zbhead-c11 (lam g9 vh1 g11 (inf-subfall nsc3 u f4))))
; f4b-5
 (defvc inf-vc-zbhead-f4b-5 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat g11 (inf-le ms u) (inf-lt (succ u) (inf-pow w))))
   (given inf-zbhead-c11 (lam g9 vh1 g11 (inf-lelt (succ u) nsc3 (inf-pow w) (inf-letrans (succ u) nsc3 nsc3 (inf-ltsu u nsc3 f4) (inf-refl nsc3)) c3e3))))
; f4b-6
 (defvc inf-vc-zbhead-f4b-6 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat g11 (inf-le ms u) (inf-le ic4 (add n 9))))
   (given inf-zbhead-c11 (lam g9 vh1 g11 c4e1)))
; f4b-7
 (defvc inf-vc-zbhead-f4b-7 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat g11 (inf-le ms u) (inf-le kc4 64)))
   (given inf-zbhead-c11 (lam g9 vh1 g11 c4e2)))
; f4b-8
 (defvc inf-vc-zbhead-f4b-8 (under inf-zbhead-c11 (pi g9 (paths nat bc4 0) vh1 nat g11 (inf-le ms u) (inf-lt (natminus nsc3 (succ u)) (natminus nsc3 u))))
   (given inf-zbhead-c11 (lam g9 vh1 g11 (inf-subfall nsc3 u f4))))
; s3-1
 (defvc inf-vc-zbhead-s3-1 (under inf-zbhead-c11 (pi g9 (inf-lt 0 bc4) (inf-lt (add j 1) (inf-pow w))))
   (given inf-zbhead-c11 (lam g9 (inf-wlit (add j 1) w gw (inf-letrans (add j 1) ngc2 63 (inf-lt1 j ngc2 w1c) (inf-letrans ngc2 6 63 g7 (idpath false)))))))
; r6-1
 (defvc inf-vc-zbhead-r6-1 (under inf-zbhead-c11 (pi g9 (inf-lt 0 bc4) g10 (inf-le ngc2 (add j 1)) (inf-le ic4 (add n 9))))
   (given inf-zbhead-c11 (lam g9 g10 c4e1)))
; r6-2
 (defvc inf-vc-zbhead-r6-2 (under inf-zbhead-c11 (pi g9 (inf-lt 0 bc4) g10 (inf-le ngc2 (add j 1)) (inf-le kc4 64)))
   (given inf-zbhead-c11 (lam g9 g10 c4e2)))
; w1b-1
 (defvc inf-vc-zbhead-w1b-1 (under inf-zbhead-c11 (pi g9 (inf-lt 0 bc4) g10 (inf-lt (add j 1) ngc2) (inf-le ic4 (add n 9))))
   (given inf-zbhead-c11 (lam g9 g10 c4e1)))
; w1b-2
 (defvc inf-vc-zbhead-w1b-2 (under inf-zbhead-c11 (pi g9 (inf-lt 0 bc4) g10 (inf-lt (add j 1) ngc2) (inf-le kc4 64)))
   (given inf-zbhead-c11 (lam g9 g10 c4e2)))
; w1b-3
 (defvc inf-vc-zbhead-w1b-3 (under inf-zbhead-c11 (pi g9 (inf-lt 0 bc4) g10 (inf-lt (add j 1) ngc2) (inf-lt (add j 1) ngc2)))
   (given inf-zbhead-c11 (lam g9 g10 g10)))
; w1b-4
 (defvc inf-vc-zbhead-w1b-4 (under inf-zbhead-c11 (pi g9 (inf-lt 0 bc4) g10 (inf-lt (add j 1) ngc2) (inf-lt (natminus ngc2 (add j 1)) (natminus ngc2 j))))
   (given inf-zbhead-c11 (lam g9 g10 (inf-subfall1 ngc2 j w1c))))
; s4-1
 (defvc inf-vc-zbhead-s4-1 (under inf-zbhead-c3-f3-f4 (pi f4 (inf-le nsc3 u) g12 (inf-lt ms nsc3) (inf-lt ms (inf-pow w))))
   (given inf-zbhead-c3-f3-f4 (lam f4 g12 hms)))
 (defcx inf-zbhead-c4 inf-zbhead-c3-f3-f4 (f4 (inf-le nsc3 u)) (nsj1 nat) )
; s5-1
 (defvc inf-vc-zbhead-s5-1 (under inf-zbhead-c4 (inf-lt 0 (inf-pow w)))
   (given inf-zbhead-c4 (inf-wlit 0 w gw (idpath false))))
; s6-1
 (defvc inf-vc-zbhead-s6-1 (under inf-zbhead-c4 (inf-lt (add n 9) (inf-pow w)))
   (given inf-zbhead-c4 gn))
; s6-2
 (defvc inf-vc-zbhead-s6-2 (under inf-zbhead-c4 (inf-lt (inf-by16 (add n 9)) (inf-pow w)))
   (given inf-zbhead-c4 gc))
; f5e-1
 (defvc inf-vc-zbhead-f5e-1 (under inf-zbhead-c4 (inf-le i (add n 9)))
   (given inf-zbhead-c4 f4a))
; f5e-2
 (defvc inf-vc-zbhead-f5e-2 (under inf-zbhead-c4 (inf-le k 64))
   (given inf-zbhead-c4 f4b))
 (defcx inf-zbhead-c4-f5 inf-zbhead-c4 (t nat) (m nat) (i nat) (k nat) (f5a (inf-le i (add n 9))) (f5b (inf-le k 64)) )
; c5-1
 (defvc inf-vc-zbhead-c5-1 (under inf-zbhead-c4-f5 (pi f5 (inf-lt t ngc2) (inf-le 32 w)))
   (given inf-zbhead-c4-f5 (lam f5 gw)))
; c5-2
 (defvc inf-vc-zbhead-c5-2 (under inf-zbhead-c4-f5 (pi f5 (inf-lt t ngc2) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbhead-c4-f5 (lam f5 gn)))
; c5-3
 (defvc inf-vc-zbhead-c5-3 (under inf-zbhead-c4-f5 (pi f5 (inf-lt t ngc2) (inf-le i (add n 9))))
   (given inf-zbhead-c4-f5 (lam f5 f5a)))
; c5-4
 (defvc inf-vc-zbhead-c5-4 (under inf-zbhead-c4-f5 (pi f5 (inf-lt t ngc2) (inf-le k 64)))
   (given inf-zbhead-c4-f5 (lam f5 f5b)))
; c5-5
 (defvc inf-vc-zbhead-c5-5 (under inf-zbhead-c4-f5 (pi f5 (inf-lt t ngc2) (inf-lt 0 5)))
   (given inf-zbhead-c4-f5 (lam f5 (idpath true))))
; c5-6
 (defvc inf-vc-zbhead-c5-6 (under inf-zbhead-c4-f5 (pi f5 (inf-lt t ngc2) (inf-le 5 32)))
   (given inf-zbhead-c4-f5 (lam f5 (idpath false))))
 (defcx inf-zbhead-c5 inf-zbhead-c4-f5 (f5 (inf-lt t ngc2)) (ic5 nat) (kc5 nat) (cc5 nat) (c5e1 (inf-le ic5 (add n 9))) (c5e2 (inf-le kc5 64)) (c5e3 (inf-lt cc5 (inf-pow w))) )
; f6e-1
 (defvc inf-vc-zbhead-f6e-1 (under inf-zbhead-c5 (inf-le ic5 (add n 9)))
   (given inf-zbhead-c5 c5e1))
; f6e-2
 (defvc inf-vc-zbhead-f6e-2 (under inf-zbhead-c5 (inf-le kc5 64))
   (given inf-zbhead-c5 c5e2))
 (defcx inf-zbhead-c5-f6 inf-zbhead-c5 (v nat) (c nat) (i nat) (k nat) (m nat) (f6a (inf-le i (add n 9))) (f6b (inf-le k 64)) )
; w2e-1
 (defvc inf-vc-zbhead-w2e-1 (under inf-zbhead-c5-f6 (pi f6 (inf-lt v alphah0) (inf-le i (add n 9))))
   (given inf-zbhead-c5-f6 (lam f6 f6a)))
; w2e-2
 (defvc inf-vc-zbhead-w2e-2 (under inf-zbhead-c5-f6 (pi f6 (inf-lt v alphah0) (inf-le k 64)))
   (given inf-zbhead-c5-f6 (lam f6 f6b)))
 (defcx inf-zbhead-c5-f6-w2 inf-zbhead-c5-f6 (f6 (inf-lt v alphah0)) (c nat) (i nat) (k nat) (m nat) (w2a (inf-le i (add n 9))) (w2b (inf-le k 64)) )
; r7-1
 (defvc inf-vc-zbhead-r7-1 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-le (inf-by16 (add n 9)) m) (inf-le i (add n 9))))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 w2a)))
; r7-2
 (defvc inf-vc-zbhead-r7-2 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-le (inf-by16 (add n 9)) m) (inf-le k 64)))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 w2b)))
; s7-1
 (defvc inf-vc-zbhead-s7-1 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) (inf-lt (add m 1) (inf-pow w))))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 (inf-lelt (add m 1) (inf-by16 (add n 9)) (inf-pow w) (inf-letrans (add m 1) (inf-by16 (add n 9)) (inf-by16 (add n 9)) (inf-lt1 m (inf-by16 (add n 9)) g13) (inf-refl (inf-by16 (add n 9)))) gc))))
; r8-1
 (defvc inf-vc-zbhead-r8-1 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-lt c 1) (inf-le i (add n 9))))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 w2a)))
; r8-2
 (defvc inf-vc-zbhead-r8-2 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-lt c 1) (inf-le k 64)))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 w2b)))
; r9-1
 (defvc inf-vc-zbhead-r9-1 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-le 1 c) g15 (inf-lt 20 c) (inf-le i (add n 9))))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 g15 w2a)))
; r9-2
 (defvc inf-vc-zbhead-r9-2 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-le 1 c) g15 (inf-lt 20 c) (inf-le k 64)))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 g15 w2b)))
; c6-1
 (defvc inf-vc-zbhead-c6-1 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-le 1 c) g15 (inf-le c 20) (inf-le 32 w)))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 g15 gw)))
; c6-2
 (defvc inf-vc-zbhead-c6-2 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-le 1 c) g15 (inf-le c 20) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 g15 gn)))
; c6-3
 (defvc inf-vc-zbhead-c6-3 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-le 1 c) g15 (inf-le c 20) (inf-le i (add n 9))))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 g15 w2a)))
; c6-4
 (defvc inf-vc-zbhead-c6-4 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-le 1 c) g15 (inf-le c 20) (inf-le k 64)))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 g15 w2b)))
; c6-5
 (defvc inf-vc-zbhead-c6-5 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-le 1 c) g15 (inf-le c 20) (inf-lt 0 1)))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 g15 (idpath true))))
; c6-6
 (defvc inf-vc-zbhead-c6-6 (under inf-zbhead-c5-f6-w2 (pi w2 unit g13 (inf-lt m (inf-by16 (add n 9))) g14 (inf-le 1 c) g15 (inf-le c 20) (inf-le 1 32)))
   (given inf-zbhead-c5-f6-w2 (lam w2 g13 g14 g15 (idpath false))))
 (defcx inf-zbhead-c8 inf-zbhead-c5-f6-w2 (w2 unit) (g13 (inf-lt m (inf-by16 (add n 9)))) (g14 (inf-le 1 c)) (g15 (inf-le c 20)) (ic6 nat) (kc6 nat) (bc6 nat) (c6e1 (inf-le ic6 (add n 9))) (c6e2 (inf-le kc6 64)) (c6e3 (inf-lt bc6 (inf-pow w))) )
; p5-1
 (defvc inf-vc-zbhead-p5-1 (under inf-zbhead-c8 (pi g16 (paths nat bc6 0) (inf-lt v 258)))
   (given inf-zbhead-c8 (lam g16 (inf-lttrans v alphah0 258 f6 g5))))
; f6b-1
 (defvc inf-vc-zbhead-f6b-1 (under inf-zbhead-c8 (pi g16 (paths nat bc6 0) (inf-lt (succ v) (inf-pow w))))
   (given inf-zbhead-c8 (lam g16 (inf-lelt (succ v) 1024 (inf-pow w) (inf-letrans (succ v) alphah0 1024 (inf-ltsu v alphah0 f6) (inf-letrans alphah0 258 1024 g5 (idpath false))) (bz-w1k w gw)))))
; f6b-2
 (defvc inf-vc-zbhead-f6b-2 (under inf-zbhead-c8 (pi g16 (paths nat bc6 0) (inf-le ic6 (add n 9))))
   (given inf-zbhead-c8 (lam g16 c6e1)))
; f6b-3
 (defvc inf-vc-zbhead-f6b-3 (under inf-zbhead-c8 (pi g16 (paths nat bc6 0) (inf-le kc6 64)))
   (given inf-zbhead-c8 (lam g16 c6e2)))
; f6b-4
 (defvc inf-vc-zbhead-f6b-4 (under inf-zbhead-c8 (pi g16 (paths nat bc6 0) (inf-lt (natminus alphah0 (succ v)) (natminus alphah0 v))))
   (given inf-zbhead-c8 (lam g16 (inf-subfall alphah0 v f6))))
; c7-1
 (defvc inf-vc-zbhead-c7-1 (under inf-zbhead-c8 (pi g16 (inf-lt 0 bc6) (inf-le 32 w)))
   (given inf-zbhead-c8 (lam g16 gw)))
; c7-2
 (defvc inf-vc-zbhead-c7-2 (under inf-zbhead-c8 (pi g16 (inf-lt 0 bc6) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbhead-c8 (lam g16 gn)))
; c7-3
 (defvc inf-vc-zbhead-c7-3 (under inf-zbhead-c8 (pi g16 (inf-lt 0 bc6) (inf-le ic6 (add n 9))))
   (given inf-zbhead-c8 (lam g16 c6e1)))
; c7-4
 (defvc inf-vc-zbhead-c7-4 (under inf-zbhead-c8 (pi g16 (inf-lt 0 bc6) (inf-le kc6 64)))
   (given inf-zbhead-c8 (lam g16 c6e2)))
; c7-5
 (defvc inf-vc-zbhead-c7-5 (under inf-zbhead-c8 (pi g16 (inf-lt 0 bc6) (inf-lt 0 1)))
   (given inf-zbhead-c8 (lam g16 (idpath true))))
; c7-6
 (defvc inf-vc-zbhead-c7-6 (under inf-zbhead-c8 (pi g16 (inf-lt 0 bc6) (inf-le 1 32)))
   (given inf-zbhead-c8 (lam g16 (idpath false))))
 (defcx inf-zbhead-c9 inf-zbhead-c8 (g16 (inf-lt 0 bc6)) (ic7 nat) (kc7 nat) (xc7 nat) (c7e1 (inf-le ic7 (add n 9))) (c7e2 (inf-le kc7 64)) (c7e3 (inf-lt xc7 (inf-pow w))) )
; d2-1
 (defvc inf-vc-zbhead-d2-1 (under inf-zbhead-c9 (pi g17 (inf-lt 0 xc7) (inf-le 1 c)))
   (given inf-zbhead-c9 (lam g17 g14)))
; s8-1
 (defvc inf-vc-zbhead-s8-1 (under inf-zbhead-c9 (pi g17 (paths nat xc7 0) (inf-lt (add c 1) (inf-pow w))))
   (given inf-zbhead-c9 (lam g17 (inf-wlit (add c 1) w gw (inf-letrans (add c 1) 21 63 (inf-addr c 20 1 g15) (idpath false))))))
 (defcx inf-zbhead-c10 inf-zbhead-c9 (cj2 nat) )
; w2b-1
 (defvc inf-vc-zbhead-w2b-1 (under inf-zbhead-c10 (inf-le ic7 (add n 9)))
   (given inf-zbhead-c10 c7e1))
; w2b-2
 (defvc inf-vc-zbhead-w2b-2 (under inf-zbhead-c10 (inf-le kc7 64))
   (given inf-zbhead-c10 c7e2))
; w2b-3
 (defvc inf-vc-zbhead-w2b-3 (under inf-zbhead-c10 (inf-lt (natminus (inf-by16 (add n 9)) (add m 1)) (natminus (inf-by16 (add n 9)) m)))
   (given inf-zbhead-c10 (inf-subfall1 (inf-by16 (add n 9)) m g13)))
; t1-1
 (defvc inf-vc-zbhead-t1-1 (under inf-zbhead-c5-f6 (pi f6 (inf-le alphah0 v) (inf-lt t 6)))
   (given inf-zbhead-c5-f6 (lam f6 (inf-lttrans t ngc2 6 f5 g7))))
; c8-1
 (defvc inf-vc-zbhead-c8-1 (under inf-zbhead-c5-f6 (pi f6 (inf-le alphah0 v) (inf-le 32 w)))
   (given inf-zbhead-c5-f6 (lam f6 gw)))
; c8-2
 (defvc inf-vc-zbhead-c8-2 (under inf-zbhead-c5-f6 (pi f6 (inf-le alphah0 v) (inf-le 19 tl)))
   (given inf-zbhead-c5-f6 (lam f6 (inf-letrans 19 tl tl (inf-letrans 19 20 tl (idpath false) h20) (inf-refl tl)))))
; c8-3
 (defvc inf-vc-zbhead-c8-3 (under inf-zbhead-c5-f6 (pi f6 (inf-le alphah0 v) (inf-lt tl 31)))
   (given inf-zbhead-c5-f6 (lam f6 (inf-lelts tl 30 (inf-letrans tl 30 30 (inf-ltle tl 30 hq) (inf-refl 30))))))
; c8-4
 (defvc inf-vc-zbhead-c8-4 (under inf-zbhead-c5-f6 (pi f6 (inf-le alphah0 v) (inf-le 20 tl)))
   (given inf-zbhead-c5-f6 (lam f6 h20)))
; c8-5
 (defvc inf-vc-zbhead-c8-5 (under inf-zbhead-c5-f6 (pi f6 (inf-le alphah0 v) (inf-lt tl 30)))
   (given inf-zbhead-c5-f6 (lam f6 hq)))
; c8-6
 (defvc inf-vc-zbhead-c8-6 (under inf-zbhead-c5-f6 (pi f6 (inf-le alphah0 v) (inf-le alphah0 258)))
   (given inf-zbhead-c5-f6 (lam f6 g5)))
 (defcx inf-zbhead-c6 inf-zbhead-c5-f6 (f6 (inf-le alphah0 v)) (xc8 nat) )
; r10-1
 (defvc inf-vc-zbhead-r10-1 (under inf-zbhead-c6 (pi g18 (paths nat xc8 0) (inf-le i (add n 9))))
   (given inf-zbhead-c6 (lam g18 f6a)))
; r10-2
 (defvc inf-vc-zbhead-r10-2 (under inf-zbhead-c6 (pi g18 (paths nat xc8 0) (inf-le k 64)))
   (given inf-zbhead-c6 (lam g18 f6b)))
 (defcx inf-zbhead-c7 inf-zbhead-c6 (g18 (inf-lt 0 xc8)) (xc9 nat) )
; r11-1
 (defvc inf-vc-zbhead-r11-1 (under inf-zbhead-c7 (pi g19 (inf-lt 0 xc9) (inf-le i (add n 9))))
   (given inf-zbhead-c7 (lam g19 f6a)))
; r11-2
 (defvc inf-vc-zbhead-r11-2 (under inf-zbhead-c7 (pi g19 (inf-lt 0 xc9) (inf-le k 64)))
   (given inf-zbhead-c7 (lam g19 f6b)))
; f5b-1
 (defvc inf-vc-zbhead-f5b-1 (under inf-zbhead-c7 (pi g19 (paths nat xc9 0) (inf-lt (succ t) (inf-pow w))))
   (given inf-zbhead-c7 (lam g19 (inf-wlit (succ t) w gw (inf-letrans (succ t) ngc2 63 (inf-ltsu t ngc2 f5) (inf-letrans ngc2 6 63 g7 (idpath false)))))))
; f5b-2
 (defvc inf-vc-zbhead-f5b-2 (under inf-zbhead-c7 (pi g19 (paths nat xc9 0) (inf-le i (add n 9))))
   (given inf-zbhead-c7 (lam g19 f6a)))
; f5b-3
 (defvc inf-vc-zbhead-f5b-3 (under inf-zbhead-c7 (pi g19 (paths nat xc9 0) (inf-le k 64)))
   (given inf-zbhead-c7 (lam g19 f6b)))
; f5b-4
 (defvc inf-vc-zbhead-f5b-4 (under inf-zbhead-c7 (pi g19 (paths nat xc9 0) (inf-lt (natminus ngc2 (succ t)) (natminus ngc2 t))))
   (given inf-zbhead-c7 (lam g19 (inf-subfall ngc2 t f5))))
; r12-1
 (defvc inf-vc-zbhead-r12-1 (under inf-zbhead-c4-f5 (pi f5 (inf-le ngc2 t) (inf-le i (add n 9))))
   (given inf-zbhead-c4-f5 (lam f5 f5a)))
; r12-2
 (defvc inf-vc-zbhead-r12-2 (under inf-zbhead-c4-f5 (pi f5 (inf-le ngc2 t) (inf-le k 64)))
   (given inf-zbhead-c4-f5 (lam f5 f5b)))
 (defcx inf-zbsyms (In (pi x nat nat)) (n nat) (w nat) (i0 nat) (k0 nat) (gw (inf-le 32 w)) (gn (inf-lt (add n 9) (inf-pow w))) (gi (inf-le i0 (add n 9))) (gk (inf-le k0 64)) (Sq (pi x nat nat)) (Sl (pi x nat nat)) (Yy (pi x nat nat)) (Cn (pi x nat nat)) (Zt (pi x nat nat)) (ms nat) (tn nat) (lim nat) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hts (inf-le tn (inf-pow lim))) (hms (inf-lt ms (inf-pow w))) )
; r0-1
 (defvc inf-vc-zbsyms-r0-1 (under inf-zbsyms (pi alphah0 nat nsh1 nat g0 (inf-lt 258 alphah0) (inf-le i0 (add n 9))))
   (given inf-zbsyms (lam alphah0 nsh1 g0 gi)))
; r0-2
 (defvc inf-vc-zbsyms-r0-2 (under inf-zbsyms (pi alphah0 nat nsh1 nat g0 (inf-lt 258 alphah0) (inf-le k0 64)))
   (given inf-zbsyms (lam alphah0 nsh1 g0 gk)))
; r1-1
 (defvc inf-vc-zbsyms-r1-1 (under inf-zbsyms (pi alphah0 nat nsh1 nat g0 (inf-le alphah0 258) g1 (inf-lt alphah0 2) (inf-le i0 (add n 9))))
   (given inf-zbsyms (lam alphah0 nsh1 g0 g1 gi)))
; r1-2
 (defvc inf-vc-zbsyms-r1-2 (under inf-zbsyms (pi alphah0 nat nsh1 nat g0 (inf-le alphah0 258) g1 (inf-lt alphah0 2) (inf-le k0 64)))
   (given inf-zbsyms (lam alphah0 nsh1 g0 g1 gk)))
; r2-1
 (defvc inf-vc-zbsyms-r2-1 (under inf-zbsyms (pi alphah0 nat nsh1 nat g0 (inf-le alphah0 258) g1 (inf-le 2 alphah0) g2 (inf-lt ms nsh1) (inf-le i0 (add n 9))))
   (given inf-zbsyms (lam alphah0 nsh1 g0 g1 g2 gi)))
; r2-2
 (defvc inf-vc-zbsyms-r2-2 (under inf-zbsyms (pi alphah0 nat nsh1 nat g0 (inf-le alphah0 258) g1 (inf-le 2 alphah0) g2 (inf-lt ms nsh1) (inf-le k0 64)))
   (given inf-zbsyms (lam alphah0 nsh1 g0 g1 g2 gk)))
; r3-1
 (defvc inf-vc-zbsyms-r3-1 (under inf-zbsyms (pi alphah0 nat nsh1 nat g0 (inf-le alphah0 258) g1 (inf-le 2 alphah0) g2 (inf-le nsh1 ms) mxh2 nat g3 (inf-lt tn mxh2) (inf-le i0 (add n 9))))
   (given inf-zbsyms (lam alphah0 nsh1 g0 g1 g2 mxh2 g3 gi)))
; r3-2
 (defvc inf-vc-zbsyms-r3-2 (under inf-zbsyms (pi alphah0 nat nsh1 nat g0 (inf-le alphah0 258) g1 (inf-le 2 alphah0) g2 (inf-le nsh1 ms) mxh2 nat g3 (inf-lt tn mxh2) (inf-le k0 64)))
   (given inf-zbsyms (lam alphah0 nsh1 g0 g1 g2 mxh2 g3 gk)))
; s0-1
 (defvc inf-vc-zbsyms-s0-1 (under inf-zbsyms (pi alphah0 nat nsh1 nat g0 (inf-le alphah0 258) g1 (inf-le 2 alphah0) g2 (inf-le nsh1 ms) mxh2 nat g3 (inf-le mxh2 tn) (inf-lt 0 (inf-pow w))))
   (given inf-zbsyms (lam alphah0 nsh1 g0 g1 g2 mxh2 g3 (inf-wlit 0 w gw (idpath false)))))
 (defcx inf-zbsyms-f0 inf-zbsyms (alphah0 nat) (nsh1 nat) (g0 (inf-le alphah0 258)) (g1 (inf-le 2 alphah0)) (g2 (inf-le nsh1 ms)) (mxh2 nat) (g3 (inf-le mxh2 tn)) (runh3 nat) (rwh4 nat) (y nat) )
; p0-1
 (defvc inf-vc-zbsyms-p0-1 (under inf-zbsyms-f0 (pi f0 (inf-lt y 256) (inf-lt y 256)))
   (given inf-zbsyms-f0 (lam f0 f0)))
; f0b-1
 (defvc inf-vc-zbsyms-f0b-1 (under inf-zbsyms-f0 (pi f0 (inf-lt y 256) (inf-lt (succ y) (inf-pow w))))
   (given inf-zbsyms-f0 (lam f0 (inf-lelt (succ y) 1024 (inf-pow w) (inf-letrans (succ y) 256 1024 (inf-ltsu y 256 f0) (idpath false)) (bz-w1k w gw)))))
; f0b-2
 (defvc inf-vc-zbsyms-f0b-2 (under inf-zbsyms-f0 (pi f0 (inf-lt y 256) (inf-lt (natminus 256 (succ y)) (natminus 256 y))))
   (given inf-zbsyms-f0 (lam f0 (inf-subfall 256 y f0))))
; f1e-1
 (defvc inf-vc-zbsyms-f1e-1 (under inf-zbsyms-f0 (pi f0 (inf-le 256 y) (inf-le i0 (add n 9))))
   (given inf-zbsyms-f0 (lam f0 gi)))
; f1e-2
 (defvc inf-vc-zbsyms-f1e-2 (under inf-zbsyms-f0 (pi f0 (inf-le 256 y) (inf-le k0 64)))
   (given inf-zbsyms-f0 (lam f0 gk)))
; f1e-3
 (defvc inf-vc-zbsyms-f1e-3 (under inf-zbsyms-f0 (pi f0 (inf-le 256 y) (inf-le 0 mxh2)))
   (given inf-zbsyms-f0 (lam f0 (idpath false))))
 (defcx inf-zbsyms-f0-f1 inf-zbsyms-f0 (f0 (inf-le 256 y)) (g nat) (y nat) (rw nat) (run nat) (nb nat) (i nat) (k nat) (f1a (inf-le i (add n 9))) (f1b (inf-le k 64)) (f1c (inf-le nb mxh2)) )
 (defcx inf-zbsyms-c1 inf-zbsyms-f0-f1 (f1 (inf-lt g nsh1)) (xc1 nat) )
; r4-1
 (defvc inf-vc-zbsyms-r4-1 (under inf-zbsyms-c1 (pi g4 (inf-lt 0 xc1) (inf-le i (add n 9))))
   (given inf-zbsyms-c1 (lam g4 f1a)))
; r4-2
 (defvc inf-vc-zbsyms-r4-2 (under inf-zbsyms-c1 (pi g4 (inf-lt 0 xc1) (inf-le k 64)))
   (given inf-zbsyms-c1 (lam g4 f1b)))
; h5-1
 (defvc inf-vc-zbsyms-h5-1 (under inf-zbsyms-c1 (pi g4 (paths nat xc1 0) (inf-lt g ms)))
   (given inf-zbsyms-c1 (lam g4 (inf-lttrans g nsh1 ms f1 g2))))
; r5-1
 (defvc inf-vc-zbsyms-r5-1 (under inf-zbsyms-c1 (pi g4 (paths nat xc1 0) xh5 nat g5 (inf-lt 5 xh5) (inf-le i (add n 9))))
   (given inf-zbsyms-c1 (lam g4 xh5 g5 f1a)))
; r5-2
 (defvc inf-vc-zbsyms-r5-2 (under inf-zbsyms-c1 (pi g4 (paths nat xc1 0) xh5 nat g5 (inf-lt 5 xh5) (inf-le k 64)))
   (given inf-zbsyms-c1 (lam g4 xh5 g5 f1b)))
; t0-1
 (defvc inf-vc-zbsyms-t0-1 (under inf-zbsyms-c1 (pi g4 (paths nat xc1 0) xh5 nat g5 (inf-le xh5 5) (inf-lt xh5 6)))
   (given inf-zbsyms-c1 (lam g4 xh5 g5 (inf-lelts xh5 5 g5))))
; f2e-1
 (defvc inf-vc-zbsyms-f2e-1 (under inf-zbsyms-c1 (pi g4 (paths nat xc1 0) xh5 nat g5 (inf-le xh5 5) (inf-le i (add n 9))))
   (given inf-zbsyms-c1 (lam g4 xh5 g5 f1a)))
; f2e-2
 (defvc inf-vc-zbsyms-f2e-2 (under inf-zbsyms-c1 (pi g4 (paths nat xc1 0) xh5 nat g5 (inf-le xh5 5) (inf-le k 64)))
   (given inf-zbsyms-c1 (lam g4 xh5 g5 f1b)))
; f2e-3
 (defvc inf-vc-zbsyms-f2e-3 (under inf-zbsyms-c1 (pi g4 (paths nat xc1 0) xh5 nat g5 (inf-le xh5 5) (inf-le nb mxh2)))
   (given inf-zbsyms-c1 (lam g4 xh5 g5 f1c)))
 (defcx inf-zbsyms-c1-f2 inf-zbsyms-c1 (g4 (paths nat xc1 0)) (xh5 nat) (g5 (inf-le xh5 5)) (left nat) (y nat) (rw nat) (run nat) (nb nat) (i nat) (k nat) (f2a (inf-le i (add n 9))) (f2b (inf-le k 64)) (f2c (inf-le nb mxh2)) )
; c2-1
 (defvc inf-vc-zbsyms-c2-1 (under inf-zbsyms-c1-f2 (pi f2 (inf-lt left 50) (inf-le 32 w)))
   (given inf-zbsyms-c1-f2 (lam f2 gw)))
; c2-2
 (defvc inf-vc-zbsyms-c2-2 (under inf-zbsyms-c1-f2 (pi f2 (inf-lt left 50) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbsyms-c1-f2 (lam f2 gn)))
; c2-3
 (defvc inf-vc-zbsyms-c2-3 (under inf-zbsyms-c1-f2 (pi f2 (inf-lt left 50) (inf-le i (add n 9))))
   (given inf-zbsyms-c1-f2 (lam f2 f2a)))
; c2-4
 (defvc inf-vc-zbsyms-c2-4 (under inf-zbsyms-c1-f2 (pi f2 (inf-lt left 50) (inf-le k 64)))
   (given inf-zbsyms-c1-f2 (lam f2 f2b)))
 (defcx inf-zbsyms-c2 inf-zbsyms-c1-f2 (f2 (inf-lt left 50)) (ic2 nat) (kc2 nat) (sc2 nat) (c2e1 (inf-le ic2 (add n 9))) (c2e2 (inf-le kc2 64)) )
; r6-1
 (defvc inf-vc-zbsyms-r6-1 (under inf-zbsyms-c2 (pi g6 (inf-le alphah0 sc2) (inf-le ic2 (add n 9))))
   (given inf-zbsyms-c2 (lam g6 c2e1)))
; r6-2
 (defvc inf-vc-zbsyms-r6-2 (under inf-zbsyms-c2 (pi g6 (inf-le alphah0 sc2) (inf-le kc2 64)))
   (given inf-zbsyms-c2 (lam g6 c2e2)))
; r7-1
 (defvc inf-vc-zbsyms-r7-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-lt mxh2 rw) (inf-le ic2 (add n 9))))
   (given inf-zbsyms-c2 (lam g6 g7 g8 c2e1)))
; r7-2
 (defvc inf-vc-zbsyms-r7-2 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-lt mxh2 rw) (inf-le kc2 64)))
   (given inf-zbsyms-c2 (lam g6 g7 g8 c2e2)))
; h6-1
 (defvc inf-vc-zbsyms-h6-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-le rw mxh2) (inf-lt sc2 64)))
   (given inf-zbsyms-c2 (lam g6 g7 g8 (inf-lelts sc2 63 (inf-letrans sc2 2 63 (inf-ltle sc2 2 g7) (idpath false))))))
; h7-1
 (defvc inf-vc-zbsyms-h7-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-le rw mxh2) runh6 nat (inf-lt 1 64)))
   (given inf-zbsyms-c2 (lam g6 g7 g8 runh6 (idpath true))))
; r8-1
 (defvc inf-vc-zbsyms-r8-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-le rw mxh2) runh6 nat rwh7 nat g9 (inf-lt mxh2 runh6) (inf-le ic2 (add n 9))))
   (given inf-zbsyms-c2 (lam g6 g7 g8 runh6 rwh7 g9 c2e1)))
; r8-2
 (defvc inf-vc-zbsyms-r8-2 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-le rw mxh2) runh6 nat rwh7 nat g9 (inf-lt mxh2 runh6) (inf-le kc2 64)))
   (given inf-zbsyms-c2 (lam g6 g7 g8 runh6 rwh7 g9 c2e2)))
; f2b-1
 (defvc inf-vc-zbsyms-f2b-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-le rw mxh2) runh6 nat rwh7 nat g9 (inf-le runh6 mxh2) (inf-lt (succ left) (inf-pow w))))
   (given inf-zbsyms-c2 (lam g6 g7 g8 runh6 rwh7 g9 (inf-wlit (succ left) w gw (inf-letrans (succ left) 50 63 (inf-ltsu left 50 f2) (idpath false))))))
; f2b-2
 (defvc inf-vc-zbsyms-f2b-2 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-le rw mxh2) runh6 nat rwh7 nat g9 (inf-le runh6 mxh2) (inf-le ic2 (add n 9))))
   (given inf-zbsyms-c2 (lam g6 g7 g8 runh6 rwh7 g9 c2e1)))
; f2b-3
 (defvc inf-vc-zbsyms-f2b-3 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-le rw mxh2) runh6 nat rwh7 nat g9 (inf-le runh6 mxh2) (inf-le kc2 64)))
   (given inf-zbsyms-c2 (lam g6 g7 g8 runh6 rwh7 g9 c2e2)))
; f2b-4
 (defvc inf-vc-zbsyms-f2b-4 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-le rw mxh2) runh6 nat rwh7 nat g9 (inf-le runh6 mxh2) (inf-le nb mxh2)))
   (given inf-zbsyms-c2 (lam g6 g7 g8 runh6 rwh7 g9 f2c)))
; f2b-5
 (defvc inf-vc-zbsyms-f2b-5 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-lt sc2 2) g8 (inf-le rw mxh2) runh6 nat rwh7 nat g9 (inf-le runh6 mxh2) (inf-lt (natminus 50 (succ left)) (natminus 50 left))))
   (given inf-zbsyms-c2 (lam g6 g7 g8 runh6 rwh7 g9 (inf-subfall 50 left f2))))
; h8-1
 (defvc inf-vc-zbsyms-h8-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-le 2 sc2) g10 (inf-lt 0 run) (inf-lt 0 256)))
   (given inf-zbsyms-c2 (lam g6 g7 g10 (idpath true))))
; h9-1
 (defvc inf-vc-zbsyms-h9-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-le 2 sc2) g10 (inf-lt 0 run) yh8 nat (inf-lt (inf-mod 256 yh8) 256)))
   (given inf-zbsyms-c2 (lam g6 g7 g10 yh8 (inf-lelts (inf-mod 256 yh8) 255 (inf-letrans (inf-mod 256 yh8) 255 255 (inf-ltsle (inf-mod 256 yh8) 255 (inf-modlt 255 yh8)) (inf-refl 255))))))
; i9-1
 (defvc inf-vc-zbsyms-i9-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-le 2 sc2) g10 (inf-lt 0 run) yh8 nat ch9 nat (inf-le nb mxh2)))
   (given inf-zbsyms-c2 (lam g6 g7 g10 yh8 ch9 f2c)))
; r9-1
 (defvc inf-vc-zbsyms-r9-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-le 2 sc2) g10 (inf-lt 0 run) yh8 nat ch9 nat g11 (inf-lt (natminus mxh2 nb) run) (inf-le ic2 (add n 9))))
   (given inf-zbsyms-c2 (lam g6 g7 g10 yh8 ch9 g11 c2e1)))
; r9-2
 (defvc inf-vc-zbsyms-r9-2 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-le 2 sc2) g10 (inf-lt 0 run) yh8 nat ch9 nat g11 (inf-lt (natminus mxh2 nb) run) (inf-le kc2 64)))
   (given inf-zbsyms-c2 (lam g6 g7 g10 yh8 ch9 g11 c2e2)))
; p1-1
 (defvc inf-vc-zbsyms-p1-1 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-le 2 sc2) g10 (inf-lt 0 run) yh8 nat ch9 nat g11 (inf-le run (natminus mxh2 nb)) (inf-lt (inf-mod 256 ch9) 256)))
   (given inf-zbsyms-c2 (lam g6 g7 g10 yh8 ch9 g11 (inf-lelts (inf-mod 256 ch9) 255 (inf-letrans (inf-mod 256 ch9) 255 255 (inf-ltsle (inf-mod 256 ch9) 255 (inf-modlt 255 ch9)) (inf-refl 255))))))
 (defcx inf-zbsyms-c2-f3 inf-zbsyms-c2 (g6 (inf-lt sc2 alphah0)) (g7 (inf-le 2 sc2)) (g10 (inf-lt 0 run)) (yh8 nat) (ch9 nat) (g11 (inf-le run (natminus mxh2 nb))) (q nat) )
; p2-1
 (defvc inf-vc-zbsyms-p2-1 (under inf-zbsyms-c2-f3 (pi f3 (inf-lt q run) (inf-lt (add nb q) (inf-pow w))))
   (given inf-zbsyms-c2-f3 (lam f3 (inf-lttrans (add nb q) mxh2 (inf-pow w) ((bz-nbq nb q run mxh2 f3 g11 f2c)) (inf-ltle mxh2 (inf-pow w) ((inf-lelt mxh2 (inf-pow lim) (inf-pow w) ((inf-letrans mxh2 tn (inf-pow lim) g3 hts)) ((inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))))))
; p2-2
 (defvc inf-vc-zbsyms-p2-2 (under inf-zbsyms-c2-f3 (pi f3 (inf-lt q run) (inf-lt (add nb q) tn)))
   (given inf-zbsyms-c2-f3 (lam f3 (inf-lttrans (add nb q) mxh2 tn ((bz-nbq nb q run mxh2 f3 g11 f2c)) g3))))
; f3b-1
 (defvc inf-vc-zbsyms-f3b-1 (under inf-zbsyms-c2-f3 (pi f3 (inf-lt q run) (inf-lt (succ q) (inf-pow w))))
   (given inf-zbsyms-c2-f3 (lam f3 (inf-lelt (succ q) mxh2 (inf-pow w) (inf-letrans (succ q) run mxh2 (inf-ltsu q run f3) (inf-letrans run (natminus mxh2 nb) mxh2 g11 (inf-suble mxh2 nb))) ((inf-lelt mxh2 (inf-pow lim) (inf-pow w) ((inf-letrans mxh2 tn (inf-pow lim) g3 hts)) ((inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false))))))))))
; f3b-2
 (defvc inf-vc-zbsyms-f3b-2 (under inf-zbsyms-c2-f3 (pi f3 (inf-lt q run) (inf-lt (natminus run (succ q)) (natminus run q))))
   (given inf-zbsyms-c2-f3 (lam f3 (inf-subfall run q f3))))
; s1-1
 (defvc inf-vc-zbsyms-s1-1 (under inf-zbsyms-c2-f3 (pi f3 (inf-le run q) (inf-lt (add nb run) (inf-pow w))))
   (given inf-zbsyms-c2-f3 (lam f3 (inf-fitlim w lim nb run gw hm (inf-letrans nb mxh2 (inf-pow lim) f2c (inf-letrans mxh2 tn (inf-pow lim) g3 hts)) (inf-letrans run (natminus mxh2 nb) (inf-pow lim) g11 (inf-letrans (natminus mxh2 nb) mxh2 (inf-pow lim) (inf-suble mxh2 nb) (inf-letrans mxh2 tn (inf-pow lim) g3 hts)))))))
; j0j-1
 (defvc inf-vc-zbsyms-j0j-1 (under inf-zbsyms-c2-f3 (pi f3 (inf-le run q) runh10 nat rwh11 nat (inf-le (add nb run) mxh2)))
   (given inf-zbsyms-c2-f3 (lam f3 runh10 rwh11 (bz-nbr nb run mxh2 g11 f2c))))
; j0j-2
 (defvc inf-vc-zbsyms-j0j-2 (under inf-zbsyms-c2 (pi g6 (inf-lt sc2 alphah0) g7 (inf-le 2 sc2) g10 (paths nat run 0) (inf-le nb mxh2)))
   (given inf-zbsyms-c2 (lam g6 g7 g10 f2c)))
 (defcx inf-zbsyms-c3 inf-zbsyms-c2 (g6 (inf-lt sc2 alphah0)) (g7 (inf-le 2 sc2)) (yj0 nat) (nbj0 nat) (runj0 nat) (rwj0 nat) (j0a (inf-le nbj0 mxh2)) )
; i10-1
 (defvc inf-vc-zbsyms-i10-1 (under inf-zbsyms-c3 (inf-le 1 alphah0))
   (given inf-zbsyms-c3 (inf-letrans 1 sc2 alphah0 (inf-letrans 1 2 sc2 (idpath false) g7) (inf-letrans sc2 alphah0 alphah0 (inf-ltle sc2 alphah0 g6) (inf-refl alphah0)))))
; r10-1
 (defvc inf-vc-zbsyms-r10-1 (under inf-zbsyms-c3 (pi g12 (inf-le (natminus alphah0 1) sc2) (inf-le ic2 (add n 9))))
   (given inf-zbsyms-c3 (lam g12 c2e1)))
; r10-2
 (defvc inf-vc-zbsyms-r10-2 (under inf-zbsyms-c3 (pi g12 (inf-le (natminus alphah0 1) sc2) (inf-le kc2 64)))
   (given inf-zbsyms-c3 (lam g12 c2e2)))
; r11-1
 (defvc inf-vc-zbsyms-r11-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-le mxh2 nbj0) (inf-le ic2 (add n 9))))
   (given inf-zbsyms-c3 (lam g12 g13 c2e1)))
; r11-2
 (defvc inf-vc-zbsyms-r11-2 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-le mxh2 nbj0) (inf-le kc2 64)))
   (given inf-zbsyms-c3 (lam g12 g13 c2e2)))
; s2-1
 (defvc inf-vc-zbsyms-s2-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) (inf-le 1 sc2)))
   (given inf-zbsyms-c3 (lam g12 g13 (inf-letrans 1 sc2 sc2 (inf-letrans 1 2 sc2 (idpath false) g7) (inf-refl sc2)))))
; s2-2
 (defvc inf-vc-zbsyms-s2-2 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) (inf-lt (natminus sc2 1) (inf-pow w))))
   (given inf-zbsyms-c3 (lam g12 g13 (inf-lelt (natminus sc2 1) 1024 (inf-pow w) (inf-letrans (natminus sc2 1) sc2 1024 (inf-suble sc2 1) (inf-letrans sc2 alphah0 1024 (inf-ltle sc2 alphah0 g6) (inf-letrans alphah0 258 1024 g0 (idpath false)))) (bz-w1k w gw)))))
; r13-1
 (defvc inf-vc-zbsyms-r13-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-le 256 (natminus sc2 1)) (inf-le ic2 (add n 9))))
   (given inf-zbsyms-c3 (lam g12 g13 g14 c2e1)))
; r13-2
 (defvc inf-vc-zbsyms-r13-2 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-le 256 (natminus sc2 1)) (inf-le kc2 64)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 c2e2)))
; h12-1
 (defvc inf-vc-zbsyms-h12-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) (inf-lt (natminus sc2 1) 256)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 g14)))
; m0-1
 (defvc inf-vc-zbsyms-m0-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat (inf-le (add 1 (natminus sc2 1)) 256)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 (inf-letrans (add 1 (natminus sc2 1)) 256 256 (inf-ltsu (natminus sc2 1) 256 g14) (inf-refl 256)))))
; m0-2
 (defvc inf-vc-zbsyms-m0-2 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat (inf-le (add 0 (natminus sc2 1)) 256)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 (inf-letrans (add 0 (natminus sc2 1)) (natminus sc2 1) 256 (inf-refl (natminus sc2 1)) (inf-letrans (natminus sc2 1) 256 256 (inf-ltle (natminus sc2 1) 256 g14) (inf-refl 256))))))
; p3-1
 (defvc inf-vc-zbsyms-p3-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat (inf-lt 0 256)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 (idpath true))))
; h13-1
 (defvc inf-vc-zbsyms-h13-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat (inf-lt (inf-mod 256 yh12) 256)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 (inf-lelts (inf-mod 256 yh12) 255 (inf-letrans (inf-mod 256 yh12) 255 255 (inf-ltsle (inf-mod 256 yh12) 255 (inf-modlt 255 yh12)) (inf-refl 255))))))
; p4-1
 (defvc inf-vc-zbsyms-p4-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat ch13 nat (inf-lt (inf-mod 256 ch13) 256)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 ch13 (inf-lelts (inf-mod 256 ch13) 255 (inf-letrans (inf-mod 256 ch13) 255 255 (inf-ltsle (inf-mod 256 ch13) 255 (inf-modlt 255 ch13)) (inf-refl 255))))))
; p5-1
 (defvc inf-vc-zbsyms-p5-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat ch13 nat (inf-lt nbj0 tn)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 ch13 (inf-lttrans nbj0 mxh2 tn g13 g3))))
; s3-1
 (defvc inf-vc-zbsyms-s3-1 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat ch13 nat (inf-lt (add nbj0 1) (inf-pow w))))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 ch13 (inf-lelt (add nbj0 1) (inf-pow lim) (inf-pow w) (inf-letrans (add nbj0 1) mxh2 (inf-pow lim) (inf-lt1 nbj0 mxh2 g13) (inf-letrans mxh2 tn (inf-pow lim) g3 hts)) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; f2b-6
 (defvc inf-vc-zbsyms-f2b-6 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat ch13 nat (inf-lt (succ left) (inf-pow w))))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 ch13 (inf-wlit (succ left) w gw (inf-letrans (succ left) 50 63 (inf-ltsu left 50 f2) (idpath false))))))
; f2b-7
 (defvc inf-vc-zbsyms-f2b-7 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat ch13 nat (inf-le ic2 (add n 9))))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 ch13 c2e1)))
; f2b-8
 (defvc inf-vc-zbsyms-f2b-8 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat ch13 nat (inf-le kc2 64)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 ch13 c2e2)))
; f2b-9
 (defvc inf-vc-zbsyms-f2b-9 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat ch13 nat (inf-le (add nbj0 1) mxh2)))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 ch13 (inf-letrans (add nbj0 1) mxh2 mxh2 (inf-lt1 nbj0 mxh2 g13) (inf-refl mxh2)))))
; f2b-10
 (defvc inf-vc-zbsyms-f2b-10 (under inf-zbsyms-c3 (pi g12 (inf-lt sc2 (natminus alphah0 1)) g13 (inf-lt nbj0 mxh2) g14 (inf-lt (natminus sc2 1) 256) yh12 nat ch13 nat (inf-lt (natminus 50 (succ left)) (natminus 50 left))))
   (given inf-zbsyms-c3 (lam g12 g13 g14 yh12 ch13 (inf-subfall 50 left f2))))
; f1b-1
 (defvc inf-vc-zbsyms-f1b-1 (under inf-zbsyms-c1-f2 (pi f2 (inf-le 50 left) (inf-lt (succ g) (inf-pow w))))
   (given inf-zbsyms-c1-f2 (lam f2 (inf-lelt (succ g) ms (inf-pow w) (inf-letrans (succ g) nsh1 ms (inf-ltsu g nsh1 f1) g2) hms))))
; f1b-2
 (defvc inf-vc-zbsyms-f1b-2 (under inf-zbsyms-c1-f2 (pi f2 (inf-le 50 left) (inf-le i (add n 9))))
   (given inf-zbsyms-c1-f2 (lam f2 f2a)))
; f1b-3
 (defvc inf-vc-zbsyms-f1b-3 (under inf-zbsyms-c1-f2 (pi f2 (inf-le 50 left) (inf-le k 64)))
   (given inf-zbsyms-c1-f2 (lam f2 f2b)))
; f1b-4
 (defvc inf-vc-zbsyms-f1b-4 (under inf-zbsyms-c1-f2 (pi f2 (inf-le 50 left) (inf-le nb mxh2)))
   (given inf-zbsyms-c1-f2 (lam f2 f2c)))
; f1b-5
 (defvc inf-vc-zbsyms-f1b-5 (under inf-zbsyms-c1-f2 (pi f2 (inf-le 50 left) (inf-lt (natminus nsh1 (succ g)) (natminus nsh1 g))))
   (given inf-zbsyms-c1-f2 (lam f2 (inf-subfall nsh1 g f1))))
; r12-1
 (defvc inf-vc-zbsyms-r12-1 (under inf-zbsyms-f0-f1 (pi f1 (inf-le nsh1 g) (inf-le i (add n 9))))
   (given inf-zbsyms-f0-f1 (lam f1 f1a)))
; r12-2
 (defvc inf-vc-zbsyms-r12-2 (under inf-zbsyms-f0-f1 (pi f1 (inf-le nsh1 g) (inf-le k 64)))
   (given inf-zbsyms-f0-f1 (lam f1 f1b)))
 (defcx inf-zbout (Tt (pi x nat nat)) (Cn (pi x nat nat)) (Cf (pi x nat nat)) (Cr (pi x nat nat)) (w nat) (lim nat) (tn nat) (nb nat) (orig nat) (on0 nat) (oc0 nat) (gw (inf-le 32 w)) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hts (inf-le tn (inf-pow lim))) (hq (inf-le on0 oc0)) (hf (inf-lt oc0 (inf-pow w))) )
; r0-1
 (defvc inf-vc-zbout-r0-1 (under inf-zbout (pi g0 (inf-lt tn nb) (inf-le on0 oc0)))
   (given inf-zbout (lam g0 hq)))
; r0-2
 (defvc inf-vc-zbout-r0-2 (under inf-zbout (pi g0 (inf-lt tn nb) (inf-lt oc0 (inf-pow w))))
   (given inf-zbout (lam g0 hf)))
; r1-1
 (defvc inf-vc-zbout-r1-1 (under inf-zbout (pi g0 (inf-le nb tn) g1 (inf-le nb orig) (inf-le on0 oc0)))
   (given inf-zbout (lam g0 g1 hq)))
; r1-2
 (defvc inf-vc-zbout-r1-2 (under inf-zbout (pi g0 (inf-le nb tn) g1 (inf-le nb orig) (inf-lt oc0 (inf-pow w))))
   (given inf-zbout (lam g0 g1 hf)))
 (defcx inf-zbout-f0 inf-zbout (g0 (inf-le nb tn)) (g1 (inf-lt orig nb)) (sh0 nat) (c nat) (s nat) )
; p0-1
 (defvc inf-vc-zbout-p0-1 (under inf-zbout-f0 (pi f0 (inf-lt c 256) (inf-lt c 256)))
   (given inf-zbout-f0 (lam f0 f0)))
; h1-1
 (defvc inf-vc-zbout-h1-1 (under inf-zbout-f0 (pi f0 (inf-lt c 256) (inf-lt c 256)))
   (given inf-zbout-f0 (lam f0 f0)))
; f0b-1
 (defvc inf-vc-zbout-f0b-1 (under inf-zbout-f0 (pi f0 (inf-lt c 256) sh1 nat (inf-lt (succ c) (inf-pow w))))
   (given inf-zbout-f0 (lam f0 sh1 (inf-lelt (succ c) 1024 (inf-pow w) (inf-letrans (succ c) 256 1024 (inf-ltsu c 256 f0) (idpath false)) (bz-w1k w gw)))))
; f0b-2
 (defvc inf-vc-zbout-f0b-2 (under inf-zbout-f0 (pi f0 (inf-lt c 256) sh1 nat (inf-lt (natminus 256 (succ c)) (natminus 256 c))))
   (given inf-zbout-f0 (lam f0 sh1 (inf-subfall 256 c f0))))
 (defcx inf-zbout-f0-f1 inf-zbout-f0 (f0 (inf-le 256 c)) (u nat) )
; h2-1
 (defvc inf-vc-zbout-h2-1 (under inf-zbout-f0-f1 (pi f1 (inf-lt u nb) (inf-lt u tn)))
   (given inf-zbout-f0-f1 (lam f1 (inf-lttrans u nb tn f1 g0))))
; h3-1
 (defvc inf-vc-zbout-h3-1 (under inf-zbout-f0-f1 (pi f1 (inf-lt u nb) xh2 nat (inf-lt (inf-mod 256 xh2) 256)))
   (given inf-zbout-f0-f1 (lam f1 xh2 (inf-lelts (inf-mod 256 xh2) 255 (inf-letrans (inf-mod 256 xh2) 255 255 (inf-ltsle (inf-mod 256 xh2) 255 (inf-modlt 255 xh2)) (inf-refl 255))))))
; r2-1
 (defvc inf-vc-zbout-r2-1 (under inf-zbout-f0-f1 (pi f1 (inf-lt u nb) xh2 nat jh3 nat g2 (inf-le nb jh3) (inf-le on0 oc0)))
   (given inf-zbout-f0-f1 (lam f1 xh2 jh3 g2 hq)))
; r2-2
 (defvc inf-vc-zbout-r2-2 (under inf-zbout-f0-f1 (pi f1 (inf-lt u nb) xh2 nat jh3 nat g2 (inf-le nb jh3) (inf-lt oc0 (inf-pow w))))
   (given inf-zbout-f0-f1 (lam f1 xh2 jh3 g2 hf)))
; p1-1
 (defvc inf-vc-zbout-p1-1 (under inf-zbout-f0-f1 (pi f1 (inf-lt u nb) xh2 nat jh3 nat g2 (inf-lt jh3 nb) (inf-lt jh3 tn)))
   (given inf-zbout-f0-f1 (lam f1 xh2 jh3 g2 (inf-lttrans jh3 nb tn g2 g0))))
; p1-2
 (defvc inf-vc-zbout-p1-2 (under inf-zbout-f0-f1 (pi f1 (inf-lt u nb) xh2 nat jh3 nat g2 (inf-lt jh3 nb) (inf-lt 8 64)))
   (given inf-zbout-f0-f1 (lam f1 xh2 jh3 g2 (idpath true))))
; p2-1
 (defvc inf-vc-zbout-p2-1 (under inf-zbout-f0-f1 (pi f1 (inf-lt u nb) xh2 nat jh3 nat g2 (inf-lt jh3 nb) (inf-lt (inf-mod 256 xh2) 256)))
   (given inf-zbout-f0-f1 (lam f1 xh2 jh3 g2 (inf-lelts (inf-mod 256 xh2) 255 (inf-letrans (inf-mod 256 xh2) 255 255 (inf-ltsle (inf-mod 256 xh2) 255 (inf-modlt 255 xh2)) (inf-refl 255))))))
; f1b-1
 (defvc inf-vc-zbout-f1b-1 (under inf-zbout-f0-f1 (pi f1 (inf-lt u nb) xh2 nat jh3 nat g2 (inf-lt jh3 nb) (inf-lt (succ u) (inf-pow w))))
   (given inf-zbout-f0-f1 (lam f1 xh2 jh3 g2 (inf-lelt (succ u) (inf-pow lim) (inf-pow w) (inf-letrans (succ u) nb (inf-pow lim) (inf-ltsu u nb f1) (inf-letrans nb tn (inf-pow lim) g0 hts)) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; f1b-2
 (defvc inf-vc-zbout-f1b-2 (under inf-zbout-f0-f1 (pi f1 (inf-lt u nb) xh2 nat jh3 nat g2 (inf-lt jh3 nb) (inf-lt (natminus nb (succ u)) (natminus nb u))))
   (given inf-zbout-f0-f1 (lam f1 xh2 jh3 g2 (inf-subfall nb u f1))))
; h4-1
 (defvc inf-vc-zbout-h4-1 (under inf-zbout-f0-f1 (pi f1 (inf-le nb u) (inf-lt orig tn)))
   (given inf-zbout-f0-f1 (lam f1 (inf-lttrans orig nb tn g1 g0))))
; h4-2
 (defvc inf-vc-zbout-h4-2 (under inf-zbout-f0-f1 (pi f1 (inf-le nb u) (inf-lt 8 64)))
   (given inf-zbout-f0-f1 (lam f1 (idpath true))))
; f2e-1
 (defvc inf-vc-zbout-f2e-1 (under inf-zbout-f0-f1 (pi f1 (inf-le nb u) ph4 nat crch5 nat lasth6 nat sameh7 nat (inf-le on0 oc0)))
   (given inf-zbout-f0-f1 (lam f1 ph4 crch5 lasth6 sameh7 hq)))
; f2e-2
 (defvc inf-vc-zbout-f2e-2 (under inf-zbout-f0-f1 (pi f1 (inf-le nb u) ph4 nat crch5 nat lasth6 nat sameh7 nat (inf-lt oc0 (inf-pow w))))
   (given inf-zbout-f0-f1 (lam f1 ph4 crch5 lasth6 sameh7 hf)))
 (defcx inf-zbout-f0-f1-f2 inf-zbout-f0-f1 (f1 (inf-le nb u)) (ph4 nat) (crch5 nat) (lasth6 nat) (sameh7 nat) (u nat) (same nat) (last nat) (crc nat) (p nat) (c nat) (on nat) (oc nat) (f2a (inf-le on oc)) (f2b (inf-lt oc (inf-pow w))) )
; r3-1
 (defvc inf-vc-zbout-r3-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-le nb p) (inf-le on oc)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 f2a)))
; r3-2
 (defvc inf-vc-zbout-r3-2 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-le nb p) (inf-lt oc (inf-pow w))))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 f2b)))
; h8-1
 (defvc inf-vc-zbout-h8-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) (inf-lt p tn)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 (inf-lttrans p nb tn g3 g0))))
; s0-1
 (defvc inf-vc-zbout-s0-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat (inf-lt (inf-mod 256 xh8) (inf-pow w))))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 (inf-lelt (inf-mod 256 xh8) 1024 (inf-pow w) (inf-letrans (inf-mod 256 xh8) 255 1024 (inf-ltsle (inf-mod 256 xh8) 255 (inf-modlt 255 xh8)) (idpath false)) (bz-w1k w gw)))))
; h9-1
 (defvc inf-vc-zbout-h9-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat (inf-lt 8 64)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 (idpath true))))
; f3e-1
 (defvc inf-vc-zbout-f3e-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit (inf-le on oc)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 f2a)))
; f3e-2
 (defvc inf-vc-zbout-f3e-2 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit (inf-lt oc (inf-pow w))))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 f2b)))
 (defcx inf-zbout-f0-f1-f2-f3 inf-zbout-f0-f1-f2 (f2 (inf-lt u nb)) (g3 (inf-lt p nb)) (xh8 nat) (ph9 nat) (g4 unit) (j nat) (crc nat) (on nat) (oc nat) (f3a (inf-le on oc)) (f3b (inf-lt oc (inf-pow w))) )
; h10-1
 (defvc inf-vc-zbout-h10-1 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-lt j (inf-mod 256 xh8)) (inf-lt 24 64)))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 (idpath true))))
; h11-1
 (defvc inf-vc-zbout-h11-1 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-lt j (inf-mod 256 xh8)) yh10 nat (inf-lt 8 64)))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 yh10 (idpath true))))
; h11-2
 (defvc inf-vc-zbout-h11-2 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-lt j (inf-mod 256 xh8)) yh10 nat (inf-lt (inf-mod 256 yh10) 256)))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 yh10 (inf-lelts (inf-mod 256 yh10) 255 (inf-letrans (inf-mod 256 yh10) 255 255 (inf-ltsle (inf-mod 256 yh10) 255 (inf-modlt 255 yh10)) (inf-refl 255))))))
; c0-1
 (defvc inf-vc-zbout-c0-1 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-lt j (inf-mod 256 xh8)) yh10 nat crch11 nat (inf-le 32 w)))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 yh10 crch11 gw)))
; c0-2
 (defvc inf-vc-zbout-c0-2 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-lt j (inf-mod 256 xh8)) yh10 nat crch11 nat (inf-le 19 lim)))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 yh10 crch11 hl)))
; c0-3
 (defvc inf-vc-zbout-c0-3 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-lt j (inf-mod 256 xh8)) yh10 nat crch11 nat (inf-lt lim 31)))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 yh10 crch11 hm)))
; c0-4
 (defvc inf-vc-zbout-c0-4 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-lt j (inf-mod 256 xh8)) yh10 nat crch11 nat (inf-le on oc)))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 yh10 crch11 f3a)))
; c0-5
 (defvc inf-vc-zbout-c0-5 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-lt j (inf-mod 256 xh8)) yh10 nat crch11 nat (inf-lt oc (inf-pow w))))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 yh10 crch11 f3b)))
 (defcx inf-zbout-c2 inf-zbout-f0-f1-f2-f3 (f3 (inf-lt j (inf-mod 256 xh8))) (yh10 nat) (crch11 nat) (onc0 nat) (occ0 nat) (c0e1 (inf-le onc0 occ0)) (c0e2 (inf-lt occ0 (inf-pow w))) )
; f3b-1
 (defvc inf-vc-zbout-f3b-1 (under inf-zbout-c2 (inf-lt (succ j) (inf-pow w)))
   (given inf-zbout-c2 (inf-lelt (succ j) 1024 (inf-pow w) (inf-letrans (succ j) (inf-mod 256 xh8) 1024 (inf-ltsu j (inf-mod 256 xh8) f3) (inf-letrans (inf-mod 256 xh8) 255 1024 (inf-ltsle (inf-mod 256 xh8) 255 (inf-modlt 255 xh8)) (idpath false))) (bz-w1k w gw))))
; f3b-2
 (defvc inf-vc-zbout-f3b-2 (under inf-zbout-c2 (inf-le onc0 occ0))
   (given inf-zbout-c2 c0e1))
; f3b-3
 (defvc inf-vc-zbout-f3b-3 (under inf-zbout-c2 (inf-lt occ0 (inf-pow w)))
   (given inf-zbout-c2 c0e2))
; f3b-4
 (defvc inf-vc-zbout-f3b-4 (under inf-zbout-c2 (inf-lt (natminus (inf-mod 256 xh8) (succ j)) (natminus (inf-mod 256 xh8) j)))
   (given inf-zbout-c2 (inf-subfall (inf-mod 256 xh8) j f3)))
; f2b-1
 (defvc inf-vc-zbout-f2b-1 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-le (inf-mod 256 xh8) j) sameh12 nat lasth13 nat (inf-lt (succ u) (inf-pow w))))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 sameh12 lasth13 (inf-lelt (succ u) (inf-pow lim) (inf-pow w) (inf-letrans (succ u) nb (inf-pow lim) (inf-ltsu u nb f2) (inf-letrans nb tn (inf-pow lim) g0 hts)) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; f2b-2
 (defvc inf-vc-zbout-f2b-2 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-le (inf-mod 256 xh8) j) sameh12 nat lasth13 nat (inf-le on oc)))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 sameh12 lasth13 f3a)))
; f2b-3
 (defvc inf-vc-zbout-f2b-3 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-le (inf-mod 256 xh8) j) sameh12 nat lasth13 nat (inf-lt oc (inf-pow w))))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 sameh12 lasth13 f3b)))
; f2b-4
 (defvc inf-vc-zbout-f2b-4 (under inf-zbout-f0-f1-f2-f3 (pi f3 (inf-le (inf-mod 256 xh8) j) sameh12 nat lasth13 nat (inf-lt (natminus nb (succ u)) (natminus nb u))))
   (given inf-zbout-f0-f1-f2-f3 (lam f3 sameh12 lasth13 (inf-subfall nb u f2))))
; h14-1
 (defvc inf-vc-zbout-h14-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit (inf-lt 24 64)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 (idpath true))))
; h15-1
 (defvc inf-vc-zbout-h15-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit yh14 nat (inf-lt 8 64)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 yh14 (idpath true))))
; h15-2
 (defvc inf-vc-zbout-h15-2 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit yh14 nat (inf-lt (inf-mod 256 yh14) 256)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 yh14 (inf-lelts (inf-mod 256 yh14) 255 (inf-letrans (inf-mod 256 yh14) 255 255 (inf-ltsle (inf-mod 256 yh14) 255 (inf-modlt 255 yh14)) (inf-refl 255))))))
; c1-1
 (defvc inf-vc-zbout-c1-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit yh14 nat crch15 nat (inf-le 32 w)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 yh14 crch15 gw)))
; c1-2
 (defvc inf-vc-zbout-c1-2 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit yh14 nat crch15 nat (inf-le 19 lim)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 yh14 crch15 hl)))
; c1-3
 (defvc inf-vc-zbout-c1-3 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit yh14 nat crch15 nat (inf-lt lim 31)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 yh14 crch15 hm)))
; c1-4
 (defvc inf-vc-zbout-c1-4 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit yh14 nat crch15 nat (inf-le on oc)))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 yh14 crch15 f2a)))
; c1-5
 (defvc inf-vc-zbout-c1-5 (under inf-zbout-f0-f1-f2 (pi f2 (inf-lt u nb) g3 (inf-lt p nb) xh8 nat ph9 nat g4 unit yh14 nat crch15 nat (inf-lt oc (inf-pow w))))
   (given inf-zbout-f0-f1-f2 (lam f2 g3 xh8 ph9 g4 yh14 crch15 f2b)))
 (defcx inf-zbout-c1 inf-zbout-f0-f1-f2 (f2 (inf-lt u nb)) (g3 (inf-lt p nb)) (xh8 nat) (ph9 nat) (g4 unit) (yh14 nat) (crch15 nat) (onc1 nat) (occ1 nat) (c1e1 (inf-le onc1 occ1)) (c1e2 (inf-lt occ1 (inf-pow w))) )
; f2b-5
 (defvc inf-vc-zbout-f2b-5 (under inf-zbout-c1 (pi g5 unit sameh16 nat lasth18 nat (inf-lt (succ u) (inf-pow w))))
   (given inf-zbout-c1 (lam g5 sameh16 lasth18 (inf-lelt (succ u) (inf-pow lim) (inf-pow w) (inf-letrans (succ u) nb (inf-pow lim) (inf-ltsu u nb f2) (inf-letrans nb tn (inf-pow lim) g0 hts)) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; f2b-6
 (defvc inf-vc-zbout-f2b-6 (under inf-zbout-c1 (pi g5 unit sameh16 nat lasth18 nat (inf-le onc1 occ1)))
   (given inf-zbout-c1 (lam g5 sameh16 lasth18 c1e1)))
; f2b-7
 (defvc inf-vc-zbout-f2b-7 (under inf-zbout-c1 (pi g5 unit sameh16 nat lasth18 nat (inf-lt occ1 (inf-pow w))))
   (given inf-zbout-c1 (lam g5 sameh16 lasth18 c1e2)))
; f2b-8
 (defvc inf-vc-zbout-f2b-8 (under inf-zbout-c1 (pi g5 unit sameh16 nat lasth18 nat (inf-lt (natminus nb (succ u)) (natminus nb u))))
   (given inf-zbout-c1 (lam g5 sameh16 lasth18 (inf-subfall nb u f2))))
; f2b-9
 (defvc inf-vc-zbout-f2b-9 (under inf-zbout-c1 (pi g5 unit sameh17 nat lasth18 nat (inf-lt (succ u) (inf-pow w))))
   (given inf-zbout-c1 (lam g5 sameh17 lasth18 (inf-lelt (succ u) (inf-pow lim) (inf-pow w) (inf-letrans (succ u) nb (inf-pow lim) (inf-ltsu u nb f2) (inf-letrans nb tn (inf-pow lim) g0 hts)) (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false)))))))
; f2b-10
 (defvc inf-vc-zbout-f2b-10 (under inf-zbout-c1 (pi g5 unit sameh17 nat lasth18 nat (inf-le onc1 occ1)))
   (given inf-zbout-c1 (lam g5 sameh17 lasth18 c1e1)))
; f2b-11
 (defvc inf-vc-zbout-f2b-11 (under inf-zbout-c1 (pi g5 unit sameh17 nat lasth18 nat (inf-lt occ1 (inf-pow w))))
   (given inf-zbout-c1 (lam g5 sameh17 lasth18 c1e2)))
; f2b-12
 (defvc inf-vc-zbout-f2b-12 (under inf-zbout-c1 (pi g5 unit sameh17 nat lasth18 nat (inf-lt (natminus nb (succ u)) (natminus nb u))))
   (given inf-zbout-c1 (lam g5 sameh17 lasth18 (inf-subfall nb u f2))))
; r4-1
 (defvc inf-vc-zbout-r4-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-le nb u) g6 unit (inf-le on oc)))
   (given inf-zbout-f0-f1-f2 (lam f2 g6 f2a)))
; r4-2
 (defvc inf-vc-zbout-r4-2 (under inf-zbout-f0-f1-f2 (pi f2 (inf-le nb u) g6 unit (inf-lt oc (inf-pow w))))
   (given inf-zbout-f0-f1-f2 (lam f2 g6 f2b)))
; r5-1
 (defvc inf-vc-zbout-r5-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-le nb u) g6 unit g7 unit (inf-le on oc)))
   (given inf-zbout-f0-f1-f2 (lam f2 g6 g7 f2a)))
; r5-2
 (defvc inf-vc-zbout-r5-2 (under inf-zbout-f0-f1-f2 (pi f2 (inf-le nb u) g6 unit g7 unit (inf-lt oc (inf-pow w))))
   (given inf-zbout-f0-f1-f2 (lam f2 g6 g7 f2b)))
; r6-1
 (defvc inf-vc-zbout-r6-1 (under inf-zbout-f0-f1-f2 (pi f2 (inf-le nb u) g6 unit g7 unit (inf-le on oc)))
   (given inf-zbout-f0-f1-f2 (lam f2 g6 g7 f2a)))
; r6-2
 (defvc inf-vc-zbout-r6-2 (under inf-zbout-f0-f1-f2 (pi f2 (inf-le nb u) g6 unit g7 unit (inf-lt oc (inf-pow w))))
   (given inf-zbout-f0-f1-f2 (lam f2 g6 g7 f2b)))
 (defcx inf-zbblock (In (pi x nat nat)) (Ps (pi x nat nat)) (Ln (pi x nat nat)) (Sq (pi x nat nat)) (Sl (pi x nat nat)) (Yy (pi x nat nat)) (Cn (pi x nat nat)) (Cf (pi x nat nat)) (Tt (pi x nat nat)) (Cr (pi x nat nat)) (Zt (pi x nat nat)) (n nat) (w nat) (i0 nat) (k0 nat) (on0 nat) (oc0 nat) (ms nat) (tn nat) (lim nat) (tl nat) (gw (inf-le 32 w)) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hts (inf-le tn (inf-pow lim))) (hms (inf-lt ms (inf-pow w))) (h20 (inf-le 20 tl)) (hq (inf-lt tl 30)) (hf (inf-lt oc0 (inf-pow w))) )
; i1-1
 (defvc inf-vc-zbblock-i1-1 (under inf-zbblock (pi g0 (inf-lt (add n 9) (inf-pow w)) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbblock (lam g0 g0)))
; i2-1
 (defvc inf-vc-zbblock-i2-1 (under inf-zbblock (pi g0 (inf-lt (add n 9) (inf-pow w)) g1 (inf-lt (inf-by16 (add n 9)) (inf-pow w)) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbblock (lam g0 g1 g0)))
; c0-1
 (defvc inf-vc-zbblock-c0-1 (under inf-zbblock (pi g0 (inf-lt (add n 9) (inf-pow w)) g1 (inf-lt (inf-by16 (add n 9)) (inf-pow w)) g2 (inf-le i0 (add n 9)) g3 (inf-le k0 64) g4 (inf-le on0 oc0) (inf-le 32 w)))
   (given inf-zbblock (lam g0 g1 g2 g3 g4 gw)))
; c0-2
 (defvc inf-vc-zbblock-c0-2 (under inf-zbblock (pi g0 (inf-lt (add n 9) (inf-pow w)) g1 (inf-lt (inf-by16 (add n 9)) (inf-pow w)) g2 (inf-le i0 (add n 9)) g3 (inf-le k0 64) g4 (inf-le on0 oc0) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbblock (lam g0 g1 g2 g3 g4 g0)))
; c0-3
 (defvc inf-vc-zbblock-c0-3 (under inf-zbblock (pi g0 (inf-lt (add n 9) (inf-pow w)) g1 (inf-lt (inf-by16 (add n 9)) (inf-pow w)) g2 (inf-le i0 (add n 9)) g3 (inf-le k0 64) g4 (inf-le on0 oc0) (inf-le i0 (add n 9))))
   (given inf-zbblock (lam g0 g1 g2 g3 g4 g2)))
; c0-4
 (defvc inf-vc-zbblock-c0-4 (under inf-zbblock (pi g0 (inf-lt (add n 9) (inf-pow w)) g1 (inf-lt (inf-by16 (add n 9)) (inf-pow w)) g2 (inf-le i0 (add n 9)) g3 (inf-le k0 64) g4 (inf-le on0 oc0) (inf-le k0 64)))
   (given inf-zbblock (lam g0 g1 g2 g3 g4 g3)))
; c0-5
 (defvc inf-vc-zbblock-c0-5 (under inf-zbblock (pi g0 (inf-lt (add n 9) (inf-pow w)) g1 (inf-lt (inf-by16 (add n 9)) (inf-pow w)) g2 (inf-le i0 (add n 9)) g3 (inf-le k0 64) g4 (inf-le on0 oc0) (inf-lt 0 32)))
   (given inf-zbblock (lam g0 g1 g2 g3 g4 (idpath true))))
; c0-6
 (defvc inf-vc-zbblock-c0-6 (under inf-zbblock (pi g0 (inf-lt (add n 9) (inf-pow w)) g1 (inf-lt (inf-by16 (add n 9)) (inf-pow w)) g2 (inf-le i0 (add n 9)) g3 (inf-le k0 64) g4 (inf-le on0 oc0) (inf-le 32 32)))
   (given inf-zbblock (lam g0 g1 g2 g3 g4 (idpath false))))
 (defcx inf-zbblock-c1 inf-zbblock (g0 (inf-lt (add n 9) (inf-pow w))) (g1 (inf-lt (inf-by16 (add n 9)) (inf-pow w))) (g2 (inf-le i0 (add n 9))) (g3 (inf-le k0 64)) (g4 (inf-le on0 oc0)) (ic0 nat) (kc0 nat) (wantc0 nat) (c0e1 (inf-le ic0 (add n 9))) (c0e2 (inf-le kc0 64)) (c0e3 (inf-lt wantc0 (inf-pow w))) )
; c1-1
 (defvc inf-vc-zbblock-c1-1 (under inf-zbblock-c1 (inf-le 32 w))
   (given inf-zbblock-c1 gw))
; c1-2
 (defvc inf-vc-zbblock-c1-2 (under inf-zbblock-c1 (inf-lt (add n 9) (inf-pow w)))
   (given inf-zbblock-c1 g0))
; c1-3
 (defvc inf-vc-zbblock-c1-3 (under inf-zbblock-c1 (inf-le ic0 (add n 9)))
   (given inf-zbblock-c1 c0e1))
; c1-4
 (defvc inf-vc-zbblock-c1-4 (under inf-zbblock-c1 (inf-le kc0 64))
   (given inf-zbblock-c1 c0e2))
; c1-5
 (defvc inf-vc-zbblock-c1-5 (under inf-zbblock-c1 (inf-lt 0 1))
   (given inf-zbblock-c1 (idpath true)))
; c1-6
 (defvc inf-vc-zbblock-c1-6 (under inf-zbblock-c1 (inf-le 1 32))
   (given inf-zbblock-c1 (idpath false)))
 (defcx inf-zbblock-c2 inf-zbblock-c1 (ic1 nat) (kc1 nat) (xc1 nat) (c1e1 (inf-le ic1 (add n 9))) (c1e2 (inf-le kc1 64)) (c1e3 (inf-lt xc1 (inf-pow w))) )
; c2-1
 (defvc inf-vc-zbblock-c2-1 (under inf-zbblock-c2 (pi g5 (paths nat xc1 0) (inf-le 32 w)))
   (given inf-zbblock-c2 (lam g5 gw)))
; c2-2
 (defvc inf-vc-zbblock-c2-2 (under inf-zbblock-c2 (pi g5 (paths nat xc1 0) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbblock-c2 (lam g5 g0)))
; c2-3
 (defvc inf-vc-zbblock-c2-3 (under inf-zbblock-c2 (pi g5 (paths nat xc1 0) (inf-le ic1 (add n 9))))
   (given inf-zbblock-c2 (lam g5 c1e1)))
; c2-4
 (defvc inf-vc-zbblock-c2-4 (under inf-zbblock-c2 (pi g5 (paths nat xc1 0) (inf-le kc1 64)))
   (given inf-zbblock-c2 (lam g5 c1e2)))
; c2-5
 (defvc inf-vc-zbblock-c2-5 (under inf-zbblock-c2 (pi g5 (paths nat xc1 0) (inf-lt 0 24)))
   (given inf-zbblock-c2 (lam g5 (idpath true))))
; c2-6
 (defvc inf-vc-zbblock-c2-6 (under inf-zbblock-c2 (pi g5 (paths nat xc1 0) (inf-le 24 32)))
   (given inf-zbblock-c2 (lam g5 (idpath false))))
 (defcx inf-zbblock-c3 inf-zbblock-c2 (g5 (paths nat xc1 0)) (ic2 nat) (kc2 nat) (origc2 nat) (c2e1 (inf-le ic2 (add n 9))) (c2e2 (inf-le kc2 64)) (c2e3 (inf-lt origc2 (inf-pow w))) )
; c3-1
 (defvc inf-vc-zbblock-c3-1 (under inf-zbblock-c3 (inf-le 32 w))
   (given inf-zbblock-c3 gw))
; c3-2
 (defvc inf-vc-zbblock-c3-2 (under inf-zbblock-c3 (inf-lt (add n 9) (inf-pow w)))
   (given inf-zbblock-c3 g0))
; c3-3
 (defvc inf-vc-zbblock-c3-3 (under inf-zbblock-c3 (inf-le ic2 (add n 9)))
   (given inf-zbblock-c3 c2e1))
; c3-4
 (defvc inf-vc-zbblock-c3-4 (under inf-zbblock-c3 (inf-le kc2 64))
   (given inf-zbblock-c3 c2e2))
; c3-5
 (defvc inf-vc-zbblock-c3-5 (under inf-zbblock-c3 (inf-lt (inf-by16 (add n 9)) (inf-pow w)))
   (given inf-zbblock-c3 g1))
; c3-6
 (defvc inf-vc-zbblock-c3-6 (under inf-zbblock-c3 (inf-lt ms (inf-pow w)))
   (given inf-zbblock-c3 hms))
; c3-7
 (defvc inf-vc-zbblock-c3-7 (under inf-zbblock-c3 (inf-le 20 tl))
   (given inf-zbblock-c3 h20))
; c3-8
 (defvc inf-vc-zbblock-c3-8 (under inf-zbblock-c3 (inf-lt tl 30))
   (given inf-zbblock-c3 hq))
 (defcx inf-zbblock-c4 inf-zbblock-c3 (ic3 nat) (kc3 nat) (xc3 nat) (c3e1 (inf-le ic3 (add n 9))) (c3e2 (inf-le kc3 64)) )
; c4-1
 (defvc inf-vc-zbblock-c4-1 (under inf-zbblock-c4 (pi g6 (paths nat xc3 0) (inf-le 32 w)))
   (given inf-zbblock-c4 (lam g6 gw)))
; c4-2
 (defvc inf-vc-zbblock-c4-2 (under inf-zbblock-c4 (pi g6 (paths nat xc3 0) (inf-lt (add n 9) (inf-pow w))))
   (given inf-zbblock-c4 (lam g6 g0)))
; c4-3
 (defvc inf-vc-zbblock-c4-3 (under inf-zbblock-c4 (pi g6 (paths nat xc3 0) (inf-le ic3 (add n 9))))
   (given inf-zbblock-c4 (lam g6 c3e1)))
; c4-4
 (defvc inf-vc-zbblock-c4-4 (under inf-zbblock-c4 (pi g6 (paths nat xc3 0) (inf-le kc3 64)))
   (given inf-zbblock-c4 (lam g6 c3e2)))
; c4-5
 (defvc inf-vc-zbblock-c4-5 (under inf-zbblock-c4 (pi g6 (paths nat xc3 0) (inf-le 19 lim)))
   (given inf-zbblock-c4 (lam g6 hl)))
; c4-6
 (defvc inf-vc-zbblock-c4-6 (under inf-zbblock-c4 (pi g6 (paths nat xc3 0) (inf-lt lim 31)))
   (given inf-zbblock-c4 (lam g6 hm)))
; c4-7
 (defvc inf-vc-zbblock-c4-7 (under inf-zbblock-c4 (pi g6 (paths nat xc3 0) (inf-le tn (inf-pow lim))))
   (given inf-zbblock-c4 (lam g6 hts)))
; c4-8
 (defvc inf-vc-zbblock-c4-8 (under inf-zbblock-c4 (pi g6 (paths nat xc3 0) (inf-lt ms (inf-pow w))))
   (given inf-zbblock-c4 (lam g6 hms)))
 (defcx inf-zbblock-c5 inf-zbblock-c4 (g6 (paths nat xc3 0)) (ic4 nat) (kc4 nat) (xc4 nat) (c4e1 (inf-le ic4 (add n 9))) (c4e2 (inf-le kc4 64)) )
 (defcx inf-zbblock-c6 inf-zbblock-c5 (g7 (paths nat xc4 0)) (xc5 nat) )
; c6-1
 (defvc inf-vc-zbblock-c6-1 (under inf-zbblock-c6 (pi g8 (paths nat xc5 0) nbh0 nat (inf-le 32 w)))
   (given inf-zbblock-c6 (lam g8 nbh0 gw)))
; c6-2
 (defvc inf-vc-zbblock-c6-2 (under inf-zbblock-c6 (pi g8 (paths nat xc5 0) nbh0 nat (inf-le 19 lim)))
   (given inf-zbblock-c6 (lam g8 nbh0 hl)))
; c6-3
 (defvc inf-vc-zbblock-c6-3 (under inf-zbblock-c6 (pi g8 (paths nat xc5 0) nbh0 nat (inf-lt lim 31)))
   (given inf-zbblock-c6 (lam g8 nbh0 hm)))
; c6-4
 (defvc inf-vc-zbblock-c6-4 (under inf-zbblock-c6 (pi g8 (paths nat xc5 0) nbh0 nat (inf-le tn (inf-pow lim))))
   (given inf-zbblock-c6 (lam g8 nbh0 hts)))
; c6-5
 (defvc inf-vc-zbblock-c6-5 (under inf-zbblock-c6 (pi g8 (paths nat xc5 0) nbh0 nat (inf-le on0 oc0)))
   (given inf-zbblock-c6 (lam g8 nbh0 g4)))
; c6-6
 (defvc inf-vc-zbblock-c6-6 (under inf-zbblock-c6 (pi g8 (paths nat xc5 0) nbh0 nat (inf-lt oc0 (inf-pow w))))
   (given inf-zbblock-c6 (lam g8 nbh0 hf)))
 (defcx inf-zbblock-c7 inf-zbblock-c6 (g8 (paths nat xc5 0)) (nbh0 nat) (onc6 nat) (occ6 nat) (xc6 nat) (c6e1 (inf-le onc6 occ6)) (c6e2 (inf-lt occ6 (inf-pow w))) )
 )
