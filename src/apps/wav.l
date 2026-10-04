; src/apps/wav.l -- wav reading, pcm conversion to the horn's s16, and aplay over both.
; `(borrow 'wav)`, then:
;
;   (wav-head s)        -> a format tablet with 'at and 'len, the data chunk's offset and
;                          length (-1 to the end) | 'raw not a wav | 'more | why not
;   (wav-format name)   -> the format tablet aplay's -f names, case aside | ()
;   (wav-pcm f n c)     -> n frames of cask c in format f, as interleaved s16le of one or
;                          two channels: a cask
;   (aplay-main as)     -> the verb: `love aplay [-q] [-t wav|raw] [-f F] [-c N] [-r N]
;                          [-d SECS] [-s FRAMES] [FILE..]`
;
; a format tablet: 'name 'desc as aplay spells them, 'w bytes a sample, 'bits significant,
; 'kind (s u f mu a), 'big, and for a stream 'ch 'rate 'align. conversion is ffmpeg's:
; integers floor down to 16 bits, floats round half to even and saturate, the laws are g.711's.
; past two channels the first two are played. a stream is read a gulp at a time.
(module (wav wav-head wav-format wav-pcm wav-desc aplay-main aplay-usage)
(:
   peepv (cite 'guts 'peepv) pinv (cite 'guts 'pinv)
   open (cite 'posix 'open) close (cite 'posix 'close)

   ; --- the formats ----------------------------------------------------------
   ; one row per name: width, significant bits, kind, big, words
   wav-rows [["S8" 1 8 's 0 "Signed 8 bit"] ["U8" 1 8 'u 0 "Unsigned 8 bit"]
             ["S16_LE" 2 16 's 0 "Signed 16 bit Little Endian"] ["S16_BE" 2 16 's 1 "Signed 16 bit Big Endian"]
             ["U16_LE" 2 16 'u 0 "Unsigned 16 bit Little Endian"] ["U16_BE" 2 16 'u 1 "Unsigned 16 bit Big Endian"]
             ["S24_LE" 4 24 's 0 "Signed 24 bit Little Endian"] ["S24_BE" 4 24 's 1 "Signed 24 bit Big Endian"]
             ["U24_LE" 4 24 'u 0 "Unsigned 24 bit Little Endian"] ["U24_BE" 4 24 'u 1 "Unsigned 24 bit Big Endian"]
             ["S32_LE" 4 32 's 0 "Signed 32 bit Little Endian"] ["S32_BE" 4 32 's 1 "Signed 32 bit Big Endian"]
             ["U32_LE" 4 32 'u 0 "Unsigned 32 bit Little Endian"] ["U32_BE" 4 32 'u 1 "Unsigned 32 bit Big Endian"]
             ["FLOAT_LE" 4 32 'f 0 "Float 32 bit Little Endian"] ["FLOAT_BE" 4 32 'f 1 "Float 32 bit Big Endian"]
             ["FLOAT64_LE" 8 64 'f 0 "Float 64 bit Little Endian"] ["FLOAT64_BE" 8 64 'f 1 "Float 64 bit Big Endian"]
             ["MU_LAW" 1 8 'mu 0 "Mu-Law"] ["A_LAW" 1 8 'a 0 "A-Law"]
             ["S24_3LE" 3 24 's 0 "Signed 24 bit Little Endian in 3bytes"]
             ["S24_3BE" 3 24 's 1 "Signed 24 bit Big Endian in 3bytes"]
             ["U24_3LE" 3 24 'u 0 "Unsigned 24 bit Little Endian in 3bytes"]
             ["U24_3BE" 3 24 'u 1 "Unsigned 24 bit Big Endian in 3bytes"]]
   (wav-format name)
    (upper name @ u
       (: (go l) (? (atom? l) ()
                    (<<l = u) (<l @ [n w b k g d] {'name n 'w w 'bits b 'kind k 'big g 'desc d})
                    (go >l))
          (go wav-rows)))
   (wav-desc f) (f 'desc + ", Rate " + show (f 'rate) + " Hz, "
                 + (f 'ch @ 1 "Mono" 2 "Stereo" n ("Channels " + show n)))

   ; --- the RIFF walk --------------------------------------------------------
   (wav-le s i n) (foldl (\ a j (a * 256 + s (i + j))) 0 (rev ^n))
   (wav-hex n) (: d "0123456789abcdef" (string (map (k \ d ((n >> k) & 15)) [12 8 4 0])))
   ; the fmt chunk at p, of size z -> a format tablet | why not
   (wav-fmt s p z)
    (: tag0 (wav-le s p 2)
       tag (tag0 = 65534 && z >= 26 ? (wav-le s (p + 24) 2) tag0)
       ch (wav-le s (p + 2) 2) rate (wav-le s (p + 4) 4)
       align (wav-le s (p + 12) 2) bits (wav-le s (p + 14) 2)
       name (? (tag = 1) (bits @ 8 "U8" 16 "S16_LE" 32 "S32_LE"
                               24 (ch && align // ch = 4 ? "S24_LE" "S24_3LE") ())
               (tag = 3) (bits @ 32 "FLOAT_LE" 64 "FLOAT64_LE" ())
               (tag = 6) "A_LAW"
               (tag = 7) "MU_LAW"
               'tag)
       (? (name = 'tag) ("can't play WAVE-file format 0x" + wav-hex tag + " which is not PCM or FLOAT encoded")
          !(string? name) ("can't play WAVE-files with sample " + show bits + " bits wide")
          (ch < 1) "can't play WAVE-files with no channels"
          (wav-format name @ f
             (align < ch * f 'w ? "a WAVE-file whose frame is narrower than its samples"
                (pins f 'ch ch 'rate rate 'align align)))))
   (wav-head s)
    (: (go i f)
        (? (#s < i + 8) 'more
           (: id (snip s i (i + 4)) z (wav-le s (i + 4) 4)
              (? (id = "data") (? !(tablet? f) "a WAVE-file with no fmt chunk ahead of its data"
                                  (pins f 'at (i + 8) 'len (z = 0 || z = 4294967295 ? -1 z)))
                 (id = "fmt ") (? (#s < i + 8 + z) 'more
                                  (wav-fmt s (i + 8) z @ g (string? g ? g (go (i + 8 + z + (z & 1)) g))))
                 (go (i + 8 + z + (z & 1)) f))))
       (? (#s < 12) (#s < 4 || "RIFF" = snip s 0 4 ? 'more 'raw)
          ("RIFF" = snip s 0 4 && "WAVE" = snip s 8 12) (go 12 ())
          'raw))

   ; --- the samples ----------------------------------------------------------
   ; n samples of w <= 4 bytes at byte off, a frame apart: an unsigned tray
   (wav-word c n align off w big)
    (? (!big || w = 1) (peepv c off w align n)
       (foldl (\ a j (a + ((peepv c (off + j) 1 align n) << (8 * (w - 1 - j))))) 0 ^w))
   ; mag rounded half to even off (N >> s), saturated as ffmpeg's av_clip_int16
   (wav-round sgn N s big)
    (: q (N >> s) r (N - (q << s)) half ((1 << s) >> 1)
       up ((s > 0) * ((r > half) + (r = half) * (q & 1)))
       mag ((q + up) * (1 - big) + big * 65536)
       ((1 - sgn) * (min mag 32767) - sgn * (min mag 32768)))
   ; channel k as an s16 tray
   (wav-chan f n c k)
    (: w (f 'w) bits (f 'bits) big (f 'big) align (f 'align) off (k * w)
       (f 'kind @
         'f (? (w = 4)
               (: u (wav-word c n align off 4 big) e ((u >> 23) & 255)
                  N ((u & 8388607) + (e > 0) * 8388608)
                  (wav-round (u >> 31) N (min 25 (max 0 (135 - e))) (e >= 135)))
               (: lo (wav-word c n align (off + big * 4) 4 big)
                  hi (wav-word c n align (off + (1 - big) * 4) 4 big)
                  e ((hi >> 20) & 2047)
                  N ((((hi & 1048575) + (e > 0) * 1048576) << 32) + lo)
                  (wav-round (hi >> 31) N (min 54 (max 0 (1060 - e))) (e >= 1060))))
         'mu (: x (255 - wav-word c n align off 1 0)
                t ((((x & 15) << 3) + 132) << ((x & 112) >> 4))
                ((t - 132) * (1 - 2 * (x >> 7))))
         'a (: x ((wav-word c n align off 1 0) ^ 85) t (x & 15) seg ((x & 112) >> 4)
               m ((seg > 0) * ((2 * t + 33) << (seg + 2)) + (seg = 0) * ((2 * t + 1) << 3))
               (m * (2 * (x >> 7) - 1)))
         kind (: mask ((1 << bits) - 1)
                 u ((wav-word c n align off w big) & mask)
                 v (kind = 's ? ((u + (1 << (bits - 1))) & mask) u)
                 ((bits > 16 ? (v >> (bits - 16)) (v << (16 - bits))) - 32768))))
   (wav-pcm f n c)
    (: o (min 2 (f 'ch)) out (cask (n * 2 * o))
       (n = 0 ? out
        (each ^o (k \ pinv out (2 * k) 2 (2 * o) (wav-chan f n c k)), out)))

   ; --- the verb -------------------------------------------------------------
   aplay-usage "usage: aplay [-q] [-t wav|raw] [-f FORMAT] [-c N] [-r RATE] [-d SECS] [-s FRAMES] [FILE..]
  -f is one of S8 U8 S16_LE S16_BE U16_LE U16_BE S24_LE S24_BE U24_LE U24_BE S32_LE S32_BE
  U32_LE U32_BE FLOAT_LE FLOAT_BE FLOAT64_LE FLOAT64_BE MU_LAW A_LAW S24_3LE S24_3BE U24_3LE
  U24_3BE, or cd, cdr, dat; raw defaults to U8, 8000 Hz, mono. the horn picks the device:
  HORN=PATH names one, HORN=none plays to a sink that keeps time."
   (aplay-fail m) (say err ("aplay: " + m + "\n"), flush err, 1)
   (aplay-int s) (string? s && #s && all (c \ 48 <= c <= 57) (chars s)
                  ? (foldl (\ a c (a * 10 + c - 48)) 0 (chars s)))
   ; the horn's close drops what it holds, so wait it out as aplay's drain does
   (aplay-drain hn) (horn-lag hn @ n (charm? n && 0 < n ? (rest 10, aplay-drain hn) 0))
   ; held bytes then the port's gulps, a whole frame at a time, out the horn
   (aplay-pump q h0 f left cap hn)
    (: align (f 'align)
       (gulp _) (see q @ -1 () c (unsee q c, chug q))
       (go h left cap)
        (? (left = 0 || cap = 0) 1
           (: k (#h // align @ k (cap < 0 ? k (min k cap)))
              (? (k = 0) (gulp () @ g (? !(string? g) 1 (: g2 (left < 0 || #g <= left ? g (snip g 0 left))
                                                   (go (h + g2) (left < 0 ? left (left - #g2)) cap))))
                 (: m (k * align) c (cask m)
                    (pour c 0 h 0 m, say hn (wav-pcm f k c),
                     go (snip h m #h) left (cap < 0 ? cap (cap - k)))))))
       (go (left < 0 || #h0 <= left ? h0 (snip h0 0 left)) (left < 0 ? left (max 0 (left - #h0))) cap))
   ; one input, its port q named nm: read the head, open the horn, pump
   (aplay-one o q nm)
    (: (more h) (see q @ -1 h c (unsee q c, h + chug q))
       ; -> [what wav-head says, the bytes read for it]; a short head that is no RIFF is raw
       (head h) (wav-head h @ 'more (more h @ h2 (#h2 = #h ? [("RIFF" = snip h 0 4 ? 'more 'raw) h]
                                                        (head h2)))
                                r [r h])
       rh (o 't = 'raw ? ['raw (more "")] (head (more "")))
       hb <>rh
       r (<rh = 'more ? "a WAVE-file cut short ahead of its data" <rh)
       wav (tablet? r)
       (? (string? r) (aplay-fail r)
          (!wav && o 't = 'wav) (aplay-fail (nm + ": not a WAVE-file"))
          (: fo (o 'f)
             f (wav ? r (pins fo 'ch (o 'c) 'rate (o 'r) 'align (o 'c * fo 'w)))
             cap (? (0 <= o 'd) (o 'd * f 'rate) (0 <= o 's) (o 's) -1)
             h (wav ? (snip hb (r 'at) #hb) hb)
             (? (f 'rate < 8000 || 192000 < f 'rate)
                 (aplay-fail ("rate " + show (f 'rate) + " Hz is outside the horn's 8000..192000"))
                (o 'q ? () (say err ("Playing " + (wav ? "WAVE" "raw data") + " '" + nm + "' : "
                                     + wav-desc f + "\n"), flush err),
                 horn (f 'rate) (min 2 (f 'ch)) @ hn
                  (nom? hn ? (aplay-fail ("audio open error: " + show hn))
                   (aplay-pump q h f (wav ? (r 'len) -1) cap hn,
                    flush hn, aplay-drain hn, close hn, 0)))))))
   (aplay-file o p)
    (? (p = "-") (aplay-one o in "stdin")
       (open p "r" @ q
         (hot? q ? (aplay-one o q p @ r (close q, r))
            (say err (p + ": " + uerrno q + "\n"), flush err, 1))))
   ; -x V, -xV and --long=V; aplay's -r takes kHz below 300
   aplay-long {"quiet" "-q" "file-type" "-t" "format" "-f" "channels" "-c" "rate" "-r"
               "duration" "-d" "samples" "-s"}
   (aplay-set o k v)
    (k @ "-t" ((lower v) @ "wav" (pin o 't 'wav, 1) "raw" (pin o 't 'raw, 1)
                            (aplay-fail ("unrecognized file format " + v), ()))
         "-f" ((lower v) @ "cd" (pins o 'f (wav-format "S16_LE") 'r 44100 'c 2, 1)
                           "cdr" (pins o 'f (wav-format "S16_BE") 'r 44100 'c 2, 1)
                           "dat" (pins o 'f (wav-format "S16_LE") 'r 48000 'c 2, 1)
                           _ (wav-format v @ f (tablet? f ? (pin o 'f f, 1) (aplay-fail ("wrong extended format '" + v + "'"), ()))))
         "-c" (aplay-int v @ n (n && 0 < n ? (pin o 'c n, 1) (aplay-fail ("value " + v + " for channels is invalid"), ())))
         "-r" (aplay-int v @ n (n && 0 < n ? (pin o 'r (n < 300 ? (n * 1000) n), 1) (aplay-fail ("bad speed value " + v), ())))
         "-d" (aplay-int v @ n (charm? n ? (pin o 'd (n ? n -1), 1) (aplay-fail ("bad duration " + v), ())))
         "-s" (aplay-int v @ n (charm? n ? (pin o 's (n ? n -1), 1) (aplay-fail ("bad samples " + v), ())))
         (aplay-fail ("invalid option -- '" + snip k 1 #k + "'"), ()))
   (aplay-main as)
    (: o {'q 0 't () 'f (wav-format "U8") 'c 1 'r 8000 'd -1 's -1}
       (go l fs)
        (? (atom? l) (foldl (\ st p (aplay-file o p @ r (r ? r st))) 0 (two? fs ? (rev fs) ["-"]))
           (: a <l
              (? (a = "--") (go () (rev >l + fs))
                 (a = "-q" || a = "--quiet") (pin o 'q 1, go >l fs)
                 (2 < #a && "--" = snip a 0 2)
                  (: i (findsub a "=") k (snip a 2 (i < 0 ? #a i)) s (aplay-long k)
                     (? !(string? s) (aplay-fail ("unrecognized option '" + a + "'"))
                        (s = "-q") (pin o 'q 1, go >l fs)
                        (i < 0) (two? >l ? (aplay-set o s <>l ? (go >>l fs) 1) (aplay-fail ("option '" + a + "' needs a value")))
                        (aplay-set o s (snip a (i + 1) #a) ? (go >l fs) 1)))
                 (1 < #a && 45 = a 0)
                  (: k (snip a 0 2)
                     (? (2 < #a) (aplay-set o k (snip a 2 #a) ? (go >l fs) 1)
                        (two? >l) (aplay-set o k <>l ? (go >>l fs) 1)
                        (aplay-fail ("option requires an argument -- '" + snip a 1 2 + "'"))))
                 (go >l (a . fs)))))
       (go as ()))
   _ (pins (cite 'verbs 'tab) 'aplay (udoor 'aplay aplay-main aplay-usage 1 0)))
) ; module wav
