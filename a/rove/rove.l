; rove -- quay's roguelike engine: the parts any game on the console rides.
;
; a floor is tiles in a cask carved by delve, with a seen cask for what the player has
; been shown; fov is line-of-sight over bresenham strides; the painter says a frame of
; painted cells into any port, each cell's face the game's own function, so frames gate
; headless; the helm turns a key into a steer; the sign is a box over the frame; the
; words machine fills a line's ~ and {braces}; and the keys are paced, so a key held
; down is not a key pressed again. the tower (a/rove/tower.l) and the slop
; (a/rove/slop.l) borrow it; it gates headless in t/host/rove.l.
(module (rove cell-of cells-cut cells-from clear? dat deal delve dice dput drain-keys due?
         fill first-n fit fit-in fov hole key-drain key-wait lead lim lit? mix mob-at note
         nth-on open-book open? pad page-foot paint paint-live pen pens repeat-gap roll
         settle settle-slice sign-box sign-flow sign-gap sign-line sign-over sign-pen
         sign-rect sign-top sign-tpen snip-l steer tail? tap-steer toward vlen)
; posix is optional -- the page's seat (i/wasm) links none of it and this file runs
; there, so ask before splicing: an absent module is a scare.
(? (cite 'posix) (borrow 'posix) ())
(borrow 'x11)
(:
 ; the computed pens first: a value bound below the lambdas that read it is missing at
 ; the bake, where a literal would fold
 choice-fg (x11-256 "honeydew")                         ; a choice's button: text on ground
 choice-bg (x11-256 "darkslategray")
 ; 4 a building's floor, 5 a door, 6 glass -- looked through and never entered: a road's
 ; end off the map, heaven's void -- 7 a step and 8 a platform; the vale's 9 dirt, 10 the
 ; bare spot, 11 timber -- the cottage seen from outside, a wall -- 12 garden, 13 a stair down
 (dat d x y) (0 <= x < d 'w && 0 <= y < d 'h ? (peep (d 't) (x + (d 'w) * y) 0) 0)
 (open? d x y) (: t (dat d x y) (0 < t && t != 6 && t != 11 && t != 12))   ; walked: the cottage and its bed are not
 (lit? d x y) (0 < dat d x y)                           ; looked through
 (dput d x y v) (pin (d 't) (x + (d 'w) * y) v)

 ; a spun rng: the functional state in a box, one draw steps it
 (roll sb n) (: p (random (peep sb () 0) n) (pin sb () >p, <p))

 ; --- delve: carve rooms, lash them with corridors ---
 ; a room is [x y rw rh]; its center anchors the corridors. rooms keep a
 ; one-cell gap so no two merge; each new room tunnels to the previous one,
 ; so the whole floor is connected by construction. answers (floor . st').
 ; the plan is the tier's own -- wide from, wide by, tall from, tall by, and one
 ; try per so many cells -- which is what makes the garden a patch of small beds
 ; and heaven a few long blocks.
 (delve w h st pl) (:
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms ()}
   sb {st}
   (mid rm) [(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)]
   (carve x0 y0 rw rh) (: (row y x) (x < x0 + rw ? (dput d x y 1, row y (x + 1)))
                          (rows y) (y < y0 + rh ? (row y x0, rows (y + 1)))
                          (rows y0))
   (hallx y xa xb) (carve (xa < xb ? xa xb) y (1 + |(xb - xa)) 1)
   (hally x ya yb) (carve x (ya < yb ? ya yb) 1 (1 + |(yb - ya)))
   (lash [ax ay] [bx by])
    (roll sb 2 ? (hallx ay ax bx, hally bx ay by)
                 (hally ax ay by, hallx by ax bx))
   (apart? rm) (all (o \ 1 + peep rm 0 0 + peep rm 2 1 <= peep o 0 0 ||
                         1 + peep o 0 0 + peep o 2 1 <= peep rm 0 0 ||
                         1 + peep rm 1 0 + peep rm 3 1 <= peep o 1 0 ||
                         1 + peep o 1 0 + peep o 3 1 <= peep rm 1 0))
   (try n) (? (0 < n)
            (: rw ((pl 0) + roll sb (pl 1)) rh ((pl 2) + roll sb (pl 3))
               (? (w <= rw + 2 || h <= rh + 2) (try (n - 1))
                ; the span a room of width rw can start at, keeping a 1-cell border: x is
                ; 1 + roll(w - rw - 1), so the far edge lands at w-2 at worst. (this read `+ 1`
                ; while the additive band folded right and w - (rw + 1) is the same number --
                ; the hand made the arithmetic say what it means.)
                (: x (1 + roll sb (w - rw - 1)) y (1 + roll sb (h - rh - 1))
                   rm [x y rw rh]
                 (? !(apart? rm (d 'rooms)) (try (n - 1))
                  (carve x y rw rh,
                   d 'rooms ? (lash (mid rm) (mid <(d 'rooms))),
                   pin d 'rooms (rm . d 'rooms),
                   try (n - 1)))))))
   _ (try ((w * h) // (pl 4)))
   ; a cramped floor can come up short: guarantee two joined rooms
   _ (#(d 'rooms) < 2 ?
      (: r1 '(1 1 3 3) r2 [(w - 4) (h - 4) 3 3]
         (carve 1 1 3 3, carve (w - 4) (h - 4) 3 3,
          lash (mid r1) (mid r2), pin d 'rooms [r2 r1])))
   _ (pins d 'in (mid (last (d 'rooms)))
             'stair (mid <(d 'rooms)))
   _ (dput d <(d 'stair) <>(d 'stair) 2)
   ; ..and a second stair in another room, where the floor has one to spare
   _ (? (2 < #(d 'rooms)) (: s2 (mid ((d 'rooms) 1)) (dput d <s2 <>s2 2)))
   (d . peep sb () 0))

 ; a list dealt out in a random order, and the first n of one
 (deal sb l) (:- (go l ())
   (go l acc) (two? l ? (: k (roll sb #l) (go (cat (snip-l l 0 k) (nth-on l (k + 1))) ((l k) . acc))) acc))
 (snip-l l a b) (a >= b ? () ((l a) . snip-l l (a + 1) b))
 (nth-on l k) (k <= 0 ? l (nth-on >l (k - 1)))
 (first-n n l) (0 < n && two? l ? (<l . first-n (n - 1) >l) ())

 ; --- the lantern: line-of-sight fov over bresenham strides ---
 ; a stride is clear when every cell strictly between the ends is looked through; the
 ; endpoint itself may be rock -- that is how a wall catches the light.
 (clear? d x0 y0 x1 y1) (:
   dx |(x1 - x0) dy (0 - |(y1 - y0))
   sx (? (x0 < x1) 1 -1) sy (? (y0 < y1) 1 -1)
   (go x y e) (? (x = x1 && y = y1) 1
               (: e2 (2 * e)
                  mx (dy <= e2) my (e2 <= dx)
                  nx (? mx (x + sx) x) ny (? my (y + sy) y)
                  ne (e + (mx ? dy) + (my ? dx))
                  (? (nx = x1 && ny = y1) 1
                     (lit? d nx ny) (go nx ny ne)
                     0)))
   (go x0 y0 (dx + dy)))

 ; the visible set: a tablet of cell indices, radius-bounded and stride-clear;
 ; each visible cell is also pinned into the floor's seen cask (the memory).
 ; a closing pass glows the rock beside every lit floor cell, so corridors
 ; wear their walls (a bare stride only catches rock end-on)
 (fov d px py r) (:
   vis {} w (d 'w) h (d 'h) sn (d 'seen) r2 (1 + r * r)
   (glow x y) (: i (x + w * y) (pin vis i 1, pin sn i 1, ()))
   (cell x y) (2 (x - px) + 2 (y - py) <= r2 && clear? d px py x y ? (glow x y))
   (row y x) (x <= px + r ? (cell x y, row y (x + 1)))
   (rows y) (y <= py + r ? (row y (px - r), rows (y + 1)))
   _ (rows (py - r))
   _ (flip map (keys vis) (i \ 0 < peep (d 't) i 0 ?
      (: x (i % w) y (i // w)
       (map (\ o (: nx (x + <o) ny (y + <>o)
                  (0 <= nx < w && 0 <= ny < h && dat d nx ny = 0 ? (glow nx ny))))
            '((-1 -1) (0 -1) (1 -1) (-1 0)
              (1 0) (-1 1) (0 1) (1 1))))))
   vis)

 ; --- the painter: one frame said into a port as painted cells ---
 ; a cell's face is the game's: cell takes a cell's index and answers (glyph hue).
 ; one SGR per hue change, threaded down the frame; the port is any jug, so frames
 ; gate headless.
 pens {}
 (pen n) (: s (pens n) (string? s ? s
          (: s2 ("\e[38;5;" + show n + "m") (pin pens n s2, s2))))
 ; two multiply-shift rounds masked to 32 bits: the dice a cell throws for itself,
 ; so the same cell of the same floor always throws the same number.
 lim 4294967296
 (mix a) (: h ((a * 2654435761) % lim)
            h2 ((h ^ (h >> 15)) * 2246822519 % lim)
            (h2 ^ (h2 >> 13)))
 (dice x y s k) ((mix (y * 374761393 + x * 668265263 + s * 2654435761 + 1)) % k)
 ; a piece with a book opens it a page at a time: every page is a sign under the book's
 ; title, and the key that takes one down puts the next up. the foot is read here and
 ; not in the words below: a lambda reads a value bound above it, never one below
 page-foot "-- ~ of ~, any key --"
 (open-book g bk) (: n #>bk
                      (page i) (<bk . ((>bk i) + ["" (fill page-foot [(i + 1) n])]))
                      pgs (map page ^n)
                      (pins g 'sign <pgs 'pages >pgs))
 (paint j d cell msg bar) (:
   w (d 'w) h (d 'h)
   ; the screen's rows of a floor taller than it: from the view's top, and a row past
   ; the floor's foot is blank. a floor smaller than the screen sits in the middle of
   ; it, padded left and the rows above and below it blank
   rows-n (peep d 'rows h) vy (peep d 'vy 0)
   padding (peep d 'vx 0 (t \ t + " ") "")
   ; the note row through `fit`: a message may carry the token's braces, and an
   ; escape is no width, so the cut is made in what a reader sees. a long one wraps
   ; onto a second row, which covers the floor's first: the floor does not move.
   ; d 'top is the rows it took, for the live painter to keep under
   cols (peep d 'cols w)
   wr (cite 'story 'wrap)
   notes (: ls (wr && cols < vlen msg ? (wr msg cols) [msg]) (two? >ls ? [<ls (ls 1)] ls))
   _ (pin d 'top #notes)
   _ (say j "\e[H")
   _ (each notes (l \ say j ("\e[0m" + fit l cols + "\e[K\r\n")))
   (row y x i p) (x >= w ? p
                  (: gh (cell i)
                     p2 <>gh
                   (p != p2 ? (say j (pen p2)),
                    say j (string <gh),
                    row y (x + 1) (i + 1) p2)))
   ; every row ends on \e[K: a floor narrower than the screen leaves nothing of the
   ; last floor past its edge
   (rows y p) (y >= vy + rows-n ? p
               (rows (y + 1) (: p2 (y < 0 || y >= h ? p
                                    (say j padding, row y 0 (w * y) p))
                                _ (say j "\e[K\r\n")
                                p2)))
   ; ..and the bar a column short of the screen: a console that wraps at its edge would
   ; scroll the floor for a bar that reached it
   (rows (vy + #notes - 1) -1,
    say j "\e[0m", say j (fit bar (cols - 1)), say j "\e[K",
    j))
 ; some cells alone, each under a cursor move, as the last frame laid the floor: a
 ; cell off the screen, under the note, unlit or under a sign's box is left be
 (paint-live j d vis cell cells) (:
   w (d 'w) h (d 'h) rows (peep d 'rows h) vy (peep d 'vy 0) vx (peep d 'vx 0)
   top (peep d 'top 1) box (peep d 'box ())
   lit-all? (peep d 'lit 0)
   (boxed? sx sy) (box && (box 0 <= sx < box 0 + box 2) && (box 1 <= sy < box 1 + box 3))
   (one i) (: x (i % w) y (i // w) sx (x + vx) sy (y - vy + 1)
              (? (top <= sy < rows + 1 && (lit-all? || peep vis i 0) && !(boxed? sx sy))
                 (: gh (cell i)
                    (say j ("\e[" + show (sy + 1) + ";" + show (sx + 1) + "H" + pen <>gh + string <gh)))))
   _ (each cells one)
   (say j "\e[0m", j))

 ; --- the helm: a key (cli's edkey: a byte, an arrow code, an alt letter) -> one steer,
 ; a move pair; any other key answers as itself ---
 (steer k)
  (k @ (104 || -1) '(-1 0)  (106 || -9) '(0 1)  (107 || -8) '(0 -1)  (108 || -2) '(1 0)
       (121 || 377) '(-1 -1) (117 || 373) '(1 -1) (98 || 354) '(-1 1) (110 || 366) '(1 1)
       k)

 ; ..and a tap is a place rather than a letter: one step of the eight toward the cell it
 ; landed on -- the nearest of the eight as the screen shows them, a cell being twice
 ; as tall as it is wide, so a tap a little off a row is still along it -- and a tap on
 ; the cell you stand on is the stair; standing on one, so are the eight about it, a
 ; finger being wider than a cell. the note row is the screen's first, so a screen y
 ; is a floor y and one. c is [x y], cli's edtap.
 (toward a b) (a < b ? 1 (a > b ? -1 0))
 (tap-steer g c) (: p (g 'p) d (g 'd)
                    ex (<c - peep d 'vx 0 - (p 'x))
                    ey (<>c - 1 + peep d 'vy 0 - (p 'y))
                    ax (abs ex) ay (2 * abs ey)          ; in cell widths
                    ; within 22.5 degrees of a row or a column is along it: tan is 5/12
                    dx (12 * ax < 5 * ay ? 0 (toward 0 ex))
                    dy (12 * ay < 5 * ax ? 0 (toward 0 ey))
                    (? (dx = 0 && dy = 0) 60
                       (ax <= 1 && ay <= 2 && 2 = dat d (p 'x) (p 'y)) 60
                       [dx dy]))

 ; a line and its holes: each ~ takes the next value, a string as itself and anything
 ; else as show, so a table line reads as the line it prints.
 (hole v) (string? v ? v (show v))
 (fill s vs) (:- (go 0 "" vs) (go i acc vs)
              (i >= #s ? acc
               (: c (s i)
                (c = 126 && two? vs ? (go (i + 1) (acc + hole <vs) >vs)
                 (go (i + 1) (acc + string c) vs)))))
 ; a cell is a character and not a byte: the face's blocks and arrows are three bytes
 ; each, and only the first of them is a cell -- the tails ride along with it
 (tail? c) (128 <= c < 192)
 (lead c) (tail? c ? 0 1)
 ; ..and its braces, put on at the port, and a choice between the bytes 1 and 2 on its
 ; own ground. an escape is no width, so this is also where a line is cut to fit: the
 ; row's span is what a reader sees, not what a cask holds. off is what comes back
 ; after either, the pen the line was in
 token-pen 201                                          ; the pen a {braced} word is named in
 (fit-in s w off) (: on ("\e[38;5;" + show token-pen + "m")
                     on2 ("\e[48;5;" + show choice-bg + ";38;5;" + show choice-fg + "m")
              (go i n acc)
               (? (i >= #s) acc
                  (: c (s i)
                     (? (n >= w && !(tail? c)) acc
                        (c = 123) (go (i + 1) n (acc + on))
                        (c = 1) (go (i + 1) n (acc + on2))
                        (c = 125 || c = 2) (go (i + 1) n (acc + off))
                        (go (i + 1) (n + lead c) (acc + string c)))))
              (go 0 0 ""))
 (fit s w) (fit-in s w "\e[0m")

 ; --- the sign: a box over the frame, story's lighthouse way. braces cost no width, so
 ; it is measured in what a reader sees, and it runs to the row's end so no pen meets.
 sign-pen (x11-256 "lavender")                          ; the frame, and the title in its own
 sign-tpen (x11-256 "honeydew")
 (vlen s) (:- (go 0 0) (go i n) (i >= #s ? n
           (s i @ c (go (i + 1) (c @ (123 || 125 || 1 || 2) n (n + lead c))))))
 (pad s n c) (: v (vlen s) (v >= n ? s (s + ((n - v) (\ t (t + c)) ""))))
 (sign-box ttl ls) (:
   w (foldl (\ a l (vlen l @ v (a < v ? v a))) (vlen ttl) ls)
   ww (w + 4)
   top ("+-" + pad (ttl + " ") (ww - 3) "-" + "+")
   bot ("+" + ((ww - 2) (t \ t + "-") "") + "+")
   ([top] + (map (l \ "| " + pad l (ww - 4) " " + " |") ls) + [bot]))
 ; the first n cells of a painted row: an SGR has no width, so the count is of glyphs,
 ; and a glyph's tail bytes belong to the cell its lead began -- k is the leads so far.
 ; a painted row ends on \e[K, an escape with no m, so the skip stops at the end too
 (cell-of c k) (tail? c ? (k - 1) k)
 ; ..and a row shorter than n cells -- a blank one beside a small room -- is padded
 ; out to n, so what is laid after it lands where it was measured to
 (cells-cut r n) (:- (go 0 0 "")
                  (past i) (i >= #r ? i (r i @ 109 (i + 1) (past (i + 1))))
                  (go i k acc)
                   (i >= #r ? (acc + ((n - k) (t \ t + " ") ""))
                    (: c (r i)
                       (? (n <= cell-of c k) acc
                          (c = 27) (past i @ e (go e k (acc + snip r i e)))
                          (go (i + 1) (k + lead c) (acc + string c))))))
 ; ..and the other side of the same cut: the cells from n on. EVERY escape is kept, from
 ; the row's start and not from n, because a colour is a state and the one in force at
 ; cell n was set somewhere to its left -- drop those and the tail wears whatever the
 ; caller happened to leave on.
 (cells-from r n) (:- (go 0 0 "")
                   (past i) (i >= #r ? i (r i @ 109 (i + 1) (past (i + 1))))
                   (go i k acc)
                    (i >= #r ? acc
                     (r i @ 27 (past i @ e (go e k (acc + snip r i e)))
                       c (go (i + 1) (k + lead c) (n <= cell-of c k ? (acc + string c) acc)))))
 ; a line wider than the screen is reflowed at its words -- story's own wrap -- to a
 ; few cells short of the edge either side, so no row runs full and a word never sits
 ; against the frame. one list of rows per line
 (sign-flow ls w) (: wr (cite 'story 'wrap)
                     (map (l \ (wr && (w - 10) < vlen l ? (wr l (w - 10)) [l])) ls))
 ; the screen row the box's top takes, for a box of nb rows
 (sign-top a n nb) (: q (a + (n - nb) // 2) (a < q ? q a))
 ; the line under screen row y, as an index into ls, or -1 off the box and its frame
 (sign-line ttl ls a n w y) (:- (go (y - sign-top a n (2 + net (map tally fl)) - 1) 0 fl)
   fl (sign-flow ls w)
   (go j i l) (? (j < 0 || one? l) -1
                 (j < #<l) i
                 (go (j - #<l) (i + 1) >l)))
 ; where the box lands on the screen: [x0 y0 w rows], as sign-over lays it
 (sign-rect ttl ls a n w) (: box (sign-box ttl (foldl (+) () (sign-flow ls w)))
                             ww (vlen <box)
                             [(: q ((w - ww) // 2) (0 < q ? q 0)) (sign-top a n #box) ww #box])
 ; a frame with the box centred over its rows a .. a+n, for a screen w wide; the box
 ; takes the rows the reflow makes
 (sign-over f ttl ls a n w) (:- (go 0 "")
   rs (split "\r\n" f)
   box (sign-box ttl (foldl (+) () (sign-flow ls w)))
   ww (vlen <box)
   x0 (: q ((w - ww) // 2) (0 < q ? q 0))
   y0 (sign-top a n #box)
   ; ..and never past the rows it was given: a box too tall for the screen loses its
   ; foot, which is the screen's doing, but the bar under it is not the box's to take
   (lay i) (rs i @ r
            (!(y0 <= i < y0 + #box && i < a + n) ? r
             ; the field either side of the box, and the box between them. the tail is
             ; not decoration: a row that stops at the box leaves the cells past it
             ; holding whatever the LAST frame put there, and the floor before this one
             ; is where that comes from.
             (cells-cut r x0 + "\e[0m" + pen sign-pen + fit-in (row i) 400 ("\e[0m" + pen sign-pen)
              + "\e[0m" + cells-from r (x0 + ww))))
   ; the top row's tab, +-title, wears its own pen; the cells were counted before the pens went in
   (row i) (: s (box (i - y0))
              (i = y0 && 0 < #ttl ? (pen sign-tpen + snip s 0 (3 + #ttl) + pen sign-pen + snip s (3 + #ttl) #s) s))
   (go i acc) (i >= #rs ? acc (go (i + 1) (acc + (0 < i ? "\r\n" "") + lay i))))

 ; --- the keys: what a held key means, for any game on the stage ---------------------
 ; a key held down is not a key pressed again: the same key within a short gap of the
 ; last one taken is dropped, and a longer gap while a sign stands, so a held key cannot
 ; run through a scene's pages or a valley. a different key passes at once
 repeat-gap 120                                         ; ms a held key's repeats are dropped for
 sign-gap 600                                           ; ..and while a sign stands
 ; the blocking shape: wait for a key, running idle between polls -- last is the key
 ; the last turn took and t0 when; answers the key to turn on
 (key-wait t0 last gap idle) (? (cue? 0)
                                (: k (edkey in)
                                   (k = last && (clock 0 - t0) < gap ? (key-wait t0 last gap idle) k))
                                (idle (), key-wait t0 last gap idle))
 ; the polling shape: every key waiting handed to take under the same rule, the last
 ; key taken and its time riding g as 'lk and 'lt; answers how many were taken
 (key-drain g gap take)
  (:- (go 0) (go n)
   (? (cue? 0)
      (: k (edkey in)
         (? (k = g 'lk && (clock 0 - g 'lt) < gap) (go n)
            (take k, pins g 'lk k 'lt (clock 0), go (n + 1))))
      n))
 ; the queue eaten: keys typed at what stood before are not typed at what stands now
 (drain-keys _) (cue? 0 ? (see in, drain-keys ()))
 ; ..and for a while: a box that goes up over what the keys were typed at
 settle-slice 25
 (settle ms) (? (0 < ms) (drain-keys (), rest settle-slice, settle (ms - settle-slice)))

 (note g s) (pin g 'msg (g 'msg ? (g 'msg + "; " + s) s))
 (mob-at g x y) <(filter (m \ x = m 'x && y = m 'y) (g 'ms))
 ; a mob stirs on the turns its pace divides, so heaven moves at half a climber's rate
 (due? g m) (: q ((g 'tn) % (m 'pc)) (0 = q)))
) ; module rove
