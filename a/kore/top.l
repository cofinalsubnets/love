; a/kore/top.l -- top: the process table, repainted. a screen app and not a line
; tool, so it takes a file of its own the way the pager does; kore is still its door.
; the data floor is proc.l's (uprocs, upstat, umeminfo, uupsecs, uloadav) and the
; screen is less.l's shape -- raw, the alternate screen, and one whole frame built
; as a string and written once, because a frame drawn in pieces tears.
;
; %CPU IS A DELTA and cannot be read off one sample. the first frame shows each
; process's since-boot average over its own age; every frame after it shows the
; ticks burned since the previous one. that is procps' own behaviour and it is why
; `top -bn1` reads high -- the one-shot frame has no previous sample to subtract.
;
; the keyboard is polled, never parked on: `swig` sets O_NONBLOCK around its read
; and puts the flag back, so a raw tty answers 0 for "no key yet". the whole timer
; is that plus `rest`, and no nif grew for any of it.
;
; the columns are fixed and shared by every row, which is why this lays them by
; hand rather than through `grid`: grid packs interchangeable items into as many
; columns as fit, and a table is the other shape.
;
; keys: q quit, space or r repaint now, c the command line against the comm,
; P by cpu, M by memory, T by time, N by pid -- procps' own letters.
; flags: -b batch (no terminal wanted, every process, one frame per iteration),
; -n N stop after N frames, -d SECS the delay, -p PID one process (repeatable).
;
; absent and said so: the thread and forest views, per-cpu meters, the field
; editor, renice and kill from the keyboard, and colour.
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   ; USER_HZ is 100 everywhere Linux runs a userland we could be in, which is the
   ; same assumption proc.l's uclk/uhms already make.
   tp-hz 100
   tp-pgkb 4                           ; a page in KiB
   tp-swig (cite 'posix 'swig)
   tp-usage "usage: top [-b] [-n FRAMES] [-d SECS] [-p PID].."

   ; ---- the numbers, as columns of text ---------------------------------------
   (tp-d1 n)                           ; tenths -> "n.d"
    ((show (// n 10)) + "." + (show (% n 10)))
   ; a KiB count in seven columns: six digits and procps' letter. a width is a
   ; promise the header made, and a terabyte of virtual address space is real.
   tp-sfx ["" "m" "g" "t" "p"]
   (tp-kb k)
    (: (go v i) (? ((v < 1000000) || ((#tp-sfx - 1) <= i)) ((show v) + (tp-sfx i))
                   (go (v // 1024) (i + 1)))
       (go k 0))
   (tp-time tk)                        ; ticks -> procps' TIME+, mm:ss.hh
    (: s (// tk tp-hz)
       ((show (// s 60)) + ":" + (uzpad 2 (show (% s 60)))
                        + "." + (uzpad 2 (show (% tk tp-hz)))))
   (tp-cut s w) (? (w < #s) (snip s 0 w) s)

   ; ---- the samples -------------------------------------------------------------
   ; /proc/stat's first line without its name: user nice system idle iowait irq
   ; softirq steal, and whatever the kernel adds after them.
   (tp-cpu _)
    (: r (uread "/proc/stat")
       (? !(two? r) ()
          (: w (words <(lines <>r))
             (? (#w < 5) () (map uatoi >w)))))
   (tp-at l i) (? (i < #l) (l i) 0)            ; a field the kernel did not print reads 0
   (tp-sum l) (foldl (\ a v (a + v)) 0 l)
   ; /proc/PID/statm's third number, the resident pages a process shares. a second
   ; read per process, which is what the SHR column costs and all that it costs.
   (tp-shr pid)
    (: r (uread ("/proc/" + (show pid) + "/statm"))
       (? !(two? r) 0 (: w (words <>r) (? (2 < #w) (uatoi (w 2)) 0))))

   ; one process -> a row, or () when it went away between the readdir and the read.
   ; `last` is the previous frame's ticks by pid and `ms` the milliseconds since it;
   ; with no previous sample the process's own age stands in, which is the since-boot
   ; average and the only honest answer a first frame has.
   (tp-row pid last ms up memkb cmd?)   ; `up` in ticks, the scale starttime uses
    (: f (upstat pid)
       (? !f ()
          (: tk ((uatoi (tp-at f 13)) + (uatoi (tp-at f 14)))
             was (peep last pid ())
             age (? (charm? was) ms (: a ((up - (uatoi (tp-at f 21))) * (1000 // tp-hz))
                                        (? (0 < a) a 1)))
             d (? (charm? was) (tk - was) tk)
             pc (? (age < 1) 0 (: v ((? (d < 0) 0 d) * 10000 // age) (? (v < 0) 0 v)))
             res ((uatoi (tp-at f 23)) * tp-pgkb)
             nm (? cmd? (: c (upcmd pid) (? (string? c) c (tp-at f 1))) (tp-at f 1))
             [pid                                            ; 0  the key and the sort's tie
              (uidname "/etc/passwd" (upuid pid))            ; 1
              (tp-at f 17)                                   ; 2  PR, the kernel's own text
              (tp-at f 18)                                   ; 3  NI
              ((uatoi (tp-at f 22)) // 1024)                 ; 4  VIRT, bytes to KiB
              res                                            ; 5  RES
              ((tp-shr pid) * tp-pgkb)                       ; 6  SHR
              (tp-at f 2)                                    ; 7  S
              pc                                             ; 8  %CPU in tenths
              (? (memkb < 1) 0 (res * 1000 // memkb))        ; 9  %MEM in tenths
              tk                                             ; 10 ticks, for TIME+ and the sort
              nm])))                                         ; 11 COMMAND

   ; the rows, and the tablet of ticks the next frame subtracts
   (tp-sample last ms up memkb cmd? pids)
    (: ps (? (two? pids) pids (uprocs 0))
       rs (filter two? (map (\ p (tp-row p last ms up memkb cmd?)) ps))
       nxt (foldl (\ t r (pin t <r (r 10))) {} rs)
       [rs nxt])

   ; ---- the order ---------------------------------------------------------------
   ; every key falls back to the pid, so a frame never reshuffles equal rows under
   ; the reader's eye: two rows at 0.0% would otherwise trade places every repaint.
   ; N is the one order that climbs, so its key is the pid turned over
   (tp-key k r) (? (k = 77) (r 9) (k = 84) (r 10) (k = 78) (0 - <r) (r 8))
   (tp-sort k rs)
    (sortby (\ x y (: a (tp-key k x) b (tp-key k y)
                      (? (= a b) (<x <= <y) (b < a)))) rs)

   ; ---- the frame ---------------------------------------------------------------
   (tp-tasks rs)                       ; the state census the second header line is
    (: (cnt c) (#(filter (\ r ((r 7) = c)) rs))
       (p3 n) (upad 3 (show n))
       ((show #rs) + " total, " + (p3 (cnt "R")) + " running, "
        + (p3 ((cnt "S") + (cnt "D") + (cnt "I"))) + " sleeping, "
        + (p3 ((cnt "T") + (cnt "t"))) + " stopped, " + (p3 (cnt "Z")) + " zombie"))
   ; the cpu line, off the difference between two /proc/stat reads. with no previous
   ; read there is no difference, so the first frame is the average since boot.
   (tp-cpuline now was)
    (: d (? (two? was) (map (\ i ((tp-at now i) - (tp-at was i))) (jot 8))
              (map (\ i (tp-at now i)) (jot 8)))
       tot (: v (tp-sum (map (\ x (? (x < 0) 0 x)) d)) (? (0 < v) v 1))
       (pc i) (upad 5 (tp-d1 ((tp-at d i) * 1000 // tot)))
       ("%Cpu(s): " + (pc 0) + " us, " + (pc 2) + " sy, " + (pc 1) + " ni, "
                    + (pc 3) + " id, " + (pc 4) + " wa, " + (pc 5) + " hi, "
                    + (pc 6) + " si, " + (pc 7) + " st"))
   (tp-mem mi)
    (: g (\ k (peep mi k 0))
       tot (g 'MemTotal) free (g 'MemFree) av (g 'MemAvailable)
       bc ((g 'Buffers) + (g 'Cached) + (g 'SReclaimable))
       st (g 'SwapTotal) sf (g 'SwapFree)
       (m1 k) (upad 9 (tp-d1 (k * 10 // 1024)))
       [("MiB Mem : " + (m1 tot) + " total, " + (m1 free) + " free, "
                      + (m1 (tot - free - bc)) + " used, " + (m1 bc) + " buff/cache")
        ("MiB Swap: " + (m1 st) + " total, " + (m1 sf) + " free, "
                      + (m1 (st - sf)) + " used. " + (m1 av) + " avail Mem")])
   tp-head "    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND"
   (tp-line r w)
    (tp-cut ((upad 7 (show <r)) + " " + (urpad 8 (tp-cut (r 1) 8))
             + " " + (upad 3 (r 2)) + " " + (upad 3 (r 3))
             + " " + (upad 7 (tp-kb (r 4))) + " " + (upad 6 (tp-kb (r 5)))
             + " " + (upad 6 (tp-kb (r 6))) + " " + (r 7)
             + " " + (upad 5 (tp-d1 (r 8))) + " " + (upad 5 (tp-d1 (r 9)))
             + " " + (upad 9 (tp-time (r 10))) + " " + (r 11)) w)
   (tp-join ls) (foldl (\ a s (a + s + "\n")) "" ls)

   ; one frame over the state tablet st, which carries the previous sample. answers
   ; the text; the sampling is the mutation, so a frame is not to be built twice.
   (tp-frame st w h)
    (: now (clock 0)
       was (peep st 'at 0)
       ms (: d (now - was) (? (0 < was && 0 < d) d 0))
       mi (umeminfo 0)
       memkb (peep mi 'MemTotal 0)
       cpu (tp-cpu 0)
       q (tp-sample (peep st 'last {}) ms (uupticks 0) memkb (peep st 'cmd 0) (peep st 'pids ()))
       rs (tp-sort (peep st 'sort 80) <q)
       _ (pins st 'last <>q 'at now 'cpu0 cpu)
       hd [("top - " + (uclk (% (// now 1000) 86400)) + " up " + (uupsay (uupsecs 0))
                     + ",  load average: " + (uloadav 0))
           ("Tasks: " + (tp-tasks rs))
           (tp-cpuline cpu (peep st 'cpu ()))]
       _ (pin st 'cpu cpu)
       top (hd + (tp-mem mi) + ["" tp-head])
       room (: n (h - #top) (? (0 < n) n 0))
       body (map (\ r (tp-line r w)) (? (h < 1) rs (snip rs 0 room)))
       ((tp-join (map (\ s (tp-cut s w)) top)) + (tp-join body)))

   ; ---- the two faces -----------------------------------------------------------
   ; batch: no terminal is wanted and none is asked for, every process is shown, and
   ; the frames are separated by a blank line the way procps separates them.
   (tp-batch st n d w)
    (: (go k first)
        (: _ (? first () (put out 10))
           _ (say out (tp-frame st w 0))
           _ (flush out)
           (? ((0 < n) && (n <= k)) 0
              (: _ (rest d) (go (k + 1) 0))))
       (go 1 1))
   ; the screen: repaint, then poll the keyboard in short naps until the delay is
   ; spent. a key is read as one byte -- top's own keys are all single -- and an
   ; escape sequence arrives as its bytes, none of which mean anything here.
   tp-nap 60
   (tp-keys st b)
    (: n (tp-swig in b)
       (? !(charm? n) 0
          (: ks (snip b 0 n)
             (go i acc) (? (n <= i) acc
                           (: c (ks i)
                              (? ((c = 113) || (c = 81)) 1                  ; q Q
                                 (c = 99) (: _ (pin st 'cmd !(peep st 'cmd 0)) acc)
                                 ((c = 80) || (c = 77) || (c = 84) || (c = 78))
                                  (: _ (pin st 'sort c) (go (i + 1) 2))
                                 ((c = 32) || (c = 114)) (go (i + 1) 2)     ; space r
                                 (go (i + 1) acc))))
             (go 0 0))))
   (tp-ride st n d)
    (: b (cask 64)
       e (string 27)
       _ (raw 1)
       _ (puts (e + "[?1049h"))
       (fin _) (: _ (puts (e + "[0m" + e + "[?1049l")) _ (flush out) _ (raw 0) 0)
       (paint _) (: ws (tty 1)
                    h (? (two? ws && 0 < <ws) <ws 24)
                    w (? (two? ws && 0 < >ws) >ws 80)
                    _ (puts (e + "[H" + e + "[2J" + (tp-frame st w h)))
                    (flush out))
       ; the wait: naps until the delay is spent, cut short by a key that asks for
       ; a repaint. 1 quits, 2 repaints now, 0 carries on waiting.
       (wait left) (: k (tp-keys st b)
                      (? (k = 1) 1
                         (k = 2) 0
                         (left < 1) 0
                         (: _ (rest tp-nap) (wait (left - tp-nap)))))
       (go k) (: _ (paint 0)
                 (? ((0 < n) && (n <= k)) (fin 0)
                    (? (wait d) (fin 0) (go (k + 1)))))
       (go 1))

   (top-main as)
    (: t (tablet 0)
       o (uopt as t '(110 100 112) '(112) ())       ; -n -d -p take values, -p repeats
       _ (? (two? o) () (udie 2 tp-usage))
       _ (: c (uoptun t "bndp") (? (nil? c) () (udie 2 ("top: unknown option -- " + (string c)))))
       b? (peep t 98 0)
       n (: v (uoptv t 110) (? (string? v) (: k (unum v) (? (charm? k) k (udie 2 tp-usage))) 0))
       d (: v (uoptv t 100)
              (? (string? v) (: k (udur v) (? (charm? k && 0 < k) k (udie 2 tp-usage))) 3000))
       pids (map uatoi <>o)                          ; -p stacks, so it rides `stacked`
       st (tablet 0)
       _ (pins st 'sort 80 'cmd 0 'last {} 'at 0 'pids pids)
       ws (tty 1)
       ; no terminal is not a refusal: it is batch, which is what a pipe wants and
       ; what the gate reads. -b asks for the same face where there is a terminal.
       (? (b? || !(two? ws))
          (tp-batch st (? (0 < n) n 1) d ((cite 'grid 'screen) 1))
          (tp-ride st n d))))

) ; module 'kore
