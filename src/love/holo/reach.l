; reach -- what a link can reach. a unit is a name and the names it names; the live units are
; the roots and everything a live unit names, to the fixed point. no format in it: a link
; states its units, its roots and what it always keeps (as roots), and lays the live ones.
;   (reach units roots)       units ((name ref ..) ..), roots (name ..) -> a tablet, live name -> 1
;   (reach-keep units live)   the live units, in the order they came
; a name no unit carries is nobody's to keep and is passed over: the link says what is undefined

(module 'holo

(: (reach units roots)
    (: refs {} have {} live {}
       _ (map (u \ (pin have <u 1, pin refs <u >u)) units)
       (go work)
        (work @- live
         (n . rest) (? (peep live n 0 || !(peep have n 0)) (go rest)
                       (pin live n 1, go (peep refs n () + rest))))
       (go roots))
   (reach-keep units live) (filter (u \ peep live <u 0) units))
) ; module 'holo
