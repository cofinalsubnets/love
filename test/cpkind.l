; cprop's kinds: a name bound to tally, show or a cons, or a local under a kind test's arm, has
; a certain kind, so a kind test on it folds. a compiler that
; folds nothing (love0's c0) answers the values alike, and the shape laws stand down
(: cp ("(\\ a 3)" = show (x \ 1 + 2))
   (gone? s f) (!cp || !(has? (show f) s))
   (cnt n) (charm? n ? (map (i \ i) ^n) 'no)
 (test
  (gone? "string?" (l \ (: s (show l) (string? s ? 1 2))))
  (gone? "atom?" (l \ (: n #l (atom? n ? 1 2))))
  (gone? "atom?" (x \ (two? x ? (atom? x ? 'a 'b) 'c)))
  (gone? "two?" (x \ (atom? x ? 0 (two? x ? 1 2))))         ; past a failed atom?, a pair
  (gone? "string?" (x \ (charm? x ? (string? x) 'z)))
  (gone? "atom?" (x \ (two? x && atom? x)))
  (gone? "two?" (x \ (atom? x || two? x)))
  (!cp || has? (show (x \ (: (two? y) 1 (two? x ? (atom? x) 0)))) "atom?")   ; a shadowed test says nothing
  (!cp || has? (show (x \ (? (two? x) 0 (atom? x)))) "atom?")       ; a failed two? says nothing
  ([0 1 2] = cnt 3) ('no = cnt 2.5) ('no = cnt (1 ~ 3)) (() = cnt -1)
  ([1 2 3] = (: (f l) (: n #l (map (i \ i + 1) ^n)) (f "abc")))
  (['a 'c 'b] = map (x \ (two? x ? (atom? <x ? 'a 'b) 'c)) [[1] 2 [[3]]])))
