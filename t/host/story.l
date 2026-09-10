; --- t/host/story.l: rove's fiction engine, headless ---
; not in the t/*.l corpus (it reads the tree). the engine is pure love, so everything
; but the tty runner gates here: the level file read into play and written back the
; same; a turn (the keys move @, a wall stops it, a thing opens its window); the window
; (a say pages its words, enter steps, esc closes; the prompt's interpreter answers
; read, look, help and a love form into the window); the frame (the map with @ and the
; things, the box over it, the status line); and the library lifted from a -- a
; shelf per wing whose books read through libra. the runner, vi and the hatch stay live
; probes: `love story`, `love story a`.
;   cat t/00-init.l t/host/story.l | out/love

(borrow 'story)   ; the artifact's module, warm from the tree

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
   L (load-level "a/rove/levels/lighthouse.l")
   _ (test L (13 = (L 'w)) (14 = (L 'h)) (6 = (L 'sx)) (8 = (L 'sy))
             (= '(lamp sign) (sort (keys (L 'things))))
             ("*" = (L 'things 'lamp 'gl)) (220 = (L 'things 'lamp 'fg))
             (= (data-of (level-of <(sound (level-text L)))) (data-of L)))   ; a shown level reads back
   ; the palette: the space is a wall that shows nothing, the water a wall with pens, the
   ; floor a floor; a character the palette lacks is a floor drawn as itself
   _ (test (4 = tally (keys (L 'tiles))) (wall? L 0 0) (" " = (kind-of L 32) 'gl) (wall? L 0 12) (27 = (kind-of L 126) 'fg)
             !(wall? L 3 1) (wall? L 2 0) (wall? L -1 5) (wall? L 4 99)      ; off the map is wall
             !((kind-of L 120) 'solid) ("x" = (kind-of L 120) 'gl))

   ; --- the map: moves, walls, a thing ---
   g (story-new L)
   _ (keys! g "l")
   _ (test (7 = (g 'x)) (8 = (g 'y)) !(g 'win))
   _ (story-key g -1)                                  ; the left arrow, as edkey hands it in
   _ (test (6 = (g 'x)))
   _ (story-key g -2)
   _ (test (7 = (g 'x)))
   _ (keys! g "jjjj")                                 ; the south wall stops you
   _ (test (10 = (g 'y)))
   _ (keys! g "h")                                    ; under the sign
   _ (test (6 = (g 'x)) (10 = (g 'y)) !(g 'win))
   _ (keys! g "y")                                    ; a diagonal up and west, and back down
   _ (test (5 = (g 'x)) (9 = (g 'y)))
   _ (keys! g "n")
   _ (test (6 = (g 'x)) (10 = (g 'y)))
   _ (keys! g "k")                                    ; bump: the sign opens, you stay
   _ (test (g 'win) ("the sign" = (g 'win 'title)) (10 = (g 'y)) (has? <(g 'win 'lines) "KEEPER OUT"))
   _ (keys! g "\r")                                   ; enter: the next page
   _ (test (has? (g 'win 'lines 1) "NEXT TIDE"))
   _ (keys! g "\r")                                   ; ..and past the last step the window closes
   _ (test !(g 'win))
   _ (keys! g "q\e")                                 ; q alone is nothing, esc alone is nothing
   _ (test !(g 'over))
   _ (keys! g ":wq")                                  ; the command line, and esc backs out of it
   _ (test ('cmd = (g 'mode)) ("wq" = (edtext (g 'cmd))))
   _ (keys! g "\e")
   _ (test ('map = (g 'mode)) !(g 'over))
   _ (keys! g ":dance\r")
   _ (test ('map = (g 'mode)) (has? (g 'msg) "not a command") !(g 'over))
   _ (keys! g ":q\r")
   _ (test ('quit = (g 'over)))

   ; --- the frame: @ where you stand, the things, the status line; the box over it ---
   g2 (story-new L)
   f (plain (story-frame g2 30 14))
   rows (split "\r\n" f)
   _ (test (14 = tally rows) (64 = (rows 8) 6) (42 = (rows 2) 6) (63 = (rows 9) 6)
             (32 = (rows 0) 0) (35 = (rows 0) 2) (126 = (rows 12) 0)             ; the unseen wall, the seen, the water
             (has? (rows 13) "the lighthouse") (has? (rows 13) "@ 6,8"))
   ; the pens: the water's fg and bg, the floor's fg with the terminal's own bg
   fp (story-frame g2 30 14)
   _ (test (has? fp "\e[38;5;27m\e[48;5;17m~") (has? fp "\e[38;5;240m\e[49m."))
   _ (keys! g2 "kkkkkk")                              ; up the shaft to the lamp
   _ (test (g2 'win) ("the lamp" = (g2 'win 'title)))
   f2 (plain (story-frame g2 70 20))
   _ (test (has? f2 "+-the lamp ") (has? f2 "| a fresnel lens") (has? f2 "-- enter --") (has? f2 "esc closes"))
   ; the command line shows at the foot in place of the status
   _ (keys! g2 "\e:q")
   _ (test (has? (plain (story-frame g2 70 20)) "\r\n:q"))
   _ (keys! g2 "\e")

   ; --- the view scrolls: a map wider and taller than the screen follows you ---
   big (level "wide" 1 1 (map (\ y (: (go x acc) (? (x < 60) (go (x + 1) (acc + (? (y = 0 || y = 29 || x = 0 || x = 59) "#" "."))) acc) (go 0 ""))) (jot 30)) {} {})
   g4 (story-new big)
   f4 (plain (story-frame g4 20 10))
   r4 (split "\r\n" f4)
   _ (test (0 = (g4 'vx)) (0 = (g4 'vy)) (64 = (r4 1) 1))               ; the corner: @ at 1,1 of the view
   _ (keys! g4 "llllllllllllllllllll")                                   ; twenty east: x 21
   f5 (plain (story-frame g4 20 10))
   _ (test (21 = (g4 'x)) (5 = (g4 'vx)) (64 = (split "\r\n" f5) 1 16))  ; the view slid; @ sits a margin in
   _ (keys! g4 "jjjjjjjjjjjjjjjjjjjjjjjjjjj")                           ; to the south wall: y 28
   f6 (plain (story-frame g4 20 10))
   _ (test (28 = (g4 'y)) (21 = (g4 'vy)) (64 = (split "\r\n" f6) 7 16))   ; the view stops at the map's edge
   _ (keys! g4 "llllllllllllllllllllllllllllllllllllllllllllll")          ; to the east wall: x 58
   _ (story-frame g4 20 10)                                               ; the view follows at the lay
   _ (test (58 = (g4 'x)) (40 = (g4 'vx)))

   ; --- the library: a shelf per wing, its books through libra, the interpreter ---
   LB (library "a")
   _ (test (10 < tally (keys (LB 'things))) (LB 'things 'rove) (LB 'things 'lapiz) (LB 'things 'hatch)
             ("|" = (LB 'things 'rove 'gl)) (LB 'things 'rove 'books 'story))
   g3 (story-new LB)
   sh (LB 'things 'rove)
   _ (open-window g3 sh)
   _ (test (g3 'win) (has? <(g3 'win 'lines) "rove") !(g3 'win 'prompt))
   _ (keys! g3 "\r")                                  ; the say pages out; then (ask) opens the prompt
   _ (test (g3 'win 'prompt))
   _ (keys! g3 "look\r")
   _ (test (has? (last (g3 'win 'lines)) "story"))   ; the shelf's books, the newest line
   _ (keys! g3 "read story\r")
   _ (test (has? (joins (g3 'win 'lines) " ") "fiction engine"))   ; libra's lift of this file's header
   _ (keys! g3 "(+ 1 2)\r")
   _ (test ("3" = last (g3 'win 'lines)))             ; a love form, evaluated into the window
   _ (keys! g3 "dance\r")
   _ (test (has? (last (g3 'win 'lines)) "cannot dance"))
   _ (keys! g3 "\e")
   _ (test !(g3 'win))
   _ (test_fin ())
   _ (puts "story: ok -- the level, the map, the window and its interpreter, the library\n")
   0)
