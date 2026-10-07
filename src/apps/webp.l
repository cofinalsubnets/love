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
(:
   webp-why ["" "not a webp" "cut short" "a kind of webp this can't read" "a bad stream"
             "too big" "no room"]
   (webp-le16 s i) (s i + 256 * s (i + 1))
   (webp-le24 s i) (webp-le16 s i + 65536 * s (i + 2))

   ; the first chunk: a lossy frame's header, a lossless one's, or the extended canvas
   (webp-size s)
    (? (#s < 12 || snip s 0 4 != "RIFF" || snip s 8 12 != "WEBP") "not a webp"
       (#s < 30) "cut short"
       (snip s 12 16 @
        "VP8 " [(webp-le16 s 26 & 16383) (webp-le16 s 28 & 16383)]
        "VP8L" (s 20 != 47 ? "a bad stream"
                [((webp-le16 s 21 & 16383) + 1) (((webp-le24 s 22 >> 6) & 16383) + 1)])
        "VP8X" [(webp-le24 s 24 + 1) (webp-le24 s 27 + 1)]
        "a bad stream"))

   ; the door: the nif where the artifact carries it, asked at first call, never at load
   webp-door {}
   (webp-nif? _)
    (webp-door 0 @ v
       (charm? v ? v
          (trap (_ \ (webp-pixels "", 1)) () (a \ b \ 0) @ w (pin webp-door 0 w, w))))

   (webp-decode s)
    (webp-size s @ d
       (? (string? d) d
          !(webp-nif? 0) "no decoder here"
          (webp-pixels s @ r
             (? (string? r) [(d 0) (d 1) r] (charm? r) (webp-why r) "not a webp"))))))
