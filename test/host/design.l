; test/host/design.l -- the level designer headless: a map painted from keys, saved as the datum
; story plays and loaded back the same, and the frame. the runner is a live probe: `love lore design`.
; run: cat test/00-init.l test/host/00-host.l test/host/design.l | out/love

(borrow 'story)
(borrow 'design)

(: S "/tmp/designtest.l"
   d (design-new (level "a test" 1 1 ["###" "#.#" "###"] {} {}) S)
   (keys! s) (each (map (i \ s i) ^#s) (c \ design-key d c))
   lvl (d 'lvl)
   ; floor east past the map's edge grows the row
   _ (keys! "l.l.j#")
   _ (test (46 = tile lvl 2 1) (46 = tile lvl 3 1) (35 = tile lvl 3 2) (4 = lvl 'w))
   _ (keys! "y")
   _ (test (2 = d 'cx) (1 = d 'cy))
   _ (keys! "n")
   _ (test (3 = d 'cx) (2 = d 'cy))
   ; a new tile kind in one line is the brush; space paints it; c sets its pens
   _ (keys! "a~ ~ 27 17 wall\r")
   _ (test ('map = d 'mode) (126 = d 'brush) (lvl 'tiles 126) (wall? lvl 0 99)   ; ..and it stops you
             (17 = lvl 'tiles 126 'bg) (has? (d 'msg) "brush"))
   _ (keys! "l ")
   _ (test (126 = tile lvl 4 2))
   _ (keys! "c33 18\r")
   _ (test (33 = lvl 'tiles 126 'fg) (18 = lvl 'tiles 126 'bg))
   _ (keys! "1")
   _ (test (126 = d 'brush))
   _ (keys! ".")
   _ (test (46 = d 'brush) (46 = tile lvl 4 2))
   ; a thing at the cursor: id, glyph, name, in three prompts; then its pens
   _ (keys! "ktdesk\r")
   _ (test ('glyph = d 'mode))
   _ (keys! "D\r")
   _ (test ('name = d 'mode))
   _ (keys! "the desk\r")
   _ (test ('map = d 'mode) (lvl 'things 'desk) ("D" = lvl 'things 'desk 'gl) (4 = lvl 'things 'desk 'x)
             (220 = lvl 'things 'desk 'fg) (has? (d 'msg) "placed"))
   _ (keys! "c196 -1\r")
   _ (test (196 = lvl 'things 'desk 'fg) (-1 = lvl 'things 'desk 'bg))
   ; the start moves; a prompt backs out on escape; an empty entry is refused
   _ (keys! "hhhm")
   _ (test (1 = lvl 'sx) (1 = lvl 'sy) (has? (d 'msg) "start"))
   _ (keys! "t")
   _ (design-key d 27)
   _ (test ('map = d 'mode))
   _ (keys! "t\r")
   _ (test (has? (d 'msg) "nothing entered"))
   _ (keys! "lllx")
   _ (test !(lvl 'things 'desk) (has? (d 'msg) "removed"))
   ; saved, it loads back the same, and the story plays it
   _ (keys! "s")
   L (load-level S)
   _ (test (has? (d 'msg) "saved") !(d 'dirty) (data-of L = data-of lvl) (33 = L 'tiles 126 'fg))
   g (story-new L)
   _ (story-key g 108)
   _ (test (2 = g 'x))
   f (h-plain (design-frame d 60 12))
   (test (has? f "design: a test") (has? f "4,1 # wall") (has? f "brush: .") (has? f "palette: ~") (has? f "hjkl yubn move"),     ; past the row's end is wall
    ; no frame line wider than the screen: a wrap would scroll and redraw the map every key
    test (foldl (a \ l \ (a && #l <= 41)) 1 (split "\n" (h-plain (design-frame d 40 12)))),
    test_fin (),
    puts "design: ok -- a map from keys alone, its palette and pens, saved as the datum story plays\n",
    0))
