; round trip: rd is show -> read (datums), rt is show -> read -> eval (data values)
(: (s2cl s) ((: (g i) (i < #s ? ((peep s i 0) . g (1 + i)))) 0)
   ; rd-test is the reader-under-test socket
   (rdr s) (rd-test (s2cl s) @ r (two? r ? <r r))
   (rd x) (rdr (show x))
   (rt x) (ev (rdr (show x))))
(test
 ; --- datum round-trip (print -> read): the printed form re-reads equal ---
 (42 = rd 42)
 (-7 = rd -7)
 ('foo = rd 'foo)
 ("hi\n" = rd "hi\n")
 ('(a (b c) d) = rd '(a (b c) d))
 (''x = rd ''x)                                   ; quote sugar 'x survives the loop
 ; --- value round-trip (print -> read -> eval) ---
 ; self-evaluating atoms
 (42 = rt 42)
 ("hi\n" = rt "hi\n")
 (1.5 = rt 1.5)
 ; -0.0 = 0.0, so the sign is checked through the reciprocal
 ("-0.0" = show -0.0) ("0.0" = show 0.0)
 ("0.0" = show (0 - 0.0))                            ; +0.0 stays unsigned: 0 - 0 is +0
 ("-infinity" = show (1.0 / rd -0.0))                ; the sign survived the loop
 ("infinity" = show (1.0 / rd 0.0))
 ; ,-prefixed constructor forms reconstruct an equal value
 (aall (@(1 2 3) = rt @(1 2 3)))
 (aall (star-tray '(2 2) '(1 2 3 4) = rt (star-tray '(2 2) '(1 2 3 4))))
 (aall (gem-tray '(2) '(1.5 2.5) = rt (gem-tray '(2) '(1.5 2.5))))
 ((2 ~ -3) = rt (2 ~ -3))
 ; complex arrays round-trip (ca-* from complex.l)
 (aall (ca-v = rt ca-v))
 (aall (ca-m = rt ca-m))
 (100 = peep (rt {1 100 2 200}) 1 0)
 (200 = peep (rt {1 100 2 200}) 2 0))
