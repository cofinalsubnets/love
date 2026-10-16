; test/gate/rebind.l -- gwen's rebinding law, for rebind.sh: a `:` may bind one name twice,
; functions included; the later binding shadows the earlier past it, and a rebinding's own body
; sees the earlier one. each form through ev, so a bare top-level `:` meets the glaze
(puts (show (map ev ['(: f 1  (f x) 2  (f 0))
                     '(: (f x) 1  (f x) (+ x 10)  (f 0))
                     '(: (f x) 2  f 1  f)
                     '(: (f n) 1  (f n) (? (< n 1) 7 (f (- n 1)))  (f 2))
                     '(: a 1  a (+ a 1)  a (* 2 a)  a)]))
      + "\n")
