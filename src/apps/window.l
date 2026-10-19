; src/apps/window.l -- a window: pixels out, input events in, the same face on X and on inle.
;
;   (window-here? _)          whether there is a screen to open one on
;   (window-open w h title)   a window, or a nom: 'no-display 'refused 'no-paper
;   (window-paper win)        its paper: a cask of w x h 32-bit pixels, 0x00rrggbb, the form
;                             src/love/quay/paint.c lays and `dye` paints into
;   (window-size win)         (w h)
;   (window-show win y0 y1)   the paper's rows y0..y1-1 out to the screen
;   (window-blit win pic w h) a picture w x h, 32-bit pixels as the paper's, out to the
;                             whole window, the server enlarging it; 0 where it cannot, the
;                             picture to be painted onto the paper
;   (window-hold win on)      the pointer held in the window and hidden, on 1, or let go, on
;                             0; 1 where it was done
;   (window-warp win x y)     the pointer moved to x y in the window
;   (window-events win)       the records waiting, () when none; never blocks
;   (window-close win)
;   (window-own win sel text) text held as the selection sel, 'primary or 'clipboard
;   (window-ask win sel)      the selection sel asked for: its text comes as [paste s]
;   (window-typing win on)    a phone's soft keyboard up or down, and a row of the keys it lacks
;
; the records: [down key] [up key] [text s] [press b x y] [release b x y] [move x y]
; [size w h] [close] [paste s] [lost sel]. a key is its PS/2 set-1 code, where it sits and
; not what it types; text is what it types; a lost sel is a selection another took. a size
; is a fresh paper, black, for the program to draw again.
; on X it is a window of its own over the wire (src/apps/lux/wire.l); on inle it is the
; whole screen (src/inle/seat.l's kwin-events over kmain.c's kpaper kshow kscan), and
; w h are the screen's whatever was asked; under android's bridge (LOVE_FACE, the wire in
; src/apps/droid/bridge.c) it is the whole screen over LOVE_FACE_SCALE, 2 unless said,
; taken from its next frame's 'S' record on. a tablet of 'w 'h 'paper alone is a window with
; no screen, a law's: it shows nothing, and its events are what was left in its 'evq. off
; X a selection is the window's own, held and given back.
(module '(window window-here? window-open window-paper window-size window-show window-blit window-hold window-warp window-events window-close
          window-own window-ask window-typing)
