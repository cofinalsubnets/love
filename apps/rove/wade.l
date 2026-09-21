; wade -- a night river in half blocks, first person: the sky, a moon and stars, black
; forest on either bank, and all of it in the water, rippled where the player wades.
;
; the screen is the terminal, two pixels to a cell: the upper half block, the top pixel
; in the pen and the bottom in the ground; the view is ninety degrees wide whatever the
; width, and the horizon starts halfway down. nothing is stored: a tree is a hash of its bank,
; its row back from the water and its place along the river, which loops; a star is a
; hash of the bearing and height its direction falls in, so both keep their places as
; the player turns and wades. the water is a mirror in the world: a pixel's ray meets
; the water, and the swell and the rings the player's steps sent out tilt what it shows,
; by more the nearer, which is what draws the moon into a path.
;
; the music is a slendro pentatonic, five near-equal steps to the octave as a gamelan
; is tuned, struck at random on a long-ringing chime, low and slow, with a gong under it
; every so many seconds; it goes out the horn a frame's worth at a time.
;
; the scene is pure love -- wade-new, wade-step, wade-move and wade-frame are state in
; and state out, and the song feeds any port -- gated headless by test/host/wade.l;
; only wade-run ties the tty and the horn.
;
; run: love wade    h l or the arrows turn, k j or up down wade on and back, u n look up
;                   and down, space walks on until pressed again; q or esc leaves.
;                   HORN=none plays silent on a seat with no sound device
(module (wade wade-run wade-main wade-new wade-step wade-move wade-frame wade-tables
         wade-size wade-song-new wade-song-feed moon-at swell rings-at tree-of rw sp loop fps
         slendro song-chunk)
(borrow 'rove)
(borrow 'play)                          ; the voices, the mix
(? (cite 'posix) (borrow 'posix) ())    ; close, for the horn
(:
 esc (string 27)
 ; the screen rides the state: 'w and 'h its pixels, 'cx the middle column, 'foc the
 ; focal length, half the width for a view ninety degrees wide, 'hz the horizon's row
 eh 1.2 rw 5.0                        ; the eye above the water, waist deep; the river's half width
 sp 3.0 loop 64                       ; a tree every so far along a bank; the bank repeats
 far 150.0 near 35.0                  ; sight along a bank; a tree nearer than near is black, past it haze
 fps 30
 pi 3.141592653589793
 ; the pens, in the 256-colour palette. 16..231 is a 6x6x6 cube, a channel's levels
 ; 0 95 135 175 215 255 and the cell 16 + 36r + 6g + b; 232..255 is the grey ramp, where
 ; 232 + n is #vvvvvv with v = 8 + 10n, so a grey of brightness v is 232 + (v - 8) / 10.
 ; `love x11 NAME` answers a named colour's cube cell
 moon-pen 230 sea-pen 187             ; #ffffd7 the disc, #d7d7af its seas
 tree-pen 16 haze-pen 233             ; #000000 a near tree, #121212 a far one
 bank-pen 232                         ; #080808 the bank, a shade under the water's #121212
 (clamp v lo hi) (v < lo ? lo (hi < v ? hi v))
 (flo v) (int (v + 1000.0) - 1000)
 (wrap a) (a < -pi ? (wrap (a + 2.0 * pi)) (pi < a ? (wrap (a - 2.0 * pi)) a))
 (tn a) (sin a / cos a)
 (min2 a b) (a < b ? a b)
 (max2 a b) (a < b ? b a)
 ; the moon: its bearing, its height, and its angular radius; on a screen whose horizon
 ; is row hz it is [cx cy r], or far off the screen when it is behind the player
 maz 0.35 mel 0.40 mang 0.14
 (moon-at st) (: th (st 'th) hz (st 'hz) foc (st 'foc) rel (wrap (maz - th)) c (cos rel)
   (? (abs rel < 1.3) [(st 'cx + foc * tn rel) (hz - (foc * tn mel) / c) ((foc * tn mang) / c)]
      [-999.0 -999.0 0.0]))
 ; a tree by its bank s (-1 or 1), its row r back from the water and its index k along
 ; the river: where it stands, how tall and wide, and whether its crown is round. the
 ; loop has so many places, and each is hashed once and kept
 trees {}
 (tree-of k s r) (: kk (((k % loop) + loop) % loop) key (kk * 8 + r * 2 + (0 < s))
   b (peep trees key ())
   b2 (? (two? b) b
         (: seed (s + 2 + 5 * r)
            b3 [((dice kk seed 3 100) / 100.0 * sp)
                (s * (rw + 0.8 + 2.2 * r + (dice kk seed 5 100) / 100.0 * 2.0))
                (5.0 + (dice kk seed 7 100) / 100.0 * 6.0)
                (2.5 + (dice kk seed 9 100) / 100.0 * 2.5)
                ((dice kk seed 4 3) = 0)]
            (pin trees key b3, b3)))
   {'z (k * sp + b2 0) 'x (b2 1) 'ht (b2 2) 'wd (b2 3) 'round (b2 4)})
 ; the frame's tables: the columns' indices and bearing cells as trays; the treeline's
 ; top row for all trees and for the near ones alone and the reflection's bottom row,
 ; tablets while the trees are laid and trays after; a row's height cell, for rows well
 ; above the screen too, since the water mirrors sky that is off the top; and the sky's
 ; rows, darkened for the water, and the frame's, kept as they are asked for
 (fresh st) (: w (st 'w) h (st 'h) hz (st 'hz) th (st 'th) foc (st 'foc) cx (st 'cx)
   xs (iota w)
   tb {'xs xs 'tops {} 'ntops {} 'bots {} 'qes {} 'sky {} 'dark {} 'rows {}
       'qas (((floor ((th + atan ((xs - cx) / foc)) / (2.0 * pi) * 256.0)) % 256 + 256) % 256)}
   (row y) (? (y < hz) (pin (tb 'qes) y (flo (atan ((hz - y) / foc) * foc)), row (y + 1)))
   (row (0 - h - 12), tb))
 ; the trees within sight, each laid into the columns it covers: a conifer or a round
 ; crown, its base at the bank and its mirror hanging under it. the row at the water
 ; runs to the horizon, the two behind it half as far
 (lay-trees st tb) (: px (st 'px) pz (st 'pz) th (st 'th) hz (st 'hz) sn (sin th) cs (cos th)
   w (st 'w) foc (st 'foc) cx0 (st 'cx)
   (one k s r) (: tr (tree-of k s r)
     dx (tr 'x - px) dz (tr 'z - pz)
     d (dx * sn + dz * cs) lat (dx * cs - dz * sn)
     (? (0.5 < d)
        (: u (lat / d)
           (? (abs u < 1.5)
              (: cx (cx0 + foc * u) hw ((foc * tr 'wd) / (2.0 * d)) hg ((foc * tr 'ht) / d) by (hz + (foc * eh) / d)
                 tops (d < near ? (tb 'ntops) (tb 'tops)) bots (tb 'bots)
                 xa (clamp (flo (cx - hw)) 0 (w - 1)) xb (clamp (flo (cx + hw)) 0 (w - 1))
                 (col x) (? (x <= xb) (: q ((abs (x - cx)) / hw)
                                         hx (q < 1.0 ? (hg * (? (tr 'round) (sqrt (1.0 - q * q)) (1.0 - q))) 0.0)
                                         _ (pin tops x (min2 (peep tops x 999.0) (by - hx)))
                                         _ (pin bots x (max2 (peep bots x (hz - 1.0)) (by + hx)))
                                         (col (x + 1))))
                 (col xa))))))
   (go k k1 r) (? (k <= k1) (one k -1 r, one k 1 r, go (k + 1) k1 r))
   (span r reach) (go (flo ((pz - reach) / sp)) (flo ((pz + reach) / sp)) r)
   (tray-of tab d) (gem-tray [w] (map (x \ peep tab x d) (jot w)))
   (span 0 far, span 1 (far / 2.0), span 2 (far / 2.0),
    pins tb 'tops (tray-of (tb 'tops) 999.0) 'ntops (tray-of (tb 'ntops) 999.0) 'bots (tray-of (tb 'bots) (hz - 1.0))))
 (wade-tables st) (: tb (lay-trees st (fresh st)) (pin tb 'water (water-rows st)))
 ; the sky, a row at a time in trays over the columns: a grey ramp up from the horizon,
 ; the stars hashed off the column's bearing cell and the row's height cell, the moon's
 ; glow, and its disc with its seas, each laid over the last where its mask holds. the
 ; ramp's bands and the glow's reach scale with the screen. the hash is two rounds of
 ; multiply, shift and mask kept under 32 bits, so a tray's machine words and a number
 ; throw alike
 m32 4294967295
 (mash a) (: h (((a & m32) * 1103515245) & m32) h2 (((h ^ (h >> 15)) * 1664525) & m32) (h2 ^ (h2 >> 13)))
 (throw x y s k) ((mash (y * 374761393 + x * 668265263 + s * 2654435761 + 1)) % k)
 (over c m v) (c + m * (v - c))
 (sky-row y st tb mn t) (: hz (st 'hz) h (st 'h) sc (st 'foc / 40.0) xs (tb 'xs)
   qa (tb 'qas) qe (peep (tb 'qes) y 0) up (hz - y)
   ramp (? ((3 * h // 8) < up) 233 ((h // 4) < up) 234 ((h // 8) < up) 235 236)   ; #121212 .. #303030 down to the horizon
   bright (0 = throw qa qe 13 197)                                                  ; #eeeeee a bright star
   star (0 = throw qa qe 7 41)                                                      ; #8a8a8a twinkling to #bcbcbc
   twinkle (0 = ((throw qa qe 11 3) + (t // 3)) % 3)
   starry (over (over ramp bright 255) star (245 + (5 * twinkle)))
   dy (y - mn 1) r (mn 2) g1 (r + (1.5 * sc)) g4 (r + (4.0 * sc))
   ; the moon's layers, on the rows it reaches
   (mooned _) (: dx (xs - mn 0) r2 (dx * dx + dy * dy)
                 sea (0 = throw (floor (dx + 100.0)) (floor (dy + 100.0)) 21 7)
                 (over (over (over starry
                                   (r2 < (g4 * g4)) 237)     ; #3a3a3a the glow, wide
                             (r2 < (g1 * g1)) 238)           ; #444444 ..and close
                       (r2 < (r * r)) (over moon-pen sea sea-pen)))
   (? (abs dy < g4) (mooned ()) starry))
 (sky-at y st tb mn t) (: r (peep (tb 'sky) y ())
   (? (tray? r) r (: r2 (sky-row y st tb mn t) (pin (tb 'sky) y r2, r2))))
 ; a row above the horizon: the sky, a far tree's haze over it, a near tree's black over that
 (top-row y st tb mn t) (: r (peep (tb 'rows) y ())
   (? (tray? r) r
      (: r2 (over (over (sky-at y st tb mn t) (y >= (tb 'tops)) haze-pen) (y >= (tb 'ntops)) tree-pen)
         (pin (tb 'rows) y r2, r2))))
 ; the water's lift, in the world's units: a slow swell, and the rings the player's steps
 ; sent out, each fading as it spreads. x and z are trays, a row of points at once, and
 ; a ring's reach is a mask over them; numbers pass through the same words
 (swell x z t) ((0.10 * sin (1.1 * z + 0.3 * x + 0.20 * t)) + (0.07 * sin (1.7 * x - 0.4 * z + 0.31 * t)))
 (rings-at x z t rings) (:
   (ring a r) (: age (t - r 't) dx (x - r 'x) dz (z - r 'z) d (sqrt (dx * dx + dz * dz))
                 (? (0.0 < age) (a + (d < (0.18 * age)) * 0.25 * exp (-0.25 * d - 0.03 * age) * sin (4.0 * d - 0.72 * age)) a))
   (foldl ring 0.0 rings))
 ; a ring five seconds old is a hundredth of what it was: gone from the list, so the
 ; water stops asking after it
 ring-life 150.0
 ; every water row at once, in trays over the columns: where the row's rays meet the
 ; water, whether that is past the river's edge, and the lift there tilting the sample
 ; by more the nearer it is -- the sample's row and column, and the rings' own lift, for
 ; a crest
 (water-rows st) (: w (st 'w) h (st 'h) hz (st 'hz) foc (st 'foc) t (st 't)
   th (st 'th) sn (sin th) cs (cos th) px (st 'px) pz (st 'pz) rings (st 'rings)
   xs (iota w + 0.0)
   u ((xs - st 'cx) / foc)
   hi (w - 1.0)
   rows {}
   (row y) (? (y < h)
     (: d ((foc * eh) / (y + 0.5 - hz)) g (foc / d)
        wx (px + d * (sn + u * cs)) wz (pz + d * (cs - u * sn))
        bank ((wx > rw) + (wx < -rw))
        rl (rings-at wx wz t rings)
        l (swell wx wz t + rl)
        y2 (y + l * g * 2.0)
        x2 (floor (max 0.0 (min hi (xs + l * g * 0.4))))
        _ (pin rows y [bank y2 x2 rl])
        (row (y + 1))))
   (row hz, rows))
 ; what the water makes of what it mirrors -- its own grey under the forest, a shade
 ; off the bank -- and a ring's crest catching the moon, a step or two lighter
 ; the moon #ffffd7 to #d7af5f, its seas to #af8700, a star to a grey two steps down, the
 ; sky's greys a step down, and the forest and the bank to the water's #121212
 dark {230 179 187 136 238 236 237 235 236 235 235 234 234 234 233 233 16 233 232 233 250 244 245 240 255 247}
 ; ..and a crest: the water's greys two steps up, the moon's gold to #ffd787
 crest {233 235 234 236 235 237 236 238 179 222 136 179 244 250 240 245 247 255 16 233 232 233}
 ; ..the two as trays a pen row indexes
 darks (star-tray [256] (map (i \ peep dark i haze-pen) (jot 256)))
 crests (star-tray [256] (map (i \ peep crest i i) (jot 256)))
 ; a sky row as the water darkens it, kept as asked for
 (dark-at r st tb mn t) (: d (peep (tb 'dark) r ())
   (? (tray? d) d (: d2 (peep darks (sky-at r st tb mn t) haze-pen) (pin (tb 'dark) r d2, d2))))
 ; a water row, off its trays: the mirror's sample, gathered from each darkened sky row
 ; the row's columns reach; the forest's reflection where the sample is under the
 ; treeline; a crest a step lighter; and the bank
 (water-row y st tb mn t) (: hz (st 'hz) row (peep (tb 'water) y ())
   bank (row 0) y2 (row 1) x2 (row 2) rl (row 3)
   yq (min (floor (2 * hz - 1 - y2)) (hz - 1))
   (band r r1 acc) (? (r <= r1)
                      (: m (yq = r)
                         (band (r + 1) r1 (? (aany m) (over acc m (peep (dark-at r st tb mn t) x2 haze-pen)) acc)))
                      acc)
   c (band (amin yq) (amax yq) haze-pen)
   c2 (over c (y2 < peep (tb 'bots) x2 0.0) haze-pen)
   c3 (over c2 (0.06 < rl) (peep crests c2 haze-pen))
   (over c3 (0 < bank) bank-pen))
 ; a frame: two pixel rows a cell, one sgr per change, the rows joined by \r\n with no
 ; newline after the last, so a screen of just enough rows never scrolls. a pixel row is
 ; a tray of pens, the sky's and the trees' above the horizon and the water's below it
 sgrs {}
 (sgr f b) (: k (f * 256 + b) s (sgrs k)
              (string? s ? s (: s2 (esc + "[38;5;" + show f + ";48;5;" + show b + "m") (pin sgrs k s2, s2))))
 (wade-frame st) (: t (st 't) w (st 'w) h (st 'h) hz (st 'hz)
   _ (pin st 'rings (filter (r \ (t - r 't) < ring-life) (st 'rings)))
   tb (wade-tables st) mn (moon-at st)
   j (jug 0)
   (src y) (? (y < hz) (top-row y st tb mn t) (water-row y st tb mn t))
   (row y x f b ts bs) (? (x < w) (: f2 (peep ts x 236) b2 (peep bs x 236)
                                     _ (f2 != f || b2 != b ? (say j (sgr f2 b2)))
                                     _ (say j "▀")
                                     (row y (x + 1) f2 b2 ts bs)))
   (rows y) (? (y < (h // 2)) (row y 0 -1 -1 (src (2 * y)) (src (2 * y + 1)), say j (esc + "[0m"), (? ((y + 1) < (h // 2)) (say j "\r\n")), rows (y + 1)))
   (rows 0, slurp j))
 ; the state: the screen, where the player stands and faces, the horizon's row, the
 ; tick, the rings on the water, and whether they walk on by themselves
 (wade-new w h) {'w w 'h h 'cx (w / 2.0) 'foc (w / 2.0) 'hz (h // 2)
                 'px 0.0 'pz 0.0 'th 0.0 't 0 'rings () 'walk 0}
 ; the screen's shape: w cells across and r rows, two pixels a row, the horizon kept
 ; where it stood in proportion
 (wade-size st w r) (: h (2 * r) hz ((st 'hz) * h // (st 'h))
   (pins st 'w w 'h h 'cx (w / 2.0) 'foc (w / 2.0) 'hz (clamp hz (h // 4) (3 * h // 4))))
 ; a step along the heading, kept in the river; it sends a ring, but not on the heels
 ; of the last one
 (wade-move st mv) (: th (st 'th) t (st 't) rs (st 'rings)
   px2 (clamp (st 'px + mv * sin th) (0.8 - rw) (rw - 0.8)) pz2 (st 'pz + mv * cos th)
   due (? (rs = ()) 1 (6.0 <= (t - peep (cap rs) 't 0.0)))
   r {'x px2 'z pz2 't (t + 0.0)}
   (pins st 'px px2 'pz pz2 'rings (due ? (first-n 5 (r . rs)) rs)))
 ; a key: h l or the arrows turn, k j or up down wade on and back, u n look up and down.
 ; a tty tells of keys pressed and never of keys let go, and it repeats one key at a
 ; time, so a chord cannot be seen: space walks on by itself, and the turns steer it
 (wade-step st k) (: th (st 'th)
   turn (k @ 104 -0.08 -1 -0.08 108 0.08 -2 0.08 0.0)
   mv (k @ 107 0.35 -8 0.35 106 -0.35 -9 -0.35 0.0)
   h (st 'h) tilt (k @ 117 (0 - h // 16) 110 (h // 16) 0)
   (? (turn != 0.0) (pin st 'th (wrap (th + turn)))
      (tilt != 0) (pin st 'hz (clamp (st 'hz + tilt) (h // 4) (3 * h // 4)))
      (mv != 0.0) (wade-move st mv)
      (k = 32) (pin st 'walk ((st 'walk) ? 0 1))
      st))
 ; --- the song: a slendro chime now and then, and a gong under it ---------------------
 ; five near-equal steps to the octave, as a gamelan is tuned, in semitones from middle c
 slendro (map (d \ d * 2.4) ^5)
 song-chunk (song-rate // fps)                          ; a frame's worth
 song-gain 11000.0
 chime-odds 12                                          ; a chime's chance a chunk, in thousandths: one every three seconds or so
 ; the song: its port, a spun die, the frames written, the voices ringing, when the gong
 ; is next due, and how many strikes there have been
 (wade-song-new h st) {'h h 'sb {st} 'fpos 0 'vs () 'gong 0 'struck 0}
 ; one chunk out the port. a chime by the die, its degree and octave off the die too, the
 ; low octave three times in four, ringing long; a gong when it is due, the next some
 ; seconds on. the port is any jug, so the song gates headless
 (wade-song-feed s) (: sb (s 'sb) base (s 'fpos)
   (strike v) (: at (base + roll sb song-chunk)
                 (pins s 'vs (cat (s 'vs) [[at (mkvoice at v song-rate)]]) 'struck (s 'struck + 1)))
   _ (? (roll sb 1000 < chime-odds)
        (strike {'s "chime" 'note (slendro (roll sb 5) - 36 + 12 * ((roll sb 4) = 0))
                 'gain (0.6 + roll sb 40 / 100.0) 'pan (0.2 + roll sb 60 / 100.0) 'legato 5.0}))
   ; the gong is a triangle, not a sine: its odd harmonics are what a small speaker
   ; gives of a note this low
   _ (? (s 'gong <= base)
        (strike {'s "tri" 'note -22.0 'gain 0.9 'pan 0.5 'legato 7.0},
         pin s 'gong (base + song-rate * (8 + roll sb 6))))
   live (filter (p \ p 1 0 >= base) (s 'vs))          ; not finished
   now (filter (p \ p 0 < base + song-chunk) live)    ; ..and already begun
   _ (pins s 'vs live 'fpos (base + song-chunk))
   (say (s 'h) (pack (mixdown (map (p \ p 1) now) base song-chunk) song-chunk song-gain)))
 ; the tty: every key waiting is read each frame and the last one acts, so a held key
 ; moves once a frame and stops when it is let go; the horn is fed until a lead stands
 ; queued, ahead of anything else the loop does, the lead paced by the frame gap (rove's
 ; pacer); a frame's rest is what the tick has left after the painting
 (wade-run _) (: _ (raw 1)
   _ (say out (esc + "[?1049h" + esc + "[?25l" + esc + "[2J"))
   ; the terminal's size, and 80 by 24 off a tty that will not say; asked again every
   ; frame, so a resized window is painted whole
   (shape _) (: ws (tty 1) [(two? ws && 19 < <>ws ? <>ws 80) (two? ws && 7 < <ws ? <ws 24)])
   sh0 (shape ())
   st (wade-new (sh0 0) (2 * sh0 1))
   (resize _) (: sh (shape ())
                 (? ((sh 0 != st 'w) || (2 * sh 1 != st 'h))
                    (wade-size st (sh 0) (sh 1), say out (esc + "[2J"))))
   tick (1000 // fps)
   hn (: h (horn song-rate 2) (? (nom? h) () h))
   sng (? hn (wade-song-new hn (wheel (clock 0))) ())
   pace (pacer ())
   (feed _) (: l (song-lead-of (pace! pace))
               (fill _) (? (sng && horn-lag hn < l) (wade-song-feed sng, fill ()))
               (fill ()))
   (keys last) (? (cue? 0) (: k (edkey in) (? ((k = 113) || (k = 27)) 'quit (keys ((charm? k) ? k last)))) last)
   (go _) (: t0 (clock 0)
             _ (feed ())
             _ (resize ())
             _ (say out (esc + "[H" + wade-frame st), flush out)
             k (keys ())
             _ (pin st 't (st 't + 1))
             (? (k = 'quit) ()
                (: _ (? (charm? k) (wade-step st k))
                   _ (? (st 'walk) (wade-move st 0.25))
                   spent (clock 0 - t0)
                   _ (? (spent < tick) (rest (tick - spent)))
                   (go ()))))
   _ (go ())
   _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"), flush out)
   _ (? hn (: _ (flush hn) (close hn)) ())
   _ (drain-keys ())
   _ (raw 0)
   0)
 wade-usage "usage: love wade   (h l turn, k j wade, u n look, space walks; q or esc leaves)"
 (wade-main as) (as @ () (wade-run ())
                      (say err ("wade: " + wade-usage + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'wade (udoor 'wade wade-main wade-usage 1 1)))
) ; module wade
