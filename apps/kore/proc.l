; apps/kore/proc.l -- the process and world tools of kore: env, nohup, nice, renice,
; printenv, sleep, kill, xargs, date, id, whoami, groups, stty, microcom, who, users, logname.
; a toolbox file, no seat -- kore is its door; loads after core.l and rides the
; u-floor. no nifs of its own: environ/getenv/setenv (love/main.c + init.c),
; spawn/wait (init.c's posix lane -- spawn answers the pid or a NEGATIVE errno,
; a child that cannot exec _exit(127)s), still (posix.c's kill), prio/setprio and
; termios/settermios (posix.c), rest (the core sleep, milliseconds). a body-less top-level `:` leaking one pure helper
; (udur -- lawed in test/law/kore.l) and the mains.
(module 'kore
(borrow 'cli)
(borrow 'bytes)
(borrow 'cal)
(borrow 'path)
(borrow 'posix)

(:
   ; -- env: assignments, then print the world or run a command inside it --
   (env-main as)
    (: (eqat s) (: n #s                    ; the first = past position 0, or ()
                   (go k) (? (n <= k) ()
                             (s k = 61) (? (0 < k) k ())
                             (go (k + 1)))
                   (go 1))
       (setp a) (? (atom? a) a
                   (: i (eqat <a)
                      (? i (: s <a
                              _ (setenv (snip s 0 i) (snip s (i + 1) #s))
                              (setp >a))
                         a)))
       ; the options come first: -i empties the environment, -u NAME drops one --
       ; a non-string value unsets (love/main.c's setenv shape); then the assignments
       (unset-all e) (? (atom? e) 0 (: k <e i (eqat k) _ (setenv (? i (snip k 0 i) k) ()) (unset-all >e)))
       (opts a) (? (atom? a) a
                  (<a = "-i") (unset-all (environ 0), opts >a)
                  (<a = "-u") (? (two? >a) (setenv <>a (), opts >>a) (udie 1 "env: -u needs a name"))
                  (<a = "--") >a
                  a)
       rest (setp (opts as))
       (? (two? rest)
          (: p (spawn rest)
             (? (nom? p) (udie 127 ("env: cannot run " + <rest))
                (: w (wait p) _ (flush out) w)))
          (: (pr e) (? (atom? e) (flush out, 0)
                       (say out <e, put out 10, pr >e))
             (pr (environ 0)))))

   ; -- sleep: the durations, summed --
   (sleep-main as)
    (? (atom? as) (udie 1 "sleep: missing operand")
       (: (tot a acc) (? (atom? a) acc
                         (: m (udur <a)
                            (? (charm? m) (tot >a (acc + m))
                               (udie 1 ("sleep: invalid time interval '" + <a + "'")))))
          t (tot as 0)
          _ (rest t)
          0))

   ; -TERM / -15 / -9 -> the number, or () for anything else. shared with kill, which
   ; is the tool that taught the table; pkill and killall wear the same spelling.
   ; the one signal table: kill, pkill, killall and timeout spell by it, and lush's
   ; trap and kill builtins read it too. the numbers are Linux's; USR1 USR2 CHLD TSTP
   ; want an ISA/OS table on a BSD
   usignames '(("HUP" 1) ("INT" 2) ("QUIT" 3) ("ABRT" 6) ("KILL" 9) ("USR1" 10) ("SEGV" 11)
               ("USR2" 12) ("PIPE" 13) ("ALRM" 14) ("TERM" 15) ("CHLD" 17) ("CONT" 18)
               ("STOP" 19) ("TSTP" 20) ("TTIN" 21) ("TTOU" 22))
   (usigdig? b k) (? (#b <= k) (0 < #b)
                     (48 <= (b k) && (b k) <= 57) (usigdig? b (k + 1))
                     0)
   (usignum w)
    (: n #w
       (snl l b) (? (atom? l) () (<<l = b) <><l (snl >l b))
       (? (n < 2 || !((w 0) = 45)) ()
          (: b (snip w 1 n)
             (? (usigdig? b 0) (uatoi b) (snl usignames b)))))

   ; -- kill: a signal (default TERM) onto every named pid --
   (kill-main as)
    (: (alldig? s) (usigdig? s 0)
       sig (? (two? as) (usignum <as) ())
       pids (? (charm? sig) >as as)
       sg (? (charm? sig) sig 15)
       _ (? (two? pids) () (udie 1 "usage: kill [-SIG] PID.."))
       (one p ok)
        (? !(alldig? p)
           (say err ("kill: invalid pid " + p), put err 10, 0)
           (: r (still (uatoi p) sg)
              (? !r ok
                 (say err ("kill: cannot kill " + p), put err 10, 0))))
       (go a ok) (? (two? a) (go >a (one <a ok))
                    (flush err, (? ok 0 1)))
       (go pids 1))

   ; -- the time zone: TZ, else /etc/localtime. a zone is a function from utc seconds to
   ; [offset-east-seconds abbreviation]. a TZif file is read for its transitions and its
   ; footer rule past the last one; a TZ that names no file is read as a posix rule
   ; (EST5EDT,M3.2.0,M11.1.0); an empty TZ, or nothing readable, is utc
   ; the day a second falls in, floored: before the epoch // would round toward it
   (tzday0 s) (: q (s // 86400) (? (s < q * 86400) (q - 1) q))
   (tzs s k n) (: (go i a) (? (n <= i) a (go (i + 1) (a * 256 + s (k + i)))) (go 0 (s k >= 128 ? -1 0)))
   (tzu s k n) (: (go i a) (? (n <= i) a (go (i + 1) (a * 256 + s (k + i)))) (go 0 0))
   (tzp-to s i c) (? (#s <= i || s i = c) i (tzp-to s (i + 1) c))
   (tzp-alpha s i) (? (i < #s && (65 <= s i <= 90 || 97 <= s i <= 122)) (tzp-alpha s (i + 1)) i)
   (tzp-name s i)
    (? (i < #s && s i = 60) (: e (tzp-to s (i + 1) 62) [(snip s (i + 1) e) (e + 1)])
       (: e (tzp-alpha s i) [(snip s i e) e]))
   (tzp-num s i) (: (go j a) (? (j < #s && 48 <= s j <= 57) (go (j + 1) (a * 10 + s j - 48)) [a j]) (go i 0))
   ; [+-]h[:m[:s]] -> [seconds next]
   (tzp-hms s i)
    (: sg (? (i < #s && s i = 45) -1 1)
       j (? (i < #s && (s i = 45 || s i = 43)) (i + 1) i)
       h (tzp-num s j)
       m (? (h 1 < #s && s (h 1) = 58) (tzp-num s (h 1 + 1)) [0 (h 1)])
       z (? (m 1 < #s && s (m 1) = 58) (tzp-num s (m 1 + 1)) [0 (m 1)])
       [(sg * (<h * 3600 + <m * 60 + <z)) (z 1)])
   ; Mm.w.d, Jn or n, then /time (2:00 unsaid) -> [[kind a w d] seconds next]
   (tzp-date s i)
    (: k (? (i < #s && s i = 77) 'm (i < #s && s i = 74) 'j 'n)
       a (tzp-num s (k = 'n ? i (i + 1)))
       e (? (k = 'm) (: w (tzp-num s (a 1 + 1)) d (tzp-num s (w 1 + 1)) [[k <a <w <d] (d 1)])
            [[k <a 0 0] (a 1)])
       t (? (e 1 < #s && s (e 1) = 47) (tzp-hms s (e 1 + 1)) [7200 (e 1)])
       [<e <t (t 1)])
   ; a posix TZ rule -> {'std 'so 'dst 'do 'r}, offsets east of utc; () when unreadable
   (tzrule s)
    (: a (tzp-name s 0)
       (? (#<a < 1 || #s <= a 1) ()
          (: o (tzp-hms s (a 1)) so (0 - <o) k (o 1)
             (? (#s <= k) {'std <a 'so so 'dst ()}
                (: b (tzp-name s k)
                   p (? (b 1 < #s && s (b 1) != 44) (: q (tzp-hms s (b 1)) [(0 - <q) (q 1)]) [(so + 3600) (b 1)])
                   rs (? (p 1 < #s && s (p 1) = 44) (snip s (p 1 + 1) #s) "M3.2.0,M11.1.0")
                   x (tzp-date rs 0) y (tzp-date rs (x 2 + 1))
                   {'std <a 'so so 'dst <b 'do <p 'r [x y]})))))
   ; a rule date in year Y -> days since the epoch
   (tzday r Y)
    (: k <r n (r 1) w (r 2) d (r 3) j1 (epoch-days Y 1 1)
       (? (k = 'j) (j1 + n - 1 + (59 < n && mdays Y 2 = 29 ? 1 0))
          (k = 'n) (j1 + n)
          (: f (epoch-days Y n 1) d1 (f + (d - wday f + 7) % 7) dd (d1 + 7 * (w - 1))
             (dd < f + mdays Y n ? dd (dd - 7)))))
   (tzrule-at z t)
    (? !(z 'dst) [(z 'so) (z 'std)]
       (: Y <(civil (tzday0 (t + z 'so)))
          x <(z 'r) y (z 'r 1)
          t1 (tzday <x Y * 86400 + x 1 - z 'so)
          t2 (tzday <y Y * 86400 + y 1 - z 'do)
          in (? (t1 < t2) (t1 <= t && t < t2) !(t2 <= t && t < t1))
          (in ? [(z 'do) (z 'dst)] [(z 'so) (z 'std)])))
   ; TZif, the 64-bit block when there is one -> {'ts 'ix 'ty 'rp} or ()
   (tzif s)
    (? !(44 <= #s && snip s 0 4 = "TZif") ()
       (: (cnts b) (map (\ i (tzu s (b + 20 + 4 * i) 4)) ^6)     ; isut isstd leap time type char
          c1 (cnts 0)
          v1 (c1 3 * 5 + c1 4 * 6 + c1 5 + c1 2 * 8 + c1 1 + c1 0)
          two (50 <= s 4 && 44 + v1 + 44 <= #s)
          b (two ? (44 + v1) 0)
          c (two ? (cnts b) c1)
          w (two ? 8 4)
          tc (c 3) yc (c 4) cc (c 5)
          p0 (b + 44) p1 (p0 + w * tc) p2 (p1 + tc) p3 (p2 + 6 * yc)
          (nul j) (? (p3 + cc <= j || s j = 0) j (nul (j + 1)))
          ty (map (\ i (: q (p2 + 6 * i) [(tzs s q 4) (snip s (p3 + s (q + 5)) (nul (p3 + s (q + 5))))])) ^yc)
          pe (p3 + cc + c 2 * (w + 4) + c 1 + c 0)
          (eol j) (? (#s <= j || s j = 10) j (eol (j + 1)))
          ft (? (two && pe < #s && s pe = 10) (snip s (pe + 1) (eol (pe + 1))) "")
          {'ts (map (\ i (tzs s (p0 + w * i) w)) ^tc)
           'ix (map (\ i (s (p1 + i))) ^tc)
           'ty ty
           'rp (0 < #ft ? (tzrule ft) ())}))
   (tzif-at z t)
    (: ts (z 'ts) tc #ts ty (z 'ty)
       (go l i k) (? (atom? l) k (<l <= t) (go >l (i + 1) i) k)
       k (go ts 0 -1)
       (? (k = tc - 1 && tablet? (z 'rp)) (tzrule-at (z 'rp) t)
          (k < 0) (? (two? ty) <ty [0 "UTC"])
          (ty (z 'ix k))))
   tz-utc (\ t [0 "UTC"])
   (tz-zone _)
    (: e (getenv "TZ")
       (? (string? e && #e = 0) tz-utc
          (: nm (? (string? e && e 0 = 58) (snip e 1 #e) (string? e) e "")
             p (? (#nm = 0) "/etc/localtime" (nm 0 = 47) nm ("/usr/share/zoneinfo/" + nm))
             r (uread p)
             z (? (two? r) (tzif <>r) ())
             ru (? (tablet? z) () (0 < #nm) (tzrule nm) ())
             (? (tablet? z) (\ t (tzif-at z t))
                (tablet? ru) (\ t (tzrule-at ru t))
                tz-utc))))

   ; -- date: the wall clock, in the zone above; -u for utc. -d @seconds and -r file name
   ; a moment other than now, which is also what makes this tool gateable against GNU.
   ; +format, or GNU's C-locale default when none is given.
   (udatef fmt ms) (udatez fmt ms [0 "UTC"])
   ; zn is [offset abbreviation]: the fields are local, %s stays the epoch's
   (udatez fmt ms zn)
    (: s0 (ms // 1000) off <zn
       s (s0 + off)
       days (tzday0 s) secs (s - days * 86400)
       ymd (civil days)
       Y <ymd M <>ymd D <>>ymd
       hh (secs // 3600) mm ((secs % 3600) // 60) ss (secs % 60)
       wd (wday days)
       yday ((days - (epoch-days Y 1 1)) + 1)
       (p2 v) (zpad 2 (show v))
       n #fmt o (jug 0)
       (go k)
        (? (n <= k) (slurp o)
           (: c (fmt k)
              (? !(c = 37 && (k + 1) < n) (put o c, go (k + 1))
                 (: d (fmt (k + 1))
                    _ (? (d = 37) (put o 37)
                         (d = 89) (say o (show Y))
                         (d = 109) (say o (p2 M))
                         (d = 100) (say o (p2 D))
                         (d = 101) (say o (upad 2 (show D)))
                         (d = 72) (say o (p2 hh))
                         (d = 77) (say o (p2 mm))
                         (d = 83) (say o (p2 ss))
                         (d = 106) (say o (zpad 3 (show yday)))
                         (d = 121) (say o (p2 (Y % 100)))
                         (d = 67) (say o (p2 (Y // 100)))
                         (d = 70) (say o ((zpad 4 (show Y)) + "-" + (p2 M) + "-" + (p2 D)))
                         (d = 84) (say o ((p2 hh) + ":" + (p2 mm) + ":" + (p2 ss)))
                         (d = 68) (say o ((p2 M) + "/" + (p2 D) + "/" + (p2 (Y % 100))))
                         (d = 115) (say o (show s0))
                         (d = 97) (say o (wd3 wd))
                         (d = 65) (say o (wdl wd))
                         (d = 98 || d = 104) (say o (mon3 (M - 1)))
                         (d = 66) (say o (monl (M - 1)))
                         (d = 112) (say o (? (hh < 12) "AM" "PM"))
                         (d = 73) (say o (p2 (: h (hh % 12) (? h h 12))))
                         (d = 117) (say o (show (? wd wd 7)))
                         (d = 119) (say o (show wd))
                         (d = 90) (say o (zn 1))
                         (d = 122) (: a (abs off)
                                      (say o ((off < 0 ? "-" "+") + p2 (a // 3600) + p2 (a % 3600 // 60))))
                         (d = 110) (put o 10)
                         (d = 116) (put o 9)
                         (put o 37, put o d))
                    (go (k + 2))))))
       (go 0))
   (udt-when w)                        ; -d's @seconds, the one spelling this date parses
    (? ((0 < tally w) && (w 0 = 64)) (1000 * (uatoi (snip w 1 #w)))
       (udie 1 ("date: cannot read the date '" + w + "' (only @SECONDS here)")))
   (date-main as)
    (: u {'u 0}
       (fl a when fmt)
        (? (atom? a) [when fmt]
           (<a = "-u" || <a = "--utc") (pin u 'u 1, fl >a when fmt)
           (<a = "-d") (? (two? >a) (fl >>a (udt-when <>a) fmt)
                          (udie 1 "date: -d wants a time"))
           (<a = "-r") (? (two? >a)
                          (: st (stat <>a)
                             (? (two? st) (fl >>a <>st fmt)
                                (udie 1 ("date: cannot stat '" + <>a + "'"))))
                          (udie 1 "date: -r wants a file"))
           ((0 < tally <a) && (<a 0 = 43)) (fl >a when (snip <a 1 #<a))
           (udie 1 ("date: cannot set the clock (" + <a + ")")))
       p (fl as () ())
       ms (? (charm? <p) <p (clock 0))
       fmt (? (string? <>p) <>p "%a %b %e %H:%M:%S %Z %Y")
       zone (u 'u ? tz-utc (tz-zone 0))
       _ (say out (udatez fmt ms (zone (ms // 1000)))) _ (put out 10) _ (flush out) 0)

   ; -- cal: a month, laid out on 'cal's rows. `cal` alone is this month, `cal M Y` a
   ; named one, `cal Y` the twelve. weeks open on Sunday, as cal's do.
   ucal-hdr "Su Mo Tu We Th Fr Sa"                  ; 20 wide, and so is every row under it
   (ucal-mid w s) (: n #s (urpad w (upad ((((w - n) + 1) // 2) + n) s)))
   ; SIX rows always, blank ones included, each the full 20 -- cal pads rather than
   ; trims, which is the whole reason a month is a fixed block that tiles across
   (ucal-weeks y m)
    (: lead (wday (epoch-days y m 1)) len (mdays y m)
       (cell d) (? (d < 1 || len < d) "  " (upad 2 (show d)))
       (row r) (: o (jug 0)
                  (go c) (? (7 <= c) (slurp o)
                            ((? c (put o 32) 0), say o (cell (((7 * r) + c) - (lead - 1))), go (c + 1)))
                  (go 0))
       (go r acc) (? (6 <= r) (rev acc) (go (r + 1) ((row r) . acc)))
       (go 0 ()))
   (ucal-say l) (say out l, put out 10)
   (ucal-tri a b c) (a + "   " + b + "   " + c)     ; three columns -> the 66-wide line
   (cal-main as)
    (: ymd (civil (((clock 0) // 1000) // 86400))
       (bad _) (udie 2 "usage: cal [[MONTH] YEAR]")
       ms (? (atom? as) [<>ymd <ymd]
             (atom? >as) (: y (uatoi <as) _ (? (0 < y) 0 (bad 0)) ['all y])
             (: m (uatoi <as) y (uatoi <>as)
                _ (? ((1 <= m <= 12) && 0 < y) 0 (bad 0))
                [m y]))
       m <ms y <>ms
       ; a quarter: three titles, three headers, then the six week rows abreast
       (quarter k)
        (: ms3 [k (k + 1) (k + 2)]
           (col f) (map f ms3)
           ts (col (j \ (ucal-mid 20 (monl (j - 1)))))
           ws (col (j \ (ucal-weeks y j)))
           w1 <ws w2 <>ws w3 <>>ws
           _ (ucal-say (ucal-tri <ts <>ts <>>ts))
           _ (ucal-say (ucal-tri ucal-hdr ucal-hdr ucal-hdr))
           (go r) (? (6 <= r) 1
                     (ucal-say (ucal-tri (w1 r) (w2 r) (w3 r)), go (r + 1)))
           (go 0))
       _ (? (m = 'all)
            (ucal-say (ucal-mid 66 (show y)), put out 10,
             (: (go k) (? (12 < k) 1 (quarter k, go (k + 3))) (go 1)))
            (ucal-say (ucal-mid 20 ((monl (m - 1)) + " " + (show y))), ucal-say ucal-hdr, map ucal-say (ucal-weeks y m), 1))
       _ (flush out) 0)

   ; -- id: who this process is. -u/-g/-G the ids, -n their names, and the bare face
   ; GNU's uid=/gid=/groups= line. the supplementary groups are read out of
   ; /etc/group -- there is no getgroups here and no nss anywhere, so a box whose groups
   ; live in a directory service will be told less than the truth. -r is taken and
   ; changes nothing: this love holds only the real ids, which is what -r asks for.
   (id-main as)
    (: (fl a t)
        (? (atom? a) t
           ((#<a < 2) || !(<a 0 = 45)) (udie 1 ("id: unknown argument " + <a))
           (: w <a
              (cl k) (? (#w <= k) (fl >a t)
                        (: c (w k)
                           (? (elem c '(117 103 71 110 114))
                              (pin t c 1, cl (k + 1))
                              (udie 1 ("id: unknown option -" + string c)))))
              (cl 1)))
       t (fl as (tablet 0))
       uid (getuid 0) gid (getgid 0)
       nm (uidname "/etc/passwd" uid)
       gs (ugroups nm gid)
       n? (peep t 110 0)
       (one g) ((show g) + "(" + (uidname "/etc/group" g) + ")")
       _ (? (peep t 117 0) (say out (? n? nm (show uid)))
            (peep t 103 0) (say out (? n? (uidname "/etc/group" gid) (show gid)))
            (peep t 71 0) (say out (ujoin (map (g \ (? n? (uidname "/etc/group" g) (show g))) gs)))
            (say out ((("uid=" + (show uid) + "(" + nm + ")") + (" gid=" + (one gid)))
                      + (" groups=" + (ujoinc 44 (map one gs))))))
       _ (put out 10) _ (flush out) 0)

   ; -- nohup: SIGHUP ignored, then exec the command. a terminal on 0 is swapped for
   ; /dev/null, one on 1 for nohup.out (0600, $HOME's when the cwd refuses), one on 2
   ; for stdout; the sentence says which, before err moves. 125 nohup's own trouble,
   ; 126 the command would not run, 127 no such command, else the command's own --
   (nohup-main as)
    (: cmd (? (two? as && <as = "--") >as as)
       _ (? (two? cmd) () (udie 125 "nohup: missing operand"))
       tin (two? (tty 0)) tout (two? (tty 1)) terr (two? (tty 2))
       _ (signal 1 1)
       (open1 p) (: new (atom? (stat p)) fd (openfd p 2)
                    (? (nom? fd) () ((? new (chmod p 384) 0), [fd p])))
       ofd (? tout (: a (open1 "nohup.out") h (getenv "HOME")
                      (? (two? a) a (string? h) (open1 (h + "/nohup.out")) ()))
              ())
       _ (? (tout && atom? ofd) (udie 125 "nohup: failed to open nohup.out") ())
       what (? tout ("appending output to '" + <>ofd + "'")
               terr "redirecting stderr to stdout"
               "")
       msg (? (tin && #what) ("ignoring input and " + what) tin "ignoring input" what)
       _ (? #msg (say err ("nohup: " + msg), put err 10, flush err) 0)
       _ (? tin (: fd (openfd "/dev/null" 0) (? (nom? fd) 0 (dup2 fd 0, close fd))) 0)
       _ (? tout (dup2 <ofd 1, close <ofd) 0)
       _ (? terr (dup2 1 2) 0)
       _ (flush out)
       e (exec cmd)
       (udie (? (e = 'enoent) 127 126) ("nohup: failed to run command '" + <cmd + "'")))

   ; -- nice: run a command at another niceness, 10 lower by default; bare, say this
   ; one's. -N and --N are the old spellings of -n N. a refusal to raise the priority is
   ; said and the command runs anyway; 125 nice's own trouble, 126/127 as nohup's --
   (nice-main as)
    (: (num? w k) (: n #w (k < n && 48 <= w k && w k <= 57))
       (go a adj)
        (? (atom? a) [adj ()]
           (: w <a n #w
              (? (w = "--") [adj >a]
                 (1 < n && w 0 = 45 && num? w (? (w 1 = 45 || w 1 = 43) 2 1)) (go >a (snip w 1 n))
                 (w = "-n" || w = "--adjustment")
                  (? (two? >a) (go >>a <>a) (udie 125 "nice: option requires an argument -- 'n'"))
                 (2 < n && snip w 0 2 = "-n") (go >a (snip w 2 n))
                 (13 < n && snip w 0 13 = "--adjustment=") (go >a (snip w 13 n))
                 (1 < n && w 0 = 45) (udie 125 ("nice: invalid option -- '" + string (w 1) + "'\nTry 'nice --help' for more information."))
                 [adj a])))
       r (go as ())
       adj <r cmd <>r
       cur (prio 0 0)
       (? (atom? cmd)
          (? (string? adj) (udie 125 "nice: a command must be given with an adjustment\nTry 'nice --help' for more information.")
             (say out (show cur + "\n"), flush out, 0))
          (: a0 (? (string? adj) (: t (? (0 < #adj && adj 0 = 43) (snip adj 1 #adj) adj)
                                   v (? (0 < #t && t 0 = 45) (: u (unum (snip t 1 #t)) (? (charm? u) (0 - u) ()))
                                        (unum t))
                                   (? (charm? v) v (udie 125 ("nice: invalid adjustment '" + adj + "'"))))
                   10)
             e (setprio 0 0 (cur + (max -39 (min 39 a0))))
             _ (? (nom? e) (say err ("nice: cannot set niceness: " + uerrno e + "\n"), flush err) 0)
             x (exec cmd)
             (udie (? (x = 'enoent) 127 126) ("nice: '" + <cmd + "': " + uerrno x)))))

   ; -- renice: util-linux's. the priority is absolute, or with --relative added to
   ; each one's own; -p -g -u say what the ids that follow are (a user by name or
   ; number). each change is reported, each failure warned, 1 if any failed --
   (renice-main as)
    (: kinds ["process ID" "process group ID" "user ID"]
       a0 (? (two? as && (<as = "-n" || <as = "--priority" || <as = "--relative")) >as as)
       rel (two? as && <as = "--relative")
       _ (? (two? a0) 0 (udie 1 "renice: not enough arguments\nTry 'renice --help' for more information."))
       pr (: v (? (0 < #<a0 && <a0 0 = 45) (: u (unum (snip <a0 1 #<a0)) (? (charm? u) (0 - u) ())) (unum <a0))
             (? (charm? v) v (udie 1 ("renice: invalid priority '" + <a0 + "'\nTry 'renice --help' for more information."))))
       (warn m) (say err ("renice: " + m + "\n"), flush err)
       (one wh id)
        (: o (prio wh id)
           (? (nom? o) (warn ("failed to get priority for " + show id + " (" + kinds wh + "): " + uerrno o), 1)
              (: e (setprio wh id (? rel (o + pr) pr))
                 (? (nom? e) (warn ("failed to set priority for " + show id + " (" + kinds wh + "): " + uerrno e), 1)
                    (: nw (prio wh id)
                       _ (say out (show id + " (" + kinds wh + ") old priority " + show o
                                   + ", new priority " + show nw + "\n"))
                       0)))))
       (go l wh bad)
        (? (atom? l) bad
           (: w <l
              (? (w = "-p" || w = "--pid") (go >l 0 bad)
                 (w = "-g" || w = "--pgrp") (go >l 1 bad)
                 (w = "-u" || w = "--user") (go >l 2 bad)
                 (: id (? (wh = 2) (: u (uidof "/etc/passwd" w) (? u <>u (unum w))) (unum w))
                    (? (!(charm? id) || id < 0)
                       (warn (? (wh = 2) ("unknown user " + w) ("bad " + kinds wh + " value: " + w)), go >l wh 1)
                       (go >l wh (max bad (one wh id))))))))
       b (go >a0 0 0)
       _ (flush out)
       (? b 1 0))

   ; -- printenv: the world, or just the names asked for (a name with no value in it
   ; says nothing and the exit remembers, like GNU's) --
   (printenv-main as)
    (? (atom? as)
       (: (pr e) (? (atom? e) (flush out, 0)
                    (say out <e, put out 10, pr >e))
          (pr (environ 0)))
       (: (one w ok) (: v (getenv w)
                        (? (string? v) (say out v, put out 10, ok) 0))
          (go a ok) (? (two? a) (go >a (one <a ok)) (flush out, (? ok 0 1)))
          (go as 1)))

   ; -- whoami and groups: id's two thin faces (id -un and id -Gn) --
   (whoami-main _)
    (say out (uidname "/etc/passwd" (getuid 0)), put out 10, flush out, 0)
   (groups-main _)
    (: nm (uidname "/etc/passwd" (getuid 0))
       gs (ugroups nm (getgid 0))
       _ (say out (ujoin (map (g \ (uidname "/etc/group" g)) gs)))
       _ (put out 10) _ (flush out) 0)

   ; -- hostname: the name the kernel keeps. uname -n reads the same line, and this is
   ; the spelling a script asks by; no setting, which wants privilege and a syscall --
   (hostname-main _)
    (say out (u-1line "/proc/sys/kernel/hostname" "unknown"), put out 10, flush out, 0)

   ; -- hostid and dnsdomainname: what the resolver says of this host's own name, read
   ; the way glibc's lookup reaches it here -- /etc/hosts, then the addresses the host
   ; itself carries (systemd's myhostname, which the resolver asks next), lowest
   ; interface first and never loopback, then 127.0.0.2 where it carries none. no DNS:
   ; a name the host gives itself is not a question for a nameserver --
   (uhw-words l) (filter (w \ (0 < #w)) (foldl (\ a w (a + usplit 9 w)) () (usplit 32 l)))
   (uhw-quad w)                         ; dotted quad -> the in_addr as a charm (a first, low)
    (: ps (usplit 46 w)
       ns (map unum ps)
       (? (#ps = 4 && all (n \ (charm? n && 0 <= n && n < 256)) ns)
          (ns 0 + (ns 1 << 8) + (ns 2 << 16) + (ns 3 << 24)) ()))
   (uhw-hosts h)                        ; -> [addr canonical] | ()
    (: r (uread "/etc/hosts")
       (row l) (: k (findsub l "#") c (? (k < 0) l (snip l 0 k))
                  ws (uhw-words c)
                  a (? (two? ws) (uhw-quad <ws) ())
                  (? (charm? a && elem h >ws) [a <>ws] ()))
       (? (two? r) (: hits (filter two? (map row (lines <>r))) (? (two? hits) <hits ())) ()))
   (uhw-hex s) (: (go k a) (? (#s <= k) a (: c (s k) (go (k + 1) (a * 16 + (? (c < 58) (c - 48) (c < 71) (c - 55) (c - 87)))))) (go 0 0))
   (uhw-local _)                        ; the host's own ipv4s, by interface index
    (: fr (uread "/proc/net/fib_trie")
       ls (? (two? fr) (lines <>fr) ())
       (take l last acc) (? (atom? l) acc
                            (: ws (uhw-words <l)
                               (? (two? ws && <ws = "|--") (take >l (uhw-quad <>ws) acc)
                                  (ws = ["/32" "host" "LOCAL"]) (take >l last (? (charm? last && !((last & 255) = 127) && nelem last acc) (last . acc) acc))
                                  (take >l last acc))))
       as (take ls () ())
       rt (uread "/proc/net/route")
       rs (? (two? rt) (map uhw-words >(lines <>rt)) ())
       ; the narrowest route holding the address names its interface (the default holds all)
       (ifx a) (: r (filter (w \ (7 < #w && (a & uhw-hex (w 7)) = uhw-hex (w 1))) rs)
                  b (foldl (\ m w (? ((atom? m) || uhw-hex (m 7) < uhw-hex (w 7)) w m)) () r)
                  v (? (two? b) (uread ("/sys/class/net/" + <b + "/ifindex")) ())
                  (? (two? v) (unum (chomp <>v)) 1000000))
       (sortby (\ x y (: p (ifx x) q (ifx y) (? (p = q) (x <= y) (p < q)))) as))
   (uhw-self _)                         ; -> [addr canonical]
    (: h (u-1line "/proc/sys/kernel/hostname" "localhost")
       r (uhw-hosts h)
       (? (two? r) r
          (: ls (uhw-local 0) [(? (two? ls) <ls 33554559) h])))
   (hostid-main _)
    (: r (uread "/etc/hostid")
       v (? (two? r && 4 <= #<>r) (: b <>r (b 0 + (b 1 << 8) + (b 2 << 16) + (b 3 << 24)))
            (: a <(uhw-self 0) (((a << 16) + (a >> 16)) & 4294967295)))
       x (radix v 16)
       _ (say out ((zpad 8 x) + "\n")) _ (flush out) 0)
   (dnsdomainname-main _)
    (: c <>(uhw-self 0)
       k (findsub c ".")
       _ (? (0 <= k) (say out ((snip c (k + 1) #c) + "\n")) 0)
       _ (flush out) 0)

   ; -- setsid: the command in a session of its own. a group leader cannot start one,
   ; so it forks first, as util-linux does (and always under -f); -w waits for the
   ; child and leaves with its status, -c takes the terminal on 0 as the session's --
   (setsid-main as)
    (: (usage m) (udie 1 ("setsid: " + m + "\nTry 'setsid --help' for more information."))
       (go a c f w)
        (? (atom? a) [c f w ()]
           (: x <a n #x
              (? (x = "--") [c f w >a]
                 (x = "--ctty") (go >a 1 f w)
                 (x = "--fork") (go >a c 1 w)
                 (x = "--wait") (go >a c f 1)
                 (2 < n && snip x 0 2 = "--") (usage ("unrecognized option '" + x + "'"))
                 (1 < n && x 0 = 45)
                  (: (cl k c f w)
                      (? (n <= k) (go >a c f w)
                         (x k = 99) (cl (k + 1) 1 f w)
                         (x k = 102) (cl (k + 1) c 1 w)
                         (x k = 119) (cl (k + 1) c f 1)
                         (usage ("invalid option -- '" + string (x k) + "'")))
                     (cl 1 c f w))
                 [c f w a])))
       r (go as 0 0 0)
       c <r f <>r w <>>r cmd <>>>r
       _ (? (two? cmd) 0 (usage "no command specified"))
       (refused e) (udie 1 (? c ("setsid: failed to set the controlling terminal: " + uerrno e)
                               ("setsid: setsid failed: " + uerrno e)))
       (run _) (: x (exec cmd)
                  (udie (? (x = 'enoent) 127 126) ("setsid: failed to execute " + <cmd + ": " + uerrno x)))
       e0 (? f 'eperm (setsid c))
       (? !(nom? e0) (run 0)
          !(e0 = 'eperm) (refused e0)
          (: _ (flush out) _ (flush err)
             p (fork 0)
             (? (nom? p) (udie 1 ("setsid: fork failed: " + uerrno p))
                (p = 0) (: e (setsid c) (? (nom? e) (refused e) (run 0)))
                w (wait p)
                0))))

   ; -- watch: a command run again every -n seconds (2 by default, tenths allowed), its
   ; output laid over the screen under procps' title line; -t drops the title, -x execs
   ; the words rather than `sh -c` them, -b rings on a failure, -e stops on one, -g
   ; stops when the output changes --
   (watch-main as)
    (: (usage m) (udie 1 ("watch: " + m + "\nTry 'watch --help' for more information."))
       (secs w) (: v (udur w)
                   (? (charm? v) (max v 100) (usage ("failed to parse argument: '" + w + "'"))))
       (go a o)
        (? (atom? a) (pin o 'cmd (), o)
           (: x <a n #x
              (? (x = "--") (pin o 'cmd >a, o)
                 (x = "-n" || x = "--interval")
                  (? (two? >a) (pin o 'n (secs <>a), go >>a o) (usage "option requires an argument -- 'n'"))
                 (11 < n && snip x 0 11 = "--interval=") (pin o 'n (secs (snip x 11 n)), go >a o)
                 (x = "--no-title") (pin o 't 1, go >a o)
                 (x = "--exec") (pin o 'x 1, go >a o)
                 (x = "--beep") (pin o 'b 1, go >a o)
                 (x = "--errexit") (pin o 'e 1, go >a o)
                 (x = "--chgexit") (pin o 'g 1, go >a o)
                 (2 < n && snip x 0 2 = "--") (usage ("unrecognized option '" + x + "'"))
                 (1 < n && x 0 = 45)
                  (: (cl k)
                      (? (n <= k) (go >a o)
                         (x k = 110) (? (k + 1 < n) (pin o 'n (secs (snip x (k + 1) n)), go >a o)
                                        (two? >a) (pin o 'n (secs <>a), go >>a o)
                                        (usage "option requires an argument -- 'n'"))
                         (elem (x k) [116 120 98 101 103]) (pin o (x k @ 116 't 120 'x 98 'b 101 'e 'g) 1, cl (k + 1))
                         (usage ("invalid option -- '" + string (x k) + "'")))
                     (cl 1))
                 (pin o 'cmd a, o))))
       o (go as {'n 2000})
       cmd (o 'cmd)
       _ (? (two? cmd) 0 (usage "no command specified"))
       argv (? (o 'x) cmd ["sh" "-c" ("exec 2>&1\n" + ujoin cmd)])
       iv (o 'n)
       ivs (: t (zpad 2 (show (iv // 100))) ((snip t 0 (#t - 1)) + "." + snip t (#t - 1) #t))
       host (u-1line "/proc/sys/kernel/hostname" "localhost")
       (clip w s) (? (w < #s) (snip s 0 w) s)
       (frame out0 st)
        (: ws (tty 1)
           h (? (two? ws && 0 < <ws) <ws 24) w (cite 'grid 'screen 1)
           left ("Every " + ivs + "s: " + ujoin cmd)
           right (host + ": " + udatef "%a %b %e %H:%M:%S %Y" (clock 0))
           gap (w - #left - #right)
           head (? (o 't) () [(? (0 < gap) (left + upad (gap + #right) right) (clip w (left + "  " + right))) ""])
           ls (take (max 0 (h - #head)) (head + lines out0))
           _ (say out "\e[H\e[J")
           _ (say out (ujoinc 10 (map (clip w) ls)))
           _ (? (o 'b && st) (say out "\a") 0)
           (flush out))
       (loop prev)
        (: r (hark argv)
           st <r txt (? (string? >r) >r "")
           _ (frame txt st)
           (? (o 'g && string? prev && !(prev = txt)) 0
              (o 'e && st) (say out "\ncommand exit with a non-zero status\n", flush out, 1)
              (rest iv, loop txt)))
       (loop ()))

   ; -- tty: the terminal on stdin, named. there is no ttyname(3) here, so the answer
   ; comes off /proc/self/fd/0 -- the same link, by another road. GNU's exit codes:
   ; 0 a terminal, 1 not one --
   (tty-main _)
    (: t? (two? (tty in))
       r (readlink "/proc/self/fd/0")
       _ (say out (? !t? "not a tty" (? (string? r) r "/dev/tty")))
       _ (put out 10) _ (flush out)
       (? t? 0 1))

   ; -- stty: the line discipline on stdin (or -F's device), shown or set. the flags are
   ; linux's names and bits, which the libc hands over whatever kernel is under it; the
   ; views are GNU's: bare the changes from sane, -a all of it, -g the saved form. there
   ; is one speed, so ispeed and ospeed both set it. a row
   ; is (name word marks bits mask): word 0 iflag 1 oflag 2 cflag 3 lflag, marks 1 may be
   ; negated, 2 set by sane, 4 cleared by sane, 8 an alias never shown --
   ustty-modes
    '(("parenb" 2 1 256 0) ("parodd" 2 1 512 0) ("cmspar" 2 1 1073741824 0)
      ("cs5" 2 0 0 48) ("cs6" 2 0 16 48) ("cs7" 2 0 32 48) ("cs8" 2 0 48 48)
      ("hupcl" 2 1 1024 0) ("hup" 2 9 1024 0) ("cstopb" 2 1 64 0) ("cread" 2 3 128 0)
      ("clocal" 2 1 2048 0) ("crtscts" 2 1 2147483648 0)
      ("ignbrk" 0 5 1 0) ("brkint" 0 3 2 0) ("ignpar" 0 1 4 0) ("parmrk" 0 1 8 0)
      ("inpck" 0 1 16 0) ("istrip" 0 1 32 0) ("inlcr" 0 5 64 0) ("igncr" 0 5 128 0)
      ("icrnl" 0 3 256 0) ("ixon" 0 1 1024 0) ("ixoff" 0 5 4096 0) ("tandem" 0 9 4096 0)
      ("iuclc" 0 5 512 0) ("ixany" 0 5 2048 0) ("imaxbel" 0 3 8192 0) ("iutf8" 0 5 16384 0)
      ("opost" 1 3 1 0) ("olcuc" 1 5 2 0) ("ocrnl" 1 5 8 0) ("onlcr" 1 3 4 0)
      ("onocr" 1 5 16 0) ("onlret" 1 5 32 0) ("ofill" 1 5 64 0) ("ofdel" 1 5 128 0)
      ("nl1" 1 4 256 256) ("nl0" 1 2 0 256)
      ("cr3" 1 4 1536 1536) ("cr2" 1 4 1024 1536) ("cr1" 1 4 512 1536) ("cr0" 1 2 0 1536)
      ("tab3" 1 4 6144 6144) ("tab2" 1 4 4096 6144) ("tab1" 1 4 2048 6144) ("tab0" 1 2 0 6144)
      ("bs1" 1 4 8192 8192) ("bs0" 1 2 0 8192) ("vt1" 1 4 16384 16384) ("vt0" 1 2 0 16384)
      ("ff1" 1 4 32768 32768) ("ff0" 1 2 0 32768)
      ("isig" 3 3 1 0) ("icanon" 3 3 2 0) ("iexten" 3 3 32768 0) ("echo" 3 3 8 0)
      ("echoe" 3 3 16 0) ("crterase" 3 9 16 0) ("echok" 3 3 32 0) ("echonl" 3 5 64 0)
      ("noflsh" 3 5 128 0) ("xcase" 3 5 4 0) ("tostop" 3 5 256 0) ("echoprt" 3 5 1024 0)
      ("prterase" 3 9 1024 0) ("echoctl" 3 3 512 0) ("ctlecho" 3 9 512 0)
      ("echoke" 3 3 2048 0) ("crtkill" 3 9 2048 0) ("flusho" 3 5 4096 0) ("extproc" 3 5 65536 0))
   ; the control characters: (name slot sane); the state list holds slot k at 5 + k
   ustty-ccs '(("intr" 0 3) ("quit" 1 28) ("erase" 2 127) ("kill" 3 21) ("eof" 4 4)
               ("eol" 11 0) ("eol2" 16 0) ("swtch" 7 0) ("start" 8 17) ("stop" 9 19)
               ("susp" 10 26) ("rprnt" 12 18) ("werase" 14 23) ("lnext" 15 22) ("discard" 13 15))
   ustty-bauds '(0 50 75 110 134 150 200 300 600 1200 1800 2400 4800 9600 19200 38400 57600
                 115200 230400 460800 500000 576000 921600 1000000 1152000 1500000 2000000
                 2500000 3000000 3500000 4000000)
   ; the combinations, as the words they stand for; a leading - is the undoing
   ustty-combos
    {"cooked" ["brkint" "ignpar" "istrip" "icrnl" "ixon" "opost" "isig" "icanon"]
     "-raw" ["brkint" "ignpar" "istrip" "icrnl" "ixon" "opost" "isig" "icanon"]
     "evenp" ["-parodd" "cs7" "parenb"] "parity" ["-parodd" "cs7" "parenb"]
     "-evenp" ["-parenb" "cs8"] "-parity" ["-parenb" "cs8"]
     "oddp" ["cs7" "parodd" "parenb"] "-oddp" ["-parenb" "cs8"]
     "nl" ["-icrnl" "-onlcr"] "-nl" ["icrnl" "-inlcr" "-igncr" "onlcr" "-ocrnl" "-onlret"]
     "ek" ["erase" "^?" "kill" "^U"]
     "cbreak" ["-icanon"] "-cbreak" ["icanon"]
     "pass8" ["-parenb" "cs8" "-istrip"] "-pass8" ["cs7" "parenb" "istrip"]
     "litout" ["-parenb" "cs8" "-istrip" "-opost"] "-litout" ["cs7" "parenb" "istrip" "opost"]
     "decctlq" ["-ixany"] "-decctlq" ["ixany"] "tabs" ["tab0"] "-tabs" ["tab3"]
     "lcase" ["xcase" "iuclc" "olcuc"] "-lcase" ["-xcase" "-iuclc" "-olcuc"]
     "LCASE" ["xcase" "iuclc" "olcuc"] "-LCASE" ["-xcase" "-iuclc" "-olcuc"]
     "crt" ["echoe" "echoctl" "echoke"]
     "dec" ["intr" "^C" "erase" "^?" "kill" "^U" "echoe" "echoctl" "echoke" "-ixany"]}
   (ustty-vis c)
    (? (c = 0) "<undef>" (c = 127) "^?" (c < 32) ("^" + string (c + 64)) (c < 127) (string c)
       (: d (c - 128) ("M-" + (? (d = 127) "^?" (d < 32) ("^" + string (d + 64)) (string d)))))
   (ustty-at l k v) (? (k = 0) (v . >l) (<l . (ustty-at >l (k - 1) v)))
   (ustty-off x b) (x - (x & b))
   (ustty-on? st m) (: mk (? (0 < m 4) (m 4) (m 3)) (((st (m 1)) & mk) = m 3))
   (ustty-set st m neg)
    (: k (m 1) x (st k) mk (? (0 < m 4) (m 4) (m 3))
       (ustty-at st k (? neg (ustty-off x (m 3)) (ustty-off x mk | m 3))))
   (ustty-sane st)
    (: c (foldl (\ s r (ustty-at s (5 + r 1) (r 2))) st ustty-ccs)
       c2 (ustty-at (ustty-at c 11 1) 10 0)
       (foldl (\ s m (: k (m 1) x (s k) mk (? (0 < m 4) (m 4) (m 3))
                        (? (0 < (m 2 & 2)) (ustty-at s k (ustty-off x mk | m 3))
                           (0 < (m 2 & 4)) (ustty-at s k (ustty-off (ustty-off x (m 4)) (m 3)))
                           s)))
              c2 ustty-modes))
   (ustty-int s)                       ; decimal, 0x hex or 0 octal -> a charm | ()
    (: n #s
       hx (2 < n && s 0 = 48 && (s 1 = 120 || s 1 = 88))
       b (? hx 16 (1 < n && s 0 = 48) 8 10)
       (dig c) (? (48 <= c && c <= 57) (c - 48) (97 <= c && c <= 102) (c - 87)
                  (65 <= c && c <= 70) (c - 55) 99)
       (go i a) (? (n <= i) a (: d (dig (s i)) (? (d < b) (go (i + 1) (a * b + d)) ())))
       (? (n = 0) () (go (? hx 2 0) 0)))
   (ustty-byte w)
    (: v (ustty-int w)
       (? (charm? v && v <= 255) v
          (udie 1 ("stty: invalid integer argument: '" + w + "'"
                   + (? (charm? v) ": Value too large for defined data type" "")))))
   (ustty-ccval s)
    (? (#s = 1) (s 0)
       (s = "^-" || s = "undef") 0
       (#s = 2 && s 0 = 94) (? (s 1 = 63) 127 (s 1 & 159))
       (ustty-byte s))
   (ustty-hex v)
    (: d "0123456789abcdef"
       (go v a) (? (v < 16) (string (d v) + a) (go (v // 16) (string (d (v % 16)) + a)))
       (go v ""))
   (ustty-wrap w items xtra)           ; GNU's wrap: an item that would reach w starts a line
    (: (go l col acc)
        (? (atom? l) (acc + "\n")
           (: s <l n (#s + (? (two? >l) 0 xtra))
              (? (col = 0) (go >l n (acc + s))
                 ((w - col) <= n) (go >l n (acc + "\n" + s))
                 (go >l (col + 1 + n) (acc + " " + s)))))
       (go items 0 ""))
   (ustty-flags st all?)               ; -> the four groups' items, control input output local
    (: (item m)
        (? (ustty-on? st m) (? (all? || 0 < (m 2 & 4)) (m 0) ())
           all? (? (0 < (m 2 & 1)) ("-" + m 0) ())
           ((m 2 & 3) = 3) ("-" + m 0)
           ())
       (grp g) (filter string? (map item (filter (m \ (m 1 = g) && (m 2 & 8) = 0) ustty-modes)))
       (map grp '(2 0 1 3)))
   (ustty-show st all? w rc)
    (: sp ("speed " + show (st 4) + " baud;")
       cci (map (r \ r 0 + " = " + ustty-vis (st (5 + r 1)) + ";")
                (? all? ustty-ccs (filter (r \ !(st (5 + r 1) = r 2)) ustty-ccs)))
       mt ("min = " + show (st 11) + "; time = " + show (st 10) + ";")
       icanon (0 < (st 3 & 2))
       l1 (ustty-wrap w (? all? ([sp] + (? (two? rc) [("rows " + show <rc + "; columns " + show >rc + ";")] ())
                                      + ["line = 0;"])
                           [sp "line = 0;"]) 0)
       l2 (? all? (ustty-wrap w (cci + [mt]) 0)
             !icanon (ustty-wrap w (cci + [mt]) 1)
             (two? cci) (ustty-wrap w cci 0)
             "")
       fl (foldl (\ a g (? (two? g) (a + ustty-wrap w g 0) a)) "" (ustty-flags st all?))
       (say out (l1 + l2 + fl)))
   (stty-main as)
    (: (bad w) (udie 1 ("stty: invalid argument '" + w + "'\nTry 'stty --help' for more information."))
       (go a all gs dev ss)
        (? (atom? a) [all gs dev (rev ss)]
           (: w <a
              (? (w = "-a" || w = "--all") (go >a 1 gs dev ss)
                 (w = "-g" || w = "--save") (go >a all 1 dev ss)
                 (w = "-F" || w = "--file")
                  (? (two? >a) (go >>a all gs <>a ss) (udie 1 "stty: option requires an argument -- 'F'"))
                 (7 < #w && snip w 0 7 = "--file=") (go >a all gs (snip w 7 #w) ss)
                 (2 < #w && snip w 0 2 = "-F") (go >a all gs (snip w 2 #w) ss)
                 (go >a all gs dev (w . ss)))))
       o (go as 0 0 () ())
       all <o gs <>o dev <>>o ss (o 3)
       _ (? (all && gs) (udie 1 "stty: the options for verbose and stty-readable output styles are\nmutually exclusive") 0)
       _ (? ((all || gs) && two? ss) (udie 1 "stty: when specifying an output style, modes may not be set") 0)
       nm (? dev dev "'standard input'")
       fd (? dev (: q (open dev "r") (? (hot? q) q (udie 1 ("stty: " + dev + ": " + uerrno q)))) in)
       st0 (termios fd)
       _ (? (nom? st0) (udie 1 ("stty: " + nm + ": " + uerrno st0)) 0)
       tw (tty out)
       cw (getenv "COLUMNS")
       w (? (two? tw && 0 < >tw) >tw (string? cw && 0 < uatoi cw) (uatoi cw) 80)
       rc (: r (tty fd) (? (two? r) r ()))
       (need l) (? (two? >l) <>l (udie 1 ("stty: missing argument to '" + <l + "'\nTry 'stty --help' for more information.")))
       (win l k)                       ; rows or cols, laid now, as GNU lays them
        (: v (ustty-byte0 (need l)) r (tty fd)
           _ (? (two? r) (settty fd (? (k = 0) v <r) (? (k = 0) >r v)) 0)
           0)
       (gform w)                       ; -g's own output read back -> the state | ()
        (: f (usplit 58 w) vs (map (x \ ustty-int ("0x" + x)) f)
           (? (4 < #f && nelem () vs)
              (: cc (: (go l k) (? (17 <= k) () ((? (two? l) <l 0) . (go >l (k + 1)))) (go (drop 4 vs) 0))
                 ([(vs 0) (vs 1) (vs 2) (vs 3) -1] + cc))
              ()))
       (apply st l)
        (? (atom? l) st
           (: w <l
              neg (1 < #w && w 0 = 45)
              base (? neg (snip w 1 #w) w)
              m (: (f ms) (? (atom? ms) () (<ms 0 = base) <ms (f >ms)) (f ustty-modes))
              cc (: (f cs) (? (atom? cs) () (<cs 0 = w) <cs (f >cs)) (f ustty-ccs))
              cb (ustty-combos w)
              sp (ustty-int w)
              gf (? (usub? ":" w) (gform w) ())
              (? (two? m) (? (neg && (m 2 & 1) = 0) (bad w) (apply (ustty-set st m neg) >l))
                 (two? cc) (apply (ustty-at st (5 + cc 1) (ustty-ccval (need l))) >>l)
                 (w = "min") (apply (ustty-at st 11 (ustty-byte (need l))) >>l)
                 (w = "time") (apply (ustty-at st 10 (ustty-byte (need l))) >>l)
                 (w = "ispeed" || w = "ospeed")
                  (: v (ustty-int (need l))
                     (? (elem v ustty-bauds) (apply (ustty-at st 4 v) >>l) (bad <>l)))
                 (w = "rows") (win l 0, apply st >>l)
                 (w = "cols" || w = "columns") (win l 1, apply st >>l)
                 (w = "size") (: r (tty fd)
                                 _ (? (two? r) (say out (show <r + " " + show >r + "\n"))
                                      (udie 1 ("stty: " + nm + ": unable to get window size")))
                                 (apply st >l))
                 (w = "speed") (say out (show (st 4) + "\n"), apply st >l)
                 (w = "raw" || w = "-cooked")
                  (apply (apply (ustty-at st 0 0) ["-opost" "-isig" "-icanon" "-xcase" "min" "1" "time" "0"]) >l)
                 (w = "sane") (apply (ustty-sane st) >l)
                 (two? cb) (apply (apply st cb) >l)
                 (charm? sp) (? (elem sp ustty-bauds) (apply (ustty-at st 4 sp) >l) (bad w))
                 (two? gf) (apply gf >l)
                 (bad w))))
       (? gs (say out (ustty-hex (st0 0) + ":" + ustty-hex (st0 1) + ":" + ustty-hex (st0 2) + ":"
                            + ustty-hex (st0 3)
                            + foldl (\ a v (a + ":" + ustty-hex v)) "" (drop 5 st0 + map (_ \ 0) ^15) + "\n"), flush out, 0)
          (two? ss) (: st (apply st0 ss)
                       e (? (st = st0) () (settermios fd st))
                       _ (flush out)
                       _ (? (nom? e) (udie 1 ("stty: " + nm + ": " + uerrno e)) 0)
                       ; read back, as GNU does: a pty takes no parity and no size, and
                       ; saying nothing then would be a lie
                       now (termios fd)
                       (same a b) (: sa (? (b 4 < 0) (ustty-at a 4 -1) a) sb (? (b 4 < 0) (ustty-at b 4 -1) b) (sa = sb))
                       (? (st = st0 || (two? now && same now st)) 0
                          (udie 1 ("stty: " + nm + ": unable to perform all requested operations"))))
          (ustty-show st0 all w rc, flush out, 0)))
   (ustty-byte0 w) (: v (ustty-int w) (? (charm? v && v <= 65535) v (udie 1 ("stty: invalid integer argument: '" + w + "'"))))

   ; -- microcom: a serial line and this terminal, byte for byte, busybox's. the device is
   ; opened read-write, never as our controlling terminal, and set raw 8N1 without flow
   ; control at -s's speed (or its own); ^X leaves unless -X, and -t ms of quiet both ways
   ; leaves too. the device's termios goes back as it was
   (microcom-main as)
    (: usage "usage: microcom [-X] [-s SPEED] [-t TIMEOUT] TTY"
       t (tablet 0)
       o (uopt as t '(115 116 100) () ())
       _ (? (two? o) 0 (udie 1 usage))
       _ (: u (uoptun t '(115 116 88)) (? !u 0 (udie 1 ("microcom: -" + string u + " is not supported\n" + usage))))
       ops (o 2)
       _ (? (two? ops && atom? >ops) 0 (udie 1 usage))
       dev <ops
       sp (: v (uoptv t 115) (? !v -1 (: n (ustty-int v) (? (elem n ustty-bauds) n (udie 1 ("microcom: bad speed " + v))))))
       tmo (: v (uoptv t 116) (? !v () (: n (ustty-int v) (? (charm? n) n (udie 1 ("microcom: bad timeout " + v))))))
       x? (peep t 88 0)
       fd (openfd dev 5)
       _ (? (charm? fd) 0 (udie 1 ("microcom: " + dev + ": " + uerrno fd)))
       st0 (termios fd)
       _ (? (nom? st0) (udie 1 ("microcom: " + dev + ": " + uerrno st0)) 0)
       ; iflag, oflag and lflag off, cflag CS8 CREAD CLOCAL, a read of one byte at a time
       st (ustty-at (ustty-at ([0 0 2224 0 (? (sp < 0) (st0 4) sp)] + drop 5 st0) 11 1) 10 0)
       e (settermios fd st)
       _ (? (nom? e) (udie 1 ("microcom: " + dev + ": " + uerrno e)) 0)
       p (fdopen fd)
       tty? (two? (tty 0))
       _ (? tty? (raw 1) 0)
       last (tablet 1) _ (pin last 't (clock 0))
       (done _) (settermios fd st0, (? tty? (raw 0) 0), flush out, quit 0)
       ; the line to the screen, in its own task
       (down _) (: _ (await p) c (see p)
                   (? (c = -1) (done 0)
                      (unsee p c, say out (chug p), flush out, pin last 't (clock 0), down 0)))
       _ (twirl down 0)
       _ (? (charm? tmo) (twirl (_ \ ((: (g _) (? (tmo < ((clock 0) - (last 't))) (done 0) (rest 50, g 0))) 0)) 0) 0)
       ; the keys to the line, up to a ^X
       (up _) (: _ (await in) c (see in)
                 (? (c = -1) (done 0)
                    (: _ (unsee in c) s (chug in)
                       k (? x? -1 ((: (g i) (? (#s <= i) -1 (s i = 24) i (g (i + 1)))) 0))
                       _ (say p (? (k < 0) s (snip s 0 k))) _ (flush p)
                       _ (pin last 't (clock 0))
                       (? (k < 0) (up 0) (done 0)))))
       (up 0))

   ; -- clear: home, erase, and drop the scrollback. the third (xterm's 3J) is what a
   ; modern clear sends and the reason `clear` and ^L are not the same key --
   (clear-main _) (say out "\e[H\e[2J\e[3J", flush out, 0)

   ; -- which: the first PATH member holding NAME and letting us run it; -a names
   ; every one. a NAME carrying a slash is a path already and answers for itself.
   ; exit 1 where a name went unfound, as GNU's does --
   (uwhich-try p) (t-file "-f" p && t-file "-x" p)
   (uwhich nm all?)                             ; -> the hits, in PATH order
    (? (0 < (lastslash nm)) (? (uwhich-try nm) [nm] ())
       (: pv (getenv "PATH")
          ds (usplit 58 (? (string? pv) pv ""))
          (go l acc) (? (atom? l) (rev acc)
                        (: d (? (0 < tally <l) <l ".")
                           p (d + "/" + nm)
                           (? !(uwhich-try p) (go >l acc)
                              all? (go >l (p . acc))
                              (rev (p . acc)))))
          (go ds ())))
   (which-main as)
    (: a? (two? as && <as = "-a")
       ns (? a? >as as)
       _ (? (two? ns) () (udie 2 "usage: which [-a] NAME.."))
       (go l bad)
        (? (atom? l) (flush out, bad)
           (: hs (uwhich <l a?)
              _ (map (p \ (say out p, put out 10)) hs)
              (go >l (? (two? hs) bad 1))))
       (go ns 0))

   ; -- timeout: run a command, and end it if it outruns the clock. `gather` polls
   ; without blocking, so the wait and the deadline are the one loop; the signal is
   ; TERM unless -s names another, and -k arms a KILL that far past it. GNU's status:
   ; 124 for a command the clock ended, 125 for our own trouble, 126/127 for one that
   ; would not start, and otherwise the command's own --
   ; usignum wants the dash the command line writes; -s spells the bare name
   (utmo-flags a sig kill)
    (? (atom? a) [sig kill a]
       (<a = "-s") (? (two? >a) (utmo-flags >>a (usignum ("-" + <>a)) kill)
                      (udie 125 "timeout: -s wants a signal"))
       (<a = "-k") (? (two? >a) (utmo-flags >>a sig (udur <>a))
                      (udie 125 "timeout: -k wants a duration"))
       [sig kill a])
   ; the deadline and the wait are ONE loop: gather polls without blocking, so there
   ; is no alarm to arm and no handler to run. `sent` is the elapsed reading the signal
   ; went out at and () while the command still has its time; k? says the KILL followed
   (utmo-wait p t0 lim sig kill)
    (: (go sent k?)
        (: r (gather p)
           (? (two? r) (? (charm? sent) 124 <r)  ; a child we ended reads 124, not its own
              (nom? r) 125
              (: el (clock t0)
                 fire (? (!(charm? sent) && lim <= el) el sent)
                 _ (? (fire = sent) 0 (still p sig))
                 k2 (? ((!k? && charm? fire) && (charm? kill && (fire + kill) <= el))
                       (still p 9, 1)
                       k?)
                 _ (rest 20)
                 (go fire k2))))
       (go () 0))
   (timeout-main as)
    (: fp (utmo-flags as 15 ())
       sig <fp kill <>fp ops <>>fp
       _ (? (two? ops && two? >ops) ()
            (udie 125 "usage: timeout [-s SIG] [-k DUR] DURATION CMD [ARG..]"))
       _ (? (charm? sig) () (udie 125 "timeout: unknown signal"))
       lim (udur <ops)
       _ (? (charm? lim) () (udie 125 ("timeout: invalid duration '" + <ops + "'")))
       cmd >ops
       t0 (clock 0)
       p (spawn cmd)
       (? (nom? p) (say err ("timeout: cannot run " + <cmd), put err 10, uleave 127)
          (lim = 0) (wait p)                    ; a zero duration is no limit, as GNU has it
          (utmo-wait p t0 lim sig kill)))


   ; ---- chroot, mount and umount: the three the distro's own boot asks for -------
   ; every one of them needs privilege and says so through errno like any other row:
   ; 'eperm is an answer, not a crash, which is what makes them safe to smoke unprivileged.

   ; chroot DIR [CMD [ARG..]] -- LFS chapter 7 is this call. the root changes, the cwd
   ; follows it to /, and the command REPLACES us, so the only thing that returns here
   ; is a failure.
   ;
   ; with no CMD the command is OUR OWN SHELL, not $SHELL and not /bin/sh: in an empty
   ; root there is no /bin/sh to be had, and there does not need to be one -- lush's
   ; verbs are in this binary, so an autonomous shell in a root with no files in it is
   ; a whole userland. what that costs is an exec of an image the new root cannot name,
   ; which is exactly what fexecve is for: the fd is opened HERE, before the root moves,
   ; and names the image afterwards when no path does. a seat that cannot say where it
   ; is (no selfpath) has no self to exec and falls back to the path it was given.
   (chroot-main as)
    (: _ (? (two? as) () (udie 1 "usage: chroot DIR [CMD [ARG..]]"))
       d <as
       _ (? (lit? (cite 'posix 'chroot)) () (udie 1 "chroot: no chroot on this seat"))
       ; both of these are read BEFORE the root moves, and for the same reason:
       ; selfpath is /proc/self/exe, and the new root has no /proc to read it from.
       mypath (: p (selfpath 0) (? (string? p) p ()))
       me (? mypath (open mypath "r") ())
       e (chroot d)
       _ (? e (udie 1 ("chroot: cannot change root to " + d + ": " + (show e))) ())
       ; the chdir is not tidiness. chroot moves the ROOT and leaves the cwd where it
       ; was -- outside the new tree -- and a relative path then walks out of the jail.
       _ (? (chdir "/") (udie 1 "chroot: cannot enter the new root") ())
       self? (atom? >as && hot? me)
       cmd (? (two? >as) >as
              self? [mypath "lush"]
              (: sh (getenv "SHELL") [(? (string? sh) sh "/bin/sh") "-i"]))
       r (self? ? (fexec me cmd) (exec cmd))
       (udie 127 ("chroot: cannot run " + <cmd + ": " + (show r))))

   ; the -o words that are FLAGS. anything else an -o can carry is filesystem text
   ; (tmpfs's size=, vfat's uid=) and rides mount(2)'s data argument, which no nif
   ; here passes -- so it is refused by name rather than taken and dropped.
   umnt-flags '(("ro" 1) ("nosuid" 2) ("nodev" 4) ("noexec" 8) ("sync" 16)
                ("remount" 32) ("noatime" 1024) ("nodiratime" 2048) ("bind" 4096)
                ("move" 8192) ("rec" 16384) ("relatime" 2097152)
                ("rw" 0) ("suid" 0) ("dev" 0) ("exec" 0) ("async" 0) ("defaults" 0))
   (umnt-opt w)
    (: r (assoc w umnt-flags) (? (two? r) <>r ()))
   (umnt-bits ws acc)
    (? (atom? ws) acc
       (: b (umnt-opt <ws)
          _ (? (charm? b) () (udie 1 ("mount: -o " + <ws + " is not a flag this mount can carry")))
          (umnt-bits >ws (acc | b))))

   ; bare `mount` reads /proc/self/mounts, which is where the kernel keeps the answer.
   ; there is no /etc/mtab here and writing one would be a second truth to keep.
   (mount-list _)
    (: r (uread "/proc/self/mounts")
       _ (? (two? r) () (udie 1 "mount: cannot read /proc/self/mounts"))
       (go l) (? (atom? l) ()
                 (: w (words <l)
                    _ (? (4 <= #w) (say out ((w 0) + " on " + (w 1) + " type " + (w 2)
                                                  + " (" + (w 3) + ")"), put out 10)
                         ())
                    (go >l)))
       _ (go (filter (s \ #s) (lines <>r)))
       _ (flush out) 0)
   (mount-main as)
    (? (atom? as) (mount-list ())
       (: t (tablet 0)
          o (uopt as t '(116 111) '(101) ())
          _ (? (two? o) () (udie 1 "mount: -t and -o each want a value"))
          _ (: c (uoptun t "to") (? !c () (udie 1 ("mount: unknown option -" + string c))))
          ty (: v (uoptv t 116) (? (string? v) v "auto"))
          ob (: v (uoptv t 111) (? (string? v) (umnt-bits (usplit 44 v) 0) 0))
          fs <>>o
          _ (? (two? >fs) () (udie 1 "usage: mount [-t TYPE] [-o OPTS] SRC TGT   (or bare, to list)"))
          src <fs tgt <>fs
          _ (? (lit? (cite 'posix 'mountf)) () (udie 1 "mount: no mount on this seat"))
          e (mountf src tgt ty ob)
          (? e (udie 1 ("mount: cannot mount " + src + " on " + tgt + ": " + (show e))) 0)))
   (umount-main as)
    (: _ (? (two? as) () (udie 1 "usage: umount TARGET.."))
       _ (? (lit? (cite 'posix 'umount)) () (udie 1 "umount: no umount on this seat"))
       (go l ok) (? (atom? l) ok
                    (: e (umount <l)
                       _ (? e (say err ("umount: cannot unmount " + <l + ": " + (show e)), put err 10)
                            ())
                       (go >l (? e 0 ok))))
       ok (go as 1)
       _ (flush err) (? ok 0 1))

   ; ---- the /proc family: ps, free, uptime, pidof, pgrep, pkill, killall, pwdx ----
   ; no nif grew for any of these. /proc is a filesystem, so the whole family is
   ; `uread` and a parser -- which is also why a world without one (the kernel's own
   ; image, inle/kmain.c, mounts no procfs) reads as no processes rather than as an
   ; error. The tools say what they found; they do not invent a reason.
   ; and none of them can be smoked byte-for-byte against procps: the process table
   ; moves between two runs, and every number here is a clock. So the parsers are lawed
   ; (test/law/kore.l) and the faces are smoked as sets -- a pid we made ourselves is in the
   ; listing, a pid we killed is gone -- which is test/kore/procfs.sh's own note.

   (uprocs _)                          ; every numeric name under /proc, ascending
    (: r (readdir "/proc")
       (dig? s) (: n #s
                   (go k) (? (n <= k) (0 < n)
                             (48 <= (s k) && (s k) <= 57) (go (k + 1))
                             0)
                   (go 0))
       (? (two? r) (sort (map uatoi (filter dig? r))) ()))
   ; a stat line -> (pid comm state ppid pgrp session tty_nr ..). the comm is taken
   ; between the first "(" AND THE LAST ")" and never by splitting on spaces: a program
   ; may be named `(sd-pam)` or `a b)c`, and a naive split reads its parentheses as
   ; fields -- silently, since every field after it is then off by the same amount.
   (ustatf ln)
    (: n #ln
       (lp k) (? (k < 0) -1 ((ln k) = 41) k (lp (k - 1)))
       (fp k) (? (n <= k) -1 ((ln k) = 40) k (fp (k + 1)))
       a (fp 0) b (lp (n - 1))
       ; the pid is taken through the word split and not off the raw slice: `uatoi`
       ; reads every charm it is handed, so the space before the "(" goes in as -16
       (? (a < 0 || (b < 0 || b < a)) ()
          (: h (words (snip ln 0 a))
             (? (atom? h) ()
                ((uatoi <h) . ((snip ln (a + 1) b) . (words (snip ln (b + 1) n))))))))
   (upstat pid)                        ; a pid -> its stat fields | ()
    (: r (uread (("/proc/" + (show pid)) + "/stat"))
       (? (two? r) (ustatf <>r) ()))
   (upself _)                          ; the same for this very process
    (: r (uread "/proc/self/stat") (? (two? r) (ustatf <>r) ()))
   (upcmd pid)                         ; the cmdline, NULs to spaces, or () when empty
    (: r (uread (("/proc/" + (show pid)) + "/cmdline"))
       (? (atom? r) ()
          (: s <>r n #s
             (go k acc) (? (n <= k) acc
                           (go (k + 1) (acc + (? ((s k) = 0) " " (string (s k))))))
             o (go 0 "")
             z #o
             (? (0 = z) () ((o (z - 1)) = 32) (snip o 0 (z - 1)) o))))
   ; argv[0]'s basename, for pidof -- the raw clip, since a kernel comm never
   ; carries a trailing slash for posix's rule to strip

   ; the two clocks. user_hz is 100 everywhere Linux runs a userland we could be in.
   (uclk s)                            ; a second count -> hh:mm:SS
    (: (p2 v) (zpad 2 (show v))
       ((((p2 (s // 3600)) + ":") + ((p2 ((s % 3600) // 60)) + ":")) + (p2 (s % 60))))
   (uhms tk) (uclk (tk // 100))
   ; tty_nr -> the name ps prints. the encoding is Linux's own: major in bits 8..19,
   ; minor split across 0..7 and 20..31, and 0 means no controlling terminal.
   (utty n)
    (? (n = 0) "?"
       (: maj ((n >> 8) & 4095)
          mn ((n & 255) | ((n >> 12) & 1048320))
          (? (maj = 136) ("pts/" + (show mn))
             (maj = 4) (? (mn < 64) ("tty" + (show mn)) ("ttyS" + (show (mn - 64))))
             "?")))
   ; /proc/uptime's seconds -> procps' phrase. under an hour it counts minutes, and a
   ; day arrives with a comma: "up 26 days,  8:01", "up  2:33", "up 33 min"
   (uupsay secs)
    (: d (secs // 86400)
       hh ((secs % 86400) // 3600)
       mm ((secs % 3600) // 60)
       ds (? (0 < d) ((show d) + (? (d = 1) " day, " " days, ")) "")
       (? (0 < (d + hh)) ((ds + (upad 2 (show hh))) + (":" + (zpad 2 (show mm))))
          ((show mm) + " min")))
   (umeminfo _)                        ; /proc/meminfo -> a tablet, the kB counts by name
    (: r (uread "/proc/meminfo")
       t (tablet 0)
       (one ln) (: n #ln
                   (go k) (? (n <= k) -1 ((ln k) = 58) k (go (k + 1)))
                   i (go 0)
                   (? (i < 0) 0
                      (: ws (words (snip ln (i + 1) n))
                         (? (two? ws) (pin t (intern (snip ln 0 i)) (uatoi <ws)) 0))))
       _ (? (two? r) (foldl (\ _ ln (one ln)) 0 (lines <>r)) 0)
       t)

   ; -- ps: the pid, its terminal, its cpu time and its name. -e/-A/a/x take every
   ; process; bare ps takes the ones that are ours and share this terminal, which is
   ; procps' rule (same euid, same tty) and not a simplification of it -- a bare ps
   ; listing root's daemons would be a different tool.
   ; the owner comes off /proc/PID itself, whose directory is owned by the process:
   ; one stat where /proc/PID/status would be a second read and a second parser.
   (upuid p) (: st (stat ("/proc/" + (show p))) (? (5 < #st) (st 4) -1))
   (ps-main as)
    (: all (: (go l) (? (atom? l) 0
                        (: w <l
                           (? (elem w '("-e" "-A" "-ax" "ax" "a" "x" "-a")) 1 (go >l))))
              (go as))
       self (upself 0)
       mine (? self (uatoi (self 6)) 0)
       myuid (getuid 0)
       _ (say out "    PID TTY          TIME CMD") _ (put out 10)
       (one p) (: f (upstat p)
                  (? !f 0
                     (: tty (uatoi (f 6))
                        (? !(all || (tty = mine && (upuid p) = myuid)) 0
                           (say out (upad 7 (show p)), say out (" " + (urpad 8 (utty tty))), say out (" " + (uhms ((uatoi (f 13)) + (uatoi (f 14))))), say out (" " + (f 1)), put out 10)))))
       _ (foldl (\ _ p (one p)) 0 (uprocs 0))
       _ (flush out) 0)

   ; -- free: /proc/meminfo, procps' six columns. used is total minus available and
   ; not total minus free: the kernel's own estimate of what a new program could have
   ; is the only honest reading of "used", and it is what procps prints --
   (free-main as)
    (: m (umeminfo 0)
       (g k) (peep m k 0)
       div (? (elem "-g" as) 1048576 (? (elem "-m" as) 1024 1))
       ; -h: the unit each number fits, procps' suffixes. the readings are KiB out of
       ; /proc/meminfo, so the ladder starts at Ki
       (hum k) (: (go v us) (? (v < 1024 || (atom? >us)) (show v + <us) (go (v // 1024) >us))
                  (go k '("Ki" "Mi" "Gi" "Ti" "Pi")))
       h? (elem "-h" as)
       (cell x) (upad 12 (? h? (hum x) (show (x // div))))
       tot (g 'MemTotal) fre (g 'MemFree) av (g 'MemAvailable)
       bc (((g 'Buffers) + (g 'Cached)) + (g 'SReclaimable))
       st (g 'SwapTotal) sf (g 'SwapFree)
       _ (say out "               total        used        free      shared  buff/cache   available")
       _ (put out 10)
       _ (say out ((urpad 8 "Mem:") + (cell tot) + (cell (tot - av)) + (cell fre)
                   + (cell (g 'Shmem)) + (cell bc) + (cell av)))
       _ (put out 10)
       _ (say out ((urpad 8 "Swap:") + (cell st) + (cell (st - sf)) + (cell sf)))
       _ (put out 10)
       _ (flush out) 0)

   ; -- uptime: the clock, how long since boot, the users the host's utmp holds, and
   ; the three load averages. with no utmp to read the users field is left out, never
   ; a made-up 0. the time of day is utc, for the reason `date` gives --
   (uupticks _)                        ; /proc/uptime's first number in centiseconds --
    (: r (uread "/proc/uptime")         ; user_hz, the scale a starttime is already in
       (? (atom? r) 0
          (: w (words <>r)
             (? (atom? w) 0
                (: p (usplit 46 <w)
                   fr (? (two? >p) (snip (<>p + "00") 0 2) "00")
                   (((uatoi <p) * 100) + (uatoi fr)))))))
   (uupsecs _) ((uupticks 0) // 100)   ; ..and the whole seconds uptime prints
   (uloadav _)                         ; /proc/loadavg's three figures, as one phrase
    (: l (uread "/proc/loadavg")
       ws (? (two? l) (words <>l) ())
       (? (2 < #ws) ((((ws 0) + ", ") + ((ws 1) + ", ")) + (ws 2))
          "0.00, 0.00, 0.00"))
   (uptime-main as)
    (: secs (uupsecs 0)
       ld (uloadav 0)
       tod (uclk (((clock 0) // 1000) % 86400))
       r (uut-read (uut-file 0))
       nu (? r #(filter (uut-user? 1) <>r) ())
       us (? (charm? nu) (",  " + show nu + (? (nu = 1) " user" " users")) "")
       _ (say out (" " + tod + " up " + uupsay secs + us + ",  load average: " + ld))
       _ (put out 10) _ (flush out) 0)

   ; -- the utmp family: who, users, logname. the host keeps the file and kore only
   ; reads it, in the three shapes a host writes: glibc's 384-byte record, netbsd's
   ; 520-byte utmpx, freebsd's packed 197-byte futx (big-endian). a record reads as
   ; (type pid line id user host secs term exit), the type in sysv's numbering --
   (ucz s i n)                         ; the NUL-ended text in s[i, i+n)
    (: e (i + n) (go j) (? (j < e && !(s j = 0)) (go (j + 1)) (snip s i j)) (go i))
   (uut-glibc s i)
    [(rdle s i 2) (rdle s (i + 4) 4) (ucz s (i + 8) 32) (ucz s (i + 40) 4) (ucz s (i + 44) 32)
     (ucz s (i + 76) 256) (rdle s (i + 340) 4) (rdle s (i + 332) 2) (rdle s (i + 334) 2)]
   (uut-nbsd s i)                      ; its run level rides the exit pair, not the pid
    [(rdle s (i + 326) 2)
     (? (rdle s (i + 326) 2 = 1) (rdle s (i + 332) 2 + 256 * rdle s (i + 334) 2) (rdle s (i + 328) 4)) (ucz s (i + 36) 32) (ucz s (i + 32) 4) (ucz s i 32)
     (ucz s (i + 68) 256) (rdle s (i + 464) 8) (rdle s (i + 332) 2) (rdle s (i + 334) 2)]
   (uut-fbsd s i)                      ; freebsd counts its types from boot = 1
    [(: t (s i) (? (t < 8) ([0 2 3 4 7 5 6 8] t) 0))
     (rdbe s (i + 17) 4) (ucz s (i + 53) 16) (ucz s (i + 9) 8) (ucz s (i + 21) 32)
     (ucz s (i + 69) 128) (rdbe s (i + 1) 8 // 1000000) 0 0]
   ; the shape goes by the name, as each host names its own file
   (uut-read p)                        ; -> (1 records) | () for no file to read
    (: r (uread p)
       b (pbase p)
       (? (atom? r) ()
          (: s <>r
             k (? (4 <= #b && snip b 0 4 = "utx.") [197 uut-fbsd]
                  (usub? "tmpx" b) [520 uut-nbsd]
                  [384 uut-glibc])
             (go i acc) (? (#s < i + <k) [1 (rev acc)] (go (i + <k) ((<>k s i) . acc)))
             (go 0 ()))))
   (usub? x s) (: n #x (go i) (? (#s < i + n) () (snip s i (i + n) = x) 1 (go (i + 1))) (go 0))
   (uut-file _)                        ; the first the host keeps, else the one it would
    (: (go l) (? (atom? >l) <l (two? (stat <l)) <l (go >l))
       (go '("/var/run/utx.active" "/var/run/utmpx" "/run/utmp" "/var/run/utmp")))
   ; a user process is one with a name, and in the live file one whose pid is still
   ; there (GNU's check: a record a crashed session left behind is not a user)
   (uut-user? live u)
    ((u 0 = 7) && (0 < #(u 4)) && (!live || (u 1 <= 0) || !((still (u 1) 0) = 'esrch)))
   (uut-dev l) (? (0 < #l && l 0 = 47) l ("/dev/" + l))
   (uut-rdev l) (: st (stat (uut-dev l)) (? (two? st && 12 < #st) (st 12) -1))
   (uut-mine _)                        ; stdin's terminal as its device number, or -1
    (: st (stat 0) (? (two? st && 12 < #st && (st 2 & 61440) = 8192) (st 12) -1))
   (utrimr s) (: (go k) (? (0 < k && (s (k - 1) = 32)) (go (k - 1)) (snip s 0 k)) (go #s))
   (uwho-say c user st line tm idl pid cm ex)
    (say out (utrimr ((urpad 8 user) + (? (c 'mesg) (" " + string st) "")
                           + " " + urpad 12 line + " " + urpad 12 tm
                           + (? (c 'idle && !(c 'short)) (" " + urpad 6 idl) "")
                           + (? (c 'short) "" (" " + upad 10 pid))
                           + " " + urpad 8 cm
                           + (? (c 'ext) (" " + urpad 12 ex) ""))), put out 10)
   (uwho-tm u) (udatef "%b %e %H:%M" (u 6 * 1000))
   ; an idle clock as hh:mm
   (u-hhmm s) (zpad 2 (show (s // 3600)) + ":" + zpad 2 (show (s % 3600 // 60)))
   (uwho-idle when boot now)
    (: d (now - when)
       (? (boot < when && when <= now && d < 86400)
          (? (d < 60) "  .  " (u-hhmm d))
          " old "))
   (uwho-user c u boot now)
    (: st (stat (uut-dev (u 2)))
       ok (two? st && 9 < #st)
       idl (? ok (uwho-idle (st 9 // 1000000000) boot now) "  ?")
       (uwho-say c (u 4) (? !ok 63 (0 < (st 2 & 16)) 43 45) (u 2) (uwho-tm u) idl
                 (show (u 1)) (? (0 < #(u 5)) ("(" + u 5 + ")") "") ""))
   (uwho-id u) ("id=" + u 3)
   (uwho-one c u boot now)
    (: ty <u
       (? (c 'users && uut-user? (c 'live) u) (uwho-user c u boot now)
          ((c 'run) && ty = 1)
           (: lst (u 1 // 256) cur (u 1 % 256)
              (uwho-say c "" 32 ("run-level " + string cur) (uwho-tm u) "" ""
                        (? (32 < lst && lst < 127) ("last=" + string (? (lst = 78) 83 lst)) "") ""))
          ((c 'boot) && ty = 2) (uwho-say c "" 32 "system boot" (uwho-tm u) "" "" "" "")
          ((c 'clock) && ty = 4) (uwho-say c "" 32 "clock change" (uwho-tm u) "" "" "" "")
          ((c 'init) && ty = 5) (uwho-say c "" 32 (u 2) (uwho-tm u) "" (show (u 1)) (uwho-id u) "")
          ((c 'login) && ty = 6) (uwho-say c "LOGIN" 32 (u 2) (uwho-tm u) "" (show (u 1)) (uwho-id u) "")
          ((c 'dead) && ty = 8)
           (uwho-say c "" 32 (u 2) (uwho-tm u) "" (show (u 1)) (uwho-id u)
                     ("term=" + show (u 7) + " exit=" + show (u 8)))
          0))
   (uwho-opts as t)                    ; -> the operands
    (: longs {"all" 97 "boot" 98 "dead" 100 "heading" 72 "login" 108 "lookup" 0 "mesg" 84
              "message" 84 "writable" 84 "process" 112 "count" 113 "runlevel" 114 "short" 115
              "time" 116 "users" 117}
       (go a ops)
        (? (atom? a) (rev ops)
           (: w <a n #w
              (? (w = "--") (rev ops + >a)
                 (n < 2 || !(w 0 = 45)) (go >a (w . ops))
                 (w 1 = 45)
                  (: k (longs (snip w 2 n))
                     (? (charm? k) (pin t k 1, go >a ops)
                        (udie 1 ("who: unrecognized option '" + w + "'\nTry 'who --help' for more information."))))
                 (: (cl j) (? (n <= j) (go >a ops)
                              (: c (w j)
                                 (? (elem c [97 98 100 72 108 109 112 113 114 115 116 84 117 119])
                                    (pin t (? (c = 119) 84 c) 1, cl (j + 1))
                                    (udie 1 ("who: invalid option -- '" + string c + "'\nTry 'who --help' for more information.")))))
                    (cl 1)))))
       (go as ()))
   (who-main as)
    (: t (tablet 0)
       o (uwho-opts as t)
       _ (? (2 < #o) (udie 1 ("who: extra operand '" + o 2 + "'\nTry 'who --help' for more information.")) 0)
       (f? k) (peep t k 0)
       all (f? 97)
       asm (all || f? 98 || f? 100 || f? 108 || f? 112 || f? 114 || f? 116 || f? 117)
       ext (all || f? 100)
       c {'mesg (all || f? 84) 'idle (all || f? 117 || f? 100 || f? 108) 'ext ext
          'short ((!asm || f? 115) && !ext) 'users (!asm || all || f? 117)
          'run (all || f? 114) 'boot (all || f? 98) 'clock (all || f? 116)
          'init (all || f? 112) 'login (all || f? 108) 'dead ext 'live (#o = 0)}
       fl (? (#o = 1) <o (uut-file 0))
       r (uut-read fl)
       _ (? r 0 (udie 1 ("who: " + fl + ": No such file or directory")))
       us (filter (uut-user? (#o = 0)) <>r)
       (? (f? 113)
          (say out (ujoin (map (u \ u 4) us) + "\n# users=" + show #us + "\n"), flush out, 0)
          (: _ (? (f? 72) (uwho-say c "NAME" 32 "LINE" "TIME" "IDLE" "PID" "COMMENT" "EXIT") 0)
             me (? (#o = 2 || f? 109) (uut-mine 0) ())
             now (clock 0 // 1000)
             _ (foldl (\ boot u
                       ((? (!(charm? me) || (0 <= me && uut-rdev (u 2) = me))
                               (uwho-one c u boot now) 0), (? (<u = 2) (u 6) boot)))
                      0 <>r)
             _ (flush out) 0)))

   ; -- pinky: GNU's lightweight finger over the same utmp -- the short table (-f no
   ; head, -w no name, -i no name nor where, -q not idle either), or -l's long form of
   ; the named users off /etc/passwd (-b no home nor shell, -h no .project, -p no .plan) --
   (upw-row nm)                         ; the passwd row -> its seven fields | ()
    (: r (uread "/etc/passwd")
       hit (? (two? r) (filter (l \ (: f (usplit 58 l) (two? f && <f = nm))) (lines <>r)) ())
       (? (two? hit) (usplit 58 <hit) ()))
   (upw-real row)                       ; the gecos up to its comma, & the capitalized login
    (: g (row 4) k (findsub g ",") g2 (? (k < 0) g (snip g 0 k))
       nm <row ncap (? (#nm && 96 < nm 0 && nm 0 < 123) (string (nm 0 - 32) + snip nm 1 #nm) nm)
       (go i) (? (#g2 <= i) "" (g2 i = 38) (ncap + go (i + 1)) (string (g2 i) + go (i + 1)))
       (go 0))
   (pinky-idle s)
    (? (s < 60) "     " (s < 86400) (u-hhmm s)
       (show (s // 86400) + "d"))
   (pinky-main as)
    (: (usage m) (udie 1 ("pinky: " + m + "\nTry 'pinky --help' for more information."))
       (go a o)
        (? (atom? a) o
           (: w <a n #w
              (? (w = "--") (pin o 'us (o 'us + >a), o)
                 (2 < n && snip w 0 2 = "--") (usage ("unrecognized option '" + w + "'"))
                 (1 < n && w 0 = 45)
                  (map (c \ (? (elem c "slbhpfwiq") (pin o c 1) (usage ("invalid option -- '" + string c + "'"))))
                            (map w (drop 1 ^n)), go >a o)
                 (pin o 'us (o 'us + [w]), go >a o))))
       o (go as {'us ()})
       us (o 'us)
       (f? c) (peep o c 0)
       (? (f? 108)
          (? (atom? us) (usage "no username specified; at least one must be specified when using -l")
             (map (nm \
                        (: row (upw-row nm)
                           (? (atom? row) (say out ("Login name: " + urpad 28 nm + "In real life:  ???\n"))
                              (: _ (say out ("Login name: " + urpad 28 nm + "In real life:  " + upw-real row + "\n"))
                                 _ (? (f? 98) 0 (say out ("Directory: " + urpad 29 (row 5) + "Shell:  " + row 6 + "\n")))
                                 (dot f what) (: r (uread (row 5 + "/" + f)) (? (two? r) (say out (what + <>r)) 0))
                                 _ (? (f? 104) 0 (dot ".project" "Project: "))
                                 _ (? (f? 112) 0 (dot ".plan" "Plan:\n"))
                                 (say out "\n")))))
                       us, flush out, 0))
          (: full !(f? 119 || f? 105 || f? 113)
             where !(f? 105 || f? 113)
             idle !(f? 113)
             _ (? (f? 102) 0
                  (say out ((urpad 8 "Login") + (? full (" " + urpad 19 "Name") "") + " " + urpad 9 " TTY"
                            + (? idle (" " + urpad 6 "Idle") "") + " " + urpad 12 "When" + (? where " Where" "") + "\n")))
             r (uut-read (uut-file 0))
             now (clock 0 // 1000)
             _ (map (u \
                         (? (!(u 0 = 7) || !(#(u 4)) || (two? us && nelem (u 4) us)) 0
                            (: st (stat (uut-dev (u 2)))
                               ok (two? st && 9 < #st)
                               row (upw-row (u 4))
                               _ (say out ((urpad 8 (u 4))
                                           + (? full (? (two? row) (" " + urpad 19 (: t (upw-real row) (? (19 < #t) (snip t 0 19) t)))
                                                        (" " + upad 19 "        ???")) "")
                                           + " " + string (? !ok 63 (0 < (st 2 & 16)) 32 42) + urpad 8 (u 2)
                                           + (? idle (" " + urpad 6 (? ok (pinky-idle (now - st 9 // 1000000000)) "???")) "")
                                           + " " + uwho-tm u
                                           + (? (where && #(u 5)) (" " + u 5) "") + "\n"))
                               0)))
                    (? (two? r) <>r ()))
             _ (flush out) 0)))

   ; -- usleep: a pause in microseconds (to the millisecond, which is the clock's grain) --
   (usleep-main as)
    (: _ (? (two? as && atom? >as) 0 (udie 1 "usage: usleep MICROSECONDS"))
       v (unum <as)
       _ (? (charm? v && 0 <= v) (rest ((v + 999) // 1000)) (udie 1 ("usleep: invalid number '" + <as + "'")))
       0)

   ; -- reset: the terminal put back -- the line discipline sane where stdin is one, and
   ; the full reset (RIS) sent, toybox's pair --
   (reset-main _)
    ((? (two? (tty 0)) (stty-main ["sane"]) 0), say out "\ec", flush out, 0)

   ; -- ts: each line of the input stamped as it arrives, toybox's: the date and time
   ; ("%b %d %H:%M:%S"), or with -s the time since the start and with -i since the line
   ; before ("%H:%M:%S"); -m adds the milliseconds; a FORMAT is strftime's. UTC, as every
   ; clock here is --
   (ts-main as)
    (: (go a o) (? (atom? a) o
                   (1 < #<a && <a 0 = 45)
                    (: w <a _ (map (c \ (? (elem c "ism") (pin o c 1) (udie 1 ("ts: Unknown option '" + string c + "' (see \"ts --help\")"))))
                                   (map w (drop 1 ^#w)))
                       (go >a o))
                   (pin o 'fmt <a, go >a o))
       o (go as {})
       rel (peep o 115 0) inc (peep o 105 0)
       fmt (? (o 'fmt) (o 'fmt) (rel || inc) "%H:%M:%S" "%b %d %H:%M:%S")
       t0 (clock 0)
       rd (urd in)
       (stamp ms) (udatef fmt ms + (? (peep o 109 0) ("." + zpad 3 (show (ms % 1000))) ""))
       (loop last)
        (: l (urd-line rd)
           (? (atom? l) (flush out, 0)
              (: now (clock 0)
                 _ (say out (stamp (? rel (now - t0) inc (now - last) now) + " " + <l + (? <>l "\n" "")))
                 _ (flush out)
                 (loop now))))
       (loop t0))

   ; -- users: the names logged in, sorted, on one line --
   (users-main as)
    (: _ (? (1 < #as) (udie 1 ("users: extra operand '" + as 1 + "'")) 0)
       fl (? (two? as) <as (uut-file 0))
       r (uut-read fl)
       _ (? r 0 (udie 1 ("users: " + fl + ": No such file or directory")))
       ns (sort (map (u \ u 4) (filter (uut-user? (atom? as)) <>r)))
       _ (? (two? ns) (say out (ujoin ns), put out 10) 0)
       _ (flush out) 0)

   ; -- logname: the name this session logged in as. linux keeps it with the process
   ; (/proc/self/loginuid); else the utmp record holding stdin's terminal says it --
   (logname-main as)
    (: _ (? (two? as) (udie 1 ("logname: extra operand '" + <as + "'")) 0)
       lu (u-1line "/proc/self/loginuid" "")
       id (? (0 < #lu) (uatoi lu) -1)
       pw (? (0 <= id && id < 4294967295) (uidname "/etc/passwd" id) "")
       me (uut-mine 0)
       r (? (0 < #pw && !(pw = show id)) () (0 <= me) (uut-read (uut-file 0)) ())
       (hit l) (? (atom? l) "" ((<l 0 = 7) && uut-rdev (<l 2) = me) (<l 4) (hit >l))
       nm (? r (hit <>r) pw)
       _ (? (0 < #nm && !(nm = show id)) 0 (udie 1 "logname: no login name"))
       _ (say out nm) _ (put out 10) _ (flush out) 0)

   ; -- the four by-name tools. a name is matched against the comm, which is what the
   ; kernel keeps and is capped at fifteen charms -- `pgrep -f` asks the cmdline
   ; instead, where the whole of a long program name lives --
   (upmatch f? x? pat pid)             ; does this process answer to pat
    (: c (? f? (upcmd pid) (: s (upstat pid) (? s (s 1) ())))
       (? !(string? c) 0
          x? (c = pat)
          (: r (reere pat) (? (two? r) (rehas <>r c) (udie 2 ("bad pattern: " + pat))))))
   (upfind f? x? pat)                  ; the pids answering, ours never among them
    (: me (: s (upself 0) (? s <s -1))
       (filter (p \ (? (p = me) 0 (upmatch f? x? pat p))) (uprocs 0)))
   (pidof-main as)
    (: fs (filter (\ w !((0 < tally w) && (w 0) = 45)) as)
       _ (? (two? fs) () (udie 1 "usage: pidof NAME.."))
       me (: s (upself 0) (? s <s -1))
       (hit p) (: s (upstat p)
                  c (? s (s 1) ())
                  a (: x (upcmd p) (? (string? x) (pbase <(usplit 32 x)) ()))
                  (? (p = me) 0
                     (foldl (\ acc w (? acc 1 (? (c = w || a = w) 1 0))) 0 fs)))
       ps (filter hit (rev (uprocs 0)))
       _ (? (two? ps) (say out (ujoin (map show ps)), put out 10) 0)
       _ (flush out)
       (? (two? ps) 0 1))
   (pgrep-main as)
    (: t (tablet 0)
       o (uopt as t () '(101) ())
       _ (? (two? o) () (udie 2 "usage: pgrep [-f] [-x] PATTERN"))
       _ (: c (uoptun t "fx") (? !c () (udie 2 ("pgrep: unknown option -" + string c))))
       rest <>>o
       _ (? (two? rest) () (udie 2 "usage: pgrep [-f] [-x] PATTERN"))
       ps (upfind (peep t 102 0) (peep t 120 0) <rest)
       _ (foldl (\ _ p (say out (show p), put out 10)) 0 ps)
       _ (flush out)
       (? (two? ps) 0 1))
   (pkill-main as)
    (: sig (? (two? as) (usignum <as) ())
       rest (? (charm? sig) >as as)
       t (tablet 0)
       o (uopt rest t () '(101) ())
       _ (? (two? o) () (udie 2 "usage: pkill [-SIG] [-f] [-x] PATTERN"))
       _ (: c (uoptun t "fx") (? !c () (udie 2 ("pkill: unknown option -" + string c))))
       ws <>>o
       _ (? (two? ws) () (udie 2 "usage: pkill [-SIG] [-f] [-x] PATTERN"))
       ps (upfind (peep t 102 0) (peep t 120 0) <ws)
       _ (foldl (\ _ p (still p (? (charm? sig) sig 15))) 0 ps)
       (? (two? ps) 0 1))
   (killall-main as)
    (: sig (? (two? as) (usignum <as) ())
       ns (? (charm? sig) >as as)
       _ (? (two? ns) () (udie 1 "usage: killall [-SIG] NAME.."))
       me (: s (upself 0) (? s <s -1))
       (one nm ok)
        (: ps (filter (p \ (? (p = me) 0 (: s (upstat p) (? s ((s 1) = nm) 0)))) (uprocs 0))
           (? (two? ps)
              (foldl (\ _ p (still p (? (charm? sig) sig 15))) 0 ps, ok)
              (say err (nm + ": no process found"), put err 10, 0)))
       ok (foldl (\ a nm (one nm a)) 1 ns)
       _ (flush err)
       (? ok 0 1))
   ; -- pwdx: where a process is standing, out of /proc/PID/cwd --
   (pwdx-main as)
    (: _ (? (two? as) () (udie 1 "usage: pwdx PID.."))
       (one w ok)
        (: d (readlink (("/proc/" + w) + "/cwd"))
           (? (string? d) (say out ((w + ": ") + d), put out 10, ok)
              (say err (w + ": No such process"), put err 10, 0)))
       ok (foldl (\ a w (one w a)) 1 as)
       _ (flush out) (? ok 0 1))

   ; -- xargs: stdin's words onto the command's tail (echo when none). words split on
   ; blanks and newlines, '..' "..." and \ quoting as GNU's; -0 and -d C split on a NUL or
   ; C instead, quotes plain. -n N words a run, -L N lines a run, -I S one run a line
   ; with S replaced in the command's words; -r runs nothing on no input, -t says each
   ; run on stderr, -P N keeps N going at once (0 as many as there are). exits 0 clean,
   ; 123 when a run failed, 127 when one could not exec. the command's own flags follow
   ; it, so the walk stops at the command's name --
   (xwords s)
    (: n #s
       (go i q w acc)
        (? (n <= i) (rev (? (string? w) (w . acc) acc))
           (: c (s i) w0 (? (string? w) w "")
              (? (0 < q) (? (c = q) (go (i + 1) 0 w acc) (go (i + 1) q (w + string c) acc))
                 (c = 39 || c = 34) (go (i + 1) c w0 acc)
                 (c = 92 && i + 1 < n) (go (i + 2) 0 (w0 + string (s (i + 1))) acc)
                 (c = 32 || c = 9 || c = 10) (go (i + 1) 0 () (? (string? w) (w . acc) acc))
                 (go (i + 1) 0 (w0 + string c) acc))))
       (go 0 0 () ()))
   (xargs-main as)
    (: t (tablet 0)
       o (uopt as t '(100 73 76 110 80) () ())
       _ (? (two? o) () (udie 1 "xargs: an option wants a value"))
       _ (: c (uoptun t "0dILnPrt") (? !c () (udie 1 ("xargs: unknown option -" + string c))))
       (num c lo) (: v (uoptv t c) n (? v (unum v) ())
                     (? (!v || (charm? n && lo <= n)) n (udie 1 ("xargs: invalid number for -" + string c + ": " + v))))
       nn (num 110 1) ll (num 76 1) pp (: v (num 80 0) (? (charm? v) (? (v = 0) 1073741824 v) 1))
       rs (uoptv t 73)
       dl (: v (uoptv t 100)
             (? !v () (v = "\\n") 10 (v = "\\t") 9 (v = "\\0") 0 (v = "\\\\") 92 (#v = 1) (v 0)
                (udie 1 ("xargs: invalid delimiter: " + v))))
       cmd (? (two? (o 2)) (o 2) '("echo"))
       txt (slurp in)
       (cut c) (: ps (usplit c txt) (? (two? ps && <(rev ps) = "") (rev >(rev ps)) ps))
       (inked l) (filter (x \ 0 < #x) (map lstrip l))   ; -I and -L read lines, blanks led off
       (chunks k l) (? (atom? l) () (take k l . chunks k (drop k l)))
       (batch ws) (? (atom? ws) () (map (w \ cmd + w) (? nn (chunks nn ws) [ws])))
       runs (? (t 48) (batch (cut 0))
               dl (batch (cut dl))
               rs (map (x \ map (a \ replace a rs x) cmd) (inked (lines txt)))
               ll (map (ls \ cmd + cats (map xwords ls)) (chunks ll (inked (lines txt))))
               (batch (xwords txt)))
       ; no input still runs once, as GNU's, unless -r or -I
       runs2 (? (two? runs) runs (t 114 || rs) () [cmd])
       (upd bad w) (? (w = 127) 127 (w && !(bad = 127)) 123 bad)
       (go rs live bad)
        (? (atom? rs) (foldl (\ b p (upd b (wait p))) bad live)
           (pp <= #live) (go rs >live (upd bad (wait <live)))
           (: argv <rs
              _ (? (t 116) (say err (ujoinc 32 argv + "\n"), flush err) 0)
              _ (flush out)
              p (spawn argv)
              (? (nom? p) (: _ (say err ("xargs: failed to run command '" + <argv + "': No such file or directory\n")) (go >rs live 127))
                 (go >rs (live + [p]) bad))))
       (: r (go runs2 () 0) _ (flush out) r))

   ; -- time: what a command costs. real off the wall clock; user and sys out of the
   ; rusage the kernel keeps for reaped children, read on both sides of the spawn --
   ; the child is the only one reaped in between, so the difference is its own. the
   ; three lines go to err, after the command's own output, and the status answered is
   ; the command's (127 for one that would not start). one face, posix's: -p is the
   ; spelling for it and not a switch, there being no second format to choose.
   ; a kernel with no rusage row (netbsd, and inle) reports the real line and dashes the
   ; other two, rather than call a pair of zeroes a measurement.
   (utsec us)                          ; microseconds -> seconds, two places
    (: cs ((us + 5000) // 10000)
       ((show (cs // 100)) + "." + (zpad 2 (show (cs % 100)))))
   (utline nm v) (say err (nm + " " + v), put err 10)
   (time-main as)
    (: cmd (? (two? as && <as = "-p") >as as)
       _ (? (two? cmd) () (udie 2 "usage: time [-p] CMD [ARG..]"))
       r0 (rusage -1)
       t0 (clock 0)
       p (spawn cmd)
       st (? (nom? p) 127 (wait p))
       ms (clock t0)
       r1 (rusage -1)
       cpu? (two? r0 && two? r1)
       _ (? (nom? p) (say err ("time: cannot run " + <cmd), put err 10) ())
       _ (flush out)
       _ (utline "real" (utsec (ms * 1000)))
       _ (? cpu? (utline "user" (utsec (<r1 - <r0)), utline "sys" (utsec (<>r1 - <>r0)))
            (utline "user" "-", utline "sys" "-"))
       st))
) ; module 'kore
