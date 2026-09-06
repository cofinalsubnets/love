; design -- the level designer: a story's map painted where it is played. the map is
; tiles, a room is what you wall off, and a thing is a glyph placed on a tile; every
; edit is a key at the cursor, and the level is saved as the datum story.l plays
; (src/apps/rove/levels). the words -- a thing's dialog -- are edited in vi on the file,
; and the level is played from here to try it.
;
;   hjkl / arrows  the cursor     #  wall here    .  floor here    m  the start is here
;   t  a thing here: its id, then its glyph, then its name        x  remove the thing here
;   v  save and open the file in vi     p  save and play     s  save     q  quit
;
; every key is a pure step on the state and every frame a pure lay into a port, so
; the designer gates headless (test/host/design.l); only design-run ties the tty. the
; engine's words -- level, thing, load-level, save-level, story-run -- are the story
; module's.
; usage: love design [LEVEL.l]      the file to lay out (default src/apps/rove/levels/lighthouse.l)
(module (design design-main design-run design-new design-key design-frame)
(use 'story)
(:
 (design-new lvl p) {'lvl lvl 'path p 'cx (lvl 'sx) 'cy (lvl 'sy) 'mode 'map 'buf "" 'msg "" 'new () 'dirty 0}
 (tell d s) (pin d 'msg s)
 (touch d) (pin d 'dirty 1)
 (nat n) (0 <= n ? n 0)
 (move d dx dy) (pins d 'cx (nat (d 'cx + dx)) 'cy (nat (d 'cy + dy)))

 ; --- the tiles: a row grows to reach the cursor, and the map grows a row ------------
 (pad s n c) (#s < n ? (s + ((n - #s) (\ t (t + c)) "")) s)
 (set-tile d c) (: lvl (d 'lvl) x (d 'cx) y (d 'cy)
                   rows (lvl 'rows + map (\ _ "") (jot (nat (y + 1 - lvl 'h))))
                   r (pad (rows y) (x + 1) " ")
                   r2 (snip r 0 x + string c + snip r (x + 1) #r)
                   rows2 (map (\ i (i = y ? r2 (rows i))) (jot #rows))
                   _ (pins lvl 'rows rows2 'h #rows2 'w (foldl (\ a s (#s < a ? a #s)) 0 rows2))
                   (touch d))

 ; --- the things: placed at the cursor in three prompts, removed in one -----------
 (add-thing d) (: n (d 'new) lvl (d 'lvl)
                  id (nom (n 'id))
                  _ (pin (lvl 'things) id (thing id (d 'cx) (d 'cy) (n 'gl) (n 'name) [['say (n 'name + ".")]]))
                  (touch d, tell d ("placed " + show id)))
 (drop-thing d) (: t (thing-at (d 'lvl) (d 'cx) (d 'cy))
                   (? t (pull (d 'lvl 'things) (t 'id) (), touch d, tell d ("removed " + show (t 'id)))
                      (tell d "nothing here")))
 (set-start d) (pins (d 'lvl) 'sx (d 'cx) 'sy (d 'cy), touch d, tell d "start: here")
 (save d) (: ok (save-level (d 'path) (d 'lvl))
             (ok ? (pin d 'dirty 0, tell d ("saved " + d 'path)) (tell d ("cannot write " + d 'path))))
 (reload d) (: lvl (load-level (d 'path))
               (lvl ? (pin d 'lvl lvl, tell d "reloaded") (tell d "the file no longer reads as a level")))

 ; --- one key: the mode says what a key means -------------------------------------
 ; map: the cursor and the edits. a prompt collects a line into buf; a thing takes
 ; three in turn (id, glyph, name). esc backs out.
 (prompt d m) (pins d 'mode m 'buf "")
 (commit d) (: b (d 'buf) m (d 'mode)
               _ (pin d 'mode 'map)
               (? !(0 < #b) (tell d "nothing entered")
                  (m @ 'id   (: n {} _ (pin n 'id b) (pin d 'new n, prompt d 'glyph))
                       'glyph (pin (d 'new) 'gl (snip b 0 1), prompt d 'name)
                       'name  (pin (d 'new) 'name b, add-thing d)
                       d)))
 (design-key d c) (: m (d 'mode)
   (? (m = 'map)
      (c @ (104 || 68) (move d -1 0)   (108 || 67) (move d 1 0)
           (107 || 65) (move d 0 -1)   (106 || 66) (move d 0 1)
           35 (set-tile d 35)  46 (set-tile d 46)
           116 (prompt d 'id)  120 (drop-thing d)  109 (set-start d)  115 (save d)
           d)
      (c @ (13 || 10) (commit d)
           27 (pin d 'mode 'map, tell d "")
           (127 || 8) (: b (d 'buf) (0 < #b ? (pin d 'buf (snip b 0 (#b - 1))) d))
           (32 <= c < 127 ? (pin d 'buf (d 'buf + string c)) d))))

 ; --- the frame: the map with the cursor on it, the tile and thing under it, the help --
 (pen n) ("\e[38;5;" + show n + "m")
 (design-frame d w h) (: j (jug 0) lvl (d 'lvl)
   mh (h - 4)
   spot (foldl (\ t id (: th (lvl 'things id) (pin t [(th 'x) (th 'y)] th))) {} (keys (lvl 'things)))
   (cell x y) (? (x = lvl 'sx && y = lvl 'sy) [64 228]
                 (peep spot [x y] 0) [((spot [x y] 'gl) 0) 220]
                 (tile lvl x y = 35) [35 242]
                 (y < lvl 'h && x < #((lvl 'rows) y)) [46 238]
                 [32 0])
   (row y) (: (go x p acc) (? (x < w)
                              (: c (cell x y) cur? (x = d 'cx && y = d 'cy) p2 <>c
                                 (go (x + 1) p2 (acc + (p2 = p ? "" (pen p2)) + (cur? ? ("\e[7m" + string <c + "\e[27m") (string <c)))))
                              acc)
              (go 0 -1 ""))
   _ (say j ("\e[H\e[0m\e[7m" + pad (" design: " + lvl 'title + " -- " + d 'path + (d 'dirty ? " [+]" "")) w " " + "\e[0m\e[K\r\n"))
   _ (each (jot mh) (\ y (say j (row y + "\e[0m\e[K\r\n"))))
   t (thing-at lvl (d 'cx) (d 'cy))
   about ((show (d 'cx) + "," + show (d 'cy) + " ")
          + (t ? (show (t 'id) + " " + t 'gl + " " + t 'name) (tile lvl (d 'cx) (d 'cy) = 35 ? "wall" "floor")))
   _ (say j (pad about w " " + "\e[K\r\n"))
   _ (say j (pad " hjkl move  # wall  . floor  t thing  x remove  m start  v vi  p play  s save  q quit" w " " + "\e[K\r\n"))
   _ (say j (d 'mode @ 'map (pad (d 'msg) w " " + "\e[K")
                       (show (d 'mode) + ": " + d 'buf + "\e[K")))
   (slurp j))

 ; --- the runner: the designer on the tty ------------------------------------------
 (design-run p) (: ws (winsize 0)
                   h (two? ws && 7 < <ws ? <ws 24)
                   w (two? ws && 19 < <>ws ? <>ws 80)
                   lvl (: l (load-level p) (l ? l (level p 1 1 ["#####" "#...#" "#####"] {})))
                   d (design-new lvl p)
                   vi (from 'vi 'vi-main)
                   (show _) (say out (design-frame d w h))
                   (key _) (see in @ 27 (rest 1, cue? 0 ? (see in @ 91 (see in) c (unsee in c, 27)) 27) c c)
                   (loop _) (show (), key () @
                     (3 || -1) ()
                     113 (d 'mode = 'map ? () (design-key d 113, loop ()))
                     118 (d 'mode = 'map ? (save d, (? vi (vi [p], reload d) (tell d "no editor on this seat")), loop ())
                                           (design-key d 118, loop ()))
                     112 (d 'mode = 'map ? (save d, story-run (d 'lvl), say out "\e[?25l\e[2J", loop ())
                                           (design-key d 112, loop ()))
                     c (design-key d c, loop ()))
                   (raw 1, say out "\e[?1049h\e[?25l\e[2J", loop (),
                    say out "\e[0m\e[?25h\e[?1049l", flush out, raw 0, 0))
 (design-main as) (design-run (two? as ? <as "src/apps/rove/levels/lighthouse.l"))
 verb (pins (from 'verbs 'tab) 'design design-main))
) ; module design
