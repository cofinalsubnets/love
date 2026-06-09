# g

every `g` value is a total monadic function `g -> g`.
1 is the identity function, 0 is the constant function of 1,
numbers act on functions by iteration (church numerals),
and a list represents an exponential tower.
- `(0 x) = 1`
- `(1 x) = (x) = x`
- `(f x y) = ((f x) y)`
- `(2 f x) = (f (f x))`
- `(2 3 4) = 262144`
- `(* i pi e) = -1`
the language is built around three special forms plus prefix operators (sigils).
the special forms are:
- `:` let
- `?` cond
- `\` lam
the sigils are:
- `#` pin (saturating projection to non-negative fixnum; length operator on list/string/map)
- `!` bang (1 when pin is 0 else 0; `!!#` = truth value)
- `.` dot (print)
- `'` quote (monadic case of lam)
- `~` wave (complex literal / conjugate)
- `@` at (array literal)
- `%` hash (map literal)
- `$` cash (gensym literal)

## code examples

euler's identity
```
(= -1 (* i pi e))
```

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

