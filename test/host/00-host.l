; helpers shared by the host tests: test_hostnif cats this between test/00-init.l and each test
(: (h-waitfor pid) (gather pid @ s (? (two? s) s (nom? s) s (rest 2, h-waitfor pid)))   ; a child's status, polled
   (h-wf p) (gather p @ g (two? g ? g (rest 2, h-wf p)))
   (h-mkscr r c) (screen (cask (screen () r c)) r c)                                      ; a quay screen, r by c
   (h-count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (h-rows s) (1 + h-count s "\r\n")                                                      ; a frame's rows
   (h-plain s) ((: (g i acc esc) (i < #s ? (s i @ c                                       ; s less its escapes
                                     (? esc (g (i + 1) acc (65 <= c < 91 || 97 <= c < 123 ? 0 1))
                                        (c = 27) (g (i + 1) acc 1)
                                        (g (i + 1) (acc + string c) 0))) acc)) 0 "" 0))
