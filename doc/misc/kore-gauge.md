# kore-gauge — what kore's applets are measured against, and what a ratio there means

The instrument is `bench/korebench.sh` (`make -C bench korebench`). It is not a gate and is
not wired into one: like `ccnif.sh`, it is a development instrument, run by hand while
working in `src/apps/kore/`.

## the ratio is not the finding

`src/apps/kore/` is ~90 POSIX tools written in love and run by love's interpreter. The
comparison lanes are **busybox** and **GNU coreutils** (C) and **uutils** (Rust). Being
slower than all three is the premise, not the result — a tree that wanted C's numbers
would have written the userland in C.

What the gauge is for is **the shape of the slowness**, and that is why it prints five
tables instead of one number. A constant factor is what a high-level userland costs, and
it is paid once and stays paid. An exponent is a defect: it keeps growing after the
machine gets faster, and it is invisible in ordinary use because ordinary inputs are
small and well-shaped. The two look identical in a single timing. Separating them is the
whole design:

| table | the question it answers |
| --- | --- |
| answers | is the tool *right*? GNU is the oracle; a divergence is a bug |
| start | what does one invocation cost before any applet runs? |
| work | the ordinary corpus, big enough that start is a rounding error |
| shapes | adversarial inputs — where a flat 8× row turns into 400× |
| scaling | t(4n)/t(n) with start subtracted — constant, or exponent? |

⚠ **never read a work row alone.** The nif-backed rows (`md5sum`, `sha256sum`, `cksum`,
and `gzip`) run the *same C* in every lane, because love reaches SHA-256 and DEFLATE
through nifs. Whatever ratio they show is love's own per-invocation and per-byte
overhead, not any applet's algorithm. A row sitting at the md5sum ratio is as fast as
this tree currently makes anything; a row well above it is the applet's own, and only the
scaling table says whether that is a constant or an exponent.

## the readings (2026-09-06, x86-64, 8 MB corpus, median of 3)

busybox 1.36.1 · uutils 0.11.0 · GNU coreutils 9.11 · `LC_ALL=C` throughout.

### start — the fixed cost of one invocation

| ms | kore | busybox | uutils | gnu |
| --- | ---: | ---: | ---: | ---: |
| `true` | 25 | 1 (25×) | 5 (5.0×) | 2 (12.5×) |

love loads a baked image and wakes a heap before it reads a byte. This constant rides
every row below it and every `find -exec` loop in a build script; it is measured once and
never folded into an applet's number. ⚠ On any input under a megabyte this number *is*
the measurement, which is why the work corpus is eight.

It is compute, not I/O: `love -e 0` is 220.6M instructions, 469 page faults and 34
syscalls, flat across `LOVE_BUDGET_MB` from 16 to 1024. Under `perf` 94% of it is the
image — `img_wake` 46%, `img_expand` 39%, `inf_run` 4%, `img_decode_cold` 4% — and
`LOVE_NO_IMAGE=1` is 1,648 ms, so the image is emphatically earning its keep. The whole
25 ms is love waking, not kore loading: `love kore cat /dev/null` costs what `love -e 0`
costs, and the applet registry is free.

⚠ **this row is a per-process cost, and a shell is what decides how many processes there
are.** Under **lush**(1) with the distro's shadow PATH a whole session pays it once: a word
whose PATH winner is this binary either runs in the shell's own process or forks without
exec'ing, so the child rides the heap that is already warm. Measured on the shadow PATH,
five `cat FILE` commands cost 31 ms together rather than 5 × 35 ms, and `ls | wc -l` five
times over — ten love processes — costs 43 ms. So the number above is what an applet costs
when something *else* spawns it; it is not what a kore pipeline costs.

### work — the ordinary corpus

