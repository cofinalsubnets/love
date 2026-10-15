; --- test/horn.l: the horn, PCM out as a port ---
; the laws are the port's shape, not the sound: a full device refuses at the door,
; the writer parks and the scheduler runs on, what has played drains at the rate.
; on the host HORN=none picks the sink, a ring that keeps time and discards -- so
; the gate needs no card and wakes no speaker. under inle the same laws meet a real
; card: src/inle/hda.c's where the machine has a controller, the page's own where it is a
; wasm module (src/inle/wasm/horn.c). a seat with neither is the errno nom.

; a wait yields: a task polls while the loop works, and marks it ran when it finds the loop
; inside a call that waits. a call that waited 10 ms without it ran had the scheduler held.
; on a loaded box the ring drains while the process is off the cpu and no call need wait:
; then there is nothing to witness, and the law holds of no call
(: (hn-witness box) (twirl (_ \ (: (go u) (? (box 'done) () (box 'in) (pin box 'ran 1) (: _ (rest 1) (go 0))) (go 0))) ())
   (hn-waits box f) (: a (clock 0) _ (pin box 'in 1) r (f 0) _ (pin box 'in ())
                       (: _ (? (clock a >= 10) (pin box 'waited 1) 0) r))
   (hn-yielded? box) (: _ (pin box 'done 1) (!(box 'waited) || box 'ran)))

(: _ (hosted ? (setenv "HORN" "none"))           ; inle and the browser read no policy word
   h (horn 48000 2)
   _ (test ('badarg = horn 100 2) ('badarg = horn 48000 3) ('badarg = horn "a" 2))
   _ (? (nom? h)
        ; no device: only inle on a machine with no card of its own may say so
        (test (h = 'enodev) (love-os = 'inle) !(elem love-arch '(x64 wasm)))
        (: ; one second of silence, 4K at a time: the sink holds a quarter second, the
           ; card's ring under two thirds, so the loop must WAIT for most of it -- and
           ; while it waits another task gets to run
           z (: (mk n acc) (n = 0 ? acc (mk (n - 1) (0 . acc))) (string (mk 4096 ())))
           box {}
           _ (hn-witness box)
           t0 (clock 0)
           _ (: (go n) (n = 0 ? () (hn-waits box (u \ say h z), go (n - 1))) (go 47))
           dt (clock t0)
           lag (horn-lag h)
           _ (test (hot? h) (dt >= 200) (dt < 5000) (0 < lag) (lag <= 48000) (hn-yielded? box))
           ; mono: a frame is two bytes, and the lag counts the caller's frames (plus a lead)
           m (horn 48000 1)
           ((test (hot? m) (0 = horn-lag m)),
            say m (snip z 0 2000),
            flush m,
            (test (0 < (horn-lag m) < 4096)),       ; the card counts its prefetch lead too
            ; close lands the run and shuts the device; a closed horn has no lag
            (test !(close m) !(horn-lag m) !(close h) !(horn-lag h)),
            ; and a horn is not the reader
            (test (quote (5) = sound "5")),
            ; the policy word goes, so the environ laws downstream count what they always did
            (hosted ? (setenv "HORN" ()))))))

; --- the horn turned round: capture is a port that reads. on the host HORN_IN=none is
; silence heard at the rate, so a quarter second of it takes a quarter second to read,
; and the reader parks while it waits. a seat's own card does not listen yet: the
; errno nom, where the host always has the silence.
(: _ (hosted ? (setenv "HORN_IN" "none"))
   hi (horn-in 48000 1)
   _ (test ('badarg = horn-in 100 1) ('badarg = horn-in 48000 3) ('badarg = horn-in 48000 "a"))
   (? (nom? hi)
        (test (hi = 'enodev) !hosted)
        (: box {}
           _ (hn-witness box)
           t0 (clock 0)
           ; a byte by see, the rest of the gulp by chug: n bytes and their sum
           (rd p n k z) (n <= k ? [k z] (hn-waits box (u \ see p) @ c (c = -1 ? [k z] (: s (chug p) (rd p n (k + 1 + #s) (z + c + +s))))))
           r (rd hi 24000 0 0)
           dt (clock t0)
           _ (test (r 0 >= 24000) (r 1 = 0) (dt >= 200) (dt < 5000) (hn-yielded? box) (0 <= horn-lag hi < 12001))
           ; stereo is four bytes a frame, and what waits to be read is the lag
           hj (horn-in 44100 2)
           ((rest 100),
            (test (0 < horn-lag hj <= 11025) (0 = (#(chug hj)) % 4)),
            (: r2 (rd hj 4000 0 0) (test (0 = (r2 0) % 4) (r2 1 = 0))),
            ; a closed capture port has no lag
            (test !(close hi) !(horn-lag hi) !(close hj) !(horn-lag hj)),
            (hosted ? (setenv "HORN_IN" ()))))))

; --- capture by a socket's listener: HORN_IN=sock:PATH says the rate, the u32's top byte
; the channels, and reads the frames the listener sends until it hangs up; its lag is
; what the listener sent and nobody has read yet
(: _ (hosted ? (: path ("/tmp/.love-hornin-" + show (getpid 0) + ".sock")
                  l (listen ['unix path])
                  _ (setenv "HORN_IN" ("sock:" + path))
                  hm (horn-in 48000 1) cm (accept l)
                  hs (horn-in 44100 2) cs (accept l)
                  (word c) (map (_ \ see c) ^4)
                  wm (word cm) ws (word cs)
                  _ (say cm (string [1 0 2 0 3 0]), flush cm)
                  lg (horn-lag hm)
                  got (see hm @ b (string [b] + chug hm))
                  _ (close cm)
                  over (see hm)
                  (close hm, close hs, close cs, close l, unlink path, setenv "HORN_IN" (),
                   test (wm = [128 187 0 1]) (ws = [68 172 0 2]) (lg = 3) (got = string [1 0 2 0 3 0]) (over = -1)))))
