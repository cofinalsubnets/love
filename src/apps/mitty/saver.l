; src/apps/mitty/saver.l -- mitty's screensavers. a saver draws into a canvas of cells at a
; time t, and a painter sends only the cells that changed since the last frame.
;
;   love mitty -s NAME     a saver on its own, until a key; -s alone names them
;
; mitty starts one when its glass has had no key for (screensaver-idle N) minutes, as
; ~/.love/etc/mitty.l says with (screensaver NAME) -- cycle and 10 unless said, 0 for never --
; and the watch below is all it holds. the frames are pure in (rows cols t phase):
; saver-frame and saver-canvas are the headless doors, gated by test/host/saver.l.
;   pom     the moon at its phase, over stars that twinkle; pom natural draws it as pom -n
;   slop    slop's skin, slop-drift, in its own gold and pink
;   life    conway's life on the half cells, aged in greens
;   matrix  green rain down the columns
;   court   lore's courtyard: a day and an hour thrown, the season's weather, the eye
;           somewhere in the yard turning slowly, the hours running on
;   grass99 grass simulator 1999's week, from a thrown hour of it, the field on its own
;   cycle   each of the above in turn, the next at each start and every five minutes
(module (saver saver-names saver-frame saver-canvas saver-cell saver-moon-lit?
         saver-watch saver-tick saver-key saver-on? saver-cli)
(borrow 'posix)
(borrow 'cal)
(:
 drain-keys (cite 'rove 'drain-keys)
 ; a cell's own dice, kept under 2^32 at every step so no product leaves the fixnums
 (h32 a) (: h ((a ^ a >> 16) * 73244475 % 4294967296)
            h2 ((h ^ h >> 16) * 73244475 % 4294967296)
            (h2 ^ h2 >> 16))
 (dice x y s k) (h32 ((x * 7919 + y * 104729 + s * 15485863) % 4294967296) % k)

 ; --- the canvas: r by c cells of seven bytes, a glyph and two pens of three. a pen below
 ; 256 is the palette's; 256 on is 256 + a 24-bit colour as view-deep-pens gives it ---
 blank-fg 252
 sky 16
 cw 7
 (cv-new r c) (: n (r * c) z (cask (cw * n))
                 _ (each ^n (i \ cv-set z i 32 blank-fg sky))
                 {'r r 'c c 'b (cask (cw * n)) 'z z})
 (cv-wipe cv) (pour (cv 'b) 0 (cv 'z) 0 (cw * cv 'r * cv 'c))
 ; cell i of the canvas's bytes d
 (pen3 d k v) (pin d k (v >> 16 & 255), pin d (k + 1) (v >> 8 & 255), pin d (k + 2) (v & 255))
 (pen-at d k) (peep d k 0 * 65536 + peep d (k + 1) 0 * 256 + peep d (k + 2) 0)
 (cv-set d i g f b) (: k (cw * i) (pin d k g, pen3 d (k + 1) f, pen3 d (k + 4) b))
 (cv-put cv y x g f b) (? (0 <= y < cv 'r && 0 <= x < cv 'c) (cv-set (cv 'b) (y * cv 'c + x) g f b))
 ; ascii only: a byte is a cell
 (cv-text cv y x s f b) (each ^#s (i \ cv-put cv y (x + i) (s i) f b))
 (saver-cell cv y x) (: k (cw * (y * cv 'c + x)) d (cv 'b) [(peep d k 0) (pen-at d (k + 1)) (pen-at d (k + 4))])

 ; a glyph byte below 128 is itself; these are the ones above
 marks ["▀" "·" "✉"]
 hb 128
 twinkle 129
 mail 130
 glyphs (: t {} _ (each ^128 (i \ pin t i (string i))) _ (each ^#marks (i \ pin t (128 + i) (marks i))) t)

 ; the pens and the cursor's steps right, spelled once
 fgs (: t {} _ (each ^256 (i \ pin t i ("\e[38;5;" + show i + "m"))) t)
 bgs (: t {} _ (each ^256 (i \ pin t i ("\e[48;5;" + show i + "m"))) t)
 ; ..and a 24-bit one, its six bits a channel widened
 (rgb-sgr ground v) (: q (v - 256) (ch k) (show ((q >> k & 63) * 255 // 63))
   ("\e[" + ground + ";2;" + ch 12 + ";" + ch 6 + ";" + ch 0 + "m"))
 (fg-sgr f) (f < 256 ? (fgs f) (rgb-sgr "38" f))
 (bg-sgr b) (b < 256 ? (bgs b) (rgb-sgr "48" b))
 rights (: t {} _ (each ^256 (i \ pin t i ("\e[" + show i + "C"))) t)

 ; the first cell from i on where the bytes a and p differ, n for none: numbers only, so
 ; the scan stays a tight loop
 (cv-next a p i n)
  (? (i < n && (: k (cw * i) (peep a k 0 = peep p k 0 && peep a (k + 1) 0 = peep p (k + 1) 0
                                && peep a (k + 2) 0 = peep p (k + 2) 0 && peep a (k + 3) 0 = peep p (k + 3) 0
                                && peep a (k + 4) 0 = peep p (k + 4) 0 && peep a (k + 5) 0 = peep p (k + 5) 0
                                && peep a (k + 6) 0 = peep p (k + 6) 0)))
     (cv-next a p (i + 1) n)
     i)
 ; the cells of cv that differ from pv's, or all of them, as escapes; pv is then cv's copy.
 ; the cursor and the pen are tracked, so a run of changed cells costs a glyph each, and
 ; a gap in a row a step right
 (cv-paint cv pv all)
  (: j (jug 0) c (cv 'c) n (cv 'r * c) a (cv 'b) p (pv 'b)
     (go i0 at f0 b0)
      (: i (all ? i0 (cv-next a p i0 n))
         (? (i < n)
            (: k (cw * i) g (peep a k 0) f (pen-at a (k + 1)) b (pen-at a (k + 4))
               _ (? (at = i) 0
                    (0 <= at && at // c = i // c) (say j (rights (i - at)))
                    (say j ("\e[" + show (i // c + 1) + ";" + show (i % c + 1) + "H")))
               _ (? (f != f0) (say j (fg-sgr f)) 0)
               _ (? (b != b0) (say j (bg-sgr b)) 0)
               _ (say j (glyphs g))
               (go (i + 1) (i % c = c - 1 ? -1 (i + 1)) f b))
            0))
     _ (go 0 -1 -1 -1)
     _ (pour p 0 a 0 (cw * n))
     s (slurp j)
     (#s ? ("\e[?2026h" + s + "\e[0m\e[?2026l") ""))

 ; --- pom: the moon at its phase, large and centred, over stars that twinkle ---
 pom-name (cite 'pom 'pom-name)
 pom-percent (cite 'pom 'pom-percent)
 pom-now (cite 'pom 'pom-now)                  ; the phase this hour, utc, as pom reckons it
 ; the moon's face is pom's, so `pom -s` prints what this draws
 saver-moon-lit? (cite 'pom 'pom-lit?)
 moon-pen (cite 'pom 'pom-face)
 ; ..or as pom -n draws it, its nearest pen
 (natural-pen p nx ny) ((cite 'pom 'pom-glow) p nx ny @ v (charm? v ? ((cite 'pom 'pom-xterm) v)))
 ; the disc on half cells, a cell two pixels each about as wide as it is tall, as
 ; [y x upper lower] for every cell it touches: laid once, it does not move
 (moon-cells p r c pen0)
  (: rad (0.45 * min (2 * r - 4) c)
     cy (r - 1.0) cx (c / 2.0)
     y0 (max 0 (floor ((cy - rad) / 2) - 1)) y1 (min (r - 1) (floor ((cy + rad) / 2) + 1))
     x0 (max 0 (floor (cx - rad) - 1)) x1 (min c (floor (cx + rad) + 2))
     (pen x py) (pen0 p ((x + 0.5 - cx) / rad) ((py + 0.5 - cy) / rad))
     (cell y x) (: u (pen x (2 * y)) l (pen x (2 * y + 1))
                   (? (u = () && l = ()) () [y x (u = () ? sky u) (l = () ? sky l)]))
     (? (rad <= 0) ()
        (filter two? (catmap (y \ map (x \ cell y x) (map (+ x0) ^(x1 - x0))) (map (+ y0) ^(y1 - y0))))))
 ; a few dozen stars, each [y x period phase], off the caption's row
 (pom-new r c seed p0 sty)
  (: n (min 64 (max 16 (r * c // 50)))
     h (max 1 (r - 1))
     p (p0 = () ? (pom-now 0) p0)
     {'p p 'moon (moon-cells p r c (sty = "natural" ? natural-pen moon-pen))
      'stars (map (i \ [(dice i 0 seed h) (dice i 1 seed c) (1500 + dice i 2 seed 5000) (dice i 3 seed 628 / 100.0)]) ^n)})
 (star cv s t) (: b (sin (2 * pi * t / s 2 + s 3))
                  (? (b < -0.4) (cv-put cv <s (s 1) 46 238 sky)
                     (b < 0.3) (cv-put cv <s (s 1) twinkle 244 sky)
                     (b < 0.8) (cv-put cv <s (s 1) 43 250 sky)
                     (cv-put cv <s (s 1) 42 255 sky)))
 (pom-draw st cv t)
  (: r (cv 'r) c (cv 'c) p (st 'p)
     cap (pom-name p + ", " + show (pom-percent p) + "% of full")
     (each (st 'stars) (s \ star cv s t),
      each (st 'moon) (m \ cv-put cv <m (m 1) hb (m 2) (m 3)),
      cv-text cv (r - 1) (max 0 ((c - #cap) // 2)) (snip cap 0 c) 244 sky))

 ; --- slop: slop-drift, the slop's skin, on half cells in slop's own ramp ---
 slop-drift (cite 'slop 'slop-drift)
 ramp (star-tray [#(cite 'slop 'slop-ramp)] (cite 'slop 'slop-ramp))
 ; each cell's upper and lower sample, as flat indices into the field's 2r by c
 (slop-new r c seed p sty)
  (: n (r * c) up ((iota n // c) * (2 * c) + iota n % c)
     {'f (slop-drift r c) 'up up 'lo (up + c)})
 ; the skin's [-4 4] read onto the ramp's 24 steps, slop's own reading, at a calmer clock;
 ; the pens are two gathers, so the cells are only copied
 (slop-draw st cv t)
  (: fl (st 'f)
     k (int ((fl (t * 0.0005) 0 + 4.001) * 2.9))
     fg (peep ramp (peep k (st 'up) 0) 220)
     bg (peep ramp (peep k (st 'lo) 0) 220)
     d (cv 'b)
     (each ^(cv 'r * cv 'c) (i \ cv-set d i hb (peep fg i 0) (peep bg i 0))))

 ; --- life: conway's, on a torus of half cells, each cell's age its green ---
 ; a step is eight gathers and a few tray ops, C doing every cell
 (life-new r c seed p sty)
  (: h (2 * r) w c n (h * w)
     ys (iota n // w) xs (iota n % w)
     (nb dy dx) ((ys + dy + h) % h * w + (xs + dx + w) % w)
     up ((iota (r * c) // c) * (2 * c) + iota (r * c) % c)
     {'n n 'seed seed 'gen 0 't 0 'same 0 'pop -1 'up up 'lo (up + c)
      'nbs [(nb -1 -1) (nb -1 0) (nb -1 1) (nb 0 -1) (nb 0 1) (nb 1 -1) (nb 1 0) (nb 1 1)]
      'age (life-seed n seed)})
 (life-seed n seed) (star-tray [n] (map (i \ (dice i 7 seed 100 < 28 ? 1 0)) ^n))
 (life-step st)
  (: a (st 'age)
     g (min a 1)
     s (foldl (\ acc ix (acc + peep g ix 0)) 0 (st 'nbs))
     g2 ((s = 3) + g * (s = 2))
     pop (net g2)
     ; a world gone still, or into a loop of one population, is sown again
     same (pop = st 'pop ? (st 'same + 1) 0)
     (? (40 < same || 2000 < st 'gen)
        (: sd (st 'seed + 1) (pins st 'seed sd 'age (life-seed (st 'n) sd) 'gen 0 'same 0 'pop -1))
        (pins st 'age (g2 * min (a + 1) 60) 'gen (st 'gen + 1) 'same same 'pop pop)))
 ; an age's green: newborn pale, the long-lived dark
 life-pens (star-tray [61] (map (a \ (? (a < 1) sky (a < 2) 157 (a < 4) 120 (a < 9) 46 (a < 20) 34 28)) ^61))
 life-gps 10
 ; the generations owed by t, at most three a frame so a late frame does not stall
 (life-draw st cv t)
  (: want (t * life-gps // 1000)
     (owed k) (? (k < 3 && st 't < want) (: _ (life-step st) _ (pin st 't (st 't + 1)) (owed (k + 1))) 0)
     _ (owed 0)
     a (st 'age)
     fg (peep life-pens (peep a (st 'up) 0) sky)
     bg (peep life-pens (peep a (st 'lo) 0) sky)
     d (cv 'b)
     (each ^(cv 'r * cv 'c) (i \ cv-set d i hb (peep fg i 0) (peep bg i 0))))

 ; --- matrix: green rain, each column a drop of its own speed, length and gap; the head
 ; and every glyph a pure function of the column, the row and the clock ---
 (rain-new r c seed p sty) {'seed seed}
 (rain-pen d n) (? (d = 0) 231 (4 * d < n) 46 (2 * d < n) 40 (4 * d < 3 * n) 34 22)
 (rain-draw st cv t)
  (: r (cv 'r) sd (st 'seed)
     (col x)
      (: sp (5 + dice x 0 sd 14)
         n (4 + dice x 1 sd (max 1 (r - 2)))
         per (r + n + dice x 2 sd (2 * r + 1))
         pos (t * sp // 1000 + dice x 3 sd per)
         cyc (pos // per) hd (pos % per)
         (cell d) (: y (hd - d)
                     ; one glyph in nine flickers; the rest hold for the drop's pass
                     fl (dice x y sd 9 = 0 ? (t // 180) 0)
                     (? (0 <= y < r)
                        (cv-put cv y x (33 + dice x y (sd + cyc * 7 + fl + (d = 0) * (t // 90)) 94) (rain-pen d n) sky)))
         (each ^n cell))
     (each ^(cv 'c) col))

 ; --- the lore scenes: a screen of pixels two to a cell, drawn as half blocks in the
 ; scene's own dithered pens; the scene ticked as many frames as the clock owes it, a few
 ; at most, so a slow frame skips the time rather than chasing it ---
 ; a scene's colours as pens: 24-bit where COLORTERM says the terminal has them, as lore's
 ; games ask, else the palette's cube dithered by bay
 (scene-pens c bay) (? (elem (getenv "COLORTERM") ["truecolor" "24bit"]) ((cite 'view 'view-deep-pens) c + 256)
                       ((cite 'view 'view-cube-pens) c bay))
 (halves cv px) (: r (cv 'r) c (cv 'c) d (cv 'b)
   (each ^r (y \ each ^c (x \ cv-set d (y * c + x) hb (int (peep px (2 * y * c + x) 16))
                                      (int (peep px ((2 * y + 1) * c + x) 16))))))
 (owe s want tick) (: (go k) (? (k < 4 && s 'done < want) (: _ (tick 0) _ (pin s 'done (s 'done + 1)) (go (k + 1))) 0)
                      _ (go 0)
                      (pin s 'done (max (s 'done) (want - 4))))
 ; ..court: a day of this year and an hour thrown -- by day three times in four, any hour
 ; else -- the season's weather, the eye somewhere in the yard and not in the trunk,
 ; looking nearly straight up through a narrower lens than the walk's, so the sky fills
 ; it and the wall tops and the tree frame it, nodding slowly as it turns; the sky's
 ; hours at 600 a second
 (court-new r c seed p sty)
  (: (rr k m) (dice k 5 seed m)
     y <((cite 'cal 'civil) (clock 0 // 86400000))
     hr (rr 7 4 = 0 ? (rr 1 24) (7 + rr 1 12))
     l (86400.0 * (cite 'cal 'epoch-days) y 1 1 + 86400.0 * rr 0 365 + 3600.0 * hr + 60.0 * rr 2 60)
     st ((cite 'court 'court-new) c (2 * r) ((cite 'court 'court-local) l))
     ya (cite 'court 'yard-a) yb (cite 'court 'yard-b) bs (st 'tree 'base)
     x (ya * (rr 3 160 / 100.0 - 0.8)) z0 (yb * (rr 4 160 / 100.0 - 0.8))
     z ((x - bs 0) * (x - bs 0) + (z0 - bs 2) * (z0 - bs 2) < 0.6 ? (z0 - 1.5) z0)
     _ (pins st 'px x 'pz z 'th (rr 5 628 / 100.0) 'ph (rr 6 18 / 100.0 + 1.22) 'pace 1 'deep 0
                   'U (st 'U * 0.58) 'V (st 'V * 0.58) 'foc (st 'foc / 0.58))
     {'st st 'done 0 'th (st 'th) 'ph (st 'ph)})
 (court-draw s cv t)
  (: st (s 'st)
     _ (owe s (t * 20 // 1000) (_ \ (pin st 't (st 't + 1), (cite 'court 'court-move) st)))
     _ (pins st 'th (s 'th + t * 0.00003) 'ph (s 'ph + 0.05 * sin (t * 0.000045)))
     (halves cv (scene-pens ((cite 'court 'court-pens) st) (st 'bay))))
 ; ..grass99: the week from a thrown hour of it, a field its own; at the week's end another
 (meadow-new r c seed p sty)
  (: g ((cite 'grass 'grass-new) r c seed)
     _ (pin g 'h (6.0 + dice 0 9 seed 160 + dice 1 9 seed 100 / 100.0))
     {'g g 'm ((cite 'meadow 'meadow-new) (seed % 9973) c (2 * r)) 'done 0 'seed seed 'r r 'c c})
 (meadow-draw s cv t)
  (: _ (owe s (t * (cite 'grass 'fps) // 1000) (_ \ (cite 'grass 'grass-tick) (s 'g)))
     _ (? ((cite 'grass 'week-hours) <= s 'g 'h)
          (: n (meadow-new (s 'r) (s 'c) (s 'seed + 1) () ()) (pins s 'g (n 'g) 'm (n 'm) 'seed (n 'seed))) 0)
     g (s 'g) m (s 'm)
     (halves cv (scene-pens ((cite 'meadow 'meadow-pens) m g ((cite 'meadow 'meadow-sky) g)) (m 'bay * 0.5 + 0.25))))

 ; --- the savers, by name ---
 savers {"pom" {'fps 8 'new pom-new 'draw pom-draw}
         "court" {'fps 8 'new court-new 'draw court-draw}
         "grass99" {'fps 8 'new meadow-new 'draw meadow-draw}
         "slop" {'fps 12 'new slop-new 'draw slop-draw}
         "life" {'fps 10 'new life-new 'draw life-draw}
         "matrix" {'fps 15 'new rain-new 'draw rain-draw}}
 saver-names (sort (keys savers))
 ; cycle plays each saver in turn: the next at each start, and the next again each cycle-ms
 cycle-ms 300000
 (pick nm k) (nm = "cycle" ? (saver-names (k % #saver-names)) nm)
 ; a name may carry a style after a space, "pom natural": the saver's, then the word
 (base nm) (nm @ (b + " " + _) b _ nm)
 (style nm) (nm @ (_ + " " + w) w _ ())
 ; the styles a saver draws in besides its own
 styles {"pom" ["natural"]}
 (known? nm) (nm = "cycle" || peep savers (base nm) () != () && (style nm = () || elem (style nm) (peep styles (base nm) ())))
 (saver-make nm r c seed p)
  (: d (savers (base nm)) nw (d 'new)
     {'nm nm 'd d 'r r 'c c 'st (nw r c (seed % 65536) p (style nm)) 'cv (cv-new r c) 'pv (cv-new r c) 'all 1 't0 0 'next 0})
 ; the frame at t, ms into the saver; a mark, a pen, puts a small ✉ in the top right corner
 (saver-show s t mark)
  (: cv (s 'cv) dr ((s 'd) 'draw) all (s 'all)
     _ (cv-wipe cv)
     _ (dr (s 'st) cv t)
     _ (? mark (cv-put cv 0 (cv 'c - 2) mail mark sky) 0)
     _ (pin s 'all 0)
     (cv-paint cv (s 'pv) all))
 ; a frame now, the next one a period on; a frame late is skipped, not caught up
 (saver-step s now mark)
  (: per (1000 // peep (s 'd) 'fps 10) nx (s 'next + per)
     _ (pin s 'next (nx <= now ? (now + per) nx))
     (saver-show s (now - s 't0) mark))
 ; headless: a whole frame's escapes, and the canvas it painted
 (saver-frame nm r c t p) (: s (saver-make nm r c 7 p) (saver-show s t 0))
 (saver-canvas nm r c t p) (: s (saver-make nm r c 7 p) _ (saver-show s t 0) (s 'cv))

 ; --- the idle watch: a saver after mins without a key, and any key back ---
 ; the key that wakes it is the saver's; news is a count the screen keeps of what arrived
 (saver-watch nm mins)
  {'nm nm 'last () 'on () 'bye 0 'n0 0 'k (clock 0 // 1000)
   'idle (? !(known? nm) 0 (charm? mins || gem? mins) (int (mins * 60000)) 0)}
 (saver-on? w) (w 'on != ())
 (saver-key w now) (? (saver-on? w) (pins w 'on () 'bye 1 'last now, 1) (pin w 'last now, 0))
 ; -> the escapes to send now: a frame while a saver runs, the cursor back as it ends,
 ; else ""
 (saver-tick w now r c news)
  (: s (w 'on)
     (fresh t0 nm) (: s2 (saver-make nm r c now ()) (pins s2 't0 t0 'next now, pin w 'on s2, s2))
     (turn _) (: k (w 'k + 1) (pin w 'k k, pick (w 'nm) k))
     (? (w 'last = ()) (pin w 'last now, "")
        (w 'bye) (pin w 'bye 0, "\e[0m\e[?25h")
        (s = ()) (? (0 < w 'idle && w 'idle <= now - w 'last)
                    (: s2 (fresh now (turn 0)) (pin w 'n0 news, "\e[?25l" + saver-step s2 now 0))
                    "")
        (r != s 'r || c != s 'c) (saver-step (fresh (s 't0) (s 'nm)) now (news-pen w news))
        (w 'nm = "cycle" && cycle-ms <= now - s 't0) (saver-step (fresh now (turn 0)) now (news-pen w news))
        (now < s 'next) ""
        (saver-step s now (news-pen w news))))
 ; the mail mark's pen once news came, the watch's 'ink or a soft pink
 (news-pen w news) (w 'n0 < news ? (peep w 'ink 218) 0)

 ; --- the door: love mitty -s NAME [STYLE] ---
 (saver-cli as)
  (: nm (two? as ? (two? >as ? (<as + " " + <>as) <as) ())
     names (foldl (\ a n (a + n + (peep styles n () @ ss (two? ss ? (" [" + join "|" ss + "]") "")) + "\n")) "" saver-names
            + "cycle\n")
     (? (nm = ()) (puts names, 0)
        (2 < #as || !(known? nm)) (say err ("mitty: no screensaver " + nm + "; there are\n" + names), flush err, 2)
        (saver-run nm)))
 ; until a key: a frame when one is due, a rest until the next
 (saver-run nm)
  (: (go s k)
      (? (cue? 0) 0
         (: now (clock 0) z (ttysize 1 1)
            k2 (nm = "cycle" && cycle-ms <= now - s 't0 ? (k + 1) k)
            s2 (? (k2 != k) (: n (saver-make (pick nm k2) <z (z 1) now ()) (pins n 't0 now 'next now, n))
                  (<z = s 'r && z 1 = s 'c) s
                  (: n (saver-make (s 'nm) <z (z 1) now ()) (pins n 't0 (s 't0) 'next now, n)))
            _ (? (s2 'next <= now) (: f (saver-step s2 now 0) (say out f, flush out)) 0)
            _ (rest (max 5 (s2 'next - clock 0)))
            (go s2 k2)))
     (run _) (: z (ttysize 1 1) k0 (clock 0 // 1000)
                s0 (saver-make (pick nm k0) <z (z 1) (clock 0) ())
                (pins s0 't0 (clock 0) 'next (clock 0), go s0 k0))
     (ttytake ['hide], drain-keys (), mind run () (_ \ (drain-keys (), ttygive ['hide])), 0)))
) ; module saver
