; the socket nifs over loopback in one process, server and client as tasks; host only

; a line off p, ended by \n or eof
(? hosted (do
  (: (rdline p) (:- (go "") (go acc)
                 (see p @ (10 || -1) acc ch (go (acc + string ch)))))

  ; --- listen / accept / connect / get / say / seal over 127.0.0.1 ---
  (: pl (test-listen 0)
   port <pl
   l (pl 1)
   _ (test
      (lit? l)                              ; the listener is a heap port
      (hot? l))                             ; ... an opaque hot, like any fd port
   ; server task: accept, echo a line, half-close, close
   srv (twirl (_ \ (: c (accept l)
                      ln (rdline c)
                      (say c (ln + "\n"),
                       seal c 1,
                       close c, 1))) 0)
   c (connect ['tcp "127.0.0.1" port])
   _ (test
      (lit? c)                              ; the client side is a heap port too
      (hot? c))
   _ (say c "neko\n")
   echo (rdline c)
   _ (test
      (echo = "neko"))                      ; the round trip: what went out came back
   ; (seal s how) answers the port; a no-op on a non-port
   _ (test
      (lit? (seal c 1)) ; answers the port
      (5 = seal 5 1))   ; misuse: answers the arg unchanged
   _ (catch srv)        ; catch the server task -- no orphan
   _ (close c)
   _ (close l))

  ; --- every failure answers a nom that says which ---
  (: none (test-free 0)   ; a port of ours, its listener gone
     _ (test
      ('badarg = listen -1)                       ; bad port: refused up here
      ('econnrefused = connect ['tcp "127.0.0.1" none])  ; nothing listening there
      ('badarg = connect ['tcp 12345 80])         ; non-string host
      ('badarg = connect ['tcp "example.org" 80])  ; a NAME is a misuse: connect takes a quad
      ('badarg = bind ['udp -1])
      ; the address is a list whose head names a family the verb has: nothing else goes
      ('badarg = connect 12345) ('badarg = connect ['ftp "127.0.0.1" 21])
      ('badarg = listen ['udp 7393]) ('badarg = bind ['tcp 7393]) ('badarg = connect ['icmp])
      ('badarg = bind ['udp 0 'fast]) ('badarg = connect ['unix ""])
      ('badarg = connect ['icmp6]) ('badarg = bind ['icmp6 'fast])
      ; a peer's v6 text is read whole: a second :: is no address
      (: u (bind ['udp 0]) r (send u ["1::2::3" 9] "x") (close u, 'badarg = r))))

  ; --- seal lands the write run first: put parks bytes undrained, and both must cross ---
  (: pl (test-listen 0)
   port <pl
   l (pl 1)
   got {}
   srv (twirl (_ \ (: c (accept l)
                      n ((: (go k) (see c @ -1 k (go (k + 1)))) 0)
                      (pin got 0 n,
                       close c, 1))) 0)
   c (connect ['tcp "127.0.0.1" port])
   _ (each [104 105] (b \ put c b))         ; held in the write run, not sent
   _ (seal c 1)                             ; ... and the fin it sends is the server's EOF
   _ (catch srv)
   _ (test
      (peep got 0 0 = 2))                 ; both bytes crossed the half-close
   _ (close c)
   _ (close l))

  ; --- slurp over a port that parks is linear: a park copies the task's stack ---
  (: pl (test-listen 0)
   port <pl
   l (pl 1)
   got {}
   srv (twirl (_ \ (: c (accept l) s (slurp c) (pin got 0 #s, close c, 1))) 0)
   c (connect ['tcp "127.0.0.1" port])
   _ (say c ("x" * 160000))
   _ (close c)
   t0 (clock 0)
   _ (catch srv)
   ms (clock t0)
   _ (close l)
   _ (test
      (peep got 0 0 = 160000)             ; every byte
      (ms < 3000)))

  ; --- a peer that hangs up mid-response does not kill the runtime: sigpipe is ignored ---
  (: pl (test-listen 0)
   port <pl
   l (pl 1)
   srv (twirl (_ \ accept l @ c
                   (((: (go k) (k = 0 ? 0
                                  (say c ("x" * 200000), rest 5, go (k - 1)))) 30),
                    close c, 1)) 0)
   c (connect ['tcp "127.0.0.1" port])
   _ (rest 30)
   _ (close c)                              ; hang up mid-response
   _ (rest 400)
   _ (catch srv)
   _ (close l))                             ; reaching here at all is the law

  ; a listener on one address, loopback's, reached there; a quad that is not one refused
  (: pl (test-seat (p \ listen ['tcp "127.0.0.1" p]))
     l (pl 1) c (connect ['tcp "127.0.0.1" <pl]) s (accept l)
     (close c, close s, close l,
      (test (hot? l) (hot? c) (hot? s) ('badarg = listen ['tcp "1.2.3" (test-free 0)]))))

  ; --- the other families: unix streams, udp's peer, an icmp echo ---
  (: path ("/tmp/.love-net-unix-" + show (getpid 0) + ".sock")   ; short, under sun_path's 108
   l (listen ['unix path])
   srv (twirl (_ \ (: c (accept l) ln (rdline c) (say c (ln + "!\n"), close c, 1))) 0)
   c (connect ['unix path])
   _ (say c "neko\n")
   echo (rdline c)
   _ (close c) _ (catch srv) _ (close l)
   miss (connect ['unix (path + ".none")])
   (unlink path,
    (test (hot? l) (echo = "neko!") ('enoent = miss))))
  ; a listen clears a stale socket at its path, but a file there stays whole
  (: path ("/tmp/.love-net-" + show (getpid 0) + ".sock")
   _ (unlink path)
   q (open path "w") _ (say q "keep me") _ (close q)
   f (listen ['unix path])
   r (open path "r") kept (slurp r) _ (close r)
   _ (unlink path)
   a (listen ['unix path]) _ (close a)            ; leaves its socket file behind
   b (listen ['unix path]) (close b,              ; a restarted server still binds over it
                            unlink path,
                            (test ('eaddrinuse = f) (kept = "keep me") (hot? a) (hot? b))))
  ; a datagram comes with its peer as send takes one, so a reply is (send p (car d) ..)
  (: ua (test-bind 0) ub (test-bind 0)
   pa <ua pb <ub a (ua 1) b (ub 1)
   _ (send b ["127.0.0.1" pa] "ping")
   d (recv a)
   _ (send a <d "pong")
   e (recv b)
   (close a, close b,
    (test (<>d = "ping") (<(<d) = "127.0.0.1") (<d 1 = pb) (e = [["127.0.0.1" pa] "pong"]))))
  ; an icmp echo to loopback with its ttl; unprivileged it may be refused
  (bind ['icmp 'ttl] @ p
   (nom? p ? (test ('eacces = p || 'eperm = p || 'eprotonosupport = p))
      (: _ (send p ["127.0.0.1" 0] ("\x08\x00\x00\x00\x00\x00\x00\x01" + "love"))
         d (recv p)
         (close p,
          (test (<(<d) = "127.0.0.1") (<>d 0 = 0) (snip <>d 8 12 = "love") (0 < d 2 <= 255))))))
  ; and icmp6 to ::1; a host with no v6 refuses the socket or the send
  (bind ['icmp6 'ttl] @ p
   (nom? p ? (test ('eacces = p || 'eperm = p || 'eprotonosupport = p || 'eafnosupport = p))
      (: w (send p ["::1" 0] ("\x80\x00\x00\x00\x00\x00\x00\x01" + "love"))
         d (nom? w ? () (recv p))
         (close p,
          (nom? w ? (test 1)
             (test (<(<d) = "::1") (<>d 0 = 129) (snip <>d 8 12 = "love") (0 < d 2 <= 255)))))))

  (test_fin ())
))
