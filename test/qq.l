; quasiquote / unquote / unquote-splice (reader macros ` , ,@ + qq expander)
(: b 2 xs '(3 4) c 9)
(assert
 ; plain quasiquote with no unquotes is just a literal
 (= '(a b c) `(a b c))
 (= 'x `x)
 ; unquote substitutes a value
 (= '(a 2 c) `(a ,b c))
 (= '(1 2 3) `(,(- b 1) ,b ,(+ b 1)))
 ; unquote-splice splices a list in place
 (= '(a 3 4 c) `(a ,@xs c))
 (= '(3 4 3 4) `(,@xs ,@xs))
 (= '(0 3 4 2 9) `(0 ,@xs ,b ,c))
 ; nested structure with a deep unquote
 (= '(a (x 2) c) `(a (x ,b) c))
 ; a stray top-level unquote just evaluates its operand (uq = identity)
 (= 3 ,(+ 1 2))
 ; nested quasiquote: the inner unquote stays LITERAL, only an outer one fires
 (= '(qq (b (uq c)))   ``(b ,c))
 (= '(qq (b (uq 9)))   ``(b ,,c))
 ; an empty splice contributes nothing
 (= '(a c) `(a ,@'() c)))
