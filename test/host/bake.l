; test/host/bake.l -- the bake nif: (bake path) snapshots the live session mid-eval, and
; `love wake PATH prog.l` boots a session carrying every global pinned before it.
; run: cat test/00-init.l test/host/bake.l | out/love
; a bodiless top-level `:`, so a global the snapshot carries
(: bake-smoke-marker 4242)

; the dump hash-conses equal chains and strings: the lists merge, the casks must not,
; or a write to either would land on both
(: bake-dedup-l1 [1 2 3 4 5]
   bake-dedup-l2 [1 2 3 4 5]
   bake-dedup-c1 (cask 4)
   bake-dedup-c2 (cask 4))

; a native rides the bake as bytes, woken as arena text without a compile
(: bake-native (ev '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a i)) a)) 0 0))))

; paths are the pid's own, so two runs over one out/ keep apart
(: me (show (getpid 0))
   img ("out/.bake-nif-smoke-" + me + ".image")
   drv ("out/.bake-nif-drive-" + me + ".l")

   ; woke from its own image: a misplaced blob falls back to the egg in silence, and
   ; love-image is the one tell. not for the cold lane (LOVE_NO_IMAGE)
   _ (test (ev 'love-image = "<baked>"))

   ; the session rides on past the dump, the file port feeding this script live across it
   _ (test (bake img = 1))

   _ (open drv "w" @ p (say p "(: _ (putn bake-smoke-marker) (quit 0))", close p))
   r (hark ["out/love" "wake" img drv])
   _ (test (two? r) (<r = 0) (>r = "4242"))

   ; equal casks stay two objects, which a pin on one shows
   _ (open drv "w" @ p
      (say p "(: _ (pin bake-dedup-c1 0 65) ok (? (= bake-dedup-l1 bake-dedup-l2) ",
       say p "(? ((peep bake-dedup-c1 0 -1) = 65 && (peep bake-dedup-c2 0 -1) = 0) 1 0) 0) ",
       say p "_ (putn ok) (quit 0))",
       close p))
   r2 (hark ["out/love" "wake" img drv])
   _ (test (two? r2) (<r2 = 0) (>r2 = "1"))

   _ (test (nat? bake-native) (bake-native 100000 = 4999950000))
   _ (open drv "w" @ p
      (say p "(: _ (putn (? (nat? bake-native) (bake-native 100000) -1)) (quit 0))",
       close p))
   r3 (hark ["out/love" "wake" img drv])
   _ (test (two? r3) (<r3 = 0) (>r3 = "4999950000"))

   ; a baked binary inflates a native's code at first call: foldl is native before it runs,
   ; and keys a tablet the same before and after
   r4 (hark ["out/love" "-e" "(: t {foldl 1} n (nat? foldl) s (foldl (+) 0 [1 2 3]) _ (putx [n s (t foldl) (nat? foldl)]) (quit 0))"])
   (test (two? r4) (<r4 = 0) (>r4 = "(1 6 1 1)"),

    unlink img, unlink drv,
    test_fin (),
    puts "bake: ok\n"))
