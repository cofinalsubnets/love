; test/host/mus.l -- doom's MUS scores: one laid here, read, played on a sine and looped
;   cat test/00-init.l test/host/00-host.l test/host/mus.l | out/love
(borrow 'mus)
(borrow 'opl)
(borrow 'bytes)
(: (mus-t-b l) (foldl (\ a c (a + string c)) "" l)
   ; ..a bank whose first instrument is a sine held while its key is (the modulator silent)
   v (mus-t-b [33 240 15 0 0 63 0 33 240 15 0 0 0 0 0 0])
   B (opl-bank ("#OPL_II#" + mus-t-b [0 0 128 0] + v + v + zbytes (174 * 36) + "sine" + zbytes (28 + 174 * 32)))
   ; ..a score: channel 0 takes instrument 0; a = 440 at full volume for 70 ticks, let go, 70 more, the end
   ev (mus-t-b [64 0 0  144 197 127 70  128 69 70  96])
   (score ev) ("MUS\x1a" + wrle #ev 2 + wrle 18 2 + wrle 1 2 + wrle 0 2 + wrle 1 2 + wrle 0 2 + wrle 0 2 + ev)
   sc (mus-read (score ev))
   _ (test (mus-read "MUS" = ()) (mus-read "hello there, not a score" = ()) (sc 'ticks = 140)
           (sc 'evs = [[0 0 'ctl 0 0] [0 0 'on 69 127] [70 0 'off 69 0]]))
   ; played at 14000 a second, 100 frames a tick: sounding to frame 7000, let go there, then silence
   ;   until the loop sounds it again at 14000
   rate 14000 p (mus-new sc B rate)
   (feed n) (: r (mus-feed p n) <r + >r)
   (peak y a b) (sqrt (amax (peep (y * y) (iota (b - a) + a) 0.0)))
   y (feed 21000)
   (ups a b) (net ((peep y (iota (b - a - 1) + a) 0.0 <= 0.0) * (peep y (iota (b - a - 1) + a + 1) 0.0 > 0.0)))
   _ (test (peak y 0 6900 > 0.5) (abs (ups 0 7000 - 220) <= 1)     ; half a second of 440
           (peak y 7500 13900 < 0.001)                            ; let go: a release of 15 is at once
           (peak y 14000 20900 > 0.5))                             ; and again, looped
   _ (feed 100)
   _ (test (mus-voices p = 1))                                   ; the first one let go is gone
   ; ..volume 0 on the channel: the note sounds nothing
   q (mus-new (mus-read (score (mus-t-b [64 0 0  64 3 0  144 197 127 70  128 69 70  96]))) B rate)
   _ (test (: r (mus-feed q 7000) (peak (<r + >r) 0 6900 = 0.0)))
   ; which lump a map plays
   _ (test (mus-track "E1M1" = "D_E1M1") (mus-track "E3M9" = "D_E3M9") (mus-track "E4M1" = "D_E3M4") (mus-track "E4M9" = "D_E1M9")
           (mus-track "MAP01" = "D_RUNNIN") (mus-track "MAP32" = "D_ULTIMA") (mus-track "MAP33" = ()) (mus-track "STAGE" = ()))
   ((test_fin ()),
    puts "mus: ok\n"))
