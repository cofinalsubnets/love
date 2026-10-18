; test/host/dns.l -- the resolver offline: the nameserver is a love task on loopback UDP, nothing
; reads /etc. run by test/host/run.l under a timeout, as a resolver that stops parking stops the vm
(cite 'posix ? (borrow 'posix) ())

(: _ (borrow 'dns))
(: _ (borrow 'bytes))

; --- the fake nameserver
; answer `q` with one a record for `addr`, or TC set and no records; the answer's name
; is a compression pointer, as a real server sends
(: (dns-reply q addr tc)
    (snip q 0 2
     + wrbe (tc ? 33664 33152) 2                  ; qr|RD|ra, and TC if asked
     + wrbe 1 2 + wrbe (tc ? 0 1) 2 + wrbe 0 2 + wrbe 0 2
     + snip q 12 #q
     + (tc ? "" (string 192 + string 12             ; name: a pointer to offset 12
           + wrbe 1 2 + wrbe 1 2              ; type A, class in
           + wrbe 0 2 + wrbe 60 2
           + wrbe 4 2
           + string (addr >> 24 & 255) + string (addr >> 16 & 255)
           + string (addr >> 8 & 255) + string (addr & 255))))

   ; serve one query on p, then exit; its recv running proves the resolver parked
   (nameserver p addr tc)
    (twirl (_ \ (recv p @ d
                 (send p <d (dns-reply <>d addr tc),
                  rest 20,
                  close p, 1))) ()))

; --- law 1: a query goes out, an answer comes back, the address is exact
(: sp (test-bind 0)
   port <sp
   s (nameserver (sp 1) 16909060 ())
   _ (rest 20)                                        ; s reaches its park
   a (dns-ask 2130706433 port "ab.cd" 2000)
   _ (catch s)
   _ (assert (two? a)
             (<a = 16909060)
             !(two? >a)))

; --- law 2: a silent nameserver gives up, by a park not a poll
(: none (test-free 0)
   t0 (clock 0)
   a (dns-ask 2130706433 none "ab.cd" 200)
   ms (clock 0 - t0)
   _ (assert !(two? a)
             (200 <= ms)
             (ms < 2000)))

; --- law 3: a truncated answer is torn, never a silent partial
; no TCP here, so TC with no records must not read as () ("no such host")
(: q (dns-query 4660 "ab.cd")
   r (dns-reply q 0 1)
   _ (assert (dns-answers r 4660 = 'torn)))

; --- law 4: /etc/hosts answers with no packet at all
; a fixture, not the machine's file; paths are the pid's own so two runs keep apart
(: dns-dir ("out/.dns-t-" + show (getpid 0)))
(: dir dns-dir
   _ <(hark ["mkdir" "-p" dir])
   hp (dir + "/hosts")
   cp (dir + "/conf")
   h (open hp "w")
   _ (say h "# a comment\n1.2.3.4  ab.cd  alias\n::1 v6.only\n5.6.7.8 other\n")
   _ (close h)
   c (open cp "w")
   _ (say c "search one.test two.test\nnameserver 9.9.9.9\n")
   _ (close c)
   ; no nameserver is reachable, so an answer proves hosts was enough
   a (resolve-in cp hp "ab.cd")
   _ (assert (two? a) (<a = 16909060))
   ns (dns-servers cp)
   _ (assert (two? ns)
             (<<ns = 151587081)                  ; 9.9.9.9
             (><ns = 53))                        ; resolv.conf means 53
   _ (assert (dns-conf cp "search" = '("one.test" "two.test"))))

; --- law 5: an empty resolv.conf still names a server
; 127.0.0.1, the libc fallback
(dns-servers (dns-dir + "/nope") @ ns
   (assert (two? ns) (<<ns = 2130706433)))

; --- law 6: a whole answer read back, every record type nslookup shows
; two aaaas: a zero run folds, a single zero stays
(: q0 (dns-qtype 4661 "ex.test" 1)
   ptr (string 192 + string 12)
   (rr ty rd) (ptr + wrbe ty 2 + wrbe 1 2 + wrbe 0 2 + wrbe 60 2 + wrbe #rd 2 + rd)
   (bytes l) (catmap string l)
   rrs [(rr 5 (dns-labels "al.ex.test")) (rr 1 (bytes [1 2 3 4]))
        (rr 28 (bytes [32 1 13 184 0 0 0 0 0 0 0 0 0 0 0 1]))
        (rr 28 (bytes [0 1 0 0 0 2 0 0 0 0 0 0 0 3 0 4]))
        (rr 15 (wrbe 10 2 + dns-labels "mx.ex.test")) (rr 16 (string 2 + "hi" + string 3 + "you"))
        (rr 2 ptr) (rr 12 (string 3 + "srv" + ptr))]
   (resp fl) (snip q0 0 2 + wrbe fl 2 + wrbe 1 2 + wrbe #rrs 2 + wrbe 0 2 + wrbe 0 2
              + snip q0 12 #q0 + catmap (x \ x) rrs)
   r (dns-records (resp 33152) 4661)
   _ (assert (r = [0 0 [["ex.test" 5 "al.ex.test"] ["ex.test" 1 "1.2.3.4"] ["ex.test" 28 "2001:db8::1"]
                         ["ex.test" 28 "1:0:2::3:4"] ["ex.test" 15 "10 mx.ex.test"]
                         ["ex.test" 16 "\"hi\" \"you\""] ["ex.test" 2 "ex.test"] ["ex.test" 12 "srv.ex.test"]]])
             (<(dns-records (resp 33155) 4661) = 3)            ; NXDOMAIN's rcode
             (dns-records (resp 33152) 4662 = ())            ; another question's answer
             (dns-name (snip q0 0 12 + ptr) 12 = ()))         ; a pointer to itself
   ; the edns query is the plain one plus a counted OPT record
   qe (dns-qedns 4661 "ex.test" 1)
   _ (assert (snip qe 0 10 = snip q0 0 10) (qe 11 = 1)
             (snip qe 12 #q0 = snip q0 12 #q0)
             (snip qe #q0 #qe = string 0 + wrbe 41 2 + wrbe 1232 2 + wrbe 0 2 + wrbe 0 2 + wrbe 0 2)))

; --- law 7: resolve6's pieces; the reply echoes the question short of its 11-byte OPT
(: sp (test-bind 0)
   port <sp
   v6 (catmap string [32 1 13 184 0 0 0 0 0 0 0 0 0 0 0 1])
   s (twirl (_ \ (: p (sp 1)
                    d (recv p) q <>d
                    r (snip q 0 2 + wrbe 33152 2 + wrbe 1 2 + wrbe 1 2 + wrbe 0 2 + wrbe 0 2
                       + snip q 12 (#q - 11) + string 192 + string 12 + wrbe 28 2 + wrbe 1 2
                       + wrbe 0 2 + wrbe 60 2 + wrbe 16 2 + v6)
                    (send p <d r, rest 20, close p, 1))) ())
   _ (rest 20)
   a (dns-walk6 [(2130706433 . port)] "ab.cd")
   _ (catch s)
   _ (assert (a = ["2001:db8::1"])
             (resolve6-in (dns-dir + "/conf") (dns-dir + "/hosts") "v6.only" = ["::1"])
             (resolve6 "fe80::1" = ["fe80::1"])))

; --- law 8: only the nameserver's own answer to our own question is taken
; dropped ahead of it: another address, another port, another id, another question
(: sp (test-bind 0)
   port <sp
   (rep q addr) (dns-reply q addr ())
   (other-name q) (snip q 0 13 + string (q 13 ^ 1) + snip q 14 #q)          ; ab.cd -> `b.cd
   s (twirl (_ \ (: p (sp 1)
                    d (recv p) q <>d
                    far (bind ['udp "127.0.0.2" 0])
                    _ (hot? far ? (send far <d (rep q 101058054)) 0)       ; 6.6.6.6
                    near (bind ['udp 0])
                    (send near <d (rep q 117901063),                            ; 7.7.7.7
                     send p <d (rep (wrbe (rdbe q 0 2 ^ 1) 2 + snip q 2 #q) 134744072),     ; 8.8.8.8
                     send p <d (rep (other-name q) 151587081),                  ; 9.9.9.9
                     send p <d (rep q 16909060),                                ; 1.2.3.4
                     rest 20,
                     (hot? far ? (close far) 0), close near, close p, 1))) ())
   _ (rest 20)
   a (dns-ask 2130706433 port "ab.cd" 2000)
   _ (catch s)
   _ (assert (a = [16909060])))

; --- law 9: the matcher's own cases, and ids that are not the clock
(: q (dns-query 4663 "ab.cd")
   r (dns-reply q 16909060 ())
   qe (dns-qedns 4663 "ab.cd" 1)
   ids (map (_ \ dns-id 0) ^8)
   _ (assert (dns-match? q r)
             (dns-match? qe r)                                     ; the edns record is not the question
             !(dns-match? q q)                                     ; a query is no answer: qr clear
             !(dns-match? q (snip r 0 14))                         ; torn short
             (all (i \ charm? i && 0 <= i && i < 65536) ids)
             (any (i \ i != <ids) ids)))                         ; eight equal would be 2^-112

(hark ["rm" "-rf" dns-dir])
(say out "dns: ok", putc 10)
