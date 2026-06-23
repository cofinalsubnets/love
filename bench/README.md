# bench/ — ai benchmark harness

Times a small set of numeric and list-processing workloads across **ai** and one
fast implementation of each comparison language, printing a side-by-side table.
Each workload is implemented once per language, computing an identical checksum so
the runs are verified equivalent (the `ok` column). **One implementation per
language** — the fastest readily available — so the columns compare *languages*,
not JIT-vs-bytecode variants of one. The lineup:

- **ai** — the subject.
- **lisps** — `chez` (Scheme, compiled), `sbcl` (Common Lisp, native compiler),
  `clojure` (JVM).
- **dynamic** — `pypy` (Python), `ruby`, `node` (JS, V8), `luajit` (Lua, JIT),
  `elixir` (BEAM), `julia` (LLVM JIT).
- **static / compiled** — `go`, `java` (JVM, JIT), `haskell` (GHC `-O2`),
  `rust` (`rustc -O`).

The interpreted languages run their source directly; the compiled ones
(`go`/`java`/`haskell`/`rust`) are built to a scratch dir first and then run — the
compile is **not** timed (each bench self-times only its inner loop), so every
column reflects steady-state execution. `BENCH_LANG` sets each column's label; the
per-language timing primitive lives in `lib/bench.*` (and `lib/Bench.*` for Java
and Haskell). One implementation per extension now, so a column maps to its file:
`.ss` chez, `.lisp` sbcl, `.py` pypy, `.js` node, `.lua` luajit, plus `.clj`/`.exs`/
`.jl`/`.rb`/`.go`/`.java`/`.hs`/`.rs`.

## Running

```sh
make bench          # from the repo root, or `make` here: the default column set
                    #   (ai pypy ruby node luajit julia go rust)
make all            # every language present on this machine (a wide table)
make chez           # one language, shown alongside ai for contrast
make pypy           # ... any language name works as a target
make BENCHES=fib    # restrict the workloads (then `make clean` to refresh files)
make TIMEOUT=60 …   # per-bench wall-clock cutoff in seconds (default 30)
make raw            # the raw result lines, unformatted
make html           # write bench.html — a self-contained results page (below)
make clean          # remove out/bench/
```

**Results are cached per language.** Each language writes its lines to
`out/bench/<lang>.txt`, and that file depends on the language's bench sources (and,
for ai, the `ai` binary). The user-facing targets just *pretty-print* those
files — a bench is only (re)run when its result file is missing or older than the
sources, so `make bench` reformats instantly once the files exist. Touch a source
or `make clean` to force a re-run. The per-language run logic (extension,
interpreter command, `BENCH_LANG`) lives in `run.sh`.

A language whose interpreter/compiler isn't on `PATH` is **automatically
omitted**; so is any bench a language has no implementation for (e.g.
`luajit`/`rust` lack `bell` — no bignums in the Lua number model or the Rust
standard library) and, for the compiled languages, any bench that fails to build
(a compile error yields no output, so the cell drops exactly like a missing file).
Pairs known to exceed `TIMEOUT` can be listed in the Makefile's `SKIP` variable
(empty by default) and dropped up front. Such cells just drop out of the table.
As benches run, `run.sh` prints a `  <lang> <bench>` tick per bench to stderr,
with a `(dropped: …)`/`(skipped: …)` note for any pre-skipped, timed-out, or
errored, so stdout stays clean for the table.

Example output (the real table is wide — one column per language; abridged slice):

```
bench         ai ms/it    node ms/it  luajit ms/it   julia ms/it     go ms/it    rust ms/it   ok
fib               9.0938      16.5169       9.7481       10.1085       7.3516       3.9450  yes
tak               1.2148       1.9992       1.6167        1.1960       0.8845       0.6857  yes
closure           7.2812       1.5767      27.1555        0.0151       0.0645       0.0295  yes
float             0.4258       0.2397       0.2674        0.2370       0.2684       0.2352  yes
bell            132.5000      55.8015            –      110.6090      50.8098            –  yes
```

Each `ms/it` column is that language's per-iteration time; lower is faster. `ok`
confirms every present language's checksum for the bench agrees. Things to read out
of it: the **static/compiled** languages (`rust`, `go`, `java`) lead the recursive
arithmetic (`fib`/`tak`); the **`closure`/`sum`/`mapfilter`** columns are where
optimizing backends fold pure loops away — `julia`, `rust`, `go` and `luajit`'s JIT
drive them toward zero (see the `closure` note below on why this is honest only once
the benches defeat *compile-time* evaluation); `bell` shows `–` for `luajit`/`rust`
(no bignums); and ai's native **glaze** keeps it competitive on the benches it
compiles (`fib`/`float`/`strscan`/`primes`/`deforest`, plus `strcat` whose O(n²)
build it rebuilds to an O(n) buffer) and posts ~0 on `polysum`, which it closes to
O(1). Run `make all` for the full table, or `make html` for an interactive one.

