; court -- the inner courtyard of an apartment block, first person in half blocks: the
; level after the shaft. twenty feet by thirty of concrete gone green with moss, a grated
; sump in the middle, four floors of brick painted grey and chipped to the red beneath,
; windows lit and dark, a honey locust leaning in from the north-east corner, and the sky
; at the top of the well.
;
; the long walls run north and south with four windows a floor; the short walls carry
; two narrow ones a floor and the stair's three between the floors, and over their outer
; thirds a battlement each. the tree is grown afresh each run: its trunk leans toward
; the middle and forks in the third floor, and its leaves are points, drawn over the
; scene where nearer and down the sun into a map its shade is read from. the sky is the sun
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
         tree-new sun-clear unit mag sq top-h block-h
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
 ; the short walls' battlements: a block over each outer third, two thirds of a floor high
 block-h (2.0 * floor-h / 3.0) top-h (wall-h + block-h) wall-t 0.45
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
                            'deep 0 'done 0 'tree (tree-new (int (now 0)))}
                       (court-size st w (h // 2)))
 ; the screen w cells by r rows, and each pixel's offsets from the middle, and its dither
 (court-size st w r) (: h (2 * r) n (w * h) i (iota n) x (i % w) y (i // w)
   (pins (view! st w h (h // 2)) 'U ((x + 0.5 - w / 2.0) / (w / 2.0)) 'V ((h / 2.0 - y - 0.5) / (w / 2.0))
         'bay (peep bayers (y % 4 * 4 + x % 4) 0 / 16.0 + 1.0 / 32.0)))
 ; --- moving ---
 ; ..kept inside the walls and out of the trunk
 (put! st x z) (: ma (yard-a - body-r) mb (yard-b - body-r) bs (st 'tree 'base)
                  x2 (clamp x (0.0 - ma) ma) z2 (clamp z (0.0 - mb) mb)
                  qx (x2 - bs 0) qz (z2 - bs 2) d (sqrt (qx * qx + qz * qz)) m (0.3 + body-r)
                  (d < m ? (pins st 'px (bs 0 + qx * m / max2 d 0.001) 'pz (bs 2 + qz * m / max2 d 0.001))
                     (pins st 'px x2 'pz z2)))
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
 nu-long (cells (2.0 * yard-b)) nu-short (cells (2.0 * yard-a)) nv (cells top-h)
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
 ; stained under the sills, the red or an older coat beneath, and the coping; over it
 ; the battlements, weathered harder under their dark caps. what a window shows lit is
 ; laid here too, and which window it is
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
   blk (isz * (yard-a / 3.0 < mag al)) up (blk * (hh - 0.18 <= py))
   cope ((hh - 0.18 < py) * (1 - blk))
   ; ..the battlements: the paint blotched and streaked down from the cap, chipped more
   streak (sat (vn (al * 9.0) 0.5 77 * 2.2 - 0.9) * sat (1.0 - (top-h - py) / 1.4))
   worn (c* ((0.8 + 0.3 * vn (al * 3.0) (py * 3.0) 78) * (1.0 - 0.4 * streak)) [0.6 0.61 0.6])
   chip2 (0 < (throw cx cy (wid + 13) 3 = 0) * (throw bi row (wid + 7) 2 = 0) + (throw bi row (wid + 9) 40 = 0))
   battle (cmix (cmix worn under chip2) [0.15 0.15 0.16] (top-h - 0.14 < py))
   alb (cmix (cmix (cmix (cmix (cmix paint2 under chip) [0.68 0.66 0.62] sill) [0.7 0.7 0.66] frm) [0.5 0.49 0.46] cope)
             battle up)
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
 ; whether the sun reaches the points px py pz (trays) past the rim, the long walls'
 ; parapets and the battlements: the way out toward it is through the top, or over a wall
 ; low enough where it crosses
 (sun-clear px py pz s) (: a yard-a b yard-b sx (s 0) sy (s 1) sz (s 2)
   (away v) (v < 0.0 ? (min2 v -1e-6) (max2 v 1e-6))
   ux (((sx < 0.0 ? (0.0 - a) a) - px) / away sx)
   uz (((sz < 0.0 ? (0.0 - b) b) - pz) / away sz)
   uy ((top-h - py) / max2 sy 1e-6)
   viax ((ux < uz) * (ux < uy)) viaz ((1 - viax) * (uz < uy))
   ye (py + sy * min ux uz) xe (px + uz * sx)
   ((0.0 < sy) * (1 - viax * (ye < wall-h) - viaz * (0 < (ye < wall-h) + (a / 3.0 < mag xe)))))
 ; --- the tree: a honey locust in the north-east quarter, grown afresh each run. its
 ; trunk leans toward the middle as it climbs and forks two ways in the third floor;
 ; each leader throws limbs, each limb twigs, and each twig the fronds of a leaf twice
 ; pinnate, spear-shaped, as points. the wood is cylinders, a 'segs list of [a b r] ---
 (rnd g) (: s ((g 's * 1103515245 + 12345) % 2147483648) (pin g 's s, s / 2147483648.0))
 (rr g lo hi) (lo + (hi - lo) * rnd g)
 (dot a b) (a 0 * b 0 + a 1 * b 1 + a 2 * b 2)
 (unit a) (c* (1.0 / sqrt (max2 1e-12 (dot a a))) a)
 (cross a b) [(a 1 * b 2 - a 2 * b 1) (a 2 * b 0 - a 0 * b 2) (a 0 * b 1 - a 1 * b 0)]
 (lerp a b f) (c+ a (c* f (c+ b (c* -1.0 a))))
 ; d turned by ang about the unit axis k; a unit square to d; d turned off by ang toward
 ; a thrown bearing round it
 (turn d k ang) (: c (cos ang) sn (sin ang)
                   (c+ (c+ (c* c d) (c* sn (cross k d))) (c* (dot k d * (1.0 - c)) k)))
 (side d) (unit (cross d (mag (d 1) < 0.95 ? [0.0 1.0 0.0] [1.0 0.0 0.0])))
 (spread g d ang) (turn d (turn (side d) d (rr g 0.0 (2.0 * pi))) ang)
 ; a point kept inside the walls while it is below their tops; the crown starts a metre
 ; under them
 crown-y (wall-h - 1.0)
 (inside p) (p 1 < wall-h ? [(clamp (p 0) (0.15 - yard-a) (yard-a - 0.15)) (max2 0.05 (p 1))
                            (clamp (p 2) (0.15 - yard-b) (yard-b - 0.15))] p)
 (tree-new seed) (: g {'s (seed % 2147483647 + 1)} segs {'n 0} pts {'n 0}
   (seg! a b r) (pins segs (segs 'n) [a b r] 'n (segs 'n + 1))
   ; ..a point that would be in a wall is not grown
   (pt! p k sh ye ph) (p 1 < wall-h && (yard-a - 0.1 < mag (p 0) || yard-b - 0.1 < mag (p 2)) ? ()
                         (: n (pts 'n) (pins pts n [p k sh ye ph] 'n (n + 1))))
   (wob p) (c+ p [(rr g -0.08 0.08) 0.0 (rr g -0.08 0.08)])
   base [(rr g 1.3 1.8) 0.0 (rr g 2.2 2.9)]
   cdir (unit [(0.0 - base 0) 0.0 (0.0 - base 2)])
   hs (rr g 7.2 7.8) lean (rr g 1.7 2.3)
   (tp f) (c+ (c+ base (c* (lean * f * sqrt f) cdir)) [0.0 (hs * f) 0.0])
   tq (map (f \ (0.0 < f < 1.0 ? (wob (tp f)) (tp f))) [0.0 0.25 0.5 0.75 1.0])
   _ (each ^4 (i \ seg! (tq i) (tq (i + 1)) (0.24 - 0.07 * i / 4.0)))
   ; ..the fork's two ways splayed either side of upright, a little toward the middle
   top (tq 4) up0 (unit (c+ [0.0 1.0 0.0] (c* 0.2 cdir))) sd (side (unit (c+ (tq 4) (c* -1.0 (tq 3)))))
   ; a leaf: a rachis drooping off the twig, its leaflets in pairs, widest in the middle
   (leaf! p twd) (p 1 < crown-y ? () (: rd (unit (c+ (spread g twd (rr g 0.5 1.2)) [0.0 -0.35 0.0]))
                    sv (side rd) ll (rr g 0.18 0.3) sh (rr g 0.75 1.15) ye (sq (rnd g)) ph (rr g 0.0 (2.0 * pi))
                    (each ^5 (m \ (: u ((m + 0.5) / 5.0) c (c+ p (c* (ll * u) rd))
                                     wd (0.09 * sin (pi * u) * (1.0 - 0.3 * u))
                                     (pt! (c+ c (c* wd sv)) 2 sh ye ph,
                                      pt! (c+ c (c* (0.0 - wd) sv)) 2 sh ye ph))))))
   ; a twig: its wood as points, leaves along it and one at its tip
   (twig! o ld) (: td (unit (c+ (spread g ld (rr g 0.4 1.1)) [0.0 -0.15 0.0]))
                   tl (rr g 0.5 1.2) e (inside (c+ o (c* tl td)))
                   nw (int (tl / 0.04)) nl (int (tl / 0.09))
                   (each ^nw (q \ pt! (lerp o e (q / (1.0 * nw))) 1 1.0 0.0 0.0),
                    each ^nl (q \ leaf! (lerp o e ((q + 1.0) / (nl + 1.0))) td),
                    leaf! e td))
   ; a limb: wood, twigs along its outer two thirds, and two smaller limbs off it, their
   ; wood as points
   (sub! o od) (: sd2 (unit (c+ (spread g od (rr g 0.4 0.9)) [0.0 0.1 0.0]))
                  se (inside (c+ o (c* (rr g 1.2 2.2) sd2)))
                  nw (int (sqrt (dot (c+ se (c* -1.0 o)) (c+ se (c* -1.0 o))) / 0.03))
                  (each ^nw (q \ pt! (lerp o se (q / (1.0 * nw))) 1 1.0 0.0 0.0),
                   each ^5 (j \ twig! (lerp o se (0.3 + 0.17 * j)) sd2)))
   (limb! o od) (: ld (unit (c+ (spread g od (rr g 0.8 1.4)) [0.0 0.25 0.0]))
                   le (inside (c+ o (c* (rr g 3.0 4.5) ld)))
                   nw (int (sqrt (dot (c+ le (c* -1.0 o)) (c+ le (c* -1.0 o))) / 0.025))
                   (each ^nw (q \ pt! (lerp o le (q / (1.0 * nw))) 1 1.0 0.0 0.0),
                    each ^6 (j \ twig! (lerp o le (0.3 + 0.14 * j)) ld),
                    sub! (lerp o le (rr g 0.3 0.45)) ld, sub! (lerp o le (rr g 0.5 0.65)) ld,
                    sub! (lerp o le (rr g 0.7 0.9)) ld))
   ; the two leaders, forking from the trunk's top, each in two pieces, with limbs
   (leader! sg) (: d (unit (turn up0 sd (sg * rr g 0.3 0.5)))
                   ln (rr g 5.0 6.0) m (c+ top (c* (ln * 0.5) d))
                   d2 (unit (c+ d [(rr g -0.1 0.1) 0.3 (rr g -0.1 0.1)]))
                   e (inside (c+ m (c* (ln * 0.5) d2)))
                   (seg! top m 0.14, seg! m e 0.09,
                    limb! (lerp top m 0.9) d, limb! (lerp m e 0.25) d2, limb! (lerp m e 0.5) d2,
                    limb! (lerp m e 0.75) d2, limb! e d2, limb! e d2))
   _ (leader! -1.0) _ (leader! 1.0)
   n (pts 'n) (col k) (gem-tray [n] (map (i \ pts i 0 k) ^n))
   (fld k) (gem-tray [n] (map (i \ 1.0 * pts i k) ^n))
   sl (map (i \ segs i) ^(segs 'n))
   ; the wood as rings of points, for the shadow the sun casts
   (rings s) (: a (s 0) b (s 1) r (s 2) ax (c+ b (c* -1.0 a)) l (sqrt (dot ax ax)) u (unit ax)
                p1 (side u) p2 (cross u p1) k (int (l / 0.1) + 1)
                (cat* (map (i \ (lerp a b (i / (1.0 * k))) @ c
                                  (map (j \ c+ c (c+ (c* (r * cos (j * 1.047)) p1) (c* (r * sin (j * 1.047)) p2))) ^6))
                           ^(k + 1))))
   (cat* ls) (foldl (acc \ l \ cat acc l) () ls)
   wood (cat* (map rings sl)) nwd #wood
   X (col 0) Y (col 1) Z (col 2)
   cen [(net X / n) (net Y / n) (net Z / n)]
   R (sqrt (amax ((X - cen 0) * (X - cen 0) + (Y - cen 1) * (Y - cen 1) + (Z - cen 2) * (Z - cen 2))) + 0.5)
   (wc k) (gem-tray [nwd] (map (p \ p k) wood))
   {'segs sl 'base base 'x X 'y Y 'z Z 'kind (fld 1) 'shade (fld 2) 'yel (fld 3) 'ph (fld 4)
    'shx (wc 0) 'shy (wc 1) 'shz (wc 2) 'c cen 'R R})
 ; the sun's map of the tree: every point and the wood's rings seen down the sun, a
 ; texel keeping how far toward the sun the tree stands there; () while the sun is down
 smap-n 128
 (smap-new tr s) (s 1 <= 0.0 ? ()
   (: e1 (side s) e2 (cross e1 s) c (tr 'c) R (tr 'R) n smap-n
      (pix X Y Z) (: qx (X - c 0) qy (Y - c 1) qz (Z - c 2)
                     iu (floor (((qx * e1 0 + qy * e1 1 + qz * e1 2) / (2.0 * R) + 0.5) * n))
                     iv (floor (((qx * e2 0 + qy * e2 1 + qz * e2 2) / (2.0 * R) + 0.5) * n))
                     (over -1 ((0 <= iu) * (iu < n) * (0 <= iv) * (iv < n)) (iv * n + iu)))
      (depth X Y Z) (X * s 0 + Y * s 1 + Z * s 2)
      m0 (iota (n * n) * 0.0 - 1e9)
      m1 (pin m0 (pix (tr 'x) (tr 'y) (tr 'z)) (depth (tr 'x) (tr 'y) (tr 'z)))
      m2 (pin m1 (pix (tr 'shx) (tr 'shy) (tr 'shz)) (depth (tr 'shx) (tr 'shy) (tr 'shz)))
      {'map m2 'pix pix 'depth depth}))
 ; the sun's map and each point's share of the sun, kept on the state until the sun has
 ; moved a step: [map clear]
 (sun-cache st tr s) (: k (int (s 0 * 400.0) * 1000000 + int (s 1 * 400.0) * 1000 + int (s 2 * 400.0))
   (k = st 'sun-key ? (st 'sun-cache)
      (: sm (smap-new tr s) X (tr 'x) Y (tr 'y) Z (tr 'z)
         c [sm (sun-clear X Y Z s * (1.0 - shade-of sm X Y Z))]
         (pins st 'sun-key k 'sun-cache c, c))))
 ; how much of the sun the tree takes at the points: some of it through the leaves
 (shade-of sm X Y Z) (sm ? (0.8 * (depth-of sm X Y Z + 0.3 < peep (sm 'map) (sm 'pix X Y Z) -1e9)) 0.0)
 (depth-of sm X Y Z) (sm 'depth X Y Z)
 ; the wood drawn into the buffers: each cylinder tried only on the pixels of its box on
 ; the screen, kept where it is nearer than what is there
 (wood! tr cam lt sm buf) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
   s (lt 'sun)
   (rel p) (c+ p (c* -1.0 e))
   (proj p) (rel p @ q (dot q f @ z [(w / 2.0 + foc * dot q rt / z) (h / 2.0 - foc * dot q uv / z)]))
   (one sg) (: a0 (sg 0) b0 (sg 1) r (sg 2)
     za (dot (rel a0) f) zb (dot (rel b0) f)
     ((za < 0.1 && zb < 0.1) ? ()
      (: a (za < 0.1 ? (lerp a0 b0 ((0.1 - za) / (zb - za))) a0)
         b (zb < 0.1 ? (lerp b0 a0 ((0.1 - zb) / (za - zb))) b0)
         pa (proj a) pb (proj b) rp (r * foc / max2 0.1 (min2 za zb) + 1.5)
         x0 (max2 0 (flo (min2 (pa 0) (pb 0) - rp))) x1 (min2 (w - 1) (flo (max2 (pa 0) (pb 0) + rp)))
         y0 (max2 0 (flo (min2 (pa 1) (pb 1) - rp))) y1 (min2 (h - 1) (flo (max2 (pa 1) (pb 1) + rp)))
         bw (x1 - x0 + 1) bh (y1 - y0 + 1)
         ((bw <= 0 || bh <= 0) ? ()
          (: ii (iota (bw * bh)) idx ((y0 + ii // bw) * w + x0 + ii % bw)
             ddx (peep (cam 'dx) idx 0.0) ddy (peep (cam 'dy) idx 0.0) ddz (peep (cam 'dz) idx 0.0)
             ax (c+ b0 (c* -1.0 a0)) L (sqrt (dot ax ax)) u (unit ax)
             wv (rel a0 @ q (c* -1.0 q)) wu (dot wv u) W (c+ wv (c* (0.0 - wu) u))
             dd (ddx * u 0 + ddy * u 1 + ddz * u 2)
             Wd (ddx * W 0 + ddy * W 1 + ddz * W 2)
             A (max (1.0 - dd * dd) 1e-9) C (dot W W - r * r)
             disc (Wd * Wd - A * C)
             t ((0.0 - Wd - sqrt (max disc 0.0)) / A)
             sa (wu + t * dd)
             hit ((0.0 < disc) * (0.0 < t) * (0.0 <= sa) * (sa <= L) * (t < peep (buf 't) idx 1e9))
             i2 (over -1 hit idx)
             nx ((W 0 + t * (ddx - dd * u 0)) / r) ny ((W 1 + t * (ddy - dd * u 1)) / r) nz ((W 2 + t * (ddz - dd * u 2)) / r)
             X (e 0 + t * ddx) Y (e 1 + t * ddy) Z (e 2 + t * ddz)
             p1 (side u)
             fur (0.75 + 0.5 * frac (sin ((nx * p1 0 + ny * p1 1 + nz * p1 2) * 9.0 + sa * 3.0) * 4375.85))
             nds (max 0.0 (nx * s 0 + ny * s 1 + nz * s 2))
             lit (nds * sun-clear X Y Z s * (1.0 - shade-of sm X Y Z) * lt 'sunk)
             bark (c* fur [0.17 0.15 0.13])
             irr (c+ (c* 0.9 (lt 'amb)) (c* lit (lt 'sunc)))
             cl (cm bark irr)
             (pins buf 't (pin (buf 't) i2 t) 'r (pin (buf 'r) i2 (cl 0))
                       'g (pin (buf 'g) i2 (cl 1)) 'b (pin (buf 'b) i2 (cl 2))))))))
   (each (tr 'segs) one))
 ; the twigs and leaves drawn into the buffers, a point a pixel, kept where nearer; the
 ; leaves sway, darken deep in the crown and glow where the sun is behind them
 (leaves! tr cam lt lc buf t0) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
   s (lt 'sun) lf (tr 'kind = 2.0) ph (tr 'ph)
   sw (0.025 * sin (t0 * 0.13 + ph)) sw2 (0.02 * sin (t0 * 0.09 + ph * 1.7))
   X (tr 'x + lf * sw) Y (tr 'y) Z (tr 'z + lf * sw2)
   qx (X - e 0) qy (Y - e 1) qz (Z - e 2)
   zc (qx * f 0 + qy * f 1 + qz * f 2)
   zs (max zc 0.1)
   cx (floor (w / 2.0 + foc * (qx * rt 0 + qy * rt 1 + qz * rt 2) / zs))
   cy (floor (h / 2.0 - foc * (qx * uv 0 + qy * uv 1 + qz * uv 2) / zs))
   dist (sqrt (qx * qx + qy * qy + qz * qz))
   ok ((0.1 < zc) * (0 <= cx) * (cx < w) * (0 <= cy) * (cy < h))
   idx (over -1 ok (cy * w + cx))
   i2 (over -1 (dist < peep (buf 't) idx 1e9) idx)
   clear (lc * lt 'sunk)
   mu ((qx * s 0 + qy * s 1 + qz * s 2) / dist)
   glow (lf * clear * sq (sat ((mu - 0.2) / 0.8)))
   sh (tr 'shade)
   base (cmix [0.16 0.14 0.12] (c+ (c* sh [0.2 0.34 0.09]) (c* (tr 'yel) [0.16 0.14 -0.02])) lf)
   irr (c+ (c* 0.8 (lt 'amb)) (c* (0.6 * clear) (lt 'sunc)))
   cl (c+ (cm base irr) (c* glow [0.45 0.55 0.12]))
   (pins buf 't (pin (buf 't) i2 dist) 'r (pin (buf 'r) i2 (cl 0))
             'g (pin (buf 'g) i2 (cl 1)) 'b (pin (buf 'b) i2 (cl 2))))
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
   ; the first of the four walls, the floor and the plane of the battlements' tops
   tx ((over (0.0 - a) (0.0 < dx) a - ex) / dx)
   tz ((over (0.0 - b) (0.0 < dz) b - ez) / dz)
   ty ((over 0.0 (0.0 < dy) top-h - ey) / dy)
   isx ((tx <= tz) * (tx <= ty)) isz ((1 - isx) * (tz <= ty))
   isy (1 - isx - isz) gnd (isy * (dy <= 0.0))
   t0w (min tx (min tz ty))
   px0 (ex + t0w * dx) py0 (ey + t0w * dy) pz0 (ez + t0w * dz)
   ; ..a wall over the parapet is there only under a battlement; a ray over the middle
   ; third may meet a battlement's end, in the wall's thickness
   solid ((py0 < hh) + isz * (hh <= py0) * (a / 3.0 < mag px0))
   gap ((1 - isy) * (1 - solid))
   sgn (over -1.0 (0.0 < dx) 1.0) ef (sgn * a / 3.0)
   te ((ef - ex) / dx) ye (ey + te * dy) ze (ez + te * dz)
   endf (gap * isz * (b <= mag ze) * (mag ze <= b + wall-t) * (hh <= ye) * (ye < top-h))
   sky (isy * (0.0 < dy) + gap - endf)
   t (over t0w endf te)
   px (over px0 endf ef) py (over py0 endf ye) pz (over pz0 endf ze)
   ; --- the stuff: a wall's texel by which wall and where on it, a battlement's end
   ; going on round from its face, else the floor's ---
   al (over (over px isx pz) endf (sgn * (a / 3.0 + mag ze - b)))
   wid (isx * (over 1 (0.0 < dx) 0) + isz * (over 3 (0.0 < dz) 2))
   nx (isx * (over 1.0 (0.0 < dx) -1.0) - endf * sgn) nz ((isz - endf) * (over 1.0 (0.0 < dz) -1.0))
   nu (peep wall-nus wid 0)
   tu (max 0 (min (nu - 1) (floor ((al + over yard-a isx yard-b) / ts))))
   tv (max 0 (min (nv - 1) (floor (py / ts))))
   wi (peep wall-offs wid 0 + tv * nu + tu)
   fi (max 0 (min (fl-nz - 1) (floor ((pz + b) / fts))) * fl-nx + max 0 (min (fl-nx - 1) (floor ((px + a) / fts))))
   wm (mp 'wall) fm (mp 'floor)
   (wg k) (peep (wm k) wi 0.0) (fg k) (peep (fm k) fi 0.0)
   alb (cmix [(wg 'r) (wg 'g) (wg 'b)] [(fg 'r) (fg 'g) (fg 'b)] gnd)
   glass ((1 - gnd) * peep (wm 'glass) wi 0)
   ; --- the light: the sun where it faces and gets in past the rim and the battlements,
   ; the sky's light by how much of the sky is seen and how it faces the sun's side, and a
   ; little back off the walls the sun is on ---
   s (lt 'sun) sx (s 0) sy (s 1) sz (s 2)
   nd (nx * sx + gnd * sy + nz * sz)
   tr (st 'tree) sc (sun-cache st tr s) sm (sc 0)
   lit ((0.0 < nd) * sun-clear px py pz s * (1.0 - shade-of sm px py pz))
   dir (nd * lit * lt 'sunk * 0.9)
   sv (over (0.45 + 0.5 * min 1.0 (py / hh)) gnd 0.42 * (1.0 + 0.2 * lt 'day * (nx * sx + nz * sz)))
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
   col0 (cmix surf skyc sky)
   ; ..and the tree, drawn over all of it where it is nearer
   cam {'e [ex ey ez] 'f [(sth * cph) sph (cth * cph)] 'r [cth 0.0 (0.0 - sth)] 'u [(0.0 - sth * sph) cph (0.0 - cth * sph)]
        'w (st 'w) 'h (st 'h) 'foc (st 'foc) 'dx dx 'dy dy 'dz dz}
   buf {'t (over t sky 1e9) 'r (col0 0) 'g (col0 1) 'b (col0 2)}
   _ (wood! tr cam lt sm buf) _ (leaves! tr cam lt (sc 1) buf t0)
   col [(buf 'r) (buf 'g) (buf 'b)]
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
