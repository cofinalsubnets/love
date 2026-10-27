(\ egg post (:
 (sit e z a) (? (two? a) (sit e (e (cap a)) (cup a)) z)
 now (clock 0)
 ev (sit (sit ev () egg) () egg)
 _ (pin book 'ev ev)
 _ (sit ev () post)
 _ (pin book 'born (clock now))
 ; the internals move off the book into the guts module. compiled code holds its own
 ; references, so after the boot the module keeps only `kept`; the rest leave for good.
 ; nomop keeps them all. a start that loads more first finds `mop` under latemop
 (ev '(:
   m '(cellread seal-hook stack setstack lib enter leave gv trim peek poke pick place seek stem span
       dis disp discell opname opnames nifop spin thrun lamthr lamform threadir nifnom yield ci-vt to-vt macros boxfix boxfix-es bodyless? bpr breads boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs hashtx feels apx iop letc opfixed gone jotfuse numfn nfa nfq nfnest powg fpow ipow tray atype asum aprod alen a-coll a-dim a-emax a-rank a-shape a-type pureset operators seqx lidx ldel _)
   n (filter (\ k (? (nom? k) (= "lvm_" (snip (string k) 0 4)))) (keys book))
   M (lib ())
   ; the module may already hold rows bound from C at boot: join them, don't replace
   F (: e (M 'guts) (tablet? e ? e (tablet 0)))
   miss (mint 0)                       ; a roster name that never bound answers this, and is skipped
   (p k) (: v (peep book k miss) (? (== v miss) 0 (pin F k v)))
   _ (each m p)
   _ (each n p)
   _ (pin M 'guts F)
   ; what a run may still cite: none reaches a word by address or writes a cell it did not lay
   kept '(peepw pinw peepv pinv threadir)
   ; a book name goes only while it is still the one moved: a later file may bind its own
   (off k) (: v (peep F k miss) (? (== v miss) 0 (== v (peep book k miss)) (pull book k k) 0))
   (mop _) (: _ (pull book 'latemop 0)
              (? (book 'nomop) ()
                 (: _ (each m off) _ (each n off)
                    _ (each (filter (\ k (? (elem k kept) 0 1)) (keys F)) (\ k (pull F k k)))
                    ; raw code addresses: natives read them through g->reach
                    _ (each '(calloutdrive calloutresume) (\ k (pull book k k)))
                    ())))
   (? (book 'latemop) (pin book 'latemop mop) (mop ()))))))
