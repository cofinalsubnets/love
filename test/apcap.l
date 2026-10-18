; apcap: the numeral ceiling, (pin apcap 0 n) retunes. a compose count past it scares;
; a power scares only when ~k*log2|b| result bits top it read as words
(test (tablet? apcap) (1048576 = apcap 0) (1048576 = peep apcap 0 0))

; a help answering 'apcap scares with (capped k); the rest falls through to the prior one
(: apcap-t0 (heard ()))
(hear (a \ b \ a @ 'apcap ['capped b] (apcap-t0 a b)))
(test
 ; a bignum compose count saturates to maxcharm, far above the cap -> scares
 (((100 2) (+ 1)) @ r ('capped = <r && (1048576 < <>r)))
 ; 2 ** 2^100 would be the boom: ~2^100 result bits top the word budget
 (((100 2) 2) @ r ('capped = <r))
 ; ... and via a huge negative exponent (the reciprocal still runs ipow)
 (((0 - (100 2)) 2) @ r ('capped = <r))
 ; growthless bases run free at the same exponent: +-1, 0, and any gem
 (1 = 100 2 1) (0 = 100 2 0) (1 = 100 2 -1) (1.0 = 100 2 1.0)
 (1048576 < 25 2 2.0)      ; a gem base never scares -- it just rides to inf
 ; a deliberate big power fits the word budget: 2^(2^21)
 (0 < 21 2 2)
 ; at or below the cap nothing changes
 (1024 = 10 2) (13 = 3 (+ 1) 10) (0.5 = -1 2))

; cap 4: compose 5 scares; a power only past 4 words (256 bits)
(pin apcap 0 4)
(test
 (14 = 4 (+ 1) 10)
 ('capped = <(5 (+ 1)))   ; the scare fires at compose time, mid-curry
 (16 = 4 2)
 (32 = 5 2)            ; over the count, under the budget: runs
 ('capped = <(300 2)) ; ~300 result bits top 256
 (1 = 300 1))          ; growthless still free under a tiny box
(pin apcap 0 1048576)
; restore: a missing prior help reads 0, exactly the uninstall
(hear apcap-t0)
(test (1048576 = apcap 0) (64 = 6 2) (12 = 2 (+ 1) 10))
