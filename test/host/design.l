; --- test/host/design.l: the level designer, headless ---
; every key is a pure step and every frame a pure lay, so the designer gates here: a
; map painted from keys alone -- the brush, walls and floor at the cursor, a new tile
; kind with pens, a thing placed in three prompts and its pens set, the start -- saved
; as the datum story.l plays and loaded back the same, and the frame showing the
; cursor, what is under it, the help. the runner, vi on the file and play stay live
; probes: `love design`.
;   cat test/00-init.l test/host/design.l | out/love

(use 'story)
(use 'design)

(: S "/tmp/designtest.l"
   (find h n i) (? (i + tally n < 1 + tally h)
                  (? (n = snip h i (i + tally n)) 1 (find h n (i + 1)))
                  0)
   (has? h n) (find h n 0)
   (plain s) ((: (g i acc esc) (? (i < #s)
                                  (: c (s i)
                                     (? esc (g (i + 1) acc (? (65 <= c < 91 || 97 <= c < 123) 0 1))
                                        (c = 27) (g (i + 1) acc 1)
                                        (g (i + 1) (acc + string c) 0)))
                                  acc)) 0 "" 0)
   d (design-new (level "a test" 1 1 ["###" "#.#" "###"] {} {}) S)
   (keys! s) (each (map (i \ s i) ^#s) (c \ design-key d c))
   lvl (d 'lvl)
   ; floor to the east, past the map's edge: the row grows; a wall south of that; a
   ; diagonal back up and west
   _ (keys! "l.l.j#")
   _ (assert (46 = tile lvl 2 1) (46 = tile lvl 3 1) (35 = tile lvl 3 2) (4 = (lvl 'w)))
   _ (keys! "y")
   _ (assert (2 = (d 'cx)) (1 = (d 'cy)))
   _ (keys! "n")
   _ (assert (3 = (d 'cx)) (2 = (d 'cy)))
   ; a new tile kind in one line is the brush; space paints it; c sets its pens
   _ (keys! "a~ ~ 27 17 wall\r")
   _ (assert ('map = (d 'mode)) (126 = (d 'brush)) (lvl 'tiles 126) (wall? lvl 0 99)   ; ..and it stops you
             (17 = (lvl 'tiles 126 'bg)) (has? (d 'msg) "brush"))
   _ (keys! "l ")
   _ (assert (126 = tile lvl 4 2))
   _ (keys! "c33 18\r")
   _ (assert (33 = (lvl 'tiles 126 'fg)) (18 = (lvl 'tiles 126 'bg)))
   _ (keys! "1")                                      ; the palette's first, by number
   _ (assert (126 = (d 'brush)))
   _ (keys! ".")
   _ (assert (46 = (d 'brush)) (46 = tile lvl 4 2))
   ; a thing at the cursor: id, glyph, name, in three prompts; then its pens
   _ (keys! "ktdesk\r")
   _ (assert ('glyph = (d 'mode)))
   _ (keys! "D\r")
   _ (assert ('name = (d 'mode)))
   _ (keys! "the desk\r")
   _ (assert ('map = (d 'mode)) (lvl 'things 'desk) ("D" = (lvl 'things 'desk 'gl)) (4 = (lvl 'things 'desk 'x))
             (220 = (lvl 'things 'desk 'fg)) (has? (d 'msg) "placed"))
   _ (keys! "c196 -1\r")
   _ (assert (196 = (lvl 'things 'desk 'fg)) (-1 = (lvl 'things 'desk 'bg)))
   ; the start moves; a prompt backs out on escape; an empty entry is refused
   _ (keys! "hhhm")
   _ (assert (1 = (lvl 'sx)) (1 = (lvl 'sy)) (has? (d 'msg) "start"))
   _ (keys! "t")
   _ (design-key d 27)
   _ (assert ('map = (d 'mode)))
   _ (keys! "t\r")
   _ (assert (has? (d 'msg) "nothing entered"))
   ; remove takes the thing under the cursor
   _ (keys! "lllx")
   _ (assert !(lvl 'things 'desk) (has? (d 'msg) "removed"))
   ; save, and the file loads back as the same level, tiles and all; the story plays it
   _ (keys! "s")
   L (load-level S)
   _ (assert (has? (d 'msg) "saved") !(d 'dirty) (= (data-of L) (data-of lvl)) (33 = (L 'tiles 126 'fg)))
   g (story-new L)
   _ (story-key g 108)
   _ (assert (2 = (g 'x)))
   ; the frame: the title bar, what is under the cursor, the brush, the help
   f (plain (design-frame d 60 12))
   _ (assert (has? f "design: a test") (has? f "4,1 # wall") (has? f "brush: .") (has? f "palette: ~") (has? f "hjkl yubn move"))   ; past the row's end is wall
   ; ..and no line of a frame is wider than the screen: one that wrapped would scroll the
   ; frame up a row, and every key would redraw the whole map
   _ (assert (foldl (\ a l (a && #l <= 41)) 1 (split "\n" (plain (design-frame d 40 12)))))
   _ (test_fin ())
   _ (puts "design: ok -- a map from keys alone, its palette and pens, saved as the datum story plays\n")
   0)
