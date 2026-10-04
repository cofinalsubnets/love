; src/apps/hearts/xcert.l -- the kernel's certs/extract-cert, ours: no openssl. "" makes an
; empty DST; a file gives the DER of every CERTIFICATE (or X509 CERTIFICATE) block in it, in
; order, as openssl's PEM_read_bio_X509 + i2d_X509 do -- any other block is skipped whole, and a
; file with none is an error that writes nothing. a pkcs11: URI wants a token: refused.
; usage: love xcert.l SOURCE DEST    (hearts lays certs/extract-cert as a wrapper over this)
(: argv cmdline
   (die m) (puts ("extract-cert: " + m + "\n"), quit 1)
   _ (#argv = 4 || (puts "Usage: extract-cert <source> <dest>\n", quit 2))
   src (argv 2)
   dst (argv 3)
   _ (borrow 'tls)
   b64 (cite 'tls 'b64-dec)
   ; a der's first element, whole: its tag, its length octets, its contents
   (tlv d) (: l (d 1) n (l & 127)
              (? (#d < 2 || d 0 != 48) ()
                 (l < 128) (snip d 0 (2 + l))
                 (n < 1 || 4 < n || #d < 2 + n) ()
                 ((: (g i v) (i < n ? (g (i + 1) (v * 256 + d (2 + i))) v)) 0 0 @ v
                    (#d < 2 + n + v ? () (snip d 0 (2 + n + v))))))
   ; every block from i on: [label der-or-()] in file order
   (blocks t i acc)
    (: p (fsub t "-----BEGIN " i)
       le (p < 0 ? -1 (fsub t "-----" (p + 11)))
       label (le < 0 ? "" (snip t (p + 11) le))
       end ("-----END " + label + "-----")
       q (le < 0 ? -1 (fsub t end (le + 5)))
       (q < 0 ? (rev acc)
          (blocks t (q + #end) ([label (b64 t (le + 5) q)] . acc))))
   (cert? b) (<b = "CERTIFICATE" || <b = "X509 CERTIFICATE")
   (? (#src = 0) (uwrite dst "")
      (snip src 0 7 = "pkcs11:") (die (src + ": a PKCS#11 token is not something hearts reads"))
      (: t (uread src @ [1 s] s (die (src + ": No such file or directory")))
         ders (map (b \ tlv (b 1)) (filter cert? (blocks t 0 ())))
         _ (two? ders || (die (src + ": no certificate in it")))
         _ (all string? ders || (die (src + ": a certificate block that is not a certificate")))
         (uwrite dst (join "" ders)))))
