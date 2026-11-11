; crypt -- the password hashes a shadow file holds. (crypt-hash pw setting) answers what
; crypt(3) answers for that setting, () for one it does not read; (crypt-check pw stored)
; is 1 when pw hashes to stored, compared in constant time.
;   $6$[rounds=N$]SALT  sha512-crypt, after drepper's spec: 5000 rounds unless named, held
;                       to 1000..999999999, the salt cut at 16
;   $y$PARAMS$SALT      yescrypt, its rw defaults (flavour j) or classic scrypt (.): the kdf is
;                       yescrypt.c's, the string's codings and the cask here
(module (crypt crypt-hash crypt-check crypt-sha512 crypt-b64 crypt-yes crypt-d64 crypt-e64)
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
 ; --- yescrypt's string: a digit's value is its place in cr-abc
 (cr-at c) (: (go i) (? (i = 64) 64 (cr-abc i = c) i (go (i + 1))) (go 0))
 ; a variable-length number at s[i]: the first digit says how many follow -> [v next] | ()
 (cr-dvar s i mn)
  (: c (i < #s ? (cr-at (s i)) 64)
     (tail j k bt v) (? (k = 0) [v j]
                        (j < #s && cr-at (s j) < 64) (tail (j + 1) (k - 1) (bt - 6) (v + (cr-at (s j) << (bt - 6))))
                        ())
     (go st en ch bt v) (c > en ? (go (en + 1) (en + 1 + (62 - en) // 2) (ch + 1) (bt + 6) (v + ((en + 1 - st) << bt)))
                           (tail (i + 1) (ch - 1) bt (v + ((c - st) << bt))))
     (c > 63 ? () (go 0 47 1 0 mn)))
 ; digits to bytes, four to three, a short group's spare bits zero; at most 64 bytes -> bytes | ()
 (crypt-d64 t)
  (: (grp i acc) (? (i = #t) acc
                    (: n (min 4 (#t - i))
                       ds (map (k \ cr-at (t (i + k))) ^n)
                       v (foldl (\ a k (a | ds k << (6 * k))) 0 ^n)
                       nb (6 * n // 8)
                       (n < 2 || elem 64 ds || v >> (8 * nb) != 0 ? ()
                        (grp (i + n) (acc + string (map (k \ v >> (8 * k) & 255) ^nb))))))
     d (grp 0 "")
     (string? d && #d <= 64 ? d ()))
 (crypt-e64 b) (: (go i acc) (? (i >= #b) acc
                                (: n (min 3 (#b - i))
                                   (go (i + 3) (acc + cr-w64 (foldl (\ a k (a | b (i + k) << (8 * k))) 0 ^n) ((8 * n + 5) // 6)))))
                  (go 0 ""))
 ; $y$ PARAMS $ SALT -> [prefix flags N r p t salt-text] | ()
 (cr-yparse st)
  (: f (cr-dvar st 3 0)
     fl (two? f ? (f 0 @ v (? (v < 2) v (v < 258) (2 + (v - 2 << 2)) -1)) -1)
     n (two? f ? (cr-dvar st (f 1) 1) ())
     r (two? n ? (cr-dvar st (n 1) 1) ())
     hv (? !(two? r) () (r 1 < #st && st (r 1) = 36) [0 (r 1)] (cr-dvar st (r 1) 1))
     hb (two? hv ? (hv 0) 0)
     pp (two? hv && hb & 1 ? (cr-dvar st (hv 1) 2) [1 (two? hv ? (hv 1) 0)])
     tt (two? pp && hb & 2 ? (cr-dvar st (pp 1) 1) [0 (two? pp ? (pp 1) 0)])
     e (two? tt ? (tt 1) 0)
     rest (snip st (e + 1) #st)
     cut (: (go i k) (? (i = #rest) k (rest i = 36) (go (i + 1) i) (go (i + 1) k)) (go 0 #rest))
     (? (fl < 0 || !(two? tt) || hb > 3 || n 0 > 63 || e >= #st || !(st e = 36)) ()
        [(snip st 0 (e + 1)) fl (1 << n 0) (r 0) (pp 0) (tt 0) (snip rest 0 cut)]))
 (crypt-yes pw st)
  (cr-yparse st @ (pre fl n r p t salt)
   (: sb (crypt-d64 salt)
      room (yescrypt-room n r p)
      k (string? sb && charm? room ? (yescrypt-kdf (cask room) pw sb [fl n r p t]) ())
      (string? k ? (pre + salt + "$" + crypt-e64 k) ()))
   _ ())
 (crypt-hash pw st)
  (? (#st > 2 && snip st 0 3 = "$6$")
     (cr-six st @ (n named salt) ("$6$" + (named ? ("rounds=" + show n + "$") "") + salt + "$"
                                   + crypt-b64 (crypt-sha512 pw salt n))
                  _ ())
     (#st > 2 && snip st 0 3 = "$y$") (crypt-yes pw st)
     ())
 ; every byte read whatever the first difference, so the time says nothing of where it falls
 (crypt-check pw stored) (: h (crypt-hash pw stored)
                            (string? h && #h = #stored
                             ? (foldl (\ d i (d | h i ^ stored i)) 0 ^#h = 0) 0)))
) ; module crypt
