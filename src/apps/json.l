; src/apps/json.l -- json, the wire format the outside world speaks (language servers,
; http apis, sway's ipc). `(borrow 'json)`, then json-read and json-show.
;
; the mapping, both ways:
;   null    <-> json-null       a coin, like the booleans
;   true    <-> json-true
;   false   <-> json-false
;   number  <-> charm / sun / big / gem     (the celestial ladder; exact where json is)
;   string  <-> string
;   array   <-> list, and `[]` is plain ()
;   object  <-> tablet
(module (json json-read json-show json-true json-false json-null
               json-bool json-bool? json-null?)
(: jbool      (coin 'json-bool ())
   json-true  (jbool 1)
   json-false (jbool 0)
   (json-bool? v) (kind v = 'json-bool)
   (json-bool v)  (v ? json-true json-false)

   ; null on its own die: payload 0 nets like nothing, but never `=` json-false.
   jnull          (coin 'json-null ())
   json-null      (jnull 0)
   (json-null? v) (kind v = 'json-null)

   ; --- reading ---
   (jws s i n)  (i < n && elem (s i) '(32 9 10 13) ? (jws s (i + 1) n) i)

   (jdigv c)    (48 <= c <= 57 ? (c - 48) -1)

   ; a run of decimals -> `(value end); end = start means none, which callers check.
   (jdigits s i n) ((: (go k acc)
                       (k < n && -1 < jdigv (s k) ?
                          (go (k + 1) (acc * 10 + jdigv (s k)))
                          [acc k]))
                    i 0)

   (jhex4 s i n)   ((: (go k acc d)
                       (? (d = 0)      [acc k]
                          (k >= n)  ()
                          (hexv (s k) @ v
                             (v >= 0 ? (go (k + 1) (acc * 16 + v) (d - 1))))))
                    i 0 4)

   ; \uxxxx, the surrogate pair rejoined; a lone surrogate passes through as itself
   ; rather than refusing the whole document.
   (juni s i n)
    (jhex4 s i n @ (u k)
     (? !(55296 <= u <= 56319)
         [(utf8 u) k]
        !(k + 1 < n && s k = 92 && s (k + 1) = 117)
         [(utf8 u) k]
        (jhex4 s (k + 2) n @ l
           (atom? l ? [(utf8 u) k]
              (<l @ v
                 (56320 <= v <= 57343 ?
                    [(utf8 (65536 + (u - 55296) * 1024 + (v - 56320))) <>l]
                    [(utf8 u) k]))))))

   ; the byte after the backslash; -1 for no such escape (0 is a fine byte).
   (jesc s i n) (i < n ?
                   (s i @ c
                      (c = 117 ? (juni s (i + 1) n)
                         (: b (c @ 34  34   92  92   47  47
                                   98  8    102 12   110 10
                                   114 13   116 9
                                   -1)
                            (b >= 0 ? [(string b) (i + 1)])))))

   (jstr s i n) ((: (go k acc)
                     (k < n ?
                        (s k @ c
                           (? (c = 34) [acc (k + 1)]
                              (c = 92) (jesc s (k + 1) n @ e
                                          (two? e && go <>e (acc + <e)))
                              (c < 32) ()            ; a raw control byte is not json
                              (go (k + 1) (acc + string c))))))
                 (i + 1) "")

   ; an exponent: optional sign, then at least one digit.
   (jexp s i n) (: g  (i < n && s i = 45 ? -1 1)
                   a  (i < n && elem (s i) '(43 45) ? (i + 1) i)
                   dg (jdigits s a n)
                   (<>dg != a ? [(g * <dg) <>dg]))

   (jpow10 e) (e < 0 ? (1.0 / -e 10) (1.0 * e 10))

   ; a whole int stays exact (charm -> sun -> big); a fraction or exponent is a gem.
   (jnum s i n) (: neg (i < n && s i = 45)
                   a   (neg ? (i + 1) i)
                   ip  (jdigits s a n)
                   iv  <ip
                   b   <>ip
                   (b = a ? ()                       ; a sign with no digits
                      (: fd (b < n && s b = 46 ? (jdigits s (b + 1) n))
                         c  (two? fd ? <>fd b)
                         fv (two? fd ? <fd 0)
                         fl (two? fd ? (c - (b + 1)) 0)
                         ee (c < n && elem (s c) '(101 69))
                         ex (ee && jexp s (c + 1) n)
                         d  (two? ex ? <>ex c)
                         (? (two? fd && fl = 0) ()   ; "1." is not json
                            (ee && atom? ex)     ()   ; "1e" neither
                            (: sgn (neg ? -1 1)
                               (fl = 0 &&  !ee ?
                                  [(sgn * iv) d]
                                  (: mant (iv * fl 10 + fv)
                                     base (1.0 * sgn * mant / fl 10)
                                     (two? ex ? [(base * jpow10 <ex) d]
                                                [base d]))))))))

   (jlit? s i n w) (i + #w @ e (e <= n && snip s i e = w))

   (jlit s i n) (? (jlit? s i n "true")  [json-true (i + 4)]
                   (jlit? s i n "false") [json-false (i + 5)]
                   (jlit? s i n "null")  [json-null (i + 4)]
                   (jnum s i n))

   (jarr s i n) (jws s (i + 1) n @ a
                   (a < n && s a = 93 ? [() (a + 1)]
                    (:- (go a ()) (go k acc)
                     (jval s k n @ r
                      (two? r ?
                       (jws s <>r n @ e
                        (e < n ? (s e @ 44 (go (e + 1) (<r . acc))
                                        93 [(rev (<r . acc)) (e + 1)]))))))))

   ; a later duplicate key wins.
   (jobj s i n) (jws s (i + 1) n @ a
    (a < n && s a = 125 ? [{} (a + 1)]
     (:- (go a {}) (go k acc)
      (jws s k n @ ks
       (ks < n && s ks = 34 ?
        (jstr s ks n @ kr
         (two? kr ? (jws s <>kr n @ cn
          (cn < n && s cn = 58 ?
           (jval s (cn + 1) n @ vr
            (two? vr ?  (: e (pin acc <kr <vr, jws s <>vr n)
             (e < n ? (s e @ 44 (go (e + 1) acc) 125 [acc (e + 1)]))))))))))))))

   (jval s i n) (jws s i n @ a
                  (a < n ? (s a @ 34 (jstr s a n) 91 (jarr s a n) 123 (jobj s a n) (jlit s a n))))

   ; --- the door in ---
   ; (1 value), or () -- trailing junk is a refusal.
   (json-read s) (: n #s
                    r (jval s 0 n)
                    (two? r ? (jws s <>r n @ e (e < n ? () [1 <r]))))

   ; --- writing ---
   (jhexd v) (string (v + (v < 10 ? 48 87)))

   ; bytes >= 128 ride out untouched (utf-8 already); only the named escapes and the
   ; control bytes need saying. every byte is spelled, never built by +: ("" + 34) is "".
   (jqc c) (c @ 34 "\\\""  92 "\\\\"
                10 "\\n"   13 "\\r"   9 "\\t"
                8  "\\b"   12 "\\f"
                (c < 32 ? ("\\u00" + jhexd (c // 16) + jhexd (c % 16))
                          (string c)))

   (jqt s) (jug 0 @ j (say j "\"", each ^#s (k \ say j (jqc (s k))), say j "\"", slurp j))

   (jjoin xs) (atom? xs ? ""
                 ((: (go l acc) (two? l ? (go >l (acc + "," + <l)) acc)) >xs <xs))

   ; show spells every number as json does; what it shows as a name (infinity and
   ; friends) becomes null rather than text no parser takes back.
   (jnumshow v) (: t (show v)
                   c (0 < #t ? (t 0) 0)
                   (c = 45 || 48 <= c && c <= 57 ? t "null"))

   ; () = v is true only for () itself, so a bare () writes `[]`. anything json cannot
   ; spell scares rather than riding out as null; trays stay out (arrays are lists).
   (json-show v)
      (? (string? v)    (jqt v)
         (json-bool? v) (v ? "true" "false")
         (json-null? v) "null"
         (() = v)       "[]"
         (tablet? v)    ("{"
                          + jjoin (map (k \ jqt k + ":" + json-show (v k)) (keys v))
                         + "}")
         (tray? v)      (scare 'json "arrays are lists" v)
         (two? v)       ("[" + jjoin (map json-show v) + "]")
         (constellation? v) (jnumshow v)
         (scare 'json "no json spelling for this" v)))
) ; module json
