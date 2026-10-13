; test/host/porthole.l -- the mitty in a window of its own, headless: an Xvfb, `love mitty
; --window` on it with a child that paints cells as its input arrives, the pixels read back
; through GetImage and the keys sent through XTEST. asserted in turn: the child's red cells on
; the paper (it draws them when COLORTERM says truecolor), a line typed reaching it (the green), C-a v splitting the window (the right half
; lit by the new pane), and C-a x twice shutting both panes, the mitty ending with status 0.
; no Xvfb -> a polite skip.
; run: cat test/00-init.l test/host/porthole.l | out/love
(: xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "800x600x24" "-nolisten" "tcp"])
   (wfx p) (gather p @ g2 (two? g2 ? g2 (rest 2, wfx p)))
   _ (!(two? xv) ? (gate-skip "porthole: ok (no Xvfb, skipped)") 0)
   (rdnum p) ((: (go n st) (see p @ c
                              (? (c = -1) ()
                                 (c = 13) (go n st)
                                 (c = 10) (st = 1 ? n (go 0 0))
                                 (48 <= c && c < 58)
                                  (st = 2 ? (go 0 2) (go (10 * n + (c - 48)) 1))
                                 (go 0 2))))
              0 0)
   dn (rdnum >xv)
   _ (test (charm? dn))
   kid "[ \"$COLORTERM\" = truecolor ] && printf '\\033[41m  \\033[m'; read l; [ \"$l\" = a ] && printf '\\033[42m  \\033[m'; sleep 60"
   ph (tether ["env" "HORN=none" "MITTY=" "COLORTERM=" ("DISPLAY=:" + show dn) "out/love" "mitty" "--window" "sh" "-c" kid])
   _ (rest 4000)
   XW (cite 'xwire)
   (w8 s v) (XW 'x-w8 s v) (w16 s v) (XW 'x-w16 s v) (w32 s v) (XW 'x-w32 s v)
   s (XW 'x-connect ("/tmp/.X11-unix/X" + show dn))
   _ (test (hot? s))
   sc (XW 'x-setup s ())
   win (: kids <>(XW 'x-querytree s (XW 'scr-root sc)) (last l) (two? >l ? (last >l) <l) (last kids))
   ; GetImage, ZPixmap: a w by h piece of the window at (x,y), its bytes bgrx
   (grab x y w h) (: _ (w8 s 73, w8 s 2, w16 s 5, w32 s win)
                     _ (w16 s x, w16 s y, w16 s w, w16 s h, w32 s 4294967295)
                     _ (XW 'x-flush s)
                     hdr (XW 'x-reply s)
                     (XW 'x-rbytes s (XW 'u32 hdr 4 * 4)))
   (px x y) (grab x y 1 1 @ bs [(bs 2) (bs 1) (bs 0)])
   ; a pixel as it becomes c, or as it stands after n tries a tenth of a second apart
   (until x y c n) (px x y @ v (v = c || n < 1 ? v (rest 100, until x y c (n - 1))))
   ; how many of a piece's pixels are lit
   (lit x y w h) (grab x y w h @ bs (net (map (i \ (bs (4 * i) + bs (4 * i + 1) + bs (4 * i + 2) > 0)) ^(w * h))))
   qx (: _ (w8 s 98, w8 s 0, w16 s 4, w16 s 5, w16 s 0)
         _ (XW 'x-wpad s "XTEST", XW 'x-flush s)
         hdr (XW 'x-reply s) (hdr 9))
   _ (test (0 < qx))
   (fakeat ty d x y) (w8 s qx, w8 s 2, w16 s 9, w8 s ty, w8 s d, w16 s 0,
                      w32 s 0, w32 s 0, w32 s 0, w32 s 0,
                      w16 s x, w16 s y, w32 s 0, w16 s 0, w8 s 0, w8 s 0,
                      XW 'x-flush s)
   (fake ty d) (fakeat ty d 0 0)
   (tap kc) (fake 2 kc, fake 3 kc)
   (chord kc) (fake 2 37, tap kc, fake 3 37)                     ; under Control_L
   _ (fakeat 6 0 300 200)                                        ; no window manager: the keys go where the pointer is
   _ (test ([128 0 0] = until 4 4 [128 0 0] 40))                 ; the child's red cells, top left
   _ (tap 38, tap 36)                                            ; a, Return
   _ (test ([0 128 0] = until 4 20 [0 128 0] 40))                ; a row down: the green, the child read `a`
   right0 (lit 400 0 240 64)
   _ (chord 38, tap 55)                                          ; C-a v: a pane beside
   (grew n) (lit 400 0 240 64 @ v (right0 < v || n < 1 ? v (rest 100, grew (n - 1))))
   right1 (grew 60)
   _ (test (right0 < right1))
   _ (chord 38, tap 53)                                          ; C-a x: the new pane shut
   _ (rest 1500)
   _ (chord 38, tap 53)                                          ; ..and the child's
   (wfn p n) (gather p @ g2 (two? g2 ? g2 (n < 1 ? () (rest 2, wfn p (n - 1)))))
   st (wfn <ph 5000)
   ((two? st ? 0 (still <ph 15, wfx <ph)),
    test (two? st) (0 = <st),
    close s,
    still <xv 15,
    wfx <xv,
    test_fin (),
    puts "porthole: ok\n"))
