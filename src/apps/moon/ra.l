; src/apps/moon/ra.l -- the new backend's allocator over lo.l's forms: liveness per form, one
; hull per vreg, linear scan, and a spilled vreg reloaded at every touch, the scan then run
; again. a physical register's live points bar every vreg whose hull holds one
(module 'moon
(borrow 'holo)
(:

   ; the vregs lo.l mints
   (lomk g) (peep g 'lon 0 @ k (pin g 'lon (k + 1), name "%n\(k)"))
   (lovr? x) (nom? x && (show x @ s (1 < #s && s 0 = 37 && s 1 = 110)))
   ; x64's file, caller-saved first: a callee-saved one costs its save
   ragp '(r0 r1 r2 r5 r6 r7 r8 r9 r10 r3 r11 r12 r13 r14)
   (raok? x) (lovr? x || elem x ragp)
   ; a form's [reads defs] over the file and the vregs | 'bad
   (raops g f)
    ((f @ ('cuse . rs) [rs ()]
          ('fix u d _) [u d]
          ('call . _) [() (lvgp g)]
          ('callr . r . _) [[r] (lvgp g)]
          ('ret . _) ['(r0) ()]
          (('jmp || 'br || 'label) . _) [() ()]
          ((op . d . a . b . _) && elem op divops) [[a b] [d 'r0]]
          (rdsp g f @ 'bar 'bad (u . d . _) [u d])) @
     'bad 'bad
     (u d) [(filter raok? u) (filter raok? d)])

   ; -- sorted int sets --
   (ramin a b) (? (atom? a) () (atom? b) a
                  (<a < <b) (<a . ramin >a b)
                  (<b < <a) (ramin a >b)
                  (ramin >a >b))
   (raset l) (foldl (s \ x \ vun s [x]) () l)

   ; one round: ids, liveness, hulls, the scan -> [loc spills] | 'bad
   (raround g fs nosp)
    (: n #fs
       ft {} _ (foldl (i \ f \ (pin ft i f, i + 1)) 0 fs)
       ids {} nms {}
       (id x) (peep ids x -1 @ -1 (peep nms 'n 0 @ j (pins nms 'n (j + 1) j x, pin ids x j, j)) k k)
       _ (map id ragp)
       ud (: t {}
             (go i) (n <= i ? t
                       (raops g (ft i) @ 'bad 'bad
                          (u d) (pin t i [(raset (map id u)) (raset (map id d))], go (i + 1))))
             (go 0))
       (ud @ 'bad 'bad
          _ (: sc (vsucc fs)
               lin {} lout {}
               (sweep i chg)
                (i < 0 ? chg
                   (: o (foldl (a \ j \ vun a (peep lin j ())) () (peep sc i ()))
                      li (ud i @ (u d) (vun u (ramin o d)))
                      c2 (#li != #(peep lin i ()) ? 1 chg)
                      (pin lout i o, pin lin i li, sweep (i - 1) c2)))
               (fix _) (sweep (n - 1) 0 @ 1 (fix 0) 0)
               _ (fix 0)
               np #ragp
               lo {} hi {} pts {}
               (mark x p) (x < np ? (pin pts x (p . peep pts x ()))
                             (pin lo x (min p (peep lo x p)), pin hi x (max p (peep hi x p))))
               _ (map (i \ (map (x \ mark x (2 * i)) (lin i),
                            map (x \ mark x (2 * i + 1)) (lout i),
                            map (x \ mark x (2 * i + 1)) <>(ud i))) ^n)
               ; the copies hint their two sides together; a divide's quotient never takes rdx
               hint {} forb {}
               (link x y) (pin hint x (y . peep hint x ()))
               _ (map (f \ (f @ (('mov a b) && raok? a && raok? b) (: x (id a) y (id b) (link x y, link y x))
                                ((op . d . _) && elem op divops) (pin forb (id d) ['r2])
                                0)) fs)
               vs (sortby (a \ b \ lo a < lo b || lo a = lo b && a < b) (filter (x \ np <= x) (keys lo)))
               loc {}
               (fits? r x) (: s (lo x) e (hi x)
                              (nelem r (peep forb x ()) && !(any (p \ s <= p && p <= e) (peep pts (id r) ()))))
               (free? r x act) (!(any (w \ loc w = r) act) && fits? r x)
               (hreg x) (filter nom? (map (y \ y < np ? (nms y) (peep loc y ())) (peep hint x ())))
               ; evict the active hull ending last, where its register serves this one
               (victim x act)
                (foldl (b \ w \ (? (nosp (nms w) || hi w <= hi x || !(fits? (loc w) x)) b
                                   (b @ () w _ (hi b < hi w ? w b))))
                       () act)
               (scan l act sp)
                (l @ ()
                      [loc sp]
                     (x . u)
                      (: a2 (filter (w \ lo x <= hi w) act)
                         (filter (r \ free? r x a2) (hreg x) + filter (r \ free? r x a2) ragp @
                          (r . _) (pin loc x r, scan u (x . a2) sp)
                          _ (victim x a2 @
                               () (nosp (nms x) ? 'bad (scan u a2 (nms x . sp)))
                               w (pin loc x (loc w), scan u (x . filter (y \ y != w) a2) (nms w . sp))))))
               (scan vs () () @ 'bad 'bad
                  (lc sp) [(foldl (t \ k \ pin t (nms k) (lc k)) {} (keys lc)) sp]))))

   ; a spilled vreg: a slot, reloaded before each read and stored after each write
   (raspill g fs sp nosp)
    (: sl (foldl (t \ v \ pin t v (nslot g 8)) {} sp)
       (one f)
        (raops g f @
           (u d)
            (: us (filter (x \ elem x sp) u) ds (filter (x \ elem x sp) d)
               (foldl (a \ x \ elem x a ? a (a + [x])) () (us + ds) @
                  () [f]
                  vs (: m (foldl (t \ v \ lomk g @ k (pin nosp k 1, pin t v k)) {} vs)
                        (map (v \ ['ld (m v) 'r4 (sl v)]) us + [(map (x \ peep m x x) f)] +
                         map (v \ ['st 'r4 (sl v) (m v)]) ds))))
           _ [f])
       (catmap one fs))

   ; -> forms over registers | 'bad
   (raall g fs)
    (: nosp {}
       (go fs k)
        (k = 0 ? 'bad
           (raround g fs nosp @
              'bad 'bad
              (loc ())
               (: (sub x) (lovr? x ? (loc x) x)
                  (catmap (f \ (f @ ('cuse . _) ()
                                    ('fix _ _ fs) fs
                                    (('mov a b) && sub a = sub b) ()
                                    (_ . _) [(map sub f)]
                                    [f])) fs))
              (_ sp) (go (raspill g fs sp nosp) (k - 1))))
       (go fs 16))
)) ; module 'moon
