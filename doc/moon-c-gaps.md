# moon-c-gaps — the C that mooncc doesn't accept (and the one it accepts wrongly)

A **living ledger** of mooncc's conformance gaps: what C it refuses, what it mishandles, and
where the root cause sits. Rows get deleted as they land — this is a status surface, not a
history. For the prioritised work items (`typeof`, `asm goto`) see `doc/moon-next.md`.

Everything below was **probed against `out/host/mooncc`** on 2026-07-18, with a binary built
after the 32-bit data-model fix landed. The recipes are included — reproduce rather than
trust. Every `parse.l` anchor was re-verified against the tree at that point; they survived
the 32-bit fix unshifted, but re-check before editing.

---

## 1. cfold — three operators that never fold (SILENT) — RESOLVED

**Fixed** (post): both defects landed together in `cfold` (`crew/moon/parse.l`). A `cond` arm
folds the SELECTED ternary arm only (the dead arm need not be constant, so `1 ? 1 : 1/0` is a
valid constant expression); `land`/`lor` now read the correct 3-element accessors (`<>e`/`<>>e`)
and use `!= 0` truthiness (a negative operand is true). `?:`, `&&`, `||` fold in constant
expressions, and the false-folding `_Static_assert`s below now correctly FIRE. `law.l` gained
goldens (both ternary directions, dead-arm div0, negative `&&`, `&&`/`||` both ways) plus the
soundness asserts (the three that must fire, the negative-true that must not, and a genuinely
non-constant assert still let by). `make test_moon` green; `test_raw` unregressed (no false
assert in love.c/host was silently riding the bug). The rest of this section is the record of what
was wrong.

The headline, because it is the only gap here that fails quietly. `cfold`
(`crew/moon/parse.l:663-697`) is the parse-time constant-expression folder. It had **two
distinct defects**:

**a. No `cond` arm.** The ternary node is `('cond c a b)` (built at `parse.l:567`). `cfold`
has arms for `num`/`bin`/`un`/`cast`/`land`/`lor` and falls through to `()` — "not a
constant" — for anything else.

**b. `land`/`lor` read one level too deep.** `parse.l:546` builds `('land l r)`, a *three*-element
node, but `cfold:693,695` use `<>>e`/`<>>>e` — the accessors for `('bin op a b)`, which carries an
extra `op` slot. So `a` reads the right operand and `b` reads past the end. `b` is never
`cint?`, and the fold can never fire. Copied from the `bin` arm without dropping a level.

Net effect: **`?:`, `&&`, and `||` do not fold in constant expressions.**

```
int a[1?1:2];        → parse error      int a[1&&1];  → parse error
enum { E = 1?2:3 };  → parse error      int a[1||0];  → parse error
int g = 1?2:3;       → codegen error
int f(void){ return 1?2:3; }            → OK    (the runtime path is fine)
```

### why this is worse than a rejection

`pstatic` (`parse.l:700-709`) folds the assertion with `cfold` and, by documented design,
**lets a non-constant assertion by**. Since `cfold` misclassifies these three operators as
non-constant, a *false* static assert silently passes:

```
_Static_assert(0, "boom");                        → correctly fails
_Static_assert(1 ? 0 : 0, "boom");                → COMPILES, never fires
_Static_assert(1 && 0, "boom");                   → COMPILES, never fires
_Static_assert(0 || 0, "boom");                   → COMPILES, never fires
_Static_assert(sizeof(int) == 4 ? 0 : 0, "boom"); → COMPILES, never fires
```

That matters concretely: `cpp.l:350-351` advertises `__STDC_VERSION__` 201112 precisely so
gnulib's `verify.h` takes its `_Static_assert` lane, and that header is built on exactly these
idioms. A static assert is the mechanism that would *catch* a layout bug — this one has a hole
in it.

