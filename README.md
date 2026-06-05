# gwen lisp

A lisp dialect where every value is a unary function.

## features

- lists, symbols, macros, lambdas, eval/apply, call/cc
- strings, file i/o
- integers, floats, bignums, complex, vectors
- only three special forms
- currying like haskell
- co-op multitasking
- repl with native line editing
- self-hosting threaded code compiler
- super portable

## language details

Gwen lisp has Scheme-like lexical scope and a single namespace for functions and values, and uses four
special forms with easy Scheme equivalents.  However, the evaluation procedure is different, more similar to Haskell,
though gwen lisp is dynamically typed. Functions are automatically curried, and data implicitly act as their own constant
functions.  Therefore in gwen lisp every value is a unary function. Lists are evaluated by left-to-right application:

- `(f x y z) = (((f x) y) z) = (foldl id f (list x y z)) ; modulo side effects`

However, this is only a conceptual description: actual evaluation order may vary for optimization purposes.
Therefore if you need specific evaluation order you should use the sequencing form `:`

```
(: y (f 0) ; eval second argument first
   x (g 0) ; eval first argument second
 (c x y))
```

Since every value is a unary function, nullary/0-argument functions (thunks) don't exist per se in Gwen lisp, and a singleton
list has the value of its element:

- `(f) = f`

To implement a nullary function, write a unary function and call with an arbitrary value. Conventionally `0` or `()` are used
for this purpose. Similarly, variadic functions aren't a distinct feature in Gwen lisp, but they can either be simulated with
macros, or written directly using an explicit sentinel (see below for an example).

### special forms

There are three special forms:

| gwen               |  scheme equivalent |
|--------------------|----------|
| `?`                | `cond`   |
| `:`                | `let`    |
| <code>&#92;</code> | `lambda` / `quote` |

Quote is not a separate form: it is the degenerate case of `\` with no parameters
(see below). The surface sugar `'x` reads as `(\ x)`.

#### ? (cond)

| gwen            | scheme                      |
|-----------------|-----------------------------|
| `(? a b c d e)` | `(cond (a b) (c d) (#t e))` |

- like `cond` in other lisp
- `0` is the sole false value
- `(? 0 a b) = b`
- `(? x a b) = a ; x != 0`
- `(? x a) = (? x a 0)`
- `(? x) = x`

#### : (let)

| gwen            | scheme                      |
|-----------------|-----------------------------|
| `(: a b c d e)` | `(let  ((a b) (c d)) e)` |

- like `let` in scheme (but see below)
- `(: a) = a`
- `(: a b) = (: a b a) ; at toplevel this is also a global definition`
- `(: (a f b) (f b)) = (: a (\ f b (f b))) ; syntact sugar for lambdas`
- `(: a 1 a (+ 1 a) a) = 2 ; variable shadowing works`
- recursive functions are supported like `letrec` in scheme
- evaluation is sequential like `let*` in scheme
- assignments are immutable (some data are mutable)
- also used for sequencing `(: _ (do this) _ (then do that) (final value))`

#### &#92; (lambda / quote)

| gwen                           | scheme                 |
|--------------------------------|------------------------|
| <code>(&#92; a b c d e)</code> | `(lambda (a b c d) e)` |
| <code>(&#92; x)</code>         | `(quote x)`            |

- like `lambda` in other lisp, but multiple arguments and one body expression, not one argument list and multiple body expressions
- the last operand is the body, the rest are parameters
- with exactly one operand there are no parameters, so it is a nullary "function";
  since nullary application doesn't exist it can never be forced, and degenerates to
  a literal — i.e. `quote`. So `(\ x)` is `(quote x)`, and the reader sugar `'x`
  expands to `(\ x)`.
- use `:` for sequencing multiple expressions in one function body

#### quasiquote

Reader sugar (expanded by the `qq` macro in the prelude), like other lisps:

| gwen    | meaning                                  |
|---------|------------------------------------------|
| `` `x`` | quasiquote — quote `x` but allow escapes |
| `,x`    | unquote — splice in the value of `x`     |
| `,@x`   | unquote-splicing — splice the elements of the list `x` |

So <code>&#96;(a ,b ,@xs c)</code> builds `(cons 'a (cons b (cat xs (cons 'c '()))))`.
Nesting tracks depth (R7RS): an unquote only fires at the outermost quasiquote.
A stray `,x` outside any quasiquote just evaluates `x` (`uq` is bound to identity).

### printed representation

Most values print as themselves; a few print as the `,`-prefixed constructor
expression that rebuilds them (`,` reads as `uq`, i.e. identity, so the printed
form round-trips):

| value              | prints as                          |
|--------------------|------------------------------------|
| complex            | `,(cplx re im)`                    |
| rank-1 i64/f64 array | `,(vec a b …)`                   |
| other array        | `,(arrl type '(shape) '(elems))`   |
| table              | `,(tbl k1 v1 …)`                   |

Functions print the same way — a builtin as `,name`, a compiled lambda as its
source `,(\ x (+ x 1))`, and a partial application / closure as the base applied
to its captured arguments `,(+ 1)`, `,((\ y x (+ x y)) 5)` (the `,` is only on the
outermost form). A closure shows its captured variables as **leading parameters**
of the base lambda (`y` above), matching the order they're applied, so it too reads
back to an equal value. An opaque thread (a continuation) prints bare as `#<thread>`.

## code examples

### variadic function using a sentinel

```
(: endsym (sym 0)
   (li k x) (? (= endsym x) (k ()) (li (\ z (k (cons x z)))))
   lis (li id)
 (lis 1 2 3 4 5 endsym)) ; = '(1 2 3 4 5)
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
