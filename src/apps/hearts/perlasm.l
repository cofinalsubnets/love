; src/apps/hearts/perlasm.l -- the kernel's lib/crypto/arm64/sha2-armv8.pl, ported: the one perlasm
; script an arm64 defconfig runs (sha256-core.S, sha512-core.S), its output held byte-identical to
; perl's. the script is pinned by its sha256 -- another refuses, so an upstream change shows rather
; than being mistranslated -- and its heredocs, read from it in order, are the templates: `interp`
; interpolates perl's "$x", "$x[i]" and "@x[e]", `ins` is its AUTOLOAD thunk, the body_00_15
; strings are thunks over the same state, and `post` is its six rewrites.
; usage: love perlasm.l SCRIPT FLAVOUR OUTPUT   (kbuild's perlasm_with_args passes FLAVOUR void)
(: argv cmdline
   pinned "5bdb5dcb78edfac87cc5c4e2009c065b045568fa9a0b563ba1a818f44329fd72"
   st {}                                  ; 'code (newest first) and 'q, the NEON thunk queue
   env {}                                 ; perl's variables by name: numbers, strings, arrays
   (die m) (puts ("perlasm: " + m + "\n"), quit 1)
   (emit s) (pin st 'code (s . st 'code))
   gv env
   (sv k v) (pin env k v)
   (setn names vals) (two? names ? (sv <names <vals, setn >names >vals) 0)
   (rep n f) (n > 0 ? (f 0, rep (n - 1) f) 0)
   (word? c) (c = 95 || alnum? c)
   (space? c) (c = 32 || 9 <= c <= 13)
   ; a number as perl prints it here: every value the script makes is integral
   (fmtn v) (int v @ k (k = v ? (show k) (die ("a fraction: " + show v))))
   (txt v) (string? v ? v (fmtn v))
   (idend t i) (i < #t && word? (t i) ? (idend t (i + 1)) i)
   (digend t i) (i < #t && digit? (t i) ? (digend t (i + 1)) i)

   ; -- arithmetic, perl's precedence for what the script writes: & under + - under * / %
   (arith s)
    (: p {'i 0} n #s
       (skip _) (p 'i < n && space? (s (p 'i)) ? (pin p 'i (p 'i + 1), skip 0) 0)
       (at _) (skip 0, p 'i < n ? (s (p 'i)) -1)
       (eat _) (pin p 'i (p 'i + 1))
       (num _) (: e (digend s (p 'i)) v (read (snip s (p 'i) e)) _ (pin p 'i e) v)
       (prim _)
        (at 0 @ c
           (? (c = 40) (: _ (eat 0) v (ex 0) _ (at 0) _ (eat 0) v)     ; ( e )
              (c = 45) (eat 0, -(prim 0))
              (c = 108) (pin p 'i (p 'i + 3), (log (prim 0)))   ; log(e)
              (digit? c) (num 0)
              (die ("cannot read " + s))))
       (mul v) (at 0 @ 42 (eat 0, prim 0 @ w (mul (v * w)))
                       47 (eat 0, prim 0 @ w (mul (v / w)))
                       37 (eat 0, prim 0 @ w (mul (v % w)))
                       v)
       (add v) (at 0 @ 43 (eat 0, mul (prim 0) @ w (add (v + w)))
                       45 (eat 0, mul (prim 0) @ w (add (v - w)))
                       v)
       (band v) (at 0 @- v 38 (eat 0, add (mul (prim 0)) @ w (band (v & w))))
       (ex _) (band (add (mul (prim 0))))
       (ex 0))

   ; -- a heredoc's interpolation: $x, $x[e] (an element of @x), @x[e], and \@
   (close t i d) (t i @ 91 (close t (i + 1) (d + 1))
                        93 (d = 1 ? i (close t (i + 1) (d - 1)))
                        (close t (i + 1) d))
   (interp t)
    (:- (go 0 ()) n #t
       (go i acc)
        (i >= n ? (join "" (rev acc))
           (t i @ c
              (? (c = 92 && i + 1 < n && t (i + 1) = 64) (go (i + 2) ("@" . acc))
                 ((c = 36 || c = 64) && i + 1 < n && word? (t (i + 1)) && !(digit? (t (i + 1))))
                  (: e (idend t (i + 1)) nm (snip t (i + 1) e)
                     (? (e < n && t e = 91)
                         (: k (close t e 0) ix (arith (interp (snip t (e + 1) k)))
                            (go (k + 1) (txt ((gv nm) ix) . acc)))
                        (c = 64) (go (i + 1) ("@" . acc))
                        (go e (txt (gv nm) . acc))))
                 (go (i + 1) (string c . acc))))))

   ; -- the script: pinned, its header comment, and its heredocs in order
   src (uread (argv 2) @ [1 s] s (die ("cannot read " + argv 2)))
   _ (sha256 src = pinned || (die ((argv 2) + " is not the pinned sha2-armv8.pl")))
   ls (lines src)
   docs ((: (go l acc cur) (? (atom? l) (rev acc)
                              (string? cur) (<l = "___" ? (go >l (cur . acc) ()) (go >l acc (cur + <l + "\n")))
                              (findsub <l "<<___" >= 0) (go >l acc "")
                              (go >l acc cur))) ls () ())
   _ (#docs = 22 || (die "the heredocs moved"))
   (doc k) (emit (interp (docs k)))
   head ((: (go l acc) (? (atom? l) (rev acc)
                          (snip <l 0 2 = "#!") (go >l acc)
                          (<l = "") (go >l ("" . acc))
                          (snip <l 0 1 = "#") (go >l (("//" + snip <l 1 #<l) . acc))
                          (rev acc))) ls ())

   ; -- AUTOLOAD: op with its first _ a dot, the args joined, a numeric last one as #n
   (ins op args)
    (: k (findsub op "_") nm (k >= 0 ? (snip op 0 k + "." + snip op (k + 1) #op) op)
       l (rev args) lst (<l @ a (string? a ? a ("#" + fmtn a)))
       (emit ("\t" + nm + "\t" + join "," (rev (lst . >l)) + "\n")))
   ; Dscalar / Dlo / Dhi: the number after the first q or v
   (regno r) ((: (go i) (? (i >= #r) "" (r i = 113 || r i = 118) (snip r (i + 1) (digend r (i + 1))) (go (i + 1)))) 0)
   (dscalar r) (regno r @ d (d = "" ? "" ("d" + d)))
   (dlo r) (regno r @ "" "" d ("v" + d + ".d[0]"))
   (dhi r) (regno r @ "" "" d ("v" + d + ".d[1]"))
   (lastof l) (atom? >l ? <l (lastof >l))
   (butlast l) (atom? >l ? () (<l . butlast >l))
   (rot l) (atom? l ? l (lastof l . butlast l))       ; unshift(@l, pop(@l))
   (rotl l) (atom? l ? l (>l + [<l]))              ; push(@l, shift(@l))
   (x k) ((gv "X") k)
   abcdefgh ["a" "b" "c" "d" "e" "f" "g" "h"]

   ; -- the scalar rounds (BODY_00_xx)
   (body i v)
    (: _ (sv "i" i)
       _ (setn abcdefgh v)
       _ (sv "j" ((i + 1) & 15))
       _ (sv "T0" (i < 11 ? (x (i + 3)) (x ((i - 8) & 15))))
       _ (sv "T1" (x ((i - 9) & 15)))
       _ (sv "T2" (x ((i - 10) & 15)))
       _ (i < 16 ? (doc 0))
       _ ((i < 13 && (i & 1) = 1) ? (doc 1))
       _ (i = 13 ? (doc 2))
       _ (i >= 14 ? (doc 3))
       _ ((i > 0 && i < 16) ? (doc 4))
       _ (i >= 11 ? (doc 5))
       _ (i < 15 ? (doc 6))
       _ (i >= 15 ? (doc 7))
       (gv "t2" @ t (sv "t2" (gv "t3"), sv "t3" t)))

   ; -- the NEON rounds' instruction strings, as thunks over env (body_00_15)
   (sg k i) ((gv k) i)
   (body15 _)
    [(_ \ (setn abcdefgh (gv "V"), ins "add" [(gv "h") (gv "h") (gv "t1")]))
     (_ \ (ins "add" [(gv "a") (gv "a") (gv "t4")], ins "and" [(gv "t1") (gv "f") (gv "e")]))
     (_ \ ins "bic" [(gv "t4") (gv "g") (gv "e")])
     (_ \ ins "eor" [(gv "t0") (gv "e") (gv "e") ("ror#" + fmtn (sg "Sigma1" 1 - sg "Sigma1" 0))])
     (_ \ ins "add" [(gv "a") (gv "a") (gv "t2")])
     (_ \ ins "orr" [(gv "t1") (gv "t1") (gv "t4")])
     (_ \ ins "eor" [(gv "t0") (gv "t0") (gv "e") ("ror#" + fmtn (sg "Sigma1" 2 - sg "Sigma1" 0))])
     (_ \ ins "eor" [(gv "t4") (gv "a") (gv "a") ("ror#" + fmtn (sg "Sigma0" 1 - sg "Sigma0" 0))])
     (_ \ ins "add" [(gv "h") (gv "h") (gv "t1")])
     (_ \ ins "ror" [(gv "t0") (gv "t0") ("#" + fmtn (sg "Sigma1" 0))])
     (_ \ ins "eor" [(gv "t2") (gv "a") (gv "b")])
     (_ \ ins "eor" [(gv "t4") (gv "t4") (gv "a") ("ror#" + fmtn (sg "Sigma0" 2 - sg "Sigma0" 0))])
     (_ \ ins "add" [(gv "h") (gv "h") (gv "t0")])
     (_ \ (: j (gv "j")
             _ (j & 15 != 15 ? (ins "ldr" [(gv "t1") ("[sp,#" + fmtn (4 * ((j + 1) & 15)) + "]")]))
             _ (j = 15 ? (ins "ldr" [(gv "t1") ("[" + gv "Ktbl" + "]")]))
             (ins "and" [(gv "t3") (gv "t3") (gv "t2")])))
     (_ \ ins "ror" [(gv "t4") (gv "t4") ("#" + fmtn (sg "Sigma0" 0))])
     (_ \ ins "add" [(gv "d") (gv "d") (gv "h")])
     (_ \ ins "eor" [(gv "t3") (gv "t3") (gv "b")])
     (_ \ (sv "j" (gv "j" + 1), sv "V" (rot (gv "V")), gv "t2" @ t (sv "t2" (gv "t3"), sv "t3" t)))]
   ; the queue Xupdate and Xpreload draw from: four bodies' worth, taken one at a time
   (qload _) (pin st 'q (body15 0 + body15 0 + body15 0 + body15 0))
   (e1 _) (peep st 'q () @ q (two? q ? (pin st 'q >q, <q 0) 0))
   (en k) (rep k e1)
   (qn _) #(peep st 'q ())
   (T k) (gv ("T" + show k))
   (sg0 k) (sg "sigma0" k)
   (sg1 k) (sg "sigma1" k)
   (br r) ("{" + r + "}")
   (xupdate _)
    (qload 0,
     ins "ext_8" [(T 0) (x 0) (x 1) 4], en 3,
     ins "ext_8" [(T 3) (x 2) (x 3) 4], en 2,
     ins "mov" [(dscalar (T 7)) (dhi (x 3))], en 2,
     ins "ushr_32" [(T 2) (T 0) (sg0 0)], en 1,
     ins "ushr_32" [(T 1) (T 0) (sg0 2)], en 1,
     ins "add_32" [(x 0) (x 0) (T 3)], en 1,
     ins "sli_32" [(T 2) (T 0) (32 - sg0 0)], en 2,
     ins "ushr_32" [(T 3) (T 0) (sg0 1)], en 2,
     ins "eor_8" [(T 1) (T 1) (T 2)], en 2,
     ins "sli_32" [(T 3) (T 0) (32 - sg0 1)], en 2,
     ins "ushr_32" [(T 4) (T 7) (sg1 0)], en 2,
     ins "eor_8" [(T 1) (T 1) (T 3)], en 2,
     ins "sli_32" [(T 4) (T 7) (32 - sg1 0)], en 2,
     ins "ushr_32" [(T 5) (T 7) (sg1 2)], en 2,
     ins "ushr_32" [(T 3) (T 7) (sg1 1)], en 2,
     ins "add_32" [(x 0) (x 0) (T 1)], en 2,
     ins "sli_u32" [(T 3) (T 7) (32 - sg1 1)], en 2,
     ins "eor_8" [(T 5) (T 5) (T 4)], en 3,
     ins "eor_8" [(T 5) (T 5) (T 3)], en 3,
     ins "add_32" [(x 0) (x 0) (T 5)], en 3,
     ins "ushr_32" [(T 6) (x 0) (sg1 0)], en 1,
     ins "ushr_32" [(T 7) (x 0) (sg1 2)], en 2,
     ins "sli_32" [(T 6) (x 0) (32 - sg1 0)], en 1,
     ins "ushr_32" [(T 5) (x 0) (sg1 1)], en 2,
     ins "eor_8" [(T 7) (T 7) (T 6)], en 2,
     ins "sli_32" [(T 5) (x 0) (32 - sg1 1)], en 2,
     ins "ld1_32" [(br (T 0)) ("[" + gv "Ktbl" + "], #16")], en 1,
     ins "eor_8" [(T 7) (T 7) (T 5)], en 2,
     ins "eor_8" [(T 5) (T 5) (T 5)], en 2,
     ins "mov" [(dhi (T 5)) (dlo (T 7))], en 3,
     ins "add_32" [(x 0) (x 0) (T 5)], en 3,
     ins "add_32" [(T 0) (T 0) (x 0)],
     en (qn 0 - 1),                          ; while($#insns>=1): all but the last
     ins "st1_32" [(br (T 0)) ("[" + gv "Xfer" + "], #16")], en 1,
     sv "X" (rotl (gv "X")))
   (xpreload _)
    (qload 0, en 2,
     ins "ld1_8" [(br (x 0)) ("[" + gv "inp" + "],#16")], en 2,
     ins "ld1_32" [(br (T 0)) ("[" + gv "Ktbl" + "],#16")], en 4,
     ins "rev32" [(x 0) (x 0)], en 4,
     ins "add_32" [(T 0) (T 0) (x 0)],
     en (qn 0),                              ; foreach (@insns): the rest
     ins "st1_32" [(br (T 0)) ("[" + gv "Xfer" + "], #16")],
     sv "X" (rotl (gv "X")))

   ; -- the post-pass, line by line (the script's six s///)
   (bt l) (findsub l "`" @ a
            (a < 0 ? l (: r (snip l (a + 1) #l) b (findsub r "`")
                          (bt (snip l 0 a + fmtn (arith (snip r 0 b)) + snip r (b + 1) #r)))))
   (hex8 v) (join "" (map (k \ string ("0123456789abcdef" ((v >> (4 * (7 - k))) & 15))) ^8))
   (opc m) (m @ "sha256h" 0x5e004000 "sha256h2" 0x5e005000
                "sha256su0" 0x5e282800 "sha256su1" 0x5e006000)
   ; at i: [qv] then digits -> [number index-past], else ()
   (qvnum s i) (i + 1 < #s && (s i = 113 || s i = 118) && digit? (s (i + 1))
                ? (: e (digend s (i + 1)) [(read (snip s (i + 1) e)) e]) ())
   (skipsp s i) (i < #s && space? (s i) ? (skipsp s (i + 1)) i)
   (upto s i c) (i < #s && s i != c ? (upto s (i + 1) c) i)      ; [^c]*
   ; m/[qv](N)[^,]*,\s*[qv](N)[^,]*(?:,\s*[qv](N))?/, from the first place it matches
   (unregs a i) (? (i >= #a) ()
                   (qvnum a i @ r1
                      (? !(two? r1) (unregs a (i + 1))
                         (: c1 (upto a (r1 1) 44)
                            r2 (c1 < #a ? (qvnum a (skipsp a (c1 + 1))) ())
                            (? !(two? r2) (unregs a (i + 1))
                               (: c2 (upto a (r2 1) 44)
                                  r3 (c2 < #a ? (qvnum a (skipsp a (c2 + 1))) ())
                                  [(r1 0) (r2 0) (two? r3 ? (r3 0) 0)]))))))
   (unsha l)
    (findsub l "sha256" @ a
       (? (a < 0 || (a > 0 && word? (l (a - 1)))) l
          (: me (idend l a) m (snip l a me) ws (skipsp l me)
             (? (ws = me || ws >= #l || !(l ws = 113 || l ws = 118) || opc m = ()) l
                (: arg (snip l ws #l) g (unregs arg 0)
                   (? !(two? g) l
                      (snip l 0 a + ".inst\t0x" + hex8 (opc m | g 0 | (g 1 << 5) | (g 2 << 16)) + "\t//" + m + " " + arg)))))))
   (qreg l) ((: (go i acc)
                (? (i >= #l) (join "" (rev acc))
                   (l i = 113 && (i = 0 || !(word? (l (i - 1)))) && i + 1 < #l && digit? (l (i + 1))
                    && (digend l (i + 1) @ e (e = #l || !(word? (l e)))))
                    (: e (digend l (i + 1)) (go e (("v" + snip l (i + 1) e + ".16b") . acc)))
                   (go (i + 1) (string (l i) . acc)))) 0 ())
   (dot8 l) ((: (go i)
                (? (i >= #l) l
                   (l i = 46 && i + 2 < #l && l (i + 1) = 56 && space? (l (i + 2))) (snip l 0 i + snip l (i + 2) #l)
                   (l i = 46 && i + 3 < #l && (l (i + 1) = 117 || l (i + 1) = 105) && l (i + 2) = 56 && space? (l (i + 3)))
                    (snip l 0 i + snip l (i + 3) #l)
                   (go (i + 1)))) 0)
   (edge? l k) (k >= #l || !(word? (l k)))
   (dot32 l) ((: (go i)
                 (? (i >= #l) ()
                    (l i = 46 && i + 1 < #l && word? (l (i + 1)) && snip l (i + 2) (i + 4) = "32" && edge? l (i + 4))
                     (snip l 0 i + snip l (i + 4) #l)
                    (l i = 46 && snip l (i + 1) (i + 3) = "32" && edge? l (i + 3)) (snip l 0 i + snip l (i + 3) #l)
                    (go (i + 1)))) 0)
   (subst l a b) (findsub l a @ k (k < 0 ? l (snip l 0 k + b + subst (snip l (k + #a) #l) a b)))
   (ldst? l) ((: (go i) (? (i + 3 > #l) 0
                          ((snip l i (i + 3) = "ld1" || snip l i (i + 3) = "st1")
                           && (findsub (snip l (i + 3) #l) "[" @ b (b > 0 && snip (snip l (i + 3) #l) b (b + 3) = "[0]"))) 1
                          (go (i + 1)))) 0)
   (post l)
    (: l1 (unsha (bt l))
       l2 (dot8 (qreg l1))
       l3 (dot32 l2 @ d (string? d ? (subst d ".16b" ".4s") l2))
       (ldst? l3 ? (subst l3 ".4s" ".s") l3))

   ; -- the script itself
   _ (argv 3 = "void" || (die "a flavour other than void would want arm-xlate.pl"))
   outp (argv 4)
   sz4 (findsub outp "512" < 0)
   _ (sz4 ? (setn ["BITS" "SZ" "Sigma0" "Sigma1" "sigma0" "sigma1" "rounds" "reg_t"]
                  [256 4 [2 13 22] [6 11 25] [7 18 3] [17 19 10] 64 "w"])
            (setn ["BITS" "SZ" "Sigma0" "Sigma1" "sigma0" "sigma1" "rounds" "reg_t"]
                  [512 8 [28 34 39] [14 18 41] [1 8 7] [19 61 6] 80 "x"]))
   rt (gv "reg_t")
   _ (setn ["func" "ctx" "inp" "num" "Ktbl"] [("sha" + show (gv "BITS") + "_block_data_order") "x0" "x1" "x2" "x30"])
   _ (sv "X" (map (n \ rt + show n) [3 4 5 6 7 8 9 10 11 12 13 14 15 0 1 2]))
   v0 (map (n \ rt + show n) [20 21 22 23 24 25 26 27])
   _ (setn ["A" "B" "C" "D" "E" "F" "G" "H"] v0)
   _ (setn ["t0" "t1" "t2" "t3"] (map (n \ rt + show n) [16 17 19 28]))
   _ (doc 8)
   _ (sz4 ? (doc 9))
   _ (doc 10)
   v1 ((: (go i v) (i @ 16 v (body i v, go (i + 1) (rot v)))) 0 v0)
   _ (emit ".Loop_16_xx:\n")
   _ ((: (go i v) (i @ 32 v (body i v, go (i + 1) (rot v)))) 16 v1)
   _ (doc 11)
   _ (sz4 ? (doc 13) (doc 12))
   _ (doc 14)
   _ (sz4 ?
       (: _ (setn ["Ktbl" "ABCD" "EFGH" "abcd" "MSG" "W0" "W1" "ABCD_SAVE" "EFGH_SAVE"]
                  ["x3" "v0.16b" "v1.16b" "v2.16b" ["v4.16b" "v5.16b" "v6.16b" "v7.16b"]
                   "v16.4s" "v17.4s" "v18.16b" "v19.16b"])
          _ (doc 15)
          _ (rep 12 (_ \ (doc 16, gv "W0" @ w (sv "W0" (gv "W1"), sv "W1" w), sv "MSG" (rotl (gv "MSG")))))
          (doc 17)))
   _ (sz4 ?
       (map (n \ "w" + show n) [3 4 5 6 7 8 9 10] @ vn
        (sv "V" vn,
         setn ["A" "B" "C" "D" "E" "F" "G" "H"] vn,
         setn ["t0" "t1" "t2" "t3" "t4"] ["w11" "w12" "w13" "w14" "w15"],
         setn ["Ktbl" "Xfer" "X" "j"] ["x16" "x17" ["q0" "q1" "q2" "q3"] 0],
         setn ["T0" "T1" "T2" "T3" "T4" "T5" "T6" "T7"] ["q4" "q5" "q6" "q7" "q16" "q17" "q18" "q19"],
         doc 18,
         rep 4 xupdate,
         doc 19,
         rep 4 xpreload,
         doc 20)))
   _ (doc 21)
   text (join "" (map (l \ post l + "\n") (lines (join "" (rev (st 'code))))))
   (uwrite outp (join "" (map (l \ l + "\n") head) + text)))
