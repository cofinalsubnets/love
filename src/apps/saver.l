; src/apps/saver.l -- screensavers for a full screen. a saver draws into a canvas of cells at
; a time t, and a painter sends only the cells that changed since the last frame.
;
;   love bee -s NAME     a saver on its own, until a key; -s alone names them
;
; bee's chat (src/apps/mitty/chat.l) starts one when it has had no key for (screensaver-idle N)
; minutes, and the watch below is all it holds. the frames are pure in (rows cols t phase): saver-frame and
; saver-canvas are the headless doors, gated by test/host/saver.l.
;   pom     the moon at its phase, over stars that twinkle
;   slop    slop's skin, slop-drift, in its own gold and pink
;   life    conway's life on the half cells, aged in greens
;   matrix  green rain down the columns
(module (saver saver-names saver-frame saver-canvas saver-cell saver-moon-lit?
         saver-watch saver-tick saver-key saver-on? saver-cli)
(borrow 'posix)
(borrow 'cal)
(:
 esc (string 27)
 drain-keys (cite 'rove 'drain-keys)
 (upto n f) (: (go i) (? (i < n) (: _ (f i) (go (i + 1))) 0) (go 0))
 ; a cell's own dice, kept under 2^32 at every step so no product leaves the fixnums
 (h32 a) (: h ((a ^ a >> 16) * 73244475 % 4294967296)
            h2 ((h ^ h >> 16) * 73244475 % 4294967296)
            (h2 ^ h2 >> 16))
 (dice x y s k) (h32 ((x * 7919 + y * 104729 + s * 15485863) % 4294967296) % k)

 ; --- the canvas: r by c cells of three bytes, glyph foreground background ---
 blank-fg 252
 sky 16
 (cv-new r c) (: n (r * c) z (cask (3 * n))
                 _ (upto n (i \ (pin z (3 * i) 32, pin z (3 * i + 1) blank-fg, pin z (3 * i + 2) sky)))
                 {'r r 'c c 'b (cask (3 * n)) 'z z})
 (cv-wipe cv) (pour (cv 'b) 0 (cv 'z) 0 (3 * cv 'r * cv 'c))
 ; cell i of the canvas's bytes d
 (cv-set d i g f b) (: k (3 * i) (pin d k g, pin d (k + 1) f, pin d (k + 2) b))
 (cv-put cv y x g f b) (? (0 <= y < cv 'r && 0 <= x < cv 'c) (cv-set (cv 'b) (y * cv 'c + x) g f b))
 ; ascii only: a byte is a cell
 (cv-text cv y x s f b) (upto #s (i \ cv-put cv y (x + i) (s i) f b))
 (saver-cell cv y x) (: k (3 * (y * cv 'c + x)) d (cv 'b) [(peep d k 0) (peep d (k + 1) 0) (peep d (k + 2) 0)])

 ; a glyph byte below 128 is itself; these are the ones above
 marks ["▀" "·" "✉"]
 hb 128
 twinkle 129
 mail 130
 glyphs (: t {} _ (upto 128 (i \ pin t i (string i))) _ (upto #marks (i \ pin t (128 + i) (marks i))) t)

 ; the pens and the cursor's steps right, spelled once
 fgs (: t {} _ (upto 256 (i \ pin t i (esc + "[38;5;" + show i + "m"))) t)
 bgs (: t {} _ (upto 256 (i \ pin t i (esc + "[48;5;" + show i + "m"))) t)
 rights (: t {} _ (upto 256 (i \ pin t i (esc + "[" + show i + "C"))) t)

 ; the first cell from i on where the bytes a and p differ, n for none: numbers only, so
 ; the scan stays a tight loop
 (cv-next a p i n)
  (? (i < n && peep a (3 * i) 0 = peep p (3 * i) 0 && peep a (3 * i + 1) 0 = peep p (3 * i + 1) 0
      && peep a (3 * i + 2) 0 = peep p (3 * i + 2) 0)
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
            (: k (3 * i) g (peep a k 0) f (peep a (k + 1) 0) b (peep a (k + 2) 0)
               _ (? (at = i) 0
                    (0 <= at && at // c = i // c) (say j (rights (i - at)))
                    (say j (esc + "[" + show (i // c + 1) + ";" + show (i % c + 1) + "H")))
               _ (? (f != f0) (say j (fgs f)) 0)
               _ (? (b != b0) (say j (bgs b)) 0)
               _ (say j (glyphs g))
               (go (i + 1) (i % c = c - 1 ? -1 (i + 1)) f b))
            0))
     _ (go 0 -1 -1 -1)
     _ (pour p 0 a 0 (3 * n))
     s (slurp j)
     (#s ? (esc + "[?2026h" + s + esc + "[0m" + esc + "[?2026l") ""))

 ; --- pom: the moon at its phase, large and centred, over stars that twinkle ---
 pom-phase (cite 'pom 'pom-phase)
 pom-name (cite 'pom 'pom-name)
 pom-percent (cite 'pom 'pom-percent)
 ; the phase this hour, utc, as pom reckons it
 (pom-now _) (: s (clock 0 // 1000) d (civil (s // 86400))
                (pom-phase (s % 86400 // 3600) <>d <>>d <d))
 ; the moon's face is pom's, so `pom -s` prints what this draws
 saver-moon-lit? (cite 'pom 'pom-lit?)
 moon-pen (cite 'pom 'pom-face)
 ; the disc on half cells, a cell two pixels each about as wide as it is tall, as
 ; [y x upper lower] for every cell it touches: laid once, it does not move
 (moon-cells p r c)
  (: rad (0.45 * min (2 * r - 4) c)
     cy (r - 1.0) cx (c / 2.0)
     y0 (max 0 (floor ((cy - rad) / 2) - 1)) y1 (min (r - 1) (floor ((cy + rad) / 2) + 1))
     x0 (max 0 (floor (cx - rad) - 1)) x1 (min c (floor (cx + rad) + 2))
     (pen x py) (moon-pen p ((x + 0.5 - cx) / rad) ((py + 0.5 - cy) / rad))
     (cell y x) (: u (pen x (2 * y)) l (pen x (2 * y + 1))
                   (? (u = () && l = ()) () [y x (u = () ? sky u) (l = () ? sky l)]))
     (? (rad <= 0) ()
        (filter two? (catmap (y \ map (x \ cell y x) (map (+ x0) ^(x1 - x0))) (map (+ y0) ^(y1 - y0))))))
 ; a few dozen stars, each [y x period phase], off the caption's row
 (pom-new r c seed p0)
  (: n (min 64 (max 16 (r * c // 50)))
     h (max 1 (r - 1))
     p (p0 = () ? (pom-now 0) p0)
     {'p p 'moon (moon-cells p r c)
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
 (slop-new r c seed p)
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
     (upto (cv 'r * cv 'c) (i \ cv-set d i hb (peep fg i 0) (peep bg i 0))))

 ; --- life: conway's, on a torus of half cells, each cell's age its green ---
 ; a step is eight gathers and a few tray ops, C doing every cell
 (life-new r c seed p)
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
     (upto (cv 'r * cv 'c) (i \ cv-set d i hb (peep fg i 0) (peep bg i 0))))

 ; --- matrix: green rain, each column a drop of its own speed, length and gap; the head
 ; and every glyph a pure function of the column, the row and the clock ---
 (rain-new r c seed p) {'seed seed}
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
         (upto n cell))
     (upto (cv 'c) col))

 ; --- the savers, by name ---
 savers {"pom" {'fps 8 'new pom-new 'draw pom-draw}
         "slop" {'fps 12 'new slop-new 'draw slop-draw}
         "life" {'fps 10 'new life-new 'draw life-draw}
         "matrix" {'fps 15 'new rain-new 'draw rain-draw}}
 saver-names (sort (keys savers))
 (saver-make nm r c seed p)
  (: d (savers nm) nw (d 'new)
     {'d d 'r r 'c c 'st (nw r c (seed % 65536) p) 'cv (cv-new r c) 'pv (cv-new r c) 'all 1 't0 0 'next 0})
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
  {'nm nm 'last () 'on () 'bye 0 'n0 0
   'idle (? (peep savers nm () = ()) 0 (charm? mins || gem? mins) (int (mins * 60000)) 0)}
 (saver-on? w) (w 'on != ())
 (saver-key w now) (? (saver-on? w) (pins w 'on () 'bye 1 'last now, 1) (pin w 'last now, 0))
 ; -> the escapes to send now: a frame while a saver runs, the cursor back as it ends,
 ; else ""
 (saver-tick w now r c news)
  (: s (w 'on)
     (fresh t0) (: s2 (saver-make (w 'nm) r c now ()) (pins s2 't0 t0 'next now, pin w 'on s2, s2))
     (? (w 'last = ()) (pin w 'last now, "")
        (w 'bye) (pin w 'bye 0, esc + "[0m" + esc + "[?25h")
        (s = ()) (? (0 < w 'idle && w 'idle <= now - w 'last)
                    (: s2 (fresh now) (pin w 'n0 news, esc + "[?25l" + saver-step s2 now 0))
                    "")
        (r != s 'r || c != s 'c) (saver-step (fresh (s 't0)) now (news-pen w news))
        (now < s 'next) ""
        (saver-step s now (news-pen w news))))
 ; the mail mark's pen once news came, the watch's 'ink (bee's accent) or a soft pink
 (news-pen w news) (w 'n0 < news ? (peep w 'ink 218) 0)

 ; --- the door: love bee -s NAME ---
 (saver-cli as)
  (: nm (two? as ? <as ())
     names (foldl (\ a n (a + n + "\n")) "" saver-names)
     (? (nm = ()) (puts names, 0)
        (peep savers nm () = ()) (say err ("bee: no screensaver " + nm + "; there are\n" + names), flush err, 2)
        (saver-run nm)))
 (size _) (: ws (tty 1) [(two? ws && 1 < <ws ? <ws 24) (two? ws && 1 < >ws ? >ws 80)])
 ; until a key: a frame when one is due, a rest until the next
 (saver-run nm)
  (: (go s)
      (? (cue? 0) 0
         (: now (clock 0) z (size 0)
            s2 (? (<z = s 'r && z 1 = s 'c) s
                  (: n (saver-make nm <z (z 1) now ()) (pins n 't0 (s 't0) 'next now, n)))
            _ (? (s2 'next <= now) (: f (saver-step s2 now 0) (say out f, flush out)) 0)
            _ (rest (max 5 (s2 'next - clock 0)))
            (go s2)))
     _ (raw 1)
     _ (say out (esc + "[?1049h" + esc + "[?25l" + esc + "[2J"))
     _ (flush out)
     _ (drain-keys ())
     z (size 0)
     s0 (saver-make nm <z (z 1) (clock 0) ())
     _ (pins s0 't0 (clock 0) 'next (clock 0))
     _ (go s0)
     _ (drain-keys ())
     _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"))
     _ (flush out)
     _ (raw 0)
     0))
) ; module saver