| row | kore | busybox | uutils | gnu |
| --- | ---: | ---: | ---: | ---: |
| md5sum | 60 | 16 (3.8×) | 16 (3.8×) | 13 (4.6×) |
| sha256sum | 96 | 9 (10.7×) | 11 (8.7×) | 8 (12.0×) |
| cksum | 42 | 26 (1.6×) | 6 (7.0×) | 4 (10.5×) |
| cat | 37 | 2 (18.5×) | 5 (7.4×) | 2 (18.5×) |
| **base64** | **21,307** | 36 (592×) | 9 (2367×) | 9 (2367×) |
| wc -l | 95 | 30 (3.2×) | 6 (15.8×) | 4 (23.8×) |
| head -n 1000 | 26 | 2 (13.0×) | 5 (5.2×) | 2 (13.0×) |
| tail -n 1000 | 202 | 20 (10.1×) | 5 (40.4×) | 2 (101×) |
| cut -f2 | 1,194 | 136 (8.8×) | 15 (79.6×) | 15 (79.6×) |
| tr a-z A-Z | 1,049 | 22 (47.7×) | 9 (117×) | 7 (150×) |
| rev | 1,034 | 71 (14.6×) | – | 118 (8.8×) |
| grep (literal) | 486 | 173 (2.8×) | – | 2 (243×) |
| grep -E | 1,261 | 151 (8.4×) | – | 2 (631×) |
| sed s///g | 1,086 | 200 (5.4×) | – | 37 (29.4×) |
| awk (sum a column) | 2,908 | 227 (12.8×) | – | 54 (53.9×) |
| sort | 918 | 541 (1.7×) | 31 (29.6×) | 34 (27.0×) |
| uniq -c | 789 | 131 (6.0×) | 21 (37.6×) | 38 (20.8×) |

The floor is the top three: 1.6–12×, and that is love's overhead on work whose inner loop
is identical C in every lane. Most line tools land at 3–50× busybox, which is the
interpreter's honest price. Two rows are not that — `base64` and, on the shapes table
below, `grep -E`.

`sort` at 1.7× busybox and `grep` at 2.8× are worth stating the other way round: busybox
is not fast at either.

### tools — the rows that are not stdin filters

| row | kore | busybox | gnu | what it is |
| --- | ---: | ---: | ---: | --- |
| gzip -c | 582 | 534 (1.1×) | 403 (1.4×) | DEFLATE, a nif in every lane |
| tar cf (300 files) | 87 | 8 (10.9×) | 5 (17.4×) | mostly the 25 ms start |
| bc -l (500 digits of π) | 38 | 121 (**0.3×**) | 28 (1.4×) | love's own bigints |
| sh (4000 loop turns) | 40 | 3 (13.3×) | 6 (6.7×) | lush vs ash vs bash |

**`bc` is three times faster than busybox's** and within 1.4× of GNU's — the arctangent
series is all bignum division, and love's bigints are underneath it. `gzip` at 1.1×/1.4×
is the nif floor again. These are the rows that say the ceiling is not the language.

### shapes — 1 MB of adversarial input

| row | kore | busybox | uutils | gnu |
| --- | ---: | ---: | ---: | ---: |
| one 1 MB line, `wc -l` | 26 | 5 (5.2×) | 5 (5.2×) | 2 (13.0×) |
| one 1 MB line, `grep` | 65 | 14 (4.6×) | – | 4 (16.2×) |
| one 1 MB line, `sed` | 551 | 24 (23.0×) | – | 6 (91.8×) |
| one 1 MB line, `cut` | 159 | 8 (19.9×) | 6 (26.5×) | 2 (79.5×) |
| one 1 MB line, `rev` | 149 | 7 (21.3×) | – | 17 (8.8×) |
| one 1 MB line, `tr` | 217 | 4 (54.2×) | 6 (36.2×) | 2 (109×) |
| 1M one-byte lines, `wc -l` | 101 | 5 (20.2×) | 5 (20.2×) | 2 (50.5×) |
| 1M one-byte lines, `sort` | 603 | 561 (1.1×) | 24 (25.1×) | 32 (18.8×) |
| 1M one-byte lines, `uniq -c` | 1,145 | 150 (7.6×) | 21 (54.5×) | 32 (35.8×) |
| 1M one-byte lines, `head -n1` | 26 | 1 (26.0×) | 5 (5.2×) | 2 (13.0×) |
| one repeated byte, `sort` | 110 | 15 (7.3×) | 7 (15.7×) | 5 (22.0×) |
| one repeated byte, `uniq -c` | 36 | 7 (5.1×) | 5 (7.2×) | 3 (12.0×) |
| one repeated byte, `gzip` | 46 | 9 (5.1×) | – | 5 (9.2×) |
| high-bit bytes, `base64` | 1,844 | 6 (307×) | 5 (369×) | 3 (615×) |
| high-bit bytes, `tr` | 219 | 4 (54.8×) | 5 (43.8×) | 2 (110×) |
| high-bit bytes, `wc -c` | 27 | 5 (5.4×) | – | 2 (13.5×) |
| **`grep -E '^(a\|aa)+b$'` on 41 bytes** | **timeout (>60 s)** | **2** | – | **2** |

