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

; the interactive entry. for now it is exactly the baked shell -- install the
; faced help if none is present, print the banner, run the editor repl. an arg is
; taken (ai has no nullary calls); later it dispatches bao's own modes (wrap a
; command over a pty, the debug repl). the shell reads from `in`; main.c puts the
; tty in raw mode before loading bao, and restores it on exit.
(: (bao _) (shell 0))

; load = launch (the -l lane read-evals each form, then falls through to the bare
; stdin runner once the shell returns on ^D). the tty frontend loads bao for this
; top-level call; nothing else here runs at load time.
(bao 0)
