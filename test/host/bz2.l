; test/host/bz2.l -- bz2-pull, a block at a time, held to bz2-unpack of the whole
; an error word is compared alone: the pull has put out the blocks before it. bz2-zip, fed in
; any cut, lays bz2-pack's bytes
; run: cat test/00-init.l test/host/bz2.l | out/love
(borrow '(bz2 bytes hashes))

(: (bzt-mk n f) (: b (cask n) (go i) (n <= i ? (string b) (pin b i (f i), go (i + 1))) (go 0))
   (bzt-cut s k) (: n #s (go i) (n <= i ? () ((snip s i (min n (i + k))) . go (i + k))) (go 0))
   (bzt-rd ps) ({0 ps} @ t (_ \ (peep t 0 () @ l (two? l ? (pin t 0 >l, <l) ""))))
   (bzt-pull s k) (: g (bz2-pull (bzt-rd (bzt-cut s k)))
                     (go acc) (bz2-next g @ p (#p = 0 ? [(g 'ans) (two? acc ? (cats (rev acc)) "")] (go (p . acc))))
                     (go ()))
   (bzt-whole s) (bz2-unpack s @ u (atom? u ? [u ""] [[1 #<>u] <>u]))
   (bzt-all f xs) (foldl (a \ x \ (a && f x)) 1 xs)
   (bzt-same s ks) (bzt-whole s @ w
                      (bzt-all (k \ (bzt-pull s k @ p (atom? <w ? (<p = <w) (p = w)))) ks))
   bzt-ks [1 7 4096 100000]
   bzt-text (: (go i a) (i < 1 ? a (go (i - 1) (a + "the quick brown fox jumps over the lazy dog. "))) (go 3000 ""))
   bzt-a (bz2-pack bzt-text 1)
   ; noise: blocks run past the pull's buffer and are read again
   bzt-noise (cats (map (i \ hex2b (sha256 (show i))) (jot 80000)))
   bzt-n (bz2-pack bzt-noise 1)
   (bzt-flip s k) (cask #s @ c (pour c 0 s 0 #s, pin c k (s k ^ 1), string c))
   (bzt-zip s k l) (: o {0 ()}
                      z (bz2-zip (bzt-rd (bzt-cut s k)) l (b \ pin o 0 (b . o 0)))
                      (two? z ? (cats (rev (o 0))) ()))
   (bzt-zips s k l) (bzt-zip s k l = bz2-pack s l)
   ; runs of 700 and 300: a run cut by a feed, one past 255
   bzt-runs (bzt-mk 30000 (i \ (97 + i // 700 % 3 + (i % 1000 < 300 ? 3 0)))))
(test
 (lit? bz2-step)
 (bzt-same bzt-a bzt-ks)
 (bzt-same (bz2-pack bzt-text 9) bzt-ks)
 (bzt-same (bz2-pack "" 9) bzt-ks)
 (bzt-same bzt-n [4096 65536])
 ; concatenated, trailing junk, not bzip2
 (bzt-same (bzt-a + bz2-pack "second" 3) bzt-ks)
 (bzt-same (bzt-a + "junk") bzt-ks)
 (bzt-same "hello, not bzip2" bzt-ks)
 ; a block of zeros runs to megabytes: it reads out in pieces, a run of four past the mark at most
 (: z (string (cask 8388608))
    g (bz2-pull (bzt-rd [(bz2-pack z 1)]))
    (go n k big) (bz2-next g @ p (#p = 0 ? [n k big (g 'ans)] (go (n + #p) (k + 1) (max big #p))))
    ((go 0 0 0) @ [8388608 (k && 7 < k) (b && b <= 1048576 + 256) [1 8388608]] 1 _ 0))
 ; streamed: several blocks, any cut, runs across the cuts, nothing at all
 (bzt-all (k \ bzt-zips (snip bzt-noise 0 250000) k 1) [4096 100000 300000])
 (bzt-all (k \ bzt-zips bzt-runs k 1) [1 7 256 4096])
 (bzt-zips (bzt-text + bzt-runs) 999 9)
 (bzt-zips "" 7 9)
 (bz2e-new 0 = ())
 (: st (bz2e-new 1)   _ (bz2e-end st) (bz2e-feed st "x" = ()))
 ; truncated, and bit flips
 (: (go i) (? (#bzt-a <= i) 1 !(bzt-same (snip bzt-a 0 i) [7 4096]) 0 (go (i + 17))) (go 0))
 (: (go i) (? (#bzt-a <= i) 1 !(bzt-same (bzt-flip bzt-a i) [7 4096]) 0 (go (i + 11))) (go 0)))

(test_fin (), puts "bz2: ok -- every cut of a stream reads as the whole does\n", 0)
