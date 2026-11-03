; src/apps/moon/lo.l -- the new backend's lowering: AST -> forms over vregs (%nK). a physical
; register appears only in a copy next to the form that demands it (args, results, returns,
; params on entry, the shift count). x64's integer core; any other arm answers 'bad and the
; fn takes the old path whole. ra.l lays first and mints the vregs. a value is (ty vreg forms), an lvalue ('v vreg ty) or
; ('a addr-value ty off). ra.l allocates what this lays
(module 'moon
(borrow 'holo)
(:

   (losc? ty) (elem ty ints9 || ty = 'bool || ptr? ty)
   ; a pointer's step: the pointee's size, void and functions one byte
   (lostep g ty) (<>ty @ 'void 1 ('fn . _) 1 ('varr . _) 'bad t (tsz g t))
   (lok g e) (knum g e @ ((k . _) && fits32 k) [k] ())

   ; a value converted to ty, copied when the conversion writes
   (lotr g (vt r fs) ty)
    (two? (cvt ty 'r0) && !(irfit? vt ty) ?
       (lomk g @ t [ty t (fs + [['mov t r]] + cvt ty t)])
       [ty r fs])
   ; a copy, so the caller may write it in place
   (locp g (vt r fs)) (lomk g @ t [vt t (fs + [['mov t r]])])
   ; a 32-bit unsigned meeting a signed operand: the signed side's pattern zero-extends
   (loz g v other)
    (u32bin? g (vty v) (vty other) && !(usg? (vty v)) && !(ptr? (vty v)) ?
       (locp g v @ (vt t fs) [vt t (fs + [['zx4 t]])]) v)

   ; the names whose address the body takes: those live in memory
   (lotaken x acc)
    (x @ ('addr ('var n)) (elem n acc ? acc (n . acc))
         (_ . _) (foldl (a \ y \ lotaken y a) acc x)
         acc)

   ; -- the environment: (name 'v vreg ty) | (name 'm off ty), and ('brk L) ('cont L) ('sw tab ty) --
   (lovar g env nm)
    (assoc nm env @ (_ . en) en
       (peep (g 'gregs) nm () ? 'bad
          (g 'glob nm @ (a . b . _) ['g a b] 'bad)))
   (lolv g env e)
    (e @ ('var nm)
          (lovar g env nm @ ('v r ty) ['v r ty]
                            ('m off ty) ['a ['long 'r4 ()] ty off]
                            ('g lbl ty) (lomk g @ t ['a ['long t [['la t lbl]]] ty 0])
                            (lono g ['var nm]))
         ('deref p)
          (lox g env p @ (('ptr pt) r fs) ['a [['ptr pt] r fs] pt 0] 'bad (_ _ _) (lono g 'deref))
         ('dot base fld)
          (lolv g env base @ ('a av ty off)
                              (fmem g ty fld @ 'bad (lono g ['member fld])
                                               (_ ('bitfield . _)) (lono g 'bitfield)
                                               (o mt) ['a av mt (off + o)])
                             'bad 'bad
                             _ (lono g 'dotbase))
         (lono g ['lval <e]))
   ; a refusal, its first cause kept for MOON_LOLOG
   (lono g why) (g 'lowhy @ () (pin g 'lowhy why, 'bad) _ 'bad)
   ; a frame address become a value: no sibling call may jump past it
   (loesc g r) (r @ 'r4 (pin g 'fesc 1) 0)
   ; a scalar load from an address
   (loload g (_ r fs) ty off)
    (losc? ty ? (lomk g @ t [ty t (fs + [[(ldop ty) t r off]])]) (lono g ['load ty]))
   ; an lvalue's value: an array decays, an aggregate refuses
   (lorv g lv)
    (lv @ ('v r ty) [ty r ()]
          ('a (_ r fs) ('arr . et . _) off) (lomk g @ t (loesc g r, [['ptr et] t (fs + [['lea t r off]])]))
          ('a av ty off) (loload g av ty off)
          'bad)
   ; a store of v (converted) to an lvalue -> [forms value] | 'bad
   (lost g lv v)
    (lv @ ('v r ty) (lotr g v ty @ (_ c fs) [(fs + [['mov r c]]) [ty r ()]])
          (('a (_ b _) ty off) && losc? ty) (lotr g v ty @ (_ c fs) [(fs + [[(stop ty) b off c]]) [ty c ()]])
          (_ _ ty . _) (lono g ['store ty])
          'bad)
   ; the lvalue's own forms, laid once before its use, and the lvalue without them
   (lolvfs lv) (lv @ ('a . (_ _ fs) . _) fs ())
   (lolvbare lv) (lv @ ('a (t r _) ty off) ['a [t r ()] ty off] lv)

   ; -- binary operators over two values --
   (locmp? op) (elem op '(eq ne lt le gt ge))
   (lobin g op a b kb)
    (? (bad? a || bad? b) 'bad
       !(losc? (vty a) && losc? (vty b)) (lono g ['bin op (vty a) (vty b)])
       (: ta (vty a) tb (vty b)
          (? (locmp? op)
              (loz g a b @ (_ x fx) (loz g b a @ (_ y fy) (lomk g @ d
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
                 (loz g a b @ (_ x fx) (loz g b a @ (_ y fy) (lomk g @ d
                    [(rbin g ta tb) d (fx + fy + [(io @ ('rem || 'urem) [io d x y 'r0] [io d x y])])]))))
             (lono g ['bin op]))))
   (lolog n) (n <= 1 ? 0 (1 + lolog (n // 2)))
   ; a shift keeps the left type; x64's variable count rides r1
   (losh g op (ta ra fa) b kb)
    (: uL (usg? ta)
       u32 (op = 'shl && u32? g ta)
       s32 (s32bin? g ta 'int)
       rt (? (u32? g ta) 'uint s32 'int uL 'ulong 'long)
       iop (op = 'shl ? 'shl (uL ? 'shr 'sar))
       vop (op = 'shl ? 'shlv (uL ? 'shrv 'sarv))
       d (lomk g)
       nar (? u32 [['zx4 d]] (s32 && op = 'shl) [['sx4 d]] ())
       (kb @ ((k) && 0 <= k && k < 64) [rt d (fa + [['mov d ra] [iop d k]] + nar)]
             (_) 'bad
             [rt d (fa + vfs b + [['mov d ra] ['mov 'r1 (vreg b)] [vop d 'r1]] + nar)]))

   ; forms laid by thunks run in list order (argument order is unspecified, and they mint), the
   ; first 'bad the answer
   (loseq l) (foldl (a \ t \ (bad? a ? 'bad (t 0 @ 'bad 'bad fs (a + fs)))) () l)
   (lol x _) x

   ; -- branches: to L when e's truth is sense --
   (lobr g env e sense L)
    (: (br x s L2 _) (lobr g env x s L2)
       (e @ ('land a b)
             (sense ? (nlab g ".lo" @ k (loseq [(br a 0 k) (br b 1 L) (lol [['label k]])]))
                (loseq [(br a 0 L) (br b 0 L)]))
            ('lor a b)
             (sense ? (loseq [(br a 1 L) (br b 1 L)])
                (nlab g ".lo" @ k (loseq [(br a 1 k) (br b 0 L) (lol [['label k]])])))
            ('un 'not x) (lobr g env x (sense ? 0 1) L)
            (('bin op a b) && locmp? op)
             (lox g env a @ ((ta ra fa) && losc? ta)
                (lox g env b @ ((tb rb fb) && losc? tb)
                   (loz g [ta ra fa] [tb rb fb] @ (_ x fx) (loz g [tb rb fb] [ta ra fa] @ (_ y fy)
                      (fx + fy + [['cmp x y] ['br (scc (sense ? op (negrel op)) (cmpu g ta tb)) L]])))
                   'bad)
                'bad)
            (lox g env e @ ((ty r fs) && losc? ty) (fs + [['cmp r 0] ['br (sense ? 'ne 'eq) L]])
                           'bad)))

   ; -- expressions -> (ty vreg forms) | 'bad --
   (lox g env e)
    (e @ ('num v)
          (-9223372036854775808 <= v && v <= 18446744073709551615 ?
             (lomk g @ t [(numty v) t [['li t v]]]) 'bad)
         ('str s)
          (nlab g ".S" @ lbl
             (pin g 'strs ([lbl s] . g 'strs),
              lomk g @ t [['ptr (gchar g)] t [['la t lbl]]]))
         ('var nm)
          (lovar g env nm @ 'bad (g 'fns nm ? (lomk g @ t [['ptr (fnty g nm)] t [['la t (name nm)]]]) 'bad)
                            _ (lorv g (lolv g env e)))
         (('deref _) || ('dot _ _)) (lorv g (lolv g env e))
         (('addr ('var nm)) && bad? (lovar g env nm) && g 'fns nm)
          (lomk g @ t [['ptr (fnty g nm)] t [['la t (name nm)]]])
         ('addr lv)
          (lolv g env lv @ ('a (_ r fs) ty off) (lomk g @ t (loesc g r, [['ptr ty] t (fs + [['lea t r off]])])) 'bad)
         ('asn dst rhs)
          (lolv g env dst @ 'bad 'bad
             l (lox g env rhs @ 'bad 'bad
                  v (lost g (lolvbare l) v @ (fs (ty r _)) [ty r (lolvfs l + fs)] 'bad)))
         (('post dst step) && charm? step)
          (lolv g env dst @ 'bad 'bad
             l (: lb (lolvbare l)
                  (lorv g lb @ 'bad 'bad
                     o (: ty (vty o)
                          (lostep g (ptr? ty ? ty ['ptr 'void]) @ 'bad 'bad
                             sz (locp g o @ (_ t fo) (lomk g @ n
                                   (lost g lb [(ptr? ty ? ty (rbin g ty 'int)) n [['mov n t] ['add n n (step * sz)]]] @
                                      (fs _) [ty t (lolvfs l + fo + fs)] 'bad))))))))
         ('rmw op dst rhs)
          (lolv g env dst @ 'bad 'bad
             l (: lb (lolvbare l)
                  vo (lorv g lb) vr (lox g env rhs)
                  (lobin g op vo vr (elem op '(shl shr) ? (lok g rhs)) @ 'bad 'bad
                     r (lost g lb r @ (fs (ty x _)) [ty x (lolvfs l + fs)] 'bad))))
         ('cast 'void x) (lox g env x @ (_ _ fs) ['void () fs] 'bad)
         ('cast ty x)
          (lox g env x @ ((vt r fs) && losc? ty && losc? vt)
                          (two? (cvt ty r) ? (locp g [vt r fs] @ (_ t f2) [ty t (f2 + cvt ty t)]) [ty r fs])
                         'bad)
         ; -1 and ~0 are literals, typed as C reads them
         (('un _ _) && two? (litv e)) (lox g env ['num <(litv e)])
         ('un 'not x)
          (lox g env x @ ((ty r fs) && losc? ty) (lomk g @ d ['int d (fs + [['cmp r 0] ['set 'eq d]])]) 'bad)
         (('un op x) && elem op '(neg bnot))
          (lox g env x @ ((ty r fs) && losc? ty)
             (: uty (usg? ty && !(elem ty '(uchar cchar ushort)))
                sty (op = 'neg && !uty && s32bin? g ty 'int)
                (locp g [ty r fs] @ (_ d f2)
                   [(? uty ty sty 'int 'long) d
                    (f2 + [[(op = 'neg ? 'neg 'not) d]] + (? uty (ty @ 'uint [['zx4 d]] ()) sty [['sx4 d]] ()))]))
             'bad)
         ('comma a b) (lox g env a @ (_ _ fa) (lox g env b @ (t r fb) [t r (fa + fb)] 'bad) 'bad)
         (('land || 'lor) . _)
          (nlab g ".lo" @ lf (nlab g ".lo" @ ld (lomk g @ d
             (lobr g env e 0 lf @ 'bad 'bad
                f ['int d (f + [['li d 1] ['jmp ld] ['label lf] ['li d 0] ['label ld]])]))))
         ('cond c a b)
          (nlab g ".lo" @ le (nlab g ".lo" @ ld
             (lobr g env c 0 le @ 'bad 'bad
                fc (lox g env a @ 'bad 'bad
                      va (lox g env b @ 'bad 'bad
                            vb (? (vty va = 'void || vty vb = 'void)
                                   ['void () (fc + vfs va + [['jmp ld] ['label le]] + vfs vb + [['label ld]])]
                                  !(losc? (vty va) && losc? (vty vb)) 'bad
                                  (: ta (vty va) tb (vty vb)
                                     rt (? (ptr? ta) ta (ptr? tb) tb (rbin g ta tb))
                                     (loz g (lotr g va rt) vb @ (_ x fx) (loz g (lotr g vb rt) va @ (_ y fy) (lomk g @ d
                                        [rt d (fc + fx + [['mov d x] ['jmp ld] ['label le]] + fy + [['mov d y] ['label ld]])]))))))))))
         ('bin op a b)
          (: kb (elem op '(shl shr) ? (lok g b))
             va (lox g env a)
             vb (two? kb ? ['int () ()] (lox g env b))
             (lobin g op va vb kb))
         ('call fh as) (locall g env fh as)
         (lono g ['expr <e]))

   ; a call: the first six gp scalars in registers, the rest in a 16-aligned block at sp. a
   ; direct callee is a known fn, an indirect one a pointer value read after the args
   (locall g env fh as)
    (fh @ (('var nm) && bad? (lovar g env nm) && g 'fns nm)
           (g 'sigs nm @
              ((rt . ptys . va . rest) && !(1 < #nm && nm 0 = 95 && nm 1 = 95) && !(rest @ ('ms . _) 1 ()))
               (locall1 g env rt ptys va as [['call (intern nm)]] ())
              (lono g ['call nm]))
          _ (lox g env fh @
               (('ptr ('fn rt ptys)) r fs) (locall1 g env rt ptys 1 as [['callr r]] [r fs])
               (('ptr ('fn rt)) r fs) (locall1 g env rt () 1 as [['callr r]] [r fs])
               'bad 'bad
               (ty . _) (lono g ['callee ty])))
   ; cl the call form, fv the callee's (vreg forms) | (); va also lays al, the vector count
   (locall1 g env rt ptys va as cl fv)
    (? !(rt = 'void || losc? rt) (lono g ['ret rt])
       (0 < #ptys && !va && #as != #ptys) (lono g 'arity)
       (: (arg e pt)
           (lox g env e @ ((vt r fs) && losc? vt)
                           (pt @ 'none [vt r fs] p9 (losc? p9 ? (lotr g [vt r fs] p9) (lono g ['arg p9])))
                          'bad 'bad
                          (vt . _) (lono g ['arg vt]))
          (go l i acc)
           (l @ (e . u) (arg e (i < #ptys ? (ptys i) 'none) @ 'bad 'bad v (go u (i + 1) (acc + [v])))
                acc)
          (go as 0 () @ 'bad 'bad
             vs (: n (min 6 #vs) rs (take n argregs) d (lomk g)
                   sk (drop 6 vs) blk (aup (8 * #sk) 16)
                   al (va ? [['li 'r0 0]])
                   res (rt @ 'void () (['mov d 'r0] . map (f \ [<f d]) (rext g rt)))
                   [rt (rt = 'void ? () d)
                    (catmap vfs vs + (fv @ (_ ffs) ffs ()) +
                     (blk = 0 ? () ([['sub 'sp 'sp blk]] + map (k \ ['st 'sp (8 * k) (vreg (sk k))]) ^#sk)) +
                     map (k \ ['mov (rs k) (vreg (vs k))]) ^n + al +
                     [('(cuse) + rs + (va ? '(r0)) + (fv @ (fr _) [fr] ()))] + cl +
                     (blk = 0 ? () [['add 'sp 'sp blk]]) + res)]))))

   ; -- statements -> forms | 'bad --
   (lost1 g env s)
    (: (st x e2 _) (lost1 g e2 x)
       (br x s L _) (lobr g env x s L)
       (s @ () ()
            ((_ . _) . _) (loitems g env s)
            ('nop . _) ()
            ('tdef . _) ()
            ('expr e) (lox g env e @ (_ _ fs) fs 'bad)
            ('ret) (peep g 'epi epi)
            ('ret e)
             (: rt <(peep (g 'sigs) (g 'fn) ['long ()]) epj (peep g 'epi epi)
                (lox g env e @ 'bad 'bad
                   ((_ _ fs) && rt = 'void) (fs + epj)
                   ((vt r fs) && losc? rt && losc? vt) (lotr g [vt r fs] rt @ (_ c f2) (f2 + [['mov 'r0 c]] + epj))
                   'bad))
            ('blk items) (loitems g env items)
            ('if c t)
             (nlab g ".lo" @ le (loseq [(br c 0 le) (st t env) (lol [['label le]])]))
            ('if c t el)
             (nlab g ".lo" @ le (nlab g ".lo" @ ld
                (loseq [(br c 0 le) (st t env) (lol [['jmp ld] ['label le]]) (st el env) (lol [['label ld]])])))
            ('while c body)
             (nlab g ".lo" @ lc (nlab g ".lo" @ lb
                (loseq [(lol [['label lc]]) (br c 0 lb) (st body (['brk lb] . ['cont lc] . env)) (lol [['jmp lc] ['label lb]])])))
            ('do body c)
             (nlab g ".lo" @ lt (nlab g ".lo" @ lc (nlab g ".lo" @ lb
                (loseq [(lol [['label lt]]) (st body (['brk lb] . ['cont lc] . env)) (lol [['label lc]]) (br c 1 lt) (lol [['label lb]])]))))
            ('for init c stp body)
             (nlab g ".lo" @ lt (nlab g ".lo" @ lc (nlab g ".lo" @ lb
                ((init @ () [() env]
                         ('decl ps) (lodecl g env ps)
                         (_ x) (lox g env x @ (_ _ fs) [fs env] 'bad)
                         'bad) @
                 (fi e1)
                  (loseq [(lol (fi + [['label lt]])) (u \ (c @ () () _ (lobr g e1 c 0 lb)))
                          (st body (['brk lb] . ['cont lc] . e1)) (lol [['label lc]])
                          (u \ (stp @ () () _ (lox g e1 stp @ (_ _ fs) fs 'bad))) (lol [['jmp lt] ['label lb]])])
                  'bad))))
            ('brk . _) (assoc 'brk env @ (_ L) [['jmp L]] 'bad)
            ('cont . _) (assoc 'cont env @ (_ L) [['jmp L]] 'bad)
            ('goto nm) [['jmp (name "\(g 'fn).\(nm)")]]
            ('lbl nm) [['label (name "\(g 'fn).\(nm)")]]
            ('switch ce body) (loswitch g env ce body)
            ('case lo hi) (assoc 'sw env @ (_ tab _) (peep tab "\(lo):\(hi)" () @ () 'bad L [['label L]]) 'bad)
            ('case cv) (assoc 'sw env @ (_ tab ty) (peep tab (lokey g ty cv) () @ () 'bad L [['label L]]) 'bad)
            ('dflt . _) (assoc 'sw env @ (_ tab _) (peep tab 'dflt () @ () 'bad L [['label L]]) 'bad)
            (lono g ['stmt <s])))
   (lokey g ty cv) (charm? cv ? (cfit g ty cv) 'bad)
   ; a switch as a compare chain: its cases, nested switches aside, each take a label
   (loswitch g env ce body)
    (lox g env ce @ ((ty r fs) && losc? ty)
       (: tab {}
          (walk x) (x @ ('switch . _) 0
                        ('case cv) (lokey g ty cv @ 'bad (pin tab 'bad 1) k (pin tab k (nlab g ".lo")))
                        ('case lo hi)
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
   ; a block's items, decls threading the env
   (loitems g env items)
    (: (go l env acc)
        (l @ (('decl ps) . u) (lodecl g env ps @ (fs e2) (go u e2 (acc + fs)) 'bad)
             (it . u) (lost1 g env it @ 'bad 'bad fs (go u env (acc + fs)))
             acc)
       (go items env ()))
   ; -> [forms env] | 'bad
   (lodecl g env ps)
    (: (go l env acc)
        (l @ ((nm . ty . rest) . u)
              (: init (rest @ (i . _) i ())
                 (? (rest @ (_ . x . _) x ()) (lono g 'regasm)
                    (gvarr? ty) (lono g 'vla)
                    (init @ ('init . _) 1 ()) (lono g ['init ty])
                    (losc? ty && nelem nm (g 'lotk))
                     (lomk g @ r
                        (: e2 ([nm 'v r ty] . env)
                           (init @ () (go u e2 acc)
                                   _ (lox g env init @ 'bad 'bad
                                        v (lost g ['v r ty] v @ (fs _) (go u e2 (acc + fs)) 'bad)))))
                    (ntmp g ty @ off
                       (: e2 ([nm 'm off ty] . env)
                          (init @ () (go u e2 acc)
                                  _ (? !(losc? ty) (lono g ['init ty])
                                       (lox g env init @ 'bad 'bad
                                          v (lost g ['a ['long 'r4 ()] ty off] v @ (fs _) (go u e2 (acc + fs)) 'bad))))))))
             [acc env])
       (go ps env ()))

   ; -- the fn: params home off their registers, then the body -> forms over vregs | 'bad --
   ; MOON_LOLOG=1 names each fn and which path took it; MOON_LOONLY=fn keeps the new path to one fn, for bisecting
   (lofn g f params sig)
    ((getenv "MOON_LOONLY" @ () (lofn1 g f params sig) n (n = <>f ? (lofn1 g f params sig) 'bad)) @ r
       (getenv "MOON_LOLOG" @ () r _ (puts ";; lo \(<>f) \(bad? r ? "old \(show (g 'lowhy))" "new")\n", r)))
   (lofn1 g f params sig)
    (sig @ ((rt . _ . va . _) && !va && (rt = 'void || losc? rt) && #params <= 6 && all (p \ losc? <>p) params &&
            !(g 'hasasm || g 'twice || g 'abad || g 'sspf || two? (g 'ltaken)))
       (: _ (pins g 'lon 0 'lotk (lotaken (f 3) ()) 'lowhy ())
          (go l i env acc)
           (l @ ((nm . ty . _) . u)
                 (: A (argregs i)
                    (elem nm (g 'lotk) ?
                       (ntmp g ty @ off (go u (i + 1) ([nm 'm off ty] . env) (acc + cvt ty A + [[(stop ty) 'r4 off A]])))
                       (lomk g @ r (go u (i + 1) ([nm 'v r ty] . env) (acc + [['mov r A]] + cvt ty r)))))
                [acc env])
          (go params 0 () () @ (pe env)
             (loitems g env (f 3 @ ('blk items) items x [x]) @ 'bad 'bad
                body (lobuild g f (pe + body + fz0 g <>f + peep g 'epi epi)))))
       (pin g 'lowhy ['fn (sig @ (rt . p . va . _) [rt va (map (x \ <>x) params)] 'nosig)
                           (g 'hasasm) (g 'twice) (g 'abad) (g 'sspf) (two? (g 'ltaken))], 'bad))

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
