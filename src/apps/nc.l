#!/usr/bin/env -S love -l
; nc -- netcat in love.
;
;   nc [flags] host port..            client: connect to host:port
;   nc [flags] -l [addr] port         server: listen, accept one client
;   nc [flags] -l [-s addr] -p port
;   nc [flags] -U [-l] path           the same over a unix socket
;   -C        send each newline as crlf
;   -d        read nothing from stdin
;   -i secs   send and write a line at a time, secs apart; with -z, wait between ports
;   -k        with -l, accept the next client when one leaves
;   -N        shut down the write half at stdin's end
;   -n        taken and ignored: an address is numeric or resolved, never asked about
;   -o file   write the traffic to file as hex: > sent, < received
;   -q secs   quit secs after stdin's end; a negative wait is forever, the default
;   -s addr   with -l, listen on addr alone; -p port names the port
;   -U        a unix stream socket at path; -l unlinks it after
;   -u        udp: datagrams of at most 1472 bytes; -l answers the first sender alone
;   -v        say on stderr what was connected, refused, listened on, accepted
;   -w secs   give up a connect, or quit when neither way moves, after secs; not the accept
;   -z        connect to each port, lo-hi a range, and close at once; 0 when any took
;
; secs are udur's: 3, 1.5, 2m. either way a bidirectional pump, stdin -> socket and
; socket -> stdout, two tasks each parked in a port read on its own fd; the scheduler
; polls the fds, so no select loop. run it straight -- prel is already in the egg, so
; no `-l src/love/boot/prel.l`:
;   out/love src/apps/nc.l host port
; or as kore's `nc` applet (src/apps/kore/kore.l).

