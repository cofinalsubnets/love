; apps/ssh/bcrypt.l -- bcrypt_pbkdf, openbsd's kdf for openssh-key-v1 passphrases.
;
;   (bcrypt-pbkdf pass salt rounds n)   n bytes of key
;
; the blowfish block, bcrypt_hash, is the bcrypt-hash nif (inle/bcrypt.c); this is the
; pbkdf2-like chain around it, sha-512 between the blocks, and blowfish's starting state,
; which is pi's hex fraction and is computed here by machin's formula, not transcribed.
(module 'ssh
(borrow 'tls)
(:
   ; 1042 words of pi past the 3, big-endian: P's 18 then the four S-boxes
   (bf-pi _)
    (: bits (32 * 1042 + 64)
       (atan k) (: x2 (k * k)
                   (go t n s a) (? (t = 0) a (go (t // x2) (n + 2) (0 - s) (a + s * (t // n))))
                   (go ((1 << bits) // k) 1 1 0))
       fr (16 * atan 5 - 4 * atan 239 - (3 << bits))
       (bytes 4168 (j \ (fr >> (bits - 8 * (j + 1))) & 255)))

   ; the output's bytes are dealt out strided: byte d is block d % stride's (d // stride)-th
   (bcrypt-pbkdf pass salt rounds n)
    (: pi (bf-pi 0)
       hp (sha512 pass)
       stride ((n + 31) // 32)
       (blk count)
        (: (go i t acc) (? (rounds <= i) acc
                           (: t2 (bcrypt-hash pi hp (sha512 t)) (go (i + 1) t2 (xors acc t2))))
           t1 (bcrypt-hash pi hp (sha512 (salt + u32 count)))
           (go 1 t1 t1))
       bs (map (c \ blk (c + 1)) (jot stride))
       (bytes n (d \ (bs (d % stride)) (d // stride))))
)
) ; module 'ssh
