; court -- the inner courtyard of an apartment block, first person in half blocks: the
; level after the shaft. twenty feet by thirty of concrete gone green with moss, a grated
; sump in the middle, four floors of brick painted grey and chipped to the red beneath,
; windows lit and dark, a honey locust leaning in from the north-east corner, and the sky
; at the top of the well.
;
; the long walls run north and south with four windows a floor; the short walls carry
; two narrow ones a floor and the stair's three between the floors, and over their outer
; thirds a battlement each. the tree is grove's, grown afresh each run, its trunk leaning
; toward the middle; the sky is sky's, the sun at this hour of this day at a fixed
; latitude under the weather -- clear, partly or mostly cloudy, or overcast, the sky
; drawn smooth or in the grass game's pixels -- and runs on faster than the clock: the
; sun comes in over the rim where it can, low and orange on the top of a wall at either
; end of the day, and windows come on and go off with the hours.
;
; every pixel casts its own ray, so the look tilts as far as the neck does. the scene is
; trays a frame wide: what each ray meets, the stuff there, the sun on it past the rim,
; and the colour out -- 24-bit where COLORTERM says so, else the 256 palette dithered.
; court-new, court-step, court-move and court-frame are pure, gated by test/host/tree.l;
; only court-walk and court-run tie the tty. court-walk takes a stage already raised.
;
; run: love lore court  h l or the arrows turn, k j step, u n look up and down;
;                       [ ] an hour back or on, t the time's pace, c the cloud, v the
;                       sky smooth or in pixels; q or esc leaves
;      love lore court [clear|partly|mostly|overcast] [smooth|pixel]   the weather to start
(module (court court-run court-walk court-main court-new court-size court-step court-move
         court-frame court-sun court-light court-clock court-now court-pens court-maps
         tree-grow sun-clear top-h block-h crown-y
         fps yard-a yard-b floor-h floors wall-h eye-h body-r lat paces)
(borrow 'rove)
(borrow 'view)                          ; the screen, the pens, the hash, the loop
(borrow 'vec)                           ; triples, and the noise
(borrow 'sky)                           ; the sun, its light, the sky's colour
(borrow 'grove)                         ; the honey locust
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
 ; the litter and the falling leaves: sticks in the ring, leaves on the ground, how low a
 ; leaf lies, how many landed are kept, a leaf let go about one frame in so many, how fast
 ; it falls; and the leaves' colours, dry yellow, tan, brown, a few still green
 stick-n 22 leaf-n 420 leaf-y 0.006 fallen-n 400 drop-every 70 fall-v 0.45
 hues [[0.6 0.5 0.17] [0.5 0.39 0.19] [0.36 0.26 0.14] [0.33 0.38 0.13]]
 bay (2.0 * yard-b / 4.0)               ; a long wall's window bay
 ; --- the time: 'sim is the wall clock's local seconds, 'dst what summer adds to it ---
 ; now, as [local-seconds dst]: the zone's offset now, against the least of it a season on, two and three
 (court-now _) (: s (clock 0 // 1000) zone ((cite 'kore 'tz-zone) 0)
                  (off u) (zone ? (zone u 0) 0)
                  o (off s) std (foldl (a \ k \ min2 a (off (s + k * 7889400))) o [1 2 3])
                  [(1.0 * (s + o)) (o - std)])
 (court-clock st) (: d (day-secs (st 'sim)) hh (int (d / 3600.0)) mm (int (d / 60.0) % 60)
                     (p2 v) (v < 10 ? ("0" + show v) (show v))
                     (p2 hh + ":" + p2 mm))
 ; the sun as [east up north] and its light, at the scene's hour
 (court-sun st) (sky-sun (st 'sim) (st 'dst) lat)
 (court-light st) (sky-light (court-sun st) (st 'wx) (st 'sim))
 ; --- the state: the screen as view lays it, where the player stands and looks ('th the
 ; bearing, 'ph the pitch), the clock, its pace, and the pixels' rays ---
 ; the weather a run starts under, unless it is said: the cover thrown, the sky smooth
 (court-new w h now) (: sd (int (now 0)) tr (tree-grow sd)
                        st {'px 0.0 'pz (0.0 - yard-b + 1.4) 'th 0.0 'ph 0.5
                            'sim (now 0) 'dst (now 1) 'pace 0 'shown 40 't 0
                            'deep 0 'done 0 'tree tr 'litter (litter tr sd) 'fall () 'fallen ()
                            'wx (sky-weather (throw sd 7 71 4) 'smooth)}
                       (court-size st w (h // 2)))
 ; the screen w cells by r rows, and each pixel's offsets from the middle, and its dither
 (court-size st w r) (: h (2 * r) n (w * h) i (iota n) x (i % w) y (i // w)
   (pins (view! st w h (h // 2)) 'U ((x + 0.5 - w / 2.0) / (w / 2.0)) 'V ((h / 2.0 - y - 0.5) / (w / 2.0))
         'bay (view-bayer w h)))
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
        99 (tell (pin st 'wx (sky-weather ((st 'wx 'cover + 1) % 4) (st 'wx 'style))))
        118 (tell (pin st 'wx (sky-weather (st 'wx 'cover) (st 'wx 'style = 'pixel ? 'smooth 'pixel))))
        st))
 ; a frame's motion: the clock, and the leaves -- now and then one lets go of the top of
 ; the crown, drifts down and lies where it lands
 (court-move st) (: t (st 't) tops (st 'litter 'tops)
   born (? (throw t 3 97 drop-every = 0 && two? tops)
           (tops (throw t 5 89 #tops) @ p [[(p 0) (p 1) (p 2) (throw t 7 83 628 / 100.0) (throw t 9 79 3)]])
           ())
   moved (map (q \ fall-step q t) (cat born (st 'fall)))
   down (filter (q \ q 1 <= leaf-y) moved)
   (pins st 'sim (st 'sim + paces (st 'pace) / fps)
            'fall (filter (q \ leaf-y < q 1) moved)
            'fallen (newest fallen-n (cat down (st 'fallen)))))
 ; --- the maps: the walls and the floor, laid once a run in texels
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
 (court-maps _) (maps 'wall ? maps (pins maps 'wall (wall-map ()) 'floor (floor-map ())))
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
 ; --- the tree: a honey locust in the north-east quarter, leaning toward the middle; its
 ; crown starts a metre under the wall tops, and below them a point is kept inside the
 ; walls, or not grown if it would be in one ---
 crown-y (wall-h - 1.0)
 (inside p) (p 1 < wall-h ? [(clamp (p 0) (0.15 - yard-a) (yard-a - 0.15)) (max2 0.05 (p 1))
                            (clamp (p 2) (0.15 - yard-b) (yard-b - 0.15))] p)
 (in-wall? p) (p 1 < wall-h && (yard-a - 0.1 < mag (p 0) || yard-b - 0.1 < mag (p 2)))
 (tree-grow seed) (: g {'s (seed % 2147483647 + 1)}
                     (rr lo hi) (: v ((g 's * 1103515245 + 12345) % 2147483648) (pin g 's v, lo + (hi - lo) * v / 2147483648.0))
                     base [(rr 1.3 1.8) 0.0 (rr 2.2 2.9)]
                     (grove-new {'seed seed 'base base 'toward [0.0 0.0] 'crown crown-y
                                 'inside inside 'keep? (p \ !(in-wall? p))}))
 ; --- what lies under it: a ring of sticks round the foot of the trunk, and the leaves the
 ; crown has dropped, laid once a run from the tree's own seed; and the high leaves a
 ; falling one may start from. a point is [x y z r g b up], up 1 for one lying flat ---
 (newest n l) (n < 1 || atom? l ? () (<l . newest (n - 1) >l))
 (cat* ls) (foldl (acc \ l \ cat acc l) () ls)
 ; a leaf lying at x z, turned ang: its stalk and a leaflet either side, six along
 (lying x z ang c) (: ca (cos ang) sa (sin ang)
   (cat* (map (j \ (: u ((j - 2.5) * 0.012)
                     (map (v \ [(x + u * ca - v * sa) leaf-y (z + u * sa + v * ca) (c 0) (c 1) (c 2) 1.0])
                          [-0.01 0.0 0.01]))) ^6)))
 (litter tr seed) (: g {'s (seed % 2147483647 + 7)}
   (rr lo hi) (: v ((g 's * 1103515245 + 12345) % 2147483648) (pin g 's v, lo + (hi - lo) * v / 2147483648.0))
   bs (tr 'base) X (tr 'x) Y (tr 'y) Z (tr 'z) K (tr 'kind) n #X top (amax Y)
   ; a leaf of the crown, thrown for until one comes up, or the first point
   (pick k ok?) (: i (int (rr 0.0 (n - 0.5))) ((k < 1 || (peep K i 0.0 = 2.0 && ok? i)) ? i (pick (k - 1) ok?)))
   ; ..each stick lies across the ring, tilted off it a little: two rows of points, bark
   ; brown or weathered grey
   (stick i) (: a (i * 2.0 * pi / stick-n + rr -0.12 0.12) rad (rr 0.46 0.56)
                cx (bs 0 + rad * cos a) cz (bs 2 + rad * sin a)
                yaw (a + pi / 2.0 + rr -0.45 0.45) ln (rr 0.28 0.48) k (int (ln / 0.008))
                cy (cos yaw) sy (sin yaw) th (rr 0.012 0.02)
                c (c* (rr 0.75 1.15) (rr 0.0 1.0 < 0.3 ? [0.42 0.38 0.33] [0.34 0.24 0.15]))
                ; ..three strands wide and three high, the top one the lightest
                (cat* (map (j \ (: u (((j + 0.5) / k - 0.5) * ln)
                                   (cat* (map (v \ (map (m \ [(cx + u * cy - v * sy) (0.01 + m * th) (cz + u * sy + v * cy)
                                                               ((0.8 + 0.12 * m) * c 0) ((0.8 + 0.12 * m) * c 1) ((0.8 + 0.12 * m) * c 2) 1.0])
                                                         ^3))
                                              [(0.0 - th) 0.0 th])))) ^k)))
   ; ..each leaf under one of the crown's, blown a little way off, kept off the walls
   (leaf _) (: i (pick 40 (j \ 1)) x (clamp (peep X i 0.0 + rr -0.4 0.4) (0.08 - yard-a) (yard-a - 0.08))
               z (clamp (peep Z i 0.0 + rr -0.4 0.4) (0.08 - yard-b) (yard-b - 0.08))
               ang (rr 0.0 (2.0 * pi)) c (c* (rr 0.8 1.1) (hues (int (rr 0.0 3.99))))
               (lying x z ang c))
   l (cat (cat* (map stick ^stick-n)) (cat* (map leaf ^leaf-n)))
   hi (filter (i \ peep K i 0.0 = 2.0 && top - 1.5 < peep Y i 0.0) ^n)
   tops (two? hi ? (map (q \ hi (int (rr 0.0 (#hi - 0.5))) @ i [(peep X i 0.0) (peep Y i 0.0) (peep Z i 0.0)]) ^120) ())
   {'pts (bits l) 'tops tops})
 ; points as the trays bits! draws
 (bits l) (: m #l (col k) (gem-tray [m] (map (q \ 1.0 * q k) l))
             {'x (col 0) 'y (col 1) 'z (col 2) 'r (col 3) 'g (col 4) 'b (col 5) 'up (col 6)})
 ; a falling leaf, [x y z ph hue]: down at its own pace, swung side to side as it goes, and
 ; kept inside the walls; it lands at the floor
 (fall-step q t) (: x (q 0) y (q 1) z (q 2) ph (q 3) w (1.0 * t * 0.11 + ph)
   [(clamp (x + 0.3 * sin w / fps) (0.08 - yard-a) (yard-a - 0.08)) (max2 leaf-y (y - fall-v / fps))
    (clamp (z + 0.3 * cos (w * 0.7) / fps) (0.08 - yard-b) (yard-b - 0.08)) ph (q 4)])
 ; the leaves loose on the scene as points: those falling, turning as they go, and those landed
 (loose st) (: t (st 't)
   (falling q) (: a (q 3 + 1.0 * t * 0.3) c (hues (q 4))
                  (map (j \ [(q 0 + (j - 1.5) * 0.012 * cos a) (q 1 + (j - 1.5) * 0.006 * sin (a * 1.3))
                              (q 2 + (j - 1.5) * 0.012 * sin a) (c 0) (c 1) (c 2) 0.0]) ^4))
   (landed q) (lying (q 0) (q 2) (q 3) (hues (q 4)))
   l (cat (cat* (map falling (st 'fall))) (cat* (map landed (st 'fallen))))
   (two? l ? (bits l) ()))
 ; points drawn into the buffers, a point a pixel where nearer, lit as the floor is: the
 ; sun where it gets in and the tree lets it through, and the sky's light
 (bits! P cam lt sm buf) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
   s (lt 'sun) X (P 'x) Y (P 'y) Z (P 'z)
   qx (X - e 0) qy (Y - e 1) qz (Z - e 2)
   zc (qx * f 0 + qy * f 1 + qz * f 2) zs (max zc 0.1)
   cx (floor (w / 2.0 + foc * (qx * rt 0 + qy * rt 1 + qz * rt 2) / zs))
   cy (floor (h / 2.0 - foc * (qx * uv 0 + qy * uv 1 + qz * uv 2) / zs))
   dist (sqrt (qx * qx + qy * qy + qz * qz))
   ok ((0.1 < zc) * (0 <= cx) * (cx < w) * (0 <= cy) * (cy < h))
   idx (over -1 ok (cy * w + cx))
   i2 (over -1 (dist < peep (buf 't) idx 1e9) idx)
   up (P 'up) face (up * max2 (s 1) 0.0 + (1.0 - up) * 0.5)
   lit (sun-clear X Y Z s * (1.0 - grove-shade sm X Y Z) * lt 'sunk * face * 0.9)
   irr (c+ (c* 0.42 (lt 'amb)) (c* lit (lt 'sunc)))
   cl (cm [(P 'r) (P 'g) (P 'b)] irr)
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
   s (lt 'sun) sx (s 0) sy (s 1) sz (s 2)
   tr (st 'tree) sm (grove-sun tr s sun-clear 0)
   ; ..each pixel shaded only as what it shows: a surface's on the surfaces' pixels, the
   ; sky's on the sky's, each gathered there and scattered back
   (surface px py pz isx isz gnd endf sgn ze dx dz)
    (:
     ; --- the stuff: a wall's texel by which wall and where on it, a battlement's end
     ; going on round from its face, else the floor's ---
     al (over (over px isx pz) endf (sgn * (a / 3.0 + mag ze - b)))
     wid (isx * (over 1 (0.0 < dx) 0) + isz * (over 3 (0.0 < dz) 2))
     nx (isx * (over 1.0 (0.0 < dx) -1.0) - endf * sgn) nz ((isz - endf) * (over 1.0 (0.0 < dz) -1.0))
     nu (peep wall-nus wid 0)
     tu (max 0 (min (nu - 1) (floor ((al + over yard-a isx yard-b) / ts))))
     trow (max 0 (min (nv - 1) (floor (py / ts))))
     wi (peep wall-offs wid 0 + trow * nu + tu)
     fi (max 0 (min (fl-nz - 1) (floor ((pz + b) / fts))) * fl-nx + max 0 (min (fl-nx - 1) (floor ((px + a) / fts))))
     wm (mp 'wall) fm (mp 'floor)
     (wg k) (peep (wm k) wi 0.0) (fg k) (peep (fm k) fi 0.0)
     alb (cmix [(wg 'r) (wg 'g) (wg 'b)] [(fg 'r) (fg 'g) (fg 'b)] gnd)
     glass ((1 - gnd) * peep (wm 'glass) wi 0)
     ; --- the light: the sun where it faces and gets in past the rim and the battlements,
     ; the sky's light by how much of the sky is seen and how it faces the sun's side, and a
     ; little back off the walls the sun is on ---
     nd (nx * sx + gnd * sy + nz * sz)
     lit ((0.0 < nd) * sun-clear px py pz s * (1.0 - grove-shade sm px py pz))
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
     (cmix (cm alb irr) inglass glass))
   G (iota (1 - sky)) S (iota sky) (only ix v) (peep v ix 0)
   sf (surface (only G px) (only G py) (only G pz) (only G isx) (only G isz) (only G gnd) (only G endf)
               (only G sgn) (only G ze) (only G dx) (only G dz))
   hv (sky-colour lt (st 'wx) (only S dx) (only S dy) (only S dz) ex ez (st 'sim) t0)
   z0 (dx * 0.0)
   col0 (map (c \ pin (pin z0 G (sf c)) S (hv c)) ^3)
   ; ..and the tree, drawn over all of it where it is nearer
   cam {'e [ex ey ez] 'f [(sth * cph) sph (cth * cph)] 'r [cth 0.0 (0.0 - sth)] 'u [(0.0 - sth * sph) cph (0.0 - cth * sph)]
        'w (st 'w) 'h (st 'h) 'foc (st 'foc) 'dx dx 'dy dy 'dz dz}
   buf {'t (over t sky 1e9) 'r (col0 0) 'g (col0 1) 'b (col0 2)}
   _ (grove-wood! tr cam lt sun-clear buf) _ (grove-leaves! tr cam lt sun-clear buf t0)
   ; ..and what lies on the floor, and the leaves falling
   _ (bits! (st 'litter 'pts) cam lt sm buf) _ (loose st @ P (tablet? P ? (bits! P cam lt sm buf)))
   ; ..and the eye's gain and shoulder
   (sky-tone lt [(buf 'r) (buf 'g) (buf 'b)]))
 ; the frame: the clock in the corner for a while after the time is touched
 (court-frame st) (: w (st 'w) h (st 'h) c (court-pens st) deep (st 'deep)
   px (deep ? (view-deep-pens c) (view-cube-pens c (st 'bay)))
   pace (paces (st 'pace))
   wx (st 'wx)
   txt (" " + court-clock st + (pace = 0.0 ? "  still" (pace = 1.0 ? "" ("  x" + show (int pace))))
        + "  " + sky-says (wx 'cover) + (wx 'style = 'pixel ? ", in pixels " " "))
   bands (st 't < st 'shown ? {0 [1 txt (deep ? 249660 255) (deep ? 33288 235)]} {})
   (deep ? (view-deep-frame w h px bands)
      (view-frame w h (y \ peep px (iota w + w * y) 0) bands)))
 ; --- the walk, on view's loop; court-run raises the stage ---
 ; ..wx the weather to start under, or () for the run's own
 (court-walk wx) (view-walk {'new (w \ h \ (: st (pin (court-new w h (court-now ())) 'deep
                                                     (elem (getenv "COLORTERM") ["truecolor" "24bit"]))
                                              (wx ? (pin st 'wx wx) st)))
                            'size court-size 'frame court-frame 'key court-step 'tick court-move
                            'fps fps 'song (hn \ ()) 'linger 0 'next ()})
 (court-run wx) (view-run (_ \ court-walk wx))
 court-usage "usage: love lore court [clear|partly|mostly|overcast] [smooth|pixel]   (h l turn, k j step, u n look, [ ] an hour, t the pace, c the cloud, v the sky's style; q or esc leaves)"
 ; the words, in either order: a cover, a style, or both
 (court-main as) (: (ix l w) (: (go i) (i < #l ? (l i = name w ? i (go (i + 1))) ()) (go 0))
   (cov w) (ix sky-covers w) (sty w) (ix sky-styles w)
   cs (filter charm? (map cov as)) ss (filter charm? (map sty as))
   (? (2 < #as || #as != #cs + #ss || 1 < #cs || 1 < #ss)
      (say err ("court: " + court-usage + "\n"), flush err, 2)
      (court-run (#as ? (sky-weather (#cs ? <cs (throw (int (court-now () 0)) 7 71 4)) (#ss ? sky-styles <ss 'smooth))))))
 _ ((cite 'lore 'lore-enlist) 'court (udoor 'court court-main court-usage 1 1)))
) ; module court
