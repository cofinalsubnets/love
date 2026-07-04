# 🌑 ai

ai is kind of like `ai = (ml + apl) * (lisp / C)`.
every value in ai is a total function, and (almost) every
expression has a value. all recursion is on heap and any
 recursive operator may be iterated by non-negative integers
(green charms), which is their function action. consequently
the value of a numeric list under the left-associative lisp
eval function corresponds to a reversed exponential tower.
this refinement forms the ML part of `ml + apl`. the APL
part is a transparent right-associative superset that
interprets sigils (all-punctuation symbols) as infix or
prefix operators according to placement. the two forms mix
freely: infix operators take the lisp meaning in function
position, and infix can be converted to left-associative by
wrapping the sigil in parens, eg.  `3 = ((+) 1 2)`.

in terms of implementation, `lisp : software :: C : hardware`.
C gives random memory access via pointer arithmetic and direct
access to hardware. `lisp` is the software facing basement,
which you could factor as `ml * scheme` left-associative
applicative curried untyped lambda calculus, but applicative order
may vary in general. this is internally sound because every operator
is total and every thread cooperatively yields control regardless of
user program behavior. a uniform global mechanism exists for handling
conditions such as OOM.

features
- numeric tower with shaped array broadcasting
- lambdas, macros, closures, multitasking
- freestanding bare metal kernel build
- free portable C with zero dependencies
- self-hosting compiler written in ai

ai has three special forms plus "operators". the forms are
- `\` lambda
- `?` cond
- `:` let

the reader is structural and knows no operator tables -- just tokens, parens,
strings, and the value surface:
- `'` quote (desugars to one-operand lambda)
- `` ` `` list (the element-eval ctor: every element is evaluated, so quote the literal positions)
- `@` at (array literal)
- `#` hash (hash/box literal)
- `~` twin (twin-gem/complex literal `~(re im)`; a bare `~x` lifts a gem, conjugates a twin gem)

operator sigils are plain symbols until the compiler factors them against the
one `operators` table (per-form extensible: pin an entry and the next form
compiles with it):
- at one: `$` sat (the value's net -- its content measure -- clamped once,
  `max(0, ceil)`; `!!$` is the iverson bracket, the truth bit `?` dispatches on),
  `!` nil? (not), `.` dot (print and return item)
- at two: `+ - * / % = < <= > >= | &`
- at three: `?` (the cond form infix: `(t ? a b)`)
- aliases: `<-` pin, `->` peep (the collection accessors: `(t <- k v)`, `(t -> k d)`)
- factorization is greedy, longest prefix first: `!=` is `!` of `=`, `!!`
  double-negates, and a token that doesn't factor stays one symbol (`&&`, `>>=`)

and the valence law: every operator is two operators -- GLUED IS MONADIC,
SPACED IS DYADIC. head position never fuses, so calls, sections and minified
source read as ever (`(+ 1 2)`, `(1 +)`).
- `<x >x` cap and cup; `<>x ><x <<x >>x` the compounds, by factorization
- `+l` the net -- the true sum, APL's `+/` -- and `*l` the product
- `|x` abs, `-x` neg (`+` and `-` fuse only to `( ' " @ ~ #`, so `-3` stays a
  number and `-x` a kebab name), `/x` reciprocal, `%x` frac, `?x` the iverson bracket
- `$x !x .x` as ever: sat, not, print
- a glued sigil binds tightest: `$"ab" + 2` is `(+ ($ "ab") 2)`, i.e. 197
the numerals still carry the power family (`-1 x = 1 / x`, `(1 / 2) x =
sqrt x`, `n x = x ** n`); words cover the rest (`abs int gcd // << >> ^
sine cosine log`), and general folds stay words: `(foldl f z l)`.

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
- `5 = () + 5` and `5 = () * 5` -- `()` is the **unit**, the shared identity of `+` and `*` in every lane; `0` and `1` are its two faces (the additive identity it shows in `+`, the multiplicative in `*`). it rides through every other arithmetic operator the same way, either side: `5 = 5 - ()` and `5 = () - 5` (the do-nothing operand -- the op never happens)
- `'(0 0 1 3 6 10 15 21) = ((flip compose jot (map (compose sat jot))) 8)`

that last is the triangular numbers, point-free: `jot` lays out `0 .. n-1`,
`sat` sums each prefix to its charm, and `flip compose` feeds the one into the
other (the nth is the net of `0 .. n-1`, so it opens on the floor twice).

the spec is [test/spec.l](test/spec.l) -- the reference and the test in one,
each section stating its laws in a comment over the asserts that prove them, a
real test in the corpus, so every claim stays green. the narrative -- how to
work here, the traps, the architecture -- is [CLAUDE.md](CLAUDE.md).


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
- `make wasm` build the browser image (wasm/ai.js, used by index.html) -- rebuild + stage by hand
- `out/host/ai` is the binary -- ai is the word now (it was `love` once)
- `out/host/ai file.l` run a file
- `echo .ev | ai` print the compiler

that last one is not a joke. `.` prints, `ev` is the self-hosted evaluator,
and what comes out is the lambda the compiler compiled itself into -- about
eight kilobytes of the whole back end.

