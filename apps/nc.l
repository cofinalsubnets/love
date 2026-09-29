#!/usr/bin/env -S love -l
; nc -- netcat in love.
;
;   nc [-N] [-q secs] [-w secs] host port   tcp client: connect to host:port
;   nc [-N] [-q secs] [-w secs] -l port     tcp server: listen on port, accept one client
;   -N        shut down the write half at stdin's end
;   -q secs   quit secs after stdin's end; a negative wait is forever, the default
;   -w secs   give up a connect, or quit when neither way moves, after secs; not the accept
;
; either way a bidirectional pump, stdin -> socket and socket -> stdout, two tasks each
; parked in a port read on its own fd; the scheduler polls the fds, so no select loop.
; run it straight -- prel is already in the egg, so no `-l love/boot/prel.l`:
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
    usage "usage: nc [-N] [-q SECS] [-w SECS] {HOST PORT | -l PORT}"
    (portof s) (: n (unum s) (? (charm? n && 0 < n < 65536) n (die ("not a port: " + s))))
    ; a flag's whole seconds, -1 when absent or negative
    (secs c) (: v (uoptv t c)
                neg (string? v && 0 < #v && v 0 = 45)
                n (? (string? v) (unum (? neg (snip v 1 #v) v)) -1)
                (? !(charm? n) (die ("-" + string c + " takes whole seconds, not " + v)) neg -1 n))
    q (secs 113)
    w (secs 119)
    seen (tablet 0)   ; the clock at the last chunk either way, for -w

    ; src to dst a chunk at a time until src's eof: see refills and parks, chug takes
    ; the rest of what is read. the flush keeps stdout prompt and is a no-op on a socket
    (pump src dst) (: c (see src)
                      (? (c = -1) 0 (unsee src c, say dst (chug src), flush dst, pin seen 0 (clock 0), pump src dst)))

    ; with -w: quit once neither way has moved for w seconds
    (idle _) (: gap (clock 0 - seen 0)
                (? (w * 1000 <= gap) (flush out, quit 0) (rest (w * 1000 - gap), idle 0)))

    ; wait out the inbound pump: to the peer's eof, or with -q at most q seconds, when a
    ; watchdog task freezes it
    (linger d) (? (q < 0) (catch d)
                  (: w (twirl (_ \ (rest (q * 1000), freeze d)) ())
                     _ (catch d)
                     (freeze w)))

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
               1))

    ; server: listen, accept one client, talk, close the listener
    (serve port) (: l (listen port)
                    (? (hot? l) (: c (accept l)
                            (hot? c ? (talk c, close l, 1)
                             (close l, die "accept failed")))
                       (die $ "cannot listen on port " + show port + " -- " + show l)))

    ; dial, given up after w seconds with -w. a frozen catch answers 0, so the answer
    ; rides wrapped
    (dial-by host port) (? (w < 0) (dial host port)
                           (: r (twirl (_ \ [1 (dial host port)]) ())
                              d (twirl (_ \ (rest (w * 1000), freeze r)) ())
                              x (catch r)
                              _ (freeze d)
                              (two? x ? (x 1) ())))

    (client host port) (: s (dial-by host port)
                          (? s (talk s) (die ("cannot connect to " + host + ":" + show port))))

    (? (uoptun t "lNqw") (die usage)
       (t 108) (#ops = 1 ? (serve (portof <ops)) (die usage))
       (#ops = 2) (client <ops (portof <>ops))
       (die usage))))

; the seat: fire nc-main iff this file sits in the program seat of the real command line --
; the positional program or a `-l` preload -- with the args after it. `cmdline` is the
; full C argv, so both load orders read the same; kore's dispatcher calls nc-main itself.
(: s (cite 'verbs 'fire ["nc" "nc.l"])
   (two? s ? (nc-main >s)))
) ; module nc
