; sortby: merge sort with a love comparator; the left is taken when (le x y), so 1 on ties is stable
(: (lcg x) ((16807 * x) % 2147483647)
   (genl x n) (n < 1 ? () (lcg x @ nx (nx . genl nx (n - 1))))
   (ins x l) (? (atom? l) [x] (x <= <l) (x . l) (<l . ins x >l))
   (isort l) (foldl (acc \ x \ ins x acc) () l)
   l (genl 1 3000)
   (recs ks i) (atom? ks ? () (((<ks % 7) . i) . recs >ks (i + 1)))     ; (key . position)
   rs (recs (genl 3 400) 0)
   ; a budget of twice the live set forces a collection at the spine, re-entering the step
   ; with a compare's answer pending; the knobs go back before anything reads them
   k0 (tune ())
   _ (please 1)
   _ (tune [(2 * peep (gauge 0) 8 0) 8192 65536 24])
   tight (sortby (a \ b \ ([a b (show a)], a < b)) l)
   (tune k0,
    (test
     (() = (sortby (<) ()))
     ('(5) = (sortby (<) '(5)))
     ('(1 2) = (sortby (<) '(2 1)))
     ('(1 2 3) = (sortby (<) '(3 1 2)))
     ('(3 2 1) = (sortby (>) '(3 1 2)))
     ((sort l) = (sortby (<) l))                                    ; a random 3000 against the C order
     ((sort l) = (sortby (<=) l))
     ((rev (sort l)) = (sortby (>) l))
     ((isort (genl 5 300)) = (sortby (<=) (genl 5 300)))
     ; stable: ties keep their order under a <= comparator, first by key then by original index
     ('((0 . b) (0 . d) (1 . a) (1 . c)) = (sortby (a \ b \ <a <= <b) '((1 . a) (0 . b) (1 . c) (0 . d))))
     ((: byk (sortby (a \ b \ <a <= <b) rs)
         (ok l) (? (atom? >l) 1
                   (<<l < <<>l
                    || <<l = <<>l && ><l < ><>l)
                   (ok >l) 0)
         (ok byk)) = 1)
     ; a comparator that allocates: collections run under the sort, and the trays move with them
     ((sort l) = (sortby (a \ b \ ([a b (show a)], a < b)) l))
     ((sort l) = tight)                                             ; ... and the same under a budget that collects at the spine
     ; a comparator that sorts: the frames nest
     ((sort l) = (sortby (a \ b \ #(sortby (<) [a b a]) < 4 ? (a < b) 0) l))
     ; the answer is read as a truth, not a bit: a list answers by its net
     ('(1 2 3) = (sortby (a \ b \ a < b ? '(1 1) '(-1)) '(2 3 1)))
     ; strings and lists sort by their own comparators
     ('("a" "bb" "ccc") = (sortby (a \ b \ #a <= #b) '("ccc" "a" "bb"))))))
