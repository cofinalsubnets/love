# gwen lisp

- three special forms `:` `\` `?`
- int, float, complex, bignum, array
- list, lambda, macro, symbol, string, process, hash (mutable)
- portable C virtual machine for self hosting thread compiler

## language

in gwen the function type includes every value. even "data" like
numbers, strings, symbols, lists, etc. act like functions in a (hopefully)
well-defined way. therefore many expressions that would be meaningless
in other lisp are well defined and common in gwen, meanwhile certain common
expressions in other lisp have unexpected meaning in gwen. in particular, an
equation for function application is `(f x y z) = (((f x) y) z) = (foldl 1 f (list x y z))`
which implies `(f) = f`, so "thunks" are given (arbitrary) arguments in gwen.
this is not a meaningless choice: the input value corresponds to the output
value at the memory level. function/argument evaluation order is unspecified.
the `:` form is used for both variable naming and expression sequencing:

```
(: b (g 0)       ; eval second argument first
   a (f 0)       ; eval first argument second
   _ (puts "hi") ; print something third
 (c a b))        ; last expression = final result
```

comments begin with `;` or `#!`. sugar: `'` (quote) ; `#` (hash table) ;
in `:`  `(f x y) (y x) = f (\ x y (y x))` like (define (f x y) ...)` in scheme.
dotted lists are not distinguished for reading/printing so `.` is a normal symbol.
the three basic special forms are:

| gwen               |   scheme approximate |
|--------------------|-----------|
| `(: a b c d e)`    | `(letrec* ((a b) (c d)) e)`   |
| `(? a b c d e)`    | `(cond (a b) (c d) (#t e))`    |
| <code>(&#92; x)</code> | `(quote x)` |
| <code>(&#92; a b c d e)</code> | `(lambda (a) (lambda (b) (lambda (c) (lambda (d) e))))`|

## church fizz buzz (code example)

```
; church numerals
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

; gwen lisp follows this behavior
(assert (= (3 3 3) 7625597484987))

; so fizzbuzz may be written as
(100
 (\ n (: f (? (% n 3) "" "fizz")
         b (? (% n 5) "" "buzz")
         fb (+ f b)
         _ (? (len fb) (putln fb))
       (+ 1 n)))
 1)
```
