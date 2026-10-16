; the pty nifs (src/love/posix.c). a master can EOF before its child is a zombie, so waitfor polls
; gather; exited is told by two?, never net: (0) nets to nothing. love0 can't run it twice, so no corpus
; run: cat test/00-init.l test/host/pty.l | out/love
(: (waitfor pid)
 (gather pid @ s (? (two? s) s (nom? s) s (rest 2, waitfor pid))))

(: r (tether ["echo" "hello"])
 _ (test
    (two? r)
    (charm? <r)
    (0 < <r)
    (lit? >r))
 out (slurp >r)
 _ (test
    (0 < #out))
 st (waitfor <r)
 _ (test
    (two? st)
    (0 = <st)
    (st = [0])))

; signal death
(: r (tether ["cat"])
 _ (test (two? r))
 _ (still <r 9)   ; a positive pid: the process, not the group
 _ (slurp >r)
 st (waitfor <r)
 _ (test
    (two? st)
    (137 = <st)))    ; 128 + 9

(tether ["cat"] @ r
 (test !(settty >r 24 80)
       ('ebadf = settty 5 24 80),
  still <r 9,
  slurp >r,
  waitfor <r))

; ttypg: a tethered child leads its own group; the echo back first, so it has taken the pty
(tether ["cat"] @ r
 (put >r 120, put >r 10, flush >r, see >r,
  test ((<r) = ttypg >r)
       (nom? (ttypg "x")),
  (pipe 0 @ pp (test (nom? (ttypg <pp)), close <pp, close >pp)),
  still <r 9,
  waitfor <r))

(: dead <(tether ["true"])
 (waitfor dead,   ; reaped, not a zombie
  test ('esrch = still dead 0)))

; a round trip over the master, read byte by byte: cat never EOFs
(: r (tether ["cat"])
 m >r
 _ (put m 110, put m 101, put m 107, put m 111, put m 10)
 _ (flush m)
 a (see m) b (see m) c (see m) d (see m)
 _ (test (a = 110) (b = 101) (c = 107) (d = 111))
 _ (still <r 9)
 _ (waitfor <r))

; ptyecho off: only tr's uppercase comes back, not the line discipline's echo
(: r (tether ["tr" "a-z" "A-Z"])
 m >r
 _ (test !(ptyecho m 0))
 _ (put m 104, put m 105, put m 10)
 _ (flush m)
 a (see m) b (see m)
 _ (test (a = 72) (b = 73))
 _ (still <r 9)
 _ (waitfor <r))
(: _ (test ('ebadf = ptyecho 5 0)))

(test_fin ())
(puts "pty: ok\n")

; edraw in one task, a pump on another port in a second: a parked task must see its buffered byte
; the keyboard pty has echo off, else ESC renders as `^[` and the arrow never decodes
(: edraw (cite 'cli 'edraw)
   (pump src dst) (see src @ -1 0 ch (put dst ch, flush dst, pump src dst))
   (feedlines ip m)
    (edraw ip "" @ line
       (!(two? line) ? (put m 4)
          (each line (put m),
           put m 10,
           flush m,
           feedlines ip m)))
   rk (tether ["cat"]) mk >rk
   rc (tether ["tr" "a-z" "A-Z"]) mc >rc
   _ (ptyecho mk 0, ptyecho mc 0)
   sink (jug 0)
   a (twirl (_ \ feedlines mk mc) 0)
   b (twirl (_ \ pump mc sink) 0)
   _ (each [97 98 27 91 68 88 10] (put mk))   ; ab, left, X, enter
   _ (flush mk)
   _ (rest 300)
   got (slurp sink)
   (still <rk 9, still <rc 9,
    (landed? a ? (catch a) (freeze a)),
    (landed? b ? (catch b) (freeze b)),
    test (string? got)
         (got = "AXB\r\n")))

