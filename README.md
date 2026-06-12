# love

every love expression has a value.
stackless operation, all recursion on heap, overflow safe.
every quote below evals to 1. try them in the repl :)
(or in your browser: [index.html](index.html) runs the same
image compiled to wasm -- nothing mocked.)

- `0 x = 1`
- `1 x = x`
- `(x) = x`
- `f x y = (f x) y`
- `2 f x = f (f x)`
- `65536 = (2 2 2 2)`
- `-1 = i * i`
- `(log -1) = i * pi`
- `i = (1 / 2) -1`
- `1 = (i love you)`

that last one holds because `i` is the identity count, an unbound name
reads as the unit, and the unit applies as the constant. love stays out
of the book, so the sentence stays true -- solve for love and you get 1,
but only the help that answers every absence with one can witness it:
bind love and the sentence breaks.


## love

basically, love is a synthesis of lisp haskell and apl over c
where every value is a total function of one argument and every
action is as defined as generically efficient as possible.

- numeric tower with shaped array broadcasting
- lambdas, macros, closures, multitasking
- freestanding bare metal kernel build
- public domain portable C with zero dependencies
- claude can write love like a champ no cap

love has three special forms plus "operators". the forms are
- `\` lambda
- `?` cond
- `:` let

the reader is structural and knows no operator tables -- just tokens, parens,
strings, and the value surface:
- `'` quote (desugars to one-operand lambda)
- `` ` `` quasiquote, `,` unquote, `,@` splice
- `@` at (array literal)
- `#` hash (hash/box literal)
- `~` wave (complex literal `~(re im)`; a bare `~x` lifts a real, conjugates a complex)

operator sigils are plain symbols until the compiler factors them against the
one `operators` table (per-form extensible: pin an entry and the next form
compiles with it):
- at one: `$` sat (the value's net -- its content measure -- clamped once,
  `max(0, ceil)`; `!!$` is the iverson bracket, the truth bit `?` dispatches on),
  `!` nilp (not), `.` dot (print and return item)
- at two: `+ - * / % = < <= > >= | &`
- at three: `?` (the cond form infix: `(t ? a b)`)
- aliases: `<-` pin, `->` peep (the collection accessors: `(t <- k v)`, `(t -> k d)`)
- factorization is greedy, longest prefix first: `!=` is `!` of `=`, `!!`
  double-negates, and a token that doesn't factor stays one symbol (`&&`, `>>=`)

and the valence law: every operator is two operators -- GLUED IS MONADIC,
SPACED IS DYADIC. head position never fuses, so calls, sections and minified
source read as ever (`(+ 1 2)`, `(1 +)`).
- `<x >x` cap and cbp; `<>x ><x <<x >>x` the compounds, by factorization
- `+l` the net -- the true sum, APL's `+/` -- and `*l` the product
- `|x` abs, `-x` neg (`+` and `-` fuse only to `( ' " @ ~ #`, so `-3` stays a
  number and `-x` a kebab name), `/x` reciprocal, `%x` frac, `?x` the iverson bracket
- `$x !x .x` as ever: sat, not, print
- a glued sigil binds tightest: `$"ab" + 2` is `(+ ($ "ab") 2)`, i.e. 197
the numerals still carry the power family (`-1 x = 1 / x`, `(1 / 2) x =
sqrt x`, `n x = x ** n`); words cover the rest (`abs int gcd // << >> ^
sin cos log pow`), and general folds stay words: `(foldl f z l)`.

pure lisp is the lassoc subset: `?` is still the cond form at the head of a
list, bare punct symbols escape in parens -- `(+)` is `+` as a value -- and
quote interiors are data (operators under `'` stay plain symbols), so these
are true too:
- `12 = (foldl (+) 0 '(3 4 5))`
- `24 = (foldl (*) 1 '(1 2 3 4))`
- `'(1 2 3) = (sort '(3 1 2))`
- `'(2 3 4) = (map (+ 1) '(1 2 3))`
- `'(0 1 2) = (jot 3)`
- `10 = +(jot 5)`

the full spec
is [CLAUDE.md](CLAUDE.md) -- the root test file CLAUDE.l in a code fence, so
the spec stays green.


### hello world

```
."hello world\n"
```

### fizzbuzz
```
(100
 (\ n (: f (? (n % 3) "" "fizz")
         b (? (n % 5) "" "buzz")
         _ .(? ($f | $b) (f + b) n)
         _ ."\n"
       (n + 1)))
 1)
```

### build test run
- `make` build + test
- `make repl` interactive shell
- `make test_all` adds the freestanding kernel (qemu) + tool diffs
- `make wasm` build the browser image (wasm/love.js, used by index.html)
- `out/host/ai` is a symlink to `love` -- ai is love in the filesystem too
- `out/host/love file.l` run a file
- `echo .ev | love` print the compiler

that last one is not a joke. `.` prints, `ev` is the self-hosted evaluator,
and what comes out is the lambda the compiler compiled itself into -- a couple
kilobytes of the whole back end.

the shell survives its mistakes: with no help of your own installed it
provides one, so any condition prints `# a b` -- `# missing undefined-name`,
`# apcap 3000000` -- answers the zero point, and the session keeps going. multiline
entry continues while a shape is open; enter cashes any complete buffer;
history is a normal shell's. scripts and files stay helpless (terminal),
per the law.

### under the hood
- one word per value: a fixnum is a tagged odd word, anything else is a heap
  object whose first word is its hot -- a live external reference, the wire out
  of the heap to the ap that runs it. the vm is tail-threaded -- aps jump,
  never return -- over a two-space copying heap; `make vmret` proves the
  no-return claim by disassembling the binary.
- every operation is generic, dispatched on a value's kind through NxN tables
  (`+` `*` apply); the kind enum is the type lattice, the total order over all
  values is the enum order, and the lattice is literally the diagonal of the
  dispatch tables. `sort` is one C comparison per pair -- the total order is
  the comparator.
- no interpreter state lives outside the heap: the book (an ordinary love
  hash) carries the globals, macros, the operators table, the help function
  and the rng; C finds its own hooks by name, allocation-free. the egg pulls
  every compiler-internal name -- the book itself included -- before the
  image is born. a name not in the book is missing: reading one is a
  call for help, and helpless it reads the zero point, a nameless unit.
- the compiler is written in love. at build time the evaluator sits on the egg
  (the quoted compiler source) twice -- the C bootstrap compiles the compiler,
  which recompiles itself -- and the hatchling bakes into the binary; `born`
  records the hatch time. the same image runs on linux, bare metal
  (x86_64/aarch64 via limine), and wasm.
- status rides the two pointer tag bits: scare (something is wrong) and more
  (the reader wants more); eof = more|scare. a global `help` function receives
  every raise as `(help s a b)`.
- `=` is exact, so e^(i*pi) honestly misses -1 by ~1e-16 -- but the principal
  log is exact (`(log -1) = i * pi`, since atan2(0,-1) is pi by IEEE fiat),
  and sqrt factors its angle through sinpi/cospi, so `(1 / 2) -1 = i` on the
  nose.
- functions compare by alpha-equivalence of their source, and the numerals
  bridge: `1 = (\ x x)`, `0 = (\ _ 1)`.
