; apps/bz2.l -- bzip2 over inle/bz2.c, which holds the whole stream: its blocks lie on bit
; boundaries, so there is no container to read here. `(borrow 'bz2)`, then:
;   (bz2-pack s level)  -> the .bz2 bytes of s, level 1..9 the block in 100k
;   (bz2-unpack s)      -> (1 bytes) | a word saying why not ('format 'corrupt 'end 'check):
;                          every stream in s, each block's crc and each stream's held
(module 'bz2
(: (bz2-pack s level) (bz2e s level)
   (bz2-unpack s) (: u (bz2d s) (? (string? u) [1 u] (u @ 1 'format 3 'end 4 'check 'corrupt)))
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
(: bzc-help "bzip2 -- the block-sorting compressor in love (inle/bz2.c is the codec)
usage: bzip2 [-cdfkqstvz] [-1..-9] [FILE..]
  -z  compress (the default)            -d  decompress (bunzip2)
  -c  write on stdout, keep the files   -k  keep the input file
  -f  overwrite an existing output      -t  test the files, write nothing
  -q  say nothing on a warning          -v  say what happened, on err
  -1 .. -9  the block, 100k to 900k (9)  --fast is -1, --best -9
  -s  taken, and it changes nothing
no file, or a bare -, is the filter: stdin -> stdout"
   bzc-sufs [[".bz2" ""] [".bz" ""] [".tbz2" ".tar"] [".tbz" ".tar"]]

   (bzc-slurp p) (: q (open p "r") (hot? q && (: s (slurp q) _ (close q) [1 (s + "")])))
   (bzc-blurt p s) (: q (open p "w") (hot? q && (: _ (say q s) _ (close q) 1)))
   (bzc-say t m) (: _ (say err (peep t 'nm "bzip2" + ": " + m + "\n")) (flush err))
   (bzc-moan t m) (? (peep t 'q 0) 0 (bzc-say t m))
   (bzc-ends? s x) (: n #s m #x (m <= n && snip s (n - m) n = x))
   (bzc-suf p) (: (go l) (? !(two? l) () (bzc-ends? p <<l) <l (go >l)) (go bzc-sufs))
   (bzc-lpad w c s) (? (w <= #s) s (bzc-lpad w c (c + s)))
   (bzc-fix x m w)                     ; x at m's decimals (1000: three), right in w, printf's %w.nf
    (: v (floor (abs x * m + 0.5))
       s ((x < 0 && 0 < v ? "-" "") + show (v // m) + "." + bzc-lpad (#(show m) - 1) "0" (show (v % m)))
       (bzc-lpad w " " s))
   (bzc-why t p w) (w @ 'format (p + " is not a bzip2 file.")
                        'end (p + ": Compressed file ends unexpectedly")
                        (p + ": data integrity (CRC) error in data"))
   (bzc-tell t p m)                    ; -v's line: the name, padded as bzip2 pads it
    (: _ (say err ("  " + p + ": " + bzc-lpad (peep t 'w 7 - #p) " " "" + m + "\n")) (flush err))
   (bzc-ratio s z)
    (? (#s = 0) "no data compressed."
       (bzc-fix (#s / #z) 1000 6 + ":1, " + bzc-fix (8 * #z / #s) 1000 6 + " bits/byte, "
        + bzc-fix (100 * (1 - #z / #s)) 100 5 + "% saved, " + show #s + " in, " + show #z + " out."))
   (bzc-put t p dst bytes st)          ; the output laid, the input's mode and time carried
    (? (two? (lstat dst) && !(peep t 'f 0)) (: _ (bzc-moan t ("Output file " + dst + " already exists.")) 1)
       !(bzc-blurt dst bytes) (: _ (bzc-moan t ("Can't create output file " + dst + ".")) 1)
       (: _ (two? st && (: _ (chmod dst (st 2 & 4095)) (utime dst (st 1))))
          _ (peep t 'k 0 ? 0 (unlink p))
          0))
   (bzc-one t p)
    (: r (bzc-slurp p)
       st (stat p)
       (? (two? st && (st 2 & 61440) = 16384) (: _ (bzc-moan t ("Input file " + p + " is a directory.")) 1)
          !r (: _ (bzc-moan t ("Can't open input file " + p + ": No such file or directory.")) 1)
          (peep t 'd 0)
           (: u (bz2-unpack <>r)
              (? !(two? u) (: _ (bzc-say t (bzc-why t p u)) 2)
                 (peep t 't 0) (: _ (peep t 'v 0 && bzc-tell t p "ok") 0)
                 (peep t 'c 0) (: _ (say out <>u) 0)
                 (: x (bzc-suf p)
                    dst (? x (snip p 0 (#p - #<x) + <>x) (p + ".out"))
                    _ (!x && bzc-moan t ("Can't guess original name for " + p + " -- using " + dst))
                    rc (bzc-put t p dst <>u st)
                    _ (rc = 0 && peep t 'v 0 && bzc-tell t p "done")
                    rc)))
          (: x (bzc-suf p)
             (? (x && !(peep t 'c 0))
                (: _ (bzc-moan t ("Input file " + p + " already has " + <x + " suffix.")) 1)
                (: z (bz2-pack <>r (peep t 'lvl 9))
                   _ (peep t 'v 0 && bzc-tell t p (bzc-ratio <>r z))
                   (? (peep t 'c 0) (: _ (say out z) 0) (bzc-put t p (p + ".bz2") z st)))))))
   (bzc-filter t)
    (? (peep t 'd 0)
       (: u (bz2-unpack (slurp in + ""))
          (? !(two? u) (: _ (bzc-say t (bzc-why t "(stdin)" u)) 2)
             (peep t 't 0) 0
             (: _ (say out <>u) 0)))
       (two? (tty out) && !(peep t 'f 0))
        (: _ (bzc-say t "I won't write compressed data to a terminal.") 1)
       (: _ (say out (bz2-pack (slurp in + "") (peep t 'lvl 9))) 0))

   ; each flag's rows: what it pins. -t tests, which is a decompress
   bzc-longs [["stdout" 'c 1] ["decompress" 'd 1] ["compress" 'd 0] ["keep" 'k 1]
              ["force" 'f 1] ["test" 't 1] ["test" 'd 1] ["quiet" 'q 1] ["verbose" 'v 1]
              ["fast" 'lvl 1] ["best" 'lvl 9] ["help" 'h 1] ["version" 'V 1] ["license" 'V 1]
              ["small" 's 1] ["repetitive-fast" 's 1] ["repetitive-best" 's 1]]
   bzc-shorts [[99 'c 1] [100 'd 1] [122 'd 0] [107 'k 1] [102 'f 1] [116 't 1] [116 'd 1]
               [113 'q 1] [118 'v 1] [104 'h 1] [86 'V 1] [76 'V 1] [115 's 1]
               [49 'lvl 1] [50 'lvl 2] [51 'lvl 3] [52 'lvl 4] [53 'lvl 5] [54 'lvl 6]
               [55 'lvl 7] [56 'lvl 8] [57 'lvl 9]]
   (bzc-flag t rows k)                 ; pins every row keyed k -> 1 | () for none
    (foldl (\ a e (? (<e = k) (: _ (pin t (e 1) (e 2)) 1) a)) () rows)
   (bzc-opts as t)                     ; -> (1 files) | () for a bad flag
    (: (shorts w k) (? (#w <= k) 1 (bzc-flag t bzc-shorts (w k)) (shorts w (k + 1)) ())
       (bad w) (: _ (bzc-say t ("Bad flag `" + w + "'")) ())
       (go a fs)
        (? !(two? a) [1 (rev fs)]
           (: w <a n #w
              (? (w = "--") [1 (rev fs + >a)]
                 (n < 2 || !(w 0 = 45)) (go >a (w . fs))
                 (w 1 = 45) (? (bzc-flag t bzc-longs (snip w 2 n)) (go >a fs) (bad w))
                 (shorts w 1) (go >a fs)
                 (bad w))))
       (go as ()))

   (bzc-run as t)
    (: o (bzc-opts as t)
       r (? !o 1
            (peep t 'h 0) (: _ (say out (bzc-help + "\n")) 0)
            (peep t 'V 0) (: _ (say out ("bzip2 (love " + love-version + ")\n")) 0)
            (: fs (filter (p \ !(p = "-")) <>o)
               _ (pin t 'w (foldl (\ a p (max a #p)) 7 fs))
               (? !(two? fs) (bzc-filter t)
                  (foldl (\ acc p (max acc (bzc-one t p))) 0 fs))))
       _ (flush out) _ (flush err)
       r)
   (bzip2-main as) (bzc-run as (tablet 0))
   (bunzip2-main as) (: t (tablet 0) _ (pin t 'd 1) _ (pin t 'nm "bunzip2") (bzc-run as t))
   (bzcat-main as) (: t (tablet 0) _ (pin t 'd 1) _ (pin t 'c 1) _ (pin t 'nm "bzcat") (bzc-run as t))

   _ (pins (cite 'verbs 'tab)
      'bzip2 bzip2-main 'bunzip2 bunzip2-main 'bzcat bzcat-main))

) ; module 'bz2cmd
