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

   mag-specs [add]
   mag-h (cats ["// mag_gen.h -- laid by src/love/mag.l, `make mx`. edit that file.\n"
                (cats (map (s \ clay-show (cl-fn s)) mag-specs))])
   mag-ledger
    [["limbs" "every limb a magnitude holds is under B = 2^L" "love_limb is L bits: L = limb_bits"]
     ["dlimb" "a dlimb holds 2L bits" "love.h's dlimb"]
     ["sizes" "na and nb are counts, nb <= na, r holds na + 1, and na + 1 fits an int" "mag_add, which orders them, and its callers"]]
   (ledger-text l) (cats (map (r \ r @ [a b c] "; \(a): \(b) -- \(c)\n") l))
   mag-vc (cats ["; test/uumagvc.l -- laid by src/love/mag.l, `make mx`. edit that file.\n"
                 "; the ledger: what the theorems leave open, each with who answers for it\n"
                 (ledger-text mag-ledger)
                 "(test\n"
                 (cats (map (s \ cats (vc-text s)) mag-specs)) " )\n"])
   mag-ok (0 < #mag-vc && all (s \ clay-ok? (cl-fn s) = 1 && atom? (vc-open s) && atom? (vc-stale s)) mag-specs))
