; --- test/horn.l: the horn, PCM out as a port (doc/misc/plan/horn.md, rung 0) ---
; the laws are the port's shape, not the sound: a full device refuses at the door,
; the writer parks and the scheduler runs on, what has played drains at the rate.
; on the host HORN=none picks the sink, a ring that keeps time and discards -- so
; the gate needs no card and wakes no speaker. under inle the same laws meet the
; real driver (inle/hda.c) where the machine has a controller, and its absence
; on the other seats is the errno nom.

(: _ (? hosted (setenv "HORN" "none") ())        ; inle and the browser read no policy word
   h (horn 48000 2)
   _ (assert ('badarg = horn 100 2) ('badarg = horn 48000 3) ('badarg = horn "a" 2))
   _ (? (nom? h)
        ; no device: only inle on a machine with no HDA controller may say so
        (assert (h = 'enodev) (love-os = 'inle) !(love-arch = 'x64))
        (: ; one second of silence, 4K at a time: the sink holds a quarter second, the
           ; card's ring under two thirds, so the loop must WAIT for most of it -- and
           ; while it waits another task gets to run
           z (: (mk n acc) (? (n = 0) acc (mk (n - 1) (0 . acc))) (string (mk 4096 ())))
           box {}
           _ (twirl (\ _ (: _ (rest 20) (pin box 'ran 1))) ())
           t0 (clock 0)
           _ (: (go n) (? (n = 0) () (: _ (say h z) (go (n - 1)))) (go 47))
           dt (clock t0)
           lag (horn-lag h)
           _ (assert (hot? h) (dt >= 200) (dt < 5000) (0 < lag) (lag <= 48000) (box 'ran))
           ; mono: a frame is two bytes, and the lag counts the caller's frames (plus a lead)
           m (horn 48000 1)
           _ (assert (hot? m) (0 = horn-lag m))
           _ (say m (snip z 0 2000))
           _ (flush m)
           _ (assert (0 < (horn-lag m) < 4096))       ; the card counts its prefetch lead too
           ; close lands the run and shuts the device; a closed horn has no lag
           _ (assert !(close m) !(horn-lag m) !(close h) !(horn-lag h))
           ; and a horn is not the reader
           _ (assert (= (quote (5)) (sound "5")))
           ; the policy word goes, so the environ laws downstream count what they always did
           (? hosted (setenv "HORN" ()) ()))))
