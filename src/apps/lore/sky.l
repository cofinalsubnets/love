; sky -- the sky over a scene, by two things: the hour and the weather. the hour is the
; sun, by the day of the year, the solar hour and the latitude, and the light that
; follows from it; the weather is how much cloud there is -- clear, partly cloudy, mostly
; cloudy or overcast -- and how the sky is drawn: smooth, blue by day and warm toward the
; sun at either end of it, the clouds soft on two winds; or pixel, the grass game's sky,
; its colour stepped through the day by the sun's height and its clouds blocks on the
; cloud deck, solid at the core and dithered at the edge. stars at night either way, and
; the cloud over the sun takes the sun off the scene. the clouds and stars are maps laid
; once a run and gathered from by every frame.
;
; a scene's time is local seconds 'sim and the summer offset 'dst; its rays are trays of
; unit directions [east up north]. the weather is a tablet, (sky-weather cover style):
; cover 0 to 3, style 'smooth or 'pixel; and what falls from it, 'fall 0 nothing, 1 rain,
; 2 snow (nothing unless said), drawn into a scene by sky-fall!
(module (sky sky-sun sky-body sky-light sky-maps sky-weather sky-cover sky-cloud sky-colour sky-colour-of sky-near sky-tone
         sky-covers sky-styles sky-says sky-falls sky-fall sky-fall! bil cloud-n star-n day-secs)
(borrow 'view)
(borrow 'vec)
(:
 (day-secs s) (s - 86400.0 * floor (s / 86400.0))
 ; the sun as [east up north], a unit vector, by solar time and the day of the year
 (sky-sun sim dst lat) (sky-body (sim - dst) lat 0.0 0.0)
 ; ..and a body on the sun's own track, its hour dh hours on from the sun's and its day of
 ; the year dd days: the moon, a phase p round, is the sun's hour -24p and its day +365p
 (sky-body s lat dh dd) (: hr (day-secs s / 3600.0 + dh)
   doy (s / 86400.0 - 10957.0 - 365.2422 * floor ((s / 86400.0 - 10957.0) / 365.2422) + dd)
   dec (-0.4091 * cos (2.0 * pi * (doy + 10.0) / 365.2422))
   ha ((hr - 12.0) * pi / 12.0)
   [(0.0 - cos dec * sin ha)
    (sin lat * sin dec + cos lat * cos dec * cos ha)
    (cos lat * sin dec - sin lat * cos dec * cos ha)])
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
   (c = 0 || c = 3 ? b (b + 0.04 * sin (sim / 7300.0) + 0.02 * sin (sim / 2900.0))))
 ; --- the maps ---
 cloud-n 128 star-n 256
 ; the clouds' thickness, a square that tiles: value noise on lattices that wrap
 (cloud-map _) (: n cloud-n i (iota (n * n)) u (i % n / (1.0 * n)) v (i // n / (1.0 * n))
   (vp x z s p) (: ix (floor x) iz (floor z) ux (x - ix) uz (z - iz)
                   ex (ux * ux * (3.0 - 2.0 * ux)) ez (uz * uz * (3.0 - 2.0 * uz))
                   (h a c) (throw (a % p) (c % p) s 1024 / 1023.0)
                   q0 (h ix iz) q1 (h (ix + 1) iz) q2 (h ix (iz + 1)) q3 (h (ix + 1) (iz + 1))
                   lo (q0 + ex * (q1 - q0)) hi (q2 + ex * (q3 - q2))
                   (lo + ez * (hi - lo)))
   (0.55 * vp (u * 8.0) (v * 8.0) 61 8 + 0.3 * vp (u * 16.0) (v * 16.0) 62 16 + 0.15 * vp (u * 32.0) (v * 32.0) 63 32))
 ; the stars: a few cells of a square lit, each its own brightness
 (star-map _) (: i (iota (star-n * star-n)) x (i % star-n) y (i // star-n)
                 ((throw x y 51 70 = 0) * (0.3 + 0.12 * throw x y 52 5)))
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
   (: m (cloud-map ()) (pins maps 'cloud m 'stars (star-map ()) 0.3 (quantiles m 0.3) 0.0 (quantiles m 0.0))))
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
 ; --- the clouds: a deck high over the eye, where a ray crosses it, in map tiles: two
 ; layers on two winds, and a broad swell that thickens and thins the cover from place
 ; to place. answers [u v] the place on the deck, and the cloud's thickness there. under
 ; three degrees the deck goes on away ever slower, so the rows by the horizon each reach
 ; a little further than the last ---
 deck 1800.0 tile 400.0
 (deck-at dx dy dz ex ez sim) (: tc (deck / over dy (dy < 0.05) (0.025 + 0.025 * exp ((min dy 0.05 - 0.05) / 0.025)))
   [((ex + dx * tc) / tile) ((ez + dz * tc) / tile)])
 (thick mp u v sim f) (: m (mp 'cloud)
   a (bil m cloud-n ((u + sim * 0.006) * 16.0) ((v + sim * 0.0025) * 16.0))
   b (f = 0.0 ? 0.0 (bil m cloud-n ((u + sim * 0.011) * 37.0 + 11.3) ((v - sim * 0.004) * 37.0 - 5.1)))
   sw (bil m cloud-n ((u + sim * 0.002) * 3.0 + 40.0) ((v + sim * 0.001) * 3.0 + 17.0))
   ((1.0 - f) * a + f * b + 0.18 * (sw - 0.5)))
 ; how much cloud down the rays, 0 to 1, as the smooth sky draws it: by the horizon the
 ; deck too far to tell apart, a haze as thick as the cover
 (haze c dy wx sim) (: k (sat (1.0 - dy / 0.06)) (c + 0.85 * k * (sat (1.2 * sky-cover wx sim) - c)))
 (sky-cloud wx dx dy dz ex ez sim) (: mp (sky-maps ()) d (deck-at dx dy dz ex ez sim)
   (: c (haze (sat (0.5 + (thick mp (d 0) (d 1) sim 0.3 - edge wx sim 0.3) * 10.0)) dy wx sim)
      (wx 'cover = 3 ? (max c 0.93) c)))
 ; the cloud over the sun as the light under it feels it: rays over a patch round it, each
 ; with a soft edge, so a passing cloud thins the light and gives it back over a while --
 ; low down, where one ray sweeps the deck fast, most of all
 sun-ring (cat [[0.0 0.0]] (map (k \ (: a (k * pi / 6.0) [(cos a) (sin a)])) ^12))
 (sun-cloud wx s sim) (: mp (sky-maps ()) r 0.05
   (one o) (: d (deck-at (s 0 + r * o 0) (max2 (s 1) 0.05) (s 2 + r * o 1) 0.0 0.0 sim)
              c (sat (0.5 + (thick mp (d 0) (d 1) sim 0.3 - edge wx sim 0.3) * 3.0))   ; a soft edge
              (wx 'cover = 3 ? (max c 0.93) c))
   (net (map one sun-ring) / #sun-ring))
 ; the light of the sun s under the weather: its colour and strength, the share of it
 ; the cloud over it lets through, how much day and twilight there is, the sky's light on
 ; what it sees -- greyer the more cloud -- and the eye's gain against the dark
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
   {'sun s 'day day 'tw tw 'sunk sunk 'sunc sunc 'amb amb 'cover oc 'csun csun
    'expo (1.0 + 1.2 * (1.0 - day) + 0.3 * oc)})
 ; --- the smooth sky. far weighs what lies past the moon, the stars and the sun's own disc:
 ; 0 is the sky nearer than it, what a body in front of them shows; sf the stars alone ---
 (smooth-of lt wx dx dy dz ex ez sim t0 far sf) (: mp (sky-maps ())
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
   d (deck-at dx dy dz ex ez sim) th (thick mp (d 0) (d 1) sim 0.3)
   cl0 (haze (sat (0.5 + (th - edge wx sim 0.3) * 10.0)) dy wx sim)
   cl (wx 'cover = 3 ? (max cl0 0.93) cl0)        ; overcast: no sky through it
   ; ..the clouds: lit from under by the sun, darker the thicker, greyer the more of them
   body ((1.0 - 0.3 * cl - 0.35 * oc * sat ((th - 0.45) * 2.0)) * (sky-fall wx = 1 ? 0.8 1.0))
   cloudc (c* body
              (c+ (c+ (c+ (c* 1.15 (lt 'amb)) (c* (sat ((sy + 0.005) / 0.05) * (1.0 - 0.6 * oc) * (0.55 + 0.4 * sy)) (lt 'sunc)))
                      (c* (lt 'tw) [0.5 0.22 0.14]))
                  (c* (1.0 - lt 'day) [0.06 0.05 0.045])))
   qs (40.0 / max dy 0.05) sk ((floor (dz * qs) % star-n + star-n) % star-n * star-n + (floor (dx * qs) % star-n + star-n) % star-n)
   star (peep (mp 'stars) sk 0.0 * (0.75 + 0.25 * sin (t0 * 0.9 + sk)) * sat (1.0 - lt 'day * 3.0) * (1.0 - cl) * far * sf)
   (c+ (cmix sky0 cloudc cl) [star star star]))
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
 (pixel lt wx dx dy dz ex ez sim t0 sf) (: mp (sky-maps ())
   s (lt 'sun) sx (s 0) sy (s 1) sz (s 2)
   ground (keyed (sx < 0.0 ? evening morning) sy)
   ; ..a cloud's block: its thickness at the block's middle, in four depths over the
   ; cover's edge -- 3 the core down to 0 the faint fringe -- and a die off now and then
   d (deck-at dx dy dz ex ez sim)
   bu ((d 0 + sim * 0.006) * blocks) bv ((d 1 + sim * 0.0025) * blocks)
   cu ((floor bu + 0.5) / blocks - sim * 0.006) cv ((floor bv + 0.5) / blocks - sim * 0.0025)
   th (thick mp cu cv sim 0.0)
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
   ; ..the sun a disc, the moon none, and the stars
   sun ((0.9994 < mu) * (v < 0) * sat ((sy + 0.02) / 0.04))
   qs (40.0 / max dy 0.05) sk ((floor (dz * qs) % star-n + star-n) % star-n * star-n + (floor (dx * qs) % star-n + star-n) % star-n)
   star ((0.0 < peep (mp 'stars) sk 0.0) * (0.6 < sin (t0 * 0.9 + sk)) * (lt 'day < 0.1) * (v < 0) * (0.0 < sf))
   bg (cmix (cmix ground (rgb 0xffd700) sun) (rgb 0xffffd7) star)
   (untone lt (cmix bg cloudc ((0 <= v) * cov))))
 ; the sky's colour down the rays dx dy dz (trays) from the eye at ex ez, under the light
 ; lt and the weather wx, at the time sim and the frame's clock t0 (in frames); sky-colour-of
 ; weighs its stars by sf, 0 for a scene that lays its own
 (sky-colour lt wx dx dy dz ex ez sim t0) (sky-colour-of lt wx dx dy dz ex ez sim t0 1.0)
 (sky-colour-of lt wx dx dy dz ex ez sim t0 sf)
  (wx 'style = 'pixel ? (pixel lt wx dx dy dz ex ez sim t0 sf) (smooth-of lt wx dx dy dz ex ez sim t0 1.0 sf))
 ; ..and the sky nearer than the moon: no stars and no sun's disc
 (sky-near lt wx dx dy dz ex ez sim)
  (wx 'style = 'pixel ? (pixel lt wx dx dy dz ex ez sim 0.0 1.0) (smooth-of lt wx dx dy dz ex ez sim 0.0 0.0 1.0))
 ; --- what falls: rain in streaks and snow in flakes, drawn into a scene's buffers -- 't
 ; the depth, 'r 'g 'b the colour -- through a camera (grove's: 'e 'f 'r 'u 'w 'h 'foc),
 ; at sec seconds of the scene's own clock. no state: a drop is where its number and the
 ; clock put it, on a lattice fixed to the ground and wrapped round the eye, so walking
 ; through it is walking through weather; nearer than the scene or not drawn ---
 fall-r 6.0 fall-h 9.0 rain-n 1600 snow-n 1400
 (sky-fall! wx cam lt buf sec) (: f (sky-fall wx)
   (f = 0 ? buf
      (: e (cam 'e) fw (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
         n (f = 1 ? rain-n snow-n) i (iota n) R fall-r H fall-h
         (rnd k) (frac (sin (i * 12.9898 + k * 78.233) * 43758.5453))
         v (f = 1 ? 7.5 1.1) sway (f = 1 ? 0.0 0.25)
         (wrap w0 c) (c + 2.0 * R * (frac ((w0 - c) / (2.0 * R)) - 0.5))
         X0 (wrap (2.0 * R * rnd 1 + sway * sin (sec * 0.7 + 6.3 * rnd 4)) (e 0))
         Z0 (wrap (2.0 * R * rnd 2 + sway * cos (sec * 0.5 + 6.3 * rnd 5)) (e 2))
         Y0 (H * (1.0 - frac (rnd 3 + sec * v / H)))
         ; ..a drop is a streak three points long, a flake a point and its neighbour
         (one dy) (: Y (Y0 + dy) qx (X0 - e 0) qy (Y - e 1) qz (Z0 - e 2)
                     zc (qx * fw 0 + qy * fw 1 + qz * fw 2) zs (max zc 0.1)
                     cx (floor (w / 2.0 + foc * (qx * rt 0 + qy * rt 1 + qz * rt 2) / zs))
                     cy (floor (h / 2.0 - foc * (qx * uv 0 + qy * uv 1 + qz * uv 2) / zs))
                     dist (sqrt (qx * qx + qy * qy + qz * qz))
                     ok ((0.1 < zc) * (0 <= cx) * (cx < w) * (0 <= cy) * (cy < h))
                     idx (over -1 ok (cy * w + cx))
                     i2 (over -1 (dist < peep (buf 't) idx 1e9) idx)
                     a ((f = 1 ? 0.38 0.85) * sat (1.4 - dist / R))
                     tc (f = 1 ? (c* 0.95 (c+ (lt 'amb) [0.08 0.09 0.11]))
                                 (c+ (c* 1.5 (lt 'amb)) (c* (0.4 * lt 'sunk) (lt 'sunc))))
                     (old k) (peep (buf k) i2 0.0)
                     (pins buf 'r (pin (buf 'r) i2 (old 'r + a * (tc 0 - old 'r)))
                               'g (pin (buf 'g) i2 (old 'g + a * (tc 1 - old 'g)))
                               'b (pin (buf 'b) i2 (old 'b + a * (tc 2 - old 'b)))))
         _ (each (f = 1 ? [0.0 0.07 0.14] [0.0 0.012]) one)
         buf)))
 ; ..and the eye: its gain against the dark under lt, and a soft shoulder that keeps a hue
 (sky-tone lt col) (: k (1.5 * lt 'expo)
   [(1.0 - exp (0.0 - k * col 0)) (1.0 - exp (0.0 - k * col 1)) (1.0 - exp (0.0 - k * col 2))]))
) ; module sky
