; src/apps/net/wire.l -- an in-memory link between two sides, lossy by a seeded rng: a frame put
; on one side reaches the other after its delay, or is dropped, duplicated or held back. the
; clock is the caller's, in ms, so a run is the same at any speed
;   (wire-make seed o)      -> a wire; o a tablet of 'drop 'dup 'reorder (per mille), 'delay
;                              and 'jitter (ms, a held-back frame's extra)
;   (wire-put w side f now) frame f leaves side 0 or 1
;   (wire-take w side now)  -> the frames due at side by now, in arrival order
;   (wire-rand w)           -> the rng's next, 1 .. 2147483646; (w 'lost) the frames dropped
(module (wire wire-make wire-put wire-take wire-rand)
(:
   ; park and miller's minimal standard
   (wire-rand w) (w 'x * 48271 % 2147483647 @ x (pin w 'x x, x))
   (wire-make seed o) {'x (seed % 2147483646 + 1) 'n 0 'lost 0 'o o 'q {0 () 1 ()}}
   (opt w k) (peep (w 'o) k 0)
   (roll w pm) (0 < pm && wire-rand w % 1000 < pm)
   ; a queue is (due n frame) rows, by due then by the order put
   (ins l e) (? (atom? l) [e]
                (<l @ [d k _] (e 0 < d || (e 0 = d && e 1 < k)) ? (e . l) (<l . ins >l e)))
   (put1 w to f at) (w 'n + 1 @ n (pin w 'n n, pin (w 'q) to (ins (w 'q to) [at n f])))
   (wire-put w side f now)
    (: to (1 - side)
       at (now + opt w 'delay)
       (? (roll w (opt w 'drop)) (pin w 'lost (w 'lost + 1), 0)
          (put1 w to f (roll w (opt w 'reorder) ? (at + 1 + wire-rand w % max 1 (opt w 'jitter)) at),
           roll w (opt w 'dup) ? (put1 w to f (at + 1)) 0)))
   (wire-take w side now)
    (: (go l acc) (? (atom? l || <l 0 > now) [(rev acc) l] (go >l (<l 2 . acc)))
       r (go (w 'q side) ())
       (pin (w 'q) side (r 1), <r))
)
) ; module wire