The good news first: the long-line, one-byte-line and repeated-byte corpora produce
**no blow-up anywhere**. Every row is within a small factor of its own position on the
ordinary corpus — the line reader does not cons a charm at a time, `sort` does not
degenerate on an all-equal key, and `gzip` is *faster* on the repeated byte, not slower.
Those were the four hypotheses the shapes table was built to test and all four came back
clean.

The last row is the exception, and it is the finding.

### scaling — kore only, start subtracted

t(4n)/t(n) at 2/4/8 MB. 4.0 is linear, ~4.3 is n log n, 16 is quadratic, 1.0 means the
tool stopped early. ⚠ the start cost is subtracted before the ratio is taken — leaving
it in makes every row look sublinear at these sizes, which is exactly the reading that
would hide a quadratic one.

| row | 2 MB | 4 MB | 8 MB | growth | reading |
| --- | ---: | ---: | ---: | ---: | --- |
| tail -n 1 | 110 | 167 | 304 | 3.3 | linear |
| base64 | 5,071 | 9,649 | 23,160 | 4.6 | linear |
| cut | 383 | 649 | 1,208 | 3.3 | linear |
| tr | 351 | 577 | 1,036 | 3.1 | linear |
| rev | 340 | 568 | 1,081 | 3.4 | linear |
| grep | 174 | 287 | 493 | 3.1 | linear |
| sed | 350 | 595 | 1,101 | 3.3 | linear |
| awk | 799 | 1,512 | 2,937 | 3.8 | linear |
| sort | 247 | 534 | 906 | 4.0 | linear |
| uniq -c | 279 | 448 | 807 | 3.1 | linear |

`cat`, `wc -l`, `head -n1` and `md5sum` all read *too fast at 2 MB* — with start
subtracted their real work is single-digit ms and the quotient would be two noise terms
divided by each other. That guard is not fussiness: on the first fill, before it existed,
`wc -l` read as **8.3× — QUADRATIC**, and it is linear. Raise `SCALE` to read those rows.

**Every row that can be read is linear.** No applet in `src/apps/kore/` has a bad
exponent on ordinary input. That is the single most useful line on this page, and it is
what makes the constant factors above merely a cost rather than a trap.

## what the first fill found

Four, in the order they matter. None of them is "kore is slower than C". **All four are
closed** — the tables above are the fill that found them, and re-running
`make -C bench korebench` now shows `base64` at ~135× rather than ~600× and the
backtracker answering in under a second instead of not at all. The numbers were left as
they were measured rather than refreshed: a gauge's first fill is the record of what it
caught, and overwriting it hides that.

### 1. `grep -E` backtracked catastrophically — now bounded

`grep -E '^(a|aa)+b$'` against forty `a`s did not finish in sixty seconds; busybox and
GNU both answer in two milliseconds. The engine is `module 're` in
`src/core/boot/post.l`, and its own header says what it is: *"matching is greedy
backtracking in continuation style"*. On a repeated alternation that is exponential in
the input length — it tries every way to split the run — while GNU builds an automaton
and walks the string once.

That is a property of the design, not a bug in the code. But it had a consequence the
design note did not draw: **a pattern from an untrusted source was a hang**, and so was
an innocent-looking one a person types. It was the only unbounded input in the tree.

The repair is a **step budget**, which is what this engine can afford — the other two
routes (memoizing `(position, node)` pairs, or a Thompson construction for the
backreference-free subset) are a different engine, not a fix. The same line now answers
in 0.4 s with a sentence and exit 2. Three things make it cost nothing anywhere else:

