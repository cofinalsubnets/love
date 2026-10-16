; rove -- lore's roguelike engine: the parts any game on the console rides. a floor is tiles
; in a cask carved by delve, with a seen cask for what the player has been shown; fov is
; line of sight; the painter says a frame into any port, each cell's face the game's own, so
; frames run headless; then the helm, the sign box, the ~ and {brace} words, paced keys, and
; the horn's lead paced by the frame gap.
(module (rove cell-of cells-cut cells-from clear? dat deal delve dice dput drain-keys due?
         fill first-n fit fit-in fov hole key-drain key-wait lead legible legible-gap legible-lum lim lit? mix mob-at note
         nth-on open-book open? pace! pacer pad page-foot paint paint-live pen pen-gap pen-lum pen-rgb pens repeat-gap rgb-pen roll
         settle settle-slice sign-box sign-flow sign-gap sign-line sign-over sign-pen
         sign-rect sign-top sign-tpen snip-l song-fill song-lead song-lead-max song-lead-of song-rate steer
         tail? tap-dir tap-key tap-steer rove-key rove-modes toward vlen rove-wander rove-turn rove-press rove-loop)
(borrow 'posix)
(borrow 'x11)
(borrow 'text)
(:
 ; the computed pens first: a value bound below the lambdas that read it is missing at
 ; the bake, where a literal would fold
 choice-fg (x11-256 "honeydew")                         ; a choice's button: text on ground
 choice-bg (x11-256 "darkslategray")
 ; tiles past the engine's: 4 a building's floor, 5 a door, 6 glass (looked through, never
 ; entered), 7 a step, 8 a platform, 9 dirt, 10 a bare spot, 11 timber, 12 garden, 13 a stair down
 (dat d x y) (0 <= x < d 'w && 0 <= y < d 'h ? (peep (d 't) (x + d 'w * y) 0) 0)
 ; walked: anything laid but the tiles this floor names in 'solid; the engine itself lays only 1 and 2
 (open? d x y) (dat d x y @ t (0 < t && nelem t (d 'solid)))
 (lit? d x y) (0 < dat d x y)                           ; looked through
 (dput d x y v) (pin (d 't) (x + d 'w * y) v)

 ; a spun rng: the functional state in a box, one draw steps it
 (roll sb n) (random (peep sb () 0) n @ p (pin sb () >p, <p))

 ; --- delve: carve rooms, lash them with corridors ---
 ; a room is [x y rw rh], its center anchoring the corridors; rooms keep a one-cell gap and
 ; each tunnels to the previous one, so the floor is connected. pl, the tier's plan: wide
 ; from, wide by, tall from, tall by, one try per so many cells. answers (floor . st')
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
   (try n) (0 < n ?
            (: rw (pl 0 + roll sb (pl 1)) rh (pl 2 + roll sb (pl 3))
               (w <= rw + 2 || h <= rh + 2 ? (try (n - 1))
                ; ..x is 1 + roll (w - rw - 1), keeping a one-cell border
                (: x (1 + roll sb (w - rw - 1)) y (1 + roll sb (h - rh - 1))
                   rm [x y rw rh]
                 (? !(apart? rm (d 'rooms)) (try (n - 1))
                  (carve x y rw rh,
                   d 'rooms ? (lash (mid rm) (mid <(d 'rooms))),
                   pin d 'rooms (rm . d 'rooms),
                   try (n - 1)))))))
   (try (w * h // pl 4),
   ; a cramped floor can come up short: guarantee two joined rooms
    (#(d 'rooms) < 2 ?
     (: r1 '(1 1 3 3) r2 [(w - 4) (h - 4) 3 3]
        (carve 1 1 3 3, carve (w - 4) (h - 4) 3 3,
         lash (mid r1) (mid r2), pin d 'rooms [r2 r1]))),
    (pins d 'in (mid (last (d 'rooms)))
            'stair (mid <(d 'rooms))),
    dput d <(d 'stair) <>(d 'stair) 2,
   ; ..and a second stair in another room, where the floor has one to spare
    (? (2 < #(d 'rooms)) (mid (d 'rooms 1) @ s2 (dput d <s2 <>s2 2))),
    d . peep sb () 0))

 ; a list dealt out in a random order, and the first n of one
 (deal sb l) (:- (go l ())
   (go l acc) (two? l ? (roll sb #l @ k (go (cat (snip-l l 0 k) (nth-on l (k + 1))) (l k . acc))) acc))
 (snip-l l a b) (a < b ? (l a . snip-l l (a + 1) b))
 (nth-on l k) (k <= 0 ? l (nth-on >l (k - 1)))
 (first-n n l) (0 < n && two? l ? (<l . first-n (n - 1) >l))

 ; --- the lantern: line-of-sight fov over bresenham strides ---
 ; a stride is clear when every cell strictly between the ends is looked through; the end
 ; may be rock, so a wall catches the light
 (clear? d x0 y0 x1 y1) (:
   dx |(x1 - x0) dy -|(y1 - y0)
   sx (x0 < x1 ? 1 -1) sy (y0 < y1 ? 1 -1)
   (go x y e) (x = x1 && y = y1 ? 1
               (: e2 (2 * e)
                  mx (dy <= e2) my (e2 <= dx)
                  nx (mx ? (x + sx) x) ny (my ? (y + sy) y)
                  ne (e + (mx ? dy) + (my ? dx))
                  (? (nx = x1 && ny = y1) 1
                     (lit? d nx ny) (go nx ny ne)
                     0)))
   (go x0 y0 (dx + dy)))

 ; the visible set: a tablet of cell indices, radius-bounded and stride-clear, each pinned in
 ; the seen cask too; a closing pass glows the rock beside every lit floor cell
 (fov d px py r) (:
   vis {} w (d 'w) h (d 'h) sn (d 'seen) r2 (1 + r * r)
   (glow x y) (x + w * y @ i (pin vis i 1, pin sn i 1, ()))
   (cell x y) (2 (x - px) + 2 (y - py) <= r2 && clear? d px py x y ? (glow x y))
   (row y x) (x <= px + r ? (cell x y, row y (x + 1)))
   (rows y) (y <= py + r ? (row y (px - r), rows (y + 1)))
   (rows (py - r),
    flip map (keys vis) (i \ 0 < peep (d 't) i 0 ?
    (: x (i % w) y (i // w)
     (map (o \ (: nx (x + <o) ny (y + <>o)
                (0 <= nx < w && 0 <= ny < h && dat d nx ny = 0 ? (glow nx ny))))
          '((-1 -1) (0 -1) (1 -1) (-1 0)
            (1 0) (-1 1) (0 1) (1 1))))),
    vis))

 ; --- the painter: one frame said into a port as painted cells. cell answers (glyph hue) for
 ; an index, the hue a pen or (fg bg); one SGR per hue change, a ground put off after its glyph ---
 pens {}
 (pen n) (two? n ? ("\e[38;5;" + show <n + ";48;5;" + show <>n + "m")
          (pens n @ s (string? s ? s
           ("\e[38;5;" + show n + "m" @ s2 (pin pens n s2, s2)))))
 ; a pen's rgb and the pen nearest an rgb, over the cube and the grey ramp both
 levels [0 95 135 175 215 255]
 (pen-rgb c) (? (232 <= c) (8 + 10 * (c - 232) @ v [v v v])
                (16 <= c) (c - 16 @ i [(levels (i // 36)) (levels (i // 6 % 6)) (levels (i % 6))])
                [0 0 0])
 (cube v) (v < 48 ? 0 ((v - 35) // 40))                 ; x11's rule: a channel to its nearest level
 (rgb-pen r g b) (: cb (16 + 36 * cube r + 6 * cube g + cube b)
                    n (((r + g + b) // 3 - 3) // 10)
                    gy (232 + (? (n < 0) 0 (23 < n) 23 n))
                    (dist p) (pen-rgb p @ q (2 (q 0 - r) + 2 (q 1 - g) + 2 (q 2 - b)))
                    (dist gy < dist cb ? gy cb))
 ; how far apart two pens are, in rgb squared and in luminance; and a fg that reads over a bg:
 ; itself if far enough both ways, else its inverse, else black or white
 (pen-gap a b) (: p (pen-rgb a) q (pen-rgb b) (2 (p 0 - q 0) + 2 (p 1 - q 1) + 2 (p 2 - q 2)))
 (pen-lum c) (pen-rgb c @ q (int (0.2126 * q 0 + 0.7152 * q 1 + 0.0722 * q 2)))
 legible-gap 14400                                       ; a hundred and twenty of rgb, squared
 legible-lum 80                                          ; ..and this much of luminance, of 255
 (legible fg bg) (: (far? a) (legible-gap <= pen-gap a bg && legible-lum <= |(pen-lum a - pen-lum bg))
                    q (pen-rgb fg) inv (rgb-pen (255 - q 0) (255 - q 1) (255 - q 2))
                    (? (far? fg) fg (far? inv) inv (128 <= pen-lum bg) 16 231))
 ; the dice a cell throws for itself: the same cell of the same floor throws the same number
 lim 4294967296
 (mix a) (: h (a * 2654435761 % lim)
            h2 ((h ^ h >> 15) * 2246822519 % lim)
            (h2 ^ h2 >> 13))
 (dice x y s k) (mix (y * 374761393 + x * 668265263 + s * 2654435761 + 1) % k)
 ; a book opens a page at a time, each a sign under its title, the key that takes one down
 ; putting the next up. page-foot is bound here: a lambda reads a value bound above it, not below
 page-foot "-- ~ of ~, any key --"
 (open-book g bk) (: n #>bk
                      (page i) (<bk . (>bk i + ["" (fill page-foot [(i + 1) n])]))
                      pgs (map page ^n)
                      (pins g 'sign <pgs 'pages >pgs))
 (paint j d cell msg bar) (:
   w (d 'w) h (d 'h)
   ; the screen's rows of a floor taller than it from 'vy, past its foot blank; a smaller floor
   ; sits padded in the middle
   rows-n (peep d 'rows h) vy (peep d 'vy 0)
   vx (peep d 'vx 0) padding (vx (t \ t + " ") "")
   ; the note row through fit, cut in what a reader sees; a long one wraps to three rows over
   ; the floor, which does not move. d 'top is the rows it took, for paint-live
   cols (peep d 'cols w)
   wr (cite 'story 'wrap)
   notes ((wr && cols < vlen msg ? (wr msg cols) [msg]) @ ls (first-n 3 ls))
   _ (pin d 'top #notes)
   _ (say j "\e[H")
   ; an erase under a pending wrap takes the glyph that raised it, so a full row is not cleared
   (end n) (n < cols ? "\e[K\r\n" "\r\n")
   _ (each notes (l \ say j ("\e[0m" + fit l cols + end (vlen l))))
   (row y x i p) (x >= w ? p
                  (: gh (cell i)
                     p2 <>gh
                   (p != p2 ? (say j (pen p2)),
                    say j (string <gh),
                    ; a ground goes no further than its glyph, and the next pen is said whole
                    two? p2 ? (say j "\e[49m"),
                    row y (x + 1) (i + 1) (two? p2 ? -1 p2))))
   ; a short row ends on \e[K, so nothing of the last floor shows past its edge
   (rows y p) (y >= vy + rows-n ? p
               (rows (y + 1) (: on (0 <= y < h)
                                p2 (on ? (say j padding, row y 0 (w * y) p) p)
                                (say j (end (on ? (vx + w) 0)),
                                 p2))))
   ; ..and the bar a column short of the screen, so a console that wraps does not scroll
   (rows (vy + #notes - 1) -1,
    say j "\e[0m", say j (fit bar (cols - 1)), say j "\e[K",
    j))
 ; some cells alone, each under a cursor move: one off the screen, under the note, unlit or
 ; under a sign's box is left be
 (paint-live j d vis cell cells) (:
   w (d 'w) h (d 'h) rows (peep d 'rows h) vy (peep d 'vy 0) vx (peep d 'vx 0)
   top (peep d 'top 1) box (d 'box)
   lit-all? (peep d 'lit 0)
   (boxed? sx sy) (box && box 0 <= sx < box 0 + box 2 && box 1 <= sy < box 1 + box 3)
   (one i) (: x (i % w) y (i // w) sx (x + vx) sy (y - vy + 1)
              (? (top <= sy < rows + 1 && (lit-all? || peep vis i 0) && !(boxed? sx sy))
                 (cell i @ gh
                    (say j ("\e[" + show (sy + 1) + ";" + show (sx + 1) + "H" + pen <>gh + string <gh
                            + (two? <>gh ? "\e[49m" ""))))))
   (each cells one,
    (say j "\e[0m", j)))

 ; --- the helm: a key (cli's edkey: a byte, an arrow code, an alt letter) -> one steer,
 ; a move pair; any other key answers as itself ---
 (steer k)
  (k @ (104 || -1) '(-1 0)  (106 || -9) '(0 1)  (107 || -8) '(0 -1)  (108 || -2) '(1 0)
       (121 || 377) '(-1 -1) (117 || 373) '(1 -1) (98 || 354) '(-1 1) (110 || 366) '(1 1)
       k)

 ; ..and a tap is a place: the step of the eight toward a cell ex across, ey down; a cell is
 ; twice as tall as wide, so within 22.5 degrees (tan 5/12) is along. [0 0] for the cell itself
 (toward a b) (a < b ? 1 (a > b ? -1 0))
 (tap-dir ex ey) (: ax (abs ex) ay (2 * abs ey)          ; in cell widths
                    [(12 * ax < 5 * ay ? 0 (toward 0 ex)) (12 * ay < 5 * ax ? 0 (toward 0 ey))])
 ; a floor's tap: on your own cell, or near when you stand on a stair, it is the stair (60).
 ; the note row is the screen's first, so a screen y is a floor y and one. c is [x y], cli's edtap
 (tap-steer g c) (: p (g 'p) d (g 'd)
                    ex (<c - peep d 'vx 0 - p 'x)
                    ey (<>c - 1 + peep d 'vy 0 - p 'y)
                    st (tap-dir ex ey)
                    (? (st = [0 0]) 60
                       (abs ex <= 1 && abs ey <= 1 && 2 = dat d (p 'x) (p 'y)) 60
                       st))
 ; ..but a tap on a standing sign is the choice it lands on: its digit, or 0, any other key
 (tap-key g c) (: sg (g 'sign) d (g 'd)
                  (two? sg ?
                     (: j (sign-line <sg >sg 1 (peep d 'rows (d 'h)) (peep d 'cols (d 'w)) <>c)
                        l (0 <= j ? (>sg j) "")
                        (2 < #l && l 0 = 1 ? (l 2) 0))  ; a choice's line opens on 1, its digit next
                     (tap-steer g c)))
 ; the key a floor's turn is given: a tap (cli's -12) through tap-key, the rest through steer
 (rove-key g k) (k = -12 ? (tap-key g (edtap ())) (steer k))
 ; ..and the tty a floor is played on, for ttytake and ttygive: a tap's press, no cursor
 rove-modes '(hide tap)

 ; a line and its holes: each ~ takes the next value, a string as itself, else as show
 (hole v) (string? v ? v (show v))
 (fill s vs) (:- (go 0 "" vs) (go i acc vs)
              (i >= #s ? acc
               (s i @ c
                (c = 126 && two? vs ? (go (i + 1) (acc + hole <vs) >vs)
                 (go (i + 1) (acc + string c) vs)))))
 ; a cell is a character, not a byte: a utf-8 tail rides with its lead
 (tail? c) (128 <= c < 192)
 (lead c) (tail? c ? 0 1)
 (cw s i) (max 0 (wcwidth (cpat s i)))                  ; the cells of the character at i
 ; ..and its braces put on at the port, and a choice between the bytes 1 and 2 on its own
 ; ground; escapes have no width, so the cut is in what a reader sees. off restores the pen after
 token-pen 201                                          ; the pen a {braced} word is named in
 (fit-in s w off) (: on ("\e[38;5;" + show token-pen + "m")
                     on2 ("\e[48;5;" + show choice-bg + ";38;5;" + show choice-fg + "m")
              (go i n acc)
               (i >= #s ? acc
                  (s i @ c
                     (? (n >= w) acc
                        (c = 123) (go (i + 1) n (acc + on))
                        (c = 1) (go (i + 1) n (acc + on2))
                        (c = 125 || c = 2) (go (i + 1) n (acc + off))
                        (: k (cpnext s i) v (n + cw s i)
                           (w < v ? acc (go k v (acc + snip s i k)))))))
              (go 0 0 ""))
 (fit s w) (fit-in s w "\e[0m")

 ; --- the sign: a box over the frame, measured in what a reader sees, running to the row's end ---
 sign-pen (x11-256 "lavender")                          ; the frame, and the title in its own
 sign-tpen (x11-256 "honeydew")
 (vlen s) (:- (go 0 0) (go i n) (i >= #s ? n
           (s i @ c (go (cpnext s i) (c @ (123 || 125 || 1 || 2) n (n + cw s i))))))
 (pad s n c) (vlen s @ v (v >= n ? s (s + ((n - v) (t \ t + c) ""))))
 (sign-box ttl ls) (:
   w (foldl (a \ l \ (vlen l @ v (a < v ? v a))) (vlen ttl) ls)
   ww (w + 4)
   top ("+-" + pad (ttl + " ") (ww - 3) "-" + "+")
   bot ("+" + ((ww - 2) (t \ t + "-") "") + "+")
   ([top] + map (l \ "| " + pad l (ww - 4) " " + " |") ls + [bot]))
 ; the first n cells of a painted row: SGRs have no width, a tail byte belongs to its lead's
 ; cell, k the leads so far; \e[K has no m, so the skip stops at the row's end too
 (cell-of c k) (tail? c ? (k - 1) k)
 ; ..a row shorter than n cells is padded out to n, so what follows lands where measured
 (cells-cut r n) (:- (go 0 0 "")
                  (past i) (i >= #r ? i (r i @ 109 (i + 1) (past (i + 1))))
                  (go i k acc)
                   (i >= #r ? (acc + ((n - k) (t \ t + " ") ""))
                    (r i @ c
                       (? (n <= cell-of c k) acc
                          (c = 27) (past i @ e (go e k (acc + snip r i e)))
                          (go (i + 1) (k + lead c) (acc + string c))))))
 ; ..and the cells from n on. every escape is kept from the row's start: the colour in force
 ; at n was set to its left
 (cells-from r n) (:- (go 0 0 "")
                   (past i) (i >= #r ? i (r i @ 109 (i + 1) (past (i + 1))))
                   (go i k acc)
                    (i >= #r ? acc
                     (r i @ 27 (past i @ e (go e k (acc + snip r i e)))
                       c (go (i + 1) (k + lead c) (n <= cell-of c k ? (acc + string c) acc)))))
 ; a line wider than the screen is reflowed at its words, ten cells short of the edge
 (sign-flow ls w) ((cite 'story 'wrap) @ wr
                   (map (l \ wr && (w - 10) < vlen l ? (wr l (w - 10)) [l]) ls))
 ; the screen row the box's top takes, for a box of nb rows
 (sign-top a n nb) (a + (n - nb) // 2 @ q (a < q ? q a))
 ; the line under screen row y, as an index into ls, or -1 off the box and its frame
 (sign-line ttl ls a n w y) (:- (go (y - sign-top a n (2 + net (map tally fl)) - 1) 0 fl)
   fl (sign-flow ls w)
   (go j i l) (? (j < 0 || atom? l) -1
                 (j < #<l) i
                 (go (j - #<l) (i + 1) >l)))
 ; where the box lands on the screen: [x0 y0 w rows], as sign-over lays it
 (sign-rect ttl ls a n w) (: box (sign-box ttl (foldl (+) () (sign-flow ls w)))
                             ww (vlen <box)
                             [((w - ww) // 2 @ q (0 < q ? q 0)) (sign-top a n #box) ww #box])
 ; a frame with the box centred over its rows a .. a+n, for a screen w wide; the box
 ; takes the rows the reflow makes
 (sign-over f ttl ls a n w) (:- (go 0 "")
   rs (split "\r\n" f)
   box (sign-box ttl (foldl (+) () (sign-flow ls w)))
   ww (vlen <box)
   x0 ((w - ww) // 2 @ q (0 < q ? q 0))
   y0 (sign-top a n #box)
   ; ..never past the rows it was given: a box too tall loses its foot, not the bar under it
   (lay i) (rs i @ r
            (!(y0 <= i < y0 + #box && i < a + n) ? r
             ; the field either side and the box between; the tail is needed, or the cells past the box
             ; keep what the last frame put there
             (cells-cut r x0 + "\e[0m" + pen sign-pen + fit-in (row i) 400 ("\e[0m" + pen sign-pen)
              + "\e[0m" + cells-from r (x0 + ww))))
   ; the top row's tab, +-title, wears its own pen; the cells were counted before the pens went in
   (row i) (box (i - y0) @ s
              (i = y0 && 0 < #ttl ? (pen sign-tpen + snip s 0 (3 + #ttl) + pen sign-pen + snip s (3 + #ttl) #s) s))
   (go i acc) (i >= #rs ? acc (go (i + 1) (acc + (0 < i ? "\r\n" "") + lay i))))

 ; --- the keys: the same key again within a gap of the last is dropped, a longer gap while a
 ; sign stands, so a held key cannot run through pages. a different key passes at once ---
 repeat-gap 120                                         ; ms a held key's repeats are dropped for
 sign-gap 600                                           ; ..and while a sign stands
 ; the blocking shape: wait for a key, idle between polls; last the key the last turn took
 ; and t0 when. a tap's release (cli's 0) is no key
 (key-wait t0 last gap idle) (cue? 0 ?
                                (edkey in @ k
                                   (k = 0 || k = last && clock t0 < gap ? (key-wait t0 last gap idle) k))
                                (idle (), key-wait t0 last gap idle))
 ; the polling shape: every waiting key handed to take under the same rule, the last key and
 ; its time riding g as 'lk and 'lt; answers how many were taken
 (key-drain g gap take)
  (:- (go 0) (go n)
   (cue? 0 ?
      (edkey in @ k
         (k = g 'lk && clock (g 'lt) < gap ? (go n)
            (take k, pins g 'lk k 'lt (clock 0), go (n + 1))))
      n))
 ; the queue eaten: keys typed at what stood before are not for what stands now; stops at end of input
 (drain-keys _) (cue? 0 ? (see in @ -1 () _ (drain-keys ())))

 ; --- the horn: every sample is a closure call, so wasm plays at a third of the 48k ---
 song-rate (love-arch @ 'wasm 16000 48000)
 ; the queue must outlast the gap between feeds, which on a slow machine is a frame's paint;
 ; the pacer holds the gap at its recent worst, halving every two seconds of clock, and the
 ; lead is two and a half gaps, clamped to song-lead .. song-lead-max
 song-lead (6 * (song-rate // 30))
 song-lead-max (20 * (song-rate // 30))
 (pacer _) {'t (clock 0) 'gap 0.0}
 (pace! p) (: t (clock 0)
              d (1.0 * (t - p 't))
              v ((d / 2000.0) 0.5 * p 'gap)
              ((pins p 't t 'gap (v < d ? d v)),
               p 'gap))
 (song-lead-of gap) (int (2.5 * gap * song-rate / 1000.0) @ n
                       (n < song-lead ? song-lead (song-lead-max < n ? song-lead-max n)))
 ; the horn fed up to a lead, while each feed raises the lag: a full ring or run takes nothing,
 ; so a lead past them is never reached and the filler stops rather than loop. answers the feeds
 (song-fill hn lead feed) (:- (go (horn-lag hn) 0) (go l0 k)
                            (l0 < lead ? (: _ (feed ()) l1 (horn-lag hn) (l0 < l1 ? (go l1 (k + 1)) (k + 1)))
                               k))
 ; ..and a settle: keys drained for a while, under a box that goes up over what they were typed at
 settle-slice 25
 (settle ms) (0 < ms ? (drain-keys (), rest settle-slice, settle (ms - settle-slice)))

 (note g s) (pin g 'msg (g 'msg ? (g 'msg + "; " + s) s))
 (mob-at g x y) <(filter ({'x ^x 'y ^y} \ 1) (g 'ms))
 ; a mob stirs on the turns its pace divides, so heaven moves at half a climber's rate
 (due? g m) (0 = g 'tn % m 'pc)
 ; --- a turn on a floor: the walk's key, the turn it makes, the mobs after it ---
 ; ..the mobs that move (moves? m) wander a step a turn by sb's dice, to a cell free? holds and
 ; no mob stands on
 (rove-wander ms sb moves? free?) (: (taken? x y) (any (m \ m 'x = x && m 'y = y) ms)
   (each ms (m \ (moves? m ? (: nx (m 'x + roll sb 3 - 1) ny (m 'y + roll sb 3 - 1)
                                 (? (free? nx ny && !(taken? nx ny)) (pins m 'x nx 'y ny)))))))
 ; ..a turn: the note cleared and the turn counted; a standing sign takes the key (sign g k),
 ; an ended walk none, and a steer is a step (step g k)
 (rove-turn g k sign step) (: _ (pins g 'msg "" 'tn (1 + g 'tn))
   ((? (g 'sign) (sign g k) (g 'over) () (two? k) (step g k) ()),
    g))
 ; ..a key: escape at a standing sign takes it down (down g), q or escape ends the walk as how,
 ; any other is a turn (turn g k) on its steer
 (rove-press g k how down turn) (k = 27 && g 'sign ? (down g)
   (k @ (113 || 27 || -7) (pin g 'over how) (turn g (rove-key g k))))
 ; ..and the walk's loop: frame said, a key waited for and paced, (idle) while none comes,
 ; handed on (press k), until the walk is over
 (rove-loop g frame idle press) (: (go last t0) (g 'over ? ()
                                   (: _ (say out (frame g), flush out)
                                      k (key-wait t0 last (g 'sign ? sign-gap repeat-gap) idle)
                                      (press k,
                                       go k (clock 0))))
   (go 0 0)))
) ; module rove
