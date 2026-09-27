; --- test/host/ed.l: ed and ex on a terminal ---
; test/kore/ed.sh drives both as scripts; this is the other face, a pty: ed's prompt, an
; error that says `?` and lets the edit go on, h saying why; ex's prompt and autoprint,
; and its vi handing the buffer to the vi engine, whose :wq writes it and ends both.
;   cat test/00-init.l test/host/ed.l | out/love
(borrow 'posix)
(: love <cmdline
   dir "out/.edtest"
   _ (hark ["rm" "-rf" dir]) _ (mkdir dir 493)
   f (dir + "/t")
   _ (: q (open f "w") _ (say q "alpha\nbeta\ngamma\n") (close q))
   (sub? h n) (: (go i) (? (#h < i + #n) 0 (n = snip h i (i + #n)) 1 (go (i + 1))) (go 0))
   ; what the pty shows up to pat, or all of it at its end
   (upto m pat t) (: b (see m) (? (b < 0) t (: t2 (t + string b) (? (sub? t2 pat) t2 (upto m pat t2)))))
   (waitfor pid) (: s (gather pid) (? (two? s) s (nom? s) s (: _ (rest 2) (waitfor pid))))
   (type m s) (: _ (say m s) (flush m))
   r (tether [love "kore" "ed" "-p" "* " f])
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
   s1 (waitfor <r)
   _ (test (sub? a0 "17") (sub? a1 "beta") (sub? a2 "?") (sub? a3 "unknown command") (<s1 = 0))
   r2 (tether [love "kore" "ex" f])
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
   s2 (waitfor <r2)
   got (: q (open f "r") (? (hot? q) (: g (slurp q) _ (close q) g) ""))
   _ (test (sub? b0 "3L, 17B") (sub? b1 "beta") (sub? b2 "\e[?1049h") (sub? b3 "\e[?1049l")
           (<s2 = 0) (got = "beta\ngamma\n")))
(test_fin (), puts "ed: ok", putc 10, 0)
