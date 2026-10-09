; corridor -- an indoor level played in first person, its rooms read from a level file
; and read again whenever the file changes, so a level is built by hand in an editor
; beside the running game. the first is the test corridor (src/apps/lore/levels/hall.l):
; a station hallway under light strips, one of them failing, a poster and a neon sign on
; its walls, and a sliding door at its end onto a room lit by one red bulb. the second is
; a subway station (levels/station.l), its walls ribbed with pilasters that slope into
; buttresses under the ceiling.
;
; a level is a datum, (level NAME FORM ..), in metres -- x east, y up, z north. every
; place in it is a point (x y z), in that order, and every colour (rgb r g b); its forms:
;   (start (x y z) [bearing [pitch]])       where the player stands, facing bearing degrees
;                                           from north toward east, looking pitch degrees up
;   (room (x y z) (x y z) SKIN ..)          a box of air between two corners: floor, walls
;                                           and ceiling. two rooms a wall apart share it
;   (air SHAPE CUT .. SKIN ..) (solid SHAPE CUT .. SKIN ..)  a brush (brush.l): space starts
;                                           solid, air carves it and solid fills it again, the
;                                           later winning; a room is an air box
;     SHAPE (box (x y z) (x y z))           ..between two corners
;           (prism height (x y z) (x y z) (x y z) ..)  its floor plan going round, all at
;                                           the first point's height, standing height tall
;     CUT   (cut (x y z) (x y z) (x y z))   ..less what lies across the plane through three
;                                           points from the brush's middle: a slope, a bevel
;     SKIN  (walls NAME) (floor NAME) (ceiling NAME) (all NAME)  the textures on its faces,
;                                           a floor any face turned up and a ceiling down;
;                                           otherwise those named wall, floor and ceiling
;   (texture NAME width height metres LAYER ..)  a texture, width by height texels and
;                                           metres wide on a surface, painted by its layers
;                                           (swatch.l). a wall's sits on its brush's foot; one
;                                           named door is the doors'. one not given is a grid
;   (repeat n (dx dy dz) FORM ..)           the forms n times, each that far on from the last
;   (mirror x c FORM ..) (mirror z c FORM ..) the forms, and again reflected where x or z is c
;   (door (x y z) width height)             a sliding door in the wall between two rooms, the
;                                           middle of its foot at x y z
;   (strip (x y z) [across] [how])          a light strip, its face at y, along z or across
;   (bulb (x y z) (rgb r g b) [how])        a bare bulb, its light
;   (poster (x y z) width height [FILE])    on the wall nearest, the middle of its foot at
;                                           x y z; a png's path from the level's folder
;   (sign (x y z) height TEXT (rgb r g b) [how])  a neon sign on the wall nearest, the
;                                           middle of its foot at x y z
; how a light behaves: steady, stammer, buzz or breathe.
;
; nothing outside: every light is a lamp (mesh.l's), baked once into a channel and summed
; each frame by how bright it is just then. corridor-read, corridor-new, corridor-step,
; corridor-move and corridor-frame are pure, gated by test/host/corridor.l; corridor-watch
; reads the disk, and only corridor-walk and corridor-run tie the tty.
;
; run: love lore corridor [--level FILE] [--kitty|--cells]
;      h l or the arrows turn, k j step, u n look up and down, p where you stand; q or
;      esc leaves
(module (corridor corridor-run corridor-walk corridor-main corridor-new corridor-size corridor-step
         corridor-move corridor-frame corridor-pens corridor-opts corridor-read corridor-load
         corridor-watch corridor-free? corridor-ks fps eye-h body-r)
(borrow 'rove)                          ; pad, for the bottom row
(borrow 'posix)                         ; open, close and stat, for the level and its pictures
(borrow 'view)                          ; the screen, the pens, the hash, the loop
(borrow 'vec)                           ; triples
(borrow 'mesh)                          ; the triangles, the lamps, the frame
(borrow 'neon)                          ; the signs, and the poster's letters
(borrow 'brush)                         ; the world, carved and filled
(borrow 'swatch)                        ; the textures, from their recipes
(:
 fps 20
 eye-h 1.6 body-r 0.25
 walk-v 1.8 turn-v 1.6 tilt-v 1.2         ; metres, and radians, a second
 door-v 1.4 door-near 2.4 door-t 0.03     ; the doors: their pace, how near opens one, half their thickness
 cell 0.25                                ; how fine the surfaces are cut, for the light
 watch-every 10                           ; frames between looks at the files
 the-level "src/apps/lore/levels/hall.l"
 ; --- the level, read: (corridor-read s) a tablet {'name 'start 'rooms 'doors 'strips
 ;     'bulbs 'posters 'signs 'brushes 'textures}, or a string saying what is wrong ---
 (num? v) (charm? v || gem? v)
 (f v) (1.0 * v)
 (pt q) (two? q && #q = 3 && all num? q ? (map f q))
 (rgb q) (two? q && <q = 'rgb && #q = 4 && all num? >q ? (map f >q))
 (hows l) (filter (w \ elem w ['steady 'stammer 'buzz 'breathe]) l)
 (name? v) (kind v = 'nom)
 ; ..a brush's skin: [class name] each, the later winning
 (opt? q) (two? q && #q = 2 && elem <q ['walls 'floor 'ceiling 'all] && name? (q 1))
 (skin-of l) (cats (map (q \ (<q = 'all ? (map (c \ [c (q 1)]) ['wall 'floor 'ceiling]) [[(<q = 'walls ? 'wall <q) (q 1)]]))
                       (filter opt? l)))
 (skin-name sk c) (foldl (\ a e (e 0 = c ? e 1 a)) c sk)
 ; ..each form's words, or () where they are not what it takes
 (form k a) (: p (a 0) at (pt p) (n i) (num? (a i)) (v i) (f (a i))
   (k @ 'start (at != () && (#a = 1 || n 1) && (#a <= 2 || n 2)
                    ? {'at [(at 0) (at 2)] 'y (at 1) 'deg (#a > 1 ? (v 1) 0.0) 'pitch (#a > 2 ? (v 2) 0.0)})
       'room (#a >= 2 && at != () && pt (a 1) != () && all opt? (drop 2 a)
                   ? (: q (pt (a 1)) [(min2 (at 0) (q 0)) (min2 (at 2) (q 2)) (max2 (at 0) (q 0)) (max2 (at 2) (q 2))
                                     (max2 (at 1) (q 1)) (min2 (at 1) (q 1))]))
       'door (#a = 3 && at != () && n 1 && n 2 ? [(at 0) (at 2) (v 1) (v 2) (at 1)])
      'strip (at != () ? {'at [(at 0) (at 2)] 'y (at 1) 'across (elem 'across a) 'how (hows a)})
       'bulb (at != () && rgb (peep a 1 ()) != () ? {'at at 'c (rgb (a 1)) 'how (hows a)})
       'poster (#a >= 3 && at != () && n 1 && n 2 ? {'at [(at 0) (at 2) (at 1) (v 1) (v 2)] 'file (peep a 3 ())})
       'sign (#a >= 4 && at != () && n 1 && string? (a 2) && rgb (peep a 3 ()) != ()
                   ? {'at [(at 0) (at 2) (at 1) (v 1)] 'text (a 2) 'c (rgb (a 3)) 'how (hows a)})
      ('air || 'solid)
       (two? a && shape-of <a != () && all (c \ cut-of c != () || opt? c) >a
        ? {'air (k = 'air) 'shape (shape-of <a) 'cuts (map cut-of (filter (!= () * cut-of) >a)) 'skin (skin-of >a)})
       'texture (#a >= 4 && name? (a 0) && charm? (a 1) && charm? (a 2) && 0 < a 1 <= 512 && 0 < a 2 <= 512
                 && n 3 && v 3 > 0.0 && swatch-fault (drop 4 a) = ()
                 ? {'name (a 0) 'w (a 1) 'h (a 2) 'm (v 3) 'layers (drop 4 a)})))
 ; ..a brush's shape, and a cut
 (shape-of q) (? (!(two? q)) ()
                 (<q = 'box && #q = 3 && pt (q 1) != () && pt (q 2) != ())
                  (: a (pt (q 1)) b (pt (q 2)) {'box [(map (k \ min2 (a k) (b k)) ^3) (map (k \ max2 (a k) (b k)) ^3)]})
                 (<q = 'prism && #q >= 5 && num? (q 1) && all (p \ pt p != ()) (drop 2 q))
                  (: ps (map pt (drop 2 q)) y0 (<ps 1) {'prism [y0 (y0 + f (q 1)) (map (p \ [(p 0) (p 2)]) ps)]}))
 (cut-of q) (two? q && <q = 'cut && #q = 4 && all (!= () * pt) >q ? (map pt >q))
 ; ..what each form takes, said back when one is not understood
 usage {'start "(start (x y z) [bearing [pitch]])" 'room "(room (x y z) (x y z) [(walls NAME)] [(floor NAME)] [(ceiling NAME)] [(all NAME)])"
        'door "(door (x y z) width height)"
        'strip "(strip (x y z) [across] [how])" 'bulb "(bulb (x y z) (rgb r g b) [how])"
        'poster "(poster (x y z) width height [FILE])" 'sign "(sign (x y z) height TEXT (rgb r g b) [how])"
        'air "(air (box (x y z) (x y z)) (cut (x y z) (x y z) (x y z)) .. (walls NAME) ..)"
        'solid "(solid (box (x y z) (x y z)) (cut (x y z) (x y z) (x y z)) .. (walls NAME) ..)"
        'texture "(texture NAME width height metres LAYER ..)"}
 ; ..what is wrong with a form not understood: a texture's first bad layer, or what it reads
 (why q) (: u (two? q && <q = 'texture && #q >= 6 ? (swatch-fault (drop 5 q)))
   (? (two? u) "not understood: \(u 0) in the texture \(q 1)  -- it reads \(u 1)"
      ("not understood: " + show q + (two? q && usage <q != () ? ("  -- it reads " + usage <q) ""))))
 ; ..a brush with no inside: a box flat in some direction, a prism no height
 (empty? r) (: sh (r 'shape)
   (sh 'box @ () (: p (sh 'prism) (p 1 - p 0 < 1e-6)) b (any (k \ b 1 k - b 0 k < 1e-6) ^3)))
 ; --- repeat and mirror, laid out before the level is read: each a copy of its forms with
 ;     every point (x y z) in them moved, and a start's bearing turned ---
 (re-form q g b) (: (go e) (? (!(two? e)) e (pt e != () ? (g (pt e)) (map go e)))
   (two? q && <q = 'start && num? (peep q 2 ()) ? ('start . go (q 1) . b (f (q 2)) . drop 3 q) (go q)))
 (expand l) (cats (map (q \ (? (two? q && <q = 'repeat && #q >= 3 && num? (q 1) && pt (q 2) != ())
                                (: n (int (q 1)) d (pt (q 2)) inner (expand (drop 3 q))
                                   (cats (map (i \ map (r \ re-form r (p \ [(p 0 + i * d 0) (p 1 + i * d 1) (p 2 + i * d 2)]) (b \ b)) inner) ^n)))
                                (two? q && <q = 'mirror && #q >= 3 && elem (q 1) ['x 'z] && num? (q 2))
                                (: inner (expand (drop 3 q)) c (f (q 2)) x? (q 1 = 'x)
                                   (inner + map (r \ re-form r (p \ x? ? [(2.0 * c - p 0) (p 1) (p 2)] [(p 0) (p 1) (2.0 * c - p 2)])
                                                              (b \ x? ? (0.0 - b) (180.0 - b))) inner))
                                [q]))
                       l))
 forms ['start 'room 'door 'strip 'bulb 'poster 'sign 'air 'solid 'texture]
 (corridor-read s) (: r (sound s)
   (? (!(two? r) || !(two? <r) || <<r != 'level) "not a level: it should read (level NAME FORM ..)"
      (: nm (<r 1) fs0 (expand (string? nm ? >><r >(<r)))
         bad (filter (q \ !(two? q) || !(elem <q forms) || form <q >q = ()) fs0)
         (of k) (map (q \ form <q >q) (filter (q \ <q = k) fs0))
         ; ..the brushes in the file's order, a room an air box
         bq (filter (q \ elem <q ['room 'air 'solid]) fs0)
         bs (map (q \ (: v (form <q >q) (<q = 'room ? {'air 1 'shape {'box [[(v 0) (v 5) (v 1)] [(v 2) (v 4) (v 3)]]} 'cuts ()
                                                         'skin (skin-of (drop 2 >q))} v))) bq)
         hollow (two? bad ? () (filter (i \ empty? (bs i)) ^#bs))
         ; ..a skin's names each a texture's
         tn (two? bad ? () (map (t \ t 'name) (of 'texture)))
         unnamed (two? bad ? () (filter (nm \ !(elem nm tn)) (cats (map (b \ map (e \ e 1) (b 'skin)) bs))))
         (? (two? bad) (why <bad)
            (two? hollow) "a brush with no inside: \(bq <hollow)"
            (two? unnamed) "no texture named \(<unnamed): a level's own are made by (texture NAME width height metres LAYER ..)"
            (atom? (of 'room)) "a level needs a room"
            (: lv {'name (string? nm ? nm "") 'rooms (of 'room) 'doors (of 'door) 'strips (of 'strip)
                   'bulbs (of 'bulb) 'posters (of 'poster) 'signs (of 'sign) 'brushes bs 'textures (of 'texture)
                   'start (of 'start @ () {'at [0.0 0.0] 'y 0.0 'deg 0.0 'pitch 0.0} l <l)}
               (doors-of lv @ ds (string? ds ? ds (pin lv 'doors ds))))))))
 ; ..a door's place among the rooms: the two walls it passes, on axis ax -- 'z when it
 ; spans x in a wall across z -- its middle c along them, a and b the walls' places
 (hits r x z) [(? (r 0 <= x <= r 2) (filter (w \ mag (w - z) < 0.5) [(r 1) (r 3)]) ())
               (? (r 1 <= z <= r 3) (filter (w \ mag (w - x) < 0.5) [(r 0) (r 2)]) ())]
 (doors-of lv) (: (place d) (: x (d 0) z (d 1) hs (map (r \ hits r x z) (lv 'rooms))
                                 zs (cats (map cap hs)) xs (cats (map caup hs))
                                 (? (#zs = 2) {'ax 'z 'c x 'a (min2 (zs 0) (zs 1)) 'b (max2 (zs 0) (zs 1)) 'w (d 2) 'h (d 3) 'y (d 4)}
                                    (#xs = 2) {'ax 'x 'c z 'a (min2 (xs 0) (xs 1)) 'b (max2 (xs 0) (xs 1)) 'w (d 2) 'h (d 3) 'y (d 4)}
                                    "a door must sit in the wall between two rooms: \('door . d)"))
   ps (map place (lv 'doors))
   (any string? ps ? <(filter string? ps) ps))
 ; ..from a file: the level, or why not
 (slurp-file p) (: q (open p "r") (hot? q ? (slurp q @ s (close q, s)) ()))
 (corridor-load p) (slurp-file p @ () ("cannot read " + p) s (corridor-read s))
 ; --- places: in a door's frame, along its wall, up, and across it ---
 (P ax al y ac) (ax = 'z ? [al y ac] [ac y al])
 (along ax) (ax @ 'z [1.0 0.0 0.0] [0.0 0.0 1.0])
 (across ax) (ax @ 'z [0.0 0.0 1.0] [1.0 0.0 0.0])
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
 (mag3 a) (sqrt (dot a a))
 (sheets o U V n uv tex col) (mesh-sheet o U V (max2 1 (int (mag3 U / cell + 0.5))) (max2 1 (int (mag3 V / cell + 0.5))) n uv tex col)
 (slab lo hi uv tex col) (: x0 (lo 0) y0 (lo 1) z0 (lo 2) x1 (hi 0) y1 (hi 1) z1 (hi 2)
   dx [(x1 - x0) 0.0 0.0] dy [0.0 (y1 - y0) 0.0] dz [0.0 0.0 (z1 - z0)]
   (mesh-join [(sheets lo dy dz [-1.0 0.0 0.0] uv tex col) (sheets [x1 y0 z0] dy dz [1.0 0.0 0.0] uv tex col)
               (sheets lo dx dz [0.0 -1.0 0.0] uv tex col) (sheets [x0 y1 z0] dx dz [0.0 1.0 0.0] uv tex col)
               (sheets lo dx dy [0.0 0.0 -1.0] uv tex col) (sheets [x0 y0 z1] dx dy [0.0 0.0 1.0] uv tex col)]))
 ; --- the world: the level's brushes in its order, and last each doorway carved through
 ;     its wall; the surfaces where air meets solid, textured by the way they face ---
 (brush-of r) (: sh (r 'shape)
   b0 (sh 'box @ () (: p (sh 'prism) (brush-prism (r 'air) (p 0) (p 1) (p 2))) bx (brush-box (r 'air) (bx 0) (bx 1)))
   (pin (foldl (\ b c (brush-cut b (c 0) (c 1) (c 2))) b0 (r 'cuts)) 'skin (r 'skin)))
 (doorway d) (: ax (d 'ax) p (P ax (d 'c - 0.5 * d 'w) (d 'y) (d 'a - 0.02)) q (P ax (d 'c + 0.5 * d 'w) (d 'y + d 'h) (d 'b + 0.02))
   (brush-box 1 [(min2 (p 0) (q 0)) (d 'y) (min2 (p 2) (q 2))] [(max2 (p 0) (q 0)) (d 'y + d 'h) (max2 (p 2) (q 2))]))
 (brushes-of lv) (map brush-of (lv 'brushes) + map doorway (lv 'doors))
 ; ..the texture on a face of brush b facing n, by its skin, and its texels at p: tt the
 ; textures, each [name w h metres]; a floor's and ceiling's laid from x 0 z 0, a wall's
 ; along it and its foot on the brush's
 (tix tt nm) (foldl (\ a i (tt i 0 = nm ? i a)) 0 ^#tt)
 (look tt) (\ n p b (: c (? (0.7 < n 1) 'floor (n 1 < -0.7) 'ceiling 'wall)
                       i (tix tt (skin-name (peep b 'skin ()) c)) t (tt i) k (t 1 / t 3)
                       (? (c = 'wall) (: d (unit [(0.0 - n 2) 0.0 (n 0)]) [i (k * dot p d) (t 2 - k * (p 1 - b 'lo 1))])
                          [i (k * p 0) (k * p 2)])))
 ; ..the door itself, shut: a slab of steel in the middle of the wall, the texture once
 ; across each face
 (door-mesh d tt) (: ax (d 'ax) m (0.5 * (d 'a + d 'b)) l0 (d 'c - 0.5 * d 'w) w (d 'w) h (d 'h)
   y0 (d 'y) p (P ax l0 y0 (m - door-t)) q (P ax (l0 + w) (y0 + h) (m + door-t)) i (tix tt 'door) t (tt i)
   (slab p q (s \ [(t 1 / w * ((s $ ax @ 'z 0 2) - l0)) (t 2 / h * (y0 + h - s 1))]) i white))
 ; --- the lights: {'lamps 'how 'shine 'glow} -- lamps summed as one channel, how it
 ;     behaves, and what shines and glows by it, [packed brightness] each ---
 (light ls how sh gl) {'lamps ls 'how how 'shine sh 'glow gl}
 (nub at s col) (slab (c+ at [(0.0 - s) (0.0 - s) (0.0 - s)]) (c+ at [s s s]) (_ \ [0.0 0.0]) -1 col)
 (strip-light lv s) (: x (s 'at 0) z (s 'at 1) r (room-at lv x z) h (s 'y) fl (r 5) ac (s 'across) k (inside r)
   (spot i) (: o (0.3 * i - 0.6) (ac ? [(x + o) (h - 0.06) z] [x (h - 0.06) (z + o)]))
   bar (ac ? (slab [(x - 0.6) (h - 0.05) (z - 0.08)] [(x + 0.6) h (z + 0.08)] (_ \ [0.0 0.0]) -1 white)
            (slab [(x - 0.08) (h - 0.05) (z - 0.6)] [(x + 0.08) h (z + 0.6)] (_ \ [0.0 0.0]) -1 white))
   ; ..a fitting as strong as its ceiling is high: the light on the floor the same
   g (max2 0.5 ((h - fl) / 2.6)) g2 (g * g)
   (light [{'at (map spot ^5) 'n [0.0 -1.0 0.0] 'c (c* g2 [2.3 2.4 2.6]) 'r (7.5 * g) 'keep k}
           {'at [[x (fl + 0.02) z]] 'n [0.0 1.0 0.0] 'c (c* g2 [1.1 1.1 1.15]) 'r (6.0 * g) 'soft g 'keep k}]
          (s 'how) [[(mesh-pack bar) 3.0]] ()))
 ; ..a bulb: its glass white-hot and tinted, a glow round it, its light soft on what is near
 (bulb-light lv b) (: p (b 'at) c (b 'c) r (room-at lv (p 0) (p 2)) top (max2 0.01 (max2 (c 0) (max2 (c 1) (c 2))))
   tint (c* (1.0 / top) c)
   (light [{'at [p] 'c c 'r 6.0 'soft 0.35 'keep (inside r)}] (b 'how)
          [[(mesh-pack (nub p 0.04 (cmix tint white 0.55))) 4.0]] [[(mesh-pack (halo-ball p 0.35 tint)) 0.9]]))
 ; ..a glow round p, r across: three discs crossed, bright in the middle and gone at the
 ; edge, each seen from both sides
 (halo-ball p r col) (: n 12 z [0.0 0.0 0.0]
   (vx q k) [(q 0) (q 1) (q 2) 0.0 0.0 0.0 0.0 0.0 (k 0) (k 1) (k 2)]
   (disc u v) (: rim (map (i \ (: a (2.0 * pi * i / n) (vx (c+ p (c+ (c* (r * cos a) u) (c* (r * sin a) v))) z))) ^n)
     (mesh (vx p col . rim) (cats (map (i \ (: a (1 + i) b (1 + (i + 1) % n) [[0 a b -1] [0 b a -1]])) ^n))))
   (mesh-join [(disc [1.0 0.0 0.0] [0.0 1.0 0.0]) (disc [0.0 1.0 0.0] [0.0 0.0 1.0]) (disc [1.0 0.0 0.0] [0.0 0.0 1.0])]))
 (sign-light lv s) (: a (s 'at) hg (hang lv (a 0) (a 1)) n (hg 1) rt (hg 2) h (a 3)
   w (h * (neon-strokes (s 'text) 1)) o (c+ (c+ (hg 0) [0.0 (a 2) 0.0]) (c* (-0.5 * w) rt))
   sg (neon-sign (s 'text) o rt [0.0 1.0 0.0] n h (c* 0.7 (s 'c)))
   (light [(pin (sg 'lamp) 'keep (inside (room-at lv (a 0) (a 1))))] (s 'how)
          [[(sg 'tube) 1.8]] [[(sg 'halo) 0.3]]))
 ; ..each door's lamps either side of it, red while it is shut and green once it opens
 (door-lights lv i d) (: ax (d 'ax) at (d 'c + 0.5 * d 'w + 0.25)
   (side ac off) (: p (P ax at (d 'y + 1.5) (ac + off)) k (inside (room-at lv (p 0) (p 2)))
     [(light [{'at [p] 'c [0.08 0.006 0.003] 'r 1.6 'soft 0.2 'keep k}] [['shut i]]
             [[(mesh-pack (nub p 0.035 [1.0 0.1 0.05])) 2.5]] ())
      (light [{'at [p] 'c [0.006 0.07 0.015] 'r 1.6 'soft 0.2 'keep k}] [['open i]]
             [[(mesh-pack (nub p 0.035 [0.1 1.0 0.25])) 2.5]] ())])
   (side (d 'a) -0.01 + side (d 'b) 0.01))
 (lights-of lv) (map (strip-light lv) (lv 'strips) + map (bulb-light lv) (lv 'bulbs)
                 + map (sign-light lv) (lv 'signs)
                 + cats (map (i \ door-lights lv i (lv 'doors i)) ^#(lv 'doors)))
 ; ..how bright a light is at mt seconds, the doors open by ds: steady; a strip failing,
 ; mostly on and now and then stammering off; a tube's buzz; a bulb breathing; a door's
 ; lamp by its door. sd keeps two failing lights out of step
 (stammer mt sd) (: s (int (mt * 12.0)) burst (throw (int (mt / 3.0)) sd 151 5 = 0)
   (burst && throw s (sd + 2) 157 3 != 0 ? (0.05 * throw s 3 163 4) (throw s (sd + 4) 167 90 = 0 ? 0.3 1.0)))
 (bright how mt sd ds) ((two? how ? <how 'steady) @
  'stammer (stammer mt sd)
  'buzz (0.93 + 0.07 * sin (mt * 53.0) * sin (mt * 7.0))
  'breathe (0.7 + 0.3 * sin (mt * 1.7 + sd))
  (a . u) (peep ds <u 0.0 @ d (a @ 'shut (d < 0.02 ? 1.0 0.0) (d < 0.02 ? 0.0 1.0)))
  1.0)
 (corridor-ks sc mt ds) (map (i \ bright (sc 'lights i 'how) mt i ds) ^#(sc 'lights))
 amb [0.025 0.025 0.03]
 ; --- the textures: the level's, then a grid for any of wall floor ceiling door it has
 ;     not, then the posters' ---
 grid-layers '((fill 0.55) (grid 16 16 1 0.47) (grid 64 64 1 0.35))
 (textures lv) (: ts (lv 'textures) have (map (t \ t 'name) ts)
   (ts + map (nm \ {'name nm 'w 64 'h 64 'm 1.0 'layers grid-layers}) (filter (nm \ !(elem nm have)) ['wall 'floor 'ceiling 'door])))
 ; ..a poster drawn: a navy field, a pale ring round a star of four points, a red band
 ; across, and ENLIST in the letters the neon bends; a pale edge
 (poster-art _) (: w 48 h 72 sk (neon-strokes "ENLIST") k (40.0 / sk 1)
   segs (catmap (: (go l) (two? >l ? ([<l <>l] . go >l)) go) (sk 0))
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
 (file-of dir p) (p 'file @ () () f (f 0 @ 47 f (dir + f)))
 ; --- the scene, built from a level: the meshes packed and each light's channel baked;
 ;     dir the level's folder, for its pictures ---
 (scene lv dir) (: ps (lv 'posters) ls (lights-of lv)
   txs (textures lv) tt (map (t \ [(t 'name) (t 'w) (t 'h) (t 'm)]) txs)
   ptex (map (p \ poster-tex (file-of dir p) (p 'at 3) (p 'at 4)) ps)
   pm (map (i \ poster-mesh lv (ps i) (#tt + i) (shape (ptex i 0) 1) (shape (ptex i 0) 0)) ^#ps)
   bs (brushes-of lv)
   hall (mesh-pack (mesh-join (brush-mesh bs cell (look tt) . pm)))
   drs (map (d \ mesh-pack (door-mesh d tt)) (lv 'doors))
   ; ..each light's channel; the steady ones summed once with the ambient, so a frame adds
   ; only the lights that change
   dyn (filter (i \ two? (ls i 'how)) ^#ls) still (filter (i \ atom? (ls i 'how)) ^#ls)
   (ch pk l) (foldl (a \ c+ a * mesh-lamp pk) [0.0 0.0 0.0] (l 'lamps))
   (lit pk) {'base (foldl (a \ c+ a * ch pk * ls) (c+ amb (c* 0.0 (pk 'cols 0 @ z [z z z]))) still)
             'chs (map (ch pk * ls) dyn)}
   {'hall hall 'hall-lit (lit hall) 'doors drs 'doors-lit (map lit drs) 'lights ls 'dyn dyn 'brushes bs
    'texs (map (t \ swatch (t 'w) (t 'h) (t 'layers)) txs + ptex)})
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
   dk (map (i \ ks i) (sc 'dyn))
   (relit pk l) (mesh-lamps! pk (l 'base) (l 'chs) dk 1.0)
   hall (relit (sc 'hall) (sc 'hall-lit))
   ; ..each door slid open along its wall into the wall's thickness
   doors (map (i \ (: pk (sc 'doors i) b (relit pk (sc 'doors-lit i)) d (lv 'doors i)
                      ix (iota (pk 'n) * 8 + (d 'ax = 'z ? 0 2))
                      [(pin (b 0) ix (pk 'cols (d 'ax = 'z ? 0 2) + ds i * (d 'w - 0.05))) (b 1)]))
              ^#(lv 'doors))
   ; ..what shines and glows, at each light's brightness; none where it is out
   (by key) (cats (map (i \ cats (map (q \ ((q 1 * ks i) @ 0.0 () b [(mesh-shine (q 0) b)])) (sc 'lights i key))) ^#ks))
   all ([hall] + doors + by 'shine + map mesh-glow (by 'glow))
   (mesh-frame v [(map (b \ b 0) all) (map (b \ b 1) all)] (sc 'texs) [0.0 0.0 0.0 30.0 60.0] 8 gain 0))
 ; ..a frame, and under it the bottom row's word: what a reload found wrong, or for a few
 ; seconds that it read the level again
 (corridor-frame st) (: w (st 'w) h (st 'h) k (peep st 'kp 1) f (corridor-pens st) r (h // 2)
   ; ..or, with p pressed, where the player stands and faces, as a level says it
   m (? (st 'err || !(peep st 'pos 0)) (st 'msg) (where st))
   say? (string? m && (st 'err || peep st 'pos 0 || st 'mt < st 'msg-t + 3.0))
   text (say? ? (snip (pad (" " + m) w " ") 0 w) "")
   (? (st 'kitty)
      (: n (peep st 'kn 0) _ (pin st 'kn (1 - n))
         (esc + "[?2026h" + mesh-kitty f (k * w) (k * h) w r (kitty-id + n) + mesh-kitty-del (kitty-id + 1 - n)
          + (say? ? (esc + "[" + show r + ";1H" + esc + (st 'err ? "[1;37;41m" "[0;37;40m") + text + esc + "[0m") "")
          + esc + "[?2026l"))
      (esc + "[?2026h" + mesh-cells f w h (st 'deep) (st 'deep ? 0 (st 'bay)) (say? ? (band st text r) {}) + esc + "[?2026l")))
 (where st) (: (r v) (show (int (v * 100.0 + (v < 0.0 ? -0.5 0.5)) / 100.0))
   deg (st 'th * 180.0 / pi @ d (d < 0.0 ? (d + 360.0) d))
   ("(" + r (st 'px) + " " + r (st 'py - eye-h) + " " + r (st 'pz) + ")  facing " + r deg + "  pitch " + r (st 'ph * 180.0 / pi)))
 ; ..as one of view's bands on row r: its cells, a character each, and its pens
 (band st s r) (: deep (st 'deep)
   (pen v) (deep ? (: (q x) ((x * 63 + 127) // 255) (q (v 0) * 4096 + q (v 1) * 64 + q (v 2))) (v 3))
   (cells s) (: (go i) (i < #s ? (: j (cite 'text 'cpnext s i) (snip s i j . go j)) ()) (go 0))
   {(r - 1) [0 (cells s) (pen [240 240 240 255]) (pen (st 'err ? [150 20 20 124] [20 20 20 233]))]})
 ; --- the state: the screen as view lays it, the level and its scene, where the player
 ;     stands and looks, the clock, the doors ---
 (corridor-new w h lv dir) (: s (lv 'start)
   (corridor-size {'px (s 'at 0) 'pz (s 'at 1) 'py (s 'y + eye-h) 'th (s 'deg * pi / 180.0) 'ph (s 'pitch * pi / 180.0) 't 0 'mt 0.0
                   'lvl lv 'sc (scene lv dir) 'dir dir 'doors (map (_ \ 0.0) (lv 'doors)) 'deep 0 'kitty 0 'kp 1
                   'done 0 'msg () 'msg-t 0.0 'err 0}
                  w (h // 2)))
 (corridor-size st w r) (: h (2 * r)
   (pins (view! st w h (h // 2)) 'bay (view-bayer w h) 'kp (st 'kitty ? (max2 1 (kitty-w // w)) 1)))
 ; --- moving: where the body's round, at its feet and at its head, is all air, and not
 ;     through a door that is not open ---
 (corridor-free? st x z) (: r body-r lv (st 'lvl) bs (st 'sc 'brushes)
   ring (map (k \ (: a (k * pi / 4.0) [(x + r * cos a) (z + r * sin a)])) ^8) pts ([x z] . ring)
   (shut? i) (: d (lv 'doors i) al (d 'ax = 'z ? x z) ac (d 'ax = 'z ? z x)
     (st 'doors i < 0.85 && mag (al - d 'c) < 0.5 * d 'w + r && d 'a - r < ac && ac < d 'b + r))
   fl (st 'py - eye-h)
   (all (q \ brush-medium bs [(q 0) (fl + 0.3) (q 1)] = 1 && brush-medium bs [(q 0) (fl + 1.7) (q 1)] = 1) pts
    && !(any shut? ^#(lv 'doors))))
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
        112 (pin st 'pos (1 - peep st 'pos 0))
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
 corridor-usage "usage: love lore corridor [--level FILE] [--kitty|--cells]   (h l turn, k j step, u n look, p where you stand; q or esc leaves; the level is read again when it changes)"
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
