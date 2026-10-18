; src/apps/zstd.l -- the zstandard frame (rfc 8878) over src/love/compress/zstd.c's blocks.
; `(borrow 'zstd)`, then:
;   (zstd-pack s level) -> the .zst bytes of s, level 1..19: one frame, its size and checksum
;   (zstd-unpack s)     -> (1 bytes) | a word saying why not ('format 'corrupt 'end 'check 'big
;                          'dict): every frame in s, the skippable ones passed over, each
;                          frame's size and checksum held where it says them
;   (zstd-pull rd)      -> g, a reader over the frames as they come: (zstd-next g) the next
;                          block's bytes, "" once done, and g's 'ans then (1 n) | the word
;   (zstd-unf rd mk)    -> (1 n) | the word | 'no: off rd, out through the writer mk answers
;                          (1 w), or () for 'no
; the codec is C (zstde, zstd-d, and zstd-new zstd-block zstd-sum); the frame read is here, where
; its fields are plain to read.
(module 'zstd
(borrow 'bytes)
(borrow 'tar)

(: (zstd-pack s level) (zstde s level)
   zstd-magic 4247762216               ; 28 b5 2f fd, little-endian
   zstd-wmax 134217728                 ; the window past which a frame is refused, zstd's own
   (zs-fin g a) (pins g 'mode 'end 'ans a, "")
   (zs-skip src n)                     ; n bytes passed over -> 1 | 0 where the input ends first
    (n <= 0 ? 1 (tar-take src (min n 65536) @ b (#b = 0 ? 0 (zs-skip src (n - #b)))))
   ; a frame header past its magic -> [window fcs check] | a word. d the descriptor byte: the
   ; content size's width, single segment, reserved, checksum, the dictionary id's width
   (zs-head d r)
    (: ss (d >> 5 & 1)   dn ([0 1 2 4] (d & 3))   fz ([ss 2 4 8] (d >> 6))   fo (1 - ss + dn)
       fcs (fz = 0 ? () (rdle r fo fz + (fz = 2 ? 256 0)))
       wd (ss = 1 ? 0 (r 0))
       win (ss = 1 ? fcs (: b (1 << 10 + (wd >> 3)) (b + b // 8 * (wd & 7))))
       (? (0 < d & 8) 'corrupt
          (0 < dn && rdle r (1 - ss) dn != 0) 'dict
          (zstd-wmax < win && !(charm? fcs && fcs <= zstd-wmax)) 'big
          [(charm? fcs ? (min win fcs) win) fcs (d >> 2 & 1)]))

   (zstd-pull rd) {'src (tar-src rd) 'mode 'frame 'n 0 'any 0}
   (zstd-next g)
    (: m (peep g 'mode 'end)   src (g 'src)
       (? (m = 'end) ""
          (m = 'frame)
           (: h (tar-peek src 4)   v (#h = 4 ? (rdle h 0 4) 0)
              (? (#h = 0) (zs-fin g (g 'any = 1 ? [1 (g 'n)] 'format))
                 (#h < 4) (zs-fin g (snip "\x28\xb5\x2f\xfd" 0 #h = h ? 'end 'format))
                 (v & 4294967280 = 407710288)    ; a skippable frame: its length, and that passed over
                  (tar-take src 8 @ k
                     (#k < 8 || zs-skip src (rdle k 4 4) = 0 ? (zs-fin g 'end)
                        (pin g 'any 1, zstd-next g)))
                 (v != zstd-magic) (zs-fin g 'format)
                 (: fh (tar-take src 5)   d (#fh = 5 ? (fh 4) 0)
                    hn ((1 - (d >> 5 & 1)) + [0 1 2 4] (d & 3) + [(d >> 5 & 1) 2 4 8] (d >> 6))
                    r (#fh = 5 ? (tar-take src hn) "")
                    (? (#fh < 5 || #r < hn) (zs-fin g 'end)
                       (zs-head d r @ fr
                          (atom? fr ? (zs-fin g fr)
                             (zstd-new (fr 0) @ st
                                (st = () ? (zs-fin g 'big)
                                   (pins g 'st st 'fcs (fr 1) 'ck (fr 2) 'fn 0 'mode 'block,
                                    zstd-next g)))))))))
          (m = 'block)                    ; a block whole, its header first: raw, one byte run, coded
           (: h (tar-take src 3)   v (#h = 3 ? (rdle h 0 3) 0)   k (v >> 1 & 3 = 1 ? 1 (v >> 3))
              b (#h = 3 ? (tar-take src k) "")
              (? (#h < 3 || #b < k) (zs-fin g 'end)
                 (zstd-block (g 'st) (h + b) @ u
                    (!(string? u) ? (zs-fin g 'corrupt)
                       (pins g 'n (g 'n + #u) 'fn (g 'fn + #u) 'mode (v & 1 ? 'sum 'block),
                        (#u = 0 ? (zstd-next g) u))))))
          (: ck (g 'ck)   c (ck = 1 ? (tar-take src 4) "")   fcs (g 'fcs)   ; 'sum: the frame's end
             (? (ck = 1 && #c < 4) (zs-fin g 'end)
                (charm? fcs && fcs != g 'fn) (zs-fin g 'corrupt)
                (ck = 1 && c != zstd-sum (g 'st)) (zs-fin g 'check)
                (pins g 'st () 'any 1 'mode 'frame, zstd-next g)))))
   (zs-once s) ({0 s} @ t (_ \ (peep t 0 "" @ p (pin t 0 "", p))))
   ; one frame that says its size decodes at once in C; anything else, or a fault, is walked
   (zstd-unpack s) (zstd-d s @ u (string? u ? [1 u] (zs-walk s)))
   (zs-walk s)
    (: g (zstd-pull (zs-once s))
       (go acc) (zstd-next g @ p
                  (#p = 0 ? (atom? (g 'ans) ? (g 'ans) [1 (two? acc ? (cats (rev acc)) "")])
                     (go (p . acc))))
       (go ()))
   ; mk is asked for the writer before the first byte out; a stream that fails before any
   ; is said without it
   (zstd-unf rd mk)
    (: g (zstd-pull rd)   p (zstd-next g)
       (#p = 0 && atom? (g 'ans) ? (g 'ans)
          (mk 0 @ m
             (!(two? m) ? 'no
                (: w <>m
                   (go p) (#p @ 0 (g 'ans) (w p, go (zstd-next g)))
                   (go p))))))
)
) ; module 'zstd

; --- the face -----------------------------------------------------------------------
; `love zstd`, `unzstd`, `zstdcat`: zstd 1.5's flag spelling, messages and statuses (0, 1 for
; any failure) over the module above. unlike gzip, the input is kept unless --rm.
;
;   zstd [-dcfkqtvz] [-#] [--rm] [-o FILE] [FILE..]
;   unzstd = zstd -d      zstdcat = zstd -dcf
;
; no file, or a bare -, is the filter. -T, --ultra, --[no-]progress, --[no-]check are taken.
(module 'zstdcmd
(borrow 'zstd)
(borrow 'posix)
(: zsc-help "zstd -- the zstandard compressor
usage: zstd [-cdfkqtvz] [-#] [--rm] [-o FILE] [FILE..]
  -z  compress (the default)            -d  decompress (unzstd)
  -c  write on stdout                   -o FILE  write FILE, one input
  -k  keep the input (the default)      --rm  remove the input once done
  -f  overwrite an existing output      -t  test the files, write nothing
  -q  say less                          -v  say more, on err
  -#  the level, 1 to 19 (3)            -T#, --ultra, --[no-]check: accepted, ignored
no file, or a bare -, is the filter: stdin -> stdout"
   zsc-sufs [[".zst" ""] [".tzst" ".tar"]]

   (zsc-say t m) (say err (peep t 'nm "zstd" + ": " + m + "\n"), flush err)
   (zsc-moan t m) (peep t 'q 0 ? 0 (zsc-say t m))
   (zsc-suf p) (: (go l) (? (atom? l) () (ends? p <<l) <l (go >l)) (go zsc-sufs))
   (zsc-why w) (w @ 'format "unsupported format"
                    'end "Read error (39) : premature end"
                    'check "Decoding error (36) : Restored data doesn't match checksum"
                    'big "Frame requires too much memory for decoding"
                    'dict "Dictionary mismatch"
                    "Decoding error (36) : Corrupted block detected")
   (zsc-rd q) (_ \ (see q @ c (c < 0 ? "" (unsee q c, chug q))))
   (zsc-dst t p)                       ; -> the output's name | () for a file it cannot name
    (? (peep t 'o ()) (t 'o)
       (peep t 'd 0) (zsc-suf p @ x (x ? (snip p 0 (#p - #<x) + <>x) ()))
       (p + ".zst"))
   (zsc-done t p st dst)               ; the input's mode and time carried, the input gone on --rm
    (two? st && (chmod dst (st 2 & 4095), utime dst (st 1)),
     peep t 'rm 0 && unlink p, 0)
   ; a file decompressed as it comes off the disk: the output opened before the first byte,
   ; its mode and time laid after the last, and taken away again if the stream fails partway
   (zsc-unone t p st)
    (open p "r" @ q
       (!(hot? q) ? (zsc-say t ("can't stat " + p + " : No such file or directory -- ignored"), 1)
          (: k {}
             to (peep t 'c 0 || peep t 't 0)
             dst (to ? () (zsc-dst t p))
             (no m) (zsc-say t m, ())
             (mk _) (? (peep t 't 0) [1 (s \ 0)]
                       (peep t 'c 0) [1 (s \ say out s)]
                       (two? (lstat dst) && !(peep t 'f 0)) (no (dst + " already exists; not overwritten"))
                       (open dst "w" @ o
                          (!(hot? o) ? (no ("can't open " + dst + " for writing"))
                             (pin k 'o o, [1 (s \ say o s)]))))
             u (? (to || dst) (zstd-unf (zsc-rd q) mk) 'name)
             _ (close q)
             o (peep k 'o ())   laid (hot? o)
             (laid && close o,
              (? (u = 'name) (zsc-say t (p + ": unknown suffix (.zst/.tzst expected). Can't derive the output file name. Specify it with -o dstFileName. Ignoring."), 1)
                 (u = 'no) 1
                 (atom? u) (laid && unlink dst, zsc-say t (p + " : " + zsc-why u), 1)
                 (peep t 'v 0) (zsc-say t (p + " : " + show (u 1) + " bytes"), 0)
                 !laid 0
                 (zsc-done t p st dst))))))
   (zsc-one t p)
    (stat p @ st
       (? (two? st && st 2 & 61440 = 16384) (zsc-moan t (p + " is a directory -- ignored"), 1)
          (peep t 'd 0) (zsc-unone t p st)
          (uread p @ r
             (!r ? (zsc-say t ("can't stat " + p + " : No such file or directory -- ignored"), 1)
                (: dst (zsc-dst t p)
                   (? (zsc-suf p && !(peep t 'c 0) && !(peep t 'o ()))
                       (zsc-moan t (p + " already has .zst suffix -- ignored"), 1)
                      (zstd-pack <>r (peep t 'lvl 3) @ z
                         (peep t 'v 0 && zsc-say t (p + " : " + show (#<>r = 0 ? 0 (100 * #z // #<>r)) + "%   ("
                                                     + show #<>r + " B => " + show #z + " B, "
                                                     + (peep t 'c 0 ? "/*stdout*\\" dst) + ")"),
                          (? (peep t 'c 0) (say out z, 0)
                             (two? (lstat dst) && !(peep t 'f 0))
                              (zsc-say t (dst + " already exists; not overwritten"), 1)
                             !(uwrite dst z) (zsc-say t ("can't open " + dst + " for writing"), 1)
                             (zsc-done t p st dst))))))))))
   (zsc-filter t)
    (? (peep t 'd 0)
       (zstd-unf (zsc-rd in) (_ \ [1 (peep t 't 0 ? (s \ 0) (say out))]) @ u
          (atom? u ? (zsc-say t ("/*stdin*\\ : " + zsc-why u), 1) 0))
       (two? (tty out) && !(peep t 'f 0)) (zsc-say t "stdout is a console, aborting", 1)
       (say out (zstd-pack (slurp in + "") (peep t 'lvl 3)), 0))

   ; the cli walker in gnu order. -d, -z and -t decide the direction by the last one said;
   ; a level is a word of digits, -19, or --fast, and the last one stands
   zsc-longs {"stdout" 99 "decompress" 100 "uncompress" 100 "compress" 122 "keep" 107 "force" 102
              "test" 116 "quiet" 113 "verbose" 118 "help" 104 "version" 86 "rm" 82 "ultra" 85
              "threads" 84 "progress" 80 "no-progress" 80 "check" 67 "no-check" 78 "sparse" 83
              "no-sparse" 83 "output" 111 "single-thread" 85}
   (zsc-lvl? w) (: (go i) (? (#w <= i) 1 (w i < 48 || 57 < w i) 0 (go (i + 1))) (1 < #w && w 0 = 45 && go 1))
   (zsc-fast? w) (w = "--fast" || 7 <= #w && snip w 0 7 = "--fast=")
   (zsc-opts as t)                     ; -> (1 files) | () for a bad flag
    (: (cut a) (? (atom? a) [() ()] (<a = "--") [() a] (cut >a @ c [(<a . <c) (c 1)]))
       c (cut as)
       _ (each <c (w \ (? (zsc-lvl? w) (pin t 'lvl (max 1 (min 19 (read (snip w 1 #w)))))
                          (zsc-fast? w) (pin t 'lvl 1))))
       pre (filter (w \ !(zsc-lvl? w || zsc-fast? w)) <c + c 1)
       u {}
       r (uoptp pre u [111 84] () zsc-longs)
       bad (uoptun u [99 100 122 107 102 116 113 118 104 86 82 85 84 80 67 78 83 111])
       (? (!(two? r) || r 3) (zsc-say t ("incorrect parameter: " + (two? r && r 3 || "-o")), ())
          bad (zsc-say t ("bad usage: unknown option " + (charm? bad ? "-" + string bad (show bad))), ())
          (: _ (each [99 102 113 118 104 86] (c \ peep u c 0 && pin t (intern (string c)) 1))
             _ (peep u 82 0 && pin t 'rm 1)
             _ (peep u 111 () @ o (two? o && pin t 'o <>o))
             dir (uoptlast pre [100 122 116] [111 84] zsc-longs)
             _ (dir ? (pin t 'd (dir @ 122 0 1)))
             _ (dir = 116 && pin t 't 1)
             [1 (r 2)])))

   (zsc-run as t)
    (: o (zsc-opts as t)
       r (? !o 1
            (peep t 'h 0) (say out (zsc-help + "\n"), 0)
            (peep t 'V 0) (say out (uvers "zstd" + "\n"), 0)
            (filter (!= "-") <>o @ fs
               (? (peep t 'o () && 1 < #fs) (zsc-say t "-o can only be used with a single input", 1)
                  (atom? fs) (zsc-filter t)
                  (foldl (acc \ p \ max acc (zsc-one t p)) 0 fs))))
       (flush out, flush err, r))
   (zstd-main as) (zsc-run as {})
   (unzstd-main as) (zsc-run as {'d 1 'nm "unzstd"})
   (zstdcat-main as) (zsc-run as {'d 1 'c 1 'f 1 'nm "zstdcat"})

   _ (pins (cite 'verbs 'tab)
      'zstd zstd-main 'unzstd unzstd-main 'zstdcat zstdcat-main))

) ; module 'zstdcmd
