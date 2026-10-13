; src/apps/window.l -- a window: pixels out, input events in, the same face on X and on inle.
;
;   (window-open w h title)   a window, or a nom: 'no-display 'refused 'no-paper
;   (window-paper win)        its paper: a cask of w x h 32-bit pixels, 0x00rrggbb, the form
;                             src/love/quay/paint.c lays and `dye` paints into
;   (window-size win)         (w h)
;   (window-show win y0 y1)   the paper's rows y0..y1-1 out to the screen
;   (window-events win)       the records waiting, () when none; never blocks
;   (window-close win)
;   (window-own win sel text) text held as the selection sel, 'primary or 'clipboard
;   (window-ask win sel)      the selection sel asked for: its text comes as [paste s]
;
; the records: [down key] [up key] [text s] [press b x y] [release b x y] [move x y]
; [size w h] [close] [paste s] [lost sel]. a lost sel is a selection another took. a key is its PS/2 set-1 code, where it sits and not what it types;
; text is what it types. a size is a fresh paper, black, for the program to draw again.
; on X it is a window of its own over the wire (src/apps/lux/wire.l); on inle it is the
; whole screen (src/inle/seat.l's kwin-events over kmain.c's kpaper kshow kscan), and
; w h are the screen's whatever was asked. a tablet of 'w 'h 'paper alone is a window with
; no screen, a law's: it shows nothing, and its events are what was left in its 'evq. off
; X a selection is the window's own, held and given back.
(module '(window window-open window-paper window-size window-show window-events window-close
          window-own window-ask)
