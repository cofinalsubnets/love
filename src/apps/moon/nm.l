; src/apps/moon/nm.l -- the new backend's normalise stage, lo.l's forms to lo.l's forms before ra.l:
; copy-then-op fused to three-address, copies and constants propagated, address arithmetic folded
; into loads and stores, extensions of values already in range dropped, unreachable forms dropped.
; each rule keeps the forms' meaning on its own
(module 'moon
(borrow 'holo)
(:
   ; x64's indexed twin of a load or store, and a store's immediate twin; a64 has neither the
   ; 32-bit indexed loads nor a store of an immediate, riscv only the word and byte twins
   nmxld {'ld 'ldx 'ldu1 'ldxb 'ldu4 'ldxw 'ld4 'ldxsw 'ldsd 'ldsdx 'ldss 'ldssx}
   nmxst {'st 'stx 'st1 'stxb 'stsd 'stsdx 'stss 'stssx}
   nmsi {'st 'si 'st1 'si1 'st2 'si2 'st4 'si4}
   (nmxop g op) (peep nmxld op () @ () () xo (? (x64? g) xo (rv64? g) (elem xo '(ldx ldxb) ? xo) (nelem xo '(ldxw ldxsw) ? xo)))
   (nmxsop g op) (peep nmxst op () @ () () xo (rv64? g && nelem xo '(stx stxb) ? () xo))

   ; (mov d a) (op d d b) -> (op d a b): b is read before d is written. a64's register ALU
   ; cannot read sp
   (nmfuse g fs)
    (fs @ ((['mov d a] . [op x y b] . u) && lovr? d && d = x && d = y && b != d && elem op raalu && (x64? g || a != 'sp))
           ([op d a b] . nmfuse g u)
          (f . u) (f . nmfuse g u)
          _ ())
   ; nothing reaches past a jump or a return but through a label; a jump to a label just after
   ; it goes
   (nmreach fs)
    (fs @ ((['jmp L] . u) && nmnext? u L) (nmreach u)
          (f . u) (f . nmreach (f @ (('jmp || 'ret) . _) (nmskip u) _ u))
          _ ())
   (nmnext? fs L) (fs @ (['label x] . u) (x = L || nmnext? u L) _ ())
   (nmskip fs) (fs @ (('label . _) . _) fs (_ . u) (nmskip u) _ ())

   ; a value's upper bound when it is known not negative, forward through a block: an extension
   ; that cannot change its operand goes
   nmext {'zx1 255 'zx2 65535 'zx4 4294967295 'sx1 127 'sx2 32767 'sx4 2147483647}
   nmldw {'ldu1 255 'ldxb 255 'ldu2 65535 'ldu4 4294967295 'ldxw 4294967295}
   (nmcov n) (n < 1 ? 0 (2 * nmcov (n // 2) + 1))
   (nmwid g fs)
    (: lb (vlabs fs)
       ; a table or asm goto's target knows nothing; a loop's head assumes its bounds until they hold
       bad {} back {}
       _ (foldl (i \ f \ (f @ ['jmp L] (peep lb L -1 <= i ? (pin back L 1))
                              ['br _ L] (peep lb L -1 <= i ? (pin back L 1))
                              ['jmpt _ _ ls] (map (L \ pin bad L 1) ls)
                              (('fix . _) && 4 < #f) (map (L \ pin bad L 1) (f 4))
                              _ 0,
                           i + 1)) 0 fs)
       ; one walk under the heads' assumptions A -> [forms, the states into each label, each head's]
       (rnd A)
        (: pend {} hs {}
           (keep L w) (peep bad L () ? 0 (pin pend L (nmcp w . peep pend L ())))
           (go fs w i fall)
            (fs @ (f . u)
                   (: (b x) (cint? x ? (x < 0 ? () x) (peep w x ()))
                      (f @ ['label L]
                            (: cs ((fall ? [w] ()) + peep pend L ())
                               w0 (peep bad L () || !(two? cs) ? {} (foldl nmmeet <cs >cs))
                               ; a head only jumped back to first guesses the state laid before it
                               w1 (peep back L () ? (A L @ () (two? cs ? w0 (nmcp w)) a (two? cs ? (nmmeet w0 a) (nmcp a))) w0)
                               (peep back L () ? (pin hs L (nmcp w1)), f . go u w1 (i + 1) 1))
                           ([op t] && peep nmext op () && b t != () && b t <= nmext op) (go u w (i + 1) 1)
                           ; a value already 0 or 1 made boolean again
                           ((['cmp t 0] . ['set 'ne t2] . u2) && t = t2 && lovr? t && b t != () && b t <= 1 && !(nmflg? u2)) (go u2 w (i + 2) 1)
                           ['jmp L] (keep L w, f . go u w (i + 1) 0)
                           ['br _ L] (keep L w, f . go u w (i + 1) 1)
                           (('ret || 'jmpt) . _) (f . go u w (i + 1) 0)
                           _ (: nb (f @ ['li t k] (b k)
                                        ['mov t a] (b a)
                                        ([op t _ _] && peep nmldw op ()) (nmldw op)
                                        ([op t _ _ _ _] && peep nmldw op ()) (nmldw op)
                                        ([op t] && peep nmext op ()) (op @ ('zx1 || 'zx2 || 'zx4) (nmext op))
                                        ['set _ t] 1
                                        ['and t x y] (b x @ () (b y) n (b y @ () n m (min n m)))
                                        [('or || 'xor) t x y] (b x @ () () n (b y @ () () m (nmcov (max n m))))
                                        ['add t x y] (b x @ () () n (b y @ () () m (n + m)))
                                        ['imul t x y] (b x @ () () n (b y @ () () m (n * m)))
                                        [('shr || 'sar) t k] (b t @ () () n (cint? k ? (n // 2 ** k)))
                                        ['shl t k] (b t @ () () n (cint? k && k < 32 ? (n * 2 ** k)))
                                        _ ())
                                _ (raops g f @ [_ ds]
                                   (map (x \ pin w x ()) ds,
                                    f @ ((_ . t . _) && lovr? t && elem t ds && nb != () && nb < 4611686018427387904) (pin w t nb) _ 0)
                                   _ 0)
                                (f . go u w (i + 1) 1))))
                  _ ())
           [(go fs {} 0 1) pend hs])
       ; a head holds when every way in stays under it; one that does not widens, and after six
       ; rounds every head knows nothing
       (held? pend hs L) (hs L @ () 1 h (all (c \ all (k \ (h k @ () 1 x (c k @ () 0 v (v <= x)))) (keys h)) (peep pend L ())))
       (fix A k)
        (rnd A @ [out pend hs]
           (filter (L \ !(held? pend hs L)) (keys back) @
              () out
              ls (k < 1 ? (rnd (foldl (t \ L \ pin t L {}) {} (keys back)) @ [o2 _ _] o2)
                    (fix (foldl (t \ L \ pin t L (hs L @ h (nmwide h (foldl nmmeet h (peep pend L ()))))) (nmcp A) ls) (k - 1)))))
       (fix {} 6))
   ; a head's bounds after a round: each that grew, to 32 bits or none
   (nmwide h m) (foldl (t \ k \ (m k @ v (pin t k (h k @ () (nmstep v) x (v <= x ? v (nmstep v)))))) {} (keys m))
   (nmstep v) (v <= 4294967295 ? 4294967295)
   ; the next form reads the flags a compare left
   (nmflg? u) (u @ ((('br || 'set) . _) . _) 1 _ 0)
   (nmcp w) (foldl (t \ k \ pin t k (w k)) {} (keys w))
   ; two blocks' bounds where they join: the looser of each both know
   (nmmeet a b) (foldl (t \ k \ (a k @ () t x (b k @ () t y (pin t k (max x y))))) {} (keys a))

   ; per vreg its defs and its reads -> [defs reads]
   (nmcnt g fs)
    (: dn {} un {}
       (bump t x) (lovr? x ? (pin t x (peep t x 0 + 1)))
       _ (map (f \ (raops g f @ [u d] (map (bump un) u, map (bump dn) d) _ 0)) fs)
       [dn un])

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
    (: (r x) (peep cp x () @ () x y (r y))
       (lit d n) ((lovr? d && peep dn d 0 = 1 ? (pin kc d n)), ['li d n])
       (k x) (peep kc (r x) ())
       (kv x) (cint? x ? x (k x))
       (imm f) (f @ ([op d a b] && elem op raalu)
                     (: x (kv a) y (kv b) n (cint? x && cint? y ? (nmk op x y))
                        (? (cint? n && fits32 n) (lit d n)
                           (cint? y && imma g op y) [op d a y]
                           (cint? x && elem op racomm && imma g op x) [op d b x]
                           f))
                    ['cmp a b] (k b @ () f n (imma g 'cmp n ? ['cmp a n] f))
                    ([op b o v] && x64? g && peep nmsi op ()) (k v @ () f n (k b @ () [(nmsi op) b o n] _ f))
                    ['mov d y] (k y @ () f n ['li d n])
                    f)
       ; an unsigned divide or remainder by a power of two: a shift or a mask
       (pw x) (cint? x && 0 < x && x & (x - 1) = 0)
       (dv f) (f @ (('udiv . d . a . b . _) && pw (kv b)) [['mov d a] ['shr d (nmlog (kv b))]]
                   (('urem . d . a . b . _) && pw (kv b) && imma g 'and (kv b - 1)) [['and d a (kv b - 1)]]
                   _ ())
       (catmap (f \ (f @ ([('mov || 'movapd) x _] && peep cp x ()) ()
                         (_ . _) (map r f @ f2 (dv f2 @ () [(imm f2)] fs2 fs2))
                         [f])) fs))
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
          (f . u) (f . nmlit u)
          _ ())

   ; within a block, a one-def vreg's def while what it read still holds: copies read through, an
   ; add or lea of a literal moves into the offset, an add of a scaled index into an indexed form
   ; av: each def that holds, rv: per register the defs that read it, so a write drops them
   (nmloc g fs dn)
    (: (one? x) (lovr? x && peep dn x 0 = 1)
       (go fs av rv)
        (fs @ (f . u)
               (f @ ('label . _) (f . go u {} {})
                    _ (nmfold g f av @ f2
                       (raops g f2 @ [rs ds]
                          (: _ (map (d \ (map (t \ pin av t ()) (peep rv d ()), pin av d (), pin rv d ())) ds)
                             e (f2 @ ([('add || 'lea || 'imul || 'and) t _ _] && one? t) rs
                                     (['mov t y] && one? t && lovr? y) [y]
                                     (['li t k] && one? t) ()
                                     _ 'no)
                             _ (e = 'no ? 0 (pin av <>f2 f2, map (x \ pin rv x (<>f2 . peep rv x ())) e))
                             (f2 . go u av rv))
                          _ (f2 . go u {} {}))))
              _ ())
       (go fs {} {}))
   (nmav av x) (peep av x ())
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
                _ (nmxop g op @ () f xo (idx b o @ [b2 i s o2] [xo d b2 i s o2] _ f)))
            ([op b o v] && elem op (gstops + fstops))
             (base b o @ [b2 o2] [op b2 o2 v]
                _ (nmxsop g op @ () f xo (idx b o @ [b2 i s o2] [xo b2 i s o2 v] _ f)))
            ([op d b o] && elem op leaops) (base b o @ [b2 o2] [op d b2 o2] _ f)
            ([op b o v] && elem op siops) (base b o @ [b2 o2] [op b2 o2 v] _ f)
            ; an add of a literal onto a literal's sum is one add
            (['add d a k] && cint? k && lovr? a) (base a k @ ([b2 o2] && lovr? b2) ['add d b2 o2] _ f)
            ['cmp t 0] (nmav av t @ ['and _ a k] ['test a k] _ f)
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
       (nmcnt g fs @ [dn _]
          (nmmaps fs dn @ [cp kc]
             ; the substitution may add defs, so the block pass counts again
             (nmsub g fs cp kc dn @ f2 (nmcnt g f2 @ [d2 _] (nmsink g (radce g (nmshl g (nmloc g f2 d2) d2))))))))
   ; off x64, a multiply by a power of two the fold left a register for is a shift
   (nmshl g fs dn)
    (: (lg n) (n = 1 ? 0 (1 + lg (n >> 1)))
       kv (foldl (t \ f \ (f @ (['li k n] && lovr? k && peep dn k 0 = 1) (pin t k n) _ t)) {} fs)
       (p2 n) (cint? n && 1 < n && n & (n - 1) = 0)
       (x64? g ? fs
          (catmap (f \ (f @ (['imul d a k] && lovr? k && p2 (kv k)) [['mov d a] ['shl d (lg (kv k))]] _ [f])) fs)))
   ; -> the forms normalised; a form whose reads raops cannot say leaves them as they are
   (nmall g fs)
    (any (f \ raops g f @ 'bad 1 _ ()) fs ? fs (nmround g (nmround g (nmreach (nmfuse g fs)))))
)) ; module 'moon
