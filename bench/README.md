# bench/ — ai benchmark harness

Times a small set of numeric and list-processing workloads across **ai** and
every standard lisp / scripting language on the box, printing a side-by-side
comparison. Each workload is implemented once per dialect, computing an identical
checksum so the runs are verified equivalent (the `ok` column). The lineup:

- **schemes** — `chez` (compiled), `petite` (Chez's interpreter), `guile`,
  `racket`, `mit-scheme`, `chicken`, `bigloo`, `owl` (purely functional)
- **common lisp** — `sbcl`, `clisp`, `ecl`
- **on a host VM** — `clojure` (JVM), `hy` (→ CPython), `fennel` (→ Lua),
  `elixir` (BEAM)
- **others** — `python`/`pypy`, `ruby`, `node`/`deno` (js), `lua`, and `luajit`
  with the JIT on and, separately, off via `-joff`

Several interpreters share one implementation file, with `BENCH_LANG` setting the
column label so they stay distinct: `chez`/`petite` over `.ss`, `sbcl`/`clisp`/`ecl`
over `.lisp`, `python`/`pypy` over `.py`, `node`/`deno` over `.js`,
`lua`/`luajit`/`luajit-nojit` over `.lua`. `hy` reuses the Python harness
(`lib/bench.py`) and `fennel` the Lua harness (`lib/bench.lua`) by importing it.
The per-dialect timing primitive lives in `lib/bench.*`; note `mit-scheme` has only
a CPU-time clock (`(runtime)`, ~10 ms granularity) so its numbers are coarser, and
`owl` is purely functional (immutable strings, `ff` maps for the `bell` memo).

## Running

```sh
make bench          # from the repo root, or `make` here: the default column set
                    #   (ai cpython chez sbcl node luajit elixir)
make all            # every language present on this machine (a wide table)
make chez           # one language, shown alongside ai for contrast
make pypy           # ... any language name works as a target
make BENCHES=fib    # restrict the workloads (then `make clean` to refresh files)
make TIMEOUT=60 …   # per-bench wall-clock cutoff in seconds (default 30)
make SKIP= …        # clear the known-timeout drop list (default: owl:bell)
make raw            # the raw result lines, unformatted
make clean          # remove out/bench/
```

**Results are cached per language.** Each language writes its lines to
`out/bench/<lang>.txt`, and that file depends on the language's bench sources (and,
for ai, the `ai` binary). The user-facing targets just *pretty-print* those
files — a bench is only (re)run when its result file is missing or older than the
sources, so `make bench` reformats instantly once the files exist. Touch a source
or `make clean` to force a re-run. The per-language run logic (extension,
interpreter command, `BENCH_LANG`) lives in `run.sh`.

A language whose interpreter isn't on `PATH` is **automatically omitted**; so is
any bench a language has no implementation for (e.g. `lua`/`fennel` lack `bell` —
no bignums). Pairs that exceed `TIMEOUT` are listed in the Makefile's `SKIP`
variable (default `owl:bell`) and dropped up front, so the build never pays the
30 s timeout wall for a cell that was never going to land — re-test one by
removing it from `SKIP` and `make clean`. Such cells just drop out of the table.
As benches run, `run.sh` prints a `  <lang> <bench>` tick per bench to stderr,
with a `(dropped: …)`/`(skipped: …)` note for any pre-skipped, timed-out, or
errored, so stdout stays clean for the table.

Example output (one column per dialect — the real table is wide; abridged slice):

```
bench         ai ms/it    chez ms/it  petite ms/it  racket ms/it    sbcl ms/it   clisp ms/it  luajit ms/it  python ms/it    pypy ms/it  ...   ok
fib              27.1250        6.5312       67.2500        5.4180       12.5636      748.8520        8.0017      101.7170        9.0407  ...  yes
sum               6.4688        0.5918        3.7812        0.2874        0.7579       50.0703        0.0792        2.9250        0.2941  ...  yes
mapfilter         1.0742        0.1128        0.2314        0.1087        0.1069        2.6892        0.0348        0.9911        0.0983  ...  yes
```

