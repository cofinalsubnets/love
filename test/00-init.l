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
   (test_get k) (peep test_state k 0)
   ; wint: a full 64-bit-word build (native, kernel) -- which is also where reals
   ; are f64, libm is glibc's, a filesystem exists, and the RNG runs full-width.
   ; false only on the 32-bit wasm shim; gates the asserts that need any of those.
   wint (< (32 2) max-charm))
(:: 'assert (\ l
(:
 (report x v) (do
  (test_set 'count (+ 1 (test_get 'count)))
   (? v (term_text green_dot)
    (do (term_text red_x) (putc 10)
       (puts "assert failed: ") (putx x) (putc 10) (nap 1))))
 (link 'do (map (\ l `(report `('\ l) l)) l)))))
