; wm/layout.l -- layouts as DATA records, messages as SYMBOLS. A layout answers
; two questions, both PURE (no X, no sockets -- so this rides the corpus on every
; target, wm/law.l asserts the geometry):
;
;   (lay-tile lay rect z) -> (placements lay')   ; place the zipper's row in the rect
;   (lay-msg  lay msg  z) -> lay' | ()            ; () = "I don't take this message"
;
; rect is (x y w h); a placement is (win x y w h) -- the shape wm/wm.l's render
; already configures. `z` is the focus zipper (wm/core.l), so a layout sees BOTH
; the ordered row (zrow) and the focus (zfoc). Messages ride sendMessage: () back
; means unhandled, so a modifier stack (rung 4) falls through cleanly. This rung
; ships xmonad's ResizableTall (nmaster/ratio/per-slave heights), Full, and the
; ||| choice + NextLayout. A body-LESS `:` -- the vocabulary leaks to the driver.
(:
   ; --- geometry: a rect is (x y w h); splits return rect lists ---
   (rct x y w h) (L x y w h)
   (rx r) (cap r)  (ry r) (caup r)  (rw r) (nthl r 2)  (rh r) (nthl r 3)
   (splitv-eq n r)                                                               ; n equal vertical strips, last takes the remainder
    (? (< n 1) ()
       (: hh (// (rh r) n)
          (: (go i) (? (< i n) (link (rct (rx r) (+ (ry r) (* i hh)) (rw r)
                                          (? (= i (- n 1)) (- (rh r) (* (- n 1) hh)) hh))
                                     (go (+ i 1))) ())
             (go 0))))
   (splitv-w fracs r)                                                            ; weighted vertical split (ResizableTall's slave heights)
    (: n (tally fracs) tot (foldl (+) 0.0 fracs)
       (: (go i yy) (? (< i n)
                       (: fr (nthl fracs i)
                          hh (? (= i (- n 1)) (- (+ (ry r) (rh r)) yy) (int (* (rh r) (/ fr tot))))
                          (link (rct (rx r) yy (rw r) hh) (go (+ i 1) (+ yy hh))))
                       ())
          (go 0 (ry r))))
   (splith-by ratio r)                                                          ; split width by ratio -> (left right)
    (: mw (int (* ratio (rw r)))
       (L (rct (rx r) (ry r) mw (rh r)) (rct (+ (rx r) mw) (ry r) (- (rw r) mw) (rh r))))
   (placeat wins rects) (? (&& (two? wins) (two? rects))                        ; zip windows with rects -> (win x y w h)..
                           (link (link (cap wins) (cap rects)) (placeat (cup wins) (cup rects))) ())
   (posof x l) (: (go i m) (? (! (two? m)) -1 (? (= (cap m) x) i (go (+ i 1) (cup m)))) (go 0 l))
   (mx2 a b) (? (< a b) b a)  (mn2 a b) (? (< a b) a b)                          ; scalar max/min (max/min are array reducers)
   (padfr fr ns) (: (go i f) (? (< i ns) (link (? (two? f) (cap f) 1.0)         ; a length-ns slave-frac list, padded with 1.0
                                              (go (+ i 1) (? (two? f) (cup f) ()))) ())
                    (go 0 fr))

   ; --- ResizableTall (nmaster delta frac slaves): xmonad's Tall + slave heights ---
   (resizable-tall nm delta frac) (L 'rtall nm frac delta ())                   ; slaves start equal (())
   (tall nm) (resizable-tall nm 0.03 0.5)                                       ; plain Tall, 3% steps, half master
   (rt-nm lay n) (: m (nthl lay 1) (? (< m 1) 1 (? (> m n) n m)))               ; master count, clamped to [1,n]
   (rt-tile lay rect z)
    (: row (zrow z) n (tally row) ratio (nthl lay 2) fracs (nthl lay 4) nm (rt-nm lay n)
       (? (< n 1) (L () lay)
          (<= n nm) (L (placeat row (splitv-eq n rect)) lay)                    ; all fit the master column
          (: hs (splith-by ratio rect) rl (cap hs) rr (caup hs)
             ns (- n nm)
             ms (placeat (take nm row) (splitv-eq nm rl))
             ss (placeat (drop nm row) (splitv-w (padfr fracs ns) rr))
             (L (cat ms ss) lay))))
   (rt-set lay k v) (: (go i p) (? (! (two? p)) () (link (? (= i k) v (cap p)) (go (+ i 1) (cup p)))) (go 0 lay))
   (rt-msg lay msg z)
    (: ratio (nthl lay 2) delta (nthl lay 3)
       (? (= msg 'shrink)     (rt-set lay 2 (mx2 0.05 (- ratio delta)))
          (= msg 'expand)     (rt-set lay 2 (mn2 0.95 (+ ratio delta)))
          (= msg 'inc-master) (rt-set lay 1 (+ (nthl lay 1) 1))
          (= msg 'dec-master) (rt-set lay 1 (mx2 1 (- (nthl lay 1) 1)))
          (|| (= msg 'mirror-shrink) (= msg 'mirror-expand))                     ; nudge the FOCUSED slave's height
          (: row (zrow z) n (tally row) nm (rt-nm lay n)
             slaves (drop nm row) idx (posof (zfoc z) slaves)
             (? (< idx 0) lay                                                    ; a master is focused: no slave to resize
                (: sf (padfr (nthl lay 4) (tally slaves)) d (? (= msg 'mirror-shrink) (- 0.0 delta) delta)
                   (rt-set lay 4 (rt-set sf idx (mx2 0.1 (+ (nthl sf idx) d)))))))
          ()))

   ; --- Full: the focused window owns the whole rect; the rest go unplaced
   ;     (the driver unmaps windows absent from the placements) ---
   full (L 'full)
   (full-tile lay rect z) (: f (zfoc z) (L (? f (L (link f rect)) ()) lay))

   ; --- ||| : a list of layouts + an index; NextLayout bumps it ---
   (choice subs) (L 'choice 0 subs)
   (ch-cur lay) (nthl (nthl lay 2) (nthl lay 1))
   (ch-put lay cur2) (: idx (nthl lay 1) subs (nthl lay 2)                       ; replace the active sublayout
                        (L 'choice idx (map2 (\ i s (? (= i idx) cur2 s)) (jot (tally subs)) subs)))
   (ch-tile lay rect z) (: res (lay-tile (ch-cur lay) rect z)
                           (L (cap res) (ch-put lay (caup res))))
   (ch-msg lay msg z)
    (? (= msg 'next-layout) (L 'choice (% (+ (nthl lay 1) 1) (tally (nthl lay 2))) (nthl lay 2))
       (: r (lay-msg (ch-cur lay) msg z) (? r (ch-put lay r) ())))

   ; map over two lists in lockstep (prel has none) ---
   (map2 f a b) (? (&& (two? a) (two? b)) (link (f (cap a) (cap b)) (map2 f (cup a) (cup b))) ())

   ; --- the dispatch: case on the record tag ---
   (lay-tile lay rect z) (: k (cap lay) (? (= k 'rtall) (rt-tile lay rect z)
                                            (= k 'full)  (full-tile lay rect z)
                                            (= k 'choice) (ch-tile lay rect z) (L () lay)))
   (lay-msg lay msg z) (: k (cap lay) (? (= k 'rtall) (rt-msg lay msg z)
                                          (= k 'full)  ()
                                          (= k 'choice) (ch-msg lay msg z) ())))
