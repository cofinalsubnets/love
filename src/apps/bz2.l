; src/apps/bz2.l -- bzip2 over src/love/lib/bz2.c, which holds the whole stream: its blocks lie on bit
; boundaries, so there is no container to read here. `(borrow 'bz2)`, then:
;   (bz2-pack s level)  -> the .bz2 bytes of s, level 1..9 the block in 100k
;   (bz2-unpack s)      -> (1 bytes) | a word saying why not ('format 'corrupt 'end 'check 'big):
;                          every stream in s, each block's crc and each stream's held
;   (bz2-pull rd)       -> g, a reader over the streams as they come: (bz2-next g) the next
;                          block's bytes, "" once done, and g's 'ans then (1 n) | the word
;   (bz2-unf rd mk)     -> (1 n) | the word | 'no: off rd, out through the writer mk answers
;                          (1 w), or () for 'no
(module 'bz2
(: (bz2-pack s level) (bz2e s level)
   (bz2-word c) (c @ 1 'format 3 'end 4 'check 5 'big 'corrupt)
   (bz2-unpack s) (: u (bz2d s) (? (string? u) [1 u] (bz2-word u)))

   ; bz2d's walk a block at a time off rd (rd _ the next piece, "" at the end). a block lies
   ; on bits and says its length only by ending, so the input is held a little past the
   ; biggest a block runs to, and one that runs past what is held is tried again with more
   bz2-hold 1100000
   (bz2-pull rd) {'rd rd 'st (bz2-new 0) 'buf "" 'eof 0 'n 0 'mode 'go}
   (bz2-more g)                        ; the buffer topped up past bz2-hold and a piece, or the end said
    (: want (max bz2-hold (#(g 'buf) + 65536))
       (fill acc have) (? (want <= have) acc
                          (: p (g 'rd 0) (? (#p = 0) (: _ (pin g 'eof 1) acc) (fill (p . acc) (have + #p)))))
       ps (fill () #(g 'buf))
       (? (two? ps) (pin g 'buf (cats (g 'buf . rev ps))) (pin g 'eof 1)))
   (bz2-next g)
    (? (peep g 'mode 'go = 'end) ""
       (: r (bz2-step (g 'st) (g 'buf) (g 'eof))
          (? (two? r) (: o <r
                         _ (pins g 'buf (snip (g 'buf) >r #(g 'buf)) 'n (g 'n + #o))
                         (? (#o = 0) (bz2-next g) o))
             (r = -1) (: _ (bz2-more g) (bz2-next g))
             (: _ (pins g 'mode 'end 'ans (? (r = 0) [1 (g 'n)] (charm? r) (bz2-word r) 'corrupt)) ""))))
   ; mk is asked for the writer before the first byte out; a stream that fails before any
   ; is said without it
   (bz2-unf rd mk)
    (: g (bz2-pull rd)   p (bz2-next g)
       (? (#p = 0 && atom? (g 'ans)) (g 'ans)
          (: m (mk 0)
             (? !(two? m) 'no
                (: w <>m
                   (go p) (? (#p = 0) (g 'ans) (: _ (w p) (go (bz2-next g))))
                   (go p))))))
)
) ; module 'bz2

; --- the face -----------------------------------------------------------------------
; `love bzip2`, `bunzip2`, `bzcat`: bzip2 1.0.8's flag spelling, messages and statuses
; (0, 1 a file or a flag, 2 a stream that will not read) over the module above.
;
;   bzip2 [-cdfkqstvz] [-1..-9] [--fast] [--best] [FILE..]
;   bunzip2 = bzip2 -d      bzcat = bzip2 -dc
;
; no file, or a bare -, is the filter. -s is taken and changes nothing.
(module 'bz2cmd
(borrow 'bz2)
(borrow 'path)
(borrow 'posix)
(: bzc-help "bzip2 -- the block-sorting compressor in love (src/love/lib/bz2.c is the codec)
usage: bzip2 [-cdfkqstvz] [-1..-9] [FILE..]
  -z  compress (the default)            -d  decompress (bunzip2)
  -c  write on stdout, keep the files   -k  keep the input file
  -f  overwrite an existing output      -t  test the files, write nothing
  -q  say nothing on a warning          -v  say what happened, on err
  -1 .. -9  the block, 100k to 900k (9)  --fast is -1, --best -9
  -s  taken, and it changes nothing
no file, or a bare -, is the filter: stdin -> stdout"
   bzc-sufs [[".bz2" ""] [".bz" ""] [".tbz2" ".tar"] [".tbz" ".tar"]]

   (bzc-say t m) (say err (peep t 'nm "bzip2" + ": " + m + "\n"), flush err)
   (bzc-moan t m) (? (peep t 'q 0) 0 (bzc-say t m))
   (bzc-suf p) (: (go l) (? (atom? l) () (ends? p <<l) <l (go >l)) (go bzc-sufs))
   (bzc-lpad w c s) (? (w <= #s) s (bzc-lpad w c (c + s)))
   (bzc-fix x m w)                     ; x at m's decimals (1000: three), right in w, printf's %w.nf
    (: v (floor (abs x * m + 0.5))
       s ((x < 0 && 0 < v ? "-" "") + show (v // m) + "." + bzc-lpad (#(show m) - 1) "0" (show (v % m)))
       (bzc-lpad w " " s))
   (bzc-why t p w) (w @ 'format (p + " is not a bzip2 file.")
                        'end (p + ": Compressed file ends unexpectedly")
                        'big (p + ": decompresses past 1 GiB, more than is held in memory")
                        (p + ": data integrity (CRC) error in data"))
   (bzc-tell t p m)                    ; -v's line: the name, padded as bzip2 pads it
    (say err ("  " + p + ": " + bzc-lpad (peep t 'w 7 - #p) " " "" + m + "\n"), flush err)
   (bzc-ratio s z)
    (? (#s = 0) "no data compressed."
       (bzc-fix (#s / #z) 1000 6 + ":1, " + bzc-fix (8 * #z / #s) 1000 6 + " bits/byte, "
        + bzc-fix (100 * (1 - #z / #s)) 100 5 + "% saved, " + show #s + " in, " + show #z + " out."))
   (bzc-put t p dst bytes st)          ; the output laid, the input's mode and time carried
    (? (two? (lstat dst) && !(peep t 'f 0)) (bzc-moan t ("Output file " + dst + " already exists."), 1)
       !(uwrite dst bytes) (bzc-moan t ("Can't create output file " + dst + "."), 1)
       (two? st && (chmod dst (st 2 & 4095), utime dst (st 1)), peep t 'k 0 ? 0 (unlink p), 0))
   (bzc-rd q) (\ _ (: c (see q) (? (c < 0) "" (: _ (unsee q c) (chug q)))))
   ; a file decompressed as it comes off the disk: the output opened before the first byte,
   ; its mode and time laid after the last, and taken away again if the stream fails partway
   (bzc-unone t p st)
    (: q (open p "r")
       (? !(hot? q) (bzc-moan t ("Can't open input file " + p + ": No such file or directory."), 1)
          (: k (tablet 0)
             x (bzc-suf p)
             dst (? x (snip p 0 (#p - #<x) + <>x) (p + ".out"))
             (no m) (: _ (bzc-moan t m) ())
             (mk _) (? (peep t 't 0) [1 (\ s 0)]
                       (peep t 'c 0) [1 (\ s (say out s))]
                       (: _ (!x && bzc-moan t ("Can't guess original name for " + p + " -- using " + dst))
                          (? (two? (lstat dst) && !(peep t 'f 0)) (no ("Output file " + dst + " already exists."))
                             (: o (open dst "w")
                                (? !(hot? o) (no ("Can't create output file " + dst + "."))
                                   (: _ (pin k 'o o) [1 (\ s (say o s))]))))))
             u (bz2-unf (bzc-rd q) mk)
             _ (close q)
             o (peep k 'o ())   laid (hot? o)
             _ (laid && close o)
             (? (u = 'no) 1
                (atom? u) (: _ (laid && unlink dst) (bzc-say t (bzc-why t p u), 2))
                (peep t 't 0) (: _ (peep t 'v 0 && bzc-tell t p "ok") 0)
                !laid 0
                (: _ (two? st && (chmod dst (st 2 & 4095), utime dst (st 1)))
                   _ (peep t 'k 0 || unlink p)
                   _ (peep t 'v 0 && bzc-tell t p "done")
                   0)))))
   (bzc-one t p)
    (: st (stat p)
       (? (two? st && (st 2 & 61440) = 16384) (bzc-moan t ("Input file " + p + " is a directory."), 1)
          (peep t 'd 0) (bzc-unone t p st)
          (: r (uread p)
             (? !r (bzc-moan t ("Can't open input file " + p + ": No such file or directory."), 1)
                (: x (bzc-suf p)
                   (? (x && !(peep t 'c 0))
                      (bzc-moan t ("Input file " + p + " already has " + <x + " suffix."), 1)
                      (: z (bz2-pack <>r (peep t 'lvl 9))
                         _ (peep t 'v 0 && bzc-tell t p (bzc-ratio <>r z))
                         (? (peep t 'c 0) (say out z, 0) (bzc-put t p (p + ".bz2") z st)))))))))
   (bzc-filter t)
    (? (peep t 'd 0)
       (: u (bz2-unf (bzc-rd in) (\ _ [1 (? (peep t 't 0) (\ s 0) (\ s (say out s)))]))
          (? (atom? u) (bzc-say t (bzc-why t "(stdin)" u), 2) 0))
       (two? (tty out) && !(peep t 'f 0))
        (bzc-say t "I won't write compressed data to a terminal.", 1)
       (say out (bz2-pack (slurp in + "") (peep t 'lvl 9)), 0))

   ; the cli walker in gnu order. -d, -z and -t decide the direction by the last one said,
   ; and a level digit (or --fast, --best) likewise
   bzc-longs {"stdout" 99 "decompress" 100 "compress" 122 "keep" 107 "force" 102 "test" 116
              "quiet" 113 "verbose" 118 "fast" 49 "best" 57 "help" 104 "version" 86
              "license" 76 "small" 115 "repetitive-fast" 115 "repetitive-best" 115}
   (bzc-opts as t)                     ; -> (1 files) | () for a bad flag
    (: u (tablet 0)
       r (cite 'cli 'uoptp as u () () bzc-longs)
       bad (cite 'cli 'uoptun u "cdzkftqvhVLs123456789")
       (? (r 3) (bzc-say t ("Bad flag `" + r 3 + "'"), ())
          bad (: w <(filter (w \ 1 < #w && w 0 = 45 && w 1 != 45 && elem bad w) as)
                 (bzc-say t ("Bad flag `" + w + "'"), ()))
          (: _ (each (chars "ckfqvhVs") (c \ peep u c 0 && pin t (intern (string c)) 1))
             _ (? (peep u 76 0) (pin t 'V 1))
             _ (? (peep u 116 0) (pin t 't 1))
             dir (cite 'cli 'uoptlast as [100 122 116] () bzc-longs)
             _ (? dir (pin t 'd (dir = 122 ? 0 1)))
             lv (cite 'cli 'uoptlast as "123456789" () bzc-longs)
             _ (? lv (pin t 'lvl (lv - 48)))
             [1 (r 2)])))

   (bzc-run as t)
    (: o (bzc-opts as t)
       r (? !o 1
            (peep t 'h 0) (say out (bzc-help + "\n"), 0)
            (peep t 'V 0) (say out ("bzip2 (love " + love-version + ")\n"), 0)
            (: fs (filter (p \ p != "-") <>o)
               _ (pin t 'w (foldl (\ a p (max a #p)) 7 fs))
               (? (atom? fs) (bzc-filter t)
                  (foldl (\ acc p (max acc (bzc-one t p))) 0 fs))))
       (flush out, flush err, r))
   (bzip2-main as) (bzc-run as (tablet 0))
   (bunzip2-main as) (: t (tablet 0) (pin t 'd 1, pin t 'nm "bunzip2", bzc-run as t))
   (bzcat-main as) (: t (tablet 0) (pin t 'd 1, pin t 'c 1, pin t 'nm "bzcat", bzc-run as t))

   _ (pins (cite 'verbs 'tab)
      'bzip2 bzip2-main 'bunzip2 bunzip2-main 'bzcat bzcat-main))

) ; module 'bz2cmd
