; scenery -- the words a level is written in. a level is a love file whose last form is
; (level NAME PART ..); every word below is a plain function, so a level can name
; things, compute them, and build them in loops. in metres: x east, y up, z north, every
; place a point [x y z], every colour (rgb r g b).
;
;   (level NAME PART ..)               the level; a part may be a list of parts. a macro
;                                      over (level-of NAME [PART ..])
;   (start [x y z] bearing pitch)      where the player stands, facing bearing degrees from
;                                      north toward east, looking pitch degrees up
;   (room [x y z] [x y z])             a box of air between two corners: floor, walls and
;                                      ceiling. two rooms a wall apart share it
;   (street [x y z] [x y z])           a room open to the sky: no ceiling, its walls standing
;                                      to its top, lit by the sun and the sky
;   (sky hour COVER)                   the level's sky at that hour of the day, COVER 'clear
;                                      'partly 'mostly or 'overcast; none, and no street is lit
;   (smog k)                           the sky and its light browned toward orange, k 0 to 1
;   (ambient (rgb r g b))              light everywhere under a roof at once, over the
;                                      corridor's own dim
;   (air SHAPE) (solid SHAPE)          a brush: space starts solid, air carves it and solid
;                                      fills it again, the later winning; a room is an air box
;     (box [x y z] [x y z])            ..a box between two corners
;     (prism height [[x y z] ..])      ..its floor plan going round, at the first point's height
;   (whole BRUSH)                      the brush never cut finer near a lamp: a small thing's
;                                      light as its corners have it
;   (cut [x y z] [x y z] [x y z] BRUSH)  the brush less what lies across the plane through
;                                      three points from its shape's middle, however many
;                                      cuts are on it: a slope, a bevel
;   (door [x y z] width height)        a sliding door in the wall between two rooms, the
;                                      middle of its foot at x y z
;   (train [x y z] [x y z] DOOR leave) a car on rails, its inside between two corners and a
;                                      (door ..) in a long wall: it opens as the level starts,
;                                      shuts once the player is out, and the car goes leave
;                                      metres along its length, the sign its way, and is gone
;   (bin [x y z] width depth height TEXTURE SIGN)  a rubbish bin standing at x y z: narrower
;                                      at its foot, its corners cut, capped, hollow up top and
;                                      open on every side there, SIGN () or a texture on each
;                                      side below; solid
;   (grav [x y z] [x y z] DIR)         a grav shaft: a column of air over the plan between the
;                                      corners, from the lower's floor to a room's height over
;                                      the upper's, motes of light streaming through it; who
;                                      stands in it is carried 'up to the upper floor or 'down
;                                      to the lower
;   (ball [x y z])                     a basketball standing at x y z, kicked by walking into it
;   (window [x y z] [x y z] TEXTURE)   an opening carved between two corners, a pane of glass
;                                      across its middle the thin way: what is beyond it
;                                      seen through the texture, the light on it; solid
;   (decal [x y z] [nx ny nz] [ux uy uz] width height TEXTURE)  a picture laid on a surface,
;                                      its middle at x y z, facing n, its top toward u; its
;                                      texture's holes show what is under it
;   (drape TEXTURE [[[x y z] ..] ..])  a sheet through rows of points, () a gap: each four
;                                      neighbours round two triangles, none by a gap; its
;                                      front up when the rows run toward z, their points toward x
;   (strip-light [x y z])              a light strip along z, its face at y
;   (bulb [x y z] (rgb r g b))         a bare bulb, its light
;   (sconce [x y z] [nx ny nz] [dx dy dz] length TEXTURE)  a lamp in a three-sided fitting on
;                                      the wall facing n: its lit face standing out from the
;                                      wall at x y z, looking d along it, length long across
;                                      both, and its back sloping from the face's outer edge
;                                      down to the wall; solid
;   (flames (rgb r g b) [[x y z] ..])  small flames, a candle's, standing at each point, all
;                                      one light between them
;   (poster [x y z] width height FILE) on the wall nearest, the middle of its foot at x y z;
;                                      a png's path from the level's folder, or () for the
;                                      corridor's own
;   (sign [x y z] height TEXT (rgb r g b))  a neon sign on the wall nearest
;   (neon [x y z] [nx ny nz] height TEXT (rgb r g b))  a neon sign whose foot's middle is at
;                                      x y z, facing n
;   (ad [x y z] [nx ny nz] [ux uy uz] width height TEXTURE)  a lit advertisement, laid as a
;                                      decal is, bright as its own light and lighting what
;                                      is before it in its colours
;   (spinner [x y z] width height TEXTURE TEXTURE)  a square of four lit advertisements
;                                      turning slowly about its middle at x y z, the two
;                                      textures in turn round it
;   (across LIGHT)                     a strip turned across, along x
;   (stammer LIGHT) (buzz LIGHT) (breathe LIGHT) (blink LIGHT)  a light failing, buzzing,
;                                      breathing, or flashing as a mast's beacon does
;   (texture width height metres LAYERS)  a texture, width by height texels and metres wide
;                                      on a surface, painted by its layers (swatch.l), quoted
;   (skin {'walls T 'floor T 'ceiling T 'all T} BRUSH)  the textures on a brush's faces, a
;                                      floor any face turned up and a ceiling down
;   (textures {'wall T 'floor T 'ceiling T 'door T 'train T})  the textures where no skin says
;   (laid TEXTURE degrees [du dv])     the texture as a skin or textures lays it, turned
;                                      degrees from u toward v and shifted du dv metres its
;                                      own way; a floor's u is x and v z, a wall's u along it
;                                      and v down
;   (repeat n [dx dy dz] PARTS)        the parts n times, each that far on from the last
;   (move [dx dy dz] PARTS)            the parts that far on
;   (mirror-x c PARTS) (mirror-z c PARTS)  the parts, and again reflected where x or z is c
;
; a word given what it does not take stops the level, saying what it takes.
(module (scenery level-of sourced start room street sky ambient air solid box prism cut whole door train bin decal drape window grav ball smog ad spinner neon strip-light bulb sconce flames poster sign
         across stammer buzz breathe blink texture laid skin textures repeat move mirror-x mirror-z rgb)
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
 ; ..the parts a form of the level's source made, each told where it stands there, path p
 ; down the source's forms; one told already by a form inside keeps that
 (sourced p x) (map (q \ peep q 'src () = () ? (with q 'src p) q) (flat x))
 (kind? p ks) (tablet? p && elem (peep p 'kind ()) ks)
 (rgb r g b) [(N r "(rgb r g b)") (N g "(rgb r g b)") (N b "(rgb r g b)")]
 (colour? c) (two? c && #c = 3 && all num? c)
 (start at deg pitch) (: u "(start [x y z] bearing pitch)" (part 'start [['at (P at u)] ['deg (N deg u)] ['pitch (N pitch u)]]))
 (room lo hi) (: u "(room [x y z] [x y z])" (part 'room [['lo (P lo u)] ['hi (P hi u)] ['skin {}]]))
 (street lo hi) (: u "(street [x y z] [x y z])" (part 'room [['lo (P lo u)] ['hi (P hi u)] ['skin {}] ['open 1]]))
 (sky hr cv) (: u "(sky hour COVER)" (? (!(charm? hr || gem? hr)) (no u hr) (!(elem cv ['clear 'partly 'mostly 'overcast])) (no u cv)
                                       (part 'sky [['hour (1.0 * hr)] ['cover cv]])))
 (smog k) (: u "(smog k)" ((charm? k || gem? k) && 0 <= k && k <= 1 ? (part 'smog [['k (1.0 * k)]]) (no u k)))
 (ambient c) (: u "(ambient (rgb r g b))" (colour? c ? (part 'ambient [['c c]]) (no u c)))
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
 ; ..a grav shaft: its column, a room, and which way it carries
 grav-head 3.0
 (grav lo hi dir) (: u "(grav [x y z] [x y z] DIR)" a (lo2 (P lo u) (P hi u)) b (hi2 (P lo u) (P hi u))
   (elem dir ['up 'down] ? [(room a [(b 0) (b 1 + grav-head) (b 2)]) (part 'grav [['lo a] ['hi b] ['dir dir]])] (no u dir)))
 (ball at) (: u "(ball [x y z])" (part 'ball [['at (P at u)]]))
 ; ..a window: its opening, and its pane
 (window lo hi t) (: u "(window [x y z] [x y z] TEXTURE)" a (P lo u) b (P hi u)
   (texture? t ? [(air (box a b)) (part 'pane [['lo (lo2 a b)] ['hi (hi2 a b)] ['tex t]])] (no u t)))
 ; ..a decal: its middle, and points a metre on along its facing and its up
 (decal at n up w h t) (: u "(decal [x y z] [nx ny nz] [ux uy uz] width height TEXTURE)" a (P at u) nn (P n u) uu (P up u)
   (texture? t ? (part 'decal [['at a] ['np (map (k \ a k + nn k) ^3)] ['up (map (k \ a k + uu k) ^3)] ['w (N w u)] ['h (N h u)] ['tex t]])
      (no u t)))
 (drape t rs) (: u "(drape TEXTURE [[[x y z] ..] ..])" (pg q) (q = () ? () (P q u))
   (? (!(texture? t)) (no u t) (!(two? rs && all two? rs && all (r \ #r = #<rs) rs)) (no u rs)
      (part 'drape [['tex t] ['rows (map (map pg) rs)]])))
 ; ..a bin: brushes, its body's sides and corners cut in toward its foot, hollow up top with an
 ; opening into it on each side, the band over those and a cap a little wider going in
 ; toward the top; its sign on each side
 (bin at w d h t sg) (: u "(bin [x y z] width depth height TEXTURE SIGN)" p (P at u) x (p 0) y (p 1) z (p 2)
   (? (!(texture? t)) (no u t) (!(sg = () || texture? sg)) (no u sg)
      (: dk (texture 8 8 1 '((fill 0.12) (noise 2 0.3)))
         W (0.5 * N w u) D (0.5 * N d u) H (N h u) k (0.12 * min2 W D) c (0.2 * min2 W D) y1 (y + H)
         i0 (y1 - 0.5 * H) i1 (y1 - 0.04) iw (W - 0.5 * k - 0.03) id (D - 0.5 * k - 0.03)
         o0 (y1 - 0.4 * H) o1 (y1 - 0.1 * H) sl (0.7 * W) sd (0.7 * D) tp (0.9 * k)
         (sx i) (i ? 1.0 -1.0)
         ; ..a solid from y0 to y1, w0 by d0 at its foot and w1 by d1 at its top, each side
         ; through both edges and each corner cut c off
         (taper y0 y1 w0 d0 w1 d1) (: m (max2 w0 w1) n (max2 d0 d1)
           sides [[[(x + w1) y1 (z - d1)] [(x + w1) y1 (z + d1)] [(x + w0) y0 (z - d0)]]
                  [[(x - w1) y1 (z - d1)] [(x - w1) y1 (z + d1)] [(x - w0) y0 (z - d0)]]
                  [[(x - w1) y1 (z + d1)] [(x + w1) y1 (z + d1)] [(x - w0) y0 (z + d0)]]
                  [[(x - w1) y1 (z - d1)] [(x + w1) y1 (z - d1)] [(x - w0) y0 (z - d0)]]]
           corners (map (i \ (: a (sx (i % 2)) b (sx (i // 2)) X (x + a * w1) Z (z + b * d1)
                                 [[(X - a * c) y1 Z] [X y1 (Z - b * c)] [(x + a * w0 - a * c) y0 (z + b * d0)]]))
                        ^4)
           (foldl (\ b q (cut (q 0) (q 1) (q 2) b)) (solid (box [(x - m) y0 (z - n)] [(x + m) y1 (z + n)])) (sides + corners)))
         body (taper y o1 (W - k) (D - k) W D)
         band (taper o1 y1 W D (W - tp) (D - tp))
         hollow [(box [(x - iw) i0 (z - id)] [(x + iw) i1 (z + id)])
                 (box [x o0 (z - sd)] [(x + W + 0.01) o1 (z + sd)]) (box [(x - W - 0.01) o0 (z - sd)] [x o1 (z + sd)])
                 (box [(x - sl) o0 z] [(x + sl) o1 (z + D + 0.01)]) (box [(x - sl) o0 (z - D - 0.01)] [(x + sl) o1 z])]
         ; ..the sign a third of the way up each side, a hair off it, leaning as it leans, as
         ; wide as the narrower side takes
         hb (o1 - y) ys (y + 0.33 * H) e ((1.0 - (ys - y) / hb) * k - 0.004) sz (min2 (0.42 * H) (1.3 * min2 W D)) L (sqrt (hb * hb + k * k))
         signs (sg = () ? ()
                  [(decal [(x + W - e) ys z] [(hb / L) (0.0 - k / L) 0.0] [(k / L) (hb / L) 0.0] sz sz sg)
                   (decal [(x - W + e) ys z] [(0.0 - hb / L) (0.0 - k / L) 0.0] [(0.0 - k / L) (hb / L) 0.0] sz sz sg)
                   (decal [x ys (z + D - e)] [0.0 (0.0 - k / L) (hb / L)] [0.0 (hb / L) (k / L)] sz sz sg)
                   (decal [x ys (z - D + e)] [0.0 (0.0 - k / L) (0.0 - hb / L)] [0.0 (hb / L) (0.0 - k / L)] sz sz sg)])
         ; ..small enough that its faces go uncut, lit at their corners
         [(map (b \ with b 'whole 1)
               ([(skin {'all t} body) (skin {'all t} band)] + map (b \ skin {'all dk} (air b)) hollow
                + [(skin {'all t} (taper y1 (y1 + 0.05) (W - tp + 0.02) (D - tp + 0.02) (W - tp - 0.01) (D - tp - 0.01)))]))
          signs])))
 (strip-light at) (part 'strip [['at (P at "(strip-light [x y z])")] ['across 0] ['how ()]])
 (bulb at c) (: u "(bulb [x y z] (rgb r g b))" (colour? c ? (part 'bulb [['at (P at u)] ['c c] ['how ()]]) (no u c)))
 ; ..a sconce: a box from a little inside the wall cut corner to corner, keeping the wall's
 ; side, and its lamp; n and d kept as points a metre on, as a decal's are
 sconce-d 0.25
 (sconce at n d len t) (: u "(sconce [x y z] [nx ny nz] [dx dy dz] length TEXTURE)" a (P at u) nv (P n u) dv (P d u) L (N len u) s sconce-d
   lv [(nv 1 * dv 2 - nv 2 * dv 1) (nv 2 * dv 0 - nv 0 * dv 2) (nv 0 * dv 1 - nv 1 * dv 0)]
   (pt kn kd kl) (map (i \ a i + kn * nv i + kd * dv i + kl * lv i) ^3)
   p0 (pt -0.05 (0.0 - s) (-0.5 * L)) p1 (pt s 0.0 (0.5 * L))
   (? (!(texture? t)) (no u t)
      [(whole (skin {'all t} (cut (pt s 0.0 0.0) (pt 0.0 (0.0 - s) 0.0) (pt s 0.0 1.0)
                              (solid (box (map (i \ min2 (p0 i) (p1 i)) ^3) (map (i \ max2 (p0 i) (p1 i)) ^3))))))
       (part 'sconce [['at a] ['np (map (i \ a i + nv i) ^3)] ['up (map (i \ a i + dv i) ^3)] ['len L] ['how ()]])]))
 (flames c ps) (: u "(flames (rgb r g b) [[x y z] ..])"
   (? (!(colour? c)) (no u c) (!(two? ps)) (no u ps)
      (part 'flame [['pts (map (p \ P p u) ps)] ['c c] ['how ()]])))
 (poster at w h file) (: u "(poster [x y z] width height FILE)"
   (string? file || file = () ? (part 'poster [['at (P at u)] ['w (N w u)] ['h (N h u)] ['file file]]) (no u file)))
 (sign at h text c) (: u "(sign [x y z] height TEXT (rgb r g b))"
   (? (!(string? text)) (no u text) (!(colour? c)) (no u c)
      (part 'sign [['at (P at u)] ['h (N h u)] ['text text] ['c c] ['how ()]])))
 (neon at n h text c) (: u "(neon [x y z] [nx ny nz] height TEXT (rgb r g b))"
   (? (!(string? text)) (no u text) (!(colour? c)) (no u c)
      (part 'sign [['at (P at u)] ['n (P n u)] ['h (N h u)] ['text text] ['c c] ['how ()]])))
 ; ..an advertisement: a decal that is its own light
 (ad at n up w h t) (: u "(ad [x y z] [nx ny nz] [ux uy uz] width height TEXTURE)"
   (decal at n up w h t @ d (tablet? d ? (pin d 'kind 'ad) (no u t))))
 (spinner at w h t1 t2) (: u "(spinner [x y z] width height TEXTURE TEXTURE)"
   (? (!(texture? t1)) (no u t1) (!(texture? t2)) (no u t2)
      (part 'spin [['at (P at u)] ['w (N w u)] ['h (N h u)] ['t1 t1] ['t2 t2]])))
 (across s) (kind? s ['strip] ? (with s 'across 1) (no "(across (strip-light ..))" s))
 (how w l) (kind? l ['strip 'bulb 'sconce 'sign 'flame] ? (with l 'how [w]) (no ("(" + show w + " LIGHT), a strip-light, bulb, sconce, sign or flames") l))
 (stammer l) (how 'stammer l)
 (buzz l) (how 'buzz l)
 (breathe l) (how 'breathe l)
 (blink l) (how 'blink l)
 ; a texture's recipe is checked here, so a bad layer stops the level at it
 (texture w h m ls) (: u "(texture width height metres LAYERS)"
   (? (!(charm? w && charm? h && 0 < w <= 512 && 0 < h <= 512)) (no u [w h])
      (!(num? m && m > 0)) (no u m)
      (swatch-fault ls @ () {'kind 'texture 'w w 'h h 'm (f m) 'layers ls}
                         e (scare 'level ("in a texture, " + show (e 0) + " -- it reads " + e 1)))))
 (texture? t) (kind? t ['texture])
 (laid t deg off) (: u "(laid TEXTURE degrees [du dv])"
   (? (!(texture? t)) (no u t) (!(num? deg)) (no u deg) (!(two? off && #off = 2 && all num? off)) (no u off)
      {'kind 'laid 'tex t 'deg (f deg) 'off (map f off)}))
 ; ..what a skin takes: a texture, or one laid; its texture, and how it is laid if it is
 (surface? t) (texture? t || kind? t ['laid])
 (bare t) (kind? t ['laid] ? (t 'tex) t)
 (lay t) (kind? t ['laid] ? [[(t 'deg) (t 'off)]] ())
 (whole b) (brush? b ? (with b 'whole 1) (no "(whole BRUSH)" b))
 (skin s b) (: u "(skin {'walls T 'floor T 'ceiling T 'all T} BRUSH)"
   (? (!(brush? b)) (no u b) (!(tablet? s)) (no u s)
      (any (k \ !(elem k ['walls 'floor 'ceiling 'all]) || !(surface? (s k))) (keys s)) (no u s)
      (with b 'skin s)))
 (textures s) (: u "(textures {'wall T 'floor T 'ceiling T 'door T 'train T})"
   (tablet? s && all (k \ elem k ['wall 'floor 'ceiling 'door 'train] && surface? (s k)) (keys s) ? (part 'textures [['set s]]) (no u s)))
 ; --- repeat and mirror: copies with every point moved, and a start's bearing turned ---
 (flat x) (? (tablet? x) [x] (atom? x) () (cats (map flat x)))
 (re g b p) (: q (foldl (\ q k (with q k (g (p k)))) p (filter (k \ elem k (keys p)) ['at 'lo 'hi 'np 'up]))
   q2 (elem 'pts (keys q) ? (with q 'pts (map g (q 'pts))) q)
   q3 (elem 'cuts (keys q2) ? (with q2 'cuts (map (c \ map g c) (q2 'cuts))) q2)
   q4 (elem 'door (keys q3) ? (with q3 'door (re g b (q3 'door))) q3)
   q5 (elem 'rows (keys q4) ? (with q4 'rows (map (map (p \ p = () ? () (g p))) (q4 'rows))) q4)
   (elem 'deg (keys q5) ? (with q5 'deg (b (q5 'deg))) q5))
 (repeat n d ps) (: u "(repeat n [dx dy dz] PARTS)" dd (P d u)
   (charm? n ? (cats (map (i \ map (re (p \ [(p 0 + i * dd 0) (p 1 + i * dd 1) (p 2 + i * dd 2)]) (b \ b)) (flat ps)) ^n)) (no u n)))
 (move d ps) (: u "(move [dx dy dz] PARTS)" dd (P d u) (map (re (p \ [(p 0 + dd 0) (p 1 + dd 1) (p 2 + dd 2)]) (b \ b)) (flat ps)))
 ; ..a mirror turns a drape over, so its rows run back to keep its front
 (flip p) (kind? p ['drape] ? (with p 'rows (map rev (p 'rows))) p)
 (mirror-x c ps) (: x (N c "(mirror-x c PARTS)") l (flat ps) (l + map (flip * re (p \ [(2.0 * x - p 0) (p 1) (p 2)]) (b \ 0.0 - b)) l))
 (mirror-z c ps) (: z (N c "(mirror-z c PARTS)") l (flat ps) (l + map (flip * re (p \ [(p 0) (p 1) (2.0 * z - p 2)]) (b \ 180.0 - b)) l))
 ; --- the level: its parts sorted into what the corridor builds from ---
 (lo2 a b) (map (k \ min2 (a k) (b k)) ^3)
 (hi2 a b) (map (k \ max2 (a k) (b k)) ^3)
 (shape-of b) (? (b 'kind = 'prism) (: y0 (b 'pts 0 1) {'prism [y0 (y0 + b 'h) (map (p \ [(p 0) (p 2)]) (b 'pts))]})
                 {'box [(lo2 (b 'lo) (b 'hi)) (hi2 (b 'lo) (b 'hi))]})
 ; textures named: the defaults by their place, every other by its number
 (level-of name ps) (: l (flat ps) bad (filter (p \ !(tablet? p) || !(brush? p || elem (peep p 'kind ()) ['start 'door 'car 'strip 'bulb 'sconce 'flame 'poster 'sign 'decal 'drape 'pane 'grav 'ball 'sky 'smog 'ambient 'ad 'spin 'textures])) l)
   (of k) (filter (p \ p 'kind = k) l)
   bs (filter brush? l)
   dflt (foldl (\ t p (foldl (\ t k (pin t k (p 'set k))) t (keys (p 'set)))) {} (of 'textures))
   used (foldl (\ a t (elem t a ? a (a + [t]))) () (cats (map (b \ map (k \ bare (b 'skin k)) (sort (keys (b 'skin)))) bs)
                                                     + map (d \ d 'tex) (of 'decal + of 'drape + of 'pane + of 'ad)
                                                     + cats (map (s \ [(s 't1) (s 't2)]) (of 'spin))))
   (tname t) (foldl (\ a i (used i = t ? i a)) () ^#used)
   (skin-of b) (: s (b 'skin) (cats (map (k \ (: (e c) ([c (tname (bare (s k)))] + lay (s k)) (k = 'all ? (map e ['wall 'floor 'ceiling]) [(e (k = 'walls ? 'wall k))])))
                                       (filter (k \ elem k (keys s)) ['all 'walls 'floor 'ceiling]))))
   (tex nm t) (: b (bare t) {'name nm 'w (b 'w) 'h (b 'h) 'm (b 'm) 'layers (b 'layers) 'lay (kind? t ['laid] ? [(t 'deg) (t 'off)] ())})
   (? (!(string? name)) (no "(level NAME PART ..)" name)
      (two? bad) (scare 'level ("not a part: " + show <bad))
      {'kind 'level 'name name
       'start (of 'start @ () {'at [0.0 0.0] 'y 0.0 'deg 0.0 'pitch 0.0}
                          s (: a (<s 'at) {'at [(a 0) (a 2)] 'y (a 1) 'deg (<s 'deg) 'pitch (<s 'pitch)}))
       'rooms (map (r \ (: a (lo2 (r 'lo) (r 'hi)) b (hi2 (r 'lo) (r 'hi)) [(a 0) (a 2) (b 0) (b 2) (b 1) (a 1)])) (of 'room))
       'brushes (map (b \ {'air (b 'kind = 'room ? 1 (b 'air)) 'shape (shape-of b) 'cuts (b 'cuts) 'skin (skin-of b) 'whole (peep b 'whole 0) 'open (peep b 'open 0) 'src (peep b 'src ())}) bs)
       'doors (map (d \ (: a (d 'at) [(a 0) (a 2) (d 'w) (d 'h) (a 1)])) (of 'door))
       'cars (map (c \ (: a (c 'door 'at) {'lo (lo2 (c 'lo) (c 'hi)) 'hi (hi2 (c 'lo) (c 'hi))
                                           'door [(a 0) (a 2) (c 'door 'w) (c 'door 'h) (a 1)] 'leave (c 'leave)})) (of 'car))
       'strips (map (s \ (: a (s 'at) {'at [(a 0) (a 2)] 'y (a 1) 'across (s 'across) 'how (s 'how)})) (of 'strip))
       'bulbs (map (b \ {'at (b 'at) 'c (b 'c) 'how (b 'how)}) (of 'bulb))
       'sconces (map (q \ {'at (q 'at) 'np (q 'np) 'up (q 'up) 'len (q 'len) 'how (q 'how)}) (of 'sconce))
       'flames (map (q \ {'pts (q 'pts) 'c (q 'c) 'how (q 'how)}) (of 'flame))
       'posters (map (p \ (: a (p 'at) {'at [(a 0) (a 2) (a 1) (p 'w) (p 'h)] 'file (p 'file)})) (of 'poster))
       'gravs (map (g \ {'lo (g 'lo) 'hi (g 'hi) 'dir (g 'dir)}) (of 'grav))
       'balls (map (b \ b 'at) (of 'ball))
       'ambient (of 'ambient @ () [0.0 0.0 0.0] a (<a 'c))
       'sky (of 'sky @ () () s {'hour (<s 'hour) 'cover (<s 'cover) 'smog (of 'smog @ () 0.0 m (<m 'k))})
       'panes (map (p \ {'lo (p 'lo) 'hi (p 'hi) 'tex (tname (p 'tex))}) (of 'pane))
       'decals (map (d \ {'at (d 'at) 'np (d 'np) 'up (d 'up) 'w (d 'w) 'h (d 'h) 'tex (tname (d 'tex))}) (of 'decal))
       'drapes (map (d \ {'rows (d 'rows) 'tex (tname (d 'tex))}) (of 'drape))
       'ads (map (d \ {'at (d 'at) 'np (d 'np) 'up (d 'up) 'w (d 'w) 'h (d 'h) 'tex (tname (d 'tex))}) (of 'ad))
       'spins (map (s \ {'at (s 'at) 'w (s 'w) 'h (s 'h) 't1 (tname (s 't1)) 't2 (tname (s 't2))}) (of 'spin))
       'signs (map (s \ (: a (s 'at) {'at [(a 0) (a 2) (a 1) (s 'h)] 'n (peep s 'n ()) 'text (s 'text) 'c (s 'c) 'how (s 'how)})) (of 'sign))
       'textures (map (k \ tex k (dflt k)) (filter (k \ elem k (keys dflt)) ['wall 'floor 'ceiling 'door 'train])
                  + map (i \ tex (tname (used i)) (used i)) ^#used)})))
(:: 'level (\ l ['level-of <l ('list . >l)]))
) ; module scenery
