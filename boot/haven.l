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

(reads (open "apps/wm/core.l" "r"))
(reads (open "apps/wm/wire.l" "r"))

(: dpy "/tmp/.X11-unix/X78"
   sock "/tmp/haven-boot.sock"
   xv (mind `("Xvfb" ":78" "-screen" "0" "640x480x24" "-nolisten" "tcp"))
   (wfx p) (: g2 (gather p) (? (two? g2) g2 (: _ (rest 2) (wfx p))))
   (waitsock pth t) (? (< t 1) ()
                      (: p (connectu pth)
                         (? (lit? p) (: _ (close p) 1)
                            (: _ (rest 50) (waitsock pth (- t 1))))))
 _ (? (! (two? xv))
      (: _ (puts "haven: ok (no Xvfb, skipped)") (nap 0))
      0)
 _ (assert (waitsock dpy 100))

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
 hv (mind `("out/host/ai" "-l" "apps/wm/core.l" "-l" "apps/wm/wire.l"
            "-l" "apps/wm/layout.l" "-l" "apps/quay/pier.l"
            "-l" "apps/haven/wire.l" "-l" "apps/haven/haven.l"
            "-e" "(haven \"/tmp/haven-boot.sock\" \"/tmp/.X11-unix/X78\" () 320 240)"))
 _ (assert (two? hv))
 _ (assert (waitsock sock 100))

 ; our own eyes: find the window, wait till it's viewable
 s (connectu dpy)
 sc (x-setup s ())
 _ (assert (two? sc) (= 24 (scr-depth sc)))
 (waitwin t) (? (< t 1) ()
                (: ws (x-querytree s (scr-root sc))
                   (? (two? ws) (cap ws) (: _ (rest 100) (waitwin (- t 1))))))
 win (waitwin 100)
 _ (assert (charm? win))
 (waitmap t) (? (< t 1) 0
                (? (= 2 (cap (x-attrs s win))) 1
                   (: _ (rest 50) (waitmap (- t 1)))))
 _ (assert (waitmap 100))

 ; a hue-waiter: an 8x8 patch at (x y) holds >= 30 (b g r) pixels
 (waithue x y b g r t) (? (< t 1) 0
                          (: n (hue-in (px-getimg s win x y 8 8) b g r)
                             (? (< 30 n) n (: _ (rest 100) (waithue x y b g r (- t 1))))))

 ; the red skiff, alone: one toplevel takes the whole 320x240 glass
 skr (mind `("out/host/ai" "-l" "apps/haven/wire.l" "-l" "apps/haven/skiff.l"
             "-e" "(skiff \"/tmp/haven-boot.sock\" 320 240 12582912)"))
 _ (assert (two? skr))
 _ (assert (waithue 240 120 0 0 192 100))    ; red deep in the right half

 ; the blue skiff arrives: the layout retiles -- blue masters the left
 ; column, red hears its new size and re-dresses into the right
 skb (mind `("out/host/ai" "-l" "apps/haven/wire.l" "-l" "apps/haven/skiff.l"
             "-e" "(skiff \"/tmp/haven-boot.sock\" 320 240 192)"))
 _ (assert (two? skb))
 _ (assert (waithue 76 120 192 0 0 100))     ; blue in the master column
 _ (assert (waithue 240 120 0 0 192 100))    ; red re-dressed in the slave

 ; blue steps away: red should spread back over the whole glass
 _ (still (cap skb) 15) _ (wfx (cap skb)) _ (close (cup skb))
 _ (assert (waithue 76 120 0 0 192 100))     ; red owns the left again

 ; strike the camp
 _ (still (cap skr) 15) _ (wfx (cap skr)) _ (close (cup skr))
 _ (still (cap hv) 15) _ (wfx (cap hv)) _ (close (cup hv))
 _ (close s)
 _ (still (cap xv) 15)
 _ (wfx (cap xv))
 (puts "haven: ok"))
