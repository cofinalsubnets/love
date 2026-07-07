; --- boot/haven.l: haven + two skiffs, end to end under a headless X ---
; NOT in the test/*.l corpus (shore/wl-send/memfd/connectu/mind are host/*.c).
; spawns an Xvfb, sails haven (the wayland compositor) as one child and two
; skiffs (red, then blue) as two more, then reads haven's X WINDOW back with
; GetImage: red fills the glass alone; when blue arrives the LAYOUT retiles
; -- blue takes the master column, red re-dresses into the slave column --
; and both colors must sit in their tiles. the whole loop: wayland socket ->
; SCM_RIGHTS fd -> shm pool -> commit -> layout -> mapin -> px-ship -> X.
;
;   cat test/00-init.l boot/haven.l | out/host/ai
;
; no Xvfb on the box -> a polite skip (the sentinel still prints).

(reads (open "crew/phos/core.l" "r"))
(reads (open "crew/phos/wire.l" "r"))

; -displayfd: Xvfb PICKS a free display and prints the number when it is ready
; to accept -- so no fixed :78 a stray server can poison (a stale server would
; silently BECOME the test target: waitsock connects to it, QueryTree finds the
; old run's frozen window, and the hue checks read last week's pixels), and the
; number arriving IS the readiness signal. the wayland socket rides the same
; number, one namespace per live server; a crashed run's stale socket FILE is
; unlinked before haven binds. the CAMP: every child pid enlists as it spawns,
; and a failed claim STRIKES the camp before exiting -- an assert naps straight
; out of file mode, so cleanup must ride in front of it (Xvfb catches SIGHUP,
; it survives our death; the ai children die with their pty).
(: xv (mind `("Xvfb" "-displayfd" "1" "-screen" "0" "640x480x24" "-nolisten" "tcp"))
   (wfx p) (: g2 (gather p) (? (two? g2) g2 (: _ (rest 2) (wfx p))))
   camp #()
   (enlist k pid) (pin camp k pid)
   (strike _) (map (\ k (: p (camp k)
                           _ (? (charm? p) (: _ (still p 15) (wfx p)) 0) 0))
                   (keys camp))
   (must tag v) (? v v (: _ (strike ())
                           _ (puts "haven: FAIL ") _ (putx tag) _ (putc 10)
                           (nap 1)))
   (waitsock pth t) (? (< t 1) ()
                      (: p (connectu pth)
                         (? (lit? p) (: _ (close p) 1)
                            (: _ (rest 50) (waitsock pth (- t 1))))))
 _ (? (! (two? xv))
      (: _ (puts "haven: ok (no Xvfb, skipped)") (nap 0))
      0)
 _ (enlist 'xv (cap xv))
 ; the display number off Xvfb's stdout: -displayfd writes it on ITS OWN line,
 ; so take the first line that is ENTIRELY digits -- server chatter shares the
 ; pty (this box's amdgpu warning says "(-13)", which a naive digit-skimmer
 ; happily reads as display 13; haven then aims at a ghost and bows out).
 ; st: 0 at line start, 1 digits-so-far, 2 line poisoned. see parks until ready.
 (rdnum p) ((: (go n st) (: c (see p)
                            (? (= c -1) ()
                               (= c 13) (go n st)
                               (= c 10) (? (= st 1) n (go 0 0))
                               (&& (<= 48 c) (< c 58))
                                (? (= st 2) (go 0 2) (go (+ (* 10 n) (- c 48)) 1))
                               (go 0 2))))
            0 0)
 dn (rdnum (cup xv))
 _ (must 'display (&& (charm? dn) (! (two? (gather (cap xv))))))
 dpy (+ "/tmp/.X11-unix/X" (show dn))
 sock (+ "/tmp/haven-boot-" (+ (show dn) ".sock"))
 _ (unlink sock)
 _ (unlink (+ sock ".moor"))

 ; GetImage (opcode 73, ZPixmap): w*h pixels back as a byte list (BGRX)
 (px-getimg s d x y w h)
  (: _ (x-w8 s 73) _ (x-w8 s 2) _ (x-w16 s 5)
     _ (x-w32 s d) _ (x-w16 s x) _ (x-w16 s y) _ (x-w16 s w) _ (x-w16 s h)
     _ (x-w32 s 4294967295) _ (x-flush s)
     hdr (x-reply s)
     (x-rbytes s (* 4 (u32 hdr 4))))
 ; how many pixels in the patch wear exactly (b g r)
 (hue-in px b g r) (: (go l n) (? (! (two? l)) n
                                  (go (drop 4 l)
                                      (+ n (? (= b (cap l))
                                              (? (= g (nthl l 1)) (? (= r (nthl l 2)) 1 0) 0)
                                              0))))
                      (go px 0))

 ; haven on its own X window + shore
 hv (mind `("out/host/ai" "-l" "crew/phos/core.l" "-l" "crew/phos/wire.l"
            "-l" "crew/phos/layout.l" "-l" "crew/quay/pier.l"
            "-l" "crew/haven/wire.l" "-l" "crew/haven/haven.l"
            "-e" (+ "(haven \"" (+ sock (+ "\" \"" (+ dpy "\" () 320 240)"))))))
 _ (must 'haven-up (two? hv))
 _ (enlist 'hv (cap hv))
 _ (must 'haven-sock (waitsock sock 100))

 ; our own eyes: find the window, wait till it's viewable
 s (connectu dpy)
 sc (x-setup s ())
 _ (must 'x-eyes (&& (two? sc) (= 24 (scr-depth sc))))
 (waitwin t) (? (< t 1) ()
                (: ws (x-querytree s (scr-root sc))
                   (? (two? ws) (cap ws) (: _ (rest 100) (waitwin (- t 1))))))
 win (waitwin 100)
 _ (must 'haven-window (charm? win))
 (waitmap t) (? (< t 1) 0
                (? (= 2 (cap (x-attrs s win))) 1
                   (: _ (rest 50) (waitmap (- t 1)))))
 _ (must 'haven-mapped (waitmap 100))

 ; a hue-waiter: an 8x8 patch at (x y) holds >= 30 (b g r) pixels
 (waithue x y b g r t) (? (< t 1) 0
                          (: n (hue-in (px-getimg s win x y 8 8) b g r)
                             (? (< 30 n) n (: _ (rest 100) (waithue x y b g r (- t 1))))))

 ; the red skiff, alone: one toplevel takes the whole 320x240 glass
 skr (mind `("out/host/ai" "-l" "crew/haven/wire.l" "-l" "crew/haven/skiff.l"
             "-e" (+ "(skiff \"" (+ sock "\" 320 240 12582912)"))))
 _ (must 'red-up (two? skr))
 _ (enlist 'skr (cap skr))
 _ (must 'red-fills (waithue 240 120 0 0 192 100))    ; red deep in the right half

 ; the blue skiff arrives: the layout retiles -- blue masters the left
 ; column, red hears its new size and re-dresses into the right
 skb (mind `("out/host/ai" "-l" "crew/haven/wire.l" "-l" "crew/haven/skiff.l"
             "-e" (+ "(skiff \"" (+ sock "\" 320 240 192)"))))
 _ (must 'blue-up (two? skb))
 _ (enlist 'skb (cap skb))
 _ (must 'blue-masters (waithue 76 120 192 0 0 100))     ; blue in the master column
 _ (must 'red-slave (waithue 240 120 0 0 192 100))    ; red re-dressed in the slave

 ; the moor: the whole language over a socket into the RUNNING compositor.
 ; eval, survive a scare, SWAP THE LAYOUT live -- mirror flips the master
 ; column into the top ROW (blue re-dresses wide up top, red wide below;
 ; the change rides the painter's tick, the retile the configure/ack path
 ; both skiffs already dance) -- refuse garbage, restore the columns
 mc (: (try t) (? (< t 1) ()
                  (: p (connectu (+ sock ".moor"))
                     (? (lit? p) p (: _ (rest 100) (try (- t 1))))))
       (try 100))
 _ (must 'moor-up (lit? mc))
 (rdline u) (: (go acc) (: ch (see mc)
                           (? (|| (= ch -1) (= ch 10)) acc (go (+ acc (+ "" ch)))))
               (go ""))
 (ask q) (: _ (say mc q) _ (say mc "\n") _ (flush mc) (rdline ()))
 _ (must 'moor-evals (= "3" (ask "(+ 1 2)")))
 _ (ask "(boom-unbound)")                              ; a scare answers a value; the session lives
 _ (must 'moor-survives (= "7" (ask "(+ 3 4)")))
 _ (ask "(lay! (mirror (tall 1)))")                    ; the swap lane: a fresh layout (toggle OFF)
 _ (ask "(msg! 'mirror)")                              ; the message lane: the toggle flips ON
 _ (must 'moor-mirrors (waithue 240 60 192 0 0 100))   ; blue re-dressed across the TOP band
 _ (must 'red-below (waithue 240 180 0 0 192 100))     ; red across the bottom
 _ (ask "(haven! (\\ z lay 7))")                       ; garbage: refused, haven stands
 _ (must 'moor-refuses (= "11" (ask "(+ 5 6)")))
 _ (ask "(lay! (mirror (choice (L (tall 1) full))))")  ; back to the boot ring (columns at idx 0)
 _ (must 'moor-restores (waithue 76 120 192 0 0 100))  ; the columns come back

 ; the control plane: swap trades the tiles (blue focused, swapped under red),
 ; then swaps back; kill! asks the focused toplevel to close and blue PARTS ON
 ; ITS OWN -- exit 0 is the proof -- and red spreads
 _ (ask "(swapup! ())")
 _ (must 'swap-red-masters (waithue 76 120 0 0 192 100))   ; red takes the master column
 _ (must 'swap-blue-slaves (waithue 240 120 192 0 0 100))
 _ (ask "(swapdn! ())")
 _ (must 'swap-back (waithue 76 120 192 0 0 100))          ; blue masters again
 _ (ask "(kill! ())")
 gb (wfx (cap skb))
 _ (close (cup skb))
 _ (pull camp 'skb 0)                        ; reaped: a second wfx would spin on the dead pid
 _ (must 'blue-clean (= 0 (cap gb)))                    ; blue's OWN exit, status 0
 _ (must 'red-spreads (waithue 76 120 0 0 192 100))     ; red owns the left again
 _ (close mc)

 ; the third act, where the binary exists (see the Makefile's $(smoke) rule):
 ; a REAL client -- libwayland + xdg-shell, the reference implementation and
 ; strict about ids -- joins red. green masters the left, red re-dresses into
 ; the slave; the SEAT speaks (a fake key through haven's glass must reach
 ; the smoke as wl_keyboard traffic, keymap and enter and all -- the smoke's
 ; 4th arg arms the expectation and its exit 0 is the proof); a yellow skiff
 ; squeezes it (the resize dance, both directions); the smoke lives 300
 ; frames on its 10ms clock, strikes its own court (buffers, toplevel,
 ; surface -- every destructor answered by delete_id) and exits 0 BY
 ; ITSELF; red spreads back. no binary, no act.
 (fake qx ty dt) (: _ (x-w8 s qx) _ (x-w8 s 2) _ (x-w16 s 9)
                    _ (x-w8 s ty) _ (x-w8 s dt) _ (x-w16 s 0)
                    _ (x-w32 s 0) _ (x-w32 s 0) _ (x-w32 s 0) _ (x-w32 s 0)
                    _ (x-w16 s 0) _ (x-w16 s 0) _ (x-w32 s 0) _ (x-w16 s 0) _ (x-w8 s 0) _ (x-w8 s 0)
                    (x-flush s))
 smokebin "out/host/haven-smoke"
 smokep (open smokebin "r")
 _ (? (lit? smokep)
      (: _ (close smokep)
         smk (mind (L smokebin sock "00c000" "700" "30"))       ; expect evdev 30 (X keycode 38); frames cover the chord act too
         _ (must 'smoke-up (two? smk))
         _ (enlist 'smk (cap smk))
         _ (must 'smoke-masters (waithue 76 120 0 192 0 100))   ; green in the master column
         _ (must 'red-reslave (waithue 240 120 0 0 192 100))    ; red re-dressed right
         ; the seat act: XTEST a key at haven's focused glass
         qx (: n (tally "XTEST")
               _ (x-w8 s 98) _ (x-w8 s 0) _ (x-w16 s (+ 2 (/ (+ n (x-pad4 n)) 4)))
               _ (x-w16 s n) _ (x-w16 s 0) _ (x-wpad s "XTEST") _ (x-flush s)
               hdr (x-reply s)
               (nthl hdr 9))
         _ (must 'xtest (< 0 qx))
         _ (x-focus s win) _ (x-flush s)
         _ (rest 150)
         _ (fake qx 2 38) _ (rest 80)                           ; KeyPress 38 ('a')
         _ (fake qx 3 38) _ (rest 80)                           ; KeyRelease
         ; the chord through the glass: sup+space walks the layout ring --
         ; FULL (the focused smoke owns the whole glass), then back to the
         ; columns. XTEST holds super and taps space twice; the key table
         ; answers, the queue drains on the painter's tick
         ckm (x-keymap s (scr-mink sc) (scr-maxk sc) (L 65515 32))
         supk (peep ckm 65515 0) spck (peep ckm 32 0)
         _ (must 'chord-keys (? (< 0 supk) (< 0 spck) 0))
         _ (fake qx 2 supk) _ (rest 30)
         _ (fake qx 2 spck) _ (rest 30) _ (fake qx 3 spck)
         _ (must 'chord-full (waithue 240 120 0 192 0 100))     ; green owns the right half too
         _ (fake qx 2 spck) _ (rest 30) _ (fake qx 3 spck)
         _ (fake qx 3 supk)
         _ (must 'chord-cycles (waithue 240 120 0 0 192 100))   ; red back in the slave
         ; a yellow skiff barges in: three tiles -- the smoke hears a SMALLER
         ; size and does the honest resize: buffers struck (delete_id), a
         ; fresh pool dressed, the retired ids REUSED by libwayland. a
         ; bookkeeping slip is a protocol error and a nonzero exit below.
         sky (mind `("out/host/ai" "-l" "crew/haven/wire.l" "-l" "crew/haven/skiff.l"
                     "-e" (+ "(skiff \"" (+ sock "\" 320 240 12632064)"))))
         _ (must 'yellow-up (two? sky))
         _ (enlist 'sky (cap sky))
         _ (must 'yellow-masters (waithue 76 120 0 192 192 100))  ; yellow takes the master
         _ (must 'smoke-reslave (waithue 240 60 0 192 0 100))     ; green re-dressed smaller, upper slave
         ; yellow steps away: the smoke grows back -- a second fresh pool
         _ (still (cap sky) 15) _ (wfx (cap sky)) _ (close (cup sky))
         _ (pull camp 'sky 0)
         _ (must 'smoke-remasters (waithue 76 120 0 192 0 100))
         g (wfx (cap smk))
         _ (close (cup smk))
         _ (pull camp 'smk 0)
         _ (must 'smoke-clean (= 0 (cap g)))                    ; its OWN exit, status 0
         (must 'red-respreads (waithue 76 120 0 0 192 100)))
      0)

 ; strike the camp (the same teardown the failure path takes)
 _ (close s)
 _ (strike ())
 _ (close (cup skr)) _ (close (cup hv)) _ (close (cup xv))
 _ (unlink sock)
 _ (unlink (+ sock ".moor"))
 (puts "haven: ok"))
