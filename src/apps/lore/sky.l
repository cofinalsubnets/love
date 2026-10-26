; sky -- the sky over a scene, by the hour and the weather: the sun from day of year, solar
; hour and latitude, and its light; cloud cover, lit on the side toward the sun. cloud over
; the sun takes it off the scene. the cloud map is laid once a run; stars are points a scene
; lays a pixel each.
; time is local seconds 'sim and summer offset 'dst; rays are trays of unit [east up north].
; weather (sky-weather cover): cover 0 to 3; 'fall 0 none (default), 1 rain, 2 snow;
; 'smog 0 (default) to 1, the sky and its light browned toward orange. a light with
; 'turn, the eye's axes in the world's, has the sky's clouds fixed in the world, far
; off as the stars, not a deck over the eye, and the sky all round, below the eye's
; horizon too: sky-lit's csun then sky-orb-cloud's
(module (sky sky-sun sky-body sky-light sky-lit sky-orb-cloud sky-maps sky-weather turns lap sky-cover sky-cloud sky-colour-of sky-colour-at sky-near sky-tone
         sky-irr sky-stars sky-stars! sky-covers sky-says sky-falls sky-fall sky-drops bil cloud-n day-secs rgb)
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
 sky-says ["clear" "partly cloudy" "mostly cloudy" "overcast"]
 (sky-weather cover) {'cover cover}
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
 ; the clouds' thickness, a square that tiles: value noise on lattices that wrap, read through
 ; a slow warp so no lattice shows, its finer two puffed toward billows
 (cloud-map _) (: n cloud-n i (iota (n * n)) u (i % n / (1.0 * n)) v (i // n / (1.0 * n))
   (vp x z s p) (: ix (floor x) iz (floor z) ux (x - ix) uz (z - iz)
                   ex (ux * ux * (3.0 - 2.0 * ux)) ez (uz * uz * (3.0 - 2.0 * uz))
                   (h a c) (throw (wrap-n a p) (wrap-n c p) s 1024 / 1023.0)
                   q0 (h ix iz) q1 (h (ix + 1) iz) q2 (h ix (iz + 1)) q3 (h (ix + 1) (iz + 1))
                   lo (q0 + ex * (q1 - q0)) hi (q2 + ex * (q3 - q2))
                   (lo + ez * (hi - lo)))
   x (u + 0.06 * (vp (u * 4.0) (v * 4.0) 71 4 - 0.5)) z (v + 0.06 * (vp (u * 4.0) (v * 4.0) 72 4 - 0.5))
   (puff q) (0.7 * q + 0.3 * (1.0 - mag (2.0 * q - 1.0)))
   (0.55 * vp (x * 8.0) (z * 8.0) 61 8 + 0.3 * puff (vp (x * 16.0) (z * 16.0) 62 16) + 0.15 * puff (vp (x * 32.0) (z * 32.0) 63 32)))
 maps {}
 ; ..and where the clouds' thickness stands at each hundredth of the sky, so a cover's
 ; share is the share of sky its clouds take: thick's own mix of the map, shuffled
 fine 0.3                               ; the fine layer's weight
 (quantiles m f) (: n (cloud-n * cloud-n) i (iota n)
   (sh k) (m ((i * k + 7919 * k) % n))
   t ((1.0 - f) * m + f * sh 7 + 0.18 * (sh 13 - 0.5))
   l (sort (map t ^n))
   (map (q \ l (q * (n - 1) // 100)) ^101))
 (sky-maps _) (maps 'cloud ? maps
   (: m (cloud-map ()) (pins maps 'cloud m 'edges (quantiles m fine))))
 ; the thickness a cover's clouds start at
 (edge wx sim) (sky-maps () 'edges (int ((1.0 - min 1.0 (sky-cover wx sim)) * 100.0 + 0.5)))
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
 (deck-low dy) (over dy (dy < 0.05) (0.025 + 0.025 * exp ((min dy 0.05 - 0.05) / 0.025)))
 (deck-at dx dy dz ex ez sim) (: tc (deck / deck-low dy)
   [((ex + dx * tc) / tile) ((ez + dz * tc) / tile)])
 ; ..how many tiles of the deck lie between rays a radians apart, across the ray: what a
 ; turn of the eye slides them over
 (deck-fp a dy) (a * deck / (deck-low dy * tile))
 (thick wx mp u v sim) (thick-fp wx mp u v sim 0.0)
 ; ..each layer toward its middle as a sample spans more of its texels, fp tiles a sample,
 ; so what a ray cannot tell apart never shimmers as the eye turns
 (thick-fp wx mp u v sim fp) (: m (mp 'cloud) f fine (seen q) (1.0 / (1.0 + sq (fp * q)))
   a (bil m cloud-n ((u + sim * lap wx 0.006 16.0) * 16.0) ((v + sim * lap wx 0.0025 16.0) * 16.0))
   b (bil m cloud-n ((u + sim * lap wx 0.011 37.0) * 37.0 + 11.3) ((v + sim * lap wx -0.004 37.0) * 37.0 - 5.1))
   sw (bil m cloud-n ((u + sim * lap wx 0.002 3.0) * 3.0 + 40.0) ((v + sim * lap wx 0.001 3.0) * 3.0 + 17.0))
   ; ..each layer's features a tile: the map's lattice of 32 across its 128 texels, mostly
   ; its 8 and 16
   ((1.0 - f) * (0.5 + seen 2.0 * (a - 0.5)) + f * (0.5 + seen 4.6 * (b - 0.5)) + 0.18 * seen 0.4 * (sw - 0.5)))
 ; ..and the spread a sample's thickness hides under its mean, the map's about 0.2 a layer
 (thick-sd fp) (: f fine (lost q w) (: k (1.0 / (1.0 + sq (fp * q))) (sq w * (1.0 - k * k)))
   (0.2 * sqrt (lost 2.0 (1.0 - f) + lost 4.6 f + lost 0.4 0.18)))
 ; how much cloud down the rays, 0 to 1, as the sky draws it: by the horizon the
 ; deck too far to tell apart, a haze as thick as the cover
 (haze c dy wx sim) (: k (sat (1.0 - dy / 0.06)) (c + 0.85 * k * (sat (1.2 * sky-cover wx sim) - c)))
 ; ..past where the cover starts, k as sharp; at a full cover, never under 0.93
 (thick-at wx mp d sim k) (sat (0.5 + (thick wx mp (d 0) (d 1) sim - edge wx sim) * k))
 (clouded wx c) (wx 'cover = 3 ? (max c 0.93) c)
 (sky-cloud wx dx dy dz ex ez sim) (: mp (sky-maps ()) d (deck-at dx dy dz ex ez sim)
   (clouded wx (haze (thick-at wx mp d sim 10.0) dy wx sim)))
 ; ..clouds fixed in the world down world rays W: the map laid on each axis's plane, as many
 ; tiles a radian as the deck overhead, the far half of each turned off it, and blended so
 ; each holds only near its own axis -- no seam anywhere
 orb-k (deck / tile)
 (orb-thick wx mp W sim fp) (: (wt k) (sq (sq (sq (W k)))) ws (wt 0 + wt 1 + wt 2)
   (face k) (: a (W ((k + 1) % 3)) b (W ((k + 2) % 3)) o (37.0 * (W k < 0.0) + 11.0 * k)
     (wt k * thick-fp wx mp (a * orb-k + o) (b * orb-k - o) sim fp))
   ((face 0 + face 1 + face 2) / ws))
 ; ..the cloud down rays X Y Z as lt's sky draws it: the deck's, or under 'turn the world's
 (sky-cloud-lt lt wx X Y Z ex ez sim) (peep lt 'turn () @ B
   (? !(two? B) (sky-cloud wx X Y Z ex ez sim)
      (: W (map (j \ X * B 0 j + Y * B 1 j + Z * B 2 j) ^3) mp (sky-maps ())
         (clouded wx (haze (sat (0.5 + (orb-thick wx mp W sim 0.0 - edge wx sim) * 10.0)) (max Y (0.0 - Y)) wx sim)))))
 ; ..and the cloud over the sun, world way s, a soft edge
 (sky-orb-cloud wx s sim) (: mp (sky-maps ()) W (map (k \ gem-tray [1] [(1.0 * s k)]) ^3)
   (clouded wx (sat (0.5 + (orb-thick wx mp W sim 1.0 - edge wx sim) * 3.0)) 0))
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
 (sky-light s wx sim) (sky-lit s wx sim (s 1 <= 0.0 ? 0.0 (sun-cloud wx s sim)))
 ; ..its cloud over the sun given, csun 0 to 1
 (sky-lit s wx sim csun) (: sy (s 1)
   oc (sky-cover wx sim)
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
 ; --- the sky. far weighs what lies past the moon, the sun's own disc: 0 is the
 ; sky nearer than it, what a body in front of it shows ---
 (paint lt wx dx dy dz ex ez sim far a) (: mp (sky-maps ())
   s (lt 'sun) sx (s 0) sy (s 1) sz (s 2) oc (lt 'cover)
   mu (dx * sx + dy * sy + dz * sz)
   ; ..under a light with 'turn the sky is all round, as high below the eye's horizon as above
   B (peep lt 'turn ()) dh (two? B ? (max dy (0.0 - dy)) dy)
   up (sat dh)
   blue (cmix [0.55 0.7 0.9] [0.2 0.42 0.84] (sat (up * 1.3)))
   dark (c+ [0.012 0.016 0.04] (c* (0.06 * (1.0 - up)) [0.6 0.45 0.3]))
   warm (sat ((mu + 0.3) / 1.3))
   dusk (c* (lt 'tw * (1.0 - 0.5 * lt 'day)) (c+ (c* (warm * warm * warm) [0.9 0.38 0.16]) [0.22 0.12 0.28]))
   disc (sat ((mu - 0.9995) * 4000.0))
   halo (0.35 * lt 'day * exp ((mu - 1.0) * 60.0))
   sky0 (c+ (c+ (cmix dark blue (lt 'day)) dusk) (c* (halo + 3.0 * far * disc * lt 'sunk) (lt 'sunc)))
   fp (two? B ? (a * orb-k) (deck-fp a dy))
   (th-of dx dy dz) (? (two? B) (orb-thick wx mp (map (j \ dx * B 0 j + dy * B 1 j + dz * B 2 j) ^3) sim fp)
                       (: d (deck-at dx dy dz ex ez sim) (thick-fp wx mp (d 0) (d 1) sim fp)))
   th (th-of dx dy dz)
   ; ..and a step toward the sun: thinner there, this side faces it
   ts (: n 0.025 X (dx + n * sx) Y (dy + n * sy) Z (dz + n * sz) l (sqrt (X * X + Y * Y + Z * Z))
        (th-of (X / l) (Y / l) (Z / l)))
   ; ..the edge as wide as that spread: the share of the sample past it, not a fringe
   cl0 (haze (sat (0.5 + (th - edge wx sim) / sqrt (0.0016 + 2.0 * sq (thick-sd fp)))) dh wx sim)
   cl (clouded wx cl0)                          ; overcast: no sky through it
   ; ..the clouds: lit on the side toward the sun, darker the thicker, greyer the more of them
   ; ..and under smog the thick of them darker still and the thin lit through
   sm (peep wx 'smog 0.0)
   core (sat ((th - edge wx sim) * 5.0))
   lit (sat (0.45 + 6.0 * lt 'day * (th - ts)))
   body ((0.62 + 0.5 * lit - 0.3 * core - 0.2 * oc * core) * (sky-fall wx = 1 ? 0.8 1.0)
         * (1.0 - 0.45 * sm) * (1.0 - 0.6 * sm * sat ((th - 0.3) * 2.2) + 0.5 * sm * sat ((0.4 - th) * 3.0)))
   cloudc (c* body
              (c+ (c+ (sky-irr lt 1.15 (sat ((sy + 0.005) / 0.05) * (1.0 - 0.6 * oc) * (0.55 + 0.4 * sy)))
                      (c* (lt 'tw) [0.5 0.22 0.14]))
                  (c* (1.0 - lt 'day) [0.06 0.05 0.045])))
   (smoggy wx (cmix sky0 cloudc cl)))
 ; a colour said as 0xrrggbb
 (rgb x) [((x // 65536) / 255.0) ((x // 256 % 256) / 255.0) ((x % 256) / 255.0)]
 ; the sky's colour down the rays dx dy dz (trays) from the eye at ex ez, under the light
 ; lt and the weather wx, at the time sim, the sun's disc in it; the stars are sky-stars!'s
 (sky-colour-of lt wx dx dy dz ex ez sim) (sky-colour-at lt wx 0.0 dx dy dz ex ez sim)
 ; ..its rays a radians apart, the clouds no finer than they tell apart
 (sky-colour-at lt wx a dx dy dz ex ez sim) (paint lt wx dx dy dz ex ez sim 1.0 a)
 ; ..and the sky nearer than the moon: no sun's disc
 (sky-near lt wx dx dy dz ex ez sim) (paint lt wx dx dy dz ex ez sim 0.0 0.0)
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
    'b (stars0 'b * sat (y / 0.1)) 'b0 (stars0 'b) 'ph (stars0 'ph) 'tint (stars0 'tint)})
 ; ..their light added to the colours c, [r g b] trays before the eye's gain, ix each of
 ; ss's stars' place in them, -1 where it is not on the open sky: dimmed by the cloud before
 ; it, twinkling by the frame's clock t0
 (sky-stars! ss c lt wx ex ez sim t0 ix) (: nt (sat (1.0 - lt 'day * 3.0))
   (nt <= 0.0 ? c
    (: X (ss 'x) Y (ss 'y) Z (ss 'z)
       cl (sky-cloud-lt lt wx X Y Z ex ez sim)
       tw (sin (t0 * turns wx 'tper 0.9 + ss 'ph))
       v (ss 'b * (0.75 + 0.25 * tw) * nt * (1.0 - cl))
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
