; walk -- a body walking in first person. a state holds 'px 'pz where it stands, 'th its
; bearing (radians from north toward east) and 'ph how far it looks up.
;   (walk-key st a g put)    view's turn, step and look actions, as far as g {'turn 'walk 'tilt
;                            'up 'down} says; (put st x z) moves it. () for any other action
;   (walk-look st dx dy g)   the mouse's dx dy pixels: turned g 'mouse radians a pixel right,
;                            looked up as far down, within g 'up and 'down
;   (walk-slide st x z free?)  to x z where free?, else along x alone, else z alone, else nowhere
;   (walk-dt st)             'dt the seconds since the last frame, 0.02..0.25, 'wall its clock
;   (walk-rail st a facing move)  on a rail: turns within facing of ahead, 'forward by
;                            (move st d), never back; 'stroll toggles 'walk; none once 'done
(module (walk walk-key walk-look walk-slide walk-dt walk-rail walk-binds walk-listed)
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
 (walk-look st dx dy g) (: k (g 'mouse)
   (pins st 'th (wrap (st 'th + k * dx)) 'ph (clamp (st 'ph - k * dy) (g 'down) (g 'up))))
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
