; test/host/zstd.l -- zstandard read a block at a time, held to the frames read whole
; zstd-pull steps a block at a time off a reader and zstd-unpack reads the whole string; every
; cut of a stream answers the same bytes, or the same word. zstd-pack's frames read back.
;   run:  cat test/00-init.l test/host/zstd.l | out/love
(borrow '(zstd bytes hashes))

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
   (zst-xor s k b) (cask #s @ c (pour c 0 s 0 #s, pin c k (s k ^ b), string c))
   (zst-flip s k) (zst-xor s k 1)
   ; the same frame with its checksum and the flag that wants it taken off
   zst-nk (zst-xor (snip zst-a 0 (#zst-a - 4)) 4 4)
   (zst-back s l) (zstd-unpack (zstd-pack s l) @ u (two? u && <>u = s)))
(test
 (lit? zstd-block)
 ; every level reads back, the empty input too, and one byte over and over
 (zst-all (zst-back zst-mix) [1 2 3 5 9 12 16 17 18 19])
 (zst-back "" 3)
 (zst-back "x" 3)
 (zst-back "" 19)
 (zst-back "x" 19)
 (zst-back (cats (map (_ \ "z") (jot 70000))) 19)
 ; the optimal parse beats the chain on source, and text beside noise splits its blocks
 (uread "src/love/compress/zstd.c" @ [1 c] (: z (zstd-pack (c + "") 19) (#z * 100 < #(zstd-pack (c + "") 15) * 97 && zstd-d z = c + "")))
 (zst-back (cats (map (_ \ "z") (jot 70000))) 3)
 ; each step of the ladder pays on source, and the lookahead reads back to the last bytes
 (uread "src/love/compress/zstd.c" @ [1 c] (: (z l) #(zstd-pack (c + "") l) (z 15 < z 9 && z 9 < z 5 && z 5 < z 3)))
 (zst-all (zst-back "abcdefghabcdefgh") [4 9 15])
 (zst-all (zst-back zst-noise) [4 9 15])
 ; the fast parse reads past a run of nothing, up to the last byte, and its tables grow by level
 (zst-all (zst-back zst-noise) [1 2 3])
 (zst-all (zst-back "abcdefgh") [1 2 3])
 (zst-all (zst-back "abcdefghabcdefgh") [1 2 3])
 (uread "src/love/compress/zstd.c" @ [1 c] (#(zstd-pack (c + "") 3) <= #(zstd-pack (c + "") 1)))
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
 ; and a frame with none reads as well, before or after one with
 (zstd-unpack (zst-nk + zst-a) = [1 (zst-text + zst-text)])
 (zstd-unpack (zst-a + zst-nk) = [1 (zst-text + zst-text)])
 (zst-same zst-nk zst-ks)
 ; torn at every length, and a flipped bit anywhere: the same answer whole or pulled
 (zstd-unpack (snip zst-a 0 (#zst-a - 1)) = 'end)
 (: (go i) (? (#zst-a <= i) 1 !(zst-same (snip zst-a 0 i) [7 4096]) 0 (go (i + 13))) (go 0))
 (: (go i) (? (#zst-a <= i) 1 !(zst-same (zst-flip zst-a i) [7 4096]) 0 (go (i + 7))) (go 0)))

; pour lands nothing in a state, and it reads on as it was
(: st (zstd-new 4096)
   ; a state is a port with no door: nothing lands, a read is the end, close leaves it whole
   _ (say st "xyz", put st 65, flush st, close st)
   _ (test (read st = ()) (slurp st = "")
           (zstd-block (jug 0) "abc" = ()) (zstd-block (cask 4096) "abc" = ()))
   _ (pour st 24 "\xff\xff\xff\xff\xff\x7f" 0 6)
   _ (test (kind st = 'port) (zstd-block st "\x19\0\0abc" = "abc"))
   0)

(test_fin (), puts "zstd: ok -- every cut of a frame reads as the whole does, and our frames read back\n", 0)
