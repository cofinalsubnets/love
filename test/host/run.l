; --- test/host/run.l: smoke test for the run / runt nifs (host/main.c host_run) ---
; (run argv) forks, captures the child's stdout into a string, and answers
; (status . output). (runt argv) is the SAME answer, but relays each chunk to our
; stdout as it is read instead of holding it to the exit -- what make does, and
; what lets a long cook step show progress. The tee must not disturb the capture.
; host-only (the nifs are host/*.c), so it runs standalone against the built
; binary like test/host/bake.l:
;   cat test/00-init.l test/host/run.l | out/host/love
;
; The payloads are deliberately TINY: runt echoes what it captures, so anything
; big would flood the gate log. The >64KB lane -- where the capture string
; outgrows its buffer and MOVES mid-drain -- is checked by hand instead:
;   (: c `("sh" "-c" "i=0; while [ $i -lt 20000 ]; do echo abcdefgh; i=$((i+1)); done")
;      (assert ((>(run c)) = (>(runt c)))))
(: cmd `("sh" "-c" "printf 'tee-me\n'")

   ; the two agree on BOTH halves of the answer: teeing changes when the bytes
   ; reach stdout, never what the caller is handed.
   a (run cmd) b (runt cmd)
   _ (assert (two? a) (two? b))
   _ (assert ((<a) = (<b)) ((<a) = 0))
   _ (assert ((>a) = (>b)) ((>a) = "tee-me\n"))

   ; a nonzero exit still rides back through the tee path
   bad (runt `("sh" "-c" "printf 'nope\n'; exit 3"))
   _ (assert (two? bad) ((<bad) = 3) ((>bad) = "nope\n"))

   ; no output -> the EmptyString singleton, tee or not
   quiet (runt `("sh" "-c" "exit 0"))
   _ (assert (two? quiet) ((<quiet) = 0) (! (>quiet)))

   (puts "run: ok\n"))
