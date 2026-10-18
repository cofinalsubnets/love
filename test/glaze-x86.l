; glaze-x86 -- the glaze's x86-64 native-codegen tests; run once, by `make test_glaze` only (a re-cat clobbers base-ev)
; blocks compile through base-ev; the emit block shadows ev -> base-ev, the auto block keeps auto-ev
; the guard runs before the binds below: a body-less top-level `:` lands its names on the book
(assert (elem 'glaze (cite ()))
        (400 < #(keys (cite 'glaze)))
        (: nm (names ()) (!(elem 'autogroup nm) && !(elem 'jitir nm) && !(elem 'glaze nm))))
(: assemble (cite 'holo 'assemble)
   bcat (ps \ foldl (a \ b \ a + b) () ps)
   G (cite 'glaze)
   anat-defs (G 'anat-defs)  autogroup (G 'autogroup)  autonat (G 'autonat)  autospec (G 'autospec)
   base-ev (G 'base-ev)  castbuild (G 'castbuild)  cggir (G 'cggir)  cggvir (G 'cggvir)
   consir (G 'consir)  coreir (G 'coreir)  delet (G 'delet)  deoptir (G 'deoptir)
   emit (G 'emit)  fbits (G 'fbits)  fr (G 'fr)  grok (G 'grok)
   jit (G 'jit)  jit2 (G 'jit2)  jitf (G 'jitf)  jitfgrid (G 'jitfgrid)  jitfr (G 'jitfr)
   jitgroupir (G 'jitgroupir)  jitgroupirx (G 'jitgroupirx)  jitir (G 'jitir)  jitloop-n (G 'jitloop-n)  jitn (G 'jitn)
   jitnir (G 'jitnir)  jitsum (G 'jitsum)  jitcalloutsum (G 'jitcalloutsum)  jitcalloutx (G 'jitcalloutx)  calloutir (G 'calloutir)  calloutframeir (G 'calloutframeir)  loopcode (G 'loopcode)
   thloop (G 'thloop)  thcount (G 'thcount)  threadir (G 'threadir)  mkhir (G 'mkhir)  mkouterir (G 'mkouterir)
   occurs? (G 'occurs?)  plift (G 'plift)  qualfr (G 'qualfr)  twolow (G 'twolow)  canon (G 'canon)
   nif (G 'nif)                                  ; the C install seam, a glaze member: every boot pulls it off the book
   (tloop f) (thloop (threadir (base-ev f) 0)))    ; a written loop, as the hook's thread lane reads what ev made of it
(assert (lit? base-ev) (lit? autogroup) (lit? jitgroupir) (lit? assemble))
(: tw twin)                                            ; a synonym, for canon's law below

(base-ev '(: ev base-ev
(: (isum n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (* i 7))) a)) 0 0)
      f (jit '(\ x (+ (* x 3) 1)))   g (jitsum '(* i 7))
    _ (assert
  (lit? f) (lit? g)                                          ; native closures are applicable values
  (31 = (f 10)) (315 = (g 10))
  ((\ x (+ (* x 3) 1)) = f)                                  ; ... and are =-identical to their source
  !(f = (\ x (+ (* x 3) 2)))
  (f = (jit '(\ x (+ (* x 3) 1))))                           ; two natives, same source
  ; fixnum input guard: a non-fixnum arg deopts (no sar/putfix corruption of a heap word)
  (: idn (jit '(\ x x)) (&& (5 = (idn 5)) ('(1 2) = (idn '(1 2))) ('a = (idn 'a)) (= (:) (idn (:)))))
  (: pls (jit '(\ x (+ x 1))) (&& (6 = (pls 5)) ((+ '(1 2) 1) = (pls '(1 2)))))   ; native == interp on a non-fixnum
  (: q (jit '(\ n (+ (* n 3) 1))) (&& (31 = (q 10)) ((\ n (+ (* n 3) 1)) = q) (q = f)))  ; arity-1 leaf, non-x param (= f up to alpha)
  ('(2 4 6) = (map (jit '(\ x (+ x 1))) '(1 3 5)))
  ((isum 1000) = (g 1000))                                   ; the loop agrees with the interpreter
  (9000000000000000000 = ((jit '(\ x (* x x))) 3000000000))  ; overflow -> deopt -> correct bignum
  (1 = ((: (go i a) (? (< i 60) (go (+ i 1) (&& a (= ((jit ['\ 'x ['* 'x i]]) 7) (* 7 i)))) a)) 0 1))
  ; comparisons (-> 0/1) and conditionals
  (: lt (jit '(\ x (< x 5))) (&& (1 = (lt 3)) (1 = (lt -2)) (0 = (lt 5)) (0 = (lt 9))))
  (: ab (jit '(\ x (? (< x 0) (- 0 x) x))) (&& (7 = (ab -7)) (7 = (ab 7)) (0 = (ab 0))))   ; abs
  ((\ x (? (< x 0) (- 0 x) x)) = (jit '(\ x (? (< x 0) (- 0 x) x))))
  (: cap50 (jitsum '(? (< i 50) i 0)) c50 ((: (go i a) (? (< i 1000) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0)
     (= c50 (cap50 1000)))                                                                  ; loop with a conditional body
  ; call-out bridge: a native counted loop calling an interp closure each step
  (: (isum clos n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (clos i))) a)) 0 0)
     sq (\ i (* i i))  co (jitcalloutsum sq)
     (&& (lit? co) (0 = (co 0)) (30 = (co 5)) (285 = (co 10)) ((co 8) = (isum sq 8))
         ; gate 1: a float-returning callee deopts to the interp twin
         (: cf (jitcalloutsum (\ i (* i 0.5))) (&& (7.5 = (cf 6)) ((cf 20) = (isum (\ i (* i 0.5)) 20))))
         ; gate 2: a sum leaving fixnum range deopts -> bignum
         (: cb (jitcalloutsum (\ i 1000000000000000000)) (&& ((cb 100) = (isum (\ i 1000000000000000000) 100))
                                                             (100000000000000000000 = (cb 100)))) ; == interp bignum
         ; * fold: product of (F i)
         (: iprod (\ f n ((: (go i a) (? (< i n) (go (+ i 1) (* a (f i))) a)) 0 1))
            inc (\ i (+ i 1))  pr (jitcalloutx inc '(\ n 0) '* 'i 'i 'x64)                               ; native product of (i+1) = n!
            (&& (lit? pr) (1 = (pr 0)) (120 = (pr 5)) ((pr 6) = (iprod inc 6))                     ; fast path: 5!=120, empty=1 (product identity)
                (: pf (jitcalloutx (\ i (+ i 0.5)) '(\ n 0) '* 'i 'i 'x64)                               ; gate 1: float result -> deopt -> interp product
                   (1.875 = (pf 3)))
                (: pb (jitcalloutx inc '(\ n 0) '* 'i 'i 'x64)                                           ; gate 2: product leaves fixnum range -> deopt -> bignum
                   (&& (51090942171709440000 = (pb 21)) ((pb 25) = (iprod inc 25))))
                ; [2^62, 2^63): 3*2^61 is out of fixnum yet < 2^63, so the end retag must deopt
                (: p3 (jitcalloutx (\ i (? (= i 0) 3 2)) '(\ n 0) '* 'i 'i 'x64)
                   (6917529027641081856 = (p3 62)))))
         ; (F ARG), ARG computed over i: an ARG leaving fixnum range deopts to the twin
         (: isumg  (\ f g n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (f (g i)))) a)) 0 0))         ; interp: sum f(g(i))
            iprodg (\ f g n ((: (go i a) (? (< i n) (go (+ i 1) (* a (f (g i)))) a)) 0 1))         ; interp: product f(g(i))
            sqx (\ x (* x x))  md7 (\ x (% x 7))
            cae  (jitcalloutx sqx '(\ n 0) '+ 'i '(+ i 1) 'x64)                                    ; sum sq(i+1)
            cap  (jitcalloutx sqx '(\ n 0) '* 'i '(+ i 1) 'x64)                                    ; product sq(i+1) = (n!)^2
            caov (jitcalloutx md7 '(\ n 0) '+ 'i '(* (* i i) 1000000000) 'x64)                     ; arg overflows ~i=68k; bounded clos so only the arg deopts
            mkq  (\ f (\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (f (* i i)))) a)) 0 0)))        ; captured f, computed arg (* i i) -> the frame lane (hook)
            cq   (mkq sqx)
            (&& (lit? cae) (55 = (cae 5)) (0 = (cae 0)) ((cae 6) = (isumg sqx (\ i (+ i 1)) 6))    ; computed arg, native fast path
                (576 = (cap 4)) ((cap 15) = (iprodg sqx (\ i (+ i 1)) 15))                         ; computed arg + * fold, overflow -> bignum twin
                (280000 = (caov 70000)) ((caov 100000) = (isumg md7 (\ i (* (* i i) 1000000000)) 100000))   ; arg overflow -> twin
                ((cq 6) = (isumg sqx (\ i (* i i)) 6)) ((cq 50) = (isumg sqx (\ i (* i i)) 50)))))) ; captured computed arg (frame lane), fast + bignum
  ; // and %
  (: dv (jit '(\ x (// x 3))) (&& (3 = (dv 10)) (4 = (dv 13)) (-3 = (dv -10))))
  (: md (jit '(\ x (% x 7)))  (&& (1 = (md 8)) (-1 = (md -8)) (0 = (md 14))))
  ; a mid-nest deopt must leave the machine stack balanced
  (16000000000000000001 = ((jit '(\ x (+ 1 (* x x)))) 4000000000))
  (16000000000000000003 = ((jit '(\ x (+ (+ 1 (* x x)) 2))) 4000000000))
  ; bitwise & | ^
  (: bt (jit '(\ x (& x 12))) (&& (8 = (bt 10)) (12 = (bt 13))))
  (: bo (jit '(\ x (| x 1)))  (&& (3 = (bo 2)) (5 = (bo 5))))
  (: bx (jit '(\ x (^ x 5)))  (&& (15 = (bx 10)) (0 = (bx 5))))
  ; arity-2 leaves: saturated + curried, transparent, deopt via interp body
  (: ad (jit2 '(\ x y (+ x y)))           (&& (7 = (ad 3 4)) (7 = ((ad 3) 4))))
  (: sb (jit2 '(\ x y (- (* x x) y)))     (&& (5 = (sb 3 4)) (16000000000000000000 = (sb 4000000000 0))))
  ((\ x y (+ x y)) = (jit2 '(\ x y (+ x y))))
  (: dd (jit2 '(\ x y (// x y)))          (&& (3 = (dd 13 4)) (-2 = (dd -7 3))))
  ; arity-3 / arity-4 leaves: param i at Sp[i], saturating at any split, transparent
  (: t3 (jitn '(\ x y z (+ (+ x y) (* z 2)))) (&& (13 = (t3 1 2 5)) (13 = ((t3 1 2) 5)) (13 = ((t3 1) 2 5))))
  ((\ x y z (+ (+ x y) (* z 2))) = (jitn '(\ x y z (+ (+ x y) (* z 2)))))
  (: t4 (jitn '(\ a b c d (+ (* a b) (- c d)))) (&& (7 = (t4 2 3 7 6)) (7 = ((t4 2 3) 7 6)) (7 = ((t4 2) 3 7 6))))
  (16000000000000000005 = ((jitn '(\ x y z (+ (+ (* x x) y) z))) 4000000000 0 5))   ; deopt through a middle param
  ; n-variable loop: iterative fib (3 loop vars i,a,b) -- native == interp, deopts at overflow
  (: nf (jitloop-n '(\ n ((: (go i a b) (? (< i n) (go (+ i 1) b (+ a b)) a)) 0 0 1))
                   '(i a b) '((+ i 1) b (+ a b)) '(< i n) 'a '(0 0 1))
     fi (\ n ((: (go i a b) (? (< i n) (go (+ i 1) b (+ a b)) a)) 0 0 1))
     (&& (55 = (nf 10)) (832040 = (nf 30)) (= (fi 30) (nf 30))                       ; fib(10)=55, fib(30)=832040
         (4660046610375530309 = (nf 91))))                                          ; fib(91) > fixnum -> deopt -> bignum
  ; captures = partial-apply a native multi-arg; the leading param(s) are the captures.
  (: mk (jit2 '(\ n x (+ x n)))  a5 (mk 5)  a7 (mk 7)
     (&& (15 = (a5 10)) (17 = (a7 10)) ('(6 7 8) = (map a5 '(1 2 3)))                 ; native captured closure, composes
         (8000000000000000000 = ((mk 4000000000000000000) 4000000000000000000))))    ; ... and deopts through the capture
  ; heap result (jitfr): a float-result leaf boxes on the heap -- a gem out, == interp, transparent, deopts
  (: fr (jitfr '(\ x (+ (* x 1.5) 2.0)) 'x64)  ifr (\ x (+ (* x 1.5) 2.0))
     (&& (gem? (fr 4)) (8.0 = (fr 4)) (= (ifr 7) (fr 7))                  ; a float box; 4*1.5+2=8.0; == interp
         (lit? fr) ((\ x (+ (* x 1.5) 2.0)) = fr)
         (= (map ifr '(1 2 3)) (map fr '(1 2 3)))                         ; composes with map, == interp
         (= (ifr (:)) (fr (:)))))                                         ; non-fixnum arg -> fxv deopt -> interp
  (: frz (jitfr '(\ x (/ (- x x) (- x x))) 'x64) (&& (gem? (frz 5)) (0.0 = (frz 5))))   ; 0/0 -> NaN -> 0.0 (mk_gem's law)
  ; gc-safety: a native-written box is a normal gem, held across a forced gc and boxed under pressure
  (: gfr (jitfr '(\ x (+ (* x 1.5) 2.0)) 'x64)  b (gfr 4)  _ (tally (jot 200000))  (8.0 = b))   ; the box survives a forced GC
  (: gfr (jitfr '(\ x (+ (* x 1.5) 2.0)) 'x64)  ys (map gfr (jot 4000))  zs (map (\ x (+ (* x 1.5) 2.0)) (jot 4000)) (= ys zs))  ; 4000 boxes under GC pressure == interp
  ; comparison result codes
  (: le (jit '(\ x (<= x 5))) (&& (1 = (le 5)) (1 = (le 3)) (0 = (le 6))))
  (: gt (jit '(\ x (>  x 5))) (&& (1 = (gt 6)) (0 = (gt 5)) (0 = (gt 2))))
  (: ge (jit '(\ x (>= x 5))) (&& (1 = (ge 5)) (1 = (ge 9)) (0 = (ge 4))))
  (: eq (jit '(\ x (= x 5))) (&& (1 = (eq 5)) (0 = (eq 4)) (0 = (eq 6))))
  ; multi-arg (cgn) op dispatch
  (: mdn (jit2 '(\ x y (% x y))) (&& (1 = (mdn 8 7)) (-1 = (mdn -8 7)) (0 = (mdn 14 7))))   ; idivseq-mn %
  (: ban (jit2 '(\ x y (& x y))) (&& (8 = (ban 10 12)) (4 = (ban 4 5))))                    ; cgn -> bitseq
  (: bon (jit2 '(\ x y (| x y))) (&& (3 = (bon 2 1)) (7 = (bon 5 3))))
  (: ltn (jit2 '(\ x y (< x y))) (&& (1 = (ltn 3 5)) (0 = (ltn 5 3))))                      ; cgn -> cmpseq
  (: mnn (jit2 '(\ x y (? (< x y) x y))) (&& (3 = (mnn 3 5)) (4 = (mnn 9 4))))              ; cgn -> condcode (min)
  ; *-fold counted loop through loopcode (jitsum hardcodes +/<)
  (: prodf (: psrc ['\ 'n [[': ['go 'i 'a] ['? ['< 'i 'n] ['go ['+ 'i 1] ['* 'a ['+ 'i 1]]] 'a]] 0 1]]
              (nif (emit (loopcode '(+ i 1) 'i '* '< 'x64)) (ev psrc) 1))
     pf (\ n ((: (go i a) (? (< i n) (go (+ i 1) (* a (+ i 1))) a)) 0 1))
     (&& (120 = (prodf 5)) (= (pf 8) (prodf 8))))                                           ; n! via a product fold
  ; divide-by-zero takes the guardz deopt
  (: dz (jit '(\ x (// x 0))) (= (// 10 0) (dz 10)))                                        ; // by 0 -> deopt -> interp
  ; --- float predicate leaves (SSE): unboxed-double compares over a fixnum arg -> 0/1 ---
  (= "4616189618054758400" (show (fbits 4.0)))                                              ; fbits: 4.0 -> 0x4010000000000000
  (: flt (jitf '(\ x (< (* x 1.5) 10.0)))
     (&& (1 = (flt 6)) (0 = (flt 7)) (1 = (flt 0)) (1 = (flt -3))                           ; 1.5x < 10  <=> x < 6.67
         ((\ x (< (* x 1.5) 10.0)) = flt)
         (= ((\ x (< (* x 1.5) 10.0)) '(1 2)) (flt '(1 2)))))
  (: fle (jitf '(\ x (<= (+ (* x x) 2.0) 38.0))) (&& (1 = (fle 6)) (0 = (fle 7)) (1 = (fle -6))))   ; x*x+2 <= 38 <=> |x|<=6
  (: fgt (jitf '(\ x (> (/ 100.0 x) 7.0)))       (&& (1 = (fgt 10)) (0 = (fgt 20)) (1 = (fgt 5))))  ; 100/x > 7 <=> 0<x<14.3
  (: fge (jitf '(\ x (>= (- (* x 0.5) 1.0) 2.0))) (&& (1 = (fge 6)) (0 = (fge 5))))                 ; x/2-1 >= 2 <=> x>=6
  (: feq (jitf '(\ x (= (* x 0.25) 2.0)))         (&& (1 = (feq 8)) (0 = (feq 7))))                 ; x/4 == 2 <=> x==8
  ; --- nested grid owner: native whole-grid mandelbrot == interpreter (checksum 87130) ---
  (: gsrc '(\ _ (: (mand cx cy zx zy it) (? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
                       (mand cx cy (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1)) it)
                   (col px py acc) (? (< py 64) (col px (+ py 1) (+ acc (mand (- (* px 0.046875) 2.0) (- (* py 0.046875) 1.5) 0.0 0.0 0))) acc)
                   (grid px acc) (? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
                 (grid 0 0)))
     mg (jitfgrid gsrc 64 64 '(- (* px 0.046875) 2.0) '(- (* py 0.046875) 1.5)
                  '(zx zy) '((+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy))
                  '(+ (* zx zx) (* zy zy)) '<= 4.0 100 'x64)
     (&& (= 87130 (mg 0)) (= ((ev gsrc) 0) (mg 0))))
  ; --- auto-hook: recognize the (mand col grid) nest from source and glaze it -> checksum 87130 ---
  (: gmand '(? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
               (mand cx cy (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1)) it)
     gcol '(? (< py 64) (col px (+ py 1) (+ acc (mand (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875)) 0.0 0.0 0))) acc)
     ggrid '(? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
     ng (grok '(\ _ 0) '(cx cy zx zy it) gmand gcol ggrid 'x64)
     (= 87130 (ng 0))))
    (say err "glaze emit: native codegen ok (arith + loop + D-dim float grid, transparent, deopt)\n"))
))

; call-out recognizer: a counted sum calling a global closure glazes; targets are body-less defines, so gv finds them
(: (rc-sq i) (i * i))
(: (rc-half i) (i * 0.5))
(: (rc-big i) 1000000000000000000)
(: (rc-ssum n) ((: (go i a) (i < n ? (go (i + 1) (a + rc-sq i)) a)) 0 0))
(: (rc-fsum n) ((: (go i a) (i < n ? (go (i + 1) (a + rc-half i)) a)) 0 0))
(: (rc-bsum n) ((: (go i a) (i < n ? (go (i + 1) (a + rc-big i)) a)) 0 0))
; interp references: inline sums, not closures, so natjit never fires on them
(: sref ((: (go i a) (i < 30 ? (go (i + 1) (a + rc-sq i)) a)) 0 0))
(: fref ((: (go i a) (i < 20 ? (go (i + 1) (a + rc-half i)) a)) 0 0))
(: bref ((: (go i a) (i < 100 ? (go (i + 1) (a + rc-big i)) a)) 0 0))
(: _ (assert (lit? rc-ssum) (285 = (rc-ssum 10)) ((rc-ssum 30) = sref)
        (95.0 = (rc-fsum 20)) ((rc-fsum 20) = fref)                                ; gate 1: float call-out -> gem, == interp
        (100000000000000000000 = (rc-bsum 100)) ((rc-bsum 100) = bref)             ; gate 2: sum overflows fixnum -> bignum, == interp
        (8999995500000500000 = (rc-ssum 3000000)))                                 ; gate 2 boundary: sum in [2^62,2^63) -> bignum
   (say err "test/glaze-x86: call-out recognizer -- a global-target sum glazes (fast path + gate1 float + gate2 overflow) ok\n"))

; captured / multi-arg call-out: F is read from the frame, not baked
(: (rc-summer f) (n \ (: (go i a) (i < n ? (go (i + 1) (a + f i)) a)) 0 0))     ; captured: (\ f n ..)
(: (rc-hosum f n) ((: (go i a) (i < n ? (go (i + 1) (a + f i)) a)) 0 0))        ; multi-arg: f a genuine 2nd frame arg
(: cs (rc-summer rc-sq)  cf (rc-summer rc-half)  cb (rc-summer rc-big)
   _ (assert (lit? cs) (285 = (cs 10)) ((cs 30) = sref)
        (95.0 = (cf 20)) ((cf 20) = fref)                                                  ; gate 1 (captured float)
        (100000000000000000000 = (cb 100)) ((cb 100) = bref)                              ; gate 2 (captured overflow -> bignum)
        (8999995500000500000 = (cs 3000000))                                             ; gate 2 boundary (captured)
        (285 = (rc-hosum rc-sq 10)) ((rc-hosum rc-sq 30) = sref)                          ; multi-arg ho sum == interp
        (95.0 = (rc-hosum rc-half 20)))
   (say err "test/glaze-x86: call-out recognizer -- captured + multi-arg (frame-read F, hand-rolled ret) glaze ok\n"))

; amble, the last lane: shapes every other lane declines glaze at creation, == interp
; the () literal is the empty mint, not charm 0; go and the loop names are never callee candidates
(: (am-cnt l k a) ((: (go l a) (two? l ? (go >l (cap l = k ? (a + 1) a)) a)) l a))
(: (am-rev l acc) ((: (go l a) (two? l ? (go >l (. <l a)) a)) l acc))
(: (am-mk i acc) (i < 1 ? acc (am-mk (i - 1) (. (i % 7) acc))))
(: am-l (am-mk 200 ()))
(: am-dbl (: F (x \ x + x) (n \ (: (go i a) (i < n ? (go (i + 1) (a + F (F i))) a)) 0 0)))
(: (am-sq x) ((x * x) + 1))                                                          ; global callees, and a loop-name namesake
(: (am-mul2 x y) ((x + 1) * y))
(: (am-seed k) (k + 3))
(: (am-gref l a) ((: (go l a) (two? l ? (go >l (a + am-sq <l)) a)) l a))
(: am-go (x \ x * 1000000))
(: _ (: n0 (peep fires () 0)
       wk (ev '(\ l k a ((: (go l a) (? (two? l) (go (cup l) (? (= (cap l) k) (+ a 1) a)) a)) l a)))
       ; references are literals: any in-file reference closure would amble too
       (assert (fired? n0)
          (29 = (wk am-l 3 0)) (29 = (am-cnt am-l 3 0))           ; fast path; i%7==3 for i in 1..200 -> 29
          (4611686018427387932 = (wk am-l 3 4611686018427387903)) ; +1 past max fixnum -> restart -> bignum
          (30.5 = (wk am-l 3 1.5))                                ; gem acc -> arith guard deopt -> generic +
          (0 = (wk () 3 0)) (7 = (wk 42 3 7))                     ; ()/non-chain -> two? false -> a
          ((am-rev (am-rev am-l ()) ()) = am-l)                   ; native cons round-trips against the interp-built list (()-tailed)
          (() = am-rev () ())                                     ; the () literal is the mint, not charm 0
          (19800 = (am-dbl 100))                                  ; nested captured calls via the drive: sum 4i, i<100
          (: deep (base-ev '(: H (\ x ((: (go i a) (? (< i 40) (go (+ i 1) (. i a)) a)) 0 (. x ())))
                             (: (dv d) (? (< d 1) 0 (+ (two? (H d)) (dv (- d 1)))))))
             (5000 = (deep 5000)))                                                 ; the storm shape: 5000 pending frames + GC churn, == interp
          ; quoted constants: (= a 'sym) is raw identity; a quoted list answers interp's own node
          (: dsp (ev '(\ l a ((: (go l a) (? (two? l) (go (cup l) (? (= (cap l) (\ r)) (+ a 1) (? ((cap l) = (\ R)) (+ a 10) a))) a)) l a)))
             (23 = dsp '(r R r x R r) 0 && 0 = dsp () 0 && 5 = dsp '(x y) 5))
          (: qz (ev '(\ x (? (= x (\ k)) (\ (1 2)) ())))
             ('(1 2) = qz 'k && qz 'k = qz 'k && () = qz 'nope))
          (: qe (ev '(\ x (? (= x (\ q)) 1 0)))
             (1 = qe 'q && 0 = qe 'r && 0 = qe 5 && 0 = qe "q" && 0 = qe '(q)))
          ; global callees: per-element, multi-arg, in an init, and a nif head
          (: gw (ev '(\ l a ((: (go l a) (? (two? l) (go (cup l) (+ a (am-sq (cap l)))) a)) l a)))
             (32 = gw '(2 3 4) 0 && gw am-l 0 = am-gref am-l 0))
          (: gm (ev '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (am-mul2 i 2))) a)) (am-seed 0) 0)))
             (98 = gm 10 && 0 = gm 0))                                    ; inits ran: (am-seed 0) = 3 -> i starts at 3
          (: gp (ev '(\ l a ((: (go l a) (? (two? l) (go (cup l) (+ a (% (cap l) 3))) a)) l a)))
             (4 = (gp '(10 11 12 13) 0)))                                         ; 1+2+0+1 -- a nif callee curries through two drives
          ; a global namesake of the loop name: the non-tail (am-go ..) is the local binding, so amble declines
          (: r4 (ev '(\ n ((: (am-go i a) (? (< i n) (am-go (+ i 1) (+ a i)) (+ a (tally (am-go n))))) 0 0)))
             (10 = r4 5
              && r4 5 = ((n \ (: (am-go i a) (i < n ? (am-go (i + 1) (a + i)) (a + tally (am-go n)))) 0 0) 5)))
          ; the string lane: in-range (s i) is a native byte index, a negative or past-end read drives
          ; one site takes closures and strings; a param named tally shadows the fast lane
          (: dg (ev '(\ s n ((: (go i a) (? (< i n) (go (+ i 1) (+ (* a 10) (- (s i) 48))) a)) 0 0)))
             (31415926 = (dg "31415926" 8)))
          (: bs (ev '(\ s ((: (go i a) (? (< i (tally s)) (go (+ i 1) (+ a (s i))) a)) 0 0)))
             (294 = bs "abc" && 0 = bs ""))
          (: pk (ev '(\ s n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (s (- i 2)))) a)) 0 0)))
             (195 = (pk "ab" 6)))                                                 ; 97+98: out-of-range reads add nothing
          (: mx (ev '(\ f n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (f i))) a)) 0 0)))
             (90 = mx (x \ x * 2) 10 && 294 = mx "abc" 5))                ; one site, both callee kinds
          (: ct (ev '(\ l n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (tally l))) a)) 0 0)))
             (12 = ct '(1 2 3) 4 && 8 = ct "ab" 4))                       ; chain tally drives; text tally native
          (: ts (ev '(\ tally n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (tally i))) a)) 0 0)))
             (10 = (ts (x \ x + 1) 4)))
          ; sibling callees: a letrec sibling's call curries its frozen entry; digrun is moon's lexer shape
          (: n2 (peep fires () 0)
             lx (ev '(: (dig? c) (? (< c 58) (< 47 c) ())
                        (digrun s n) (: (go k v) (? (&& (k < n) (dig? (s k))) (go (k + 1) ((* 10 v) + ((s k) - 48))) v) (go 0 0))
                        digrun))
             (31415 = lx "31415x" 6 && 0 = lx "x" 1 && fired? n2))         ; the lexer class ambles (fires) and == interp
          (: mk (ev '(\ b (: (addb x) (+ x b)
                             (suml l) ((: (go l a) (? (two? l) (go (cup l) (+ a (addb (cap l)))) a)) l 0)
                             suml)))
             (306 = (mk 100 '(1 2 3))))                                           ; a sibling with an import: entry curried through the frame
          (: eo (ev '(: (ev? n) (? (< n 1) 1 (od? (- n 1)))
                        (od? n) (? (< n 1) 0 (ev? (- n 1)))
                        (cnt l) ((: (go l a) (? (two? l) (go (cup l) (+ a (od? (cap l)))) a)) l 0)
                        cnt))
             (4 = (eo '(1 2 3 4 5 6 7))))                                         ; mutual recursion: the later sibling drives the earlier's entry
          ; the deopt budget: a native that deopts every call retires to the twin, correct throughout
          (: hp (ev '(\ l q ((: (go l a) (? (two? l) (go (cup l) (? (= (cap l) q) (+ a 1) a)) a)) l 0)))
             (: (chk i bad) (i < 40 ? (chk (i + 1) (2 = hp '("ab" "cd" "ab" "x") "ab" ? bad (bad + 1))) bad)
                (0 = (chk 0 0))))))
   (say err "test/glaze-x86: amble -- the boring-tier translator (walker + cons + globals + siblings + the deopt budget) ok\n"))

; swallow helpers: top-level so srcrec records their source; swsum's named-let exercises the lift
(: (swq n) ((n * n) + 1))
(: (swsum n) (: (go i a) (i < 1 ? a (go (i - 1) (a + i))) (go n 0)))

(base-ev '(:
 _ (assert
    ((\ x (+ (* x 2) 3)) = (ev '(\ x (+ (* x 2) 3))))          ; leaf: native, =-identical
    (23 = ((ev '(\ x (+ (* x 2) 3))) 10))
    (((base-ev '(\ x (+ (* x 9) 4))) 11) = ((ev '(\ x (+ (* x 9) 4))) 11))
    (: ny (ev '(\ y (+ y 1))) (&& (6 = (ny 5)) ((\ y (+ y 1)) = ny)))   ; arity-1 leaf, non-x param, auto-natived
    (3 = ((ev '(\ x (cap x))) '(3 4)))                         ; non-qualifying -> interpreter
    ((base-ev '(+ 1 2 3)) = (ev '(+ 1 2 3)))                   ; non-lambda forms unaffected (ev == base-ev; curried + nets 27, not 6)
    (9000000000000000000 = ((ev '(\ x (* x x))) 3000000000))   ; overflow deopts -> bignum
    (: ab (ev '(\ x (? (< x 0) (- 0 x) x))) (&& (7 = (ab -7)) (7 = (ab 7))))   ; conditional leaf auto-natived
    ; loop auto-detected -> native counted loop, =-identical + correct
    (: L1 '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (* i 7))) a)) 0 0))
       f  (ev L1)
       (&& (= f (ev L1)) (3496500 = (f 1000)) (two? (thcount (tloop L1)))
           (= (ev L1) (ev L1))))                                  ; same source -> same native, memoized
    ; loop with a conditional body (sum i for i<50, capped) auto-detected
    (: L2 '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0))
       h  (ev L2)  c ((: (go i a) (? (< i 1000) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0)
       (&& (two? (thcount (tloop L2))) (= c (h 1000))))
    ; generalized loop -- a product fold (op=*, init 1): n! = prod_{i<n}(i+1)
    (: P '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (* a (+ i 1))) a)) 0 1))
       f (ev P)  fi ((: (go i a) (? (< i 10) (go (+ i 1) (* a (+ i 1))) a)) 0 1)
       (&& (two? (thcount (tloop P))) (3628800 = (f 10)) (= fi (f 10)) (= (ev P) (ev P))
           (15511210043330985984000000 = (f 25))))             ; overflow -> deopt -> bignum (transparent)
    ; generalized loop -- a <= comparison: sum_{i<=n} i
    (: Q '(\ n ((: (go i a) (? (<= i n) (go (+ i 1) (+ a i)) a)) 0 0))
       g (ev Q)  (&& (two? (thcount (tloop Q))) (55 = (g 10))))        ; 0+1+..+10 = 55
    ; n-variable loop auto-detected: iterative fib (i,a,b -- updates b and a+b)
    (: F '(\ n ((: (go i a b) (? (< i n) (go (+ i 1) b (+ a b)) a)) 0 0 1))
       nf (ev F)  (&& (two? (tloop F)) (832040 = (nf 30)) (= (ev F) (ev F))   ; fib(30)=832040, native+transparent
                      (4660046610375530309 = (nf 91))                              ; fib(91) -> deopt -> bignum
                      (354224848179261915075 = (nf 100))                           ; fib(100) overflows -> deopt to the thread, exact bignum
                      (40 = ((show nf) 0))))                                       ; the native shows as its lambda: the deopt is its thread
    ; a constant-scaled (* 2 b) update: pell(60) overflows int64; the deopted loop must equal interp exactly
    (: PL '(\ n ((: (go i a b) (? (< i n) (go (+ i 1) b (+ (* 2 b) a)) a)) 0 0 1))
       pf (ev PL)  (&& (two? (tloop PL)) (= ((base-ev PL) 60) (pf 60)) (= 12 (pf 4))))  ; pell(60) deopt == interp; pell(4)=12 in-range
    (= (ev '(\ x (+ x 1))) (ev '(\ x (+ x 1))))
    (: ad (ev '(\ x y (+ (* x x) y))) (&& (13 = (ad 3 4)) (13 = ((ad 3) 4)) ((\ x y (+ (* x x) y)) = ad)))  ; 2-arg leaf auto-natived
    (: a3 (ev '(\ x y z (+ (+ x y) (* z 3))))                                                  ; 3-arg leaf auto-natived, currying at any split
       (&& (13 = (a3 1 3 3)) (13 = ((a3 1 3) 3)) (13 = ((a3 1) 3 3)) ((\ x y z (+ (+ x y) (* z 3))) = a3)))
    ; captured-closure constructor auto-natived: captures transparent (= interp)
    (: adder (ev '(\ n (\ x (+ x n))))  a5 (adder 5)
       (&& (15 = (a5 10)) ('(6 7 8) = (map a5 '(1 2 3))) (= a5 ((\ n (\ x (+ x n))) 5))))
    ; float-result leaf auto-natived -> a heap-boxed gem, == interp, transparent
    (: fr (ev '(\ x (+ (* x 1.5) 2.0)))
       (&& (gem? (fr 4)) (8.0 = (fr 4)) (= ((base-ev '(\ x (+ (* x 1.5) 2.0))) 7) (fr 7))
           ((\ x (+ (* x 1.5) 2.0)) = fr)))
    (qualfr '(\ x (/ (+ x 1.0) 2.0)))                          ; float-division leaf: param floated at first use -> sound
    !(qualfr '(\ x (+ (* x 3) 1.5)))                           ; (* x 3) is int: late promotion diverges -> rejected
    !(qualfr '(\ x (/ x 2)))                                   ; int/int division: result type value-dependent -> rejected
    !(qualfr '(\ x (+ (* x 2) 3)))                             ; an all-integer leaf is no float result (qual handles it)
    (: ii (ev '(\ x (+ (* x 2) 3))) (&& (7 = (ii 2)) !(gem? (ii 2)))))   ; qualfr did not steal it
 _ (assert    ; d-dimensional float-recurrence grids auto-glazed to a native whole-grid kernel, bit-exact
    ; D=2 -- the mandelbrot 64x64 grid (M=2 invariants, N=2 fvars) -> checksum 87130
    (: g2 '(: (mand cx cy zx zy it)
               (? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
                  (mand cx cy (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1)) it)
              (col px py acc) (? (< py 64) (col px (+ py 1) (+ acc (mand (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875)) 0.0 0.0 0))) acc)
              (grid px acc) (? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
            (grid 0 0))
       (&& !(= (autonat g2) g2) (= 87130 (ev g2)) (= (base-ev g2) (ev g2))))      ; autonat rewrote it -> native == interp
    ; D=1 -- a single row of escape counts (cy a constant 0.0) -> native == interp
    (: g1 '(: (mand cx cy zx zy it) (? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0)) (mand cx cy (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1)) it)
              (row px acc) (? (< px 64) (row (+ px 1) (+ acc (mand (- (* px 0.046875) 2.0) 0.0 0.0 0.0 0))) acc)
            (row 0 0))
       (&& !(= (autonat g1) g1) (= (base-ev g1) (ev g1))))
    ; D=3 -- an 8x8x8 nest, M=3 invariants, cz=pz*0.01 shifting zy (exercises r12 push/pop)
    (: g3 '(: (mand cx cy cz zx zy it) (? (&& (< it 50) (<= (+ (* zx zx) (* zy zy)) 4.0)) (mand cx cy cz (+ (- (* zx zx) (* zy zy)) cx) (+ (+ (* (* 2.0 zx) zy) cy) cz) (+ it 1)) it)
              (lz px py pz acc) (? (< pz 8) (lz px py (+ pz 1) (+ acc (mand (- (* px 0.046875) 2.0) (- (* py 0.046875) 1.5) (* pz 0.01) 0.0 0.0 0))) acc)
              (ly px py acc) (? (< py 8) (ly px (+ py 1) (+ acc (lz px py 0 0))) acc)
              (lx px acc) (? (< px 8) (lx (+ px 1) (+ acc (ly px 0 0))) acc)
            (lx 0 0))
       (&& !(= (autonat g3) g3) (= (base-ev g3) (ev g3))))
    ; twin grid: twolow lowers c/z to real pairs, autonat glazes it, bit-exact
    (: g2t '(: (mand c z it)
                 (? (&& (< it 100) (<= (+ (* (re z) (re z)) (* (im z) (im z))) 4.0)) (mand c (+ (* z z) c) (+ it 1)) it)
               (col px py acc) (? (< py 64) (col px (+ py 1) (+ acc (mand (twin (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875))) (twin 0.0 0.0) 0))) acc)
               (grid px acc) (? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
             (grid 0 0))
       (&& !(= (twolow g2t) g2t)                                                    ; twolow rewrote the twin grid
           !(= (autonat (twolow g2t)) (twolow g2t))                                 ; ... and autonat then glazes the real-pair form
           (= 87130 (ev g2t)) (= (base-ev g2t) (ev g2t))))                            ; native == interp, same checksum as the plain-float g2
    ; ... spelled (re ~ im): auto-ev opfixes ahead of the lowering, so twolow reads (twin ..)
    (: g2i '(: (mand c z it)
                 (? (&& (< it 100) (<= (+ (* (re z) (re z)) (* (im z) (im z))) 4.0)) (mand c (+ (* z z) c) (+ it 1)) it)
               (col px py acc) (? (< py 64) (col px (+ py 1) (+ acc (mand ((+ -2.0 (* px 0.046875)) ~ (+ -1.5 (* py 0.046875))) (0.0 ~ 0.0) 0))) acc)
               (grid px acc) (? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
             (grid 0 0))
       (&& (= (twolow g2i) g2i) !(= (twolow (opfix g2i)) (opfix g2i))                 ; raw infix declines, opfixed lowers
           (= 87130 (ev g2i)) (= (base-ev g2i) (ev g2i))))
    ; ... and through a synonym: canon respells a free nom by its value, so `tw` meets twolow as twin
    (: g2s '(: (mand c z it)
                 (? (&& (< it 100) (<= (+ (* (re z) (re z)) (* (im z) (im z))) 4.0)) (mand c (+ (* z z) c) (+ it 1)) it)
               (col px py acc) (? (< py 64) (col px (+ py 1) (+ acc (mand (tw (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875))) (tw 0.0 0.0) 0))) acc)
               (grid px acc) (? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
             (grid 0 0))
       (&& (= (twolow g2s) g2s) !(= (twolow (canon (opfix g2s))) (canon (opfix g2s)))
           (= 87130 (ev g2s)) (= (base-ev g2s) (ev g2s))))
    ; recursive arithmetic: naive fib glazes; an overflowing recursion deopts to the exact bignum
    (: rf '(: (fib n) (? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))) (fib 25))
       (&& !(= (autogroup rf) rf) (= 75025 (ev rf)) (= (base-ev rf) (ev rf))))
    ; a body-less group `:` (even # of forms) is declined, returned unchanged
    (: bl '(: (fib n) (? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))  (= (autogroup bl) bl))
    ; the lowering must stay right anyway (srcrec walks it): norm-let's inlined aux leaves closed
    ; over earlier ones, and an uncopyable aux (one tablet) stays put
    (: nl '(: (f b) (: gb (? (= b 6) 3 5) gc (// (* gb 8) b)
                       (go i a) (? (< i gc) (go (+ i 1) (+ a gb)) a) (go 0 0))
              (f 6))
       dup '(: (f n) (: t (tablet 0)
                        (go i a) (? (< i n) (: _ (pin t 0 (+ 1 (peep t 0 0))) (go (+ i 1) (+ a 1)))
                                             (peep t 0 0))
                        (go 0 0))
               (f 3))
       (&& (= 12 (ev nl)) (= (base-ev nl) (ev nl))      ; gc's value carries gb out with it
           (= 3 (ev dup)) (= (base-ev dup) (ev dup))))  ; the tablet aux stays put
    (: rp '(: (p2 n) (? (< n 1) 1 (* 2 (p2 (- n 1)))) (p2 70))
       (= (base-ev rp) (ev rp)))                               ; 2^70 overflows -> deopt -> bignum
    ; multi-arg recursion: tak's args survive nested self-calls on the machine stack
    (: rt '(: (tak x y z) (? (< y x) (tak (tak (- x 1) y z) (tak (- y 1) z x) (tak (- z 1) x y)) z) (tak 18 12 6))
       (&& !(= (autogroup rt) rt) (= 7 (ev rt)) (= (base-ev rt) (ev rt))))
    ; a higher-order constant inlines into its callers and only its own binding drops: sum (n + 2) over 1..5
    (: rh '(: tw (\ h x (h (h x)))  (inc n) (+ n 1)  (f n) (? (< n 1) 0 (+ (tw inc n) (f (- n 1))))  (f 5))
       (&& !(= (autogroup rh) rh) (= 25 (ev rh)) (= (base-ev rh) (ev rh))))
    ; a macro's call never flattens: sec inlines to ((list v 9) 1), an index, never (list v 9 1)
    (: rl '(: (sec l) (l 1)  (pr2 v) (sec (list v 9))  (nib c) (? (< c 58) (- c 48) (- c 87))  (+ (pr2 5) (nib 50)))
       (&& !(= (autogroup rl) rl) (= 11 (ev rl)) (= (base-ev rl) (ev rl))))
    ; an inlined name stays as written in a quote: (show 'sec) is "sec", never the lambda's text
    (: rq '(: (sec l) (l 1)  (pr2 v) (sec (list v 9))  (nib c) (? (< c 58) (- c 48) (- c 87))  k (tally (show 'sec))  (+ (+ (pr2 5) (nib 50)) k))
       (&& !(= (autogroup rq) rq) (= 14 (ev rq)) (= (base-ev rq) (ev rq))))
    ; group swallow: an external global callee's recorded source folds in as an in-blob sibling
    (: rsw '(: (rsw1 n) (? (< n 1) 0 (+ (swq n) (rsw1 (- n 1)))) (rsw1 5))                    ; sum swq(1..5) = 2+5+10+17+26 = 60
       rst '(: (rst1 n) (? (< n 1) 0 (+ (swsum n) (rst1 (- n 1)))) (rst1 4))                 ; sum swsum(1..4) = 1+3+6+10 = 20
       (&& !(= (autogroup rsw) rsw) (= 60 (ev rsw)) (= (base-ev rsw) (ev rsw))             ; leaf callee swallowed -> native == interp
           !(= (autogroup rst) rst) (= 20 (ev rst)) (= (base-ev rst) (ev rst))))           ; named-let callee (lift) swallowed too
    ; mutual recursion: both siblings glazed, cross-calls native inside one buffer
    (: rm '(: (evn n) (? (= n 0) 1 (odn (- n 1))) (odn n) (? (= n 0) 0 (evn (- n 1))) [(evn 100) (odn 100) (evn 7)])
       (&& !(= (autogroup rm) rm) ('(1 0 0) = (ev rm)) (= (base-ev rm) (ev rm))))
    ; lambda-lifting: each named-let loop lifts to a flat group fn, so the whole graph glazes
    (: rpr '(: (prime? n) ((: (go d) (? (< n (* d d)) 1 (? (= 0 (% n d)) 0 (go (+ d 1))))) 2)
               (count lo hi) ((: (go n c) (? (< n hi) (go (+ n 1) (? (prime? n) (+ c 1) c)) c)) lo 0)
               (count 2 30))
       (&& !(= (autogroup rpr) rpr) (10 = (ev rpr)) (= (base-ev rpr) (ev rpr))))
    ; string lane: a recursive (peep s i) byte processor glazes, s passed raw
    (: rsl '(: data (string [72 105 90 33 65])
               (bsum s i) (? (< i 0) 0 (+ (peep s i 0) (bsum s (- i 1))))
               (bsum data 4))
       (&& !(= (autogroup rsl) rsl) (365 = (ev rsl)) (= (base-ev rsl) (ev rsl))))
    ; full string lane: fold-consts, norm-let, lift and inference glaze the rolling hash
    (: rss '(: hmod 1000000007
               (strhash s) (: n (tally s) (go i h) (? (< i n) (go (+ i 1) (% (+ (* h 31) (peep s i 0)) hmod)) h) (go 0 0))
               data (string [72 105 90 33 65])
               (strhash data))
       (&& !(= (autogroup rss) rss) (69709145 = (ev rss)) (= (base-ev rss) (ev rss))))
    ; chain lane: a tree node-count glazes; no entry guard since two? is total, cap/cup guarded
    (: rcl '(: (mk d) (? (< d 1) 0 (. (mk (- d 1)) (mk (- d 1))))
               (ck t) (? (two? t) (+ 1 (+ (ck (cap t)) (ck (cup t)))) 0)
               (ck (mk 8)))
       (&& !(= (autogroup rcl) rcl) (255 = (ev rcl)) (= (base-ev rcl) (ev rcl))))      ; depth 8 = 2^8-1 = 255 nodes
    ; chain-lane soundness: a cap feeding arithmetic is rejected, stays interpreted
    (: rcb '(: (g t) (+ (cap t) 0) (g (. 7 8)))
       (&& (= (autogroup rcb) rcb) (= (base-ev rcb) (ev rcb))))                         ; not rewritten (rejected) -> == interp
    ; partial lift: the read-only `scan` hoists to a top-level sibling threading (n h); tested via
    ; base-ev, since plift is not on the autogroup chain
    (: rpl '(: (hash-run n)
                (: h (tablet 0)
                   (ins i)      (? (< i n) (: _ (pin h (+ 1 (* 97 i)) i) (ins (+ i 1))) h)
                   (scan i acc) (? (< i n) (scan (+ i 1) (+ acc (peep h (+ 1 (* 97 i)) 0))) acc)
                   (bump i)     (? (< i n) (: k (+ 1 (* 97 i)) _ (pin h k (+ 1 (peep h k 0))) (bump (+ i 1))) h)
                   _  (ins 0) a (scan 0 0) __ (bump 0) (+ a (scan 0 0)))
                (hash-run 30))
       pl (plift rpl)
       (&& !(= pl rpl) (900 = (base-ev rpl)) (900 = (base-ev pl))                       ; fired + source->source semantic equivalence
           (elem 'hash-run_scan (map (\ pr (? (two? (cap pr)) (caap pr) (cap pr))) (cap (anat-defs (cup pl)))))))   ; scan hoisted to a top-level sibling
    ; map lane: a read-only map probe glazes; h is peep'd but never tally'd, so mapfix makes it a map
    (: rmap '(: (msum m i acc) (? (< i 5) (msum m (+ i 1) (+ acc (peep m (+ 1 (* 97 i)) 0))) acc)
                h (tablet 0) _ (pin h 1 10) _ (pin h 98 20) _ (pin h 195 30) _ (pin h 292 40) _ (pin h 389 50)
                (msum h 0 0))
       (&& !(= (autogroup rmap) rmap) (150 = (ev rmap)) (= (base-ev rmap) (ev rmap))))
    ; the hash bench: plift hoists scan, mapfix maps its peep, the allocating fns stay interpreted
    (: rhash '(: (hash-run n) (: h (tablet 0)
                  (ins i)      (? (< i n) (: _ (pin h (+ 1 (* 97 i)) i) (ins (+ i 1))) h)
                  (scan i acc) (? (< i n) (scan (+ i 1) (+ acc (peep h (+ 1 (* 97 i)) 0))) acc)
                  (bump i)     (? (< i n) (: k (+ 1 (* 97 i)) _ (pin h k (+ 1 (peep h k 0))) (bump (+ i 1))) h)
                  _ (ins 0) a (scan 0 0) __ (bump 0) (+ a (scan 0 0)))
                (hash-run 50))
       (&& !(= (autogroup rhash) rhash) (2500 = (ev rhash)) (= (base-ev rhash) (ev rhash))))   ; hash-run(50) = 2500
    ; deforestation: defoliate fuses a map/filter/fold over (jot N) into one native counted loop
    (: dq '(: (sumsq n) (foldl (+) 0 (map (\ x (* x x)) (jot n))) (sumsq 100))
       (&& !(= (autogroup dq) dq) (328350 = (ev dq)) (= (base-ev dq) (ev dq))))      ; sum i^2 for i<100
    ; map after filter: the filter guards the fused step; map-after-map composes the element subs
    (: dpf '(: (f n) (foldl (+) 0 (map (+ 1) (filter (\ x (> x 2)) (jot n)))) (f 10))
       (&& !(= (autogroup dpf) dpf) (49 = (ev dpf)) (= (base-ev dpf) (ev dpf))))      ; keep>2, +1, sum = 49
    (: dmm '(: (sm n) (foldl (+) 0 (map (* 2) (map (+ 1) (jot n)))) (sm 5))
       (&& !(= (autogroup dmm) dmm) (30 = (ev dmm)) (= (base-ev dmm) (ev dmm))))      ; (*2).(+1) over 0..4 = 30
    ; a bare foldl over jot (no producers) lowers straight to the loop
    (: dj '(: (s n) (foldl (+) 0 (jot n)) (s 100))
       (&& !(= (autogroup dj) dj) (4950 = (ev dj)) (= (base-ev dj) (ev dj))))         ; sum 0..99 = 4950
    ; soundness: foldl/map don't iterate an (iota N) tray, and fusion keeps that degenerate answer
    (: di '(: (h n) (foldl (+) 0 (map (\ x (* x x)) (iota n))) (h 100))
       (= (base-ev di) (ev di)))                                                         ; iota: degenerate to 0, transparent
    ; a foldl over a list param can't lower (no jot) -> interpreted, value still correct (defoliate no-op)
    (: dl '(: (g l) (foldl (+) 0 l) (g (jot 5)))
       (= (base-ev dl) (ev dl)))                                                         ; 0+1+2+3+4 = 10
    ; foldr: the fused down-loop lifts to a group fn and natives
    (: dr '(: (f n) (foldr (+) 0 (map (\ x (* x x)) (jot n))) (f 100))
       (&& !(= (autogroup dr) dr) (328350 = (ev dr)) (= (base-ev dr) (ev dr))))        ; foldr +.map sq, sum i^2 for i<100
    (: drf '(: (f n) (foldr (+) 0 (filter (\ x (= 1 (% x 2))) (jot n))) (f 20))
       (&& !(= (autogroup drf) drf) (100 = (ev drf)) (= (base-ev drf) (ev drf))))      ; foldr +.filter odd, 1+3+..+19 = 100
    ; loopclose: a polynomial fold over jot (odd/even filter optional) closes to a form in the bound
    (: lcsq '(: (f n) (foldl (+) 0 (map (\ x (* x x)) (jot n))) (f 100))
       (&& !(= (autogroup lcsq) lcsq) (328350 = (ev lcsq)) (= (base-ev lcsq) (ev lcsq))))   ; Σ i^2 for i<100, closed
    (: lcid '(: (f n) (foldl (+) 0 (jot n)) (f 100))
       (&& !(= (autogroup lcid) lcid) (4950 = (ev lcid)) (= (base-ev lcid) (ev lcid))))     ; Σ i for i<100 = C(100,2)
    ; Σ of the odd squares, the odd filter reparametrized k=2j+1
    (: lcodd '(: (f n) (foldl (+) 0 (map (\ x (* x x)) (filter (\ x (= 1 (% x 2))) (jot n)))) (f 20000))
       (&& !(= (autogroup lcodd) lcodd) (1333333330000 = (ev lcodd)) (= (base-ev lcodd) (ev lcodd))))   ; Σ odd k^2 -> a literal, scev keeps the loop
    ; symbolic bound: the closed form is a polynomial in n, exact at multiple n (not one folded point)
    (: lcvar '(: (f n) (foldl (+) 0 (map (\ x (* x x)) (jot n))) (+ (f 7) (* 1000 (f 13))))
       (= (base-ev lcvar) (ev lcvar)))                                                        ; f(7)+1000*f(13), the closed form reused at two n
    ; decline 1: a non-period-2 filter (>2) is left to defoliate; value preserved
    (: lcdec '(: (f n) (foldl (+) 0 (map (\ x (+ x 1)) (filter (\ x (> x 2)) (jot n)))) (f 10))
       (= (base-ev lcdec) (ev lcdec)))                                                        ; keep>2,+1 -> defoliate
    ; decline 2: a piecewise body is not polynomial -> the difference table never dies
    (: lcnp '(: (f n) (foldl (+) 0 (map (\ x (? (< x 5) (* x x) 0)) (jot n))) (f 12))
       (= (base-ev lcnp) (ev lcnp)))                                                          ; 0+1+4+9+16 = 30, defoliated/interpreted
    ; a named-let accumulator with a polynomial step closes too; "fired" is checked through show
    (: lcacc '(: (hof i acc) (? (< i 100) (hof (+ i 1) (+ acc (+ i (+ i i)))) acc) (hof 0 0))
       (&& !(= (show (autogroup lcacc)) (show lcacc)) (14850 = (ev lcacc)) (= (base-ev lcacc) (ev lcacc))))   ; Σ 3k for k<100 = 3·4950
    ; the guard keeps the rewrite faithful at a non-zero start (i=50, i>=N), reused at two starts
    (: lcacc2 '(: (hof i acc) (? (< i 100) (hof (+ i 1) (+ acc (+ i (+ i i)))) acc) (+ (hof 0 0) (* 7 (hof 50 1000))))
       (= (base-ev lcacc2) (ev lcacc2)))                                                       ; (hof 0 0) + 7*(hof 50 1000), closed form reused
    ; decline: a non-polynomial accumulator (%) stays a loop, value kept
    (: lcaccd '(: (g i acc) (? (< i 50) (g (+ i 1) (+ acc (% (* i i) 7))) acc) (g 0 0))
       (= (base-ev lcaccd) (ev lcaccd)))
    ; castbuild: a string-accumulator loop rewrites to a threaded jug
    (: cb1 '(: (build n) (: (go i s) (? (< i n) (go (+ i 1) (+ s (string (+ 48 (% i 10))))) s) (go 0 "")) (tally (build 100)))
       (&& !(= (castbuild cb1) cb1) (100 = (ev cb1)) (= (base-ev cb1) (ev cb1))))             ; a 100-char build -> jug, == interp
    ; the strcat bench: strhash glazes (string lane) while strbuild fills a cask, hash exact
    (: cb2 '(: hmod 1000000007 (strhash s) (: n (tally s) (go i h) (? (< i n) (go (+ i 1) (% (+ (* h 31) (peep s i 0)) hmod)) h) (go 0 0))
               (strbuild n) (: (go i s) (? (< i n) (go (+ i 1) (+ s (string (+ 48 (% i 10))))) s) (go 0 "")) (strhash (strbuild 500)))
       (&& !(= (castbuild cb2) cb2) (= (base-ev cb2) (ev cb2))))                              ; build 500 chars then rolling-hash
    ; multi-char append (the say path): a 2-char piece per step -> (say s (string [.. ..]))
    (: cb3 '(: (build n) (: (go i s) (? (< i n) (go (+ i 1) (+ s (string [(+ 65 (% i 5)) 45]))) s) (go 0 "")) (tally (build 30)))
       (&& !(= (castbuild cb3) cb3) (60 = (ev cb3)) (= (base-ev cb3) (ev cb3))))              ; 30 steps x 2 chars = 60
    ; the recursion in the else branch: handled, branch order preserved
    (: cb4 '(: (build n) (: (go i s) (? (>= i n) s (go (+ i 1) (+ s (string 88)))) (go 0 "")) (tally (build 40)))
       (&& !(= (castbuild cb4) cb4) (40 = (ev cb4)) (= (base-ev cb4) (ev cb4))))
    ; decline: s is also read (tally s), so the recur arg is no pure append -> left alone
    (: cb5 '(: (build n) (: (go i s) (? (< i n) (go (+ i 1) (? (< (tally s) 3) (+ s (string 65)) s)) s) (go 0 "")) (tally (build 10)))
       (&& (= (castbuild cb5) cb5) (= (base-ev cb5) (ev cb5))))                               ; not rewritten, value still exact
    ; all/any: an early-exit loop answering 0/1, run off or short-circuited, with or without a producer
    (: dall '(: (f n) (all (\ x (< x n)) (jot n)) (f 10))
       (&& !(= (autogroup dall) dall) (1 = (ev dall)) (= (base-ev dall) (ev dall))))   ; every i<n -> run off -> 1
    (: dalf '(: (f n) (all (\ x (< x 5)) (jot n)) (f 10))
       (&& !(= (autogroup dalf) dalf) (0 = (ev dalf)) (= (base-ev dalf) (ev dalf))))   ; i=5 fails -> early 0
    (: dany '(: (f n) (any (\ x (> x 7)) (jot n)) (f 10))
       (&& !(= (autogroup dany) dany) (1 = (ev dany)) (= (base-ev dany) (ev dany))))   ; i=8 hits -> early 1
    (: danf '(: (f n) (any (\ x (> x 100)) (jot n)) (f 10))
       (&& !(= (autogroup danf) danf) (0 = (ev danf)) (= (base-ev danf) (ev danf))))   ; none -> run off -> 0
    (: dap '(: (f n) (all (\ x (> x 0)) (map (+ 1) (jot n))) (f 10))
       (&& !(= (autogroup dap) dap) (1 = (ev dap)) (= (base-ev dap) (ev dap))))        ; all (+1 i)>0 -> producer fuses into the guard
    ; a fn that calls out of the fragment (into `link`) drops the whole group -> form unchanged, interpreted
    (: ro '(: (build n) (? (< n 1) () (. n (build (- n 1)))) (build 3))
       (&& (= (autogroup ro) ro) ('(3 2 1) = (ev ro))))   ; left interpreted; base () -> a clean ()-terminated (3 2 1)
    ; autospec: an interpreter ev1 over a static program P folds to P's arithmetic, so the loop natives
    (: sp '(: (ev1 nd x) (? (= (cap nd) 'lit) (caup nd)  (= (cap nd) 'var) x
                            (= (cap nd) 'add) (+ (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))
                            (= (cap nd) 'mul) (* (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))  0)
               P '(add (mul (add (mul (add (mul (lit 2) (var)) (lit 3)) (var)) (lit 5)) (var)) (lit 7))
               (run n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ev1 P i))) a)) 0 0)  (run 1000))
       (&& !(= (autogroup sp) sp) (500001505000 = (ev sp)) (= (base-ev sp) (ev sp))         ; sum P(i) i<1000, native == interp
           (! (occurs? 'ev1 ((autospec sp) 6)))))   ; ev1 folds away: guards autospec firing at all
    ; a different static program specializes to its own residual
    (: sp2 '(: (ev1 nd x) (? (= (cap nd) 'lit) (caup nd)  (= (cap nd) 'var) x
                             (= (cap nd) 'add) (+ (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))
                             (= (cap nd) 'mul) (* (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))  0)
                Q '(mul (add (var) (lit 1)) (add (var) (lit 2)))
                (run n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ev1 Q i))) a)) 0 0)  (run 50))
       (&& !(= (autogroup sp2) sp2) (= (base-ev sp2) (ev sp2))))   ; sum (i+1)(i+2) i<50, native == interp
    ; autospec is a no-op without a defined fn and a static-data binding: a plain fib group is byte-unchanged
    (: nf '(: (fib n) (? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))) (fib 10))
       (= (autospec nf) nf))
    ; the descent guard: a static-list recursion on a counter shrinks its static weight each level, so it terminates
    (: sd '(: (f s n) (? (< n 1) s (f (cup s) (- n 1))) zz '(aa bb cc dd) (f zz 1))
       (&& ('(bb cc dd) = (ev sd)) (= (base-ev sd) (ev sd))))
    ; an unfoldable test (%): descent still bounds the speculative arm
    (: sr '(: (g s k) (? (= 1 (% k 2)) s (g (cup s) (+ k 1))) ww '(a b c) (g ww 0))
       (&& ('(b c) = (ev sr)) (= (base-ev sr) (ev sr))))
    ; dechurch: a literal (N f x) with a function operand lowers to f^N(x) nested, so the group glazes
    (: dch '(: (f i) (2 (+ i) i)                                                          ; (2 (+ i) i) = (+ i (+ i i)) = 3i
               ((: (go k a) (? (< k 100) (go (+ k 1) (+ a (f k))) a)) 0 0))
       (&& !(= (autogroup dch) dch) (14850 = (ev dch)) (= (base-ev dch) (ev dch))))     ; Σ 3k for k<100 = 3·4950
    (: dchk '(: (f i) ((2 (+ i)) i)                                                       ; curried form, must compile the same
                ((: (go k a) (? (< k 100) (go (+ k 1) (+ a (f k))) a)) 0 0))
       (&& !(= (autogroup dchk) dchk) (14850 = (ev dchk)) (= (base-ev dchk) (ev dchk))))
    (: dchl '(: (f i) (2 (\ a (* a a)) i)                                                 ; (2 sqr i) = (sqr (sqr i)) = i^4
                ((: (go k a) (? (< k 10) (go (+ k 1) (+ a (f k))) a)) 0 0))
       (&& !(= (autogroup dchl) dchl) (15333 = (ev dchl)) (= (base-ev dchl) (ev dchl))))  ; Σ k^4 for k<10
    ; a number operand is a power, not church: dechurch leaves it. (2 3 i) = (9 i) = i^9
    (: dpw '(: (g i) (2 i)   ((: (go k a) (? (< k 6) (go (+ k 1) (+ a (g k))) a)) 0 0))
       (&& (55 = (ev dpw)) (= (base-ev dpw) (ev dpw))))                                   ; Σ k^2 for k<6 = 55, untouched
    (: dpw2 '(: (h i) (2 3 i) ((: (go k a) (? (< k 4) (go (+ k 1) (+ a (h k))) a)) 0 0))
       (&& (20196 = (ev dpw2)) (= (base-ev dpw2) (ev dpw2))))                             ; Σ k^9 for k<4 = 20196, untouched
    ; delet: a pure value-let in a fn body inlines, so the fn joins the group
    (: lb '(: (f x) (: q (* x x) (+ q q)) (f 5))
       (&& !(= (autogroup lb) lb) (50 = (ev lb)) (= (base-ev lb) (ev lb))))                ; q=x*x, 2q = 50
    ; a chain of bindings, the first used twice -- but call-free (dup-cheap), so it inlines freely
    (: lc '(: (f x) (: a (+ x 1) b (* a 2) (+ a b)) (f 5))
       (&& !(= (autogroup lc) lc) (18 = (ev lc)) (= (base-ev lc) (ev lc))))                ; a=6,b=12 -> 18
    ; a binding holding a recursive sibling call, used once -> inlines; the fn glazes and calls native g
    (: ls '(: (g n) (? (< n 1) 0 (+ n (g (- n 1)))) (f n) (: h (g n) (* h 2)) (f 5))
       (&& !(= (autogroup ls) ls) (30 = (ev ls)) (= (base-ev ls) (ev ls))))                ; g(5)=15, h*2 = 30
    ; a value-let wrapping a named-let loop: delet inlines k into the loop, lift then glazes it
    (: lw '(: (f n) (: k (* n 1) ((: (go i a) (? (< i k) (go (+ i 1) (+ a i)) a)) 0 0)) (f 10))
       (&& !(= (autogroup lw) lw) (45 = (ev lw)) (= (base-ev lw) (ev lw))))                ; sum 0..9 = 45
    ; bail: a call binding used twice is not inlined, so f interprets (g still glazes)
    (: lbail '(: (g n) (? (< n 1) 1 (* n (g (- n 1)))) (f n) (: a (g n) (+ a a)) (f 5))
       (= (base-ev lbail) (ev lbail)))                                                        ; g(5)=120, a+a = 240, interpreted
    ; a value-let nested in a tail call's arg: delet-body recurses to it; dup-cheap x inlines twice
    (: ldeep '(: (f N) (: (lp i acc) (? (< i N) (lp (+ i 1) (: x (% i 13) (+ acc (* x x)))) acc) (lp 0 0)) (f 20))
       (&& !(= (autogroup ldeep) ldeep) (741 = (ev ldeep)) (= (base-ev ldeep) (ev ldeep))))  ; sum (i%13)^2 for i<20, native == interp
    ; an effectful `_`-bound let is kept, not inlined away; the fn stays interpreted
    (: leff '(: (f N) (: (lp i b) (? (< i N) (: _ (pin b 0 (+ 1 (peep b 0 0))) (lp (+ i 1) b)) (peep b 0 0)) (lp 0 (cask 1))) (f 7))
       (= (base-ev leff) (ev leff)))                                                          ; pin 7x -> 7, write preserved
    ; debool: &&/||/min/max/abs lower to ?, so the fn glazes
    (: band '(: (f x n) (? (&& (< x n) (> x 0)) 1 0) (f 5 9))
       (&& !(= (autogroup band) band) (1 = (ev band)) (= (base-ev band) (ev band))))        ; 5<9 && 5>0 -> 1
    (: bor '(: (f x) (? (|| (< x 0) (> x 9)) 1 0) (f 5))
       (&& !(= (autogroup bor) bor) (0 = (ev bor)) (= (base-ev bor) (ev bor))))             ; neither -> 0
    (: babs '(: (f x) (+ (abs x) 1) (f -5))
       (&& !(= (autogroup babs) babs) (6 = (ev babs)) (= (base-ev babs) (ev babs))))        ; |-5|+1 -> 6
    ; abs inside a hot loop: |i-50| summed for i<100 -> the running clamp natives
    (: babl '(: (f n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (abs (- i 50)))) a)) 0 0) (f 100))
       (&& !(= (autogroup babl) babl) (2500 = (ev babl)) (= (base-ev babl) (ev babl))))      ; sum|i-50| = 2*(1+..+50) = 2550-50 = 2500
    ; nested compound: && of a cmp and an ||, guarding an abs -- all collapse to ?
    (: bnest '(: (f x) (? (&& (> x 0) (|| (< x 5) (> x 10))) (abs x) 0) (f 3))
       (&& !(= (autogroup bnest) bnest) (3 = (ev bnest)) (= (base-ev bnest) (ev bnest))))    ; 3>0 && 3<5 -> abs 3 = 3
    ; bail: || whose first operand is a recursive call would duplicate it -> f interprets (sound)
    (: bbail '(: (g n) (? (< n 1) 0 (+ n (g (- n 1)))) (f n) (? (|| (g n) (< n 0)) 1 0) (f 5))
       (= (base-ev bbail) (ev bbail)))                                                        ; (|| g(5)=15 ..) truthy -> 1, interpreted (g still glazes)
    ; || and abs nested in a loop accumulator
    (: bdeep '(: (f n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (? (|| (< i 100) (> i 900)) (abs (- i 500)) 0))) a)) 0 0) (f 1000))
       (&& !(= (autogroup bdeep) bdeep) (= (base-ev bdeep) (ev bdeep))))                     ; native == interp on the nested ||/abs loop
    ; a debool'd helper called by a loop sibling: clamp glazes as a group fn, run_go calls it native
    (: bclamp '(: (clamp i) (? (|| (< i 100) (> i 900)) (abs (- i 500)) 0)
                  (run n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (clamp i))) a)) 0 0) (run 1000))
       (&& !(= (autogroup bclamp) bclamp) (= (base-ev bclamp) (ev bclamp)))))                ; native == interp; clamp a glazed sibling
   (say err "glaze auto: native codegen ok
")))

; --- the neutral IR: x86 natives == interp; a64 only assembles (data) ---
(base-ev '(: ev base-ev
   _ (assert
      ; an unbound name reads (), and (() x) = 1 fakes a pass: assert these are bound
      (lit? assemble) (lit? jitir) (lit? jitnir) (lit? jitgroupir) (lit? coreir) (lit? deoptir)
      (lit? cggir) (lit? cggvir) (lit? consir) (lit? mkhir) (lit? mkouterir)
      (31 = ((jitir '(\ x (+ (* x 3) 1)) 'x64) 10))
      (= ((ev '(\ x (+ (* x 3) 1))) 10) ((jitir '(\ x (+ (* x 3) 1)) 'x64) 10))
      (49 = ((jitir '(\ x (* x x)) 'x64) 7))
      (8 = ((jitir '(\ x (- x 2)) 'x64) 10)) (-8 = ((jitir '(\ x (- 2 x)) 'x64) 10))     ; - keeps a-b order
      (3 = ((jitir '(\ x (// x 3)) 'x64) 10)) (1 = ((jitir '(\ x (% x 7)) 'x64) 8))
      (8 = ((jitir '(\ x (& x 12)) 'x64) 10)) (3 = ((jitir '(\ x (| x 1)) 'x64) 2)) (15 = ((jitir '(\ x (^ x 5)) 'x64) 10))
      (1 = ((jitir '(\ x (< x 5)) 'x64) 3)) (0 = ((jitir '(\ x (< x 5)) 'x64) 9))         ; cmp -> set
      (1 = ((jitir '(\ x (<= x 5)) 'x64) 5)) (1 = ((jitir '(\ x (>= x 5)) 'x64) 9)) (1 = ((jitir '(\ x (= x 5)) 'x64) 5))
      (7 = ((jitir '(\ x (? (< x 0) (- 0 x) x)) 'x64) -7)) (0 = ((jitir '(\ x (? (< x 0) (- 0 x) x)) 'x64) 0))   ; abs (?)
      (9000000000000000000 = ((jitir '(\ x (* x x)) 'x64) 3000000000))                    ; overflow -> deopt -> bignum
      (16000000000000000001 = ((jitir '(\ x (+ 1 (* x x))) 'x64) 4000000000))             ; mid-nest overflow: sp unwind on deopt
      (= (// 10 0) ((jitir '(\ x (// x 0)) 'x64) 10))                                      ; /-by-0 guard -> deopt -> interp
      (= (+ '(1 2) 1) ((jitir '(\ x (+ x 1)) 'x64) '(1 2)))                                ; non-fixnum arg -> deopt -> interp
      ((\ x (+ (* x 3) 1)) = (jitir '(\ x (+ (* x 3) 1)) 'x64))
      (= '(2 4 6) (map (jitir '(\ x (+ x 1)) 'x64) '(1 3 5)))
      (= 1 ((: (go i a) (? (< i 60) (go (+ i 1) (&& a (= ((jitir ['\ 'x ['* 'x i]] 'x64) 7) (* 7 i)))) a)) 0 1))
      ; n-ary lane (jitnir)
      (7 = ((jitnir '(\ x y (+ x y)) 'x64) 3 4)) (7 = (((jitnir '(\ x y (+ x y)) 'x64) 3) 4))      ; saturated + curried
      (= ((ev '(\ x y (- (* x x) y))) 5 3) ((jitnir '(\ x y (- (* x x) y)) 'x64) 5 3))
      (16000000000000000000 = ((jitnir '(\ x y (- (* x x) y)) 'x64) 4000000000 0))                 ; overflow -> deopt -> bignum
      (13 = ((jitnir '(\ x y z (+ (+ x y) (* z 2))) 'x64) 1 2 5))
      (13 = (((jitnir '(\ x y z (+ (+ x y) (* z 2))) 'x64) 1) 2 5))                                 ; arity-3, saturate at any split
      ((\ x y z (+ (+ x y) (* z 2))) = (jitnir '(\ x y z (+ (+ x y) (* z 2))) 'x64))
      (16000000000000000005 = ((jitnir '(\ x y z (+ (+ (* x x) y) z)) 'x64) 4000000000 0 5))        ; deopt through a middle param
      (3 = ((jitnir '(\ x y (// x y)) 'x64) 13 4)) (1 = ((jitnir '(\ x y (% x y)) 'x64) 8 7))       ; n-ary // and %
      ; a64: the same source assembles, and differs from x64
      (< 0 (tally (peep (assemble 'a64 (coreir 'a64 '(x) '(+ (* x 3) 1) (deoptir 'a64 0))) 'bytes 0)))   ; leaf
      (< 0 (tally (peep (assemble 'a64 (coreir 'a64 '(x y) '(+ (* x x) y) (deoptir 'a64 1))) 'bytes 0))) ; n-ary (deopt -> interp body)
      !(= (peep (assemble 'x64   (coreir 'x64   '(x) '(+ x 1) (deoptir 'x64 0))) 'bytes 0)
          (peep (assemble 'a64 (coreir 'a64 '(x) '(+ x 1) (deoptir 'a64 0))) 'bytes 0))       ; per-target codegen differs
      ; call-out bridge: the drive IR lays for a64 too, and differs from x64
      (< 0 (tally (peep (assemble 'a64 (calloutir 'a64 '+ 'i)) 'bytes 0)))                         ; global-F sum-over-(F i)
      (< 0 (tally (peep (assemble 'a64 (calloutframeir 'a64 1 0 2 '+ 'i)) 'bytes 0)))              ; frame F@1 N@0 arity 2
      !(= (peep (assemble 'x64   (calloutir 'x64 '+ 'i)) 'bytes 0)
          (peep (assemble 'a64 (calloutir 'a64 '+ 'i)) 'bytes 0))                                  ; per-target callout codegen differs
      !(= (peep (assemble 'x64 (calloutir 'x64 '+ 'i)) 'bytes 0)
          (peep (assemble 'x64 (calloutir 'x64 '* 'i)) 'bytes 0))                                      ; the * fold lays differently from + (mulo accumulator)
      !(= (peep (assemble 'x64 (calloutir 'x64 '+ 'i)) 'bytes 0)
          (peep (assemble 'x64 (calloutir 'x64 '+ '(* i i))) 'bytes 0))                                ; a computed arg (F (* i i)) lays differently from bare (F i)
      ; group lane (jitgroupir): mutually recursive first-order integer fns
      (55 = ((jitgroupir [(. '(fib n) '(? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))] 'fib 'x64) 10))
      (= ((ev '(: (fib n) (? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))) fib)) 25)
         ((jitgroupir [(. '(fib n) '(? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))] 'fib 'x64) 25))            ; fib(25)=75025 == interp
      (1180591620717411303424 = ((jitgroupir [(. '(p2 n) '(? (< n 1) 1 (* 2 (p2 (- n 1)))))] 'p2 'x64) 70))   ; 2^70: mul overflow -> ovf -> deopt -> bignum
      ; int-param fixnum guard: a heap arg must deopt, never re-tag into a garbage fixnum
      (: gidh ((jitgroupir [(. '(id1 x) 'x)] 'id1 'x64) '(a b)) (&& ('(a b) = gidh) !(charm? gidh)))     ; identity on a list -> the list, not a mangled fixnum
      (= (+ '(1 2) 1) ((jitgroupir [(. '(inc n) '(+ n 1))] 'inc 'x64) '(1 2)))                            ; arith on a heap arg -> deopt == interp
      ; // and % in the group lane, with the /-by-0 deopt
      (3 = ((jitgroupir [(. '(q n d) '(// n d))] 'q 'x64) 10 3)) (-3 = ((jitgroupir [(. '(q n d) '(// n d))] 'q 'x64) -10 3))
      (1 = ((jitgroupir [(. '(r n d) '(% n d))] 'r 'x64) 10 3)) (= (% 7 0) ((jitgroupir [(. '(r n d) '(% n d))] 'r 'x64) 7 0))       ; /-by-0 -> deopt -> interp
      (7 = ((jitgroupir [(. '(tak x y z) '(? (< y x) (tak (tak (- x 1) y z) (tak (- y 1) z x) (tak (- z 1) x y)) z))] 'tak 'x64) 18 12 6))     ; multi-arg, nested self-calls
      (7 = (((jitgroupir [(. '(tak x y z) '(? (< y x) (tak (tak (- x 1) y z) (tak (- y 1) z x) (tak (- z 1) x y)) z))] 'tak 'x64) 18 12) 6))   ; ... curries at any split
      (: eo [(. '(evn n) '(? (= n 0) 1 (odn (- n 1)))) (. '(odn n) '(? (= n 0) 0 (evn (- n 1))))]
         (&& (1 = ((jitgroupir eo 'evn 'x64) 10)) (0 = ((jitgroupir eo 'evn 'x64) 7)) (1 = ((jitgroupir eo 'odn 'x64) 7))))   ; mutual recursion (either entry)
      (= (jitgroupir [(. '(fib n) '(? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))] 'fib 'x64)
         (jitgroupir [(. '(fib n) '(? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))] 'fib 'x64))                 ; two natives, same source -> = (transparent)
      ; jitgroupirx takes its deopt target directly; a native is its twin to `=`
      (: dfs [(. '(fib n) '(? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))]  dopt (jitgroupir dfs 'fib 'x64)
         (&& (55 = ((jitgroupirx dfs 'fib 'x64 dopt) 10))
             (= (jitgroupirx dfs 'fib 'x64 dopt) (jitgroupirx dfs 'fib 'x64 dopt))))
      ; string lane: s kind-guarded and passed raw
      (: data (string [72 105 90 33 65])                                                                         ; "HiZ!A": byte-sum 365, len 5
         sbn (jitgroupir [(. '(sb s i) '(? (< i 0) 0 (+ (peep s i 0) (sb s (- i 1)))))] 'sb 'x64)              ; recursive byte-sum
         tln (jitgroupir [(. '(tl s) '(tally s))] 'tl 'x64)
         pkn (jitgroupir [(. '(pk s i) '(peep s i 0))] 'pk 'x64)
         (&& (365 = (sbn data 4)) (= ((ev '(: (sb s i) (? (< i 0) 0 (+ (peep s i 0) (sb s (- i 1)))) sb)) data 4) (sbn data 4))   ; native byte-sum == interp
             (5 = (tln data)) (! (tln 5))                                                                         ; a fixnum arg deopts -> interp tally = ()
             (72 = (pkn data 0)) (0 = (pkn data 99))))                                                            ; in bounds; oob -> the default, no deopt
      ; cask lane: pin stores the low byte and answers c, so it threads as a call arg
      (: c (cask 5)
         fil (jitgroupir [(. '(fill c i) '(? (< i 0) 0 (fill (pin c i (+ 65 i)) (- i 1))))] 'fill 'x64)          ; recurses on pin's answer
         _ (fil c 4)
         (&& (= '(65 66 67 68 69) [(peep c 0 0) (peep c 1 0) (peep c 2 0) (peep c 3 0) (peep c 4 0)])               ; each byte written natively
             (88 = (: c2 (cask 4) _ ((jitgroupir [(. '(g c) '(pin c 2 88))] 'g 'x64) c2) (peep c2 2 0)))))       ; a single native pin -> byte 2
      ; map lane (mpeep/mpin): m kind-guarded and raw
      (: rn (jitgroupir [(. '(run m i) '(? (< i 0) (mpeep m 3 -1) (run (mpin m (+ 1 i) (* 10 i)) (- i 1))))] 'run 'x64)     ; fill keys 1..i+1 with 10*i, then read key 3
         m16 (tablet 16) r16 (rn m16 8)                                                                              ; presized -> pure native
         m2 (tablet 2) r2 (rn m2 8)                                                                                  ; undersized -> grow deopt -> interp grows
         (&& (20 = r16) (40 = (peep m16 5 -1)) (0 = (peep m16 1 -1))                                                 ; native mpin wrote real entries
             (20 = r2) (80 = (peep m2 9 -1))                                                                         ; grow deopt faithful
             (-1 = ((jitgroupir [(. '(g m k) '(mpeep m k -1))] 'g 'x64) 5 3))))                                   ; a fixnum map arg deopts -> the default
      ; chain lane: no entry guard (two? is total); cap/cup guard inline
      (: (mk d) (? (< d 1) 0 (. (mk (- d 1)) (mk (- d 1))))                                                       ; an interp tree builder
         ckn (jitgroupir [(. '(ck t) '(? (two? t) (+ 1 (+ (ck (cap t)) (ck (cup t)))) 0))] 'ck 'x64)              ; native node-count walk
         (&& (255 = (ckn (mk 8))) (15 = (ckn (mk 4)))                                                                ; 2^d-1 nodes, native cap/cup recursion
             (0 = (ckn 0)) (1 = (ckn (. 0 ())))))                                                                  ; two? total: a fixnum leaf -> 0; a lone chain -> 1
      ; tco: a tail self-call reuses its frame; 1M deep would overflow without it
      (1000000 = ((jitgroupir [(. '(loop i) '(? (< i 1000000) (loop (+ i 1)) i))] 'loop 'x64) 0))                 ; single-arg counted loop
      (499999500000 = ((jitgroupir [(. '(sm i a) '(? (< i 1000000) (sm (+ i 1) (+ a i)) a))] 'sm 'x64) 0 0))      ; multi-arg tail accumulator (sum 0..1M-1)
      ; a64: the group assembles
      (< 0 (tally (peep (assemble 'a64 (bcat [(mkouterir 'a64 1 'fib 1 0 () () () () ())
                (mkhir 'a64 '(fib) 'fib '(n) '(? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))])) 'bytes 0))))
   (say err "glaze emit-ir: neutral-IR leaf + n-ary + group lanes ok (x86 == interp; a64 assembles)\n")))

; --- delet soundness: only dup-cheap values inline; a user-fn call hides its effects, so it never inlines ---
(: j (jug 0)
   (dsw v) (: _ (put j (255 & v)) (put j (255 & (v >> 8)))) ; a 16-bit write
   (dsleaf n) ((4 - (n % 4)) % 4)                           ; the pure leaf that triggers the walk
   _ (dsw 513)                                              ; bytes 1 then 2
   t (tap [1 2 3 4])
   (dsr2 u) (: a (see t) b (see t) (a | (b << 8)))
   (dsr4 u) (: a (dsr2 ()) b (dsr2 ()) (a | (b << 16)))                                            ; a 32-bit read
   v (dsr4 ())
   _ (assert
      (0 = (dsleaf 20))
      (slurp j = (string 1 + string 2)) ; both bytes, in order: the _-bound put kept
      (67305985 = v))                   ; 0x04030201: the two dsr2 calls read in source order
   (say err "glaze auto: delet keeps _-bound effects + call-binding order ok\n"))

; --- swheads opfixes first: a raw infix operand is no call head ---
(: swh (G 'swheads)
   h1 (swh '(? (two? l) (pm9 x (want9 = 3 ? (cup l) l)) 0) '(x l) ())
   h2 (swh '(: a (want9 1 2) (+ a x)) '(x) ())
   _ (assert
      (! (elem 'want9 h1)) (1 = (elem 'pm9 h1))                             ; a free operand is no head; the real call is
      (1 = (elem 'want9 h2))                                                   ; a called global still arrives
      (! (elem 'x h2)))                                                        ; ... and the binder set still filters
   (say err "glaze auto: swheads reads opfixed source -- no operand fake heads\n"))

; --- the point-= grammar: (= P (cap ..)) admits, so elem is a group native; charm and string keys deopt ---
(: mm (nom 0)
   ; admission: an admitted form splices the native closure, a declined one keeps the quoted body
   adm (G 'autogroup '(: (pm1 x l) (? (two? l) (? (= x (cap l)) 1 (pm1 x (cup l))) 0) (pm1 'b '(a b))))
   _ (assert
      (! (two? (caup >adm))) (1 = (ev adm))                  ; admitted: native spliced, and it answers
      (1 = (elem 'b '(a b c))) (0 = (elem 'z '(a b c)))      ; nom key, native walk
      (1 = (elem 2 '(1 2 3))) (0 = (elem 9 '(1 2 3)))        ; charm key -> entry deopt (bridges), interp stays right
      (1 = (elem 2 '(2.0 4))) (1 = (elem 2 '(4 2.0 2)))      ; the numeric bridge, through the fallback
      (0 = (elem 5 '(6.0 7.0)))                              ; deopt lane, false stays false
      (1 = (elem "ab" '(1 "ab"))) (0 = (elem "zz" '("ab")))  ; string key -> entry deopt, structural =
      (1 = (elem 'z '(1 "s" (x y) 2.5 z)))                   ; nom key walks every car kind natively
      (0 = (elem 'q '("s" 2.5 (a))))                         ; ... and a miss over heap cars
      (1 = (elem mm (. 1 (. mm ())))) (0 = (elem mm '(a b))) ; a mint key rides the guard
      (0 = (elem () '(1 2))) (1 = (elem () (. () ())))       ; the zero point is a mint
      (0 = (elem 'x ())) (0 = (elem 'x 5))                   ; no chain -> the walk never starts
      (200000 = ((: (go i a) (i < 200000 ? (go (i + 1) (a + elem 'q '(a b q))) a)) 0 0))
      (: pg (jitgroupir [(. '(pm2 x l) '(? (two? l) (? (= x (cap l)) 1 (pm2 x (cup l))) 0))] 'pm2 'x64)     ; the group lane direct: exec x64 ...
         (1 = pg 'b '(a b) && 0 = pg 'z '(a b) && 0 = pg 'z 7))
      (0 < #(peep (assemble 'a64 (bcat [(mkouterir 'a64 2 'pm3 2 0 () () () () '(0))     ; ... and the point-guarded outer assembles on a64
                (mkhir 'a64 '(pm3) 'pm3 '(x l) '(? (two? l) (? (= x (cap l)) 1 (pm3 x (cup l))) 0))])) 'bytes 0)))
   (say err "glaze emit: the point-= grammar -- elem group-native, admission + both deopt lanes ok\n"))

(say err "test/glaze-x86: emit + auto + ir native codegen ok\n")
