; src/love/mag.l -- num.c's magnitude loops as data: vc.l lays mag_gen.h and the obligations in
; test/uumagvc.l. a magnitude's value is un-val, its limbs under B = 2^L: each function's theorem
; says what it computes, test/uumag.l the arithmetic underneath
(:
   _ (borrow "src/apps/moon/clay.l")
   _ (borrow "src/love/compress/vc.l")

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

   mag-specs [add sub mas ge]
   mag-h (cats ["// mag_gen.h -- laid by src/love/mag.l, `make mx`. edit that file.\n"
                (cats (map (s \ clay-show (cl-fn s)) mag-specs))])
   mag-ledger
    [["limbs" "every limb a magnitude holds is under B = 2^L" "love_limb is L bits: L = limb_bits"]
     ["dlimb" "a dlimb holds 2L bits" "love.h's dlimb"]
     ["sizes" "na and nb are counts, nb <= na, r holds na + 1 (na for sub), and na + 1 fits an int" "mag_add, which orders them, and the callers"]
     ["order" "sub's b is at most its a" "big_addsub, by mag_cmp"]]
   (ledger-text l) (cats (map (r \ r @ [a b c] "; \(a): \(b) -- \(c)\n") l))
   mag-vc (cats ["; test/uumagvc.l -- laid by src/love/mag.l, `make mx`. edit that file.\n"
                 "; the ledger: what the theorems leave open, each with who answers for it\n"
                 (ledger-text mag-ledger)
                 "(test\n"
                 (cats (map (s \ cats (vc-text s)) mag-specs)) " )\n"])
   mag-ok (0 < #mag-vc && all (s \ clay-ok? (cl-fn s) = 1 && atom? (vc-open s) && atom? (vc-stale s)) mag-specs))
