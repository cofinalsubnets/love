; test/host/gz.l -- src/apps/gz.l and src/apps/tar.l against themselves; GNU tar and gzip
; agreeing with us is test/gate/targz.sh's
(borrow 'gz)
(borrow 'tar)

(: (gz-mk n f) (: b (cask n) (go i) (n <= i ? (string b) (pin b i (f i), go (i + 1))) (go 0))
   gz-empty ""
   gz-one   "x"
   gz-run   (gz-mk 300 (i \ 65))                          ; one byte 300 times
   gz-text  "the quick brown fox jumps over the lazy dog. the quick brown fox jumps over the lazy dog."
   gz-noise (gz-mk 2000 (i \ (i * 2654435761 >> 7 & 255)))   ; no runs, no matches
   gz-shapes [gz-empty gz-one gz-run gz-text gz-noise]
   ; round trips: the raw stream, and the container
   (gz-rt s) (gz-inflate (gz-deflate s) 0 @ r (!r ? 0 (<(>r) = s ? 1 0)))
   (gz-crt s) (gz-unzip (gz-zip s "" 0) @ r (!r ? 0 (<(>r) = s ? 1 0)))
   (gz-all f xs) (!(two? xs) ? 1 (f <xs ? (gz-all f >xs) 0)))

; crc32's published check value
(test
 (3421780262 = gz-crc32 "123456789")          ; 0xcbf43926
 (0 = gz-crc32 "")
 !(gz-crc32 "a" = gz-crc32 "b")
 (gz-crc32 "abc" = gz-crc32 ("ab" + "c")))

(test
 (gz-all gz-rt gz-shapes)
 (gz-all gz-crt gz-shapes)
 ; a run is the overlapping dist-1 copy
 (gz-inflate (gz-deflate gz-run) 0 @ r (300 = #(<(>r))))
 ; a corrupted body is refused by the trailer
 (: g (gz-zip gz-text "" 0)
    n #g
    bad (gz-mk n (i \ (i = 20 ? (g i ^ 255) (g i))))
    !(gz-unzip bad))
 !(gz-unzip "notagzipatall")                 ; absence, not a scare
 !(gz-unzip "")
 ; a coder that only stored would pass every law above
 (#(gz-deflate gz-run) < 20)
 (#(gz-deflate gz-text) < #gz-text))

; ustar: checked at the wire offsets, since a misplaced field survives our own round trip
(: tz-e (tar-entry "dir/file.txt" 'file "hello")
   _ (pin tz-e 'mode 420, pin tz-e 'mtime 1234)
   tz-h (tar-head tz-e))
(test
 (512 = #tz-h)
 (100 = tz-h 0)                               ; 'd'
 (tz-h 156 = 48)                              ; typeflag '0', a regular file
 ("ustar" = tar-txt tz-h 257 6)               ; the magic, at 257
 (tz-h 263 = 48) (tz-h 264 = 48)            ; version "00", not NUL-ended
 (420 = tar-oct tz-h 100 8)                   ; mode
 (5 = tar-oct tz-h 124 12)                    ; size
 (1234 = tar-oct tz-h 136 12)                 ; mtime
 ; a short path leaves the prefix empty, as every tar writes it
 ("" = tar-txt tz-h 345 155)
 ("dir/file.txt" = tar-txt tz-h 0 100)
 ; the checksum sums the block with its own field read as spaces
 (tar-sum tz-h = tar-oct tz-h 148 8))

(: tz-es [(tar-entry "a.txt" 'file "alpha\n")
          (tar-entry "sub" 'dir "")
          (tar-entry "sub/b.txt" 'file "beta beta\n")]
   tz-a (tar-pack tz-es)
   tz-r (tar-unpack tz-a)
   tz-back (!tz-r ? () <(>tz-r)))
(test
 (0 = #tz-a % 512)
 (#tz-a = 3584)                          ; 3 headers + 2 bodies + 2 zero blocks
 (two? tz-r)
 (3 = #tz-back)
 ("a.txt" = <tz-back 'nom)
 ('file = <tz-back 'kind)
 ("alpha\n" = <tz-back 'body)
 ('dir = (peep <(>tz-back) 'kind ()))
 ("sub/b.txt" = (peep <(>(>tz-back)) 'nom ()))
 ; order is the archive's, directories before their files
 ("beta beta\n" = (peep <(>(>tz-back)) 'body ()))
 !(tar-unpack (snip tz-a 0 700))
 !(tar-unpack "rubbish"))

; the name split: 100-byte name, 155-byte prefix, an unstored "/"; a path fitting neither
; is refused, never truncated
(: tz-long (: (go i a) (12 <= i ? a (go (i + 1) (a + "0123456789/"))) (go 0 ""))
   tz-deep (tz-long + "leaf.txt"))
(test
 (tar-split "short.txt" @ sp ("" = <sp && "short.txt" = <(>sp)))
 (tar-split tz-deep @ sp (two? sp && (tally <(>sp)) < 101))
 !(tar-split (gz-mk 200 (i \ 97)))
 !(tar-head (tar-entry (gz-mk 200 (i \ 97)) 'file "" @ e e)))

; a .tar.gz built and taken apart entirely in love
(: tgz-a (tar-pack [(tar-entry "x/one.txt" 'file "first\n")
                    (tar-entry "x/two.txt" 'file (gz-mk 5000 (i \ (97 + i % 26))))])
   tgz-z (gz-zip tgz-a "archive.tar" 0)
   tgz-u (gz-unzip tgz-z)
   tgz-back (!tgz-u ? () (tar-unpack <(>tgz-u))))
(test
 (#tgz-z < #tgz-a)
 (two? tgz-u)
 (two? tgz-back)
 (2 = #(<(>tgz-back)))
 ("first\n" = (peep <(<(>tgz-back)) 'body ()))
 (5000 = #(peep <(>(<(>tgz-back))) 'body ())))

; the ceiling: a stream inflating past 1 GiB is refused with a word, never grown into.
; fixed-code: one zero, then 258-byte dist-1 copies, eight per 13 bytes: 7 MB says 1.1 GiB
(: (bomb-rep s k) (? (k = 0) "" (k % 2 = 1) (s + bomb-rep s (k - 1))
                     (bomb-rep s (k // 2) @ h (h + h)))
   bomb-u "\xa3\x60\x14\x8c\x82\x51\x30\x0a\x46\xc1\x28\x18\x05"
   (bomb k) ("\x63\x18\x05" + bomb-rep bomb-u k + "\x00")
   bomb-small (bomb 2)
   bomb-big (bomb 558835)
   bomb-z ("\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03" + bomb-big + "\x00\x00\x00\x00\x33\x36\xc0\x44"))
(test
 (#(<(>(gz-inflate bomb-small 0))) = 4387)          ; 1 + 17 copies of 258
 (inflate bomb-big 0 = 1)
 (inflate bomb-big 100 = 1)                         ; a hint that lies low is not believed
 (gz-inflate bomb-big 0 = 'big)
 (gz-unzip bomb-z = 'big))

; gz-unzipf streamed: every cut answers member, stamp and name; following members are read
; on; a non-member tail is 'trail
(: (gzf-cut s k) (: n #s (go i) (n <= i ? () ((snip s i (min n (i + k))) . go (i + k))) (go 0))
   (gzf-rd ps) ({0 ps} @ t (_ \ (peep t 0 () @ l (two? l ? (pin t 0 >l, <l) ""))))
   (gzf-wr t) (a \ b \ [1 (o \ (pin t 0 (o . peep t 0 ())))])
   (gzf-run s k) (: t {0 ()}   u (gz-unzipf (gzf-rd (gzf-cut s k)) (gzf-wr t))
                    [u (cats (rev (t 0)))])
   (gzf-all f xs) (foldl (a \ x \ (a && f x)) 1 xs)
   gzf-a (gz-zip gz-text "a.txt" 7)
   gzf-b (gz-zip "delta\n" "" 0)
   gzf-ks [1 5 64 100000]
   (gzf-ok s k out) (: r (gzf-run s k) u <r
                       (two? u & (<u = 1) & (u 1 = 7) & (u 2 = "a.txt") & (u 3 = #out) & (r 1 = out) ? 1 0))
   gzf-n {0 0}
   gzf-bu (gz-unzipf (gzf-rd (gzf-cut bomb-z 65536)) (a \ b \ [1 (o \ (pin gzf-n 0 (peep gzf-n 0 0 + #o)))])))
(test
 (gzf-all (k \ (gzf-ok gzf-a k gz-text)) gzf-ks)
 (gzf-all (k \ (gzf-ok (gzf-a + gzf-b) k (gz-text + "delta\n"))) gzf-ks)
 (gzf-all (k \ (gzf-run (gzf-a + "junk") k @ r ((<(<r) = 'trail) & (r 1 = gz-text) ? 1 0))) gzf-ks)
 (gzf-all (k \ (<(gzf-run (snip gzf-a 0 (#gzf-a - 3)) k) = ())) gzf-ks)
 (<(gzf-run (snip gzf-a 0 (#gzf-a - 8) + "\x01\x02\x03\x04" + snip gzf-a (#gzf-a - 4) #gzf-a) 64) = ())
 (<(gzf-run "hello, not a gzip" 5) = 'nogz)
 (gz-unzipf (gzf-rd [gzf-a]) (a \ b \ ()) = 'no)
 ; streamed, the bomb goes out whole (its crc is not its own)
 (gzf-bu = ())
 (peep gzf-n 0 0 = 1 + 258 * (1 + 8 * 558835)))

; gz-zip9: the harder coder, read back by the same unzip
(test
 (: z (gz-zip9 gz-text "a.txt" 7) u (gz-unzip z) h (gz-head z)
    (two? u & (<>u = gz-text) & (h 2 = "a.txt") & (#z <= #(gz-zip gz-text "a.txt" 7)) ? 1 0)))

(puts "gz: ok") (putc 10)
