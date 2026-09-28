; roost -- the nest as a floor: `love nest` on a terminal. the room is ~/.love/bin: the
; perch in the middle holds the love there, a shelf along the north wall is each tool's
; link, and the door in the south wall is the way out. bumping the perch asks whether to
; lay this build on it, bumping a shelf turns that tool's link on or off, and the door
; asks whether to do it all. the plan is apps/source.l's (nest-plan), edited in place, and
; every line said about it is source.l's too, so the floor and `love nest -n` cannot
; disagree. roost-run answers 'apply or 'cancel.
;
; a floor on rove: laid, not delved, lit end to end; the painter and the signs are rove's.
; roost-new, roost-turn and roost-frame are state in and state out, gated headless by
; test/host/roost.l.
(module (roost roost-run roost-new roost-turn roost-frame roost-face)
; posix is optional -- the page's seat (inle/wasm) links none of it and this file runs
; there, so ask before splicing: an absent module is a scare.
(? (cite 'posix) (borrow 'posix) ())
(borrow 'rove)
(:
 esc (string 27)
 ; --- the room: 0 outside, 1 the floor, 2 a wall, 3 the door, 4 the perch, 5 a shelf ---
 room-w 25                              ; seven shelves three apart, and the walls
 room-h 9
 shelf-gap 3
 wall-glyph "█"
 wall-pen 239
 floor-glyph "·"
 floor-pen 238
 ground 234
 door-glyph "▒"
 door-pen 180
 perch-glyph "♥"
 bare-glyph "○"                         ; the perch with no love on it
 old-pen 245                            ; the love there, kept
 new-pen 213                            ; this build, to be laid
 link-pen 120                           ; a tool that is, or will be, love's
 keep-pen 244                           ; one left as it is
 me-pen 228

 ; --- the words: every line the floor says of its own; the plan's lines are source.l's ---
 w-bar      "the nest   there: ~   this build: ~"
 w-wall     "the wall"
 w-already  "~ is love's already"
 w-same     "the love on the perch is this very build"
 w-lay      "this build will be laid on the perch"
 w-keep     "the perch keeps the love it has"
 open-ttl   "the nest"
 open-foot '(""
             "move     h j k l    or the arrow keys"
             "perch    bump it to lay this build there, or not"
             "shelf    bump one to link that tool to love, or not"
             "door     bump it to do it all, or leave with nothing changed"
             "leave    q          or esc, nothing changed"
             ""
             "-- any key --")
 perch-ttl "the perch"
 door-ttl  "the door"
 ; a choice's line is marked off between the bytes 1 and 2, which fit paints as a button
 (choice-line n s) (string 1 + " " + show n + "  " + s + " " + string 2)
 (src w) (cite 'source w)

 ; --- laying the room: in the middle of the screen, the rest of it outside -----------
 (roost-lay w h n) (:
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms () 'rows h 'cols w 'solid '(0 2 4 5)}
   x0 ((w - room-w) // 2) y0 ((h - room-h) // 2)
   x1 (x0 + room-w - 1) y1 (y0 + room-h - 1)
   _ (each ^room-h (j \ each ^room-w (i \ dput d (x0 + i) (y0 + j)
                                            (? (i = 0 || j = 0 || x0 + i = x1 || y0 + j = y1) 2 1))))
   cx (x0 + room-w // 2)
   _ (dput d cx y1 3)
   _ (dput d cx (y0 + room-h // 2) 4)
   ; the shelves, left to right in the tools' order, along the inside of the north wall
   sx (x0 + (room-w - (n - 1) * shelf-gap) // 2)
   shelves (foldl (\ t k (: x (sx + k * shelf-gap) _ (dput d x (y0 + 1) 5) (pin t x k))) {} ^n)
   (pins d 'shelves shelves 'perch [cx (y0 + room-h // 2)] 'door [cx y1]))
 ; a shelf wears the first letter of its tool that no shelf before it wears
 (shelf-glyphs nms) (:- (go nms "" ()) (go l used acc)
   (? (atom? l) (rev acc)
      (: nm <l
         (pick i) (? (#nm <= i) "?" (elem (nm i) used) (pick (i + 1)) (string (nm i)))
         g (pick 0)
         (go >l (used + g) (g . acc)))))

 ; a fresh floor: the room laid, you just inside the door, the plan's opening said
 (roost-new w h pl) (:
   d (roost-lay w h #(pl 'tools))
   _ (pin d 'glyphs (shelf-glyphs (map (t \ t 'nm) (pl 'tools))))
   dr (d 'door)
   p {'x <dr 'y (<>dr - 1) 'gl 64 'hue me-pen}
   g {'d d 'p p 'pl pl 'ms () 'msg "" 'tn 0 'over 0 'sign () 'ask ()}
   _ (pin g 'sign (open-ttl . ((src 'nest-lines) pl + open-foot)))
   g)

 ; --- the questions: a sign with choices, and the digit that answers it ---------------
 (ask g what ttl ls) (pins g 'ask what 'sign (ttl . ls))
 (ask-perch g) (: pl (g 'pl) when (src 'nest-when)
   (? (pl 'verdict = 'same) (note g w-same)
      (ask g 'perch perch-ttl
           [("there: " + when (pl 'theirs) + ", this build: " + when (pl 'mine))
            ((src 'nest-verdict) pl)
            ""
            (choice-line 1 "lay this build here")
            (choice-line 2 "leave it as it is")])))
 (ask-door g) (ask g 'door door-ttl
                   ((src 'nest-lines) (g 'pl)
                    + [""
                       (choice-line 1 "do it")
                       (choice-line 2 "leave with nothing changed")
                       (choice-line 3 "stay")]))
 (answer g k) (: what (g 'ask) pl (g 'pl)
   done (\ _ (pins g 'ask () 'sign ()))
   (? (what = 'perch)
      (k @ 49 (: _ (pin pl 'lay 'lay) _ (done ()) (note g w-lay))
           50 (: _ (pin pl 'lay 'keep) _ (done ()) (note g w-keep))
           ())
      (what = 'door)
      (k @ 49 (: _ (done ()) (pin g 'over 'apply))
           50 (: _ (done ()) (pin g 'over 'cancel))
           51 (done ())
           ())
      ()))
 ; a shelf bumped: its tool's link on or off. one that is love's already has nothing to do
 (toggle g k) (: t ((g 'pl 'tools) k)
   (? (t 'was = "love") (note g (fill w-already [(t 'nm)]))
      (: _ (pin t 'act (t 'act = 'link ? 'keep 'link))
         (note g ((src 'nest-tool-line) (g 'pl) t)))))

 ; --- a turn: a question takes a digit, a sign any key, else a step --------------------
 (roost-stride g mv) (: p (g 'p) d (g 'd) nx (p 'x + <mv) ny (p 'y + <>mv) t (dat d nx ny)
   (? (t = 4) (ask-perch g)
      (t = 5) (toggle g (d 'shelves nx))
      (t = 3) (ask-door g)
      !(open? d nx ny) (note g w-wall)
      (pins p 'x nx 'y ny)))
 (roost-turn g k) (:
   _ (pins g 'msg "" 'tn (1 + g 'tn))
   _ (? (g 'ask) (answer g k)
        (g 'sign) (pin g 'sign ())
        (g 'over) ()
        (: mv (steer k) (? (two? mv) (roost-stride g mv) ())))
   g)

 ; --- the frame --------------------------------------------------------------------
 (roost-face g) (: d (g 'd) w (d 'w) p (g 'p) pl (g 'pl) at (p 'x + w * p 'y)
   (perch _) (? (pl 'lay = 'lay) [perch-glyph [new-pen ground]]
                (pl 'verdict = 'fresh) [bare-glyph [keep-pen ground]]
                [perch-glyph [old-pen ground]])
   (shelf x) (: k (d 'shelves x) t ((pl 'tools) k)
                [((d 'glyphs) k)
                 [(? (t 'act = 'link || t 'was = "love") link-pen keep-pen) ground]])
   (\ i (: x (i % w) t (peep (d 't) i 0)
           (? (i = at) ["@" [(legible me-pen ground) ground]]
              (t @ 1 [floor-glyph [floor-pen ground]]
                   2 [wall-glyph wall-pen]
                   3 [door-glyph door-pen]
                   4 (perch ())
                   5 (shelf x)
                   '(32 0))))))
 (roost-bar g) (: when (src 'nest-when) (fill w-bar [(when (g 'pl 'theirs)) (when (g 'pl 'mine))]))
 (roost-frame g) (: d (g 'd) rows (d 'rows) cols (d 'cols)
   f (:- (slurp j) j (paint (jug 0) d (roost-face g) (g 'msg) (roost-bar g)))
   sg (g 'sign)
   _ (pin d 'box (two? sg ? (sign-rect <sg >sg 1 rows cols) ()))
   (two? sg ? (sign-over f <sg >sg 1 rows cols) f))

 ; --- the walk: the screen raised, a key a turn, the answer handed back ---------------
 (roost-walk pl) (: ws (tty 1)
   r (two? ws && 7 < <ws ? (<ws - 2) 22)
   c (two? ws && 19 < <>ws ? <>ws 80)
   g (roost-new c r pl)
   (turn k) (? (g 'ask) (? (k = 27) (pins g 'ask () 'sign ()) (roost-turn g k))
               (k = 27 && g 'sign) (pin g 'sign ())
               (k @ (113 || 27 || -7) (pin g 'over 'cancel)
                (roost-turn g k)))
   (loop last t0) (? (g 'over) ()
                     (: _ (say out (roost-frame g), flush out)
                        k (key-wait t0 last (g 'sign ? sign-gap repeat-gap) (\ _ (rest 30)))
                        _ (turn k)
                        (loop k (clock 0))))
   _ (say out (esc + "[2J"))
   _ (loop 0 0)
   (g 'over))
 (roost-run pl) (: _ (raw 1)
   _ (say out (esc + "[?1049h" + esc + "[?25l"))
   r (roost-walk pl)
   _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"), flush out)
   _ (drain-keys ())
   _ (raw 0)
   r))
) ; module roost