Probe recipe (each needs a trailing declaration — see §3's `pstatic` EOF quirk):

```sh
printf '_Static_assert(1 && 0, "boom");\nint m(void){ return 0; }\n' > q.c
mooncc -c -t x64 -o /dev/null q.c     # compiles = the assert never fired
```

---

## 2. the fix for §1 — LANDED

Both defects landed together in one function (fixing the accessors without fixing truthiness
would have activated a third latent bug — the negative-`&&` case below). The shipped form of
each arm:

**The `cond` arm**, inserted after the `lor` arm (`parse.l:695-696`), before the trailing
fallthrough. Accessors: `<>e` = condition, `<>>e` = then, `<>>>e` = else.

```
(<e = 'cond) (: c (cfold <>e)
                (? (! (cint? c)) ()
                   (: v (? (c = 0) (cfold <>>>e) (cfold <>>e))
                      (? (cint? v) v ()))))
```

**The `land`/`lor` repair** — correct accessors *and* correct truthiness:

```
(<e = 'land) (: a (cfold <>e) b (cfold <>>e)
                (? (|| (! (cint? a)) (! (cint? b))) () (? (&& (! (a = 0)) (! (b = 0))) 1 0)))
(<e = 'lor)  (: a (cfold <>e) b (cfold <>>e)
                (? (|| (! (cint? a)) (! (cint? b))) () (? (|| (! (a = 0)) (! (b = 0))) 1 0)))
```

### the decisions, so they aren't re-derived

- **Fold only the selected ternary arm** (C11 6.6), not both. Both-arms is not merely
  stricter — it is *unsound here*: the divide guard at `parse.l:670` answers `()` for `b = 0`,
  so `_Static_assert(1 ? 0 : 1/0, "boom")` would fold to "not constant" and be let by.
  Selected-only closes strictly more of the hole.
- **Truthiness is `!= 0`, not `> 0`.** The existing arms use `(0 < a)`, which is wrong for
  negatives — `-1 && 1` is true in C but would fold to `0`. Currently masked because those
  arms never fold at all; repairing the accessors makes it live. Both must change together.
- **Optional refinement:** C11 6.6p3 gives `&&`/`||` the same latitude as `?:` — an unevaluated
  operand need not be constant, so `1 || 1/0` is a valid constant expression. Short-circuiting
  them the way the `cond` arm does closes marginally more of the let-by hole. The simple
  both-must-fold form above is correct for everything real; take the refinement only if a
  consumer wants it.
- **Do not change `pstatic`'s let-by policy.** `cfold` is deliberately partial (no floats, no
  comma, no address constants); making non-foldable an *error* converts every remaining gap
  into a hard failure across the LFS ladder for no gain on the cases that now fold. Tightening
  it later wants its own risk budget — instrument which real-world asserts fall through first.
- Accepted deviation to document in the comment: selected-only accepts `int a[1 ? 4 : x]`
  where gcc rejects it as variably-modified. Errs toward accepting, consistent with this
  file's whole posture (`()` = not constant = let it through to runtime).

### tests

Gate is `make test_moon`. Add constant-fold goldens to the `cfold` block in `crew/moon/law.l`
(the `(gdecl ((name long (num N))))` shape is at `law.l:112`), covering: both ternary
directions, a divide-by-zero in the dead arm, a negative condition, and `&&`/`||` folding both
ways. Add the `_Static_assert` refusals as the soundness assertions — including one that
confirms a *genuinely* non-constant assert is still let by, so the unchanged policy is pinned.

**Regression vector:** local scalar initialisers change AST shape — `int x = 1?2:3;` now emits
`(num 2)` instead of a `cond` node. Semantically identical, but grep `law.l` for constant
ternaries in initialiser strings before committing; goldens may shift.

### a separate, smaller quirk in the same function

A translation unit containing **only** a `_Static_assert` is a parse error; adding any
declaration makes it compile. `want` (`parse.l:34`) answers `>ts`, which is `()` when the
matched token was the last one, so `pstatic`'s `rest (want r4 ";")` (`parse.l:706`) cannot
distinguish "consumed the final `;`" from "no `;` found", and the `(! (two? rest))` guard on
the next line rejects. The house-style fix is already written for the same situation in
`tdeflist` (`parse.l:1037`, under the comment *"the remainder may be EMPTY (a typedef at
EOF)"*): peek for the `;`, then take the tail unconditionally. Different root cause from the
fold defects — separate commit.

---

## 3. the syntax ledger

Sweep of 40 constructs, x64: **33 pass, 7 fail** — all of C89 now passes. Grouped by *why* each
remaining one is missing.

### C89 — all RESOLVED

| construct | probe | status |
|---|---|---|
| ~~pointer to array~~ | `int (*p)[3] = &a;` | **RESOLVED** |
| ~~function returning function pointer~~ | `int (*g(void))(void){ return f; }` | **RESOLVED** |
| ~~brace elision in nested initialiser~~ | `int a[2][2] = { 1,2,3,4 };` | **RESOLVED** |
| ~~wide character constant~~ | `L'a'` | **RESOLVED** |

