; stones -- a slot canyon in sandstone, first person in half blocks. the player starts a
; little way in from its mouth, between walls a stride or two apart that open toward the
; sky, carved smooth by the floods that come down it in the rains. the canyon winds on
; north, and opens on a round bowl, its sloping sides stepped in rows like an
; amphitheatre's: in the middle a grey block like an altar, stained dark red on top, and
; round it an octagon of standing stones, the north-west one missing. a few more stones
; stand about the rows, an audience, somewhere new each run. turning back and walking out
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
;      h l or the arrows turn, k j step, u n look up and down; q or esc leaves, or walk
;      back out of the canyon
(module (stones stones-run stones-walk stones-main stones-new stones-size stones-step stones-move
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
 ; --- the land, in metres: x east, z north, y up. the slot runs north from its mouth
 ; through the plateau to the bowl, whose middle is at x 0, z zc: a flat floor floor-r
 ; across, then rows rising row-h every row-w out to rim-r, and the bowl's wall over them
 ; to the plateau's top ---
 zc 120.0 floor-r 14.0 row-w 2.4 row-h 1.5 rows 7
 rim-r (floor-r + rows * row-w)
 exit-z -34.0                           ; out on the open sand: the run done
 ; the slot's line, winding, and straight where it meets the bowl
 (slot-x z) (sat ((zc - 30.0 - z) / 25.0) * (1.9 * sin (z / 11.0) + 0.9 * sin (z / 5.3)))
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
 altar [0.0 0.45 zc 0.0 1.1 0.45 0.5 0]
 (stone x z yaw w ht th) [x (stones-ground x z + 0.5 * ht - 0.15) z yaw (0.5 * w) (0.5 * ht) (0.5 * th) 1]
 ; the ring: eight places a turn round, east first and on through north; the fourth, the
 ; north-west, is empty
 ring (filter two? (map (k \ (k = 3 ? ()
                             (: a (k * pi / 4.0) j (throw k 1 31 100 / 100.0)
                                (stone (ring-r * cos a) (zc + ring-r * sin a) (pi / 2.0 - a)
                                       (1.0 + 0.2 * j) (2.9 + 0.5 * throw k 2 37 100 / 100.0) 0.55))))
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
                               (0.4 + 0.2 * throw sd k 67 100 / 100.0)) . got)))))
   (try 0 ()))
 (stones-blocks sd) (altar . cat ring (audience sd))
 ; ..and toward the sun from where a ray met: how much of it gets past the rock, tried at
 ; a few places out along the way, soft at a shadow's edge by how near the rock passes for
 ; how far. the rock is thick, so the places can stand wide apart
 sun-ts [0.2 0.6 1.5 3.5 7.0 12.0 20.0 32.0]
 (shadow X Y Z s) (foldl (res \ t \ min res (8.0 * field (X + t * s 0) (Y + t * s 1) (Z + t * s 2) / t))
                         (X * 0.0 + 1.0) sun-ts @ r (sat r))
 ; a ray against a block: [tn nx ny nz u v w] -- where it enters, the face's normal, and the
 ; place on the block, each part a tray; tn 1e9 where it misses
 (slab b ox oy oz ax ay az) (: c (cos (b 3)) sn (sin (b 3))
   ; ..into the block's own frame: u across, v up, w through
   qx (ox - b 0) qy (oy - b 1) qz (oz - b 2)
   lu (qx * c - qz * sn) lw (qx * sn + qz * c)
   du (ax * c - az * sn) dw (ax * sn + az * c)
   (sl o d hh) (: d2 (over d (mag d < 1e-9) 1e-9) t1 ((0.0 - hh - o) / d2) t2 ((hh - o) / d2) [(min t1 t2) (max t1 t2)])
   su (sl lu du (b 4)) sv (sl qy ay (b 5)) sw (sl lw dw (b 6))
   tn (max (su 0) (max (sv 0) (sw 0))) tf (min (su 1) (min (sv 1) (sw 1)))
   hit ((tn < tf) * (0.0 < tn))
   fu (tn = su 0) fv ((1 - fu) * (tn = sv 0)) fw (1 - fu - fv)
   nu (fu * over 1.0 (0.0 < du) -1.0) nv (fv * over 1.0 (0.0 < ay) -1.0) nw (fw * over 1.0 (0.0 < dw) -1.0)
   [(over 1e9 hit tn) (nu * c + nw * sn) nv (nw * c - nu * sn)
    (lu + tn * du) (qy + tn * ay) (lw + tn * dw)])
 ; ..and toward the sun: 0 where a block stands between, else 1 -- each block tried only
 ; on the places near enough to it to lie in its shadow
 (block-shade bs X Y Z s) (: reach (1.0 / max2 (s 1) 0.15)
   (foldl (L \ b \ (: ix (iota (sq (X - b 0) + sq (Z - b 2) < sq (b 4 + b 6 + 2.0 * b 5 * reach)))
                      (#ix = 0 ? L
                         (: (g v) (peep v ix 0.0) one (g X * 0.0 + 1.0)
                            (pin L ix (g L * (1e9 <= slab b (g X) (g Y) (g Z) (one * s 0) (one * s 1) (one * s 2) 0)))))))
          (X * 0.0 + 1.0) bs))
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
 dz 1.0 z0 -90.0                          ; the slot's rings, from out on the plain
 nw 8                                     ; rows up a wall
 lips [2.0 5.0 9.0]                       ; ..and out over the plateau, under its edge
 (rim-y x z) (min (top x z) (bowl x z))
 ; a slot wall, side sg -1 the west and 1 the east, its profile i up and over at ring j:
 ; the east's i and j crossed, so both face the slot. its foot is sunk under the floor
 (wall sg)
  (: nz (int ((zend - z0) / dz)) np (nw + #lips)
     (at i j) (: z (z0 + j * dz) sx (slot-x z) T (rim-y (sx + sg * half (top sx z) z) z)
                 (i <= nw ? (: y ((T + 0.3) * i / nw - 0.3) x (sx + sg * half (max y 0.0) z) [x y z (tx * z) (tx * y)])
                    (: x (sx + sg * (half T z + lips (i - nw - 1))) y (rim-y x z - 0.08)
                       [x y z (tx * z) (tx * (T + mag (x - sx)))])))
     m (sg < 0 ? (mesh-grid nz np (\ j i (at i j)) 0 [1.0 1.0 1.0])
          (mesh-grid np nz at 0 [1.0 1.0 1.0]))
     ; ..its lips only under the plateau, not where the bowl's rows are the ground
     (mesh-keep m (\ x y z (mag (x - slot-x z) < half (max y 0.0) z + 0.5 || top x z - 0.3 <= bowl x z))))
 ; ..its floor, sand from wall to wall, a hair under the bowl's where they meet, and a
 ; skirt on past each wall's foot: a wall's rows are straight, its curve between them
 ; not where the floor's edge is
 floor-n 3
 (slot-floor _) (: nz (int ((zend + 2.0 - z0) / dz))
   (mesh-grid (floor-n + 2) nz (\ i j (: z (z0 + j * dz) sx (slot-x z) hw (half 0.0 z)
                                         x (? (i = 0) (sx - hw - 0.5) (i = floor-n + 2) (sx + hw + 0.5)
                                              (sx - hw + 2.0 * hw * (i - 1) / floor-n))
                                         [x -0.02 z (tx * x) (tx * z)]))
              1 [1.0 1.0 1.0]))
 ; the slot's air: inside its walls, short of the bowl
 (in-slot? x y z) (z < zend && mag (x - slot-x z) < half (max y 0.0) z - 0.02)
 ; the bowl's rows as knots [rr y] out from the middle: a tread, then a riser eased up
 ; to the next; past the rim the wall to the plateau, and on under it
 knots (: (row k) (: r0 (floor-r + k * row-w) h (k * row-h)
                     [[(r0 + 0.5 * row-w) h] [(r0 + 0.65 * row-w) (h + 0.156 * row-h)]
                      [(r0 + 0.75 * row-w) (h + 0.5 * row-h)] [(r0 + 0.85 * row-w) (h + 0.844 * row-h)]
                      [(r0 + row-w) (h + row-h)]])
          ([[0.0 0.0] [6.0 0.0] [floor-r 0.0]] + foldr (+) () (map row ^rows)
           + map (d \ [(rim-r + d) (rows * row-h + 2.2 * d)]) [1.0 2.5 4.0 5.5 7.0 10.0 15.0]))
 bowl-n 72
 (bowl-mesh _)
  (: (at i j) (: a (2.0 * pi * i / bowl-n) kn (knots j) rr (kn 0)
                 ; ..each knot where the rows' wavering puts its radius
                 (go r k) (: x (r * sin a) z (zc + r * cos a)
                            (k = 0 ? [x z] (go (rr - 0.6 * sin (x / 4.0 + z / 6.0)) (k - 1))))
                 p (go rr 2) x (p 0) z (p 1)
                 y (min (kn 1) (top x z) - (rim-r + 5.0 < rr ? 0.08 0.0))
                 [x y z (tx * rr * a) (tx * (rr + y))])
     m (mesh-grid bowl-n (#knots - 1) at 1 [1.0 1.0 1.0])
     ; ..where the slot cuts the rows: a vertex in its air moved out across to the wall on
     ; its side, so a row ends on the wall; a triangle across the slot, its corners either
     ; side of it, or with all three moved into the wall, dropped
     (side v) (v 0 < slot-x (v 2) ? -1 1)
     (in? v) (in-slot? (v 0) (v 1 + 0.3) (v 2))
     S (star-tray [#(m 0)] (map side (m 0))) I (star-tray [#(m 0)] (map (v \ in? v ? 1 0) (m 0)))
     Z (gem-tray [#(m 0)] (map (v \ 1.0 * v 2) (m 0)))
     vs (map (v \ (in? v ? ([(slot-x (v 2) + side v * half (v 1) (v 2)) (v 1) (v 2)] + drop 3 v) v)) (m 0))
     ts (filter (t \ (: (g T k) (peep T (t k) 0) zl (min (g Z 0) (min (g Z 1) (g Z 2)))
                       across (g S 0 != g S 1 || g S 0 != g S 2)
                       !(across && zl < zend || g I 0 + g I 1 + g I 2 = 3)))
                (m 1))
     (mesh-normals (mesh vs ts)))
 ; the plateau, four metres a cell: where it is the top, not the bowl's air nor the slot's
 cell 4.0
 (plateau _) (: nx 40 nz 75 x0 (-0.5 * nx * cell) zp -110.0
   m (mesh-grid nx nz (\ i j (: x (x0 + i * cell) z (zp + j * cell) y (top x z) [x y z (tx * x) (tx * z)])) 1 [1.0 1.0 1.0])
   (mesh-keep m (\ x y z (sqrt (x * x + sq (z - zc)) > rim-r + 7.0
                          && (zend <= z || mag (x - slot-x z) > half (top x z) z + 8.0)))))
 ; the blocks as boxes, the altar's top stained: a decal over it, its holes the rock
 (block-mesh b) (: k (b 7) yaw (b 3)
   bx (mesh-box [(b 0) (b 1) (b 2)] [(b 4) (b 5) (b 6)] yaw (k = 0 ? 2 3) [1.0 1.0 1.0] tx)
   (k = 0 ? (mesh-join [bx (mesh-move (mesh-quad [[(0.0 - b 4) 0.0 (0.0 - b 6)] [(b 4) 0.0 (0.0 - b 6)] [(b 4) 0.0 (b 6)] [(0.0 - b 4) 0.0 (b 6)]]
                                                 [[0.0 0.0] [64.0 0.0] [64.0 32.0] [0.0 32.0]] 4 [1.0 1.0 1.0])
                                      [(b 0) (b 1 + b 5 + 0.006) (b 2)] yaw)])
      bx))
 ; the rock's own colour at each vertex, its fine lines left to the texture: over the
 ; texture's mean, which darkens it as much
 (rock-cols pk) (: c (pk 'cols) al (rock (c 0) (c 1) (c 2) (c 7) 60.0)
   (pins pk 'cols (take 8 c + map (k \ al k / 0.88) ^3)))
 ; --- the textures, 64 texels a side, four metres: the rock's beds, the sand's ripples, the
 ; altar's grey, a stone's grey and lichen, and the stain with holes where there is none ---
 (tex-of f) (mesh-tex 64 (\ x y (f (x / tx) (y / tx))))
 (grey g) [g g g]
 texs-of (_ \ [(tex-of (\ u v (grey (0.88 + 0.05 * sin (v * 9.0 + 2.0 * sin (u * 0.8)) + 0.05 * sin ((0.7 * v + u / 4.0) * 7.0)
                                      + 0.06 * (vn (u * 6.0) (v * 7.0) 89 - 0.5)))))
               (tex-of (\ u v (grey (0.86 + 0.06 * sin (u * 6.0 + v * 4.0 + 2.0 * sin (v * 1.1)) + 0.08 * (vn (u * 9.0) (v * 9.0) 97 - 0.5)))))
               (tex-of (\ u v (c* (0.82 + 0.3 * vn (u * 3.0) (v * 3.0) 71) [0.46 0.46 0.45])))
               (tex-of (\ u v (: g (0.82 + 0.3 * vn (u * 3.0) (v * 2.3) 71)
                                  lich (sat ((vn (u * 5.0) (v * 5.0) 79 - 0.62) * 5.0))
                                  (cmix (c* g [0.5 0.48 0.44]) [0.62 0.63 0.46] (0.7 * lich)))))
               (mesh-tex 64 (\ x y (: u (x / 64.0 * 2.2 - 1.1) w (y / 32.0 - 0.5)
                                      m (0.7 * vn (x / 64.0 * 5.7 + 3.0) (y / 32.0 * 3.4 + 5.0) 73 + 0.75 - sq (u / 1.15) - sq (w / 0.55))
                                      (32.0 <= y || m < 0.45 ? ()
                                         (cmix [0.27 0.035 0.03] [0.15 0.02 0.02] (sat ((m - 0.8) * 6.0)))))))])
 ; the land, kept for every run in the process: the rock packed, its colours its own;
 ; the textures
 kept {}
 (land _) (: l (peep kept 'land ())
   (tablet? l ? l
      (: rk (rock-cols (mesh-pack (mesh-join [(wall -1) (wall 1) (slot-floor ()) (bowl-mesh ()) (plateau ())])))
         l2 {'rock rk 'texs (texs-of ())}
         (pin kept 'land l2, l2))))
 ; --- the light baked: each vertex's share of the sun past the rock and the blocks, of the
 ; sky by how much of it is open overhead and how near the rock crowds it, and the glow
 ; the sunlit walls throw down the slot. again once the sun has gone on two minutes ---
 (light-of st lt) (: s (lt 'sun) bs (st 'blocks)
   (c \ (: X (c 0) Y (c 1) Z (c 2) nx (c 5) ny (c 6) nz (c 7) h 0.02
           ox (X + 0.05 * nx) oy (Y + 0.05 * ny) oz (Z + 0.05 * nz)
           sun (0.0 < lt 'sunk * s 1 ? (shadow ox oy oz s * block-shade bs ox oy oz s) (X * 0.0))
           d0 (field X Y Z)
           gn (max (sqrt (sq (field (X + h) Y Z - d0) + sq (field X (Y + h) Z - d0) + sq (field X Y (Z + h) - d0)) / h) 0.2)
           sv (sat (field X (Y + 5.0) Z / (4.0 * gn)))
           ao (sat (0.45 + 0.55 * field (X + 0.4 * nx) (Y + 0.4 * ny) (Z + 0.4 * nz) / (0.4 * gn)))
           g (lt 'sunk * sat (s 1 * 3.0) * (1.0 - sv) * ao * (0.25 + 0.5 * sat (Y / 14.0)))
           [sun (ao * (0.18 + 0.82 * sv) * (0.75 + 0.25 * ny)) [(0.95 * g) (0.5 * g) (0.24 * g)]])))
 (scene st) (: was (peep st 'scene ()) sim (st 'sim)
   (tablet? was && mag (sim - was 'at) < 120.0 ? (was 'sc)
      (: lt (stones-light st) L (land ()) lit (light-of st lt)
         rk (mesh-bake (L 'rock) lt lit 1.0) bl (mesh-bake (st 'bpk) lt lit 1.0)
         sc [[(rk 0) (bl 0)] [(rk 1) (bl 1)]]
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
 (stones-pens st) (: lt (stones-light st) k (peep st 'kp 1) w (k * st 'w) h (k * st 'h) e [(st 'px) (st 'py) (st 'pz)]
   v (mesh-view w h e (st 'th) (st 'ph) fov 0.05 900.0)
   hz (mesh-haze v lt (st 'wx) (st 'sim))
   (mesh-frame v (scene st) ((land ()) 'texs) [(hz 0) (hz 1) (hz 2) 150.0 900.0] 8 (1.5 * lt 'expo)
               (mesh-sky lt (st 'wx) e (st 'sim) (st 't) (k = 1 ? 1 (sky-k * k)))))
 (stones-frame st) (: w (st 'w) h (st 'h) k (peep st 'kp 1) f (stones-pens st)
   (? (st 'kitty) (: n (peep st 'kn 0) _ (pin st 'kn (1 - n))
                     (esc + "[?2026h" + mesh-kitty f (k * w) (k * h) w (h // 2) (kitty-id + n)
                      + kitty-del (kitty-id + 1 - n) + esc + "[?2026l"))
      (st 'deep) (mesh-cells f w h 1 0 {})
      (mesh-cells f w h 0 (st 'bay) {})))
 ; ..a terminal that shows kitty's pixels, by what it says of itself: mitty, kitty,
 ; ghostty, wezterm
 (kitty-term? _) (: (has e s) (has? (getenv e) s)
   (? (0 < #(getenv "MITTY")) 1 (has "TERM" "kitty") 1 (0 < #(getenv "KITTY_WINDOW_ID")) 1
      (has "TERM_PROGRAM" "ghostty") 1 (has "TERM_PROGRAM" "WezTerm") 1 0))
 ; --- the state: the screen as view lays it, where the player stands and looks ('th the
 ; bearing, 'ph the pitch, 'py the eye's height), the clock, the weather, the blocks. a run
 ; starts a little way in from the mouth, facing on up the slot ---
 ; the weather thrown: the desert's mostly clear
 (cover-of sd) (throw sd 3 89 20 @ k (? (k < 13) 0 (k < 17) 1 (k < 19) 2 3))
 (stones-new w h now sd) (: bs (stones-blocks sd)
   st {'px (slot-x 0.0) 'pz 0.0 'py eye-h 'th 0.0 'ph 0.12 'sim (now 0) 'dst (now 1)
       'wx (sky-weather (cover-of sd) 'smooth) 't 0 'deep 0 'kitty 0 'kp 1 'done 0
       'blocks bs 'bpk (mesh-pack (mesh-join (map block-mesh bs)))}
   (stones-size st w (h // 2)))
 ; the screen w cells by r rows, two pixels a row, and its dither; as kitty's, 'kp times
 ; as many pixels each way
 (stones-size st w r) (: h (2 * r)
   (pins (view! st w h (h // 2)) 'bay (view-bayer w h) 'kp (st 'kitty ? (max2 1 (kitty-w // w)) 1)))
 ; --- moving: over the sand and up the rows, but not up the rock, nor through a block;
 ; sliding along what stops a step. out past the mouth, the run is done ---
 (free? st x z) (: g (stones-ground x z) g0 (stones-ground (st 'px) (st 'pz))
   (g < g0 + 0.7 && g < rows * row-h + 0.3
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
      (k @ (104 || -1) (pin st 'th (wrap (th - turn-v * dt)))
           (108 || -2) (pin st 'th (wrap (th + turn-v * dt)))
           (107 || -8) (step (walk-v * dt))
           (106 || -9) (step (0.0 - walk-v * dt))
           117 (pin st 'ph (min2 1.45 (st 'ph + tilt-v * dt)))
           110 (pin st 'ph (max2 -1.2 (st 'ph - tilt-v * dt)))
           st)))
 ; a frame's motion: the clock at its own pace, the eye easing to the ground's height, and
 ; done once out on the plain
 (stones-move st) (: g (stones-ground (st 'px) (st 'pz)) y (st 'py)
   (pins st 'sim (st 'sim + 1.0 / fps) 'py (g + eye-h - y @ dy (mag dy < 0.002 ? (g + eye-h) (y + 0.35 * dy)))
            'done (st 'pz < exit-z ? 1 0)))
 ; --- the walk, on view's loop; stones-run raises the stage. o's 'md 'kitty or 'cells, or
 ; () for what the terminal says of itself; its 'time a local hour of today in seconds, or ()
 ; for now ---
 (stones-walk o)
   (view-walk {'new (w \ h \ (: sd (clock 0) now0 ((cite 'court 'court-now) ()) l0 (int (now0 0)) t (o 'time)
                               now (t = () ? now0 ((cite 'court 'court-local) (86400 * (l0 // 86400) + t)))
                               k (o 'md @ 'kitty 1 'cells 0 (kitty-term? ()))
                               (stones-size (pins (stones-new w h now sd) 'deep (elem (getenv "COLORTERM") ["truecolor" "24bit"]) 'kitty k)
                                            w (h // 2))))
               'size stones-size 'frame stones-frame 'key stones-step
               ; ..the frame's own time, kept for the next frame's keys: a slow frame steps further
               'tick (st \ (clock 0 @ now (pins st 'dt (clamp ((now - peep st 'wall now) / 1000.0) 0.02 0.25) 'wall now),
                            stones-move st))
               'fps fps 'song (hn \ ()) 'linger 800 'next ()})
 ; ..and kitty's picture taken down after, where it was put up
 (stones-run o) (view-run (_ \ stones-walk o), say out kitty-gone, flush out, 0)
 stones-usage "usage: love lore stones [--time HH:MM] [--kitty|--cells]   (h l turn, k j step, u n look; q or esc leaves, or walk back out of the canyon)"
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
