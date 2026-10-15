; --- the horn, pcm out as a port: the laws are the port's shape, not the sound ---
; on the host HORN=none is a sink that keeps time and discards, so no card is needed

; a wait yields: a call that waited 10 ms while the polling task never ran had the scheduler held
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
        (: ; a second of silence, 4K at a time: the sink holds a quarter second, so the loop waits
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
            ; unset, so the environ laws downstream see no extra word
            (hosted ? (setenv "HORN" ()))))))

; --- capture is a port that reads: HORN_IN=none is silence at the rate, and the reader parks ---
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

; --- HORN_IN=sock:PATH: a u32 says the rate (top byte the channels), then frames until hangup ---
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
