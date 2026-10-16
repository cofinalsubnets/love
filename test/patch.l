; test/patch.l -- the patch groupoid: distribution, namespace and repo-state as one algebra, commute underneath
; test/uupatch.l is the uu twin, name for name
; the named-slot model: a tree is a (key . value) assoc, a patch one slot-change in context, commute the partial swap
; the corpus is one scope: shared helpers carry pt-

(:
 ; the shared kit: sequences, trees, paths, patch shapes, the clash cell, patterns
 (pt-htake s n) (n < 1 ? () (<s . pt-htake >s (n - 1)))
 (pt-hdrop s n) (n < 1 ? s (pt-hdrop >s (n - 1)))
 (pt-hcat a b) (atom? a ? b (<a . pt-hcat >a b))
 (pt-seg s i n) (pt-htake (pt-hdrop s i) n)
 (pt-splice s i c news) (pt-hcat (pt-htake s i) (pt-hcat news (pt-hdrop s (i + c))))
 (pt-nth s j) <(pt-hdrop s j)
 (pt-heq a b) (? (atom? a && atom? b) (a = b)
               (atom? a || atom? b) 0
               (pt-heq <a <b && pt-heq >a >b))
 (pt-tnav t path) (atom? path ? t (pt-tnav (pt-nth t <path) >path))
 (pt-tlay t path s2)
    (atom? path ? s2
       (pt-splice t <path 1
               [(pt-tlay (pt-nth t <path) >path s2)]))
 (pt-setidx path d v) (d = 0 ? (v . >path)
                       (<path . pt-setidx >path (d - 1) v))
 (pt-rel P Q d) (? (atom? P && atom? Q) '(same)
                 (atom? P) ['inq <Q d]
                 (atom? Q) ['inp <P d]
                 (<P = <Q) (pt-rel >P >Q (d + 1))
                 '(apart))
 (pt-pathok t path) (atom? path ? 1
                     (<path @ j
                      (j < #t
                          && (pt-nth t j @ e
                              (!(atom? e) && pt-pathok e >path)))))
 (pt-tp path i o n) ['tp path i o n]
 (pt-pp p) <>p
 (pt-pi p) <>>p
 (pt-po p) <>>>p
 (pt-pn p) <>>>>p
 (pt-hunk i o n) ['hunk i o n]
 (pt-hi p) <>p
 (pt-ho p) <>>p
 (pt-hn p) <>>>p
 (pt-pk p) <>p
 (pt-pa p) <>>p
 (pt-pb p) <>>>p
 (pt-tget t k) (atom? t ? 0 (<t @ c (k = <c ? >c (pt-tget >t k))))
 (pt-tset t k v) ((k . v) . t)
 (pt-clash a rs) ['clash a rs]
 (pt-clash? v) (atom? v ? 0 (<v = 'clash))
 (pt-cbase c) <>c
 (pt-rivals c) <>>c
 (pt-cins x rs) (atom? rs ? [x]
                 (<rs @ h
                  (? (x = h) rs
                     (x < h) (x . rs)
                     (h . pt-cins x >rs))))
 (pt-hstr h s i n) (i = n ? h (pt-hstr (((h * 33) + s i) % 4294967296) s (i + 1) n))
 (pt-hval v) (show v @ s (pt-hstr 5381 s 0 #s))
 (pt-asq k s) (atom? s ? () (<s @ c (k = <c ? [>c] (pt-asq k >s))))
 (pt-mv? x) (atom? x ? 0 (<x = 'mv))
 (pt-mvname x) <>x
 (pt-inst p s) (? (pt-mv? p) (pt-asq (pt-mvname p) s @ r (atom? r ? p <r))
                (atom? p) p
                (pt-inst <p s . pt-inst >p s))
 (pt-mtch p g s)
    (? (s = 'no) 'no
       (pt-mv? p) (pt-asq (pt-mvname p) s @ r
                (atom? r ? ((pt-mvname p . g) . s)
                   (pt-heq <r g ? s 'no)))
       (atom? p && atom? g) (p = g ? s 'no)
       (atom? p || atom? g) 'no
       (pt-mtch >p >g (pt-mtch <p <g s))))

(:
 ; --- the model ---
 (chg k a b) ['chg k a b]                 ; patch: change slot k, old->new
 (valid t p) (pt-tget t (pt-pk p) = pt-pa p)              ; a patch belongs iff its context matches
 (apon t p) (pt-tset t (pt-pk p) (pt-pb p))               ; lay the patch's new value
 (applall t ps) (foldl apon t ps)                ; fold a whole frontier onto a tree
 (invert p) (chg (pt-pk p) (pt-pb p) (pt-pa p))           ; the groupoid inverse (unpull)
 (commute p q) (pt-pk p = pt-pk q ? 0 [q p])     ; partial: 0 = a dependency

 ; --- tree agreement at a witness key set ---
 (teq a b ks) (atom? ks ? 1 ((pt-tget a <ks = pt-tget b <ks) && teq a b >ks))

 ; --- witnesses ---
 px (chg 'x 0 1) py (chg 'y 0 2)                          ; independent -- different slots
 p1 (chg 'x 0 1) p2 (chg 'x 1 2)                          ; dependent -- same slot

 ; (L1) commute is involutive; same-slot patches don't commute
 ((test
   (pt-heq (commute px py) [py px])                          ; p;q -> q;p
   (commute px py @ c (pt-heq (commute <c <>c)
                           [px py]))                      ; ...and back to p;q
   !(commute p1 p2)                                                  ; same slot -> no commute
   (pt-heq p1 p1) !(pt-heq px py)),                                        ; leq itself is honest

  ; (L2) inverse round-trips in context; invert is its own inverse
  (: t0 (pt-tset () 'x 5) p (chg 'x 5 9)
     (test
      (valid t0 p)                                                   ; p belongs on t0
      (apon (apon t0 p) (invert p) @ t1 (teq t1 t0 '(x y)))          ; apply;unpull == id
      (pt-heq p (invert (invert p))))),                                 ; invert involutive

  ; (L3a) independent patches are order-free: both pull orders land the same tree
  (: a (apon (apon 0 px) py) b (apon (apon 0 py) px)
     (test (teq a b '(x y)) (1 = pt-tget a 'x) (2 = pt-tget a 'y))),

  ; (L3b) a frontier is stable under an adjacent independent swap, so the patch set is a sound identity
  (: pre [(chg 'a 0 7)] post [(chg 'b 0 8)]
     f1 (applall () (pt-hcat pre (px . py . post)))                ; pre ++ [px py] ++ post
     f2 (applall () (pt-hcat pre (py . px . post)))                ; ...px,py swapped
     ((test (teq f1 f2 '(a b x y))),
      (: holo [(chg 'holo 0 1)] glaze [(chg 'glaze 0 1)]
         (test (teq (applall () (pt-hcat holo glaze))
                      (applall () (pt-hcat glaze holo)) '(holo glaze)))))),
  0))

; --- the positional rung: (hunk i olds news) over a sequence; commute re-aims by the length delta ---
; touching hunks refuse (two inserts on one seam have no order); valid's bound keeps L2 honest

(:
 ; --- the model: sequences and hunks ---
 (valid s p) ((pt-hi p + #(pt-ho p)) <= #s                ; in range -- the round-trip bound
                 && pt-heq (pt-seg s (pt-hi p) #(pt-ho p)) (pt-ho p))
 (apon s p) (pt-splice s (pt-hi p) #(pt-ho p) (pt-hn p))
 (applall s ps) (foldl apon s ps)
 (invert p) (pt-hunk (pt-hi p) (pt-hn p) (pt-ho p))

 ; --- commute: q past p's news shifts back by p's delta, q before shifts p forward; overlap or touch -> () ---
 (commute p q)
   (: i (pt-hi p) o1 #(pt-ho p) n1 #(pt-hn p)
      j (pt-hi q) o2 #(pt-ho q) n2 #(pt-hn q)
      (? (j > (i + n1)) [(pt-hunk ((j + o1) - n1) (pt-ho q) (pt-hn q)) p]
         ((j + o2) < i) [q (pt-hunk ((i + n2) - o2) (pt-ho p) (pt-hn p))]
         ()))

 ; --- witnesses: a file of five forms; p grows the file (delta +1) ---
 s0 '(a b c d e)
 p (pt-hunk 1 '(b) '(x y))                                   ; at 1, b -> x y
 q (pt-hunk 4 '(d) '(z))                                     ; post-p coords: d sits at 4

 ; (L1) involutive, and a real re-aim: q comes back at its pre-p seat
 ((: c (commute p q) cq <c cp <>c
     (test
      (4 = pt-hi q) (3 = pt-hi cq)                          ; the shift is real
      (pt-heq cp p)
      (commute cq cp @ c2
       (pt-heq <c2 p && pt-heq <>c2 q)))),

  ; dependencies: overlap, and the seam -- touching refuses too (strict)
  (test
   !(commute p (pt-hunk 2 '(y) '(w)))                        ; lands inside p's news
   !(commute p (pt-hunk 3 '(c) '(w)))                        ; starts exactly at p's end
   !(commute (pt-hunk 1 () '(u)) (pt-hunk 1 () '(v)))),         ; two inserts, one seam

  ; (L2) round-trips; the bound refuses the out-of-range insert whose round-trip would lie
  (test
   (valid s0 p)
   (pt-heq (apon (apon s0 p) (invert p)) s0)
   (pt-heq p (invert (invert p)))
   !(valid '(a) (pt-hunk 5 () '(u)))),                       ; past the end: no home

  ; (L3a) p;q and q';p' land the same sequence; un-shifted q has no home on s0
  (: c (commute p q) cq <c cp <>c
     (test
      (pt-heq (apon (apon s0 p) q) (apon (apon s0 cq) cp))
      (pt-heq (apon (apon s0 p) q) '(a x y c z e))
      !(valid s0 q))),                                    ; naive swap: context miss

  ; a shrinking p (delta -1) shifts q the other way -- same law, other sign
  (: pn (pt-hunk 1 '(b c) '(u)) qn (pt-hunk 3 '(e) '(w))        ; post-pn coords: e at 3
     c (commute pn qn) cq <c cp <>c
     (test
      (4 = pt-hi cq)                                       ; back up to its s0 seat
      (pt-heq (apon (apon s0 pn) qn) (apon (apon s0 cq) cp))
      (pt-heq (apon (apon s0 pn) qn) '(a u d w)))),

  ; the before branch: q lands ahead of p, so p is the one re-aimed (by q's delta)
  (: pb (pt-hunk 3 '(d) '(w)) qb (pt-hunk 0 '(a b) '(u))        ; qb shrinks the prefix
     c (commute pb qb) cq <c cp <>c
     (test
      (pt-heq cq qb) (2 = pt-hi cp)                           ; q unmoved; p slides down
      (pt-heq (apon (apon s0 pb) qb) (apon (apon s0 cq) cp))
      (pt-heq (apon (apon s0 pb) qb) '(u c w e)))),

  ; elements are forms, not lines: a hunk swaps a whole definition
  (: fs '((f a) (g b) (main ()))
     fp (pt-hunk 1 '((g b)) '((g c) (h d)))
     (test (valid fs fp)
             (pt-heq (apon fs fp) '((f a) (g c) (h d) (main ()))))),

  ; (L3b) a frontier is stable under the adjacent independent swap
  (: c (commute p q)
     f1 (applall s0 [(pt-hunk 0 '(a) '(aa)) p q])
     f2 (applall s0 (pt-hunk 0 '(a) '(aa) . c))
     (test (pt-heq f1 f2) (pt-heq f1 '(aa x y c z e)))),
  0))

; --- the conflictor rung: merge is total, a conflicted slot holds a clash cell (base + ordered rivals) ---
; resolving is an ordinary invertible chg; pull trusts the co-valid discipline, valid gates a lone patch

(:
 ; --- the model: the named-slot trees and patches, plus the clash cell ---
 (chg k a b) ['chg k a b]
 (invert p) (chg (pt-pk p) (pt-pb p) (pt-pa p))
 (teq a b ks) (atom? ks ? 1 (pt-heq (pt-tget a <ks) (pt-tget b <ks)
                                && teq a b >ks))

 ; --- pull: total merge-application; a cell-shaped mismatch no-ops ---
 (pull t p)
   (: k (pt-pk p) a (pt-pa p) b (pt-pb p) v (pt-tget t k)
      (? (pt-heq v a) (pt-tset t k b)                            ; the plain lane: context matches
         (pt-heq v b) t                                       ; the same edit again: settled
         (pt-clash? v && (pt-heq (pt-cbase v) a && !(pt-clash? b)))
           (pt-tset t k (pt-clash a (pt-cins b (pt-rivals v))))        ; join the rivals
         (!(pt-clash? v) && !(pt-clash? a) && !(pt-clash? b))
           (pt-tset t k (pt-clash a (pt-cins b (pt-cins v ()))))       ; a rival landed first
         t))                                               ; discipline breach: no-op
 (applall t ps) (foldl pull t ps)

 ; --- witnesses: three rivals for x over base 1, and an independent bystander ---
 t0 (pt-tset () 'x 1)
 p (chg 'x 1 2) q (chg 'x 1 3) r (chg 'x 1 4)
 w (chg 'y 0 9)

 ; (M1) merge is total and symmetric: both pull orders land the same tree
 ((test
   (teq (pull (pull t0 p) q) (pull (pull t0 q) p) '(x y))
   (teq (pull (pull t0 p) w) (pull (pull t0 w) p) '(x y))),

  ; (M2) a matching context applies; the same edit twice settles
  (test
   (2 = pt-tget (pull t0 p) 'x)
   (teq (pull (pull t0 p) p) (pull t0 p) '(x y))),

  ; (M3) a conflict keeps the base and both rivals, canonically ordered
  (: m (pull (pull t0 q) p) c (pt-tget m 'x)
     (test (pt-clash? c) (1 = pt-cbase c) (pt-heq (pt-rivals c) '(2 3)))),

  ; (M4) three rivals, any order: one cell, one set
  (: m1 (pull (pull (pull t0 p) q) r)
     m2 (pull (pull (pull t0 r) q) p)
     m3 (pull (pull (pull t0 q) r) p)
     (test (teq m1 m2 '(x)) (teq m2 m3 '(x))
             (pt-heq (pt-rivals (pt-tget m1 'x)) '(2 3 4)))),

  ; (M5) resolution is a patch from the cell; invert unpulls it and the clash returns
  (: m (pull (pull t0 p) q) cell (pt-tget m 'x)
     res (chg 'x cell 5)
     m2 (pull m res)
     (test
      (5 = pt-tget m2 'x) !(pt-clash? (pt-tget m2 'x))
      (teq (pull m2 (invert res)) m '(x y)))),

  ; two components pinning one name differently land the same clash in either order
  (: holo [(chg 'font 0 1)] glaze [(chg 'font 0 2)]
     fa (applall () (pt-hcat holo glaze))
     fb (applall () (pt-hcat glaze holo))
     (test (teq fa fb '(font)) (pt-clash? (pt-tget fa 'font)))),
  0))

; --- the identity rung: a version is its patch set, hashed canonically ---
; frontier meaning forgets order and repetition, so hash each patch's show and fold through cins

(:
 (fid ps) (foldl (acc \ p \ pt-cins (pt-hval p) acc) () ps)      ; the canonical hash set
 (ident ps) (pt-hval (fid ps))                                 ; one scalar to name it
 (chg k a b) ['chg k a b]

 ; --- witnesses ---
 p (chg 'x 1 2) q (chg 'x 1 3) w (chg 'y 0 9)

 ; (H1) order-free: any pull order, one identity
 ((test
   (ident [p q w] = ident [w q p])
   (ident [p w] = ident [w p])),

  ; (H2) multiplicity-free: pulling twice settles, the name agrees
  (test (ident [p p q] = ident [p q])),

  ; (H3) content-sensitive: touch any patch, or invert it, and the name moves
  (test
   !(ident [p] = ident [q])
   !(ident [p q] = ident [p w])
   !(ident [p] = ident [(chg 'x 2 1)])),
  0))

; --- the tree lift rung: a hunk gets a path; a shallow splice re-aims a deeper patch's path ---
; lanes by path relation: same (the positional shift), inq/inp (the deeper re-aims at the crossing; inside is a dependency), apart
; at a crossing >= is sound where the seam needed >: a path component names a survivor, not a seam

(:
 ; --- the sequence kit (local) ---

 ; --- the tree kit: navigate to a path's sequence, lay a new one back ---

 ; --- patches: (tp path i olds news) -- a hunk with a postcode ---
 (apon t p) (pt-tlay t (pt-pp p) (pt-splice (pt-tnav t (pt-pp p)) (pt-pi p) #(pt-po p) (pt-pn p)))
 (applall t ps) (foldl apon t ps)
 (invert p) (pt-tp (pt-pp p) (pt-pi p) (pt-pn p) (pt-po p))
 (valid t p) (pt-pathok t (pt-pp p)
                 && (pt-tnav t (pt-pp p) @ s
                     ((pt-pi p + #(pt-po p)) <= #s
                         && pt-heq (pt-seg s (pt-pi p) #(pt-po p)) (pt-po p))))

 ; --- path surgery + the path relation ---

 ; --- commute: four lanes; re-aim the index at 'same, the path at the crossings ---
 (commute p q)
   (: P (pt-pp p) ip (pt-pi p) o1 #(pt-po p) n1 #(pt-pn p) dp (n1 - o1)
      Q (pt-pp q) iq (pt-pi q) o2 #(pt-po q) n2 #(pt-pn q) dq (n2 - o2)
      r (pt-rel P Q 0) tag <r
      (? (tag = 'same)
           (? (iq > (ip + n1)) [(pt-tp Q ((iq + o1) - n1) (pt-po q) (pt-pn q)) p]
              ((iq + o2) < ip) [q (pt-tp P ((ip + n2) - o2) (pt-po p) (pt-pn p))]
              ())
         (tag = 'inq)
           (: j <>r d <>>r
              (? (j < ip) [q p]
                 (j >= (ip + n1))
                   [(pt-tp (pt-setidx Q d (j - dp)) iq (pt-po q) (pt-pn q)) p]
                 ()))
         (tag = 'inp)
           (: j <>r d <>>r
              (? (j < iq) [q p]
                 (j >= (iq + o2))
                   [q (pt-tp (pt-setidx P d (j + dq)) ip (pt-po p) (pt-pn p))]
                 ()))
         [q p]))

 ; --- witnesses: a little program -- three top forms, one nested ---
 t0 '((: a 1) (: b 2) (main (f x)))
 pr (pt-tp () 0 () '((borrow m)))                                ; root insert at 0 (dp +1)
 qd (pt-tp '(3) 1 '((f x)) '((g y)))                          ; deep edit, aimed post-pr

 ; (L1) involutive, and a path re-aim: qd slides 3 -> 2
 ((: c (commute pr qd) cq <c cp <>c
     (test
      (pt-heq (pt-pp qd) '(3)) (pt-heq (pt-pp cq) '(2))                ; the path moved
      (pt-heq cp pr)
      (commute cq cp @ c2
       (pt-heq <c2 pr && pt-heq <>c2 qd)))),

  ; dependencies: a deep edit inside fresh news, and the swallow
  (test
   !(commute pr (pt-tp '(0) 0 '(borrow) '(want)))                ; inside pr's news
   !(commute (pt-tp '(1) 2 '(1) '(7)) (pt-tp () 1 '((: a 7)) ()))),     ; swallowed

  ; (L2) inverse round-trips at depth
  (pt-tp '(2) 1 '((f x)) '((g y) (h z)) @ pd
   (test
    (valid t0 pd)
    (pt-heq (apon (apon t0 pd) (invert pd)) t0)
    (valid t0 (pt-tp '(2 1) 0 () '(u)))                       ; (f x) is a sequence: descend
    !(valid t0 (pt-tp '(9) 0 () '(u)))                        ; no such child
    !(valid t0 (pt-tp '(2 0) 0 () '(u))))),                   ; main is a leaf: no descent

  ; (L3a) sound across levels; the un-shifted qd has no home on t0
  (: c (commute pr qd) cq <c cp <>c
     (test
      (pt-heq (apon (apon t0 pr) qd) (apon (apon t0 cq) cp))
      (pt-heq (apon (apon t0 pr) qd)
           '((borrow m) (: a 1) (: b 2) (main (g y))))
      !(valid t0 qd))),

  ; the inp lane: a deep edit rides a root shrink the other way (path 2 -> 1)
  (: pd (pt-tp '(2) 1 '((f x)) '((g y))) qr (pt-tp () 0 '((: a 1)) ())
     c (commute pd qr) cq <c cp <>c
     (test
      (pt-heq cq qr) (pt-heq (pt-pp cp) '(1))                       ; p slides down
      (pt-heq (apon (apon t0 pd) qr) (apon (apon t0 cq) cp))
      (pt-heq (apon (apon t0 pd) qr) '((: b 2) (main (g y)))))),

  ; apart: sibling subtrees ride untouched, both orders agree
  (: pa (pt-tp '(0) 2 '(1) '(9)) qa (pt-tp '(2) 1 '((f x)) '((g y)))
     c (commute pa qa)
     (test
      (pt-heq <c qa) (pt-heq <>c pa)
      (pt-heq (apon (apon t0 pa) qa) (apon (apon t0 qa) pa)))),

  ; same sequence at depth: the positional shift, riding a postcode
  (: ts '((a b c d e))
     p1 (pt-tp '(0) 1 '(b) '(x y)) q1 (pt-tp '(0) 4 '(d) '(z))
     c (commute p1 q1) cq <c
     (test
      (3 = pt-pi cq) (pt-heq (pt-pp cq) '(0))                     ; index shifts, path rides
      (pt-heq (apon (apon ts p1) q1) (apon (apon ts cq) <>c))
      (pt-heq (apon (apon ts p1) q1) '((a x y c z e))))),

  ; (L3b) a frontier is stable under the adjacent independent swap, mixed grains
  (: c (commute pr qd)
     f1 (applall t0 [pr qd])
     f2 (applall t0 c)
     (test (pt-heq f1 f2))),
  0))

; --- the content-rewrite rung: the swallow commutes, its context rewritten through ---
; undo the deep edit inside the shallow context, re-aim it at the content's survivor; ambiguity refuses
; the mirror lane is p;q = (q^-1;p^-1)^-1, so one core (swal) serves both directions

(:
 ; --- the tree kit (local) ---
 (apon t p) (pt-tlay t (pt-pp p) (pt-splice (pt-tnav t (pt-pp p)) (pt-pi p) #(pt-po p) (pt-pn p)))
 (applall t ps) (foldl apon t ps)
 (invert p) (pt-tp (pt-pp p) (pt-pi p) (pt-pn p) (pt-po p))
 (valid t p) (pt-pathok t (pt-pp p)
                 && (pt-tnav t (pt-pp p) @ s
                     ((pt-pi p + #(pt-po p)) <= #s
                         && pt-heq (pt-seg s (pt-pi p) #(pt-po p)) (pt-po p))))

 ; --- matching: occs and ffind descend alike, so the ==1 guard names ffind's answer ---
 (occs f x) (atom? f ? 0
                (<f @ h
                 ((? (pt-heq h x) 1 (atom? h) 0 (occs h x))
                  + occs >f x)))
 (ffind f x) (atom? f ? ()
                (<f @ h
                 (pt-heq h x ? '(0)
                    ((atom? h ? () (ffind h x)) @ r
                     (!(atom? r) ? (0 . r)
                        (ffind >f x @ d
                         (atom? d ? ()
                            ((<d + 1) . >d))))))))
 ; the unit walk: the shallowest deep-path prefix whose subtree survives on the far side, () on erasure
 (sunit el R n2 k)
   (? !(pt-pathok el (pt-htake R k)) ()
      (0 < occs n2 (pt-tnav el (pt-htake R k))) [k]
      (#R <= k) ()
      (sunit el R n2 (k + 1)))

 ; --- swal: undo dp inside the unit, lay the pre state into sp's sides, re-aim dp at the survivor;
 ;     any guard miss answers (), declining is always sound ---
 (swal dp sp j d)
   (: S (pt-pp sp) is (pt-pi sp) O (pt-po sp) N (pt-pn sp)
      R (pt-hdrop (pt-pp dp) (d + 1)) off (j - is) el (pt-nth O off)
      (atom? el ? ()
         (sunit el R N 0 @ u
          (atom? u ? ()
             (: k <u Rk (pt-htake R k) Rrem (pt-hdrop R k)
                ep (pt-tnav el Rk)
                bak (pt-tp Rrem (pt-pi dp) (pt-pn dp) (pt-po dp))
                (!(valid ep bak) ? ()
                   (apon ep bak @ e
                    (!(1 = occs O ep
                              && (0 = occs O e
                                  && ((1 = occs N ep) && (0 = occs N e)))) ? ()
                       (ffind N ep @ fd
                        (. (pt-tp S is (pt-tlay O (off . Rk) e) (pt-tlay N fd e))
                              (. (pt-tp (pt-hcat S (pt-hcat (pt-setidx fd 0 (is + <fd)) Rrem))
                                        (pt-pi dp) (pt-po dp) (pt-pn dp))
                                    ())))))))))))

 ; --- commute: the four lanes, the swallows now doors; inq flips through the groupoid inverse ---
 (commute p q)
   (: P (pt-pp p) ip (pt-pi p) o1 #(pt-po p) n1 #(pt-pn p)
      Q (pt-pp q) iq (pt-pi q) o2 #(pt-po q) n2 #(pt-pn q)
      r (pt-rel P Q 0) tag <r
      (? (tag = 'same)
           (? (iq > (ip + n1)) [(pt-tp Q ((iq + o1) - n1) (pt-po q) (pt-pn q)) p]
              ((iq + o2) < ip) [q (pt-tp P ((ip + n2) - o2) (pt-po p) (pt-pn p))]
              ())
         (tag = 'inq)
           (: j <>r d <>>r
              (? (j < ip) [q p]
                 (j >= (ip + n1))
                   [(pt-tp (pt-setidx Q d ((j + o1) - n1)) iq (pt-po q) (pt-pn q)) p]
                 (swal (invert q) (invert p) j d @ c
                  (atom? c ? ()
                     [(invert <>c) (invert <c)]))))
         (tag = 'inp)
           (: j <>r d <>>r
              (? (j < iq) [q p]
                 (j >= (iq + o2))
                   [q (pt-tp (pt-setidx P d ((j + n2) - o2)) ip (pt-po p) (pt-pn p))]
                 (swal p q j d)))
         [q p]))

 ; --- witnesses: pd edits deep, qm moves the edited form (its context aimed post-pd) ---
 t0 '((: a 1) (: b 2) (main (f x)))
 pd (pt-tp '(1) 2 '(2) '(9))                                  ; deep: (: b 2) -> (: b 9)
 qm (pt-tp () 1 '((: b 9) (main (f x))) '((main (f x)) (: b 9)))

 ; (L1) the swallow commutes: qm's context rewrites to the pre state, pd re-aims 1 -> 2
 ((: c (commute pd qm) cq <c cp <>c
     (test
      (pt-heq (pt-pp cp) '(2))                                   ; the survivor's new seat
      (pt-heq (pt-po cq) '((: b 2) (main (f x))))                ; undo laid into olds
      (pt-heq (pt-pn cq) '((main (f x)) (: b 2)))                ; ...and into news
      (commute cq cp @ c2
       (pt-heq <c2 pd && pt-heq <>c2 qm)))),

  ; (L3a) both orders land the same tree; the un-rewritten qm has no home on t0
  (: c (commute pd qm) cq <c cp <>c
     (test
      (pt-heq (apon (apon t0 pd) qm) (apon (apon t0 cq) cp))
      (pt-heq (apon (apon t0 pd) qm) '((: a 1) (main (f x)) (: b 9)))
      !(valid t0 qm))),

  ; the wrap: the survivor sits deeper in the news, so the path grows (1 -> 1 1); back is home
  (: qw (pt-tp () 1 '((: b 9)) '((guard (: b 9))))
     c (commute pd qw) cq <c cp <>c
     (test
      (pt-heq (pt-pp cp) '(1 1))
      (pt-heq (pt-pn cq) '((guard (: b 2))))
      (pt-heq (apon (apon t0 pd) qw) (apon (apon t0 cq) cp))
      (commute cq cp @ c2
       (pt-heq <c2 pd && pt-heq <>c2 qw)))),

  ; the mirror lane: the move first, the edit re-aims to the pre-move seat (2 -> 1)
  (: pm (pt-tp () 1 '((: b 2) (main (f x))) '((main (f x)) (: b 2)))
     qd (pt-tp '(2) 2 '(2) '(9))
     c (commute pm qd) cq <c cp <>c
     (test
      (pt-heq (pt-pp cq) '(1))
      (pt-heq (pt-po cp) '((: b 9) (main (f x))))
      (pt-heq (apon (apon t0 pm) qd) (apon (apon t0 cq) cp))
      (pt-heq (apon (apon t0 pm) qd) '((: a 1) (main (f x)) (: b 9)))
      (commute cq cp @ c2
       (pt-heq <c2 pm && pt-heq <>c2 qd)))),

  ; refusals: erasure, duplication, the pre state already in news, freshly written content
  (test
   !(commute pd (pt-tp () 1 '((: b 9)) ()))                           ; deleted: erased edit
   !(commute pd (pt-tp () 1 '((: b 9)) '((: b 9) (: b 9))))           ; duplicated
   !(commute pd (pt-tp () 1 '((: b 9) (main (f x))) '((: b 2) (: b 9))))      ; pre state in news
   !(commute (pt-tp () 1 '((: b 2)) '((let x))) (pt-tp '(1) 1 '(x) '(y)))),      ; fresh content

  ; (L2) the rewritten pair are honest patches: each round-trips in context.
  (: c (commute pd qm) cq <c cp <>c
     t1 (apon t0 cq)
     (test
      (valid t0 cq) (valid t1 cp)
      (pt-heq (apon t1 (invert cq)) t0)
      (pt-heq (apon (apon t1 cp) (invert cp)) t1))),

  ; (L3b) a frontier is stable under the swallow swap, a bystander riding along.
  (: w (pt-tp '(0) 2 '(1) '(7))
     c (commute pd qm)
     f1 (applall t0 [w pd qm])
     f2 (applall t0 (w . c))
     (test (pt-heq f1 f2) (pt-heq f1 '((: a 7) (main (f x)) (: b 9))))),
  0))

; --- the clash-segments rung: the conflictor cell lifted to sequences ---
; state alone cannot delimit a first rival's footprint, so merge2 (both hunks in hand) makes the bubble
; and pull answers only what state can: plain, settled (non-empty news), join, breach no-op
; the bubble is one element (hull + rivals ordered by hval), so downstream seats stay fixed

(:
 ; --- the sequence kit (local) ---
 (valid s p) ((pt-hi p + #(pt-ho p)) <= #s
                 && pt-heq (pt-seg s (pt-hi p) #(pt-ho p)) (pt-ho p))
 (apon s p) (pt-splice s (pt-hi p) #(pt-ho p) (pt-hn p))
 (invert p) (pt-hunk (pt-hi p) (pt-hn p) (pt-ho p))
 (commute p q)
   (: i (pt-hi p) o1 #(pt-ho p) n1 #(pt-hn p)
      j (pt-hi q) o2 #(pt-ho q) n2 #(pt-hn q)
      (? (j > (i + n1)) [(pt-hunk ((j + o1) - n1) (pt-ho q) (pt-hn q)) p]
         ((j + o2) < i) [q (pt-hunk ((i + n2) - o2) (pt-ho p) (pt-hn p))]
         ()))

 ; --- the cell: hull base + rivals, canonically ordered by content hash ---
 (sins x rs) (atom? rs ? [x]        ; canonical insert --
                (<rs @ h            ; dedup by content,
                 (? (pt-heq x h) rs    ; order by its hash
                    (pt-hval x < pt-hval h) (x . rs)
                    (h . sins x >rs))))
 (has rs x) (atom? rs ? 0 (pt-heq <rs x || has >rs x))

 ; --- merge2: equal edits settle, commute re-aims an independent q, a refusal makes the bubble ---
 (merge2 s0 p q)
   (pt-heq p q ? (apon s0 p)
      (commute (invert p) q @ c
       (!(atom? c) ? (apon (apon s0 p) <c)
          (: lo (pt-hi q < pt-hi p ? (pt-hi q) (pt-hi p))           ; the union hull
             e1 (pt-hi p + #(pt-ho p)) e2 (pt-hi q + #(pt-ho q))
             hu (e1 < e2 ? e2 e1)
             base (pt-seg s0 lo (hu - lo))
             rp (pt-splice base (pt-hi p - lo) #(pt-ho p) (pt-hn p))
             rq (pt-splice base (pt-hi q - lo) #(pt-ho q) (pt-hn q))
             (pt-splice s0 lo (hu - lo)
                     [(pt-clash base (sins rp (sins rq ())))])))))

 ; --- pull: plain / settled / join / breach. a rival overlapping or touching a landed hull joins it,
 ;     widening the hull with the pads (padding commutes with rendering); any mismatch no-ops ---
 (findc s q k)          ; first cell whose
   (#s <= k ? ()        ; hull meets q's span
      (<(pt-hdrop s k) @ e
       (? (pt-clash? e
              && (pt-hi q <= (k + #(pt-cbase e))
                  && k <= (pt-hi q + #(pt-ho q)))) [k]
          (findc s q (k + 1)))))
 (pull s q)
   (: i (pt-hi q) o (pt-ho q) n (pt-hn q)
      (? (valid s q) (apon s q)                  ; plain
         (0 < #n && pt-heq (pt-seg s i #n) n) s        ; settled (non-empty)
         (findc s q 0 @ f
          (atom? f ? s                                      ; no cell: breach, no-op
             (: k <f e <(pt-hdrop s k) b (pt-cbase e)
                lo (i < k ? i k)                            ; the union hull
                eo (k + #b) eq (i + #o)
                hu (eo < eq ? eq eo)
                pl (pt-seg s lo (k - lo))                      ; the pads, off the state
                pr (pt-seg s (k + 1) (hu - eo))
                hull (pt-hcat pl (pt-hcat b pr))
                (!(pt-heq (pt-seg hull (i - lo) #o) o) ? s        ; dishonest: no-op
                   (: rs (foldl (a \ x \ sins (pt-hcat pl (pt-hcat x pr)) a) () (pt-rivals e))
                      rv (pt-splice hull (i - lo) #o n)
                      (pt-splice s (k - #pl) (#pl + (1 + #pr))
                              [(pt-clash hull (sins rv rs))]))))))))

 ; --- witnesses: one disputed span, rivals of three sizes, and a bystander ---
 s0 '(a b c d e)
 p (pt-hunk 2 '(c) '(p1 p2)) q (pt-hunk 2 '(c) '(q1)) r (pt-hunk 2 '(c) '(r1 r2 r3))
 w (pt-hunk 4 '(e) '(e9))

 ; (M1) merge is total and symmetric, independent or rival
 ((test
   (pt-heq (merge2 s0 p q) (merge2 s0 q p))
   (pt-heq (merge2 s0 p w) (merge2 s0 w p))
   (pt-heq (merge2 s0 p w) '(a b p1 p2 d e9))),

  ; (M2) the same edit settles, and a re-arriving rival is absorbed
  (test
   (pt-heq (merge2 s0 p p) (apon s0 p))
   (pt-heq (pull (apon s0 p) p) (apon s0 p))
   (merge2 s0 p q @ m (pt-heq (pull m p) m))),

  ; (M3) the conflict is honest, and the bubble keeps the sequence 5 long
  (: m (merge2 s0 p q) e <(pt-hdrop m 2)
     (test
      (5 = #m) (pt-clash? e)
      (pt-heq (pt-cbase e) '(c)) (2 = #(pt-rivals e))
      (has (pt-rivals e) '(p1 p2)) (has (pt-rivals e) '(q1))
      (pt-heq (pt-hdrop m 3) '(d e)))),

  ; (M4) three rivals, any order: one cell, one set
  (: m1 (pull (merge2 s0 p q) r)
     m2 (pull (merge2 s0 q r) p)
     m3 (pull (merge2 s0 r p) q)
     (test (pt-heq m1 m2) (pt-heq m2 m3)
             (3 = #(pt-rivals <(pt-hdrop m1 2))))),

  ; (M5) resolution is a hunk whose olds is the cell; invert returns the clash
  (: m (merge2 s0 p q) cell <(pt-hdrop m 2)
     res (pt-hunk 2 [cell] '(z9))
     m2 (pull m res)
     (test
      (pt-heq m2 '(a b z9 d e)) !(pt-clash? <(pt-hdrop m2 2))
      (pt-heq (pull m2 (invert res)) m))),

  ; two inserts on one seam: recorded as a cell with an empty base
  (: sp (pt-hunk 1 () '(u)) sq (pt-hunk 1 () '(v))
     m (merge2 s0 sp sq) e <(pt-hdrop m 1)
     (test
      (pt-heq m (merge2 s0 sq sp))
      (6 = #m) (pt-clash? e) (pt-heq (pt-cbase e) ())
      (has (pt-rivals e) '(u)) (has (pt-rivals e) '(v))
      (pt-heq (pt-hdrop m 2) '(b c d e)))),

  ; overlapping spans: each rival is the union hull with its hunk laid inside
  (: op (pt-hunk 1 '(b c) '(x)) oq (pt-hunk 2 '(c d) '(y z))
     m (merge2 s0 op oq) e <(pt-hdrop m 1)
     (test
      (pt-heq m (merge2 s0 oq op))
      (3 = #m) (pt-clash? e)
      (pt-heq (pt-cbase e) '(b c d))
      (has (pt-rivals e) '(x d)) (has (pt-rivals e) '(b y z))
      (pt-heq (pt-hdrop m 2) '(e)))),

  ; the boundary: a first rival by pull no-ops (merge2's job), a repeated deletion rests in breach,
  ;      a stray mismatch rides through
  (: dl (pt-hunk 3 '(d) ()) s1 (apon s0 dl)
     (test
      (pt-heq (pull (apon s0 p) q) (apon s0 p))
      (pt-heq (pull s1 dl) s1)
      (merge2 s0 p q @ m (pt-heq (pull m (pt-hunk 0 '(zz) '(ww))) m)))),

  ; the widening: three overlapping spans, any arrival order, one bubble over the union hull
  (: p2 (pt-hunk 1 '(b c) '(x)) q2 (pt-hunk 2 '(c d) '(y z)) r2 (pt-hunk 3 '(d e) '(w))
     m1 (pull (merge2 s0 p2 q2) r2)
     m2 (pull (merge2 s0 q2 r2) p2)
     m3 (pull (merge2 s0 r2 p2) q2)
     e <(pt-hdrop m1 1)
     (test
      (pt-heq m1 m2) (pt-heq m2 m3)
      (2 = #m1) (pt-clash? e)                                ; (a BUBBLE) -- length fixed
      (pt-heq (pt-cbase e) '(b c d e))
      (3 = #(pt-rivals e))
      (has (pt-rivals e) '(x d e)) (has (pt-rivals e) '(b y z e)) (has (pt-rivals e) '(b c w)))),

  ; a contained rival lays into the landed hull -- same lane, pads empty.
  (: op (pt-hunk 1 '(b c) '(x)) oq (pt-hunk 2 '(c d) '(y z))
     m (pull (merge2 s0 op oq) (pt-hunk 2 '(c) '(k1)))
     e <(pt-hdrop m 1)
     (test
      (3 = #(pt-rivals e))
      (has (pt-rivals e) '(b k1 d)))),

  ; resolution off the widened bubble stays ordinary -- and unpull returns it.
  (: p2 (pt-hunk 1 '(b c) '(x)) q2 (pt-hunk 2 '(c d) '(y z)) r2 (pt-hunk 3 '(d e) '(w))
     m (pull (merge2 s0 p2 q2) r2)
     cell <(pt-hdrop m 1)
     res (pt-hunk 1 [cell] '(z9))
     (test
      (pt-heq (pull m res) '(a z9))
      (pt-heq (pull (pull m res) (invert res)) m))),
  0))

; --- the metavariable rung: a patch carrying (mv v) cells is a rewrite rule ---
; valid matches olds one-sided (non-linear patterns bind consistently), apon lays news instantiated
; a rule is blind to its variable's binding, so a deep ground edit inside it commutes, re-aimed to the news seat;
; linearity is the guard: the variable exactly once on each side

(:
 ; --- the tree kit (local) ---
 (invert p) (pt-tp (pt-pp p) (pt-pi p) (pt-pn p) (pt-po p))

 ; --- the pattern kit: a (mv v) cell is a variable; ground content never spells one ---

 ; --- apply: match the olds, lay the news instantiated ---
 (valid t q) (pt-pathok t (pt-pp q)
                 && (pt-tnav t (pt-pp q) @ s
                     ((pt-pi q + #(pt-po q)) <= #s
                         && !((pt-mtch (pt-po q) (pt-seg s (pt-pi q) #(pt-po q)) ()) = 'no))))
 (apon t q) (: sq (pt-tnav t (pt-pp q))
               sg (pt-mtch (pt-po q) (pt-seg sq (pt-pi q) #(pt-po q)) ())
               (pt-tlay t (pt-pp q) (pt-splice sq (pt-pi q) #(pt-po q) (pt-inst (pt-pn q) sg))))
 (applall t ps) (foldl apon t ps)

 ; --- the variable's seats: count and address in a pattern segment ---
 (mvn f v) (atom? f ? 0
               (<f @ h
                ((? (atom? h) 0 (pt-mv? h && (pt-mvname h = v)) 1 (mvn h v))
                 + mvn >f v)))
 (mvat f v) (atom? f ? ()
                (<f @ h
                 (!(atom? h) && (pt-mv? h && (pt-mvname h = v)) ? '(0)
                    ((atom? h ? () (mvat h v)) @ r
                     (!(atom? r) ? (0 . r)
                        (mvat >f v @ d
                         (atom? d ? ()
                            ((<d + 1) . >d))))))))
 (alast a) (atom? >a ? <a (alast >a))
 (abut a) (atom? >a ? () (<a . abut >a))

 ; --- bind: descend the rule's olds along the deep path: ('in mv rest) inside the binding,
 ;     ('at pat) on a pattern sequence, 'no off the rigid structure ---
 (bind e R)
   (? (pt-mv? e) ['in e R]
      (atom? R) ['at e]
      (<R @ j
       (atom? e || #e <= j ? 'no
          (bind (pt-nth e j) >R))))

 ; --- mvswal: the rule rides unchanged, dp re-aims to the variable's news seat; nonlinear -> () ---
 (mvswal dp sp j d)
   (: S (pt-pp sp) is (pt-pi sp) O (pt-po sp) N (pt-pn sp)
      R (pt-hdrop (pt-pp dp) (d + 1)) off (j - is)
      b (bind (pt-nth O off) R)
      (? (atom? b) ()
         (<b = 'in)
           (: v (pt-mvname <>b) rest <>>b
              (!((1 = mvn O v) && (1 = mvn N v)) ? ()
                 (mvat N v @ an
                  (. sp (. (pt-tp (pt-hcat S ((is + <an) . pt-hcat >an rest))
                                     (pt-pi dp) (pt-po dp) (pt-pn dp)) ())))))
         (: pat <>b im (pt-pi dp)                                     ; the whole-binding swap:
            (? !((1 = #(pt-po dp)) && (1 = #(pt-pn dp))) ()              ; one for one,
               (#pat <= im) ()                                     ; exactly at the seat
               (pt-nth pat im @ m
                (atom? m || !(pt-mv? m) ? ()                ; rigid part: a real dependency
                   (pt-mvname m @ v
                    (!((1 = mvn O v) && (1 = mvn N v)) ? ()
                       (mvat N v @ an
                        (? (atom? >an)
                           [sp (pt-tp S (is + <an) (pt-po dp) (pt-pn dp))]
                           (. sp (. (pt-tp (pt-hcat S ((is + <an) . abut >an))
                                              (alast >an) (pt-po dp) (pt-pn dp)) ()))))))))))))

 ; --- commute: the tree lift's lanes with schematic swallow arms; a ground swallow refuses ---
 (commute p q)
   (: P (pt-pp p) ip (pt-pi p) o1 #(pt-po p) n1 #(pt-pn p)
      Q (pt-pp q) iq (pt-pi q) o2 #(pt-po q) n2 #(pt-pn q)
      r (pt-rel P Q 0) tag <r
      (? (tag = 'same)
           (? (iq > (ip + n1)) [(pt-tp Q ((iq + o1) - n1) (pt-po q) (pt-pn q)) p]
              ((iq + o2) < ip) [q (pt-tp P ((ip + n2) - o2) (pt-po p) (pt-pn p))]
              ())
         (tag = 'inq)
           (: j <>r d <>>r
              (? (j < ip) [q p]
                 (j >= (ip + n1))
                   [(pt-tp (pt-setidx Q d ((j + o1) - n1)) iq (pt-po q) (pt-pn q)) p]
                 (mvswal (invert q) (invert p) j d @ c
                  (atom? c ? ()
                     [(invert <>c) (invert <c)]))))
         (tag = 'inp)
           (: j <>r d <>>r
              (? (j < iq) [q p]
                 (j >= (iq + o2))
                   [q (pt-tp (pt-setidx P d ((j + n2) - o2)) ip (pt-po p) (pt-pn p))]
                 (mvswal p q j d)))
         [q p]))

 ; --- witnesses: the rule renames main -> run and moves the body (seat 1 -> 2) ---
 t0 '((: a 1) (: b 2) (main (f x)))
 q8 (pt-tp () 2 '((main (mv v))) '((run () (mv v))))
 p8 (pt-tp '(2 1) 0 '(f) '(g))

 ; (L1 + L3a) the rule commutes unchanged, the edit follows the seat (2 1 -> 2 2)
 ((: c (commute p8 q8) cq <c cp <>c
     (test
      (pt-heq cq q8)                                          ; the rule is blind: q' = q
      (pt-heq (pt-pp cp) '(2 2))                                 ; the seat re-aim
      (pt-heq (apon (apon t0 p8) q8) (apon (apon t0 cq) cp))
      (pt-heq (apon (apon t0 p8) q8) '((: a 1) (: b 2) (run () (g x))))
      (commute cq cp @ c2
       (pt-heq <c2 p8 && pt-heq <>c2 q8)))),

  ; the whole-binding swap re-seats the same way
  (: p9 (pt-tp '(2) 1 '((f x)) '((h y)))
     c (commute p9 q8) cq <c cp <>c
     (test
      (pt-heq cq q8)
      (pt-heq (pt-pp cp) '(2)) (2 = pt-pi cp)
      (pt-heq (apon (apon t0 p9) q8) (apon (apon t0 cq) cp))
      (pt-heq (apon (apon t0 p9) q8) '((: a 1) (: b 2) (run () (h y))))
      (commute cq cp @ c2
       (pt-heq <c2 p9 && pt-heq <>c2 q8)))),

  ; refusals: a rigid-part edit, a duplicating rule, an erasing rule, a span over rigid structure
  (test
   !(commute (pt-tp '(2) 0 '(main) '(go)) q8)
   !(commute p8 (pt-tp () 2 '((main (mv v))) '((run (mv v) (mv v)))))
   !(commute p8 (pt-tp () 2 '((main (mv v))) '((halt))))
   !(commute (pt-tp '(2) 0 '(main (f x)) '(go)) q8)),

  ; the unifier: a non-linear pattern binds consistently or not at all
  (: t1 '((pair 5 5) (pair 5 6))
     qc (pt-tp () 0 '((pair (mv w) (mv w))) '((mv w)))
     (test
      (valid t1 qc)
      !(valid t1 (pt-tp () 1 '((pair (mv w) (mv w))) '((mv w))))
      (pt-heq (apon t1 qc) '(5 (pair 5 6))))),

  ; (L2) a variable-preserving rule round-trips through its inverse
  (apon t0 q8 @ t2
   (test
    (valid t0 q8) (valid t2 (invert q8))
    (pt-heq (apon t2 (invert q8)) t0))),

  ; (L3b) a frontier is stable under the schematic swallow swap.
  (: w (pt-tp '(0) 2 '(1) '(7))
     c (commute p8 q8)
     f1 (applall t0 [w p8 q8])
     f2 (applall t0 (w . c))
     (test (pt-heq f1 f2) (pt-heq f1 '((: a 7) (: b 2) (run () (g x)))))),
  0))

; --- the critical-pairs rung: two rules meet on one tree ---
; a rule is (olds news) at a seat; diverging seats are order-free with no re-aim,
; overlapping seats can both land and disagree, so a refusal is earned

(:
 ; --- the tree + pattern kit (trimmed, local) ---

 ; --- a rule at a seat: rw answers (tree) or (), rw2 sequences two ---
 (rw R path t)
   (: sub (pt-tnav t path)
      sg (pt-mtch <R sub ())
      (sg = 'no ? ()
         [(pt-tlay t path (pt-inst <>R sg))]))
 (rw2 Ra pa Rb pb t) (rw Ra pa t @ r (atom? r ? () (rw Rb pb <r)))

 t0 '((f 1) ((g 2) (h 3)))
 Ra '((f (mv x)) (f ((mv x) (mv x))))     ; duplicate under f
 Rb '((h (mv y)) (k (mv y)))

 ; (L3a at rule grain) diverging seats are order-free, addresses unshifted
 ((: c1 (rw2 Ra '(0) Rb '(1 1) t0) c2 (rw2 Rb '(1 1) Ra '(0) t0)
     (test
      !(atom? c1) (pt-heq <c1 <c2)
      (pt-heq <c1 '((f (1 1)) ((g 2) (k 3)))))),
  (: p9 '((g (mv u)) (g ((mv u)))) q9 '((h (mv v)) (h))
     c1 (rw2 p9 '(1 0) q9 '(1 1) t0) c2 (rw2 q9 '(1 1) p9 '(1 0) t0)
     (test !(atom? c1) (pt-heq <c1 <c2))),

  ; the critical pair: one seat, two rules, both land and disagree
  (: R1 '((mv z) (a)) R2 '((mv z) (b))
     c1 (rw2 R1 () R2 () t0) c2 (rw2 R2 () R1 () t0)
     (test
      !(atom? c1) !(atom? c2)
      !(pt-heq <c1 <c2)
      (pt-heq <c1 '(b)) (pt-heq <c2 '(a)))),

  ; nested seats: the order decides which rule survives
  (: Rc '((g (mv u)) (k 5)) Rd '((g (mv w)) (g 9))
     (test
      !(atom? (rw2 Rd '(1 0) Rc '(1 0) t0))       ; d then c: c still sees a g
      (atom? (rw2 Rc '(1 0) Rd '(1 0) t0)))),     ; c then d: the g is gone
  0))
