; test/patch.l -- the PATCH GROUPOID, the executable SOURCE-OF-TRUTH spec.
;
; the drift anchor for the whole patch stack: doc/proto/patch.l is the design (the
; argument that a distribution / namespace / repo-state are ONE algebra of
; selectable sets, with COMMUTE the primitive underneath); proof/rocq/patch.v
; machine-checks both slices axiom-free (named slots AND the positional hunks
; below, under `make test_proof`). the laws asserted HERE are what those
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
