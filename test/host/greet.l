; test/host/greet.l -- love greet (src/apps/greet.l) headless: the keys move its fields, the box
; reads as it should, and it lands on a saver's frame through saver-over
;   cat test/00-init.l test/host/00-host.l test/host/greet.l | out/love
(borrow '(greet saver))
(: g (greet-new 0)
   (press l) (map (k \ greet-key g k 2) l)
   r1 (press [107 105 116])                                   ; "kit"
   r2 (press [13 115 101 99 120 127 127 99])                  ; enter, then "sec" x, two back, c
   r3 (press [9 -2 -2 -1 13])                                 ; to the session, turned, then enter
   rows (: t {} _ (greet-box g "bee" ["shell" "lux"] 24 80 (\ y x s f b (pin t y s))) t)
   text (map (y \ rows y) (sort (keys rows)))
   s (saver-make "life" 24 80 7 ())
   _ (saver-over s 0 (put \ greet-box g "bee" ["shell" "lux"] 24 80 put))
   cell (saver-cell (s 'cv) 10 18)                            ; the box's left edge, its login row
   h (greet-new 0)
   _ (pin h 'hold (clock 0 + 60000))
   _ (test (r1 = [() () ()]) (g 'user = "kit")
           (r2 = [() () () () () () () ()]) (g 'pass = "sec")
           (r3 = [() () () () 'try]) (g 'focus = 2) (g 'sess = 1)
           (#text = 9) (#(text 0) = 44) (snip (text 0) 0 2 = "+-")
           ("| login     kit" = snip (text 3) 0 15)
           ("| password  ***" = snip (text 4) 0 15)
           ("| session   < lux >" = snip (text 5) 0 19)
           (cell 0 = 124) (cell 2 = 236)                         ; "|" on the box's ground
           (nil? (greet-key h 107 2)) (h 'user = ""))             ; a failure's wait takes no key
   (puts "greet: ok\n"))
