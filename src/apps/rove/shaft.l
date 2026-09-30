; shaft -- an elevator shaft in half blocks, first person, climbed: the level after the
; garage. the shaft is square, its walls iron plate, and a ledge of rust runs
; round it at every floor, with stretches missing that have to be jumped; a ladder from
; each floor to the next stands against a wall. on every floor the two walls that face
; each other across the shaft from the door wall carry a small red light, and the lights
; blink slowly together as a mast's do, with a halo on the plates around each when it
; is on; the door wall carries a lift door, shut -- all but the top one, which opens when
; the player stands at it, and that ends the level. the player walks the floor and the
; ledges as they like, jumps with the space bar and comes down under gravity; off a
; ledge's edge they fall to whatever is under them, the floor at worst, and are not
; hurt, but the screen flashes red, the harder the landing the more opaque and the
; slower it fades.
;
; the screen is the terminal, two pixels to a cell: the upper half block, the top pixel
; in the pen and the bottom in the ground; the view is ninety degrees wide whatever the
; width. the walls, floor, lights, doors and ladders are a row at a time in trays: a
; row's rays end on one of four planes, and what is painted is a function of where.
; the ledges are laid over that a column at a time: each ledge a ray passes projects to
; a few spans of rows -- its face, its top or its underside -- nearest first, and the
; walls are always behind them. the red flash and the lights' halos are one thing: the
; palette pulled toward red in four steps, each a tray a pen indexes, made once.
;
; the scene is pure love -- shaft-new, shaft-step, shaft-move and shaft-frame are state in
; and state out, and the song feeds any port -- gated headless by test/host/shaft.l;
; only shaft-walk and shaft-run tie the tty and the horn. shaft-walk takes a stage
; already raised, which is how the garage hands over on the same screen.
;
; run: love shaft   h l or the arrows turn, k or up steps forward, j or down back -- a
;                   held key repeats, which is a walk; space jumps, or at a ladder takes
;                   hold of it, and then k and j climb it and space lets go; u n look up
;                   and down; q or esc leaves.
;                   HORN=none plays silent on a seat with no sound device
(module (shaft shaft-run shaft-walk shaft-main shaft-new shaft-size shaft-lay shaft-step shaft-move
         shaft-jump shaft-land shaft-frame shaft-song-new shaft-song-feed shaft-sfx blink
         ledge? ledge-under? ground-at land-at ladder-at ring-pt wall-of wall-s wall-q wrap-s s-apart
         tangent-of near-wall
         fps floors floor-h shaft-r perim ledge-d ledge-t walk-q eye-h body-r grav jump-v walk-v climb-v
         climb-h coyote ladders ladder-w hatches hatch-w door-s door-w door-h light-h light-period light-on
         light-drift gap-l
         flash-v0 flash-span done-ms turn-step song-chunk)
(borrow 'rove)
(borrow 'view)                          ; the screen, its rays, the pens
(borrow 'play)                          ; the voices, the mix
(borrow 'posix)    ; close, for the horn
(:
 fps 30
 ; --- the shaft, in the world's units: x and z across it, y up, the middle of the
 ; floor the origin. s runs round the walls from the corner at (-r -r): along the wall
 ; at z = -r first, then x = r, z = r and x = -r, each of them twice r long ---
 shaft-r 3.0 perim (8.0 * shaft-r)
 floors 3 floor-h 4.0                 ; floors, and the height of one; a floor's ledge is at its height
 ceil-h 3.0                           ; the roof above the top ledge
 ledge-d 1.4 ledge-t 0.25             ; a ledge: how far it stands out from the wall, and how thick
 walk-q 0.7 eye-h 1.3                 ; the player starts this far in from the wall, eyes this high off their feet
 body-r 0.3                           ; ..and comes no nearer a wall than this
 ; the ladders, [s from to] each: one a floor, up the wall at z = -r for the even floors
 ; and beside the door for the odd; and the hole in the ledge each comes up through, by ring
 door-s (5.0 * shaft-r) door-w 0.6 door-h 2.2 door-edge 0.08   ; the doors, in the middle of the wall at z = r
 ladders (map (f \ [(f % 2 = 0 ? shaft-r (door-s - 1.6)) (f * floor-h) ((f + 1) * floor-h)]) ^(floors - 1))
 ladder-w 0.35                        ; ..how near a ladder is at it
 hatch-w 0.5                          ; the hole in a ledge over its ladder, either side of it -- drawn, not fallen through
 hatches (foldl (\ t l (pin t (int (l 2 / floor-h + 0.5)) [[(l 0 - hatch-w) (l 0 + hatch-w)]])) {} ladders)
 rail-in 0.16 rail-out 0.26 rung-gap 0.35 rung-w 0.2 ladder-over 0.9   ; ..its rails, its rungs, and how far it stands above its ledge
 light-h 1.6                          ; the lights, in the middle of the walls at x = r and x = -r, this high above a floor's ledge
 core-r2 0.012 halo-r2 0.6            ; ..a light's lamp, and the reach of its halo on the plates when lit, radii squared
 light-period 2.4 light-on 0.9 light-edge 0.35   ; ..blink: on this long in every period, up and down over the edge
 light-drift 0.17                     ; ..a floor's period longer than the one below by this, so they drift apart
 gap-l 1.4 gaps-a-ring 2              ; a gap in a ledge, and how many a ring
 gap-margin 1.2                       ; ..clear of a ladder, the door or another gap
 corner-margin (ledge-d + 0.4)        ; ..and of a corner: past the reach of the next wall's ledge
 plate-w 1.5 plate-h 1.2 seam-w 0.05  ; the iron plates, and the seams between them
 ; --- the player: walking, jumping, falling, climbing ---
 grav 12.0 jump-v 5.2                 ; gravity, and a jump's speed up
 walk-v 2.0 climb-v 1.6               ; walking, and up a ladder -- a key a frame, held
 turn-step 0.08                       ; a turn key's turn
 climb-h 0.35                         ; a step up this high is walked, not jumped
 coyote 4                             ; frames off a ledge's edge a jump still counts, and a key's push still carries
 flash-v0 5.0 flash-span 9.0          ; a landing faster than the first flashes, fully so at the sum
 flash-hold 0.25 flash-slow 1.5       ; ..and fades over this many seconds, plus this many at the fullest
 done-ms 1500                         ; the top door open: this long, then the level is over
 ; the pens, near, middling and far, in the 256-colour palette: dark
 band-1 6.0 band-2 12.0               ; ..the reaches
 iron-pens [236 235 234] seam-pens [233 232 232]
 rust-pens [88 52 52] face-pens [52 233 233] under-pens [233 232 232]
 floor-pens [232 232 232] ceil-pen 232
 core-pen 196 lamp-pen 52             ; a light lit, and its lamp dark between
 panel-pen 235 frame-pen 240 open-pen 230 ladder-pen 242
 irons (star-tray [3] iron-pens) seams (star-tray [3] seam-pens) floorings (star-tray [3] floor-pens)
 (band-of d) ((band-1 < d) + (band-2 < d))
 ; --- round the walls ---
 (wrap-s s) (s - perim * flo (s / perim))
 (s-apart a b) (: d (wrap-s (a - b)) (min2 d (perim - d)))
 (wall-of s) ((flo (wrap-s s / (2.0 * shaft-r))) % 4)
 ; the point s round the walls and q in from them; a point's run along a wall and its
 ; distance in from it; the way a wall runs, as a bearing, direction (sin cos)
 (ring-pt s q) (: r shaft-r i (wall-of s) l (wrap-s s - 2.0 * r * i)
                  (i @ 0 [(l - r) (q - r)] 1 [(r - q) (l - r)] 2 [(r - l) (r - q)] [(q - r) (r - l)]))
 (wall-s i x z) (: r shaft-r (i @ 0 (x + r) 1 (z + r) 2 (r - x) (r - z)))
 (wall-q i x z) (: r shaft-r (i @ 0 (z + r) 1 (r - x) 2 (r - z) (x + r)))
 tangents [(pi / 2.0) 0.0 (0.0 - pi / 2.0) pi]
 (tangent-of s) (tangents (wall-of s))
 ; --- the lay: the gaps in the ledges, [s0 s1] each by ring, off the die -- each within
 ; one wall and clear of its corners, of a ladder and its hole, of the door and of another gap ---
 (shaft-lay sb) (: keep ((map (l \ l 0) ladders) + [door-s])
   (clear? s0 gs) (: w2 (2.0 * shaft-r) c (s0 - w2 * flo (s0 / w2)) s1 (s0 + gap-l)
                     (off p) (p < s0 - gap-margin || s1 + gap-margin < p)
                     (corner-margin <= c && c + gap-l <= w2 - corner-margin
                      && all off keep && all (g \ off (g 0) && off (g 1)) gs))
   (ring gs n tries) (? (n <= 0 || tries <= 0) gs
                        (: s0 (roll sb 10000 / 10000.0 * perim)
                           (clear? s0 gs ? (ring (gs + [[s0 (s0 + gap-l)]]) (n - 1) tries)
                                           (ring gs n (tries - 1)))))
   gaps (foldl (\ t f (pin t f (ring () gaps-a-ring 80))) {} (map (+ 1) ^(floors - 1)))
   {'gaps gaps})
 ; a ledge under s on ring f: the floor is one everywhere, and a ring above it wherever
 ; no gap is
 (ledge? lay f s) (? (f <= 0) 1 (floors <= f) 0
                     (: ss (wrap-s s) (!(any (g \ g 0 <= ss < g 1) (peep (lay 'gaps) f ())))))
 ; the wall a point stands nearest, [i s q]: which, how far round the shaft, and how far in
 (near-wall x z) (foldl (\ a i (: q (wall-q i x z) (q < a 2 ? [i (2.0 * shaft-r * i + wall-s i x z) q] a)))
                        [0 0.0 99.0] ^4)
 ; a ledge of ring f under the point: within a ledge's depth of some wall, and no gap there
 (ledge-under? lay f x z) (? (f <= 0) 1
                             (any (i \ wall-q i x z <= ledge-d && ledge? lay f (2.0 * shaft-r * i + wall-s i x z)) ^4))
 ; the ground under feet at y: the highest ledge under the point no more than a step above them
 (ground-at lay x z y) (foldl max2 0.0 (map (f \ (? (ledge-under? lay f x z && f * floor-h <= y + climb-h) (f * floor-h) 0.0)) ^floors))
 ; a fall from y1 to y2: the highest ledge under the point crossed on the way, or -1 for none
 (land-at lay x z y1 y2) (foldl max2 -1.0 (map (f \ (: t (f * floor-h) (ledge-under? lay f x z && y2 <= t < y1 ? t -1.0))) ^floors))
 ; the ladder within reach of the point at y, or (): against its wall, beside it, and
 ; between its ends or near enough
 (ladder-at lay x z y) (: (near? l) (: i (wall-of (l 0))
                                       (wall-q i x z <= ledge-d + 0.2 && s-apart (2.0 * shaft-r * i + wall-s i x z) (l 0) <= ladder-w
                                        && l 1 - 0.2 <= y <= l 2 + 0.2))
                          ls (filter near? ladders)
                          (two? ls ? <ls ()))
 ; --- the state: the screen, where the player stands and looks, how they move, and
 ; the lay ---
 ; the screen as view lays it; 'px 'pz where the player stands, 'y the feet's height, 'th the way they face as a bearing; 'vx 'vz 'vy
 ; the speed across and up, kept in the air; 'kx 'kz the last step a key pushed and
 ; 'kt when, for a jump to carry it; 'ground standing on something, 'rung the ladder
 ; held or (); 'flash the red on the screen and 'flash-k what is left of it a frame on,
 ; 'sfx sounds due, 'done the top door open
 ; the horizon starts a little above the middle: the view pitched down a touch, to the ledge ahead
 (shaft-new w h st) (: sb {st} e (ring-pt 1.0 walk-q)
   (view! {'px (e 0) 'pz (e 1) 'y 0.0 'th (tangents 0) 'vx 0.0 'vz 0.0 'vy 0.0 'kx 0.0 'kz 0.0 'kt -999
           'ground 1 'rung () 't 0 'off-t -999
           'flash 0.0 'flash-k 1.0 'sfx () 'done 0 'sb sb 'lay (shaft-lay sb)}
          w h (5 * h // 12)))
 ; the screen's shape: w cells across and r rows, the horizon off the top and bottom eighth
 (shaft-size st w r) (view-size st w r 8)
 ; --- a frame of motion ---
 ; a landing on a ledge at g, coming down at v: the feet on it, the flash by how hard --
 ; nothing under flash-v0, and both more opaque and slower to fade the harder -- and a thud
 (shaft-land st g v) (: a (clamp ((v - flash-v0) / flash-span) 0.0 1.0)
   tau (flash-hold + flash-slow * a)
   (pins st 'y g 'vy 0.0 'ground 1
            'flash (max2 a (st 'flash))
            'flash-k (a <= 0.0 ? (st 'flash-k) (exp (0.0 - 1.0 / (fps * tau))))
            'sfx (v < 1.0 ? (st 'sfx) (st 'sfx + [['thud (0.3 + 0.7 * clamp (v / 12.0) 0.0 1.0)]]))))
 ; the push the keys last gave, if it was within a few frames, else none: what a jump
 ; or a fall carries, a second's worth
 (carried st) (st 't - st 'kt <= coyote ? [(st 'kx * fps) (st 'kz * fps)] [0.0 0.0])
 ; a jump, from the ground or within a few frames of leaving it, carrying the walk
 (shaft-jump st) (? (st 'rung) st
                    (st 'ground || st 't - st 'off-t <= coyote)
                    (: c (carried st) (pins st 'vy jump-v 'vx (c 0) 'vz (c 1) 'ground 0 'off-t -999))
                    st)
 ; a step to x z, kept inside the walls
 (put! st x z) (: m (shaft-r - body-r) (pins st 'px (clamp x (0.0 - m) m) 'pz (clamp z (0.0 - m) m)))
 ; the frame's motion: on a ladder, nothing but what the keys do; on the ground, the
 ; step the keys pushed, and off a ledge's edge into the air; in the air, on at the speed
 ; the ground was left at and down under gravity, until a ledge or the floor is crossed
 ; on the way down, which is a landing. the flash fades; and standing at the top door
 ; opens it, which is the level done
 (shaft-move st) (: lay (st 'lay) y (st 'y) dt (1.0 / fps)
   _ (? (st 'rung) st
        (st 'ground)
        (: _ (? (st 'kt = st 't) (put! st (st 'px + st 'kx) (st 'pz + st 'kz)))   ; this frame's push
           g (ground-at lay (st 'px) (st 'pz) y)
           (? (g < y - 0.01) (: c (carried st) (pins st 'ground 0 'vy 0.0 'vx (c 0) 'vz (c 1) 'off-t (st 't)))
              (pin st 'y g)))
        (: vy (st 'vy - grav * dt) y2 (y + vy * dt)
           _ (put! st (st 'px + st 'vx * dt) (st 'pz + st 'vz * dt))
           g (vy < 0.0 ? (land-at lay (st 'px) (st 'pz) y y2) -1.0)
           (? (0.0 <= g) (shaft-land st g (0.0 - vy)) (pins st 'y y2 'vy vy))))
   fl (st 'flash * st 'flash-k)
   _ (pin st 'flash (fl < 0.02 ? 0.0 fl))
   nw (near-wall (st 'px) (st 'pz))
   _ (? (!(st 'done) && st 'ground && (floors - 1) * floor-h - 0.01 <= st 'y
         && nw 0 = wall-of door-s && nw 2 <= ledge-d && s-apart (nw 1) door-s <= door-w + 0.2)
        (pins st 'done 1 'sfx (st 'sfx + ['door])))
   st)
 ; a key: h l or the arrows turn, k or up steps forward and j or down back -- a tty
 ; tells of keys pressed and never of keys let go, and repeats a held one, so a held key
 ; is a walk, a step a frame -- u n tilt the look; space jumps, or at a ladder takes hold
 ; of it: then k and j climb, off at the top onto the ledge or at the foot onto the
 ; ground, and space lets go
 (shaft-step st k) (: turn (k @ (104 || -1) (0.0 - turn-step) (108 || -2) turn-step 0.0)
   h (st 'h) tilt (k @ 117 (h // 16) 110 (0 - h // 16) 0)
   fwd (k @ (107 || -8) 1.0 (106 || -9) -1.0 0.0)
   l (st 'rung)
   (step d) (: v (d * walk-v / fps) (pins st 'kx (v * sin (st 'th)) 'kz (v * cos (st 'th)) 'kt (st 't)))
   (climb d) (: y2 (st 'y + d * climb-v / fps)
                (? (l 2 <= y2) (pins st 'y (l 2) 'rung () 'ground 1)
                   (y2 <= l 1) (pins st 'y (l 1) 'rung () 'ground 1)
                   (pin st 'y y2)))
   (hold la) (: i (wall-of (la 0)) e (ring-pt (la 0) walk-q)
                (pins st 'rung la 'px (e 0) 'pz (e 1) 'th (wrap (tangents i + pi / 2.0)) 'ground 0 'vx 0.0 'vz 0.0 'vy 0.0))
   (? (st 'done) st
      (turn != 0.0) (pin st 'th (wrap (st 'th + turn)))
      (tilt != 0) (view-hz st (st 'hz + tilt) 8)
      (k = 32) (? l (pins st 'rung () 'ground 0 'off-t (st 't))
                  (: la (ladder-at (st 'lay) (st 'px) (st 'pz) (st 'y)) (la ? (hold la) (shaft-jump st))))
      (fwd != 0.0) (l ? (climb fwd) (step fwd))
      st))
 ; --- the frame ---
 ; the flash: the screen's pens pulled toward red, in four steps of opacity, each a
 ; tray a pen indexes, made once
 (tint a) (star-tray [256] (map (c \ (: q (pen-rgb c)
                                        (rgb-pen (int (q 0 + a * (255 - q 0))) (int (q 1 * (1.0 - a))) (int (q 2 * (1.0 - a))))))
                                ^256))
 flashes (map (i \ tint ((i + 1) / 4.0)) ^4)
 ; a floor's lights' brightness at tick t, 0 to 1: on for light-on of every period, up
 ; and down over light-edge; each floor's period a little longer than the one below
 (blink t f) (: sec (t / (1.0 * fps)) per (light-period + f * light-drift) ph (sec - per * flo (sec / per))
                (clamp (min2 (ph / light-edge) ((light-on - ph) / light-edge)) 0.0 1.0))
 ; a row of the background: every column's ray at the row's slope, and what it meets:
 ; the wall it ends on, its plates in seams and a speckle, the lights, the doors and
 ; the ladders on it by where it is hit; or the floor, or the roof
 (bg-row y st tb) (: hz (st 'hz) foc (st 'foc) ey (tb 'ey) lay (st 'lay) r shaft-r
   dw (tb 'dw) iw (tb 'iw) sw (tb 'sw) sg (tb 'sg) bd (tb 'bd) vx (tb 'vx) vz (tb 'vz)
   m ((hz - y - 0.5) / foc)
   yh (ey + m * dw)
   ; the plates: seams, and a speckle
   sp (sg / plate-w) fs (sp - floor sp) yp (yh / plate-h) fy (yp - floor yp)
   seam (0 < (fs < seam-w) + (fy < seam-w))
   spk (0 = throw (floor (sg * 4.0)) (floor (yh * 4.0)) 3 5)
   iron (peep irons bd 236)
   c1 (over (over iron seam (peep seams bd 233)) spk (iron - 1))
   ; the lights, on the walls at x = r and x = -r, one a floor: a lamp, and when lit a
   ; halo on the plates round it, the palette pulled toward red by more the nearer
   side ((iw = 1) + (iw = 3))
   ds (sw - r)
   (light c f) (: dy (yh - (f * floor-h + light-h)) r2 (ds * ds + dy * dy)
                  bl (tb 'blinks f) hr (halo-r2 * bl)
                  lv (floor (3.0 * (1.0 - r2 / (hr + 0.000001))) + 1)   ; 3 by the lamp, 1 at the halo's edge
                  (halo c k) (over c (side * (r2 < hr) * (lv = k)) (peep (flashes (k - 1)) c 0))
                  c2 (0.0 < bl ? (foldl halo c [1 2 3]) c)
                  (over c2 (side * (r2 < core-r2)) (0.5 < bl ? core-pen lamp-pen)))
   c2 (foldl light c1 ^floors)
   ; the doors, on the wall at z = r: a frame, a shut panel, and the top one open with light beyond
   ads (max ds (0.0 - ds))
   (door c f) (: dy (yh - f * floor-h) in ((iw = 2) * (ads < door-w) * (0.0 <= dy) * (dy < door-h))
                 edge ((door-w - door-edge < ads) + (door-h - door-edge < dy))
                 (over (over c in (f = floors - 1 && st 'done ? open-pen panel-pen)) (in * (0 < edge)) frame-pen))
   c3 (foldl door c2 ^floors)
   ; the ladders: two rails and the rungs between, each on its wall
   (ladder c l) (: wl (wall-of (l 0)) dd (sw - (l 0 - 2.0 * r * wl)) add (max dd (0.0 - dd))
                   on ((iw = wl) * (l 1 <= yh) * (yh <= l 2 + ladder-over))
                   rail (on * (rail-in < add) * (add < rail-out))
                   yr (yh / rung-gap) rung (on * (add < rail-out) * ((yr - floor yr) < rung-w))
                   (over c (0 < rail + rung) ladder-pen))
   c4 (foldl ladder c3 ladders)
   ; the floor under it all, concrete, and the roof
   df ((tb 'ey) / (0.000001 - m))
   fx ((tb 'ex) + df * vx) fz ((tb 'ez) + df * vz)
   fspk (0 = throw (floor (fx * 3.0)) (floor (fz * 3.0)) 9 4)
   fbd (band-of df)
   flr (over (peep floorings fbd 232) fspk (peep floorings fbd 232 + 1))
   (over (over c4 (yh < 0.0) flr) (tb 'ceil < yh) ceil-pen))
 ; the ledges, a column at a time into ov, a cask of bytes, a pen a pixel and 0 for none -- with
 ; the hole over each ladder left out, which the feet do not know of: the ray's
 ; stretch through each wall's band -- where it is both within a ledge's depth of the
 ; wall and along it, the square at a corner going to the wall that starts there and
 ; not the one that ends -- nearest band first; on each, every ring's ledge where no
 ; gap is, the ring whose plane is nearest the eye first and nearest stretch first, as
 ; spans of rows: its face where the ray comes at it across the band's inner edge or
 ; out of a gap, its top if the eye is above it, its underside if below; a pixel
 ; painted stays painted
 (ledges! st tb ov) (: w (st 'w) h (st 'h) hz (st 'hz) foc (st 'foc) lay (st 'lay)
   ey (tb 'ey) ex (tb 'ex) ez (tb 'ez) r shaft-r w2 (2.0 * shaft-r)
   (rowof d yy) (flo (hz - foc * (yy - ey) / (d < 0.02 ? 0.02 d)))
   (fill! x ra rb p) (: a (max2 0 (min2 ra rb)) b (min2 (h - 1) (max2 ra rb))
                        (go i) (? (i <= x + w * b) (: _ (? (0 = peep ov i 0) (pin ov i p)) (go (i + w))))
                        (go (x + w * a)))
   (span a k lo hi) (? (k * k < 1e-18) (lo <= a <= hi ? [0.0 1e9] [1.0 0.0])
                       (: t0 ((lo - a) / k) t1 ((hi - a) / k) (t0 < t1 ? [t0 t1] [t1 t0])))
   (col x) (: vx (peep (tb 'vx) x 0.0) vz (peep (tb 'vz) x 0.0) dw (peep (tb 'dw) x 0.0)
     (band i) (: qa (wall-q i ex ez) kq (i @ 0 vz 1 (0.0 - vx) 2 (0.0 - vz) vx)
                 sa (wall-s i ex ez) ks (i @ 0 vx 1 vz 2 (0.0 - vx) (0.0 - vz))
                 q (span qa kq 0.0 ledge-d) rn (span sa ks 0.0 (w2 - ledge-d))
                 da (max2 0.0 (max2 (q 0) (rn 0))) db (min2 dw (min2 (q 1) (rn 1)))
                 [da db i sa ks (kq < 0.0 && ledge-d < qa && rn 0 <= q 0)])
     (ring b f) (: da (b 0) db (b 1) sag (b 3 + w2 * b 2) ks (b 4) front (b 5) yf (f * floor-h)
                   ; the stretch in s, and the ledge's runs on it between the gaps, as stretches in d
                   sA (sag + ks * da) sB (sag + ks * db) lo (min2 sA sB) hi (max2 sA sB)
                   gs ((peep (lay 'gaps) f ()) + (peep hatches f ()))   ; the gaps, and the hole over the ladder
                   pts (sort ([lo hi] + (filter (p \ lo < p < hi) (cat (map (g \ g 0) gs) (map (g \ g 1) gs)))))
                   (drawn? p) (: ss (wrap-s p) (ledge? lay f ss && !(any (g \ g 0 <= ss < g 1) (peep hatches f ()))))
                   (run p0 p1) (: mid ((p0 + p1) / 2.0)
                                  (? (drawn? mid) (: d0 ((p0 - sag) / ks) d1 ((p1 - sag) / ks) [(min2 d0 d1) (max2 d0 d1)]) ()))
                   runs (? (ks * ks < 1e-18) (drawn? sag ? [[da db]] ())
                           (sort (filter two? (map (i \ run (pts i) (pts (i + 1))) ^(#pts - 1)))))
                   (one rr) (: d0 (max2 da (rr 0)) d1 (min2 db (rr 1)) k (band-of d0)
                               _ (? (front || da + 1e-6 < d0) (fill! x (rowof d0 yf) (rowof d0 (yf - ledge-t)) (face-pens k)))
                               _ (? (yf < ey) (fill! x (rowof d1 yf) (rowof d0 yf) (rust-pens k)))
                               (? (ey < yf - ledge-t) (fill! x (rowof d0 (yf - ledge-t)) (rowof d1 (yf - ledge-t)) (under-pens k))))
                   (each runs one))
     bands (sort (filter (b \ b 0 < b 1) (map band ^4)))
     rings (map (p \ p 1) (sort (map (f \ (: dy (f * floor-h - ey) [(dy * dy) f])) (map (+ 1) ^(floors - 1)))))
     (each bands (b \ each rings (f \ ring b f))))
   (each ^w col))
 ; a frame, as view lays it: the background rows are trays and the ledges a cask over
 ; them, a pixel row a cask of the two, and the flash tints both
 (shaft-frame st) (: w (st 'w) h (st 'h) r shaft-r
   ex (st 'px) ez (st 'pz) ey (st 'y + eye-h)
   rs (view-rays st) vx0 (rs 0) vz0 (rs 1)
   vx (over vx0 (vx0 = 0.0) 1e-9) vz (over vz0 (vz0 = 0.0) 1e-9)
   ; each column's ray ends on the nearest of the four planes ahead of it
   tx (over ((0.0 - r - ex) / vx) (0.0 < vx) ((r - ex) / vx))
   tz (over ((0.0 - r - ez) / vz) (0.0 < vz) ((r - ez) / vz))
   nz (tz <= tx)
   dw (over tx nz tz)
   iw (nz * (over 0 (0.0 < vz) 2) + (1 - nz) * (over 3 (0.0 < vx) 1))
   hx (ex + dw * vx) hzz (ez + dw * vz)
   sw (over (over (over (hx + r) (iw = 1) (hzz + r)) (iw = 2) (r - hx)) (iw = 3) (r - hzz))
   tb {'ex ex 'ez ez 'ey ey 'vx vx 'vz vz 'dw dw 'iw iw 'sw sw 'sg (sw + 2.0 * r * iw) 'bd (band-of dw)
       'ceil ((floors - 1) * floor-h + ceil-h) 'blinks (map (f \ blink (st 't) f) ^floors)}
   ov (cask (w * h))                       ; zero to start: nothing painted
   _ (ledges! st tb ov)
   lv (int (st 'flash * 4.0 + 0.999))
   fm (0 < lv ? (flashes (lv - 1)) ())
   (src y) (: rw (bg-row y st tb) ts (fm ? (peep fm rw 0) rw) i0 (w * y) px (cask w)
              (go x) (? (x < w) (: o (peep ov (i0 + x) 0)
                                  _ (pin px x (0 = o ? (peep ts x 0) (fm ? (peep fm o 0) o)))
                                  (go (x + 1))))
              (go 0, px))
   (view-frame w h src {}))
 ; --- the song: nothing but what happens -- a thud on landing, the harder the louder,
 ; and two notes when the top door opens; out any port a frame's worth at a time ---
 song-chunk (song-rate // fps)
 song-gain 11000.0
 (shaft-song-new h st) {'h h 'sb {st} 'fpos 0 'vs ()}
 ; the sounds the state has due, into the song's voices, and the state's list cleared
 (shaft-sfx s st) (: (at k v) [(s 'fpos + int (k * song-rate)) (mkvoice (s 'fpos + int (k * song-rate)) v song-rate)]
   (one f) (f @- ()
              ('thud . g) [(at 0.0 {'s "bd" 'gain <g 'legato 0.5}) (at 0.03 {'s "sn" 'gain (0.4 * <g) 'speed 0.6})]
              'door [(at 0.0 {'s "chime" 'note 7.0 'gain 0.5 'legato 4.0}) (at 0.3 {'s "chime" 'note 12.0 'gain 0.5 'legato 4.0})])
   vs (foldl (\ acc f (cat acc (one f))) () (st 'sfx))
   _ (pin st 'sfx ())
   (pin s 'vs (s 'vs + filter (p \ two? (p 1)) vs)))
 (shaft-song-feed s) (song-out s song-chunk song-gain)
 ; --- the walk, on view's loop: a frame's motion after the key, the sounds it made fed to
 ; the song -- or let go, on a seat with no horn. shaft-walk takes a stage already
 ; raised, and shaft-run raises one ---
 (shaft-walk _) (view-walk {'new (\ w h (shaft-new w h (wheel (clock 0)))) 'size shaft-size
                            'frame shaft-frame 'key shaft-step 'tick shaft-move 'fps fps
                            'song (hn \ (: s (? hn (shaft-song-new hn (wheel (clock 0))) ())
                                           (? s (\ st (shaft-sfx s st, shaft-song-feed s)) (\ st (pin st 'sfx ())))))
                            'linger done-ms 'next ()})
 (shaft-run _) (view-run shaft-walk)
 shaft-usage "usage: love shaft   (h l turn, k j step, space jumps or takes a ladder, u n look; q or esc leaves)"
 (shaft-main as) (as @ () (shaft-run ())
                       (say err ("shaft: " + shaft-usage + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'shaft (udoor 'shaft shaft-main shaft-usage 1 1)))
) ; module shaft
