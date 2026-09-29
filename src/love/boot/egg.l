(\ egg post (:
 (sit e z a) (? (two? a) (sit e (e (cap a)) (cup a)) z)
 now (clock 0)
 ; p1 is live already (c0 read it in): the twice-sat half is the rest, and p1 is
 ; compiled once by the ev that came out, ahead of post
 ev (sit (sit ev () (cup egg)) () (cup egg))
 _ (pin book 'ev ev)
 _ (ev (cap egg))
 _ (sit ev () post)
 _ (pin book 'born (clock now))
 ; the internals move off the book and into a module: the same names, invisible to a
 ; global read. compiled code holds its own references, so once the boot has compiled
 ; the module keeps only the doors a run still asks for by name; the rest -- the cell
 ; doors, the stack and hook doors, the compiler's walkers over them -- leave for good.
 ; nomop leaves every one of them on the book and in the module.
 (ev '(:
   ; keep this list up to date
   m '(cellread seal-hook stack setstack lib enter leave gv trim peek poke pick place seek stem span
       dis disp discell opname opnames nifop spin lamform nifnom yield ci-vt to-vt macros boxfix boxfix-es bodyless? bpr breads boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs hashtx feels apx iop letc opfixed gone numfn nfa nfq nfnest powg fpow ipow tray atype asum aprod alen a-coll a-dim a-emax a-rank a-shape a-type pureset operators seqx sortsplit lidx ldel packp _)
   n (filter (\ k (? (nom? k) (= "lvm_" (snip (string k) 0 4)))) (keys book))
   M (lib ())
   ; the module may already exist: a def row can name it in C (src/love/love.h's LvNif), and
   ; those rows were bound at boot, before any of this. join them rather than replace.
   F (: e (M 'guts) (tablet? e ? e (tablet 0)))
   miss (mint 0)                       ; a roster name that never bound answers this, and is skipped
   keep (book 'nomop)
   (p k) (: v (peep book k miss)
            (? (== v miss) 0
               (: _ (pin F k v) (? keep 0 (pull book k k)))))
   _ (each m p)
   _ (each n p)
   ; what a baked run may still cite: the bounded byte doors (src/love/mem.c) and the glaze's
   ; reads of ev.l -- none reaches a word by address or writes a cell
   kept '(peepw pinw peepv pinv gv nifop letc opfixed)
   _ (? keep 0 (each (filter (\ k (? (elem k kept) 0 1)) (keys F)) (\ k (pull F k k))))
   ; raw code addresses: the natives read them through g->reach, not these
   _ (? keep 0 (each '(calloutdrive calloutresume) (\ k (pull book k k))))
   _ (pin M 'guts F)
   ()))))
