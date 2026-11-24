; test/host/deflate.l -- deflate streams written off src/love/compress/deflate.l: each symbol and header
; shape, and near misses per refusal. the reference decoder, gz-puff, `inflate` and `inflate-feed` read
; them all; what the tokens mean, worked out apart from any decoder, is the answer.
; run: cat test/00-init.l test/host/deflate.l | out/love
(borrow '(gz hashes))
(borrow "src/love/compress/deflate.l")

(: ; --- the writer: a sink is {'j jug 'a acc 'n bits} ---
   (dw-new _) {'j (jug 0) 'a 0 'n 0}
   (dw-put w v k)
    (: (go a n) (n < 8 ? (pin w 'a a, pin w 'n n, w) (put (w 'j) (a & 255), go (a >> 8) (n - 8)))
       (go (w 'a | (v & (1 << k) - 1) << w 'n) (w 'n + k)))
   (dw-code w c) (: (go i) (i < 0 ? w (dw-put w (c 1 >> i & 1) 1, go (i - 1))) (go (c 2 - 1)))
   (dw-end w) (w 'n ? (dw-put w 0 (8 - w 'n), slurp (w 'j)) (slurp (w 'j)))
   (dw-field w f v) (dw-put w (v - f 2) (f 1))
   ; symbol -> [symbol code length]
   (dw-tab lens) (foldl (\ t r (pin t (r 0) r)) {} (df-canon lens))

   ; --- a block: [kind ..]. a token is a symbol, [lsym lextra dsym dextra], or ['raw v k] ---
   (dw-head w last type) (dw-field w (df-head 0) last, dw-field w (df-head 1) type)
   (dw-stored w last pad t nl)
    (dw-head w last 0, (w 'n ? (dw-put w pad (8 - w 'n))),
     dw-field w (df-stored 0) #t, dw-field w (df-stored 1) (? (nl < 0) (65535 - #t) nl), each t (b \ dw-put w b 8), w)
   (dw-toks w lit dist ts)
    (each ts (t \ (? (charm? t) (dw-code w (lit t))
                     (t 0 == 'raw) (dw-put w (t 1) (t 2))
                     (: r (df-lent (t 0 - 257)) e (df-distt (t 2))
                        (dw-code w (lit (t 0)), dw-put w (t 1) (r 1), dw-code w (dist (t 2)), dw-put w (t 3) (e 1))))), w)
   (dw-fixed w last ts) (dw-head w last 1, dw-toks w (dw-tab df-flit) (dw-tab df-fdist) ts)
   ; n symbols' lengths, complete: the first few a bit shorter
   (dw-flat n) (: (lg k) (? (1 << k < n) (lg (k + 1)) k) k (lg 0) s ((1 << k) - n)
                (? (n = 1) [1] (map (i \ (? (i < s) (k - 1) k)) ^n)))
   ; lengths over alphabet m: syms in order take ls
   (dw-over m syms ls) (: t (foldl (\ t p (pin t <p >p)) {} (zip syms ls)) (map (i \ peep t i 0) ^m))
   (dw-flatover m syms) (dw-over m syms (dw-flat #syms))
   ; a dynamic block. ops: code-length symbols as [symbol count]; cl: the 19 lengths, or () for a
   ; complete code over what ops use; hc: hclen, or 0 for the least
   (dw-cl ops hc)
    (: use (foldl (\ t o (pin t (o 0) 1)) {} ops)
       _ (? hc (pin use (df-clord (hc - 1)) 1) 0)
       ks (filter (i \ peep use i 0) ^19)
       ks2 (? (#ks < 2) (sort (<(filter (i \ !(peep use i 0)) df-clord) . ks)) ks)
     (dw-flatover 19 ks2))
   (dw-hc cl) (: (go k) (? (k < 5) 4 (cl (df-clord (k - 1))) k (go (k - 1))) (go 19))
   (dw-dynhead w last hl hd ops cl hc)
    (: c (dw-tab cl)  k (? hc hc (dw-hc cl))
     (dw-head w last 2, dw-field w (df-dyn 0) hl, dw-field w (df-dyn 1) hd, dw-field w (df-dyn 2) k,
      each ^k (i \ dw-put w (cl (df-clord i)) df-clbits),
      each ops (o \ (dw-code w (c (o 0)), (? (15 < o 0) (: r (dw-op (o 0)) (dw-put w (o 1 - r 3) (r 2))) 0))), w))
   (dw-op v) (<(filter (o \ <o = v) df-clops))
   (dw-ops lens) (map (l \ [l 1]) lens)
   ; the same lengths through the repeats, greedily
   (dw-rle lens)
    (: (run l k) (? (two? l && <l = k) (1 + run >l k) 0)
       (go l prev)
        (? !(two? l) ()
           (: v <l n (run l v)
            (? (v = 0 && 10 < n) (: k (min n 138) ([18 k] . go (drop k l) 0))
               (v = 0 && 2 < n) ([17 n] . go (drop n l) 0)
               (v = prev && 2 < n) (: k (min n 6) ([16 k] . go (drop k l) v))
               ([v 1] . go >l v))))
       (go lens -1))
   (dw-dynx w last ll dl ops cl hc ts)
    (dw-dynhead w last #ll #dl ops cl hc, dw-toks w (dw-tab ll) (dw-tab dl) ts)
   (dw-dyn w last ll dl ts) (: ops (dw-rle (ll + dl)) (dw-dynx w last ll dl ops (dw-cl ops 0) 0 ts))
   ; --- what tokens mean ---
   (dw-mean o ts)                                         ; o a list, newest first
    (foldl (\ o t (? (charm? t) (t < 256 ? (t . o) o)
                     (: r (df-lent (t 0 - 257)) e (df-distt (t 2)) n (r 0 + t 1) d (e 0 + t 3)
                        (go o n) (n ? (go (o (d - 1) . o) (n - 1)) o)
                      (go o n)))) o ts)
   (dw-str o) (: n #o c (cask n) (go o i) (two? o ? (pin c i <o, go >o (i - 1)) (string c)) (go o (n - 1)))

   ; --- what the decoders say ---
   dw-seen {}
   (dw-see k v) (pin dw-seen k (pin (tablet? (dw-seen k) ? (dw-seen k) {}) v 1), 0)
   (dw-saw k l) (: t (dw-seen k) (tablet? t ? (all (v \ peep t v 0) l) 0))
   dw-cap 140000
   ; the C: one shot, and fed in pieces, the empty one last
   (dw-feed s)
    (: st (inflate-new 0)  n #s
       (go i ks acc)
        (: k <ks  r (inflate-feed st (i < n ? (snip s i (min n (i + k))) ""))
         (? (two? r) (cats (rev (<r . acc))) !(string? r) 'no (n <= i) 'no (go (i + k) (>ks + [k]) (r . acc))))
     (go 0 '(1 9 4000 2 300) ()))
   (dw-c s) (inflate s 0 @ r (string? r ? r 'no) @ a (a = dw-feed s ? a 'split))
   (dw-p s) (gz-puff s 0 @ r (two? r ? <>r 'no))
   ; a stream and its meaning: all three say it, its bytes used to the last
   (dw-good s want)
    (: r (df-run s dw-cap () dw-see)
     (? !(r = [1 want (r 2)]) 0 !(r 2 + 7 >> 3 = #s) 0 !(dw-c s = want) 0 !(dw-p s = want) 0 1))
   ; a refusal by name: the decoders refuse it too, unless the name is let by; then they read what
   ; the reference does with it let by, and an over code's meaning is nobody's
   dw-overs '(cl-over lit-over dist-over)
   dw-mild (filter (n \ !(elem n dw-overs)) df-lenient)
   (dw-bad why s)
    (: r (df-decode s dw-cap)  q (df-run s dw-cap dw-mild (_ \ _ \ 0))
     (? !(r = [0 why]) 0
        !(dw-c s = dw-p s) 0
        (q 0) (dw-c s = q 1)
        (elem (q 1) dw-overs) 1
        (dw-c s = 'no)))
   (dw-all f l) (: bad (filter (x \ !(f x)) l) (two? bad ? (puts "deflate: \(#bad) of \(#l): \(show <<bad)\n", 0) 1))
   dw-ok (dw-all (p \ p @ [nm s want] (dw-good s want)))
   dw-no (dw-all (p \ p @ [why s] (dw-bad why s)))

   ; --- valid streams, [name stream meaning] ---
   E 256
   (dw-one nm f) (: w (dw-new 0) o (f w) [nm (dw-end w) (dw-str o)])
   ; a block's lengths, for the tokens it holds
   (dw-syms ts) (: t (foldl (\ a x (charm? x ? (pin a x 1) (pin a (x 0) 1))) {E 1} ts) (filter (i \ peep t i 0) ^286))
   (dw-dsyms ts) (: t (foldl (\ a x (charm? x ? a (pin a (x 2) 1))) {} ts) (filter (i \ peep t i 0) ^30))
   (dw-ll ts) (: y (dw-syms ts) (dw-flatover (max 257 (1 + last y)) (1 < #y ? y [0 E])))
   (dw-dl ts) (: y (dw-dsyms ts) (two? y ? (dw-flatover (1 + last y) y) [0]))
   (dw-auto nm ts) (dw-one nm (w \ (dw-dyn w 1 (dw-ll ts) (dw-dl ts) (ts + [E]), dw-mean () ts)))
   (dw-autof nm ts) (dw-one nm (w \ (dw-fixed w 1 (ts + [E]), dw-mean () ts)))
   ; each length symbol with each extra, distance 1
   dw-lensyms (catmap (i \ map (x \ [(257 + i) x 0 0]) ^(1 << df-lent i 1)) ^29)
   (dw-ends r) (? (r 1) [0 ((1 << r 1) - 1)] [0])
   dw-v1 [(dw-auto "lens dyn" (65 . dw-lensyms)) (dw-autof "lens fixed" (65 . dw-lensyms))]
   ; each distance symbol at its least and most, behind 32768 stored bytes
   dw-noise (map (i \ i * 2654435761 >> 13 & 255) ^32768)
   dw-hist (rev dw-noise)
   dw-distsyms (catmap (i \ map (x \ [257 0 i x]) (dw-ends (df-distt i))) ^30)
   dw-v2 [(dw-one "dists dyn" (w \ (dw-stored w 0 0 dw-noise -1, dw-dyn w 1 (dw-ll dw-distsyms) (dw-dl dw-distsyms) (dw-distsyms + [E]),
                                    dw-mean dw-hist dw-distsyms)))
          (dw-one "dists fixed" (w \ (dw-stored w 0 0 dw-noise -1, dw-fixed w 1 (dw-distsyms + [E]), dw-mean dw-hist dw-distsyms)))]
   ; every byte, fixed and dynamic
   dw-v3 [(dw-auto "bytes dyn" ^256) (dw-autof "bytes fixed" ^256) (dw-auto "empty dyn" ()) (dw-autof "empty fixed" ())]
   ; hclen: a code of 8-bit lengths alone, then the last sent length at each place
   dw-l8 (map (i \ 0 < i ? 8 0) ^257)
   dw-v4 (map (k \ dw-one "hclen \(k)" (w \ (: ops (dw-rle (dw-l8 + [0])) (dw-dynx w 1 dw-l8 [0] ops (dw-cl ops k) k [65 66 E], [66 65]))))
              (map (+ 5) ^15))
   ; hlit and hdist at each value, the last length a real one
   (dw-lastsym m) (map (i \ (? (i = 65) 2 (i = E) 2 (i = m - 1) 1 0)) ^m)
   dw-v5 (map (m \ dw-one "hlit \(m)" (w \ (dw-dyn w 1 (dw-lastsym m) [1] [65 E], [65]))) (map (+ 258) ^29)
          + map (m \ dw-one "hdist \(m)" (w \ (dw-dyn w 1 (dw-flatover 258 [65 E 257]) (map (i \ (? (i = m - 1) 1 0)) ^m) [65 E], [65]))) (map (+ 1) ^30)
          + [(dw-one "hlit 257" (w \ (dw-dyn w 1 (dw-flatover 257 [65 E]) [1] [65 E], [65])))])
   ; the deepest codes: 1 2 .. 14 15 15, each code's and the code lengths' own 1 .. 6 7 7
   (dw-deep n) (map (+ 1) ^(n - 1) + [(n - 1)])
   dw-v6 [(: ts (map (+ 65) ^14 + [[257 0 0 0] [257 0 15 63]] + map (+ 65) ^14)
             pre (map (i \ i & 255) ^400)
           (dw-one "deep" (w \ (dw-stored w 0 0 pre -1,
             dw-dyn w 1 (dw-over 258 (map (+ 65) ^14 + [E 257]) (dw-deep 16)) (dw-over 30 (0 . 15 . map (+ 16) ^14) (rev (dw-deep 16))) (ts + [E]),
             dw-mean (rev pre) ts))))
          ; 1 2 3 .. as the code-length code: the lengths 0 to 6 and 8 spell dw-l8's kin
          (: ll (dw-flatover 258 [65 66 67 E 257]) ops (dw-ops (ll + [1]))
             cl (dw-over 19 [0 2 3 1 4 5 6 7] (dw-deep 8))
           (dw-one "deep cl" (w \ (dw-dynx w 1 ll [1] ops cl 0 [65 66 67 [257 0 0 0] E], dw-mean () [65 66 67 [257 0 0 0]]))))]
   ; one distance code, of one bit, at each symbol that 400 bytes reach; and each repeat's ends
   dw-v7 (map (i \ dw-one "lone dist \(i)" (w \ (: pre (map (i \ i & 255) ^40000) t [257 0 i 0]
                (dw-stored w 0 0 pre -1, dw-dyn w 1 (dw-flatover 258 [65 E 257]) (map (j \ (? (j = i) 1 0)) ^30) [65 t E], dw-mean (65 . rev pre) [t]))))
              [0 1 4 15 29])
   ; ops that spell ll then dl, as given: the repeats at both ends, and a 16 and an 18 across the seam
   (dw-spell ops) (: (go p o) (two? o ? (: x <o v (x 0) n (x 1) u (? (v < 16) v (v = 16) p 0)
                                          (map (_ \ u) ^n + go u >o)))
                    (go 0 ops))
   (dw-seam nm nl ops ts m)
    (: all2 (dw-spell ops)
     (dw-one nm (w \ (dw-dynx w 1 (take nl all2) (drop nl all2) ops (dw-cl ops 0) 0 ts, m))))
   dw-v8 [(dw-seam "16 across" 258 [[18 65] [2 1] [2 1] [18 138] [18 51] [2 1] [16 5]] [65 E] [65])
          (dw-seam "16 of 6" 264 [[18 138] [18 118] [3 1] [16 6] [3 1] [3 1] [16 3] [16 4]] [E] ())
          (dw-seam "18 across" 280 [[18 65] [1 1] [18 138] [18 52] [1 1] [17 10] [17 3] [17 3] [17 3] [18 11] [1 1] [1 1]] [65 E] [65])
          (dw-seam "18 of 11" 257 [[18 11] [18 138] [18 106] [1 1] [1 1] [1 1]] [255 E] [255])]

   ; --- random streams ---
   dw-rs {'s 20261123}
   (rnd n) (: x ((dw-rs 's * 1103515245 + 12345) & 2147483647) _ (pin dw-rs 's x) ((x >> 8) % n))
   ; m complete lengths, none past mx
   (dw-split m mx)
    (: (go ls m) (m < 1 ? ls
                  (: i (rnd #ls) l (ls i)
                   (? (l < mx) (go (take i ls + [(l + 1) (l + 1)] + drop (i + 1) ls) (m - 1)) (go ls m))))
       (? (m = 1) [1] (go [0] (m - 1))))
   (dw-rover m syms mx) (dw-over m syms (dw-split #syms mx))
   (dw-rtoks n have)
    (n < 1 ? ()
     (: k (rnd 3)
      (? (k || have < 1) (: b (rnd 40) ((b * 6) . dw-rtoks (n - 1) (have + 1)))
         (: ls (rnd 29) rl (df-lent ls) lx (rnd (1 << rl 1))
            ds (rnd #(filter (e \ e 0 <= have) df-distt)) rd (df-distt ds) dx0 (rnd (1 << rd 1))
            dx (min dx0 (have - rd 0))
          ([(257 + ls) lx ds dx] . dw-rtoks (n - 1) (have + rl 0 + lx))))))
   (dw-rcl ops)
    (: u0 (foldl (\ t o (pin t (o 0) 1)) {} ops)
       k (rnd 19) _ (pin u0 k 1)  k2 (rnd 18) _ (pin u0 ((k + 1 + k2) % 19) 1)
       (dw-rover 19 (filter (i \ peep u0 i 0) ^19) 7))
   (dw-rblock w last o)
    (: kind (rnd 4) nt (rnd 60) have #o
     (? (kind = 0) (: ts (map (_ \ rnd 256) ^nt) pad (rnd 128) _ (dw-stored w last pad ts -1) (dw-mean o ts))
        (kind = 1) (: ts (dw-rtoks nt have) _ (dw-fixed w last (ts + [E])) (dw-mean o ts))
        (: ts (dw-rtoks nt have)  ys (dw-syms ts) ds (dw-dsyms ts)
           l0 (max 257 (1 + last-of ys)) l1 (rnd (287 - l0)) hl (l0 + l1)
           d0 (? (two? ds) (1 + last-of ds) 1) d1 (rnd (31 - d0)) hd (d0 + d1)
           ll (dw-rover hl ys 15)  dl (? (two? ds) (dw-rover hd ds 15) (map (_ \ 0) ^hd))
           plain (rnd 2)
           ops (? plain (dw-ops (ll + dl)) (dw-rle (ll + dl)))
           cl (dw-rcl ops)  h0 (dw-hc cl) h1 (rnd (20 - h0))
           _ (dw-dynx w last ll dl ops cl (h0 + h1) (ts + [E]))
         (dw-mean o ts))))
   (last-of l) (last l)
   (dw-rand i) (dw-one "random \(i)" (w \ (: nb (rnd 4) (go k o) (: o2 (dw-rblock w (? (k = nb) 1 0) o) (? (k = nb) o2 (go (k + 1) o2))) (go 0 ()))))
   dw-vr (map dw-rand ^300)

   ; --- one near miss and more per refusal, [why stream] ---
   (dw-w f) (: w (dw-new 0) _ (f w) (dw-end w))
   L3 (dw-flatover 258 [65 66 E 257])
   (dw-d ll dl ts) (dw-w (w \ dw-dyn w 1 ll dl ts))
   (dw-x ll dl ops cl ts) (dw-w (w \ dw-dynx w 1 ll dl ops cl 0 ts))
   (dw-f ts) (dw-w (w \ dw-fixed w 1 ts))
   (dw-set l i v) (map (j \ (? (j = i) v (j < #l) (l j) 0)) ^(max #l (i + 1)))
   dw-misses
    (map (p \ ['torn (snip (p 1) 0 (#(p 1) - 1))]) (filter (p \ #(p 1) < 400) (dw-v3 + dw-v4 + dw-v8 + take 60 dw-vr))
     + [['type (dw-w (w \ dw-put (dw-head w 1 3) 0 40))]
        ['torn ""] ['nlen (dw-w (w \ dw-stored w 1 0 [1 2 3] 65533))] ['nlen (dw-w (w \ dw-stored w 1 0 () 0))]
        ['hlit (dw-d (dw-set (dw-set L3 286 0) 66 2) [1] [65 E])] ['hlit (dw-d (dw-flatover 288 [65 66 E 287]) [1] [65 E])]
        ['hdist (dw-d L3 (dw-set [1] 30 1) [65 E])] ['hdist (dw-d L3 (dw-set [1] 31 1) [65 [257 0 0 0] E])]
        ['hdist (dw-d L3 (dw-set [1] 30 1) [65 257 ['raw 1 1] E])] ['hdist (dw-d L3 (dw-set [1] 31 1) [65 257 ['raw 1 1] E])]
        ['hlit (dw-d (dw-flatover 287 [65 66 E 286]) [1] [65 286 ['raw 0 1] E])] ['hlit (dw-d (dw-flatover 288 [65 66 E 287]) [1] [65 287 ['raw 0 1] E])]
        ['cl-short (dw-x L3 [1] (dw-ops (L3 + [1])) (dw-over 19 [0 1 2] [2 2 2]) [65 E])]
        ['cl-short (dw-x L3 [1] (dw-ops (L3 + [1])) (dw-over 19 [0 1 2] [7 7 7]) [65 E])]
        ['cl-over (dw-x L3 [1] (dw-ops (L3 + [1])) (dw-over 19 [0 1 2 3] [1 2 2 2]) [65 E])]
        ['rep-first (dw-x L3 [1] ([16 3] . dw-ops (drop 3 L3 + [1])) (dw-cl ([16 1] . dw-ops (L3 + [1])) 0) [65 E])]
        ['rep-past (dw-x L3 [1 0] (dw-ops L3 + [[1 1] [18 11]]) (dw-cl ([18 11] . dw-ops (L3 + [1])) 0) [65 E])]
        ['rep-past (dw-x L3 [2 2 2 2] (dw-ops L3 + [[2 1] [16 6]]) (dw-cl ([16 3] . dw-ops L3) 0) [65 [257 0 0 0] E])]
        ['rep-past (dw-x L3 [1 0 0] (dw-ops L3 + [[1 1] [17 3]]) (dw-cl ([17 3] . dw-ops (L3 + [1])) 0) [65 E])]
        ['rep-past (dw-x L3 [0] (dw-ops L3 + [[17 3]]) (dw-cl ([17 3] . dw-ops L3) 0) [65 E])]
        ['noend (dw-d (dw-flatover 257 [65 66]) [1] [65 66])]
        ['lit-over (dw-d (dw-set L3 67 2) [1] [65 E])] ['lit-over (dw-d (dw-over 257 [65 66 E] [1 1 1]) [1] [65 E])]
        ['lit-short (dw-d (dw-set L3 66 0) [1] [65 E])] ['lit-short (dw-d (dw-over 257 [65 E] [15 15]) [1] [65 E])]
        ['lit-short (dw-d (dw-over 257 [E] [2]) [1] [E])]
        ['dist-over (dw-d L3 [1 1 1] [65 E])] ['dist-over (dw-d L3 [1 1 15] [65 [257 0 0 0] E])]
        ['dist-short (dw-d L3 [2] [65 [257 0 0 0] E])] ['dist-short (dw-d L3 [2 2 2] [65 [257 0 0 0] E])]
        ['nocode (dw-d L3 [1] [65 257 ['raw 65535 16] E])] ['nocode (dw-d L3 [0] [65 257 ['raw 0 16] E])]
        ['nocode (dw-d (dw-over 257 [E] [1]) [1] [['raw 65535 16]])]
        ['sym (dw-f [65 286 ['raw 0 5] E])] ['sym (dw-f [65 287 ['raw 0 5] E])]
        ['dsym (dw-f [65 257 ['raw 15 5] E])] ['dsym (dw-f [65 257 ['raw 31 5] E])]
        ['far (dw-f [[257 0 0 0] E])] ['far (dw-f [65 [257 0 1 0] E])] ['far (dw-d (dw-flatover 258 [65 E 257]) (dw-set [1] 29 1) [65 [257 0 29 8191] E])]])
   ; a bit flipped anywhere: whatever the reference says of it, the decoders say
   (dw-flip s i) (: b (cask #s) _ (pour b 0 s 0 #s) k (i >> 3) (pin b k (s k ^ 1 << (i & 7)), string b))
   (dw-any s) (: r (df-decode s dw-cap) (? (r 0) (dw-c s = r 1 && dw-p s = r 1) (r 1 == 'cap) 1 (dw-bad (r 1) s)))
   dw-small (map (p \ p 1) (filter (p \ #(p 1) < 120) (dw-v3 + dw-v4 + dw-v5 + dw-v8 + dw-vr)))
   dw-flips (catmap (s \ map (_ \ (: i (rnd (8 * #s)) (dw-flip s i))) ^12) dw-small)
   (dw-set? l) (sort (keys (foldl (\ t x (pin t x 1)) {} l))))

(test
 (dw-ok (dw-v1 + dw-v2 + dw-v3 + dw-v4))
 (dw-ok (dw-v5 + dw-v6 + dw-v7 + dw-v8))
 (dw-ok dw-vr)
 (dw-no dw-misses)
 (dw-all dw-any dw-flips))

; what the valid streams used: every symbol, width, count and edge
(test
 (dw-saw 'lit ^286) (dw-saw 'dist ^30) (dw-saw 'cl ^19) (dw-saw 'bits (map (+ 1) ^15))
 (dw-saw 'len (map (+ 3) ^256)) (dw-saw 'far [1 32768])
 (dw-saw 'hlit (map (+ 257) ^30)) (dw-saw 'hdist (map (+ 1) ^30)) (dw-saw 'hclen (map (+ 5) ^15))
 (dw-saw 'rep [(16 . 3) (16 . 6) (17 . 3) (17 . 10) (18 . 11) (18 . 138)]) (dw-saw 'cross [16 18])
 ; each refusal has its near miss, and what is let by is still let by
 (dw-set? df-refusals = dw-set? (map cap dw-misses))
 (dw-set? df-lenient = dw-set? (map cap (filter (p \ !(dw-c (p 1) = 'no)) dw-misses))))

; gz.l's tables are its own
(: (dw-tray t l) (map (i \ peep t i -1) ^(1 + #l) = l + [-1])
 (test
  (dw-tray gz-lbase (map cap df-lent)) (dw-tray gz-lext (map (r \ r 1) df-lent))
  (dw-tray gz-dbase (map cap df-distt)) (dw-tray gz-dext (map (r \ r 1) df-distt))
  (dw-tray gz-clord df-clord) (dw-tray gz-fixlenl df-flit)
  (dw-tray gz-fixlend (take df-hdist df-fdist))))

(test_fin (), puts "deflate: ok -- every decoder reads the streams as the format says\n", 0)
