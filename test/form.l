(assert
 (id? (:) :) (id? (:) \)          ; a special-form name as a value is missing: not in the book
 (id? (:) (\))                   ; ... and the singleton law collapses (\) to \, the same missing.
 (id? (:) (:)) (id? (:) (?))      ; the empty forms are their head reads -- (f)==f at zero
                                ; operands, BOTH lanes -- the same missing reads, 0 helpless
                                ; (under a help they raise like any missing name; see missing.l)
 (= ''x '(\ x))
 (= 1 (? 1))
 (= 1 (: 1))
 (= 1 (\ 1))
 (= 1 (quote 1))
 (= 'a (quote a))
 (= 5 (: a 2 b 3 a (+ a b) a))
 (= 8 (: a 2 b 3 a (+ a b) a (+ a b) a))
 (= 2 ((\ a b a) 2 3))
 (= 3 ((\ f g (f g 1 2 3)) (\ g a b c (g c b)) (\ a b a)))
 (= 0 (: _ 1 _ 2 0))            ; regression: dup _ + literal-0 body segfaulted pre-round-16
 (= 7 (: _ 1 _ 2 _ 3 7))
 )
