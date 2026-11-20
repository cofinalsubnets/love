; test/gate/wakekeys.l -- baked into an image, read back woken: a key that hashes by its serial
; -- a mint, a list holding one, a tablet -- is found where the bake left it. test_wake
(: wk-ms (map (_ \ mint 0) ^50)
   wk-ts (map (_ \ tablet 0) ^50)
   wk-tab (tablet 0)
   _ (foldl (i \ m \ (pin wk-tab m i, pin wk-tab [m 3] (i + 100), i + 1)) 0 wk-ms)
   _ (foldl (i \ t \ (pin wk-tab t (i + 200), i + 1)) 0 wk-ts)
   (wakekeys _) (map (m \ peep wk-tab m -1) wk-ms = jot 50
                 && map (m \ peep wk-tab [m 3] -1) wk-ms = map (+ 100) ^50
                 && map (t \ peep wk-tab t -1) wk-ts = map (+ 200) ^50))
