; src/apps/ogg.l -- the ogg container (rfc 3533): pages, packets, the codec each logical stream
; carries, and the decoder door over it, so av.l plays what is inside.
; `(borrow 'ogg)`, then:
;
;   (ogg-page s o)         -> the page at o: [type granule serial seq laces body end] | 'more | why
;   (ogg-cut s b ls)       -> a page body's packets: [closed open], open the packet that runs on
;                             to the next page, () for none
;   (ogg-meta s)           -> the first stream a codec here reads: its codec's meta, with 'ogg the
;                             codec, 'serial, 'at the page where its audio starts and 'skip the
;                             header packets on that page | 'more | why not
;   (ogg-format m)         -> its codec's format tablet
;   (ogg-pump q h m emit)  -> each packet's samples to emit -> 0 | why not. a chained stream
;                             (an internet radio's) plays on while its format holds, each new
;                             link's 'tags pinned on m and its 'link counted up from 0
;   (ogg-sniff s)          -> 1 an ogg stream | 0 | 'more
;
; a codec rides ogg as [name id? head format start]: (id? p) knows its first packet, (head ps)
; reads its header packets -> m | 'more | why, (start m) -> a decoder, (packet granule) ->
; samples | why, in format's shape. granule is the stream's length, given with the last
; packet of its end page, -1 with every other.
(module (ogg ogg-sniff ogg-meta ogg-format ogg-pump ogg-page ogg-cut)
(:
   (le s i n) (foldl (\ a j (a * 256 + s (i + j))) 0 (rev ^n))

   ; --- pages and packets ----------------------------------------------------
   (ogg-page s o)
    (? (#s < o + 27) 'more
       ("OggS" != snip s o (o + 4)) "lost sync"
       (s (o + 4) != 0) "an ogg version this can't read"
       (: k (s (o + 26)) b (o + 27 + k)
          (? (#s < b) 'more
             (: ls (map (j \ s (o + 27 + j)) ^k) e (b + foldl (+) 0 ls)
                (? (#s < e) 'more
                   (ogg-crc s o (e - o) != le s (o + 22) 4) "a bad page (its crc)"
                   [(s (o + 5)) (le s (o + 6) 8) (le s (o + 14) 4) (le s (o + 18) 4) ls b e])))))
   ; a lace under 255 ends its packet; laces of 255 to the page's end run on
   (ogg-cut s b ls)
    (: (go l p st acc) (? (atom? l) [(rev acc) (p > st ? (snip s st p) ())]
                          (<l < 255) (go >l (p + <l) (p + <l) (snip s st (p + <l) . acc))
                          (go >l (p + <l) st acc))
       (go ls b b ()))
   ; a page's packets with what ran on from the last page (held, () for none) -> [closed open].
   ; a continuation with nothing held (a stream entered mid-way) loses its first piece
   (ogg-join held cont pk tl)
    (? !cont [pk tl]
       !(string? held) [(two? pk ? >pk ()) (two? pk ? tl ())]
       (two? pk) [(held + <pk . >pk) tl]
       [() (held + (string? tl ? tl ""))])

   ; --- the codecs ----------------------------------------------------------
   ; flac (the ogg mapping 1.0): "\x7fFLAC" 1 0, a count, then "fLaC" and STREAMINFO; each later
   ; header packet is one metadata block, and each audio packet one frame
   (ogg-flac-head ps)
    (: p <ps
       (? (#p < 13 || p 5 != 1) "an Ogg FLAC mapping this can't read"
          ; flac's sizes and skips count bytes of a flac stream, not of these packets
          ((cite 'flac 'flac-meta) (cats ("fLaC" . snip p 13 #p . >ps)) @ ('more . _) 'more ('skip . _) 'more m m)))
   ; a packet that is no frame (empty, cut, a bad crc) answers (), and the pump passes it over
   (ogg-flac-start m)
    (\ pkt gr (flac-frame pkt 0 (m 'bps) (m 'ch) @ (pcm . _) pcm _ ()))
   ; vorbis: identification, comments and setup, then each audio packet a block; the end
   ; page's granule cuts the last block to the stream's length
   ; a comment header's tags, its vendor's length at o: vorbis's and opus's, the same shape
   (ogg-tags p o)
    (: vn (le p o 4) k (le p (o + 4 + vn) 4)
       (go i j acc) (? (j >= k || #p < i + 4) (rev acc) (le p i 4 @ n (go (i + 4 + n) (j + 1) (snip p (i + 4) (i + 4 + n) . acc))))
       ; a name is any case; the door's are upper, as they are written by convention
       (? (#p < o + 8) () (map (t \ (findsub t "=") @ i (i < 0 ? t (upper (snip t 0 i) + snip t i #t))) (go (o + 8 + vn) 0 ()))))
   ogg-vb-why ["" "not a vorbis stream" "a vorbis setup cut short" "a kind of vorbis this can't read (floor 0)"
               "a bad vorbis setup"]
   (ogg-vb-head ps)
    (? (#ps < 3) 'more
       (: id <ps su (ps 2) n (vorbis-size id su)
          (? (n < 0) (ogg-vb-why (0 - n))
             {'rate (le id 12 4) 'ch (id 11) 'tags (ogg-tags (ps 1) 7) 'vb [id su] 'size n})))
   (ogg-vb-format m) {'name "vorbis" 'desc "vorbis" 'w 2 'bits 16 'kind 's 'big 0 'ch (m 'ch)
                      'rate (m 'rate) 'align (2 * m 'ch)}
   (ogg-vb-start m)
    (: st (cask (m 'size)) r (vorbis-init st (m 'vb 0) (m 'vb 1)) w (2 * m 'ch) n {'n 0}
       (? (r != 0) (\ pkt gr ())
          (\ pkt gr (vorbis-packet st pkt 0 @
                      pcm (? !(string? pcm) ()                 ; a packet that is no block is passed over
                             (: k (#pcm // w) t (n 'n) c (? (0 <= gr && gr < t + k) (max 0 (gr - t)) k)
                                (pin n 'n (t + c), snip pcm 0 (c * w))))))))
   ; opus (rfc 7845): OpusHead and OpusTags, then packets of 48 kHz audio; the head's
   ; pre-skip comes off the front, and the end page's granule, which counts it, cuts the last
   (ogg-op-head ps)
    (? (#ps < 2) 'more
       (: p <ps ch (#p > 9 ? (p 9) 0)
          (? (#p < 19 || p 8 > 15) "an opus head this can't read"
             (p 18 != 0 || ch < 1 || ch > 2) "multichannel opus (a channel mapping past 0) is not read here"
             {'rate 48000 'ch ch 'pre (le p 10 2) 'tags (ogg-tags (ps 1) 8)})))
   (ogg-op-format m) {'name "opus" 'desc "opus" 'w 2 'bits 16 'kind 's 'big 0 'ch (m 'ch) 'rate 48000
                      'align (2 * m 'ch)}
   (ogg-op-start m)
    (: st (cask (opus-state (m 'ch))) r (opus-init st (m 'ch)) w (2 * m 'ch) n {'n 0}
       (? (r != 0) (\ pkt gr ())
          (\ pkt gr (opus-packet st pkt 0 @
                      pcm (? !(string? pcm) ()                 ; a packet that will not decode is passed over
                             (: k (#pcm // w) t (n 'n) lo (max 0 (m 'pre - t))
                                hi (? (0 <= gr && gr < t + k) (max 0 (gr - t)) k)
                                (pin n 'n (t + k), lo < hi ? (snip pcm (lo * w) (hi * w)) "")))))))
   (ogg-codecs _)
    [["flac" (p \ "\x7fFLAC" = snip p 0 5) ogg-flac-head (cite 'flac 'flac-format) ogg-flac-start]
     ["vorbis" (p \ "\x01vorbis" = snip p 0 7) ogg-vb-head ogg-vb-format ogg-vb-start]
     ["opus" (p \ "OpusHead" = snip p 0 8) ogg-op-head ogg-op-format ogg-op-start]]
   (ogg-codec nm) <(filter (c \ <c = nm) (ogg-codecs ()))

   ; --- the door ------------------------------------------------------------
   (ogg-sniff s) (? (#s < 4) (snip "OggS" 0 #s = s ? 'more 0) ("OggS" = snip s 0 4) 1 0)
   ; header packets fed one at a time -> ['done m used] | ['more ps] | why
   (ogg-heads c ps l i)
    (? (atom? l) ['more ps]
       (: ps2 (ps + [<l])
          ((c 2) ps2 @ 'more (ogg-heads c ps2 >l (i + 1))
                       m (tablet? m ? ['done m (i + 1)] m))))
   ; st: () before a stream is chosen, else [codec serial packets held]
   (ogg-meta s)
    (: (go o st)
        (ogg-page s o @
          [ty gr sn sq ls b e]
           (ogg-cut s b ls @ [pk tl]
             (? !(two? st)
                 (? !(ty & 2) "an ogg stream with no codec this reads"
                    (: c <(filter (c \ (c 1) (pk 0 @ p (string? p ? p ""))) (ogg-codecs ()))
                       (? !(two? c) (go e ())
                          (ogg-heads c () pk 0 @
                            ['done m k] (pins m 'ogg <c 'serial sn 'at o 'skip k)
                            ['more ps] (go e [c sn ps tl])
                            why why))))
                (sn != st 1) (go e st)
                (st @ [c _ ps held]
                  (: jn (ogg-join held (ty & 1) pk tl)
                     off (? ((ty & 1) && string? held) 1 0)
                     (ogg-heads c ps (<jn) 0 @
                       ['done m k] (pins m 'ogg <c 'serial sn 'at o 'skip (k - off))
                       ['more ps2] (go e [c sn ps2 (jn 1)])
                       why why)))))
          why why)
       (? (#s < 4) 'more ("OggS" != snip s 0 4) "not an Ogg stream" (go 0 ())))
   (ogg-format m) ((ogg-codec (m 'ogg)) 3 m)
   (ogg-pump q h0 m0 emit)
    (: (gulp _) (see q @ -1 () c (unsee q c, chug q))
       ; the next "OggS" at or past i, -1 for none in h
       (sync h i) (: k (findsub (snip h i #h) "OggS") (k < 0 ? -1 (i + k)))
       ; a chain's next stream: its headers read on from o, and its format the first's
       (chain h o fmt)
        ((cite 'av 'av-head) q ogg-meta (snip h o #h) @
          ['short _] 0
          [m h2] (? !(tablet? m) m
                    (ogg-format m @ f (f 'rate = fmt 'rate && f 'ch = fmt 'ch && f 'align = fmt 'align))
                     (: _ (pin m0 'tags (m 'tags), pin m0 'link (peep m0 'link 0 + 1))   ; tags first: a watcher reads 'link
                        (run h2 (m 'at) m (((ogg-codec (m 'ogg)) 4) m) () (m 'skip) 0))
                    "a chained stream changes its format"))
       ; h the bytes, o the page, dec the decoder, held the packet running on, k packets yet
       ; to pass over, ended once this stream's last page is read
       (run h o m dec held k ended)
        (ogg-page h o @
          'more (gulp () @ g (? (string? g) (run (snip h o #h + g) 0 m dec held k ended)
                                (o >= #h || ended) 0
                                "cut short"))
          [ty gr sn sq ls b e]
           (? (sn != m 'serial)
               (? (ended && (ty & 2)) (chain h o (ogg-format m)) (run h e m dec held k ended))
              (ogg-cut h b ls @ [pk tl]
                (ogg-join held (ty & 1) pk tl @ [ps tl2]
                  (: (go l k) (? (atom? l) ()
                                 (0 < k) (go >l (k - 1))
                                 (dec <l (atom? >l && (ty & 4) ? gr -1) @ pcm (? (string? pcm) (emit pcm, go >l 0) !pcm (go >l 0) pcm)))
                     r (go ps k)
                     (? (string? r) r
                        (run h e m dec tl2 (max 0 (k - #ps)) (ty & 4)))))))
          why (sync h (o + 1) @ i (? (0 <= i) (run h i m dec () k ended)
                                     (gulp () @ g (? (string? g) (run (snip h (max o (#h - 3)) #h + g) 0 m dec () k ended)
                                                     ended 0
                                                     why)))))
       (run h0 0 m0 ((ogg-codec (m0 'ogg)) 4 m0) () (m0 'skip) 0)))
) ; module ogg
