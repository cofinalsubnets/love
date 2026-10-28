; the feel pre-pass: fold correctness, and identity-minting heads never folded.
; whether a fold fired differs between compilers, so it is not asserted here
(test
 ; --- impure / identity-minting heads are not folded (fresh each call) ---
 (: (f _) {} !(f 0 = f 0))                  ; a tablet mints fresh each call

 ; --- arithmetic folds are correct, nested ---
 (7 = (1 + (2 * 3)))
 (4096 = (* 2 3 4))                              ; ((* 2 3) 4) = 4 ** 6
 (8 = (3 2))
 (6 = gcd 24 18)
 (6 = ((+ 1) 5))

 ; --- X / A / B fold; element access is correct ---
 (9 = <(9 . 8))
 (8 = >(9 . 8))
 (2 = <>'(1 2 3))
 (4 = #("ab" + "cd"))

 ; --- a TEXT head folds its known prefix: pure and total at every operand ---
 ("abcd" = ("ab" "cd"))
 ("abcdef" = ("ab" "cd" "ef"))
 ("abcd" = (: a "ab" b "cd" (a b)))                   ; through const-propagated binders
 (97 = ("abc" 0)) !("hi" 9)
 ("abcdef" = (: (f x) ("ab" "cd" x) (f "ef")))        ; the unknown tail rides on
 ("abcdefgh" = (: (f x) ("ab" "cd" x "gh") (f "ef"))) ; ... and later operands still apply in order
 ("abZcd" = (: (f x) ("ab" x "cd") (f "Z")))          ; nothing known past the head: wholly residual
 ("xy" = (: (f s) (s "y") (f "x")))

 ; --- ... and the walk is the head VALUE's purity, not text: a point and a numeral fold too ---
 (256 = (: (f x) (3 2 x) (f 2)))     ; (3 2) is the charm 8, folded
 ('sym = (: (f x) ('sym 5 x) (f 9))) ; a point applied answers itself
 !(: (f x) (() 5 x) (f 9))           ; () folds too, named apart since nom? is false of it
 (5 = (0 0 5)) (262144 = (2 3 4))
 (1.0 = (: (f x) (2 1.5 x) (f 1)))   ; (2 1.5) is a charm-sized gem, so it folds
 ; over-application can grow unbounded: (+ 1 200000 2) is 60207 digits, left residual
 (sun? (: (f x) (+ 1 200000 2) (f 0)))          ; sun?, not (tally (show ..)): the render is slow
 ('(1 2 3 4) = (: (f x) ('(1 2) x) (f '(3 4)))) ; a chain joins like text
 ; --- readset: peep and pin fold on an immutable container, never on a tablet ---
 ("aXcd" = (: (f x) (pin "abcd" 1 x) (f 88)))      ; the functional update, folded whole
 ('(1 X 3) = (: (f x) (pin '(1 2 3) 1 x) (f 'X)))
 (8 = (: (f x) (peep '(7 8 9) x 0) (f 1)))
 (: (f _) (pin {} 1 2) !(f 0 = f 0))               ; a tablet is mutable: pin there is a write, never folded
 (256 = (: (f x) ('(7 8 9) 1 x) (f 2)))            ; ('(7 8 9) 1) folds to 8, leaving (8 x)
 !(: (f x) ((1 . 2) x) (f (a \ b \ a + b)))
 ; a numeral whose answer outgrows a charm stays residual
 (3 = (: (f x) (3 (y \ y + 1) x) (f 0)))

 ; --- currying: under-application yields a usable closure ---
 (7 = ((+ 3) 4))
 (15 = (: (g x) (10 + x) (g 5)))

 ; --- shadowing: a locally-bound name is never folded as the global ---
 (99 = (: (. a b) 99 (. 1 2)))
 (5 = (: (cap x) 5 (cap '(1 2))))
 (7 = (: (f .) (. 3 4) (f (+))))  ; param shadows the global

 ; --- nil?-flip: (? (nil? e) a b) == (? e b a) ---
 ('z = (: (f x) (!x ? 'z 'nz) (f 0)))
 ('nz = (: (f x) (!x ? 'z 'nz) (f 5)))
 ('z = (: (f x) (!x ? 'z 'nz) (f "")))
 ('nz = (: (f x) (!x ? 'z 'nz) (f '(1))))
 ('z = (: (f x) (!x ? 'z 'nz) (f 0)))
 ('c = (: (f x) (? (5 < x) 'a !x 'c 'b) (f 0)))       ; final-clause flip inside a chain
 ('b = (: (f x) (? (5 < x) 'a !x 'c 'b) (f 3)))
 ('a = (: (f x) (? (5 < x) 'a !x 'c 'b) (f 9)))
 (() = (: (f x) (? !x 'z) (f 5))))                    ; no else: the zero point ()

; --- the purity gate: an inlined lambda substitutes only pure args, or a param named
; twice runs an impure arg twice, silently ---
(: pg-ctr (cask 1)
   (pg-bump _) (peep pg-ctr 0 0 @ v (pin pg-ctr 0 (v + 1), v + 1))
   (pg-dbl x) (x + x)                                ; names its param twice
   (test
    (: _ (pin pg-ctr 0 0) r (pg-dbl (pg-bump 0))
       (2 = r && 1 = peep pg-ctr 0 0))))       ; evaluated once

; --- the binding splice: an impure arg binds once, ahead of the body; behavioural, so
; each holds under both compilers and under decline ---
(: bs-ctr (cask 1)
   (bs-bump _) (peep bs-ctr 0 0 @ v (pin bs-ctr 0 (v + 1), v + 1))
   (bs-mix a b c) (a + b + c)
   (bs-ord a b) (b - a)
   (bs-drop a b) b                         ; the effect must still run
   (bs-esc n) (x \ x + n)                  ; escapes at value position
   (test
    ; mixed: constants substitute, the impure arg binds
    (: _ (pin bs-ctr 0 0) r (bs-mix 3 (bs-bump 0) 4)
       (8 = r && 1 = peep bs-ctr 0 0))
    ; impure args run once each, in no promised order
    (: _ (pin bs-ctr 0 0) r (bs-ord (bs-bump 0) (bs-bump 0))
       ((r = 1 || r = -1) && 2 = peep bs-ctr 0 0))
    ; a dropped param's effect still runs
    (: _ (pin bs-ctr 0 0) r (bs-drop (bs-bump 0) 7)
       (7 = r && 1 = peep bs-ctr 0 0))
    ; an identity-minting arg is bound once
    (: (bs-same t) (t = t) (bs-same {}))
    ; under-saturated + impure: declined, the effect fires once at build
    (: _ (pin bs-ctr 0 0) p (bs-mix 3 (bs-bump 0))
       (9 = p 5 && 1 = peep bs-ctr 0 0))
    ; a lambda body at value position declines; the closure still works
    (: _ (pin bs-ctr 0 0) h (bs-esc (bs-bump 0))
       (3 = h 2 && 1 = peep bs-ctr 0 0))))

; --- read-once: an effectful arg read exactly once, unconditionally, substitutes;
; read many times it binds, under ? or \ it declines ---
(: r1-c1 (cask 1) r1-c2 (cask 1)
   (r1-b1 _) (peep r1-c1 0 0 @ v (pin r1-c1 0 (v + 1), v + 1))
   (r1-b2 x) (peep r1-c2 0 0 @ v (pin r1-c2 0 (v + 1), x + v))
   (r1-mix a b c) (a + c + b)                                       ; b read once: substitutes
   (r1-two a b) (a + a + b)                                         ; a twice: binds
   (r1-iff p b) (p ? b 0)                                           ; b under ?: declines, still runs once
   (test
    (: _ (pin r1-c1 0 0) r (r1-mix 3 (r1-b1 0) 4)
       (8 = r && 1 = peep r1-c1 0 0))
    ; args run in no set order: either value
    (: _ (pin r1-c1 0 0) _ (pin r1-c2 0 0)
       r (r1-two (r1-b1 0) (r1-b2 (peep r1-c1 0 0)))
       ((r = 2 || r = 3) && 1 = peep r1-c1 0 0 && 1 = peep r1-c2 0 0))
    ; the strict call runs b always, so it binds
    (: _ (pin r1-c1 0 0) r (r1-iff 0 (r1-b1 0))
       (0 = r && 1 = peep r1-c1 0 0))))

; --- under-saturated beta: a known lambda short of its params answers a \ of the rest ---
(: (usadd a b) (a + b)
   (us3 a b c) (a + b + c)
   (ustw f x) (f (f x))
   (test
    (15 = (: (g i) (ustw (usadd i) i) (g 5)))
    (7 = (ustw (us3 1 2) 1))
    (9 = (usadd 4 @ h (h (h 1))))))                      ; value position: the partial reverts

; --- a body-position `:` splices into its parent's frame, unless a name collides or is captured ---
(: (lf-h n) (n = 0 ? 4 (lf-h (n - 1)))           ; recursive: cprop neither folds nor inlines it
   (test
    (3 = (1 @ a (2 @ b (a + b))))
    (6 = (1 @ a (2 @ b (3 @ c (a + b + c)))))       ; any depth lands in one frame
    (2 = (1 @ a (2 @ a a)))                         ; a collision: the inner still shadows
    (4 = (1 @ a (a @ b (3 @ a (b + a)))))           ; ... and b read the outer a
    (4 = (: (f _) (lf-h 1) ((y \ 99) @ lf-h (f 0))))))   ; an outer def reads the name: no capture

; --- an over-applied known-arity head splits: (f 1 2 3) is ((f 1 2) 3). the heads
; recurse so the inliner declines them ---
(: (oa2 a b) (a = 0 ? (c \ b + c) (oa2 (a - 1) b))
   (oa3 a b c) (a = 0 ? [b c] (oa3 (a - 1) b c))
   (oan x) (x = 0 ? 3 (oan (x - 1)))                ; an operand no fold knows: 3
   (test
    (7 = (oa2 1 3 4))
    (7 = (oa2 1 3 4))
    (8 = (oa3 1 9 8 1))                             ; [9 8] indexed at 1
    ; a curried nif splits the same way: the surplus applies to its answer
    (4096 = (* (oan 0) 2 4)) (1024 = (+ (oan 0) 2 4)) (4 = (- (oan 0) 1 2))))

; --- ..and a shadowed name does not wear the outer one's arity; only an unglazed run sees it ---
(: (oas-w a b) (two? a ? (oas-w >a b) b)                ; arity 2
   (oas-in l) (: (oas-w x y z) (two? x ? (oas-w >x y z) (y + z))     ; shadowed at arity 3
                 (oas-w l 1 2))
   (test
    (3 = (oas-in [1 2 3]))
    (3 = (oas-in ()))
    (9 = (oas-w [1 2] 9))))

; --- an unknown head takes the optimistic apply (apo): args land r2l in the apn frame, a
; cur of exactly that many enters; a cur of more is one partial over all the args, `=` and
; hashed as the l2r chain's; fewer, or no cur, runs the chain. the heads are recursive params,
; so no fold or inline knows them. ap-t* call in tail position, ap-n* do not ---
(: (ap-k3 a b c) (a < 1 ? [a b c] (ap-k3 (a - 1) b c))
   (ap-k4 a b c d) (a < 1 ? [a b c d] (ap-k4 (a - 1) b c d))
   (ap-k2 a b) (a < 1 ? (c \ [b c]) (ap-k2 (a - 1) b))
   (ap-k1 a) (a < 1 ? (b \ a - b) (ap-k1 (a - 1)))
   (ap-t2 f a b n) (n < 1 ? (f a b) (ap-t2 f a b (n - 1)))
   (ap-t3 f a b c n) (n < 1 ? (f a b c) (ap-t3 f a b c (n - 1)))
   (ap-n2 f a b n) (n < 1 ? [(f a b)] (ap-n2 f a b (n - 1)))
   (ap-n3 f a b c n) (n < 1 ? [(f a b c)] (ap-n3 f a b c (n - 1)))
   (test
    ([0 2 3] = ap-t3 ap-k3 0 2 3 1) ([[0 2 3]] = ap-n3 ap-k3 0 2 3 1)
    ([0 2 3] = ap-t2 ap-k3 0 2 1 3) ([0 2 3] = cap (ap-n2 ap-k3 0 2 1) 3)    ; short: a partial
    ([0 2 3 4] = ap-t2 (ap-t2 ap-k4 0 2 1) 3 4 1)
    ([0 2 3 4] = ap-t2 ap-k4 0 2 1 3 4)
    ((ap-t2 ap-k3 0 2 1) = (ap-k3 0) 2)                                    ; the one cell is the chain's
    !((ap-t2 ap-k4 0 2 1) = ((ap-k4 0) 2) 3)                               ; ..and differs from a longer one
    (((ap-t2 ap-k4 0 2 1) 3) = cap (ap-n3 ap-k4 0 2 3 1))                  ; an unc over an uncn is the one cell
    (9 = peep {((ap-k3 0) 2) 9} (ap-t2 ap-k3 0 2 1) 0)                     ; hashed as the chain's
    ([2 3] = ap-t3 ap-k2 0 2 3 1) ([[2 3]] = ap-n3 ap-k2 0 2 3 1)          ; long: the surplus curries
    (-2 = ap-t2 ap-k1 1 2 1) ([-2] = ap-n2 ap-k1 1 2 1)                     ; no cur
    (5 = ap-t2 {1 (x \ x + 4)} 1 1 1) ([5] = ap-n2 {1 (x \ x + 4)} 1 1 1)  ; a tablet
    (7 = ap-t2 1 (+ 3) 4 1) ([7] = ap-n2 1 (+ 3) 4 1)))                    ; a number: the tower

; a literal 2..4 applied to one operand: a number takes ipow's products, the rest num-ap's lane
(: (fl-sq x) (2 x) (fl-cu x) (3 x) (fl-qu x) (4 x)
   (fl-ip x) (: h (1 * x) [(h * h) (h * h * x) (: q (h * h) (q * q))])
   (test
    ([49 343 2401] = [(fl-sq 7) (fl-cu 7) (fl-qu 7)])
    (all (x \ show [(fl-sq x) (fl-cu x) (fl-qu x)] = show (fl-ip x)) [1.1 -0.0 0.1 -3.7 1e200 (70 2) (0 ~ 1) (1.5 ~ -0.0)])
    (aall (fl-sq @(1 2 3) = @(1 4 9))) (aall (fl-cu @(1.5 -2.0) = @(3.375 -8.0)))
    ([2 3 4] = [((fl-sq (+ 1)) 0) ((fl-cu (+ 1)) 0) ((fl-qu (+ 1)) 0)])   ; a function: its church power
    (2 = (fl-sq [1 2]) 0)                                                 ; data too: [1 2] ([1 2] 0)
    (5 = (: (f g x) (2 g x) (f (+ 2) 1)))))                               ; a second operand: church, not lowered

; dechurch: a numeral over a literal function is that function nested, church's answer
(: (dc-a i) (2 (+ i) i) (dc-b i) ((2 (+ i)) i) (dc-c i) (2 (\ a (a * a)) i)
   dc-n {}
   (dc-bump _) (pin dc-n 'k (dc-n 'k + 1), dc-n 'k)
   (test
    ([15 15 625] = [(dc-a 5) (dc-b 5) (dc-c 5)])
    ([7 5 9] = [(0 (\ a a) 7) (1 (+ 2) 3) (3 (+ 3) 0)])
    (: _ (pin dc-n 'k 0) (3 = 2 (\ a (a + 1)) (dc-bump 0) && 1 = dc-n 'k))   ; the operand evaluates once
    (: _ (pin dc-n 'k 0) (2 = 2 (+ (dc-bump 0)) 0 && 1 = dc-n 'k))))       ; an impure partial: once too
