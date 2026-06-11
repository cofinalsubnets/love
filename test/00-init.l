(: test_t0 (clock 0)
 (term_esc string) (do (putc 27) (puts string))
 green_dot "[32m."
 red_x "[31mX"
 reset "[0m"
 (term_text s)
  (do (putc 27)
     (puts s)
     (putc 27)
     (puts reset))

   test_state (tablet 0)
   (test_set k v) (pin test_state k v)
   (test_get k) (peep test_state k 0))
(:: 'assert (\ l
(:
 (report x v) (do
  (test_set 'count (+ 1 (test_get 'count)))
   (? v (term_text green_dot)
    (do (term_text red_x) (putc 10)
       (puts "assert failed: ") (putx x) (putc 10) (exit 1))))
 (cons 'do (map (\ l (L report (L '\ l) l)) l)))))
