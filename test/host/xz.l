; --- test/host/xz.l: the .xz container read as it comes, held to the one read whole ---
; xz-pull walks a source a piece at a time and xz-unpack walks the whole string; both are
; src/apps/xz.l's, and every cut of a container answers the same bytes, or the same word.
;   run:  cat test/00-init.l test/host/xz.l | out/love
(borrow 'xz)
(borrow 'bytes)

(: (xzt-mk n f) (: b (cask n) (go i) (n <= i ? (string b) (pin b i (f i), go (i + 1))) (go 0))
   (xzt-cut s k) (: n #s (go i) (? (n <= i) () ((snip s i (min n (i + k))) . go (i + k))) (go 0))
   (xzt-rd ps) (: t {0 ps} (\ _ (: l (peep t 0 ()) (? (two? l) (: _ (pin t 0 >l) <l) ""))))
   (xzt-pull s k) (: g (xz-pull (xzt-rd (xzt-cut s k)))
                     (go acc) (: p (xz-next g) (? (#p = 0) [(g 'ans) (? (two? acc) (cats (rev acc)) "")] (go (p . acc))))
                     (go ()))
   ; the answer whole, as the pull spells it: (1 n) and the bytes, or the word
   (xzt-whole s) (: u (xz-unpack s) (? (atom? u) [u ""] [[1 #<>u] <>u]))
   (xzt-all f xs) (foldl (\ a x (a && f x)) 1 xs)
   xzt-ks [1 7 4096 100000]
   ; a word is compared alone: the pull has put out what came before it, the whole has not
   (xzt-same s) (: w (xzt-whole s)
                   (xzt-all (\ k (: p (xzt-pull s k) (? (atom? <w) (<p = <w) (p = w)))) xzt-ks))
   xzt-text (: (go i a) (? (i < 1) a (go (i - 1) (a + "the quick brown fox jumps over the lazy dog. "))) (go 400 ""))
   xzt-noise (xzt-mk 70000 (\ i (((i * 2654435761) >> 11) & 255)))
   xzt-big (xzt-mk 3000000 (\ i ((i * 7 + (i // 1000)) % 251)))
   xzt-a (xz-pack xzt-text 4096 'crc64)
   (xzt-flip s k) (: c (cask #s) _ (pour c 0 s 0 #s) _ (pin c k ((s k) ^ 1)) (string c)))
(test
 (lit? lzma2-chunk)
 ; the shapes, every check, a window the output outruns, and the empty stream
 (xzt-same xzt-a)
 (xzt-same (xz-pack xzt-text 4096 'crc32))
 (xzt-same (xz-pack xzt-text 4096 'sha256))
 (xzt-same (xz-pack xzt-text 4096 'none))
 (xzt-same (xz-pack xzt-noise 65536 'crc64))
 (xzt-same (xz-pack xzt-big 65536 'crc64))
 (xzt-same (xz-pack "" 4096 'crc64))
 ; streams one after another, and the zeros xz allows between them
 (xzt-same (xzt-a + xz-pack "second" 4096 'crc32))
 (xzt-same (xzt-a + zbytes 8 + xz-pack "second" 4096 'crc32))
 (xzt-same (xzt-a + zbytes 3))
 ; the words: not xz, torn at every length a byte at a time, and a check that disagrees
 (xzt-same "hello, not xz at all")
 (: (go i) (? (#xzt-a <= i) 1 !(xzt-same (snip xzt-a 0 i)) 0 (go (i + 13))) (go 0))
 (: (go i) (? (#xzt-a <= i) 1 !(xzt-same (xzt-flip xzt-a i)) 0 (go (i + 5))) (go 0))
 ; the crc64 sits behind the data, ahead of the index (12 bytes here) and the footer (12)
 (<(xzt-pull (xzt-flip xzt-a (#xzt-a - 28)) 64) = 'check))

(test_fin (), puts "xz: ok -- every cut of a container reads as the whole does\n", 0)
