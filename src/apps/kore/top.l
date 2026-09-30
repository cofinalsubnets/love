; src/apps/kore/top.l -- top: the process table, repainted. this file is the data floor both
; faces share and the plain face, procps' own; the rich face and top-main are htop.l's.
; the floor under this one is proc.l's (uprocs, ustatf, umeminfo, uupticks, uloadav).
;
; %cpu is a delta: the first frame shows each process's since-boot average, every frame
; after it the ticks since the previous one (so `top -bn1` reads high, as procps' does).
; the keyboard is polled: `swig` sets O_NONBLOCK around its read, so no key reads 0.
;
; a row is a list by field: 0 pid (a tid under H), 1 user, 2 PR, 3 NI, 4 VIRT KiB,
; 5 RES KiB, 6 SHR KiB, 7 state, 8 %CPU tenths, 9 %MEM tenths, 10 ticks, 11 command,
; 12 ppid, 13 threads, 14 kernel thread, 15 tgid, 16 uid. the sort key is that index,
; and the first twelve are the columns in order.
;
; the plain face: keys q quit, space or r repaint now, c the command line against the
; comm, P by cpu, M by memory, T by time, N by pid. -b is this face with no terminal,
; every process and one frame per iteration, and is what test/kore/top.sh reads.
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
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
   (tp-cut s w) (w < #s ? (snip s 0 w) s)

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
   (tp-dig? s) (: n #s (go k) (? (n <= k) (0 < n) (48 <= s k <= 57) (go (k + 1)) 0) (go 0))
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

   ; one process or thread -> a row, or () when it went away between the readdir and
   ; the read. `base` is its /proc directory, `tgid` the process it belongs to. `last`
   ; is the previous frame's ticks by id and `ms` the milliseconds since it; with no
   ; previous sample the process's own age stands in, which is the since-boot average
   ; and the only honest answer a first frame has.
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
       (two? r ? (filter (t \ (t != p)) (sort (map uatoi (filter tp-dig? r))))))

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
   ; every key falls back to the pid, so a frame never reshuffles equal rows under
   ; the reader's eye: two rows at 0.0% would otherwise trade places every repaint.
   ; the names climb and the numbers fall, as both tops have it; inv turns it over
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
    (tp-cut (upad 7 (show <r) + " " + urpad 8 (tp-cut (r 1) 8)
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
       (tp-join (map (s \ (tp-cut s w)) top) + tp-join body))

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
   ; the screen: repaint, then poll the keyboard in short naps until the delay is
   ; spent. a key is read as one byte -- the plain face's keys are all single -- and an
   ; escape sequence arrives as its bytes, none of which mean anything here.
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
       (paint _) (: ws (tty 1)
                    h (two? ws && 0 < <ws ? <ws 24)
                    w (two? ws && 0 < >ws ? >ws 80)
                    (puts (e + "[H" + e + "[2J" + tp-frame st w h),
                     flush out))
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
       (raw 1, puts (e + "[?1049h"),
        mind go 1 (_ \ (puts (e + "[0m" + e + "[?1049l"), flush out, raw 0)))))

) ; module 'kore
