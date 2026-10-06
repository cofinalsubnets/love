; stones -- a slot canyon in sandstone, first person in half blocks. the player starts a
; little way in from its mouth, between walls a stride or two apart that open toward the
; sky, carved smooth by the floods that come down it in the rains. the canyon winds on
; north, and opens on a round bowl, its sloping sides stepped in rows like an
; amphitheatre's: in the middle a grey block like an altar, stained dark red on top, and
; round it an octagon of standing stones, the north-west one missing. a few more stones
; stand about the rows, an audience, somewhere new each run. turning back and walking out
; of the mouth ends it.
;
; every pixel casts its own ray. the rock is a field of distances -- the slot, the bowl
; and the plateau over both -- marched a few steps at a time, the rays still going gathered
; between; the stones and the altar are blocks, met exactly. the sun is sky's at this hour,
; and down in the slot most of the light is the sky's and the walls' own glow.
; stones-new, stones-step and stones-frame are pure, gated by test/host/stones.l; only
; stones-walk and stones-run tie the tty.
;
; run: love lore stones   h l or the arrows turn, k j step, u n look up and down;
;                         q or esc leaves, or walk back out of the canyon
(module (stones stones-run stones-walk stones-main stones-new stones-size stones-step stones-move stones-pace
         stones-frame stones-pens stones-field stones-ground stones-blocks slot-x
         fps eye-h zc floor-r row-w row-h rows rim-r exit-z lat)
(borrow 'rove)
(borrow 'view)                          ; the screen, the pens, the hash, the loop
(borrow 'vec)                           ; triples, and the noise
(borrow 'sky)                           ; the sun, its light, the sky's colour
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
 ; --- the march: the rays still going, a few steps at a time, then gathered again. a ray
 ; is done when the rock is nearer than a pixel's width there, or it is up over the
 ; plateau going up, or far; the last still going have met the rock if it is near. 'T
 ; where each met the rock, 1e9 for the sky, and 'E where those gone to the sky left ---
 march-k 4 march-n 24 tmax 500.0 ymax 25.5
 (march e dx dy dz n foc t0) (: ex (e 0) ey (e 1) ez (e 2) B {'T (dx * 0.0 + 1e9) 'E (dx * 0.0)}
   ; ..each step near the eye half again as far as the open air reaches, and back by as
   ; much as a step past the rock went in; where the air has been closing in since the
   ; last step, on to where it would close at that rate, but no more than six times as far
   (run j t tp dp ax ay az) (j < 1 ? t
     (field (ex + t * ax) (ey + t * ay) (ez + t * az) @ d
       (: sec ((0.0 < d) * (d < dp) * (1.0 < t))
          plain (d * (1.0 + 0.5 * (0.0 < d) * (t < 8.0)))
          ahead (min (6.0 * d) (max d (d * (t - tp) / max (dp - d) 1e-6)))
          (run (j - 1) (t + over plain sec ahead) t d ax ay az))))
   (go ph idx t0) (: ax (peep dx idx 0.0) ay (peep dy idx 0.0) az (peep dz idx 0.0)
     t (run (ph = 0 ? 2 march-k) t0 t0 (t0 * 0.0 + 1e9) ax ay az)
     Y (ey + t * ay) d (field (ex + t * ax) Y (ez + t * az))
     last (march-n <= ph + 1)
     ; ..met on the open side of the rock, where its slope says which way it faces
     eps (0.003 + 1.2 * t / foc)
     hit (over ((d < eps) * (-0.002 < d)) last (mag d < 0.5))
     gone ((1 - hit) * (0 < (tmax < t) + (ymax < Y) * (0.0 < ay) + last))
     _ (pins B 'T (pin (B 'T) (over -1 hit idx) t) 'E (pin (B 'E) (over -1 gone idx) t))
     on (iota (1 - hit - gone))
     (#on = 0 ? B (go (ph + 1) (peep idx on 0) (peep t on 0.0))))
   ; ..all of them from the edge of the open air round the eye, or further where t0 says
   ; the rock lies further
   (go 0 (iota n) (max (dx * 0.0 + max 0.0 (stones-field ex ey ez)) (tray? t0 ? t0 0.0))))
 ; where to start the rays of the camera cam, n of them: the places last frame's ended,
 ; seen from here, each ray from a little short of the nearest of them round its pixel, or
 ; from the eye where none fell near -- the eye moves a little a frame, so the rock lies
 ; about where it lay, however far apart its rays were cast. () before the first
 (reseen st cam n) (: sn (peep st 'seen ())
   (tablet? sn ?
     (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
        vx (sn 'X - e 0) vy (sn 'Y - e 1) vz (sn 'Z - e 2)
        zc (vx * f 0 + vy * f 1 + vz * f 2) zs (max zc 0.01)
        sx (floor (cam 'cx + foc * (vx * rt 0 + vy * rt 1 + vz * rt 2) / zs))
        sy (floor (cam 'cy - foc * (vx * uv 0 + vy * uv 1 + vz * uv 2) / zs))
        ok ((0.1 < zc) * (0 <= sx) * (sx < w) * (0 <= sy) * (sy < h))
        D (pin (iota n * 0.0) (over -1 ok (sy * w + sx)) (sqrt (vx * vx + vy * vy + vz * vz)))
        i (iota n) x (i % w) y (i // w)
        (nb a b) (peep D (min (max (y + b) 0) (h - 1) * w + min (max (x + a) 0) (w - 1)) 0.0)
        m (foldl (acc \ o \ min acc (nb (o 0) (o 1))) D [[-1 -1] [0 -1] [1 -1] [-1 0] [1 0] [-1 1] [0 1] [1 1]])
        (max (0.93 * m - 0.05) 0.0))
     ()))
 ; ..and toward the sun from where a ray met: how much of it gets past the rock, tried at
 ; a few places out along the way, soft at a shadow's edge by how near the rock passes for
 ; how far. the rock is thick, so the places can stand wide apart
 sun-ts [0.2 0.6 1.5 3.5 7.0 12.0 20.0 32.0]
 (shadow X Y Z s) (foldl (res \ t \ min res (8.0 * field (X + t * s 0) (Y + t * s 1) (Z + t * s 2) / t))
                         (X * 0.0 + 1.0) sun-ts @ r (sat r))
 ; --- the blocks met: each tried only on the pixels of its box on the screen ---
 ; the block's eight corners
 (corners b) (: c (cos (b 3)) sn (sin (b 3))
   (map (k \ (: u ((k % 2 * 2 - 1) * b 4) v ((k // 2 % 2 * 2 - 1) * b 5) w ((k // 4 * 2 - 1) * b 6)
               [(b 0 + u * c + w * sn) (b 1 + v) (b 2 - u * sn + w * c)]))
        ^8))
 ; the pixels of the screen's box round the points qs, or all of them when one is behind
 (spot qs cam) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc) cx (cam 'cx) cy (cam 'cy)
   vs (map (q \ c+ q (c* -1.0 e)) qs) zs (map (v \ dot v f) vs)
   (? (all (z \ z < 0.1) zs) ()
      (any (z \ z < 0.1) zs) (iota (w * h))
      (: xs (map (i \ cx + foc * dot (vs i) rt / zs i) ^8) ys (map (i \ cy - foc * dot (vs i) uv / zs i) ^8)
         x0 (max2 0 (flo (foldl min2 1e9 xs) - 1)) x1 (min2 (w - 1) (flo (foldl max2 -1e9 xs) + 1))
         y0 (max2 0 (flo (foldl min2 1e9 ys) - 1)) y1 (min2 (h - 1) (flo (foldl max2 -1e9 ys) + 1))
         bw (x1 - x0 + 1) bh (y1 - y0 + 1)
         (bw < 1 || bh < 1 ? () (iota (bw * bh) @ ii ((y0 + ii // bw) * w + x0 + ii % bw))))))
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
 ; the stuff of a block at its own u v w, the normal's v part nv: the altar's grey, and
 ; on its top the stain, darkest where it pooled; a stone weathered, lichen on the tops
 (block-stuff b u v w nv k) (: g (0.82 + 0.3 * vn (u * 3.0 + v * 0.7 + k * 7.0) (w * 3.0 + v * 2.3) 71)
   (b 7 = 0 ?
      (: up (0.5 < nv) m (0.7 * vn (u * 2.6 + 3.0) (w * 3.4 + 5.0) 73 + 0.75 - sq (u / 1.15) - sq (w / 0.55))
         stain (up * sat ((m - 0.45) * 8.0)) core (up * sat ((m - 0.8) * 6.0))
         (cmix (cmix (c* g [0.46 0.46 0.45]) [0.27 0.035 0.03] stain) [0.15 0.02 0.02] core))
      (: lich (sat ((vn (u * 5.0 + k) (v * 5.0 + w * 3.0) 79 - 0.62) * 5.0) * (0.3 + 0.7 * (0.5 < nv)))
         (cmix (c* g [0.5 0.48 0.44]) [0.62 0.63 0.46] (0.7 * lich)))))
 ; ..and laid into the buffers where nearer
 (blocks! bs cam buf) (: e (cam 'e)
   (one k b) (spot (corners b) cam @ idx
     (#idx = 0 ? ()
      (: ax (peep (cam 'dx) idx 0.0) ay (peep (cam 'dy) idx 0.0) az (peep (cam 'dz) idx 0.0)
         r (slab b (e 0) (e 1) (e 2) ax ay az) tn (r 0)
         near (tn < peep (buf 't) idx 1e9) ks (iota near)
         (#ks = 0 ? ()
          (: ix (peep idx ks 0) (g v) (peep v ks 0.0)
             al (block-stuff b (g (r 4)) (g (r 5)) (g (r 6)) (g (r 2)) k)
             (put key v) (pin buf key (pin (buf key) ix v))
             (put 't (g tn), put 'nx (g (r 1)), put 'ny (g (r 2)), put 'nz (g (r 3)),
              put 'ar (al 0), put 'ag (al 1), put 'ab (al 2), put 'k (g tn * 0.0 + 1.0)))))))
   (each ^#bs (k \ one k (bs k))))
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
 ; --- the frame ---
 ; the sun and its light at the scene's hour, under its weather
 (stones-sun st) (sky-sun (st 'sim) (st 'dst) lat)
 (stones-light st) (sky-light (stones-sun st) (st 'wx) (st 'sim))
 ; --- the rock's colour kept: the stuff of a place and what the sun and the sky lay on
 ; it, kept in a cell of the world about two pixels across where it is seen, so a frame
 ; colours only the places it has not seen lately. a cell keeps its colour and when it was
 ; lit; it is lit again a minute and a half to two and a half of the sky's time on, cells
 ; apart, so the sun's going on is caught a little at a time. the cells hash into light-n
 ; slots, each with its own key ---
 light-n 262144
 (light-new _) (: z (iota light-n * 0.0)
   {'key (iota light-n * 0 - 1) 'r z 'g z 'b z 'at z})
 ; what the rays meet: the sky's mask and three trays of colour where it is not
 (surface st lt cam n) (: e (cam 'e) dx (cam 'dx) dy (cam 'dy) dz (cam 'dz) z0 (dx * 0.0)
   mt (march e dx dy dz n (cam 'foc) (reseen st cam n))
   buf {'t (mt 'T) 'nx z0 'ny z0 'nz z0 'ar z0 'ag z0 'ab z0 'k z0}
   _ (blocks! (st 'blocks) cam buf)
   T (buf 't) sky (1e9 <= T) G (iota (1 - sky))
   (only ix v) (peep v ix 0.0)
   t (only G T) X (e 0 + t * only G dx) Y (e 1 + t * only G dy) Z (e 2 + t * only G dz)
   kb (only G (buf 'k))
   ; ..and where each ray ended, the rock or the edge of the sky, for the next frame to start from
   E (over (mt 'E) (T < 1e9) T) ends (iota (0.0 < E)) te (peep E ends 0.0)
   _ (pin st 'seen {'X (e 0 + te * peep dx ends 0.0) 'Y (e 1 + te * peep dy ends 0.0) 'Z (e 2 + te * peep dz ends 0.0)})
   ; ..each place's cell: its size a power of two over a centimetre, near two pixels' width there
   L (min (max (floor (log (2.0 * t / cam 'foc / 0.01) / log 2.0)) 0) 12)
   sz (0.01 * exp (L * log 2.0))
   ix (floor (X / sz)) iy (floor (Y / sz)) iz (floor (Z / sz))
   slot (throw (ix + 7919 * iz) iy L light-n) key (throw ix (iy + 31 * iz) (L + 17) 1073741824)
   lc (st 'light) sim (st 'sim)
   fresh ((peep (lc 'key) slot -1 = key) * (sim - peep (lc 'at) slot -1e9 < 90.0 + 60.0 * (slot % 97) / 97.0))
   mi (iota (1 - fresh))
   ; ..read before any are laid, for one laid now may take a slot another reads; and those
   ; lit afresh take their own colour
   kept (map (k \ peep (lc k) slot 0.0) ['r 'g 'b])
   lit (#mi = 0 ? () (lay-light st lt (peep slot mi 0) (peep key mi 0) (only mi X) (only mi Y) (only mi Z)
                                 (only mi kb) (only mi t) (map (k \ only mi (only G (buf k))) ['nx 'ny 'nz 'ar 'ag 'ab])))
   (sky . map (i \ pin z0 G (two? lit ? (pin (kept i) mi (lit i)) (kept i))) ^3))
 ; ..the colour laid on places X Y Z, t from the eye, into their slots under their keys:
 ; the rock's normal across the field, a block's (kb) its face's, and its stuff -- B the
 ; block's normal and stuff, six trays; the sun where it faces, past the rock and the
 ; blocks; the sky's light by how much of it is seen and how near the rock crowds the
 ; place; and the glow the sunlit walls throw down the slot
 (lay-light st lt slot key X Y Z kb t B) (: h 0.02 lc (st 'light) bnx (B 0) bny (B 1) bnz (B 2)
   d0 (field X Y Z)
   gx (field (X + h) Y Z - d0) gy (field X (Y + h) Z - d0) gz (field X Y (Z + h) - d0)
   gl (sqrt (max (gx * gx + gy * gy + gz * gz) 1e-12))
   nx (over (gx / gl) kb bnx) ny (over (gy / gl) kb bny) nz (over (gz / gl) kb bnz)
   s (lt 'sun) nd (max 0.0 (nx * s 0 + ny * s 1 + nz * s 2))
   ox (X + 0.05 * nx) oy (Y + 0.05 * ny) oz (Z + 0.05 * nz)
   lit (0.0 < lt 'sunk * s 1 ? (shadow ox oy oz s * block-shade (st 'blocks) ox oy oz s) (X * 0.0))
   dir (nd * lit * lt 'sunk)
   ; ..the field read as distances by its own slope there, for each part of it steps short
   ; its own way
   gn (max (gl / h) 0.2)
   sv (sat (field X (Y + 5.0) Z / (4.0 * gn)))
   ao (sat (0.45 + 0.55 * field (X + 0.4 * nx) (Y + 0.4 * ny) (Z + 0.4 * nz) / (0.4 * gn)))
   skl (ao * (0.18 + 0.82 * sv) * (0.75 + 0.25 * ny))
   glow (lt 'sunk * sat (s 1 * 3.0) * (1.0 - sv) * ao * (0.25 + 0.5 * sat (Y / 14.0)))
   irr (c+ (c+ (c* skl (lt 'amb)) (c* dir (lt 'sunc))) (c* glow [0.95 0.5 0.24]))
   alb (cmix (rock X Y Z ny t) [(B 3) (B 4) (B 5)] kb)
   c (cm alb irr)
   (put k v) (pin lc k (pin (lc k) slot v))
   (put 'key key, put 'r (c 0), put 'g (c 1), put 'b (c 2), put 'at (X * 0.0 + st 'sim), c))
 ; ..a grid's colours spread over the screen: the sky where the nearest ray found it, and
 ; the rock blended from the four rays round each pixel that met rock
 (spread g sc) (: M (g 'M) Q (g 'Q) A (g 'A) B (g 'B) sk (sc 0)
   (wt k a) (a * (1 - peep sk (Q k) 1))
   ws [(wt 0 ((1.0 - A) * (1.0 - B))) (wt 1 (A * (1.0 - B))) (wt 2 ((1.0 - A) * B)) (wt 3 (A * B))]
   tw (max (ws 0 + ws 1 + ws 2 + ws 3) 1e-6)
   ((peep sk M 0) . map (c \ (: v (sc (c + 1)) ((foldl (acc \ k \ acc + ws k * peep v (Q k) 0.0) 0.0 ^4) / tw))) ^3))
 ; the rays through U V, facing th and pitched ph, and a camera on them, its middle cx cy
 ; and its focal length foc
 (camera e th ph U V w h foc cx cy) (: sth (sin th) cth (cos th) sph (sin ph) cph (cos ph)
   dx0 (sth * cph + U * cth - V * sth * sph) dy0 (sph + V * cph) dz0 (cth * cph - U * sth - V * cth * sph)
   ln (sqrt (dx0 * dx0 + dy0 * dy0 + dz0 * dz0))
   {'e e 'f [(sth * cph) sph (cth * cph)] 'r [cth 0.0 (0.0 - sth)] 'u [(0.0 - sth * sph) cph (0.0 - cth * sph)]
    'w w 'h h 'foc foc 'cx cx 'cy cy
    'dx (over (dx0 / ln) (dx0 = 0.0) 1e-9) 'dy (over (dy0 / ln) (dy0 = 0.0) 1e-9) 'dz (over (dz0 / ln) (dz0 = 0.0) 1e-9)})
 ; every pixel's colour, three trays: what the rays meet lit, and the sky and its stars
 ; where they meet nothing, through the eye's gain. the rays are cast f pixels apart,
 ; spread over the pixels between, the sky every pixel; what they met is kept while the eye
 ; holds still and the sun has not gone on far. a frame that moved says what its rays cost,
 ; 'cost, in milliseconds, for the pace to weigh
 (stones-pens st) (: lt (stones-light st) th (st 'th) ph (st 'ph) w (st 'w) h (st 'h) n (w * h) f (st 'f)
   e [(st 'px) (st 'py) (st 'pz)]
   cam (camera e th ph (st 'U) (st 'V) w h (st 'foc) (w / 2.0) (h / 2.0))
   pose [e th ph n (int (st 'sim // 20.0))] was (peep st 'scene ())
   sc (two? was && was 0 = pose && was 1 = f ? (was 2)
         (: t0 (clock 0)
            v (f = 1.0 ? (surface st lt cam n)
                 (: g (grid st f)
                    (spread g (surface st lt (camera e th ph (g 'U) (g 'V) (g 'w) (g 'h) (st 'foc / f) (w / 2.0 / f) (h / 2.0 / f))
                                       (g 'w * g 'h)))))
            _ (two? was && was 0 = pose ? () (pin st 'cost (clock 0 - t0)))
            (pin st 'scene [pose f v], v)))
   sky (sc 0) S (iota sky) (only ix v) (peep v ix 0.0)
   hv (sky-colour-of lt (st 'wx) (only S (cam 'dx)) (only S (cam 'dy)) (only S (cam 'dz)) (e 0) (e 2) (st 'sim) (st 't) 0.0)
   col0 (map (k \ pin (sc (k + 1)) S (hv k)) ^3)
   col1 ((cite 'court 'stars!) col0 st lt cam sky (st 't))
   (sky-tone lt col1))
 (stones-frame st) (: w (st 'w) h (st 'h) c (stones-pens st)
   (st 'deep ? (view-deep-frame w h (view-deep-pens c) {})
      (view-cube-pens c (st 'bay) @ px (view-frame w h (y \ peep px (iota w + w * y) 0) {}))))
 ; --- the state: the screen as view lays it, where the player stands and looks ('th the
 ; bearing, 'ph the pitch, 'py the eye's height), the clock, the weather, the blocks. a run
 ; starts a little way in from the mouth, facing on up the slot ---
 ; the weather thrown: the desert's mostly clear
 (cover-of sd) (throw sd 3 89 20 @ k (? (k < 13) 0 (k < 17) 1 (k < 19) 2 3))
 (stones-new w h now sd) (: st {'px (slot-x 0.0) 'pz 0.0 'py eye-h 'th 0.0 'ph 0.12 'sim (now 0) 'dst (now 1)
                                'wx (sky-weather (cover-of sd) 'smooth) 't 0 'deep 0 'done 0
                                'blocks (stones-blocks sd) 'light (light-new ())}
   (stones-size st w (h // 2)))
 ; the screen w cells by r rows, and each pixel's offsets from the middle, and its dither;
 ; the rays f pixels apart to start with, f the least quarter that keeps them to ray-n or
 ; so, and the pace takes it from there
 ray-n 4000
 (stones-size st w r) (: h (2 * r) n (w * h) i (iota n) x (i % w) y (i // w)
   f (min2 4.0 (max2 1.0 (int (4.0 * sqrt (n / (1.0 * ray-n)) + 0.999) / 4.0)))
   (pins (view! st w h (h // 2)) 'U ((x + 0.5 - w / 2.0) / (w / 2.0)) 'V ((h / 2.0 - y - 0.5) / (w / 2.0))
         'bay (view-bayer w h) 'f f 'grids {} 'scene ()))
 ; the grid of rays f pixels apart, kept by f: each ray's offsets, w by h of them, M each
 ; pixel's nearest, Q the four round it and A B how far it lies across and down between them
 (grid st f) (: gs (st 'grids) k (int (f * 4.0)) old (peep gs k ())
   (tablet? old ? old
      (: W (st 'w) H (st 'h) w (int (W / f + 0.999)) h (int (H / f + 0.999))
         i (iota (W * H)) x (i % W) y (i // W) j (iota (w * h)) x2 (j % w) y2 (j // w)
         gx ((x + 0.5) / f - 0.5) gy ((y + 0.5) / f - 0.5)
         x0 (min (max (floor gx) 0) (w - 1)) y0 (min (max (floor gy) 0) (h - 1))
         x1 (min (x0 + 1) (w - 1)) y1 (min (y0 + 1) (h - 1))
         g {'w w 'h h
            'U ((f * (x2 + 0.5) - W / 2.0) / (W / 2.0)) 'V ((H / 2.0 - f * (y2 + 0.5)) / (W / 2.0))
            'M (min (int ((y + 0.5) / f)) (h - 1) * w + min (int ((x + 0.5) / f)) (w - 1))
            'Q [(y0 * w + x0) (y0 * w + x1) (y1 * w + x0) (y1 * w + x1)]
            'A (sat (gx - x0)) 'B (sat (gy - y0))}
         (pin gs k g, g))))
 ; the pace: the rays further apart a quarter pixel at a time while a moving frame's rays
 ; cost more than pace-ms, closer while they cost well under it -- a step a few frames
 ; apart, so the picture never jumps; and the frame just after a step, laying a new grid,
 ; is not weighed
 pace-ms 40
 (stones-pace st) (: c (peep st 'cost 0) f (st 'f) since (peep st 'paced 0)
   up (? (since < 2) 0 (2.0 * pace-ms < c) 1 (1.2 * pace-ms < c && 6 <= since) 1 0)
   dn ((1 - up) * (c < 0.65 * pace-ms && 20 <= since && 1.0 < f))
   f2 (min2 4.0 (max2 1.0 (f + 0.25 * up - 0.25 * dn)))
   (f2 = f ? (pin st 'paced (since + 1)) (pins st 'f f2 'paced 0 'cost 0)))
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
 ; --- the walk, on view's loop; stones-run raises the stage ---
 (stones-walk _)
   (view-walk {'new (w \ h \ (: sd (clock 0) now ((cite 'court 'court-now) ())
                               (pin (stones-new w h now sd) 'deep (elem (getenv "COLORTERM") ["truecolor" "24bit"]))))
               'size stones-size 'frame stones-frame 'key stones-step
               ; ..the frame's own time, kept for the next frame's keys: a slow frame steps further
               'tick (st \ (clock 0 @ now (pins st 'dt (clamp ((now - peep st 'wall now) / 1000.0) 0.02 0.25) 'wall now),
                            stones-move st, stones-pace st))
               'fps fps 'song (hn \ ()) 'linger 800 'next ()})
 (stones-run _) (view-run stones-walk)
 stones-usage "usage: love lore stones   (h l turn, k j step, u n look; q or esc leaves, or walk back out of the canyon)"
 (stones-main as) (as @ () (stones-run ())
                       (say err ("stones: " + stones-usage + "\n"), flush err, 2))
 _ ((cite 'lore 'lore-enlist) 'stones (udoor 'stones stones-main stones-usage 1 1)))
) ; module stones
