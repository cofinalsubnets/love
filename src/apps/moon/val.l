; src/apps/moon/val.l -- the value layer gen.l's frame passes read: op widths, per-index
; successors, reaching defs and chain grouping over a window, a value's liveness at cell grain.
; every list a v-fn answers is sorted, and no answer depends on tablet iteration order.
(module 'moon
(:

   ; -- op families: width in bytes, 0 = not in the family --
   (vldw x) (x @ 'ld 8 'ld4 4 'ldu4 4 'ld2 2 'ldu2 2 'ld1 1 'ldu1 1 0)
   (vstw x) (x @ 'st 8 'st4 4 'st2 2 'st1 1 0)
   (vsiw x) (x @ 'si 8 'si4 4 'si2 2 'si1 1 0)

   ; -- sorted-int-list sets --
   (vun a b) (? (atom? a) b (atom? b) a
                (<a < <b) (<a . vun >a b)
                (<b < <a) (<b . vun a >b)
                (<a . vun >a >b))
   (vboth a b) (? (atom? a || atom? b) ()
                  (<a < <b) (vboth >a b)
                  (<b < <a) (vboth a >b)
                  (<a . vboth >a >b))
   (vapp a b) (atom? a ? b (<a . vapp >a b))
   (vany p l) (? (atom? l) 0 (p <l) 1 (vany p >l))
   ; -- indexing: a label's form index --
   (vlabs bd) (: t {}
                 (go l i) (atom? l ? t
                             (<l @ f
                                (two? f && <f = 'label ? (pin t <>f i) 0,
                                 go >l (i + 1))))
                 (go bd 0))
   ; -- the loop weight 8^min(depth,3) over back-edge spans --
   (vwt sp i)
    (: (dep l d) (atom? l ? d
                    (<l @ s (dep >l (<s <= i && i <= <>s ? (d + 1) d))))
       d (dep sp 0)
       ((3 < d ? 3 d) 8))

   ; -- successors per index --
   (vsucc bd)
    (: lt (vlabs bd) n #bd t {}
       (go l i)
        (atom? l ? t
           (: f <l
              nx (i + 1 < n ? [(i + 1)])
              ss (atom? f ? nx
                    (<f @ op
                       (? (op = 'jmp) (peep lt <>f -1 @ j (j < 0 ? () [j]))
                          (op = 'br) (peep lt <>>f -1 @ j (j < 0 ? nx (j . nx)))
                          (op = 'jmpt) (filter (j \ 0 <= j) (map (L \ peep lt L -1) (f 3)))
                          (elem op '(ret jmpr jmpm ud2)) ()
                          nx)))
              (pin t i ss,
               go >l (i + 1))))
       (go bd 0))

   ; -- reaching defs: rt i -> the defs (sorted subset of dfs) reaching i, over [lo, hi],
   ; a window no path leaves and returns to unseen. forward fixpoint.
   (vreach lo hi succ dfs)
    (: rt {}
       dt (foldl (t \ d \ pin t d 1) {} dfs)
       (step chg i)
        (hi < i ? chg
           (: rout (peep dt i 0 ? [i] (rt i))
              c2 (: (push l ch)
                    (atom? l ? ch
                       (<l @ j
                          (j < lo || hi < j ? (push >l ch)
                             (: old (rt j) nu (vun old rout)
                                (pin rt j nu,
                                 push >l (#nu = #old ? ch 1))))))
                    (push (succ i) chg))
              (step c2 (i + 1))))
       (fix _) (0 < step 0 lo ? (fix 0) rt)
       (fix 0))

   ; -- chain grouping: defs merge when one load's reaching set joins them.
   ; [((defs uses)..) nodefs], chains ascending by first def.
   (vgroup rt dfs uss)
    (: uf {}
       (find x) (peep uf x x @ p (p = x ? x (find p)))
       (uni a b) (: ra (find a) rb (find b)
                    (? (ra = rb) 0 (ra < rb) (pin uf rb ra) (pin uf ra rb)))
       _ (: (g l2) (atom? l2 ? 0
                      (: u <l2 rin (rt u)
                         (two? rin ?
                            (: (g2 m) (atom? m ? 0 (uni <rin <m, g2 >m))
                               (g2 >rin))
                            0,
                          g >l2)))
            (g uss))
       gt {}
       _ (: (g l2) (atom? l2 ? 0
                      (: d2 <l2 r2 (find d2)
                         (pin gt r2 (vapp (gt r2) [d2]),
                          g >l2)))
            (g dfs))
       ut {}
       nod (: (g l2 a) (atom? l2 ? (rev a)
                          (: u <l2 rin (rt u)
                             (atom? rin ? (g >l2 (u . a))
                                (find <rin @ r2
                                   (pin ut r2 (vapp (ut r2) [u]),
                                    g >l2 a)))))
              (g uss ()))
       [(map (r2 \ [(gt r2) (ut r2)]) (sort (keys gt))) nod])

   ; -- one value's boolean liveness at cell grain over [lo, hi]: kills at the
   ; stores, uses at the loads. answers i -> live out of i.
   (vclive lo hi succ kills uses)
    (: lo9 {}
       ut (foldl (t \ u \ pin t u 1) {} uses)
       kt (foldl (t \ k \ pin t k 1) {} kills)
       (lin i) (? (peep ut i 0) 1 (peep kt i 0) 0 (peep lo9 i 0))
       (sweep chg i)
        (i < lo ? chg
           (: o (: (go ss) (? (atom? ss) 0 (0 < lin <ss) 1 (go >ss)) (go (succ i)))
              old (peep lo9 i 0)
              (pin lo9 i o,
               sweep (o = old ? chg 1) (i - 1))))
       (fix _) (0 < sweep 0 hi ? (fix 0) lo9)
       (fix 0))
)) ; module 'moon
