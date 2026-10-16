; helm, the supervisor: units, checks, restarts, the control socket, underlay, scatter; not mounts
; helm is not baked, so its crew files load by path
; run: cat test/00-init.l test/host/helm.l | out/love
(borrow "src/apps/helm/unit.l")
(borrow "src/apps/helm/sup.l")
(borrow "src/apps/helm/moor.l")
(borrow "src/apps/helm/helm.l")
(borrow 'helm)

(test
 (elem 'helm (cite ()))
 (elem 'hconf (keys (cite 'helm)))
 (lit? (cite 'helm 'helm-main)))

(: (spill path text) (open path "w" @ q (say q text, flush q, close q))
   ; paths carry the pid, so two runs over one out/ keep apart
   me (show (getpid 0))
   good ("out/.helm-test-" + me + ".l")
   bad  ("out/.helm-bad-" + me + ".l")
   stamp ("out/.helm-stamp-" + me)
   _ (unlink stamp)
   _ (spill good ("(oneshot once (exec \"/bin/sh\" \"-c\" \"echo hi > " + stamp + "\"))
(service fails (after once) (exec \"/bin/sh\" \"-c\" \"exit 3\") (restart on-fail) (tries 1))
(service settles (exec \"/bin/sh\" \"-c\" \"exit 0\"))
(target default (wants fails settles))
"))
   _ (spill bad "(service a (after b) (exec \"/bin/true\") (restart sometimes))
(service b (after a) (exec \"/bin/true\"))
(service a (exec \"/bin/true\"))
(widget w (exec \"/bin/true\"))
(target t (wants nosuch))
")

   r  (hconf good)
   us <r
   _ (test
      (4 = #us)
      (['once 'fails 'settles 'default] = hnames us)
      (atom? <>r)
      (== 'oneshot (peep (hby us 'once) 'kind ()))
      (== 'no      (peep (hby us 'once) 'restart ()))
      (== 'on-fail (peep (hby us 'settles) 'restart 'x))
      (3 = peep (hby us 'settles) 'tries 0)
      (1 = peep (hby us 'fails) 'tries 0)
      (['once] = peep (hby us 'fails) 'after [])
      (["/bin/sh" "-c" "exit 3"] = peep (hby us 'fails) 'exec [])
      ; an exec prints as a command line, sh's one word quoted
      (has? (hunit-line (hby us 'fails)) "exec /bin/sh -c 'exit 3'"))

   ; every complaint at once
   b  (hconf bad)
   gs <>b
   (says? t) ((: (go l) (? (atom? l) 0 (has? <l t) 1 (go >l))) gs)
   _ (test
      (5 < #gs)
      (says? "unknown kind")
      (says? "duplicate unit a")
      (says? "after cycles")
      (says? "is not no|on-fail|always")
      (says? "wants nosuch is not a unit"))

   ; no hloop: hdrain is the signal loop's own call, hand-cranked
   _ (helm-reset us)
   _ (hput 'quiet 1)
   (settled? nm) (hstate nm @ s (s == 'done || s == 'failed))
   (settle ms) (: t0 (clock 0)
                  (go _) (hdrain 0,
                          ? (settled? 'fails && settled? 'settles) 1
                               (clock 0 - t0 > ms) 0
                               (rest 5, go 0))
                  (go 0))
   _ (hboot 'default)
   _ (test
      (two? (stat stamp))
      (== 'done (hstate 'once))
      (settle 5000)
      (== 'failed (hstate 'fails))
      (1 = peep (hstat 'fails) 'tries 0)
      (== 'done (hstate 'settles))
      (== 'done (hstate 'default)))

   ; moor, an eval server: the moor twirled, the client here, one process
   sock ("out/.helm-" + me + ".sock")
   _ (twirl (_ \ (helm-moor sock)) 0)
   _ (rest 50)
   c (connect ['unix sock])
   _ (test (lit? c))
   ; `string` joins the charlist; `+ ""` would leave a list of charms
   (rdline _) (: (go acc) (see c @ ch
                             (? (ch == -1) (string (rev acc))
                                (ch == 10) (string (rev acc))
                                (go (ch . acc))))
                 (go ()))
   _ (say c "(+ 2 3)\n")
   _ (flush c)
   _ (test ("5" = rdline 0))
   _ (say c "(status 'once)\n")
   _ (flush c)
   l (rdline 0)
   _ (test (has? l "once") (has? l "done"))
   _ (say c "(units 0)\n")
   _ (flush c)
   _ (test (has? (rdline 0) "oneshot"))
   _ (close c)
   _ (unlink sock)

   ; underlay: a link per registered verb, counted from the registry, not a roster here
   ubd ("out/.helm-underlay-" + me)
   n   (hunderlay ubd)
   ws  (keys (cite 'verbs 'tab))
   _   (test (n = 1 + tally ws))
   _   (test (readlink (ubd + "/ls") = selfpath 0))
   _   (test (elem 'ls ws) (string? (readlink (ubd + "/love"))))
   r   (hark [(ubd + "/sh") "-c" ("PATH=" + ubd + "; ls " + ubd + "/ls")])
   _   (test (0 = <r) (has? <>r "ls"))
   _   (each ws (w \ (unlink (ubd + "/" + string w))))
   _   (unlink (ubd + "/love"))
   _   (rmdir ubd)

   ; scatter: the blob inle boots on, laid as a checkout
   scd ("out/.helm-scatter-" + me)
   k   (hscatter scd)
   (test (0 < k),
    test (two? (stat (scd + "/src/apps/helm/helm.l"))),
    test (atom? (stat (scd + "/love-0.1"))),
    hark [(selfpath 0) "rm" "-rf" scd],

    unlink good, unlink bad, unlink stamp,
    test_fin (),
    0))

(puts "helm: ok\n")
