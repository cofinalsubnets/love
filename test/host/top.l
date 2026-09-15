; --- test/host/top.l: top's face on a real terminal ---
; the frame builder (apps/kore/top.l's tp-frame) is exercised through `top -b` in
; test/gate/kore.sh with no tty at all; what is left is the face -- raw mode, the
; alternate screen, the poll that stands in for a timer, and the exit that puts
; the screen back. That lane needs a terminal, so it gets one: `tether` spawns
; `kore top` on a pty, we type at the master and read the frames back off it.
; not in the test/*.l corpus -- tether and tty both live in inle/posix.c, which love0
; does not link. Run it (the test macro comes from test/00-init.l):
;
;   LOVEBIN=out/love sh -c "cat test/00-init.l test/host/top.l | out/love"
;
; the pty starts 0x0 until settty lands and the child may read its size before we
; push one, so nothing here asks about geometry -- only about what any window
; shows: the header, the column row, our own keys landing, and the screen put back.

(: love (getenv "LOVEBIN")
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid))))
   ; the keys go in ONE AT A TIME, a fifth of a second apart. typed as one word they
   ; arrive in a single read, and the q at the end of it would be found in the same
   ; buffer as the repaints ahead of it and win -- correctly, and with nothing left
   ; to count. a reader types slower than a pipe.
   (type m s) (: n (tally s)
                 (go i) (? (n <= i) 0 (do (say m (string (s i))) (rest 200) (go (i + 1))))
                 (go 0))
   ; spawn `love kore top ARGS..` on a pty, size it, type keys, answer what it drew.
   ; every key list ends in q: a run that failed to quit would park this harness on
   ; `slurp` until the gate's own clock ran out, with no word about which key did it.
   (run keys args)
    (: r (tether (cat [love "kore" "top"] args))
       _ (test (two? r))
       m >r
       _ (settty m 24 100)
       _ (type m (keys + "q"))
       txt (slurp m)
       st (waitfor <r)
       [txt <st])
   (has? t s) (: n (tally t) k (tally s)
                 (go i) (? ((n - k) < i) () (= (snip t i (i + k)) s) 1 (go (i + 1)))
                 (go 0))
   (cnt t s) (: n (tally t) k (tally s)
                (go i a) (? ((n - k) < i) a (go (i + 1) (? (= (snip t i (i + k)) s) (a + 1) a)))
                (go 0 0))

   ; --- q leaves at once, and what it leaves behind is a screen put back ---
   r1 (run "" [])
   t1 <r1
   _ (test
      (0 = <>r1)                            ; the status a seat quits with
      (has? t1 "\e[?1049h")                 ; the alternate screen was entered
      (has? t1 "\e[?1049l")                 ; ..and left, which is the whole contract
      (has? t1 "PID USER")                  ; the column row was drawn
      (has? t1 "%Cpu(s):")                  ; ..under the headers
      (has? t1 "Tasks:")
      (has? t1 "load average:"))

   ; --- a repaint key draws a second frame without waiting out the delay. the delay
   ; is three seconds and this run takes nowhere near that, so a second column row
   ; is proof the poll cut the wait short and nothing else could be.
   r2 (run "rr" [])
   _ (test (0 = <>r2) (2 < (cnt <r2 "PID USER")))

   ; --- an unknown option is a usage refusal and not a screen ---
   r3 (run "" ["-Z"])
   _ (test (2 = <>r3) !(has? <r3 "PID USER"))

   _ (puts "test/host/top: top's face on a pty -- the alternate screen both ways, the headers, a key that repaints, the refusal\n")
   (flush out))
