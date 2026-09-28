; --- test/host/pier.l: the terminal in its own X window, headless ---
; spawns an Xvfb and runs `love pier` on it with a child that paints two red cells and
; reads a line. the window's pixels come back through GetImage: the red is there, laid by
; the console's own painter (dye). then `a` and Return go in through XTEST -- pier's key
; path to the pty -- and the child, having read `a`, paints two green cells a row down.
; the child's exit takes pier with it, status 0. no Xvfb on the box -> a polite skip.
;   cat test/00-init.l test/host/pier.l | out/love
(: xv (tether ["Xvfb" "-displayfd" "1" "-screen" "0" "800x600x24" "-nolisten" "tcp"])
   (wfx p) (: g2 (gather p) (two? g2 ? g2 (rest 2, wfx p)))
   _ (? !(two? xv) (puts "pier: ok (no Xvfb, skipped)\n", quit 0) 0)
   (rdnum p) ((: (go n st) (: c (see p)
                              (? (c = -1) ()
                                 (c = 13) (go n st)
                                 (c = 10) (st = 1 ? n (go 0 0))
                                 ((48 <= c) && (c < 58))
                                  (st = 2 ? (go 0 2) (go ((10 * n) + (c - 48)) 1))
                                 (go 0 2))))
              0 0)
   dn (rdnum >xv)
   _ (test (charm? dn))
   kid "printf '\\033[41m  \\033[m'; read l; [ \"$l\" = a ] && printf '\\033[42m  \\033[m'; sleep 4"
   ph (tether ["out/love" "pier" "-display" (":" + show dn) "sh" "-c" kid])
   _ (rest 2500)
   XW (cite 'xwire)
   (w8 s v) ((XW 'x-w8) s v) (w16 s v) ((XW 'x-w16) s v) (w32 s v) ((XW 'x-w32) s v)
   s ((XW 'x-connect) ("/tmp/.X11-unix/X" + show dn))
   _ (test (hot? s))
   sc ((XW 'x-setup) s ())
   tree ((XW 'x-querytree) s ((XW 'scr-root) sc))
   _ (test (two? tree))
   kids <>tree                                         ; (1 windows): the children
   _ (test (two? kids))
   win (: (last l) (? (two? >l) (last >l) <l) (last kids))
   ; GetImage, ZPixmap: a 16x16 square of pier's window at (x,y), as (r g b) of its middle pixel
   (px x y) (: _ (w8 s 73) _ (w8 s 2) _ (w16 s 5) _ (w32 s win)
               _ (w16 s x) _ (w16 s y) _ (w16 s 16) _ (w16 s 16) _ (w32 s 4294967295)
               _ ((XW 'x-flush) s)
               hdr ((XW 'x-reply) s)
               n (((XW 'u32) hdr 4) * 4)
               bs ((XW 'x-rbytes) s n)
               at (((8 * 16) + 8) * 4)                   ; the middle, bgrx
               [(bs (at + 2)) (bs (at + 1)) (bs at)])
   _ (test ([128 0 0] = px 0 0))                       ; the red cells, xterm-256's 1
   ; XTEST: the key `a` (keycode 38) and Return (36), pressed and let go
   qx (: _ (w8 s 98) _ (w8 s 0) _ (w16 s 4) _ (w16 s 5) _ (w16 s 0)
         _ ((XW 'x-wpad) s "XTEST") _ ((XW 'x-flush) s)
         hdr ((XW 'x-reply) s) (hdr 9))
   (fake ty kc) (: _ (w8 s qx) _ (w8 s 2) _ (w16 s 9) _ (w8 s ty) _ (w8 s kc) _ (w16 s 0)
                   _ (w32 s 0) _ (w32 s 0) _ (w32 s 0) _ (w32 s 0)
                   _ (w16 s 0) _ (w16 s 0) _ (w32 s 0) _ (w16 s 0) _ (w8 s 0) _ (w8 s 0)
                   ((XW 'x-flush) s))
   _ (test (0 < qx))
   _ (fake 2 38) _ (fake 3 38) _ (fake 2 36) _ (fake 3 36)
   _ (rest 1500)
   _ (test ([0 128 0] = px 0 16))                      ; a row down: the green, the child read `a`
   _ (close s)
   st (wfx <ph)
   _ (test (two? st) (0 = <st))                        ; the child's exit took pier with it
   _ (still <xv 15)
   _ (wfx <xv)
   _ (test_fin ())
   (puts "pier: ok\n"))
