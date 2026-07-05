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
