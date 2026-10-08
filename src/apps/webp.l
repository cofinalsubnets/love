; src/apps/webp.l -- webp decoding, over src/love/lib/webp.c's nif (webp-pixels s).
; `(borrow 'webp)`, then:
;
;   (webp-size s)    -> (w h) off the RIFF headers, an animation's canvas | why not
;   (webp-decode s)  -> (w h rgba) | a string saying why not
;
; lossy with or without its alpha plane, lossless, and an animation's first frame on its
; canvas, the pixels libwebp's own. where the artifact carries no nif, every webp is "no
; decoder here".
(module (webp webp-size webp-decode webp-pixels)
(borrow 'bytes)
(:
   webp-why ["" "not a webp" "cut short" "a kind of webp this can't read" "a bad stream"
             "too big" "no room"]

   ; the first chunk: a lossy frame's header, a lossless one's, or the extended canvas
   (webp-size s)
    (? (#s < 12 || snip s 0 4 != "RIFF" || snip s 8 12 != "WEBP") "not a webp"
       (#s < 30) "cut short"
       (snip s 12 16 @
        "VP8 " [(rdle s 26 2 & 16383) (rdle s 28 2 & 16383)]
        "VP8L" (s 20 != 47 ? "a bad stream"
                [((rdle s 21 2 & 16383) + 1) (((rdle s 22 3 >> 6) & 16383) + 1)])
        "VP8X" [(rdle s 24 3 + 1) (rdle s 27 3 + 1)]
        "a bad stream"))


   (webp-decode s)
    (webp-size s @ d
       (? (string? d) d
          (webp-pixels s @ r
             (? (string? r) [(d 0) (d 1) r] (charm? r) (webp-why r) "not a webp"))))))
