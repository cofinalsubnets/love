; test/host/ed.l -- ed and ex on a terminal
; over a pty: ed's prompt, `?` and h; ex's autoprint and its vi, whose :wq ends both
;   cat test/00-init.l test/host/00-host.l test/host/ed.l | out/love
(borrow 'posix)
(: love <cmdline
   ; per pid, so two runs over one out/ keep apart
   dir ("out/.edtest-" + show (getpid 0))
   _ (mkdir dir 493)
   f (dir + "/t")
   _ (open f "w" @ q (say q "alpha\nbeta\ngamma\n", close q))
   ; what the pty shows up to pat, or all of it at its end
   (upto m pat t) (see m @ b (b < 0 ? t (t + string b @ t2 (has? t2 pat ? t2 (upto m pat t2)))))
   (type m s) (say m s, flush m)
   r (tether [love "ed" "-p" "* " f])
   _ (test (two? r))
   m >r
   a0 (upto m "* " "")
   _ (type m "2p\r")
   a1 (upto m "* " "")
   _ (type m "y\r")
   a2 (upto m "* " "")
   _ (type m "h\r")
   a3 (upto m "* " "")
   _ (type m "Q\r")
   _ (slurp m)
   s1 (h-waitfor <r)
   _ (test (has? a0 "17") (has? a1 "beta") (has? a2 "?") (has? a3 "unknown command") (<s1 = 0))
   r2 (tether [love "ex" f])
   _ (test (two? r2))
   n >r2
   b0 (upto n ":" "")
   _ (type n "1d\r")
   b1 (upto n ":" "")
   _ (type n "vi\r")
   b2 (upto n "\e[?1049h" "")
   _ (rest 300)
   _ (type n ":wq\r")
   b3 (slurp n)
   s2 (h-waitfor <r2)
   got (open f "r" @ q (hot? q ? (slurp q @ g (close q, g)) ""))
   (test (has? b0 "3L, 17B") (has? b1 "beta") (has? b2 "\e[?1049h") (has? b3 "\e[?1049l")
         (<s2 = 0) (got = "beta\ngamma\n"),
    hark ["rm" "-rf" dir]))
(test_fin (), puts "ed: ok", putc 10, 0)
