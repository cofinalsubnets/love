; grove -- trees of heaven grown from a seed, and drawn. a scene gives a tree its habit, the
; shape of its wood, grown with grove's kit. the wood is a 'segs list of [a b r]; leaflets and
; seeds are points, each with its long axis and half-width as vectors. drawn in triangles
; (mesh.l): thick wood grove-wood under grove-bark, thin wood grove-twigs, points grove-dots.
; (grove-new p) grows one; p is a tablet:
;   'seed     the dice                         'base   [x 0 z], where it stands
;   'habit    kit -> the fork, the wood grown   'crown  the height leaves start at
;   'inside   p -> p, a point kept in bounds    'keep?  p -> 0 for a point not grown
; the kit is a tablet: 'rr lo hi a throw, 'spread d ang a way turned off d, 'dir a b,
; 'seg a b r a piece of wood, 'branch from way length pieces r0 r1 bend droop (its joints),
; 'head limb i0 n, 'spray q d len n lf, 'sprig q d, 'tuft q d
; the season rides on the tree, each 0..1: 'share of the crown in leaf (default 1), 'turn
; green to yellow, 'seeds of the clusters hanging, 'ripe green through red to tan
(module (grove grove-new grove-habit grove-bark grove-wood grove-dots grove-twigs)
(borrow '(view vec))
(borrow 'sky)                           ; the light a sky casts
(borrow 'mesh)                          ; the tubes
(:
 (rr g lo hi) (lo + (hi - lo) * rnd g)
 (num? v) (charm? v || gem? v)
 ; d turned off by ang toward a thrown bearing round it
 (spread g d ang) (turn d (turn (side d) d (rr g 0.0 tau)) ang)
 (grove-new p) (: g (rnd-new (p 'seed)) segs {'n 0} pts {'n 0}
   inside (peep p 'inside 1) keep? (peep p 'keep? 0) crown-y (peep p 'crown 0.0)
   ; ..the leaf and the fruit, as a species gives them: a number, or [lo hi] thrown
   lf (peep p 'leaf {}) lk (peep lf 'kind 'pinnate) fr (peep p 'fruit {})
   (lr t k lo hi) (peep t k () @ () (rr g lo hi) v (num? v ? (1.0 * v) (rr g (v 0) (v 1))))
   (lp k lo hi) (peep lf k () @ () (rr g lo hi) v (num? v ? (1.0 * v) (rr g (v 0) (v 1 + 0.99))))
   (seg! a b r) (pins segs (segs 'n) [a b r] 'n (segs 'n + 1))
   ; a point: its middle q, its long axis ax, its half-width sw, its kind (2 a leaflet, 3
   ; a seed), its shade, how yellow it turns, and its phase
   (pt! q ax sw k sh ye ph) (keep? q ? (: n (pts 'n) (pins pts n [q ax sw k sh ye ph] 'n (n + 1))))
   ; a branch from o along d, len long in k pieces, its radius r0 to r1, each piece bent by
   ; up to bend and dipped by droop: the joints, o first
   (branch! o d len k r0 r1 bend droop)
    (: (go i q dd acc) (i < k ? (: nd (unit (c+ (spread g dd (rr g 0.0 bend)) [0.0 -droop 0.0]))
                                    q2 (inside (c+ q (c* (len / k) nd)))
                                    _ (seg! q q2 (r0 + (r1 - r0) * i / (1.0 * k)))
                                    (go (i + 1) q2 nd (q2 . acc)))
                         (rev acc))
       (go 0 o d [o]))
   (dir a b) (unit (c+ b (c* -1.0 a)))
   ; a leaf of its kind, none below the crown
   (leaf! q d) (q 1 < crown-y ? () (lk @ 'simple (simple! q d) 'needle (needle! q d) 'blade (grass! q d) 'none () (pinnate! q d)))
   ; ..pinnate, or a frond: a stalk arching out of q along d and down, its leaflets in pairs,
   ; the middle ones the longest, and a third of the time one at its tip
   (pinnate! q d)
     (: rl (lr lf 'len 0.5 0.9) np (int (lp 'pairs 8.0 12.99)) rd (unit (c+ d [0.0 -0.3 0.0]))
        sv (side rd) nv (cross rd sv) sh (rr g 0.75 1.15) ye (2 (rnd g)) ph (rr g 0.0 tau) ll (lr lf 'leaflet 0.09 0.13)
        ar (0.0 - peep lf 'arch 0.25) wd (peep lf 'wide 0.2)
        (at u) (c+ q (c+ (c* (rl * u) rd) [0.0 (ar * rl * u * u) 0.0]))
        (blade c ax lw) (pt! c (c* lw ax) (c* (wd * lw) (unit (cross ax nv))) 2 sh ye ph)
        (each ^np (m \ (: u ((m + 0.7) / (np + 0.4)) lw (ll * (0.65 + 0.45 * sin (pi * (0.2 + 0.75 * u))))
                          (each [1.0 -1.0] (sg \ (: ax (unit (c+ (c* sg sv) (c* 0.4 rd)))
                                                    (blade (c+ (at u) (c* (0.5 * lw) ax)) ax lw)))))),
         rnd g < peep lf 'tip 0.33 ? (blade (c+ (at 1.0) (c* (0.5 * ll) rd)) rd (0.8 * ll))))
   ; ..one blade at c along ax, lw long and wd of that wide, facing off nv
   (blade! c ax lw wd nv sh ye ph) (pt! c (c* lw ax) (c* (wd * lw) (unit (cross ax nv))) 2 sh ye ph)
   ; ..simple: 'pairs blades, each on a short stalk fanned out of q round d
   (simple! q d) (: sh (rr g 0.75 1.15) ye (2 (rnd g)) ph (rr g 0.0 tau) n (int (lp 'pairs 1.0 1.99)) rd (unit (c+ d [0.0 -0.3 0.0]))
     (each ^n (i \ (: ax (n > 1 ? (spread g rd (rr g 0.3 1.1)) rd) sl (lr lf 'len 0.03 0.08) ll (lr lf 'leaflet 0.06 0.1)
                     (blade! (c+ q (c* (sl + 0.5 * ll) ax)) ax ll (peep lf 'wide 0.4) (cross ax (side ax)) sh ye ph)))))
   ; ..needles: a bundle fanned out of q round d
   (needle! q d) (: sh (rr g 0.75 1.15) ph (rr g 0.0 tau)
     (each ^(int (lp 'pairs 8.0 12.99)) (i \ (: ax (spread g d (rr g 0.2 1.0)) ll (lr lf 'leaflet 0.08 0.12)
                                              (blade! (c+ q (c* (0.5 * ll) ax)) ax ll (peep lf 'wide 0.05) (side ax) sh 0.0 ph)))))
   ; ..a grass blade: from q along d, bowing over as it goes and narrowing to its tip
   (grass! q d) (: L (lr lf 'len 0.25 0.5) k 4 bw (peep lf 'bow 0.6) sh (rr g 0.75 1.15) ye (2 (rnd g)) ph (rr g 0.0 tau)
     nv (cross d (side d)) wd (peep lf 'wide 0.15)
     (go i p) (i < k ? (: dd (unit (c+ d [0.0 (0.0 - bw * i / k) 0.0])) e (c+ p (c* (L / k) dd))
                         (blade! (lerp p e 0.5) dd (L / k) (wd * (1.0 - 0.6 * i / k)) nv sh ye ph, go (i + 1) e)))
     (go 0 q))
   ; a cluster of seeds hanging under q: a loose drooping head of winged seeds, each turned
   ; its own way
   (seeds! q) (: c (c+ q [0.0 (rr g -0.25 -0.15) 0.0]) ph (rr g 0.0 tau) n (int (lr fr 'n 25.0 45.0))
     (each ^n (i \ (: o [(rr g -0.11 0.11) (rr g -0.12 0.08) (rr g -0.11 0.11)]
                     ax (unit [(rr g -1.0 1.0) (rr g -1.0 0.3) (rr g -1.0 1.0)])
                     (pt! (c+ c o) (c* 0.035 ax) (c* 0.006 (side ax)) 3 (rr g 0.8 1.1) 0.0 ph)))))
   ; a spray: a crooked bare twig off q forking n times more, shorter each time, a tuft at
   ; one in lf of its ends; a sprig is one, bare, what a twig end shows in winter
   (spray! q d len n lf) (: sp (branch! q d len 2 (0.004 + 0.006 * n) (0.003 + 0.005 * n) 0.6 0.05)
     (n > 0 ? (each [1 2] (i \ (rnd g < 0.8 ? (spray! (sp i) (unit (c+ (spread g (dir (sp (i - 1)) (sp i)) (rr g 0.4 0.9)) [0.0 0.1 0.0]))
                                                       (len * rr g 0.5 0.75) (n - 1) lf))))
              (rnd g < lf ? (tuft! (sp 2) (dir (sp 1) (sp 2))))))
   (sprig! q d) (spray! q (unit (c+ (spread g d (rr g 0.5 1.2)) [0.0 0.2 0.0])) (rr g 0.4 0.9) 2 0.0)
   ; a twig end: a few short twigs, each with a leaf or three off its end; and on some, seeds
   (tuft! q d) (each ^(int (rr g 3.0 5.99))
                 (j \ (: td (unit (c+ (spread g d (rr g 0.3 1.0)) [0.0 0.15 0.0])) e (inside (c+ q (c* (rr g 0.12 0.35) td)))
                         (seg! q e 0.018,
                          each ^(int (rr g 2.0 4.99)) (i \ leaf! e (spread g td (rr g 0.2 1.0))),
                          rnd g < peep fr 'odds 0.3 ? (seeds! e)))))
   ; a head: a knot of short thick stubs at the end of a limb b, from its joint i0 on, and
   ; off each stub long thin twigs fanning out and up
   (head! b i0 n) (: k (#b - 1) ld (dir (b (k - 1)) (b k))
     (each ^n (j \ (: o (b (int (rr g (1.0 * i0) (k + 0.99)))) d (unit (c+ (spread g ld (rr g 0.6 1.5)) [0.0 0.15 0.0]))
                     st (branch! o d (rr g 0.3 0.8) 2 0.05 0.035 0.6 0.0) e (dir (st 1) (st 2))   ; a stub
                     (tuft! (st 2) e,
                      each ^(int (rr g 2.0 3.99)) (i \ spray! (st 2) (unit (c+ (spread g e (rr g 0.2 0.8)) [0.0 0.2 0.0])) (rr g 0.8 1.3) 2 0.55))))))   ; its twigs, a tuft at 0.55 of their ends
   ; the kit a scene's habit grows the wood with; the habit answers the fork
   kit {'rr (rr g) 'spread (spread g) 'dir dir 'seg seg! 'branch branch! 'head head! 'spray spray!
        'sprig sprig! 'tuft tuft! 'leaf leaf!}
   base (p 'base) fk ((p 'habit) kit)
   n (pts 'n) (fld k) (gem-tray [n] (map (i \ 1.0 * pts i k) ^n))
   (vec k j) (gem-tray [n] (map (i \ pts i k j) ^n))
   {'segs (map segs ^(segs 'n)) 'base base 'fork fk
    'x (vec 0 0) 'y (vec 0 1) 'z (vec 0 2) 'ax (vec 1 0) 'ay (vec 1 1) 'az (vec 1 2) 'sx (vec 2 0) 'sy (vec 2 1) 'sz (vec 2 2)
    'kind (fld 3) 'shade (fld 4) 'yel (fld 5) 'ph (fld 6)})
 ; a habit from a species as data: a trunk 'height tall in 'pieces, its top 'lean off the
 ; upright, its joints 'crook off the line, 'girth [foot top] thick; each of 'levels grows
 ; 'n limbs off the one before, 'along it, 'up and 'out, 'len long and shorter by 'cone
 ; toward its tip, 'pieces 'r 'bend 'droop as branch takes them, a 'head, 'twigs off each
 ; joint, 'leaves at each joint; 'ends at the last level's ends and each twig's; 'clump
 ; leaves 'splay-ed off the foot
 (grove-habit sp) (\ k (: rr (k 'rr) spread (k 'spread) dir (k 'dir) seg! (k 'seg) branch! (k 'branch) head! (k 'head) leaf! (k 'leaf)
   (th t q d) (peep t q d @ v (num? v ? (1.0 * v) (rr (v 0) (v 1))))
   (end! q d) (peep sp 'ends 'tuft @ 'tuft (k 'tuft q d) 'sprig (k 'sprig q d) 'spray (k 'spray q d (rr 0.8 1.3) 2 0.55) ())
   h (th sp 'height 0.0) hh (max h 0.05) tn (peep sp 'pieces 5) gr (peep sp 'girth [0.2 0.1]) cr (peep sp 'crook 0.0)
   b (rr 0.0 tau) ln (th sp 'lean 0.0) top [(ln * hh * cos b) hh (ln * hh * sin b)]
   tq (map (i \ (: p (c* (i / (1.0 * tn)) top) (0 < i < tn ? (c+ p [(rr (0.0 - cr) cr) 0.0 (rr (0.0 - cr) cr)]) p))) ^(tn + 1))
   _ (h > 0.05 ? (each ^tn (i \ seg! (tq i) (tq (i + 1)) (gr 0 + (gr 1 - gr 0) * i / tn))))
   ; ..a point t of the way along joints js, and the way they run there
   (on js t) (: m (#js - 1) x (t * m) i (min (m - 1) (int x)) [(lerp (js i) (js (i + 1)) (x - i)) (dir (js i) (js (i + 1)))])
   (grow js ls) (? (atom? ls) (end! (js (#js - 1)) (dir (js (#js - 2)) (js (#js - 1))))
     (: L <ls al (peep L 'along [0.5 1.0]) r (peep L 'r [0.05 0.02]) cn (peep L 'cone 0.0) hd (peep L 'head ()) tw (peep L 'twigs ())
        (each ^(int (th L 'n 3.0 + 0.5))
          (j \ (: t (rr (al 0) (al 1)) a (on js t)
                  d (unit (c+ (spread (a 1) (th L 'out 0.5 * 1.5708)) [0.0 (th L 'up 0.0) 0.0]))
                  bb (branch! (a 0) d (th L 'len 1.0 * (1.0 - cn * t)) (peep L 'pieces 4) (r 0) (r 1) (th L 'bend 0.3) (th L 'droop 0.0))
                  ((two? hd ? (head! bb 1 (int (rr (hd 0) (hd 1 + 0.99))))),
                   (each (drop 1 ^#bb) (i \ (: e (dir (bb (i - 1)) (bb i)) (each ^(int (th L 'leaves 0.0 + 0.5)) (_ \ leaf! (bb i) (spread e (rr 0.4 1.2))))))),
                   (two? tw ? (each (drop 2 ^#bb) (i \ (: e (dir (bb (i - 1)) (bb i))
                                                          tb (branch! (bb i) (unit (c+ (spread e (rr 0.5 1.1)) [0.0 -0.4 0.0])) (rr (tw 0) (tw 1)) 2 0.018 0.01 0.4 0.15)
                                                          (end! (tb 2) (dir (tb 1) (tb 2))))))),
                   grow bb >ls))))))
   cl (peep sp 'clump ()) lv (peep sp 'levels ())
   _ (two? cl ? (each ^(int (rr (cl 0) (cl 1) + 0.5)) (i \ leaf! [0.0 0.0 0.0] (spread [0.0 1.0 0.0] (rr 0.0 (peep sp 'splay 0.5))))))
   _ (two? lv ? (grow tq lv))
   (h > 0.05 ? (tq tn) [0.0 0.0 0.0])))
 ; which of the tree's points are on it: the leaves and the seeds the season has kept
 (in-leaf tr) (: q (tr 'ph / tau)
   ((tr 'kind = 2.0) * (q < peep tr 'share 1.0) + (tr 'kind = 3.0) * (q < peep tr 'seeds 0.0)))
 ; the bark, a texture a centimetre a texel, tiling round and along: dark, faintly mottled,
 ; thin pale streaks running down and fading; a share of the wood's own colour
 (grove-bark _) (: w 32 h 128
   (hash x k) (frac (sin (x * 12.9898 + k * 78.233) * 43758.5453))
   (mesh-pic w h (\ x y (: u (tau * x / w) v (tau * y / h)
                         mot (0.04 * sin (u * 2.0 + v * 3.0) * sin (v * 5.0 - u))
                         s0 (hash x 1) s1 (hash x 2) ln (8.0 + 50.0 * hash x 3)   ; a streak's column, top and run
                         dy (frac ((y - s1 * h) / h) * h)
                         st ((s0 < 0.12) * (dy < ln) * (1.0 - dy / ln))
                         k (0.72 + mot + 0.4 * st)
                         [k k (k * 1.01)]))))
 ; the wood as tubes, dark grey under their bark tex: the pieces thick enough to show as
 ; themselves, a mesh to pack and light as a scene's own (the thin ones are grove-twigs')
 thick 0.03
 (grove-wood tr tex) (mesh-join (map (s \ mesh-rod (s 0) (s 1) (s 2) [0.3 0.3 0.31] 8 tex 0.01) (filter (s \ thick <= s 2) (tr 'segs))))
 ; the leaflets and seeds as a scene draws them, where they are and their colours, kept on
 ; the tree for its season
 (laid tr) (: k [(peep tr 'share 1.0) (peep tr 'turn 0.0) (peep tr 'seeds 0.0) (peep tr 'ripe 0.0)] was (tr 'laid)
   (two? was && was 0 = k ? (was 1)
      (: ix (iota (in-leaf tr)) (fk q) (peep (tr q) ix 0.0)
         lf (fk 'kind = 2.0) ph (fk 'ph) sh (fk 'shade) yel (fk 'yel)
         ; ..a leaflet green, or yellow as far as the season has turned it, the yellower
         ; ones first; a seed green, then red, then the winter's tan
         gold (sat ((k 1 - 0.4 * (1.0 - yel)) / 0.6))
         leafc (cmix (c+ (c* sh [0.2 0.34 0.11]) (c* yel [0.12 0.12 -0.02])) (c* sh [0.6 0.52 0.14]) gold)
         r (k 3) seedc (c* sh (r < 0.5 ? (cmix [0.42 0.5 0.18] [0.62 0.3 0.2] (2.0 * r)) (cmix [0.62 0.3 0.2] [0.62 0.52 0.36] (2.0 * r - 1.0))))
         ; ..each a triangle pointed along its axis: its corners' places
         a [(fk 'ax) (fk 'ay) (fk 'az)] w [(fk 'sx) (fk 'sy) (fk 'sz)] P [(fk 'x) (fk 'y) (fk 'z)]
         l {'x (fk 'x) 'z (fk 'z) 'lf lf 'ph ph 'base (cmix seedc leafc lf)
            'cs [(map (k \ P k - 0.5 * a k - w k) ^3) (map (k \ P k - 0.5 * a k + w k) ^3) (map (k \ P k + 0.5 * a k) ^3)]}
         (pin tr 'laid [k l], l))))
 ; ..lit by sky's light lt seen from e, kept until the light or season moves or the eye goes
 ; a quarter metre; deep leaves darken, backlit ones glow. where a pixel spans pa and a leaflet
 ; is smaller, one in th is drawn, grown to stand for the rest
 (lit tr lt e pa) (: L0 (laid tr) (r v) (int (v * 100.0)) th (max 1 (min 3 (int (pa / 0.006))))
   k [(tr 'laid 0) (map r (lt 'sun)) (r (lt 'sunk)) (map r (lt 'amb)) (map r (lt 'sunc)) (map (v \ int (v * 4.0)) e) th]
   was (tr 'lit)
   (two? was && was 0 = k ? (was 1)
      (: ix (iota (iota #(L0 'lf) % th = 0)) (g t) (peep t ix 0.0) gs (sqrt (1.0 * th))
         m (map (j \ (g (L0 'cs 0 j) + g (L0 'cs 1 j) + g (L0 'cs 2 j)) / 3.0) ^3)
         L {'lf (g (L0 'lf)) 'base (map g (L0 'base)) 'ph (g (L0 'ph))
            'cs (map (c \ map (j \ m j + gs * (g (c j) - m j)) ^3) (L0 'cs))}
         s (lt 'sun) lf (L 'lf) base (L 'base) cs (L 'cs)
         qx (cs 2 0 - e 0) qy (cs 2 1 - e 1) qz (cs 2 2 - e 2) dist (sqrt (2 qx + 2 qy + 2 qz + 1e-9))
         glow (lf * 2 (sat (((qx * s 0 + qy * s 1 + qz * s 2) / dist - 0.2) / 0.8)))
         sky (cm base (c* 0.8 (lt 'amb)))
         sun (c* (lt 'sunk) (c+ (cm base (c* 0.6 (lt 'sunc))) (c* glow [0.45 0.55 0.12])))
         b [(mesh-dots cs sky sun -1) (L 'ph)]
         (pin tr 'lit [k b], b))))
 ; ..at the frame's clock t0: [verts tris], each swaying its own way, the lit ones moved
 (grove-dots tr lt e t0 pa) (: b (lit tr lt e pa) ph (b 1)
   dx (0.025 * sin (t0 * 0.13 + ph)) dz (0.02 * sin (t0 * 0.09 + ph * 1.7))
   [(b 0 0 + lace (catmap (q \ [dx 0.0 dz 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0]) ^3)) (b 0 1)])
 ; the thin wood: each piece a ribbon a to b turned to the eye at e, never narrower than a
 ; pixel (pa the angle one spans); [verts tris] for facets
 (grove-twigs tr lt e pa) (: T (tr 'thin @ ()
      (: sg (filter (s \ s 2 < thick) (tr 'segs)) n #sg (col i k) (gem-tray [n] (map (s \ 1.0 * s i k) sg))
         t {'a [(col 0 0) (col 0 1) (col 0 2)] 'b [(col 1 0) (col 1 1) (col 1 2)] 'r (gem-tray [n] (map (s \ s 2) sg))}
         (pin tr 'thin t, t)) t t)
   a (T 'a) b (T 'b) u [(b 0 - a 0) (b 1 - a 1) (b 2 - a 2)] v [(a 0 - e 0) (a 1 - e 1) (a 2 - e 2)]
   d (sqrt (2 (v 0) + 2 (v 1) + 2 (v 2))) hw (max (T 'r) (0.6 * pa * d))
   x [(u 1 * v 2 - u 2 * v 1) (u 2 * v 0 - u 0 * v 2) (u 0 * v 1 - u 1 * v 0)]
   k (hw / sqrt (2 (x 0) + 2 (x 1) + 2 (x 2) + 1e-12))
   col [0.22 0.22 0.23]
   (lo q i) (q i - k * x i) (hi q i) (q i + k * x i)
   (mesh-dots [(map (i \ lace [(lo a i) (lo a i)]) ^3) (map (i \ lace [(hi a i) (hi b i)]) ^3) (map (i \ lace [(hi b i) (lo b i)]) ^3)]
              (cm col (c* 0.9 (lt 'amb))) (cm col (c* (0.5 * lt 'sunk) (lt 'sunc))) -1)))
) ; module grove