; one define: the body-less top-level `:` leaks nc-main and nothing else; the seat at the
; bottom fires it only when this file was invoked, so a multi-call cat stays quiet.
; dns splices for nc's own compile and leaves the session's book alone.
(module (nc nc-main)
(borrow 'dns)

(borrow 'posix)

(: (nc-main as)
 (: (die m) (udie 1 ("nc: " + m))
    t {}
    ops (uopt as t '(105 111 112 113 115 119) () () 2)
    usage "usage: nc [-CdkNnUuvz] [-i SECS] [-o FILE] [-q SECS] [-w SECS] {HOST PORT.. | -l [[-s] ADDR] [-p] PORT | -U [-l] PATH}"
    (portof s) (uport s @ n (n ? n (die ("not a port: " + s))))
    ; a flag's duration in ms, -1 when absent or negative
    (dur c) (: v (uoptv t c)
               neg (string? v && 0 < #v && v 0 = 45)
               m (string? v ? (udur (neg ? (snip v 1 #v) v)) -1)
               (? !(charm? m) (die ("-" + string c + " takes a duration, not " + v)) neg -1 m))
    q (dur 113)
    w (dur 119)
    i (dur 105)
    seen {}   ; the clock at the last chunk either way, for -w
    ov (uoptv t 111)
    dumpf (string? ov ? (open ov "w" @ h (hot? h ? h (die ("cannot write " + ov + ": " + uerrno h)))))
    offs {}   ; each direction's offset, for -o
    (note m) (t 118 ? (say err (m + "\n"), flush err) 0)

    ; -o: s as traditional netcat's hex lines -- dir (> or <), the offset, 16 bytes, their text
    (dump dir s) (!dumpf ? 0 (peep offs dir 0 @ o (pin offs dir (o + #s), dline dir s o 0)))
    (dline dir s o k)
     (#s <= k ? (flush dumpf)
        (: e (min #s (k + 16)) b (chars (snip s k e))
           hx (cats (map (c \ " " + zpad 2 (radix c 16)) b))
           pad (cats (map (_ \ "   ") (jot (16 - #b))))
           tx (string (map (c \ 32 <= c < 127 ? c 46) b))
           (say dumpf (string dir + " " + zpad 8 (radix (o + k) 16) + hx + pad + " # " + tx + "\n"),
            dline dir s o e)))
    ; outbound bytes: with -C each newline goes as crlf
    (crlf b) (t 67 ? (replace b "\n" "\r\n") b)
    ; s cut after each newline
    (pieces s) (findsub s "\n" @ k
                  (k < 0 || #s <= k + 1 ? [s] (. (snip s 0 (k + 1)) (pieces (snip s (k + 1) #s)))))
    ; s out through f: whole, or with -i a line at a time, i ms apart
    (paced f s) (i < 0 ? (f s) (map (l \ (f l, pin seen 0 (clock 0), rest i)) (pieces s)))

    ; src to dst a chunk at a time until src's eof: see refills and parks, chug takes
    ; the rest of what is read. the flush keeps stdout prompt and is a no-op on a socket
    (pump src dst dir) (see src @ c
                          (c = -1 ? 0
                             (: b (dir = 62 ? (crlf (unsee src c, chug src)) (unsee src c, chug src))
                                (dump dir b,
                                 paced (x \ (say dst x, flush dst)) b,
                                 pin seen 0 (clock 0),
                                 pump src dst dir))))

    ; with -w: answer once neither way has moved for w ms
    (idle _) (clock 0 - seen 0 @ gap
                (w <= gap ? 0 (rest (w - gap), idle 0)))

    ; wait out the inbound pump: to the peer's eof, or with -q at most q ms, when a
    ; watchdog task freezes it
    (linger d) (q < 0 ? (catch d)
                  (twirl (_ \ (rest q, freeze d)) () @ g
                     (catch d,
                      freeze g)))

    ; a conversation: stdin outward in `up`, inward to stdout in `down`. all of stdin goes
    ; before teardown; then the peer must end it, or -q runs out. with -w, `dog` ends both
    ; when idle
    (converse upf downf s) (: _ (pin seen 0 (clock 0))
                              down (twirl downf 0)
                              up (twirl upf 0)
                              dog (w < 0 ? () (twirl (_ \ (idle 0, freeze up, freeze down)) ()))
                            (catch up,
                             linger down,
                             (w < 0 ? 0 (freeze dog)),
                             flush out,
                             close s,
                             0))
    ; over tcp, -N half-closes at stdin's end so the peer sees our eof
    (talk s) (converse (_ \ ((t 100 ? 0 (pump in s 62)), (t 78 ? (seal s 1) 0))) (_ \ pump s out 60) s)

    ; over udp: stdin goes out cut to datagrams; only `to`'s come in
    (dsend p to d) (#d <= 1472 ? (send p to d) (send p to (snip d 0 1472), dsend p to (snip d 1472 #d)))
    (dup p to) (see in @ c
                  (c = -1 ? 0
                     (crlf (unsee in c, chug in) @ b
                        (dump 62 b,
                         paced (x \ dsend p to x) b,
                         pin seen 0 (clock 0),
                         dup p to))))
    (dwrite d) (dump 60 d, paced (x \ (say out x, flush out)) d, pin seen 0 (clock 0))
    (ddown p to) (recv p @ d
                    (? (nom? d) 0
                       (<d = to) (dwrite (d 1), ddown p to)
                       (ddown p to)))
    (dtalk p to) (converse (_ \ t 100 ? 0 (dup p to)) (_ \ ddown p to) p)

    ; server: listen on la, named name, accept a client and talk; with -k the next, until
    ; killed. a unix peer has no address to say, so its path stands in
    (serve la name)
     (: l (listen la)
        (go _) (accept l @ c
                  (hot? c ? (: f (t 85 ? () (farend c))
                               ((? (two? f) (note ("Connection received on " + <f + " " + show (f 1)))
                                   (t 85) (note ("Connection received on " + name)) 0),
                                talk c,
                                (t 107 ? (go 0) (close l, 0))))
                     (close l, die ("accept failed: " + uerrno c))))
        (hot? l ? (note ("Listening on " + name), go 0)
           (die ("cannot listen on " + name + ": " + uerrno l))))
    (tserve addr port) (serve (addr ? ['tcp addr port] port) ((addr || "0.0.0.0") + " " + show port))
    ; -U -l: the socket file goes when the server does
    (userv path) (serve ['unix path] path, unlink path, 0)
    ; -u -l: bind, and the first datagram's sender is the peer
    (userve addr port)
     (: p (addr ? (bind ['udp addr port]) (bind ['udp port]))
        (hot? p ? (: _ (note ("Bound on " + (addr || "0.0.0.0") + " " + show port))
                     d (recv p)
                     (nom? d ? (die ("recv failed: " + uerrno d))
                        (note ("Connection received on " + <<d + " " + show (<d 1)),
                         dwrite (d 1),
                         dtalk p <d)))
           (die ("cannot bind " + (addr ? addr "port") + " " + show port + ": " + uerrno p))))
    (uclient host port) (: to [(quad host) port]
                           p (bind ['udp 0])
                           (hot? p ? (note ("Connection to " + host + " " + show port + " port [udp/*] succeeded!"), dtalk p to)
                              (die ("cannot bind: " + uerrno p))))
    ; a listen address as the dotted quad listen takes, names resolved
    (quad a) (resolve a @ r (two? r ? (dns-show <r) (die ("cannot resolve " + a))))
    ; -l's operands: [addr] port, or -s addr and -p port in their place
    (listener _)
     (: sv (uoptv t 115) pv (uoptv t 112) n #ops
        (srv a p) (t 117 ? (userve a p) (tserve a p))
        (? (n = 2 && !sv && !pv) (srv (quad <ops) (portof <>ops))
           (n = 1 && !pv) (srv (sv ? (quad sv)) (portof <ops))
           (n = 0 && pv) (srv (sv ? (quad sv)) (portof pv))
           (die usage)))

    ; one connect to the address ca, given up after w ms with -w: the port, or the
    ; refusal's nom. a frozen catch answers 0, so the answer rides wrapped
    (conn ca) (w < 0 ? (connect ca)
                 (: r (twirl (_ \ [1 (connect ca)]) ())
                        d (twirl (_ \ (rest w, freeze r)) ())
                        x (catch r)
                        (freeze d,
                         (two? x ? (x 1) 'etimedout))))
    ; each of host's addresses in turn until one takes: the port, or the last refusal
    (reach host port) (: (go l e) (atom? l ? e (conn ['tcp (dns-show <l) port] @ c (hot? c ? c (go >l c))))
                         (go (resolve host) 'ehostunreach))
    (took host port) ("Connection to " + host + " " + show port + " port [tcp/*] succeeded!")
    (refused host port e) ("connect to " + host + " port " + show port + " (tcp) failed: " + uerrno e)

    (client host port) (reach host port @ s
                          (hot? s ? (note (took host port), talk s) (die (refused host port s))))

    ; -U: the path's listener, or with -z only whether one is there
    (uconn path) (conn ['unix path] @ s
                    (? !(hot? s) (t 122 ? (note ("nc: connect to " + path + " failed: " + uerrno s), uleave 1)
                                    (die ("connect to " + path + " failed: " + uerrno s)))
                       (t 122) (close s, note ("Connection to " + path + " succeeded!"), 0)
                       (note ("Connection to " + path + " succeeded!"), talk s)))

    ; -z: each port connected and closed, nothing sent; 0 when any took
    (scan host ports) (: (one n p) (: s (reach host p)
                                      m (hot? s ? (close s, note (took host p), n + 1)
                                           (note ("nc: " + refused host p s), n))
                                      ((i < 0 ? 0 (rest i)),
                                       m))
                         (0 < foldl one 0 ports ? 0 (uleave 1)))
    ; a port or a lo-hi range -> its ports
    (span a) (findsub a "-" @ k
                (k < 0 ? [(portof a)]
                   (: lo (portof (snip a 0 k)) hi (portof (snip a (k + 1) #a))
                      (hi < lo ? (die ("not a range: " + a)) (map (+ lo) (jot (hi - lo + 1)))))))

    (? (uoptbad as t "CdiklNnopqsUuwvz") (die usage)
       (t 117 && (t 107 || t 122)) (die "-u takes neither -k nor -z")
       (t 85) (? (t 117 || t 112 || t 115) (die "-U takes none of -u, -p, -s")
                 !(#ops = 1) (die usage)
                 (t 108) (t 122 ? (die usage) (userv <ops))
                 (t 107) (die "-k goes with -l")
                 (uconn <ops))
       (t 108) (!(t 122) ? (listener 0) (die usage))
       (t 107 || t 112 || t 115) (die "-k, -p and -s go with -l")
       (t 122) (two? >ops ? (scan <ops (foldl (l \ a \ l + span a) () >ops)) (die usage))
       (#ops = 2) (t 117 ? (uclient <ops (portof <>ops)) (client <ops (portof <>ops)))
       (die usage))))

; the seat: fire nc-main iff this file sits in the program seat of the real command line --
; the positional program or a `-l` preload -- with the args after it. `cmdline` is the
; full C argv, so both load orders read the same; kore's dispatcher calls nc-main itself.
(: s (cite 'verbs 'fire ["nc" "nc.l"])
   (two? s ? (nc-main >s)))
) ; module nc
