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

(: (lk-str x) (string? x ? x (show x))
   (lk-cs s) (lk-str s @ t (map t ^#t))   ; a string's bytes, as a list
   ; a name as a file name: letters, digits, _ and -; the dot is kept for the tool's own temps
   (lk-slug s) (string (map (\ c (? (47 < c < 58 || 64 < c < 91 || 96 < c < 123 ||
                                     c = 95 || c = 45) c 45))
                            (lk-cs s)))
   (lk-dot? n) (elem 46 (lk-cs n))
   (lk-num s) (foldl (\ a c (47 < c < 58 ? (a * 10 + c - 48) a)) 0 (lk-cs s))
   (lk-pad n) (: s (show n) (string (map (_ \ 48) ^(16 - #s)) + s))
   (lk-read p) (: r (uread p) (? (two? r) <>r ()))
   (lk-paras ls) (foldl (\ a l (a + l + "\n")) "" ls)
   (lk-write p s) (: f (open p "w") (? (hot? f) (say f s, close f, 1)))
   (lk-names d) (: ns (readdir d) (? (two? ns) (sort (filter (n \ 0 < #n && n 0 != 46) ns)) ()))

   ; a process's start time, field 22 of /proc/PID/stat, as the string it is there; () off linux
   (lk-start p)
    (: t (lk-read ("/proc/" + show p + "/stat"))
       (? !(string? t) ()
          (: f (cite 'kore 'ustatf t) (two? f && 21 < #f ? (f 21)))))

   ; an owner, one `key value` a line
   (lk-owner who note)
    (lk-paras [("pid " + show who) ("start " + lk-str (lk-start who)) ("since " + show (clock 0))
            ("note " + lk-str note)])
   (lk-parse t)
    (foldl (\ o l (l @ ((k && 0 < #k) + " " + v) (pin o k v) o))
           {} (lines (lk-str t)))
   ; live: the pid answers a signal 0 (eperm is someone else's, and alive), and where a start
   ; time was kept it still matches
   (lk-live? o)
    (: p (lk-num (peep o "pid" "0")) s (peep o "start" "")
       (0 < p && 'esrch != still p 0 &&
        (0 >= #s ? 1 (: now (lk-start p) (string? now ? (now = s) 1)))))
   (lk-view o) {"pid" (lk-num (peep o "pid" "0")) "note" (peep o "note" "") "since" (lk-num (peep o "since" "0"))}

   ; MemAvailable in GB, () where there is no /proc/meminfo
   (lk-mem _)
    (: t (lk-read "/proc/meminfo")
       ls (? (string? t) (filter (l \ 13 <= #l && snip l 0 13 = "MemAvailable:") (lines t)) ())
       (? (two? ls) (: w (words <ls) (1 < #w ? (lk-num (w 1) / 1048576))) ()))
   (lk-load _) (: t (lk-read "/proc/loadavg") (? (string? t) (: w (words t) (? (two? w) <w "")) ""))

   ; --- exclusive: a directory holding its owner, laid whole by a rename ---
   (lk-xdir root nm) (root + "/x/" + lk-slug nm)
   (lk-gone d) (: _ (unlink (d + "/owner")) (rmdir d))
   ; an owner's own name, pid start and since, which no later owner shares
   (lk-token o) (lk-slug (peep o "pid" "0") + "-" + lk-slug (peep o "start" "") + "-" + lk-slug (peep o "since" ""))
   ; a stale lock is renamed aside only by the one reaper whose mkdir of d.reap-TOKEN won, and only
   ; while d still holds that owner, so a live lock laid since is never moved. a marker goes after an hour
   (lk-reclaim dir base o)
    (: d (dir + "/" + base) k (lk-token o) pre (base + ".reap-") now (clock 0)
       _ (map (\ n (: p (dir + "/" + n) s (stat p) (? (two? s && s 1 < now - 3600000) (rmdir p) 0)))
              (filter (\ n (#pre <= #n && snip n 0 #pre = pre)) (: ns (readdir dir) (? (two? ns) ns ()))))
       (? (mkdir (d + ".reap-" + k) 448) 0
          ((lk-token (lk-parse (lk-read (d + "/owner")))) != k) 0
          !(rename d (d + ".gone-" + k)) (lk-gone (d + ".gone-" + k))
          0))
   (lk-x-take dir base nm who note tries)
    (: _ (umkdirs dir 448)
       d (dir + "/" + base)
       tmp (d + ".new-" + show who)
       _ (mkdir tmp 448)
       (? !(lk-write (tmp + "/owner") (lk-owner who note))
           (: _ (lk-gone tmp) {"granted" 0 "lock" nm "error" "cannot write the owner"})
          !(rename tmp d) {"granted" 1 "lock" nm}
          (: _ (lk-gone tmp)
             t (lk-read (d + "/owner"))
             o (lk-parse t)
             (? (lk-num (peep o "pid" "0") = who) {"granted" 1 "lock" nm}
                (tries <= 0) {"granted" 0 "lock" nm "position" 1 "holder" (lk-view o)}
                ; no owner: its holder is letting go, and a rename onto the empty dir takes it
                !(string? t) (lk-x-take dir base nm who note (tries - 1))
                !(lk-live? o) (: _ (lk-reclaim dir base o) (lk-x-take dir base nm who note (tries - 1)))
                {"granted" 0 "lock" nm "position" 1 "holder" (lk-view o)}))))
   (lk-x-free d who)
    (: o (lk-parse (lk-read (d + "/owner")))
       (? (lk-num (peep o "pid" "0") = who) (: _ (lk-gone d) 1) ()))
   (lk-x-drop root nm who) (lk-x-free (lk-xdir root nm) who)

   ; --- heavy: tickets, q/ waiting and h/ held, each a file holding its owner; a ticket is named
   ; by when it was asked for, so sorted names are the order of asking ---
   (lk-hq root) (root + "/heavy/q")
   (lk-hh root) (root + "/heavy/h")
   (lk-tag who nm) ("-" + show who + "-" + lk-slug nm)
   (lk-mine? n tag) (#tag <= #n && snip n (#n - #tag) #n = tag)
   ; the dead go, in either pile; the live names, sorted, answer
   (lk-sweep d)
    (filter (\ n (: o (lk-parse (lk-read (d + "/" + n)))
                    (? (lk-live? o) 1 (unlink (d + "/" + n), ()))))
            (lk-names d))
   (lk-h-take root nm who note floor max)
    (: q (lk-hq root) h (lk-hh root)
       _ (umkdirs q 448) _ (umkdirs h 448)
       tag (lk-tag who nm)
       (mine? n) (lk-mine? n tag)
       (? (two? (filter mine? (lk-names h))) {"granted" 1 "lock" nm}
          (: have (filter mine? (lk-names q))
             t (? (two? have) <have
                  (: t (lk-pad (clock 0) + tag)
                     _ (lk-write (q + "/." + t) (lk-owner who note))
                     _ (rename (q + "/." + t) (q + "/" + t))
                     t))
             ; the count and the move are one step under the pool's mutex, held by this process
             me (getpid 0) mx (root + "/heavy")
             got (lk-hold mx me 50)
             r (lk-h-step root nm t floor max got)
             _ (? got (lk-x-free (mx + "/mutex") me) 0)
             r)))
   (lk-hold mx me n)
    (? (peep (lk-x-take mx "mutex" "mutex" me "" 1) "granted" 0) 1
       (n <= 0) 0
       (: _ (rest 20) (lk-hold mx me (n - 1))))
   ; ticket t moved to h/ when may, it is first, and there is room and memory; else its place
   (lk-h-step root nm t floor max may)
    (: q (lk-hq root) h (lk-hh root)
       held (lk-sweep h)
       waiting (lk-sweep q)
       ws (? (elem t waiting) waiting (sort (t . waiting)))
       pos (lk-at ws t 0)
       mem (lk-mem 0)
       (? (may && pos = 0 && #held < max && (? (() = floor) 1 (() = mem) 1 (floor <= mem)))
          (? !(rename (q + "/" + t) (h + "/" + t)) {"granted" 1 "lock" nm}
             {"granted" 0 "lock" nm "position" 1 "held" #held "mem_gb" mem})
          {"granted" 0 "lock" nm "position" (pos + 1) "held" #held "mem_gb" mem
           "holders" (map (\ n (lk-view (lk-parse (lk-read (h + "/" + n))))) held)}))
   (lk-at l x k) (? !(two? l) -1 (<l = x) k (lk-at >l x (k + 1)))
   (lk-h-drop root nm who)
    (: tag (lk-tag who nm)
       ps (foldl (a \ d \ a + map (n \ d + "/" + n) (filter (n \ lk-mine? n tag) (lk-names d)))
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
    (kind @ 'exclusive (lk-x-take (root + "/x") (lk-slug nm) nm who note 1)
            'heavy (lk-h-take root nm who note floor max)
            {"granted" 0 "error" "kind is exclusive or heavy"})

   (locks-release root nm kind who)
    (kind @ 'exclusive (lk-x-drop root nm who) 'heavy (lk-h-drop root nm who) ())

   (locks-list root)
    (: xs (lk-names (root + "/x"))
       {"exclusive" (filter two? (map (\ n (: o (lk-parse (lk-read (root + "/x/" + n + "/owner")))
                                              (lk-live? o ? [n (lk-view o)])))
                                     (filter (nil? * lk-dot?) xs)))
        "heavy" (map (n \ lk-view (lk-parse (lk-read (lk-hh root + "/" + n)))) (lk-sweep (lk-hh root)))
        "waiting" (map (n \ lk-view (lk-parse (lk-read (lk-hq root + "/" + n)))) (lk-sweep (lk-hq root)))
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
       (mind (\ _ (: p (spawn argv) (charm? p && 0 <= p ? (wait p) 127)))
             ()
             (\ _ (map (r \ locks-release root <r (r 1) me) (rev reqs))))))
) ; module locks
