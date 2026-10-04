; meadow -- the grass game's field in three dimensions: the eye a few inches off the dirt
; behind your blade, looking south along the row, the meadow running on behind it to green
; hills paling into the air, the sky over all of it, the sun and the moon crossing it. the
; game is grass's and unchanged: its state is drawn here as it stands, each blade bent by
; its own lean, stretch and bow, the field behind swaying on the same wind, the shadows
; thrown along the sun, and the day's cover as the sky's weather. new york's sky, seen in
; a mirror: east on the right, as the flat field has it.
;
; a frame is trays a picture wide: the land or the sky behind every pixel -- where each ray
; meets the land is found once, the eye and the hills holding still -- then the
; blades drawn over it far to near, a point a pixel -- a scatter's later write wins, so
; the order is the depth.
(module (meadow meadow-new meadow-size meadow-pens meadow-frame meadow-sky meadow-light
         meadow-weather meadow-bodies cellm eye)
(borrow 'view)
(borrow 'vec)
(borrow 'sky)
(:
 cellm 0.00635                          ; a flat cell's width, a quarter inch, in metres
 inch 0.0254
 lat (40.7 * pi / 180.0)
 ; the equinox, so the sun is up from six to six as the game's daylight has it
 day0 (86400.0 * 20532.0)
 eye [0.0 0.1 -0.22]                    ; four inches up, nine back
 pitch -0.08
 sky-lo -0.01                           ; the sky's lens: the land's edge a hair under the horizon
 az-lift 2.1                            ; ..and each degree across 2.1, so the sun rises at one edge and sets at the other
 near-z 0.12                           ; the bare dirt behind the row, before the meadow
 deep-z 2.6                             ; how far the meadow's own blades run
 field-n 700
 ; --- the screen: w by h pixels, and each pixel's ray, and where it meets the dirt. the
 ; land takes the rows under the middle up to land-r of the width; a screen taller than
 ; that gives the rest to the sky, as the flat field does ---
 land-r 0.3
 (meadow-size st w h) (: n (w * h) i (iota n) x (i % w) y (i // w)
   cy (h - min2 (h / 2.0) (land-r * w))
   U ((x + 0.5 - w / 2.0) / (w / 2.0)) V ((cy - y - 0.5) / (w / 2.0))
   sp (sin pitch) cp (cos pitch)
   dx0 U dy0 (sp + V * cp) dz0 (cp - V * sp)
   ln (sqrt (dx0 * dx0 + dy0 * dy0 + dz0 * dz0))
   dx (dx0 / ln) dy (dy0 / ln) dz (dz0 / ln)
   ; where each ray meets the land, marched once: the eye and the hills hold still, so a
   ; frame only lights what this found
   hit (march dx dy dz) gnd (hit 0) t (hit 1)
   gx (eye 0 + t * dx) gz (eye 2 + t * dz)
   e 0.05 hy0 (hill gx gz)
   nrm (unit [(hy0 - hill (gx + e) gz) e (hy0 - hill gx (gz + e))])
   _ (pins st 'nx (nrm 0) 'ny (nrm 1) 'nz (nrm 2) 'dist t)
   ; ..and the sky through a lens: in each column, the sky from the land's edge up to the
   ; picture's top shows the whole of it from the horizon to overhead, and across, the
   ; sky from sunrise to sunset -- so the clouds stand large, the sun comes up off the
   ; hilltops and crosses the picture, as on the flat field. k the column's sky rows
   sky (1 - gnd)
   kc (gem-tray [w] (map (c \ 1.0 * net (peep sky (iota h * w + c) 0)) ^w))
   kx (max (peep kc x 0.0) 1.0) f ((kx - y - 0.5) / kx)
   el (sky-lo + f * (0.5 * pi - sky-lo) * 0.97) az (az-lift * atan U) cl (cos el)
   _ (pins st 'kc kc 'sdx (cl * sin az) 'sdy (sin el) 'sdz (cl * cos az))
   (lay-stars (pins st 'w w 'h h 'cy cy 'foc (w / 2.0) 'dx dx 'dy dy 'dz dz 'gnd gnd
                     'gx gx 'gz gz 'G (iota gnd) 'S (iota (1 - gnd))
                     'bay (view-bayer w h) 'f [0.0 sp cp] 'u [0.0 cp (0.0 - sp)])))
 ; the stars: fixed in the sky, evenly up it, each one pixel where the lens shows it and
 ; the land does not -- [index direction brightness phase]
 star-k 70
 (lay-stars st) (: w (st 'w) h (st 'h)
   (one k) (: az (5.8 * (throw k 1 91 1000 / 1000.0 - 0.5)) el (0.47 * pi * throw k 2 93 1000 / 1000.0)
              q [(cos el * sin az) (sin el) (cos el * cos az)]
              (on-screen st q @ p (two? p ? (: x (int (p 0)) y (int (p 1)) i (y * w + x)
                                               (0 <= x && x < w && 0 <= y && y < h && peep (st 'gnd) i 1 = 0 ?
                                                  [i q (0.3 + 0.12 * throw k 3 95 5) (throw k 4 97 628 / 100.0)])))))
   (pin st 'stars (filter two? (map one ^star-k))))
 (asin v) (atan (v / sqrt (max (1.0 - v * v) 1e-9)))
 (at2 y x) (? (0.0 < x) (atan (y / x)) (x < 0.0) (atan (y / x) + (y < 0.0 ? (0.0 - pi) pi)) (y < 0.0 ? (-0.5 * pi) (0.5 * pi)))
 ; ..and back: a direction in the sky to the place on the screen the lens shows it, [x y]
 ; in pixels, or () when the lens puts it under the horizon or off the sides
 (on-screen st q) (: w (st 'w) as (at2 (q 0) (q 2) / az-lift)
   f ((asin (q 1) - sky-lo) / ((0.5 * pi - sky-lo) * 0.97))
   x (0.5 * w * (1.0 + sin as / cos as))
   (mag as < 1.4 && -4.0 < x && x < w + 4.0 && -0.1 < f ?
      [x (peep (st 'kc) (min2 (w - 1) (max2 0 (int x))) 1.0 * (1.0 - f))] ()))
 ; how much of the sun's disc the moon's covers, 0 to 1: as drawn, where both are on the
 ; screen, else by the angle between them at the screen's middle scale
 (acos x) (at2 (sqrt (max 0.0 (1.0 - x * x))) x)
 (covered d a b) (? (a + b <= d) 0.0 (d <= b - a) 1.0 (d <= a - b) (b * b / (a * a))
   (: p (a * a * acos ((d * d + a * a - b * b) / (2.0 * d * a)))
      q (b * b * acos ((d * d + b * b - a * a) / (2.0 * d * b)))
      r (0.5 * sqrt (max 0.0 ((a + b - d) * (d + a - b) * (d - a + b) * (d + a + b))))
      ((p + q - r) / (pi * a * a))))
 (eclipse st s mo) (: sc (on-screen st s) mc (on-screen st mo)
   (? (s 1 < -0.03 || mo 1 < -0.03) 0.0
      (two? sc && two? mc) (covered (sqrt (sq (sc 0 - mc 0) + sq (sc 1 - mc 1))) 2.4 2.8)
      (: k (0.5 * st 'w / az-lift) (covered (k * acos (s 0 * mo 0 + s 1 * mo 1 + s 2 * mo 2)) 2.4 2.8))))
 ; the pixels of a disc r across at c, off the land: [idx du dv], du dv its own
 ; coordinates, -1 to 1, up and to the right
 (disc st c r) (: w (st 'w) h (st 'h) x0 (max2 0 (int (c 0 - r) - 1)) x1 (min2 (w - 1) (int (c 0 + r) + 1))
   y0 (max2 0 (int (c 1 - r) - 1)) y1 (min2 (h - 1) (int (c 1 + r) + 1)) bw (x1 - x0 + 1) bh (y1 - y0 + 1)
   (bw < 1 || bh < 1 ? ()
      (: i (iota (bw * bh)) px (x0 + i % bw) py (y0 + i // bw) idx (py * w + px)
         du ((px + 0.5 - c 0) / r) dv ((c 1 - py - 0.5) / r)
         in ((du * du + dv * dv < 1.0) * (1 - peep (st 'gnd) idx 1))
         [(int (over -1 in idx)) du dv])))              ; the land's mask is a float: an index must not be
 ; --- the land: flat about the row and the meadow, then gentle hills, broad crests a few
 ; metres high some tens of metres off, rising out of the flat by a smooth step ---
 (hill x z) (: r (sat ((z - 8.0) / 38.0)) a (r * r * (3.0 - 2.0 * r))
   (a * max 0.0 (4.2 + 2.0 * sin (x * 0.03 + 0.3) * cos (z * 0.02) + 1.0 * sin (x * 0.06 - z * 0.035 + 1.1)
                 + 0.5 * cos (z * 0.08 + x * 0.015))))
 ; a ray against the land: stepped out geometrically to some hundreds of metres, the first
 ; step under the land bracketing the meeting, and the bracket halved down to it. answers
 ; [met t]: met 0 is the sky
 march-n 70 march-k 1.14 march-t0 0.05
 (march dx dy dz) (:
   (under t) (eye 1 + t * dy < hill (eye 0 + t * dx) (eye 2 + t * dz))
   z0 (dx * 0.0)
   (go k t0 lo hi met) (? (march-n <= k) [lo hi met]
     (: t (t0 * march-k) u (under t) nw (u * (1 - met))
        (go (k + 1) t (over lo nw t0) (over hi nw t) (max met u))))
   b (go 0 march-t0 z0 (z0 + 1e9) (z0 * 0))
   (halve k lo hi) (k < 10 ? (: m ((lo + hi) / 2.0) u (under m) (halve (k + 1) (over m u lo) (over hi u m))) hi)
   [(b 2) (over 1e9 (b 2) (halve 0 (b 0) (over 1.0 (b 2) (b 1))))])
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
 ; the sky's [east up north] seen facing south in the mirror: [right up ahead]
 (mirror v) [(v 0) (v 1) (0.0 - v 2)]
 (meadow-sun g) (mirror (sky-sun (day0 + (g 'h % 24.0) * 3600.0) 0.0 lat))
 ; the moon: a phase thrown with the week ('moon0 on g in its place, if said), and a round
 ; of it every 29.53 calendar days, 'cal of them to a game day (1 unless said): at 0 it
 ; keeps its phase, and the sky comes round to itself each day. it rides the sun's
 ; track, as many hours behind it as its phase is of a day
 (meadow-phase st g) (frac (peep g 'moon0 (st 'seed * 0.6180339) + peep g 'cal 1.0 * g 'h / 24.0 / 29.530588))
 (meadow-moon st g) (: p (meadow-phase st g)
   (mirror (sky-body (day0 + (g 'h % 24.0) * 3600.0) lat (-24.0 * p) (365.2422 * p))))
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
   cy (floor (st 'cy - foc * (qy * uv 1 + qz * uv 2) / zs))
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
   (cmix base peb dot))
 ; ..and the turf beyond, the hills' green: broad patches lighter and darker, and a finer
 ; mottle under them
 (turf gx gz) (: m (0.6 * vn (gx * 0.07) (gz * 0.07) 41 + 0.4 * vn (gx * 0.6) (gz * 0.6) 42)
   (cmix [0.07 0.24 0.03] [0.2 0.5 0.06] m))
 ; the ground's own colour: dirt about the row, turf from the meadow out
 (land gx gz) (cmix (dirt gx gz) (turf gx gz) (sat ((gz - 1.0) / 2.5)))
 ; --- the frame's colours, three trays a picture wide ---
 (meadow-pens st g wx) (: lt (meadow-light g wx) s (lt 'sun) sim (cloud-sim g) t0 (g 'fr)
   ; the moon over the sun takes its light as it covers it, and the sky's with it
   mo (meadow-moon st g) ph (meadow-phase st g) ec (eclipse st s mo)
   _ (? (0.0 < ec) (pins lt 'sunk (lt 'sunk * (1.0 - ec)) 'day (lt 'day * (1.0 - 0.85 * ec * ec))
                          'amb (c* (1.0 - 0.7 * ec * ec) (lt 'amb))) 0)
   w (st 'w) h (st 'h) G (st 'G) S (st 'S) (only ix v) (peep v ix 0.0)
   wxv ((0.0 - sin (g 'head * pi / 180.0) * g 'wind) * g 'gust)
   ; the sky behind, and the dirt under, each where it shows
   hv (sky-colour-of lt wx (only S (st 'sdx)) (only S (st 'sdy)) (only S (st 'sdz)) (eye 0) (eye 2) sim t0 0.0)
   gx (only G (st 'gx)) gz (only G (st 'gz))
   alb (land gx gz)
   nx (only G (st 'nx)) ny (only G (st 'ny)) nz (only G (st 'nz))
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
   fu (fd 'u) sway (0.05 * wxv * (1.0 + 0.35 * sin (t0 * turns wx 'tper (2.2 / 30.0) + fd 'ph)))
   fp (bent (fd 'x) (fd 'z) (fd 'L) (max -1.2 (min 1.2 sway)) 0.0 fu)
   ; shadows: each point down the sun to the dirt, darkening the pixel it lands on
   (cast p) (: k (p 1 / max (s 1) 0.05) [(p 0 - k * s 0) 0.0 (p 2 - k * s 2)])
   shp (sunup ? (pin (pin (iota (w * h) * 0) (to-screen st (cast fp) 0) 1) (to-screen st (cast rp) 0) 1) (iota (w * h) * 0))
   shg (only G shp)
   ; ..lit as it faces: the sky's light most on what looks up, the sun on what turns to it
   nd (max 0.0 (nx * s 0 + ny * s 1 + nz * s 2))
   irr (c+ (c* (0.95 * (0.55 + 0.45 * ny)) (lt 'amb)) (c* ((1 - shg) * lt 'sunk * nd) (lt 'sunc)))
   ; ..and the far hills paling into the air
   far (1.0 - exp (0.0 - only G (st 'dist) / 160.0))
   hazec (c+ (c* 1.05 (lt 'amb)) (c* (0.2 * lt 'sunk) (lt 'sunc)))
   gc (cmix (cm alb irr) hazec far)

   z0 (st 'dx * 0.0)
   colg (map (k \ pin (pin z0 G (gc k)) S (hv k)) ^3)
   (put col d c) (: ix (d 0) (map (k \ pin (col k) ix (c k)) ^3))
   (behind col d) (: ix (d 0) (map (k \ peep (col k) ix 0.0) ^3))
   ; --- the stars by night, a pixel each, where no cloud is: twinkling, or in pixels on
   ; and off ---
   sl (st 'stars) nt (sat (1.0 - lt 'day * 3.0))
   col00 (? (0.0 < nt && two? sl)
            (: (tr k) (gem-tray [#sl] (map (q \ 1.0 * q k) sl)) (td k) (gem-tray [#sl] (map (q \ q 1 k) sl))
               si (int (tr 0)) ph (tr 3)
               cl (sky-cloud wx (td 0) (td 1) (td 2) (eye 0) (eye 2) sim)
               v (wx 'style = 'pixel ? ((0.6 < sin (t0 * turns wx 'tper 0.9 + ph)) * (lt 'day < 0.1) * (cl < 0.5) * 1.6)
                    (tr 2 * (0.75 + 0.25 * sin (t0 * turns wx 'tper 0.9 + ph)) * nt * (1.0 - cl)))
               (put colg [si] (c+ (behind colg [si]) [v v (0.9 * v)])))
            colg)
   ; --- the sun and the moon, discs where the lens shows them, the land in front of them ---
   ; the sun: hot at the middle, its colour the light's. behind a cloud it softens and pales
   ; but shows, and the cloud round it glows, so where it is can be told
   sc (on-screen st s) cs (lt 'csun) sd (s 1 < -0.03 || !sc ? () (disc st sc 2.4))
   core (c* 1.4 (cmix (cmix [1.0 0.42 0.08] [1.0 0.8 0.28] (sat ((s 1 - 0.02) / 0.3))) [1.0 0.95 0.86] (0.6 * cs)))
   hd (cs < 0.05 || s 1 < -0.03 || !sc ? () (disc st sc 7.0))
   colh (two? hd ? (: rr (hd 1 * hd 1 + hd 2 * hd 2) (put col00 hd (cmix (behind col00 hd) core (0.3 * cs * sq (sat (1.0 - rr))))))
            col00)
   col01 (two? sd ? (: rr (sd 1 * sd 1 + sd 2 * sd 2) fall (sat ((1.0 - rr) * (3.0 - 1.5 * cs)) * (1.0 - 0.45 * cs))
                       (put colh sd (cmix (behind colh sd) core fall)))
              colh)
   ; the moon: its lit side toward the sun and as wide as the phase, seas on it, pale by day,
   ; behind a cloud dimmed. it hides what lies past it -- the stars, and the sun -- and no
   ; more: its dark side shows the sky nearer than it, the twilight and the cloud
   mcs (on-screen st mo) md (mo 1 < -0.03 || !mcs ? () (disc st mcs 2.8))
   col0 (two? md ? (: du (md 1) dv (md 2) ix (md 0) (dir v) (peep v ix 0.0)
                     sg (? (0.0 < wrap (at2 (s 0) (s 2) - at2 (mo 0) (mo 2))) 1.0 -1.0)
                     lit (sg * du > cos (2.0 * pi * ph) * sqrt (max (1.0 - dv * dv) 0.0))
                     sea (0.72 + 0.28 * vn ((du + 3.0) * 2.3) ((dv + 3.0) * 2.3) 77)
                     cl (sky-cloud wx (mo 0) (mo 1) (mo 2) (eye 0) (eye 2) sim)
                     k (sea * (0.5 + 0.9 * (1.0 - lt 'day)) * (1.0 - 0.85 * cl))
                     near (sky-near lt wx (dir (st 'sdx)) (dir (st 'sdy)) (dir (st 'sdz)) (eye 0) (eye 2) sim)
                     (put col01 md (c+ near (c* (lit * k) [0.95 0.93 0.82]))))
             col01)
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
 (meadow-sky g) (meadow-weather g 'smooth)
 ; where the sun and the moon stand on the screen, [x y] or (), and the moon's phase
 (meadow-bodies st g) [(meadow-sun g @ s (s 1 < -0.03 ? () (on-screen st s)))
                       (meadow-moon st g @ m (m 1 < -0.03 ? () (on-screen st m)))
                       (meadow-phase st g)])
) ; module meadow