Wide/prefixed literals landed in the lexer (`wpfx` in `lex.l`): `L` (wchar_t), `u`/`U`
(char16/32), `u8` (UTF-8 string). mooncc carries no distinct wide type, so the prefix simply
drops — a char constant's value is identical, a wide string reads narrow. An identifier that
merely begins with `L`/`u`/`U` (no quote follows) is untouched. The whole C89 row is now clean;
what remains below is C99/C11/GNU.

Brace elision landed: the init tree is normalized up front (`unelide`/`normfill` in `gen.l`)
so an elided flat run is wrapped in explicit `('init ..)` before layout — the existing
fully-braced path then lays it. Global + local, arrays + structs, deep nesting; `[]` row
inference (`initcount` in `parse.l`) divides the flat count by the row's scalar-leaf count.

Pointer-to-array landed: the parenthesized declarator `(*p)` in `pdtor` (`parse.l`) took its
pointee type from what TRAILS the `)` — `(params)` a function (the pre-existing case),
`[dims]` an array (`('ptr ('arr t n))`), nothing a plain pointer. An inner `[n]` on the name
still makes it an array of those pointers (`int (*p[2])[3]`). Deref/stride/`&a` and the
fn-pointer + dispatch-table forms were already right in gen — only the declarator grammar
was missing. The remaining C89 bug (function returning a function pointer) is the same
declarator family: a `(*g(void))(void)` — a function declarator inside the parens.

### C99 — absent

`_Bool`; variable-length arrays (`int a[n]`).

### C11 — absent

`_Alignof`; `_Generic`.

### GNU extensions — absent

Statement expressions (`({ ... })`); computed goto (`&&label`, `goto *p`). Plus `typeof` and
`asm goto`, both assessed in `doc/moon-next.md` — not restated here.

### what passes, for contrast

The more surprising half. Designated initialisers (both `.field =` and `[i] =`), compound
literals, K&R definitions, bitfields including compound assignment, flexible array members,
variadic macros, `long long`, hex floats, anonymous unions, `restrict`, `static inline`, mixed
declarations, `for`-scoped declarations, `_Static_assert` itself, string-literal concatenation,
self-referential structs, enum trailing commas, multidimensional arrays.

---

## 4. target asymmetries

Function pointers in initialisers — the originally-reported bug — **are fixed.** All eight
shapes (global fn-ptr array, typedef'd, `&f`, struct member, array of structs) now compile on
all four targets; the `obj32-data-reloc-unsupported` scare is gone with the `.rel.data` work.
The struct-layout miscompile is fixed too: the probe now emits `adds r0, r0, #0x4` where it
read `#0x8`.

The thumb2 `la` gap is **fixed**: `la` lowers to the MOVW/MOVT absolute pair (movw16/movt16
fixups → R_ARM_THM_MOVW_ABS_NC/MOVT_ABS, section-bound addends baked in-field, a static fn's
thumb bit riding the addend), gated end-to-end by `make test_thumb2` (qemu Cortex-M7).

**64-bit `long long` is real on thumb2** (rung 3, the register pairs): on the t32 targets
`long long` canons to its own 8-byte type ('llong/'ullong — the 64-bit folds to 'long
everywhere else), lo:hi riding r0:r1 on the value protocol, r2:r3 the shuttle. Covered:
+, -, ×(UMULL/MLA), unsigned / and % (a self-contained 64-step restoring expansion — no
`__aeabi_uldivmod`, no libgcc), all shifts (constant and variable counts across the word
boundary), every relation (SUBS/SBCS, exact at the 2^53 tie), widen/narrow, `__builtin_clzll`
(CLZ), pair args (AAPCS32 even-odd pairs, 8-aligned stack slots, gp closing behind a stack
arg) and pair returns, pair globals/locals/members/derefs, `++`/compound assigns. The same
work fixed the pre-existing t32 >4-arg overflow ABI (4-byte slots, block-allocated) and the
t32 ≥8-byte struct-copy stride. 43 differential checks vs gcc ride `make test_thumb2`
(test/thumb2/{lib64,harness64}.c).

**thumb2 `leax` is fixed** — ADD.W Rd,Rn,Rm,LSL#n (one insn, both sources read before the
write), with LDR/LDRB register-offset fusing ldx/ldxb at disp 0; indexed-array differential
checks ride the test_thumb2 gate. thumb1's leax-call range gap remains (below).

