# gwen lisp

in gwen lisp every value is a monadic total function.
1 is the identity function, 0 is the constant function of 1.
numbers act on functions by composition (church numerals).
a numeric list evaluates to an exponential tower.

- `(0 x) = 1`
- `(1 x) = (x) = x`
- `(f x y) = ((f x) y)`
- `(2 f x) = (f (f x))`
- `(2 3 4) = 4 ** (3 ** 2) = 262144`

reader sigils (prefix operators)
- `.` print
- `'` quote
- `%` hash literal
- `@` array literal
- `$` gensym literal
- `~` complex literal
- `#` saturating projection to non-negative fixnum (len on lists/strings/hashes)
- `!` 1 when `#` is 0 else 0

style special forms
- `:` let
- `\` lambda
- `?` cond

## code examples

hello world

```
."hello world\n"
```

fizzbuzz

```
(100
 (\ n (: f (? (mod n 3) "" "fizz")
         b (? (mod n 5) "" "buzz")
         _ .(? (| #f #b) (+ f b) n)
         _ ."\n"
       (+ 1 n)))
 1)
```
