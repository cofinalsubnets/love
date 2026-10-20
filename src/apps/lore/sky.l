; sky -- the sky over a scene, by the hour and the weather: the sun from day of year, solar
; hour and latitude, and its light; cloud cover drawn 'smooth or 'pixel (grass's stepped
; sky, block clouds). cloud over the sun takes it off the scene. the cloud map is laid
; once a run; stars are points a scene lays a pixel each.
; time is local seconds 'sim and summer offset 'dst; rays are trays of unit [east up north].
; weather (sky-weather cover style): cover 0 to 3; 'fall 0 none (default), 1 rain, 2 snow;
; 'smog 0 (default) to 1, the smooth sky and its light browned toward orange
(module (sky sky-sun sky-body sky-light sky-maps sky-weather turns lap sky-cover sky-cloud sky-colour-of sky-near sky-tone
         sky-irr sky-stars sky-stars! sky-covers sky-styles sky-says sky-falls sky-fall sky-drops bil cloud-n day-secs rgb)
(borrow 'view)
(borrow 'vec)
(borrow 'starmap)
(:
 (day-secs s) (s - 86400.0 * floor (s / 86400.0))
 ; the sun as [east up north], a unit vector, by solar time and the day of the year
 (sky-sun sim dst lat) (sky-body (sim - dst) lat 0.0 0.0)
 ; ..and a body on the sun's own track, its hour dh hours on from the sun's and its day of
 ; the year dd days: the moon, a phase p round, is the sun's hour -24p and its day +365p
 (sky-body s lat dh dd) (: hr (day-secs s / 3600.0 + dh)
   doy (sky-doy s + dd)
   dec (-0.4091 * cos (tau * (doy + 10.0) / 365.2422))
   ha ((hr - 12.0) * pi / 12.0)
   [(0.0 - cos dec * sin ha)
    (sin lat * sin dec + cos lat * cos dec * cos ha)
    (cos lat * sin dec - sin lat * cos dec * cos ha)])
 (sky-doy s) (s / 86400.0 - 10957.0 - 365.2422 * floor ((s / 86400.0 - 10957.0) / 365.2422))
 ; the local sidereal time, as an angle: the sun's hour angle and its right ascension, off
 ; the same year as its declination -- so the stars keep their place against the sun
 (sky-lst s) (: lam (tau * (sky-doy s - 81.31) / 365.2422) k (1.0 - cos 0.4091)
   ((day-secs s / 3600.0 - 12.0) * pi / 12.0 + lam - atan (k * sin lam * cos lam / (1.0 - k * sq (sin lam)))))
 ; --- the weather ---
 sky-covers ['clear 'partly 'mostly 'overcast]
 sky-styles ['smooth 'pixel]
 sky-says ["clear" "partly cloudy" "mostly cloudy" "overcast"]
 (sky-weather cover style) {'cover cover 'style style}
 sky-falls ['none 'rain 'snow]
 (sky-fall wx) (peep wx 'fall 0)
 ; the share of the sky that is cloud: each cover's own, breathing a little with the hours
 shares [0.03 0.22 0.55 0.97]
 (sky-cover wx sim) (: c (wx 'cover) b (shares c)
   (c = 0 || c = 3 ? b (b + 0.04 * sin (sim * turns wx 'per (1.0 / 7300.0))
                          + 0.02 * sin (sim * turns wx 'per (1.0 / 2900.0)))))
 ; --- the maps ---
 cloud-n 128
 ; a loop: 'per on the weather is its length in sim seconds and 'tper in frames, and each of
 ; the sky's clocks then comes round a whole number of times in it -- the nearest number, so
 ; a slow one stands still. turns snaps a rate in radians, lap a drift over a wrapping map
 (turns wx k w) (peep wx k 0 @ p (p = 0 ? w (tau * floor (w * p / tau + 0.5) / p)))
 (lap wx r k) (peep wx 'per 0 @ p (p = 0 ? r (floor (r * k * p / cloud-n + 0.5) * cloud-n / (k * p))))
 ; the clouds' thickness, a square that tiles: value noise on lattices that wrap
 (cloud-map _) (: n cloud-n i (iota (n * n)) u (i % n / (1.0 * n)) v (i // n / (1.0 * n))
   (vp x z s p) (: ix (floor x) iz (floor z) ux (x - ix) uz (z - iz)
                   ex (ux * ux * (3.0 - 2.0 * ux)) ez (uz * uz * (3.0 - 2.0 * uz))
                   (h a c) (throw (a % p) (c % p) s 1024 / 1023.0)
                   q0 (h ix iz) q1 (h (ix + 1) iz) q2 (h ix (iz + 1)) q3 (h (ix + 1) (iz + 1))
                   lo (q0 + ex * (q1 - q0)) hi (q2 + ex * (q3 - q2))
                   (lo + ez * (hi - lo)))
   (0.55 * vp (u * 8.0) (v * 8.0) 61 8 + 0.3 * vp (u * 16.0) (v * 16.0) 62 16 + 0.15 * vp (u * 32.0) (v * 32.0) 63 32))
 maps {}
 ; ..and where the clouds' thickness stands at each hundredth of the sky, so a cover's
 ; share is the share of sky its clouds take: thick's own mix of the map, shuffled, with
 ; the fine layer's weight f
 (quantiles m f) (: n (cloud-n * cloud-n) i (iota n)
   (sh k) (peep m ((i * k + 7919 * k) % n) 0.0)
   t ((1.0 - f) * m + f * sh 7 + 0.18 * (sh 13 - 0.5))
   l (sort (map (k \ peep t k 0.0) ^n))
   (map (q \ l (q * (n - 1) // 100)) ^101))
 (sky-maps _) (maps 'cloud ? maps
   (: m (cloud-map ()) (pins maps 'cloud m 0.3 (quantiles m 0.3) 0.0 (quantiles m 0.0))))
 ; the thickness a cover's clouds start at, the fine layer weighing f
 ; ..the blocks' dithered fringe shows less of a cloud than the smooth sky's soft edge,
 ; so they take a little more of the sky for the same cover
 (edge wx sim f) (: sh (min 1.0 (sky-cover wx sim * (f = 0.0 ? 1.3 1.0)))
                    ((sky-maps () f) (int ((1.0 - sh) * 100.0 + 0.5))))
 ; a square map at fractional texels, bilinear, wrapping
 (wrap-n i n) ((i % n + n) % n)
 (bil tab n x z) (: ix (floor x) iz (floor z) ux (x - ix) uz (z - iz)
                    x0 (wrap-n ix n) x1 (wrap-n (ix + 1) n) z0 (wrap-n iz n * n) z1 (wrap-n (iz + 1) n * n)
                    (g k) (peep tab k 0.0)
                    lo (g (z0 + x0) @ q (q + ux * (g (z0 + x1) - q)))
                    hi (g (z1 + x0) @ q (q + ux * (g (z1 + x1) - q)))
                    (lo + uz * (hi - lo)))
 ; --- the clouds: a deck over the eye, two layers on two winds and a swell; deck-at
 ; answers where a ray crosses it, in map tiles. under three degrees the deck recedes
 ; ever slower, so each row by the horizon reaches a little further ---
 deck 1800.0 tile 400.0
 (deck-at dx dy dz ex ez sim) (: tc (deck / over dy (dy < 0.05) (0.025 + 0.025 * exp ((min dy 0.05 - 0.05) / 0.025)))
   [((ex + dx * tc) / tile) ((ez + dz * tc) / tile)])
 (thick wx mp u v sim f) (: m (mp 'cloud)
   a (bil m cloud-n ((u + sim * lap wx 0.006 16.0) * 16.0) ((v + sim * lap wx 0.0025 16.0) * 16.0))
   b (f = 0.0 ? 0.0 (bil m cloud-n ((u + sim * lap wx 0.011 37.0) * 37.0 + 11.3) ((v + sim * lap wx -0.004 37.0) * 37.0 - 5.1)))
   sw (bil m cloud-n ((u + sim * lap wx 0.002 3.0) * 3.0 + 40.0) ((v + sim * lap wx 0.001 3.0) * 3.0 + 17.0))
   ((1.0 - f) * a + f * b + 0.18 * (sw - 0.5)))
 ; how much cloud down the rays, 0 to 1, as the smooth sky draws it: by the horizon the
 ; deck too far to tell apart, a haze as thick as the cover
 (haze c dy wx sim) (: k (sat (1.0 - dy / 0.06)) (c + 0.85 * k * (sat (1.2 * sky-cover wx sim) - c)))
 ; ..past where the cover starts, k as sharp; at a full cover, never under 0.93
 (thick-at wx mp d sim k) (sat (0.5 + (thick wx mp (d 0) (d 1) sim 0.3 - edge wx sim 0.3) * k))
 (clouded wx c) (wx 'cover = 3 ? (max c 0.93) c)
 (sky-cloud wx dx dy dz ex ez sim) (: mp (sky-maps ()) d (deck-at dx dy dz ex ez sim)
   (clouded wx (haze (thick-at wx mp d sim 10.0) dy wx sim)))
 ; the cloud over the sun as the light under it feels it: rays over a patch round it, each
 ; with a soft edge, so a passing cloud thins the light and gives it back over a while --
 ; low down, where one ray sweeps the deck fast, most of all
 sun-ring (cat [[0.0 0.0]] (map (k \ (: a (k * pi / 6.0) [(cos a) (sin a)])) ^12))
 (sun-cloud wx s sim) (: mp (sky-maps ()) r 0.05
   (one o) (deck-at (s 0 + r * o 0) (max2 (s 1) 0.05) (s 2 + r * o 1) 0.0 0.0 sim @ d
              (clouded wx (thick-at wx mp d sim 3.0)))                    ; a soft edge
   (net (map one sun-ring) / #sun-ring))
 ; the light of the sun s under the weather: its colour and strength, the share of it
 ; the cloud over it lets through, how much day and twilight there is, the sky's light on
 ; what it sees -- greyer the more cloud -- and the eye's gain against the dark
 ; ..and what it lights: a times the sky's ambient and b times the sun's colour
 (sky-irr lt a b) (c+ (c* a (lt 'amb)) (c* b (lt 'sunc)))
 ; ..smog, wx 'smog 0 to 1 of the way, browns what is seen and what it lights toward orange
 (smoggy wx c) (: k (peep wx 'smog 0.0) l ((c 0 + c 1 + c 2) / 3.0)
   t (cmix [1.35 0.52 0.16] [2.0 1.0 0.24] (sat (1.6 * l)))
   (k = 0.0 ? c (cmix c [(t 0 * l) (t 1 * l) (t 2 * l)] k)))
 (sky-light s wx sim) (: sy (s 1)
   oc (sky-cover wx sim)
   csun (s 1 <= 0.0 ? 0.0 (sun-cloud wx s sim))
   day (sat ((sy + 0.06) / 0.3))
   tw (sat (1.0 - mag (sy + 0.03) / 0.2) * (1.0 - 0.7 * oc))
   ; ..rain or snow takes the most of the sun, and rain the light's edge besides
   f (sky-fall wx)
   sunk (sat ((sy + 0.005) / 0.05) * (1.0 - 0.75 * csun - 0.2 * csun * csun * csun * csun) * (f = 0 ? 1.0 0.3))
   sunc (cmix [1.0 0.4 0.1] [1.0 0.93 0.82] (sat ((sy - 0.04) / 0.4) @ k (k * k * (3.0 - 2.0 * k))))
   night [0.05 0.055 0.075]
   amb0 (c+ (cmix night [0.42 0.47 0.56] day) (c* (tw * (1.0 - 0.5 * day)) [0.1 0.05 0.07]))
   grey (cmix night [0.5 0.51 0.53] day)
   amb (c* (f = 1 ? 0.8 1.0) (cmix amb0 grey (0.7 * oc)))
   {'sun s 'day day 'tw tw 'sunk sunk 'sunc (smoggy wx sunc) 'amb (smoggy wx amb) 'cover oc 'csun csun
    'expo (1.0 + 1.2 * (1.0 - day) + 0.3 * oc)})
 ; --- the smooth sky. far weighs what lies past the moon, the sun's own disc: 0 is the
 ; sky nearer than it, what a body in front of it shows ---
 (smooth-of lt wx dx dy dz ex ez sim far) (: mp (sky-maps ())
   s (lt 'sun) sx (s 0) sy (s 1) sz (s 2) oc (lt 'cover)
   mu (dx * sx + dy * sy + dz * sz)
   up (sat dy)
   blue (cmix [0.55 0.7 0.9] [0.2 0.42 0.84] (sat (up * 1.3)))
   dark (c+ [0.012 0.016 0.04] (c* (0.06 * (1.0 - up)) [0.6 0.45 0.3]))
   warm (sat ((mu + 0.3) / 1.3))
   dusk (c* (lt 'tw * (1.0 - 0.5 * lt 'day)) (c+ (c* (warm * warm * warm) [0.9 0.38 0.16]) [0.22 0.12 0.28]))
   disc (sat ((mu - 0.9995) * 4000.0))
   halo (0.35 * lt 'day * exp ((mu - 1.0) * 60.0))
   sky0 (c+ (c+ (cmix dark blue (lt 'day)) dusk) (c* (halo + 3.0 * far * disc * lt 'sunk) (lt 'sunc)))
   d (deck-at dx dy dz ex ez sim) th (thick wx mp (d 0) (d 1) sim 0.3)
   cl0 (haze (sat (0.5 + (th - edge wx sim 0.3) * 10.0)) dy wx sim)
   cl (clouded wx cl0)                          ; overcast: no sky through it
   ; ..the clouds: lit from under by the sun, darker the thicker, greyer the more of them
   ; ..and under smog the thick of them darker still and the thin lit through
   sm (peep wx 'smog 0.0)
   body ((1.0 - 0.3 * cl - 0.35 * oc * sat ((th - 0.45) * 2.0)) * (sky-fall wx = 1 ? 0.8 1.0)
         * (1.0 - 0.45 * sm) * (1.0 - 0.6 * sm * sat ((th - 0.3) * 2.2) + 0.5 * sm * sat ((0.4 - th) * 3.0)))
   cloudc (c* body
              (c+ (c+ (sky-irr lt 1.15 (sat ((sy + 0.005) / 0.05) * (1.0 - 0.6 * oc) * (0.55 + 0.4 * sy)))
                      (c* (lt 'tw) [0.5 0.22 0.14]))
                  (c* (1.0 - lt 'day) [0.06 0.05 0.045])))
   (smoggy wx (cmix sky0 cloudc cl)))
 ; --- the pixel sky: the grass game's. its colours are xterm pens, said here as they
 ; are to show, and put back through the eye's tone so the frame shows them so ---
 (rgb x) [((x // 65536) / 255.0) ((x // 256 % 256) / 255.0) ((x % 256) / 255.0)]
 ; the ground of the sky by the sun's height, the morning's and the evening's: grass's
 ; hours as keys on the sun, blended between
 morning [[-0.3 0x00005f] [-0.12 0x000087] [-0.04 0x5f5f87] [0.03 0xd78787] [0.12 0x5fafd7] [0.28 0x00afff]]
 evening [[-0.3 0x00005f] [-0.16 0x000087] [-0.08 0x5f0087] [-0.02 0x875f87] [0.04 0xd7875f] [0.13 0x87afff] [0.28 0x00afff]]
 (keyed ks y) (: (go l) (? (atom? >l) (rgb (<l 1))
                           (y <= >l 0 0) (: a <l b <>l f (sat ((y - a 0) / (b 0 - a 0)))
                                            (cmix (rgb (a 1)) (rgb (b 1)) f))
                           (go >l))
                 (y <= <ks 0 ? (rgb (<ks 1)) (go ks)))
 ; ..and the clouds' pens, lit and in shade, and lit from behind near the sun: by day, at
 ; either end of it and by night, blended by the light
 (pens3 lt d u n) (: dl (lt 'day) nf (sat ((0.12 - dl) / 0.12)) df (sat ((dl - 0.3) / 0.4))
   (cmix (cmix (rgb u) (rgb n) nf) (rgb d) df))
 (untone lt c) (: k (1.5 * lt 'expo) (f v) (0.0 - log (1.0 - min v 0.97) / k)
                  [(f (c 0)) (f (c 1)) (f (c 2))])
 blocks 6.0                             ; blocks a tile, a side
 (pixel lt wx dx dy dz ex ez sim far) (: mp (sky-maps ())
   s (lt 'sun) sx (s 0) sy (s 1) sz (s 2)
   ground (keyed (sx < 0.0 ? evening morning) sy)
   ; ..a cloud's block: its thickness at the block's middle, in four depths over the
   ; cover's edge -- 3 the core down to 0 the faint fringe -- and a die off now and then
   d (deck-at dx dy dz ex ez sim)
   ru (lap wx 0.006 16.0) rv (lap wx 0.0025 16.0)
   bu ((d 0 + sim * ru) * blocks) bv ((d 1 + sim * rv) * blocks)
   cu ((floor bu + 0.5) / blocks - sim * ru) cv ((floor bv + 0.5) / blocks - sim * rv)
   th (thick wx mp cu cv sim 0.0)
   q (floor ((th - edge wx sim 0.0) / 0.015) + 1)
   die (throw (floor bu) (floor bv) 5 4 = 0)
   v0 (min 3 q - die)
   v (wx 'cover = 3 ? (max v0 2) v0)            ; overcast: no sky through it
   ; ..the block's quarters, for the dither: a checker, and one quarter in four
   qx (mag (floor (bu * 2.0) % 2)) qz (mag (floor (bv * 2.0) % 2))
   chk (mag ((qx + qz) % 2)) one (qx * qz)
   mu (dx * sx + dy * sy + dz * sz)
   glow (0.97 < mu)
   lit (cmix (pens3 lt 0xeeeeee 0xffafaf 0x585858) (pens3 lt 0xffffff 0xffd7af 0xd0d0d0) glow)
   shade (cmix (pens3 lt 0xd0d0d0 0xd7afaf 0x3a3a3a) (pens3 lt 0xeeeeee 0xffd7d7 0x949494) glow)
   ; █ the core, ▓ lit over shade, ▒ shade checkered on the sky, ░ a quarter of shade
   cov (over (over (over (over 0.0 (v = 0) (one * 1.0)) (v = 1) (chk * 1.0)) (v = 2) 1.0) (3 <= v) 1.0)
   inner (over (over (over (over 0.0 (v = 0) 0.0) (v = 1) 0.0) (v = 2) 0.55) (3 <= v) 1.0)
   cloudc (cmix shade lit inner)
   ; ..the sun a disc where it is seen, the moon none
   sun ((0.9994 < mu) * (v < 0) * sat ((sy + 0.02) / 0.04) * far)
   bg (cmix ground (rgb 0xffd700) sun)
   (untone lt (cmix bg cloudc ((0 <= v) * cov))))
 ; the sky's colour down the rays dx dy dz (trays) from the eye at ex ez, under the light
 ; lt and the weather wx, at the time sim, the sun's disc in it; the stars are sky-stars!'s
 (sky-colour-of lt wx dx dy dz ex ez sim)
  (wx 'style = 'pixel ? (pixel lt wx dx dy dz ex ez sim 1.0) (smooth-of lt wx dx dy dz ex ez sim 1.0))
 ; ..and the sky nearer than the moon: no sun's disc
 (sky-near lt wx dx dy dz ex ez sim)
  (wx 'style = 'pixel ? (pixel lt wx dx dy dz ex ez sim 0.0) (smooth-of lt wx dx dy dz ex ez sim 0.0))
 ; --- the stars: starmap.l's catalogue turned by sidereal time over latitude, trays 'x 'y
 ; 'z [east up north] with brightness 'b, twinkle 'ph, 'tint. laid a pixel each, not read
 ; off a map per ray, which would stretch them overhead and lose them low ---
 stars0 (: n (#star-cat // 4) (col j) (gem-tray [n] (map (i \ 1.0 * star-cat (4 * i + j)) ^n))
           ra (col 0 * (pi / 18000.0)) de (col 1 * (pi / 18000.0)) m (col 2 / 100.0)
           t (sat ((col 3 / 100.0 + 0.3) / 1.9)) u (sat (t * 2.13)) w (sat ((t - 0.47) * 1.89))
           {'ra ra 'sd (sin de) 'cd (cos de) 'b (sat ((0.85 - 0.13 * m) / 1.1) * 1.1)
            'ph (gem-tray [n] (map (k \ throw k 4 97 628 / 100.0) ^n))
            'tint [(0.78 + 0.22 * u) (0.86 + 0.11 * u - 0.19 * w) (1.0 - 0.1 * u - 0.35 * w)]})
 (sky-stars sim dst lat) (: H (sky-lst (sim - dst) - stars0 'ra) ch (cos H) sd (stars0 'sd) cd (stars0 'cd)
   y (sin lat * sd + cos lat * cd * ch)
   {'x (0.0 - cd * sin H) 'y y 'z (cos lat * sd - sin lat * cd * ch)
    'b (stars0 'b * sat (y / 0.1)) 'ph (stars0 'ph) 'tint (stars0 'tint)})
 ; ..their light added to the colours c, [r g b] trays before the eye's gain, ix each of
 ; ss's stars' place in them, -1 where it is not on the open sky: dimmed by the cloud before
 ; it, twinkling by the frame's clock t0, or in the pixel sky on and off
 (sky-stars! ss c lt wx ex ez sim t0 ix) (: nt (sat (1.0 - lt 'day * 3.0))
   (nt <= 0.0 ? c
    (: X (ss 'x) Y (ss 'y) Z (ss 'z)
       cl (sky-cloud wx X Y Z ex ez sim)
       tw (sin (t0 * turns wx 'tper 0.9 + ss 'ph))
       v (wx 'style = 'pixel ? ((0.6 < tw) * (lt 'day < 0.1) * (cl < 0.5) * (0.0 < Y) * 1.6)
            (ss 'b * (0.75 + 0.25 * tw) * nt * (1.0 - cl)))
       (map (k \ peep (c k) ix 0.0 @ o (pin (c k) ix (o + (ss 'tint) k * v))) ^3))))
 ; --- what falls round the eye e at sec: () or {'x 'y 'z foot, 'len 'wd 'a 'c}. no state:
 ; a drop's place is its number and the clock, on a ground lattice wrapped round the eye ---
 fall-r 6.0 fall-h 9.0 rain-n 1600 snow-n 1400
 (sky-drops wx lt e sec) (: f (sky-fall wx)
   (f = 0 ? ()
      (: n (f = 1 ? rain-n snow-n) i (iota n) R fall-r H fall-h
         (rnd k) (frac (sin (i * 12.9898 + k * 78.233) * 43758.5453))
         v (f = 1 ? 7.5 1.1) sway (f = 1 ? 0.0 0.25)
         (wrap w0 c) (c + 2.0 * R * (frac ((w0 - c) / (2.0 * R)) - 0.5))
         X (wrap (2.0 * R * rnd 1 + sway * sin (sec * 0.7 + 6.3 * rnd 4)) (e 0))
         Z (wrap (2.0 * R * rnd 2 + sway * cos (sec * 0.5 + 6.3 * rnd 5)) (e 2))
         Y (H * (1.0 - frac (rnd 3 + sec * v / H)))
         dist (sqrt (sq (X - e 0) + sq (Y - e 1) + sq (Z - e 2)))
         {'x X 'y Y 'z Z 'len (f = 1 ? 0.14 0.012) 'wd (f = 1 ? 0.004 0.012)
          'a ((f = 1 ? 0.38 0.85) * sat (1.4 - dist / R))
          'c (f = 1 ? (c* 0.95 (c+ (lt 'amb) [0.08 0.09 0.11])) (sky-irr lt 1.5 (0.4 * lt 'sunk)))})))
 ; ..and the eye: its gain against the dark under lt, and a soft shoulder that keeps a hue
 (sky-tone lt col) (: k (1.5 * lt 'expo)
   [(1.0 - exp (0.0 - k * col 0)) (1.0 - exp (0.0 - k * col 1)) (1.0 - exp (0.0 - k * col 2))]))
) ; module sky
