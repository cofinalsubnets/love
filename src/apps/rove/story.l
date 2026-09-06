; story -- rove's fiction engine: a roguelike map to walk, and dialog windows to talk in.
;
; a level is a datum in a file (src/apps/rove/levels) the reader and printer round-trip,
; so the designer (design.l) edits what this file plays:
;   (level TITLE (start X Y) (map ROW ..) (things (ID X Y GLYPH NAME STEP ..) ..))
; the map's rows are tiles: # a wall, anything else floor. a thing sits on a tile with
; a glyph, and bumping it opens its dialog: a window over the map that plays the
; thing's steps -- (say TEXT ..) pages of words, (ask) a prompt -- and the prompt is
; where the words go free: an interpreter takes a line (read X, open X, look, help, or a
; love form, evaluated) and answers into the window. only inside a window; on the map
; the keys are the roguelike's, hjkl yubn and the arrows, @ for you.
;
; the engine is pure -- a turn is (story-key g c), a frame (story-frame g w h) into any
; port -- so it gates headless (test/host/story.l); only story-run ties the tty.
;
; the library: (library ROOT) lays a hall with a shelf per crew module under the root,
; each shelf's dialog the module's header as libra lifts it and its books the files;
; `read` a book is its own header, `open` a book is vi called in place, and the hatch
; in the floor runs the crawl (rove.l). no story in this file: the words are the levels'.
;
; usage: love story [LEVEL.l | ROOT]      a level file (default src/apps/rove/levels/lighthouse.l),
;                                         or a root to lift the library from (src/apps)
(module (story story-main story-run story-new story-key story-frame open-window window-say
         level thing level-of data-of level-text load-level save-level library
         tile thing-at wrap joins)
(:
 ; --- levels as data ------------------------------------------------------------
 ; in play: level {'title 'rows (strings) 'w 'h 'sx 'sy 'things {id thing ..}}; a thing
 ; {'id 'x 'y 'gl 'name 'steps (the dialog) 'books {word file ..}} -- books are the
 ; library's, a hand level's things carry none
 (level title sx sy rows things) (: w (foldl (\ a r (#r < a ? a #r)) 0 rows)
                                    {'title title 'sx sx 'sy sy 'rows rows 'w w 'h #rows 'things things})
 (thing id x y gl nm steps) {'id id 'x x 'y y 'gl gl 'name nm 'steps steps 'books {}}
 (tile lvl x y) (: rows (lvl 'rows)
                   (? (0 <= y < lvl 'h && 0 <= x < #(rows y)) ((rows y) x) 35))   ; off the map is wall
 (wall? lvl x y) (tile lvl x y = 35)
 (thing-at lvl x y) (: ts (filter (id \ lvl 'things id 'x = x && lvl 'things id 'y = y) (keys (lvl 'things)))
                       (two? ts ? (lvl 'things <ts) ()))

 ; the file's datum -> the level in play, and back. a shown level is a legal file.
 (part k l) (: p (filter (x \ two? x && <x = k) l) (two? p ? ><p ()))
 (level-of d) (: st (part 'start >d)
                 things (foldl (\ t r (pin t <r (thing <r (r 1) (r 2) (r 3) (r 4) (drop 5 r)))) {} (part 'things >d))
                 (level (d 1) (? (two? st) <st 1) (? (two? st) (st 1) 1) (part 'map >d) things))
 (data-of lvl) (: (row id) (: t (lvl 'things id) ([id (t 'x) (t 'y) (t 'gl) (t 'name)] + (t 'steps)))
                  ['level (lvl 'title) ['start (lvl 'sx) (lvl 'sy)] ('map . lvl 'rows)
                   ('things . map row (sort (keys (lvl 'things))))])
 ; the map one row per line and a thing per line, so the file reads as a level
 (level-text lvl) (: d (data-of lvl)
                     ("(level " + show (d 1) + " " + show (d 2) + "\n  (map\n"
                      + joins (map (r \ "   " + show r) (lvl 'rows)) "\n" + ")\n  (things\n"
                      + joins (map (r \ "   " + show r) >(d 4)) "\n" + "))\n"))
 (load-level p) (: q (open p "r")
                   (? !(hot? q) ()
                      (: s (slurp q) _ (close q) r (sound s)
                         (two? r && two? <r && <<r = 'level ? (level-of <r) ()))))
 (save-level p lvl) (: q (open p "w") (hot? q ? (say q (level-text lvl), close q, 1) 0))

 ; --- the state: where you stand, and the window if one is open ------------------
 (story-new lvl) {'lvl lvl 'x (lvl 'sx) 'y (lvl 'sy) 'win () 'over 0 'msg ""}
 (words s) (filter (w \ 0 < #w) (split " " s))
 (joins l sp) (? (one? l) "" (one? >l) <l (<l + sp + joins >l sp))
 (wrap s w) (: (go ws cur acc) (? (one? ws) (rev (cur . acc))
                                  (: nx (0 < #cur ? (cur + " " + <ws) <ws)
                                     (? (#nx <= w) (go >ws nx acc)
                                        (0 < #cur) (go ws "" (cur . acc))
                                        (go >ws "" (snip nx 0 w . acc)))))
               (go (words s) "" ()))
 (concat ls) (foldl (\ a l (cat a l)) () ls)               ; cat is the pairwise append
 (lines-of s w) (concat (map (l \ wrap l w) (split "\n" s)))

 ; --- windows: a thing's dialog, one step at a time ---------------------------------
 ; win {'title 'lines 'top 'steps 'prompt 'line 'thing 'w}: lines are the words shown so
 ; far (a page is a say step's text appended), top the first line shown, steps what is
 ; left to play, prompt whether the line at the foot takes typing
 (open-window g t) (: w {'title (t 'name) 'lines () 'top 0 'steps (t 'steps) 'prompt 0 'line "" 'thing t 'w 56}
                      _ (pin g 'win w)
                      (step g))
 (window-say g s) (: w (g 'win)
                      ls (lines-of s (w 'w - 4))
                      _ (pin w 'lines (w 'lines + ls))
                      ; the newest words at the foot: the top slides so the last page shows
                      (pin w 'top (: n #(w 'lines) k (page-rows g) (n <= k ? 0 (n - k)))))
 (page-rows g) 10
 ; the next step of the dialog: a say appends its words, an ask opens the prompt, a
 ; hatch runs the crawl, and nothing left closes the window
 (step g) (: w (g 'win) st (w 'steps)
             (? (one? st) (pin g 'win ())
                (: s <st
                   _ (pin w 'steps >st)
                   (<s @ 'say (each >s (t \ window-say g t))
                        'ask (pin w 'prompt 1)
                        'hatch (: run (from 'rove 'rove-run)
                                  (? run (run (), window-say g "you climb back out of the hold.")
                                     (window-say g "the hatch is sealed on this seat.")))
                        (window-say g ("?? " + show s))))))
 (mod nm k) (from nm k)
 ; the interpreter, inside a window: a book to read or open off the thing's shelf, a
 ; look, a help, or a love form evaluated and shown -- every answer lands in the window
 (interp g ln) (: w (g 'win) t (w 'thing)
   ws (words ln) v (? (two? ws) <ws "") n (? (two? >ws) <>ws "")
   (book f) (: q (open f "r") (? (hot? q) (: s (slurp q) (close q, s)) ()))
   (with f) (: p (t 'books (nom n))
               (? !(0 < #n) (window-say g (v + " what?"))
                  !p (window-say g ("there is no " + n + " here."))
                  (f p)))
   _ (window-say g ("> " + ln))
   (? (0 < #ln && ln 0 = 40)
      (: r (trap (\ _ (show (ev (: d (sound ln) (two? d ? <d ()))))) () (\ a b (";; " + show a + " " + show b)))
         (window-say g r))
      (v @ ("read" || "r") (with (p \ (: lift (mod 'libra 'ldoc-md) s (book p)
                                          (? !s (window-say g ("the book is missing: " + p))
                                             !lift (window-say g "you cannot read here.")
                                             (: md (lift s) (window-say g (0 < #md ? md "the pages are blank.")))))))
           ("open" || "o") (with (p \ (: vi (mod 'vi 'vi-main)
                                          (? vi (vi [p], window-say g ("you close " + n + "."))
                                             (window-say g "no editor on this seat.")))))
           ("look" || "l") (window-say g ("books: " + joins (map show (sort (keys (t 'books)))) ", "))
           ("help" || "?") (window-say g "read <book>, open <book>, look -- or a love form in parens. esc closes.")
           (window-say g ("you cannot " + ln + ".")))))

 ; --- one key: the map's, or the window's ----------------------------------------
 (move g dx dy) (: lvl (g 'lvl) nx (g 'x + dx) ny (g 'y + dy) t (thing-at lvl nx ny)
                   (? t (open-window g t)
                      (wall? lvl nx ny) g
                      (pins g 'x nx 'y ny)))
 (story-key g c) (: w (g 'win)
   _ (? !w (c @ (104 || 68) (move g -1 0)  (108 || 67) (move g 1 0)
              (107 || 65) (move g 0 -1)  (106 || 66) (move g 0 1)
              121 (move g -1 -1) 117 (move g 1 -1) 98 (move g -1 1) 110 (move g 1 1)
              (113 || 27) (pin g 'over 'quit)
              63 (open-window g (thing 'help 0 0 "?" "help" '((say "hjkl yubn and the arrows move you. walk into a thing to talk to it. q leaves."))))
              g)
      (w 'prompt) (c @ 27 (pin g 'win ())
                       (13 || 10) (: l (w 'line) (pin w 'line "", 0 < #l ? (interp g l)))
                       (127 || 8) (: l (w 'line) (0 < #l ? (pin w 'line (snip l 0 (#l - 1)))))
                       (32 <= c < 127 ? (pin w 'line (w 'line + string c))))
      (c @ (27 || 113) (pin g 'win ())
           (13 || 10 || 32) (step g)
           107 (0 < w 'top ? (pin w 'top (w 'top - 1)))
           106 (w 'top + page-rows g < #(w 'lines) ? (pin w 'top (w 'top + 1)))
           g))
   g)

 ; --- the frame: the map with @ on it, the window over it, a status line --------------
 ; a grid of rows is laid as glyphs then the window is written over it, so the port
 ; sees one composed frame; the pens are quay's 256 (rove's palette)
 (pad s n) (#s < n ? (s + ((n - #s) (\ t (t + " ")) "")) (snip s 0 n))
 (pen n) ("\e[38;5;" + show n + "m")
 (story-frame g w h) (: j (jug 0) lvl (g 'lvl) win (g 'win)
   mh (h - 1)
   ; the map row by row: a wall, a floor, a thing, you -- each cell a glyph and a pen
   spot (foldl (\ t id (: th (lvl 'things id) (pin t [(th 'x) (th 'y)] th))) {} (keys (lvl 'things)))
   (cell x y) (? (x = g 'x && y = g 'y) [64 228]
                 (peep spot [x y] 0) (: th (spot [x y]) [((th 'gl) 0) 220])
                 !(y < lvl 'h && x < #((lvl 'rows) y)) [32 0]           ; past the map: nothing
                 (wall? lvl x y) [35 242]
                 [46 238])
   (row y) (: (go x p acc) (? (x < w) (: c (cell x y) p2 <>c
                                          (go (x + 1) p2 (acc + (p2 = p ? "" (pen p2)) + string <c)))
                              acc)
              (go 0 -1 ""))
   rows (map row (jot mh))
   ; the window: a box of the dialog's lines, its title in the top border, a prompt or
   ; a more-mark at the foot, laid over the rows it covers
   rows2 (? !win rows
            (: ww (win 'w) ls (win 'lines) k (page-rows g)
               shown (take k (drop (win 'top) ls))
               foot (? (win 'prompt) ("> " + win 'line)
                       (win 'top + k < #ls) "-- more --"
                       (one? (win 'steps)) "-- esc --" "-- enter --")
               inner (map (l \ "| " + pad l (ww - 4) + " |") (shown + (map (\ _ "") (jot (k - #shown))) + [foot]))
               top ("+-" + pad (win 'title + " ") (ww - 4) "-" + "+")
               box ([top] + inner + [("+" + ((ww - 2) (\ t (t + "-")) "") + "+")])
               x0 ((w - ww) // 2) y0 ((mh - #box) // 2)
               (map (\ i (? (y0 <= i < y0 + #box)
                            (: r (rows i) b (box (i - y0))
                               ; the pen resets around the box, so the map's colour does not bleed in
                               (snip-cells r x0 + "\e[0m" + pen 252 + b + pen 238 + (x0 + ww < w ? "" "")))
                            (rows i)))
                    (jot mh))))
   _ (each rows2 (r \ say j (r + "\e[0m\e[K\r\n")))
   _ (say j ("\e[7m" + pad (" " + lvl 'title + "  @ " + show (g 'x) + "," + show (g 'y) + "  " + g 'msg
                            + (win ? "  esc closes" "  ? help  q quits")) w + "\e[0m\e[K"))
   ("\e[H" + slurp j))
 ; the first n cells of a painted row: pens have no width, so count the glyphs
 (snip-cells r n) (: (past i) (r i = 109 ? (i + 1) (past (i + 1)))          ; the byte after an SGR's m
                     (go i k acc) (? (i < #r && k < n)
                                     (: c (r i)
                                        (? (c = 27) (: e (past i) (go e k (acc + snip r i e)))
                                           (go (i + 1) (k + 1) (acc + string c))))
                                     acc)
                     (go 0 0 ""))

 ; --- the library: a hall of shelves, one per crew module under root ------------------
 (base p) (: n #p (go k r) (k < n ? (go (k + 1) (p k = 47 ? (k + 1) r)) (snip p r n)) (go 0 0))
 (ends? s t) (: n #s m #t ((m <= n) && (snip s (n - m) n = t)))
 (first-para md) (: ls (split "\n" md)
                    (go l acc) (? !(two? l) acc
                                  (0 < #(<l) && !(<l 0 = 35)) (go >l (0 < #acc ? (acc + " " + <l) <l))
                                  (0 < #acc) acc
                                  (go >l acc))
                    (go ls ""))
 (head-of f) (: q (open f "r") lift (mod 'libra 'ldoc-md)
                (hot? q && lift ? (: s (slurp q) (close q, first-para (lift s))) ""))
 (library root) (:
   dirs (sort (filter (d \ two? (readdir (root + "/" + d))) (readdir root)))
   n #dirs
   cols 6 rowsn ((n + cols - 1) // cols)
   ; the hall: a shelf every 4 columns and 3 rows, a border of wall, the hatch at the foot
   w (2 + 4 * cols + 1) h (3 + 3 * rowsn + 2)
   (line y) (: (go x acc) (? (x < w) (go (x + 1) (acc + (? (y = 0 || y = h - 1 || x = 0 || x = w - 1) "#" "."))) acc) (go 0 ""))
   rows (map line (jot h))
   (shelf i d) (: p (root + "/" + d)
                  fs (sort (filter (f \ ends? f ".l") (readdir p)))
                  txt (: t (head-of (p + "/" + d + ".l")) (0 < #t ? t ("the " + d + " shelf. source, bound.")))
                  th (thing (nom d) (3 + 4 * (i % cols)) (2 + 3 * (i // cols)) "|" (d + "'s shelf")
                            [['say txt ("books: " + joins (map (f \ snip f 0 (#f - 2)) fs) ", ") "read one, open one, or look."] '(ask)])
                  _ (pin th 'books (foldl (\ t f (pin t (nom (snip f 0 (#f - 2))) (p + "/" + f))) {} fs))
                  th)
   things (foldl (\ t i (: th (shelf i (dirs i)) (pin t (th 'id) th))) {} (jot n))
   _ (pin things 'hatch (thing 'hatch (w // 2) (h - 2) ">" "the hatch" '((say "a grating in the floor, and the hold below.") (hatch))))
   (level "the library" 1 1 rows things))

 ; --- the runner: the story on the tty, a key a turn ---------------------------------
 (story-run lvl) (: ws (winsize 0)
                    h (two? ws && 7 < <ws ? <ws 24)
                    w (two? ws && 19 < <>ws ? <>ws 80)
                    g (story-new lvl)
                    (show _) (say out (story-frame g w h))
                    ; an escape alone is a key, a CSI arrow its final byte; a byte that is
                    ; neither goes back for the next read, so esc then q is two keys
                    (key _) (see in @ 27 (rest 1, cue? 0 ? (see in @ 91 (see in) c (unsee in c, 27)) 27)
                                       c c)
                    (sail _) (show (), key () @ -1 () c (story-key g c, g 'over ? () (sail ())))
                    (raw 1, say out "\e[?1049h\e[?25l\e[2J", sail (),
                     say out "\e[0m\e[?25h\e[?1049l", flush out, raw 0, 0))
 ; the verb: a level file, or the library under a root; the page has its own door (web.l)
 (story-main as) (: p (two? as ? <as "src/apps/rove/levels/lighthouse.l")
                     lvl (? (two? (readdir p)) (library p) (load-level p))
                     (? lvl (story-run lvl) (say err ("story: not a level: " + p + "\n"), 1)))
 _ (pins (from 'verbs 'tab) 'story story-main))
) ; module story