## How timing works

Every language self-times only the inner workload, so interpreter startup is
excluded from the measurement. The harness auto-scales the repetition count —
doubling until the run clears a 200 ms floor — then reports `(reps, ms)`. The
report divides `ms / reps` for a per-iteration time, so the chosen rep count
cancels out and benches of very different cost stay comparable. ai's clock has
1 ms resolution (`(clock 0)`), which the 200 ms floor keeps under ~0.5 % error.

## Results page

`make html` writes **`bench.html`** — a self-contained page (data embedded, no
server needed) showing the same per-iteration table with the fastest cell per
bench highlighted and the `ai` axis tinted. A **transpose** button swaps benches
and languages between the rows and columns, and the initial orientation is chosen
from the viewport (portrait drops languages down the side). It's regenerated from
the cached `out/bench/*.txt`, so run `make all` first for a full table; the full
roster appears as columns, and a language that produced no rows (toolchain absent
or broken) shows a dotted column.

## Benchmarks

| bench       | kind    | workload                                                   |
|-------------|---------|------------------------------------------------------------|
| `fib`       | numeric | naive recursive `fib(30)` — call + integer-arithmetic cost |
| `tak`       | numeric | Takeuchi `tak(22,12,6)` — deep non-tail recursion          |
| `sum`       | list    | build `1..100000`, fold-sum it                             |
| `mapfilter` | list    | square 10000 elems, keep evens, sum                        |
| `deforest`  | list    | sum `(k² mod p)` of the odds in `[0,N)` — map/filter/fold FUSED to one loop (the `%` keeps it O(n)) |
| `polysum`   | list    | sum `k²` of the odds in `[0,N)` — same shape, pure-polynomial body, CLOSED to O(1) by the loop-closer |
| `primes`    | numeric | count primes below 30000 by trial division                |
| `bell`      | bignum  | Bell numbers in base 36 to 280 digits (port of `test/bell.l`) |
| `strcat`    | string  | build a 4000-char string by single-char concatenation, then hash it — ai glazes the O(n²) accumulator loop to an O(n) `pot` buffer |
| `strscan`   | string  | rolling-hash scan over a fixed 20000-char string (read path) |
| `hash`      | table   | mutable hash table: 10000 sparse-int-keyed insert / lookup / update ops |
| `sort`      | sort    | merge/quick-sort 5000 LCG-random ints, hash the sorted order |
| `tree`      | alloc   | build + traverse a depth-16 binary tree (small-aggregate alloc / GC churn) |
| `float`     | float   | mandelbrot escape counts over a 64×64 grid (pure f64, integer checksum) |
| `closure`   | closure | build & apply 2 closures per iter over 100000 iters (higher-order stress) |

`bell` is the heavy one: it leans on the whole bignum tower (`*`/`/`/`%` over numbers
hundreds of digits long) and rebuilds its memo tables each iteration so every rep recomputes
from scratch. It's the most evaluator-neutral comparison here — every language does identical
big-integer arithmetic (node and julia via `BigInt`, go via `math/big`, java via `BigInteger`,
the lisps/python/ruby/haskell natively). **luajit and rust are omitted**: Lua's number model is
a 64-bit float and the Rust standard library has no arbitrary-precision integer (and these
single-file benches pull in no crates), so there is no `bell.lua`/`bell.rs` and the cell shows
`–`. The memo also shows a dialect difference: most implementations use a mutable hashtable,
but `elixir` (functional) threads an immutable map through the loop — same result, same checksum.

`hash` is the mutable-hash-table bench: into a fresh table it inserts N=10000
integer keys, sum-looks-them-up, does a read-modify-write update pass, then
sum-looks-up again (checksum = N²). Keys are sparse (stride 97) on purpose, so
luajit/pypy can't service them from a contiguous-integer *array* fast-path and
must actually hash. Each language uses its native mutable table — ai `table`/
`put`/`get`, chez/sbcl hashtables, JS `Map`, luajit tables, julia `Dict`, go/rust
hash maps, java's `HashMap` (and `clojure` via the same interop). The functional
`elixir` has no mutable table, so it drops the `hash` cell.

