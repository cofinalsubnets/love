; test/host/gz.l -- the laws of src/apps/gz.l and src/apps/tar.l, internal only: crc32 against
; its published vector, both coders against each other, and the ustar header field by field.
; GNU tar and gzip agreeing with us is test/gate/targz.sh's. the round-trip shapes are chosen:
; empty and one byte are the block edges, a long run is the dist-1 overlapping copy, random data
; never matches, and text is the happy path.
(borrow 'gz)
(borrow 'tar)

(: (gz-mk n f) (: b (cask n) (go i) (n <= i ? (string b) (pin b i (f i), go (i + 1))) (go 0))
   gz-empty ""
   gz-one   "x"
   gz-run   (gz-mk 300 (i \ 65))                          ; one byte 300 times
   gz-text  "the quick brown fox jumps over the lazy dog. the quick brown fox jumps over the lazy dog."
   gz-noise (gz-mk 2000 (i \ (i * 2654435761 >> 7 & 255)))   ; no runs, no matches
   gz-shapes [gz-empty gz-one gz-run gz-text gz-noise]
   ; a round trip through the raw stream, and again through the container
   (gz-rt s) (gz-inflate (gz-deflate s) 0 @ r (!r ? 0 (<(>r) = s ? 1 0)))
   (gz-crt s) (gz-unzip (gz-zip s "" 0) @ r (!r ? 0 (<(>r) = s ? 1 0)))
   (gz-all f xs) (!(two? xs) ? 1 (f <xs ? (gz-all f >xs) 0)))

; --- crc32 --- the check value every crc32 implementation publishes is the one for
; "123456789", and it is the whole point of naming a polynomial: two crc32s that
; disagree here are different functions wearing one name.
(test
 (3421780262 = gz-crc32 "123456789")          ; 0xcbf43926
 (0 = gz-crc32 "")                            ; the empty message hashes to the seed
 !(gz-crc32 "a" = gz-crc32 "b")
 (gz-crc32 "abc" = gz-crc32 ("ab" + "c")))  ; it reads bytes, not strings

; --- deflate and inflate --- ours against ours, over the five shapes.
(test
 (gz-all gz-rt gz-shapes)
 (gz-all gz-crt gz-shapes)
 ; a run of one byte is the overlapping copy: the match source is still being
 ; written as it is read, so a decoder that moved the block at once would answer
 ; the first bytes repeated rather than the run.
 (gz-inflate (gz-deflate gz-run) 0 @ r (300 = #(<(>r))))
 ; the container's trailer is the only thing that can catch a stream that inflates
 ; and is still wrong, so a corrupted body must be refused, not returned.
 (: g (gz-zip gz-text "" 0)
    n #g
    bad (gz-mk n (i \ (i = 20 ? (g i ^ 255) (g i))))
    !(gz-unzip bad))
 !(gz-unzip "notagzipatall")                 ; a wrong magic is absence, not a scare
 !(gz-unzip "")
 ; and compression is real rather than nominal -- a coder that stored everything
 ; would pass every law above this one.
 (#(gz-deflate gz-run) < 20)
 (#(gz-deflate gz-text) < #gz-text))

; --- ustar --- the header is a wire, so the laws are its offsets. a field written
; where the next one starts is the classic tar bug and it survives a round trip
; through our own reader, which is why these are checked against the offsets and
; not against what we read back.
(: tz-e (tar-entry "dir/file.txt" 'file "hello")
   _ (pin tz-e 'mode 420, pin tz-e 'mtime 1234)
   tz-h (tar-head tz-e))
(test
 (512 = #tz-h)
 (100 = tz-h 0)                               ; name starts at offset 0: 'd'
 (tz-h 156 = 48)                              ; typeflag '0', a regular file
 ("ustar" = tar-txt tz-h 257 6)               ; the magic, at 257
 (tz-h 263 = 48) (tz-h 264 = 48)            ; version "00", not NUL-ended
 (420 = tar-oct tz-h 100 8)                   ; mode
 (5 = tar-oct tz-h 124 12)                    ; size
 (1234 = tar-oct tz-h 136 12)                 ; mtime
 ; a path of 12 characters is not split. The prefix exists for names past 100,
 ; and reaching for it earlier would produce an archive every tar can still read
 ; but none writes -- so the empty prefix here is the law, not an omission.
 ("" = tar-txt tz-h 345 155)
 ("dir/file.txt" = tar-txt tz-h 0 100)
 ; the checksum covers the block with its own field read as spaces, which is the
 ; only way a field can live inside what it sums.
 (tar-sum tz-h = tar-oct tz-h 148 8))

; --- pack and unpack --- a whole archive, ours through ours.
(: tz-es [(tar-entry "a.txt" 'file "alpha\n")
          (tar-entry "sub" 'dir "")
          (tar-entry "sub/b.txt" 'file "beta beta\n")]
   tz-a (tar-pack tz-es)
   tz-r (tar-unpack tz-a)
   tz-back (!tz-r ? () <(>tz-r)))
(test
 (0 = #tz-a % 512)                     ; an archive is whole blocks, always
 (#tz-a = 3584)                          ; 3 headers + 2 bodies + 2 zero blocks
 (two? tz-r)
 (3 = #tz-back)
 ("a.txt" = <tz-back 'nom)
 ('file = <tz-back 'kind)
 ("alpha\n" = <tz-back 'body)
 ('dir = (peep <(>tz-back) 'kind ()))
 ("sub/b.txt" = (peep <(>(>tz-back)) 'nom ()))
 ; order is the archive's. a reader that answered entries reversed would satisfy
 ; every "is it in there" law and still extract a tree whose directories arrive
 ; after the files that need them.
 ("beta beta\n" = (peep <(>(>tz-back)) 'body ()))
 ; a truncated archive is absence, not half an answer
 !(tar-unpack (snip tz-a 0 700))
 !(tar-unpack "rubbish"))

; --- the name split --- ustar's 100-byte name with a 155-byte prefix, joined by a
; "/" that is not stored. The refusal at the end is the point: a path that fits
; neither field is refused rather than truncated, because a silently shortened path
; is a wrong archive that looks right until something extracts it.
(: tz-long (: (go i a) (12 <= i ? a (go (i + 1) (a + "0123456789/"))) (go 0 ""))
   tz-deep (tz-long + "leaf.txt"))
(test
 (tar-split "short.txt" @ sp ("" = <sp && "short.txt" = <(>sp)))
 (tar-split tz-deep @ sp (two? sp && (tally <(>sp)) < 101))
 ; 200 characters with no "/" at all: no split can exist, and none is invented
 !(tar-split (gz-mk 200 (i \ 97)))
 !(tar-head (tar-entry (gz-mk 200 (i \ 97)) 'file "" @ e e)))

; --- the two together --- a .tar.gz built and taken apart entirely in love, which
; is the whole errand: `make dist` shells out to neither tar nor gzip.
(: tgz-a (tar-pack [(tar-entry "x/one.txt" 'file "first\n")
                    (tar-entry "x/two.txt" 'file (gz-mk 5000 (i \ (97 + i % 26))))])
   tgz-z (gz-zip tgz-a "archive.tar" 0)
   tgz-u (gz-unzip tgz-z)
   tgz-back (!tgz-u ? () (tar-unpack <(>tgz-u))))
(test
 (#tgz-z < #tgz-a)                ; it actually compressed
 (two? tgz-u)
 (two? tgz-back)
 (2 = #(<(>tgz-back)))
 ("first\n" = (peep <(<(>tgz-back)) 'body ()))
 (5000 = #(peep <(>(<(>tgz-back))) 'body ())))

; --- the ceiling --- the inflated bytes are one string in the heap, so a stream that
; inflates past 1 GiB is refused with a word and never grown into. a fixed-code stream of
; one zero then 258-byte copies at distance one: 13 bytes carry eight of them, so 7 MB
; says 1.1 GiB. the counting pass that finds it out is cheap
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

; --- the container streamed --- gz-unzipf reads a piece at a time and writes as it inflates:
; every cut answers the member, the stamp and the name; members that follow are read on; the
; tail that is no member is 'trail; torn, a wrong crc and a declined writer say so
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
 ; the ceiling is the heap's: streamed, the 1.1 GiB bomb goes out whole (its crc is not its own)
 (gzf-bu = ())
 (peep gzf-n 0 0 = 1 + 258 * (1 + 8 * 558835)))

; gz-zip9: the harder coder under the same container, read back by the same unzip
(test
 (: z (gz-zip9 gz-text "a.txt" 7) u (gz-unzip z) h (gz-head z)
    (two? u & (<>u = gz-text) & (h 2 = "a.txt") & (#z <= #(gz-zip gz-text "a.txt" 7)) ? 1 0)))

(puts "gz: ok") (putc 10)
