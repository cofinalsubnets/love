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
  (['a 'c 'b] = map (x \ (two? x ? (atom? <x ? 'a 'b) 'c)) [[1] 2 [[3]]])
  (!cp || "(\\ a (? (charm? a) 3 0))" = show (x \ (charm? x && 3)))   ; && and || past their own test
  (!cp || "(\\ a (? (two? a) 1 5))" = show (x \ (two? x || 5)))
  ([3 0 1 5] = map (x \ (charm? x && 3)) [7 "s"] + map (x \ (two? x || 5)) [[1] 2])
  (!cp || "(\\ a (+ a 1))" = show (s \ (: q s (q + 1))))          ; a local's alias reads as it
  ([6 5] = [((s \ (: q s ((\ s (q + s)) 5))) 1) ((s \ (: q s (: s 4 (q + s + s - 4)))) 1)])  ; hidden, the alias stays
  (7 = ((s \ (: q s f (\ _ q) s 9 ((f 0) + s - 3))) 1))              ; a sibling's s is no alias
  (!cp || "(\\ a 5)" = show (x \ (? 0 x 1 5 9)))                      ; a constant test keeps its live arm
  ([() () 5] = [((x \ (? x 5)) 0) ((x \ (? (nil? x) 5)) 3) ((x \ (? (nil? x) 5)) ())])   ; no else: ()
  ([2 1 1] = [((x \ (? (nil? x) 1 2)) 3) ((x \ (? (nil? x) 1 2)) ())
              ((x \ (: (nil? y) 7 (? (nil? x) 1 2))) 3)])))                  ; a local nil? is no flip
