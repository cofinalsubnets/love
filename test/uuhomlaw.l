; test/uuhomlaw.l -- the destination-die laws, proved of uuhomgen.l's lifted terms
; guard: substrate + generated terms must load first; fail by name if not.
(test (elem 'vof (names ())) (two? (peep GLOB 'drun 0)) (two? (peep GLOB 'ds1ck 0)))

; --- the member store & the home write collapse: one si, one alu ---
(test
 (defq dl-onesi
   (paths nlist ds1ck (ncons 4 (ncons 18 (ncons 1 (ncons 15 nnil)))))
   (idpath ds1ck))
 (defq dl-onealu (paths nat (nlen ds2ck) 4) (idpath 4)))

; --- and the collapse is sound: the home write lands the same r8, forall states ---
(test
 (defq dl-mig-asn
   (pi R hst (pi F hst (pi K hst
      (paths nat (mrg (drun ds2ck (mmk R F K 0)) 8)
                 (mrg (drun ds2cv (mmk R F K 0)) 8)))))
   (lam R (lam F (lam K (idpath (mrg (drun ds2ck (mmk R F K 0)) 8)))))))

; --- control destinations: ck branches off the compares, cv reifies via set ---
(test
 (defq dl-noset (paths bool (memb 8 (opsof ds3ck)) false)
   (idpath false))
 (defq dl-cvset (paths bool (memb 8 (opsof ds3cv)) true)
   (idpath true)))

; --- the tail: ck's emission ends in jmp (the sibcall), cv's in call;ret ---
(test
 (defq dl-tailjmp (paths nat (pr1 (pr2 (lrev (opsof ds4ck)))) 10)
   (idpath 10))
 (defq dl-cvret (paths nat (pr1 (pr2 (lrev (opsof ds4cv)))) 13)
   (idpath 13))
 (defq dl-cvcall (paths nat (pr1 (pr2 (pr2 (lrev (opsof ds4cv))))) 12)
   (idpath 12)))

; --- and the arg seats agree before either transfer, forall states ---
(test
 (defq dl-seat6
   (pi R hst (pi F hst (pi K hst
      (paths nat (mrg (drun ds4ckargs (mmk R F K 0)) 6)
                 (mrg (drun ds4cvargs (mmk R F K 0)) 6)))))
   (lam R (lam F (lam K (idpath (mrg (drun ds4ckargs (mmk R F K 0)) 6))))))
 (defq dl-seat5
   (pi R hst (pi F hst (pi K hst
      (paths nat (mrg (drun ds4ckargs (mmk R F K 0)) 5)
                 (mrg (drun ds4cvargs (mmk R F K 0)) 5)))))
   (lam R (lam F (lam K (idpath (mrg (drun ds4ckargs (mmk R F K 0)) 5)))))))

; --- the degenerate die: a leaf under () compiles byte-for-byte as cv does ---
(test
 (defq dl-lane-k (paths nlist de5kcv de5kck) (idpath de5kck))
 (defq dl-lane-v (paths nlist de5vcv de5vck) (idpath de5vck)))

; --- a compound under a die only improves: same r0 forall states, fewer forms ---
(test
 (defq dl-mig-bin
   (pi R hst (pi F hst (pi K hst
      (paths nat (mrg (drun de5bck (mmk R F K 0)) 0)
                 (mrg (drun de5bcv (mmk R F K 0)) 0)))))
   (lam R (lam F (lam K (idpath (mrg (drun de5bck (mmk R F K 0)) 0))))))
 (defq dl-fewer (paths bool (natgtb (nlen de5bcv) (nlen de5bck)) true)
   (idpath true)))
