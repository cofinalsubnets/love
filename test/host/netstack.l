; test/host/netstack.l -- src/apps/net: two stacks in one love over wire.l. arp, ping, udp, a
; dropped fragment, arp giving up; tcp a megabyte each way under loss with the window shut and
; the sequence wrapping, close in both orders, refused, reset. all on virtual ms, seeded
; run: cat test/00-init.l test/host/netstack.l | out/love
(borrow "src/apps/net/wire.l")
(borrow "src/apps/net/ip.l")
(borrow "src/apps/net/tcp.l")
(borrow '(wire net tcp bytes))

(: ipa (quad 10 0 0 1))
(: ipb (quad 10 0 0 2))
(: (pair seed o)
    (: a (net-make (string [2 0 0 0 0 1]) ipa seed)
       b (net-make (string [2 0 0 0 0 2]) ipb (seed + 1))
       (tcp-on a, tcp-on b, [(wire-make seed o) a b])))
(: lossy {'drop 30 'dup 10 'reorder 50 'delay 2 'jitter 5})
; an established pair: the client's tcb and the server's
(: (open2 w a b now)
    (: _ (tcp-listen b 80)
       c (tcp-connect a ipb 80 now)
       s {'t ()}
       t (net-run w a b now 20000 (_ \ s 't = () ? (pin s 't (tcp-accept b 80), 0) 1))
       [t c (s 't)]))

; arp, ping, udp; an unbound port and a fragment dropped; no one at .9
(: p (pair 3 {'delay 1}) w (p 0) a (p 1) b (p 2)
   _ (net-ping a ipb 9 1 "hi" 0)
   _ (udp-bind b 7)
   _ (udp-send a ipb 5000 7 "hello" 0)
   t1 (net-run w a b 0 100 (_ \ two? (net-pongs a) && two? (b 'udp 7)))
   _ (test (t1 != ())
           (net-pongs a @ [[src 9 1 "hi" _]] (src = ipb) _ 0)
           (udp-recv b 7 = [ipa 5000 "hello"]) (udp-recv b 7 = ())
           (string? (arp-mac a ipb t1)) (string? (arp-mac b ipa t1))
           (a 'drops = 0) (b 'drops = 0))
   _ (udp-send a ipb 5000 8 "x" t1)
   _ (net-run w a b t1 10 (_ \ 0))
   _ (test (b 'drops = 1))
   ; the first half of a fragmented datagram, more to come
   h (string [69 0] + wrbe 28 2 + wrbe 1 2 + string [32 0 64 17] + zbytes 2 + ipa + ipb)
   f (string [2 0 0 0 0 2 2 0 0 0 0 1 8 0] + snip h 0 10 + wrbe (ip-sum h) 2 + snip h 12 20
      + wrbe 5000 2 + wrbe 7 2 + wrbe 8 2 + zbytes 2)
   _ (net-rx b f t1)
   _ (test (b 'drops = 2) (udp-recv b 7 = ()))
   _ (net-ping a (quad 10 0 0 9) 1 1 "?" t1)
   _ (net-run w a b t1 5000 (_ \ 0))
   (test (keys (a 'pend) = ()) (a 'drops = 1) (#(net-pongs a) = 1)))

; a megabyte one way and 300k the other, lossy, b reading in bursts so its window shuts, both
; sequences over 2^32, then the client's close first
(: p (pair 11 lossy) w (p 0) a (p 1) b (p 2)
   _ (pin a 'iss 4294967000)
   _ (pin b 'iss 4294960000)
   blk (string (map (i \ i * 7 + 3 & 255) ^4093))
   big (join "" (map (_ \ blk) ^256))
   back (snip big 0 300000)
   o (open2 w a b 0) t0 (o 0) c (o 1) v (o 2)
   s {'ai 0 'bi 0 'ad () 'bd () 'ae 0 'be 0 'shut 0}
   (pump st t src i now)
    (: n (s i)
       (n < #src ? (pin s i (n + tcp-write st t (snip src n (min #src (n + 20000))) now), 0)
          (t 'fin) 0
          (tcp-close st t now)))
   (drain st t d e now)
    (tcp-read st t now @ r (r = () ? (pin s e 1) (0 < #r ? (pin s d (r . s d)) 0)))
   (step now)
    (pump a c big 'ai now, pump b v back 'bi now, drain a c 'ad 'ae now,
     now % 400 < 40 ? (drain b v 'bd 'be now) 0,
     v 'awin = 0 ? (pin s 'shut 1) 0,
     s 'ae && s 'be)
   t2 (net-run w a b t0 200000 step)
   gb (join "" (rev (s 'bd)))
   ga (join "" (rev (s 'ad)))
   _ (test (t2 != ()) (#gb = #big) (gb = big) (#ga = #back) (ga = back) (s 'shut)
           (c 'nxt < 4294967000) (v 'nxt < 4294960000) (20 < w 'lost))
   ; one in time-wait a while, then both gone
   t3 (net-run w a b t2 20000 (_ \ tcp-state c = 'closed && tcp-state v = 'closed))
   (test (t3 != ()) (tcp-err c = ()) (tcp-err v = ())
         (keys (a 'tcbs) = ()) (keys (b 'tcbs) = ())))

; the server closes first, lossy
(: p (pair 21 lossy) w (p 0) a (p 1) b (p 2)
   o (open2 w a b 0) t0 (o 0) c (o 1) v (o 2)
   _ (tcp-write b v "bye" t0)
   _ (tcp-close b v t0)
   got {'d ""}
   t1 (net-run w a b t0 20000
        (now \ tcp-read a c now @ r (r = () ? 1 (pin got 'd (got 'd + r), 0))))
   _ (test (t1 != ()) (got 'd = "bye") (tcp-state c = 'close-wait))
   _ (tcp-close a c t1)
   t2 (net-run w a b t1 20000 (_ \ tcp-state c = 'closed))
   _ (test (t2 != ()) (elem (tcp-state v) '(time-wait closed)))
   t3 (net-run w a b t2 20000 (_ \ tcp-state v = 'closed))
   (test (t3 != ()) (tcp-err c = ()) (tcp-err v = ())))

; a closed port refuses; an abort resets the peer
(: p (pair 31 {'delay 1}) w (p 0) a (p 1) b (p 2)
   c (tcp-connect a ipb 81 0)
   _ (test (net-run w a b 0 1000 (_ \ tcp-state c = 'closed) != ()) (tcp-err c = 'refused))
   o (open2 w a b 10) t0 (o 0) c (o 1) v (o 2)
   _ (tcp-write a c "lost" t0)
   _ (tcp-abort a c t0)
   (test (tcp-state c = 'closed)
         (net-run w a b t0 1000 (_ \ tcp-state v = 'closed) != ()) (tcp-err v = 'reset)))

(test_fin ())
(puts "netstack: ok\n")
