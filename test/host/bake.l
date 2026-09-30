; test/host/bake.l -- the bake nif: (bake path) snapshots the live session mid-eval, and
; `love wake PATH prog.l` boots a session carrying every global pinned before it.
; run: cat test/00-init.l test/host/bake.l | out/love
; the marker the woken child reads back: a bodiless top-level `:`, so it is a global the
; snapshot carries, where a binding in the bodied `:` below would be local.
(: bake-smoke-marker 4242)

; the dump hash-conses equal chains and strings (doc/misc/snapshot.md). these ride the
; snapshot as top-level globals like the marker above, and the woken child asks what
; merged: the two lists are one value, and the two casks -- equal bytes, but written
; through their holder -- are not, or a write to either would land on both.
(: bake-dedup-l1 [1 2 3 4 5]
   bake-dedup-l2 [1 2 3 4 5]
   bake-dedup-c1 (cask 4)
   bake-dedup-c2 (cask 4))

; a native rides the bake: its code is bytes in the image's segment, woken as arena text,
; so the child runs it without a compile
(: bake-native (ev '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a i)) a)) 0 0))))

; every path this lays is the pid's own, so two runs over one out/ keep apart
(: me (show (getpid 0))
   img ("out/.bake-nif-smoke-" + me + ".image")
   drv ("out/.bake-nif-drive-" + me + ".l")

   ; this binary woke from its own .image. every assertion below rides `love wake FILE`,
   ; a door ai_baked_pick does not use -- a blob laid where the section opens instead of
   ; where ai_baked_image reads falls back to the egg in silence, and `love-image` is the
   ; one tell. not for the cold lane (LOVE_NO_IMAGE), which has no image by design.
   _ (test (ev 'love-image = "<baked>"))

   ; the bake answers 1 and the session rides on (this very assert runs post-dump);
   ; note the file port feeding this script is live at the dump -- the fz leg.
   _ (test (bake img = 1))

   ; the woken child reads the marker this session pinned before its bake
   _ (open drv "w" @ p (say p "(: _ (putn bake-smoke-marker) (quit 0))", close p))
   r (hark ["out/love" "wake" img drv])
   _ (test (two? r) (<r = 0) (>r = "4242"))

   ; ..and what the hash-cons did to the pair of casks: two equal casks stay two objects,
   ; which a pin on one shows (the deduped lists cannot be told apart, and need not be)
   _ (open drv "w" @ p
      (say p "(: _ (pin bake-dedup-c1 0 65) ok (? (= bake-dedup-l1 bake-dedup-l2) ",
       say p "(? ((peep bake-dedup-c1 0 -1) = 65 && (peep bake-dedup-c2 0 -1) = 0) 1 0) 0) ",
       say p "_ (putn ok) (quit 0))",
       close p))
   r2 (hark ["out/love" "wake" img drv])
   _ (test (two? r2) (<r2 = 0) (>r2 = "1"))

   ; ..and the native: still native in the child, and the same answer
   _ (test (nat? bake-native) (bake-native 100000 = 4999950000))
   _ (open drv "w" @ p
      (say p "(: _ (putn (? (nat? bake-native) (bake-native 100000) -1)) (quit 0))",
       close p))
   r3 (hark ["out/love" "wake" img drv])
   _ (test (two? r3) (<r3 = 0) (>r3 = "4999950000"))

   ; a baked binary wakes its natives unseated, the code inflated at first call: foldl is
   ; native before it runs, and keys a tablet the same before and after
   r4 (hark ["out/love" "-e" "(: t {foldl 1} n (nat? foldl) s (foldl (+) 0 [1 2 3]) _ (putx [n s (t foldl) (nat? foldl)]) (quit 0))"])
   (test (two? r4) (<r4 = 0) (>r4 = "(1 6 1 1)"),

    unlink img, unlink drv,
    test_fin (),
    puts "bake: ok\n"))
