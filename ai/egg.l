(:
 (mop _) ((peep book 'ev 0) '(:
   ; delete interna
   _ (each '(trim peek poke seek spin macros boxfix boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs hashtx qql qqx wevs apx iop do_eval numfn nfa nfq nfnest powg ipow a-coll a-dim a-emax a-rank a-shape a-type m eofsym prc _)
      (\ k (pull book k 0)))
   (each (keys book)
    (\ k (? (symp k) (? (= "lvm_" (slice (string k) 0 4)) (pull book k 0) 0) 0)))))
 (sit e z a) (? (twop a) (sit e (e (cap a)) (cup a)) z)
(\ egg (:
 now (clock 0)
 _ (mop (pin book 'ev (sit (sit ev 0 egg) 0 egg)))
 (pull (pin book 'born (clock now)) 'book 0))))
