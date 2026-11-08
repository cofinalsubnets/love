; src/apps/moon/nm.l -- the backend's normalise stage, lo.l's forms to lo.l's forms before ra.l:
; copy-then-op fused to three-address, copies and constants propagated, address arithmetic folded
; into loads and stores, extensions of values already in range dropped, unreachable forms dropped.
; each rule keeps the forms' meaning on its own
(module 'moon
(borrow 'holo)
(:
   ; x64's indexed twin of a load or store, and a store's immediate twin; a64 has neither the
   ; 32-bit indexed loads nor a store of an immediate, riscv only the word, halfword and byte twins
   nmxld {'ld 'ldx 'ldu1 'ldxb 'ldu2 'ldxh 'ldu4 'ldxw 'ld4 'ldxsw 'ldsd 'ldsdx 'ldss 'ldssx}
   nmxst {'st 'stx 'st1 'stxb 'stsd 'stsdx 'stss 'stssx}
   ; t32's word is ld4 and st4 too, and it has no float index
   nmxl32 {'ld 'ldx 'ld4 'ldx 'ldu4 'ldx 'ldu1 'ldxb}
   nmxs32 {'st 'stx 'st4 'stx 'st1 'stxb}
   nmsi {'st 'si 'st1 'si1 'st2 'si2 'st4 'si4}
   (nmu v) (v < 0 ? (v + 18446744073709551616) v)
   nmcc {'eq (a \ b \ a = b) 'ne (a \ b \ a != b) 'lt (a \ b \ a < b) 'le (a \ b \ a <= b)
         'gt (a \ b \ b < a) 'ge (a \ b \ b <= a) 'below (a \ b \ nmu a < nmu b) 'be (a \ b \ nmu a <= nmu b)
         'above (a \ b \ nmu b < nmu a) 'ae (a \ b \ nmu b <= nmu a)}
   (nmxop g op) (t32? g ? (nmxl32 op) (nmxld op @ () () xo (? (x86? g) xo (rv? g) (elem xo '(ldx ldxb ldxh) ? xo) (nelem xo '(ldxw ldxsw) ? xo))))
   (nmxsop g op) (? (v6m? g) () (t32? g) (nmxs32 op) (nmxst op @ () () xo (rv? g && nelem xo '(stx stxb) ? () xo)))
   ; a64 lays these through x16, so their displacement has to encode in the one instruction
   nmxw {'ldxh 2 'stx 8 'stxb 1 'stsdx 8 'stssx 4 'ldsdx 8 'ldssx 4}
   (nmxfar g xo o) (a64? g && cint? o && (nmxw xo @ () 0 w !(-256 <= o <= 255 || 0 <= o <= w * 4095 && o % w = 0)))

   ; (mov d a) (op d d b) -> (op d a b): b is read before d is written. a64's register ALU
   ; cannot read sp
   (nmfuse g fs)
    (fs @ ((['mov d a] . [op x y b] . u) && lovr? d && d = x && d = y && b != d && elem op raalu && (x86? g || a != 'sp))
           ([op d a b] . nmfuse g u)
          (f . u) (f . nmfuse g u)
          _ ())
   ; a branch over a lone jump is the jump's branch; thumb's short branches stay put, and only
   ; x64's reaches a symbol
   (nminv g fs)
    (t32? g ? fs
       (: labs (map (f \ f 1) (filter (f \ two? f && <f = 'label) fs))
          (go l) (l @ ((['br cc L] . ['jmp X] . u) && nmnext? u L && elem cc '(eq ne lt le gt ge below be above ae s ns) && (x64? g || elem X labs))
                       (['br (negcc cc) X] . go u)
                      (f . u) (f . go u)
                      _ ())
          (go fs)))
   ; nothing reaches past a jump or a return but through a label; a jump to a label just after
   ; it goes
   (nmreach fs)
    (fs @ ((['jmp L] . u) && nmnext? u L) (nmreach u)
          (f . u) (f . nmreach (f @ (('jmp || 'ret) . _) (nmskip u) _ u))
          _ ())
   (nmnext? fs L) (fs @ (['label x] . u) (x = L || nmnext? u L) _ ())
   (nmskip fs) (fs @ (('label . _) . _) fs (_ . u) (nmskip u) _ ())

   ; a value's bounds [lo hi], forward through a block: an extension that cannot change its
   ; operand goes
   nmext {'zx1 [0 255] 'zx2 [0 65535] 'zx4 [0 4294967295] 'sx1 [-128 127] 'sx2 [-32768 32767] 'sx4 [-2147483648 2147483647]}
   nmldw {'ldu1 [0 255] 'ldxb [0 255] 'ldu2 [0 65535] 'ldxh [0 65535] 'ldu4 [0 4294967295] 'ldxw [0 4294967295]
          'ld1 [-128 127] 'ld2 [-32768 32767] 'ld4 [-2147483648 2147483647] 'ldxsw [-2147483648 2147483647]}
   nmneg {'lt 'ge 'ge 'lt 'le 'gt 'gt 'le 'eq 'ne 'ne 'eq 'below 'ae 'ae 'below 'be 'above 'above 'be}
   nmwctl {'label 1 'jmp 1 'br 1 'ret 1 'jmpt 1 'cmp 1}
   (nmcov n) (n < 1 ? 0 (2 * nmcov (n // 2) + 1))
   (nmin? a b) (<b <= <a && a 1 <= b 1)
   (nmor a b) [(min <a <b) (max (a 1) (b 1))]
   (nmnn x) (two? x && 0 <= <x)
   ; two values both in [-c-1 c] mix their bits there
   (nmbits x y) (nmcov (max (max (x 1) (-1 - <x)) (max (y 1) (-1 - <y))) @ c [(-1 - c) c])
   (nmand x y) (? (nmnn x && nmnn y) [0 (min (x 1) (y 1))] (nmnn x) [0 (x 1)] (nmnn y) [0 (y 1)]
                  (two? x && two? y) (nmbits x y) ())
   ; a word holds a bound as signed; one worked exactly that fits did not wrap
   (nmlim g) (ilp32? g ? 2147483648 9223372036854775808)
   (nmok g x) (two? x && -(nmlim g) <= <x && x 1 < nmlim g)
   ; x's bounds where (x cc y) holds, an unknown x the whole word
   (nmcut g x cc y)
    ((two? x ? x [-(nmlim g) (nmlim g - 1)]) @ [lo hi]
       (!(two? y) ? x
          (cc @ 'lt [lo (min hi (y 1 - 1))] 'le [lo (min hi (y 1))]
                'gt [(max lo (<y + 1)) hi] 'ge [(max lo <y) hi]
                'eq [(max lo <y) (min hi (y 1))]
                'below (0 <= <y ? [(max lo 0) (min hi (y 1 - 1))] x)
                'be (0 <= <y ? [(max lo 0) (min hi (y 1))] x)
                _ x) @ z (<z <= z 1 ? z x)))
   ; a cmov just after (cmp a k), its target holding a's value: [a k] by the cmov's index
   (nmcmv g fs)
    (: at {}
       (same cs gn d a) (d = a || (cs d @ [x n] (x = a && n = peep gn a 0) _ 0))
       (go l j p cs gn)
        (l @ (f . u)
           (: _ (f @ (['cmov _ d _] && two? p && <p = 'cmp && same cs gn d (p 1)) (pin at j [(p 1) (p 2)]) _ 0)
              (f @ ('label . _) (go u (j + 1) f {} gn)
                   _ (raops g f @ [_ ds]
                        (: g2 (foldl (t \ x \ pin t x (peep t x 0 + 1)) gn ds)
                           c2 (foldl (t \ x \ pin t x ()) cs ds)
                           (go u (j + 1) f (f @ (['mov t a] && lovr? t && lovr? a) (pin c2 t [a (peep g2 a 0)]) _ c2) g2))
                        _ (go u (j + 1) f {} gn))))
           _ at)
       (go fs 0 () {} {}))
   ; the vregs a bound could matter for: an extension's operand, and what its bound is made of
   (nmdem fs)
    (: dep {} dem {}
       (edge t l) (pin dep t (l + dep t))
       _ (map (f \ (f @ ['mov t a] (edge t [a])
                         [('and || 'or || 'xor || 'add || 'sub || 'imul) t x y] (edge t [x y])
                         ['cmov _ t a] (edge t [a])
                         ['cmp t k] (edge t [k])
                         _ 0)) fs)
       (want x) (dem x = () && lovr? x ? (pin dem x 1, map want (dep x)))
       (map (f \ (f @ ([op t] && two? (nmext op)) (want t) ['cmp t 0] (want t) _ 0)) fs, dem))
   (nmwid g fs)
    (: dem (nmdem fs)
       (#(keys dem) = 0 ? fs (nmwid1 g fs dem)))
   (nmwid1 g fs dem)
    (: lb (vlabs fs)
       ; a table or asm goto's target knows nothing; a loop's head assumes its bounds until they hold
       bad {} back {}
       _ (foldl (i \ f \ (f @ ['jmp L] (peep lb L -1 <= i ? (pin back L 1))
                              ['br _ L] (peep lb L -1 <= i ? (pin back L 1))
                              ['jmpt _ _ ls] (map (L \ pin bad L 1) ls)
                              (('fix . _) && 4 < #f) (map (L \ pin bad L 1) (f 4))
                              _ 0,
                           i + 1)) 0 fs)
       ; only what can change a bound or a state is walked: each as (its index . the forms from it)
       cv (nmcmv g fs)
       (want? f) (f @ ['cmp t _] (dem t != ())
                      ('cmp . _) 0
                      _ (nmwctl <f || two? (nmext <f) || (raops g f @ [_ ds] (any dem ds) _ 0)))
       ws (: (go l j) (l @ (f . u) (want? f ? ((j . l) . go u (j + 1)) (go u (j + 1))) _ ())
             (go fs 0))
       ; one walk under the heads' assumptions A -> [the forms that go, the states into each label, each head's]
       (rnd A)
        (: pend {} hs {} gone {}
           (keep L w) (bad L ? 0 (pin pend L (nmcp w . pend L)))
           (go ws w last fall)
            (ws @ ((j . l) . v)
                   (: f <l u >l
                      (b x) (cint? x ? [x x] (w x))
                      ; any form with no bound to make or use, as itself
                      (rest _)
                       (: t0 (elem <f '(set cmov) ? (f 2) (f 1))
                          (bb x y) (b x @ () () n (b y @ () () m [n m]))
                          nb (dem t0 = () ? ()
                                (f @ ['li t k] (b k)
                                     ['mov t a] (b a)
                                     ([op t _ _] && two? (nmldw op)) (nmldw op)
                                     ([op t _ _ _ _] && two? (nmldw op)) (nmldw op)
                                     ([op t] && two? (nmext op)) (nmext op @ e (b t @ () e x (nmin? x e ? x e)))
                                     ['set _ t] [0 1]
                                     ['cmov cc t a] (b a @ () () m (: n (cv j @ [_ k] (nmcut g (b t) (nmneg cc) (b k)) _ (b t)) (two? n ? (nmor n m))))
                                     ['and t x y] (nmand (b x) (b y))
                                     [('or || 'xor) t x y] (bb x y @ () () [n m] (nmnn n && nmnn m ? [0 (nmcov (max (n 1) (m 1)))] (nmbits n m)))
                                     ['add t x y] (bb x y @ () () [n m] [(<n + <m) (n 1 + m 1)])
                                     ['sub t x y] (bb x y @ () () [n m] [(<n - m 1) (n 1 - <m)])
                                     ['imul t x y] (bb x y @ () () [n m] (: p [(<n * <m) (<n * m 1) (n 1 * <m) (n 1 * m 1)] [(foldl min <p >p) (foldl max <p >p)]))
                                     ['shr t k] (b t @ () () n (cint? k && nmnn n ? [(<n >> k) (n 1 >> k)]))
                                     ['sar t k] (b t @ () () n (cint? k ? [(<n >> k) (n 1 >> k)]))
                                     ['shl t k] (b t @ () () n (cint? k && k < 32 ? [(<n * 2 ** k) (n 1 * 2 ** k)]))
                                     _ ()))
                          _ (raops g f @ [_ ds]
                             (map (x \ w x != () ? (pin w x ())) ds,
                              lovr? t0 && elem t0 ds && nmok g nb ? (pin w t0 nb))
                             _ 0)
                          (go v w j 1))
                      (!(nmwctl <f || two? (nmext <f)) ? (rest 0)
                      (f @ ['label L]
                            (: cs ((fall || j != last + 1 ? [w] ()) + pend L)
                               w0 (bad L || !(two? cs) ? {} (foldl nmmeet <cs >cs))
                               ; a head only jumped back to first guesses the state laid before it
                               w1 (back L ? (A L @ () (two? cs ? w0 (nmcp w)) a (two? cs ? (nmmeet w0 a) (nmcp a))) w0)
                               (back L ? (pin hs L (nmcp w1)), go v w1 j 1))
                           ([op t] && two? (nmext op) && two? (b t) && nmin? (b t) (nmext op)) (pin gone j 1, go v w j 1)
                           ; a value already 0 or 1 made boolean again
                           ['cmp t k] (u @ ((['set 'ne t2] . u2) && k = 0 && t = t2 && lovr? t && two? (b t) && nmin? (b t) [0 1] && !(nmflg? u2)) (pin gone j 1, pin gone (j + 1) 1, go >v w (j + 1) 1)
                                           ; a branch on it bounds it either way
                                           ((['br cc L] . _) && lovr? t)
                                            (: (cut c w2) (nmcut g (b t) c (b k) @ z (nmok g z ? (pin w2 t z) w2))
                                               (keep L (cut cc (nmcp w)), cut (nmneg cc) w, go >v w (j + 1) 1))
                                           _ (rest 0))
                           ['jmp L] (keep L w, go v w j 0)
                           ['br _ L] (keep L w, go v w j 1)
                           (('ret || 'jmpt) . _) (go v w j 0)
                           _ (rest 0))))
                  _ 0)
           (go ws {} -1 1, [gone pend hs]))
       ; a head holds when every way in stays under it; one that does not widens, and after six
       ; rounds every head knows nothing
       (held? pend hs L) (hs L @ () 1 h (all (c \ all (k \ (h k @ () 1 x (c k @ () 0 v (nmin? v x)))) (keys h)) (pend L)))
       (fix A k)
        (rnd A @ [out pend hs]
           (filter (L \ !(held? pend hs L)) (keys back) @
              () out
              ls (k < 1 ? (rnd (foldl (t \ L \ pin t L {}) {} (keys back)) @ [o2 _ _] o2)
                    (fix (foldl (t \ L \ pin t L (hs L @ h (nmwide g h (foldl nmmeet h (pend L))))) (nmcp A) ls) (k - 1)))))
       (fix {} 6 @ gone
          (: (kept l j) (l @ (f . u) (gone j ? (kept u (j + 1)) (f . kept u (j + 1))) _ ())
             (kept fs 0))))
   ; a head's bounds after a round: each that grew, to 32 bits or none
   (nmwide g h m) (foldl (t \ k \ (m k @ v (pin t k (h k @ () (nmstep g v) x (nmin? v x ? v (nmstep g v)))))) {} (keys m))
   (nmstep g v) (? (nmin? v [0 4294967295] && nmok g [0 4294967295]) [0 4294967295]
                   (nmin? v [-2147483648 2147483647]) [-2147483648 2147483647] ())
   ; the next form reads the flags a compare left
   (nmflg? u) (u @ ((('br || 'set || 'cmov) . _) . _) 1 _ 0)
   (nmcp w) (foldl (t \ k \ (w k @ () t v (pin t k v))) {} (keys w))
   ; two blocks' bounds where they join: the span of each both know
   (nmmeet a b) (foldl (t \ k \ (a k @ () t x (b k @ () t y (pin t k (nmor x y))))) {} (keys a))

   ; per vreg its defs and its reads -> [defs reads]
   (nmcnt g fs)
    (: dn {} un {}
       (bump t x) (lovr? x ? (pin t x (peep t x 0 + 1)))
       _ (map (f \ (raops g f @ [u d] (map (bump un) u, map (bump dn) d) _ 0)) fs)
       [dn un])

   ; only the defs
   (nmdn g fs)
    (: dn {}
       (map (f \ (raops g f @ [_ d] (map (x \ lovr? x ? (pin dn x (peep dn x 0 + 1))) d) _ 0)) fs, dn))

   ; a one-def vreg copied from another, or holding a literal that fits an immediate -> [copies literals]
   (nmmaps fs dn)
    (: cp {} kc {}
       (one? x) (lovr? x && peep dn x 0 = 1)
       _ (map (f \ (f @ ([('mov || 'movapd) x y] && one? x && one? y) (pin cp x y)
                        (['li x k] && one? x && cint? k && fits32 k) (pin kc x k)
                        _ 0)) fs)
       [cp kc])
   ; two literals under an op, the bitwise ones over naturals only | ()
   (nmk op x y) (op @ 'add (x + y) 'sub (x - y) 'imul (x * y)
                      _ (x < 0 || y < 0 ? () (op @ 'and (x & y) 'or (x | y) _ (x ^ y))))
   ; the copies' readers read the source, and a literal rides where the form takes an immediate;
   ; a one-def vreg folded to a literal is one from there on
   (nmsub g fs cp kc dn)
    (: (r x) (cp x @ () x y (r y))
       (lit d n) ((lovr? d && peep dn d 0 = 1 ? (pin kc d n)), ['li d n])
       (k x) (kc (r x))
       (kv x) (cint? x ? x (k x))
       (imm f) (f @ ([op d a b] && elem op raalu)
                     (: x (kv a) y (kv b) n (cint? x && cint? y ? (nmk op x y))
                        (? (cint? n && fits32 n) (lit d n)
                           (cint? y && imma g op y) [op d a y]
                           (cint? x && elem op racomm && imma g op x) [op d b x]
                           f))
                    ['cmp a b] (k b @ () f n (imma g 'cmp n ? ['cmp a n] f))
                    ([op b o v] && x86? g && nmsi op) (k v @ () f n (k b @ () [(nmsi op) b o n] _ f))
                    ['mov d y] (k y @ () f n ['li d n])
                    f)
       ; an unsigned divide or remainder by a power of two: a shift or a mask
       (pw x) (cint? x && 0 < x && x & (x - 1) = 0)
       (dv f) (f @ (('udiv . d . a . b . _) && pw (kv b)) [['mov d a] ['shr d (nmlog (kv b))]]
                   (('urem . d . a . b . _) && pw (kv b) && imma g 'and (kv b - 1)) [['and d a (kv b - 1)]]
                   _ ())
       ; a compare of two known values decides its branch or select, lo.l laying a compare before each. in a
       ; block a value of more defs is known too, from its last literal
       (kb t x) (cint? x ? x (peep t x () @ () (k x) n n))
       (kbr l t)
        (l @ ((['cmp a b] . ['br cc L] . u) && cint? (kb t a) && cint? (kb t b) && peep nmcc cc ())
              (nmcc cc (kb t a) (kb t b) ? (['jmp L] . kbr u t) (kbr u t))
             ((['cmp a b] . ['cmov cc d s] . u) && cint? (kb t a) && cint? (kb t b) && peep nmcc cc ())
              (kbr (nmcc cc (kb t a) (kb t b) ? (['mov d s] . u) u) t)
             (f . u)
              (f . kbr u (f @ ('label . _) {}
                              ['li d n] (pin t d n)
                              ['mov d y] (kb t y @ () (pin t d ()) n (pin t d n))
                              _ (raops g f @ [_ ds] (foldl (t2 \ d \ pin t2 d ()) t ds) _ t)))
             _ ())
       (kbr (catmap (f \ (f @ ([('mov || 'movapd) x _] && peep cp x ()) ()
                         (_ . _) (map r f @ f2 (dv f2 @ () [(imm f2)] fs2 fs2))
                         [f])) fs) {}))
   (nmlog n) (n <= 1 ? 0 (1 + nmlog (n // 2)))
   ; a literal and the one-register rewrite after it: one literal
   nmun {'neg (k \ 0 - k) 'not (k \ -1 - k)
         'zx1 (k \ (k % 256 + 256) % 256) 'zx2 (k \ (k % 65536 + 65536) % 65536)
         'zx4 (k \ (k % 4294967296 + 4294967296) % 4294967296)
         'sx1 (k \ (k % 256 + 256) % 256 @ z (z < 128 ? z (z - 256)))
         'sx2 (k \ (k % 65536 + 65536) % 65536 @ z (z < 32768 ? z (z - 65536)))
         'sx4 (k \ (k % 4294967296 + 4294967296) % 4294967296 @ z (z < 2147483648 ? z (z - 4294967296)))}
   (nmlit fs)
    (fs @ ((['li t k] . [op t2] . u) && t = t2 && cint? k && peep nmun op ()) (nmlit (['li t ((nmun op) k)] . u))
          ((['li t k] . ['shl t2 n] . u) && t = t2 && cint? k && cint? n && 0 <= n < 32 && fits32 (k * n 2)) (nmlit (['li t (k * n 2)] . u))
          (f . u) (f . nmlit u)
          _ ())

   ; within a block, a vreg's one def but its declaration's while what it read still holds: copies
   ; read through, an add or lea of a literal moves into the offset, an add of a scaled index into an
   ; indexed form. av: each def that holds, rv: per register the defs that read it, so a write drops
   ; them; a def that reads its own target is never held
   (nmloc g fs)
    (: dr (foldl (t \ f \ (f @ (('cdef . _) && !(abl? g 'nmdecl)) t
                                _ (raops g f @ [_ d] (foldl (t2 \ x \ (lovr? x ? (pin t2 x (peep t2 x 0 + 1)) t2)) t d) _ t))) {} fs)
       (one? x) (lovr? x && peep dr x 0 = 1)
       (go fs av rv)
        (fs @ (f . u)
               (f @ ('label . _) (f . go u {} {})
                    _ (nmfold g f av @ f2
                       (raops g f2 @ [rs ds]
                          (: _ (map (d \ (map (t \ pin av t ()) (rv d), pin av d (), pin rv d ())) ds)
                             e (f2 @ ([('add || 'lea || 'imul || 'and) t _ _] && one? t && nelem t rs) rs
                                     (['mov t y] && one? t && lovr? y && y != t) [y]
                                     (['li t k] && one? t) ()
                                     _ 'no)
                             _ (e = 'no ? 0 (pin av <>f2 f2, map (x \ pin rv x (<>f2 . rv x)) e))
                             (f2 . go u av rv))
                          _ (f2 . go u {} {}))))
              _ ())
       (go fs {} {}))
   (nmav av x) (av x)
   (nmfold g f0 av)
    (: (cpy x) (nmav av x @ ['mov _ y] y _ x)
       f (f0 @ (('fix || 'cdef || 'cuse) . _) f0 (_ . _) (map cpy f0) f0)
       ; a scale is a literal, or a register a literal loaded (a64 multiplies registers alone)
       (scl s) (cint? s ? s (nmav av s @ ['li _ k] k _ ()))
       (base b o) (nmav av b @ ([('add || 'lea) _ b2 k] && cint? k && cint? o && fits32 (o + k)) [b2 (o + k)] _ ())
       (idx b o) (nmav av b @ (['add _ b2 x] && lovr? x)
                               (nmav av x @ (['imul _ i s] && elem (scl s) '(1 2 4 8)) [b2 i (scl s) o] _ [b2 x 1 o])
                              _ ())
       (f @ ([op d b o] && elem op (ldops9 + fldops))
             (base b o @ [b2 o2] [op d b2 o2]
                _ (nmxop g op @ () f xo (idx b o @ [b2 i s o2] (nmxfar g xo o2 ? f [xo d b2 i s o2]) _ f)))
            ([op b o v] && elem op (gstops + fstops))
             (base b o @ [b2 o2] [op b2 o2 v]
                _ (nmxsop g op @ () f xo (idx b o @ ([b2 i s o2] && (o2 = 0 || !(t32? g))) (nmxfar g xo o2 ? f [xo b2 i s o2 v]) _ f)))
            ([op d b o] && elem op leaops)
             (base b o @ [b2 o2] [op d b2 o2]
                _ (<f = 'lea && o = 0 && lovr? b ? ['mov d b] f))                 ; no offset is a copy
            ; an indexed form's base and displacement fold the same way, not a64's frame base, which
            ; may be sp, nor where v6-M's form has no displacement
            ([op d b i s o] && elem op (xops + fxops))
             (base b o @ ([b2 o2] && !(nmxfar g op o2) && !(a64? g && b2 = 'r4) && (o2 = 0 || !(v6m? g))) [op d b2 i s o2] _ f)
            ([op b i s o v] && elem op (stxops + fstxops))
             (base b o @ ([b2 o2] && !(nmxfar g op o2) && !(a64? g && b2 = 'r4) && (o2 = 0 || !(t32? g))) [op b2 i s o2 v] _ f)
            ([op b o v] && elem op siops) (base b o @ [b2 o2] [op b2 o2 v] _ f)
            ; an add of a literal onto a literal's sum is one add
            (['add d a k] && cint? k && lovr? a) (base a k @ ([b2 o2] && lovr? b2) ['add d b2 o2] _ f)
            ['cmp t 0] (nmav av t @ (['and _ a k] && (!(charm? k) || immok g 'log k)) ['test a k] _ f)
            f))

   ; (op t ..) (mov x t), t's one def and one read: the op writes x
   (nmsink g fs)
    (nmcnt g fs @ [dn un]
       (: (own? f t x) (raops g f @ [u [d]] (d = t && nelem t u && #(filter (y \ y = t) f) = 1 &&
                                             !(<f = 'sub && elem x u) && nelem <f '(fix call callr cdef))
                                    _ ())
          (go fs) (fs @ ((f . [('mov || 'movapd) x t] . u) && lovr? x && lovr? t && lofr? x = lofr? t &&
                         peep dn t 0 = 1 && peep un t 0 = 1 && own? f t x)
                         ((map (y \ y = t ? x y) f) . go u)
                        (f . u) (f . go u)
                        _ ())
          (go fs)))

   (nmround g fs0)
    (nmwid g (nmlit fs0) @ fs
       (nmdn g fs @ dn
          (nmmaps fs dn @ [cp kc]
             ; the substitution may add defs, so the block pass counts again
             (nmsub g fs cp kc dn @ f2 (nmdn g f2 @ d2 (nmsink g (radce g (nmshl g (nmloc g f2) d2))))))))
   ; a multiply by a power of two the fold left is a shift, off x86 through a register;
   ; x86's literal by 3, 5 or 9 of one a lea, then the shift
   (nmshl g fs dn)
    (: (lg n) (n = 1 ? 0 (1 + lg (n >> 1)))
       kv (foldl (t \ f \ (f @ (['li k n] && lovr? k && peep dn k 0 = 1) (pin t k n) _ t)) {} fs)
       (p2 n) (cint? n && 1 < n && n & (n - 1) = 0)
       (odd n) (n & 1 = 1 ? n (odd (n >> 1)))
       (x86k d a k) (odd k @ m ((m = 1 ? (a = d ? () [['mov d a]]) [['leax d a a (m - 1) 0]]) + (1 < k // m ? [['shl d (lg (k // m))]])))
       (kx86? k) (cint? k && 1 < k && (k & (k - 1) = 0 || elem (odd k) '(3 5 9)))
       (go fs) (fs @ ((['mov d a] . ['imul d2 x k] . u) && d = d2 && d = x && kx86? k) (x86k d a k + go u)
                     (f . u) (((f @ (['imul d a k] && kx86? k) (x86k d a k) _ [f])) + go u)
                     ())
       (x86? g ? (go fs)
          (catmap (f \ (f @ (['imul d a k] && lovr? k && p2 (kv k)) [['mov d a] ['shl d (lg (kv k))]] _ [f])) fs)))
   ; a wide literal or an address a loop makes again each time round, one-def, is made once ahead of
   ; the outermost loop entered only by its head or a jump to its test; the same one again is a
   ; copy. a few to a loop, each a register held across it. -> fs itself when nothing moves
   nmhmax 4
   (nmhoist g fs)
    (: dn (nmdn g fs)
       lab {} ft {} n (foldl (i \ f \ (pin ft i f, (f @ ['label L] (pin lab L i) _ 0), i + 1)) 0 fs)
       (dests f) (f @ ['jmp L] [L] ['br _ L] [L] ['jmpt _ _ ls] ls (('fix . _) && 4 < #f) (f 4) _ ())
       refs (catmap (i \ map (L \ [i (peep lab L -1)]) (dests (ft i))) ^n)
       far (foldl (t \ r \ (r @ ([i a] && 0 <= a <= i && peep t a -1 < i) (pin t a i) _ t)) {} refs)   ; head -> last jump back
       spans (sort (keys far))
       (pre a b)                                         ; the index the span's values go ahead of | ()
        (: p (0 < a && (ft (a - 1) @ ['jmp E] (a < peep lab E -1 <= b) _ 0) ? (a - 1) a)
           (any (r \ r @ [i t] (a <= t <= b && !(a <= i <= b) && i != p) _ 0) refs ? () p))
       (hoist? f) (f @ (['li t k] && lovr? t && peep dn t 0 = 1 && cint? k && !(fits32 k)) 1
                       (['la t _] && lovr? t && peep dn t 0 = 1) 1
                       _ 0)
       ins {} out {}                                     ; index -> what goes ahead of it, last first; a form's fate
       (add p i f)
        (: k (show (f 2)) seen (peep ins p ())
           (assoc k seen @ () (#seen < nmhmax ? (pin ins p ((k . f) . seen), pin out i 1) 0)
                            e (pin out i ['mov (f 1) (>e 1)])))
       (seat l i f)
        (l @ (a . u) (a <= i <= far a ? (pre a (far a) @ () (seat u i f) p (add p i f)) (seat u i f)) _ 0)
       _ (map (i \ (hoist? (ft i) ? (seat spans i (ft i)) 0)) ^n)
       (#(keys out) = 0 ? fs
          (catmap (i \ map cup (rev (peep ins i ())) + (out i @ () [(ft i)] 1 () m [m])) ^n)))
   ; t32 has no scaled index. in an innermost rotated loop, (jmp E) (label L) .. (br cc L), entered
   ; only by that jump: an address B + (v << k), v the loop's one-step counter and B the same all
   ; through it, read only in its own straight run, becomes a pointer set ahead of the jump and
   ; stepped beside v; a load or store at the pointer, then its step in the same straight run, is
   ; one post-increment. -> fs itself when nothing moves
   nmpi {'ldss 'ldsspi 'ld4 'ldpi4 'ldu4 'ldpi4 'ld 'ldpi4}
   nmps {'stss 'stsspi 'st4 'stpi4 'st 'stpi4}
   (nmrd g f) (raops g f @ [u d] [u d] _ [() ()])
   (nmlsr g fs)
    (: lab {} ft {} n (foldl (i \ f \ (pin ft i f, (f @ ['label L] (pin lab L i) _ 0), i + 1)) 0 fs)
       (dests f) (f @ ['jmp L] [L] ['br _ L] [L] ['jmpt _ _ ls] ls (('fix . _) && 4 < #f) (f 4) _ ())
       refs (catmap (i \ map (L \ [i (peep lab L -1)]) (dests (ft i))) ^n)
       held {} _ (map (r \ (r @ [_ t] (pin held t 1) _ 0)) refs)
       ; no form strictly between i and j a referenced label or a transfer
       (run? i j) (all (x \ ft x @ ['label L] !(held (lab L)) (('jmp || 'br || 'jmpt || 'ret || 'jmpr) . _) 0 _ 1) (map (+ (i + 1)) ^(j - i - 1)))
       (loop? a b) (0 < a && (ft (a - 1) @ ['jmp E] (a < peep lab E -1 <= b) _ 0) &&
                    all (r \ r @ [i t] ((a <= t <= b ? (a <= i <= b || i = a - 1) 1) && (a <= i <= b && t <= i ? (i = b && t = a) 1)) _ 1) refs)
       loops (catmap (r \ r @ ([b a] && 0 <= a < b && loop? a b) [[a b]] _ ()) refs)
       us {} ds {}
       (cnt t x) (pin t x (peep t x 0 + 1))
       _ (map (f \ (nmrd g f @ [u d] (map (cnt us) u, map (cnt ds) d))) fs)
       (uses x) (filter (i \ nmrd g (ft i) @ [u _] (elem x u) _ 0) ^n)
       ; a loop's plan [drops renames pre steps]: forms gone, [vreg pointer] read through, forms ahead
       ; of the jump, [i P d] a step after form i
       (plan lp)
        (lp @ [a b]
           (: span (map (+ a) ^(b - a + 1))
              dl {} _ (map (i \ (nmrd g (ft i) @ [_ d] (map (cnt dl) d))) span)
              (ivat v) (filter (i \ ft i @ (['add x y c] && x = v && y = v && cint? c) 1 _ 0) span @ [i] i _ ())
              (iv? v) (peep dl v 0 = 1 && ivat v != ())
              (inv? x) (lovr? x && peep dl x 0 = 0)
              (tri j)
               (ft j @ (['mov t v] && lovr? t && lovr? v && iv? v)
                        (ft (j + 1) @ (['shl t2 k] && t2 = t && cint? k && 0 <= k <= 3)
                           (ft (j + 2) @ (['add x p q] && (p = t && inv? q || q = t && inv? p) && lovr? x &&
                                           peep ds x 0 = 1 && peep us t 0 = 2 && peep ds t 0 = 2)
                              (: e (uses x) s (ivat v)
                                 (two? e && all (i \ j + 2 < i < s && run? (j + 2) (i + 1)) e ? [j v k (p = t ? q p) x]))
                              _ ())
                           _ ())
                        _ ())
              ts (filter two? (map tri span))
              ps (foldl (t \ c \ (c @ [_ v k B _] (show [v k B] @ key (t key @ () (pin t key [(lomk g) v k B]) _ t)) _ t)) {} ts)
              (ptr c) (c @ [_ v k B _] <(ps (show [v k B])) _ ())
              ks (sort (keys ps))
              ; the exit (cmp v m) (br below L), v read by nothing else but its step: a pointer's
              ; test against B + (m << k), and v goes
              (lftr P v k2 B)
               (: s (ivat v) nv #(filter (c \ c 1 = v) ts)
                  (ft (b - 1) @ (['cmp x m] && x = v && (cint? m || inv? m) && (ft b @ ['br 'below _] 1 _ 0) &&
                                 0 < ft s 3 && peep us v 0 = nv + 2)
                     (lomk g @ E [[s] ((cint? m ? [['li E (m << k2)]] [['mov E m] ['shl E k2]]) + [['add E E B]]) [(b - 1) ['cmp P E]]])
                     _ ()))
              lf (ks @ (k . _) (ps k @ [P v k2 B] (lftr P v k2 B) _ ()) _ ())
              [(catmap (c \ c @ [j _ _ _ _] [j (j + 1) (j + 2)] _ ()) ts + (lf @ [d _ _] d _ ()))
               (map (c \ c @ [_ _ _ _ x] [x (ptr c)] _ ()) ts)
               (catmap (k \ ps k @ [P v k2 B] [['mov P v] ['shl P k2] ['add P P B]] _ ()) ks + (lf @ [_ p _] p _ ()))
               (map (k \ ps k @ [P v k2 B] [(ivat v) P (ft (ivat v) 3 * (1 << k2))] _ ()) ks)
               (lf @ [_ _ r] [r] _ ())])
         _ [() () () () ()])
       rs (map (lp \ [lp (plan lp)]) loops)
       (any (r \ r @ [_ [(_ . _) _ _ _ _]] 1 _ 0) rs ? (nmpinc g (nmlsr2 fs ft n rs)) fs))
   (nmlsr2 fs ft n rs)
    (: drop {} ren {} pre {} stp {} rep {}
       _ (map (r \ (r @ [[a _] [d e p s x]]
                       (map (j \ pin drop j 1) d, map (y \ pin ren (y 0) (y 1)) e, pin pre (a - 1) p,
                        map (y \ y @ [i P d2] (pin stp i (peep stp i () + [['add P P d2]])) _ 0) s,
                        map (y \ pin rep (y 0) (y 1)) x)
                       _ 0)) rs)
       (sub f) (atom? f ? f (map (x \ peep ren x x) f))
       (catmap (i \ peep pre i () + (drop i ? () [(sub (peep rep i (ft i)))]) + peep stp i ()) ^n))
   ; a pointer's step folds into the load or store just behind it in its straight run
   (nmpinc g fs)
    (: held {} _ (map (f \ (f @ ['jmp L] (pin held L 1) ['br _ L] (pin held L 1) ['jmpt _ _ ls] (map (L \ pin held L 1) ls) _ 0)) fs)
       (stop? f) (f @ ['label L] (held L) (('jmp || 'br || 'jmpt || 'ret || 'jmpr || 'fix || 'call || 'callr) . _) 1 _ 0)
       ; back from the step over forms that leave P be, to the one that reads it
       (fold acc P)
        (acc @ (f . u)
                (? (stop? f) ()
                   (f @ (['ldss w b 0] || ['ld4 w b 0] || ['ldu4 w b 0] || ['ld w b 0]) (b = P && w != P) _ 0)
                    (f @ [op w _ _] [([(nmpi op) w P] . u)] _ ())
                   (f @ (['stss b 0 w] || ['st4 b 0 w] || ['st b 0 w]) (b = P && w != P) _ 0)
                    (f @ [op _ _ w] [([(nmps op) P w] . u)] _ ())
                   (nmrd g f @ [x y] (elem P x || elem P y) _ 1) ()
                   (fold u P @ () () [l] [(f . l)]))
               _ ())
       (go acc l)
        (l @ ((['add P P 4] && lovr? P) . u) (fold acc P @ () (go (<l . acc) u) [a2] (go a2 u))
             (f . u) (go (f . acc) u)
             _ (rev acc))
       (go () fs))
   ; -> the forms normalised; a form whose reads raops cannot say leaves them as they are
   (nmall g fs)
    (any (f \ raops g f @ 'bad 1 _ ()) fs ? fs (nmfwd g (nmlow g (nmfix g (nmreach (nminv g (nmfuse g fs))) @ r (? (x64? g || a64? g) (nmhoist g r @ h (h == r ? r (nmfix g h))) (t32? g && !(v6m? g)) (nmlsr g r @ h (h == r ? r (nmfix g h))) r)))))
   ; a 32-bit extension of a vreg whose every reader takes only its low half goes. such a reader:
   ; the extension, a store of 4 bytes or less, or an add, sub, imul, and, or, xor or copy whose
   ; answer is such a vreg in turn or is extended by the next form
   (nmlow g fs)
    (: lv {}
       _ (map (f \ (raops g f @ [u _] (map (x \ lovr? x ? (pin lv x 1)) u) _ 0)) fs)
       ; a form's full reads, nx the form after it
       (full f nx)
        (: (low? t) (lv t = 1 || (nx @ [('zx4 || 'sx4) v] (v = t) _ 0))
           (f @ [('zx4 || 'sx4) _] ()
                [('st4 || 'st2 || 'st1) b o _] [b o]
                [('add || 'sub || 'imul || 'and || 'or || 'xor) t x y] (low? t ? () [x y])
                ['mov t a] (lovr? t && low? t ? () [a])
                _ (raops g f @ [u _] u _ ())))
       (sweep l c) (l @ (f . u) (sweep u (foldl (c2 \ x \ (lv x = 1 ? (pin lv x 0, 1) c2)) c (full f (u @ (n . _) n _ ())))) _ c)
       (fix _) (sweep fs 0 @ 0 0 _ (fix 0))
       _ (fix 0)
       (filter (f \ !(f @ [('zx4 || 'sx4) v] (lv v = 1) _ 0)) fs))
   ; in a block, past (mov t v) a read of v reads t while neither is written, where that lets v die
   ; at the copy: ra's copy hint then gives the two one register. a form that also writes v or t
   ; (a cmov onto itself has no encoding), or an asm, ends it. a round leaves the names it moved to the next, over fresh liveness
   (nmfwd g fs) (abl? g 'fwd ? fs (nmfwd1 g fs 4))
   (nmfwd1 g fs k)
    (k = 0 ? fs
       (ralive g fs @ [ft ud _ lout]
          (: n #fs
             (out? x i) (elem x (lout i))
             (end? f) (f @ (('label || 'jmp || 'br || 'jmpt || 'ret || 'fix || 'cdef || 'cuse) . _) 1 _ 0)
             ; the reads past the copy to rewrite, the last one leaving v dead -> indices | ()
             (scan v t i acc)
              (n <= i ? ()
                 (ft i @ ('label . _) ()
                    f (ud i @ [u d]
                         (: rd (elem v u) wv (elem v d) wt (elem t d)
                            (? (rd && (wv || wt || end? f)) ()
                               rd (: a2 (i . acc) (out? v i ? (scan v t (i + 1) a2) a2))
                               wv acc
                               (wt || end? f) (out? v i ? () acc)
                               (scan v t (i + 1) acc))))))
             (cp i) (ft i @ ([('mov || 'movapd) t v] && lovr? t && lovr? v && t != v && lofr? t = lofr? v) [t v] _ ())
             dirty {} rw {}
             _ (map (i \ (cp i @ [t v]
                            (!(dirty t) && !(dirty v) && out? v i ?
                               (scan v t (i + 1) () @ l
                                  (two? l && all (j \ !(two? (rw j))) l ? (map (j \ pin rw j [v t]) l, pin dirty t 1, pin dirty v 1))))
                            _ 0)) ^n)
             (!(two? (keys rw)) ? fs
                (nmfwd1 g (map (i \ (rw i @ [v t] (map (x \ x = v ? t x) (ft i)) _ (ft i))) ^n) (k - 1))))))
   ; a decided branch's dead arm may hold a value's other def: round again without it
   (nmfix g fs)
    (nmround g (nmround g fs) @ r
       (deadlabk (cg-refs (g 'fasecs) {}) (nmreach r) @ d (#d < #r ? (nmfix g d) d)))
)) ; module 'moon
