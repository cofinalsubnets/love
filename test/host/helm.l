; --- test/host/helm.l: helm, the supervisor -- the unit language, the restart
; policy over REAL processes, and the control socket ---
; spawnmap/glean/sigfd/shore live in src/posix.c and src/sock.c, which love0 does not
; link, so this runs standalone against the built binary like test/host/kiosko.l.
; helm is not baked into the image either, so the four crew files are loaded by path.
; run: cat test/00-init.l test/host/helm.l | out/host/love
;
; what is asserted:
;   LANGUAGE  a config reads to units keyed by their own clause names; the defaults
;             land (a service restarts on-fail, a oneshot not at all).
;   CHECKS    every complaint at once, and the ones that matter: an unknown kind or
;             clause, a duplicate, an `after` cycle, a dep that is not a unit.
;   POLICY    over real children: a oneshot BLOCKS its dependents and ends 'done, a
;             service that exits nonzero is restarted to its cap and then 'failed,
;             one that exits 0 is left alone.
;   MOOR      a love form in over the socket, its value back out.
(use "src/apps/helm/unit.l")
(use "src/apps/helm/sup.l")
(use "src/apps/helm/moor.l")
(use "src/apps/helm/helm.l")
(use 'helm)

(assert
 (member? 'helm (from ()))
 (member? 'hconf (keys (from 'helm)))
 (lit? (from 'helm 'helm-main)))

; --- a config on disk -------------------------------------------------------------
(: (spill path text) (: q (open path "w") _ (say q text) _ (flush q) (close q))
   ; is n a substring of h? there is no core `find`, and the gate needs one
   (has? h n) (: nh (tally h) nn (tally n)
                 (go i) (? ((nh - nn) < i) 0
                           (= n (snip h i (i + nn))) 1
                           (go (i + 1)))
                 (go 0))
   good "out/.helm-test.l"
   bad  "out/.helm-bad.l"
   stamp "out/.helm-test-stamp"
   _ (unlink stamp)
   _ (spill good "(oneshot once (exec \"/bin/sh\" \"-c\" \"echo hi > out/.helm-test-stamp\"))
(service fails (after once) (exec \"/bin/sh\" \"-c\" \"exit 3\") (restart on-fail) (tries 1))
(service settles (exec \"/bin/sh\" \"-c\" \"exit 0\"))
(target default (wants fails settles))
")
   _ (spill bad "(service a (after b) (exec \"/bin/true\") (restart sometimes))
(service b (after a) (exec \"/bin/true\"))
(service a (exec \"/bin/true\"))
(widget w (exec \"/bin/true\"))
(target t (wants nosuch))
")

   ; --- LANGUAGE ------------------------------------------------------------------
   r  (hconf good)
   us <r
   _ (assert
      (= 4 (tally us))
      (= ['once 'fails 'settles 'default] (hnames us))
      (! (two? <>r))                                  ; a clean config gripes about nothing
      (id? 'oneshot (peep (hby us 'once) 'kind ()))
      (id? 'no      (peep (hby us 'once) 'restart ()))   ; a oneshot does not restart
      (id? 'on-fail (peep (hby us 'settles) 'restart 'x)) ; ... a service does, by default
      (= 3 (peep (hby us 'settles) 'tries 0))            ; ... three times
      (= 1 (peep (hby us 'fails) 'tries 0))              ; unless the config says otherwise
      (= ['once] (peep (hby us 'fails) 'after []))
      (= ["/bin/sh" "-c" "exit 3"] (peep (hby us 'fails) 'exec [])))

   ; --- CHECKS --------------------------------------------------------------------
   ; every complaint at once, and each one names the unit it is about
   b  (hconf bad)
   gs <>b
   (says? t) ((: (go l) (? !(two? l) 0 (has? <l t) 1 (go >l))) gs)
   _ (assert
      (< 5 (tally gs))
      (says? "unknown kind")
      (says? "duplicate unit a")
      (says? "after cycles")
      (says? "is not no|on-fail|always")
      (says? "wants nosuch is not a unit"))

   ; --- POLICY, over real children ------------------------------------------------
   ; no hloop here: the gate drives the drain itself, which is the same call the
   ; signal loop makes -- so this is the real reaper, just hand-cranked.
   _ (helm-reset us)
   _ (hput 'quiet 1)
   (settled? nm) (: s (hstate nm) ((s == 'done) || (s == 'failed)))
   (settle ms) (: t0 (clock 0)
                  (go _) (: _ (hdrain 0)
                            (? ((settled? 'fails) && (settled? 'settles)) 1
                               (((clock 0) - t0) > ms) 0
                               (rest 5, go 0)))
                  (go 0))
   _ (hboot 'default)
   _ (assert
      (two? (stat stamp))                     ; the oneshot RAN, and ran to completion
      (id? 'done (hstate 'once))              ; ... before anything that came after it
      (settle 5000)
      (id? 'failed (hstate 'fails))           ; nonzero, restarted to the cap, then failed
      (= 1 (peep (hstat 'fails) 'tries 0))
      (id? 'done (hstate 'settles))           ; a 0 exit is not a failure, so no restart
      (id? 'done (hstate 'default)))          ; the target its wants reached

   ; --- MOOR ----------------------------------------------------------------------
   ; the socket is an eval server: a form in, its value out. one process, two tasks --
   ; the moor twirled, the client here -- interleaving through the scheduler.
   sock "out/.helm-test.sock"
   _ (twirl (\ _ (helm-moor sock)) 0)
   _ (rest 50)
   c (connectu sock)
   _ (assert (lit? c))
   ; the reply, one line. the accumulator is a charlist, and `string` is what
   ; makes it one string -- a `+ ""` leaves it a list of charms.
   (rdline _) (: (go acc) (: ch (see c)
                             (? (ch == -1) (string (rev acc))
                                (ch == 10) (string (rev acc))
                                (go (ch . acc))))
                 (go ()))
   _ (say c "(+ 2 3)\n")
   _ (flush c)
   _ (assert (= "5" (rdline 0)))
   _ (say c "(status 'once)\n")
   _ (flush c)
   l (rdline 0)
   _ (assert (has? l "once") (has? l "done"))
   _ (say c "(units 0)\n")
   _ (flush c)
   _ (assert (has? (rdline 0) "oneshot"))
   _ (close c)
   _ (unlink sock)
   _ (unlink good) _ (unlink bad) _ (unlink stamp)
   _ (test_fin ())
   0)

(puts "helm: ok\n")
