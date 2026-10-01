; sky -- the sky over a scene at an hour: the sun by the day of the year, the solar hour
; and the latitude, the light that follows from it, and the colour of the sky down any
; ray -- blue by day, warm toward the sun at either end of it, stars at night through a
; city's glow, and clouds on the wind lit from under them. the clouds and stars are maps
; laid once a run and gathered from by every frame.
;
; a scene's time is local seconds 'sim and the summer offset 'dst; its rays are trays of
; unit directions [east up north]. the clouds take knobs, a tablet laid over sky-clouds:
;   'cover  how much of the sky is cloud, 0 to 1, a function of the time
;   'scale  how far a cloud map's tile spans overhead, in metres
;   'high   the clouds' height, in metres
;   'wind   [east north] how far the clouds go a second, in tiles
;   'sharp  how hard their edges are
(module (sky sky-sun sky-light sky-maps sky-clouds sky-colour sky-tone bil cloud-n star-n day-secs)
(borrow 'view)
(borrow 'vec)
(:
 (day-secs s) (s - 86400.0 * floor (s / 86400.0))
 ; the sun as [east up north], a unit vector, by solar time and the day of the year
 (sky-sun sim dst lat) (: s (sim - dst) hr (day-secs s / 3600.0)
   doy (s / 86400.0 - 10957.0 - 365.2422 * floor ((s / 86400.0 - 10957.0) / 365.2422))
   dec (-0.4091 * cos (2.0 * pi * (doy + 10.0) / 365.2422))
   ha ((hr - 12.0) * pi / 12.0)
   [(0.0 - cos dec * sin ha)
    (sin lat * sin dec + cos lat * cos dec * cos ha)
    (cos lat * sin dec - sin lat * cos dec * cos ha)])
 ; the light of the sun s: its colour and strength, how much day and twilight there is,
 ; the sky's light on what it sees, and the eye's gain against the dark
 (sky-light s) (: sy (s 1)
   day (sat ((sy + 0.06) / 0.3))
   tw (sat (1.0 - mag (sy + 0.03) / 0.2))
   sunk (sat ((sy + 0.005) / 0.05))
   sunc (cmix [1.0 0.4 0.1] [1.0 0.93 0.82] (sat ((sy - 0.04) / 0.4) @ k (k * k * (3.0 - 2.0 * k))))
   night [0.05 0.055 0.075]
   amb (c+ (cmix night [0.42 0.47 0.56] day) (c* (tw * (1.0 - 0.5 * day)) [0.1 0.05 0.07]))
   {'sun s 'day day 'tw tw 'sunk sunk 'sunc sunc 'amb amb 'expo (1.0 + 1.2 * (1.0 - day))})
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
 (sky-maps _) (maps 'cloud ? maps (pins maps 'cloud (cloud-map ()) 'stars (star-map ())))
 ; a square map at fractional texels, bilinear, wrapping
 (bil tab n x z) (: ix (floor x) iz (floor z) ux (x - ix) uz (z - iz)
                    (w i) ((i % n + n) % n)
                    x0 (w ix) x1 (w (ix + 1)) z0 (w iz * n) z1 (w (iz + 1) * n)
                    (g k) (peep tab k 0.0)
                    lo (g (z0 + x0) @ q (q + ux * (g (z0 + x1) - q)))
                    hi (g (z1 + x0) @ q (q + ux * (g (z1 + x1) - q)))
                    (lo + uz * (hi - lo)))
 ; the clouds' knobs, and a scene's own laid over them
 sky-clouds {'cover (sim \ 0.4 + 0.22 * sin (sim / 20000.0) + 0.1 * sin (sim / 7300.0))
             'scale 900.0 'high 1800.0 'wind [0.006 0.0025] 'sharp 3.2}
 (knob kn k) (peep kn k (sky-clouds k))
 ; the sky's colour down the rays dx dy dz (trays) from the eye at ex ez, under the light
 ; lt, at the time sim and the frame's clock t0 (in frames), the clouds by the knobs kn
 (sky-colour lt dx dy dz ex ez sim t0 kn) (: mp (sky-maps ())
   s (lt 'sun) sx (s 0) sy (s 1) sz (s 2)
   mu (dx * sx + dy * sy + dz * sz)
   up (sat dy)
   blue (cmix [0.55 0.7 0.9] [0.2 0.42 0.84] (sat (up * 1.3)))
   dark (c+ [0.012 0.016 0.04] (c* (0.06 * (1.0 - up)) [0.6 0.45 0.3]))
   warm (sat ((mu + 0.3) / 1.3))
   dusk (c* (lt 'tw * (1.0 - 0.5 * lt 'day)) (c+ (c* (warm * warm * warm) [0.9 0.38 0.16]) [0.22 0.12 0.28]))
   disc (sat ((mu - 0.9995) * 4000.0))
   halo (0.35 * lt 'day * exp ((mu - 1.0) * 60.0))
   sky0 (c+ (c+ (cmix dark blue (lt 'day)) dusk) (c* (halo + 3.0 * disc * lt 'sunk) (lt 'sunc)))
   ; ..the clouds: the ray's crossing of their height, on the map, blown by the wind
   sc (knob kn 'scale) wd (knob kn 'wind)
   tc (knob kn 'high / max dy 0.05)
   kx ((ex + dx * tc) / sc + sim * wd 0) kz ((ez + dz * tc) / sc + sim * wd 1)
   cn (bil (mp 'cloud) cloud-n (kx * 16.0) (kz * 16.0))
   cover (knob kn 'cover sim)
   cl (sat ((cn - (1.0 - cover)) * knob kn 'sharp))
   cloudc (c* (1.0 - 0.3 * cl)
              (c+ (c+ (c+ (c* 1.15 (lt 'amb)) (c* (lt 'sunk * (0.55 + 0.4 * sy)) (lt 'sunc)))
                      (c* (lt 'tw) [0.5 0.22 0.14]))
                  (c* (1.0 - lt 'day) [0.06 0.05 0.045])))
   qs (40.0 / max dy 0.05) sk ((floor (dz * qs) % star-n + star-n) % star-n * star-n + (floor (dx * qs) % star-n + star-n) % star-n)
   star (peep (mp 'stars) sk 0.0 * (0.75 + 0.25 * sin (t0 * 0.9 + sk)) * sat (1.0 - lt 'day * 3.0) * (1.0 - cl))
   (c+ (cmix sky0 cloudc cl) [star star star]))
 ; ..and the eye: its gain against the dark under lt, and a soft shoulder that keeps a hue
 (sky-tone lt col) (: k (1.5 * lt 'expo)
   [(1.0 - exp (0.0 - k * col 0)) (1.0 - exp (0.0 - k * col 1)) (1.0 - exp (0.0 - k * col 2))]))
) ; module sky
