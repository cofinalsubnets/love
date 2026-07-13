; test/patch.l -- the PATCH GROUPOID, the executable SOURCE-OF-TRUTH spec.
;
; the drift anchor for the whole patch stack: doc/proto/patch.l is the design (the
; argument that a distribution / namespace / repo-state are ONE algebra of
; selectable sets, with COMMUTE the primitive underneath); proof/rocq/patch.v
; machine-checks the slices axiom-free under `make test_proof` (named slots,
; positional hunks, the conflictor merge, and the frontier identity in full;
; the tree lift's commute ALGEBRA -- L1 with the path re-aim -- with its apply
; laws asserted here and queued for the uu-term rung). the laws asserted HERE are what those
; are gated to agree with -- the .v today, and the next rung (L1..L3b as uu proof
; TERMS emitted to rocq + lean by tools/uu2coq.l + tools/uu2lean.l) tomorrow; a
; hand .v drifts (the wm2uu lesson), so this file is the truth it regenerates off.
;
; the named-slot model: a tree is a (key . value) assoc, a patch a single
; slot-change carrying its CONTEXT (old -> new -- not a bare diff), commute the
; partial swap. the laws:
;   L1  commute is involutive              L3a commute is sound: independent
;   L2  inverse round-trips (in context)       patches are ORDER-FREE
;                                          L3b a FRONTIER is stable under an
;                                              adjacent swap of independent patches
; helpers stay LOCAL (the corpus runs concatenated in one scope); the asserts run
; inside the body, so the whole spec is one leak-free form.

