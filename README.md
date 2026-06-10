# ll

every `ll` value is a total monadic function `ll -> ll`.
1 is the identity function, 0 is the constant function of 1,
numbers act on functions by iteration (church numerals),
and a list represents an exponential tower.
- `(0 x) = 1`
- `(1 x) = (x) = x`
- `(f x y) = ((f x) y)`
- `(2 f x) = (f (f x))`
- `(2 3 4) = 262144`
- `(* i i) = -1`
- `(log -1) = (* i pi)`
- `((/ 1 2) -1) = i`

the language is built around three special forms plus reader operators,
prefix and infix. the special forms are:
- `\` lam (with a single operand, quote)
- `?` cond
- `:` letrec*/sequence

a prefix operator char desugars its next datum(s) to a form; the table is
`dict['operators]`, extensible at runtime. seven ship:
- `$` sat (saturating size/magnitude -- a count on containers, 0 when empty or <= 0)
- `#` hasht (hash table literal `#(k v ..)`; a scalar boxes: `#x` = `#(() x)`)
- `'` quote (literally the one-operand lambda)
- `!` bang (negation; `!!$x` is x's truth bit)
- `.` dot (printing identity)
- `@` tup (array constructor)
- `` ` `` quasiquote

infix operators are all-punct symbols in `dict['infix]`, right-associative,
reading as plain symbols with no left operand -- `(1 + 2)`, `'+`, and `(+)` all work:
- `+ - * / = < <= > >= | &` dyadic
- `?` ternary (the cond form infix: `(t ? a b)`)
- `%` mod
- `<-` pin, `->` peek (the collection accessors: `(t <- k v)`, `(t -> k d)`)

`,` unquote, `,@` splice, and `~` wave (complex constructor / conjugate) stay
reader digraphs. the full spec is [CLAUDE.md](CLAUDE.md) -- the root test file
CLAUDE.l in a code fence, so the spec stays green.

## code examples

a few identities (each evaluates to 1; euler's identity is bit-exact read
through the principal log -- atan2(0,-1) is pi by IEEE fiat -- and sqrt
takes the principal root, so it is total on negatives)

```
(1 = (\ x x)) (0 = (\ _ 1))
(8 = (3 2)) (65536 = (2 2 2 2))
(-1 = i * i) ((log -1) = i * pi)
(i = ((/ 1 2) -1)) (5.0 = (abs ~(3 4)))
(12 = (3 (+ 1) 9)) (2.0 = ((/ 1 2) 4))
("ababab" = "ab" * 3) ('(1 2 1 2) = '(1 2) * 2)
(!"" = 0 = $"")
```

hello world

```
."hello world\n"
```

fizzbuzz

```
(100
 (\ n (: f (? (n % 3) "" "fizz")
         b (? (n % 5) "" "buzz")
         _ .(? ($f | $b) (f + b) n)
         _ ."\n"
       (n + 1)))
 1)
```

## build & test

`make` builds the host binary `out/host/ll`. `make test` is the commit gate:
it runs the test corpus through both `ll` and the self-hosted bootstrap `ll0`.
`make test_all` adds the freestanding kernel (qemu) and tool diffs.
