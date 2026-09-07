; sortby -- the merge sort with a love comparator, a C loop that hands each compare back to
; the VM. the left is taken when (le x y), so a comparator that answers 1 on ties is stable.
(: (lcg x) (% (* 16807 x) 2147483647)
   (genl x n) (? (< n 1) () (: nx (lcg x) (. nx (genl nx (- n 1)))))
   (ins x l) (? (one? l) [x] (x <= <l) (x . l) (<l . ins x >l))
   (isort l) (foldl (\ acc x (ins x acc)) () l)
   l (genl 1 3000)
   (recs ks i) (? (one? ks) () (((% <ks 7) . i) . recs >ks (+ i 1)))   ; (key . position)
   rs (recs (genl 3 400) 0)
 (assert
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
                (|| (< (cap (cap l)) (cap (cap (cup l))))
                    (&& (= (cap (cap l)) (cap (cap (cup l)))) (< (cup (cap l)) (cup (cap (cup l))))))
                (ok >l) 0)
      (ok byk)) = 1)
  ; a comparator that allocates: collections run under the sort, and the trays move with them
  ((sort l) = (sortby (\ a b (: _ (list a b (show a)) (< a b))) l))
  ; a comparator that sorts: the frames nest
  ((sort l) = (sortby (\ a b (? (< (tally (sortby (<) (list a b a))) 4) (< a b) 0)) l))
  ; the answer is read as a truth, not a bit: a list answers by its net
  ('(1 2 3) = (sortby (\ a b (? (< a b) '(1 1) '(-1))) '(2 3 1)))
  ; strings and lists sort by their own comparators
  ('("a" "bb" "ccc") = (sortby (\ a b (<= (tally a) (tally b))) '("ccc" "a" "bb")))))
