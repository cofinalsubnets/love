; src/apps/window.l -- a window: pixels out, input events in, the same face on X and on inle.
;
;   (window-here? _)          whether there is a screen to open one on
;   (window-open w h title)   a window, or a nom: 'no-display 'refused 'no-paper
;   (window-paper win)        its paper: a cask of w x h pixels 0x00rrggbb, what `dye` paints
;   (window-size win)         (w h)
;   (window-sized win)        (w h) as the screen has it now: the events waiting read, so the
;                             paper follows a resize, and kept for window-events
;   (window-show win y0 y1)   the paper's rows y0..y1-1 out to the screen
;   (window-blit win pic w h ys)  a picture w x h, 32-bit pixels as the paper's, out to the
;                             whole window but the rows ys, [y0 y1] spans the paper shows, the
;                             server enlarging it; 0 where it cannot, the picture to be
;                             painted onto the paper
;   (window-hold win on)      the pointer held in the window and hidden, on 1, or let go, on
;                             0; 1 where it was done
;   (window-warp win x y)     the pointer moved to x y in the window
;   (window-events win)       the records waiting, () when none; never blocks
;   (window-close win)
;   (window-own win sel text) text held as the selection sel, 'primary or 'clipboard
;   (window-ask win sel)      the selection sel asked for: its text comes as [paste s]
;   (window-typing win on)    a phone's soft keyboard up or down, and a row of the keys it lacks
;   (window-wets sc)          the rows of quay screen sc dirty since the last asking (wet clears)
;
; the records: [down key] [up key] [text s] [press b x y] [release b x y] [move x y]
; [size w h] [close] [paste s] [lost sel]. a key is its PS/2 set-1 code (where it sits);
; text is what it types. a size is a fresh black paper to draw again.
; on X a window of its own (lux/wire.l); on inle and under android's bridge (LOVE_FACE,
; scaled by LOVE_FACE_SCALE, 2 unless said) the whole screen, whatever w h asked.
; a tablet of 'w 'h 'paper alone is a law's screenless window: it shows nothing and its
; events are its 'evq. off X a selection is the window's own.
(module '(window window-here? window-open window-paper window-size window-sized window-show window-blit window-hold window-warp window-events window-close
          window-own window-ask window-typing window-wets)
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
          (: rb (x-rbytes s 11) a <rb
             (i32 o) (u32 rb o @ v (v >= 2147483648 ? (v - 4294967296) v))
             (k = 80 ? [k a (foldl (t \ b \ t + string b) "" (snip >rb 0 (min a 10))) 0]   ; a paste's piece
                [k a (i32 3) (i32 7)]))))
   droid-scale (getenv "LOVE_FACE_SCALE" @ v (? (0 < #v) (read v @ n (? (charm? n && 0 < n) n 2)) 2))
   ; an android keycode -> its set-1 place: the letters, the digits, the f keys, the rest
   droid-set1 (foldl (t \ p \ pin t <p >p) {}
                (zip (map (+ 29) ^26) [30 48 46 32 18 33 34 35 23 36 37 38 50 49 24 25 16 19 31 20 22 47 17 45 21 44]
                 + zip (map (+ 7) ^10) [11 2 3 4 5 6 7 8 9 10]
                 + zip (map (+ 131) ^12) [59 60 61 62 63 64 65 66 67 68 87 88]
                 + zip [66 67 61 62 111 112 19 20 21 22 122 123 92 93 124 59 60 113 114 57 58 115 55 56 68 69 70 71 72 73 74 75 76]
                       [28 14 15 57 1 339 328 336 331 333 327 335 329 337 338 42 54 29 285 56 312 58 51 52 41 12 13 26 27 43 39 40 53]))
   ; the keys a phone's keyboard lacks, a row under the paper while it types: [label key
   ; text]. ctrl and alt hold for the next key
   droid-row [["esc" 1 ""] ["|" 43 "|"] ["-" 12 "-"] ["home" 327 ""] ["↑" 328 ""] ["end" 335 ""] ["pgup" 329 ""] ["paste" 'paste ""]
              ["tab" 15 ""] ["ctrl" 29 ""] ["alt" 56 ""] ["←" 331 ""] ["↓" 336 ""] ["→" 333 ""] ["pgdn" 337 ""] ["/" 53 "/"]]
   droid-per 8                                         ; keys a row
   droid-rowh 96                                       ; two keys of three cells
   (droid-cols t) #(filter (b \ b & 192 != 128) (chars t))
   (droid-sp n) (n < 1 ? "" (" " + droid-sp (n - 1)))
   ; the row painted in the console's font, a held modifier lit
   (droid-strip win)
    (: w (win 'w) c (w // 8) sc (screen (cask (screen () 6 c)) 6 c) held (win 'held)
       (key r i) (droid-row (droid-per * r + i) @ [lab k _]
                    (: x0 (i * c // droid-per) n ((i + 1) * c // droid-per - x0) pad ((n - droid-cols lab) // 2)
                       bg (? (elem k held) "60;110;170" ((r + i) % 2 = 0) "44;44;44" "28;28;28")
                       (each ^3 (j \ scribe sc ("\e[" + show (3 * r + j + 1) + ";" + show (x0 + 1) + "H\e[38;2;220;220;220;48;2;" + bg + "m"
                                               + (j = 1 ? (droid-sp pad + lab + droid-sp (n - pad - droid-cols lab)) (droid-sp n)))))))
       _ (each ^2 (r \ each ^droid-per (key r)))
       st (cask (w * droid-rowh * 4))
       (each ^6 (y \ dye sc st w y -1 ()), st))
   (droid-send win y n px)
    (: s (win 's) (say s ("F" + wrle (win 'w) 2 + wrle (win 'H) 2 + wrle y 2 + wrle n 2), say s px, flush s))
   (droid-row-show win) (0 < win 'row ? (droid-send win (win 'h) (win 'row) (droid-strip win)) 0)
   ; android's clipboard: 'C its new text, 'V asks it, its answer as 'P records
   (droid-copy win t) (: s (win 's) (say s ("C" + wrle (tally t) 4), say s t, flush s))
   (droid-paste win) (: s (win 's) (say s "V", flush s))
   ; a key under the held modifiers: theirs down before it and up after, and let go
   (droid-key win k t)
    (: held (win 'held) _ (pin win 'held ())
       ev (map (m \ ['down m]) held + [['down k]] + (0 < #t ? [['text t]] ()) + [['up k]] + map (m \ ['up m]) held)
       (two? held ? (droid-row-show win) 0, ev))
   ; a touch on the row: a modifier held or let go, else its key
   (droid-tap win x y)
    (droid-row (droid-per * min 1 (y // (droid-rowh // 2)) + min (droid-per - 1) (x * droid-per // win 'w)) @ [_ k t]
       (? (k = 'paste) (droid-paste win, ())
          (k = 29 || k = 56) (: held (win 'held)
                                (pin win 'held (elem k held ? (filter (m \ m != k) held) (k . held)),
                                 droid-row-show win, ()))
          (droid-key win k t)))
   ; a record -> the window's events. a key's text is android's map under meta state c; a
   ; touch is the left button, or a key of the row
   (droid-events win r)
    (r @ [k a b c]
       (? (k = 83) (: _ (pin win 'H (c // droid-scale)) [['size (b // droid-scale) (c // droid-scale - win 'row)]])
          (k = 80) (peep win 'pst "" @ t (a = 0 ? (pin win 'pst "", [['paste t]]) (pin win 'pst (t + b), ())))
          (k = 75 && b = 279) (a ? (droid-paste win) 0, ())   ; a keyboard's paste key
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
   (window-blit win pic w h ys)
    (: r (win 'how = 'x ? (x-render win) 0) H (win 'h)
       ; ..the rows between the spans left, each [y0 y1]
       gaps (foldl (\ g s (: a (max 0 (s 0)) b (min H (s 1)) e <g (? (b <= a) g ([b (e 1)] . [(e 0) (min a (e 1))] . >g)))) [[0 H]] (sort ys))
       (? !(tablet? r) 0
          (: k (win 's) op (r 'op)
             _ (x-hold win)
             _ (x-render-at win r w h)
             _ (x-putrows k (r 'pm) (win 'gc) (win 'depth) pic w 0 h)
             _ (each (filter (g \ g 0 < g 1) gaps)
                 (g \ (x-w8 k op, x-w8 k 8, x-w16 k 9, x-w8 k 1, x-w8 k 0, x-w16 k 0,          ; Composite, Src
                    x-w32 k (r 'src), x-w32 k 0, x-w32 k (r 'dst),
                    x-w16 k 0, x-w16 k (g 0), x-w16 k 0, x-w16 k 0, x-w16 k 0, x-w16 k (g 0),
                    x-w16 k (win 'w), x-w16 k (g 1 - g 0))))
             _ (x-flush k)
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
    (? (win 'how = 'inle) (kgrab (on ? 1 0))
       (win 'how != 'x) 0
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
   (window-warp win x y) (? (win 'how = 'inle) (kgrab [x y])
                            (win 'how != 'x) 0
                            (: k (win 's) _ (x-hold win) _ (x-warp k (win 'xw) x y) _ (x-flush k) _ (x-let win) 1))

   ; a size the paper already has is no news: X says one for every move
   (resized win r)
    (? (<r != 'size) [r]
       (r 1 = win 'w && r 2 = win 'h) ()
       (pins win 'w (r 1) 'h (r 2) 'paper (cask (r 1 * r 2 * 4)), [r]))
   ; every X event waiting, a reply's leftovers too; Exposes ship the paper once for the lot
   (x-pending win)
    (: s (win 's)
       (go acc ex) (? !(cue? s || two? (peep evq s ())) [(rev acc) ex]
                      (x-next s @ e
                         (? (atom? e) [(rev (['close] . acc)) ex]
                            (ev-code e = 12) (go acc 1)
                            (go (rev (x-ev win e) + acc) ex))))
       (go () 0))
   ; one event: the selections' four are the window's to answer; an input's time is kept
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

   (window-sized win) (: ev (window-events win) _ (pin win 'said (peep win 'said () + ev)) (window-size win))
   (window-close win) (win 'how = 'x || win 'how = 'droid ? (close (win 's)) (kpaper 0))
   ; on a phone the keyboard comes with the row, and the paper gives it room
   (window-typing win on)
    (win 'how = 'droid ? (: s (win 's) _ (say s ("I" + wrle (on ? 1 0) 1), flush s)
                            (pins win 'row (on ? droid-rowh 0) 'more [['size (win 'w) (win 'H - (on ? droid-rowh 0))]], 0))
       0)
   (window-wets sc) (: (bits d base i acc) (i < 32 ? (bits d base (i + 1) (d >> i & 1 ? ((base + i) . acc) acc)) acc)
                       (go k acc) (k < 8 ? (go (k + 1) (bits (wet sc k) (32 * k) 0 acc)) acc)
                       (go 0 ()))

   ; --- the selections. off X the window keeps them; on X it owns one, serves it, and
   ;     asks another's owner onto a property of its own ---
   (clip win) (peep win 'clip () @ c (? (tablet? c) c (pin win 'clip (tablet 4) @ w (w 'clip))))
   (window-own win sel text)
    (pin (clip win) sel text,
     (? (win 'how = 'x) (x-own win (x-sel win sel))
        (win 'how = 'droid && sel = 'clipboard) (droid-copy win text)
        0))
   (window-ask win sel)
    (? (win 'how = 'x) (x-ask win (x-sel win sel) (win 'utf8))
       (win 'how = 'droid && sel = 'clipboard) (droid-paste win)
       (pin win 'said (peep win 'said () + [['paste (peep (clip win) sel "")]]), 0))
   (x-sel win sel) (sel = 'clipboard ? (win 'cb) 1)
   (x-name win a) (? (a = 1) 'primary (a = win 'cb) 'clipboard ())
   ; the painter and the events share the socket: a turn runs from a request's first byte
   ; to its flush
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
   ; another client asks for one of ours (utf-8, latin-1, or the targets); the answer rides
   ; its property and a SelectionNotify
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
   ; the owner's answer: none as utf-8 asks again as latin-1; a paste too big for one
   ; property comes INCR, a piece at a time on ours
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
