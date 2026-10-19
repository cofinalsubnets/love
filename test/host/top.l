; test/host/top.l -- `love top` on a pty (frames are lawed by test/kore/top.sh); it signals
; and renices only sleeps this file spawned, pointed at with -p
; run: LOVEBIN=out/love sh -c "cat test/00-init.l test/host/top.l | out/love"

(: love (getenv "LOVEBIN")
   bf (cask 65536)
   (waitfor pid) (gather pid @ s (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid))))
   ; drain for ms: an unread frame blocks top, and keys typed meanwhile land in one read
   (drain m acc ms) (swig m bf @ n
                       (? (charm? n && 0 < n) (drain m (acc + snip bf 0 n) ms)
                          (ms < 1) acc
                          (do (rest 20) (drain m acc (ms - 20)))))
   ; ..or until the alt screen is raised: a key typed before the tty is raw meets a cooked line
   (raised m acc ms) (? (has? acc "\e[?1049h") (drain m acc 300)
                        (ms < 1) acc
                        (raised m (drain m acc 100) (ms - 100)))
   ; top on a 24x100 pty, each key sent whole; a function key acts on the master.
   ; esc then q leaves any mode. answers [transcript status last-frame-text]
   (run keys args)
    (: r (tether (cat [love "top"] args))
       _ (test (two? r))
       m >r
       _ (settty m 24 100)
       t0 (raised m "" 5000)
       t1 (foldl (acc \ k \ ((string? k ? (say m k) (k m)), drain m acc 500)) t0 keys)
       t2 (say m "\e", drain m t1 300)
       _ (say m "q")
       txt (t2 + slurp m)
       st (waitfor <r)
       s (screen (cask (screen () 24 100)) 24 100)
       (scribe s t1,
        [txt <st (copied s 0 2400)]))
   (cnt t s) (: (go i a) (findsub (snip t i #t) s @ k (k < 0 ? a (go (i + k + 1) (a + 1))))
                (go 0 0))
   (at t s) (findsub t s)
   (lineof t s) (at t s @ k (k < 0 ? -1 (cnt (snip t 0 k) "\n")))
   (click x y) ("\e[<0;" + show (x + 1) + ";" + show (y + 1) + "M\e[<0;" + show (x + 1) + ";"
                + show (y + 1) + "m")
   (sleeper _) (spawn ["sleep" "30"])
   (nice p) (uread ("/proc/" + show p + "/stat") @ r ((cite 'kore 'ustatf) <>r 18))

   ; the plain face (-P)
   r1 (run [] ["-P"])
   t1 <r1
   _ (test
      (0 = r1 1)
      (has? t1 "\e[?1049h")
      (has? t1 "\e[?1049l")
      (has? t1 "PID USER")
      (has? t1 "%Cpu(s):")
      (has? t1 "Tasks:")
      (has? t1 "load average:")
      !(has? t1 "\e[?1006h"))               ; no mouse

   ; a repaint key draws without waiting out the delay
   r2 (run ["r" "r"] ["-P"])
   _ (test (0 = r2 1) (2 < cnt <r2 "PID USER"))

   ; the rich face, the default; its exit puts the mouse, cursor and screen back
   r3 (run [] [])
   t3 <r3
   _ (test
      (0 = r3 1)
      (has? t3 "\e[?1049h") (has? t3 "\e[?1006h") (has? t3 "\e[38;5;")
      (has? (r3 2) "Load average:") (has? (r3 2) "Tasks:") (has? (r3 2) "Mem")
      (has? (r3 2) "PID USER") (has? (r3 2) "F10Quit")
      (at t3 "\e[?1049h" < at t3 "\e[?1006l")
      (has? t3 "\e[?1000l") (has? t3 "\e[?25h") (has? t3 "\e[?1049l"))

   ; -C: no colour
   r4 (run [] ["-C"])
   _ (test (0 = r4 1) (has? (r4 2) "PID USER") !(has? <r4 "\e[38;5;"))

   r5 (run ["h"] [])
   r6 (run ["\e[17~"] [])
   r7 (run ["u"] [])
   _ (test (has? (r5 2) "any key goes back") (has? (r6 2) "Sort by:") (has? (r7 2) "Show user:")
           (0 = r5 1) (0 = r6 1) (0 = r7 1))

   r8 (run [(m \ (settty m 30 100)) "r"] [])
   _ (test (0 = r8 1) (has? <r8 "\e[30;1H"))

   ; k: enter sends TERM
   s1 (sleeper 0)
   r9 (run ["k" "\r"] ["-p" (show s1)])
   k1 (waitfor s1)
   _ (test (0 = r9 1) (has? <r9 "Send signal:") (143 = <k1))

   ; ] twice: two steps nicer
   s2 (sleeper 0)
   b2 <(sound (nice s2))
   r10 (run ["]" "]"] ["-p" (show s2)])
   n2 <(sound (nice s2))
   _ (still s2 9)
   _ (waitfor s2)
   _ (test (0 = r10 1) (n2 = b2 + 2))

   me (getpid 0)
   s3 (sleeper 0)
   s4 (sleeper 0)
   ps ["-p" (show me) "-p" (show s3) "-p" (show s4)]
   ; t: tree
   r11 (run ["t"] ps)
   _ (test (0 = r11 1) (has? (r11 2) "├─ sleep 30") (has? (r11 2) "└─ sleep 30"))
   ; \: filter
   r12 (run ["\\" "sleep" "\r"] ps)
   _ (test (0 = r12 1) (has? (r12 2) " filter sleep") (has? (r12 2) (show s3 + " "))
           !(has? (r12 2) (show me + " ")))
   r13 (run ["/" "sleep"] ps)
   _ (test (0 = r13 1) (has? (r13 2) "Search: sleep"))
   ; a click on the PID heading sorts by it, a second reverses
   hy (lineof (r13 2) "PID USER")
   r14 (run [(click 3 hy)] ps)
   r15 (run [(click 3 hy) (click 3 hy)] ps)
   _ (test (0 = r14 1) (0 = r15 1) (0 < hy)
           (at (r14 2) (show s3 + " ") < at (r14 2) (show s4 + " "))
           (at (r15 2) (show s4 + " ") < at (r15 2) (show s3 + " ")))
   ; a click selects a row: N sorts by pid, so the third row is s4
   r16 (run ["N" (click 20 (hy + 3)) "k" "\r"] ps)
   k4 (waitfor s4)
   _ (test (0 = r16 1) (143 = <k4) (atom? (gather s3)))
   _ (still s3 9)
   _ (waitfor s3)

   r17 (run [] ["-Z"])
   (test (2 = r17 1) !(has? <r17 "PID USER"),
    test_fin (),

    puts "test/host/top: both faces on a pty -- the plain one's frames and repaint key; the rich one's meters, colour and -C, help and pickers, a resize, kill and renice of our own sleeps, tree, filter, search, mouse sort and select, the screen and mouse put back, the refusal\n",
    flush out))