the shell survives its mistakes: with no help of your own installed it
provides one, so any condition prints `;; a b` -- `;; missing undefined-name`,
`;; apcap 3000000` -- answers the zero point, and the session keeps going. multiline
entry continues while a shape is open; enter cashes any complete buffer;
history is a normal shell's. scripts and files stay helpless (terminal),
per the law.

### cook

ai includes a somewhat GNU-compatible `make` clone called `cook` written in pure
ai and bootstrapped through normal `make`. `cook` accepts either the traditional
`Makefile` format or its own `Cookfile` DSL.

```
(recipe "hello" '("hello.o" "greet.o")
        '(("cc" "-o" "hello" "hello.o" "greet.o")))
(recipe 'clean '() '(("rm" "-f" "hello" "hello.o" "greet.o")))
(cook (ticket 0))
```

each card is `(recipe item ingredients steps)`: an item is a filename or a
phony symbol, ingredients are the items it needs first, steps are argv lists
(run as subprocesses) or thunks. item ages come from `stat` through the host
`run` nif, so a phony symbol is ageless and always cooks. the whole kitchen:
cook an item -- check its date, prep its ingredients, follow the recipe's
steps, record what shipped, from the cards; the ticket names what to make
(default: the first card, the standing check).

- `ai -l apps/cook/cook.l [ticket]` -- cook a ticket (cook discovers the build file:
  a `Makefile` if present, else a `Cookfile`, else a legacy `Cards.l`; name one
  explicitly to override)
- cook reads a real **Makefile** directly -- a reasonably GNU-make-compatible
  import: `$(VAR)` expansion and substitution refs, the common functions
  (`shell`, `wildcard`, `dir`, `patsubst`, `filter`, ...), `ifeq`/`ifdef`
  conditionals, `include`, `:= ?= +=`, pattern + static-pattern rules,
  order-only prereqs, and the `$@ $< $^ $*` automatics
- `make -f cook.mk test` -- the make-shaped stub: bootstraps the binary, then
  forwards to cook (it names the `Cookfile` explicitly)
- [apps/cook/example/](apps/cook/example/) is a worked C build;
  [apps/cook/cooktest.l](apps/cook/cooktest.l) (`make test_cook`) tests the importer

ai builds itself this way too: `ai -l apps/cook/cook.l Makefile host` runs g's own
Makefile from scratch, and the cook-built binary passes the whole corpus. cook
runs *on* ai, so you need an ai to begin; the [apps/cook/Cookfile](apps/cook/Cookfile) is the
curated cross-cutting verbs (`test clean valg vmret bench install`).

### the crew

cook is one of the **inle crew** -- a small crew of real programs that ride on
**inle**, the freestanding ai kernel ([a ship in port](port/inle/)). each is a
tiny ai layer over a handful of host nifs; on a hosted system they `make install`
onto PATH beside `ai`.

- **ain** -- a netcat clone in ~70 lines: `ain host
  port` is a TCP client, `ain -l port` a server, bytes pumping both ways at
  once. it is the "real apps day one" demo, and the shape the cooperative scheduler
  was built for: two spawned pump loops, each parked in a port read on a different
  fd, interleave with no select loop. socket nifs in [host/net.c](host/net.c), the
  program in [tools/ain.l](tools/ain.l).
- **bao** -- the interactive shell as a loadable lib (`ai -l bao`, or the installed
  `bao`): raw `ai` shrinks to a bare read/eval/write filter, and bao is the editor +
  history + fault-face on top, doubling as a pty wrapper (one editor, the condition
  system). [ai/bao.l](ai/bao.l) + [host/pty.c](host/pty.c).
- **inle** -- the ship itself: the freestanding kernel grown a NIC and a
  self-driving agent loop, booting on bare metal with no OS, perceiving the network,
  running the language over UDP -- a bare-metal network REPL. `make kernel INLE=1`
  builds the bootable image. [port/inle/](port/inle/).

### under the hood
- one word per value: a fixnum is a tagged odd word, anything else is a heap
  object whose first word is its hot -- a live external reference, the wire out
  of the heap to the ap that runs it. the vm is tail-threaded -- aps jump,
  never return -- over a two-space copying heap; `make vmret` proves the
  no-return claim by disassembling the binary.
- every operation is generic, dispatched on a value's kind through NxN tables
  (`+` `*` apply); the kind enum is the type lattice, the total order over all
  values is the enum order, and the lattice is literally the diagonal of the
  dispatch tables. `sort` is one C comparison per chain -- the total order is
  the comparator.
- no interpreter state lives outside the heap: the book (an ordinary ai
  hash) carries the globals, macros, the operators table, the help function
  and the rng; C finds its own hooks by name, allocation-free. the egg pulls
  every compiler-internal name -- the book itself included -- before the
  image is born. a name not in the book is missing: reading one is a
  call for help, and helpless it reads the zero point, a nameless unit.
- the compiler is written in ai. at build time the evaluator sits on the egg
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
- functions compare by alpha-equivalence of their source, and a partial
  application equals its literal lambda: `(adder 5) = (\ x (+ x 5))`. numbers
  never equal closures -- numerals *act* as their lambdas (`(1 x) = x`), but
  `=` stays representation-strict.

### credits

- the web page is set in 8x16 DOS/V bitmap fonts from the [Oldschool PC Font
  Pack](https://int10h.org/oldschool-pc-fonts/) by VileR, used under
  [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/): **DOS/V TWN16**
  for the body text, **DOS/V re. PRC16** for the live repl.
