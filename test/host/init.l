; --- test/host/init.l: smoke test for the init (pid1 supervisor) nifs (src/posix.c) ---
; spawn/glean/wait/still link into `love` but not love0 (which bakes the corpus), so this
; runs standalone against the built binary, like test/host/pty.l -- not in test/*.l. Run
; (assert comes from test/00-init.l):
;   cat test/00-init.l test/host/init.l | out/host/love
; the full pid-1 story -- mounting proc, reaping a reparented orphan -- needs love to
; actually be pid 1: `make init-container` (a pid+user+mount namespace). Here we
; cover the glean nif's three distinct returns and the spawn/wait pair.

; glean is waitpid(-1, WNOHANG), with three returns the supervisor tells apart:
;   (pid . status)  a child was reaped
;   ()              none pending (children alive) -- the real zero point, not charm 0
;   -echild         no children remain -- a negative charm (nil?-true), distinct from ()
(: (glean-until n)                                   ; glean, paced, to a (pid . status) pair (or steps out)
     (: ev (glean 0) (? (two? ev) ev (< n 1) () (: _ (rest 2) (glean-until (- n 1)))))
   _ (assert
       ; spawn is non-blocking: a real live pid, the child runs on
       (: p (spawn ["sleep" "5"])
          (&& (charm? p) (< 0 p)
              ; a child alive, none exited -> glean is the real () (not charm 0), nil?-true
              (id? (glean 0) ()) (nil? (glean 0)) !(charm? (glean 0))
              ; kill it (bao's `still`), then glean the zombie -> (pid . 128+sig)
              (: _ (still p 9) r (glean-until 200)
                 (&& (two? r) (= (cap r) p) (= (cup r) 137)))))
       ; no children left -> -echild: a negative charm, nil?-true, but not the () above
       (charm? (glean 0)) (< (glean 0) 0) (nil? (glean 0)) !(id? (glean 0) ())
       ; the blocking foreground wait: spawn then wait -> the child's exit status
       (= 0 (wait (spawn ["true"])))
       (= 3 (wait (spawn ["sh" "-c" "exit 3"])))
       ; the "()"-returns are the real zero point now (the ai_nil -> () flip), not charm 0:
       ; (id? x ()) holds and (charm? x) is false -- charm 0 would fail both.
       (= 0 (close -1))                                    ; closing nothing still answers ok
       (id? (getenv "LOVE_NO_SUCH_ENV_VAR_XYZZY") ())             ; getenv absent -> the real ()
       !(charm? (getenv "LOVE_NO_SUCH_ENV_VAR_XYZZY"))))


; --- the fs nifs: stat readdir unlink lseek (the posix_ lane in src/posix.c) -----
(: d "out/.fs-nif-probe" f (+ d "/x")
   _ (mkdir d 493)                                  ; EEXIST from a prior run is fine
   _ (unlink f)                                     ; a clean slate, tolerated if absent
   ; write 5 bytes through the port lane, then measure with stat
   _ (: p (open f "w") _ (say p "hello") _ (flush p) (close p))
   st (stat f)
   (assert
    ; stat: (size mtime mode) -- 5 bytes, an mtime on the (clock t) ms scale, a file mode
    (two? st) (= 5 (cap st))
    (< 1600000000000 (caup st))                     ; ms, not seconds (a 2020s stamp)
    (= 32768 (& 61440 (cauup st)))                  ; s_ifmt bits say regular file
    ; a directory wears the dir bits; a missing path is nothing, the real ()
    (= 16384 (& 61440 (cauup (stat d))))
    (id? (stat (+ f "-absent")) ()) !(charm? (stat (+ f "-absent")))
    ; readdir: our one entry, as a string; a missing dir is ()
    (: l (readdir d) (&& (two? l) (= "x" (cap l)) !(two? (cup l))))
    (id? (readdir (+ d "-absent")) ())
    ; lseek rides the raw openfd lane: end is the size, set returns the offset
    (: fd (openfd f 0)
       (&& (= 5 (lseek fd 0 2)) (= 1 (lseek fd 1 0)) (= 3 (lseek fd 2 1))
           (= 0 (close fd))))
    (< (lseek -1 0 0) 0)                            ; a bad fd is a negative charm
    ; a whence no seat knows is the row's EINVAL and moves nothing -- read as SET
    ; it would have seeked to 0 and called that success
    (: fd (openfd f 0)
       (&& (= 2 (lseek fd 2 0)) (= -22 (lseek fd 0 7)) (= -22 (lseek fd 0 -3))
           (= 2 (lseek fd 0 1)) (= 0 (close fd))))
    ; stat takes a charm as an fd, which is fstat under another name: the same
    ; tuple the path answers, and nothing for a row that is not there
    (: fd (openfd f 0) r (= (stat fd) (stat f)) _ (close fd) r)
    (id? (stat 4096) ()) !(charm? (stat 4096))
    ; and stat reads a row's kind off the fd: a file, and a directory, which
    ; opens read-only by POSIX's own rule
    (: fd (openfd f 0) s (stat fd) _ (close fd) (= 32768 (& 61440 (cauup s))))
    (: fd (openfd d 0) s (stat fd) _ (close fd) (= 16384 (& 61440 (cauup s))))
    ; close wears the errno convention: a stranger row is EBADF, and so is the
    ; second close of a real one -- the row is gone, which is what it says
    (: fd (openfd f 0) a (close fd) b (close fd) (&& (= 0 a) (= -9 b)))
    (= -9 (close 4096))
    ; unlink: () ok, then the file really is gone, and a re-unlink says so (-ENOENT)
    (= 0 (unlink f))
    (id? (stat f) ()) (id? (readdir d) ())
    (: e (unlink f) (&& (charm? e) (e < 0)))))

; --- the raw-fd lane: the port ops with a charm where the port goes ------------
; an fd carries no buffer of love's and no seat, so each op is one motion on the
; row -- and the answers are the port arm's, so the two spellings compose.
(: pp (pipe 0) rfd (cap pp) wfd (cup pp)
   _ (say wfd "through the door") _ (put wfd 33) _ (close wfd)
   s (slurp rfd) _ (close rfd)
   (assert (= "through the door!" s)))

; see draws one byte, chug takes what the row still has in hand, and both answer
; the empty end -- see is the door that tells a quiet row from an ended one, so it
; is what a drain leans on
(: pp (pipe 0) rfd (cap pp) wfd (cup pp)
   _ (say wfd "abcdef")
   a (see rfd)
   x (chug rfd)
   _ (close wfd)
   e (see rfd)
   y (chug rfd)
   _ (close rfd)
   (assert (= 97 a) (= "bcdef" x) (= -1 e) (= "" y)))

; a file reads the same bytes both ways, gulp boundaries and all
(: d "out/.fd-lane-probe" f (+ d "/x")
   _ (mkdir d 493)
   _ (: p (open f "w") _ (say p (* "abcdefgh" 2000)) (close p))
   fd (openfd f 0) a (slurp fd) _ (close fd)
   p (open f "r") b (slurp p) _ (close p)
   _ (unlink f)
   (assert (= a b) (= 16000 (tally a))))

; a row that is not there swallows and reads as the end: a closed seat's output
; must not fault a task that cannot know it is closed
(assert (= "into the void" (say 4096 "into the void"))
        (= -1 (see 4096)) (= "" (slurp 4096))
        (= 4096 (flush 4096)))                      ; nothing of love's is pending

(test_fin ())
(puts "init: ok") (putc 10)
