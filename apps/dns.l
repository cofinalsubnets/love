; apps/dns.l -- the resolver, in love. `connect` takes a dotted quad and nothing else
; (inle/sock.c), because getaddrinfo is not a syscall with an O_NONBLOCK to set but a
; config read that may speak DNS, and there is no nonblocking form of it. so the name
; half lives up here instead, where a lookup can park like anything else:
;
;   (resolve "example.org")      ; -> a list of ipv4 charms, in the server's order
;   (resolve6 "example.org")     ; -> a list of ipv6 texts, the spelling `send` takes
;   (dial "example.org" 80)      ; -> a port, or ()  -- resolve, then connect
;   (resolve-in conf hosts name) ; the same, against named config paths
;
; nothing here polls, and the shape that manages it is worth reading. a lookup needs
; "an answer, or a deadline", and the scheduler has no or of the two -- a task parked
; on both a timer and an fd wakes when both are ready. so it is three tasks: the
; receiver parks on the socket, a watchdog parks on the clock, and the caller parks in
; `catch`. whichever finishes first wins, because a freeze out from under a catcher
; wakes it with the zero point. no `cue?` loop, no 1 ms tick.
;
; this is a port of apps/moon/lib/moonlibc/dns.c, which is what a mooncc-built
; love used to reach through getaddrinfo -- and which blocked, for up to 2 tries x
; 2.5 s per nameserver across three of them. that C is the reference for every fiddly
; part here (the wire format, the compression pointer, the two config parsers) and it
; stays where it is: moonlibc is a libc, and a C program mooncc builds is entitled to
; getaddrinfo.
;
; what it speaks, and what it does not: a records (and aaaa, through resolve6) over UDP,
; /etc/hosts first, /etc/resolv.conf's nameservers in order with the search domains
; appended on a miss. not the TCP fallback -- a truncated answer is a scare, never a
; silent partial, so the gap says so when something reaches it.
;
; presence is the wrapper here as everywhere: `0.0.0.0` is a perfectly good address and
; nets nothing, so every "did it parse" answer is a one-list tested with `two?`.

