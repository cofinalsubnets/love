; the four orderings on a tray, asked with the collector running inside them. every
; element of ord-t lies strictly between lo and hi, so each mask is all ones and a wrong
; answer is not a rounding question; each ordering is asked with the tray on either side,
; since an implementation may reach one case through another. THE SMALL NURSERY IS THE
; POINT: at a roomy one a collection lands inside a comparison too rarely to be a law, so
; the budget goes to twice the live set -- the nursery drops to its floor -- for the sweeps,
; and back after. the last law holds the collections to having happened
(: ord-knobs (tune ())
   _ (please 1)
   _ (tune (pin (tune ()) 0 (2 * peep (gauge 0) 8 0)))
   _ (please 1)
   ord-m0 (peep (gauge 0) 3 0)
   ord-n 1600
   ord-reps 400
   ; ord-t is built once, so from here nearly every word taken is the mask a comparison
   ; makes -- which is what puts the collection inside it rather than beside it
   ord-t ((iota ord-n) * 0.00002)
   (ord-ok f) (: (go k) (? (ord-reps <= k) 1 (ord-n = net (f ord-t)) (go (k + 1)) 0) (go 0))
   ord-lo -1.0
   ord-hi 1.2
   _ (test (ord-ok (\ t (t < ord-hi)))
           (ord-ok (\ t (t <= ord-hi)))
           (ord-ok (\ t (t > ord-lo)))
           (ord-ok (\ t (t >= ord-lo)))
           (ord-ok (\ t (ord-lo < t)))
           (ord-ok (\ t (ord-lo <= t)))
           (ord-ok (\ t (ord-hi > t)))
           (ord-ok (\ t (ord-hi >= t))))
   ord-gcs (peep (gauge 0) 3 0 - ord-m0)
   _ (tune ord-knobs)
   _ (please 1)
   (test (100 < ord-gcs)))
