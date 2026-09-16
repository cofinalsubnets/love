; test/law/tui.l -- apps/tui.l's laws: the window follow and the diff repaint, held by
; assertion. both are pure (tui-fresh but for its one pin on the box it is handed), so
; there is no tty and no port here. rides the vi cat (`make test_vi`), so every helper
; is prefixed -- the lane is one scope.
(borrow 'tui)

(: (tl-esc s) (: n #s                                  ; escapes spelled, so a law reads
                 (go i a) (i >= n ? a
                           (: c (s i) (go (i + 1) (a + (c = 27 ? "^" (string c))))))
                 (go 0 ""))
   (tl-box _) {}
   (tl-in? cur top rows) (top <= cur < top + rows)

; --- settle: the window moves only far enough to hold the cursor ---
   _ (test
      (3 = tui-settle 3 7 5)                          ; above the window: the cursor becomes the top
      (6 = tui-settle 10 4 5)                         ; below it: the cursor lands on the last row
      (4 = tui-settle 5 4 5)                          ; inside: nothing moves
      (4 = tui-settle 4 4 5)                          ; the top row itself is inside
      (4 = tui-settle 8 4 5)                          ; and so is the last
      (5 = tui-settle 9 4 5)                          ; one past it scrolls by exactly one
      (7 = tui-settle 7 7 1)                          ; a one-row window still holds its cursor
      (0 = tui-settle 0 0 1))
   ; the law the three branches exist for, over a spread rather than by cases
   _ (test
      (: (row c t r) (tui-settle c t r @ t2 (tl-in? c t2 r && 0 <= t2)))
       (foldl (\ a c (foldl (\ a2 t (foldl (\ a3 r (a3 && row c t r)) a2 [1 2 3 7 24]))
                            a ^30))
              1 ^30))

; --- fresh: the first frame paints every row from home ---
   _ (test
      (: b (tl-box ())
         f (tui-fresh b 3 'g1 () ["one" "two"] "st" 3 1)
       (tl-esc f = "^[?2026h^[Hone^[K\r\ntwo^[K\r\n^[3;1Hst^[K^[3;1H^[?2026l"))
      ; the same rows again at the same geometry: no body, no status, just the cursor
      (: b (tl-box ())
         _ (tui-fresh b 3 'g1 () ["one" "two"] "st" 3 1)
         f (tui-fresh b 3 'g1 () ["one" "two"] "st" 2 4)
       (tl-esc f = "^[?2026h^[2;4H^[?2026l"))
      ; one row differs: only that row is placed, and rows are 1-based on the wire
      (: b (tl-box ())
         _ (tui-fresh b 3 'g1 () ["one" "two"] "st" 3 1)
         f (tui-fresh b 3 'g1 () ["one" "TWO"] "st" 3 1)
       (tl-esc f = "^[?2026h^[2;1HTWO^[K^[3;1H^[?2026l"))
      ; the status alone moved
      (: b (tl-box ())
         _ (tui-fresh b 3 'g1 () ["one" "two"] "st" 3 1)
         f (tui-fresh b 3 'g1 () ["one" "two"] "ST" 3 1)
       (tl-esc f = "^[?2026h^[3;1HST^[K^[3;1H^[?2026l")))

; --- fresh: the geometry is what says the rows still line up ---
   _ (test
      ; a moved view repaints from home, never by diff -- the rows no longer correspond
      (: b (tl-box ())
         _ (tui-fresh b 3 'g1 () ["one" "two"] "st" 3 1)
         f (tui-fresh b 3 'g2 () ["one" "two"] "st" 3 1)
       (tl-esc f = "^[?2026h^[Hone^[K\r\ntwo^[K\r\n^[3;1Hst^[K^[3;1H^[?2026l"))
      ; a shorter frame than the last still places every row it has
      (: b (tl-box ())
         _ (tui-fresh b 3 'g1 () ["one" "two" "three"] "st" 3 1)
         f (tui-fresh b 3 'g1 () ["one" "XX"] "st" 3 1)
       (tl-esc f = "^[?2026h^[2;1HXX^[K^[3;1H^[?2026l")))

; --- fresh: the content key short-circuits the body, and () means there is none ---
   _ (test
      ; an equal key says the body cannot have changed, so the rows are not even walked
      (: b (tl-box ())
         _ (tui-fresh b 3 'g1 'k1 ["one" "two"] "st" 3 1)
         f (tui-fresh b 3 'g1 'k1 ["one" "CHANGED"] "st" 3 1)
       (tl-esc f = "^[?2026h^[3;1H^[?2026l"))
      ; a different key falls back to the diff
      (: b (tl-box ())
         _ (tui-fresh b 3 'g1 'k1 ["one" "two"] "st" 3 1)
         f (tui-fresh b 3 'g1 'k2 ["one" "TWO"] "st" 3 1)
       (tl-esc f = "^[?2026h^[2;1HTWO^[K^[3;1H^[?2026l"))
      ; () is no key at all: it must never read as "equal to the last ()"
      (: b (tl-box ())
         _ (tui-fresh b 3 'g1 () ["one" "two"] "st" 3 1)
         f (tui-fresh b 3 'g1 () ["one" "TWO"] "st" 3 1)
       (tl-esc f = "^[?2026h^[2;1HTWO^[K^[3;1H^[?2026l")))

   _ (test_fin ())
   _ (say err "test/law/tui: the window follow + the diff repaint ok") _ (put err 10) 0)
