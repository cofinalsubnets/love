; src/apps/window.l -- a window: pixels out, input events in, the same face on X and on inle.
;
;   (window-open w h title)   a window, or a nom: 'no-display 'refused 'no-paper
;   (window-paper win)        its paper: a cask of w x h 32-bit pixels, 0x00rrggbb, the form
;                             src/love/quay/paint.c lays and `dye` paints into
;   (window-size win)         (w h)
;   (window-show win y0 y1)   the paper's rows y0..y1-1 out to the screen
;   (window-events win)       the records waiting, () when none; never blocks
;   (window-close win)
;   (window-typing win on)    a soft keyboard up or down, where the keys are one (android)
;
; the records: [down key] [up key] [text s] [press b x y] [release b x y] [move x y]
; [size w h] [close]. a key is its PS/2 set-1 code, where it sits and not what it types;
; text is what it types. a size is a fresh paper, black, for the program to draw again.
; on X it is a window of its own over the wire (src/apps/lux/wire.l); on inle it is the
; whole screen (src/inle/seat.l's kwin-events over kmain.c's kpaper kshow kscan), and
; w h are the screen's whatever was asked; under android's bridge (LOVE_FACE, the wire in
; src/apps/droid/bridge.c) it is the whole screen over LOVE_FACE_SCALE, 2 unless said,
; taken from its next frame's 'S' record on. a tablet of 'w 'h 'paper alone is a window with
; no screen, a law's: it shows nothing, and its events are what was left in its 'evq.
(module '(window window-open window-paper window-size window-show window-events window-close
          window-typing)
