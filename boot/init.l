; --- boot/init.l: smoke test for the init (pid1 supervisor) nifs (host/init.c) ---
; spawn/reap/wait/still link into `ai` but NOT ai0 (which bakes the corpus), so this
; runs standalone against the built binary, like boot/pty.l -- not in test/*.l. Run
; (assert comes from test/00-init.l):
;   cat test/00-init.l boot/init.l | out/host/ai
; the FULL pid-1 story -- mounting proc, reaping a REPARENTED orphan -- needs ai to
; actually BE pid 1: `make init-container` (a pid+user+mount namespace). Here we
; cover the reap nif's three distinct returns and the spawn/wait pair.

; reap is waitpid(-1, WNOHANG), with THREE returns the supervisor tells apart:
;   (pid . status)  a child was reaped
;   ()              none pending (children alive) -- the REAL zero point, not charm 0
;   -ECHILD         no children remain -- a negative charm (nil?-true), distinct from ()
(: (reap-until n)                                   ; reap, paced, to a (pid . status) pair (or steps out)
     (: ev (reap 0) (? (two? ev) ev (< n 1) () (: _ (rest 2) (reap-until (- n 1)))))
   _ (assert
       ; spawn is NON-BLOCKING: a real live pid, the child runs on
       (: p (spawn (L "sleep" "5"))
          (&& (charm? p) (< 0 p)
              ; a child ALIVE, none exited -> reap is the REAL () (not charm 0), nil?-true
              (id? (reap 0) ()) (nil? (reap 0)) !(charm? (reap 0))
              ; kill it (bao's `still`), then reap the zombie -> (pid . 128+sig)
              (: _ (still p 9) r (reap-until 200)
                 (&& (two? r) (= (cap r) p) (= (cup r) 137)))))
       ; no children left -> -ECHILD: a NEGATIVE charm, nil?-true, but NOT the () above
       (charm? (reap 0)) (< (reap 0) 0) (nil? (reap 0)) !(id? (reap 0) ())
       ; the blocking foreground wait: spawn then wait -> the child's exit status
       (= 0 (wait (spawn (L "true"))))
       (= 3 (wait (spawn (L "sh" "-c" "exit 3"))))))

(puts "init: ok") (putc 10)
