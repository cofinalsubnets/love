(\ egg (:
 ; pre egg hatch cleanup routine
 (mop _) ((peep book 'ev 0) '(:
   _ (each '(peek poke seek lamb macros boxfix boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs hashtx qql qqx wevs apx iop do_eval numfn nfa nfq nfnest powg ipow a-coll a-dim a-emax a-rank a-shape a-type m eofsym prc _)
      (\ k (pull book k 0)))
   (each (keys book)
    (\ k (? (symp k) (? (= "lvm_" (slice (string k) 0 4)) (pull book k 0) 0) 0)))))
 (sit e z a) (? (twop a) (sit e (e (cap a)) (cbp a)) z)

 now (clock 0)
 _ (mop (pin book 'ev (sit (sit ev 0 egg) 0 egg)))
 ; runtime-internal names die before the image is born: the raw cell ops,
 ; the compiler's own machinery (boxfix, wev, the num-ap and array-ctor
 ; helpers, the macro expanders -- the macro TABLE lives on inside the
 ; compiler's closures), the repl's sentinels, every leaked lvm_* pointer,
 ; and finally book itself. compiled references were folded, so only the
 ; names die; an absent name reads as nil. names the printer or an expander
 ; EMITS (uq ltuple cons pin table ...) stay, as do the C-resolved hooks
 ; (num-ap scomb bcomb trap) and the repl's test-driven editor surface.
 ; the sweep runs through the FRESH ev -- c0 is done by now, and
 ; late-binding through book['ev] is the egg's own idiom.
 (pull (pin book 'born (clock now)) 'book 0)))