(borrow 'xwire)
(borrow 'posix)
(borrow 'bytes)
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
   ; the keys a phone's keyboard lacks, a row of two under the paper while it types:
   ; [label key text]. ctrl and alt hold for the next key, off the row or the keyboard
   droid-row [["esc" 1 ""] ["|" 43 "|"] ["-" 12 "-"] ["home" 327 ""] ["↑" 328 ""] ["end" 335 ""] ["pgup" 329 ""]
              ["tab" 15 ""] ["ctrl" 29 ""] ["alt" 56 ""] ["←" 331 ""] ["↓" 336 ""] ["→" 333 ""] ["pgdn" 337 ""]]
   droid-rowh 96                                       ; two keys of three cells
   (droid-cols t) #(filter (b \ b & 192 != 128) (chars t))
   (droid-sp n) (n < 1 ? "" (" " + droid-sp (n - 1)))
   ; the row painted in the console's font, a held modifier lit
   (droid-strip win)
    (: w (win 'w) c (w // 8) sc (screen (cask (screen () 6 c)) 6 c) held (win 'held)
       (key r i) (droid-row (7 * r + i) @ [lab k _]
                    (: x0 (i * c // 7) n ((i + 1) * c // 7 - x0) pad ((n - droid-cols lab) // 2)
                       bg (? (elem k held) "60;110;170" ((r + i) % 2 = 0) "44;44;44" "28;28;28")
                       (each ^3 (j \ scribe sc ("\e[" + show (3 * r + j + 1) + ";" + show (x0 + 1) + "H\e[38;2;220;220;220;48;2;" + bg + "m"
                                               + (j = 1 ? (droid-sp pad + lab + droid-sp (n - pad - droid-cols lab)) (droid-sp n)))))))
       _ (each ^2 (r \ each ^7 (key r)))
       st (cask (w * droid-rowh * 4))
       (each ^6 (y \ dye sc st w y -1 ()), st))
   (droid-send win y n px)
    (: s (win 's) (say s ("F" + wrle (win 'w) 2 + wrle (win 'H) 2 + wrle y 2 + wrle n 2), say s px, flush s))
   (droid-row-show win) (0 < win 'row ? (droid-send win (win 'h) (win 'row) (droid-strip win)) 0)
   ; a key under the held modifiers: theirs down before it and up after, and let go
   (droid-key win k t)
    (: held (win 'held) _ (pin win 'held ())
       ev (map (m \ ['down m]) held + [['down k]] + (0 < #t ? [['text t]] ()) + [['up k]] + map (m \ ['up m]) held)
       (two? held ? (droid-row-show win) 0, ev))
   ; a touch on the row: a modifier held or let go, else its key
   (droid-tap win x y)
    (droid-row (7 * min 1 (y // (droid-rowh // 2)) + min 6 (x * 7 // win 'w)) @ [_ k t]
       (? (k = 29 || k = 56) (: held (win 'held)
                                (pin win 'held (elem k held ? (filter (m \ m != k) held) (k . held)),
                                 droid-row-show win, ()))
          (droid-key win k t)))
   ; a record -> the window's events. a key's text is what android's map types under its
   ; meta state, c; a touch is the left button, or a key of the row
   (droid-events win r)
    (r @ [k a b c]
       (? (k = 83) (: _ (pin win 'H (c // droid-scale)) [['size (b // droid-scale) (c // droid-scale - win 'row)]])
          (k = 75) (: p (peep droid-set1 b ()) t (a && 32 <= c && c != 127 ? (utf8 c) "")
                      (? !(charm? p) (0 < #t ? [['text t]] ())
                         (a && two? (win 'held)) (droid-key win p t)
                         ([[(a ? 'down 'up) p]] + (0 < #t ? [['text t]] ()))))
          (k = 84) (? (c < win 'h) [(? (a = 0) ['press 1 b c] (a = 1) ['release 1 b c] ['move b c])]
                      (a = 0) (droid-tap win b (c - win 'h))
                      ())
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
                         {'how 'droid 's s 'w w 'h h 'H h 'row 0 'held () 'paper (cask (w * h * 4))})))))))
   (droid-pending win)
    (: s (win 's) more (peep win 'more ()) _ (pin win 'more ())
       (go acc) (? !(cue? s) acc
                   (droid-rec s @ r (? !r (acc + [['close]]) (go (acc + droid-events win r)))))
       (go more))

   (window-here? _) (inle? 0 || 0 < #(getenv "DISPLAY") || string? (getenv "LOVE_FACE"))
   (window-open w h title) (? (inle? 0) (inle-open-win ())
                              (string? (getenv "LOVE_FACE")) (droid-open-win ())
                              (x-open-win w h title))

   (window-paper win) (win 'paper)
   (window-size win) [(win 'w) (win 'h)]
   (window-show win y0 y1)
    (: a (max 0 y0) b (min (win 'h) y1)
       (? (b <= a) 0
          (win 'how = 'x) (x-hold win, x-putrows (win 's) (win 'xw) (win 'gc) (win 'depth) (win 'paper) (win 'w) a (b - a),
                           x-let win)
          (win 'how = 'inle) (kshow (win 'paper) a b)
          (win 'how = 'droid) (droid-send win a (b - a) (snip (win 'paper) (a * win 'w * 4) (b * win 'w * 4)))
          0))

   ; --- RENDER: a picture put up at its own size and drawn s times over by the server, so a
   ;     frame ships its own pixels and not the window's. the format is the paper's: depth
   ;     the window's, red at 16, green at 8, blue at 0, no alpha ---
   (x-render win) (peep win 'rd () @ () (: r (x-render-init win) _ (pin win 'rd r) r) r r)
   (x-render-init win)
    (: s (win 's) ext (x-queryext s "RENDER")
       (? !(two? ext) 0
          (: op <ext
             _ (x-w8 s op, x-w8 s 0, x-w16 s 3, x-w32 s 0, x-w32 s 11, x-flush s)        ; QueryVersion 0.11
             v (x-reply s)
             _ (x-w8 s op, x-w8 s 1, x-w16 s 1, x-flush s)                               ; QueryPictFormats
             hdr (x-reply s)
             n (<hdr = 1 ? (u32 hdr 8) 0) b (<hdr = 1 ? (x-rbytes s (4 * u32 hdr 4)) ())
             (fmt i) (: o (28 * i)
               (b (o + 4) = 1 && b (o + 5) = win 'depth && u16 b (o + 8) = 16 && u16 b (o + 10) = 255
                && u16 b (o + 12) = 8 && u16 b (o + 16) = 0 && u16 b (o + 18) = 255 && u16 b (o + 22) = 0 ? (u32 b o) ()))
             f (foldl (\ a i (a = () ? (fmt i) a)) () ^n)
             (? (!(<v = 1) || f = ()) 0
                {'op op 'fmt f 'pw 0 'ph 0 'sc 0 'made 0 'pm (win 'xw + 2) 'src (win 'xw + 3) 'dst (win 'xw + 4)}))))
   ; ..the pixmap and its pictures made again whenever the picture's size or the window's
   ; changes; a transform taking the window's place to the picture's, its share each way
   (x-render-at win r w h)
    (? (r 'pw = w && r 'ph = h && r 'sc = [(win 'w) (win 'h)]) 0
       (: k (win 's) op (r 'op) mx (65536 * w // max 1 (win 'w)) my (65536 * h // max 1 (win 'h))
          _ (r 'made ? (x-w8 k op, x-w8 k 7, x-w16 k 2, x-w32 k (r 'src),                 ; FreePicture
                        x-w8 k op, x-w8 k 7, x-w16 k 2, x-w32 k (r 'dst),
                        x-w8 k 54, x-w8 k 0, x-w16 k 2, x-w32 k (r 'pm)) 0)                 ; FreePixmap
          _ (x-w8 k 53, x-w8 k (win 'depth), x-w16 k 4, x-w32 k (r 'pm), x-w32 k (win 'xw), x-w16 k w, x-w16 k h)
          _ (x-w8 k op, x-w8 k 4, x-w16 k 5, x-w32 k (r 'src), x-w32 k (r 'pm), x-w32 k (r 'fmt), x-w32 k 0)
          _ (x-w8 k op, x-w8 k 4, x-w16 k 5, x-w32 k (r 'dst), x-w32 k (win 'xw), x-w32 k (r 'fmt), x-w32 k 0)
          _ (x-w8 k op, x-w8 k 28, x-w16 k 11, x-w32 k (r 'src), each [mx 0 0 0 my 0 0 0 65536] (v \ x-w32 k v))
          (pins r 'pw w 'ph h 'sc [(win 'w) (win 'h)] 'made 1)))
   (window-blit win pic w h)
    (: r (win 'how = 'x ? (x-render win) 0)
       (? !(tablet? r) 0
          (: k (win 's) op (r 'op)
             _ (x-hold win)
             _ (x-render-at win r w h)
             _ (x-putrows k (r 'pm) (win 'gc) (win 'depth) pic w 0 h)
             _ (x-w8 k op, x-w8 k 8, x-w16 k 9, x-w8 k 1, x-w8 k 0, x-w16 k 0,               ; Composite, Src
                x-w32 k (r 'src), x-w32 k 0, x-w32 k (r 'dst),
                x-w16 k 0, x-w16 k 0, x-w16 k 0, x-w16 k 0, x-w16 k 0, x-w16 k 0,
                x-w16 k (win 'w), x-w16 k (win 'h), x-flush k)
             _ (x-let win)
             1)))

   ; --- the pointer held: GrabPointer confined to the window, its motion and buttons ours,
   ;     shown by a cursor of one clear pixel, made once; UngrabPointer lets it go ---
   (x-blank win) (peep win 'blank () @ () (: k (win 's) pm (win 'xw + 5) gc (win 'xw + 6) cu (win 'xw + 7)
      _ (x-w8 k 53, x-w8 k 1, x-w16 k 4, x-w32 k pm, x-w32 k (win 'xw), x-w16 k 1, x-w16 k 1)     ; CreatePixmap, depth 1
      _ (x-w8 k 55, x-w8 k 0, x-w16 k 5, x-w32 k gc, x-w32 k pm, x-w32 k 4, x-w32 k 0)           ; CreateGC, foreground 0
      _ (x-w8 k 70, x-w8 k 0, x-w16 k 5, x-w32 k pm, x-w32 k gc, x-w16 k 0, x-w16 k 0, x-w16 k 1, x-w16 k 1)  ; PolyFillRectangle
      _ (x-w8 k 93, x-w8 k 0, x-w16 k 8, x-w32 k cu, x-w32 k pm, x-w32 k pm,                     ; CreateCursor, all mask clear
         x-w16 k 0, x-w16 k 0, x-w16 k 0, x-w16 k 0, x-w16 k 0, x-w16 k 0, x-w16 k 0, x-w16 k 0)
      _ (pin win 'blank cu) cu) c c)
   (window-hold win on)
    (? (win 'how != 'x) 0
       (: k (win 's)
          _ (x-hold win)
          ok (? on (: cu (x-blank win)
                      _ (x-w8 k 26, x-w8 k 0, x-w16 k 6, x-w32 k (win 'xw), x-w16 k 76, x-w8 k 1, x-w8 k 1,   ; GrabPointer
                         x-w32 k (win 'xw), x-w32 k cu, x-w32 k 0, x-flush k)
                      r (x-reply k)
                      (<r = 1 && r 1 = 0))
                   (: _ (x-w8 k 27, x-w8 k 0, x-w16 k 2, x-w32 k 0, x-flush k) 1))
          _ (x-let win)
          (ok ? 1 0)))
   (window-warp win x y) (? (win 'how != 'x) 0
                            (: k (win 's) _ (x-hold win) _ (x-warp k (win 'xw) x y) _ (x-flush k) _ (x-let win) 1))

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
            (win 'how = 'droid) (droid-pending win)
            (peep win 'evq () @ q (pin win 'evq (), q)))
       said (peep win 'said () @ q (pin win 'said (), q))
       ev (foldl (a \ r \ a + resized win r) () (said + l))
       (win 'how = 'droid && any (e \ <e = 'size) ev ? (droid-row-show win) 0, ev))

   (window-close win) (win 'how = 'x || win 'how = 'droid ? (close (win 's)) (kpaper 0))
   ; on a phone the keyboard comes with the row, and the paper gives it room
   (window-typing win on)
    (win 'how = 'droid ? (: s (win 's) _ (say s ("I" + wrle (on ? 1 0) 1), flush s)
                            (pins win 'row (on ? droid-rowh 0) 'more [['size (win 'w) (win 'H - (on ? droid-rowh 0))]], 0))
       0)

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
