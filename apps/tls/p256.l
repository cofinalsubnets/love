; apps/tls/p256.l -- ecdsa over p-256 with sha-256 (fips 186-4), signing in constant time.
;
;   (p256-scalar _)          a fresh private scalar: 32 bytes, big-endian, in [1, n-1]
;   (p256-pub d)             its public point [x y]
;   (p256-sign d m)          [r s], the signature of sha-256(m), the nonce by rfc 6979
;   (p256-sign-k d h k)      [r s] for a digest h and a nonce k given, 32 bytes each | ()
;   (p256-nonce d h)         rfc 6979's nonce for key d and digest h, hmac-sha-256
;
; a secret is never a bignum, whose length and every operation on it would talk. scalars are
; 32-byte strings; field and scalar elements are ten 26-bit limbs, little-endian, each a charm.
; a limb product is under 2^52 and no sum here passes 2^58, inside love's 63-bit charm, so
; every + - * & | ^ >> is one tier whatever the values. products are montgomery's with a fixed
; carry chain, a conditional subtract is a mask (a borrow's sign shifted across), and the only
; `?` in the arithmetic reads a loop counter or a public exponent's bit. points are projective
; and added by renes, costello and batina's complete formula for a = -3 (2016, algorithm 4),
; so doubling, the identity and equal points take the one path. the scalar walks 4-bit windows
; from the top, its table entry built by masking all sixteen. rfc 6979's hmac reads sha-256's
; hex back by masks too.
;
; what that leans on: a charm op's cost is its operands' tier, never their value (true of the
; lvm and the glaze on the 64-bit seats; a 32-bit seat's narrower charm would promote);
; list and string reads at public positions; sha256's nif, whose hex face indexes a 16-byte
; table by the digest's nibbles. a key's pem goes through base64 by branches, a once-a-load
; leak this does not close
(module 'tls
(borrow 'bytes)
(:
   p2-m 67108863                                        ; 2^26 - 1, one limb

   ; --- limbs ---
   (p2-zip f a b) (? (atom? a) () ((f <a <b) . (p2-zip f >a >b)))
   (p2-limbs x) (map (i \ x >> (26 * i) & p2-m) ^10)   ; a public value's limbs
   (p2-num l) (foldl (a \ v \ a << 26 | v) 0 (rev l))  ; ..and back, for a public result
   ; 32 bytes big-endian -> limbs, by shifts fixed by position alone
   (p2-bytes s)
    (map (i \ (: lo (26 * i)
                 js (filter (j \ lo <= 8 * j + 7 && 8 * j <= lo + 25) ^32)
                 ((foldl (a \ j \ (: sh (8 * j - lo) v (s (31 - j)) (a | (? (sh < 0) (v >> (0 - sh)) (v << sh))))) 0 js)
                  & p2-m)))
         ^10)
   ; a carry chain down the limbs; limbs may be negative, the carry is the arithmetic shift
   (p2-norm t)
    (: (go l c acc) (? (atom? l) (rev acc) (: v (<l + c) (go >l (v >> 26) ((v & p2-m) . acc))))
       (go t 0 ()))
   ; x - n and its borrow, -1 when x < n and 0 otherwise
   (p2-sub x n)
    (: (go a b c acc) (? (atom? a) [(rev acc) c] (: v (<a - <b + c) (go >a >b (v >> 26) ((v & p2-m) . acc))))
       (go x n 0 ()))
   ; x mod n for x under 2n: both subtracted and kept, one picked by the borrow's mask
   (p2-csub x n)
    (: r (p2-sub x n) k (r 1)
       (p2-zip (u \ w \ u & k | w & (-1 ^ k)) x <r))
   ; n^-1 mod 2^26, n odd, a bit at a time
   (p2-inv26 a)
    (: (go x i) (? (26 <= i) x (go (? ((a * x >> i) & 1 = 1) (x + (1 << i)) x) (i + 1)))
       (go 1 1))
   ; a modulus as the product reads it: [limbs n0]
   (p2-md n) [(p2-limbs n) ((p2-m + 1 - p2-inv26 (n & p2-m)) & p2-m)]
   ; a b / 2^260 mod n, a and b under 2n. each row adds a_i b and the multiple of n that
   ; clears the low limb, then drops that limb: a limb gathers under 20 products, < 2^57
   (p2-mm a b md)
    (: n <md n0 (md 1)
       (row t ai)
        (: u (p2-zip (+) t (map (bj \ ai * bj) b + [0]))
           m ((<u & p2-m) * n0 & p2-m)
           v (p2-zip (+) u (map (nj \ m * nj) n + [0]))
           ((<>v + (<v >> 26)) . (>>v + [0])))
       t (p2-norm (foldl row (map (_ \ 0) ^11) a))
       (p2-csub (rev >(rev t)) n))
   ; a^e for a public exponent, in the montgomery domain whose one is given
   (p2-pow a e md one)
    (: (go i acc) (? (i < 0) acc (: s (p2-mm acc acc md) (go (i - 1) (? ((e >> i) & 1 = 1) (p2-mm s a md) s))))
       (go (bits-of e - 1) one))

   ; --- the two fields: coordinates mod p, scalars mod n ---
   p2-p (curve-p256 0)
   p2-n (curve-p256 1)
   p2-fp (p2-md p2-p)
   p2-fn (p2-md p2-n)
   p2-onep (p2-limbs ((1 << 260) % p2-p))
   p2-onen (p2-limbs ((1 << 260) % p2-n))
   p2-r2n (p2-limbs ((1 << 520) % p2-n))
   p2-unit (p2-limbs 1)
   p2-zero (p2-limbs 0)
   (p2-inp x) (p2-limbs ((x << 260) % p2-p))           ; public values into the domain
   (p2-inn x) (p2-limbs ((x << 260) % p2-n))
   p2-b (p2-inp (curve-p256 2))
   p2-o [p2-zero p2-onep p2-zero]                       ; the identity, (0 : 1 : 0)
   p2-g [(p2-inp (curve-p256 3)) (p2-inp (curve-p256 4)) p2-onep]
   (p2-fm a b) (p2-mm a b p2-fp)
   (p2-fa a b) (p2-csub (p2-norm (p2-zip (+) a b)) <p2-fp)
   (p2-fs a b) (p2-csub (p2-norm (p2-zip (+) (p2-zip (-) a b) <p2-fp)) <p2-fp)
   (p2-na a b) (p2-csub (p2-norm (p2-zip (+) a b)) <p2-fn)

   ; --- points: the complete addition, a = -3, each step as the paper numbers it ---
   (p2-add q1 q2)
    (: x1 <q1 y1 (q1 1) z1 (q1 2) x2 <q2 y2 (q2 1) z2 (q2 2)
       t0 (p2-fm x1 x2) t1 (p2-fm y1 y2) t2 (p2-fm z1 z2)                  ; 1-3
       t3 (p2-fs (p2-fm (p2-fa x1 y1) (p2-fa x2 y2)) (p2-fa t0 t1))       ; 4-8
       t4 (p2-fs (p2-fm (p2-fa y1 z1) (p2-fa y2 z2)) (p2-fa t1 t2))       ; 9-13
       ya (p2-fs (p2-fm (p2-fa x1 z1) (p2-fa x2 z2)) (p2-fa t0 t2))       ; 14-18
       xa (p2-fs ya (p2-fm p2-b t2))                                      ; 19-20
       xb (p2-fa xa (p2-fa xa xa))                                        ; 21-22
       za (p2-fs t1 xb) xc (p2-fa t1 xb)                                  ; 23-24
       t2b (p2-fa t2 (p2-fa t2 t2))                                       ; 26-27
       yb (p2-fs (p2-fs (p2-fm p2-b ya) t2b) t0)                          ; 25, 28-29
       yc (p2-fa yb (p2-fa yb yb))                                        ; 30-31
       t0b (p2-fs (p2-fa t0 (p2-fa t0 t0)) t2b)                           ; 32-34
       [(p2-fs (p2-fm xc t3) (p2-fm t4 yc))                               ; 35, 39-40
        (p2-fa (p2-fm xc za) (p2-fm t0b yc))                              ; 36-38
        (p2-fa (p2-fm za t4) (p2-fm t3 t0b))])                            ; 41-43
   ; [0P .. 15P]
   (p2-table q) (: (go i acc) (? (i = 16) (rev acc) (go (i + 1) ((p2-add <acc q) . acc))) (go 1 [p2-o]))
   ; entry w of the table, every entry read and all but one masked away
   (p2-pick tab w)
    (: (sel acc j) (: mk ((j ^ w) - 1 >> 62) e (tab j)
                      (map (c \ p2-zip (u \ v \ u | v & mk) (acc c) (e c)) ^3))
       (foldl sel [p2-zero p2-zero p2-zero] ^16))
   ; k q for a 32-byte k, q's table given: four doublings and one addition a nibble
   (p2-mulw tab k)
    (: (nib i) (: c (k (i >> 1)) (? ((i & 1) = 0) (c >> 4) (c & 15)))
       (dbl a) (p2-add a a)
       (go i acc) (? (i = 64) acc (go (i + 1) (p2-add (dbl (dbl (dbl (dbl acc)))) (p2-pick tab (nib i)))))
       (go 0 p2-o))
   ; a projective point -> [x y], affine and out of the domain
   (p2-affine q)
    (: zi (p2-pow (q 2) (p2-p - 2) p2-fp p2-onep)
       (out a) (p2-num (p2-mm (p2-fm a zi) p2-unit p2-fp))
       [(out <q) (out (q 1))])
   p2-gtab (p2-table p2-g)

   ; --- the scalar: 1 when 0 < k < n, else 0, by masks ---
   (p2-ok? k)
    (: l (p2-bytes k) lt ((p2-sub l <p2-fn) 1)
       nz ((0 - foldl (a \ v \ a | v) 0 l) >> 62)
       (lt & nz & 1))
   (p256-pub d) (p2-affine (p2-mulw p2-gtab d))

   ; --- rfc 6979: hmac-sha-256, the digest's hex read back without a branch on a digit ---
   (p2-hv c) (: m (57 - c >> 62) ((c - 48) & (-1 ^ m) | (c - 87) & m))
   (p2-sha s) (: h (sha256 s) (bytes 32 (i \ p2-hv (h (2 * i)) << 4 | p2-hv (h (2 * i + 1)))))
   (p2-hmac k m)
    (: kp (k + zbytes (64 - #k))
       (p2-sha (xorb kp (bytes 64 (_ \ 92)) + p2-sha (xorb kp (bytes 64 (_ \ 54)) + m))))
   (p256-nonce d h)
    (: z (be-num h) h1 (wrbe (? (z < p2-n) z (z - p2-n)) 32)
       v0 (bytes 32 (_ \ 1)) k0 (zbytes 32)
       k1 (p2-hmac k0 (v0 + string 0 + d + h1)) v1 (p2-hmac k1 v0)
       k2 (p2-hmac k1 (v1 + string 1 + d + h1)) v2 (p2-hmac k2 v1)
       (go k v) (: t (p2-hmac k v)
                   (? (p2-ok? t = 1) t (: k3 (p2-hmac k (t + string 0)) (go k3 (p2-hmac k3 t)))))
       (go k2 v2))
   ; s = k^-1 (e + r d) mod n, every operand on d and k a montgomery product
   (p256-sign-k d h k)
    (: e (be-num h % p2-n)
       r (<(p2-affine (p2-mulw p2-gtab k)) % p2-n)
       (inn x) (p2-mm (p2-bytes x) p2-r2n p2-fn)
       ki (p2-pow (inn k) (p2-n - 2) p2-fn p2-onen)
       t (p2-na (p2-inn e) (p2-mm (p2-inn r) (inn d) p2-fn))
       s (p2-num (p2-mm (p2-mm ki t p2-fn) p2-unit p2-fn))
       (? (r = 0 || s = 0) () [r s]))
   (p256-sign d m) (: h (p2-sha m) (p256-sign-k d h (p256-nonce d h)))
   (p256-scalar _) (: d (rnd 32) (? (p2-ok? d = 1) d (p256-scalar 0))))
) ; module tls
