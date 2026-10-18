; the natjit creation hook: a qualifying leaf is native-backed when its closure is built. its own
; lane (test_hook). each law claims the answer and that the hook fired, since bytecode computes it too
(assert (lit? natjit) (lit? fires) (lit? fired?))            ; unbound, every claim below would read 1

(assert
    ; --- embedded leaves: native at creation, computing right
    (: n (peep fires () 0)
       (31 = (ev '(: f (\ x (+ (* x 3) 1)) (f 10)))                ; leaf in a let body
        && fired? n))                                               ; ..and the hook fired
    (9000000000000000000 = (ev '((\ x (* x x)) 3000000000)))        ; applied inline, deopts to a bignum
    (3 = (ev '(: g (\ x (cap x)) (g '(3 4)))))                      ; a chain body: the amble owns it
    ; --- a float-result leaf boxes a gem, == interp, deopts on a non-float arg
    (: n (peep fires () 0)  fr (ev '(: f (\ x (+ (* x 1.5) 2.0)) f))         ; the float lane fires
       (gem? (fr 4) && 8.0 = (fr 4) && (fr 4 = ((x \ (x * 1.5) + 2.0) 4))      ; == the interpreter
        && fired? n && (fr 'nope = ((x \ (x * 1.5) + 2.0) 'nope))))            ; ..and a non-float arg deopts
    ; --- an N-var loop (fib): a native back-edge, == interp
    (: n (peep fires () 0)  fib (ev '(: f (\ m ((: (go i a b) (? (< i m) (go (+ i 1) b (+ a b)) a)) 0 0 1)) f))
       (55 = (fib 10) && fired? n
        && (fib 20 = ((m \ (: (go i a b) (i < m ? (go (i + 1) b (a + b)) a)) 0 0 1) 20))         ; == the interpreter
        && (fib 100 = ((m \ (: (go i a b) (i < m ? (go (i + 1) b (a + b)) a)) 0 0 1) 100))))     ; ..past fixnum, deopted to its thread
    ; --- a capturing closure: native and transparent
    (: mk (ev '(\ y (\ x (+ x y))))  a5 (mk 5)           ; the inner lambda is the embedded one
       (15 = (a5 10) && ('(6 7 8) = (map a5 '(1 2 3)))
        && a5 = ((y \ (x \ x + y)) 5)))                    ; ..= the interpreter's instance
    ; --- transparency on a capturing leaf pulled out as a value (a closed one would hoist)
    (: id (ev '(\ z (\ x (+ x z))))  f (id 9)  g (id 9)  ; a fresh native cell per call
       (19 = (f 10) && f = ((z \ (x \ x + z)) 9)))
    ; --- the self seam: a tail self-call loops, a non-tail one takes the direct self frame
    (: n (peep fires () 0)
       r (ev '(: (sum f z l) (? (two? l) (sum f (f z (cap l)) (cup l)) z) (sum (\ a x (+ a (* x x))) 0 '(1 2 3 4))))
       (30 = r && fired? n))
    (: n (peep fires () 0)
       r (ev '(: p 7 (f k) (? (< 0 k) (+ p (f (- k 1))) 0) (f 3)))
       (21 = r && fired? n))
    ; --- the generic = stays native and right across kinds: points inline, structure drives
    (: n (peep fires () 0)
       mem (ev '(: (mem x l) (? (two? l) (? (= x (cap l)) 1 (mem x (cup l))) 0) mem))
       (1 = (mem 'b '(a b c)) && 0 = (mem 'z '(a b c)) && 1 = (mem "s" '("q" "s"))
        && 1 = (mem 2.0 '(1 2 3)) && 0 = (mem 2.5 '(1 2 3)) && fired? n))
    ; --- tagged surfaces untag: a synthesized body-lambda's apx/iop forms compile
    (: n (peep fires () 0)
       r1 (ev '(: p 5 q (+ p 2) (* q q)))
       r2 (ev '(: f (\ a b (+ a b)) (f 3 4)))
       (49 = r1 && 7 = r2 && fired? n))
    ; --- VALUE lets: the destructuring idiom rides slots; order, _, and the let-bound callee
    (: n (peep fires () 0)
       dw (ev '(: (dw x l) (? (two? l) (: h (cap l) t (cup l) (? (= h x) 1 (dw x t))) 0) dw))
       (fired? n && 1 = (dw 'b '(a b c)) && 0 = (dw 'z '(a b c)) && 0 = (dw 3 ())
        && (dw 2.0 '(1 2) = ((x \ l \ two? l ? (: h <l t >l (h = x ? 1 (dw x t))) 0) 2.0 '(1 2)))))
    ; --- the owned op set widens: // % & | ^ (fixnum-guarded, trunc toward zero), == interp
    (: n (peep fires () 0)
       h (ev '(: (h a b) (? (< 0 b) (+ (+ (// a b) (% a b)) (+ (& a b) (+ (| a b) (^ a b)))) 0) h))
       i (a \ b \ ((a // b) + (a % b)) + ((a & b) + ((a | b) + (a ^ b))))
       (fired? n && (h 17 5 = i 17 5) && (h -17 8 = i -17 8) && 0 = (h 17 0)))
    ; --- an inner lambda in a driver body is built fresh per evaluation, a closed one shared. the
    ; inner bodies decline every lane, so the fire is the driver's
    (: n (peep fires () 0)
       ad (ev '(: (ad f l) (? (two? l) (. (f (\ x (+ (tally (show x)) (cap l)))) (ad f (cup l))) ()) ad))
       cs (ad (g \ g) '(1 2))
       (fired? n && ('(4 5 6) = (ad (g \ g 100) '(1 2 3)))
        && !(cap cs = cap >cs)
        && (cap cs = ((l \ (x \ tally (show x) + cap l)) '(1 2)))))
    (: n (peep fires () 0)
       ac (ev '(: (ac f l) (? (two? l) (. (f (\ x (+ (tally (show x)) 1))) (ac f (cup l))) ()) ac))
       cs (ac (g \ g) '(1 2))
       (fired? n && ('(2 2) = (ac (g \ g 5) '(1 2))) && (cap cs = cap >cs)))
    ; --- the negations, a cond chain, and an inlined sibling's mint-bound arg
    (: n (peep fires () 0)
       lay (ev '(: (pad be n) (list n n) (at l k) (? (= k 0) (cap l) (at (cup l) (- k 1)))
                   (lay p acc) (? !(two? p) (rev acc)
                                  (= (cap (cap p)) 'label) (: _ (pin (tablet 0) (at (cap p) 1) 0) (lay (cup p) acc))
                                  (= (cap (cap p)) 'align) (: r (pad 0 (at (cap p) 1)) (lay (cup p) (. (cap r) acc)))
                                  (: r (cap (cap p)) (lay (cup p) (. r acc))))
                   lay))
       (fired? n && ('(add 4 mov) = (lay '((label a) (add) (align 4) (mov)) ()))
        && (lay '((x) (align 2)) () = '(x 2))))
    ; --- the leaf grammar is exact-arity: (+ x 1 2) is the tower ((+ x 1) 2), never x + 1
    (: f (ev '(\ x (+ x 1 2)))  g (x \ (+ x 1 2))
       (16 = (f 3) && (f 3 = g 3) && (f 5 = g 5)))
    ; ... and under a named-let whose loop var shadows the frame: the site's import renames with it
    (: n (peep fires () 0)
       mk (ev '(\ l ((: (go l acc) (? (two? l) (go (cup l) (. (\ y (* y (tally (show (cap l))))) acc)) acc)) l ())))
       (fired? n && ('(2 2 2) = (map (c \ c 2) (mk '(1 2 3)))) && ('(4 2) = (map (c \ c 2) (mk '(1 10))))))
    ; --- the restart law: a deopt re-runs from the restart point, so nothing is written twice
    (: f (ev '(: (mk o n k) (? (<= n 0) (slurp o) (: _ (put o (+ 97 (% k 5))) (mk o (- n 1) (+ (* k 7) 3)))) mk))
       ("ebadebadebadebadebadebadebadebadebadebad" = (f (jug 0) 40 9)))     ; a self-call loop restarts at the running iteration
    (: f (ev '(: (build o n) ((: (go m k) (? (<= m 0) (slurp o) (: _ (put o (+ 97 (% k 5))) (go (- m 1) (+ (* k 7) 3))))) n 9) build))
       ("ebadebadebadebadebadebadebadebadebadebad" = (f (jug 0) 40)))       ; a named-let restarts the whole loop
    ; --- a constant past fixnum range is no immediate: declined, never laid truncated
    (: f (ev '(\ x (: y 6000000000000000000 (+ x y))))
       (6000000000000000000 = (f 0) && (f 0 = ((x \ (: y 6000000000000000000 (x + y))) 0))))
    (: f (ev '(\ x (: y -6000000000000000000 (+ x y))))
       (-6000000000000000000 = (f 0)))
    (: f (ev '(\ n (: (go i a) (? (< i n) (go (+ i 1) 6000000000000000000) a) (go 0 0))))
       (6000000000000000000 = (f 4)))                            ; ..and one left behind in a loop
    (: f (ev '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a 6000000000000000000)) a)) 0 0)))
       (6000000000000000000 = (f 1)))
    ; --- the fallback stubs: a guard failing past a call computes the op in place; no call runs twice
    (: n (peep fires () 0)
       f (ev '(: (g h m) (? (< m 1) () ((h m) . (g h (- m 1)))) g))
       (fired? n && ('(9 4 1) = f (x \ x * x) 3)))                     ; a cons after the non-tail self-call
    (: n (peep fires () 0)
       f (ev '(: (g h m) (? (< m 1) 0 (+ (h m) (g h (- m 1)))) g))
       (fired? n && (12000000000000000000 = f (_ \ 4000000000000000000) 3)))   ; the + stub answers the bignum
    (: n (peep fires () 0)
       f (ev '(: (g h m) (? (< m 1) 0 (? (h m) (+ 1 (g h (- m 1))) (g h (- m 1)))) g))
       (fired? n && (2 = f (x \ x = 2 ? () [x]) 3)))                     ; the bit stub decides
    ; ... and the stub's bit is the glaze's own, whatever the book binds to `bit`
    (: old bit
       _ (ev '(: bit (\ a b 1)))
       n (peep fires () 0)
       f (ev '(: (g h m) (: y (? (< m 1) (h m) ()) (? y 8 9)) g))
       r (f (x \ x) 1)
       _ (ev [': 'bit ['quote old]])
       (fired? n && 9 = r && 0 = bit ()))
    (: o (jug 0) k {0}
       f (ev '(: (g h m) (? (< m 1) 0 (+ (h m) (g h (- m 1)))) g))
       _ (f (x \ (: _ (pin k 0 (1 + peep k 0 0)) _ (put o (97 + x)) 4000000000000000000)) 3)
       ((3 = peep k 0 0) && ("dcb" = slurp o)))                          ; three calls, three effects, none replayed
    ; ... and a lane keeps calls no restart can reach
    (: n (peep fires () 0)
       f (ev '(: (go i m a) (? (< i m) (go (+ i 1) m (tally (show (+ a i)))) a) go))
       (fired? n && 2 = (f 0 20 0)))
    ; --- a literal divisor shifts or multiplies by its magic, truncating toward zero
    (: n (peep fires () 0)
       f (ev '(\ x (+ (* 100 (// x 7)) (% x 7))))
       (fired? n && ('(-1401 -1 0 1 1401 20000 -20000) = map f '(-99 -1 0 1 99 1400 -1400))))
    (: n (peep fires () 0)
       f (ev '(\ x (+ (* 10000 (// x 4096)) (% x 4096))))
       (fired? n && ('(-241695 -10000 -4095 -1 0 4095 10000 241695) = map f '(-99999 -4096 -4095 -1 0 4095 4096 99999))))
    (: n (peep fires () 0)
       f (ev '(\ x (+ (* 1000 (// x 1000003)) (% x 1000003))))
       (fired? n && ('(-3001 -1000 -1000002 0 1000002 1000 3001) = map f '(-3000010 -1000003 -1000002 0 1000002 1000003 3000010))))
    (: n (peep fires () 0)
       f (ev '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (+ (% (- i 5) 4) (// (- i 5) 3)))) a)) 0 0)))
       (fired? n && 4 = (f 12)))
    (: n (peep fires () 0)
       f (ev '(: (g h m) (? (< m 1) 0 (+ (% (h m) 4096) (+ (// (h m) 10) (g h (- m 1))))) g))
       (fired? n && 6504 = (f (x \ 1000 - (x * (x * x))) 12)))
    ; --- a helper above the sibling it calls compiles into the cell its callers already hold
    (: n (peep fires () 0)
       _ (ev '(module (gzh gzh-sum) (: (gzh-sum l acc) (? (two? l) (gzh-sum >l (acc + gzh-sq <l)) acc) (gzh-sq x) (x * x))))
       f (cite 'gzh 'gzh-sum)
       (fired? n && nat? f && 14 = (f [1 2 3] 0)))
    ; --- a saturated call's frame must not land on a tablet a call-out just made in the last free
    ; words: swept over m, the 15th argument stays a tablet
    (: n (peep fires () 0)
       f (ev '(: (gzf16 a b c d e f g h i j k l m n o p) (? (tablet? o) 0 1)
                 (gzfmk m) (: g (gauge 0)  r (- (- (g 0) (g 1)) (g 2))
                              _ (? (> r (+ m 64)) (cask (* 8 (- (- r m) 16))))
                              (tablet 0))
                 (gzfrun m bad) (? (< m 0) bad
                                   (: x (list m m)
                                      (gzfrun (- m 1) (+ bad (gzf16 x x x x x x x x x x x x x x (gzfmk m) x)))))
                 gzfrun))
       (fired? n && 0 = (f 120 0)))
   )
(: _ (puts "glaze-hook: ok -- the natjit creation hook (leaf, float, loop, capture, self, =, transparency)
") 0)
