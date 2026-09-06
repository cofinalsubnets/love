; design -- the level designer: a story's rooms laid out on a map, edited where they
; stand. the map is a grid of cells, a room a box in its cell, and every edit is a key
; on the box under the cursor: a room is placed, named, linked to another by an exit,
; given a thing, made the start, or removed, and the level is saved as the datum
; story.l plays (src/apps/rove/levels). the words themselves -- a room's text, a thing's
; -- are edited in vi on the file, and the level is played from here to try it.
;
;   hjkl / arrows  the cursor        n  a new room here (then its name)      s  save
;   e  an exit from this room: the word, then the cursor on the target, enter
;   t  a thing here (its word; the name and text are the file's, under v)
;   r  rename   m  the start is here   x  remove   v  save and open the file in vi
;   p  save and play the level   q  quit
;
; every key is a pure step on the state and every frame a pure lay into a port, so
; the designer gates headless (test/host/design.l); only `design` ties the tty. the
; engine's words -- room, thing, level, load-level, save-level, story -- are story.l's,
; loaded first.
; usage: out/love -l src/apps/rove/story.l -l src/apps/rove/design.l -e '(design "src/apps/rove/levels/lighthouse.l")'

(:
 ; --- the map: cells of cw x ch, a room a box in its cell -----------------------
 cw 14 ch 4
 (room-at lvl x y) (: ids (filter (id \ lvl 'rooms id 'x = x && lvl 'rooms id 'y = y) (keys (lvl 'rooms)))
                      (two? ids ? <ids ()))
 (design-new lvl p) {'lvl lvl 'path p 'cx 0 'cy 0 'mode 'map 'buf "" 'msg "" 'from () 'word () 'dirty 0}
 (tell d s) (pin d 'msg s)
 (touch d) (pin d 'dirty 1)

 ; an id from a name: the letters, joined by dashes, told apart from the taken ones
 (slug s) (: (go i acc dash) (? (i < #s)
                                (: c (s i)
                                   (? (97 <= c < 123 || 48 <= c < 58) (go (i + 1) (acc + (dash && 0 < #acc ? "-" "") + string c) 0)
                                      (65 <= c < 91) (go (i + 1) (acc + (dash && 0 < #acc ? "-" "") + string (c + 32)) 0)
                                      (go (i + 1) acc 1)))
                                acc)
              (: a (go 0 "" 0) (0 < #a ? a "room")))
 (fresh-id lvl nm) (: base (slug nm)
                      (go k) (: id (nom (k = 0 ? base (base + "-" + show k)))
                                (lvl 'rooms id ? (go (k + 1)) id))
                      (go 0))

 ; --- the edits, each on the room under the cursor --------------------------------
 (here d) (room-at (d 'lvl) (d 'cx) (d 'cy))
 (add-room d nm) (: lvl (d 'lvl) id (fresh-id lvl nm)
                    rm (room nm "" {} {})
                    _ (pins rm 'x (d 'cx) 'y (d 'cy))
                    _ (pin (lvl 'rooms) id rm)
                    _ (lvl 'start ? () (pin lvl 'start id))
                    (touch d, tell d ("placed " + show id)))
 (rename-room d nm) (: id (here d) (id ? (pin (d 'lvl 'rooms id) 'name nm, touch d, tell d ("named " + show id)) d))
 (drop-room d) (: id (here d) lvl (d 'lvl)
                  (? !id (tell d "nothing here")
                     (: _ (pull (lvl 'rooms) id ())
                        _ (each (keys (lvl 'rooms))                        ; and every exit that led here
                                (o \ each (keys (lvl 'rooms o 'exits))
                                          (w \ lvl 'rooms o 'exits w = id ? (pull (lvl 'rooms o 'exits) w ()))))
                        _ (lvl 'start = id ? (pin lvl 'start (: ks (sort (keys (lvl 'rooms))) (two? ks ? <ks ()))))
                        (touch d, tell d ("removed " + show id)))))
 (link d from w to) (: _ (pin (d 'lvl 'rooms from 'exits) w to)
                       (touch d, tell d (show from + " " + show w + " -> " + show to)))
 (add-thing d w) (: id (here d)
                    (? !id (tell d "nothing here")
                       (: _ (pin (d 'lvl 'rooms id 'things) (nom w) (thing w "" ()))
                          (touch d, tell d ("a " + w + " in " + show id)))))
 (set-start d) (: id (here d) (id ? (pin (d 'lvl) 'start id, touch d, tell d ("start: " + show id)) (tell d "nothing here")))
 (save d) (: ok (save-level (d 'path) (d 'lvl))
             (ok ? (pin d 'dirty 0, tell d ("saved " + d 'path)) (tell d ("cannot write " + d 'path))))
 (reload d) (: lvl (load-level (d 'path))
               (lvl ? (pin d 'lvl lvl, tell d "reloaded") (tell d "the file no longer reads as a level")))

 ; --- one key: the mode says what a key means -------------------------------------
 ; map: the cursor and the edits. a prompt (name rename exit thing) collects a line
 ; into buf; link moves the cursor to the target and enter commits. esc backs out.
 (nat n) (0 <= n ? n 0)
 (move d dx dy) (pins d 'cx (nat (d 'cx + dx)) 'cy (nat (d 'cy + dy)))
 (prompt d m) (pins d 'mode m 'buf "")
 (commit d) (: b (d 'buf) m (d 'mode)
               _ (pin d 'mode 'map)
               (? !(0 < #b) (tell d "nothing entered")
                  (m @ 'name   (add-room d b)
                       'rename (rename-room d b)
                       'thing  (add-thing d b)
                       'exit   (: id (here d) (? id (pins d 'mode 'link 'from id 'word (nom b), tell d ("exit " + b + ": move to the target, enter"))
                                                 (tell d "nothing here")))
                       d)))
 (design-key d c) (: m (d 'mode)
   (? (m = 'map || m = 'link)
      (c @ (104 || 68) (move d -1 0)   (108 || 67) (move d 1 0)
           (107 || 65) (move d 0 -1)   (106 || 66) (move d 0 1)
           (m = 'link ?
            (c @ (13 || 10) (: to (here d) _ (pin d 'mode 'map) (? to (link d (d 'from) (d 'word) to) (tell d "no room there")))
                 27 (pin d 'mode 'map, tell d "unlinked")
                 d)
            (c @ 110 (prompt d 'name)  114 (here d ? (prompt d 'rename) (tell d "nothing here"))
                 101 (here d ? (prompt d 'exit) (tell d "nothing here"))
                 116 (here d ? (prompt d 'thing) (tell d "nothing here"))
                 120 (drop-room d)  109 (set-start d)  115 (save d)
                 d)))
      (c @ (13 || 10) (commit d)
           27 (pin d 'mode 'map, tell d "")
           (127 || 8) (: b (d 'buf) (0 < #b ? (pin d 'buf (snip b 0 (#b - 1))) d))
           (32 <= c < 127 ? (pin d 'buf (d 'buf + string c)) d))))

 ; --- the frame: the map, the room under the cursor, the help, the message ----------
 (pad s n) (#s < n ? (s + ((n - #s) (\ t (t + " ")) "")) (snip s 0 n))
 (box-rows lvl id cur?) (: r (lvl 'rooms id) nm (pad (r 'name) (cw - 4))
                           st (lvl 'start = id ? "*" " ")
                           hi (cur? ? "\e[7m" "") lo (cur? ? "\e[0m" "")
                           [(hi + "+" + ((cw - 4) (\ t (t + "-")) "") + "+" + lo)
                            (hi + "|" + nm + "|" + lo)
                            (hi + "+" + st + ((cw - 5) (\ t (t + "-")) "") + "+" + lo)])
 (design-frame d w h) (: j (jug 0) lvl (d 'lvl)
   cols (w // cw) rows ((h - 5) // ch)
   ; the map: each cell's box, or the bare cursor, laid row by row
   ; a cell is cw - 2 glyphs wide, the box exactly that (the pen's escapes have no width)
   (cell x y k) (: id (room-at lvl x y) cur? (x = d 'cx && y = d 'cy)
                   (? id (box-rows lvl id cur? k)
                      cur? (k @ 0 ("\e[7m+\e[0m" + pad "" (cw - 3)) (pad "" (cw - 2)))
                      (pad "" (cw - 2))))
   (line y k) (joins (map (x \ cell x y k) (jot cols)) " ")
   _ (say j ("\e[H\e[0m\e[7m" + pad (" design: " + lvl 'title + " -- " + d 'path + (d 'dirty ? " [+]" "")) w + "\e[0m\e[K\r\n"))
   _ (each (jot rows) (\ y (: _ (each (jot (ch - 1)) (\ k (say j (line y k + "\e[K\r\n"))))
                             (say j "\e[K\r\n"))))
   ; the room under the cursor: its exits and things, one line
   id (here d)
   r (id ? (lvl 'rooms id))
   about (? !id ("cell " + show (d 'cx) + "," + show (d 'cy) + ": empty")
             (show id + "  exits: " + joins (map (k \ show k + "->" + show (r 'exits k)) (sort (keys (r 'exits)))) " "
              + "  things: " + joins (map show (sort (keys (r 'things)))) " "))
   _ (say j (pad about w + "\e[K\r\n"))
   _ (say j (pad " hjkl move  n new  r rename  e exit  t thing  m start  x remove  v vi  p play  s save  q quit" w + "\e[K\r\n"))
   _ (say j (pad (d 'msg) w + "\e[K\r\n"))
   _ (say j (d 'mode @ 'map  "\e[K"
                       'link ("link " + show (d 'word) + " -> ?\e[K")
                       (show (d 'mode) + ": " + d 'buf + "\e[K")))
   (slurp j))

 ; --- the runner: the designer on the tty ------------------------------------------
 (design p) (: ws (winsize 0)
               h (two? ws && 7 < <ws ? <ws 24)
               w (two? ws && 19 < <>ws ? <>ws 80)
               lvl (: l (load-level p) (l ? l (level p {} ())))
               d (design-new lvl p)
               vi (from 'vi 'vi-main)
               (show _) (say out (design-frame d w h))
               (loop _) (show (), see in @
                 (3 || -1) ()
                 113 (d 'mode = 'map ? () (design-key d 113, loop ()))
                 118 (d 'mode = 'map ? (save d, (? vi (vi [p], reload d) (tell d "no editor on this seat")), loop ())
                                       (design-key d 118, loop ()))
                 112 (d 'mode = 'map ? (save d, story (d 'lvl), say out "\e[?25l\e[2J", loop ())
                                       (design-key d 112, loop ()))
                 c (design-key d c, loop ()))
               (raw 1, say out "\e[?1049h\e[?25l\e[2J", loop (),
                say out "\e[0m\e[?25h\e[?1049l", flush out, raw 0, 0)))
