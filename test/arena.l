; the code arena under churn: (arena 0) is [mapped bumped free spans], the bytes of the chunks
; installs own, how far their bump has run, the free list's bytes and its length. rounds of
; glazed lambdas of varied size, the last 40 kept live, each round's dead finalized by a major:
; the free list stays a handful of spans, and once every one is dead the arena is where it began
; -- each span handed back whole, merged with its neighbours, the bump retracted. where nothing
; glazes (love0, the kernel, LOVE_NO_GLAZE) there is no arena to churn, and this stands down.
(: (arz-src k i) (: (go j b) (j = 0 ? b (go (j - 1) ['+ b ['* 'x (i + j)]])) ['\ 'x (go k 'x)])
   (arz-mk i) (ev (arz-src (1 + (i * 7) % 13) i))
   (arz-round r live) (: (go i l) (i = 120 ? l (: f (arz-mk (r * 1000 + i)) (go (i + 1) (f 1, take 40 (f . l))))) (go 0 live))
   (arz-churn r live most) (r = 4 ? most (: l (arz-round r live) _ (please 1) (arz-churn (r + 1) l (max most (arena 0 3)))))
   (arz-law _) (: _ (please 1) _ (please 1) a0 (arena 0)
                  most (arz-churn 0 () 0)
                  _ (please 1) _ (please 1)
                  [(most <= 8 + a0 3) (a0 = arena 0)])
   (test (4 = tally (arena 0))
         (nat? (arz-mk 1) ? (: r (arz-law 0) (r 0 && r 1)) 1)))
