; src/apps/dns.l -- the resolver. `connect` takes only a dotted quad, and getaddrinfo
; has no nonblocking form, so names resolve up here where a lookup can park:
;
;   (resolve "example.org")      ; -> a list of ipv4 charms, in the server's order
;   (resolve6 "example.org")     ; -> a list of ipv6 texts, the spelling `send` takes
;   (dial "example.org" 80)      ; -> a port, or ()  -- resolve, then connect
;   (resolve-in conf hosts name) ; the same, against named config paths
;   (resolve-via conf hosts px name) ; and netd's socket px, asked when conf names no server
;
; a lookup is three tasks: receiver on the socket, watchdog on the clock, caller in
; `catch`; the first to finish wins. wire format after moonlibc's dns.c.
; /etc/hosts first, then resolv.conf's nameservers over udp, search domains on a miss.
; android has no resolv.conf: there netd answers on /dev/socket/dnsproxyd, as it does bionic.
; no tcp fallback: a truncated answer is a scare. presence is a one-list (0.0.0.0 nets 0).
(module (dns dial resolve dns-show
         dns-answers dns-ask dns-conf dns-query dns-servers
         dns-hosts dns-labels resolve-in resolve-via dns-proxy dns-quad
         dns-qtype dns-qedns dns-raw dns-id dns-match? dns-name dns-records dns-v6
         resolve6 resolve6-in dns-hosts6 dns-colon? dns-walk6)
(borrow 'posix)
(borrow 'bytes)
(:
   ; --- files, lines, words ---
   ; absent config reads as "".
   (dns-look path) (uread path @ [1 s] s "")

   (dns-eol t i n) (n <= i || t i = 10 ? i (dns-eol t (i + 1) n))
   (dns-lines t)
    (: n #t
       (go i) (n <= i ? () (dns-eol t i n @ j (snip t i j . go (j + 1))))
       (go 0))

   ; a line's whitespace-separated words, stopping at a '#'.
   (dns-blank? c) (c = 32 || c = 9)
   (dns-words l)
    (: n #l
       (skip i) (i < n && dns-blank? (l i) ? (skip (i + 1)) i)
       (end i)  (n <= i || dns-blank? (l i) || l i = 35 ? i (end (i + 1)))
       (go i)   (skip i @ s
                   (n <= s || l s = 35 ? ()
                      (end s @ e (snip l s e . go e))))
       (go 0))

   ; --- a dotted quad ---
   ; -> [address in host order] | (); must agree with sock.c's `quad` on what is numeric.
   (dns-digit? c) (47 < c < 58)
   (dns-quad s)
    (: n #s
       (oct i a k)
        (: (dig j v any)
            (j < n && dns-digit? (s j) ?
               (v * 10 + s j - 48 @ w (255 < w ? () (dig (j + 1) w 1)))
               (any ? [j v] ()))
           r (dig i 0 0)
           (atom? r ? ()
              (: j <r  b (a * 256 + <>r)
                 (? (k = 1) (n <= j ? [b] ())
                    (j < n && s j = 46) (oct (j + 1) b (k - 1))))))
       (oct 0 0 4))

   ; --- the wire ---

   ; a name as length-prefixed labels, NUL-terminated; () if a label is empty or > 63.
   (dns-labels h)
    (: n #h
       (dot i) (n <= i || h i = 46 ? i (dot (i + 1)))
       (go i) (n <= i ? (string 0)
                 (: j (dot i)  l (j - i)
                    (l = 0 || 63 < l ? ()
                       (go (j + 1) @ r
                          (string? r && string l + snip h i j + r)))))
       (0 < n && go 0))

   ; the query packet: RD set, one question of type t, class IN
   (dns-qtype id h t)
    (dns-labels h @ q
       (string? q &&
        wrbe id 2 + wrbe 256 2 + wrbe 1 2 + wrbe 0 2
         + wrbe 0 2 + wrbe 0 2 + q + wrbe t 2 + wrbe 1 2))
   (dns-query id h) (dns-qtype id h 1)
   ; ..with an EDNS0 OPT (RFC 6891) offering 1232 bytes, so a long answer is not cut at 512
   (dns-qedns id h t)
    (dns-qtype id h t @ q
       (string? q && snip q 0 10 + wrbe 1 2 + snip q 12 #q
                      + string 0 + wrbe 41 2 + wrbe 1232 2 + wrbe 0 2 + wrbe 0 2 + wrbe 0 2))

   ; skip a name at `pos` -> the position after it, or -1. a compression pointer
   ; (top two bits set) is two bytes and ends the name.
   (dns-skip r pos n)
    (n <= pos ? -1
       (r pos @ l
          (? (l = 0) (pos + 1)
             (l & 192 = 192) (n < pos + 2 ? -1 (pos + 2))
             (dns-skip r (pos + l + 1) n))))

   ; a response -> the a addresses in server order, () if no, 'torn on TC. cnames ride past.
   (dns-answers r id)
    (: n #r
       (go k pos)
        (k < 1 || n <= pos ? ()
           (dns-skip r pos n @ p
              (p < 0 || n < p + 10 ? ()
                 (: ty (rdbe r p 2)  cl (rdbe r (p + 2) 2)  rl (rdbe r (p + 8) 2)
                    q (p + 10)
                    (? (n < q + rl) ()
                       (ty = 1 && cl = 1 && rl = 4)
                         ((rdbe r q 2 * 65536 + rdbe r (q + 2) 2) . go (k - 1) (q + rl))
                       (go (k - 1) (q + rl)))))))
       (? (n < 12) ()
          !(rdbe r 0 2 = id) ()                      ; not our question
          (0 < r 2 & 2) 'torn                        ; TC
          (0 < r 3 & 15) ()                          ; NXDOMAIN, SERVFAIL, ..
          (dns-skip r 12 n @ p0
             (p0 < 0 ? () (go (rdbe r 6 2) (p0 + 4))))))

   ; --- one question to one nameserver ---
   ; a query id from /dev/urandom; no entropy is a scare, never a guessable id
   (dns-id _)
    (: q (open "/dev/urandom" "r")
       _ (nom? q ? (scare 'no-entropy q) 0)
       (byte _) (see q @ c (c < 0 ? (close q, scare 'no-entropy "/dev/urandom") c))
       hi (byte 0) lo (byte 0)
       (close q, hi * 256 + lo))

   ; is r an answer to q: qr bit, id, and the question byte for byte (edns excluded)
   (dns-match? q r)
    (: e (dns-skip q 12 #q)
       qe (e + 4)
       (0 < e && qe <= #r && 0 < r 2 & 128 && rdbe r 4 2 = 1
        && snip r 0 2 = snip q 0 2 && snip r 12 qe = snip q 12 qe))

   ; a packet to a server -> its answer's bytes, () on none within `ms`. a datagram
   ; from anyone but the server, or not an answer to q, is dropped
   (dns-raw ns port q ms)
    (bind ['udp 0] @ (p && hot? p)
     (: from [(dns-show ns) port]
        (take _) (recv p @ d
                    (? !(two? d) ()
                       (<d = from && dns-match? q <>d) d
                       (take 0)))
        _ (send p from q)
        r (twirl take ())
        w (twirl (_ \ (rest ms, freeze r)) ())
        d (catch r)
      (freeze w,
       close p,
       two? d ? <>d)))
   ; -> the addresses, () on no answer
   (dns-ask ns port h ms)
    (: id (dns-id 0)
       q (dns-query id h)
       r (string? q ? (dns-raw ns port q ms))
       (string? r ? (dns-answers r id)))

   ; --- a whole answer, for a person to read ---
   ; -> [the dotted name, the position past it where written], () if it runs off or loops
   (dns-name r pos)
    (: n #r
       (dots l) (? (atom? l) "." !(two? >l) <l (<l + "." + dots >l))
       (go p acc hops after)
        (n <= p || 64 < hops ? ()
           (r p @ l
              (? (l = 0) [(dots (rev acc)) (after < 0 ? (p + 1) after)]
                 (l & 192 = 192)
                  (n <= p + 1 ? ()
                     (go ((l & 63) * 256 + r (p + 1)) acc (hops + 1) (after < 0 ? (p + 2) after)))
                 (n < p + 1 + l) ()
                 (go (p + 1 + l) (snip r (p + 1) (p + 1 + l) . acc) hops after))))
       (go pos () 0 -1))
   ; sixteen bytes -> RFC 5952 text: lower hex, the longest run of 2+ zero groups as ::
   (dns-v6 r q)
    (: gs (map (i \ rdbe r (q + 2 * i) 2) ^8)
       hx "0123456789abcdef"
       (h4 v) (v < 16 ? (string (hx v)) (h4 (v // 16) + string (hx (v % 16))))
       (cat l) (? (atom? l) "" !(two? >l) <l (<l + ":" + cat >l))
       (zrun i st k best)
        (? (8 <= i) (<>best < k ? [st k] best)
           (gs i = 0) (zrun (i + 1) (k = 0 ? i st) (k + 1) best)
           (zrun (i + 1) 0 0 (<>best < k ? [st k] best)))
       b (zrun 0 0 0 [0 0])
       st <b ln <>b
       (ln < 2 ? (cat (map h4 gs))
          (cat (map (i \ h4 (gs i)) ^st) + "::" + cat (map (i \ h4 (gs (st + ln + i))) ^(8 - st - ln)))))
   ; a txt record's strings, each quoted, from q to e
   (dns-txt r q e)
    (e <= q ? ""
       (: l (r q) t (dns-txt r (q + 1 + l) e)
          ("\"" + snip r (q + 1) (min e (q + 1 + l)) + "\"" + (#t ? (" " + t) ""))))
   ; a soa record's seven fields, as nslookup lays them
   (dns-soa r q)
    (: a (dns-name r q) b (two? a ? (dns-name r (a 1)))
       (!(two? b) ? " ?"
          (: p (b 1)
             (u k) (rdbe r (p + 4 * k) 2 * 65536 + rdbe r (p + 4 * k + 2) 2)
             ("\n\torigin = " + <a + "\n\tmail addr = " + <b + "\n\tserial = " + show (u 0)
              + "\n\trefresh = " + show (u 1) + "\n\tretry = " + show (u 2)
              + "\n\texpire = " + show (u 3) + "\n\tminimum = " + show (u 4)))))
   ; -> [rcode authoritative? records], a record [name type text], nslookup's spelling;
   ; 'torn on TC, () for another question's answer
   (dns-records r id)
    (: n #r
       (name-at q) (dns-name r q @ m (two? m ? <m "?"))
       (rd t q l)
        (? (t = 1 && l = 4) (dns-show (rdbe r q 2 * 65536 + rdbe r (q + 2) 2))
           (t = 28 && l = 16) (dns-v6 r q)
           (elem t '(2 5 12)) (name-at q)
           (t = 15) (show (rdbe r q 2) + " " + name-at (q + 2))
           (t = 16) (dns-txt r q (q + l))
           (t = 6) (dns-soa r q)
           ("type " + show t + ", " + show l + " bytes"))
       (go k pos acc)
        (: m (k < 1 ? () (dns-name r pos))
           p (two? m ? <>m n)
           (n < p + 10 ? (rev acc)
              (: ty (rdbe r p 2) rl (rdbe r (p + 8) 2) q (p + 10)
                 (n < q + rl ? (rev acc)
                    (go (k - 1) (q + rl) ([<m ty (rd ty q rl)] . acc))))))
       (? (n < 12 || rdbe r 0 2 != id) ()
          (0 < r 2 & 2) 'torn
          (dns-skip r 12 n @ p0
             [(r 3 & 15) (0 < r 2 & 4) (p0 < 0 ? () (go (rdbe r 6 2) (p0 + 4) ()))])))

   ; --- the two config files ---
   ; every word after `k` on every line starting with it, in file order
   (dns-conf path k)
    (: (go (a . u)) (dns-words a @ (^k . w) (w + go u) (go u))
     (go (dns-lines (dns-look path))))

   ; /etc/hosts: the first line whose address parses and names h exactly -> [addr]
   (dns-hosts path h)
    (: (go (l . u))
     (dns-words l @ w
      (atom? w ? (go u)
       (dns-quad <w @ a
        (two? a && elem h >w ? a (go u)))))
     (go (dns-lines (dns-look path))))
   ; and its v6 lines, the address kept as the text it is
   (dns-hosts6 path h)
    (: (go (l . u))
     (dns-words l @ w
      (? (atom? w) (go u)
         (dns-colon? <w && elem h >w) [<w]
         (go u)))
     (go (dns-lines (dns-look path))))
   (dns-colon? s) ((: (g i) (? (#s <= i) 0 (s i = 58) 1 (g (i + 1)))) 0)

   ; the nameservers in order; 127.0.0.1 when none (musl's and moonlibc's fallback)
   (dns-servers conf)
    (: ns (: (go l) (two? l ?
                     (dns-quad <l @ a
                      (two? a ? ((<a . 53) . go >l) (go >l))))
             (go (dns-conf conf "nameserver")))
       (two? ns ? ns [(2130706433 . 53)]))

   ; --- the door ---
   dns-ms 2500                            ; moonlibc's per-server deadline

   ; ask each server in turn: any answer ends the walk, even no; only silence moves on
   (dns-walk ((a . u) . su) h)
    (dns-ask a u h dns-ms @
     'torn (scare 'torn ['dns h])
     (x && two? x) x
     (dns-walk su h))
   ; the same walk asking aaaa, its answers v6 text
   (dns-walk6 ((a . u) . su) h)
    (: id (dns-id 0)
       r (dns-raw a u (dns-qedns id h 28) dns-ms)
       ((string? r ? (dns-records r id)) @
        'torn (scare 'torn ['dns h])
        (x && two? x) (catmap (d \ ? (d 1 = 28) [(d 2)] ()) (x 2))
        (dns-walk6 su h)))

   ; android's netd: getaddrinfo asked of it by name, family fam (2 or 10), a stream ->
   ; the addresses, () on none or no netd. it answers "222\0", then per address a be32 1,
   ; five be32s (flags family socktype protocol addrlen), the sockaddr, a be32 name length
   ; and the name; a be32 0 ends. netd walks the search domains itself. selinux refuses an
   ; app a stat of the socket and allows the connect, so the connect is the only test
   dns-proxyd "/dev/socket/dnsproxyd"
   (dns-proxy px h fam)
    (connect ['unix px] @ s
       (? !(hot? s) ()
           (: (be n v) (n = 0 ? v (see s @ c (c < 0 ? -1 (be (n - 1) (v * 256 + c)))))
              (take n acc) (n = 0 ? (rev acc) (see s @ c (c < 0 ? () (take (n - 1) (c . acc)))))
              (addr sa) (? (fam = 2 && 8 <= #sa) [(((sa 4 * 256 + sa 5) * 256 + sa 6) * 256 + sa 7)]
                           (fam = 10 && 24 <= #sa) [(dns-v6 (string sa) 8)]
                           ())
              (go acc) (be 4 0 @ m
                         (m != 1 ? acc
                          (: _ (be 4 0, be 4 0, be 4 0, be 4 0)
                             sa (take (be 4 0) ())
                             _ (take (be 4 0) ())
                             (go (acc + addr sa)))))
              (say s ("getaddrinfo " + h + " ^ 0 " + show fam + " 1 0 0" + string [0]), flush s,
               (take 4 () = [50 50 50 0] ? (go ()) ()) @ a (close s, a)))))

   ; hosts first, then netd's answer when conf names no server, then the name and each
   ; search domain appended
   (dns-lookup conf hosts px h byhosts walk fam)
    (byhosts hosts h @ f
       (? (two? f) f
          (: n (two? (dns-conf conf "nameserver") ? () (dns-proxy px h fam))
             servers (dns-servers conf)
             (? (two? n) n
                (walk servers h @ a
                   (two? a ? a
                      (: (go ds) (atom? ds ? ()
                                    (walk servers (h + "." + <ds) @ b
                                       (two? b ? b (go >ds))))
                         (go (dns-conf conf "search")))))))))
   (resolve-via conf hosts px h) (dns-lookup conf hosts px h dns-hosts dns-walk 2)
   (resolve-in conf hosts h) (resolve-via conf hosts dns-proxyd h)
   (resolve6-in conf hosts h) (dns-lookup conf hosts dns-proxyd h dns-hosts6 dns-walk6 10)

   (resolve h) (dns-quad h @ a (two? a ? a (resolve-in "/etc/resolv.conf" "/etc/hosts" h)))
   (resolve6 h) (dns-colon? h ? [h] (resolve6-in "/etc/resolv.conf" "/etc/hosts" h))

   ; connect to each address in turn until one takes
   (dial h port)
    (: (go (a . u)) (connect ['tcp (dns-show a) port] @ c (hot? c ? c (go u)))
     (go (resolve h)))

   ; an address -> the dotted quad `connect` takes
   (dns-show a)
    (: (o k) (show $ a >> k & 255)
     (o 24 + "." + o 16 + "." + o 8 + "." + o 0)))
) ; module dns
