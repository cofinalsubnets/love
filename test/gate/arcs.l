; test/gate/arcs.l -- ulp.sh's oracle for lm.c's arcs. reads `ulp arcs` (a line a case: fn,
; args, ours, glibc's, all as bits) and works each answer out in integers: annex f's specials,
; else newton in big fixed point from glibc's answer, then one rounding to the nearest double.
; fails on a case ours is not that double, or one its error bound cannot settle
(: _ (borrow 'posix)
   (die m) (say err ("arcs.l: " + m + "\n"), flush err, quit 1)
   (slurpf p) (uread p @ [1 x] (x + "") (die ("cannot read " + p)))
   (hexv s) (foldl (a \ i \ (s i @ c (a * 16 + (c < 58 ? (c - 48) (c - 87))))) 0 ^#s)
   ; the least k with n < 2^k
   (blen n) (: (up k) (n < 2 ** k ? (fine (max 0 (k - 64))) (up (k + 64)))
               (fine k) (n < 2 ** k ? k (fine (k + 1)))
               (up 64))
   sgn (2 ** 63)
   (neg? b) (sgn <= b)
   (mag b) (b % sgn)
   (nan? b) (mag b > 9218868437227405312)
   (inf? b) (mag b = 9218868437227405312)
   ; |b| as [m e], m 2^e
   (num b) (: e (mag b // 2 ** 52) f (b % 2 ** 52) (e = 0 ? [f -1074] [(f + 2 ** 52) (e - 1075)]))
   (exr b) (num b @ [m e] (e + blen m - 1))
   ; m 2^e at scale 2^q, truncated
   (fix m e q) (0 <= e + q ? (m * 2 ** (e + q)) (m // 2 ** (0 - e - q)))
   ; the bits of M 2^(sh-q), M the mantissa an n-bit T held at sh = (max (n - 53) (q - 1074))
   (bitsof M n sh q) (q - 1074 >= n - 53 ? M ((n - 1 - q + 1023) * 2 ** 52 + M - 2 ** 52))
   ; T 2^-q > 0 as the nearest double's bits; a remainder within 2^56 of the half is not settled
   (rnd T q)
    (? (T = 0) 0
       (: n (blen T) sh (max (n - 53) (q - 1074)) M (T // 2 ** sh) rm (T - M * 2 ** sh) hf (2 ** (sh - 1))
          (? (sh < 80) (die ("too few bits past the last: " + show sh))
             (abs (rm - hf) <= 2 ** 56) 'unsettled
             (bitsof (hf < rm ? (M + 1) M) n sh q))))
   ; the nearest double under the rational a/b > 0, exactly, a tie going down: atan t for a tiny t,
   ; which lies in (t - t^3/3, t), nearer t than any midpoint but one t sits on
   (rnd-under a b)
    (: q 1300 T ((a * 2 ** q) // b) fr (a * 2 ** q - T * b)
       (? (T = 0) 0
          (: n (blen T) sh (max (n - 53) (q - 1074)) M (T // 2 ** sh) rm (T - M * 2 ** sh)
             (bitsof (2 ** (sh - 1) * b < rm * b + fr ? (M + 1) M) n sh q))))
   (signed r b) (r = 'unsettled ? r (neg? b ? (r + sgn) r))
   ; [sin cos] of T 2^-q by their series, at 2^q
   (sc T q)
    (: one (2 ** q) T2 ((T * T) // one)
       (ser t j acc) (t = 0 ? acc (ser ((0 - t * T2) // (one * j * (j + 1))) (j + 2) (acc + t)))
       [(ser T 2 0) (ser one 1 0)])
   ; atan(1/m) at 2^p
   (atanq m p)
    (: m2 (m * m)
       (go pw k acc) (pw = 0 ? acc (go (pw // m2) (k + 2) (k % 4 = 1 ? (acc + pw // k) (acc - pw // k))))
       (go ((2 ** p) // m) 1 0))
   pq 200
   pi200 ((16 * atanq 5 (pq + 8) - 4 * atanq 239 (pq + 8)) // 256)
   ; k pi/4, rounded
   (piq k) (rnd ((k * pi200) // 4) pq)
   ; newton from T until its step is small, then once more; the step answers [T ok]
   (newt T step)
    (: (go T i small) (step T @ [d ok]
                        (? !ok [T 0]
                           small [(T + d) 1]
                           (i = 12) [T 0]
                           (go (T + d) (i + 1) (abs d < 2 ** 48))))
       (go T 0 0))
   ; the scale for an answer near glibc's g: 200 bits past its leading one
   (scale g) (mag g = 0 ? 1300 (200 - exr g))
   (start g q) (mag g = 0 ? 0 (num g @ [m e] (fix m e q)))

   (o-atan2 y x g)
    (? (nan? y || nan? x) 'nan
       (mag y = 0) (neg? x ? (signed (piq 4) y) y)
       (mag x = 0) (signed (piq 2) y)
       (inf? y) (signed (piq (inf? x ? (neg? x ? 3 1) 2)) y)
       (inf? x) (neg? x ? (signed (piq 4) y) (neg? y ? sgn 0))
       (num y @ [my ey]
        (num x @ [mx ex]
         (: q (scale g) e0 (min ey ex)
            Y (my * 2 ** (ey - e0)) X (mx * 2 ** (ex - e0) * (neg? x ? -1 1))
            (step T) (sc T q @ [s c] (: dn (X * c + Y * s) (dn <= 0 ? [0 0] [(((Y * c - X * s) * 2 ** q) // dn) 1])))
            (0 < X && Y * 2 ** 60 < X ? (signed (rnd-under Y X) y)
             (newt (start g q) step @ [T ok] (ok ? (signed (rnd T q) y) 'lost)))))))
   (o-asin x g)
    (? (nan? x || mag x > 4607182418800017408) 'nan
       (mag x = 0) x
       (mag x = 4607182418800017408) (signed (piq 2) x)
       (: q (scale g) X (num x @ [m e] (fix m e q))
          (step T) (sc T q @ [s c] (c <= 0 ? [0 0] [(((X - s) * 2 ** q) // c) 1]))
          (newt (start g q) step @ [T ok] (ok && 0 < T ? (signed (rnd T q) x) 'lost))))
   (o-acos x g)
    (? (nan? x || mag x > 4607182418800017408) 'nan
       (x = 4607182418800017408) 0
       (mag x = 4607182418800017408) (piq 4)
       (: q (scale g) X ((num x @ [m e] (fix m e q)) * (neg? x ? -1 1))
          (step T) (sc T q @ [s c] (s <= 0 ? [0 0] [(((c - X) * 2 ** q) // s) 1]))
          (newt (start g q) step @ [T ok] (ok && 0 < T ? (rnd T q) 'lost))))

   ; [line fn want ours glibc's]
   (case l)
    (words l @
     ("atan2" y x o g) [l "atan2" (o-atan2 (hexv y) (hexv x) (hexv g)) (hexv o) (hexv g)]
     ("asin" x o g) [l "asin" (o-asin (hexv x) (hexv g)) (hexv o) (hexv g)]
     ("acos" x o g) [l "acos" (o-acos (hexv x) (hexv g)) (hexv o) (hexv g)]
     _ (die ("a line not understood: " + l)))
   (same w b) (w = 'nan ? (nan? b) (w = b))
   (hexs n) (join "" (map (i \ "0123456789abcdef" (n // 16 ** (15 - i) % 16) @ c (string c)) ^16))

   (main args)
    (: rs (map case (filter (l \ 0 < #l) (lines (slurpf (args 0)))))
       bad (filter (r \ !(same (r 2) (r 3))) rs)
       gm (filter (r \ !(same (r 2) (r 4))) rs)
       (n f) #(filter (r \ r 1 = f) rs)
       (? (two? bad)
          (: _ (map (r \ say err ("arcs.l: " + <r + "  wants " + (charm? (r 2) ? (hexs (r 2)) (show (r 2))) + "\n"))
                    (take 10 bad))
             (die (show #bad + " of " + show #rs + " cases are not the nearest double")))
          (say out ("arcs: " + show #rs + " cases the nearest double (atan2 " + show (n "atan2") + ", asin "
                    + show (n "asin") + ", acos " + show (n "acos") + "); glibc's last bit misses "
                    + show #gm + "\n"))))
   (main >argv))
