; test/patch.l -- the patch groupoid, the executable spec the patch stack drifts against:
; a distribution, a namespace and a repo-state are one algebra of selectable sets, with
; commute underneath. test/uupatch.l is the uu twin, same model name for name (proved
; axiom-free via uu2coq/uu2lean: test_uugen, test_uulean); test/proof/rocq/patch.v
; scaffolds the slices still settling (test_proof).
;
; the named-slot model: a tree is a (key . value) assoc, a patch a single slot-change
; carrying its context (old -> new, not a bare diff), commute the partial swap.
;   L1  commute is involutive              L3a commute is sound: independent
;   L2  inverse round-trips (in context)       patches are order-free
;                                          L3b a frontier is stable under an
;                                              adjacent swap of independent patches
; the corpus is one scope: shared helpers carry pt-, the rest stay local to their block.

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
 (chg k a b) ('chg . k . a . b . 0)       ; patch: change slot k, old->new
 (valid t p) (pt-tget t (pt-pk p) = pt-pa p)              ; a patch belongs iff its context matches
 (apon t p) (pt-tset t (pt-pk p) (pt-pb p))               ; lay the patch's new value
 (applall t ps) (foldl apon t ps)                ; fold a whole frontier onto a tree
 (invert p) (chg (pt-pk p) (pt-pb p) (pt-pa p))           ; the groupoid inverse (unpull)
 (commute p q) (pt-pk p = pt-pk q ? 0 (q . p . 0))     ; partial: 0 = a dependency

 ; --- tree agreement at a witness key set (trees are maps: pointwise, as the .v does) ---
 (teq a b ks) (atom? ks ? 1 ((pt-tget a <ks = pt-tget b <ks) && teq a b >ks))

 ; --- witnesses ---
 px (chg 'x 0 1) py (chg 'y 0 2)                          ; independent -- different slots
 p1 (chg 'x 0 1) p2 (chg 'x 1 2)                          ; dependent -- same slot

 ; (L1) commute is involutive: swap two independent patches, swap the result back,
 ;      and you are home. same-slot patches don'T commute -- 0, a dependency.
 ((test
   (pt-heq (commute px py) (py . px . 0))                          ; p;q -> q;p
   (commute px py @ c (pt-heq (commute <c <>c)
                           (px . py . 0)))                      ; ...and back to p;q
   !(commute p1 p2)                                                  ; same slot -> no commute
   (pt-heq p1 p1) !(pt-heq px py)),                                        ; leq itself is honest

  ; (L2) inverse round-trips in context: where the patch is valid, apply then unpull
  ;      (apply the inverse) restores every slot; invert is its own inverse.
  (: t0 (pt-tset 0 'x 5) p (chg 'x 5 9)
     (test
      (valid t0 p)                                                   ; p belongs on t0
      (apon (apon t0 p) (invert p) @ t1 (teq t1 t0 '(x y)))          ; apply;unpull == id
      (pt-heq p (invert (invert p))))),                                 ; invert involutive

  ; (L3a) independent patches are order-free (the semantic heart -- what makes merge
  ;       and cherry-pick sound): both pull orders land the same tree.
  (: a (apon (apon 0 px) py) b (apon (apon 0 py) px)
     (test (teq a b '(x y)) (1 = pt-tget a 'x) (2 = pt-tget a 'y))),

  ; (L3b) a frontier is stable under swapping two adjacent independent patches -- the
  ;       reproducibility tie: meaning is order-free, so the (unordered) patch set is
  ;       a sound version identity. and the distribution face: two disjoint components
  ;       install to the same frontier whichever is pulled first.
  (: pre (chg 'a 0 7 . 0) post (chg 'b 0 8 . 0)
     f1 (applall 0 (pt-hcat pre (px . py . post)))                ; pre ++ [px py] ++ post
     f2 (applall 0 (pt-hcat pre (py . px . post)))                ; ...px,py swapped
     ((test (teq f1 f2 '(a b x y))),
      (: holo (chg 'holo 0 1 . 0) glaze (chg 'glaze 0 1 . 0)
         (test (teq (applall 0 (pt-hcat holo glaze))
                      (applall 0 (pt-hcat glaze holo)) '(holo glaze)))))),
  0))

; --- the positional rung: hunks over a sequence, where commute genuinely re-aims ---
;
; a file is a sequence of forms, a patch a hunk -- (hunk i olds news): at index i the
; segment olds (its context: a hunk belongs somewhere) becomes news. named slots never
; shift; hunks do -- commuting past an unequal-length hunk moves the other's index by
; the length delta, so the swapped q is a genuine re-aim. the same four laws, with two
; new teeth: touching hunks refuse to commute (two inserts on one seam have no
; canonical order), and valid carries a bound -- an out-of-range insert still splices
; at the end, but its inverse aims past the end, so the bound keeps L2 honest. the uu
; twin is test/uupatch.l's positional slice.

(:
 ; --- the model: sequences and hunks ---
 (valid s p) ((pt-hi p + #(pt-ho p)) <= #s                ; in range -- the round-trip bound
                 && pt-heq (pt-seg s (pt-hi p) #(pt-ho p)) (pt-ho p))
 (apon s p) (pt-splice s (pt-hi p) #(pt-ho p) (pt-hn p))
 (applall s ps) (foldl apon s ps)
 (invert p) (pt-hunk (pt-hi p) (pt-hn p) (pt-ho p))

 ; --- commute: the re-aim. p;q -> q';p'. q strictly past p's news shifts back by
 ;     p's delta (j + |o1| - |n1|); q strictly before shifts p forward by q's
 ;     delta. overlap or touch answers () -- a dependency. ---
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

 ; (L1) commute is involutive -- and the swap is a genuine re-aim: q comes back
 ;      at 3 (its pre-p seat), p rides unmoved, and swapping again is home.
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

  ; (L2) inverse round-trips in context -- and valid's bound has teeth: the
  ;      out-of-range insert is exactly the hunk whose round-trip would lie.
  (test
   (valid s0 p)
   (pt-heq (apon (apon s0 p) (invert p)) s0)
   (pt-heq p (invert (invert p)))
   !(valid '(a) (pt-hunk 5 () '(u)))),                       ; past the end: no home

  ; (L3a) commute is sound: p;q and q';p' land the same sequence -- while q
  ;       un-shifted does not even belong on s0 (the point of the re-aim).
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

  ; the elements are forms, not lines -- the love-native grain: a hunk swaps a whole
  ; definition and nothing above cares what an element is.
  (: fs '((f a) (g b) (main ()))
     fp (pt-hunk 1 '((g b)) '((g c) (h d)))
     (test (valid fs fp)
             (pt-heq (apon fs fp) '((f a) (g c) (h d) (main ()))))),

  ; (L3b) a frontier is stable under the adjacent independent swap -- the
  ;       reproducibility tie again, now with real shifting inside the list.
  (: c (commute p q)
     f1 (applall s0 [(pt-hunk 0 '(a) '(aa)) p q])
     f2 (applall s0 (pt-hunk 0 '(a) '(aa) . c))
     (test (pt-heq f1 f2) (pt-heq f1 '(aa x y c z e)))),
  0))

; --- the conflictor rung: a real merge records, and the state enlarges ---
;
; commute refuses a dependency; merge may not. the sound move is to enlarge the state
; until merge is total: a conflicted slot holds a clash cell -- the shared base plus a
; canonically-ordered set of rivals -- so merge is symmetric and associative by
; construction, neither side silently wins, and resolution needs no new machinery. a
; clash cell is a first-class value, so resolving is an ordinary chg whose old value is
; the cell, invertible like any patch. `pull` is merge machinery, not honest
; application: it trusts the co-valid discipline, while `valid` stays the gate for a
; lone patch. rivals here are charms, so < is the canon; a general value order arrives
; with the clash-segments rung.

(:
 ; --- the model: rung 1's trees and patches, plus the clash cell ---
 (chg k a b) ['chg k a b]
 (invert p) (chg (pt-pk p) (pt-pb p) (pt-pa p))
 (teq a b ks) (atom? ks ? 1 (pt-heq (pt-tget a <ks) (pt-tget b <ks)
                                && teq a b >ks))

 ; --- pull: total merge-application. five lanes; the last is the discipline
 ;     backstop (a cell-shaped mismatch no-ops rather than inventing a story). ---
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
 t0 (pt-tset 0 'x 1)
 p (chg 'x 1 2) q (chg 'x 1 3) r (chg 'x 1 4)
 w (chg 'y 0 9)

 ; (M1) merge is total and symmetric: rivals or bystanders, both pull orders
 ;      land the same tree -- the pushout apex, unique.
 ((test
   (teq (pull (pull t0 p) q) (pull (pull t0 q) p) '(x y))
   (teq (pull (pull t0 p) w) (pull (pull t0 w) p) '(x y))),

  ; (M2) the plain lane is rung 1: a matching context applies as ever, and the
  ;      same edit arriving twice settles (idempotent).
  (test
   (2 = pt-tget (pull t0 p) 'x)
   (teq (pull (pull t0 p) p) (pull t0 p) '(x y))),

  ; (M3) a conflict is honest: the slot carries the base and both rivals,
  ;      canonically ordered -- neither side silently won.
  (: m (pull (pull t0 q) p) c (pt-tget m 'x)
     (test (pt-clash? c) (1 = pt-cbase c) (pt-heq (pt-rivals c) '(2 3)))),

  ; (M4) three rivals, any order: one cell, one set -- the associativity that
  ;      broke classic darcs, answered by a set instead of patch algebra.
  (: m1 (pull (pull (pull t0 p) q) r)
     m2 (pull (pull (pull t0 r) q) p)
     m3 (pull (pull (pull t0 q) r) p)
     (test (teq m1 m2 '(x)) (teq m2 m3 '(x))
             (pt-heq (pt-rivals (pt-tget m1 'x)) '(2 3 4)))),

  ; (M5) resolution is just a patch: old value = the cell, new = the choice --
  ;      the plain lane applies it, invert unpulls it and the clash returns.
  (: m (pull (pull t0 p) q) cell (pt-tget m 'x)
     res (chg 'x cell 5)
     m2 (pull m res)
     (test
      (5 = pt-tget m2 'x) !(pt-clash? (pt-tget m2 'x))
      (teq (pull m2 (invert res)) m '(x y)))),

  ; and the distribution face: two components pinning one name differently
  ;      install to the same recorded clash whichever is pulled first.
  (: holo [(chg 'font 0 1)] glaze [(chg 'font 0 2)]
     fa (applall 0 (pt-hcat holo glaze))
     fb (applall 0 (pt-hcat glaze holo))
     (test (teq fa fb '(font)) (pt-clash? (pt-tget fa 'font)))),
  0))

; --- the identity rung: a version is its patch set, hashed canonically ---
;
; L3b/M4 proved a frontier's meaning is order-free and M2 that multiplicity is dead, so
; an identity quotienting by exactly order and repetition forgets nothing the semantics
; keeps. dependent patches carry their order in their contexts -- a frontier is a
; downward-closed set, replay order derived -- so the set identity is the right grain
; even when patches chain. the shape: hash each patch's printed form (show is the
; canonical serialization), fold through cins -- the same canonical set that carries a
; clash's rivals, so order-freedom is cins-commutativity and dup-freedom is
; cins-absorption -- then hash the canonical list once for the scalar name.
; collision-freedom is engineering (djb2 here); the laws live on the canonical list.

(:
 (fid ps) (foldl (acc \ p \ pt-cins (pt-hval p) acc) () ps)      ; the canonical hash set
 (ident ps) (pt-hval (fid ps))                                 ; one scalar to name it
 (chg k a b) ['chg k a b]

 ; --- witnesses ---
 p (chg 'x 1 2) q (chg 'x 1 3) w (chg 'y 0 9)

 ; (H1) order-free: any pull order, one identity -- the M4 face, on the name.
 ((test
   (ident [p q w] = ident [w q p])
   (ident [p w] = ident [w p])),

  ; (H2) multiplicity-free: pulling twice settles (M2), and the name agrees.
  (test (ident [p p q] = ident [p q])),

  ; (H3) content-sensitive: touch any patch and the name moves -- including
  ;      direction (a patch and its inverse are different content).
  (test
   !(ident [p] = ident [q])
   !(ident [p q] = ident [p w])
   !(ident [p] = ident [(chg 'x 2 1)])),
  0))

; --- the tree lift rung: a hunk gets a path, and the shift climbs the levels ---
;
; a file is a tree of forms, a patch a hunk with a postcode -- the path to the sequence
; it splices. the load-bearing fact: a deep patch never changes the length of any
; ancestor sequence, so only same-sequence patches shift each other's indices -- but a
; shallow splice moves whole subtrees, so it re-aims a deeper patch's path component at
; the crossing level. commute gets four lanes by path relation:
;   same    the two hunks share a sequence -- rung 2 verbatim, paths ride
;   inq     q is deeper, crossing p's sequence at child j: j past p's news slides back
;           by p's delta; j inside p's news is a dependency
;   inp     p is deeper, crossing q's sequence at child j: j past q's olds slides
;           forward by q's delta; j inside q's olds is a dependency -- q swallows p's
;           subtree, the door the content-rewrite rung opens
;   apart   the paths diverge: disjoint subtrees, both ride untouched
; strictness at the crossing differs from rung 2's seam on purpose: a path component
; >= the splice's far edge names a survivor, not a seam position, so there is no
; insert-order ambiguity to refuse and >= is sound where the seam needed >.

(:
 ; --- the sequence kit (rung 2, local) ---

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

 ; --- commute: four lanes, two kinds of re-aim (index at 'same, PATH at the
 ;     crossings), () a dependency ---
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

 ; (L1) commute is involutive, and the re-aim is a PATH re-aim: qd's postcode
 ;      slides 3 -> 2 (its pre-pr seat), and swapping back is home.
 ((: c (commute pr qd) cq <c cp <>c
     (test
      (pt-heq (pt-pp qd) '(3)) (pt-heq (pt-pp cq) '(2))                ; the path moved
      (pt-heq cp pr)
      (commute cq cp @ c2
       (pt-heq <c2 pr && pt-heq <>c2 qd)))),

  ; dependencies: a deep edit inside freshly-written news, and the swallow
  ;      (q replaces the subtree p edited -- shut HERE; form six opens it)
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

  ; (L3a) commute is sound across levels: root insert then deep edit == re-aimed
  ;       deep edit then root insert -- and the un-shifted qd has no home on t0.
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

  ; same sequence at depth: rung 2's shift verbatim, riding a postcode
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

; --- the content-rewrite rung: the swallow commutes -- context rewrites through ---
;
; the door the tree lift shut by fiat: a shallow patch whose olds swallow the subtree a
; deep patch edited, and the mirror. the dependency was never real when the shallow
; patch moves the content: undo the deep edit inside the shallow context -- both olds
; and news carry it -- and re-aim the deep patch at the content's new seat. the
; machinery is matching: find where the edited subtree survives on the far side. the
; unit walk descends the deep path until a subtree of the swallowed element occurs over
; there, so a wrap or an unwrap commutes too, and four occurrence guards keep the match
; canonical: the unit exactly once on each side in its post state, never in its pre
; state. ambiguity refuses -- a deleted subtree is a real dependency, a duplicate has no
; single home, and a news already carrying the pre state could not tell undo from
; content. the mirror lane rides the groupoid itself: p;q = (q^-1;p^-1)^-1 and
; q^-1;p^-1 is deep-first, so one rewrite core (swal) serves both directions, and
; involution comes from the algebra rather than a second implementation. patch.v proves
; the swal involution at element grain; the full rose-tree laws are asserted here and
; queued for their uu migration.

(:
 ; --- the tree kit (rung 5, local) ---
 (apon t p) (pt-tlay t (pt-pp p) (pt-splice (pt-tnav t (pt-pp p)) (pt-pi p) #(pt-po p) (pt-pn p)))
 (applall t ps) (foldl apon t ps)
 (invert p) (pt-tp (pt-pp p) (pt-pi p) (pt-pn p) (pt-po p))
 (valid t p) (pt-pathok t (pt-pp p)
                 && (pt-tnav t (pt-pp p) @ s
                     ((pt-pi p + #(pt-po p)) <= #s
                         && pt-heq (pt-seg s (pt-pi p) #(pt-po p)) (pt-po p))))

 ; --- the matching kit: a subtree's occurrences, counted and found at every
 ;     depth (occs and ffind descend the same way -- their agreement is what
 ;     makes the ==1 guard name ffind's answer) ---
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
 ; the unit walk: the shallowest prefix of the deep path whose subtree of the
 ; swallowed element survives into the far side -- (k), or () when nothing
 ; survives (erasure: the honest dependency)
 (sunit el R n2 k)
   (? !(pt-pathok el (pt-htake R k)) ()
      (0 < occs n2 (pt-tnav el (pt-htake R k))) [k]
      (#R <= k) ()
      (sunit el R n2 (k + 1)))

 ; --- swal: the deep-first swallow commute. dp ran first, so sp's olds carry
 ;     its effect (element off, unit at Rk below); undo dp inside the unit
 ;     (bak, dp's inverse below the crossing -- valid keeps the context
 ;     honest), lay the pre state into both of sp's sides, and re-aim dp at
 ;     the survivor's seat in the news. the guards make the match canonical;
 ;     any miss answers () -- declining is always sound. ---
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

 ; --- commute: rung 5's four lanes, the two swallow refusals now doors --
 ;     inp calls swal straight (p IS deep-first), inq flips through the
 ;     groupoid inverse and back ---
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

 ; --- witnesses: the same little program; pd edits deep, qm moves the edited
 ;     form (its context aimed post-pd, as a second branch would record it) ---
 t0 '((: a 1) (: b 2) (main (f x)))
 pd (pt-tp '(1) 2 '(2) '(9))                                  ; deep: (: b 2) -> (: b 9)
 qm (pt-tp () 1 '((: b 9) (main (f x))) '((main (f x)) (: b 9)))

 ; (L1) the swallow commutes: qm's context rewrites through (both sides read
 ;      (: b 2) now -- the pre state), the deep edit re-aims to the moved
 ;      seat (path 1 -> 2), and swapping back is home.
 ((: c (commute pd qm) cq <c cp <>c
     (test
      (pt-heq (pt-pp cp) '(2))                                   ; the survivor's new seat
      (pt-heq (pt-po cq) '((: b 2) (main (f x))))                ; undo laid into olds
      (pt-heq (pt-pn cq) '((main (f x)) (: b 2)))                ; ...and into news
      (commute cq cp @ c2
       (pt-heq <c2 pd && pt-heq <>c2 qm)))),

  ; (L3a) sound across the rewrite: both orders land the same tree -- while the
  ;       un-rewritten qm has no home on t0 (its olds still carry the edit).
  (: c (commute pd qm) cq <c cp <>c
     (test
      (pt-heq (apon (apon t0 pd) qm) (apon (apon t0 cq) cp))
      (pt-heq (apon (apon t0 pd) qm) '((: a 1) (main (f x)) (: b 9)))
      !(valid t0 qm))),

  ; the wrap: the survivor sits at depth in the news (the unit walk descends),
  ;      so the re-aimed path grows a component (1 -> 1 1) -- and back is home,
  ;      the unwrap direction shedding it again.
  (: qw (pt-tp () 1 '((: b 9)) '((guard (: b 9))))
     c (commute pd qw) cq <c cp <>c
     (test
      (pt-heq (pt-pp cp) '(1 1))
      (pt-heq (pt-pn cq) '((guard (: b 2))))
      (pt-heq (apon (apon t0 pd) qw) (apon (apon t0 cq) cp))
      (commute cq cp @ c2
       (pt-heq <c2 pd && pt-heq <>c2 qw)))),

  ; the mirror lane (the groupoid ride): the move lands first, the deep edit
  ;      aims into its news -- commute re-aims the edit to the pre-move seat
  ;      (path 2 -> 1) and advances the move's both sides to the edited content.
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

  ; the refusals keep the door honest: erasure is a real dependency, a
  ;      duplicate has no single home, a news already carrying the pre state
  ;      cannot tell undo from content, and content the shallow patch wrote
  ;      fresh was never anywhere else to move from.
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
;
; rung 3 recorded rivals at named slots; here they rival over spans -- pijul's
; graggle corner, taken through our habit. the load-bearing fact this rung
; must respect: state alone cannot delimit a first rival's footprint (a landed
; hunk left news of unknown length -- the extent problem, the reason pijul
; carries provenance). so the machinery splits honestly in two:
;   merge2   the pushout of two co-valid hunks off the shared base -- both
;            patches in hand, so every footprint is known. independent hunks
;            ride commute (the darcs ride: invert one, commute the other
;            past it); a refusal -- overlap, touch, or the classic two
;            inserts on one seam -- collapses the union hull of the two base
;            spans to one element, the bubble: a clash cell holding the hull
;            segment and each rival as the hull with its hunk laid inside.
;   pull     state-only, for what state can answer: the plain lane (rung 2
;            verbatim), the settled lane (the news already in, gated to
;            non-empty news -- an empty segment is vacuously "present"), the
;            join lane (a landed cell absorbs a same-span rival), and the
;            breach backstop (no-op rather than invent a story).
; the bubble fixes the length: rivals of any sizes occupy one seat, so every
; downstream seat is determinate before anyone resolves -- the graggle's
; bubble, collapsed to one first-class element. rivals are segments now,
; ordered by content hash (hval, the canon rung 3 deferred to "a general
; value order"; collision is engineering, as with the frontier identity).
; a resolution is an ordinary hunk whose olds is the one-element cell
; segment -- invertible, unpull returns the clash. the seam refusal that
; rung 2 closed by fiat is answered here: recorded as a cell with an empty
; base. and the join lane widens: a rival extending past a landed bubble
; re-derives the cell over the union hull, the pads riding in from beside
; the seat -- padding commutes with rendering, so mixed-span rivals land
; the same bubble in any arrival order.

(:
 ; --- the sequence kit (rung 2, local) ---
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

 ; --- merge2: the pushout off the shared base. equal edits settle; commute
 ;     re-aims an independent q past p; a refusal makes the bubble ---
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

 ; --- pull: plain / settled / the widening join / breach -- what state can
 ;     answer. the join lane is general: any rival whose base span overlaps
 ;     (or touches -- the seam law is strict everywhere) a landed cell's hull
 ;     joins it. a same-span rival rides as before, a contained one lays into
 ;     the hull, an extending one widens the bubble: the hull grows to the
 ;     union, the pads (base content beside the cell -- seats 1:1 by the
 ;     co-valid discipline) re-render every rival over the wider hull.
 ;     padding commutes with rendering (patch.v splice_pad), so a rival
 ;     padded up equals the rival rendered over the wide hull directly --
 ;     arrival order stays dead at mixed spans. the honest guard reads the
 ;     rebuilt hull; any mismatch no-ops. ---
 (findc s q k)          ; first cell whose
   (#s <= k ? ()        ; hull meets q's span
      (<(pt-hdrop s k) @ e
       (? (pt-clash? e
              && (pt-hi q <= (k + #(pt-cbase e))
                  && k <= (pt-hi q + #(pt-ho q)))) [k]
          (findc s q (k + 1)))))
 (pull s q)
   (: i (pt-hi q) o (pt-ho q) n (pt-hn q)
      (? (valid s q) (apon s q)                  ; plain: rung 2
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

 ; --- witnesses: one disputed span, rivals of three different sizes (the
 ;     segment teeth), and an independent bystander ---
 s0 '(a b c d e)
 p (pt-hunk 2 '(c) '(p1 p2)) q (pt-hunk 2 '(c) '(q1)) r (pt-hunk 2 '(c) '(r1 r2 r3))
 w (pt-hunk 4 '(e) '(e9))

 ; (M1) merge is total and symmetric: rivals or bystanders, either order --
 ;      the independent lane riding commute, the rival lane riding the set.
 ((test
   (pt-heq (merge2 s0 p q) (merge2 s0 q p))
   (pt-heq (merge2 s0 p w) (merge2 s0 w p))
   (pt-heq (merge2 s0 p w) '(a b p1 p2 d e9))),

  ; (M2) the same edit settles: merged with itself is a plain apply, pulled
  ;      again it is already in, and a rival re-arriving is absorbed.
  (test
   (pt-heq (merge2 s0 p p) (apon s0 p))
   (pt-heq (pull (apon s0 p) p) (apon s0 p))
   (merge2 s0 p q @ m (pt-heq (pull m p) m))),

  ; (M3) the conflict is honest, and the bubble fixes the length: rivals of
  ;      sizes 2 and 1 over a span of 1, and the sequence stays 5 long --
  ;      every downstream seat determinate before anyone resolves.
  (: m (merge2 s0 p q) e <(pt-hdrop m 2)
     (test
      (5 = #m) (pt-clash? e)
      (pt-heq (pt-cbase e) '(c)) (2 = #(pt-rivals e))
      (has (pt-rivals e) '(p1 p2)) (has (pt-rivals e) '(q1))
      (pt-heq (pt-hdrop m 3) '(d e)))),

  ; (M4) three rivals, any order: one cell, one set -- pull's join lane
  ;      absorbing whichever arrives last.
  (: m1 (pull (merge2 s0 p q) r)
     m2 (pull (merge2 s0 q r) p)
     m3 (pull (merge2 s0 r p) q)
     (test (pt-heq m1 m2) (pt-heq m2 m3)
             (3 = #(pt-rivals <(pt-hdrop m1 2))))),

  ; (M5) resolution is just a hunk: olds = the one-element cell segment --
  ;      the plain lane applies it, invert unpulls it and the clash returns.
  (: m (merge2 s0 p q) cell <(pt-hdrop m 2)
     res (pt-hunk 2 [cell] '(z9))
     m2 (pull m res)
     (test
      (pt-heq m2 '(a b z9 d e)) !(pt-clash? <(pt-hdrop m2 2))
      (pt-heq (pull m2 (invert res)) m))),

  ; the seam answered: two inserts on one seam -- rung 2 refused by fiat;
  ;      here the ambiguity is recorded, a cell with an empty base.
  (: sp (pt-hunk 1 () '(u)) sq (pt-hunk 1 () '(v))
     m (merge2 s0 sp sq) e <(pt-hdrop m 1)
     (test
      (pt-heq m (merge2 s0 sq sp))
      (6 = #m) (pt-clash? e) (pt-heq (pt-cbase e) ())
      (has (pt-rivals e) '(u)) (has (pt-rivals e) '(v))
      (pt-heq (pt-hdrop m 2) '(b c d e)))),

  ; overlapping spans: the union hull is the base, each rival the hull with
  ;      its hunk laid inside -- and downstream rides at a determinate seat.
  (: op (pt-hunk 1 '(b c) '(x)) oq (pt-hunk 2 '(c d) '(y z))
     m (merge2 s0 op oq) e <(pt-hdrop m 1)
     (test
      (pt-heq m (merge2 s0 oq op))
      (3 = #m) (pt-clash? e)
      (pt-heq (pt-cbase e) '(b c d))
      (has (pt-rivals e) '(x d)) (has (pt-rivals e) '(b y z))
      (pt-heq (pt-hdrop m 2) '(e)))),

  ; the boundary, honest: a first rival arriving by pull no-ops (state cannot
  ;      delimit its footprint -- the extent problem; the first clash needs
  ;      merge2, both patches in hand), a deletion arriving twice rests in the
  ;      breach lane, and a mismatch that is neither settled nor a join rides
  ;      through untouched.
  (: dl (pt-hunk 3 '(d) ()) s1 (apon s0 dl)
     (test
      (pt-heq (pull (apon s0 p) q) (apon s0 p))
      (pt-heq (pull s1 dl) s1)
      (merge2 s0 p q @ m (pt-heq (pull m (pt-hunk 0 '(zz) '(ww))) m)))),

  ; the widening: three rivals over three different overlapping spans (the
  ;      middle one bridging, the outer two merely touching) -- whichever pair
  ;      bubbles first, the third widens the cell to the union hull and every
  ;      rival re-renders over it: one bubble, one set, any arrival order.
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

; --- the metavariable rung: patches grow variables, the unifier takes the seat ---
;
; the door the content-rewrite rung framed, opened: a patch's segments may
; carry metavariables ((mv v) cells), so a patch is now a rewrite rule. the
; unifier enters at application: valid matches olds against the tree (one-
; sided unification -- a substitution threads through, and a non-linear
; pattern binds consistently or not at all, the kanren move), apon lays the
; news instantiated. a ground patch is the variable-free special case (match
; degenerates to heq, instantiate to the identity), so this model subsumes
; the tree lift's whole.
;
; and the swallow commute transforms: a schematic shallow patch is blind to
; the content its variable binds, so a deep ground edit inside the binding
; commutes with the rule unchanged -- form six rewrote the context through
; the content; the variable abstracted the content away, and what remains is
; pure address algebra. `bind` descends the rule's olds pattern along the
; deep path: entering the variable's seat names the binder (the edit rides
; inside the binding); landing beside it with a one-for-one swap replaces
; the binding whole; hitting the rigid part refuses -- the rule's context
; genuinely mentions that content. the deep patch re-aims from the
; variable's olds seat to its news seat (mvat), and form six's occurrence
; guards become structural: the variable exactly once on each side, read
; off the rule itself -- a duplicating rule would need the edit twice, an
; erasing rule would lose it, both honest dependencies. the mirror rides
; the groupoid inverse as ever, one core. patch.v proves the two halves at
; their grains: matching is sound (a pattern instantiated with its own
; bindings reproduces the ground term -- mtch_sound) and the seat re-aim is
; involutive (reaim_involutive). the schematic-vs-schematic door opens in
; form nine below -- the critical-pairs rung.

(:
 ; --- the tree kit (rung 5, local) ---
 (invert p) (pt-tp (pt-pp p) (pt-pi p) (pt-pn p) (pt-po p))

 ; --- the pattern kit: metavariables, match, instantiate. a (mv v) cell is
 ;     a variable (data by discipline: ground content never spells one) ---

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

 ; --- bind: descend the rule's olds along the deep path. answers ('in mv
 ;     rest) -- the edit rides inside the binding, rest below the seat;
 ;     ('at pat) -- the path landed on a pattern sequence (the whole-binding
 ;     swap checks there); 'no -- fell off the rigid structure ---
 (bind e R)
   (? (pt-mv? e) ['in e R]
      (atom? R) ['at e]
      (<R @ j
       (atom? e || #e <= j ? 'no
          (bind (pt-nth e j) >R))))

 ; --- mvswal: the schematic swallow. the rule rides unchanged (its variable
 ;     abstracts the content); the deep patch re-aims from the variable's
 ;     olds seat to its news seat. linearity is the guard: the variable
 ;     exactly once on each side, or the dependency is real. ---
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

 ; --- commute: the tree lift's lanes, the swallow arms schematic; a ground
 ;     swallow refuses here (form six owns the ground rewrite; a real vcs
 ;     composes both) ---
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

 ; --- witnesses: the rule renames main -> run and moves the body (the
 ;     variable's seat slides from child 1 to child 2); the deep edit rides ---
 t0 '((: a 1) (: b 2) (main (f x)))
 q8 (pt-tp () 2 '((main (mv v))) '((run () (mv v))))
 p8 (pt-tp '(2 1) 0 '(f) '(g))

 ; (L1 + L3a) the edit rides inside the binding: the rule commutes unchanged,
 ;      the deep path follows the seat (2 1 -> 2 2), both orders land the
 ;      same tree, and swapping back is home.
 ((: c (commute p8 q8) cq <c cp <>c
     (test
      (pt-heq cq q8)                                          ; the rule is blind: q' = q
      (pt-heq (pt-pp cp) '(2 2))                                 ; the seat re-aim
      (pt-heq (apon (apon t0 p8) q8) (apon (apon t0 cq) cp))
      (pt-heq (apon (apon t0 p8) q8) '((: a 1) (: b 2) (run () (g x))))
      (commute cq cp @ c2
       (pt-heq <c2 p8 && pt-heq <>c2 q8)))),

  ; the whole-binding swap: a one-for-one replacement at the variable's seat
  ;      re-seats the same way (path 2 index 1 -> path 2 index 2).
  (: p9 (pt-tp '(2) 1 '((f x)) '((h y)))
     c (commute p9 q8) cq <c cp <>c
     (test
      (pt-heq cq q8)
      (pt-heq (pt-pp cp) '(2)) (2 = pt-pi cp)
      (pt-heq (apon (apon t0 p9) q8) (apon (apon t0 cq) cp))
      (pt-heq (apon (apon t0 p9) q8) '((: a 1) (: b 2) (run () (h y))))
      (commute cq cp @ c2
       (pt-heq <c2 p9 && pt-heq <>c2 q8)))),

  ; the refusals read off the rule: a rigid-part edit (the rule's context
  ;      mentions it), a duplicating rule (the edit would be needed twice),
  ;      an erasing rule (the edit would vanish), a span covering rigid
  ;      structure beside the binding.
  (test
   !(commute (pt-tp '(2) 0 '(main) '(go)) q8)
   !(commute p8 (pt-tp () 2 '((main (mv v))) '((run (mv v) (mv v)))))
   !(commute p8 (pt-tp () 2 '((main (mv v))) '((halt))))
   !(commute (pt-tp '(2) 0 '(main (f x)) '(go)) q8)),

  ; the unifier face: a non-linear pattern binds consistently or not at all,
  ;      and instantiation reads the bindings back out.
  (: t1 '((pair 5 5) (pair 5 6))
     qc (pt-tp () 0 '((pair (mv w) (mv w))) '((mv w)))
     (test
      (valid t1 qc)
      !(valid t1 (pt-tp () 1 '((pair (mv w) (mv w))) '((mv w))))
      (pt-heq (apon t1 qc) '(5 (pair 5 6))))),

  ; (L2) a variable-preserving rule round-trips through its inverse: the news
  ;      pattern matches what it laid, and the olds pattern restores.
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
;
; the ninth form, the door form eight left shut: schematic-vs-schematic. a
; rule here is (olds news) applied at a seat -- match olds against the
; subtree, lay news instantiated over it -- so this is the rule grain with
; the sequence machinery stripped away (patch.v's ninth slice mirrors it
; term for term). the seat relation decides everything: diverging seats
; are order-free, and with no re-aim -- a tree address doesn't shift under
; a disjoint rewrite, so the sequence forms' index slide vanishes at this
; grain (rw_comm_div) -- while any overlap is critical-pair territory: two
; rules at one seat can both land, in either order, and disagree, so no
; total commute exists at rule grain and a refusal is earned, never
; cautious (cp_earned). the uu-term leg re-proves both at code grain
; (test/uupatch.l), its deep demos on the lof lane. deliberately out,
; named in patch.v's header: the variable-overlap lane (a redex under the
; other rule's metavariable slides to its rhs seat for linear rules --
; mvswal's rule-rule face) and joinability of critical pairs (which
; overlaps are harmless is Knuth-Bendix completion territory, not a
; commute question).

(:
 ; --- the tree + pattern kit (form 8's, trimmed local) ---

 ; --- a rule at a seat: match olds against the subtree, lay news
 ;     instantiated; rw answers (tree) or (), rw2 sequences two ---
 (rw R path t)
   (: sub (pt-tnav t path)
      sg (pt-mtch <R sub ())
      (sg = 'no ? ()
         [(pt-tlay t path (pt-inst <>R sg))]))
 (rw2 Ra pa Rb pb t) (rw Ra pa t @ r (atom? r ? () (rw Rb pb <r)))

 t0 '((f 1) ((g 2) (h 3)))
 Ra '((f (mv x)) (f ((mv x) (mv x))))     ; duplicate under f
 Rb '((h (mv y)) (k (mv y)))

 ; (L3a at rule grain) diverging seats are order-free, the addresses
 ;     unshifted -- both orders, one tree; deeper shared prefixes too
 ((: c1 (rw2 Ra '(0) Rb '(1 1) t0) c2 (rw2 Rb '(1 1) Ra '(0) t0)
     (test
      !(atom? c1) (pt-heq <c1 <c2)
      (pt-heq <c1 '((f (1 1)) ((g 2) (k 3)))))),
  (: p9 '((g (mv u)) (g ((mv u)))) q9 '((h (mv v)) (h))
     c1 (rw2 p9 '(1 0) q9 '(1 1) t0) c2 (rw2 q9 '(1 1) p9 '(1 0) t0)
     (test !(atom? c1) (pt-heq <c1 <c2))),

  ; the critical pair, earned: one seat, two rules, both orders green --
  ;     and they disagree, so no total commute exists at rule grain
  (: R1 '((mv z) (a)) R2 '((mv z) (b))
     c1 (rw2 R1 () R2 () t0) c2 (rw2 R2 () R1 () t0)
     (test
      !(atom? c1) !(atom? c2)
      !(pt-heq <c1 <c2)
      (pt-heq <c1 '(b)) (pt-heq <c2 '(a)))),

  ; the destroyed redex, the overlap's other face: nested seats, and the
  ;     order decides which rule survives at all
  (: Rc '((g (mv u)) (k 5)) Rd '((g (mv w)) (g 9))
     (test
      !(atom? (rw2 Rd '(1 0) Rc '(1 0) t0))       ; d then c: c still sees a g
      (atom? (rw2 Rc '(1 0) Rd '(1 0) t0)))),     ; c then d: the g is gone
  0))
