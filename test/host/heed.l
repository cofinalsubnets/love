; test/host/heed.l -- (heed p ms): 1 once p has input, 0 when ms pass first. alone it waits in
; place; beside a peer it parks on the fd and the clock both, whichever comes first waking it.
; the bounds are loose: a loaded box is late, never early
(: (now _) (clock 0)
   (writer fd s) (spawnio ["sh" "-c" ("sleep 0.1; printf " + s)] 0 fd 2 [] -1 0)
   (ticker n) (twirl (_ \ (: (go i) (n 'stop ? i (pin n 0 i, rest 10, go (i + 1))) (go 0))) 0)

   ; alone: the clock first, then the fd first
   p1 (pipe 0)  r1 (fdopen <p1)
   t1 (now 0)  a1 (heed r1 200)  e1 (now 0 - t1)
   w1 (writer >p1 "x")
   t2 (now 0)  a2 (heed r1 5000)  e2 (now 0 - t2)
   _ (wait w1)
   b2 (see r1)

   ; bytes in the port answer at once, however quiet the fd; so does a pushback
   _ (unsee r1 65)
   t3 (now 0)  a3 (heed r1 5000)  e3 (now 0 - t3)
   b3 (see r1)
   a4 (heed r1 0)  a5 (heed r1 -1)

   ; beside a ticking peer: the fd first, then the clock first
   n1 {}  k1 (ticker n1)
   w2 (writer >p1 "y")
   t6 (now 0)  a6 (heed r1 5000)  e6 (now 0 - t6)
   _ (wait w2)
   b6 (see r1)
   t7 (now 0)  a7 (heed r1 300)  e7 (now 0 - t7)
   _ (pin n1 'stop 1)
   c7 (catch k1)

   ; a heeding peer, woken by its fd while main waits on it
   w3 (writer >p1 "z")
   h8 (twirl (_ \ heed r1 5000) 0)
   t8 (now 0)  a8 (catch h8)  e8 (now 0 - t8)
   _ (wait w3)

   ; a write end gone is input: see answers -1
   p9 (pipe 0)  r9 (fdopen <p9)
   _ (close >p9)
   a9 (heed r9 5000)

   _ (test (a1 = 0) (200 <= e1) (e1 < 2500)
           (a2 = 1) (e2 < 2500) (b2 = 120)
           (a3 = 1) (e3 < 500) (b3 = 65)
           (a4 = 0) (a5 = 0)
           (a6 = 1) (e6 < 2500) (b6 = 121)
           (a7 = 0) (300 <= e7) (e7 < 2500) (5 < c7)
           (a8 = 1) (e8 < 2500)
           (a9 = 1) (see r9 = -1))
   0)

(puts "heed: ok\n")
