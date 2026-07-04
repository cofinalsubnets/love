; --- boot/pier.l: the X window frontend, end to end against a headless server ---
; NOT in the test/*.l corpus (connectu/mind/screen/blit are host/*.c). spawns its
; own Xvfb, sails a pier with a real child, finds the window with QueryTree, and
; reads the PAINTED PIXELS back through the server with GetImage -- the whole loop:
; pty -> parser -> grid -> blit -> PutImage -> X -> GetImage.
;
;   cat test/00-init.l boot/pier.l | out/host/ai
;
; no Xvfb on the box -> a polite skip (the sentinel still prints).

(reads (open "apps/wm/core.l" "r"))
(reads (open "apps/wm/wire.l" "r"))
(reads (open "apps/quay/berth.l" "r"))
(reads (open "apps/quay/pier.l" "r"))

(: dpy "/tmp/.X11-unix/X77"
   xv (mind `("Xvfb" ":77" "-screen" "0" "2560x1200x24" "-nolisten" "tcp"))
   (wfx p) (: g2 (gather p) (? (two? g2) g2 (: _ (rest 2) (wfx p))))
   (waitsock t) (? (< t 1) ()
                  (: p (connectu dpy)
                     (? (lit? p) (: _ (close p) 1)
                        (: _ (rest 50) (waitsock (- t 1))))))
 _ (? (! (two? xv))
      (: _ (puts "pier: ok (no Xvfb, skipped)") (nap 0))
      0)
 _ (assert (waitsock 100))

 ; GetImage (opcode 73, ZPixmap): w*h pixels back as a byte list
 (px-getimg s d x y w h)
  (: _ (x-w8 s 73) _ (x-w8 s 2) _ (x-w16 s 5)
     _ (x-w32 s d) _ (x-w16 s x) _ (x-w16 s y) _ (x-w16 s w) _ (x-w16 s h)
     _ (x-w32 s 4294967295) _ (x-flush s)
     hdr (x-reply s)
     (x-rbytes s (* 4 (u32 hdr 4))))
 (lit-in px) (foldl (\ a b (+ a (? (= 192 b) 1 0))) 0 px)

 ; the pier under test, on its own pty with a real child
 ; the child prints steadily, so a resize's FRESH grid refills on its own
 md (mind `("out/host/ai" "-l" "apps/wm/core.l" "-l" "apps/wm/wire.l" "-l" "apps/quay/berth.l"
            "-l" "apps/quay/pier.l"
            "-e" "(pier (L \"sh\" \"-c\" \"while true; do printf H; sleep 0.3; done\") \"/tmp/.X11-unix/X77\" ())"))
 _ (assert (two? md))

 ; our own eyes: a second connection; poll QueryTree until the window docks
 s (connectu dpy)
 sc (x-setup s ())
 _ (assert (two? sc) (= 24 (scr-depth sc)))
 (waitwin t) (? (< t 1) ()
                (: ws (x-querytree s (scr-root sc))
                   (? (two? ws) (cap ws) (: _ (rest 100) (waitwin (- t 1))))))
 win (waitwin 100)
 _ (assert (charm? win))
 ; GetImage on an unmapped window is a BadMatch -- wait for IsViewable
 (waitmap t) (? (< t 1) 0
                (? (= 2 (cap (x-attrs s win))) 1
                   (: _ (rest 50) (waitmap (- t 1)))))
 _ (assert (waitmap 100))

 ; read the first cell back off the server until the H lands: an H in the
 ; default pen paints 0xc0c0c0 strokes on black -- count the 0xc0 bytes
 (waitlit t) (? (< t 1) 0
                (: n (lit-in (px-getimg s win 0 0 8 16))
                   (? (< 30 n) n (: _ (rest 100) (waitlit (- t 1))))))
 _ (assert (< 30 (waitlit 100)))
 _ (assert (= 0 (lit-in (px-getimg s win 0 160 8 16))))  ; row ten: still sea

 ; the wm's move: retile us WIDE. fat rows must still ship in legal PutImage
 ; bands -- one over-long request would corrupt pier's whole stream (the bug
 ; a real desktop found: prompt painted, then garble and silence)
 _ (x-configure s win 0 0 2560 1184)
 _ (x-flush s)
 (waitlit2 t) (? (< t 1) 0
                (: n (lit-in (px-getimg s win 0 0 8 16))
                   (? (< 30 n) n (: _ (rest 100) (waitlit2 (- t 1))))))
 _ (assert (< 30 (waitlit2 100)))                        ; the wide frame shipped

 ; step away: the child dies, the pier follows
 pid (cap md)
 _ (still pid 15)
 st (wfx pid)
 _ (assert (two? st))
 _ (close s)
 _ (close (cup md))
 _ (still (cap xv) 15)
 _ (wfx (cap xv))
 (puts "pier: ok"))
