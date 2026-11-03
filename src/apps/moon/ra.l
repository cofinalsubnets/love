; src/apps/moon/ra.l -- the new backend's allocator over lo.l's forms: liveness per form, live
; ranges with holes per vreg, linear scan in start order, and a spilled vreg reloaded at every
; touch, the scan then run again. a physical register's live points bar every vreg live at one
(module 'moon
(borrow 'holo)
(:

   ; x64's files, caller-saved first: a callee-saved one costs its save. every xmm is caller-saved
   ragp '(r0 r1 r2 r5 r6 r7 r8 r9 r10 r3 r11 r12 r13 r14)
   ragf '(f0 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15)
   rafile (ragp + ragf)
   ; the vregs lo.l mints: %nK on the gp file, %wK on the float file
   (lomk g) (peep g 'lon 0 @ k (pin g 'lon (k + 1), name "%n\(k)"))
   (lomkf g) (peep g 'lon 0 @ k (pin g 'lon (k + 1), name "%w\(k)"))
   (lovr? x) (nom? x && (show x @ s (1 < #s && s 0 = 37 && (s 1 = 110 || s 1 = 119))))
   (lofr? x) (nom? x && (show x @ s (1 < #s && s 0 = 37 && s 1 = 119)) || elem x ragf)
   (raok? x) (lovr? x || elem x rafile)
   ; the float forms rdsp does not see: two-address ops, copies, compares, the gp crossings
   rafbin '(addsd subsd mulsd divsd minsd maxsd addss subss mulss divss minss maxss xorpd andpd)
   ; the three-address ops, and those of them that commute
   raalu '(add sub and or xor imul)
   racomm '(add and or xor imul)
   rafmv '(movapd movsd movss cvtss2sd cvtsd2ss cvtsi2sd cvtsi2ss movqxr movdxr cvttsd2si cvttss2si movqrx movdrx)
   ; a form's [reads defs] over the file and the vregs | 'bad
   (raops g f)
    ((f @ ('cuse . rs) [rs ()]
          ('cdef . rs) [() rs]
          ('fix . u . d . _) [u d]
          ('call . _) [() (lvgp g + ragf)]
          ('callr . r . _) [[r] (lvgp g + ragf)]
          ('ret . _) [(peep g 'loret '(r0)) ()]
          ([op d s] && elem op rafbin) [[d s] [d]]
          ([op d s] && elem op rafmv) [[s] [d]]
          [('ucomisd || 'ucomiss) a b] [[a b] ()]
          [('ldsd || 'ldss) d b _] [[b] [d]]
          [('stsd || 'stss) b _ v] [[b v] ()]
          (('jmp || 'br || 'label) . _) [() ()]
          ((op . d . a . b . _) && elem op divops) [[a b] [d 'r0]]
          (rdsp g f @ 'bar 'bad (u . d . _) [u d])) @
     'bad 'bad
     [u d] [(filter raok? u) (filter raok? d)])

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

   ; one round: ids, liveness, hulls, the scan -> [loc spills] | 'bad
   (raround g fs nosp)
    (: n #fs
       ft {} _ (foldl (i \ f \ (pin ft i f, i + 1)) 0 fs)
       ids {} nms {}
       (id x) (peep ids x -1 @ -1 (peep nms 'n 0 @ j (pins nms 'n (j + 1) j x, pin ids x j, j)) k k)
       _ (map id rafile)
       ud (: t {}
             (go i) (n <= i ? t
                       (raops g (ft i) @ 'bad 'bad
                          [u d] (pin t i [(raset (map id u)) (raset (map id d))], go (i + 1))))
             (go 0))
       (ud @ 'bad 'bad
          _ (: sc (vsucc fs)
               lin {} lout {}
               (sweep i chg)
                (i < 0 ? chg
                   (: o (foldl (a \ j \ vun a (peep lin j ())) () (peep sc i ()))
                      li (ud i @ [u d] (vun u (ramin o d)))
                      c2 (#li != #(peep lin i ()) ? 1 chg)
                      (pin lout i o, pin lin i li, sweep (i - 1) c2)))
               (fix _) (sweep (n - 1) 0 @ 1 (fix 0) 0)
               _ (fix 0)
               np #rafile
               lo {} hi {} pts {}
               (mark x p) (pin pts x (p . peep pts x ()),
                           x < np ? 0 (pin lo x (min p (peep lo x p)), pin hi x (max p (peep hi x p))))
               ; a sub's right side outlives its def, which may not overwrite it before the subtract
               _ (map (i \ (map (x \ mark x (2 * i)) (lin i),
                            map (x \ mark x (2 * i + 1)) (lout i),
                            map (x \ mark x (2 * i + 1)) <>(ud i),
                            (ft i @ (['sub _ _ b] && raok? b) (mark (id b) (2 * i + 1)) _ 0))) ^n)
               ; each id's live positions as ranges, with the holes between them
               rg (foldl (t \ x \ pin t x (rarng (pts x))) {} (keys pts))
               ; the copies hint their two sides together, a three-address op its def to its left
               ; side (either side when it commutes); a divide's quotient never takes rdx
               hint {} forb {}
               (link x y) (pin hint x (y . peep hint x ()))
               (link2 a b) (raok? a && raok? b ? (: x (id a) y (id b) (link x y, link y x)))
               _ (map (f \ (f @ [('mov || 'movapd) a b] (link2 a b)
                                ([op d a b] && elem op raalu) (link2 d a, elem op racomm ? (link2 d b))
                                ((op . d . _) && elem op divops) (pin forb (id d) ['r2])
                                0)) fs)
               vs (sortby (a \ b \ lo a < lo b || lo a = lo b && a < b) (filter (x \ np <= x) (keys lo)))
               loc {}
               (ovl? x y) (raovl (peep rg x ()) (peep rg y ()))
               (fits? r x) (nelem r (peep forb x ()) && !(ovl? x (id r)))
               (free? r x act) (!(any (w \ loc w = r && ovl? w x) act) && fits? r x)
               (hreg x fl) (filter (r \ elem r fl) (map (y \ y < np ? (nms y) (peep loc y ())) (peep hint x ())))
               ; evict the active hull ending last, where its register serves this one
               (victim x act)
                (foldl (b \ w \ (? (nosp (nms w) || hi w <= hi x || !(fits? (loc w) x) ||
                                     any (y \ y != w && loc y = loc w && ovl? y x) act) b
                                   (b @ () w _ (hi b < hi w ? w b))))
                       () act)
               (scan fl l act sp)
                (l @ ()
                      sp
                     (x . u)
                      (: a2 (filter (w \ lo x <= hi w) act)
                         (filter (r \ free? r x a2) (hreg x fl) + filter (r \ free? r x a2) fl @
                          (r . _) (pin loc x r, scan fl u (x . a2) sp)
                          _ (victim x a2 @
                               () (nosp (nms x) ? 'bad (scan fl u a2 (nms x . sp)))
                               w (pin loc x (loc w), scan fl u (x . filter (y \ y != w) a2) (nms w . sp))))))
               (fv? x) (lofr? (nms x))
               (scan ragp (filter (x \ !(fv? x)) vs) () () @ 'bad 'bad
                  sg (scan ragf (filter fv? vs) () sg @ 'bad 'bad
                        sp [(foldl (t \ k \ pin t (nms k) (loc k)) {} (keys loc)) sp])))))

   ; a spilled vreg: a slot, reloaded before each read and stored after each write
   (raspill g fs sp nosp)
    (: sl (foldl (t \ v \ pin t v (nslot g 8)) {} sp)
       (one f)
        (raops g f @
           [u d]
            (: us (filter (x \ elem x sp) u) ds (filter (x \ elem x sp) d)
               (foldl (a \ x \ elem x a ? a (a + [x])) () (us + ds) @
                  () [f]
                  vs (: m (foldl (t \ v \ (lofr? v ? (lomkf g) (lomk g)) @ k (pin nosp k 1, pin t v k)) {} vs)
                        (map (v \ [(lofr? v ? 'ldsd 'ld) (m v) 'r4 (sl v)]) us + [(map (x \ peep m x x) f)] +
                         map (v \ [(lofr? v ? 'stsd 'st) 'r4 (sl v) (m v)]) ds))))
           _ [f])
       (catmap one fs))

   ; -> [forms loc]: the round that fit, over the forms its spills left | 'bad
   (raplan g fs)
    (: nosp {}
       (go fs k)
        (k = 0 ? 'bad
           (raround g fs nosp @
              'bad 'bad
              [loc ()] [fs loc]
              [_ sp] (go (raspill g fs sp nosp) (k - 1))))
       (go fs 16))
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
   rapure '(li la lea mov movapd add sub and or xor imul shl shr sar not neg sx1 sx2 sx4 zx1 zx2 zx4 set
            movqxr movdxr movqrx movdrx)
   (radce g fs)
    (: cnt (foldl (t \ f \ (raops g f @ [u _] (foldl (t2 \ x \ (lovr? x ? (pin t2 x (peep t2 x 0 + 1)) t2)) t u) _ t)) {} fs)
       (own x u) #(filter (y \ y = x) u)
       (dead? f) (two? f && elem <f rapure &&
                  (raops g f @ [u d] (two? d && all (x \ lovr? x && peep cnt x 0 = own x u) d) _ ()))
       f2 (filter (f \ !(dead? f)) fs)
       (#f2 < #fs ? (radce g f2) fs))
   ; -> forms over registers | 'bad
   (raall g fs) (raplan g fs @ 'bad 'bad [f2 loc] (rasub f2 loc))

   ; -- the laws' checks over a fn's forms: MOON_LOLAW=1 pins what breaks on g 'lolaw --
   ; a physical register but the frame and stack bases
   (raphys? x) (elem x rafile && nelem x '(r4 sp))
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
           (: o (foldl (a \ j \ raund a (peep lin j ())) () (peep sc i ()))
              li (ud i @ [u d] (raund u (filter (x \ nelem x d) o)))
              c2 (#li != #(peep lin i ()) ? 1 chg)
              (pin lout i o, pin lin i li, sw (i - 1) c2)))
       (fix _) (sw (n - 1) 0 @ 1 (fix 0) 0)
       (fix 0, [ft ud lin lout]))
   ; a physical register named outside the glue, or live across a form that is not glue
   (rachkp g fs)
    (ralive g fs @ [ft ud lin lout]
       (catmap (i \ (ft i @ (hd . a)
                       (? (elem hd raglue || elem hd rafixed) ()
                          (filter raphys? a @ () (filter (x \ raphys? x && elem x (lout i) && nelem x <>(ud i)) (lin i) @
                                                    () () ps [['across ps (ft i)]])
                                             ps [['phys ps (ft i)]]))
                       _ ()))
               ^#fs))
   ; a vreg read where some path reaches without its def: defined-on-entry by a forward fixpoint, top 'all
   (rachkd g fs)
    (ralive g fs @ [ft ud _ _]
       (: n #fs sc (vsucc fs)
          pr (foldl (t \ i \ foldl (t2 \ j \ pin t2 j (i . peep t2 j ())) t (peep sc i ())) {} ^n)
          dout {}
          (meet a s) (a @ 'all s _ (s @ 'all a _ (filter (x \ elem x s) a)))
          (din i) (i = 0 ? () (foldl (a \ p \ meet a (peep dout p 'all)) 'all (peep pr i ())))
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
       (: cs (lvgp g + ragf)
          (catmap (i \ (ft i @ (('call || 'callr) . _)
                          (filter (x \ lovr? x && elem (loc x) cs) (lout i) @ () () vs [['call (map (x \ [x (loc x)]) vs) (ft i)]])
                          _ ()))
                  ^#fs)))
   (rachk g fs f2 loc) (rachkp g fs + rachkd g fs + rachkc g f2 loc)
)) ; module 'moon
