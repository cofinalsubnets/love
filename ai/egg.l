(:
 (mop _) ((peep bag 'ev 0) '(:
   ; delete internal names. keep this up to date!
   ; NB: the old repl internals (do_eval m eofsym prc + the ed* editor) USED to be
   ; mopped here -- they are now CLOSURE-PRIVATE inside ai/bao.l (the shell core), so
   ; they never reach the bag and need no mop entry.
   _ (each '(trim peek poke seek spin macros boxfix boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs hashtx qql qqx wevs apx iop numfn nfa nfq nfnest powg power ipow a-coll a-dim a-emax a-rank a-shape a-type op-fr op-fold op-frg op-frd op-frn op-frc op-fro op-fin op-ent op-del op-core op-steal op-drain op-w op-qq op-long op-puncp op-punc-byte opfactor monofactor mono-long seqx sortsplit lidx ldel eat1 eat2 packp _)
      (\ k (pull bag k 0)))
   (each (keys bag)
    (\ k (? (nom? k) (? (= "lvm_" (snip (string k) 0 4)) (pull bag k 0) 0) 0)))))
 (sit e z a) (? (two? a) (sit e (e (cap a)) (cup a)) z)
(\ egg (:
 now (clock 0)
 _ (mop (pin bag 'ev (sit (sit ev 0 egg) 0 egg)))
 (pull (pin bag 'born (clock now)) 'bag 0))))
