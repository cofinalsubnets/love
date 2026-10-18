; scenery -- the words a level is written in: a love file whose last form is (level NAME
; PART ..), every word a plain function. metres, x east, y up, z north; points [x y z].
;   (level NAME PART ..)          a part may be a list of parts; a macro over level-of
;   (start [x y z] bearing pitch) bearing degrees from north toward east, pitch up
;   (room [x y z] [x y z])        a box of air; two rooms a wall apart share it
;   (air SHAPE) (solid SHAPE)     brushes: space starts solid, the later winning
;     (box [x y z] [x y z])  (prism height [[x y z] ..])  a floor plan going round
;   (cut [x y z] [x y z] [x y z] BRUSH)  less what lies across the plane, from its middle
;   (door [x y z] width height)   sliding, in the wall between two rooms, its foot's middle
;   (train [x y z] [x y z] DOOR leave)  a car whose door opens at the start and shuts once
;                                 the player is out; it goes leave metres, the sign its way
;   (strip-light [x y z])  (bulb [x y z] (rgb r g b))  (across LIGHT) a strip along x
;   (poster [x y z] width height FILE)  on the nearest wall; FILE () the corridor's own
;   (sign [x y z] height TEXT (rgb r g b))  neon, on the nearest wall
;   (stammer LIGHT) (buzz LIGHT) (breathe LIGHT)
;   (texture width height metres LAYERS)  texels, metres wide on a surface, layers quoted
;   (skin {'walls T 'floor T 'ceiling T 'all T} BRUSH)  a floor any face turned up
;   (textures {'wall T 'floor T 'ceiling T 'door T 'train T})  where no skin says
;   (repeat n [dx dy dz] PARTS)  (mirror-x c PARTS) (mirror-z c PARTS)
; a word given what it does not take stops the level, saying what it takes.
(module (scenery level-of start room air solid box prism cut door train strip-light bulb poster sign
         across stammer buzz breathe texture skin textures repeat mirror-x mirror-z rgb)
(borrow 'view)
(borrow 'swatch)
(:
 (num? v) (charm? v || gem? v)
 (f v) (1.0 * v)
 (pt? q) (two? q && #q = 3 && all num? q)
 (no what got) (scare 'level (what + " -- not " + show got))
 (P q what) (pt? q ? (map f q) (no what q))
 (N v what) (num? v ? (f v) (no what v))
 ; a part: a tablet of its kind and fields; with, a copy changed
 (part k l) (foldl (\ t kv (pin t (kv 0) (kv 1))) {'kind k} l)
 (with p k v) (pin (foldl (\ t q (pin t q (p q))) {} (keys p)) k v)
 (kind? p ks) (tablet? p && elem (peep p 'kind ()) ks)
 (rgb r g b) [(N r "(rgb r g b)") (N g "(rgb r g b)") (N b "(rgb r g b)")]
 (colour? c) (two? c && #c = 3 && all num? c)
 (start at deg pitch) (: u "(start [x y z] bearing pitch)" (part 'start [['at (P at u)] ['deg (N deg u)] ['pitch (N pitch u)]]))
 (room lo hi) (: u "(room [x y z] [x y z])" (part 'room [['lo (P lo u)] ['hi (P hi u)] ['skin {}]]))
 ; a brush's shape; air and solid make it a brush
 (box lo hi) (: u "(box [x y z] [x y z])" (part 'box [['lo (P lo u)] ['hi (P hi u)]]))
 (prism h ps) (: u "(prism height [[x y z] ..])"
   (two? ps && #ps >= 3 ? (part 'prism [['h (N h u)] ['pts (map (q \ P q u) ps)]]) (no u ps)))
 (brush a sh) (kind? sh ['box 'prism] && !(elem 'air (keys sh)) ? (with (with (with sh 'air a) 'cuts ()) 'skin {}) (no "(air SHAPE) or (solid SHAPE), a SHAPE (box ..) or (prism ..)" sh))
 (air sh) (brush 1 sh)
 (solid sh) (brush 0 sh)
 (brush? b) (kind? b ['room] || (kind? b ['box 'prism] && elem 'air (keys b)))
 (cut p q r b) (: u "(cut [x y z] [x y z] [x y z] BRUSH)"
   (? (!(brush? b)) (no u b) (with b 'cuts (b 'cuts + [[(P p u) (P q u) (P r u)]]))))
 (door at w h) (: u "(door [x y z] width height)" (part 'door [['at (P at u)] ['w (N w u)] ['h (N h u)]]))
 (train lo hi d leave) (: u "(train [x y z] [x y z] (door [x y z] width height) leave)"
   (kind? d ['door] ? (part 'car [['lo (P lo u)] ['hi (P hi u)] ['door d] ['leave (N leave u)]]) (no u d)))
 (strip-light at) (part 'strip [['at (P at "(strip-light [x y z])")] ['across 0] ['how ()]])
 (bulb at c) (: u "(bulb [x y z] (rgb r g b))" (colour? c ? (part 'bulb [['at (P at u)] ['c c] ['how ()]]) (no u c)))
 (poster at w h file) (: u "(poster [x y z] width height FILE)"
   (string? file || file = () ? (part 'poster [['at (P at u)] ['w (N w u)] ['h (N h u)] ['file file]]) (no u file)))
 (sign at h text c) (: u "(sign [x y z] height TEXT (rgb r g b))"
   (? (!(string? text)) (no u text) (!(colour? c)) (no u c)
      (part 'sign [['at (P at u)] ['h (N h u)] ['text text] ['c c] ['how ()]])))
 (across s) (kind? s ['strip] ? (with s 'across 1) (no "(across (strip-light ..))" s))
 (how w l) (kind? l ['strip 'bulb 'sign] ? (with l 'how [w]) (no ("(" + show w + " LIGHT), a strip-light, bulb or sign") l))
 (stammer l) (how 'stammer l)
 (buzz l) (how 'buzz l)
 (breathe l) (how 'breathe l)
 ; a texture's recipe is checked here, so a bad layer stops the level at it
 (texture w h m ls) (: u "(texture width height metres LAYERS)"
   (? (!(charm? w && charm? h && 0 < w <= 512 && 0 < h <= 512)) (no u [w h])
      (!(num? m && m > 0)) (no u m)
      (swatch-fault ls @ () {'kind 'texture 'w w 'h h 'm (f m) 'layers ls}
                         e (scare 'level ("in a texture, " + show (e 0) + " -- it reads " + e 1)))))
 (texture? t) (kind? t ['texture])
 (skin s b) (: u "(skin {'walls T 'floor T 'ceiling T 'all T} BRUSH)"
   (? (!(brush? b)) (no u b) (!(tablet? s)) (no u s)
      (any (k \ !(elem k ['walls 'floor 'ceiling 'all]) || !(texture? (s k))) (keys s)) (no u s)
      (with b 'skin s)))
 (textures s) (: u "(textures {'wall T 'floor T 'ceiling T 'door T 'train T})"
   (tablet? s && all (k \ elem k ['wall 'floor 'ceiling 'door 'train] && texture? (s k)) (keys s) ? (part 'textures [['set s]]) (no u s)))
 ; --- repeat and mirror: copies with every point moved, and a start's bearing turned ---
 (flat x) (? (tablet? x) [x] (atom? x) () (cats (map flat x)))
 (re g b p) (: q (foldl (\ q k (with q k (g (p k)))) p (filter (k \ elem k (keys p)) ['at 'lo 'hi]))
   q2 (elem 'pts (keys q) ? (with q 'pts (map g (q 'pts))) q)
   q3 (elem 'cuts (keys q2) ? (with q2 'cuts (map (c \ map g c) (q2 'cuts))) q2)
   q4 (elem 'door (keys q3) ? (with q3 'door (re g b (q3 'door))) q3)
   (elem 'deg (keys q4) ? (with q4 'deg (b (q4 'deg))) q4))
 (repeat n d ps) (: u "(repeat n [dx dy dz] PARTS)" dd (P d u)
   (charm? n ? (cats (map (i \ map (re (p \ [(p 0 + i * dd 0) (p 1 + i * dd 1) (p 2 + i * dd 2)]) (b \ b)) (flat ps)) ^n)) (no u n)))
 (mirror-x c ps) (: x (N c "(mirror-x c PARTS)") l (flat ps) (l + map (re (p \ [(2.0 * x - p 0) (p 1) (p 2)]) (b \ 0.0 - b)) l))
 (mirror-z c ps) (: z (N c "(mirror-z c PARTS)") l (flat ps) (l + map (re (p \ [(p 0) (p 1) (2.0 * z - p 2)]) (b \ 180.0 - b)) l))
 ; --- the level: its parts sorted into what the corridor builds from ---
 (lo2 a b) (map (k \ min2 (a k) (b k)) ^3)
 (hi2 a b) (map (k \ max2 (a k) (b k)) ^3)
 (shape-of b) (? (b 'kind = 'prism) (: y0 (b 'pts 0 1) {'prism [y0 (y0 + b 'h) (map (p \ [(p 0) (p 2)]) (b 'pts))]})
                 {'box [(lo2 (b 'lo) (b 'hi)) (hi2 (b 'lo) (b 'hi))]})
 ; textures named: the defaults by their place, every other by its number
 (level-of name ps) (: l (flat ps) bad (filter (p \ !(tablet? p) || !(brush? p || elem (peep p 'kind ()) ['start 'door 'car 'strip 'bulb 'poster 'sign 'textures])) l)
   (of k) (filter (p \ p 'kind = k) l)
   bs (filter brush? l)
   dflt (foldl (\ t p (foldl (\ t k (pin t k (p 'set k))) t (keys (p 'set)))) {} (of 'textures))
   used (foldl (\ a t (elem t a ? a (a + [t]))) () (cats (map (b \ map (k \ b 'skin k) (sort (keys (b 'skin)))) bs)))
   (tname t) (foldl (\ a i (used i = t ? i a)) () ^#used)
   (skin-of b) (: s (b 'skin) (cats (map (k \ (k = 'all ? (map (c \ [c (tname (s k))]) ['wall 'floor 'ceiling])
                                                 [[(k = 'walls ? 'wall k) (tname (s k))]]))
                                       (filter (k \ elem k (keys s)) ['all 'walls 'floor 'ceiling]))))
   (tex nm t) {'name nm 'w (t 'w) 'h (t 'h) 'm (t 'm) 'layers (t 'layers)}
   (? (!(string? name)) (no "(level NAME PART ..)" name)
      (two? bad) (scare 'level ("not a part: " + show <bad))
      {'kind 'level 'name name
       'start (of 'start @ () {'at [0.0 0.0] 'y 0.0 'deg 0.0 'pitch 0.0}
                          s (: a (<s 'at) {'at [(a 0) (a 2)] 'y (a 1) 'deg (<s 'deg) 'pitch (<s 'pitch)}))
       'rooms (map (r \ (: a (lo2 (r 'lo) (r 'hi)) b (hi2 (r 'lo) (r 'hi)) [(a 0) (a 2) (b 0) (b 2) (b 1) (a 1)])) (of 'room))
       'brushes (map (b \ {'air (b 'kind = 'room ? 1 (b 'air)) 'shape (shape-of b) 'cuts (b 'cuts) 'skin (skin-of b)}) bs)
       'doors (map (d \ (: a (d 'at) [(a 0) (a 2) (d 'w) (d 'h) (a 1)])) (of 'door))
       'cars (map (c \ (: a (c 'door 'at) {'lo (lo2 (c 'lo) (c 'hi)) 'hi (hi2 (c 'lo) (c 'hi))
                                           'door [(a 0) (a 2) (c 'door 'w) (c 'door 'h) (a 1)] 'leave (c 'leave)})) (of 'car))
       'strips (map (s \ (: a (s 'at) {'at [(a 0) (a 2)] 'y (a 1) 'across (s 'across) 'how (s 'how)})) (of 'strip))
       'bulbs (map (b \ {'at (b 'at) 'c (b 'c) 'how (b 'how)}) (of 'bulb))
       'posters (map (p \ (: a (p 'at) {'at [(a 0) (a 2) (a 1) (p 'w) (p 'h)] 'file (p 'file)})) (of 'poster))
       'signs (map (s \ (: a (s 'at) {'at [(a 0) (a 2) (a 1) (s 'h)] 'text (s 'text) 'c (s 'c) 'how (s 'how)})) (of 'sign))
       'textures (map (k \ tex k (dflt k)) (filter (k \ elem k (keys dflt)) ['wall 'floor 'ceiling 'door 'train])
                  + map (i \ tex (tname (used i)) (used i)) ^#used)})))
(:: 'level (\ l ['level-of <l ('list . >l)]))
) ; module scenery
