; test/jotfuse.l -- a walker over (jot N) runs its counted twin, or with a lambda literal for its
; step the loop with that body inline (ev.l's jotfuse, jotin): every answer, and the order of every
; call, as the walker over the built range. jf-r builds the range where no fold sees a jot, so it
; is the walker as written
(: (jf-r n) (jot n)
   (jf-log f) (: t {'l ()} _ (f (i \ pin t 'l (i . t 'l))) (t 'l)))
(test
 ; --- answers, against the built range ---
 (10 = foldl (+) 0 ^5)
 (foldl (\ a i (i . a)) () ^5 = foldl (\ a i (i . a)) () (jf-r 5))
 ([0 1 2 3 4] = foldr (\ i a (i . a)) () ^5)
 ([0 2 4 6] = map (* 2) ^4)
 (() = map (* 2) ^0)
 (7 = foldl (+) 7 ^0)
 (7 = foldr (+) 7 (jot -3))
 (map (+ 1) (jot 2.5) = map (+ 1) (jf-r 2.5))
 ; a list operand is jot's own: the range of each
 ([[0 1] [0 1 2]] = map (x \ x) (jot [2 3]))
 (5 = foldl (\ a l (a + #l)) 0 (jot [2 3]))
 (4999950000 = foldl (+) 0 ^100000)

 ; --- the calls run in the walker's order ---
 ([3 2 1 0] = jf-log (g \ each ^4 g))
 ([3 2 1 0] = jf-log (g \ map (i \ (g i, i)) ^4))
 ([3 2 1 0] = jf-log (g \ foldl (\ a i (g i, a)) 0 ^4))
 ([0 1 2 3] = jf-log (g \ foldr (\ i a (g i, a)) 0 ^4))          ; foldr's innermost call first

 ; --- a local walker or jot is the local's ---
 (: (jot n) [n] ([4] = map (+ 1) (jot 3)))
 (: (foldl f z l) 'mine ('mine = foldl (+) 0 ^3))
 (: (map f l) 'mine ('mine = map (+ 1) ^3))
 ; a partial walker, and the range by name, take the walker as written
 (6 = (foldl (+) 0) ^4)
 (: r ^4 (6 = foldl (+) 0 r))

 ; --- the inline loop: the body sees its own names, and nothing of the loop's ---
 (: n 10 ([10 11 12] = map (i \ i + n) ^3))
 (: rev 0 go 1 m 2 ([0 1 2] = map (i \ i) ^3))
 (: (two? x) 'mine ([0 1 2] = map (i \ i) ^3))
 (: a 5 i 6 (9 = foldl (\ a i (a + i)) a ^3 + i - 5))
 (: t {} _ (foldl (\ _ i (pin t i 1)) 0 ^3) ([0 1 2] = sort (keys t)))
 ([1 3] = map ([a b] \ a + b) [[0 1] [1 2]])
 ([0 1] = map (\ i i) (jot 2))
 ; a fold's Z and N, both with effects, run in the walker's order
 (: t {'l ()} (g x) (pin t 'l (x . t 'l), x)
   (foldl (\ a i (a + i)) (g 0) (jot (g 3)) = foldl (\ a i (a + i)) (g 0) (jf-r (g 3))
    && (t 'l @ [a b c d] (a = c && b = d))))
 ; a nested walker over jot, the inner range the outer's index
 ([[] [0] [0 1]] = map (i \ map (j \ j) ^i) ^3)
 (6 = foldl (\ a i (a + foldl (\ b j (b + 1)) 0 ^i)) 0 ^4))
