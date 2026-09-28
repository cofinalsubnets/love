; apps/ssh/ed25519.l -- ed25519 (RFC 8032): the host key's signature and ours.
;
;   (ed-pub seed)            the 32-byte public key of a 32-byte seed
;   (ed-sign seed pub m)     the 64-byte signature of m
;   (ed-verify pub m sig)    1 | 0
;
; points are extended coordinates (X Y Z T) on -x^2 + y^2 = 1 + d x^2 y^2 over
; 2^255 - 19, the field by `%` as the x25519 ladder does it. d, the base point and
; sqrt(-1) are derived, not transcribed; only the group order L is written down.
; the arithmetic is not constant time: signing leaks timing, which matters for a key
; that signs often on a watched wire.
(module 'ssh
(borrow 'tls)
(:
   ed-q p25519
   (ed-mod a) ((a % ed-q + ed-q) % ed-q)
   (ed-mul a b) (ed-mod (a * b))
   (ed-inv a) (modpow a (ed-q - 2) ed-q)
   ed-d (ed-mul (ed-q - 121665) (ed-inv 121666))
   ed-i (modpow 2 ((ed-q - 1) // 4) ed-q)
   ed-l ((1 << 252) + 27742317777372353535851937790883648493)

   ; x from y and the sign bit, or -1 off the curve
   (ed-x y sign)
    (: yy (ed-mul y y)
       x2 (ed-mul (yy - 1) (ed-inv (ed-mul ed-d yy + 1)))
       x0 (modpow x2 ((ed-q + 3) // 8) ed-q)
       x1 (ed-mod (x0 * x0 - x2) = 0 ? x0 (ed-mul x0 ed-i))
       (? (ed-mod (x1 * x1 - x2) != 0) -1
          (x1 = 0 && sign = 1) -1
          ((x1 & 1) = sign) x1
          (ed-q - x1)))
   (ed-pt x y) [x y 1 (ed-mul x y)]
   ed-zero [0 1 1 0]
   ed-b (: y (ed-mul 4 (ed-inv 5)) (ed-pt (ed-x y 0) y))

   (ed-add p q)
    (: x1 (p 0) y1 (p 1) z1 (p 2) t1 (p 3) x2 (q 0) y2 (q 1) z2 (q 2) t2 (q 3)
       a (ed-mul (y1 - x1) (y2 - x2))
       b (ed-mul (y1 + x1) (y2 + x2))
       c (ed-mul (ed-mul t1 (2 * ed-d)) t2)
       d (ed-mul (2 * z1) z2)
       e (b - a) f (d - c) g (d + c) h (b + a)
       [(ed-mul e f) (ed-mul g h) (ed-mul f g) (ed-mul e h)])
   (ed-scale k p)
    (: (go i acc) (? (i < 0) acc
                     (: a2 (ed-add acc acc)
                        (go (i - 1) (k >> i & 1 ? (ed-add a2 p) a2))))
       (go (bitlen k) ed-zero))

   (ed-enc p)
    (: x (p 0) y (p 1)
       zi (ed-inv (p 2))
       (le-bytes (ed-mul y zi + ((ed-mul x zi & 1) << 255))))
   (ed-dec s)
    (: n (le-num s)
       y (n & (1 << 255) - 1)
       (? (#s != 32 || ed-q <= y) ()
          (: x (ed-x y (n >> 255)) (x < 0 ? () (ed-pt x y)))))

   (ed-hint s) (le-num (sha512 s) % ed-l)
   (ed-secret seed)
    (: h (sha512 seed)
       a (le-num (snip h 0 32))
       [(a & (1 << 254) - 8 | 1 << 254) (snip h 32 64)])

   (ed-pub seed) (ed-enc (ed-scale <(ed-secret seed) ed-b))
   (ed-sign seed pub m)
    (: sec (ed-secret seed) a <sec pre <>sec
       r (ed-hint (pre + m))
       rr (ed-enc (ed-scale r ed-b))
       k (ed-hint (rr + pub + m))
       (rr + le-bytes ((r + k * a) % ed-l)))
   (ed-verify pub m sig)
    (: a (ed-dec pub)
       rp (ed-dec (snip sig 0 32))
       s (le-num (snip sig 32 64))
       (? (#sig != 64 || atom? a || atom? rp || ed-l <= s) 0
          (: k (ed-hint ((snip sig 0 32) + pub + m))
             (ed-enc (ed-scale s ed-b) = ed-enc (ed-add rp (ed-scale k a)))))))
) ; module 'ssh
