; test/host/gzc.l -- the C twins of gz.l (`inflate`, `crc32`, `deflate`) held to the love, the oracle
; `string?`, never `?` or `!`, asks whether an answer is there: a run of NULs reads as false
; not in the corpus: host nifs. run: cat test/00-init.l test/host/gzc.l | out/love
(borrow 'gz)
(borrow 'hashes)

(test
 (lit? inflate)
 (lit? crc32))

(: (gzc-mk n f) (: b (cask n) (go i) (n <= i ? (string b) (pin b i (f i), go (i + 1))) (go 0))
   (gzc-l d h) (gz-puff d h @ r (two? r ? <>r 'nil))          ; the oracle
   (gzc-c d h) (inflate d h @ r (string? r ? r 'nil))         ; the C twin
   (gzc-same d h) (gzc-l d h = gzc-c d h)
   (gzc-all f xs) (!(two? xs) ? 1 (f <xs ? (gzc-all f >xs) 0))

   gzc-empty ""
   gzc-one   "x"
   gzc-run   (gzc-mk 300 (i \ 65))                       ; dist 1, the overlapping copy
   gzc-long  (gzc-mk 100000 (i \ 65))                    ; matches at the 258 ceiling
   gzc-per   (gzc-mk 40000 (i \ (65 + i % 11)))        ; dist 11, three words at a time
   ; periods 2 through 9: under eight a word move reads bytes it has not written yet
   gzc-near  (: (go j a) (9 < j ? a (go (j + 1) (a + gzc-mk 4000 (i \ (65 + i % j)))))
                (go 2 ""))
   gzc-text  ("the quick brown fox jumps over the lazy dog. "
              + "pack my box with five dozen liquor jugs. ")
   gzc-noise (gzc-mk 2000 (i \ (i * 2654435761 >> 7 & 255)))   ; no matches: stored
   gzc-mixed (: (go k a) (k < 1 ? a (go (k - 1) (a + gzc-text + gzc-run + gzc-noise)))
                (go 8 ""))
   gzc-shapes [gzc-empty gzc-one gzc-run gzc-long gzc-per gzc-near gzc-text gzc-noise
               gzc-mixed]

   ; a round trip, and the same stream read both ways with the size and without it
   (gzc-rt s) (: d (gz-deflate s)   n #s
                 (? !(gzc-same d n) 0
                    !(gzc-same d 0) 0
                    !(gzc-c d n = s) 0
                    1))
   ; a size that lies is the retry
   (gzc-hint s) (: d (gz-deflate s)   n #s
                   (? !(gzc-same d (n + 100)) 0
                      !(gzc-same d -3) 0
                      !(gzc-same d (n < 2 ? 1 (n - 1))) 0
                      1))
   ; `gz-inflate` reaches for the nif and must answer what puff answers
   (gzc-door s) (: d (gz-deflate s)   n #s
                   r (gz-inflate d n)
                   (? !(two? r) 0 (<>r = s) 1 0)))

; the shapes
(test
 (gzc-all gzc-rt gzc-shapes)
 (gzc-all gzc-hint gzc-shapes)
 (gzc-all gzc-door gzc-shapes))

; torn: every prefix of a good stream
(: gzc-td (gz-deflate gzc-mixed)
   (gzc-cut d i) (cask i @ c ((i ? (pour c 0 d 0 i) 0), string c))
   (gzc-torn d k step)
    (: (go i) (? (k <= i) 1 !(gzc-same (gzc-cut d i) 400) 0 (go (i + step)))
       (go 0)))
(test (gzc-torn gzc-td #gzc-td 7))

; fuzz: one flipped bit, over every bit of the smaller stream
(: (gzc-flip d k)
    (: n #d   c (cask n)   _ (pour c 0 d 0 n)   o (k // 8)
       (pin c o (peep c o 0 ^ 1 << k % 8),
        string c))
   (gzc-fuzz s step)
    (: d (gz-deflate s)   nb (8 * #d)   n #s
       (go k) (? (nb <= k) 1 !(gzc-same (gzc-flip d k) n) 0 (go (k + step)))
       (go 0))
   ; small on purpose: gz-puff walks the nonsense at love speed. a dynamic, stored and fixed block
   gzc-fz [gzc-text gzc-run gzc-one])
(test
 (gzc-all (s \ (gzc-fuzz s 1)) gzc-fz)
 (gzc-fuzz gzc-noise 29))

; inflate-feed: every cut of a stream answers what the one-shot `inflate` did; the empty piece
; ends the input
(: (gzs-run z ks)
    (: st (inflate-new 0)   nz #z
       (go i ks acc)
        (: k <ks
           r (inflate-feed st (i < nz ? (snip z i (min nz (i + k))) ""))
           (? (two? r) [(cats (rev (<r . acc))) (>r + (i + k < nz ? (snip z (i + k) nz) ""))]
              (string? r) (nz <= i ? 'nil (go (i + k) (>ks + [k]) (r . acc)))
              'nil))
       (go 0 ks ()))
   (gzs-out z ks) (gzs-run z ks @ r (two? r ? <r 'nil))
   gzs-cuts [[1] [7] [4096] [3 1 250 2 17 64 5]]
   (gzs-same d) (gzc-all (ks \ (gzc-c d 0 = gzs-out d ks)) gzs-cuts)
   (gzs-shape s) (gzs-same (gz-deflate s))
   (gzs-torn d step) (: (go i) (? (#d < i) 1 !(gzs-same (gzc-cut d i)) 0 (go (i + step))) (go 0))
   (gzs-fuzz s step)
    (: d (gz-deflate s)   nb (8 * #d)
       (go k) (? (nb <= k) 1 !(gzs-same (gzc-flip d k)) 0 (go (k + step)))
       (go 0))
   (gzs-rest s) (gz-deflate s @ d
                   (gzc-all (ks \ (gzs-run (d + "TRAILER!") ks = [s "TRAILER!"])) gzs-cuts))
   (test (lit? inflate-feed)
         (gzc-all gzs-shape gzc-shapes)
         (gzc-all gzs-rest [gzc-empty gzc-one gzc-text gzc-noise gzc-long])
         (gzs-torn gzc-td 7)
         (gzc-all (s \ (gzs-fuzz s 1)) gzc-fz)
         (gzs-fuzz gzc-noise 29)
         ; a stream's end hands back what lay behind it, and every piece after is all behind
         (: st (inflate-new 0)   r (inflate-feed st (gz-deflate gzc-text + "abc"))
            r2 (inflate-feed st "de")
            (two? r & (<r = gzc-text) & (>r = "abc") & two? r2 & (<r2 = "") & (>r2 = "de") ? 1 0))
         ; misuse answers ()
         !(inflate-feed (cask 8) "abc")
         !(inflate-feed 7 "abc")
         !(string? (inflate-feed (inflate-new 0) 7))
         ; the input over before a stream began is a torn stream
         !(inflate-feed (inflate-new 0) ""),
    puts "gzc: inflate-feed ok -- every cut of a stream answers the one-shot inflate\n"))

; crc32 (src/love/crypto/hash.c) against gz-crcwalk: every length 0..129, as the C reads eight
; bytes at a time; the published check value is asserted off the C side
(: (gzc-crc s) (crc32 s = gz-crcwalk s)
   (gzc-crclen k)
    (: (go i) (? (k < i) 1
                 !(gzc-crc (gzc-mk i (j \ (j * 2654435761 >> 11 & 255)))) 0
                 (go (i + 1)))
       (go 0)))
(test
 (3421780262 = crc32 "123456789")              ; 0xcbf43926, what every crc32 publishes
 (gzc-crclen 129)
 (gzc-all gzc-crc gzc-shapes)
 ; all-NUL and empty: answers a truth test would throw away
 (gzc-crc (gzc-mk 300 (i \ 0)))
 (0 = crc32 "")
 (charm? (crc32 (gzc-mk 300 (i \ 0)))))

; misuse: a wrong shape answers () and decodes nothing
(test
 !(charm? (crc32 7))
 !(charm? (crc32 ()))
 !(charm? (crc32 (cask 8)))
 !(string? (inflate 7 10))
 !(string? (inflate () 10))
 !(string? (inflate (cask 8) 10))
 !(string? (inflate (iota 8) 10))
 !(string? (inflate gzc-td 'x))
 !(string? (inflate gzc-td 1.5))
 ; the empty stream is not a stream, at either lane
 (gzc-same "" 0))

; deflate (src/love/compress/gz.c) held to love's bytes: same parse, costing and Huffman ties
(: (gzd-same s) (deflate s = gz-deflatel s)
   (gzd-trip s) (: c (deflate s)
                   l (gz-puff c #s)
                   i (inflate c #s)
                   (two? l & string? i & (<(>l) = s) & (i = s) ? 1 0))
   gzd-corp [gzc-empty gzc-one gzc-run gzc-long gzc-per gzc-near gzc-text]
   (test (lit? deflate)
         (gzc-all gzd-same gzd-corp)                       ; the bytes, corpus-wide
         (gzc-all gzd-trip gzd-corp)                       ; both inflates read them
         ; one operand, so a second indexes the answer
         (deflate gzc-text 3 = (deflate gzc-text) 3)
         (deflate gzc-one 0 = (deflate gzc-one) 0),
    puts "gzc: deflate twin ok -- the C coder answers love's bytes, both inflates read it
"))

; deflate-best, no twin: both inflates read it back, never longer than deflate's
(: (gzb-trip s) (: c (deflate-best s)
                   l (gz-puff c #s)   i (inflate c #s)
                   (two? l & string? i & (<(>l) = s) & (i = s) ? 1 0))
   (gzb-small s) (#(deflate-best s) <= #(deflate s))
   _ (test
      (lit? deflate-best)
      (gzc-all gzb-trip gzc-shapes)
      (gzc-all gzb-small gzc-shapes)
      (#(deflate-best gzc-mixed) < #(deflate gzc-mixed))     ; the lazy parse pays on text
      !(string? (deflate-best 7))
      !(string? (deflate-best (cask 8)))))

(test_fin (),
 puts "gzc: ok -- the C twins agree with love (shapes, hints, torn, fuzz, crc, misuse)
",
 0)
