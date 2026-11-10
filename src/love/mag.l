; src/love/mag.l -- num.c's magnitude loops as data: vc.l lays mag_gen.h and the obligations in
; test/uumagvc.l. a magnitude's value is un-val, its limbs under B = 2^L: each function's theorem
; says what it computes, test/uumag.l the arithmetic underneath
(:
   _ (borrow "src/apps/moon/clay.l")
   _ (borrow "src/love/compress/vc.l")
   _ (borrow "src/love/compress/ring.l")

   Bt '(inf-pow L)
   (vl A n) ['un-val Bt A n]
   (pw i) ['uu-app i Bt]
   limb-req '((L nat) (w nat) (gw (inf-le 32 w)) (gL (inf-le 1 L)))
   (limbs A) [(intern "g\(A)") ['pi 'j 'nat ['inf-lt [A 'j] Bt]]]
   (int-n v) ['raw ['cast '(named "uintptr_t") ['var v]]]

   ; --- r = a + b, a the longer: r's capacity n + 1 -> its limb count -------------------------
   add
    {'name "mag_add_ge" 'short "madd"
     'attrs '("static" "love_inline")
     'ret 'int
     'params '(("r" (ptr (named "love_limb"))) ("a" (ptr (const (named "love_limb")))) ("na" int)
               ("b" (ptr (const (named "love_limb")))) ("nb" int))
     'fields ()
     'limb 'L
     'vals '(R)
     'dvars '(s c)
     'arrays '((R (v "r") rc) (A (v "a") n) (V (v "b") m))
     'requires
      (['(R (pi j nat nat)) '(A (pi j nat nat)) '(V (pi j nat nat)) '(n nat) '(m nat) '(rc nat)]
       + limb-req
       + ['(gm (inf-le m n)) '(gr (inf-le (add n 1) rc)) '(gn (inf-lt (add n 1) (inf-pow w))) (limbs 'A) (limbs 'V)])
     'decls
      [['(named "uintptr_t") ['n (int-n "na")] ['m (int-n "nb")] ['i]]
       ['(named "dlimb") ['s] ['c]]]
     'ensures
      [['e1 ['inf-le 'res '(add n 1)]]
       ['e2 ['paths 'nat (vl 'R 'res) ['add (vl 'A 'n) (vl 'V 'm)]]]]
     'body
      [['s0 'set 'i 0] ['s8 'set 'c 0]
       ['w1 'while '(lt i m) '(natminus m i)
        [['a1 '(inf-le i m)] ['a2 '(inf-le c 1)]
         ['a3 ['paths 'nat ['add (vl 'R 'i) ['mul 'c (pw 'i)]] ['add (vl 'A 'i) (vl 'V 'i)]]]]
        '((s1 set s (d+ (d+ (dl (at A i)) (dl (at V i))) c))
          (p1 poke R i (lo s))
          (s2 set c (hi s))
          (s3 set i (+ i 1)))]
       ['w2 'while '(lt i n) '(natminus n i)
        [['b1 '(inf-le m i)] ['b2 '(inf-le i n)] ['b3 '(inf-le c 1)]
         ['b4 ['paths 'nat ['add (vl 'R 'i) ['mul 'c (pw 'i)]] ['add (vl 'A 'i) (vl 'V 'm)]]]]
        '((s4 set s (d+ (dl (at A i)) c))
          (p2 poke R i (lo s))
          (s5 set c (hi s))
          (s6 set i (+ i 1)))]
       ['j1 'join 'g1 '(nz c) '((p3 poke R i (lc c)) (s7 set i (+ i 1))) ()
        [['t1 '(inf-le i (add n 1))] ['t2 ['paths 'nat (vl 'R 'i) ['add (vl 'A 'n) (vl 'V 'm)]]]]]
       '(r1 ret (cast i))]
     'macros '()
     'proofs
      {
       "s8-1" '(inf-powpos (add L L))
       "w1e-3" '(idpath 0)
       "s1-3" '(un-dfit L gL (add (A i) (V i)) (un-sum2llt (inf-pow L) (A i) (V i) (gA i) (gV i)))
       "s1-4" '(un-dfit L gL (add (add (A i) (V i)) c) (un-sum3lt (inf-pow L) (A i) (V i) c (gA i) (gV i) a2))
       "p1-1" '(inf-lttrans i m rc w1 (inf-letrans m n rc gm (inf-letrans n (add n 1) rc (inf-leaddr n 1) gr)))
       "s2-1" '(un-cfit L gL (un-div (inf-pow L) (add (add (A i) (V i)) c)) (un-carry1 (inf-pow L) (inf-powpos L) (add (add (A i) (V i)) c) (un-sum3lt (inf-pow L) (A i) (V i) c (gA i) (gV i) a2)))
       "w1b-2" '(un-carry1 (inf-pow L) (inf-powpos L) (add (add (A i) (V i)) c) (un-sum3lt (inf-pow L) (A i) (V i) c (gA i) (gV i) a2))
       "w1b-3" '(transportf nat (lam z (paths nat (add (un-val (inf-pow L) (inf-upd R i (inf-mod (inf-pow L) (add (add (A i) (V i)) c))) z) (mul (un-div (inf-pow L) (add (add (A i) (V i)) c)) (uu-app z (inf-pow L)))) (add (un-val (inf-pow L) A z) (un-val (inf-pow L) V z)))) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (un-addstep (inf-pow L) (inf-powpos L) R A V i c a3))
       "w2e-4" '(transportf nat (lam z (paths nat (add (un-val (inf-pow L) R i) (mul c (uu-app i (inf-pow L)))) (add (un-val (inf-pow L) A i) (un-val (inf-pow L) V z)))) i m (isantisymmnatleh i m a1 w1) a3)
       "s4-2" '(un-dfit L gL (add (A i) c) (un-sum2lt (inf-pow L) (inf-powpos L) (A i) c (gA i) b3))
       "p2-1" '(inf-lttrans i n rc w2 (inf-letrans n (add n 1) rc (inf-leaddr n 1) gr))
       "s5-1" '(un-cfit L gL (un-div (inf-pow L) (add (A i) c)) (un-carry1 (inf-pow L) (inf-powpos L) (add (A i) c) (un-sum2lt (inf-pow L) (inf-powpos L) (A i) c (gA i) b3)))
       "w2b-3" '(un-carry1 (inf-pow L) (inf-powpos L) (add (A i) c) (un-sum2lt (inf-pow L) (inf-powpos L) (A i) c (gA i) b3))
       "w2b-4" '(transportf nat (lam z (paths nat (add (un-val (inf-pow L) (inf-upd R i (inf-mod (inf-pow L) (add (A i) c))) z) (mul (un-div (inf-pow L) (add (A i) c)) (uu-app z (inf-pow L)))) (add (un-val (inf-pow L) A z) (un-val (inf-pow L) V m)))) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (un-addstep1 (inf-pow L) (inf-powpos L) R A (un-val (inf-pow L) V m) i c b4))
       "p3-1" '(inf-lelt i n rc b2 (inf-lttrans n (add n 1) rc (un-ltp1 n) gr))
       "p3-2" '(inf-lelt c 1 (inf-pow L) b3 (un-1ltB L gL))
       "s7-1" '(inf-lelt (add i 1) (add n 1) (inf-pow w) (inf-addr i n 1 b2) gn)
       "j1j-1" '(inf-addr i n 1 b2)
       "j1j-2" '(transportf nat (lam z (paths nat (un-val (inf-pow L) (inf-upd R i c) z) (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)))) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (pathscomp0 nat (un-val (inf-pow L) (inf-upd R i c) (succ i)) (add (un-val (inf-pow L) R i) (mul c (uu-app i (inf-pow L)))) (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)) (un-valst (inf-pow L) R i c) (pathscomp0 nat (add (un-val (inf-pow L) R i) (mul c (uu-app i (inf-pow L)))) (add (un-val (inf-pow L) A i) (un-val (inf-pow L) V m)) (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)) b4 (maponpaths nat nat (lam z (add (un-val (inf-pow L) A z) (un-val (inf-pow L) V m))) i n (isantisymmnatleh i n b2 w2)))))
       "j1j-4" '(pathscomp0 nat (un-val (inf-pow L) R i) (add (un-val (inf-pow L) R i) (mul c (uu-app i (inf-pow L)))) (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)) (pathscomp0 nat (un-val (inf-pow L) R i) (add (un-val (inf-pow L) R i) 0) (add (un-val (inf-pow L) R i) (mul c (uu-app i (inf-pow L)))) (pathsinv0 nat (add (un-val (inf-pow L) R i) 0) (un-val (inf-pow L) R i) (natplusr0 (un-val (inf-pow L) R i))) (maponpaths nat nat (lam z (add (un-val (inf-pow L) R i) (mul z (uu-app i (inf-pow L))))) 0 c (pathsinv0 nat c 0 g1))) (pathscomp0 nat (add (un-val (inf-pow L) R i) (mul c (uu-app i (inf-pow L)))) (add (un-val (inf-pow L) A i) (un-val (inf-pow L) V m)) (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)) b4 (maponpaths nat nat (lam z (add (un-val (inf-pow L) A z) (un-val (inf-pow L) V m))) i n (isantisymmnatleh i n b2 w2))))}}

   ; --- r = a - b, a >= b: r's capacity n -> n, the high zeros the caller's ------------------------
   sub
    {'name "mag_sub" 'short "msub"
     'attrs '("static" "love_noinline")
     'ret 'int
     'params '(("r" (ptr (named "love_limb"))) ("a" (ptr (const (named "love_limb")))) ("na" int)
               ("b" (ptr (const (named "love_limb")))) ("nb" int))
     'fields ()
     'limb 'L
     'vals '(R)
     'dvars '(s c)
     'arrays '((R (v "r") rc) (A (v "a") n) (V (v "b") m))
     'requires
      (['(R (pi j nat nat)) '(A (pi j nat nat)) '(V (pi j nat nat)) '(n nat) '(m nat) '(rc nat)]
       + limb-req
       + ['(gm (inf-le m n)) '(gr (inf-le n rc)) '(gn (inf-lt n (inf-pow w))) (limbs 'A) (limbs 'V)
          ['gle ['inf-le (vl 'V 'm) (vl 'A 'n)]]])
     'decls
      [['(named "uintptr_t") ['n (int-n "na")] ['m (int-n "nb")] ['i]]
       ['(named "dlimb") ['s] ['c]]]
     'ensures
      [['e1 '(paths nat res n)]
       ['e2 ['paths 'nat ['add (vl 'R 'n) (vl 'V 'm)] (vl 'A 'n)]]]
     'body
      [['s0 'set 'i 0] ['s8 'set 'c 0]
       ['w1 'while '(lt i m) '(natminus m i)
        [['a1 '(inf-le i m)] ['a2 '(inf-le c 1)]
         ['a3 ['paths 'nat ['add (vl 'R 'i) (vl 'V 'i)] ['add (vl 'A 'i) ['mul 'c (pw 'i)]]]]
         ['a4 ['inf-lt (vl 'R 'i) (pw 'i)]]]
        '((s1 set s (- (d+ (dl (at A i)) (lB)) (d+ (dl (at V i)) c)))
          (p1 poke R i (lo s))
          (s2 set c (- 1 (hi s)))
          (s3 set i (+ i 1)))]
       ['w2 'while '(lt i n) '(natminus n i)
        [['b1 '(inf-le m i)] ['b2 '(inf-le i n)] ['b3 '(inf-le c 1)]
         ['b4 ['paths 'nat ['add (vl 'R 'i) (vl 'V 'm)] ['add (vl 'A 'i) ['mul 'c (pw 'i)]]]]
         ['b5 ['inf-lt (vl 'R 'i) (pw 'i)]]]
        '((s4 set s (- (d+ (dl (at A i)) (lB)) c))
          (p2 poke R i (lo s))
          (s5 set c (- 1 (hi s)))
          (s6 set i (+ i 1)))]
       '(r1 ret (cast n))]
     'macros '()
     'proofs
      {
       "s8-1" '(inf-powpos (add L L))
       "w1e-3" '(idpath 0)
       "w1e-4" '(idpath true)
       "s1-2" '(un-dfit L gL (add (A i) (inf-pow L)) (inf-ltaddr (A i) (inf-pow L) (inf-pow L) (gA i)))
       "s1-4" '(un-dfit L gL (add (V i) c) (un-sum2lt (inf-pow L) (inf-powpos L) (V i) c (gV i) a2))
       "s1-5" '(inf-letrans (add (V i) c) (inf-pow L) (add (A i) (inf-pow L)) (un-vcle (inf-pow L) (V i) c (gV i) a2) (inf-leaddl (inf-pow L) (A i)))
       "s1-6" '(un-dfit L gL (natminus (add (A i) (inf-pow L)) (add (V i) c)) (inf-lelt (natminus (add (A i) (inf-pow L)) (add (V i) c)) (add (A i) (inf-pow L)) (add (inf-pow L) (inf-pow L)) (inf-suble (add (A i) (inf-pow L)) (add (V i) c)) (inf-ltaddr (A i) (inf-pow L) (inf-pow L) (gA i))))
       "s2-1" '(un-carry1 (inf-pow L) (inf-powpos L) (natminus (add (A i) (inf-pow L)) (add (V i) c)) (inf-lelt (natminus (add (A i) (inf-pow L)) (add (V i) c)) (add (A i) (inf-pow L)) (add (inf-pow L) (inf-pow L)) (inf-suble (add (A i) (inf-pow L)) (add (V i) c)) (inf-ltaddr (A i) (inf-pow L) (inf-pow L) (gA i))))
       "s2-2" '(un-cfit L gL (natminus 1 (un-div (inf-pow L) (natminus (add (A i) (inf-pow L)) (add (V i) c)))) (inf-suble 1 (un-div (inf-pow L) (natminus (add (A i) (inf-pow L)) (add (V i) c)))))
       "w1b-3" '(transportf nat (lam z (paths nat (add (un-val (inf-pow L) (inf-upd R i (inf-mod (inf-pow L) (natminus (add (A i) (inf-pow L)) (add (V i) c)))) z) (un-val (inf-pow L) V z)) (add (un-val (inf-pow L) A z) (mul (natminus 1 (un-div (inf-pow L) (natminus (add (A i) (inf-pow L)) (add (V i) c)))) (uu-app z (inf-pow L)))))) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (un-substep (inf-pow L) (inf-powpos L) R A V i c (inf-letrans (add (V i) c) (inf-pow L) (add (A i) (inf-pow L)) (un-vcle (inf-pow L) (V i) c (gV i) a2) (inf-leaddl (inf-pow L) (A i))) (un-carry1 (inf-pow L) (inf-powpos L) (natminus (add (A i) (inf-pow L)) (add (V i) c)) (inf-lelt (natminus (add (A i) (inf-pow L)) (add (V i) c)) (add (A i) (inf-pow L)) (add (inf-pow L) (inf-pow L)) (inf-suble (add (A i) (inf-pow L)) (add (V i) c)) (inf-ltaddr (A i) (inf-pow L) (inf-pow L) (gA i)))) a3))
       "w1b-4" '(transportf nat (lam z (inf-lt (un-val (inf-pow L) (inf-upd R i (inf-mod (inf-pow L) (natminus (add (A i) (inf-pow L)) (add (V i) c)))) z) (uu-app z (inf-pow L)))) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (un-rbound (inf-pow L) R i (inf-mod (inf-pow L) (natminus (add (A i) (inf-pow L)) (add (V i) c))) a4 (un-modlt0 (inf-pow L) (inf-powpos L) (natminus (add (A i) (inf-pow L)) (add (V i) c)))))
       "w2e-4" '(transportf nat (lam z (paths nat (add (un-val (inf-pow L) R i) (un-val (inf-pow L) V z)) (add (un-val (inf-pow L) A i) (mul c (uu-app i (inf-pow L)))))) i m (isantisymmnatleh i m a1 w1) a3)
       "s4-2" '(un-dfit L gL (add (A i) (inf-pow L)) (inf-ltaddr (A i) (inf-pow L) (inf-pow L) (gA i)))
       "s4-3" '(inf-letrans c (inf-pow L) (add (A i) (inf-pow L)) (inf-letrans c 1 (inf-pow L) b3 (inf-ltle 1 (inf-pow L) (un-1ltB L gL))) (inf-leaddl (inf-pow L) (A i)))
       "s4-4" '(un-dfit L gL (natminus (add (A i) (inf-pow L)) c) (inf-lelt (natminus (add (A i) (inf-pow L)) c) (add (A i) (inf-pow L)) (add (inf-pow L) (inf-pow L)) (inf-suble (add (A i) (inf-pow L)) c) (inf-ltaddr (A i) (inf-pow L) (inf-pow L) (gA i))))
       "s5-1" '(un-carry1 (inf-pow L) (inf-powpos L) (natminus (add (A i) (inf-pow L)) c) (inf-lelt (natminus (add (A i) (inf-pow L)) c) (add (A i) (inf-pow L)) (add (inf-pow L) (inf-pow L)) (inf-suble (add (A i) (inf-pow L)) c) (inf-ltaddr (A i) (inf-pow L) (inf-pow L) (gA i))))
       "s5-2" '(un-cfit L gL (natminus 1 (un-div (inf-pow L) (natminus (add (A i) (inf-pow L)) c))) (inf-suble 1 (un-div (inf-pow L) (natminus (add (A i) (inf-pow L)) c))))
       "w2b-4" '(transportf nat (lam z (paths nat (add (un-val (inf-pow L) (inf-upd R i (inf-mod (inf-pow L) (natminus (add (A i) (inf-pow L)) c))) z) (un-val (inf-pow L) V m)) (add (un-val (inf-pow L) A z) (mul (natminus 1 (un-div (inf-pow L) (natminus (add (A i) (inf-pow L)) c))) (uu-app z (inf-pow L)))))) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (un-substep1 (inf-pow L) (inf-powpos L) R A (un-val (inf-pow L) V m) i c (inf-letrans c (inf-pow L) (add (A i) (inf-pow L)) (inf-letrans c 1 (inf-pow L) b3 (inf-ltle 1 (inf-pow L) (un-1ltB L gL))) (inf-leaddl (inf-pow L) (A i))) (un-carry1 (inf-pow L) (inf-powpos L) (natminus (add (A i) (inf-pow L)) c) (inf-lelt (natminus (add (A i) (inf-pow L)) c) (add (A i) (inf-pow L)) (add (inf-pow L) (inf-pow L)) (inf-suble (add (A i) (inf-pow L)) c) (inf-ltaddr (A i) (inf-pow L) (inf-pow L) (gA i)))) b4))
       "w2b-5" '(transportf nat (lam z (inf-lt (un-val (inf-pow L) (inf-upd R i (inf-mod (inf-pow L) (natminus (add (A i) (inf-pow L)) c))) z) (uu-app z (inf-pow L)))) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (un-rbound (inf-pow L) R i (inf-mod (inf-pow L) (natminus (add (A i) (inf-pow L)) c)) b5 (un-modlt0 (inf-pow L) (inf-powpos L) (natminus (add (A i) (inf-pow L)) c))))
       "r1-2" '(idpath n)
       "r1-3" '(un-bdone (uu-app n (inf-pow L)) (un-val (inf-pow L) R n) (un-val (inf-pow L) V m) (un-val (inf-pow L) A n) c (transportf nat (lam z (paths nat (add (un-val (inf-pow L) R z) (un-val (inf-pow L) V m)) (add (un-val (inf-pow L) A z) (mul c (uu-app z (inf-pow L)))))) i n (isantisymmnatleh i n b2 w2) b4) (transportf nat (lam z (inf-lt (un-val (inf-pow L) R z) (uu-app z (inf-pow L)))) i n (isantisymmnatleh i n b2 w2) b5) gle)
      }}

   ; --- a = a ml + ad in place, room at a[n] for the carry -> the limb count ---------------------
   mas
    {'name "mag_mul_add_small" 'short "mmas"
     'attrs '("static" "love_noinline")
     'ret 'int
     'params '(("a" (ptr (named "love_limb"))) ("na" int) ("ml" (named "love_limb")) ("ad" (named "love_limb")))
     'fields ()
     'limb 'L
     'vals '(A)
     'dvars '(s c)
     'arrays '((A (v "a") ac))
     'requires
      (['(A (pi j nat nat)) '(A0 (pi j nat nat)) '(n nat) '(ac nat) '(ml nat) '(ad nat)]
       + limb-req
       + ['(gr (inf-le (add n 1) ac)) '(gn (inf-lt (add n 1) (inf-pow w))) (limbs 'A0)
          ['gml ['inf-lt 'ml Bt]] ['gad ['inf-lt 'ad Bt]] '(g0 (pi j nat (paths nat (A j) (A0 j))))])
     'decls
      [['(named "uintptr_t") ['n (int-n "na")] ['i]]
       ['(named "dlimb") ['s] ['c]]]
     'ensures
      [['e1 ['inf-le 'res '(add n 1)]]
       ['e2 ['paths 'nat (vl 'A 'res) ['add ['mul 'ml (vl 'A0 'n)] 'ad]]]]
     'body
      [['s0 'set 'i 0] '(s8 set c (dl ad))
       ['w1 'while '(lt i n) '(natminus n i)
        [['a1 '(inf-le i n)] ['a2 ['inf-lt 'c Bt]]
         ['a3 ['paths 'nat ['add (vl 'A 'i) ['mul 'c (pw 'i)]] ['add ['mul 'ml (vl 'A0 'i)] 'ad]]]
         ['a4 '(pi j nat (pi g (inf-le i j) (paths nat (A j) (A0 j))))]]
        '((s1 set s (d+ (d* (dl (at A i)) (dl ml)) c))
          (p1 poke A i (lo s))
          (s2 set c (hi s))
          (s3 set i (+ i 1)))]
       ['j1 'join 'g1 '(nz c) '((p3 poke A i (lc c)) (s7 set i (+ i 1))) ()
        [['t1 '(inf-le i (add n 1))] ['t2 ['paths 'nat (vl 'A 'i) ['add ['mul 'ml (vl 'A0 'n)] 'ad]]]]]
       '(r1 ret (cast i))]
     'macros '()
     'proofs
      {
       "s8-1" '(un-dfit L gL ad (inf-lttrans ad (inf-pow L) (add (inf-pow L) (inf-pow L)) gad (inf-leaddr (inf-pow L) (inf-pow L))))
       "w1e-3" '(pathscomp0 nat (mul ad 1) ad (add (mul ml 0) ad) (natmultr1 ad) (pathsinv0 nat (add (mul ml 0) ad) ad (maponpaths nat nat (lam z (add z ad)) (mul ml 0) 0 (natmultn0 ml))))
       "w1e-4" '(lam j g (g0 j))
       "s1-1" '(inf-lttrans i n ac w1 (inf-letrans n (add n 1) ac (inf-leaddr n 1) gr))
       "s1-2" '(un-bbfit L (mul (A i) ml) (inf-lelt (mul (A i) ml) (add (mul (A i) ml) c) (mul (inf-pow L) (inf-pow L)) (inf-leaddr (mul (A i) ml) c) (un-mfit (inf-pow L) (A i) ml c (inf-lttr (A0 i) (A i) (inf-pow L) (pathsinv0 nat (A i) (A0 i) (a4 i (isreflnatleh i))) (gA0 i)) gml a2)))
       "s1-3" '(un-bbfit L (add (mul (A i) ml) c) (un-mfit (inf-pow L) (A i) ml c (inf-lttr (A0 i) (A i) (inf-pow L) (pathsinv0 nat (A i) (A0 i) (a4 i (isreflnatleh i))) (gA0 i)) gml a2))
       "p1-1" '(inf-lttrans i n ac w1 (inf-letrans n (add n 1) ac (inf-leaddr n 1) gr))
       "s2-1" '(un-dfit L gL (un-div (inf-pow L) (add (mul (A i) ml) c)) (inf-lttrans (un-div (inf-pow L) (add (mul (A i) ml) c)) (inf-pow L) (add (inf-pow L) (inf-pow L)) (un-divlt (inf-pow L) (inf-powpos L) (add (mul (A i) ml) c) (inf-pow L) (un-mfit (inf-pow L) (A i) ml c (inf-lttr (A0 i) (A i) (inf-pow L) (pathsinv0 nat (A i) (A0 i) (a4 i (isreflnatleh i))) (gA0 i)) gml a2)) (inf-leaddr (inf-pow L) (inf-pow L))))
       "w1b-2" '(un-divlt (inf-pow L) (inf-powpos L) (add (mul (A i) ml) c) (inf-pow L) (un-mfit (inf-pow L) (A i) ml c (inf-lttr (A0 i) (A i) (inf-pow L) (pathsinv0 nat (A i) (A0 i) (a4 i (isreflnatleh i))) (gA0 i)) gml a2))
       "w1b-3" '(transportf nat (lam z (paths nat (add (un-val (inf-pow L) (inf-upd A i (inf-mod (inf-pow L) (add (mul (A i) ml) c))) z) (mul (un-div (inf-pow L) (add (mul (A i) ml) c)) (uu-app z (inf-pow L)))) (add (mul ml (un-val (inf-pow L) A0 z)) ad))) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (un-mstep (inf-pow L) (inf-powpos L) A A0 ml ad i c a3 (a4 i (isreflnatleh i))))
       "w1b-4" '(lam j g (pathscomp0 nat ((inf-upd A i (inf-mod (inf-pow L) (add (mul (A i) ml) c))) j) (A j) (A0 j) (un-updgt A i (inf-mod (inf-pow L) (add (mul (A i) ml) c)) j (un-sult i j (inf-letr (add i 1) (succ i) j (un-add1 i) g))) (a4 j (inf-letrans i (add i 1) j (inf-leaddr i 1) g))))
       "p3-1" '(inf-lelt i n ac a1 (inf-lttrans n (add n 1) ac (un-ltp1 n) gr))
       "s7-1" '(inf-lelt (add i 1) (add n 1) (inf-pow w) (inf-addr i n 1 a1) gn)
       "j1j-1" '(inf-addr i n 1 a1)
       "j1j-2" '(transportf nat (lam z (paths nat (un-val (inf-pow L) (inf-upd A i c) z) (add (mul ml (un-val (inf-pow L) A0 n)) ad))) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (pathscomp0 nat (un-val (inf-pow L) (inf-upd A i c) (succ i)) (add (un-val (inf-pow L) A i) (mul c (uu-app i (inf-pow L)))) (add (mul ml (un-val (inf-pow L) A0 n)) ad) (un-valst (inf-pow L) A i c) (transportf nat (lam z (paths nat (add (un-val (inf-pow L) A i) (mul c (uu-app i (inf-pow L)))) (add (mul ml (un-val (inf-pow L) A0 z)) ad))) i n (isantisymmnatleh i n a1 w1) a3)))
       "j1j-4" '(pathscomp0 nat (un-val (inf-pow L) A i) (add (un-val (inf-pow L) A i) (mul c (uu-app i (inf-pow L)))) (add (mul ml (un-val (inf-pow L) A0 n)) ad) (pathscomp0 nat (un-val (inf-pow L) A i) (add (un-val (inf-pow L) A i) 0) (add (un-val (inf-pow L) A i) (mul c (uu-app i (inf-pow L)))) (pathsinv0 nat (add (un-val (inf-pow L) A i) 0) (un-val (inf-pow L) A i) (natplusr0 (un-val (inf-pow L) A i))) (maponpaths nat nat (lam z (add (un-val (inf-pow L) A i) (mul z (uu-app i (inf-pow L))))) 0 c (pathsinv0 nat c 0 g1))) (transportf nat (lam z (paths nat (add (un-val (inf-pow L) A i) (mul c (uu-app i (inf-pow L)))) (add (mul ml (un-val (inf-pow L) A0 z)) ad))) i n (isantisymmnatleh i n a1 w1) a3))
      }}

   ; --- rows [p, n) of the schoolbook r = a b, row i adding a[i] b at limb i. only row 0 reads
   ;     limbs no row wrote, so lvm_bmul can run a chunk per dispatch and yield -----------------
   (limbsR g) [g ['pi 'j 'nat ['inf-lt '(R j) Bt]]]
   (rows-at i) ['paths 'nat (vl 'R ['add i 'm]) ['mul (vl 'A i) (vl 'V 'm)]]
   rows0
    {'name "mag_mul_rows" 'short "mrows"
     'attrs '("static" "love_noinline")
     'ret 'void
     'params '(("r" (ptr (named "love_limb"))) ("a" (ptr (const (named "love_limb")))) ("i0" int) ("end" int)
               ("b" (ptr (const (named "love_limb")))) ("nb" int))
     'fields ()
     'limb 'L
     'vals '(R)
     'dvars '(ai s c)
     'arrays '((R (v "r") rc) (A (v "a") an) (V (v "b") m))
     'requires
      (['(R (pi j nat nat)) '(A (pi j nat nat)) '(V (pi j nat nat)) '(p nat) '(n nat) '(m nat) '(rc nat) '(an nat)]
       + limb-req
       + ['(gpn (inf-le p n)) '(gan (inf-le n an)) '(grc (inf-le (add n m) rc)) '(gnw (inf-lt (add n m) (inf-pow w)))
          (limbs 'A) (limbs 'V) (limbs 'R) ['g0 ['pi 'h '(inf-lt 0 p) (rows-at 'p)]]])
     'decls
      [['(named "uintptr_t") ['p (int-n "i0")] ['n (int-n "end")] ['m (int-n "nb")] ['i] ['k]]
       ['(named "love_limb") ['ai]]
       ['(named "dlimb") ['s] ['c]]]
     'ensures [['e1 (rows-at 'n)] (limbsR 'e2)]
     'body
      [['j0 'join 'g1 '(z p)
        [['z1 'for 'k 0 'm
          [['k1 '(inf-le k m)] ['k2 ['paths 'nat (vl 'R 'k) 0]] (limbsR 'gR1)]
          '((p0 poke R k 0))]]
        ()
        [['t1 (rows-at 'p)] (limbsR 'gR2)]]
       ['w1 'for 'i 'p 'n
        [['o1 '(inf-le i n)] ['o2 (rows-at 'i)] (limbsR 'gR3)]
        ['(s1 set ai (lc (at A i))) '(s2 set c 0)
         ['w2 'for 'k 0 'm
          [['b1 '(inf-le k m)] ['b2 ['inf-lt 'c Bt]]
           ['b3 ['paths 'nat ['add (vl 'R '(add i m)) ['mul 'c (pw '(add i k))]]
                 ['add ['mul (vl 'A 'i) (vl 'V 'm)] ['mul ['mul 'ai (vl 'V 'k)] (pw 'i)]]]]
           (limbsR 'gR4)]
          '((s3 set s (d+ (d+ (d* (dl ai) (dl (at V k))) (dl (at R (+ i k)))) c))
            (p1 poke R (+ i k) (lo s))
            (s4 set c (hi s)))]
         '(p2 poke R (+ i m) (lc c))]]]
     'macros '()
     'proofs {}}
   rows-goals (foldl (t \ c \ pin t (c 0) (c 1)) {} (spec-vcs rows0))
   rows-out
    (: (tm s) <(sound s)
       (hy m t) [(m == () ? () (tm m)) (tm (t 0)) (tm (t 1)) (tm (t 2))]
       (lid name k hs) [name (rows-goals k 2) (rows-goals k 3) hs]
       (use id) (show (ring-use id))
       B "(inf-pow L)" h "(inf-powpos L)"
       (Vl A i) "(un-val \(B) \(A) \(i))"
       (Pw i) "(uu-app \(i) \(B))"
       Xm (Vl "R" "(add i m)") K "(mul \(Vl "A" "i") \(Vl "V" "m"))" Pi (Pw "i") P (Pw "(add i k)")
       ; k < m, i < n: what an index owes
       IK "(inf-lttrans (add i k) (add i m) (add n m) (inf-ltaddl i k m w2) (inf-addr i n m (inf-ltle i n w1)))"
       nw "(inf-ltle (add n m) (inf-pow w) gnw)"
       (sk g) "(inf-lelt (succ k) (add n m) (inf-pow w) (inf-letrans (succ k) m (add n m) (inf-ltsu k m \(g)) (inf-leaddl m n)) gnw)"
       IM "(inf-ltaddr i n m w1)"
       S "(add (add (mul (A i) (V k)) (R (add i k))) c)" lo "(inf-mod \(B) \(S))" hi "(un-div \(B) \(S))"
       F3 "(un-mfit3 \(B) \(h) (A i) (V k) (R (add i k)) c (gA i) (gV k) (gR4 (add i k)) b2)"
       DV "(un-divlt \(B) \(h) \(S) \(B) \(F3))"
       (dfit x p) "(un-dfit L gL \(x) (inf-lttrans \(x) \(B) (add \(B) \(B)) \(p) (inf-leaddr \(B) \(B))))"
       ; the inner step: the low limb at i + k, the high one carried a limb up
       id1 (lid "un-rows-w2b-4" "w2b-4"
            [(hy () ["(add \(Vl "(inf-upd R (add i k) \(lo))" "(add i m)") (mul (R (add i k)) \(P)))"
                     "(add \(Xm) (mul \(lo) \(P)))"
                     "(un-valup \(B) R (add i k) \(lo) (add i m) (inf-ltaddl i k m w2))"])
             (hy P ["(add (mul \(B) \(hi)) \(lo))" S "(un-dm0 \(B) \(h) \(S))"])
             (hy () ["(add \(Xm) (mul c \(P)))" "(add \(K) (mul (mul (A i) \(Vl "V" "k")) \(Pi)))" "b3"])
             (hy hi [(Pw "(add i (succ k))") "(mul \(B) \(P))"
                     "(maponpaths nat nat (lam z (uu-app z \(B))) (add i (succ k)) (succ (add i k)) (natplusnsm i k))"])
             (hy "(mul (A i) \(Pi))" [(Vl "V" "(succ k)") "(add \(Vl "V" "k") (mul (V k) \(Pw "k")))" "(idpath \(Vl "V" "(succ k)"))"])
             (hy "(mul (A i) (V k))" [P "(mul \(Pi) \(Pw "k"))" "(un-appadd \(B) i k)"])])
       ; a row's end: its carry is the limb at i + m
       Pm (Pw "(add i m)")
       b3m "(transportf nat (lam z (paths nat (add \(Xm) (mul c (uu-app (add i z) \(B)))) (add \(K) (mul (mul (A i) \(Vl "V" "z")) \(Pi))))) k m (isantisymmnatleh k m b1 w2) b3)"
       id2 (lid "un-rows-w1b-3" "w1b-3"
            [(hy () [(Vl "(inf-upd R (add i m) c)" "(add (succ i) m)") "(add \(Xm) (mul c \(Pm)))" "(un-valst \(B) R (add i m) c)"])
             (hy () ["(add \(Xm) (mul c \(Pm)))" "(add \(K) (mul (mul (A i) \(Vl "V" "m")) \(Pi)))" b3m])
             (hy (Vl "V" "m") [(Vl "A" "(succ i)") "(add \(Vl "A" "i") (mul (A i) \(Pi)))" "(idpath \(Vl "A" "(succ i)"))"])])
       (ra z) "(paths nat \(Vl "R" "(add \(z) m)") (mul \(Vl "A" z) \(Vl "V" "m")))"
       Km (Vl "R" "k")
       w2e3 (: X "(add \(Xm) (mul 0 \(Pw "(add i 0)")))" R0 "(add \(K) (mul (mul (A i) \(Vl "V" "0")) \(Pi)))"
             "(pathscomp0 nat \(X) \(Xm) \(R0) (natplusr0 \(Xm)) (pathscomp0 nat \(Xm) \(K) \(R0) o2 (pathsinv0 nat \(R0) \(K) (pathscomp0 nat \(R0) (add \(K) 0) \(K) (maponpaths nat nat (lam z (add \(K) (mul z \(Pi)))) (mul (A i) 0) 0 (natmultn0 (A i))) (natplusr0 \(K))))))")
       rs
        [["z1e-2" "(idpath 0)"]
         ["p0-1" "(inf-lttrans k m rc z1 (inf-letrans m (add n m) rc (inf-leaddl m n) grc))"]
         ["z1b-1" (sk "z1")]
         ["z1b-3" "(pathscomp0 nat \(Vl "(inf-upd R k 0)" "(succ k)") (add \(Km) (mul 0 \(Pw "k"))) 0 (un-valst \(B) R k 0) (maponpaths nat nat (lam z (add z 0)) \(Km) 0 k2))"]
         ["z1b-4" "(un-updlt \(B) R k 0 gR1 \(h))"]
         ["j0j-1" "(transportf nat (lam z \(ra "z")) 0 p (pathsinv0 nat p 0 g1) (transportf nat (lam z (paths nat \(Vl "R" "z") 0)) k m (isantisymmnatleh k m k1 z1) k2))"]
         ["j0j-3" "(g0 g1)"]
         ["s1-2" "(gA i)"]
         ["s1-3" (dfit "(A i)" "(gA i)")]
         ["s2-1" "(inf-powpos (add L L))"]
         ["w2e-2" h]
         ["w2e-3" w2e3]
         ["s3-2" "(un-bbfit L (mul (A i) (V k)) (inf-lelt (mul (A i) (V k)) (add (mul (A i) (V k)) 0) (mul \(B) \(B)) (inf-leaddr (mul (A i) (V k)) 0) (un-mfit \(B) (A i) (V k) 0 (gA i) (gV k) \(h))))"]
         ["s3-3" "(inf-lttrans (add i k) (add n m) (inf-pow w) \(IK) \(nw))"]
         ["s3-4" "(inf-lttrans (add i k) (add n m) rc \(IK) grc)"]
         ["s3-5" "(un-bbfit L (add (mul (A i) (V k)) (R (add i k))) (un-mfit \(B) (A i) (V k) (R (add i k)) (gA i) (gV k) (gR4 (add i k))))"]
         ["s3-6" "(un-bbfit L \(S) \(F3))"]
         ["p1-1" "(inf-lttrans (add i k) (add n m) (inf-pow w) \(IK) \(nw))"]
         ["p1-2" "(inf-lttrans (add i k) (add n m) rc \(IK) grc)"]
         ["s4-1" (dfit hi DV)]
         ["w2b-1" (sk "w2")]
         ["w2b-3" DV]
         ["w2b-4" (use id1)]
         ["w2b-5" "(un-updlt \(B) R (add i k) \(lo) gR4 (un-modlt0 \(B) \(h) \(S)))"]
         ["p2-1" "(inf-lttrans (add i m) (add n m) (inf-pow w) \(IM) \(nw))"]
         ["p2-2" "(inf-lttrans (add i m) (add n m) rc \(IM) grc)"]
         ["w1b-3" (use id2)]
         ["w1b-4" "(un-updlt \(B) R (add i m) c gR4 b2)"]
         ["end-1" "(transportf nat (lam z \(ra "z")) i n (isantisymmnatleh i n o1 w1) o2)"]]
     [(foldl (t \ r \ pin t (r 0) (tm (r 1))) {} rs) [id1 id2]])
   rows (pin rows0 'proofs (rows-out 0))

   ; --- r += s at limb off, r sized for the whole sum, so the carry settles inside it ----------
   offT ['add (vl 'R0 'n) ['mul (vl 'S 'm) (pw 'o)]]
   offs0
    {'name "mag_add_off" 'short "maoff"
     'attrs '("static")
     'ret 'void
     'params '(("r" (ptr (named "love_limb"))) ("rn" int) ("s" (ptr (const (named "love_limb")))) ("sn" int) ("off" int))
     'fields ()
     'limb 'L
     'vals '(R)
     'dvars '(t c)
     'arrays '((R (v "r") n) (S (v "s") m))
     'requires
      (['(R (pi j nat nat)) '(R0 (pi j nat nat)) '(S (pi j nat nat)) '(n nat) '(m nat) '(o nat)]
       + limb-req
       + ['(gom (inf-le (add o m) n)) '(gnw (inf-lt n (inf-pow w))) (limbs 'R) (limbs 'S)
          '(g0 (pi j nat (paths nat (R j) (R0 j)))) ['gf ['inf-lt offT (pw 'n)]]])
     'decls
      [['(named "uintptr_t") ['n (int-n "rn")] ['m (int-n "sn")] ['o (int-n "off")] ['i]]
       ['(named "dlimb") ['t] ['c]]]
     'ensures [['e1 ['paths 'nat (vl 'R 'n) offT]] (limbsR 'e2)]
     'body
      ['(s0 set c 0)
       ['w1 'for 'i 0 'm
        [['a1 '(inf-le i m)] ['a2 '(inf-le c 1)]
         ['a3 ['paths 'nat ['add (vl 'R 'n) ['mul 'c (pw '(add o i))]] ['add (vl 'R0 'n) ['mul (vl 'S 'i) (pw 'o)]]]]
         (limbsR 'gR1)]
        '((s1 set t (d+ (d+ (dl (at R (+ o i))) (dl (at S i))) c))
          (p1 poke R (+ o i) (lo t))
          (s2 set c (hi t)))]
       ; the carry runs up while it lasts; gf says it is gone by r's end
       ['w2 'while '(lt (+ o i) n) '(natminus n i)
        [['b1 '(inf-le (add o i) n)] ['b2 '(inf-le c 1)]
         ['b3 ['paths 'nat ['add (vl 'R 'n) ['mul 'c (pw '(add o i))]] offT]] (limbsR 'gR2)]
        '((j1 join g1 (z c) ((x1 brk)) () ())
          (s3 set t (d+ (dl (at R (+ o i))) c))
          (p2 poke R (+ o i) (lo t))
          (s4 set c (hi t))
          (s5 set i (+ i 1)))]]
     'macros '()
     'proofs {}}
   offs-goals (foldl (t \ c \ pin t (c 0) (c 1)) {} (spec-vcs offs0))
   offs-out
    (: (tm s) <(sound s)
       (hy m t) [(m == () ? () (tm m)) (tm (t 0)) (tm (t 1)) (tm (t 2))]
       (lid name k hs) [name (offs-goals k 2) (offs-goals k 3) hs]
       (use id) (show (ring-use id))
       B "(inf-pow L)" h "(inf-powpos L)"
       (Vl A i) "(un-val \(B) \(A) \(i))"
       (Pw i) "(uu-app \(i) \(B))"
       Rn (Vl "R" "n") R0n (Vl "R0" "n") P (Pw "(add o i)") Po (Pw "o") Ro "(R (add o i))"
       T "(add \(R0n) (mul \(Vl "S" "m") \(Po)))"
       OI "(inf-lttrans (add o i) (add o m) n (inf-ltaddl o i m w1) gom)"
       IL "(inf-lelt i (add o i) n (inf-leaddl i o) w2)"
       E1 "(isantisymmnatleh i m a1 w1)"
       T1 "(add (add \(Ro) (S i)) c)" lo1 "(inf-mod \(B) \(T1))" hi1 "(un-div \(B) \(T1))"
       CY1 "(un-carry1 \(B) \(h) \(T1) (un-sum3lt \(B) \(Ro) (S i) c (gR1 (add o i)) (gS i) a2))"
       T2 "(add \(Ro) c)" lo2 "(inf-mod \(B) \(T2))" hi2 "(un-div \(B) \(T2))"
       CY2 "(un-carry1 \(B) \(h) \(T2) (un-sum2lt \(B) \(h) \(Ro) c (gR2 (add o i)) b2))"
       (valup lo lt) (hy () ["(add \(Vl "(inf-upd R (add o i) \(lo))" "n") (mul \(Ro) \(P)))" "(add \(Rn) (mul \(lo) \(P)))"
                             "(un-valup \(B) R (add o i) \(lo) n \(lt))"])
       (dm hi lo t) (hy P ["(add (mul \(B) \(hi)) \(lo))" t "(un-dm0 \(B) \(h) \(t))"])
       ; the first loop: s's limb and the carry at o + i
       id1 (lid "un-offs-w1b-4" "w1b-4"
            [(valup lo1 OI) (dm hi1 lo1 T1)
             (hy () ["(add \(Rn) (mul c \(P)))" "(add \(R0n) (mul \(Vl "S" "i") \(Po)))" "a3"])
             (hy hi1 [(Pw "(add o (succ i))") "(mul \(B) \(P))"
                      "(maponpaths nat nat (lam z (uu-app z \(B))) (add o (succ i)) (succ (add o i)) (natplusnsm o i))"])
             (hy Po [(Vl "S" "(succ i)") "(add \(Vl "S" "i") (mul (S i) \(Pw "i")))" "(idpath \(Vl "S" "(succ i)"))"])
             (hy "(S i)" [P "(mul \(Po) \(Pw "i"))" "(un-appadd \(B) o i)"])])
       ; the second: the carry alone
       Ei "(pathscomp0 nat (add o (add i 1)) (add o (succ i)) (succ (add o i)) (maponpaths nat nat (lam z (add o z)) (add i 1) (succ i) (un-add1 i)) (natplusnsm o i))"
       id2 (lid "un-offs-w2b-3" "w2b-3"
            [(valup lo2 "w2") (dm hi2 lo2 T2)
             (hy () ["(add \(Rn) (mul c \(P)))" T "b3"])
             (hy hi2 [(Pw "(add o (add i 1))") "(mul \(B) \(P))" "(maponpaths nat nat (lam z (uu-app z \(B))) (add o (add i 1)) (succ (add o i)) \(Ei))"])])
       rs
        [["s0-1" "(inf-powpos (add L L))"]
         ["w1e-3" "(maponpaths nat nat (lam z (add z 0)) \(Rn) \(R0n) (un-valcong \(B) R R0 n g0))"]
         ["s1-1" "(inf-lttrans (add o i) n (inf-pow w) \(OI) (inf-ltle n (inf-pow w) gnw))"]
         ["s1-2" OI]
         ["s1-4" "(un-dfit L gL (add \(Ro) (S i)) (un-sum2llt \(B) \(Ro) (S i) (gR1 (add o i)) (gS i)))"]
         ["s1-5" "(un-dfit L gL \(T1) (un-sum3lt \(B) \(Ro) (S i) c (gR1 (add o i)) (gS i) a2))"]
         ["p1-1" "(inf-lttrans (add o i) n (inf-pow w) \(OI) (inf-ltle n (inf-pow w) gnw))"]
         ["p1-2" OI]
         ["s2-1" "(un-cfit L gL \(hi1) \(CY1))"]
         ["w1b-1" "(inf-lelt (succ i) n (inf-pow w) (inf-letrans (succ i) m n (inf-ltsu i m w1) (inf-letrans m (add o m) n (inf-leaddl m o) gom)) gnw)"]
         ["w1b-3" CY1]
         ["w1b-4" (use id1)]
         ["w1b-5" "(un-updlt \(B) R (add o i) \(lo1) gR1 (un-modlt0 \(B) \(h) \(T1)))"]
         ["w2e-1" "(transportf nat (lam z (inf-le (add o z) n)) m i (pathsinv0 nat i m \(E1)) gom)"]
         ["w2e-3" "(transportf nat (lam z (paths nat (add \(Rn) (mul c \(P))) (add \(R0n) (mul \(Vl "S" "z") \(Po))))) i m \(E1) a3)"]
         ; a break: the carry is 0
         ["end-1" "(pathscomp0 nat \(Rn) (add \(Rn) (mul c \(P))) \(T) (pathsinv0 nat (add \(Rn) (mul c \(P))) \(Rn) (pathscomp0 nat (add \(Rn) (mul c \(P))) (add \(Rn) 0) \(Rn) (maponpaths nat nat (lam z (add \(Rn) (mul z \(P)))) c 0 g1) (natplusr0 \(Rn)))) b3)"]
         ["s3-3" "(un-dfit L gL \(T2) (un-sum2lt \(B) \(h) \(Ro) c (gR2 (add o i)) b2))"]
         ["s4-1" "(un-cfit L gL \(hi2) \(CY2))"]
         ["s5-1" "(inf-lelt (add i 1) n (inf-pow w) (transportf nat (lam z (inf-le z n)) (succ i) (add i 1) (pathsinv0 nat (add i 1) (succ i) (un-add1 i)) (inf-ltsu i n \(IL))) gnw)"]
         ["w2b-1" "(transportf nat (lam z (inf-le z n)) (succ (add o i)) (add o (add i 1)) (pathsinv0 nat (add o (add i 1)) (succ (add o i)) \(Ei)) (inf-ltsu (add o i) n w2))"]
         ["w2b-2" CY2]
         ["w2b-3" (use id2)]
         ["w2b-4" "(un-updlt \(B) R (add o i) \(lo2) gR2 (un-modlt0 \(B) \(h) \(T2)))"]
         ["w2b-5" "(inf-subfall1 n i \(IL))"]
         ; r's end: what still carries would be B^n, past gf
         ["end-3" "(un-czero \(Rn) c \(Pw "n") \(T) (transportf nat (lam z (paths nat (add \(Rn) (mul c (uu-app z \(B)))) \(T))) (add o i) n (isantisymmnatleh (add o i) n b1 w2) b3) gf)"]]
     [(foldl (t \ r \ pin t (r 0) (tm (r 1))) {} rs) [id1 id2]])
   offs (pin offs0 'proofs (offs-out 0))

   ; --- a >= b as values, na >= nb: 1 or 0 -------------------------------------------------------
   ge
    {'name "mag_ge" 'short "mge"
     'attrs '("static" "love_inline")
     'ret 'int
     'params '(("a" (ptr (const (named "love_limb")))) ("na" int) ("b" (ptr (const (named "love_limb")))) ("nb" int))
     'fields ()
     'limb 'L
     'arrays '((A (v "a") n) (V (v "b") m))
     'requires
      (['(A (pi j nat nat)) '(V (pi j nat nat)) '(n nat) '(m nat)]
       + limb-req
       + ['(gm (inf-le m n)) '(gn (inf-lt n (inf-pow w))) (limbs 'A) (limbs 'V)])
     'decls
      [['(named "uintptr_t") ['n (int-n "na")] ['m (int-n "nb")] ['i]]]
     'ensures
      [['e1 '(inf-le res 1)]
       ['e2 ['pi 'g '(paths nat res 1) ['inf-le (vl 'V 'm) (vl 'A 'n)]]]
       ['e3 ['pi 'g '(paths nat res 0) ['inf-lt (vl 'A 'n) (vl 'V 'm)]]]]
     'body
      [['s0 'set 'i 'n]
       ['w1 'while '(lt m i) 'i
        [['a1 '(inf-le m i)] ['a2 '(inf-le i n)] ['a3 ['paths 'nat (vl 'A 'n) (vl 'A 'i)]]]
        [['s1 'set 'i '(- i 1)]
         ['j1 'join 'g1 '(nz (at A i)) '((r1 ret 1)) () [['t1 '(paths nat (A i) 0)]]]]]
       ['w2 'while '(lt 0 i) 'i
        [['b1 '(inf-le i m)] ['b2 ['paths 'nat ['add (vl 'A 'n) (vl 'V 'i)] ['add (vl 'V 'm) (vl 'A 'i)]]] ['b3 '(inf-le i n)]]
        [['s2 'set 'i '(- i 1)]
         ['j2 'join 'g2 '(dif (at A i) (at V i)) '((j3 ife g3 (lt (at V i) (at A i)) ((r2 ret 1)) ((r3 ret 0)))) ()
          [['t2 '(paths nat (A i) (V i))]]]]]
       '(r4 ret 1)]
     'macros '()
     'proofs
      {
       "w1e-3" '(idpath (un-val (inf-pow L) A n))
       "s1-1" '(inf-ltsu 0 i (inf-lelt 0 m i (idpath false) w1))
       "j1-1" '(inf-lttrans (natminus i 1) i n (un-predlt i (inf-ltsu 0 i (inf-lelt 0 m i (idpath false) w1))) a2)
       "r1-2" '(lam g (inf-ltle (un-val (inf-pow L) V m) (un-val (inf-pow L) A n) (inf-lttrans (un-val (inf-pow L) V m) (uu-app m (inf-pow L)) (un-val (inf-pow L) A n) (un-vallt (inf-pow L) V m gV) (inf-letrans (uu-app m (inf-pow L)) (uu-app (natminus i 1) (inf-pow L)) (un-val (inf-pow L) A n) (un-appmono (inf-pow L) (inf-powpos L) m (natminus i 1) (inf-ltsle m (natminus i 1) (transportf nat (lam z (inf-lt m z)) i (succ (natminus i 1)) (pathsinv0 nat (succ (natminus i 1)) i (inf-addsub 1 i (inf-ltsu 0 i (inf-lelt 0 m i (idpath false) w1)))) w1))) (inf-letl (uu-app (natminus i 1) (inf-pow L)) (un-val (inf-pow L) A i) (un-val (inf-pow L) A n) (pathsinv0 nat (un-val (inf-pow L) A n) (un-val (inf-pow L) A i) a3) (transportf nat (lam z (inf-le (uu-app (natminus i 1) (inf-pow L)) (un-val (inf-pow L) A z))) (succ (natminus i 1)) i (inf-addsub 1 i (inf-ltsu 0 i (inf-lelt 0 m i (idpath false) w1))) (un-valge1 (inf-pow L) A (natminus i 1) g1)))))))
       "r1-3" '(lam g (un-10 (inf-lt (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)) g))
       "w1b-1" '(inf-ltsle m (natminus i 1) (transportf nat (lam z (inf-lt m z)) i (succ (natminus i 1)) (pathsinv0 nat (succ (natminus i 1)) i (inf-addsub 1 i (inf-ltsu 0 i (inf-lelt 0 m i (idpath false) w1)))) w1))
       "w1b-3" '(pathscomp0 nat (un-val (inf-pow L) A n) (un-val (inf-pow L) A i) (un-val (inf-pow L) A (natminus i 1)) a3 (pathscomp0 nat (un-val (inf-pow L) A i) (add (un-val (inf-pow L) A (natminus i 1)) (mul (A (natminus i 1)) (uu-app (natminus i 1) (inf-pow L)))) (un-val (inf-pow L) A (natminus i 1)) (maponpaths nat nat (lam z (un-val (inf-pow L) A z)) i (succ (natminus i 1)) (pathsinv0 nat (succ (natminus i 1)) i (inf-addsub 1 i (inf-ltsu 0 i (inf-lelt 0 m i (idpath false) w1))))) (pathscomp0 nat (add (un-val (inf-pow L) A (natminus i 1)) (mul (A (natminus i 1)) (uu-app (natminus i 1) (inf-pow L)))) (add (un-val (inf-pow L) A (natminus i 1)) 0) (un-val (inf-pow L) A (natminus i 1)) (maponpaths nat nat (lam z (add (un-val (inf-pow L) A (natminus i 1)) (mul z (uu-app (natminus i 1) (inf-pow L))))) (A (natminus i 1)) 0 t1) (natplusr0 (un-val (inf-pow L) A (natminus i 1))))))
       "w1b-4" '(un-predlt i (inf-ltsu 0 i (inf-lelt 0 m i (idpath false) w1)))
       "w2e-2" '(transportf nat (lam z (paths nat (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V z)) (add (un-val (inf-pow L) V m) (un-val (inf-pow L) A i)))) m i (pathsinv0 nat i m (isantisymmnatleh i m w1 a1)) (pathscomp0 nat (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)) (add (un-val (inf-pow L) V m) (un-val (inf-pow L) A n)) (add (un-val (inf-pow L) V m) (un-val (inf-pow L) A i)) (natpluscomm (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)) (maponpaths nat nat (lam z (add (un-val (inf-pow L) V m) z)) (un-val (inf-pow L) A n) (un-val (inf-pow L) A i) a3)))
       "s2-1" '(inf-ltsu 0 i w2)
       "j2-1" '(inf-lttrans (natminus i 1) i n (un-predlt i (inf-ltsu 0 i w2)) (inf-letrans i m n b1 gm))
       "j2-2" '(inf-lttrans (natminus i 1) i m (un-predlt i (inf-ltsu 0 i w2)) b1)
       "j3-1" '(inf-lttrans (natminus i 1) i m (un-predlt i (inf-ltsu 0 i w2)) b1)
       "j3-2" '(inf-lttrans (natminus i 1) i n (un-predlt i (inf-ltsu 0 i w2)) (inf-letrans i m n b1 gm))
       "r2-2" '(lam g (inf-ltle (un-val (inf-pow L) V m) (un-val (inf-pow L) A n) (un-cancle (un-val (inf-pow L) A n) (un-val (inf-pow L) V m) (un-val (inf-pow L) V i) (un-val (inf-pow L) A i) b2 (transportf nat (lam z (inf-lt (un-val (inf-pow L) V z) (un-val (inf-pow L) A z))) (succ (natminus i 1)) i (inf-addsub 1 i (inf-ltsu 0 i w2)) (un-lexlt (inf-pow L) A V (natminus i 1) gV g3)))))
       "r2-3" '(lam g (un-10 (inf-lt (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)) g))
       "r3-2" '(lam g (un-01 (inf-le (un-val (inf-pow L) V m) (un-val (inf-pow L) A n)) g))
       "r3-3" '(lam g (un-cancle (un-val (inf-pow L) V m) (un-val (inf-pow L) A n) (un-val (inf-pow L) A i) (un-val (inf-pow L) V i) (pathsinv0 nat (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V i)) (add (un-val (inf-pow L) V m) (un-val (inf-pow L) A i)) b2) (transportf nat (lam z (inf-lt (un-val (inf-pow L) A z) (un-val (inf-pow L) V z))) (succ (natminus i 1)) i (inf-addsub 1 i (inf-ltsu 0 i w2)) (un-lexlt (inf-pow L) V A (natminus i 1) gA (un-lene (A (natminus i 1)) (V (natminus i 1)) g3 g2)))))
       "w2b-2" '(un-cancmid (un-val (inf-pow L) A n) (un-val (inf-pow L) V (natminus i 1)) (un-val (inf-pow L) V m) (un-val (inf-pow L) A (natminus i 1)) (mul (V (natminus i 1)) (uu-app (natminus i 1) (inf-pow L))) (pathscomp0 nat (add (un-val (inf-pow L) A n) (add (un-val (inf-pow L) V (natminus i 1)) (mul (V (natminus i 1)) (uu-app (natminus i 1) (inf-pow L))))) (add (un-val (inf-pow L) V m) (add (un-val (inf-pow L) A (natminus i 1)) (mul (A (natminus i 1)) (uu-app (natminus i 1) (inf-pow L))))) (add (un-val (inf-pow L) V m) (add (un-val (inf-pow L) A (natminus i 1)) (mul (V (natminus i 1)) (uu-app (natminus i 1) (inf-pow L))))) (transportf nat (lam z (paths nat (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V z)) (add (un-val (inf-pow L) V m) (un-val (inf-pow L) A z)))) i (succ (natminus i 1)) (pathsinv0 nat (succ (natminus i 1)) i (inf-addsub 1 i (inf-ltsu 0 i w2))) b2) (maponpaths nat nat (lam z (add (un-val (inf-pow L) V m) (add (un-val (inf-pow L) A (natminus i 1)) (mul z (uu-app (natminus i 1) (inf-pow L)))))) (A (natminus i 1)) (V (natminus i 1)) t2)))
       "w2b-4" '(un-predlt i (inf-ltsu 0 i w2))
       "r4-2" '(lam g (inf-eqle (un-val (inf-pow L) V m) (un-val (inf-pow L) A n) (pathscomp0 nat (un-val (inf-pow L) V m) (add (un-val (inf-pow L) V m) 0) (un-val (inf-pow L) A n) (pathsinv0 nat (add (un-val (inf-pow L) V m) 0) (un-val (inf-pow L) V m) (natplusr0 (un-val (inf-pow L) V m))) (pathscomp0 nat (add (un-val (inf-pow L) V m) 0) (add (un-val (inf-pow L) A n) 0) (un-val (inf-pow L) A n) (pathsinv0 nat (add (un-val (inf-pow L) A n) 0) (add (un-val (inf-pow L) V m) 0) (transportf nat (lam z (paths nat (add (un-val (inf-pow L) A n) (un-val (inf-pow L) V z)) (add (un-val (inf-pow L) V m) (un-val (inf-pow L) A z)))) i 0 (isantisymmnatleh i 0 w2 (idpath false)) b2)) (natplusr0 (un-val (inf-pow L) A n))))))
       "r4-3" '(lam g (un-10 (inf-lt (un-val (inf-pow L) A n) (un-val (inf-pow L) V m)) g))
      }}

   ; --- one quotient limb of knuth's D: the window w[0..n] over vn, q from mag_qhat. q too big adds
   ;     back, q too small subtracts again, so u = q v + r and r < v whatever mag_qhat answers ---
   (wv W) (vl W '(add n 1))
   limbsW '(gW (pi j nat (inf-lt (W j) (inf-pow L))))
   (limbs3 g) [g '(pi j nat (inf-lt (W j) (inf-pow L)))]
   divstep0
    {'name "mag_divstep" 'short "mdiv"
     'attrs '("static" "love_inline")
     'ret '(named "love_limb")
     'params '(("w" (ptr (named "love_limb"))) ("vn" (ptr (const (named "love_limb")))) ("nn" int))
     'fields ()
     'limb 'L
     'vals '(W)
     'dvars '(s t c b)
     'calls [ge]
     'arrays '((W (v "w") wc) (V (v "vn") n))
     'requires
      (['(W (pi j nat nat)) '(W0 (pi j nat nat)) '(V (pi j nat nat)) '(n nat) '(wc nat)]
       + limb-req
       + ['(gLw (inf-le L w)) '(gwc (inf-le (add n 1) wc)) '(gn (inf-lt (add n 1) (inf-pow w))) (limbs 'W0) (limbs 'V)
          '(g0 (pi j nat (paths nat (W j) (W0 j)))) ['gv ['inf-lt 0 (vl 'V 'n)]]
          ['gu ['inf-lt (wv 'W0) ['mul Bt (vl 'V 'n)]]]])
     'decls
      [['(named "uintptr_t") ['n (int-n "nn")] ['i]]
       ['(named "love_limb") ['q]]
       ['(named "dlimb") ['s] ['t] ['c] ['b]]
       ['int ['x]]]
     'ensures
      [['e1 ['inf-lt 'res Bt]]
       ['e2 ['paths 'nat ['add (wv 'W) ['mul 'res (vl 'V 'n)]] (wv 'W0)]]
       ['e3 ['inf-lt (wv 'W) (vl 'V 'n)]]]
     'body
      [['h0 'havl 'q '(raw (call (var "mag_qhat") ((var "w") (var "vn") (var "nn")))) 'gq]
       '(s0 set i 0) '(s1 set c 0) '(s2 set b 0)
       ; w -= q v: c the product's carry, b the borrow
       ['w1 'while '(lt i n) '(natminus n i)
        [['a1 '(inf-le i n)] ['a2 ['inf-lt 'c Bt]] ['a3 '(inf-le b 1)]
         ['a4 ['paths 'nat ['add (wv 'W) ['mul 'q (vl 'V 'i)]] ['add (wv 'W0) ['mul '(add b c) (pw 'i)]]]]
         ['a5 '(pi j nat (pi g (inf-le i j) (paths nat (W j) (W0 j))))] limbsW]
        '((m1 set s (d+ (d* (dl q) (dl (at V i))) c))
          (m2 set t (- (d+ (dl (at W i)) (lB)) (d+ (dl (lo s)) b)))
          (p1 poke W i (lo t))
          (m3 set b (- 1 (hi t)))
          (m4 set c (hi s))
          (m5 set i (+ i 1)))]
       '(m6 set t (- (d+ (dl (at W n)) (lB)) (d+ c b)))
       '(p2 poke W n (lo t))
       '(m7 set b (- 1 (hi t)))
       ; while it borrows, q was too big: add v back
       ['w2 'while '(nz b) 'q
        [['d1 '(inf-le b 1)] ['d2 ['paths 'nat ['add (wv 'W) ['mul 'q (vl 'V 'n)]] ['add (wv 'W0) ['mul 'b (pw '(add n 1))]]]]
         limbsW ['d4 ['inf-lt 'q Bt]]]
        [['u0 'ghost 'u (wv 'W) 'gu0]
         ; what the inner loop needs of w, said of u, since it takes w's name
         ['v0 'have 'gd ['paths 'nat ['add 'u ['mul 'q (vl 'V 'n)]] ['add (wv 'W0) ['mul 'b (pw '(add n 1))]]]]
         ['v1 'have 'gul ['inf-lt 'u (pw '(add n 1))]]
         '(s3 set i 0) '(s4 set c 0)
         ['w3 'while '(lt i n) '(natminus n i)
          [['k1 '(inf-le i n)] ['k2 '(inf-le c 1)]
           ['k3 ['paths 'nat ['add (wv 'W) ['mul 'c (pw 'i)]] ['add 'u (vl 'V 'i)]]] (limbs3 'gW3)]
          '((s5 set s (d+ (d+ (dl (at W i)) (dl (at V i))) c))
            (p3 poke W i (lo s))
            (s6 set c (hi s))
            (s7 set i (+ i 1)))]
         '(s8 set t (d+ (dl (at W n)) c))
         '(p4 poke W n (lo t))
         '(s9 set b (- b (hi t)))
         '(s10 set q (- q 1))]]
       ; while r >= v, q was too small: take v again
       ['w4 'while '(tru) ['natminus Bt 'q]
        [['f1 ['paths 'nat ['add (wv 'W) ['mul 'q (vl 'V 'n)]] (wv 'W0)]] limbsW ['f3 ['inf-lt 'q Bt]]]
        [['c1 'calx 'x "mag_ge" '((raw (var "w")) (raw (bin + (var "nn") (num 1))) (raw (var "vn")) (raw (var "nn")))
          '((A W) V (n (add n 1)) (m n) L w) ()]
         ['j5 'join 'g5 '(z x) '((b1 brk)) () [['k9 ['inf-le (vl 'V 'n) (wv 'W)]]]]
         ['u1 'ghost 'u (wv 'W) 'gu1]
         ['v2 'have 'gf ['paths 'nat ['add 'u ['mul 'q (vl 'V 'n)]] (wv 'W0)]]
         ['v3 'have 'gk ['inf-le (vl 'V 'n) 'u]]
         '(s11 set i 0) '(s12 set b 0)
         ['w5 'while '(lt i n) '(natminus n i)
          [['h1 '(inf-le i n)] ['h2 '(inf-le b 1)]
           ['h3 ['paths 'nat ['add (wv 'W) (vl 'V 'i)] ['add 'u ['mul 'b (pw 'i)]]]] (limbs3 'gW5)]
          '((s13 set t (- (d+ (dl (at W i)) (lB)) (d+ (dl (at V i)) b)))
            (p5 poke W i (lo t))
            (s14 set b (- 1 (hi t)))
            (s15 set i (+ i 1)))]
         '(s16 set t (- (d+ (dl (at W n)) (lB)) b))
         '(p6 poke W n (lo t))
         '(s17 set q (lc (+ q 1)))]]
       '(r1 ret q)]
     'macros '()
     'proofs
      {}}

   ; --- divstep's proofs: templates over its names, its goals read back from divstep0. a step that
   ;     only regroups is a ring identity, laid once as a lemma over its atoms ----------------------
   ds-goals (foldl (t \ c \ pin t (c 0) (c 1)) {} (spec-vcs divstep0))
   ds-out
    (: (tm s) <(sound s)
       (hy m t) [(m == () ? () (tm m)) (tm (t 0)) (tm (t 1)) (tm (t 2))]
       (lid name k hs) [name (ds-goals k 2) (ds-goals k 3) hs]
       (use id) (show (ring-use id))
       B "(inf-pow L)" h "(inf-powpos L)" B2 "(add \(B) \(B))"
       (VW W) "(un-val \(B) \(W) (add n 1))"
       (Vv i) "(un-val \(B) V \(i))"
       (Pw i) "(uu-app \(i) \(B))"
       (upd W i x) "(inf-upd \(W) \(i) \(x))"
       (md x) "(inf-mod \(B) \(x))"
       Wv (VW "W") W0v (VW "W0") Vn (Vv "n") Vi (Vv "i") Vz (Vv "z")
       Pi (Pw "i") Pn (Pw "n") Pz (Pw "z") P1 (Pw "(add n 1)")
       ; i < wc from the loop's exit ex : i < n
       (wlt i ex) "(inf-lttrans \(i) n wc \(ex) (inf-letrans n (add n 1) wc (inf-leaddr n 1) gwc))"
       nwc "(inf-lttrans n (add n 1) wc (un-ltp1 n) gwc)"
       (dfit x p) "(un-dfit L gL \(x) \(p))"
       (ltAB Wi g) "(inf-ltaddr \(Wi) \(B) \(B) \(g))"
       ; natminus (Wi + B) sub < B + B
       (Tlt T Wi sub g) "(inf-lelt \(T) (add \(Wi) \(B)) \(B2) (inf-suble (add \(Wi) \(B)) \(sub)) \(ltAB Wi g))"
       (carry1 x p) "(un-carry1 \(B) \(h) \(x) \(p))"
       (nm1 x) "(natminus 1 (un-div \(B) \(x)))"
       (cfit1 x) "(un-cfit L gL \(nm1 x) (inf-suble 1 (un-div \(B) \(x))))"
       ; the facts a lemma takes, each [lhs rhs proof]
       (sval A i) ["(un-val \(B) \(A) (add \(i) 1))" "(add (un-val \(B) \(A) \(i)) (mul (\(A) \(i)) \(Pw i)))"
                   "(maponpaths nat nat (lam z (un-val \(B) \(A) z)) (add \(i) 1) (succ \(i)) (un-add1 \(i)))"]
       (spw i) [(Pw "(add \(i) 1)") "(mul \(B) \(Pw i))"
                "(maponpaths nat nat (lam z (uu-app z \(B))) (add \(i) 1) (succ \(i)) (un-add1 \(i)))"]
       (valup W i x lt) ["(add \(VW (upd W i x)) (mul (\(W) \(i)) \(Pw i)))" "(add \(VW W) (mul \(x) \(Pw i)))"
                         "(un-valup \(B) \(W) \(i) \(x) (add n 1) \(lt))"]
       (bdig a u s k g) ["(add \(u) \(md s))" "(add \(a) (mul \(nm1 s) \(B)))"
                         "(un-bdig \(B) \(h) \(a) \(u) \(s) (inf-addsub \(u) (add \(a) \(B)) \(k)) \(g))"]
       (dm s) ["(add (mul \(B) (un-div \(B) \(s))) \(md s))" s "(un-dm0 \(B) \(h) \(s))"]
       ; a statement in i carried to n
       (tr mot p e) "(transportf nat (lam z \(mot)) i n \(e) \(p))"
       (updlt W i x g s) "(un-updlt \(B) \(W) \(i) \(x) \(g) (un-modlt0 \(B) \(h) \(s)))"
       (at ks p) (map (k \ [k p]) ks)

       ; entry: q 0 = 0, W = W0
       valc "(un-valcong \(B) W W0 (add n 1) g0)"
       ; w1: w -= q v
       S1 "(add (mul qh0 (V i)) c)" LS (md S1) T1 "(natminus (add (W i) \(B)) (add \(LS) b))" mT1 (md T1)
       MF "(un-mfit \(B) qh0 (V i) c gq (gV i) a2)"
       K1 "(inf-letrans (add \(LS) b) \(B) (add (W i) \(B)) (un-vcle \(B) \(LS) b (un-modlt0 \(B) \(h) \(S1)) a3) (inf-leaddl \(B) (W i)))"
       T1lt (Tlt T1 "(W i)" "(add \(LS) b)" "(gW i)")
       G1 (carry1 T1 T1lt)
       DV "(un-divlt \(B) \(h) \(S1) \(B) \(MF))"
       id1 (lid "un-ds-w1b-4" "w1b-4"
            [(hy () (valup "W" "i" mT1 "(inf-lttrans i n (add n 1) w1 (inf-leaddr n 1))"))
             (hy () ["(add \(Wv) (mul qh0 \(Vi)))" "(add \(W0v) (mul (add b c) \(Pi)))" "a4"])
             (hy Pi (bdig "(W i)" "(add \(LS) b)" T1 K1 G1))
             (hy Pi (dm S1))
             (hy "qh0" (sval "V" "i"))
             (hy "(add \(nm1 T1) (un-div \(B) \(S1)))" (spw "i"))])
       ; the top limb after w1
       E1 "(isantisymmnatleh i n a1 w1)"
       T6 "(natminus (add (W n) \(B)) (add c b))" mT6 (md T6)
       K6 "(inf-letrans (add c b) \(B) (add (W n) \(B)) (un-vcle \(B) c b a2 a3) (inf-leaddl \(B) (W n)))"
       T6lt (Tlt T6 "(W n)" "(add c b)" "(gW n)")
       G6 (carry1 T6 T6lt)
       a4n (tr "(paths nat (add \(Wv) (mul qh0 \(Vz))) (add \(W0v) (mul (add b c) \(Pz))))" "a4" E1)
       id2 (lid "un-ds-w2e-2" "w2e-2"
            [(hy () (valup "W" "n" mT6 "(un-ltp1 n)"))
             (hy () ["(add \(Wv) (mul qh0 \(Vn)))" "(add \(W0v) (mul (add b c) \(Pn)))" a4n])
             (hy Pn (bdig "(W n)" "(add c b)" T6 K6 G6))
             (hy (nm1 T6) (spw "n"))])
       ; w3: add v back
       S5 "(add (add (W i) (V i)) c)" mS5 (md S5)
       S5lt "(un-sum3lt \(B) (W i) (V i) c (gW3 i) (gV i) k2)"
       id3 (lid "un-ds-w3b-3" "w3b-3"
            [(hy () (valup "W" "i" mS5 "(inf-lttrans i n (add n 1) w3 (inf-leaddr n 1))"))
             (hy () ["(add \(Wv) (mul c \(Pi)))" "(add u \(Vi))" "k3"])
             (hy Pi (dm S5))
             (hy () (sval "V" "i"))
             (hy "(un-div \(B) \(S5))" (spw "i"))])
       ; the add-back's top, q - 1
       T8 "(add (W n) c)" mT8 (md T8) E3 "(isantisymmnatleh i n k1 w3)"
       T8lt "(un-sum2lt \(B) \(h) (W n) c (gW3 n) k2)"
       hi8 "(un-div \(B) \(T8))"
       HI8 "(inf-letrans \(hi8) 1 b \(carry1 T8 T8lt) (inf-ltsu 0 b w2))"
       Q1 "(un-qpos \(P1) u q \(Vn) \(W0v) b gd gul w2)"
       k3n (tr "(paths nat (add \(Wv) (mul c \(Pz))) (add u \(Vz)))" "k3" E3)
       id4 (lid "un-ds-w2b-2" "w2b-2"
            [(hy () (valup "W" "n" mT8 "(un-ltp1 n)"))
             (hy () ["(add \(Wv) (mul c \(Pn)))" "(add u \(Vn))" k3n])
             (hy Pn (dm T8))
             (hy () ["(add u (mul q \(Vn)))" "(add \(W0v) (mul b \(P1)))" "gd"])
             (hy Vn ["(add 1 (natminus q 1))" "q" "(inf-addsub 1 q \(Q1))"])
             (hy "(mul \(B) \(Pn))" ["(add \(hi8) (natminus b \(hi8)))" "b" "(inf-addsub \(hi8) b \(HI8))"])
             (hy "(natminus b \(hi8))" (spw "n"))
             (hy "b" (spw "n"))])
       ; w5: take v again
       T13 "(natminus (add (W i) \(B)) (add (V i) b))" mT13 (md T13)
       K13 "(inf-letrans (add (V i) b) \(B) (add (W i) \(B)) (un-vcle \(B) (V i) b (gV i) h2) (inf-leaddl \(B) (W i)))"
       T13lt (Tlt T13 "(W i)" "(add (V i) b)" "(gW5 i)")
       G13 (carry1 T13 T13lt)
       id5 (lid "un-ds-w5b-3" "w5b-3"
            [(hy () (valup "W" "i" mT13 "(inf-lttrans i n (add n 1) w5 (inf-leaddr n 1))"))
             (hy () ["(add \(Wv) \(Vi))" "(add u (mul b \(Pi)))" "h3"])
             (hy Pi (bdig "(W i)" "(add (V i) b)" T13 K13 G13))
             (hy () (sval "V" "i"))
             (hy (nm1 T13) (spw "i"))])
       ; the top, q + 1
       T16 "(natminus (add (W n) \(B)) b)" mT16 (md T16) E5 "(isantisymmnatleh i n h1 w5)"
       K16 "(inf-letrans b \(B) (add (W n) \(B)) (inf-letrans b 1 \(B) h2 (inf-ltle 1 \(B) (un-1ltB L gL))) (inf-leaddl \(B) (W n)))"
       T16lt (Tlt T16 "(W n)" "b" "(gW5 n)")
       G16 (carry1 T16 T16lt)
       Wu (upd "W" "n" mT16) Xu (VW Wu)
       UL16 (updlt "W" "n" mT16 "gW5" T16)
       h3n (tr "(paths nat (add \(Wv) \(Vz)) (add u (mul b \(Pz))))" "h3" E5)
       id6 ["un-ds-pre" (tm "(add \(Xu) \(Vn))") (tm "(add u (mul \(nm1 T16) \(P1)))")
            [(hy () (valup "W" "n" mT16 "(un-ltp1 n)"))
             (hy () ["(add \(Wv) \(Vn))" "(add u (mul b \(Pn)))" h3n])
             (hy Pn (bdig "(W n)" "b" T16 K16 G16))
             (hy (nm1 T16) (spw "n"))]]
       Xlt "(un-vallt \(B) \(Wu) (add n 1) \(UL16))"
       DONE "(un-bdone \(P1) \(Xu) \(Vn) u \(nm1 T16) \(use id6) \(Xlt) gk)"
       id7 (lid "un-ds-w4b1" "w4b-1" [(hy () ["(add \(Xu) \(Vn))" "u" DONE]) (hy () ["(add u (mul q \(Vn)))" W0v "gf"])])
       QV "(mul (add q 1) \(Vn))"
       QLE "(inf-letl \(QV) (add \(Xu) \(QV)) \(W0v) \(use id7) (inf-leaddl \(QV) \(Xu)))"
       QB "(un-qlt (add q 1) \(Vn) \(W0v) \(B) \(QLE) gu)"

       rows
       ((at ["s1-1" "s2-1" "s4-1" "s12-1"] "(inf-powpos (add L L))")
        + at ["m2-1" "p1-1"] (wlt "i" "w1")
        + at ["m6-1" "p2-1" "s8-1" "p4-1" "s16-1" "p6-1"] nwc
        + at ["s5-1" "p3-1"] (wlt "i" "w3")
        + at ["s13-1" "p5-1"] (wlt "i" "w5")
        + at ["s17-2" "w4b-3"] QB
        + [["w1e-2" h]
           ["w1e-4" "(pathscomp0 nat (add \(Wv) (mul qh0 0)) (add \(Wv) 0) (add \(W0v) 0) (maponpaths nat nat (lam z (add \(Wv) z)) (mul qh0 0) 0 (natmultn0 qh0)) (maponpaths nat nat (lam z (add z 0)) \(Wv) \(W0v) \(valc)))"]
           ["w1e-5" "(lam j g (g0 j))"]
           ["w1e-6" "(lam j (inf-lttr (W0 j) (W j) \(B) (pathsinv0 nat (W j) (W0 j) (g0 j)) (gW0 j)))"]
           ["m1-2" "(un-bbfit L (mul qh0 (V i)) (inf-lelt (mul qh0 (V i)) \(S1) (mul \(B) \(B)) (inf-leaddr (mul qh0 (V i)) c) \(MF)))"]
           ["m1-3" "(un-bbfit L \(S1) \(MF))"]
           ["m2-2" (dfit "(add (W i) \(B))" (ltAB "(W i)" "(gW i)"))]
           ["m2-3" (dfit "(add \(LS) b)" "(un-sum2lt \(B) \(h) \(LS) b (un-modlt0 \(B) \(h) \(S1)) a3)")]
           ["m2-4" K1]
           ["m2-5" (dfit T1 T1lt)]
           ["m3-1" G1]
           ["m3-2" (cfit1 T1)]
           ["m4-1" (dfit "(un-div \(B) \(S1))" "(inf-lttrans (un-div \(B) \(S1)) \(B) \(B2) \(DV) (inf-leaddr \(B) \(B)))")]
           ["w1b-2" DV]
           ["w1b-4" (use id1)]
           ["w1b-5" "(lam j g (pathscomp0 nat ((inf-upd W i \(mT1)) j) (W j) (W0 j) (un-updgt W i \(mT1) j (un-sult i j (inf-letr (add i 1) (succ i) j (un-add1 i) g))) (a5 j (inf-letrans i (add i 1) j (inf-leaddr i 1) g))))"]
           ["w1b-6" (updlt "W" "i" mT1 "gW" T1)]
           ["m6-2" (dfit "(add (W n) \(B))" (ltAB "(W n)" "(gW n)"))]
           ["m6-3" (dfit "(add c b)" "(un-sum2lt \(B) \(h) c b a2 a3)")]
           ["m6-4" K6]
           ["m6-5" (dfit T6 T6lt)]
           ["m7-1" G6]
           ["m7-2" (cfit1 T6)]
           ["w2e-2" (use id2)]
           ["w2e-3" (updlt "W" "n" mT6 "gW" T6)]
           ["w3e-3" "(maponpaths nat nat (lam z (add z 0)) \(Wv) u (pathsinv0 nat u \(Wv) gu0))"]
           ["s5-3" (dfit "(add (W i) (V i))" "(un-sum2llt \(B) (W i) (V i) (gW3 i) (gV i))")]
           ["s5-4" (dfit S5 S5lt)]
           ["s6-1" "(un-cfit L gL (un-div \(B) \(S5)) \(carry1 S5 S5lt))"]
           ["w3b-2" (carry1 S5 S5lt)]
           ["w3b-3" (use id3)]
           ["w3b-4" (updlt "W" "i" mS5 "gW3" S5)]
           ["s8-2" (dfit T8 T8lt)]
           ["s9-1" HI8]
           ["s9-2" "(un-cfit L gL (natminus b \(hi8)) (inf-letrans (natminus b \(hi8)) b 1 (inf-suble b \(hi8)) d1))"]
           ["v0-1" "(pathscomp0 nat (add u (mul q \(Vn))) (add \(Wv) (mul q \(Vn))) (add \(W0v) (mul b \(P1))) (maponpaths nat nat (lam z (add z (mul q \(Vn)))) u \(Wv) gu0) d2)"]
           ["v1-1" "(inf-lttr \(Wv) u \(P1) (pathsinv0 nat u \(Wv) gu0) (un-vallt \(B) W (add n 1) gW))"]
           ["s10-1" Q1]
           ["s10-2" "(inf-lelt (natminus q 1) q (inf-pow w) (inf-suble q 1) (inf-lttrans q \(B) (inf-pow w) d4 (inf-powle L w gLw)))"]
           ["w2b-2" (use id4)]
           ["w2b-3" (updlt "W" "n" mT8 "gW3" T8)]
           ["w2b-4" "(inf-lelt (natminus q 1) q \(B) (inf-suble q 1) d4)"]
           ["w2b-5" "(un-predlt q \(Q1))"]
           ["w4e-1" "(pathscomp0 nat (add \(Wv) (mul q \(Vn))) (add \(W0v) (mul b \(P1))) \(W0v) d2 (pathscomp0 nat (add \(W0v) (mul b \(P1))) (add \(W0v) 0) \(W0v) (maponpaths nat nat (lam z (add \(W0v) (mul z \(P1)))) b 0 w2) (natplusr0 \(W0v))))"]
           ["r1-3" "(c1e3 g5)"]
           ["j5j-1" "(c1e2 (isantisymmnatleh xc1 1 c1e1 (inf-ltsu 0 xc1 g5)))"]
           ["w5e-3" "(maponpaths nat nat (lam z (add z 0)) \(Wv) u (pathsinv0 nat u \(Wv) gu1))"]
           ["s13-2" (dfit "(add (W i) \(B))" (ltAB "(W i)" "(gW5 i)"))]
           ["s13-4" (dfit "(add (V i) b)" "(un-sum2lt \(B) \(h) (V i) b (gV i) h2)")]
           ["s13-5" K13]
           ["s13-6" (dfit T13 T13lt)]
           ["s14-1" G13]
           ["s14-2" (cfit1 T13)]
           ["w5b-3" (use id5)]
           ["w5b-4" (updlt "W" "i" mT13 "gW5" T13)]
           ["s16-2" (dfit "(add (W n) \(B))" (ltAB "(W n)" "(gW5 n)"))]
           ["s16-3" K16]
           ["s16-4" (dfit T16 T16lt)]
           ["v2-1" "(pathscomp0 nat (add u (mul q \(Vn))) (add \(Wv) (mul q \(Vn))) \(W0v) (maponpaths nat nat (lam z (add z (mul q \(Vn)))) u \(Wv) gu1) f1)"]
           ["v3-1" "(inf-letl \(Vn) \(Wv) u (pathsinv0 nat u \(Wv) gu1) k9)"]
           ["w4b-1" (use id7)]
           ["s17-1" "(inf-lttrans (add q 1) \(B) (inf-pow w) \(QB) (inf-powle L w gLw))"]
           ["w4b-2" UL16]])
     [(foldl (t \ r \ pin t (r 0) (tm (r 1))) {} rows) [id1 id2 id3 id4 id5 id6 id7]])
   divstep (pin divstep0 'proofs (ds-out 0))
   ds-ids (ds-out 1)

   mag-specs [add sub mas rows offs ge divstep]
   mag-h (cats ["// mag_gen.h -- laid by src/love/mag.l, `make mx`. edit that file.\n"
                (cats (map (s \ clay-show (cl-fn s)) mag-specs))])
   mag-ledger
    [["limbs" "every limb a magnitude holds is under B = 2^L" "love_limb is L bits: L = limb_bits"]
     ["dlimb" "a dlimb holds 2L bits" "love.h's dlimb"]
     ["sizes" "na and nb are counts, nb <= na, r holds na + 1 (na for sub), and na + 1 fits an int" "mag_add, which orders them, and the callers"]
     ["order" "sub's b is at most its a" "big_addsub, by mag_cmp"]
     ["offs" "mag_add_off's r is apart from s, and the sum fits it: off + sn <= rn, and r + s B^off < B^rn" "mag_mul_kara, lvm_kmul and mag_join_dec, whose r holds the whole product"]
     ["rows" "mag_mul_rows' r is apart from a and b and holds end + nb; past row 0 it holds a[0..i0) b, as the chunk before left it" "mag_mul, and lvm_bmul, whose r is a fresh cask its chunks fill in order"]
     ["window" "divstep's w[0..n] is under B times v, and v is not zero" "mag_divmod and lvm_bdiv: dnorm's top limb, then each step's e3"]
     ["qhat" "mag_qhat is the quotient limb or one over, knuth's theorem b (taocp 4.3.1), the one fact left unproved; divstep is right for any limb q, so it bounds only the fix-ups' cost" "mag_qhat in num.c"]]
   (ledger-text l) (cats (map (r \ r @ [a b c] "; \(a): \(b) -- \(c)\n") l))
   mag-vc (cats ["; test/uumagvc.l -- laid by src/love/mag.l, `make mx`. edit that file.\n"
                 "; the ledger: what the theorems leave open, each with who answers for it\n"
                 (ledger-text mag-ledger)
                 "(test\n"
                 (cats (map ring-lemma (rows-out 1 + offs-out 1 + ds-ids)))
                 (cats (map (s \ cats (vc-text s)) mag-specs)) " )\n"])
   mag-ok (0 < #mag-vc && all (s \ clay-ok? (cl-fn s) = 1 && atom? (vc-open s) && atom? (vc-stale s)) mag-specs))
