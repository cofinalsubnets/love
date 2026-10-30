; sat -- a CDCL solver on the core's mutable maps, with a DPLL baseline as its fuzz oracle.
; a literal is a nonzero fixnum (+k var k true, -k false); a clause a list of literals.
; the module sat, a carried unit (dimacs.l, flat.l, cli.l join it); test/law/sat.l gates it.
(module 'sat
(:
   ; --- literals ---
   (vof l)  |l
   (neg l)  -l
   (sgn l)  (l < 0 ? -1 1)
   ; --- list helpers ---
   (sfind p l) (? (atom? l) () (p <l) <l (sfind p >l))                     ; first match, else ()
   (rng lo hi) (lo < hi ? (lo . rng (lo + 1) hi))                        ; [lo,hi)
   ; --- the DPLL assignment: an alist (var . +-1) ---
   (aget a v)  (? (atom? a) 0 (<<a = v) ><a (aget >a v))        ; 0 = unassigned
   (lval a l)  (aget a (vof l) @ v (? (v = 0) 0 (v = sgn l) 1 -1))      ; 1 sat / -1 false / 0 free
   (put-lit a l) ((vof l . sgn l) . a)
   ; --- clause / formula status under a ---
   (csat? a c)  (any (l \ lval a l = 1) c)
   (cfals? a c) (all (l \ lval a l = -1) c)              ; a conflict
   (sat? a formula) (all (c \ csat? a c) formula)
   ; --- unit propagation: an extended alist, or 'conflict ---
   (unit-of a c) (csat? a c ? 0
                    (filter (l \ lval a l = 0) c @ free
                       (#free = 1 ? <free 0)))       ; the one free literal, else 0
   (bcp a formula)
    ((: (go a)
        (any (c \ cfals? a c) formula ? 'conflict
           (sfind (c \ unit-of a c != 0) formula @ u
              (atom? u ? a (go (put-lit a (unit-of a u))))))) a)
   ; --- DPLL: decide a var, recurse on each polarity, backtrack on 'conflict ---
   (pick a nvars) ((: (go v) (? (v > nvars) 0 (aget a v = 0) v (go (v + 1)))) 1)   ; 0 if none
   (dpll a formula nvars)                                    ; -> a model alist | 'unsat
    (bcp a formula @ a2
       (a2 = 'conflict ? 'unsat
          (pick a2 nvars @ v
             (v = 0 ? a2
                (dpll (put-lit a2 v) formula nvars @ r
                   (r = 'unsat ? (dpll (put-lit a2 (neg v)) formula nvars) r))))))
   (solve formula nvars) (dpll () formula nvars)
   ; --- model counting, a self-check ---
   (count-models formula nvars)
    ((: (go a)
        (any (c \ cfals? a c) formula ? 0
           (pick a nvars @ v
              (v = 0 ? 1 (go (put-lit a v) + go (put-lit a (neg v))))))) ())
   ; --- instances ---
   ; cyclic "no two adjacent 0s": clauses (x_i v x_{i+1 mod n}), vars 1..n.
   ; models = the Lucas number L_n
   (cyclic n) (map (i \ [(i + 1) ((i + 1) % n + 1)]) ^n)
   (lucas n)  ((: (go k a b) (k = 0 ? a (go (k - 1) b (a + b)))) n 2 1)    ; L_0=2, L_1=1
   ; pigeonhole: h+1 pigeons in h holes, UNSAT and resolution-hard. x[p][k] = p*h+k+1
   (php h) (: P (h + 1)
              pc (map (p \ map (k \ p * h + k + 1) ^h) ^P)
              hc (foldl (a \ k \ cat a (foldl (a2 \ p \ cat a2 (foldl (\ a3 q
                       (p < q ? ([(neg (p * h + k + 1)) (neg (q * h + k + 1))] . a3) a3))
                       () ^P)) () ^P)) () ^h)
              (pc + hc))
   (php-vars h) ((h + 1) * h)

   ; --- CDCL: a mutable trail, 1-uip learning, backjump. `s` is one map of sub-maps;
   ;     each assignment carries its level and reason ---
   (vmap s k)   (s k)
   (val-of s v) (peep (vmap s 'val) v 0)                    ; 1/-1, 0 = unassigned
   (lit-val s l) (val-of s (vof l) @ v (? (v = 0) 0 (v = sgn l) 1 -1))
   (add-clause s c)                                         ; -> its id
    (peep s 'ncls 0 @ id (pin (vmap s 'cls) id c, pin s 'ncls (id + 1), id))
   (assign s lit cid)                                       ; reason cid, -1 a decision
    (: v (vof lit) t (peep s 'top 0)
       (pin (vmap s 'val) v (sgn lit), pin (vmap s 'lvl) v (peep s 'level 0),
        pin (vmap s 'reason) v cid, pin (vmap s 'trail) t lit, pin s 'top (t + 1), 0))
   (mk formula nvars)
    ({} @ s
       (pin s 'nvars nvars, pin s 'val {}, pin s 'lvl {},
        pin s 'reason {}, pin s 'trail {}, pin s 'top 0, pin s 'qhead 0,
        pin s 'level 0, pin s 'cls {}, pin s 'ncls 0, pin s 'act {},
        pin s 'watch {}, pin s 'wl {}, pin s 'bad 0,
        pin s 'phase {}, pin s 'vinc 1.0, pin s 'nconf 0, pin s 'rnum 1, pin s 'climit 100,
        foldl (\ _ c (load-clause s c)) 0 formula, s))
   ; --- two-watched-literals bcp ---
   ; watch[l] lists the clauses watching l, wl[cid] is the watched pair. unassigning only
   ; relaxes the invariant, which is why backjump need only rewind qhead.
   (enqueue s lit cid)                                      ; 0 ok, 'conflict if already false
    (lit-val s lit @ lv (? (lv = 1) 0  (lv = -1) 'conflict  (assign s lit cid, 0)))
   (watch2 s cid a b)
    (pin (vmap s 'wl) cid (a . b),
     pin (vmap s 'watch) a (cid . peep (vmap s 'watch) a ()),
     pin (vmap s 'watch) b (cid . peep (vmap s 'watch) b ()), 0)
   (dedup-lits c) (? (atom? c) () (elem <c >c) (dedup-lits >c) (<c . dedup-lits >c))
   (taut? c) (? (atom? c) 0 (elem (neg <c) >c) 1 (taut? >c))
   (load-clause s c0)                                       ; deduped, tautologies dropped
    (taut? c0 = 1 ? 0
       (dedup-lits c0 @ c
          (? (atom? c) (pin s 'bad 1)
             (atom? >c) (add-clause s c @ cid (enqueue s <c cid = 'conflict ? (pin s 'bad 1) 0))               ; a unit is a level-0 fact
             (add-clause s c @ cid (watch2 s cid <c <>c)))))
   (find-watch s cid wo)                                    ; else 0
    ((: (go ls) (atom? ls ? 0 (<ls @ l (l != wo && lit-val s l != -1 ? l (go >ls))))) (peep (vmap s 'cls) cid ()))
   (prop-lit s f)                                           ; f just went false -> conflict cid | -1
    (: res ((: (go cs kept)                                                      ; kept = still watching f
               (atom? cs ? (-1 . kept)
                  (: cid <cs rest >cs pr (peep (vmap s 'wl) cid ())
                     wo (<pr = f ? >pr <pr)
                     (lit-val s wo = 1 ? (go rest (cid . kept))
                        (find-watch s cid wo @ k
                           (? (k != 0)
                              (pin (vmap s 'wl) cid (wo . k),
                               pin (vmap s 'watch) k (cid . peep (vmap s 'watch) k ()),
                               go rest kept)                                      ; cid no longer watches f
                              (lit-val s wo = 0) (assign s wo cid, go rest (cid . kept))
                              (cid . cat kept (cid . rest))))))))               ; conflict: f keeps cid and the rest unprocessed
            (peep (vmap s 'watch) f ()) ())
       (pin (vmap s 'watch) f >res, <res))
   (propagate s)                                            ; -> conflict cid | -1
    ((: (loop _) (peep s 'qhead 0 >= peep s 'top 0 ? -1
                   (: p (peep (vmap s 'trail) (peep s 'qhead 0) ()) _ (pin s 'qhead (peep s 'qhead 0 + 1))
                      confl (prop-lit s (neg p)) (confl > -1 ? confl (loop ()))))) ())
   ; --- 1-uip conflict analysis ---
   ; fold a reason clause into (counter . learnt): count unseen level>0 vars at the
   ; conflict level, collect the lower ones. skipv the resolved var (0 = none)
   (absorb s seen dl skipv c acc)
    (foldl (st \ l \
              (vof l @ v
                 (? (v = skipv) st
                    (peep seen v 0 != 0) st
                    (peep (vmap s 'lvl) v 0 = 0) st
                    (pin seen v 1, bump s v,
                     peep (vmap s 'lvl) v 0 = dl ? ((<st + 1) . >st)
                       (<st . (l . >st))))))
           acc c)
   (find-seen tr seen idx) (peep seen (vof (peep tr idx ())) 0 = 0 ? (find-seen tr seen (idx - 1)) idx)
   (bj-level s learnt) (foldl (m \ l \ (peep (vmap s 'lvl) (vof l) 0 @ lv (lv > m ? lv m))) 0 learnt)
   ; learnt[1] must be the max-level tail literal: a lower one could be unassigned by a
   ; backtrack and the clause would go unit undetected. learnt[0] stays the asserter.
   (rem-lit x ls) (? (atom? ls) () (<ls = x) >ls (<ls . rem-lit x >ls))
   (max-lit s ls) (foldl (b \ l \ (peep (vmap s 'lvl) (vof l) 0 > peep (vmap s 'lvl) (vof b) 0 ? l b)) <ls >ls)
   (reorder-watch s learnt) (atom? >learnt ? learnt
                               (: a0 <learnt rest >learnt mx (max-lit s rest) (a0 . (mx . rem-lit mx rest))))
   (analyze s confl)                                        ; -> (learnt . backjump level), learnt[0] the asserter
    (: dl (peep s 'level 0) seen {} tr (vmap s 'trail) cls (vmap s 'cls) reason (vmap s 'reason)
       a0 (absorb s seen dl 0 (peep cls confl ()) [0])
       res ((: (go counter learnt idx)
               (: ix (find-seen tr seen idx) np (peep tr ix ()) v (vof np)
                  _ (pin seen v 0) cnt (counter - 1)
                  (cnt = 0 ? (np . learnt)
                     (absorb s seen dl v (peep cls (peep reason v 0) ()) (cnt . learnt) @ a
                        (go <a >a (ix - 1))))))
            <a0 >a0 (peep s 'top 0 - 1))
       uip <res learnt >res learntc (neg uip . learnt)
       (learntc . bj-level s learnt))
   (backjump s lvl)
    (: tr (vmap s 'trail) val (vmap s 'val) lm (vmap s 'lvl) rs (vmap s 'reason) ph (vmap s 'phase)
       nt ((: (go t)
              (t = 0 ? 0
                 (: l (peep tr (t - 1) ()) v (vof l)
                    (peep lm v 0 > lvl ?
                       (pin ph v (peep val v 1), pull val v 0, pull lm v 0, pull rs v 0, go (t - 1))                   ; saves the phase
                       t))))
           (peep s 'top 0))
       (pin s 'top nt, pin s 'qhead nt, pin s 'level lvl, 0))
   ; --- VSIDS: the increment grows per conflict so recent ones weigh more; rescale keeps
   ;     activities finite. a decision takes the var's saved phase ---
   (bump s v) (pin (vmap s 'act) v (peep (vmap s 'act) v 0.0 + peep s 'vinc 1.0))
   (rescale s) (foldl (\ _ v (pin (vmap s 'act) v (peep (vmap s 'act) v 0.0 * 1e-100))) 0 (rng 1 (peep s 'nvars 0 + 1)))
   (decay s) (peep s 'vinc 1.0 * 1.05 @ vi
                (vi > 1e100 ? (rescale s, pin s 'vinc (vi * 1e-100)) (pin s 'vinc vi)))
   (pick-branch s)
    ((: (go v best ba)
        (v > peep s 'nvars 0 ? best
           (peep (vmap s 'act) v 0.0 @ a
              (val-of s v = 0 && (best = 0 || a > ba) ? (go (v + 1) v a) (go (v + 1) best ba)))))
     1 0 -1.0)
   (pow2 k) (k 2)
   (luby i)                                                 ; Luby: 1,1,2,1,1,2,4,..
    ((: (go k) (pow2 k - 1 @ hi
                  (? (hi < i) (go (k + 1))  (hi = i) (pow2 (k - 1))  (luby (i - pow2 (k - 1) + 1))))) 1)
   (next-restart s) (peep s 'rnum 1 + 1 @ rn (pin s 'rnum rn, pin s 'nconf 0, pin s 'climit (luby rn * 100), 0))
   (search s)                                               ; -> 'sat | 'unsat, s left holding the model
    ((: (loop _)
        (propagate s @ confl
           (? (confl > -1)
              (peep s 'level 0 = 0 ? 'unsat
                 (: res (analyze s confl) learnt (reorder-watch s <res) cid (add-clause s learnt)
                    (decay s, pin s 'nconf (peep s 'nconf 0 + 1),
                     backjump s >res,
                     atom? >learnt ? 0 (watch2 s cid <learnt <>learnt),                    ; a unit learnt is a level-0 fact, unwatched
                     assign s <learnt cid, loop ())))
              (peep s 'level 0 > 0 && peep s 'nconf 0 >= peep s 'climit 0)      ; restart, learnt clauses kept
                 (backjump s 0, next-restart s, loop ())
              (pick-branch s @ v
                 (v = 0 ? 'sat
                    (pin s 'level (peep s 'level 0 + 1),
                     assign s (v * peep (vmap s 'phase) v -1) -1, loop ())))))) ())
   (extract-model s nvars) (map (v \ v . val-of s v) (rng 1 (nvars + 1)))
   (cdcl formula nvars) (mk formula nvars @ s
                           (peep s 'bad 0 = 1 ? 'unsat
                              (search s @ r (r = 'unsat ? 'unsat (extract-model s nvars)))))
   ; --- #SAT by blocking each model until UNSAT: count-cdcl (cyclic n) = Lucas n ---
   (block model) (map (vv \ neg (>vv * <vv)) model)
   (count-cdcl formula nvars)
    ((: (go fm c) (cdcl fm nvars @ r (r = 'unsat ? c (go (block r . fm) (c + 1))))) formula 0)
   ; --- random 3-SAT, a deterministic LCG, for the differential fuzz ---
   (lcg-next x)  ((x * 1103515245 + 12345) % 2147483648)
   (lit-from x n) (x // 16 % n + 1 @ v (x % 2 = 0 ? v -v))
   (gen-formula seed n m)
    ((: (go i x acc)
        (i >= m ? acc
           (: x1 (lcg-next x) x2 (lcg-next x1) x3 (lcg-next x2)
              (go (i + 1) x3 ([(lit-from x1 n) (lit-from x2 n) (lit-from x3 n)] . acc))))) 0 seed ())
   (diff-test seed n m)                                     ; DPLL and CDCL agree, a CDCL model checks
    (: f (gen-formula seed n m) d (solve f n) c (cdcl f n)
       dsat (d != 'unsat) csat (c != 'unsat)
       (? (dsat != csat) 0  !csat 1  (sat? c f)))
   (fuzz k n m) (all (i \ diff-test (i * 7919 + 1009) n m = 1) ^k))
) ; module sat
