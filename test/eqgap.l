; a function key probed with a nursery all but full: eqv lays its table of function pairs in
; the free room left, and a room too small to hold one pair still walks. love0 has no avail
; floor, so its gap reaches every word count; a love keeps eight and only passes
(: (eqg-ngc _) (gauge 0 @ (_ . _ . _ . n . _) n)
   ; after a collection, whether (iota m) fit uncollected, and the table's answer
   (eqg-try T f m) (please 0 @ n (iota m @ z (peep T f 0 @ v [(eqg-ngc 0 == n && #z == m) v])))
   ; the most that fits with the gauge after it, between a fit lo and a miss hi
   (eqg-most T f lo hi) (lo + 1 < hi ? ((lo + hi) // 2 @ m (<(eqg-try T f m) ? (eqg-most T f m hi) (eqg-most T f lo m))) lo)
   ; past it the gauge's room goes, so the room the probe meets walks down to none
   (eqg-up T f m e) (m > e ? 'done (eqg-try T f m @ [_ v] (v == 'one ? (eqg-up T f (m + 1) e) m)))
   eqg-t (pin {} (\ y (y + 1)) 'one)
   eqg-f (\ y (y + 1))
   eqg-m (eqg-most eqg-t eqg-f 0 1048576)
 (test ('done = eqg-up eqg-t eqg-f eqg-m (eqg-m + 128))))
