; src/apps/gz.l -- gzip in love, both ways: the RFC 1952 container, the RFC 1951 deflate
; stream inside it, and the crc32 underneath. `(borrow 'gz)`, then:
;
;   (gz-crc32 s)           -> the IEEE crc32 of a string, a charm
;   (gz-deflate s)         -> raw deflate bytes
;   (gz-inflate s n)       -> (1 bytes) | () | 'big    n a size hint, 0 when unknown
;   (gz-puff s n)          -> the same, in love, and the oracle the C twin answers to
;   (gz-zip s nom stamp)   -> a .gz member; nom "" for no name, stamp 0 for no time
;   (gz-deflate-best s) (gz-zip9 s nom stamp)  the same, deflated harder: a lazy parse down a
;                          long chain
;   (gz-unzip s)           -> (1 bytes) | () | 'big
;   (gz-head s)            -> (1 stamp name body-seat) | (), the header walked
;   (gz-pull rd)           -> g, a reader: (gz-next g) the next piece inflated, "" at the end
;   (gz-unzipf rd mk)      -> (1 stamp name n seat) | ('trail ..) | 'nogz | 'no | () | 'big
;                             the members streamed: rd _ is the next piece ("" the end), mk
;                             (stamp name) -> (1 w), w the writer the bytes go through, or ()
;
; every decode answers (1 _): an empty member is legitimate, so test with two?.
;
; the coder is greedy LZ77 in 16k-symbol blocks, each written the cheapest of stored,
; fixed or dynamic Huffman; the decoder takes all three.
; gz-inflate is a door onto src/love/lib/gz.c's nif, falling back to
; gz-puff (test/host/gzc.l fuzzes the pair).
; a cask is mutable bytes; a tray's pin answers a copy, so trays hold constant tables only.
; the wrap registers module 'gz in the dist cat too, so the bake compiles it once.
(module 'gz
(borrow 'bytes)
(borrow 'hashes)
(:
   ; --- crc32 (IEEE 802.3: reflected, polynomial 0xedb88320) -----------------
   ; built once at load into a tray, read with peep. the final xor is the same
   ; 0xffffffff the register starts at.
   (gz-crcrow n) (foldl (\ c k (c & 1 ? (c >> 1 ^ 3988292384) (c >> 1))) n ^8)
   gz-crctab (star-tray '(256) (map gz-crcrow (jot 256)))
   (gz-crcwalk s) (foldl (\ c i (peep gz-crctab ((c ^ s i) & 255) 0 ^ c >> 8)) 4294967295 ^#s ^ 4294967295)

   ; src/love/lib/hash.c's; the walk above states the polynomial and is the oracle
   ; test/host/gzc.l holds the C to.
   ; `charm?`, not `?`: the crc of "" is 0, a true answer a truth test calls absent.
   (gz-crc32 s)
    (crc32 s @ r (charm? r ? r (gz-crcwalk s)))

   ; --- the bit sink ---------------------------------------------------------
   ; deflate packs bits into bytes LSB-first, but a Huffman code is stored
   ; MSB-first, so a code is reversed on the way in and its extra bits are not.
   ; the cursor is a tablet: 0 the accumulator, 1 how many bits it holds.
   (gz-put j t v k)
    (: (go a n) (n < 8 ? (pin t 0 a, pin t 1 n, 0)
                    (say j (string (a & 255)), go (a >> 8) (n - 8)))
       (go (peep t 0 0 | (v & (1 << k) - 1) << peep t 1 0) (peep t 1 0 + k)))
   (gz-align j t)                          ; flush the tail byte, zero-padded
    (peep t 1 0 ?
       (say j (string (peep t 0 0 & 255)), pin t 0 0, pin t 1 0, 0)
       0)
   (gz-rev v k) (: (go i a w) (k <= i ? a (go (i + 1) (a << 1 | w & 1) (w >> 1))) (go 0 0 v))

   ; --- the length and distance ladders (RFC 1951 3.2.5) ---------------------
   gz-lbase (star-tray '(29) '(3 4 5 6 7 8 9 10 11 13 15 17 19 23 27 31 35 43 51 59
                               67 83 99 115 131 163 195 227 258))
   gz-lext  (star-tray '(29) '(0 0 0 0 0 0 0 0 1 1 1 1 2 2 2 2 3 3 3 3 4 4 4 4 5 5 5 5 0))
   gz-dbase (star-tray '(30) '(1 2 3 4 5 7 9 13 17 25 33 49 65 97 129 193 257 385 513 769
                               1025 1537 2049 3073 4097 6145 8193 12289 16385 24577))
   gz-dext  (star-tray '(30) '(0 0 0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 10 10 11 11 12 12 13 13))
   ; the ladders are short and walked from the top, so the first base at or below
   ; the value is its code -- no search structure earns its keep at 30 rows.
   (gz-lcode v) (: (go i) (? (i < 1) 0 (peep gz-lbase i 0 <= v) i (go (i - 1))) (go 28))
   (gz-dcode v) (: (go i) (? (i < 1) 0 (peep gz-dbase i 0 <= v) i (go (i - 1))) (go 29))

   ; --- 32-bit cells in a cask ----------------------------------------------
   ; the match finder's two arrays hold positions, which outgrow a byte and outgrow
   ; 16 bits on any file over 64k. a cask is the only mutable array here, so a cell
   ; is four of its bytes.
   (gz-c32 c i) (i * 4 @ o
                   (peep c o 0 + (peep c (o + 1) 0 << 8)
                    + (peep c (o + 2) 0 << 16) + (peep c (o + 3) 0 << 24)))
   (gz-c32! c i v) (i * 4 @ o
                      (pin c o (v & 255), pin c (o + 1) (v >> 8 & 255),
                       pin c (o + 2) (v >> 16 & 255), pin c (o + 3) (v >> 24 & 255), 0))

   ; --- a Huffman code, built from frequencies -------------------------------
   ; sort the used symbols by count, then merge the two lightest live nodes until one is
   ; left; a leaf's depth is its code length. the candidates come off two queues -- sorted
   ; leaves, and the internal nodes the merge makes, ascending for free -- so nothing is
   ; searched or re-sorted. a symbol rides its count as one number, count:sym, so `sort`
   ; needs no comparator and the tie goes to the lower symbol.
   (gz-hkeys f i a) (i < 0 ? a
                       (gz-c32 f i @ c (gz-hkeys f (i - 1) (c ? (((c << 9) + i) . a) a))))
   (gz-hcopy f nsym) (cask (nsym * 4) @ c (each ^nsym (i \ gz-c32! c i (gz-c32 f i)), c))
   (gz-hdep pa i d) (gz-c32 pa i @ p (p ? (gz-hdep pa (p - 1) (d + 1)) d))
   ; halving the counts and rebuilding walks a code back under the depth the format allows,
   ; and always terminates: all-ones is a balanced tree, nine deep over the literal alphabet.
   (gz-hhalve f nsym i) (nsym <= i ? 0
                           (gz-c32 f i @ c
                              ((c ? (gz-c32! f i (c >> 1 @ h (h ? h 1))) 0),
                               gz-hhalve f nsym (i + 1))))
   (gz-hpass f nsym lim pass)               ; -> (lengths deepest)
    (: ks (sort (gz-hkeys f (nsym - 1) ()))
       nl #ks
       w (cask (nl * 8))   sy (cask (nl * 8))   pa (cask (nl * 8))
       _ (: (go i l) (nl <= i ? 0
                        (<l @ v
                           (gz-c32! w i (v >> 9), gz-c32! sy i (v & 511),
                            go (i + 1) >l)))
            (go 0 ks))
       (pick li ii top) (? (nl <= li) 0     ; 1 takes the leaf queue, 0 the internal one
                           (top <= ii) 1
                           (gz-c32 w li <= gz-c32 w ii) 1
                           0)
       _ (: (go top li ii)
             (nl + nl - 1 <= top ? 0
                (: p (pick li ii top)
                   a (p ? li ii)    li1 (p ? (li + 1) li)    ii1 (p ? ii (ii + 1))
                   q (pick li1 ii1 top)
                   b (q ? li1 ii1)  li2 (q ? (li1 + 1) li1)  ii2 (q ? ii1 (ii1 + 1))
                   (gz-c32! w top (gz-c32 w a + gz-c32 w b),
                    gz-c32! pa a (top + 1), gz-c32! pa b (top + 1),
                    go (top + 1) li2 ii2)))
            (go nl 0 nl))
       lens {}
       mx (foldl (\ m i (gz-hdep pa i 0 @ d (pin lens (gz-c32 sy i) d, m < d ? d m))) 0 ^nl)
       ((lim < mx) & (pass < 32) ? (gz-hhalve f nsym 0, gz-hpass f nsym lim (pass + 1))
          [lens mx]))
   ; a code needs two symbols even where the block used one or none: a lone symbol wants a
   ; zero-bit code and the format cannot spell one. the two cheapest are conjured at count 1.
   (gz-hlens f nsym lim)
    (: c (gz-hcopy f nsym)                  ; halving is destructive; the caller's
       u (foldl (\ k i (gz-c32 c i ? (k + 1) k)) 0 ^nsym)   ; counts are still owed to the cost sums
       ((2 <= u ? 0
           ((gz-c32 c 0 ? 0 (gz-c32! c 0 1)),
            (gz-c32 c 1 ? 0 (gz-c32! c 1 1)), 0)),
        gz-hpass c nsym lim 0))
   ; canonical: shortest codes first, ties by symbol. the code goes in reversed, since
   ; a Huffman code is stored MSB-first and gz-put spends bits the other way.
   (gz-hcodes lens nsym mx)
    (: cnt {}
       _ (each ^nsym (i \ (peep lens i 0 @ l (l ? (pin cnt l (peep cnt l 0 + 1)) 0))))
       nxt {}
       _ (: (go l c) (mx < l ? 0
                        (pin nxt l c, go (l + 1) (c + peep cnt l 0 << 1)))
            (go 1 0))
       code {}
       (each ^nsym (i \ (peep lens i 0 @ l
                            (l ? (peep nxt l 0 @ c (pin code i (gz-rev c l), pin nxt l (c + 1), 0)) 0))),
        code))

   ; the fixed code (RFC 1951 3.2.6) is canonical over four runs of length, so it is
   ; those lengths handed to the same builder -- and the decoder reads its tables off
   ; the same two rows.
   gz-fixlenl (star-tray '(288) (map (i \ (? (i < 144) 8 (i < 256) 9 (i < 280) 7 8))
                                     ^288))
   gz-fixlend (star-tray '(30) (map (i \ 5) ^30))
   gz-fixcodl (gz-hcodes gz-fixlenl 288 9)
   gz-fixcodd (gz-hcodes gz-fixlend 30 5)

   ; --- the match finder -----------------------------------------------------
   ; deflate's window is 32k and its match 258 bytes, both the format's numbers.
   ; `head` maps a 3-byte hash to the most recent position + 1, 0 being "none". `prev`
   ; chains older positions indexed by position & the window mask, which is why a chain
   ; walk must STOP past the window -- beyond it the cell belongs to a newer position.
   gz-wsize 32768   gz-wmask 32767   gz-hmask 32767
   gz-maxmatch 258  gz-minmatch 3
   gz-chain 32      ; how far down a chain to look before taking what we have
   (gz-hash s i) ((s i << 10 ^ s (i + 1) << 5 ^ s (i + 2)) & gz-hmask)
   (gz-mlen s n i k lim)                   ; the run shared from i and from k
    (: (go l) (? (lim <= l) l
                 (n <= i + l) l
                 (s (i + l) = s (k + l)) (go (l + 1))
                 l)
       (go 0))
   (gz-find s n i head prev)                ; -> (len dist), len 0 for no match
    (: lim (n - i < gz-maxmatch ? (n - i) gz-maxmatch)
       (go k d bl bd)
        (? !k [bl bd]
           !d [bl bd]
           (: p (k - 1) dist (i - p)
              (gz-wsize < dist ? [bl bd]
                 (: l (gz-mlen s n i p lim)
                    nx (gz-c32 prev (p & gz-wmask))
                    (bl < l ? (lim <= l ? [l dist] (go nx (d - 1) l dist))
                                (go nx (d - 1) bl bd))))))
       (go (gz-c32 head (gz-hash s i)) gz-chain 0 0))

   (gz-ins s n i head prev)                 ; index position i, if 3 bytes remain
    (i + 2 < n ?
       (gz-hash s i @ h
          (gz-c32! prev (i & gz-wmask) (gz-c32 head h),
           gz-c32! head h (i + 1), 0))
       0)
   (gz-fill s n head prev i l)              ; index every position a match covered
    (each ^l (k \ gz-ins s n (i + k) head prev))

   ; --- the token buffer -----------------------------------------------------
   ; a block is tokenized first and coded second, because a code of the block's own
   ; cannot be built until the block's frequencies are known. a literal is its own
   ; byte; a match packs the two codes and the two extra values that spell it, so the
   ; ladders are walked here and not again at write time.
   gz-tokmax 16384                          ; zlib's block, measured in symbols
   ; a three-byte match spends a length code and a distance code -- thirteen bits and
   ; up, against the fifteen or so three literals cost -- so past some reach it is a
   ; loss, and a greedy parse takes it anyway and blocks the longer match one byte on.
   ; refusing them past 4096 pays everywhere measured: the source tarball 2984599 ->
   ; 2960320, this tree's .l files 32094 -> 31862, out/love 1225045 -> 1216277.
   ; and refusing them outright does not. text likes it (the tarball goes on to
   ; 2949504) and binaries do not -- out/love swells to 1275300, 4.6% worse.
   gz-toofar 4096
   (gz-tok s n head prev tok fl fd i k xb)  ; -> (i tokens extra-bits)
    (? (n <= i) [i k xb]
       (gz-tokmax <= k) [i k xb]
       (: m (? (i + gz-minmatch <= n) (gz-find s n i head prev) '(0 0))
          l (<m = 3 ? (gz-toofar < <>m ? 0 <m) <m)
          (l < gz-minmatch ?
             (s i @ c
                (gz-c32! tok k c,
                 gz-c32! fl c (gz-c32 fl c + 1),
                 gz-ins s n i head prev,
                 gz-tok s n head prev tok fl fd (i + 1) (k + 1) xb))
             (: d (<(>m))
                lc (gz-lcode l)   dc (gz-dcode d)
                le (peep gz-lext lc 0)   de (peep gz-dext dc 0)
                (gz-c32! tok k (256 + (lc << 23) + (dc << 18)
                                + (l - peep gz-lbase lc 0 << 13)
                                + (d - peep gz-dbase dc 0)),
                 gz-c32! fl (257 + lc) (gz-c32 fl (257 + lc) + 1),
                 gz-c32! fd dc (gz-c32 fd dc + 1),
                 gz-fill s n head prev i l,
                 gz-tok s n head prev tok fl fd (i + l) (k + 1) (xb + le + de))))))

   ; --- the block's own code, written out as code lengths ---------------------
   ; the lengths go through a third Huffman code, run-length coded first: 16 repeats
   ; the previous length three to six times, 17 and 18 are runs of zero, three to ten
   ; and eleven to a hundred and thirty-eight. a value is always spelled once before
   ; 16 may repeat it.
   ; the order is the format's, not ours: the code-length code declares its own
   ; lengths in this permutation so the rarely-used ones sit at the tail and can be
   ; trimmed off. both sides read the same row.
   gz-clord (star-tray '(19) '(16 17 18 0 8 7 9 6 10 5 11 4 12 3 13 2 14 1 15))
   (gz-clx sy) (sy @ 16 2 17 3 18 7 0)
   (gz-trim lens k lo) (? (k <= lo) lo (peep lens (k - 1) 0) k (gz-trim lens (k - 1) lo))
   (gz-run cl tot rl)                       ; -> how many entries rl holds
    (: (span v k) (? (tot <= k) k (peep cl k 0 = v) (span v (k + 1)) k)
       (put j sy ex) (gz-c32! rl j ((sy << 7) + ex), j + 1)
       (zeros i r j) (? (r < 3) (r ? (zeros (i + 1) (r - 1) (put j 0 0)) [i j])
                          (r < 11) (zeros (i + r) 0 (put j 17 (r - 3)))
                          (: t (138 < r ? 138 r) (zeros (i + t) (r - t) (put j 18 (t - 11)))))
       (reps i r v j) (r < 3 ? (r ? (reps (i + 1) (r - 1) v (put j v 0)) [i j])
                          (: t (6 < r ? 6 r) (reps (i + t) (r - t) v (put j 16 (t - 3)))))
       (go i j) (tot <= i ? j
                   (: v (peep cl i 0)
                      r (span v i - i)
                      p (v ? (reps (i + 1) (r - 1) v (put j v 0)) (zeros i r j))
                      (go <p <>p)))
       (go 0 0))

   ; --- what a block would cost, in bits -------------------------------------
   (gz-cost f lens nsym i a)
    (nsym <= i ? a
       (gz-cost f lens nsym (i + 1) (a + gz-c32 f i * peep lens i 0)))
   (gz-ccost rl lenc nr i a)
    (nr <= i ? a
       (gz-c32 rl i >> 7 @ sy
          (gz-ccost rl lenc nr (i + 1) (a + peep lenc sy 0 + gz-clx sy))))

   (gz-wtoks j t tok k codl lenl codd lend i)
    (k <= i ? (gz-put j t (peep codl 256 0) (peep lenl 256 0))   ; 256 ends the block
       (gz-c32 tok i @ v
          (v < 256 ?
             (gz-put j t (peep codl v 0) (peep lenl v 0),
              gz-wtoks j t tok k codl lenl codd lend (i + 1))
             (: u (v - 256)   lc (u >> 23)   dc (u >> 18 & 31)
                (gz-put j t (peep codl (257 + lc) 0) (peep lenl (257 + lc) 0),
                 (peep gz-lext lc 0 @ e (e ? (gz-put j t (u >> 13 & 31) e) 0)),
                 gz-put j t (peep codd dc 0) (peep lend dc 0),
                 (peep gz-dext dc 0 @ e (e ? (gz-put j t (u & 8191) e) 0)),
                 gz-wtoks j t tok k codl lenl codd lend (i + 1))))))
   (gz-wstored j t s i0 i1 last)
    (i1 - i0 @ len
       (gz-put j t (last ? 1 0) 1, gz-put j t 0 2,
        gz-align j t,                     ; a stored block starts at a byte
        gz-put j t (len & 255) 8, gz-put j t (len >> 8 & 255) 8,
        gz-put j t ((len ^ 65535) & 255) 8,
        gz-put j t ((len ^ 65535) >> 8 & 255) 8,
        each ^len (k \ gz-put j t (s (i0 + k)) 8)))

   ; three ways to spell one block, and the cheapest in bits wins. the tree the third
   ; must declare ahead of itself is the only reason the other two still win anything:
   ; a block of noise pays it for nothing, and a short one cannot amortize it.
   (gz-flush s j t tok k fl fd i0 i1 last xb)
    (: _ (gz-c32! fl 256 (gz-c32 fl 256 + 1))          ; end-of-block, always sent
       rl (gz-hlens fl 286 15)   lenl <rl   mxl <>rl
       rd (gz-hlens fd 30 15)    lend <rd   mxd <>rd
       hlit (gz-trim lenl 286 257)   hdist (gz-trim lend 30 1)
       cl {}                        ; the two length runs, laid end to end
       _ (each ^hlit (i \ pin cl i (peep lenl i 0)))
       _ (each ^hdist (i \ pin cl (hlit + i) (peep lend i 0)))
       rlb (cask (320 * 4))
       nr (gz-run cl (hlit + hdist) rlb)
       fc (cask (19 * 4))
       _ (each ^nr (i \ (gz-c32 rlb i >> 7 @ sy (gz-c32! fc sy (gz-c32 fc sy + 1)))))
       rc (gz-hlens fc 19 7)   lenc <rc   mxc <>rc
       hclen (: (go i) (? (i <= 4) 4 (peep lenc (peep gz-clord (i - 1) 0) 0) i (go (i - 1)))
                (go 19))
       dyn (17 + hclen * 3 + gz-ccost rlb lenc nr 0 0
            + gz-cost fl lenl 286 0 0 + gz-cost fd lend 30 0 0 + xb)
       fix (3 + gz-cost fl gz-fixlenl 286 0 0 + gz-cost fd gz-fixlend 30 0 0 + xb)
       ; len is sixteen bits, so a span past 65535 has no stored spelling at all.
       raw (i1 - i0 < 65536 ? (42 + (i1 - i0) * 8) (dyn + fix))
       (? (raw < (dyn <= fix ? dyn fix)) (gz-wstored j t s i0 i1 last)
          (fix < dyn)
           (gz-put j t (last ? 1 0) 1, gz-put j t 1 2,
            gz-wtoks j t tok k gz-fixcodl gz-fixlenl gz-fixcodd gz-fixlend 0)
          (: codl (gz-hcodes lenl 286 mxl)   codd (gz-hcodes lend 30 mxd)
             codc (gz-hcodes lenc 19 mxc)
             (gz-put j t (last ? 1 0) 1, gz-put j t 2 2,
              gz-put j t (hlit - 257) 5, gz-put j t (hdist - 1) 5,
              gz-put j t (hclen - 4) 4,
              each ^hclen (i \ gz-put j t (peep lenc (peep gz-clord i 0) 0) 3),
              each ^nr (i \ (: v (gz-c32 rlb i)   sy (v >> 7)
                               (gz-put j t (peep codc sy 0) (peep lenc sy 0),
                                (gz-clx sy @ b (b ? (gz-put j t (v & 127) b) 0))))),
              gz-wtoks j t tok k codl lenl codd lend 0))))

   ; the window and the chains outlive the block: a match may reach back into any
   ; block already written, which is what makes many blocks cost only their trees.
   (gz-blocks s n j t head prev i)
    (: tok (cask (gz-tokmax * 4))
       fl (cask (286 * 4))   fd (cask (30 * 4))
       r (gz-tok s n head prev tok fl fd i 0 0)
       i2 <r   k <>r   xb <>>r
       (gz-flush s j t tok k fl fd i i2 (n <= i2) xb,
        (n <= i2 ? 0 (gz-blocks s n j t head prev i2))))

   (gz-deflatel s)
    (: n #s
       j (jug 0)   t {}
       head (cask (32768 * 4))   prev (cask (32768 * 4))
       (gz-blocks s n j t head prev 0,
        gz-align j t,
        slurp j + ""))
   ; src/love/lib/gz.c's, a twin held to the bytes of the coder above: the love lane is the
   ; oracle test/host/gzc.l holds it to.
   (gz-deflate s)
    (deflate s @ r (string? r ? r (gz-deflatel s)))
   ; the harder coder has no love twin: it is the image lane's, and any deflate reads it
   (gz-deflate-best s)
    (deflate-best s @ r (string? r ? r (gz-deflate s)))

   ; --- the growing byte buffer ---------------------------------------------
   ; inflate writes bytes and reads them back (a match copies out of what it has
   ; already produced), so its sink cannot be a jug -- a jug pours out, it does not
   ; index. a cask that doubles, then one exact copy at the end.
   (gz-buf n) ({} @ b (pin b 0 (cask (n < 64 ? 64 n)), pin b 1 0, b))
   (gz-room b k)
    (: c (peep b 0 0) cap #c len (peep b 1 0)
       (len + k <= cap ? 0
          (: big (: (go m) (len + k <= m ? m (go (m * 2))) (go cap))
             c2 (cask big)
             ((len ? (pour c2 0 (string c) 0 len) 0),
              pin b 0 c2, 0))))
   ; the room check is inline, and that is not tidiness: `gz-room` reads the cask
   ; and its length again for a test the pushing path has already made, and this
   ; runs once per output byte -- nine and a half million of them for the source
   ; the artifact carries.
   (gz-push b v)
    (: c (peep b 0 0) len (peep b 1 0)
       (len < #c ? (pin c len v, pin b 1 (len + 1), 0)
          (: _ (gz-room b 1) c2 (peep b 0 0)
             (pin c2 len v, pin b 1 (len + 1), 0))))
   (gz-take b)
    (: c (peep b 0 0) len (peep b 1 0)
       (len ? (cask len @ c2 (pour c2 0 (string c) 0 len, string c2)) ""))
   ; a match copies byte by byte on purpose: deflate lets a run overlap its own
   ; source (dist 1, len 100 is a hundred of one byte), so a bulk move would be wrong.
   ; 1 for the clean end, never 0 -- the caller asks `(! r)`, and 0 is nothing.
   ; the room is taken once, before the loop, so the cask cannot be replaced
   ; under it and the walk holds `c` and the write cursor in hand -- two tablet
   ; reads for the whole match instead of nine per byte. the copy stays byte by
   ; byte: deflate lets a run overlap its own source and a bulk move would be wrong.
   (gz-copy b dist len)
    (: _ (gz-room b len)
       c (peep b 0 0)
       (go k p) (? (len <= k) (pin b 1 p, 1)
                   (p < dist) (pin b 1 p, ())         ; a reach before the start
                   (pin c p (peep c (p - dist) 0), go (k + 1) (p + 1)))
       (go 0 (peep b 1 0)))

   ; --- the bit source -------------------------------------------------------
   ; the cursor is a tablet again: 0 the bit position, 1 the torn flag. reading past
   ; the end sets torn and answers 0 rather than scaring, so a torn stream unwinds
   ; through the ordinary return path and the caller reads presence at the end.
   (gz-bit s n t)
    (peep t 0 0 @ p
       (n <= p >> 3 ? (pin t 1 1, 0)
          (pin t 0 (p + 1), s (p >> 3) >> (p & 7) & 1)))
   ; the position rides a local, read once and written back once. `gz-bit` pays a
   ; peep and a pin per bit because the cursor is a tablet, and a deflate stream is
   ; twenty-seven million bits -- so the cursor is taken in hand for the length of a
   ; run and put back at the end. the semantics are gz-bit's exactly, torn flag and
   ; all: past the end sets torn, answers a 0 bit, and does not advance.
   (gz-bits s n t k)
    (: (go i a p)
        (k <= i ? (pin t 0 p, a)
           (n <= p >> 3 @ over
              ((over ? (pin t 1 1) 0),
               go (i + 1) (over ? a (a | (s (p >> 3) >> (p & 7) & 1) << i))
                  (over ? p (p + 1)))))
       (go 0 0 (peep t 0 0)))

   ; --- canonical Huffman, built from code lengths --------------------------
   ; the shape is puff's: a count of codes per length and the symbols in canonical
   ; order. decoding walks one bit at a time -- no lookup table, which is slower per
   ; symbol and is the whole of the algorithm rather than an index over it.
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
   ; ..and the decode walks up to fifteen bits for one symbol, which is where the
   ; per-bit cursor cost lands hardest -- so it takes the position in hand too, and
   ; writes it back on every way out, the failing one included.
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

   ; the dynamic block's own code, read as code lengths through a third Huffman code
   ; -- the one place the format describes itself. 16/17/18 are runs, and 16 repeats
   ; the previous length, so the walk carries it.
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
          ; the distance lengths sit after the literal ones in the same run, and
          ; gz-huff counts from 0, so they are carried down into a table of their own.
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
   ; src/love/lib/gz.c's, gz-puff wherever it declines -- a torn stream declines, so a torn one
   ; is read twice and answers () both times. `string?`, never `?`: a string of NULs sums to
   ; zero and would read as absent.
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

   ; the header's optional fields are four flags, and every one of them must be
   ; stepped over even though we write none of them -- the far side is gzip, and
   ; `gzip -N` writes a name. ftext (bit 0) carries no bytes.
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
             ; `pour`'s last argument is a count, not an end offset, and the nif
             ; clamps it to the shorter of the two arrays -- so an end offset can
             ; answer right off the destination's size alone, silently, and move
             ; the whole tail to do it. spell the count.
             body (cask (n - i4 - 8) @ c (pour c 0 s i4 (n - i4 - 8), string c))
             r (gz-inflate body isize)
             out <>r
             ; the trailer is the whole point of the container: a stream
             ; that inflated cleanly and hashes wrong is a corrupt one,
             ; and saying so is the only thing the crc is for.
             (? (r = 'big) 'big
                r (gz-crc32 out = crc && #out = isize & 4294967295 && [1 out])))))

   ; --- the container, streamed ---------------------------------------------
   ; (gz-pull rd) is a reader over the members: (gz-next g) answers the next piece inflated,
   ; "" once the stream is done, and then g's 'ans says how it ended. nothing holds a whole
   ; member: the header is read as far as it runs, the body fed as it comes with the crc
   ; carried on, and each trailer checked where its member ends. members that follow are read
   ; on, as gzip reads `cat a.gz b.gz`; bytes behind the last that are no member are 'trail.
   ; 'ans: (1 stamp name n seat) of the first header and every byte out | ('trail ..) |
   ; 'nogz a first header that is not one | () torn or a crc wrong | 'big
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
   ; the same members written out: mk (stamp name) of the first header answers (1 w), w
   ; the writer every piece goes through, or () for 'no. what came out before a failure
   ; came out.
   (gz-unzipf rd mk)
    (: g (gz-pull rd)   p (gz-next g)   hd (peep g 'hd ())
       (!(two? hd) ? (peep g 'ans ())
          (mk (hd 0) (hd 1) @ m
             (!(two? m) ? 'no
                (: w <>m
                   (go p) (#p = 0 ? (peep g 'ans ()) (w p, go (gz-next g)))
                   (go p)))))))

) ; module 'gz

; --- the face -----------------------------------------------------------------------
; `love gzip`, `love gunzip` and `love zcat`: GNU's flag spelling over the two doors
; above. the module above is the codec; this one is the face -- the options, the suffix
; rules, and the in-place replace that carries the mode and the mtime across.
;
;   gzip [-cdfklnNqrtv] [-1..-9] [-S suf] [file..]    file.gz written, file removed
;   gunzip [..]  = gzip -d          zcat [..] = gzip -dc
;   -c stdout   -d decompress   -f overwrite an existing output   -k keep the input
;   -l list     -n write no name or time into the header   -N take both back out of it
;   -q quiet    -r walk directories   -t test only   -v say what happened   -S suf
;
; no file (or a bare `-`) is the filter: stdin -> stdout, which is what a pipe wants.
; a status like GNU's: 0 clean, 1 something failed, 2 a warning (a name refused).
;
; decompressing streams through gz-unzipf: a piece of the file at a time, out as it inflates,
; so no member is held whole. members that follow are read on (`cat a.gz b.gz`), a tail that
; is no member is GNU's warning and a 2, and a file whose crc fails loses its partial output.
; compressing still reads the file whole. -9 (--best) deflates harder, a lazy parse down a
; long chain; the other levels are taken and change nothing -- the coder costs every block
; three ways and writes the cheapest, which is one level.
;
; -l's ratio is the deflate payload's and not the file's, GNU taking the header and the
; trailer out before it divides, which is why a small file lists a ratio its bytes on
; disk do not show. the (totals) row is ours: GNU's own adds the first file's whole size
; to the others' payloads.
;
; gz rides module 'gz, so the codec's names are asked for and the ask lands in a layer
; of our own rather than on the dist cat's shared one.
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

   ; --- one file, decompressed (and -t, which is the same read and no write) --
   ; the members stream from the file to the output a piece at a time, so a member's size is
   ; no one's memory. the output is named, and opened, once the header says what it is (-N
   ; takes its name from there); a stream that fails partway takes the partial output away.
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
       ; the suffix is asked before the bytes are: a name with nothing to strip is a
       ; warning and not an error, so a `gunzip *` over a mixed directory walks on --
       ; reading first would call every plain file "not in gzip format" instead
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
                   ; without -N the output keeps the .gz's own mtime and not the one in
                   ; the header: gzip restores the stored stamp only when asked, which is
                   ; what -N means on this side
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
   ; the cli walker in gnu order: clustered shorts, the long names beside them, and -S's
   ; suffix glued or next. a digit is a level and not a flag: the last one said is kept, and
   ; only 9 (or --best) changes anything -- the harder coder
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
