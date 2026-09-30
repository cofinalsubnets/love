; test/host/less.l -- the pager's face on a real terminal (the engine is lawed in test/law/kore.l):
; raw mode, the alternate screen, the key loop, the blit, and the files the : commands ask for.
; the pty is 0x0 until settty lands, so nothing here asks about geometry.
; run: LOVEBIN=out/love LESSTESTDIR=out sh -c "cat test/00-init.l test/host/less.l | out/love"

(: love (getenv "LOVEBIN")
   dir (getenv "LESSTESTDIR")
   f (dir + "/pg.txt")
   ; ten short lines, so the first screenful is the first of them at any size
   _ (open f "w" @ q
      (say q "alpha\nbravo\ncharlie\ndelta\necho\nfoxtrot\ngolf\nhotel\nindia\njuliet\n",
       close q))
   (waitfor pid) (gather pid @ s (? (two? s) s (nom? s) s (do (rest 2) (waitfor pid))))
   ; spawn `love kore less ARGS..` on a pty, size it, type keys, answer what it drew
   ; the keys carry a "qq\n" tail: they are typed before the child has raw mode,
   ; so the line discipline is still canonical and holds a partial line back -- and
   ; a sequence that failed to quit would otherwise park the harness on `slurp`
   ; forever. two q's, because the first leaves the help page rather than the pager
   (run keys args)
    (: r (tether (cat [love "kore" "less"] args))
       _ (test (two? r))
       m >r
       _ (settty m 10 40)
       _ (say m (keys + "qq\n"))
       txt (slurp m)
       st (waitfor <r)
       [txt <st])
   (has? t s) (: n #t k #s
                 (go i) (? (n - k < i) () (s = snip t i (i + k)) 1 (go (i + 1)))
                 (go 0))

   ; --- q leaves at once: the first screenful, the status line, and the screen back
   r1 (run "" [f])
   _ (test
      (<>r1 = 0)                            ; the pager's own status, not a signal
      (has? <r1 "alpha")                    ; the top of the file
      (has? <r1 "pg.txt")                   ; the status line names the file
      (has? <r1 "1-")                       ; ... and where in it we are
      (has? <r1 "\e[?1049h")                ; the alternate screen, entered
      (has? <r1 "\e[?1049l"))               ; ... and left

   ; --- G lands at the end, and the status says so
   r2 (run "G" [f])
   _ (test (<>r2 = 0) (has? <r2 "juliet") (has? <r2 "(END)"))

   ; --- /pattern moves to the match, and h swaps the help page in
   r3 (run "/india\n" [f])
   _ (test (<>r3 = 0) (has? <r3 "india"))
   ; the first q comes back out of the help; only the second one leaves
   r4 (run "h" [f])
   _ (test (<>r4 = 0) (has? <r4 "the pager") (has? <r4 "alpha"))

   ; --- -N numbers the lines, and +/pat opens where the match is
   r5 (run "" ["-N" f])
   _ (test (<>r5 = 0) (has? <r5 "1 alpha"))
   r6 (run "" ["+/golf" f])
   _ (test (<>r6 = 0) (has? <r6 "golf"))

   ; --- a name that will not open is a status, said on err, and no screen at all
   r7 (run "" [(dir + "/nope.txt")])
   _ (test (<>r7 = 1) !(has? <r7 "\e[?1049h"))

   ; --- :n walks to the second operand and :p walks back
   g (dir + "/pg2.txt")
   _ (open g "w" @ q (say q "kilo\nlima\n", close q))
   r8 (run ":n" [f g])
   _ (test (<>r8 = 0) (has? <r8 "kilo") (has? <r8 "pg2.txt"))
   r9 (run ":n:p" [f g])
   _ (test (<>r9 = 0) (has? <r9 "alpha"))

   ; --- a PIPE is the text and /dev/tty is the keyboard: `more` is the same door
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
    test_fin (),                            ; no zz-fin here: quit before claiming ok
    say err "test/host/less: the pager face on a pty -- screenfuls, search, help, -N, +/PAT, the file walk and the pipe ok",
    put err 10,
    0))
