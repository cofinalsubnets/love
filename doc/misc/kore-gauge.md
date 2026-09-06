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

Four, in the order they matter. None of them is "kore is slower than C".

### 1. `grep -E` backtracks catastrophically — the one unbounded row

`grep -E '^(a|aa)+b$'` against forty-one `a`s does not finish in sixty seconds; busybox
and GNU both answer in two milliseconds. The engine is `module 're` in
`src/core/boot/post.l`, and its own header says what it is: *"matching is greedy
backtracking in continuation style"*. On a repeated alternation that is exponential in
the input length — it tries every way to split the run — while GNU builds an automaton
and walks the string once.

This is a property of the design and not a bug in the code, but it has a consequence the
design note does not draw: **a pattern from an untrusted source is a hang**, and so is an
innocent-looking one a person types. Nothing else in this tree has an unbounded input
today; `grep` does. The repairs, in increasing order of work: a step budget that gives up
and says so, memoizing (position, node) pairs to make it polynomial, or a Thompson
construction for the subset of patterns that has no backreferences. None is scoped here —
the finding is that the cliff is real and reachable from one line of shell.

### 2. `base64` is ~600× busybox, and 3.5× of that is closure minting

Alone among the line tools, `base64` is two orders of magnitude off its neighbours:
21.3 s for 8 MB where `tr` — a comparable per-byte transform — takes 1.0 s. The scaling
table says it is **linear**, so this is a constant, not a cliff, but the constant is
~100× larger than any other row's.

Two guesses were measured and are wrong, and they are recorded so nobody spends the
afternoon again: the tower `((* bits ((gc - 1) - j)) 2)` computing 2^shift per output
charm is **not** the cost (3M towers = 5 ms), and neither is the jug (1.4M `put`s =
145 ms, ~6% of the row).

What is: `ubenc` in `src/apps/kore/core.l` defines `val` and `go` **inside** `grp`, so
two closures are minted per three input bytes. Lifting both to the enclosing scope and
precomputing the four shift divisors — no other change, byte-identical output — takes
539 ms to 155 ms on the same input, a **3.5×**. That would put the row in line with `cut`
and `tr` instead of a hundred times past them.

⚠ the shape generalizes past this one applet: a loop lambda born inside another loop's
body is minted every turn, and love has no pass that hoists it. Worth a look wherever a
`(: ... (go 0))` sits inside a recursive step.

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
