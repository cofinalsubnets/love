; bao -- the interactive shell personality. a HOST-ONLY, LOADABLE lib: the tty
; frontend auto-loads it, and `ai -l ai/bao.l` launches it by hand. raw `ai`
; stays a pure read/eval/write filter (a pipe gets the bare stdin runner); bao is
; the whole interactive shell on top of it.
;
; WHY bao drives repl.l rather than OWNING the editor: the editor + repl + the
; stream shell (zevs) + the floor handler (welp) live in the egg-baked repl.l and
; CANNOT move here --
;   * the freestanding kernel (kmain.c) calls (shell 0) directly and has no file
;     loader, so its shell must be baked into the kernel image;
;   * ai0's self-test bakes the whole corpus, which drives the editor primitives
;     (test/repl.l), parseall (test/replio.l), zev/zevs/charms (test/zev.l), and
;     asserts welp (test/help.l) -- all of it must be in the baked egg.
; so repl.l is the REUSABLE editor/repl core (host + kernel + the ai0 corpus), and
; bao is the host personality that drives it -- and the seam the pty-wrapper and
; the debugger (doc/bao.md) grow into: wrapping host processes over a pty (ptyrun,
; host/pty.c) and a `help`-handler-with-a-face are bao's, not the core's.

; pump bytes from port `src` to port `dst`, one at a time, until src hits EOF
; (fgetc -> -1); fflush after each byte keeps the far side prompt. (Same shape as
; aineko's pump -- prel stays socket/pty-free, so each app carries its own.)
(: (pump src dst) (: ch (fgetc src) (? (= ch -1) 0 (: _ (fputc dst ch) _ (fflush dst) (pump src dst))))

   ; poll a non-blocking (reap pid) to its exited PAIR. the pair is told from
   ; still-running (0) STRUCTURALLY (chainp), never by net: the status pair (0)
   ; nets blue, so ! / non can't tell it from 0 -- only chainp can.
   (waitfor pid) (: s (reap pid) (? (chainp s) s (= 0 s) (do (sleep 2) (waitfor pid)) s))

   ; (wrap argv) -- run argv on a fresh pty and become a TRANSPARENT bidirectional
   ; pump: stdin -> the child, the child's output -> stdout, both live at once
   ; (the two pumps park on different fds and interleave through the cooperative
   ; scheduler, like aineko). The teardown differs from aineko's SYMMETRIC network
   ; pump, though: a wrapped PROCESS can exit while stdin is still open, so the
   ; child's death is the primary signal -- master->stdout runs HERE and ends on
   ; master EOF (the child gone); the stdin->master side runs in `up` and, on the
   ; user's own EOF, forwards VEOF (byte 4) so a canonical child exits. funnel
   ; through one death: when master EOF lands, join `up` -- wait if it already
   ; finished (user EOF first), else hush it (still parked on stdin; the child is
   ; dead so dropping pending input is correct, not aineko's data-loss case).
   ; returns the child's exited status pair, or ptyrun's errno fixnum on spawn
   ; failure. NOTE: drives the real in/out tty fds, so it is exercised manually
   ; (the in-process gate covers the master read/write lanes; see boot/pty.l).
   (wrap argv)
     (: r (ptyrun argv)
        (? (chainp r)
           (: pid (cap r) m (cup r)
              up (spawn (\ _ (: _ (pump in m) (fputc m 4))) 0)   ; stdin -> child; VEOF on user EOF
              _ (pump m out)                                      ; child -> stdout; ends when the child dies
              _ (? (done? up) (wait up) (hush up))                ; join the input pump through the one death
              _ (fflush out)
              _ (close m)
              (waitfor pid))                                      ; reap the child
           r))

   ; the interactive entry. for now it is exactly the baked shell -- install the
   ; faced help if none is present, print the banner, run the editor repl. an arg
   ; is taken (ai has no nullary calls). `wrap` above is reachable from the bao
   ; prompt -- (wrap (L "python3")) pty-wraps a host program; the editor-as-line-
   ; reader and the debug `help` are the later modes (doc/bao.md). the shell reads
   ; from `in`; main.c puts the tty in raw mode before loading bao, restores on exit.
   (bao _) (shell 0))

; load = launch (the -l lane read-evals each form, then falls through to the bare
; stdin runner once the shell returns on ^D). the tty frontend loads bao for this
; top-level call; nothing else here runs at load time.
(bao 0)
