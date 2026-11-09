; test/host/xz.l -- src/apps/xz.l: xz-pull at every cut answers what xz-unpack does whole.
;   run:  cat test/00-init.l test/host/xz.l | out/love
(borrow '(xz bytes))

(: (xzt-mk n f) (: b (cask n) (go i) (n <= i ? (string b) (pin b i (f i), go (i + 1))) (go 0))
   (xzt-cut s k) (: n #s (go i) (n <= i ? () ((snip s i (min n (i + k))) . go (i + k))) (go 0))
   (xzt-rd ps) ({0 ps} @ t (_ \ (peep t 0 () @ l (two? l ? (pin t 0 >l, <l) ""))))
   (xzt-pull s k) (: g (xz-pull (xzt-rd (xzt-cut s k)))
                     (go acc) (xz-next g @ p (#p = 0 ? [(g 'ans) (two? acc ? (cats (rev acc)) "")] (go (p . acc))))
                     (go ()))
   ; the whole answer as the pull spells it: (1 n) and the bytes, or the word
   (xzt-whole s) (xz-unpack s @ u (atom? u ? [u ""] [[1 #<>u] <>u]))
   (xzt-all f xs) (foldl (a \ x \ (a && f x)) 1 xs)
   xzt-ks [1 7 4096 100000]
   ; a word is compared alone: the pull has already put out what came before it
   (xzt-same s) (xzt-whole s @ w
                   (xzt-all (k \ (xzt-pull s k @ p (atom? <w ? (<p = <w) (p = w)))) xzt-ks))
   xzt-text (: (go i a) (i < 1 ? a (go (i - 1) (a + "the quick brown fox jumps over the lazy dog. "))) (go 400 ""))
   xzt-noise (xzt-mk 70000 (i \ (i * 2654435761 >> 11 & 255)))
   xzt-big (xzt-mk 3000000 (i \ ((i * 7 + i // 1000) % 251)))
   xzt-a (xz-pack xzt-text 4096 'crc64)
   (xzt-flip s k) (cask #s @ c (pour c 0 s 0 #s, pin c k (s k ^ 1), string c)))
(test
 (lit? lzma2-chunk)
 ; every check, a window the output outruns, the empty stream
 (xzt-same xzt-a)
 (xzt-same (xz-pack xzt-text 4096 'crc32))
 (xzt-same (xz-pack xzt-text 4096 'sha256))
 (xzt-same (xz-pack xzt-text 4096 'none))
 (xzt-same (xz-pack xzt-noise 65536 'crc64))
 (xzt-same (xz-pack xzt-big 65536 'crc64))
 (xzt-same (xz-pack "" 4096 'crc64))
 ; concatenated streams, and padding zeros between them
 (xzt-same (xzt-a + xz-pack "second" 4096 'crc32))
 (xzt-same (xzt-a + zbytes 8 + xz-pack "second" 4096 'crc32))
 (xzt-same (xzt-a + zbytes 3))
 ; not xz, truncated, a flipped byte
 (xzt-same "hello, not xz at all")
 (: (go i) (? (#xzt-a <= i) 1 !(xzt-same (snip xzt-a 0 i)) 0 (go (i + 13))) (go 0))
 (: (go i) (? (#xzt-a <= i) 1 !(xzt-same (xzt-flip xzt-a i)) 0 (go (i + 5))) (go 0))
 ; the crc64 sits behind the data, ahead of the index (12 bytes here) and the footer (12)
 (<(xzt-pull (xzt-flip xzt-a (#xzt-a - 28)) 64) = 'check))

; a refused chunk ends the state; no flipped byte of a container reads as the whole does
(: st (lzma2-new 65536)
   _ (test (lzma2-chunk st "\xc0\0\0\0\x01\xe0x" = ()) (lzma2-chunk st "\x01\0\0a" = ()) (kind st = 'port))
   (go i) (? (#xzt-a <= i) 1 (<(xz-unpack (xzt-flip xzt-a i)) = 1) 0 (go (i + 1)))
   _ (test (go 0))
   0)

; lzma2e fed in pieces is lzma2e whole, sliding past its window; xz-zip's streams read back
(: (xzf-feed s k d) (: st (lzma2e-new d)
                       (go ps acc) (? (atom? ps) (lzma2e-end st @ z (string? z ? (cats (rev (z . acc))) ()))
                                      (lzma2e-feed st <ps @ z (string? z ? (go >ps (z . acc)) ())))
                       (go (xzt-cut s k) ()))
   (xzf-same s k d) (xzf-feed s k d @ z (string? z && z = lzma2e s d))
   (xzf-zip s k ck) (: o {0 ()}
                       z (xz-zip (xzt-rd (xzt-cut s k)) 65536 ck (x \ pin o 0 (x . o 0)))
                       (two? z ? (cats (rev (o 0))) ()))
   (xzf-back s k ck) (xzf-zip s k ck @ z (string? z && xz-unpack z = [1 s] && xzt-same z))
   _ (test
      (xzt-all (k \ xzf-same xzt-big k 65536) [100000 4000000])
      (xzf-same (snip xzt-text 0 3000) 1 4096)
      (xzf-same "" 7 4096)
      (xzt-all (ck \ xzf-back xzt-text 999 ck) ['none 'crc32 'crc64 'sha256])
      (xzf-back "" 7 'crc64)
      (lzma2e-new 7 = ())
      (: st (lzma2e-new 4096)   _ (lzma2e-end st) (lzma2e-feed st "x" = ())))
   0)

(test_fin (), puts "xz: ok -- every cut of a container reads as the whole does\n", 0)
