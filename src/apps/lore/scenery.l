; scenery -- the words a level is written in. a level is a love file whose last form is
; (level NAME PART ..); every word below is a plain function, so a level can name
; things, compute them, and build them in loops. in metres: x east, y up, z north, every
; place a point [x y z], every colour (rgb r g b).
;
;   (level NAME PART ..)               the level; a part may be a list of parts. a macro
;                                      over (level-of NAME [PART ..])
;   (start [x y z] bearing pitch)      where the player stands, facing bearing degrees from
;                                      north toward east, looking pitch degrees up
;   (entry NAME [x y z] bearing pitch)  another way into the level, as the start but named,
;                                      for another level's way out to arrive by
;   (shot seconds [x y z] bearing pitch)  before the start, the level seen from there for
;                                      seconds, the shots in their order; a key skips them
;   (shot seconds (sky hour COVER) bearing pitch)  ..or that sky alone, nothing under it
;   (room [x y z] [x y z])             a box of air between two corners: floor, walls and
;                                      ceiling. two rooms a wall apart share it
;   (street [x y z] [x y z])           a room open to the sky: no ceiling, its walls standing
;                                      to its top, lit by the sun and the sky
;   (void [x y z] [x y z])             a street with no walls to see, the sky past its edge:
;                                      the edge stops a body all the same, and rings when
;                                      walked into
;   (gravity [[y g] ..])               how hard the level pulls at each height, metres a
;                                      second a second, straight between them and held past
;                                      the ends; none, and 9.8 everywhere
;   (surface 'torus lx lz)            the level laid round a ring's tube instead of flat: x
;                                      along the ring, z round the tube from its inside, its
;                                      outside at half lz, each wrapping at
;                                      lx and lz back to 0, y up off it, a body pulled down
;                                      toward the tube's core. lx and lz are the lengths
;                                      round the ring's middle and round the tube; nothing
;                                      should straddle where x or z wraps
;   (surface 'plane lx lz)             ..or flat, wrapping the same way
;   (pocket [x z] PARTS)               the parts laid flat in the world, standing straight up
;                                      off the surface from x z and never bent round it, their
;                                      x y z the level's own as though it were flat there; on
;                                      a torus straight up off its inside reaches the ring's
;                                      middle. one to a level on a surface; an orb glowing in
;                                      it lights nothing round it
;   (lift [x y z] width rise TEXTURE)  a platform width square, the middle of its top at x y z,
;                                      on a pad, railed toward z and gated toward x and away, the
;                                      gates swinging out: its
;                                      switch on the post up its middle tapped from on it, the
;                                      gates swing shut and it is carried rise metres up, or back
;                                      down. one at the foot of a pocket is stepped onto off the
;                                      surface
;   (tether h LIFT)                    a lift climbing a tether up through its middle, from its
;                                      pad to h over its head
;   (sky hour COVER)                   the level's sky at that hour of the day, COVER 'clear
;                                      'partly 'mostly or 'overcast; none, and no street is lit
;   (smog k)                           the sky and its light browned toward orange, k 0 to 1
;   (twinkle k)                        the air's stir under the stars: 1 earth's (none said),
;                                      0 an airless sky's still stars, more a shimmering night
;   (ambient (rgb r g b))              light everywhere under a roof at once, over the
;                                      world's own dim
;   (skylight (rgb r g b))             light out under the sky at any hour, over the sky's own
;   (hum SOUND [x y z] [x y z])        a sound always going, heard between two corners and
;                                      fading out a little past them: 'fluorescent, the
;                                      tubes' buzz, louder under each strip light; 'wind and
;                                      'bells, a desert's, dulled under a roof or in glass;
;                                      'throb, the garage's plant
;   (deck [x y z] [x y z])             a box a tap starts the loop playing in, a phrase from a
;                                      die wearing away as it goes round (decay.l), and stops
;   (speaker [x y z])                  where the loop is heard from: whole near it, gone some
;                                      ten metres off
;   (heard [x y z] [x y z] PARTS)      the speakers among PARTS heard only inside the box,
;                                      fading out past it as a hum does
;   (air SHAPE) (solid SHAPE)          a brush: space starts solid, air carves it and solid
;                                      fills it again, the later winning; a room is an air box
;     (box [x y z] [x y z])            ..a box between two corners
;     (prism height [[x y z] ..])      ..its floor plan going round, at the first point's height
;   (land TEXTURE [[[x y z] ..] ..])   ground: a brush solid under a sheet through rows of
;                                      points, laid as a drape is with no gaps, and drawn so
;                                      but where a later brush carves it open
;   (whole BRUSH)                      the brush never cut finer near a lamp: a small thing's
;                                      light as its corners have it
;   (cut [x y z] [x y z] [x y z] BRUSH)  the brush less what lies across the plane through
;                                      three points from its shape's middle, however many
;                                      cuts are on it: a slope, a bevel
;   (door [x y z] width height)        a sliding door in the wall between two rooms, the
;                                      middle of its foot at x y z, opening as one comes near
;   (by-hand DOOR)                     the door opened and shut only by a tap on it
;   (glazed TEXTURE DOOR)              the door a pane of glass in a thin frame, sliding
;   (dark ROOM)                        a room the ambient does not reach: lit by its lamps alone
;   (train [x y z] [x y z] DOOR leave) a car on rails, its inside between two corners and a
;                                      (door ..) in a long wall: it opens as the level starts,
;                                      shuts once the player is out, and the car goes leave
;                                      metres along its length, the sign its way, and is gone
;   (bin [x y z] width depth height TEXTURE SIGN)  a rubbish bin standing at x y z: narrower
;                                      at its foot, its corners cut, capped, hollow up top and
;                                      open on every side there, SIGN () or a texture on each
;                                      side below; solid
;   (mattress [x y z] bearing)         a bare twin mattress lying with the middle of its foot
;                                      at x y z, its head toward bearing; solid
;   (wake-bed NAME [x y z] bearing)    a mattress as above, and a way in named NAME: who
;                                      arrives by it wakes lying on it and gets up
;   (sleep-bed [x y z] bearing FILE ENTRY)  a mattress as above that a tap lies down on,
;                                      and then the level left for FILE beside it at its way
;                                      in ENTRY, or its start for ()
;   (fall y FILE ENTRY)                once a body's feet are below height y, the level
;                                      left for FILE at ENTRY, as sleep's
;   (telescope [x y z] bearing pitch (rgb r g b))  a refractor on a tripod standing at x
;                                      y z, looking toward bearing and pitch degrees up, its
;                                      tube that colour; solid
;   (book [x y z] bearing)             an open book lying with its spine's middle at x y z,
;                                      the top of its pages toward bearing; solid
;   (pencil [x y z] bearing (rgb r g b))  a pencil lying from its eraser at x y z, its point
;                                      toward bearing, painted that colour; solid
;   (rod [x y z] [x y z] radius sides TEXTURE)  a straight bar between two points, sides
;                                      flats round, its ends square to it; solid
;   (lathe [x y z] [[r y] ..] sides SKIN)  a profile turned round the upright through x y z,
;                                      r out at y up, its heights rising; solid
;   (sweep [[x y z] ..] radius sides TEXTURE)  a rod bent through the points: a cable, a rail
;   (fit SKIN SHAPE)                   a small solid, lit at its corners: SKIN a texture or a
;                                      skin's tablet
;   (dice seed k)                      0 to 1, thrown for k (a number or a name) under seed
;   (pick seed k v)                    v a number, or [lo hi] thrown as dice
;   (seed-of seed i)                   the seed of the i'th of many
;   (ease v a b) (smin a b r) (smax a b r)  0 to 1 smoothly as v goes a to b; the lesser
;                                      or greater, rounded within r of the other
;   (scatter seed [[x z] ..] n MAKE {'gap 'bearing 'ground 'keep?})  n places thrown over
;                                      two corners, or three or more going round; kept
;                                      where (keep? x z), and gap from another; each
;                                      (MAKE [x y z] bearing seed), y off 'ground, a
;                                      height or (\ x z y); 'bearing a number or [lo hi]
;   (line-up seed [x y z] [x y z] MAKE {'w 'gap})  side by side from one point toward
;                                      the other, each w wide (a number or [lo hi]), as
;                                      many as fit: (MAKE [x y z] bearing seed w), facing
;                                      across the line
;   (grav [x y z] [x y z] DIR)         a grav shaft: a column of air over the plan between the
;                                      corners, from the lower's floor to a room's height over
;                                      the upper's, motes of light streaming through it; who
;                                      stands in it is carried 'up to the upper floor or 'down
;                                      to the lower
;   (ball [x y z])                     a basketball standing at x y z, kicked by walking into it
;   (tree [x y z] seed TEXTURE)        a tree of heaven grown from seed, its foot at x y z: its
;                                      wood in the bark TEXTURE, its trunk in the way and
;                                      climbed as a ladder, facing it; fitting a 2 m well
;   (plant [x y z] seed SPECIES)       a plant grown from seed, its foot at x y z, a tree as
;                                      the above is to every word after it: SPECIES 'ailanthus
;                                      'oak 'birch 'pine 'willow 'shrub 'grass 'reed 'fern
;                                      'dead, or {'like 'oak 'height [lo hi] ..} changing one:
;                                      'height 'lean 'crook 'girth [foot top] 'pieces 'crown,
;                                      'levels [{'n 'len 'up 'out 'pieces 'r 'bend 'droop
;                                      'along 'cone 'head 'twigs 'leaves} ..], 'ends 'tuft 'spray
;                                      'sprig or (), 'clump 'splay, 'leaf {'kind 'pinnate
;                                      'frond 'simple 'needle 'blade 'len 'pairs 'leaflet 'wide
;                                      'arch 'tip 'bow 'colour 'every 'grow} or (), 'fruit
;                                      {'odds 'n}, 'bark a texture, a kind or bark's {..}
;   (vined TREE)                       the tree climbed only once vines have grown up its
;                                      trunk to the fork, out of the ground, from when the
;                                      loop first plays
;   (burnt TREE)                       the tree dead and charred, its leaves and twigs gone
;   (sheared [x y z] [x y z] [x y z] TREE)  the tree less what lies across the plane through
;                                      three points from its foot, and nothing that grew from
;                                      what went; burnt, each cut face smouldering
;   (sized k girth TREE)               the tree k times as tall and as wide, its wood girth
;                                      times as thick
;   (shadow-hole TREE)                 the tree's shadow under the level's sun a hole in the
;                                      ground it stands on, black down past where one falls
;   (plush [x y z] bearing FILE)       a stuffed toy lying at x y z, facing bearing: a .glb
;                                      beside the level, its origin the floor under it
;   (window [x y z] [x y z] TEXTURE)   an opening carved between two corners, a pane of glass
;                                      across its middle the thin way: what is beyond it
;                                      seen through the texture, the light on it; solid
;   (brittle WINDOW)                   its pane broken by a tap, and gone: then the way through
;   (lens [x y z] WINDOW)              its pane, on the face toward x y z, one a beyond drape is
;                                      seen through; other glass shows only what is there
;   (decal [x y z] [nx ny nz] [ux uy uz] width height TEXTURE)  a picture laid on a surface,
;                                      its middle at x y z, facing n, its top toward u; its
;                                      texture's holes show what is under it
;   (drape TEXTURE [[[x y z] ..] ..])  a sheet through rows of points, () a gap: each four
;                                      neighbours round two triangles, none by a gap; its
;                                      front up when the rows run toward z, their points toward x
;   (beyond DRAPE) (hither DRAPE)      the drape seen only through a lens, or only
;                                      where no lens is between: what the window shows, and
;                                      what is really there
;   (flow [du dv] DRAPE)               the drape's texture drifting du dv metres a second
;   (along s DRAPE)                    the drape's texture laid along its rows as they go,
;                                      from s metres, not from above: a flow keeps to its bends
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
;                                      world's own
;   (sign [x y z] height TEXT (rgb r g b))  a neon sign on the wall nearest
;   (neon [x y z] [nx ny nz] height TEXT (rgb r g b))  a neon sign whose foot's middle is at
;                                      x y z, facing n
;   (ad [x y z] [nx ny nz] [ux uy uz] width height TEXTURE)  a lit advertisement, laid as a
;                                      decal is, bright as its own light and lighting what
;                                      is before it in its colours
;   (playing AD)                       an advertisement lit only while the level's loop plays
;   (fence [[x y z] ..] height TEXTURE)  a wrought iron fence through the points, each the
;                                      foot of a post, two rails between and pickets on them,
;                                      spiked; in a body's way below its top
;   (wooden FENCE)                     the fence a picket fence of boards
;   (gate [x y z] [x y z] height degrees TEXTURE)  a wrought iron gate's leaf from the foot of
;                                      its hinge to its latch's: a tap swings it open degrees
;                                      clockwise from above, and shut again; in a
;                                      body's way where it hangs
;   (grave [x y z] bearing NAME TEXTURE)  a small headstone, the middle of its foot at x y z,
;                                      facing bearing: tapped, the player kneels before it,
;                                      the name shown, to weep or leave; solid
;   (spinner [x y z] width height TEXTURE TEXTURE)  a square of four lit advertisements
;                                      turning slowly about its middle at x y z, the two
;                                      textures in turn round it
;   (orb [x y z] radius TEXTURE turns)  a ball hanging in the air about x y z, turning
;                                      turns a second about the up through it, lit where it is
;   (glow ORB)                         an orb as bright as its own colours, lit or not
;   (inward ORB)                       an orb facing in, seen only from inside it
;   (herald [x y z] size reach TEXTURE FILE ENTRY)  a picture size across always facing
;                                      the eye, waiting at x y z: once the eye is within
;                                      reach of it, it comes for the eye fast, and at the
;                                      touch the level is left for FILE at ENTRY, as sleep's
;   (coarse k ORB)                     an orb drawn k times coarser than the world round it, k
;                                      2 4 or 8, its pixels k by k of the world's
;   (across LIGHT)                     a strip turned across, along x
;   (troffer LIGHT)                    a strip laid in a drop ceiling: two of its tiles, from
;                                      x and z on its grid, a diffuser in a frame
;   (unlit LIGHT)                      a strip's fitting alone, bright by the room's own light
;                                      and lighting nothing: one of many under an ambient; a
;                                      sign its tubes and their halo alone
;                                      standing for theirs
;   (stammer LIGHT) (buzz LIGHT) (breathe LIGHT) (blink LIGHT)  a light failing, buzzing,
;                                      breathing, or flashing as a mast's beacon does
;   (texture width height metres LAYERS)  a texture, width by height texels and metres wide
;                                      on a surface, painted by its layers (swatch.l), quoted
;   (rock [x y z] seed SHAPE)          a rock standing at x y z: a box cut by planes thrown
;                                      round it, sunk a little; SHAPE 'boulder 'pebble 'scree
;                                      'slab 'standing 'altar 'outcrop 'cairn, or a tablet
;                                      {'like 'boulder 'size [lo hi] ..} changing one: 'size
;                                      a number, [lo hi], or three of those across, up and
;                                      along; 'cuts 'bite 'flat 'sink 'bearing; 'n of them
;                                      'spread metres apart or 'stack-ed, each 'shrink of the
;                                      last; 'skin a texture, a skin or a material's kind
;   (hills seed {'scale 'height 'octaves}) (ridges seed ..)  a ground: (\ x z y), up to
;                                      height above and below it; ridges above it alone
;   (dunes {'bearing 'length 'height}) (mound [x z] radius top height)  (terrace GROUND step)
;   (channel [[x z] ..] w depth)       depth down within w of the path, its banks up by 2 w
;   (rise G G) (blend G G r) (carve G G r)  grounds summed, the higher, the lower, rounded
;   (ground-of SKIN [[x z] [x z]] step GROUND)  a land over two corners, a point every step
;   (furnish KIND [x y z] bearing {PARAM v ..})  a piece of furniture, the middle of its foot
;                                      at x y z, its user facing the bearing: 'table 'desk
;                                      'chair 'stool 'bench 'bed 'shelf 'cabinet 'counter
;                                      'crate 'carton 'sofa; 'w 'd 'h, 'top, 'legs 'corners
;                                      'panels 'trestle 'pedestal 'star or (), 'leg 'inset
;                                      'apron 'modesty 'seat 'back 'arms 'shelves 'drawers
;                                      'doors 'over 'slats, 'fill 'books or a MAKE given each
;                                      'fill-w slot as line-up does, 'seed, and 'skin of
;                                      'top 'frame 'body 'soft 'feet, each a texture, a skin
;                                      or a kind; 'feet a star's casters, the frame's unless said
;   (material KIND seed {PARAM v ..})  a texture of a kind, its parameters each a number,
;                                      [lo hi] thrown under seed, or a colour, and felt as
;                                      the kind is: 'wood 'plank 'stone 'sandstone 'brick
;                                      'tile 'cobble 'mud 'concrete 'metal 'cloth 'carpet
;                                      'gravel 'sand 'soil 'grass 'card 'bark; a wrong one says what it takes
;   (skin {'walls T 'floor T 'ceiling T 'all T} BRUSH)  the textures on a brush's faces, a
;                                      floor any face turned up and a ceiling down
;   (textures {'wall T 'floor T 'ceiling T 'door T 'train T})  the textures where no skin says
;   (feel 'soft TEXTURE)               the texture as it sounds landed on: 'soft, 'hard (any
;                                      not felt), 'wood or 'metal
;   (laid TEXTURE degrees [du dv])     the texture as a skin or textures lays it, turned
;                                      degrees from u toward v and shifted du dv metres its
;                                      own way; a floor's u is x and v z, a wall's u along it
;                                      and v down
;   (repeat n [dx dy dz] PARTS)        the parts n times, each that far on from the last
;   (move [dx dy dz] PARTS)            the parts that far on
;   (turn degrees [x z] PARTS)         the parts swung degrees clockwise from above about
;                                      the upright through x z, a bearing turned as far; a
;                                      box swung off the square a prism, and a room, street,
;                                      door, window, grav, train or strip light swung only
;                                      a quarter at a time
;   (mirror-x c PARTS) (mirror-z c PARTS)  the parts, and again reflected where x or z is c
;
; a word given what it does not take stops the level, saying what it takes.
(module (scenery level-of sourced dice pick seed-of ease smin smax fit lathe sweep scatter line-up material rock hills ridges dunes terrace mound channel rise blend carve ground-of furnish plant start entry shot room street void gravity surface pocket lift deck speaker heard sky ambient skylight hum air solid box prism cut whole land door by-hand glazed dark tree vined burnt sheared sized shadow-hole train bin mattress wake-bed sleep-bed fall telescope book pencil rod decal drape beyond hither flow along window brittle lens grav ball plush smog twinkle ad spinner orb glow inward herald tether playing fence wooden gate grave coarse neon strip-light bulb sconce flames poster sign
         across troffer unlit stammer buzz breathe blink texture feel laid skin textures repeat move turn mirror-x mirror-z rgb)
(borrow '(view swatch))
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
 ; ..where a part stands from the form that told it, over the floor: [a b c d tx tz], its
 ; x a x + b z + tx and its z c x + d z + tz
 xf-id [1.0 0.0 0.0 1.0 0.0 0.0]
 ; ..the parts a form of the level's source made, each told where it stands there, path p
 ; down the source's forms; one told already by a form inside keeps that
 (sourced p x) (map (q \ q 'src = () ? (pin (with q 'src p) 'xf xf-id) q) (flat x))
 (xf-then o i) [(o 0 * i 0 + o 1 * i 2) (o 0 * i 1 + o 1 * i 3) (o 2 * i 0 + o 3 * i 2) (o 2 * i 1 + o 3 * i 3)
                (o 0 * i 4 + o 1 * i 5 + o 4) (o 2 * i 4 + o 3 * i 5 + o 5)]
 (xf-on o p) (with p 'xf (xf-then o (peep p 'xf xf-id)))
 (kind? p ks) (tablet? p && elem (p 'kind) ks)
 (rgb r g b) [(N r "(rgb r g b)") (N g "(rgb r g b)") (N b "(rgb r g b)")]
 (colour? c) (two? c && #c = 3 && all num? c)
 (start at deg pitch) (: u "(start [x y z] bearing pitch)" (part 'start [['at (P at u)] ['deg (N deg u)] ['pitch (N pitch u)]]))
 (entry nm at deg pitch) (: u "(entry NAME [x y z] bearing pitch)"
   (nom? nm ? (part 'entry [['name nm] ['at (P at u)] ['deg (N deg u)] ['pitch (N pitch u)]]) (no u nm)))
 ; ..where another level is, and the way into it: a file beside this one, a name or ()
 (way-to u file nm) (? (!(string? file)) (no u file) (!(nom? nm || nm = ())) (no u nm) [['file file] ['entry nm]])
 (shot s w deg pitch) (: u "(shot seconds [x y z] bearing pitch), or (shot seconds (sky hour COVER) bearing pitch)"
   (? (!(num? s) || s <= 0) (no u s)
      (part 'shot ([['secs (f s)] ['deg (N deg u)] ['pitch (N pitch u)]] + (kind? w ['sky] ? [['sky w]] [['at (P w u)]])))))
 (room lo hi) (: u "(room [x y z] [x y z])" (part 'room [['lo (P lo u)] ['hi (P hi u)] ['skin {}]]))
 (street lo hi) (: u "(street [x y z] [x y z])" (part 'room [['lo (P lo u)] ['hi (P hi u)] ['skin {}] ['open 1]]))
 (void lo hi) (: u "(void [x y z] [x y z])" (part 'room [['lo (P lo u)] ['hi (P hi u)] ['skin {}] ['open 1] ['sheer 1]]))
 (gravity ps) (: u "(gravity [[y g] ..])"
   (two? ps && all (q \ two? q && #q = 2 && all num? q && 0 <= q 1) ps
    ? (part 'gravity [['by (sort (map (q \ [(1.0 * q 0) (1.0 * q 1)]) ps))]]) (no u ps)))
 (surface k lx lz) (: u "(surface 'torus lx lz) or (surface 'plane lx lz)"
   (elem k ['torus 'plane] && num? lx && num? lz && 0 < lx && 0 < lz ? (part 'surface [['shape k] ['lx (f lx)] ['lz (f lz)]]) (no u k)))
 ; ..a pocket: its parts sunk far under and away from everything, where the world finds them
 ; and lays them flat
 pocket-d 1000.0
 (pocket at ps) (: u "(pocket [x z] PARTS)"
   (two? at && #at = 2 && all num? at ? ([(part 'pocket [['at (map f at)] ['d pocket-d]])] + move [0.0 -pocket-d -pocket-d] ps) (no u at)))
 (lift at w rise t) (: u "(lift [x y z] width rise TEXTURE)"
   (? (!(num? w) || w < 1.0) (no u w) (!(num? rise) || rise <= 0) (no u rise) (!(texture? t)) (no u t)
      (part 'lift [['at (P at u)] ['w (f w)] ['rise (f rise)] ['tex t]])))
 (deck lo hi) (: u "(deck [x y z] [x y z])" (part 'deck [['lo (P lo u)] ['hi (P hi u)]]))
 (speaker at) (part 'speaker [['at (P at "(speaker [x y z])")]])
 (heard lo hi ps) (: u "(heard [x y z] [x y z] PARTS)" a (P lo u) b (P hi u)
   (map (p \ kind? p ['speaker] ? (with (with p 'lo (lo2 a b)) 'hi (hi2 a b)) p) (flat ps)))
 (sky hr cv) (: u "(sky hour COVER)" (? (!(charm? hr || gem? hr)) (no u hr) (!(elem cv ['clear 'partly 'mostly 'overcast])) (no u cv)
                                       (part 'sky [['hour (1.0 * hr)] ['cover cv]])))
 (smog k) (: u "(smog k)" ((charm? k || gem? k) && 0 <= k && k <= 1 ? (part 'smog [['k (1.0 * k)]]) (no u k)))
 (twinkle k) (: u "(twinkle k)" ((charm? k || gem? k) && 0 <= k ? (part 'twinkle [['k (1.0 * k)]]) (no u k)))
 (ambient c) (: u "(ambient (rgb r g b))" (colour? c ? (part 'ambient [['c c]]) (no u c)))
 (skylight c) (: u "(skylight (rgb r g b))" (colour? c ? (part 'skylight [['c c]]) (no u c)))
 (hum nm lo hi) (: u "(hum SOUND [x y z] [x y z])"
   (elem nm ['fluorescent 'wind 'bells 'throb] ? (part 'hum [['sound nm] ['lo (P lo u)] ['hi (P hi u)]]) (no u nm)))
 ; a brush's shape; air and solid make it a brush
 (box lo hi) (: u "(box [x y z] [x y z])" (part 'box [['lo (P lo u)] ['hi (P hi u)]]))
 (prism h ps) (: u "(prism height [[x y z] ..])"
   (two? ps && #ps >= 3 ? (part 'prism [['h (N h u)] ['pts (map (q \ P q u) ps)]]) (no u ps)))
 (brush a sh) (kind? sh ['box 'prism] && !(elem 'air (keys sh)) ? (with (with (with sh 'air a) 'cuts ()) 'skin {}) (no "(air SHAPE) or (solid SHAPE), a SHAPE (box ..) or (prism ..)" sh))
 (air sh) (brush 1 sh)
 (solid sh) (brush 0 sh)
 (brush? b) (kind? b ['room 'land] || (kind? b ['box 'prism] && elem 'air (keys b)))
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
 (by-hand d) (kind? d ['door] ? (with d 'hand 1) (no "(by-hand (door ..))" d))
 (glazed t d) (: u "(glazed TEXTURE (door ..))" (? (!(texture? t)) (no u t) (kind? d ['door]) (with d 'glass t) (no u d)))
 (dark r) (kind? r ['room] && !(peep r 'open 0) ? (with r 'dark 1) (no "(dark (room ..))" r))
 (tree at seed t) (: u "(tree [x y z] seed TEXTURE)" p (P at u)
   (? (!(charm? seed)) (no u seed) (!(texture? t)) (no u t)
      (part 'tree [['at p] ['seed seed] ['tex t]])))
 (vined t) (kind? t ['tree] ? (with t 'vine 1) (no "(vined (tree ..))" t))
 (burnt t) (kind? t ['tree] ? (with t 'burnt 1) (no "(burnt (tree ..))" t))
 (sheared p q r t) (: u "(sheared [x y z] [x y z] [x y z] (tree ..))"
   (kind? t ['tree] ? (with (with t 'burnt 1) 'cuts [[(P p u) (P q u) (P r u)]]) (no u t)))
 (sized k g t) (: u "(sized k girth (tree ..))"
   (? (!(kind? t ['tree])) (no u t) (!(num? k && k > 0)) (no u k) (!(num? g && g > 0)) (no u g)
      (with t 'size [(f k) (f g)])))
 (shadow-hole t) (kind? t ['tree] ? (with t 'hole 1) (no "(shadow-hole (tree ..))" t))
 (plush at deg file) (: u "(plush [x y z] bearing FILE)"
   (string? file ? (part 'plush [['at (P at u)] ['deg (N deg u)] ['file file]]) (no u file)))
 ; ..a window: its opening, and its pane
 (window lo hi t) (: u "(window [x y z] [x y z] TEXTURE)" a (P lo u) b (P hi u)
   (texture? t ? [(air (box a b)) (part 'pane [['lo (lo2 a b)] ['hi (hi2 a b)] ['tex t]])] (no u t)))
 (brittle w) (: u "(brittle (window ..))" ps (filter (p \ kind? p ['pane]) (flat [w]))
   (#ps @ 1 (map (p \ kind? p ['pane] ? (with p 'brittle 1) p) (flat [w])) (no u w)))
 (lens at w) (: u "(lens [x y z] (window ..))" ps (filter (p \ kind? p ['pane]) (flat [w]))
   (? (!(pt? at)) (no u at) (#ps = 1) (map (p \ kind? p ['pane] ? (with p 'lens (P at u)) p) (flat [w])) (no u w)))
 ; ..a decal: its middle, and points a metre on along its facing and its up
 (decal at n up w h t) (: u "(decal [x y z] [nx ny nz] [ux uy uz] width height TEXTURE)" a (P at u) nn (P n u) uu (P up u)
   (texture? t ? (part 'decal [['at a] ['np (map (k \ a k + nn k) ^3)] ['up (map (k \ a k + uu k) ^3)] ['w (N w u)] ['h (N h u)] ['tex t]])
      (no u t)))
 (drape t rs) (: u "(drape TEXTURE [[[x y z] ..] ..])" (pg q) (q @ () () (P q u))
   (? (!(texture? t)) (no u t) (!(two? rs && all two? rs && all (r \ #r = #<rs) rs)) (no u rs)
      (part 'drape [['tex t] ['rows (map (map pg) rs)]])))
 (land t rs) (: u "(land TEXTURE [[[x y z] ..] ..])"
   (? (!(texture? t)) (no u t) (!(two? rs && #rs > 1 && all two? rs && all (r \ #r = #<rs && all pt? r) rs && #<rs > 1)) (no u rs)
      (part 'land [['air 0] ['tex t] ['skin {'floor t}] ['rows (map (map (map f)) rs)]])))
 (beyond d) (kind? d ['drape] ? (with d 'seen 1) (no "(beyond DRAPE)" d))
 (hither d) (kind? d ['drape] ? (with d 'seen 2) (no "(hither DRAPE)" d))
 (flow v d) (: u "(flow [du dv] DRAPE)"
   (two? v && #v = 2 && all num? v && kind? d ['drape] ? (with d 'flow (map f v)) (no u (kind? d ['drape] ? v d))))
 (along s d) (: u "(along s DRAPE)" (num? s && kind? d ['drape] ? (with d 'along (f s)) (no u (num? s ? d s))))
 ; ..a bin: brushes, its body's sides and corners cut in toward its foot, hollow up top with an
 ; opening into it on each side, the band over those and a cap a little wider going in
 ; toward the top; its sign on each side
 (bin at w d h t sg) (: u "(bin [x y z] width depth height TEXTURE SIGN)" p (P at u) x (p 0) y (p 1) z (p 2)
   (? (!(texture? t)) (no u t) (!(sg = () || texture? sg)) (no u sg)
      (: dk (texture 8 8 1 '((fill 0.12) (noise 2 0.3)))
         W (0.5 * N w u) D (0.5 * N d u) H (N h u) k (0.12 * min W D) c (0.2 * min W D) y1 (y + H)
         i0 (y1 - 0.5 * H) i1 (y1 - 0.04) iw (W - 0.5 * k - 0.03) id (D - 0.5 * k - 0.03)
         o0 (y1 - 0.4 * H) o1 (y1 - 0.1 * H) sl (0.7 * W) sd (0.7 * D) tp (0.9 * k)
         (sx i) (i ? 1.0 -1.0)
         ; ..a solid from y0 to y1, w0 by d0 at its foot and w1 by d1 at its top, each side
         ; through both edges and each corner cut c off
         (taper y0 y1 w0 d0 w1 d1) (: m (max w0 w1) n (max d0 d1)
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
         hb (o1 - y) ys (y + 0.33 * H) e ((1.0 - (ys - y) / hb) * k - 0.004) sz (min (0.42 * H) (1.3 * min W D)) L (sqrt (2 hb + 2 k))
         signs (sg = () ? ()
                  [(decal [(x + W - e) ys z] [(hb / L) -(k / L) 0.0] [(k / L) (hb / L) 0.0] sz sz sg)
                   (decal [(x - W + e) ys z] [-(hb / L) -(k / L) 0.0] [-(k / L) (hb / L) 0.0] sz sz sg)
                   (decal [x ys (z + D - e)] [0.0 -(k / L) (hb / L)] [0.0 (hb / L) (k / L)] sz sz sg)
                   (decal [x ys (z - D + e)] [0.0 -(k / L) -(hb / L)] [0.0 (hb / L) -(k / L)] sz sz sg)])
         ; ..small enough that its faces go uncut, lit at their corners
         [(map (b \ with b 'whole 1)
               ([(skin {'all t} body) (skin {'all t} band)] + map (b \ skin {'all dk} (air b)) hollow
                + [(skin {'all t} (taper y1 (y1 + 0.05) (W - tp + 0.02) (D - tp + 0.02) (W - tp - 0.01) (D - tp - 0.01)))]))
          signs])))
 ; --- props: brushes in a group, turned by a bearing, degrees from north toward east ---
 (v+ a b) (map (k \ a k + b k) ^3)
 (v* c a) (map (k \ c * a k) ^3)
 (cross a b) [(a 1 * b 2 - a 2 * b 1) (a 2 * b 0 - a 0 * b 2) (a 0 * b 1 - a 1 * b 0)]
 (unit a) (: m (sqrt (2 (a 0) + 2 (a 1) + 2 (a 2))) (v* (1.0 / m) a))
 (ahead deg) (: t (deg * pi / 180.0) [(sin t) 0.0 (cos t)])
 ; ..a rod: a box round it cut by a plane along each flat and one square across each end
 (rod a b r n t) (: u "(rod [x y z] [x y z] radius sides TEXTURE)" p (P a u) q (P b u) R (N r u)
   (? (!(charm? n && n >= 3)) (no u n) (!(texture? t)) (no u t)
      (: d (v+ q (v* -1.0 p)) _ (? (sqrt (2 (d 0) + 2 (d 1) + 2 (d 2)) < 1e-6) (no u b))
         w (unit d) e1 (unit (cross w (abs (w 1) > 0.9 ? [1.0 0.0 0.0] [0.0 1.0 0.0]))) e2 (cross w e1)
         m (v* 0.5 (v+ p q))
         flats (map (k \ (: a (2.0 * pi * k / n) dk (v+ (v* (cos a) e1) (v* (sin a) e2)) tk (v+ (v* -(sin a) e1) (v* (cos a) e2))
                         o (v+ m (v* R dk)) [o (v+ o w) (v+ o tk)]))
                    ^n)
         ends [[p (v+ p e1) (v+ p e2)] [q (v+ q e1) (v+ q e2)]]
         lo (map (k \ min (p k) (q k) - R - 0.01) ^3) hi (map (k \ max (p k) (q k) + R + 0.01) ^3)
         (with (skin {'all t} (foldl (\ b c (cut (c 0) (c 1) (c 2) b)) (solid (box lo hi)) (flats + ends))) 'whole 1))))
 ; --- the kit a prop is grown with: dice, easing, and ways to lay things out ---
 ; ..a die for k under seed, 0 to 1, the same every read; k a number or a name, so each
 ; parameter throws its own and changing one leaves the rest
 (key k) (charm? k ? k (foldl (\ a c ((a * 31 + c) % 2147483647)) 7 (chars (show k))))
 (dice s k) (throw (key k) 0 (key s) 1048576 / 1048576.0)
 (pick s k v) (? (num? v) (f v) (two? v && #v = 2 && all num? v) (f (v 0) + (v 1 - v 0) * dice s k)
                 (no "a number, or [lo hi]" v))
 ; ..the seed of the i'th of many
 (seed-of s i) (throw (key i) 7 (key s) 2147483647)
 (ease v a b) (: k (min 1.0 (max 0.0 ((v - a) / (b - a)))) (2 k * (3.0 - 2.0 * k)))
 ; ..the lesser and the greater, rounded where they come within r
 (smin a b r) (max 0.0 (r - abs (a - b)) / r @ h (min a b - h * h * r * 0.25))
 (smax a b r) (0.0 - smin (0.0 - a) (0.0 - b) r)
 (skin-of-any t) (surface? t ? {'all t} t)
 (fit t sh) (whole (skin (skin-of-any t) (solid sh)))
 ; ..a lathe: each span of the profile between two heights a brush cut by a plane along
 ; each flat, so it stays convex; a span whose radii are both 0, or that does not rise, is none
 (lathe at prof n t) (: u "(lathe [x y z] [[r y] ..] sides SKIN)" o (P at u)
   (? (!(charm? n && n >= 3)) (no u n)
      (!(two? prof && #prof >= 2 && all (q \ two? q && #q = 2 && all num? q && q 0 >= 0) prof)) (no u prof)
      (: ps (map (map f) prof) sk (skin-of-any t) c (cos (pi / n))
         (span p q) (: R (max (p 0) (q 0) / c + 0.01)
           flats (map (k \ (: a (2.0 * pi * k / n) d [(cos a) 0.0 (sin a)] b (v+ o [(p 0 * d 0) (p 1) (p 0 * d 2)])
                            [b (v+ o [(q 0 * d 0) (q 1) (q 0 * d 2)]) (v+ b [-(d 2) 0.0 (d 0)])]))
                      ^n)
           (whole (skin sk (foldl (\ b e (cut (e 0) (e 1) (e 2) b))
                                  (solid (box [(o 0 - R) (o 1 + p 1) (o 2 - R)] [(o 0 + R) (o 1 + q 1) (o 2 + R)])) flats))))
         (map (i \ span (ps i) (ps (i + 1))) (filter (i \ ps i 1 < ps (i + 1) 1 && 0.0 < ps i 0 + ps (i + 1) 0) ^(#ps - 1))))))
 ; ..a sweep: a rod from each point of the path to the next, run on r past each joint so a
 ; bend is closed, square at the path's own ends
 (sweep path r n t) (: u "(sweep [[x y z] ..] radius sides TEXTURE)"
   (? (!(two? path && #path >= 2 && all pt? path)) (no u path) (!(num? r && r > 0)) (no u r)
      (: ps (map (map f) path) m (#ps - 1) R (f r)
         (seg i) (: a (ps i) b (ps (i + 1)) d (v+ b (v* -1.0 a)) w (unit d)
           (rod (i = 0 ? a (v+ a (v* -R w))) (i = m - 1 ? b (v+ b (v* R w))) R n t))
         (map seg (filter (i \ (ps (i + 1) @ b (abs (b 0 - ps i 0) + abs (b 1 - ps i 1) + abs (b 2 - ps i 2) > 1e-6))) ^m)))))
 ; ..a polygon's inside, its corners [x z] going round: crossed an odd number of times to the right
 (poly-in ps) (: n #ps
   (\ x z (foldl (\ a i (: p (ps i) q (ps ((i + 1) % n))
                          ((p 1 > z) != (q 1 > z) && x < p 0 + (q 0 - p 0) * (z - p 1) / (q 1 - p 1) ? (1 - a) a)))
                 0 ^n = 1)))
 ; ..a scatter: n places thrown over the region, each kept where it is inside, keep? says so
 ; and none kept before is within gap; then made there, (make [x y z] bearing seed)
 (scatter s reg n mk o) (: u "(scatter seed [[x z] ..] n MAKE {'gap 'bearing 'ground 'keep?})"
   (? (!(two? reg && #reg >= 2 && all (q \ two? q && #q = 2 && all num? q) reg)) (no u reg)
      (!(charm? n && n >= 0)) (no u n) (!(tablet? o)) (no u o)
      (: rs (map (map f) reg) xs (map (q \ q 0) rs) zs (map (q \ q 1) rs)
         x0 (foldl min (xs 0) xs) x1 (foldl max (xs 0) xs) z0 (foldl min (zs 0) zs) z1 (foldl max (zs 0) zs)
         in? (#rs = 2 ? (\ x z 1) (poly-in rs))
         gap (f (peep o 'gap 0.0)) bg (peep o 'bearing [0.0 360.0]) gr (peep o 'ground 0.0) keep? (peep o 'keep? (\ x z 1))
         (near? x z got) (any (q \ (q 0 - x) * (q 0 - x) + (q 2 - z) * (q 2 - z) < gap * gap) got)
         (try i got) (? (n <= i) (rev got)
           (: e (seed-of s i) x (x0 + (x1 - x0) * dice e 'x) z (z0 + (z1 - z0) * dice e 'z)
              (in? x z && keep? x z && !(near? x z got) ? (try (i + 1) ([x (num? gr ? (f gr) (gr x z)) z e] . got)) (try (i + 1) got))))
         (map (q \ mk [(q 0) (q 1) (q 2)] (pick (q 3) 'bearing bg) (q 3)) (try 0 ())))))
 ; ..a line-up: things side by side from a toward b, each w wide and gap apart, as many as
 ; fit; (make [x y z] bearing seed w) at each one's middle, facing across the line
 (line-up s a b mk o) (: u "(line-up seed [x y z] [x y z] MAKE {'w 'gap})" p (P a u) q (P b u)
   (? (!(tablet? o)) (no u o)
      (: d (v+ q (v* -1.0 p)) L (sqrt (d 0 * d 0 + d 1 * d 1 + d 2 * d 2)) dir (v* (1.0 / L) d)
         ws (peep o 'w 1.0) gap (f (peep o 'gap 0.0)) deg (atan2 (d 0) (d 2) * 180.0 / pi + 90.0)
         (go x i acc) (: e (seed-of s i) w (pick e 'w ws)
           (L < x + w || w <= 0.0 ? (rev acc) (go (x + w + gap) (i + 1) (mk (v+ p (v* (x + 0.5 * w) dir)) deg e w . acc))))
         (go 0.0 0 ()))))
 ; ..a bare twin mattress, 99 by 190.5 by 25 cm: quilted ivory ticking on top, its border
 ; striped between two pipings, plain under; its corners rounded off in plan and its edges
 ; top and bottom
 mattress-w 0.99 mattress-l 1.905 mattress-h 0.25
 (mattress-top _) (texture 64 64 0.5 '((fill (rgb 0.9 0.88 0.82)) (noise 3 0.06) (patches 8 0.3 (shade 0.94))
                                   (stripes 16 1 1 (shade 0.8)) (stripes 16 1 -1 (shade 0.8)) (dots 16 16 1.6 (shade 0.7))))
 (mattress-side _) (texture 64 32 0.5 '((fill (rgb 0.87 0.85 0.79)) (stripes 8 2 0 (shade 0.92)) (noise 3 0.05)
                                    (rows 0 2 (rgb 0.72 0.7 0.64)) (rows 30 32 (rgb 0.72 0.7 0.64))))
 (mattress-under _) (texture 32 32 0.5 '((fill (rgb 0.78 0.77 0.73)) (noise 4 0.08)))
 (mattress at deg) (: u "(mattress [x y z] bearing)" o (P at u) f (ahead (N deg u)) r [(f 2) 0.0 -(f 0)]
   w (0.5 * mattress-w) l mattress-l H mattress-h c 0.07 e 0.035
   (L a h b) (v+ o (v+ (v* a r) (v+ (v* b f) [0.0 h 0.0])))
   plan [[(w - c) l] [w (l - c)] [w c] [(w - c) 0.0] [(c - w) 0.0] [-w c] [-w (l - c)] [(c - w) l]]
   mid [0.0 (0.5 * l)]
   ; ..each edge of the plan bevelled at the top and less at the bottom, toward its outside
   (edge i) (: A (plan i) B (plan ((i + 1) % 8)) da (B 0 - A 0) db (B 1 - A 1) dl (sqrt (2 da + 2 db))
              n0 (db / dl) n1 -(da / dl) s (n0 * (0.5 * (A 0 + B 0) - mid 0) + n1 * (0.5 * (A 1 + B 1) - mid 1) < 0.0 ? -1.0 1.0)
              ox (s * n0) oz (s * n1) k (0.6 * e)
              [[(L (A 0 - e * ox) H (A 1 - e * oz)) (L (B 0 - e * ox) H (B 1 - e * oz)) (L (A 0) (H - e) (A 1))]
               [(L (A 0 - k * ox) 0.0 (A 1 - k * oz)) (L (B 0 - k * ox) 0.0 (B 1 - k * oz)) (L (A 0) k (A 1))]])
   body (solid (prism H (map (q \ L (q 0) 0.0 (q 1)) plan)))
   (skin {'floor (mattress-top ()) 'walls (mattress-side ()) 'ceiling (mattress-under ())}
         (foldl (\ b c (cut (c 0) (c 1) (c 2) b)) body (catmap edge ^8))))
 ; ..a mattress that is a way in, and one that is a way out
 (wake-bed nm at deg) (: u "(wake-bed NAME [x y z] bearing)"
   (nom? nm ? [(mattress at deg) (part 'entry [['name nm] ['at (P at u)] ['deg (N deg u)] ['pitch 0.0] ['bed 1]])] (no u nm)))
 (sleep-bed at deg file nm) (: u "(sleep-bed [x y z] bearing FILE ENTRY)"
   [(mattress at deg) (part 'sleep ([['at (P at u)] ['deg (N deg u)]] + way-to u file nm))])
 (fall y file nm) (: u "(fall y FILE ENTRY)"
   (num? y ? (part 'fall ([['y (f y)]] + way-to u file nm)) (no u y)))
 ; ..a small refractor on an aluminium tripod: three legs splayed from a black head, the
 ; tube its colour with a black dew shield and cell, a finder along its top, the eyepiece
 ; in a diagonal at its back looking up
 (telescope-leg _) (texture 16 16 0.2 '((fill (rgb 0.63 0.65 0.68)) (noise 2 0.12)))
 (telescope-black _) (texture 16 16 0.2 '((fill (rgb 0.07 0.07 0.08)) (noise 3 0.2)))
 (telescope at deg pitch c) (: u "(telescope [x y z] bearing pitch (rgb r g b))" o (P at u) th (N deg u) ph (N pitch u * pi / 180.0)
   _ (? (!(colour? c)) (no u c))
   lg (telescope-leg ()) bk (telescope-black ()) wt (texture 32 16 0.3 [['fill ['rgb (c 0) (c 1) (c 2)]] '(noise 4 0.05)])
   (up h) (v+ o [0.0 h 0.0]) H 1.15 f (ahead th)
   legs (map (k \ (: g (ahead (th + 120.0 * k))
                    (rod (v+ (up -0.02) (v* 0.42 g)) (v+ (up (H - 0.03)) (v* 0.04 g)) 0.016 4 lg)))
             ^3)
   head [(rod (up (H - 0.07)) (up H) 0.07 6 bk) (rod (up H) (up (H + 0.1)) 0.03 8 bk)]
   pv (up (H + 0.15)) v (v+ (v* (cos ph) f) [0.0 (sin ph) 0.0]) n (v+ (v* -(sin ph) f) [0.0 (cos ph) 0.0])
   (tp k j) (v+ pv (v+ (v* k v) (v* j n)))
   tube [(rod (tp -0.38 0.0) (tp 0.44 0.0) 0.05 8 wt)
         (rod (tp 0.42 0.0) (tp 0.66 0.0) 0.058 8 bk)
         (rod (tp -0.43 0.0) (tp -0.37 0.0) 0.045 8 bk)
         (rod (tp -0.47 0.0) (tp -0.43 0.0) 0.025 8 bk)
         (rod (tp -0.47 -0.01) (tp -0.47 0.12) 0.016 8 bk)
         (rod (tp 0.05 0.072) (tp 0.06 0.05) 0.008 4 bk)
         (rod (tp -0.06 0.085) (tp 0.2 0.085) 0.016 8 bk)
         (rod (tp -0.01 -0.03) (tp -0.01 -0.13) 0.02 8 bk)]
   (legs + head + tube))
 ; ..an open book: its cover laid flat, a block of pages each side of the spine, ruled and
 ; written, the lines running across the pages
 (book at deg) (: u "(book [x y z] bearing)" o (P at u) th (N deg u) f (ahead th) r [(f 2) 0.0 -(f 0)]
   (L a h b) (v+ o (v+ (v* a r) (v+ (v* b f) [0.0 h 0.0])))
   (flat a0 a1 b0 b1 y0 y1) (whole (solid (prism (y1 - y0) [(L a0 y0 b0) (L a1 y0 b0) (L a1 y0 b1) (L a0 y0 b1)])))
   cover (texture 16 16 0.2 '((fill (rgb 0.36 0.09 0.07)) (noise 3 0.15)))
   edge (texture 16 8 0.05 '((fill (rgb 0.93 0.91 0.84)) (grid 0 2 1 (shade 0.86))))
   page (laid (texture 32 32 0.16 '((fill (rgb 0.95 0.93 0.86)) (grid 0 4 1 (rgb 0.72 0.76 0.86))
                                    (within 3 1 30 31 (patches 1.5 0.22 (rgb 0.16 0.18 0.32)))
                                    (cols 3 4 (rgb 0.86 0.6 0.6))))
              -th [0 0])
   [(skin {'all cover} (flat -0.172 0.172 -0.122 0.122 0.0 0.004))
    (skin {'floor page 'walls edge 'ceiling cover} (flat -0.165 -0.006 -0.115 0.115 0.004 0.016))
    (skin {'floor page 'walls edge 'ceiling cover} (flat 0.006 0.165 -0.115 0.115 0.004 0.016))])
 ; ..a pencil: its painted hexagon, a ferrule and eraser at one end, the wood sharpened to
 ; its lead at the other
 (pencil at deg c) (: u "(pencil [x y z] bearing (rgb r g b))" o (P at u) f (ahead (N deg u))
   _ (? (!(colour? c)) (no u c))
   (pt k) (v+ o (v+ (v* k f) [0.0 0.0036 0.0]))
   (tx c) (texture 8 8 0.05 [['fill ['rgb (c 0) (c 1) (c 2)]] '(noise 2 0.1)])
   [(rod (pt 0.013) (pt 0.163) 0.0035 6 (tx c))
    (rod (pt 0.004) (pt 0.014) 0.0037 8 (tx [0.75 0.76 0.78]))
    (rod (pt 0.0) (pt 0.005) 0.0033 8 (tx [0.9 0.55 0.55]))
    (rod (pt 0.163) (pt 0.174) 0.0024 6 (tx [0.86 0.7 0.5]))
    (rod (pt 0.174) (pt 0.179) 0.0011 6 (tx [0.12 0.12 0.13]))])
 (strip-light at) (part 'strip [['at (P at "(strip-light [x y z])")] ['across 0] ['how ()]])
 (bulb at c) (: u "(bulb [x y z] (rgb r g b))" (colour? c ? (part 'bulb [['at (P at u)] ['c c] ['how ()]]) (no u c)))
 ; ..a sconce: a box from a little inside the wall cut corner to corner, keeping the wall's
 ; side, and its lamp; n and d kept as points a metre on, as a decal's are
 sconce-d 0.25
 (sconce at n d len t) (: u "(sconce [x y z] [nx ny nz] [dx dy dz] length TEXTURE)" a (P at u) nv (P n u) dv (P d u) L (N len u) s sconce-d
   lv [(nv 1 * dv 2 - nv 2 * dv 1) (nv 2 * dv 0 - nv 0 * dv 2) (nv 0 * dv 1 - nv 1 * dv 0)]
   (pt kn kd kl) (map (i \ a i + kn * nv i + kd * dv i + kl * lv i) ^3)
   p0 (pt -0.05 -s (-0.5 * L)) p1 (pt s 0.0 (0.5 * L))
   (? (!(texture? t)) (no u t)
      [(whole (skin {'all t} (cut (pt s 0.0 0.0) (pt 0.0 -s 0.0) (pt s 0.0 1.0)
                              (solid (box (map (i \ min (p0 i) (p1 i)) ^3) (map (i \ max (p0 i) (p1 i)) ^3))))))
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
 (orb at r t turns) (: u "(orb [x y z] radius TEXTURE turns)"
   (? (!(num? r) || r <= 0) (no u r) (!(texture? t)) (no u t)
      (part 'orb [['at (P at u)] ['r (N r u)] ['tex t] ['turns (N turns u)]])))
 (tether h l) (? (!(num? h) || h <= 0) (no "(tether h LIFT)" h) (kind? l ['lift]) (with l 'tether (1.0 * h)) (no "(tether h LIFT)" l))
 (playing d) (kind? d ['ad] ? (with d 'music 1) (no "(playing AD)" d))
 (fence ps h t) (: u "(fence [[x y z] ..] height TEXTURE)"
   (? (!(two? ps) || #ps < 2 || !(all pt? ps)) (no u ps) (!(num? h) || h <= 0) (no u h) (!(texture? t)) (no u t)
      (part 'fence [['pts (map (map f) ps)] ['h (f h)] ['tex t]])))
 (wooden q) (kind? q ['fence] ? (with q 'wood 1) (no "(wooden (fence ..))" q))
 (gate a b h deg t) (: u "(gate [x y z] [x y z] height degrees TEXTURE)"
   (? (!(num? h) || h <= 0) (no u h) (!(num? deg)) (no u deg) (!(texture? t)) (no u t)
      (part 'gate [['at (P a u)] ['np (P b u)] ['h (N h u)] ['swing (N deg u)] ['tex t]])))
 ; ..a headstone, its face toward north and then turned: a slab arched over, on a plinth
 (grave at deg nm t) (: u "(grave [x y z] bearing NAME TEXTURE)" p (P at u) d (N deg u) x (p 0) y (p 1) z (p 2)
   (? (!(string? nm)) (no u nm) (!(texture? t)) (no u t)
      [(turn d [x z] [(skin {'all t} (solid (box [(x - 0.19) (y - 0.1) (z - 0.09)] [(x + 0.19) (y + 0.04) (z + 0.09)])))
                      (skin {'all t} (solid (box [(x - 0.14) (y + 0.04) (z - 0.04)] [(x + 0.14) (y + 0.24) (z + 0.04)])))
                      (rod [x (y + 0.24) (z - 0.04)] [x (y + 0.24) (z + 0.04)] 0.14 12 t)])
       (part 'grave [['at p] ['deg d] ['name nm]])]))
 (glow o) (kind? o ['orb] ? (with o 'glow 1) (no "(glow ORB)" o))
 (inward o) (kind? o ['orb] ? (with o 'in 1) (no "(inward ORB)" o))
 (herald at size reach t file nm) (: u "(herald [x y z] size reach TEXTURE FILE ENTRY)"
   (? (!(texture? t)) (no u t)
      (part 'herald ([['at (P at u)] ['size (N size u)] ['reach (N reach u)] ['tex t]] + way-to u file nm))))
 (coarse k o) (: u "(coarse k ORB)"
   (? (!(elem k [2 4 8])) (no u k) (kind? o ['orb]) (with o 'coarse k) (no u o)))
 (across s) (kind? s ['strip] ? (with s 'across 1) (no "(across (strip-light ..))" s))
 (troffer s) (kind? s ['strip] ? (with s 'troffer 1) (no "(troffer (strip-light ..))" s))
 (unlit s) (kind? s ['strip 'sign] ? (with s 'unlit 1) (no "(unlit (strip-light ..)) or (unlit (sign ..))" s))
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
 ; --- materials: a texture from its kind and the parameters it changes, a number or [lo hi]
 ; thrown under the seed, or a colour; [w h metres layers feel] of the parameters, g ---
 (sh k) ['shade k]
 (mx c k) ['mix c k]
 materials
  {'wood [{'colour (rgb 0.56 0.39 0.23) 'rings 7 'warp 2.5 'grain 0.2 'knots 0.06 'metres 1.0}
          (g \ [32 64 (g 'metres) [['fill (g 'colour)] ['noise 2 12 (g 'grain)] ['grain (g 'rings) 1.5 (g 'warp) 24 (sh 0.82)]
                                   ['patches 3 (g 'knots) (sh 0.6)]] 'wood])]
   'plank [{'colour (rgb 0.6 0.43 0.26) 'rings 7 'warp 2.5 'grain 0.2 'board 16 'metres 1.6}
           (g \ [64 64 (g 'metres) [['fill (g 'colour)] ['noise 2 12 (g 'grain)] ['grain (g 'rings) 1.5 (g 'warp) 24 (sh 0.85)]
                                    ['grid 0 (g 'board) 1 (sh 0.55)] ['patches 6 0.25 (sh 0.9)]] 'wood])]
   'stone [{'colour (rgb 0.5 0.49 0.46) 'grain 0.15 'cracks 0.5 'lichen 0.0 'metres 2.0}
           (g \ [64 64 (g 'metres) [['fill (g 'colour)] ['noise 3 (g 'grain)] ['patches 6 0.3 (sh 0.85)]
                                    ['cracks 32 28 1 (8.0 * g 'cracks) (sh (1.0 - 0.6 * g 'cracks))]
                                    ['patches 3 (g 'lichen) (mx ['rgb 0.45 0.5 0.25] 0.5)] '(noise 1 0.08)] 'hard])]
   'sandstone [{'colour (rgb 0.72 0.45 0.3) 'pale (rgb 0.86 0.7 0.52) 'beds 9 'warp 1.5 'metres 3.0}
               (g \ [64 64 (g 'metres) [['fill (g 'colour)] '(noise 2 0.08) ['grain (g 'beds) 3 (g 'warp) 40 (mx (g 'pale) 0.35)]
                                        ['grain (0.37 * g 'beds) 1 (g 'warp) 25 (sh 0.85)] ['patches 8 0.2 (sh 0.9)]] 'hard])]
   'brick [{'colour (rgb 0.55 0.25 0.18) 'mortar (rgb 0.75 0.72 0.66) 'w 16 'h 6 'vary 0.25 'metres 0.225}
           (g \ (: w (int (g 'w)) h (int (g 'h)) a (w // 2) m (g 'mortar)
                  [w (2 * h) (g 'metres) [['fill (g 'colour)] ['patches 3 (g 'vary) (sh 0.8)] '(noise 2 0.1)
                                          ['rows 0 1 m] ['rows h (h + 1) m] ['within 0 0 w h ['cols 0 1 m]]
                                          ['within 0 h w (2 * h) ['cols a (a + 1) m]]] 'hard]))]
   'tile [{'a (rgb 0.8 0.8 0.78) 'b (rgb 0.7 0.7 0.68) 'grout (rgb 0.4 0.4 0.4) 'n 32 'metres 0.6}
          (g \ (: n (int (g 'n)) h (n // 2)
                 [n n (g 'metres) [['fill (g 'a)] ['checker h h (g 'b)] '(noise 5 0.1) ['grid h h 1 (g 'grout)]] 'hard]))]
   'cobble [{'colour (rgb 0.45 0.43 0.4) 'grout (rgb 0.2 0.19 0.18) 'size 10 'w 0.12 'vary 0.3 'metres 1.5}
            (g \ [64 64 (g 'metres) [['fill (g 'colour)] '(noise 2 0.15) ['patches 4 (g 'vary) (sh 0.8)]
                                     ['cells (g 'size) (g 'w) (g 'grout)] '(noise 5 0.1)] 'hard])]
   'mud [{'colour (rgb 0.42 0.33 0.24) 'crack (rgb 0.18 0.13 0.09) 'size 14 'w 0.08 'metres 2.0}
         (g \ [64 64 (g 'metres) [['fill (g 'colour)] '(noise 2 0.12) ['patches 5 0.3 (sh 0.9)] ['cells (g 'size) (g 'w) (g 'crack)]] 'soft])]
   'concrete [{'colour (rgb 0.42 0.41 0.4) 'stain 0.18 'ties 0 'metres 6.0}
              (g \ [128 128 (g 'metres) ([['fill (g 'colour)] '(noise 6 0.05) ['patches 6 (g 'stain) (sh 0.88)] ['rows 0 1 (sh 0.88)]
                                          ['rows 64 65 (sh 0.88)]] + (g 'ties > 0.0 ? [['dots 42.667 16 0.8 (sh 0.6)]] ())) 'hard])]
   'metal [{'colour (rgb 0.46 0.48 0.51) 'grain 0.12 'seams 0 'metres 1.0}
           (g \ [32 32 (g 'metres) ([['fill (g 'colour)] ['noise 3 (g 'grain)]]
                                    + (g 'seams > 0.0 ? [['grid 32 32 1 (sh 0.6)] ['dots 8 8 0.8 (sh 0.5)]] ())) 'metal])]
   'cloth [{'colour (rgb 0.16 0.17 0.22) 'nap 0.3 'metres 0.5}
           (g \ [16 16 (g 'metres) [['fill (g 'colour)] ['noise 1 (g 'nap)]] 'soft])]
   'carpet [{'colour (rgb 0.3 0.33 0.39) 'nap 0.25 'metres 2.0}
            (g \ [64 64 (g 'metres) [['fill (g 'colour)] ['noise 1 (g 'nap)] '(noise 8 0.1) ['patches 5 0.2 (sh 0.9)]] 'soft])]
   'gravel [{'colour 0.4 'metres 2.0}
            (g \ [32 32 (g 'metres) [['fill (g 'colour)] '(noise 1 0.35) '(noise 6 0.1) ['patches 4 0.2 (sh 0.85)]] 'hard])]
   'sand [{'colour (rgb 0.8 0.7 0.5) 'ripple 0.0 'metres 2.0}
          (g \ [64 64 (g 'metres) ([['fill (g 'colour)] '(noise 1 0.12) '(noise 8 0.08)]
                                   + (g 'ripple > 0.0 ? [['grain 8 3 (g 'ripple) 20 (sh 0.9)]] ())) 'soft])]
   'soil [{'colour (rgb 0.36 0.27 0.19) 'stones 0.15 'metres 2.0}
          (g \ [64 64 (g 'metres) [['fill (g 'colour)] '(noise 1 0.3) ['patches 5 0.3 (sh 0.8)]
                                   ['patches 2 (g 'stones) (mx ['rgb 0.5 0.48 0.44] 0.5)]] 'soft])]
   'grass [{'colour (rgb 0.3 0.45 0.18) 'dry 0.3 'metres 2.0}
           (g \ [64 64 (g 'metres) [['fill (g 'colour)] '(noise 1 0.35) ['patches 6 (g 'dry) (mx ['rgb 0.62 0.58 0.3] 0.3)]
                                    ['patches 3 0.2 (sh 0.8)]] 'soft])]
   'card [{'colour (rgb 0.62 0.47 0.3) 'tape (rgb 0.7 0.58 0.4) 'metres 0.5}
          (g \ [32 32 (g 'metres) [['fill (g 'colour)] '(noise 2 0.06) ['patches 4 0.15 (sh 0.9)] ['rows 14 18 (g 'tape)]] 'soft])]
   'bark [{'colour (rgb 0.3 0.29 0.27) 'streak 0.3 'marks 0.0 'metres 1.0}
          (g \ [32 64 (g 'metres) [['fill (g 'colour)] ['noise 1 8 (g 'streak)] '(noise 3 0.1) ['patches 4 0.25 (sh 0.85)] ['noise 6 1 (g 'marks)]] 'wood])]}
 (material k s o) (: u "(material KIND seed {PARAM v ..})"
   (? (!(two? (materials k))) (no (u + ", a KIND of " + show (sort (keys materials))) k)
      (!(charm? s && 0 <= s < 1000000)) (no u s) (!(tablet? o)) (no u o)
      (: d (materials k 0)
         _ (each (keys o) (q \ elem q (keys d) ? 0 (no (u + ", " + show k + " takes " + show (sort (keys d))) q)))
         (g q) (peep o q (d q) @ v (colour? v ? ['rgb (v 0) (v 1) (v 2)] (pick s q v)))
         r (materials k 1 g)
         (feel (r 4) (texture (r 0) (r 1) (r 2) (['seed s] . r 3))))))
 ; ..a skin by a material's kind, or as given
 (tex-by t) (nom? t ? (material t 1 {}) t)
 (skin-by t) (skin-of-any (tex-by t))
 ; --- rocks: a box cut by planes thrown round it, each square to the ellipsoid in the box where
 ; it meets it and bite of the way in, so one brush; n of them spread or stacked ---
 rocks {'boulder {'size [[0.8 1.6] [0.6 1.2] [0.7 1.5]] 'cuts [8 12] 'bite [0.0 0.25] 'sink [0.1 0.25]}
        'pebble {'size [[0.05 0.15] [0.03 0.08] [0.05 0.15]] 'cuts [6 9] 'bite [0.0 0.2] 'flat 0.3 'sink 0.1}
        'scree {'size [[0.15 0.4] [0.1 0.25] [0.15 0.4]] 'cuts [6 9] 'bite [0.0 0.25] 'flat 0.2 'sink 0.15}
        'slab {'size [[1.2 2.2] [0.15 0.35] [0.8 1.6]] 'cuts [5 8] 'bite [0.0 0.15] 'flat 0.6 'sink 0.1}
        'standing {'size [[0.8 1.2] [2.4 3.4] [0.5 0.8]] 'cuts [6 9] 'bite [0.0 0.12] 'sink [0.1 0.2]}
        'altar {'size [2.2 0.7 1.0] 'cuts [4 6] 'bite [0.0 0.05] 'flat 0.8 'sink 0.05}
        'outcrop {'size [[0.8 1.6] [0.6 1.2] [0.7 1.5]] 'cuts [8 12] 'bite [0.0 0.25] 'sink [0.1 0.25] 'n [3 5] 'spread 1.2}
        'cairn {'size [[0.25 0.4] [0.12 0.2] [0.25 0.4]] 'cuts [6 9] 'bite [0.0 0.2] 'flat 0.5 'sink 0.05 'n [4 7] 'stack 1 'shrink 0.85}}
 rock-keys ['like 'size 'cuts 'bite 'flat 'sink 'bearing 'n 'spread 'stack 'shrink 'skin]
 (rock-shape q) (? (nom? q) (rocks q)
                   (tablet? q) (: b (peep q 'like ()) a (b = () ? {} (rocks b)) (tablet? a ? (foldl (\ t k (pin t k (q k))) (foldl (\ t k (pin t k (a k))) {} (keys a)) (keys q)))))
 (rock at s q) (: u "(rock [x y z] seed SHAPE)" o (P at u) r (rock-shape q)
   (? (!(tablet? r)) (no (u + ", a SHAPE " + show (sort (keys rocks)) + " or a tablet over one, {'like 'boulder ..}") q)
      (!(charm? s)) (no u s)
      (: _ (each (keys r) (k \ elem k rock-keys ? 0 (no (u + ", a rock takes " + show rock-keys) k)))
         (g e k d) (pick e k (peep r k d))
         n (max 1 (int (g s 'n 1))) sk (skin-by (peep r 'skin 'stone))
         (axes v) (two? v && #v = 3 ? v [v v v])
         ; ..a piece from its foot's middle c under its own seed e, k the share of its size: [brush top]
         (piece c e k) (: sz (axes (peep r 'size 1.0)) h (map (j \ 0.5 * k * pick e ['size j] (sz j)) ^3) H (2.0 * h 1)
           y0 (c 1 - g e 'sink 0.0 * H) m [(c 0) (y0 + h 1) (c 2)] fl (g e 'flat 0.0) bt (peep r 'bite 0.0)
           (plane i) (: w (2.0 * dice e ['w i] - 1.0) a (2.0 * pi * dice e ['a i])
                        wy ((w < 0.0 ? -1.0 1.0) * (1.0 - 0.8 * fl) (abs w)) r0 (sqrt (max 0.0 (1.0 - wy * wy)))
                        d [(r0 * cos a) wy (r0 * sin a)] nn (unit [(d 0 / h 0) (d 1 / h 1) (d 2 / h 2)])
                        p (v+ m (v* (1.0 - pick e ['bite i] bt) [(h 0 * d 0) (h 1 * d 1) (h 2 * d 2)]))
                        e1 (unit (cross nn (abs (nn 1) > 0.9 ? [1.0 0.0 0.0] [0.0 1.0 0.0])))
                        [p (v+ p e1) (v+ p (cross nn e1))])
           b (skin sk (foldl (\ b c (cut (c 0) (c 1) (c 2) b)) (solid (box [(m 0 - h 0) y0 (m 2 - h 2)] [(m 0 + h 0) (y0 + H) (m 2 + h 2)]))
                             (map plane ^(int (g e 'cuts 8)))))
           [(turn (g e 'bearing [0.0 360.0]) [(c 0) (c 2)] [(max (h 0) (max (h 1) (h 2)) < 0.75 ? (with b 'whole 1) b)]) (y0 + H)])
         ; ..each piece on from the last: stacked on its top, else thrown within spread of the first
         st (g s 'stack 0.0 > 0.5) sp (g s 'spread 0.0) kk (g s 'shrink 1.0)
         (go i c k acc) (? (n <= i) (rev acc)
           (: e (seed-of s i) q (piece c e k)
              c2 (st ? [(o 0 + 0.1 * (dice e 'x - 0.5)) (q 1 - 0.02) (o 2 + 0.1 * (dice e 'z - 0.5))]
                       [(o 0 + sp * (2.0 * dice e 'x - 1.0)) (o 1) (o 2 + sp * (2.0 * dice e 'z - 1.0))])
              (go (i + 1) c2 (k * kk) (q 0 . acc))))
         (go 0 o 1.0 ()))))
 ; --- ground: heights (\ x z y) that compose, and a land laid under one ---
 vn (cite 'vec 'vn)
 (fbm s o fold) (: u "{'scale 'height 'octaves}" sc (N (peep o 'scale 30.0) u) ht (N (peep o 'height 4.0) u)
   n (int (peep o 'octaves 4)) k (key s) nm (foldl (\ a i (a + i 0.5)) 0.0 ^n)
   (\ x z (ht * foldl (\ a i (a + i 0.5 * fold (vn (x / sc * i 2) (z / sc * i 2) (k + 31 * i)))) 0.0 ^n / nm)))
 (hills s o) (fbm s o (v \ 2.0 * v - 1.0))
 (ridges s o) (fbm s o (v \ (1.0 - abs (2.0 * v - 1.0)) @ r (r * r)))
 (dunes o) (: u "(dunes {'bearing 'length 'height})" a (N (peep o 'bearing 0.0) u * pi / 180.0) L (N (peep o 'length 6.0) u)
   ht (N (peep o 'height 2.0) u) sa (sin a) ca (cos a)
   (\ x z ((x * sa + z * ca) / L * 2.0 * pi @ t (ht * (0.5 + 0.5 * sin (t + 0.6 * sin t))))))
 (terrace f step) (: t (N step "(terrace GROUND step)")
   (\ x z (f x z @ v (: b (t * floor (v / t)) (b + t * ease ((v - b) / t) 0.8 1.0)))))
 (mound c r top h) (: u "(mound [x z] radius top height)" (? (!(two? c && #c = 2 && all num? c)) (no u c)
   (\ x z (: dx (x - c 0) dz (z - c 1) (h * (1.0 - ease (sqrt (dx * dx + dz * dz)) top r))))))
 ; ..a channel along the path [[x z] ..]: its bed depth down within w of it, its banks easing up to 2 w
 (channel ps w depth) (: u "(channel [[x z] ..] w depth)"
   (? (!(two? ps && #ps >= 2 && all (q \ two? q && #q = 2 && all num? q) ps)) (no u ps)
      (: (seg a b x z) (: ux (b 0 - a 0) uz (b 1 - a 1) l2 (ux * ux + uz * uz)
                        t (l2 > 0.0 ? (max 0.0 (min 1.0 (((x - a 0) * ux + (z - a 1) * uz) / l2))) 0.0)
                        dx (x - a 0 - t * ux) dz (z - a 1 - t * uz) (dx * dx + dz * dz))
         (\ x z (sqrt (foldl (\ m i (min m (seg (ps i) (ps (i + 1)) x z))) 1e18 ^(#ps - 1)) @ d (0.0 - depth * (1.0 - ease d w (2.0 * w))))))))
 (rise f g) (\ x z (f x z + g x z))
 (blend f g r) (\ x z (smax (f x z) (g x z) r))
 (carve f g r) (\ x z (smin (f x z) (g x z) r))
 ; ..a land through rows of points step apart over two corners, at the ground's heights
 (ground-of t c step gr) (: u "(ground-of SKIN [[x z] [x z]] step GROUND)"
   (? (!(two? c && #c = 2 && all (q \ two? q && #q = 2 && all num? q) c)) (no u c) (!(num? step && step > 0)) (no u step)
      (: (span a b) (: n (max 1 (int (abs (b - a) / step + 0.5))) (map (i \ a + (b - a) * i / n) ^(n + 1)))
         xs (span (f (c 0 0)) (f (c 1 0))) zs (span (f (c 0 1)) (f (c 1 1)))
         (land (tex-by t) (map (z \ map (x \ [x (f (gr x z)) z]) xs) zs)))))
 ; --- furniture: a top on legs, a body, a back, sized by its style and built facing the
 ; bearing, the way one using it faces: a bed's head that way, a desk's sitter, a cabinet's
 ; front toward them ---
 furniture
  {'table {'w 1.4 'd 0.8 'h 0.75 'top 0.04 'legs 'corners 'leg 0.025 'inset 0.03 'apron 0.08 'skin {'top 'plank 'frame 'wood}}
   'desk {'w 1.6 'd 0.8 'h 0.75 'top 0.04 'legs 'panels 'leg 0.02 'inset 0.02 'modesty 0.5 'skin {'top 'plank 'frame 'wood}}
   'chair {'w 0.48 'd 0.48 'h 0.9 'seat 0.45 'top 0.05 'legs 'corners 'leg 0.02 'inset 0.02 'back 1 'arms 0
           'skin {'frame 'wood 'soft 'cloth}}
   'stool {'w 0.36 'd 0.36 'h 0.65 'top 0.04 'legs 'corners 'leg 0.02 'inset 0.02 'skin {'top 'wood 'frame 'wood}}
   'bench {'w 1.5 'd 0.36 'h 0.45 'top 0.05 'legs 'trestle 'leg 0.03 'inset 0.1 'skin {'top 'plank 'frame 'wood}}
   'bed {'w 1.0 'd 2.0 'h 0.3 'back 0.9 'skin {'frame 'wood}}
   'shelf {'w 0.9 'd 0.3 'h 1.8 'top 0.02 'shelves 4 'fill () 'fill-w [0.02 0.05] 'skin {'frame 'wood}}
   'cabinet {'w 0.5 'd 0.6 'h 1.3 'drawers 4 'doors 0 'skin {'body 'metal 'frame 'metal}}
   'counter {'w 2.0 'd 0.6 'h 0.9 'top 0.04 'over 0.03 'drawers 0 'doors 2 'skin {'body 'wood 'top 'stone 'frame 'metal}}
   'crate {'w 0.5 'd 0.35 'h 0.3 'top 0.015 'slats 0 'skin {'frame 'wood}}
   'carton {'w 0.5 'd 0.4 'h 0.35 'skin {'body 'card}}
   'sofa {'w 1.9 'd 0.9 'h 0.85 'seat 0.42 'arms 1 'skin {'soft 'cloth 'frame 'wood}}}
 furnish-keys ['w 'd 'h 'top 'legs 'leg 'inset 'apron 'modesty 'seat 'back 'arms 'shelves 'fill 'fill-w 'drawers 'doors 'over 'slats 'seed 'skin]
 book-colours [(rgb 0.36 0.09 0.07) (rgb 0.1 0.2 0.36) (rgb 0.14 0.3 0.16) (rgb 0.55 0.45 0.2) (rgb 0.2 0.2 0.22) (rgb 0.6 0.3 0.12)]
 (furnish k at deg st) (: u "(furnish KIND [x y z] bearing {PARAM v ..})" o (P at u) dd (N deg u)
   (? (!(tablet? (furniture k))) (no (u + ", a KIND of " + show (sort (keys furniture))) k)
      (!(tablet? st)) (no u st)
      (: _ (each (keys st) (q \ elem q furnish-keys ? 0 (no (u + ", furniture takes " + show furnish-keys) q)))
         df (furniture k) s (int (peep st 'seed 1))
         ; ..a parameter: the style's, else the kind's; a number or [lo hi] thrown under the seed
         (g q) (peep st q (df q) @ v (num? v || (two? v && #v = 2 && all num? v) ? (pick s q v) v))
         sks (foldl (\ t q (pin t q (st 'skin q))) (foldl (\ t q (pin t q (df 'skin q))) {} (keys (df 'skin))) (keys (peep st 'skin {})))
         (role r) (skin-by (peep sks r (peep sks 'frame 'wood)))
         ; ..a box between two corners, the middle of the foot the origin, x across and z ahead
         (bx x0 y0 z0 x1 y1 z1 r) (fit (role r) (box [(o 0 + x0) (o 1 + y0) (o 2 + z0)] [(o 0 + x1) (o 1 + y1) (o 2 + z1)]))
         W (0.5 * g 'w) D (0.5 * g 'd) H (g 'h) T (peep st 'top (peep df 'top 0.0) @ t (pick s 'top t)) L (g 'leg) I (g 'inset)
         (post x z y1) (bx (x - L) 0.0 (z - L) (x + L) y1 (z + L) 'frame)
         (sides y1) (map (sx \ bx (sx * (W - I - L) - L) 0.0 (I - D) (sx * (W - I - L) + L) y1 (D - I) 'frame) [-1 1])
         ; ..legs from the floor up to y1
         (legs y1) (g 'legs @
           'corners (map (c \ post (c 0 * (W - I - L)) (c 1 * (D - I - L)) y1) [[-1 -1] [1 -1] [-1 1] [1 1]])
           'panels (sides y1)
           'trestle (sides y1 + [(bx (I - W) (0.15 * y1) (0.0 - L) (W - I) (0.15 * y1 + 2.0 * L) L 'frame)])
           'pedestal (: r (0.6 * min W D) [(bx (-3.0 * L) 0.0 (-3.0 * L) (3.0 * L) y1 (3.0 * L) 'frame) (bx (0.0 - r) 0.0 (0.0 - r) r 0.03 r 'frame)])
           'star ([(bx (0.0 - L) 0.09 (0.0 - L) L y1 L 'frame) (bx -0.28 0.06 -0.02 0.28 0.09 0.02 'frame) (bx -0.02 0.06 -0.28 0.02 0.09 0.28 'frame)]
                  + map (c \ bx (c 0 - 0.025) 0.0 (c 1 - 0.025) (c 0 + 0.025) 0.06 (c 1 + 0.025) 'feet) [[0.26 0.0] [-0.26 0.0] [0.0 0.26] [0.0 -0.26]])
           ())
         ; ..fronts toward the user at -z: n drawers one over another, or n doors side by side
         (fronts y0 y1) (: nd (int (g 'drawers)) nr (int (g 'doors)) e 0.008 z0 (0.0 - D - 0.012) z1 (0.0 - D) ym (0.5 * (y0 + y1))
           (? (0 < nd) (catmap (i \ (: a (y0 + (y1 - y0) * i / nd + e) b (y0 + (y1 - y0) * (i + 1) / nd - e) m (0.5 * (a + b))
                                      [(bx (e - W) a z0 (W - e) b z1 'body) (bx -0.06 (m - 0.01) (z0 - 0.02) 0.06 (m + 0.01) z0 'frame)]))
                               ^nd)
              (0 < nr) (catmap (j \ (: a (2.0 * W * j / nr - W + e) b (2.0 * W * (j + 1) / nr - W - e) hx (j % 2 = 0 ? (b - 0.05) (a + 0.05))
                                      [(bx a (y0 + e) z0 b (y1 - e) z1 'body) (bx (hx - 0.01) (ym - 0.06) (z0 - 0.02) (hx + 0.01) (ym + 0.06) z0 'frame)]))
                               ^nr)
              ()))
         ; ..one row along a shelf from x0 to x1 at y, MAKE given each slot as line-up does
         (row x0 x1 y i mk) (line-up (seed-of s i) [(o 0 + x0) (o 1 + y) (o 2)] [(o 0 + x1) (o 1 + y) (o 2)] mk {'w (peep st 'fill-w (df 'fill-w)) 'gap 0.0})
         ; ..books under a gap gp: each its own height, depth and cover
         (books gp bk) (\ a dg e w (: bh (gp * pick e 'h [0.6 0.9]) bd (2.0 * D * pick e 'd [0.6 0.85]) c (bk (int (#bk * dice e 'c)))
                                     (fit c (box [(a 0 - 0.5 * w) (a 1) (o 2 + D - bd)] [(a 0 + 0.5 * w - 0.002) (a 1 + bh) (o 2 + D)]))))
         parts
          (k @
           'chair (: S (g 'seat) [(bx (0.0 - W) (S - T) (0.0 - D) W S D 'soft) (legs (S - T))
                                  (g 'back > 0.0 ? [(bx (0.0 - W) S (0.0 - D) W H (0.06 - D) 'soft)] ())
                                  (g 'arms > 0.0 ? (map (sx \ bx (sx * W - 0.03) (S + 0.2) (0.0 - D) (sx * W + 0.03) (S + 0.24) (0.6 * D) 'frame) [-1 1]) ())])
           'bed [(bx (0.0 - W) 0.0 (0.0 - D) W H D 'frame) (bx (0.0 - W) 0.0 (D - 0.05) W (g 'back) D 'frame)
                 (whole (skin {'floor (mattress-top ()) 'walls (mattress-side ()) 'ceiling (mattress-under ())}
                              (solid (box [(o 0 - W + 0.02) (o 1 + H) (o 2 - D + 0.02)] [(o 0 + W - 0.02) (o 1 + H + 0.22) (o 2 + D - 0.06)]))))]
           'shelf (: n (max 1 (int (g 'shelves))) t (max 0.012 T) gp ((H - 2.0 * t) / n - t) (at-y i) (t + (H - 2.0 * t) * i / n)
                    [(bx (0.0 - W) 0.0 (0.0 - D) (t - W) H D 'frame) (bx (W - t) 0.0 (0.0 - D) W H D 'frame)
                     (bx (0.0 - W) 0.0 (D - 0.01) W H D 'frame)
                     (map (i \ bx (t - W) (at-y i - t) (0.0 - D) (W - t) (at-y i) (D - 0.01) 'frame) ^(n + 1))
                     (g 'fill @ () ()
                        'books (: bk (map (c \ material 'cloth 1 {'colour c}) book-colours)
                                 (map (i \ row (t - W + 0.005) (W - t - 0.005) (at-y i) i (books gp bk)) ^n))
                        mk (map (i \ row (t - W) (W - t) (at-y i) i mk) ^n))])
           'cabinet [(bx (0.0 - W) 0.0 (0.0 - D) W H D 'body) (fronts 0.0 H)]
           'counter (: v (g 'over) [(bx (0.0 - W) 0.0 (0.0 - D) W (H - T) D 'body) (fronts 0.08 (H - T)) (bx (0.0 - W - v) (H - T) (0.0 - D - v) (W + v) H D 'top)])
           'crate (: t (max 0.008 T) n (int (g 'slats))
                    (wall x0 z0 x1 z1) (? (0 < n) (map (i \ bx x0 (t + (H - t) * i / n) z0 x1 (t + (H - t) * (i + 0.6) / n) z1 'frame) ^n)
                                          [(bx x0 t z0 x1 H z1 'frame)])
                    [(bx (0.0 - W) 0.0 (0.0 - D) W t D 'frame) (wall (0.0 - W) (0.0 - D) W (t - D)) (wall (0.0 - W) (D - t) W D)
                     (wall (0.0 - W) (t - D) (t - W) (D - t)) (wall (W - t) (t - D) W (D - t))])
           'carton [(bx (0.0 - W) 0.0 (0.0 - D) W H D 'body)]
           'sofa (: S (g 'seat) aw (g 'arms > 0.0 ? 0.18 0.0)
                   [(map (c \ bx (c 0 * (W - 0.06) - 0.03) 0.0 (c 1 * (D - 0.06) - 0.03) (c 0 * (W - 0.06) + 0.03) 0.1 (c 1 * (D - 0.06) + 0.03) 'frame)
                         [[-1 -1] [1 -1] [-1 1] [1 1]])
                    (bx (0.0 - W) 0.1 (0.0 - D) W (S - 0.12) D 'soft) (bx (aw - W) (S - 0.12) (0.22 - D) (W - aw) S D 'soft)
                    (bx (0.0 - W) (S - 0.12) (0.0 - D) W H (0.22 - D) 'soft)
                    (aw > 0.0 ? [(bx (0.0 - W) (S - 0.12) (0.22 - D) (aw - W) (S + 0.2) D 'soft)
                                 (bx (W - aw) (S - 0.12) (0.22 - D) W (S + 0.2) D 'soft)] ())])
           ; ..a table, desk, stool or bench: a top on legs, an apron under it, a panel m high at the back
           (: y (H - T) a (g 'apron) m (g 'modesty)
             [(bx (0.0 - W) y (0.0 - D) W H D 'top) (legs y)
              (num? a && a > 0.0 ? [(bx (I + L - W) (y - a) (D - I - L - 0.02) (W - I - L) y (D - I - L) 'frame)
                                    (bx (I + L - W) (y - a) (I + L - D) (W - I - L) y (I + L + 0.02 - D) 'frame)] ())
              (num? m && m > 0.0 ? [(bx (I + 2.0 * L - W) (y - 0.06 - m) (D - 0.1) (W - I - 2.0 * L) (y - 0.06) (D - 0.07) 'frame)] ())]))
         (turn dd [(o 0) (o 2)] parts))))
 ; --- plants: a species grown from seed as grove grows the tree of heaven, its habit as data
 ; (grove-habit): a trunk, levels of limbs each off the last, ends, a clump off the foot ---
 plants
  {'ailanthus {'height [6.6 7.4] 'lean 0.02 'crook 0.08 'girth [0.3 0.18] 'crown 3.0
               'levels [{'n 2 'len [2.6 3.8] 'up 0.6 'out 0.35 'pieces 6 'r [0.16 0.07] 'along [0.95 1.0] 'head [9 13]}
                        {'n [2 3] 'len [2.6 3.8] 'up 0.4 'out 0.9 'pieces 7 'r [0.06 0.022] 'bend 0.35 'droop 0.07 'along [0.3 0.9] 'twigs [0.4 1.0]}]
               'leaf {'kind 'pinnate} 'fruit {'odds 0.3}}
   'oak {'height [2.6 3.4] 'lean 0.04 'crook 0.12 'girth [0.45 0.32] 'crown 1.8
         'levels [{'n [4 5] 'len [3.0 4.2] 'up 0.25 'out 0.7 'pieces 5 'r [0.22 0.08] 'bend 0.5 'along [0.8 1.0]}
                  {'n [3 4] 'len [1.6 2.6] 'up 0.15 'out 0.8 'pieces 4 'r [0.07 0.025] 'bend 0.6 'droop 0.04 'along [0.3 1.0] 'twigs [0.3 0.7]}]
         'leaf {'kind 'simple 'pairs [4 7] 'len [0.02 0.05] 'leaflet [0.12 0.18] 'wide 0.4 'colour (rgb 0.2 0.32 0.1) 'every 1 'grow 1.3}
         'bark {'colour (rgb 0.27 0.25 0.22) 'streak 0.45}}
   'birch {'height [8.0 10.5] 'lean 0.03 'crook 0.05 'girth [0.14 0.05] 'pieces 6 'crown 2.5
           'levels [{'n [7 10] 'len [1.6 3.0] 'up 0.45 'out 0.55 'pieces 4 'r [0.045 0.015] 'droop 0.1 'along [0.3 1.0] 'cone 0.6 'twigs [0.3 0.6] 'leaves 3}]
           'leaf {'kind 'simple 'pairs [4 6] 'len [0.02 0.04] 'leaflet [0.07 0.1] 'wide 0.45 'colour (rgb 0.3 0.45 0.13) 'every 1 'grow 1.4}
           'bark {'colour (rgb 0.86 0.84 0.8) 'streak 0.1 'marks 0.6}}
   'pine {'height [9.0 12.0] 'lean 0.01 'crook 0.03 'girth [0.28 0.06] 'pieces 8 'crown 2.5
          'levels [{'n [16 22] 'len [2.4 3.4] 'up -0.05 'out 1.0 'pieces 3 'r [0.05 0.015] 'bend 0.15 'droop 0.08 'along [0.25 0.98] 'cone 0.95 'twigs [0.2 0.5] 'leaves 3}]
          'leaf {'kind 'needle 'pairs [10 14] 'leaflet [0.18 0.26] 'wide 0.25 'colour (rgb 0.12 0.24 0.1) 'every 2 'grow 2.0}
          'bark {'colour (rgb 0.36 0.24 0.18) 'streak 0.35}}
   'willow {'height [3.5 4.5] 'lean 0.06 'crook 0.15 'girth [0.4 0.26] 'crown 1.0
            'levels [{'n [4 6] 'len [2.4 3.4] 'up 0.6 'out 0.5 'pieces 5 'r [0.15 0.05] 'along [0.8 1.0]}
                     {'n [5 8] 'len [3.0 4.5] 'up 0.3 'out 0.6 'pieces 8 'r [0.02 0.008] 'bend 0.2 'droop 0.35 'along [0.2 1.0] 'leaves 3}]
            'leaf {'kind 'simple 'pairs [2 3] 'len [0.01 0.02] 'leaflet [0.1 0.15] 'wide 0.3 'colour (rgb 0.34 0.48 0.17) 'every 1 'grow 1.6}}
   'shrub {'height 0.0 'levels [{'n [6 10] 'len [0.8 1.4] 'up 0.9 'out 0.5 'pieces 3 'r [0.025 0.01] 'bend 0.5 'droop 0.02 'along [0.0 0.0] 'leaves 2}]
           'leaf {'kind 'simple 'pairs [3 5] 'len [0.01 0.03] 'leaflet [0.06 0.09] 'colour (rgb 0.18 0.3 0.1) 'every 1 'grow 1.3}}
   'grass {'height 0.0 'clump [40 60] 'splay 0.7 'leaf {'kind 'blade 'len [0.3 0.6] 'bow 0.8 'wide 0.2 'colour (rgb 0.32 0.52 0.14) 'every 1 'grow 1.0}}
   'reed {'height 0.0 'clump [12 18] 'splay 0.3 'leaf {'kind 'blade 'len [1.4 2.0] 'bow 0.5 'wide 0.18 'colour (rgb 0.42 0.5 0.22) 'every 1 'grow 1.0}}
   'fern {'height 0.0 'clump [8 12] 'splay 0.9 'leaf {'kind 'frond 'len [0.5 0.9] 'pairs [12 16] 'leaflet [0.08 0.12] 'wide 0.35 'arch 0.5 'colour (rgb 0.18 0.36 0.1) 'every 1 'grow 1.3}}
   'dead {'like 'oak 'leaf () 'ends 'sprig}}
 plant-keys ['like 'height 'lean 'crook 'girth 'pieces 'crown 'levels 'ends 'clump 'splay 'leaf 'fruit 'bark]
 limb-keys ['n 'len 'up 'out 'pieces 'r 'bend 'droop 'along 'cone 'head 'twigs 'leaves]
 leaf-keys ['kind 'len 'pairs 'leaflet 'wide 'arch 'tip 'bow 'colour 'every 'grow]
 ; ..a species: a preset, or a tablet, {'like PRESET ..} changing one, its own keys over its;
 ; no leaf none, and no fruit unless it says
 (species q) (: u "(plant [x y z] seed SPECIES)"
   (over t ks w) (? (!(tablet? t)) (no u t) (: _ (each (keys t) (k \ elem k ks ? 0 (no (u + ", " + w + " takes " + show ks) k))) t))
   (like q n) (? (n > 4) (no u q)
                 (nom? q) (tablet? (plants q) ? (like (plants q) (n + 1)) (no (u + ", a SPECIES of " + show (sort (keys plants))) q))
                 (: t (over q plant-keys "a plant")
                    (t 'like @ () t l (: b (like l (n + 1)) (foldl (\ a k (pin a k (t k))) (foldl (\ a k (pin a k (b k))) {} (keys b)) (filter (k \ k != 'like) (keys t)))))))
   sp (like q 0) lf (peep sp 'leaf {} @ () {'kind 'none} l (over l leaf-keys "a leaf"))
   _ (each (peep sp 'levels ()) (l \ over l limb-keys "a level"))
   _ (elem (peep lf 'kind 'pinnate) ['pinnate 'frond 'simple 'needle 'blade 'none] ? 0 (no (u + ", a leaf's 'kind 'pinnate 'frond 'simple 'needle 'blade") (lf 'kind)))
   (pins sp 'leaf lf 'fruit (peep sp 'fruit {'odds 0.0})))
 (plant at seed q) (: u "(plant [x y z] seed SPECIES)" p (P at u)
   (? (!(charm? seed && 0 <= seed < 1000000)) (no u seed)
      (: sp (species q) bk (peep sp 'bark {})
         (part 'tree [['at p] ['seed seed] ['tex (texture? bk ? bk (nom? bk ? (material bk 1 {}) (material 'bark 1 bk)))] ['species sp]]))))
 (feel k t) (: u "(feel 'soft TEXTURE)"
   (? (!(elem k ['soft 'hard 'wood 'metal])) (no u k) (!(texture? t)) (no u t) (with t 'feel k)))
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
 (flat x) (? (tablet? x) [x] (atom? x) () (catmap flat x))
 (re g b p) (: q (foldl (\ q k (with q k (g (p k)))) p (filter (k \ elem k (keys p)) ['at 'lo 'hi 'np 'up]))
   q2 (elem 'pts (keys q) ? (with q 'pts (map g (q 'pts))) q)
   q3 (elem 'cuts (keys q2) ? (with q2 'cuts (map (map g) (q2 'cuts))) q2)
   q4 (elem 'door (keys q3) ? (with q3 'door (re g b (q3 'door))) q3)
   q5 (elem 'rows (keys q4) ? (with q4 'rows (map (map (p \ p = () ? () (g p))) (q4 'rows))) q4)
   q6 (elem 'trunk (keys q5) ? (with q5 'trunk (map (s \ [(g (s 0)) (g (s 1)) (s 2)]) (q5 'trunk))) q5)
   (elem 'deg (keys q6) ? (with q6 'deg (b (q6 'deg))) q6))
 (repeat n d ps) (: u "(repeat n [dx dy dz] PARTS)" dd (P d u)
   (charm? n ? (catmap (i \ map (p \ xf-on [1.0 0.0 0.0 1.0 (i * dd 0) (i * dd 2)] (re (p \ [(p 0 + i * dd 0) (p 1 + i * dd 1) (p 2 + i * dd 2)]) (b \ b) p)) (flat ps)) ^n) (no u n)))
 (move d ps) (: u "(move [dx dy dz] PARTS)" dd (P d u) (map (p \ xf-on [1.0 0.0 0.0 1.0 (dd 0) (dd 2)] (re (p \ [(p 0 + dd 0) (p 1 + dd 1) (p 2 + dd 2)]) (b \ b) p)) (flat ps)))
 ; ..a turn: off the square a box's four corners a prism's plan, a neon's facing swung too
 (turn deg c ps) (: u "(turn degrees [x z] PARTS)" d (N deg u)
   cc (two? c && #c = 2 && all num? c ? (map f c) (no u c)) x0 (cc 0) z0 (cc 1)
   q (floor (d / 90.0 + 0.5)) sq (d - 90.0 * q @ e (-1e-9 < e && e < 1e-9)) qn ((q % 4 + 4) % 4)
   co (sq ? (qn @ 0 1.0 1 0.0 2 -1.0 3 0.0) (cos (d * pi / 180.0)))
   si (sq ? (qn @ 0 0.0 1 1.0 2 0.0 3 -1.0) (sin (d * pi / 180.0)))
   (sw v) [(v 0 * co + v 2 * si) (v 1) (v 2 * co - v 0 * si)]
   (g p) (: s (sw [(p 0 - x0) (p 1) (p 2 - z0)]) [(s 0 + x0) (s 1) (s 2 + z0)])
   xf [co si -si co (x0 - co * x0 - si * z0) (z0 + si * x0 - co * z0)]
   (prism-of b) (: a (lo2 (b 'lo) (b 'hi)) z (hi2 (b 'lo) (b 'hi))
     (foldl (\ t k (elem k ['lo 'hi 'kind] ? t (pin t k (b k)))) {'kind 'prism 'h (z 1 - a 1)
            'pts [[(a 0) (a 1) (a 2)] [(z 0) (a 1) (a 2)] [(z 0) (a 1) (z 2)] [(a 0) (a 1) (z 2)]]} (keys b)))
   (one p) (: k (p 'kind)
     (? (!sq && elem k ['room 'door 'pane 'grav 'car 'strip]) (no (u + ", a room, street, door, window, grav, train or strip light a quarter at a time") d)
        (: p1 (!sq && k = 'box ? (prism-of p) p) p2 (k = 'strip && qn % 2 = 1 ? (with p1 'across (1 - p1 'across)) p1)
           p3 (k = 'sign && elem 'n (keys p2) ? (with p2 'n (sw (p2 'n))) p2)
           (xf-on xf (re g (b \ b + d) p3)))))
   (map one (flat ps)))
 ; ..a mirror turns a drape over, so its rows run back to keep its front
 (flip p) (kind? p ['drape] ? (with p 'rows (map rev (p 'rows))) p)
 (mirror-x c ps) (: x (N c "(mirror-x c PARTS)") l (flat ps) (l + map (p \ xf-on [-1.0 0.0 0.0 1.0 (2.0 * x) 0.0] (flip (re (p \ [(2.0 * x - p 0) (p 1) (p 2)]) (b \ 0.0 - b) p))) l))
 (mirror-z c ps) (: z (N c "(mirror-z c PARTS)") l (flat ps) (l + map (p \ xf-on [1.0 0.0 0.0 -1.0 0.0 (2.0 * z)] (flip (re (p \ [(p 0) (p 1) (2.0 * z - p 2)]) (b \ 180.0 - b) p))) l))
 ; --- the level: its parts sorted into what the world builds from ---
 (lo2 a b) (map (k \ min (a k) (b k)) ^3)
 (hi2 a b) (map (k \ max (a k) (b k)) ^3)
 (shape-of b) (? (b 'kind = 'prism) (: y0 (b 'pts 0 1) {'prism [y0 (y0 + b 'h) (map (p \ [(p 0) (p 2)]) (b 'pts))]})
                 {'box [(lo2 (b 'lo) (b 'hi)) (hi2 (b 'lo) (b 'hi))]})
 ; textures named: the defaults by their place, every other by its number
 (level-of name ps) (: l (flat ps) bad (filter (p \ !(tablet? p) || !(brush? p || elem (p 'kind) ['start 'shot 'door 'car 'strip 'bulb 'sconce 'flame 'poster 'sign 'decal 'drape 'pane 'grav 'ball 'plush 'tree 'sky 'smog 'twinkle 'gravity 'surface 'pocket 'lift 'deck 'speaker 'ambient 'skylight 'hum 'ad 'spin 'orb 'fence 'gate 'grave 'textures 'entry 'sleep 'fall 'herald])) l)
   (of k) (filter (p \ p 'kind = k) l)
   bs (filter brush? l)
   dflt (foldl (\ t p (foldl (\ t k (pin t k (p 'set k))) t (keys (p 'set)))) {} (of 'textures))
   used (foldl (\ a t (elem t a ? a (a + [t]))) () (catmap (b \ map (bare * b 'skin) (sort (keys (b 'skin)))) bs
                                                     + map (d \ d 'tex) (of 'decal + of 'drape + of 'pane + of 'ad + of 'tree)
                                                     + map (d \ d 'glass) (filter (d \ d 'glass != ()) (of 'door))
                                                     + catmap (s \ [(s 't1) (s 't2)]) (of 'spin) + map (o \ o 'tex) (of 'orb + of 'lift + of 'gate + of 'fence + of 'herald)))
   (tname t) (foldl (\ a i (used i = t ? i a)) () ^#used)
   (skin-of b) (: s (b 'skin) (catmap (k \ (: (e c) ([c (tname (bare (s k)))] + lay (s k)) (k @ 'all (map e ['wall 'floor 'ceiling]) [(e (k @ 'walls 'wall k))])))
                                       (filter (k \ elem k (keys s)) ['all 'walls 'floor 'ceiling])))
   (tex nm t) (: b (bare t) {'name nm 'w (b 'w) 'h (b 'h) 'm (b 'm) 'layers (b 'layers) 'feel (peep b 'feel 'hard) 'lay (kind? t ['laid] ? [(t 'deg) (t 'off)] ())})
   (? (!(string? name)) (no "(level NAME PART ..)" name)
      (two? bad) (scare 'level ("not a part: " + show <bad))
      (#(of 'pocket) > 1 || (two? (of 'pocket) && atom? (of 'surface))) (scare 'level "one pocket to a level, and that on a surface")
      {'kind 'level 'name name
       'start (of 'start @ () {'at [0.0 0.0] 'y 0.0 'deg 0.0 'pitch 0.0}
                          s (: a (<s 'at) {'at [(a 0) (a 2)] 'y (a 1) 'deg (<s 'deg) 'pitch (<s 'pitch)}))
       'entries (map (e \ (: a (e 'at) {'name (e 'name) 'at [(a 0) (a 2)] 'y (a 1) 'deg (e 'deg) 'pitch (e 'pitch) 'bed (peep e 'bed 0) 'foot a}))
                     (of 'entry))
       'sleeps (map (q \ {'at (q 'at) 'deg (q 'deg) 'file (q 'file) 'entry (q 'entry)}) (of 'sleep))
       'falls (map (q \ {'y (q 'y) 'file (q 'file) 'entry (q 'entry)}) (of 'fall))
       'heralds (map (h \ {'at (h 'at) 'size (h 'size) 'reach (h 'reach) 'tex (tname (h 'tex)) 'file (h 'file) 'entry (h 'entry)}) (of 'herald))
       'shots (map (s \ (: k (s 'sky)
                         {'secs (s 'secs) 'deg (s 'deg) 'pitch (s 'pitch)
                          'at (tablet? k ? () (s 'at)) 'sky (tablet? k ? {'hour (k 'hour) 'cover (k 'cover) 'smog 0.0 'twinkle 1.0} ())}))
                   (of 'shot))
       'rooms (map (r \ (: a (lo2 (r 'lo) (r 'hi)) b (hi2 (r 'lo) (r 'hi)) [(a 0) (a 2) (b 0) (b 2) (b 1) (a 1)])) (of 'room))
       'brushes (map (b \ b 'kind = 'land ? {'air 0 'land (b 'rows) 'skin (skin-of b) 'src (b 'src)}
                         {'air (b 'kind @ 'room 1 (b 'air)) 'shape (shape-of b) 'cuts (b 'cuts) 'skin (skin-of b) 'whole (peep b 'whole 0) 'open (peep b 'open 0) 'sheer (peep b 'sheer 0) 'src (b 'src) 'xf (peep b 'xf xf-id)}) bs)
       'doors (map (d \ (: a (d 'at) [(a 0) (a 2) (d 'w) (d 'h) (a 1) (peep d 'hand 0) (d 'glass @ () () g (tname g))])) (of 'door))
       'darks (map (r \ [(lo2 (r 'lo) (r 'hi)) (hi2 (r 'lo) (r 'hi))]) (filter (r \ peep r 'dark 0) (of 'room)))
       'trees (map (m \ {'at (m 'at) 'seed (m 'seed) 'tex (tname (m 'tex)) 'vine (peep m 'vine 0) 'xf (peep m 'xf xf-id) 'size (m 'size)
                          'burnt (peep m 'burnt 0) 'cuts (m 'cuts) 'hole (peep m 'hole 0)}
                         @ t (tablet? (m 'species) ? (pin t 'species (m 'species)) t))
                   (of 'tree))
       'cars (map (c \ (: a (c 'door 'at) {'lo (lo2 (c 'lo) (c 'hi)) 'hi (hi2 (c 'lo) (c 'hi))
                                           'door [(a 0) (a 2) (c 'door 'w) (c 'door 'h) (a 1)] 'leave (c 'leave)})) (of 'car))
       'strips (map (s \ (: a (s 'at) {'at [(a 0) (a 2)] 'y (a 1) 'across (s 'across) 'troffer (peep s 'troffer 0) 'unlit (peep s 'unlit 0) 'how (s 'how) 'src (s 'src) 'xf (peep s 'xf xf-id)})) (of 'strip))
       'bulbs (map (b \ {'at (b 'at) 'c (b 'c) 'how (b 'how)}) (of 'bulb))
       'hums (map (h \ {'sound (h 'sound) 'lo (lo2 (h 'lo) (h 'hi)) 'hi (hi2 (h 'lo) (h 'hi))}) (of 'hum))
       'sconces (map (q \ {'at (q 'at) 'np (q 'np) 'up (q 'up) 'len (q 'len) 'how (q 'how)}) (of 'sconce))
       'flames (map (q \ {'pts (q 'pts) 'c (q 'c) 'how (q 'how)}) (of 'flame))
       'posters (map (p \ (: a (p 'at) {'at [(a 0) (a 2) (a 1) (p 'w) (p 'h)] 'file (p 'file)})) (of 'poster))
       'gravs (map (g \ {'lo (g 'lo) 'hi (g 'hi) 'dir (g 'dir)}) (of 'grav))
       'balls (map (b \ b 'at) (of 'ball))
       'plushes (map (p \ {'at (p 'at) 'deg (p 'deg) 'file (p 'file) 'src (p 'src) 'xf (peep p 'xf xf-id)}) (of 'plush))
       'voids (map (r \ [(lo2 (r 'lo) (r 'hi)) (hi2 (r 'lo) (r 'hi))]) (filter (r \ peep r 'sheer 0) (of 'room)))
       'gravity (of 'gravity @ () () g (<g 'by))
       'surface (of 'surface @ () () s {'shape (<s 'shape) 'lx (<s 'lx) 'lz (<s 'lz)})
       'pocket (of 'pocket @ () () p {'at (<p 'at) 'd (<p 'd)})
       'lifts (map (c \ {'at (c 'at) 'w (c 'w) 'rise (c 'rise) 'tether (peep c 'tether 0.0) 'tex (tname (c 'tex))}) (of 'lift))
       'decks (map (d \ [(lo2 (d 'lo) (d 'hi)) (hi2 (d 'lo) (d 'hi))]) (of 'deck))
       'fences (map (q \ {'pts (q 'pts) 'h (q 'h) 'tex (tname (q 'tex)) 'wood (peep q 'wood 0)}) (of 'fence))
       'gates (map (g \ {'a (g 'at) 'b (g 'np) 'h (g 'h) 'swing (g 'swing) 'tex (tname (g 'tex))}) (of 'gate))
       'graves (map (g \ {'at (g 'at) 'deg (g 'deg) 'name (g 'name)}) (of 'grave))
       'speakers (map (q \ {'at (q 'at) 'lo (q 'lo) 'hi (q 'hi)}) (of 'speaker))
       'ambient (of 'ambient @ () [0.0 0.0 0.0] a (<a 'c))
       'skylight (of 'skylight @ () [0.0 0.0 0.0] a (<a 'c))
       'sky (of 'sky @ () () s {'hour (<s 'hour) 'cover (<s 'cover) 'smog (of 'smog @ () 0.0 m (<m 'k)) 'twinkle (of 'twinkle @ () 1.0 m (<m 'k))})
       'panes (map (p \ {'lo (p 'lo) 'hi (p 'hi) 'tex (tname (p 'tex)) 'brittle (peep p 'brittle 0) 'lens (p 'lens)}) (of 'pane))
       'decals (map (d \ {'at (d 'at) 'np (d 'np) 'up (d 'up) 'w (d 'w) 'h (d 'h) 'tex (tname (d 'tex))}) (of 'decal))
       'drapes (map (d \ {'rows (d 'rows) 'tex (tname (d 'tex)) 'seen (peep d 'seen 0) 'flow (peep d 'flow [0.0 0.0]) 'along (d 'along) 'land (d 'kind @ 'land 1 0)}) (of 'drape + of 'land))
       'ads (map (d \ {'at (d 'at) 'np (d 'np) 'up (d 'up) 'w (d 'w) 'h (d 'h) 'tex (tname (d 'tex)) 'music (peep d 'music 0)}) (of 'ad))
       'spins (map (s \ {'at (s 'at) 'w (s 'w) 'h (s 'h) 't1 (tname (s 't1)) 't2 (tname (s 't2))}) (of 'spin))
       'orbs (map (o \ {'at (o 'at) 'r (o 'r) 'tex (tname (o 'tex)) 'turns (o 'turns) 'coarse (peep o 'coarse 1) 'glow (peep o 'glow 0) 'in (peep o 'in 0) 'src (o 'src) 'xf (peep o 'xf xf-id)}) (of 'orb))
       'signs (map (s \ (: a (s 'at) {'at [(a 0) (a 2) (a 1) (s 'h)] 'n (s 'n) 'text (s 'text) 'c (s 'c) 'how (s 'how) 'unlit (peep s 'unlit 0)})) (of 'sign))
       'textures (map (k \ tex k (dflt k)) (filter (k \ elem k (keys dflt)) ['wall 'floor 'ceiling 'door 'train])
                  + map (i \ tex (tname (used i)) (used i)) ^#used)})))
(:: 'level (\ l ['level-of <l ('list . >l)]))
) ; module scenery
