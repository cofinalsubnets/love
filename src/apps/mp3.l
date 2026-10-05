; src/apps/mp3.l -- mpeg audio layer iii over src/love/lib/mp3.c's nifs: the decoder door, and
; mpg123's decode: -w writes a wav, -s raw samples to stdout, -t decodes and keeps nothing.
; `(borrow 'mp3)`, then:
;
;   (mp3-meta s)           -> 'rate 'ch 'at the first audio frame, 'skip and 'total the samples
;                             a gapless stream drops ahead and plays (0 for unknown), 'tags
;                             ("NAME=value" ..) from an id3v2 tag | 'more | why not
;   (mp3-format m)         -> the format tablet src/apps/wav.l's wav-pcm takes: s16, m's shape
;   (mp3-pump q h m emit)  -> each frame's samples to emit, h the bytes held from m 'at, q the
;                             port the rest comes from -> 0 | why not. a stream entered mid-way
;                             finds the next frame; a damaged frame plays as silence; an id3v2
;                             tag between frames (a stream's next song) pins its 'tags on m and
;                             counts its 'link up from 0
;   (mp3-sniff s)          -> 1 an mp3 | 0 | 'more: with meta, format and pump, the decoder door
;
; a frame whose channels differ from the stream's first (a mode change) is laid in its shape:
; one doubled, or two averaged.
(module (mp3 mp3-sniff mp3-meta mp3-format mp3-pump mpg123-main mpg123-usage)
(:
   open (cite 'posix 'open) close (cite 'posix 'close)
   (be s i n) (foldl (\ a j (a * 256 + s (i + j))) 0 ^n)
   (le s i n) (foldl (\ a j (a * 256 + s (i + j))) 0 (rev ^n))
   (mp3-cat l) (foldl (\ a x (a + x)) "" l)

   ; --- where the audio starts ----------------------------------------------
   ; past an id3v2 tag, -1 while its header is short
   (mp3-id3 s) (? ("ID3" = snip s 0 3) (? (#s < 10) -1
                                          (10 + foldl (\ a j (a * 128 + (s (6 + j) & 127))) 0 ^4
                                           + ((s 5 & 16) ? 10 0)))
                  0)
   ; an id3v2 tag at the head of s, for av-head: its end once held; else its size, or for a tag
   ; past 1 MiB the tag rebuilt from the frames already held, the rest of it skipped unread
   (mp3-tagr s)
    (: k (mp3-id3 s) v (#s > 3 ? (s 3) 4)
       (fsz i) (? (v = 4) (foldl (\ a j (a * 128 + (s (i + 4 + j) & 127))) 0 ^4) (be s (i + 4) 4))
       (held i) (? (#s < i + 10 || s i = 0) i (: e (i + 10 + fsz i) (e <= #s ? (held e) i)))
       (ss n) (string (map (j \ (n >> (7 * (3 - j))) & 127) ^4))
       (? (k < 0) ['more 10]
          (k <= #s) k
          (k <= 1048576) ['more k]
          (: t (held 10)
             ['skip 0 k ("ID3" + string [v (s 4) (s 5 & 239)] + ss (t - 10) + snip s 10 t)])))
   ; a header -> [bytes ch rate] | (), bytes 0 for free format
   (mp3-hd s o) (mp3-head s o @ v (? (charm? v && 0 < v) [(v & 4095) ((v >> 12) & 15) (v >> 16)] ()))
   ; the first frame at or past i whose successor is where its length says, so a stray 0xff in
   ; a tag or a cut is not taken for one -> its offset | -1 none in s | -2 none yet
   (mp3-find s i lim)
    (: (next i n r) (? (n = 0) i                                   ; free format: its own word
                       (#s < i + n + 4) (#s >= lim + 4 ? -1 -2)
                       (mp3-hd s (i + n) @ [_ _ r2] (r2 = r ? i (go (i + 1))) _ (go (i + 1))))
       (go i) (? (lim <= i || #s < i + 4) (lim <= i ? -1 -2)
                 (mp3-hd s i @ [n _ r] (next i n r) _ (go (i + 1))))
       (go i))
   (mp3-sniff s)
    (: i (mp3-id3 s)
       (? (i < 0 || (#s < 3 && snip "ID3" 0 #s = s)) 'more
          (0 < i) 1                                          ; flac and ogg were asked first
          (mp3-find s 0 4096 @ -2 'more -1 0 _ 1)))

   ; --- the tags: id3v2's text frames, as vorbis comments name them ------------
   mp3-names {"TIT2" "TITLE" "TPE1" "ARTIST" "TALB" "ALBUM" "TRCK" "TRACKNUMBER" "TYER" "DATE"
              "TDRC" "DATE" "TCON" "GENRE" "TPE2" "ALBUMARTIST"}
   ; text in its encoding byte's form -> utf-8: latin-1, utf-16 with or without its bom, utf-8
   (mp3-utf8 cs) (mp3-cat (map (c \ (? (c < 128) (string [c]) (c < 2048) (string [(192 | (c >> 6)) (128 | (c & 63))])
                                      (string [(224 | (c >> 12)) (128 | ((c >> 6) & 63)) (128 | (c & 63))])))
                               cs))
   (mp3-text t)
    (? (#t < 1) ""
       (: e (t 0) b (snip t 1 #t)
          (u16 b big) (map (k \ (big ? (b (2 * k) * 256 + b (2 * k + 1)) (b (2 * k + 1) * 256 + b (2 * k)))) ^(#b // 2))
          s (e @ 0 (mp3-utf8 (chars b))
                 1 (? (#b >= 2 && b 0 = 255 && b 1 = 254) (mp3-utf8 (u16 (snip b 2 #b) 0))
                      (#b >= 2 && b 0 = 254 && b 1 = 255) (mp3-utf8 (u16 (snip b 2 #b) 1))
                      (mp3-utf8 (u16 b 0)))
                 2 (mp3-utf8 (u16 b 1))
                 _ b)
          (findsub s (string [0]) @ k (k < 0 ? s (snip s 0 k)))))
   (mp3-tags s end)
    (: v (s 3) syncsafe (v = 4)
       (go i acc) (? (end < i + 10 || s i = 0) (rev acc)
                     (: id (snip s i (i + 4)) n (? syncsafe (foldl (\ a j (a * 128 + (s (i + 4 + j) & 127))) 0 ^4) (be s (i + 4) 4))
                        nm (mp3-names id)
                        (go (i + 10 + n) (string? nm ? ((nm + "=" + mp3-text (snip s (i + 10) (i + 10 + n))) . acc) acc))))
       (? (v < 3) () (go 10 ())))

   ; --- the meta ------------------------------------------------------------
   ; a xing or info frame: no audio; its frame count, and lame's encoder delay and padding
   (mp3-xing s o n ch lsf)
    (: x (o + 4 + (lsf ? (ch = 1 ? 9 17) (ch = 1 ? 17 32)) + ((s (o + 1) & 1) ? 0 2))
       tag (snip s x (x + 4))
       (? !(tag = "Xing" || tag = "Info") ()
          (: fl (be s (x + 4) 4) p (x + 8)
             frames (fl & 1 ? (be s p 4) 0)
             p2 (p + (fl & 1 ? 4 0) + (fl & 2 ? 4 0) + (fl & 4 ? 100 0) + (fl & 8 ? 4 0))
             lame (p2 + 21 <= o + n && ("LAME" = snip s p2 (p2 + 4) || "Lavf" = snip s p2 (p2 + 4)
                                         || "Lavc" = snip s p2 (p2 + 4)))
             d (lame ? (be s (p2 + 21) 3) 0)
             [frames (lame ? (d >> 12) 0) (lame ? (d & 4095) 0) lame])))
   (mp3-meta s)
    (: i (mp3-id3 s)
       (? (i < 0) ['more 10]
          (#s < i) (mp3-tagr s)
          (mp3-find s i (i + 65536) @
            -2 'more
            -1 "no mpeg audio layer iii frame here"
            o (mp3-hd s o @
                [n ch rate]
                 (: lsf (rate < 32000) spf (lsf ? 576 1152)
                    (? (#s < o + max n 192) 'more
                       (mp3-xing s o n ch lsf @
                         [fr dl pd lame]
                          {'rate rate 'ch ch 'at (o + n) 'tags (mp3-tags s i) 'spf spf
                           'skip (lame ? (dl + 529) 0)
                           'total (? (fr && lame) (fr * spf - dl - pd) fr (fr * spf) 0)}
                         _ {'rate rate 'ch ch 'at o 'tags (mp3-tags s i) 'spf spf 'skip 0 'total 0})))
                _ "no mpeg audio layer iii frame here"))))
   (mp3-format m) {'name "mp3" 'desc "mp3" 'w 2 'bits 16 'kind 's 'big 0 'ch (m 'ch) 'rate (m 'rate)
                   'align (2 * m 'ch)}

   ; --- the frames ----------------------------------------------------------
   ; one frame's s16 in ch channels -> in want's
   (mp3-shape pcm ch want)
    (? (ch = want) pcm
       (: n (#pcm // (2 * ch)) c (cask #pcm) o (cask (n * 2 * want))
          (pour c 0 pcm 0 #pcm,
           ch = 1 ? (each ^n (k \ (pour o (4 * k) pcm (2 * k) 2, pour o (4 * k + 2) pcm (2 * k) 2)))
                    (each ^n (k \ (: (s16 j) (le pcm j 2 @ v (v < 32768 ? v (v - 65536)))
                                     a ((s16 (4 * k) + s16 (4 * k + 2)) // 2 @ v (v < 0 ? (v + 65536) v))
                                     (pin o (2 * k) (a & 255), pin o (2 * k + 1) (a >> 8))))),
           string o)))
   ; f 0 for s16, 1 for f32; emit gets each run past m's skip and short of its total
   (mp3-run q h0 m f emit)
    (: st (cask (mp3-state 0)) want (m 'ch) w (f ? 4 2)
       left {'skip (m 'skip * want * w) 'rest (m 'total * want * w)}
       (out pcm)
        (: k (left 'skip)
           p (? (k <= 0) pcm (#pcm <= k) (: _ (pin left 'skip (k - #pcm)) "") (: _ (pin left 'skip 0) (snip pcm k #pcm)))
           r (left 'rest)
           p2 (? (m 'total = 0) p (r <= 0) "" (#p <= r) (: _ (pin left 'rest (r - #p)) p) (: _ (pin left 'rest 0) (snip p 0 r)))
           (? (0 < #p2) (emit p2) ()))
       (gulp _) (see q @ -1 () c (unsee q c, chug q))
       ; a tag at the end is no frame
       (tail? h o) (? (#h - o = 128 && "TAG" = snip h o (o + 3)) 1 ("APETAGEX" = snip h o (o + 8)) 1 0)
       (go h o)
        (? (65536 < o) (go (snip h o #h) 0)
           (mp3-frame st h o f @
             (pcm . nx) (: hd (mp3-hd h o) c (hd 1)
                           (? (hd 2 != m 'rate) "the stream changes its sample rate"
                              (: _ (out (f ? pcm (mp3-shape pcm c want))) (go h nx))))
             2 (gulp () @ g (string? g ? (go (snip h o #h + g) 0) 0))
             4 (mp3-hd h o @ [n c r] (: _ (out (string (cask (m 'spf * want * w)))) (go h (o + max n 4))) _ (go h (o + 1)))
             _ (? (o >= #h) (gulp () @ g (string? g ? (go g 0) 0))
                  (tail? h o) 0
                  ; a tag between frames is read through av-head, as the one ahead of them
                  ("ID3" = snip h o (o + 3))
                   (? (0 < o) (go (snip h o #h) 0)
                      ((cite 'av 'av-head) q mp3-tagr h @
                        [k h2] (? (charm? k)
                                  (: _ (pin m 'tags (mp3-tags (snip h2 0 k) k), pin m 'link (peep m 'link 0 + 1)) (go h2 k))
                                  (string? k) k
                                  0)))
                  (mp3-find h (o + 1) #h @ -1 (go h #h) -2 (gulp () @ g (string? g ? (go (snip h o #h + g) 0) 0))
                                            i (go h i)))))
       (go h0 0))
   (mp3-pump q h m emit) (mp3-run q h m 0 emit)

   ; --- mpg123 --------------------------------------------------------------
   mpg123-usage "usage: mpg123 [-q] [-t | -s | -w FILE] [-e s16|f32] [--no-gapless] FILE..
  decodes each FILE (- for stdin): -w to a wav, -s raw to stdout, -t tests and writes nothing.
  layer iii only; playing to a sound card is aplay's (love aplay)."
   (mpg123-err m) (say err (m + "\n"), flush err, 1)
   (mpg123-wav m f n)
    (: ch (m 'ch) w (f ? 4 2) (wle v k) (string (map (j \ (v >> (8 * j)) & 255) ^k)) (cl v) (min 4294967295 v)
       ("RIFF" + wle (cl (36 + n)) 4 + "WAVE" + "fmt " + wle 16 4 + wle (f ? 3 1) 2 + wle ch 2 + wle (m 'rate) 4
        + wle (m 'rate * ch * w) 4 + wle (ch * w) 2 + wle (8 * w) 2 + "data" + wle (cl n) 4))
   (mpg123-one o p)
    (: q (p = "-" ? in (open p "r"))
       (? !(hot? q) (mpg123-err ("mpg123: cannot open " + p + ": " + uerrno q))
          (: r ((cite 'av 'av-head) q mp3-meta "" @ ['short h] ["cut short" h] x x)
             m0 <r hb (r 1) f (o "e" = "f32" ? 1 0)
             fin (\ v (p = "-" ? v (close q, v)))
             (? (string? m0) (fin (mpg123-err ("mpg123: " + p + ": " + m0)))
                (: m (o "g" ? (pins m0 'skip 0 'total 0) m0)
                   d (? (o "w") (open (o "w") "w") (o "s") out ())
                   (? (o "w" && !(hot? d)) (fin (mpg123-err ("mpg123: cannot write " + o "w")))
                      ; -w streams: the header goes ahead, and its sizes are laid over it at the end
                      (: ps {'n 0}
                         _ (? (o "w") (say d (mpg123-wav m f 0)) ())
                         r (mp3-run q (snip hb (m 'at) #hb) m f
                                    (pcm \ (: _ (pin ps 'n (ps 'n + #pcm)) (? (o "w" || o "s") (say d pcm) ()))))
                         _ (? (o "w") (: _ (flush d) _ (close d) ((cite 'av 'av-patch) (o "w") 0 (mpg123-wav m f (ps 'n))))
                              (o "s") (flush d) ())
                         (fin (? (string? r) (mpg123-err ("mpg123: " + p + ": " + r)) 0)))))))))
   (mpg123-main as)
    (: o {}
       (go l fs)
        (? (atom? l) (? !(two? fs) (mpg123-err mpg123-usage)
                        (foldl (\ st p (mpg123-one o p @ r (r ? r st))) 0 (rev fs)))
           (<l @ "-q" (go >l fs) "-t" (go >l fs) "-s" (pin o "s" 1, go >l fs)
                 "--no-gapless" (pin o "g" 1, go >l fs)
                 "-w" (two? >l ? (pin o "w" <>l, go >>l fs) (mpg123-err "mpg123: -w needs a file name"))
                 "-e" (? (two? >l && (<>l = "s16" || <>l = "f32")) (pin o "e" <>l, go >>l fs)
                         (mpg123-err "mpg123: -e is s16 or f32"))
                 a (? (1 < #a && 45 = a 0) (mpg123-err ("mpg123: unknown option " + a)) (go >l (a . fs)))))
       (go as ()))
   _ (pins (cite 'verbs 'tab) 'mpg123 (udoor 'mpg123 mpg123-main mpg123-usage 1 0)))
) ; module mp3
