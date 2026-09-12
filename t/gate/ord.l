; t/gate/ord.l -- the four orderings on a tray, asked with the collector running inside
; them. every element of t lies strictly between lo and hi, so each mask below is all
; ones and a wrong answer is not a rounding question; and each ordering is asked with
; the tray on either side, since an implementation may reach one case through another.
; THE SMALL BUDGET IS THE POINT: what is being asked is what a comparison answers when
; a collection lands in the middle of it, and at a roomy heap that case is too rare to
; be a law. `make test_ord` sets it, and the fast gate runs that.
(: n 1600
   reps 400
   lo -1.0
   hi 1.2
   ; t is built once, so from here nearly every word taken is the mask the comparison
   ; makes -- which is what puts the collection inside it rather than beside it
   t ((iota n) * 0.00002)
   (sweep nm f)
    (: (go k bad) (? (reps <= k) bad
                     (go (k + 1) (? (n = net (f t)) bad (bad + 1))))
       b (go 0 0)
       _ (? (0 < b) (puts ("FAIL ord: " + nm + " wrong in " + show b
                           + " chunks of " + show reps + "\n")) ())
       b)
   bad (net [(sweep "t < hi"  (\ t (t < hi)))
             (sweep "t <= hi" (\ t (t <= hi)))
             (sweep "t > lo"  (\ t (t > lo)))
             (sweep "t >= lo" (\ t (t >= lo)))
             (sweep "lo < t"  (\ t (lo < t)))
             (sweep "lo <= t" (\ t (lo <= t)))
             (sweep "hi > t"  (\ t (hi > t)))
             (sweep "hi >= t" (\ t (hi >= t)))])
   _ (? (0 < bad) ()
        (puts "  ord: ok -- the four orderings on a tray, either way round, under the collector\n"))
   (quit (0 < bad ? 1 0)))
