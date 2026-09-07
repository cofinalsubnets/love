; story -- rove's fiction engine: a roguelike map to walk, and dialog windows to talk in.
;
; a level is a datum in a file (apps/rove/levels) the reader and printer round-trip,
; so the designer (design.l) edits what this file plays:
;   (level TITLE (start X Y) (map ROW ..)
;     (tiles (CH GLYPH FG BG SOLID) ..) (things (ID X Y GLYPH FG BG NAME STEP ..) ..))
; the map's rows are characters, and the palette says what each is: the glyph it
; shows, its pens (xterm's 256; -1 the terminal's own), and whether it stops you --
; a solid tile that shows nothing is a wall you cannot see, the outdoors' edge. a
; character the palette lacks is # a wall or a floor drawn as itself. a thing sits on
; a tile with a glyph and pens, and bumping it opens its dialog: a window over the map that plays the
; thing's steps -- (say TEXT ..) pages of words, (ask) a prompt -- and the prompt is
; where the words go free: an interpreter takes a line (read X, open X, look, help, or a
; love form, evaluated) and answers into the window. only inside a window; on the map
; the keys are the roguelike's, hjkl yubn and the arrows, @ for you, and the hand is
; vi's: `:` opens a command line at the foot -- :q leaves, nothing else does -- and esc
; backs out of anything. a map wider or taller than the screen scrolls under you.
;
; the engine is pure -- a turn is (story-key g c), a frame (story-frame g w h) into any
; port -- so it gates headless (test/host/story.l); story-run puts it on cli's stage,
; and its keys are cli's edkey codes (arrows negative, alt letters 256 + the letter).
;
; the library: (library ROOT) lays a hall with a shelf per crew module under the root,
; each shelf's dialog the module's header as libra lifts it and its books the files;
; `read` a book is its own header, `open` a book is vi called in place, and the hatch
; in the floor runs the crawl (rove.l). no story in this file: the words are the levels'.
;
; usage: love story [LEVEL.l | ROOT]      a level file (default apps/rove/levels/lighthouse.l),
;                                         or a root to lift the library from (apps)
(module (story story-main story-run story-new story-key story-frame open-window window-say
         level kind thing level-of data-of level-text load-level save-level library
         tile kind-of wall? thing-at pen wrap joins)
(:
 ; --- levels as data ------------------------------------------------------------
 ; in play: level {'title 'rows (strings) 'w 'h 'sx 'sy 'tiles {ch kind ..} 'things {id
 ; thing ..}}; a kind {'ch 'gl 'fg 'bg 'solid}; a thing {'id 'x 'y 'gl 'fg 'bg 'name
 ; 'steps (the dialog) 'books {word file ..}} -- books are the library's, a hand
 ; level's things carry none
 (level title sx sy rows tiles things) (: w (foldl (\ a r (#r < a ? a #r)) 0 rows)
                                          {'title title 'sx sx 'sy sy 'rows rows 'w w 'h #rows 'tiles tiles 'things things})
 (kind ch gl fg bg solid) {'ch ch 'gl gl 'fg fg 'bg bg 'solid solid}
 (thing id x y gl fg bg nm steps) {'id id 'x x 'y y 'gl gl 'fg fg 'bg bg 'name nm 'steps steps 'books {}}
 ; the palette's defaults: # a wall, anything else a floor drawn as itself
 (kind-of lvl c) (: k (lvl 'tiles c)
                    (? k k (c = 35) (kind 35 "#" 242 -1 1) (kind c (string c) 238 -1 ())))
 (tile lvl x y) (: rows (lvl 'rows)
                   (? (0 <= y < lvl 'h && 0 <= x < #(rows y)) ((rows y) x) 35))   ; off the map is wall
 (wall? lvl x y) (: k (kind-of lvl (tile lvl x y)) (? (k 'solid) 1 0))
 (thing-at lvl x y) (: ts (filter (id \ lvl 'things id 'x = x && lvl 'things id 'y = y) (keys (lvl 'things)))
                       (two? ts ? (lvl 'things <ts) ()))

 ; the file's datum -> the level in play, and back. a shown level is a legal file.
 (part k l) (: p (filter (x \ two? x && <x = k) l) (two? p ? ><p ()))
 (level-of d) (: st (part 'start >d)
                 tiles (foldl (\ t r (pin t (<r 0) (kind (<r 0) (r 1) (r 2) (r 3) (? (r 4) 1 ())))) {} (part 'tiles >d))
                 things (foldl (\ t r (pin t <r (thing <r (r 1) (r 2) (r 3) (r 4) (r 5) (r 6) (drop 7 r)))) {} (part 'things >d))
                 (level (d 1) (? (two? st) <st 1) (? (two? st) (st 1) 1) (part 'map >d) tiles things))
 (data-of lvl) (: (trow c) (: k (lvl 'tiles c) [(string c) (k 'gl) (k 'fg) (k 'bg) (k 'solid ? 'wall ())])
                  (row id) (: t (lvl 'things id) ([id (t 'x) (t 'y) (t 'gl) (t 'fg) (t 'bg) (t 'name)] + (t 'steps)))
                  ['level (lvl 'title) ['start (lvl 'sx) (lvl 'sy)] ('map . lvl 'rows)
                   ('tiles . map trow (sort (keys (lvl 'tiles))))
                   ('things . map row (sort (keys (lvl 'things))))])
 ; the map one row per line, a tile and a thing per line, so the file reads as a level
 (level-text lvl) (: d (data-of lvl)
                     (block k) (joins (map (r \ "   " + show r) >(d k)) "\n")
                     ("(level " + show (d 1) + " " + show (d 2) + "\n  (map\n"
                      + joins (map (r \ "   " + show r) (lvl 'rows)) "\n" + ")\n  (tiles\n"
                      + block 4 + ")\n  (things\n" + block 5 + "))\n"))
 (load-level p) (: q (open p "r")
                   (? !(hot? q) ()
                      (: s (slurp q) _ (close q) r (sound s)
                         (two? r && two? <r && <<r = 'level ? (level-of <r) ()))))
 (save-level p lvl) (: q (open p "w") (hot? q ? (say q (level-text lvl), close q, 1) 0))

 ; --- the state: where you stand, the view's corner, the window if one is open, the
 ; command line if it is -- 'mode is 'map or 'cmd, 'cmd its text --------------------
 (story-new lvl) {'lvl lvl 'x (lvl 'sx) 'y (lvl 'sy) 'vx 0 'vy 0 'win () 'over 0 'msg "" 'mode 'map 'cmd (ednew ())}
 ; the window's prompt and the command line are cli's editor, a key at a time: enter
 ; takes the line and clears it, escape is the caller's, the rest the editor's
 (edit-line t k c enter esc) (: e (t k) _ (edstep e c)
   (e 'ev @ 27 (esc ())
             10 (: l (edtext e) _ (pin t k (ednew ())) (0 < #l ? (enter l)))
             ()))
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
 (open-window g t) (: w {'title (t 'name) 'lines () 'top 0 'steps (t 'steps) 'prompt 0 'line (ednew ()) 'thing t 'w 56}
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

 ; --- one key: the map's, the window's, or the command line's ---------------------
 (move g dx dy) (: lvl (g 'lvl) nx (g 'x + dx) ny (g 'y + dy) t (thing-at lvl nx ny)
                   (? t (open-window g t)
                      (wall? lvl nx ny) g
                      (pins g 'x nx 'y ny)))
 ; the command line: :q leaves; anything else is not a command
 (command g l) (l @ "q" (pin g 'over 'quit)
                   (pin g 'msg ("not a command: " + l)))
 (story-key g c) (: w (g 'win)
   _ (? (g 'mode = 'cmd) (edit-line g 'cmd c (l \ (pin g 'mode 'map, command g l)) (\ _ (pins g 'mode 'map 'cmd (ednew ()))))
        !w (c @ (104 || -1) (move g -1 0)  (108 || -2) (move g 1 0)
                (107 || -8) (move g 0 -1)  (106 || -9) (move g 0 1)
                (121 || 377) (move g -1 -1) (117 || 373) (move g 1 -1)
                (98 || 354) (move g -1 1) (110 || 366) (move g 1 1)
                58 (pins g 'mode 'cmd 'cmd (ednew ()) 'msg "")
                63 (open-window g (thing 'help 0 0 "?" 220 -1 "help" '((say "hjkl yubn and the arrows move you. walk into a thing to talk to it. esc closes a window; :q leaves."))))
                27 (pin g 'msg "")
                g)
        (w 'prompt) (edit-line w 'line c (l \ interp g l) (\ _ (pin g 'win ())))
        (c @ 27 (pin g 'win ())
             (13 || 10 || 32) (step g)
             107 (0 < w 'top ? (pin w 'top (w 'top - 1)))
             106 (w 'top + page-rows g < #(w 'lines) ? (pin w 'top (w 'top + 1)))
             g))
   g)

 ; --- the frame: the map with @ on it, the window over it, a status line --------------
 ; a grid of rows is laid as glyphs then the window is written over it, so the port
 ; sees one composed frame; the pens are quay's 256 (rove's palette)
 (pad s n) (#s < n ? (s + ((n - #s) (\ t (t + " ")) "")) (snip s 0 n))
 ; a pen is a pair (fg bg); -1 is the terminal's own colour on that side
 (pen p) (: fg <p bg <>p
            ((fg < 0 ? "\e[39m" ("\e[38;5;" + show fg + "m")) + (bg < 0 ? "\e[49m" ("\e[48;5;" + show bg + "m"))))
 pen0 '(-1 -1)
 ; the view follows you: its corner slides so you stay a margin in from its edges,
 ; and never past the map's own -- a map inside the view sits at the corner
 (follow g w h) (: lvl (g 'lvl) m 3
                   (clamp v p span len) (: lo (0 < len - span ? (len - span) 0)
                                           v2 (? (p - m < v) (p - m) (v + span - 1 - m < p) (p - span + 1 + m) v)
                                           (? (v2 < 0) 0 (lo < v2) lo v2))
                   (pins g 'vx (clamp (g 'vx) (g 'x) w (lvl 'w)) 'vy (clamp (g 'vy) (g 'y) h (lvl 'h))))
 (story-frame g w h) (: j (jug 0) lvl (g 'lvl) win (g 'win)
   mh (h - 1)
   _ (follow g w mh)
   vx (g 'vx) vy (g 'vy)
   ; the map row by row: the tile's glyph and pens, a thing's, yours -- each cell (glyph . pen)
   spot (foldl (\ t id (: th (lvl 'things id) (pin t [(th 'x) (th 'y)] th))) {} (keys (lvl 'things)))
   (cell x y) (? (x = g 'x && y = g 'y) ["@" 228 -1]
                 (peep spot [x y] 0) (: th (spot [x y]) [(th 'gl) (th 'fg) (th 'bg)])
                 !(y < lvl 'h && x < #((lvl 'rows) y)) [" " -1 -1]        ; past the map: nothing
                 (: k (kind-of lvl (tile lvl x y)) [(k 'gl) (k 'fg) (k 'bg)]))
   (row y) (: (go x p acc) (? (x < w) (: c (cell (vx + x) (vy + y)) p2 >c
                                          (go (x + 1) p2 (acc + (= p2 p ? "" (pen p2)) + <c)))
                              acc)
              (go 0 () ""))
   rows (map row (jot mh))
   ; the window: a box of the dialog's lines, its title in the top border, a prompt or
   ; a more-mark at the foot, laid over the rows it covers
   rows2 (? !win rows
            (: ww (win 'w) ls (win 'lines) k (page-rows g)
               shown (take k (drop (win 'top) ls))
               foot (? (win 'prompt) ("> " + edtext (win 'line))
                       (win 'top + k < #ls) "-- more --"
                       (one? (win 'steps)) "-- esc --" "-- enter --")
               inner (map (l \ "| " + pad l (ww - 4) + " |") (shown + (map (\ _ "") (jot (k - #shown))) + [foot]))
               top ("+-" + pad (win 'title + " ") (ww - 4) "-" + "+")
               box ([top] + inner + [("+" + ((ww - 2) (\ t (t + "-")) "") + "+")])
               x0 ((w - ww) // 2) y0 ((mh - #box) // 2)
               (map (\ i (? (y0 <= i < y0 + #box)
                            (: r (rows i) b (box (i - y0))
                               ; the pen resets around the box, so the map's colour does not bleed in
                               (snip-cells r x0 + "\e[0m" + pen '(252 -1) + b))
                            (rows i)))
                    (jot mh))))
   _ (each rows2 (r \ say j (r + "\e[0m\e[K\r\n")))
   ; the cursor shows only where you type: at the command line's end
   _ (say j (? (g 'mode = 'cmd) (":" + edtext (g 'cmd) + "\e[K\e[?25h")
               ("\e[7m" + pad (" " + lvl 'title + "  @ " + show (g 'x) + "," + show (g 'y) + "  " + g 'msg
                               + (win ? "  esc closes" "  ? help  :q leaves")) w + "\e[0m\e[K\e[?25l")))
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
                  th (thing (nom d) (3 + 4 * (i % cols)) (2 + 3 * (i // cols)) "|" 220 -1 (d + "'s shelf")
                            [['say txt ("books: " + joins (map (f \ snip f 0 (#f - 2)) fs) ", ") "read one, open one, or look."] '(ask)])
                  _ (pin th 'books (foldl (\ t f (pin t (nom (snip f 0 (#f - 2))) (p + "/" + f))) {} fs))
                  th)
   things (foldl (\ t i (: th (shelf i (dirs i)) (pin t (th 'id) th))) {} (jot n))
   _ (pin things 'hatch (thing 'hatch (w // 2) (h - 2) ">" 220 -1 "the hatch" '((say "a grating in the floor, and the hold below.") (hatch))))
   (level "the library" 1 1 rows {} things))

 ; --- the runner: the story on cli's stage, a key a turn -----------------------------
 (story-run lvl) (: g (story-new lvl)
                    (stage (w \ h \ story-frame g w h) (c \ story-key g c) (\ _ (g 'over))))
 ; the verb: a level file, or the library under a root; the page has its own door (web.l)
 (story-main as) (: p (two? as ? <as "apps/rove/levels/lighthouse.l")
                     lvl (? (two? (readdir p)) (library p) (load-level p))
                     (? lvl (story-run lvl) (say err ("story: not a level: " + p + "\n"), 1)))
 _ (pins (from 'verbs 'tab) 'story story-main))
) ; module story
