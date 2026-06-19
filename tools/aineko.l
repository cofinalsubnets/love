#!/usr/bin/env -S ai -l
; aineko -- a netcat clone in ~50 lines of ai (愛猫, "beloved cat").
;
;   aineko HOST PORT   TCP client: connect to HOST:PORT
;   aineko -l PORT     TCP server: listen on PORT, accept one client
;
; Either way it becomes a BIDIRECTIONAL PUMP -- stdin -> socket and socket ->
; stdout, both live at once. Two tasks, each parked in a port read on a different
; fd, interleave with no select loop: the cooperative scheduler poll()s the fd a
; parked task blocks on (ai_wait_fds) and wakes the ready one (get yields when
; its fd is not ready -- see host/net.c / ai.c). So the whole program is just two
; pump loops + a teardown discipline; the real work is the socket nifs in C.
;
; Run (until the egg bakes aineko into a multi-call binary). prel is ALREADY in
; the egg -- do NOT `-l ai/prel.l` (the egg mops book/tray/etc after it hatches, so
; re-feeding prel.l to the live ev raises `missing book`/`missing tray`):
;   out/host/ai tools/aineko.l HOST PORT
;   out/host/ai tools/aineko.l -l PORT
; The socket nifs (connect/listen/accept/seal) live in host/net.c; prel stays
; socket-free so the kernel/wasm frontends are unaffected.

; A top-level body-having `:` runs directly (and leaks no bindings). NOT wrapped
; in a nullary (aineko-main) -- a bare (f) is `f` itself (the (f) == f law), so a
; zero-arg call would never fire; the program body just IS this form.
(: as (cup argv)                                   ; (cup argv) = the program's args
    ; parse a decimal port string -> a fixnum (a string indexes its bytes; '0' = 48).
    (atoi s) (: (go i acc) (? (< i (tally s)) (go (+ 1 i) (+ (* 10 acc) (- (s i) 48))) acc)
                (go 0 0))
    (die m) (: _ (say err (+ "aineko: " (+ m "\n"))) (nap 1))

    ; pump bytes from port `src` to port `dst`, one byte at a time, until src
    ; hits EOF (get -> -1). flush after each byte makes stdout prompt (it is a
    ; no-op on a socket port -- fd_flush only flushes the real stdout fd), so one
    ; pump serves both directions. Returns nil at EOF; the caller owns teardown.
    (pump src dst) (: ch (get src)
                      (? (= ch -1) 0
                         (: _ (put dst ch) _ (flush dst) (pump src dst))))

    ; the conversation over a connected socket `s`. The two directions are
    ; INDEPENDENT half-duplex channels: a read-side EOF does NOT mean the write
    ; side is dead, so we must drain our outbound stdin fully before closing.
    ;   - stdin -> socket runs in THIS task: it always sends every stdin byte
    ;     before teardown, then half-closes the write side (seal s 1) so the
    ;     peer sees EOF rather than a hung half-open socket.
    ;   - socket -> stdout runs in the spawned task `down`; it ends when the peer
    ;     closes (socket EOF). The two pumps interleave through the cooperative
    ;     scheduler (each parked in a port read on its own fd).
    ; Teardown joins through one path: send all of stdin, half-close, then WAIT
    ; for the inbound pump to drain to the peer's EOF before the final close.
    (talk s) (: down (spin (\ _ (pump s out)) 0)   ; socket -> stdout, in a task
                _ (pump in s)                        ; stdin -> socket (drains fully here)
                _ (seal s 1)                     ; half-close write: peer sees stdin EOF
                _ (catch down)                        ; let the inbound pump drain to socket EOF
                _ (flush out)
                _ (close s)
                1)

    ; server: listen + accept one client, then talk. close the listener after.
    (serve port) (: l (listen port)
                    (? l (: c (accept l)
                            (? c (: _ (talk c) _ (close l) 1)
                               (: _ (close l) (die "accept failed"))))
                       (die (+ "cannot listen on port " (string port)))))

    ; client: connect, then talk.
    (dial host port) (: s (connect host port)
                       (? s (talk s) (die (+ "cannot connect to " (+ host (+ ":" (string port)))))))

    ; dispatch on the args: -l PORT = server, HOST PORT = client, else usage.
    (? (= (cap as) "-l") (? (two? (cup as)) (serve (atoi (caup as)))
                            (die "usage: aineko -l PORT"))
       (two? (cup as)) (dial (cap as) (atoi (caup as)))
       (die "usage: aineko HOST PORT  |  aineko -l PORT")))
