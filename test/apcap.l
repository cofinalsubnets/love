; apcap: the numeral count ceiling -- a public tunable box. a compose count or
; exact-power exponent above (apcap 0) raises (scare 'apcap k) instead of
; allocating O(k), so applying a bignum asks for help where it would oom. the box is
; runtime tunable: (pin apcap 0 n). counts at or below the cap are untouched.
(assert (tab? apcap) (= 1048576 (apcap 0)) (= 1048576 (peep apcap 0 0)))

; install a help that answers 'apcap scares with (capped k); anything else
; falls through to whatever was installed before (nil pre-help.l: const-1).
(: apcap-t0 help)
(: help (\ s a b (? (&& (scare? s) (= a 'apcap)) (L 'capped b) (apcap-t0 s a b))))
(assert
 ; a bignum compose count saturates to fix_max, far above the cap -> scares
 (: r ((100 2) (+ 1)) (&& (= 'capped (cap r)) (< 1048576 (caup r))))
 ; the exact-power path is capped too: 2 ** 2^100 would be the boom
 (: r ((100 2) 2) (= 'capped (cap r)))
 ; ... and via a huge negative exponent (the reciprocal still runs ipow)
 (: r ((- 0 (100 2)) 2) (= 'capped (cap r)))
 ; at or below the cap nothing changes
 (= 1024 (10 2)) (= 13 ((3 (+ 1)) 10)) (= 0.5 (-1 2)))

; runtime tunable: drop the cap to 4, watch 5 scare and 4 run, restore.
(pin apcap 0 4)
(assert
 (= 14 ((4 (+ 1)) 10))
 (= 'capped (cap (5 (+ 1))))   ; the scare fires at compose time, mid-curry
 (= 16 (4 2))
 (= 'capped (cap (5 2))))
(pin apcap 0 1048576)
; restore: a missing prior help reads 0 -- exactly the uninstall. (one nothing
; closed the old hole where a ()-saved help reinstalled as the unit.)
(: help apcap-t0)
(assert (= 1048576 (apcap 0)) (= 64 (6 2)) (= 12 ((2 (+ 1)) 10)))
