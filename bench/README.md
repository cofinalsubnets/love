# bench/ — gwen benchmark harness

Times a small set of numeric and list-processing workloads written in **gwen**,
**python**, **ruby**, **chez scheme**, **sbcl** (common lisp), **node** (js) and
**lua**, and prints a side-by-side comparison. Each workload is implemented once
per language, computing an identical checksum so the runs are verified
equivalent (the `ok` column).

## Running

From the repo root:

```sh
make bench
```

or from this directory:

```sh
make            # run every bench in all available languages -> table
make BENCHES=fib            # one bench
make BENCHES="sum primes"   # a subset
make gwen                   # one language only
make python                 # also: ruby / chez / sbcl / node / lua
make raw                    # the raw result lines, unformatted
make clean                  # remove bench/b/
```

Each non-gwen interpreter (`python3`, `ruby`, `chez`, `sbcl`, `node`, `lua`) is
auto-skipped if not on `PATH`, and is skipped for any individual bench it has no
implementation file for; its column then drops out of the table. gwen always
runs against `../b/host/gl` (built on demand via the root Makefile).

Example output:

```
bench           gwen ms/it  python ms/it    ruby ms/it    chez ms/it    sbcl ms/it    node ms/it     lua ms/it   ok
-------------------------------------------------------------------------------------------------------------------
fib                42.3750       87.1958       75.8413        5.6875       10.9072        7.4162       43.6644  yes
tak                 8.5625       10.0101        9.8063        0.6211        4.0785        0.9480        5.8184  yes
sum                 7.8125        2.6841        2.2309        0.4961        0.6973        0.7629        0.9479  yes
mapfilter           1.0820        0.8505        0.9343        0.1108        0.0945        0.2110        0.2066  yes
reverse             1.0508        0.0658        0.0159        0.0480        0.0392        0.0245        0.3441  yes
primes             19.6875       23.7931       19.0537        1.7266        4.9692        0.7996        7.8247  yes
bell               67.2500       54.5637      120.7780       66.0000       51.7548       28.6885             -  yes
```

Each `ms/it` column is that language's per-iteration time; lower is faster. `ok`
confirms every present language's checksum for the bench agrees. `bell` has no
`-` lua entry because lua has no arbitrary-precision integers (see below).

## How timing works

Every language self-times only the inner workload, so interpreter startup is
excluded from the measurement. The harness auto-scales the repetition count —
doubling until the run clears a 200 ms floor — then reports `(reps, ms)`. The
report divides `ms / reps` for a per-iteration time, so the chosen rep count
cancels out and benches of very different cost stay comparable. gwen's clock has
1 ms resolution (`(clock 0)`), which the 200 ms floor keeps under ~0.5 % error.

## Benchmarks

| bench       | kind    | workload                                                   |
|-------------|---------|------------------------------------------------------------|
| `fib`       | numeric | naive recursive `fib(30)` — call + integer-arithmetic cost |
| `tak`       | numeric | Takeuchi `tak(22,12,6)` — deep non-tail recursion          |
| `sum`       | list    | build `1..100000`, fold-sum it                             |
| `mapfilter` | list    | square 10000 elems, keep evens, sum                        |
| `reverse`   | list    | reverse a 20000-element list                               |
| `primes`    | numeric | count primes below 30000 by trial division                |
| `bell`      | bignum  | Bell numbers in base 36 to 280 digits (port of `test/bell.g`) |
| `strcat`    | string  | build a 4000-char string by single-char concatenation, then hash it |
| `strscan`   | string  | rolling-hash scan over a fixed 20000-char string (read path) |

`bell` is the heavy one: it leans on the whole bignum tower (`*`/`/`/`%` over numbers
hundreds of digits long) and rebuilds its memo tables each iteration so every rep recomputes
from scratch. It's the most evaluator-neutral comparison here — every language does identical
big-integer arithmetic (node via `BigInt`, the lisps/python/ruby natively). **lua is omitted**:
its numbers are 64-bit int/double, so it has no `bell.lua` and its column shows `-`.

The two string benches split the write and read paths. `strcat` builds a string
one character at a time with each language's concatenation operator (gwen `scat`,
python/lua/lisp string-append, etc.) — an O(n²) build that measures how that
operator copies, so it favours languages with mutable/rope-backed strings.
`strscan` times only a linear rolling hash over a string built once outside the
loop, isolating the byte-read path (gwen `get`/`len`). Both fold the same
polynomial hash `h = (h*31 + byte) mod 1e9+7`; taking it mod a prime keeps the
checksum a 64-bit fixnum, so it is identical across every language (lua included)
and doubles as the `ok` cross-check.

The list benches compare *idiomatic* implementations: gwen and the lisps walk
cons-cell linked lists, while python/ruby/node/lua use native dynamic arrays and
built-ins — so `sum`/`reverse` largely measure linked lists vs. C array
primitives, not just the language. The numeric/recursion benches (`fib`, `tak`,
`primes`) are the closest apples-to-apples comparison of the evaluators
themselves.

## Layout

```
bench.g          gwen harness — iota/iota1 + the (bench name work) timer
lib/bench.py     python harness — bench(name, work)
lib/bench.rb     ruby harness   — bench(name) { work }
lib/bench.ss     chez harness   — (bench name work)
lib/bench.lisp   sbcl harness   — (bench name work)
lib/bench.js     node harness   — bench(name, work)  [require("../lib/bench")]
lib/bench.lua    lua harness    — bench(name, work)
benches/<x>.{g,py,rb,ss,lisp,js,lua}   each language's implementation of a workload
report.awk       formats the raw result lines into the table
Makefile         orchestration
```

## Adding a benchmark

1. Write `benches/<name>.{g,py,rb,ss,lisp,js,lua}` (skip any language whose
   value model can't express the workload — as lua skips `bell`; a missing file
   just drops that cell). Each ends in a single `bench("<name>", …)` call whose
   thunk returns a deterministic checksum identical across every language (the
   `ok` column checks this).
   - gwen: `(bench "<name>" (\ _ <expr>))` — the thunk takes one ignored arg
     since gwen has no nullary calls. Shared helpers (`iota`, `iota1`, `foldl`,
     `map`, `filter`, `rev`, …) are already in scope.
   - python: `bench("<name>", lambda: <expr>)`
   - ruby: `bench("<name>") { <expr> }`
   - chez: `(load "lib/bench.ss")` then `(bench "<name>" (lambda () <expr>))`
   - sbcl: `(load "lib/bench.lisp")` then `(bench "<name>" (lambda () <expr>))`
   - node: `const { bench } = require("../lib/bench");` then
     `bench("<name>", () => <expr>)`
   - lua: the two-line `package.path`/`require("bench")` preamble (copy it from
     any `benches/*.lua`), then `bench("<name>", function() return <expr> end)`
2. Add `<name>` to `BENCHES` in the `Makefile` (controls display order).

Each gwen bench is concatenated after `bench.g` before being piped to `gl`,
exactly like the `test/` corpus — a top-level `:` form with no trailing body
leaks its bindings into global scope, so the harness names are visible.
