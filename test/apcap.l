; apcap: the numeral count ceiling -- a public tunable box. a compose count or
; exact-power exponent above (apcap ()) raises (scare 'apcap k) instead of
; allocating O(k), so applying a bignum asks for help where it would oom. the box is
; runtime tunable: (pin apcap () n). counts at or below the cap are untouched.
(assert (mapp apcap) (= 1048576 (apcap ())) (= 1048576 (peep apcap () 0)))

; install a help that answers 'apcap scares with (capped k); anything else
; falls through to whatever was installed before (nil pre-help.l: const-1).
(: apcap-t0 help)
(: help (\ s a b (? (&& (scare? s) (= a 'apcap)) (L 'capped b) (apcap-t0 s a b))))
(assert
 ; a bignum compose count saturates to fix_max, far above the cap -> scares
 (: r ((100 2) (+ 1)) (&& (= 'capped (cap r)) (< 1048576 (cabp r))))
 ; the exact-power path is capped too: 2 ** 2^100 would be the boom
 (: r ((100 2) 2) (= 'capped (cap r)))
 ; ... and via a huge negative exponent (the reciprocal still runs ipow)
 (: r ((- 0 (100 2)) 2) (= 'capped (cap r)))
 ; at or below the cap nothing changes
 (= 1024 (10 2)) (= 13 ((3 (+ 1)) 10)) (= 0.5 (-1 2)))

; runtime tunable: drop the cap to 4, watch 5 scare and 4 run, restore.
(pin apcap () 4)
(assert
 (= 14 ((4 (+ 1)) 10))
 (= 'capped (cap (5 (+ 1))))   ; the scare fires at compose time, mid-curry
 (= 16 (4 2))
 (= 'capped (cap (5 2))))
(pin apcap () 1048576)
; restore. a missing prior help was saved as (), which would reinstall as the
; unit (a lamp -- every missing read downstream would answer 1): the uninstall
; is help = 0, a non-lamp, per the contract in help.l/missing.l.
(: help (? apcap-t0 apcap-t0 0))
(assert (= 1048576 (apcap ())) (= 64 (6 2)) (= 12 ((2 (+ 1)) 10)))
