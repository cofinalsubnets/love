; recursive bindings in `:`. functions resolve lazily per call; a recursive value is
; boxed through a heap cell, since closures capture by value at creation

(:
 (nfac n) (n < 1 ? 1 (n * nfac (n - 1)))
 ; the eta-expanded factory idiom
 (mkconst z) (n \ n < 1 ? z (kconst (n - 1)))
 kconst (mkconst 7)
 ; memoizing fixpoint, for the recursive-value fib below
 (memo f) (: m {} (x \ (: c (peep m x 0) (c ? c (: y (f x) (pin m x y, y))))))
 (test
  (120 = nfac 5)
  (7 = kconst 0) ; base case
  (7 = kconst 5) ; re-entrant

  ; --- recursive VALUE: a factory closure captures the name being defined ---
  (7 = (: (mk z) (n \ n < 1 ? z (self (n - 1))) self (mk 7) (self 0)))
  (7 = (: (mk z) (n \ n < 1 ? z (self (n - 1))) self (mk 7) (self 1)))
  (7 = (: (mk z) (n \ n < 1 ? z (self (n - 1))) self (mk 7) (self 5)))
  ; same shape, a captured factorial
  (120 = (: (mk z) (n \ n < 1 ? 1 (n * cf (n - 1))) cf (mk 0) (cf 5)))

  ; --- forward value reference captured by an earlier function binding ---
  (15 = (: (f x) (v + x) v 5 (f 10)))

  ; --- mutual recursion among value bindings ---
  (9 =   (: (mka z) (n \ n < 1 ? z (kb (n - 1)))
            (mkb z) (n \ n < 1 ? z (ka (n - 1)))
            ka (mka 7) kb (mkb 9) (ka 1)))

  ; --- memoized fib: fib is a recursive value (its init closes over fib) ---
  (55 = (: fib (memo (n \ n < 2 ? n (fib (n - 1) + fib (n - 2)))) (fib 10)))
  (6765 = (: fib (memo (n \ n < 2 ? n (fib (n - 1) + fib (n - 2)))) (fib 20)))

  ; --- shadowing: an inner lambda rebinds the boxed name; left untouched ---
  (7 = (: (mk z) (n \ n < 1 ? z (self (n - 1))) self (mk 7) g (self \ self) (g (self 1))))

  ; --- a value defined before the function using it needs no box, stays correct ---
  (6 = (: x 5 f (n \ x + n) (f 1)))

  ; --- `_` repeats, each its own slot, and a literal body still answers ---
  (0 = (: _ 1 _ 2 0))
  (7 = (: _ 1 _ 2 _ 3 7))

  ; --- a box cell must not shift an earlier ref to an outer binding ---
  (108 = (: outer 100
            (: a (outer + 1)
               (mk z) (n \ n < 1 ? z (self (n - 1)))
               self (mk 7)
               (a + self 3))))
  ; two cells (mutual): the early ref must survive both
  (110 = (: outer 100
            (: a (outer + 1)
               (mka z) (n \ n < 1 ? z (kb (n - 1)))
               (mkb z) (n \ n < 1 ? z (ka (n - 1)))
               ka (mka 7) kb (mkb 9)
               (a + ka 1))))
  ; nor a sibling of an enclosing let, below the inner let's cell
  (108 = (: g 100
            q (: a (g + 1)
                  (mk z) (n \ n < 1 ? z (self (n - 1)))
                  self (mk 7)
                  (a + self 3))
            q))
  ; doubly nested: the reference crosses two cell regions
  (114 = (: g 100
            q (: b 7
                 r (: a (g + b)
                      (mk z) (n \ n < 1 ? z (self (n - 1)))
                      self (mk 7)
                      (a + self 3))
                 r)
            q))))

; --- tenured closures: show, = and the hash read them in the major pool, and agree ---
(: (lots n) ((: (go i a) (i >= n ? #a (go (i + 1) (i . a)))) 0 ())
   (fa a b) (a + b) (ga a b) (a + b)
   _ (lots 200000)                                       ; force a major, tenuring fa/ga
   (test
     (fa = ga)
     (9 = peep {fa 9} ga 0)  ; eq and hash agree
     (8 < #(show fa))))

; --- an inner loop `go` shadows a later outer sibling `go`: its self-reference must
; not reach the outer one, or (zap x) under-applies to a truthy partial ---
(: rq <[1]
   (zap q)
    (? (two? q)
       (: (go m ok) (? (atom? m) ok
                       (: k (zap <m)
                          (go >m (ok && !k)))) ; every leaf must answer ()
          (go q 1)))                           ; a partial is truthy
   (go a) (? rq (zap a) 0)
   (test (1 = go [5 6 7])))

; --- capture through a later sibling: an earlier closure inherits its captures, so
; the value is boxed on the reach, not only on a direct mention ---
(: (tk1 _) (: (a o) (f o) c {} f (o \ peep c o 'no) _ (pin c 'k 'yes) (a 'k))
   (tk2 _) (: (helper x) (other x) K {} (other y) (peep K y 'no)
               _ (pin K 'k 'yes) (helper 'k))
   ; a binding whose nom also spells a macro is a variable here, never a macro head
   (tk3 _) (: (a o) (zz o) c {} zz (o \ peep c o 'no) _ (pin c 'k 'yes) (a 'k))
   (test ('yes = tk1 ()) ('yes = tk2 ()) ('yes = tk3 ())))

; --- a body-less top-level `:` defines after its def is built, so a nested lambda
; naming it reads the book when it runs ---
(: closure-fct (: (h n acc) (n < 1 ? acc (h (n - 1) (acc * n))) (n \ h n 1)))
(: (tl1 _) (: walk (: (kid k) (two? k ? (walk >k) k) kid) (walk '(1 2 3)))
   (test (120 = closure-fct 5) !(tl1 ())))
