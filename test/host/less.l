; test/host/less.l -- the pager on a pty (the engine is lawed in test/law/kore.l)
; the pty is 0x0 until settty lands, so nothing here asks about geometry
; run: LOVEBIN=out/love LESSTESTDIR=out sh -c "cat test/00-init.l test/host/less.l | out/love"

(: love (getenv "LOVEBIN")
   dir (getenv "LESSTESTDIR")
   f (dir + "/pg.txt")
   _ (open f "w" @ q
      (say q "alpha\nbravo\ncharlie\ndelta\necho\nfoxtrot\ngolf\nhotel\nindia\njuliet\n",
       close q))
   (waitfor pid) (gather pid @ s (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid))))
   ; keys are typed before raw mode, so "\n" flushes the canonical line; "qq" so a
   ; failed quit or the help page can't park slurp forever
   (run keys args)
    (: r (tether (cat [love "kore" "less"] args))
       _ (test (two? r))
       m >r
       _ (settty m 10 40)
       _ (say m (keys + "qq\n"))
       txt (slurp m)
       st (waitfor <r)
       [txt <st])

   ; q leaves at once
   r1 (run "" [f])
   _ (test
      (<>r1 = 0)
      (has? <r1 "alpha")
      (has? <r1 "pg.txt")
      (has? <r1 "1-")
      (has? <r1 "\e[?1049h")
      (has? <r1 "\e[?1049l"))

   r2 (run "G" [f])
   _ (test (<>r2 = 0) (has? <r2 "juliet") (has? <r2 "(END)"))

   r3 (run "/india\n" [f])
   _ (test (<>r3 = 0) (has? <r3 "india"))
   r4 (run "h" [f])
   _ (test (<>r4 = 0) (has? <r4 "the pager") (has? <r4 "alpha"))

   r5 (run "" ["-N" f])
   _ (test (<>r5 = 0) (has? <r5 "1 alpha"))
   r6 (run "" ["+/golf" f])
   _ (test (<>r6 = 0) (has? <r6 "golf"))

   ; a name that will not open: status 1, no screen
   r7 (run "" [(dir + "/nope.txt")])
   _ (test (<>r7 = 1) !(has? <r7 "\e[?1049h"))

   g (dir + "/pg2.txt")
   _ (open g "w" @ q (say q "kilo\nlima\n", close q))
   r8 (run ":n" [f g])
   _ (test (<>r8 = 0) (has? <r8 "kilo") (has? <r8 "pg2.txt"))
   r9 (run ":n:p" [f g])
   _ (test (<>r9 = 0) (has? <r9 "alpha"))

   ; a pipe is the text and /dev/tty the keyboard
   ra (: r (tether ["sh" "-c" (love + " kore head -3 " + f + " | " + love + " kore more")])
         _ (test (two? r))
         m >r
         _ (settty m 10 40)
         _ (say m "qq\n")
         txt (slurp m)
         st (waitfor <r)
         [txt <st])
   (test (<>ra = 0) (has? <ra "alpha") (has? <ra "\e[?1049h"),

    unlink f, unlink g,
    test_fin (),
    say err "test/host/less: the pager face on a pty -- screenfuls, search, help, -N, +/PAT, the file walk and the pipe ok",
    put err 10,
    0))
