; walk -- a body walking in first person: its keys, its step slid along what stops it,
; and the time a frame took. a state holds 'px 'pz where it stands, 'th the way it faces
; (radians from north toward east) and 'ph how far it looks up.
;
;   (walk-key st k g put)    a walking key: h l or the arrows turn, k j step, u n look up
;                            and down, each as far as g says -- {'turn 'walk 'tilt 'up
;                            'down}, a press's turn, step and tilt and the pitch's bounds;
;                            (put st x z) moves it. () for any other key
;   (walk-slide st x z free?)  to x z where (free? st x z), else as far as goes east or
;                            north alone, else nowhere
;   (walk-dt st)             'dt the seconds since the last frame, kept between 0.02 and
;                            0.25, and 'wall the clock it was taken at
;   (walk-rail st k facing move)  a key on a rail, view's horizon for the look: h l or the
;                            arrows turn, within facing of ahead, k or up goes on -- never
;                            back -- by (move st d), u n tilt the horizon an eighth of the
;                            screen, and space goes on by itself, 'walk; once 'done, none
(module (walk walk-key walk-slide walk-dt walk-rail)
(borrow 'view)                          ; wrap, clamp, min2, max2
(:
 (walk-key st k g put) (: th (st 'th)
   (step d) (put st (st 'px + d * sin th) (st 'pz + d * cos th))
   (k @ (104 || -1) (pin st 'th (wrap (th - g 'turn)))
        (108 || -2) (pin st 'th (wrap (th + g 'turn)))
        (107 || -8) (step (g 'walk))
        (106 || -9) (step (0.0 - g 'walk))
        117 (pin st 'ph (min2 (g 'up) (st 'ph + g 'tilt)))
        110 (pin st 'ph (max2 (g 'down) (st 'ph - g 'tilt)))
        ()))
 (walk-slide st x z free?) (? (free? st x z) (pins st 'px x 'pz z)
                              (free? st x (st 'pz)) (pin st 'px x)
                              (free? st (st 'px) z) (pin st 'pz z)
                              st)
 (walk-dt st) (clock 0 @ now (pins st 'dt (clamp ((now - peep st 'wall now) / 1000.0) 0.02 0.25) 'wall now))
 (walk-rail st k facing move) (: turn (k @ 104 -0.08 -1 -0.08 108 0.08 -2 0.08 0.0)
   mv (k @ 107 0.35 -8 0.35 0.0)
   h (st 'h) tilt (k @ 117 (h // 16) 110 (0 - h // 16) 0)
   (? (st 'done) st
      (turn != 0.0) (pin st 'th (clamp (st 'th + turn) (0.0 - facing) facing))
      (tilt != 0) (view-hz st (st 'hz + tilt) 4)
      (mv != 0.0) (move st mv)
      (k = 32) (pin st 'walk (st 'walk ? 0 1))
      st))))
