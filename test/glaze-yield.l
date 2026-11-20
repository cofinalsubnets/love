; --- test/glaze-yield.l: a native loop yields to a waiting peer --------------------
; a witness task counts while the main task runs one call to a glazed loop that calls
; nothing: every lane's countdown must hand the ring over, so the witness moves many
; times inside that one call, and the answer is the bytecode's, alone and beside the peer.
; the loops run past 2^32, so a register the countdown clobbers shows. test.mk's test_hook runs it
(: box {'n 0 'stop 0}
   (moved f x) (: n0 (box 'n)  r (f x)  [r (box 'n - n0)])
   l (map (i \ i % 7) ^400000)
   fs [(ev '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (* i 3))) a)) 0 0)))                      ; the counted loop
       (ev '(\ n ((: (go i a b) (? (< i n) (go (+ i 1) (+ a b) (- b 1)) a)) 0 0 1)))                ; the n-var loop
       (ev '(: (gys l a) (? (two? l) (gys (cup l) (+ a (cap l))) a) (\ l (gys l 0))))               ; amble, a tail self-call
       (ev '(\ l ((: (go l a) (? (two? l) (go (cup l) (+ a (cap l))) a)) l 0)))                     ; amble, a named let
       (ev '(: (gyt m i) (? (< i m) (. i (gyt m (+ i 1))) ()) (\ m (tally (gyt m 0)))))                 ; amble, the cons-tail loop
       (ev '(: (gyf n) (? (< n 2) n (+ (gyf (- n 1)) (gyf (- n 2)))) gyf))]                         ; the group lane's recursion
   xs [20000000 20000000 l l 400000 27]
   want [599999970000000 -199999970000000 1199997 1199997 400000 196418]
   r0 (map (i \ (fs i) (xs i)) ^#fs)                                                                 ; alone
   _ (twirl (_ \ (: (go _) (box 'stop ? () (pin box 'n (box 'n + 1), rest 0, go 0)) (go 0))) ())
   _ (rest 0)
   rs (map (i \ moved (fs i) (xs i)) ^#fs)
   _ (pin box 'stop 1)
   bad (filter (i \ !(r0 i = want i && rs i 0 = want i && rs i 1 > 100)) ^#fs)
   (two? bad ? (puts ("glaze-yield: " + show (map (i \ [i (r0 i) (rs i)]) bad) + "\n"))
      (puts "glaze-yield: ok\n")))
