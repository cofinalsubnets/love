; test/host/player.l -- src/apps/player: the bus (eq.c's biquads and spectrum, bus.l's
; coefficients) and the core, driven in process through its messages on HORN=none, which keeps
; real time, so every track here is a fraction of a second. where sox is, one band of the eq
; is held to sox's equalizer, the same rbj filter, within a sample's rounding.
;   cat test/00-init.l test/host/player.l | out/love
(borrow 'posix)
(borrow 'bus)
(borrow 'core)
(: dir (cwd 0 + "/out/.playerd")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   _ (setenv "HORN" "none")
   (sh c) (hark ["sh" "-c" c])
   peepv (cite 'guts 'peepv) pinv (cite 'guts 'pinv)
   (le v n) (string (map (k \ (v >> (8 * k)) & 255) ^n))
   (pl-wav rate ch pcm)
    ("RIFF" + le (36 + #pcm) 4 + "WAVEfmt " + le 16 4 + le 1 2 + le ch 2 + le rate 4
     + le (rate * ch * 2) 4 + le (ch * 2) 2 + le 16 2 + "data" + le #pcm 4 + pcm)
   (pl-lay p s) (open p "w" @ q (say q s, close q))
   ; s16 frames from a tray per channel
   (pl-pcm ts) (: n #(<ts) ch #ts c (cask (2 * ch * n))
                  (each ^ch (k \ pinv c (2 * k) 2 (2 * ch) (ts k)), string c))
   (pl-chan s ch k) (: c (cask #s) _ (pour c 0 s 0 #s) t (peepv c (2 * k) 2 (2 * ch) (#s // (2 * ch)))
                      (t - 65536 * (t >= 32768)))
   (pl-sine f rate n amp) (int (amp * sin (iota n * (2.0 * 3.141592653589793 * f / rate))))
   ; a reproducible noise, as a tray
   (pl-noise n seed) (: (go k x acc) (? (k = 0) acc (: y ((x * 1103515245 + 12345) % 2147483648)
                                                         (go (k - 1) y ((y >> 16) % 16000 - 8000 . acc))))
                        l (go n seed ())
                        c (cask (2 * n))
                        (each ^n (i \ pinv c (2 * i) 2 2 (iota 1 + l i)),
                         pl-chan (string c) 1 0))

   ; --- the bus --------------------------------------------------------------
   nz (pl-pcm [(pl-noise 4410 7) (pl-noise 4410 11)])
   flat (bus-co 44100 (map (_ \ 0) ^10) 0 100 0 1)
   (run1 co s ch) ((cite 'dsp 'biquads) s ch co "" @ (o . _) o w w)
   _ (test (run1 flat nz 2 = nz)                                       ; flat and full: the same bytes
           (pl-chan (run1 (bus-co 44100 (map (_ \ 0) ^10) 0 50 0 1) nz 2) 2 0
              = (pl-chan nz 2 0 @ v (int (v * 0.5 + (v >= 0) * 0.5 - (v < 0) * 0.5))))
           (aall (pl-chan (run1 (bus-co 44100 (map (_ \ 0) ^10) 0 100 100 1) nz 2) 2 0 = 0))
           (pl-chan (run1 (bus-co 44100 (map (_ \ 0) ^10) 0 100 100 1) nz 2) 2 1 = pl-chan nz 2 1)
           ((cite 'dsp 'biquads) nz 3 flat "" = 'badarg))
   ; memory carries: two halves through one bus equal the whole through another
   _ (: eq (map (k \ k % 3 * 4 - 4) ^10) a (bus-new ()) b (bus-new ())
        _ (pin a 'co (bus-co 44100 eq 0 100 0 1)) _ (pin b 'co (a 'co))
        h (#nz // 8 * 4)
        x (bus-run a (snip nz 0 h) 2) y (bus-run a (snip nz h #nz) 2) z (bus-run b nz 2)
        (test (x + y = z)))
   ; a slider moved off 0 dB keeps the filters' memory: no cold start, so no click. the
   ; difference just after the switch is no bigger than where it has settled
   _ (: A [-12 9 0 0 0 0 0 0 0 0] B [-12 9 0 0 0 0 0 0 0 1] h (#nz // 8 * 4)
        bq (cite 'dsp 'biquads)
        (run co s st) (bq s 2 co st @ (o . st2) [o st2] w w)
        whole (<(run (bus-co 44100 A 0 100 0 1) nz ""))
        r1 (run (bus-co 44100 A 0 100 0 1) (snip nz 0 h) "")
        r2 (run (bus-co 44100 B 0 100 0 1) (snip nz h #nz) (r1 1))
        d (pl-chan (snip whole h #nz) 2 0 - pl-chan (<r2) 2 0)
        ad (max d (0 - d))
        (win k) (amax (peep ad (k + iota 500) 0))
        (test (#(r1 1) = #((run (bus-co 44100 B 0 100 0 0) nz "") 1))
              (win 0 <= 2 * win 1500 + 2)))
   ; the spectrum: a 1 kHz sine at full scale tops its own band, silence is the floor
   sine (pl-pcm [(pl-sine 1000.0 44100 4096 32767.0) (pl-sine 1000.0 44100 4096 32767.0)])
   sp (bus-spec sine 2 44100 32)
   top (findsub sp [(foldl max 0 sp)])
   _ (test (#sp = 32) (240 <= foldl max 0 sp)
           (top = 18)                                                   ; 970 .. 1219 Hz
           (bus-spec (pl-pcm [(iota 4096 * 0) (iota 4096 * 0)]) 2 44100 32 = map (_ \ 0) ^32)
           (6 <= #(uniq (snip (bus-spec nz 2 44100 32) 0 8)))           ; bars narrower than a bin
           (#(bus-scope sine 2 8) = 8)
           (bus-scope sine 2 1 = [[-128 127]]))

   ; --- one band against sox's equalizer --------------------------------------
   mono (pl-pcm [(pl-noise 22050 3)])
   _ (pl-lay (dir + "/n.wav") (pl-wav 44100 1 mono))
   _ (? (sh "command -v sox >/dev/null" @ (0 . _) 1 _ 0)
        (: _ (sh ("sox -D " + dir + "/n.wav " + dir + "/e.wav equalizer 1000 1.41q 6 equalizer 60 1.41q -4"))
           q (open (dir + "/e.wav") "r") s (slurp q) _ (close q)
           ref (pl-chan (snip s 44 #s) 1 0)
           eq (map (k \ k @ 0 -4 4 6 _ 0) ^10)
           ours (pl-chan (run1 (bus-co 44100 eq 0 100 0 1) mono 1) 1 0)
           (test (#ref = #ours) (amax (max (ref - ours) (ours - ref)) <= 1)))
        (gate-partly "player: no sox here, the eq is not held to its equalizer"))

   ; --- the core, in process ---------------------------------------------------
   tone (pl-pcm [(pl-sine 440.0 8000 4000 8000.0) (pl-sine 660.0 8000 4000 8000.0)])
   _ (pl-lay (dir + "/a.wav") (pl-wav 8000 2 tone))
   _ (pl-lay (dir + "/b.wav") (pl-wav 8000 2 tone))
   _ (pl-lay (dir + "/m.wav") (pl-wav 8000 1 (pl-pcm [(pl-sine 440.0 8000 800 8000.0)])))
   c (core-new "t")
   ev {}
   (heard f) (filter f (rev (peep ev 'l ())))
   (sets k) (map (m \ m 1) (heard (m \ <m = 'set && elem k (map (kv \ <kv) (m 1)))))
   id (core-watch c (m \ pin ev 'l (m . peep ev 'l ())))
   (st k) (core-send c ['status] @ [_ s _] (<(filter (kv \ <kv = k) s) 1))
   (waits k v n) (? (st k = v || n = 0) (st k = v) (rest 20, waits k v (n - 1)))
   _ (test (<(<(heard (m \ 1))) = 'snap)
           (core-send c ['add (dir + "/a.wav")] = ['ok 1])
           (core-send c ['add (dir + "/b.wav")] = ['ok 2])
           (core-send c ['add (dir + "/m.wav") 0] = ['ok 3])
           (<(core-send c ['add (dir + "/none.wav")]) = 'err)
           (core-send c ['frob] = ['err "no verb frob"])
           (st 'qver = 3))
   (ids _) (core-send c ['status] @ [_ _ [_ its]] (map (it \ (<(filter (kv \ <kv = 'id) it)) 1) its))
   (titles _) (core-send c ['status] @ [_ _ [_ its]] (map (it \ (<(filter (kv \ <kv = 'title) it)) 1) its))
   _ (test (ids () = [3 1 2]) (titles () = ["m.wav" "a.wav" "b.wav"])
           (core-send c ['move 3 2] = ['ok]) (ids () = [1 2 3])
           (core-send c ['sort 'title] = ['ok]) (titles () = ["a.wav" "b.wav" "m.wav"])
           ((core-send c ['status] @ [_ s [_ (it . _)]] ((<(filter (kv \ <kv = 'dur) it)) 1) _ ()) = 0.5))
   ; play the queue out: each song in turn, then stop
   _ (test (core-send c ['vol 80] = ['ok]) (st 'vol = 80)
           (core-send c ['eq [3 0 0 0 0 0 0 0 0 -3]] = ['ok])
           (core-send c ['play] = ['ok]) (waits 'state 'stop 150)
           (foldr (\ x a (two? a && <a = x ? a (x . a))) ()
                  (map (s \ (<(filter (kv \ <kv = 'song) s)) 1) (filter (s \ elem 'song (map (kv \ <kv) s)) (sets 'song)))
              = [0 1 2 -1]))
   ; pause holds the place, and play goes on from it
   _ (test (core-send c ['play 0] = ['ok]) (rest 60, core-send c ['pause] = ['ok]) (st 'state = 'pause)
           (: p (st 'pos) (rest 100, st 'pos = p))
           (core-send c ['toggle] = ['ok]) (st 'state = 'play)
           (core-send c ['seek 0.1] = ['ok]) (0.1 <= st 'pos)
           (core-send c ['stop] = ['ok]) (st 'state = 'stop) (st 'song = -1))
   ; a client's feed comes while it plays, and only to it
   _ (test (core-send c ['feed 'spec 30 16] = ['err "feed: a watcher's"])
           (core-tell c id ['feed 'spec 30 16] = ['ok])
           (core-tell c id ['feed 'scope 30 8] = ['ok])
           (core-send c ['play 1] = ['ok]) (waits 'state 'stop 150)
           (foldl (\ a m (a && #(m 2) = 16)) 1 (heard (m \ <m = 'spec)))
           (0 < #(heard (m \ <m = 'scope))))
   ; consume: what plays leaves the queue
   _ (test (core-send c ['consume 1] = ['ok]) (core-send c ['play 2] = ['ok]) (waits 'state 'stop 150)
           (ids () = [1 2]) (core-send c ['clear] = ['ok]) (ids () = []))
   ; a station on loopback: an icy stream of a wav, its titles between the blocks. queued, it is
   ; asked only its name; played, the item takes each StreamTitle as it comes
   (pl-block m) (: n ((#m + 15) // 16) (string [n] + m + string (cask (16 * n - #m))))
   (pl-icy s mi ts) (: (go i acc) (? (#s <= i * mi) (cats (rev acc))
                                    (: b (snip s (i * mi) (min #s (i * mi + mi)))
                                       (go (i + 1) ((#b < mi ? b (b + pl-block (i < #ts ? (ts i) ""))) . acc))))
                       (go 0 ()))
   station ("ICY 200 OK\r\nicy-name: love radio\r\nicy-br: 256\r\nicy-metaint: 1000\r\nContent-Type: audio/wav\r\n\r\n"
            + pl-icy (pl-wav 8000 2 tone) 1000 ["StreamTitle='one';" "" "StreamTitle='two';"])
   (pl-req s) (: (go b) (? (0 <= fsub b "\r\n\r\n" 0) b (see s @ -1 b ch (unsee s ch, go (b + chug s)))) (go ""))
   (pl-serve l) (: _ (await l) s (accept l)
                   _ (? (hot? s) (: _ (pl-req s) (say s station, flush s, close s)) 0)
                   (pl-serve l))
   lp (test-listen 0) srv (twirl (_ \ pl-serve (lp 1)) ())
   url ("http://127.0.0.1:" + show <lp + "/live")
   _ (test (core-send c ['consume 0] = ['ok]) (<(core-send c ['add url]) = 'ok) (titles () = ["love radio"])
           (core-send c ['play 0] = ['ok]) (waits 'state 'stop 150)
           (titles () = ["two"]))
   _ (freeze srv)
   ; an ogg chain: two flac --ogg links, TITLE=c1 then TITLE=c4. queued it says c1; played out,
   ; the second link's tags retitle it
   _ (? (sh "command -v flac >/dev/null" @ (0 . _) 1 _ 0)
        (: f (\ n (dir + "/" + n))
           _ (sh ("flac -s -f --ogg --serial-number=101 -T TITLE=c1 " + f "a.wav" + " -o " + f "c1.oga"
                  + " && flac -s -f --ogg --serial-number=104 -T TITLE=c4 " + f "b.wav" + " -o " + f "c4.oga"
                  + " && cat " + f "c1.oga" + " " + f "c4.oga" + " > " + f "ch.oga"))
           (test (core-send c ['clear] = ['ok]) (<(core-send c ['add (f "ch.oga")]) = 'ok) (titles () = ["c1"])
                 (core-send c ['play 0] = ['ok]) (waits 'state 'stop 150)
                 (titles () = ["c4"])))
        (gate-partly "player: no flac here, the ogg chain's retitle is not run"))
   _ (core-close c)
   ; the verb speaks the same messages on stdin and stdout
   _ (test (sh ("printf '(ping)\\n(bye)\\n' | HORN=none out/love player --pipe | tail -2")
              = (0 . "(ok)\n(ok)\n"))
           (sh ("printf '(nonsense\\n(bye)\\n' | HORN=none out/love player --pipe | sed -n 3p")
              = (0 . "(err \"a message is [verb arg ..]\")\n")))
   (hark ["rm" "-rf" dir], 0))

(test_fin (), puts "player: ok", putc 10, 0)
