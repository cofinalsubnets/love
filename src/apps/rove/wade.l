; wade -- a night river in half blocks, first person: the sky, a moon and stars, black
; forest on either bank, and all of it in the water, rippled where the player wades.
; the player wades on down the river, facing where they like within sixty degrees of
; ahead, and the moon goes where the wading takes it: high on the right at the start, it
; arcs down to the middle of the screen where the water meets the sky, then contracts
; into the lamp of a lamppost standing in the river, and the level ends at its foot.
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
; only wade-walk and wade-run tie the tty and the horn.
;
; run: love wade    h l or the arrows turn, k or up wades on, u n look up and down,
;                   space walks on until pressed again; q or esc leaves. reaching the
;                   lamppost ends the level: the view turns to the lamp and pitches up
;                   to hold its flame, a moment passes, and the apartment takes the
;                   screen (src/apps/rove/apartment.l) where the seat carries it.
;                   HORN=none plays silent on a seat with no sound device
(module (wade wade-run wade-walk wade-main wade-new wade-step wade-move wade-frame wade-tables
         wade-size wade-song-new wade-song-feed moon-at swell rings-at tree-of rw sp loop fps
         slendro song-chunk arc-z morph-z lamp-z lamp-near done-ms settle-ms wade-aim wade-settle
         texts texts-at)
(borrow 'rove)
(borrow 'view)                          ; the screen, its rays, the pens
(borrow 'play)                          ; the voices, the mix
(borrow 'posix)    ; close, for the horn
(:
 eh 1.2 rw 5.0                        ; the eye above the water, waist deep; the river's half width
 sp 3.0 loop 64                       ; a tree every so far along a bank; the bank repeats
 far 150.0 near 35.0                  ; sight along a bank; a tree nearer than near is black, past it haze
 fps 30
 ; the pens, in the 256-colour palette. 16..231 is a 6x6x6 cube, a channel's levels
 ; 0 95 135 175 215 255 and the cell 16 + 36r + 6g + b; 232..255 is the grey ramp, where
 ; 232 + n is #vvvvvv with v = 8 + 10n, so a grey of brightness v is 232 + (v - 8) / 10.
 ; `love x11 NAME` answers a named colour's cube cell
 moon-pen 230 sea-pen 187             ; #ffffd7 the disc, #d7d7af its seas
 glass-pen 179 heart-pen 231          ; #d7af5f the lantern's glass; the flame in it is the moon's pale, its heart #ffffff
 tree-pen 16 haze-pen 233             ; #000000 a near tree, #121212 a far one
 bank-pen 232                         ; #080808 the bank, a shade under the water's #121212
 (tn a) (sin a / cos a)
 ; the moon's journey, a piecewise function of how far the player has waded. over the
 ; first stretch it arcs from high on the right down to dead ahead on the horizon, its
 ; bearing sweeping in as its height falls; over the next it contracts into the lamp of
 ; a lamppost standing in the river's middle, a post growing under it to the water; from
 ; there the lamppost is a thing in the world, nearer and taller with every step, and
 ; the level ends at its foot
 arc-z 90.0 morph-z 30.0              ; the stretch the moon arcs over, and the one it contracts over
 lamp-z 160.0 lamp-h 3.2 lamp-r 0.45  ; where the post stands, and the lamp's height and radius
 post-w 0.12 lamp-near 3.0            ; the post's half width, and how near its foot is arrived
 ; the lantern on the post, in the world's units about the lamp's centre: the glass, lit,
 ; its half width and height; a dark rim around it; and a roof over it, that wide at its
 ; eaves and that tall to its peak
 lan-w 0.4 lan-h 0.7 lan-rim 0.08 lan-eave 0.6 lan-roof 0.35
 lan-taper 0.4                        ; ..and the glass and its rim this much narrower at the bottom than the top
 done-ms 1000                         ; at the lamppost's foot: this long looking around, then the level is over
 ; the words: a line over the frame while the player is between two points down the
 ; river, [start end text] each, pinned to where they are and not to the clock. a line
 ; sits text-row rows above the screen's middle, below it for a negative, centred, in
 ; the moon's pale on a ground that is the average of the pixels it covers; two at once
 ; stack upward
 texts [[10.0 20.0 "found the river again"]]
 text-pen 230 text-row -3
 (texts-at pz) (map (e \ e 2) (filter (e \ e 0 <= pz < e 1) texts))
 maz 0.5 mel 0.36 mang 0.14           ; the moon's bearing and height at the start, and its angular radius
 (lerp a b v) (a + v * (b - a))
 ; what is on the screen: [cx cy r foot pw v] -- the disc's centre and radius, the row
 ; the post's foot stands on and the post's half width, no post while it is the moon, and
 ; how far along the contraction it is, 0 a moon and 1 a lamp; and far off the screen
 ; when it is behind the player
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
 ; a tree by its bank s (-1 or 1), its row r back from the water and its index k along
 ; the river: where it stands, how tall and wide, and whether its crown is round. the
 ; loop has so many places, and each is hashed once and kept
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
 ; the frame's tables: the columns' indices and bearing cells as trays; the treeline's
 ; top row for all trees and for the near ones alone and the reflection's bottom row,
 ; tablets while the trees are laid and trays after; a row's height cell, for rows well
 ; above the screen too, since the water mirrors sky that is off the top; and the sky's
 ; rows, darkened for the water, and the frame's, kept as they are asked for
 (fresh st) (: w (st 'w) h (st 'h) hz (st 'hz) th (st 'th) foc (st 'foc) cx (st 'cx)
   xs (iota w)
   tb {'xs xs 'tops {} 'ntops {} 'bots {} 'qes {} 'sky {} 'dark {} 'rows {}
       'qas ((floor ((th + atan ((xs - cx) / foc)) / (2.0 * pi) * 256.0) % 256 + 256) % 256)}
   (row y) (y < hz ? (pin (tb 'qes) y (flo (atan ((hz - y) / foc) * foc)), row (y + 1)))
   (row (-h - 12), tb))
 ; the trees within sight, each laid into the columns it covers: a conifer or a round
 ; crown, its base at the bank and its mirror hanging under it. the row at the water
 ; runs to the horizon, the two behind it half as far
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
 ; the sky, a row at a time in trays over the columns: a grey ramp up from the horizon,
 ; the stars hashed off the column's bearing cell and the row's height cell, the moon's
 ; glow, and its disc with its seas, each laid over the last where its mask holds. the
 ; ramp's bands and the glow's reach scale with the screen
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
   ; the lantern's parts in pixels, once it is the lamp: the glass a pixel at least, which
   ; is what the contracted moon was; the rim a pixel around it at least, the eaves a
   ; pixel past the rim and the roof a pixel tall, so the shape reads however far it is
   ; -- but only once the glass is wider than a pixel, and the flame's heart with it: a
   ; housing around a lone point of light is not what a far lamp looks like
   sz (r / lamp-r)                                                                  ; a world unit in pixels
   gw (max2 0.5 (lan-w * sz)) gh (max2 0.5 (lan-h / 2.0 * sz))
   housed (1.25 <= lan-w * sz)                                                     ; the glass three wide at the top
   rw (max2 (gw + 1.0) ((lan-w + lan-rim) * sz)) rh (max2 (gh + 1.0) ((lan-h / 2.0 + lan-rim) * sz))
   ev (max2 (rw + 1.0) (lan-eave * sz)) rf (max2 1.0 (lan-roof * sz))
   reach (rh + rf)                                                                  ; the roof's peak above the lamp's centre
   ; the moon's layers, on the rows it reaches: the glow, the post over it, black, and
   ; the disc over that -- or, once it is the lamp, the lantern: the roof, black, the
   ; rim, the water's grey, the glass, the two tapering down it, and in the glass a
   ; flame: a teardrop off the glass's floor in the moon's pale, its tip swaying and its
   ; height breathing with the tick, and a white heart low in it -- a pixel at least,
   ; which is what the contracted moon was
   (lantern c dx) (: x2 (2 dx) ady (abs dy)
     tp (1.0 - lan-taper * clamp ((dy + gh) / (2.0 * gh + 0.001)) 0.0 1.0)  ; down the glass: 1 at the top
     gwt (gw * tp) rwt (max2 (gwt + 1.0) ((lan-w + lan-rim) * sz * tp))
     q ((-dy - rh) / rf)                       ; up the roof: 0 at the eaves, 1 at the peak
     ew (max2 0.5 (ev * (1.0 - q)))
     roofed (housed ? (over c ((0.0 <= q) * (q <= 1.0) * (x2 <= ew * ew)) tree-pen) c)
     rimmed (housed ? (over roofed ((x2 <= rwt * rwt) * (ady <= rh)) haze-pen) roofed)
     glass ((x2 <= gwt * gwt) * (ady <= gh))
     glassed (over rimmed glass glass-pen)
     fh (1.5 * gh * (0.85 + 0.15 * sin (1.3 * t)))    ; the flame's height, off the floor to its tip
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
 ; the water's lift, in the world's units: a slow swell, and the rings the player's steps
 ; sent out, each fading as it spreads. x and z are trays, a row of points at once, and
 ; a ring's reach is a mask over them; numbers pass through the same words
 (swell x z t) (0.10 * sin (1.1 * z + 0.3 * x + 0.20 * t) + 0.07 * sin (1.7 * x - 0.4 * z + 0.31 * t))
 (rings-at x z t rings) (:
   (ring a r) (: age (t - r 't) dx (x - r 'x) dz (z - r 'z) d (sqrt (2 dx + 2 dz))
                 (0.0 < age ? (a + (d < 0.18 * age) * 0.25 * exp (-0.25 * d - 0.03 * age) * sin (4.0 * d - 0.72 * age)) a))
   (foldl ring 0.0 rings))
 ; a ring five seconds old is a hundredth of what it was: gone from the list, so the
 ; water stops asking after it
 ring-life 150.0
 ; every water row at once, in trays over the columns: where the row's rays meet the
 ; water, whether that is past the river's edge, and the lift there tilting the sample
 ; by more the nearer it is -- the sample's row and column, and the rings' own lift, for
 ; a crest
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
 ; what the water makes of what it mirrors -- its own grey under the forest, a shade
 ; off the bank -- and a ring's crest catching the moon, a step or two lighter
 ; the moon #ffffd7 to #d7af5f, its seas to #af8700, a star to a grey two steps down, the
 ; sky's greys a step down, and the forest and the bank to the water's #121212
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
 ; a water row, off its trays: the mirror's sample, gathered from each darkened sky row
 ; the row's columns reach; the forest's reflection where the sample is under the
 ; treeline; a crest a step lighter; and the bank
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
   ; the words live here, each a band [x0 text pen ground] on its cell row, the ground the
   ; average of the two pixel rows under the text
   ws (texts-at (st 'pz))
   (band i) (: s (snip (ws i) 0 (min2 #(ws i) w)) ty (h // 4 - text-row - i) x0 ((w - #s) // 2)
               ts (src (2 * ty)) bs (src (2 * ty + 1))
               (add a x) (: p (pen-rgb (peep ts x 236)) q (pen-rgb (peep bs x 236))
                            [(a 0 + p 0 + q 0) (a 1 + p 1 + q 1) (a 2 + p 2 + q 2)])
               sum (foldl add [0 0 0] (map (+ x0) ^#s)) n (2 * #s)
               [x0 s text-pen (rgb-pen (sum 0 // n) (sum 1 // n) (sum 2 // n))])
   bands (foldl (tab \ i \ (h // 4 - text-row - i @ ty (0 <= ty < h // 2 ? (pin tab ty (band i)) tab))) {} ^#ws)
   (view-frame w h src bands))
 ; the state: the screen, where the player stands and faces, the horizon's row, the
 ; tick, the rings on the water, and whether they walk on by themselves
 (wade-new w h) (view! {'px 0.0 'pz 0.0 'th 0.0 't 0 'rings () 'walk 0 'done 0} w h (h // 2))
 ; the screen's shape: w cells across and r rows, the horizon off the top and bottom quarter
 (wade-size st w r) (view-size st w r 4)
 ; a step on down the river, whichever way the player faces, and no further than the
 ; lamppost's foot, where the level is done and the wading with it -- the player may
 ; still look around; it sends a ring, but not on the heels of the last one
 (wade-move st mv) (: t (st 't) rs (st 'rings) px (st 'px)
   pz2 (min2 (st 'pz + mv) (lamp-z - lamp-near))
   due (rs @ () 1 (6.0 <= t - peep <rs 't 0.0))
   r {'x px 'z pz2 't (t + 0.0)}
   (st 'done ? st
      ((pins st 'pz pz2 'rings (due ? (first-n 5 (r . rs)) rs)),
       lamp-z - pz2 <= lamp-near ? (pins st 'done 1 'walk 0 'th0 (st 'th) 'hz0 (st 'hz)) st)))

 ; a key: h l or the arrows turn, within sixty degrees of ahead, k or up wades on -- there
 ; is no wading back -- u n look up and down, the horizon dropping down the screen to
 ; look up. a tty tells of keys pressed and never of keys let go, and it repeats one key
 ; at a time, so a chord cannot be seen: space walks on by itself, and the turns steer it
 facing (pi / 3.0)
 (wade-step st k) (: th (st 'th)
   turn (k @ 104 -0.08 -1 -0.08 108 0.08 -2 0.08 0.0)
   mv (k @ 107 0.35 -8 0.35 0.0)
   h (st 'h) tilt (k @ 117 (h // 16) 110 (0 - h // 16) 0)
   (? (st 'done) st                     ; arrived: the view is the level's now
      (turn != 0.0) (pin st 'th (clamp (th + turn) (0.0 - facing) facing))
      (tilt != 0) (view-hz st (st 'hz + tilt) 4)
      (mv != 0.0) (wade-move st mv)
      (k = 32) (pin st 'walk (st 'walk ? 0 1))
      st))
 ; --- arrived: the view is the level's. it turns to the lamp and pitches down until the
 ; flame's reflection holds the middle of the screen, eased over settle-ms from where
 ; the player left it, and the level is over done-ms after that. the reflection hangs
 ; as far under the horizon as the flame is over the water and the eye is over it, so
 ; from this close the horizon goes off the top and the screen is water ---
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
 song-gain 11000.0
 chime-odds 12                                          ; a chime's chance a chunk, in thousandths: one every three seconds or so
 ; the song: its port, a spun die, the frames written, the voices ringing, when the gong
 ; is next due, and how many strikes there have been
 (wade-song-new h st) {'h h 'sb {st} 'fpos 0 'vs () 'gong 0 'struck 0}
 ; one chunk out the port. a chime by the die, its degree and octave off the die too, the
 ; low octave three times in four, ringing long; a gong when it is due, the next some
 ; seconds on. the port is any jug, so the song gates headless
 (wade-song-feed s) (: sb (s 'sb) base (s 'fpos)
   (strike v) (base + roll sb song-chunk @ at
                 (pins s 'vs (s 'vs + [[at (mkvoice at v song-rate)]]) 'struck (s 'struck + 1)))
   (roll sb 1000 < chime-odds ?
      (strike {'s "chime" 'note (slendro (roll sb 5) - 36 + 12 * (roll sb 4 = 0))
               'gain (0.6 + roll sb 40 / 100.0) 'pan (0.2 + roll sb 60 / 100.0) 'legato 5.0}),
   ; the gong is a triangle, not a sine: its odd harmonics are what a small speaker
   ; gives of a note this low
    s 'gong <= base ?
      (strike {'s "tri" 'note -22.0 'gain 0.9 'pan 0.5 'legato 7.0},
       pin s 'gong (base + song-rate * (8 + roll sb 6))),
    song-out s song-chunk song-gain))
 ; --- the walk, on view's loop: walking on by itself, or at the lamppost settling on the
 ; lamp over settle-ms, and the apartment after it. wade-walk takes a stage already
 ; raised, and wade-run raises one ---
 (wade-walk _) (view-walk {'new wade-new 'size wade-size 'frame wade-frame 'key wade-step 'fps fps
                           'tick (st \ (? (st 'done-at) (clock (st 'done-at) / (1.0 * settle-ms) @ s
                                                            (wade-settle st (1.0 < s ? 1.0 s)))
                                          (st 'walk) (wade-move st 0.25)))
                           'song (hn \ ((hn ? (wade-song-new hn (wheel (clock 0)))) @ s
                                          (s ? (_ \ (wade-song-feed s)))))
                           'linger (settle-ms + done-ms) 'next ['apartment 'apartment-walk]})
 (wade-run _) (view-run wade-walk)
 wade-usage "usage: love wade   (h l turn, k j wade, u n look, space walks on to the lamppost; q or esc leaves)"
 (wade-main as) (as @ () (wade-run ())
                      (say err ("wade: " + wade-usage + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'wade (udoor 'wade wade-main wade-usage 1 1)))
) ; module wade
