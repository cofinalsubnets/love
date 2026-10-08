; src/apps/flac.l -- flac decoding over src/love/lib/flac.c's nif, and the flac and metaflac
; verbs: flac's decode and test, and metaflac's reading.
; `(borrow 'flac)`, then:
;
;   (flac-meta s)          -> the metadata as a tablet: 'rate 'ch 'bps 'total 'minbs 'maxbs
;                             'minfr 'maxfr 'md5, 'blocks ([type length offset] ..), 'vendor,
;                             'tags ("NAME=value" ..), 'at the first frame, 'head the bytes up
;                             to it | 'more | why not
;   (flac-format m)        -> the format tablet src/apps/wav.l's wav-pcm takes for m's frames
;   (flac-pump q h m emit) -> each frame's samples to emit, h the bytes held past the
;                             metadata, q the port the rest comes from -> 0 | why not. a
;                             stream entered mid-way (a seek) starts at the next frame;
;                             m 'whole says h opens on the first frame, which must decode
;   (flac-wav-head m)      -> the wav header flac -d writes ahead of m's samples
;   (flac-sniff s)         -> 1 a flac | 0 | 'more: with meta, format and pump, the decoder
;                             door (notes/plan/av.md)
;
; a frame's samples are little-endian, signed, (bps + 7) / 8 bytes each: what the stream's md5
; is taken over, and what flac -d --force-raw-format --endian=little --sign=signed writes.
(module (flac flac-sniff flac-meta flac-format flac-pump flac-wav-head flac-id3 flac-main metaflac-main
              flac-usage metaflac-usage flac-frame)
(borrow 'bytes)
(borrow 'wav)
(borrow 'hashes)
(:
   peepv (cite 'guts 'peepv) pinv (cite 'guts 'pinv)
   open (cite 'posix 'open) close (cite 'posix 'close)

   ; --- the metadata --------------------------------------------------------
   (flac-info s p)
    (: b (s (p + 12))
       {'minbs (rdbe s p 2) 'maxbs (rdbe s (p + 2) 2) 'minfr (rdbe s (p + 4) 3) 'maxfr (rdbe s (p + 7) 3)
        'rate ((rdbe s (p + 10) 2) * 16 + (b >> 4)) 'ch (((b >> 1) & 7) + 1)
        'bps ((((b & 1) * 16) + (s (p + 13) >> 4)) + 1)
        'total (((s (p + 13) & 15) * 4294967296) + rdbe s (p + 14) 4)
        'md5 (b2hex (snip s (p + 18) (p + 34)))})
   (flac-tags s p n)
    (: vn (rdle s p 4) k (rdle s (p + 4 + vn) 4)
       (go i j acc) (? (j >= k || i + 4 > p + n) (rev acc)
                       (rdle s i 4 @ m (go (i + 4 + m) (j + 1) (snip s (i + 4) (i + 4 + m) . acc))))
       [(snip s (p + 4) (p + 4 + vn)) (go (p + 8 + vn) 0 ())])
   ; an id3v2 tag ahead of the stream is passed over, as flac does. a picture or padding past
   ; 64 KiB is skipped unread (av-head): the last block becomes an empty padding block, so the
   ; blocks still end where they say
   (flac-meta s)
    (: id3 (flac-id3 s)
       (go i m bl)
        (? (#s < i + 4) ['more (i + 4)]
           (: t (s i & 127) last (s i >> 7) n (rdbe s (i + 1) 3) p (i + 4)
              (? (#s < p + n) (? ((t = 1 || t = 6) && 65536 < n) ['skip i (p + n) (last = 1 ? (string [129 0 0 0]) "")]
                                 ['more (p + n)])
                 (: m2 (? (t = 0) (pins (flac-info s p) 'blocks () 'tags () 'vendor "")
                          (t = 4 && tablet? m) (flac-tags s p n @ [v ts] (pins m 'vendor v 'tags ts))
                          m)
                    bl2 ([t n p] . bl)
                    (? !(tablet? m2) "a FLAC stream with no STREAMINFO first"
                       (last = 1) (pins m2 'blocks (rev bl2) 'at (p + n) 'head (snip s 0 (p + n)))
                       (go (p + n) m2 bl2))))))
       (? (id3 < 0) ['more 10]
          (65536 < id3 && #s < id3) ['skip 0 id3 ""]
          (#s < id3 + 4) ['more (id3 + 4)]
          ("fLaC" != snip s id3 (id3 + 4)) "not a FLAC file"
          (go (id3 + 4) () ())))
   ; where the stream starts: past an id3v2 tag, -1 while the tag's header is short
   (flac-id3 s) (? ("ID3" = snip s 0 3) (? (#s < 10) -1
                                            (10 + foldl (\ a j (a * 128 + (s (6 + j) & 127))) 0 ^4
                                             + ((s 5 & 16) ? 10 0)))
                   0)
   (flac-sniff s)
    (: i (flac-id3 s) p (max i 0)
       (? (i < 0 || (#s < 3 && snip "ID3" 0 #s = s)) 'more
          (#s < p + 4) (snip "fLaC" 0 (#s - p) = snip s p #s ? 'more 0)
          ("fLaC" = snip s p (p + 4)) 1
          0))
   (flac-format m)
    ((m 'bps + 7) // 8 @ w {'name "flac" 'desc "flac" 'w w 'bits (m 'bps) 'kind 's 'big 0
                            'ch (m 'ch) 'rate (m 'rate) 'align (w * m 'ch)})

   ; --- the frames ----------------------------------------------------------
   flac-why ["" "lost sync" "cut short" "a kind of FLAC frame this can't read"
             "a bad frame (its crc, or a reserved code)"]
   (flac-pump q h0 m emit)
    (: bps (m 'bps) ch (m 'ch)
       ; an id3v1 tag at the end is no frame
       (tail? h o) (#h - o = 128 && "TAG" = snip h o (o + 3))
       ; the next frame sync at or past i, -1 for none in h
       (sync h i) (? (#h <= i + 1) -1 (h i = 255 && (h (i + 1) & 254) = 248) i (sync h (i + 1)))
       ; until a frame has decoded, a stream entered mid-way (a seek) hunts for the next one,
       ; and a sync that is no frame is passed over
       (hunt h o) (sync h (o + 1) @ i (? (0 <= i) (go h i 1)
                                         (wav-gulp q @ g (string? g ? (go (snip h (max o (#h - 1)) #h + g) 0 1) (flac-why 1)))))
       (go h o first)
        (flac-frame h o bps ch @
          (pcm . nx) (emit pcm, go h nx 0)
          2 (wav-gulp q @ g (? (string? g) (go (snip h o #h + g) 0 first)
                               (o >= #h || tail? h o) 0
                               (flac-why 2)))
          1 (? (o >= #h) (wav-gulp q @ g (string? g ? (go g 0 first) 0))
               (tail? h o) 0
               first (hunt h o)
               (flac-why 1))
          w (? (first && w = 4) (hunt h o) (flac-why w)))
       (go h0 0 (peep m 'whole 0 ? 0 1)))
   ; little-endian signed samples of w bytes -> the same in the order and sign asked, up s bits:
   ; a wav's samples fill their bytes from the top
   (flac-lay pcm w s big uns)
    (: p (? (s = 0) pcm
            (: n (#pcm // w) c (cask #pcm)
               (pour c 0 pcm 0 #pcm, pinv c 0 w w ((peepv c 0 w w n) << s & ((1 << (8 * w)) - 1)), string c)))
       (? (!big && !uns) p
          (: n (#p // w) c (cask #p) out (cask #p)
             (pour c 0 p 0 #p,
              each ^w (k \ (: t (peepv c k 1 w n)
                              (pinv out (big ? (w - 1 - k) k) 1 w (uns && k = w - 1 ? (t ^ 128) t)))),
              string out))))
   flac-masks [4 3 7 51 1543 1551 1807 1599]
   (flac-wav-head m)
    (: ch (m 'ch) bps (m 'bps) w ((bps + 7) // 8) d (m 'total * ch * w)
       ext (ch > 2 || (bps != 8 && bps != 16))
       fmt ((ext ? 65534 1) @ tag
              (wrle tag 2 + wrle ch 2 + wrle (m 'rate) 4 + wrle (m 'rate * ch * w) 4 + wrle (ch * w) 2
               + wrle (8 * w) 2
               + (ext ? (wrle 22 2 + wrle bps 2 + wrle (flac-masks (ch - 1)) 4
                         + "\x01\x00\x00\x00\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71") "")))
       ; a size past 4 GiB is 0xffffffff, never wrapped
       ("RIFF" + wrle (min 4294967295 (20 + #fmt + d)) 4 + "WAVE" + "fmt " + wrle #fmt 4 + fmt + "data" + wrle (min 4294967295 d) 4))

   ; --- flac ----------------------------------------------------------------
   flac-usage "usage: flac [-0..-8] [-b N] [-T NAME=VALUE].. [--no-padding] [--no-seektable] [-c] [-f] [-s] [-o FILE] FILE..
       flac -d [-c] [-f] [-s] [-o FILE] [--force-raw-format --endian=little|big --sign=signed|unsigned] FILE..
       flac -t [-s] FILE..
  encodes each FILE (anything src/apps/av.l decodes; raw with --force-raw-format and
  --channels --bps --sample-rate --endian --sign) to FILE.flac, at level 5 unless -0..-8
  (--fast, --best) says; -b the blocksize, -T a tag. a flac re-encoded keeps its metadata. -d decodes each FILE.flac to FILE.wav,
  -t decodes and checks the stream's md5. -c writes to stdout, -o names the output, -f
  overwrites one that exists, -s is quiet."
   (flac-say o m) (o "s" ? 0 (say err m, flush err, 0))
   (flac-err m) (say err (m + "\n"), flush err, 1)
   (flac-exists? p) (open p "r" @ q (hot? q ? (close q, 1) 0))
   (flac-one o p)
    (: nm (p = "-" ? "stdin" p)
       q (p = "-" ? in (open p "r"))
       (? !(hot? q) (flac-err (nm + ": ERROR: " + uerrno q))
          (: r ((cite 'av 'av-head) q flac-meta "" @ ['short h] ["cut short" h] x x)
             m <r hb (r 1)
             fin (\ v (p = "-" ? v (close q, v)))
             (? (string? m) (fin (flac-err (nm + ": ERROR: " + m)))
                (o "t") (: b (cask 89) _ (md5-init b)
                          r (flac-pump q (snip hb (m 'at) #hb) (pin m 'whole 1) (pcm \ md5-feed b pcm))
                          sum (md5-done b)
                          (fin (? (string? r) (flac-err (nm + ": ERROR while decoding data: " + r))
                                  (m 'md5 != "00000000000000000000000000000000" && sum != m 'md5)
                                   (flac-err (nm + ": ERROR, MD5 signature mismatch"))
                                  (flac-say o (nm + ": ok\n")))))
                (: raw (o "raw")
                   w ((m 'bps + 7) // 8)
                   big (o "endian" = "big") uns (raw ? (o "sign" = "unsigned") (w = 1))
                   op (? (o "c" || (p = "-" && !(o "o"))) "-"
                         (o "o") (o "o")
                         ((#p > 5 && ".flac" = snip p (#p - 5) #p ? (snip p 0 (#p - 5)) p) + (raw ? ".raw" ".wav")))
                   (? (raw && !(o "endian" && o "sign"))
                       (fin (flac-err "ERROR: for decoding to a raw file you must specify --endian and --sign"))
                      (op != "-" && !(o "f") && flac-exists? op)
                       (fin (flac-err ("ERROR: output file " + op + " already exists, use -f to override")))
                      (: d (op = "-" ? out (open op "w"))
                         (? !(hot? d) (fin (flac-err ("ERROR: cannot write " + op + ": " + uerrno d)))
                            (: _ (raw ? () (say d (flac-wav-head m)))
                               r (flac-pump q (snip hb (m 'at) #hb) (pin m 'whole 1) (pcm \ say d (flac-lay pcm w (raw ? 0 (8 * w - m 'bps)) big uns)))
                               _ (flush d, op = "-" ? () (close d))
                               (fin (? (string? r) (flac-err (nm + ": ERROR while decoding data: " + r))
                                       (flac-say o (nm + ": done\n")))))))))))))
   ; --- encoding ------------------------------------------------------------
   flac-level-bs [1152 1152 1152 4096 4096 4096 4096 4096 4096]
   ; a field keeps its width while its value is () (the head laid ahead), as wrbe would not
   (flac-be v n) (string (map (k \ (v // (256 ** (n - 1 - k))) % 256) ^n))
   (flac-le v n) (string (map (k \ (v // (256 ** k)) % 256) ^n))
   (flac-unhex h) (string (map (i \ (: (d c) (c < 58 ? (c - 48) (c - 87)) (d (h (2 * i)) * 16 + d (h (2 * i + 1))))) ^(#h // 2)))
   (flac-block last t body) (string [((last ? 128 0) + t)] + flac-be #body 3 + body)
   ; a format's samples -> a fn to flac's little-endian signed ones | why not
   (flac-native f)
    (: w (f 'w) bits (f 'bits) big (f 'big) k (f 'kind)
       (? (charm? (f 'tag) && k != 's && k != 'u)
           ((f 'ext ? "unsupported WAVEFORMATEXTENSIBLE chunk with non-PCM format " "unsupported format type ")
            + show (f 'tag))
          (k != 's && k != 'u) ("can't encode " + f 'desc + " samples")
          (bits < 4 || bits > 32 || w != (bits + 7) // 8) ("can't encode " + f 'desc + " samples")
          (pcm \ (: le (big ? (flac-lay pcm w 1 0) pcm) (k = 'u ? (flac-lay le w 0 1) le)))))
   ; the input as [format meta held pump port] | why not
   (flac-src o q)
    (? (o "raw")
        (: bits (o "bps") ch (o "channels") rate (o "sample-rate")
           (? !(o "endian" && o "sign" && bits && ch && rate)
               "for raw input you must specify --channels, --bps, --sample-rate, --endian and --sign"
              (: w ((bits + 7) // 8)
                 f {'name "raw" 'desc "raw" 'w w 'bits bits 'kind (o "sign" = "unsigned" ? 'u 's)
                    'big (o "endian" = "big") 'ch ch 'rate rate 'align (ch * w) 'len -1}
                 [f f "" (cite 'wav 'wav-pump) q])))
       ; every block of a head is kept, so a re-encode carries its pictures
       ((cite 'av 'av-open-all) q @
          [nm m h] (: c ((cite 'av 'av-codec) nm)
                      [((c 3) m) m h (c 4) q])
          why why))
   ; a source encoded onto port d (the file op, or "-") a frame at a time -> [bytes total] |
   ; why not. the metadata goes ahead at its final length -- a seek table sized for the total
   ; the input declares -- and is laid over again at the end, once the totals, md5 and frame
   ; sizes are known; on "-", which cannot be sought, it stays as first written, as flac's does
   (flac-enc o [f m h pump q] d op)
    (: lv (o "level" @ () 5 n n) bs (o "b" @ () (flac-level-bs lv) n n)
       ch (f 'ch) bps (f 'bits) rate (f 'rate) w ((bps + 7) // 8) fs (ch * w)
       conv (flac-native f)
       b (cask 89)
       st {'buf "" 'fno 0 'sizes () 'total 0 'err () 'out 0}
       ; frames the input says it holds, -1 for a stream that does not say
       dt (? (charm? (peep m 'total ()) && 0 < m 'total) (m 'total)
             (charm? (peep m 'len ()) && 0 < m 'len) (m 'len // m 'align)
             -1)
       (frame pcm) (flac-encode pcm ch bps rate (st 'fno) lv @
                      e (? (string? e) (: _ (say d e)
                                          (pins st 'fno (st 'fno + 1) 'sizes ([(#pcm // fs) #e] . st 'sizes)
                                                'total (st 'total + #pcm // fs) 'out (st 'out + #e)))
                           (pin st 'err "a frame that cannot be encoded")))
       (take pcm) (: _ (md5-feed b pcm) hh (st 'buf + pcm) blk (bs * fs) n (#hh // blk)
                     _ (each ^n (i \ frame (snip hh (i * blk) (i * blk + blk))))
                     (pin st 'buf (snip hh (n * blk) #hh)))
       ; a seek point every 10 seconds, at the frame holding it; np points, placeholders past
       ; the last real one, so the table is as long as was laid
       (points total offs sizes np)
        (: (go k acc) (? (total <= k * 10 * rate) (rev acc)
                         (: fi (k * 10 * rate // bs) sn (fi * bs)
                            (go (k + 1) (acc && <<acc = sn ? acc ([sn (offs fi) (<(sizes fi))] . acc)))))
           real (total = 0 || atom? sizes ? () (go 0 ()))
           ps (snip real 0 (min np #real))
           (join "" (map (p \ flac-be (p 0) 8 + flac-be (p 1) 8 + flac-be (p 2) 2) ps)
            + join "" (map (_ \ flac-be 18446744073709551615 8 + flac-be 0 8 + flac-be 0 2) ^(np - #ps))))
       np (? (dt <= 0) 0 (: (go k acc) (? (dt <= k * 10 * rate) acc
                                          (: sn (k * 10 * rate // bs * bs) (go (k + 1) (acc && <acc = sn ? acc (sn . acc)))))
                            #(go 0 ())))
       vendor ("love " + love-version)
       (vc ts) (flac-le #vendor 4 + vendor + flac-le #ts 4 + join "" (map (t \ flac-le #t 4 + t) ts))
       ; a flac re-encoded keeps its blocks but STREAMINFO, the padding's length, and its tags
       ; unless -T gives others
       kf (tablet? m && string? (peep m 'head ()))
       hd (kf ? (m 'head) "")
       bl (kf ? (m 'blocks) ())
       rt (two? (o "tags") && two? (filter (b \ <b = 4) bl))
       kept (filter (b \ <b != 0 && <b != 1 && !(rt && <b = 4)) bl)
       (has t) (two? (filter (b \ <b = t) kept))
       padn (filter (b \ <b = 1) bl @ (b . _) (b 1) _ 8192)
       ; the whole head for totals known so far: [total offs sizes md5]
       (head total offs sizes md5)
        (: fb (map (z \ z 1) sizes) one (#sizes < 2)
           mb (one && 0 < total ? (total < bs ? total bs) bs)
           info (flac-be mb 2 + flac-be mb 2
                 + flac-be (fb ? (foldl min <fb fb) 0) 3 + flac-be (fb ? (foldl max 0 fb) 0) 3
                 + flac-be (((rate * 8 + ch - 1) * 32 + bps - 1) * 68719476736 + total) 8
                 + md5)
           (body [t n p]) (t @ 3 (flac-reseek (snip hd p (p + n)) total bs offs sizes)
                               4 (vc (m 'tags))
                               _ (snip hd p (p + n)))
           bks ((? (has 3 || o "noseek" || np = 0) () [[3 (points total offs sizes np)]])
                + (has 4 ? () [[4 (vc (o "tags" @ () () t (rev t)))]])
                + map (b \ [<b (body b)]) kept + (o "nopad" ? () [[1 (string (cask padn))]]))
           ("fLaC" + flac-block 0 0 info
            + join "" (map (i \ flac-block (i = #bks - 1) <(bks i) ((bks i) 1)) ^#bks)))
       z16 (string (cask 16))
       (? (string? conv) conv
          (ch > 8) "can't encode past 8 channels"
          (bs < 16 || bs > 65535) "a blocksize must be 16 to 65535"
          (: h0 (head (dt < 0 ? 0 dt) [0] () z16)
             _ (say d h0)
             _ (md5-init b)
             r (pump q h m (pcm \ take (conv pcm)))
             _ (#(st 'buf) ? (frame (st 'buf)) ())
             (? (string? r) r
                (string? (st 'err)) (st 'err)
                (: total (st 'total) sizes (rev (st 'sizes))
                   offs (rev (foldl (\ a z ((<a + z 1) . a)) [0] sizes))
                   h1 (head total offs sizes (flac-unhex (md5-done b)))
                   _ (flush d)
                   (? (#h1 != #h0) "the metadata changed its length"
                      (op = "-") [(#h0 + st 'out) total]
                      (: _ (close d)
                         (((cite 'av 'av-patch) op 0 h1) @ 0 [(#h1 + st 'out) total] why why))))))))
   ; a kept seektable's points moved to the frames that now hold them: sorted, a repeat a
   ; placeholder, a point past the end left as it was
   (flac-reseek s total bs offs sizes)
    (: ph (string (map (k \ 255) ^8))
       ps (map (i \ snip s (18 * i) (18 * i + 18)) ^(#s // 18))
       live (filter (p \ snip p 0 8 != ph && rdbe p 0 8 < total) ps)
       far (filter (p \ snip p 0 8 != ph && rdbe p 0 8 >= total) ps)
       sns (foldl (\ a sn (two? a && <a = sn ? a (sn . a))) () (sort (map (p \ rdbe p 0 8 // bs * bs) live)))
       re (map (sn \ flac-be sn 8 + flac-be (offs (sn // bs)) 8 + flac-be (<(sizes (sn // bs))) 2) (rev sns))
       (join "" (re + far + map (k \ ph + string (cask 10)) ^(#ps - #re - #far))))
   ; to three places, rounded; flac input on stdin has no size to say it against
   (flac-ratio a b) (? !(charm? b) "N/A"
                       ((b ? ((2000 * a + b) // (2 * b)) 0) @ k (show (k // 1000) + "." + snip (show (1000 + k % 1000)) 1 4)))
   ; what flac measures the ratio against: a flac file's size, a wav's samples and a header
   (flac-den o p [f m h pump q] total)
    (? (o "raw") (total * f 'align)
       (string? (m 'head)) (p = "-" ? 'na <((cite 'posix 'stat) p))
       (total * f 'align + 44))
   ; flac's warnings, which -s does not quiet
   (flac-warn o p [f m h pump q])
    (: sk (string? (flac-native f) ? () (f 'skip @ (l && two? l) l _ ()))
       rt (two? (o "tags") && string? (m 'head) && two? (filter (b \ <b = 4) (m 'blocks)))
       _ (each sk (id \ say err (p + ": WARNING: skipping unknown chunk '" + id + "' (use --keep-foreign-metadata to keep)\n")))
       _ (? rt (say err (p + ": WARNING, replacing tags from input FLAC file with those given on the command-line\n")) ())
       (flush err, 1))
   flac-same (" already exists.\n\nBy default flac encodes files to FLAC format; if you meant to decode this file\n"
              + "from FLAC to something else, use -d.  If you meant to re-encode this file from\n"
              + "FLAC to FLAC again, use -f to force writing to the same file, or -o to specify\n"
              + "a different output filename.")
   (flac-enc-one o p)
    (: nm p
       q (p = "-" ? in (open p "r"))
       (? !(hot? q) (flac-err (nm + ": ERROR: " + uerrno q))
          (: fin (\ v (p = "-" ? v (close q, v)))
             op (? (o "c" || (p = "-" && !(o "o"))) "-"
                   (o "o") (o "o")
                   (: i (foldl (\ a k (p k = 46 ? k a)) -1 ^#p)
                      ((0 < i && i > foldl (\ a k (p k = 47 ? k a)) -1 ^#p ? (snip p 0 i) p) + ".flac")))
             (? (op != "-" && !(o "f") && flac-exists? op)
                 (fin (flac-err ("ERROR: output file " + op
                                 + (op = p ? flac-same " already exists, use -f to override"))))
                (flac-src o q @
                   (why && string? why) (fin (flac-err (nm + ": ERROR: " + why)))
                   src (: d (op = "-" ? out (open op "w"))
                          (? !(hot? d) (fin (flac-err ("ERROR: cannot write " + op + ": " + uerrno d)))
                             ((flac-warn o p src, flac-enc o src d op) @
                               ; a failed encode leaves no half a file behind
                               (why && string? why) (: _ (? (op = "-") () (close d, (cite 'posix 'unlink) op))
                                                       (fin (flac-err (nm + ": ERROR: " + why))))
                               [n total] (fin (flac-say o (nm + ": wrote " + show n + " bytes, ratio="
                                                           + flac-ratio n (flac-den o p src total) + "\n")))))))))))
   flac-long {"decode" "d" "test" "t" "stdout" "c" "force" "f" "silent" "s"
              "no-padding" "nopad" "no-seektable" "noseek"}
   (flac-num s) (string? s && #s && all (c \ 48 <= c <= 57) (chars s)
                 ? (foldl (\ a c (a * 10 + c - 48)) 0 (chars s)))
   ; a value option: -b, -o and -T take one, glued or the next word
   (flac-val o k v)
    (k @ "b" (flac-num v @ n (n ? (pin o "b" n, 1) (flac-err ("ERROR: bad blocksize " + v), ())))
         "o" (pin o "o" v, 1)
         "T" (0 < findsub v "=" ? (pin o "tags" (v . peep o "tags" ()), 1) (flac-err ("ERROR: bad tag " + v), ()))
         _ ())
   (flac-main as)
    (: o {}
       (go l fs)
        (? (atom? l)
            (foldl (\ st p ((o "d" || o "t" ? flac-one flac-enc-one) o p @ r (r ? r st))) 0
                   (two? fs ? (rev fs) ["-"]))
           (: a <l
              (? (a = "--") (go () (rev >l + fs))
                 (a = "--force-raw-format") (pin o "raw" 1, go >l fs)
                 (a = "--fast") (pin o "level" 0, go >l fs)
                 (a = "--best") (pin o "level" 8, go >l fs)
                 (2 < #a && "--" = snip a 0 2)
                  (: i (findsub a "=") k (snip a 2 (i < 0 ? #a i)) v (snip a (i + 1) #a)
                     (? (k = "output-name" && 0 <= i) (pin o "o" v, go >l fs)
                        (k = "tag" && 0 <= i) (flac-val o "T" v ? (go >l fs) 1)
                        (k = "blocksize" && 0 <= i) (flac-val o "b" v ? (go >l fs) 1)
                        ((k = "channels" || k = "bps" || k = "sample-rate") && flac-num v)
                         (pin o k (flac-num v), go >l fs)
                        ((k = "endian" && (v = "little" || v = "big"))
                         || (k = "sign" && (v = "signed" || v = "unsigned")))
                         (pin o k v, go >l fs)
                        (string? (flac-long k)) (pin o (flac-long k) 1, go >l fs)
                        (flac-err ("ERROR: unknown option " + a))))
                 (1 < #a && 45 = a 0)
                  (: c (string [(a 1)]) rest (snip a 2 #a)
                     (? (elem (a 1) (chars "boT"))
                         (? #rest (flac-val o c rest ? (go >l fs) 1)
                            (two? >l) (flac-val o c <>l ? (go >>l fs) 1)
                            (flac-err ("ERROR: option -" + c + " needs a value")))
                        (all (c \ elem c (chars "dtcfs012345678")) (chars (snip a 1 #a)))
                         (each (chars (snip a 1 #a))
                               (c \ (48 <= c <= 56 ? (pin o "level" (c - 48)) (pin o (string [c]) 1))),
                          go >l fs)
                        (flac-err ("ERROR: unknown option " + a))))
                 (go >l (a . fs)))))
       (go as ()))

   ; --- metaflac, reading ---------------------------------------------------
   metaflac-usage "usage: metaflac [--list] [--show-md5sum] [--show-min-blocksize] [--show-max-blocksize]
       [--show-min-framesize] [--show-max-framesize] [--show-sample-rate] [--show-channels]
       [--show-bps] [--show-total-samples] [--show-vendor-tag] [--show-tag=NAME]
       [--export-tags-to=-] FILE..
  reading only; editing is not built yet."
   flac-types ["STREAMINFO" "PADDING" "APPLICATION" "SEEKTABLE" "VORBIS_COMMENT" "CUESHEET" "PICTURE"]
   (mf-list s m)
    (: (n i [t len p])
        (: kind (t < 7 ? (flac-types t) "UNKNOWN")
           last (i = #(m 'blocks) - 1)
           ("METADATA block #" + show i + "\n  type: " + show t + " (" + kind + ")\n  is last: "
            + (last ? "true" "false") + "\n  length: " + show len + "\n"
            + (t @ 0 ("  minimum blocksize: " + show (m 'minbs) + " samples\n  maximum blocksize: "
                       + show (m 'maxbs) + " samples\n  minimum framesize: " + show (m 'minfr)
                       + " bytes\n  maximum framesize: " + show (m 'maxfr) + " bytes\n  sample_rate: "
                       + show (m 'rate) + " Hz\n  channels: " + show (m 'ch) + "\n  bits-per-sample: "
                       + show (m 'bps) + "\n  total samples: " + show (m 'total) + "\n  MD5 signature: "
                       + m 'md5 + "\n")
                  3 (: k (len // 18)
                       ("  seek points: " + show k + "\n"
                        + join "" (map (j \ (: q (p + 18 * j)
                                          ("    point " + show j
                                           + (rdbe s q 8 = 18446744073709551615 ? ": PLACEHOLDER\n"
                                              (": sample_number=" + show (rdbe s q 8) + ", stream_offset="
                                               + show (rdbe s (q + 8) 8) + ", frame_samples="
                                               + show (rdbe s (q + 16) 2) + "\n")))))
                                   ^k)))
                  4 (flac-tags s p len @ [v ts]
                       ("  vendor string: " + v + "\n  comments: " + show #ts + "\n"
                        + join "" (map (j \ "    comment[" + show j + "]: " + ts j + "\n") ^#ts)))
                  2 ("  application ID: " + b2hex (snip s p (p + 4)) + "\n")
                  "")))
       (join "" (map (i \ n i (m 'blocks i)) ^#(m 'blocks))))
   (mf-tag ts k) (filter (t \ (findsub t "=") @ i (0 < i && upper (snip t 0 i) = upper k)) ts)
   mf-opts ["--list" "--show-md5sum" "--show-min-blocksize" "--show-max-blocksize" "--show-min-framesize"
            "--show-max-framesize" "--show-sample-rate" "--show-channels" "--show-bps"
            "--show-total-samples" "--show-vendor-tag" "--export-tags-to=-"]
   (mf-show s m a)
    (: (num k) (show (m k) + "\n")
       (? (11 < #a && "--show-tag=" = snip a 0 11)
           (foldl (\ r t (r + t + "\n")) "" (mf-tag (m 'tags) (snip a 11 #a)))
        (a @ "--list" (mf-list s m)
            "--show-md5sum" (m 'md5 + "\n") "--show-min-blocksize" (num 'minbs)
            "--show-max-blocksize" (num 'maxbs) "--show-min-framesize" (num 'minfr)
            "--show-max-framesize" (num 'maxfr) "--show-sample-rate" (num 'rate)
            "--show-channels" (num 'ch) "--show-bps" (num 'bps) "--show-total-samples" (num 'total)
            "--show-vendor-tag" (m 'vendor + "\n")
            "--export-tags-to=-" (foldl (\ r t (r + t + "\n")) "" (m 'tags))
            ())))
   ; one file's answers, each line led by its name when there are several
   (mf-print ops pre s)
    (: m (flac-meta s)
       (? !(tablet? m) (flac-err ("ERROR: " + (string? m ? m "cut short")))
          (: _ (each ops (a \ say out (a = "--list" ? (mf-show s m a)
                                       (join "" (map (x \ pre + x + "\n") (lines (mf-show s m a)))))))
             _ (flush out)
             0)))
   ; the head alone, every block of it
   (mf-file ops pre p)
    (open p "r" @ q
      (? !(hot? q) (flac-err (p + ": ERROR: No such file or directory"))
         (: r ((cite 'av 'av-head-all) q flac-meta "" @ [_ h] h _ "") _ (close q)
            (mf-print ops pre r))))
   (metaflac-main as)
    (: ops (filter (a \ 2 < #a && "--" = snip a 0 2) as)
       fs (filter (a \ !(2 < #a && "--" = snip a 0 2)) as)
       bad (filter (a \ !(elem a mf-opts || (11 < #a && "--show-tag=" = snip a 0 11))) ops)
       (? (two? bad) (flac-err ("metaflac: ERROR: unknown option " + <bad + "\n" + metaflac-usage))
          !(two? fs) (flac-err ("metaflac: ERROR: you must specify at least one FLAC file\n" + metaflac-usage))
          (foldl (\ st p (mf-file (two? ops ? ops ["--list"]) (#fs > 1 ? (p + ":") "") p @ r (r ? r st)))
                 0 fs)))
   _ (pins (cite 'verbs 'tab) 'flac (udoor 'flac flac-main flac-usage 1 0))
   _ (pins (cite 'verbs 'tab) 'metaflac (udoor 'metaflac metaflac-main metaflac-usage 1 1)))
) ; module flac
