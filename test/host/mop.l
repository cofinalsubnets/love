; --- test/host/mop.l: what the mop takes off a baked image, and what nomop keeps ---
; a baked run holds no door that reads or writes a word by address, lays a thread cell,
; or swaps the scope stack or a core hook: the boot's compiled code keeps its own
; references and the names leave the `guts` module for good (src/love/boot/egg.l). the
; bounded byte doors and the glaze's reads of ev.l stay. an unbaked boot under
; LOVE_NO_MOP keeps every one, on the book and in the module.
;   cat test/00-init.l test/host/mop.l | out/love
(: mop-G (cite 'guts)
   mop-gone '(peek poke pick place seek spin stem span trim cellread stack setstack
              seal-hook lib enter leave yield dis disp discell opname nifnom ci-vt to-vt
              numfn nfq nfa lamform macros boxset lvm_ret lvm_quote)
   mop-kept '(peepw pinw peepv pinv gv nifop letc opfixed)
   (mop-has k) (mop-G k !== ())
   (mop-on-book k) (elem k (names ()))

   ; the baked image: every dropped name answers the miss, off the module and the book
   _ (test (tablet? mop-G)
           (all (k \ !(mop-has k)) mop-gone)
           (all (k \ !(mop-on-book k)) mop-gone)
           (all mop-has mop-kept)
           !(mop-on-book 'calloutdrive) !(mop-on-book 'calloutresume))

   ; the doors that segfaulted from a script now answer (), as any missing name's value does
   _ (test (() = (cite 'guts 'peek) 100000000000 "abc")
           (() = (cite 'guts 'poke) 100000 7 "abc")
           (() = (cite 'guts 'place) 0 1 "abc"))

   ; the bounded byte doors still answer, and still hold their bounds
   _ (: c (cask 16) pinw (mop-G 'pinw) peepw (mop-G 'peepw)
        (test (c = pinw c 1 77) (77 = peepw c 1)
              (() = peepw c 2) (() = peepw c 2305843009213693953) (() = pinw c -1 5)))

   ; the lane the doors come back on: an unbaked boot with LOVE_NO_MOP keeps them, and one
   ; without it mops the same as the bake did
   ask "(: G (cite 'guts) _ (putx [(? (G 'peek) 1 0) (? (G 'setstack) 1 0) (? (elem 'poke (names ())) 1 0) (? (elem 'calloutdrive (names ())) 1 0)]) (quit 0))"
   kept (hark ["env" "LOVE_NO_IMAGE=1" "LOVE_NO_MOP=1" "out/love" "-e" ask])
   mopped (hark ["env" "LOVE_NO_IMAGE=1" "out/love" "-e" ask])
   _ (test (two? kept) (<kept = 0) (>kept = "(1 1 1 1)")
           (two? mopped) (<mopped = 0) (>mopped = "(0 0 0 0)"))

   _ (test_fin ())
   (puts "mop: ok\n"))
