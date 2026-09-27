; apps/xz.l -- the .xz container (and the old .lzma one, read) over love/lib/xz.c's LZMA2
; codec. `(borrow 'xz)`, then:
;   (xz-pack s dict check)  -> the .xz bytes of s: one block, one LZMA2 filter, the check
;                              one of 'none 'crc32 'crc64 'sha256
;   (xz-unpack s)           -> (1 bytes) | a word saying why not ('format 'corrupt 'end
;                              'filter 'check): every stream in s, the padding between them
;                              skipped, each block's check and each index held to its blocks
; the codec is C (lzma2e lzma2d lzma2len lzmad crc64); the container is here, where
; its fields are plain to read. the xz spec is tukaani's .xz file format 1.2.
(module 'xz
(borrow 'posix)
(borrow 'bytes)

(:
   (xz-bytes l) (foldl (\ a b (a + string b)) "" l)
   xz-magic (xz-bytes [253 55 122 88 90 0])
   (xz-vli v) (? (v < 128) (string v) (string (128 | (v & 127)) + xz-vli (v >> 7)))
   (xz-rvli s i)                       ; -> (value next) | () for a run off the end or past 9
    (: (go j v sh) (? (#s <= j || 9 <= j - i) ()
                      (: b (s j) v2 (v + ((b & 127) << sh))
                         (? (b < 128) [v2 (j + 1)] (go (j + 1) v2 (sh + 7)))))
       (go i 0 0))
   xz-checks {'none 0 'crc32 1 'crc64 4 'sha256 10}
   (xz-csize id) (? (id = 0) 0 (id = 1) 4 (id = 4) 8 (id = 10) 32 ())
   (xz-check id u) (? (id = 1) (wrle (crc32 u) 4) (id = 4) (crc64 u) (id = 10) (hex2b (sha256 u)) "")
   ; the dictionary as LZMA2's one props byte spells it: (2 | p&1) << (p/2 + 11)
   (xz-dsize p) ((2 | (p & 1)) << (p // 2 + 11))
   (xz-dprop d) (: (go p) (? (40 <= p || d <= xz-dsize p) p (go (p + 1))) (go 0))

   ;; --- writing: one block holding everything, both sizes in its header ---
   (xz-pack s dict check)
    (: cid (peep xz-checks check 4)
       flags (xz-bytes [0 cid])
       head (xz-magic + flags + wrle (crc32 flags) 4)
       p (xz-dprop dict)
       body (? (#s = 0) "" (lzma2e s (xz-dsize p)))
       ; the block header: its size byte, flags (one filter, both sizes), the sizes, the
       ; LZMA2 filter with its props byte, padding to four, and its own crc32
       bh0 (string 192 + xz-vli #body + xz-vli #s + xz-bytes [33 1 p])
       bh1 (string ((#bh0 + 1 + padk (#bh0 + 1) 4 + 4) // 4 - 1) + bh0)
       bh2 (bh1 + zbytes (padk #bh1 4))
       bh (bh2 + wrle (crc32 bh2) 4)
       ck (xz-check cid s)
       block (? (#s = 0) "" (bh + body + zbytes (padk #body 4) + ck))
       ; the index: one record (unpadded size, uncompressed size), or none for no block
       ix0 (string 0 + (? (#s = 0) (xz-vli 0) (xz-vli 1 + xz-vli (#bh + #body + #ck) + xz-vli #s)))
       ix1 (ix0 + zbytes (padk #ix0 4))
       ix (ix1 + wrle (crc32 ix1) 4)
       ft0 (wrle (#ix // 4 - 1) 4 + flags)
       (head + block + ix + wrle (crc32 ft0) 4 + ft0 + "YZ"))

   ;; --- reading ---
   (xz-block s i cid)                  ; a block at i -> (bytes next unpadded) | a word
    (: hs ((s i + 1) * 4)
       (? (#s < i + hs) 'end
          !(rdle s (i + hs - 4) 4 = crc32 (snip s i (i + hs - 4))) 'corrupt
          (: hd (snip s i (i + hs))
             fl (hd 1)
             nf ((fl & 3) + 1)
             r1 (? (0 < (fl & 64)) (xz-rvli hd 2) [() 2])
             r2 (? (r1 && 0 < (fl & 128)) (xz-rvli hd <>r1) (r1 && [() <>r1]))
             (? (!r2 || 0 < (fl & 60)) 'corrupt
                !(nf = 1) 'filter
                (: fi (xz-rvli hd <>r2)
                   pz (fi && xz-rvli hd <>fi)
                   (? (!pz || !(<fi = 33) || !(<pz = 1) || 40 < hd <>pz) 'filter
                      (: d0 (i + hs)
                         cl (? (charm? <r1) <r1 (: n (lzma2len (snip s d0 #s)) (? (charm? n) n -1)))
                         u (? (0 <= cl && d0 + cl <= #s) (lzma2d (snip s d0 (d0 + cl))) ())
                         cz (xz-csize cid)
                         e (d0 + cl + padk cl 4)
                         (? (cl < 0 || #s < d0 + cl) 'end
                            (!(string? u) || (charm? <r2 && !(#u = <r2))) 'corrupt
                            (#s < e + cz) 'end
                            (? (0 < cz && !(snip s e (e + cz) = xz-check cid u)) 'check
                               [u (e + cz) (hs + cl + cz) #u])))))))))
   (xz-stream s i)                     ; a stream at i -> (bytes next) | a word
    (? (#s < i + 12) 'end
          !(snip s i (i + 6) = xz-magic) 'format
          (: fl (snip s (i + 6) (i + 8))
             (? !(rdle s (i + 8) 4 = crc32 fl) 'corrupt
                (0 < (fl 0) || 15 < (fl 1)) 'corrupt
                !(charm? (xz-csize (fl 1))) 'check
                (: cid (fl 1)
                   (blocks j acc recs)
                    (? (#s <= j) 'end
                       (s j = 0) [acc j (rev recs)]
                       (: b (xz-block s j cid)
                          (? !(two? b) b
                             (blocks <>b (acc + <b) ([<>>b (b 3)] . recs)))))
                   r (blocks (i + 12) "" ())
                   (? !(two? r) r
                      (: ix <>r recs <>>r
                         n (xz-rvli s (ix + 1))
                         (rec k j) (? (k < 1) j
                                      (: a (xz-rvli s j) b (a && xz-rvli s <>a)
                                         (? b (rec (k - 1) <>b) ())))
                         e (n && rec <n <>n)
                         (? (!e || !(<n = #recs)) 'corrupt
                            (: e2 (e + padk (e - ix) 4)
                               (? (#s < e2 + 16) 'end
                                  !(rdle s e2 4 = crc32 (snip s ix e2)) 'corrupt
                                  ; each record, as the blocks read it
                                  !(: (chk k j) (? (k < 1) 1
                                                   (: a (xz-rvli s j) b (xz-rvli s <>a) m (recs (<n - k))
                                                      (? (<a = <m && <b = <>m) (chk (k - 1) <>b) ())))
                                      (chk <n <>n))
                                   'corrupt
                                  (: f (e2 + 4)
                                     (? (!(rdle s f 4 = crc32 (snip s (f + 4) (f + 10)))
                                         || !(rdle s (f + 4) 4 = (e2 + 4 - ix) // 4 - 1)
                                         || !(snip s (f + 8) (f + 10) = fl)
                                         || !(snip s (f + 10) (f + 12) = "YZ"))
                                        'corrupt
                                        [<r (f + 12)])))))))))))
   (xz-unpack s)
    (: (go i acc)
        (: r (xz-stream s i)
           (? !(two? r) r
              (: (pad j) (? (j + 4 <= #s && snip s j (j + 4) = zbytes 4) (pad (j + 4)) j)
                 j (pad <>r)
                 (? (#s <= j) [1 (acc + <r)]
                    (#s < j + 4) 'corrupt
                    (go j (acc + <r))))))
       (go 0 ""))
   ; the old container: a props byte, the dictionary, the size (all ones for unsaid,
   ; then the stream's end mark says where it stops), and one LZMA1 stream
   ; liblzma's sniff: props under 225, a dictionary of 2^n or 2^n + 2^(n-1) (or all ones),
   ; and a size of at most 2^38 or unsaid
   (xz-lzma? s)
    (: d (? (13 <= #s) (rdle s 1 4) 0) us (? (13 <= #s) (rdle s 5 8) 0)
       (up v) (: a (v - 1) b (a | (a >> 2)) c (b | (b >> 3)) e (c | (c >> 4)) f (e | (e >> 8))
                 ((f | (f >> 16)) + 1))
       (13 <= #s && s 0 < 225 && (d = 4294967295 || up d = d)
        && (us <= 274877906944 || us = 18446744073709551615)))
   (xz-unlzma s)
    (: us (rdle s 5 8)
       u (lzmad (snip s 13 #s) (s 0) (rdle s 1 4) (? (us = 18446744073709551615) -1 us))
       (? (string? u) [1 u] 'corrupt))
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
(: xzc-help "xz -- the .xz container in love (love/lib/xz.c is the LZMA2 codec)
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

   (xzc-moan t m) (? (peep t 'q 0) 0 (: _ (say err ("xz: " + m + "\n")) (flush err)))
   (xzc-ends? s x) (: n #s m #x (m <= n && snip s (n - m) n = x))
   (xzc-worse a b) (max a b)
   (xzc-dict t n)                      ; the level's dictionary, cut to what n bytes need
    (: d (xzc-dicts (peep t 'lvl 6)) (go v) (? (d <= v || n <= v) v (go (v * 2))) (go 4096))
   (xzc-why w) (w @ 'format "File format not recognized" 'end "Unexpected end of input"
                    'filter "Unsupported filters" 'check "Compressed data is corrupt"
                    "Compressed data is corrupt")
   (xzc-un s) (? (xz-lzma? s && !(snip s 0 6 = xz-magic)) (xz-unlzma s) (xz-unpack s))
   ; .xz and .lzma come off; .txz and .tlz answer .tar
   (xzc-stem t p)
    (: suf (peep t 'suf ())
       (? (suf && xzc-ends? p suf) [1 (snip p 0 (#p - #suf))]
          (xzc-ends? p ".xz") [1 (snip p 0 (#p - 3))]
          (xzc-ends? p ".lzma") [1 (snip p 0 (#p - 5))]
          (xzc-ends? p ".txz" || xzc-ends? p ".tlz") [1 (snip p 0 (#p - 4) + ".tar")]
          ()))
   (xzc-put t p dst bytes st)           ; the output laid, the input's mode and time carried
    (? (two? (lstat dst) && !(peep t 'f 0)) (: _ (xzc-moan t (dst + ": File exists")) 1)
       !(uwrite dst bytes) (: _ (xzc-moan t (dst + ": Cannot write")) 1)
       (: _ (two? st && (: _ (chmod dst (st 2 & 4095)) (utime dst (st 1))))
          _ (peep t 'k 0 ? 0 (unlink p))
          _ (peep t 'v 0 && (: _ (say err ("xz: " + p + " -> " + dst + "\n")) (flush err)))
          0))
   (xzc-one t p)
    (: r (uread p)
       st (stat p)
       (? !r (: _ (xzc-moan t (p + ": No such file or directory")) 1)
          (two? st && (st 2 & 61440) = 16384) (: _ (xzc-moan t (p + ": Is a directory, skipping")) 2)
          (peep t 'd 0)
           (: u (xzc-un <>r) stem (xzc-stem t p)
              (? !(two? u) (: _ (xzc-moan t (p + ": " + xzc-why u)) 1)
                 (peep t 't 0) 0
                 (peep t 'c 0) (: _ (say out <>u) 0)
                 !stem (: _ (xzc-moan t (p + ": Filename has an unknown suffix, skipping")) 2)
                 (xzc-put t p <>stem <>u st)))
          (: suf (peep t 'suf ".xz")
             (? (!(peep t 'c 0) && (xzc-ends? p suf || xzc-ends? p ".xz" || xzc-ends? p ".txz"))
                (: _ (xzc-moan t (p + ": File already has '" + suf + "' suffix, skipping")) 2)
                (: z (xz-pack <>r (xzc-dict t #<>r) (peep t 'ck 'crc64))
                   (? (peep t 'c 0) (: _ (say out z) 0) (xzc-put t p (p + suf) z st)))))))
   (xzc-filter t)
    (: s (slurp in) s2 (s + "")
       (? (peep t 'd 0)
          (: u (xzc-un s2)
             (? !(two? u) (: _ (xzc-moan t ("(stdin): " + xzc-why u)) 1)
                (peep t 't 0) 0
                (: _ (say out <>u) 0)))
          (two? (tty out) && !(peep t 'f 0))
           (: _ (say err "xz: Compressed data cannot be written to a terminal\n") 1)
          (: _ (say out (xz-pack s2 (xzc-dict t #s2) (peep t 'ck 'crc64))) 0)))

   (xzc-opts as t)                     ; -> (1 files) | () for a bad option
    (: (ck w) (? (elem w '("none" "crc32" "crc64" "sha256")) (: _ (pin t 'ck (intern w)) 1)
                 (: _ (xzc-moan t ("--check=" + w + ": Unsupported integrity check type")) ()))
       (long w)                        ; -> 1 | () for a bad one
        (: eq (\ k (#k < #w && snip w 0 #k = k))
           (? (w = "stdout" || w = "to-stdout") (: _ (pin t 'c 1) 1)
              (w = "decompress" || w = "uncompress") (: _ (pin t 'd 1) 1)
              (w = "compress") (: _ (pin t 'd 0) 1)
              (w = "keep") (: _ (pin t 'k 1) 1)
              (w = "force") (: _ (pin t 'f 1) 1)
              (w = "test") (: _ (pin t 't 1) _ (pin t 'd 1) 1)
              (w = "quiet") (: _ (pin t 'q 1) 1)
              (w = "verbose") (: _ (pin t 'v 1) 1)
              (w = "extreme" || w = "fast" || w = "best") 1
              (w = "help") (: _ (pin t 'h 1) 1)
              (w = "version") (: _ (pin t 'V 1) 1)
              (eq "check=") (ck (snip w 6 #w))
              (eq "suffix=") (: _ (pin t 'suf (snip w 7 #w)) 1)
              (eq "threads=") 1
              (eq "format=") (: f (snip w 7 #w)
                                (? (elem f '("auto" "xz" "lzma" "alone")) 1
                                   (: _ (xzc-moan t ("--format=" + f + ": not here (auto, xz, lzma)")) ())))
              (: _ (xzc-moan t ("unrecognized option '--" + w + "'")) ())))
       (go a fs)
        (? !(two? a) [1 (rev fs)]
           (: w <a n #w
              (? (w = "--") [1 (rev fs + >a)]
                 (n < 2 || !(w 0 = 45)) (go >a (w . fs))
                 (w 1 = 45) (? (long (snip w 2 n)) (go >a fs) ())
                 (: (cl k rest)
                     (? (n <= k) (go rest fs)
                        (: c (w k)
                           (? (48 <= c && c <= 57) (: _ (pin t 'lvl (c - 48)) (cl (k + 1) rest))
                              (elem c [67 83 84])     ; -C -S -T take a word, glued or next
                               (: g (snip w (k + 1) n)
                                  v (? (0 < #g) [g rest] (two? rest) [<rest >rest] ())
                                  (? !v (: _ (xzc-moan t ("option requires an argument -- '" + string c + "'")) ())
                                     (c = 67) (? (ck <v) (go <>v fs) ())
                                     (c = 83) (: _ (pin t 'suf <v) (go <>v fs))
                                     (go <>v fs)))
                              (c = 122) (: _ (pin t 'd 0) (cl (k + 1) rest))
                              (c = 116) (: _ (pin t 't 1) _ (pin t 'd 1) (cl (k + 1) rest))
                              (elem c [99 100 102 107 113 118]) (: _ (pin t (intern (string c)) 1) (cl (k + 1) rest))
                              (c = 101) (cl (k + 1) rest)
                              (c = 104) (: _ (pin t 'h 1) (cl (k + 1) rest))
                              (c = 86) (: _ (pin t 'V 1) (cl (k + 1) rest))
                              (: _ (xzc-moan t ("invalid option -- '" + string c + "'")) ()))))
                    (cl 1 >a)))))
       (go as ()))

   (xzc-run as t)
    (: o (xzc-opts as t)
       r (? !o 1
            (peep t 'h 0) (: _ (say out (xzc-help + "\n")) 0)
            (peep t 'V 0) (: _ (say out ("xz (love " + love-version + ")\n")) 0)
            (: fs (filter (p \ !(p = "-")) <>o)
               (? !(two? fs) (xzc-filter t)
                  (foldl (\ acc p (xzc-worse acc (xzc-one t p))) 0 fs))))
       _ (flush out) _ (flush err)
       r)
   (xz-main as) (xzc-run as (tablet 0))
   (unxz-main as) (: t (tablet 0) _ (pin t 'd 1) (xzc-run as t))
   (xzcat-main as) (: t (tablet 0) _ (pin t 'd 1) _ (pin t 'c 1) (xzc-run as t))

   _ (pins (cite 'verbs 'tab)
      'xz xz-main 'unxz unxz-main 'xzcat xzcat-main
      'unlzma unxz-main 'lzcat xzcat-main))

) ; module 'xzcmd
