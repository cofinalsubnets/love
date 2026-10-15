; src/apps/gz.l -- gzip in love: the RFC 1952 container, the RFC 1951 deflate inside, crc32.
; a decode answers (1 _) on success: an empty member is legitimate, so test with two?.
; the coder is src/love/compress/gz.c's deflate nif; gz-inflate is a door onto its inflate,
; falling back to gz-puff, the love decoder and the C inflate's oracle.
; a cask is mutable bytes; a tray's pin answers a copy, so trays hold constant tables only.
; the wrap registers module 'gz in the dist cat too, so the bake compiles it once.
(module 'gz
(borrow 'bytes)
(borrow 'hashes)
(:
   ; --- crc32 (IEEE 802.3: reflected, polynomial 0xedb88320) -----------------
   ; table built once at load; the final xor is the starting 0xffffffff
   (gz-crcrow n) (foldl (\ c k (c & 1 ? (c >> 1 ^ 3988292384) (c >> 1))) n ^8)
   gz-crctab (star-tray '(256) (map gz-crcrow (jot 256)))
   (gz-crcwalk s) (foldl (\ c i (peep gz-crctab ((c ^ s i) & 255) 0 ^ c >> 8)) 4294967295 ^#s ^ 4294967295)

   ; hash.c's nif, else the walk above. `charm?`, not `?`: the crc of "" is 0
   (gz-crc32 s)
    (crc32 s @ r (charm? r ? r (gz-crcwalk s)))

   ; --- the length and distance ladders (RFC 1951 3.2.5) ---------------------
   gz-lbase (star-tray '(29) '(3 4 5 6 7 8 9 10 11 13 15 17 19 23 27 31 35 43 51 59
                               67 83 99 115 131 163 195 227 258))
   gz-lext  (star-tray '(29) '(0 0 0 0 0 0 0 0 1 1 1 1 2 2 2 2 3 3 3 3 4 4 4 4 5 5 5 5 0))
   gz-dbase (star-tray '(30) '(1 2 3 4 5 7 9 13 17 25 33 49 65 97 129 193 257 385 513 769
                               1025 1537 2049 3073 4097 6145 8193 12289 16385 24577))
   gz-dext  (star-tray '(30) '(0 0 0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 10 10 11 11 12 12 13 13))

   ; the fixed code (RFC 1951 3.2.6) is canonical over four runs of length: the decoder
   ; reads its tables off these two rows.
   gz-fixlenl (star-tray '(288) (map (i \ (? (i < 144) 8 (i < 256) 9 (i < 280) 7 8))
                                     ^288))
   gz-fixlend (star-tray '(30) (map (i \ 5) ^30))

   ; the code-length code's own lengths come in the format's permutation, the rarely-used
   ; ones at the tail where they can be trimmed off
   gz-clord (star-tray '(19) '(16 17 18 0 8 7 9 6 10 5 11 4 12 3 13 2 14 1 15))
   ; the coder is src/love/compress/gz.c's; test/host/gzdeflate.l keeps the love coder it is
   ; held to. the harder one is the image lane's, and any deflate reads it
   (gz-deflate s) (deflate s)
   (gz-deflate-best s)
    (deflate-best s @ r (string? r ? r (gz-deflate s)))

   ; --- the growing byte buffer ---------------------------------------------
   ; a match reads back what inflate wrote, so not a jug: a doubling cask, copied exact at the end
   (gz-buf n) ({} @ b (pin b 0 (cask (n < 64 ? 64 n)), pin b 1 0, b))
   (gz-room b k)
    (: c (peep b 0 0) cap #c len (peep b 1 0)
       (len + k <= cap ? 0
          (: big (: (go m) (len + k <= m ? m (go (m * 2))) (go cap))
             c2 (cask big)
             ((len ? (pour c2 0 (string c) 0 len) 0),
              pin b 0 c2, 0))))
   ; the room check is inline: this runs once per output byte
   (gz-push b v)
    (: c (peep b 0 0) len (peep b 1 0)
       (len < #c ? (pin c len v, pin b 1 (len + 1), 0)
          (: _ (gz-room b 1) c2 (peep b 0 0)
             (pin c2 len v, pin b 1 (len + 1), 0))))
   (gz-take b)
    (: c (peep b 0 0) len (peep b 1 0)
       (len ? (cask len @ c2 (pour c2 0 (string c) 0 len, string c2)) ""))
   ; byte by byte: a run may overlap its own source (dist 1, len 100). room is taken first,
   ; so `c` stays the cask. answers 1 at the clean end, never 0: the caller asks `(! r)`
   (gz-copy b dist len)
    (: _ (gz-room b len)
       c (peep b 0 0)
       (go k p) (? (len <= k) (pin b 1 p, 1)
                   (p < dist) (pin b 1 p, ())         ; a reach before the start
                   (pin c p (peep c (p - dist) 0), go (k + 1) (p + 1)))
       (go 0 (peep b 1 0)))

   ; --- the bit source -------------------------------------------------------
   ; the cursor tablet: 0 the bit position, 1 torn. past the end sets torn and answers 0,
   ; no scare, so a torn stream unwinds by ordinary returns
   (gz-bit s n t)
    (peep t 0 0 @ p
       (n <= p >> 3 ? (pin t 1 1, 0)
          (pin t 0 (p + 1), s (p >> 3) >> (p & 7) & 1)))
   ; gz-bit's semantics exactly, with the position held in a local for the run
   (gz-bits s n t k)
    (: (go i a p)
        (k <= i ? (pin t 0 p, a)
           (n <= p >> 3 @ over
              ((over ? (pin t 1 1) 0),
               go (i + 1) (over ? a (a | (s (p >> 3) >> (p & 7) & 1) << i))
                  (over ? p (p + 1)))))
       (go 0 0 (peep t 0 0)))

   ; --- canonical Huffman, built from code lengths --------------------------
   ; puff's shape: codes per length and symbols in canonical order, decoded a bit at a time
   (gz-huff lens nsym)
    (: cnt {}
       _ (each ^nsym (i \ (peep lens i 0 @ l (pin cnt l (peep cnt l 0 + 1)))))
       _ (pin cnt 0 0)                       ; a zero length is "no code", not a code
       ofs {}
       _ (: (go l a) (15 < l ? 0 (pin ofs l a, go (l + 1) (a + peep cnt l 0)))
            (go 1 0))
       sym {}
       (each ^nsym (i \ (peep lens i 0 @ l (l ? (peep ofs l 0 @ o (pin sym o i, pin ofs l (o + 1), 0)) 0))),
        [cnt sym]))
   ; the position is held in a local too, written back on every way out
   (gz-dec s n t h)                          ; -> (1 symbol) | ()
    (: cnt <h sym (<(>h))
       (go l code first index p)
        (15 < l ? (pin t 0 p, ())
           (: over (n <= p >> 3)
              _ (over ? (pin t 1 1) 0)
              c (over ? code (code | s (p >> 3) >> (p & 7) & 1))
              p2 (over ? p (p + 1))
              k (peep cnt l 0)
              (c - k < first ? (pin t 0 p2, [1 (peep sym (index + (c - first)) 0)])
                 (go (l + 1) (c << 1) (first + k << 1) (index + k) p2))))
       (go 1 0 0 0 (peep t 0 0)))

   gz-fixlithuff (gz-huff gz-fixlenl 288)
   gz-fixdisthuff (gz-huff gz-fixlend 30)

   ; --- the three block kinds ------------------------------------------------
   (gz-stored s n t b)
    ((peep t 0 0 + 7) // 8 @ p ; a stored block starts at a byte
       (n < p + 4 ? ()
          (: len (s p + (s (p + 1) << 8))
             nl (s (p + 2) + (s (p + 3) << 8))
             (((len ^ 65535) & 65535 = nl) & 1 ?
                (n < p + 4 + len ? ()
                   (each ^len (k \ gz-push b (s (p + 4 + k))),
                    pin t 0 ((p + 4 + len) * 8),
                    1))))))

   (gz-codes s n t b lit dst)                ; the symbol loop, fixed or dynamic
    (: (go u)
        (gz-dec s n t lit @ d
           (? !d ()
              (peep t 1 0) ()                                  ; ran off the end
              (: sy (<(>d))
                 (? (sy < 256) (gz-push b sy, go ())
                    (sy = 256) 1
                    (285 < sy) ()
                    (: lc (sy - 257)
                       l (peep gz-lbase lc 0 + gz-bits s n t (peep gz-lext lc 0))
                       dd (gz-dec s n t dst)
                       (!dd ? ()
                          (: dc (<(>dd))
                             (29 < dc ? ()
                                (: dist (peep gz-dbase dc 0 + gz-bits s n t (peep gz-dext dc 0))
                                   r (gz-copy b dist l)
                                   ((! r) ? () (go ())))))))))))
       (go ()))

   ; code lengths through a third code; 16 repeats the previous length, so the walk carries it
   (gz-dynamic s n t b)
    (: hlit (gz-bits s n t 5 + 257)
       hdist (gz-bits s n t 5 + 1)
       hclen (gz-bits s n t 4 + 4)
       cl {}
       _ (each ^hclen (i \ pin cl (peep gz-clord i 0) (gz-bits s n t 3)))
       ch (gz-huff cl 19)
       tot (hlit + hdist)
       lens {}
       (rep i r v) (each ^r (k \ pin lens (i + k) v))
       (rd i prev)
        (? (tot <= i) 1
           (peep t 1 0) ()
           (gz-dec s n t ch @ d
              (!d ? ()
                 (: sy (<(>d))
                    (sy < 16 ? (pin lens i sy, rd (i + 1) sy)
                     (sy @ 16 (3 + gz-bits s n t 2 @ r (rep i r prev, rd (i + r) prev))
                           17 (3 + gz-bits s n t 3 @ r (rep i r 0, rd (i + r) 0))
                           18 (11 + gz-bits s n t 7 @ r (rep i r 0, rd (i + r) 0))))))))
       ok (rd 0 0)
       (!ok ? ()
          ; the distance lengths follow the literal ones; gz-huff counts from 0, so copy them down
          (: dl {}
             _ (each ^hdist (k \ pin dl k (peep lens (hlit + k) 0)))
             lit (gz-huff lens hlit)
             dst (gz-huff dl hdist)
             (gz-codes s n t b lit dst))))

   (gz-block s n t b)                         ; -> (1 last?) | ()
    (: fin (gz-bit s n t)
       typ (gz-bits s n t 2)
       r (typ @ 0 (gz-stored s n t b)
                1 (gz-codes s n t b gz-fixlithuff gz-fixdisthuff)
                2 (gz-dynamic s n t b))
       (r ? [1 fin]))

   (gz-puff s hint)
    (:- (n && go ())
     n #s t {}  b (gz-buf hint)
     (go u) (gz-block s n t b @ r
               (? (!r || peep t 1 0) ()
                  <>r [1 (gz-take b)]
                  (go ()))))
   ; gz.c's nif, else gz-puff (a torn stream is read by both). `string?`, never `?`: NULs sum to 0
   (gz-inflate s hint)
    (inflate s hint @ r (? (string? r) [1 r] (r = 1) 'big (gz-puff s hint)))

   ; --- the container (RFC 1952) --------------------------------------------
   (gz-zip s nom stamp) (gz-zipw s nom stamp gz-deflate)
   (gz-zip9 s nom stamp) (gz-zipw s nom stamp gz-deflate-best)
   (gz-zipw s nom stamp def)
    (: txt (s + "")
       named (#nom ? 1 0)
       h (cask 10)
       (pins h 0 31 1 139 2 8 3 (named ? 8 0)
        4 (stamp & 255) 5 (stamp >> 8 & 255)
        6 (stamp >> 16 & 255) 7 (stamp >> 24 & 255)
        8 0 9 3,               ; xfl none, os 3 = unix
        string h + (named ? (nom + string 0) "") + def txt
        + wrle (gz-crc32 txt) 4 + wrle (#txt & 4294967295) 4))

   ; every optional field is stepped over, though we write only fname. ftext carries no bytes
   (gz-head s)                                ; -> (1 stamp name body-seat) | ()
    (: n #s
       (skip i) (? (n <= i) () (s i = 0) (i + 1) (skip (i + 1)))       ; a NUL-ended field
       (n < 18 || !(s 0 = 31 && s 1 = 139 && s 2 = 8) ? ()
          (: flg (s 3)
             i1 (flg & 4 ? (12 + rdle s 10 2) 10)                                  ; fextra
             r2 (flg & 8 ? (skip i1 @ e (e && [1 (snip s i1 (e - 1)) e])) [1 "" i1])   ; fname
             (!r2 ? ()
                (: i3 (flg & 16 ? (skip <>>r2) <>>r2)                             ; fcomment
                   (!i3 ? ()
                      (: i4 (flg & 2 ? (i3 + 2) i3)                               ; fhcrc
                         (n < i4 + 8 ? () [1 (rdle s 4 4) <>r2 i4]))))))))
   (gz-unzip s)
    (: n #s h (gz-head s)
       (!h ? ()
          (: i4 <>>>h
             isize (rdle s (n - 4) 4)
             crc (rdle s (n - 8) 4)
             ; pour's last argument is a count, not an end offset, and it clamps silently
             body (cask (n - i4 - 8) @ c (pour c 0 s i4 (n - i4 - 8), string c))
             r (gz-inflate body isize)
             out <>r
             ; a stream that inflates cleanly but fails the crc or size is corrupt
             (? (r = 'big) 'big
                r (gz-crc32 out = crc && #out = isize & 4294967295 && [1 out])))))

   ; --- the container, streamed ---------------------------------------------
   ; (gz-next g) answers the next piece inflated, "" at the end; then g's 'ans is
   ; (1 stamp name n offset) of the first header | ('trail ..) bytes past the last member |
   ; 'nogz | () torn or a crc wrong | 'big. no member is held whole; members concatenate
   (gz-pull rd) {'rd rd 'buf "" 'mode 'head 'first 1 'tot 0}
   (gz-fin g a) (pins g 'mode 'end 'ans a, "")
   (gz-more g k)                                 ; buf grown to k bytes, or as far as the input goes
    (peep g 'buf "" @ b
       (k <= #b ? b (peep g 'rd () 0 @ p (#p = 0 ? b (pin g 'buf (b + p), gz-more g k)))))
   (gz-headin g)                                 ; -> the header whole off buf | () where none can be
    (: b (peep g 'buf "")   h (gz-head b)
       (? h h
          (3 <= #b && !(b 0 = 31 && b 1 = 139 && b 2 = 8)) ()
          (peep g 'rd () 0 @ p (#p = 0 ? () (pin g 'buf (b + p), gz-headin g)))))
   (gz-next g)
    (peep g 'mode 'end @
     'end ""
     'head
     (: h (gz-headin g)   b (peep g 'buf "")   hd (peep g 'hd ())
        (!h ? (? (peep g 'first 0) (gz-fin g 'nogz)
                 (#(gz-more g 1) = 0) (gz-fin g [1 (hd 0) (hd 1) (peep g 'tot 0) (hd 2)])
                 (gz-fin g ['trail (hd 0) (hd 1) (peep g 'tot 0) (hd 2)]))
           ((peep g 'first 0 ? (pins g 'hd [(h 1) (h 2) (h 3)] 'first 0)),
            pins g 'st (inflate-new 0) 'crc 0 'n 0 'buf (snip b (h 3) #b) 'mode 'body,
            gz-next g)))
     'body
     (: b (peep g 'buf "")
        r (inflate-feed (peep g 'st ()) (#b = 0 ? (peep g 'rd () 0) b))
        (pin g 'buf "",
         (? (two? r) (<r @ o
                        (pins g 'crc (crc32-on (peep g 'crc 0) o) 'n (peep g 'n 0 + #o) 'buf >r 'mode 'trail,
                         (#o @ 0 (gz-next g) o)))
            (string? r) (pins g 'crc (crc32-on (peep g 'crc 0) r) 'n (peep g 'n 0 + #r),
                         (#r @ 0 (gz-next g) r))
            (gz-fin g (r @ 1 'big)))))
    (: t (gz-more g 8)   n (peep g 'n 0)        ; the trailer
       (#t < 8 || !(rdle t 0 4 = peep g 'crc 0) || !(rdle t 4 4 = n & 4294967295) ? (gz-fin g ())
          (pins g 'buf (snip t 8 #t) 'tot (peep g 'tot 0 + n) 'mode 'head,
           gz-next g))))
   ; mk (stamp name) of the first header answers (1 w), w the writer, or () for 'no
   (gz-unzipf rd mk)
    (: g (gz-pull rd)   p (gz-next g)   hd (peep g 'hd ())
       (!(two? hd) ? (peep g 'ans ())
          (mk (hd 0) (hd 1) @ m
             (!(two? m) ? 'no
                (: w <>m
                   (go p) (#p = 0 ? (peep g 'ans ()) (w p, go (gz-next g)))
                   (go p)))))))

) ; module 'gz

; --- the face: `love gzip`, `gunzip`, `zcat` with GNU's flags; status 0 clean, 1 failed,
; 2 a warning. decompressing streams, and a crc failure removes the partial output;
; compressing reads whole. -l's ratio is the payload's, as GNU's is.
; a module of its own, so the borrow of 'gz lands in this layer, not the dist cat's
(module 'gzcmd
(borrow 'gz)
(borrow 'bytes)

(borrow 'path)
(borrow 'posix)
(: gzc-usage "usage: gzip [-cdfklnNqrtv19] [-S SUF] [FILE..]   (gunzip = -d, zcat = -dc)"
   gzc-big ": inflates past 1 GiB, more than is held in memory -- refused"
   gzc-help "gzip -- the RFC 1952 container in love (module 'gz is the codec)
usage: gzip [-cdfklnNqrtv19] [-S SUF] [FILE..]
  -c  write on stdout, keep the files      -d  decompress (gunzip)
  -f  overwrite an existing output         -k  keep the input file
  -l  list a member's sizes and ratio      -n  no name or time in the header
  -N  take the name AND the time back      -q  say nothing on a warning
  -r  walk the named directories           -S  the suffix (.gz unsaid)
  -t  test the members, write nothing      -v  say what happened, on err
  -9  deflate harder (--best)             -1 .. -8  taken, and they change nothing
no file, or a bare -, is the filter: stdin -> stdout"

   ; --- the small floor ------------------------------------------------------
   (gzc-moan t m) (peep t 'q 0 ? 0
                     (say err ("gzip: " + m), put err 10, flush err))
   (gzc-tell t m) (peep t 'v 0 && (say err m, put err 10, flush err))
   (gzc-pad w s) (#s < w ? (gzc-pad w (" " + s)) s)
   (gzc-dirp? q) (stat q @ st (two? st && <>>st & 61440 = 16384))
   (gzc-worse a b) (? (a = 1 || b = 1) 1 (a = 2 || b = 2) 2 0)

   ; --- a member's sizes, for -l --
   (gzc-isize s) (rdle s (#s - 4) 4)
   (gzc-pay z) (gz-head z @ h (h ? (#z - <>>>h - 8) 0))          ; the deflate bytes alone

   ; --- the ratio, GNU's `%5.1f%%` ------------------------------------------
   ; the tenth is rounded, not truncated, and a tie lands half away from zero where C
   ; rounds half to even -- a difference an exact .05 could reach and real sizes do not.
   (gzc-ratio num den)
    (den = 0 ? "  0.0%"
       (: neg (num < 0) a (neg ? -num num)
          v ((a * 1000 + den // 2) // den)
          txt (show (v // 10) + "." + show (v % 10) + "%")
          (gzc-pad 6 (neg ? ("-" + txt) txt))))

   ; --- -l, the listing ------------------------------------------------------
   gzc-lhead "         compressed        uncompressed  ratio uncompressed_name"
   (gzc-lrow fs un pay nom)
    (gzc-pad 19 (show fs) + " " + gzc-pad 19 (show un)
     + " " + gzc-ratio (un - pay) un + " " + nom)
   (gzc-list t fs)
    (: suf (peep t 'suf ".gz")
       _ (say out (gzc-lhead + "\n"))
       (one p acc)                     ; acc: (status compressed uncompressed payload)
        (uread p @ r
           (!r ? (gzc-moan t (p + ": No such file or directory"),
                  [(gzc-worse <acc 1) <>acc <>>acc <>>>acc])
              (: s <>r h (gz-head s)
                 (!h ? (gzc-moan t (p + ": not in gzip format"),
                        [(gzc-worse <acc 1) <>acc <>>acc <>>>acc])
                    (: fs2 #s un (gzc-isize s) pay (fs2 - <>>>h - 8)
                       ; the name column is the path as it was typed, stem and all --
                       ; only -N's stored name arrives without a directory to keep
                       nom (peep t 'N 0 && 0 < #<>>h ? (pbase <>>h)
                              (gzc-stem p suf @ st (st ? <>st p)))
                       (say out (gzc-lrow fs2 un pay nom + "\n"),
                        [<acc (<>acc + fs2) (<>>acc + un) (<>>>acc + pay)]))))))
       a (foldl (acc \ p \ one p acc) '(0 0 0 0) fs)
       (two? >fs && say out (gzc-lrow <>a <>>a <>>>a "(totals)" + "\n"),
        flush out,
        <a))

   ; --- the suffix rules -----------------------------------------------------
   ; .gz (or -S's) comes off; .tgz answers .tar, which is the one rename gzip does.
   (gzc-stem p suf)                    ; -> (1 stem) | ()
    (p @ (s + ^suf + "") [1 s] (s + ".tgz") [1 (s + ".tar")] ())

   (gzc-zip t s nom stamp) (peep t 'lvl 6 @ 9 (gz-zip9 s nom stamp) (gz-zip s nom stamp))

   ; --- one file, compressed -------------------------------------------------
   (gzc-zip1 t p)
    (: suf (peep t 'suf ".gz")
       r (uread p)
       (? !r (gzc-moan t (p + ": No such file or directory"), 1)
          (ends? p suf && !(peep t 'c 0))
           (gzc-moan t (p + " already has " + suf + " suffix -- unchanged"), 0)
          (: s <>r
             st (stat p)
             ms (two? st ? <>st 0)
             n? (peep t 'n 0)
             z (gzc-zip t s (n? ? "" (pbase p)) (n? ? 0 (ms // 1000)))
             (peep t 'c 0 ? (say out z, flush out, 0)
                (p + suf @ dst
                   (? (two? (lstat dst) && !(peep t 'f 0))
                      (gzc-moan t (dst + " already exists;\tnot overwritten"), 2)
                      !(uwrite dst z)
                       (gzc-moan t ("cannot write " + dst), 1)
                      (two? st && (chmod dst (<>>st & 4095), utime dst ms),
                       peep t 'k 0 ? 0 (unlink p),
                       gzc-tell t (p + ":\t" + gzc-ratio (#s - gzc-pay z) #s
                                     + (peep t 'k 0 ? " -- created " " -- replaced with ")
                                     + dst),
                       0)))))))

   ; --- one file, decompressed (and -t, the same read with no write) --
   ; the output is opened once the header names it (-N); a failure partway removes it
   (gzc-rd q) (_ \ (see q @ c (c < 0 ? "" (unsee q c, chug q))))
   (gzc-dstat t nm u)                  ; the answer of gz-unzipf, said
    (? (u = 'big) (gzc-moan t (nm + gzc-big), 1)
       (u = 'nogz) (gzc-moan t (nm + ": not in gzip format"), 1)
       (u = 'no) (peep t 'why 1)
       (two? u && <u = 'trail) (gzc-moan t (nm + ": decompression OK, trailing garbage ignored"), 2)
       (two? u) 0
       (gzc-moan t (nm + ": invalid compressed data--crc error"), 1))
   (gzc-unzip1 t p)
    (: suf (peep t 'suf ".gz")
       stem0 (gzc-stem p suf)
       ; the suffix first: no suffix is a warning, so `gunzip *` over a mixed directory walks on
       (!(peep t 'c 0) && !(peep t 't 0) && !stem0 && !(peep t 'N 0) ?
          (gzc-moan t (p + ": unknown suffix -- ignored"), 2)
       (open p "r" @ q
       (!(hot? q) ? (gzc-moan t (p + ": No such file or directory"), 1)
          (: k {}
             (no w m) (pin k 'why w, gzc-moan t m, ())
             (mk stamp nom)
              (? (peep t 't 0) [1 (s \ 0)]
                 (peep t 'c 0) [1 (say out)]
                 (peep t 'N 0 && 0 < #nom @ N?
                    (!stem0 && !N? ? (no 2 (p + ": unknown suffix -- ignored"))
                       (: dst (N? ? (phead p + pbase nom) <>stem0)
                          (two? (lstat dst) && !(peep t 'f 0) ?
                             (no 2 (dst + " already exists;\tnot overwritten"))
                             (open dst "w" @ o
                                (!(hot? o) ? (no 1 ("cannot write " + dst))
                                   (pins k 'dst dst 'o o 'N N? 'stamp stamp,
                                    [1 (s \ say o s)]))))))))
             u (gz-unzipf (gzc-rd q) mk)
             _ (close q)
             o (peep k 'o ())
             _ (? (hot? o) (close o) (peep t 'c 0) (flush out) 0)
             r (gzc-dstat t p u)
             (? (1 = r)
                ((hot? o ? (unlink (peep k 'dst ""))), r)   ; the partial output goes
                !(hot? o) r
                (: dst (peep k 'dst "")
                   st (stat p)
                   (two? st && chmod dst (<>>st & 4095),
                   ; the header's stamp only with -N, else the .gz's own mtime
                    (? (peep k 'N 0) (utime dst (peep k 'stamp 0 * 1000))
                       (two? st) (utime dst <>st)
                       0),
                    peep t 'k 0 || unlink p,
                    gzc-tell t (p + ":\t" + gzc-ratio (u 3 - (<st - u 4 - 8)) (u 3)
                                 + (peep t 'k 0 ? " -- created " " -- replaced with ")
                                 + dst),
                    r))))))))

   ; --- the walk -------------------------------------------------------------
   (gzc-one t p) (peep t 'd 0 ? (gzc-unzip1 t p) (gzc-zip1 t p))
   (gzc-walk t p)                      ; -r: a directory is its files, sorted
    (? !(gzc-dirp? p) (gzc-one t p)
       (peep t 'r 0)
        (foldl (acc \ c \ gzc-worse acc (gzc-walk t (p + "/" + c))) 0 (sort (readdir p)))
       (gzc-moan t (p + " is a directory -- ignored"), 2))

   ; --- the filter: no file named, so stdin -> stdout -------------------------
   (gzc-filter t)
    (peep t 'd 0 ?
       (gz-unzipf (gzc-rd in) (a \ b \ [1 (peep t 't 0 ? (s \ 0) (s \ say out s))]) @ u
          (flush out,
           gzc-dstat t "stdin" u))
       (slurp in @ s (say out (gzc-zip t (s + "") "" 0), flush out, 0)))

   ; --- the options ----------------------------------------------------------
   ; a digit is a level, the last one kept; only 9 (--best) changes the coder
   gzc-longs {"stdout" 99 "to-stdout" 99 "decompress" 100 "uncompress" 100 "force" 102
              "keep" 107 "list" 108 "no-name" 110 "name" 78 "quiet" 113 "recursive" 114
              "test" 116 "verbose" 118 "fast" 49 "best" 57 "help" 104 "version" 86 "suffix" 83}
   gzc-flags "cdfklnNqrtvhV"
   (gzc-opts as t)                     ; -> (1 files) | ()  -- () is a bad option
    (: u {}
       r (cite 'cli 'uoptp as u [83] () gzc-longs)
       bad (two? r ? (cite 'cli 'uoptun u (gzc-flags + "S0123456789")))
       (? !(two? r) (: w <(rev as) (gzc-moan t ((w 1 = 45 ? "--suffix" "-S") + " wants a suffix"), ()))
          (r 3) (gzc-moan t ("unknown option " + r 3), ())
          bad (gzc-moan t ("unknown option -" + string bad), ())
          (: _ (each (chars gzc-flags) (c \ peep u c 0 && pin t (intern (string c)) 1))
             lv (cite 'cli 'uoptlast as "123456789" [83] gzc-longs)
             _ (lv ? (pin t 'lvl (lv - 48)))
             v (peep u 83 ())
             ((two? v ? (pin t 'suf <>v)),
              [1 (r 2)]))))

   (gzc-run as t0)
    (: t t0
       o (gzc-opts as t)
       (? !o 1
          (peep t 'h 0) (say out (gzc-help + "\n"), flush out, 0)
          (peep t 'V 0)
           (say out (uvers "gzip" + "\n"), flush out, 0)
          (filter (p \ !(p = "-")) <>o @ fs
             ((? (peep t 'l 0) 0 (peep t 't 0) (pin t 'd 1) 0),
              (? !(two? fs) (peep t 'l 0 ? (gzc-moan t "-l wants a file", 1)
                                           (gzc-filter t))
                 (peep t 'l 0) (gzc-list t fs)
                 (foldl (acc \ p \ gzc-worse acc (gzc-walk t p)) 0 fs))))))

   (gzip-main as) (gzc-run as {})
   (gunzip-main as) ({} @ t (pin t 'd 1, gzc-run as t))
   (zcat-main as) ({} @ t (pin t 'd 1, pin t 'c 1, gzc-run as t))

   ; bound, not the body: a bodyless letrec leaks its names onto the module, which is
   ; how kore's registry cites these three (tarcmd is spelled the same way)
   _ (pins (cite 'verbs 'tab)
      'gzip   gzip-main
      'gunzip gunzip-main
      'zcat   zcat-main))

) ; module 'gzcmd
