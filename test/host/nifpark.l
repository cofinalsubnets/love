; test/host/nifpark.l -- a nif that cannot answer yet parks its task, not the vm
; each law is a ticker that advances only if the task under test yields. run bare by
; test/host/run.l under a timeout (failures are hangs), hence the posix borrow here
(cite 'posix ? (borrow 'posix) ())

(: (ticker n) (twirl (_ \ ((: (go u) (pin n 0 (1 + peep n 0 0),
                                      rest 0,
                                      go ())) ())) ()))

; law 1: accept parks on an empty backlog
(: pl (test-listen 0)
   port <pl
   l (pl 1)
   n {}
   srv (twirl (_ \ (accept l @ c (close c, 1))) ())
   t (ticker n)
   _ (rest 20)                          ; both reach their parks; the ticker spins
   k (peep n 0 0)
   c (connect ['tcp "127.0.0.1" port])
   _ (catch srv)
   _ (freeze t)
   _ (close c)
   _ (close l)
   _ (assert (0 < k)))                  ; a blocking accept never gets here at all

; law 2: recv parks on a quiet socket; a peer is (ipv4 << 16) | port, as src/love/sock.c packs it
(: up (test-bind 0)
   p (up 1)
   n {}
   rx (twirl (_ \ (recv p @ d (close p, <>d))) ())
   t (ticker n)
   _ (rest 20)
   k (peep n 0 0)
   s ((test-bind 0) 1)
   _ (send s ["127.0.0.1" <up] "ping")
   got (catch rx)
   (freeze t,
    close s,
    assert (0 < k)
           (got = "ping")))           ; and the datagram still arrives whole

; law 3: wait parks while a child is up; a poll, not an fd wait, so only that a peer runs is pinned
(: n {}
   t (ticker n)
   r (tether '("sleep" "0.3"))
   st (wait <r)
   (freeze t,
    close >r,
    assert (0 < peep n 0 0)         ; 0 with the blocking waitpid back in
           (st = 0)))                 ; ... and the child's status is still exact

; law 4: hark parks through the drain, not just the reap
; the child is slow in the middle: one that writes all at once lets a blocking drain pass
(: n {}
   t (ticker n)
   r (hark '("sh" "-c" "echo one; sleep 0.2; echo two"))
   (freeze t,
    assert (0 < peep n 0 0)         ; 0 with the blocking drain back in
           (<r = 0)
           (>r = "one\ntwo\n")))  ; ... and the capture is still whole

; law 5: connect parks on the handshake, the write-direction park
; the stall is a full accept queue (an unroutable address fails at once): this knows
; src/love/sock.c's listen_backlog, 512; linux queues one more, so backlog+1 fills it.
; the fill closes as it goes: a hangup does not free an unaccepted slot
; closing the listener resets the stalled handshake, and catch reaps its nom
(: pl (test-listen 0)
   port <pl
   l (pl 1)
   n {}
   a (connect ['tcp "127.0.0.1" port])         ; the witness: one that lands, kept open
   (fillq k) (k @ 0 0 (connect ['tcp "127.0.0.1" port] @ c (close c, fillq (k - 1))))
   _ (fillq 512)                        ; a + 512 = 513 = backlog + 1: the queue is full
   t (ticker n)
   s (twirl (_ \ connect ['tcp "127.0.0.1" port]) ())   ; the next: syn dropped, stalls
   _ (rest 50)
   k (peep n 0 0)
   _ (close l)                          ; ... which resets it, so the task ends
   r (catch s)
   (freeze t,
    close a,
    assert (0 < k)                    ; 0 with a blocking connect back in
           (nom? r)                   ; the reset handshake answers its nom
           (lit? a)))                 ; ... and a connect that did land is a port

(say out "nifpark: ok\n")
