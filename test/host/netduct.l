; test/host/netduct.l -- sock-port: a connection as a duct, worked by say, see, chug, cue?, seal
; and close from tasks, while a pump task turns the stack over its loopback. a megabyte each
; way against a reader that starts late, then close from either side
; run: cat test/00-init.l test/host/netduct.l | out/love
(borrow 'posix)
(borrow "src/apps/net/wire.l")
(borrow "src/apps/net/ip.l")
(borrow "src/apps/net/tcp.l")
(borrow "src/apps/net/sock.l")
(borrow '(wire net tcp sock bytes))

(: st (net-make (string [2 0 0 0 0 1]) (quad 10 0 0 1) 9))
(: _ (tcp-on st, pin st 'msl 50))
; the pump on the clock, as a seat's runs, until told to stop; 't the clock it last turned at
(: pk {'t (clock 0) 'stop 0})
(: (pumping _) (pk 'stop ? 0 (pin pk 't (clock 0), net-pump st (pk 'nic) (pk 't), rest 0, pumping 0)))
(: _ (pin pk 'nic (nic-loop 0)))
(: pumper (twirl pumping 0))

; a connection's both ends as ducts
; f true within about 20 s of the clock, or 0
(: (wait-for f) (:- (go 20000) (go n) (f () ? 1 (n = 0 ? 0 (rest 1, go (n - 1))))))
(: (pair port)
    (: l (sock-listen st port (pk 't))
       c (sock-connect st ['tcp "127.0.0.1" port] (pk 't))
       _ (wait-for (_ \ sock-readable? l))
       s (sock-accept l (pk 't))
       _ (wait-for (_ \ sock-writable? c))
       [(sock-port c) (sock-port s) l c s]))
; a port read to its end: see parks while dry, chug takes the run
(: (drain p) (:- (go ()) (go acc) (see p @ -1 (join "" (rev acc)) ch (go (chug p . string ch . acc)))))
(: (pour p s) (:- (go 0) (go i) (i < #s ? (say p (snip s i (min #s (i + 9000))), go (i + 9000)) (flush p))))

(: blk (string (map (i \ i * 31 + 7 & 255) ^4093)))
(: big (join "" (map (_ \ blk) ^256)))
(: back (snip big 777 #big))

; both ways at once, each writer sealing its half; the server's reader starts late, so the
; client's writer must wait on it: its last say lands after the reader began
(: q (pair 7100) cp (q 0) sp (q 1) c (q 3) s (q 4)
   _ (test (hot? cp) (hot? sp) (!(cue? sp)) (sock-port 5 = 'badarg))
   marks {'w () 'r ()}
   cw (twirl (_ \ (pour cp big, seal cp 1, pin marks 'w (pk 't), 1)) 0)
   sw (twirl (_ \ (pour sp back, seal sp 1, 1)) 0)
   cr (twirl (_ \ drain cp) 0)
   _ (rest 300)
   t0 (pk 't)
   sr (twirl (_ \ drain sp) 0)
   up (catch sr)
   down (catch cr)
   _ (catch cw) _ (catch sw)
   _ (test (#up = #big) (up = big) (#down = #back) (down = back)
           ; the writer finished only after the late reader began
           (t0 < marks 'w)
           (see cp = -1) (see sp = -1) (cue? cp))
   _ (close cp) _ (close sp)
   (test (wait-for (_ \ sock-closed? c && sock-closed? s && keys (st 'tcbs) = ()))
         (sock-err c = ()) (sock-err s = ())))

; the server closes first: the client reads to the end, writes on, then closes
(: q (pair 7101) cp (q 0) sp (q 1) c (q 3) s (q 4)
   _ (say sp "bye", close sp)
   _ (test (drain cp = "bye"))
   _ (say cp "late", flush cp)
   _ (close cp)
   (test (wait-for (_ \ keys (st 'tcbs) = ()))))

; the client closes first; the server hears its end and answers before closing
(: q (pair 7102) cp (q 0) sp (q 1) c (q 3) s (q 4)
   rd (twirl (_ \ drain cp) 0)
   _ (say cp "hi", seal cp 1)
   _ (test (drain sp = "hi"))
   _ (say sp "ho", close sp)
   _ (test (catch rd = "ho"))
   _ (close cp)
   (test (wait-for (_ \ keys (st 'tcbs) = ())) (sock-err c = ()) (sock-err s = ())))

; a reset reaches the program as its end, and its writes fail quietly
(: q (pair 7103) cp (q 0) sp (q 1) c (q 3) s (q 4)
   _ (tcp-abort st (s 't) (pk 't))
   (test (drain cp = "") (wait-for (_ \ sock-err c = 'econnreset))))

(: _ (pin pk 'stop 1, catch pumper))
(test_fin ())
(puts "netduct: ok\n")
