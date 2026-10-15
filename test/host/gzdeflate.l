; test/host/gzdeflate.l -- the love deflate coder, the oracle src/love/compress/gz.c's
; deflate is held to byte for byte (test/host/gzc.l). greedy LZ77 in 16k-symbol blocks, each
; written the cheapest of stored, fixed or dynamic huffman. it splices into module 'gz:
;   (borrow 'gz) (borrow "test/host/gzdeflate.l"), then (gz-deflatel s) -> raw deflate bytes
(module 'gz
(borrow 'bytes)
(borrow 'hashes)
(:
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
   (gz-clx sy) (sy @ 16 2 17 3 18 7 0)
   (gz-trim lens k lo) (? (k <= lo) lo (peep lens (k - 1) 0) k (gz-trim lens (k - 1) lo))
   ; the block's own code lengths, run-length coded before a third huffman code: 16 repeats
   ; the previous length three to six times, 17 and 18 are runs of zero, three to ten and
   ; eleven to a hundred and thirty-eight. a value is spelled once before 16 may repeat it
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
)
) ; module 'gz
