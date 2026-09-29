#!/usr/bin/env -S love -l
; nc -- netcat in love.
;
;   nc [-Nvz] [-q secs] [-w secs] host port..   tcp client: connect to host:port
;   nc [-Nv] [-q secs] [-w secs] -l port        tcp server: listen on port, accept one client
;   -N        shut down the write half at stdin's end
;   -q secs   quit secs after stdin's end; a negative wait is forever, the default
;   -w secs   give up a connect, or quit when neither way moves, after secs; not the accept
;   -v        say on stderr what was connected, refused, listened on, accepted
;   -z        connect to each port, lo-hi a range, and close at once; 0 when any took
;
; secs are udur's: 3, 1.5, 2m. either way a bidirectional pump, stdin -> socket and
; socket -> stdout, two tasks each parked in a port read on its own fd; the scheduler
; polls the fds, so no select loop. run it straight -- prel is already in the egg, so
; no `-l love/boot/prel.l`:
;   out/love apps/nc.l host port
; or as kore's `nc` applet (apps/kore/kore.l).

; one define: the body-less top-level `:` leaks nc-main and nothing else; the seat at the
; bottom fires it only when this file was invoked, so a multi-call cat stays quiet.
; dns splices for nc's own compile and leaves the session's book alone.
(module (nc nc-main)
(borrow 'dns)

(borrow 'posix)

(: (nc-main as)
 (: (die m) (udie 1 ("nc: " + m))
    t (tablet 0)
    ops ((uopt as t '(113 119) () ()) 2)
    usage "usage: nc [-Nvz] [-q SECS] [-w SECS] {HOST PORT.. | -l PORT}"
    (portof s) (: n (uport s) (? n n (die ("not a port: " + s))))
    ; a flag's duration in ms, -1 when absent or negative
    (dur c) (: v (uoptv t c)
               neg (string? v && 0 < #v && v 0 = 45)
               m (? (string? v) (udur (? neg (snip v 1 #v) v)) -1)
               (? !(charm? m) (die ("-" + string c + " takes a duration, not " + v)) neg -1 m))
    q (dur 113)
    w (dur 119)
    seen (tablet 0)   ; the clock at the last chunk either way, for -w
    (note m) (? (t 118) (say err (m + "\n"), flush err) 0)

    ; src to dst a chunk at a time until src's eof: see refills and parks, chug takes
    ; the rest of what is read. the flush keeps stdout prompt and is a no-op on a socket
    (pump src dst) (: c (see src)
                      (? (c = -1) 0 (unsee src c, say dst (chug src), flush dst, pin seen 0 (clock 0), pump src dst)))

    ; with -w: quit once neither way has moved for w ms
    (idle _) (: gap (clock 0 - seen 0)
                (? (w <= gap) (flush out, quit 0) (rest (w - gap), idle 0)))

    ; wait out the inbound pump: to the peer's eof, or with -q at most q ms, when a
    ; watchdog task freezes it
    (linger d) (? (q < 0) (catch d)
                  (: g (twirl (_ \ (rest q, freeze d)) ())
                     _ (catch d)
                     (freeze g)))

    ; the conversation: stdin -> socket here, socket -> stdout in `down`. all of stdin goes
    ; before teardown, then -N half-closes so the peer sees our eof; without it the peer
    ; must close first, or -q runs out
    (talk s) (: _ (pin seen 0 (clock 0))
                dog (? (w < 0) () (twirl idle ()))
                down (twirl (_ \ pump s out) 0)
              (pump in s,
               (? (t 78) (seal s 1) 0),
               linger down,
               (? (w < 0) 0 (freeze dog)),
               flush out,
               close s,
               0))

    ; server: listen, accept one client, talk, close the listener
    (serve port) (: l (listen port)
                    (? (hot? l) (: _ (note ("Listening on 0.0.0.0 " + show port))
                                   c (accept l)
                                   (? (hot? c) (: f (farend c)
                                                  _ (? (two? f) (note ("Connection received on " + <f + " " + show (f 1))) 0)
                                                  (talk c, close l, 0))
                                      (close l, die "accept failed")))
                       (die ("cannot listen on port " + show port + ": " + uerrno l))))

    ; one connect, given up after w ms with -w: the port, or the refusal's nom. a frozen
    ; catch answers 0, so the answer rides wrapped
    (conn a port) (? (w < 0) (connect ['tcp a port])
                     (: r (twirl (_ \ [1 (connect ['tcp a port])]) ())
                        d (twirl (_ \ (rest w, freeze r)) ())
                        x (catch r)
                        _ (freeze d)
                        (two? x ? (x 1) 'etimedout)))
    ; each of host's addresses in turn until one takes: the port, or the last refusal
    (reach host port) (: (go l e) (? (atom? l) e (: c (conn (dns-show <l) port) (hot? c ? c (go >l c))))
                         (go (resolve host) 'ehostunreach))
    (took host port) ("Connection to " + host + " " + show port + " port [tcp/*] succeeded!")
    (refused host port e) ("connect to " + host + " port " + show port + " (tcp) failed: " + uerrno e)

    (client host port) (: s (reach host port)
                          (? (hot? s) (note (took host port), talk s) (die (refused host port s))))

    ; -z: each port connected and closed, nothing sent; 0 when any took
    (scan host ports) (: (one n p) (: s (reach host p)
                                      (? (hot? s) (close s, note (took host p), n + 1)
                                         (note ("nc: " + refused host p s), n)))
                         (? (0 < foldl one 0 ports) 0 (uleave 1)))
    ; a port or a lo-hi range -> its ports
    (span a) (: k (findsub a "-")
                (? (k < 0) [(portof a)]
                   (: lo (portof (snip a 0 k)) hi (portof (snip a (k + 1) #a))
                      (? (hi < lo) (die ("not a range: " + a)) (map (+ lo) (jot (hi - lo + 1)))))))

    (? (uoptun t "lNqwvz") (die usage)
       (t 108) (#ops = 1 && !(t 122) ? (serve (portof <ops)) (die usage))
       (t 122) (two? >ops ? (scan <ops (foldl (\ l a (l + span a)) () >ops)) (die usage))
       (#ops = 2) (client <ops (portof <>ops))
       (die usage))))

; the seat: fire nc-main iff this file sits in the program seat of the real command line --
; the positional program or a `-l` preload -- with the args after it. `cmdline` is the
; full C argv, so both load orders read the same; kore's dispatcher calls nc-main itself.
(: s (cite 'verbs 'fire ["nc" "nc.l"])
   (two? s ? (nc-main >s)))
) ; module nc
