# gwen lisp

A lisp dialect where every value is a unary function.

## features

- lisp stuff: lists, symbols, macros, lambdas, quote, quasiquote, eval/apply, call/cc
- integers, floats, bignums, complex, vectors
- strings, file i/o, multitasking
- only three special forms
- every value is a unary function
- all functions curried like haskell
- super portable self hosting optimizing threaded code compiler
- native repl with line editing


## language details

### three special forms

| gwen               |  scheme equivalent |
|--------------------|-------- --|
| `(? a b c d e)`    | `(cond (a b) (c d) (#t e))`    |
| `(: a b c d e)`    | `(letrec* ((a b) (c d)) e)`   |
| <code>(&#92; a b c d e)</code> | `(lambda (a b c d) e)`|
| <code>(&#92; x)</code> | `(quote x)` |

### evaluation strategy

gwen lisp evaluation strategy is somewhat different from other lisp.
functions are automatically curried, and data implicitly act as their own constant
functions, therefore in gwen lisp every value is a unary function.
lists are evaluated as if by left-to-right application:

- `(f x y z) = (((f x) y) z) = (foldl1 id (list f x y z)) ; modulo side effects`

however, this is only a conceptual description: actual argument evaluation order may vary.
therefore if you need specific order you should use the sequencing form `:`

```
(: y (f 0) ; eval second argument first
   x (g 0) ; eval first argument second
 (c x y))
```

## potentially confusing differences from other lisp

### everything is a function

even data like strings, numbers, etc. everything acts as a function in a defined way. many expressions
that would be erroneous in other lisp are perfectly fine in gwen lisp.

### less parens

special forms in gwen lisp omit most internal grouping parens compared to their counterparts in
scheme and common lisp. for `:` and <code>&#92;</code>this means only a single body expression
is allowed. if you want sequencing of multiple expressions, make the body an explicit `:` form.

### nullary functions (thunks)

since every value is a unary function, nullary/0-argument functions (thunks) don't exist per se in Gwen lisp.
a singleton list has the value of its element, consistent with the `foldl1` identity above.

- `(f) = f`

for a nullary function in gwen lisp, write a unary function and call it with an arbitrary value. passing an ignored
value is (usually `0` or equivalently `()`) is idiomatic in gwen lisp, but in practice it's often possible to find
something to parametrize over.

### variadic functions (varargs)

similarly, variadic functions aren't a distinct feature in gwen lisp, but they can either be simulated with
macros, or written directly using an explicit sentinel (see below for an example). as a corollary, functions like
`+` that are variadic in other lisp are binary in gwen lisp.

### dotted pairs

gwen lisp doesn't print or read them. tails of improper lists are not displayed.


## code examples

### variadic function using a sentinel

```
(: end (sym 0) ; vararg sentinel value
   (li k x) (? (= end x) (k ()) (li (\ z (k (cons x z)))))
   lis (li id)
 (lis 1 2 3 4 5 end)) ; = '(1 2 3 4 5)
```

### church numerals

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
