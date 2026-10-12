; src/apps/window.l -- a window: pixels out, input events in, the same face on X and on inle.
;
;   (window-open w h title)   a window, or a nom: 'no-display 'refused 'no-paper
;   (window-paper win)        its paper: a cask of w x h 32-bit pixels, 0x00rrggbb, the form
;                             src/love/quay/paint.c lays and `dye` paints into
;   (window-size win)         (w h)
;   (window-show win y0 y1)   the paper's rows y0..y1-1 out to the screen
;   (window-events win)       the records waiting, () when none; never blocks
;   (window-close win)
;
; the records: [down key] [up key] [text s] [press b x y] [release b x y] [move x y]
; [size w h] [close]. a key is its PS/2 set-1 code, where it sits and not what it types;
; text is what it types. a size is a fresh paper, black, for the program to draw again.
; on X it is a window of its own over the wire (src/apps/lux/wire.l); on inle it is the
; whole screen (src/inle/seat.l's kwin-events over kmain.c's kpaper kshow kscan), and
; w h are the screen's whatever was asked.
(module '(window window-open window-paper window-size window-show window-events window-close)
(borrow 'xwire)
(borrow 'posix)
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
   (window-open w h title) (inle? 0 ? (inle-open-win ()) (x-open-win w h title))

   (window-paper win) (win 'paper)
   (window-size win) [(win 'w) (win 'h)]
   (window-show win y0 y1)
    (: a (max 0 y0) b (min (win 'h) y1)
       (? (b <= a) 0
          (win 'how = 'x) (x-putrows (win 's) (win 'xw) (win 'gc) (win 'depth) (win 'paper) (win 'w) a (b - a))
          (kshow (win 'paper) a b)))

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
            (kwin-events 0))
       (foldl (a \ r \ a + resized win r) () l))

   (window-close win) (win 'how = 'x ? (close (win 's)) (kpaper 0)))
) ; module window
