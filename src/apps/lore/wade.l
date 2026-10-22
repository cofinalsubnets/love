; wade -- a night river, first person: sky, moon and stars, black forest on both banks, all of
; it mirrored in the water and rippled where the player wades. the moon goes where the wading
; takes it, arcing down to the horizon and contracting into the lamp of a lamppost in the
; river; the level ends at its foot and hands on to the apartment.
; two pixels to a cell; the view is ninety degrees wide whatever the width. nothing is
; stored: trees hash their bank, row and place along the looping river, stars their bearing
; and height cells, so both hold still as the player moves. the water mirrors: each pixel's
; ray meets it, tilted by the swell and the step rings, more the nearer.
; wade-new, wade-step, wade-move and wade-frame are pure; only wade-walk and wade-run touch
; the tty and the horn. HORN=none plays silent.
(module (wade wade-run wade-walk wade-main wade-new wade-step wade-move wade-frame wade-tables
         wade-size wade-song-new wade-song-feed moon-at swell rings-at tree-of rw sp loop fps
         slendro song-chunk arc-z morph-z lamp-z lamp-near done-ms settle-ms wade-aim wade-settle
         texts texts-at)
(borrow 'rove)
(borrow 'view)                          ; the screen, its rays, the pens
(borrow 'flicker)                       ; the flame's breath
(borrow 'walk)                          ; the rail
(borrow 'gamelan)                       ; the song
(borrow 'posix)    ; close, for the horn
(:
 eh 1.2 rw 5.0                        ; the eye above the water, waist deep; the river's half width
 sp 3.0 loop 64                       ; a tree every so far along a bank; the bank repeats
 far 150.0 near 35.0                  ; sight along a bank; a tree nearer than near is black, past it haze
 fps 30
 ; the pens, in the 256-colour palette: 16 + 36r + 6g + b in the 6x6x6 cube (levels 0 95 135
 ; 175 215 255), and greys 232 + n = #vvvvvv with v = 8 + 10n
 moon-pen 230 sea-pen 187             ; #ffffd7 the disc, #d7d7af its seas
 glass-pen 179 heart-pen 231          ; #d7af5f the lantern's glass; the flame in it is the moon's pale, its heart #ffffff
 tree-pen 16 haze-pen 233             ; #000000 a near tree, #121212 a far one
 bank-pen 232                         ; #080808 the bank, a shade under the water's #121212
 (tn a) (sin a / cos a)
 ; the moon's journey by how far the player has waded: over arc-z it arcs from high right to
 ; dead ahead on the horizon, over morph-z it contracts into the lamp of the lamppost, then the
 ; lamppost is a thing in the world
 arc-z 90.0 morph-z 30.0              ; the stretch the moon arcs over, and the one it contracts over
 lamp-z 160.0 lamp-h 3.2 lamp-r 0.45  ; where the post stands, and the lamp's height and radius
 post-w 0.12 lamp-near 3.0            ; the post's half width, and how near its foot is arrived
 ; the lantern, in world units about the lamp's centre: the glass's half width and height, a
 ; dark rim, and a roof that wide at its eaves and that tall to its peak
 lan-w 0.4 lan-h 0.7 lan-rim 0.08 lan-eave 0.6 lan-roof 0.35
 lan-taper 0.4                        ; ..and the glass and its rim this much narrower at the bottom than the top
 done-ms 1000                         ; at the lamppost's foot: this long looking around, then the level is over
 ; the words: [start end text], shown while the player is between start and end down the
 ; river; text-row rows above the middle (below for negative), on the average of the pixels
 ; it covers; two at once stack upward
 texts [[10.0 20.0 "found the river again"]]
 text-pen 230 text-row -3
 (texts-at pz) (map (e \ e 2) (filter (e \ e 0 <= pz < e 1) texts))
 maz 0.5 mel 0.36 mang 0.14           ; the moon's bearing and height at the start, and its angular radius
 (lerp a b v) (a + v * (b - a))
 ; what is on the screen: [cx cy r foot pw v] -- the disc's centre and radius, the post's foot
 ; row and half width (none while a moon), v 0 a moon to 1 a lamp; off-screen when behind
 off-screen [-999.0 -999.0 0.0 -999.0 0.0 0.0]
 (moon-at st) (: th (st 'th) hz (st 'hz) foc (st 'foc) cx0 (st 'cx) px (st 'px) pz (st 'pz)
   u (clamp (pz / arc-z) 0.0 1.0)
   v (clamp ((pz - arc-z) / morph-z) 0.0 1.0)
   rel (wrap (maz * (1.0 - u) - th)) c (cos rel) el (mel * cos (u * pi / 2.0))
   moon (abs rel < 1.3 ? [(cx0 + foc * tn rel) (hz - foc * tn el / c) (foc * tn mang / c) (hz - foc * tn el / c) 0.0 0.0]
           off-screen)
   dz (lamp-z - pz) dist (sqrt (2 px + 2 dz))
   rl (wrap (atan2 (0.0 - px) dz - th)) dep (dist * cos rl)
   lamp (abs rl < 1.3 && 0.5 < dep ?
           [(cx0 + foc * tn rl) (hz - (foc * (lamp-h - eh)) / dep) (foc * lamp-r / dep)
            (hz + foc * eh / dep) (foc * post-w / dep) 1.0]
           off-screen)
   (? (v <= 0.0) moon (1.0 <= v) lamp
      (moon 0 < -900.0 || lamp 0 < -900.0) off-screen
      (map (i \ lerp (moon i) (lamp i) v) ^6)))
 ; a tree by its bank s (-1 or 1), row r back from the water and index k along the river;
 ; each of the loop's places is hashed once and kept
 trees {}
 (tree-of k s r) (: kk ((k % loop + loop) % loop) key (kk * 8 + r * 2 + (0 < s))
   b (trees key)
   b2 (two? b ? b
         (: seed (s + 2 + 5 * r)
            b3 [(dice kk seed 3 100 / 100.0 * sp)
                (s * (rw + 0.8 + 2.2 * r + dice kk seed 5 100 / 100.0 * 2.0))
                (5.0 + dice kk seed 7 100 / 100.0 * 6.0)
                (2.5 + dice kk seed 9 100 / 100.0 * 2.5)
                (dice kk seed 4 3 = 0)]
            (pin trees key b3, b3)))
   {'z (k * sp + b2 0) 'x (b2 1) 'ht (b2 2) 'wd (b2 3) 'round (b2 4)})
 ; the frame's tables: column indices and bearing cells; treeline tops (all and near trees)
 ; and the reflection's bottoms, tablets while laid and trays after; height cells for rows
 ; well above the screen too, since the water mirrors sky off the top; sky rows kept as asked
 (fresh st) (: w (st 'w) h (st 'h) hz (st 'hz) th (st 'th) foc (st 'foc) cx (st 'cx)
   xs (iota w)
   tb {'xs xs 'tops {} 'ntops {} 'bots {} 'qes {} 'sky {} 'dark {} 'rows {}
       'qas ((floor ((th + atan ((xs - cx) / foc)) / tau * 256.0) % 256 + 256) % 256)}
   (row y) (y < hz ? (pin (tb 'qes) y (flo (atan ((hz - y) / foc) * foc)), row (y + 1)))
   (row (-h - 12), tb))
 ; the trees within sight laid into the columns they cover, with their mirrors; the row at
 ; the water seen to far, the two behind it half as far
 (lay-trees st tb) (: px (st 'px) pz (st 'pz) th (st 'th) hz (st 'hz) sn (sin th) cs (cos th)
   w (st 'w) foc (st 'foc) cx0 (st 'cx)
   (one k s r) (: tr (tree-of k s r)
     dx (tr 'x - px) dz (tr 'z - pz)
     d (dx * sn + dz * cs) lat (dx * cs - dz * sn)
     (0.5 < d ?
        (lat / d @ u
           (abs u < 1.5 ?
              (: cx (cx0 + foc * u) hw (foc * tr 'wd / (2.0 * d)) hg (foc * tr 'ht / d) by (hz + foc * eh / d)
                 tops (tb (d < near ? 'ntops 'tops)) bots (tb 'bots)
                 xa (clamp (flo (cx - hw)) 0 (w - 1)) xb (clamp (flo (cx + hw)) 0 (w - 1))
                 (col x) (x <= xb ? (: q (abs (x - cx) / hw)
                                       hx (q < 1.0 ? (hg * (tr 'round ? (sqrt (1.0 - 2 q)) (1.0 - q))) 0.0)
                                       (pin tops x (min2 (peep tops x 999.0) (by - hx)),
                                        pin bots x (max2 (peep bots x (hz - 1.0)) (by + hx)),
                                        col (x + 1))))
                 (col xa))))))
   (go k k1 r) (k <= k1 ? (one k -1 r, one k 1 r, go (k + 1) k1 r))
   (span r reach) (go (flo ((pz - reach) / sp)) (flo ((pz + reach) / sp)) r)
   (tray-of tab d) (gem-tray [w] (map (x \ peep tab x d) ^w))
   (span 0 far, span 1 (far / 2.0), span 2 (far / 2.0),
    pins tb 'tops (tray-of (tb 'tops) 999.0) 'ntops (tray-of (tb 'ntops) 999.0) 'bots (tray-of (tb 'bots) (hz - 1.0))))
 (wade-tables st) (lay-trees st (fresh st) @ tb (pin tb 'water (water-rows st)))
 ; the sky a row at a time in trays: a grey ramp up from the horizon, stars hashed off the
 ; bearing and height cells, the moon's glow and its disc with seas, each over the last
 (sky-row y st tb mn t) (: hz (st 'hz) h (st 'h) sc (st 'foc / 40.0) xs (tb 'xs)
   qa (tb 'qas) qe (peep (tb 'qes) y 0) up (hz - y)
   ramp (? (3 * h // 8 < up) 233 (h // 4 < up) 234 (h // 8 < up) 235 236)   ; #121212 .. #303030 down to the horizon
   bright (0 = throw qa qe 13 197)                                                  ; #eeeeee a bright star
   star (0 = throw qa qe 7 41)                                                      ; #8a8a8a twinkling to #bcbcbc
   twinkle (0 = (throw qa qe 11 3 + t // 3) % 3)
   starry (over (over ramp bright 255) star (245 + 5 * twinkle))
   dy (y - mn 1) r (mn 2) v (mn 5) lit (1.0 <= v)
   g1 (r + 1.5 * sc) g4 (r + 4.0 * sc)                                          ; the glow, the lamp's as much as the moon's
   pw (mn 4) hw (max2 0.5 pw)                                                       ; the post, a pixel at least
   ; the lantern in pixels: glass, rim, eaves and roof each at least a pixel so the shape reads
   ; far off -- but only once the glass is wider than a pixel; a lone point of light is unhoused
   sz (r / lamp-r)                                                                  ; a world unit in pixels
   gw (max2 0.5 (lan-w * sz)) gh (max2 0.5 (lan-h / 2.0 * sz))
   housed (1.25 <= lan-w * sz)                                                     ; the glass three wide at the top
   rw (max2 (gw + 1.0) ((lan-w + lan-rim) * sz)) rh (max2 (gh + 1.0) ((lan-h / 2.0 + lan-rim) * sz))
   ev (max2 (rw + 1.0) (lan-eave * sz)) rf (max2 1.0 (lan-roof * sz))
   reach (rh + rf)                                                                  ; the roof's peak above the lamp's centre
   ; the moon's layers on the rows it reaches: glow, the black post, the disc -- or as the lamp,
   ; the lantern: roof, rim, tapering glass, a swaying flame and its white heart
   (lantern c dx) (: x2 (2 dx) ady (abs dy)
     tp (1.0 - lan-taper * clamp ((dy + gh) / (2.0 * gh + 0.001)) 0.0 1.0)  ; down the glass: 1 at the top
     gwt (gw * tp) rwt (max2 (gwt + 1.0) ((lan-w + lan-rim) * sz * tp))
     q ((-dy - rh) / rf)                       ; up the roof: 0 at the eaves, 1 at the peak
     ew (max2 0.5 (ev * (1.0 - q)))
     roofed (housed ? (over c ((0.0 <= q) * (q <= 1.0) * (x2 <= ew * ew)) tree-pen) c)
     rimmed (housed ? (over roofed ((x2 <= rwt * rwt) * (ady <= rh)) haze-pen) roofed)
     glass ((x2 <= gwt * gwt) * (ady <= gh))
     glassed (over rimmed glass glass-pen)
     fh (1.5 * gh * flicker-pulse t 0.85 0.15 1.3 0.0)  ; the flame's height, off the floor to its tip
     p ((0.6 * gh - dy) / fh)                         ; up the flame: 0 at its foot, 1 at its tip
     sx (p * gw * (0.3 * sin (0.5 * t) + 0.15 * sin (1.9 * t)))   ; the sway, all of it at the tip
     fw (max2 0.5 (1.43 * gw * (1.0 - p) * sqrt (max2 0.0 p)))     ; the teardrop, widest a third of the way up
     f2 ((dx - sx) * (dx - sx))
     flamed (over glassed (glass * (0.0 <= p) * (p <= 1.0) * (f2 <= fw * fw)) moon-pen)
     hw2 (max2 0.5 (0.45 * fw))
     (over flamed (housed * (1.0 <= fw) * glass * (0.05 <= p) * (p <= 0.65) * (f2 <= 2 hw2)) heart-pen))   ; ..where the flame is three wide around it
   (mooned _) (: dx (xs - mn 0) r2 (2 dx + 2 dy)
                 sea (0 = throw (floor (dx + 100.0)) (floor (dy + 100.0)) 21 7)
                 glowed (over (over starry (r2 < g4 * g4) 237)     ; #3a3a3a the glow, wide
                              (r2 < g1 * g1) 238)                  ; #444444 ..and close
                 posted (over glowed ((0.0 < pw) * (0.0 < dy) * (2 dx <= 2 hw)) tree-pen)
                 (lit ? (lantern posted dx)
                    (over posted (r2 < r * r) (over moon-pen sea sea-pen))))
   (abs dy < g4 || lit && abs dy <= reach || 0.0 < pw && 0.0 < dy ? (mooned ()) starry))
 (sky-at y st tb mn t) (tb 'sky y @ r
   (tray? r ? r (sky-row y st tb mn t @ r2 (pin (tb 'sky) y r2, r2))))
 ; a row above the horizon: the sky, a far tree's haze over it, a near tree's black over that
 (top-row y st tb mn t) (tb 'rows y @ r
   (tray? r ? r
      (over (over (sky-at y st tb mn t) (y >= tb 'tops) haze-pen) (y >= tb 'ntops) tree-pen @ r2
         (pin (tb 'rows) y r2, r2))))
 ; the water's lift, in world units: a slow swell and the fading step rings. x and z may be
 ; trays, a ring's reach a mask over them
 (swell x z t) (0.10 * sin (1.1 * z + 0.3 * x + 0.20 * t) + 0.07 * sin (1.7 * x - 0.4 * z + 0.31 * t))
 (rings-at x z t rings) (:
   (ring a r) (: age (t - r 't) dx (x - r 'x) dz (z - r 'z) d (sqrt (2 dx + 2 dz))
                 (0.0 < age ? (a + (d < 0.18 * age) * 0.25 * exp (-0.25 * d - 0.03 * age) * sin (4.0 * d - 0.72 * age)) a))
   (foldl ring 0.0 rings))
 ; a ring five seconds old is a hundredth of what it was, and dropped
 ring-life 150.0
 ; every water row at once: where each ray meets the water, whether past the river's edge,
 ; and the lift tilting the sample more the nearer -- [bank row column ring-lift]
 (water-rows st) (: w (st 'w) h (st 'h) hz (st 'hz) foc (st 'foc) t (st 't)
   px (st 'px) pz (st 'pz) rings (st 'rings)
   xs (iota w + 0.0)
   rs (view-rays st) vx (rs 0) vz (rs 1)
   hi (w - 1.0)
   rows {}
   (row y) (y < h ?
     (: d (foc * eh / (y + 0.5 - hz)) g (foc / d)
        wx (px + d * vx) wz (pz + d * vz)
        bank ((wx > rw) + (wx < -rw))
        rl (rings-at wx wz t rings)
        l (swell wx wz t + rl)
        y2 (y + l * g * 2.0)
        x2 (floor (max 0.0 (min hi (xs + l * g * 0.4))))
        (pin rows y [bank y2 x2 rl],
         row (y + 1))))
   (row hz, rows))
 ; what the water makes of what it mirrors: the moon to gold, the stars and sky a step or two
 ; down, the forest and bank to the water's #121212
 dark {230 179 187 136 238 236 237 235 236 235 235 234 234 234 233 233 16 233 232 233 250 244 245 240 255 247
       179 136 231 179}                                   ; the lantern's glass to #af8700, the flame's heart as the moon
 ; ..and a crest: the water's greys two steps up, the moon's gold to #ffd787
 crest {233 235 234 236 235 237 236 238 179 222 136 179 244 250 240 245 247 255 16 233 232 233}
 ; ..the two as trays a pen row indexes
 darks (star-tray [256] (map (i \ peep dark i haze-pen) ^256))
 crests (star-tray [256] (map (i \ peep crest i i) ^256))
 ; a sky row as the water darkens it, kept as asked for
 (dark-at r st tb mn t) (tb 'dark r @ d
   (tray? d ? d (peep darks (sky-at r st tb mn t) haze-pen @ d2 (pin (tb 'dark) r d2, d2))))
 ; a water row: the mirror's sample from each darkened sky row its columns reach, the forest's
 ; reflection under the treeline, a crest a step lighter, and the bank
 (water-row y st tb mn t) (: hz (st 'hz) row (tb 'water y)
   bank (row 0) y2 (row 1) x2 (row 2) rl (row 3)
   yq (min (floor (2 * hz - 1 - y2)) (hz - 1))
   (band r r1 acc) (r <= r1 ?
                      (yq = r @ m
                       (band (r + 1) r1 (aany m ? (over acc m (peep (dark-at r st tb mn t) x2 haze-pen)) acc)))
                      acc)
   c (band (amin yq) (amax yq) haze-pen)
   c2 (over c (y2 < peep (tb 'bots) x2 0.0) haze-pen)
   c3 (over c2 (0.06 < rl) (peep crests c2 haze-pen))
   c4 (over c3 (0 < bank) bank-pen)
   pw (mn 4) hw (max2 0.5 pw) dx (tb 'xs - mn 0)
   (over c4 ((0.0 < pw) * (y < mn 3) * (2 dx <= 2 hw)) tree-pen))
 ; a frame, as view lays it: a pixel row is a tray of pens, the sky's and the trees' above
 ; the horizon and the water's below it
 (wade-frame st) (: t (st 't) w (st 'w) h (st 'h) hz (st 'hz)
   _ (pin st 'rings (filter (r \ t - r 't < ring-life) (st 'rings)))
   tb (wade-tables st) mn (moon-at st)
   (src y) (y < hz ? (top-row y st tb mn t) (water-row y st tb mn t))
   ; the words, each a band [x0 text pen ground] on its cell row, the ground the average of
   ; the two pixel rows under it
   ws (texts-at (st 'pz))
   (band i) (: s (snip (ws i) 0 (min2 #(ws i) w)) ty (h // 4 - text-row - i) x0 ((w - #s) // 2)
               ts (src (2 * ty)) bs (src (2 * ty + 1))
               (add a x) (: p (pen-rgb (peep ts x 236)) q (pen-rgb (peep bs x 236))
                            [(a 0 + p 0 + q 0) (a 1 + p 1 + q 1) (a 2 + p 2 + q 2)])
               sum (foldl add [0 0 0] (map (+ x0) ^#s)) n (2 * #s)
               [x0 s text-pen (rgb-pen (sum 0 // n) (sum 1 // n) (sum 2 // n))])
   bands (foldl (tab \ i \ (h // 4 - text-row - i @ ty (0 <= ty < h // 2 ? (pin tab ty (band i)) tab))) {} ^#ws)
   (view-frame w h src bands))
 ; the state: where the player stands and faces, the horizon's row, the tick, the rings, and
 ; whether they walk on by themselves
 (wade-new w h) (view! {'px 0.0 'pz 0.0 'th 0.0 't 0 'rings () 'walk 0 'done 0} w h (h // 2))
 ; the screen's shape: w cells across and r rows, the horizon off the top and bottom quarter
 (wade-size st w r) (view-size st w r 4)
 ; a step on down the river, no further than the lamppost's foot, where the level is done;
 ; it sends a ring, but not on the heels of the last
 (wade-move st mv) (: t (st 't) rs (st 'rings) px (st 'px)
   pz2 (min2 (st 'pz + mv) (lamp-z - lamp-near))
   due (rs @ () 1 (6.0 <= t - peep <rs 't 0.0))
   r {'x px 'z pz2 't (t + 0.0)}
   (st 'done ? st
      ((pins st 'pz pz2 'rings (due ? (first-n 5 (r . rs)) rs)),
       lamp-z - pz2 <= lamp-near ? (pins st 'done 1 'walk 0 'th0 (st 'th) 'hz0 (st 'hz)) st)))

 ; turns stay within facing of ahead. a tty reports presses, never releases, and repeats one
 ; key at a time, so a chord cannot be seen: space walks on by itself, and the turns steer it
 facing (pi / 3.0)
 (wade-step st a) (walk-rail st a facing wade-move)     ; arrived, the view is the level's
 ; --- arrived: turn to the lamp and pitch down until the flame's reflection holds the middle
 ; of the screen, eased over settle-ms; the level is over done-ms after. the reflection hangs
 ; as far under the horizon as flame plus eye are over the water ---
 settle-ms 1500
 (wade-aim st) (: px (st 'px) dz (lamp-z - st 'pz) dist (sqrt (2 px + 2 dz))
                  th (clamp (wrap (atan2 -px dz)) -facing facing)
                  hz (st 'h // 2 - int (st 'foc * (lamp-h + eh) / dist))
                  [th (clamp hz (1 - st 'h) (st 'h - 1))])
 (wade-settle st s) (: e (2 s * (3.0 - 2.0 * s)) aim (wade-aim st)
                       th0 (peep st 'th0 (st 'th)) hz0 (peep st 'hz0 (st 'hz))
                       (pins st 'th (th0 + (aim 0 - th0) * e)
                                'hz (floor (hz0 + (aim 1 - hz0) * e + 0.5))))   ; to the nearest row, above the screen too
 ; --- the song: a slendro chime now and then, and a gong under it ---------------------
 ; five near-equal steps to the octave, as a gamelan is tuned, in semitones from middle c
 slendro (map (* 2.4) ^5)
 song-chunk (song-rate // fps)                          ; a frame's worth
 ; ..three octaves down, the high one a time in four, ringing long; the gong a triangle wave,
 ; since a small speaker gives only the odd harmonics of a note this low
 tune {'scale slendro 'down -36 'high 4 'gain 0.6 'odds 12 'gong -22.0 'gong-gain 0.9 'gong-legato 7.0 'gong-every 8}
 (wade-song-new h st) (gamelan-new h st)
 (wade-song-feed s) (gamelan-feed s tune)
 ; --- the walk, on view's loop: walking on by itself, or at the lamppost settling on the lamp
 ; over settle-ms, then the apartment ---
 (wade-walk _) (view-walk {'new wade-new 'size wade-size 'frame wade-frame 'key wade-step 'fps fps
                           'binds (view-bind view-binds walk-binds) 'listed walk-listed
                           'tick (st \ (? (st 'done-at) (clock (st 'done-at) / (1.0 * settle-ms) @ s
                                                            (wade-settle st (1.0 < s ? 1.0 s)))
                                          (st 'walk) (wade-move st 0.25)))
                           'song (view-song wade-song-new wade-song-feed)
                           'linger (settle-ms + done-ms) 'next ['apartment 'apartment-walk]})
 (wade-run _) (view-run wade-walk)
 wade-usage "usage: love play wade   (h l turn, k j wade, u n look, space walks on to the lamppost; ? the keys, q or esc leaves)"
 (wade-main as) (view-main "wade" wade-usage (as \ view-words as []) wade-run as)
 _ ((cite 'lore 'lore-enlist) 'wade (udoor 'wade wade-main wade-usage 1 1)))
) ; module wade
