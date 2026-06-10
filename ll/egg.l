(\ egg (:
 (sit e z a) (? a (sit e (e (A a)) (B a)) z)
 now (clock 0)
 ev (sit (sit ev 0 egg) 0 egg)
 _ (pin dict 'ev ev)
 (pin dict 'born-at (clock now))))
