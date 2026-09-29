; apps/tls/verify.l -- what the client needs to believe a CertificateVerify: the leaf's
; public key off its der, and the three signatures it can check with one.
;
;   (der s i end)            the tlv at i, inside end -> [tag cs ce st] | ()
;   (der-kids s cs ce)       a constructed value's children, tiling it exactly -> list | 0
;   (leaf-key der)           the certificate's key -> [kind key spki] | ()
;                            kind 'ed25519 (32 bytes), 'p256 ([x y]), 'rsa ([n e])
;   (cv-ok? k scheme sig m)  1 when sig is the leaf's signature of m under scheme
;
; schemes: ed25519 (0x0807), ecdsa_secp256r1_sha256 (0x0403), rsa_pss_rsae_sha256 (0x0804).
; the key is public and so are the signatures, so the arithmetic is the plain bignums,
; no constant time owed. every reader here is total: a short or lying length answers
; (), never an index past the end.
(module 'tls
(borrow 'bytes)
(:
   (vsha s) (unhex (sha256 s))
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
   (be-num s) (foldl (a \ i \ a * 256 + s i) 0 ^#s)
   ; an unsigned integer's value, () for a negative or empty one
   (der-uint s t)
    (? (atom? t || <t != 2 || t 2 <= t 1 || 127 < s (t 1)) ()
       [(be-num (snip s (t 1) (t 2)))])

   (bits-of n) (: (go n k) (? (n < 1) k (go (n >> 1) (k + 1))) (go n 0))

   ; --- p-256 (sec 2, fips 186-4), jacobian over a = -3; z = 0 is the point at infinity ---
   p256-p (be-num (unhex "ffffffff00000001000000000000000000000000ffffffffffffffffffffffff"))
   p256-n (be-num (unhex "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551"))
   p256-b (be-num (unhex "5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b"))
   p256-g [(be-num (unhex "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296"))
           (be-num (unhex "4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5"))
           1]
   (pm a) ((a % p256-p + p256-p) % p256-p)
   (p256-on? x y)
    (x < p256-p && y < p256-p && pm (y * y) = pm (x * x * x - 3 * x + p256-b))
   (p256-dbl q)
    (: x <q y <>q z (q 2)
       (? (z = 0 || y = 0) [1 1 0]
          (: dl (pm (z * z)) gm (pm (y * y)) be (pm (x * gm))
             al (pm (3 * (x - dl) * (x + dl)))
             x3 (pm (al * al - 8 * be))
             z3 (pm ((y + z) * (y + z) - gm - dl))
             [x3 (pm (al * (4 * be - x3) - 8 * gm * gm)) z3])))
   (p256-add a b)
    (? (a 2 = 0) b (b 2 = 0) a
       (: z1z1 (pm (a 2 * a 2)) z2z2 (pm (b 2 * b 2))
          u1 (pm (<a * z2z2)) u2 (pm (<b * z1z1))
          s1 (pm (<>a * b 2 * z2z2)) s2 (pm (<>b * a 2 * z1z1))
          h (pm (u2 - u1)) r (pm (s2 - s1))
          (? (h = 0) (? (r = 0) (p256-dbl a) [1 1 0])
             (: hh (pm (h * h)) hhh (pm (h * hh)) v (pm (u1 * hh))
                x3 (pm (r * r - hhh - 2 * v))
                [x3 (pm (r * (v - x3) - s1 * hhh)) (pm (a 2 * b 2 * h))]))))
   ; u1 g + u2 q, the two ladders walked together
   (p256-twin u1 u2 q)
    (: gq (p256-add p256-g q)
       (go i acc) (? (i < 0) acc
                     (: a (p256-dbl acc) b1 (u1 >> i & 1) b2 (u2 >> i & 1)
                        (go (i - 1) (? (b1 = 1 && b2 = 1) (p256-add a gq)
                                       (b1 = 1) (p256-add a p256-g)
                                       (b2 = 1) (p256-add a q)
                                       a))))
       (go 255 [1 1 0]))
   ; a der ecdsa signature of the 32-byte digest h under key [x y]
   (p256-ok? xy h sig)
    (: t (der sig 0 #sig)
       rs (? (two? t && <t = 48 && t 2 = #sig) (der-kids sig (t 1) (t 2)) 0)
       r (? (two? rs && #rs = 2) (der-uint sig <rs) ())
       s (? (two? rs && #rs = 2) (der-uint sig <>rs) ())
       (? (atom? r || atom? s || <r < 1 || p256-n <= <r || <s < 1 || p256-n <= <s) 0
          (: w (modpow <s (p256-n - 2) p256-n)
             e (be-num h % p256-n)
             pt (p256-twin ((e * w) % p256-n) ((<r * w) % p256-n) [<xy <>xy 1])
             (? (pt 2 = 0) 0
                (: zi (modpow (pt 2) (p256-p - 2) p256-p)
                   (pm (<pt * zi * zi) % p256-n = <r ? 1 0))))))

   ; --- rsassa-pss (rfc 8017 9.1.2) over sha-256, the salt a digest long, as tls 1.3 says ---
   (mgf1 seed n)
    (: (go c acc) (? (n <= #acc) (snip acc 0 n) (go (c + 1) (acc + vsha (seed + wrbe c 4))))
       (go 0 ""))
   (pss-ok? ne m sig)
    (: n <ne e <>ne k ((bits-of n + 7) // 8) mb (bits-of n - 1) el ((mb + 7) // 8)
       zb (8 * el - mb)
       (? (#sig != k || el < 66) 0
          (: s (be-num sig)
             x (? (s < n) (modpow s e n) n)
             (? (n <= x || 0 < (x >> (8 * el))) 0
                (: em (wrbe x el)
                   md (snip em 0 (el - 33)) h (snip em (el - 33) (el - 1))
                   (? (em (el - 1) != 188 || 0 < ((md 0) & (255 - (255 >> zb)))) 0
                      (: db0 (xorb md (mgf1 h (el - 33)))
                         db (string ((db0 0) & (255 >> zb)) + snip db0 1 #db0)
                         pl (el - 66)
                         (? (!(snip db 0 pl = zbytes pl) || db pl != 1) 0
                            (h = vsha (zbytes 8 + vsha m + snip db (pl + 1) #db) ? 1 0)))))))))

   ; --- the leaf's key ---
   oid-ed25519 (unhex "2b6570")
   oid-ec (unhex "2a8648ce3d0201")
   oid-p256 (unhex "2a8648ce3d030107")
   oid-rsa (unhex "2a864886f70d010101")
   (leaf-key c)
    (: top (der c 0 #c)
       tk (? (two? top && <top = 48 && top 2 = #c) (der-kids c (top 1) (top 2)) 0)
       tbs (? (two? tk && <<tk = 48) (der-kids c (<tk 1) (<tk 2)) 0)
       fs (? (two? tbs && <<tbs = 160) >tbs tbs)          ; the version, when present
       sp (? (two? fs && 5 < #fs) (der-at c (fs 5) 48) ())
       ks (? (two? sp) (der-kids c (sp 1) (sp 2)) 0)
       alg (? (two? ks && #ks = 2 && <<ks = 48) (der-kids c (<ks 1) (<ks 2)) 0)
       bits (? (two? ks && #ks = 2) (der-at c <>ks 3) ())
       (? (atom? alg || atom? bits || <<alg != 6 || bits 2 <= bits 1 || c (bits 1) != 0) ()
          (: oid (snip c (<alg 1) (<alg 2))
             par (? (two? >alg) (snip c (<>alg 1) (<>alg 2)) "")
             key (snip c (bits 1 + 1) (bits 2))
             spki (snip c (sp 3) (sp 2))
             (? (oid = oid-ed25519 && #key = 32) ['ed25519 key spki]
                (oid = oid-ec && par = oid-p256 && #key = 65 && key 0 = 4)
                 (: x (be-num (snip key 1 33)) y (be-num (snip key 33 65))
                    (p256-on? x y ? ['p256 [x y] spki] ()))
                (oid = oid-rsa)
                 (: r (der key 0 #key)
                    ne (? (two? r && <r = 48 && r 2 = #key) (der-kids key (r 1) (r 2)) 0)
                    n (? (two? ne && #ne = 2) (der-uint key <ne) ())
                    e (? (two? ne && #ne = 2) (der-uint key <>ne) ())
                    (? (two? n && two? e && 2 < <e && 1024 <= bits-of <n) ['rsa [<n <e] spki] ()))
                ()))))

   ; --- the certificate verify: the message the server signed, and its check ---
   (cv-msg tr-hash) (bytes 64 (i \ 32) + "TLS 1.3, server CertificateVerify" + string 0 + tr-hash)
   (cv-ok? k scheme sig m)
    (: kind <k key <>k
       (? (scheme = 2055 && kind = 'ed25519)
           (: v (cite 'ssh 'ed-verify) (? (lit? v) (v key m sig ? 1 0) 0))
          (scheme = 1027 && kind = 'p256) (p256-ok? key (vsha m) sig)
          (scheme = 2052 && kind = 'rsa) (pss-ok? key m sig)
          0)))
) ; module tls
