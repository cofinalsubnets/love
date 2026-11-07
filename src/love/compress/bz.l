; src/love/compress/bz.l -- bzip2's decoder and its output sink as data: vc.l lays the C and the
; obligations for test/uuzbvc.l. the table's contents, the crc and the block's bytes are not modelled:
; each read that could leave an array is guarded, so what is proved holds whatever the tables hold.
(:
   _ (borrow "src/apps/moon/clay.l")
   _ (borrow "src/love/compress/vc.l")

   bz-tn 900000                ; tt's words, the largest block
   bz-ms 18002                 ; the selectors a largest block can use, and two
   bz-lim 30                   ; the output is one heap string: no further
   bz-tl 20                    ; a width past every code length, for tables' proofs

   rd-fields '(p i n acc k)
   rd-params '(("r" (ptr (struct "bz_r"))))
   rd-state '((i i0) (k k0))
   rd-arrays '((In (r "p") n))
   rd-req '((In (pi x nat nat)) (n nat) (w nat) (i0 nat) (k0 nat)
            (gw (inf-le 32 w))
            (gn (inf-lt (add n 9) (inf-pow w)))
            (gi (inf-le i0 (add n 9)))
            (gk (inf-le k0 64)))
   rd-ens '((e1 (inf-le i (add n 9))) (e2 (inf-le k 64)))

   ; --- the sink: grows by doubling to 2^lim, or holds to what the caller gave it -----------------
   bwbyte
    {'name "bw_byte" 'short "zbw"
     'attrs '("static" "inline")
     'ret 'int
     'params '(("r" (ptr (struct "bz_w"))) ("b" (named "uint8_t")))
     'fields '(p on oc bad big fix)
     'state '((on on0) (oc oc0))
     'arrays '((Op (r "p") oc) (Qm (v "q") o))
     'requires
      '((w nat) (lim nat) (on0 nat) (oc0 nat)
        (gw (inf-le 32 w)) (hl (inf-le 19 lim)) (hm (inf-lt lim 31))
        (hq (inf-le on0 oc0)) (hf (inf-lt oc0 (inf-pow w))))
     'decls '((uint (lim (raw (var "BZ_LIM")))) ((named "uintptr_t") (c)) ((ptr (named "uint8_t")) (q)))
     'ensures '((e1 (inf-le on oc)) (e2 (inf-lt oc (inf-pow w))))
     'body
      '((j1 join g1 (le oc on)
         ((i1 if g2 (ne fix 0) ((s1 store "bad" 1) (r1 ret 0)))
          (i2 if g3 (le (pow lim) on) ((s2 store "bad" 1) (s3 store "big" 1) (r2 ret 0)))
          (i3 if g4 (ne bad 0) ((r3 ret 0)))
          (j2 join g5 (z oc) ((s4 set c 4096)) ((s5 set c (shl oc 1)))
           ((a1 (inf-lt on c)) (a2 (inf-lt c (inf-pow w)))))
          (n1 new q o c g6)
          (i4 if g7 (z q) ((s6 store "bad" 1) (r4 ret 0)))
          (j3 join g8 (nz on) ((m1 mcopy Qm 0 Op 0 on)) () ())
          (j4 join g9 (ne p 0) ((f1 free p)) () ())
          (s7 store "p" q)
          (s8 set oc c))
         ()
         ((a3 (inf-lt on oc)) (a4 (inf-lt oc (inf-pow w)))))
        (p1 poke Op on b)
        (s9 set on (+ on 1))
        (r5 ret 0))
     'macros '()
     'proofs
      {"s4-1" '(bz-w4k w gw)
       "j2j-1" '(bz-none on0 oc0 hq g5)
       "j2j-2" '(bz-w4k w gw)
       "j2j-3" '(bz-dbl on0 oc0 hq g5)
       "m1-1" '(bz-cle on0 on1 cj2 (g6 g7) a1)}}

   ; --- the reader: msb first, zeros past the end, i held under n + 9 -----------------------------
   fill
    {'name "br_fill" 'short "zbfill"
     'attrs '("static" "inline")
     'ret 'void
     'params rd-params 'fields rd-fields 'state rd-state 'arrays rd-arrays 'requires rd-req
     'decls '((uint (x)))
     'ensures (rd-ens + '((e3 (inf-lt 56 k))))
     'body
      '((w1 while (le k 56) (natminus 64 k) ((a1 (inf-le i (add n 9))) (a2 (inf-le k 64)))
         ((j1 join g1 (lt i n) ((h1 havoc x (at In i))) ((h2 havoc x 0)) ())
          (s1 store "acc" (bor64 (shl64 acc 8) x))
          (j2 join g2 (lt i (+ n 9)) ((s2 set i (+ i 1))) () ((a3 (inf-le i (add n 9)))))
          (s3 set k (+ k 8)))))
     'macros '()
     'proofs
      {"w1b-3" '(inf-subby k 64 8 (inf-lelt k 56 64 w1 (idpath true)) (idpath true))}}

   ; k bits off the reader, 1 to 32
   get
    {'name "br_get" 'short "zbget"
     'attrs '("static" "inline")
     'ret 'uint
     'params (rd-params + '(("K" uint))) 'fields rd-fields 'state rd-state 'arrays rd-arrays
     'requires (rd-req + '((K nat) (g1 (inf-lt 0 K)) (g2 (inf-le K 32))))
     'decls '((uint (v)))
     'ensures (rd-ens + '((e3 (inf-lt res (inf-pow w)))))
     'calls [fill]
     'body
      '((j1 join t1 (lt k K) ((c1 call "br_fill" ((raw (var "r"))) (In n w) ())) ()
         ((a1 (inf-le K k)) (a2 (inf-le k 64)) (a3 (inf-le i (add n 9)))))
        (d1 havw v (u32 (and64 (shr64 acc (- k K)) (m64 K))) h1)
        (d2 dec k (- k K))
        (r1 ret v))
     'macros '()
     'proofs {}}

   ; has it read past the end? bits consumed, 8i - k, past 8n, with no multiply to overflow
   past
    {'name "br_past" 'short "zbpast"
     'attrs '("static" "inline")
     'ret 'int
     'params '(("r" (ptr (const (struct "bz_r")))))
     'fields '(i n k)
     'arrays ()
     'requires '((n nat) (i nat) (k nat))
     'decls ()
     'ensures ()
     'body
      '((i1 if g1 (lt n i) ((i2 if g2 (lt (div8 k) (- i n)) ((r1 ret 1)))))
        (r2 ret 0))
     'macros '()
     'proofs {}}

   ; --- the code table, for the n lengths it is given ----------------------------------------------
   tab-arrays '((Ft (s "fast") 1024) (Lm (s "limit") 22) (Bs (s "base") 22) (Pm (s "perm") 258))
   tbuild
    {'name "bz_tbuild" 'short "zbtab"
     'attrs '("static")
     'ret 'int
     'params '(("s" (ptr (struct "bz_tab"))) ("len" (ptr (const (named "uint8_t")))) ("n" uint))
     'sfields '(maxl)
     'arrays (tab-arrays + '((Ln (v "len") 258)))
     'requires
      '((Ln (pi x nat nat)) (n nat) (w nat) (lim nat)
        (gw (inf-le 32 w)) (hl (inf-le 19 lim)) (hm (inf-lt lim 31))
        (h20 (inf-le 20 lim)) (hq (inf-lt lim 30)) (hsy (inf-le n 258)))
     'decls '((uint (code) (t) (l) (u) (lo) (hi) (j)))
     'ensures ()
     'body
      '((c0 clear Ft (szof (dot (deref (var "s")) "fast")))
        (s0 set maxl 0)
        (f0 for u 0 n ()
         ((i0 if g0 (lt maxl (at Ln u)) ((h0 havoc maxl (at Ln u))))))
        (s1 set code 0)
        (s2 set t 0)
        (f1 for l 1 21 ((b1 (inf-le code (inf-pow l))) (b2 (inf-le t 258)))
         ((p0 poke Bs l (wsub code t))
          (f2 for u 0 n ((b3 (inf-le code (add u (inf-pow l)))) (b4 (inf-le t 258)))
           ((i1 if g1 (eq (at Ln u) l)
             ((i2 if g2 (le 258 t) ((r0 ret 0)))
              (p1 poke Pm t u)
              (s3 set t (+ t 1))
              (j1 join g3 (le l 10)
               ((h1 havoc lo (shl64 code (- 10 l)))
                (i3 if g4 (lt 1024 lo) ((r1 ret 0)))
                (s4 set hi (+ lo (pow (- 10 l))))
                (i4 if g5 (lt 1024 hi) ((r2 ret 0)))
                (f3 for j lo hi ()
                 ((p2 poke Ft j (bor64 (shl64 u 5) l)))))
               ()
               ())
              (s5 set code (+ code 1))))))
          (i5 if g6 (lt (pow l) code) ((r3 ret 0)))
          (p3 poke Lm l code)
          (s6 set code (shl code 1))))
        (r4 ret 1))
     'macros
      '((U (inf-letrans u n 258 (inf-ltle u n f2) hsy))
        (C (inf-letrans code (inf-pow l) (inf-pow lim) g6 (inf-powle l lim (inf-letrans l 20 lim (inf-ltsle l 20 f1) h20))))
        (X (inf-lelts code (add u (inf-pow l)) b3)))
     'proofs
      {"f2e-1" 'b1
       "s4-4" '(inf-fitlim w 10 loh1 (inf-pow (natminus 10 l)) gw (idpath true)
                 (inf-letrans loh1 1024 (inf-pow 10) g4 (idpath false))
                 (inf-powle (natminus 10 l) 10 (inf-suble 10 l)))
       "s5-1" '(bz-cfit w lim l code u gw h20 hq f1 U b3)
       "f2b-2" '(inf-lt1 code (add (succ u) (inf-pow l)) X)
       "f2b-6" '(inf-ltle code (add (succ u) (inf-pow l)) X)
       "s6-1" '(inf-fitlim w lim code code gw hm C C)
       "f1b-2" '(inf-powdbl l code code g6 g6)}}

   ; the next symbol, or 999, past any alphabet: the table's longest walked bit by bit
   sym
    {'name "bz_sym" 'short "zbsym"
     'attrs '("static" "inline")
     'ret 'uint
     'params (rd-params + '(("s" (ptr (const (struct "bz_tab"))))))
     'fields rd-fields 'state rd-state
     'arrays (rd-arrays + tab-arrays)
     'requires (rd-req + '((Ft (pi x nat nat)) (Lm (pi x nat nat)) (Bs (pi x nat nat)) (Pm (pi x nat nat))))
     'decls '((uint (v) (f) (l) (c) (t) (m)))
     'ensures rd-ens
     'calls [fill]
     'body
      '((j1 join g0 (lt k 32) ((c1 call "br_fill" ((raw (var "r"))) (In n w) ())) ()
         ((a1 (inf-le 32 k)) (a2 (inf-le k 64)) (a3 (inf-le i (add n 9)))))
        (d1 havoc v (u32 (shr64 acc (- k 10))))
        (d2 havoc f (at Ft (low v 1023)))
        (i1 if g1 (ne f 0)
         ((d3 dec k (- k (low f 31)))
          (r1 ret (shr64 f 5))))
        (h1 havoc m (sg "maxl"))
        (i2 if g2 (lt 20 m) ((r2 ret 999)))
        (f1 for l 11 (+ m 1) ((b1 (inf-le 11 l)) (b2 (inf-le 32 k)) (b3 (inf-le k 64)) (b4 (inf-le i (add n 9))))
         ((d4 havoc c (u32 (and64 (shr64 acc (- k l)) (m64 l))))
          (i3 if g3 (lt c (at Lm l))
           ((d5 havoc t (wsub c (at Bs l)))
            (i4 if g4 (le 258 t) ((r3 ret 999)))
            (d6 dec k (- k l))
            (r4 ret (at Pm t))))))
        (r5 ret 999))
     'macros '()
     'proofs
      {"f1b-2" '(inf-letrans 11 l (succ l) b1 (inf-ltle l (succ l) (inf-lelts l l (inf-refl l))))}}

   ; --- a block: its head, its symbols, its bytes ---------------------------------------------------
   hd-arrays '((Sq (d "seq") 256) (Ps (d "pos") 6) (Sl (d "sel") ms) (Ln (d "len") 258) (Tb (d "tab") 6))
   rd1 '(In n w (K 1))
   ; the map of bytes in use, the selectors, the tables
   dhead
    {'name "bz_dhead" 'short "zbhead"
     'attrs '("static")
     'ret 'int
     'params (rd-params + '(("d" (ptr (struct "bz_d")))))
     'fields rd-fields 'state rd-state
     'arrays (rd-arrays + hd-arrays)
     'requires
      (rd-req
       + '((Ps (pi x nat nat)) (Ln (pi x nat nat)) (ms nat) (tl nat)
           (gc (inf-lt (inf-by16 (add n 9)) (inf-pow w)))
           (hms (inf-lt ms (inf-pow w)))
           (h20 (inf-le 20 tl)) (hq (inf-lt tl 30))))
     'decls '((uint (u) (j) (t) (v) (b) (nuse) (m0) (m1) (c) (x) (alpha) (ng) (ns) (ms (raw (var "BZ_MAXSEL"))))
              ((named "uintptr_t") (cap) (m))
              ((ptr (struct "bz_tab")) (tp)))
     'ensures rd-ens
     'calls [get past tbuild]
     'body
      '((s0 set nuse 0)
        (c0 calx m0 "br_get" ((raw (var "r")) 16) (In n w (K 16)) ())
        (f1 for u 0 16 ((f1a (inf-le i (add n 9))) (f1b (inf-le k 64)))
         ((i1 if g1 (nz (sbit m0 (- 15 u)))
           ((c1 calx m1 "br_get" ((raw (var "r")) 16) (In n w (K 16)) ())
            (f2 for j 0 16 ((f2a (inf-le i (add n 9))) (f2b (inf-le k 64)))
             ((i2 if g2 (nz (sbit m1 (- 15 j)))
               ((i3 if g3 (le 256 nuse) ((r0 ret 2)))
                (p1 poke Sq nuse (wadd (shl64 u 4) j))
                (s1 set nuse (+ nuse 1))))))))))
        (i4 if g4 (z nuse) ((r1 ret 2)))
        (h0 havoc alpha (wadd nuse 2))
        (i5 if g5 (lt 258 alpha) ((r2 ret 2)))
        (c2 calx ng "br_get" ((raw (var "r")) 3) (In n w (K 3)) ())
        (c3 calx ns "br_get" ((raw (var "r")) 15) (In n w (K 15)) ())
        (i6 if g6 (lt ng 2) ((r3 ret 2)))
        (i7 if g7 (lt 6 ng) ((r4 ret 2)))
        (i8 if g8 (z ns) ((r5 ret 2)))
        (f3 for t 0 ng () ((p2 poke Ps t t)))
        (f4 for u 0 ns ((f4a (inf-le i (add n 9))) (f4b (inf-le k 64)))
         ((s2 set j 0)
          (w1 while (tru) (natminus ng j)
           ((w1a (inf-le i (add n 9))) (w1b (inf-le k 64)) (w1c (inf-lt j ng)))
           ((c4 calx b "br_get" ((raw (var "r")) 1) (In n w (K 1)) ())
            (i9 if g9 (z b) ((b1 brk)))
            (s3 set j (+ j 1))
            (i10 if g10 (le ng j) ((r6 ret 2)))))
          (h1 havoc v (at Ps j))
          (m2 mmove Ps 1 Ps 0 j)
          (p3 poke Ps 0 v)
          (i11 if g11 (lt u ms) ((p4 poke Sl u v)))))
        (j1 join g12 (lt ms ns) ((s4 set ns ms)) () ())
        (d0 dstore "ns" ns)
        (d1 dstore "alpha" alpha)
        (s5 set m 0)
        (s6 set cap (shl (+ n 9) 4))
        (f5 for t 0 ng ((f5a (inf-le i (add n 9))) (f5b (inf-le k 64)))
         ((c5 calx c "br_get" ((raw (var "r")) 5) (In n w (K 5)) ())
          (f6 for v 0 alpha ((f6a (inf-le i (add n 9))) (f6b (inf-le k 64)))
           ((w2 while (tru) (natminus cap m) ((w2a (inf-le i (add n 9))) (w2b (inf-le k 64)))
             ((i12 if g13 (le cap m) ((r7 ret 3)))
              (s7 set m (+ m 1))
              (i13 if g14 (lt c 1) ((r8 ret 2)))
              (i14 if g15 (lt 20 c) ((r9 ret 2)))
              (c6 calx b "br_get" ((raw (var "r")) 1) (In n w (K 1)) ())
              (i15 if g16 (z b) ((b2 brk)))
              (c7 calx x "br_get" ((raw (var "r")) 1) (In n w (K 1)) ())
              (j2 join g17 (nz x) ((d2 dec c (- c 1))) ((s8 set c (+ c 1))) ())))
            (p5 poke Ln v c)))
          (t1 ptr tp Tb t)
          (c8 calx x "bz_tbuild" ((raw (var "tp")) (dg "len") alpha) (Ln (n alpha) w (lim tl)) ())
          (i16 if g18 (z x) ((r10 ret 2)))
          (c9 calx x "br_past" ((raw (var "r"))) (n i k) ())
          (i17 if g19 (nz x) ((r11 ret 3)))))
        (r12 ret 0))
     'macros '()
     'proofs {}}

   ; the symbols: mtf and zero runs back to the bwt's last column, in tt's low byte
   dsyms
    {'name "bz_dsyms" 'short "zbsyms"
     'attrs '("static")
     'ret 'int
     'params (rd-params + '(("d" (ptr (struct "bz_d"))) ("level" uint)))
     'fields rd-fields 'state rd-state
     'arrays (rd-arrays + '((Sq (d "seq") 256) (Sl (d "sel") ms) (Tb (d "tab") 6) (Yy (d "yy") 256)
                            (Cn (d "cnt") 256) (Tt (d "tt") tn)))
     'requires
      (rd-req
       + '((Sq (pi x nat nat)) (Sl (pi x nat nat)) (Yy (pi x nat nat)) (Cn (pi x nat nat)) (Zt (pi x nat nat))
           (ms nat) (tn nat) (lim nat)
           (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hts (inf-le tn (inf-pow lim)))
           (hms (inf-lt ms (inf-pow w)))))
     'decls '((uint (g) (left) (s) (x) (run) (rw) (mx) (c) (v) (q) (y) (nb) (alpha) (ns)
                    (ms (raw (var "BZ_MAXSEL"))) (tn (raw (var "BZ_TN"))))
              ((ptr (struct "bz_tab")) (tp)))
     'ensures rd-ens
     'calls [past sym]
     'body
      '((h0 havoc alpha (dg "alpha"))
        (h1 havoc ns (dg "ns"))
        (i0 if g0 (lt 258 alpha) ((r0 ret 2)))
        (i1 if g1 (lt alpha 2) ((r1 ret 2)))
        (i2 if g2 (lt ms ns) ((r2 ret 2)))
        (c0 clear Cn (szof (dot (deref (var "d")) "cnt")))
        (h2 havoc mx (wmul level (raw (num 100000))))
        (i3 if g3 (lt tn mx) ((r3 ret 2)))
        (s0 set nb 0)
        (h3 havoc run 0)
        (h4 havoc rw 1)
        (f0 for y 0 256 () ((p0 poke Yy y y)))
        (f1 for g 0 ns ((f1a (inf-le i (add n 9))) (f1b (inf-le k 64)) (f1c (inf-le nb mx)))
         ((c1 calx x "br_past" ((raw (var "r"))) (n i k) ())
          (i4 if g4 (nz x) ((r4 ret 3)))
          (h5 havoc x (at Sl g))
          (i5 if g5 (lt 5 x) ((r5 ret 2)))
          (t0 ptr tp Tb x)
          (f2 for left 0 50 ((f2a (inf-le i (add n 9))) (f2b (inf-le k 64)) (f2c (inf-le nb mx)))
           ((c2 calx s "bz_sym" ((raw (var "r")) (raw (var "tp"))) (In n w (Ft Zt) (Lm Zt) (Bs Zt) (Pm Zt)) ())
            (i6 if g6 (le alpha s) ((r6 ret 2)))
            (e0 ife g7 (lt s 2)
             ((i7 if g8 (lt mx rw) ((r7 ret 2)))
              (h6 havoc run (wadd run (shl64 rw s)))
              (h7 havoc rw (shl64 rw 1))
              (i8 if g9 (lt mx run) ((r8 ret 2))))
             ((j0 join g10 (nz run)
               ((h8 havoc y (at Yy 0))
                (h9 havoc c (at Sq (low y 255)))
                (i9 if g11 (lt (- mx nb) run) ((r9 ret 2)))
                (p1 poke Cn (low c 255) (wadd (at Cn (low c 255)) run))
                (f3 for q 0 run () ((p2 poke Tt (+ nb q) c)))
                (s1 set nb (+ nb run))
                (h10 havoc run 0)
                (h11 havoc rw 1))
               ()
               ((j0a (inf-le nb mx))))
              (i10 if g12 (le (- alpha 1) s)
               ((d0 dstore "nb" nb)
                (r10 ret 0)))
              (i11 if g13 (le mx nb) ((r11 ret 2)))
              (s2 set v (- s 1))
              (i12 if g14 (le 256 v) ((r13 ret 2)))
              (h12 havoc y (at Yy v))
              (m0 mmove Yy 1 Yy 0 v)
              (p3 poke Yy 0 y)
              (h13 havoc c (at Sq (low y 255)))
              (p4 poke Cn (low c 255) (wadd (at Cn (low c 255)) 1))
              (p5 poke Tt nb c)
              (s3 set nb (+ nb 1))))))))
        (r12 ret 2))
     'macros
      '((Lw (inf-wpow w lim gw (inf-lttrans lim 31 32 hm (idpath false))))
        (Mt (inf-letrans mxh2 tn (inf-pow lim) g3 hts))
        (Mw (inf-lelt mxh2 (inf-pow lim) (inf-pow w) Mt Lw))
        (Nq (bz-nbq nb q run mxh2 f3 g11 f2c)))
     'proofs
      {"p2-1" '(inf-lttrans (add nb q) mxh2 (inf-pow w) Nq (inf-ltle mxh2 (inf-pow w) Mw))
       "p2-2" '(inf-lttrans (add nb q) mxh2 tn Nq g3)
       "f3b-1" '(inf-lelt (succ q) mxh2 (inf-pow w)
                 (inf-letrans (succ q) run mxh2 (inf-ltsu q run f3) (inf-letrans run (natminus mxh2 nb) mxh2 g11 (inf-suble mxh2 nb))) Mw)
       "j0j-1" '(bz-nbr nb run mxh2 g11 f2c)}}

   ; the inverse transform and the walk, the runs of four undone on the way out
   dout
    {'name "bz_dout" 'short "zbout"
     'attrs '("static")
     'ret 'int
     'params '(("d" (ptr (struct "bz_d"))) ("w" (ptr (struct "bz_w"))) ("nb" uint) ("orig" uint) ("want" uint))
     'state '((on on0) (oc oc0))
     'arrays '((Tt (d "tt") tn) (Cn (d "cnt") 256) (Cf (d "cf") 256) (Cr (d "crct") 256))
     'requires
      '((Tt (pi x nat nat)) (Cn (pi x nat nat)) (Cf (pi x nat nat)) (Cr (pi x nat nat))
        (w nat) (lim nat) (tn nat) (nb nat) (orig nat) (on0 nat) (oc0 nat)
        (gw (inf-le 32 w)) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hts (inf-le tn (inf-pow lim)))
        (hq (inf-le on0 oc0)) (hf (inf-lt oc0 (inf-pow w))))
     'decls '((uint (c) (s) (u) (j) (x) (p) (crc) (y) (same) (tn (raw (var "BZ_TN")))) (int (last)))
     'ensures '((e1 (inf-le on oc)) (e2 (inf-lt oc (inf-pow w))))
     'calls [bwbyte]
     'body
      '((i0 if g0 (lt tn nb) ((r0 ret 2)))
        (i1 if g1 (le nb orig) ((r1 ret 2)))
        (h0 havoc s 0)
        (f0 for c 0 256 ()
         ((p0 poke Cf c s)
          (h1 havoc s (wadd s (at Cn c)))))
        (f1 for u 0 nb ()
         ((h2 havoc x (at Tt u))
          (h3 havoc j (at Cf (low x 255)))
          (i2 if g2 (le nb j) ((r2 ret 2)))
          (p1 poke Tt j (bor64 (at Tt j) (shl64 u 8)))
          (p2 poke Cf (low x 255) (wadd j 1))))
        (h4 havoc p (shr64 (at Tt orig) 8))
        (h5 havoc crc (raw (num 4294967295)))
        (h6 havoc last (raw (un neg (num 1))))
        (h7 havoc same 0)
        (f2 for u 0 nb ((f2a (inf-le on oc)) (f2b (inf-lt oc (inf-pow w))))
         ((i3 if g3 (le nb p) ((r3 ret 2)))
          (h8 havoc x (at Tt p))
          (s0 set c (low x 255))
          (h9 havoc p (shr64 x 8))
          (e0 ife g4 (eq same 4)
           ((f3 for j 0 c ((f3a (inf-le on oc)) (f3b (inf-lt oc (inf-pow w))))
             ((h10 havoc y (bxor (shr64 crc 24) last))
              (h11 havoc crc (bxor (shl64 crc 8) (at Cr (low y 255))))
              (c0 call "bw_byte" ((raw (var "w")) (u8 last)) (w lim) ())))
            (h12 havoc same 0)
            (h13 havoc last (raw (un neg (num 1)))))
           ((h14 havoc y (bxor (shr64 crc 24) c))
            (h15 havoc crc (bxor (shl64 crc 8) (at Cr (low y 255))))
            (c1 call "bw_byte" ((raw (var "w")) (u8 c)) (w lim) ())
            (e1 ife g5 (eq c (u32 last)) ((h16 havoc same (wadd same 1))) ((h17 havoc same 1)))
            (h18 havoc last c)))))
        (i4 if g6 (ne (wg "bad") 0) ((r4 ret (raw (un neg (num 1))))))
        (i5 if g7 (ne (bnot crc) want) ((r5 ret 4)))
        (r6 ret 0))
     'macros '()
     'proofs {}}

   ; one block after its magic -> 0 | an error; its bytes appended to w, their crc checked and left in
   ; d->bc. it takes nothing from its caller it cannot check, but that the pointers hold what they say
   dblock
    {'name "bz_dblock" 'short "zbblock"
     'attrs '("static")
     'ret 'int
     'params '(("d" (ptr (struct "bz_d"))) ("r" (ptr (struct "bz_r"))) ("level" uint) ("w" (ptr (struct "bz_w"))))
     'fields rd-fields 'wfields '(on oc)
     'state (rd-state + '((on on0) (oc oc0)))
     'arrays rd-arrays
     'requires
      '((In (pi x nat nat)) (Ps (pi x nat nat)) (Ln (pi x nat nat)) (Sq (pi x nat nat)) (Sl (pi x nat nat)) (Yy (pi x nat nat))
        (Cn (pi x nat nat)) (Cf (pi x nat nat)) (Tt (pi x nat nat)) (Cr (pi x nat nat)) (Zt (pi x nat nat))
        (n nat) (w nat) (i0 nat) (k0 nat) (on0 nat) (oc0 nat) (ms nat) (tn nat) (lim nat) (tl nat)
        (gw (inf-le 32 w)) (hl (inf-le 19 lim)) (hm (inf-lt lim 31)) (hts (inf-le tn (inf-pow lim)))
        (hms (inf-lt ms (inf-pow w))) (h20 (inf-le 20 tl)) (hq (inf-lt tl 30))
        (hf (inf-lt oc0 (inf-pow w))))
     'decls '((uint (want) (orig) (x) (nb)))
     'ensures ()
     'calls [get past dhead dsyms dout]
     'body
      '((i0 if g0 (over n 9) ((r0 ret 2)))
        (i1 if g1 (over16 (+ n 9)) ((r1 ret 2)))
        (i2 if g2 (lt (+ n 9) i) ((r2 ret 2)))
        (i3 if g3 (lt 64 k) ((r3 ret 2)))
        (i4 if g4 (lt oc on) ((r4 ret 2)))
        (c0 calx want "br_get" ((raw (var "r")) 32) (In n w (K 32)) ())
        (c1 calx x "br_get" ((raw (var "r")) 1) (In n w (K 1)) ())
        (i5 if g5 (nz x) ((r5 ret 2)))
        (c2 calx orig "br_get" ((raw (var "r")) 24) (In n w (K 24)) ())
        (c3 calx x "bz_dhead" ((raw (var "r")) (raw (var "d"))) (In n w Ps Ln ms tl) ())
        (i6 if g6 (nz x) ((r6 ret x)))
        (c4 calx x "bz_dsyms" ((raw (var "r")) (raw (var "d")) level) (In n w Sq Sl Yy Cn Zt ms tn lim) ())
        (i7 if g7 (nz x) ((r7 ret x)))
        (c5 calx x "br_past" ((raw (var "r"))) (n i k) ())
        (i8 if g8 (nz x) ((r8 ret 3)))
        (h0 havoc nb (dg "nb"))
        (c6 calx x "bz_dout" ((raw (var "d")) (raw (var "w")) nb orig want) (Tt Cn Cf Cr w lim tn nb orig) ())
        (i9 if g9 (nz x) ((r9 ret x)))
        (d0 dstore "bc" want)
        (r10 ret 0))
     'macros '()
     'proofs {}}

   bz-head (cats ["#define BZ_TN " (show bz-tn) "\n#define BZ_MAXSEL " (show bz-ms) "\n#define BZ_LIM " (show bz-lim) "\n"
      """
      struct bz_w { uint8_t *p; uintptr_t on, oc; uint64_t acc; unsigned k; int bad, big, fix; };   // fix: p is the caller's, never grown
      struct bz_r { const uint8_t *p; uintptr_t i, n; uint64_t acc; unsigned k; };
      struct bz_tab {
       uint16_t fast[1024];                            // sym << 5 | len, or 0 past the root
       uint32_t limit[22], base[22]; uint16_t perm[258]; unsigned maxl; };
      struct bz_d {
       uint32_t tt[BZ_TN]; struct bz_tab tab[6]; uint8_t sel[BZ_MAXSEL]; uint32_t crct[256];
       uint32_t cnt[256], cf[256], alpha, ns, nb, bc; uint8_t seq[256], yy[256], len[258], pos[6]; };
      """])
   bz-specs [bwbyte fill get past tbuild sym dhead dsyms dout dblock]
   bz-h (cats ["// bz_gen.h -- laid by src/love/compress/bz.l, `make mx`. edit that file.\n"
               bz-head
               (cats (map (s \ clay-show (cl-fn s)) bz-specs))])
   bz-ledger
    [["pointers" "bz_dblock's d, r and w" "bz2.c hands them over whole, d from alloc, r over the string, w from its caller"]
     ["sink" "w's p holds oc bytes" "w is all zero, or bz2_into's out and cap (srctree.c)"]
     ["reader" "br_get from bz_dec and bz_step" "n + 9 fits, i <= n + 9, k <= 64: bz2.c's framing; bz_dblock checks them for itself"]
     ["alloc" "NULL or the bytes asked for" "alloc.c, as inflate's ledger has it"]
     ["word" "oc fits its word, and a word read back fits" "the C type; `havw` states the second"]
     ["widths" "tn <= 2^lim, ms fits" "bz-ok checks the numbers, bz.l's one binding"]]
   (ledger-text l) (cats (map (r \ r @ [a b c] "; \(a): \(b) -- \(c)\n") l))
   bz-vc (cats ["; test/uuzbvc.l -- laid by src/love/compress/bz.l, `make mx`. edit that file.\n"
                "; the ledger: what the theorems leave open, each with who answers for it\n"
                (ledger-text bz-ledger)
                "(test\n"
                (cats (map (s \ cats (vc-text s)) bz-specs)) " )\n"])
   bz-ok (0 < #bz-vc && all (s \ clay-ok? (cl-fn s) = 1 && atom? (vc-open s) && atom? (vc-stale s)) bz-specs
          && bz-tn <= 1 << bz-lim && bz-ms < 1 << 32 && bz-tl = 20))
