; --- test/host/design.l: the level designer, headless ---
; every key is a pure step and every frame a pure lay, so the designer gates here: a
; level built from keys alone -- two rooms placed and named, an exit linked across the
; map, a thing, the start -- saved as the datum story.l plays, loaded back the same,
; and the frame showing the boxes, the cursor's room and its exits. the tty runner,
; vi on the file and play stay live probes.
;   cat test/00-init.l test/host/design.l | out/love

(reads (open "src/apps/rove/story.l" "r"))
(reads (open "src/apps/rove/design.l" "r"))

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
   d (design-new (level "a test" {} ()) S)
   (keys! s) (each (map (i \ s i) ^#s) (c \ design-key d c))
   ; two rooms, the second a cell to the right; back to the first; an exit east, its
   ; target picked with the cursor; a thing in the second; the start on the first
   _ (keys! "nhall\rlnyard\rheeast\rl\rtbench\rhm")
   lvl (d 'lvl)
   _ (assert ('hall = (lvl 'start))
             (2 = tally (keys (lvl 'rooms)))
             ('yard = (lvl 'rooms 'hall 'exits 'east))
             (1 = (lvl 'rooms 'yard 'x)) (0 = (lvl 'rooms 'yard 'y))
             (lvl 'rooms 'yard 'things 'bench)
             (has? (d 'msg) "start: hall"))
   ; a name is slugged to its id, and a taken id gets a number
   _ (keys! "lln The Blue Room!\r")
   _ (assert (lvl 'rooms 'the-blue-room))
   _ (keys! "jnhall\r")
   _ (assert (lvl 'rooms 'hall-1))
   ; remove takes the room and every exit into it
   _ (keys! "kx")
   _ (assert !(lvl 'rooms 'the-blue-room))
   _ (keys! "hx")                                    ; yard goes, and hall's exit to it
   _ (assert !(lvl 'rooms 'yard) !(lvl 'rooms 'hall 'exits 'east) (lvl 'rooms 'hall))
   ; a prompt backs out on escape, and an empty entry is refused
   _ (keys! "n")
   _ (assert ('name = (d 'mode)))
   _ (design-key d 27)
   _ (assert ('map = (d 'mode)))
   _ (keys! "n\r")
   _ (assert (has? (d 'msg) "nothing entered"))
   ; save, and the file loads back as the same level
   _ (design-key d 115)
   L (load-level S)
   _ (assert (has? (d 'msg) "saved") !(d 'dirty) (= (data-of L) (data-of lvl)))
   ; the frame: the title bar, the box under the cursor, its line, the help
   _ (keys! "h")
   f (plain (design-frame d 60 14))
   _ (assert (has? f "design: a test") (has? f "|hall") (has? f "+*---")
             (has? f "hall  exits:") (has? f "hjkl move"))
   _ (test_fin ())
   _ (puts "design: ok -- a level from keys alone, saved as the datum story plays\n")
   0)
