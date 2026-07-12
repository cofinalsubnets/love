; sketch: THE PATCH GROUPOID -- the layer UNDER a distribution, and the missing
; piece that makes a distribution and a namespace the SAME thing rather than two
; that merely rhyme. a darcs, read through our lattice-and-algebra habit and sat
; on the self-hosting fixpoint.
;
; --- one algebra, read a fourth way --- we already lean on "one lattice, read
; four ways" (dispatch / order / algebra / abstract domain). the distribution
; story wants the SAME move one level up: every layer we stack is a SELECTION --
; a subset over a dependency relation, with a merge:
;   * a NAMESPACE   = a selected set of NAMES        (a book -- holo, glaze)
;   * a COMPONENT   = a selected set of DEFINITIONS  (a book's worth of source)
;   * a DISTRIBUTION= a selected set of COMPONENTS   (a book of books, layered)
;   * a REPO STATE  = a selected set of PATCHES       <- THIS is the missing floor
; these are not four analogous tools. they are one algebra. the patch layer is
; the DYNAMICS -- how the sets are formed, inverted, and combined -- for the
; floor under all the others. that is why version control slots in exactly here
; and nowhere else: it turns a "version" from an opaque atom into something
; COMPOSABLE, and composable is what collapses distribution and namespace into
; one mechanism.
;
; --- a version is a FRONTIER, not a snapshot --- the earlier distribution sketch
; keyed the store on named images (git/rustup snapshot thinking). that is the
; seam this closes. a version is a downward-closed SET OF PATCHES (a frontier);
; the baked image (`.image`) is a CACHE of replaying that frontier; the patch set
; is the truth, the manifest, AND the reproducibility handle. "install version X"
; = pull these patches, replay, and fixpoint-check the bake. rustup cannot verify
; a download; we can verify a REBUILD -- cc(cc(ai)) is already byte-identical, so
; a frontier's identity (a hash of its patch set) is checkable to the bit.
;
; --- why patches, not snapshots --- a component selection is LITERALLY a
; cherry-pick, and cherry-pick / merge / unpull / component-composition are all
; ONE operation: COMMUTE. "this toolchain = base u {these components} u {that
; fix}" is an arbitrary consistent subset of a patch bag. git's snapshot DAG
; cannot say "any consistent subset is a valid state"; a darcs patch bag is
; DEFINED that way. so the VCS model and the distribution model want the identical
; primitive -- build commute once (soundly), get the rest as bookkeeping.
;
; --- the groupoid --- patches form an inverse structure: partial composition
; (append when contexts line up), every patch INVERTIBLE (unpull is apply-inverse),
; and COMMUTE the partial swap that reorders independent patches. the three laws
; to prove, the same way we proved the tiling theorem and the fixpoint axiom-free:
;   (L1) commute is its own inverse:      commute(p,q)=(q',p') => commute(q',p')=(p,q)
;   (L2) inverse round-trips:             apon (apon t p) (invert p) == t   (on p's slot)
;   (L3) merge = commute into a common context (the ONLY definition of merge)
; classic darcs got these subtly wrong (the exponential / unsound conflict corner).
; building this in the one language with the Rocq/Lean harness, DON'T clone darcs
; 1.x -- clone the idea on the SOUND substrate (the inverse-semigroup formalization,
; or pijul's pushout-in-a-category), and let proof/ carry L1..L3. the first slice
; (the named-slot model) is machine-checked axiom-free in proof/rocq/patch.v -- but
; that .v is SCAFFOLDING: a hand proof drifts (the wm2uu lesson). the destination is
; GENERATED like the rest of proof/ -- L1..L3b encoded as uu proof TERMS, emitted to
; Rocq AND Lean by tools/uu2coq.l + tools/uu2lean.l (the model fits uu's MLTT:
; pointwise, decidable eqb, list induction -- no funext, no classical). source of
; truth is an executable ai spec (a test/patch.l), the .v/.lean drift-gated off it.
;
; --- the ai-native sharpening --- source is .l, so a patch can be a transform over
; the FORM TREE, not textual line ranges. then "do p and q commute?" is "do these
; two rewrites touch disjoint locations / are they confluent?" -- a question wev /
; boxfix and the kanren unifier already answer. darcs fought line-hunk commutation
; for years; we would commute AST edits with machinery we own. the toy below uses
; NAMED SLOTS (a file of named lines) so commute is clean; the comment at `commute`
; marks where positional / structural patches make q' a genuine re-aim -- and THAT
; is where the rewrite layer earns its keep.
;
; --- staging (keep it honest) --- build the snapshot store + shim + default now
; (independent, useful today), but make a version's identity a PATCH-SET HASH from
; day one -- even if the first VCS is a stub that only does linear apply. then the
; patch layer slots UNDER the store later instead of replacing it. the two forks
; are DECIDED (gwen, 2026-07-12): FORM-TREE + SOUND. (a) patch GRAIN: a patch is a
; rewrite over the form tree, commutation answered by machinery we own (wev /
; boxfix / the unifier); textual hunks are at most a later compatibility skin,
; never the model. (b) theory BASE: the sound substrate -- the inverse-semigroup
; reading (partial composition, invert, commute the partial swap) is the working
; formalization since it fits uu's MLTT (decidable eqb, list induction, no
; funext); pijul's pushout stays the cross-check reading, classic darcs 1.x a
; cautionary tale only.
;
; --- the runnable toy below --- two layers. first the NAMED-SLOT model: a tree, a
; chg patch carrying its own context (old->new), and the four primitives: apon /
; invert / commute / frontier. it DEMONSTRATES: independent patches commute and
; are order-free; a same-slot patch DEPENDS (commute answers ()); inverse
; round-trips; and two distribution COMPONENTS install to the same frontier
; regardless of pull order. then the POSITIONAL layer (demo E, the rung opened
; 2026-07-12): hunks over a sequence of forms, where commute genuinely RE-AIMS --
; the swapped hunk's index slides by the other's length delta, and TOUCHING hunks
; refuse (strict: a seam has no canonical order once inserts land on it; classic
; darcs's ambiguity corner, closed by fiat). the laws for BOTH layers live in
; test/patch.l, the source of truth. still deliberately OMITTED: conflictors (a
; real merge records one), content hashing (the frontier identity), and the TREE
; lift (a path per hunk -- the sequence law applied at every level, where the
; unifier earns its keep). those are the next rungs.

(:
 ; --- the patch: a groupoid element. (chg slot old new) carries its context
 ;     (old) so it knows where it BELONGS -- a patch is not a bare diff. ---
 (chg k a b) (link 'chg (link k (link a (link b 0))))
 (pk p) (cap (cup p))                                       ; the slot it touches
 (pa p) (cap (cup (cup p)))                                 ; its context (old value)
 (pb p) (cap (cup (cup (cup p))))                           ; the new value

 ; --- the tree: an assoc (k . v), newest shadows, a missing slot reads 0 (a
 ;     nothing -- the nil-is-0 floor). ---
 (tget t k) (? (atom? t) 0 (: c (cap t) (? (id? k (cap c)) (cup c) (tget (cup t) k))))
 (tset t k v) (link (link k v) t)

 ; --- apply: a patch belongs on t only if its context matches (valid); apon
 ;     lays the new value. applall folds a frontier onto the empty tree. ---
 (valid t p) (id? (tget t (pk p)) (pa p))
 (apon t p) (tset t (pk p) (pb p))
 (applall t ps) (foldl apon t ps)

 ; --- invert: every patch has an inverse (the groupoid law) -- unpull is just
 ;     apply-the-inverse. ---
 (invert p) (chg (pk p) (pb p) (pa p))

 ; --- commute: the ONE hard primitive. p;q -> q;p when INDEPENDENT (different
 ;     slots); () when q DEPENDS on p (same slot -- q's context is p's effect).
 ;     merge, cherry-pick, and unpull are all built on this. here the swapped
 ;     patches are unchanged because named slots do not SHIFT; with positional or
 ;     form-tree patches q' is a genuine re-aim (the rewrite/unifier lane). ---
 (commute p q) (? (id? (pk p) (pk q)) 0 (link q (link p 0)))
 (depends p q) (atom? (commute p q))                        ; q needs p iff they don't commute

 ; --- report helpers ---
 (line label v) (: _ (puts label) _ (. (show v)) (putc 10))
 (cat2 a b) (? (atom? a) b (link (cap a) (cat2 (cup a) b)))

 ; ---- demos ----
 _ (: px (chg 'x 0 1) py (chg 'y 0 2)
      t1 (applall 0 (link px (link py 0)))
      t2 (applall 0 (link py (link px 0)))                  ; opposite pull order
      _ (puts ";; A. independent patches commute -- both pull orders agree\n")
      _ (puts "     commute(px,py) = ")
      _ (. (show (commute px py)))
      _ (putc 10)
      _ (line "     order px;py -> x,y = " (link (tget t1 'x) (link (tget t1 'y) 0)))
      (line "     order py;px -> x,y = " (link (tget t2 'x) (link (tget t2 'y) 0))))

 _ (: p1 (chg 'x 0 1) p2 (chg 'x 1 2)                       ; both touch x
      _ (puts ";; B. same-slot patches DEPEND -- commute answers () -> a dependency\n")
      _ (line "     commute(p1,p2) = " (commute p1 p2))
      (line "     p2 depends on p1 = " (depends p1 p2)))

 _ (: px (chg 'x 0 7)
      t (apon (apon 0 px) (invert px))                      ; apply then unpull
      _ (puts ";; C. inverse round-trips (the groupoid law)\n")
      (line "     apon;invert -> x = " (tget t 'x)))

 _ (: holo (link (chg 'holo 0 1) 0)                         ; a component = a patch bag
      glaze (link (chg 'glaze 0 1) 0)
      fa (applall 0 (cat2 holo glaze))                      ; install holo then glaze
      fb (applall 0 (cat2 glaze holo))                      ; ...or glaze then holo
      _ (puts ";; D. two distribution COMPONENTS install to the same frontier\n")
      _ (line "     pull holo;glaze -> " (link (tget fa 'holo) (link (tget fa 'glaze) 0)))
      (line "     pull glaze;holo -> " (link (tget fb 'holo) (link (tget fb 'glaze) 0))))

 ; ---- demo E: the positional layer -- a self-contained hunk model, where the
 ;      swapped q is a genuine RE-AIM (its index slides by p's length delta) ----
 _ (: (htake s n) (? (< n 1) () (link (cap s) (htake (cup s) (- n 1))))
      (hdrop s n) (? (< n 1) s (hdrop (cup s) (- n 1)))
      (splice s i c news) (cat2 (htake s i) (cat2 news (hdrop s (+ i c))))
      (hunk i o n) (link 'hunk (link i (link o (link n ())))) ; at i, segment o -> n
      (hi p) (cap (cup p)) (ho p) (cap (cup (cup p))) (hn p) (cap (cup (cup (cup p))))
      (hpon s p) (splice s (hi p) (tally (ho p)) (hn p))
      (hcom p q)                                            ; p;q -> q';p', or () on a seam
        (: i (hi p) o1 (tally (ho p)) n1 (tally (hn p))
           j (hi q) o2 (tally (ho q)) n2 (tally (hn q))
           (? (> j (+ i n1)) (link (hunk (- (+ j o1) n1) (ho q) (hn q)) (link p ()))
              (< (+ j o2) i) (link q (link (hunk (- (+ i n2) o2) (ho p) (hn p)) ()))
              ()))
      s0 '(a b c d e)
      p (hunk 1 '(b) '(x y))                                ; grows the file by one
      q (hunk 4 '(d) '(z))                                  ; aimed in post-p coordinates
      c (hcom p q)
      _ (puts ";; E. positional hunks -- commute RE-AIMS: q slides 4 -> 3 past p's growth\n")
      _ (line "     commute(p,q) = " c)
      _ (line "     order p;q   -> " (hpon (hpon s0 p) q))
      _ (line "     order q';p' -> " (hpon (hpon s0 (cap c)) (cap (cup c))))
      (line "     the seam refuses: " (hcom p (hunk 3 '(c) '(w)))))
 0)
