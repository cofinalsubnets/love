(\ egg (:
 (sit e z a) (? (twop a) (sit e (e (cap a)) (cbp a)) z)
 now (clock 0)
 _ (pin dict 'ev (sit (sit ev 0 egg) 0 egg))
 ; runtime-internal names die before the image is born: the raw cell ops,
 ; the compiler's own machinery (boxfix, wev, the num-ap and array-ctor
 ; helpers, the macro expanders -- the macro TABLE lives on inside the
 ; compiler's closures), the repl's sentinels, every leaked g_vm_* pointer,
 ; and finally dict itself. compiled references were folded, so only the
 ; names die; an absent name reads as nil. names the printer or an expander
 ; EMITS (uq ltuple cons pin table ...) stay, as do the C-resolved hooks
 ; (num-ap scomb bcomb trap) and the repl's test-driven editor surface.
 ; the sweep runs through the FRESH ev -- c0 is done by now, and
 ; late-binding through dict['ev] is the egg's own idiom.
 _ ((peep dict 'ev 0)
    '(: _ (each '(peek poke seek lamb tally macros
                  boxfix boxfix-core boxset cellbinds dsug lambp lp ln w wl mkcs
                  hashtx qql qqx wevs apx iop do_eval
                  numfn nfa nfq nfnest powg ipow
                  a-coll a-dim a-emax a-rank a-shape a-type
                  m eofsym prc _)
            (\ k (pull dict k 0)))
        (each (keys dict)
         (\ k (? (symp k) (? (= "g_vm_" (slice (string k) 0 5)) (pull dict k 0) 0) 0)))))
 _ (pin dict 'born (clock now))
 (pull dict 'dict 0)))