* **the choice is made at compile time.** `renests?` asks whether a repeat's *atom* can
  match one span two ways — an alternation, or another repeat. `[0-9]+`, `.*` and
  `a\{2,5\}` cannot, so they compile to exactly the loop they always did and their inner
  loop never reads a counter. Only the dangerous shape gets the counting twin.
* **the counter is born in the closure**, one per entry to that repeat — per starting
  position for a top-level one. There is no module-level cell to bake, to reset per
  find, or to share with a nested match.
* ⚠ **and it could not have been a module-level value binding.** `relimit 200000` at the
  top of module `'re` floods love0's boot with `;; missing relimit`: post.l's own module
  is walked while post.l is still loading, so a value binding there is read before the
  letrec reaches it. The built love, whose image already holds the module, is perfectly
  happy — and so is a module of one's own loaded afterwards, which is why the shape is
  easy to get wrong. `(relimit _) 200000` defers and is fine.

`make test_kore` gates it, and gates it *on the clock*: a grep that hangs on a pattern a
person can type is a different kind of defect from a wrong answer, and only a timer sees
it.

### 2. `base64` was ~600× busybox, and 3.5× of that was closure minting

Alone among the line tools, `base64` is two orders of magnitude off its neighbours:
21.3 s for 8 MB where `tr` — a comparable per-byte transform — takes 1.0 s. The scaling
table says it is **linear**, so this is a constant, not a cliff, but the constant is
~100× larger than any other row's.

Two guesses were measured and are wrong, and they are recorded so nobody spends the
afternoon again: the tower `((* bits ((gc - 1) - j)) 2)` computing 2^shift per output
charm is **not** the cost (3M towers = 5 ms), and neither is the jug (1.4M `put`s =
145 ms, ~6% of the row).

What was: `ubenc` in `src/apps/kore/core.l` defined `val` and `go` **inside** `grp`, so
two closures were minted per three input bytes. Lifting both to the enclosing scope and
precomputing the four shift divisors — no other change, byte-identical output — took
539 ms to 155 ms on the same input, a **3.5×**. Landed; the row went from 592× busybox
to 135×, which is `tr`'s neighbourhood rather than a hundred times past it.

⚠ **the shape generalizes past this one applet.** A loop lambda born inside another
loop's body is minted every turn, and love has no pass that hoists it. Worth a look
wherever a `(: ... (go 0))` sits inside a recursive step — this is the single cheapest
thing the gauge has found, and there is no reason to think `base64` was the only place.

### 3. `sort` had no `-n`, and `ls` no `-l` — both fixed

Both turned up in the answers table rather than a timing: `sort -n` died with
`sort: cannot open -n` — it read the flag as a filename — and `ls -l` printed
`ls: cannot access -l` and then the bare names. `sort-main` took `-r -u` and nothing
else; `ls-main` took `-a` and nothing else. Neither absence was written down anywhere:
`doc/misc/kore.md`'s inventory lists tools, not flags.

Both now carry a matrix against GNU inside `make test_kore` — `test/gate/sortcmp.sh`
(75 rows) and `test/gate/lscmp.sh` (29 rows), byte-identical. What the matrices cost,
which is the part worth keeping:

* **`?` on a comparison is the falsy trap again.** `-1` is false here (a predicate is
  the sign of the net), so `(? c c (go >ks))` sent every *less-than* on to the next sort
  key as though the keys had tied, and `!(cmp a b)` called it equal. Both readings have
  to ask `= 0` out loud. This is the same shape `bc` hit with `['ret v]`.
* **prel's `sortby` is not a stable sort.** `sortsplit` *deals* the list into two, so
  element 1 lands to the right of element 2 and a left-preferring merge hands them back
  swapped. `sort -u` then keeps an arbitrary representative of each equal run where GNU
  keeps the input's first. The repair is to carry the index as the last tiebreak, which
  states stability instead of hoping for it from the sort underneath.
* **`-k1,1b` and `-k1b,1` are different keys.** `n`/`r`/`f` on either half order the
  whole key, but `b` names a *position*: on the start spec it skips the field's leading
  blanks, on the end spec it is about where the key stops. Folding the two halves'
  letters together sorts `-k1,1b` on the wrong key, quietly.
