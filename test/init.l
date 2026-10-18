; --- the init nifs, host only: spawn/wait, and glean, which is waitpid(-1, WNOHANG):
; (pid . status) reaped, () none pending, 'echild no children left ---
(hosted ? (do
  (: (glean-until n)                                   ; glean, paced, to a (pid . status) pair
       (glean 0 @ ev (? (two? ev) ev (n < 1) () (rest 2, glean-until (n - 1))))
     _ (test
         ; spawn is non-blocking: a real live pid, the child runs on
         (spawn ["sleep" "5"] @ p
          (charm? p && 0 < p
              ; a child alive, none exited -> glean is the real (), not charm 0
           && glean 0 = () && !(glean 0) && !(charm? (glean 0))
              ; kill it, then glean the zombie -> (pid . 128+sig)
           && (: _ (still p 9) r (glean-until 200)
                 (two? r && <r = p && >r = 137))))
         ; no children left -> 'echild: a nom, truthy, and not the () above
         ('echild = (glean 0)) (nom? (glean 0)) !!(glean 0) !((glean 0) = ())
         ; the blocking foreground wait: spawn then wait -> the child's exit status
         (0 = wait (spawn ["true"]))
         (3 = wait (spawn ["sh" "-c" "exit 3"]))
         ; the () answers are the zero point, not charm 0
         !(close -1)
         ((getenv "LOVE_NO_SUCH_ENV_VAR_XYZZY") = ())
         !(charm? (getenv "LOVE_NO_SUCH_ENV_VAR_XYZZY"))))


  ; --- the fs nifs: stat readdir unlink lseek ---
  (: d ("out/.fs-nif-probe." + show (getpid 0)) f (d + "/x")   ; per process: shards run at once
     _ (mkdir d 493)
     _ (unlink f)
     ; write 5 bytes through the port lane, then stat
     _ (open f "w" @ p (say p "hello", flush p, close p))
     st (stat f)
     (test
      ; stat: (size mtime mode) -- 5 bytes, an mtime on the (clock t) ms scale, a file mode
      (two? st) (5 = <st)
      (1600000000000 < <>st)         ; ms, not seconds
      (32768 = 61440 & <>>st)        ; s_ifmt bits say regular file
      ; a directory wears the dir bits; a missing path is its nom
      (16384 = 61440 & <>>(stat d))
      ((stat (f + "-absent")) = 'enoent) !(charm? (stat (f + "-absent")))
      (readdir d @ l (two? l && "x" = <l && atom? >l))
      ((readdir (d + "-absent")) = 'enoent)
      ; lseek rides the raw openfd lane: end is the size, set returns the offset
      (openfd f 0 @ fd
       (5 = lseek fd 0 2 && 1 = lseek fd 1 0 && 3 = lseek fd 2 1
        && !(close fd)))
      ('ebadf = (lseek -1 0 0))
      ; an unknown whence is 'einval and moves nothing
      (openfd f 0 @ fd
       (2 = lseek fd 2 0 && 'einval = lseek fd 0 7 && 'einval = lseek fd 0 -3
        && 2 = lseek fd 0 1 && !(close fd)))
      ; stat of a charm is fstat
      (: fd (openfd f 0) r (stat fd = stat f) (close fd, r))
      ((stat 4096) = 'ebadf) !(charm? (stat 4096))
      ; the kind off the fd: a file, and a directory opened read-only
      (: fd (openfd f 0) s (stat fd) (close fd, 32768 = 61440 & <>>s))
      (: fd (openfd d 0) s (stat fd) (close fd, 16384 = 61440 & <>>s))
      ; close of a stranger, or a second close, is 'ebadf
      (: fd (openfd f 0) a (close fd) b (close fd) (!a && 'ebadf = b))
      ('ebadf = (close 4096))
      ; unlink: () ok, then gone, and a re-unlink says so
      !(unlink f)
      ((stat f) = 'enoent) ((readdir d) = ())
      ('enoent = (unlink f))
      !(rmdir d)))

  ; --- the raw-fd lane: the port ops on a charm, unbuffered, answering as the port arm does ---
  (: pp (pipe 0) rfd <pp wfd >pp
     _ (say wfd "through the door") _ (put wfd 33) _ (close wfd)
     s (slurp rfd) (close rfd,
                    (test ("through the door!" = s))))

  ; see draws one byte, chug what is in hand; see tells a quiet row from an ended one
  (: pp (pipe 0) rfd <pp wfd >pp
     _ (say wfd "abcdef")
     a (see rfd)
     x (chug rfd)
     _ (close wfd)
     e (see rfd)
     y (chug rfd)
     (close rfd,
      (test (97 = a) ("bcdef" = x) (-1 = e) ("" = y))))

  ; a file reads the same bytes both ways, gulp boundaries and all
  (: d ("out/.fd-lane-probe." + show (getpid 0)) f (d + "/x")
     _ (mkdir d 493)
     _ (open f "w" @ p (say p ("abcdefgh" * 2000), close p))
     fd (openfd f 0) a (slurp fd) _ (close fd)
     p (open f "r") b (slurp p) (close p,
                                 unlink f, rmdir d,
                                 (test (a = b) (16000 = #a))))

  ; a row that is not there swallows and reads as the end, so a closed output never faults
  (test ("into the void" = say 4096 "into the void")
          (-1 = see 4096) ("" = slurp 4096)
          (4096 = flush 4096))                      ; nothing of love's is pending

  (test_fin ())
) 0)
