; test/host/netstream.l -- stream-nic: two stacks whose frames ride ducts as length records, the
; way inle's /dev/ecm carries them, a relay moving the bytes a few at a time so records arrive cut
; run: cat test/00-init.l test/host/netstream.l | out/love
(borrow "src/apps/net/wire.l")
(borrow "src/apps/net/ip.l")
(borrow '(wire net bytes))

(: ipa (quad 10 7 0 1) ipb (quad 10 7 0 2)
   a (net-make (string [2 0 0 0 0 1]) ipa 5)
   b (net-make (string [2 0 0 0 0 2]) ipb 6)
   da (duct 0) db (duct 0)
   na (stream-nic da da) nb (stream-nic db db)
   ; what one side wrote, fed to the other seven bytes a turn
   hold {'a "" 'b ""}
   (move from to k)
    (: s (hold k + (duct-take from @ () "" s s))
       n (#s = 0 ? 0 (duct-feed to (snip s 0 (min 7 #s))))
       (pin hold k (snip s n #s)))
   (turn t) (net-pump a na t, net-pump b nb t, move da db 'a, move db da 'b)
   (run t ms done) (? (done ()) t (ms = 0) () (turn t, run (t + 1) (ms - 1) done))
   _ (net-ping a ipb 9 1 "hi" 0)
   _ (udp-bind b 7)
   _ (udp-send a ipb 5000 7 "hello" 0)
   t1 (run 0 2000 (_ \ two? (net-pongs a) && two? (b 'udp 7)))
 (test (t1 != ())
       (net-pongs a @ [[src 9 1 "hi" _]] (src = ipb) _ 0)
       (udp-recv b 7 = [ipa 5000 "hello"])
       (a 'drops = 0) (b 'drops = 0)))

(test_fin ())
(puts "netstream: ok\n")
