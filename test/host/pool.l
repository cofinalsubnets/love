; test/host/pool.l -- the thread pool (src/love/pool.c): the width a call takes, LOVE_THREADS
; read at each call, (threads N) in ~/.love/etc/love.l under it, and a fork's child drawing
; on a pool of its own
;   run:  cat test/00-init.l test/host/pool.l | out/love
(borrow 'posix)
(: (pl-w k n) (: _ (setenv "LOVE_THREADS" k) w (par-width n) _ (setenv "LOVE_THREADS" "") w)
   ; a frame big enough to share: two big squares, red and blue, one over the other
   (pl-g l) (: f (foldr (+) () l) (gem-tray [(tally f)] f))
   (pl-vx x y z r g b) [(1.0 * x) (1.0 * y) (1.0 * z) 0.0 0.0 (1.0 * r) (1.0 * g) (1.0 * b)]
   pl-id (gem-tray [16] [1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 1.0])
   pl-vs (pl-g [(pl-vx -1 -1 0 1 0 0) (pl-vx 1 -1 0 1 0 0) (pl-vx 0 1 0 1 0 0)
                (pl-vx -1 1 0.5 0 0 1) (pl-vx 1 1 0.5 0 0 1) (pl-vx 0 -1 0.5 0 0 1)])
   pl-ts (: f [0 1 2 -1 3 4 5 -1] (star-tray [(tally f)] f))
   (pl-frame k) (: _ (setenv "LOVE_THREADS" k) f (facets 512 320 7 pl-id pl-vs pl-ts () ())
                   _ (setenv "LOVE_THREADS" "") f)
   pl-one (pl-frame "1")
   pl-out ("/tmp/love-pool-law-" + show (getpid 0))
   ; a home whose love.l says (threads ..): read on the load's 50 ms tick, so each change waits
   pl-home ("/tmp/love-pool-home-" + show (getpid 0))
   pl-h0 (getenv "HOME")
   (pl-salt k n) (: _ (uwrite (pl-home + "/.love/etc/love.l") ("; the runtime's own\n(threads " + k + ")\n"))
                    _ (rest 80) w (par-width n) w)
   _ (mkdir pl-home 448) _ (mkdir (pl-home + "/.love") 448) _ (mkdir (pl-home + "/.love/etc") 448)
   _ (setenv "HOME" pl-home)
   s1 (pl-salt "1" 64)
   s3 (pl-salt "3!" 64)
   s3e (: _ (setenv "LOVE_THREADS" "2!") w (par-width 64) _ (setenv "LOVE_THREADS" "") w)
   _ (unlink (pl-home + "/.love/etc/love.l"))
   _ (rmdir (pl-home + "/.love/etc")) _ (rmdir (pl-home + "/.love")) _ (rmdir pl-home)
   _ (setenv "HOME" pl-h0)
   ; the parent draws on its pool first, so the child forks with one made and its workers left behind
   _ (pl-frame "4!")
   pid (fork 0)
   _ (pid = 0 && (: f (pl-frame "4!") (uwrite pl-out (? (aall (f = pl-one)) "same" "differs")), quit 0))
   _ (wait pid)
   said (uread pl-out @ r (two? r ? <>r ""))
   _ (unlink pl-out))
(test
 ; off, a width of one chunk, a cap, and forced
 (pl-w "1" 64 = 1)
 (pl-w "" 1 = 1)
 (pl-w "8!" 1 = 1)
 (pl-w "3!" 64 = 3)
 (pl-w "3!" 2 = 2)
 (pl-w "2" 64 <= 2)
 ; the setting in love.l, read again when it changes, and the env over it
 (s1 = 1) (s3 = 3) (s3e = 2)
 ; the frame the same at any width, and in a fork's child
 (aall (pl-frame "3!" = pl-one))
 (said = "same"))
