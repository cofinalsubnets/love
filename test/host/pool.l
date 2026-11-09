; test/host/pool.l -- the thread pool (src/love/pool.c): the width a call takes, LOVE_THREADS
; read at each call, (threads N) in the nest's etc/love.l setting it at a start, and a fork's child drawing
; on a pool of its own
;   run:  cat test/00-init.l test/host/pool.l | out/love
(borrow '(posix pool))
(: (pl-w k n) (: _ (setenv "LOVE_THREADS" k) w (par-width n) _ (setenv "LOVE_THREADS" ()) w)
   ; a frame big enough to share: two big squares, red and blue, one over the other
   (pl-g l) (: f (foldr (+) () l) (gem-tray [(tally f)] f))
   (pl-vx x y z r g b) [(1.0 * x) (1.0 * y) (1.0 * z) 0.0 0.0 (1.0 * r) (1.0 * g) (1.0 * b)]
   pl-id (gem-tray [16] [1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 1.0])
   pl-vs (pl-g [(pl-vx -1 -1 0 1 0 0) (pl-vx 1 -1 0 1 0 0) (pl-vx 0 1 0 1 0 0)
                (pl-vx -1 1 0.5 0 0 1) (pl-vx 1 1 0.5 0 0 1) (pl-vx 0 -1 0.5 0 0 1)])
   pl-ts (: f [0 1 2 -1 3 4 5 -1] (star-tray [(tally f)] f))
   (pl-frame k) (: _ (setenv "LOVE_THREADS" k) f (facets 512 320 7 pl-id pl-vs pl-ts () ())
                   _ (setenv "LOVE_THREADS" ()) f)
   pl-one (pl-frame "1")
   pl-out ("/tmp/love-pool-law-" + show (getpid 0))
   ; a nest whose love.l says (threads ..): a love starting there reads it through salt as
   ; LOVE_THREADS, unless that is set. the child answers [LOVE_THREADS (par-width 64)]
   pl-home ("/tmp/love-pool-home-" + show (getpid 0))
   (pl-child txt env)
    (: _ (? (string? txt) (uwrite (pl-home + "/.love/etc/love.l") txt) (unlink (pl-home + "/.love/etc/love.l")))
       r (hark (["env" "-u" "LOVE_THREADS" ("LOVE_NEST=" + pl-home + "/.love")] + env
                + [(selfpath 0) "-e" "(borrow 'pool) (puts (show [(getenv \"LOVE_THREADS\") (par-width 64)]), quit 0)"]))
       (<r = 0 ? >r ""))
   _ (mkdir pl-home 448) _ (mkdir (pl-home + "/.love") 448) _ (mkdir (pl-home + "/.love/etc") 448)
   s1 (pl-child "; the runtime's own\n(threads 1)\n" [])
   s3 (pl-child "(threads 3!)\n" [])
   ; a form read as a form: spaces inside, a newline in it, a comment after
   sw (pl-child "( threads\n  3! ) ; three\n" [])
   s3e (pl-child "(threads 3!)\n" ["LOVE_THREADS=2!"])
   s0 (pl-child () [])
   _ (unlink (pl-home + "/.love/etc/love.l"))
   _ (rmdir (pl-home + "/.love/etc")) _ (rmdir (pl-home + "/.love")) _ (rmdir pl-home)
   ; the parent draws on its pool first, so the child forks with one made and its workers left behind
   _ (pl-frame "4!")
   pid (fork 0)
   _ (pid = 0 && (: f (pl-frame "4!") (uwrite pl-out (? (aall (f = pl-one)) "same" "differs")), quit 0))
   _ (wait pid)
   said (uread pl-out @ r (two? r ? <>r ""))
   _ (unlink pl-out))
(test
 ; the spare in whole cpus, rounded past a quarter's margin: 1.98 idle is two, 1.7 is one
 (par-cpus 1980 = 2) (par-cpus 1750 = 2) (par-cpus 1749 = 1) (par-cpus 999 = 1) (par-cpus 0 = 0) (par-cpus 3740 = 3)
 ; off, a width of one chunk, a cap, and forced
 (pl-w "1" 64 = 1)
 (pl-w "" 1 = 1)
 (pl-w "8!" 1 = 1)
 (pl-w "3!" 64 = 3)
 (pl-w "3!" 2 = 2)
 (pl-w "2" 64 <= 2)
 ; the setting in love.l reaching LOVE_THREADS at a start, and the env over it
 (s1 = "(\"1\" 1)") (s3 = "(\"3!\" 3)") (sw = "(\"3!\" 3)") (s3e = "(\"2!\" 2)") (starts? s0 "(() ")
 ; the frame the same at any width, and in a fork's child
 (aall (pl-frame "3!" = pl-one))
 (said = "same"))

(test_fin (), puts "pool: ok -- widths, the margin, love.l, the frame alike at any width and in a fork\n", 0)
