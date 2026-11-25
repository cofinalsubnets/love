; test/host/lorewin.l -- view's loop on a headless window ('evq its events): keys to actions,
; held keys at the level's pace, repeat no press, ? help; and the world painted on its paper.
; not in the corpus: crew modules. run: cat test/00-init.l test/host/lorewin.l | out/love
(borrow '(view console cli world posix window lore))

(: _ (setenv "HORN" "none")
   _ (setenv "LOVE_NEST" (cwd 0 + "/out/.lorewin-nest-" + show (getpid 0)))   ; no nest: no scene kept
   ; events by frame: k held 0-2, p at 3-4, q at 6; or ? down 1-3
   script {0 [['down 37]] 3 [['up 37] ['down 25]] 4 [['up 25]] 6 [['down 16]]}
   ; ..k held, repeating at frames 1 and 2
   echoed {0 [['down 37]] 1 [['down 37]] 2 [['down 37]] 3 [['up 37] ['down 25]] 4 [['up 25]] 6 [['down 16]]}
   asked {1 [['down 42] ['down 53] ['text "?"]] 3 [['up 53] ['up 42]] 5 [['down 16]]}
   ; ..+ finer, then - twice coarser: 2 to 1, 2 and 4
   scaled {1 [['down 13] ['text "+"]] 2 [['up 13] ['down 12] ['text "-"]] 3 [['up 12] ['down 12] ['text "-"]] 5 [['down 16]]}
   ; ..w held 0-4, shift down from 2 to 4: the held w its capital while shift is
   shifted {0 [['down 17] ['text "w"]] 2 [['down 42]] 4 [['up 42]] 5 [['up 17]] 7 [['down 16]]}
   (run sc held rep) (: win {'w 640 'h 400 'paper (cask (640 * 400 * 4)) 'evq (peep sc 0 ())}
                    lv {'new (w \ h \ {'w w 'h h 't 0 'log () 'helped ()})
                        'size (st \ w \ r \ pins st 'w w 'h (2 * r))
                        'frame (st \ ((0 < #(keys (peep st 'over {})) ? (pin st 'helped (st 't . st 'helped))), ""))
                        'key (st \ a \ pin st 'log ([(st 't) a] . st 'log))
                        'tick (st \ pin win 'evq (peep sc (st 't + 1) ()))
                        'binds (view-bind view-binds {112 'where 119 'forward 87 'sprint}) 'walking (view-walking + ['sprint])
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
   g (run shifted (_ \ 1) ev)
 (test (a 0 = [[0 'forward] [1 'forward] [2 'forward] [3 'where]])   ; k each frame held, then p once
       (b 0 = [[0 'forward] [3 'where]])                              ; held, but the level says not now
       (e 0 = [[0 'forward] [3 'where]])                              ; the keyboard's repeat is no press
       (f 0 = a 0)                                                    ; nor a second one a frame
       (a 1 = 80) (a 2 = 50)                                          ; 640 by 400: 80 cells by 25 rows
       (c 3 = [1 2]) (c 0 = ()) (d 4 = 4) (d 0 = ()) (a 4 = ())
       (g 0 = [[0 'forward] [1 'forward] [2 'sprint] [3 'sprint] [4 'forward]])))   ; shift turns a held w to a sprint and back                                     ; the help while ? is down, and no action

; a window's buttons go to the level's 'mouse, pressed and let go; where it looks by the
; mouse only once that is held, so the first click takes the mouse and goes no further
(: lwm {1 [['press 1 9 9]] 2 [['release 1 9 9]] 3 [['press 3 9 9]] 5 [['down 16]]}
   (lwrun look) (: win {'w 640 'h 400 'paper (cask (640 * 400 * 4)) 'evq ()}
                  lv {'new (w \ h \ {'w w 'h h 't 0 'log ()})
                      'size (st \ w \ r \ pins st 'w w 'h (2 * r)) 'frame (st \ "") 'key (st \ a \ st)
                      'mouse (st \ e \ b \ pin st 'log ([(st 't) e b] . st 'log))
                      'tick (st \ pin win 'evq (peep lwm (st 't + 1) ()))
                      'fps 100 'linger 0 'next () 'song (_ \ ()) 'win win}
                  st (view-walk (look ? (pin lv 'look (st \ dx \ dy \ st)) lv))
                  (rev (st 'log)))
 (test (lwrun 0 = [[1 'press 1] [2 'release 1] [3 'press 3]]) (lwrun 1 = ())))

; the gauge: a frame resting a ms each 2560 pixels at its scale, 25 ms at 2 for a 20 ms goal,
; steps once to 4 and holds there; a key by hand stops it, and 1 holds though it is over
(: (lwg sc n) (: win {'w 640 'h 400 'paper (cask 4) 'evq ()}
                 (sized st) (pins st 'pic-w (640 // st 'scale) 'pic-h (400 // st 'scale))
                 lv {'new (w \ h \ sized {'w w 'h h 't 0 'scale 2 'seen ()})
                     'size (st \ w \ r \ sized st) 'key (st \ a \ st)
                     'frame (st \ (rest (st 'pic-w * st 'pic-h // 2560), pin st 'seen (st 'scale . st 'seen)))
                     'tick (st \ pin win 'evq (peep sc (st 't + 1) (st 't + 1 < n ? () [['down 16]])))
                     'fps 50 'linger 0 'next () 'song (_ \ ()) 'win win}
                 (uniq (rev ((view-walk lv) 'seen))))
 (test (lwg {} 60 = [2 4]) (lwg {1 [['down 13] ['text "+"]] 2 [['up 13]]} 14 = [2 1])
       ; ..and 0 sets it going again, from the scale the key left
       (lwg {1 [['down 13] ['text "+"]] 2 [['up 13]] 4 [['down 11] ['text "0"]] 5 [['up 11]]} 80 = [2 1 4])))
; the console: ~ opens it, letting go what is held and giving the scene less of the window;
; meanwhile keys are typed, q and ~ too, and act on nothing; enter answers a line, up brings it
; back, ctrl-d shuts it and the scene has its size again
(: con {0 [['down 37] ['text "k"]] 2 [['down 42] ['down 41] ['text "~"]] 3 [['down 41] ['text "~"] ['up 41] ['up 42] ['up 37]]
        4 (catmap (t \ [['down 2] ['text t] ['up 2]]) ["s" "a" "y" " " "(" "0" " " "~" " " "9" "q"] + [['down 14] ['up 14] ['down 2] ['text ")"] ['up 2] ['down 28] ['text "\r"] ['up 28]])
        5 [['down 328] ['up 328] ['down 28] ['up 28]] 6 [['down 29] ['down 32] ['text "d"] ['up 32] ['up 29]] 8 [['down 25] ['text "p"] ['up 25]] 10 [['down 16] ['text "q"]]}
   win {'w 640 'h 400 'paper (cask (640 * 400 * 4)) 'evq (con 0)}
   st (view-walk {'new (w \ h \ {'w w 'h h 't 0 'log () 'said () 'sizes () 'helped ()}) 'size (st \ w \ r \ pins st 'w w 'h (2 * r) 'sizes ([w r] . st 'sizes))
                  'frame (st \ ((0 < #(keys (peep st 'over {})) ? (pin st 'helped (st 't . st 'helped))), ""))
                  'key (st \ a \ pin st 'log ([(st 't) a] . st 'log)) 'words (st \ [["say" "" (x \ (pin st 'said (x . st 'said), x))]])
                  'tick (st \ pin win 'evq (peep con (st 't + 1) ())) 'binds (view-bind view-binds {112 'where}) 'walking view-walking
                  'fps 100 'linger 0 'next () 'song (_ \ ()) 'win win 'held (_ \ 1) 'repeat [0 0]}))
 (test (rev (st 'log) = [[0 'forward] [1 'forward] [8 'where]]) (st 'said = [(0 ~ 9) (0 ~ 9)]) (rev (st 'helped) = [2 3 4 5])
       (rev (st 'sizes) = [[80 14] [80 25]]))
; a phone's: a tap at the top's middle opens it, beside the scene, the keyboard up and the touches
; the panes'; the same spot, esc or Back puts it away, and Back alone does nothing, the thumbs back and the screen all the scene's
(: tap (_ \ [['finger 1 0 320 10] ['finger 1 1 320 10]]) back (_ \ [['down 362] ['up 362]]) path ("/tmp/lorewin-face-" + show (getpid 0)) ls (listen ['unix path])
   srv (twirl (_ \ (: _ (await ls) c (accept ls) (slurp c))) ()) line (connect ['unix path])
   con {0 [['finger 1 0 100 200] ['finger 1 1 100 200]] 2 (tap 0) 4 [['press 1 320 10] ['release 1 320 10]] 6 (tap 0) 8 [['down 1] ['up 1]]
       9 (back 0) 10 (tap 0) 12 (back 0) 14 [['finger 1 0 10 10] ['finger 1 1 10 10]]}
   win {'how 'droid 's line 'w 640 'h 400 'H 400 'row 0 'held () 'paper (cask (640 * 400 * 4)) 'said (con 0)}
   st (view-walk {'new (w \ h \ {'w w 'h h 't 0 'win win 'sizes () 'typing () 'thumbs () 'gpu ()}) 'size (st \ w \ r \ pins st 'w w 'h (2 * r) 'sizes ([w r] . st 'sizes))
                  'frame (_ \ "") 'key (st \ a \ st)
                  'tick (st \ (pins st 'typing (peep win 'typing 0 . st 'typing) 'thumbs (peep win 'thumbs 0 . st 'thumbs), pin win 'said (peep con (st 't + 1) ())))
                  'stick [119 115 97 100 87] 'binds view-binds 'fps 100 'linger 0 'next () 'song (_ \ ()) 'win win})
 z (close line, catch srv, close ls, unlink path)
 (test (elem 1 (st 'typing)) (st 'typing 0 = 0) (st 'thumbs 0 = 1) (all (i \ st 'typing i = 1 - st 'thumbs i) ^#(st 'typing))
       (rev (st 'typing) @ l (filter (i \ 0 < i && l i = 1 && l (i - 1) = 0) ^#l) = [2 6 10])
       (0 < #(filter (q \ q 0 < 60) (st 'sizes))) (st 'sizes 0 = [80 25])))
; the panes: the scene over the console, a bar between, the screen all the scene's while it is
; away; ctrl-w m puts them side by side, x trades them, and the split is kept for the next time
(: co (con-new ()) l0 (con-lay co 80 24) _ (con-up co 1) l1 (con-lay co 80 24)
   (cw c) (: _ (con-key co (_ \ "") 23) _ (con-key co (_ \ "") c) (con-lay co 80 24))
   l2 (cw 109) l3 (cw 120) bx (con-box co (l3 1)) _ (cw 119) f (con-keyed? co) _ (con-up co 0) l4 (con-lay co 80 24) _ (con-up co 1) l5 (con-lay co 80 24)
 (test (l0 = [[0 0 80 24] ()]) (l1 = [[0 0 80 13] [0 14 80 10]]) (l2 = [[0 0 47 24] [48 0 32 24]]) (l3 = [[32 0 48 24] [0 0 31 24]])
       (bx 0 = 0) (#(bx 2) = 24) !f (l4 = [[0 0 80 24] ()]) (l5 = l3)))
; ctrl-c drops the line typed and leaves the console up, and stops what runs
(: co (con-new ()) _ (con-up co 1) _ (each ["1 + " 3 "2" 13] (con-key co (l \ "=" + l)))
   (spin _) (spin ()) n {'n 0}
 (test (con-keyed? co) (rev (co 'log) = ["> 1 + ^C" "> 2" "=2"]) (con-task (_ \ "a") (_ \ 1) = "a")
       (con-task spin (_ \ (pin n 'n (n 'n + 1), 2 < n 'n)) = "^C") (n 'n = 3)))
; a press on the scene gives it the keys and goes on to it, one on the console does not; a
; terminal's keys are the console's while it has them, and eof puts it away
(: co (con-new ()) _ (con-up co 1) _ (con-lay co 80 24) (ev e) (con-event co (l \ l) e "" (_ \ ()) 0)
   a (ev ['press 1 8 300]) ka (con-keyed? co) b (ev ['press 1 8 8]) kb (con-keyed? co) d (con-term co (l \ l) 97 0) o (con-term co (l \ l) 126 1) ko (con-keyed? co)
   x (con-term co (l \ l) 97 0) t (edtext (co 'ed)) _ (con-term co (l \ l) -7 0)
 (test (a = 1) ka (b = 0) !kb (d = 97) (o = ()) ko (x = ()) (t = "a") !(co 'on)))
; page up and down scroll what was said
(: co (con-new ()) _ (con-up co 1) _ (each ^30 (i \ (con-key co (l \ l) (show i), con-key co (l \ l) 13))) l (con-lay co 80 24)
   top (_ \ con-box co (l 1) 2 1) a (top ()) _ (con-key co (l \ l) -14) b (top ()) _ (con-key co (l \ l) -15) c (top ())
 (test (a != b) (a = c)))
; a terminal's frame moved to where its pane is
(: e (string 27) (test (con-shift (e + "[Hab\r\ncd" + e + "[1mx" + e + "[3;4He") 10 2 = (e + "[3;11H" + e + "[3;11Hab\r\n" + e + "[10Ccd" + e + "[1mx" + e + "[5;14He")) (con-shift "q" 0 0 = "q")))

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
       (tablet? (world-opts ["--window"])) ((world-opts ["--window"]) 'md = 'window) ((world-opts ["-w"]) 'md = 'window)))

; ..and in a bigger window the picture is the window over the scale: at 8 each of its pixels
; 8 by 8 of the window's
(: hall (world-load "test/lore/hall.l") big {'w 1280 'h 800 'paper (cask 4)}
   s8 (world-size (pins (world-new 160 100 hall "test/lore/") 'win big 'deep 1 'scale 8) 160 50)
 (test (s8 'pic-w = 160) (s8 'pic-h = 100)))

; the loading screen: view-spin blacks its box and puts the moon in the middle, a fifth of
; the box across as pom draws it: new to begin, dark but for earthshine, its right half lit a
; quarter through, full at half, and after shows only the moon's rows; in a terminal its
; faces. and view-loading draws only once the making has taken a moment, then not again
; within a frame
(: win {'w 640 'h 400 'paper (cask (640 * 400 * 4))}
   (rgb x y) (4 * (y * 640 + x) @ i (string (win 'paper) @ p [(p (i + 2)) (p (i + 1)) (p i)]))
   _ (frame-paint (iota (640 * 400) * 0 + 0xffffff) 640 1 (win 'paper) 640)
   s0 (view-spin {'win win 'box [0 0 320 400] 'n 0}) new (rgb 160 200) s1 (view-spin {'win win 'box [0 0 320 400] 'n 6})
   qr (rgb 175 200) ql (rgb 145 200) _ (view-spin {'win win 'box [0 0 320 400] 'n 12}) full [(rgb 145 200) (rgb 175 200)]
   (lum c) (c 0 + c 1 + c 2)
   big (view-spin {'win {'w 1200 'h 1000 'paper (cask (1200 * 1000 * 4))} 'box [0 0 1200 1000] 'n 1})
   tw (view-spin {'win () 'box [0 0 80 24] 'n 3})
   c {'n 0} tk (view-loading () [0 0 80 24] (ld \ (pin c 'n (c 'n + 1), pin c 'ld ld, "")))
   _ (tk 'early ()) n0 (c 'n) _ (rest 200) _ (tk 'cuts 0.5) n1 (c 'n) _ (tk 'cuts 0.6) n2 (c 'n)
 (test (s0 = ()) (s1 = [168 232]) (big = [400 600]) (rgb 10 10 = [0 0 0]) (rgb 600 10 = [255 255 255])
       (0 < lum new) (lum new < 120) (lum qr > 400) (lum ql < 60) (all (c \ lum c > 300) full)
       (has? tw "\u{1f312}")
       (n0 = 0) (n1 = 1) (n2 = 1) (c 'ld 'what = 'cuts) (c 'ld 'part = 0.5) (c 'ld 'n = 0) (c 'ld 'ms >= 150)))
; ..a window resized before the loading screen draws: the moon in the middle of its new size,
; the events read on the way kept for the walk
(: rw {'w 320 'h 200 'paper (cask (320 * 200 * 4)) 'evq [['size 800 600] ['down 16]]}
   tk (view-loading rw () view-spin) _ (rest 200) _ (tk 'cuts 0.5)
   (at x y) (4 * (y * 800 + x) @ i (string (rw 'paper) @ p [(p (i + 2)) (p (i + 1)) (p i)]))
 (test (window-size rw = [800 600]) (0 < at 400 300 0) (at 400 300 0 < 60) (at 300 300 = [0 0 0]) (window-events rw = [['down 16]])))
; ..and resized while it draws: the draw after told the box is fresh, so the moon blacks it
; whole again and shows it all, the moon's old place too
(: fw {'w 320 'h 200 'paper (cask (320 * 200 * 4)) 'evq ()} fs {'l ()}
   tk (view-loading fw () (ld \ (pin fs 'l (fs 'l + [(ld 'fresh)]), ())))
   _ (rest 200) _ (tk 'cuts 0.1) _ (rest 60) _ (tk 'cuts 0.2) _ (pin fw 'evq [['size 400 300]]) _ (rest 60) _ (tk 'cuts 0.3) _ (rest 60) _ (tk 'cuts 0.4)
   pw {'w 320 'h 200 'paper (cask (320 * 200 * 4))} _ (frame-paint (iota (320 * 200) * 0 + 0xffffff) 320 1 (pw 'paper) 320)
   f0 (view-spin {'win pw 'box [0 0 320 200] 'n 5 'fresh 0}) w0 (string (pw 'paper) 0)
   f1 (view-spin {'win pw 'box [0 0 320 200] 'n 6 'fresh 1}) w1 (string (pw 'paper) 0)
 (test (fs 'l = [1 0 1 0]) (two? f0) (w0 = 255) (f1 = ()) (w1 = 0)))

(test_fin (),
 puts "lorewin: ok -- a held key walks at its pace, the keyboard's repeat no press, a pressed one acts once, and the world paints its window\n")
