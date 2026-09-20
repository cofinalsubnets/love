; wade -- a night river in half blocks, first person: the sky, a moon and stars, black
; forest on either bank, and all of it in the water, rippled where the player wades.
;
; the screen is 80 by 48 pixels, two to a cell: the upper half block, the top pixel in
; the pen and the bottom in the ground. nothing is stored: a tree is a hash of its bank,
; its row back from the water and its place along the river, which loops; a star is a
; hash of the bearing and height its direction falls in, so both keep their places as
; the player turns and wades. the water is a mirror in the world: a pixel's ray meets
; the water, and the swell and the rings the player's steps sent out tilt what it shows,
; by more the nearer, which is what draws the moon into a path.
;
; the scene is pure love -- wade-new, wade-step, wade-move and wade-frame are state in
; and state out, gated headless by test/host/wade.l; only wade-run ties the tty.
;
; run: love wade    h l or the arrows turn, k j or up down wade on and back, u n look up
;                   and down, space walks on until pressed again; q or esc leaves
(module (wade wade-run wade-main wade-new wade-step wade-move wade-frame wade-tables
         moon-at swell rings-at tree-of foc rw sp loop fps)
(borrow 'rove)
(:
 esc (string 27)
 w 80 h 48 foc 40.0                   ; the pixels, and the focal length
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
 (moon-at th hz) (: rel (wrap (maz - th)) c (cos rel)
   (? (abs rel < 1.3) [(40.0 + foc * tn rel) (hz - (foc * tn mel) / c) ((foc * tn mang) / c)]
      [-999.0 -999.0 0.0]))
 ; a tree by its bank s (-1 or 1), its row r back from the water and its index k along
 ; the river: where it stands, how tall and wide, and whether its crown is round
 (tree-of k s r) (: kk (((k % loop) + loop) % loop) seed (s + 2 + 5 * r)
   {'z (k * sp + (dice kk seed 3 100) / 100.0 * sp)
    'x (s * (rw + 0.8 + 2.2 * r + (dice kk seed 5 100) / 100.0 * 2.0))
    'ht (5.0 + (dice kk seed 7 100) / 100.0 * 6.0)
    'wd (2.5 + (dice kk seed 9 100) / 100.0 * 2.5)
    'round ((dice kk seed 4 3) = 0)})
 ; the frame's tables: a column's bearing cell, the treeline's top row for all trees and
 ; for the near ones alone, the reflection's bottom row; a row's height cell, for rows
 ; well above the screen too, since the water mirrors sky that is off the top
 (fresh th hz) (: tb {'tops {} 'ntops {} 'bots {} 'qas {} 'qes {}}
   (col x) (? (x < w) (pin (tb 'tops) x 999.0, pin (tb 'ntops) x 999.0, pin (tb 'bots) x (hz - 1.0),
                       pin (tb 'qas) x (((flo ((th + atan ((x - 40.0) / foc)) / (2.0 * pi) * 256.0)) % 256 + 256) % 256),
                       col (x + 1)))
   (row y) (? (y < hz) (pin (tb 'qes) y (flo (atan ((hz - y) / foc) * foc)), row (y + 1)))
   (col 0, row (0 - h - 12), tb))
 ; the trees within sight, each laid into the columns it covers: a conifer or a round
 ; crown, its base at the bank and its mirror hanging under it. the row at the water
 ; runs to the horizon, the two behind it half as far
 (lay-trees st tb) (: px (st 'px) pz (st 'pz) th (st 'th) hz (st 'hz) sn (sin th) cs (cos th)
   (one k s r) (: tr (tree-of k s r)
     dx (tr 'x - px) dz (tr 'z - pz)
     d (dx * sn + dz * cs) lat (dx * cs - dz * sn)
     (? (0.5 < d)
        (: u (lat / d)
           (? (abs u < 1.5)
              (: cx (40.0 + foc * u) hw ((foc * tr 'wd) / (2.0 * d)) hg ((foc * tr 'ht) / d) by (hz + (foc * eh) / d)
                 tops (d < near ? (tb 'ntops) (tb 'tops)) bots (tb 'bots)
                 xa (clamp (flo (cx - hw)) 0 (w - 1)) xb (clamp (flo (cx + hw)) 0 (w - 1))
                 (col x) (? (x <= xb) (: q ((abs (x - cx)) / hw)
                                         hx (q < 1.0 ? (hg * (? (tr 'round) (sqrt (1.0 - q * q)) (1.0 - q))) 0.0)
                                         _ (pin tops x (min2 (tops x) (by - hx)))
                                         _ (pin bots x (max2 (bots x) (by + hx)))
                                         (col (x + 1))))
                 (col xa))))))
   (go k k1 r) (? (k <= k1) (one k -1 r, one k 1 r, go (k + 1) k1 r))
   (span r reach) (go (flo ((pz - reach) / sp)) (flo ((pz + reach) / sp)) r)
   (span 0 far, span 1 (far / 2.0), span 2 (far / 2.0), tb))
 (wade-tables st) (lay-trees st (fresh (st 'th) (st 'hz)))
 ; the sky at a pixel: a grey ramp up from the horizon, the moon's glow, the disc with
 ; its seas, the stars
 (sky x y tb mn hz t) (:
   (star _) (: qa (peep (tb 'qas) x 0) qe (peep (tb 'qes) y 0) up (hz - y)
               (? (0 = dice qa qe 7 41) ((((dice qa qe 11 3) + (t // 3)) % 3 = 0) ? 250 245)   ; #bcbcbc twinkling to #8a8a8a
                  (0 = dice qa qe 13 197) 255                                                  ; #eeeeee a bright one
                  (18 < up) 233 (12 < up) 234 (6 < up) 235 236))                              ; #121212 .. #303030 down to the horizon
   dx (x - mn 0) dy (y - mn 1) r (mn 2) r2 (dx * dx + dy * dy)
   (? (r2 < (r * r)) ((0 = dice (flo dx + 100) (flo dy + 100) 21 7) ? sea-pen moon-pen)
      (r2 < ((r + 1.5) * (r + 1.5))) 238   ; #444444 the glow
      (r2 < ((r + 4.0) * (r + 4.0))) 237   ; #3a3a3a ..and wider
      (star ())))
 ; the water's lift, in the world's units: a slow swell, and the rings the player's steps
 ; sent out, each fading as it spreads
 (swell x z t) ((0.10 * sin (1.1 * z + 0.3 * x + 0.20 * t)) + (0.07 * sin (1.7 * x - 0.4 * z + 0.31 * t)))
 (rings-at x z t rings) (:
   (ring r) (: age (t - r 't) dx (x - r 'x) dz (z - r 'z) d (sqrt (dx * dx + dz * dz))
               (? ((0.0 < age) && (d < (0.18 * age))) (0.25 * exp (-0.25 * d - 0.03 * age) * sin (4.0 * d - 0.72 * age)) 0.0))
   (net (map ring rings)))
 ; what the water makes of what it mirrors -- its own grey under the forest, a shade
 ; off the bank -- and a ring's crest catching the moon, a step or two lighter
 ; the moon #ffffd7 to #d7af5f, its seas to #af8700, a star to a grey two steps down, the
 ; sky's greys a step down, and the forest and the bank to the water's #121212
 dark {230 179 187 136 238 236 237 235 236 235 235 234 234 234 233 233 16 233 232 233 250 244 245 240 255 247}
 ; ..and a crest: the water's greys two steps up, the moon's gold to #ffd787
 crest {233 235 234 236 235 237 236 238 179 222 136 179 244 250 240 245 247 255 16 233 232 233}
 ; a water pixel: where its ray meets the water, the bank if that is past the river's
 ; edge, else the mirror, the lift there tilting the sample by more the nearer it is
 (water x y st tb mn t) (: th (st 'th) hz (st 'hz) sn (sin th) cs (cos th)
   d ((foc * eh) / (y + 0.5 - hz))
   u ((x - 40.0) / foc)
   wx (st 'px + d * (sn + u * cs)) wz (st 'pz + d * (cs - u * sn))
   (? (rw < abs wx) bank-pen
      (: rl (rings-at wx wz t (st 'rings))
         l (swell wx wz t + rl)
         g (foc / d)
         y2 (y + l * g * 2.0) x2 (clamp (flo (x + l * g * 0.4)) 0 (w - 1))
         c (? (y2 < peep (tb 'bots) x2 0.0) haze-pen
              (peep dark (sky x2 (min2 (flo (2 * hz - 1 - y2)) (hz - 1)) tb mn hz t) haze-pen))
         ((0.06 < rl) ? (peep crest c c) c))))
 ; a pixel above the horizon is a near tree, a far one in haze, or the sky
 (pix x y st tb mn t) (: hz (st 'hz)
   (? (y < hz) (? (y >= peep (tb 'ntops) x 999.0) tree-pen (y >= peep (tb 'tops) x 999.0) haze-pen (sky x y tb mn hz t))
      (water x y st tb mn t)))
 ; a frame: two pixel rows a cell, one sgr per change, the rows joined by \r\n with no
 ; newline after the last, so a screen of just enough rows never scrolls
 sgrs {}
 (sgr f b) (: k (f * 256 + b) s (sgrs k)
              (string? s ? s (: s2 (esc + "[38;5;" + show f + ";48;5;" + show b + "m") (pin sgrs k s2, s2))))
 (wade-frame st) (: t (st 't) th (st 'th) hz (st 'hz) tb (wade-tables st) mn (moon-at th hz)
   j (jug 0)
   (row y x f b) (? (x < w) (: f2 (pix x (2 * y) st tb mn t) b2 (pix x (2 * y + 1) st tb mn t)
                               _ (f2 != f || b2 != b ? (say j (sgr f2 b2)))
                               _ (say j "▀")
                               (row y (x + 1) f2 b2)))
   (rows y) (? (y < (h // 2)) (row y 0 -1 -1, say j (esc + "[0m"), (? ((y + 1) < (h // 2)) (say j "\r\n")), rows (y + 1)))
   (rows 0, slurp j))
 ; the state: where the player stands and faces, the horizon's row, the tick, the rings
 ; on the water, and whether they walk on by themselves
 (wade-new _) {'px 0.0 'pz 0.0 'th 0.0 'hz 24 't 0 'rings () 'walk 0}
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
   tilt (k @ 117 -3 110 3 0)
   (? (turn != 0.0) (pin st 'th (wrap (th + turn)))
      (tilt != 0) (pin st 'hz (clamp (st 'hz + tilt) 12 36))
      (mv != 0.0) (wade-move st mv)
      (k = 32) (pin st 'walk ((st 'walk) ? 0 1))
      st))
 ; the tty: every key waiting is read each frame and the last one acts, so a held key
 ; moves once a frame and stops when it is let go; a frame's rest is what the tick has
 ; left after the painting
 (wade-run _) (: _ (raw 1)
   _ (say out (esc + "[?1049h" + esc + "[?25l" + esc + "[2J"))
   st (wade-new ())
   tick (1000 // fps)
   (keys last) (? (cue? 0) (: k (edkey in) (? ((k = 113) || (k = 27)) 'quit (keys ((charm? k) ? k last)))) last)
   (go _) (: t0 (clock 0)
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
   _ (drain-keys ())
   _ (raw 0)
   0)
 wade-usage "usage: love wade   (h l turn, k j wade, u n look, space walks; q or esc leaves)"
 (wade-main as) (as @ () (wade-run ())
                      (say err ("wade: " + wade-usage + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'wade (udoor 'wade wade-main wade-usage 1 1)))
) ; module wade
