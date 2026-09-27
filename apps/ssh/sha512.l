; apps/ssh/sha512.l -- sha-512 (FIPS 180-4), the hash ed25519 is defined over.
;
;   (sha512 s)   the 64-byte digest of the string s
;
; the words are 64 bits, past a charm, so they ride the bignums; ed25519 hashes a
; hundred bytes a handshake and this is milliseconds there. the round constants are
; not transcribed: K is the cube roots and H0 the square roots of the first primes,
; their fractional 64 bits, which is what the standard says they are.
(module 'ssh
(borrow 'tls)
(:
   m64 ((1 << 64) - 1)
   (bitlen n) (: (go n k) (? (n < 1) k (go (n >> 1) (k + 1))) (go n 0))
   ; floor of the r-th root, newton from above
   (iroot r n)
    (: (go x) (: y ((((r - 1) * x) + (n // (r - 1) x)) // r) (? (y < x) (go y) x))
       (go (1 << ((bitlen n // r) + 1))))
   (primes k)
    (: (prime? n) (: (go d) (? (n < (d * d)) 1 ((n % d) = 0) 0 (go (d + 1))) (go 2))
       (go n l) (? (k <= #l) (rev l) (go (n + 1) (? (prime? n) (n . l) l)))
       (go 2 ()))
   (frac64 r p) ((iroot r (p << (64 * r))) & m64)
   sha512-k (map (frac64 3) (primes 80))
   sha512-h (map (frac64 2) (primes 8))

   (rotr x n) (((x >> n) | (x << (64 - n))) & m64)
   (be64 s i) (: (go j a) (? (j = 8) a (go (j + 1) ((a << 8) | s (i + j)))) (go 0 0))
   (add64 a b) ((a + b) & m64)

   ; one 128-byte block into the eight-word state h
   (sha512-block h s o)
    (: w (tablet 80)
       _ (each ^16 (t \ pin w t (be64 s (o + (8 * t)))))
       (sig0 x) (rotr x 1 ^ rotr x 8 ^ (x >> 7))
       (sig1 x) (rotr x 19 ^ rotr x 61 ^ (x >> 6))
       _ (each (map (+ 16) ^64)
               (t \ pin w t (add64 (add64 (sig1 (w (t - 2))) (w (t - 7)))
                                   (add64 (sig0 (w (t - 15))) (w (t - 16))))))
       (round v k t)
        (: a (v 0) b (v 1) c (v 2) d (v 3) e (v 4) f (v 5) g (v 6) hh (v 7)
           s1 (rotr e 14 ^ rotr e 18 ^ rotr e 41)
           ch ((e & f) ^ ((m64 ^ e) & g))
           t1 (add64 (add64 (add64 hh s1) (add64 ch k)) (w t))
           s0 (rotr a 28 ^ rotr a 34 ^ rotr a 39)
           mj ((a & b) ^ (a & c) ^ (b & c))
           [(add64 t1 (add64 s0 mj)) a b c (add64 d t1) e f g])
       (go v ks t) (? (t = 80) v (go (round v <ks t) >ks (t + 1)))
       (zipw a b) (? (two? a) (add64 <a <b . zipw >a >b))
       (zipw h (go h sha512-k 0)))

   (sha512 s)
    (: n #s
       pad (s + string 128 + zeros ((((111 - n) % 128) + 128) % 128) + zeros 8 + u64be (n * 8))
       (go h o) (? (#pad <= o) h (go (sha512-block h pad o) (o + 128)))
       (foldl (+) "" (map u64be (go sha512-h 0)))))
) ; module 'ssh
