; --- test/host/top.l: top's two faces on a real terminal ---
; the frame builders are exercised through `top -b` in test/kore/top.sh with no tty at
; all; what is left is the faces -- raw mode, the alternate screen, the poll, the keys,
; the mouse, and the exit that puts it all back. That lane needs a terminal, so it gets
; one: `tether` spawns `kore top` on a pty, we type at the master, and the last frame
; is laid on a quay screen to be read as text.
; not in the test/*.l corpus -- tether and tty both live in src/love/posix.c, which love0
; does not link. Run it (the test macro comes from test/00-init.l):
;
;   LOVEBIN=out/love sh -c "cat test/00-init.l test/host/top.l | out/love"
;
; the only processes signalled or reniced here are sleeps this file spawned, and top
; is pointed at them with -p.

(: love (getenv "LOVEBIN")
   bf (cask 65536)
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid))))
   ; the master drained for ms: a frame nobody reads blocks its writer, and the keys
   ; typed meanwhile would land in one read, the closing q with them
   (drain m acc ms) (: n (swig m bf)
                       (? (charm? n && 0 < n) (drain m (acc + snip bf 0 n) ms)
                          (ms < 1) acc
                          (do (rest 20) (drain m acc (ms - 20)))))
   ; ..or until the screen is raised, which top does after the tty went raw: a key typed
   ; before that meets a cooked line discipline
   (raised m acc ms) (? (has? acc "\e[?1049h") (drain m acc 300)
                        (ms < 1) acc
                        (raised m (drain m acc 100) (ms - 100)))
   ; spawn `love kore top ARGS..` on a 24x100 pty and send each key whole, a reader's
   ; pace apart; a function in keys acts on the master instead. an escape then q leaves
   ; from any mode. answers [transcript status last-frame-text]
   (run keys args)
    (: r (tether (cat [love "kore" "top"] args))
       _ (test (two? r))
       m >r
       _ (settty m 24 100)
       t0 (raised m "" 5000)
       t1 (foldl (\ acc k (: _ (? (string? k) (say m k) (k m)) (drain m acc 500))) t0 keys)
       t2 (: _ (say m "\e") (drain m t1 300))
       _ (say m "q")
       txt (t2 + slurp m)
       st (waitfor <r)
       s (screen (cask (screen () 24 100)) 24 100)
       _ (scribe s t1)
       [txt <st (copied s 0 2400)])
   (cnt t s) (: (go i a) (: k (findsub (snip t i #t) s) (k < 0 ? a (go (i + k + 1) (a + 1))))
                (go 0 0))
   (at t s) (findsub t s)
   (lineof t s) (: k (at t s) (k < 0 ? -1 (cnt (snip t 0 k) "\n")))
   (click x y) ("\e[<0;" + show (x + 1) + ";" + show (y + 1) + "M\e[<0;" + show (x + 1) + ";"
                + show (y + 1) + "m")
   (sleeper _) (spawn ["sleep" "30"])
   (nice p) (: r (uread ("/proc/" + show p + "/stat")) ((cite 'kore 'ustatf) <>r 18))

   ; --- the plain face (-P): q leaves at once, and leaves the screen put back ---
   r1 (run [] ["-P"])
   t1 <r1
   _ (test
      (0 = r1 1)                            ; the status a seat quits with
      (has? t1 "\e[?1049h")                 ; the alternate screen was entered
      (has? t1 "\e[?1049l")                 ; ..and left, which is the whole contract
      (has? t1 "PID USER")                  ; the column row was drawn
      (has? t1 "%Cpu(s):")                  ; ..under the headers
      (has? t1 "Tasks:")
      (has? t1 "load average:")
      !(has? t1 "\e[?1006h"))               ; and no mouse was asked for

   ; --- a repaint key draws another frame without waiting out the three second delay
   r2 (run ["r" "r"] ["-P"])
   _ (test (0 = r2 1) (2 < cnt <r2 "PID USER"))

   ; --- the rich face, the default on a terminal: meters, the list, the key bar, and an
   ; exit that turns the mouse off, shows the cursor and leaves the alternate screen
   r3 (run [] [])
   t3 <r3
   _ (test
      (0 = r3 1)
      (has? t3 "\e[?1049h") (has? t3 "\e[?1006h") (has? t3 "\e[38;5;")
      (has? (r3 2) "Load average:") (has? (r3 2) "Tasks:") (has? (r3 2) "Mem")
      (has? (r3 2) "PID USER") (has? (r3 2) "F10Quit")
      (at t3 "\e[?1049h" < at t3 "\e[?1006l")
      (has? t3 "\e[?1000l") (has? t3 "\e[?25h") (has? t3 "\e[?1049l"))

   ; --- -C: the same face without a colour
   r4 (run [] ["-C"])
   _ (test (0 = r4 1) (has? (r4 2) "PID USER") !(has? <r4 "\e[38;5;"))

   ; --- the help, the sort picker and the user picker open over the list
   r5 (run ["h"] [])
   r6 (run ["\e[17~"] [])
   r7 (run ["u"] [])
   _ (test (has? (r5 2) "any key goes back") (has? (r6 2) "Sort by:") (has? (r7 2) "Show user:")
           (0 = r5 1) (0 = r6 1) (0 = r7 1))

   ; --- a new size is read at the next frame
   r8 (run [(\ m (settty m 30 100)) "r"] [])
   _ (test (0 = r8 1) (has? <r8 "\e[30;1H"))

   ; --- k: the signal menu over a sleep of ours, the only row; enter sends TERM
   s1 (sleeper 0)
   r9 (run ["k" "\r"] ["-p" (show s1)])
   k1 (waitfor s1)
   _ (test (0 = r9 1) (has? <r9 "Send signal:") (143 = <k1))

   ; --- ] twice: a sleep of ours two steps nicer than it started, which is the runner's nice
   s2 (sleeper 0)
   b2 (<(sound (nice s2)))
   r10 (run ["]" "]"] ["-p" (show s2)])
   n2 (<(sound (nice s2)))
   _ (still s2 9)
   _ (waitfor s2)
   _ (test (0 = r10 1) (n2 = b2 + 2))

   ; --- three rows: this harness and two sleeps it spawned
   me (getpid 0)
   s3 (sleeper 0)
   s4 (sleeper 0)
   ps ["-p" (show me) "-p" (show s3) "-p" (show s4)]
   ; t: the sleeps hang under this process
   r11 (run ["t"] ps)
   _ (test (0 = r11 1) (has? (r11 2) "├─ sleep 30") (has? (r11 2) "└─ sleep 30"))
   ; \: a filter keeps the sleeps and drops the harness, and says so over the list
   r12 (run ["\\" "sleep" "\r"] ps)
   _ (test (0 = r12 1) (has? (r12 2) " filter sleep") (has? (r12 2) (show s3 + " "))
           !(has? (r12 2) (show me + " ")))
   ; /: the search is typed on the bottom line
   r13 (run ["/" "sleep"] ps)
   _ (test (0 = r13 1) (has? (r13 2) "Search: sleep"))
   ; the mouse: a click on the PID heading sorts by it, a second turns it over
   hy (lineof (r13 2) "PID USER")
   r14 (run [(click 3 hy)] ps)
   r15 (run [(click 3 hy) (click 3 hy)] ps)
   _ (test (0 = r14 1) (0 = r15 1) (0 < hy)
           (at (r14 2) (show s3 + " ") < at (r14 2) (show s4 + " "))
           (at (r15 2) (show s4 + " ") < at (r15 2) (show s3 + " ")))
   ; ..and a click on a row selects it: N lays them by pid, the third row is s4, and
   ; k's TERM reaches s4 and nothing else
   r16 (run ["N" (click 20 (hy + 3)) "k" "\r"] ps)
   k4 (waitfor s4)
   _ (test (0 = r16 1) (143 = <k4) (atom? (gather s3)))
   _ (still s3 9)
   _ (waitfor s3)

   ; --- an unknown option is a usage refusal and not a screen ---
   r17 (run [] ["-Z"])
   _ (test (2 = r17 1) !(has? <r17 "PID USER"))
   _ (test_fin ())

   _ (puts "test/host/top: both faces on a pty -- the plain one's frames and repaint key; the rich one's meters, colour and -C, help and pickers, a resize, kill and renice of our own sleeps, tree, filter, search, mouse sort and select, the screen and mouse put back, the refusal\n")
   (flush out))
