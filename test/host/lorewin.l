; test/host/lorewin.l -- view's loop on a headless window ('evq its events): keys to actions,
; held keys at the level's pace, repeat no press, ? help; and the world painted on its paper.
; not in the corpus: crew modules. run: cat test/00-init.l test/host/lorewin.l | out/love
(borrow 'view)
(borrow 'world)
(borrow 'posix)
(borrow 'window)

(: _ (setenv "HORN" "none")
   ; events by frame: k held 0-2, p at 3-4, q at 6; or ? down 1-3
   script {0 [['down 37]] 3 [['up 37] ['down 25]] 4 [['up 25]] 6 [['down 16]]}
   ; ..k held, repeating at frames 1 and 2
   echoed {0 [['down 37]] 1 [['down 37]] 2 [['down 37]] 3 [['up 37] ['down 25]] 4 [['up 25]] 6 [['down 16]]}
   asked {1 [['down 42] ['down 53] ['text "?"]] 3 [['up 53] ['up 42]] 5 [['down 16]]}
   ; ..+ finer, then - twice coarser: 2 to 1, 2 and 4
   scaled {1 [['down 13] ['text "+"]] 2 [['up 13] ['down 12] ['text "-"]] 3 [['up 12] ['down 12] ['text "-"]] 5 [['down 16]]}
   (run sc held rep) (: win {'w 640 'h 400 'paper (cask (640 * 400 * 4)) 'evq (peep sc 0 ())}
                    lv {'new (w \ h \ {'w w 'h h 't 0 'log () 'helped ()})
                        'size (st \ w \ r \ pins st 'w w 'h (2 * r))
                        'frame (st \ ((0 < #(keys (peep st 'over {})) ? (pin st 'helped (st 't . st 'helped))), ""))
                        'key (st \ a \ pin st 'log ([(st 't) a] . st 'log))
                        'tick (st \ pin win 'evq (peep sc (st 't + 1) ()))
                        'binds (view-bind view-binds {112 'where})
                        'fps 100 'linger 0 'next () 'song (_ \ ()) 'win win 'held held 'repeat rep}
                    st (view-walk lv)
                    [(rev (st 'log)) (st 'w) (st 'h) (rev (st 'helped)) (peep st 'scale ())])
   ev [0 0] none [100000 0]
   a (run script (_ \ 1) ev)
   b (run script (_ \ 0) ev)
   c (run asked (_ \ 1) ev)
   d (run scaled (_ \ 1) ev)
   e (run echoed (_ \ 1) none)
   f (run echoed (_ \ 1) ev)
 (test (a 0 = [[0 'forward] [1 'forward] [2 'forward] [3 'where]])   ; k each frame held, then p once
       (b 0 = [[0 'forward] [3 'where]])                              ; held, but the level says not now
       (e 0 = [[0 'forward] [3 'where]])                              ; the keyboard's repeat is no press
       (f 0 = a 0)                                                    ; nor a second one a frame
       (a 1 = 80) (a 2 = 50)                                          ; 640 by 400: 80 cells by 25 rows
       (c 3 = [1 2]) (c 0 = ()) (d 4 = 4) (d 0 = ()) (a 4 = ())))                                     ; the help while ? is down, and no action

; the world on a window's paper: the lit hall, and with p the bottom row's words
(: hall (world-load "test/lore/hall.l")
   win {'w 640 'h 400 'paper (cask (640 * 400 * 4))}
   st (world-size (pins (world-new 80 50 hall "test/lore/") 'win win 'deep 1) 80 25)
   out (world-frame st)
   (rgb x y) (4 * (y * 640 + x) @ i (string (win 'paper) @ p [(p (i + 2)) (p (i + 1)) (p i)]))
   lit (net (map (i \ (rgb (i * 37 % 640) (i * 53 % 384) != [0 0 0])) ^200))
   ; ..each pixel a 2 by 2 square, the default scale
   sq (all (i \ (: x (2 * (i * 37 % 320)) y (2 * (i * 23 % 190)) c (rgb x y)
                  (c = rgb (x + 1) y && c = rgb x (y + 1) && c = rgb (x + 1) (y + 1)))) ^200)
   _ (pin st 'pos 1)
   _ (world-frame st)
   ground (rgb 636 392)
   ink (any (y \ any (x \ rgb x y = [238 238 238]) (map (+ 8) ^8)) (map (+ 384) ^16))
 (test (out = "") (st 'kp = 2) (100 < lit) sq (ground = [20 20 20]) ink
       (tablet? (world-opts ["--window"])) ((world-opts ["--window"]) 'md = 'window)))

; the loading screen: view-spin blacks its box and puts the moon in the middle, a fifth of
; the box across, new to begin, its right half lit a quarter through, full at half, and
; after shows only the moon's rows; in a terminal its faces. and view-loading draws only once the making has taken a moment, then
; not again within a frame
(: win {'w 640 'h 400 'paper (cask (640 * 400 * 4))}
   (rgb x y) (4 * (y * 640 + x) @ i (string (win 'paper) @ p [(p (i + 2)) (p (i + 1)) (p i)]))
   _ (frame-paint (iota (640 * 400) * 0 + 0xffffff) 640 1 (win 'paper) 640)
   s0 (view-spin {'win win 'box [0 0 320 400] 'n 0}) new (rgb 160 200) s1 (view-spin {'win win 'box [0 0 320 400] 'n 6})
   qr (rgb 175 200) ql (rgb 145 200) _ (view-spin {'win win 'box [0 0 320 400] 'n 12}) full [(rgb 145 200) (rgb 175 200)]
   big (view-spin {'win {'w 1200 'h 1000 'paper (cask (1200 * 1000 * 4))} 'box [0 0 1200 1000] 'n 1})
   tw (view-spin {'win () 'box [0 0 80 24] 'n 3})
   c {'n 0} tk (view-loading () [0 0 80 24] (ld \ (pin c 'n (c 'n + 1), pin c 'ld ld, "")))
   _ (tk 'early ()) n0 (c 'n) _ (rest 200) _ (tk 'cuts 0.5) n1 (c 'n) _ (tk 'cuts 0.6) n2 (c 'n)
 (test (s0 = ()) (s1 = [168 232]) (big = [401 599]) (rgb 10 10 = [0 0 0]) (rgb 600 10 = [255 255 255])
       (new = [36 39 44]) (qr = [232 228 214]) (ql = [36 39 44]) (full = [[232 228 214] [232 228 214]])
       (has? tw "\u{1f312}")
       (n0 = 0) (n1 = 1) (n2 = 1) (c 'ld 'what = 'cuts) (c 'ld 'part = 0.5) (c 'ld 'n = 0) (c 'ld 'ms >= 150)))
; ..a window resized before the loading screen draws: the moon in the middle of its new size,
; the events read on the way kept for the walk
(: rw {'w 320 'h 200 'paper (cask (320 * 200 * 4)) 'evq [['size 800 600] ['down 16]]}
   tk (view-loading rw () view-spin) _ (rest 200) _ (tk 'cuts 0.5)
   (at x y) (4 * (y * 800 + x) @ i (string (rw 'paper) @ p [(p (i + 2)) (p (i + 1)) (p i)]))
 (test (window-size rw = [800 600]) (at 400 300 = [36 39 44]) (at 300 300 = [0 0 0]) (window-events rw = [['down 16]])))

(test_fin (),
 puts "lorewin: ok -- a held key walks at its pace, the keyboard's repeat no press, a pressed one acts once, and the world paints its window\n")
