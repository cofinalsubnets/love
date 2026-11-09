; src/love/compress/ring.l -- equalities of nat sums and products over opaque atoms, proved as uu
; paths: what a spec's step owes when its terms only regroup. both sides flatten to a list of
; monomials, and r's list is swapped into l's order. lin adds each hypothesis, times its multiplier,
; to the side it balances, and cancels them; a lemma states the identity once over its atoms.
; a proof is a term, or 'rf where the two sides are one term
(:
   (rf? p) (p == 'rf)
   (rinv x y p) (rf? p ? 'rf ['pathsinv0 'nat x y p])
   (rcomp x y z p q) (? (rf? p) q (rf? q) p ['pathscomp0 'nat x y z p q])
   (rap f x y p) (rf? p ? 'rf ['maponpaths 'nat 'nat ['lam 'z (f 'z)] x y p])
   (rfin x p) (rf? p ? ['idpath x] p)
   (rsum? e) (two? e && <e = 'add)
   (rmul? e) (two? e && <e = 'mul)
   (rop? e) (rsum? e || rmul? e)

   ; a monomial is a list of atoms, a sum a list of monomials, each right-nested
   (rM m) (? (atom? m) 1 (atom? >m) <m ['mul <m (rM >m)])
   (rS ms) (? (atom? ms) 0 (atom? >ms) (rM <ms) ['add (rM <ms) (rS >ms)])

   ; (op (B xs) (B ys)) = (B (xs + ys)), op's unit, assoc and r-unit
   (rcat op xs ys)
    (: B (op = 'add ? rS rM) e (op = 'add ? rM (x \ x))
     (? (atom? xs) 'rf
        (atom? ys) [(op = 'add ? 'natplusr0 'natmultr1) (B xs)]
        (atom? >xs) 'rf
        (: x (e <xs) R (B >xs) Y (B ys)
         (rcomp [op [op x R] Y] [op x [op R Y]] (B (xs + ys))
                [(op = 'add ? 'natplusassoc 'natmultassoc) x R Y]
                (rap (z \ [op x z]) [op R Y] (B (>xs + ys)) (rcat op >xs ys))))))

   ; the k-th and next swapped, inside the prefix before them
   (rswap op l k)
    (: B (op = 'add ? rS rM) e (op = 'add ? rM (x \ x))
       a (e (l k)) b (e (l (k + 1))) post (snip l (k + 2) #l) pre (snip l 0 k)
       (wrap z) (foldl (acc \ t \ [op (e t) acc]) z (rev pre))
     (? (atom? post)
        (: p [(op = 'add ? 'natpluscomm 'natmultcomm) a b]
         (atom? pre ? p (rap wrap [op a b] [op b a] p)))
        (: R (B post) p [(op = 'add ? 'un-pswap 'un-mswap) a b R]
         (atom? pre ? p (rap wrap [op a [op b R]] [op b [op a R]] p)))))

   ; swap l into the order ks names, the first inversion each time -> [l proof]
   (rbub op l ks)
    (: B (op = 'add ? rS rM) l0 l
       (first ks k) (? (#ks <= k + 1) -1 (ks (k + 1) < ks k) k (first ks (k + 1)))
       (sw l k) (snip l 0 k + [(l (k + 1)) (l k)] + snip l (k + 2) #l)
       (go l ks pf)
        ((first ks 0) @ k
         (k < 0 ? [l pf]
          (: l2 (sw l k) (go l2 (sw ks k) (rcomp (B l0) (B l) (B l2) pf (rswap op l k))))))
     (go l ks 'rf))

   (rkey a) (show a)
   (rrank xs) (map (x \ #(filter (y \ rkey y < rkey x) xs)) xs)

   ; atoms times atoms, sorted
   (rmono xs ys)
    (: l (xs + ys) p1 (rcat 'mul xs ys) r (rbub 'mul l (rrank l))
     [<r (rcomp ['mul (rM xs) (rM ys)] (rM l) (rM <r) p1 (r 1))])

   ; a product of two sums, distributed in order -> [monomials proof]
   (rdist xs ys)
    (? (atom? xs) [() 'rf]
       (atom? ys) [() ['natmultn0 (rS xs)]]
       (atom? >xs && atom? >ys) ((rmono <xs <ys) @ [m p] [[m] p])
       (: X (rS xs) Y (rS ys)
          sp (atom? >xs)
          e1 (sp ? ['add ['mul X (rM <ys)] ['mul X (rS >ys)]] ['add ['mul (rM <xs) Y] ['mul (rS >xs) Y]])
          p1 (sp ? ['natldistr (rM <ys) (rS >ys) X] ['natrdistr (rM <xs) (rS >xs) Y])
          A (sp ? (rdist xs [<ys]) (rdist [<xs] ys))
          C (sp ? (rdist xs >ys) (rdist >xs ys))
          a <A b <C
          p2 ['un-add2 (e1 1) (rS a) (e1 2) (rS b) (rfin (e1 1) (A 1)) (rfin (e1 2) (C 1))]
        [(a + b) (rcomp ['mul X Y] e1 (rS (a + b)) p1
                   (rcomp e1 ['add (rS a) (rS b)] (rS (a + b)) p2 (rcat 'add a b)))]))

   ; e flattened -> [monomials proof]
   (rflat e)
    (? (rop? e)
       (: A (rflat (e 1)) C (rflat (e 2)) a <A b <C
          e1 [<e (rS a) (rS b)]
          p1 (rf? (A 1) && rf? (C 1) ? 'rf
              [(<e = 'add ? 'un-add2 'un-mul2) (e 1) (rS a) (e 2) (rS b) (rfin (e 1) (A 1)) (rfin (e 2) (C 1))])
        (<e = 'add ? [(a + b) (rcomp e e1 (rS (a + b)) p1 (rcat 'add a b))]
         ((rdist a b) @ [l p2] [l (rcomp e e1 (rS l) p1 p2)])))
       (e = 0) [() 'rf]
       (e = 1) [[()] 'rf]
       [[[e]] 'rf])

   ; where each of rs stands in ls, a repeat taking the next
   (rplace rs ls)
    (: (go rs used)
        (atom? rs ? ()
         (: j (first-free <rs 0 used) (j . go >rs (j . used))))
       (first-free m k used) (? (#ls <= k) -1 (ls k = m && !(elem k used)) k (first-free m (k + 1) used))
     (go rs ()))
   (rsame ls rs) (sort (map rkey ls) = sort (map rkey rs))

   ; l = r when they regroup alike
   (req l r)
    (: L (rflat l) R (rflat r)
       _ (rsame <L <R ? 0 (quit-on "ring: the two sides differ\n \(show l)\n \(show r)"))
       Bb (rbub 'add <R (rplace <R <L))
       c (rS <L)
     (rfin l (rcomp l c r (L 1) (rinv r c (rcomp r (rS <R) c (R 1) (Bb 1))))))
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
   (rbal l r hs) (rsame <(rflat ['add l (rnest (map (h \ rtimes (h 0) (h 2)) hs))])
                        <(rflat ['add r (rnest (map (h \ rtimes (h 0) (h 1)) hs))]))
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