**VFP doubles are real on thumb2** (rung 4): the SSE-named IR ops lower to fpv5-d16
scalar-double VFP (f0..f15 -> d0..d15, S[2n] the single views, d15/f15 the reserved
converter scratch); movqxr/movqrx move the gp PAIR in one VMOV; VCMP+VMRS gives the
a64-flavored NaN-honest flags, so the flo compare lanes ride the `arm?` cc branch. The
64-bit float bridges are gen sequences: llong->double exact (hi rides the U-converter and
scales by 2^32, one rounding; the signed face negates through, INT64_MIN survives) and
double->llong via mantissa peel + the pair shifters. u32<->double ride the U-converters.
`am.c` — the whole math floor — compiles and runs BIT-IDENTICAL to the host on the M7
(the seven transcendentals + Payne-Hanek, the test_thumb2 am leg). The same hunt fixed
four deeper t32 holes: sizeof(double) said 4 (tsz defaulted to the word), the operand
pool handed out callee-saved r5-r10 the frame never saved (pool now empty on t32),
[2^31,2^32) literals sign-smeared under pair-widening (now 'ulong), and `imnum` imaged
big-constant initializers as ff.. (bitwise ops are undefined on love bignums — bytes now
come off // and %). The lexer grew 'llnum/'ullnum: the LL/ULL suffixes force the pair
type on t32 (1ull << 40 works); UL literals past 32 bits promote per C99.

**love BOOTS on the M7** (port/mps2/, `make test_mps2`): the whole runtime compiled by
mooncc -t thumb2, linked by arm-none-eabi-ld, bakes its egg from source on qemu's
Cortex-M7 and passes spec laws (exit 42). The boot surfaced and fixed two deep holes:
objelf32's REL movw/movt addends truncated static-fn addresses past 32K of .text
(referenced .text labels now get LOCAL FUNC symbols, the gcc convention), and the t32
callr park in r12 collided with the far-mem scratch (the target now parks in a frame
slot, reloaded last before the call).

**by-value composites + varargs are real on thumb2** (rung 5): the sse2/'x2 lanes extend
to t32 — a {double,double} HFA (`struct ai_zn`) rides d-pairs in args, params, returns,
and call-result parking (the AAPCS32-VFP rule); an 8-byte one-sse blob rides the r0:r1
pair into a d-reg (bit-identical to the packed S-pair), a ≤4-byte int one rides r0's
word. Varargs: the prologue pushes r0-r3 under fp/lr, contiguous with the caller's stack
args; va_list is gcc's one running pointer (`stdarg.h` `__arm__` branch); anonymous WORDS
walk it (love.c's whole variadic surface — ai_push/ioprintf). En route: `__FLT_MAX__`
predefined, the %-pow2 lane gated through immok (no AND-imm on t32), imby materializes on
every arm, objelf32 learned R_ARM_THM_JUMP24. **love.c now compiles whole** for the M7 —
the undef set is exactly the freestanding seam, zero `__aeabi_*` — and test_thumb2 runs an
18-check gcc↔mooncc differential leg over the new lanes (45+45+9+18 total).

What remains, all loud scares (never silent):

- **mixed/int-pair 8..16B composites on t32** (an aone-'int 5..8B or a two-eightbyte
  not-both-sse aggregate by value), register-exhausted stack HFAs (9+ double args), and
  doubles/pairs/structs across a t32 VARIADIC seam — love.c reaches none of them.
- **signed 64-bit `/` and `%`** refuse (`cgfn refuses`) — love.c's lane is unsigned; wrap
  the unsigned expansion in an abs/refix sleeve when needed.
- **thumb1 varargs** — the pop-pc epilogue can't drop the r0-r3 block; vaspill-t32
  refuses v6-M whole.
- **thumb1 `leax`.** The indexed-call variant (`a[i]()` over a local array) hits
  `;; lea-range (r0 r4 8)` — the known scaled-indexed-address gap.

---

## 5. external corpora — recommendation, not wired

`test/cc/` already holds 89 gcc-differentiated files, so the harness exists; this is a corpus
question, not an infrastructure one.

- **c-testsuite** — ~220 tiny single-file tests with expected output, purpose-built for small
  compilers. Best first fit, and fast enough for the one-to-two-second ethos.
- **gcc.c-torture/execute** — ~1500 self-contained self-checking files (`abort()` on failure,
  `return 0` on pass). The de facto bar; tcc, chibicc, cproc and lacc all run it. Ships in the
  gcc source tarball, not installed here.
- **csmith** — random program generation for differential testing against gcc/clang; fits the
  differential-fuzz habit already in holo. Not installed.
- The commercial ANSI/ISO conformance suites (Plum Hall, Perennial ACVS, Solid Sands SuperTest)
  are not realistically obtainable. Noted so nobody goes looking twice.
