; src/apps/webp.l -- webp decoding, over src/love/picture/webp.c's nif (webp-pixels s).
; `(borrow 'webp)`, then:
;
;   (webp-encode w h rgba) -> a lossless webp of the rgba, from webp.c | ()
;   (webp-size s)    -> (w h) off the RIFF headers, an animation's canvas | why not
;   (webp-decode s)  -> (w h rgba) | a string saying why not
;   (webp-frames s most) -> (w h ((rgba ms) ..)), each frame as shown and how long, at most
;                       most of them | why not; a still picture is one frame of no time
;
; lossy with or without its alpha plane, lossless, and an animation's first frame on its
; canvas, the pixels libwebp's own; its frames composed as libwebp's animation decoder does.
; where the artifact carries no nif, every webp is "no decoder here".
(module (webp webp-size webp-decode webp-pixels webp-frames webp-encode)
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
             (? (string? r) [(d 0) (d 1) r] (charm? r) (webp-why r) "not a webp"))))

   ; an animation's frames, each laid on what the last one left: the first, a frame covering
   ; the canvas that has no alpha or does not blend, and one after a frame cleared away that
   ; covered it or was a key frame itself start from a clear canvas (libwebp's key frames);
   ; a frame that disposes is cleared from its box before the next, and nothing in that box
   ; blends with what it left
   (webp-frames s most)
    (webp-size s @ d
       (? (string? d) d
          (#s < 21 || snip s 12 16 != "VP8X" || (s 20 & 2) = 0)
           (webp-decode s @ r (two? r ? [(r 0) (r 1) [[(r 2) 0]]] r))
          (: w (d 0) h (d 1) e (min #s (8 + rdle s 4 4))
             ; an ANMF at p -> [x y fw fh ms dispose blend alpha]
             (anmf p) (: q (p + 24) f (s (p + 23))
                         [(2 * rdle s (p + 8) 3) (2 * rdle s (p + 11) 3) (rdle s (p + 14) 3 + 1)
                          (rdle s (p + 17) 3 + 1) (rdle s (p + 20) 3) (f & 1) ((f & 2) = 0)
                          (? (e < q + 13) 0 (snip s q (q + 4) = "ALPH") 1
                             (snip s q (q + 4) = "VP8L") ((rdle s (q + 9) 4 >> 28) & 1) 0)])
             (full a) (a 0 = 0 && a 1 = 0 && a 2 = w && a 3 = h)
             (clear c a) (: o (cask #c) z (string (cask (4 * a 2)))
                            (pour o 0 c 0 #c,
                             each (jot (a 3)) (y \ pour o (4 * ((a 1 + y) * w + a 0)) z 0 (4 * a 2)),
                             string o))
             ; p the next chunk, c the canvas, pv [anmf key at] of the frame before
             (go p c pv acc n)
              (? (n = most || e < p + 8) acc
                 (: sz (rdle s (p + 4) 4) nx (p + 8 + sz + (sz & 1))
                    (? (snip s p (p + 4) != "ANMF" || e < p + 24) (go nx c pv acc n)
                       (: a (anmf p)
                          key (? (pv = ()) 1
                                 ((a 7 = 0 || !(a 6)) && full a) 1
                                 (pv 0 5 = 1 && (full (pv 0) || pv 1 = 1)))
                          (webp-frame s p c key (pv != () && pv 0 5 = 1 ? (pv 2) 0) @ r
                             (? (string? r) (go nx (a 5 = 1 ? (clear r a) r) [a key p] ([r (a 4)] . acc) (n + 1))
                                (two? acc) acc
                                (webp-why r)))))))
             (go 12 (string (cask (4 * w * h))) () () 0 @ fs
                (? (string? fs) fs (atom? fs) "a bad stream" [w h (rev fs)])))))))
