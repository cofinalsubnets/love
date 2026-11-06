; src/apps/moon/ra.l -- the backend's allocator over lo.l's forms: liveness per form, live
; ranges with holes per vreg, linear scan in start order, and a spilled vreg reloaded at every
; touch, the scan then run again. a physical register's live points bar every vreg live at one
(module 'moon
(borrow 'holo)
(:

   ; each target's files, caller-saved first: a callee-saved one costs its save. every x64 xmm is
   ; caller-saved; a64 keeps r4 out (a4ize reads it as the frame base), x15 to the callr park, x16-x18
   ; to holo and the platform, d8-d15 for their saves; riscv keeps r4 out likewise and t4 (r12) to the
   ; park, and its float file is caller-saved whole; t32 keeps r4 out, r12 to the park and holo, d8-d15
   ; for their saves
   (ragp g) (? (a64? g) '(r0 r1 r2 r3 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14 r19 r20 r21 r22 r23 r24 r25 r26 r27 r28)
               (rv64? g) '(r0 r1 r2 r3 r5 r6 r7 r8 r9 r10 r11 r13 r14 r15 r19 r20 r21 r22 r23 r24 r25 r26)
               (v6m? g) '(r0 r1 r2 r3 r5 r6)
               (t32? g) '(r0 r1 r2 r3 r5 r6 r7 r8 r9 r10)
               (ia32? g) '(r0 r1 r2 r5 r6 r3)
               '(r0 r1 r2 r5 r6 r7 r8 r9 r10 r3 r11 r12 r13 r14))
   (ragf g) (? (a64? g) '(f0 f1 f2 f3 f4 f5 f6 f7 f16 f17 f18 f19 f20 f21 f22 f23 f24 f25 f26 f27 f28 f29 f30 f31)
               (rv64? g) '(f0 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 f16 f17 f18 f19)
               (v6m? g) ()
               (t32? g) '(f0 f1 f2 f3 f4 f5 f6 f7)
               (ia32? g) '(f0 f1 f2 f3 f4 f5 f6 f7)
               '(f0 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15))
   (rapool g) (ragp g + ragf g)
   ; what a call clobbers: the caller-saved gp file and every float register the pool takes
   (racl g) (lvgp g + ragf g)
   ; the vregs lo.l mints: %nK on the gp file, %wK on the float file
   (lomk g) (peep g 'lon 0 @ k (pin g 'lon (k + 1), name "%n\(k)"))
   (lomkf g) (peep g 'lon 0 @ k (pin g 'lon (k + 1), name "%w\(k)"))
   ; a symbol orders by its spelling, so a prefix is a range: %n.. and %w.., the float file f0..f9..
   vn0 (name "%n") vn1 (name "%o") vw0 (name "%w") vw1 (name "%x") vf0 (name "f0") vf1 (name "f:")
   (lovr? x) (nom? x && (vn0 <= x && x < vn1 || vw0 <= x && x < vw1))
   (lofr? x) (nom? x && (vw0 <= x && x < vw1 || vf0 <= x && x < vf1))
   ; the unit's pool as a set, and a call's clobbers in it, laid once per unit
   (rasets g) (g 'rasets @
                 () (: p (rapool g) s [(foldl (t \ r \ pin t r 1) {} p) (filter (r \ elem r p) (racl g))]
                       (pin g 'rasets s, s))
                 s s)
   (raok? g x) (lovr? x || (<(rasets g)) x)
   ; the float forms rdsp does not see: two-address ops, copies, compares, the gp crossings
   rafbin '(addsd subsd mulsd divsd minsd maxsd addss subss mulss divss minss maxss xorpd andpd)
   ; the three-address ops, and those of them that commute
   raalu '(add sub and or xor imul)
   racomm '(add and or xor imul)
   rafmv '(movapd movsd movss cvtss2sd cvtsd2ss cvtsi2sd cvtsi2ss cvtui2sd cvtui2ss movqxr movdxr cvttsd2si cvttss2si cvttsd2ui cvttss2ui movqrx movdrx)
   ; each head's own shape, the rest rdsp's
   raky (: (cls t k ops) (foldl (t \ op \ pin t op k) t ops)
           t0 (cls (cls (cls (cls (cls (cls (cls (cls (cls {} 'fbin rafbin) 'fmv rafmv) 'div divops) 'ctl '(jmp br label))
                 'ucom '(ucomisd ucomiss)) 'fld '(ldsd ldss)) 'fst '(stsd stss)) 'fldx '(ldsdx ldssx)) 'fstx '(stsdx stssx))
           (foldl (t \ op \ pin t op op) t0 '(cuse cdef fix call callr ret movqrr movrrq ldsdl)))
   ; a form's [reads defs] over the file and the vregs | 'bad. the answer is the form's own but at
   ; an exit (the fn's return registers), so the unit keeps the rest by their value
   (raops g f)
    (? (!(two? f) || elem <f '(ret pop)) (raops0 g f)
       (: m (g 'raopm @ () (pin g 'raopm {}, g 'raopm) m m)
          (m f @ () (raops0 g f @ r (pin m f r, r)) r r)))
   (raops0 g f)
    ((: (gen f) (rdsp g f @ 'bar 'bad (u . d . _) [u d])
        (two? f ? (raky <f @
                     () (gen f)
                     'cuse [>f ()]
                     'cdef [() >f]
                     'fix (f @ ('fix . u . d . _) [u d] _ (gen f))
                     'movqrr (f @ [_ d a b] [[a b] [d]] _ (gen f))
                     'movrrq (f @ [_ a b s] [[s] [a b]] _ (gen f))
                     'call 'call
                     'callr (f @ ('callr . r . _) [[r] 'call] _ (gen f))
                     'ret [(peep g 'loret '(r0)) ()]
                     'fbin (f @ [_ d s] [[d s] [d]] _ (gen f))
                     'fmv (f @ [_ d s] [[s] [d]] _ (gen f))
                     'ucom (f @ [_ a b] [[a b] ()] _ (gen f))
                     'fld (f @ [_ d b _] [[b] [d]] _ (gen f))
                     'fst (f @ [_ b _ v] [[b v] ()] _ (gen f))
                     'fldx (f @ [_ d b i _ _] [[b i] [d]] _ (gen f))
                     'fstx (f @ [_ b i _ _ v] [[b i v] ()] _ (gen f))
                     'ctl [() ()]
                     'ldsdl (f @ [_ d _] [() [d]] _ (gen f))
                     'div (f @ (_ . d . a . b . t) (x86? g ? [[a b] [d 'r0]] [[a b] (d . t)]) _ (gen f)))
           (gen f))) @
     'bad 'bad
     'call [() <>(rasets g)]
     [u 'call] [(filter (raok? g) u) <>(rasets g)]
     [u d] [(filter (raok? g) u) (filter (raok? g) d)])

   ; -- sorted int sets --
   (ramin a b) (? (atom? a) () (atom? b) a
                  (<a < <b) (<a . ramin >a b)
                  (<b < <a) (ramin a >b)
                  (ramin >a >b))
   (raset l) (foldl (s \ x \ vun s [x]) () l)
   ; positions, descending with repeats -> ranges [s e] ascending, neighbours joined
   (rarng l) (foldl (a \ p \ (a @ ([s e] . u) (p = s || p + 1 = s ? ([p e] . u) ([p p] . a)) _ [[p p]])) () l)
   ; two ascending range lists share a position
   (raovl a b)
    (? (atom? a || atom? b) ()
       (: x <a y <b
          (? (x 1 < y 0) (raovl >a b)
             (y 1 < x 0) (raovl a >b)
             1)))

   ; a fn's blocks, descending, as [first last]: each form runs on to the next but a block's last
   (rablocks sc n)
    (: lead (foldl (t \ i \ (sc i @ ([j] && j = i + 1) t
                                js (map (j \ pin t j 1) js, pin t (i + 1) 1, t))) (pin {} 0 1) ^n)
       (go l) (l @ (s . u) ([s ((u @ (t . _) t _ n) - 1)] . go u) _ ())
       (rev (go (filter lead ^n))))

   ; one round: ids, liveness, hulls, the scan -> [loc spills] | 'bad
   (raround g fs nosp)
    (: n #fs
       ft {} _ (foldl (i \ f \ (pin ft i f, i + 1)) 0 fs)
       ids {} nms {}
       (id x) (peep ids x -1 @ -1 (peep nms 'n 0 @ j (pins nms 'n (j + 1) j x, pin ids x j, j)) k k)
       _ (map id (rapool g))
       ud (: t {}
             (go i) (n <= i ? t
                       (raops g (ft i) @ 'bad 'bad
                          [u d] (pin t i [(raset (map id u)) (raset (map id d))], go (i + 1))))
             (go 0))
       (ud @ 'bad 'bad
          _ (: sc (vsucc fs)
               bs (rablocks sc n)
               ; a block's reads before any write in it, and its writes, by its first form
               (bud1 s i a w) (ud i @ [u d] (: a2 (vun u (ramin a d)) w2 (vun w d)
                                               (i = s ? [a2 w2] (bud1 s (i - 1) a2 w2))))
               bud (foldl (t \ b \ (b @ [s e] (pin t s (bud1 s e () ())))) {} bs)
               lin {} lout {}
               (sweep l chg)
                (l @ ([s e] . u)
                      (: o (foldl (a \ j \ vun a (lin j)) () (sc e))
                         li (bud s @ [a w] (vun a (ramin o w)))
                         c2 (#li != #(lin s) ? 1 chg)
                         (pin lout s o, pin lin s li, sweep u c2))
                     _ chg)
               (fix _) (sweep bs 0 @ 1 (fix 0) 0)
               _ (fix 0)
               np #(rapool g)
               ; each id's live positions as ranges, with the holes between them, laid last to first
               lo {} hi {} rg {}
               (add x s e) ((rg x @ ([a b] . u) (e + 1 = a ? (pin rg x ([s b] . u)) (pin rg x ([s e] . rg x)))
                                    _ (pin rg x [[s e]], x < np ? 0 (pin hi x e))),
                            x < np ? 0 (pin lo x s))
               ; a sub's right side outlives its def, which may not overwrite it before the subtract;
               ; a remainder's scratch is written before its operands are done
               (late i) (ft i @ (['sub _ _ b] && raok? g b) [(id b)]
                                ((op _ a b _) && elem op '(rem urem) && !(x86? g)) (map id (filter (raok? g) [a b]))
                                _ ())
               ; open: each id live here, to the end of its range. a form touches only what it names
               (blk s e)
                (: op {}
                   (on x p) (op x @ () (pin op x p) _ 0)
                   (step i)
                    (ud i @ [u d]
                       (: p (2 * i + 1)
                          (map (x \ on x p) d,
                           map (x \ (op x != () || elem x u ? (on x p) (add x p p))) (late i),
                           map (x \ (nelem x u ? (add x p (op x), pin op x ()))) d,
                           map (x \ on x (2 * i)) u,
                           s < i ? (step (i - 1)))))
                   (map (x \ pin op x (2 * e + 1)) (lout s),
                    step e,
                    map (x \ (op x @ () 0 t (add x (2 * s) t))) (keys op)))
               _ (foldl (_ \ b \ (b @ [s e] (blk s e))) 0 bs)
               ; the copies hint their two sides together, a three-address op its def to its left
               ; side (either side when it commutes); a divide's quotient never takes rdx
               hint {} forb {}
               (link x y) (pin hint x (y . hint x))
               (link2 a b) (raok? g a && raok? g b ? (: x (id a) y (id b) (link x y, link y x)))
               _ (map (f \ (f @ [('mov || 'movapd) a b] (link2 a b)
                                ([op d a b] && elem op raalu) (link2 d a, elem op racomm ? (link2 d b))
                                ((op . d . _) && elem op divops && x86? g) (pin forb (id d) ['r2])
                                0)) fs)
               vs (sortby (a \ b \ lo a < lo b || lo a = lo b && a < b) (filter (x \ np <= x) (keys lo)))
               loc {}
               ; x the interval being placed: nothing before it matters to later ones either, so y's
               ; ranges behind it are passed for good
               cu {}
               (past l p) (l @ ([_ e] . u) (e < p && two? u ? (past u p) l) _ l)
               (ovl? x y) (raovl (rg x) (past (cu y @ () (rg y) c c) (lo x) @ l (pin cu y l, l)))
               (fits? r x) (nelem r (forb x) && !(ovl? x (id r)))
               (free? r x act) (!(any (w \ loc w = r && ovl? x w) act) && fits? r x)
               (pick l x act) (l @ (r . u) (free? r x act ? r (pick u x act)) _ ())
               (hreg x fl) (filter (r \ elem r fl) (map (y \ y < np ? (nms y) (loc y)) (hint x)))
               ; a spill's weight: its touches, each 8^loop depth
               spn (raspans fs)
               wt (foldl (t \ i \ (vwt spn i @ w (ud i @ [u d] (map (x \ pin t x (peep t x 0 + w)) (vun u d), t)))) {} ^n)
               (wt? x) (peep wt x 0)
               rw (foldl (t \ i \ (vwt spn i @ w (ud i @ [u _] (map (x \ pin t x (peep t x 0 + w)) u, t)))) {} ^n)
               ; the lightest active interval whose register serves this one alone, or none when
               ; this one weighs less and may spill itself
               (victim x act)
                (foldl (b \ w \ (? (nosp (nms w) || !(ovl? x w) || !(fits? (loc w) x) ||
                                     any (y \ y != w && loc y = loc w && ovl? x y) act) b
                                   (b @ () w _ (wt? w < wt? b ? w b))))
                       () act @
                   () ()
                   w (!(nosp (nms x)) && wt? x <= wt? w ? () w))
               (scan fl l act sp)
                (l @ ()
                      sp
                     (x . u)
                      (: a2 (filter (w \ lo x <= hi w) act)
                         ((pick (hreg x fl) x a2 @ () (pick fl x a2) r r) @
                          () (victim x a2 @
                               () (nosp (nms x) ? 'bad (scan fl u a2 (nms x . sp)))
                               w (pin loc x (loc w), scan fl u (x . filter (y \ y != w) a2) (nms w . sp)))
                          r (pin loc x r, scan fl u (x . a2) sp))))
               (fv? x) (lofr? (nms x))
               (scan (ragp g) (filter (x \ !(fv? x)) vs) () () @ 'bad 'bad
                  sg (scan (ragf g) (filter fv? vs) () sg @ 'bad 'bad
                        sp (: si (map id sp)
                              ; per call, the spilled vregs it outlives; their reloads' weight there
                              cw {}
                              cr (foldl (t \ i \ (ft i @ (('call || 'callr) . _)
                                                      (filter (x \ raovl (rg x) [[(2 * i + 1) (2 * i + 1)]]) si @
                                                         () t
                                                         xs (vwt spn i @ w (map (x \ pin cw x (peep cw x 0 + w)) xs, pin t i (map nms xs))))
                                                      _ t)) {} ^n)
                              ; split where reloading after the calls weighs less than at the reads
                              sv (map nms (filter (x \ cw x != () && cw x < peep rw x 0) si))
                              [(foldl (t \ k \ pin t (nms k) (loc k)) {} (keys loc)) sp cr sv]))))))

   ; the back edges' spans [label jump], for vwt's loop depth
   (raspans fs)
    (: lb (vlabs fs)
       (go l i) (l @ (f . u) (: j (f @ ['jmp t] (peep lb t -1) ['br _ t] (peep lb t -1) _ -1)
                                (0 <= j && j <= i ? ([j i] . go u (i + 1)) (go u (i + 1))))
                    _ ())
       (go fs 0))

   ; a spilled vreg: a slot, stored after each write and reloaded before a read, a temp holding it
   ; until a label or a call ends the run (the last nk kept)
   (raspill g fs sp nosp nk)
    (: sl (foldl (t \ v \ pin t v (nslot g 8)) {} sp)
       _ (pin g 'rasls (map sl sp + g 'rasls))
       (tmp v) ((lofr? v ? (lomkf g) (lomk g)) @ k (pin nosp k 1, k))
       (go fs c)
        (fs @ ((['mov p v] && !(lovr? p) && elem v sp && raget c v = ()) . u)   ; a fixed register's reload needs no temp, which might take another's
               (['ld p 'r4 (sl v)] . go u c)
              ; t32's odd s-register goes by r12 with the float file full: to and from its slot straight
              ((['movdxr v r] && t32? g && elem v sp) . u)
               (['st 'r4 (sl v) r] . go u (filter (e \ <e != v) c))
              ((['movdrx r v] && t32? g && elem v sp && !(lovr? r) && raget c v = ()) . u)
               (['ld r 'r4 (sl v)] . go u c)
              (f . u)
               (: c0 (f @ (('label || 'call || 'callr) . _) () _ c)
                  (raops g f @
                     [u0 d0]
                      (: us (filter (x \ elem x sp) u0) ds (filter (x \ elem x sp) d0)
                         vs (foldl (a \ x \ elem x a ? a (x . a)) () (us + ds))
                         m (foldl (t \ v \ pin t v (raget c0 v @ () (tmp v) k k)) {} vs)
                         lds (map (v \ [(lofr? v ? 'ldsd 'ld) (m v) 'r4 (sl v)]) (filter (v \ raget c0 v = ()) us))
                         sts (map (v \ [(lofr? v ? 'stsd 'st) 'r4 (sl v) (m v)]) ds)
                         c2 (take nk (map (v \ [v (m v)]) vs + filter (e \ nelem <e vs) c0))
                         ((vs @ () [f] _ (lds + [(map (x \ peep m x x) f)] + sts)) + go u c2))
                     _ (f . go u c0)))
              _ ())
       (go fs ()))
   (raget c v) (foldl (a \ e \ (a @ () (<e = v ? <>e) _ a)) () c)

   ; -> [forms loc]: the round that fit, over the forms its spills left | 'bad
   ; the entry's fast region: the forms the entry reaches through no call, a label only when every
   ; way in comes from the region. a vreg the entry run sets once and the rest of the fn needs lives
   ; in the region as a twin, copied back on each edge out (a branch's through a stub at the end), so
   ; the region writes no callee-saved register and swrap can move the frame onto its exits
   (raentry g fs)
    (: n #fs
       ft {} _ (foldl (i \ f \ (pin ft i f, i + 1)) 0 fs)
       sc (vsucc fs) lb (vlabs fs)
       pr (foldl (t \ i \ foldl (t2 \ j \ pin t2 j (i . t2 j)) t (sc i)) {} ^n)
       (hd i) (ft i @ (h . _) h _ ())
       (call? i) (elem (hd i) '(call callr))
       inr {}
       (in? i) (inr i)
       (sw i chg)
        (n <= i ? chg
           (: ok (!(call? i) && (i = 0 || (pr i @ () ()
                                             ps (hd i = 'label ? (all in? ps) (any in? ps)))))
              (ok && !(in? i) ? (pin inr i 1, sw (i + 1) 1) (sw (i + 1) chg))))
       (fix _) (sw 0 0 @ 1 (fix 0) 0)
       _ (fix 0)
       ; the entry run: up to the first label, jump, branch, call or return
       k (: (go i) (i < n && nelem (hd i) '(label jmp br call callr ret jmpt fix) ? (go (i + 1)) i) (go 0))
       dfs (foldl (t \ i \ (raops g (ft i) @ [_ d] (map (x \ pin t x (i . t x)) (filter lovr? d), t) _ t)) {} ^n)
       outs (foldl (t \ i \ (in? i ? t (raops g (ft i) @ [u d] (map (x \ pin t x 1) (filter lovr? (u + d)), t) _ t))) {} ^n)
       vs (filter (v \ outs v && (dfs v @ [i] (i < k) _ ()))
                  (raund () (catmap (i \ raops g (ft i) @ [_ d] (filter lovr? d) _ ()) ^k)))
       ; an asm goto out of the region has no edge to lay copies on
       (? (!(two? vs) || !(any (i \ !(in? i)) ^n) ||
           any (i \ in? i && hd i = 'fix && 4 < #(ft i) && any (j \ !(in? j)) (sc i)) ^n) fs
          (: tw (foldl (t \ v \ pin t v (lofr? v ? (lomkf g) (lomk g))) {} vs)
             (cp v) [(lofr? v ? 'movapd 'mov) v (tw v)]
             cps (map cp vs)
             (ren f) (f @ (('fix || 'cdef) . _) f (_ . _) (map (x \ peep tw x x) f) f)
             stubs {}
             (stub L) (stubs L @ () (nlab g ".lo" @ T (pin stubs L T, T)) T T)
             ; a fall into a call copies ahead of its argument setup, whose registers the copies may take
             (setup? i) (ft i @ ('cuse . _) 1 ((op . d . _) && elem op '(mov movapd li la lea)) (!(lovr? d)) _ 0)
             (back i) (0 < i && in? (i - 1) && setup? (i - 1) ? (back (i - 1)) i)
             pre {}
             _ (map (i \ (in? i && i + 1 < n && !(in? (i + 1)) && setup? i ? (pin pre (back i) 1))) ^n)
             body (catmap (i \ (? !(in? i) [(ft i)]
                                   (: f (ren (ft i))
                                      nx (i + 1 < n && !(in? (i + 1)) && nelem (hd i) '(jmp ret) && !(setup? i) ? cps)
                                      ((pre i ? cps) +
                                      (f @ ['jmp L] (in? (peep lb L -1) ? [f] (cps + [f]))
                                           ['br c L] ((in? (peep lb L -1) ? [f] [['br c (stub L)]]) + nx)
                                           ; a table's ways out go by stubs, in the form and in its cells
                                           ['jmpt t tl ls] [['jmpt t tl (map (L \ in? (peep lb L -1) ? L (stub L)) ls)]]
                                           _ ([f] + nx))))))
                          ^n)
             tls (catmap (i \ (in? i ? (ft i @ ['jmpt _ tl _] [tl] _ ()))) ^n)
             (cell c) (c @ ['fix 4 'rel32 L o] ['fix 4 'rel32 (peep stubs L L) o] _ c)
             _ (pin g 'jtabs (map (e \ (e @ ([tl cs] && elem tl tls) [tl (map cell cs)] _ e)) (g 'jtabs)))
             (body + catmap (L \ [['label (stubs L)]] + cps + [['jmp L]]) (sort (keys stubs))))))

   ; a vreg spilled across calls splits there first when that weighs less, a full spill when it
   ; misses again
   ; a small file can run out under the temps a spill keeps: then again with none kept
   (raplan g fs) ((raplan1 g fs 4) @ 'bad (raplan1 g fs 0) r r)
   (raplan1 g fs nk)
    (: nosp {} split {}
       _ (pin g 'rasls ())
       (go fs k)
        (k = 0 ? 'bad
           (raround g fs nosp @
              'bad 'bad
              [loc () _ _] [(radse g fs (g 'rasls)) loc]
              [_ sp cr sv] (: s1 (filter (v \ elem v sv && !(split v)) sp)
                           s2 (filter (v \ nelem v s1) sp)
                           (map (v \ pin split v 1) s1,
                            go (raspill g (rasplit g fs s1) s2 nosp nk) (k - 1)))))
       (go fs 16))
   ; a spill slot's store goes when no path reads the slot back before writing it again or
   ; leaving: the slots are ra's own, so only its loads and stores name them
   (radse g fs sls) (!(two? sls) ? fs (radse1 g fs sls))
   (radse1 g fs sls)
    (: isl (foldl (t \ o \ pin t o 1) {} sls)
       sl {}
       _ (foldl (i \ f \ (f @ ([('ld || 'ldsd) _ 'r4 o] && isl o) (pin sl i ['ld o])
                              ([('st || 'stsd) 'r4 o _] && isl o) (pin sl i ['st o])
                              _ 0,
                           i + 1)) 0 fs)
       sc (vsucc fs)
       bs (rablocks sc #fs)
       ; a block's reads before any write in it, and its writes, by its first form
       (bud1 s i a w)
        (sl i @ ['ld k] (bnext s i (raund [k] a) w)
                ['st k] (bnext s i (filter (x \ x != k) a) (raund [k] w))
                _ (bnext s i a w))
       (bnext s i a w) (i = s ? [a w] (bud1 s (i - 1) a w))
       bud (foldl (t \ b \ (b @ [s e] (pin t s (bud1 s e () ())))) {} bs)
       lin {} lout {}
       (sweep l chg)
        (l @ ([s e] . u)
              (: o (foldl (a \ j \ raund a (lin j)) () (sc e))
                 li (bud s @ [a w] (raund a (filter (x \ nelem x w) o)))
                 c2 (#li != #(lin s) || #o != #(lout s) ? 1 chg)
                 (pin lout s o, pin lin s li, sweep u c2))
             _ chg)
       (fix _) (sweep bs 0 @ 1 (fix 0) 0)
       _ (fix 0)
       ; a store goes when nothing after it in its block, or past, reads the slot first
       dead {}
       (walk s i o)
        (: o2 (sl i @ ['ld k] (raund [k] o)
                      ['st k] ((nelem k o ? (pin dead i 1)), filter (x \ x != k) o)
                      _ o)
           (s < i ? (walk s (i - 1) o2)))
       _ (map (b \ (b @ [s e] (walk s e (lout s)))) bs)
       (keep l i) (l @ (f . u) (dead i ? (keep u (i + 1)) (f . keep u (i + 1))) _ ())
       (keep fs 0))

   ; a vreg split at its calls: stored after each def, reloaded before a read its register may not
   ; hold, by a forward must-availability where a call holds none, so no call finds it live
   (rasplit g fs vs)
    (: n #fs
       ft {} _ (foldl (i \ f \ (pin ft i f, i + 1)) 0 fs)
       sl (foldl (t \ v \ pin t v (nslot g 8)) {} vs)
       _ (pin g 'rasls (map sl vs + g 'rasls))
       (ld v) [(lofr? v ? 'ldsd 'ld) v 'r4 (sl v)]
       (st v) [(lofr? v ? 'stsd 'st) 'r4 (sl v) v]
       ud (foldl (t \ i \ pin t i (raops g (ft i) @ [u d] [(filter (x \ elem x vs) u) (filter (x \ elem x vs) d)] _ [() ()])) {} ^n)
       sc (vsucc fs)
       pr (foldl (t \ i \ foldl (t2 \ j \ pin t2 j (i . t2 j)) t (sc i)) {} ^n)
       aout {}
       (meet a s) (a @ 'all s _ (s @ 'all a _ (filter (x \ elem x s) a)))
       (ain i) (pr i @ () () ps (foldl (a \ p \ meet a (peep aout p 'all)) 'all ps))
       (sz s) (s @ 'all -1 _ #s)
       (sw i chg)
        (n <= i ? chg
           (: o (ft i @ (('call || 'callr) . _) ()
                       _ (ain i @ 'all 'all a (ud i @ [u d] (raund (raund a u) d))))
              c2 (sz o != sz (peep aout i 'all) ? 1 chg)
              (pin aout i o, sw (i + 1) c2)))
       (fix _) (sw 0 0 @ 1 (fix 0) 0)
       _ (fix 0)
       (vs @ () fs
          _ (catmap (i \ (ud i @ [u d] (: a (ain i @ 'all () a a)
                                          (map ld (filter (x \ nelem x a) u) + [(ft i)] + map st d))))
                    ^n)))
   ; the forms over their registers: a copy onto itself and the use markers gone, a fix its body
   (rasub fs loc)
    (: (sub x) (lovr? x ? (loc x) x)
       (catmap (f \ (f @ (('cuse || 'cdef) . _) ()
                         ('fix . _ . _ . fs . _) fs
                         ([('mov || 'movapd) a b] && sub a = sub b) ()
                         (_ . _) [(map sub f)]
                         [f])) fs))
   ; dead defs: a pure form whose every def is a vreg no other form reads goes, to a fixpoint.
   ; no flag-setter a branch reads is pure here: lo.l lays a compare before every branch
   rapure (foldl (t \ op \ pin t op 1) {} '(li la lea mov movapd add sub and or xor imul shl shr sar not neg
                                              sx1 sx2 sx4 zx1 zx2 zx4 set movqxr movdxr movqrx movdrx movqrr movrrq))
   (radce g fs)
    (: cnt (foldl (t \ f \ (raops g f @ [u _] (foldl (t2 \ x \ (lovr? x ? (pin t2 x (peep t2 x 0 + 1)) t2)) t u) _ t)) {} fs)
       (own x u) #(filter (y \ y = x) u)
       (dead? f) (two? f && rapure <f &&
                  (raops g f @ [u d] (two? d && all (x \ lovr? x && peep cnt x 0 = own x u) d) _ ()))
       ; a form that goes gives back its reads, so a walk from the end takes a chain at once
       (kill f) (raops g f @ [u _] (map (x \ lovr? x ? (pin cnt x (peep cnt x 0 - 1))) u))
       (go fs) (foldl (a \ f \ (dead? f ? (kill f, a) (f . a))) () (rev fs) @ f2 (#f2 < #fs ? (go f2) fs))
       (go fs))
   ; -> forms over registers | 'bad
   (raall g fs) (raplan g fs @ 'bad 'bad [f2 loc] (rasub f2 loc))

   ; -- the laws' checks over a fn's forms: MOON_LOLAW=1 pins what breaks on g 'lolaw --
   ; a physical register but the frame and stack bases
   (raphys? g x) (elem x (rapool g) && nelem x '(r4 sp))
   ; the forms a physical register may stand in or live across: copies, crossings, control
   raglue '(cdef mov movapd movqrx movdrx movqxr movdxr li la st st1 st2 st4 stsd stss ld ldsd ldss cuse jmp label rests pop)
   ; the forms with a fixed register operand: the count in rcx, a divide's rax
   rafixed '(fix call callr ret shlv shrv sarv div rem udiv urem)
   (raund a b) (foldl (s \ x \ elem x s ? s (x . s)) a b)
   ; -> [forms reads-defs live-in live-out], tablets by index, over names
   (ralive g fs)
    (: n #fs ft {} _ (foldl (i \ f \ (pin ft i f, i + 1)) 0 fs)
       ud (foldl (t \ i \ (raops g (ft i) @ 'bad (pin t i [() ()]) p (pin t i p))) {} ^n)
       sc (vsucc fs) lin {} lout {}
       (sw i chg)
        (i < 0 ? chg
           (: o (foldl (a \ j \ raund a (lin j)) () (sc i))
              li (ud i @ [u d] (raund u (filter (x \ nelem x d) o)))
              c2 (#li != #(lin i) ? 1 chg)
              (pin lout i o, pin lin i li, sw (i - 1) c2)))
       (fix _) (sw (n - 1) 0 @ 1 (fix 0) 0)
       (fix 0, [ft ud lin lout]))
   ; a physical register named outside the glue, or live across a form that is not glue (an sp
   ; adjustment is the arm targets' frame teardown)
   (rachkp g fs)
    (ralive g fs @ [ft ud lin lout]
       (catmap (i \ (ft i @ (hd . a)
                       (? (elem hd raglue || elem hd rafixed || elem hd '(lea add sub) && <a = 'sp) ()
                          (filter (raphys? g) a @ () (filter (x \ raphys? g x && elem x (lout i) && nelem x <>(ud i)) (lin i) @
                                                    () () ps [['across ps (ft i)]])
                                             ps [['phys ps (ft i)]]))
                       _ ()))
               ^#fs))
   ; a vreg read where some path reaches without its def: defined-on-entry by a forward fixpoint, top 'all
   (rachkd g fs)
    (ralive g fs @ [ft ud _ _]
       (: n #fs sc (vsucc fs)
          pr (foldl (t \ i \ foldl (t2 \ j \ pin t2 j (i . t2 j)) t (sc i)) {} ^n)
          dout {}
          (meet a s) (a @ 'all s _ (s @ 'all a _ (filter (x \ elem x s) a)))
          (din i) (i = 0 ? () (foldl (a \ p \ meet a (peep dout p 'all)) 'all (pr i)))
          (sz s) (s @ 'all -1 _ #s)
          (sw i chg)
           (n <= i ? chg
              (: o (din i @ 'all 'all s (raund s (filter lovr? <>(ud i))))
                 c2 (sz o != sz (peep dout i 'all) ? 1 chg)
                 (pin dout i o, sw (i + 1) c2)))
          (fix _) (sw 0 0 @ 1 (fix 0) 0)
          (fix 0,
           catmap (i \ (din i @ 'all ()
                          s (filter (x \ lovr? x && nelem x s) <(ud i) @ () () vs [['undef vs (ft i)]])))
                  ^n)))
   ; a vreg live across a call, homed in a register the call clobbers
   (rachkc g fs loc)
    (ralive g fs @ [ft _ _ lout]
       (: cs (racl g)
          (catmap (i \ (ft i @ (('call || 'callr) . _)
                          (filter (x \ lovr? x && elem (loc x) cs) (lout i) @ () () vs [['call (map (x \ [x (loc x)]) vs) (ft i)]])
                          _ ()))
                  ^#fs)))
   (rachk g fs f2 loc) (rachkp g fs + rachkd g fs + rachkc g f2 loc)
)) ; module 'moon
