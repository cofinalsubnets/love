; corridor -- an indoor level played in first person, its rooms read from a level file
; and read again whenever the file changes, so a level is built by hand in an editor
; beside the running game. the first is the test corridor (src/apps/lore/levels/hall.l):
; a station hallway under light strips, one of them failing, a poster and a neon sign on
; its walls, and a sliding door at its end onto a room lit by one red bulb.
;
; a level is a datum, (level NAME FORM ..), in metres -- x east, z north, y up -- and its
; forms are:
;   (start x z [bearing])                  where the player stands, facing bearing degrees
;                                          from north toward east
;   (room x0 z0 x1 z1 height)              a box of floor, walls and ceiling. two rooms a
;                                          wall's thickness apart share that wall
;   (door x z width height)                a sliding door in the wall between two rooms,
;                                          its middle at x z; it opens as the player nears
;   (strip x z [across] [how])             a light strip on the ceiling, along z or across
;   (bulb x y z (r g b) [how])             a bare bulb, its light
;   (poster x z y width height [FILE])     on the wall nearest x z, its foot at y; a png's
;                                          path from the level's own folder, else drawn
;   (sign x z y height TEXT (r g b) [how]) a neon sign on the wall nearest x z
; how a light behaves: steady, stammer, buzz or breathe.
;
; nothing outside: every light is a lamp (mesh.l's), baked once into a channel and summed
; each frame by how bright it is just then. corridor-read, corridor-new, corridor-step,
; corridor-move and corridor-frame are pure, gated by test/host/corridor.l; corridor-watch
; reads the disk, and only corridor-walk and corridor-run tie the tty.
;
; run: love lore corridor [--level FILE] [--kitty|--cells]
;      h l or the arrows turn, k j step, u n look up and down; q or esc leaves
(module (corridor corridor-run corridor-walk corridor-main corridor-new corridor-size corridor-step
         corridor-move corridor-frame corridor-pens corridor-opts corridor-read corridor-load
         corridor-watch corridor-free? corridor-ks fps eye-h body-r)
(borrow 'rove)                          ; pad, for the bottom row
(borrow 'posix)                         ; open, close and stat, for the level and its pictures
(borrow 'view)                          ; the screen, the pens, the hash, the loop
(borrow 'vec)                           ; triples
(borrow 'mesh)                          ; the triangles, the lamps, the frame
(borrow 'neon)                          ; the signs, and the poster's letters
(:
 fps 20
 eye-h 1.6 body-r 0.25
 walk-v 1.8 turn-v 1.6 tilt-v 1.2         ; metres, and radians, a second
 door-v 1.4 door-near 2.4 door-t 0.03     ; the doors: their pace, how near opens one, half their thickness
 cell 0.25                                ; how fine the surfaces are cut, for the light
 watch-every 10                           ; frames between looks at the files
 the-level "src/apps/lore/levels/hall.l"
 ; --- the level, read: (corridor-read s) a tablet {'name 'start 'rooms 'doors 'strips
 ;     'bulbs 'posters 'signs}, or a string saying what is wrong ---
 (num? v) (charm? v || gem? v)
 (col? v) (two? v && #v = 3 && all num? v)
 (f v) (1.0 * v)
 (fs l) (map f l)
 (hows l) (filter (w \ elem w ['steady 'stammer 'buzz 'breathe]) l)
 (form k a) (? (k = 'start) (#a >= 2 && all num? a ? {'at (fs (take 2 a)) 'deg (f (peep a 2 0))})
               (k = 'room) (#a = 5 && all num? a ? (fs a))
               (k = 'door) (#a = 4 && all num? a ? (fs a))
               (k = 'strip) (#a >= 2 && all num? (take 2 a) ? {'at (fs (take 2 a)) 'across (elem 'across a) 'how (hows a)})
               (k = 'bulb) (#a >= 4 && all num? (take 3 a) && col? (a 3) ? {'at (fs (take 3 a)) 'c (fs (a 3)) 'how (hows a)})
               (k = 'poster) (#a >= 5 && all num? (take 5 a) ? {'at (fs (take 5 a)) 'file (peep a 5 ())})
               (k = 'sign) (#a >= 6 && all num? (take 4 a) && string? (a 4) && col? (a 5)
                              ? {'at (fs (take 4 a)) 'text (a 4) 'c (fs (a 5)) 'how (hows a)}))
 forms ['start 'room 'door 'strip 'bulb 'poster 'sign]
 (corridor-read s) (: r (sound s)
   (? (!(two? r) || !(two? <r) || <<r != 'level) "not a level: it should read (level NAME FORM ..)"
      (: nm (<r 1) fs0 (string? nm ? >><r >(<r))
         bad (filter (q \ !(two? q) || !(elem <q forms) || form <q >q = ()) fs0)
         (of k) (map (q \ form <q >q) (filter (q \ <q = k) fs0))
         (? (two? bad) ("not understood: " + show <bad)
            (atom? (of 'room)) "a level needs a room"
            (: lv {'name (string? nm ? nm "") 'rooms (of 'room) 'doors (of 'door) 'strips (of 'strip)
                   'bulbs (of 'bulb) 'posters (of 'poster) 'signs (of 'sign)
                   'start (of 'start @ () {'at [0.0 0.0] 'deg 0.0} l <l)}
               (doors-of lv @ ds (string? ds ? ds (pin lv 'doors ds))))))))
 ; ..a door's place among the rooms: the two walls it passes, on axis ax -- 'z when it
 ; spans x in a wall across z -- its middle c along them, a and b the walls' places
 (hits r x z) [(? (r 0 <= x <= r 2) (filter (w \ mag (w - z) < 0.5) [(r 1) (r 3)]) ())
               (? (r 1 <= z <= r 3) (filter (w \ mag (w - x) < 0.5) [(r 0) (r 2)]) ())]
 (doors-of lv) (: (place d) (: x (d 0) z (d 1) hs (map (r \ hits r x z) (lv 'rooms))
                                 zs (cats (map (h \ h 0) hs)) xs (cats (map (h \ h 1) hs))
                                 (? (#zs = 2) {'ax 'z 'c x 'a (min2 (zs 0) (zs 1)) 'b (max2 (zs 0) (zs 1)) 'w (d 2) 'h (d 3)}
                                    (#xs = 2) {'ax 'x 'c z 'a (min2 (xs 0) (xs 1)) 'b (max2 (xs 0) (xs 1)) 'w (d 2) 'h (d 3)}
                                    ("a door must sit in the wall between two rooms: " + show ('door . d))))
   ps (map place (lv 'doors))
   (any string? ps ? <(filter string? ps) ps))
 ; ..from a file: the level, or why not
 (slurp-file p) (: q (open p "r") (hot? q ? (slurp q @ s (close q, s)) ()))
 (corridor-load p) (slurp-file p @ () ("cannot read " + p) s (corridor-read s))
 ; --- places: in a door's frame, along its wall, up, and across it ---
 (P ax al y ac) (ax = 'z ? [al y ac] [ac y al])
 (along ax) (ax = 'z ? [1.0 0.0 0.0] [0.0 0.0 1.0])
 (across ax) (ax = 'z ? [0.0 0.0 1.0] [1.0 0.0 0.0])
 (room-at lv x z) (: rs (lv 'rooms)
   (gap r) (sq (max2 0.0 (max2 (r 0 - x) (x - r 2))) + sq (max2 0.0 (max2 (r 1 - z) (z - r 3))))
   (foldl (\ b r (gap r < gap b ? r b)) <rs >rs))
 ; ..a room's box as a mask of places, a little past its walls: what its lamps reach
 (inside r) (\ X Y Z ((r 0 - 0.11 < X) * (X < r 2 + 0.11) * (r 1 - 0.11 < Z) * (Z < r 3 + 0.11)))
 ; ..the wall of x z's room nearest it: [ax at lo hi n], n into the room
 (wall-near lv x z) (: r (room-at lv x z)
   ws [['x (r 0) (r 1) (r 3) [1.0 0.0 0.0]] ['x (r 2) (r 1) (r 3) [-1.0 0.0 0.0]]
       ['z (r 1) (r 0) (r 2) [0.0 0.0 1.0]] ['z (r 3) (r 0) (r 2) [0.0 0.0 -1.0]]]
   (d w) (mag ((w 0 = 'x ? x z) - w 1))
   (foldl (\ b w (d w < d b ? w b)) <ws >ws))
 ; ..a thing hung on that wall at x z: its foot there, the way into the room, and its
 ; right as one faces the wall
 (hang lv x z) (: w (wall-near lv x z) n (w 4) r [(0.0 - n 2) 0.0 (n 0)]
   [(w 0 = 'x ? [(w 1) 0.0 z] [x 0.0 (w 1)]) n r])
 ; --- the shapes ---
 white [1.0 1.0 1.0]
 tw (64.0 / 1.3)                          ; the wall's texels a metre
 (mag3 a) (sqrt (dot a a))
 (sheets o U V n uv tex col) (mesh-sheet o U V (max2 1 (int (mag3 U / cell + 0.5))) (max2 1 (int (mag3 V / cell + 0.5))) n uv tex col)
 (slab lo hi uv tex col) (: x0 (lo 0) y0 (lo 1) z0 (lo 2) x1 (hi 0) y1 (hi 1) z1 (hi 2)
   dx [(x1 - x0) 0.0 0.0] dy [0.0 (y1 - y0) 0.0] dz [0.0 0.0 (z1 - z0)]
   (mesh-join [(sheets lo dy dz [-1.0 0.0 0.0] uv tex col) (sheets [x1 y0 z0] dy dz [1.0 0.0 0.0] uv tex col)
               (sheets lo dx dz [0.0 -1.0 0.0] uv tex col) (sheets [x0 y1 z0] dx dz [0.0 1.0 0.0] uv tex col)
               (sheets lo dx dy [0.0 0.0 -1.0] uv tex col) (sheets [x0 y0 z1] dx dy [0.0 0.0 1.0] uv tex col)]))
 (wall-uv h) (p \ [(tw * (p 0 + p 2)) (tw * (h - p 1))])
 (floor-uv p) [(64.0 * p 0) (64.0 * p 2)]
 (ceil-uv p) [(64.0 / 1.2 * p 0) (64.0 / 1.2 * p 2)]
 (sort-by k l) (map (q \ q 1) (sort (map (v \ [(k v) v]) l)))
 ; a room: its floor, ceiling and four walls, each wall cut round the doors through it
 (room-mesh lv r) (: x0 (r 0) z0 (r 1) x1 (r 2) z1 (r 3) h (r 4) dx [(x1 - x0) 0.0 0.0] dz [0.0 0.0 (z1 - z0)]
   (wall ax at lo hi n)
    (: dd (sort-by (d \ d 'c) (filter (d \ d 'ax = ax && (d 'a = at || d 'b = at)) (lv 'doors)))
       (piece l0 l1 y0 y1) (l1 - l0 < 0.005 || y1 - y0 < 0.005 ? ()
                              [(sheets (P ax l0 y0 at) (c* (l1 - l0) (along ax)) [0.0 (y1 - y0) 0.0] n (wall-uv h) 0 white)])
       (go s l) (? (atom? l) (piece s hi 0.0 h)
                   (: d <l a (d 'c - 0.5 * d 'w) b (d 'c + 0.5 * d 'w)
                      (piece s a 0.0 h + piece a b (d 'h) h + go b >l)))
       (go lo dd))
   (mesh-join ([(sheets [x0 0.0 z0] dx dz [0.0 1.0 0.0] floor-uv 1 white) (sheets [x0 h z0] dx dz [0.0 -1.0 0.0] ceil-uv 2 white)]
               + wall 'x x0 z0 z1 [1.0 0.0 0.0] + wall 'x x1 z0 z1 [-1.0 0.0 0.0]
               + wall 'z z0 x0 x1 [0.0 0.0 1.0] + wall 'z z1 x0 x1 [0.0 0.0 -1.0])))
 ; ..a doorway through the wall's thickness: its two jambs, the lintel's underside and the sill
 (frame-mesh d) (: ax (d 'ax) a (d 'a) b (d 'b) l0 (d 'c - 0.5 * d 'w) l1 (d 'c + 0.5 * d 'w) h (d 'h)
   dp (c* (b - a) (across ax)) wd (c* (l1 - l0) (along ax)) up [0.0 h 0.0]
   (b - a < 0.01 ? ()
      [(sheets (P ax l0 0.0 a) dp up (along ax) (wall-uv h) 0 white)
       (sheets (P ax l1 0.0 a) dp up (c* -1.0 (along ax)) (wall-uv h) 0 white)
       (sheets (P ax l0 h a) wd dp [0.0 -1.0 0.0] (wall-uv h) 0 white)
       (sheets (P ax l0 0.0 a) wd dp [0.0 1.0 0.0] floor-uv 1 white)]))
 ; ..the door itself, shut: a slab of steel in the middle of the wall, the texture once
 ; across each face
 (door-mesh d) (: ax (d 'ax) m (0.5 * (d 'a + d 'b)) l0 (d 'c - 0.5 * d 'w) w (d 'w) h (d 'h)
   p (P ax l0 0.0 (m - door-t)) q (P ax (l0 + w) h (m + door-t))
   (slab p q (s \ [(64.0 / w * ((ax = 'z ? s 0 (s 2)) - l0)) (128.0 / h * (h - s 1))]) 3 white))
 ; --- the lights: {'lamps 'how 'shine 'glow} -- lamps summed as one channel, how it
 ;     behaves, and what shines and glows by it, [packed brightness] each ---
 (light ls how sh gl) {'lamps ls 'how how 'shine sh 'glow gl}
 (nub at s col) (slab (c+ at [(0.0 - s) (0.0 - s) (0.0 - s)]) (c+ at [s s s]) (_ \ [0.0 0.0]) -1 col)
 (strip-light lv s) (: x (s 'at 0) z (s 'at 1) r (room-at lv x z) h (r 4) ac (s 'across) k (inside r)
   (pt i) (: o (0.3 * i - 0.6) (ac ? [(x + o) (h - 0.06) z] [x (h - 0.06) (z + o)]))
   bar (ac ? (slab [(x - 0.6) (h - 0.05) (z - 0.08)] [(x + 0.6) h (z + 0.08)] (_ \ [0.0 0.0]) -1 white)
            (slab [(x - 0.08) (h - 0.05) (z - 0.6)] [(x + 0.08) h (z + 0.6)] (_ \ [0.0 0.0]) -1 white))
   (light [{'at (map pt ^5) 'n [0.0 -1.0 0.0] 'c [2.3 2.4 2.6] 'r 7.5 'keep k}
           {'at [[x 0.02 z]] 'n [0.0 1.0 0.0] 'c [1.1 1.1 1.15] 'r 6.0 'soft 1.0 'keep k}]
          (s 'how) [[(mesh-pack bar) 3.0]] ()))
 (bulb-light lv b) (: p (b 'at) c (b 'c) r (room-at lv (p 0) (p 2)) top (max2 0.01 (max2 (c 0) (max2 (c 1) (c 2))))
   (light [{'at [p] 'c c 'r 6.0 'soft 0.15 'keep (inside r)}] (b 'how)
          [[(mesh-pack (nub p 0.05 (c* (1.0 / top) c))) 2.0]] ()))
 (sign-light lv s) (: a (s 'at) hg (hang lv (a 0) (a 1)) n (hg 1) rt (hg 2) h (a 3)
   w (h * (neon-strokes (s 'text) 1)) o (c+ (c+ (hg 0) [0.0 (a 2) 0.0]) (c* (-0.5 * w) rt))
   sg (neon-sign (s 'text) o rt [0.0 1.0 0.0] n h (c* 0.7 (s 'c)))
   (light [(pin (sg 'lamp) 'keep (inside (room-at lv (a 0) (a 1))))] (s 'how)
          [[(sg 'tube) 3.5]] [[(sg 'halo) 0.3]]))
 ; ..each door's lamps either side of it, red while it is shut and green once it opens
 (door-lights lv i d) (: ax (d 'ax) at (d 'c + 0.5 * d 'w + 0.25)
   (side ac off) (: p (P ax at 1.5 (ac + off)) k (inside (room-at lv (p 0) (p 2)))
     [(light [{'at [p] 'c [0.08 0.006 0.003] 'r 1.6 'soft 0.2 'keep k}] [['shut i]]
             [[(mesh-pack (nub p 0.035 [1.0 0.1 0.05])) 2.5]] ())
      (light [{'at [p] 'c [0.006 0.07 0.015] 'r 1.6 'soft 0.2 'keep k}] [['open i]]
             [[(mesh-pack (nub p 0.035 [0.1 1.0 0.25])) 2.5]] ())])
   (side (d 'a) -0.01 + side (d 'b) 0.01))
 (lights-of lv) (map (s \ strip-light lv s) (lv 'strips) + map (b \ bulb-light lv b) (lv 'bulbs)
                 + map (s \ sign-light lv s) (lv 'signs)
                 + cats (map (i \ door-lights lv i (lv 'doors i)) ^#(lv 'doors)))
 ; ..how bright a light is at mt seconds, the doors open by ds: steady; a strip failing,
 ; mostly on and now and then stammering off; a tube's buzz; a bulb breathing; a door's
 ; lamp by its door. sd keeps two failing lights out of step
 (stammer mt sd) (: s (int (mt * 12.0)) burst (throw (int (mt / 3.0)) sd 151 5 = 0)
   (burst && throw s (sd + 2) 157 3 != 0 ? (0.05 * throw s 3 163 4) (throw s (sd + 4) 167 90 = 0 ? 0.3 1.0)))
 (bright how mt sd ds) (: w (two? how ? <how 'steady)
   (? (w = 'stammer) (stammer mt sd)
      (w = 'buzz) (0.93 + 0.07 * sin (mt * 53.0) * sin (mt * 7.0))
      (w = 'breathe) (0.7 + 0.3 * sin (mt * 1.7 + sd))
      (two? w) (: d (peep ds (w 1) 0.0) (<w = 'shut ? (d < 0.02 ? 1.0 0.0) (d < 0.02 ? 0.0 1.0)))
      1.0))
 (corridor-ks sc mt ds) (map (i \ bright (sc 'lights i 'how) mt i ds) ^#(sc 'lights))
 amb [0.025 0.025 0.03]
 ; --- the textures: [walls floor ceiling door posters..] ---
 (grey g) [g g g]
 (tex-wall _) (mesh-pic 64 128 (\ x y (: n (0.94 + 0.06 * vn (x / 9.0) (y / 7.0) 211)
   (? (x < 1 || 62 < x) (grey 0.22)
      (124 <= y) (grey 0.16)
      (78 <= y <= 80) (c* n [0.42 0.45 0.44])
      (c* n (79 < y ? [0.5 0.54 0.52] [0.66 0.7 0.68]))))))
 (tex-floor _) (mesh-pic 64 64 (\ x y (: n (0.9 + 0.1 * vn (x / 5.0) (y / 5.0) 223)
   (x % 32 = 0 || y % 32 = 0 ? (grey 0.12) (c* n ((x // 32 + y // 32) % 2 = 0 ? [0.34 0.34 0.36] [0.3 0.31 0.33]))))))
 (tex-ceil _) (mesh-pic 64 64 (\ x y (x % 32 = 0 || y % 32 = 0 ? (grey 0.3) (grey (0.78 + 0.03 * vn (x / 6.0) (y / 6.0) 227)))))
 (tex-door _) (mesh-pic 64 128 (\ x y (: s (0.92 + 0.08 * vn (x / 30.0) (y * 1.3) 229)
   (? (y >= 112) ((x + 128 - y) % 16 < 8 ? [0.85 0.65 0.08] (grey 0.08))
      (y % 32 = 0) (grey 0.25)
      (30 <= x <= 33) (grey 0.2)
      (c* s [0.5 0.52 0.56])))))
 ; ..a poster drawn: a navy field, a pale ring round a star of four points, a red band
 ; across, and ENLIST in the letters the neon bends; a pale edge
 (poster-art _) (: w 48 h 72 sk (neon-strokes "ENLIST") k (40.0 / sk 1)
   segs (cats (map (ln \ (: (go l) (atom? >l ? () ([<l <>l] . go >l)) (go ln))) (sk 0)))
   ; ..each letter's stroke in texels, from the bottom left at 4 8 and k a cap
   (tx p) [(4.0 + k * p 0) (h - 8.0 - k * p 1)]
   ts (map (g \ [(tx (g 0)) (tx (g 1))]) segs)
   (near px py) (any (g \ (: a (g 0) b (g 1) dx (b 0 - a 0) dy (b 1 - a 1) l2 (max2 1e-9 (dx * dx + dy * dy))
                            t (sat (((px - a 0) * dx + (py - a 1) * dy) / l2)) ex (a 0 + t * dx - px) ey (a 1 + t * dy - py)
                            (ex * ex + ey * ey < 1.3))) ts)
   cream [0.9 0.85 0.7] navy [0.07 0.1 0.24] red [0.7 0.1 0.08]
   (mesh-pic w h (\ x y (: px (x + 0.5) py (y + 0.5) cx (px - 24.0) cy (py - 26.0) r (sqrt (cx * cx + cy * cy))
     star (mag cx * mag cy < 9.0 && r < 13.0)
     (? (x < 2 || 45 < x || y < 2 || 69 < y) cream
        (near px py) cream
        (15.0 < r < 17.5 || star) cream
        (mag (py - 0.5 * px - 34.0) < 3.0) red
        navy)))))
 ; ..or a png's, 80 texels a metre up to 128 a side; drawn where there is none
 (poster-tex path w h) (: b (string? path ? (slurp-file path)) r (string? b ? (cite 'png 'png-decode b))
   (two? r && charm? (r 0)
    ? (mesh-rgba (r 0) (r 1) (r 2) (min2 128 (max2 2 (int (80.0 * w)))) (min2 128 (max2 2 (int (80.0 * h)))))
      (poster-art ())))
 ; ..a poster's sheet: on the wall nearest x z, a hair off it, its texture tex tw by th
 (poster-mesh lv p tex tw th) (: a (p 'at) hg (hang lv (a 0) (a 1)) n (hg 1) rt (hg 2) w (a 3) h (a 4)
   o (c+ (c+ (hg 0) (c* 0.006 n)) (c+ [0.0 (a 2) 0.0] (c* (-0.5 * w) rt)))
   (sheets o [0.0 h 0.0] (c* w rt) n (q \ (: d (c+ q (c* -1.0 o)) [(1.0 * tw / w * dot d rt) (1.0 * th / h * (h - d 1))])) tex white))
 (file-of dir p) ((p 'file) @ () () f ((f 0) = 47 ? f (dir + f)))
 ; --- the scene, built from a level: the meshes packed and each light's channel baked;
 ;     dir the level's folder, for its pictures ---
 (scene lv dir) (: ps (lv 'posters) ls (lights-of lv)
   ptex (map (p \ poster-tex (file-of dir p) (p 'at 3) (p 'at 4)) ps)
   pm (map (i \ poster-mesh lv (ps i) (4 + i) (shape (ptex i 0) 1) (shape (ptex i 0) 0)) ^#ps)
   hall (mesh-pack (mesh-join (map (r \ room-mesh lv r) (lv 'rooms) + cats (map frame-mesh (lv 'doors)) + pm)))
   drs (map (d \ mesh-pack (door-mesh d)) (lv 'doors))
   (chs pk) (map (l \ foldl (\ a lp (c+ a (mesh-lamp pk lp))) [0.0 0.0 0.0] (l 'lamps)) ls)
   {'hall hall 'hall-ch (chs hall) 'doors drs 'doors-ch (map chs drs) 'lights ls
    'texs ([(tex-wall ()) (tex-floor ()) (tex-ceil ()) (tex-door ())] + ptex)})
 ; --- the frame: the rooms and doors lit by the lights as bright as they are now, then
 ;     what shines, then the glows; out as half blocks or kitty's pixels ---
 fov 1.5
 kitty-w 640
 kitty-id 7
 kitty-gone (mesh-kitty-del 7 + mesh-kitty-del 8)
 gain 2.0
 (corridor-pens st) (: k (peep st 'kp 1) w (k * st 'w) h (k * st 'h) sc (st 'sc) lv (st 'lvl)
   ds (st 'doors) ks (corridor-ks sc (st 'mt) ds)
   e [(st 'px) (st 'py) (st 'pz)]
   v (mesh-eye w h e (st 'th) (st 'ph) 0.0 fov 0.05 60.0)
   hall (mesh-lamps (sc 'hall) amb (sc 'hall-ch) ks 1.0)
   ; ..each door slid open along its wall into the wall's thickness
   doors (map (i \ (: pk (sc 'doors i) b (mesh-lamps pk amb (sc 'doors-ch i) ks 1.0) d (lv 'doors i)
                      ix (iota (pk 'n) * 8 + (d 'ax = 'z ? 0 2))
                      [(pin (b 0) ix (peep (b 0) ix 0.0 + ds i * (d 'w - 0.05))) (b 1)]))
              ^#(lv 'doors))
   ; ..what shines and glows, at each light's brightness; none where it is out
   (by key) (cats (map (i \ cats (map (q \ ((q 1 * ks i) @ 0.0 () b [(mesh-shine (q 0) b)])) (sc 'lights i key))) ^#ks))
   all ([hall] + doors + by 'shine + map mesh-glow (by 'glow))
   (mesh-frame v [(map (b \ b 0) all) (map (b \ b 1) all)] (sc 'texs) [0.0 0.0 0.0 30.0 60.0] 8 gain 0))
 ; ..a frame, and under it the bottom row's word: what a reload found wrong, or for a few
 ; seconds that it read the level again
 (corridor-frame st) (: w (st 'w) h (st 'h) k (peep st 'kp 1) f (corridor-pens st) r (h // 2)
   m (st 'msg) say? (string? m && (st 'err || st 'mt < st 'msg-t + 3.0))
   text (say? ? (snip (pad (" " + m) w " ") 0 w) "")
   (? (st 'kitty)
      (: n (peep st 'kn 0) _ (pin st 'kn (1 - n))
         (esc + "[?2026h" + mesh-kitty f (k * w) (k * h) w r (kitty-id + n) + mesh-kitty-del (kitty-id + 1 - n)
          + (say? ? (esc + "[" + show r + ";1H" + esc + (st 'err ? "[1;37;41m" "[0;37;40m") + text + esc + "[0m") "")
          + esc + "[?2026l"))
      (esc + "[?2026h" + mesh-cells f w h (st 'deep) (st 'deep ? 0 (st 'bay)) (say? ? (band st text r) {}) + esc + "[?2026l")))
 ; ..as one of view's bands on row r: its cells, a character each, and its pens
 (band st s r) (: deep (st 'deep)
   (pen v) (deep ? (: (q x) ((x * 63 + 127) // 255) (q (v 0) * 4096 + q (v 1) * 64 + q (v 2))) (v 3))
   (cells s) (: (go i) (i < #s ? (: j (cite 'text 'cpnext s i) (snip s i j . go j)) ()) (go 0))
   {(r - 1) [0 (cells s) (pen [240 240 240 255]) (pen (st 'err ? [150 20 20 124] [20 20 20 233]))]})
 ; --- the state: the screen as view lays it, the level and its scene, where the player
 ;     stands and looks, the clock, the doors ---
 (corridor-new w h lv dir) (: s (lv 'start)
   (corridor-size {'px (s 'at 0) 'pz (s 'at 1) 'py eye-h 'th (s 'deg * pi / 180.0) 'ph 0.0 't 0 'mt 0.0
                   'lvl lv 'sc (scene lv dir) 'dir dir 'doors (map (_ \ 0.0) (lv 'doors)) 'deep 0 'kitty 0 'kp 1
                   'done 0 'msg () 'msg-t 0.0 'err 0}
                  w (h // 2)))
 (corridor-size st w r) (: h (2 * r)
   (pins (view! st w h (h // 2)) 'bay (view-bayer w h) 'kp (st 'kitty ? (max2 1 (kitty-w // w)) 1)))
 ; --- moving: inside a room, or through a doorway once its door is open ---
 (corridor-free? st x z) (: r body-r lv (st 'lvl)
   (any (q \ q 0 + r < x && x < q 2 - r && q 1 + r < z && z < q 3 - r) (lv 'rooms)
    || any (i \ (: d (lv 'doors i) al (d 'ax = 'z ? x z) ac (d 'ax = 'z ? z x)
                   (0.85 < st 'doors i && mag (al - d 'c) < 0.5 * d 'w - r && d 'a - r - 0.01 < ac && ac < d 'b + r + 0.01)))
           ^#(lv 'doors)))
 (put! st x z) (? (corridor-free? st x z) (pins st 'px x 'pz z)
                  (corridor-free? st x (st 'pz)) (pin st 'px x)
                  (corridor-free? st (st 'px) z) (pin st 'pz z)
                  st)
 (corridor-step st k) (: th (st 'th) dt (peep st 'dt (1.0 / fps))
   (step d) (put! st (st 'px + d * sin th) (st 'pz + d * cos th))
   (k @ (104 || -1) (pin st 'th (wrap (th - turn-v * dt)))
        (108 || -2) (pin st 'th (wrap (th + turn-v * dt)))
        (107 || -8) (step (walk-v * dt))
        (106 || -9) (step (0.0 - walk-v * dt))
        117 (pin st 'ph (min2 1.3 (st 'ph + tilt-v * dt)))
        110 (pin st 'ph (max2 -1.2 (st 'ph - tilt-v * dt)))
        st))
 ; a frame's motion: the clock, and each door toward open while the player is near it
 (corridor-move st) (: dt (peep st 'dt (1.0 / fps)) lv (st 'lvl) x (st 'px) z (st 'pz)
   (go i) (: d (lv 'doors i) o (st 'doors i) p (P (d 'ax) (d 'c) 0.0 (0.5 * (d 'a + d 'b)))
             want (sq (p 0 - x) + sq (p 2 - z) < sq door-near ? 1.0 0.0)
             (want < o ? (max2 want (o - door-v * dt)) (min2 want (o + door-v * dt))))
   (pins st 'mt (st 'mt + dt) 'doors (map go ^#(lv 'doors))))
 ; --- the files watched: the level and its pictures, each by its size, time and inode;
 ;     the first look takes them, and a change reads the level again and builds its
 ;     scene, the player kept where they stand. a level that will not read keeps the
 ;     last, and says why ---
 (stamp p) (stat p @ s (two? s ? [(s 0) (s 3) (s 8)] ()))
 (files st) (: p (st 'path)
   (string? p ? (p . filter string? (map (q \ file-of (st 'dir) q) (st 'lvl 'posters))) ()))
 (seen! st) (pin st 'stamps (map (p \ [p (stamp p)]) (files st)))
 (corridor-watch st) (: was (peep st 'stamps ())
   (? (atom? was) (seen! st)
      (all (q \ stamp (q 0) = q 1) was) st
      (: lv (corridor-load (st 'path))
         (? (string? lv) (pins (seen! st) 'msg lv 'err 1 'msg-t (st 'mt))
            (: ds (#(lv 'doors) = #(st 'lvl 'doors) ? (st 'doors) (map (_ \ 0.0) (lv 'doors)))
               (seen! (pins st 'lvl lv 'sc (scene lv (st 'dir)) 'doors ds 'msg ("read " + st 'path + " again")
                               'err 0 'msg-t (st 'mt))))))))
 (dir-of p) (: (go i) (i < 0 ? "" (p i = 47 ? (snip p 0 (i + 1)) (go (i - 1)))) (go (#p - 1)))
 ; --- the walk, on view's loop; corridor-run raises the stage ---
 (corridor-walk o lv)
   (view-walk {'new (w \ h \ (: k (o 'md @ 'kitty 1 'cells 0 (mesh-kitty? ())) p (o 'level)
                               st (pins (corridor-new w h lv (dir-of p)) 'deep (elem (getenv "COLORTERM") ["truecolor" "24bit"])
                                        'kitty k 'path p)
                               (corridor-watch (corridor-size st w (h // 2)))))
               'size corridor-size 'frame corridor-frame 'key corridor-step
               'tick (st \ (clock 0 @ now (pins st 'dt (clamp ((now - peep st 'wall now) / 1000.0) 0.02 0.25) 'wall now),
                            corridor-move st,
                            (st 't % watch-every = 0 ? (corridor-watch st))))
               'fps fps 'linger 0 'next () 'song (_ \ ())})
 ; ..the level named, else the tree's own on disk, else the one the binary carries
 (corridor-run o) (: p (o 'level @ () (two? (stat the-level) ? the-level ("/love/" + the-level)) q q)
                     lv (corridor-load p)
   (? (string? lv) (say err ("corridor: " + p + ": " + lv + "\n"), flush err, 1)
      (view-run (_ \ corridor-walk (pin o 'level p) lv), say out kitty-gone, flush out, 0)))
 corridor-usage "usage: love lore corridor [--level FILE] [--kitty|--cells]   (h l turn, k j step, u n look; q or esc leaves; the level is read again when it changes)"
 ; the words, as a tablet for corridor-run, or () where one is wrong or said twice
 (corridor-opts as)
  (: o {}
     (once k v r) (v = () || o k != () ? () (pin o k v, go r))
     (go l) (? (atom? l) o
               (<l = "--kitty") (once 'md 'kitty >l)
               (<l = "--cells") (once 'md 'cells >l)
               (two? >l && <l = "--level") (once 'level <>l >>l))
     (go as))
 (corridor-main as) (corridor-opts as @ o
   (tablet? o ? (corridor-run o) (say err ("corridor: " + corridor-usage + "\n"), flush err, 2)))
 _ (cite 'lore 'lore-enlist 'corridor (udoor 'corridor corridor-main corridor-usage 1 1)))
) ; module corridor
