; test/host/bz2.l -- bz2-pull, a block at a time, held to bz2-unpack of the whole
; an error word is compared alone: the pull has put out the blocks before it
; run: cat test/00-init.l test/host/bz2.l | out/love
(borrow 'bz2)
(borrow 'bytes)
(borrow 'hashes)

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
   (bzt-flip s k) (cask #s @ c (pour c 0 s 0 #s, pin c k (s k ^ 1), string c)))
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
 ; truncated, and bit flips
 (: (go i) (? (#bzt-a <= i) 1 !(bzt-same (snip bzt-a 0 i) [7 4096]) 0 (go (i + 17))) (go 0))
 (: (go i) (? (#bzt-a <= i) 1 !(bzt-same (bzt-flip bzt-a i) [7 4096]) 0 (go (i + 11))) (go 0)))

(test_fin (), puts "bz2: ok -- every cut of a stream reads as the whole does\n", 0)
