# gwen lisp

- three special forms `:` `\` `?`
- int, float, complex, bignum, array
- list, lambda, macro, symbol, string, process, hash (mutable)
- portable C virtual machine for self hosting thread compiler

## language

in gwen lisp the function type includes every value, in other words,
every value has the type `value: value -> value`. even "data" like
numbers, strings, symbols, lists, etc. act as functions in a (hopefully)
well-defined way. therefore many expressions that would be meaningless
in other lisp are well defined and common in gwen lisp, while certain
expressions common in other lisp have different meaning in gwen lisp.
for example, a formula for application is
`(f x y z) = (((f x) y) z) = (foldl id f (list x y z))`, which implies
`(f) = f`, so "thunks" are written differently in gwen lisp.
the `:` form is used both to name variables and to sequence evaluation.
```
(: b (g 0)       ; eval second argument first
   a (f 0)       ; eval first argument second
   _ (puts "hi") ; print something third
 (c a b))        ; last expression = final result
```

comments start with `;` or `#!`. `'` and `#` desugar to quote and hash
constructors respectively. dotted lists are not present. the special
forms are:

| gwen               |   scheme approximate |
|--------------------|-----------|
| `(: a b c d e)`    | `(letrec* ((a b) (c d)) e)`   |
| `(? a b c d e)`    | `(cond (a b) (c d) (#t e))`    |
| <code>(&#92; x)</code> | `(quote x)` |
| <code>(&#92; a b c d e)</code> | `(lambda (a) (lambda (b) (lambda (c) (lambda (d) e))))`|

## code example: church numerals

```
(: (add a b f x) (a f (b f x))
   (mul a b f) (a (b f))
   (zero a b) b
   one (zero zero)
   two (add one one)
   three (add one two)
   four (add two two)
   five (add two three)
   six (mul two three)
   seven (add one six)
 (assert (= 420 (mul (mul two five) (mul six seven) (+ 1) 0))))
; church numerals equivalent to above are built in to the language
(assert (= (3 3 3) 7625597484987))
```
