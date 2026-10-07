; src/apps/gif.l -- gif encoding, an rgba image or a run of them to a gif89a, and decoding.
; `(borrow 'gif)`, then:
;
;   (gif-encode w h rgba)   -> the gif's bytes
;   (gif-anim w h fs)       -> a looping gif of fs, ((rgba ms) ..) as gif-frames answers them
;   (gif-decode s)          -> (w h rgba), the first frame | a string saying why not
;   (gif-frames s most)     -> (w h ((rgba ms) ..)), each frame as shown and how long,
;                              at most most of them | why not
;   (gif-palette px n room) -> (rgbs index-of key-fn), at most room colours (sixel's too)
;
; decoding is src/love/lib/gif.c's, frame by frame onto the screen; disposal 2 clears a
; frame's box to see-through (as browsers do) and 3 restores what was under it.
; a pixel under half alpha is the transparent index. up to 256 colours stay exact; past
; that each channel is cut to 5 bits and a median cut over what is left picks the palette.
(module (gif gif-encode gif-anim gif-decode gif-frames gif-palette gif-key gif-frame)
(:
   ; --- the palette ----------------------------------------------------------------------
   ; a pixel's colour as one number, -1 when it is transparent
   (gif-key px i)
    (peep px (i + 3) 0 < 128 ? -1
       (peep px i 0 << 16 | peep px (i + 1) 0 << 8 | peep px (i + 2) 0))
   (gif-coarse k) (k < 0 ? k (k >> 19 << 10 | (k >> 11 & 31) << 5 | k >> 3 & 31))
   ; colour -> count over every pixel, colours through f; () once past most colours
   (gif-census px n f most)
    (: t {}
       (go i m) (? (i = n) t (most < m) ()
                   (: k (f (gif-key px (4 * i))) c (peep t k 0) (pin t k (c + 1),
                                                                 go (i + 1) (c ? m (m + 1)))))
       (go 0 0))

   ; a box of the cut: its widest channel's range, that channel, its [colour count]s
   (gif-box cs)
    (: (ch k c) (k >> 10 - 5 * c & 31)
       (span c) (map (e \ ch <e c) cs @ vs (foldl max 0 vs - foldl min 31 vs))
       r (span 0) g (span 1) b (span 2)
       c (? (r >= g && r >= b) 0 (g >= b) 1 2)
       [(? (c = 0) r (c = 1) g b) c cs])
   ; halve a box at its weighted median along its channel
   (gif-split bx)
    (: c (bx 1) sh (10 - 5 * c)
       cs (map cup (sort (map (e \ (<e >> sh & 31) . e) (bx 2))))
       total +(map (e \ e 1) cs)
       ; the first k whose running weight reaches half, both halves kept
       (cut l acc k) (atom? >l || (acc + (<l 1)) * 2 >= total ? (k + 1)
                        (cut >l (acc + (<l 1)) (k + 1)))
       m (cut cs 0 0 @ k (k >= #cs ? (#cs - 1) k))
       [(gif-box (take m cs)) (gif-box (drop m cs))])
   ; boxes to n, each split the widest -> the boxes
   (gif-cut boxes n)
    (foldl (a \ i \ (boxes i 0 > boxes a 0 ? i a)) 0 (jot #boxes) @ at
       (#boxes >= n || boxes at 0 = 0 ? boxes
          (gif-cut (take at boxes + gif-split (boxes at) + drop (at + 1) boxes) n)))

   ; -> [palette-rgb-list index-of-colour colour-fn]: exact when it fits, cut when not
   (gif-palette px n room)
    (: exact (gif-census px n 1 (room + 1))                ; the +1 is the transparent key
       ks (exact = () ? () (sort (keys exact)))
       opaque (<ks = -1 ? >ks ks)
       (!(exact = ()) && #opaque <= room ?
          [opaque (foldl (t \ i \ pin t (opaque i) i) {} (jot #opaque)) 1]
          (: coarse (gif-census px n gif-coarse (n + 1))
             cks (sort (keys coarse))
             cs (map (k \ [k (coarse k)]) (<cks = -1 ? >cks cks))
             boxes (gif-cut [(gif-box cs)] room)
             ; a box's colour is its members' mean, weighted, back at 8 bits
             (mean cs sh) (: w +(map (e \ e 1) cs)
                             ((+(map (e \ (<e >> sh & 31) * (e 1)) cs) * 8 + 4 * w) // w))
             (rgb bx) (mean (bx 2) 10 << 16 | mean (bx 2) 5 << 8 | mean (bx 2) 0)
             ix (foldl (t \ i \ foldl (t \ e \ pin t <e i) t (boxes i 2)) {} (jot #boxes))
             [(map rgb boxes) ix gif-coarse])))

   ; --- lzw --------------------------------------------------------------------------------
   ; the codes of n indices from ix at min code size mcs -> their bytes, lsb first
   (gif-lzw ix n mcs)
    (: clear (1 << mcs) eoi (clear + 1)
       o (cask (n * 2 + 16)) st {'acc 0 'nb 0 'len 0}
       (emit code cs)
        (: acc (st 'acc | code << st 'nb) nb (st 'nb + cs)
           (out acc nb) (nb < 8 ? (pin st 'acc acc, pin st 'nb nb)
                           (pin o (st 'len) (acc & 255), pin st 'len (st 'len + 1),
                            out (acc >> 8) (nb - 8)))
           (out acc nb))
       (go i w d next cs)
        (i = n ? (emit w cs, emit eoi cs, (st 'nb ? (emit 0 (8 - st 'nb)) 0),
                  snip (string o) 0 (st 'len))
           (: k (peep ix i 0) key (w << 8 | k) c (peep d key -1)
              (c >= 0 ? (go (i + 1) c d next cs)
                 (: _ (emit w cs) _ (pin d key next)
                    cs2 (next >= 1 << cs ? (cs + 1) cs)
                    (next = 4095 ?
                       (emit clear cs2, go (i + 1) k {} (eoi + 1) (mcs + 1))
                       (go (i + 1) k d (next + 1) cs2))))))
       (emit clear (mcs + 1),
        go 1 (peep ix 0 0) {} (eoi + 1) (mcs + 1)))

   ; --- the file ---------------------------------------------------------------------------
   (gif-le16 v) (string (v & 255) + string (v >> 8 & 255))
   ; bytes into sub-blocks of at most 255, then the empty one
   (gif-blocks s)
    (: o (jug 0)
       (go i) (#s <= i ? (say o (string 0), slurp o)
                 (: k (#s - i < 255 ? (#s - i) 255)
                    (say o (string k), say o (snip s i (i + k)),
                     go (i + k))))
       (go 0))

   ; one image's palette and codes: [s table trans colours mcs codes], s its table's bits
   (gif-image w h px)
    (: n (w * h)
       trans (: (go i) (? (i = n) 0 (peep px (4 * i + 3) 0 < 128) 1 (go (i + 1))) (go 0))
       pal (gif-palette px n (256 - trans))
       cols (pal 0) ix-of (pal 1) f (pal 2)
       count (#cols + trans)
       s (: (go s) (1 << s >= count ? s (go (s + 1))) (go 1))
       mcs (s < 2 ? 2 s)
       ix (cask n)
       (put i) (f (gif-key px (4 * i)) @ k (pin ix i (k < 0 ? #cols (peep ix-of k 0))))
       _ (map put (jot n))
       rgb (foldl (acc \ c \ acc + gif-bytes [(c >> 16) (c >> 8) c]) "" cols)
       table (rgb + gif-bytes (map (k \ 0) (jot (3 * ((1 << s) - #cols)))))
       [s table trans #cols mcs (gif-blocks (gif-lzw ix n mcs))])
   (gif-bytes l) (foldl (acc \ b \ acc + string (b & 255)) "" l)
   ; the box at the screen's corner, w by h, its table local when pk says so
   (gif-place w h pk) (string 44 + gif-le16 0 + gif-le16 0 + gif-le16 w + gif-le16 h + string pk)

   (gif-encode w h px)
    (gif-image w h px @ [s table trans nc mcs codes]
       ("GIF89a" + gif-le16 w + gif-le16 h + gif-bytes [(128 | 112 | s - 1) 0 0]
        + table
        + (trans ? (gif-bytes [33 249 4 1 0 0 nc 0]) "")
        + gif-place w h 0 + string mcs + codes + string 59))

   ; frames as gif-frames answers them, ((rgba ms) ..), to a gif that loops for good: each
   ; frame its own table, and cleared after it is shown (disposal 2), so each is as given.
   ; a delay is centiseconds on the wire, and under 2 most viewers show as 10
   (gif-anim w h fs)
    (: (frame f) (gif-image w h (f 0) @ [s table trans nc mcs codes]
                   (: cs (f 1 // 10)
                      (gif-bytes [33 249 4 (8 | trans) cs (cs >> 8) (trans ? nc 0) 0]
                       + gif-place w h (128 | s - 1) + table + string mcs + codes)))
       ("GIF89a" + gif-le16 w + gif-le16 h + gif-bytes [0 0 0]
        + gif-bytes [33 255 11] + "NETSCAPE2.0" + gif-bytes [3 1 0 0 0]
        + cats (map frame fs) + string 59))

   ; --- decoding, over src/love/lib/gif.c's gif-frame and gif-clear ----------------------------
   (gif-rd16 s i) (s i + 256 * s (i + 1))
   ; the offset past the sub-blocks that start at p and their empty one
   (gif-skip s p) (? (#s <= p) #s (s p = 0) (p + 1) (gif-skip s (p + 1 + s p)))
   ; the palette's length in bytes by a flags byte
   (gif-table f) (f & 128 ? (3 * (2 << (f & 7))) 0)
   ; the door: asked at first call, never at load
   gif-door {}
   (gif-nif? _)
    (peep gif-door 0 () @ v
       (charm? v ? v
          (trap (_ \ (gif-clear "" 0 "", 1)) () (a \ b \ 0) @ w (pin gif-door 0 w, w))))
   ; the images laid in turn on the screen, each as the viewer sees it, at most most of them
   ; gc is the graphic control ahead of an image: [disposal trans ms]
   (gif-frames s most)
    (? (#s < 13 || snip s 0 4 != "GIF8") "not a gif"
       !(gif-nif? 0) "no decoder here"
       (: w (gif-rd16 s 6) h (gif-rd16 s 8)
          (? (w * h = 0) "not a gif"
             (16777216 < w * h) "too big"
             (: (go p cv gc acc)
                 (? (#acc = most || #s <= p || s p = 59) acc
                    (s p = 33)
                     (gif-skip s (p + 2) @ nx
                        (s (p + 1) = 249 && p + 7 < #s ?
                            (: pk (s (p + 3)) cs (gif-rd16 s (p + 4))
                               (go nx cv [(pk >> 2 & 7) (pk & 1 ? (s (p + 6)) -1)
                                          (cs < 2 ? 100 (10 * cs))] acc))
                           (go nx cv gc acc)))
                    (s p = 44)
                     (gif-frame s p cv (gc 1) @ f
                        (!(string? f) ? acc
                           (: q (gif-skip s (p + 11 + gif-table (s (p + 9))))
                              c (gif-clear s p f)
                              under (? (gc 0 = 2) (string? c ? c f) (gc 0 = 3) cv f)
                              (go q under [0 -1 100] (acc + [[f (gc 2)]])))))
                    acc)
                fs (go (13 + gif-table (s 10)) (string (cask (4 * w * h))) [0 -1 100] ())
                (two? fs ? [w h fs] "no image")))))
   (gif-decode s) (gif-frames s 1 @ r (two? r ? [(r 0) (r 1) <(<(r 2))] r)))

) ; module gif
