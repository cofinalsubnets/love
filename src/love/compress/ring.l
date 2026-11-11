; src/love/compress/ring.l -- equalities of nat sums and products over opaque atoms, proved as uu
; paths: what a spec's step owes when its terms only regroup. both sides are encoded as a rex
; over their atoms and proved equal by reflection. lin adds each hypothesis, times its multiplier,
; to the side it balances, and cancels them; a lemma states the identity once over its atoms.
; a proof is a term, or 'rf where the two sides are one term
(:
   (rf? p) (p == 'rf)
   (rinv x y p) (rf? p ? 'rf ['pathsinv0 'nat x y p])
   (rcomp x y z p q) (? (rf? p) q (rf? q) p ['pathscomp0 'nat x y z p q])
   (rap f x y p) (rf? p ? 'rf ['maponpaths 'nat 'nat ['lam 'z (f 'z)] x y p])
   (rsum? e) (two? e && <e = 'add)
   (rmul? e) (two? e && <e = 'mul)
   (rop? e) (rsum? e || rmul? e)

   ; e flattened to its monomials, each a list of atoms
   (rflat e)
    (? (rsum? e) (rflat (e 1) + rflat (e 2))
       (rmul? e) (: b (rflat (e 2)) (cats (map (x \ map (y \ x + y) b) (rflat (e 1)))))
       (e = 0) ()
       (e = 1) [()]
       [[e]])
   (rkey a) (show a)
   (rsame ls rs) (sort (map (m \ sort (map rkey m)) ls) = sort (map (m \ sort (map rkey m)) rs))

   ; l = r when they regroup alike: both encoded over their atoms as a rex, whose normal forms
   ; the kernel computes and compares (test/uumag.l's rex-eq)
   (renc as e)
    (? (rop? e) [(rsum? e ? 'rexa 'rexm) (renc as (e 1)) (renc as (e 2))]
       (e = 0) 'rexz
       (e = 1) 'rexo
       ['rexv (: (go k) (as k = e ? k (go (k + 1))) (go 0))])
   (req l r)
    (: _ (rsame (rflat l) (rflat r) ? 0 (quit-on "ring: the two sides differ\n \(show l)\n \(show r)"))
       as (ratoms r (ratoms l ()))
       x (renc as l)
     ['rex-eq (foldr (\ a t ['rexl1 a t]) 'rexl0 as) x (renc as r) ['idpath ['rex-norm x]]])
   (quit-on s) (puts "\(s)\n", quit 1)

   ; a hypothesis is [m lhs rhs proof], m the multiplier or ()
   (rnest ts) (atom? >ts ? <ts ['add <ts (rnest >ts)])
   (rtimes m t) (m == () ? t ['mul m t])
   (rlin l r hs)
    (: tl (map (h \ rtimes (h 0) (h 1)) hs) tr (map (h \ rtimes (h 0) (h 2)) hs)
       X (rnest tl) Y (rnest tr)
       (with ts k t) (snip ts 0 k + [t] + snip ts (k + 1) #ts)
       (step k cur pf)
        (? (#hs <= k) pf
           (: h (hs k) tp (h 0 == () ? (h 3) (rap (z \ ['mul (h 0) z]) (h 1) (h 2) (h 3)))
              new (with cur k (tr k))
              q (#cur < 2 ? tp (rap (z \ rnest (with cur k z)) (cur k) (tr k) tp))
            (step (k + 1) new (rcomp X (rnest cur) (rnest new) pf q))))
       s1 (rap (z \ ['add l z]) X Y (step 0 tl 'rf))
       s2 (req ['add l Y] ['add r X])
     ['un-cancr l r X (rcomp ['add l X] ['add l Y] ['add r X] s1 s2)])
   ; each hypothesis either way round, the first that balances
   (rflip h) [(h 0) (h 2) (h 1) (rinv (h 1) (h 2) (h 3))]
   (rbal l r hs) (rsame (rflat ['add l (rnest (map (h \ rtimes (h 0) (h 2)) hs))])
                        (rflat ['add r (rnest (map (h \ rtimes (h 0) (h 1)) hs))]))
   (rorient l r hs)
    (: (go k hs)
        (? (#hs <= k) (rbal l r hs ? hs ())
           ((go (k + 1) hs) @ a (two? a ? a (go (k + 1) (snip hs 0 k + [(rflip (hs k))] + snip hs (k + 1) #hs)))))
     (go 0 hs))
   (rlina l r hs)
    (atom? hs ? (req l r)
     ((rorient l r hs) @ o (two? o ? (rlin l r o) (quit-on "ring: no orientation balances \(show l)"))))

   ; --- a lemma over the identity's atoms: [name l r hyps] -> its defq, and its use ----------
   (ratoms e acc) (? (rop? e) (ratoms (e 2) (ratoms (e 1) acc)) (e = 0 || e = 1 || elem e acc) acc (acc + [e]))
   (rvars id)
    (: hs (id 3)
     (foldl (acc \ e \ ratoms e acc) () ([(id 1) (id 2)] + cats (map (h \ (h 0 == () ? () [(h 0)]) + [(h 1) (h 2)]) hs))))
   (rsubst m e) (? (rop? e) [<e (rsubst m (e 1)) (rsubst m (e 2))] (e = 0 || e = 1) e (peep m ("#" + show e) e))
   (ring-lemma id)
    (: as (rvars id) vs (map (k \ intern "x\(k)") (jot #as))
       m (foldl (t \ k \ pin t ("#" + show (as k)) (vs k)) {} (jot #as))
       hs (map (k \ ((id 3) k) @ h [(h 0 == () ? () (rsubst m (h 0))) (rsubst m (h 1)) (rsubst m (h 2)) (intern "e\(k)")]) (jot #(id 3)))
       l (rsubst m (id 1)) r (rsubst m (id 2))
       pis (cats (map (v \ [v 'nat]) vs) + cats (map (h \ [(h 3) ['paths 'nat (h 1) (h 2)]]) hs))
     " (defq \(id 0) \(show ('pi . (pis + [['paths 'nat l r]])))\n   \(show ('lam . (vs + map (h \ h 3) hs + [(rlina l r hs)]))))\n")
   (ring-use id) ((intern (id 0)) . ((rvars id) + map (h \ h 3) (id 3))))
