; court -- the inner courtyard of an apartment block, first person in half blocks: the
; level after the shaft. twenty feet by thirty of concrete gone green with moss, a grated
; sump in the middle, four floors of brick painted grey and chipped to the red beneath,
; windows lit and dark, and the sky at the top of the well.
;
; the long walls run north and south with four windows a floor; the short walls carry
; two narrow ones a floor and the stair's three between the floors. the sky is the sun
; and the clouds at this hour of this day, at a fixed latitude, and runs on faster than
; the clock: the sun comes in over the rim where it can, low and orange on the top of a
; wall at either end of the day, and windows come on and go off with the hours.
;
; every pixel casts its own ray, so the look tilts as far as the neck does. the scene is
; trays a frame wide: what each ray meets, the stuff there, the sun on it past the rim,
; and the colour out -- 24-bit where COLORTERM says so, else the 256 palette dithered.
; court-new, court-step, court-move and court-frame are pure, gated by test/host/court.l;
; only court-walk and court-run tie the tty. court-walk takes a stage already raised.
;
; run: love court   h l or the arrows turn, k j step, u n look up and down;
;                   [ ] an hour back or on, t the time's pace; q or esc leaves
(module (court court-run court-walk court-main court-new court-size court-step court-move
         court-frame court-sun court-light court-clock court-now court-pens court-maps
         fps yard-a yard-b floor-h floors wall-h eye-h body-r lat paces)
(borrow 'rove)
(borrow 'view)                          ; the screen, the pens, the hash, the loop
(:
 fps 20
 ; --- the yard, in metres: x east, z north, y up, the sump at the origin. the long walls
 ; stand at x = -a and a, the short at z = -b and b ---
 yard-a 3.05 yard-b 4.57
 floors 4 floor-h 3.0
 wall-h (floors * floor-h + 0.5)        ; ..and a parapet over the top floor
 eye-h 1.6 body-r 0.3
 walk-v 1.4 turn-step 0.07 tilt-step 0.06
 lat (40.7 * pi / 180.0)
 paces [60.0 600.0 1.0 0.0]             ; seconds of the sky a second, t steps through them
 bay (2.0 * yard-b / 4.0)               ; a long wall's window bay
 bayer [0 8 2 10 12 4 14 6 3 11 1 9 15 7 13 5]
 bayers (star-tray [16] bayer)
 (sat v) (min 1.0 (max 0.0 v))
 (sq v) (v * v)
 (mag v) (max v (0.0 - v))
 (frac v) (v - floor v)
 ; colours are triples, each part a number or a tray
 (c* k a) [(k * a 0) (k * a 1) (k * a 2)]
 (cm a b) [(a 0 * b 0) (a 1 * b 1) (a 2 * b 2)]
 (c+ a b) [(a 0 + b 0) (a 1 + b 1) (a 2 + b 2)]
 (cmix a b m) [(a 0 + m * (b 0 - a 0)) (a 1 + m * (b 1 - a 1)) (a 2 + m * (b 2 - a 2))]
 ; value noise: the hash on a lattice, eased between
 (vn x z s) (: ix (floor x) iz (floor z) ux (x - ix) uz (z - iz)
               ex (ux * ux * (3.0 - 2.0 * ux)) ez (uz * uz * (3.0 - 2.0 * uz))
               (h i k) (throw i k s 1024 / 1023.0)
               p (h ix iz) q (h (ix + 1) iz) r (h ix (iz + 1)) t (h (ix + 1) (iz + 1))
               lo (p + ex * (q - p)) hi (r + ex * (t - r))
               (lo + ez * (hi - lo)))
 ; --- the time: 'sim is the wall clock's local seconds, 'dst what summer adds to it ---
 ; now, as [local-seconds dst]: the zone's offset now, against the least of it a season on, two and three
 (court-now _) (: s (clock 0 // 1000) zone ((cite 'kore 'tz-zone) 0)
                  (off u) (zone ? (zone u 0) 0)
                  o (off s) std (foldl (a \ k \ min2 a (off (s + k * 7889400))) o [1 2 3])
                  [(1.0 * (s + o)) (o - std)])
 (day-secs s) (s - 86400.0 * floor (s / 86400.0))
 (court-clock st) (: d (day-secs (st 'sim)) hh (int (d / 3600.0)) mm (int (d / 60.0) % 60)
                     (p2 v) (v < 10 ? ("0" + show v) (show v))
                     (p2 hh + ":" + p2 mm))
 ; the sun as [east up north], a unit vector, by solar time and the day of the year
 (court-sun st) (: s (st 'sim - st 'dst) hr (day-secs s / 3600.0)
                   doy (s / 86400.0 - 10957.0 - 365.2422 * floor ((s / 86400.0 - 10957.0) / 365.2422))
                   dec (-0.4091 * cos (2.0 * pi * (doy + 10.0) / 365.2422))
                   ha ((hr - 12.0) * pi / 12.0)
                   [(0.0 - cos dec * sin ha)
                    (sin lat * sin dec + cos lat * cos dec * cos ha)
                    (cos lat * sin dec - sin lat * cos dec * cos ha)])
 ; the light of the hour: the sun, its colour and strength, how much day and twilight
 ; there is, the sky's light on what it sees, and the eye's gain against the dark
 (court-light st) (: s (court-sun st) sy (s 1)
   day (sat ((sy + 0.06) / 0.3))
   tw (sat (1.0 - mag (sy + 0.03) / 0.2))
   sunk (sat ((sy + 0.005) / 0.05))
   sunc (cmix [1.0 0.4 0.1] [1.0 0.93 0.82] (sat ((sy - 0.04) / 0.4) @ k (k * k * (3.0 - 2.0 * k))))
   night [0.05 0.055 0.075]
   amb (c+ (cmix night [0.42 0.47 0.56] day) (c* (tw * (1.0 - 0.5 * day)) [0.1 0.05 0.07]))
   {'sun s 'day day 'tw tw 'sunk sunk 'sunc sunc 'amb amb 'expo (1.0 + 1.2 * (1.0 - day))})
 ; --- the state: the screen as view lays it, where the player stands and looks ('th the
 ; bearing, 'ph the pitch), the clock, its pace, and the pixels' rays ---
 (court-new w h now) (: st {'px 0.0 'pz (0.0 - yard-b + 1.4) 'th 0.0 'ph 0.5
                            'sim (now 0) 'dst (now 1) 'pace 0 'shown 40 't 0
                            'deep 0 'done 0}
                       (court-size st w (h // 2)))
 ; the screen w cells by r rows, and each pixel's offsets from the middle, and its dither
 (court-size st w r) (: h (2 * r) n (w * h) i (iota n) x (i % w) y (i // w)
   (pins (view! st w h (h // 2)) 'U ((x + 0.5 - w / 2.0) / (w / 2.0)) 'V ((h / 2.0 - y - 0.5) / (w / 2.0))
         'bay (peep bayers (y % 4 * 4 + x % 4) 0 / 16.0 + 1.0 / 32.0)))
 ; --- moving ---
 (put! st x z) (: ma (yard-a - body-r) mb (yard-b - body-r)
                  (pins st 'px (clamp x (0.0 - ma) ma) 'pz (clamp z (0.0 - mb) mb)))
 (court-step st k) (: th (st 'th)
   (step d) (put! st (st 'px + d * sin th) (st 'pz + d * cos th))
   (tell st2) (pin st2 'shown (st 't + 2 * fps))
   (k @ (104 || -1) (pin st 'th (wrap (th - turn-step)))
        (108 || -2) (pin st 'th (wrap (th + turn-step)))
        (107 || -8) (step (walk-v / fps))
        (106 || -9) (step (0.0 - walk-v / fps))
        117 (pin st 'ph (min2 1.45 (st 'ph + tilt-step)))
        110 (pin st 'ph (max2 -1.2 (st 'ph - tilt-step)))
        91 (tell (pin st 'sim (st 'sim - 3600.0)))
        93 (tell (pin st 'sim (st 'sim + 3600.0)))
        116 (tell (pin st 'pace ((st 'pace + 1) % #paces)))
        st))
 (court-move st) (pin st 'sim (st 'sim + paces (st 'pace) / fps))
 ; --- the maps: the walls, the floor, the clouds and the stars, laid once a run in texels
 ; and gathered from by every frame, so no hash is thrown a frame ---
 ts 0.04                                ; a texel's side
 (cells l) (int (l / ts + 0.999))
 nu-long (cells (2.0 * yard-b)) nu-short (cells (2.0 * yard-a)) nv (cells wall-h)
 ; the walls side by side: east, west, north, south -- each its run across and its first texel
 wall-nus (star-tray [4] [nu-long nu-long nu-short nu-short])
 wall-offs (star-tray [4] [0 (nu-long * nv) (2 * nu-long * nv) ((2 * nu-long + nu-short) * nv)])
 wall-n (2 * (nu-long + nu-short) * nv)
 fts 0.02                               ; ..and the floor's, finer for its joints and grate
 fl-nx (int (2.0 * yard-a / fts + 0.999)) fl-nz (int (2.0 * yard-b / fts + 0.999))
 cloud-n 128 star-n 256
 maps {}
 ; the brick, painted grey and chipped, at the run along wall wid and the height py:
 ; the windows and their sills and frames, the paint mottled, grimed at the foot and
 ; stained under the sills, the red or an older coat beneath, and the coping. what a
 ; window shows lit is laid here too, and which window it is
 (wall-map _) (: i (iota wall-n)
   wid ((nu-long * nv <= i) + (2 * nu-long * nv <= i) + ((2 * nu-long + nu-short) * nv <= i))
   nu (peep wall-nus wid 0) j (i - peep wall-offs wid 0)
   isx (wid < 2) isz (1 - isx)
   half (over yard-a isx yard-b)
   al ((j % nu + 0.5) * ts - half) py ((j // nu + 0.5) * ts)
   b yard-b hh wall-h
   fl (floor (py / floor-h)) yy (py - fl * floor-h) infl (fl < floors)
   ; the windows: four a floor on the long walls, two narrow on the short, and the
   ; stair's between the floors, in the middle of the short walls
   wa ((al + b) / bay) wi (floor wa) ca ((wa - wi - 0.5) * bay)
   lw (isx * (sq ca < 0.2025) * (0.9 < yy) * (yy < 2.3) * infl)
   sa (mag al - 1.6)
   sw (isz * (sq sa < 0.0625) * (0.9 < yy) * (yy < 2.4) * infl)
   ys (py - 2.45) fs (floor (ys / floor-h)) yys (ys - fs * floor-h)
   stw (isz * (sq al < 0.09) * (yys < 1.2) * (0 <= fs) * (fs < floors - 1))
   win (lw + sw + stw)
   sill ((isx * (sq ca < 0.27) + isz * (sq sa < 0.09)) * (0.82 < yy) * (yy <= 0.9) * infl)
   ; ..a window's frame: its edges, and the long ones' mullion and transom
   cp (lw * ca + sw * sa + stw * al) hw (lw * 0.45 + sw * 0.25 + stw * 0.3)
   vp ((lw + sw) * (yy - 0.9) + stw * yys) vh (lw * 1.4 + sw * 1.5 + stw * 1.2)
   frm (win * (0 < (hw - mag cp < 0.06) + (vp < 0.07) + (vh - vp < 0.06)
                   + lw * (mag cp < 0.05) + lw * (sq (vp - 1.0) < 0.0016)))
   glass (win - frm)
   ; ..each its own: lamps warm and various, a few with the curtains drawn, a few a television
   wkey (wid * 100 + fl % 8 * 10 + lw * wi + sw * (4 + (0.0 < al)))
   tv ((throw wkey 0 13 9 = 0) * (1 - stw))
   cur (throw wkey 1 19 3 = 0)
   lamp (0.55 + 0.45 * (throw wkey 2 23 10 / 10.0))
   glow (lamp * (1.0 - 0.6 * cur * (hw * 0.45 < mag cp)))
   em (cmix (cmix (c* glow [1.0 0.76 0.44]) [0.5 0.62 1.0] tv) [0.85 0.95 0.82] stw)
   ; ..the brick: courses and their bonds, chipped in patches a brick at a time
   row (floor (py / 0.075)) bi (floor ((al + row % 2 * 0.11) / 0.22))
   cx (floor (al / 0.7)) cy (floor (py / 0.5))
   chip (0 < (throw cx cy (wid + 11) 9 = 0) * (throw bi row (wid + 3) 2 = 0) + (throw bi row (wid + 5) 500 = 0))
   old (throw cx cy (wid + 23) 4 = 0)
   stain ((isx * (sq ca < 0.16) + isz * (sq sa < 0.05)) * (yy < 0.82) * infl
          * sat (1.0 - (0.82 - yy) / 0.9) * sat (vn (al * 18.0) 0.5 9 * 2.0 - 0.6))
   foot (sat (1.0 - py / 1.2))
   paint (c* ((0.92 + 0.13 * vn (al * 0.9) (py * 0.9) (wid + 40)) * (1.0 - 0.3 * stain) * (1.0 - 0.28 * foot))
             [0.6 0.61 0.6])
   paint2 (cmix paint [0.3 0.34 0.24] (0.35 * foot))
   under (cmix (c* (0.82 + 0.3 * (throw bi row 41 10 / 10.0)) [0.56 0.27 0.2]) [0.55 0.6 0.48] old)
   cope (hh - 0.18 < py)
   alb (cmix (cmix (cmix (cmix paint2 under chip) [0.68 0.66 0.62] sill) [0.7 0.7 0.66] frm) [0.5 0.49 0.46] cope)
   {'r (alb 0) 'g (alb 1) 'b (alb 2) 'glass glass 'key wkey 'stair stw 'tv tv
    'er (em 0) 'eg (em 1) 'eb (em 2)})
 ; the floor: eight triangular slabs meeting at the sump -- split by the two axes and the
 ; two diagonals to the corners -- each poured a shade apart, their joints, moss over
 ; most of it and thickest by the walls, in the joints and round the sump, and the
 ; sump's round grate
 sump-r 0.2
 (floor-map _) (: i (iota (fl-nx * fl-nz)) a yard-a b yard-b
   px ((i % fl-nx + 0.5) * fts - a) pz ((i // fl-nx + 0.5) * fts - b)
   r2 (sq px + sq pz) dg (sqrt (a * a + b * b))
   ux (mag px) uz (mag pz)
   jd (min (min ux uz) (mag (b * ux - a * uz) / dg))        ; to the nearest joint
   joint ((jd < 0.02) * (sump-r * sump-r < r2))
   oct ((0.0 < px) * 4 + (0.0 < pz) * 2 + (a * uz < b * ux))
   tone (peep (gem-tray [8] [0.97 1.03 0.94 1.0 1.02 0.95 1.04 0.98]) oct 1.0)
   de (min (a - ux) (b - uz))
   mf (0.55 * vn (px * 1.3) (pz * 1.3) 31 + 0.3 * vn (px * 4.1) (pz * 4.1) 32
       + 0.45 * sat (1.0 - de / 1.3) + 0.3 * sat (1.0 - r2 / 1.0) + 0.5 * sat (1.0 - jd / 0.12) - 0.02)
   moss (sat ((mf - 0.15) * 2.0))
   speck (throw (floor (px * 30.0)) (floor (pz * 30.0)) 34 9 = 0)
   conc (c* (tone * (0.9 + 0.2 * vn (px * 7.0) (pz * 7.0) 33) * (1.0 - 0.15 * speck)) [0.5 0.5 0.47])
   mossc (c* (0.75 + 0.45 * vn (px * 9.0) (pz * 9.0) 35) [0.2 0.31 0.12])
   wet (1.0 - 0.2 * (r2 < 0.2) - 0.35 * joint)
   sump (r2 < sump-r * sump-r)
   rim (sump * ((sump-r - 0.035) * (sump-r - 0.035) < r2))
   bar (frac ((px + sump-r) / 0.06) < 0.5)
   grate (cmix (cmix [0.01 0.01 0.01] [0.18 0.16 0.14] bar) [0.24 0.21 0.18] rim)
   alb (cmix (c* wet (cmix conc mossc moss)) grate sump)
   {'r (alb 0) 'g (alb 1) 'b (alb 2)})
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
 (court-maps _) (maps 'wall ? maps (pins maps 'wall (wall-map ()) 'floor (floor-map ()) 'cloud (cloud-map ()) 'stars (star-map ())))
 ; a square map at fractional texels, bilinear, wrapping
 (bil tab n x z) (: ix (floor x) iz (floor z) ux (x - ix) uz (z - iz)
                    (w i) ((i % n + n) % n)
                    x0 (w ix) x1 (w (ix + 1)) z0 (w iz * n) z1 (w (iz + 1) * n)
                    (g k) (peep tab k 0.0)
                    lo (g (z0 + x0) @ q (q + ux * (g (z0 + x1) - q)))
                    hi (g (z1 + x0) @ q (q + ux * (g (z1 + x1) - q)))
                    (lo + uz * (hi - lo)))
 ; --- the frame ---
 ; the lit share of the windows by the hour of the evening
 (lit-share hr) (? (hr < 5.0) 6 (hr < 6.5) 12 (hr < 9.0) 35 (hr < 16.0) 4 (hr < 18.0) 25 (hr < 23.0) 60 25)
 ; every pixel's colour, three trays: the ray from the eye, what it meets first -- a wall,
 ; the floor or the sky through the rim -- the stuff there out of the maps, and the light on it
 (court-pens st) (: mp (court-maps ()) lt (court-light st) th (st 'th) ph (st 'ph) U (st 'U) V (st 'V)
   a yard-a b yard-b hh wall-h t0 (st 't)
   sth (sin th) cth (cos th) sph (sin ph) cph (cos ph)
   dx0 (sth * cph + U * cth - V * sth * sph) dy0 (sph + V * cph) dz0 (cth * cph - U * sth - V * cth * sph)
   ln (sqrt (dx0 * dx0 + dy0 * dy0 + dz0 * dz0))
   dx (over (dx0 / ln) (dx0 = 0.0) 1e-9) dy (over (dy0 / ln) (dy0 = 0.0) 1e-9) dz (over (dz0 / ln) (dz0 = 0.0) 1e-9)
   ex (st 'px) ey eye-h ez (st 'pz)
   ; the first of the four walls, the floor and the rim's plane
   tx ((over (0.0 - a) (0.0 < dx) a - ex) / dx)
   tz ((over (0.0 - b) (0.0 < dz) b - ez) / dz)
   ty ((over 0.0 (0.0 < dy) hh - ey) / dy)
   isx ((tx <= tz) * (tx <= ty)) isz ((1 - isx) * (tz <= ty))
   isy (1 - isx - isz) sky (isy * (0.0 < dy)) gnd (isy * (dy <= 0.0))
   t (min tx (min tz ty))
   px (ex + t * dx) py (ey + t * dy) pz (ez + t * dz)
   ; --- the stuff: a wall's texel by which wall and where on it, else the floor's ---
   al (over px isx pz)
   wid (isx * (over 1 (0.0 < dx) 0) + isz * (over 3 (0.0 < dz) 2))
   nx (isx * (over 1.0 (0.0 < dx) -1.0)) nz (isz * (over 1.0 (0.0 < dz) -1.0))
   nu (peep wall-nus wid 0)
   tu (max 0 (min (nu - 1) (floor ((al + over yard-a isx yard-b) / ts))))
   tv (max 0 (min (nv - 1) (floor (py / ts))))
   wi (peep wall-offs wid 0 + tv * nu + tu)
   fi (max 0 (min (fl-nz - 1) (floor ((pz + b) / fts))) * fl-nx + max 0 (min (fl-nx - 1) (floor ((px + a) / fts))))
   wm (mp 'wall) fm (mp 'floor)
   (wg k) (peep (wm k) wi 0.0) (fg k) (peep (fm k) fi 0.0)
   alb (cmix [(wg 'r) (wg 'g) (wg 'b)] [(fg 'r) (fg 'g) (fg 'b)] gnd)
   glass ((1 - gnd) * peep (wm 'glass) wi 0)
   ; --- the light: the sun where it faces and gets in past the rim, the sky's light by
   ; how much of the sky is seen and how it faces the sun's side, and a little back off
   ; the walls the sun is on ---
   s (lt 'sun) sx (s 0) sy (s 1) sz (s 2)
   nd (nx * sx + gnd * sy + nz * sz)
   tt ((hh - py) / max2 sy 1e-6) qx (px + tt * sx) qz (pz + tt * sz)
   lit ((0.0 < nd) * (sq qx <= a * a + 0.001) * (sq qz <= b * b + 0.001) * (0.0 < sy))
   dir (nd * lit * lt 'sunk * 0.9)
   sv (over (0.45 + 0.5 * py / hh) gnd 0.42 * (1.0 + 0.2 * lt 'day * (nx * sx + nz * sz)))
   bounce (c* (lt 'sunk * 0.05) (lt 'sunc))
   irr (c+ (c+ (c* sv (lt 'amb)) (c* dir (lt 'sunc))) bounce)
   ; ..a window: the sky in the pane, and the room behind it when it is lit -- each window
   ; by the hour, the stair's whenever it is dark out, a television flickering
   hr (day-secs (st 'sim) / 3600.0)
   key (peep (wm 'key) wi 0) stw (peep (wm 'stair) wi 0) tv (peep (wm 'tv) wi 0)
   on (frac (sin (key * 12.9898 + int hr * 78.233) * 43758.5453) * 100.0 < lit-share hr)
   flick (1.0 - tv * (0.3 + 0.25 * sin (t0 * 1.7 + key * 2.1) * sin (t0 * 0.61 + key)))
   lamps (over ((1 - stw) * on * 0.7 * flick) stw ((lt 'day < 0.55) * 0.75))
   panes (c+ (c* 0.25 (lt 'amb)) [0.02 0.025 0.03])
   inglass (c+ panes (c* lamps [(wg 'er) (wg 'eg) (wg 'eb)]))
   surf (cmix (cm alb irr) inglass glass)
   ; --- the sky: blue by day, toward the sun warm at either end of it, stars at night
   ; through the city's glow, and clouds on the wind, lit by the sun from under them ---
   mu (dx * sx + dy * sy + dz * sz)
   up (sat dy)
   blue (cmix [0.55 0.7 0.9] [0.2 0.42 0.84] (sat (up * 1.3)))
   dark (c+ [0.012 0.016 0.04] (c* (0.06 * (1.0 - up)) [0.6 0.45 0.3]))
   warm (sat ((mu + 0.3) / 1.3))
   dusk (c* (lt 'tw * (1.0 - 0.5 * lt 'day)) (c+ (c* (warm * warm * warm) [0.9 0.38 0.16]) [0.22 0.12 0.28]))
   disc (sat ((mu - 0.9995) * 4000.0))
   halo (0.35 * lt 'day * exp ((mu - 1.0) * 60.0))
   sky0 (c+ (c+ (cmix dark blue (lt 'day)) dusk) (c* (halo + 3.0 * disc * lt 'sunk) (lt 'sunc)))
   sim (st 'sim) tc (1800.0 / max dy 0.05)
   kx ((ex + dx * tc) / 900.0 + sim * 0.006) kz ((ez + dz * tc) / 900.0 + sim * 0.0025)
   cn (bil (mp 'cloud) cloud-n (kx * 16.0) (kz * 16.0))
   cover (0.4 + 0.22 * sin (sim / 20000.0) + 0.1 * sin (sim / 7300.0))
   cl (sat ((cn - (1.0 - cover)) * 3.2))
   cloudc (c* (1.0 - 0.3 * cl)
              (c+ (c+ (c+ (c* 1.15 (lt 'amb)) (c* (lt 'sunk * (0.55 + 0.4 * sy)) (lt 'sunc)))
                      (c* (lt 'tw) [0.5 0.22 0.14]))
                  (c* (1.0 - lt 'day) [0.06 0.05 0.045])))
   qs (40.0 / max dy 0.05) sk ((floor (dz * qs) % star-n + star-n) % star-n * star-n + (floor (dx * qs) % star-n + star-n) % star-n)
   star (peep (mp 'stars) sk 0.0 * (0.75 + 0.25 * sin (t0 * 0.9 + sk)) * sat (1.0 - lt 'day * 3.0) * (1.0 - cl))
   skyc (c+ (cmix sky0 cloudc cl) [star star star])
   col (cmix surf skyc sky)
   ; ..and the eye: its gain against the dark, and a soft shoulder that keeps a hue
   k (1.5 * lt 'expo)
   [(1.0 - exp (0.0 - k * col 0)) (1.0 - exp (0.0 - k * col 1)) (1.0 - exp (0.0 - k * col 2))])
 ; the pens out of the colours: 24-bit, six bits a channel packed, or the 256 palette's
 ; cube or grey ramp, dithered between its steps
 (deep-pens c) (: (q v) (int (sat v * 63.0 + 0.5)) (q (c 0) * 4096 + q (c 1) * 64 + q (c 2)))
 (cube-pens c bay) (: (lv v) (sat v * 255.0 @ u (over (u / 95.0) (95.0 <= u) (1.0 + (u - 95.0) / 40.0)))
   (ix v) (max 0 (min 5 (floor (lv v + bay))))
   r (c 0) g (c 1) bl (c 2)
   chroma (max r (max g bl) - min r (min g bl))
   y (sat (0.299 * r + 0.587 * g + 0.114 * bl) * 255.0)
   gi (floor ((y - 8.0) / 10.0 + bay))
   grey (over (232 + max 0 (min 23 gi)) (gi < 0) 16)
   cube (16 + 36 * ix r + 6 * ix g + ix bl)
   (over cube (chroma < 0.05) grey))
 ; a frame of 24-bit pens: view's frame, each pen's words kept once said, and only
 ; the half that changed said again
 tints {}
 (tint c) (: s (tints c)
             (string? s ? s
                (: (ch k) (show ((c >> k & 63) * 255 // 63))
                   s2 (ch 12 + ";" + ch 6 + ";" + ch 0)
                   n (peep tints -1 0)
                   _ (60000 < n ? (each (keys tints) (k \ pin tints k ())))
                   (pins tints c s2 -1 (n + 1), s2))))
 (deep-sgr f b f2 b2) (? (f2 = f) (esc + "[48;2;" + tint b2 + "m")
                         (b2 = b) (esc + "[38;2;" + tint f2 + "m")
                         (esc + "[38;2;" + tint f2 + ";48;2;" + tint b2 + "m"))
 (deep-frame w h px bands) (: j (jug 0)
   (row x f b i bd) (x < w ?
     (: tx (two? bd && bd 0 <= x < bd 0 + #(bd 1))
        f2 (tx ? (bd 2) (peep px (i + x) 0)) b2 (tx ? (bd 3) (peep px (i + w + x) 0))
        (f2 != f || b2 != b ? (say j (deep-sgr f b f2 b2)),
         say j (tx ? (string (bd 1 (x - bd 0))) "▀"),
         row (x + 1) f2 b2 i bd)))
   (rows y) (y < h // 2 ? (row 0 -1 -1 (2 * y * w) (peep bands y ()),
                           say j (esc + "[0m"), y + 1 < h // 2 ? (say j "\r\n"), rows (y + 1)))
   (rows 0, slurp j))
 ; the frame: the clock in the corner for a while after the time is touched
 (court-frame st) (: w (st 'w) h (st 'h) c (court-pens st) deep (st 'deep)
   px (deep ? (deep-pens c) (cube-pens c (st 'bay)))
   pace (paces (st 'pace))
   txt (" " + court-clock st + (pace = 0.0 ? "  still " (pace = 1.0 ? "  " ("  x" + show (int pace) + " "))))
   bands (st 't < st 'shown ? {0 [1 txt (deep ? 249660 255) (deep ? 33288 235)]} {})
   (deep ? (deep-frame w h px bands)
      (view-frame w h (y \ peep px (iota w + w * y) 0) bands)))
 ; --- the walk, on view's loop; court-run raises the stage ---
 (court-walk _) (view-walk {'new (w \ h \ pin (court-new w h (court-now ())) 'deep
                                         (elem (getenv "COLORTERM") ["truecolor" "24bit"]))
                            'size court-size 'frame court-frame 'key court-step 'tick court-move
                            'fps fps 'song (hn \ ()) 'linger 0 'next ()})
 (court-run _) (view-run court-walk)
 court-usage "usage: love court   (h l turn, k j step, u n look, [ ] an hour, t the pace; q or esc leaves)"
 (court-main as) (as @ () (court-run ())
                       (say err ("court: " + court-usage + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'court (udoor 'court court-main court-usage 1 1)))
) ; module court
