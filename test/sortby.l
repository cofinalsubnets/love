; sortby -- the merge sort with a love comparator, a C loop that hands each compare back to
; the VM. the left is taken when (le x y), so a comparator that answers 1 on ties is stable.
(: (lcg x) ((16807 * x) % 2147483647)
   (genl x n) (? (n < 1) () (: nx (lcg x) (. nx (genl nx (n - 1)))))
   (ins x l) (? (one? l) [x] (x <= <l) (x . l) (<l . ins x >l))
   (isort l) (foldl (\ acc x (ins x acc)) () l)
   l (genl 1 3000)
   (recs ks i) (? (one? ks) () (((<ks % 7) . i) . recs >ks (i + 1)))   ; (key . position)
   rs (recs (genl 3 400) 0)
   ; the spine is reserved after the merge, and that reservation collects like any other --
   ; which re-enters the step at its top, where the last compare's answer is still pending.
   ; the law wants that collection, so it sorts under a budget tight enough to force one
   ; (tune's units are words; the knobs are put back before anything else reads them).
   k0 (tune ())
   _ (tune @(1048576 8192 65536 24))
   tight (sortby (\ a b (: _ (list a b (show a)) (a < b))) l)
   _ (tune k0)
 (test
  (() = (sortby (<) ()))
  ('(5) = (sortby (<) '(5)))
  ('(1 2) = (sortby (<) '(2 1)))
  ('(1 2 3) = (sortby (<) '(3 1 2)))
  ('(3 2 1) = (sortby (>) '(3 1 2)))
  ((sort l) = (sortby (<) l))                                       ; a random 3000 against the C order
  ((sort l) = (sortby (<=) l))
  ((rev (sort l)) = (sortby (>) l))
  ((isort (genl 5 300)) = (sortby (<=) (genl 5 300)))
  ; stable: ties keep their order under a <= comparator, first by key then by original index
  ('((0 . b) (0 . d) (1 . a) (1 . c)) = (sortby (\ a b (<a <= <b)) '((1 . a) (0 . b) (1 . c) (0 . d))))
  ((: byk (sortby (\ a b (<a <= <b)) rs)
      (ok l) (? (one? >l) 1
                (|| (cap <l < cap <>l)
                    ((cap <l = cap <>l) && (cup <l < cup <>l)))
                (ok >l) 0)
      (ok byk)) = 1)
  ; a comparator that allocates: collections run under the sort, and the trays move with them
  ((sort l) = (sortby (\ a b (: _ (list a b (show a)) (a < b))) l))
  ((sort l) = tight)                                                ; ... and the same under a budget that collects at the spine
  ; a comparator that sorts: the frames nest
  ((sort l) = (sortby (\ a b (? (tally (sortby (<) (list a b a)) < 4) (a < b) 0)) l))
  ; the answer is read as a truth, not a bit: a list answers by its net
  ('(1 2 3) = (sortby (\ a b (? (a < b) '(1 1) '(-1))) '(2 3 1)))
  ; strings and lists sort by their own comparators
  ('("a" "bb" "ccc") = (sortby (\ a b (tally a <= tally b)) '("ccc" "a" "bb")))))
