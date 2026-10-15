; test/host/imgcheck.l -- a damaged image refuses, or ends the run saying so; it never faults
; the head (header, dictionary, tables) is checked at the wake, and each deflated chunk, stream
; or code, before it inflates (doc/misc/snapshot.md, the digests). a refused `love wake FILE`
; exits 2 saying so.
;   cat test/00-init.l test/host/imgcheck.l | out/love
(: imgcheck-native (ev '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a i)) a)) 0 0))))

(: me (show (getpid 0))
   img ("out/.imgcheck-" + me + ".image")
   bad ("out/.imgcheck-bad-" + me + ".image")
   drv ("out/.imgcheck-drive-" + me + ".l")
   _ (test (bake img = 1))
   s (: q (open img "r") b (slurp q) (close q, b))
   n #s
   (u64 o) (foldr (\ i a (a * 256 + s (o + i))) 0 ^8)

   ; the wire: header (eleven words, then the root table), dictionary, stream, code
   hsz (8 * (11 + 2 * u64 40))
   ns (u64 56)  nc (u64 72)
   so (n - nc - ns)  co (n - nc)
   sch (u64 (so + 8))  srow (so + 16)  sz (srow + 32 * sch)
   (szoff k) (sz + u64 (srow + 32 * k + 16))
   nch (u64 (co + 8))  ndz (u64 (co + 24))  crow (co + 32)  cz (crow + 24 * nch + ndz)
   (czoff k) (cz + u64 (crow + 24 * k + 8))
   _ (test (1 < sch) (1 < nch) (hsz < so))

   ; a copy with byte o flipped, or cut to its first m bytes
   (flip os) (: t (foldl (\ a o (snip a 0 o + string ((a o) ^ 90) + snip a (o + 1) n)) s os)
               f (open bad "w") _ (say f t) (close f))
   (cut m) (: f (open bad "w") _ (say f (snip s 0 m)) (close f))
   _ (open drv "w" @ p (say p "(: _ (putx [love-image (imgcheck-native 1000)]) (quit 0))", close p))
   (run _) (hark ["out/love" "wake" bad drv])
   woke ("(\"" + bad + "\" 499500)")
   (outcome r) (? (<r = 2) 'refused
                  (two? r && <r = 0 && >r = woke) 'woke
                  (<r = 70) 'damaged
                  (<r >= 128) 'fault
                  'other)

   ; an undamaged copy wakes
   _ (flip [])
   _ (test (outcome (run ()) = 'woke))

   ; the head: any byte of the header, the dictionary, either table refuses at the wake
   _ (each [0 80 (hsz - 8) (hsz + 100) (so - 1) (so + 4) (srow + 40) (co + 3) (crow + 30) (cz - 1)]
       (o \ (: _ (flip [o]) (test (outcome (run ()) = 'refused)))))

   ; a stream chunk: every chunk damaged refuses at the wake, which decodes the image's edges;
   ; one damaged inside ends the run at its first touch, which a major forces
   _ (flip (map (k \ szoff k + 1) ^sch))
   _ (test (outcome (run ()) = 'refused))
   _ (open drv "w" @ p (say p "(: l (jot 3000000) _ (putx [love-image (tally l)]) (quit 0))", close p))
   _ (flip [(szoff (sch // 2) + 7)])
   _ (test (outcome (run ()) = 'damaged))
   _ (open drv "w" @ p (say p "(: _ (putx [love-image (imgcheck-native 1000)]) (quit 0))", close p))

   ; a code chunk: every one damaged, so the native's is; its first call refuses to seat it
   _ (flip (map (k \ czoff k + 3) ^nch))
   o (outcome (run ()))
   _ (test (o != 'fault) (o != 'woke))

   ; cut short at each edge: the header, the dictionary, a stream chunk, the code segment
   ((each [8 (hsz - 1) (so - 1) (sz + 1) (szoff 1) (co - 1) (cz + 1) (n - 1)]
     (m \ (: _ (cut m) (test (outcome (run ()) = 'refused))))),

 unlink img, unlink bad, unlink drv,
 test_fin (),
 puts "imgcheck: ok\n"))
