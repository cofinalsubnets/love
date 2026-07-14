; crew/haven/metal.l -- the real session: haven on the metal. the DRM dumb
; buffer is the glass, evdev the hands, and the SAME harbor as the nested X
; entry carries everything else -- protocols, layouts, moor, painter. run
; from a tty of one's own (the card must grant master):
;
;   ai -l crew/lux/core.l -l crew/lux/layout.l -l crew/haven/wire.l \
;      -l crew/haven/drm.l -l crew/haven/haven.l -l crew/haven/metal.l \
;      -e '(metal "/run/user/1000/haven-0" 1)'
;
; (haven.l's X entry prints `;; missing` scares at load without the X wire
; -- harmless, the metal path never calls them.) the console flips to
; KD_GRAPHICS (fbcon stops drawing over the glass) and stdin goes raw; the
; keyboard is NOT muted, so ctrl-alt-Fn -- the escape hatch -- stays alive,
; and a parted session restores the console from any other tty over the
; moor: `ain <path>.moor` then (metal-text ()).
; a body-LESS `:` -- the helpers leak; none shadows a nif.
(:
   ; --- the console: KDSETMODE 0x4B3A on /dev/tty (0 text, 1 graphics) ---
   (metal-mode m) (: t (open "/dev/tty" "r")
                     (? (lit? t) (: r (ioctl t 19258 m) _ (close t) r) -1))
   (metal-text u) (metal-mode 0)

   ; --- evdev: input_event is 24 bytes -- sec u64, usec u64, type u16 at
   ;     16, code u16 at 18, value s32 at 20. see parks per byte (the
   ;     reader's park law: a quiet device costs nothing) ---
   (ev-rd24 p b) (: (go i) (? (< i 24)
                              (: c (see p)
                                 (? (= c -1) () (: _ (pin b i c) (go (+ i 1)))))
                              1)
                    (go 0))
   (ev-code b) (| (peep b 18 0) (<< (peep b 19 0) 8))
   (ev-val b) (: v (wl-u32 b 20) (? (< v 2147483648) v (- v 4294967296)))
   (ev-ms b) (& 4294967295 (+ (* (wl-u32 b 0) 1000) (// (wl-u32 b 8) 1000)))
   ; modifiers by evdev code: meta -> sup(64), shift 1, ctrl 4, alt 8
   ev-mods '((125 64) (126 64) (42 1) (54 1) (29 4) (97 4) (56 8) (100 8))
   ; the qwerty rows: ascii keysym -> evdev code (the harbor's keycodes
   ; ride +8, the X fold in reverse -- one keycode space everywhere)
   ev-keys '((113 16) (119 17) (101 18) (114 19) (116 20) (121 21) (117 22) (105 23) (111 24) (112 25)
             (97 30) (115 31) (100 32) (102 33) (103 34) (104 35) (106 36) (107 37) (108 38)
             (122 44) (120 45) (99 46) (118 47) (98 48) (110 49) (109 50)
             (49 2) (50 3) (51 4) (52 5) (53 6) (54 7) (55 8) (56 9) (57 10) (48 11)
             (32 57) (65293 28))
   (ev-sym sym) (: v (afind (\ r (= (cap r) sym)) ev-keys)
                   (? (two? v) (+ (caup v) 8) 0))
   (clamp v lo hi) (? (< v lo) lo (< hi v) hi v)

   ; --- the metal harbor: master the card, set the native mode on the
   ;     first connected connector, and moor the same shore ---
   (metal path k)
     (: p (drm-open k)
        (? (! (lit? p)) 'no-card
         (: mr (drm-master p)
            (? (! (= 0 mr)) (: _ (close p) 'no-master)
             (: res (drm-res p)
                hit (: (go l) (? (! (two? l)) ()
                                 (: c (drm-conn p (cap l))
                                    (? (? (two? c) (= 1 (cap c)) 0)
                                       (L (cap l) c)
                                       (go (cup l)))))
                       (go (caup res)))
                (? (! (two? hit)) (: _ (close p) 'no-monitor)
                 (: conn (cap hit) c (caup hit)
                    m (cap (nthl c 4)) w (cap m) h (caup m) raw (nthl m 3)
                    enc (drm-encoder p (caup c))
                    crtc (? (? (two? enc) (< 0 (caup enc)) 0) (caup enc) (cap (cap res)))
                    db (drm-dumb p w h)
                    (? (! (two? db)) (: _ (close p) 'no-dumb)
                     (: hd (cap db) pitch (caup db) size (nthl db 2)
                        fbid (drm-fb p w h pitch hd)
                        ptr (? (charm? fbid) (drm-map p hd size) ())
                        (? (! (charm? ptr)) (: _ (close p) 'no-fb)
                         (: sr (drm-set p crtc fbid conn raw)
                            (? (! (= 0 sr)) (: _ (close p) 'no-modeset)
                             (: fb (cask (* w (* h 4)))
                                x (L () () () () w h)
                                rowb (* w 4)
                                ; the pointer: a cell the readers move, a
                                ; white 8x12 block the ship draws over
                                cur (tablet 2)
                                _ (pin cur 0 (// w 2)) _ (pin cur 1 (// h 2))
                                wrow (cask 32)
                                _ (: (go i) (? (< i 32) (: _ (pin wrow i 255) (go (+ i 1))) 0) (go 0))
                                (ship f)
                                  (: _ (? (= pitch rowb)
                                          (mapout ptr 0 f 0 (* h rowb))
                                          (: (go y) (? (< y h)
                                                       (: _ (mapout ptr (* y pitch) f (* y rowb) rowb)
                                                          (go (+ y 1)))
                                                       0)
                                             (go 0)))
                                     cx (peep cur 0 0) cy (peep cur 1 0)
                                     (go j) (? (< j 12)
                                               (? (< (+ cy j) h)
                                                  (: _ (mapout ptr (+ (* (+ cy j) pitch) (* cx 4)) wrow 0 32)
                                                     (go (+ j 1)))
                                                  0)
                                               0)
                                     (go 0))
                                (attach hb tl)
                                  (: _ (pin hb 13 (: t (tablet 64)
                                                     _ (map (\ r (pin t (cap r) (+ (caup r) 8))) ev-keys)
                                                     t))
                                     _ (pin hb 12 (hv-ktab ev-sym))
                                     mods (tablet 2) _ (pin mods 0 0)
                                     (onkey b)
                                       (: code (ev-code b)
                                          press (? (= 0 (ev-val b)) 0 1)   ; 2 = repeat rides as press
                                          mb (afind (\ r (= (cap r) code)) ev-mods)
                                          (? (two? mb)
                                             (pin mods 0 (? press (| (peep mods 0 0) (caup mb))
                                                            (& (peep mods 0 0) (- 255 (caup mb)))))
                                             (= code 272) (hv-ptrbtn hb tl (ev-ms b) 1 press)
                                             (= code 273) (hv-ptrbtn hb tl (ev-ms b) 3 press)
                                             (= code 274) (hv-ptrbtn hb tl (ev-ms b) 2 press)
                                             (hv-keyev hb tl (ev-ms b) (+ code 8) press (peep mods 0 0))))
                                     (onrel b)
                                       (: code (ev-code b) v (ev-val b)
                                          _ (? (= code 0) (pin cur 0 (clamp (+ (peep cur 0 0) v) 0 (- w 9)))
                                               (= code 1) (pin cur 1 (clamp (+ (peep cur 1 0) v) 0 (- h 13)))
                                               0)
                                          _ (pin hb 5 1)                   ; the pointer moved: repaint
                                          (hv-ptrmove hb tl (ev-ms b) (peep cur 0 0) (peep cur 1 0)))
                                     (reader p2)
                                       (: b (cask 24)
                                          (go _) (? (ev-rd24 p2 b)
                                                    (: ty (| (peep b 16 0) (<< (peep b 17 0) 8))
                                                       _ (? (= ty 1) (onkey b)
                                                            (= ty 2) (onrel b)
                                                            0)
                                                       (go ()))
                                                    (close p2)))
                                     (scan i) (? (< 15 i) 0
                                                 (: p2 (open (+ "/dev/input/event" (show i)) "r")
                                                    _ (? (lit? p2) (twirl (\ u (reader p2)) 0) 0)
                                                    (scan (+ i 1))))
                                     (scan 0))
                                _ (metal-mode 1)                           ; fbcon lets go of the glass
                                _ (raw 1)                                  ; keystrokes stop echoing behind us
                                (hv-harbor path x fb ship attach)))))))))))))))