`sort` builds 5000 ints from a MINSTD LCG (`x = 16807·x mod 2³¹−1`, chosen so the
multiply stays under 2⁵³ and every language — doubles included — produces the
identical sequence), sorts ascending, and checksums an order-dependent rolling
hash of the result (so the checksum verifies the *ordering*, not just the
multiset). ai uses the prel's `sort` (a list merge sort added for this);
every other dialect uses its built-in sort, so the column reads as library sort
quality. `tree` is the classic binary-trees alloc/GC stress: build a perfect
depth-16 tree (2¹⁶−1 nodes, leaves nil) and traverse counting nodes — it churns
small two-field aggregates (cons pairs / 2-tuples / `[ai r]`) and exercises the
collector more than any other bench. `float` is mandelbrot escape counts over a
64×64 grid: pure f64 `+`/`−`/`*`/`<=` (no transcendentals) over exactly
representable constants, with an integer checksum, so it is bit-identical
everywhere — including ai's *boxed*-float path, which is the point (it's the
only bench that touches floats; `sbcl` needs `d0` double-float literals to agree).
`closure` stresses ai's defining feature — every value a curried unary function:
per iteration it builds `(adder i)` and `(twice (adder i))` and applies them, so it
allocates and calls two closures 100000 times.

A caution the `closure` bench taught us: an **optimizing backend can evaluate the
whole loop at compile time.** Its inputs are compile-time constants and
`twice (adder i) i` reduces to `3i`, so LLVM's scalar-evolution recognizes the
series `Σ 3i`, closes it to a formula, and folds the bench to a single literal — a
meaningless O(1) "result" (we saw 0.05 µs/it, ~150,000× too fast). Julia (LLVM JIT)
and Rust (`rustc -O`) both do it, and constant-argument recursion folds the same way
(`fib(30)`/`tak(22,12,6)` collapse to a literal → an infinite rep-doubling hang). The
fix is to make the loop's inputs opaque to the optimizer — Julia iterates a prebuilt
vector instead of a literal range, Rust wraps inputs in `std::hint::black_box` — so
the real O(n) loop must run. The checksum is unchanged; only the timing becomes
honest. (This is where partial evaluation shades into closed-form recurrence solving,
a backend doing it uninvited.)

`deforest` and `polysum` are the two sides of that coin, deliberately. Both are the
same odd-squares map/filter/fold pipeline. **`deforest`** has a `% p` in the body,
which keeps it non-polynomial: ai's glaze FUSES the pipeline to one native counted
loop (no intermediate lists) but cannot close it, so every language runs an honest
O(n) loop — it measures the *fusion* a functional pipeline needs to land at the
hand-written loop's cost. **`polysum`** drops the `%`, leaving a pure-polynomial body,
and ai's **loop-closer** collapses it to its closed form — Σ over the odds
reparametrized to `k=2j+1` and summed by finite differences — so ai runs O(1) while
everyone else runs O(n). That is the closure caution turned into a feature: a closed-
form recurrence solver invited *in*, and one that reaches the case LLVM's
scalar-evolution punts on (it gives up on the data-dependent odd filter; the
loop-closer changes variable and solves it). So ai's `polysum` cell is ~0 by design,
and the cross-language row reads honestly as "O(1) closed form vs. O(n) loop."

