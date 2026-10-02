; meadow -- the grass game's field in three dimensions: the eye a few inches off the dirt
; behind your blade, looking north along the row, the meadow running on behind it to the
; haze, the sky over all of it. the game is grass's and unchanged: its state is drawn
; here as it stands, each blade bent by its own lean, stretch and bow, the field behind
; swaying on the same wind, the shadows thrown along the sun, and the day's cover as the
; sky's weather. south of the line, so the sun crosses the sky in front, east on the right
; as the flat field has it.
;
; a frame is trays a picture wide: the ground or the sky behind every pixel, then the
; blades drawn over it far to near, a point a pixel -- a scatter's later write wins, so
; the order is the depth.
(module (meadow meadow-new meadow-size meadow-pens meadow-frame meadow-sky meadow-light
         meadow-weather cellm eye)
(borrow 'view)
(borrow 'vec)
(borrow 'sky)
(:
 cellm 0.00635                          ; a flat cell's width, a quarter inch, in metres
 inch 0.0254
 lat (-34.6 * pi / 180.0)               ; south of the line: the sun in the north
 ; the equinox, so the sun is up from six to six as the game's daylight has it
 day0 (86400.0 * 20532.0)
 eye [0.0 0.1 -0.22]                    ; four inches up, nine back
 pitch -0.08
 lift-lo 0.12 lift 2.6                  ; the sky's lens: the horizon at 7 degrees, each degree over it 2.6
 near-z 0.12                           ; the bare dirt behind the row, before the meadow
 deep-z 2.6                             ; how far the meadow's own blades run
 field-n 700
 ; --- the screen: w by h pixels, and each pixel's ray, and where it meets the dirt ---
 (meadow-size st w h) (: n (w * h) i (iota n) x (i % w) y (i // w)
   U ((x + 0.5 - w / 2.0) / (w / 2.0)) V ((h / 2.0 - y - 0.5) / (w / 2.0))
   sp (sin pitch) cp (cos pitch)
   dx0 U dy0 (sp + V * cp) dz0 (cp - V * sp)
   ln (sqrt (dx0 * dx0 + dy0 * dy0 + dz0 * dz0))
   dx (dx0 / ln) dy (dy0 / ln) dz (dz0 / ln)
   gnd (dy < -0.0005) t (over 0.0 gnd ((0.0 - eye 1) / min dy -0.0005))
   ; ..and the sky through a lens: the strip over the horizon a blade's eye sees is
   ; lifted and stretched to show the sky high overhead, so the clouds stand large and
   ; the sun crosses the picture, as they do on the flat field
   hl (sqrt (dx * dx + dz * dz)) el (lift-lo + lift * atan (max dy 0.0 / sqrt (max (1.0 - dy * dy) 1e-6))) cl (cos el)
   _ (pins st 'sdx (dx / hl * cl) 'sdy (sin el) 'sdz (dz / hl * cl))
   (pins st 'w w 'h h 'foc (w / 2.0) 'dx dx 'dy dy 'dz dz 'gnd gnd
            'gx (eye 0 + t * dx) 'gz (eye 2 + t * dz) 'G (iota gnd) 'S (iota (1 - gnd))
            'bay (view-bayer w h) 'f [0.0 sp cp] 'u [0.0 cp (0.0 - sp)]))
 ; --- the meadow behind the row: blades thrown once, each as the points it is drawn by,
 ; more of them the nearer it stands, the whole far to near ---
 (rnd g) (: s ((g 's * 1103515245 + 12345) % 2147483648) (pin g 's s, s / 2147483648.0))
 (field seed foc) (: g {'s (seed % 2147483647 + 1)}
   bl (map (_ \ (: z (near-z + sq (rnd g) * (deep-z - near-z)) hw ((z - eye 2) * 1.15)
                   [(rnd g * 2.0 * hw - hw) z ((1.5 + 2.0 * rnd g) * inch) (rnd g * 6.283) (rnd g)]))
           ^field-n)
   far (sort (map (b \ [(0.0 - b 1) b]) bl))
   pts (foldl (acc \ e \ (: b (e 1) k (max2 2 (min2 14 (int (b 2 * foc / (b 1 - eye 2) * 1.2) + 1)))
                            (foldl (a \ j \ ([(b 0) (b 1) (b 2) (b 3) (b 4) ((j + 1.0) / k)] . a)) acc ^k)))
              () far)
   ps (rev pts)
   (col k) (gem-tray [#ps] (map (p \ p k) ps))
   {'x (col 0) 'z (col 1) 'L (col 2) 'ph (col 3) 'hue (col 4) 'u (col 5)})
 (meadow-new seed w h) (: st (meadow-size {'seed seed} w h)
                          (pin st 'field (field seed (st 'foc))))
 ; --- the hour and the weather from the game ---
 (meadow-sun g) (sky-sun (day0 + (g 'h % 24.0) * 3600.0) 0.0 lat)
 ; the clouds ride a clock of their own, a slow one: the game's day is a minute
 (cloud-sim g) (g 'fr * 2.0)
 (meadow-weather g style) (: d (int (g 'h / 24.0) @ v (6 < v ? 6 v)) c (g 'covers d)
   (sky-weather (? (c < 0.2) 0 (c < 0.5) 1 (c < 0.8) 2 3) style))
 (meadow-light g wx) (sky-light (meadow-sun g) wx (cloud-sim g))
 ; --- a blade as points: base x0 z0, length L, its lean A at the tip and its bow, at u
 ; along it. the lean grows along the blade, so it curves as a stem does ---
 (bent x0 z0 L A bw u) (: a (A + 1e-4) au (a * u)
   [(x0 + L * (1.0 - cos au) / a + bw * sin (pi * u)) (L * sin au / a) z0])
 ; ..each point to the screen: its pixel, -1 off it, and its distance
 (to-screen st p) (: e eye f (st 'f) uv (st 'u) w (st 'w) h (st 'h) foc (st 'foc)
   qx (p 0 - e 0) qy (p 1 - e 1) qz (p 2 - e 2)
   zc (qy * f 1 + qz * f 2)
   zs (max zc 0.01)
   cx (floor (w / 2.0 + foc * qx / zs))
   cy (floor (h / 2.0 - foc * (qy * uv 1 + qz * uv 2) / zs))
   ok ((0.01 < zc) * (0 <= cx) * (cx < w) * (0 <= cy) * (cy < h))
   [(over -1 ok (cy * w + cx)) cx cy])
 ; --- the dirt: patches of brown, a pebble now and then, greener toward the haze ---
 (rgb x) [((x // 65536) / 255.0) ((x // 256 % 256) / 255.0) ((x % 256) / 255.0)]
 dirts [0x875f00 0xaf5f00 0x875f00 0xaf875f 0x5f3f1f]
 (pick ls k) (: a (rgb (ls 0)) (foldl (acc \ i \ cmix acc (rgb (ls i)) (k = i)) a ^#ls))
 (dirt gx gz) (: ix (floor (gx / 0.01)) iz (floor (gz / 0.01))
   pk (throw (floor (ix / 4.0)) (floor (iz / 3.0)) 13 #dirts)
   dot (throw ix iz 17 7 = 0)
   base (c* 0.45 (pick dirts pk))
   peb (c* 0.7 (rgb 0xaf875f))
   haze (sat ((gz - 1.2) / (deep-z - 1.2)))
   (cmix (cmix base peb dot) [0.1 0.22 0.05] (0.85 * haze)))
 ; --- the frame's colours, three trays a picture wide ---
 (meadow-pens st g wx) (: lt (meadow-light g wx) s (lt 'sun) sim (cloud-sim g) t0 (g 'fr)
   w (st 'w) h (st 'h) G (st 'G) S (st 'S) (only ix v) (peep v ix 0.0)
   wxv ((0.0 - sin (g 'head * pi / 180.0) * g 'wind) * g 'gust)
   ; the sky behind, and the dirt under, each where it shows
   hv (sky-colour lt wx (only S (st 'sdx)) (only S (st 'sdy)) (only S (st 'sdz)) (eye 0) (eye 2) sim t0)
   gx (only G (st 'gx)) gz (only G (st 'gz))
   alb (dirt gx gz)
   ; ..the shadows, the blades' points thrown down the sun onto the dirt
   sunup (0.02 < s 1)
   fd (st 'field) c (g 'c)
   ; the row's own blades, as points: a lean from th, a stretch from s, a bow when squeezed.
   ; you last, so you stand in front of whoever shares your pixels
   bs (cat (filter (b \ !(b 'me)) (g 'bs)) (filter (b \ b 'me) (g 'bs)))
   kr 20
   rx (gem-tray [#bs] (map (b \ (b 'x - c / 2.0) * cellm) bs))
   rz (gem-tray [#bs] (map (b \ throw (b 'x) 0 19 9 * 0.002 - 0.008) bs))
   rL (gem-tray [#bs] (map (b \ b 'ht * inch * (1.0 + b 's)) bs))
   rA (gem-tray [#bs] (map (b \ b 'th * 0.9) bs))
   rB (gem-tray [#bs] (map (b \ (b 's < -0.1 ? ((b 'th < 0.0 ? -1.5 1.5) * (-0.1 - b 's)) 0.0) * cellm * 4.0) bs))
   rme (gem-tray [#bs] (map (b \ b 'me * 1.0) bs))
   rwt (gem-tray [#bs] (map (b \ b 'hy < 12.0 ? 1.0 (b 'hy < 25.0 ? ((25.0 - b 'hy) / 26.0) 0.0)) bs))
   n #bs j (iota (n * kr))
   bix (j // kr) u ((j % kr + 1.0) / kr)
   (rf v) (peep v bix 0.0)
   rp (bent (rf rx) (rf rz) (rf rL) (rf rA) (rf rB) u)
   ; the meadow's: swaying on the wind as the row does, each its own phase
   fu (fd 'u) sway (0.05 * wxv * (1.0 + 0.35 * sin (t0 / 30.0 * 2.2 + fd 'ph)))
   fp (bent (fd 'x) (fd 'z) (fd 'L) (max -1.2 (min 1.2 sway)) 0.0 fu)
   ; shadows: each point down the sun to the dirt, darkening the pixel it lands on
   (cast p) (: k (p 1 / max (s 1) 0.05) [(p 0 - k * s 0) 0.0 (p 2 - k * s 2)])
   shp (sunup ? (pin (pin (iota (w * h) * 0) (to-screen st (cast fp) 0) 1) (to-screen st (cast rp) 0) 1) (iota (w * h) * 0))
   shg (only G shp)
   irr (c+ (c* 0.95 (lt 'amb)) (c* ((1 - shg) * lt 'sunk * max (s 1) 0.0) (lt 'sunc)))
   gc (cm alb irr)

   z0 (st 'dx * 0.0)
   col0 (map (k \ pin (pin z0 G (gc k)) S (hv k)) ^3)
   ; --- the blades, far to near: the meadow's, then the row's ---
   (green hue u wilt mu) (: base (cmix [0.05 0.16 0.03] [0.16 0.4 0.07] u)
                            tint (c+ base (c* (hue * 0.06) [0.6 0.4 -0.1]))
                            dry (cmix [0.2 0.17 0.07] [0.5 0.45 0.18] u)
                            (cmix tint dry wilt))
   (shade al u mu) (: glow (lt 'sunk * sq (sat ((mu - 0.4) / 0.6)))
                      irr2 (c+ (c* (0.8 + 0.25 * u) (lt 'amb)) (c* (0.45 * lt 'sunk * (0.4 + 0.6 * u)) (lt 'sunc)))
                      (c+ (cm al irr2) (c* glow [0.12 0.3 0.02])))
   (mu-of p) (: qx (p 0 - eye 0) qy (p 1 - eye 1) qz (p 2 - eye 2) d (sqrt (qx * qx + qy * qy + qz * qz))
                ((qx * s 0 + qy * s 1 + qz * s 2) / d))
   dry0 (net rwt / max2 1 n * 0.6)
   fcol (shade (green (fd 'hue) fu dry0 0.0) fu (mu-of fp))
   rcol0 (shade (green (rf rme * 0.8) u (rf rwt) 0.0) u (mu-of rp))
   rcol (cmix rcol0 (c+ (c* 1.4 rcol0) (c* (0.3 + 0.7 * lt 'day) [0.05 0.12 0.0])) (rf rme))
   fi (to-screen st fp 0) ri (to-screen st rp 0)   ; ..you are a pixel wider, so you read among the rest
   ri2 (to-screen st [(rp 0 + 0.0018 * rf rme) (rp 1) (rp 2)] 0)
   ri2m (over -1 (rf rme > 0.5) ri2)
   col1 (map (k \ pin (pin (pin (col0 k) fi (fcol k)) ri (rcol k)) ri2m (rcol k)) ^3)
   (sky-tone lt col1))
 ; the picture: 24-bit where the seat says so, else the palette dithered
 (meadow-frame st g wx deep) (: w (st 'w) h (st 'h) c (meadow-pens st g wx)
   px (deep ? (view-deep-pens c) (view-cube-pens c (st 'bay * 0.5 + 0.25)))
   (deep ? (view-deep-frame w h px {}) (view-frame w h (y \ peep px (iota w + w * y) 0) {})))
 (meadow-sky g) (meadow-weather g 'pixel))
) ; module meadow
