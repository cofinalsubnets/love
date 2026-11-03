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
    (? (gcplx? ty || gcplx? vt) (locxsame? vt ty ? [vt r fs] (locvt g [vt r fs] ty))
       (d128? ty || d128? vt) (lowtr g [vt r fs] ty)
       (lofl? ty || lofl? vt) (lotrf g [vt r fs] ty)
       (two? (cvt ty 'r0) && !(irfit? vt ty)) (lomk g @ t [ty t (fs + [['mov t r]] + cvt ty t)])
       [ty r fs])
   ; -- the wide pair: a value [ty [lo hi] fs], a local in memory; the kit's ops work rax:rdx, each in
   ; a fix over the registers it reads and writes --
   ; a value as a pair -> [fs lo hi] | 'bad: a word widens by its source's signedness
   (lopair g v)
    (v @ ([vt [l h] fs] && d128? vt) [fs l h]
         ([vt _ _] && losc? vt)
          (: u (usg? vt || ptr? vt)
             (lotr g v (u ? 'ulong 'long) @ [_ l fs]
                (lomk g @ h [(fs + (u ? [['li h 0]] [['mov h l] ['sar h 63]])) l h])))
         _ 'bad)
   ; ins [register vreg].. moved in, the kit's forms, the pair out of rax:rdx
   (lokit g ty pre ins uses defs body)
    (lomk g @ l (lomk g @ h
       [ty [l h] (pre + map (p \ ['mov <p <>p]) ins + [['fix uses defs body] ['mov l 'r0] ['mov h 'r2]])]))
   ; to or from the pair: a word widens, the pair read as a word is its low half, its truth either half
   (lowtr g v ty)
    (? (d128? ty) (lopair g v @ 'bad (lono g ['cast (vty v) ty]) [fs l h] [ty [l h] fs])
       (v @ ([vt [l _] fs] && d128? vt && losc? ty) (ty = 'bool ? (lotest g v @ [_ d f2] ['bool d f2]) (lotr g ['ulong l fs] ty))
            _ (lono g ['cast (vty v) ty])))
   ; a divisor whose high half is zero: an unsigned word, a literal no less than 0, or a pair widened so
   (lohz? v) (v @ ([vt _ fs] && !(d128? vt)) (usg? vt || ptr? vt || (fs @ [['li _ k]] (0 <= k) _ ()))
                  ([vt [_ h] fs] && d128? vt) (rev fs @ (['li x 0] . _) (x = h) _ ())
                  _ ())
   (lowbin g op a b kb)
    (: ta (vty a) tb (vty b) rt (wbin ta tb) u (rt = 'u128)
       (? (lofl? ta || lofl? tb) (lono g ['bin op ta tb])
          (elem op '(shl shr))
           (lopair g a @ 'bad 'bad
              [fa l h] (: k9 (? (op = 'shl) 'shl128 (usg? ta) 'shr128 'sar128)
                          v9 (? (op = 'shl) 'shl128v (usg? ta) 'shr128v 'sar128v)
                          (? !(d128? ta) (lono g ['bin op ta tb])
                             (two? kb) (? (<kb < 0 || 127 < <kb) (lono g ['shift <kb])
                                          (<kb = 0) [ta [l h] fa]
                                          (lokit g ta fa [['r0 l] ['r2 h]] '(r0 r2) '(r0 r2) [[k9 <kb]]))
                             (b @ ([_ [c _] fb] && d128? tb) (lokit g ta (fa + fb) [['r0 l] ['r2 h] ['r1 c]] '(r0 r1 r2) '(r0 r2) [[v9]])
                                  ([_ c fb] && losc? tb) (lokit g ta (fa + fb) [['r0 l] ['r2 h] ['r1 c]] '(r0 r1 r2) '(r0 r2) [[v9]])
                                  _ (lono g ['bin op ta tb])))))
          (lopair g a @ 'bad 'bad
             [fa al ah] (lopair g b @ 'bad 'bad
                [fb bl bh]
                 (: pre (fa + fb) lr [['r6 al] ['r5 ah] ['r0 bl] ['r2 bh]]
                    (op @ '+ (lokit g rt pre lr '(r0 r2 r5 r6) '(r0 r2) '((a128r r6 r5)))
                          ; s128r answers (r6:r5) - (rax:rdx), its operand pair spent
                          '- (lokit g rt pre lr '(r0 r2 r5 r6) '(r0 r2 r5 r6) '((s128r r6 r5)))
                          '* (lokit g rt pre lr '(r0 r2 r5 r6) '(r0 r1 r2) '((m128r r6 r5)))
                          ('& || '| || '^)
                           (lomk g @ l (lomk g @ h
                              [rt [l h] (pre + [['mov l al] [(irop op) l l bl] ['mov h ah] [(irop op) h h bh]])]))
                          ; 0/1 of (r6:r5) cond (rax:rdx)
                          ('eq || 'ne || 'lt || 'le || 'gt || 'ge)
                           (lomk g @ d ['long d (pre + map (p \ ['mov <p <>p]) lr +
                                                 [['fix '(r0 r2 r5 r6) '(r0 r1 r2) [['c128r (scc op u) 'r6 'r5]]] ['mov d 'r0]])])
                          ; u128 by a divisor whose high half is zero: the dividend in a cell at sp
                          ('/ || '%)
                           (u && lohz? b ?
                              (lokit g rt pre [['r6 al] ['r5 ah] ['r0 bl]] '(r0 r5 r6) '(r0 r1 r2)
                                 [['sub 'sp 'sp 16] ['st 'sp 0 'r6] ['st 'sp 8 'r5] [(op @ '/ 'dv128 'rm128) 'sp] ['add 'sp 'sp 16]])
                              (lono g ['bin op ta tb]))
                          (lono g ['bin op ta tb])))))))
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
          (lotr g v p @ [_ re f2] (lomk g @ t (lomkf g @ im [(f2 + [['li t 0] [(p = 'float ? 'movdxr 'movqxr) im t]]) re im])))
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
       rt (fa && fb ? '(struct "__cplx_float") cxdty)
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
   ; (x + yi) op (c + di) over the parts, in the old arms' order
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
          [fs x y] (lomk g @ t (lomk g @ k (lomkf g @ re (lomkf g @ im
                      (: f (p = 'float) (fl z w) [[(f ? 'movdrx 'movqrx) t w] ['li k (f ? 2147483648 -9223372036854775808)] ['xor t t k]
                                                 [(f ? 'movdxr 'movqxr) z t]]
                         (lopack g (vty v) p [(fs + fl re x + fl im y) re im]))))))))
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
    (? (d128? vt) (lomk g @ d ['int d (fs + [['mov d <r] ['or d d <>r] ['cmp d 0] ['set 'ne d]])])
       (lofl? vt)
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

   ; the names whose address the body takes live in memory, and every name under a call that
   ; returns twice: its second return restores no register
   (lotk? g nm) (g 'twice || elem nm (g 'lotk))
   (lotaken x acc)
    (x @ ['addr ['var n]] (elem n acc ? acc (n . acc))
         ; an asm's memory operand takes its name's address
         ('asm . _ . os . is . _)
          (foldl (a \ o \ (o @ (c . ['var n] . _) (any (k \ elem (c k) '(109 111)) ^#c && nelem n a ? (n . a) a) _ a))
                 (foldl (a \ y \ lotaken y a) acc x) (os + is))
         (_ . _) (foldl (a \ y \ lotaken y a) acc x)
         acc)

   ; -- the environment: (name 'v vreg ty) | (name 'm off ty), and ('brk L) ('cont L) ('sw tab ty) --
   (lovar g env nm)
    (assoc nm env @ (_ . en) en
       ; a global register variable is its register
       (peep (g 'gregs) nm () @ (s . y . _) (gas-regname (gtgt g) s @ r (nom? r ? ['v r y] 'bad))
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
                   (lofill g env off ty ini @ 'bad 'bad fs ['a ['long 'r4 (lozero g off (aup (tsz g ty) 8) + fs)] ty off])
                   (lox g env (ini @ ['init (x . _)] x ['init ()] ['num 0] _ ini) @ 'bad 'bad
                      v (lost g ['a ['long 'r4 ()] ty off] v @ [fs _] ['a ['long 'r4 fs] ty off] 'bad)))))
         ; a struct rvalue (a call's, a cond's): its address
         (lox g env e @ ([ty r fs] && stru? ty) ['a [ty r fs] ty 0] 'bad 'bad _ (lono g ['lval <e])))
   ; the type of e without its forms (arrays undecayed), every accumulator handed back: peekty over a lo env
   (lopeek g env e)
    (: o0 (peep g 'off 0) sl0 (g 'slots) s0 (g 'strs) fe0 (g 'fesc) w0 (g 'lowhy)
       ty (lolv g env e @ (('v || 'a || 'b) . _ . ty . _) ty _ (lox g env e @ [t _ _] t _ 'bad))
       (pins g 'off o0 'slots sl0 'strs s0 'fesc fe0 'lowhy w0, ty))
   ; a register variable named as an asm operand: its register | ()
   (lovpin g env e) (e @ ['var nm] (lovar g env nm @ ['v r _] (g 'lopins r) _ ()) _ ())
   ; a refusal, its first cause kept for MOON_LOLOG
   (lono g why) (g 'lowhy @ () (pin g 'lowhy why, 'bad) _ 'bad)
   ; a frame address become a value: no sibling call may jump past it
   ; a frame address become a value: sibcalls stop, a musttail still jumps
   (loesc g r) (r @ 'r4 (pin g 'fescv 1) 0)
   ; a scalar load from an address
   (loload g [_ r fs] ty off)
    (? (losc? ty) (lomk g @ t [ty t (fs + [[(ldop ty) t r off]])])
       (lofl? ty) (lomkf g @ t [ty t (fs + [[(ty = 'float ? 'ldss 'ldsd) t r off]])])
       (d128? ty) (lomk g @ l (lomk g @ h [ty [l h] (fs + [['ld l r off] ['ld h r (off + 8)]])]))
       (lono g ['load ty]))
   ; an lvalue's value: an array decays, an aggregate refuses
   (lorv g lv)
    (lv @ ['v r ty] [ty r ()]
          ['a [_ r fs] (('arr || 'varr) . et . _) off] (lomk g @ t (loesc g r, [['ptr et] t (fs + [['lea t r off]])]))
          (['a [_ r fs] ty off] && stru? ty) (lomk g @ t (loesc g r, [ty t (fs + [['lea t r off]])]))
          ; a function designator decays to its address
          ['a [_ r fs] ('fn . ft) off] (lomk g @ t (loesc g r, [['ptr ('fn . ft)] t (fs + [['lea t r off]])]))
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
          (['a [_ b _] ty off] && d128? ty)
           (lotr g v ty @ [_ [l h] fs] [(fs + [['st b off l] ['st b (off + 8) h]]) [ty [l h] ()]] _ 'bad)
          (['a _ ty _] && gcplx? ty && !(locxsame? (vty v) ty)) (lotr g v ty @ 'bad 'bad v2 (lost g lv v2))
          (['a [_ b _] ty off] && stru? ty)
           (v @ ([vt r fs] && stru? vt && tsz g vt = tsz g ty)
                 (lomk g @ t (loesc g b, [(fs + locopy g r b off (tsz g ty) + [['lea t b off]]) [ty t ()]]))
                _ (lono g ['store ty]))
          (_ . _ . ty . _) (lono g ['store ty])
          'bad)
   ; sz bytes from address s to d + doff, widest first
   (locopy g s d doff sz)
    (lomk g @ t
       (: (go k) (? (8 <= sz - k) (['ld t s k] . ['st d (doff + k) t] . go (k + 8))
                    (4 <= sz - k) (['ldu4 t s k] . ['st4 d (doff + k) t] . go (k + 4))
                    (2 <= sz - k) (['ldu2 t s k] . ['st2 d (doff + k) t] . go (k + 2))
                    (1 <= sz - k) (['ldu1 t s k] . ['st1 d (doff + k) t] . go (k + 1))
                    ())
          (go 0)))
   ; an aggregate in the frame: zeroed, then filled from its braces (cgzero and cgfill's arms)
   (lozero g off span)
    (lomk g @ z
       (: (go o rem) (? (8 <= rem) (['st 'r4 o z] . go (o + 8) (rem - 8))
                        (0 < rem) (['st1 'r4 o z] . go (o + 1) (rem - 1))
                        ())
          (['li z 0] . go off span)))
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
    (? (aggish? ty && (val @ ('init . _) 1 ()) || arr? ty && (val @ ('str . _) 1 ())) (lofill g env off ty val)
       (stru? ty) (lox g env val @ 'bad 'bad v (lost g ['a ['long 'r4 ()] ty off] v @ [fs _] fs 'bad))
       (arr? ty) (lono g ['init ty])
       (lox g env val @ 'bad 'bad v (lost g ['a ['long 'r4 ()] ty off] v @ [fs _] fs 'bad)))

   ; the lvalue's own forms, laid once before its use, and the lvalue without them
   (lolvfs lv) (lv @ (('a || 'b) . [_ _ fs] . _) fs ())
   (lolvbare lv) (lv @ [k [t r _] ty off] [k [t r ()] ty off] lv)

   ; a pointer to a VLA steps by its row's bytes, the dim evaluated at the step: p +- i, i + p, p - q
   ; as the char arithmetic they are -> an expression | ()
   (lovrow g ty) (ty @ ['ptr ('varr . el . n . _)] ['bin '* ['cast 'long n] ['num (tsz g el)]] _ ())
   (lovstep g op a b va vb)
    (: ra (lovrow g (vty va)) rb (lovrow g (vty vb)) (cp x) ['cast ['ptr 'char] x]
       (? !(elem op '(+ -)) ()
          (ra && rb) (op = '- ? ['bin '/ ['bin '- (cp a) (cp b)] ra])
          ra ['cast (vty va) ['bin op (cp a) ['bin '* b ra]]]
          (rb && op = '+) ['cast (vty vb) ['bin '+ (cp b) ['bin '* a rb]]]
          ()))
   ; -- binary operators over two values --
   (locmp? op) (elem op '(eq ne lt le gt ge))
   (lobin g op a b kb)
    (? (bad? a || bad? b) 'bad
       (gcplx? (vty a) || gcplx? (vty b)) (locxbin g op a b)
       (d128? (vty a) || d128? (vty b)) (lowbin g op a b kb)
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
              (: nar (nar32 g op ta tb 1) rt (lonrw op a b (rbin g ta tb))
                 ; a literal right side rides as the immediate
                 (b @ ([_ t [['li t2 k]]] && t = t2 && fits32 k) (lomk g @ d [rt d (vfs a + [['mov d (vreg a)] [(irop op) d d k]] + (nar ? [[nar d]]))])
                      _ (lomk g @ d [rt d (vfs a + vfs b + [['mov d (vreg a)] [(irop op) d d (vreg b)]] + (nar ? [[nar d]]))])))
             (elem op '(/ %))
              (: u (cmpu g ta tb) io (op = '/ ? (u ? 'udiv 'div) (u ? 'urem 'rem))
                 (loz g a b @ [_ x fx] (loz g b a @ [_ y fy] (lomk g @ d
                    [(rbin g ta tb) d (fx + fy + [(io @ ('rem || 'urem) [io d x y 'r0] [io d x y])])]))))
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
            (['bin op a b] && locmp? op)
             (lox g env a @ 'bad 'bad
                va (lox g env b @ 'bad 'bad
                      vb (? !(losc? (vty va) && losc? (vty vb))
                             (lobin g op va vb () @ [_ d fs] (fs + [['cmp d 0] ['br (sense ? 'ne 'eq) L]]) 'bad)
                            (loz g va vb @ [_ x fx] (loz g vb va @ [_ y fy]
                               (fx + fy + [['cmp x y] ['br (scc (sense ? op (negrel op)) (cmpu g (vty va) (vty vb))) L]]))))))
            (lox g env e @ ([ty r fs] && losc? ty) (fs + [['cmp r 0] ['br (sense ? 'ne 'eq) L]])
                           ([ty r fs] && (lofl? ty || d128? ty)) (lotest g [ty r fs] @ [_ d f2] (f2 + [['cmp d 0] ['br (sense ? 'ne 'eq) L]]))
                           'bad))))

   ; -- expressions -> (ty vreg forms) | 'bad --
   (lox g env e)
    (e @ () ['void () ()]
         ['num v]
          (? (-9223372036854775808 <= v && v <= 18446744073709551615) (lomk g @ t [(numty v) t [['li t v]]])
             ; past the word: the wide pair, split by // and % (a big has no bitwise ops)
             ((v < 0 ? (v + 64 2 * 64 2) v) % (64 2 * 64 2) @ u
                (lomk g @ l (lomk g @ h ['u128 [l h] [['li l (u % 18446744073709551616)] ['li h (u // 18446744073709551616)]]]))))
         ; sizeof a VLA local: its stashed bytes; a VLA type: its dim times its row
         ['szof e2]
          (lopeek g env e2 @
             ('varr . _ . _ . k . _) (peep (g 'vslots) k () @ [_ so] (lomk g @ t ['ulong t [['ld t 'r4 so]]]) _ (lono g 'vla))
             ('varr . el . n . _) (lox g env ['cast 'ulong ['bin '* ['cast 'long n] ['num (tsz g el)]]])
             'bad 'bad
             ty (lomk g @ t ['ulong t [['li t (tsz g ty)]]]))
         ; gcc's &&L
         ['laddr nm] (lomk g @ t [['ptr 'void] t [['la t (name "\(g 'fn).\(nm)")]]])
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
                          (? (d128? ty)
                              ; the pair steps by one in the kit, the old answers
                              (o @ ([_ [ol oh] fo] && (step = 1 || step = -1))
                                    (lokit g ty fo [['r0 ol] ['r2 oh]] '(r0 r2) '(r0 r2) [[(step = 1 ? 'inc128 'dec128)]] @
                                       n (lost g lb n @ [fs _] [ty [ol oh] (lolvfs l + fs)] 'bad))
                                   _ (lono g ['post ty]))
                             (lofl? ty) (lopostf g env l lb o step)
                             (lostep g (ptr? ty ? ty ['ptr 'void]) @ 'bad 'bad
                             sz (locp g o @ [_ t fo] (lomk g @ n
                                   (lost g lb [(ptr? ty ? ty (rbin g ty 'int)) n ([['mov n t] ['add n n (step * sz)]] + (s32bin? g ty 'int ? [['sx4 n]]))] @
                                      [fs _] [ty t (lolvfs l + fo + fs)] 'bad)))))))))
         ['rmw op dst rhs]
          (lolv g env dst @ 'bad 'bad
             l (: lb (lolvbare l)
                  vo (lorv g lb) vr (lox g env rhs)
                  (lobin g op vo vr (elem op '(shl shr) ? (lok g rhs)) @ 'bad 'bad
                     r (lost g lb r @ [fs [ty x _]] [ty x (lolvfs l + fs)] 'bad))))
         ['cast 'void x] (lox g env x @ [_ _ fs] ['void () fs] 'bad)
         ['cast 'float ['flo v]] (lomk g @ t (lomkf g @ w ['float w [['li t (fbits32 v)] ['movdxr w t]]]))
         ; a float of a wide value: a constant only, folded exactly, as the old path
         (['cast ty x] && lofl? ty && d128? (lopeek g env x))
          (cfold 1 x @ (v && cint? v) (lox g env ['cast ty ['flo (0.0 + v)]]) _ (lono g ['cast 'u128 ty]))
         ['cast ty x]
          (lox g env x @ ([vt r fs] && (gcplx? ty || gcplx? vt) && (losv? ty || gcplx? ty)) (lotr g [vt r fs] ty)
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
          (lox g env x @ ([ty r fs] && losc? ty) (lomk g @ d ['int d (fs + [['cmp r 0] ['set 'eq d]])])
                         ([ty r fs] && (lofl? ty || d128? ty)) (lotest g [ty r fs] @ [_ t f2] (lomk g @ d ['int d (f2 + [['cmp t 0] ['set 'eq d]])]))
                         'bad)
         (['un op x] && elem op '(neg bnot))
          (lox g env x @ ([ty r fs] && gcplx? ty && op = 'neg) (locxneg g [ty r fs])
                         ([ty [l h] fs] && d128? ty)
                          (op = 'neg ? (lokit g ty fs [['r0 l] ['r2 h]] '(r0 r2) '(r0 r2) '((n128)))
                             (lomk g @ l2 (lomk g @ h2 [ty [l2 h2] (fs + [['mov l2 l] ['not l2] ['mov h2 h] ['not h2]])])))
                         ([ty r fs] && losc? ty)
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
                                  ; two structs: the chosen one's address
                                  (stru? (vty va) && stru? (vty vb))
                                   (tsz g (vty va) != tsz g (vty vb) ? (lono g ['cond (vty va) (vty vb)])
                                      (lomk g @ d [(vty va) d (fc + vfs va + [['mov d (vreg va)] ['jmp ld] ['label le]] +
                                                               vfs vb + [['mov d (vreg vb)] ['label ld]])]))
                                  ; a wide side: both as the pair, each half joined
                                  (d128? (vty va) || d128? (vty vb))
                                   (: rt (wbin (vty va) (vty vb))
                                      (lotr g va rt @ [_ [xl xh] fx]
                                         (lotr g vb rt @ [_ [yl yh] fy]
                                            (lomk g @ l (lomk g @ h
                                               [rt [l h] (fc + fx + [['mov l xl] ['mov h xh] ['jmp ld] ['label le]] +
                                                          fy + [['mov l yl] ['mov h yh] ['label ld]])]))
                                            _ 'bad)
                                         _ 'bad))
                                  !(losv? (vty va) && losv? (vty vb)) (lono g ['cond (vty va) (vty vb)])
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
             (lovstep g op a b va vb @ () (lobin g op va vb kb) x (lox g env x)))
         ; x86's caches are coherent: the args for their effects alone
         ['call ['var "__builtin___clear_cache"] as] (loseq (map (x \ (lox g env x @ [_ _ fs] (lol fs) _ (lol 'bad))) as) @ 'bad 'bad fs ['void () fs])
         ['call fh as] (lomem g env fh as @ 'no (locall g env fh as) v v)
         ; the va_list's fields, as cgexpr's SysV arms lay them
         ['vastart ap]
          (lox g env ap @ [_ p fs]
             (lomk g @ t (pin g 'fesc 1,
                ['void () (fs + [['li t (8 * peep g 'vagp 0)] ['st4 p 0 t] ['li t (48 + 16 * peep g 'vaxmm 0)] ['st4 p 4 t]
                                 ['lea t 'r4 (16 + 8 * peep g 'vaov 0)] ['st p 8 t] ['lea t 'r4 (peep g 'rsa 0)] ['st p 16 t]])]))
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
              (rt . ptys . va . rest)
               (locall1 g env rt ptys va (rest @ ('ms . _) 1 ()) as [['call (intern nm)]] ())
              (lono g ['call nm]))
          _ (lox g env fh @
               [['ptr ['fn rt ptys]] r fs] (locall1 g env rt ptys 1 () as (locr g r) [r fs])
               [['ptr ['fn rt ptys 'ms]] r fs] (locall1 g env rt ptys () 1 as (locr g r) [r fs])
               [['ptr ['fn rt]] r fs] (locall1 g env rt () 1 () as (locr g r) [r fs])
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
                                          ['fix '(r0 r1) '(r0 r1)
                                            [['raw ([72] + (nm @ "__builtin_add_overflow" [1 200] "__builtin_sub_overflow" [41 200] _ [15 175 193])
                                                    + [15 144 193 72 15 182 201])]]]
                                          ['mov t 'r0] ['mov d 'r1] ['st p 0 t]])])))))
              x (lox g env x)))
       ; |x| is infinite: the bits shifted past the sign are inf's
       (nm = "__builtin_isinf")
        (lox g env <as @ ([vt r f0] && lofl? vt)
           (lotr g [vt r f0] 'double @ [_ w fs]
              (lomk g @ t (lomk g @ k (lomk g @ d
                 ['long d (fs + [['movqrx t w] ['shl t 1] ['li k 18437736874454810624] ['cmp t k] ['set 'eq d]])]))))
           _ (lono g ['call nm]))
       ; an infinity, a quiet NaN (the tag ignored): their bits
       (elem nm '("__builtin_inf" "__builtin_nan" "__builtin_nanf"))
        (lomk g @ t (lomkf g @ w ['double w [['li t (nm = "__builtin_inf" ? 9218868437227405312 9221120237041090560)] ['movqxr w t]]]))
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
   ; ms an ms_abi callee: ints only, rcx rdx r8 r9 then the stack above a 32-byte shadow
   (locall1 g env rt ptys va ms as cl fv)
    (? !(rt = 'void || losv? rt || d128? rt || loagg? g rt) (lono g ['ret rt])
       (ms && any (t \ d128? t) (rt . ptys)) (lono g 'msabi)
       (ms && any (t \ lofl? t || stru? t) (rt . ptys)) (lono g 'msabi)
       (0 < #ptys && !va && #as != #ptys) (lono g 'arity)
       (: (arg e pt)
           (lox g env e @ ([vt r fs] && (losv? vt || d128? vt))
                           (pt @ 'none (vt = 'float ? (lotr g [vt r fs] 'double) [vt r fs])
                                 p9 (losv? p9 || d128? p9 ? (lotr g [vt r fs] p9) (lono g ['arg p9])))
                          ([vt r fs] && loagg? g vt) [vt r fs]
                          'bad 'bad
                          (vt . _) (lono g ['arg vt]))
          (go l i acc)
           (l @ (e . u) (arg e (i < #ptys ? (ptys i) 'none) @ 'bad 'bad v (go u (i + 1) (acc + [v])))
                acc)
          ; a returned aggregate lands in a temp; in the memory class its address is the hidden first arg
          sret (stru? rt && !(two? (aclass g rt)))
          (go as 0 () @ 'bad 'bad
             vs (: rto (stru? rt ? (ntmp g rt) 0)
                   hv (sret ? (lomk g @ h [[['ptr rt] h [['lea h 'r4 rto]]]]))
                   pl (ms ? [0 0 (map (i \ [('(r1 r2 r7 r8) i) (vreg (vs i))]) ^(min 4 #vs))
                             (map (i \ ['w (vs i) 8]) (filter (i \ 3 < i) ^#vs)) ()]
                          (loplace g (hv + vs)))
                   sh (ms ? 32 0)
                   nf (pl 1) rg (pl 2) sk (pl 3) pre (pl 4) rs (map (x \ <x) rg)
                   d (d128? rt ? [(lomk g) (lomk g)] (lomkt g rt))
                   ; -mskip-rax-setup: no count of the vector registers in al
                   al (va && !(x86k? g 'nal) ? [['li 'r0 nf]])
                   (stk x o) (x @ ['w2 v _] [['st 'sp o <(vreg v)] ['st 'sp (o + 8) <>(vreg v)]]
                                  ['w v _] [[(vty v @ 'float 'stss 'double 'stsd 'st) 'sp o (vreg v)]]
                                  ['s v n] (locopy g (vreg v) 'sp o n))
                   ; a pair on the stack sits 16-aligned
                   (sgo l o acc) (l @ (x . u) ((x @ ['w2 . _] (aup o 16) _ o) @ p (sgo u (p + x 2) (acc + stk x p))) [o acc])
                   so (sgo sk sh ()) sfs (so 1) blk (aup <so 16)
                   res (? (rt = 'void) ()
                          (lofl? rt) [['movapd d 'f0]]
                          (d128? rt) [['mov <d 'r0] ['mov <>d 'r2]]
                          (stru? rt) (loesc g 'r4, (sret ? () (loebst g (aclass g rt) 'r4 rto)) + [['lea d 'r4 rto]])
                          (['mov d 'r0] . map (f \ [<f d]) (rext g rt)))
                   [rt (rt = 'void ? () d)
                    (catmap vfs (hv + vs) + (fv @ [_ ffs] ffs ()) + pre +
                     (blk = 0 ? () ([['sub 'sp 'sp blk]] + sfs)) +
                     map (p \ lomv <p <>p) rg + al +
                     [('(cuse) + rs + (two? al ? '(r0)) + (fv @ [fr _] [fr] ()))] + cl +
                     res + (blk = 0 ? () [['add 'sp 'sp blk]]))]))))
   ; the last call of a musttail ret's forms, marked 'must, as the old path's mustret | 'bad
   (lomust g fs)
    (: (go l) (l @ () (lono g 'musttail)
                   ((f . u) && two? f && elem <f '(call callr)) ((f + '(must)) . u)
                   (f . u) (go u @ 'bad 'bad r (f . r)))
       (go (rev fs) @ 'bad 'bad r (rev r)))
   ; an indirect call through the old path's park, the one register its sibcall jumps by
   (locr g r) [['mov (pkr g) r] ['callr (pkr g)]]
   ; an aggregate the SysV rules carry by value: classed in eightbytes, or the memory class
   (loagg? g ty) (stru? ty && 0 < tsz g ty && asalign g ty <= 8)
   ; the args to their registers in order, each file its own count; an aggregate's eightbytes take
   ; registers only all together, else it goes whole to the block -> [nf rg sk pre]: rg [reg vreg]..,
   ; sk ['w v 8] | ['s v bytes].., pre the eightbyte loads
   (loplace g vs)
    (foldl (s \ v \ (s @ [gi fi rg sk pre]
              (: ty (vty v) x (vreg v)
                 (? (d128? ty)
                     (gi + 2 <= 6 ? [(gi + 2) fi (rg + [[(argregs gi) <x] [(argregs (gi + 1)) <>x]]) sk pre]
                        [gi fi rg (sk + [['w2 v 16]]) pre])
                    (stru? ty)
                     (: cls (aclass g ty) sz (tsz g ty)
                        ng #(filter (c \ c = 'int) cls) nx (#cls - ng)
                        (two? cls && gi + ng <= 6 && fi + nx <= 8 ?
                           (foldl (t \ i \ (t @ [gi fi rg sk pre]
                                     (: c (cls i) n (min 8 (sz - 8 * i))
                                        (loeb g c x (8 * i) n @ [w fs]
                                           (c = 'sse ? [gi (fi + 1) (rg + [[(xmmreg fi) w]]) sk (pre + fs)]
                                              [(gi + 1) fi (rg + [[(argregs gi) w]]) sk (pre + fs)])))))
                                  [gi fi rg sk pre] ^#cls)
                           [gi fi rg (sk + [['s v (8 * aslots g ty)]]) pre]))
                    (lofr? x) (fi < 8 ? [gi (fi + 1) (rg + [[(xmmreg fi) x]]) sk pre] [gi fi rg (sk + [['w v 8]]) pre])
                    (gi < 6) [(gi + 1) fi (rg + [[(argregs gi) x]]) sk pre]
                    [gi fi rg (sk + [['w v 8]]) pre]))))
           [0 0 () () ()] vs)
   ; eightbyte n bytes at a+off into a fresh vreg of class c -> [vreg forms]: exact widths, the
   ; odd ones by the old chunk arm
   (loeb g c a off n)
    (? (c = 'sse) (lomkf g @ w [w [[(n <= 4 ? 'ldss 'ldsd) w a off]]])
       (lomk g @ t [t (n @ 8 [['ld t a off]] 4 [['ldu4 t a off]] 2 [['ldu2 t a off]] 1 [['ldu1 t a off]]
                         _ (loren2 g () 'r2 'long (ldal 'r2 a off n 8) @ [_ y fs] (fs + [['mov t y]])))]))
   ; the return registers of classes cls: int takes rax then rdx, sse xmm0 then xmm1
   (loebregs cls)
    (foldl (s \ c \ (s @ [gs xs acc] (c = 'sse ? [gs (>xs) (acc + [<xs])] [(>gs) xs (acc + [<gs])])))
           ['(r0 r2) '(f0 f1) ()] cls @ [_ _ rs] rs)
   ; ..stored whole into the 8-aligned temp at b+off
   (loebst g cls b off)
    (loebregs cls @ rs (map (i \ [((rs i) @ ('f0 || 'f1) 'stsd _ 'st) b (off + 8 * i) (rs i)]) ^#cls))

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
            ; clay's (ret e PRE), a musttail: its call marked for the sibcall that must jump it
            ['ret e _] (lost1 g env ['ret e] @ 'bad 'bad fs (lomust g fs))
            ['ret e]
             (: rt <(peep (g 'sigs) (g 'fn) ['long ()]) epj (peep g 'epi epi)
                (lox g env e @ 'bad 'bad
                   ([_ _ fs] && rt = 'void) (fs + epj)
                   ; an int's upper half is the caller's to extend
                   ([vt r fs] && losv? rt && losv? vt)
                    (lotr g [vt r fs] (elem rt '(int uint) && losc? vt ? 'long rt) @ [_ c f2] (f2 + [(lomv (lofl? rt ? 'f0 'r0) c)] + epj))
                   ([vt r fs] && d128? rt && (losv? vt || d128? vt))
                    (lotr g [vt r fs] rt @ [_ [l h] f2] (f2 + [['mov 'r0 l] ['mov 'r2 h]] + epj) _ 'bad)
                   ; an aggregate: out through the hidden pointer, or its eightbytes into the return registers
                   ([vt r fs] && stru? rt && tsz g vt = tsz g rt)
                    (g 'losret @ () (: cls (aclass g rt) sz (tsz g rt)
                                       (foldl (t \ i \ (t @ [acc ws]
                                                 (loeb g (cls i) r (8 * i) (min 8 (sz - 8 * i)) @ [w f2] [(acc + f2) (ws + [w])])))
                                              [fs ()] ^#cls @
                                        [f2 ws] (f2 + map (i \ lomv (loebregs cls i) (ws i)) ^#cls + epj)))
                                 h (fs + locopy g r h 0 (tsz g rt) + [['mov 'r0 h]] + epj))
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
            ; goto *e: a table jump over every label whose address the fn takes
            ['igoto e]
             (map (nm \ name "\(g 'fn).\(nm)") (g 'ltaken) @
                () (lono g 'igoto)
                ls (lox g env e @ [_ r fs] (fs + [['jmpt r <ls ls]]) 'bad))
            ['lbl nm] [['label (name "\(g 'fn).\(nm)")]]
            ['switch ce body] (loswitch g env ce body)
            ['case lo hi] (assoc 'sw env @ [_ tab _] (peep tab "\(lo):\(hi)" () @ () 'bad L [['label L]]) 'bad)
            ['case cv] (assoc 'sw env @ [_ tab ty] (peep tab (lokey g ty cv) () @ () 'bad L [['label L]]) 'bad)
            ('dflt . _) (assoc 'sw env @ [_ tab _] (peep tab 'dflt () @ () 'bad L [['label L]]) 'bad)
            ('asm . _) (trap (s9 \ loasm g env s9) s (a \ b \ (a = 'leave ? (scare a b) (lono g ['asm a]))))
            (lono g ['stmt <s])))
   ; an asm, its operands seated as asmplan seats them: the values moved to their registers, the body
   ; one fix form reading the inputs' and writing the outputs' and the clobbers', the outputs stored
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
              [vt r fs] [fs (? (freg? a && lofr? r) ['movapd a r]
                               (freg? a) [(o 3 <= 4 ? 'movdxr 'movqxr) a r]
                               (lofr? r) [(vt = 'float ? 'movdrx 'movqrx) a r]
                               ['mov a r])])
          (st o a)
           (lolv g env (o 2) @
              'bad 'bad
              ; a struct or union a register holds whole stores as the integer its size is
              (['a av ty off] && stru? ty && <o = 'o && !(freg? a) && elem (tsz g ty) [1 2 4 8])
               (st1 o a ['a av (tsz g ty @ 1 'uchar 2 'ushort 4 'uint _ 'ulong) off])
              lv (st1 o a lv))
          (st1 o a lv)
           (lv 2 @ ty
              (stru? ty || arr? ty || lofl? ty && !(freg? a) ? (lono g 'asmout)
                 ; an xmm output into an integer lvalue: its bits
                 ((freg? a && lofl? ty ? (lomkf g) (lomk g)) @ t
                    [(freg? a && !(lofl? ty) ? [(o 3 <= 4 ? 'movdrx 'movqrx) t a] (lomv t a))
                     (lost g lv [ty t ()] @ [fs _] fs 'bad)])))
          ins (filter (i \ in? (ops i)) ^#ops)
          outs (filter (i \ out? (ops i)) ^#ops)
          lds (map (i \ ld (ops i) (asgn i)) ins)
          sts (map (i \ st (ops i) (asgn i)) outs)
          ; a goto's edges are not unframe's to see
          ab (asmbody g tgt neutral? txt)
          body (map (r \ ['push r]) saves + (two? labs ? ab (asmfsafe txt ab)) + map (r \ ['pop r]) (rev saves)
                + catmap (i \ (ops i @ ('f . _ . _ . _ . c . _) [['set c (asgn i)]] _ ())) outs)
          (any bad? lds || any bad? sts ? 'bad
             (: post (map (x \ <x) sts + catmap (x \ x 1) sts)
                fx ['fix (map asgn ins) (map asgn outs + kills) body tls]
                ; an asm goto with outputs jumps to a trampoline per label that stores them and goes on
                (catmap (x \ <x) lds + map (x \ x 1) lds +
                 (tls = labs ? (fx . post)
                    (nlab g "\(g 'fn).ag" @ done
                       ([fx ['jmp done]] + catmap (i \ [['label (tls i)]] + post + [['jmp (labs i)]]) ^#tls +
                        [['label done]] + post))))))))
   (lokey g ty cv) (cint? cv ? (cfit g ty cv) 'bad)
   ; a switch as a compare chain: its cases, nested switches aside, each take a label
   (loswitch g env ce body)
    (lox g env ce @ ([ty r fs] && losc? ty)
       (: tab {}
          (walk x) (x @ ('switch . _) 0
                        ['case cv] (lokey g ty cv @ 'bad (pin tab 'bad 1) k (pin tab k (nlab g ".lo")))
                        ['case lo hi]
                         (? !(cint? lo && cint? hi && lo <= hi) (pin tab 'bad 1)
                            ; a narrow range a label a value, a wide one a compare of its own
                            (nlab g ".lo" @ L
                               (pin tab "\(lo):\(hi)" L,
                                hi - lo < 64 ? (map (k \ pin tab (cfit g ty (lo + k)) L) ^(hi - lo + 1))
                                   (pin tab 'rng ([(cfit g ty lo) (hi - lo) L] . peep tab 'rng ())))))
                        ('dflt . _) (pin tab 'dflt (nlab g ".lo"))
                        (_ . _) (map walk x)
                        0)
          _ (walk body)
          (tab 'bad ? (lono g 'case)
             (nlab g ".lo" @ lb
                (: ks (sort (filter cint? (keys tab)))
                   dl (peep tab 'dflt lb)
                   tst (lojt g r tab ks dl @ () (lochain g r tab ks) fs fs)
                   (lost1 g (['brk lb] . ['sw tab ty] . env) body @ 'bad 'bad
                      fb (fs + tst + [['jmp dl]] + fb + [['label lb]]))))))
       'bad)
   ; memset and memcpy of a small constant size, straight-line, as the old path's cgmem: not where
   ; a local shadows the name or the fn is the library's own -> the destination | 'no
   (lomem g env fh as)
    (fh @ (['var bi] && string? bi && 3 = #as && !(abl? g 'meminl) && !(two? (assoc bi env)) && g 'fn != bi)
           (memk g (as 2) @ n
              (? !(charm? n && 0 <= n && n <= meminl g) 'no
                 (memnm? g bi "memset")
                  (memk g (as 1) @ c
                     (!(charm? c) ? 'no
                        (lox g env <as @ [_ d fd]
                           (lobase [_ d fd] @ [b o]
                              (lomk g @ v
                                 ['(ptr void) d (fd + [['li v ((c & 255) * 72340172838076673)]] +
                                                 map (k \ (k + 8 <= n ? ['st b (o + k) v] ['st1 b (o + k) v])) (lochunks n))]))
                           'bad)))
                 (memnm? g bi "memcpy")
                  (lox g env <as @ [_ d fd]
                     (lox g env <>as @ sv
                        (vfs sv @ fs (lobase [_ d fd] @ [db do] (lobase sv @ [sb so]
                           (lomk g @ t
                              ['(ptr void) d (fd + fs + catmap (k \ (k + 8 <= n ? [['ld t sb (so + k)] ['st db (do + k) t]]
                                                                            [['ldu1 t sb (so + k)] ['st1 db (do + k) t]])) (lochunks n))]))))
                        'bad)
                     'bad)
                 'no))
          _ 'no)
   ; a pointer as a base and offset: a local's address reads off the frame, its lea left to die
   ; where the value goes unused -> [base off]
   (lobase v) (v @ [_ t fs] (rev fs @ (['lea t2 'r4 o] . _) (t = t2 ? ['r4 o] [t 0]) _ [t 0]))
   ; the offsets of n bytes in words, then the byte tail
   (lochunks n) (map (i \ 8 * i) ^(n // 8) + map (i \ 8 * (n // 8) + i) ^(n % 8))
   ; a switch's compares: each key, then each wide range as r - lo unsigned at most the span
   (lochain g r tab ks)
    (catmap (k \ (fits32 k ? [['cmp r k] ['br 'eq (tab k)]] (lomk g @ t [['li t k] ['cmp r t] ['br 'eq (tab k)]]))) ks +
     catmap (x \ (x @ [lo n L] (lomk g @ t (lomk g @ k
                   ([['mov t r] ['li k lo] ['sub t t k]] + (fits32 n ? [['cmp t n]] [['li k n] ['cmp t k]]) + [['br 'be L]])))))
            (peep tab 'rng ()))
   ; the table lane, as the old path's jtable: six keys or more, a third full at least, no wide
   ; range, -fno-jump-tables off. rel32 cells off the table's label, one unsigned compare to the
   ; default -> forms | ()
   (lojt g r tab ks dl)
    (: n #ks lo (two? ks ? <ks 0) span (two? ks ? (ks (n - 1) - lo + 1) 0)
       (? (n < 6 || 4096 < span || span > 3 * n || two? (peep tab 'rng ()) || abl? g 'jtab || njt? g || !(fits32 lo)) ()
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
                 fs + [['mov z n]] + (es = 1 ? () [['imul z z es]]) + [['st 'r4 so z]] + up z +
                 [['mov q 'sp] ['sub q q z] ['mov 'sp q] ['st 'r4 po q]] +
                 ; -ftrivial-auto-var-init=zero: the block word by word, from its top down
                 (avz? g ? (lomk g @ k (lomk g @ a (nlab g ".vla" @ l1 (nlab g ".vla" @ l2
                    [['li k 0] ['label l1] ['cmp z 0] ['br 'eq l2] ['sub z z 8] ['mov a q] ['add a a z] ['st a 0 k]
                     ['jmp l1] ['label l2]]))))))))))))
       'bad 'bad
       _ (lono g 'vla)))
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
                        (peep (g 'vslots) (varix ty) () @
                           [po so] (lovla g env ty po so @ 'bad 'bad fs (go u ([nm 'p po ty] . env) (acc + fs)))
                           _ (lono g 'vla)))
                    (losv? ty && (init @ ('init . _) 1 ())) (lono g ['init ty])
                    (losv? ty && !(lotk? g nm))
                     (lomkt g ty @ r
                        (: _ (ap ? (pin (g 'lopins) r ap))
                           e2 ([nm 'v r ty] . env)
                           ; no init: a def that lays nothing, so the vreg lives from here; zero under
                           ; -ftrivial-auto-var-init=zero
                           (init @ () (go u e2 (acc + (? !(avz? g) [['cdef r]]
                                                           (lofl? ty) (lomk g @ t [['li t 0] [(ty = 'float ? 'movdxr 'movqxr) r t]])
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
                              (lofill g e2 off ty init @ 'bad 'bad fs (go u e2 (acc + lozero g off (aup (tsz g ty) 8) + fs)))
                             (stru? ty) (loelt g e2 off ty init @ 'bad 'bad fs (go u e2 (acc + fs)))
                             (lono g ['init ty]))))))
             [acc env])
       (go ps env ()))

   ; -- the fn: params home off their registers, then the body -> forms over vregs | 'bad --
   ; MOON_LOLOG=1 names each fn and which path took it; MOON_LOONLY=fn keeps the new path to one fn, for bisecting
   (lofn g f params sig)
    ((pins g 'lopeek lopeek 'lovpin lovpin 'lopins {}, getenv "MOON_LOONLY" @ () (lofn1 g f params sig) n (n = <>f ? (lofn1 g f params sig) 'bad)) @ r
       (pins g 'lopeek () 'lovpin (), getenv "MOON_LOLOG" @ () r _ (puts ";; lo \(<>f) \(bad? r ? "old \(show (g 'lowhy))" "new")\n", r)))
   (lofn1 g f params sig)
    (sig @ ((rt . _ . va . _) && (rt = 'void || losv? rt || d128? rt || loagg? g rt) && all (p \ losv? <>p || d128? <>p || loagg? g <>p) params &&
            !(g 'abad || g 'sspf))
       ; a returned aggregate of the memory class: its address comes in rdi and goes back in rax
       (: sret (stru? rt && !(two? (aclass g rt)))
          _ (pin g 'lon 0)
          sr (sret ? (lomk g))
          _ (pins g 'lotk (lotaken (f 3) ()) 'lowhy () 'losret sr
                  'loret (? (rt = 'void) () (lofl? rt) '(f0) (d128? rt) '(r0 r2) (stru? rt && !sret) (loebregs (aclass g rt)) '(r0)))
          ; the params, each file's registers in order, the rest above the link at ovb step 8
          (ovm ty ov) ['m (ovb g + 8 * ov) ty]
          ; the copies off the registers first, their conversions after (post)
          (go l gi fi ov env acc post)
           (l @ ((nm . ty . _) . u)
                 (? (d128? ty)
                     ; a pair: two gp registers, else 16-aligned above the link
                     (gi + 2 <= 6 ?
                        (ntmp g ty @ off (go u (gi + 2) fi ov ([nm 'm off ty] . env)
                                             (acc + [['st 'r4 off (argregs gi)] ['st 'r4 (off + 8) (argregs (gi + 1))]]) post))
                        ((ov + ov % 2) @ o (go u gi fi (o + 2) ((nm . ovm ty o) . env) acc post)))
                    (stru? ty)
                     (: cls (aclass g ty) ng #(filter (c \ c = 'int) cls) nx (#cls - ng)
                        (two? cls && gi + ng <= 6 && fi + nx <= 8 ?
                           (ntmp g ty @ off
                              (foldl (t \ i \ (t @ [gi fi fs]
                                        (cls i = 'sse ? [gi (fi + 1) (fs + [['stsd 'r4 (off + 8 * i) (xmmreg fi)]])]
                                           [(gi + 1) fi (fs + [['st 'r4 (off + 8 * i) (argregs gi)]])])))
                                     [gi fi ()] ^#cls @
                               [g2 f2 fs] (go u g2 f2 ov ([nm 'm off ty] . env) (acc + fs) post)))
                           (go u gi fi (ov + aslots g ty) ((nm . ovm ty ov) . env) acc post)))
                    (lofl? ty ? (8 <= fi) (6 <= gi)) (go u gi fi (ov + 1) ((nm . ovm ty ov) . env) acc post)
                    (: fl (lofl? ty) A (fl ? (xmmreg fi) (argregs gi)) g2 (fl ? gi (gi + 1)) f2 (fl ? (fi + 1) fi)
                       (lotk? g nm ?
                          (ntmp g ty @ off
                             (go u g2 f2 ov ([nm 'm off ty] . env)
                                 ; a narrow store narrows on its own
                                 (acc + [[(fl ? (ty = 'float ? 'stss 'stsd) (stop ty)) 'r4 off A]]) post))
                          (lomkt g ty @ r (go u g2 f2 ov ([nm 'v r ty] . env) (acc + [(lomv r A)]) (post + (fl ? () (cvt ty r))))))))
                [gi fi ov (acc + post) env])
          ; each VLA site's size cell reads 0 until its decl runs
          vz (keys (g 'vslots) @ () () ks (lomk g @ z (['li z 0] . map (k \ ['st 'r4 (g 'vslots k 1) z]) (sort ks))))
          (go params (sret ? 1 0) 0 0 () (sret ? [['mov sr 'r6]]) vz @ [gi fi ov pe env]
             (pins g 'vagp gi 'vaxmm fi 'vaov ov,
              (va ? (lovasave g)) @ vs
              (loitems g env (f 3 @ ['blk items] items x [x]) @ 'bad 'bad
                 body (lobuild g f (vs + pe + body + fz0 g <>f + peep g 'epi epi))))))
       (pin g 'lowhy ['fn (sig @ (rt . p . va . _) [rt va (map (x \ <>x) params)] 'nosig)
                           (g 'abad) (g 'sspf)], 'bad))

   ; a variadic fn (SysV): a 176-byte save area, gp at +0 step 8, xmm at +48 step 16
   (lovasave g)
    (nslot g 176 @ rsa
      (pins g 'rsa rsa 'fesc 1,
        map (i \ ['st 'r4 (rsa + 8 * i) (argregs i)]) ^6 +
        (nofp? g ? () (map (i \ ['stsd 'r4 (rsa + 48 + 16 * i) (xmmreg i)]) ^8))))

   ; allocated, then framed: the link, the frame, the saves marker csframe lays out
   (lobuild g f fs0)
    (radce g (getenv "MOON_NONM" @ () (nmall g fs0) _ fs0) @ fs
     ((getenv "MOON_LOLOG" @ "2" (map (x \ (putx x, putc 10)) fs) 0),
     raplan g fs @ 'bad (lono g 'ra)
       [f2 loc]
        ((getenv "MOON_LOLAW" @ () ()
            _ (rachk g fs f2 loc @ ws
                 (map (w \ (puts ";; lolaw \(<>f) ", putx w, putc 10)) (getenv "MOON_LOLOG" @ () () _ ws),
                  pins g 'lolawn (peep g 'lolawn 0 + 1) 'lolaw ((g 'lolaw) + map (w \ [<>f w]) ws)))),
         rasub f2 loc @ body
         ((getenv "MOON_LOLOG" @ "2" (puts ";; allocated\n", map (x \ (putx x, putc 10)) body) 0),
             sibcall g ([['label (name <>f)]] + pro4 + [['sub 'sp 'sp (aup (peep g 'off 0) 16)] '(saves)] + body)))))
   ; the frame and emit tail the old path ends on
   (lotail g ir)
    (dp 'final (fldcut g (thunks g (pushsv g (rjoin g (absg g (rawclean (a64sp g (twmv g (bprot g (frrec g (swrap g
     (tailarm g (jmpm g (csdrop g (cskeep g (unframe g (csframe g (deadlabk (cg-refs (g 'fasecs) {}) ir)))))))))))))))))))
)) ; module 'moon
