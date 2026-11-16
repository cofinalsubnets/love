; zstd's C coder read back by its decoder: a run of period 1..17 is one long match a short way
; back, across the decoder's eight- and sixteen-byte copy steps; alone and against a base
(borrow 'zstd)
(: zs-alpha "abcdefghijklmnopq"
   (zs-run k n) (cats (map (_ \ snip zs-alpha 0 k) ^(n // k)))
   (zs-back k) (: s (zs-run k 1200) (zstd-d (zstde s 19) = s))
   (zs-back-by k) (: b (zs-run 17 600) s (zs-run k 900) (zstd-d-by (zstde-by s b 19) b = s))
   zs-ks (map (+ 1) ^17))
(test
 (map zs-back zs-ks = map (_ \ 1) zs-ks)
 (map zs-back-by zs-ks = map (_ \ 1) zs-ks))