* **GNU's `ls -l` sizes the command-line block's columns over every operand**,
  directories included — even though a directory operand is listed further down as its
  own block and its row is never printed. `ls -l file dir` pads *file*'s size to the
  width of *dir*'s.
* **`readdir` does not hand back `.` and `..`**, so `ls -a` owed both. They are put back
  in `ls`, not in `readdir`, where every other caller would have to take them out again.
  The old gate had asserted the divergence — it compared our `-a` against GNU's `-A` —
  which is how an absence stays invisible for a year. `-A` is now its own flag.

### 4. what the shapes did *not* find, which is most of them

Long lines, one-byte lines, an all-equal sort key and high-bit bytes all came back within
a small factor of the ordinary corpus, and every readable scaling row is linear. The four
classic ways a text tool degenerates are all absent here. That is worth recording as
plainly as the failures: the constant factors on this page are a price, not a trap, and
they are the price of a userland written in love.

## the second fill (2026-09-07)

Same machine, same lanes, median of 3, 8 MB. Three rows were added and four things
were changed on the strength of the first fill; the numbers above stay as the record of
what it caught, these are what the tree does now.

### the rows added

`bc` and `sh` were on the tools table but not on the scaling one, and a calculator and
a shell are exactly the two tools whose cost is per *turn* rather than per byte. Both now
run a loop program at N, 2N and 4N turns (`SCALE * 1000` per step): `bc` sums squares,
`sh` counts with `[ ]` and `$(( ))`. And one more tools row, **`sh +cat`**: two hundred
commands each naming a tool by its bare word, which is what a *command* costs a shell
rather than what its evaluator costs.

| row | kore | busybox | gnu | what it reads |
| --- | ---: | ---: | ---: | --- |
| sh +cat (200 commands) | 314 | 59 (5.3×) | 127 (2.5×) | lush forks its warm heap; ash and bash fork+exec a cat |
| sh (turns), 4k/8k/16k | 617 / 956 / 1716 | | | 2.9, linear -- ~0.1 ms a turn |
| bc (turns), 4k/8k/16k | 45 / 98 / 164 | | | too fast at this scale |

### the readings, before and after

| row | first fill | now | busybox | gnu | how |
| --- | ---: | ---: | ---: | ---: | --- |
| base64 | 4,598 | **121** | 37 (3.3×) | 9 (13.4×) | the `kb64` kernel |
| tr a-z A-Z | 1,359 | **88** | 23 (3.8×) | 7 (12.6×) | the `xlat` nif |
| sort | 5,359 | **710** | 516 (1.4×) | 36 (19.7×) | prel's C sort again, lines off the reading floor |
| cut -f2 | 1,362 | 1,164 | 129 (9.0×) | 13 (89.5×) | `usplit` finds each separator on the scan floor |
| sh (turns), 16k | 3,628 | 1,716 | | | the arithmetic's operator read |
| high-bit bytes, base64 | 53 | 36 | 6 (6.0×) | 3 (12.0×) | |
| one 1 MB line, tr | 38 | 32 | 5 (6.4×) | 2 (16.0×) | |

`base64` and `tr` now sit at the md5sum ratio -- the floor -- which is what a row reads
when its inner loop is native in every lane. Everything not in this table moved within
the run-to-run noise.

### what it found

