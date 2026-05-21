(: test_t0 (clock 0)
 (term_esc string) (, (putc 27) (puts string))
 green_dot "[32m."
 red_x "[31mX"
 reset "[0m"
 (term_text s)
  (, (putc 27)
     (puts s)
     (putc 27)
     (puts reset))

   test_state (new 0)
   (test_set k v) (put k v test_state)
   (test_get k) (get 0 k test_state))
(:: 'assert (\ l
(:
 (report x v) (,
  (test_set 'count (+ 1 (test_get 'count)))
   (? v (term_text green_dot)
    (, (test_set 'fail (X x (test_get 'fail)))
       (term_text red_x))))
 (X ', (map (\ l (L report (L '` l) l)) l)))))
