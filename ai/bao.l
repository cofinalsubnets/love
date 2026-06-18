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

   ; --- the raw-line editor (bao's own line reader) ---
   ; repl.l's `edline` is wrong for wrapping a host program: it parses the buffer
   ; as ai forms (submits only when it reads complete) and prints its own `> `. a
   ; wrapped program (bash, python) wants the RAW bytes, submitted on Enter no
   ; matter what. So bao reads its own line -- reusing repl.l's PURE zipper
   ; primitives (edleft/edright/edbsp/eddel/edhome/edend/revcat/edrender, all
   ; in/out-free for the logic), but with PORT-PARAMETERIZED event decode so the
   ; input is any port: `in` for the tty, a (sip ..) for tests. This is the seed of
   ; the editor that will replace repl's (doc/bao.md: bao supersedes the repl).

   ; bev/besc/besc1 are repl.l's edev/edesc/edesc1, reading (fgetc ip) instead of
   ; the global getc -- event codes are identical (printable >0; -1 left, -2 right,
   ; -3 bsp, -4 del, -5 home, -6 end, -7 quit/EOF; 10 = enter; up/down/^C ignored
   ; by a single-line reader).
   (besc1 ip c) (? (= c 126) -5
                   (= c 59) (: _ (fgetc ip) d (fgetc ip)
                              (? (= d 72) -5 (= d 70) -6 (= d 65) -8 (= d 66) -9
                                 (= d 67) -2 (= d 68) -1 0)))
   (besc ip) (? !(= 91 (fgetc ip)) 0
     (: c (fgetc ip)
        (? (= c 68) -1 (= c 67) -2 (= c 65) -8 (= c 66) -9 (= c 72) -5 (= c 70) -6
           (= c 49) (besc1 ip (fgetc ip))
           (= c 55) (: _ (fgetc ip) -5)
           (|| (= c 52) (= c 56)) (: _ (fgetc ip) -6)
           (= c 51) (: _ (fgetc ip) -4) 0)))
   (bev ip) (: c (fgetc ip)
     (? (|| (= c -1) (= c 4)) -7
        (= c 3) -12
        (|| (= c 13) (= c 10)) 10
        (|| (= c 8) (= c 127)) -3
        (= c 1) -5 (= c 5) -6 (= c 27) (besc ip)
        (&& (<= 32 c) (< c 127) c)))

   ; (edraw ip pr) -- read ONE line off port `ip`, with in-line editing, prompt pr
   ; echoed to out. Enter submits the raw line (its bytes, in order); ^D / port EOF
   ; returns eofsym. single line, no history, no parseall -- the text goes straight
   ; back to the caller (bao's wrapper feeds it to a child). the buffer is the
   ; (l . r) halves of repl.l's zipper with the line count (u d) pinned empty, so
   ; the baked single-line primitives drive it unchanged.
   (edraw ip pr)
     (: _ (puts pr) pl (tally pr)
        (loop l r)
          (: _ (edrender pl 0 0 l r 0)
             c (bev ip)
             (km uu ll rr dd) (loop ll rr)         ; motion: edleft/.. give (k u l r d), keep l r
             (? (= c -7) eofsym                     ; ^D / EOF -> the sentinel
                (= c 10) (: _ (putc 10) (revcat l r)); Enter -> submit the raw line, in order
                (< 0 c)  (loop (link c l) r)         ; insert a printable
                (= c -1) (edleft  km 0 l r 0)
                (= c -2) (edright km 0 l r 0)
                (= c -3) (edbsp   km 0 l r 0)
                (= c -4) (eddel   km 0 l r 0)
                (= c -5) (edhome  km 0 l r 0)
                (= c -6) (edend   km 0 l r 0)
                (loop l r)))                         ; up/down/^C/unknown: ignore in a line reader
        (loop 0 0))

   ; the interactive entry. for now it is exactly the baked shell -- install the
   ; faced help if none is present, print the banner, run the editor repl. an arg
   ; is taken (ai has no nullary calls). `wrap` above is reachable from the bao
   ; prompt -- (wrap (L "python3")) pty-wraps a host program; the editor-as-line-
   ; reader and the debug `help` are the later modes (doc/bao.md). the shell reads
   ; from `in`; main.c puts the tty in raw mode before loading bao, restores on exit.
   (bao _) (shell 0))

; bao.l is DEFINE-ONLY -- loading it (egg-bake or `-l ai/bao.l`) installs the
; personality but does NOT launch. The frontend launches: host/main.c evals
; `(bao 0)` on a tty (so `ai` on a terminal is the bao shell), while a pipe stays
; the bare filter. Define-only is what makes bao loadable for tests (load the
; defs, read piped forms with the bare reader -- no editor intermediating stdin)
; and is the shape bao needs to supersede the repl (doc/bao.md).
