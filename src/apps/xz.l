; src/apps/xz.l -- the .xz container (and the old .lzma one, read) over src/love/lib/xz.c's LZMA2
; codec. `(borrow 'xz)`, then:
;   (xz-pack s dict check)  -> the .xz bytes of s: one block, one LZMA2 filter, the check
;                              one of 'none 'crc32 'crc64 'sha256
;   (xz-unpack s)           -> (1 bytes) | a word saying why not ('format 'corrupt 'end
;                              'filter 'check 'big): every stream in s, the padding between them
;                              skipped, each block's check and each index held to its blocks
;   (xz-pull rd)            -> g, a reader over the streams as they come: (xz-next g) the next
;                              piece, "" once done, and g's 'ans then (1 n) | the word
;   (xz-unf rd mk)          -> (1 n) | the word | 'no: .xz or .lzma off rd, out through the
;                              writer mk answers (1 w), or () for 'no
; the codec is C (lzma2e lzma2d lzma2len lzmad crc64, and lzma2-new lzma2-chunk crc64-on
; for a stream a chunk at a time); the container is here, where
; its fields are plain to read. the xz spec is tukaani's .xz file format 1.2.
(module 'xz
(borrow 'posix)
(borrow 'bytes)
(borrow 'tar)

(:
   (xz-bytes l) (foldl (a \ b \ a + string b) "" l)
   xz-magic (xz-bytes [253 55 122 88 90 0])
   (xz-vli v) (v < 128 ? (string v) (string (128 | v & 127) + xz-vli (v >> 7)))
   (xz-rvli s i)                       ; -> (value next) | () for a run off the end or past 9
    (:- (go i 0 0)
        (go j v sh) (#s <= j || 9 <= j - i ? ()
                       (: b (s j) v2 (v + ((b & 127) << sh))
                          (b < 128 ? [v2 (j + 1)] (go (j + 1) v2 (sh + 7))))))
   xz-checks {'none 0 'crc32 1 'crc64 4 'sha256 10}
   (xz-csize id) (? (id = 0) 0 (id = 1) 4 (id = 4) 8 (id = 10) 32 ())
   (xz-check id u) (? (id = 1) (wrle (crc32 u) 4) (id = 4) (crc64 u) (id = 10) (hex2b (sha256 u)) "")
   ; the dictionary as LZMA2's one props byte spells it: (2 | p&1) << (p/2 + 11)
   (xz-dsize p) ((2 | p & 1) << p // 2 + 11)
   (xz-dprop d) (:- (go 0) (go p) (40 <= p || d <= xz-dsize p ? p (go (p + 1))))

   ;; --- writing: one block holding everything, both sizes in its header ---
   (xz-pack s dict check)
    (: cid (peep xz-checks check 4)
       flags (xz-bytes [0 cid])
       head (xz-magic + flags + wrle (crc32 flags) 4)
       p (xz-dprop dict)
       body (#s = 0 ? "" (lzma2e s (xz-dsize p)))
       ; the block header: its size byte, flags (one filter, both sizes), the sizes, the
       ; LZMA2 filter with its props byte, padding to four, and its own crc32
       bh0 (string 192 + xz-vli #body + xz-vli #s + xz-bytes [33 1 p])
       bh1 (string ((#bh0 + 1 + padk (#bh0 + 1) 4 + 4) // 4 - 1) + bh0)
       bh2 (bh1 + zbytes (padk #bh1 4))
       bh (bh2 + wrle (crc32 bh2) 4)
       ck (xz-check cid s)
       block (#s = 0 ? "" (bh + body + zbytes (padk #body 4) + ck))
       ; the index: one record (unpadded size, uncompressed size), or none for no block
       ix0 (string 0 + (#s = 0 ? (xz-vli 0) (xz-vli 1 + xz-vli (#bh + #body + #ck) + xz-vli #s)))
       ix1 (ix0 + zbytes (padk #ix0 4))
       ix (ix1 + wrle (crc32 ix1) 4)
       ft0 (wrle (#ix // 4 - 1) 4 + flags)
       (head + block + ix + wrle (crc32 ft0) 4 + ft0 + "YZ"))

   ;; --- reading ---
   (xz-bhead hd)                       ; a block header, its crc held -> (csize usize props) | a word
    (: fl (hd 1)
       nf ((fl & 3) + 1)
       r1 (0 < fl & 64 ? (xz-rvli hd 2) [() 2])
       r2 (r1 && 0 < fl & 128 ? (xz-rvli hd <>r1) (r1 && [() <>r1]))
       (? (!r2 || 0 < fl & 60) 'corrupt
          (nf != 1) 'filter
          (: fi (xz-rvli hd <>r2)
             pz (fi && xz-rvli hd <>fi)
             (!pz || <fi != 33 || <pz != 1 || 40 < hd <>pz ? 'filter [<r1 <r2 (hd <>pz)]))))
   (xz-block s i cid)                  ; a block at i -> (bytes next unpadded) | a word
    ((s i + 1) * 4 @ hs
       (? (#s < i + hs) 'end
          !(rdle s (i + hs - 4) 4 = crc32 (snip s i (i + hs - 4))) 'corrupt
          (xz-bhead (snip s i (i + hs)) @ bh
             (atom? bh ? bh
                (: d0 (i + hs)
                   cl (charm? (bh 0) ? (bh 0) (lzma2len (snip s d0 #s) @ n (charm? n ? n -1)))
                   u (0 <= cl && d0 + cl <= #s ? (lzma2d (snip s d0 (d0 + cl))) ())
                   cz (xz-csize cid)
                   e (d0 + cl + padk cl 4)
                   (? (cl < 0 || #s < d0 + cl) 'end
                      (u = 1) 'big
                      (!(string? u) || charm? (bh 1) && #u != bh 1) 'corrupt
                      (#s < e + cz) 'end
                      (0 < cz && snip s e (e + cz) != xz-check cid u ? 'check
                         [u (e + cz) (hs + cl + cz) #u])))))))
   (xz-stream s i)                     ; a stream at i -> (bytes next) | a word
    (? (#s < i + 12) 'end
          !(snip s i (i + 6) = xz-magic) 'format
          (snip s (i + 6) (i + 8) @ fl
             (? !(rdle s (i + 8) 4 = crc32 fl) 'corrupt
                (0 < fl 0 || 15 < fl 1) 'corrupt
                !(charm? (xz-csize (fl 1))) 'check
                (: cid (fl 1)
                   (blocks j acc recs)
                    (? (#s <= j) 'end
                       (s j = 0) [acc j (rev recs)]
                       (xz-block s j cid @ b
                          (atom? b ? b
                             (blocks <>b (acc + <b) ([<>>b (b 3)] . recs)))))
                   r (blocks (i + 12) "" ())
                   (atom? r ? r
                      (: ix <>r recs <>>r
                         n (xz-rvli s (ix + 1))
                         (rec k j) (k < 1 ? j
                                      (: a (xz-rvli s j) b (a && xz-rvli s <>a)
                                         (b ? (rec (k - 1) <>b) ())))
                         e (n && rec <n <>n)
                         (!e || <n != #recs ? 'corrupt
                            (e + padk (e - ix) 4 @ e2
                               (? (#s < e2 + 16) 'end
                                  !(rdle s e2 4 = crc32 (snip s ix e2)) 'corrupt
                                  ; each record, as the blocks read it
                                  !(:- (chk <n <>n)
                                       (chk k j) (k < 1 ? 1
                                                    (: a (xz-rvli s j) b (xz-rvli s <>a) m (recs (<n - k))
                                                       (<a = <m && <b = <>m ? (chk (k - 1) <>b) ()))))
                                   'corrupt
                                  (e2 + 4 @ f
                                     (rdle s f 4 != crc32 (snip s (f + 4) (f + 10))
                                      || rdle s (f + 4) 4 != (e2 + 4 - ix) // 4 - 1
                                      || snip s (f + 8) (f + 10) != fl
                                      || snip s (f + 10) (f + 12) != "YZ"
                                      ? 'corrupt
                                        [<r (f + 12)])))))))))))
   (xz-unpack s)
    (:- (go 0 "")
        (go i acc)
        (xz-stream s i @ r
           (atom? r ? r
              (: (pad j) (j + 4 <= #s && snip s j (j + 4) = zbytes 4 ? (pad (j + 4)) j)
                 j (pad <>r)
                 (? (#s <= j) [1 (acc + <r)]
                    (#s < j + 4) 'corrupt
                    (go j (acc + <r)))))))
   ; the old container: a props byte, the dictionary, the size (all ones for unsaid,
   ; then the stream's end mark says where it stops), and one LZMA1 stream
   ; liblzma's sniff: props under 225, a dictionary of 2^n or 2^n + 2^(n-1) (or all ones),
   ; and a size of at most 2^38 or unsaid
   (xz-lzma? s)
    (: d (13 <= #s ? (rdle s 1 4) 0) us (13 <= #s ? (rdle s 5 8) 0)
       (up v) (: a (v - 1) b (a | a >> 2) c (b | b >> 3) e (c | c >> 4) f (e | e >> 8)
                 ((f | f >> 16) + 1))
       (13 <= #s && s 0 < 225 && (d = 4294967295 || up d = d)
        && (us <= 274877906944 || us = 18446744073709551615)))
   (xz-unlzma s)
    (: us (rdle s 5 8)
       u (lzmad (snip s 13 #s) (s 0) (rdle s 1 4) (us = 18446744073709551615 ? -1 us))
       (? (string? u) [1 u] (u = 1) 'big 'corrupt))

   ;; --- reading as it comes ---
   ; xz-unpack's walk over a source (src/apps/tar.l's tar-src) instead of a string: a block's
   ; LZMA2 is decoded a chunk at a time into a window its dictionary wide (its size where the
   ; header says it, if less), the check carried on as the bytes go by, and each index held
   ; to the blocks read. the words are xz-unpack's
   (xz-pull rd) {'src (tar-src rd) 'mode 'stream 'n 0}
   (xz-fin g a) (pins g 'mode 'end 'ans a, "")
   (xz-ck0 cid) (? (cid = 1) 0 (cid = 4) (crc64 "") (cid = 10) (cask 105 @ c (sha256-init c, c)) ())
   (xz-ckon cid c u) (? (cid = 1) (crc32-on c u) (cid = 4) (crc64-on c u) (cid = 10) (sha256-feed c u, c) c)
   (xz-ckend cid c) (? (cid = 1) (wrle c 4) (cid = 4) c (cid = 10) (hex2b (sha256-done c)) "")
   (xz-tvli g)                         ; an index vli off the source, its bytes kept for the crc -> v | ()
    (: (go v sh k)
        (9 <= k ? ()
           (tar-take (g 'src) 1 @ b
              (#b < 1 ? ()
                 (: _ (pin g 'ib (g 'ib + b))
                    v2 (v + ((b 0 & 127) << sh))
                    (b 0 < 128 ? v2 (go v2 (sh + 7) (k + 1)))))))
       (go 0 0 0))
   (xz-next g)
    (: m (peep g 'mode 'end)   src (g 'src)
       (? (m = 'end) ""
          (m = 'stream)
           (: h (tar-take src 12)   fl (snip h 6 8)
              (? (#h < 12) (xz-fin g 'end)
                 !(snip h 0 6 = xz-magic) (xz-fin g 'format)
                 !(rdle h 8 4 = crc32 fl) (xz-fin g 'corrupt)
                 (0 < fl 0 || 15 < fl 1) (xz-fin g 'corrupt)
                 !(charm? (xz-csize (fl 1))) (xz-fin g 'check)
                 (pins g 'fl fl 'cid (fl 1) 'recs () 'mode 'block, xz-next g)))
          (m = 'block)
           (tar-peek src 1 @ b
              (? (#b < 1) (xz-fin g 'end)
                 (b 0 = 0) (pin g 'mode 'index, xz-next g)
                 (: hs ((b 0 + 1) * 4)   hd (tar-take src hs)
                    (? (#hd < hs) (xz-fin g 'end)
                       !(rdle hd (hs - 4) 4 = crc32 (snip hd 0 (hs - 4))) (xz-fin g 'corrupt)
                       (xz-bhead hd @ bh
                          (atom? bh ? (xz-fin g bh)
                             (: d (xz-dsize (bh 2))
                                st (lzma2-new (max 4096 (charm? (bh 1) ? (min d (bh 1)) d)))
                                (st = () ? (xz-fin g 'big)
                                   (pins g 'st st 'hs hs 'bh bh 'cl 0 'un 0 'ck (xz-ck0 (g 'cid)) 'mode 'chunk,
                                    xz-next g)))))))))
          (m = 'chunk)                           ; a chunk whole: its control byte, header, data
           (: cz (g 'bh 0)   (past? v) (charm? cz && cz < v)   ; no chunk runs past a size the header said
              c (past? (g 'cl + 1) ? "" (tar-take src 1))   k0 (#c ? (c 0) 0)
              hn (? (k0 < 3) 2 (k0 < 128) -1 (192 <= k0) 5 4)
              (? (past? (g 'cl + 1)) (xz-fin g 'corrupt)
                 (#c < 1) (xz-fin g 'end)
                 (k0 = 0) (pins g 'cl (g 'cl + 1) 'mode 'check, xz-next g)
                 (hn < 0) (xz-fin g 'corrupt)
                 (: h (tar-take src hn)
                    k (#h < hn ? 0 (1 + (k0 < 3 ? (h 0 << 8 | h 1) (h 2 << 8 | h 3))))
                    body (past? (g 'cl + 1 + hn + k) ? "" (tar-take src k))
                    (? (#h < hn) (xz-fin g 'end)
                       (past? (g 'cl + 1 + hn + k)) (xz-fin g 'corrupt)
                       (#body < k) (xz-fin g 'end)
                       (lzma2-chunk (g 'st) (c + h + body) @ u
                          (!(string? u) ? (xz-fin g 'corrupt)
                             (pins g 'cl (g 'cl + 1 + hn + k) 'un (g 'un + #u) 'n (g 'n + #u)
                                   'ck (xz-ckon (g 'cid) (g 'ck) u),
                              (#u = 0 ? (xz-next g) u))))))))
          (m = 'check)                           ; the sizes the header said, the padding, the check
           (: bh (g 'bh)   cl (g 'cl)   cz (xz-csize (g 'cid))
              (charm? (bh 0) && bh 0 != cl || charm? (bh 1) && bh 1 != g 'un ? (xz-fin g 'corrupt)
                 (: pd (tar-take src (padk cl 4))   ck (tar-take src cz)
                    (? (#pd < padk cl 4 || #ck < cz) (xz-fin g 'end)
                       (0 < cz && ck != xz-ckend (g 'cid) (g 'ck)) (xz-fin g 'check)
                       (pins g 'recs ([(g 'hs + cl + cz) (g 'un)] . g 'recs) 'st () 'mode 'block,
                        xz-next g)))))
          (m = 'index)                           ; each record as the blocks read it, then the footer
           (: _ (pin g 'ib (tar-take src 1))
              n (xz-tvli g)
              recs (rev (g 'recs))
              (same l) (!(two? l) ? 1 (: a (xz-tvli g) b (xz-tvli g) (a = <l 0 && b = <l 1 ? (same >l) 0)))
              (n = () || n != #recs || !(same recs) ? (xz-fin g 'corrupt)
                 (: ib (g 'ib + tar-take src (padk #(g 'ib) 4))   cr (tar-take src 4)   f (tar-take src 12)
                    (? (#cr < 4 || #f < 12) (xz-fin g 'end)
                       (rdle cr 0 4 != crc32 ib
                        || rdle f 0 4 != crc32 (snip f 4 10)
                        || rdle f 4 4 != (#ib + 4) // 4 - 1
                        || snip f 8 10 != g 'fl
                        || snip f 10 12 != "YZ") (xz-fin g 'corrupt)
                       (pin g 'mode 'pad, xz-next g)))))
          (tar-peek src 4 @ p ; the zeros between streams, then one more or the end
             (? (#p = 0) (xz-fin g [1 (g 'n)])
                (p = zbytes 4) (tar-take src 4, xz-next g)
                (#p < 4) (xz-fin g 'corrupt)
                (pin g 'mode 'stream, xz-next g)))))
   ; .xz streamed, or a .lzma read whole: mk is asked for the writer before the first byte out,
   ; and a stream that fails before any is said without it
   (xz-unf rd mk)
    (: raw (tar-src rd)   h (tar-peek raw 13)
       (all r a) (r 0 @ p (#p = 0 ? (cats (rev a)) (all r (p . a))))
       (xz-lzma? h && snip h 0 6 != xz-magic ?
          (xz-unlzma (all (tar-rd raw) ()) @ u
             (atom? u ? u (mk 0 @ m (!(two? m) ? 'no ((<>m <>u), [1 #<>u])))))
          (: g (xz-pull (tar-rd raw))   p (xz-next g)
             (#p = 0 && atom? (g 'ans) ? (g 'ans)
                (mk 0 @ m
                   (!(two? m) ? 'no
                      (: w <>m
                         (go p) (#p = 0 ? (g 'ans) (w p, go (xz-next g)))
                         (go p))))))))
)
) ; module 'xz

; --- the face -----------------------------------------------------------------------
; `love xz`, `unxz`, `xzcat`, and the .lzma readers `unlzma`/`lzcat`: xz-utils' flag
; spelling over the container above.
;
;   xz [-cdfkqtvz] [-0..-9] [-e] [-T N] [-C CHECK] [-S SUF] [FILE..]
;   unxz = xz -d      xzcat = xz -dc      unlzma = xz -d      lzcat = xz -dc
;
; a level picks the dictionary (-0 256 KiB .. -9 64 MiB, xz's), never bigger than the
; input needs; the parse is one fast greedy one whatever the level, so -e and -T are
; taken and change nothing. writing is .xz alone; reading takes .xz and .lzma by their
; magic. no file, or a bare -, is the filter. status as xz's: 0, 1 an error, 2 a warning.
(module 'xzcmd
(borrow 'xz)
(borrow 'path)
(borrow 'posix)
(: xzc-help "xz -- the .xz container in love (src/love/lib/xz.c is the LZMA2 codec)
usage: xz [-cdfkqtvz] [-0..-9] [-e] [-T N] [-C CHECK] [-S SUF] [FILE..]
  -z  compress (the default)            -d  decompress (unxz; .xz and .lzma)
  -c  write on stdout, keep the files   -k  keep the input file
  -f  overwrite an existing output      -t  test the files, write nothing
  -q  say nothing on a warning          -v  say what happened, on err
  -0 .. -9  the dictionary, 256 KiB to 64 MiB (6: 8 MiB)
  -C  the check: none crc32 crc64 (the default) sha256
  -S  the suffix (.xz unsaid)           -e -T N  taken, and they change nothing
no file, or a bare -, is the filter: stdin -> stdout"
   xzc-dicts [262144 1048576 2097152 4194304 4194304 8388608 8388608 16777216 33554432 67108864]

   (xzc-moan t m) (peep t 'q 0 ? 0 (say err ("xz: " + m + "\n"), flush err))
   (xzc-worse a b) (max a b)
   (xzc-dict t n)                      ; the level's dictionary, cut to what n bytes need
    (: d (xzc-dicts (peep t 'lvl 6)) (go v) (d <= v || n <= v ? v (go (v * 2))) (go 4096))
   (xzc-why w) (w @ 'format "File format not recognized" 'end "Unexpected end of input"
                    'filter "Unsupported filters" 'check "Compressed data is corrupt"
                    'big "Memory usage limit reached (the output passes 1 GiB)"
                    "Compressed data is corrupt")
   ; .xz and .lzma come off; .txz and .tlz answer .tar
   (xzc-stem t p)
    (: suf (t 'suf)
       (p @ (s + ^suf + "") [1 s]
            (s + ".xz") [1 s]
            (s + ".lzma") [1 s]
            ((s + ".txz") || (s + ".tlz")) [1 (s + ".tar")]
            ()))
   (xzc-put t p dst bytes st)           ; the output laid, the input's mode and time carried
    (? (two? (lstat dst) && !(peep t 'f 0)) (xzc-moan t (dst + ": File exists"), 1)
       !(uwrite dst bytes) (xzc-moan t (dst + ": Cannot write"), 1)
       (two? st && (chmod dst (st 2 & 4095), utime dst (st 1)),
        (peep t 'k 0 ? 0 (unlink p)),
        peep t 'v 0 && (say err ("xz: " + p + " -> " + dst + "\n"), flush err),
        0))
   (xzc-rd q) (_ \ (see q @ c (c < 0 ? "" (unsee q c, chug q))))
   ; a file decompressed as it comes off the disk: the output opened before the first byte,
   ; its mode and time laid after the last, and taken away again if the stream fails partway
   (xzc-unone t p st)
    (xzc-stem t p @ stem
       (!(peep t 't 0) && !(peep t 'c 0) && !stem ? (xzc-moan t (p + ": Filename has an unknown suffix, skipping"), 2)
          (open p "r" @ q
             (!(hot? q) ? (xzc-moan t (p + ": No such file or directory"), 1)
                (: k {}
                   (no m) (xzc-moan t m, ())
                   (mk _) (? (peep t 't 0) [1 (s \ 0)]
                             (peep t 'c 0) [1 (s \ say out s)]
                             (<>stem @ dst
                                (two? (lstat dst) && !(peep t 'f 0) ? (no (dst + ": File exists"))
                                   (open dst "w" @ o
                                      (!(hot? o) ? (no (dst + ": Cannot write"))
                                         (pins k 'o o 'dst dst, [1 (s \ say o s)]))))))
                   u (xz-unf (xzc-rd q) mk)
                   _ (close q)
                   o (peep k 'o ())   laid (hot? o)   dst (peep k 'dst "")
                   (laid && close o,
                    (? (u = 'no) 1
                       (atom? u) (laid && unlink dst, xzc-moan t (p + ": " + xzc-why u), 1)
                       !laid 0
                       (two? st && (chmod dst (st 2 & 4095), utime dst (st 1)),
                        (peep t 'k 0 ? 0 (unlink p)),
                        peep t 'v 0 && (say err ("xz: " + p + " -> " + dst + "\n"), flush err),
                        0))))))))
   (xzc-one t p)
    (stat p @ st
       (? (two? st && st 2 & 61440 = 16384) (xzc-moan t (p + ": Is a directory, skipping"), 2)
          (peep t 'd 0) (xzc-unone t p st)
          (uread p @ r
             (!r ? (xzc-moan t (p + ": No such file or directory"), 1)
                (: suf (peep t 'suf ".xz")
                   (!(peep t 'c 0) && (ends? p suf || ends? p ".xz" || ends? p ".txz")
                    ? (xzc-moan t (p + ": File already has '" + suf + "' suffix, skipping"), 2)
                      (xz-pack <>r (xzc-dict t #<>r) (peep t 'ck 'crc64) @ z
                         (peep t 'c 0 ? (say out z, 0) (xzc-put t p (p + suf) z st)))))))))
   (xzc-filter t)
    (? (peep t 'd 0)
       (xz-unf (xzc-rd in) (_ \ [1 (peep t 't 0 ? (s \ 0) (s \ say out s))]) @ u
          (atom? u ? (xzc-moan t ("(stdin): " + xzc-why u), 1) 0))
       (two? (tty out) && !(peep t 'f 0))
        (say err "xz: Compressed data cannot be written to a terminal\n", 1)
       (slurp in + "" @ s2 (say out (xz-pack s2 (xzc-dict t #s2) (peep t 'ck 'crc64)), 0)))

   ; the cli walker in gnu order. -d, -z and -t decide the direction by the last one said,
   ; and a level digit likewise; -C -S -T -F take a word, glued or next
   xzc-longs {"stdout" 99 "to-stdout" 99 "decompress" 100 "uncompress" 100 "compress" 122
              "keep" 107 "force" 102 "test" 116 "quiet" 113 "verbose" 118 "extreme" 101
              "fast" 101 "best" 101 "help" 104 "version" 86
              "check" 67 "suffix" 83 "threads" 84 "format" 70}
   xzc-vals [67 83 84 70]
   (xzc-opts as t)                     ; -> (1 files) | () for a bad option
    (: (ck w) (elem w '("none" "crc32" "crc64" "sha256") ? (pin t 'ck (intern w), 1)
                 (xzc-moan t ("--check=" + w + ": Unsupported integrity check type"), ()))
       (fmt f) (elem f '("auto" "xz" "lzma" "alone") ? 1
                  (xzc-moan t ("--format=" + f + ": not here (auto, xz, lzma)"), ()))
       (last ks) (cite 'cli 'uoptlast as ks xzc-vals xzc-longs)
       u {}
       r (cite 'cli 'uoptp as u xzc-vals () xzc-longs)
       bad (two? r ? (cite 'cli 'uoptun u "cdzktqvfehVCSTF0123456789") ())
       (? (atom? r)
           (: w <(rev as)
              (xzc-moan t (w 1 = 45 ? ("option '" + w + "' requires an argument")
                             ("option requires an argument -- '" + string (w (#w - 1)) + "'")), ()))
          (r 3) (xzc-moan t ("unrecognized option '" + r 3 + "'"), ())
          bad (xzc-moan t ("invalid option -- '" + string bad + "'"), ())
          (: _ (each (chars "ckfqvhV") (c \ peep u c 0 && pin t (intern (string c)) 1))
             dir (last [100 122 116])
             _ (dir ? (pin t 'd (dir = 122 ? 0 1)))
             _ (peep u 116 0 ? (pin t 't 1))
             lv (last "0123456789")
             _ (lv ? (pin t 'lvl (lv - 48)))
             s (u 83)
             _ (two? s ? (pin t 'suf <>s))
             c (u 67) f (u 70)
             (? (two? c && !(ck <>c)) ()
                (two? f && !(fmt <>f)) ()
                [1 (r 2)]))))

   (xzc-run as t)
    (: o (xzc-opts as t)
       r (? !o 1
            (peep t 'h 0) (say out (xzc-help + "\n"), 0)
            (peep t 'V 0) (say out (uvers "xz" + "\n"), 0)
            (filter (p \ p != "-") <>o @ fs
               (atom? fs ? (xzc-filter t)
                  (foldl (acc \ p \ xzc-worse acc (xzc-one t p)) 0 fs))))
       (flush out, flush err, r))
   (xz-main as) (xzc-run as {})
   (unxz-main as) (xzc-run as (pin {} 'd 1))
   (xzcat-main as) (xzc-run as (pins {} 'd 1 'c 1))

   _ (pins (cite 'verbs 'tab)
      'xz xz-main 'unxz unxz-main 'xzcat xzcat-main
      'unlzma unxz-main 'lzcat xzcat-main))

) ; module 'xzcmd
