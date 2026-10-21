; test/host/window.l -- a window on Xvfb, driven by a second wire (GetImage, XTEST, resize):
; keys, pointer, size, selections and INCR; a blit refused with no screen; then `love synth -w`
; and `love lore corridor --window`.
; skips without Xvfb
; run: cat test/00-init.l test/host/window.l | out/love
(borrow 'window)
(borrow 'synth)   ; synth-trows
(borrow 'xwire)
; a key the keymap makes a ctrl is ctrl's, wherever it sits: caps lock as ctrl
(: xkm {66 [65507 0] 25 [119 87]}
 (test (x-events [2 66 0 0 ""] xkm 0 = [['down 29]]) (x-events [3 66 0 4 ""] xkm 0 = [['up 29]]) (x-events [2 25 0 4 ""] xkm 0 = [['down 17]])))
(: w0 {'w 1 'h 1 'paper (cask 4)}
   _ (window-own w0 'clipboard "kept", window-ask w0 'clipboard, window-ask w0 'primary)
   _ (test ([['paste "kept"] ['paste ""]] = window-events w0) (() = window-events w0)
           (window-blit w0 (cask 4) 1 1 = 0))
   xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "800x600x24" "-nolisten" "tcp"])
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
   ; GetImage, ZPixmap: one pixel at (x,y), as (r g b)
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
   ; the selections: owned, asked for and served back through the server, utf-8 whole
   _ (window-own win 'clipboard "h\u00e9llo\nw\u00f6rld", window-ask win 'clipboard)
   _ (rest 300)
   ev3 (drain () 4)
   _ (window-own win 'primary "p1", window-ask win 'primary)
   _ (rest 300)
   ev4 (drain () 4)
   ; SetSelectionOwner from the test's wire, owner none: the window loses the clipboard
   cb (XW 'x-intern s "CLIPBOARD")
   _ (w8 s 22, w8 s 0, w16 s 4, w32 s 0, w32 s cb, w32 s 0, XW 'x-flush s)
   _ (rest 300)
   ev5 (drain () 4)
   _ (test (elem ['paste "h\u00e9llo\nw\u00f6rld"] ev3) (elem ['paste "p1"] ev4)
           (elem ['lost 'clipboard] ev5))
   ; INCR: a piece each time the window deletes the property, the empty one closing it
   u32 (XW 'u32)
   ow (XW 'scr-idbase sc)
   _ (XW 'x-window s ow (XW 'scr-root sc) 1 1 0)
   ic (XW 'x-intern s "INCR")
   (prop w pr ty fmt n bs) (w8 s 18, w8 s 0, w16 s (6 + (#bs + 3) // 4), w32 s w, w32 s pr,
                            w32 s ty, w8 s fmt, w8 s 0, w16 s 0, w32 s n, XW 'x-wpad s bs)
   (next code f) (XW 'x-next s @ e (? !(two? e) () (XW 'ev-code e = code && f (XW 'ev-raw e)) (XW 'ev-raw e) (next code f)))
   (serve _) (: raw (next 30 (r \ 1))
                rq (u32 raw 12) sel (u32 raw 16) ty (u32 raw 20) pr (u32 raw 24)
                _ (w8 s 2, w8 s 0, w16 s 4, w32 s rq, w32 s 2048, w32 s 4194304)     ; its property changes, to us
                _ (prop rq pr ic 32 1 (string 5 + string 0 + string 0 + string 0))
                _ (w8 s 25, w8 s 0, w16 s 11, w32 s rq, w32 s 0)
                _ (w8 s 31, w8 s 0, w16 s 0, w32 s 0, w32 s rq, w32 s sel)
                _ (w32 s ty, w32 s pr, w32 s 0, w32 s 0)
                _ (XW 'x-flush s)
                (feed l) (two? l ?
                            (next 28 (r \ (u32 r 4 = rq && u32 r 8 = pr && r 16 = 1)),
                             prop rq pr ty 8 #<l <l,
                             XW 'x-flush s,
                             feed >l)
                            0)
                (feed ["p1" "\nq2" ""]))
   _ (w8 s 22, w8 s 0, w16 s 4, w32 s ow, w32 s cb, w32 s 0, XW 'x-flush s)
   it (twirl (_ \ (serve 0)) 0)
   _ (rest 100, window-ask win 'clipboard)
   (waitpaste n acc) (window-events win @ l
                    (acc + l @ a (any (r \ <r = 'paste) a || n < 1 ? a (rest 100, waitpaste (n - 1) a))))
   ev6 (waitpaste 30 ())
   _ (landed? it ? 0 (freeze it))
   _ (test (elem ['paste "p1\nq2"] ev6))
   _ (window-close win)
   ; synth: q's note lit only while held; esc ends with status 0
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
   ; the corridor: l held turns the view; a click holds the mouse and its motion turns the
   ; view, esc lets it go and leaves the corridor running; q ends with status 0
   pc (tether ["env" "HORN=none" ("DISPLAY=:" + show dn) "out/love" "lore" "corridor" "--window"])
   _ (rest 6000)
   cw (: kids <>(XW 'x-querytree s (XW 'scr-root sc)) (last l) (two? >l ? (last >l) <l) (last kids))
   (look _) (map (i \ px cw (40 + i * 70) (60 + i * 35)) ^8)
   v0 (look ())
   _ (fake 2 46, rest 1000, fake 3 46)                            ; l, held a second
   (moved n) (look () @ v (v != v0 || n < 1 ? v (rest 100, moved (n - 1))))
   v1 (moved 30)
   _ (fakeat 6 0 320 200, fake 4 1, fake 5 1, rest 300)          ; a click at the middle
   _ (fakeat 6 0 400 200, rest 300, fakeat 6 0 400 200)           ; the mouse right, twice
   (turned n) (look () @ v (v != v1 || n < 1 ? v (rest 100, turned (n - 1))))
   v2 (turned 30)
   _ (fake 2 9, fake 3 9, rest 500)                               ; esc
   up (gather <pc)
   _ (fake 2 24, fake 3 24)                                       ; q
   sc2 (wfn <pc 3000)
   _ (test (any (c \ c != [0 0 0]) v0) (v0 != v1) (v1 != v2) (!(two? up)) (two? sc2) (0 = <sc2))
   _ (close s)
   _ (still <xv 15)
   _ (wfx <xv)
   (test_fin (),
    puts "window: ok\n"))
