; --- test/host/doomx.l: doom on the host, in an X window, headless ---
; spawns an Xvfb and runs `love doom -frames 120` against it (the same window and
; wire a desktop gets: src/apps/doom/doom.l), holding the run to exit 0 and its own
; frame count. no Xvfb on the box -> a polite skip. wants a DOOM=1 love and the IWAD
; (test_doomx builds the first; the Makefile's doom lane says where the second goes).
;   cat test/00-init.l test/host/doomx.l | out/love
(: xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "800x600x24" "-nolisten" "tcp"])
   (wfx p) (: g2 (gather p) (? (two? g2) g2 (: _ (rest 2) (wfx p))))
   _ (? !(two? xv) (: _ (puts "doomx: ok (no Xvfb, skipped)") (quit 0)) 0)
   (rdnum p) ((: (go n st) (: c (see p)
                              (? (= c -1) ()
                                 (= c 13) (go n st)
                                 (= c 10) (? (= st 1) n (go 0 0))
                                 (&& (<= 48 c) (< c 58))
                                  (? (= st 2) (go 0 2) (go (+ (* 10 n) (- c 48)) 1))
                                 (go 0 2))))
              0 0)
   dn (rdnum (cup xv))
   _ (assert (charm? dn))
   ; the game: silent (HORN=none), 120 frames, then it says how many it drew
   ph (tether ["env" "HORN=none" (+ "DISPLAY=:" (show dn)) "out/love" "doom" "-frames" "120"])
   out (: (go acc) (: c (see (cup ph)) (? (= c -1) acc (go (+ acc (string c))))) (go ""))
   st (wfx (cap ph))
   _ (still (cap xv) 15)
   _ (wfx (cap xv))
   ; the pty's tail: the count, then whatever line ending the terminal put after it
   (trimr s) (: n #s (? (&& (< 0 n) (member? (s (- n 1)) '(10 13))) (trimr (snip s 0 (- n 1))) s))
   o (trimr out)
   _ (assert (= "doom: 120 frames" (snip o (- (tally o) 16) (tally o))))
   (puts "doomx: ok"))
