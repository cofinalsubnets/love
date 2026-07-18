# moon-diag — teaching mooncc to name its causes

mooncc knows why it refused. It just doesn't say. Every stage discovers a precise
cause — a missing identifier, an unparseable token, an `#error` and its text — and then
returns a bare bad value across the stage boundary, where the driver prints a generic
line naming only the file. The cause is computed and then thrown away.

This doc specifies the pass that stops throwing it away, plus the mundane
header/declaration gaps the measurement below turned up alongside it.

## why now: the gnulib measurement

Building gzip-1.13's gnulib layer (2026-07-18, the [[moon-userland]] ladder). Of the 118
`lib/*.c`, automake actually builds **37** on Linux — the rest are Windows and
other-platform lanes. Against that real build set:

**20 of 37 compile with mooncc today.** The 17 failures:

| first blocker | n | files |
|---|---|---|
| undeclared function/constant (`cgfn refuses`) | 10 | cloexec, dup-safer, dup-safer-flag, filenamecat-lgpl, ialloc, opendir-safer, save-cwd, savedir, utimens, xmalloc |
| parse error, cause not isolated | 4 | freading, malloca, mbszero, openat-proc |
| no `float.h` at all | 2 | printf-frexp, printf-frexpl |
| codegen error → missing `EXIT_FAILURE` | 1 | exitfail |

Reproduce with **`tools/moon-sweep.sh PKGSRC=<a ./configure'd tree>`** — it compiles every
`lib/*.c`, scores against `lib/Makefile`'s `*_a_OBJECTS` (the 37, not the 118), prints the
per-file causes and the bucket census, and reports the other-platform lanes separately.
Skips cleanly without a tree, like `moon-tar`. Logs land in `out/host/moonsweep/logs/`.

⚠ THE DENOMINATOR IS THE POINT — a raw `for f in lib/*.c` count says 56/118 and is
meaningless, since gnulib's `lib/` carries every platform's lane. The script exists mostly
to stop that mistake being made twice (it was made once here).

These are FIRST blockers — clearing one may expose another behind it. And gzip pulls ~37
gnulib objects where coreutils pulls several hundred, so this is a lower bound on the
general gnulib distance, not a measure of it.

**The finding that matters: 15 of the 17 reported a symptom with no cause.** The work
itself is ordinary header completeness — the same thing every rung has been. The
diagnostics are what make it expensive. `exitfail.c` is *one declaration*
(`int volatile exit_failure = EXIT_FAILURE;`); it reported `cc: codegen error in
<path>` and took five minimal test programs to pin on a missing macro.

⚠ the one diagnostic that worked was `cc: cannot resolve #include <float.h>` — named its
cause instantly, and it's the one deliberately fixed to self-name during the `cppbad`
propagation work (doc/moon-userland.md, the stdckdint.h bug). **The precedent is already
set; it just never got applied anywhere else.** This pass generalizes it.

## the diagnosis

`moon.l:63-91` is the whole story. Each stage is called, then checked:

```
lx (clex ((deftext ds9) + <>r))
_  (? (two? lx) () (udie 1 ("cc: lex error in " + src)))
pp (cpp <>lx (\ name sys? (incload is (cdir src) name sys?)) src)
_  (? (two? pp) () (udie 1 ("cc: preprocessor error in " + src)))
ps (cparse-t <>pp tgt)
_  (? (two? ps) () (udie 1 ("cc: parse error in " + src)))
```

A stage answers a two-ish value on success and something else on failure. The something
else carries nothing, so the message can only be built from what the *driver* knows: the
stage it was in, and `src`. Meanwhile:

- `gen.l:4049` — `(puts (+ ";; cgfn refuses " (<>f + "\n")))` knows the enclosing
  function and prints it to stdout as a note, then answers `()`. The driver later prints
  an unrelated `codegen error` line to stderr. Two half-messages, neither sufficient.
- `cpp.l:290` — the `#error` handler has the directive in hand and prints only
  `"cc: #error directive"`, discarding the message text and the file it fired in.
- `cpp.l:328/330` — the include lane already does this right, interpolating `spelt`.

Tokens carry line numbers (`moon.l:59`, the shared-lex comment) — so position
information exists at lex and parse time and is dropped at the raise, not absent.

## the fix: a diagnostic carrier

One value a stage may answer instead of a bare bad, carrying its own cause. Working name
**`gripe`** — a complaint that remembers what it's about. (Name offered, not settled;
per [[decisions-never-locked]] and the `grip` precedent in [[precedence-grip]].)

```
(gripe stage file line col msg)   ; any field may be () when unknown
```

`udie` grows a gripe-aware form: given one, print `file:line:col: msg`; given a bare bad,
fall back to today's `cc: <stage> error in <src>` so **nothing regresses while the stages
are converted one at a time**. That fallback is what makes this landable in rungs rather
than as one flag day.

### rung 1 — `cgfn refuses` names the identifier — LANDED

