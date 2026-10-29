; court -- the inner courtyard of an apartment block, first person: the level after the shaft.
; the walls and floor are texel maps laid once a run, the tree is grove's grown to tree-habit,
; the sun, sky and weather are sky's at a fixed latitude on a clock that runs fast; all drawn
; in triangles through mesh.l. court-new, court-step, court-move and court-frame are pure;
; only court-walk and court-run tie the tty, and court-walk takes a stage already raised.
(module (court court-run court-walk court-main court-new court-size court-step court-move court-binds
         court-frame court-sun court-light court-clock court-now court-local court-doy court-season
         court-opts court-wx-pick court-fall-pick court-month court-pens court-maps
         tree-grow top-h block-h crown-y runs boxes strands wall-of wall-texel stars windows
         fps yard-a yard-b floor-h floors wall-h eye-h body-r lat paces crate-of plate-of plate-r)
(borrow 'rove)
(borrow 'view)                          ; the screen, the pens, the hash, the loop
(borrow 'vec)                           ; triples, and the noise
(borrow 'sky)                           ; the sun, its light, the sky's colour
(borrow 'grove)                         ; the tree of heaven
(borrow 'flicker)                       ; a television's flicker
(borrow 'walk)                          ; the keys
(borrow 'mesh)                          ; the triangles, lit and drawn
(:
 fps 20
 ; --- the yard, in metres: x east, z north, y up, the sump at the origin; the long walls at
 ; x = -a and a, the short at z = -b and b. walls 0..3 are east, west, north, south ---
 yard-a 3.05 yard-b 4.57
 floors 4 floor-h 3.0
 wall-h (floors * floor-h + 0.5)        ; ..and a parapet over the top floor
 ; the battlements, a floor high over the short walls: [wall centre half-length]; the roof's
 ; block as high at the east wall's north end
 block-h floor-h top-h (wall-h + block-h) wall-t 0.45 cw 1.8 lip 0.07
 bats [[2 -0.9 1.8] [2 2.45 0.6] [3 0.1 1.8]]
 eye-h 1.6 body-r 0.3
 walk-v 1.4 turn-step 0.07 tilt-step 0.06
 lat (40.7 * pi / 180.0)
 paces [60.0 600.0 1.0 0.0]             ; seconds of the sky a second, t steps through them
 ; the litter: heap branches, twigs, ground leaves, a lying leaf's height, landed leaves kept,
 ; fall speed; the barks' and the leaves' colours
 heap-n 64 stick-n 14 leaf-n 420 leaf-y 0.006 fallen-n 400 fall-v 0.45
 barks [[0.19 0.16 0.13] [0.15 0.12 0.09] [0.12 0.1 0.08] [0.27 0.26 0.23] [0.33 0.28 0.21]]
 snowc [0.88 0.9 0.94]
 hues [[0.6 0.5 0.17] [0.5 0.39 0.19] [0.36 0.26 0.14] [0.33 0.38 0.13]]
 ; the weather's odds by month, in twentieths: clear, partly, mostly cloudy, overcast
 wx-odds [[4 5 4 7] [4 5 4 7] [4 5 5 6] [4 6 5 5] [4 7 5 4] [5 7 5 3]
          [5 8 4 3] [6 7 4 3] [7 7 3 3] [7 6 3 4] [5 5 4 6] [4 5 4 7]]
 ; ..and the twentieths it rains or snows under overcast (half that mostly cloudy, none lighter)
 fall-odds [9 9 9 9 9 8 7 7 7 7 8 9]
 ; a long wall's sashes bay apart; half-widths of a sash and a small window; rise, an arch's lift
 bay 1.8 sash-w 0.36 nook-w 0.17 rise 0.09
 ; --- the windows, each [wall along half-width sill height key kind]: kind 0 a sash, 1 a small
 ; corner one, 2 a short wall's, 3 the stair's between the floors ---
 windows (: fls ^floors
   (key wid fl k) (wid * 100 + fl % 8 * 10 + k)
   (long wid) (catmap (fl \ (: y (fl * floor-h) nb (wid @ 0 0.9 1.4)
                                 cs (? (wid = 0) [-4.05 -3.45 3.45 4.05] (0 < fl) [-3.8 3.8] [])
                                 (cat (map (wi \ [wid ((wi - 1.5) * bay) sash-w (y + 0.9) 1.4 (key wid fl (2 <= wi)) 0]) ^4)
                                      (map (c \ [wid c nook-w (y + nb) (2.3 - nb) (key wid fl (4 + 2 * (0.0 < c))) 1]) cs))))
                         fls)
   (short wid) (cat (catmap (fl \ map (c \ [wid c 0.25 (fl * floor-h + 0.9) 1.5 (key wid fl (4 + (0.0 < c))) 2]) [-1.6 1.6]) fls)
                    (map (fs \ [wid 0.0 0.3 (2.45 + fs * floor-h) 1.2 (key wid fs 0) 3]) ^(floors - 1)))
   (cats [(long 0) (long 1) (short 2) (short 3)]))
 ; ..one air conditioner, on the sill of the west wall's south sash on the top floor
 (cooled? w) (w 0 = 1 && w 6 = 0 && w 1 < -2.0 && (floors - 1) * floor-h < w 3)
 ; --- the cables: one run along the west wall and round onto the short walls into a box on
 ; each, and loose strands (strands). a run is [width colour waypoints], each step along one
 ; axis on one wall's face; a box is [low corner, high corner, wall] ---
 cab [0.25 0.25 0.26]
 boxes [[[0.95 3.9 (yard-b - 0.23)] [1.25 4.2 yard-b] 2] [[0.95 3.9 -yard-b] [1.25 4.2 (0.23 - yard-b)] 3]]
 (to-box z) [[1.09 3.9 z] [1.09 2.62 z] [0.45 2.62 z] [0.45 2.3 z] [-0.43 2.3 z] [-0.43 2.62 z] [-yard-a 2.62 z]]
 runs [[0.04 cab (to-box -yard-b + rev (to-box yard-b))]]
 ; --- the time: 'sim is local seconds, 'dst what summer adds: the offset now less the least
 ; of it a season, two and three on ---
 ; the zone's offset at utc u, the zone read once a call
 (zone-off _) (: zone (cite 'kore 'tz-zone 0) (u \ zone ? (zone u 0) 0))
 (court-when s) (: off (zone-off 0)
                   o (off s) std (foldl (a \ k \ min a (off (s + k * 7889400))) o [1 2 3])
                   [(1.0 * (s + o)) (o - std)])
 (court-now _) (court-when (clock 0 // 1000))
 ; ..and a wall-clock time L in local seconds, as [L dst] in this zone
 (court-local L) (: off (zone-off 0) l (int L)
                    (court-when (l - off (l - off l))))
 ; --- the season, by the day of the year (0 the first of january): leafing mid april to mid
 ; may, turning from late september, dropping mid october to mid november; seeds june to
 ; april. a leaf lets go about one frame in 'every ---
 (court-doy st) (: d (st 'sim / 86400.0 - 10957.0) (d - 365.2422 * floor (d / 365.2422)))
 (court-season st) (: d (court-doy st) spring (sat ((d - 108.0) / 22.0)) drop (sat ((d - 285.0) / 30.0))
   share (min spring (1.0 - drop))
   {'share share 'turn (sat ((d - 262.0) / 28.0))
    'seeds (150.0 <= d ? sat ((d - 160.0) / 25.0) (1.0 - sat ((d - 90.0) / 35.0))) 'ripe (150.0 <= d ? sat ((d - 165.0) / 135.0) 1.0)
    'ground (285.0 <= d ? (0.12 + 0.88 * drop) (max 0.12 (1.0 - 0.88 * sat (d / 150.0))))
    'brown (285.0 <= d ? 0.1 0.65)
    'every (? (share < 0.05) 0 (285.0 <= d && d < 320.0) 6 300)})
 (court-clock st) (: d (day-secs (st 'sim)) hh (int (d / 3600.0)) mm (int (d / 60.0) % 60)
                     (zpad 2 (show hh) + ":" + zpad 2 (show mm)))
 ; the sun as [east up north] and its light, at the scene's hour
 (court-sun st) (sky-sun (st 'sim) (st 'dst) lat)
 (court-light st) (sky-light (court-sun st) (st 'wx) (st 'sim))
 ; --- the state: view's screen, the player's place, 'th the bearing, 'ph the pitch, the clock
 ; and its pace. a run starts by the east wall looking up into the crown ---
 (court-new w h now) (: sd (int (now 0)) tr (tree-grow sd) lr (litter tr sd)
                        bs (tr 'base)
                        st {'px (yard-a - 0.5) 'pz (bs 2 - 1.0) 'th -(pi / 2.0) 'ph 1.4
                            'sim (now 0) 'dst (now 1) 'pace 0 'paces paces 'shown 40 't 0
                            'deep 0 'done 0 'tree tr 'litter lr 'fall () 'fallen ()
                            'wx (court-season-wx (now 0) sd)
                            'drift 1 'hour (int (now 0 // 3600))}
                        _ (pins st 'wet (sky-fall (st 'wx) @ 1 0.8 0.0) 'snow (sky-fall (st 'wx) @ 2 0.6 0.0))
                       (court-size st w (h // 2)))
 ; the screen w cells by r rows, two pixels a row, and its dither; under kitty 'kp pixels
 ; a column (mesh-size)
 (court-size st w r) (mesh-size st w r)
 ; --- moving ---
 ; ..kept inside the walls and out of the trunk where it passes the eye
 (put! st x z) (: ma (yard-a - body-r) mb (yard-b - body-r) b0 (st 'tree 'base) fk (st 'tree 'fork)
                  bs (c+ b0 (c* (eye-h / fk 1) (c+ fk (c* -1.0 b0))))
                  x2 (clamp x -ma ma) z2 (clamp z -mb mb)
                  qx (x2 - bs 0) qz (z2 - bs 2) d (sqrt (2 qx + 2 qz)) m (0.3 + body-r)
                  (d < m ? (pins st 'px (bs 0 + qx * m / max d 0.001) 'pz (bs 2 + qz * m / max d 0.001))
                     (pins st 'px x2 'pz z2)))
 ; ..the court's own keys, over view's
 court-binds {91 'hour-back 93 'hour-on 116 'pace 99 'clouds 112 'fall}
 (court-step st a) (: (tell st2) (pin st2 'shown (st 't + 2 * fps))
   (walk-key st a {'turn turn-step 'walk (walk-v / fps) 'tilt tilt-step 'up 1.45 'down -1.2} put!
    @ () (a @ 'hour-back (tell (pin st 'sim (st 'sim - 3600.0)))
              'hour-on (tell (pin st 'sim (st 'sim + 3600.0)))
              'pace (tell (pin st 'pace ((st 'pace + 1) % #(st 'paces))))
              'clouds (tell (pins st 'wx (wx-of ((st 'wx 'cover + 1) % 4) (sky-fall (st 'wx))) 'drift 0))
              'fall (tell (pins st 'wx (wx-of (st 'wx 'cover) ((sky-fall (st 'wx) + 1) % 3)) 'drift 0))
              st)
      s s))
 ; a frame's motion: the clock, and the leaves -- now and then one lets go of the top of
 ; the crown, drifts down and lies where it lands
 (court-move st) (: t (st 't) tops (st 'litter 'tops) sea (court-season st) ev (sea 'every)
   ; ..gold in the fall, else mostly green
   hue (0.5 < sea 'turn ? (throw t 9 79 3) (throw t 9 79 4 @ 0 0 3))
   born (0 < ev && throw t 3 97 ev = 0 && two? tops ?
         (tops (throw t 5 89 #tops) @ p [[(p 0) (p 1) (p 2) (throw t 7 83 628 / 100.0) hue]]))
   moved (map (q \ fall-step q t) (cat born (st 'fall)))
   down (filter (q \ q 1 <= leaf-y) moved)
   ; ..the ground under the weather, in sky seconds: rain wets it in half an hour, it dries in
   ; three; snow covers it in three hours and goes in six, one under rain
   dt (st 'paces (st 'pace) / fps) f (sky-fall (st 'wx))
   _ (pins st 'sim (st 'sim + dt)
             'fall (filter (q \ leaf-y < q 1) moved)
             'fallen (newest fallen-n (cat down (st 'fallen)))
             'wet (sat (st 'wet + (f @ 1 (dt / 1800.0) -(dt / 10800.0))))
             'snow (sat (st 'snow + (f @ 2 (dt / 10800.0) (-dt / (f @ 1 3600.0 21600.0))))))
   (court-drift st))
 ; --- the weather: a month's odds pick a cover from k in 0..19; while 'drift is set it steps
 ; a notch toward a fresh draw about one sky hour in four ---
 (court-month sim) (cite 'cal 'civil (int sim // 86400) 1)
 (court-wx-pick m k) (: o (wx-odds (m - 1))
   (go i a) (i < 3 && a + o i <= k ? (go (i + 1) (a + o i)) i)
   (go 0 0))
 ; ..and what falls from a cover in month m, from k in 0..19 and a coin j for the
 ; months between rain and snow
 (court-fall-pick m c k j) (: o (fall-odds (m - 1))
   (? (c < 2 || (c @ 3 o (o // 2)) <= k) 0
      (m = 12 || m <= 2) 2
      (m = 3 || m = 11) (j @ 0 2 1)
      1))
 (wx-of c f) (pins (sky-weather c) 'fall f)
 ; the season's weather at local seconds l, its dice from sd
 (court-season-wx l sd) (: m (court-month l) c (court-wx-pick m (throw sd 7 71 20))
   (wx-of c (court-fall-pick m c (throw sd 9 73 20) (throw sd 11 79 2))))
 ; ..an hour on: the cover stepped one in four, and the fall kept two in three while the
 ; cover can hold it, else drawn again
 (court-drift st) (: h (int (st 'sim // 3600))
   (? (h = st 'hour) st
      !(st 'drift) (pin st 'hour h)
      (: m (court-month (st 'sim)) c0 (st 'wx 'cover) f0 (sky-fall (st 'wx))
         to (court-wx-pick m (throw h 13 59 20))
         c (throw h 11 67 4 @ 0 (c0 + (to < c0 ? -1 (c0 < to ? 1 0))) c0)
         f (? (c < 2) 0 (0 < f0 && throw h 21 43 3 != 0) f0
              (court-fall-pick m c (throw h 17 53 20) (throw h 19 47 2)))
         (pins st 'hour h 'wx (wx-of c f)))))
 ; --- the maps: the walls and the floor laid once a run in texels, gathered from each frame ---
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
 ; a room's light at g: a lamp's warm, a television's blue, a bathroom's white, the stair and
 ; hall's sh and the lobby's lob
 (room-em g tv bw sh lob) (cmix (cmix (cmix (cmix (c* g [1.0 0.76 0.44]) [0.5 0.62 1.0] tv) (c* g [0.9 0.88 0.8]) bw)
                                [0.85 0.95 0.82] sh) [0.95 0.8 0.52] lob)
 ; a wall texel: its colour, and what its window shows lit -- 'glass, 'key the window,
 ; 'night lit all night, 'tv
 (wall-at i) (:
   wid ((nu-long * nv <= i) + (2 * nu-long * nv <= i) + ((2 * nu-long + nu-short) * nv <= i))
   nu (wall-nus wid) j (i - wall-offs wid)
   isx (wid < 2) isz (1 - isx)
   half (over yard-a isx yard-b)
   al ((j % nu + 0.5) * ts - half) py ((j // nu + 0.5) * ts)
   b yard-b hh wall-h
   fl (floor (py / floor-h)) yy (py - fl * floor-h) infl (fl < floors)
   ; the windows, as windows lays them
   wi (max 0 (min 3 (floor (al / bay + 2.0)))) ca (al - (wi - 1.5) * bay)
   lr (sat (1.0 - sq (ca / sash-w)))
   lw (isx * (sq ca < 2 sash-w) * (0.9 < yy) * (yy < 2.3 + rise * lr) * infl)
   ea (mag al) ei ((wid = 0) * (3.75 < ea)) na (ea - over 3.8 (wid = 0) (over 3.45 ei 4.05))
   nk (isx * ((wid = 0) + (wid = 1) * (0.0 < fl)) * infl)
   nb (over 1.4 (wid = 0) 0.9) bath (wid = 1)
   nw (nk * (sq na < 2 nook-w) * (nb < yy) * (yy < 2.3))
   sa (mag al - 1.6)
   sr (sat (1.0 - sq (sa / 0.25)))
   sw (isz * (sq sa < 0.0625) * (0.9 < yy) * (yy < 2.4 + rise * sr) * infl)
   ys (py - 2.45) fs (floor (ys / floor-h)) yys (ys - fs * floor-h)
   stw (isz * (sq al < 0.09) * (yys < 1.2) * (0 <= fs) * (fs < floors - 1))
   win (lw + nw + sw + stw)
   sill (0 < (isx * (sq ca < sq (sash-w + 0.04)) + isz * (sq sa < 0.09)) * (0.82 < yy) * (yy <= 0.9) * infl
              + nk * (sq na < 0.048) * (nb - 0.08 < yy) * (yy <= nb))
   ; ..a window's frame: its edges, and the meeting rail between the two sashes
   cp (lw * ca + nw * na + sw * sa + stw * al) hw (lw * sash-w + nw * nook-w + sw * 0.25 + stw * 0.3)
   vp ((lw + sw) * (yy - 0.9) + nw * (yy - nb) + stw * yys) vh (lw * 1.4 + nw * (2.3 - nb) + sw * 1.5 + stw * 1.2)
   arc (lw * rise * lr + sw * rise * sr)
   frm (win * (0 < (hw - mag cp < 0.05) + (vp < 0.07) + (vh + arc - vp < 0.06) + (mag (vp - 0.5 * vh) < 0.03)))
   glass (win - frm)
   ; ..the arch over a sash or a short wall's window: a course of bricks on end, wider
   ; than the opening and rising with it, its joints fanned
   la (sash-w + 0.08) sb 0.33
   arch (isx * (sq ca < 2 la) * (2.3 + rise * lr <= yy) * (yy < 2.42 + rise * sat (1.0 - sq (ca / la))) * infl
         + isz * (sq sa < 2 sb) * (2.4 + rise * sr <= yy) * (yy < 2.52 + rise * sat (1.0 - sq (sa / sb))) * infl)
   ajt (frac ((isx * ca + isz * sa) / 0.075) < 0.2)
   ; ..each room its own by wkey: lamps warm and various, some curtained, some a television,
   ; a bathroom's white; the lobby, the stair and the ground floor halls lit all night
   wkey (wid * 100 + fl % 8 * 10 + lw * (2 <= wi) + nw * (4 + 2 * (0.0 < al)) + sw * (4 + (0.0 < al)))
   lob (lw * (wid = 1) * (fl = 0)) hall (sw * (fl = 0) * (al < 0.0)) nt (stw + lob + hall)
   bw (nw * bath)
   tv ((throw wkey 0 13 9 = 0) * (1 - nt) * (1 - bw))
   cur ((throw wkey 1 19 3 = 0) * (1 - lob))
   lamp (0.55 + 0.45 * (throw wkey 2 23 10 / 10.0))
   glow (lamp * (1.0 - 0.6 * cur * (hw * 0.45 < mag cp)))
   em (room-em glow tv bw (stw + hall) lob)
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
   blk (0 < foldl (n \ bt \ n + (wid = bt 0) * (mag (al - bt 1) < bt 2)) 0 bats + (wid = 0) * (b - cw < al)) up (blk * (hh - 0.18 <= py))
   cope ((hh - 0.18 < py) * (1 - blk))
   ; ..the battlements: the paint blotched and streaked down from the cap, chipped more
   streak (sat (vn (al * 9.0) 0.5 77 * 2.2 - 0.9) * sat (1.0 - (top-h - py) / 1.4))
   worn (c* ((0.8 + 0.3 * vn (al * 3.0) (py * 3.0) 78) * (1.0 - 0.4 * streak)) [0.6 0.61 0.6])
   chip2 (0 < (throw cx cy (wid + 13) 3 = 0) * (throw bi row (wid + 7) 2 = 0) + (throw bi row (wid + 9) 40 = 0))
   battle (cmix (cmix worn under chip2) [0.7 0.68 0.63] (top-h - 0.14 < py))
   ; ..a frame dark brown, one in four painted white
   fw (throw wkey 3 29 4 = 0) fc (cmix [0.16 0.12 0.09] [0.7 0.7 0.66] fw)
   ; ..the door, a dark brown in a darker frame, its knob brass on the right
   dr ((wid = 3) * (ea < 0.5) * (py < 2.1))
   dfr (dr * (0 < (0.5 - ea < 0.05) + (2.1 - py < 0.05)))
   knob (dr * (sq (al + 0.36) + sq (py - 1.0) < 0.0009))
   brick (cmix (cmix paint2 under chip) (c* (0.78 - 0.18 * ajt) paint2) arch)
   alb (cmix (cmix (cmix (cmix (cmix (cmix (cmix brick [0.68 0.66 0.62] sill) fc frm) [0.5 0.49 0.46] cope)
                         battle up) [0.17 0.115 0.08] dr) [0.1 0.075 0.055] dfr) [0.55 0.45 0.22] knob)
   {'r (alb 0) 'g (alb 1) 'b (alb 2) 'glass glass 'key wkey 'night nt 'tv tv
    'er (em 0) 'eg (em 1) 'eb (em 2)})
 ; the floor: eight triangular slabs meeting at the sump, split by the axes and the diagonals,
 ; each a shade apart; moss thickest by the walls, in the joints and round the sump's grate
 sump-r 0.2
 (floor-at i) (: a yard-a b yard-b
   px ((i % fl-nx + 0.5) * fts - a) pz ((i // fl-nx + 0.5) * fts - b)
   r2 (sq px + sq pz) dg (sqrt (2 a + 2 b))
   ux (mag px) uz (mag pz)
   jd (min (min ux uz) (mag (b * ux - a * uz) / dg))        ; to the nearest joint
   joint ((jd < 0.02) * (2 sump-r < r2))
   oct ((0.0 < px) * 4 + (0.0 < pz) * 2 + (a * uz < b * ux))
   tone (gem-tray [8] [0.97 1.03 0.94 1.0 1.02 0.95 1.04 0.98] oct)
   de (min (a - ux) (b - uz))
   mf (0.55 * vn (px * 1.3) (pz * 1.3) 31 + 0.3 * vn (px * 4.1) (pz * 4.1) 32
       + 0.45 * sat (1.0 - de / 1.3) + 0.3 * sat (1.0 - r2 / 1.0) + 0.5 * sat (1.0 - jd / 0.12) - 0.02)
   moss (sat ((mf - 0.15) * 2.0))
   speck (throw (floor (px * 30.0)) (floor (pz * 30.0)) 34 9 = 0)
   conc (c* (tone * (0.9 + 0.2 * vn (px * 7.0) (pz * 7.0) 33) * (1.0 - 0.15 * speck)) [0.5 0.5 0.47])
   mossc (c* (0.75 + 0.45 * vn (px * 9.0) (pz * 9.0) 35) [0.2 0.31 0.12])
   wet (1.0 - 0.2 * (r2 < 0.2) - 0.35 * joint)
   sump (r2 < 2 sump-r)
   rim (sump * (2 (sump-r - 0.035) < r2))
   bar (frac ((px + sump-r) / 0.06) < 0.5)
   grate (cmix (cmix [0.01 0.01 0.01] [0.18 0.16 0.14] bar) [0.24 0.21 0.18] rim)
   alb (cmix (c* wet (cmix conc mossc moss)) grate sump)
   {'r (alb 0) 'g (alb 1) 'b (alb 2)})
 ; ..laid a slice of k texels at a time, so the intermediates are held for a slice, not the map
 (lay-map n f) (: k 16384
   (go lo out) (lo < n ? (: ix (lo + iota (min k (n - lo))) c (f ix)
                            (go (lo + k) (foldl (o \ key \ pin o key (pin (peep o key (iota n * 0 + peep (c key) 0 0 * 0)) ix (c key)))
                                                out (keys c))))
                         out)
   (go 0 {}))
 (court-maps _) (maps 'wall ? maps (: m (lay-map wall-n wall-at) _ (each runs (lay-run m))
                                     (pins maps 'wall m 'floor (lay-map (fl-nx * fl-nz) floor-at))))
 ; --- the tree: below the wall tops a point is kept inside the walls, or not grown in one ---
 crown-y 5.5
 (inside p) (p 1 < wall-h ? [(clamp (p 0) (0.15 - yard-a) (yard-a - 0.15)) (max 0.05 (p 1))
                            (clamp (p 2) (0.15 - yard-b) (yard-b - 0.15))] p)
 (in-wall? p) (p 1 < wall-h && (yard-a - 0.1 < mag (p 0) || yard-b - 0.1 < mag (p 2)))
 ; its habit: the trunk from the east wall leaning a little west to a fork in the third floor,
 ; a long limb climbing south and a short one back east, long thin branches sweeping off the
 ; long one. grown with grove's kit k from base, it answers the fork
 (tree-habit base k) (: rr (k 'rr) spread (k 'spread) dir (k 'dir) seg! (k 'seg) branch! (k 'branch)
                        head! (k 'head) spray! (k 'spray) sprig! (k 'sprig) tuft! (k 'tuft)
    tw [0.0 1.0]                          ; the point on the ground, [x z], the trunk leans toward
    cdir (unit [(tw 0 - base 0) 0.0 (tw 1 - base 2)])
    ; the trunk: leaning straight on, a little crooked, to the fork
    hf (rr 7.6 8.6) lean (rr 1.3 1.6)   ; the fork's height and how far it stands off the foot
    (tp f) (c+ (c+ base (c* (lean * f) cdir)) [0.0 (hf * f) 0.0])
    tq (map (f \ (0.0 < f < 1.0 ? (c+ (tp f) [(rr -0.1 0.1) 0.0 (rr -0.1 0.1)]) (tp f))) [0.0 0.2 0.4 0.6 0.8 1.0])   ; its crook
    _ (each ^5 (i \ seg! (tq i) (tq (i + 1)) (0.22 - 0.08 * i / 5.0)))   ; its girth, foot to fork
    fk (tq 5)
    ; ..the fork: a long limb steep off to the lean's left, a short one up and back; ways weighed
    ; from up, cdir (the lean) and lh (its left); (branch! from way length pieces r0 r1 bend droop)
    lh [-(cdir 2) 0.0 (cdir 0)]
    up (branch! fk (unit (c+ (c+ [0.0 2.0 0.0] (c* 1.6 cdir)) (c* 1.1 lh))) (rr 3.2 3.8) 6 0.12 0.07 0.3 0.0)   ; the long limb
    _ (head! up 4 (int (rr 10.0 13.99)))   ; its head: from joint 4, the stubs
    ot (branch! fk (unit (c+ (c+ [0.0 1.6 0.0] (c* 0.4 cdir)) (c* (rr -0.3 -0.1) lh))) (rr 2.4 3.0) 5 0.12 0.08 0.3 0.0)   ; the short limb
    _ (head! ot 3 (int (rr 9.0 12.99)))
    ; ..and off the long one, low, a limb or two out to the side with twigs of their own
    _ (each [2 3] (i \ (: d (spread (dir (up (i - 1)) (up i)) (rr 0.9 1.4))   ; off joints 2 and 3
                          st (branch! (up i) d (rr 1.5 2.6) 3 0.05 0.025 0.4 0.05)
                          (tuft! (st 3) (dir (st 2) (st 3)),
                           each [1 2 3] (m \ spray! (st m) (unit (c+ (spread (dir (st (m - 1)) (st m)) (rr 0.3 0.9)) [0.0 0.2 0.0])) (rr 0.5 0.9) 2 0.3)))))
    ; ..and the long ones sweeping out low off the long limb, twigs off them, leaves at every end
    _ (each ^(int (rr 2.0 3.99))   ; how many
        (j \ (: o (lerp (up 2) (up 3) (rr 0.0 1.0)) a (rr -0.5 0.3)   ; from where, turned how far
                d (unit (c+ (turn (unit (c+ lh (c* 0.3 cdir))) [0.0 1.0 0.0] a) [0.0 0.6 0.0]))   ; their way
                sw (branch! o d (rr 2.6 3.8) 7 0.06 0.022 0.35 0.07)
                (each [2 3 3 4 4 5 5 6 6] (i \ (: d2 (unit (c+ (spread (dir (sw (i - 1)) (sw i)) (rr 0.5 1.1)) [0.0 -0.4 0.0]))
                                        tw2 (branch! (sw i) d2 (rr 0.4 1.0) 2 0.018 0.01 0.4 0.15)
                                        (tuft! (tw2 2) (dir (tw2 1) (tw2 2))))),
                 each ^7 (i \ sprig! (sw (i + 1)) (dir (sw i) (sw (i + 1)))),
                 tuft! (sw 7) (dir (sw 6) (sw 7))))))
    fk)
 (tree-grow seed) (: g (rnd-new seed) (rr lo hi) (lo + (hi - lo) * rnd g)
                     base [(rr 1.75 2.05) 0.0 (rr 1.2 1.5)]   ; its foot, x east and z north
                     (grove-new {'seed seed 'base base 'habit (tree-habit base) 'crown crown-y
                                 'inside inside 'keep? (p \ !(in-wall? p))}))
 ; --- the litter, laid once a run from the tree's seed: the heap at the trunk's foot, twigs,
 ; ground leaves, and the high leaves a falling one starts from. a point is [x y z r g b up],
 ; up 1 lying flat; a branch is [a b r colour bark] ---
 (newest n l) (n < 1 || atom? l ? () (<l . newest (n - 1) >l))
 ; a milk crate leaning back on the trunk's north side, open side up, propped by a branch:
 ; [centre half-sizes tilt reach], reach the half-sizes of the room it takes; a plate east of it
 (crate-of bs) (: a (pi / 4.0) hx 0.24 hy 0.165 hz 0.14 cy (hy * cos a + hz * sin a) ez (hy * sin a + hz * cos a)
   [[(bs 0) cy (bs 2 + 0.22 + ez)] [hx hy hz] a [hx cy ez]])
 (plate-of bs) [(bs 0 + 0.7) 0.0 (bs 2 + 0.36)]
 plate-r 0.145
 ; a leaf lying at x z, turned ang: its stalk and a leaflet either side, six along
 (lying x z ang c) (: ca (cos ang) sa (sin ang)
   (catmap (j \ (: u ((j - 2.5) * 0.012)
                 (map (v \ [(x + u * ca - v * sa) leaf-y (z + u * sa + v * ca) (c 0) (c 1) (c 2) 1.0])
                      [-0.01 0.0 0.01]))) ^6))
 (litter tr seed) (: g {'s (seed % 2147483647 + 7)}
   (rr lo hi) (lo + (hi - lo) * rnd g)
   bs (tr 'base) X (tr 'x) Y (tr 'y) Z (tr 'z) K (tr 'kind) n #X top (amax Y)
   ; a leaf of the crown, thrown for until one comes up, or the first point
   (pick k ok?) (: i (int (rr 0.0 (n - 0.5))) (k < 1 || K i = 2.0 && ok? i ? i (pick (k - 1) ok?)))
   ; ..the heap: branches in a ring hard against the trunk so no floor shows, most along the
   ; ring, the rest pointing out; most forked
   (keep q) [(clamp (q 0) (0.12 - yard-a) (yard-a - 0.12)) (q 1) (clamp (q 2) (0.12 - yard-b) (yard-b - 0.12))]
   (round a d y) (keep [(bs 0 + d * cos a) y (bs 2 + d * sin a)])
   (from q) (sqrt (sq (q 0 - bs 0) + sq (q 2 - bs 2)))
   (mound d) (0.2 * sat (1.0 - (d - 0.25) / 0.7))
   (bark _) (c* (rr 0.85 1.15) (barks (int (rr 0.0 4.99))))
   ; ..a fork that would reach into the trunk goes the other way
   (fork a b r c fz k) (: p (lerp a b (rr 0.4 0.75)) ax (c+ b (c* -1.0 a))
     ang ((rr 0.0 1.0 < 0.5 ? -1.0 1.0) * rr 0.4 0.9) ln (rr 0.3 0.55 * sqrt (dot ax ax))
     (tip g) (keep (c+ p (c* ln (unit (turn (unit ax) [0.0 1.0 0.0] (g * ang))))))
     q (tip 1.0 @ q (from q < 0.3 + r ? (tip -1.0) q) @ q [(q 0) (max (0.55 * r) (q 1 + rr -0.1 0.05)) (q 2)])
     rd [p q (0.55 * r) c fz]
     (0 < k && rr 0.0 1.0 < 0.5 ? (rd . fork p q (0.55 * r) c fz (k - 1)) [rd]))
   (branch _) (: a (rr 0.0 tau) r (rr 0.022 0.06) c (bark 0) fz (rr 0.15 0.35)
     (lift q) [(q 0) (r + rr 0.0 1.0 * mound (from q)) (q 2)]
     ends (rr 0.0 1.0 < 0.35
           ? [(lift (round a (0.27 + r) 0.0)) (lift (round (a + rr -0.15 0.15) (rr 0.6 1.1) 0.0))]
           (: dv (rr -0.45 0.45) d ((0.27 + r + sq (rr 0.0 1.0) * 0.4) / cos dv)
              m (round a d 0.0) yaw (a + pi / 2.0 + dv) hl (rr 0.3 0.8)
              (end k) (lift (keep [(m 0 + k * hl * cos yaw) 0.0 (m 2 + k * hl * sin yaw)]))
              [(end -1.0) (end 1.0)]))
     rd [(ends 0) (ends 1) r c fz]
     (rr 0.0 1.0 < 0.6 ? (rd . fork (ends 0) (ends 1) r c fz 1) [rd]))
   ; ..each twig lies flat a little way out from the heap: two rows of points
   (stick i) (: a (i * tau / stick-n + rr -0.3 0.3) rad (rr 0.9 1.4)
                cx (clamp (bs 0 + rad * cos a) (0.3 - yard-a) (yard-a - 0.3))
                cz (clamp (bs 2 + rad * sin a) (0.3 - yard-b) (yard-b - 0.3))
                yaw (rr 0.0 tau) ln (rr 0.15 0.35) k (int (ln / 0.008))
                cy (cos yaw) sy (sin yaw) th (rr 0.012 0.02)
                c (c* (rr 0.75 1.15) (rr 0.0 1.0 < 0.3 ? [0.42 0.38 0.33] [0.34 0.24 0.15]))
                ; ..three strands wide and three high, the top one the lightest
                (catmap (j \ (: u (((j + 0.5) / k - 0.5) * ln)
                              (catmap (v \ (map (m \ [(cx + u * cy - v * sy) (0.01 + m * th) (cz + u * sy + v * cy)
                                                               ((0.8 + 0.12 * m) * c 0) ((0.8 + 0.12 * m) * c 1) ((0.8 + 0.12 * m) * c 2) 1.0])
                                                         ^3))
                                      [-th 0.0 th]))) ^k))
   ; ..each leaf under one of the crown's, blown a little way off, kept off the walls
   (leaf _) (: i (pick 40 0) x (clamp (X i + rr -0.4 0.4) (0.08 - yard-a) (yard-a - 0.08))
               z (clamp (Z i + rr -0.4 0.4) (0.08 - yard-b) (yard-b - 0.08))
               ang (rr 0.0 tau) c (c* (rr 0.8 1.1) (hues (int (rr 0.0 3.99))))
               (lying x z ang c))
   hi (filter (i \ K i = 2.0 && top - 1.5 < Y i) ^n)
   tops (two? hi ? (map (q \ hi (int (rr 0.0 (#hi - 0.5))) @ i [(X i) (Y i) (Z i)]) ^120) ())
   ; ..the big branch propping the crate, and the heap kept out of the crate and off the plate
   cr (crate-of bs) cc (cr 0) ch (cr 3) pl (plate-of bs)
   lain (: r 0.09 z (cc 2 + ch 2 + r + 0.005)
          [[[(cc 0 - 1.3) r z] [(cc 0 + 0.6) r z] r (bark 0) 0.25]])
   (clear? rd) (all (f \ (: q (lerp (rd 0) (rd 1) f) m (rd 2)
                         (!(mag (q 0 - cc 0) < ch 0 + m && mag (q 2 - cc 2) < ch 2 + m && q 1 < 2.0 * ch 1 + m)
                          && plate-r + 0.12 + m < sqrt (sq (q 0 - pl 0) + sq (q 2 - pl 2)))))
                    (map (k \ k / 10.0) ^11))
   rods (filter clear? (catmap branch ^heap-n)) pts (bits (catmap stick ^stick-n))
   {'pts pts 'rods rods 'lain lain 'leaves (bits (catmap leaf ^leaf-n)) 'tops tops})
 ; the first k of the leaves on the ground, browned by bw
 (lead P k bw) (k < 1 ? () (: ix (iota k) (g q) (peep (P q) ix 0.0) dead [0.3 0.22 0.13]
   {'x (g 'x) 'y (g 'y) 'z (g 'z) 'up (g 'up)
    'r (g 'r + bw * (dead 0 - g 'r)) 'g (g 'g + bw * (dead 1 - g 'g)) 'b (g 'b + bw * (dead 2 - g 'b))}))
 ; points as trays, as dots draws them
 (bits l) (: m #l (col k) (gem-tray [m] (map (q \ 1.0 * q k) l))
             {'x (col 0) 'y (col 1) 'z (col 2) 'r (col 3) 'g (col 4) 'b (col 5) 'up (col 6)})
 ; a falling leaf, [x y z ph hue]: down at its own pace, swung side to side as it goes, and
 ; kept inside the walls; it lands at the floor
 (fall-step q t) (: x (q 0) y (q 1) z (q 2) ph (q 3) w (1.0 * t * 0.11 + ph)
   [(clamp (x + 0.3 * sin w / fps) (0.08 - yard-a) (yard-a - 0.08)) (max leaf-y (y - fall-v / fps))
    (clamp (z + 0.3 * cos (w * 0.7) / fps) (0.08 - yard-b) (yard-b - 0.08)) ph (q 4)])
 ; the leaves loose on the scene as points: those falling, turning as they go, and those landed
 (loose st) (: t (st 't)
   (falling q) (: a (q 3 + 1.0 * t * 0.3) c (hues (q 4))
                  (map (j \ [(q 0 + (j - 1.5) * 0.012 * cos a) (q 1 + (j - 1.5) * 0.006 * sin (a * 1.3))
                              (q 2 + (j - 1.5) * 0.012 * sin a) (c 0) (c 1) (c 2) 0.0]) ^4))
   (landed q) (lying (q 0) (q 2) (q 3) (hues (q 4)))
   l (catmap falling (st 'fall) + catmap landed (st 'fallen))
   (two? l ? (bits l) ()))
 ; ..the loose ones from the parapet's top down, swaying the more the lower they hang as the
 ; frame's clock t goes: [a b r colour bark wall]
 (strands t) (: (sway k p) (: f (sq (sat ((wall-h - p 1) / 5.0)))
                             [(p 0 + f * 0.03 * sin (t * 0.05 + k)) (p 1) (p 2 + f * 0.03 * cos (t * 0.04 + k * 1.3))])
   (hang wid ps r k) (: n #ps q (map (sway k * ps) ^n)
                        (map (i \ [(q i) (q (i + 1)) r [0.05 0.05 0.055] 0.0 wid]) ^(n - 1)))
   ea (yard-a - 0.04) wa (0.04 - yard-a) nb (yard-b - 0.04) sb (0.04 - yard-b)
   (cats [(hang 2 [[-2.2 wall-h nb] [-2.2 9.4 (nb + 0.01)] [-2.14 7.6 (nb - 0.12)]] 0.009 1.0)
          (hang 0 [[ea wall-h -3.45] [(ea + 0.01) 8.2 -3.45] [(ea - 0.16) 5.9 -3.38]] 0.01 2.0)
          (hang 1 [[wa wall-h 1.6] [(wa - 0.01) 10.6 1.62] [(wa + 0.11) 9.3 1.7]] 0.008 3.0)
          (hang 3 [[2.45 wall-h sb] [2.45 6.0 (sb - 0.01)] [2.52 2.7 (sb + 0.16)]] 0.011 4.0)
          (hang 0 [[ea wall-h 0.3] [(ea - 0.02) 11.95 0.75] [(ea - 0.03) 11.8 1.25] [(ea - 0.02) 11.95 1.7] [ea wall-h 2.1]] 0.009 5.0)
          (hang 1 [[wa wall-h -4.1] [(wa - 0.02) 10.9 -4.12] [(wa + 0.16) 10.1 -4.0]] 0.008 6.0)]))
 ; which wall's face a step of a run is on, and where along it
 (wall-of p q) (: (on? k v) (mag (p k - v) < 0.01 && mag (q k - v) < 0.01)
   (? (on? 0 yard-a) 0 (on? 0 -yard-a) 1 (on? 2 yard-b) 2 3))
 (along-of wid p) (wid < 2 ? (p 2) (p 0))
 ; ..the map's texel on wall wid at u along it and v up it
 (wall-texel wid u v) (wall-offs wid + floor (v / ts) * wall-nus wid
                       + floor ((u + (wid < 2 ? yard-b yard-a)) / ts))
 ; ..a step laid into the wall's map: the texels of its box, each the share of it the run
 ; covers, its strands striped and its upper side lit, the wall under it a little shadowed
 (lay-step m wid u0 u1 v0 v1 wd c) (: nu (wall-nus wid) half (wid < 2 ? yard-b yard-a)
   flat (mag (v1 - v0) < 0.001) pad (wd + 0.08)
   tu0 (max 0 (int ((min u0 u1 - pad + half) / ts))) tu1 (min (nu - 1) (int ((max u0 u1 + pad + half) / ts)))
   tv0 (max 0 (int ((min v0 v1 - pad) / ts))) tv1 (min (nv - 1) (int ((max v0 v1 + pad) / ts)))
   bw (tu1 - tu0 + 1) bh (tv1 - tv0 + 1)
   ii (iota (bw * bh)) tu (tu0 + ii % bw) tv (tv0 + ii // bw)
   uc ((tu + 0.5) * ts - half) vc ((tv + 0.5) * ts) ix (wall-texel wid uc vc)
   ac (flat ? (vc - v0) (uc - u0)) w2 (0.5 * wd)
   at (flat ? uc vc) lo (flat ? (min u0 u1) (min v0 v1)) hi (flat ? (max u0 u1) (max v0 v1))
   (ov x l h) (sat ((min (x + 0.5 * ts) h - max (x - 0.5 * ts) l) / ts))
   long (ov at (lo - w2) (hi + w2))
   cov (ov ac -w2 w2 * long)
   shd ((ov ac (-w2 - 0.04) (flat ? w2 (w2 + 0.04)) * long - cov) * 0.15)
   x (ac / max w2 0.001) k (max 1 (int (wd / 0.012)))
   strand (0.9 + 0.2 * throw (floor ((x + 1.0) * 0.5 * k)) (int (mag lo * 100.0)) 91 9 / 9.0)
   tie ((frac (at / 0.3) < 0.13) * (0.05 < wd))
   tone ((flat ? (1.0 + 0.25 * x) (1.1 - 0.2 * mag x)) * strand * (1.0 + 0.3 * tie))
   (lay key ck) (peep (m key) ix 0.0 @ o (pin m key (pin (m key) ix (o * (1.0 - shd) + cov * (tone * ck - o * (1.0 - shd))))))
   _ (lay 'r (c 0)) _ (lay 'g (c 1)) _ (lay 'b (c 2))
   (pin m 'glass (pin (m 'glass) (over -1 (0.5 < cov) ix) 0)))
 (lay-run m rn) (: wd (rn 0) c (rn 1) ps (rn 2) n #ps
   _ (each ^(n - 1) (i \ (: p (ps i) q (ps (i + 1)) wid (wall-of p q)
                           (lay-step m wid (along-of wid p) (along-of wid q) (p 1) (q 1) wd c)))))
 ; --- the scene in triangles: walls and floor laid once a process, what stands and the litter
 ; once a run, all relit every two sky minutes; panes, leaves, swaying cables and weather every frame ---
 ; texels w by h, an index tray of that shape counting along each row
 (grid h w) ((star-tray [h w] 0) + iota w + star-tray [h 1] (map (i \ i * w) ^h))
 (q v) (int (sat v * 255.0 + 0.5))
 (word c) ((q (c 0) << 16) | (q (c 1) << 8) | q (c 2))
 ; the walls' textures, east, west, north, south: the glass black, a pane laid over it
 ; each frame
 (wall-texs mp) (: m (mp 'wall)
   (map (wid \ (: ix (wall-offs wid + grid nv (wall-nus wid))
                  (word [(peep (m 'r) ix 0.0) (peep (m 'g) ix 0.0) (peep (m 'b) ix 0.0)] * (1 - peep (m 'glass) ix 0))))
        ^4))
 ; ..and the floor's, darker wet and white under snow
 (floor-tex mp wet snow) (: m (mp 'floor) ix (grid fl-nz fl-nx)
   fc [(peep (m 'r) ix 0.0) (peep (m 'g) ix 0.0) (peep (m 'b) ix 0.0)] lum ((fc 0 + fc 1 + fc 2) / 3.0)
   spk (frac (sin (ix * 12.9898) * 43758.5453))
   sw (sat (snow * 1.3 - 0.6 * (0.5 - lum) - 0.15 * spk))
   (word (cmix (c* (1.0 - 0.35 * wet) fc) snowc sw)))
 ; ..the four walls', the floor's (laid again when wet or snow moves a twentieth) and the bark's
 (court-texs st) (: mp (court-maps ())
   wt (maps 'wtex @ () (: t (wall-texs mp) (pin maps 'wtex t, t)) t t)
   k [(int (st 'wet * 20.0)) (int (st 'snow * 20.0))]
   ft (maps 'ftex @ [k0 t] (k0 = k ? t ()) _ ())
   bk (maps 'bark @ () (: t (grove-bark ()) (pin maps 'bark t, t)) t t)
   (cat wt [(tray? ft ? ft (: t (floor-tex mp (st 'wet) (st 'snow)) (pin maps 'ftex [k t], t))) bk]))
 ; --- the walls and the floor: a place on wall wid's face, al along it and y up it, and
 ; the way it faces, into the yard ---
 (at wid al y) (wid @ 0 [yard-a y al] 1 [-yard-a y al] 2 [al y yard-b] [al y -yard-b])
 ins [[-1.0 0.0 0.0] [1.0 0.0 0.0] [0.0 0.0 -1.0] [0.0 0.0 1.0]]
 (half-of wid) (wid < 2 ? yard-b yard-a)
 white [1.0 1.0 1.0]
 ; a quad, its corners going round, its front toward n
 (face ps uvs tex n) (: m (mesh-quad ps uvs tex white)
   (dot (take 3 (drop 5 (m 0 0))) n < 0.0 ? (mesh-quad (rev ps) (rev uvs) tex white) m))
 ; ..a stretch of a wall's face, a0 to a1 along it and y0 to y1 up it
 (panel wid a0 a1 y0 y1) (: h (half-of wid) (uv al y) [((al + h) / ts) (y / ts)]
   (face [(at wid a0 y0) (at wid a1 y0) (at wid a1 y1) (at wid a0 y1)]
         [(uv a0 y0) (uv a1 y0) (uv a1 y1) (uv a0 y1)] wid (ins wid)))
 ; ..and a block's end, at al and d deep, facing n: its texels going on round from the face,
 ; sa the way along it they go
 (end-face wid al sa d y0 y1 n) (: h (half-of wid) bk (c* -1.0 (ins wid))
   (back y k) (c+ (at wid al y) (c* k bk)) (uv k y) [((al + sa * k + h) / ts) (y / ts)]
   (face [(back y0 0.0) (back y0 d) (back y1 d) (back y1 0.0)] [(uv 0.0 y0) (uv d y0) (uv d y1) (uv 0.0 y1)] wid n))
 ; the four walls to the parapet, the battlements over the short walls and the roof's
 ; block at the east wall's north end, and the floor
 (shell _) (: a yard-a b yard-b fx (2.0 * a / fts) fz (2.0 * b / fts)
   (bat bt) (: w (bt 0) c (bt 1) h (bt 2)
              [(panel w (c - h) (c + h) wall-h top-h)
               (end-face w (c + h) 1.0 wall-t wall-h top-h [1.0 0.0 0.0]) (end-face w (c - h) -1.0 wall-t wall-h top-h [-1.0 0.0 0.0])])
   (mesh-pack (mesh-join (cat (catmap bat bats)
     [(panel 0 -b b 0.0 wall-h) (panel 1 -b b 0.0 wall-h)
      (panel 2 -a a 0.0 wall-h) (panel 3 -a a 0.0 wall-h)
      (panel 0 (b - cw) b wall-h top-h) (end-face 0 (b - cw) -1.0 cw wall-h top-h [0.0 0.0 -1.0])
      (face [[-a 0.0 -b] [a 0.0 -b] [a 0.0 b] [-a 0.0 b]]
            [[0.0 0.0] [fx 0.0] [fx fz] [0.0 fz]] 4 [0.0 1.0 0.0])]))))
 ; ..lit: the sun, the sky by how much of it a place sees -- the more the higher up a wall,
 ; and the side toward the sun more by day -- and a little back off the walls the sun is on
 (shell-light lt) (: s (lt 'sun)
   (c \ (: fl (0.5 < c 6)
           sv ((over (0.45 + 0.5 * min 1.0 (c 1 / wall-h)) fl 0.42) * (1.0 + 0.2 * lt 'day * (c 5 * s 0 + c 7 * s 2)))
           [0.9 sv (c* (lt 'sunk * 0.05) (lt 'sunc))])))
 ; --- what stands in the yard, laid once a run and kept with its tree: branches, cables and
 ; boxes, air conditioners, copings, the crate, the plate and the tree's wood ---
 (props st) (: tr (st 'tree) (tr 'props @ () (:
   (step wd c p q) (: o (c* (0.5 * wd) (ins (wall-of p q))) (mesh-rod (c+ p o) (c+ q o) (0.5 * wd) c 5 -1 1.0))
   (run rn) (: ps (rn 2) (map (i \ step (rn 0) (rn 1) (ps i) (ps (i + 1))) ^(#ps - 1)))
   (cap bt) (: z (bt 0 @ 2 1.0 -1.0)
              (mesh-box [(bt 1) (top-h + 0.05) (z * (yard-b + 0.5 * wall-t))] [(bt 2 + lip) 0.05 (0.5 * wall-t + lip)] 0.0 -1 [0.7 0.68 0.63] 1.0))
   (box bx) (mesh-box (c* 0.5 (c+ (bx 0) (bx 1))) (c* 0.5 (c+ (bx 1) (c* -1.0 (bx 0)))) 0.0 -1 [0.47 0.48 0.44] 1.0)
   ; ..the crate: rims round its open face and its back, posts at the corners, and slats
   ; across its five closed sides
   (crate bs) (: cr (crate-of bs) h (cr 1) hx (h 0) hy (h 1) hz (h 2) t 0.012 X (hx - t) Y (hy - t) Z (hz - t)
     (bar p q) (mesh-box (c* 0.5 (c+ p q)) (map (k \ 0.5 * mag (q k - p k) + t) ^3) 0.0 -1 [0.05 0.05 0.055] 1.0)
     (rim z) [(bar [-X Y z] [X Y z]) (bar [-X -Y z] [X -Y z])
              (bar [-X -Y z] [-X Y z]) (bar [X -Y z] [X Y z])]
     posts (catmap (x \ map (y \ bar [x y -Z] [x y Z]) [-Y Y]) [-X X])
     back (map (x \ bar [x -Y -Z] [x Y -Z]) [(-0.5 * X) 0.0 (0.5 * X)]
           + [(bar [-X 0.0 -Z] [X 0.0 -Z])])
     lids (catmap (y \ map (x \ bar [x y -Z] [x y Z]) [(-0.5 * X) 0.0 (0.5 * X)] + [(bar [-X y 0.0] [X y 0.0])]) [-Y Y])
     ends (catmap (x \ [(bar [x 0.0 -Z] [x 0.0 Z]) (bar [x -Y 0.0] [x Y 0.0])]) [-X X])
     ; ..tipped back about its long side, the open side turning up
     c (cos (cr 2)) s (sin (cr 2)) (rot y z) [(y * c + z * s) (z * c - y * s)]
     m (mesh-join (cats [(rim Z) (rim -Z) posts back lids ends]))
     (mesh-move (mesh (map (v \ (: p (rot (v 1) (v 2)) n (rot (v 6) (v 7))
                                 [(v 0) (p 0) (p 1) (v 3) (v 4) (v 5) (n 0) (n 1) (v 8) (v 9) (v 10)])) (m 0)) (m 1))
                (cr 0) 0.0))
   ; ..the plate: a flat ring with a raised rim, its hole for a bar
   (plate bs) (mesh-move (mesh-lathe [[0.026 0.0] [plate-r 0.0] [plate-r 0.028] [0.13 0.032] [0.04 0.022] [0.026 0.026] [0.026 0.0]]
                                     24 -1 [0.72 0.73 0.75] 1.0)
                         (plate-of bs) 0.0)
   (ac w) (: wid (w 0) hw (w 2) d (wid < 2 ? [0.2 0.19 (hw - 0.04)] [(hw - 0.04) 0.19 0.2])
            (mesh-box (c+ (at wid (w 1) (w 3 + 0.21)) (c* 0.12 (ins wid))) d 0.0 -1 [0.62 0.62 0.6] 1.0))
   p {'rods (mesh-pack (mesh-join (cats [(map (rd \ mesh-rod (rd 0) (rd 1) (rd 2) (c* 1.15 (rd 3)) 6 5 0.01) (st 'litter 'lain + st 'litter 'rods))
                                         (catmap run runs) [(grove-wood tr 5)]])))
      'boxes (mesh-pack (mesh-join (cats [(map box boxes) (map ac (filter cooled? windows)) (map cap bats) [(crate (tr 'base)) (plate (tr 'base))]])))}
   (pin tr 'props p, p)) p p))
 ; ..a packed mesh under snow: its colours toward the snow's by w, a tray of its vertices
 (snowed pk w) (: c (pk 'cols) (mix k) (c (8 + k) + w * (snowc k - c (8 + k)))
   {'n (pk 'n) 'tris (pk 'tris) 'cols (take 8 c + [(mix 0) (mix 1) (mix 2)])})
 ; --- points as little triangles for facets: P the trays bits makes, lying flat where 'up,
 ; else standing; white under snow sn where they lie ---
 (dots P lt sn sz) (: s (lt 'sun) X (P 'x) Y (P 'y) Z (P 'z) up (P 'up)
   base (cmix [(P 'r) (P 'g) (P 'b)] snowc (up * sn))
   face (up * max (s 1) 0.0 + (1.0 - up) * 0.5)
   (corner k) [(X + sz * cos (2.1 * k)) (Y + (1.0 - up) * sz * sin (2.1 * k)) (Z + up * sz * sin (2.1 * k))]
   (mesh-dots [(corner 0) (corner 1) (corner 2)] (cm base (c* 0.42 (lt 'amb))) (cm base (c* (0.9 * face * lt 'sunk) (lt 'sunc))) -1))
 ; --- the scene lit, kept with the tree until two sky minutes pass or the snow or season
 ; moves: [verts tris] lists, and the sun's view [view depths bias], () while it is down ---
 sun-n 1024 sun-half 10.0 sun-deep 30.0 sun-bias 0.06
 (scene st lt) (: was (st 'tree 'scene) sim (st 'sim) sea (court-season st) sn (st 'snow)
   key [(int (sn * 20.0)) (int (sea 'ground * 50.0)) (int (sea 'share * 50.0)) (int (sea 'turn * 50.0)) (int (sea 'seeds * 50.0))]
   (tablet? was && mag (sim - was 'at) < 120.0 && was 'key = key ? was
      (: P (props st) sh (court-shell ())
         (ny pk) (pk 'cols 6)
         wl (mesh-bake-sun sh lt (shell-light lt) 1.0)
         rd (mesh-bake-sun (snowed (P 'rods) (sn * sat (ny (P 'rods) * 2.0 - 0.8))) lt (c \ [1.0 0.9 ()]) 1.0)
         bx (mesh-bake-sun (snowed (P 'boxes) (sn * (0.0 < ny (P 'boxes)))) lt (c \ [0.9 0.75 ()]) 1.0)
         lv (lead (st 'litter 'leaves) (18 * int (leaf-n * sea 'ground)) (sea 'brown))
         gd [(dots (st 'litter 'pts) lt sn 0.008) (tablet? lv ? (dots lv lt sn 0.012) ())]
         gd2 (filter two? gd)
         tr (tree-of st sea) td (grove-dots tr lt [(st 'px) eye-h (st 'pz)] (st 't) 0.001)
         stand [[(wl 0) (rd 0) (bx 0) (td 0)] [(wl 1) (rd 1) (bx 1) (td 1)]]
         sv (mesh-sun-view lt [0.0 7.0 0.0] sun-half sun-deep)
         sun (0.0 < lt 'sunk * lt 'sun 1 ? [sv (mesh-sun-map sv stand sun-n) (sun-bias / sun-deep)] ())
         s2 {'at sim 'key key 'sun sun
             'sc [(cat [(wl 0) (rd 0) (bx 0)] (map (b \ b 0) gd2)) (cat [(wl 1) (rd 1) (bx 1)] (map (b \ b 1) gd2))]}
         (pin (st 'tree) 'scene s2, s2))))
 ; the walls and the floor, packed once a process
 (court-shell _) (maps 'shell @ () (: m (shell ()) (pin maps 'shell m, m)) m m)
 ; the tree in its season
 (tree-of st sea) (pins (st 'tree) 'share (sea 'share) 'turn (sea 'turn) 'seeds (sea 'seeds) 'ripe (sea 'ripe))
 ; ..each window's glass in six panes a hair off the wall, as trays: each corner's place, its
 ; window, whether behind a curtain, and how much sky it gives back
 (court-panes _) (maps 'panes @ ()
   (: (pieces wn) (: w (windows wn) wid (w 0) c (w 1) hw (w 2) y0 (w 3) vh (w 4) o (c* 0.02 (ins wid))
        xs [(-hw + 0.05) (-0.45 * hw) (0.45 * hw) (hw - 0.05)] ys [0.07 (0.5 * vh - 0.03) (0.5 * vh + 0.03) (vh - 0.06)]
        ar (? (w 6 = 0 || w 6 = 2) rise 0.0)
        (pc i j) (: a0 (c + xs i) a1 (c + xs (i + 1)) b0 (y0 + ys (2 * j)) b1 (y0 + ys (2 * j + 1))
                    (top x) (b1 + j * ar * sat (1.0 - sq ((x - c) / hw)))
                    [(map (p \ c+ p o) [(at wid a0 b0) (at wid a1 b0) (at wid a1 (top a1)) (at wid a0 (top a0))]) wn (i != 1)
                     (0.25 + 0.2 * j + 0.04 * throw (w 5) (3 * j + i) 37 5 + 0.15 * (j = 0 && throw (w 5) 5 41 4 = 0))])
        (catmap (j \ map (i \ pc i j) ^3) ^2))
      ps (catmap pieces ^#windows) n #ps
      (col f) (gem-tray [(4 * n)] (catmap (p \ map (k \ 1.0 * f p k) ^4) ps))
      t {'x (col (\ p k (p 0 k 0))) 'y (col (\ p k (p 0 k 1))) 'z (col (\ p k (p 0 k 2)))
         'wn (star-tray [(4 * n)] (catmap (p \ [(p 1) (p 1) (p 1) (p 1)]) ps))
         'sd (gem-tray [(4 * n)] (catmap (p \ (: s (1.0 * p 2) [s s s s])) ps))
         'rf (gem-tray [(4 * n)] (catmap (p \ [(p 3) (p 3) (p 3) (p 3)]) ps))
         'tris (star-tray [(8 * n)] (catmap (i \ (: v (4 * i) [v (v + 1) (v + 2) -2 v (v + 2) (v + 3) -2])) ^n))}
      (pin maps 'panes t, t)) t t)
 ; ..and each frame's light in them: the sky in the glass, the room behind when lit by the
 ; hour; the lobby, stair and ground floor halls whenever it is dark out
 (panes-batch st lt) (: t0 (st 't) P (court-panes ()) ws windows
   (w k) (gem-tray [#ws] (map (x \ 1.0 * x k) ws)) wid (w 0) c (w 1) y0 (w 3) kd (w 6) K (int (w 5))
   fl (floor (y0 / floor-h))
   lob ((kd = 0.0) * (wid = 1.0) * (fl = 0.0)) hall ((kd = 2.0) * (fl = 0.0) * (c < 0.0)) stw (kd = 3.0)
   nt (stw + lob + hall) bw ((kd = 1.0) * (wid = 1.0))
   tv ((throw K 0 13 9 = 0) * (1 - nt) * (1 - bw))
   cur ((throw K 1 19 3 = 0) * (1 - lob))
   lamp (0.55 + 0.45 * (throw K 2 23 10 / 10.0))
   hr (day-secs (st 'sim) / 3600.0)
   on (frac (sin (K * 12.9898 + int hr * 78.233) * 43758.5453) * 100.0 < lit-share hr)
   lamps (over ((1 - nt) * on * 0.7 * flicker-tv t0 K tv) nt ((lt 'day < 0.55) * 0.75))
   (em g) (room-em g tv bw (stw + hall) lob)
   panes (c+ (c* 0.5 (lt 'amb)) [0.02 0.025 0.03])
   mid (c* lamps (em lamp)) out (c* lamps (em (lamp * (1.0 - 0.6 * cur))))
   wn (P 'wn) sd (P 'sd) rf (P 'rf)
   (ch k) (rf * panes k + peep (mid k) wn 0.0 + sd * (peep (out k) wn 0.0 - peep (mid k) wn 0.0))
   [(lace [(P 'x) (P 'y) (P 'z) 0.0 0.0 (ch 0) (ch 1) (ch 2) 0.0 0.0 0.0]) (P 'tris)])
 ; --- what moves each frame: the loose cables, the leaves falling and fallen, and the
 ; rain or the snow, a glow over what is there where it is nearer ---
 (strand-batch t0 lt) (mesh-bake-sun (mesh-pack (mesh-join (map (rd \ mesh-rod (rd 0) (rd 1) (rd 2) (rd 3) 5 -1 1.0) (strands t0))))
                                     lt (c \ [1.0 0.9 ()]) 1.0)
 (loose-batch st lt) (loose st @ P (tablet? P ? (dots P lt (st 'snow) 0.012) ()))
 (drops-batch st lt e) (: d (sky-drops (st 'wx) lt e (1.0 * st 't / fps))
   (tablet? d ?
    (: X (d 'x) Y (d 'y) Z (d 'z) hw (0.5 * d 'wd) th (st 'th) rx (cos th * hw) rz (-(sin th) * hw) L (d 'len)
       (mesh-dots [[(X - rx) Y (Z - rz)] [(X + rx) Y (Z + rz)] [X (Y + L) Z]] (c* (d 'a) (d 'c)) [0.0 0.0 0.0] -2))
    ()))
 ; --- the stars: sky's at the hour, each one pixel where the eye sees it through the top ---
 (stars st) (sky-stars (st 'sim) (st 'dst) lat)
 ; --- the frame ---
 ; the percent of windows lit by the hour
 (lit-share hr) (? (hr < 5.0) 6 (hr < 6.5) 12 (hr < 9.0) 35 (hr < 16.0) 4 (hr < 18.0) 25 (hr < 23.0) 60 25)
 fov (pi / 2.0)
 sky-k 2                                  ; the sky asked every sky-k columns of kitty's pixels
 ; the walls, the floor and what is in the yard, the sky where they leave the screen bare,
 ; through the eye's gain: a flat tray of colours, 'kp pixels a column and twice that a row
 (court-pens st) (: lt (court-light st) k (peep st 'kp 1) dm (mesh-dims st) w <dm h (dm 1) t0 (st 't)
   e [(st 'px) eye-h (st 'pz)] fv (peep st 'fov fov)
   v (mesh-eye w h e (st 'th) (st 'ph) 0.0 fv 0.05 100.0)
   sc0 (scene st lt) sea (court-season st)
   tr (tree-of st sea) td (grove-dots tr lt e t0 (fv / w)) tw (grove-twigs tr lt e (fv / w))
   xs (filter two? [td tw (strand-batch t0 lt) (loose-batch st lt) (panes-batch st lt)])
   dr (drops-batch st lt e)
   bs (cat xs (two? dr ? [dr] ()))
   vs (cat (sc0 'sc 0) (map (b \ b 0) bs)) ts (cat (sc0 'sc 1) (map (b \ b 1) bs))
   (mesh-frame v [vs ts (sc0 'sun)] (court-texs st) [0.0 0.0 0.0 0.0 0.0] 0 (1.5 * lt 'expo)
               (mesh-sky (stars st) lt (st 'wx) e (st 'sim) t0 (k @ 1 1 (sky-k * k)) (mesh-sky-memo st))))
 ; the frame: the clock in the corner for a while after the time is touched -- in the
 ; cells, or over kitty's picture, and its row blanked once after
 (court-frame st) (: w (st 'w) deep (st 'deep) kit (st 'kitty) f (court-pens st)
   pace (st 'paces (st 'pace)) wx (st 'wx)
   txt (" " + court-clock st + (pace @ 0.0 "  still" 1.0 "" ("  x" + (show $ int pace = pace ? (int pace) pace)))
        + "  " + sky-says (wx 'cover) + (sky-fall wx @ 1 ", rain" 2 ", snow" "") + " ")
   up (st 't < st 'shown)
   bands (up ? {0 [1 txt (deep ? 249660 255) (deep ? 33288 235)]} {})
   text (? !kit "" up (esc + "[1;1H" + esc + "[0m" + txt) (st 't = st 'shown) (esc + "[1;1H" + esc + "[0m" + pad "" w " ") "")
   (mesh-show st f text bands))
 ; --- the walk, on view's loop; court-run raises the stage. o says how to start, or ():
 ; 'now [local-seconds dst], 'wx the weather, 'pace sky seconds a second ---
 (court-walk o) (: (opt k) (tablet? o ? (o k) ())
   (view-walk {'new (w \ h \ (: st (court-size (pins (court-new w h (opt 'now @ n (n ? n (court-now ()))))
                                                    'deep (opt 'md = 'window || view-deep? ()) 'kitty (mesh-mode (opt 'md))
                                                    'win (opt 'win) 'scale (opt 'scale))
                                              w (h // 2))
                                  wx (opt 'wx) p (opt 'pace)
                                  _ (wx ? (pins st 'wx wx 'drift (opt 'fix ? 0 1)))
                                  (charm? p ? (pins st 'paces (p . paces) 'pace 0) st)))
               'size court-size 'frame court-frame 'key court-step 'tick court-move
               'binds (view-bind view-binds court-binds)
               'listed (view-listed ['hour-back 'hour-on 'pace 'clouds 'fall 'finer 'coarser])
               'fps fps 'song (hn \ ()) 'linger 0 'next () 'win (opt 'win)}))
 ; ..and kitty's picture taken down after, where it was put up
 (court-run o) (view-stage o court-walk (_ \ (say out mesh-gone, flush out)))
 court-usage "usage: love play court [--date YYYY-MM-DD] [--time HH:MM] [--pace N] [--weather clear|partly|mostly|overcast] [--fall none|rain|snow] [--kitty|--cells|--window] [--scale 1|2|4|8]   (the weather words, rain and snow may stand alone; h l turn, k j step, u n look, [ ] an hour, t the pace, c the cloud, p rain or snow; ? the keys; q or esc leaves)"
 ; --- the words -> the walk's start, or () for words it cannot read; a date or a time
 ; alone keeps the other from now ---
 (court-opts as) (: (ix l w) (: (go i) (i < #l ? (l i = name w ? i (go (i + 1))) ()) (go 0))
   (cov w) (ix sky-covers w) (fal w) (ix sky-falls w)
   (dnum w) (: n #w (go i v) (i < n ? (48 <= w i <= 57 ? (go (i + 1) (v * 10 + w i - 48)) ()) v)
               (0 < n ? (go 0 0) ()))
   (date w) (w @ (y + "-" + m + "-" + d)
                 (: a (dnum y) b (dnum m) c (dnum d)
                    (charm? a && charm? b && charm? c && 0 < b <= 12 && 0 < c <= 31 ? [a b c]))
                 _ ())
   (hm w) (w @ (h + ":" + m) (: a (dnum h) b (dnum m) (charm? a && charm? b && a < 24 && b < 60 ? (3600 * a + 60 * b)))
               _ ())
   (pnum w) (: cs (chars w) (0 < #w && all (c \ (48 <= c <= 57) || c = 46) cs && #(filter (= 46) cs) < 2
                             && 48 <= w 0 <= 57 ? (1.0 * <(sound w))))
   ; ..rain and snow and a cover, each also a word alone
   (bare k read ok) (l \ ok <l ? [k (read <l) >l])
   r (view-words as [(view-arg "--date" 'date date) (view-arg "--time" 'time hm) (view-arg "--pace" 'pace pnum)
                     (view-arg "--weather" 'cov cov) (view-arg "--fall" 'fall fal)
                     (bare 'fall fal (w \ w = "rain" || w = "snow")) (bare 'cov cov (charm? * cov))
                     (view-flag "--kitty" 'md 'kitty) (view-flag "--cells" 'md 'cells)
                     (view-flag "--window" 'md 'window) view-scale])
   (tablet? r ?
      (: now0 (court-now ()) l0 (int (now0 0)) d (r 'date) t (r 'time)
         now (d = () && t = () ? now0
              (court-local (86400 * (d @ () (l0 // 86400) ((cite 'cal 'epoch-days) (d 0) (d 1) (d 2)))
                            + (t @ () (l0 % 86400) t))))
         c (r 'cov) fl (r 'fall) l (now 0) sd (int l) m (court-month l)
         ; ..what is not said is the season's: a fall said without a cover comes from overcast
         c2 (? (c != ()) c (0 < fl) 3 (court-wx-pick m (throw sd 7 71 20)))
         {'now now 'pace (r 'pace) 'fix (c = () && fl = () ? 0 1) 'md (r 'md) 'scale (r 'scale)
          'wx (c = () && fl = () ? ()
                 (wx-of c2 (fl @ () (court-fall-pick m c2 (throw sd 9 73 20) (throw sd 11 79 2)) fl)))})))
 (court-main as) (view-main "court" court-usage court-opts court-run as)
 _ ((cite 'lore 'lore-enlist) 'court (udoor 'court court-main court-usage 1 1)))
) ; module court
