# gwen lisp

- `:` `\` `?` three special forms
- int, float, complex, bignum, array
- list, lambda, macro, symbol, string, process, hash (mutable)
- portable C virtual machine for self hosting thread compiler

gwen lisp evaluation strategy is somewhat different from other lisp.
in gwen lisp every value represents an injective function.
even "data" like numbers, strings, symbols, lists, etc. act as functions
in a (hopefully) well-defined way. therefore many expressions that would be
meaningless in other lisp are well defined and common in gwen lisp, while
certain expressions common in other lisp have alternate meaning in gwen lisp.

for functions this uses currying. for "data" types each type's types
function action is defined in a (hopefully) natural way. lists
are evaluated as if by left-to-right application, excluding side effects:

- `(f x y z) = (((f x) y) z) = (foldl1 id (list f x y z))`

the exact order is up to the compiler. if user code requires specific sequencing,
this is done by the `:` special form.
```
(: y (f 0) ; eval second argument first
   x (g 0) ; eval first argument second
   _ (puts "hello world") ;
 (c x y))
```

since every value is a one-argument function, zero-functions (thunks) don't exist per se in Gwen lisp.
a singleton list has the value of its element, consistent with the `foldl1` identity above.

- `(f) = f`

for a nullary function in gwen lisp, write unary function and call it
with an arbitrary value. it's normal to call a function with `0`
(or `()` if you want to be fancy about it). similarly, variadic functions
aren't present in gwen lisp.  `+` is a binary operation in gwen lisp, but
variadic in most other lisp. if you really want a variadic function then
there's two ways:

- macro method

```
```
- sentinel way

```
(: end (gensym 'end) ; vararg sentinel value -- a fresh unique symbol
   (li k x) (? (= end x) (k ()) (li (\ z (k (cons x z)))))
   lis (li id)
 (lis 1 2 3 4 5 end)) ; = '(1 2 3 4 5)
```



##### syntax differences
gwen lisp syntax is different from other lisp, being more simple. for the language,

### three special forms

| gwen               |  scheme near equivalent |
|--------------------|-------- --|
| `(? a b c d e)`    | `(cond (a b) (c d) (#t e))`    |
| `(: a b c d e)`    | `(letrec* ((a b) (c d)) e)`   |
| <code>(&#92; a b c d e)</code> | `(lambda (a b c d) e)`|
| <code>(&#92; x)</code> | `(quote x)` |



special forms in gwen lisp omit most internal grouping parens compared to their counterparts in
scheme and common lisp. for `:` and <code>&#92;</code>this means only a single body expression
is allowed. if you want sequencing of multiple expressions, make the body an explicit `:` form.


#### no dotted pairs

unlike other lisp, gwen lisp doesn't have dotted pairs. "improper" lists are not distinguished for printing/reading purposes.


## code examples

### variadic function using a sentinel

### church numerals

church numerals come for free: a fixnum *is* its own church numeral. applying a
number `n` to a function composes that function with itself `n` times, so
`(n f x)` applies `f` to `x` `n` times:

```
(3 (+ 2) 0)            ; = 6  -- add 2, three times
(5 (* 2) 1)            ; = 32 -- double, five times
(: thrice (3 (+ 1))    ; (n f) on its own is the n-fold composition
 (thrice 0))           ; = 3
```

applied to a number instead of a function, a fixnum exponentiates:

```
(2 10)                 ; = 100 -- ten squared
```

you can also build them the classic way, as plain lambdas:

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
```