**1. the byte loop went native, two ways.** `scan.l` had already priced the interpreter's
walk at ~684 instructions a byte and written the one kernel that finds a byte; `tr` and
`base64` are nothing *but* that loop. `tr`'s is generic -- any byte map through a 512-byte
table (image and mode per charm: drop, write, squeeze), three faces in one loop -- so it
is a **nif**, `(xlat s tbl dst)` in `src/core/map.c` beside `pour`: one C body mooncc
compiles for every target, no startup cost, reachable by any applet. `base64`'s group
coder is its own shape and used by nothing in the core, so it stays out of the roster as
a **holo kernel** in `src/apps/kore/core.l`: one IR for x64 and a64 in `scan.l`'s shape
(register roles, deopt tail, kind guards off g's jk table so the blob names no C
address), coding every whole three-byte group and leaving the tail to the old coder.
Both have a love twin that is the oracle `law.l` holds them to (every length 0-40,
high-bit bytes, a 5000-byte sweep, the squeeze's longest run), and the kernel's twin is
also its engine wherever the install declines -- inle, wasm, rv64. `(cask n)` + `snip` is
the door either way: the native writes bytes, never allocates, and the caller copies the
count out. Timed apart on the 8 MB corpus, `xlat` is 14 ms; `tr`'s other ~100 ms are
the start (28) and `(slurp in)` (68). That slurp was chased and it is **not the
reader**: run first in a process it costs 68-93 ms, run second in the same process
31 ms, and a different reader (the gulps consed, laid into one cask) swapped into
first place takes the 75 instead. The first ~8 MB a process allocates is heap
first-touch, whatever touches it. Two things were tried on the strength of the wrong
reading and both are recorded so nobody tries them again: `ai_iobuf` 4096 -> 65536 cut
the reads 16× and moved `tr` not at all while making `cut` **2× slower**; the gulp-list
reader beats the jug by 24 vs 31 ms in steady state, not worth a floor primitive and a
twelve-site sweep. (`strace` does show an `F_GETFL`/`F_SETFL` trio around every read of
an inherited fd -- `src/host/fd.c`, the bit must not be left on a terminal -- but 6,150
of them cost ~12 ms of kernel time, and a pipe on stdin takes the bit once for the
session anyway.) So a stdin filter's clock reads: start 28 + first-touch ~45 + the
work, and only the third term is the applet's. The trade between
the two natives, since it came up: a nif costs a core rebuild
(nifs.l is the compiler's business) and a roster entry; a kernel costs a hand-written IR
per ISA, an assemble per process, and the riskiest code in the tree per line. Generic
earns the roster; one applet's shape does not.

**2. `sort` had gone to 5.4 s, and it was the shape, not a bug.** The `-k` matrix moved
every sort onto prel's `sortby` -- a lisp merge with a closure compare, at ~1 µs a
comparison -- and read each line's fields *per comparison*. Three moves: a sort with no
key and no letter is byte order, which is prel's `sort` (the C lane, stable) and `-r`
its reverse; a keyed sort decorates each line ONCE with its readings and sorts the
decorated lists on the same C lane, since it orders lists lexicographically and bigs
exactly -- a numeric reading becomes `[sign int frac]` with the fraction's digits
complemented under a minus so byte order is numeric order, and a key against the grain
reverses by negation, so only a *text* key against the grain still takes the merge;
and the lines come off the reading floor, because prel's `lines` walks a charm at a
time and cost 688 ms of the 1128 -- more than the sort did. `-k2` reads 3.7 s and `-n`
4.1 s now, from 6.1 and 8.9; what is left there is field splitting and number reading
in love, per line.

**3. the shell's arithmetic read every operator at every rung.** `$(( ))` is a
precedence climb over twelve rungs, and at each rung it asked `ar-op`, which folded over
nineteen operators with a `snip` per try -- 228 allocations to evaluate `1`. It reads the
operator off its first byte or two now: `i=$((i + 1))` went from 334 µs to 45, and a
`while [ ]` turn from 0.27 ms to 0.1. `[ ]` is the other half of that turn and it is
the lexer and expander, not the in-image call, which is ~1 µs.

**4. what one command costs, and where the payoff is.** The `sh +cat` row is the one to
read against lush's lanes, measured apart (200 turns, ms):

| the command | lush | bash | the lane |
| --- | ---: | ---: | --- |
| `basename /x/y` | 45 | 128 | in-image: no process at all |
| `cat /dev/null` | 308 | 135 | fork, no exec: the warm heap's page tables, ~1.3 ms |
| `echo x \| cat` | 353 | 173 | a pipeline stage, forked |
| `x=$(echo x)` | 235 | 71 | the forkless capture |

So the fork lane -- one image wake saved -- still costs twice what bash pays to exec a
C cat, because forking a process with a heap that size is a page-table copy. The
in-image lane is where a command becomes free, and its allow list is short on purpose
(the stdin story, **lush**(1)). That is the row autonomous mode is about: under `-g` on a
host whose PATH is not us, the same loop costs 1,143 ms, since every `cat` *and every
`[`* is a spawn.

**5. what is left is the interpreter, not a loop.** `cut`, `rev` and `sed` were profiled
on the corpus (`perf record`, top symbols, self time) to ask whether a glaze lane for
byte loops would have a corpus. It would not. No applet function appears; the top of
every profile is the evaluator's own dispatch and allocation:

| symbol | cut | rev | sed | what it is |
| --- | ---: | ---: | ---: | --- |
| `lvm_cur` | 8.1% | 10.7% | 13.3% | currying a call to saturation |
| `lvm_argap` + `lvm_qap` + `lvm_aap` | 11.7% | 16.4% | 17.0% | argument application |
| `gcp` | 7.3% | 6.7% | 6.0% | the collector |
| `lvm_unc` | 4.8% | 3.3% | 7.7% | uncurrying |
| `memcpy` + `lvm_snip` | 6.8% | 4.1% | 2.9% | the snips |
| `lvm_fputc` + `ioputc` + `to_writen` | | 14.2% | | rev's byte-at-a-time output |

The per-element loops in these tools allocate -- a snip per field, a cons per line, a
jug put per byte -- so a byte lane that compiles pure index-and-compare loops would fire
on nothing here; what it could take (`tr`, `base64`, the scan) is already native. The
lever left is the shape of the applets' own code: `rev` writes its output a byte at a
time through the port (14% of its run), `cut` snips every field it does not print. Those
are rewrites in love, not a compiler lane.

The `lvm_cur` + `lvm_unc` share is the currying: a call saturates into one n-ary apply
only where the compiler knows the callee's arity at compile time -- a letrec lambda
sibling, or a book global whose *value* it can read (`ev.l`'s `falook`/`napof`). Every
call through a parameter or a looked-up value curries a partial per argument: `ulines`'s
`dot`, `sortby`'s comparator, and the scanner reached as `(peep t 'sc ())` or a
parameter -- two partials per line and per field in `cut`. The obvious cure was tried
and does not work: binding the scanner as a top-level *value* in u.l so callers see its
arity bakes it into the image as a plain closure (`nat?` answers 0 -- the walk, not the
kernel), and `wc -l` went 103 -> 170 ms. Kernels must stay lazy, per process. What would
saturate all of those sites at once is a runtime-arity-checked n-ary apply in the VM,
not an applet edit; it is worth ~14% of `cut` and `sed`. Also open: `grep -E` is the backtracker;
`sort`'s scaling row reads 7.7 with start subtracted, above n log n, and the C sort is
~1 µs an element on strings -- worth a look at the comparator; `tail -n1` reads the whole
file where GNU seeks from the end.

## choices (revisable)

- **GNU is the oracle, busybox and uutils are second opinions.** `make test_kore` already
  smokes kore against GNU, so a divergence here is the same fault that gate would name.
  The other two lanes are there for the case the gate cannot cover: where all three of
  them agree with each other and *not* with GNU, the difference is likelier GNU's dialect
  than anyone's bug. (`wc -lc`'s column widths are exactly that — busybox diverges, we do
  not.)
- **generated corpora, never a file off the disk.** A row has to be reproducible on
  another machine and its contents have to be known. The generator is a linear
  congruential walk inside the script, so even awk's `rand()` — which differs between
  awks — is not in the measurement.
- **the adversarial inputs are chosen, not sampled.** One line with no newline in it, a
  million one-byte lines, one repeated byte, high-bit bytes throughout, and an ERE built
  to make a backtracking matcher explode. Each names a specific way a text tool goes
  wrong, and none of them can arise from the ordinary corpus.
- **not a gate, and not on a tier.** The same reasoning as `ccnif.sh`: what it prints is
  four readings of the same job, not a verdict, and a threshold on any of them would
  either be so loose it never fires or so tight it fires on the machine's mood.
- **the nine rows on `bench/bench.html` are a cross-section, not a best-of** — two stream
  editors, a language, a calculator, two archivers, two sorters and a shell. Picking the
  rows where love looks good would make the page an advertisement rather than an
  instrument.
