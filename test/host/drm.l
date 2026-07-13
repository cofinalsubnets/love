; --- test/host/drm.l: the metal enumerated -- DRM/KMS over the ioctl nif ---
; opens the first live card and holds the SHAPES: a two-call GETRESOURCES
; agrees with itself, every connector answers a known connection state, a
; connected one carries sane modes (real width/height, the raw 68 bytes
; whole). the MODESET half (master, a dumb fb brushed solid, SETCRTC) runs
; only when the card grants master -- a vt of one's own, or vkms; beside a
; live display server it answers -EACCES and the gate says so politely.
; no card at all -> a polite skip (the sentinel still prints).
;
;   cat test/00-init.l test/host/drm.l | out/host/ai
(reads (open "crew/phos/core.l" "r"))
(reads (open "crew/haven/wire.l" "r"))
(reads (open "crew/haven/drm.l" "r"))
(: (must tag v) (? v v (: _ (puts "drm: FAIL ") _ (putx tag) _ (putc 10) (quit 1)))
   ; prefer a card that GRANTS master (vkms, a free vt) -- the modeset half
   ; runs there; else the first card that opens (enumeration-only)
   (findcard k best) (? (< 3 k) best
                        (: p (drm-open k)
                           (? (! (lit? p)) (findcard (+ k 1) best)
                              (= 0 (drm-master p))
                                (: _ (drm-unmaster p)
                                   _ (? (lit? best) (close best) 0)
                                   p)
                              (lit? best) (: _ (close p) (findcard (+ k 1) best))
                              (findcard (+ k 1) p))))
   p (findcard 0 ())
 _ (? (! (lit? p)) (: _ (puts "drm: ok (no card, skipped)") (quit 0)) 0)
 res (drm-res p)
 _ (must 'resources (two? res))
 _ (must 'crtcs (two? (cap res)))
 conns (caup res)
 _ (must 'connectors (two? conns))
 lit ()                                       ; the first CONNECTED connector, if any
 lit (: (go l) (? (! (two? l)) ()
                  (: c (drm-conn p (cap l))
                     _ (must 'conn-shape (two? c))
                     _ (must 'conn-answer (|| (= 1 (cap c)) (|| (= 2 (cap c)) (= 3 (cap c)))))
                     (? (= 1 (cap c))
                        (: ms (nthl c 4)
                           _ (must 'modes (two? ms))
                           m (cap ms)
                           _ (must 'mode-sane (&& (< 0 (cap m)) (< 0 (caup m))))
                           _ (must 'mode-raw (= 68 (tally (nthl m 3))))
                           (L (cap l) m))
                        (go (cup l)))))
        (go conns))

 ; the modeset half: only where the card grants master (never beside a
 ; live server). dumb fb at the native mode, brushed steel blue, set,
 ; held a beat, unmade -- rc 0 at every step is the law
 mr (drm-master p)
 _ (? (? (= 0 mr) (two? lit) 0)
      (: conn (cap lit) m (caup lit) w (cap m) h (caup m) raw (nthl m 3)
         enc (drm-encoder p (: c (drm-conn p conn) (caup c)))
         crtc (? (? (two? enc) (< 0 (caup enc)) 0) (caup enc) (cap (cap res)))
         db (drm-dumb p w h)
         _ (must 'dumb (two? db))
         hd (cap db) pitch (caup db) size (nthl db 2)
         fb (drm-fb p w h pitch hd)
         _ (must 'fb (charm? fb))
         ptr (drm-map p hd size)
         _ (must 'map (charm? ptr))
         row (cask pitch)
         (brush i) (? (< i w)
                      (: _ (pin row (* i 4) 180) _ (pin row (+ (* i 4) 1) 100)
                         _ (pin row (+ (* i 4) 2) 70) (brush (+ i 1)))
                      0)
         _ (brush 0)
         (paint y) (? (< y h) (: _ (mapout ptr (* y pitch) row 0 pitch) (paint (+ y 1))) 0)
         _ (paint 0)
         sr (drm-set p crtc fb conn raw)
         _ (must 'setcrtc (= 0 sr))
         _ (rest 400)
         _ (unmap ptr size)
         _ (drm-rmfb p fb)
         _ (drm-rmdumb p hd)
         _ (drm-unmaster p)
         _ (puts "drm: MODESET -- the glass was ours")
         (putc 10))
      (: _ (puts "drm: enumerated (no master or no monitor -- modeset skipped)")
         (putc 10)))

 ; evdev: the input half needs only open (a fd port; events read as bytes)
 _ (: e (open "/dev/input/event0" "r")
      (? (lit? e) (: _ (close e) _ (puts "drm: evdev opens") (putc 10))
         (: _ (puts "drm: evdev closed to us (no seat acl)") (putc 10))))
 _ (close p)
 (puts "drm: ok"))