Highest leverage by a wide margin: 10 of 17 failures here, and it's flagged as painful in
three prior rungs of doc/moon-userland.md ("the refusal names the ENCLOSING function, NOT
the missing token"). mooncc refuses undeclared calls by design (no C89 implicit `int`), so
*every* missing libc prototype in the whole ladder surfaces through this one path.

At the refusal site the undeclared node is in hand — it's what failed to resolve. Answer a
gripe naming **the identifier**, keeping the enclosing function as context:

```
cc: dup-safer.c: undeclared 'F_DUPFD_CLOEXEC' (in dup_safer_flag)
```

This also retires the must-revert `cgexpr` probe hack (doc/moon-userland.md's cgfn-refusal
forensics recipe) — that recipe exists solely to recover what the refusal already knew.

**How it landed.** `gen.l` grows the carrier (`gripe`/`gripe?`/`okv?`, beside `bad?`) and
the `g`-stashed-cause plumbing: the cgexpr `var` refusal (the one path both an undeclared
value-use AND an undeclared call funnel through — `call-fixed` evaluates its head) pins
`(g 'undecl <name>)` before its `'bad`; `gfns` clears that pin per function and, on a
refusal, mints `(gripe () () () "undeclared '<id>' (in <fn>)")` when the pin fired, else
keeps today's `;; cgfn refuses` note + bare bad. A gripe IS a chain, so `cgen`/`cgen-obj`
guard `(gripe? r) r` *before* their `two?` check and ride it out to the driver; `moon.l`'s
new `ccdie` formats `cc: <file>:<line>:<col>: <msg>` (unknown file ← the source path,
unknown line/col elide) and every stage check flips `two?` → `okv?`. The address-of-an-
undeclared-name path (`clval`) still answers a bare bad — left for a later touch; not in
rung 1's 10. Laws in `law.l` flipped from `(! (cgn …))` to `(gripe? (cgn …))` for the
three undeclared seams. No message-content law: rung 2 reshapes the string with positions,
so a strict golden would only churn.

### rung 2 — positions into lex and parse errors

Thread the failing token's line/col into the gripe. Parse errors gain the construct where
one is known; a bare position is already most of the value, since it converts "bisect a
flattened TU with `gcc -E -P` over brace-balanced prefixes" into reading a number. The
four unexplained parse failures above are the immediate test: they should root-cause
themselves.

### rung 3 — `#error` echoes its text and file

`cpp.l:290` has both. The six `#error` hits in the sweep were all gnulib *configuration*
signals ("This platform lacks a pipe function", "Please port gnulib fseterr.c to your
platform") — i.e. not compiler bugs at all, but unreadable as-is:

```
cc: fsync.c:29: #error "This platform lacks fsync function, and Gnulib doesn't provide a replacement."
```

Distinguishing "mooncc can't compile this" from "config.h says this platform lacks the
function" is the difference between a compiler bug and a config edit, and right now the
message doesn't let you tell them apart.

## the declaration gaps (separate, mundane) — LANDED

Independent of diagnostics; the actual gnulib content work. Added to `crew/moon/include/`:

- **`float.h`** — was absent entirely; now the IEEE-754 characteristics (`FLT_*`/`DBL_*`/
  `LDBL_*`, x87 80-bit long double). Unblocked printf-frexp's *first* blocker (a later
  long-double codegen gap may still surface behind it — clearing one exposes the next).
- **`stdlib.h`** — `EXIT_FAILURE`/`EXIT_SUCCESS`, `reallocarray`, `getprogname`.
- **`unistd.h`** — `getprogname` mirrored here too (gnulib's progname reaches either).
- **`string.h`** — `mempcpy`, `rawmemchr` (GNU extensions gnulib reaches for).
- **`fcntl.h`** — `F_DUPFD_CLOEXEC` (1030) + `F_DUPFD` (0).
- **`sys/stat.h`** — `futimens` (`utimensat` was already there).

Cross-header provision where a header would otherwise fall through to `/usr/include` —
the standing rule from the tar rung. Verified: exitfail / cloexec / ialloc / dup-safer
one-liners compile; a genuinely-missing constant still names itself via rung 1.

## explicitly NOT doing yet

**`#include_next`.** Predicted as the top blocker before the sweep; it never fires.
gnulib's `include_next` lives in `.in.h` *templates* that the Makefile materializes into
real headers only when config.h says a replacement is needed — and this config.h describes
**glibc**, so gnulib stands aside almost entirely.

⚠ deferred, not dodged. The trigger is a config.h that describes **nolibc honestly**: at
that moment gnulib begins generating override headers and `#include_next` becomes
load-bearing. Two paths, and the measurement favors the first:

- keep config.h claiming glibc-like completeness, satisfy the claims in nolibc — gnulib
  stays out of the way (this is the current path, and it's what "config.h corrections are
  configuration, not patches" already amounts to);
- describe nolibc honestly — gnulib does more of the work but demands its full machinery.

**Defining `__GNUC__`.** Clang builds GNU projects by impersonating gcc (`__GNUC__ 4`,
`__GNUC_MINOR__ 2`) and implementing the GNU dialect; gnulib then special-cases
`__clang__` for the holes. That is the eventual path to "build everything" — the generic
non-GNU fallback paths in gnulib are bit-rotted from disuse. But claiming the contract
before `__typeof__` and statement expressions exist would push code *off* the fallbacks
and into holes, making failures worse. Revisit once the dialect surface is there;
`__MOONCC__` alongside it, so packages can special-case us the way they do clang.

## gates

`make test_moon` + `make test_raw` (the standing pair). The diagnostics pass touches
message construction, not codegen, so `test_raw`'s byte-identical expectations are the
guard that it stayed that way.

Re-run `tools/moon-sweep.sh` after each rung. The bucket table at the top is the
before-picture — and note the census keys are themselves the indictment:

```
  10 ;; cgfn refuses <fn>   (undeclared identifier, unnamed)
   4 cc: parse error   (no cause reported)
   2 cc: cannot resolve #include <hdr>
   1 cc: codegen error   (no cause reported)
```

The deliverable is those parentheticals disappearing — the failure list becoming
*self-explanatory* — more than the compile count going up. Rung 1 alone should retire the
first line; the four parse errors ought to root-cause themselves under rung 2.
