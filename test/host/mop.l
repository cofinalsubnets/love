; test/host/mop.l -- the mop drops the raw-address and scope-stack doors from a baked image's
; book and `guts` (src/love/boot/egg.l); bounded byte doors stay; LOVE_NO_MOP keeps them all.
;   cat test/00-init.l test/host/mop.l | out/love
(: mop-G (cite 'guts)
   mop-gone '(peek poke pick place seek spin stem span trim cellread stack setstack
              seal-hook lib enter leave yield dis disp discell opname nifnom ci-vt to-vt
              numfn nfq nfa lamform macros boxset lvm_ret lvm_quote)
   mop-kept '(peepw pinw peepv pinv gv nifop letc opfixed defercell deferpatch)
   (mop-has k) (mop-G k !== ())
   (mop-on-book k) (elem k (names ()))

   _ (test (tablet? mop-G)
           (all (k \ !(mop-has k)) mop-gone)
           (all (k \ !(mop-on-book k)) mop-gone)
           (all mop-has mop-kept)
           !(mop-on-book 'calloutdrive) !(mop-on-book 'calloutresume))

   ; a dropped door answers (), as any missing name does
   _ (test (() = (cite 'guts 'peek) 100000000000 "abc")
           (() = (cite 'guts 'poke) 100000 7 "abc")
           (() = (cite 'guts 'place) 0 1 "abc"))

   ; deferred cells: a bad operand answers (); a cell forwards until a same-arity patch
   _ (test !(mop-on-book 'defercell) !(mop-on-book 'deferpatch))
   dq "(: dc (cite 'guts 'defercell) dp (cite 'guts 'deferpatch) L (dc (+) 2) M (dc (x \\ x * 2) 1) _ (putx [(dp 1 2) (dc 5 1) (dc (+) 3) (dc (x \\ x) 0) (dp (+) (+)) (? (L == dp L (-)) 1 0) (? (L == dp L 7) 1 0) (L 3 4) (? (M == dp M L) 1 0) (map M [1 2])]) (quit 0))"
   dl (hark ["env" "LOVE_NO_IMAGE=1" "LOVE_NO_MOP=1" "out/love" "-e" dq])
   _ (test (two? dl) (<dl = 0) (>dl = "(() () () () () 1 1 7 1 (2 4))"))

   _ (: c (cask 16) pinw (mop-G 'pinw) peepw (mop-G 'peepw)
        (test (c = pinw c 1 77) (77 = peepw c 1)
              (() = peepw c 2) (() = peepw c 2305843009213693953) (() = pinw c -1 5)))

   ; unbaked: LOVE_NO_MOP keeps the doors, and without it they mop as baked
   ask "(: G (cite 'guts) _ (putx [(? (G 'peek) 1 0) (? (G 'setstack) 1 0) (? (elem 'poke (names ())) 1 0) (? (elem 'calloutdrive (names ())) 1 0)]) (quit 0))"
   kept (hark ["env" "LOVE_NO_IMAGE=1" "LOVE_NO_MOP=1" "out/love" "-e" ask])
   mopped (hark ["env" "LOVE_NO_IMAGE=1" "out/love" "-e" ask])
   (test (two? kept) (<kept = 0) (>kept = "(1 1 1 1)")
         (two? mopped) (<mopped = 0) (>mopped = "(0 0 0 0)"),

    test_fin (),
    puts "mop: ok\n"))
