(\ egg post (:
 (sit e z a) (? (two? a) (sit e (e (cap a)) (cup a)) z)
 now (clock 0)
 ; sit twice so ev compiles itself
 ev (sit (sit ev () egg) () egg)
 _ (pin book 'ev ev)
 _ (sit ev () post)
 _ (pin book 'born (clock now))
 (? (book 'nomop) ()
  (ev '(: ; mop internal names
   ; keep this list up to date
   m '(cellread seal-hook books setbooks mods lib enter leave gv trim peek poke seek spin lamsrc nifnom yield ci-vt to-vt macros boxfix boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs hashtx feels apx iop gone numfn nfa nfq nfnest powg fpow ipow tray atype asum aprod alen a-coll a-dim a-emax a-rank a-shape a-type pureset operators seqx sortsplit lidx ldel packp _)
   n (filter (\ k (? (nom? k) (= "lvm_" (snip (string k) 0 4)))) (keys book))
   (p k) (pull book k k)
   _ (each m p)
   _ (each n p)
   ())))))