The two string benches split the write and read paths. `strcat` builds a string
one character at a time with each language's concatenation operator (pypy/luajit/
lisp string-append, etc.). Written naïvely as `s = s + c`, that is an O(n²) build —
each `+` copies the whole prefix — so it favours languages with mutable/rope-backed
strings. ai's glaze reads that *same* `(+ s c)` accumulator loop from source and
rewrites it to a threaded **`pot`** (the growable output sink): the immutable string
accumulator becomes a mutable buffer appended to in O(1) amortized, drained once at
the end, so the build drops to O(n) without touching the source (the output-side dual
of `deforest`'s pipeline fusion). With the rolling hash also glazed via the string
lane, ai's `strcat` lands ahead of luajit and ruby and near pypy/node. `strscan`
times only a linear rolling hash over a string built once outside the loop, isolating
the byte-read path (ai `get`/`len`). Both fold the same polynomial hash
`h = (h*31 + byte) mod 1e9+7`; taking it mod a prime keeps the checksum a 64-bit
fixnum, so it is identical across every language (luajit's floats included) and
doubles as the `ok` cross-check.

The list benches compare *idiomatic* implementations: ai and the lisps walk
cons-cell linked lists, while pypy/ruby/node/luajit use native dynamic arrays and
built-ins — so `sum`/`mapfilter` largely measure linked lists vs. C array
primitives, not just the language. The numeric/recursion benches (`fib`, `tak`,
`primes`), `closure`, and `float` are the closest apples-to-apples comparison of
the evaluators themselves; `float` in particular isolates the floating-point path
(ai boxes its floats, so it pays heap traffic the native-double languages do
not), and `closure` isolates closure allocation + application.

`deforest` is the deforestation showcase. It is the same square/keep/sum work as
`mapfilter`, but written as a genuine *list* pipeline read straight from source —
`(foldl + 0 (map sq (filter odd (jot N))))` — which under a plain evaluator
materializes three throwaway lists (the range, the odds, the squares). ai's
native glaze **fuses** the whole pipeline into one counted loop with no
intermediate allocation (the rewrite-level pass `defoliate` collapses the
map/filter into the fold and lowers `foldl`-over-`jot` to the same loop codegen
`fib`/`primes` use). Read the cross-language row **honestly**: it measures the
*abstraction cost of the functional-pipeline idiom*, not a fixed algorithm — each
column reflects how the implementation handles the intermediates (ai fuses them;
`luajit` has no `map`/`filter`, so its bench fuses by hand; `pypy`/`clojure` are
lazy — no intermediate lists, per-element overhead; `rust`'s iterator chain fuses
and vectorizes; `node`/`ruby`/the schemes allocate eagerly). The anchor is that
ai's deforested pipeline lands near `luajit`'s *hand-written loop* — the high-level
functional source costs what the loop costs. (The purest A/B is ai with the glaze on vs off;
we keep it always-on and watch the gate for regressions.)

## Layout

```
bench.l          ai harness — iota1 + the (bench name work) timer
lib/bench.py     python harness — bench(name, work)        [pypy]
lib/bench.rb     ruby harness   — bench(name) { work }
lib/bench.ss     chez harness   — (bench name work)
lib/bench.lisp   sbcl harness   — (bench name work)
lib/bench.clj    clojure harness
lib/bench.exs    elixir harness (BEAM monotonic clock; functional map memo)
lib/bench.js     node harness   — bench(name, work)
lib/bench.lua    luajit harness — bench(name, work)
lib/bench.jl     julia harness  — bench(name, work); warms the JIT, then times
lib/bench.go     go harness     — bench(name, func() int64)   [package main, no main]
lib/Bench.java   java harness   — Bench.bench(name, LongSupplier)
lib/Bench.hs     haskell harness — module Bench (bench); NOINLINE forcing for -O2
lib/bench.rs     rust harness   — bench(name, FnMut()->i64); include!d by each bench
benches/<x>.{l,ss,lisp,clj,exs,jl,py,rb,js,lua,go,java,hs,rs}
                 each language's implementation of a workload
run.sh           per-language run/compile command + PATH check + per-bench timeout
report.awk       formats the raw result lines into the terminal table
mkhtml.sh        builds bench.html from the raw result lines (used by `make html`)
Makefile         orchestration — per-language out/bench/<lang>.txt result files
```

## Adding a benchmark

1. Write one `benches/<name>.<ext>` per language you want a column for (skip any
   whose value model can't express the workload — as `luajit`/`rust` skip `bell`;
   a missing file just drops that cell). The simplest path is to copy an existing
   bench (`fib` is the smallest) for each extension and swap in the workload. Each
   ends in a single `bench("<name>", …)` call whose thunk returns a deterministic
   checksum identical across every language (the `ok` column checks this); `ai`
   relies on the harness being concatenated ahead, the others
   `load`/`require`/`import`/`include` `lib/bench.*`.
2. Add `<name>` to `BENCHES` in the `Makefile` (controls display order).

To add a whole new **language**, give it a unique extension, add a `case` arm in
`run.sh`, and add its `EXT_`/`HARN_`/`BIN_` lines plus an `ALL_LANGS` entry in the
`Makefile`. Interpreted languages run their source directly; a **compiled** one
builds to a scratch dir and runs the binary (see the `go`/`rust`/`haskell`/`java`
arms) — the compile isn't timed, and a build failure simply drops the cell. Add a
`lib/bench.<ext>` (or `lib/Bench.<ext>`) that reads `BENCH_LANG` for its column
label and implements the rep-doubling timer. If the language has an optimizing
backend, guard the pure-loop benches against compile-time folding (opaque inputs —
`black_box`, a runtime-built array, a JIT warm-up) so the timing stays honest; see
the `closure` note above.

Each ai bench is concatenated after `bench.l` before being piped to `ai`,
exactly like the `test/` corpus — a top-level `:` form with no trailing body
leaks its bindings into global scope, so the harness names are visible.