(borrow 'xwire)
(borrow 'posix)
(:
   (inle? _) (elem 'love-os (names ()) ? (elem (ev 'love-os) '(inle wasm)) 0)
   ; KeyPress KeyRelease ButtonPress ButtonRelease PointerMotion Exposure StructureNotify
   ; PropertyChange
   x-mask 4358223

   (x-open-win w h title)
    (x-open (getenv "DISPLAY") @ o
       (? !(two? o) o
          (: s <o sc <>o xw (scr-idbase sc) gc (scr-idbase sc + 1)
             _ (x-window s xw (scr-root sc) w h x-mask)
             _ (x-gc s gc xw)
             _ (x-title s xw title)
             dl (x-protocols s xw)
             at (map (x-intern s) ["UTF8_STRING" "CLIPBOARD" "TARGETS" "INCR" "LOVE_PASTE"])
             _ (x-map s xw, x-flush s, x-autorepeat s)
             {'how 'x 's s 'xw xw 'gc gc 'depth (scr-depth sc) 'dl dl
              'km (x-keysyms s (scr-mink sc) (scr-maxk sc))
              'utf8 <at 'cb (at 1) 'targets (at 2) 'incr (at 3) 'prop (at 4) 'time 0 'x 0
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
          (win 'how = 'x) (x-hold win, x-putrows (win 's) (win 'xw) (win 'gc) (win 'depth) (win 'paper) (win 'w) a (b - a),
                           x-let win)
          (win 'how = 'inle) (kshow (win 'paper) a b)
          0))

   ; a size the paper has already is no news: X says one for every move
   (resized win r)
    (? (<r != 'size) [r]
       (r 1 = win 'w && r 2 = win 'h) ()
       (pins win 'w (r 1) 'h (r 2) 'paper (cask (r 1 * r 2 * 4)), [r]))
   ; every X event waiting, those a reply left behind too; an Expose ships the paper
   ; again, once for the lot
   (x-pending win)
    (: s (win 's)
       (go acc ex) (? !(cue? s || two? (evq 0)) [(rev acc) ex]
                      (x-next s @ e
                         (? (atom? e) [(rev (['close] . acc)) ex]
                            (ev-code e = 12) (go acc 1)
                            (go (rev (x-ev win e) + acc) ex))))
       (go () 0))
   ; one event: the selections' four are the window's to answer, an input's time is kept
   ; for taking one
   (x-ev win e)
    (: c (ev-code e) raw (ev-raw e)
       _ (2 <= c && c <= 6 ? (pin win 'time (u32 raw 4)) 0)
       (? (c = 28) (x-piece win raw) (c = 29) (x-lost win raw)
          (c = 30) (x-serve win raw) (c = 31) (x-got win raw)
          (x-events e (win 'km) (win 'dl))))
   (window-events win)
    (: l (? (win 'how = 'x) (x-pending win @ p
                              (p 1 ? (window-show win 0 (win 'h)) 0, <p))
            (win 'how = 'inle) (kwin-events 0)
            (peep win 'evq () @ q (pin win 'evq (), q)))
       said (peep win 'said () @ q (pin win 'said (), q))
       (foldl (a \ r \ a + resized win r) () (said + l)))

   (window-close win) (win 'how = 'x ? (close (win 's)) (kpaper 0))

   ; --- the selections. off X the window keeps them; on X it owns one, serves its text to
   ;     whoever asks, and asks the owner of another onto a property of its own ---
   (clip win) (peep win 'clip () @ c (? (tablet? c) c (pin win 'clip (tablet 4) @ w (w 'clip))))
   (window-own win sel text)
    (pin (clip win) sel text, win 'how = 'x ? (x-own win (x-sel win sel)) 0)
   (window-ask win sel)
    (? (win 'how = 'x) (x-ask win (x-sel win sel) (win 'utf8))
       (pin win 'said (peep win 'said () + [['paste (peep (clip win) sel "")]]), 0))
   (x-sel win sel) (sel = 'clipboard ? (win 'cb) 1)
   (x-name win a) (? (a = 1) 'primary (a = win 'cb) 'clipboard ())
   ; the socket's writers are the painter and the events: a turn runs from a request's
   ; first byte to its flush
   (x-hold win) (0 < win 'x ? (rest 1, x-hold win) (pin win 'x 1))
   (x-let win) (pin win 'x 0)
   (x-own win a)                                       ; SetSelectionOwner
    (: s (win 's)
       (x-hold win, x-w8 s 22, x-w8 s 0, x-w16 s 4, x-w32 s (win 'xw), x-w32 s a, x-w32 s (win 'time),
        x-flush s, x-let win, 0))
   (x-ask win a ty)                                    ; ConvertSelection onto our property
    (: s (win 's)
       (x-hold win, x-w8 s 24, x-w8 s 0, x-w16 s 6, x-w32 s (win 'xw), x-w32 s a, x-w32 s ty,
        x-w32 s (win 'prop), x-w32 s (win 'time), x-flush s, x-let win, 0))
   ; another client took one of ours
   (x-lost win raw) (x-name win (u32 raw 12) @ n (? (atom? n && n != ()) (pin (clip win) n (), [['lost n]]) ()))
   ; another client asks for one of ours: as utf-8 or latin-1 text, or which targets there
   ; are. the answer rides a property of the asker's and a SelectionNotify
   (x-serve win raw)
    (: s (win 's) rq (u32 raw 12) sel (u32 raw 16) ty (u32 raw 20) pr0 (u32 raw 24)
       tx (x-name win sel @ n (? (atom? n && n != ()) (peep (clip win) n ()) ()))
       pr (pr0 = 0 ? ty pr0) ut (win 'utf8) tg (win 'targets)
       (prop tp fmt n bs) (#bs @ nb
                            (x-w8 s 18, x-w8 s 0, x-w16 s (6 + (nb + x-pad4 nb) // 4), x-w32 s rq, x-w32 s pr,
                             x-w32 s tp, x-w8 s fmt, x-w8 s 0, x-w16 s 0, x-w32 s n, x-wpad s bs))
       (le4 v) (cats (map (k \ string (v >> 8 * k & 255)) (jot 4)))
       _ (x-hold win)
       ok (? !(string? tx) 0
             (ty = tg) (prop 4 32 3 (le4 tg + le4 ut + le4 31), 1)
             ((ty = ut || ty = 31) && #tx < 262000) (prop ty 8 #tx tx, 1)
             0)
       (x-w8 s 25, x-w8 s 0, x-w16 s 11, x-w32 s rq, x-w32 s 0,
        x-w8 s 31, x-w8 s 0, x-w16 s 0, x-w32 s (u32 raw 4), x-w32 s rq, x-w32 s sel,
        x-w32 s ty, x-w32 s (ok ? pr 0), x-w32 s 0, x-w32 s 0, x-flush s,
        x-let win, ()))
   ; GetProperty, deleting: [type format bytes] or ()
   (x-take win pr)
    (: s (win 's)
       _ (x-hold win, x-w8 s 20, x-w8 s 1, x-w16 s 6, x-w32 s (win 'xw), x-w32 s pr,
          x-w32 s 0, x-w32 s 0, x-w32 s 262144, x-flush s, x-let win)
       hdr (x-reply s)
       (? !(<hdr = 1) () [(u32 hdr 8) (hdr 1) (take (u32 hdr 16) (x-rbytes s (4 * u32 hdr 4)))]))
   (x-text-of ty bs) (ty = 31 ? (cats (map utf8 bs)) (string bs))
   ; the owner's answer: none as utf-8 asks again as latin-1; a paste past what one property
   ; carries comes INCR, in pieces on our property, each after we take the last
   (x-got win raw)
    (: ty (u32 raw 16) pr (u32 raw 20)
       (? (pr = 0) (ty = win 'utf8 ? (x-ask win (u32 raw 12) 31, ()) [['paste ""]])
          (x-take win pr @ v
             (? !(two? v) [['paste ""]]
                (<v = win 'incr) (pins win 'pieces () 'incrty ty 'incron 1, ())
                (v 1 != 8) [['paste ""]]
                [['paste (x-text-of ty (v 2))]]))))
   ; a new piece on our property while an INCR paste is open; an empty one ends it
   (x-piece win raw)
    (? (u32 raw 4 = win 'xw && u32 raw 8 = win 'prop && raw 16 = 0 && peep win 'incron 0)
       (: v (x-take win (win 'prop)) bs (two? v ? (v 2))
          (? (two? bs) (pin win 'pieces (x-text-of (win 'incrty) bs . win 'pieces), ())
             (cats (rev (win 'pieces)) @ t (pins win 'incron 0 'pieces (), [['paste t]]))))
       ()))
) ; module window
