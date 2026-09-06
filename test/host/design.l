; --- test/host/design.l: the level designer, headless ---
; every key is a pure step and every frame a pure lay, so the designer gates here: a
; map painted from keys alone -- walls and floor at the cursor, a thing placed in three
; prompts, the start -- saved as the datum story.l plays and loaded back the same, and
; the frame showing the cursor, the tile under it, the help. the runner, vi on the
; file and play stay live probes: `love design`.
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
   d (design-new (level "a test" 1 1 ["###" "#.#" "###"] {}) S)
   (keys! s) (each (map (i \ s i) ^#s) (c \ design-key d c))
   lvl (d 'lvl)
   ; floor to the east, past the map's edge: the row grows; a wall south of that
   _ (keys! "l.l.j#")
   _ (assert (46 = tile lvl 2 1) (46 = tile lvl 3 1) (35 = tile lvl 3 2) (4 = (lvl 'w)))
   ; a thing at the cursor: id, glyph, name, in three prompts
   _ (keys! "ktdesk\r")
   _ (assert ('glyph = (d 'mode)))
   _ (keys! "D\r")
   _ (assert ('name = (d 'mode)))
   _ (keys! "the desk\r")
   _ (assert ('map = (d 'mode)) (lvl 'things 'desk) ("D" = (lvl 'things 'desk 'gl)) (3 = (lvl 'things 'desk 'x))
             (has? (d 'msg) "placed"))
   ; the start moves; a prompt backs out on escape; an empty entry is refused
   _ (keys! "hhm")
   _ (assert (1 = (lvl 'sx)) (1 = (lvl 'sy)) (has? (d 'msg) "start"))
   _ (keys! "t")
   _ (design-key d 27)
   _ (assert ('map = (d 'mode)))
   _ (keys! "t\r")
   _ (assert (has? (d 'msg) "nothing entered"))
   ; remove takes the thing under the cursor
   _ (keys! "llx")
   _ (assert !(lvl 'things 'desk) (has? (d 'msg) "removed"))
   ; save, and the file loads back as the same level; the story plays it
   _ (keys! "s")
   L (load-level S)
   _ (assert (has? (d 'msg) "saved") !(d 'dirty) (= (data-of L) (data-of lvl)))
   g (story-new L)
   _ (story-key g 108)
   _ (assert (2 = (g 'x)))
   ; the frame: the title bar, the cursor's cell, the help
   f (plain (design-frame d 40 12))
   _ (assert (has? f "design: a test") (has? f "3,1 floor") (has? f "hjkl move"))
   _ (test_fin ())
   _ (puts "design: ok -- a map from keys alone, saved as the datum story plays\n")
   0)