Each `ms/it` column is that dialect's per-iteration time; lower is faster. `ok`
confirms every present dialect's checksum for the bench agrees. Things to read out
of it: the compiler/interpreter gap inside one language is huge — `chez` vs
`petite`, `sbcl` (native compiler) vs `clisp`/`ecl` (bytecode CLs), `pypy` vs
`cpython`, `luajit` vs `luajit-nojit` — often 10–100×; `racket` and `chez` lead the
schemes; `mit-scheme`'s coarse CPU clock makes its column blocky. `bell` shows `-`
for `lua`/`fennel`/`luajit` (no bignums) and for `owl` (its bignum `bell` exceeds
the timeout). Run `make all` for the full table.

## How timing works

Every language self-times only the inner workload, so interpreter startup is
excluded from the measurement. The harness auto-scales the repetition count —
doubling until the run clears a 200 ms floor — then reports `(reps, ms)`. The
report divides `ms / reps` for a per-iteration time, so the chosen rep count
cancels out and benches of very different cost stay comparable. ai's clock has
1 ms resolution (`(clock 0)`), which the 200 ms floor keeps under ~0.5 % error.

## Benchmarks

| bench       | kind    | workload                                                   |
|-------------|---------|------------------------------------------------------------|
| `fib`       | numeric | naive recursive `fib(30)` — call + integer-arithmetic cost |
| `tak`       | numeric | Takeuchi `tak(22,12,6)` — deep non-tail recursion          |
| `sum`       | list    | build `1..100000`, fold-sum it                             |
| `mapfilter` | list    | square 10000 elems, keep evens, sum                        |
| `primes`    | numeric | count primes below 30000 by trial division                |
| `bell`      | bignum  | Bell numbers in base 36 to 280 digits (port of `test/bell.l`) |
| `strcat`    | string  | build a 4000-char string by single-char concatenation, then hash it |
| `strscan`   | string  | rolling-hash scan over a fixed 20000-char string (read path) |
| `hash`      | table   | mutable hash table: 10000 sparse-int-keyed insert / lookup / update ops |
| `sort`      | sort    | merge/quick-sort 5000 LCG-random ints, hash the sorted order |
| `tree`      | alloc   | build + traverse a depth-16 binary tree (small-aggregate alloc / GC churn) |
| `float`     | float   | mandelbrot escape counts over a 64×64 grid (pure f64, integer checksum) |
| `closure`   | closure | build & apply 2 closures per iter over 100000 iters (higher-order stress) |

`bell` is the heavy one: it leans on the whole bignum tower (`*`/`/`/`%` over numbers
hundreds of digits long) and rebuilds its memo tables each iteration so every rep recomputes
from scratch. It's the most evaluator-neutral comparison here — every language does identical
big-integer arithmetic (node via `BigInt`, the lisps/python/ruby natively). **lua, fennel and
luajit are omitted**: their numbers are 64-bit int/double, so there is no `bell.lua`/`bell.fnl`
and the cell shows `-`. **owl** has bignums and a `bell.owl`, but its interpreter can't finish
`bell` inside the timeout, so the pair is listed in `SKIP` (`owl:bell`) and dropped up front.
The memo also shows off a dialect difference: most
implementations use a mutable hashtable, but `owl` and `elixir` (both functional) thread
immutable maps through the loop, and `chicken` (no hashtable egg installed) uses a vector —
same result, same checksum.

`hash` is the mutable-hash-table bench: into a fresh table it inserts N=10000
integer keys, sum-looks-them-up, does a read-modify-write update pass, then
sum-looks-up again (checksum = N²). Keys are sparse (stride 97) on purpose, so
Lua/Python can't service them from a contiguous-integer *array* fast-path and
must actually hash. Each dialect uses its native mutable table — ai `table`/
`put`/`get`, the schemes' `*-hashtable`, CL `gethash`, JS `Map`, Lua tables,
etc.; **Clojure** (persistent core maps) uses `java.util.HashMap` via interop.
The purely functional dialects (`owl`, `elixir`) have no mutable table, and
`chicken` has no hashtable egg installed, so all three drop the `hash` cell.

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
only bench that touches floats; `owl` has no IEEE doubles so it drops the cell,
and the Common Lisps need `d0` double-float literals to agree). `closure`
stresses ai's defining feature — every value a curried unary function: per
iteration it builds `(adder i)` and `(twice (adder i))` and applies them, so it
allocates and calls two closures 100000 times.

