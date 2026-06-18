; quasiquote / unquote / unquote-splice (reader macros `` , ,@ + qq expander)
(: b 2 xs '(3 4) c 9)
(assert
 ; plain quasiquote with no unquotes is just a literal
 (= '(a b c) ``(a b c))
 (= 'x ``x)
 ; unquote substitutes a value
 (= '(a 2 c) ``(a ,b c))
 (= '(1 2 3) ``(,(- b 1) ,b ,(+ b 1)))
 ; unquote-splice splices a list in place
 (= '(a 3 4 c) ``(a ,@xs c))
 (= '(3 4 3 4) ``(,@xs ,@xs))
 (= '(0 3 4 2 9) ``(0 ,@xs ,b ,c))
 ; nested structure with a deep unquote
 (= '(a (x 2) c) ``(a (x ,b) c))
 ; a stray top-level unquote just evaluates its operand (uq = identity)
 (= 3 ,(+ 1 2))
 ; an empty splice contributes nothing
 (= '(a c) ``(a ,@'() c))
 ; single backtick ` is the element-eval LIST constructor: `(a b c) = (list a b c),
 ; each element evaluated. (quasiquote, the less common, took the double `` -- one rule.)
 (= '(2 4 3) `((+ 1 1) (* 2 2) (+ 1 2)))
 (: a 5 b 10 (= '(5 10 15) `(a b (+ a b)))))