; the head names the exports. `dial` and `resolve` are the door; the rest are the
; wire-format pieces test/host/dns.l drives directly, a protocol being unit-tested.
(module (dns dial resolve dns-show
         dns-answers dns-ask dns-conf dns-query dns-servers
         dns-hosts dns-labels resolve-in dns-quad
         dns-qtype dns-qedns dns-raw dns-name dns-records dns-v6
         resolve6 resolve6-in dns-hosts6 dns-colon? dns-walk6)
(borrow 'posix)
(borrow 'bytes)
(:
   ; --- files, lines, words ----------------------------------------------------
   ; the two config files are line-oriented text, not love data, so `sound` is no
   ; use and this is a hand walk. absent is the normal case and reads as "".
   (dns-look path) (: q (open path "r") (? (hot? q) (: s (slurp q) _ (close q) s) ""))

   (dns-eol t i n) (? (n <= i || t i = 10) i (dns-eol t (i + 1) n))
   (dns-lines t)
    (: n #t
       (go i) (? (n <= i) () (: j (dns-eol t i n) (snip t i j . go (j + 1))))
       (go 0))

   ; a line's whitespace-separated words, stopping at a '#'.
   (dns-blank? c) (c = 32 || c = 9)
   (dns-words l)
    (: n #l
       (skip i) (? (i < n && dns-blank? (l i)) (skip (i + 1)) i)
       (end i)  (? (n <= i || dns-blank? (l i) || l i = 35) i (end (i + 1)))
       (go i)   (: s (skip i)
                   (? (n <= s || l s = 35) ()
                      (: e (end s) (snip l s e . go e))))
       (go 0))

   ; --- a dotted quad ----------------------------------------------------------
   ; -> a one-list holding the address in host order, or (). the same four-octet walk
   ; inle/sock.c's `quad` does, because both have to agree on what a numeric host is:
   ; whatever this refuses is what gets a lookup.
   (dns-digit? c) (47 < c < 58)
   (dns-quad s)
    (: n #s
       (oct i a k)
        (: (dig j v any)
            (? (j < n && dns-digit? (s j))
               (: w (v * 10 + s j - 48) (? (255 < w) () (dig (j + 1) w 1)))
               (any ? [j v] ()))
           r (dig i 0 0)
           (? (one? r) ()
              (: j <r  b (a * 256 + <>r)
                 (? (k = 1) (n <= j ? [b] ())
                    (j < n && s j = 46) (oct (j + 1) b (k - 1))))))
       (oct 0 0 4))

   ; --- the wire ---------------------------------------------------------------

   ; a name as length-prefixed labels, NUL-terminated. () if any label is empty
   ; or over 63 bytes -- a malformed name must not become a malformed packet.
   (dns-labels h)
    (: n #h
       (dot i) (? (n <= i || h i = 46) i (dot (i + 1)))
       (go i) (? (n <= i) (string 0)
                 (: j (dot i)  l (j - i)
                    (? (l = 0 || 63 < l) ()
                       (: r (go (j + 1))
                          (string? r && string l + snip h i j + r)))))
       (0 < n && go 0))

   ; the query packet: header (RD set, one question), the name, the QTYPE, QCLASS in.
   ; a resolver asks for A (1); nslookup asks for whatever it was told
   (dns-qtype id h t)
    (: q (dns-labels h)
       (string? q &&
        (wrbe id 2 + wrbe 256 2 + wrbe 1 2 + wrbe 0 2
         + wrbe 0 2 + wrbe 0 2 + q + wrbe t 2 + wrbe 1 2)))
   (dns-query id h) (dns-qtype id h 1)
   ; ..and with an EDNS0 OPT record (RFC 6891) offering 1232 bytes, the size that crosses
   ; any path unfragmented, so a long answer -- a txt set -- is not cut at udp's 512
   (dns-qedns id h t)
    (: q (dns-qtype id h t)
       (string? q && (snip q 0 10 + wrbe 1 2 + snip q 12 #q
                      + string 0 + wrbe 41 2 + wrbe 1232 2 + wrbe 0 2 + wrbe 0 2 + wrbe 0 2)))

   ; skip a name at `pos` -> the position after it, or -1. a compression pointer ends
   ; the name: its top two bits are set and it is two bytes wide, so a walk that
   ; treated it as a length would run off into the record data.
   (dns-skip r pos n)
    (? (n <= pos) -1
       (: l (r pos)
          (? (l = 0) (pos + 1)
             (l & 192 = 192) (n < pos + 2 ? -1 (pos + 2))
             (dns-skip r (pos + l + 1) n))))

   ; a response -> the a addresses in the server's order, () if it says no, or
   ; 'torn when the TC bit says the answer did not fit. cnames simply ride past:
   ; they are records of another type and the walk skips them.
   (dns-answers r id)
    (: n #r
       (go k pos)
        (? (k < 1 || n <= pos) ()
           (: p (dns-skip r pos n)
              (? (p < 0 || n < p + 10) ()
                 (: ty (rdbe r p 2)  cl (rdbe r (p + 2) 2)  rl (rdbe r (p + 8) 2)
                    q (p + 10)
                    (? (n < q + rl) ()
                       (ty = 1 && cl = 1 && rl = 4)
                         ((rdbe r q 2 * 65536 + rdbe r (q + 2) 2) . go (k - 1) (q + rl))
                       (go (k - 1) (q + rl)))))))
       (? (n < 12) ()
          !(rdbe r 0 2 = id) ()                      ; not the question we asked
          (0 < r 2 & 2) 'torn                        ; TC: it did not fit
          (0 < r 3 & 15) ()                          ; NXDOMAIN, SERVFAIL, ..
          (: p0 (dns-skip r 12 n)
             (? (p0 < 0) () (go (rdbe r 6 2) (p0 + 4))))))

   ; --- one question to one nameserver ------------------------------------------
   ; a packet to a server -> its answer's bytes, () on none within `ms`. the three-task
   ; park is the header note: receiver on the socket, watchdog on the clock, caller in
   ; catch. the server is named by address and port: resolv.conf has no port syntax and
   ; every line it yields means 53, but a stub on another port is a real thing to want
   ; and the walk carries the pair either way.
   (dns-raw ns port q ms)
    (bind ['udp 0] @ (p && hot? p)
     (: _ (send p [(dns-show ns) port] q)
        r (twirl (_ \ (recv p)) ())
        w (twirl (_ \ (rest ms, freeze r)) ())
        d (catch r)
      (freeze w,
       close p,
       two? d ? <>d)))
   ; -> the addresses, () on no answer
   (dns-ask ns port h ms)
    (: id (clock 0 & 65535)
       q (dns-query id h)
       r (? (string? q) (dns-raw ns port q ms) ())
       (? (string? r) (dns-answers r id) ()))

   ; --- a whole answer, for a person to read ---------------------------------------
   ; a name at pos, compression pointers followed -> [the dotted name, the position just
   ; past it where it was written], or () for one that runs off the packet or loops
   (dns-name r pos)
    (: n #r
       (dots l) (? (one? l) "." !(two? >l) <l (<l + "." + dots >l))
       (go p acc hops after)
        (? (n <= p || 64 < hops) ()
           (: l (r p)
              (? (l = 0) [(dots (rev acc)) (? (after < 0) (p + 1) after)]
                 (l & 192 = 192)
                  (? (n <= p + 1) ()
                     (go ((l & 63) * 256 + r (p + 1)) acc (hops + 1) (? (after < 0) (p + 2) after)))
                 (n < p + 1 + l) ()
                 (go (p + 1 + l) (snip r (p + 1) (p + 1 + l) . acc) hops after))))
       (go pos () 0 -1))
   ; sixteen bytes at q -> the ipv6 address as RFC 5952 writes it: each group in lower
   ; hex without its leading zeros, and the longest run of two or more zero groups as ::
   (dns-v6 r q)
    (: gs (map (i \ rdbe r (q + 2 * i) 2) ^8)
       hx "0123456789abcdef"
       (h4 v) (? (v < 16) (string (hx v)) (h4 (v // 16) + string (hx (v % 16))))
       (cat l) (? (one? l) "" !(two? >l) <l (<l + ":" + cat >l))
       (zrun i st k best)
        (? (8 <= i) (? (<>best < k) [st k] best)
           (gs i = 0) (zrun (i + 1) (? (k = 0) i st) (k + 1) best)
           (zrun (i + 1) 0 0 (? (<>best < k) [st k] best)))
       b (zrun 0 0 0 [0 0])
       st <b ln <>b
       (? (ln < 2) (cat (map h4 gs))
          (cat (map (i \ h4 (gs i)) ^st) + "::" + cat (map (i \ h4 (gs (st + ln + i))) ^(8 - st - ln)))))
   ; a txt record's strings, each quoted, from q to e
   (dns-txt r q e)
    (? (e <= q) ""
       (: l (r q) t (dns-txt r (q + 1 + l) e)
          ("\"" + snip r (q + 1) (min e (q + 1 + l)) + "\"" + (? #t (" " + t) ""))))
   ; a soa record's seven fields, a line each, as nslookup lays them under the name
   (dns-soa r q)
    (: a (dns-name r q) b (? (two? a) (dns-name r (a 1)) ())
       (? !(two? b) " ?"
          (: p (b 1)
             (u k) (rdbe r (p + 4 * k) 2 * 65536 + rdbe r (p + 4 * k + 2) 2)
             ("\n\torigin = " + <a + "\n\tmail addr = " + <b + "\n\tserial = " + show (u 0)
              + "\n\trefresh = " + show (u 1) + "\n\tretry = " + show (u 2)
              + "\n\texpire = " + show (u 3) + "\n\tminimum = " + show (u 4)))))
   ; a response -> [rcode authoritative? records], a record [name type text] in the server's
   ; order, its data written as nslookup shows it; 'torn when TC says the answer did not
   ; fit, () when it answers some other question
   (dns-records r id)
    (: n #r
       (name-at q) (: m (dns-name r q) (? (two? m) <m "?"))
       (rd t q l)
        (? (t = 1 && l = 4) (dns-show (rdbe r q 2 * 65536 + rdbe r (q + 2) 2))
           (t = 28 && l = 16) (dns-v6 r q)
           (elem t '(2 5 12)) (name-at q)
           (t = 15) (show (rdbe r q 2) + " " + name-at (q + 2))
           (t = 16) (dns-txt r q (q + l))
           (t = 6) (dns-soa r q)
           ("type " + show t + ", " + show l + " bytes"))
       (go k pos acc)
        (: m (? (k < 1) () (dns-name r pos))
           p (? (two? m) <>m n)
           (? (n < p + 10) (rev acc)
              (: ty (rdbe r p 2) rl (rdbe r (p + 8) 2) q (p + 10)
                 (? (n < q + rl) (rev acc)
                    (go (k - 1) (q + rl) ([<m ty (rd ty q rl)] . acc))))))
       (? (n < 12 || rdbe r 0 2 != id) ()
          (0 < r 2 & 2) 'torn
          (: p0 (dns-skip r 12 n)
             [(r 3 & 15) (0 < r 2 & 4) (? (p0 < 0) () (go (rdbe r 6 2) (p0 + 4) ()))])))

   ; --- the two config files -----------------------------------------------------
   ; every word after `k` on every line that starts with it, in file order. this
   ; reads both `nameserver` (one address a line) and `search` (many a line).
   (dns-conf path k)
    (: (go (a . u)) (dns-words a @ (^k . w) (w + go u) (go u))
     (go (dns-lines (dns-look path))))

   ; /etc/hosts: the first line whose address parses and one of whose names is an
   ; exact match -> a one-list of the address. no packet is sent at all, which is
   ; what makes localhost and every lan name free.
   (dns-hosts path h)
    (: (go (l . u))
     (: w (dns-words l)
      (? (one? w) (go u)
       (: a (dns-quad <w)
        (two? a && elem h >w ? a (go u)))))
     (go (dns-lines (dns-look path))))
   ; and its v6 lines, the address kept as the text it is
   (dns-hosts6 path h)
    (: (go (l . u))
     (: w (dns-words l)
      (? (one? w) (go u)
         (dns-colon? <w && elem h >w) [<w]
         (go u)))
     (go (dns-lines (dns-look path))))
   (dns-colon? s) ((: (g i) (? (#s <= i) 0 (s i = 58) 1 (g (i + 1)))) 0)

   ; the nameservers, in order -- 127.0.0.1 when the file names none, musl's fallback
   ; and moonlibc's, so a machine with an empty resolv.conf still reaches a local stub
   ; rather than answering "no such host".
   (dns-servers conf)
    (: ns (: (go l) (? (two? l)
                     (: a (dns-quad <l)
                      (two? a ? ((<a . 53) . go >l) (go >l))))
             (go (dns-conf conf "nameserver")))
       (two? ns ? ns [(2130706433 . 53)]))

   ; --- the door -----------------------------------------------------------------
   dns-ms 2500                            ; moonlibc's per-server deadline, kept

   ; ask every server in turn for one name. a server that answers ends the walk,
   ; even to say no -- only silence moves on to the next.
   (dns-walk ((a . u) . su) h)
    (dns-ask a u h dns-ms @
     'torn (scare 'torn ['dns h])
     (x && two? x) x
     (dns-walk su h))
   ; the same walk asking aaaa, its answers v6 text
   (dns-walk6 ((a . u) . su) h)
    (: id (clock 0 & 65535)
       r (dns-raw a u (dns-qedns id h 28) dns-ms)
       ((? (string? r) (dns-records r id) ()) @
        'torn (scare 'torn ['dns h])
        (x && two? x) (catmap (d \ ? (d 1 = 28) [(d 2)] ()) (x 2))
        (dns-walk6 su h)))

   ; hosts first, then the name as given, then each search domain appended.
   (dns-lookup conf hosts h byhosts walk)
    (: f (byhosts hosts h)
       (? (two? f) f
          (: servers (dns-servers conf)
             a (walk servers h)
             (? (two? a) a
                (: (go ds) (? (one? ds) ()
                              (: b (walk servers (h + "." + <ds))
                                 (two? b ? b (go >ds))))
                   (go (dns-conf conf "search")))))))
   (resolve-in conf hosts h) (dns-lookup conf hosts h dns-hosts dns-walk)
   (resolve6-in conf hosts h) (dns-lookup conf hosts h dns-hosts6 dns-walk6)

   (resolve h) (: a (dns-quad h) (two? a ? a (resolve-in "/etc/resolv.conf" "/etc/hosts" h)))
   (resolve6 h) (? (dns-colon? h) [h] (resolve6-in "/etc/resolv.conf" "/etc/hosts" h))

   ; resolve, then connect to each address in turn until one takes. a dotted quad
   ; costs no lookup at all -- `resolve` hands it straight back.
   (dial h port)
    (: (go (a . u)) (: c (connect ['tcp (dns-show a) port]) (hot? c ? c (go u)))
     (go (resolve h)))

   ; an address back to its dotted quad, which is the only spelling `connect` takes.
   (dns-show a)
    (: (o k) (show $ a >> k & 255)
     (o 24 + "." + o 16 + "." + o 8 + "." + o 0)))
) ; module dns
