(\ egg (:
 (sit e z a) (? a (sit e (e (cap a)) (cbp a)) z)
 now (clock 0)
 _ (pin dict 'ev (sit (sit ev 0 egg) 0 egg))
 ; the scary nifs (raw cell ops), the hot g_vm_* pointers we poke onto texts,
 ; and the macros table's global name are runtime-internal: pull them from
 ; dict before the image is born. (the table itself stays reachable at
 ; dict[0]; references already compiled into the image were folded, not
 ; late-bound.) the sweep runs through the FRESH ev -- c0 is done by now,
 ; and late-binding through dict['ev] is the egg's own idiom.
 _ ((peep dict 'ev 0)
    '(: _ (each '(peek poke seek macros) (\ k (pull dict k 0)))
        (each (keys dict)
         (\ k (? (symp k) (? (= "g_vm_" (slice (string k) 0 5)) (pull dict k 0) 0) 0)))))
 (pin dict 'born (clock now))))
