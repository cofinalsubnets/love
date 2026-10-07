; stones -- a slot canyon in sandstone, first person in half blocks. the player starts a
; little way in from its mouth, between walls a stride or two apart that open toward the
; sky, carved smooth by the floods that come down it in the rains. the canyon winds on
; north, and opens on a round bowl, its sloping sides stepped in rows like an
; amphitheatre's: in the middle a worn brown block like an altar, stained dark on top,
; and round it an octagon of standing stones, dark, rounded and leaning, the one north of
; north-west missing, the sand scuffed where it stood. a few more stand about
; the rows, an audience, somewhere new each run. turning back and walking out
; of the mouth ends it.
;
; the land is drawn in triangles (mesh.l, over facets): built once from the same shapes
; whose field of distances the player walks against, lit once an hour of the sky by its
; sun -- down in the slot most of the light is the sky's and the walls' own glow -- and
; drawn every frame, the sky where it leaves the screen bare. out as half blocks, or as
; kitty's pixels on a terminal that takes them. stones-new, stones-step and stones-frame
; are pure, gated by test/host/stones.l; only stones-walk and stones-run tie the tty.
;
; run: love lore stones [--time HH:MM] [--kitty|--cells]
;      h l or the arrows turn, k j step, u n look up and down, space kneels at the altar
;      (the bottom row names them for the first seconds of a run);
;      there 1 to 5, or k j and enter, choose what to do, and a walking key or space stands
;      again; q or esc leaves, or walk back out of the canyon
(module (stones stones-run stones-walk stones-main stones-new stones-size stones-step stones-move move-at curve acts ghost-on? post-batch stones-light
         stones-frame stones-pens stones-opts stones-field stones-ground stones-blocks slot-x
         fps eye-h zc floor-r row-w row-h rows rim-r exit-z lat)
(borrow 'rove)
(borrow 'view)                          ; the screen, the pens, the hash, the loop
(borrow 'vec)                           ; triples, and the noise
(borrow 'sky)                           ; the sun, its light, the sky's colour
(borrow 'mesh)                          ; the triangles, lit and drawn
(:
 fps 20
 lat (37.0 * pi / 180.0)               ; the colorado plateau
 eye-h 1.6 body-r 0.25
 walk-v 2.6 turn-v 1.6 tilt-v 1.2         ; metres, and radians, a second
 kneel-h 1.12                             ; the eye kneeling
 slow-v 0.9                               ; ..and the pace of a walk the eye makes on its own
 stride 0.7                               ; a step, in metres
 reach 2.2                                ; how near the altar a kneel can start
 dlg-pause 1.0                            ; seconds after an act before the choices come back
 help-t 12.0                              ; seconds the keys are named at the start
 help-text "h/j/k/l move  ·  u/n look up/down  ·  space interacts"
 ; the choices at the altar, and the keys that stand a kneeler up once they are put away
 acts ["Breathe" "Weep" "Bleed" "Beg" "Wait"]
 rise-keys [32 104 108 107 106 117 110 -1 -2 -8 -9]
 ; each act a move made from the kneel: keys [t offset] for the eye's height, its pitch,
 ; its tilt and how far it leans forward; how long; and the drops it lets fall, [t kind]
 (act-keys i) (? (i = 0)
   ; a long breath in, the chin rising and the chest back, held, then out, a little below
   {'y [[0.0 0.0] [0.5 -0.006] [3.5 0.035] [4.4 0.037] [8.4 -0.012] [9.6 0.0]]
    'ph [[0.0 0.0] [0.5 -0.012] [3.5 0.12] [4.4 0.13] [8.4 -0.05] [9.6 0.0]]
    'ro [[0.0 0.0] [4.0 0.012] [8.0 -0.006] [9.6 0.0]]
    'fw [[0.0 0.0] [3.5 -0.02] [4.4 -0.02] [8.4 0.012] [9.6 0.0]] 'len 9.8 'ev ()}
   (i = 1)
   ; the head bowed, hunched over, the sobs in fits of quick catches, the tears falling
   {'y [[0.0 0.0] [1.0 -0.03] [1.3 -0.02] [1.45 -0.032] [1.6 -0.018] [1.75 -0.033] [1.9 -0.016] [2.5 -0.04]
        [3.0 -0.022] [3.15 -0.034] [3.3 -0.02] [3.45 -0.036] [4.2 -0.045] [4.6 -0.025] [4.75 -0.035]
        [4.9 -0.022] [5.05 -0.036] [5.2 -0.024] [6.0 -0.046] [6.6 -0.04] [7.4 -0.042] [8.6 0.0]]
    'ph [[0.0 0.0] [1.0 -0.4] [1.3 -0.36] [1.45 -0.41] [1.6 -0.35] [1.75 -0.42] [1.9 -0.34] [2.5 -0.45]
         [3.0 -0.37] [3.15 -0.43] [3.3 -0.36] [3.45 -0.44] [4.2 -0.47] [4.6 -0.38] [4.75 -0.44]
         [4.9 -0.37] [5.05 -0.45] [5.2 -0.38] [6.0 -0.48] [6.6 -0.42] [7.4 -0.44] [8.6 0.0]]
    'ro [[0.0 0.0] [1.5 0.03] [3.0 -0.02] [4.5 0.035] [6.0 -0.015] [7.4 0.01] [8.6 0.0]]
    'fw [[0.0 0.0] [1.0 0.05] [7.4 0.06] [8.6 0.0]] 'len 8.8
    'ev (map (t \ [t 'tear]) [1.7 2.3 3.2 3.6 4.3 4.95 5.4 6.2 6.9])}
   (i = 2)
   ; leant in over the altar, looking down at its top; a flinch, as at a cut; the blood
   ; dripping from the hand held over it, and back
   {'y [[0.0 0.0] [1.2 -0.08] [1.9 -0.08] [1.97 -0.095] [2.3 -0.085] [5.6 -0.08] [6.8 0.0]]
    'ph [[0.0 0.0] [1.2 0.02] [1.9 0.02] [1.96 0.09] [2.4 -0.02] [5.6 0.0] [6.8 0.0]]
    'ro [[0.0 0.0] [1.9 0.0] [1.97 0.09] [2.4 0.06] [3.4 0.07] [4.6 0.04] [5.8 0.0]]
    'fw [[0.0 0.0] [1.2 0.42] [5.6 0.44] [6.8 0.0]] 'len 7.0
    'ev (map (t \ [t 'blood]) [2.4 2.9 3.3 3.8 4.2 4.7 5.1])}
   (i = 3)
   ; down, the face to the sand and held there; up at the altar from the ground; kneeling
   ; again, up at the sky, and three times the head thrown forward, calling
   {'y [[0.0 0.0] [1.2 -0.3] [2.4 -0.9] [3.0 -0.95] [5.0 -0.95] [6.2 -0.88] [6.8 -0.88] [8.4 0.0] [10.3 0.0]
        [10.55 0.02] [11.1 0.0] [11.65 0.022] [12.2 0.0] [12.85 0.022] [13.4 0.0] [15.4 0.0]]
    'ph [[0.0 0.0] [1.2 -0.5] [2.4 -0.9] [3.0 -0.92] [5.0 -0.9] [6.2 0.75] [6.8 0.7] [8.4 0.25] [8.8 0.25]
         [10.0 1.4] [10.3 1.4] [10.55 1.5] [11.1 1.4] [11.65 1.52] [12.2 1.4] [12.85 1.52] [13.4 1.38]
         [14.0 1.4] [15.4 0.0]]
    'ro [[0.0 0.0] [2.4 0.04] [5.0 0.03] [6.2 0.0] [8.4 -0.02] [10.0 0.0] [15.4 0.0]]
    'fw [[0.0 0.0] [1.2 0.3] [2.4 0.55] [3.0 0.58] [5.0 0.58] [6.2 0.5] [6.8 0.5] [8.4 0.0] [10.3 0.0]
         [10.55 0.035] [11.1 0.0] [11.65 0.035] [12.2 0.0] [12.85 0.035] [13.4 0.0] [15.4 0.0]] 'len 15.6 'ev ()}
   ())
 ; --- the land, in metres: x east, z north, y up. the slot runs north from its mouth
 ; through the plateau to the bowl, whose middle is at x 0, z zc: a flat floor floor-r
 ; across, then rows rising row-h every row-w out to rim-r, and the bowl's wall over them
 ; to the plateau's top ---
 zc 120.0 floor-r 14.0 row-w 2.4 row-h 1.5 rows 7
 rim-r (floor-r + rows * row-w)
 exit-z -52.0                           ; out on the open sand, near the lamppost: the run done
 ; the slot's line, winding, and straight where it meets the bowl
 (slot-x z) (sat ((zc - 30.0 - z) / 25.0) * (1.9 * sin (z / 11.0) + 0.9 * sin (z / 5.3)))
 ; the lamppost, far out on the plain past the mouth, a step aside of the slot's line; and
 ; how long a wait at night brings back the missing stone
 post-z -62.0 post-x (slot-x post-z + 1.5)
 ghost-wait 1800.0
 ; ..how far out of the mouth, 0 inside to 1 on the plain
 (mouth z) (sat ((-8.0 - z) / 22.0))
 ; ..its half width at a height: narrow at the floor, scalloped by the floods, opening
 ; toward the top, and wide at the mouth
 (half y z) (1.15 + 0.3 * sin (z / 7.0 + 1.0) + y * (0.08 + 0.006 * y) + 0.3 * sin (0.7 * y + z / 4.0)
             + 7.0 * mouth z)
 ; the plateau's top, falling away to the plain south of the mouth
 (top x z) (: k (sat ((z + 40.0) / 30.0))
   (k * k * (3.0 - 2.0 * k) * (21.0 + 2.5 * sin (x / 13.0 + z / 17.0) + 1.5 * sin (z / 9.0 - x / 7.0))))
 ; the bowl's floor at x z: its rows wavering a little round it, each a tread and a riser
 (bowl x z) (: r (sqrt (x * x + sq (z - zc))) rr (r + 0.6 * sin (x / 4.0 + z / 6.0))
   k (min (max ((rr - floor-r) / row-w) 0.0) (1.0 * rows)) kf (floor k) s (sat ((k - kf - 0.5) * 2.0))
   (row-h * (kf + s * s * (3.0 - 2.0 * s)) + 2.2 * max (rr - rim-r) 0.0))
 zend (zc - floor-r - 1.0)               ; where the slot's own walls end, at the bowl's floor
 ; the open air's distance to the rock, as near as the march may step: the slot, the bowl
 ; and the sky over the plateau each open, and the rock what none of them is
 (slot-d x y z) (min (min (0.8 * (half y z - mag (x - slot-x z))) (zend - z)) y)
 ; ..the bowl's floor stepped over at its true height, inside the round the rows start at
 (bowl-d x y z) (max (0.4 * (y - bowl x z)) (min y (floor-r - 0.6 - sqrt (x * x + sq (z - zc)))))
 (top-d x y z) (0.65 * (y - top x z))
 (stones-field x y z) (max (max (slot-d x y z) (bowl-d x y z)) (top-d x y z))
 ; ..and over trays, each place asked only of the parts near enough to be the nearest:
 ; south of the rows the bowl is far, and past the slot's end the slot is
 south-z (zc - rim-r - 12.0) north-z (zend + 3.0)
 (field x y z) (: a (iota (z < south-z)) b (iota (north-z < z)) c (iota ((south-z <= z) * (z <= north-z)))
   (g ix v) (peep v ix 0.0)
   o1 (#a = 0 ? (z * 0.0) (: X (g a x) Y (g a y) Z (g a z) (pin (z * 0.0) a (max (slot-d X Y Z) (top-d X Y Z)))))
   o2 (#b = 0 ? o1 (: X (g b x) Y (g b y) Z (g b z) (pin o1 b (max (bowl-d X Y Z) (top-d X Y Z)))))
   (#c = 0 ? o2 (: X (g c x) Y (g c y) Z (g c z) (pin o2 c (stones-field X Y Z)))))
 ; the ground under a place: the lowest of the slot's floor, the bowl and the plateau
 (stones-ground x z) (: in (mag (x - slot-x z) < half 1.0 z - body-r && z < zend)
   (min (in ? 0.0 99.0) (min (bowl x z) (top x z))))
 ; --- the blocks: the altar in the middle and the stones, each [x y z yaw hx hy hz kind],
 ; its middle, its turn about the vertical, its half sizes across, up and through, and
 ; kind 0 the altar, 1 a stone. the octagon is the same every run, the audience thrown ---
 ring-r 6.0
 altar [0.0 0.35 zc 0.0 1.1 0.35 0.5 0]
 (stone x z yaw w ht th) [x (stones-ground x z + 0.5 * ht - 0.15) z yaw (0.5 * w) (0.5 * ht) (0.5 * th) 1]
 ; the ring: eight places a turn round, half a place short of east and on through north,
 ; so none stands between the slot and the altar; the fourth, north of north-west, is empty
 (ring-a k) ((k - 0.5) * pi / 4.0)
 ring (filter two? (map (k \ (k = 3 ? ()
                             (: a (ring-a k) j (throw k 1 31 100 / 100.0)
                                (stone (ring-r * cos a) (zc + ring-r * sin a) (pi / 2.0 - a)
                                       (1.0 + 0.2 * j) (2.9 + 0.5 * throw k 2 37 100 / 100.0) 0.7))))
                        ^8))
 ; the audience: three to six, on the rows, none in the notch the slot cuts, none too near
 ; another
 (audience sd) (: n (3 + throw sd 1 41 4)
   (try k got) (? (n <= #got || 60 < k) got
     (: a (pi * (throw sd k 43 1000 / 500.0)) row (1 + throw sd k 47 (rows - 1))
        r (floor-r + (row + 0.2) * row-w) x (r * cos a) z (zc + r * sin a)
        notch (mag (wrap (a + pi / 2.0)) < 0.45)
        near (any (b \ sq (b 0 - x) + sq (b 2 - z) < 25.0) got)
        (notch || near ? (try (k + 1) got)
           (try (k + 1) ((stone x z (pi / 2.0 - a + 0.4 * (throw sd k 53 100 / 100.0 - 0.5))
                               (0.7 + 0.3 * throw sd k 59 100 / 100.0) (1.3 + 1.1 * throw sd k 61 100 / 100.0)
                               (0.5 + 0.2 * throw sd k 67 100 / 100.0)) . got)))))
   (try 0 ()))
 (stones-blocks sd) (altar . cat ring (audience sd))
 ; ..and toward the sun from where a ray met: how much of it gets past the rock, tried at
 ; a few places out along the way, soft at a shadow's edge by how near the rock passes for
 ; how far. the rock is thick, so the places can stand wide apart
 sun-ts [0.2 0.6 1.5 3.5 7.0 12.0 20.0 32.0]
 (shadow X Y Z s) (foldl (res \ t \ min res (8.0 * field (X + t * s 0) (Y + t * s 1) (Z + t * s 2) / t))
                         (X * 0.0 + 1.0) sun-ts @ r (sat r))
 ; --- the rock's stuff: sandstone in its beds, warmer and redder low, paler up toward the
 ; plateau, laminated finely in sets that sweep along the scallops the floods carved; up
 ; close, the grain. drifted sand where the rock lies flat. the fine lines fade with the
 ; distance t, before they are finer than the pixels ---
 (rock X Y Z ny t) (: band (Y + 0.9 * sin (X * 0.21 + Z * 0.13) + 0.6 * sin (Z * 0.37 - X * 0.11))
   tone (0.5 + 0.5 * sin (band * 1.7))
   sweep (0.7 * Y + Z / 4.0 + 0.4 * sin (Z / 2.3 + X * 0.3))
   lam (1.0 + sat (1.0 - t / 40.0) * (0.06 * sin (band * 9.0 + 2.0 * sin (X * 0.8 + Z * 0.6)) + 0.08 * sin (sweep * 7.0)))
   mot (0.9 + 0.2 * vn (X * 1.3 + Z * 0.7) (Y * 2.1) 83 + 0.12 * sat (1.0 - t / 6.0) * (vn (X * 6.0 + Z * 5.0) (Y * 7.0) 89 - 0.5))
   stone (c* (lam * mot) (cmix (cmix [0.66 0.29 0.15] [0.84 0.5 0.29] tone) [0.88 0.72 0.52] (sat ((Y - 13.0) / 8.0))))
   rip (1.0 + 0.06 * sat (1.0 - t / 12.0) * sin (X * 6.0 + Z * 4.0 + 2.0 * sin (Z * 1.1)))
   sand (c* rip (cmix [0.8 0.53 0.33] [0.86 0.66 0.45] (mouth Z)))
   (cmix stone sand (sat ((ny - 0.8) / 0.12))))
 ; the sun and its light at the scene's hour, under its weather
 (stones-sun st) (sky-sun (st 'sim) (st 'dst) lat)
 (stones-light st) (sky-light (stones-sun st) (st 'wx) (st 'sim))
 ; --- the land as triangles, built once a run and drawn by facets (src/apps/lore/mesh.l):
 ; the slot's two walls swept up the canyon and on over the plateau's edge a little way,
 ; under it; the bowl turned round its middle, each row at its own wavering radius, the
 ; slot's notch cut from it; the plateau about them, coarse, open over both. a vertex's
 ; colour the rock's own there, lit once by the hour's sun and sky, and a texture over it
 ; the fine beds and the grain ---
 tx 16.0                                  ; texels a metre
 ; the bowl's rows as knots [rr y] out from the middle: the floor a ring a metre, then a
 ; tread and a riser eased up to the next; past the rim the wall to the plateau, and on
 ; under it
 knots (: (row k) (: r0 (floor-r + k * row-w) h (k * row-h)
                     [[(r0 + 0.5 * row-w) h] [(r0 + 0.65 * row-w) (h + 0.156 * row-h)]
                      [(r0 + 0.75 * row-w) (h + 0.5 * row-h)] [(r0 + 0.85 * row-w) (h + 0.844 * row-h)]
                      [(r0 + row-w) (h + row-h)]])
          (map (k \ [(1.0 * k) 0.0]) ^(int floor-r) + [[floor-r 0.0]] + foldr (+) () (map row ^rows)
           + map (d \ [(rim-r + d) (rows * row-h + 2.2 * d)]) [1.0 2.5 4.0 5.5 7.0 10.0 15.0]))
 ; the rows' height at x z as the bowl's triangles lay it: straight between its rings,
 ; each ring's height as it lays it, out along the same line from the middle
 (bowl-m x z) (: r (max (sqrt (x * x + sq (z - zc))) 0.01) rr (r + 0.6 * sin (x / 4.0 + z / 6.0))
   (seg l) (atom? >>l || rr < >l 0 0 ? l (seg >l))
   l (seg knots) a <l b (>l 0) t (sat ((rr - a 0) / (b 0 - a 0)))
   (ky kn) (: s ((r + kn 0 - rr) / r) (ring-y kn (x * s) (zc + (z - zc) * s)))
   (b 0 < rr ? (top x z) (: ya (ky a) (ya + t * (ky b - ya)))))
 ; ..and the rock's rim there, the lower of the rows and the plateau
 (rim-y x z) (min (top x z) (bowl-m x z))
 ; ..how far the plateau's own sheets sink at the bowl's rim, under its rings: they cut
 ; the rim's crease short, a chord under it
 (sink x z) (1.2 * sat (1.0 - (bowl x z - top x z) / 2.0))
 ; a ring's place at angle a: where the rows' wavering puts its radius rr
 (ring-at rr a) (: (go r k) (: x (r * sin a) z (zc + r * cos a)
                            (k = 0 ? [x z] (go (rr - 0.6 * sin (x / 4.0 + z / 6.0)) (k - 1))))
   (go rr 2))
 ; ..its height there: the knot's, and the plateau's a little under where it is the top
 (ring-y kn x z) (min (kn 1) (top x z) - (rim-r + 5.0 < kn 0 ? 0.08 0.0))
 ; ..and where it meets the slot's wall on side sg, on its face: halved toward it from the
 ; south, east or west of it
 (notch-a kn sg) (: (miss a) (: p (ring-at (kn 0) a) y (ring-y kn (p 0) (p 1))
                                ((p 0 - slot-x (p 1) - sg * half (max y 0.0) (p 1)) * sg))
   (go lo hi k) (: m (0.5 * (lo + hi)) (k = 0 ? m (miss m < 0.0 ? (go m hi (k - 1)) (go lo m (k - 1)))))
   (sg > 0 ? (go pi (pi - 1.5) 16) (go pi (pi + 1.5) 16)))
 ; ..whether the slot crosses a ring at all
 (cut? kn) (ring-at (kn 0) pi @ p (p 1 < zend))
 ; ..each ring the slot cuts, its end on side sg as [z y x], south first
 (row-ends sg) (sort (map (kn \ (: p (ring-at (kn 0) (notch-a kn sg)) [(p 1) (ring-y kn (p 0) (p 1)) (p 0)]))
                         (filter cut? knots)))
 dz 1.0 z0 -42.0                          ; the slot's rings, from where the plain is flat
 nw 8                                     ; rows up a wall
 lips [2.0 5.0 9.0]                       ; ..and out over the plateau, under its edge
 ; a slot wall, side sg -1 the west and 1 the east, its profile i up and over at ring j:
 ; the east's i and j crossed, so both face the slot. its foot is sunk under the floor
 ; ..its rings a metre apart from one under the plain's edge, and where the rows are the
 ; rim, one at each row's end and no other, so its top is the rows' own edge; the last at
 ; the first row's, where the slot ends
 (wall-zs sg) (: c (map (e \ e 0) (row-ends sg))
   u (filter (z \ z < <c - 0.05) (map (j \ z0 + (j - 1) * dz) ^(int ((zend - z0) / dz) + 2)))
   (cat u c))
 (wall sg)
  (: zs (wall-zs sg) nz (#zs - 1) np (nw + #lips)
     ; ..its top where the rock's rim is at the wall's own lean
     (rim-at sx z) (: (gap T) ((rim-y (sx + sg * half T z) z) - T)
                      (go lo hi k) (: m (0.5 * (lo + hi)) (k = 0 ? m (gap m > 0.0 ? (go m hi (k - 1)) (go lo m (k - 1)))))
                      (go 0.0 (max 0.0 (top sx z)) 14))
     ; ..and where the rows are the rim, its top through the rows' own ends and straight
     ; between them as the rows' edge is, so the two meet with nothing between
     es (row-ends sg)
     (edge z) (: (go l) (? (atom? l) () (<l 0 = z) [(<l 1) (<l 2)] (atom? >l) () (<l 0 <= z <= >l 0 0)
                           (: a <l b (>l 0) t ((z - a 0) / max (b 0 - a 0) 1e-6) [(a 1 + t * (b 1 - a 1)) (a 2 + t * (b 2 - a 2))])
                           (go >l))
                (go es))
     ; ..its first ring, under the plain, sunk well under it
     (at i j) (: z (zs j) sx (slot-x z) ed (edge z) dn (z < z0 - 0.5 ? 0.3 0.0) T (two? ed ? (ed 0) (rim-at sx z - dn))
                 (? (i = nw && two? ed) [(ed 1) T z (tx * z) (tx * T)]
                    (i <= nw) (: y ((T + 0.3) * i / nw - 0.3) x (sx + sg * half (max y 0.0) z) [x y z (tx * z) (tx * y)])
                    (: x (sx + sg * (half T z + lips (i - nw - 1))) y (rim-y x z - 0.08 - sink x z - dn)
                       [x y z (tx * z) (tx * (T + mag (x - sx)))])))
     ; ..the face in the rock's beds, and its lips apart in the plateau's own sand, from the
     ; face's top points: where they show through the plain they are the plain
     (sheet lo n tex) (: (f i j) (: v (at (lo + i) j) ((tex = 1) ? [(v 0) (v 1) (v 2) (tx * v 0) (tx * v 2)] v))
                         (sg < 0 ? (mesh-grid nz n (\ j i (f i j)) tex [1.0 1.0 1.0]) (mesh-grid n nz f tex [1.0 1.0 1.0])))
     m (mesh-join [(sheet 0 nw 0) (sheet nw #lips 1)])
     ; ..its lips only under the plateau, every corner, not where the bowl's rows are the ground
     (mesh-keep-all m (\ x y z (mag (x - slot-x z) < half (max y 0.0) z + 0.5 || top x z - 0.3 <= bowl x z))))
 ; ..its floor, sand from wall to wall, from a row dipped under the plain's edge to one
 ; straight across between the first row's ends and through their middle, the bowl's own
 ; points there, where the bowl takes over;
 ; and a skirt on past each wall's foot: a wall's rows are straight, its curve between
 ; them not where the floor's edge is
 floor-n 2
 (slot-floor _) (: (last l) (l (#l - 1)) pw (last (row-ends -1)) pe (last (row-ends 1)) nz (int ((min (pw 0) (pe 0) - 0.3 - z0) / dz) + 1)
   m (mesh-grid (floor-n + 2) (nz + 1) (\ i j (: k (min (max (i - 1) 0) floor-n) sk (? (i = 0) -0.5 (i = floor-n + 2) 0.5 0.0)
                                         p (? (j <= nz) (: z (z0 + (j - 1) * dz) hw (half 0.0 z) [(slot-x z - hw + 2.0 * hw * k / floor-n) z])
                                              (: f (1.0 * k / floor-n) [(pw 2 + f * (pe 2 - pw 2)) (pw 0 + f * (pe 0 - pw 0))]))
                                         x (p 0 + sk) z (p 1)
                                         [x (? (sk != 0.0) -0.3 (j = 0) -0.01 0.0) z (tx * x) (tx * z)]))
              1 [1.0 1.0 1.0])
   ; ..lit as the level sand it is, its skirt not leaning its edges
   (mesh (map (v \ take 5 v + [0.0 1.0 0.0] + drop 8 v) (m 0)) (m 1)))
 bowl-n 72
 ; the bowl turned round its middle, each ring at its own wavering radius; a ring the slot
 ; crosses runs from the slot's west wall round by the north to its east wall, its ends
 ; on them, so the rows meet the walls with nothing cut away. before the first ring cut, a
 ; bridge: that ring's own points, closed across the slot's end through the middle of its
 ; ends, so the floor's last whole ring meets it all round and the slot's floor meets it
 ; point for point
 (bowl-mesh ks)
  (: (go l pc) (atom? l ? ()
                  (: kn <l c (cut? kn) e (c ? [(notch-a kn -1) (notch-a kn 1)] [pi (3.0 * pi)])
                     ((c && (pc = 0) ? [[kn e 1]] ()) + [[kn e 0]] + go >l c)))
     rs (go ks 0)
     (lerp p q f) [(p 0 + f * (q 0 - p 0)) (p 1 + f * (q 1 - p 1))]
     (at i j) (: rg (rs j) kn (rg 0) e (rg 1) w (e 0) E (e 1 + (e 1 < e 0 + pi ? (2.0 * pi) 0.0))
                 ; ..its ends at their own angles, the very points the walls' tops are
                 (on a) (ring-at (kn 0) a)
                 (cut k) (? (k = 0) (on w) (k = bowl-n) (on (e 1)) (on (w + (E - w) * k / bowl-n)))
                 p (? (rg 2 = 0) (cut i) (0 < i < bowl-n) (cut i) (lerp (on w) (on (e 1)) 0.5))
                 x (p 0) z (p 1) y (ring-y kn x z)
                 ; ..its sand laid by place, the risers' by height as well
                 [x y z (tx * x) (tx * (z + y))])
     (mesh-grid bowl-n (#rs - 1) at 1 [1.0 1.0 1.0]))
 ; the plateau, four metres a cell about the slot and the bowl, and out to the haze the
 ; cells growing: where it is the top, not the bowl's air nor the slot's
 cell 4.0
 (plateau _) (: (out k d s) (k = 0 ? () ([s + d] + out (k - 1) (1.6 * d) (s + d)))
   far (out 9 6.4 0.0)
   xs (map (o \ -80.0 - o) (rev far) + map (i \ -80.0 + i * cell) ^41 + map (o \ 80.0 + o) far)
   zs (map (o \ -110.0 - o) (rev far) + map (j \ -110.0 + j * cell) ^76)
   ; ..its edge over the bowl's rim sunk under the bowl's last rings, and by the slot under
   ; the walls' lips, past the slot's floor where it starts; lit as the top it was
   (by-slot x z) (: d (mag (x - slot-x z))
                   (z0 - 0.5 < z && z < zend && d < half (top x z) z + 9.5 && (z0 + 0.5 < z || half 0.0 z + 1.0 < d)))
   m0 (mesh-grid (#xs - 1) (#zs - 1) (\ i j (: x (xs i) z (zs j) y (top x z - sink x z)
                                           [x y z (tx * x) (tx * z)])) 1 [1.0 1.0 1.0])
   m (mesh (map (v \ (by-slot (v 0) (v 2) ? ([(v 0) (v 1 - 0.15)] + drop 2 v) v)) (m0 0)) (m0 1))
   ; ..a cell only where its corners and its middle are the top -- not down in the bowl,
   ; and clear of the slot by a metre -- so its edge stays inside where the bowl's wall and
   ; the slot's lips run on under it
   (ok x z) (top x z <= bowl x z + 0.05 && (zend <= z || z <= z0 || mag (x - slot-x z) > half (top x z) z + 1.0))
   (mesh-keep (mesh-keep-all m (\ x y z (ok x z))) (\ x y z (ok x z))))
 ; a block hewn round: rings up it at heights t, (prof j) [t r], each its section (sec a)
 ; [x z] out to the block's sides scaled by r, n round; worn by amp unevenly all over and
 ; leant by lean, each block its own way by where it stands; its texels round the section,
 ; or for flat, across it by place
 (hewn b n nr sec prof amp lean flat tex)
  (: hx (b 4) hy (b 5) hz (b 6)
     lx (lean * (vn (0.7 * b 0) (0.7 * b 2) 113 - 0.5)) lz (lean * (vn (0.7 * b 2) (0.7 * b 0) 127 - 0.5))
     m (mesh-grid n nr
         (\ i j (: a (-2.0 * pi * i / n) ca (cos a) sa (sin a) q (sec a) p (prof j) t (p 0)
                    wear (1.0 + amp * (vn (ca * 1.3 + t * 2.0 + b 0) (sa * 1.3 - t * 1.4 + b 2) 101 - 0.5)
                           + 0.4 * amp * (vn (ca * 3.5 + t * 6.0 + b 2) (sa * 3.5 + b 0) 103 - 0.5))
                    y (2.0 * hy * t - hy) up (y + hy)
                    X (hx * p 1 * q 0 * wear + lx * up) Z (hz * p 1 * q 1 * wear + lz * up)
                    [X y Z (tx * (flat ? (X + Z) (hx * a))) (tx * y)]))
         tex [1.0 1.0 1.0])
     (mesh-move m [(b 0) (b 1) (b 2)] (b 3)))
 ; a standing stone: round, a little wider at its foot, tapering up to a rounded top
 stone-r 14
 (stone-prof j) (: t (1.0 * j / stone-r)
   [t ((1.0 + 0.06 * sat (1.0 - t / 0.08)) * (1.0 - 0.3 * t) * (t < 0.7 ? 1.0 (sqrt (max 0.0 (1.0 - sq ((t - 0.7) / 0.3))))))])
 (round-sec a) [(sin a) (cos a)]
 ; ..the altar: square, its edges and its top's worn round
 altar-prof [[0.0 1.0] [0.25 1.0] [0.5 1.0] [0.7 1.0] [0.84 0.99] [0.93 0.96] [0.98 0.92] [1.0 0.86] [1.0 0.0]]
 (squarish a) (: (sp v) ((v < 0.0 ? -1.0 1.0) * ((1.0 / 3.0) (mag v))) [(sp (sin a)) (sp (cos a))])
 ; the altar, its top stained: a decal over it, its holes the stone
 (block-mesh b) (: yaw (b 3) dx (0.86 * b 4) dz (0.86 * b 6)
   (b 7 = 0
    ? (mesh-join [(hewn b 48 (#altar-prof - 1) squarish altar-prof 0.1 0.12 1 2)
                  (mesh-move (mesh-quad [[(0.0 - dx) 0.0 (0.0 - dz)] [dx 0.0 (0.0 - dz)] [dx 0.0 dz] [(0.0 - dx) 0.0 dz]]
                                        [[0.0 0.0] [64.0 0.0] [64.0 32.0] [0.0 32.0]] 4 [1.0 1.0 1.0])
                             [(b 0) (b 1 + b 5 + 0.006) (b 2)] yaw)])
      (hewn b 24 stone-r round-sec stone-prof 0.6 0.3 0 3)))
 ; ..and the sand scuffed where the missing stone stood
 (scar _) (: a (ring-a 3) x (ring-r * cos a) z (zc + ring-r * sin a)
   (mesh-move (mesh-quad [[-1.2 0.0 -1.0] [1.2 0.0 -1.0] [1.2 0.0 1.0] [-1.2 0.0 1.0]]
                         [[0.0 0.0] [64.0 0.0] [64.0 64.0] [0.0 64.0]] 5 [1.0 1.0 1.0])
              [x (stones-ground x z + 0.012) z] (pi / 2.0 - a)))
 ; the rock's own colour at each vertex, its fine lines left to the texture: over the
 ; texture's mean, which darkens it as much
 (rock-cols pk) (: c (pk 'cols) al (rock (c 0) (c 1) (c 2) (c 7) 60.0)
   (pins pk 'cols (take 8 c + map (k \ al k / 0.88) ^3)))
 ; --- the textures, 64 texels a side, four metres: the rock's beds, the sand's ripples, the
 ; altar's brown and a stone's darker, worn in streaks, pits and crust, the stain with
 ; holes where there is none, and the sand scuffed where the stone was the same ---
 ; ..f over four metres made to tile: each texel eased toward f a tile back, across and
 ; down, as it nears the far edge, so the last row meets the first
 (tex-of f) (: L (64.0 / tx)
   (mesh-tex 64 (\ x y (: u (x / tx) v (y / tx) a (u / L) b (v / L)
                          (cmix (cmix (f u v) (f (u - L) v) a) (cmix (f u (v - L)) (f (u - L) (v - L)) a) b)))))
 (grey g) [g g g]
 ; ..stone worn: its colour c, with paler crust c2, streaked down by sk, pitted
 (worn c c2 sk) (\ u v (: g (0.75 + 0.4 * vn (u * 3.0) (v * 2.3) 71)
                       streak (sk * (vn (u * 5.0) (v * 0.5) 107 - 0.5) + 0.5)
                       pit (sat ((vn (u * 3.0) (v * 3.5) 79 - 0.5) * 2.0))
                       crust (sat ((vn (u * 2.0) (v * 2.0) 109 - 0.5) * 2.5))
                       (c* (g * (0.7 + 0.5 * streak) * (1.0 - 0.25 * pit)) (cmix c c2 (0.8 * crust)))))
 ; ..its waves whole in the tile, tq a turn over four metres
 tq (pi / 2.0)
 texs-of (_ \ [(tex-of (\ u v (grey (0.88 + 0.05 * sin (v * 6.0 * tq + 2.0 * sin (u * tq)) + 0.05 * sin (v * 3.0 * tq + u * tq)
                                      + 0.06 * (vn (u * 6.0) (v * 7.0) 89 - 0.5)))))
               (tex-of (\ u v (grey (0.86 + 0.06 * sin (u * 4.0 * tq + v * 3.0 * tq + 2.0 * sin (v * tq)) + 0.08 * (vn (u * 9.0) (v * 9.0) 97 - 0.5)))))
               (tex-of (worn [0.44 0.3 0.19] [0.55 0.42 0.3] 0.0))
               (tex-of (worn [0.34 0.21 0.13] [0.46 0.33 0.22] 1.0))
               (mesh-tex 64 (\ x y (: u (x / 64.0 * 2.2 - 1.1) w (y / 32.0 - 0.5)
                                      m (0.7 * vn (x / 64.0 * 5.7 + 3.0) (y / 32.0 * 3.4 + 5.0) 73 + 0.75 - sq (u / 1.15) - sq (w / 0.55))
                                      (32.0 <= y || m < 0.45 ? ()
                                         (cmix [0.2 0.12 0.09] [0.12 0.075 0.06] (sat ((m - 0.8) * 6.0)))))))
               (mesh-tex 64 (\ x y (: u (x / 32.0 - 1.0) w (y / 32.0 - 1.0)
                                      m (0.6 * vn (x / 64.0 * 4.0 + 7.0) (y / 64.0 * 4.0 + 2.0) 131 + 0.8 - sq u - sq w)
                                      ; ..scuffed: lumps and hollows, the ripples gone, a little damp underneath
                                      lump (vn (x / 64.0 * 14.0) (y / 64.0 * 14.0) 137) dig (vn (x / 64.0 * 6.0 + 3.0) (y / 64.0 * 6.0) 139)
                                      (m < 0.4 + 0.15 * lump ? ()
                                         (c* (0.72 + 0.4 * lump) (cmix [0.84 0.52 0.29] [0.62 0.37 0.19] (sat ((m - 0.5) * 2.0) * (0.4 + 0.6 * dig))))))))])
 ; the land, kept for every run in the process: the rock packed, its colours its own;
 ; the textures
 kept {}
 (land _) (: l (peep kept 'land ())
   (tablet? l ? l
      (: rk (rock-cols (mesh-pack (mesh-join [(wall -1) (wall 1) (slot-floor ()) (bowl-mesh knots) (plateau ())])))
         l2 {'rock rk 'texs (texs-of ())}
         (pin kept 'land l2, l2))))
 ; --- the light baked: each vertex's share of the sun past the rock, of the
 ; sky by how much of it is open overhead and how near the rock crowds it, and the glow
 ; the sunlit walls throw down the slot. again once the sun has gone on two minutes ---
 (light-of st lt) (: s (lt 'sun)
   (c \ (: X (c 0) Y (max (c 1) 0.02) Z (c 2) nx (c 5) ny (c 6) nz (c 7) h 0.02
           ox (X + 0.05 * nx) oy (Y + 0.05 * ny) oz (Z + 0.05 * nz)
           sun (0.0 < lt 'sunk * s 1 ? (shadow ox oy oz s) (X * 0.0))
           d0 (field X Y Z)
           gn (max (sqrt (sq (field (X + h) Y Z - d0) + sq (field X (Y + h) Z - d0) + sq (field X Y (Z + h) - d0)) / h) 0.2)
           sv (sat (field X (Y + 5.0) Z / (4.0 * gn)))
           ao (sat (0.45 + 0.55 * field (X + 0.4 * nx) (Y + 0.4 * ny) (Z + 0.4 * nz) / (0.4 * gn)))
           g (lt 'sunk * sat (s 1 * 3.0) * (1.0 - sv) * ao * (0.25 + 0.5 * sat (Y / 14.0)))
           [sun (ao * (0.18 + 0.82 * sv) * (0.75 + 0.25 * ny)) [(0.95 * g) (0.5 * g) (0.24 * g)]])))
 ; ..and the blocks' shadows each frame, by the sun's view of them over the bowl, sun-n
 ; texels across sun-half either side of its middle
 sun-n 1024 sun-half 40.0 sun-deep 60.0 sun-bias 0.12
 (scene st) (: was (peep st 'scene ()) sim (st 'sim)
   (tablet? was && mag (sim - was 'at) < 120.0 ? (was 'sc)
      (: lt (stones-light st) L (land ()) lit (light-of st lt)
         rk (mesh-bake-sun (L 'rock) lt lit 1.0) bl (mesh-bake-sun (st 'bpk) lt lit 1.0)
         sv (mesh-sun-view lt [0.0 3.0 zc] sun-half sun-deep)
         sun (0.0 < lt 'sunk * lt 'sun 1 ? [sv (mesh-sun-map sv bl sun-n) (sun-bias / sun-deep)] ())
         sc [[(rk 0) (bl 0)] [(rk 1) (bl 1)] sun]
         (pin st 'scene {'at sim 'sc sc}, sc))))
 ; --- the frame: the land and the blocks drawn, the sky where they leave it bare, both
 ; through the eye's gain; out as half blocks, or as kitty's pixels where the terminal
 ; takes them ---
 fov (pi / 2.0)
 kitty-w 640                              ; kitty's picture about this many pixels across
 sky-k 2                                  ; ..and the sky asked every sky-k columns
 ; kitty's pictures go up as ids 7 and 8 by turns, the last taken down only once the next
 ; is over it, the two in one synchronised update: one id put up again would go blank first
 kitty-id 7
 (kitty-del id) (esc + "_Ga=d,d=I,i=" + show id + ",q=2" + esc + "\\")
 kitty-gone (kitty-del 7 + kitty-del 8)
 ; ..'kp pixels a column, and twice that a row: one, for half blocks
 (stones-pens st) (: lt (stones-light st) k (peep st 'kp 1) w (k * st 'w) h (k * st 'h) b (breath (peep st 'mt 0.0))
   e [(st 'px) (st 'py + b 0) (st 'pz)]
   v (mesh-eye w h e (st 'th) (st 'ph + b 1) (peep st 'ro 0.0) fov 0.05 900.0)
   hz (mesh-haze v lt (st 'wx) (st 'sim))
   sc0 (scene st) db (drop-batch st lt)
   ; ..and after the land the drops, the lamppost once it stands, and last the glow
   xs (filter two? [db (post-batch st lt) (ghost-batch st lt)])
   sc (#xs = 0 ? sc0 [(cat (sc0 0) (map (b \ b 0) xs)) (cat (sc0 1) (map (b \ b 1) xs)) (sc0 2)])
   (mesh-frame v sc ((land ()) 'texs) [(hz 0) (hz 1) (hz 2) 150.0 900.0] 8 (1.5 * lt 'expo)
               (mesh-sky lt (st 'wx) e (st 'sim) (st 't) (k = 1 ? 1 (sky-k * k)))))
 (stones-frame st) (: w (st 'w) h (st 'h) k (peep st 'kp 1) f0 (stones-pens st) kit (st 'kitty)
   dl (charm? (st 'dlg)) r (h // 2) bw 22 bh (#acts + 2) r0 (max2 0 (r - bh - 2)) c0 (max2 0 ((w - bw) // 2))
   hp (st 'mt < help-t && !dl)
   ; ..the frame the choices are put away, their cells blanked once: a terminal keeping
   ; text and picture in one cell would lose the picture there every frame
   _ (pin st 'shut (? dl 0 (: s (peep st 'shut 2) (s < 2 ? (s + 1) s))))
   ; ..under kitty's the choices' ground darkened in the picture, and the keys' line, the
   ; text over it
   f (? (dl && kit) (dim f0 (k * w) (k * c0) (2 * k * r0) (k * bw) (2 * k * bh))
        (hp && kit) (dim f0 (k * w) 0 (2 * k * (r - 1)) (k * w) (2 * k)) f0)
   m (menu st r0 c0 bw bh + keys-line st r w)
   (? kit (: n (peep st 'kn 0) _ (pin st 'kn (1 - n))
             (esc + "[?2026h" + mesh-kitty f (k * w) (k * h) w (h // 2) (kitty-id + n)
              + kitty-del (kitty-id + 1 - n) + m + esc + "[?2026l"))
      (st 'deep) (mesh-cells f w h 1 0 {} + m)
      (mesh-cells f w h 0 (st 'bay) {} + m)))
 ; a part of a frame W wide darkened: x0 y0 its corner, bw by bh its size, in pixels
 (dim f W x0 y0 bw bh) (: i (iota (bw * bh)) ix ((y0 + i // bw) * W + x0 + i % bw) v (peep f ix 0)
   (pin f ix ((((v >> 16 & 255) * 2 // 5) << 16) | (((v >> 8 & 255) * 2 // 5) << 8) | ((v & 255) * 2 // 5))))
 ; the choices as text at row r0, column c0, bw by bh cells: the marked one bright, over a
 ; dark ground in cells; under kitty, over the picture, and blanked when they are put away
 (menu st r0 c0 bw bh) (: kit (st 'kitty) deep (kit || st 'deep) c (st 'dlg)
   bg (kit ? "[49m" (deep ? "[48;2;22;17;14m" "[48;5;233m"))
   hi (deep ? "[1;38;2;244;234;216m" "[1;38;5;230m") lo (deep ? "[22;38;2;156;144;128m" "[22;38;5;245m")
   (at j) (esc + "[" + show (r0 + j + 1) + ";" + show (c0 + 1) + "H")
   (line j) (: i (j - 1)
     (0 < j && j < bh - 1 ? (esc + (i = c ? hi lo) + pad ((i = c ? " › " "   ") + show (i + 1) + "  " + acts i) bw " ")
        (pad "" bw " ")))
   (? (charm? c) (foldl (\ o j (o + at j + esc + bg + line j)) "" ^bh + esc + "[0m")
      (kit && st 'shut = 1) (foldl (\ o j (o + at j + esc + "[0m" + pad "" bw " ")) "" ^bh)
      ""))
 ; the keys named along the bottom row r, w wide, for the first help-t seconds and not over
 ; the choices; under kitty, blanked a while after
 (keys-line st r w) (: kit (st 'kitty) deep (kit || st 'deep) t (st 'mt)
   bg (kit ? "[49m" (deep ? "[48;2;22;17;14m" "[48;5;233m"))
   fg (deep ? "[22;38;2;196;184;166m" "[22;38;5;250m")
   at (esc + "[" + show r + ";1H")
   (? (t < help-t && !(charm? (st 'dlg)))
        (at + esc + bg + esc + fg + pad (pad "" (max2 0 ((w - vlen help-text) // 2)) " " + help-text) w " " + esc + "[0m")
      (kit && t < help-t + 1.0) (at + esc + "[0m" + pad "" w " ")
      ""))
 ; ..a terminal that shows kitty's pixels, by what it says of itself: mitty, kitty,
 ; ghostty, wezterm
 (kitty-term? _) (: (has e s) (has? (getenv e) s)
   (? (0 < #(getenv "MITTY")) 1 (has "TERM" "kitty") 1 (0 < #(getenv "KITTY_WINDOW_ID")) 1
      (has "TERM_PROGRAM" "ghostty") 1 (has "TERM_PROGRAM" "WezTerm") 1 0))
 ; --- the state: the screen as view lays it, where the player stands and looks ('th the
 ; bearing, 'ph the pitch, 'py the eye's height), the clock, the weather, the blocks. a run
 ; starts a little way in from the mouth, facing on up the slot ---
 ; the weather thrown: the desert's mostly clear
 (cover-of sd) (throw sd 3 89 20 @ k (k < 15 ? 0 1))
 (stones-new w h now sd) (: bs (stones-blocks sd)
   st {'px (slot-x 0.0) 'pz 0.0 'py eye-h 'th 0.0 'ph 0.12 'sim (now 0) 'dst (now 1)
       'wx (sky-weather (cover-of sd) 'smooth) 't 0 'deep 0 'kitty 0 'kp 1 'done 0 'eye 'walk 'mt 0.0 'ro 0.0
       'dlg () 'sel 0 'dlg-at () 'drops () 'splats () 'nd 0
       'blocks bs 'bpk (mesh-pack (mesh-join (scar () . map block-mesh bs)))}
   (stones-size st w (h // 2)))
 ; the screen w cells by r rows, two pixels a row, and its dither; as kitty's, 'kp times
 ; as many pixels each way
 (stones-size st w r) (: h (2 * r)
   (pins (view! st w h (h // 2)) 'bay (view-bayer w h) 'kp (st 'kitty ? (max2 1 (kitty-w // w)) 1)))
 ; --- moving: over the sand and up and down the rows, but not up the rock, nor off its
 ; edge where it drops sheer, nor through a block;
 ; sliding along what stops a step. out past the mouth, the run is done ---
 (free? st x z) (: g (stones-ground x z) g0 (stones-ground (st 'px) (st 'pz))
   (g < g0 + 0.7 && g0 - 0.9 < g && g < rows * row-h + 0.3
    && !(any (b \ (: c (cos (b 3)) sn (sin (b 3)) qx (x - b 0) qz (z - b 2)
                     u (qx * c - qz * sn) w (qx * sn + qz * c)
                     (mag u < b 4 + body-r && mag w < b 6 + body-r))) (st 'blocks))))
 ; ..a step that meets the rock goes on along it, the part of it into the rock taken off
 ; and a hair more, so it keeps clear; else as much of it as goes, east or north
 (put! st x z) (: x0 (st 'px) z0 (st 'pz) dx (x - x0) dz (z - z0)
   (? (free? st x z) (pins st 'px x 'pz z)
      (: e 0.05 y (st 'py - 0.6)
         gx (stones-field (x0 + e) y z0 - stones-field (x0 - e) y z0)
         gz (stones-field x0 y (z0 + e) - stones-field x0 y (z0 - e))
         gl (max2 (sqrt (gx * gx + gz * gz)) 1e-9) nx (gx / gl) nz (gz / gl)
         k (min2 0.0 (dx * nx + dz * nz) - 0.05 * sqrt (dx * dx + dz * dz))
         sx (x0 + dx - k * nx) sz (z0 + dz - k * nz)
         (? (free? st sx sz) (pins st 'px sx 'pz sz) (free? st x z0) (pin st 'px x) (free? st x0 z) (pin st 'pz z) st))))
 ; ..each key as far as the time since the last frame, 'dt, carries it
 (stones-step st k) (: th (st 'th) dt (peep st 'dt (1.0 / fps))
   (step d) (put! st (st 'px + d * sin th) (st 'pz + d * cos th))
   (? (st 'done) st
      (charm? (st 'dlg)) (dialog-key st k)
      (st 'eye = 'kneel) (elem k rise-keys ? (rise! st) st)
      (st 'eye != 'walk) st
      (k = 32) (altar-near? st ? (move! st (kneel-move st)) st)
      (k @ (104 || -1) (pin st 'th (wrap (th - turn-v * dt)))
           (108 || -2) (pin st 'th (wrap (th + turn-v * dt)))
           (107 || -8) (step (walk-v * dt))
           (106 || -9) (step (0.0 - walk-v * dt))
           117 (pin st 'ph (min2 1.45 (st 'ph + tilt-v * dt)))
           110 (pin st 'ph (max2 -1.2 (st 'ph - tilt-v * dt)))
           st)))
 ; a frame's motion: the clock at its own pace; the eye on a move of its own, or easing to
 ; the ground's height; and done once out on the plain
 (stones-move st) (: g (stones-ground (st 'px) (st 'pz)) y (st 'py) mt (peep st 'mt 0.0 + peep st 'dt (1.0 / fps))
   dt (peep st 'dt (1.0 / fps))
   _ (pins st 'sim (st 'sim + 1.0 / fps) 'mt mt)
   _ (drops! st dt)
   (? (st 'eye = 'move) (: mv (st 'mv) t (mt - st 'm0) p (move-at mv t) end (mv 'len <= t)
                           ; ..the drops the move lets fall since the last frame
                           _ (each (peep mv 'ev ()) (e \ (t - dt < e 0 && e 0 <= t ? (spawn! st (e 1)))))
                           (pins st 'px (p 0) 'py (p 1) 'pz (p 2) 'th (wrap (p 3)) 'ph (p 4) 'ro (p 5)
                                    'eye (end ? (mv 'then) 'move)
                                    'dlg-at (end && peep mv 'dlg 0 ? (mt + dlg-pause) (st 'dlg-at))))
      ; ..the choices back, once the pause after a move is up
      (st 'eye = 'kneel && gem? (st 'dlg-at) && st 'dlg-at <= mt) (pins st 'dlg (st 'sel) 'dlg-at ())
      (st 'eye = 'walk)
       (pins st 'py (g + eye-h - y @ dy (mag dy < 0.002 ? (g + eye-h) (y + 0.35 * dy))) 'ro 0.0
                'done (st 'pz < exit-z ? 1 0))
      st))
 ; --- the eye's moves: each channel of the head -- x y z where it is, th ph where it looks,
 ; ro its tilt to the right -- a list of keys [t v], seconds into the move, passed through
 ; smoothly and never past a key, easing from rest at the first and to rest at the last. 'walk [x0 z0 x1 z1] is
 ; the ground it covers on foot, which puts the steps in; 'len how long it is, and 'then
 ; what the eye does after, 'walk or 'kneel. a move starts where the eye is ---
 (curve ks t)
  (: n #ks (ti i) (ks i 0) (vi i) (ks i 1)
     ; ..a key's slope: none at the ends or where the way turns back; else the way through
     ; it, held to three times the gentler side's, so the curve stays between its keys
     (slope i) (: a ((vi i - vi (i - 1)) / (ti i - ti (i - 1))) b ((vi (i + 1) - vi i) / (ti (i + 1) - ti i))
                  m ((vi (i + 1) - vi (i - 1)) / (ti (i + 1) - ti (i - 1))) lim (3.0 * min2 (mag a) (mag b))
                  (a * b <= 0.0 ? 0.0 (clamp m (0.0 - lim) lim)))
     (slope0 i) (i = 0 || i = n - 1 ? 0.0 (slope i))
     (seg i) (i + 2 < n && ti (i + 1) <= t ? (seg (i + 1)) i)
     (? (n = 1 || t <= ti 0) (vi 0) (ti (n - 1) <= t) (vi (n - 1))
        (: i (seg 0) h (ti (i + 1) - ti i) s ((t - ti i) / h) s2 (s * s) s3 (s2 * s)
           (vi i * (2.0 * s3 - 3.0 * s2 + 1.0) + slope0 i * h * (s3 - 2.0 * s2 + s)
            + vi (i + 1) * (3.0 * s2 - 2.0 * s3) + slope0 (i + 1) * h * (s3 - s2)))))
 ; ..the head at t into the move: on foot, a dip at each step and a sway from foot to foot,
 ; the steps a whole number, so the last ends where the walk does
 (move-at mv t) (: (ch k) (curve (mv k) t) x (ch 'x) z (ch 'z) w (mv 'walk)
   (far a b) (sqrt (sq (a - w 0) + sq (b - w 1)))
   sl (two? w ? (far (w 2) (w 3) @ L (L / max2 1.0 (floor (L / stride + 0.5)))) 1.0)
   q (two? w ? (pi * far x z / sl) 0.0)
   [x (ch 'y - 0.022 * sq (sin q)) z (ch 'th) (ch 'ph) (ch 'ro + 0.012 * sin q)])
 ; ..and under every move, the breath: the eye rising and nodding a little, slowly
 (breath t) [(0.005 * sin (t * 1.55)) (0.004 * sin (t * 1.55 - 0.8))]
 (move! st mv) (pins st 'eye 'move 'mv mv 'm0 (peep st 'mt 0.0))
 ; the altar: near enough to kneel at, and in sight
 (altar-near? st) (: al <(st 'blocks) dx (st 'px - al 0) dz (st 'pz - al 2)
   gap (sqrt (sq (max 0.0 (mag dx - al 4)) + sq (max 0.0 (mag dz - al 6))))
   (gap < reach && mag (wrap (atan2 (0.0 - dx) (0.0 - dz) - st 'th)) < 1.0))
 ; ..and kneeling there: the head turns to it first and keeps it in sight; a slow walk to
 ; its near long side; one knee down, the head tipping with it, then the other, a little
 ; past and back; the gaze settling on its top
 (kneel-move st) (: al <(st 'blocks) ax (al 0) az (al 2) top (al 1 + al 5)
   x0 (st 'px) z0 (st 'pz) y0 (st 'py) th0 (st 'th) ph0 (st 'ph)
   sg (z0 < az ? -1.0 1.0) kx (ax + clamp (x0 - ax) -0.4 0.4) kz (az + sg * (al 6 + 0.85))
   yk (stones-ground kx kz + kneel-h)
   d (sqrt (sq (kx - x0) + sq (kz - z0))) tw (max2 0.6 (d / slow-v)) T (0.25 + tw)
   ; ..its bearing from a place, unwound to lie near th0
   (look x z) (th0 + wrap (atan2 (ax - x) (az - z) - th0))
   (on f) [(x0 + f * (kx - x0)) (z0 + f * (kz - z0))]
   (lk f) (on f @ p (look (p 0) (p 1)))
   {'x [[0.0 x0] [0.25 x0] [T kx]] 'z [[0.0 z0] [0.25 z0] [T kz]]
    'th [[0.0 th0] [0.55 (lk 0.0)] [(0.25 + 0.5 * tw) (lk 0.5)] [T (lk 1.0)]]
    'ph [[0.0 ph0] [0.6 -0.12] [T -0.3] [(T + 0.9) -0.55] [(T + 1.9) -0.45]]
    'y [[0.0 y0] [T y0] [(T + 0.45) (yk + 0.3)] [(T + 0.65) (yk + 0.28)] [(T + 1.05) (yk - 0.03)]
        [(T + 1.4) (yk + 0.008)] [(T + 1.8) yk]]
    'ro [[0.0 0.0] [T 0.0] [(T + 0.45) 0.06] [(T + 0.7) 0.05] [(T + 1.1) -0.025] [(T + 1.6) 0.0]]
    'walk [x0 z0 kx kz] 'len (T + 2.0) 'then 'kneel 'dlg 1})
 ; --- the choices: a number takes one, k and j or the arrows go up and down them, enter
 ; takes the one marked, and space puts them away and stands. the last, wait, puts them
 ; away and stays kneeling, and is remembered; another, its move, and the choices again
 ; after it ---
 (dialog-key st k) (: n #acts c (st 'dlg)
   (? (49 <= k && k < 49 + n) (choose! st (k - 49))
      (elem k [107 -8]) (pin st 'dlg ((c + n - 1) % n))
      (elem k [106 -9]) (pin st 'dlg ((c + 1) % n))
      (elem k [13 10]) (choose! st c)
      (k = 32) (rise! st)
      st))
 (choose! st i) (: _ (pins st 'dlg () 'sel i)
   (i = #acts - 1 ? (pins st 'waited 1 'wait-at (st 'mt)) (move! st (act-move st i))))
 (rise! st) (: _ (pins st 'dlg () 'dlg-at () 'wait-at ()) (move! st (stand-move st)))
 ; ..an act's keys laid on the eye where it kneels
 (act-move st i) (: a (act-keys i) x0 (st 'px) z0 (st 'pz) th (st 'th)
   (off v l) (map (q \ [(q 0) (v + q 1)]) l)
   {'x (map (q \ [(q 0) (x0 + q 1 * sin th)]) (a 'fw)) 'z (map (q \ [(q 0) (z0 + q 1 * cos th)]) (a 'fw))
    'y (off (st 'py) (a 'y)) 'th [[0.0 th]] 'ph (off (st 'ph) (a 'ph)) 'ro (off (st 'ro) (a 'ro))
    'walk () 'len (a 'len) 'then 'kneel 'dlg 1 'ev (a 'ev)})
 ; --- drops: a tear from under the eye, falling; blood flung from the face, out over the
 ; altar. each falls till it meets the altar's top or the ground, and lies there ---
 (spawn! st kind) (: n (peep st 'nd 0) (j k) (sin ((n * 7 + k) * 12.9898) * 43758.5453 @ q (q - floor q))
   th (st 'th) f [(sin th) 0.0 (cos th)] sd [(cos th) 0.0 (0.0 - sin th)] e [(st 'px) (st 'py) (st 'pz)]
   tear (kind = 'tear)
   ; ..a tear from under the eye; blood from the hand, held out over what is below it
   hp (c+ (c+ e (c* 0.72 f)) (c* (0.08 + 0.04 * j 1) sd))
   p (tear ? (c+ (c+ e (c* 0.12 f)) (c+ [0.0 -0.08 0.0] (c* (0.06 * (j 1 - 0.5)) sd)))
        [(hp 0) (land-y st (hp 0) (hp 2) + 0.22) (hp 2)])
   v (tear ? (c+ [0.0 -0.1 0.0] (c* (0.3 + 0.1 * j 2) f)) [0.0 -0.2 0.0])
   (pins st 'nd (n + 1)
            'drops ({'p p 'v v 'c (tear ? [0.6 0.85 1.7] [1.1 0.06 0.05]) 'r (tear ? 0.008 0.009) 'k kind} . peep st 'drops ())))
 ; ..where a drop at x z comes to rest
 (land-y st x z) (: al <(st 'blocks)
   (mag (x - al 0) < 0.9 * al 4 && mag (z - al 2) < 0.9 * al 6 ? (al 1 + al 5) (stones-ground x z)))
 ; ..a tear soaks into the sand, darkening it, and dries from its edge in a few seconds;
 ; blood stays bright where it lands
 wet [0.42 0.27 0.16]
 tear-dry 1.5 tear-gone 5.0
 (drops! st dt) (: ds (peep st 'drops ()) mt (peep st 'mt 0.0)
   moved (map (d \ (: v (c+ (d 'v) [0.0 (-9.8 * dt) 0.0]) p (c+ (d 'p) (c* dt v)) h (land-y st (p 0) (p 2))
                      (p 1 <= h ? {'splat 1 'p [(p 0) (h + 0.012) (p 2)] 'c (d 'k = 'tear ? wet (d 'c)) 'r ((d 'k = 'tear ? 4.5 6.0) * d 'r)
                                   'k (d 'k) 'born mt}
                         {'p p 'v v 'c (d 'c) 'r (d 'r) 'k (d 'k)}))) ds)
   kept (filter (d \ d 'k != 'tear || mt - d 'born < tear-gone) (peep st 'splats ()))
   (pins st 'drops (filter (d \ !(peep d 'splat 0)) moved)
            'splats (take 80 (cat (filter (d \ peep d 'splat 0) moved) kept))))
 ; ..as triangles for the frame: a falling drop a small diamond, a fallen one a ragged
 ; patch, both seen from either side, lit by the hour; () for none
 (drop-batch st lt) (: L (c+ (lt 'amb) (c* (0.7 * lt 'sunk) (lt 'sunc))) ds (peep st 'drops ()) sp (peep st 'splats ())
   (vx p c) [(p 0) (p 1) (p 2) 0.0 0.0 (L 0 * c 0) (L 1 * c 1) (L 2 * c 2) 0.0 0.0 0.0]
   (flat l) (foldr cat () l)
   (both n l) (flat (map (t \ [[(n + t 0) (n + t 1) (n + t 2) -1] [(n + t 0) (n + t 2) (n + t 1) -1]]) l))
   (gem d n) (: p (d 'p) r (d 'r) c (d 'c)
     [(map (o \ vx (c+ p o) c) [[r 0.0 0.0] [(0.0 - r) 0.0 0.0] [0.0 (1.8 * r) 0.0] [0.0 (-1.8 * r) 0.0] [0.0 0.0 r] [0.0 0.0 (0.0 - r)]])
      (both n [[0 2 4] [4 2 1] [1 2 5] [5 2 0] [4 3 0] [1 3 4] [5 3 1] [0 3 5]])])
   mt (peep st 'mt 0.0)
   (patch d n) (: p (d 'p) c (d 'c)
     r (d 'k = 'tear ? (d 'r * (1.0 - sat ((mt - d 'born - tear-dry) / (tear-gone - tear-dry)))) (d 'r))
     [(cat [(vx p c)] (map (k \ (: a (k * pi / 3.0) q (r * (0.7 + 0.3 * sin (p 0 * 91.0 + k * 2.3)))
                               (vx (c+ p [(q * cos a) 0.0 (q * sin a)]) c))) ^6))
      (both n (map (k \ [0 (1 + k) (1 + (k + 1) % 6)]) ^6))])
   parts (foldl (\ acc d (: n (acc 2) g (peep d 'splat 0 ? (patch d n) (gem d n))
                            [(cat (acc 0) (g 0)) (cat (acc 1) (g 1)) (n + #(g 0))])) [() () 0] (cat ds sp))
   (parts 2 = 0 ? () [(gem-tray [(11 * parts 2)] (flat (parts 0))) (star-tray [(4 * #(parts 1))] (flat (parts 1)))]))
 ; --- the end of it: once the eye has waited at the altar, a lamppost stands far out on
 ; the plain past the mouth, beyond where the walk ends, its lantern lit at night ---
 (box-parts c h col n) (: (p sx sy sz) [(c 0 + sx * h 0) (c 1 + sy * h 1) (c 2 + sz * h 2) 0.0 0.0 (col 0) (col 1) (col 2) 0.0 0.0 0.0]
   [[(p -1 -1 -1) (p 1 -1 -1) (p 1 1 -1) (p -1 1 -1) (p -1 -1 1) (p 1 -1 1) (p 1 1 1) (p -1 1 1)]
    (foldr cat () (map (t \ [[(n + t 0) (n + t 1) (n + t 2) -1] [(n + t 0) (n + t 2) (n + t 1) -1]])
                       [[0 1 2] [0 2 3] [4 6 5] [4 7 6] [0 4 5] [0 5 1] [3 2 6] [3 6 7] [0 3 7] [0 7 4] [1 5 6] [1 6 2]]))])
 (post-batch st lt) (? (peep st 'waited 0)
   (: L (c+ (lt 'amb) (c* (0.7 * lt 'sunk) (lt 'sunc))) iron (c* 0.07 L) g (stones-ground post-x post-z)
      lamp (lt 'day < 0.15 ? [2.6 1.9 0.9] (c* 0.32 L))
      (at y) [post-x (g + y) post-z]
      parts [[(at 0.3) [0.2 0.3 0.2] iron] [(at 2.6) [0.07 2.1 0.07] iron] [(at 4.45) [0.18 0.28 0.18] lamp]
             [(at 4.78) [0.26 0.06 0.26] iron] [(at 4.98) [0.05 0.14 0.05] iron]]
      bs (foldl (\ acc q (: b (box-parts (q 0) (q 1) (q 2) #(acc 0)) [(cat (acc 0) (b 0)) (cat (acc 1) (b 1))])) [() ()] parts)
      [(gem-tray [(11 * #(bs 0))] (foldr cat () (bs 0))) (star-tray [(4 * #(bs 1))] (foldr cat () (bs 1)))]))
 ; ..and at night, kneeling after the wait half an hour, the missing stone where it stood,
 ; faint and the purple of the dusk, coming slowly and breathing; gone at sunrise, or when
 ; the eye stands
 (ghost-on? st lt) (st 'eye = 'kneel && !(charm? (st 'dlg)) && gem? (peep st 'wait-at ()) && lt 'day < 0.1
                    && ghost-wait <= peep st 'mt 0.0 - st 'wait-at)
 (ghost-batch st lt) (? (ghost-on? st lt)
   (: g (peep kept 'ghost ())
      pk (tablet? g ? g (: a (ring-a 3) j (throw 3 1 31 100 / 100.0)
                           b (stone (ring-r * cos a) (zc + ring-r * sin a) (pi / 2.0 - a) (1.0 + 0.2 * j)
                                    (2.9 + 0.5 * throw 3 2 37 100 / 100.0) 0.7)
                           q (mesh-pack (block-mesh b)) (pin kept 'ghost q, q)))
      mt (st 'mt) f (sat ((mt - st 'wait-at - ghost-wait) / 12.0) * (0.8 + 0.2 * sin (mt * 0.9)))
      c (pk 'cols) n (pk 'n) z (c 0 * 0.0) k (f * (0.55 + 0.45 * c 6))
      cols [(c 0) (c 1) (c 2) (c 3) (c 4) (0.22 * k) (0.11 * k) (0.32 * k) z z z]
      i (iota n * 11) ts (pk 'tris)
      [(foldl (\ v m (pin v (i + m) (cols m))) (iota (11 * n) * 0.0) ^11)
       (pin ts (iota (#ts // 4) * 4 + 3) -2)]))
 ; ..and up again: a lean forward, the push up, a step back to stand, looking up
 (stand-move st) (: x0 (st 'px) z0 (st 'pz) y0 (st 'py) th (st 'th) ph0 (st 'ph)
   bx (x0 - 0.3 * sin th) bz (z0 - 0.3 * cos th) ys (stones-ground bx bz + eye-h)
   {'x [[0.0 x0] [0.5 x0] [1.4 bx]] 'z [[0.0 z0] [0.5 z0] [1.4 bz]] 'th [[0.0 th]]
    'ph [[0.0 ph0] [0.4 (ph0 - 0.15)] [1.1 -0.05] [1.7 0.05]]
    'y [[0.0 y0] [0.35 (y0 - 0.02)] [0.8 (y0 + 0.25)] [1.3 (ys + 0.015)] [1.7 ys]]
    'ro [[0.0 (st 'ro)] [0.5 -0.05] [1.0 0.02] [1.5 0.0]]
    'walk () 'len 1.8 'then 'walk})
 ; --- the walk, on view's loop; stones-run raises the stage. o's 'md 'kitty or 'cells, or
 ; () for what the terminal says of itself; its 'time a local hour of today in seconds, or ()
 ; for now ---
 (stones-walk o)
   (view-walk {'new (w \ h \ (: sd (clock 0) now0 ((cite 'court 'court-now) ()) l0 (int (now0 0)) t (o 'time)
                               now (t = () ? now0 ((cite 'court 'court-local) (86400 * (l0 // 86400) + t)))
                               k (o 'md @ 'kitty 1 'cells 0 (kitty-term? ()))
                               st (stones-size (pins (stones-new w h now sd) 'deep (elem (getenv "COLORTERM") ["truecolor" "24bit"]) 'kitty k)
                                               w (h // 2))
                               ; ..the land built and lit before the first frame, which the song's
                               ; pace would otherwise take for the frames' and run far ahead
                               (scene st, st)))
               'size stones-size 'frame stones-frame 'key stones-step
               ; ..the frame's own time, kept for the next frame's keys: a slow frame steps further
               'tick (st \ (clock 0 @ now (pins st 'dt (clamp ((now - peep st 'wall now) / 1000.0) 0.02 0.25) 'wall now),
                            stones-move st))
               'fps fps 'linger 800 'next ()
               ; ..to apartment's music box and its drone
               'song (hn \ ((hn ? ((cite 'apartment 'apartment-song-new) hn (wheel (clock 0)))) @ s
                              (s ? (_ \ ((cite 'apartment 'apartment-song-feed) s)))))})
 ; ..and kitty's picture taken down after, where it was put up
 (stones-run o) (view-run (_ \ stones-walk o), say out kitty-gone, flush out, 0)
 stones-usage "usage: love lore stones [--time HH:MM] [--kitty|--cells]   (h l turn, k j step, u n look, space kneels at the altar, and there 1 to 5 or k j and space choose; a walking key or space stands again; q or esc leaves, or walk back out of the canyon)"
 ; the words, as a tablet for stones-run, or () where one is wrong or said twice
 (stones-opts as)
  (: (num w) (0 < #w && all (c \ 48 <= c <= 57) (chars w) ? <(sound w))
     (hm w) (w @ (h + ":" + m) (: a (num h) b (num m) (charm? a && charm? b && a < 24 && b < 60 ? (3600 * a + 60 * b)))
                 _ ())
     o {}
     (once k v r) (v = () || o k != () ? () (pin o k v, go r))
     (go l) (? (atom? l) o
               (<l = "--kitty") (once 'md 'kitty >l)
               (<l = "--cells") (once 'md 'cells >l)
               (two? >l && <l = "--time") (once 'time (hm <>l) >>l)
               ())
     (go as))
 (stones-main as) (stones-opts as @ o
   (tablet? o ? (stones-run o) (say err ("stones: " + stones-usage + "\n"), flush err, 2)))
 _ ((cite 'lore 'lore-enlist) 'stones (udoor 'stones stones-main stones-usage 1 1)))
) ; module stones
