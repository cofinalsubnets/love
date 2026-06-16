(\ egg (:
 ; pre egg hatch cleanup routine
 (mop _) ((peep book 'ev 0) '(:
   ; the non-lvm_ internals to retract (each verified live 2026-06-16); the lvm_*
   ; pointers are caught by the keys-of-book loop below, so they stay off this list.
   _ (each '(trim peek poke seek spin macros boxfix boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs hashtx qql qqx wevs apx iop do_eval numfn nfa nfq nfnest powg ipow a-coll a-dim a-emax a-rank a-shape a-type m eofsym prc _)
      (\ k (pull book k 0)))
   (each (keys book)
    (\ k (? (symp k) (? (= "lvm_" (slice (string k) 0 4)) (pull book k 0) 0) 0)))))
 (sit e z a) (? (twop a) (sit e (e (cap a)) (cup a)) z)

 now (clock 0)
 _ (mop (pin book 'ev (sit (sit ev 0 egg) 0 egg)))
 ; runtime-internal names die before the image is born -- raw cell ops, the compiler's
 ; machinery (boxfix/wev/num-ap/array-ctor helpers; the macro TABLE lives on in the
 ; compiler's closures), the repl sentinels, every leaked lvm_* pointer, finally book.
 ; refs were folded, so only the names die (an absent name reads nil); names the printer
 ; or expanders EMIT (uq cons pin tablet mono ...) and the C-resolved hooks (num-ap add
 ; mul help) stay. the sweep runs through the FRESH ev (c0 is done) -- the egg's own idiom.
 (pull (pin book 'born (clock now)) 'book 0)))
