; test/host/droid.l -- the apk's own pieces, read back by our own readers: the zip inflates
; entry by entry, the binary manifest's pool decodes and its chunks walk to the end, and the
; v2 block is the zip's digest signed: taken out, the zip comes back; its signature verifies.
; a phone is the oracle for whether android takes it, and it took this shape.
;
; run:  cat test/00-init.l test/host/droid.l | out/love

(borrow "src/apps/droid/droid.l")
(borrow 'bytes)
(borrow 'gz)
(borrow 'tls)

(: dr-k (key-new 'p256)
   dr-nm (name-der "/CN=t")
   dr-c (cert-make {'spki (key-spki dr-k) 'exts () 'key dr-k 'serial 1 'issuer dr-nm 'subject dr-nm
                    'nb 1767225600 'na 3345062400})
   dr-es [["a.txt" "hello"] ["b/c" (zbytes 5000)] ["e" ""]]
   dr-z (ap-zip dr-es)
   ; the local entries, walked from the front: [name bytes] each, the bytes inflated
   (dr-ents z)
    (: (go i acc)
        (? (rdle z i 4 != 0x04034b50) (rev acc)
           (: cs (rdle z (i + 18) 4) us (rdle z (i + 22) 4) nl (rdle z (i + 26) 2)
              d (snip z (i + 30 + nl) (i + 30 + nl + cs))
              b (gz-inflate d us @ r (? (two? r) <>r ""))
              ok (gz-crc32 b = rdle z (i + 14) 4)
              (go (i + 30 + nl + cs) ([(snip z (i + 30) (i + 30 + nl)) (? ok b 'badcrc)] . acc))))
       (go 0 ()))
   dr-eo (#dr-z - 22)
   ; the manifest: its chunks, and its pool's strings
   dr-x (ap-axml (ap-manifest "org.love.t" "t"))
   (dr-walk x)
    (: (go i acc) (? (#x <= i) [i (rev acc)] (go (i + rdle x (i + 4) 4) (rdle x i 2 . acc))) (go 8 ()))
   (dr-pool x)
    (: n (rdle x 16 4) ss (8 + rdle x 28 4)
       (map (k \ : o (ss + rdle x (36 + 4 * k) 4) l (rdle x o 2)
                  (cats (map (j \ string [(rdle x (o + 2 + 2 * j) 2)]) ^l)))
            ^n))
   ; the v2 block: before the central directory, its magic last, its size first and last
   dr-s (v2-sign dr-z dr-k dr-c)
   dr-co (rdle dr-s (#dr-s - 6) 4)
   dr-n (rdle dr-s (dr-co - 24) 8)
   dr-b0 (dr-co - dr-n - 8)
   dr-sd (snip dr-s (dr-b0 + 32) (dr-b0 + 32 + rdle dr-s (dr-b0 + 28) 4))
   dr-p (dr-b0 + 32 + #dr-sd)
   dr-sig (snip dr-s (dr-p + 16) (dr-p + 16 + rdle dr-s (dr-p + 12) 4))
   dr-spk (key-spki dr-k)
   (dr-has? s t) (any (i \ snip s i (i + #t) = t) ^(#s - #t + 1))
   _ 0)

(test
 ; the zip: every entry back, the end record counting them and naming the central directory
 (dr-ents dr-z = dr-es)
 (rdle dr-z (dr-eo + 10) 2 = 3)
 (rdle dr-z (rdle dr-z (dr-eo + 16) 4) 4 = 0x02014b50)
 ; the same inputs lay the same bytes
 (ap-zip dr-es = dr-z))

(test
 ; the manifest walks chunk by chunk to its own end: the pool, the resource map, then the tree
 (: w (dr-walk dr-x) (<w = #dr-x && rdle dr-x 4 4 = #dr-x && (w 1) 0 = 1 && (w 1) 1 = 0x180))
 ; every string a string, the attribute names first in resource-id order
 (: p (dr-pool dr-x) (p 0 = "label" && elem "manifest" p && elem "org.love.t" p && elem "activity" p))
 (: p (dr-pool dr-x) !(any (x \ !(string? x)) p)))

(test
 ; the block's magic and its two sizes
 (snip dr-s (dr-co - 16) dr-co = "APK Sig Block 42")
 (rdle dr-s dr-b0 8 = dr-n)
 ; out again, with the end record's offset put back, the block leaves the zip it was laid in
 (snip dr-s 0 dr-b0 + snip dr-s dr-co (#dr-s - 6) + wrle dr-b0 4 + snip dr-s (#dr-s - 2) #dr-s = dr-z)
 ; the signed data carries the zip's digest and the certificate, and the signature verifies
 (dr-has? dr-sd (v2-digest [(snip dr-z 0 dr-b0) (snip dr-z dr-b0 dr-eo) (snip dr-z dr-eo #dr-z)]))
 (dr-has? dr-sd dr-c)
 (1 = sig-ok? (unhex "2a8648ce3d040302") (spki-key dr-spk (der dr-spk 0 #dr-spk)) dr-sd dr-sig))

(puts "droid: ok") (putc 10)
