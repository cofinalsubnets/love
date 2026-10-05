; court -- the inner courtyard of an apartment block, first person in half blocks: the
; level after the shaft. twenty feet by thirty of concrete gone green with moss, a grated
; sump in the middle, four floors of brick painted grey and chipped to the red beneath,
; windows lit and dark, a honey locust leaning in from the north-east corner, and the sky
; at the top of the well.
;
; the long walls run north and south with four sash windows a floor, the west's ground
; floor the lobby, lit all night, and small high ones by the corners -- one each end over
; the west's ground floor, two each end on the east; the short walls carry two narrow ones
; a floor and the stair's three between the floors, the south a black door under them.
; a battlement stands over the middle of each short wall, and a brick block on the roof in
; the north-east corner. cables come down over the parapets, most bundled neat against
; the walls, to holes, window corners and a box on the north wall, a few hanging loose.
; the tree is grove's, grown afresh each run, its trunk leaning toward the middle, fallen
; branches piled at its foot; the sky is sky's, the sun at this hour of this day at a fixed
; latitude under the weather -- clear, partly or mostly cloudy, or overcast, the sky
; drawn smooth or in the grass game's pixels -- and runs on faster than the clock: the
; sun comes in over the rim where it can, low and orange on the top of a wall at either
; end of the day, and windows come on and go off with the hours.
;
; every pixel casts its own ray, so the look tilts as far as the neck does. the scene is
; trays a frame wide: what each ray meets, the stuff there, the sun on it past the rim,
; and the colour out -- 24-bit where COLORTERM says so, else the 256 palette dithered.
; court-new, court-step, court-move and court-frame are pure, gated by test/host/court.l;
; only court-walk and court-run tie the tty. court-walk takes a stage already raised.
;
; run: love lore court  h l or the arrows turn, k j step, u n look up and down;
;                       [ ] an hour back or on, t the time's pace, c the cloud, p rain
;                       or snow, v the sky smooth or in pixels; q or esc leaves
;      love lore court [--date YYYY-MM-DD] [--time HH:MM] [--pace N] [--weather COVER]
;                      [--sky smooth|pixel] [--fall none|rain|snow]   how to start; the
;                      cover, the style, rain and snow words may stand alone
(module (court court-run court-walk court-main court-new court-size court-step court-move
         court-frame court-sun court-light court-clock court-now court-local court-doy court-season
         court-opts court-wx-pick court-fall-pick court-month court-pens court-maps
         tree-grow sun-clear top-h block-h crown-y runs boxes strands wall-of wall-texel stars stars!
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
 ; the battlements: a block over the middle of each short wall, two thirds of a floor
 ; high, and the roof's block as high, along the east wall at its north end and back over
 ; the roof
 block-h (2.0 * floor-h / 3.0) top-h (wall-h + block-h) wall-t 0.45 hb 0.9 cw 1.8
 eye-h 1.6 body-r 0.3
 walk-v 1.4 turn-step 0.07 tilt-step 0.06
 lat (40.7 * pi / 180.0)
 paces [60.0 600.0 1.0 0.0]             ; seconds of the sky a second, t steps through them
 ; the litter and the falling leaves: branches in the heap, twigs strewn round it, leaves
 ; on the ground, how low a leaf lies, how many landed are kept, how fast one falls; the
 ; barks, grey-brown, dark, weathered and stripped; and the leaves' colours, dry yellow,
 ; tan, brown, a few still green
 heap-n 64 stick-n 14 leaf-n 420 leaf-y 0.006 fallen-n 400 fall-v 0.45
 barks [[0.19 0.16 0.13] [0.15 0.12 0.09] [0.12 0.1 0.08] [0.27 0.26 0.23] [0.33 0.28 0.21]]
 snowc [0.88 0.9 0.94]
 hues [[0.6 0.5 0.17] [0.5 0.39 0.19] [0.36 0.26 0.14] [0.33 0.38 0.13]]
 ; the weather's odds by month, in twentieths: clear, partly, mostly cloudy, overcast --
 ; grey winters, clear late summers and falls
 wx-odds [[4 5 4 7] [4 5 4 7] [4 5 5 6] [4 6 5 5] [4 7 5 4] [5 7 5 3]
          [5 8 4 3] [6 7 4 3] [7 7 3 3] [7 6 3 4] [5 5 4 6] [4 5 4 7]]
 ; ..and under an overcast sky the twentieths it rains or snows (half that mostly cloudy,
 ; none lighter): snow in the depth of winter, either at its edges, rain the rest
 fall-odds [9 9 9 9 9 8 7 7 7 7 8 9]
 ; a long wall's sashes, 1.8 apart and 0.66 wide, and its small windows: the west's one
 ; each end, the east's two, 0.34 wide; sills at 0.9 and 1.4, heads at 2.3
 bay 1.8 sash-w 0.33 nook-w 0.17
 ; --- the cables: the building's wiring. one runs neat along the west wall over the ground
 ; floor's windows and round onto the short walls, dips under the stair's lowest window and
 ; climbs into a box beside it, each box west of the east window at the second floor's sill,
 ; the north's and the south's mirrored; and a few hang loose from the parapets, cut, and
 ; sway. a run is [width colour waypoints], each step along one axis on one wall's face;
 ; a box is [low corner, high corner, wall] ---
 cab [0.25 0.25 0.26]
 boxes [[[0.95 3.9 (yard-b - 0.23)] [1.25 4.2 yard-b] 2] [[0.95 3.9 (0.0 - yard-b)] [1.25 4.2 (0.23 - yard-b)] 3]]
 (to-box z) [[1.09 3.9 z] [1.09 2.62 z] [0.45 2.62 z] [0.45 2.3 z] [-0.43 2.3 z] [-0.43 2.62 z] [(0.0 - yard-a) 2.62 z]]
 runs [[0.04 cab (cat (to-box (0.0 - yard-b)) (rev (to-box yard-b)))]]
 ; --- the time: 'sim is the wall clock's local seconds, 'dst what summer adds to it ---
 ; now, as [local-seconds dst]: the zone's offset now, against the least of it a season on, two and three
 (court-when s) (: zone ((cite 'kore 'tz-zone) 0)
                   (off u) (zone ? (zone u 0) 0)
                   o (off s) std (foldl (a \ k \ min2 a (off (s + k * 7889400))) o [1 2 3])
                   [(1.0 * (s + o)) (o - std)])
 (court-now _) (court-when (clock 0 // 1000))
 ; ..and a wall-clock time L in local seconds, as [L dst] in this zone
 (court-local L) (: zone ((cite 'kore 'tz-zone) 0) (off u) (zone ? (zone u 0) 0) l (int L)
                    (court-when (l - off (l - off l))))
 ; --- the season, by the day of the year as the sky counts it (0 the first of january):
 ; the honey locust leafs out from mid april to mid may, turns gold from late september,
 ; drops from mid october to mid november, and stands bare the winter through. the
 ; leaves lie thickest after the fall, and rot down by summer; a leaf lets go about one
 ; frame in 'every while it is in leaf, and fastest in the drop ---
 (court-doy st) (: d (st 'sim / 86400.0 - 10957.0) (d - 365.2422 * floor (d / 365.2422)))
 (court-season st) (: d (court-doy st) spring (sat ((d - 108.0) / 22.0)) drop (sat ((d - 285.0) / 30.0))
   share (min2 spring (1.0 - drop))
   {'share share 'turn (sat ((d - 262.0) / 28.0))
    'ground (285.0 <= d ? (0.12 + 0.88 * drop) (max2 0.12 (1.0 - 0.88 * sat (d / 150.0))))
    'brown (285.0 <= d ? 0.1 0.65)
    'every (? (share < 0.05) 0 (285.0 <= d && d < 320.0) 6 300)})
 (court-clock st) (: d (day-secs (st 'sim)) hh (int (d / 3600.0)) mm (int (d / 60.0) % 60)
                     (p2 v) (v < 10 ? ("0" + show v) (show v))
                     (p2 hh + ":" + p2 mm))
 ; the sun as [east up north] and its light, at the scene's hour
 (court-sun st) (sky-sun (st 'sim) (st 'dst) lat)
 (court-light st) (sky-light (court-sun st) (st 'wx) (st 'sim))
 ; --- the state: the screen as view lays it, where the player stands and looks ('th the
 ; bearing, 'ph the pitch), the clock, its pace, and the pixels' rays. a run starts with
 ; its back to the east wall between the north pair of sashes, looking up at the sky ---
 ; the weather a run starts under, unless it is said: the cover thrown, the sky smooth
 (court-new w h now) (: sd (int (now 0)) tr (tree-grow sd) lr (litter tr sd)
                        st {'px (yard-a - 0.45) 'pz bay 'th (0.0 - pi / 2.0) 'ph 1.1
                            'sim (now 0) 'dst (now 1) 'pace 0 'paces paces 'shown 40 't 0
                            'deep 0 'done 0 'tree tr 'litter lr 'heap (heap-tree (lr 'rods) (tr 'base)) 'fall () 'fallen ()
                            'wx (court-season-wx (now 0) sd 'smooth)
                            'drift 1 'hour (int (now 0 // 3600))}
                        _ (pins st 'wet (sky-fall (st 'wx) = 1 ? 0.8 0.0) 'snow (sky-fall (st 'wx) = 2 ? 0.6 0.0))
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
        116 (tell (pin st 'pace ((st 'pace + 1) % #(st 'paces))))
        99 (tell (pins st 'wx (wx-of ((st 'wx 'cover + 1) % 4) (st 'wx 'style) (sky-fall (st 'wx))) 'drift 0))
        118 (tell (pin st 'wx (wx-of (st 'wx 'cover) (st 'wx 'style = 'pixel ? 'smooth 'pixel) (sky-fall (st 'wx)))))
        112 (tell (pins st 'wx (wx-of (st 'wx 'cover) (st 'wx 'style) ((sky-fall (st 'wx) + 1) % 3)) 'drift 0))
        st))
 ; a frame's motion: the clock, and the leaves -- now and then one lets go of the top of
 ; the crown, drifts down and lies where it lands
 (court-move st) (: t (st 't) tops (st 'litter 'tops) sea (court-season st) ev (sea 'every)
   ; ..gold in the fall, else mostly green
   hue (0.5 < sea 'turn ? (throw t 9 79 3) (throw t 9 79 4 = 0 ? 0 3))
   born (? (0 < ev && throw t 3 97 ev = 0 && two? tops)
           (tops (throw t 5 89 #tops) @ p [[(p 0) (p 1) (p 2) (throw t 7 83 628 / 100.0) hue]])
           ())
   moved (map (q \ fall-step q t) (cat born (st 'fall)))
   down (filter (q \ q 1 <= leaf-y) moved)
   ; ..the ground under the weather, by the sky's seconds this frame: rain wets the floor
   ; in half an hour and it dries in three; snow covers it in three hours, and goes in six
   ; dry or one under rain
   dt (st 'paces (st 'pace) / fps) f (sky-fall (st 'wx))
   _ (pins st 'sim (st 'sim + dt)
             'fall (filter (q \ leaf-y < q 1) moved)
             'fallen (newest fallen-n (cat down (st 'fallen)))
             'wet (sat (st 'wet + (f = 1 ? (dt / 1800.0) (0.0 - dt / 10800.0))))
             'snow (sat (st 'snow + (f = 2 ? (dt / 10800.0) (0.0 - dt / (f = 1 ? 3600.0 21600.0))))))
   (court-drift st))
 ; --- the weather's month and its drift: a month's odds pick a cover from k in 0..19; and
 ; while the weather is the season's own, about one sky hour in four it steps a notch
 ; toward a cover the month's odds draw ---
 (court-month sim) ((cite 'cal 'civil) (int sim // 86400) 1)
 (court-wx-pick m k) (: o (wx-odds (m - 1))
   (go i a) (i < 3 && a + o i <= k ? (go (i + 1) (a + o i)) i)
   (go 0 0))
 ; ..and what falls from a cover in month m, from k in 0..19 and a coin j for the
 ; months between rain and snow
 (court-fall-pick m c k j) (: o (fall-odds (m - 1))
   (? (c < 2 || (c = 3 ? o (o // 2)) <= k) 0
      (m = 12 || m <= 2) 2
      (m = 3 || m = 11) (j = 0 ? 2 1)
      1))
 (wx-of c sty f) (pins (sky-weather c sty) 'fall f)
 ; the season's weather at local seconds l, its dice from sd
 (court-season-wx l sd sty) (: m (court-month l) c (court-wx-pick m (throw sd 7 71 20))
   (wx-of c sty (court-fall-pick m c (throw sd 9 73 20) (throw sd 11 79 2))))
 ; ..an hour on: the cover stepped one in four, and the fall kept two in three while the
 ; cover can hold it, else drawn again
 (court-drift st) (: h (int (st 'sim // 3600))
   (? (h = st 'hour) st
      !(st 'drift) (pin st 'hour h)
      (: m (court-month (st 'sim)) c0 (st 'wx 'cover) f0 (sky-fall (st 'wx))
         to (court-wx-pick m (throw h 13 59 20))
         c (throw h 11 67 4 != 0 ? c0 (c0 + (to < c0 ? -1 (c0 < to ? 1 0))))
         f (? (c < 2) 0 (0 < f0 && throw h 21 43 3 != 0) f0
              (court-fall-pick m c (throw h 17 53 20) (throw h 19 47 2)))
         (pins st 'hour h 'wx (wx-of c (st 'wx 'style) f)))))
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
 ; the windows and their sills and frames, the south's door, the paint mottled, grimed at
 ; the foot and stained under the sills, the red or an older coat beneath, and the
 ; coping; over it the battlements, weathered harder under their dark caps. what a window
 ; shows lit is laid here too, which window it is, and whether it is lit all night
 (wall-at i) (:
   wid ((nu-long * nv <= i) + (2 * nu-long * nv <= i) + ((2 * nu-long + nu-short) * nv <= i))
   nu (peep wall-nus wid 0) j (i - peep wall-offs wid 0)
   isx (wid < 2) isz (1 - isx)
   half (over yard-a isx yard-b)
   al ((j % nu + 0.5) * ts - half) py ((j // nu + 0.5) * ts)
   b yard-b hh wall-h
   fl (floor (py / floor-h)) yy (py - fl * floor-h) infl (fl < floors)
   ; the windows: a long wall's four sashes a floor and the small ones by its corners --
   ; the west's a bathroom's, sill raised, the east's a living room's, level with the
   ; sashes -- a short wall's two narrow ones a floor, and the stair's between the floors
   wi (max 0 (min 3 (floor (al / bay + 2.0)))) ca (al - (wi - 1.5) * bay)
   lw (isx * (sq ca < sash-w * sash-w) * (0.9 < yy) * (yy < 2.3) * infl)
   ea (mag al) ei ((wid = 0) * (3.75 < ea)) na (ea - over 3.8 (wid = 0) (over 3.45 ei 4.05))
   nk (isx * ((wid = 0) + (wid = 1) * (0.0 < fl)) * infl)
   nb (over 1.4 (wid = 0) 0.9) bath (wid = 1)
   nw (nk * (sq na < nook-w * nook-w) * (nb < yy) * (yy < 2.3))
   sa (mag al - 1.6)
   sw (isz * (sq sa < 0.0625) * (0.9 < yy) * (yy < 2.4) * infl)
   ys (py - 2.45) fs (floor (ys / floor-h)) yys (ys - fs * floor-h)
   stw (isz * (sq al < 0.09) * (yys < 1.2) * (0 <= fs) * (fs < floors - 1))
   win (lw + nw + sw + stw)
   sill (0 < (isx * (sq ca < 0.144) + isz * (sq sa < 0.09)) * (0.82 < yy) * (yy <= 0.9) * infl
              + nk * (sq na < 0.048) * (nb - 0.08 < yy) * (yy <= nb))
   ; ..a window's frame: its edges, and the meeting rail between the two sashes
   cp (lw * ca + nw * na + sw * sa + stw * al) hw (lw * sash-w + nw * nook-w + sw * 0.25 + stw * 0.3)
   vp ((lw + sw) * (yy - 0.9) + nw * (yy - nb) + stw * yys) vh (lw * 1.4 + nw * (2.3 - nb) + sw * 1.5 + stw * 1.2)
   frm (win * (0 < (hw - mag cp < 0.05) + (vp < 0.07) + (vh - vp < 0.06) + (mag (vp - 0.5 * vh) < 0.03)))
   glass (win - frm)
   ; ..each room its own, a long wall's sashes and corner windows by the pair: lamps warm
   ; and various, a few with the curtains drawn, a few a television, a bathroom's white;
   ; the lobby's, the stair's and the ground floor halls' lit all night
   wkey (wid * 100 + fl % 8 * 10 + lw * (2 <= wi) + nw * (4 + 2 * (0.0 < al)) + sw * (4 + (0.0 < al)))
   lob (lw * (wid = 1) * (fl = 0)) hall (sw * (fl = 0) * (al < 0.0)) nt (stw + lob + hall)
   bw (nw * bath)
   tv ((throw wkey 0 13 9 = 0) * (1 - nt) * (1 - bw))
   cur ((throw wkey 1 19 3 = 0) * (1 - lob))
   lamp (0.55 + 0.45 * (throw wkey 2 23 10 / 10.0))
   glow (lamp * (1.0 - 0.6 * cur * (hw * 0.45 < mag cp)))
   em (cmix (cmix (cmix (cmix (c* glow [1.0 0.76 0.44]) [0.5 0.62 1.0] tv) (c* glow [0.9 0.88 0.8]) bw)
                  [0.85 0.95 0.82] (stw + hall)) [0.95 0.8 0.52] lob)
   ; ..the brick: courses and their bonds, chipped in patches a brick at a time
   row (floor (py / 0.08)) bi (floor ((al + row % 2 * 0.12) / 0.24))
   cx (floor (al / 0.7)) cy (floor (py / 0.5))
   chip (0 < (throw cx cy (wid + 11) 9 = 0) * (throw bi row (wid + 3) 2 = 0) + (throw bi row (wid + 5) 500 = 0))
   old (throw cx cy (wid + 23) 4 = 0)
   stain ((isx * (sq ca < 0.12) + isz * (sq sa < 0.05)) * (yy < 0.82) * infl
          * sat (1.0 - (0.82 - yy) / 0.9) * sat (vn (al * 18.0) 0.5 9 * 2.0 - 0.6))
   foot (sat (1.0 - py / 1.2))
   ; ..the paint: mottled large and small, the joints of the brick showing through where the
   ; coat is thin, grime run down it in streaks, and moss in patches at the foot
   thin (sat (vn (al * 1.3) (py * 1.3) (wid + 50) * 2.6 - 1.4))
   mort ((frac (py / 0.08) < 0.5) * 0.5 + (frac ((al + row % 2 * 0.12) / 0.24) < 0.17))
   grime (sat (vn (al * 5.0) (py * 0.12) (wid + 60) * 2.4 - 1.3) * (0.4 + 0.6 * vn (al * 0.7) (py * 0.7) (wid + 61)))
   fine ((throw (floor (al / ts)) (floor (py / ts)) (wid + 70) 9) / 9.0 - 0.5)
   paint (c* ((0.92 + 0.13 * vn (al * 0.9) (py * 0.9) (wid + 40) + 0.12 * vn (al * 0.3) (py * 0.3) (wid + 45) - 0.06 + 0.05 * fine)
              * (1.0 - 0.3 * stain) * (1.0 - 0.28 * foot) * (1.0 - 0.22 * thin * mort) * (1.0 - 0.22 * grime))
             [0.6 0.61 0.6])
   mz (sat (1.0 - py / 1.3) * sat (vn (al * 2.2) (py * 2.2) (wid + 80) * 2.4 - 0.6))
   mossc (c* (0.75 + 0.45 * vn (al * 9.0) (py * 9.0) (wid + 81)) [0.22 0.31 0.13])
   paint2 (cmix (cmix paint [0.3 0.34 0.24] (0.35 * foot)) mossc (0.85 * mz))
   under (cmix (c* (0.82 + 0.3 * (throw bi row 41 10 / 10.0)) [0.56 0.27 0.2]) [0.55 0.6 0.48] old)
   blk (0 < isz * (ea < hb) + (wid = 0) * (b - cw < al) + (wid = 2) * (yard-a - 0.05 < al)) up (blk * (hh - 0.18 <= py))
   cope ((hh - 0.18 < py) * (1 - blk))
   ; ..the battlements: the paint blotched and streaked down from the cap, chipped more
   streak (sat (vn (al * 9.0) 0.5 77 * 2.2 - 0.9) * sat (1.0 - (top-h - py) / 1.4))
   worn (c* ((0.8 + 0.3 * vn (al * 3.0) (py * 3.0) 78) * (1.0 - 0.4 * streak)) [0.6 0.61 0.6])
   chip2 (0 < (throw cx cy (wid + 13) 3 = 0) * (throw bi row (wid + 7) 2 = 0) + (throw bi row (wid + 9) 40 = 0))
   battle (cmix (cmix worn under chip2) [0.15 0.15 0.16] (top-h - 0.14 < py))
   ; ..the door, a dark brown in a darker frame, its knob brass on the right
   dr ((wid = 3) * (ea < 0.5) * (py < 2.1))
   dfr (dr * (0 < (0.5 - ea < 0.05) + (2.1 - py < 0.05)))
   knob (dr * (sq (al + 0.36) + sq (py - 1.0) < 0.0009))
   alb (cmix (cmix (cmix (cmix (cmix (cmix (cmix (cmix paint2 under chip) [0.68 0.66 0.62] sill) [0.7 0.7 0.66] frm) [0.5 0.49 0.46] cope)
                         battle up) [0.17 0.115 0.08] dr) [0.1 0.075 0.055] dfr) [0.55 0.45 0.22] knob)
   {'r (alb 0) 'g (alb 1) 'b (alb 2) 'glass glass 'key wkey 'night nt 'tv tv
    'er (em 0) 'eg (em 1) 'eb (em 2)})
 ; the floor: eight triangular slabs meeting at the sump -- split by the two axes and the
 ; two diagonals to the corners -- each poured a shade apart, their joints, moss over
 ; most of it and thickest by the walls, in the joints and round the sump, and the
 ; sump's round grate
 sump-r 0.2
 (floor-at i) (: a yard-a b yard-b
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
 ; ..each laid a slice of texels at a time into trays n long, so what a texel takes on its
 ; way is held for a slice and not the whole map: a small machine has the room
 (lay-map n f) (: k 16384
   (go lo out) (lo < n ? (: ix (lo + iota (min2 k (n - lo))) c (f ix)
                            (go (lo + k) (foldl (o \ key \ pin o key (pin (peep o key (iota n * 0 + peep (c key) 0 0 * 0)) ix (c key)))
                                                out (keys c))))
                         out)
   (go 0 {}))
 (court-maps _) (maps 'wall ? maps (: m (lay-map wall-n wall-at) _ (each runs (rn \ lay-run m rn))
                                     (pins maps 'wall m 'floor (lay-map (fl-nx * fl-nz) floor-at))))
 ; whether the sun reaches the points px py pz (trays) past the rim, the long walls'
 ; parapets and the battlements: the way out toward it is through the top, or over a wall
 ; low enough where it crosses
 (sun-clear px py pz s) (: a yard-a b yard-b sx (s 0) sy (s 1) sz (s 2)
   (away v) (v < 0.0 ? (min2 v -1e-6) (max2 v 1e-6))
   ux (((sx < 0.0 ? (0.0 - a) a) - px) / away sx)
   uz (((sz < 0.0 ? (0.0 - b) b) - pz) / away sz)
   uy ((top-h - py) / max2 sy 1e-6)
   viax ((ux < uz) * (ux < uy)) viaz ((1 - viax) * (uz < uy))
   ye (py + sy * min ux uz) xe (px + uz * sx) ze (pz + ux * sz)
   ((0.0 < sy) * (1 - viax * (0 < (ye < wall-h) + (0.0 < sx) * (b - cw < ze))
                    - viaz * (0 < (ye < wall-h) + (mag xe < hb)))))
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
 ; --- what lies under it: the fallen branches people have piled at the foot of the trunk,
 ; twigs strewn round them, and the leaves the crown has dropped, laid once a run from the
 ; tree's own seed; and the high leaves a falling one may start from. a point is
 ; [x y z r g b up], up 1 for one lying flat; a branch is a rod (rods!) ---
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
   ; ..the heap: branches laid on the floor in a ring hard against the trunk, thickest there so
   ; no floor shows round it -- most along the ring, passing the bark as close as their own
   ; width lets them, the rest pointing out from it -- an end a little off the floor where the
   ; ring is deep; most forked, some forks with a twig off them
   (keep q) [(clamp (q 0) (0.12 - yard-a) (yard-a - 0.12)) (q 1) (clamp (q 2) (0.12 - yard-b) (yard-b - 0.12))]
   (round a d y) (keep [(bs 0 + d * cos a) y (bs 2 + d * sin a)])
   (from q) (sqrt (sq (q 0 - bs 0) + sq (q 2 - bs 2)))
   (mound d) (0.2 * sat (1.0 - (d - 0.25) / 0.7))
   (bark _) (c* (rr 0.85 1.15) (barks (int (rr 0.0 4.99))))
   ; ..a fork that would reach into the trunk goes the other way
   (fork a b r c fz k) (: p (lerp a b (rr 0.4 0.75)) ax (c+ b (c* -1.0 a))
     ang ((rr 0.0 1.0 < 0.5 ? -1.0 1.0) * rr 0.4 0.9) ln (rr 0.3 0.55 * sqrt (dot ax ax))
     (tip g) (keep (c+ p (c* ln (unit (turn (unit ax) [0.0 1.0 0.0] (g * ang))))))
     q (tip 1.0 @ q (from q < 0.3 + r ? (tip -1.0) q) @ q [(q 0) (max2 (0.55 * r) (q 1 + rr -0.1 0.05)) (q 2)])
     rd [p q (0.55 * r) c fz]
     (0 < k && rr 0.0 1.0 < 0.5 ? (cat [rd] (fork p q (0.55 * r) c fz (k - 1))) [rd]))
   (branch _) (: a (rr 0.0 (2.0 * pi)) r (rr 0.022 0.06) c (bark 0) fz (rr 0.15 0.35)
     (lift q) [(q 0) (r + rr 0.0 1.0 * mound (from q)) (q 2)]
     ends (rr 0.0 1.0 < 0.35
           ? [(lift (round a (0.27 + r) 0.0)) (lift (round (a + rr -0.15 0.15) (rr 0.6 1.1) 0.0))]
           (: dv (rr -0.45 0.45) d ((0.27 + r + sq (rr 0.0 1.0) * 0.4) / cos dv)
              m (round a d 0.0) yaw (a + pi / 2.0 + dv) hl (rr 0.3 0.8)
              (end k) (lift (keep [(m 0 + k * hl * cos yaw) 0.0 (m 2 + k * hl * sin yaw)]))
              [(end -1.0) (end 1.0)]))
     rd [(ends 0) (ends 1) r c fz]
     (rr 0.0 1.0 < 0.6 ? (cat [rd] (fork (ends 0) (ends 1) r c fz 1)) [rd]))
   ; ..each twig lies flat a little way out from the heap: two rows of points
   (stick i) (: a (i * 2.0 * pi / stick-n + rr -0.3 0.3) rad (rr 0.9 1.4)
                cx (clamp (bs 0 + rad * cos a) (0.3 - yard-a) (yard-a - 0.3))
                cz (clamp (bs 2 + rad * sin a) (0.3 - yard-b) (yard-b - 0.3))
                yaw (rr 0.0 (2.0 * pi)) ln (rr 0.15 0.35) k (int (ln / 0.008))
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
   hi (filter (i \ peep K i 0.0 = 2.0 && top - 1.5 < peep Y i 0.0) ^n)
   tops (two? hi ? (map (q \ hi (int (rr 0.0 (#hi - 0.5))) @ i [(peep X i 0.0) (peep Y i 0.0) (peep Z i 0.0)]) ^120) ())
   rods (cat* (map branch ^heap-n)) pts (bits (cat* (map stick ^stick-n)))
   {'pts pts 'rods rods 'leaves (bits (cat* (map leaf ^leaf-n))) 'tops tops})
 ; the first k of the leaves on the ground, browned by bw
 (lead P k bw) (k < 1 ? () (: ix (iota k) (g q) (peep (P q) ix 0.0) dead [0.3 0.22 0.13]
   {'x (g 'x) 'y (g 'y) 'z (g 'z) 'up (g 'up)
    'r (g 'r + bw * (dead 0 - g 'r)) 'g (g 'g + bw * (dead 1 - g 'g)) 'b (g 'b + bw * (dead 2 - g 'b))}))
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
 (bits! P cam lt sms buf sn) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
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
   lit (sun-clear X Y Z s * (1.0 - shade sms X Y Z) * lt 'sunk * face * 0.9)
   irr (c+ (c* 0.42 (lt 'amb)) (c* lit (lt 'sunc)))
   cl (cm (cmix [(P 'r) (P 'g) (P 'b)] snowc (P 'up * sn)) irr)
   (pins buf 't (pin (buf 't) i2 dist) 'r (pin (buf 'r) i2 (cl 0))
             'g (pin (buf 'g) i2 (cl 1)) 'b (pin (buf 'b) i2 (cl 2))))
 ; the heap as grove's sun map takes a tree, its branches rings of points close enough
 ; that the map's texels see no gaps; how much of the sun it takes at X Y Z, by a margin
 ; a branch's width and not a crown's, so the floor just under one is shaded; and the
 ; share the tree and the heap take together, sms their two maps
 (heap-tree rs bs) (: (ring rd) (: a (rd 0) b (rd 1) r (rd 2) ax (c+ b (c* -1.0 a)) u (unit ax)
                                   p1 (side u) p2 (cross u p1) k (int (sqrt (dot ax ax) / 0.02) + 1)
                                   (cat* (map (i \ (lerp a b (i / (1.0 * k))) @ c
                                                     (map (j \ c+ c (c+ (c* (r * cos (j * 0.785)) p1) (c* (r * sin (j * 0.785)) p2))) ^8))
                                              ^(k + 1))))
   qs (cat* (map ring rs)) m #qs (col k) (gem-tray [m] (map (q \ q k) qs)) one (gem-tray [1] [1.0])
   {'x (one * bs 0) 'y (one * 0.0) 'z (one * bs 2) 'kind one 'ph (one * 0.0)
    'shx (col 0) 'shy (col 1) 'shz (col 2) 'c [(bs 0) 0.3 (bs 2)] 'R 1.9 'cache {}})
 (heap-shade hm X Y Z) (hm ? (0.85 * (hm 'depth X Y Z + 0.03 < peep (hm 'map) (hm 'pix X Y Z) -1e9)) 0.0)
 (shade sms X Y Z) (1.0 - (1.0 - grove-shade (sms 0) X Y Z) * (1.0 - heap-shade (sms 1) X Y Z))
 ; ..the loose ones from the parapet's top down, swaying the more the lower they hang as the
 ; frame's clock t goes; a rod off a wall casts its shadow there (shade-walls)
 (strands t) (: (sway k p) (: f (sq (sat ((wall-h - p 1) / 5.0)))
                             [(p 0 + f * 0.03 * sin (t * 0.05 + k)) (p 1) (p 2 + f * 0.03 * cos (t * 0.04 + k * 1.3))])
   (hang wid ps r k) (: n #ps q (map (i \ sway k (ps i)) ^n)
                        (map (i \ [(q i) (q (i + 1)) r [0.05 0.05 0.055] 0.0 wid]) ^(n - 1)))
   ea (yard-a - 0.04) wa (0.04 - yard-a) nb (yard-b - 0.04) sb (0.04 - yard-b)
   (cat* [(hang 2 [[-2.2 wall-h nb] [-2.2 9.4 (nb + 0.01)] [-2.14 7.6 (nb - 0.12)]] 0.009 1.0)
          (hang 0 [[ea wall-h -3.45] [(ea + 0.01) 8.2 -3.45] [(ea - 0.16) 5.9 -3.38]] 0.01 2.0)
          (hang 1 [[wa wall-h 1.6] [(wa - 0.01) 10.6 1.62] [(wa + 0.11) 9.3 1.7]] 0.008 3.0)
          (hang 3 [[2.45 wall-h sb] [2.45 6.0 (sb - 0.01)] [2.52 2.7 (sb + 0.16)]] 0.011 4.0)
          (hang 0 [[ea wall-h 0.3] [(ea - 0.02) 11.95 0.75] [(ea - 0.03) 11.8 1.25] [(ea - 0.02) 11.95 1.7] [ea wall-h 2.1]] 0.009 5.0)
          (hang 1 [[wa wall-h -4.1] [(wa - 0.02) 10.9 -4.12] [(wa + 0.16) 10.1 -4.0]] 0.008 6.0)]))
 ; which wall's face a step of a run is on, and where along it
 (wall-of p q) (: (on? k v) (mag (p k - v) < 0.01 && mag (q k - v) < 0.01)
   (? (on? 0 yard-a) 0 (on? 0 (0.0 - yard-a)) 1 (on? 2 yard-b) 2 3))
 (along-of wid p) (wid < 2 ? (p 2) (p 0))
 ; ..the map's texel on wall wid at u along it and v up it
 (wall-texel wid u v) (peep wall-offs wid 0 + floor (v / ts) * peep wall-nus wid 0
                       + floor ((u + (wid < 2 ? yard-b yard-a)) / ts))
 ; ..a step laid into the wall's map: the texels of its box, each the share of it the run
 ; covers, its strands striped and its upper side lit, the wall under it a little shadowed
 (lay-step m wid u0 u1 v0 v1 wd c) (: nu (peep wall-nus wid 0) half (wid < 2 ? yard-b yard-a)
   flat (mag (v1 - v0) < 0.001) pad (wd + 0.08)
   tu0 (max2 0 (int ((min2 u0 u1 - pad + half) / ts))) tu1 (min2 (nu - 1) (int ((max2 u0 u1 + pad + half) / ts)))
   tv0 (max2 0 (int ((min2 v0 v1 - pad) / ts))) tv1 (min2 (nv - 1) (int ((max2 v0 v1 + pad) / ts)))
   bw (tu1 - tu0 + 1) bh (tv1 - tv0 + 1)
   ii (iota (bw * bh)) tu (tu0 + ii % bw) tv (tv0 + ii // bw)
   uc ((tu + 0.5) * ts - half) vc ((tv + 0.5) * ts) ix (wall-texel wid uc vc)
   ac (flat ? (vc - v0) (uc - u0)) w2 (0.5 * wd)
   at (flat ? uc vc) lo (flat ? (min2 u0 u1) (min2 v0 v1)) hi (flat ? (max2 u0 u1) (max2 v0 v1))
   (ov x l h) (sat ((min (x + 0.5 * ts) h - max (x - 0.5 * ts) l) / ts))
   long (ov at (lo - w2) (hi + w2))
   cov (ov ac (0.0 - w2) w2 * long)
   shd ((ov ac (0.0 - w2 - 0.04) (flat ? w2 (w2 + 0.04)) * long - cov) * 0.15)
   x (ac / max2 w2 0.001) k (max2 1 (int (wd / 0.012)))
   strand (0.9 + 0.2 * throw (floor ((x + 1.0) * 0.5 * k)) (int (mag lo * 100.0)) 91 9 / 9.0)
   tie ((frac (at / 0.3) < 0.13) * (0.05 < wd))
   tone ((flat ? (1.0 + 0.25 * x) (1.1 - 0.2 * mag x)) * strand * (1.0 + 0.3 * tie))
   (lay key ck) (peep (m key) ix 0.0 @ o (pin m key (pin (m key) ix (o * (1.0 - shd) + cov * (tone * ck - o * (1.0 - shd))))))
   _ (lay 'r (c 0)) _ (lay 'g (c 1)) _ (lay 'b (c 2))
   (pin m 'glass (pin (m 'glass) (over -1 (0.5 < cov) ix) 0)))
 (lay-run m rn) (: wd (rn 0) c (rn 1) ps (rn 2) n #ps
   _ (each ^(n - 1) (i \ (: p (ps i) q (ps (i + 1)) wid (wall-of p q)
                           (lay-step m wid (along-of wid p) (along-of wid q) (p 1) (q 1) wd c)))))
 ; --- rods: the heap's branches and the cables off the walls, [a b r colour bark wall],
 ; cylinders each tried only on the pixels of its box on the screen; bark how much the shade
 ; wanders. one thinner than a pixel is drawn as the share of each pixel it covers, over
 ; what is there, and leaves the depth alone ---
 ; the pixels of the screen's box round the points qs, pad pixels wider: a segment's end
 ; behind the eye cut back to the near plane, else all the screen when one is behind
 (spot qs pad cam) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
   (z q) (dot (c+ q (c* -1.0 e)) f)
   (proj q) (c+ q (c* -1.0 e) @ v [(w / 2.0 + foc * dot v rt / z q) (h / 2.0 - foc * dot v uv / z q)])
   (box ps) (: xs (map (p \ p 0) ps) ys (map (p \ p 1) ps)
               x0 (max2 0 (flo (foldl min2 1e9 xs - pad))) x1 (min2 (w - 1) (flo (foldl max2 -1e9 xs + pad)))
               y0 (max2 0 (flo (foldl min2 1e9 ys - pad))) y1 (min2 (h - 1) (flo (foldl max2 -1e9 ys + pad)))
               bw (x1 - x0 + 1) bh (y1 - y0 + 1)
               ((bw <= 0 || bh <= 0) ? () (iota (bw * bh) @ ii ((y0 + ii // bw) * w + x0 + ii % bw))))
   zs (map z qs) nb #(filter (v \ v < 0.1) zs)
   (? (nb = #qs) ()
      (nb = 0) (box (map proj qs))
      (#qs = 2) (: a (qs 0) b (qs 1) za (zs 0) zb (zs 1)
                   (box [(proj (za < 0.1 ? (lerp a b ((0.1 - za) / (zb - za))) a))
                         (proj (zb < 0.1 ? (lerp b a ((0.1 - zb) / (za - zb))) b))]))
      (iota (w * h))))
 (rods! rs cam lt sms buf sn) (: e (cam 'e) f (cam 'f) foc (cam 'foc) s (lt 'sun)
   (one rd) (: a0 (rd 0) b0 (rd 1) r (rd 2) col (rd 3) fz (rd 4)
     za (dot (c+ a0 (c* -1.0 e)) f) zb (dot (c+ b0 (c* -1.0 e)) f)
     idx (spot [a0 b0] (r * foc / max2 0.1 (min2 za zb) + 1.5) cam)
     (#idx = 0 ? ()
      (: ddx (peep (cam 'dx) idx 0.0) ddy (peep (cam 'dy) idx 0.0) ddz (peep (cam 'dz) idx 0.0)
         ax (c+ b0 (c* -1.0 a0)) L (sqrt (dot ax ax)) u (unit ax)
         wv (c+ e (c* -1.0 a0)) wu (dot wv u) W (c+ wv (c* (0.0 - wu) u)) WW (dot W W)
         dd (ddx * u 0 + ddy * u 1 + ddz * u 2)
         Wd (ddx * W 0 + ddy * W 1 + ddz * W 2)
         A (max (1.0 - dd * dd) 1e-9)
         disc (Wd * Wd - A * (WW - r * r))
         th ((0.0 - Wd - sqrt (max disc 0.0)) / A) hit ((0.0 < disc) * (0.0 < th))
         tc ((0.0 - Wd) / A) tt (over tc hit th)
         ; ..the share of a pixel it covers across, where the ray passes nearest the axis
         dc (sqrt (max 0.0 (WW - Wd * Wd / A))) fp (max tc 0.01 / foc)
         cov (sat ((min (dc + r) (0.5 * fp) - max (dc - r) (-0.5 * fp)) / fp))
         sa0 (wu + tt * dd)
         al0 (max hit cov * (0.0 < tt) * (-0.5 * r <= sa0) * (sa0 <= L + 0.5 * r) * (tt < peep (buf 't) idx 1e9))
         ; ..and only the pixels it takes are lit
         ks (iota (0.004 < al0))
         (#ks = 0 ? ()
          (: (g v) (peep v ks 0.0) ix (peep idx ks 0) al (g al0) t (g tt) sa (g sa0)
             ex (g ddx) ey (g ddy) ez (g ddz) de (g dd)
             ; ..the normal, off the axis toward where the ray meets it or passes nearest
             ox (W 0 + t * (ex - de * u 0)) oy (W 1 + t * (ey - de * u 1)) oz (W 2 + t * (ez - de * u 2))
             ol (max 1e-6 (sqrt (ox * ox + oy * oy + oz * oz)))
             nx (ox / ol) ny (oy / ol) nz (oz / ol)
             X (e 0 + t * ex) Y (e 1 + t * ey) Z (e 2 + t * ez)
             p1 (side u)
             fur (1.0 + fz * (frac (sin ((nx * p1 0 + ny * p1 1 + nz * p1 2) * 9.0 + sa * 3.0) * 4375.85) - 0.5))
             nds (max 0.0 (nx * s 0 + ny * s 1 + nz * s 2))
             lit (nds * sun-clear X Y Z s * (1.0 - shade sms X Y Z) * lt 'sunk)
             base (cmix (c* fur col) snowc (sn * sat (ny * 2.0 - 0.8)))
             cl (cm base (c+ (c* 0.9 (lt 'amb)) (c* lit (lt 'sunc))))
             (mix k v) (peep (buf k) ix 0.0 @ o (o + al * (v - o)))
             (pins buf 't (pin (buf 't) (over -1 (0.5 <= al) ix) t)
                       'r (pin (buf 'r) ix (mix 'r (cl 0))) 'g (pin (buf 'g) ix (mix 'g (cl 1)))
                       'b (pin (buf 'b) ix (mix 'b (cl 2)))))))))
   (each rs one))
 ; the box: grey paint gone dull, its door's edge on the face, dirt at its foot
 (box! bx cam lt sms buf sn) (: e (cam 'e) s (lt 'sun) lo (bx 0) hi (bx 1)
   cs (map (k \ [((k % 2 = 1 ? hi lo) 0) ((k // 2 % 2 = 1 ? hi lo) 1) ((k // 4 = 1 ? hi lo) 2)]) ^8)
   idx (spot cs 1.0 cam)
   (#idx = 0 ? ()
    (: ddx (peep (cam 'dx) idx 0.0) ddy (peep (cam 'dy) idx 0.0) ddz (peep (cam 'dz) idx 0.0)
       (slab k d) (: t1 ((lo k - e k) / d) t2 ((hi k - e k) / d) [(min t1 t2) (max t1 t2)])
       sx (slab 0 ddx) sy (slab 1 ddy) sz (slab 2 ddz)
       tn (max (sx 0) (max (sy 0) (sz 0))) tf (min (sx 1) (min (sy 1) (sz 1)))
       hit ((tn < tf) * (0.0 < tn) * (tn < peep (buf 't) idx 1e9)) i2 (over -1 hit idx)
       fx (tn = sx 0) fy ((1 - fx) * (tn = sy 0)) fz (1 - fx - fy)
       nx (fx * over 1.0 (0.0 < ddx) -1.0) ny (fy * over 1.0 (0.0 < ddy) -1.0) nz (fz * over 1.0 (0.0 < ddz) -1.0)
       X (e 0 + tn * ddx) Y (e 1 + tn * ddy) Z (e 2 + tn * ddz)
       edge (fz * (min (min (X - lo 0) (hi 0 - X)) (min (Y - lo 1) (hi 1 - Y)) < 0.025))
       dirt (1.0 - 0.3 * sat (1.0 - (Y - lo 1) / 0.08) - 0.15 * (0.0 < ny))
       base (cmix (c* (dirt * (1.0 - 0.3 * edge)) [0.47 0.48 0.44]) snowc (sn * (0.0 < ny)))
       nd (max 0.0 (nx * s 0 + ny * s 1 + nz * s 2))
       lit (nd * sun-clear X Y Z s * (1.0 - shade sms X Y Z) * lt 'sunk * 0.9)
       cl (cm base (c+ (c* 0.75 (lt 'amb)) (c* lit (lt 'sunc))))
       (pins buf 't (pin (buf 't) i2 tn) 'r (pin (buf 'r) i2 (cl 0)) 'g (pin (buf 'g) i2 (cl 1)) 'b (pin (buf 'b) i2 (cl 2))))))
 ; --- the shadows the cables and the box lay on the walls, as the share of the sun each
 ; pixel loses: a rod's laid down the sun onto its wall, the box's swept from its face back
 ; to the wall, tried on the pixels of its box on the screen that show that wall. P is
 ; the pixels' [x y z wall depth], wl 1 where a pixel shows a wall ---
 ins [[-1.0 0.0 0.0] [1.0 0.0 0.0] [0.0 0.0 -1.0] [0.0 0.0 1.0]]
 (in-h wid q) (dot (ins wid) q + (wid < 2 ? yard-a yard-b))
 (shade-walls rs cam s P wl) (: foc (cam 'foc) O {'o (P 3 * 0.0)}
   (lay idx v) (pin O 'o (pin (O 'o) idx (max (peep (O 'o) idx 0.0) v)))
   (seen idx wid) (: k (peep (P 3) idx -1 = wid) (k * peep wl idx 0))
   (one rd) (: wid (rd 5) sn (dot s (ins wid))
     (sn < 0.02 ? ()
      (: a (rd 0) b (rd 1) r (rd 2) ha (in-h wid a) hb (in-h wid b)
         a2 (c+ a (c* (0.0 - ha / sn) s)) b2 (c+ b (c* (0.0 - hb / sn) s))
         idx (spot [a2 b2] 2.0 cam)
         (#idx = 0 ? ()
          (: ex (b2 0 - a2 0) ey (b2 1 - a2 1) ez (b2 2 - a2 2) ee (max2 1e-9 (ex * ex + ey * ey + ez * ez))
             qx (peep (P 0) idx 0.0 - a2 0) qy (peep (P 1) idx 0.0 - a2 1) qz (peep (P 2) idx 0.0 - a2 2)
             k (sat ((qx * ex + qy * ey + qz * ez) / ee))
             d (sqrt (sq (qx - k * ex) + sq (qy - k * ey) + sq (qz - k * ez)))
             soft (peep (P 4) idx 1.0 / foc + min2 0.3 (0.0093 * (ha + hb) * 0.5 / sn))
             cov (sat ((min (d + r) (0.5 * soft) - max (d - r) (-0.5 * soft)) / soft))
             (lay (over -1 (seen idx wid) idx) (0.85 * cov)))))))
   _ (each rs one)
   ; ..each box's on its wall: its face's outline laid back onto the wall, swept
   (cast-box bx) (: lo (bx 0) hi (bx 1) wid (bx 2) sn (dot s (ins wid))
     dep (hi 2 - lo 2) zf (wid = 2 ? yard-b (0.0 - yard-b))
     ((0.02 < sn && 0.0 < s 1) ?
      (: du (0.0 - s 0 * dep / sn) dv (0.0 - s 1 * dep / sn)
         cs (cat* (map (k \ (: q [((k % 2 = 1 ? hi lo) 0) ((k // 2 = 1 ? hi lo) 1) zf]
                               [q [(q 0 + du) (q 1 + dv) zf]])) ^4))
         idx (spot cs 1.0 cam)
         (#idx = 0 ? ()
          (: (span p d l h) (: k1 ((p - h) / d) k2 ((p - l) / d) [(min k1 k2) (max k1 k2)])
             ru (span (peep (P 0) idx 0.0) (mag du < 1e-6 ? 1e-6 du) (lo 0) (hi 0))
             rv (span (peep (P 1) idx 0.0) (mag dv < 1e-6 ? 1e-6 dv) (lo 1) (hi 1))
             ok ((max 0.0 (max (ru 0) (rv 0)) <= min 1.0 (min (ru 1) (rv 1))) * seen idx wid)
             (lay (over -1 ok idx) 0.95)))) ()))
   _ (each boxes cast-box)
   (O 'o))
 ; --- the stars: fixed in the sky, evenly over it from a little above the horizon, each
 ; one pixel where the eye sees it through the top, so none is drawn stretched across the
 ; pixels the sky's own map would give it. [x y z brightness phase] as trays ---
 star-k 400
 stars (: (one k) (: az (2.0 * pi * throw k 1 91 1000 / 1000.0) y (0.3 + 0.7 * throw k 2 93 1000 / 1000.0)
                     r (sqrt (1.0 - y * y))
                     [(r * sin az) y (r * cos az) (0.3 + 0.12 * throw k 3 95 5) (throw k 4 97 628 / 100.0)])
          l (map one ^star-k) (col j) (gem-tray [star-k] (map (q \ 1.0 * q j) l))
          {'x (col 0) 'y (col 1) 'z (col 2) 'b (col 3) 'ph (col 4)})
 ; ..laid onto the colours c where a pixel shows the sky, dimmed by the cloud before them,
 ; twinkling, or in pixels on and off
 (stars! c st lt cam sky t0) (: wx (st 'wx) nt (sat (1.0 - lt 'day * 3.0))
   (nt <= 0.0 ? c
    (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
       X (stars 'x) Y (stars 'y) Z (stars 'z)
       zc (X * f 0 + Y * f 1 + Z * f 2) zs (max zc 0.01)
       cx (floor (w / 2.0 + foc * (X * rt 0 + Y * rt 1 + Z * rt 2) / zs))
       cy (floor (h / 2.0 - foc * (X * uv 0 + Y * uv 1 + Z * uv 2) / zs))
       idx (over -1 ((0.05 < zc) * (0 <= cx) * (cx < w) * (0 <= cy) * (cy < h)) (cy * w + cx))
       ix (over -1 (peep sky idx 0) idx)
       cl (sky-cloud wx X Y Z (e 0) (e 2) (st 'sim))
       tw (sin (t0 * turns wx 'tper 0.9 + stars 'ph))
       v (wx 'style = 'pixel ? ((0.6 < tw) * (lt 'day < 0.1) * (cl < 0.5) * 1.6)
            (stars 'b * (0.75 + 0.25 * tw) * nt * (1.0 - cl)))
       (map (k \ peep (c k) ix 0.0 @ o (pin (c k) ix (o + (k = 2 ? 0.9 1.0) * v))) ^3))))
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
   ; ..a wall over the parapet is there only under a battlement or the roof's block; a
   ; ray over the parapet may meet the end of the one it heads toward, past the wall's face
   al0 (over px0 isx pz0) ea (over ex isx ez)
   da (isx * dz + (1 - isx) * dx)       ; by mask, exact: over's blend rounds a tiny dz beside dx to 0
   east (isx * (0.0 < dx)) north (isz * (0.0 < dz))
   solid ((py0 < hh) + (hh <= py0) * (0 < isz * (mag al0 < hb) + east * (b - cw < al0)))
   gap ((1 - isy) * (1 - solid))
   sa (over -1.0 (0.0 < da) 1.0)
   blk ((0.0 < sa) * (east + north * (hb < al0)))
   ef (over (0.0 - sa * hb) blk (over (b - cw) north a)) dep (over wall-t (blk * east) cw)
   te ((ef - ea) / da) ye (ey + te * dy) pp (over (ez + te * dz) isx (ex + te * dx))
   dd (mag pp - over b isx a)
   endf (gap * (0 < blk + isz * (hb < 0.0 - sa * al0)) * (0.0 <= dd) * (dd <= dep) * (hh <= ye) * (ye < top-h))
   sky (isy * (0.0 < dy) + gap - endf)
   t (over t0w endf te)
   px (over px0 endf (over ef isx pp)) py (over py0 endf ye) pz (over pz0 endf (over pp isx ef))
   ; ..which wall, where along it, and which way it faces: an end faces back along the wall
   wid (isx * (over 1 (0.0 < dx) 0) + isz * (over 3 (0.0 < dz) 2))
   al (over al0 endf (ef + sa * dd))
   nx ((1 - endf) * isx * (over 1.0 (0.0 < dx) -1.0) - endf * isz * sa)
   nz ((1 - endf) * isz * (over 1.0 (0.0 < dz) -1.0) - endf * isx * sa)
   s (lt 'sun) sx (s 0) sy (s 1) sz (s 2)
   sea (court-season st) tr (pins (st 'tree) 'share (sea 'share) 'turn (sea 'turn)) sm (grove-sun tr s sun-clear 0)
   sms [sm (grove-sun (st 'heap) s sun-clear 0)]
   cam {'e [ex ey ez] 'f [(sth * cph) sph (cth * cph)] 'r [cth 0.0 (0.0 - sth)] 'u [(0.0 - sth * sph) cph (0.0 - cth * sph)]
        'w (st 'w) 'h (st 'h) 'foc (st 'foc) 'dx dx 'dy dy 'dz dz}
   ; ..the cables off the walls this frame, and the shade they and the box lay on the walls
   sr (strands t0)
   oc (0.0 < sy ? (shade-walls sr cam s [px py pz wid t] ((1 - sky) * (1 - gnd))) (t * 0.0))
   ; ..each pixel shaded only as what it shows: a surface's on the surfaces' pixels, the
   ; sky's on the sky's, each gathered there and scattered back
   (surface px py pz al wid nx nz gnd oc)
    (:
     ; --- the stuff: a wall's texel by which wall and where on it, a block's end going on
     ; round from its face, else the floor's ---
     nu (peep wall-nus wid 0)
     tu (max 0 (min (nu - 1) (floor ((al + over yard-a (wid < 2) yard-b) / ts))))
     trow (max 0 (min (nv - 1) (floor (py / ts))))
     wi (peep wall-offs wid 0 + trow * nu + tu)
     fi (max 0 (min (fl-nz - 1) (floor ((pz + b) / fts))) * fl-nx + max 0 (min (fl-nx - 1) (floor ((px + a) / fts))))
     wm (mp 'wall) fm (mp 'floor)
     (wg k) (peep (wm k) wi 0.0) (fg k) (peep (fm k) fi 0.0)
     ; ..the floor darker wet and white under snow -- the pale concrete first, the joints,
     ; the moss and a speckle of it last
     fc [(fg 'r) (fg 'g) (fg 'b)] lum ((fc 0 + fc 1 + fc 2) / 3.0)
     spk (frac (sin (fi * 12.9898) * 43758.5453))
     sw (sat (st 'snow * 1.3 - 0.6 * (0.5 - lum) - 0.15 * spk))
     flr (cmix (c* (1.0 - 0.35 * st 'wet) fc) snowc sw)
     alb (cmix [(wg 'r) (wg 'g) (wg 'b)] flr gnd)
     glass ((1 - gnd) * peep (wm 'glass) wi 0)
     ; --- the light: the sun where it faces and gets in past the rim and the battlements,
     ; the sky's light by how much of the sky is seen and how it faces the sun's side, and a
     ; little back off the walls the sun is on ---
     nd (nx * sx + gnd * sy + nz * sz)
     lit ((0.0 < nd) * sun-clear px py pz s * (1.0 - shade sms px py pz) * (1.0 - oc))
     dir (nd * lit * lt 'sunk * 0.9)
     sv (over (0.45 + 0.5 * min 1.0 (py / hh)) gnd 0.42 * (1.0 + 0.2 * lt 'day * (nx * sx + nz * sz)))
     bounce (c* (lt 'sunk * 0.05) (lt 'sunc))
     irr (c+ (c+ (c* sv (lt 'amb)) (c* dir (lt 'sunc))) bounce)
     ; ..a window: the sky in the pane, and the room behind it when it is lit -- each window
     ; by the hour, the stair's whenever it is dark out, a television flickering
     hr (day-secs (st 'sim) / 3600.0)
     key (peep (wm 'key) wi 0) stw (peep (wm 'night) wi 0) tv (peep (wm 'tv) wi 0)
     on (frac (sin (key * 12.9898 + int hr * 78.233) * 43758.5453) * 100.0 < lit-share hr)
     flick (1.0 - tv * (0.3 + 0.25 * sin (t0 * 1.7 + key * 2.1) * sin (t0 * 0.61 + key)))
     lamps (over ((1 - stw) * on * 0.7 * flick) stw ((lt 'day < 0.55) * 0.75))
     panes (c+ (c* 0.25 (lt 'amb)) [0.02 0.025 0.03])
     inglass (c+ panes (c* lamps [(wg 'er) (wg 'eg) (wg 'eb)]))
     (cmix (cm alb irr) inglass glass))
   G (iota (1 - sky)) S (iota sky) (only ix v) (peep v ix 0)
   sf (surface (only G px) (only G py) (only G pz) (only G al) (only G wid) (only G nx) (only G nz) (only G gnd) (only G oc))
   hv (sky-colour-of lt (st 'wx) (only S dx) (only S dy) (only S dz) ex ez (st 'sim) t0 0.0)
   z0 (dx * 0.0)
   col0 (stars! (map (c \ pin (pin z0 G (sf c)) S (hv c)) ^3) st lt cam sky t0)
   ; ..and the tree, drawn over all of it where it is nearer
   buf {'t (over t sky 1e9) 'r (col0 0) 'g (col0 1) 'b (col0 2)}
   _ (grove-wood! tr cam lt sun-clear buf) _ (grove-leaves! tr cam lt sun-clear buf t0)
   ; ..and what lies on the floor, the box and the leaves falling; the loose cables last,
   ; being drawn over what is there
   sn (st 'snow)
   _ (rods! (st 'litter 'rods) cam lt sms buf sn)
   _ (each boxes (bx \ box! bx cam lt sms buf sn))
   _ (bits! (st 'litter 'pts) cam lt sms buf sn)
   _ (lead (st 'litter 'leaves) (18 * int (leaf-n * sea 'ground)) (sea 'brown) @ P (tablet? P ? (bits! P cam lt sms buf sn)))
   _ (loose st @ P (tablet? P ? (bits! P cam lt sms buf sn)))
   _ (rods! sr cam lt sms buf sn)
   ; ..and the rain or snow coming down, by the frame's own clock
   _ (sky-fall! (st 'wx) cam lt buf (1.0 * st 't / fps))
   ; ..and the eye's gain and shoulder
   (sky-tone lt [(buf 'r) (buf 'g) (buf 'b)]))
 ; the frame: the clock in the corner for a while after the time is touched
 (court-frame st) (: w (st 'w) h (st 'h) c (court-pens st) deep (st 'deep)
   px (deep ? (view-deep-pens c) (view-cube-pens c (st 'bay)))
   pace (st 'paces (st 'pace))
   wx (st 'wx)
   txt (" " + court-clock st + (pace = 0.0 ? "  still" (pace = 1.0 ? "" ("  x" + (int pace = pace ? (show (int pace)) (show pace)))))
        + "  " + sky-says (wx 'cover) + (sky-fall wx = 1 ? ", rain" (sky-fall wx = 2 ? ", snow" ""))
        + (wx 'style = 'pixel ? ", in pixels " " "))
   bands (st 't < st 'shown ? {0 [1 txt (deep ? 249660 255) (deep ? 33288 235)]} {})
   (deep ? (view-deep-frame w h px bands)
      (view-frame w h (y \ peep px (iota w + w * y) 0) bands)))
 ; --- the walk, on view's loop; court-run raises the stage ---
 ; ..o says how to start, or () for now and the run's own weather: 'now [local-seconds
 ; dst], 'wx the weather, 'pace seconds of the sky a second (t steps on to the usual ones)
 (court-walk o) (: (opt k) (tablet? o ? (o k) ())
   (view-walk {'new (w \ h \ (: st (pin (court-new w h (opt 'now @ n (n ? n (court-now ())))) 'deep
                                         (elem (getenv "COLORTERM") ["truecolor" "24bit"]))
                                  wx (opt 'wx) p (opt 'pace)
                                  _ (wx ? (pins st 'wx wx 'drift (opt 'fix ? 0 1)))
                                  (charm? p ? (pins st 'paces (p . paces) 'pace 0) st)))
               'size court-size 'frame court-frame 'key court-step 'tick court-move
               'fps fps 'song (hn \ ()) 'linger 0 'next ()}))
 (court-run o) (view-run (_ \ court-walk o))
 court-usage "usage: love lore court [--date YYYY-MM-DD] [--time HH:MM] [--pace N] [--weather clear|partly|mostly|overcast] [--sky smooth|pixel] [--fall none|rain|snow]   (the weather words, rain and snow may stand alone; h l turn, k j step, u n look, [ ] an hour, t the pace, c the cloud, p rain or snow, v the sky's style; q or esc leaves)"
 ; --- the words: a date, a time, a pace, the weather's cover and the sky's style, each at
 ; most once and in any order -> the walk's start, or () for words it cannot read. a date
 ; or a time alone keeps the other from now ---
 (court-opts as) (: (ix l w) (: (go i) (i < #l ? (l i = name w ? i (go (i + 1))) ()) (go 0))
   (cov w) (ix sky-covers w) (sty w) (ix sky-styles w) (fal w) (ix sky-falls w)
   (dnum w) (: n #w (go i v) (i < n ? (48 <= w i <= 57 ? (go (i + 1) (v * 10 + w i - 48)) ()) v)
               (0 < n ? (go 0 0) ()))
   (date w) (w @ (y + "-" + m + "-" + d)
                 (: a (dnum y) b (dnum m) c (dnum d)
                    (charm? a && charm? b && charm? c && 0 < b && b <= 12 && 0 < c && c <= 31 ? [a b c]))
                 _ ())
   (hm w) (w @ (h + ":" + m) (: a (dnum h) b (dnum m) (charm? a && charm? b && a < 24 && b < 60 ? (3600 * a + 60 * b)))
               _ ())
   (pnum w) (: cs (chars w) (0 < #w && all (c \ (48 <= c && c <= 57) || c = 46) cs && #(filter (c \ c = 46) cs) < 2
                             && 48 <= w 0 && w 0 <= 57 ? (1.0 * <(sound w))))
   o {}
   (once k v r) (v = () || o k != () ? () (pin o k v, go r))
   (go l) (? (atom? l) o
             (two? >l && <l = "--date") (once 'date (date <>l) >>l)
             (two? >l && <l = "--time") (once 'time (hm <>l) >>l)
             (two? >l && <l = "--pace") (once 'pace (pnum <>l) >>l)
             (two? >l && <l = "--weather") (once 'cov (cov <>l) >>l)
             (two? >l && <l = "--sky") (once 'sty (sty <>l) >>l)
             (two? >l && <l = "--fall") (once 'fall (fal <>l) >>l)
             (<l = "rain" || <l = "snow") (once 'fall (fal <l) >l)
             (charm? (cov <l)) (once 'cov (cov <l) >l)
             (charm? (sty <l)) (once 'sty (sty <l) >l)
             ())
   r (go as)
   (tablet? r ?
      (: now0 (court-now ()) l0 (int (now0 0)) d (r 'date) t (r 'time)
         now (? (d = () && t = ()) now0
                (court-local (86400 * (d = () ? (l0 // 86400) ((cite 'cal 'epoch-days) (d 0) (d 1) (d 2)))
                              + (t = () ? (l0 % 86400) t))))
         c (r 'cov) y (r 'sty) fl (r 'fall) l (now 0) sd (int l) m (court-month l)
         ; ..what is not said is the season's: a fall said without a cover comes from overcast
         sty (y = () ? 'smooth (sky-styles y))
         c2 (? (c != ()) c (0 < fl) 3 (court-wx-pick m (throw sd 7 71 20)))
         {'now now 'pace (r 'pace) 'fix (c = () && fl = () ? 0 1)
          'wx (c = () && y = () && fl = () ? ()
                 (wx-of c2 sty (fl = () ? (court-fall-pick m c2 (throw sd 9 73 20) (throw sd 11 79 2)) fl)))})))
 (court-main as) (court-opts as @ o
   (tablet? o ? (court-run o) (say err ("court: " + court-usage + "\n"), flush err, 2)))
 _ ((cite 'lore 'lore-enlist) 'court (udoor 'court court-main court-usage 1 1)))
) ; module court