(borrow 'xwire)
(borrow 'posix)
(borrow 'bytes)
(:
   (inle? _) (elem 'love-os (names ()) ? (elem (ev 'love-os) '(inle wasm)) 0)
   ; KeyPress KeyRelease ButtonPress ButtonRelease PointerMotion Exposure StructureNotify
   x-mask 163919

   (x-open-win w h title)
    (x-open (getenv "DISPLAY") @ o
       (? !(two? o) o
          (: s <o sc <>o xw (scr-idbase sc) gc (scr-idbase sc + 1)
             _ (x-window s xw (scr-root sc) w h x-mask)
             _ (x-gc s gc xw)
             _ (x-title s xw title)
             dl (x-protocols s xw)
             _ (x-map s xw, x-flush s, x-autorepeat s)
             {'how 'x 's s 'xw xw 'gc gc 'depth (scr-depth sc) 'dl dl
              'km (x-keysyms s (scr-mink sc) (scr-maxk sc))
              'w w 'h h 'paper (cask (w * h * 4))})))
   (inle-open-win _)
    (kpaper 1 @ wh
       (two? wh ? {'how 'inle 'w <wh 'h (wh 1) 'paper (cask (<wh * wh 1 * 4))} 'no-paper))
   ; --- the droid bridge: records in (kind a b c, little-endian), rows of the paper out ---
   (droid-rec s)
    (: k (see s)
       (k < 0 ? ()
          (: a (see s) _ (see s) _ (see s)
             (i32 _) (foldl (v \ i \ v | (see s << (8 * i))) 0 ^4 @ v (v >= 2147483648 ? (v - 4294967296) v))
             b (i32 0) c (i32 0)
             [k a b c])))
   droid-scale (getenv "LOVE_FACE_SCALE" @ v (? (0 < #v) (read v @ n (? (charm? n && 0 < n) n 2)) 2))
   ; an android keycode -> its set-1 place: the letters, the digits, the f keys, the rest
   droid-set1 (foldl (t \ p \ pin t <p >p) {}
                (zip (map (+ 29) ^26) [30 48 46 32 18 33 34 35 23 36 37 38 50 49 24 25 16 19 31 20 22 47 17 45 21 44]
                 + zip (map (+ 7) ^10) [11 2 3 4 5 6 7 8 9 10]
                 + zip (map (+ 131) ^12) [59 60 61 62 63 64 65 66 67 68 87 88]
                 + zip [66 67 61 62 111 112 19 20 21 22 122 123 92 93 124 59 60 113 114 57 58 115 55 56 68 69 70 71 72 73 74 75 76]
                       [28 14 15 57 1 339 328 336 331 333 327 335 329 337 338 42 54 29 285 56 312 58 51 52 41 12 13 26 27 43 39 40 53]))
   ; a record -> the window's events. a key's text is what android's map types under its
   ; meta state, c; a touch is the left button
   (droid-events r sc)
    (r @ [k a b c]
       (? (k = 83) [['size (b // sc) (c // sc)]]
          (k = 75) (: p (peep droid-set1 b ())
                      ((charm? p ? [[(a ? 'down 'up) p]] ()) + (a && 32 <= c && c != 127 ? [['text (utf8 c)]] ())))
          (k = 84) [(? (a = 0) ['press 1 b c] (a = 1) ['release 1 b c] ['move b c])]
          ()))
   (droid-open-win _)
    (getenv "LOVE_FACE" @ p
       (? !(string? p) 'no-display
          (connect ['unix p] @ s
             (? !(port? s) 'refused
                (: (wait _) (droid-rec s @ r (? !r 'refused (<r = 83) r (wait 0)))
                   r (wait 0)
                   (? (atom? r) r
                      (: w (r 2 // droid-scale) h (r 3 // droid-scale)
                         {'how 'droid 's s 'w w 'h h 'paper (cask (w * h * 4))})))))))
   (droid-pending win)
    (: s (win 's)
       (go acc) (? !(cue? s) acc
                   (droid-rec s @ r (? !r (acc + [['close]]) (go (acc + droid-events r droid-scale)))))
       (go ()))

   (window-open w h title) (? (inle? 0) (inle-open-win ())
                              (string? (getenv "LOVE_FACE")) (droid-open-win ())
                              (x-open-win w h title))

   (window-paper win) (win 'paper)
   (window-size win) [(win 'w) (win 'h)]
   (window-show win y0 y1)
    (: a (max 0 y0) b (min (win 'h) y1)
       (? (b <= a) 0
          (win 'how = 'x) (x-putrows (win 's) (win 'xw) (win 'gc) (win 'depth) (win 'paper) (win 'w) a (b - a))
          (win 'how = 'inle) (kshow (win 'paper) a b)
          (win 'how = 'droid) (: s (win 's) w (win 'w)
                                 (say s ("F" + wrle w 2 + wrle (win 'h) 2 + wrle a 2 + wrle (b - a) 2),
                                  say s (snip (win 'paper) (a * w * 4) (b * w * 4)), flush s))
          0))

   ; a size the paper has already is no news: X says one for every move
   (resized win r)
    (? (<r != 'size) [r]
       (r 1 = win 'w && r 2 = win 'h) ()
       (pins win 'w (r 1) 'h (r 2) 'paper (cask (r 1 * r 2 * 4)), [r]))
   ; every X event waiting; an Expose ships the paper again, once for the lot
   (x-pending win)
    (: s (win 's)
       (go acc ex) (? !(cue? s) [(rev acc) ex]
                      (x-next s @ e
                         (? (atom? e) [(rev (['close] . acc)) ex]
                            (ev-code e = 12) (go acc 1)
                            (go (rev (x-events e (win 'km) (win 'dl)) + acc) ex))))
       (go () 0))
   (window-events win)
    (: l (? (win 'how = 'x) (x-pending win @ p
                              (p 1 ? (window-show win 0 (win 'h)) 0, <p))
            (win 'how = 'inle) (kwin-events 0)
            (win 'how = 'droid) (droid-pending win)
            (peep win 'evq () @ q (pin win 'evq (), q)))
       (foldl (a \ r \ a + resized win r) () l))

   (window-close win) (win 'how = 'x || win 'how = 'droid ? (close (win 's)) (kpaper 0))
   (window-typing win on) (win 'how = 'droid ? (: s (win 's) (say s ("I" + wrle (on ? 1 0) 1), flush s)) 0))
) ; module window
