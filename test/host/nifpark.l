; test/host/nifpark.l -- the nif floor's laws: a nif that cannot answer yet parks its task
; instead of stopping the vm inside a syscall. every law is a ticker task that advances only if
; the task under test gave up its turn. driven by test/host/run.l under a timeout, since most of
; these regressions are hangs; the checks are `assert`, which stops the run.

; driven bare -- no test/00-init.l ahead of it -- so the posix door is borrowed here,
; the same guarded way the corpus prelude borrows it.
(cite 'posix ? (borrow 'posix) ())

(: (ticker n) (twirl (_ \ ((: (go u) (pin n 0 (1 + peep n 0 0),
                                      rest 0,
                                      go ())) ())) ()))

; --- law 1: accept parks on an empty backlog ----------------------------------
; the server task reaches `accept` before anyone has connected. Under the blocking
; accept it sat in the syscall and nothing else in the process ran -- not the ticker,
; and not the main task that was about to connect, which is why the control hangs.
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

; --- law 2: recv parks on a quiet socket ----------------------------------
; the same law on the datagram side. The peer address is (ipv4 << 16) | port --
; 127.0.0.1 is 2130706433 -- which is how src/love/sock.c marshals a sockaddr into a
; charm.
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

; --- law 3: wait parks while a child is up ------------------------------------
; and it is a poll, not an fd wait: sigchld is not in the scheduler's wait set and
; a pid is not an fd, so `wait` re-arms for the next tick. That is rung 5's shape for
; the write residue and the same trade. What the law pins is only that a peer runs --
; how often the waiter wakes to ask is the poll's business, not the law's.
(: n {}
   t (ticker n)
   r (tether '("sleep" "0.3"))
   st (wait <r)
   (freeze t,
    close >r,
    assert (0 < peep n 0 0)         ; 0 with the blocking waitpid back in
           (st = 0)))                 ; ... and the child's status is still exact

; --- law 4: hark parks for the child's whole life ------------------------------
; not the reap -- the drain. a blocking read(2) over the child's stdout held the
; vm for as long as the child had anything left to say. `hark` is a two-ap nif
; body ({start},{drain},{ret0}) because the op is not re-runnable where it parks:
; a re-entry from the top would fork a second child. So the fork is one op, the
; capture is the other, and the five stack slots between them are the park state.
; the child must be slow in the middle, not just at the end -- a child that
; writes everything at once and exits would let a blocking drain finish in one
; read and the law would pass over the bug.
(: n {}
   t (ticker n)
   r (hark '("sh" "-c" "echo one; sleep 0.2; echo two"))
   (freeze t,
    assert (0 < peep n 0 0)         ; 0 with the blocking drain back in
           (<r = 0)
           (>r = "one\ntwo\n")))  ; ... and the capture is still whole

; --- law 5: connect parks on the handshake ------------------------------------
; the write-direction park, and the only one there is -- held back until something
; asked for it, and connect is what asked. a socket that has sent
; its syn is not readable and will not be; pollout is the question, which is why
; the scheduler carries a direction per parked task at all.
;
; the instrument is a full accept queue, and nothing else offline works: an
; unroutable address is no good, because a machine with no route to it fails
; instantly with enetunreach and the law would pass straight over the bug. a syn
; the kernel drops is retried for about two minutes, which is the stall this needs.
;
; so this law knows src/love/sock.c's `listen_backlog` by VALUE, and has to: it
; fills the queue that constant sizes. linux queues one more than asked (the test
; is `> max`), so backlog+1 arrivals fill it and the next is dropped. if the
; constant moves and this does not, the fill stops one short, the stalled connect
; lands instead, and `(nom? r)` reddens -- noisily, which is the point.
;
; and the fill closes as it goes, which costs one fd instead of 513: a client
; hangup does not free the slot. An unaccepted connection holds its place in the
; queue until something accepts it, and nothing here ever does.
;
; closing the listener is what ends it: the queued connections reset, the stalled
; client's handshake fails, and `catch` reaps the failure's nom. no freeze, so no
; socket is left behind by a task unspliced mid-park.
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
