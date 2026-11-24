; test/host/stow.l -- src/apps/stow.l round trips every kind it takes, trays in their shape and
; tablets in their key order, and refuses what it does not; guts' pind and peepd lay and read
; a real tray's bits as they are
;   cat test/00-init.l test/host/00-host.l test/host/stow.l | out/love
(borrow 'stow)
(: pind (cite 'guts 'pind) peepd (cite 'guts 'peepd) peepv (cite 'guts 'peepv)
   (rt v) (unstow (stow v))
   (same v) (rt v @ r (show r = show v && kind r = kind v))
   vs [() 0 -7 (2 62) 1.5 -0.0 1e300 (0 ~ 1) "" "a\0b" 'sym [1 2 [3 ()] "x"] (1 . 2) {'a 1 "b" [2.5] 3 {'c ()}}
       (star-tray [3] [1 -2 3]) (gem-tray [4] [0.1 0.2 -1e-300 3.0]) (star-tray [0] ()) [(gem-tray [1] [7.0]) 'k]]
   _ (test (all same vs))
   ; ..a long list asks no deeper stack than a short one
   long ^200000
   _ (test (rt long = long))
   ; ..a tablet's keys come back in the order keys gave them
   tb (foldl (\ t k (pin t k (k * k))) {} (rev ^50))
   _ (test (keys (rt tb) = keys tb) (rt tb 7 = 49))
   ; ..a tray keeps its rank and dims, an empty one too
   g (gem-tray [2 3] [1.0 2.0 3.0 4.0 5.0 6.0]) z (star-tray [3 1 2] [1 2 3 4 5 6]) e (gem-tray [0 4] ())
   _ (test (all (v \ rt v @ r (show r = show v && shape r 0 = shape v 0 && rank r = rank v)) [g z e])
           (shape (rt z) 1 = 1) (shape (rt e) 1 = 4))
   ; ..what it does not take, and bytes it did not lay
   s2 (stow [1 2])
   _ (test (stow (x \ x) = ()) (stow [1 (x \ x)] = ()) (unstow "junk" = ()) (unstow (snip s2 0 20) = ())
           (unstow (s2 + "x") = ()) (unstow 5 = ()))
   ; ..pind lays a real tray's bits from a byte on, peepd reads them back, by count or by dims,
   ; from a cask or a string; a sign, an infinity and the smallest subnormal kept
   inf (1e308 * 10.0) d (gem-tray [4] [-0.0 inf 5e-324 2.5]) c (cask 40) r (pind c 8 d)
   _ (test (r = c) (show (peepd c 8 4) = show d) (show (peepd (string c) 8 4) = show d)
           (show (peepd c 8 [2 2]) = show (gem-tray [2 2] [-0.0 inf 5e-324 2.5]))
           (peep (peepv c 0 8 8 1) 0 () = 0) (peep (peepd c 16 1) 0 () = inf))
   ; ..an int tray, a lay past the end, a read past it or of a negative count: ()
   _ (test (pind c 0 (star-tray [2] [1 2]) = ()) (pind c 24 d = ()) (peepd c 16 4 = ()) (peepd c 0 -1 = ()))
   0)

(test_fin (), puts "stow: ok", putc 10, 0)
