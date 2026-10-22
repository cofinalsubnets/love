; gesture -- the eye moving on its own in first person: kneeling, standing, and acts made
; from the kneel, each a move. an eye is a state's 'px 'py 'pz where it is, 'th its bearing
; (radians from north toward east), 'ph how far it looks up and 'ro its tilt right; 'mt the
; clock, in seconds. a move is per channel ('x 'y 'z 'th 'ph 'ro) keys [t v], seconds into it,
; eased through without overshoot and at rest at both ends; 'walk [x0 z0 x1 z1] the ground
; covered on foot, 'len its length, 'then what the eye is after, 'ev its events [t kind].
;   (gesture-curve ks t)                  a channel's keys at t
;   (gesture-at mv t)                     the eye at t into mv, [x y z th ph ro]; on foot a dip
;                                         at each step and a sway from foot to foot
;   (gesture-breath t)                    under every move, the eye rising and nodding a
;                                         little, slowly: [dy dph]
;   (gesture-kneel st spot at ground kh)  a slow walk to spot [x z], turning to face at [x z],
;                                         one knee then the other, kh the eye kneeling over
;                                         (ground x z); then 'kneel
;   (gesture-stand st ground eh)          up from a kneel: a lean, the push up, a step back,
;                                         eh the eye standing; then 'walk
;   (gesture-act st keys)                 an act's keys laid on the eye where it kneels; keys
;                                         'y 'ph 'ro offsets, 'fw how far it leans ahead;
;                                         then 'kneel
;   gesture-acts                          the acts kept here: 'breathe 'weep 'bleed 'beg
;   (gesture-begin st mv)                 the eye on mv from now: 'eye 'move
;   (gesture-play st dt fall)             a frame of the move, dt seconds after the last:
;                                         (fall st kind) for each event passed; 'eye is mv's
;                                         'then once it is over
(module (gesture gesture-curve gesture-at gesture-breath gesture-kneel gesture-stand gesture-act gesture-acts
         gesture-begin gesture-play)
(borrow 'view)                          ; wrap, clamp, min2, max2
(borrow 'vec)
(:
 stride 0.7                             ; a step, in metres
 pace 0.9                               ; the walk to a kneel, a second
 (gesture-curve ks t)
  (: n #ks (ti i) (ks i 0) (vi i) (ks i 1)
     ; ..a key's slope: none at the ends or where the way turns back; else the way through
     ; it, held to three times the gentler side's, so the curve stays between its keys
     (slope i) (: a ((vi i - vi (i - 1)) / (ti i - ti (i - 1))) b ((vi (i + 1) - vi i) / (ti (i + 1) - ti i))
                  m ((vi (i + 1) - vi (i - 1)) / (ti (i + 1) - ti (i - 1))) lim (3.0 * min2 (mag a) (mag b))
                  (a * b <= 0.0 ? 0.0 (clamp m (0.0 - lim) lim)))
     (slope0 i) (i = 0 || i = n - 1 ? 0.0 (slope i))
     (seg i) (i + 2 < n && ti (i + 1) <= t ? (seg (i + 1)) i)
     (? (n = 1 || t <= ti 0) (vi 0) (ti (n - 1) <= t) (vi (n - 1))
        (: i (seg 0) h (ti (i + 1) - ti i) s ((t - ti i) / h) s2 (s * s) s3 (s2 * s)
           (vi i * (2.0 * s3 - 3.0 * s2 + 1.0) + slope0 i * h * (s3 - 2.0 * s2 + s)
            + vi (i + 1) * (3.0 * s2 - 2.0 * s3) + slope0 (i + 1) * h * (s3 - s2)))))
 ; ..the steps a whole number, so the last ends where the walk does
 (gesture-at mv t) (: (ch k) (gesture-curve (mv k) t) x (ch 'x) z (ch 'z) w (mv 'walk)
   (far a b) (sqrt (sq (a - w 0) + sq (b - w 1)))
   ; ..none where it goes nowhere
   sl (two? w ? (far (w 2) (w 3) @ L (L / max2 1.0 (floor (L / stride + 0.5)))) 0.0)
   q (sl > 1e-6 ? (pi * far x z / sl) 0.0)
   [x (ch 'y - 0.022 * sq (sin q)) z (ch 'th) (ch 'ph) (ch 'ro + 0.012 * sin q)])
 (gesture-breath t) [(0.005 * sin (t * 1.55)) (0.004 * sin (t * 1.55 - 0.8))]
 ; ..turn to it, the walk, the knees, the gaze settling below
 (gesture-kneel st spot at ground kh) (: x0 (st 'px) z0 (st 'pz) y0 (st 'py) th0 (st 'th) ph0 (st 'ph)
   kx (spot 0) kz (spot 1) ax (at 0) az (at 1) yk (ground kx kz + kh)
   d (sqrt (sq (kx - x0) + sq (kz - z0))) tw (max2 0.6 (d / pace)) T (0.25 + tw)
   ; ..its bearing from a place, unwound to lie near th0
   (look x z) (th0 + wrap (atan2 (ax - x) (az - z) - th0))
   (on f) [(x0 + f * (kx - x0)) (z0 + f * (kz - z0))]
   (lk f) (on f @ p (look (p 0) (p 1)))
   {'x [[0.0 x0] [0.25 x0] [T kx]] 'z [[0.0 z0] [0.25 z0] [T kz]]
    'th [[0.0 th0] [0.55 (lk 0.0)] [(0.25 + 0.5 * tw) (lk 0.5)] [T (lk 1.0)]]
    'ph [[0.0 ph0] [0.6 -0.12] [T -0.3] [(T + 0.9) -0.55] [(T + 1.9) -0.45]]
    'y [[0.0 y0] [T y0] [(T + 0.45) (yk + 0.3)] [(T + 0.65) (yk + 0.28)] [(T + 1.05) (yk - 0.03)]
        [(T + 1.4) (yk + 0.008)] [(T + 1.8) yk]]
    'ro [[0.0 0.0] [T 0.0] [(T + 0.45) 0.06] [(T + 0.7) 0.05] [(T + 1.1) -0.025] [(T + 1.6) 0.0]]
    'walk [x0 z0 kx kz] 'len (T + 2.0) 'then 'kneel})
 ; ..looking up as it stands
 (gesture-stand st ground eh) (: x0 (st 'px) z0 (st 'pz) y0 (st 'py) th (st 'th) ph0 (st 'ph)
   bx (x0 - 0.3 * sin th) bz (z0 - 0.3 * cos th) ys (ground bx bz + eh)
   {'x [[0.0 x0] [0.5 x0] [1.4 bx]] 'z [[0.0 z0] [0.5 z0] [1.4 bz]] 'th [[0.0 th]]
    'ph [[0.0 ph0] [0.4 (ph0 - 0.15)] [1.1 -0.05] [1.7 0.05]]
    'y [[0.0 y0] [0.35 (y0 - 0.02)] [0.8 (y0 + 0.25)] [1.3 (ys + 0.015)] [1.7 ys]]
    'ro [[0.0 (peep st 'ro 0.0)] [0.5 -0.05] [1.0 0.02] [1.5 0.0]]
    'walk () 'len 1.8 'then 'walk})
 (gesture-act st a) (: x0 (st 'px) z0 (st 'pz) th (st 'th)
   (off v l) (map (q \ [(q 0) (v + q 1)]) l)
   {'x (map (q \ [(q 0) (x0 + q 1 * sin th)]) (a 'fw)) 'z (map (q \ [(q 0) (z0 + q 1 * cos th)]) (a 'fw))
    'y (off (st 'py) (a 'y)) 'th [[0.0 th]] 'ph (off (st 'ph) (a 'ph)) 'ro (off (peep st 'ro 0.0) (a 'ro))
    'walk () 'len (a 'len) 'then 'kneel 'ev (peep a 'ev ())})
 gesture-acts
  {; a long breath in, the chin rising and the chest back, held, then out, a little below
   'breathe
   {'y [[0.0 0.0] [0.5 -0.006] [3.5 0.035] [4.4 0.037] [8.4 -0.012] [9.6 0.0]]
    'ph [[0.0 0.0] [0.5 -0.012] [3.5 0.12] [4.4 0.13] [8.4 -0.05] [9.6 0.0]]
    'ro [[0.0 0.0] [4.0 0.012] [8.0 -0.006] [9.6 0.0]]
    'fw [[0.0 0.0] [3.5 -0.02] [4.4 -0.02] [8.4 0.012] [9.6 0.0]] 'len 9.8 'ev ()}
   ; the head bowed, hunched over, the sobs in fits of quick catches, the tears falling
   'weep
   {'y [[0.0 0.0] [1.0 -0.03] [1.3 -0.02] [1.45 -0.032] [1.6 -0.018] [1.75 -0.033] [1.9 -0.016] [2.5 -0.04]
        [3.0 -0.022] [3.15 -0.034] [3.3 -0.02] [3.45 -0.036] [4.2 -0.045] [4.6 -0.025] [4.75 -0.035]
        [4.9 -0.022] [5.05 -0.036] [5.2 -0.024] [6.0 -0.046] [6.6 -0.04] [7.4 -0.042] [8.6 0.0]]
    'ph [[0.0 0.0] [1.0 -0.4] [1.3 -0.36] [1.45 -0.41] [1.6 -0.35] [1.75 -0.42] [1.9 -0.34] [2.5 -0.45]
         [3.0 -0.37] [3.15 -0.43] [3.3 -0.36] [3.45 -0.44] [4.2 -0.47] [4.6 -0.38] [4.75 -0.44]
         [4.9 -0.37] [5.05 -0.45] [5.2 -0.38] [6.0 -0.48] [6.6 -0.42] [7.4 -0.44] [8.6 0.0]]
    'ro [[0.0 0.0] [1.5 0.03] [3.0 -0.02] [4.5 0.035] [6.0 -0.015] [7.4 0.01] [8.6 0.0]]
    'fw [[0.0 0.0] [1.0 0.05] [7.4 0.06] [8.6 0.0]] 'len 8.8
    'ev (map (t \ [t 'tear]) [1.7 2.3 3.2 3.6 4.3 4.95 5.4 6.2 6.9])}
   ; leant over, a flinch as at a cut, blood dripping from the hand held out
   'bleed
   {'y [[0.0 0.0] [1.2 -0.08] [1.9 -0.08] [1.97 -0.095] [2.3 -0.085] [5.6 -0.08] [6.8 0.0]]
    'ph [[0.0 0.0] [1.2 0.02] [1.9 0.02] [1.96 0.09] [2.4 -0.02] [5.6 0.0] [6.8 0.0]]
    'ro [[0.0 0.0] [1.9 0.0] [1.97 0.09] [2.4 0.06] [3.4 0.07] [4.6 0.04] [5.8 0.0]]
    'fw [[0.0 0.0] [1.2 0.42] [5.6 0.44] [6.8 0.0]] 'len 7.0
    'ev (map (t \ [t 'blood]) [2.4 2.9 3.3 3.8 4.2 4.7 5.1])}
   ; face to the ground, up ahead, then up at the sky, calling three times
   'beg
   {'y [[0.0 0.0] [1.2 -0.3] [2.4 -0.9] [3.0 -0.95] [5.0 -0.95] [6.2 -0.88] [6.8 -0.88] [8.4 0.0] [10.3 0.0]
        [10.55 0.02] [11.1 0.0] [11.65 0.022] [12.2 0.0] [12.85 0.022] [13.4 0.0] [15.4 0.0]]
    'ph [[0.0 0.0] [1.2 -0.5] [2.4 -0.9] [3.0 -0.92] [5.0 -0.9] [6.2 0.75] [6.8 0.7] [8.4 0.25] [8.8 0.25]
         [10.0 1.4] [10.3 1.4] [10.55 1.5] [11.1 1.4] [11.65 1.52] [12.2 1.4] [12.85 1.52] [13.4 1.38]
         [14.0 1.4] [15.4 0.0]]
    'ro [[0.0 0.0] [2.4 0.04] [5.0 0.03] [6.2 0.0] [8.4 -0.02] [10.0 0.0] [15.4 0.0]]
    'fw [[0.0 0.0] [1.2 0.3] [2.4 0.55] [3.0 0.58] [5.0 0.58] [6.2 0.5] [6.8 0.5] [8.4 0.0] [10.3 0.0]
         [10.55 0.035] [11.1 0.0] [11.65 0.035] [12.2 0.0] [12.85 0.035] [13.4 0.0] [15.4 0.0]] 'len 15.6 'ev ()}}
 (gesture-begin st mv) (pins st 'eye 'move 'mv mv 'm0 (peep st 'mt 0.0))
 (gesture-play st dt fall) (: mv (st 'mv) t (peep st 'mt 0.0 - st 'm0) p (gesture-at mv t)
   _ (each (peep mv 'ev ()) (e \ (t - dt < e 0 && e 0 <= t ? (fall st (e 1)))))
   (pins st 'px (p 0) 'py (p 1) 'pz (p 2) 'th (wrap (p 3)) 'ph (p 4) 'ro (p 5)
            'eye (mv 'len <= t ? (mv 'then) 'move))))
) ; module gesture
