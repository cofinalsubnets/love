(\ egg post (:
 (sit e z a) (? (two? a) (sit e (e (cap a)) (cup a)) z)
 now (clock 0)
 ev (sit (sit ev () egg) () egg)
 _ (pin book 'ev ev)
 _ (sit ev () post)
 _ (pin book 'born (clock now))
 ; the internals move off the book and into a module: the same names, invisible to a
 ; global read. compiled code holds its own references, so once the boot has compiled
 ; the module keeps only the doors a run still asks for by name; the rest -- the cell
 ; doors, the stack and hook doors, the compiler's walkers over them -- leave for good.
 ; nomop leaves every one of them on the book and in the module. the module fills here;
 ; the names leave in `mop`, which a start that loads more first (main.c: the glaze, which
 ; cites ev.l's walkers out of guts) finds under latemop and calls once.
 (ev '(:
   ; keep this list up to date
   m '(cellread seal-hook stack setstack lib enter leave gv trim peek poke pick place seek stem span
       dis disp discell opname opnames nifop spin thrun lamthr lamform threadir nifnom yield ci-vt to-vt macros boxfix boxfix-es bodyless? bpr breads boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs hashtx feels apx iop letc opfixed gone jotfuse numfn nfa nfq nfnest powg fpow ipow tray atype asum aprod alen a-coll a-dim a-emax a-rank a-shape a-type pureset operators seqx sortsplit lidx ldel packp _)
   n (filter (\ k (? (nom? k) (= "lvm_" (snip (string k) 0 4)))) (keys book))
   M (lib ())
   ; the module may already exist: a def row can name it in C (src/love/love.h's LvNif), and
   ; those rows were bound at boot, before any of this. join them rather than replace.
   F (: e (M 'guts) (tablet? e ? e (tablet 0)))
   miss (mint 0)                       ; a roster name that never bound answers this, and is skipped
   (p k) (: v (peep book k miss) (? (== v miss) 0 (pin F k v)))
   _ (each m p)
   _ (each n p)
   _ (pin M 'guts F)
   ; what a run may still cite: the bounded byte doors (src/love/mem.c) and post.l's reading
   ; of a thread -- none reaches a word by address or writes a cell it did not lay
   kept '(peepw pinw peepv pinv threadir)
   ; a book name goes only while it is still the one moved: a later file may bind its own
   (off k) (: v (peep F k miss) (? (== v miss) 0 (== v (peep book k miss)) (pull book k k) 0))
   (mop _) (: _ (pull book 'latemop 0)
              (? (book 'nomop) ()
                 (: _ (each m off) _ (each n off)
                    _ (each (filter (\ k (? (elem k kept) 0 1)) (keys F)) (\ k (pull F k k)))
                    ; raw code addresses: the natives read them through g->reach, not these
                    _ (each '(calloutdrive calloutresume) (\ k (pull book k k)))
                    ())))
   (? (book 'latemop) (pin book 'latemop mop) (mop ()))))))
