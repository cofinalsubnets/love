; apps/utils/diff.l -- myers diff: the shortest edit script between two lists (Myers 1986,
; the greedy O(ND) forward pass with a trace, then the backtrack). the seed of aiutils --
; the coming `diff` tool reads it, the vcs records it. pure ai (no nif); element equality
; is the generic `=`, so it diffs lines, symbols, charms, whole trees alike.
;
; the script is a list of (op x) 2-lists, op one of 'keep 'del 'add, in order: the
; keep+del column spells the OLD list, keep+add the NEW, and the del+add count is
; MINIMAL -- the three laws apps/utils/law.l holds it to (an O(nm) LCS oracle for the
; third). a body-less top-level `:` (the wm's app shape): `myers` the entry,
; dold/dnew/dcost the script readers, d* the machinery. indexes and rounds ride TABLETS
; (charm keys, negatives fine) for O(1) reads; every loop is a tail call.
(:
   ; a list -> a tablet keyed 0..n-1: O(1) element reads for the snake loop
   (dindex l) (: t (tablet 0)
                 (go i m) (? (two? m) (: _ (pin t i (cap m)) (go (+ i 1) (cup m))) t)
                 (go 0 l))
   ; the down/right choice at diagonal k of round d, read off the PREVIOUS round's row
   ; vp -- shared by the forward pass and the backtrack (they must agree or the path tears)
   (ddown? vp d k) (|| (= k (- 0 d))
                       (&& (! (= k d)) (< (peep vp (- k 1) 0) (peep vp (+ k 1) 0))))
   ; slide the snake: advance x,y while the elements agree; answers (x y)
   (dsnake ax bx n m x y) (? (&& (< x n) (< y m) (= (ax x) (bx y)))
                             (dsnake ax bx n m (+ x 1) (+ y 1))
                             (L x y))
   ; round d: fill row vd over k = -d..d step 2 from the previous row vp, pin vd into the
   ; trace, answer (L d) the moment (n m) is reached -- else recurse into round d+1.
   ; d is bounded by n+m, so the recursion always lands.
   (dfwd ax bx n m vp d tr)
    (: vd (tablet 0)
       (gok k)
        (? (< d k) ()
           (: x0 (? (ddown? vp d k) (peep vp (+ k 1) 0) (+ 1 (peep vp (- k 1) 0)))
              xy (dsnake ax bx n m x0 (- x0 k))
              x (cap xy) y (caup xy)
              _ (pin vd k x)
              (? (&& (<= n x) (<= m y)) (L d) (gok (+ k 2)))))
       r (gok (- 0 d))
       _ (pin tr d vd)
       (? (two? r) r (dfwd ax bx n m vd (+ d 1) tr)))
   ; the leading snake back to the origin: everything left is kept
   (dkeeps ax x acc) (? (< 0 x) (dkeeps ax (- x 1) (link (L 'keep (ax (- x 1))) acc)) acc)
   ; rewind one snake from (x y) toward (px py), prepending keeps; answers (x y acc)
   (dsnakeb ax x y px py acc)
    (? (&& (< px x) (< py y))
       (dsnakeb ax (- x 1) (- y 1) px py (link (L 'keep (ax (- x 1))) acc))
       (L x y acc))
   ; walk the trace back from (n m) at round dd, emitting the script front-first: rewind
   ; the round's snake, then the one edit that opened it (down took b's line, right a's)
   (dback ax bx tr dd x y acc)
    (? (< dd 1) (dkeeps ax x acc)
       (: vp (peep tr (- dd 1) 0)
          k (- x y)
          dn (ddown? vp dd k)
          pk (? dn (+ k 1) (- k 1))
          px (peep vp pk 0)
          py (- px pk)
          acc2 (caup (cup (dsnakeb ax x y px py acc)))
          (? dn (dback ax bx tr (- dd 1) px py (link (L 'add (bx py)) acc2))
             (dback ax bx tr (- dd 1) px py (link (L 'del (ax px)) acc2)))))
   ; the entry: the shortest edit script from a to b
   (myers a b)
    (: ax (dindex a) bx (dindex b) n (tally a) m (tally b)
       v0 (pin (tablet 0) 1 0)
       tr (tablet 0)
       r (dfwd ax bx n m v0 0 tr)
       (dback ax bx tr (cap r) n m ()))
   ; the script read three ways: the old list, the new list, the edit distance
   (dold s) (map caup (filter (\ o (! (= (cap o) 'add))) s))
   (dnew s) (map caup (filter (\ o (! (= (cap o) 'del))) s))
   (dcost s) (tally (filter (\ o (! (= (cap o) 'keep))) s)))

; --- patience: the anchoring layer over myers (Bram Cohen). same script shape, so the
; projection laws carry over verbatim -- what changes is the SHAPE of the hunks: anchor
; on the lines a human would (unique in both sides), recurse between anchors, and let
; myers fill the gaps, trading minimality (dcost patience >= dcost myers) for hunks
; that align on landmarks instead of boilerplate. the pass: peel the common prefix and
; suffix (keeps for free, and they shrink the D the O(ND) core sees), census both sides
; (tablets key elements STRUCTURALLY, so string lines and whole trees census alike),
; pair the unique-in-both positions, keep the longest increasing subsequence of them
; (the patience-sorting step, an O(k^2) DP -- k is tiny), and split at the survivors.
(:
   ; occurrence census: element -> how many times it appears
   (dcensus l) (: t (tablet 0)
                  (go m) (? (two? m) (: _ (pin t (cap m) (+ 1 (peep t (cap m) 0))) (go (cup m))) t)
                  (go l))
   ; the unique-in-both candidates as (i j e) pairs, i ascending
   (danchors a b)
    (: ca (dcensus a) cb (dcensus b)
       bj (tablet 0)
       (gob m j) (? (two? m)
                    (: e (cap m)
                       _ (? (&& (= (ca e) 1) (= (cb e) 1)) (pin bj e j) ())
                       (gob (cup m) (+ j 1)))
                    ())
       _ (gob b 0)
       (goa m i acc) (? (two? m)
                        (: e (cap m) j (peep bj e -1)            ; -1 the absence face: j = 0 is a real seat
                           (? (< j 0) (goa (cup m) (+ i 1) acc)
                              (goa (cup m) (+ i 1) (link (L i j e) acc))))
                        (rev acc))
       (goa a 0 ()))
   ; the longest increasing subsequence of the j's (the i's already ascend): O(k^2) DP
   (dlis ps)
    (: n (tally ps) pt (dindex ps)
       (jof t) (caup (pt t))
       ln (tablet 0) pv (tablet 0)
       (gos t s bl bp)                                            ; best chain ending at t
        (? (<= t s) (: _ (pin ln t bl) _ (pin pv t bp) ())
           (: c (? (< (jof s) (jof t)) (+ 1 (peep ln s 0)) 0)
              (? (< bl c) (gos t (+ s 1) c s) (gos t (+ s 1) bl bp))))
       (got t) (? (<= n t) () (: _ (gos t 0 1 -1) (got (+ t 1))))
       _ (got 0)
       (gom t best bt) (? (<= n t) bt                             ; the longest chain's tail
                          (: c (peep ln t 0)
                             (? (< best c) (gom (+ t 1) c t) (gom (+ t 1) best bt))))
       (gob t acc) (? (< t 0) acc (gob (peep pv t -1) (link (pt t) acc)))
       (gob (gom 0 0 -1) ()))
   ; peel the common prefix; answers (a' b' keeps), the keeps REVERSED
   (dpre a b ks)
    (? (&& (two? a) (two? b) (= (cap a) (cap b)))
       (dpre (cup a) (cup b) (link (L 'keep (cap a)) ks))
       (L a b ks))
   ; split at the anchors: each between-segment recurses (uniqueness reappears locally
   ; once the outer context is cut away), each anchor lands as a keep
   (dsplit a b ai bi ps)
    (? (! (two? ps)) (patience a b)
       (: h (cap ps) i (cap h) j (caup h) e (caup (cup h))
          na (- i ai) nb (- j bi)
          (cat (patience (take na a) (take nb b))
               (link (L 'keep e)
                     (dsplit (drop (+ na 1) a) (drop (+ nb 1) b) (+ i 1) (+ j 1) (cup ps))))))
   ; the trimmed middle: anchor + split, or myers when nothing anchors
   (dmid a b) (: ps (danchors a b)
                 (? (two? ps) (dsplit a b 0 0 (dlis ps)) (myers a b)))
   ; the entry: patience diff, same script contract as myers
   (patience a b)
    (: p (dpre a b ())
       a1 (cap p) b1 (caup p) pre (rev (caup (cup p)))
       s (dpre (rev a1) (rev b1) ())                              ; the suffix is the reversed prefix
       a2 (rev (cap s)) b2 (rev (caup s)) suf (caup (cup s))      ; ... and its keeps come back forward
       (cat pre (cat (dmid a2 b2) suf))))
