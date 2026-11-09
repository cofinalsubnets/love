; src/apps/moon/lo.l -- the backend's lowering: AST -> forms over vregs (%nK). a physical
; register appears only in a copy next to the form that demands it (args, results, returns,
; params on entry, the shift count). an arm with no lane answers 'bad and lorefuse names why.
; ra.l lays first and mints the vregs. a value is (ty vreg forms), an lvalue ('v vreg ty) or
; ('a addr-value ty off). ra.l allocates what this lays
(module 'moon
(borrow 'holo)
(:

   (losc? ty) (elem ty ints9 || ty = 'bool || ptr? ty)
   (lofl? ty) (ty = 'double || ty = 'float)
   (losv? ty) (losc? ty || lofl? ty)
   (lomkt g ty) (lofl? ty ? (lomkf g) (lomk g))
   ; a double's bits into the float file, and out: a 32-bit target's two words any two registers
   (lobits g d bits)
    (ilp32? g ? (u64 bits @ u (lomk g @ l (lomk g @ h [['li l (u % 4294967296)] ['li h (u // 4294967296)] ['movqrr d l h]])))
       (lomk g @ t [['li t bits] ['movqxr d t]]))
   ; a zero of ty: riscv reads a single whose upper word is not all ones as a nan
   (lofz g d ty) (rv64? g && ty = 'float ? (lomk g @ t [['li t 0] ['movdxr d t]]) (lobits g d 0))
   (lomv d s) (lofr? d ? (lofo? d || lofo? s ? ['movss d s] ['movapd d s]) ['mov d s])
   ; a pointer's step: the pointee's size, void and functions one byte
   (lostep g ty) (<>ty @ 'void 1 ('fn . _) 1 ('varr . _) 'bad t (tsz g t))
   (lok g e) (knum g e @ ((k . _) && fits32 k) [k] ())
   ; d op= k, and lork3 d = a op k: the literal an immediate where the target takes it, else a register
   (lork g op d k) (lork3 g op d d k)
   (lork3 g op d a k) (imma g op k ? [[op d a k]] (lomk g @ t [['li t k] [op d a t]]))
   ; a float compare's condition: arm's fcmp reads unordered as above, so gt and ge stand in
   (lofcc g c) (arm? g ? (c @ 'above 'gt 'ae 'ge 'be 'le 'below 'lt _ c) c)

   ; a fresh register for a value, and the copy of one: a 32-bit pair is two of each
   (lomkv g ty) (pair? g ty || lovw? g ty ? (lomk g @ l (lomk g @ h [l h])) (lomkt g ty))
   ; a 64-bit word pair's __int128 local lives in two vregs
   (lovw? g ty) (d128? ty && lo128? g && !(t32w? g))
   (lomvs d s) (two? d ? [['mov <d <s] ['mov <>d <>s]] [(lomv d s)])
   ; a value converted to ty, copied when the conversion writes
   (lotr g [vt r fs] ty)
    (? (ilp32? g && (d128? ty || d128? vt)) (t32w? g ? (lowtr g [vt r fs] ty) (lono g ['wide ty], [ty r fs]))
       (ilp32? g && (pair? g ty || pair? g vt)) (lotrp g [vt r fs] ty)
       (gcplx? ty || gcplx? vt) (locxsame? vt ty ? [vt r fs] (locvt g [vt r fs] ty))
       (d128? ty || d128? vt) (lowtr g [vt r fs] ty)
       (lofl? ty || lofl? vt) (lotrf g [vt r fs] ty)
       (two? (cvt ty 'r0) && !(irfit? vt ty)) (lomk g @ t [ty t (fs + [['mov t r]] + cvt ty t)])
       [ty r fs])
   ; -- the 32-bit pair: a value [ty [lo hi] fs], a local two registers, the carry in the flags --
   lokl '(r0 r1 r2 r3 r12 f0 f1)
   ; ..what a helper's call clobbers there: riscv's caller-saved file
   (lokc g) (w32s? g ? (racl g) lokl)
   ; a value as a pair -> [fs lo hi]: a word widens by its source's signedness
   (lop g v)
    (v @ ([vt [l h] fs] && pair? g vt) [fs l h]
         [vt r fs] (lomk g @ l (lomk g @ h [(fs + [['mov l r]] + (usg? vt || ptr? vt ? [['li h 0]] [['mov h l] ['sar h 31]])) l h])))
   ; to or from a pair: the float file through kits, a word its low half
   (lotrp g [vt r fs] ty)
    (? (pair? g ty && pair? g vt) [ty r fs]
       (pair? g ty && lofl? vt && (t32? g || w32s? g))
        (lotr g [vt r fs] 'double @ [_ x f2]
           (lomk g @ l (lomk g @ h
              [ty [l h] (f2 + [['movrrq 'r0 'r1 x] '(cuse r0 r1) ['call (usg? ty ? '__aeabi_d2ulz '__aeabi_d2lz)] ['mov l 'r0] ['mov h 'r1]])])))
       (pair? g ty && lofl? vt)
        (lotr g [vt r fs] 'double @ [_ x f2]
           (lomk g @ l (lomk g @ h
              [ty [l h] (f2 + [['movapd 'f0 x] ['fix '(f0) (lokc g) (cvtdll g (usg? ty))] ['mov l 'r0] ['mov h 'r1]])])))
       (pair? g ty) (lop g [vt r fs] @ [f2 l h] [ty [l h] f2])
       (lofl? ty && (sp64? g || soft? g))
        (lomkf g @ d
           [ty d (fs + [['mov 'r0 <r] ['mov 'r1 <>r] '(cuse r0 r1)
                        ['call (ty = 'float ? (usg? vt ? '__aeabi_ul2f '__aeabi_l2f) (usg? vt ? '__aeabi_ul2d '__aeabi_l2d))]
                        (ty = 'float ? ['movdxr d 'r0] ['movqrr d 'r0 'r1])])])
       (lofl? ty)
        (lomkf g @ d
           [ty d (fs + [['mov 'r0 <r] ['mov 'r1 <>r] ['fix '(r0 r1) (lokc g) (cvtlld g (usg? vt) (ty = 'float))]
                        [(ty = 'float ? 'cvtsd2ss 'movapd) d 'f0]])])
       (ty = 'bool) (lotest g [vt r fs] @ [_ d f2] ['bool d f2])
       (lotr g ['ulong <r fs] ty))
   ; a low op and the high one its carry feeds. i386 keeps two addresses, its copies ahead of
   ; the flags: a zero one folds to lays an xor
   (lopcy g lo hi dl dh al ah bl bh)
    (? (w32s? g)                    ; no flags: the carry an unsigned compare, the borrow taken first
        (lomk g @ t (lomk g @ c
           (lo = 'adds ? [['add t al bl] ['cmp t al] ['set 'below c] ['add dh ah bh] ['add dh dh c] ['mov dl t]]
              [['cmp al bl] ['set 'below c] ['sub t al bl] ['sub dh ah bh] ['sub dh dh c] ['mov dl t]])))
       (v6m? g) [['mov 'r0 al] ['mov 'r1 ah] ['mov 'r2 bl] ['mov 'r3 bh] ['fix '(r0 r1 r2 r3) '(r0 r1) [[lo 'r0 'r0 'r2] [hi 'r1 'r1 'r3]]] ['mov dl 'r0] ['mov dh 'r1]]   ; a far reload's li sets flags
       (ia32? g) [['mov dh ah] ['mov dl al] [lo dl dl bl] [hi dh dh bh]]
       [[lo dl al bl] [hi dh ah bh]])
   ; a pair relation over flags -> [cc forms]. gt and le subtract the other way
   (lopcc g op u al ah bl bh)
    (lomk g @ t (lomk g @ k
       (? (w32s? g)                 ; the words' relations combined, then against zero, as lowrv
           (: c (lomk g) s (elem op '(lt le) ? 'lt 'gt)
              (elem op '(eq ne) ? [op [['mov t al] ['xor t t bl] ['mov k ah] ['xor k k bh] ['or t t k] ['cmp t 0]]]
                 ['ne [['cmp ah bh] ['set (scc s u) t] ['cmp ah bh] ['set 'eq k] ['cmp al bl] ['set (scc op 1) c]
                       ['and k k c] ['or t t k] ['cmp t 0]]]))
          (elem op '(eq ne)) [op [['mov t al] ['xor t t bl] ['mov k ah] ['xor k k bh] ['ors t t k]]]
          (elem op '(lt ge)) [(scc op u) (lopcy g 'subs 'sbcs t k al ah bl bh)]
          [(scc (op = 'gt ? 'lt 'ge) u) (lopcy g 'subs 'sbcs t k bl bh al ah)])))
   ; a pair by a literal count
   (lopshk g op rt fa al ah k)
    (lomk g @ l (lomk g @ h
       [rt [l h] (fa +
          (? (k < 1) [['mov l al] ['mov h ah]]
             (63 < k && op != 'sar) [['li l 0] ['li h 0]]
             (op = 'shl)
              (32 <= k ? ([['mov h al]] + (k = 32 ? () [['shl h (k - 32)]]) + [['li l 0]])
                 (lomk g @ c [['mov c al] ['shr c (32 - k)] ['mov h ah] ['shl h k] ['or h h c] ['mov l al] ['shl l k]]))
             (32 <= k)
              ([['mov l ah]] + (k = 32 ? () [[op l (min 31 (k - 32))]]) +
               (op = 'shr ? [['li h 0]] [['mov h ah] ['sar h 31]]))
             (lomk g @ c [['mov c ah] ['shl c (32 - k)] ['mov l al] ['shr l k] ['or l l c] ['mov h ah] [op h k]])))]))
   (lopsh g op a b kb)
    (: ta (vty a) kd (op = 'shl ? 'shl (usg? ta ? 'shr 'sar))
       (? !(pair? g ta) (lotr g b 'int @ b2 (lobin g op a b2 kb))
          (lop g a @ [fa al ah]
             (kb @ ([k] && 0 <= k) (lopshk g kd ta fa al ah k)
                   [_] 'bad
                   (lotr g b 'int @ [_ c fb] (lomk g @ l (lomk g @ h
                      [ta [l h] (fa + fb + [['mov 'r0 al] ['mov 'r1 ah] ['mov 'r2 c] ['fix '(r0 r1 r2) (lokc g) (pshiftv g kd)]
                                            ['mov l 'r0] ['mov h 'r1]])])))))))
   ; widened by its source's signedness: the high half's last form says
   (lozx? fs h) (rev fs @ (['li x 0] . _) (x = h) _ ())
   (losx? fs h) (rev fs @ (['sar x 31] . _) (x = h) _ ())
   (lopbin g op a b kb)
    (: ta (vty a) tb (vty b) rt (rbin g ta tb) u (cmpu g ta tb)
       (? (elem op '(shl shr)) (lopsh g op a b kb)
          (ptr? ta || ptr? tb) (lobin g op (ptr? ta ? a (lotr g a 'long)) (ptr? tb ? b (lotr g b 'long)) kb)
          !(losc? ta && losc? tb) (lono g ['bin op ta tb])
          (lop g a @ [fa al ah] (lop g b @ [fb bl bh]
             (: fs (fa + fb)
                (? (locmp? op)
                    (lopcc g op u al ah bl bh @ [cc ff] (lomk g @ d ['int d (fs + ff + [['set cc d]])]))
                   (lomk g @ l (lomk g @ h
                      (op @ '+ [rt [l h] (fs + lopcy g 'adds 'adc l h al ah bl bh)]
                            '- [rt [l h] (fs + lopcy g 'subs 'sbc l h al ah bl bh)]
                            '* (? (rv32? g)
                                   (lomk g @ t (lomk g @ k
                                      [rt [l h] (fs + [['imul t al bh] ['imul k ah bl] ['umulh h al bl] ['imul l al bl] ['add h h t] ['add h h k]])]))
                                  ; xtensa's muluh is the esp32's, past qemu's cores: the helper
                                  (v6m? g || xt? g)
                                   [rt [l h] (fs + [['mov 'r0 al] ['mov 'r1 ah] ['mov 'r2 bl] ['mov 'r3 bh] '(cuse r0 r1 r2 r3) '(call __aeabi_lmul) ['mov l 'r0] ['mov h 'r1]])]
                                  (ia32? g)
                                   ; the cross terms by imul, lo*lo by mul, the sum into hi
                                   [rt [l h] (fs + [['mov 'r2 al] ['mov 'r3 ah] ['mov 'r0 bl] ['mov 'r1 bh]
                                                    ['fix '(r0 r1 r2 r3) lokl ['(imul r3 r3 r0) '(imul r1 r1 r2) '(add r3 r3 r1)
                                                                               ['raw (m16b g + [247 226])] '(add r1 r2 r3)]]
                                                    ['mov l 'r0] ['mov h 'r1]])]
                                  (lozx? fa ah && lozx? fb bh) [rt [l h] (fs + [['umull l h al bl]])]
                                  (losx? fa ah && losx? fb bh) [rt [l h] (fs + [['smull l h al bl]])]
                                  (lomk g @ t (lomk g @ k
                                     [rt [l h] (fs + [['imul t al bh] ['imul k ah bl] ['umull l h al bl] ['add h h t] ['add h h k]])])))
                            ('& || '| || '^)
                             (irop op @ w [rt [l h] (fs + [['mov l al] [w l l bl] ['mov h ah] [w h h bh]])])
                            ('/ || '%)
                             (ia32? g
                              ? [rt [l h] (fs + [['sub 'sp 'sp 16] ['st 'sp 0 al] ['st 'sp 4 ah] ['st 'sp 8 bl] ['st 'sp 12 bh]
                                                 ['call (op = '/ ? (usg? rt ? '__udivdi3 '__divdi3) (usg? rt ? '__umoddi3 '__moddi3))]
                                                 ['add 'sp 'sp 16] ['mov l 'r0] ['mov h 'r2]])]
                              (rt = 'ullong && !(soft? g)
                              ? [rt [l h] (fs + [['mov 'r2 al] ['mov 'r3 ah] ['mov 'r0 bl] ['mov 'r1 bh]
                                                 ['fix '(r0 r1 r2 r3) (lokc g) [(op = '/ ? '(udivll) '(uremll))]]
                                                 ['mov l 'r0] ['mov h 'r1]])]
                                [rt [l h] (fs + [['mov 'r0 al] ['mov 'r1 ah] ['mov 'r2 bl] ['mov 'r3 bh] '(cuse r0 r1 r2 r3)
                                                 ['call (op = '/ ? (usg? rt ? '__udivdi3 '__divdi3) (usg? rt ? '__umoddi3 '__moddi3))] ['mov l 'r0] ['mov h 'r1]])]))
                            (lono g ['bin op]))))))))))
   ; -- the wide value: [ty parts fs], low part first, two registers or t32's four; a local in memory.
   ; the kit's ops work rax:rdx or r0-r3, each in a fix over the registers it reads and writes --
   ; holo lays the kit on x64, a64 and t32's four-word face; rv64 and wasm compose words
   (lo128? g) (x64? g || a64? g || t32w? g || rv64? g)
   (lohi g) (x64? g ? 'r2 'r1)
   (lokr g) (t32w? g ? '(r0 r1 r2 r3) '(r0 r2))
   (lowabi g) (t32w? g ? '(r0 r1 r2 r3) ['r0 (lohi g)])
   (lowd g) (t32w? g ? 4 8)
   (lomkw g) (map (_ \ lomk g) (lokr g))
   (lowin g ws) (map (k \ [(lokr g k) (ws k)]) ^#ws)
   (lowmv ds rs) (map (k \ ['mov (ds k) (rs k)]) ^#ds)
   ; a value as its parts -> [fs parts] | 'bad: a word or a 32-bit pair widens by its source's signedness
   (lopair g v)
    (v @ ([vt ws fs] && d128? vt) [fs ws]
         ([vt [l h] fs] && pair? g vt)
          (lomk g @ s [(fs + (usg? vt ? [['li s 0]] [['mov s h] ['sar s 31]])) [l h s s]])
         ([vt _ _] && losc? vt)
          (: u (usg? vt || ptr? vt)
             (lotr g v (u ? 'ulong 'long) @ [_ l fs]
                (lomk g @ h [(fs + (u ? [['li h 0]] [['mov h l] ['sar h (8 * wsize g - 1)]])) (t32w? g ? [l h h h] [l h])])))
         _ 'bad)
   ; ins [register vreg].. moved in, the kit's forms, the parts out of the kit's registers
   (lokit g ty pre ins uses defs body)
    (!(lo128? g) ? (lono g ['kit <body])
       (lomkw g @ ds
          [ty ds (pre + map (p \ ['mov <p <>p]) ins + [['fix uses defs body]] + lowmv ds (lokr g))]))
   ; to or from the wide value: a word widens, read as a word it is its low part, its truth any part
   (lowtr g v ty)
    (? (t32w? g && (lofl? (vty v) || lofl? ty)) (lono g ['cast (vty v) ty])
       (lofl? (vty v) && d128? ty) (lowfc g v ty "__fix\(usg? ty ? "uns" "")\(lofs (vty v))ti")
       (lofl? ty && d128? (vty v)) (lowfc g v ty "__float\(usg? (vty v) ? "un" "")ti\(lofs ty)")
       (d128? ty) (lopair g v @ 'bad (lono g ['cast (vty v) ty]) [fs ws] [ty ws fs])
       (v @ ([vt ws fs] && d128? vt && pair? g ty) [ty [(ws 0) (ws 1)] fs]
            ([vt ws fs] && d128? vt && losc? ty) (ty = 'bool ? (lotest g v @ [_ d f2] ['bool d f2]) (lotr g ['ulong <ws fs] ty))
            _ (lono g ['cast (vty v) ty])))
   ; a conversion or divide past the kit: the runtime's call, the name gcc's objects call too
   (lofs ty) (ty = 'float ? "sf" "df")
   (lowfc g v ty fn) (locall1 g () ty [(vty v)] () () [['lov v]] [['call (intern fn)]] ())
   (lowti g rt pre as bs fn)
    (locall1 g () rt [rt rt] () () [['lov [rt as ()]] ['lov [rt bs ()]]] [['call fn]] () @ [t d f] [t d (pre + f)] _ 'bad)
   ; -- rv64 and wasm's wide value: no kit and no flags, words and an unsigned compare's carry --
   (low3 o d a b) [['mov d a] [o d d b]]
   (lowrv g op rt u pre [al ah] [bl bh])
    (: l (lomk g) h (lomk g) c (lomk g) (cy x y) [['cmp x y] ['set (scc 'lt 1) c]]
       (op @ '+ [rt [l h] (pre + low3 'add l al bl + cy l bl + low3 'add h ah bh + [['add h h c]])]
             '- [rt [l h] (pre + cy al bl + low3 'sub l al bl + low3 'sub h ah bh + [['sub h h c]])]
             '* (lowmul g rt pre al ah bl bh)
             ('eq || 'ne) ['long c (pre + low3 'xor l al bl + low3 'xor h ah bh + [['or l l h] ['cmp l 0] ['set (scc op 1) c]])]
             (: s (elem op '(lt le) ? 'lt 'gt) x (lomk g)
                ['long x (pre + [['cmp ah bh] ['set (scc s u) l] ['cmp ah bh] ['set (scc 'eq 1) h]
                                 ['cmp al bl] ['set (scc op 1) c] ['and h h c] ['mov x l] ['or x x h]])])))
   ; the low words' high half by 32-bit pieces, then the cross terms
   (lowmul g rt pre al ah bl bh)
    (: k (lomk g) a0 (lomk g) a1 (lomk g) b0 (lomk g) b1 (lomk g) t (lomk g) w1 (lomk g) w2 (lomk g)
       u (lomk g) v (lomk g) h (lomk g) l (lomk g) x (lomk g)
       (hi d s) [['mov d s] ['shr d 32]]
       [rt [l h] (pre + [['li k 4294967295]] + low3 'and a0 al k + hi a1 al + low3 'and b0 bl k + hi b1 bl
                  + low3 'imul t a0 b0 + low3 'imul w1 a1 b0 + hi u t + [['add w1 w1 u]]
                  + low3 'imul w2 a0 b1 + low3 'and v w1 k + [['add w2 w2 v]]
                  + low3 'imul h a1 b1 + hi u w1 + [['add h h u]] + hi v w2 + [['add h h v]]
                  + low3 'imul x al bh + [['add h h x]] + low3 'imul x ah bl + [['add h h x]]
                  + low3 'imul l al bl)])
   ; a shift by a constant, 0 < k < 128; by a register, the hardware taking its count mod 64
   (lowks g ty pre [al ah] o k)
    (: l (lomk g) h (lomk g) t (lomk g) (sh d x p n) [['mov d x] [p d n]]
       [ty [l h] (pre + (? (o = 'shl)
                           (k < 64 ? (sh l al 'shl k + sh h ah 'shl k + sh t al 'shr (64 - k) + [['or h h t]])
                                     ([['li l 0]] + sh h al 'shl (k - 64)))
                           (k < 64 ? (sh h ah o k + sh l al 'shr k + sh t ah 'shl (64 - k) + [['or l l t]])
                                     (sh l ah o (k - 64) + (o = 'shr ? [['li h 0]] (sh h ah 'sar 63))))))])
   (lowvs g ty pre [al ah] o c)
    (: l (lomk g) h (lomk g) t (lomk g) k (lomk g) m (lomk g) n (lomk g) x (lomk g) y (lomk g) z (lomk g) f (lomk g) p (lomk g)
       (vs d s q w) [['mov d s] ['mov 'r1 w] [q d 'r1]]
       ; m all ones from 64 up, n its opposite, t 63 less the count
       ms [['mov t c] ['shr t 6] ['li k 1] ['and t t k] ['li m 0] ['sub m m t] ['mov n m] ['not n] ['mov t c] ['li k 63] ['xor t t k]]
       [ty [l h] (pre + ms +
          (? (o = 'shl)
             (vs x al 'shlv c + vs y ah 'shlv c + [['mov z al] ['shr z 1]] + vs z z 'shrv t + [['or y y z]]
              + low3 'and l x n + low3 'and h y n + low3 'and p x m + [['or h h p]])
             (vs x ah (o = 'shr ? 'shrv 'sarv) c + vs y al 'shrv c + [['mov z ah] ['shl z 1]] + vs z z 'shlv t + [['or y y z]]
              + (o = 'shr ? [['li f 0]] [['mov f ah] ['sar f 63]])
              + low3 'and l y n + low3 'and p x m + [['or l l p]] + low3 'and h x n + low3 'and p f m + [['or h h p]])))])
   ; a divisor whose high half is zero: an unsigned word, a literal no less than 0, or a value widened so
   (lohz? v) (v @ ([vt _ fs] && !(d128? vt)) (usg? vt || ptr? vt || (fs @ [['li _ k]] (0 <= k) _ ()))
                  ([vt ws fs] && d128? vt) (all (x \ elem ['li x 0] fs) (#ws = 4 ? [(ws 2) (ws 3)] [(ws 1)]))
                  _ ())
   ; t32: the left in a 16-byte cell at sp, the right on r0-r3
   (lowcell g as bs) ([['sub 'sp 'sp 16]] + map (k \ ['st 'sp (4 * k) (as k)]) ^4 + lowmv (lokr g) bs)
   (lowfx g rt pre as bs body)
    (lomkw g @ ds [rt ds (pre + lowcell g as bs + [['fix (lokr g) (lokr g) body] '(add sp sp 16)] + lowmv ds (lokr g))])
   ; ..or rt.c's call, its answer back in the cell
   (lowrt g rt pre as bs fn)
    (lomkw g @ ds [rt ds (pre + lowcell g as bs + [('(cuse) + lokr g) ['call fn]]
                          + map (k \ ['ld (ds k) 'sp (4 * k)]) ^4 + ['(add sp sp 16)])])
   ; a shift by a register: rcx on x64, r12 on t32, its first part if it has parts
   (lovsh g ty pre ws c v9)
    (t32w? g ? (lokit g ty pre (lowin g ws + [['r5 c]]) '(r0 r1 r2 r3 r5) (lokr g) [['mov 'r12 'r5] [v9]])
       (lokit g ty pre (lowin g ws + [['r1 c]]) '(r0 r1 r2) (lokr g) [[v9]]))
   (lowbin g op a b kb)
    (: ta (vty a) tb (vty b) rt (wbin ta tb) u (rt = 'u128)
       (? (lofl? ta || lofl? tb) (lono g ['bin op ta tb])
          (elem op '(shl shr))
           (lopair g a @ 'bad 'bad
              [fa ws] (: o9 (? (op = 'shl) 'shl (usg? ta) 'shr 'sar)
                          k9 (? (op = 'shl) 'shl128 (usg? ta) 'shr128 'sar128)
                          v9 (? (op = 'shl) 'shl128v (usg? ta) 'shr128v 'sar128v)
                          (? !(d128? ta) (lono g ['bin op ta tb])
                             (two? kb) (? (<kb < 0 || 127 < <kb) (lono g ['shift <kb])
                                          (<kb = 0) [ta ws fa]
                                          (rv64? g) (lowks g ta fa ws o9 <kb)
                                          (lokit g ta fa (lowin g ws) (lokr g) (lokr g) [[k9 <kb]]))
                             (b @ ([_ (c . _) fb] && (d128? tb || pair? g tb)) (rv64? g ? (lowvs g ta (fa + fb) ws o9 c) (lovsh g ta (fa + fb) ws c v9))
                                  ([_ c fb] && losc? tb) (rv64? g ? (lowvs g ta (fa + fb) ws o9 c) (lovsh g ta (fa + fb) ws c v9))
                                  _ (lono g ['bin op ta tb])))))
          (lopair g a @ 'bad 'bad
             [fa as] (lopair g b @ 'bad 'bad
                [fb bs]
                 (: pre (fa + fb) lr [['r6 <as] ['r5 <>as] ['r0 <bs] ['r2 <>bs]] t4 (t32w? g)
                    (? (rv64? g && !(elem op '(& | ^ / %))) (lowrv g op rt u pre as bs)
                    (op @ '+ (t4 ? (lowfx g rt pre as bs '((a128 sp)))
                                (lokit g rt pre lr '(r0 r2 r5 r6) '(r0 r2) '((a128r r6 r5))))
                          ; s128r answers (r6:r5) - (rax:rdx), its operand pair spent
                          '- (t4 ? (lowfx g rt pre as bs '((s128 sp)))
                                (lokit g rt pre lr '(r0 r2 r5 r6) '(r0 r2 r5 r6) '((s128r r6 r5))))
                          '* (? t4 (lowrt g rt pre as bs '__moon_m128)
                                (lohz? a && lohz? b) (lokit g rt pre [['r0 <bs] ['r5 <as]] '(r0 r5) '(r0 r2) '((mw128r r5)))
                                (lokit g rt pre lr '(r0 r2 r5 r6) '(r0 r1 r2) '((m128r r6 r5))))
                          ('& || '| || '^)
                           (lomkw g @ ds
                              [rt ds (pre + catmap (k \ [['mov (ds k) (as k)] [(irop op) (ds k) (ds k) (bs k)]]) ^#ds)])
                          ; 0/1 of (r6:r5) cond (rax:rdx)
                          ('eq || 'ne || 'lt || 'le || 'gt || 'ge)
                           (? !(lo128? g) (lono g ['kit 'c128r])
                              t4 (lomk g @ d ['long d (pre + lowcell g as bs
                                                       + [['fix (lokr g) (lokr g) [['c128 (scc op u) 'sp]]] '(add sp sp 16) ['mov d 'r0]])])
                              (lomk g @ d ['long d (pre + map (p \ ['mov <p <>p]) lr +
                                                    [['fix '(r0 r2 r5 r6) '(r0 r1 r2) [['c128r (scc op u) 'r6 'r5]]] ['mov d 'r0]])]))
                          ; u128 by a divisor whose high half is zero: the dividend in a cell at sp
                          ('/ || '%)
                           (? (t4 && !(u && lohz? b))
                               (lowrt g rt pre as bs (op @ '/ (u ? '__moon_ud128 '__moon_sd128) (u ? '__moon_um128 '__moon_sm128)))
                              (rv64? g || !(u && lohz? b))
                               (lowti g rt pre as bs (op @ '/ (u ? '__udivti3 '__divti3) (u ? '__umodti3 '__modti3)))
                              t4 (lowrt g rt pre as bs (op @ '/ '__moon_dv128 '__moon_rm128))
                              (lokit g rt pre [['r6 <as] ['r5 <>as] ['r0 <bs]] '(r0 r5 r6) '(r0 r1 r2)
                                 [['sub 'sp 'sp 16] ['st 'sp 0 'r6] ['st 'sp 8 'r5] [(op @ '/ 'dv128 'rm128) 'sp] ['add 'sp 'sp 16]]))
                          (lono g ['bin op ta tb]))))))))
   ; -- C99 complex: a two-part struct, a value its address; arithmetic over the parts in vregs --
   (locxsame? a b) (gcplx? a && gcplx? b && <>a = <>b)
   (lofo n p) (name "\(n)\(p = 'float ? "ss" "sd")")
   ; a complex or real value's parts in precision p, a real's im zero -> [fs re im] | 'bad
   (loparts g v p)
    (v @ ([vt r fs] && gcplx? vt)
          (: b (cxb vt) w (tsz g b) re (lomkf g) im (lomkf g)
             (ld x o) [(b = 'float ? 'ldss 'ldsd) x r o]
             (cv x) (b = p ? () [[(p = 'double ? 'cvtss2sd 'cvtsd2ss) x x]])
             [(fs + [(ld re 0)] + cv re + [(ld im w)] + cv im) re im])
         ([vt _ _] && losv? vt)
          (lotr g v p @ [_ re f2] (lomk g @ t (lomkf g @ im [(f2 + [['li t 0] (? (p = 'float) ['movdxr im t] (ilp32? g) ['movqrr im t t] ['movqxr im t])]) re im])))
         _ 'bad)
   ; parts in precision p into a fresh temp of complex type rt; its address answers
   (lopack g rt p [fs re im])
    (: b (cxb rt) w (tsz g b) o (ntmp g rt)
       (put x k) ((b = p ? [] [[(b = 'double ? 'cvtss2sd 'cvtsd2ss) x x]]) + [[(b = 'float ? 'stss 'stsd) 'r4 (o + k) x]])
       (lomk g @ t (loesc g 'r4, [rt t (fs + put re 0 + put im w + [['lea t 'r4 o]])])))
   ; to or from a complex: a width flip per part, a real's im zero, a complex read as a real its re
   (locvt g v ty)
    (? (gcplx? ty) (loparts g v (cxb ty) @ 'bad 'bad ps (lopack g ty (cxb ty) ps))
       (: p (ty = 'float ? 'float 'double)
          (loparts g v p @ 'bad 'bad [fs re _] (lotr g [p re fs] ty))))
   ; + - * / of a complex left (the parser lifts a real one): a float complex over a float complex,
   ; or / by a real no double, rounds in singles; the rest in doubles, a float answer only of two floats
   (locxbin g op a b)
    (: ta (vty a) tb (vty b)
       fa (gcplx? ta && cxb ta = 'float) fb (gcplx? tb && cxb tb = 'float)
       rt (fa && fb ? '(struct "__cplx_float") '(struct "__cplx_double"))
       (? (!(gcplx? ta) || !(elem op '(+ - * /))) (lono g ['bin op ta tb])
          (fa && op = '/ && !(gcplx? tb) && tb != 'double) (locxdivr g a b 'float ta)
          (fa && fb && op != '/) (locxar g op a b 'float ta)
          (op = '/ && !(gcplx? tb)) (locxdivr g a b 'double rt)
          (locxar g op a b 'double rt)))
   ; a real divisor divides each part
   (locxdivr g a b p rt)
    (loparts g a p @ 'bad 'bad
       [fa x y] (lotr g b p @ [_ c fc]
                   (lomkf g @ re (lomkf g @ im
                      (lopack g rt p [(fa + fc + [['movapd re x] [(lofo "div" p) re c] ['movapd im y] [(lofo "div" p) im c]]) re im])))))
   ; (x + yi) op (c + di) over the parts
   (locxar g op a b p rt)
    (loparts g a p @ 'bad 'bad
       [fa x y] (loparts g b p @ 'bad 'bad
                   [fb c d] (lomkf g @ re (lomkf g @ im (lomkf g @ s (lomkf g @ u
                      (: (o n z w) [(lofo n p) z w] (mv z w) ['movapd z w]
                         ops (op @ '+ [(mv re x) (o "add" re c) (mv im y) (o "add" im d)]
                                   '- [(mv re x) (o "sub" re c) (mv im y) (o "sub" im d)]
                                   ; re = xc - yd, im = yc + xd
                                   '* [(mv re x) (o "mul" re c) (mv s y) (o "mul" s d) (o "sub" re s)
                                       (mv s x) (o "mul" s d) (mv im y) (o "mul" im c) (o "add" im s)]
                                   ; den = c^2 + d^2, re = (xc + yd) / den, im = (yc - xd) / den
                                   [(mv s c) (o "mul" s c) (mv u d) (o "mul" u d) (o "add" s u)
                                    (mv re x) (o "mul" re c) (mv u y) (o "mul" u d) (o "add" re u) (o "div" re s)
                                    (mv im y) (o "mul" im c) (mv u x) (o "mul" u d) (o "sub" im u) (o "div" im s)])
                         (lopack g rt p [(fa + fb + ops) re im]))))))))
   ; -z: each part's sign bit flips, a nan's too
   (locxneg g v)
    (: p (cxb (vty v))
       (loparts g v p @ 'bad 'bad
          [fs x y] (lomkf g @ re (lomkf g @ im
                      (lopack g (vty v) p [(fs + lofneg g p re x + lofneg g p im y) re im])))))
   ; a float's sign flipped through the general registers, a 32-bit double's in its high word
   (lofneg g ty d r)
    (lomk g @ t (lomk g @ k
       (? (ty = 'float || !(ilp32? g))
          (: s (ty = 'float) [[(s ? 'movdrx 'movqrx) t r] ['li k (s ? 2147483648 -9223372036854775808)] ['xor t t k]
                              [(s ? 'movdxr 'movqxr) d t]])
          (lomk g @ h [['movrrq t h r] ['li k 2147483648] ['xor h h k] ['movqrr d t h]]))))
   ; an integer literal a double holds exactly converts now
   (lokfl? vt r fs)
    (fs @ [['li d n]] (d = r && cint? n && -9007199254740992 <= n <= 9007199254740992 && !(usg? vt && n < 0)) _ ())
   ; a conversion through the float file: the 64-bit forms, ulong by a kit
   (lotrf g [vt r fs] ty)
    (? (vt = ty) [ty r fs]
       (lofl? vt && lofl? ty) (lomkf g @ t [ty t (fs + [[(ty = 'float ? 'cvtsd2ss 'cvtss2sd) t r]])])
       (lofl? ty && ilp32? g && (usg? vt || ptr? vt)) (lomkf g @ t [ty t (fs + [[(ty = 'float ? 'cvtui2ss 'cvtui2sd) t r]])])
       (ilp32? g && lofl? vt && usg? ty && 4 = tsz g ty) (lomk g @ t [ty t (fs + [[(vt = 'float ? 'cvttss2ui 'cvttsd2ui) t r]])])
       ; a float rounds once: a top bit set halves with the lost bit stuck on, and doubles back
       (ty = 'float && elem vt '(ulong ullong))
        (: d (lomkf g) t (lomk g) k (lomk g) ln (nlab g ".uf") le (nlab g ".ufe")
           ['float d (fs + [['cmp r 0] ['br 'lt ln] ['cvtsi2ss d r] ['jmp le] ['label ln]
                            ['li k 1] ['and k k r] ['mov t r] ['shr t 1] ['or t t k] ['cvtsi2ss d t] ['addss d d] ['label le]])])
       (lofl? ty && elem vt '(ulong ullong))
        (loren2 g [['r0 r]] 'f0 'double ul2d @ [_ d f2] (lotrf g ['double d (fs + f2)] ty))
       (lofl? ty && lokfl? vt r fs) (lox g () (: v ['flo (0.0 + (<fs 2))] (ty = 'float ? ['cast 'float v] v)))
       (lofl? ty) (lomkf g @ t [ty t (fs + [[(ty = 'float ? 'cvtsi2ss 'cvtsi2sd) t r]])])
       (ty = 'bool) (lotest g [vt r fs] @ [_ d f2] ['bool d f2])
       (elem ty '(ulong ullong))
        (lotrf g [vt r fs] 'double @ [_ d f1] (loren2 g [['f0 d]] 'r0 ty (dtoul g) @ [_ x f2] [ty x (f1 + f2)]))
       (lomk g @ t [ty t (fs + [[(vt = 'float ? 'cvttss2si 'cvttsd2si) t r]] + cvt ty t)]))
   ; a scalar's truth as an int 0/1: a float against 0.0, a NaN true
   (lotest g [vt r fs])
    (? (d128? vt || pair? g vt) (lomk g @ d ['int d (fs + [['mov d <r]] + map (x \ ['or d d x]) >r + [['cmp d 0] ['set 'ne d]])])
       (lofl? vt)
        (: t (lomk g) z (lomkf g) a (lomk g) b (lomk g) d (lomk g)
           ['int d (fs + lofz g z vt + [[(vt = 'float ? 'ucomiss 'ucomisd) r z]
                          ['set 'ne a] ['set 'p b] ['mov d a] ['or d d b]])])
       (lomk g @ d ['int d (fs + [['cmp r 0] ['set 'ne d]])]))
   ; a copy, so the caller may write it in place
   (locp g [vt r fs]) (lomkv g vt @ t [vt t (fs + lomvs t r)])
   ; a 32-bit unsigned meeting a signed operand: the signed side's pattern zero-extends
   (loz g v other)
    (u32bin? g (vty v) (vty other) && !(usg? (vty v)) && !(ptr? (vty v)) ?
       (locp g v @ [vt t fs] [vt t (fs + [['zx4 t]])]) v)

   ; the names whose address the body takes live in memory, and every name under a call that
   ; returns twice: its second return restores no register
   (lotk? g nm) (g 'twice || elem nm (g 'lotk))
   ; ..and a volatile one, its entry's mask in the seventh slot: every access a load or a store
   (lovq? e) (charm? (e 6) && e 6 & 2 > 0)
   (lotaken x acc)
    (x @ ['addr ['var n]] (elem n acc ? acc (n . acc))
         ['decl es] (foldl (a \ e \ (lovq? e && nelem <e a ? (<e . a) a)) (foldl (a \ y \ lotaken y a) acc x) es)
         ; an asm's memory operand takes its name's address
         ('asm . _ . os . is . _)
          (foldl (a \ o \ (o @ (c . ['var n] . _) (any (k \ elem (c k) '(109 111 81)) ^#c && nelem n a ? (n . a) a) _ a))
                 (foldl (a \ y \ lotaken y a) acc x) (os + is))
         (_ . _) (foldl (a \ y \ lotaken y a) acc x)
         acc)

   ; -- the environment: (name 'v vreg ty) | (name 'm off ty), and ('brk L) ('cont L) ('sw tab ty) --
   (lovar g env nm)
    (assoc nm env @ (_ . en) en
       ; a global register variable is its register
       (g 'gregs nm @ (s . y . _) (gas-regname (gtgt g) s @ r (nom? r ? ['v r y] 'bad))
          _ (g 'glob nm @ (a . b . _) ['g a b] 'bad)))
   (lolv g env e)
    (e @ ['var nm]
          (lovar g env nm @ ['v r ty] ['v r ty]
                            ['m off ty] ['a ['long 'r4 ()] ty off]
                            ; a VLA: its block's address in a cell
                            ['p po ty] (lomk g @ t ['a ['long t [['ld t 'r4 po]]] ty 0])
                            ['g lbl ty] (lomk g @ t ['a ['long t [['la t lbl]]] ty 0])
                            (lono g ['var nm]))
         ['deref p]
          ; a pointer's third slot, where it is not 0, the alignment its pointee's address carries
          (lox g env p @ [('ptr . pt . s) r fs] (two? s && 0 < <s ? (loal g [['ptr pt] r fs] pt 0 <s) ['a [['ptr pt] r fs] pt 0])
                       'bad 'bad (_ _ _) (lono g 'deref))
         ['dot base fld]
          (lolv g env base @ ['a av ty off]
                              (fmem g ty fld @ 'bad (lono g ['member fld])
                                               ([o bt] && bitf? bt) ['b av bt (off + o) (lobfa g bt (loma g ty o))]
                                               [o mt] (loal g av mt (off + o) (loma g ty o)))
                             'bad 'bad
                             _ (lono g 'dotbase))
         ; a compound literal: a temp filled as a local would be, an lvalue in the frame
         ['clit ty ini]
          ; a complex one is a scalar's: one value converted, or its two parts
          (? (gcplx? ty && (ini @ ['init [_ _]] 1 _ ()))
              (map elval <>ini @ [x y] (cxb ty @ b
                 (lox g env x @ 'bad 'bad
                    vx (lox g env y @ 'bad 'bad
                          vy (lotr g vx b @ [_ re fx] (lotr g vy b @ [_ im fy]
                                (lopack g ty b [(fx + fy) re im] @ [_ t fs] ['a ['long t fs] ty 0])))))))
             (gcplx? ty && (ini @ ['init (_ . _ . _)] 1 _ ())) (lono g 'complex)
             (ntmp g ty @ off
                (aggish? ty && !(gcplx? ty) ?
                   (lofill g env off ty ini @ 'bad 'bad fs ['a ['long 'r4 (lozfill g off (aup (tsz g ty) 8) fs)] ty off])
                   (lox g env (ini @ ['init (x . _)] x ['init ()] ['num 0] _ ini) @ 'bad 'bad
                      v (lost g ['a ['long 'r4 ()] ty off] v @ [fs _] ['a ['long 'r4 fs] ty off] 'bad)))))
         ; a struct rvalue (a call's, a cond's): its address
         (lox g env e @ ([ty r fs] && stru? ty) ['a [ty r fs] ty 0] 'bad 'bad _ (lono g ['lval <e])))
   ; the type of e without its forms (arrays undecayed), every accumulator handed back: peekty over a lo env
   (lopeek g env e)
    (: o0 (peep g 'off 0) sl0 (g 'slots) s0 (g 'strs) fe0 (g 'fesc) w0 (g 'lowhy)
       ty (lolv g env e @ (('v || 'a || 'b || 'u) . _ . ty . _) ty _ (lox g env e @ [t _ _] t _ 'bad))
       (pins g 'off o0 'slots sl0 'strs s0 'fesc fe0 'lowhy w0, ty))
   ; a register variable named as an asm operand: its register | ()
   (lovpin g env e) (e @ ['var nm] (lovar g env nm @ ['v r _] (g 'lopins r) _ ()) _ ())
   ; a refusal, its first cause kept for lorefuse
   (lono g why) (g 'lowhy @ () (pin g 'lowhy why, 'bad) _ 'bad)
   (lowno g nm w) (nolane g "no lane for \(nm) on a \(show w)-byte object\(ontgt g)")
   (loarity g who n va m)
    (pin g 'arity "\(who) wants \(show n)\(va ? " or more" "")\(n = 1 ? " argument" " arguments"), given \(show m)", lono g 'arity)
   ; what a refusal says, unless its arm named it already
   (lorefuse g)
    (g 'nolane ? 'bad
       (g 'lowhy @ ['var nm] (pin g 'undecl nm, 'bad)
                   why (nolane g "no lane for \(lowant g why)\(ontgt g)")))
   (lowant g why)
    (why @ ('fn . _) (g 'abad ? "alloca where an operand is parked on the stack" "this function's signature")
           'complex "C99 complex arithmetic"
           'vla "this variable-length array"
           'igoto "a computed goto"
           'msabi "an ms_abi call with a float or struct in its signature"
           ('abi || ('abi _)) "this signature's wide values"
           ['arg t] "passing this \(tsz g t)-byte struct by value"
           ['ret t] "returning this \(tsz g t)-byte struct by value"
           (('vaarg . _) || 'vaarg) "this va_arg"
           ['atomic _] "this atomic operation"
           (('wide _) || ('cast 'u128 _)) "__int128 here"
           _ (show why))
   ; a frame address become a value: no sibling call may jump past it
   ; a frame address become a value: sibcalls stop, a musttail still jumps
   (loesc g r) (r @ 'r4 (pin g 'fescv 1) 0)
   ; a scalar load from an address
   (loload g [_ r fs] ty off)
    (? (pair? g ty) (lomk g @ l (lomk g @ h [ty [l h] (fs + [['ld l r off] ['ld h r (off + 4)]])]))
       (losc? ty) (lomk g @ t [ty t (fs + [[(ldop ty) t r off]])])
       (lofl? ty) (lomkf g @ t [ty t (fs + [[(ty = 'float ? 'ldss 'ldsd) t r off]])])
       (d128? ty) (lomkw g @ ws [ty ws (fs + map (k \ ['ld (ws k) r (off + k * lowd g)]) ^#ws)])
       (lono g ['load ty]))
   ; an lvalue's value: an array decays, an aggregate refuses
   (lorv g lv)
    (lv @ ['v r ty] [ty r ()]
          ['a [_ r fs] (('arr || 'varr) . et . _) off] (lomk g @ t (loesc g r, [['ptr et] t (fs + [['lea t r off]])]))
          (['a [_ r fs] ty off] && stru? ty) (lomk g @ t (loesc g r, [ty t (fs + [['lea t r off]])]))
          ; a function designator decays to its address
          ['a [_ r fs] ('fn . ft) off] (lomk g @ t (loesc g r, [['ptr ('fn . ft)] t (fs + [['lea t r off]])]))
          ['a av ty off] (loload g av ty off)
          ['u [_ r fs] (('arr || 'varr) . et . _) off a] (lomk g @ t (loesc g r, [['ptr et a] t (fs + [['lea t r off]])]))
          ['u av ty off a] (loldu g av ty off a)
          ; a field past eight bytes: a word's bits and the ninth byte's
          (['b [_ r fs] bt off a] && 8 < tsz g bt)
           (lobf9 bt @ [fl fh nl]
              (lorv g ['b ['long r ()] fl off a] @ l
                 (lotr g (lorv g ['b ['long r ()] fh (off + 8) a]) 'ullong @ h
                    (lobf9v g bt (lobin g '| l (lobfk g 'shl h nl) ()) @ [t d f2] [t d (fs + f2)]))))
          ; a bitfield: its unit, then two shifts (sar signed, shr unsigned; a bool never sign-extends)
          (['b [_ r fs] bt off a] && wsize g < tsz g bt)
           (: w (bt 3)
              (lobfwld g bt r off @ [ul uh fu]
                 (lopshk g 'shl 'ullong (fs + fu) ul uh (64 - (bt 2 + w)) @ [_ [sl sh] f2]
                    (lopshk g (usg? <>bt ? 'shr 'sar) 'ullong f2 sl sh (64 - w) @ [_ [l h] f3]
                       (lobfwv g bt l h f3)))))
          ['b [_ r fs] bt off a]
           (: uty <>bt bitoff <>>bt width <>>>bt hi (8 * wsize g - (bitoff + width)) lo (8 * wsize g - width)
              (lobfld g bt r off a @ [_ t f2]
                 [(pprom bt) t (fs + f2 + (0 < hi ? [['shl t hi]]) + (0 < lo ? [[(usg? uty || uty = 'bool ? 'shr 'sar) t lo]]))]))
          'bad)
   ; a bitfield's unit at b+off into a fresh vreg, and back: one access as its type says, or the
   ; chunks when packed, their scratch renamed
   (lobfld g bt b off a)
    (bfpk? bt || a ? (loga g b off (tsz g bt) (lobfal g a))
       (lomk g @ t ['long t [[(uldop (tsz g bt)) t b off]]]))
   (lobfst g bt b off u a)
    (bfpk? bt || a ? (lostu g b off (tsz g bt) (lobfal g a) u)
       [[(stop <>bt) b off u]])
   ; what a packed unit's chunks may assume: v6-M takes no word off its alignment
   (lobfal g a) (a ? a (v6m? g ? 1 8))
   ; a unit past the word, as two: 8 bytes as its type says, or a packed one's chunks
   (lobfwld g bt b off)
    (bfpk? bt
     ? (loga g b off 4 (lobfal g ()) @ [_ l fl] (loga g b (off + 4) (tsz g bt - 4) (lobfal g ()) @ [_ h fh] [l h (fl + fh)]))
     (lomk g @ l (lomk g @ h [l h [['ld l b off] ['ld h b (off + 4)]]])))
   (lobfwst g bt b off l h)
    (bfpk? bt ? (lostu g b off 4 (lobfal g ()) l + lostu g b (off + 4) (tsz g bt - 4) (lobfal g ()) h)
       [['st b off l] ['st b (off + 4) h]])
   ; a field over nine bytes, as the field in the first eight, the one in the last, and the first's width
   (lobf9 bt) (64 - bt 2 @ nl [['bitfield 'ullong (bt 2) nl 8] ['bitfield 'ullong 0 (bt 3 - nl) 1] nl])
   ; a shift by a constant, and those bits as the field's value
   (lobfk g op v k) (lomk g @ t (lobin g op v ['int t [['li t k]]] [k]))
   (lobf9v g bt u)
    (: sh (64 - bt 3) (lotr g (sh = 0 ? u (lobfk g 'shr (lotr g (lobfk g 'shl u sh) (usg? <>bt ? 'ullong 'llong)) sh)) (pprom bt)))
   ; a field's two words as the value it promotes to
   (lobfwv g bt l h fs) (pprom bt @ t (pair? g t ? [t [l h] fs] [t l fs]))
   ; -- -mstrict-align: no access wider than the alignment its address carries --
   ; what a member at o keeps of its struct's alignment
   (loma g ty o) (lowb o @ 0 (tal g ty) lb (min (tal g ty) lb))
   ; an lvalue at an a-aligned address: a struct short of it keeps a on its type, the rest ride 'u
   (loal g av ty off a)
    (? !(sal? g && a < salk g (stru? ty || arr? ty ? (tal g ty) (tsz g ty))) ['a av ty off]
       (stru? ty) ['a av [<ty <>ty a] off]
       ['u av ty off a])
   ; ..a bitfield's unit its alignment where that falls short, else ()
   (lobfa g bt a) (sal? g && a < salk g (tsz g bt) ? a)
   ; ..an initializer's slot in the frame, its offset all it knows
   (loelv g ty off) (loal g ['long 'r4 ()] ty off (lowb off @ 0 16 b b))
   ; n bytes at b+off by the chunks a carries, and back
   (loga g b off n a) (loren2 g () 'r2 'long (ldal 'r2 b off n a))
   (lostu g b off n a v) (loren2 g () 'r3 'long (stal b off n a v) @ [_ _ fs] fs)
   ; ..a float on v6-M, whose float file is soft: its bits by words through a frame temp
   (lofws g ty) (filter (p \ p % 4 = 0) ^(tsz g ty))
   (loldu g [_ r fs] ty off a)
    (? (lofl? ty && soft? g)
        (ntmp g ty @ tm
           (foldl (acc \ p \ (loga g r (off + p) 4 a @ [_ t f2] (acc + f2 + [['st 'r4 (tm + p) t]]))) () (lofws g ty) @ f3
              (lomkf g @ w [ty w (fs + f3 + [[(ty = 'float ? 'ldss 'ldsd) w 'r4 tm]])])))
       (d128? ty) (loga g r off 8 a @ [_ l fl] (loga g r (off + 8) 8 a @ [_ h fh] [ty [l h] (fs + fl + fh)]))
       (pair? g ty) (loga g r off 4 a @ [_ l fl] (loga g r (off + 4) 4 a @ [_ h fh] [ty [l h] (fs + fl + fh)]))
       (lofl? ty) (loga g r off (tsz g ty) a @ [_ t f2] (lomkf g @ w [ty w (fs + f2 + [[(ty = 'float ? 'movdxr 'movqxr) w t]])]))
       (loga g r off (tsz g ty) a @ [_ t f2] [ty t (fs + f2 + cvt ty t)]))
   ; a store of v (converted) to an lvalue -> [forms value] | 'bad
   (lost g lv v)
    (lv @ ['v r ty] (lotr g v ty @ [_ c fs] [(fs + lomvs r c) [ty r ()]])
          (['a [_ b _] ty off] && losc? ty && !(pair? g ty)) (lotr g v ty @ [_ c fs] [(fs + [[(stop ty) b off c]]) [ty c ()]])
          (['a [_ b _] ty off] && lofl? ty) (lotr g v ty @ [_ c fs] [(fs + [[(ty = 'float ? 'stss 'stsd) b off c]]) [ty c ()]])
          ; a bitfield: read-modify-write its unit, the truncated value answers
          ['u [_ b _] ty off a]
           (lotr g v ty @
              [_ c fs] (? (d128? ty) [(fs + lostu g b off 8 a <c + lostu g b (off + 8) 8 a <>c) [ty c ()]]
                          (pair? g ty) [(fs + lostu g b off 4 a <c + lostu g b (off + 4) 4 a <>c) [ty c ()]]
                          (lofl? ty && soft? g)
                           (ntmp g ty @ tm [(fs + [[(ty = 'float ? 'stss 'stsd) 'r4 tm c]]
                                             + catmap (p \ (lomk g @ t ([['ld t 'r4 (tm + p)]] + lostu g b (off + p) 4 a t))) (lofws g ty)) [ty c ()]])
                          (lofl? ty) (lomk g @ t [(fs + [[(ty = 'float ? 'movdrx 'movqrx) t c]] + lostu g b off (tsz g ty) a t) [ty c ()]])
                          [(fs + lostu g b off (tsz g ty) a c) [ty c ()]])
              _ 'bad)
          (['b [_ b _] bt off a] && 8 < tsz g bt)
           (lobf9 bt @ [fl fh nl]
              (lotr g v 'ullong @ u
                 (['ullong (vreg u) ()] @ c
                    (lost g ['b ['long b ()] fl off a] c @ [f1 _]
                       (lost g ['b ['long b ()] fh (off + 8) a] (lobfk g 'shr c nl) @ [f2 _]
                          (lobf9v g bt c @ [t d f3] [(vfs u + f1 + f2 + f3) [t d ()]]))))))
          (['b [_ b _] bt off a] && wsize g < tsz g bt)
           (: w (bt 3) wm ((1 << w) - 1) fm (wm << bt 2) (lo32 x) (x % 4294967296) (hi32 x) (x // 4294967296)
              (lotr g v 'ullong @ [_ [cl ch] fs]
                 (lomk g @ k (lomk g @ ml (lomk g @ mh
                    (lopshk g 'shl 'ullong () ml mh (bt 2) @ [_ [sl sh] f2]
                       (lobfwld g bt b off @ [ul uh fu]
                          ((usg? <>bt ? (lopshk g 'shr 'ullong () ml mh 0) (lopshk g 'shl 'ullong () ml mh (64 - w) @ [_ [tl th] f3] (lopshk g 'sar 'ullong f3 tl th (64 - w)))) @ [_ [al ah] f4]
                             [(fs + [['mov ml cl] ['li k (lo32 wm)] ['and ml ml k] ['mov mh ch] ['li k (hi32 wm)] ['and mh mh k]] + f2 + fu +
                               [['li k (4294967295 - lo32 fm)] ['and ul ul k] ['li k (4294967295 - hi32 fm)] ['and uh uh k]
                                ['or ul ul sl] ['or uh uh sh]] + lobfwst g bt b off ul uh + f4)
                              (lobfwv g bt al ah ())]))))))))
          ['b [_ b _] bt off a]
           (: uty <>bt bitoff <>>bt width <>>>bt mask ((1 << width) - 1) cmask (0 - (mask << bitoff) - 1)
              (lotr g v (pair? g uty ? 'ulong uty) @ [_ c fs]
                 (: k (lomk g) m (lomk g) u (lomk g) x (lomk g)
                    (lobfld g bt b off a @ [_ u fu]
                       [(fs + [['mov m c] ['li k (cfit g 'long mask)] ['and m m k]] + fu + [['li k (cfit g 'long cmask)] ['and u u k]
                               ['mov x m]] + (0 < bitoff ? [['shl x bitoff]]) + [['or u u x]] + lobfst g bt b off u a +
                         ; the field's value, a signed one's top bit its sign
                         (usg? uty || uty = 'bool || 8 * wsize g <= width ? () [['shl m (8 * wsize g - width)] ['sar m (8 * wsize g - width)]]))
                        [(pprom bt) m ()]]))))
          (['a [_ b _] ty off] && (d128? ty || pair? g ty))
           (lotr g v ty @ [_ ws fs] [(fs + map (k \ ['st b (off + k * (pair? g ty ? 4 (lowd g))) (ws k)]) ^#ws) [ty ws ()]] _ 'bad)
          (['a _ ty _] && gcplx? ty && !(locxsame? (vty v) ty)) (lotr g v ty @ 'bad 'bad v2 (lost g lv v2))
          (['a [_ b _] ty off] && stru? ty)
           (v @ ([vt r fs] && stru? vt && tsz g vt = tsz g ty)
                 (lomk g @ t (loesc g b, [(fs + locopya g r b off (tsz g ty) (min (tal g vt) (tal g ty)) + [['lea t b off]]) [ty t ()]]))
                _ (lono g ['store ty]))
          (_ . _ . ty . _) (lono g ['store ty])
          'bad)
   ; sz bytes from address s to d + doff, widest first
   (locopy g s d doff sz) (locopya g s d doff sz (wsize g))
   ; ..no wider than an alignment a, which -mstrict-align holds it to
   (locopya g s d doff sz a)
    (lomk g @ t (catmap ([p k] \ [[(uldop k) t s p] [(stw k) d (doff + p) t]]) (alchunks sz (loch g a))))
   (loch g a) (sal? g ? (salk g a) (wsize g))
   ; an aggregate in the frame: zeroed, then filled from its braces (cgzero and cgfill's arms)
   (lozero g off span)
    (lomk g @ z
       (: w (wsize g)
          (go o rem) (? (w <= rem) (['st 'r4 o z] . go (o + w) (rem - w))
                        (0 < rem) (['st1 'r4 o z] . go (o + 1) (rem - 1))
                        ())
          (['li z 0] . go off span)))
   ; the zeroing, less each store the fill lays over whole, when the fill reads nothing of the frame
   ; and calls nothing that might
   (lozfill g off span fs)
    (: sw {'st 8 'stsd 8 'st4 4 'stss 4 'st2 2 'st1 1}
       (st? f) (two? f && peep sw <f 0 > 0 && f 1 = 'r4 && cint? (f 2))
       (rd? f) (two? f && (elem <f '(call callr asm fix) || !(st? f) && elem 'r4 >f))
       cov (foldl (t \ f \ (st? f ? (foldl (t2 \ b \ pin t2 (f 2 + b) 1) t ^(sw <f)) t)) {} fs)
       (over? f) (st? f && all (b \ cov (f 2 + b) != ()) ^(sw <f))
       (any rd? fs ? (lozero g off span + fs) (filter (f \ !(over? f)) (lozero g off span) + fs)))
   (lostr g off text) (lomk g @ t (catmap (i \ [['li t (text i)] ['st1 'r4 (off + i) t]]) ^#text))
   (lofill g env off ty ini0)
    (unelide g env ty ini0 @ ini
       (? (ini @ ('str . _) 1 ()) (arr? ty ? (lostr g off (snip <>ini 0 (min #<>ini (tsz g ty)))) (lono g 'strinit))
          !(ini @ ('init . _) 1 ()) (lono g ['init ty])
          (arr? ty)
           (: elt <>ty esz (tsz g elt)
              (go l idx acc)
               (l @ (it . u) (: ci (it @ ('didx . k . _) k _ idx)
                                (loelt g env (off + ci * esz) elt (elval it) @ 'bad 'bad fs (go u (ci + 1) (acc + fs))))
                    acc)
              (go <>ini 0 ()))
          (stru? ty)
           (: fields <(peep (g 'stag) <>ty 0)
              (go l cur acc)
               (l @ (it . u)
                     (: ci (it @ ('dfield . nm . _) (fidx fields nm) _ cur)
                        (nthfield fields ci @
                           'bad (lono g 'field)
                           fe (? (bitf? (fe 2))
                                  (lox g env (elval it) @ 'bad 'bad
                                     v (lost g ['b ['long 'r4 ()] (fe 2) (off + fe 1) (lobfa g (fe 2) (lowb (off + fe 1)))] v @
                                          [f2 _] (go u (fnext g fields ci) (acc + f2))
                                          'bad))
                                 (loelt g env (off + fe 1) (fe 2) (elval it) @ 'bad 'bad
                                    fs (go u (fnext g fields ci) (acc + fs))))))
                    acc)
              (go <>ini 0 ()))
          (lono g ['init ty])))
   (loelt g env off ty val)
    (? (aggish? ty && (val @ ('init . _) 1 ()) || arr? ty && (val @ ('str . _) 1 ())) (lofill g env off ty val)
       (arr? ty) (lono g ['init ty])
       (lox g env val @ 'bad 'bad v (lost g (loelv g ty off) v @ [fs _] fs 'bad)))

   ; the lvalue's own forms, laid once before its use, and the lvalue without them
   (lolvfs lv) (lv @ (('a || 'b || 'u) . [_ _ fs] . _) fs ())
   (lolvbare lv) (lv @ [k [t r _] ty off] [k [t r ()] ty off] [k [t r _] ty off a] [k [t r ()] ty off a] lv)

   ; a pointer to a VLA steps by its row's bytes, the dim evaluated at the step: p +- i, i + p, p - q
   ; as the char arithmetic they are -> an expression | ()
   (lovrow g ty) (ty @ ('ptr . ('varr . el . n . _) . _) ['bin '* ['cast 'long n] ['num (tsz g el)]] _ ())
   (lovstep g op a b va vb)
    (: ra (lovrow g (vty va)) rb (lovrow g (vty vb)) (cp x) ['cast ['ptr 'char] x]
       (? !(elem op '(+ -)) ()
          (ra && rb) (op = '- ? ['bin '/ ['bin '- (cp a) (cp b)] ra])
          ra ['cast (vty va) ['bin op (cp a) ['bin '* b ra]]]
          (rb && op = '+) ['cast (vty vb) ['bin '+ (cp b) ['bin '* a rb]]]
          ()))
   ; an int's + - * ride a long, overflow left to the word. beside an unsigned int C says the
   ; int converts, so a long this tree calls an int does
   (lo32i? g env e)
    (e @ ['bin ('+ || '- || '* || '/ || '% || '& || '| || '^) a b] (lo32i? g env a && lo32i? g env b)
         ['bin ('shl || 'shr) a _] (lo32i? g env a)
         ['un ('neg || 'bnot) x] (lo32i? g env x)
         ['cond _ a b] (lo32i? g env a && lo32i? g env b)
         _ (elem (lopeek g env e) '(int short schar char cchar uchar ushort bool)))
   (loui g env e v w)
    (two? v && two? w && vty v = 'long && u32? g (vty w) && lo32i? g env e ? (lotr g v 'uint) v)
   ; -- the idioms read whole --
   ; x / or % a positive literal: a shift, or the reciprocal's high word -> a value | 'no
   (lomulh g u t m x)
    ((u ? 'umulh 'mulh) @ op
       (x86? g ? [['mov 'r0 x] ['li 'r1 m] ['fix '(r0 r1) '(r0 r1) [[op 'r1 'r0 'r1]]] ['mov t 'r1]]
          [['li t m] [op t t x]]))
   (lodivk g op a b)
    (b @ ([_ t0 [['li t1 n]]] && t0 = t1 && cint? n && 0 < n && !(abl? g 'divk))
          (: u (cmpu g (vty a) (vty b)) rt (rbin g (vty a) (vty b)) bw (8 * wsize g) rem (op = '%)
             (? (u && pow2? n) 'no
                (pow2? n) (loz g a b @ [_ x fx] (lodivp g rem x fx rt n bw))
                (t32? g || wasm? g || xt? g || n < 3 || !(n < 1 << (u ? bw (bw - 1)))) 'no
                (loz g a b @ [_ x fx] (lodivm g rem u x fx rt n bw))))
         _ 'no)
   ; C rounds toward zero and sar toward -inf: a negative dividend takes n - 1 first
   (lodivp g rem x fx rt n bw)
    (lomk g @ t (lomk g @ d
       (: k (lg2 n) bias ([['mov t x] ['sar t (bw - 1)] ['shr t (bw - k)] ['add t t x]])
          (? (n = 1) [rt d (rem ? (fx + [['li d 0]]) (fx + [['mov d x]]))]
             rem [rt d (fx + bias + lork g 'and t (0 - n) + [['mov d x] ['sub d d t]])]
             [rt t (fx + bias + [['sar t k]])]))))
   ; Granlund-Montgomery's reciprocal, magic1's M, its 65th bit folded back
   (lodivm g rem u x fx rt n bw)
    (magic1 n bw !u @ [m s add]
       (lomk g @ t (lomk g @ f
          (: hi (fx + lomulh g u t m x)
             (back q a) (lork g 'imul q n + [['mov a x] ['sub a a q]])
             (? !u (: q (hi + (add ? [['add t t x]]) + (0 < s ? [['sar t s]]) + [['mov f x] ['sar f (bw - 1)] ['sub t t f]])
                      (rem ? [rt f (q + back t f)] [rt t q]))
                add (: q (hi + [['mov f x] ['sub f f t] ['shr f 1] ['add f f t]] + (0 < s ? [['shr f s]]))
                       (rem ? [rt t (q + back f t)] [rt f q]))
                (: q (hi + (0 < s ? [['shr t s]]))
                   (rem ? [rt f (q + back t f)] [rt t q])))))))
   ; (x >> n) | (x << (W - n)), either way round: one rotate -> a value | 'bad | 'no
   (lorot g env L R)
    (L @ ['bin o1 _ _]
          (R @ ['bin o2 _ _]
                (? (!(rot4? g) || !(elem o1 '(shl shr)) || !(elem o2 '(shl shr)) || o1 = o2) 'no
                   (: s (o1 = 'shr ? L R) l (o1 = 'shr ? R L) x <>>s cs <>>>s cl <>>>l
                      (!(<>>l = x) || !(rotp? x) ? 'no
                         (rotw g env x @
                            () 'no
                            w (: ks (rotk g cs) kl (rotk g cl) rt (w = 32 ? 'uint 'ulong)
                                 (? (charm? ks && charm? kl)
                                     (ks + kl = w && 0 < ks && ks < w ?
                                        (lox g env x @ [_ r fs] (lomk g @ d [rt d (fs + [['mov d r] [(w = 32 ? 'ror4 'ror) d ks]])]) 'bad 'bad)
                                        'no)
                                    (charm? ks || charm? kl) 'no
                                    (rotc? g w cl cs) (lorotv g env x w cs () rt)
                                    (rotc? g w cs cl) (lorotv g env x w cl 1 rt)
                                    'no))))))
                _ 'no)
         _ 'no)
   (lorotv g env x w c ng rt)
    (lox g env x @ 'bad 'bad
       [_ r fx] (lox g env c @ 'bad 'bad
          [_ k fk] (lomk g @ d [rt d (fx + fk + [['mov d r] ['mov 'r1 k]] + (ng ? [['neg 'r1]]) + [[(w = 32 ? 'rorv4 'rorv) d 'r1]])])))
   ; c ? a : b with no branch, its arms laid ahead of the compare: what cannot fault or be written by it -> a value | 'bad | 'no
   (lospec? g env e)
    (e @ ['var nm] (lovar g env nm @ (['v _ ty] && losc? ty) 1
                                     (['m _ ty] && losc? ty) 1
                                     _ ())
         ['num _] 1
         ['bin op a b] (!(elem op '(/ %)) && lospec? g env a && lospec? g env b)
         ['un _ a] (lospec? g env a)
         ['cast ty a] (!(flo? ty || d128? ty) && lospec? g env a)
         ())
   ; what an arm costs every time it speculates: its operators
   (loops e)
    (e @ ['bin _ a b] (1 + loops a + loops b)
         ['un _ a] (1 + loops a)
         ['cast _ a] (loops a)
         0)
   (losel g env c a b)
    (? (relish? c && a = ['num 1] && b = ['num 0]) (lox g env c)
       (relish? c && a = ['num 0] && b = ['num 1]) (lox g env ['un 'not c])
       !(x64? g || a64? g) 'no
       (wrany? c || callish? c || two? (knum g c)) 'no
       (lominmax g env c a b @ 'no (losel1 g env c a b) v v))
   ; minsd and maxsd are x64's, fmin's NaN apart
   (lominmax g env c a b)
    (c @ (['bin op p q] && x64? g && elem op '(lt gt) && (a = p && b = q || a = q && b = p) && !(wrany? a || callish? a || wrany? b || callish? b))
          (lox g env a @ 'bad 'bad
             ([ta x fx] && ta = 'double)
              (lox g env b @ 'bad 'bad
                 ([tb y fy] && tb = 'double)
                  (lomkf g @ d ['double d (fx + fy + [['movapd d x] [(a = p ? (op @ 'lt 'minsd 'maxsd) (op @ 'lt 'maxsd 'minsd)) d y]])])
                 _ 'no)
             _ 'no)
         _ 'no)
   (losel1 g env c a b)
    (? !(lospec? g env a && lospec? g env b) 'no
       ; past two operators the branch, which runs one arm, wins
       (2 < loops a + loops b) 'no
       (lox g env a @ 'bad 'bad
          va (lox g env b @ 'bad 'bad
             vb (: xa (loui g env a va vb) xb (loui g env b vb va) ta (vty xa) tb (vty xb)
                   (? (lofl? ta || lofl? tb || !(losc? ta && losc? tb)) 'no
                      (: rt (? (ptr? ta) ta (ptr? tb) tb (rbin g ta tb)) (z v w) (loz g (lotr g v rt) w)
                         L (nlab g ".lo")
                         (lobr g env c 1 L @ 'bad 'bad
                            fc (rev fc @ (['br cc L2] . u)
                                  (: bl (rev u)
                                     (L2 = L && lbmen fc L = 1 ?
                                        (z xa xb @ [_ x fx] (z xb xa @ [_ y fy] (lomk g @ d
                                           [rt d (fx + fy + [['mov d y]] + bl + [['cmov cc d x]])])))
                                        'no))
                                  _ 'no))))))))
   ; __builtin_expect's mark on an arm: tailarm leaves a hot one, lays a cold one past the function
   (lohint g t le)
    (t @ ('blk (('nop m) . _)) (elem m '(hot cold) ? (pin g m (le . g m))) _ ())
   ; -- binary operators over two values --
   (locmp? op) (elem op '(eq ne lt le gt ge))
   (lobin g op a b kb)
    (? (bad? a || bad? b) 'bad
       ; a literal multiplier sits on the right
       (op = '* && losc? (vty a) && (a @ ([_ t [['li t2 k]]] && t = t2) 1 0) && !(b @ ([_ t [['li t2 k]]] && t = t2) 1 0)) (lobin g op b a ())
       (gcplx? (vty a) || gcplx? (vty b)) (locxbin g op a b)
       (d128? (vty a) || d128? (vty b)) (lowbin g op a b kb)
       (lofl? (vty a) || lofl? (vty b)) (lobinf g op a b)
       (pair? g (vty a) || pair? g (vty b)) (lopbin g op a b kb)
       !(losc? (vty a) && losc? (vty b)) (lono g ['bin op (vty a) (vty b)])
       (: ta (vty a) tb (vty b)
          (? (locmp? op)
              (loz g a b @ [_ x fx] (loz g b a @ [_ y fy] (lomk g @ d
                 ['int d (fx + fy + [['cmp x y] ['set (scc op (cmpu g ta tb)) d]])])))
             (elem op '(shl shr)) (losh g op a b kb)
             (elem op '(+ -) && ptr? ta && ptr? tb)
              (op = '+ ? 'bad
                 (lostep g ta @ 'bad 'bad
                    sz (lomk g @ d
                          (: fs (vfs a + vfs b + [['mov d (vreg a)] ['sub d d (vreg b)]])
                             ['long d (? (sz = 1) fs
                                         (sz & (sz - 1) = 0) (fs + [['sar d (lolog sz)]])
                                         (lomk g @ k (fs + [['li k sz] ['div d d k]])))]))))
             (elem op '(+ -) && (ptr? ta || op = '+ && ptr? tb))
              (: p (ptr? ta ? a b) i (ptr? ta ? b a)
                 (lostep g (vty p) @ 'bad 'bad
                    sz (lomk g @ s (lomk g @ d
                          [(vty p) d (vfs a + vfs b + (sz = 1 ? [['mov s (vreg i)]] (lork3 g 'imul s (vreg i) sz)) +
                                      [['mov d (vreg p)] [(irop op) d d s]])]))))
             (elem op '(+ - * & | ^))
              (: nar (nar32 g op ta tb 1) rt (lonrw op a b (rbin g ta tb))
                 ; a literal right side rides as the immediate
                 (b @ ([_ t [['li t2 k]]] && t = t2 && imma g (irop op) k) (lomk g @ d [rt d (vfs a + [['mov d (vreg a)] [(irop op) d d k]] + (nar ? [[nar d]]))])
                      _ (lomk g @ d [rt d (vfs a + vfs b + [['mov d (vreg a)] [(irop op) d d (vreg b)]] + (nar ? [[nar d]]))])))
             (elem op '(/ %))
              (lodivk g op a b @ v (v != 'no ? v
              (: u (cmpu g ta tb) io (op = '/ ? (u ? 'udiv 'div) (u ? 'urem 'rem))
                 ; a remainder's scratch: x64's rax, else a register apart from both operands
                 (loz g a b @ [_ x fx] (loz g b a @ [_ y fy] (lomk g @ d (lomk g @ t
                    [(rbin g ta tb) d (fx + fy + [(io @ ('rem || 'urem) [io d x y (x86? g ? 'r0 t)] [io d x y])])])))))))
             (lono g ['bin op]))))
   ; a value's range: a lone literal its own, else its type's | ()
   (lorng v) (v @ ([_ t [['li t2 k]]] && t = t2 && cint? k) [k k] [ty _ _] (irng ty) _ ())
   ; a widened + - * whose operands' ranges keep it within int is an int, sign-extended already
   (lonrw op a b rt)
    (: ra (lorng a) rb (lorng b)
       (? !(rt = 'long && two? ra && two? rb && elem op '(+ - *))  rt
          (: cs (op @ '+ [(<ra + <rb) (ra 1 + rb 1)] '- [(<ra - rb 1) (ra 1 - <rb)]
                      (map (x \ <x * <>x) [[<ra <rb] [<ra (rb 1)] [(ra 1) <rb] [(ra 1) (rb 1)]]))
             (-2147483648 <= foldl min <cs >cs && foldl max <cs >cs <= 2147483647 ? 'int rt))))
   ; the float lane: both sides to the wider of float and double, two-address
   (lobinf g op a b)
    (: ta (vty a) tb (vty b)
       ft (ta = 'double || tb = 'double ? 'double 'float)
       s (ft = 'float)
       (? !(losv? ta && losv? tb) (lono g ['bin op ta tb])
          (lotr g a ft @ [_ x fx]
             (lotr g b ft @ [_ y fy]
                (? (elem op '(+ - * /))
                    (lomkf g @ d [ft d (fx + fy + [['movapd d x]
                                                   [(op @ '+ (s ? 'addss 'addsd) '- (s ? 'subss 'subsd) '* (s ? 'mulss 'mulsd) (s ? 'divss 'divsd)) d y]])])
                   (locmp? op) (lofcmp g op s x y (fx + fy))
                   (lono g ['bin op ft]))))))
   ; x64's above and ae are false on a NaN: lt and le compare swapped, eq and ne carry parity
   (lofcmp g op s x y fs)
    (: uc (s ? 'ucomiss 'ucomisd)
       (op @ ('lt || 'le) (lomk g @ d ['int d (fs + [[uc y x] ['set (lofcc g (op = 'lt ? 'above 'ae)) d]])])
             ('gt || 'ge) (lomk g @ d ['int d (fs + [[uc x y] ['set (lofcc g (op = 'gt ? 'above 'ae)) d]])])
             _ (: a (lomk g) b (lomk g) d (lomk g)
                  ['int d (fs + [[uc x y]] + (op = 'eq ? [['set 'eq a] ['set 'np b] ['mov d a] ['and d d b]]
                                                          [['set 'ne a] ['set 'p b] ['mov d a] ['or d d b]]))])))
   (lolog n) (n <= 1 ? 0 (1 + lolog (n // 2)))
   ; a shift keeps the left type; x64's variable count rides r1
   (losh g op [ta ra fa] b kb)
    (: uL (usg? ta)
       u32 (op = 'shl && u32? g ta)
       s32 (s32bin? g ta 'int)
       ; a signed shift right keeps an int-ranged value in range
       rt (? (u32? g ta) 'uint s32 'int uL 'ulong (op = 'shr && irfit? ta 'int) 'int 'long)
       iop (op = 'shl ? 'shl (uL ? 'shr 'sar))
       vop (op = 'shl ? 'shlv (uL ? 'shrv 'sarv))
       d (lomk g)
       nar (? u32 [['zx4 d]] (s32 && op = 'shl) [['sx4 d]] ())
       (kb @ ([k] && 0 <= k && k < 64) [rt d (fa + [['mov d ra] [iop d k]] + nar)]
             [_] 'bad
             [rt d (fa + vfs b + [['mov d ra] ['mov 'r1 (vreg b)] [vop d 'r1]] + nar)]))

   ; forms laid by thunks run in list order (argument order is unspecified, and they mint), the
   ; first 'bad the answer
   (loseq l) (foldl (a \ t \ (bad? a ? 'bad (t 0 @ 'bad 'bad fs (a + fs)))) () l)
   (lol x _) x

   ; a float's post step: the old value answers, the store takes it plus the step
   (lopostf g env l lb o step)
    (locp g o @ [ty t fo]
       (lox g env ['num step] @ 'bad 'bad
          kv (lobin g '+ [ty t ()] kv () @ 'bad 'bad
                nv (lost g lb nv @ [fs _] [ty t (lolvfs l + fo + fs)] 'bad))))

   ; -- branches: to L when e's truth is sense --
   ; the builtins a 32-bit target lowers here: the rest's snippets count on the 64-bit word
   lobi32 '("__builtin_expect" "__builtin_prefetch" "__builtin_inf" "__builtin_nan" "__builtin_nanf"
            "__builtin_trap" "__builtin_unreachable" "__builtin_return_address" "__builtin_frame_address"
            "__builtin_clz" "__builtin_clzl" "__builtin_clzll" "__builtin_ctz" "__builtin_ctzl" "__builtin_ctzll"
            "__builtin_bswap16" "__builtin_bswap32" "__builtin_bswap64" "__builtin_isinf" "__builtin_alloca"
            "__builtin_popcount" "__builtin_popcountl" "__builtin_popcountll" "__builtin_ffs" "__builtin_ffsl" "__builtin_ffsll"
            "__builtin_add_overflow" "__builtin_sub_overflow" "__builtin_mul_overflow"
            "__builtin_add_overflow_p" "__builtin_sub_overflow_p" "__builtin_mul_overflow_p")
   (lopr? g a b) (losc? (vty a) && losc? (vty b) && (pair? g (vty a) || pair? g (vty b)))
   (lobr g env e sense L)
    (: (br x s L2 _) (lobr g env x s L2)
       ; a constant condition: the jump or nothing, so no edge leaves that never runs
       (knum g e @ ((k . _) && cint? k) ((k != 0) = (sense != 0) ? [['jmp L]])
          _ (e @ ['land a b]
             (sense ? (nlab g ".lo" @ k (loseq [(br a 0 k) (br b 1 L) (lol [['label k]])]))
                (loseq [(br a 0 L) (br b 0 L)]))
            ['lor a b]
             (sense ? (loseq [(br a 1 L) (br b 1 L)])
                (nlab g ".lo" @ k (loseq [(br a 1 k) (br b 0 L) (lol [['label k]])])))
            ['un 'not x] (lobr g env x (sense ? 0 1) L)
            ; a hint is its first argument's test
            ('call ('var "__builtin_expect") (x . _)) (lobr g env x sense L)
            (['bin op a b] && locmp? op)
             (lox g env a @ 'bad 'bad
                va0 (lox g env b @ 'bad 'bad
                      vb0 (: va (loui g env a va0 vb0) vb (loui g env b vb0 va0)
                            (? ((lofl? (vty va) || lofl? (vty vb)) && losv? (vty va) && losv? (vty vb))
                             (lofbr g op va vb sense L)
                            (lopr? g va vb)
                             (lop g va @ [fa al ah] (lop g vb @ [fb bl bh]
                                (lopcc g (sense ? op (negrel op)) (cmpu g (vty va) (vty vb)) al ah bl bh @ [cc ff] (fa + fb + ff + [['br cc L]]))))
                            !(losc? (vty va) && losc? (vty vb))
                             (lobin g op va vb () @ [_ d fs] (fs + [['cmp d 0] ['br (sense ? 'ne 'eq) L]]) 'bad)
                            (loz g va vb @ [_ x fx] (loz g vb va @ [_ y fy]
                               (fx + fy + [['cmp x y] ['br (scc (sense ? op (negrel op)) (cmpu g (vty va) (vty vb))) L]])))))))
            (lox g env e @ ([ty r fs] && pair? g ty) (lotest g [ty r fs] @ [_ d f2] (f2 + [['cmp d 0] ['br (sense ? 'ne 'eq) L]]))
                           ([ty r fs] && losc? ty) (fs + [['cmp r 0] ['br (sense ? 'ne 'eq) L]])
                           ([ty r fs] && lofl? ty) (lomkf g @ z (lofbr g 'ne [ty r fs] [ty z (lofz g z ty)] sense L))
                           ([ty r fs] && d128? ty) (lotest g [ty r fs] @ [_ d f2] (f2 + [['cmp d 0] ['br (sense ? 'ne 'eq) L]]))
                           'bad))))

   ; a float compare straight into its branch: above and ae are false on a NaN, so lt and le
   ; compare swapped, and the sense flipped takes be and below. a NaN is ne: parity jumps with
   ; ne, and steps over eq
   (lofbr g op va vb sense L)
    (: ft (vty va = 'double || vty vb = 'double ? 'double 'float)
       uc (ft = 'float ? 'ucomiss 'ucomisd)
       (lotr g va ft @ [_ x fx]
          (lotr g vb ft @ [_ y fy]
             ; a64's fcmp answers unordered as ne: no parity there
             (? (elem op '(eq ne))
                 (? !(x86? g) (fx + fy + [[uc x y] ['br ((op = 'ne) = (sense != 0) ? 'ne 'eq) L]])
                    ((op = 'ne) = (sense != 0)) (fx + fy + [[uc x y] ['br 'ne L] ['br 'p L]])
                    (nlab g ".lo" @ k (fx + fy + [[uc x y] ['br 'p k] ['br 'eq L] ['label k]])))
                (fx + fy + [(elem op '(lt le) ? [uc y x] [uc x y])
                            ['br (lofcc g (op @ ('lt || 'gt) (sense ? 'above 'be) _ (sense ? 'ae 'below))) L]]))
             _ 'bad)
          _ 'bad))

   ; -- expressions -> (ty vreg forms) | 'bad --
   ; what the 32-bit targets take yet: no wide or complex value, and a pair's two registers
   (lox g env e)
    (lox0 g env e @ ((ty . _) && ilp32? g && d128? ty && !(lo128? g)) (lono g ['wide ty])
                    ((ty . r . _) && pair? g ty && !(two? r)) (lono g ['pairleak ty])
                    v v)
   ; a tree of double literals, which folds as the runtime would answer: a float inside rounds first
   (lokd? e) (e @ ['flo _] 1 ['un 'neg x] (lokd? x) ['bin op a b] (elem op '(+ - * /) && (lokd? a && lokn? b || lokn? a && lokd? b)) ['cast 'double x] (lokn? x) 0)
   (lokn? e) (e @ ['num _] 1 (lokd? e))
   (lox0 g env e)
    (e @ () ['void () ()]
         ['lov v] v                                 ; a value already lowered
         ((('bin || 'un) . _) && lokd? e && gem? (ffold e)) (lox g env ['flo (ffold e)])
         (['cast 'float x] && <x != 'flo && lokd? x && gem? (ffold x)) (lox g env ['cast 'float ['flo (ffold x)]])
         (['num v] && ilp32? g && 2147483647 < v && v <= 4294967295) (lomk g @ t ['ulong t [['li t v]]])
         (['num v] && ilp32? g && !(-2147483648 <= v && v <= 2147483647) && -9223372036854775808 <= v <= 18446744073709551615)
          (u64 v @ u (lomk g @ l (lomk g @ h [(v < 0 ? 'llong 'ullong) [l h] [['li l (u % 4294967296)] ['li h (u // 4294967296)]]])))
         ['num v]
          (? (-9223372036854775808 <= v && v <= 18446744073709551615) (lomk g @ t [(numty v) t [['li t v]]])
             ; past the word: the wide value, split by // and % (a big has no bitwise ops)
             ((v < 0 ? (v + 64 2 * 64 2) v) % (64 2 * 64 2) @ u
                (: b (t32w? g ? 4294967296 18446744073709551616)
                   (cut n w) (n = 0 ? () ((w % b) . cut (n - 1) (w // b)))
                   (lomkw g @ ws (cut #ws u @ ks ['u128 ws (map (k \ ['li (ws k) (ks k)]) ^#ws)])))))
         ; sizeof a VLA local: its stashed bytes; a VLA type: its dim times its row
         ['szof e2]
          (lopeek g env e2 @
             ('varr . _ . _ . k . _) (g 'vslots k @ [_ so] (lomk g @ t ['ulong t [['ld t 'r4 so]]]) _ (lono g 'vla))
             ('varr . el . n . _) (lox g env ['cast 'ulong ['bin '* ['cast 'long n] ['num (tsz g el)]]])
             'bad 'bad
             ty (lomk g @ t ['ulong t [['li t (tsz g ty)]]]))
         ; gcc's &&L
         ['laddr nm] (wasm? g ? (lono g e) (lomk g @ t [['ptr 'void] t [['la t (name "\(g 'fn).\(nm)")]]]))
         ['flo v] (lomkf g @ w
                    ['double w (? (x64? g && fsel? g) [['ldsdl w (dblab g v)]]
                                  ((a64? g || rv64? g) && fsel? g) (lomk g @ t [['la t (dblab g v)] ['ldsd w t 0]])
                                  (lobits g w (fbits v)))])
         ['str s]
          (nlab g ".S" @ lbl
             (pin g 'strs ([lbl s] . g 'strs),
              lomk g @ t [['ptr (gchar g)] t [['la t lbl]]]))
         ['var nm]
          (lovar g env nm @ 'bad (g 'fns nm ? (lomk g @ t [['ptr (fnty g nm)] t [['la t (name nm)]]]) (lono g ['var nm]))
                            _ (lorv g (lolv g env e)))
         (['deref _] || ['dot _ _] || ['clit _ _]) (lorv g (lolv g env e))
         (['addr ['var nm]] && bad? (lovar g env nm) && g 'fns nm)
          (lomk g @ t [['ptr (fnty g nm)] t [['la t (name nm)]]])
         ['addr lv]
          (lolv g env lv @ (('a || 'u) . [_ r fs] . ty . off . _) (lomk g @ t (loesc g r, [['ptr ty] t (fs + [['lea t r off]])])) 'bad)
         ['asn dst rhs]
          (lolv g env dst @ 'bad 'bad
             l (lox g env rhs @ 'bad 'bad
                  v (lost g (lolvbare l) v @ [fs [ty r _]] [ty r (lolvfs l + fs)] 'bad)))
         (['post dst step] && charm? step)
          (lolv g env dst @ 'bad 'bad
             l (: lb (lolvbare l)
                  (lorv g lb @ 'bad 'bad
                     o (: ty (vty o)
                          (? (d128? ty)
                              ; the pair steps by one in the kit, the old answers
                              (o @ ([_ ws fo] && (step = 1 || step = -1))
                                    (lomkw g @ ov
                                       ((fo + lowmv ov ws) @ f2
                                          ((rv64? g ? (lomk g @ t (lowbin g (step = 1 ? '+ '-) [ty ws f2] ['long t [['li t 1]]] ()))
                                             (lokit g ty f2 (lowin g ws) (lokr g) (lokr g) [[(step = 1 ? 'inc128 'dec128)]])) @
                                             n (lost g lb n @ [fs _] [ty ov (lolvfs l + fs)] 'bad))))
                                   _ (lono g ['post ty]))
                             (lofl? ty || pair? g ty) (lopostf g env l lb o step)
                             (lostep g (ptr? ty ? ty ['ptr 'void]) @ 'bad 'bad
                             sz (locp g o @ [_ t fo] (lomk g @ n
                                   (lost g lb [(ptr? ty ? ty (rbin g ty 'int)) n ([['mov n t]] + lork g 'add n (step * sz) + (s32bin? g ty 'int ? [['sx4 n]]))] @
                                      [fs _] [ty t (lolvfs l + fo + fs)] 'bad)))))))))
         ['rmw op dst rhs]
          (lolv g env dst @ 'bad 'bad
             l (: lb (lolvbare l)
                  vo (lorv g lb) vr (lox g env rhs)
                  (lobin g op vo (elem op '(shl shr) ? vr (loui g env rhs vr vo)) (elem op '(shl shr) ? (lok g rhs)) @ 'bad 'bad
                     r (lost g lb r @ [fs [ty x _]] [ty x (lolvfs l + fs)] 'bad))))
         ['cast 'void x] (lox g env x @ [_ _ fs] ['void () fs] 'bad)
         ; a function type's value is its address, a function's own type standing
         ['cast ('fn . ft) x]
          (lox g env x @ ([vt r fs] && ptr? vt) [(vt @ ('ptr . ('fn . _) . _) vt _ ['ptr ('fn . ft)]) r fs]
                         v v)
         ['cast 'float ['flo v]] (lomk g @ t (lomkf g @ w ['float w [['li t (fbits32 v)] ['movdxr w t]]]))
         ; a float of a wide value: a constant only, folded exactly
         (['cast ty x] && lofl? ty && d128? (lopeek g env x))
          (cfold 1 x @ (v && cint? v) (lox g env ['cast ty ['flo (0.0 + v)]]) _ (lox g env x @ 'bad 'bad v2 (lotr g v2 ty)))
         ['cast ty x]
          (lox g env x @ ([vt r fs] && (pair? g ty || pair? g vt) && losv? ty && losv? vt) (lotr g [vt r fs] ty)
                         ([vt r fs] && (gcplx? ty || gcplx? vt) && (losv? ty || gcplx? ty)) (lotr g [vt r fs] ty)
                         ([vt r fs] && (d128? ty || d128? vt) && (losv? ty || d128? ty) && (losv? vt || d128? vt)) (lotr g [vt r fs] ty)
                         ([vt r fs] && losc? ty && losc? vt)
                          (two? (cvt ty r) ? (locp g [vt r fs] @ [_ t f2] [ty t (f2 + cvt ty t)]) [ty r fs])
                         ([vt r fs] && losv? ty && losv? vt) (lotr g [vt r fs] ty)
                         ; gcc's cast of a struct to its own type
                         ([vt r fs] && stru? ty && stru? vt && tsz g ty = tsz g vt) [ty r fs]
                         'bad 'bad
                         v (lono g ['cast (vty v) ty]))
         ; -1 and ~0 are literals, typed as C reads them
         (['un _ _] && two? (litv e)) (lox g env ['num <(litv e)])
         ['un 'not x]
          (lox g env x @ ([ty r fs] && pair? g ty) (lotest g [ty r fs] @ [_ t f2] (lomk g @ d ['int d (f2 + [['cmp t 0] ['set 'eq d]])]))
                         ([ty r fs] && losc? ty) (lomk g @ d ['int d (fs + [['cmp r 0] ['set 'eq d]])])
                         ([ty r fs] && (lofl? ty || d128? ty)) (lotest g [ty r fs] @ [_ t f2] (lomk g @ d ['int d (f2 + [['cmp t 0] ['set 'eq d]])]))
                         'bad)
         ; a float literal's negation is its image with the sign flipped
         ['un 'neg ['cast 'float ['flo v]]] (lomk g @ t (lomkf g @ w ['float w [['li t (fbits32 v ^ 2147483648)] ['movdxr w t]]]))
         (['un op x] && elem op '(neg bnot))
          (lox g env x @ ([ty [l h] fs] && pair? g ty)
                          (lomk g @ l2 (lomk g @ h2
                             [ty [l2 h2] (fs + (op = 'neg ? (lomk g @ z ([['li z 0]] + lopcy g 'subs 'sbc l2 h2 z z l h))
                                                  [['mov l2 l] ['not l2] ['mov h2 h] ['not h2]]))]))
                         ([ty r fs] && gcplx? ty && op = 'neg) (locxneg g [ty r fs])
                         ([ty ws fs] && d128? ty)
                          (op = 'neg ? (rv64? g ? (lomk g @ t (lowbin g '- ['long t [['li t 0]]] [ty ws fs] () @ [_ d f2] [ty d f2]))
                                          (lokit g ty fs (lowin g ws) (lokr g) (lokr g) '((n128))))
                             (lomkw g @ ds [ty ds (fs + catmap (k \ [['mov (ds k) (ws k)] ['not (ds k)]]) ^#ds)]))
                         ([ty r fs] && losc? ty)
             (: uty (usg? ty && !(elem ty '(uchar cchar ushort)))
                sty (op = 'neg && !uty && s32bin? g ty 'int)
                (locp g [ty r fs] @ [_ d f2]
                   [(? uty ty sty 'int 'long) d
                    (f2 + [[(op = 'neg ? 'neg 'not) d]] + (? uty (ty @ 'uint [['zx4 d]] ()) sty [['sx4 d]] ()))]))
             ; a float's sign flips through the gp file
             ([ty r fs] && lofl? ty && op = 'neg)
              (lomkf g @ d [ty d (fs + lofneg g ty d r)])
             'bad)
         ['comma a b] (lox g env a @ [_ _ fa] (lox g env b @ [t r fb] [t r (fa + fb)] 'bad) 'bad)
         ; a statement expression: its items, then the value in the env they end on
         ['sexpr items ve _]
          (loitems2 g env items @
             [fs e2] (ve @ () ['void () fs] _ (lox g e2 ve @ [t r f2] [t r (fs + f2)] 'bad))
             'bad)
         (('land || 'lor) . _)
          (nlab g ".lo" @ lf (nlab g ".lo" @ ld (lomk g @ d
             (lobr g env e 0 lf @ 'bad 'bad
                f ['int d (f + [['li d 1] ['jmp ld] ['label lf] ['li d 0] ['label ld]])]))))
         ['cond c a b]
          ((fsel? g ? (losel g env c a b) 'no) @ sel (sel != 'no ? sel
          ; arms a select would run but for their cost: no guess which is colder, so tailarm leaves the else
          (nlab g ".lo" @ le ((fsel? g && lospec? g env a && lospec? g env b ? (pin g 'hot (le . g 'hot))), nlab g ".lo" @ ld
             (lobr g env c 0 le @ 'bad 'bad
                fc (lox g env a @ 'bad 'bad
                      va (lox g env b @ 'bad 'bad
                            vb (? (vty va = 'void || vty vb = 'void)
                                   ['void () (fc + vfs va + [['jmp ld] ['label le]] + vfs vb + [['label ld]])]
                                  ; two structs: the chosen one's address
                                  (stru? (vty va) && stru? (vty vb))
                                   (tsz g (vty va) != tsz g (vty vb) ? (lono g ['cond (vty va) (vty vb)])
                                      (lomk g @ d [(vty va) d (fc + vfs va + [['mov d (vreg va)] ['jmp ld] ['label le]] +
                                                               vfs vb + [['mov d (vreg vb)] ['label ld]])]))
                                  ; a wide side: both wide, each part joined
                                  (d128? (vty va) || d128? (vty vb))
                                   (: rt (wbin (vty va) (vty vb))
                                      (lotr g va rt @ [_ xs fx]
                                         (lotr g vb rt @ [_ ys fy]
                                            (lomkw g @ ds
                                               [rt ds (fc + fx + lowmv ds xs + [['jmp ld] ['label le]] +
                                                       fy + lowmv ds ys + [['label ld]])])
                                            _ 'bad)
                                         _ 'bad))
                                  !(losv? (vty va) && losv? (vty vb)) (lono g ['cond (vty va) (vty vb)])
                                  (: xa (loui g env a va vb) xb (loui g env b vb va) ta (vty xa) tb (vty xb)
                                     fl (lofl? ta || lofl? tb)
                                     rt (? (ptr? ta) ta (ptr? tb) tb fl (ta = 'double || tb = 'double ? 'double 'float) (rbin g ta tb))
                                     (z v w) (fl ? (lotr g v rt) (loz g (lotr g v rt) w))
                                     (z xa xb @ [_ x fx] (z xb xa @ [_ y fy] (lomkv g rt @ d
                                        [rt d (fc + fx + lomvs d x + [['jmp ld] ['label le]] + fy + lomvs d y + [['label ld]])]))))))))))))
         ['bin op a b]
          (: kb (elem op '(shl shr) ? (lok g b))
             gz (op = '| ? (gather g env e))
             ro (op = '| && !gz ? (lorot g env a b) 'no)
             (? gz (lox g env gz) (ro != 'no) ro
             (: va (lox g env a)
             vb (two? kb ? ['int () ()] (lox g env b))
             sh (elem op '(shl shr)) va2 (sh ? va (loui g env a va vb)) vb2 (sh ? vb (loui g env b vb va))
                (lovstep g op a b va2 vb2 @ () (lobin g op va2 vb2 kb) x (lox g env x)))))
         ; a64 walks the lines; elsewhere the args for their effects alone
         ['call ['var "__builtin___clear_cache"] as]
          (a64? g && #as = 2 ?
             (lox g env <as @ 'bad 'bad [_ a fa]
                (lox g env <>as @ 'bad 'bad [_ b fb]
                   ['void () (fa + fb + [['mov 'r0 a] ['mov 'r1 b] ['fix '(r0 r1) '(r2 r3 r9) (a64flush g)]])]))
             (loseq (map (x \ (lox g env x @ [_ _ fs] (lol fs) _ (lol 'bad))) as) @ 'bad 'bad fs ['void () fs]))
         ['call fh as] (lomem g env fh as @ 'no (locall g env fh as) v v)
         ; the va_list's fields, as cgexpr's SysV arms lay them
         ['vastart ap]
          (lox g env ap @ [_ p fs]
             (lomk g @ t (pin g 'fesc 1,
                (: ngp (peep g 'vagp 0) nfp (peep g 'vaxmm 0) nov (peep g 'vaov 0) rsa (peep g 'rsa 0)
                   ['void () (fs + (? (ia32? g) [['lea t 'r4 (ovb g + nov)] ['st p 0 t]]
                      (t32? g) [['lea t 'r4 (ngp < 4 ? (ovb g + 4 * ngp) (ovb g + 16 + nov))] ['st p 0 t]]
                      (a64? g)
                      ; AAPCS64: __stack past the named overflow, each top past its file's saves, each offs
                      ; the unnamed registers' bytes below it
                      [['lea t 'r4 (ovb g + 8 * nov)] ['st p 0 t] ['lea t 'r4 (rsa + 64)] ['st p 8 t]
                       ['lea t 'r4 (rsa + 192)] ['st p 16 t] ['li t (0 - 8 * (8 - ngp))] ['st4 p 24 t]
                       ['li t (nofp? g ? 0 (0 - 16 * (8 - nfp)))] ['st4 p 28 t]]
                      ; the eight-word block holds the argument registers at its top
                      (w32s? g) [['lea t 'r4 (ngp < ngp g ? (ovb g + 4 * (8 - ngp g) + 4 * ngp) (ovb g + 32 + nov))] ['st p 0 t]]
                      (rv64? g) [['lea t 'r4 (ovb g + 8 * ngp + 8 * nov)] ['st p 0 t]]   ; riscv: past the named words
                      [['li t (8 * ngp)] ['st4 p 0 t] ['li t (48 + 16 * nfp)] ['st4 p 4 t]
                       ['lea t 'r4 (16 + 8 * nov)] ['st p 8 t] ['lea t 'r4 rsa] ['st p 16 t]]))])))
             'bad)
         ['vaend _] ['void () ()]
         ['vaarg ap ty]
          (? (a64? g) (lox g env ap @ [_ p fs] (lovaarg64 g p fs ty) 'bad)
             (rv64? g) (lox g env ap @ [_ p fs] (lovaargrv g p fs ty) 'bad)
             (x64? g) (lox g env ap @ [_ p fs] (lovaarg g p fs ty) 'bad)
             (ilp32? g) (lox g env ap @ [_ p fs] (lo32vaarg g p fs ty) 'bad)
             (lono g 'vaarg))
         (lono g ['expr <e]))

   ; va_arg off the list at p: the old walk, the list in r0 and the fetch address out of r2,
   ; renamed; a struct's value is that address
   (lovaarg g p fs ty)
    (: lov (nlab g ".vo") ld (nlab g ".vd")
       fl (lofl? ty) foff (fl ? 4 0) lim (fl ? 176 48) step (fl ? 16 8)
       ovs (n8 \ ['(ld r2 r0 8) '(mov r3 r2) ['add 'r3 'r3 n8] '(st r0 8 r3)])
       walk ([['ld4 'r1 'r0 foff] ['cmp 'r1 lim] ['br 'ge lov] '(ld r2 r0 16) '(add r2 r2 r1)
              ['add 'r1 'r1 step] ['st4 'r0 foff 'r1] ['jmp ld] ['label lov]] + ovs 8 + [['label ld]])
       (at w) (loren2 g [['r0 p]] 'r2 'long w @ [_ a f2] [a (fs + f2)])
       (? (ty = 'float || d128? ty || gcplx? ty) (lono g ['vaarg ty])
          (stru? ty)
           (: n8 (8 * aslots g ty)
              (? (8 < asalign g ty) (lono g ['vaarg ty])
                 (amem? g ty) (at (ovs n8) @ [a f2] [ty a f2])
                 (aone g ty = 'int || ipair? g ty)
                  (at ([['ld4 'r1 'r0 0] ['cmp 'r1 (49 - n8)] ['br 'ge lov] '(ld r2 r0 16) '(add r2 r2 r1)
                        ['add 'r1 'r1 n8] ['st4 'r0 0 'r1] ['jmp ld] ['label lov]] + ovs n8 + [['label ld]]) @
                   [a f2] [ty a f2])
                 (lono g ['vaarg ty])))
          !(losv? ty) (lono g ['vaarg ty])
          (at walk @ [a f2] (lomkt g ty @ d [ty d (f2 + [(fl ? ['ldsd d a 0] [(ldop ty) d a 0])])]))))

   ; a call: the first six gp scalars in registers, the rest in a 16-aligned block at sp. a
   ; direct callee is a known fn, an indirect one a pointer value read after the args
   (locall g env fh as)
    (fh @ (['var nm] && bad? (lovar g env nm) && starts? nm "__builtin_") (lobi g env nm as)
          (['var nm] && bad? (lovar g env nm) && (two? (atomop nm) || elem nm '("__sync_lock_test_and_set" "__sync_lock_release")))
           (loat g env nm as)
          (['var nm] && bad? (lovar g env nm) && g 'fns nm)
           (g 'sigs nm @
              ; a call off its prototype's count refuses
              ((_ . ptys . va . _) && 0 < #ptys && (va ? (#as < #ptys) (#as != #ptys))) (loarity g "call to '\(nm)'" #ptys va #as)
              (rt . ptys . va . rest)
               (locall1 g env rt ptys va (rest @ ('ms . _) 1 ()) as [['call (intern nm)]] ())
              (lono g ['call nm]))
          _ (lox g env fh @
               ; a variadic prototype parks () as an unprototyped one does: al only then
               [('ptr . ['fn rt ptys] . _) r fs] (locall1 g env rt ptys (two? ptys ? () 1) () as (locr g r) [r fs])
               [('ptr . ['fn rt ptys 'ms] . _) r fs] (locall1 g env rt ptys () 1 as (locr g r) [r fs])
               [('ptr . ['fn rt] . _) r fs] (locall1 g env rt () 1 () as (locr g r) [r fs])
               'bad 'bad
               (ty . _) (lono g ['callee ty])))
   ; a snippet over r0..r3 renamed onto fresh vregs, r0 the operand in and the answer out
   (loren g v fs) (loren2 g [['r0 v]] 'r0 'long fs)
   ; ..and over f0..f3 too: ins [register value].. copied in, the answer out of o
   (loren2 g ins o ty fs)
    (foldl (t \ r \ pin t r (lofr? r ? (lomkf g) (lomk g))) {} '(r0 r1 r2 r3 f0 f1 f2 f3) @
     t [ty (t o) (map (p \ lomv (t <p) <>p) ins + map (f \ map (x \ peep t x x) f) fs)])
   ; forms on fixed registers: the operand in r0, the answer out of it, ds what it writes
   (lofix g v ds fs)
    (lomk g @ d ['long d [['mov 'r0 v] ['fix '(r0) ds fs] ['mov d 'r0]]])
   ; ..a pair's operand in r0:r1, to a word in r0 or a pair in r0:r1
   (lofixp g v pr fs)
    (lotr g v 'llong @
     'bad 'bad
     [_ [l h] f0]
      (: b [['mov 'r0 l] ['mov 'r1 h] ['fix '(r0 r1) (lokc g) fs]]
         (lomk g @ d
            (pr ? (lomk g @ e ['ullong [d e] (f0 + b + [['mov d 'r0] ['mov e 'r1]])])
               ['long d (f0 + b + [['mov d 'r0]])]))))
   ; one scalar operand -> [ty r fs] | 'bad
   (lobi1 g env e)
    (lox g env e @ ([vt r fs] && losc? vt) [vt r fs]
                   'bad 'bad
                   (vt . _) (lono g ['arg vt]))
   ; a builtin of a pair at 32 bits, pr if it answers one
   (lobp g env e pr fs)
    (lox g env e @ 'bad 'bad v (lofixp g v pr fs))
   ; a builtin, its spec
   (lobi g env nm as)
    (: (one f) (lobi1 g env <as @ 'bad 'bad [vt r fs] (f r @ 'bad 'bad [t d fs2] [t d (fs + fs2)]))
       ll (elem nm '("__builtin_clzll" "__builtin_clzl" "__builtin_ctzll" "__builtin_ctzl"))
       (? (ilp32? g && nelem nm lobi32) (lono g ['call nm])
          (elem nm '("__builtin_expect" "__builtin_prefetch")) (lobi1 g env <as)
       ; the _p forms: the plain one, storing to a fresh temp of the third operand's type
       (elem nm '("__builtin_add_overflow_p" "__builtin_sub_overflow_p" "__builtin_mul_overflow_p"))
        (? (#as != 3) (lono g ['call nm])
           (peekty g env (as 2) @
              'bad 'bad
              ty (ntmp g ty @ off
                    (lox g env (as 2) @ 'bad 'bad
                       v (lost g ['a ['long 'r4 ()] ty off] v @
                            [f0 _] (lobi g ([".ovp" 'm off ty] . env) (snip nm 0 (#nm - 2)) [<as <>as ['addr ['var ".ovp"]]] @
                                      [vt r fs] [vt r (f0 + fs)]
                                      _ 'bad)
                            _ 'bad)))))
       ; the exact a op b stored modulo *r's width, answering whether it did not fit: ovlow's
       ; expression, or for three signed words the machine's own flag
       (elem nm '("__builtin_add_overflow" "__builtin_sub_overflow" "__builtin_mul_overflow"))
        (? (#as != 3) (lono g ['call nm])
           (ovlow g env nm as @
              () (lobi1 g env <as @ 'bad 'bad
                    a (lobi1 g env <>as @ 'bad 'bad
                         b (lox g env (as 2) @ 'bad 'bad
                              [_ p pf] (lomk g @ t (lomk g @ d
                                 ['int d (vfs a + vfs b + pf + [['mov 'r0 (vreg a)] ['mov 'r1 (vreg b)]
                                          ['fix '(r0 r1) (x64? g ? '(r0 r1) (lokc g)) (ovfops g nm)]
                                          ['mov t 'r0] ['mov d 'r1] ['st p 0 t]])])))))
              x (lox g env x)))
       ; |x| is infinite: the bits shifted past the sign are inf's
       (nm = "__builtin_isinf")
        (lox g env <as @ ([vt r f0] && lofl? vt)
           (lotr g [vt r f0] 'double @ [_ w fs]
              (ilp32? g ?
                 (lomk g @ l (lomk g @ h (lomk g @ k (lomk g @ d
                    ['long d (fs + [['movrrq l h w] ['li k 2147483647] ['and h h k] ['li k 2146435072]
                                    ['xor h h k] ['or h h l] ['cmp h 0] ['set 'eq d]])]))))
                 (lomk g @ t (lomk g @ k (lomk g @ d
                    ['long d (fs + [['movqrx t w] ['shl t 1] ['li k 18437736874454810624] ['cmp t k] ['set 'eq d]])])))))
           _ (lono g ['call nm]))
       ; an infinity, a quiet NaN (the tag ignored): their bits
       (elem nm '("__builtin_inf" "__builtin_nan" "__builtin_nanf"))
        (lomkf g @ w ['double w (lobits g w (nm = "__builtin_inf" ? 9218868437227405312 9221120237041090560))])
          (elem nm '("__builtin_trap" "__builtin_unreachable"))
           (lomk g @ d ['long d [['fix () () [[(x86? g ? 'ud2 'trap)]]] ['li d 0]]])
          (nm = "__builtin_alloca")
           (? (g 'abad) (lono g ['call nm])
              (one (v \ (: t (lomk g) u (lomk g) d (lomk g)
                           (pin g 'fesc 1, pin g 'hasasm 1,
                            ['(ptr void) d ([['mov t v] ['add t t 15] ['shr t 4] ['shl t 4] ['lea u 'sp 0]
                                             ['sub u u t] ['lea 'sp u 0]] + (avz? g ? (lovz g u t)) + [['lea d 'sp 0]])])))))
          (elem nm '("__builtin_return_address" "__builtin_frame_address"))
           ; riscv's saved ra rides a padded push, and its saved s0 is no caller's base
           (as @ ([['num k]] && 0 <= k && !((rv? g || xt? g) && 0 < k) && !(wasm? g && nm = "__builtin_return_address"))
                  (lomk g @ d
                     (pin g 'fesc 1, pin g 'fpin 1,
                      ['(ptr void) d (['lean d 'r4 0] . map (_ \ ['ld d d 0]) ^k +
                                      (nm = "__builtin_return_address" ? [['ld d d (rv? g || xt? g ? 16 (wsize g))]]))]))
                 _ (lono g ['call nm]))
          (elem nm '("__builtin_clz" "__builtin_clzl" "__builtin_clzll"))
           (: w (nm = "__builtin_clzll" || !(nm = "__builtin_clz") && !(ilp32? g))
              (ilp32? g && w ? (lobp g env <as 0 (clzops g w))
                 (one (v \ lofix g v (x64? g || a64? g ? () (lokc g)) (clzops g w)))))
          (elem nm '("__builtin_ctz" "__builtin_ctzl" "__builtin_ctzll"))
           (: w (nm = "__builtin_ctzll" || !(nm = "__builtin_ctz") && !(ilp32? g))
              (? (ilp32? g && w)
                  (t32? g ? (lono g ['call nm]) (lobp g env <as 0 (ctzops g w)))
                 (one (v \ lofix g v (x64? g || a64? g ? () (lokc g)) (ctzops g w)))))
          (nm = "__builtin_bswap16")
           (one (v \ loren g v '((li r2 255) (mov r1 r0) (shr r1 8) (and r1 r1 r2)
                                 (and r0 r0 r2) (shl r0 8) (or r0 r0 r1))))
          (nm = "__builtin_bswap32") (one (v \ loren g v bsw32))
          (nm = "__builtin_bswap64" && ilp32? g) (lobp g env <as 1 (bs64ops g))
          (nm = "__builtin_bswap64")
           (one (v \ loren g v '((li r2 71777214294589695)
                                 (mov r1 r0) (shr r1 8) (and r1 r1 r2)
                                 (and r0 r0 r2) (shl r0 8) (or r0 r0 r1)
                                 (li r2 281470681808895)
                                 (mov r1 r0) (shr r1 16) (and r1 r1 r2)
                                 (and r0 r0 r2) (shl r0 16) (or r0 r0 r1)
                                 (mov r1 r0) (shr r1 32) (shl r0 32) (or r0 r0 r1))))
          (nm = "__builtin_popcountll" && ilp32? g) (lobp g env <as 0 (pc64ops g))
          (elem nm '("__builtin_popcount" "__builtin_popcountl" "__builtin_popcountll"))
           (one (v \ loren g v (popops g (nm = "__builtin_popcount" || ilp32? g))))
          (nm = "__builtin_ffsll" && ilp32? g) (lono g ['call nm])
          (elem nm '("__builtin_ffs" "__builtin_ffsl" "__builtin_ffsll"))
           (nlab g ".ffs" @ lz
              (: w32 (nm = "__builtin_ffs" || ilp32? g)
                 (one (v \ loren g v ((w32 && !(ilp32? g) ? '((li r2 4294967295) (and r0 r0 r2))) +
                                      ['(cmp r0 0) ['br 'eq lz] '(mov r1 r0) '(sub r1 r1 1) '(xor r0 r0 r1)] +
                                      popops g w32 + [['label lz]])))))
          (lono g ['call nm])))
   ; an atomic, x64's arms of cgatomic: raw loops on fixed registers, the operands copied in
   (loat g env nm as)
    (: k (atomop nm) kind (k @ (kd . _) kd 'lock)
       ; the order: a constant, or anything else laid for its effects and taken as seq_cst
       mo (? (nm @ ("__sync_" + _) 1 ()) [5 ()] (elem kind '(lockfree generic)) [5 ()]
             (as (#as - 1) @ ['num o] [o ()]
                             e (lox g env e @ 'bad 'bad [_ _ fs] [5 fs])))
       (fx u d fs) ['fix u d fs]
       ; t32's exclusive loops keep strex's status in r4, named so the frame saves it
       (lx u d fs) (fx u d (t32? g ? ('(li r4 0) . fs) fs))
       (? (bad? mo) 'bad
          (kind = 'generic) (nolane g "\(nm) is not carried out (its _n form is)")
          (kind = 'fence) (lomk g @ d ['long d (<>mo + (<mo = 0 ? () [(fx () () (afence g))]) + [['li d 0]])])
          (kind = 'sfence) (lomk g @ d ['long d (<>mo + [(fx () () (abar g))] + [['li d 0]])])
          (kind = 'lockfree)
           (cfold !(ilp32? g) <as @ n
              (charm? n ? (lomk g @ d ['int d [['li d (elem n (awidths g) ? 1 0)]]]) (lono g ['call nm])))
          (lobi1 g env <as @
             'bad 'bad
             ([('ptr . pt . _) p pf] && amw g pt)
              (: w (amw g pt) z (lomk g)
                 ; a fence ahead of a store or a load's read, and after one
                 fa (mo0 \ (mo0 = 0 || x86? g ? () [(fx () () (afence g))]))
                 fb (mo0 \ (mo0 = 5 && !(x86? g) ? [(fx () () (afence g))]))
                 (? (ilp32? g && w = 8) (lowno g nm w)
                    (elem kind '(rmw cas vcas bcas tas lock) && !(elem (kind = 'tas ? 1 w) (awidths g))) (lowno g nm (kind = 'tas ? 1 w))
                    (kind = 'lock)
                     (? (nm = "__sync_lock_release")
                         (? !(elem w (ilp32? g ? '(4) '(4 8))) (lowno g nm w)
                            !(x86? g)
                             ['long z (pf + [['mov 'r1 p] ['li 'r0 0] ['fix '(r0 r1) '(r0 r1) (arel g w)] ['li z 0]])]
                            ['long z (pf + [['li z 0] [(stw w) p 0 z]])])
                        (lobi1 g env (as 1) @
                           'bad 'bad
                           [_ v vf] (? !(elem w (ilp32? g ? '(4) '(4 8))) (lowno g nm w)
                                       (lomk g @ d
                                          [pt d (pf + vf + [['mov 'r0 v] ['mov 'r1 p]
                                                            (fx '(r0 r1) (x86? g ? '(r0) '(r0 r2 r3)) (axchg g w))
                                                            ['mov d 'r0]] + cvt pt d)]))))
                    (kind = 'load)
                     (lomk g @ d [pt d (<>mo + pf + fb (<mo) + [[(ldop pt) d p 0]] + fa (<mo))])
                    (kind = 'clear)
                     ['long z (<>mo + pf + [['li z 0]] + (<mo = 0 || x86? g ? () [(fx () () (afence g))]) + [['st1 p 0 z]]
                               + (<mo = 5 ? [(fx () () (afence g))]))]
                    (kind = 'tas)
                     (: o (lomk g) d (lomk g)
                        ['int d (<>mo + pf + [['li 'r2 1] ['mov 'r1 p] (lx '(r1 r2) '(r0 r3) (armw g 1 'set))
                                              ['mov o 'r0] ['zx1 o] ['li z 0] ['cmp o z] ['set 'ne d]])])
                    (kind = 'cas)
                     (lobi1 g env (as 1) @ 'bad 'bad
                        [_ ep ef]
                         (lobi1 g env (as 2) @ 'bad 'bad
                            [_ dv df]
                             (: t (lomk g) o (lomk g) d (lomk g) ok (nlab g ".casok")
                                ['int d (<>mo + pf + ef + df +
                                         [[(uldop w) t ep 0] ['mov 'r0 t]] + aexp g w + [['mov 'r1 p] ['mov 'r2 dv]
                                          (lx '(r0 r1 r2) '(r0 r2 r3) (acas g w))
                                          ['mov o 'r0] ['mov d 'r2] ['li z 0] ['cmp d z] ['br 'ne ok]
                                          [(stw w) ep 0 o] ['label ok]])])))
                    (lobi1 g env (as 1) @
                       'bad 'bad
                       [_ v vf]
                        (? (kind = 'store) ['long z (<>mo + pf + vf + fa (<mo) + [[(stop pt) p 0 v]] + (<mo = 5 ? [(fx () () (afence g))]))]
                           (kind = 'rmw)
                            (lomk g @ d
                               [pt d (<>mo + pf + vf + [['mov 'r1 p] ['mov 'r2 v] (lx '(r1 r2) '(r0 r3) (armw g w (k 1)))
                                                        ['mov d (k 2 = 'new ? 'r3 'r0)]] + cvt pt d)])
                           (elem kind '(vcas bcas))
                            (lobi1 g env (as 2) @ 'bad 'bad
                               [_ nv nf]
                                (lomk g @ d
                                   (kind = 'vcas ?
                                      [pt d (pf + vf + nf + [['mov 'r0 v]] + aexp g w + [['mov 'r1 p] ['mov 'r2 nv]
                                                             (lx '(r0 r1 r2) '(r0 r2 r3) (acas g w)) ['mov d 'r0]]
                                                    + cvt pt d)]
                                      ['int d (pf + vf + nf + [['mov 'r0 v]] + aexp g w + [['mov 'r1 p] ['mov 'r2 nv]
                                                              (lx '(r0 r1 r2) '(r0 r2 r3) (acas g w)) ['mov d 'r2]])])))
                           (lono g ['call nm])))))
             (vt . _) (lono g ['atomic vt]))))
   ; cl the call form, fv the callee's (vreg forms) | (); va also lays al, the vector count
   ; ms an ms_abi callee: ints only, rcx rdx r8 r9 then the stack above a 32-byte shadow
   (locall1 g env rt ptys va ms as cl fv)
    (? !(rt = 'void || losv? rt || d128? rt || loagg? g rt) (lono g ['ret rt])
       (ms && any d128? (rt . ptys)) (lono g 'msabi)
       (ms && any (t \ lofl? t || stru? t) (rt . ptys)) (lono g 'msabi)
       (0 < #ptys && !va && #as != #ptys) (loarity g "this call" #ptys va #as)
       ; past SysV and AAPCS64 a pair has no lane
       (!(lo128? g) && (ms || d128? rt || any d128? ptys)) (lono g 'abi)
       (ilp32? g && !(lot32sig g (rt . ptys))) (lono g 'abi)
       (: (arg e pt)
           (lox g env e @ ([vt r fs] && !(lo128? g) && d128? vt) (lono g ['abi vt])
                          ([vt r fs] && (losv? vt || d128? vt))
                           (pt @ 'none (vt = 'float ? (lotr g [vt r fs] 'double) [vt r fs])
                                 p9 (losv? p9 || d128? p9 || gcplx? p9 ? (lotr g [vt r fs] p9) (lono g ['arg p9])))
                          ([vt r fs] && gcplx? vt && gcplx? pt && !(locxsame? vt pt)) (lotr g [vt r fs] pt)
                          ([vt r fs] && loagg? g vt) [vt r fs]
                          'bad 'bad
                          (vt . _) (lono g ['arg vt]))
          ; a riscv variadic call: an unnamed double rides the gp file
          (rvva i v) (v @ ([vt r fs] && rv64? g && va && two? ptys && #ptys <= i && lofl? vt)
                            (lomk g @ t ['long t (fs + [['movqrx t r]])]) _ v)
          (go l i acc)
           (l @ (e . u) (arg e (i < #ptys ? (ptys i) 'none) @ 'bad 'bad v (go u (i + 1) (acc + [(rvva i v)])))
                acc)
          ; a returned aggregate lands in a temp; in the memory class its address is the hidden first arg
          sret (losr? g rt)
          (go as 0 () @ 'bad 'bad
             vs (: rto (stru? rt ? (ntmp g rt) 0)
                   hv (sret ? (lomk g @ h [[['ptr rt] h [['lea h 'r4 rto]]]]))
                   ; the hidden pointer: SysV's first arg, AAPCS64's x8
                   pl (ms ? [0 0 (map (i \ [('(r1 r2 r7 r8) i) (vreg (vs i))]) ^(min 4 #vs))
                             (map (i \ ['w (vs i) 8]) (filter (i \ 3 < i) ^#vs)) ()]
                          (ilp32? g ? (lo32place g (hv + vs) va) (loplace g (a64? g ? vs (hv + vs)))))
                   sh (ms ? 32 0)
                   nf (pl 1) rg (pl 2 + (a64? g && sret ? [['r8 (vreg <hv)]])) sk (pl 3) pre (pl 4) rs (map lorgnm rg)
                   d (d128? rt ? (lomkw g) (lomkv g rt))
                   ; SysV's count of the vector registers in al, unless -mskip-rax-setup
                   al (va && x64? g && !(x86k? g 'nal) ? [['li 'r0 nf]])
                   (stk x o) (x @ ['at v n _] (: ty (vty v)
                                              (? (stru? ty) (locopya g (vreg v) 'sp o n (tal g ty))
                                                 (pair? g ty) [['st 'sp o <(vreg v)] ['st 'sp (o + 4) <>(vreg v)]]
                                                 (d128? ty) (map (k \ ['st 'sp (o + 4 * k) (vreg v k)]) ^4)
                                                 [[(ty @ 'float 'stss 'double 'stsd 'st) 'sp o (vreg v)]]))
                                  ['w2 v n] [['st 'sp o <(vreg v)] ['st 'sp (o + n // 2) <>(vreg v)]]
                                  ['w v _] [[(vty v @ 'float 'stss 'double 'stsd 'st) 'sp o (vreg v)]]
                                  ['s v n] (locopya g (vreg v) 'sp o n (tal g (vty v))))
                   ; a pair on the stack sits 16-aligned
                   (sgo l o acc) (l @ (x . u) ((x @ ['w2 _ n] (aup o n) ['at _ _ f] f _ o) @ p (sgo u (p + x 2) (acc + stk x p))) [o acc])
                   so (sgo sk sh ()) sfs (so 1) blk (aup <so 16)
                   res (? (rt = 'void) ()
                          (lofl? rt && soft? g) [(rt = 'float ? ['movdxr d 'r0] ['movqrr d 'r0 'r1])]
                          (lofl? rt) ((ia32? g ? [['fix () lokl [['raw (x87raw g (rt = 'float) 1)]]]]) + [['movapd d 'f0]])
                          (d128? rt) (lowmv d (lowabi g))
                          (pair? g rt) [['mov <d 'r0] ['mov <>d (ia32? g ? 'r2 'r1)]]
                          (stru? rt) (loesc g 'r4, (sret ? (ia32? g && !(srreg? g va) ? [['fix () lokl [['raw (m16b g + [131 236 4])]]]])
                                                          (loebst g (lopcs g rt) 'r4 rto)) + [['lea d 'r4 rto]])
                          (['mov d 'r0] . map (f \ [<f d]) (rext g rt)))
                   [rt (rt = 'void ? () d)
                    (catmap vfs (hv + vs) + (fv @ [_ ffs] ffs ()) + pre +
                     (blk = 0 ? () ([['sub 'sp 'sp blk]] + sfs)) +
                     catmap lorgmv rg + al +
                     [('(cuse) + rs + (two? al ? '(r0)))] + cl +
                     res + (blk = 0 ? () [['add 'sp 'sp blk]]))]))))
   ; the last call of a musttail ret's forms, marked 'must | 'bad
   (lomust g fs)
    (: (go l) (l @ () (lono g 'musttail)
                   ((f . u) && two? f && elem <f '(call callr)) ((f + '(must)) . u)
                   (f . u) (go u @ 'bad 'bad r (f . r)))
       (go (rev fs) @ 'bad 'bad r (rev r)))
   ; an indirect call through a park its sibcall jumps by: x64's r11, caller-saved and no arg's
   (locr g r) ((x64? g ? 'r10 (pkr g)) @ p [['mov p r] ['callr p]])
   ; an aggregate the SysV rules carry by value: classed in eightbytes, or the memory class
   (loagg? g ty) (stru? ty && 0 < tsz g ty && asalign g ty <= 8)
   ; the args to their registers in order, each file its own count; an aggregate's eightbytes take
   ; registers only all together, else it goes whole to the block -> [nf rg sk pre]: rg [reg vreg]..,
   ; sk ['w v 8] | ['s v bytes].., pre the eightbyte loads
   (loplace g vs)
    (foldl (s \ v \ (s @ [gi fi rg sk pre]
              (: ty (vty v) x (vreg v)
                 (? (pair? g ty)
                     (aup gi 2 @ ge
                        (ge + 2 <= ngp g ? [(ge + 2) fi (rg + [[(argr g ge) <x] [(argr g (ge + 1)) <>x]]) sk pre]
                           [(ngp g) fi rg (sk + [['w2 v 8]]) pre]))
                    (d128? ty)
                     ; AAPCS64: an even pair, and none left closes the file; riscv splits one over the last register
                     ((a64? g ? (gi + gi % 2) gi) @ j
                        (? (j + 2 <= ngp g) [(j + 2) fi (rg + [[(argr g j) <x] [(argr g (j + 1)) <>x]]) sk pre]
                           (rv64? g && j + 1 = ngp g) [(ngp g) fi (rg + [[(argr g j) <x]]) (sk + [['w ['long <>x ()] 8]]) pre]
                           [(a64? g ? (ngp g) gi) fi rg (sk + [['w2 v 16]]) pre]))
                    (stru? ty)
                     (lopcs g ty @
                        ; AAPCS64 past 16 bytes: a copy of the caller's, its address the arg
                        'ref (ntmp g ty @ off (lomk g @ p
                                (: cp (loesc g 'r4, locopya g x 'r4 off (tsz g ty) (tal g (vty v)) + [['lea p 'r4 off]])
                                   (gi < ngp g ? [(gi + 1) fi (rg + [[(argr g gi) p]]) sk (pre + cp)]
                                      [gi fi rg (sk + [['w ['long p ()] 8]]) (pre + cp)]))))
                        pcs (: ng #(filter (p \ <p = 'int) pcs) nx (#pcs - ng)
                               (? (two? pcs && gi + ng <= ngp g && fi + nx <= 8)
                                  (foldl (t \ p \ (t @ [gi fi rg sk pre]
                                            (p @ [c o n] (loeba g c x o n (tal g (vty v)) @ [w fs]
                                               (c = 'sse ? [gi (fi + 1) (rg + [[(xmmreg fi) w]]) sk (pre + fs)]
                                                  [(gi + 1) fi (rg + [[(argr g gi) w]]) sk (pre + fs)])))))
                                         [gi fi rg sk pre] pcs)
                                  ; riscv splits a gp pair over the last register and the stack
                                  (rv64? g && nx = 0 && ng = 2 && gi + 1 = ngp g)
                                   (loeb g 'int x 0 8 @ [w0 f0]
                                      (loeb g 'int x 8 ((pcs 1) 2) @ [w1 f1]
                                         [(ngp g) fi (rg + [[(argr g gi) w0]]) (sk + [['w ['long w1 ()] 8]]) (pre + f0 + f1)]))
                                  ; whole to the block; AAPCS64 then closes the file it wanted
                                  [(a64? g && 0 < ng ? ngp g gi) (a64? g && 0 < nx ? 8 fi) rg (sk + [['s v (8 * aslots g ty)]]) pre])))
                    (lofr? x) (fi < 8 ? [gi (fi + 1) (rg + [[(xmmreg fi) x]]) sk pre] [gi fi rg (sk + [['w v 8]]) pre])
                    (gi < ngp g) [(gi + 1) fi (rg + [[(argr g gi) x]]) sk pre]
                    [gi fi rg (sk + [['w v (wsize g)]]) pre]))))
           [0 0 () () ()] vs)
   ; -- AAPCS32's places: a float its lowest free s slot, a double the lowest free d, an HFA its run,
   ; and past a miss the float file is full; a word the next register, a pair or 8-aligned composite an
   ; even one, closing the file behind what goes to the stack, a composite split at r3 while the stack
   ; is empty. a variadic's floats ride the words. -> ['f slot n base] | ['r reg words] | ['x reg regs words] | ['m off] --
   (lo32words g ty) (? (stru? ty) ((aup (tsz g ty) 4) // 4) (d128? ty) 4 (ty = 'double || pair? g ty) 2 1)
   (lo32al8 g ty) (? (ia32? g) () (rv32? g) (8 <= tal g ty) (stru? ty) (8 <= asalign g ty) (2 <= lo32words g ty))
   ; cdecl: words up the stack; -mregparm's run eax edx ecx, a whole value or none, a variadic none
   (lo386cl g ts va)
    (: (go l gi ov acc)
        (l @ () (rev acc)
             (ty . u)
              (: nw (lo32words g ty)
                 ; a float or a complex spends no register
                 (? (!va && !(lofl? ty || gcplx? ty) && gi + nw <= ngp g) (go u (gi + nw) ov (['r gi nw] . acc))
                    (go u (lofl? ty || gcplx? ty ? gi (ngp g)) (ov + 4 * nw) (['m ov] . acc)))))
       (go ts 0 0 ()))
   (lo32cl g ts va)
    (ia32? g ? (lo386cl g ts va)
    (: (word u ty gi m ov acc)
        ; riscv pairs registers evenly only for a variadic, and splits any value over a7 and the stack
        (: nw (lo32words g ty) ge (lo32al8 g ty && (va || !(rv32? g)) ? (aup gi 2) gi)
           (? (ge + nw <= ngp g) (go u (ge + nw) m ov (['r ge nw] . acc))
              (ge < ngp g && ov = 0 && !(xt? g) && (stru? ty || rv32? g)) (go u (ngp g) m (4 * (ge + nw - ngp g)) (['x ge (ngp g - ge) nw] . acc))
              ((lo32al8 g ty ? (aup ov 8) ov) @ o (go u (ngp g) m (o + 4 * nw) (['m o] . acc)))))
       (go l gi m ov acc)
        (l @ () (rev acc)
             (ty . u)
              (: hb (!va && t32f? g && stru? ty && t32hfa? g ty ? (hfab g ty))
                 (? (hb || !va && t32f? g && lofl? ty)
                     (: b (hb || ty) w (tsz g b) n (hb ? (tsz g ty // w) 1) sl (w // 4 * n)
                        ((w = 8 ? (vfpn m sl 2) (vfpn m sl 1)) @ k
                           (0 <= k ? (go u gi (vfpm m k sl) ov (['f k n b] . acc))
                              ((w = 8 ? (aup ov 8) ov) @ o (go u gi vfpx (o + w * n) (['m o] . acc))))))
                    (word u ty gi m ov acc))))
       ; riscv carries an aggregate past 8 bytes by its copy's address, placed as a pointer
       (rvref? t) (rv32? g && stru? t && 8 < tsz g t)
       ((go (map (t \ rvref? t ? '(ptr void) t) ts) 0 0 0 ()) @ cs (map (i \ rvref? (ts i) ? ['ref (cs i)] (cs i)) ^#cs))))
   ; a slot's register, and a slot read into a float vreg: an odd one has no name and bounces off r12
   (lo32sn k) (xmmreg (k // 2))
   ; ..on thumb2sp every slot is a register: an odd one f(16+k/2), a single read by its own copy
   (lo32s1 k) (0 = k & 1 ? (lo32sn k) (name "f\(16 + k // 2)"))
   (lo32rd g k d ty) (? (sp64? g && ty = 'float) [['movss d (lo32s1 k)]]
                        (0 = k & 1) [['movapd d (lo32sn k)]]
                        [['movsnrx 'r12 k] ['cuse (lo32sn k)] ['movdxr d 'r12]])
   ; a call's places -> loplace's [gi fi rg sk pre], an odd slot's rg entry ['s k vreg] last
   (lo32place g vs va)
    (: ps (lo32cl g (map vty vs) va)
       (word x i n) (loeb g 'int x (4 * i) (min 4 n))
       (regs r x base nw sz rg pre)
        (foldl (s \ i \ (s @ [rg2 p2] (word x i (sz - 4 * i) @ [w f] [(rg2 + [[(argr g (r + i - base)) w]]) (p2 + f)]))) [rg pre] (map (+ base) ^nw))
       (one s v p)
        (s @ [rg sk pre]
           (: ty (vty v) x (vreg v)
              (p @ ['ref c]
                    (ntmp g ty @ off (lomk g @ q
                       (: cp (loesc g 'r4, locopya g x 'r4 off (tsz g ty) (tal g ty) + [['lea q 'r4 off]])
                          (one [rg sk (pre + cp)] ['(ptr void) q ()] c))))
                   (['f k 1 _] && stru? ty)
                     (loeb g 'sse x 0 (tsz g ty) @ [w f]
                        [(rg + [[(0 = k & 1 ? (lo32sn k) ['s k]) w]]) sk (pre + f)])
                   (['f k n b] && stru? ty)
                    (: e (tsz g b)
                       (foldl (t \ i \ (t @ [rg2 p2]
                                 (loeb g 'sse x (e * i) e @ [w f]
                                    (: kk (k + (e = 8 ? (2 * i) i))
                                       [(rg2 + [[(0 = kk & 1 ? (lo32sn kk) ['s kk]) w]]) (p2 + f)]))))
                              [rg pre] ^n @ [rg2 p2] [rg2 sk p2]))
                   ['f k _ _] [(rg + [[(? (0 = k & 1) (lo32sn k) (sp64? g) (lo32s1 k) ['s k]) x]]) sk pre]
                   ['r i nw]
                    (? (stru? ty) (regs i x 0 nw (tsz g ty) rg pre @ [rg2 p2] [rg2 sk p2])
                       (pair? g ty) [(rg + [[(argr g i) <x] [(argr g (i + 1)) <>x]]) sk pre]
                       (d128? ty) [(rg + map (j \ [(argr g (i + j)) (x j)]) ^4) sk pre]
                       (ty = 'double) (lomk g @ l (lomk g @ h [(rg + [[(argr g i) l] [(argr g (i + 1)) h]]) sk (pre + [['movrrq l h x]])]))
                       (ty = 'float) (lomk g @ l [(rg + [[(argr g i) l]]) sk (pre + [['movdrx l x]])])
                       [(rg + [[(argr g i) x]]) sk pre])
                   (['x i _ _] && !(stru? ty))
                    (? (pair? g ty) [(rg + [[(argr g i) <x]]) (sk + [['at ['int <>x ()] 4 0]]) pre]
                       (lomk g @ l (lomk g @ h [(rg + [[(argr g i) l]]) (sk + [['at ['int h ()] 4 0]]) (pre + [['movrrq l h x]])])))
                   ['x i rn nw]
                    (lomk g @ t
                       (regs i x 0 rn (tsz g ty) rg pre @ [rg2 p2]
                          [rg2 (sk + [['at [ty t ()] (tsz g ty - 4 * rn) 0]]) (p2 + [['lea t x (4 * rn)]])]))
                   ['m o] [rg (sk + [['at v (stru? ty ? (tsz g ty) (4 * lo32words g ty)) o]]) pre]
                   _ [rg sk pre])))
       ((foldl (s \ i \ one s (vs i) (ps i)) [() () ()] ^#vs) @ [rg sk pre]
          [0 0 (filter (p \ !(two? <p)) rg + filter (p \ two? <p) rg) sk pre]))
   ; a copy into an argument's register, and the register a call reads for it
   (lorgmv p) (p @ [['s k] x] [['movdrx 'r12 x] ['movsnxr k 'r12]] _ [(lomv <p <>p)])
   (lorgnm p) (p @ [['s k] _] (lo32sn k) _ <p)
   ; a fn's params -> [gi fi ov forms env]: a variadic's all in place above the link, r0-r3 pushed there
   (lo32par g params va sret vz sr)
    (: ps (lo32cl g ((sret ? ['(ptr void)]) + map (p \ <>p) params) va) ps2 (sret ? >ps ps)
       sk4 (sret && ia32? g && !(srreg? g va))
       (one s p loc)
        (s @ [odd acc post env]
           (: nm <p ty <>p
              (loc @ ['ref ['r i _]]
                      (va ? [odd acc post ([nm 'p (ovb g + 4 * i) ty] . env)]
                         (nslot g 4 @ po [odd (acc + [['st 'r4 po (argr g i)]]) post ([nm 'p po ty] . env)]))
                     ['ref ['m o]] [odd acc post ([nm 'p (ovb g + (va ? 32 0) + o) ty] . env)]
                     ['m o] [odd acc post ([nm 'm (ovb g + (va && t32? g ? 16 0) + (va && w32s? g ? 32 0) + o) ty] . env)]
                     (['r i _] && va) [odd acc post ([nm 'm (ovb g + vab g + 4 * i) ty] . env)]
                     (['x i _ _] && va) [odd acc post ([nm 'm (ovb g + vab g + 4 * i) ty] . env)]
                     ['r i nw]
                      (? (stru? ty || d128? ty || lotk? g nm)
                          (ntmp g ty @ off
                             [odd (acc + map (j \ ['st 'r4 (off + 4 * j) (argr g (i + j))]) ^nw) post ([nm 'm off ty] . env)])
                         (lomkv g ty @ r
                            [odd (acc + (? (two? r) [['mov <r (argr g i)] ['mov <>r (argr g (i + 1))]]
                                       (ty = 'double) [['movqrr r (argr g i) (argr g (i + 1))]]
                                       (ty = 'float) [['movdxr r (argr g i)]]
                                       [['mov r (argr g i)]]))
                             (post + (two? r ? () (cvt ty r))) ([nm 'v r ty] . env)]))
                     ['x i rn nw]
                      (ntmp g ty @ off (lomk g @ t
                         [odd (acc + map (j \ ['st 'r4 (off + 4 * j) (argr g (i + j))]) ^rn)
                          (post + catmap (j \ [['ld t 'r4 (ovb g + 4 * j)] ['st 'r4 (off + 4 * (rn + j)) t]]) ^(nw - rn))
                          ([nm 'm off ty] . env)]))
                     ['f k 1 _]
                      (? (stru? ty || lotk? g nm)
                          (ntmp g ty @ off
                             (0 = k & 1 ? [odd (acc + [[(ty = 'double || tsz g ty = 8 ? 'stsd 'stss) 'r4 off (lo32sn k)]]) post ([nm 'm off ty] . env)]
                                [(odd + vfpsv k 'r4 off) acc post ([nm 'm off ty] . env)]))
                         (lomkf g @ r
                            (0 = k & 1 ? [odd (acc + lo32rd g k r ty) post ([nm 'v r ty] . env)]
                               [(odd + lo32rd g k r ty) acc post ([nm 'v r ty] . env)])))
                     ['f k n b]
                      (ntmp g ty @ off
                         (: e (tsz g b)
                            [(odd + catmap (i \ (e = 4 && (k + i) & 1 ? (vfpsv (k + i) 'r4 (off + 4 * i)) ())) ^n)
                             (acc + catmap (i \ (e = 8 ? [['stsd 'r4 (off + 8 * i) (lo32sn (k + 2 * i))]]
                                                    (0 = (k + i) & 1 ? (vfpsv (k + i) 'r4 (off + 4 * i)) ()))) ^n)
                             post ([nm 'm off ty] . env)]))
                     s)))
       ; where a va_start begins: the next register, else past the named stack
       (end a i) (a @ [gi ov] ((ps2 i) @ ['r j n] [(j + n) ov]
                                         ['x _ rn nw] [(ngp g) (4 * (nw - rn))]
                                         ['m o] [(ngp g) (o + 4 * lo32words g (<>(params i)))]
                                         ['ref ['r j _]] [(j + 1) ov]
                                         ['ref ['m o]] [(ngp g) (o + 4)]
                                         _ a))
       ((foldl (s \ i \ one s (params i) (ps2 i)) [() (sret ? (sk4 ? [['ld sr 'r4 (ovb g)]] [['mov sr 'r0]])) vz ()] ^#params) @ [odd acc post env]
          ((foldl end [(sret ? 1 0) (sk4 ? 4 0)] ^#params) @ [gi ov]
             [gi 0 ov (odd + acc + post) env])))
   ; a variadic's next word: the cursor over the pushed registers and the caller's block
   (lo32vaarg g p fs ty)
    (lomk g @ a (lomk g @ n
       (: sz (4 * lo32words g ty)
          af (fs + [['ld a p 0]] + (lo32al8 g ty ? (lomk g @ k [['add a a 7] ['li k -8] ['and a a k]]) ()) +
              [['mov n a] ['add n n sz] ['st p 0 n]])
          (? (stru? ty) [ty a af]
             (pair? g ty) (lomk g @ l (lomk g @ h [ty [l h] (af + [['ld l a 0] ['ld h a 4]])]))
             (lofl? ty) (lomkf g @ d [ty d (af + [['ldsd d a 0]])])
             (lomk g @ d [ty d (af + [[(ldop ty) d a 0]])])))))
   ; eightbyte n bytes at a+off into a fresh vreg of class c -> [vreg forms]: exact widths, the
   ; odd ones by the old chunk arm
   (loeb g c a off n)
    (? (c = 'sse) (lomkf g @ w [w [[(n <= 4 ? 'ldss 'ldsd) w a off]]])
       (lomk g @ t [t (n @ 8 [['ld t a off]] 4 [['ldu4 t a off]] 2 [['ldu2 t a off]] 1 [['ldu1 t a off]]
                         _ (loren2 g () 'r2 'long (ldal 'r2 a off n 8) @ [_ y fs] (fs + [['mov t y]])))]))
   ; ..no wider than al where -mstrict-align holds it, a float's bits through a word
   (loeba g c a off n al)
    (? !(sal? g && al < salk g n) (loeb g c a off n)
       (c = 'sse) (loga g a off n al @ [_ t fs] (lomkf g @ w [w (fs + [[(n <= 4 ? 'movdxr 'movqxr) w t]])]))
       (loga g a off n al @ [_ t fs] [t fs]))
   ; an aggregate's register pieces [class offset bytes].. : SysV's eightbytes; AAPCS64's HFA one
   ; float register a member, else one gp register an eightbyte to 16 bytes. 'ref when its address
   ; rides instead (AAPCS64 past 16), () in memory (SysV's class)
   (lopcs g ty)
    (: sz (tsz g ty)
       (? (ia32? g) (cxf32? g ty ? [['int 0 4] ['int 4 4]])   ; a float complex answers on edx:eax
          (t32? g)
           (? (t32f? g && t32hfa? g ty) (tsz g (hfab g ty) @ w (map (k \ ['sse (w * k) w]) ^(sz // w)))
              (sz <= 4) [['int 0 sz]]
              ())
          (a64? g)
           (? (hfab g ty @ b (flo? b && sz <= 4 * tsz g b)) (tsz g (hfab g ty) @ w (map (k \ ['sse (w * k) w]) ^(sz // w)))
              (16 < sz) 'ref
              (map (k \ ['int (8 * k) (min 8 (sz - 8 * k))]) ^(aslots g ty)))
          ; riscv: SysV's eightbytes to 16 bytes, by reference past them; ilp32's words to 8
          (w32s? g) (? (8 < sz) 'ref (sz <= 4) [['int 0 sz]] [['int 0 4] ['int 4 (sz - 4)]])
          (rv64? g && 16 < sz) 'ref
          (aclass g ty @ () () cls (map (i \ [(cls i) (8 * i) (min 8 (sz - 8 * i))]) ^#cls))))
   ; a return in memory: SysV's memory class, AAPCS64's by-reference size
   (losr? g ty) (stru? ty && (lopcs g ty @ 'ref 1 () 1 _ ()))
   ; the return registers of pieces pcs: ints rax then rdx (x0 then x1 on a64, a0 a1 on riscv), floats from f0
   (lorregs g pcs)
    (t32? g && two? pcs && <<pcs = 'sse && <pcs 2 = 4
     ; t32's float HFA: its s slots, an odd one with no name of its own
     ? (map (k \ (0 = k & 1 ? (lo32sn k) ['s k])) ^#pcs)
     (foldl (s \ p \ (s @ [gs xs acc] (<p = 'sse ? [gs (>xs) (acc + [<xs])] [(>gs) xs (acc + [<gs])])))
           [(a8? g || w32s? g ? '(r0 r1) '(r0 r2)) '(f0 f1 f2 f3) ()] pcs @ [_ _ rs] rs))
   ; a piece stored from register r at b+off, as wide as its class reads
   (lopst p b off r) (p @ [c o n] [(c = 'sse ? (n = 4 ? 'stss 'stsd) 'st) b (off + o) r])
   ; ..the return registers stored whole into the 8-aligned temp at b+off
   (loebst g pcs b off)
    (lorregs g pcs @ rs (catmap (i \ (rs i @ ['s k] (vfpsv k b (off + (pcs i) 1)) r [(lopst (pcs i) b off r)])) ^#pcs))

   ; AAPCS64's va_list {__stack, __gr_top, __vr_top, __gr_offs, __vr_offs}: a scalar from its file's
   ; saves while the offs is negative, else from __stack
   (lovaarg64 g p fs ty)
    (: lov (nlab g ".vo") ld (nlab g ".vd")
       fl (lofl? ty) foff (fl ? 28 24) toff (fl ? 16 8) step (fl ? 16 8)
       walk [['ld4 'r1 'r0 foff] '(cmp r1 0) ['br 'ge lov] ['ld 'r2 'r0 toff] '(add r2 r2 r1)
             ['add 'r1 'r1 step] ['st4 'r0 foff 'r1] ['jmp ld] ['label lov]
             '(ld r2 r0 0) '(mov r3 r2) '(add r3 r3 8) '(st r0 0 r3) ['label ld]]
       ; a gp composite: whole, from the save area while it fits, else the stack, closing the file;
       ; past 16 bytes a slot holding its copy's address
       (? (refm? g ty) (loren2 g [['r0 p]] 'r2 'long walk @ [_ a f2]
                          (lomk g @ d [ty d (fs + f2 + [['ld d a 0]])]))
          (stru? ty && asalign g ty <= 8 && !(hfab g ty @ b (flo? b)))
           (: n8 (8 * aslots g ty)
              (loren2 g [['r0 p]] 'r2 'long
                 [['ld4 'r1 'r0 24] '(cmp r1 0) ['br 'ge lov] '(mov r3 r1) ['add 'r3 'r3 n8] ['st4 'r0 24 'r3]
                  '(cmp r3 1) ['br 'ge lov] '(ld r2 r0 8) '(add r2 r2 r1) ['jmp ld] ['label lov]
                  '(ld r2 r0 0) '(mov r3 r2) ['add 'r3 'r3 n8] '(st r0 0 r3) ['label ld]]
               @ [_ a f2] [ty a (fs + f2)]))
          (ty = 'float || !(losv? ty)) (lono g ['vaarg ty])
          (loren2 g [['r0 p]] 'r2 'long walk @ [_ a f2]
             (lomkt g ty @ d [ty d (fs + f2 + [(fl ? ['ldsd d a 0] [(ldop ty) d a 0])])]))))

   ; riscv's va_list is a cursor over 8-byte slots, doubles riding gp ones and a gp composite
   ; whole slots, its value their address
   (lovaargrv g p fs ty)
    (: (at n8) (loren2 g [['r0 p]] 'r2 'long ['(ld r2 r0 0) '(mov r3 r2) ['add 'r3 'r3 n8] '(st r0 0 r3)] @ [_ a f2] [a (fs + f2)])
       (? (stru? ty && asalign g ty <= 8 && (aone g ty = 'int || ipair? g ty)) (at (8 * aslots g ty) @ [a f2] [ty a f2])
          (ty = 'float || !(losv? ty)) (lono g ['vaarg ty])
          (at 8 @ [a f2] (lomkt g ty @ d [ty d (f2 + [(lofl? ty ? ['ldsd d a 0] [(ldop ty) d a 0])])]))))

   (lodl g pfx l f) (peep g 'dln 0 @ k (pin g 'dln (k + 1), name "\(pfx).\(k):\(l):\(f || "")"))
   ; -- statements -> forms | 'bad --
   (lost1 g env s)
    (: ; an arm that lays code and opens with no mark takes one of the statement around it, so code moved out of line keeps a row
       (st x e2 _) (lost1 g e2 x @ 'bad 'bad
                      fs (g 'dlcur @ [f l] (two? x && !(x @ ('blk (('loc . _) . _)) 1 _ 0) && any (y \ <y != 'label) fs ? ([['label (lodl g ".dl" l f)]] + fs) fs) _ fs))
       (br x s L _) (lobr g env x s L)
       (s @ () ()
            ((_ . _) . _) (loitems g env s)
            ('nop . _) ()
            ; -g's line mark: a label named for it, one per copy, read off the laid lanes (obj.l o-dwarf);
            ; its own counter, so the other labels number as under -g0
            ['loc f l] (pin g 'dlcur [f l], [['label (lodl g ".dl" l f)]])
            ['loc f l _] (pin g 'dlcur [f l], [['label (lodl g ".dlf" l f)]])   ; a body's `{`
            ('tdef . _) ()
            ; the canary at fp-16, the frame keeps its cell; the blob puts back what it borrows
            ('ssp k) [['fix () () (sspblob g k)]]
            ['expr e] (lox g env e @ [_ _ fs] fs 'bad)
            ['ret] (peep g 'epi epi)
            ; clay's (ret e PRE), a musttail: its call marked for the sibcall that must jump it
            ['ret e _] (lost1 g env ['ret e] @ 'bad 'bad fs (lomust g fs))
            ['ret e]
             (: rt <(peep (g 'sigs) (g 'fn) ['long ()]) epj (peep g 'epi epi)
                (lox g env (losv? rt && d128? (lopeek g env e) || gcplx? rt ? ['cast rt e] e) @ 'bad 'bad
                   ([_ _ fs] && rt = 'void) (fs + epj)
                   ; an int's upper half is the caller's to extend; lp64 has it leave sign-extended, unsigned too
                   ([vt r fs] && pair? g rt && losv? vt)
                    (lotr g [vt r fs] rt @ [_ [l h] f2] (f2 + [['mov 'r0 l] ['mov (ia32? g ? 'r2 'r1) h]] + epj))
                   ([vt r fs] && lofl? rt && losv? vt && soft? g)
                    (lotr g [vt r fs] rt @ [_ c f2] (f2 + [(rt = 'float ? ['movdrx 'r0 c] ['movrrq 'r0 'r1 c])] + epj))
                   ([vt r fs] && losv? rt && losv? vt)
                    (lotr g [vt r fs] (elem rt '(int uint) && losc? vt ? (g 'tgt = 'rv64 ? 'int 'long) rt) @ [_ c f2] (f2 + [(lomv (lofl? rt ? 'f0 'r0) c)]
                                                                                                               + (ia32? g && lofl? rt ? [['fix '(f0) lokl [['raw (x87raw g (rt = 'float) ())]]]])
                                                                                                               + epj))
                   ([vt r fs] && d128? rt && (losv? vt || d128? vt))
                    (lotr g [vt r fs] rt @ [_ ws f2] (f2 + lowmv (lowabi g) ws + epj) _ 'bad)
                   ; an aggregate: out through the hidden pointer, or its eightbytes into the return registers
                   ([vt r fs] && stru? rt && tsz g vt = tsz g rt)
                    (g 'losret @ () (: pcs (lopcs g rt) rs (lorregs g pcs)
                                       (foldl (t \ p \ (t @ [acc ws]
                                                 (p @ [c o n] (loeba g c r o n (tal g vt) @ [w f2] [(acc + f2) (ws + [w])]))))
                                              [fs ()] pcs @
                                        [f2 ws] (f2 + catmap (i \ lorgmv [(rs i) (ws i)]) ^#pcs + epj)))
                                 h (fs + locopya g r h 0 (tsz g rt) (tal g vt) + [['mov 'r0 h]] + epj))
                   'bad))
            ['blk items] (loitems g env items)
            ['if c t]
             (nlab g ".lo" @ le (lohint g t le, loseq [(br c 0 le) (st t env) (lol [['label le]])]))
            ['if c t el]
             (nlab g ".lo" @ le (nlab g ".lo" @ ld
                (lohint g t le, loseq [(br c 0 le) (st t env) (lol [['jmp ld] ['label le]]) (st el env) (lol [['label ld]])])))
            ; a loop tests at its bottom, entered by a jump to the test
            ['while c body]
             (nlab g ".lo" @ lc (nlab g ".lo" @ lb (nlab g ".lo" @ lt
                (loseq [(lol [['jmp lc] ['label lt]]) (st body (['brk lb] . ['cont lc] . env)) (lol [['label lc]])
                        (br c 1 lt) (lol [['label lb]])]))))
            ['do body c]
             (nlab g ".lo" @ lt (nlab g ".lo" @ lc (nlab g ".lo" @ lb
                (loseq [(lol [['label lt]]) (st body (['brk lb] . ['cont lc] . env)) (lol [['label lc]]) (br c 1 lt) (lol [['label lb]])]))))
            ['for init c stp body]
             (nlab g ".lo" @ lt (nlab g ".lo" @ lc (nlab g ".lo" @ lb (nlab g ".lo" @ lq
                ((init @ () [() env]
                         ['decl ps] (lodecl g env ps)
                         [_ x] (lox g env x @ [_ _ fs] [fs env] 'bad)
                         'bad) @
                 [fi e1]
                  (loseq [(lol (fi + (c @ () () _ [['jmp lq]]) + [['label lt]]))
                          (st body (['brk lb] . ['cont lc] . e1)) (lol [['label lc]])
                          (u \ (stp @ () () _ (lox g e1 stp @ [_ _ fs] fs 'bad)))
                          (u \ (c @ () [['jmp lt] ['label lb]]
                                   _ (lobr g e1 c 1 lt @ 'bad 'bad fs ([['label lq]] + fs + [['label lb]]))))])
                  'bad)))))
            ('brk . _) (assoc 'brk env @ [_ L] [['jmp L]] 'bad)
            ('cont . _) (assoc 'cont env @ [_ L] [['jmp L]] 'bad)
            ['goto nm] [['jmp (name "\(g 'fn).\(nm)")]]
            ; goto *e: a table jump over every label whose address the fn takes
            ['igoto e]
             (map (nm \ name "\(g 'fn).\(nm)") (g 'ltaken) @
                () (lono g 'igoto)
                ls (lox g env e @ [_ r fs] (fs + [['jmpt r <ls ls]]) 'bad))
            ['lbl nm] [['label (name "\(g 'fn).\(nm)")]]
            ['switch ce body] (loswitch g env ce body)
            ['case lo hi] (assoc 'sw env @ [_ tab _] (tab "\(lo):\(hi)" @ () 'bad L [['label L]]) 'bad)
            ['case cv] (assoc 'sw env @ [_ tab ty] (tab (lokey g ty cv) @ () 'bad L [['label L]]) 'bad)
            ('dflt . _) (assoc 'sw env @ [_ tab _] (tab 'dflt @ () 'bad L [['label L]]) 'bad)
            ('asm . _) (trap (loasm g env) s (a \ b \ (a = 'leave ? (scare a b) (lono g ['asm a]))))
            (lono g ['stmt <s])))
   ; an asm, its operands seated as asmplan seats them: the values moved to their registers, the body
   ; one fix form reading the inputs' and writing the outputs' and the clobbers', the outputs stored
   ; a narrow integer out of a register asm leaves: its own width, the bits above it unsaid
   (lonar g ty t)
    (!(charm? (tsz g ty)) || lofl? ty || ty = 'bool ? () (cvt ty t))
   (loasm g env s)
    (asmplan g env s @
       'bad (lono g ['asm (g 'nolane)])
       [ops asgn kills saves _ labs tls txt neutral? _]
       (: tgt (gtgt g)
          (in? o) (elem <o '(x i b))
          (out? o) (elem <o '(o x f))
          (ld o a)
           (lox g env (o 2) @
              'bad 'bad
              ([vt _ _] && stru? vt) (lono g 'asmstruct)
              ; a thumb pair: the value's two halves
              (v && two? a) (lotr g v 'llong @ [_ [l h] fs] [fs [['mov <a l] ['mov <>a h]]] _ 'bad)
              ([_ r _] && two? r) (lono g 'asmwide)
              ; a float in a general register refuses
              ([_ r _] && lofr? r && !(freg? a)) (lono g 'asmfl)
              [vt r fs] [fs [(? (freg? a && lofr? r) ['movapd a r]
                                (freg? a) [(o 3 <= 4 ? 'movdxr 'movqxr) a r]
                                ['mov a r])]])
          (st o a)
           (lolv g env (o 2) @
              'bad 'bad
              ; a struct or union a register holds whole stores as the integer its size is
              (['a av ty off] && stru? ty && <o = 'o && !(freg? a) && elem (tsz g ty) [1 2 4 8])
               (st1 o a ['a av (tsz g ty @ 1 'uchar 2 'ushort 4 'uint _ 'ulong) off])
              lv (st1 o a lv))
          (st1 o a lv)
           (lv 2 @ ty
              (? (stru? ty || arr? ty || lofl? ty && !(freg? a) || !(two? a) != !(pair? g ty)) (lono g 'asmout)
                 (two? a) (lomk g @ l (lomk g @ h
                             [[['mov l <a] ['mov h <>a]] (lost g lv [ty [l h] ()] @ [fs _] fs 'bad) (lolvfs lv)]))
                 ; an xmm output into an integer lvalue: its bits
                 ((freg? a && lofl? ty ? (lomkf g) (lomk g)) @ t
                    [[(freg? a && !(lofl? ty) ? [(o 3 <= 4 ? 'movdrx 'movqrx) t a] (lomv t a))]
                     (lost g lv [ty t ()] @ [fs _] (freg? a ? fs (lonar g ty t + fs)) 'bad)
                     (lolvfs lv)])))
          ins (filter (i \ in? (ops i)) ^#ops)
          outs (filter (i \ out? (ops i)) ^#ops)
          lds (map (i \ ld (ops i) (asgn i)) ins)
          sts (map (i \ st (ops i) (asgn i)) outs)
          ; a goto's edges are not unframe's to see
          ab (asmbody g tgt neutral? txt)
          (flat l) (catmap (a \ two? a ? a [a]) l)
          ; a callee-saved output whose value dies leaves no mov behind: named here, csframe still saves it
          named (map (r \ ['li r 0]) (filter (r \ elem r (csregs g) && nelem r (flat (map asgn ins))) (flat (map asgn outs))))
          body (named + map (r \ ['push r]) saves + (two? labs ? ab (asmfsafe txt ab)) + map (r \ ['pop r]) (rev saves)
                + catmap (i \ (ops i @ ('f . _ . _ . _ . c . _) [['set c (asgn i)]] _ ())) outs)
          (any bad? lds || any bad? sts ? 'bad
             (: post (catmap cap sts + catmap (x \ x 1) sts)
                fx ['fix (flat (map asgn ins)) (flat (map asgn outs) + kills) body tls]
                ; an asm goto with outputs jumps to a trampoline per label that stores them and goes on
                ; an output's address is worked out before the inputs take their registers
                (catmap (x \ x 2) sts + catmap cap lds + catmap (x \ x 1) lds +
                 (tls = labs ? (fx . post)
                    (nlab g "\(g 'fn).ag" @ done
                       ([fx ['jmp done]] + catmap (i \ [['label (tls i)]] + post + [['jmp (labs i)]]) ^#tls +
                        [['label done]] + post))))))))
   ; a case value at the switch's width; a 32-bit pair keeps all 64 bits
   (lofit g ty v)
    (!(pair? g ty) ? (cfit g ty v)
       (u64 v @ u (usg? ty || u < 9223372036854775808 ? u (u - 18446744073709551616))))
   (lokey g ty cv) (cint? cv ? (lofit g ty cv) 'bad)
   ; a case table already holds a value in [l, h]: a key, or a wide range
   (locased tab l h)
    (any (k \ cint? k && l <= k <= h) (keys tab) ||
     any (r \ (r @ [a n _] (a <= h && l <= a + n))) (tab 'rng))
   ; a switch as a compare chain: its cases, nested switches aside, each take a label
   (loswitch g env ce body)
    (lox g env ce @ ([ty r fs] && losc? ty)
       (: tab {}
          (walk x) (x @ ('switch . _) 0
                        ; a repeated value or default refuses
                        ['case cv] (lokey g ty cv @ 'bad (pin tab 'bad 1) k (locased tab k k ? (pin tab 'bad 1) (pin tab k (nlab g ".lo"))))
                        ['case lo hi]
                         (? !(cint? lo && cint? hi && lo <= hi) (pin tab 'bad 1)
                            (locased tab (lofit g ty lo) (lofit g ty hi)) (pin tab 'bad 1)
                            ; a narrow range a label a value, a wide one a compare of its own
                            (nlab g ".lo" @ L
                               (pin tab "\(lo):\(hi)" L,
                                hi - lo < 64 ? (map (k \ pin tab (lofit g ty (lo + k)) L) ^(hi - lo + 1))
                                   (pin tab 'rng ([(lofit g ty lo) (hi - lo) L] . tab 'rng)))))
                        ('dflt . _) (tab 'dflt ? (pin tab 'bad 1) (pin tab 'dflt (nlab g ".lo")))
                        (_ . _) (map walk x)
                        0)
          _ (walk body)
          (tab 'bad ? (lono g 'case)
             (nlab g ".lo" @ lb
                (: ks (sort (filter cint? (keys tab)))
                   dl (peep tab 'dflt lb)
                   tst (two? r ? (lochainp g [ty r ()] tab ks) (lojt g r tab ks dl @ () (lochain g r tab ks) fs fs))
                   (lost1 g (['brk lb] . ['sw tab ty] . env) body @ 'bad 'bad
                      fb (fs + tst + [['jmp dl]] + fb + [['label lb]]))))))
       'bad)
   ; memset and memcpy of a small constant size, straight-line: not where
   ; a local shadows the name or the fn is the library's own -> the destination | 'no
   (lomem g env fh as)
    (fh @ (['var bi] && string? bi && 3 = #as && !(abl? g 'meminl) && !(two? (assoc bi env)) && g 'fn != bi)
           (memk g (as 2) @ n
              (? !(charm? n && 0 <= n && n <= meminl g) 'no
                 (memnm? g bi "memset")
                  (memk g (as 1) @ c
                     (!(charm? c) ? 'no
                        (lox g env <as @ [ty d fd]
                           (lobase [ty d fd] @ [b o]
                              (lomk g @ v
                                 ['(ptr void) d (fd + [['li v ((c & 255) * (wsize g = 4 ? 16843009 72340172838076673))]] +
                                                 map ([p k] \ [(stw k) b (o + p) v]) (alchunks n (salk g (lomemal g env <as))))]))
                           'bad)))
                 (memnm? g bi "memcpy")
                  (lox g env <as @ [ty d fd]
                     (lox g env <>as @ sv
                        (vfs sv @ fs (lobase [ty d fd] @ [db do] (lobase sv @ [sb so]
                           (lomk g @ t
                              ['(ptr void) d (fd + fs + catmap ([p k] \ [[(uldop k) t sb (so + p)] [(stw k) db (do + p) t]])
                                                       (alchunks n (salk g (min (lomemal g env <as) (lomemal g env <>as)))))]))))
                        'bad)
                     'bad)
                 'no))
          _ 'no)
   ; a pointer as a base and offset: a local's address reads off the frame, its lea left to die
   ; where the value goes unused -> [base off]
   (lobase v) (v @ [_ t fs] (rev fs @ (['lea t2 'r4 o] . _) (t = t2 ? ['r4 o] [t 0]) _ [t 0]))
   ; what a mem builtin's pointer is known to align: under -mstrict-align a named object's own, else a byte
   (lomemal g env e)
    (!(sal? g) ? (wsize g)
       (e @ ['cast _ x] (lomemal g env x)
            ['addr ['var nm]] (lovar g env nm @ ['m _ ty] (tal g ty) ['g _ ty] (tal g ty) _ 1)
            1))
   ; a switch's compares: each key, then each wide range as r - lo unsigned at most the span
   (lochain g r tab ks)
    (catmap (k \ (imma g 'cmp k ? [['cmp r k] ['br 'eq (tab k)]] (lomk g @ t [['li t k] ['cmp r t] ['br 'eq (tab k)]]))) ks +
     catmap (x \ (x @ [lo n L] (lomk g @ t (lomk g @ k
                   ([['mov t r] ['li k lo] ['sub t t k]] + (imma g 'cmp n ? [['cmp t n]] [['li k n] ['cmp t k]]) + [['br 'be L]])))))
            (tab 'rng))
   ; ..over a 32-bit pair: the high halves first, a wide range its 64-bit difference
   (lochainp g v tab ks)
    (: (hl k) (u64 k @ u [(u % 4294967296) (u // 4294967296)])
       r (vreg v)
       (key k L) (hl k @ [a b] (nlab g ".lo" @ n (lomk g @ t
                    [['li t b] ['cmp <>r t] ['br 'ne n] ['li t a] ['cmp <r t] ['br 'eq L] ['label n]])))
       (catmap (k \ key k (tab k)) ks +
        catmap (x \ (x @ [lo n L]
                     (hl lo @ [a b] (lomk g @ p (lomk g @ q
                        (lobin g '- v [(vty v) [p q] [['li p a] ['li q b]]] () @ [_ [dl dh] fs]
                           (hl n @ [c d] (nlab g ".lo" @ e (lomk g @ t
                              (fs + [['li t d] ['cmp dh t] ['br 'below L] ['br 'above e] ['li t c] ['cmp dl t] ['br 'be L] ['label e]]))))
                         _ (lono g 'case, ())))))))
               (tab 'rng)))
   ; the table lane: six keys or more, a third full at least, no wide
   ; range, -fno-jump-tables off. rel32 cells off the table's label, one unsigned compare to the
   ; default -> forms | ()
   (lojt g r tab ks dl)
    (: n #ks lo (two? ks ? <ks 0) span (two? ks ? (ks (n - 1) - lo + 1) 0)
       (? (n < 6 || 4096 < span || span > 3 * n || two? (tab 'rng) || abl? g 'jtab || njt? g || ilp32? g || wasm? g || !(fits32 lo)) ()
          (nlab g ".J" @ tl (lomk g @ i (lomk g @ t
             (: labs (foldl (l \ k \ elem (tab k) l ? l (tab k . l)) [dl] ks)
                (pin g 'jtabs ([tl (catall (map (j \ [['fix 4 'rel32 (peep tab (lo + j) dl) 0]]) ^span))] . g 'jtabs),
                 [['mov i r]] + (lo = 0 ? () [['sub i i lo]]) +
                 [['cmp i (span - 1)] ['br 'above dl] ['la t tl] ['leax t t i 4 4] ['ld4 i t -4] ['add t t i] ['jmpt t tl labs]])))))))
   ; a block's items, decls threading the env -> forms | 'bad, and with the env it ends on
   (loitems g env items) (loitems2 g env items @ [fs _] fs 'bad)
   (loitems2 g env items)
    (: (go l env acc)
        (l @ (['decl ps] . u) (lodecl g env ps @ [fs e2] (go u e2 (acc + fs)) 'bad)
             (['sdecl ps] . u) (go u (losdecl g env ps) acc)
             (it . u) (lost1 g env it @ 'bad 'bad fs (go u env (acc + fs)))
             [acc env])
       (go items env ()))
   ; a VLA's block: the prior one this site laid given back (a loop runs the decl again), the bytes
   ; stashed, sp down by them rounded to 16, the block's address stashed. sp moves: no sibcall, no
   ; unframing
   (lovla g env ty po so)
    ; -mstack-alignment=8 holds no element that asks 16
    (? (x86k? g 'sa8 && 8 < tal g (varel ty)) (lono g 'vla)
    (lox g env (varn ty) @ ([nt r0 f0] && losc? nt)
       (lotr g [nt r0 f0] 'long @ [_ n fs]
          (lomk g @ t (lomk g @ q (lomk g @ z (nlab g ".vla" @ lf
             (: es (tsz g (varel ty)) (up r) [['add r r 15] ['shr r 4] ['shl r 4]]
                (pins g 'fesc 1 'hasasm 1,
                 [['ld t 'r4 so] ['cmp t 0] ['br 'eq lf]] + up t + [['ld q 'r4 po] ['add q q t] ['mov 'sp q] ['label lf]] +
                 fs + [['mov z n]] + (es = 1 ? () (lork g 'imul z es)) + [['st 'r4 so z]] + up z +
                 [['mov q 'sp] ['sub q q z] ['mov 'sp q] ['st 'r4 po q]] +
                 (avz? g ? (lovz g q z)))))))))
       'bad 'bad
       _ (lono g 'vla)))
   ; -ftrivial-auto-var-init=zero: z bytes at q word by word, from the top down, z spent
   (lovz g q z)
    (lomk g @ k (lomk g @ a (nlab g ".vla" @ l1 (nlab g ".vla" @ l2
       [['li k 0] ['label l1] ['cmp z 0] ['br 'eq l2] ['sub z z (wsize g)] ['mov a q] ['add a a z] ['st a 0 k]
        ['jmp l1] ['label l2]]))))
   ; statics: a data label each, laid after the fn, the initializer's names to earlier ones
   ; spelled by label now -> env
   (losdecl g env ps)
    (foldl (e2 \ p \
              (: nm <p ty <>p lbl (nlab g "\(g 'fn).")
                 (fix x) (? !(two? x) x
                            (<x == 'laddr) ['lsym "\(g 'fn).\(<>x)"]
                            (<x == 'var && string? <>x)
                             (? (<>x = nm) ['var lbl] (assoc <>x e2 @ [_ 'g l _] ['var l] x))
                            (map fix x))
                 (pin (g 'glob) lbl [lbl ty (fix <>>p)],
                  (4 < #p && 0 < p 4 ? (pin (g 'aligns) lbl (p 4))),
                  (5 < #p ? (pin (g 'sects) lbl (p 5))),
                  pin g 'statics (lbl . g 'statics),
                  [nm 'g lbl ty] . e2)))
           env ps)
   ; -> [forms env] | 'bad
   (lodecl g env ps)
    (: (go l env acc)
        (l @ ((nm . ty . rest) . u)
              (: init (rest @ (i . _) i ())
                 ; a register variable: a plain vreg, its register named for asmplan
                 ap (rest @ (_ . x . _) (string? x ? (gas-regname (gtgt g) x)) _ ())
                 (? (ap && !(nom? ap && asmreg? g ap && losv? ty && !(lotk? g nm))) (lono g 'regasm)
                    (gvarr? ty)
                     (? (init != () || gvarr? <>ty) (lono g 'vla)
                        (g 'vslots (varix ty) @
                           [po so] (lovla g env ty po so @ 'bad 'bad fs (go u ([nm 'p po ty] . env) (acc + fs)))
                           _ (lono g 'vla)))
                    (losv? ty && (init @ ('init . _) 1 ())) (lono g ['init ty])
                    ((losv? ty || lovw? g ty) && !(lotk? g nm))
                     (lomkv g ty @ r
                        (: _ (ap ? (pin (g 'lopins) r ap))
                           e2 ([nm 'v r ty] . env)
                           ; no init: a def that lays nothing, so the vreg lives from here; zero under
                           ; -ftrivial-auto-var-init=zero
                           (init @ () (go u e2 (acc + (? (two? r) (!(avz? g) ? [['cdef <r <>r]] [['li <r 0] ['li <>r 0]])
                                                           !(avz? g) [['cdef r]]
                                                           (lofl? ty) (lofz g r ty)
                                                           [['li r 0]])))
                                   _ (lox g env init @ 'bad 'bad
                                        v (lost g ['v r ty] v @ [fs _] (go u e2 (acc + fs)) 'bad)))))
                    ; a slot aligned to the type's ask or the decl's own, the record's fifth
                    (naslot g (aup (tsz g ty) 8) (max (tal g ty) (rest @ (_ . _ . a . _) (charm? a ? a 0) _ 0)) @ off
                       (: e2 ([nm 'm off ty] . env)
                          (? (init = ()) (go u e2 (acc + (avz? g ? (lozero g off (aup (tsz g ty) 8)))))
                             (losv? ty || d128? ty)
                              (lox g env init @ 'bad 'bad
                                 v (lost g ['a ['long 'r4 ()] ty off] v @ [fs _] (go u e2 (acc + fs)) 'bad))
                             ((init @ ('init . _) 1 ()) || arr? ty && (init @ ('str . _) 1 ()) || clarr? ty init)
                              (lofill g e2 off ty init @ 'bad 'bad fs (go u e2 (acc + lozfill g off (aup (tsz g ty) 8) fs)))
                             (stru? ty) (loelt g e2 off ty init @ 'bad 'bad fs (go u e2 (acc + fs)))
                             (lono g ['init ty]))))))
             [acc env])
       (go ps env ()))

   ; -- the fn: params home off their registers, then the body -> forms over vregs | 'bad --
   ; MOON_LOLOG=1 names each fn, and why it refused
   ; the t32 signatures this path takes yet
   (lot32sig g ts) (all (t \ t = 'void || losv? t || loagg? g t || d128? t && t32w? g) ts)
   (lofn g f params sig)
    ((pins g 'lopeek lopeek 'lovpin lovpin 'lopins {}, lofn1 g f params sig) @ r
       (pins g 'lopeek () 'lovpin (), getenv "MOON_LOLOG" @ () r _ (puts ";; lo \(<>f) \(bad? r ? "refused \(show (g 'lowhy))" "ok")\n", r)))
   (lofn1 g f params sig)
    (sig @ ((rt . _ . va . _) && (rt = 'void || losv? rt || d128? rt || loagg? g rt) && all (p \ losv? <>p || d128? <>p || loagg? g <>p) params &&
            !(g 'abad) &&
            ; past SysV and AAPCS64 a pair has no lane
            (lo128? g || !(d128? rt || any (p \ d128? <>p) params)) &&
            !(ilp32? g && !(lot32sig g (rt . map (p \ <>p) params))))
       ; a returned aggregate of the memory class: its address comes in rdi and goes back in rax
       (: sret (losr? g rt)
          _ (pin g 'lon 0)
          ; riscv's saves ride csframe here, so every exit restores at its marker
          _ (rv? g || xt? g || v6m? g ? (pin g 'epi ('((rests)) + peep g 'epi epi)))
          sr (sret ? (lomk g))
          _ (pins g 'lotk (lotaken (f 3) (map cap (filter lovq? (f 2)))) 'lowhy () 'losret sr
                  'loret (? (rt = 'void) () (lofl? rt) (soft? g ? (rt = 'float ? '(r0) '(r0 r1)) '(f0)) (d128? rt) (lowabi g) (pair? g rt) (ia32? g ? '(r0 r2) '(r0 r1)) (stru? rt && !sret) (filter (x \ !(two? x)) (lorregs g (lopcs g rt))) '(r0)))
          ; the params, each file's registers in order, the rest above the link at ovb step 8
          ; ..past the a0-a7 block a riscv variadic fn pushes
          ovo (ovb g + (va && rv64? g ? 64 0))
          (ovm ty ov) ['m (ovo + wsize g * ov) ty]
          ; the copies off the registers first, their conversions after (post)
          (go l gi fi ov env acc post)
           (l @ ((nm . ty . _) . u)
                 (? (pair? g ty)
                     ; even and odd registers, else 8-aligned above the link with the file closed
                     (aup gi 2 @ ge
                        (? (ngp g < ge + 2) ((aup ov 2) @ o (go u (ngp g) fi (o + 2) ((nm . ovm ty o) . env) acc post))
                           (lotk? g nm)
                            (ntmp g ty @ off (go u (ge + 2) fi ov ([nm 'm off ty] . env)
                                                 (acc + [['st 'r4 off (argr g ge)] ['st 'r4 (off + 4) (argr g (ge + 1))]]) post))
                           (lomkv g ty @ r (go u (ge + 2) fi ov ([nm 'v r ty] . env)
                                               (acc + [['mov <r (argr g ge)] ['mov <>r (argr g (ge + 1))]]) post))))
                    (d128? ty)
                     ; a pair: two gp registers, else 16-aligned above the link; AAPCS64's are even, riscv's may split
                     ((a64? g ? (gi + gi % 2) gi) @ j
                        (? (j + 2 <= ngp g)
                           (ntmp g ty @ off (go u (j + 2) fi ov ([nm 'm off ty] . env)
                                                (acc + [['st 'r4 off (argr g j)] ['st 'r4 (off + 8) (argr g (j + 1))]]) post))
                           (rv64? g && j + 1 = ngp g)
                           (ntmp g ty @ off (lomk g @ t (go u (ngp g) fi (ov + 1) ([nm 'm off ty] . env)
                                                (acc + [['st 'r4 off (argr g j)] ['ld t 'r4 (ovo + 8 * ov)] ['st 'r4 (off + 8) t]]) post)))
                           ((ov + ov % 2) @ o (go u (a64? g ? (ngp g) gi) fi (o + 2) ((nm . ovm ty o) . env) acc post))))
                    (stru? ty)
                     (lopcs g ty @
                        ; AAPCS64 past 16 bytes: the caller's copy, read through its address in a cell
                        'ref (gi < ngp g ?
                                (nslot g 8 @ po (go u (gi + 1) fi ov ([nm 'p po ty] . env) (acc + [['st 'r4 po (argr g gi)]]) post))
                                (go u gi fi (ov + 1) ([nm 'p (ovo + 8 * ov) ty] . env) acc post))
                        pcs (: ng #(filter (p \ <p = 'int) pcs) nx (#pcs - ng)
                               (two? pcs && gi + ng <= ngp g && fi + nx <= 8 ?
                                  (ntmp g ty @ off
                                     (foldl (t \ p \ (t @ [gi fi fs]
                                               (<p = 'sse ? [gi (fi + 1) (fs + [(lopst p 'r4 off (xmmreg fi))])]
                                                  [(gi + 1) fi (fs + [(lopst p 'r4 off (argr g gi))])])))
                                            [gi fi ()] pcs @
                                      [g2 f2 fs] (go u g2 f2 ov ([nm 'm off ty] . env) (acc + fs) post)))
                                  (? (rv64? g && nx = 0 && ng = 2 && gi + 1 = ngp g)
                                      ; riscv's split pair: the last register, then the first stack slot
                                      (ntmp g ty @ off (lomk g @ t
                                         (go u (ngp g) fi (ov + 1) ([nm 'm off ty] . env)
                                             (acc + [['st 'r4 off (argr g gi)] ['ld t 'r4 (ovo + 8 * ov)] ['st 'r4 (off + 8) t]]) post)))
                                     (go u (a64? g && 0 < ng ? ngp g gi) (a64? g && 0 < nx ? 8 fi) (ov + aslots g ty)
                                         ((nm . ovm ty ov) . env) acc post)))))
                    (lofl? ty ? (8 <= fi) (ngp g <= gi)) (go u gi fi (ov + 1) ((nm . ovm ty ov) . env) acc post)
                    (: fl (lofl? ty) A (fl ? (xmmreg fi) (argr g gi)) g2 (fl ? gi (gi + 1)) f2 (fl ? (fi + 1) fi)
                       (lotk? g nm ?
                          (ntmp g ty @ off
                             (go u g2 f2 ov ([nm 'm off ty] . env)
                                 ; a narrow store narrows on its own
                                 (acc + [[(fl ? (ty = 'float ? 'stss 'stsd) (stop ty)) 'r4 off A]]) post))
                          (lomkt g ty @ r (go u g2 f2 ov ([nm 'v r ty] . env) (acc + [(lomv r A)]) (post + (fl ? () (cvt ty r))))))))
                [gi fi ov (acc + post) env])
          ; each VLA site's size cell reads 0 until its decl runs
          vz (keys (g 'vslots) @ () () ks (lomk g @ z (['li z 0] . map (k \ ['st 'r4 (g 'vslots k 1) z]) (sort ks))))
          ((ilp32? g ? (lo32par g params va sret vz sr) (go params (sret && !(a64? g) ? 1 0) 0 0 () (sret ? [['mov sr (srreg g)]]) vz)) @ [gi fi ov pe env]
             (pins g 'vagp gi 'vaxmm fi 'vaov ov,
              (va ? (lovasave g)) @ vs
              (loitems g env (f 3 @ ['blk items] items x [x]) @ 'bad 'bad
                 body (lobuild g f (vs + pe + body + fz0 g <>f + peep g 'epi epi))))))
       (pin g 'lowhy ['fn (sig @ (rt . p . va . _) [rt va (map (x \ <>x) params)] 'nosig)
                           (g 'abad)], 'bad))

   ; a variadic fn: SysV's 176-byte save area, gp at +0 step 8, xmm at +48 step 16; AAPCS64's 192,
   ; x0-x7 then q0-q7 at +64
   (lovasave g)
    (rv64? g || ilp32? g ? (pin g 'fesc 1, ()) (: ng (ngp g) fb (8 * ng) n (fb + 128)
       (nslot g n @ rsa
         (pins g 'rsa rsa 'fesc 1,
           map (i \ ['st 'r4 (rsa + 8 * i) (argr g i)]) ^ng +
           (nofp? g ? () (map (i \ ['stsd 'r4 (rsa + fb + 16 * i) (xmmreg i)]) ^8))))))

   ; sp64's fpu has no double arithmetic: each op calls its helper, doubles in core pairs. a compare
   ; takes the branch or set behind it, where a parity dance folds to one answer
   (losoft g l)
    (: (ga x lo hi) ['movrrq lo hi x]
       a2 (x \ y \ [(ga x 'r0 'r1) (ga y 'r2 'r3) '(cuse r0 r1 r2 r3)])
       a1 (x \ [(ga x 'r0 'r1) '(cuse r0 r1)])
       (ansd d) ['movqrr d 'r0 'r1]
       (cc c tail9 u)
        (sf-cc c @ [h k] [['call h] '(cmp r0 0) (tail9 k)] _ (lono g ['softcc c], []))
       (fcc c tail9 u)
        (sf-cc c @ [h k] [['call (sf-ccs h)] '(cmp r0 0) (tail9 k)] _ (lono g ['softcc c], []))
       (go l)
        (!(two? l) ? l
           (: f <l r >l
              (f @ ([op d y] && soft? g && sf-bin1 op)
                    ([['movdrx 'r0 d] ['movdrx 'r1 y] '(cuse r0 r1) ['call (sf-bin1 op)] ['movdxr d 'r0]] + go r)
                   ([('cvtsi2ss || 'cvtui2ss) d x] && soft? g)
                    ([['mov 'r0 x] '(cuse r0) ['call (<f = 'cvtsi2ss ? '__aeabi_i2f '__aeabi_ui2f)] ['movdxr d 'r0]] + go r)
                   ([('cvttss2si || 'cvttss2ui) d x] && soft? g)
                    ([['movdrx 'r0 x] '(cuse r0) ['call (<f = 'cvttss2si ? '__aeabi_f2iz '__aeabi_f2uiz)] ['mov d 'r0]] + go r)
                   (['ucomiss a b] && soft? g)
                    ([['movdrx 'r0 a] ['movdrx 'r1 b] '(cuse r0 r1)]
                     + (r @ (['set 'eq _] . ['set 'np _] . ['mov d _] . ['and _ _ _] . u)
                              (fcc 'eq (k \ ['set k d]) u + go u)
                            (['set 'ne _] . ['set 'p _] . ['mov d _] . ['or _ _ _] . u)
                              (fcc 'ne (k \ ['set k d]) u + go u)
                            (['br c L] . u) (fcc c (k \ ['br k L]) u + go u)
                            (['set c d] . u) (fcc c (k \ ['set k d]) u + go u)
                            _ (lono g ['softcc (two? r ? <r)], [])))
                   ([op d y] && sf-bin op) (a2 d y + [['call (sf-bin op)] (ansd d)] + go r)
                   [('cvtsi2sd || 'cvtui2sd) d x]
                    ([['mov 'r0 x] '(cuse r0) ['call (<f = 'cvtsi2sd ? '__aeabi_i2d '__aeabi_ui2d)] (ansd d)] + go r)
                   [('cvttsd2si || 'cvttsd2ui) d x]
                    (a1 x + [['call (<f = 'cvttsd2si ? '__aeabi_d2iz '__aeabi_d2uiz)] ['mov d 'r0]] + go r)
                   ['cvtss2sd d x] ([['movdrx 'r0 x] '(cuse r0) '(call __aeabi_f2d) (ansd d)] + go r)
                   ['cvtsd2ss d x] (a1 x + ['(call __aeabi_d2f) ['movdxr d 'r0]] + go r)
                   ['ucomisd a b]
                    (a2 a b + (r @ (['set 'eq _] . ['set 'np _] . ['mov d _] . ['and _ _ _] . u)
                                   (cc 'eq (k \ ['set k d]) u + go u)
                                 (['set 'ne _] . ['set 'p _] . ['mov d _] . ['or _ _ _] . u)
                                   (cc 'ne (k \ ['set k d]) u + go u)
                                 (['br c L] . u) (cc c (k \ ['br k L]) u + go u)
                                 (['set c d] . u) (cc c (k \ ['set k d]) u + go u)
                                 _ (lono g ['softcc (two? r ? <r)], [])))
                   (f . go r))))
       (go l))

   ; v6-M has no float file: each %w splits into core vregs, its high half only where a double
   ; reaches it. every divide owns r0..r3 in holo
   (lov6 g fs)
    (: hi {} los {} his {}
       (dbl? f) (f @ ['ldsd d _ _] d ['movqrr d _ _] d ['stsd _ _ s] s ['movrrq _ _ s] s _ ())
       (mem t x) (peep t x () @ () (lomk g @ n (pin t x n, n)) n n)
       (l x) (mem los x) (h x) (mem his x)
       _ (map (f \ dbl? f @ () () d (pin hi d 1)) fs)
       (prop _) (foldl (c \ f \ (f @ ['movapd d s] (hi s && !(hi d) ? (pin hi d 1, c + 1) c) _ c)) 0 fs @ 0 0 _ (prop 0))
       _ (prop 0)
       (dv op d a b) [['mov 'r0 a] ['mov 'r1 b] ['fix '(r0 r1) '(r0 r1 r2 r3) [op]] ['mov d 'r0]]
       (sp f)
        (f @ ['movapd d s] ([['mov (l d) (l s)]] + (hi s ? [['mov (h d) (h s)]]))
             ['movss d s] [['mov (l d) (l s)]]
             ['ldsd d b o] [['ld (l d) b o] ['ld (h d) b (o + 4)]]
             ['ldss d b o] [['ld (l d) b o]]
             ['stsd b o s] [['st b o (l s)] ['st b (o + 4) (h s)]]
             ['stss b o s] [['st b o (l s)]]
             ['movqrr d a b] [['mov (l d) a] ['mov (h d) b]]
             ['movrrq a b s] [['mov a (l s)] ['mov b (h s)]]
             ['movdxr d r] [['mov (l d) r]]
             ['movdrx r s] [['mov r (l s)]]
             ([('div || 'udiv) d a b] && v6m? g) (dv [<f 'r0 'r0 'r1] d a b)
             ([('rem || 'urem) d a b _] && v6m? g) (dv [<f 'r0 'r0 'r1 'r2] d a b)
             (('cdef || 'cuse) . xs) [(<f . catmap (x \ (lovr? x && lofr? x ? (hi x ? [(l x) (h x)] [(l x)]) [x])) xs)]
             ((_ . _) && any (x \ lovr? x && lofr? x) f) (lono g ['softop <f], [f])
             _ [f])
       (catmap sp fs))

   ; allocated, then framed: the link, the frame, the saves marker csframe lays out
   (lobuild g f fs9)
    (: (li32 fs) (!(ia32? g) ? fs (map (f \ f @ (['li d k] && cint? k && !(-2147483648 <= k <= 4294967295)) ['li d (k & 4294967295)] _ f) fs))   ; nm's folds run wide
       ; an i386 struct return's ret $4, and a v6-M variadic's jump past its saved block, are a plain
       ; ret to the allocator, laid back after it
       (ret4? f) (f @ ['raw ([194 4 0] || [102 194 4 0])] 1 ['jmpr 'r3] 1 _ 0)
       ret4 (filter ret4? fs9 @ (x . _) x _ ())
       fs0 (? (sp64? g) (losoft g fs9) (w32s? g) (lov6 g (losoft g fs9)) (v6m? g) (map (f \ ret4? f ? '(ret) f) (lov6 g (losoft g fs9))) (ia32? g) (map (f \ ret4? f ? '(ret) f) fs9) fs9)
       (leak? f) (two? f && !(elem <f '(fix jmpt)) && any two? >f)
       (? (ilp32? g && (g 'lowhy || any leak? fs0)) (lono g ['pairleak (filter leak? fs0 @ (x . _) x _ ())])
    (mprof 'ra0 (_ \ raentry g (t2nx g fs0 @ fs1 ((sp64? g ? (t2mov g) 1) ((t32f? g ? (t2fimm g) 1) (li32 (getenv "MOON_NONM" @ () (mprof 'nm (_ \ nmall g fs1)) _ (radce g fs1))))))) @ fs
     ((getenv "MOON_LOLOG" @ "2" (map (x \ (putx x, putc 10)) fs) 0),
     mprof 'raplan (_ \ raplan g fs) @ 'bad (lono g 'ra)
       [f2 loc]
        ((getenv "MOON_LOLAW" @ () ()
            _ (rachk g fs f2 loc @ ws
                 (map (w \ (puts ";; lolaw \(<>f) ", putx w, putc 10)) (getenv "MOON_LOLOG" @ () () _ ws),
                  pins g 'lolawn (peep g 'lolawn 0 + 1) 'lolaw ((g 'lolaw) + map (w \ [<>f w]) ws)))),
         ; x64: a frame load only a compare reads becomes the compare's memory operand
         (mprof 'rasub (_ \ dlout g (rasub f2 loc) @ b0 (? (x64? g) (lo32op (lofuse g (cmpfuse g b0))) ret4 (map (f \ f = '(ret) ? ret4 f) b0) b0))) @ body
         ((getenv "MOON_LOLOG" @ "2" (puts ";; allocated\n", map (x \ (putx x, putc 10)) body) 0),
             (: F (aup (peep g 'off 0) 16 + (? (ia32? g) 8 (v6m? g) 4 0))
                (rv? g || xt? g ? (lorvf g (g 'sigs <>f @ s (two? s && s 2)) (a4ize (sibcall g ([['label (name <>f)] '(push lr) '(push fp) ['sub 'sp 'sp F] '(lea fp sp 0) '(saves)] + body))))
                   (((a64? g || t32? g) ? a4ize 1) (sibcall g ([['label (name <>f)]] + (t32? g && (g 'sigs <>f @ s (two? s && s 2)) ? '((push r3) (push r2) (push r1) (push r0))) + (v6m? g ? ['(push lr) '(push fp) '(push r4) '(lea fp sp 0) ['sub 'sp 'sp F] '(lea r4 sp 0)] (a64? g || t32? g ? pro-a64 pro4) + [['sub 'sp 'sp F]]) + ['(saves)] + body)))))))))))
   ; riscv links last, so fp is the frame's bottom: the saves laid, each fp slot rebased by the
   ; frame they leave, then a variadic fn's a0-a7 block ahead of the link
   (lorvf g va fs)
    (csframe g fs @ f2
       (rvslots f2 (f2 3 3) @ f3
          (va ? (wsize g @ w (<f3 . ([['sub 'sp 'sp (8 * w)]] + map (i \ ['st 'sp (vab g + w * i) (argr g i)]) ^(ngp g) + >f3))) f3)))
   ; the variadic block's bytes below its first argument register: xtensa's six sit at the top of eight
   (vab g) (xt? g ? 8 0)
   ; t32's vfp, before allocation: a float literal (li t k) (movdxr w t) lays w by vmov #imm where
   ; k encodes in eight bits, and a compare against a +0.0 literal is vcmp #0, the literal going
   ; when nothing else reads it
   (vfpimm? k) (k & 524287 = 0 && ((k >> 25 & 31) @ e (e = 0 && k >> 30 & 1 = 1 || e = 31 && k >> 30 & 1 = 0)))
   (t2fimm g fs)
    (: us {} ds {}
       (cnt t x) (pin t x (peep t x 0 + 1))
       _ (map (f \ (raops g f @ [u d] (map (cnt us) u, map (cnt ds) d) _ 0)) fs)
       ; t read and written there alone; a zero's w is written there alone too. a single no imm8
       ; reaches is fli, t its scratch, which lpool may load from a pool instead
       (lit? t) (peep us t 0 = 1 && peep ds t 0 = 1)
       zs {} zc {}
       _ (foldl (p \ f \ ((p @ ['li t 0] (f @ (['movdxr w t2] && t = t2 && lit? t && peep ds w 0 = 1) (pin zs w 1) _ 0) _ 0), f)) () fs)
       _ (map (f \ (f @ (['ucomiss a z] && a != z && zs z) (cnt zc z) _ 0)) fs)
       (go l)
        (l @ ((['li t k] . ['movdxr w t2] . u) && t = t2 && cint? k && lit? t)
              (: b (k & 4294967295)
                 (? (zs w && peep zc w 0 = peep us w 0) (go u)
                    (vfpimm? b) (['fimm w b] . go u)
                    (['fli w t b] . go u)))
             ((['ucomiss a z] . u) && a != z && zs z) (['ucom0 a] . go u)
             (f . u) (f . go u)
             _ ())
       (go fs))
   ; an sp-only vfp, before allocation: a copy of two vregs neither of which can hold a double's
   ; high half is one vmov.f32. a high half rides in from a double load, a gp pair or a machine
   ; register (a parameter, a call's answer) and on through copies, as lov6 has it
   (t2mov g fs)
    (: hi {}
       (dbl? f) (f @ ['ldsd d _ _] d ['movqrr d _ _] d ['stsd _ _ s] s ['movrrq _ _ s] s
                     (['movapd d s] && !(lovr? s)) d _ ())
       _ (map (f \ (dbl? f @ () () d (pin hi d 1))) fs)
       (prop _) (foldl (c \ f \ (f @ (['movapd d s] && hi s && !(hi d)) (pin hi d 1, c + 1) _ c)) 0 fs @ 0 0 _ (prop 0))
       _ (prop 0)
       (map (f \ (f @ (['movapd d s] && lovr? d && lovr? s && !(hi d) && !(hi s)) ['movss d s] _ f)) fs))
   ; x64, after allocation: a 64-bit op and the zero-extend of its answer are its 32-bit op, where
   ; that is one instruction
   (lo32op fs)
    (fs @ (([op d a b] . ['zx4 x] . u) && x = d && elem op '(add sub and or xor)
           && (a = d || op = 'add || b = d && op != 'sub))
           (['alu4 op d a b] . lo32op u)
          ((['shl d k] . ['zx4 x] . u) && x = d && cint? k && 0 < k < 32)
           (['shl4 d k] . lo32op u)
          (f . u) (f . lo32op u)
          _ ())
   ; after allocation, a full-word load one form alone reads, dying there, folds into it: a copy
   ; loads its copy, an alu op takes the word as its right side (a commuting one as its left)
   (lofuse g fs)
    (: (fold f nx)
        (f @ ['ld X b o]
           (nx @ (['mov Y x] && x = X && Y != X) ['ld Y b o]
                 ([op d a c] && elem op '(add sub and or xor) && c = X && a = d && d != X) ['alurm op 8 d b o]
                 ([op d a c] && elem op '(add and or xor) && a = X && c = d && d != X) ['alurm op 8 d b o]
                 _ ())
           _ ())
       (go l)
        (? !(two? l) l
           (: f <l r (two? >l ? >>l)
              m (two? >l ? (fold f <>l))
              (two? m && dieb? g <>f fs r ? (m . go r) (f . go >l))))
       (go fs))
   ; sp-only vfp, after allocation: a single's copy into d and the op on d after it are one
   ; three-operand op, d = a op b, where b is not d
   (t2op3 g fs)
    (: (go l) (l @ ((['movss d a] . [op d2 b] . u) && d = d2 && b != d && elem op '(addss subss mulss divss))
                    ([(name "\(show op)3") d a b] . go u)
                   (f . u) (f . go u)
                   _ ())
       (sp64? g ? (go fs) fs))
   ; v6-M: a frame slot off r4, the frame's bottom, its size known once csframe has laid the saves
   (lov6s g fs) (!(v6m? g) ? fs (filter (f \ f @ ('sub 'sp 'sp k) (charm? k) _ ()) fs @ ((_ _ _ k) . _) (t16slots fs k) _ fs))
   ; the frame and emit tail
   (lotail g ir)
    (dp 'final (fldcut g (thunks g (pushsv g (rjoin g (t2pm g (absg g (rawclean (a64sp g (twmv g (bprot g (frrec g (swrap g
     (tailarm g (kelse g (jmpm g (csdrop g (cskeep g (rvunframe g (unframe g (lov6s g (csframe g (t2op3 g (deadlabk (cg-refs (g 'fasecs) {}) (? (sp64? g || v6m? g) (t16la ir) (xt? g) (xtla g ir) ir)))))))))))))))))))))))))
)) ; module 'moon