(:
 ; --- the model (mirror of doc/proto/patch.l) ---
 (chg k a b) (link 'chg (link k (link a (link b 0))))     ; patch: change slot k, old->new
 (pk p) (cap (cup p))                                     ; the slot it touches
 (pa p) (cap (cup (cup p)))                               ; its context (old value)
 (pb p) (cap (cup (cup (cup p))))                         ; the new value
 (tget t k) (? (atom? t) 0 (: c (cap t) (? (id? k (cap c)) (cup c) (tget (cup t) k))))
 (tset t k v) (link (link k v) t)                         ; newest shadows; a missing slot reads 0
 (valid t p) (id? (tget t (pk p)) (pa p))                 ; a patch belongs iff its context matches
 (apon t p) (tset t (pk p) (pb p))                        ; lay the patch's new value
 (applall t ps) (foldl apon t ps)                         ; fold a whole frontier onto a tree
 (invert p) (chg (pk p) (pb p) (pa p))                    ; the groupoid inverse (unpull)
 (commute p q) (? (id? (pk p) (pk q)) 0 (link q (link p 0)))  ; partial: 0 = a dependency

 ; --- spec-local equality: deep-structural (patches are lists), and tree agreement
 ;     at a witness key set (trees are maps -> compare pointwise, as the .v does) ---
 (leq a b) (? (&& (atom? a) (atom? b)) (id? a b)
              (|| (atom? a) (atom? b)) 0
              (&& (leq (cap a) (cap b)) (leq (cup a) (cup b))))
 (teq a b ks) (? (atom? ks) 1 (&& (id? (tget a (cap ks)) (tget b (cap ks))) (teq a b (cup ks))))
 (cat2 a b) (? (atom? a) b (link (cap a) (cat2 (cup a) b)))

 ; --- witnesses ---
 px (chg 'x 0 1) py (chg 'y 0 2)                          ; independent -- different slots
 p1 (chg 'x 0 1) p2 (chg 'x 1 2)                          ; dependent -- same slot

 ; (L1) commute is INVOLUTIVE: swap two independent patches, swap the result back,
 ;      and you are home. same-slot patches DON'T commute -- 0, a dependency.
 _ (assert
    (leq (commute px py) (link py (link px 0)))                       ; p;q -> q;p
    (: c (commute px py) (leq (commute (cap c) (cap (cup c)))
                              (link px (link py 0))))                 ; ...and back to p;q
    (! (commute p1 p2))                                              ; same slot -> no commute
    (leq p1 p1) (! (leq px py)))                                     ; leq itself is honest

 ; (L2) INVERSE round-trips IN CONTEXT: where the patch is valid, apply then unpull
 ;      (apply the inverse) restores every slot; invert is its own inverse.
 _ (: t0 (tset 0 'x 5) p (chg 'x 5 9)
      (assert
       (valid t0 p)                                                  ; p belongs on t0
       (: t1 (apon (apon t0 p) (invert p)) (teq t1 t0 '(x y)))       ; apply;unpull == id
       (leq p (invert (invert p)))))                                 ; invert involutive

 ; (L3a) independent patches are ORDER-FREE (the semantic heart -- what makes merge
 ;       and cherry-pick sound): both pull orders land the same tree.
 _ (: a (apon (apon 0 px) py) b (apon (apon 0 py) px)
      (assert (teq a b '(x y)) (= 1 (tget a 'x)) (= 2 (tget a 'y))))

 ; (L3b) a FRONTIER is stable under swapping two adjacent independent patches -- the
 ;       reproducibility tie: meaning is order-free, so the (unordered) patch set is
 ;       a sound version identity. and the distribution face: two disjoint COMPONENTS
 ;       install to the same frontier whichever is pulled first.
 _ (: pre (link (chg 'a 0 7) 0) post (link (chg 'b 0 8) 0)
      f1 (applall 0 (cat2 pre (link px (link py post))))             ; pre ++ [px py] ++ post
      f2 (applall 0 (cat2 pre (link py (link px post))))             ; ...px,py swapped
      _ (assert (teq f1 f2 '(a b x y)))
      (: holo (link (chg 'holo 0 1) 0) glaze (link (chg 'glaze 0 1) 0)
         (assert (teq (applall 0 (cat2 holo glaze))
                      (applall 0 (cat2 glaze holo)) '(holo glaze)))))
 0)

; --- the POSITIONAL rung: hunks over a SEQUENCE, where commute genuinely RE-AIMS ---
;
; the form-tree fork's first slice: a file is a sequence of forms, a patch a HUNK
; -- (hunk i olds news): at index i the segment olds (its context: a hunk BELONGS
; somewhere) becomes news. named slots never shift; hunks DO -- commuting past an
; unequal-length hunk moves the other's index by the length delta, so the swapped
; q is a genuine re-aim, not the identity. the four laws are the same; the new
; teeth: TOUCHING hunks refuse to commute (strict, the sound choice -- two inserts
; on one seam have no canonical order; classic darcs's ambiguity corner), and
; valid carries a BOUND (an out-of-range insert still splices -- at the end -- but
; its inverse aims past the end, so the round-trip would lie; the bound keeps L2
; honest). same helpers-local discipline; a second leak-free form.

(:
 ; --- the model: sequences and hunks ---
 (hunk i o n) (link 'hunk (link i (link o (link n ()))))  ; at i, the segment o becomes n
 (hi p) (cap (cup p))                                     ; where it aims
 (ho p) (cap (cup (cup p)))                               ; its context (the old segment)
 (hn p) (cap (cup (cup (cup p))))                         ; the new segment
 (htake s n) (? (< n 1) () (link (cap s) (htake (cup s) (- n 1))))
 (hdrop s n) (? (< n 1) s (hdrop (cup s) (- n 1)))
 (hcat a b) (? (atom? a) b (link (cap a) (hcat (cup a) b)))
 (seg s i n) (htake (hdrop s i) n)                        ; the n elements from index i
 (splice s i c news) (hcat (htake s i) (hcat news (hdrop s (+ i c))))
 (heq a b) (? (&& (atom? a) (atom? b)) (id? a b)
              (|| (atom? a) (atom? b)) 0
              (&& (heq (cap a) (cap b)) (heq (cup a) (cup b))))
 (valid s p) (&& (<= (+ (hi p) (tally (ho p))) (tally s)) ; in range -- the round-trip bound
                 (heq (seg s (hi p) (tally (ho p))) (ho p)))
 (apon s p) (splice s (hi p) (tally (ho p)) (hn p))
 (applall s ps) (foldl apon s ps)
 (invert p) (hunk (hi p) (hn p) (ho p))

 ; --- commute: the re-aim. p;q -> q';p'. q strictly PAST p's news shifts BACK by
 ;     p's delta (j + |o1| - |n1|); q strictly BEFORE shifts p FORWARD by q's
 ;     delta. overlap OR touch answers () -- a dependency. ---
 (commute p q)
   (: i (hi p) o1 (tally (ho p)) n1 (tally (hn p))
      j (hi q) o2 (tally (ho q)) n2 (tally (hn q))
      (? (> j (+ i n1)) (link (hunk (- (+ j o1) n1) (ho q) (hn q)) (link p ()))
         (< (+ j o2) i) (link q (link (hunk (- (+ i n2) o2) (ho p) (hn p)) ()))
         ()))

 ; --- witnesses: a file of five forms; p GROWS the file (delta +1) ---
 s0 '(a b c d e)
 p (hunk 1 '(b) '(x y))                                   ; at 1, b -> x y
 q (hunk 4 '(d) '(z))                                     ; post-p coords: d sits at 4

 ; (L1) commute is INVOLUTIVE -- and the swap is a GENUINE RE-AIM: q comes back
 ;      at 3 (its pre-p seat), p rides unmoved, and swapping again is home.
 _ (: c (commute p q) cq (cap c) cp (cap (cup c))
      (assert
       (= 4 (hi q)) (= 3 (hi cq))                         ; the shift is real
       (heq cp p)
       (: c2 (commute cq cp)
          (&& (heq (cap c2) p) (heq (cap (cup c2)) q)))))

 ; dependencies: overlap, and the SEAM -- touching refuses too (strict)
 _ (assert
    (! (commute p (hunk 2 '(y) '(w))))                    ; lands inside p's news
    (! (commute p (hunk 3 '(c) '(w))))                    ; starts exactly at p's end
    (! (commute (hunk 1 () '(u)) (hunk 1 () '(v)))))      ; two inserts, one seam

 ; (L2) inverse round-trips IN CONTEXT -- and valid's BOUND has teeth: the
 ;      out-of-range insert is exactly the hunk whose round-trip would lie.
 _ (assert
    (valid s0 p)
    (heq (apon (apon s0 p) (invert p)) s0)
    (heq p (invert (invert p)))
    (! (valid '(a) (hunk 5 () '(u)))))                    ; past the end: no home

 ; (L3a) commute is SOUND: p;q and q';p' land the SAME sequence -- while q
 ;       UN-shifted does not even belong on s0 (the point of the re-aim).
 _ (: c (commute p q) cq (cap c) cp (cap (cup c))
      (assert
       (heq (apon (apon s0 p) q) (apon (apon s0 cq) cp))
       (heq (apon (apon s0 p) q) '(a x y c z e))
       (! (valid s0 q))))                                 ; naive swap: context miss

 ; a SHRINKING p (delta -1) shifts q the OTHER way -- same law, other sign
 _ (: pn (hunk 1 '(b c) '(u)) qn (hunk 3 '(e) '(w))       ; post-pn coords: e at 3
      c (commute pn qn) cq (cap c) cp (cap (cup c))
      (assert
       (= 4 (hi cq))                                      ; back UP to its s0 seat
       (heq (apon (apon s0 pn) qn) (apon (apon s0 cq) cp))
       (heq (apon (apon s0 pn) qn) '(a u d w))))

 ; the BEFORE branch: q lands ahead of p, so p is the one re-aimed (by q's delta)
 _ (: pb (hunk 3 '(d) '(w)) qb (hunk 0 '(a b) '(u))       ; qb shrinks the prefix
      c (commute pb qb) cq (cap c) cp (cap (cup c))
      (assert
       (heq cq qb) (= 2 (hi cp))                          ; q unmoved; p slides down
       (heq (apon (apon s0 pb) qb) (apon (apon s0 cq) cp))
       (heq (apon (apon s0 pb) qb) '(u c w e))))

 ; the elements are FORMS, not lines -- the ai-native grain: a hunk swaps a whole
 ; definition and nothing above cares what an element IS.
 _ (: fs '((f a) (g b) (main ()))
      fp (hunk 1 '((g b)) '((g c) (h d)))
      (assert (valid fs fp)
              (heq (apon fs fp) '((f a) (g c) (h d) (main ())))))

 ; (L3b) a FRONTIER is stable under the adjacent independent swap -- the
 ;       reproducibility tie again, now with real shifting inside the list.
 _ (: c (commute p q)
      f1 (applall s0 (link (hunk 0 '(a) '(aa)) (link p (link q ()))))
      f2 (applall s0 (link (hunk 0 '(a) '(aa)) c))
      (assert (heq f1 f2) (heq f1 '(aa x y c z e))))
 0)

; --- the CONFLICTOR rung: a real merge RECORDS, and the state enlarges ---
;
; commute REFUSES a dependency; merge may not. the sound move (pijul's, read
; through our habit -- classic darcs 1.x made conflicts exotic patch algebra and
; got the exponential/unsound corner): ENLARGE THE STATE until merge is total. a
; conflicted slot holds a CLASH cell -- the shared base plus a canonically-ordered
; set of RIVALS -- so merge is SYMMETRIC and ASSOCIATIVE by construction (a set
; has no pull order), neither side silently wins, and RESOLUTION needs no new
; machinery: a clash cell is a first-class VALUE, so resolving is an ordinary chg
; whose old value is the cell -- invertible like any patch (unpull a resolution
; and the clash returns). `pull` is MERGE machinery, not honest application: it
; trusts the co-valid discipline (every pulled patch reads the shared base or a
; rival of it -- what two branches of one repo guarantee); `valid` stays the gate
; for a lone patch. rivals here are charms, so < is the canon; a general value
; order is the tree lift's business. named-slot model (the clean case first,
; as ever); clash SEGMENTS in the hunk model ride a later rung.

(:
 ; --- the model: rung 1's trees and patches, plus the clash cell ---
 (chg k a b) (link 'chg (link k (link a (link b ()))))
 (pk p) (cap (cup p)) (pa p) (cap (cup (cup p))) (pb p) (cap (cup (cup (cup p))))
 (tget t k) (? (atom? t) 0 (: c (cap t) (? (id? k (cap c)) (cup c) (tget (cup t) k))))
 (tset t k v) (link (link k v) t)
 (invert p) (chg (pk p) (pb p) (pa p))
 (heq a b) (? (&& (atom? a) (atom? b)) (id? a b)
              (|| (atom? a) (atom? b)) 0
              (&& (heq (cap a) (cap b)) (heq (cup a) (cup b))))
 (teq a b ks) (? (atom? ks) 1 (&& (heq (tget a (cap ks)) (tget b (cap ks)))
                                  (teq a b (cup ks))))
 (clash a rs) (link 'clash (link a (link rs ())))          ; base a, rivals rs (sorted)
 (clash? v) (? (atom? v) 0 (id? (cap v) 'clash))
 (cbase c) (cap (cup c))
 (rivals c) (cap (cup (cup c)))
 (cins x rs) (? (atom? rs) (link x ())                     ; canonical insert, dedup --
                (: h (cap rs)                              ; the set that makes merge
                   (? (= x h) rs                           ; order-free
                      (< x h) (link x rs)
                      (link h (cins x (cup rs))))))

 ; --- pull: total merge-application. five lanes; the LAST is the discipline
 ;     backstop (a cell-shaped mismatch no-ops rather than inventing a story). ---
 (pull t p)
   (: k (pk p) a (pa p) b (pb p) v (tget t k)
      (? (heq v a) (tset t k b)                            ; the plain lane: context matches
         (heq v b) t                                       ; the same edit again: settled
         (&& (clash? v) (&& (heq (cbase v) a) (! (clash? b))))
           (tset t k (clash a (cins b (rivals v))))        ; join the rivals
         (&& (! (clash? v)) (! (clash? a)) (! (clash? b)))
           (tset t k (clash a (cins b (cins v ()))))       ; a rival landed first
         t))                                               ; discipline breach: no-op
 (applall t ps) (foldl pull t ps)
 (cat2 a b) (? (atom? a) b (link (cap a) (cat2 (cup a) b)))

 ; --- witnesses: three rivals for x over base 1, and an independent bystander ---
 t0 (tset 0 'x 1)
 p (chg 'x 1 2) q (chg 'x 1 3) r (chg 'x 1 4)
 w (chg 'y 0 9)

 ; (M1) merge is TOTAL and SYMMETRIC: rivals or bystanders, both pull orders
 ;      land the same tree -- the pushout apex, unique.
 _ (assert
    (teq (pull (pull t0 p) q) (pull (pull t0 q) p) '(x y))
    (teq (pull (pull t0 p) w) (pull (pull t0 w) p) '(x y)))

 ; (M2) the plain lane IS rung 1: a matching context applies as ever, and the
 ;      same edit arriving twice settles (idempotent).
 _ (assert
    (= 2 (tget (pull t0 p) 'x))
    (teq (pull (pull t0 p) p) (pull t0 p) '(x y)))

 ; (M3) a conflict is HONEST: the slot carries the base AND both rivals,
 ;      canonically ordered -- neither side silently won.
 _ (: m (pull (pull t0 q) p) c (tget m 'x)
      (assert (clash? c) (= 1 (cbase c)) (heq (rivals c) '(2 3))))

 ; (M4) three rivals, ANY order: one cell, one set -- the associativity that
 ;      broke classic darcs, answered by a set instead of patch algebra.
 _ (: m1 (pull (pull (pull t0 p) q) r)
      m2 (pull (pull (pull t0 r) q) p)
      m3 (pull (pull (pull t0 q) r) p)
      (assert (teq m1 m2 '(x)) (teq m2 m3 '(x))
              (heq (rivals (tget m1 'x)) '(2 3 4))))

 ; (M5) RESOLUTION is just a patch: old value = the cell, new = the choice --
 ;      the plain lane applies it, invert UNPULLS it and the clash returns.
 _ (: m (pull (pull t0 p) q) cell (tget m 'x)
      res (chg 'x cell 5)
      m2 (pull m res)
      (assert
       (= 5 (tget m2 'x)) (! (clash? (tget m2 'x)))
       (teq (pull m2 (invert res)) m '(x y))))

 ; and the distribution face: two components pinning ONE name differently
 ;      install to the same recorded clash whichever is pulled first.
 _ (: holo (link (chg 'font 0 1) ()) glaze (link (chg 'font 0 2) ())
      fa (applall 0 (cat2 holo glaze))
      fb (applall 0 (cat2 glaze holo))
      (assert (teq fa fb '(font)) (clash? (tget fa 'font))))
 0)

; --- the IDENTITY rung: a version IS its patch set, hashed canonically ---
;
; the reproducibility handle the laws already point at. L3b/M4 proved a
; frontier's MEANING is order-free, M2 that multiplicity is dead -- so an
; identity that quotients by exactly order and repetition is SOUND: it forgets
; nothing the semantics keeps. (dependent patches carry their ORDER in their
; contexts -- a frontier is a downward-closed SET, replay order is derived, not
; stored -- so the set identity is the right grain even when patches chain.)
; the shape: hash each patch's printed form (show is the canonical
; serialization), fold the hashes through cins -- the SAME canonical set that
; carries a clash's rivals, so order-freedom IS cins-commutativity and
; dup-freedom IS cins-absorption (both proven in patch.v) -- then hash the
; canonical list once for the scalar name. collision-freedom is engineering
; (djb2 here, a real digest when the store lands); the LAWS live on the
; canonical list.

(:
 (hstr h s i n) (? (= i n) h (hstr (% (+ (* h 33) (s i)) 4294967296) s (+ i 1) n))
 (hval v) (: s (show v) (hstr 5381 s 0 (tally s)))         ; djb2 over the printed form
 (cins x rs) (? (atom? rs) (link x ())
                (: h (cap rs) (? (= x h) rs (< x h) (link x rs)
                                 (link h (cins x (cup rs))))))
 (fid ps) (foldl (\ acc p (cins (hval p) acc)) () ps)      ; the canonical hash set
 (ident ps) (hval (fid ps))                                 ; one scalar to name it
 (chg k a b) (link 'chg (link k (link a (link b ()))))

 ; --- witnesses ---
 p (chg 'x 1 2) q (chg 'x 1 3) w (chg 'y 0 9)

 ; (H1) ORDER-FREE: any pull order, one identity -- the M4 face, on the name.
 _ (assert
    (= (ident (link p (link q (link w ()))))
       (ident (link w (link q (link p ())))))
    (= (ident (link p (link w ()))) (ident (link w (link p ())))))

 ; (H2) MULTIPLICITY-FREE: pulling twice settles (M2), and the name agrees.
 _ (assert (= (ident (link p (link p (link q ()))))
              (ident (link p (link q ())))))

 ; (H3) CONTENT-SENSITIVE: touch any patch and the name moves -- including
 ;      direction (a patch and its inverse are different content).
 _ (assert
    (! (= (ident (link p ())) (ident (link q ()))))
    (! (= (ident (link p (link q ()))) (ident (link p (link w ())))))
    (! (= (ident (link p ())) (ident (link (chg 'x 2 1) ())))))
 0)

; --- the TREE LIFT rung: a hunk gets a PATH, and the shift climbs the levels ---
;
; the form-tree grain made whole: a file is a TREE of forms (nested sequences),
; a patch a hunk with a POSTCODE -- the path to the sequence it splices. the
; load-bearing fact: a deep patch never changes the length of any ANCESTOR
; sequence, so only same-sequence patches shift each other's INDICES -- but a
; shallow splice moves whole SUBTREES, so it re-aims a deeper patch's path
; COMPONENT at the crossing level. commute gets four lanes by path relation:
;   same    the two hunks share a sequence -- rung 2 verbatim, paths ride
;   inq     q is deeper, crossing p's sequence at child j: j past p's news
;           slides BACK by p's delta (a genuine PATH re-aim); j inside p's
;           news is a dependency (q edits content p just wrote)
;   inp     p is deeper, crossing q's sequence at child j: j past q's olds
;           slides FORWARD by q's delta; j inside q's olds is a dependency --
;           q SWALLOWS p's subtree, and commuting would need to rewrite q's
;           context (undo p inside it): THE DOOR THE UNIFIER OPENS LATER
;   apart   the paths diverge: disjoint subtrees, both ride untouched
; strictness at the crossing differs from rung 2's seam ON PURPOSE: a path
; component >= the splice's far edge names a SURVIVOR (an element that moved),
; not a seam position -- there is no insert-order ambiguity to refuse, so >=
; is sound where the seam needed >.

(:
 ; --- the sequence kit (rung 2, local) ---
 (htake s n) (? (< n 1) () (link (cap s) (htake (cup s) (- n 1))))
 (hdrop s n) (? (< n 1) s (hdrop (cup s) (- n 1)))
 (hcat a b) (? (atom? a) b (link (cap a) (hcat (cup a) b)))
 (seg s i n) (htake (hdrop s i) n)
 (splice s i c news) (hcat (htake s i) (hcat news (hdrop s (+ i c))))
 (nth s j) (cap (hdrop s j))
 (heq a b) (? (&& (atom? a) (atom? b)) (id? a b)
              (|| (atom? a) (atom? b)) 0
              (&& (heq (cap a) (cap b)) (heq (cup a) (cup b))))

 ; --- the tree kit: navigate to a path's sequence, lay a new one back ---
 (tnav t path) (? (atom? path) t (tnav (nth t (cap path)) (cup path)))
 (tlay t path s2)
   (? (atom? path) s2
      (splice t (cap path) 1
              (link (tlay (nth t (cap path)) (cup path) s2) ())))

 ; --- patches: (tp path i olds news) -- a hunk with a postcode ---
 (tp path i o n) (link 'tp (link path (link i (link o (link n ())))))
 (pp p) (cap (cup p))            (pi p) (cap (cup (cup p)))
 (po p) (cap (cup (cup (cup p)))) (pn p) (cap (cup (cup (cup (cup p)))))
 (apon t p) (tlay t (pp p) (splice (tnav t (pp p)) (pi p) (tally (po p)) (pn p)))
 (applall t ps) (foldl apon t ps)
 (invert p) (tp (pp p) (pi p) (pn p) (po p))
 (pathok t path) (? (atom? path) 1
                    (: j (cap path)
                       (&& (< j (tally t))
                           (: e (nth t j)
                              (&& (! (atom? e)) (pathok e (cup path)))))))
 (valid t p) (&& (pathok t (pp p))
                 (: s (tnav t (pp p))
                    (&& (<= (+ (pi p) (tally (po p))) (tally s))
                        (heq (seg s (pi p) (tally (po p))) (po p)))))

 ; --- path surgery + the path relation ---
 (setidx path d v) (? (= d 0) (link v (cup path))
                      (link (cap path) (setidx (cup path) (- d 1) v)))
 (rel P Q d) (? (&& (atom? P) (atom? Q)) '(same)
                (atom? P) (link 'inq (link (cap Q) (link d ())))
                (atom? Q) (link 'inp (link (cap P) (link d ())))
                (id? (cap P) (cap Q)) (rel (cup P) (cup Q) (+ d 1))
                '(apart))

 ; --- commute: four lanes, two kinds of re-aim (index at 'same, PATH at the
 ;     crossings), () a dependency ---
 (commute p q)
   (: P (pp p) ip (pi p) o1 (tally (po p)) n1 (tally (pn p)) dp (- n1 o1)
      Q (pp q) iq (pi q) o2 (tally (po q)) n2 (tally (pn q)) dq (- n2 o2)
      r (rel P Q 0) tag (cap r)
      (? (id? tag 'same)
           (? (> iq (+ ip n1)) (link (tp Q (- (+ iq o1) n1) (po q) (pn q)) (link p ()))
              (< (+ iq o2) ip) (link q (link (tp P (- (+ ip n2) o2) (po p) (pn p)) ()))
              ())
         (id? tag 'inq)
           (: j (cap (cup r)) d (cap (cup (cup r)))
              (? (< j ip) (link q (link p ()))
                 (>= j (+ ip n1))
                   (link (tp (setidx Q d (- j dp)) iq (po q) (pn q)) (link p ()))
                 ()))
         (id? tag 'inp)
           (: j (cap (cup r)) d (cap (cup (cup r)))
              (? (< j iq) (link q (link p ()))
                 (>= j (+ iq o2))
                   (link q (link (tp (setidx P d (+ j dq)) ip (po p) (pn p)) ()))
                 ()))
         (link q (link p ()))))

 ; --- witnesses: a little program -- three top forms, one nested. every
 ;     witness rides through `warm` (a live identity): a CONSTANT list binding
 ;     fed straight to a recursive local trips a compiler hang -- the shape,
 ;     the probes, and the sweep-off note live in doc/bug-const-letrec-hang.md ---
 (warm x) ((\ y y) x)
 t0 (warm '((: a 1) (: b 2) (main (f x))))
 pr (warm (tp () 0 () '((use m))))                         ; root insert at 0 (dp +1)
 qd (warm (tp '(3) 1 '((f x)) '((g y))))                   ; deep edit, aimed POST-pr

 ; (L1) commute is INVOLUTIVE, and the re-aim is a PATH re-aim: qd's postcode
 ;      slides 3 -> 2 (its pre-pr seat), and swapping back is home.
 _ (: c (commute pr qd) cq (cap c) cp (cap (cup c))
      (assert
       (heq (pp qd) '(3)) (heq (pp cq) '(2))               ; the path moved
       (heq cp pr)
       (: c2 (commute cq cp)
          (&& (heq (cap c2) pr) (heq (cap (cup c2)) qd)))))

 ; dependencies: a deep edit inside freshly-written news, and the swallow
 ;      (q replaces the subtree p edited -- the unifier's door, shut for now)
 _ (assert
    (! (commute pr (tp '(0) 0 '(use) '(want))))            ; inside pr's news
    (! (commute (tp '(1) 2 '(1) '(7)) (tp () 1 '((: a 7)) ()))))  ; swallowed

 ; (L2) inverse round-trips at depth
 _ (: pd (warm (tp '(2) 1 '((f x)) '((g y) (h z))))
      (assert
       (valid t0 pd)
       (heq (apon (apon t0 pd) (invert pd)) t0)
       (valid t0 (tp '(2 1) 0 () '(u)))                    ; (f x) IS a sequence: descend
       (! (valid t0 (tp '(9) 0 () '(u))))                  ; no such child
       (! (valid t0 (tp '(2 0) 0 () '(u))))))              ; main is a LEAF: no descent

 ; (L3a) commute is SOUND across levels: root insert then deep edit == re-aimed
 ;       deep edit then root insert -- and the un-shifted qd has no home on t0.
 _ (: c (commute pr qd) cq (cap c) cp (cap (cup c))
      (assert
       (heq (apon (apon t0 pr) qd) (apon (apon t0 cq) cp))
       (heq (apon (apon t0 pr) qd)
            '((use m) (: a 1) (: b 2) (main (g y))))
       (! (valid t0 qd))))

 ; the INP lane: a deep edit rides a root shrink the other way (path 2 -> 1)
 _ (: pd (warm (tp '(2) 1 '((f x)) '((g y)))) qr (warm (tp () 0 '((: a 1)) ()))
      c (commute pd qr) cq (cap c) cp (cap (cup c))
      (assert
       (heq cq qr) (heq (pp cp) '(1))                      ; p slides down
       (heq (apon (apon t0 pd) qr) (apon (apon t0 cq) cp))
       (heq (apon (apon t0 pd) qr) '((: b 2) (main (g y))))))

 ; APART: sibling subtrees ride untouched, both orders agree
 _ (: pa (warm (tp '(0) 2 '(1) '(9))) qa (warm (tp '(2) 1 '((f x)) '((g y))))
      c (commute pa qa)
      (assert
       (heq (cap c) qa) (heq (cap (cup c)) pa)
       (heq (apon (apon t0 pa) qa) (apon (apon t0 qa) pa))))

 ; SAME sequence at depth: rung 2's shift verbatim, riding a postcode
 _ (: ts (warm '((a b c d e)))
      p1 (warm (tp '(0) 1 '(b) '(x y))) q1 (warm (tp '(0) 4 '(d) '(z)))
      c (commute p1 q1) cq (cap c)
      (assert
       (= 3 (pi cq)) (heq (pp cq) '(0))                    ; index shifts, path rides
       (heq (apon (apon ts p1) q1) (apon (apon ts cq) (cap (cup c))))
       (heq (apon (apon ts p1) q1) '((a x y c z e)))))

 ; (L3b) a FRONTIER is stable under the adjacent independent swap, mixed grains
 _ (: c (commute pr qd)
      f1 (applall t0 (link pr (link qd ())))
      f2 (applall t0 c)
      (assert (heq f1 f2)))
 0)
