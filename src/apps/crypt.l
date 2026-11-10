; crypt -- the password hashes a shadow file holds. (crypt-hash pw setting) answers what
; crypt(3) answers for that setting, () for one it does not read; (crypt-check pw stored)
; is 1 when pw hashes to stored, compared in constant time.
;   $6$[rounds=N$]SALT  sha512-crypt, after drepper's spec: 5000 rounds unless named, held
;                       to 1000..999999999, the salt cut at 16
(module (crypt crypt-hash crypt-check crypt-sha512 crypt-b64)
(borrow '(bytes hashes))
(:
 cr-abc "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
 (h512 s) (hex2b (sha512 s))
 ; n bytes of s laid end to end
 (cr-rep s n) (string (map (i \ s (i % #s)) ^n))
 ; crypt's base64: each byte triple a 24-bit word, low six bits first
 (cr-w64 w n) (string (map (i \ cr-abc (w >> (6 * i) & 63)) ^n))
 (crypt-b64 c) (: (tri a b d) (cr-w64 (c a << 16 | c b << 8 | c d) 4)
                  (go i acc) (i = 21 ? acc
                              (go (i + 1) (acc + tri (i * 22 % 63) ((i * 22 + 21) % 63) ((i * 22 + 42) % 63))))
                  (go 0 "" + cr-w64 (c 63) 2))
 ; the digits leading s, and how many
 (cr-num s) (: (go i n) (i < #s && 48 <= s i <= 57 ? (go (i + 1) (n * 10 + s i - 48)) [n i]) (go 0 0))
 (crypt-sha512 pw salt rounds)
  (: lp #pw  ls #salt
     b (h512 (pw + salt + pw))
     (bits n acc) (n = 0 ? acc (bits (n >> 1) (acc + (n & 1 ? b pw))))
     a (h512 (bits lp (pw + salt + cr-rep b lp)))
     p (cr-rep (h512 (cr-rep pw (lp * lp))) lp)
     s (cr-rep (h512 (cr-rep salt (ls * (16 + a 0)))) ls)
     (round i c) (i = rounds ? c
                  (round (i + 1) (h512 ((i & 1 ? p c) + (i % 3 ? s "") + (i % 7 ? p "") + (i & 1 ? c p)))))
     (round 0 a))
 ; $6$[rounds=N$]SALT[$..] -> [rounds named? salt], or ()
 (cr-six st) (: r (snip st 3 #st)
                named (#r > 7 && snip r 0 7 = "rounds=")
                nr (named ? (cr-num (snip r 7 #r)) [5000 0])
                rest (named ? (snip r (8 + nr 1) #r) r)
                ok (!named || (nr 1 > 0 && r (7 + nr 1) = 36))
                cut (: (go i) (i < #rest && i < 16 && !(rest i = 36) ? (go (i + 1)) i) (go 0))
                (ok ? [(max 1000 (min 999999999 (nr 0))) named (snip rest 0 cut)] ()))
 (crypt-hash pw st)
  (? (#st > 2 && snip st 0 3 = "$6$")
     (cr-six st @ (n named salt) ("$6$" + (named ? ("rounds=" + show n + "$") "") + salt + "$"
                                   + crypt-b64 (crypt-sha512 pw salt n))
                  _ ())
     ())
 ; every byte read whatever the first difference, so the time says nothing of where it falls
 (crypt-check pw stored) (: h (crypt-hash pw stored)
                            (string? h && #h = #stored
                             ? (foldl (\ d i (d | h i ^ stored i)) 0 ^#h = 0) 0)))
) ; module crypt
