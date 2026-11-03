; src/apps/moon/lo.l -- the new backend's lowering: AST -> forms over vregs (%nK). a physical
; register appears only in a copy next to the form that demands it (args, results, returns,
; params on entry, the shift count). x64's integer core; any other arm answers 'bad and the
; fn takes the old path whole. ra.l lays first and mints the vregs. a value is (ty vreg forms), an lvalue ('v vreg ty) or
; ('a addr-value ty off). ra.l allocates what this lays
(module 'moon
(borrow 'holo)
(:

   (losc? ty) (elem ty ints9 || ty = 'bool || ptr? ty)
   (lofl? ty) (ty = 'double || ty = 'float)
   (losv? ty) (losc? ty || lofl? ty)
   (lomkt g ty) (lofl? ty ? (lomkf g) (lomk g))
   (lomv d s) (lofr? d ? ['movapd d s] ['mov d s])
   ; a pointer's step: the pointee's size, void and functions one byte
   (lostep g ty) (<>ty @ 'void 1 ('fn . _) 1 ('varr . _) 'bad t (tsz g t))
   (lok g e) (knum g e @ ((k . _) && fits32 k) [k] ())

   ; a value converted to ty, copied when the conversion writes
   (lotr g [vt r fs] ty)
    (? (lofl? ty || lofl? vt) (lotrf g [vt r fs] ty)
       (two? (cvt ty 'r0) && !(irfit? vt ty)) (lomk g @ t [ty t (fs + [['mov t r]] + cvt ty t)])
       [ty r fs])
   ; a conversion through the float file: the 64-bit forms, ulong by the old arms' snippets
   (lotrf g [vt r fs] ty)
    (? (vt = ty) [ty r fs]
       (lofl? vt && lofl? ty) (lomkf g @ t [ty t (fs + [[(ty = 'float ? 'cvtsd2ss 'cvtss2sd) t r]])])
       (lofl? ty && elem vt '(ulong ullong))
        (loren2 g [['r0 r]] 'f0 'double ul2d @ [_ d f2] (lotrf g ['double d (fs + f2)] ty))
       (lofl? ty) (lomkf g @ t [ty t (fs + [[(ty = 'float ? 'cvtsi2ss 'cvtsi2sd) t r]])])
       (ty = 'bool) (lotest g [vt r fs] @ [_ d f2] ['bool d f2])
       (elem ty '(ulong ullong))
        (lotrf g [vt r fs] 'double @ [_ d f1] (loren2 g [['f0 d]] 'r0 ty (dtoul g) @ [_ x f2] [ty x (f1 + f2)]))
       (lomk g @ t [ty t (fs + [[(vt = 'float ? 'cvttss2si 'cvttsd2si) t r]] + cvt ty t)]))
   ; a scalar's truth as an int 0/1: a float against 0.0, a NaN true
   (lotest g [vt r fs])
    (? (lofl? vt)
        (: t (lomk g) z (lomkf g) a (lomk g) b (lomk g) d (lomk g)
           ['int d (fs + [['li t 0] ['movqxr z t] [(vt = 'float ? 'ucomiss 'ucomisd) r z]
                          ['set 'ne a] ['set 'p b] ['mov d a] ['or d d b]])])
       (lomk g @ d ['int d (fs + [['cmp r 0] ['set 'ne d]])]))
   ; a copy, so the caller may write it in place
   (locp g [vt r fs]) (lomkt g vt @ t [vt t (fs + [(lomv t r)])])
   ; a 32-bit unsigned meeting a signed operand: the signed side's pattern zero-extends
   (loz g v other)
    (u32bin? g (vty v) (vty other) && !(usg? (vty v)) && !(ptr? (vty v)) ?
       (locp g v @ [vt t fs] [vt t (fs + [['zx4 t]])]) v)

   ; the names whose address the body takes: those live in memory
   (lotaken x acc)
    (x @ ['addr ['var n]] (elem n acc ? acc (n . acc))
         (_ . _) (foldl (a \ y \ lotaken y a) acc x)
         acc)

   ; -- the environment: (name 'v vreg ty) | (name 'm off ty), and ('brk L) ('cont L) ('sw tab ty) --
   (lovar g env nm)
    (assoc nm env @ (_ . en) en
       (peep (g 'gregs) nm () ? 'bad
          (g 'glob nm @ (a . b . _) ['g a b] 'bad)))
   (lolv g env e)
    (e @ ['var nm]
          (lovar g env nm @ ['v r ty] ['v r ty]
                            ['m off ty] ['a ['long 'r4 ()] ty off]
                            ['g lbl ty] (lomk g @ t ['a ['long t [['la t lbl]]] ty 0])
                            (lono g ['var nm]))
         ['deref p]
          (lox g env p @ [['ptr pt] r fs] ['a [['ptr pt] r fs] pt 0] 'bad (_ _ _) (lono g 'deref))
         ['dot base fld]
          (lolv g env base @ ['a av ty off]
                              (fmem g ty fld @ 'bad (lono g ['member fld])
                                               ([o bt] && bitf? bt) (? (bfwide? g bt) (lono g 'bitfield) ['b av bt (off + o)])
                                               [o mt] ['a av mt (off + o)])
                             'bad 'bad
                             _ (lono g 'dotbase))
         ; a compound literal: a temp filled as a local would be, an lvalue in the frame
         ['clit ty ini]
          (? (gcplx? ty) (lono g 'complex)
             (ntmp g ty @ off
                (aggish? ty ?
                   (lofill g env off ty ini @ 'bad 'bad fs ['a ['long 'r4 (lozero g off (aup (tsz g ty) 8) + fs)] ty off])
                   (lox g env (ini @ ['init (x . _)] x ['init ()] ['num 0] _ ini) @ 'bad 'bad
                      v (lost g ['a ['long 'r4 ()] ty off] v @ [fs _] ['a ['long 'r4 fs] ty off] 'bad)))))
         (lono g ['lval <e]))
   ; a refusal, its first cause kept for MOON_LOLOG
   (lono g why) (g 'lowhy @ () (pin g 'lowhy why, 'bad) _ 'bad)
   ; a frame address become a value: no sibling call may jump past it
   (loesc g r) (r @ 'r4 (pin g 'fesc 1) 0)
   ; a scalar load from an address
   (loload g [_ r fs] ty off)
    (? (losc? ty) (lomk g @ t [ty t (fs + [[(ldop ty) t r off]])])
       (lofl? ty) (lomkf g @ t [ty t (fs + [[(ty = 'float ? 'ldss 'ldsd) t r off]])])
       (lono g ['load ty]))
   ; an lvalue's value: an array decays, an aggregate refuses
   (lorv g lv)
    (lv @ ['v r ty] [ty r ()]
          ['a [_ r fs] ('arr . et . _) off] (lomk g @ t (loesc g r, [['ptr et] t (fs + [['lea t r off]])]))
          (['a [_ r fs] ty off] && stru? ty) (lomk g @ t (loesc g r, [ty t (fs + [['lea t r off]])]))
          ['a av ty off] (loload g av ty off)
          ; a bitfield: its unit, then two shifts (sar signed, shr unsigned; a bool never sign-extends)
          ['b [_ r fs] bt off]
           (: uty <>bt bitoff <>>bt width <>>>bt hi (64 - (bitoff + width)) lo (64 - width)
              (lobfld g bt r off @ [_ t f2]
                 ['long t (fs + f2 + (0 < hi ? [['shl t hi]]) + (0 < lo ? [[(usg? uty || uty = 'bool ? 'shr 'sar) t lo]]))]))
          'bad)
   ; a bitfield's unit at b+off into a fresh vreg, and back: one access as its type says, or the
   ; old arms' chunks when packed, their scratch renamed
   (lobfld g bt b off)
    (bfpk? bt ? (loren2 g () 'r2 'long (ldal 'r2 b off (tsz g bt) 8))
       (lomk g @ t ['long t [[(uldop (tsz g bt)) t b off]]]))
   (lobfst g bt b off u)
    (bfpk? bt ? (loren2 g () 'r3 'long (stal b off (tsz g bt) 8 u) @ [_ _ fs] fs)
       [[(stop <>bt) b off u]])
   ; a store of v (converted) to an lvalue -> [forms value] | 'bad
   (lost g lv v)
    (lv @ ['v r ty] (lotr g v ty @ [_ c fs] [(fs + [(lomv r c)]) [ty r ()]])
          (['a [_ b _] ty off] && losc? ty) (lotr g v ty @ [_ c fs] [(fs + [[(stop ty) b off c]]) [ty c ()]])
          (['a [_ b _] ty off] && lofl? ty) (lotr g v ty @ [_ c fs] [(fs + [[(ty = 'float ? 'stss 'stsd) b off c]]) [ty c ()]])
          ; a bitfield: read-modify-write its unit, the truncated value answers
          ['b [_ b _] bt off]
           (: uty <>bt bitoff <>>bt width <>>>bt mask ((1 << width) - 1) cmask (0 - (mask << bitoff) - 1)
              (lotr g v uty @ [_ c fs]
                 (: k (lomk g) m (lomk g) u (lomk g) x (lomk g)
                    (lobfld g bt b off @ [_ u fu]
                       [(fs + [['mov m c] ['li k mask] ['and m m k]] + fu + [['li k cmask] ['and u u k]
                               ['mov x m]] + (0 < bitoff ? [['shl x bitoff]]) + [['or u u x]] + lobfst g bt b off u)
                        ['long m ()]]))))
          (['a [_ b _] ty off] && stru? ty)
           (v @ ([vt r fs] && stru? vt && tsz g vt = tsz g ty)
                 (lomk g @ t (loesc g b, [(fs + locopy g r b off (tsz g ty) + [['lea t b off]]) [ty t ()]]))
                _ (lono g ['store ty]))
          (_ . _ . ty . _) (lono g ['store ty])
          'bad)
   ; sz bytes from address s to d + doff, widest first
   (locopy g s d doff sz)
    (lomk g @ t
       (: (go k acc) (? (8 <= sz - k) (go (k + 8) (acc + [['ld t s k] ['st d (doff + k) t]]))
                        (4 <= sz - k) (go (k + 4) (acc + [['ldu4 t s k] ['st4 d (doff + k) t]]))
                        (2 <= sz - k) (go (k + 2) (acc + [['ldu2 t s k] ['st2 d (doff + k) t]]))
                        (1 <= sz - k) (go (k + 1) (acc + [['ldu1 t s k] ['st1 d (doff + k) t]]))
                        acc)
          (go 0 ())))
   ; an aggregate in the frame: zeroed, then filled from its braces (cgzero and cgfill's arms)
   (lozero g off span)
    (lomk g @ z
       (: (go o rem acc) (? (8 <= rem) (go (o + 8) (rem - 8) (acc + [['st 'r4 o z]]))
                            (0 < rem) (go (o + 1) (rem - 1) (acc + [['st1 'r4 o z]]))
                            acc)
          ([['li z 0]] + go off span ())))
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
                                  (? (bfwide? g (fe 2)) (lono g 'bitfield)
                                     (lox g env (elval it) @ 'bad 'bad
                                        v (lost g ['b ['long 'r4 ()] (fe 2) (off + fe 1)] v @
                                             [f2 _] (go u (fnext g fields ci) (acc + f2))
                                             'bad)))
                                 (loelt g env (off + fe 1) (fe 2) (elval it) @ 'bad 'bad
                                    fs (go u (fnext g fields ci) (acc + fs))))))
                    acc)
              (go <>ini 0 ()))
          (lono g ['init ty])))
   (loelt g env off ty val)
    (? (gcplx? ty) (lono g 'complex)
       (aggish? ty && (val @ ('init . _) 1 ()) || arr? ty && (val @ ('str . _) 1 ())) (lofill g env off ty val)
       (stru? ty) (lox g env val @ 'bad 'bad v (lost g ['a ['long 'r4 ()] ty off] v @ [fs _] fs 'bad))
       (arr? ty) (lono g ['init ty])
       (lox g env val @ 'bad 'bad v (lost g ['a ['long 'r4 ()] ty off] v @ [fs _] fs 'bad)))

   ; the lvalue's own forms, laid once before its use, and the lvalue without them
   (lolvfs lv) (lv @ (('a || 'b) . [_ _ fs] . _) fs ())
   (lolvbare lv) (lv @ [k [t r _] ty off] [k [t r ()] ty off] lv)

   ; -- binary operators over two values --
   (locmp? op) (elem op '(eq ne lt le gt ge))
   (lobin g op a b kb)
    (? (bad? a || bad? b) 'bad
       (lofl? (vty a) || lofl? (vty b)) (lobinf g op a b)
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
                          [(vty p) d (vfs a + vfs b + [['mov s (vreg i)]] + (sz = 1 ? () [['imul s s sz]]) +
                                      [['mov d (vreg p)] [(irop op) d d s]])]))))
             (elem op '(+ - * & | ^))
              (: nar (nar32 g op ta tb 1)
                 (lomk g @ d [(rbin g ta tb) d (vfs a + vfs b + [['mov d (vreg a)] [(irop op) d d (vreg b)]] + (nar ? [[nar d]]))]))
             (elem op '(/ %))
              (: u (cmpu g ta tb) io (op = '/ ? (u ? 'udiv 'div) (u ? 'urem 'rem))
                 (loz g a b @ [_ x fx] (loz g b a @ [_ y fy] (lomk g @ d
                    [(rbin g ta tb) d (fx + fy + [(io @ ('rem || 'urem) [io d x y 'r0] [io d x y])])]))))
             (lono g ['bin op]))))
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
       (op @ ('lt || 'le) (lomk g @ d ['int d (fs + [[uc y x] ['set (op = 'lt ? 'above 'ae) d]])])
             ('gt || 'ge) (lomk g @ d ['int d (fs + [[uc x y] ['set (op = 'gt ? 'above 'ae) d]])])
             _ (: a (lomk g) b (lomk g) d (lomk g)
                  ['int d (fs + [[uc x y]] + (op = 'eq ? [['set 'eq a] ['set 'np b] ['mov d a] ['and d d b]]
                                                          [['set 'ne a] ['set 'p b] ['mov d a] ['or d d b]]))])))
   (lolog n) (n <= 1 ? 0 (1 + lolog (n // 2)))
   ; a shift keeps the left type; x64's variable count rides r1
   (losh g op [ta ra fa] b kb)
    (: uL (usg? ta)
       u32 (op = 'shl && u32? g ta)
       s32 (s32bin? g ta 'int)
       rt (? (u32? g ta) 'uint s32 'int uL 'ulong 'long)
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
   (lobr g env e sense L)
    (: (br x s L2 _) (lobr g env x s L2)
       (e @ ['land a b]
             (sense ? (nlab g ".lo" @ k (loseq [(br a 0 k) (br b 1 L) (lol [['label k]])]))
                (loseq [(br a 0 L) (br b 0 L)]))
            ['lor a b]
             (sense ? (loseq [(br a 1 L) (br b 1 L)])
                (nlab g ".lo" @ k (loseq [(br a 1 k) (br b 0 L) (lol [['label k]])])))
            ['un 'not x] (lobr g env x (sense ? 0 1) L)
            (['bin op a b] && locmp? op)
             (lox g env a @ 'bad 'bad
                va (lox g env b @ 'bad 'bad
                      vb (? !(losc? (vty va) && losc? (vty vb))
                             (lobin g op va vb () @ [_ d fs] (fs + [['cmp d 0] ['br (sense ? 'ne 'eq) L]]) 'bad)
                            (loz g va vb @ [_ x fx] (loz g vb va @ [_ y fy]
                               (fx + fy + [['cmp x y] ['br (scc (sense ? op (negrel op)) (cmpu g (vty va) (vty vb))) L]]))))))
            (lox g env e @ ([ty r fs] && losc? ty) (fs + [['cmp r 0] ['br (sense ? 'ne 'eq) L]])
                           ([ty r fs] && lofl? ty) (lotest g [ty r fs] @ [_ d f2] (f2 + [['cmp d 0] ['br (sense ? 'ne 'eq) L]]))
                           'bad)))

   ; -- expressions -> (ty vreg forms) | 'bad --
   (lox g env e)
    (e @ () ['void () ()]
         ['num v]
          (-9223372036854775808 <= v && v <= 18446744073709551615 ?
             (lomk g @ t [(numty v) t [['li t v]]]) 'bad)
         ['flo v] (lomk g @ t (lomkf g @ w ['double w [['li t (fbits v)] ['movqxr w t]]]))
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
          (lolv g env lv @ ['a [_ r fs] ty off] (lomk g @ t (loesc g r, [['ptr ty] t (fs + [['lea t r off]])])) 'bad)
         ['asn dst rhs]
          (lolv g env dst @ 'bad 'bad
             l (lox g env rhs @ 'bad 'bad
                  v (lost g (lolvbare l) v @ [fs [ty r _]] [ty r (lolvfs l + fs)] 'bad)))
         (['post dst step] && charm? step)
          (lolv g env dst @ 'bad 'bad
             l (: lb (lolvbare l)
                  (lorv g lb @ 'bad 'bad
                     o (: ty (vty o)
                          (lofl? ty ? (lopostf g env l lb o step)
                             (lostep g (ptr? ty ? ty ['ptr 'void]) @ 'bad 'bad
                             sz (locp g o @ [_ t fo] (lomk g @ n
                                   (lost g lb [(ptr? ty ? ty (rbin g ty 'int)) n [['mov n t] ['add n n (step * sz)]]] @
                                      [fs _] [ty t (lolvfs l + fo + fs)] 'bad)))))))))
         ['rmw op dst rhs]
          (lolv g env dst @ 'bad 'bad
             l (: lb (lolvbare l)
                  vo (lorv g lb) vr (lox g env rhs)
                  (lobin g op vo vr (elem op '(shl shr) ? (lok g rhs)) @ 'bad 'bad
                     r (lost g lb r @ [fs [ty x _]] [ty x (lolvfs l + fs)] 'bad))))
         ['cast 'void x] (lox g env x @ [_ _ fs] ['void () fs] 'bad)
         ['cast 'float ['flo v]] (lomk g @ t (lomkf g @ w ['float w [['li t (fbits32 v)] ['movdxr w t]]]))
         ['cast ty x]
          (lox g env x @ ([vt r fs] && losc? ty && losc? vt)
                          (two? (cvt ty r) ? (locp g [vt r fs] @ [_ t f2] [ty t (f2 + cvt ty t)]) [ty r fs])
                         ([vt r fs] && losv? ty && losv? vt) (lotr g [vt r fs] ty)
                         'bad)
         ; -1 and ~0 are literals, typed as C reads them
         (['un _ _] && two? (litv e)) (lox g env ['num <(litv e)])
         ['un 'not x]
          (lox g env x @ ([ty r fs] && losc? ty) (lomk g @ d ['int d (fs + [['cmp r 0] ['set 'eq d]])])
                         ([ty r fs] && lofl? ty) (lotest g [ty r fs] @ [_ t f2] (lomk g @ d ['int d (f2 + [['cmp t 0] ['set 'eq d]])]))
                         'bad)
         (['un op x] && elem op '(neg bnot))
          (lox g env x @ ([ty r fs] && losc? ty)
             (: uty (usg? ty && !(elem ty '(uchar cchar ushort)))
                sty (op = 'neg && !uty && s32bin? g ty 'int)
                (locp g [ty r fs] @ [_ d f2]
                   [(? uty ty sty 'int 'long) d
                    (f2 + [[(op = 'neg ? 'neg 'not) d]] + (? uty (ty @ 'uint [['zx4 d]] ()) sty [['sx4 d]] ()))]))
             ; a float's sign flips through the gp file
             ([ty r fs] && lofl? ty && op = 'neg)
              (: t (lomk g) k (lomk g) d (lomkf g) s (ty = 'float)
                 [ty d (fs + [[(s ? 'movdrx 'movqrx) t r] ['li k (s ? 2147483648 -9223372036854775808)] ['xor t t k]
                              [(s ? 'movdxr 'movqxr) d t]])])
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
          (nlab g ".lo" @ le (nlab g ".lo" @ ld
             (lobr g env c 0 le @ 'bad 'bad
                fc (lox g env a @ 'bad 'bad
                      va (lox g env b @ 'bad 'bad
                            vb (? (vty va = 'void || vty vb = 'void)
                                   ['void () (fc + vfs va + [['jmp ld] ['label le]] + vfs vb + [['label ld]])]
                                  !(losv? (vty va) && losv? (vty vb)) 'bad
                                  (: ta (vty va) tb (vty vb)
                                     fl (lofl? ta || lofl? tb)
                                     rt (? (ptr? ta) ta (ptr? tb) tb fl (ta = 'double || tb = 'double ? 'double 'float) (rbin g ta tb))
                                     (z v w) (fl ? (lotr g v rt) (loz g (lotr g v rt) w))
                                     (z va vb @ [_ x fx] (z vb va @ [_ y fy] (lomkt g rt @ d
                                        [rt d (fc + fx + [(lomv d x) ['jmp ld] ['label le]] + fy + [(lomv d y) ['label ld]])]))))))))))
         ['bin op a b]
          (: kb (elem op '(shl shr) ? (lok g b))
             va (lox g env a)
             vb (two? kb ? ['int () ()] (lox g env b))
             (lobin g op va vb kb))
         ['call fh as] (locall g env fh as)
         ; the va_list's fields, as cgexpr's SysV arms lay them
         ['vastart ap]
          (lox g env ap @ [_ p fs]
             (lomk g @ t (pin g 'fesc 1,
                ['void () (fs + [['li t (8 * peep g 'vagp 0)] ['st4 p 0 t] ['li t (48 + 16 * peep g 'vaxmm 0)] ['st4 p 4 t]
                                 ['lea t 'r4 16] ['st p 8 t] ['lea t 'r4 (peep g 'rsa 0)] ['st p 16 t]])]))
             'bad)
         ['vaend _] ['void () ()]
         ['vaarg ap ty]
          (lox g env ap @ [_ p fs] (lovaarg g p fs ty) 'bad)
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
              ((rt . ptys . va . rest) && !(1 < #nm && nm 0 = 95 && nm 1 = 95) && !(rest @ ('ms . _) 1 ()))
               (locall1 g env rt ptys va as [['call (intern nm)]] ())
              (lono g ['call nm]))
          _ (lox g env fh @
               [['ptr ['fn rt ptys]] r fs] (locall1 g env rt ptys 1 as [['callr r]] [r fs])
               [['ptr ['fn rt]] r fs] (locall1 g env rt () 1 as [['callr r]] [r fs])
               'bad 'bad
               (ty . _) (lono g ['callee ty])))
   ; a snippet over r0..r3 renamed onto fresh vregs, r0 the operand in and the answer out
   (loren g v fs) (loren2 g [['r0 v]] 'r0 'long fs)
   ; ..and over f0..f3 too: ins [register value].. copied in, the answer out of o
   (loren2 g ins o ty fs)
    (foldl (t \ r \ pin t r (lofr? r ? (lomkf g) (lomk g))) {} '(r0 r1 r2 r3 f0 f1 f2 f3) @
     t [ty (t o) (map (p \ lomv (t <p) <>p) ins + map (f \ map (x \ peep t x x) f) fs)])
   ; raw bytes on fixed registers: the operand in r0, the answer out of it, ds what it writes
   (lofix g v ds fs)
    (lomk g @ d ['long d [['mov 'r0 v] ['fix '(r0) ds fs] ['mov d 'r0]]])
   ; one scalar operand -> [ty r fs] | 'bad
   (lobi1 g env e)
    (lox g env e @ ([vt r fs] && losc? vt) [vt r fs]
                   'bad 'bad
                   (vt . _) (lono g ['arg vt]))
   ; a builtin, the old arm its spec
   (lobi g env nm as)
    (: (one f) (lobi1 g env <as @ 'bad 'bad [vt r fs] (f r @ 'bad 'bad [t d fs2] [t d (fs + fs2)]))
       ll (elem nm '("__builtin_clzll" "__builtin_clzl" "__builtin_ctzll" "__builtin_ctzl"))
       (? (elem nm '("__builtin_expect" "__builtin_prefetch")) (lobi1 g env <as)
          (elem nm '("__builtin_trap" "__builtin_unreachable"))
           (lomk g @ d ['long d [['fix () () '((ud2))] ['li d 0]]])
          (nm = "__builtin_alloca")
           (? (g 'abad || avz? g) (lono g ['call nm])
              (one (v \ (: t (lomk g) u (lomk g) d (lomk g)
                           (pin g 'fesc 1, pin g 'hasasm 1,
                            ['(ptr void) d [['mov t v] ['add t t 15] ['shr t 4] ['shl t 4] ['lea u 'sp 0]
                                            ['sub u u t] ['lea 'sp u 0] ['lea d 'sp 0]]])))))
          (elem nm '("__builtin_return_address" "__builtin_frame_address"))
           (as @ ([['num k]] && 0 <= k)
                  (lomk g @ d
                     (pin g 'fesc 1, pin g 'fpin 1,
                      ['(ptr void) d (['lean d 'r4 0] . map (_ \ ['ld d d 0]) ^k +
                                      (nm = "__builtin_return_address" ? [['ld d d 8]]))]))
                 _ (lono g ['call nm]))
          (elem nm '("__builtin_clz" "__builtin_clzl" "__builtin_clzll"))
           (one (v \ lofix g v () ((ll ? () '((shl r0 32))) + '((raw (72 15 189 192 72 131 240 63))))))
          (elem nm '("__builtin_ctz" "__builtin_ctzl" "__builtin_ctzll"))
           (one (v \ lofix g v () '((raw (72 15 188 192)))))
          (nm = "__builtin_bswap16")
           (one (v \ loren g v '((li r2 255) (mov r1 r0) (shr r1 8) (and r1 r1 r2)
                                 (and r0 r0 r2) (shl r0 8) (or r0 r0 r1))))
          (nm = "__builtin_bswap32") (one (v \ loren g v bsw32))
          (nm = "__builtin_bswap64")
           (one (v \ loren g v '((li r2 71777214294589695)
                                 (mov r1 r0) (shr r1 8) (and r1 r1 r2)
                                 (and r0 r0 r2) (shl r0 8) (or r0 r0 r1)
                                 (li r2 281470681808895)
                                 (mov r1 r0) (shr r1 16) (and r1 r1 r2)
                                 (and r0 r0 r2) (shl r0 16) (or r0 r0 r1)
                                 (mov r1 r0) (shr r1 32) (shl r0 32) (or r0 r0 r1))))
          (elem nm '("__builtin_popcount" "__builtin_popcountl" "__builtin_popcountll"))
           (one (v \ loren g v (popops g (nm = "__builtin_popcount"))))
          (elem nm '("__builtin_ffs" "__builtin_ffsl" "__builtin_ffsll"))
           (nlab g ".ffs" @ lz
              (one (v \ loren g v ((nm = "__builtin_ffs" ? '((li r2 4294967295) (and r0 r0 r2))) +
                                   ['(cmp r0 0) ['br 'eq lz] '(mov r1 r0) '(sub r1 r1 1) '(xor r0 r0 r1)] +
                                   popops g (nm = "__builtin_ffs") + [['label lz]]))))
          (lono g ['call nm])))
   ; an atomic, x64's arms of cgatomic: raw loops on fixed registers, the operands copied in
   (loat g env nm as)
    (: k (atomop nm) kind (k @ (kd . _) kd 'lock)
       ; the order: a constant, or anything else laid for its effects and taken as seq_cst
       mo (? (nm @ ("__sync_" + _) 1 ()) [5 ()] (elem kind '(lockfree generic)) [5 ()]
             (as (#as - 1) @ ['num o] [o ()]
                             e (lox g env e @ 'bad 'bad [_ _ fs] [5 fs])))
       (fx u d fs) ['fix u d fs]
       (? (bad? mo) 'bad
          (kind = 'generic) (lono g ['call nm])
          (kind = 'fence) (lomk g @ d ['long d (<>mo + (<mo = 0 ? () [(fx () () (afence g))]) + [['li d 0]])])
          (kind = 'sfence) (lomk g @ d ['long d (<>mo + [(fx () () (abar g))] + [['li d 0]])])
          (kind = 'lockfree)
           (cfold !(ilp32? g) <as @ n
              (charm? n ? (lomk g @ d ['int d [['li d (elem n (awidths g) ? 1 0)]]]) (lono g ['call nm])))
          (lobi1 g env <as @
             'bad 'bad
             ([['ptr pt] p pf] && amw g pt)
              (: w (amw g pt) z (lomk g)
                 (? (kind = 'lock)
                     (? (nm = "__sync_lock_release")
                         (? !(elem w '(4 8)) (lono g ['atomic pt])
                            ['long z (pf + [['li z 0] [(stw w) p 0 z]])])
                        (lobi1 g env (as 1) @
                           'bad 'bad
                           [_ v vf] (? !(elem w '(4 8)) (lono g ['atomic pt])
                                       (lomk g @ d
                                          [pt d (pf + vf + [['mov 'r0 v] ['mov 'r1 p]
                                                            (fx '(r0 r1) '(r0) [['raw (w @ 4 '(135 1) '(72 135 1))]])
                                                            ['mov d 'r0]] + map (f \ [<f d]) (rext g pt))]))))
                    (kind = 'load) (lomk g @ d [pt d (<>mo + pf + [[(ldop pt) d p 0]])])
                    (kind = 'clear)
                     ['long z (<>mo + pf + [['li z 0] ['st1 p 0 z]] + (<mo = 5 ? [(fx () () (afence g))]))]
                    (kind = 'tas)
                     (: o (lomk g) d (lomk g)
                        ['int d (<>mo + pf + [['li 'r2 1] ['mov 'r1 p] (fx '(r1 r2) '(r0 r3) (armw g 1 'set))
                                              ['mov o 'r0] ['zx1 o] ['li z 0] ['cmp o z] ['set 'ne d]])])
                    (kind = 'cas)
                     (lobi1 g env (as 1) @ 'bad 'bad
                        [_ ep ef]
                         (lobi1 g env (as 2) @ 'bad 'bad
                            [_ dv df]
                             (: t (lomk g) o (lomk g) d (lomk g) ok (nlab g ".casok")
                                ['int d (<>mo + pf + ef + df +
                                         [[(uldop w) t ep 0] ['mov 'r0 t] ['mov 'r1 p] ['mov 'r2 dv]
                                          (fx '(r0 r1 r2) '(r0 r2 r3) (acas g w))
                                          ['mov o 'r0] ['mov d 'r2] ['li z 0] ['cmp d z] ['br 'ne ok]
                                          [(stw w) ep 0 o] ['label ok]])])))
                    (lobi1 g env (as 1) @
                       'bad 'bad
                       [_ v vf]
                        (? (kind = 'store) ['long z (<>mo + pf + vf + [[(stop pt) p 0 v]] + (<mo = 5 ? [(fx () () (afence g))]))]
                           (kind = 'rmw)
                            (lomk g @ d
                               [pt d (<>mo + pf + vf + [['mov 'r1 p] ['mov 'r2 v] (fx '(r1 r2) '(r0 r3) (armw g w (k 1)))
                                                        ['mov d (k 2 = 'new ? 'r3 'r0)]] + map (f \ [<f d]) (rext g pt))])
                           (elem kind '(vcas bcas))
                            (lobi1 g env (as 2) @ 'bad 'bad
                               [_ nv nf]
                                (lomk g @ d
                                   (kind = 'vcas ?
                                      [pt d (pf + vf + nf + [['mov 'r0 v] ['mov 'r1 p] ['mov 'r2 nv]
                                                             (fx '(r0 r1 r2) '(r0 r2 r3) (acas g w)) ['mov d 'r0]]
                                                    + map (f \ [<f d]) (rext g pt))]
                                      ['int d (pf + vf + nf + [['mov 'r0 v] ['mov 'r1 p] ['mov 'r2 nv]
                                                              (fx '(r0 r1 r2) '(r0 r2 r3) (acas g w)) ['mov d 'r2]])])))
                           (lono g ['call nm])))))
             (vt . _) (lono g ['atomic vt]))))
   ; cl the call form, fv the callee's (vreg forms) | (); va also lays al, the vector count
   (locall1 g env rt ptys va as cl fv)
    (? !(rt = 'void || losv? rt) (lono g ['ret rt])
       (0 < #ptys && !va && #as != #ptys) (lono g 'arity)
       (: (arg e pt)
           (lox g env e @ ([vt r fs] && losv? vt)
                           (pt @ 'none (vt = 'float ? (lotr g [vt r fs] 'double) [vt r fs])
                                 p9 (losv? p9 ? (lotr g [vt r fs] p9) (lono g ['arg p9])))
                          'bad 'bad
                          (vt . _) (lono g ['arg vt]))
          (go l i acc)
           (l @ (e . u) (arg e (i < #ptys ? (ptys i) 'none) @ 'bad 'bad v (go u (i + 1) (acc + [v])))
                acc)
          (go as 0 () @ 'bad 'bad
             ; each arg to the next register of its file, or past them to the block, in order
             vs (: pl (foldl (s \ v \ (s @ [gi fi rg sk]
                                       (? (lofr? (vreg v)) (fi < 8 ? [gi (fi + 1) (rg + [[(xmmreg fi) v]]) sk] [gi fi rg (sk + [v])])
                                          (gi < 6) [(gi + 1) fi (rg + [[(argregs gi) v]]) sk]
                                          [gi fi rg (sk + [v])])))
                              [0 0 () ()] vs)
                   nf (pl 1) rg (pl 2) sk (pl 3) rs (map (x \ <x) rg)
                   d (lomkt g rt) blk (aup (8 * #sk) 16)
                   al (va ? [['li 'r0 nf]])
                   (stk v) [(vty v @ 'float 'stss 'double 'stsd 'st) 'sp 0 (vreg v)]
                   res (? (rt = 'void) () (lofl? rt) [['movapd d 'f0]] (['mov d 'r0] . map (f \ [<f d]) (rext g rt)))
                   [rt (rt = 'void ? () d)
                    (catmap vfs vs + (fv @ [_ ffs] ffs ()) +
                     (blk = 0 ? () ([['sub 'sp 'sp blk]] + map (k \ (stk (sk k) @ [o b _ x] [o b (8 * k) x])) ^#sk)) +
                     map (p \ lomv <p (vreg <>p)) rg + al +
                     [('(cuse) + rs + (va ? '(r0)) + (fv @ [fr _] [fr] ()))] + cl +
                     (blk = 0 ? () [['add 'sp 'sp blk]]) + res)]))))

   ; -- statements -> forms | 'bad --
   (lost1 g env s)
    (: (st x e2 _) (lost1 g e2 x)
       (br x s L _) (lobr g env x s L)
       (s @ () ()
            ((_ . _) . _) (loitems g env s)
            ('nop . _) ()
            ('tdef . _) ()
            ['expr e] (lox g env e @ [_ _ fs] fs 'bad)
            ['ret] (peep g 'epi epi)
            ['ret e]
             (: rt <(peep (g 'sigs) (g 'fn) ['long ()]) epj (peep g 'epi epi)
                (lox g env e @ 'bad 'bad
                   ([_ _ fs] && rt = 'void) (fs + epj)
                   ([vt r fs] && losv? rt && losv? vt) (lotr g [vt r fs] rt @ [_ c f2] (f2 + [(lomv (lofl? rt ? 'f0 'r0) c)] + epj))
                   'bad))
            ['blk items] (loitems g env items)
            ['if c t]
             (nlab g ".lo" @ le (loseq [(br c 0 le) (st t env) (lol [['label le]])]))
            ['if c t el]
             (nlab g ".lo" @ le (nlab g ".lo" @ ld
                (loseq [(br c 0 le) (st t env) (lol [['jmp ld] ['label le]]) (st el env) (lol [['label ld]])])))
            ['while c body]
             (nlab g ".lo" @ lc (nlab g ".lo" @ lb
                (loseq [(lol [['label lc]]) (br c 0 lb) (st body (['brk lb] . ['cont lc] . env)) (lol [['jmp lc] ['label lb]])])))
            ['do body c]
             (nlab g ".lo" @ lt (nlab g ".lo" @ lc (nlab g ".lo" @ lb
                (loseq [(lol [['label lt]]) (st body (['brk lb] . ['cont lc] . env)) (lol [['label lc]]) (br c 1 lt) (lol [['label lb]])]))))
            ['for init c stp body]
             (nlab g ".lo" @ lt (nlab g ".lo" @ lc (nlab g ".lo" @ lb
                ((init @ () [() env]
                         ['decl ps] (lodecl g env ps)
                         [_ x] (lox g env x @ [_ _ fs] [fs env] 'bad)
                         'bad) @
                 [fi e1]
                  (loseq [(lol (fi + [['label lt]])) (u \ (c @ () () _ (lobr g e1 c 0 lb)))
                          (st body (['brk lb] . ['cont lc] . e1)) (lol [['label lc]])
                          (u \ (stp @ () () _ (lox g e1 stp @ [_ _ fs] fs 'bad))) (lol [['jmp lt] ['label lb]])])
                  'bad))))
            ('brk . _) (assoc 'brk env @ [_ L] [['jmp L]] 'bad)
            ('cont . _) (assoc 'cont env @ [_ L] [['jmp L]] 'bad)
            ['goto nm] [['jmp (name "\(g 'fn).\(nm)")]]
            ['lbl nm] [['label (name "\(g 'fn).\(nm)")]]
            ['switch ce body] (loswitch g env ce body)
            ['case lo hi] (assoc 'sw env @ [_ tab _] (peep tab "\(lo):\(hi)" () @ () 'bad L [['label L]]) 'bad)
            ['case cv] (assoc 'sw env @ [_ tab ty] (peep tab (lokey g ty cv) () @ () 'bad L [['label L]]) 'bad)
            ('dflt . _) (assoc 'sw env @ [_ tab _] (peep tab 'dflt () @ () 'bad L [['label L]]) 'bad)
            (lono g ['stmt <s])))
   (lokey g ty cv) (charm? cv ? (cfit g ty cv) 'bad)
   ; a switch as a compare chain: its cases, nested switches aside, each take a label
   (loswitch g env ce body)
    (lox g env ce @ ([ty r fs] && losc? ty)
       (: tab {}
          (walk x) (x @ ('switch . _) 0
                        ['case cv] (lokey g ty cv @ 'bad (pin tab 'bad 1) k (pin tab k (nlab g ".lo")))
                        ['case lo hi]
                         (? !(charm? lo && charm? hi && hi - lo < 64) (pin tab 'bad 1)
                            (nlab g ".lo" @ L (pin tab "\(lo):\(hi)" L, map (k \ pin tab (cfit g ty (lo + k)) L) ^(hi - lo + 1))))
                        ('dflt . _) (pin tab 'dflt (nlab g ".lo"))
                        (_ . _) (map walk x)
                        0)
          _ (walk body)
          (tab 'bad ? (lono g 'case)
             (nlab g ".lo" @ lb
                (: tst (catmap (k \ (fits32 k ? [['cmp r k] ['br 'eq (tab k)]]
                                       (lomk g @ t [['li t k] ['cmp r t] ['br 'eq (tab k)]])))
                               (sort (filter charm? (keys tab))))
                   (lost1 g (['brk lb] . ['sw tab ty] . env) body @ 'bad 'bad
                      fb (fs + tst + [['jmp (peep tab 'dflt lb)]] + fb + [['label lb]]))))))
       'bad)
   ; a block's items, decls threading the env -> forms | 'bad, and with the env it ends on
   (loitems g env items) (loitems2 g env items @ [fs _] fs 'bad)
   (loitems2 g env items)
    (: (go l env acc)
        (l @ (['decl ps] . u) (lodecl g env ps @ [fs e2] (go u e2 (acc + fs)) 'bad)
             (['sdecl ps] . u) (go u (losdecl g env ps) acc)
             (it . u) (lost1 g env it @ 'bad 'bad fs (go u env (acc + fs)))
             [acc env])
       (go items env ()))
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
                 (? (rest @ (_ . x . _) x ()) (lono g 'regasm)
                    (gvarr? ty) (lono g 'vla)
                    (losv? ty && (init @ ('init . _) 1 ())) (lono g ['init ty])
                    (gcplx? ty) (lono g 'complex)
                    (losv? ty && nelem nm (g 'lotk))
                     (lomkt g ty @ r
                        (: e2 ([nm 'v r ty] . env)
                           (init @ () (go u e2 acc)
                                   _ (lox g env init @ 'bad 'bad
                                        v (lost g ['v r ty] v @ [fs _] (go u e2 (acc + fs)) 'bad)))))
                    (ntmp g ty @ off
                       (: e2 ([nm 'm off ty] . env)
                          (? (init = ()) (go u e2 acc)
                             (losv? ty)
                              (lox g env init @ 'bad 'bad
                                 v (lost g ['a ['long 'r4 ()] ty off] v @ [fs _] (go u e2 (acc + fs)) 'bad))
                             ((init @ ('init . _) 1 ()) || arr? ty && (init @ ('str . _) 1 ()) || clarr? ty init)
                              (lofill g e2 off ty init @ 'bad 'bad fs (go u e2 (acc + lozero g off (aup (tsz g ty) 8) + fs)))
                             (stru? ty) (loelt g e2 off ty init @ 'bad 'bad fs (go u e2 (acc + fs)))
                             (lono g ['init ty]))))))
             [acc env])
       (go ps env ()))

   ; -- the fn: params home off their registers, then the body -> forms over vregs | 'bad --
   ; MOON_LOLOG=1 names each fn and which path took it; MOON_LOONLY=fn keeps the new path to one fn, for bisecting
   (lofn g f params sig)
    ((getenv "MOON_LOONLY" @ () (lofn1 g f params sig) n (n = <>f ? (lofn1 g f params sig) 'bad)) @ r
       (getenv "MOON_LOLOG" @ () r _ (puts ";; lo \(<>f) \(bad? r ? "old \(show (g 'lowhy))" "new")\n", r)))
   (lofn1 g f params sig)
    (sig @ ((rt . _ . va . _) && (rt = 'void || losv? rt) && all (p \ losv? <>p) params &&
            #(filter (p \ !(lofl? <>p)) params) <= 6 && #(filter (p \ lofl? <>p) params) <= 8 &&
            !(g 'hasasm || g 'twice || g 'abad || g 'sspf || two? (g 'ltaken)))
       (: _ (pins g 'lon 0 'lotk (lotaken (f 3) ()) 'lowhy () 'loret (lofl? rt ? '(f0) '(r0)))
          vs (va ? (lovasave g params))
          (go l gi fi env acc)
           (l @ ((nm . ty . _) . u)
                 (: fl (lofl? ty) A (fl ? (xmmreg fi) (argregs gi)) g2 (fl ? gi (gi + 1)) f2 (fl ? (fi + 1) fi)
                    (elem nm (g 'lotk) ?
                       (ntmp g ty @ off
                          (go u g2 f2 ([nm 'm off ty] . env)
                              (acc + (fl ? [[(ty = 'float ? 'stss 'stsd) 'r4 off A]] (cvt ty A + [[(stop ty) 'r4 off A]])))))
                       (lomkt g ty @ r (go u g2 f2 ([nm 'v r ty] . env) (acc + [(lomv r A)] + (fl ? () (cvt ty r)))))))
                [acc env])
          (go params 0 0 () () @ [pe env]
             (loitems g env (f 3 @ ['blk items] items x [x]) @ 'bad 'bad
                body (lobuild g f (vs + pe + body + fz0 g <>f + peep g 'epi epi)))))
       (pin g 'lowhy ['fn (sig @ (rt . p . va . _) [rt va (map (x \ <>x) params)] 'nosig)
                           (g 'hasasm) (g 'twice) (g 'abad) (g 'sspf) (two? (g 'ltaken))], 'bad))

   ; a variadic fn (SysV): a 176-byte save area, gp at +0 step 8, xmm at +48 step 16
   (lovasave g params)
    (: rsa (nslot g 176) nf #(filter (p \ lofl? <>p) params)
       (pins g 'rsa rsa 'vagp (#params - nf) 'vaxmm nf 'fesc 1,
        map (i \ ['st 'r4 (rsa + 8 * i) (argregs i)]) ^6 +
        (nofp? g ? () (map (i \ ['stsd 'r4 (rsa + 48 + 16 * i) (xmmreg i)]) ^8))))

   ; allocated, then framed: the link, the frame, the saves marker csframe lays out
   (lobuild g f fs)
    ((getenv "MOON_LOLOG" @ "2" (map (x \ (putx x, putc 10)) fs) 0),
     raall g fs @ 'bad (lono g 'ra)
       body ((getenv "MOON_LOLOG" @ "2" (puts ";; allocated\n", map (x \ (putx x, putc 10)) body) 0),
             sibcall g ([['label (name <>f)]] + pro4 + [['sub 'sp 'sp (aup (peep g 'off 0) 16)] '(saves)] + body)))
   ; the frame and emit tail the old path ends on
   (lotail g ir)
    (dp 'final (fldcut g (thunks g (pushsv g (rjoin g (absg g (rawclean (a64sp g (twmv g (bprot g (frrec g (swrap g
     (tailarm g (jmpm g (csdrop g (cskeep g (unframe g (csframe g (deadlabk (cg-refs (g 'fasecs) {}) ir)))))))))))))))))))
)) ; module 'moon
