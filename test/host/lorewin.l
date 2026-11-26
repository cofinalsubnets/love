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
; the mouse held: a frame's moves turn by where the last came to, the first counted from the
; middle and each after from the one before; the pointer put back once a frame, and not from the middle
(: mv {1 [['press 1 9 9]] 2 [['move 323 200] ['move 326 201] ['move 329 203]] 3 [['move 322 200]] 4 [['move 320 200]] 6 [['down 16]]}
   win {'w 640 'h 400 'paper (cask (640 * 400 * 4)) 'evq () 'holds 1}
   lv {'new (w \ h \ {'w w 'h h 't 0 'log ()})
       'size (st \ w \ r \ pins st 'w w 'h (2 * r)) 'frame (st \ "") 'key (st \ a \ st)
       'look (st \ dx \ dy \ pin st 'log ([(st 't) dx dy] . st 'log))
       'tick (st \ pin win 'evq (peep mv (st 't + 1) ()))
       'fps 100 'linger 0 'next () 'song (_ \ ()) 'win win}
   st (view-walk lv)
 (test (rev (st 'log) = [[2 9 3] [3 2 0]]) (win 'warps = [[320 200] [320 200] [320 200]])))

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
; a looking thumb held still with a thing in hand is the button: the throw the same wind by the
; button gives, to the digit; a tap, a drag, the stick's side and empty hands are none
(: (lvl _) (: s (world-new 160 100 (world-read "(level \"t\" (room [0 0 0] [10 5 14]) (ball [5 0 3]) (start [5 0 1.5] 0 0))") "")
      _ (each ^2 (_ \ (pin s 'dt 0.05, world-move s))) _ (pin s 'ph (-44.6 * pi / 180.0)) _ (world-step s 'tap) (pin s 'ph 0.6))
   (run fs ws) (: path ("/tmp/lorewin-hold-" + show (getpid 0)) _ (unlink path) ls (listen ['unix path])
      srv (twirl (_ \ (: _ (await ls) c (accept ls) (slurp c))) ()) line (connect ['unix path])
      win {'how 'droid 's line 'w 640 'h 400 'H 400 'row 0 'held () 'paper (cask (640 * 400 * 4)) 'said (peep fs 0 ())}
      st (view-walk {'new (w \ h \ {'w w 'h h 't 0 'win win 'gpu () 'ev ()}) 'size (st \ w \ r \ pins st 'w w 'h (2 * r)) 'frame (_ \ "") 'key (st \ a \ st)
                     'tick (st \ (pin ws 'dt 0.05, world-move ws, pin win 'said (peep fs (st 't + 1) ()), (60 < st 't ? (pin st 'done 1) st)))
                     'look (st \ x \ y \ st) 'mouse (st \ ev \ bt \ (pin st 'ev ([ev bt (st 't)] . st 'ev), world-mouse ws ev bt)) 'winds (_ \ world-winds? ws)
                     'stick [119 115 97 100 87] 'binds view-binds 'fps 100 'linger 0 'next () 'song (_ \ ()) 'win win})
      _ (close line, catch srv, close ls, unlink path) (rev (st 'ev)))
   dn (x \ [['finger 1 0 x 200]]) up (x \ [['finger 1 1 x 200]])
   a (lvl 0) ea (run {2 (dn 500) 50 (up 500)} a) ba (a 'balls 0)
   tp (run {2 (dn 500) 8 (up 500)} (lvl 0)) dg (run {2 (dn 500) 4 [['finger 1 2 540 200]] 50 (up 540)} (lvl 0)) sk (run {2 (dn 100) 50 (up 100)} (lvl 0))
   e0 (lvl 0) _ (world-step e0 'tap) em (run {2 (dn 500) 50 (up 500)} e0)
   ; ..the button's, by hand at the same frames
   b (lvl 0) (mv n) (each ^n (_ \ (pin b 'dt 0.05, world-move b)))
   _ (two? ea && #ea = 2 ? (mv (ea 0 2), world-mouse b 'press 1, mv (ea 1 2 - ea 0 2), world-mouse b 'release 1, mv (62 - ea 1 2)))
 (test (map (e \ [(e 0) (e 1)]) ea = ['(press 1) '(release 1)]) (ba 'held = 0) (ba 'p = b 'balls 0 'p) (ba 'v = b 'balls 0 'v) (ba 'p 2 > 4.0)
       (tp = ()) (dg = ()) (sk = ()) (em = ())))
; a phone's touches where they lean: the base walks by where the thumb is, at once, and past it
; runs; one far from it looks; a short right tap hops on its lift with what it could as it came down, a
; second finger there at once; a left tap is the level's tap; a drag, a long press are none. a corner is
; no way out, and Back is one the second time
(: gh {'split ()}
   (run fs n) (: path ("/tmp/lorewin-ctl-" + show (getpid 0)) _ (unlink path) ls (listen ['unix path])
      srv (twirl (_ \ (: _ (await ls) c (accept ls) (slurp c))) ()) line (connect ['unix path])
      win {'how 'droid 's line 'w 640 'h 400 'H 400 'row 0 'held () 'paper (cask (640 * 400 * 4)) 'said (peep fs 0 ())}
      st (view-walk {'new (w \ h \ {'w w 'h h 't 0 'win win 'gpu {'g gh} 'lg ()}) 'size (st \ w \ r \ pins st 'w w 'h (2 * r)) 'frame (st \ (: o (peep st 'over {}) _ (two? (keys o) ? (pin st 'ov o)) ""))
                     'key (st \ a \ pin st 'lg ([a (st 't)] . st 'lg))
                     'tick (st \ (pin win 'said (peep fs (st 't + 1) ()), (n < st 't ? (pin st 'done 1) st)))
                     'look (st \ x \ y \ pin st 'lg ([ 'look (st 't)] . st 'lg)) 'leans (_ \ 1) 'lean (st \ x \ y \ r \ pin st 'lg ([ 'lean (st 't) x y r] . st 'lg))
                     'poised (st \ 7) 'hop (st \ p \ pin st 'lg ([ 'hop (st 't) p] . st 'lg)) 'tap (st \ x \ y \ [101])
                     'stick [119 115 97 100 87] 'binds (view-bind view-binds {101 'act}) 'fps 100 'linger 0 'next () 'song (_ \ ()) 'win win})
      _ (close line, catch srv, close ls, unlink path) [(rev (st 'lg)) (st 't) (peep st 'ov {})])
   dn (i \ x \ y \ [['finger i 0 x y]]) up (i \ x \ y \ [['finger i 1 x y]]) mv (i \ x \ y \ [['finger i 2 x y]])
   b (view-base 640 400) kinds (r \ map (q \ q 0) (r 0))
   tap (run {2 (dn 1 500 200) 6 (up 1 500 200)} 30)
   two (run {2 (dn 1 500 200) 8 (dn 2 560 200) 12 (up 2 560 200) 20 (mv 1 560 200) 24 (up 1 560 200)} 40)
   drag (run {2 (dn 1 500 200) 4 (mv 1 540 200) 6 (up 1 540 200)} 30)
   long (run {2 (dn 1 500 200) 50 (up 1 500 200)} 60)
   left (run {2 (dn 1 (int (b 0)) (int (b 1))) 6 (up 1 (int (b 0)) (int (b 1)))} 30)
   far (run {2 (dn 1 40 30) 4 (mv 1 80 30) 8 (up 1 80 30)} 30)
   out (run {2 (dn 1 (int (b 0)) (int (b 1 - b 2 - 20))) 40 (up 1 (int (b 0)) (int (b 1 - b 2 - 20)))} 50)
   in (run {2 (dn 1 (int (b 0)) (int (b 1 - 0.1 * 400))) 40 (up 1 (int (b 0)) (int (b 1 - 0.1 * 400)))} 50)
   corner (run {2 (dn 1 630 10) 4 (up 1 630 10)} 30)
   back (d \ run {2 [['down 362] ['up 362]] (2 + d) [['down 362] ['up 362]]} 300)
   ; ..a helper's split of a slow frame is taken by the walk, the once
   _ (pin gh 'split "uploads 1") _ (run {} 5) took (gh 'split = ())
   bk (back 400)
   leans (r \ filter (q \ q 0 = 'lean) (r 0)) last (r \ (leans r @ l (l (#l - 1))))
 (test (kinds tap = ['hop]) (tap 0 0 2 = 7) (tap 0 0 1 >= 6)
       (filter (q \ q != 'look) (kinds two) = ['hop]) (two 0 0 1 < 12)
       !(elem 'hop (kinds drag)) (elem 'look (kinds drag)) !(elem 'hop (kinds long)) !(elem 'act (kinds long))
       (elem 'act (kinds left)) !(elem 'hop (kinds left)) !(two? (leans left))
       !(elem 'lean (kinds far)) (elem 'look (kinds far))
       (two? (leans out)) (last out 4) (last out 3 > 0.9) (last out 2 * last out 2 < 0.01)
       (two? (leans in)) !(last in 4) (last in 3 < 0.8) (0.3 < last in 3)
       (30 < corner 1) (#(corner 0) = 1) (corner 0 0 0 = 'hop)
       (back 400 1 > 290) (back 20 1 < 60) took
       ; ..Back's asking on the bottom row and across it; the base halfway up, and nothing laid for it
       (keys (bk 2) = [24]) (bk 2 24 0 = 0) (#(bk 2 24 1) = 80) (b 1 = 200.0) (view-base 400 640 1 = 496.0) (keys (tap 2) = ())))
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
