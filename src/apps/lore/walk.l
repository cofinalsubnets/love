; walk -- a body walking in first person: its keys, its step slid along what stops it,
; and the time a frame took. a state holds 'px 'pz where it stands, 'th the way it faces
; (radians from north toward east) and 'ph how far it looks up.
;
;   (walk-key st a g put)    a walking action, view's: 'turn-left 'turn-right turn,
;                            'forward 'back step, 'look-up 'look-down tilt, each as far as
;                            g says -- {'turn 'walk 'tilt 'up 'down}, a press's turn, step
;                            and tilt and the pitch's bounds; (put st x z) moves it. () for
;                            any other action
;   (walk-slide st x z free?)  to x z where (free? st x z), else as far as goes east or
;                            north alone, else nowhere
;   (walk-dt st)             'dt the seconds since the last frame, kept between 0.02 and
;                            0.25, and 'wall the clock it was taken at
;   (walk-rail st a facing move)  an action on a rail, view's horizon for the look: the
;                            turns within facing of ahead, 'forward goes on -- never back --
;                            by (move st d), the looks tilt the horizon an eighth of the
;                            screen, and 'stroll goes on by itself, 'walk; once 'done, none
;   walk-binds walk-listed   the rail's own key, space for 'stroll, and the actions its
;                            help shows -- no 'back on a rail
(module (walk walk-key walk-slide walk-dt walk-rail walk-binds walk-listed)
(borrow 'view)                          ; wrap, clamp, min2, max2
(:
 (walk-key st a g put) (: th (st 'th)
   (step d) (put st (st 'px + d * sin th) (st 'pz + d * cos th))
   (a @ 'turn-left (pin st 'th (wrap (th - g 'turn)))
        'turn-right (pin st 'th (wrap (th + g 'turn)))
        'forward (step (g 'walk))
        'back (step (0.0 - g 'walk))
        'look-up (pin st 'ph (min2 (g 'up) (st 'ph + g 'tilt)))
        'look-down (pin st 'ph (max2 (g 'down) (st 'ph - g 'tilt)))
        ()))
 (walk-slide st x z free?) (? (free? st x z) (pins st 'px x 'pz z)
                              (free? st x (st 'pz)) (pin st 'px x)
                              (free? st (st 'px) z) (pin st 'pz z)
                              st)
 (walk-dt st) (clock 0 @ now (pins st 'dt (clamp ((now - peep st 'wall now) / 1000.0) 0.02 0.25) 'wall now))
 walk-binds {32 'stroll}
 walk-listed ['forward 'turn-left 'turn-right 'look-up 'look-down 'stroll 'help 'quit]
 (walk-rail st a facing move) (: turn (a @ 'turn-left -0.08 'turn-right 0.08 0.0)
   mv (a = 'forward ? 0.35 0.0)
   h (st 'h) tilt (a @ 'look-up (h // 16) 'look-down (0 - h // 16) 0)
   (? (st 'done) st
      (turn != 0.0) (pin st 'th (clamp (st 'th + turn) (0.0 - facing) facing))
      (tilt != 0) (view-hz st (st 'hz + tilt) 4)
      (mv != 0.0) (move st mv)
      (a = 'stroll) (pin st 'walk (st 'walk ? 0 1))
      st))))
