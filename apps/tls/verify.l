; apps/tls/verify.l -- what the client needs to believe a server: the handshake's signature
; under the leaf's key, and the leaf itself, through its issuers, to a root it was handed.
;
;   (der s i end)            the tlv at i, inside end -> [tag cs ce st] | ()
;   (der-kids s cs ce)       a constructed value's children, tiling it exactly -> list | 0
;   (leaf-key der)           the certificate's key -> [kind key spki] | ()
;                            kind 'ed25519 (32 bytes), 'p256 'p384 or 'p521 ([x y]), 'rsa ([n e])
;   (cv-ok? k scheme sig m)  1 when sig is the leaf's signature of m under scheme
;   (x509 der)               a certificate read for path building -> a tablet | ()
;   (host-ok? c host)        1 when the certificate names host (rfc 6125, subjectAltName only)
;   (chain-ok? ders roots host now)   1, or the reason it is not, a string naming the
;                            check and the certificate; roots are x509s, now seconds
;   (pem-ders text)          the der of every CERTIFICATE block in a pem text
;   (tls-roots _)            [bundle-path anchors], the roots read once a process: the host's
;                            bundle, else the tree's own (apps/tls/roots.pem)
;
; CertificateVerify schemes: ed25519 (0x0807), ecdsa p-256/sha-256 (0x0403), ecdsa
; p-384/sha-384 (0x0503), rsa-pss/sha-256 (0x0804), rsa-pss/sha-384 (0x0805). a chain's own
; signatures: those, and rsa pkcs#1 v1.5 over sha-256/384/512; sha-1 and rsassa-pss certificate
; signatures are refused. no revocation is checked -- no crl, no ocsp. name constraints hold
; over dns and ip names, a root's as well as an issuer's; one on a kind of name not read here
; that could bear on a server (a directory name, say) refuses the chain. the key is public and so are the
; signatures, so the arithmetic is the plain bignums, no constant time owed. every reader
; here is total: a short or lying length answers (), never an index past the end.
(module 'tls
(borrow 'bytes)
(borrow 'cal)
(borrow 'posix)
(:
   (vsha s) (unhex (sha256 s))
   (vsha384 s) (unhex (sha384 s))
   (vsha512 s) (unhex (sha512 s))
   ; --- der: tag, length, content; short and long lengths up to three bytes ---
   (der s i end)
    (? (end < i + 2) ()
       (: tag (s i) l0 (s (i + 1))
          (? ((tag & 31) = 31 || l0 = 128 || 131 < l0) ()
             (: k (l0 < 128 ? 0 (l0 - 128))
                cs (i + 2 + k)
                n (k = 0 ? l0 (rdbe s (i + 2) k))
                ce (cs + n)
                (? (end < cs || end < ce) () [tag cs ce i])))))
   (der-kids s cs ce)
    (: (go i acc) (? (i = ce) (rev acc)
                     (: t (der s i ce) (? (atom? t) 0 (go (t 2) (t . acc)))))
       (go cs ()))
   ; a tlv of tag at i, else ()
   (der-at s t tag) (? (two? t && <t = tag) t ())
   ; a tlv's content, and the whole of it with its header
   (der-body s t) (snip s (t 1) (t 2))
   (der-all s t) (snip s (t 3) (t 2))
   ; the children of a tlv of tag, or 0
   (der-seq s t tag) (? (two? t && <t = tag) (der-kids s (t 1) (t 2)) 0)
   (be-num s) (foldl (a \ i \ a * 256 + s i) 0 ^#s)
   ; an unsigned integer's value, () for a negative or empty one
   (der-uint s t)
    (? (atom? t || <t != 2 || t 2 <= t 1 || 127 < s (t 1)) ()
       [(be-num (der-body s t))])

   ; small string helpers: the first index of sub from i or -1, ascii lower case, a quad's bytes
   (str-at s sub i) (: n #s m #sub (go j) (? (n - m < j) -1 (snip s j (j + m) = sub) j (go (j + 1))) (go i))
   (lower s) (string (map (i \ (: c (s i) (? (64 < c < 91) (c + 32) c))) ^#s))
   (be-num-dec p) (foldl (a \ i \ a * 10 + p i - 48) 0 ^#p)
   (quad-bytes h)
    (: ps (split "." h)
       ns (map (p \ (? (0 < #p && #p < 4 && all (i \ 47 < p i < 58) ^#p) (be-num-dec p) -1)) ps)
       (? (#ps = 4 && all (n \ 0 <= n && n < 256) ns) (catmap string ns) ()))
   (drop l k) (? (k < 1 || atom? l) l (drop >l (k - 1)))

   ; --- pem: every CERTIFICATE block of a text, its base64 undone -> a list of ders ---
   (b64v c) (? (64 < c < 91) (c - 65) (96 < c < 123) (c - 71) (47 < c < 58) (c + 4)
               (c = 43) 62 (c = 47) 63 -1)
   (b64-dec s i e)
    (: o (jug 0)
       (go i acc k) (? (e <= i) (slurp o)
                       (: v (b64v (s i))
                          (? (v < 0) (go (i + 1) acc k)
                             (: a (acc << 6 | v) k2 (k + 6)
                                (? (8 <= k2) (: _ (put o (a >> (k2 - 8))) (go (i + 1) (a & ((1 << (k2 - 8)) - 1)) (k2 - 8)))
                                   (go (i + 1) a k2))))))
       (go i 0 0))
   pem-begin "-----BEGIN CERTIFICATE-----"
   pem-end "-----END CERTIFICATE-----"
   (pem-ders t)
    (: (go i acc)
        (: b (str-at t pem-begin i)
           e (? (b < 0) -1 (str-at t pem-end (b + #pem-begin)))
           (? (e < 0) (rev acc)
              (go (e + #pem-end) (b64-dec t (b + #pem-begin) e . acc))))
       (go 0 ()))

   (bits-of n) (: (go n k) (? (n < 1) k (go (n >> 1) (k + 1))) (go n 0))

   ; --- ecdsa over a short weierstrass curve with a = -3 (sec 2, fips 186-4): a curve is
   ; [p n b gx gy], a point jacobian [x y z], z = 0 the point at infinity ---
   curve-p256
    (map (h \ be-num (unhex h))
         ["ffffffff00000001000000000000000000000000ffffffffffffffffffffffff"
          "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551"
          "5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b"
          "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296"
          "4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5"])
   curve-p384
    (map (h \ be-num (unhex h))
         [("fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe"
           + "ffffffff0000000000000000ffffffff")
          ("ffffffffffffffffffffffffffffffffffffffffffffffffc7634d81f4372ddf"
           + "581a0db248b0a77aecec196accc52973")
          ("b3312fa7e23ee7e4988e056be3f82d19181d9c6efe8141120314088f5013875a"
           + "c656398d8a2ed19d2a85c8edd3ec2aef")
          ("aa87ca22be8b05378eb1c71ef320ad746e1d3b628ba79b9859f741e082542a38"
           + "5502f25dbf55296c3a545e3872760ab7")
          ("3617de4a96262c6f5d9e98bf9292dc29f8f41dbd289a147ce9da3113b5f0b8c0"
           + "0a60b1ce1d7e819d7a431d7c90ea0e5f")])
   curve-p521
    (map (h \ be-num (unhex h))
         [("01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
           + "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
          ("01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
           + "fa51868783bf2f966b7fcc0148f709a5d03bb5c9b8899c47aebb6fb71e91386409")
          ("0051953eb9618e1c9a1f929a21a0b68540eea2da725b99b315f3b8b489918ef109"
           + "e156193951ec7e937b1652c0bd3bb1bf073573df883d2c34f1ef451fd46b503f00")
          ("00c6858e06b70404e9cd9e3ecb662395b4429c648139053fb521f828af606b4d3d"
           + "baa14b5e77efe75928fe1dc127a2ffa8de3348b3c1856a429bf97e7e31c2e5bd66")
          ("011839296a789a3bc0045c8a5fb42c7d1bd998f54449579b446817afbd17273e66"
           + "2c97ee72995ef42640c550b9013fad0761353c7086a272c24088be94769fd16650")])
   (curve-of kind) (? (kind = 'p256) curve-p256 (kind = 'p384) curve-p384 (kind = 'p521) curve-p521 ())
   (fm c a) (: p <c ((a % p + p) % p))
   (ec-on? c x y)
    (: p <c (x < p && y < p && fm c (y * y) = fm c (x * x * x - 3 * x + c 2)))
   (ec-dbl c q)
    (: x <q y <>q z (q 2) (m a) (fm c a)
       (? (z = 0 || y = 0) [1 1 0]
          (: dl (m (z * z)) gm (m (y * y)) be (m (x * gm))
             al (m (3 * (x - dl) * (x + dl)))
             x3 (m (al * al - 8 * be))
             z3 (m ((y + z) * (y + z) - gm - dl))
             [x3 (m (al * (4 * be - x3) - 8 * gm * gm)) z3])))
   (ec-add c a b)
    (? (a 2 = 0) b (b 2 = 0) a
       (: (m v) (fm c v)
          z1z1 (m (a 2 * a 2)) z2z2 (m (b 2 * b 2))
          u1 (m (<a * z2z2)) u2 (m (<b * z1z1))
          s1 (m (<>a * b 2 * z2z2)) s2 (m (<>b * a 2 * z1z1))
          h (m (u2 - u1)) r (m (s2 - s1))
          (? (h = 0) (? (r = 0) (ec-dbl c a) [1 1 0])
             (: hh (m (h * h)) hhh (m (h * hh)) v (m (u1 * hh))
                x3 (m (r * r - hhh - 2 * v))
                [x3 (m (r * (v - x3) - s1 * hhh)) (m (a 2 * b 2 * h))]))))
   ; u1 g + u2 q, the two ladders walked together
   (ec-twin c u1 u2 q)
    (: g [(c 3) (c 4) 1] gq (ec-add c g q)
       (go i acc) (? (i < 0) acc
                     (: a (ec-dbl c acc) b1 (u1 >> i & 1) b2 (u2 >> i & 1)
                        (go (i - 1) (? (b1 = 1 && b2 = 1) (ec-add c a gq)
                                       (b1 = 1) (ec-add c a g)
                                       (b2 = 1) (ec-add c a q)
                                       a))))
       (go (bits-of (c 1)) [1 1 0]))
   ; a der ecdsa signature of the digest h under key [x y] on curve c; a digest longer than
   ; the order is cut to its leftmost bits, as the standard says
   (ec-ok? c xy h sig)
    (: n (c 1)
       t (der sig 0 #sig)
       rs (? (two? t && <t = 48 && t 2 = #sig) (der-kids sig (t 1) (t 2)) 0)
       r (? (two? rs && #rs = 2) (der-uint sig <rs) ())
       s (? (two? rs && #rs = 2) (der-uint sig <>rs) ())
       cut (max 0 (8 * #h - bits-of n))
       (? (atom? c || atom? r || atom? s || <r < 1 || n <= <r || <s < 1 || n <= <s) 0
          (: w (modpow <s (n - 2) n)
             e ((be-num h >> cut) % n)
             pt (ec-twin c ((e * w) % n) ((<r * w) % n) [<xy <>xy 1])
             (? (pt 2 = 0) 0
                (: zi (modpow (pt 2) (<c - 2) <c)
                   (fm c (<pt * zi * zi) % n = <r ? 1 0))))))
   (p256-on? x y) (ec-on? curve-p256 x y)

   ; --- rsa: pss (rfc 8017 9.1.2, the salt a digest long, as tls 1.3 says) and pkcs#1 v1.5
   ; (8.2.2, the encoding rebuilt and compared whole) ---
   (mgf1 hf seed n)
    (: (go c acc) (? (n <= #acc) (snip acc 0 n) (go (c + 1) (acc + hf (seed + wrbe c 4))))
       (go 0 ""))
   (pss-ok? ne m sig) (pss-h? vsha ne m sig)
   (pss-h? hf ne m sig)
    (: n <ne e <>ne k ((bits-of n + 7) // 8) mb (bits-of n - 1) el ((mb + 7) // 8)
       zb (8 * el - mb) hl #(hf "")
       (? (#sig != k || el < 2 * hl + 2) 0
          (: s (be-num sig)
             x (? (s < n) (modpow s e n) n)
             (? (n <= x || 0 < (x >> (8 * el))) 0
                (: em (wrbe x el)
                   md (snip em 0 (el - hl - 1)) h (snip em (el - hl - 1) (el - 1))
                   (? (em (el - 1) != 188 || 0 < ((md 0) & (255 - (255 >> zb)))) 0
                      (: db0 (xorb md (mgf1 hf h (el - hl - 1)))
                         db (string ((db0 0) & (255 >> zb)) + snip db0 1 #db0)
                         pl (el - 2 * hl - 2)
                         (? (!(snip db 0 pl = zbytes pl) || db pl != 1) 0
                            (h = hf (zbytes 8 + hf m + snip db (pl + 1) #db) ? 1 0)))))))))
   ; the DigestInfo ahead of each digest
   di-sha256 (unhex "3031300d060960864801650304020105000420")
   di-sha384 (unhex "3041300d060960864801650304020205000430")
   di-sha512 (unhex "3051300d060960864801650304020305000440")
   (pkcs1-ok? ne di hf m sig)
    (: n <ne e <>ne k ((bits-of n + 7) // 8) t (di + hf m)
       (? (#sig != k || k < #t + 11) 0
          (: s (be-num sig)
             (? (n <= s) 0
                (wrbe (modpow s e n) k = (string 0 + string 1 + bytes (k - #t - 3) (i \ 255) + string 0 + t)
                 ? 1 0)))))

   ; --- a key off its SubjectPublicKeyInfo ---
   oid-ed25519 (unhex "2b6570")
   oid-ec (unhex "2a8648ce3d0201")
   oid-p256 (unhex "2a8648ce3d030107")
   oid-p384 (unhex "2b81040022")
   oid-p521 (unhex "2b81040023")
   oid-rsa (unhex "2a864886f70d010101")
   ; the spki's tlv in c -> [kind key spki] | ()
   (spki-key c sp)
    (: ks (der-seq c sp 48)
       alg (? (two? ks && #ks = 2) (der-seq c <ks 48) 0)
       bits (? (two? ks && #ks = 2) (der-at c <>ks 3) ())
       (? (atom? alg || atom? bits || <<alg != 6 || bits 2 <= bits 1 || c (bits 1) != 0) ()
          (: oid (der-body c <alg)
             par (? (two? >alg) (der-body c <>alg) "")
             key (snip c (bits 1 + 1) (bits 2))
             spki (der-all c sp)
             kind (? (oid != oid-ec) () (par = oid-p256) 'p256 (par = oid-p384) 'p384 (par = oid-p521) 'p521 ())
             w (? (kind = 'p384) 48 (kind = 'p521) 66 32)
             (? (oid = oid-ed25519 && #key = 32) ['ed25519 key spki]
                (kind && #key = 2 * w + 1 && key 0 = 4)
                 (: x (be-num (snip key 1 (w + 1))) y (be-num (snip key (w + 1) (2 * w + 1)))
                    (ec-on? (curve-of kind) x y ? [kind [x y] spki] ()))
                (oid = oid-rsa)
                 (: r (der key 0 #key)
                    ne (? (two? r && <r = 48 && r 2 = #key) (der-kids key (r 1) (r 2)) 0)
                    n (? (two? ne && #ne = 2) (der-uint key <ne) ())
                    e (? (two? ne && #ne = 2) (der-uint key <>ne) ())
                    (? (two? n && two? e && 2 < <e && 1024 <= bits-of <n) ['rsa [<n <e] spki] ()))
                ()))))
   ; the tbs's fields, the version dropped when present: serial, sigalg, issuer, validity,
   ; subject, spki, then the optional rest
   (tbs-fields c)
    (: top (der c 0 #c)
       tk (? (two? top && top 2 = #c) (der-seq c top 48) 0)
       tbs (? (two? tk && 3 = #tk) (der-seq c <tk 48) 0)
       (? (atom? tbs) () [tk (? (<<tbs = 160) >tbs tbs)]))
   (leaf-key c)
    (: f (tbs-fields c) fs (? (two? f) (f 1) ())
       (? (two? fs && 5 < #fs) (spki-key c (fs 5)) ()))

   ; --- the certificate verify: the message the server signed, and its check ---
   (cv-msg tr-hash) (bytes 64 (i \ 32) + "TLS 1.3, server CertificateVerify" + string 0 + tr-hash)
   (cv-ok? k scheme sig m)
    (: kind <k key <>k
       (? (scheme = 2055 && kind = 'ed25519)
           (: v (cite 'ssh 'ed-verify) (? (lit? v) (v key m sig ? 1 0) 0))
          (scheme = 1027 && kind = 'p256) (ec-ok? curve-p256 key (vsha m) sig)
          (scheme = 1283 && kind = 'p384) (ec-ok? curve-p384 key (vsha384 m) sig)
          (scheme = 2052 && kind = 'rsa) (pss-h? vsha key m sig)
          (scheme = 2053 && kind = 'rsa) (pss-h? vsha384 key m sig)
          0))

   ; --- a certificate's signature, by the oid of its algorithm, under its issuer's key ---
   (sig-ok? alg k m sig)
    (: kind <k key <>k
       (? (kind = 'rsa)
           (? (alg = unhex "2a864886f70d01010b") (pkcs1-ok? key di-sha256 vsha m sig)
              (alg = unhex "2a864886f70d01010c") (pkcs1-ok? key di-sha384 vsha384 m sig)
              (alg = unhex "2a864886f70d01010d") (pkcs1-ok? key di-sha512 vsha512 m sig)
              0)
          (elem kind '(p256 p384 p521))
           (: hf (? (alg = unhex "2a8648ce3d040302") vsha (alg = unhex "2a8648ce3d040303") vsha384
                    (alg = unhex "2a8648ce3d040304") vsha512 ())
              (? hf (ec-ok? (curve-of kind) key (hf m) sig) 0))
          (kind = 'ed25519 && alg = oid-ed25519)
           (: v (cite 'ssh 'ed-verify) (? (lit? v) (v key m sig ? 1 0) 0))
          0))

   ; --- x.509, what path building reads ---
   ; a time as seconds since 1970: UTCTime YYMMDDHHMMSSZ (50..99 the 1900s) or
   ; GeneralizedTime YYYYMMDDHHMMSSZ, only the Z form; () for anything else
   (x509-time s t)
    (: b (? (two? t) (der-body s t) "")
       n #b
       (dig? i) (47 < b i < 58)
       (num i k) (: (go j a) (? (k <= j) a (go (j + 1) (a * 10 + b (i + j) - 48))) (go 0 0))
       ok (? (two? t && ((<t = 23 && n = 13) || (<t = 24 && n = 15)) && b (n - 1) = 90)
             (all dig? ^(n - 1)) 0)
       (? !ok ()
          (: y (? (<t = 24) (num 0 4) (: v (num 0 2) (v < 50 ? (2000 + v) (1900 + v))))
             o (? (<t = 24) 4 2)
             mo (num o 2) d (num (o + 2) 2) h (num (o + 4) 2) mi (num (o + 6) 2) sc (num (o + 8) 2)
             (? (mo < 1 || 12 < mo || d < 1 || 31 < d || 23 < h || 59 < mi || 60 < sc) ()
                [((epoch-days y mo d * 86400) + (h * 3600) + (mi * 60) + sc)]))))
   ; the extensions this reader answers to; a critical one outside them refuses the certificate
   oid-bc (unhex "551d13") oid-ku (unhex "551d0f") oid-eku (unhex "551d25") oid-san (unhex "551d11")
   oid-server-auth (unhex "2b06010505070301") oid-any-eku (unhex "551d2500")
   oid-cn (unhex "550403") oid-nc (unhex "551d1e")
   (x509 c)
    (: f (tbs-fields c)
       tk (? (two? f) <f ()) fs (? (two? f) (f 1) ())
       ok (two? fs && 5 < #fs && <(fs 1) = 48 && <(fs 2) = 48 && <(fs 3) = 48 && <(fs 4) = 48)
       outer (? ok (der-seq c (tk 1) 48) 0)
       sigb (? ok (der-at c (tk 2) 3) ())
       vl (? ok (der-seq c (fs 3) 48) 0)
       key (? ok (spki-key c (fs 5)) ())
       (? (!ok || atom? outer || atom? sigb || atom? vl || #vl != 2 || atom? key
           || sigb 2 <= sigb 1 || c (sigb 1) != 0 || <<outer != 6) ()
          (: nb (x509-time c <vl) na (x509-time c <>vl)
             x (tablet 16)
             _ (pins x 'der c 'tbs (der-all c <tk) 'alg (der-body c <outer)
                     'inner (der-body c (fs 1)) 'sig (snip c (sigb 1 + 1) (sigb 2))
                     'issuer (der-all c (fs 2)) 'subject (der-all c (fs 4))
                     'nb (? (two? nb) <nb ()) 'na (? (two? na) <na ()) 'key key
                     'ca 0 'plen () 'ku () 'eku () 'dns () 'ips () 'ncp () 'nce () 'bad ())
             ; the inner and outer signature algorithms must agree (their oids, what we check by)
             ino (der-seq c (fs 1) 48)
             _ (? (two? ino && <<ino = 6 && der-body c <ino = x 'alg) 0 (pin x 'bad "its two signature algorithms differ"))
             ext (filter (t \ <t = 163) (drop fs 6))
             es (? (two? ext) (: s (der-seq c <ext 163) (? (two? s) (der-seq c <s 48) 0)) ())
             _ (? (two? ext && atom? es) (pin x 'bad "its extensions do not read") 0)
             _ (? (two? es) (x509-exts x c es) 0)
             x)))
   ; every extension into x; the first thing wrong is 'bad
   (x509-exts x c es)
    (: seen (tablet 8)
       (one t)
        (: e (der-seq c t 48)
           oid (? (two? e && <<e = 6) (der-body c <e) ())
           crit (? (two? e && 3 = #e && <(e 1) = 1) (der-body c (e 1) = string 255) 0)
           val (? (two? e) (der-at c (last e) 4) ())
           (? (!(string? oid) || atom? val) (pin x 'bad "an extension does not read")
              (peep seen oid 0) (pin x 'bad "an extension appears twice")
              (: _ (pin seen oid 1)
                 v (der c (val 1) (val 2))                  ; the extension's own value
                 (? (atom? v || v 2 != val 2) (pin x 'bad "an extension's value does not read")
                    (oid = oid-bc)
                     (: s (der-seq c v 48)
                        ca (? (two? s && <<s = 1) (der-body c <s = string 255) 0)
                        pl (? (two? s) (: l (filter (t \ <t = 2) s) (? (two? l) (der-uint c <l) ())) ())
                        (? (atom? s && !(s = ())) (pin x 'bad "its basicConstraints does not read")
                           (pins x 'ca (? ca 1 0) 'plen (? (two? pl) <pl ()))))
                    (oid = oid-ku)
                     (? (<v = 3 && v 1 + 1 < v 2 && v 2 - v 1 < 6) (pin x 'ku (be-num (snip c (v 1 + 1) (v 2)) << (8 * (4 - (v 2 - v 1 - 1)))))
                        (pin x 'bad "its keyUsage does not read"))
                    (oid = oid-eku)
                     (: s (der-seq c v 48)
                        (? (two? s && all (t \ <t = 6) s) (pin x 'eku (map (t \ der-body c t) s))
                           (pin x 'bad "its extendedKeyUsage does not read")))
                    (oid = oid-san)
                     (: s (der-seq c v 48)
                        (? (two? s)
                            (pins x 'dns (map (t \ der-body c t) (filter (t \ <t = 130) s))
                                    'ips (map (t \ der-body c t) (filter (t \ <t = 135) s)))
                           (pin x 'bad "its subjectAltName does not read")))
                    (oid = oid-nc)                 ; [0] permitted, [1] excluded: subtrees of [tag base]
                     (: s (der-seq c v 48)
                        (sub t) (: g (der-seq c t 48) (? (two? g && #g = 1) [(<g 0) (der-body c <g)] ()))
                        (part tag) (: p (filter (t \ <t = tag) s)
                                      (? (atom? p) ()
                                         (: ts (der-kids c (<p 1) (<p 2)) gs (? (two? ts) (map sub ts) ())
                                            (? (#p = 1 && two? gs && all two? gs) gs 'no))))
                        pm (? (two? s) (part 160) 'no) ex (? (two? s) (part 161) 'no)
                        (? (pm = 'no || ex = 'no || (atom? pm && atom? ex)) (pin x 'bad "its nameConstraints does not read")
                           (pins x 'ncp pm 'nce ex)))
                    crit (pin x 'bad "a critical extension it does not know")
                    0))))
       (each es one))
   ; keyUsage's keyCertSign, bit 5 counted from the top of the first byte (the value was
   ; shifted to 32 bits above, so the top byte is the first)
   (x509-certsign? x) (: k (x 'ku) (? (charm? k) (0 < (k & (4 << 24))) 1))
   ; a certificate's common name for a person to read, or its subject's length
   (x509-name x)
    (: s (x 'subject)
       (go i) (: j (str-at s oid-cn i)
                 (? (j < 0) ("a certificate of " + show #s + " bytes of subject")
                    (: t (der s (j + #oid-cn) #s) (? (two? t) ("\"" + der-body s t + "\"") (go (j + 1))))))
       (go 0))

   ; --- the name: rfc 6125 over subjectAltName; the common name is never read ---
   (dns-match? pat host)
    (: p (lower pat) h (lower host)
       (? (p = h) 1
          (#p < 3 || snip p 0 2 != "*.") 0
          (: rest (snip p 1 #p)                          ; ".example.com"
             k (str-at h "." 0)
             (? (k < 1 || elem 42 (map (i \ rest i) ^#rest)) 0
                (#(split "." rest) < 3) 0                 ; "*.com" names a whole suffix
                (snip h k #h = rest ? 1 0)))))
   (host-ok? x host)
    (: h (? (0 < #host && host (#host - 1) = 46) (snip host 0 (#host - 1)) host)
       q (quad-bytes h)
       (? (string? q) (? (elem q (x 'ips)) 1 0)
          (any (d \ dns-match? d h) (x 'dns) ? 1 0)))

   ; --- name constraints (rfc 5280 4.2.1.10): the names a ca may vouch for, dns and ip ---
   ; n within subtree b: "sb.test" holds itself and every name under it, ".sb.test" only
   ; those under it, "" every name
   (dns-in? b n)
    (: b (lower b) n (lower n)
       (? (b = "" || b = n && b 0 != 46) 1
          (b 0 = 46) (#b < #n && snip n (#n - #b) #n = b)
          (#b < #n && snip n (#n - #b - 1) #n = ("." + b))))
   ; address a within base b, an address and its mask of the same family
   (ip-in? b a) (: k #a (? (#b != 2 * k) 0 (all (i \ (a i & b (k + i)) = (b i & b (k + i))) ^k)))
   (nm-of x) ((map (d \ [130 d]) (x 'dns)) + (map (a \ [135 a]) (x 'ips)))
   (nm-show n) (? (<n = 130) (n 1) (#(n 1) = 4) (join "." (map (i \ show ((n 1) i)) ^4)) "an ipv6 address")
   ; one name against x's constraints -> () when x may vouch for it, else why not. a wildcard
   ; reaches every name one label down, so an excluded name there is reached
   (nc-why x nm)
    (: t <nm v (nm 1)
       p (filter (g \ <g = t) (x 'ncp)) e (filter (g \ <g = t) (x 'nce))
       (in? g) (? (t = 130) (dns-in? (g 1) v) (ip-in? (g 1) v))
       (reach? g) (? (t = 130 && 2 < #v && snip v 0 2 = "*.")
                     (: b (lower (g 1)) k (str-at b "." 0) (0 < k && snip b (k + 1) #b = lower (snip v 2 #v)))
                     0)
       (? (two? p && !(any in? p)) "is outside the names it may vouch for"
          (any (g \ in? g || reach? g) e) "is among the names it may not vouch for"
          ()))
   ; x's constraints over the names below it -> () or why not. email and uri subtrees bear on
   ; no name a server is checked by; any other kind is one this cannot check, and refuses
   (nc-sick x nms)
    (: gs ((x 'ncp) + (x 'nce))
       (? (atom? gs) ()
          (any (g \ !(elem <g [129 130 134 135])) gs) "it constrains a kind of name not checked here"
          (: bad (filter (n \ nc-why x n) nms)
             (? (two? bad) ("the name " + nm-show <bad + " " + nc-why x <bad) ()))))

   ; --- the roots: the host's bundle, read once a process ---
   ; SSL_CERT_FILE, else the first of the linux and bsd homes that reads, else the tree's own:
   ; mozilla's roots for serving tls as curl extracts them, apps/tls/roots.pem, which inle and
   ; the wasm seat read under /proc/src and a host with no bundle out of the source its binary
   ; carries
   tree-roots "apps/tls/roots.pem"
   root-homes ["/etc/ssl/certs/ca-certificates.crt" "/etc/ssl/cert.pem"
               "/etc/pki/tls/certs/ca-bundle.crt" "/usr/local/share/certs/ca-root-nss.crt"
               ("/proc/src/" + tree-roots)]
   roots-box {}
   (root-file _)
    (: e (getenv "SSL_CERT_FILE")
       (? (string? e && 0 < #e) e
          (: l (filter (p \ two? (stat p)) root-homes) (? (two? l) <l ()))))
   ; the tree's roots out of the carried source, the archive's paths under one top word ->
   ; the pem text | ()
   (carried-roots _)
    (: unzip (cite 'gz 'gz-unzip) unpack (cite 'tar 'tar-unpack) a (source-gz 0)
       u (? (lit? unzip && string? a && 0 < #a) (unzip a) ())
       es (? (lit? unpack && two? u) (unpack <>u) ())
       (at? e) (: n (e 'nom) k (#n - #tree-roots)
                  (string? n && 0 < k && n (k - 1) = 47 && snip n k #n = tree-roots))
       hit (? (two? es) (filter at? <>es) ())
       (? (two? hit) (<hit 'body) ()))
   ; the anchors, x509s, for the bundle in force -> [path anchors] ; () anchors when none reads.
   ; the carried copy answers the path "<carried>"
   (tls-roots _)
    (: p (root-file 0)
       key (? (string? p) p "<carried>")
       c (roots-box key)
       (? (two? c) [key <c]
          (: t (? (string? p) (: r (uread p) (? (two? r) <>r ())) (carried-roots 0))
             xs (? (string? t) (filter tablet? (map x509 (pem-ders t))) ())
             _ (pin roots-box key [xs])
             [(? (string? p) p (two? xs) key ()) xs])))

   ; --- the path: leaf, issuers, an anchor ---
   chain-depth 8
   chain-work 40
   ; a certificate's own trouble at time now, or ()
   (x509-sick x now)
    (? (string? (x 'bad)) (x 'bad)
       (!(charm? (x 'nb)) || !(charm? (x 'na))) "its validity does not read"
       (now < x 'nb) "it is not valid yet"
       (x 'na < now) "it has expired"
       ())
   ; a leaf's own checks: its dates, its purpose, the name
   (leaf-sick x host now)
    (: s (x509-sick x now) eku (x 'eku)
       (? s s
          (two? eku && !(elem oid-server-auth eku) && !(elem oid-any-eku eku)) "it is not for serving tls"
          !(host-ok? x host) ("it does not name " + host)
          ()))
   ; x as an issuer with k certificates under it before the leaf's
   (issuer-sick x k now)
    (: s (x509-sick x now)
       (? s s
          (x 'ca != 1) "it is not a certificate authority"
          !(x509-certsign? x) "its keyUsage does not allow signing certificates"
          (charm? (x 'plen) && x 'plen < k) "its pathLen is exceeded"
          ()))
   ; -> 1, or why not, naming the certificate
   (chain-ok? ders roots host now)
    (: xs (map x509 ders)
       leaf (? (two? xs) <xs ())
       pool (? (two? xs) (filter tablet? >xs) ())
       work (tablet 1) _ (pin work 'n 0)
       (why x s) ("certificate " + x509-name x + ": " + s)
       ; from certificate c at k issuers above the leaf, nms the names of c and all below it: an
       ; anchor that signed it and may vouch for them, else an issuer from the pool, walked on;
       ; the most telling reason is kept for the failure
       (up c k used nms)
        (? (chain-depth < k) (why c "the chain is too long")
           (: n (work 'n)
              (? (chain-work < n) (why c "too much work to find its issuer")
                 (: _ (pin work 'n (n + 1))
                    as (filter (r \ r 'subject = c 'issuer) roots)
                    ; an anchor needs no checks of its own but its key and its pathLen
                    signed (filter (r \ !(charm? (r 'plen) && r 'plen < k) && 1 = sig-ok? (c 'alg) (r 'key) (c 'tbs) (c 'sig)) as)
                    hit (any (r \ !(nc-sick r nms)) signed)
                    (? hit 1
                       (two? signed) (why <signed (nc-sick <signed nms))
                       (: cs (filter (i \ i 'subject = c 'issuer && !(elem (i 'der) used)) pool)
                          (try l best)
                           (? (atom? l) best
                              (: i <l
                                 root? (any (r \ r 'der = i 'der) roots)
                                 s0 (? root? () (issuer-sick i k now))
                                 s (? s0 s0 (nc-sick i nms))
                                 r (? s (why i s)
                                      (1 != sig-ok? (c 'alg) (i 'key) (c 'tbs) (c 'sig)) (why c "its signature does not verify")
                                      root? 1
                                      (up i (k + 1) (i 'der . used) (nms + nm-of i)))
                                 (? (r = 1) 1 (try >l r))))
                          (try cs (? (two? as) (why c "its signature does not verify")
                                     (why c "no issuer for it is known (a missing intermediate, or a root not trusted here)")))))))))
       (? !(tablet? leaf) "the server sent no certificate that reads"
          (: s (leaf-sick leaf host now)
             (? s (why leaf s) (up leaf 0 [(leaf 'der)] (nm-of leaf)))))))
) ; module tls
