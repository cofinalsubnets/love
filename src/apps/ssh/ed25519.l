; src/apps/ssh/ed25519.l -- ed25519 (RFC 8032): the host key's signature and ours.
;
;   (ed-pub seed)            the 32-byte public key of a 32-byte seed
;   (ed-sign seed pub m)     the 64-byte signature of m
;   (ed-verify pub m sig)    1 | 0
;
; points are extended coordinates (X Y Z T) on -x^2 + y^2 = 1 + d x^2 y^2 over 2^255 - 19.
; d, the base point and sqrt(-1) are derived, not transcribed; only the group order L is
; written down. signing runs on p256.l's limbs: field and scalar elements are ten 26-bit
; montgomery limbs, the scalar walks 64 nibbles through a masked table, and the digest's
; reduction mod L and s = r + k a are limb products, so no secret meets a bignum or a `?`.
; verify handles only public values and rides the bignums, which are faster.
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

   ; --- verify's side: public points on the bignums ---
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

   ; --- signing's side: limbs, the field mod q and the scalars mod L ---
   ed-fq (p2-md ed-q)
   ed-fl (p2-md ed-l)
   (ed-in x) (p2-limbs ((x << 260) % ed-q))                 ; a public value into the domain
   ed-one (ed-in 1)
   ed-d2 (ed-in (2 * ed-d % ed-q))
   (ed-fm a b) (p2-mm a b ed-fq)
   (ed-fa a b) (p2-csub (p2-norm (p2-zip (+) a b)) <ed-fq)
   (ed-fs a b) (p2-csub (p2-norm (p2-zip (+) (p2-zip (-) a b) <ed-fq)) <ed-fq)
   ; the same addition as ed-add, complete, so doubling and the identity take its one path
   (ed-ladd p q)
    (: x1 <p y1 (p 1) z1 (p 2) t1 (p 3) x2 <q y2 (q 1) z2 (q 2) t2 (q 3)
       a (ed-fm (ed-fs y1 x1) (ed-fs y2 x2))
       b (ed-fm (ed-fa y1 x1) (ed-fa y2 x2))
       c (ed-fm (ed-fm t1 ed-d2) t2)
       d (ed-fm (ed-fa z1 z1) z2)
       e (ed-fs b a) f (ed-fs d c) g (ed-fa d c) h (ed-fa b a)
       [(ed-fm e f) (ed-fm g h) (ed-fm f g) (ed-fm e h)])
   ; doubling, a = -1: 4 squares and 4 products
   (ed-ldbl p)
    (: x <p y (p 1) z (p 2)
       a (ed-fm x x) b (ed-fm y y) c (ed-fa (ed-fm z z) (ed-fm z z))
       h (ed-fa a b) xy (ed-fa x y) e (ed-fs h (ed-fm xy xy))
       g (ed-fs a b) f (ed-fa c g)
       [(ed-fm e f) (ed-fm g h) (ed-fm f g) (ed-fm e h)])
   ed-lo [p2-zero ed-one ed-one p2-zero]
   ed-gtab (: zi (ed-inv (ed-b 2)) x (ed-mul (ed-b 0) zi) y (ed-mul (ed-b 1) zi)
              (p2-table ed-ladd ed-lo [(ed-in x) (ed-in y) ed-one (ed-in (ed-mul x y))]))
   ; nibble i of a scalar's limbs, from the top
   (ed-nib l i)
    (: b (252 - 4 * i) j (b // 26) sh (b % 26)
       (((l j >> sh) | (? (22 < sh) (l (j + 1) << (26 - sh)) 0)) & 15))
   (ed-mulb l) (p2-walk ed-ladd ed-ldbl ed-lo ed-gtab (ed-nib l))
   (ed-lenc p)
    (: zi (p2-pow (p 2) (ed-q - 2) ed-fq ed-one)
       (out a) (p2-num (p2-mm (ed-fm a zi) p2-unit ed-fq))
       (le-bytes (out (p 1) + ((out <p & 1) << 255))))

   ed-r2 (p2-limbs ((1 << 520) % ed-l))
   ed-r3 (p2-limbs ((1 << 780) % ed-l))
   (ed-la a b) (p2-csub (p2-norm (p2-zip (+) a b)) <ed-fl)
   ; a 64-byte digest mod L, in the domain: its low 260 bits times R^2 plus the rest times R^3
   (ed-wide h) (ed-la (p2-mm (p2-rd h 64 0) ed-r2 ed-fl) (p2-mm (p2-rd h 64 260) ed-r3 ed-fl))
   ; [the clamped scalar's limbs, the nonce prefix]
   (ed-secret seed)
    (: h (sha512 seed)
       [(p2-rd (j \ (? (j = 0) (h 0 & 248) (j = 31) ((h 31 & 127) | 64) (h j))) 32 0) (snip h 32 64)])

   (ed-pub seed) (ed-lenc (ed-mulb <(ed-secret seed)))
   (ed-sign seed pub m)
    (: sec (ed-secret seed) a <sec pre <>sec
       rm (ed-wide (sha512 (pre + m)))
       rr (ed-lenc (ed-mulb (p2-mm rm p2-unit ed-fl)))
       km (ed-wide (sha512 (rr + pub + m)))
       s (ed-la rm (p2-mm km (p2-mm a ed-r2 ed-fl) ed-fl))  ; (r + k a) R
       (rr + le-bytes (p2-num (p2-mm s p2-unit ed-fl))))
   (ed-verify pub m sig)
    (: a (ed-dec pub)
       rp (ed-dec (snip sig 0 32))
       s (le-num (snip sig 32 64))
       (? (#sig != 64 || atom? a || atom? rp || ed-l <= s) 0
          (: k (ed-hint ((snip sig 0 32) + pub + m))
             (ed-enc (ed-scale s ed-b) = ed-enc (ed-add rp (ed-scale k a)))))))
) ; module 'ssh
