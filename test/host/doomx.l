; --- test/host/doomx.l: doom on the host, in an X window, headless ---
; spawns an Xvfb and runs `love doom -frames 300` against it (the same window and
; wire a desktop gets: apps/doom/doom.l), holds an arrow key through XTEST for a
; second and a half of the run, and holds the run to exit 0 and its own frame count. no Xvfb on the box -> a polite skip. wants a DOOM=1 love and the IWAD
; (test_doomx builds the first; the Makefile's doom lane says where the second goes).
;   cat test/00-init.l test/host/doomx.l | out/love
; a love without doom in it would take the verb's NEST path -- a seed and a build under
; $HOME -- which no gate may start: the door is DOOM=1, and this says so instead.
(: _ (? (member? 'doom-start (names ())) 0
        (: _ (puts "doomx: FAIL -- this love carries no doom (build with DOOM=1)") _ (putc 10) (quit 1)))
   xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "800x600x24" "-nolisten" "tcp"])
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
   ; the game: silent (HORN=none), 300 frames, then it says how many it drew
   ph (tether ["env" "HORN=none" (+ "DISPLAY=:" (show dn)) "out/love" "doom" "-frames" "300"])
   ; while it runs, a held key through XTEST on a wire of our own: a second and a half
   ; of the up arrow (keycode 111), which the server repeats -- the path apps/doom/
   ; doom.l's detectable autorepeat covers -- then the release. what this proves is that
   ; the key path and the XKB requests leave the wire in step: the frames still count.
   _ (rest 2500)
   XW (from 'xwire)
   s ((XW 'x-connect) (+ "/tmp/.X11-unix/X" (show dn)))
   _ (assert (hot? s))
   sc ((XW 'x-setup) s ())
   qx (: n 5 _ ((XW 'x-w8) s 98) _ ((XW 'x-w8) s 0) _ ((XW 'x-w16) s 4) _ ((XW 'x-w16) s n) _ ((XW 'x-w16) s 0)
         _ ((XW 'x-wpad) s "XTEST") _ ((XW 'x-flush) s)
         hdr ((XW 'x-reply) s) (hdr 9))
   (fake ty dt) (: w8 (XW 'x-w8) w16 (XW 'x-w16) w32 (XW 'x-w32)
                   _ (w8 s qx) _ (w8 s 2) _ (w16 s 9) _ (w8 s ty) _ (w8 s dt) _ (w16 s 0)
                   _ (w32 s 0) _ (w32 s 0) _ (w32 s 0) _ (w32 s 0)
                   _ (w16 s 0) _ (w16 s 0) _ (w32 s 0) _ (w16 s 0) _ (w8 s 0) _ (w8 s 0)
                   ((XW 'x-flush) s))
   _ (? (< 0 qx) (: _ (fake 2 111) _ (rest 1500) _ (fake 3 111) 0) 0)
   _ (close s)
   out (: (go acc) (: c (see (cup ph)) (? (= c -1) acc (go (+ acc (string c))))) (go ""))
   st (wfx (cap ph))
   _ (still (cap xv) 15)
   _ (wfx (cap xv))
   ; the pty's tail: the count, then whatever line ending the terminal put after it
   (trimr s) (: n #s (? (&& (< 0 n) (member? (s (- n 1)) '(10 13))) (trimr (snip s 0 (- n 1))) s))
   o (trimr out)
   _ (assert (= "doom: 300 frames" (snip o (- (tally o) 16) (tally o))))
   (puts "doomx: ok"))
