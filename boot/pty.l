; --- boot/pty.l: a runnable smoke test for bao's pty nifs (host/pty.c) ---
; NOT in the test/*.l corpus on purpose: the pty nifs (ptyrun/reap/kill/winsize)
; live in host/pty.c, which the final `ai` links but ai0 does NOT -- and ai0
; bakes the whole corpus, so a corpus test would read these names as missing and
; fail ai0's self-test. So this is verified the host-nif way: standalone, against
; the built binary. Run it (the assert macro comes from test/00-init.l):
;
;   cat test/00-init.l boot/pty.l | out/host/ai      ; green dots = pass, exits 1 on fail
;
; Mechanics are scriptable (here); full interactive wrapping is manual (bao.l).

; reap is non-blocking (WNOHANG): a child can EOF its master a hair before it
; becomes a zombie, so a poll right then reads 0 "still running". That gap is
; exactly why reap returns a PAIR -- poll, don't spin. waitfor blocks for it.
; The exited pair is told from still-running STRUCTURALLY (chainp), never by net:
; the status pair (0) nets blue (a chain of nothings is nothing), so it can't be
; distinguished from 0 by ! / non -- only by being a chain.
(: (waitfor pid)
 (: s (reap pid) (? (chainp s) s (= 0 s) (do (sleep 2) (waitfor pid)) s)))

; --- (ptyrun argv): spawn `echo hello` on a pty, read its output off the master ---
(: r (ptyrun (L "echo" "hello"))
 _ (assert
    (chainp r)            ; (pid . master-port)
    (fixp (cap r))        ; pid is a fixnum
    (< 0 (cap r))         ; ... a real one
    (lamp (cup r)))       ; the master is a heap port
 out (slurp (cup r))      ; drain the master to EOF (echo exits -> slave closes)
 _ (assert
    (< 0 (tally out)))    ; got bytes ("hello" + the pty's \n -> \r\n)
 st (waitfor (cap r))     ; reap the child
 _ (assert
    (chainp st)           ; reaped: a PAIR, not () "still running"
    (= 0 (cap st))))      ; echo exited 0 -- the pair keeps 0 truthy/present

; --- (kill pid sig) + signal-death reap: cat waits forever; SIGKILL it ---
(: r (ptyrun (L "cat"))
 _ (assert (chainp r))
 _ (kill (cap r) 9)       ; SIGKILL -- a positive pid, the process (not the group)
 _ (slurp (cup r))        ; drain to EOF (the killed cat's slave closes)
 st (waitfor (cap r))
 _ (assert
    (chainp st)           ; reaped
    (= 137 (cap st))))    ; 128 + 9: the signal-death encoding

; --- (setwinsize port r c): ok on a live master, errno on a non-port ---
(: r (ptyrun (L "cat"))
 _ (assert
    (non (setwinsize (cup r) 24 80))   ; () = ok
    (fixp (setwinsize 5 24 80)))       ; a bare fixnum (not a port) -> EBADF
 _ (kill (cap r) 9)
 _ (slurp (cup r))
 _ (waitfor (cap r)))

; --- (kill pid sig) on a dead pid -> an errno fixnum (ESRCH), never () ---
(: dead (cap (ptyrun (L "true")))      ; exits immediately
 _ (waitfor dead)                      ; reap it so the pid is truly gone (not a zombie)
 _ (assert (fixp (kill dead 0))))      ; sig 0 probes existence -> ESRCH

; --- bidirectional pty I/O: write to the master, read the child's echo back ---
; the foundation of bao's wrapper -- a host process and bao talk over the master
; port. cat echoes its input, and the pty's own line discipline echoes the typed
; bytes too, so the literal input comes straight back; read it byte by byte (a
; bounded read, NOT slurp -- cat never EOFs). proves the write AND read lanes of
; the master port in one round trip; the full stdin<->stdout pump (bao's `wrap`)
; rides real tty fds, so it is verified manually, like aineko's `make nettest`.
(: r (ptyrun (L "cat"))
 m (cup r)
 _ (fputc m 110) _ (fputc m 101) _ (fputc m 107) _ (fputc m 111) _ (fputc m 10)  ; "neko\n"
 _ (fflush m)
 a (fgetc m) b (fgetc m) c (fgetc m) d (fgetc m)    ; the first 4 bytes back off the master
 _ (assert (= a 110) (= b 101) (= c 107) (= d 111)) ; n e k o -- the round trip over the pty
 _ (kill (cap r) 9)
 _ (waitfor (cap r)))

(puts "pty: ok") (putc 10)
