; tray orderings with collections landing inside them: every mask is all ones, tray on either side.
; the budget drops to twice the live set so the nursery is small; the last law checks gcs happened
(: ord-knobs (tune ())
   _ (please 1)
   _ (tune (pin (tune ()) 0 (2 * peep (gauge 0) 8 0)))
   _ (please 1)
   ord-m0 (peep (gauge 0) 3 0)
   ord-n 1600
   ord-reps 400
   ; built once, so nearly every word taken after is a comparison's mask
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
