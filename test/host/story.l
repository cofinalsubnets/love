; --- test/host/story.l: rove's fiction engine, headless ---
; not in the test/*.l corpus (it reads the tree). the engine is pure love, so everything
; but the tty runner gates here: the level file read into play and written back the
; same; a turn (the keys move @, a wall stops it, a thing opens its window); the window
; (a say pages its words, enter steps, esc closes; the prompt's interpreter answers
; read, look, help and a love form into the window); the frame (the map with @ and the
; things, the box over it, the status line); and the library lifted from src/apps -- a
; shelf per wing whose books read through libra. the runner, vi and the hatch stay live
; probes: `love story`, `love story src/apps`.
;   cat test/00-init.l test/host/story.l | out/love

(use 'story)   ; the artifact's module, warm from the tree

(: (find h n i) (? (i + tally n < 1 + tally h)
                  (? (n = snip h i (i + tally n)) 1 (find h n (i + 1)))
                  0)
   (has? h n) (find h n 0)
   ; the text under the escapes: an ESC and its CSI sequence, up to the final letter, drop
   (plain s) ((: (g i acc esc) (? (i < #s)
                                  (: c (s i)
                                     (? esc (g (i + 1) acc (? (65 <= c < 91 || 97 <= c < 123) 0 1))
                                        (c = 27) (g (i + 1) acc 1)
                                        (g (i + 1) (acc + string c) 0)))
                                  acc)) 0 "" 0)
   (keys! g s) (each (map (i \ s i) ^#s) (c \ story-key g c))

   ; --- the level file, and its round trip ---
   L (load-level "src/apps/rove/levels/lighthouse.l")
   _ (assert L (9 = (L 'w)) (12 = (L 'h)) (4 = (L 'sx)) (8 = (L 'sy))
             (= '(lamp sign) (sort (keys (L 'things))))
             ("*" = (L 'things 'lamp 'gl))
             (= (data-of (level-of <(sound (level-text L)))) (data-of L)))   ; a shown level reads back
   _ (assert (35 = tile L 0 0) (46 = tile L 1 1) (35 = tile L -1 5) (35 = tile L 4 99))   ; off the map is wall

   ; --- the map: moves, walls, a thing ---
   g (story-new L)
   _ (keys! g "l")
   _ (assert (5 = (g 'x)) (8 = (g 'y)) !(g 'win))
   _ (keys! g "jjjj")                                 ; the south wall stops you
   _ (assert (10 = (g 'y)))
   _ (keys! g "h")                                    ; under the sign
   _ (assert (4 = (g 'x)) (10 = (g 'y)) !(g 'win))
   _ (keys! g "k")                                    ; bump: the sign opens, you stay
   _ (assert (g 'win) ("the sign" = (g 'win 'title)) (10 = (g 'y)) (has? <(g 'win 'lines) "KEEPER OUT"))
   _ (keys! g "\r")                                   ; enter: the next page
   _ (assert (has? (g 'win 'lines 1) "NEXT TIDE"))
   _ (keys! g "\r")                                   ; ..and past the last step the window closes
   _ (assert !(g 'win))
   _ (keys! g "\e")
   _ (assert ('quit = (g 'over)))

   ; --- the frame: @ where you stand, the things, the status line; the box over it ---
   g2 (story-new L)
   f (plain (story-frame g2 30 14))
   rows (split "\r\n" f)
   _ (assert (14 = tally rows) (64 = (rows 8) 4) (42 = (rows 2) 4) (63 = (rows 9) 4)
             (has? (rows 13) "the lighthouse") (has? (rows 13) "@ 4,8"))
   _ (keys! g2 "kkkkkk")                              ; up the shaft to the lamp
   _ (assert (g2 'win) ("the lamp" = (g2 'win 'title)))
   f2 (plain (story-frame g2 70 20))
   _ (assert (has? f2 "+-the lamp ") (has? f2 "| a fresnel lens") (has? f2 "-- enter --") (has? f2 "esc closes"))

   ; --- the library: a shelf per wing, its books through libra, the interpreter ---
   LB (library "src/apps")
   _ (assert (10 < tally (keys (LB 'things))) (LB 'things 'rove) (LB 'things 'lapiz) (LB 'things 'hatch)
             ("|" = (LB 'things 'rove 'gl)) (LB 'things 'rove 'books 'story))
   g3 (story-new LB)
   sh (LB 'things 'rove)
   _ (open-window g3 sh)
   _ (assert (g3 'win) (has? <(g3 'win 'lines) "rove") !(g3 'win 'prompt))
   _ (keys! g3 "\r")                                  ; the say pages out; then (ask) opens the prompt
   _ (assert (g3 'win 'prompt))
   _ (keys! g3 "look\r")
   _ (assert (has? (last (g3 'win 'lines)) "story"))   ; the shelf's books, the newest line
   _ (keys! g3 "read story\r")
   _ (assert (has? (joins (g3 'win 'lines) " ") "fiction engine"))   ; libra's lift of this file's header
   _ (keys! g3 "(+ 1 2)\r")
   _ (assert ("3" = last (g3 'win 'lines)))             ; a love form, evaluated into the window
   _ (keys! g3 "dance\r")
   _ (assert (has? (last (g3 'win 'lines)) "cannot dance"))
   _ (keys! g3 "\e")
   _ (assert !(g3 'win))
   _ (test_fin ())
   _ (puts "story: ok -- the level, the map, the window and its interpreter, the library\n")
   0)
