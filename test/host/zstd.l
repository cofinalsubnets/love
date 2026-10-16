; test/host/zstd.l -- zstandard read a block at a time, held to the frames read whole
; zstd-pull steps a block at a time off a reader and zstd-unpack reads the whole string; every
; cut of a stream answers the same bytes, or the same word. zstd-pack's frames read back.
;   run:  cat test/00-init.l test/host/zstd.l | out/love
(borrow 'zstd)
(borrow 'bytes)
(borrow 'hashes)

(: (zst-cut s k) (: n #s (go i) (n <= i ? () ((snip s i (min n (i + k))) . go (i + k))) (go 0))
   (zst-rd ps) ({0 ps} @ t (_ \ (peep t 0 () @ l (two? l ? (pin t 0 >l, <l) ""))))
   (zst-pull s k) (: g (zstd-pull (zst-rd (zst-cut s k)))
                     (go acc) (zstd-next g @ p (#p = 0 ? [(g 'ans) (two? acc ? (cats (rev acc)) "")] (go (p . acc))))
                     (go ()))
   (zst-whole s) (zstd-unpack s @ u (atom? u ? [u ""] [[1 #<>u] <>u]))
   (zst-all f xs) (foldl (a \ x \ (a && f x)) 1 xs)
   (zst-same s ks) (zst-whole s @ w
                      (zst-all (k \ (zst-pull s k @ p (atom? <w ? (<p = <w) (p = w)))) ks))
   zst-ks [1 7 4096 100000]
   zst-text (: (go i a) (i < 1 ? a (go (i - 1) (a + "the quick brown fox jumps over the lazy dog. "))) (go 3000 ""))
   ; noise past a block, so the frame holds stored blocks beside coded ones
   zst-noise (cats (map (i \ hex2b (sha256 (show i))) (jot 12000)))
   zst-mix (zst-text + zst-noise + zst-text)
   zst-a (zstd-pack zst-text 3)
   zst-m (zstd-pack zst-mix 9)
   ; a skippable frame: magic 0x184d2a5?, a length, that many bytes
   zst-skip ("\x5a\x2a\x4d\x18" + wrle 5 4 + "hello")
   (zst-flip s k) (cask #s @ c (pour c 0 s 0 #s, pin c k (s k ^ 1), string c))
   (zst-back s l) (zstd-unpack (zstd-pack s l) @ u (two? u && <>u = s)))
(test
 (lit? zstd-block)
 ; every level reads back, the empty input too, and one byte over and over
 (zst-all (l \ zst-back zst-mix l) [1 2 3 5 9 12 19])
 (zst-back "" 3)
 (zst-back "x" 3)
 (zst-back (cats (map (_ \ "z") (jot 70000))) 3)
 (#zst-a < #zst-text // 20)
 (zst-same zst-a zst-ks)
 (zst-same zst-m [7 4096 100000])
 (zst-same (zstd-pack "" 3) zst-ks)
 ; frames one after another, a skippable frame among them, a tail that is none, and not zstd
 (zst-same (zst-a + zst-skip + zstd-pack "second" 1) zst-ks)
 (zstd-unpack (zst-a + zst-skip + zstd-pack "second" 1) = [1 (zst-text + "second")])
 (zstd-unpack (zst-a + "junk") = 'format)
 (zstd-unpack "hello, not zstd" = 'format)
 (zstd-unpack "" = 'format)
 (zst-same (zst-a + "junk") zst-ks)
 (zst-same "hello, not zstd" zst-ks)
 ; the checksum is held: a flipped bit in it is 'check
 (zstd-unpack (zst-flip zst-a (#zst-a - 2)) = 'check)
 ; torn at every length, and a flipped bit anywhere: the same answer whole or pulled
 (zstd-unpack (snip zst-a 0 (#zst-a - 1)) = 'end)
 (: (go i) (? (#zst-a <= i) 1 !(zst-same (snip zst-a 0 i) [7 4096]) 0 (go (i + 13))) (go 0))
 (: (go i) (? (#zst-a <= i) 1 !(zst-same (zst-flip zst-a i) [7 4096]) 0 (go (i + 7))) (go 0)))

(test_fin (), puts "zstd: ok -- every cut of a frame reads as the whole does, and our frames read back\n", 0)
