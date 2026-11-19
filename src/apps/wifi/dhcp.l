; src/apps/wifi/dhcp.l -- a dhcp client (rfc 2131) over sock.c's (packet ifindex 0x0800): the
; link has no address yet, so the ip and udp headers are laid and read here. the server is
; asked to broadcast; a reply not ours by xid, port or chaddr is skipped
;   (dhcp ifindex mac ms) -> (ip plen router dns lease) as quads and seconds, () on none in time
;   (dhcp-frame mac xid opts) (dhcp-read b xid) -> a request's ip packet; a reply as (type yiaddr opts)
;   (quad-show q) -> "a.b.c.d"
;   (dhcp-name s) -> the kernel's hostname s as option 12, in a list; () for none
(module (dhcp dhcp dhcp-frame dhcp-read dhcp-opts dhcp-name quad-show ip-sum within)
(borrow '(posix bytes hashes))
(:
   (quad-show q) (join "." (map (i \ show (q i)) ^4))
   ; the ones' complement sum of big-endian halves
   (ip-sum s)
    (: n #s
       (go i a) (n <= i ? a (go (i + 2) (a + (s i << 8) + (i + 1 < n ? (s (i + 1)) 0))))
       (fold a) (a > 65535 ? (fold ((a & 65535) + (a >> 16))) a)
       ((fold (go 0 0)) ^ 65535))
   (opt c v) (string c + string #v + v)
   ; the kernel says (none) until something names it
   (dhcp-name s) (: n (snip s 0 (? (0 < #s && s (#s - 1) = 10) (#s - 1) #s))
                   (0 < #n && n != "(none)" ? [(opt 12 n)] ()))
   any (zbytes 4)
   all (string [255 255 255 255])
   (dhcp-frame mac xid opts)
    (: bootp (string [1 1 6 0] + wrbe xid 4 + wrbe 0 2 + wrbe 32768 2 + zbytes 16 + mac + zbytes 10
              + zbytes 192 + string [99 130 83 99] + join "" opts + string 255)
       udp (wrbe 68 2 + wrbe 67 2 + wrbe (8 + #bootp) 2 + wrbe 0 2 + bootp)
       h0 (string [69 0] + wrbe (20 + #udp) 2 + zbytes 4 + string [64 17] + zbytes 2 + any + all)
       (snip h0 0 10 + wrbe (ip-sum h0) 2 + snip h0 12 20 + udp))
   ; the options from i: ((code value) ..), pads skipped, to the end mark
   (dhcp-opts s i)
    (: n #s
       (go i) (? (n <= i || s i = 255) () (s i = 0) (go (i + 1))
                 (n < i + 2 + s (i + 1)) ()
                 ([(s i) (snip s (i + 2) (i + 2 + s (i + 1)))] . go (i + 2 + s (i + 1))))
       (go i))
   (get os c d) (atom? os ? d (<os @ [k v] (k = c ? v (get >os c d))))
   (dhcp-read b xid)
    (: h (#b < 20 ? 0 ((b 0 & 15) * 4))
       o (h + 8)
       (? (h < 20 || #b < o + 240 || b 9 != 17 || rdbe b (h + 2) 2 != 68 || b o != 2 || rdbe b (o + 4) 4 != xid
           || snip b (o + 236) (o + 240) != string [99 130 83 99]) ()
          (: os (dhcp-opts b (o + 240))
             [((get os 53 (string 0)) 0) (snip b (o + 16) (o + 20)) os])))

   ; (f 0)'s answer, or 0 when ms pass first
   (within ms f)
    (: r (twirl f ())
       w (twirl (_ \ (rest ms, freeze r)) ())
       d (catch r)
       (freeze w, d))
   ; the next reply of a type in ts, () on none in ms
   (await p xid ts ms)
    (within ms (_ \ (: (go 0) (recv p @ r (? !(two? r) ()
                                              (dhcp-read (r 1) xid @ m (m != () && elem (<m) ts ? m (go 0)))))
                   (go 0))))
   (plen q) (net (map (i \ (: (bits v) (v = 0 ? 0 ((v & 1) + bits (v >> 1))) (bits (q i)))) ^4))
   (dhcp ifindex mac ms)
    (: p (bind ['packet ifindex 2048])
       (? !(hot? p) ()
          (: xid (rdbe (hex2b (sha1 (mac + show (clock 0)))) 0 4)
             cid (opt 61 (string 1 + mac))
             ask (opt 55 (string [1 3 6 15 51 54]))
             nm (uread "/proc/sys/kernel/hostname" @ [1 s] (dhcp-name s) ())
             bc (string [255 255 255 255 255 255])
             (out opts) (send p [bc 2048] (dhcp-frame mac xid opts))
             (try k)
              (k = 0 ? ()
                 (: _ (out ([(opt 53 (string 1)) cid ask] + nm))
                    o (await p xid [2] ms)
                    (? !(two? o) (try (k - 1))
                       (: sid (get (o 2) 54 "")
                          _ (out ([(opt 53 (string 3)) cid (opt 50 (o 1)) (opt 54 sid) ask] + nm))
                          a (await p xid [5 6] ms)
                          (? (!(two? a) || <a = 6) (try (k - 1))
                             (: os (a 2) m (get os 1 (string [255 255 255 0]))
                                [(a 1) (plen m) (get os 3 "") (get os 6 "") (rdbe (get os 51 (zbytes 4)) 0 4)]))))))
             r (try 4)
             (close p, r))))
))
