(\ egg post (:
 (sit e z a) (? (two? a) (sit e (e (cap a)) (cup a)) z)
 now (clock 0)
 ; sit twice so ev compiles itself
 ev (sit (sit ev () egg) () egg)
 _ (pin book 'ev ev)
 _ (sit ev () post)
 _ (pin book 'born (clock now))
 ; the internals move off the book and into a module: the same names, invisible to a
 ; global read, and `(cite 'guts 'opof)` or `(borrow 'guts)` reaches one from a test or a
 ; debug session -- on the baked image too, which is the whole gain over nomop (that
 ; flag can only answer from an unbaked boot). nomop now leaves them on the book as well.
 (ev '(:
   ; keep this list up to date
   m '(cellread seal-hook stack setstack lib enter leave gv trim peek poke pick place seek stem span
       dis disp discell opname opnames nifop spin lamsrc nifnom yield ci-vt to-vt macros boxfix boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs hashtx feels apx iop gone numfn nfa nfq nfnest powg fpow ipow tray atype asum aprod alen a-coll a-dim a-emax a-rank a-shape a-type pureset operators seqx sortsplit lidx ldel packp _)
   n (filter (\ k (? (nom? k) (= "lvm_" (snip (string k) 0 4)))) (keys book))
   M (lib ())
   ; the module may already exist: a def row can name it in C (l/love.h's AiNif), and
   ; those rows were bound at boot, before any of this. join them rather than replace.
   F (: e (peep M 'guts ()) (tablet? e ? e (tablet 0)))
   miss (mint 0)                       ; a roster name that never bound answers this, and is skipped
   keep (book 'nomop)
   (p k) (: v (peep book k miss)
            (? (id? v miss) 0
               (: _ (pin F k v) (? keep 0 (pull book k k)))))
   _ (each m p)
   _ (each n p)
   _ (pin M 'guts F)
   ()))))
