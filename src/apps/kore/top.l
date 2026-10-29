; src/apps/kore/top.l -- top: the process table, repainted, in two faces over one sample: the
; plain face, procps' own (-P, and -b's batch), and the rich face, htop-shaped, the default.
; %cpu is a delta: the first frame shows each process's since-boot average, later frames the
; ticks since the previous one (so `top -bn1` reads high, as procps' does).
; the keyboard is polled: `swig` reads with O_NONBLOCK, so no key reads 0.
; a row is a list by field: 0 pid (a tid under H), 1 user, 2 PR, 3 NI, 4 VIRT KiB,
; 5 RES KiB, 6 SHR KiB, 7 state, 8 %CPU tenths, 9 %MEM tenths, 10 ticks, 11 command,
; 12 ppid, 13 threads, 14 kernel thread, 15 tgid, 16 uid. the sort key is that index,
; and the first twelve are the columns in order.
(module 'kore
(borrow 'cli)
(borrow 'posix)
(borrow 'text)

(:
   tp-usage "usage: top [-b] [-P] [-C] [-n FRAMES] [-d SECS] [-p PID].."
   ; USER_HZ is 100 everywhere Linux runs a userland we could be in, which is the
   ; same assumption proc.l's uclk/uhms already make.
   tp-hz 100
   tp-pgkb 4                           ; a page in KiB
   tp-swig (cite 'posix 'swig)

   ; ---- the numbers, as columns of text ---------------------------------------
   (tp-d1 n)                           ; tenths -> "n.d"
    (show (n // 10) + "." + show (n % 10))
   ; a KiB count in seven columns: six digits and procps' letter. a width is a
   ; promise the header made, and a terabyte of virtual address space is real.
   tp-sfx ["" "m" "g" "t" "p"]
   (tp-kb k)
    (: (go v i) (v < 1000000 || #tp-sfx - 1 <= i ? (show v + tp-sfx i)
                 (go (v // 1024) (i + 1)))
       (go k 0))
   (tp-time tk)                        ; ticks -> procps' TIME+, mm:ss.hh
    (tk // tp-hz @ s
       (show (s // 60) + ":" + zpad 2 (show (s % 60))
                        + "." + zpad 2 (show (tk % tp-hz))))

   ; ---- the samples -------------------------------------------------------------
   ; /proc/stat's cpu lines without their names, the sum first and then cpu0 onward:
   ; user nice system idle iowait irq softirq steal, and whatever the kernel adds.
   (tp-cpus _)
    (: r (uread "/proc/stat")
       (cpu? l) (3 <= #l && snip l 0 3 = "cpu")
       (atom? r ? ()
        (filter two? (map (l \ (words l @ w (#w < 5 ? () (map uatoi >w))))
                          (filter cpu? (lines <>r))))))
   (tp-at l i) (i < #l ? (l i) 0)            ; a field the kernel did not print reads 0
   (tp-sum l) (foldl (\ a v (a + v)) 0 l)
   ; /proc/PID/statm's third number, the resident pages a process shares. a second
   ; read per process, which is what the SHR column costs and all that it costs.
   (tp-shr base)
    (uread (base + "/statm") @ r
       (atom? r ? 0 (words <>r @ w (2 < #w ? (uatoi (w 2)) 0))))
   ; a uid's name, read out of the passwd file once per uid and kept in `un`
   (tp-uname un uid)
    (peep un uid () @ v
       (string? v ? v (uidname "/etc/passwd" uid @ n
                         (pin un uid n, n))))

   ; one process or thread -> a row, or () when it went away between the readdir and the
   ; read. `last` is the previous frame's ticks by id, `ms` the milliseconds since; with no
   ; previous sample the process's own age stands in (the since-boot average)
   (tp-rowat base id tgid last ms up memkb cmd? un)   ; `up` in ticks, starttime's scale
    (: r (uread (base + "/stat"))
       f (two? r ? (ustatf <>r))
       (!f ? ()
          (: tk (uatoi (tp-at f 13) + uatoi (tp-at f 14))
             was (last id)
             ; a process born since the last sample is measured over the same interval
             age (charm? was || 0 < ms ? ms ((up - uatoi (tp-at f 21)) * (1000 // tp-hz) @ a
                                                (0 < a ? a 1)))
             d (charm? was ? (tk - was) tk)
             pc (age < 1 ? 0 ((d < 0 ? 0 d) * 10000 // age @ v (v < 0 ? 0 v)))
             res (uatoi (tp-at f 23) * tp-pgkb)
             nm (cmd? ? (upcmd tgid @ c (string? c ? c (tp-at f 1))) (tp-at f 1))
             uid (upuid tgid)
             [id (tp-uname un uid) (tp-at f 17) (tp-at f 18)
              (uatoi (tp-at f 22) // 1024)                 ; VIRT, bytes to KiB
              res (tp-shr base * tp-pgkb) (tp-at f 2) pc
              (memkb < 1 ? 0 (res * 1000 // memkb))
              tk nm
              (uatoi (tp-at f 3)) (uatoi (tp-at f 19))
              (uatoi (tp-at f 8) & 2097152 ? 1 0)        ; PF_KTHREAD
              tgid uid])))
   (tp-row pid last ms up memkb cmd? un) (tp-rowat ("/proc/" + show pid) pid pid last ms up memkb cmd? un)
   ; a process's threads but its leader, by tid
   (tp-tids p)
    (readdir ("/proc/" + show p + "/task") @ r
       (two? r ? (filter (t \ (t != p)) (sort (map uatoi (filter udigs? r))))))

   ; the rows, and the tablet of ticks the next frame subtracts. thr? adds each
   ; process's other threads as rows of their own, after the processes.
   (tp-sample last ms up memkb cmd? pids thr? un)
    (: ps (two? pids ? pids (uprocs 0))
       rs (filter two? (map (p \ (tp-row p last ms up memkb cmd? un)) ps))
       (thr r) (r 13 < 2 || r 14 ? ()
                (<r @ p
                   (filter two? (map (t \ (tp-rowat ("/proc/" + show p + "/task/" + show t) t p
                                                   last ms up memkb cmd? un))
                                     (tp-tids p)))))
       ts (thr? ? (foldl (\ a r (cat a (thr r))) () rs))
       all (cat rs ts)
       nxt (foldl (\ t r (pin t <r (r 10))) {} all)
       [all nxt])

   ; one sample into the state tablet st: the rows, the memory, the cpu lines now and
   ; the ones before. the sampling is the mutation, so a sample is not to be taken twice.
   (tp-take st)
    (: now (clock 0)
       was (peep st 'at 0)
       ms (now - was @ d (0 < was && 0 < d ? d 0))
       mi (umeminfo 0)
       cl (tp-cpus 0)
       q (tp-sample (peep st 'last {}) ms (uupticks 0) (peep mi 'MemTotal 0) (peep st 'cmd 0)
                    (st 'pids) (peep st 'thr 0) (st 'un))
       (pins st 'last <>q 'at now 'rows <q 'mi mi 'cpuw (st 'cpul) 'cpul cl))

   ; ---- the order ---------------------------------------------------------------
   ; every key falls back to the pid, so equal rows never trade places between repaints.
   ; names climb and numbers fall, as both tops have it; inv turns it over
   (tp-key c r) (c @ (2 || 3) (uatoi (r c)) (r c))
   (tp-sort c inv rs)
    (: up (elem c [0 1 7 11])
       asc (inv ? !up up)
       (sortby (\ x y (: a (tp-key c x) b (tp-key c y)
                         (? (a = b) (<x <= <y) asc (a < b) (b < a)))) rs))

   ; ---- the plain frame ---------------------------------------------------------
   (tp-tasks rs)                       ; the state census the second header line is
    (: (cnt c) (#(filter (r \ (r 7 = c)) rs))
       (p3 n) (upad 3 (show n))
       (show #rs + " total, " + p3 (cnt "R") + " running, "
        + p3 (cnt "S" + cnt "D" + cnt "I") + " sleeping, "
        + p3 (cnt "T" + cnt "t") + " stopped, " + p3 (cnt "Z") + " zombie"))
   ; the difference between two reads of one cpu line, the first eight fields; with no
   ; previous read there is no difference, so the first frame is the average since boot.
   (tp-cpud now was)
    (two? was ? (map (i \ (tp-at now i - tp-at was i)) (jot 8))
     (map (i \ (tp-at now i)) (jot 8)))
   (tp-cpuline now was)
    (: d (tp-cpud now was)
       tot (tp-sum (map (x \ (x < 0 ? 0 x)) d) @ v (0 < v ? v 1))
       (pc i) (upad 5 (tp-d1 (tp-at d i * 1000 // tot)))
       ("%Cpu(s): " + pc 0 + " us, " + pc 2 + " sy, " + pc 1 + " ni, "
                    + pc 3 + " id, " + pc 4 + " wa, " + pc 5 + " hi, "
                    + pc 6 + " si, " + pc 7 + " st"))
   (tp-mem mi)
    (: g (k \ (peep mi k 0))
       tot (g 'MemTotal) free (g 'MemFree) av (g 'MemAvailable)
       bc (g 'Buffers + g 'Cached + g 'SReclaimable)
       st (g 'SwapTotal) sf (g 'SwapFree)
       (m1 k) (upad 9 (tp-d1 (k * 10 // 1024)))
       [("MiB Mem : " + m1 tot + " total, " + m1 free + " free, "
                      + m1 (tot - free - bc) + " used, " + m1 bc + " buff/cache")
        ("MiB Swap: " + m1 st + " total, " + m1 sf + " free, "
                      + m1 (st - sf) + " used. " + m1 av + " avail Mem")])
   tp-head "    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND"
   (tp-line r w)
    (scut (upad 7 (show <r) + " " + urpad 8 (scut (r 1) 8)
             + " " + upad 3 (r 2) + " " + upad 3 (r 3)
             + " " + upad 7 (tp-kb (r 4)) + " " + upad 6 (tp-kb (r 5))
             + " " + upad 6 (tp-kb (r 6)) + " " + r 7
             + " " + upad 5 (tp-d1 (r 8)) + " " + upad 5 (tp-d1 (r 9))
             + " " + upad 9 (tp-time (r 10)) + " " + r 11) w)
   (tp-join ls) (foldl (\ a s (a + s + "\n")) "" ls)
   (tp-cpu0 l) (two? l ? <l)

   ; one plain frame over the state tablet st: a sample, then its text
   (tp-frame st w h)
    (: _ (tp-take st)
       now (st 'at)
       rs (tp-sort (peep st 'sort 8) (peep st 'inv 0) (st 'rows))
       hd [("top - " + uclk (now // 1000 % 86400) + " up " + uupsay (uupsecs 0)
                     + ",  load average: " + uloadav 0)
           ("Tasks: " + tp-tasks rs)
           (tp-cpuline (tp-cpu0 (st 'cpul)) (tp-cpu0 (st 'cpuw)))]
       top (hd + tp-mem (st 'mi) + ["" tp-head])
       room (h - #top @ n (0 < n ? n 0))
       body (map (r \ (tp-line r w)) (h < 1 ? rs (snip rs 0 room)))
       (tp-join (map (s \ (scut s w)) top) + tp-join body))

   ; ---- the plain face ----------------------------------------------------------
   ; batch: no terminal is wanted and none is asked for, every process is shown, and
   ; the frames are separated by a blank line the way procps separates them.
   (tp-batch st n d w)
    (: (go k first)
        (first ? () (put out 10),
         say out (tp-frame st w 0),
         flush out,
         (0 < n && n <= k ? 0
          (rest d, go (k + 1) 0)))
       (go 1 1))
   ; the screen: repaint, then poll the keyboard in short naps until the delay is spent.
   ; a key is one byte; an escape sequence's bytes mean nothing here
   tp-nap 60
   (tp-keys st b)
    (tp-swig in b @ n
       (!(charm? n) ? 0
          (: ks (snip b 0 n)
             (go i acc) (n <= i ? acc
                         (ks i @ c
                            (? (c = 113 || c = 81) 1                  ; q Q
                               (c = 99) (pin st 'cmd !(peep st 'cmd 0), acc)
                               (c = 80 || c = 77 || c = 84 || c = 78)
                                (pin st 'sort (c @ 80 8 77 9 84 10 0), go (i + 1) 2)
                               (c = 32 || c = 114) (go (i + 1) 2)     ; space r
                               (go (i + 1) acc))))
             (go 0 0))))
   (tp-ride st n d)
    (: b (cask 64)
       e (string 27)
       (paint _) (ttysize 0 0 @ g (puts (e + "[H" + e + "[2J" + tp-frame st (g 1) <g), flush out))
       ; the wait: naps until the delay is spent, cut short by a key that asks for
       ; a repaint. 1 quits, 2 repaints now, 0 carries on waiting.
       (wait left) (tp-keys st b @ k
                      (? (k = 1) 1
                         (k = 2) 0
                         (left < 1) 0
                         (rest tp-nap, wait (left - tp-nap))))
       (go k) (paint 0,
               (0 < n && n <= k ? 0
                (wait d ? 0 (go (k + 1)))))
       (ttytake (), mind go 1 (_ \ ttygive ())))

   ; ---- the rich face ------------------------------------------------------------
   ; an engine and a seat, as less.l is: tr-step takes one key into the state tablet and
   ; answers what the seat owes (0 nothing, 1 quit, 2 a repaint, 3 a fresh sample), tr-draw
   ; answers one whole frame for w by h, and tr-ride alone touches the terminal. every line is
   ; padded to the width, so nothing is erased behind a glyph that raised a pending wrap.
   tr-swig (cite 'posix 'swig)
   tr-e (string 27)

   ; ---- text by the column ------------------------------------------------------
   (tr-sp n) (n < 1 ? "" (string (map (_ \ 32) (jot n))))
   (tr-fit s w) (: c (scut s w) m (swidth c) (m < w ? (c + tr-sp (w - m)) c))

   ; ---- pens --------------------------------------------------------------------
   ; a pen is a name; 256-colour SGR, or under -C the few that reverse or embolden
   tr-pal {'txt "" 'hdr "30;48;5;71" 'hsort "30;48;5;37" 'sel "30;48;5;37" 'lbl "38;5;37"
           'num "1" 'dim "38;5;244" 'thr "38;5;71" 'kth "38;5;244" 'run "1;38;5;71"
           'dsk "1;38;5;167" 'mb "38;5;37" 'gb "38;5;71" 'tree "38;5;37" 'fkey ""
           'flbl "30;48;5;37" 'prompt "30;48;5;178" 'mhdr "30;48;5;71" 'msel "30;48;5;37"
           'msg "38;5;178" 'miss "38;5;167"}
   tr-mono {'hdr "7" 'hsort "1;4;7" 'sel "7" 'num "1" 'run "1" 'dsk "1" 'flbl "7"
            'prompt "7" 'mhdr "7" 'msel "7"}
   (tr-pen st p) (peep (st 'mono ? tr-mono tr-pal) p "" @ c "\(tr-e)[0\(0 < #c ? ";\(c)" "")m")
   ; [[pen text] ..] -> exactly w columns, the text cut to fit, the last pen padding
   (tr-segs st segs w)
    (: (go l left acc)
        (atom? l ? (acc + tr-sp left)
         (: s <l c (scut (s 1) left)
            (go >l (left - swidth c) (acc + tr-pen st (s 0) + c))))
       (go segs w ""))

   ; ---- bars --------------------------------------------------------------------
   ; segs [[fraction colour] ..] in w cells. in colour a cell is the segment over its left
   ; edge, cut to the eighth where that segment ends and the next one showing behind it;
   ; under -C it is a run of | and the segments are one
   tr-eighth ["" "▏" "▎" "▍" "▌" "▋" "▊" "▉"]
   tr-track 236
   (tr-bar st segs w)
    (st 'mono ?
        (: f (foldl (\ a s (a + s 0)) 0 segs)
           k (max 0 (min w (int (f * w + 0.5))))
           (string (map (_ \ 124) ^k) + tr-sp (w - k)))
       (: u (w * 8)
          ends (: (go l a acc) (atom? l ? (rev acc)
                                (a + l 0 0 @ a2 (go >l a2 ([(max 0 (min u (int (a2 * u + 0.5)))) (l 0 1)] . acc))))
                  (go segs 0 ()))
          (seg s) (: (go l) (? (atom? l) [u tr-track] (s < l 0 0) (l 0) (go >l)) (go ends))
          (cell i) (: s (8 * i) g (seg s) e (g 0 - s)
                      (? (g 1 = tr-track) [" " 0 tr-track]
                         (8 <= e) ["█" (g 1) tr-track]
                         [(tr-eighth e) (g 1) (seg (s + e) 1)]))
          (go i last acc)
           (w <= i ? acc
            (: c (cell i) fb [(c 1) (c 2)]
             (go (i + 1) fb (acc + (fb @ ^last "" "\(tr-e)[38;5;\(c 1);48;5;\(c 2)m") + c 0))))
          (go 0 () "")))

   ; ---- sizes -------------------------------------------------------------------
   (tr-hum kb)                         ; KiB -> 812M, 11.2G
    (? (kb < 1024) "\(kb)K"
       (kb < 1048576) "\(kb // 1024)M"
       "\(tp-d1 $ kb * 10 // 1048576)G")
   (tr-upt s) (s // 86400 @ d
                 ((0 < d ? (show d + (d @ 1 " day, " " days, ")) "") + uclk (s % 86400)))
   (tr-load _) (: l (uread "/proc/loadavg") ws (two? l ? (words <>l))
                  (2 < #ws ? "\(ws 0) \(ws 1) \(ws 2)" "0.00 0.00 0.00"))

   ; ---- the meters --------------------------------------------------------------
   ; a meter: its label, the bar, and a figure, lw + 1 + bar + 1 + tw columns
   (tr-meter st lbl lw segs text tw w)
    (: m (st 'mono) bw (max 1 (w - lw - tw - 2))
       (tr-pen st 'lbl + upad lw lbl + tr-pen st 'txt + (m ? "[" " ") + tr-bar st segs bw
        + tr-pen st 'txt + (m ? "]" " ") + tr-pen st 'num + upad tw text + tr-pen st 'txt))
   (tr-cpum st i now was lw w)
    (: d (map (x \ max 0 x) (tp-cpud now was))
       tot (tp-sum d @ v (0 < v ? v 1))
       sy (d 2 + d 5 + d 6 + d 7)
       busy (d 0 + d 1 + sy)
       (tr-meter st (i < 0 ? "CPU" (show i)) lw
                 [[(d 0 / tot) 71] [(d 1 / tot) 33] [(sy / tot) 167] [(d 4 / tot) 244]]
                 (tp-d1 (busy * 1000 // tot) + "%") 6 w))
   (tr-memm st mi w)
    (: g (k \ (peep mi k 0))
       tot (max 1 (g 'MemTotal)) free (g 'MemFree) buf (g 'Buffers)
       cac (g 'Cached + g 'SReclaimable)
       used (max 0 (tot - free - buf - cac))
       (tr-meter st "Mem" 3 [[(used / tot) 71] [(buf / tot) 33] [(cac / tot) 178]]
                 "\(tr-hum used)/\(tr-hum tot)" 13 w))
   (tr-swapm st mi w)
    (: g (k \ (peep mi k 0))
       tot (g 'SwapTotal) used (max 0 (tot - g 'SwapFree))
       (tr-meter st "Swp" 3 [[(used / max 1 tot) 167]] (tr-hum used + "/" + tr-hum tot) 13 w))
   ; the cpus in cols columns, each filled downward before the next
   (tr-cpus st w)
    (: cl (st 'cpul) cw (st 'cpuw)
       per (two? cl && two? >cl ? >cl)
       was (two? cw && two? >cw ? >cw)
       one? (atom? per)
       ms (one? ? (two? cl ? [[-1 <cl (tp-cpu0 cw)]]) (map (i \ [i (per i) (tp-at was i)]) (jot #per)))
       n #ms
       cols (? (n <= 4 || w < 60) 1 (n <= 16 || w < 120) 2 4)
       rows ((n + cols - 1) // cols)
       cwid ((w - 2 * (cols - 1)) // cols)
       lw (one? ? 3 #(show (n - 1)))
       (at r c) (c * rows + r @ i
                   (i < n ? (ms i @ m (tr-cpum st (m 0) (m 1) (m 2) lw cwid)) (tr-sp cwid)))
       (line r) (foldl (\ a c (a + (0 < c ? "  " "") + at r c)) "" (jot cols) @ s
                   (s + tr-pen st 'txt + tr-sp (w - (cols * cwid + 2 * (cols - 1)))))
       (map line (jot rows)))
   ; Mem and Swp on the left, the census, the load and the uptime on the right
   (tr-info st w)
    (: lw ((w - 2) // 2) rw (w - 2 - lw)
       mi (st 'mi) rs (st 'rows)
       ps (filter (r \ <r = r 15) rs)
       kt (#(filter (r \ r 14) ps))
       thr (tp-sum (map (r \ r 14 ? 0 (r 13)) ps))
       run (#(filter (r \ r 7 = "R") ps))
       right [[['lbl "Tasks: "] ['num (show #ps)] ['txt ", "] ['thr (show thr)] ['txt " thr, "]
               ['kth (show kt)] ['txt " kthr; "] ['run (show run)] ['txt " running"]]
              [['lbl "Load average: "] ['num (tr-load 0)]]
              [['lbl "Uptime: "] ['num (tr-upt (uupsecs 0))]]]
       left [(tr-memm st mi lw) (tr-swapm st mi lw) (tr-pen st 'txt + tr-sp lw)]
       (map (i \ left i + tr-pen st 'txt + "  " + tr-segs st (right i) rw) ^3))

   ; ---- the list ----------------------------------------------------------------
   ; name, width, left-aligned; a column's index is its row field
   tr-cols [["PID" 7 0] ["USER" 8 1] ["PR" 3 0] ["NI" 3 0] ["VIRT" 7 0] ["RES" 6 0] ["SHR" 6 0]
            ["S" 1 0] ["%CPU" 5 0] ["%MEM" 5 0] ["TIME+" 9 0] ["Command" 0 1]]
   ; the column under x, counting each one's leading space as its own
   (tr-colat x) (: (go l i a) (atom? >l ? i
                               (a + l 0 1 + (0 < i ? 1 0) @ e (x < e ? i (go >l (i + 1) e))))
                   (go tr-cols 0 0))
   (tr-head st)
    (map (i \ (: c (tr-cols i) t (c 2 ? (urpad (c 1) (c 0)) (upad (c 1) (c 0)))
                 [(st 'sort @ ^i 'hsort 'hdr) ((0 < i ? " " "") + t)]))
         (jot 12))
   (tr-kpen k b) ((0 < #k ? (k (#k - 1)) 0) @ z (? (z = 109) 'mb (z = 103 || z = 116 || z = 112) 'gb b))
   (tr-row st r pre sel?)
    (: b (? sel? 'sel (<r != r 15) 'thr (r 14) 'kth 'txt)
       (p x) (sel? ? 'sel x)
       [[b (upad 7 (show <r))] [b (" " + urpad 8 (scut (r 1) 8))] [b (" " + upad 3 (r 2))]
        [b (" " + upad 3 (r 3))]
        [b " "] [(p (tr-kpen (tp-kb (r 4)) b)) (upad 7 (tp-kb (r 4)))]
        [b " "] [(p (tr-kpen (tp-kb (r 5)) b)) (upad 6 (tp-kb (r 5)))]
        [b " "] [(p (tr-kpen (tp-kb (r 6)) b)) (upad 6 (tp-kb (r 6)))]
        [b " "] [(p (r 7 @ "R" 'run "D" 'dsk b)) (r 7)]
        [b (" " + upad 5 (tp-d1 (r 8)))] [b (" " + upad 5 (tp-d1 (r 9)))]
        [b (" " + upad 9 (tp-time (r 10)))] [b " "] [(p 'tree) pre] [b (r 11)]])

   ; the rows on show: the user and the filter, then the order, then the tree
   (tr-view st)
    (: u (st 'user)
       f (lower (peep st 'filt ""))
       hk (peep st 'hidek 0)
       (ok r) ((string? u ? (r 1 = u) 1) && (0 < #f ? (has? (lower (r 11)) f) 1) && !(hk && r 14))
       ss (tp-sort (st 'sort) (st 'inv) (filter ok (st 'rows)))
       (st 'tree ? (tr-tree ss) (map (r \ [r ""]) ss)))
   ; a thread hangs under its process, a process under its parent, and a row whose parent
   ; is not on show is a root. siblings keep the order they were handed in
   (tr-tree ss)
    (: ids (foldl (\ t r (pin t <r 1)) {} ss)
       (par r) (<r != r 15 ? (r 15) (r 12))
       kids (foldl (\ t r (par r @ p (pin t p (r . (t p))))) {} (rev ss))
       (walk r pre ind acc)
        (: (go l a) (atom? l ? a
                     (atom? >l @ last
                        (go >l (walk <l (ind + (last ? "└─ " "├─ ")) (ind + (last ? "   " "│  ")) a))))
           (go (kids <r) ([r pre] . acc)))
       (rev (foldl (\ a r (peep ids (par r) 0 ? a (walk r "" "" a))) () ss)))
   (tr-find vs id) (: (go l i) (? (atom? l) () (l 0 0 0 = id) i (go >l (i + 1))) (charm? id ? (go vs 0)))
   (tr-clamp i n) (? (n <= i) (n - 1) (i < 0) 0 i)
   ; the selection: its pid where it can be found and following is on, else its row.
   ; until a row is picked it is the top one, so a first frame's averages do not hold it
   (tr-settle st nb)
    (: vs (tr-view st) nv #vs
       f (st 'follow && st 'picked ? (tr-find vs (st 'sel)))
       si (max 0 (charm? f ? f (tr-clamp (peep st 'si 0) nv)))
       t0 (peep st 'top 0)
       t1 (? (si < t0) si (t0 + nb <= si) (si - nb + 1) t0)
       top (max 0 (min t1 (nv - nb)))
       (pins st 'view vs 'si si 'top top 'sel (si < nv ? <(vs si 0))))

   ; ---- menus -------------------------------------------------------------------
   tr-pw 18
   (tr-menu st kind title items at)
    (pins st 'mode 'menu 'menu (pins {} 'kind kind 'title title 'items items 'at (max 0 at)), 2)
   (tr-index l x) (: (go l i) (? (atom? l) 0 (l 0 1 = x) i (go >l (i + 1))) (go l 0))
   (tr-sigs _) (sortby (\ a b (a 1 <= b 1)) usignames)
   (tr-killmenu st)
    (map (s \ [(upad 3 (show (s 1)) + " SIG" + s 0) (s 1)]) (tr-sigs 0) @ its
       (tr-menu st 'kill "Send signal:" its (tr-index its 15)))
   (tr-sortmenu st)
    (map (i \ [(tr-cols i 0) i]) (jot 12) @ its
       (tr-menu st 'sort "Sort by:" its (st 'sort)))
   (tr-usermenu st)
    (: ns (sort (map (r \ r 1) (st 'rows)))
       us (rev (foldl (\ a x (two? a && <a = x ? a (x . a))) () ns))
       its (["All users" ()] . (map (u \ [u u]) us))
       (tr-menu st 'user "Show user:" its (tr-index its (st 'user))))
   (tr-mtop st nb) (: at (st 'menu 'at) vis (nb - 1) (at < vis ? 0 (at - vis + 1)))
   (tr-mline st i nb)
    (: mu (st 'menu) its (mu 'items) j (tr-mtop st nb + i - 1)
       (? (i = 0) [['mhdr (mu 'title)]]
          (j < #its) [[(j = mu 'at ? 'msel 'txt) (its j 0)]]
          [['txt ""]]))

   ; ---- acting on the selection -------------------------------------------------
   ; only ever the selected pid, and only when the list had one
   (tr-kill st sig)
    (st 'sel @ id
       (!(charm? id) ? (pin st 'msg "no process selected")
          (still id sig @ e
             (pin st 'msg (!e ? ("sent signal " + show sig + " to " + show id)
                             ("kill " + show id + ": " + (nom? e ? (uerrno e) "failed")))))))
   (tr-nice st dn)
    (st 'sel @ id
       (!(charm? id) ? (pin st 'msg "no process selected")
          (: o (prio 0 id)
             e (nom? o ? o (setprio 0 id (o + dn)))
             (pin st 'msg (!e ? ("nice " + show (o + dn) + " for " + show id)
                             ("renice " + show id + ": " + (nom? e ? (uerrno e) "failed")))))))

   ; ---- keys --------------------------------------------------------------------
   ; the bytes of one read -> keys: a byte as itself, a named key as a symbol, a mouse
   ; report as ['mouse button x y press?], 0-based. a sequence it does not know is 0
   (tr-keys b)
    (: n #b
       (at i) (i < n ? (b i) -1)
       (csi i ps cur) (at i @ c
                         (? (48 <= c <= 57) (csi (i + 1) ps (cur * 10 + c - 48))
                            (c = 59) (csi (i + 1) (cur . ps) 0)
                            [(rev (cur . ps)) c (i + 1)]))
       (tilde p) (p @ (1 || 7) 'home (4 || 8) 'end 5 'pgup 6 'pgdn 11 'f1 12 'f2 13 'f3 14 'f4
                      15 'f5 17 'f6 18 'f7 19 'f8 20 'f9 21 'f10 0)
       (fin c) (c @ 65 'up 66 'down 67 'right 68 'left 72 'home 70 'end 80 'f1 81 'f2 82 'f3 83 'f4 0)
       (go i acc)
        (n <= i ? (rev acc)
         (at i @ c
            (? (c != 27) (go (i + 1) (c . acc))
               (n <= i + 1) (rev ('esc . acc))
               (at (i + 1) = 79) (go (i + 3) ((fin (at (i + 2))) . acc))
               (at (i + 1) != 91) (go (i + 1) ('esc . acc))
               (at (i + 2) = 60)
                (: q (csi (i + 3) () 0) ps (q 0)
                   (go (q 2) (['mouse (tp-at ps 0) (tp-at ps 1 - 1) (tp-at ps 2 - 1) (q 1 = 77)] . acc)))
               (at (i + 2) = 91)
                (go (i + 4) ((at (i + 3) @ 65 'f1 66 'f2 67 'f3 68 'f4 69 'f5 0) . acc))
               (csi (i + 2) () 0 @ q
                  (go (q 2) ((q 1 = 126 ? (tilde <(q 0)) (fin (q 1))) . acc))))))
       (go 0 ()))

   (tr-page st) (max 1 (peep st 'nb 10))
   (tr-to st i)
    (: vs (st 'view) nv #vs si (tr-clamp i nv)
       (pins st 'si (max 0 si) 'picked 1 'sel (0 <= si && si < nv ? <(vs si 0)), 2))
   (tr-move st d) (tr-to st (peep st 'si 0 + d))
   (tr-flip st k) (pin st k !(peep st k 0), 2)
   ; the next row from `from` on, around the end, whose command holds the search
   (tr-seek st from)
    (: vs (st 'view) nv #vs t (lower (peep st 'srch ""))
       (go j) (nv <= j ? () ((from + j) % nv @ i (has? (lower (vs i 0 11)) t ? i (go (j + 1)))))
       i (0 < nv && 0 < #t ? (go 0))
       (charm? i ? (pin st 'miss 0, tr-to st i) (pin st 'miss (0 < #t), 2)))
   ; a line being typed: the search or the filter
   (tr-typed st m k)
    (: f (m = 'search ? 'srch 'filt)
       s (peep st f "")
       (put1 v) (pin st f v, m = 'search ? (tr-seek st (peep st 'si 0)) 2)
       (? (k = 'esc) (m = 'filter ? (pin st 'filt "") 0, pin st 'mode (), 2)
          (k = 13 || k = 10) (pin st 'mode (), 2)
          (k = 127 || k = 8) (put1 (0 < #s ? (snip s 0 (#s - 1)) s))
          (k = 'f3 && m = 'search) (tr-seek st (peep st 'si 0 + 1))
          (charm? k && 32 <= k < 127) (put1 (s + string k))
          0))
   (tr-act st)
    (: mu (st 'menu) v (mu 'items (mu 'at) 1) kd (mu 'kind)
       (pin st 'mode (),
        (? (kd = 'kill) (tr-kill st v, 3)
           (kd = 'sort) (pins st 'sort v 'inv 0, 2)
           (pin st 'user v, 2))))
   (tr-mto st i) (st 'menu @ mu (pin mu 'at (tr-clamp i #(mu 'items)), 2))
   (tr-menukey st k)
    (: at (st 'menu 'at) pg (tr-page st)
       (two? k ? (tr-mouse st k)
        (k @ ('up || 107) (tr-mto st (at - 1))
             ('down || 106) (tr-mto st (at + 1))
             'pgup (tr-mto st (at - pg)) 'pgdn (tr-mto st (at + pg))
             'home (tr-mto st 0) 'end (tr-mto st 9999)
             (13 || 10) (tr-act st)
             ('esc || 113 || 'f10 || 'f9 || 'f6) (pin st 'mode (), 2)
             0)))
   tr-fkeys [["F1" "Help" 'f1] ["F3" "Search" 'f3] ["F4" "Filter" 'f4] ["F5" "Tree" 'f5]
             ["F6" "SortBy" 'f6] ["F7" "Nice -" 'f7] ["F8" "Nice +" 'f8] ["F9" "Kill" 'f9]
             ["F10" "Quit" 'f10]]
   (tr-fkat x) (: (go l a) (atom? l ? 0
                            (a + #(l 0 0) + 6 @ e (x < e ? (l 0 2) (go >l e))))
                  (go tr-fkeys 0))
   (tr-mouse st k)
    (: b (k 1) x (k 2) y (k 3) y0 (peep st 'y0 0) nb (peep st 'nb 0)
       menu? (st 'mode = 'menu)
       (? !(k 4) 0
          (b & 64) (menu? ? (tr-mto st (st 'menu 'at + (b & 1 ? 3 -3)))
                      (tr-move st (b & 1 ? 3 -3)))
          (b & 3 != 0) 0
          (y = y0 - 1 && !menu?)
           (tr-colat x @ c (c = st 'sort ? (tr-flip st 'inv) (pins st 'sort c 'inv 0, 2)))
          (y0 <= y && y < y0 + nb)
           (? (menu? && x < tr-pw)
               (y = y0 ? 0 (tr-mto st (tr-mtop st nb + y - y0 - 1), tr-act st))
              menu? 0
              (peep st 'top 0 + y - y0 @ i (i < #(st 'view) ? (tr-to st i) 0)))
          (y = peep st 'h 0 - 1 && !menu?) (tr-key st (tr-fkat x))
          0))
   (tr-key st k)
    (two? k ? (tr-mouse st k)
     (k @ (113 || 81 || 3 || 'f10) 1
          'up (tr-move st -1)
          ('down || 106) (tr-move st 1)
          'pgup (tr-move st (0 - tr-page st))
          'pgdn (tr-move st (tr-page st))
          'home (tr-to st 0)
          'end (tr-to st 999999)
          (116 || 'f5) (tr-flip st 'tree)
          72 (tr-flip st 'thr, 3)                        ; H
          70 (tr-flip st 'follow)                        ; F
          75 (tr-flip st 'hidek)                         ; K
          99 (tr-flip st 'cmd, 3)                        ; c
          (80 || 77 || 84 || 78) (pins st 'sort (k @ 80 8 77 9 84 10 0) 'inv 0, 2)
          73 (tr-flip st 'inv)                           ; I
          ('f6 || 60 || 62) (tr-sortmenu st)             ; < >
          (47 || 'f3) (pins st 'mode 'search 'srch "" 'miss 0, 2)
          110 (tr-seek st (peep st 'si 0 + 1))           ; n
          (92 || 'f4) (pins st 'mode 'filter, 2)
          117 (tr-usermenu st)                           ; u
          (107 || 'f9) (tr-killmenu st)                  ; k
          (91 || 'f7) (tr-nice st -1, 3)                 ; [
          (93 || 'f8) (tr-nice st 1, 3)                  ; ]
          (104 || 63 || 'f1) (pin st 'mode 'help, 2)     ; h ?
          (32 || 114) 3                                  ; space r: a sample now
          12 2                                           ; ^L
          0))
   ; one key into the state -> 0 nothing, 1 quit, 2 repaint, 3 sample and repaint
   (tr-step st k)
    (st 'mode @ m
       (k @ 0 0 (pin st 'msg ""),
        m @ ('search || 'filter) (tr-typed st m k)
         'menu (tr-menukey st k)
         'help (two? k && !(k 4) ? 0 (pin st 'mode (), 2))
         (tr-key st k)))

   ; ---- the frame ---------------------------------------------------------------
   tr-help ["top: the rich face; -P is the plain one, -C drops the colour"
            ""
            " arrows j PgUp PgDn Home End   walk the list; a click selects a row"
            " F                follow the selected pid (on) or keep its row"
            " t F5             the tree, parents over children"
            " F6 < >           the sort picker; a click on a column sorts by it"
            " P M T N          sort by cpu, memory, time, pid;  I  turn the order over"
            " / F3  n          search the commands, and the next match"
            " \\ F4             filter the commands;  u  one user's processes"
            " k F9             send the selected process a signal (TERM first)"
            " F7 [  F8 ]       its nice down (root only) and up"
            " H                threads;  K  hide kernel threads;  c  the command line"
            " space r          a sample now;  q F10  quit"
            ""
            " bars: user, nice, system, iowait; memory used, buffers, cache"
            ""
            " any key goes back"]
   (tr-bottom st w)
    (: m (st 'mode) msg (peep st 'msg "")
       (m @ 'search (tr-segs st [['prompt "Search: "] ['txt (peep st 'srch "")]
                                 [(st 'miss ? 'miss 'txt) (st 'miss ? "   not found" "")]
                                 ['txt "   Enter done  Esc back  F3 next"]] w)
           'filter (tr-segs st [['prompt "Filter: "] ['txt (peep st 'filt "")]
                                ['txt "   Enter keep  Esc clear"]] w)
          (tr-segs st (cat (foldl (\ a f (cat a [['fkey (f 0)] ['flbl (urpad 6 (f 1))]])) () tr-fkeys)
                           [['txt "  "] ['msg msg]]) w)))
   (tr-at y) "\(tr-e)[\(y + 1);1H"
   (tr-draw st w h)
    (: hd (cat (tr-cpus st w) (tr-info st w))
       hy #hd
       nb (max 1 (h - hy - 2))
       _ (pins st 'y0 (hy + 1) 'nb nb 'h h)
       _ (tr-settle st nb)
       vs (st 'view) top (st 'top) si (st 'si) m (st 'mode)
       pw (m = 'menu ? tr-pw 0)
       lw (w - pw)
       notes (cat (string? (st 'user) ? [" user \(st 'user)"])
                  (0 < #(peep st 'filt "") ? [" filter \(st 'filt)"]))
       chead (tr-segs st (cat (0 < pw ? [['mhdr (tr-fit " " pw)]])
                              (cat (tr-head st) [['hdr (cats notes)]])) w)
       (body i) (: j (top + i)
                      row (j < #vs ? (vs j @ v (tr-row st (v 0) (v 1) (j = si))) [['txt ""]])
                      ((0 < pw ? (tr-segs st (tr-mline st i nb) pw) "") + tr-segs st row lw))
       ; the help takes the whole screen over the key bar
       (help i) (tr-segs st [[(i = 0 ? 'hdr 'txt) (i < #tr-help ? (tr-help i) "")]] w)
       ls (cat (m = 'help ? (map help (jot (h - 1))) (cat hd (cat [chead] (map body (jot nb)))))
               [(tr-bottom st w)])
       (foldl (\ a i (a + tr-at i + ls i + tr-pen st 'txt)) (tr-e + "[0m") (jot (min h #ls))))

   ; ---- the seat ----------------------------------------------------------------
   ; repaint on a sample, on a key that asks, and on a new size; poll between. the
   ; first wait is short, so the second frame's %CPU is a difference and not an average
   (tr-ride st n d)
    (: b (cask 512)
       (paint g) (puts (tr-draw st (g 1) (g 0)), flush out)
       (keys _) (tr-swig in b @ k (charm? k && 0 < k ? (tr-keys (snip b 0 k))))
       (wait left g)
        (: r (foldl (\ a k (tr-step st k @ v (a = 1 || v = 1 ? 1 (max a v)))) 0 (keys 0))
           g2 (ttysize 0 0)
           (? (r = 1) 1
              (r = 3) 0
              (r = 2 || g2 != g) (paint g2, wait left g2)
              (left < 1) 0
              (rest tp-nap, wait (left - tp-nap) g2)))
       (go k) (ttysize 0 0 @ g
                 (tp-take st,
                  paint g,
                  (? (0 < n && n <= k) 0
                     (wait (k = 1 ? (min d 700) d) g) 0
                     (go (k + 1)))))
       (ttytake ['hide 'mouse], mind go 1 (_ \ ttygive ['hide 'mouse])))

   ; ---- the door ----------------------------------------------------------------
   (top-main as)
    (: t {}
       o (uopt as t '(110 100 112) '(112) ())       ; -n -d -p take values, -p repeats
       _ (two? o ? () (udie 2 tp-usage))
       _ (uoptbad as t "bndpPC" @ c (!c ? () (udie 2 ("top: unknown option -- " + string c))))
       b? (peep t 98 0)
       plain? (peep t 80 0)
       n (uoptv t 110 @ v (string? v ? (unum v @ k (charm? k ? k (udie 2 tp-usage))) 0))
       dv (uoptv t 100)
       d (string? dv ? (udur dv @ k (charm? k && 0 < k ? k (udie 2 tp-usage))))
       pids (map uatoi <>o)                          ; -p stacks, so it rides `stacked`
       st {}
       _ (pins st 'sort 8 'inv 0 'cmd 0 'last {} 'at 0 'pids pids 'un {})
       ws (tty 1)
       ; no terminal is not a refusal: it is batch, which is what a pipe wants and
       ; what the gate reads. -b asks for the same face where there is a terminal.
       (? (b? || atom? ws) (tp-batch st (0 < n ? n 1) (d ? d 3000) (cite 'grid 'screen 1))
          plain? (tp-ride st n (d ? d 3000))
          (pins st 'cmd 1 'follow 1 'mono (peep t 67 0) 'mode () 'msg "",
           tr-ride st n (d ? d 1500)))))

) ; module 'kore
