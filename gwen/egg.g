(\ egg (:
 (go e z a) (? a (go e (e (A a)) (B a)) z)
 t0 (clock 0)
 e (go (go ev 0 egg) 0 egg)
 _ (put 'ev e globals)
 t1 (clock t0)
 (put 'boot_ms t1 globals)))
