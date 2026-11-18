; src/apps/net/ip.l -- a stack's lower half over ethernet frames: arp, ipv4, icmp echo, udp.
; a stack is a tablet; frames come in by net-rx and leave by net-tx, so any nic door (virtio-net,
; usb ecm, wifi, a hosted packet socket, wire.l) carries them. the clock is the caller's, in ms.
; fragments are dropped, counted; tcp and the rest register by protocol number
;   (net-make mac ip seed)        -> a stack; mac 6 bytes, ip 4, seed its rng's
;   (net-rx st f now) (net-tx st) a frame in; the frames out since the last net-tx
;   (net-tick st now)             arp's retries, then each registered ticker
;   (net-pump st nic now)         one turn: frames out to the nic and in from it, packets to
;                                 itself delivered, then the tick. a nic is {'put (\ f now ..)
;                                 'take (now \ frames)}: (nic-loop) hears itself, (wire-nic w side)
;   (stream-nic r w)              a nic over ports carrying records, two bytes of length (high
;                                 first) then the frame: inle's /dev/ecm, read from r, written to w
;   (net-run w a b now ms done)   a and b over wire w a ms at a time: both pumped, until
;                                 (done t) (answers t) or ms pass (answers ())
;   (net-ask st f)                (f now) run by the pump's next turn, its answer this task's: tasks
;                                 beside a pump task touch the stack only so. no pump, no answer
;   (ip-send st dst proto b now)  an ipv4 packet, held for arp where the mac is not known; to
;                                 itself or 127/8 it never reaches the nic. (ip-src st dst) its source
;   (udp-bind st port) (udp-unbind st port) (udp-send st dst sport dport b now)
;   (udp-recv st port) -> (src sport b) | ()
;   (net-ping st dst id seq b now) (net-pongs st) -> ((src id seq b at) ..), oldest first
;   (ip-sum s) (ip-pseudo src dst proto n) (quad a b c d) (ip-show q)
(module (net net-make net-rx net-tx net-tick net-pump net-run net-ask nic-loop wire-nic stream-nic net-rand ip-send
         ip-send-from ip-src ip-sum ip-pseudo quad ip-show udp-bind udp-unbind udp-send udp-recv
         net-ping net-pongs arp-mac)
(borrow '(bytes wire))
(:
   arp-life 60000  arp-wait 1000  arp-tries 3  pend-max 64
   bmac (string [255 255 255 255 255 255])
   bip (string [255 255 255 255])
   (quad a b c d) (string [a b c d])
   (ip-show q) (join "." (map (i \ show (q i)) ^4))
   ; the ones' complement sum of big-endian halves, complemented
   (ip-sum s)
    (: n #s
       (go i a) (n <= i ? a (go (i + 2) (a + (s i << 8) + (i + 1 < n ? (s (i + 1)) 0))))
       (fold a) (a > 65535 ? (fold ((a & 65535) + (a >> 16))) a)
       ((fold (go 0 0)) ^ 65535))
   (ip-pseudo src dst proto n) (src + dst + string [0 proto] + wrbe n 2)
   (net-rand st) (st 'x * 48271 % 2147483647 @ x (pin st 'x x, x))
   (net-make mac ip seed)
    {'mac mac 'ip ip 'x (seed % 2147483646 + 1) 'out () 'arp {} 'pend {} 'udp {} 'pongs ()
     'proto {} 'ticks () 'id 0 'drops 0 'lo ()
     'asks {} 'told {}}
   (net-tx st) (rev (st 'out) @ fs (pin st 'out (), fs))
   (eth-out st dmac ty b)
    (: f (dmac + st 'mac + wrbe ty 2 + b)
       (pin st 'out ((#f < 60 ? (f + zbytes (60 - #f)) f) . st 'out)))
   (drop st) (pin st 'drops (st 'drops + 1), 0)

   ; --- arp ---------------------------------------------------------------------
   (arp-frame op tha tpa st) (wrbe 1 2 + wrbe 2048 2 + string [6 4] + wrbe op 2 + st 'mac + st 'ip + tha + tpa)
   (arp-who st ip) (eth-out st bmac 2054 (arp-frame 1 (zbytes 6) ip st))
   ; the mac for ip while its entry lives, else ()
   (arp-mac st ip now) (peep (st 'arp) ip () @ [m e] (now < e ? m ()) _ ())
   (arp-learn st ip m now)
    (: _ (pin (st 'arp) ip [m (now + arp-life)])
       p (peep (st 'pend) ip ())
       (two? p ? (pull (st 'pend) ip 0, each (rev <p) (b \ eth-out st m 2048 b)) 0))
   (arp-in st b now)
    (? (#b < 28 || rdbe b 2 2 != 2048 || b 4 != 6 || b 5 != 4) (drop st)
       (: op (rdbe b 6 2) sha (snip b 8 14) spa (snip b 14 18) tpa (snip b 24 28)
          ours (tpa = st 'ip)
          ((ours || two? (peep (st 'arp) spa ())) ? (arp-learn st spa sha now) 0,
           (ours && op = 1) ? (eth-out st sha 2054 (arp-frame 2 sha spa st)) 0)))
   (arp-tick st now)
    (each (keys (st 'pend))
      (ip \ (st 'pend ip @ [q k at]
               (? (now < at) 0
                  (k < arp-tries) (arp-who st ip, pin (st 'pend) ip [q (k + 1) (now + arp-wait)])
                  (pull (st 'pend) ip 0, each q (_ \ drop st))))))

   ; --- ipv4 --------------------------------------------------------------------
   lo1 (quad 127 0 0 1)
   (lo? a) (a 0 = 127)
   (ip-src st dst) (lo? dst ? lo1 (st 'ip))
   (via st dst b now)
    (? (dst = st 'ip || lo? dst) (pin st 'lo (b . st 'lo))
       (dst = bip) (eth-out st bmac 2048 b)
       (arp-mac st dst now @ m
          (? (string? m) (eth-out st m 2048 b)
             (peep (st 'pend) dst () @ [q k at] (pin (st 'pend) dst [(#q < pend-max ? (b . q) q) k at])
                                       _ (arp-who st dst, pin (st 'pend) dst [[b] 1 (now + arp-wait)])))))
   (ip-send st dst proto b now) (ip-send-from st (ip-src st dst) dst proto b now)
   (ip-send-from st src dst proto b now)
    (: id ((st 'id + 1) & 65535)
       _ (pin st 'id id)
       h (string [69 0] + wrbe (20 + #b) 2 + wrbe id 2 + string [64 0 64 proto] + zbytes 2 + src + dst)
       (via st dst (snip h 0 10 + wrbe (ip-sum h) 2 + snip h 12 20 + b) now))
   (ip-in st b now)
    (: h (#b < 20 ? 0 ((b 0 & 15) * 4))
       n (#b < 4 ? 0 (rdbe b 2 2))
       (? ((b 0 >> 4) != 4 || h < 20 || n < h || #b < n || ip-sum (snip b 0 h) != 0) (drop st)
          ((rdbe b 6 2 & 16383) != 0) (drop st)               ; a fragment: more to come, or not the first
          (: dst (snip b 16 20) src (snip b 12 16) p (snip b h n) pr (b 9)
             (? (dst != st 'ip && dst != bip && !(lo? dst)) (drop st)
                (pr = 1) (icmp-in st src p now)
                (pr = 17) (udp-in st src dst p now)
                (peep (st 'proto) pr () @ f (f != () ? (f st src dst p now) (drop st)))))))

   ; --- icmp echo -----------------------------------------------------------------
   (icmp st dst ty rest now)
    (: m (string [ty 0] + zbytes 2 + rest)
       (ip-send st dst 1 (snip m 0 2 + wrbe (ip-sum m) 2 + snip m 4 #m) now))
   (net-ping st dst id seq b now) (icmp st dst 8 (wrbe id 2 + wrbe seq 2 + b) now)
   (net-pongs st) (rev (st 'pongs))
   (icmp-in st src m now)
    (? (#m < 8 || ip-sum m != 0) (drop st)
       (m 0 = 8) (icmp st src 0 (snip m 4 #m) now)
       (m 0 = 0) (pin st 'pongs ([src (rdbe m 4 2) (rdbe m 6 2) (snip m 8 #m) now] . st 'pongs))
       0)

   ; --- udp -----------------------------------------------------------------------
   (udp-bind st port) (pin (st 'udp) port (peep (st 'udp) port ()))
   (udp-unbind st port) (pull (st 'udp) port 0)
   (udp-send st dst sp dp b now)
    (: u (wrbe sp 2 + wrbe dp 2 + wrbe (8 + #b) 2 + zbytes 2 + b)
       c (ip-sum (ip-pseudo (ip-src st dst) dst 17 #u + u))
       (ip-send st dst 17 (snip u 0 6 + wrbe (c = 0 ? 65535 c) 2 + snip u 8 #u) now))
   (udp-in st src dst u now)
    (: n (#u < 8 ? 0 (rdbe u 4 2))
       dp (#u < 8 ? 0 (rdbe u 2 2))
       (? (n < 8 || #u < n) (drop st)
          (rdbe u 6 2 != 0 && ip-sum (ip-pseudo src dst 17 n + snip u 0 n) != 0) (drop st)
          (peep (st 'udp) dp 'none @ q (q != 'none ? (pin (st 'udp) dp (q + [[src (rdbe u 0 2) (snip u 8 n)]])) (drop st)))))
   (udp-recv st port) (peep (st 'udp) port () @ (d . r) (pin (st 'udp) port r, d) _ ())

   ; --- the frame in, the clock, a pair over a wire ---------------------------------
   (net-rx st f now)
    (: dm (snip f 0 6)
       (? (#f < 14 || (dm != st 'mac && dm != bmac)) (drop st)
          (rdbe f 12 2 @ 2054 (arp-in st (snip f 14 #f) now)
                         2048 (ip-in st (snip f 14 #f) now)
                         _ (drop st))))
   (net-tick st now) (arp-tick st now, each (st 'ticks) (f \ f st now))
   ; an ask rides under its task's pid, so posting and answering each pin one key
   (net-ask st f)
    (: me (myself ()) told (st 'told)
       _ (pin (st 'asks) me f)
       (go _) (peep told me told @ r (r == told ? (rest 1, go 0) (pull told me 0, r)))
       (go 0))
   (net-pump st nic now)
    (each (sort (keys (st 'asks))) (k \ pull (st 'asks) k () @ f (pin (st 'told) k (f now))),
     each (net-tx st) (f \ (nic 'put) f now),
     each ((nic 'take) now) (f \ net-rx st f now),
     rev (st 'lo) @ ps (pin st 'lo (), each ps (p \ ip-in st p now)),
     net-tick st now)
   ; a nic that hears what it sends, for a stack alone
   (nic-loop _) (: q {'f ()} {'put (\ f _ (pin q 'f (f . q 'f))) 'take (_ \ rev (q 'f) @ fs (pin q 'f (), fs))})
   ; a take reads only what is waiting, and keeps a record cut short for the next
   (stream-nic r w)
    (: q {'b ""}
       (cut b fs) (? ((#b < 2) || (#b < 2 + rdbe b 0 2)) (pin q 'b b, rev fs)
                     (rdbe b 0 2 @ n (cut (snip b (2 + n) #b) (snip b 2 (2 + n) . fs))))
       (more b) (cue? r ? (see r @ -1 b c (more (b + string c + chug r))) b)
       {'put (\ f _ (say w (wrbe #f 2 + f), flush w)) 'take (_ \ cut (more (q 'b)) ())})
   (wire-nic w side) {'put (\ f now (wire-put w side f now)) 'take (now \ wire-take w side now)}
   (net-run w a b now ms done)
    (: na (wire-nic w 0) nb (wire-nic w 1)
       (go t) (? (done t) t (now + ms < t) () (net-pump a na t, net-pump b nb t, go (t + 1)))
       (go now))
)
) ; module net
