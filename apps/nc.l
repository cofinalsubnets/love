#!/usr/bin/env -S love -l
; nc -- netcat in love.
;
;   nc [-N] host port   tcp client: connect to host:port
;   nc [-N] -l port     tcp server: listen on port, accept one client
;   -N                  shut down the write half at stdin's end
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
 (: t (tablet 0)
    rest ((uopt as t () () ()) 2)
    usage "usage: nc [-N] HOST PORT  |  nc [-N] -l PORT"
    ; a decimal port string -> a fixnum (a string indexes its bytes; '0' = 48)
    (atoi s) (:- (go 0 0) (go i acc) (i < #s ? (go (1 + i) (10 * acc + s i - 48)) acc))
    (die m) (udie 1 ("nc: " + m))

    ; src to dst a chunk at a time until src's eof: see refills and parks, chug takes
    ; the rest of what is read. the flush keeps stdout prompt and is a no-op on a socket
    (pump src dst) (: c (see src)
                      (? (c = -1) 0 (unsee src c, say dst (chug src), flush dst, pump src dst)))

    ; the conversation: stdin -> socket here, socket -> stdout in `down`. all of stdin goes
    ; before teardown, then -N half-closes so the peer sees our eof; without it the peer
    ; must close first. either way wait for the peer's eof before the close
    (talk s) (: down (twirl (_ \ pump s out) 0)
              (pump in s,
               (? (t 78) (seal s 1) 0),
               catch down,
               flush out,
               close s,
               1))

    ; server: listen, accept one client, talk, close the listener
    (serve port) (: l (listen port)
                    (? (hot? l) (: c (accept l)
                            (hot? c ? (talk c, close l, 1)
                             (close l, die "accept failed")))
                       (die $ "cannot listen on port " + string port + " -- " + show l)))

    (client host port) (: s (dial host port)
                          (? s (talk s) (die ("cannot connect to " + host + ":" + string port))))

    (? (uoptun t "lN") (die usage)
       (t 108) (#rest = 1 ? (serve (atoi <rest)) (die usage))
       (#rest = 2) (client <rest (atoi <>rest))
       (die usage))))

; the seat: fire nc-main iff this file sits in the program seat of the real command line --
; the positional program or a `-l` preload -- with the args after it. `cmdline` is the
; full C argv, so both load orders read the same; kore's dispatcher calls nc-main itself.
(: s (cite 'verbs 'fire ["nc" "nc.l"])
   (two? s ? (nc-main >s)))
) ; module nc
