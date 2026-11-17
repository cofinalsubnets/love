; src/apps/net/sock.l -- sockets over ip.l and tcp.l in the hosted door's shapes (src/love/sock.c):
; addresses as data, peers as ("quad" port), errors as the errno's nom. every call is one step
; that never waits: where the hosted door parks, this answers 'eagain, and readiness says when
; to ask again. a socket is a tablet: a connection, a listening port, or a bound udp port
;   (sock-connect st (tcp "1.2.3.4" 80) now)   -> s, its handshake under way; s writable once up
;   (sock-listen st (tcp 80) now) or a bare port, or (tcp "quad" 80)   -> s | 'eaddrinuse
;   (sock-bind st (udp 53)) (udp "quad" 53), port 0 any   -> s | 'eaddrinuse
;   (sock-accept l now)        -> a connection | 'eagain
;   (sock-write s b now)       -> the bytes taken | 'eagain | 'epipe | 'enotconn | the error
;   (sock-read s now)          -> bytes | 'eagain | "" at the end | the error
;   (sock-send u peer b now)   -> u | 'emsgsize ; (sock-recv u) -> (peer bytes) | 'eagain
;   (sock-seal s how now)      shutdown(2): 0 the read half, 1 the write half, 2 both; -> s
;   (sock-close s now)         a connection's fin, or its rst when unread data is left
;   (sock-farend s) (sock-name s) -> ("quad" port) | 'enotconn
;   (sock-readable? s) (sock-writable? s) (sock-closed? s) (sock-err s) -> a nom or ()
;   (sock-port s)              -> a duct (src/love/io.c) over a connection: say, see, chug,
;                                 seal and close work it, each net-pump moving its bytes
; a malformed address or the wrong kind of socket answers 'badarg, as the hosted door does
(module (sock sock-connect sock-listen sock-bind sock-accept sock-write sock-read sock-send
         sock-recv sock-seal sock-close sock-farend sock-name sock-readable? sock-writable?
         sock-closed? sock-err sock-port)
(borrow '(bytes net tcp))
(:
   dg-max 1472
   any (quad 0 0 0 0)
   (ip-of s) (: ps (split "." s)
                ns (map unum ps)
                (#ps = 4 && #(filter (n \ charm? n && n < 256) ns) = 4 ? (string ns) ()))
   (port? p) (charm? p && 0 <= p < 65536)
   ; (fam ip port) | (), from (fam port) (fam "quad" port) or, for tcp, a bare port
   (addr x fam)
    (? (charm? x) (fam = 'tcp && port? x ? [fam any x] ())
       (!(two? x) || <x != fam) ()
       (>x @ [p] (port? p ? [fam any p] ())
             [q p] (string? q && port? p ? (ip-of q @ i (i != () ? [fam i p] ())) ())
             _ ()))
   (peer i p) [(ip-show i) p]
   (enom e) (e @ 'reset 'econnreset 'refused 'econnrefused 'timeout 'etimedout _ e)
   (conn st t) {'k 'tcp 'st st 't t 'rshut 0 'wshut 0 'shut 0}
   (tcp? s) (tablet? s && s 'k = 'tcp)

   (sock-connect st x now)
    (addr x 'tcp @ [_ i p] (0 < p ? (conn st (tcp-connect st i p now)) 'badarg)
                  _ 'badarg)
   (sock-listen st x now)
    (addr x 'tcp @ [_ i p] (? (p = 0) 'badarg
                              (tcp-listening? st p) 'eaddrinuse
                              (tcp-listen st p, {'k 'listen 'st st 'port p 'ip i 'shut 0}))
                  _ 'badarg)
   (sock-bind st x)
    (addr x 'udp @ [_ i p0]
                   (: p (p0 = 0 ? (eph st) p0)
                      (? (peep (st 'udp) p 'none != 'none) 'eaddrinuse
                         (udp-bind st p, {'k 'udp 'st st 'port p 'ip i 'shut 0})))
                  _ 'badarg)
   ; the next free udp port from 49152
   (eph st)
    (: (go p n) (? (n = 0) 0 (peep (st 'udp) p 'none = 'none) (pin st 'ueph p, p)
                   (go (p = 65535 ? 49152 (p + 1)) (n - 1)))
       (go (peep st 'ueph 49151 @ p (p = 65535 ? 49152 (p + 1))) 16384))
   (sock-accept l now)
    (? (!(tablet? l) || l 'k != 'listen) 'badarg
       (l 'shut) 'einval
       (tcp-accept (l 'st) (l 'port) @ t (t = () ? 'eagain (conn (l 'st) t))))

   ; --- a connection's bytes ------------------------------------------------------------------
   (sock-err s) (tcp? s ? (s 't @ t (t 'err = () ? () (enom (t 'err)))) ())
   (sock-write s b now)
    (? (!(tcp? s)) 'badarg
       (sock-err s != ()) (sock-err s)
       (s 'wshut || s 'shut) 'epipe
       (s 't @ t
          (? (t 'st = 'syn-sent || t 'st = 'syn-rcvd) 'eagain
             (!(elem (t 'st) '(established close-wait))) 'epipe
             (#b = 0) 0
             (tcp-write (s 'st) t b now @ n (n = 0 ? 'eagain n)))))
   (sock-read s now)
    (? (!(tcp? s)) 'badarg
       (s 'rshut || s 'shut) ""
       (s 't @ t
          (tcp-read (s 'st) t now @ r
             (? (r = ()) ""
                (0 < #r) r
                (sock-err s != ()) (sock-err s)
                (t 'st = 'closed) ""
                'eagain))))
   (sock-seal s how now)
    (: _ (tcp? s && (how = 0 || how = 2) ? (pin s 'rshut 1) 0)
       _ (tcp? s && (how = 1 || how = 2) && !(s 'wshut) ? (pin s 'wshut 1, tcp-close (s 'st) (s 't) now) 0)
       s)
   (sock-close s now)
    (? (s 'shut) ()
       (: _ (pin s 'shut 1)
          (s 'k @ 'tcp (s 't @ t (? (t 'st = 'closed) ()
                                    (0 < t 'rbn) (tcp-abort (s 'st) t now, ())
                                    (s 'wshut) ()
                                    (tcp-close (s 'st) t now, ())))
                   'listen (tcp-unlisten (s 'st) (s 'port) now, ())
                   'udp (udp-unbind (s 'st) (s 'port), ())
                   _ ())))
   (sock-farend s)
    (? (!(tcp? s) || elem ((s 't) 'st) '(syn-sent closed)) 'enotconn
       (s 't @ t (peer (t 'rip) (t 'rp))))
   (sock-name s)
    (? (tcp? s) (s 't @ t (peer (t 'lip) (t 'lp)))
       (tablet? s && s 'port) (peer (s 'ip) (s 'port))
       'enotconn)

   ; --- datagrams --------------------------------------------------------------------------
   (udp? s) (tablet? s && s 'k = 'udp && !(s 'shut))
   (sock-send u to b now)
    (? (!(udp? u) || !(two? to) || #to != 2) 'badarg
       (dg-max < #b) 'emsgsize
       (to @ [q p] (ip-of q @ i (i = () || !(port? p) || p = 0 ? 'badarg
                                   (udp-send (u 'st) i (u 'port) p b now, u)))))
   (sock-recv u)
    (? (!(udp? u)) 'badarg
       (udp-recv (u 'st) (u 'port) @ [i p b] [(peer i p) b] _ 'eagain))

   ; --- readiness: true when the call it names would not answer 'eagain ------------------------
   (sock-readable? s)
    (? (s 'shut) 1
       (s 'k @ 'listen (two? (peep ((s 'st) 'lsn) (s 'port) ()))
                'udp (two? (peep ((s 'st) 'udp) (s 'port) ()))
                'tcp (s 't @ t (two? (t 'rb) || t 'pfin || t 'err != () || t 'st = 'closed || s 'rshut))
                _ 0))
   (sock-writable? s)
    (? (s 'shut) 1
       (s 'k @ 'udp 1
                'tcp (s 't @ t (? (t 'err != () || s 'wshut || t 'st = 'closed) 1
                                  (elem (t 'st) '(established close-wait)) (t 'fin ? 1 (0 < tcp-room t))
                                  (!(elem (t 'st) '(syn-sent syn-rcvd)))))
                _ 0))
   (sock-closed? s)
    (? (s 'shut) 1
       (tcp? s) ((s 't) 'st = 'closed)
       0)

   ; --- a connection as a port --------------------------------------------------------------
   ; each duct rides the stack's 'ducts by its connection's key, moved by a ticker. a pin or a
   ; pull of one key is all either side does: a task preempted mid-turn loses nothing. po and pi
   ; hold what one side took and the other could not yet, so a full side stalls the next take
   (sock-port s)
    (? (!(tcp? s)) 'badarg
       (: st (s 'st)
          d (duct 0)
          _ (peep st 'ducts 'none = 'none ? (pin st 'ducts {}, pin st 'ticks (duct-tick . st 'ticks)) 0)
          (pin (st 'ducts) ((s 't) 'key) {'d d 's s 'po "" 'pi "" 'wend 0 'wsent 0 'rend 0 'done 0}, d)))
   (duct-tick st now)
    (each (keys (st 'ducts))
      (k \ peep (st 'ducts) k () @ e (e = () ? 0 (outward e now, inward e now, e 'done ? (pull (st 'ducts) k 0) 0))))
   ; the far side failed: the program hears the nom as its end, and writes no more
   (gone e n) (pin e 'po "", pin e 'wend 1, pin e 'wsent 1, pin e 'rend 1, duct-feed (e 'd) n)
   ; the program's bytes to the socket, then its write half's end as a fin
   (outward e now)
    (: d (e 'd) s (e 's)
       _ ((#(e 'po) = 0 && !(e 'wend)) ? (duct-take d @ b (b = () ? (pin e 'wend 1) (pin e 'po b))) 0)
       (? (0 < #(e 'po))
            (sock-write s (e 'po) now @ n (? (charm? n) (pin e 'po (snip (e 'po) n #(e 'po))) (n = 'eagain) 0 (gone e n)))
          (e 'wend && !(e 'wsent)) (pin e 'wsent 1, sock-seal s 1 now)
          0))
   ; the socket's bytes to the program; once it reads no more they are drained, and when its
   ; write half is done too the socket closes
   (inward e now)
    (: d (e 'd) s (e 's)
       room (duct-room d)
       (? (room < 0) (sock-read s now, e 'wsent ? (pin e 'done 1, sock-close s now) 0)
          (0 < #(e 'pi)) (duct-feed d (e 'pi) @ n (pin e 'pi (snip (e 'pi) n #(e 'pi))))
          (e 'rend) 0
          (sock-read s now @ r
             (? (r = 'eagain) 0
                (r = "") (pin e 'rend 1, duct-feed d ())
                (string? r) (duct-feed d r @ n (pin e 'pi (snip r n #r)))
                (gone e r)))))
)
) ; module sock
