; test/host/lazyglaze.l -- LOVE_LAZY_GLAZE: a closure's glaze waits for its first call (glaze.l's
; natjit, tablet.c's firstcell). the answers are eager's, a function hashes the same before and
; after its compile, and tasks calling one whose compile is still running take its twin
;   cat test/00-init.l test/host/lazyglaze.l | out/love
(: lzg-q "(: (f x) (x * x + 1) (h n a) (n < 1 ? a (h (n - 1) (a + n))) d0 (dig f) v (f 3) d1 (dig f) ps (map (k \\ twirl (k \\ h 20000 k) k) [1 2 3 4]) rs (map catch ps) _ (putx [(d0 = d1) v rs (h 10 0)]) (quit 0))"
   lzg-want "(1 10 (200010001 200010002 200010003 200010004) 55)"
   lzg-l (hark ["env" "LOVE_LAZY_GLAZE=1" "out/love" "-e" lzg-q])
   lzg-e (hark ["out/love" "-e" lzg-q])
   _ (test (two? lzg-l) (<lzg-l = 0) (>lzg-l = lzg-want) (two? lzg-e) (<lzg-e = 0) (>lzg-e = lzg-want))
  (test_fin (), puts "lazyglaze: ok\n"))
