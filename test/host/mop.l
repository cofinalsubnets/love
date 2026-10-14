; test/host/mop.l -- what the mop takes off a baked image, and what nomop keeps
; a baked run holds no door that reads or writes a word by address, lays a thread cell,
; or swaps the scope stack or a core hook: the boot's compiled code keeps its own
; references and the names leave the `guts` module for good (src/love/boot/egg.l). the
; bounded byte doors and threadir stay; the glaze cited what it reads before the mop ran.
; an unbaked boot under LOVE_NO_MOP keeps every one, on the book and in the module.
;   cat test/00-init.l test/host/mop.l | out/love
(: mop-G (cite 'guts)
   mop-gone '(peek poke pick place seek spin stem span trim cellread stack setstack
              seal-hook lib enter leave yield dis disp discell opname nifnom ci-vt to-vt
              numfn nfq nfa lamform macros boxset lvm_ret lvm_quote
              gv nifop letc opfixed jotfuse defercell deferpatch)
   mop-kept '(peepw pinw peepv pinv threadir)
   (mop-has k) (mop-G k !== ())
   (mop-on-book k) (elem k (names ()))

   ; the baked image: every dropped name answers the miss, off the module and the book
   _ (test (tablet? mop-G)
           (all (k \ !(mop-has k)) mop-gone)
           (all (k \ !(mop-on-book k)) mop-gone)
           (all mop-has mop-kept)
           (sort (filter nom? (keys mop-G)) = sort mop-kept)
           !(mop-on-book 'calloutdrive) !(mop-on-book 'calloutresume) !(mop-on-book 'latemop))

   ; a love module over a C one joins its rows: gif.l exports gif-frame and not gif-clear, and
   ; both stay in the module, on the image (its crew) and on an egg boot that reads it
   gq "_ (putx [(? (cite 'gif 'gif-clear) 1 0) (? (cite 'gif 'gif-frame) 1 0) (? (cite 'gif 'gif-encode) 1 0)]) (quit 0))"
   gw (hark ["out/love" "-e" ("(: " + gq)])
   ge (hark ["env" "LOVE_NO_IMAGE=1" "out/love" "-e" ("(: _ (borrow \"src/apps/gif.l\") " + gq)])
   _ (test (two? gw) (<gw = 0) (>gw = "(1 1 1)") (two? ge) (<ge = 0) (>ge = "(1 1 1)"))

   ; the doors that segfaulted from a script now answer (), as any missing name's value does
   _ (test (() = (cite 'guts 'peek) 100000000000 "abc")
           (() = (cite 'guts 'poke) 100000 7 "abc")
           (() = (cite 'guts 'place) 0 1 "abc"))

   ; the glaze's deferred cells, under nomop: a bad operand answers (), never a fault, and a
   ; good cell forwards to its twin while nothing of its shape and arity patches it
   dq "(: dc (cite 'guts 'defercell) dp (cite 'guts 'deferpatch) L (dc (+) 2) M (dc (x \\ x * 2) 1) _ (putx [(dp 1 2) (dc 5 1) (dc (+) 3) (dc (x \\ x) 0) (dp (+) (+)) (? (L == dp L (-)) 1 0) (? (L == dp L 7) 1 0) (L 3 4) (? (M == dp M L) 1 0) (map M [1 2])]) (quit 0))"
   dl (hark ["env" "LOVE_NO_IMAGE=1" "LOVE_NO_MOP=1" "out/love" "-e" dq])
   _ (test (two? dl) (<dl = 0) (>dl = "(() () () () () 1 1 7 1 (2 4))"))

   ; the bounded byte doors still answer, and still hold their bounds
   _ (: c (cask 16) pinw (mop-G 'pinw) peepw (mop-G 'peepw)
        (test (c = pinw c 1 77) (77 = peepw c 1)
              (() = peepw c 2) (() = peepw c 2305843009213693953) (() = pinw c -1 5)))

   ; the lane the doors come back on: an unbaked boot with LOVE_NO_MOP keeps them, and one
   ; without it mops the same as the bake did
   ask "(: G (cite 'guts) _ (putx [(? (G 'peek) 1 0) (? (G 'setstack) 1 0) (? (elem 'poke (names ())) 1 0) (? (elem 'calloutdrive (names ())) 1 0)]) (quit 0))"
   kept (hark ["env" "LOVE_NO_IMAGE=1" "LOVE_NO_MOP=1" "out/love" "-e" ask])
   mopped (hark ["env" "LOVE_NO_IMAGE=1" "out/love" "-e" ask])
   (test (two? kept) (<kept = 0) (>kept = "(1 1 1 1)")
         (two? mopped) (<mopped = 0) (>mopped = "(0 0 0 0)"),

    test_fin (),
    puts "mop: ok\n"))