The two string benches split the write and read paths. `strcat` builds a string
one character at a time with each language's concatenation operator (ai `scat`,
python/lua/lisp string-append, etc.) — an O(n²) build that measures how that
operator copies, so it favours languages with mutable/rope-backed strings.
`strscan` times only a linear rolling hash over a string built once outside the
loop, isolating the byte-read path (ai `get`/`len`). Both fold the same
polynomial hash `h = (h*31 + byte) mod 1e9+7`; taking it mod a prime keeps the
checksum a 64-bit fixnum, so it is identical across every language (lua included)
and doubles as the `ok` cross-check.

The list benches compare *idiomatic* implementations: ai and the lisps walk
cons-cell linked lists, while python/ruby/node/lua use native dynamic arrays and
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
`lua`/`fennel` have no `map`/`filter`, so a hand loop fuses them by hand;
`python`/`clojure`/`hy` are lazy — no intermediate lists, per-element overhead;
`node`/`ruby`/the schemes allocate eagerly). The anchor is that ai's deforested
pipeline lands at `luajit`'s *hand-written loop* — the high-level functional
source costs what the loop costs. (The purest A/B is ai with the glaze on vs off;
we keep it always-on and watch the gate for regressions.)

## Layout

```
bench.l          ai harness — iota/iota1 + the (bench name work) timer
lib/bench.py     python harness — bench(name, work)   [also pypy, and hy imports it]
lib/bench.rb     ruby harness   — bench(name) { work }
lib/bench.ss     chez harness   — (bench name work)    [also petite]
lib/bench.scm    guile harness  — (bench name work)
lib/bench.rkt    racket harness — (provide bench)
lib/bench.mit    mit-scheme harness
lib/bench.ck     chicken harness (provides keep/sum-list; vector memo)
lib/bench.bgl    bigloo harness
lib/bench.owl    owl harness    — concatenated ahead of each bench, ai-style
lib/bench.lisp   sbcl harness   — (bench name work)    [also clisp, ecl]
lib/bench.clj    clojure harness
lib/bench.exs    elixir harness (BEAM monotonic clock; functional ff-style memo)
lib/bench.js     node harness   — bench(name, work)    [also deno]
lib/bench.lua    lua harness    — bench(name, work)    [also luajit; fennel requires it]
benches/<x>.{g,ss,scm,rkt,mit,ck,bgl,owl,lisp,clj,exs,hy,fnl,py,rb,js,lua}
                 each language's implementation of a workload
run.sh           per-language run command + PATH check + per-bench timeout
report.awk       formats the raw result lines into the table (skips bad lines)
Makefile         orchestration — per-language out/bench/<lang>.txt result files
```

## Adding a benchmark

1. Write one `benches/<name>.<ext>` per language you want a column for (skip any
   whose value model can't express the workload — as lua skips `bell`; a missing
   file just drops that cell). The simplest path is to copy an existing bench
   (`fib` is the smallest) for each extension and swap in the workload. Each ends
   in a single `bench("<name>", …)` call whose thunk returns a deterministic
   checksum identical across every language (the `ok` column checks this); see the
   per-dialect preamble each existing file uses (`ai`/`owl` rely on the harness
   being concatenated ahead; the others `load`/`require`/`import` `lib/bench.*`).
2. Add `<name>` to `BENCHES` in the `Makefile` (controls display order).

To add a whole new **language**, give it a unique extension, add a `case` arm in
`run.sh` (extension, interpreter binary, run command), and add its `EXT_`/`HARN_`/
`BIN_` lines plus an `ALL_LANGS` entry in the `Makefile`. If it can reuse an
existing harness (a Python-hosted lisp importing `lib/bench.py`, a Lua-hosted one
requiring `lib/bench.lua`, etc.), point `HARN_<lang>` at that file; otherwise add a
`lib/bench.<ext>` that reads `BENCH_LANG` for its column label.

Each ai bench is concatenated after `bench.l` before being piped to `ai`,
exactly like the `test/` corpus — a top-level `:` form with no trailing body
leaks its bindings into global scope, so the harness names are visible.
