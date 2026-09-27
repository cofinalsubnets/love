; apps/ssh/aes.l -- aes (FIPS 197), the enciphering direction, and ctr mode over it.
;
;   (aes-keys k)          the schedule of a 16, 24 or 32-byte key, the round keys end to end
;   (aes-ctr ks iv s)     s xored with the keystream counted up from the 16-byte iv
;
; the s-box is the field inverse under the affine map, derived here, not transcribed. only
; a private key's file passes through this, a few hundred bytes a login, so it is plain.
(module 'ssh
(borrow 'tls)
(:
   (xt a) (? (a < 128) (a << 1) ((a << 1) ^ 283))
   (rl b n) (((b << n) | (b >> (8 - n))) & 255)
   (aff b) (b ^ rl b 1 ^ rl b 2 ^ rl b 3 ^ rl b 4 ^ 99)
   ; 3 generates the field: its powers, and each one's inverse the power 255 - i
   aes-sbox
    (: pw (: (go i x a) (? (i = 255) (rev a) (go (i + 1) (x ^ xt x) (x . a))) (go 0 1 ()))
       inv (foldl (t \ i \ pin t (pw i) (pw ((255 - i) % 255))) (tablet 256) ^255)
       (bytes 256 (x \ aff (? (x = 0) 0 (inv x)))))

   (aes-keys k)
    (: nk (#k // 4)
       nw (4 * (nk + 7))
       (rcon j) (? (j = 1) 1 (xt (rcon (j - 1))))
       (sub w) (map (b \ aes-sbox b) w)
       (xw a b) (? (two? a) ((<a ^ <b) . xw >a >b))
       ; ws is the words so far, newest first
       (go i ws)
        (? (nw <= i) (rev ws)
           (: t <ws
              t2 (? ((i % nk) = 0) (xw (sub [(t 1) (t 2) (t 3) (t 0)]) [(rcon (i // nk)) 0 0 0])
                    ((6 < nk) && ((i % nk) = 4)) (sub t)
                    t)
              (go (i + 1) (xw (ws (nk - 1)) t2 . ws))))
       ws (go nk (rev (map (j \ map (b \ k (4 * j + b)) ^4) (jot nk))))
       (bytes (4 * nw) (j \ (ws (j // 4)) (j % 4))))

   ; one 16-byte block, the state column by column
   (aes-block ks s)
    (: nr ((#ks // 16) - 1)
       (ark st r) (bytes 16 (j \ st j ^ ks (16 * r + j)))
       (sb st) (bytes 16 (j \ aes-sbox (st j)))
       (sr st) (bytes 16 (j \ st ((j % 4) + 4 * (((j // 4) + (j % 4)) % 4))))
       (mc st) (bytes 16 (j \ (: c (j - (j % 4)) (a k) (st (c + ((j + k) % 4)))
                                 (xt (a 0) ^ xt (a 1) ^ a 1 ^ a 2 ^ a 3))))
       (go st r) (? (r = nr) (ark (sr (sb st)) nr) (go (ark (mc (sr (sb st))) r) (r + 1)))
       (go (ark s 0) 1))

   (aes-ctr ks iv s)
    (: n0 (foldl (a \ b \ (a << 8) | b) 0 (map (j \ iv j) ^16))
       (ctr i) (: v ((n0 + i) & ((1 << 128) - 1)) (bytes 16 (j \ (v >> (8 * (15 - j))) & 255)))
       ksm (foldl (+) "" (map (i \ aes-block ks (ctr i)) (jot ((#s + 15) // 16))))
       (bytes #s (j \ s j ^ ksm j)))
)
) ; module 'ssh
