; test/host/lorewin.l -- lore in a window, headless: a window with no screen ('evq its events)
; under view's loop, the keys as the actions they bind -- a press once, a walking key again
; while it is held at the level's pace, not when the level says not now, the keyboard's own
; repeat no press, q the end, ? the help while it is held
; -- and the corridor painted onto its paper at 8 by 16 a cell, the picture and the bottom
; row's words over it.
; not in the corpus: crew modules. run: cat test/00-init.l test/host/lorewin.l | out/love
(borrow 'view)
(borrow 'corridor)
(borrow 'posix)

(: _ (setenv "HORN" "none")
   ; the events frame t reads, each left in the queue by the frame before: k held through
   ; frames 0 to 2, p pressed at 3 and let go at 4, q at 6; or ? down at 1, up at 3
   script {0 [['down 37]] 3 [['up 37] ['down 25]] 4 [['up 25]] 6 [['down 16]]}
   ; ..k held, its keyboard repeating at frames 1 and 2
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

; --- the corridor on a window's paper: the picture where the hall is lit, and with p the
; --- bottom row's words, their ground and a letter's ink
(: hall (corridor-load "src/apps/lore/levels/hall.l")
   win {'w 640 'h 400 'paper (cask (640 * 400 * 4))}
   st (corridor-size (pins (corridor-new 80 50 hall "src/apps/lore/levels/") 'win win 'deep 1) 80 25)
   out (corridor-frame st)
   (rgb x y) (4 * (y * 640 + x) @ i (string (win 'paper) @ p [(p (i + 2)) (p (i + 1)) (p i)]))
   lit (net (map (i \ (rgb (i * 37 % 640) (i * 53 % 384) != [0 0 0])) ^200))
   ; ..each of the picture's pixels a 2 by 2 square, the scale unless said
   sq (all (i \ (: x (2 * (i * 37 % 320)) y (2 * (i * 23 % 190)) c (rgb x y)
                  (c = rgb (x + 1) y && c = rgb x (y + 1) && c = rgb (x + 1) (y + 1)))) ^200)
   _ (pin st 'pos 1)
   _ (corridor-frame st)
   ground (rgb 636 392)
   ink (any (y \ any (x \ rgb x y = [238 238 238]) (map (+ 8) ^8)) (map (+ 384) ^16))
 (test (out = "") (st 'kp = 4) (100 < lit) sq (ground = [20 20 20]) ink
       (tablet? (corridor-opts ["--window"])) ((corridor-opts ["--window"]) 'md = 'window)))

(test_fin (),
 puts "lorewin: ok -- a held key walks at its pace, the keyboard's repeat no press, a pressed one acts once, and the corridor paints its window\n")
