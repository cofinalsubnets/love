; test/host/window.l -- a window of the face's own on X, headless: an Xvfb, a window opened in
; this process and laid red, and a second wire of the test's that reads its pixels back through
; GetImage, sends keys and the pointer through XTEST and resizes it. asserted: the paper shown,
; a key down and up by its set-1 code and the text it types, a move, a press and a release in
; the window's pixels, a size and the fresh paper it brings; then `love synth -w`, a key's
; note lit while it is held, and `love lore corridor --window`, turning while a key is held.
; no Xvfb -> a polite skip.
; run: cat test/00-init.l test/host/window.l | out/love
(borrow 'window)
(borrow 'synth)   ; synth-trows, where its strip sits
(: xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "800x600x24" "-nolisten" "tcp"])
   (wfx p) (gather p @ g2 (two? g2 ? g2 (rest 2, wfx p)))
   _ (!(two? xv) ? (gate-skip "window: ok (no Xvfb, skipped)") 0)
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
   _ (setenv "DISPLAY" (":" + show dn))
   win (window-open 320 200 "window")
   _ (test (tablet? win) ([320 200] = window-size win) (320 * 200 * 4 = #(window-paper win)))
   p (window-paper win)
   row (cask (320 * 4))
   _ (each ^320 (x \ pin row (4 * x + 2) 255))                   ; 0x00ff0000
   _ (each ^200 (y \ pour p (y * 320 * 4) row 0 (320 * 4)))
   _ (window-show win 0 200)
   _ (rest 500)
   (drain acc n) (n < 1 ? acc (window-events win @ l (rest 50, drain (acc + l) (n - 1))))
   _ (drain () 4)                                                 ; the map's expose and size
   XW (cite 'xwire)
   (w8 s v) (XW 'x-w8 s v) (w16 s v) (XW 'x-w16 s v) (w32 s v) (XW 'x-w32 s v)
   s (XW 'x-connect ("/tmp/.X11-unix/X" + show dn))
   _ (test (hot? s))
   sc (XW 'x-setup s ())
   xw (win 'xw)
   ; GetImage, ZPixmap: one pixel of window w at (x,y), as (r g b)
   (px w x y) (: _ (w8 s 73, w8 s 2, w16 s 5, w32 s w)
               _ (w16 s x, w16 s y, w16 s 1, w16 s 1, w32 s 4294967295)
               _ (XW 'x-flush s)
               hdr (XW 'x-reply s)
               bs (XW 'x-rbytes s (XW 'u32 hdr 4 * 4))
               [(bs 2) (bs 1) (bs 0)])
   _ (test ([255 0 0] = px xw 10 10) ([255 0 0] = px xw 319 199))
   qx (: _ (w8 s 98, w8 s 0, w16 s 4, w16 s 5, w16 s 0)
         _ (XW 'x-wpad s "XTEST", XW 'x-flush s)
         hdr (XW 'x-reply s) (hdr 9))
   _ (test (0 < qx))
   (fakeat ty d x y) (w8 s qx, w8 s 2, w16 s 9, w8 s ty, w8 s d, w16 s 0,
                      w32 s 0, w32 s 0, w32 s 0, w32 s 0,
                      w16 s x, w16 s y, w32 s 0, w16 s 0, w8 s 0, w8 s 0,
                      XW 'x-flush s)
   (fake ty d) (fakeat ty d 0 0)
   ; no window manager: the keys go where the pointer is, so it moves in first
   _ (fakeat 6 0 30 40, fake 4 1, fake 5 1)
   _ (fake 2 52, fake 3 52)                                       ; z: evdev 44, set 1's 44 too
   _ (rest 500)
   ev (drain () 4)
   _ (test (elem ['down 44] ev) (elem ['up 44] ev) (elem ['text "z"] ev)
           (elem ['move 30 40] ev) (elem ['press 1 30 40] ev) (elem ['release 1 30 40] ev)
           !(any (r \ <r = 'size) ev))                              ; nothing moved: no size
   ; ConfigureWindow, width and height: a size, and a paper of it
   _ (w8 s 12, w8 s 0, w16 s 5, w32 s xw, w16 s 12, w16 s 0, w32 s 200, w32 s 100, XW 'x-flush s)
   _ (rest 500)
   ev2 (drain () 4)
   _ (test (elem ['size 200 100] ev2) ([200 100] = window-size win)
           (200 * 100 * 4 = #(window-paper win)))
   _ (window-close win)
   ; synth in a window of its own: q's note lit while it is held and not once it is let go,
   ; esc the end with status 0
   ph (tether ["env" "HORN=none" ("DISPLAY=:" + show dn) "out/love" "synth" "-w"])
   _ (rest 4000)
   kids <>(XW 'x-querytree s (XW 'scr-root sc))
   _ (test (two? kids))
   sw (: (last l) (two? >l ? (last >l) <l) (last kids))
   y (synth-trows * 16 + 20) cq (12 * 20 + 10)                    ; middle c, the 13th of 32
   ; a pixel as it becomes c, or as it stands after n tries a tenth of a second apart
   (until w x y c n) (px w x y @ v (v = c || n < 1 ? v (rest 100, until w x y c (n - 1))))
   before (px sw cq y)
   _ (fake 2 24)                                                  ; q down
   held (until sw cq y [255 128 0] 30)
   _ (fake 3 24)
   after (until sw cq y [208 208 208] 30)
   _ (fake 2 9, fake 3 9)                                         ; esc
   (wfn p n) (gather p @ g2 (two? g2 ? g2 (n < 1 ? () (rest 2, wfn p (n - 1)))))
   st (wfn <ph 3000)
   _ (test ([208 208 208] = before) ([255 128 0] = held) ([208 208 208] = after)
           (two? st) (0 = <st))
   ; the corridor in a window of its own: l held turns the view while it is held, so the
   ; picture moves; q is the end with status 0
   pc (tether ["env" "HORN=none" ("DISPLAY=:" + show dn) "out/love" "lore" "corridor" "--window"])
   _ (rest 6000)
   cw (: kids <>(XW 'x-querytree s (XW 'scr-root sc)) (last l) (two? >l ? (last >l) <l) (last kids))
   (look _) (map (i \ px cw (40 + i * 70) (60 + i * 35)) ^8)
   v0 (look ())
   _ (fake 2 46, rest 1000, fake 3 46)                            ; l, held a second
   (moved n) (look () @ v (v != v0 || n < 1 ? v (rest 100, moved (n - 1))))
   v1 (moved 30)
   _ (fake 2 24, fake 3 24)                                       ; q
   sc2 (wfn <pc 3000)
   _ (test (any (c \ c != [0 0 0]) v0) (v0 != v1) (two? sc2) (0 = <sc2))
   _ (close s)
   _ (still <xv 15)
   _ (wfx <xv)
   (test_fin (),
    puts "window: ok\n"))
