; src/apps/locks.l -- the machine's locks, for sessions that share one box: an exclusive lock per
; resource (an out/ two makes must not build at once), and a pool of heavy slots (test_slow,
; the kernels) granted first come first served, at most `max` at once and only while memory
; is above a floor. state is files under one root, so any session can read it and a crash
; leaves evidence; nothing here kills anything.
;
;   (locks-root 0)                              BEE_LOCKS, /run/user/UID/love-locks, ~/.love/run/locks
;   (locks-acquire root nm kind who note floor max) {"granted" 1} | {"granted" 0 "position" ..}
;   (locks-release root nm kind who)            1 | ()
;   (locks-list root)                           {"exclusive" .. "heavy" .. "waiting" .. "mem_gb" ..}
;   (locks-run root reqs note floor max argv)   each [nm kind] in turn, then argv; its status
;
; kind is 'exclusive or 'heavy, who a pid (the holder's), floor in GB (() for none), max a
; count. acquire never waits: a queued heavy ticket keeps its place, and asking again polls
; it. /run/user is a tmpfs, so a boot clears it -- a pid is only a holder among this boot's
; processes, and its start time rides beside it so a reused pid is not mistaken for one.
(module (locks locks-root locks-acquire locks-release locks-list locks-run)
(borrow 'posix)

(: (lk-str x) (? (string? x) x (show x))
   (lk-cs s) (: t (lk-str s) (map (\ i (t i)) (jot #t)))   ; a string's bytes, as a list
   ; a name as a file name: letters, digits, _ and -; the dot is kept for the tool's own temps
   (lk-slug s) (string (map (\ c (? ((47 < c && c < 58) || (64 < c && c < 91) || (96 < c && c < 123) ||
                                     c = 95 || c = 45) c 45))
                            (lk-cs s)))
   (lk-dot? n) (elem 46 (lk-cs n))
   (lk-num s) (foldl (\ a c (? (47 < c && c < 58) (a * 10 + c - 48) a)) 0 (lk-cs s))
   (lk-pad n) (: s (show n) ((string (map (\ _ 48) (jot (16 - #s)))) + s))
   (lk-mkdirs p) (foldl (\ a s (: d (a + "/" + s) _ (mkdir d 448) d)) (? (0 < #p && p 0 = 47) "" ".")
                        (filter (\ s (0 < #s)) ((cite 'kore 'usplit) 47 p)))
   (lk-read p) (: r (uread p) (? (two? r) <>r ()))
   (lk-paras ls) (foldl (\ a l (a + l + "\n")) "" ls)
   (lk-write p s) (: f (open p "w") (? (hot? f) (: _ (say f s) _ (close f) 1)))
   (lk-names d) (: ns (readdir d) (? (two? ns) (sort (filter (\ n (0 < #n && (n 0) != 46)) ns)) ()))

   ; a process's start time, field 22 of /proc/PID/stat, as the string it is there; () off linux
   (lk-start p)
    (: t (lk-read ("/proc/" + show p + "/stat"))
       (? !(string? t) ()
          (: f ((cite 'kore 'ustatf) t) (? (two? f && 21 < #f) (f 21) ()))))

   ; an owner, one `key value` a line
   (lk-owner who note)
    (lk-paras [("pid " + show who) ("start " + lk-str (lk-start who)) ("since " + show (clock 0))
            ("note " + lk-str note)])
   (lk-parse t)
    (foldl (\ o l (: k (lk-sp l 0) (? (0 < k) (pin o (snip l 0 k) (snip l (k + 1) #l)) o)))
           {} (lines (lk-str t)))
   (lk-sp l k) (? (#l <= k) -1 ((l k) = 32) k (lk-sp l (k + 1)))
   ; live: the pid answers a signal 0 (eperm is someone else's, and alive), and where a start
   ; time was kept it still matches
   (lk-live? o)
    (: p (lk-num (peep o "pid" "0")) s (peep o "start" "")
       (0 < p && 'esrch != still p 0 &&
        (? (0 < #s) (: now (lk-start p) (? (string? now) (now = s) 1)) 1)))
   (lk-view o) {"pid" (lk-num (peep o "pid" "0")) "note" (peep o "note" "") "since" (lk-num (peep o "since" "0"))}

   ; MemAvailable in GB, () where there is no /proc/meminfo
   (lk-mem _)
    (: t (lk-read "/proc/meminfo")
       ls (? (string? t) (filter (\ l (13 <= #l && snip l 0 13 = "MemAvailable:")) (lines t)) ())
       (? (two? ls) (: w (words <ls) (? (1 < #w) (lk-num (w 1) / 1048576) ())) ()))
   (lk-load _) (: t (lk-read "/proc/loadavg") (? (string? t) (: w (words t) (? (two? w) <w "")) ""))

   ; --- exclusive: a directory holding its owner, laid whole by a rename ---
   (lk-xdir root nm) (root + "/x/" + lk-slug nm)
   (lk-gone d) (: _ (unlink (d + "/owner")) (rmdir d))
   ; a stale lock is renamed aside before it goes, so two sessions reclaiming it cannot both win
   (lk-reclaim d who) (: g (d + ".gone-" + show who) (? !(rename d g) (lk-gone g) ()))
   (lk-x-take root nm who note tries)
    (: _ (lk-mkdirs (root + "/x"))
       d (lk-xdir root nm)
       tmp (d + ".new-" + show who)
       _ (mkdir tmp 448)
       _ (lk-write (tmp + "/owner") (lk-owner who note))
       r (rename tmp d)
       (? !r {"granted" 1 "lock" nm}
          (: _ (lk-gone tmp)
             o (lk-parse (lk-read (d + "/owner")))
             (? (lk-num (peep o "pid" "0") = who) {"granted" 1 "lock" nm}
                (!(lk-live? o) && 0 < tries) (: _ (lk-reclaim d who) (lk-x-take root nm who note (tries - 1)))
                {"granted" 0 "lock" nm "position" 1 "holder" (lk-view o)}))))
   (lk-x-drop root nm who)
    (: d (lk-xdir root nm) o (lk-parse (lk-read (d + "/owner")))
       (? (lk-num (peep o "pid" "0") = who) (: _ (lk-gone d) 1) ()))

   ; --- heavy: tickets, q/ waiting and h/ held, each a file holding its owner; a ticket is named
   ; by when it was asked for, so sorted names are the order of asking ---
   (lk-hq root) (root + "/heavy/q")
   (lk-hh root) (root + "/heavy/h")
   (lk-tag who nm) ("-" + show who + "-" + lk-slug nm)
   (lk-mine? n tag) (#tag <= #n && snip n (#n - #tag) #n = tag)
   ; the dead go, in either pile; the live names, sorted, answer
   (lk-sweep d)
    (filter (\ n (: o (lk-parse (lk-read (d + "/" + n)))
                    (? (lk-live? o) 1 (: _ (unlink (d + "/" + n)) ()))))
            (lk-names d))
   (lk-h-take root nm who note floor max)
    (: q (lk-hq root) h (lk-hh root)
       _ (lk-mkdirs q) _ (lk-mkdirs h)
       tag (lk-tag who nm)
       held (lk-sweep h)
       waiting (lk-sweep q)
       mine (filter (\ n (lk-mine? n tag)) held)
       (? (two? mine) {"granted" 1 "lock" nm}
          (: have (filter (\ n (lk-mine? n tag)) waiting)
             t (? (two? have) <have
                  (: t (lk-pad (clock 0) + tag)
                     _ (lk-write (q + "/." + t) (lk-owner who note))
                     _ (rename (q + "/." + t) (q + "/" + t))
                     t))
             ws (? (two? have) waiting (sort (t . waiting)))
             pos (lk-at ws t 0)
             mem (lk-mem 0)
             (? (pos = 0 && #held < max && (? (() = floor) 1 (() = mem) 1 (floor <= mem)))
                (? !(rename (q + "/" + t) (h + "/" + t)) {"granted" 1 "lock" nm}
                   {"granted" 0 "lock" nm "position" 1 "held" #held "mem_gb" mem})
                {"granted" 0 "lock" nm "position" (pos + 1) "held" #held "mem_gb" mem
                 "holders" (map (\ n (lk-view (lk-parse (lk-read (h + "/" + n))))) held)}))))
   (lk-at l x k) (? !(two? l) -1 (<l = x) k (lk-at >l x (k + 1)))
   (lk-h-drop root nm who)
    (: tag (lk-tag who nm)
       ps (foldl (\ a d (a + map (\ n (d + "/" + n)) (filter (\ n (lk-mine? n tag)) (lk-names d))))
                 () [(lk-hh root) (lk-hq root)])
       _ (map unlink ps)
       (? (two? ps) 1 ()))

   (locks-root _)
    (: e (getenv "BEE_LOCKS") ru ("/run/user/" + show (getuid 0)) home (getenv "HOME")
       (? (string? e && 0 < #e) e
          (two? (stat ru)) (ru + "/love-locks")
          (string? home) (home + "/.love/run/locks")
          "/tmp/love-locks"))

   (locks-acquire root nm kind who note floor max)
    (kind @ 'exclusive (lk-x-take root nm who note 1)
            'heavy (lk-h-take root nm who note floor max)
            {"granted" 0 "error" "kind is exclusive or heavy"})

   (locks-release root nm kind who)
    (kind @ 'exclusive (lk-x-drop root nm who) 'heavy (lk-h-drop root nm who) ())

   (locks-list root)
    (: xs (lk-names (root + "/x"))
       {"exclusive" (filter two? (map (\ n (: o (lk-parse (lk-read (root + "/x/" + n + "/owner")))
                                              (? (lk-live? o) [n (lk-view o)] ())))
                                     (filter (\ n !(lk-dot? n)) xs)))
        "heavy" (map (\ n (lk-view (lk-parse (lk-read (lk-hh root + "/" + n))))) (lk-sweep (lk-hh root)))
        "waiting" (map (\ n (lk-view (lk-parse (lk-read (lk-hq root + "/" + n))))) (lk-sweep (lk-hq root)))
        "mem_gb" (lk-mem 0) "load" (lk-load 0)})

   ; the wrapper: each [nm kind] in turn, waiting with a line on stderr whenever the answer
   ; changes, then argv spawned (every disposition default: spawn resets them) and waited for.
   ; the locks go on any way out that unwinds; a killed wrapper leaves its owner to be reclaimed
   (locks-run root reqs note floor max argv)
    (: me (getpid 0)
       (wait1 r last)
        (: a (locks-acquire root <r (r 1) me note floor max)
           s (show [(peep a "position" 0) (peep a "held" 0)])
           (? (peep a "granted" 0) 1
              (: _ (? (s != last)
                      (say err ("locks: waiting for " + lk-str <r + " (position " + show (peep a "position" 0)
                                + ", mem " + show (peep a "mem_gb" "?") + " GB)\n"))
                      0)
                 _ (rest 5000)
                 (wait1 r s))))
       _ (map (\ r (wait1 r "")) reqs)
       (mind (\ _ (: p (spawn argv) (? (charm? p && 0 <= p) (wait p) 127)))
             ()
             (\ _ (map (\ r (locks-release root <r (r 1) me)) (rev reqs))))))
) ; module locks
