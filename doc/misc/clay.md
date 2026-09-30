# clay -- C as love data

a C AST written as love data (`src/apps/moon/clay.l`), a shower that renders it to C text,
and a validator (`clay-ok?`, the `gripe` protocol). its job is the regions of the C where
one table has several readers: the table lives in love, and every reader -- the C, the
linker script, the proof -- is laid from it, so none of them can drift from another.

clay is not a plan to translate love's C. most of the C has nothing to generate, and
there C is the right medium for C.

## the criterion -- generate, don't transcribe

a region earns clay when there is something to GENERATE: a repetition C cannot abstract
(an X-macro, a macro redefined per arm, a hand-kept roster with a second copy somewhere
else) or a table with more than one reader. name the repetition first; if there is none,
the answer is no.

`src/inle/mkvec.l` is the model: the x86 stubs and a64 vector slots were `.rept` loops in
GAS, and a love loop says the same thing.

the α-equivalence cluster (`salpha`/`shash`, 156 lines) was converted and reverted, and the
revert is the evidence: it was picked because it was EASY to convert, the love came to 454
lines laying 313 lines of C, and it bought no verification (below).

## the parse is enough, for verification

a region does not have to be authored in clay to be modelled: `cparse` already hands back a
faithful clay term (the α cluster round-tripped 10/10). the parse is post-cpp, which is
fatal for GENERATION -- love's C is one text for many seats and `test_fixpoint` wants it
byte-identical -- and fine for a MODEL, which should be about what the compiler compiles.

so authoring is a generation cost only. and a term is not yet a theorem: proving anything
about C needs a semantics for it, and for general C that is a CompCert-sized job. what is
in reach is a shallow embedding of a narrow subset -- fixed-width integers, arrays without
aliasing, no escaping pointers -- which fits the bignum limb helpers, already modelled
against `Z` in `test/proof/rocq/big.v` and fuzzed by `big_drive`. the prover target is uu
(`src/love/boot/uu.l`); rocq and lean are export legs, as `mx2coq.l`/`uu2coq.l` are.

past that, differentials pay better than proofs. the compiler stays trusted whatever is
proved about the datum, and every mooncc codegen bug in the run of five that prompted this
plan was caught by a differential, none by the corpus.

## macros in generated C

the generated file is allowed macros, and uses them where they compress: the generator
owns the list, and C's preprocessor only spells it out. `(cpp-def "name(args)" BODY)`
takes a parameter list in the name and a spelling body, continuation lines included.

that is different from the X-macros rung 4 deleted. those were the only COPY of the
roster, walked by hand-kept consumers; a generated X-row list is laid from `nifs.l` and
checked for drift, so the roster still has one home.

## what has landed

numbered as code comments cite them.

0. **clay itself.** the node grammar as data (`clay-tags`), `clay-show`, `clay-ok?`.
1. **G1**, the round-trip gate over `test/cc/`.
2. **the dispatch matrices.** `mx.l` is the table; `mx.h` is laid from it through clay, and
   `src/tools/mx2coq.l` reads the same table for `test/proof/rocq/mx.v`. `tools/mxdump.c`
   and its `$(CC)` step went.
   - 2b. the kind lattice (`enum q`, `KN`) laid into `kinds.h` from the grid's own roster.
   - 2c. the rep roster (`enum d`) split off it, so the exhaustive switches lost their
     defaults and a new sentinel is a `-Wswitch` error at every site.
   - 2d. `sdef`, struct definitions.
3. **the node shapes the VM definitions need**: attributes on `fn`, `restrict`, the `ret`
   prefix (`ai_musttail return`), `_Static_assert`, flexible members.
4. **the nif + instruction registry.** `nifs.l` is the roster; `nifs.h` lays the one
   `union u nifs[]` table (each nif a run inside it), `def1` with each run's offset, and
   `ai_nif_lvm` for the splice JIT. the X-macros `nifs`/`insts` and `s1`..`s5` went.
5. **the preprocessor nodes** `cpp-def`, `cpp-undef`, `cpp-if`, emit-only. first consumer:
   the data slot layout, one `mx-strides` row giving the stride to both `kinds.h` and
   `love_data.ld`.
6. **four readability shapes** kept from the reverted α conversion (`proto` with a
   signature, valued `edef` constants, index sugar through `dot`, `chr`), and
   `src/tools/clay-g2.l`, the conversion gate.
7. **`nifs.h` and `mx.h` as rows.** the roster is laid once as `ai_nif_rows(P, C)` (a plain and a
   curried row shape, the run offset in each) plus `ai_inst_rows(I)`, and `nifs[]`, `def1`
   and `ai_nif_lvm` are three short consumers of it. `mx.h` likewise keeps `mx-rows`' own
   shape: `mx_row` fans a row's seven lanes out to the fourteen columns, one macro per row
   names its seven, and each grid names a row per kind. the objects compile identical to
   the expanded forms.

## next

1. **the elementwise op table** (`num.c`). each op's meaning is written twice: inline in the
   `vbin_fill` fast path's `VBF` arms, and in `vop_flo`/`vop_int`/`vcmp_*` for the broadcast
   loop. they agree by hand, and already disagree on coverage -- the bit ops exist only in
   `vop_int`, so they fall out of the fast path's switch into the slow loop. one row per
   (op, domain) would lay both paths and a uu model of the op.
   try C first: a fast path calling a `static inline` `vop_int(vop_add, ..)` with a constant
   op is one spelling if mooncc's inliner and cfold turn it into the same loop. the table
   is owed only if they do not.
   then count the rest of the `_fill` family (`arr.c`) for the same per-op switch.
2. **`image_extra_aps`** (`snap.c`), a hand-kept roster whose order is the heap image's
   encoding. its first eight entries are the data sentinels in `enum d` order, which
   `mx.l` owns, and four more (`lvm_unc`, `lvm_ret`, `lvm_ap`, `lvm_jump`) are also in
   `nif-insts`. lay it from those rosters plus a short list of its own.
3. **`cc-clay`**, clay as a moon frontend input beside `cc-parse`: `clay-ok?`, derive `stag`
   and `sigs` (reusing parse's `playout`), then `cgen-obj`. it gives G3 a leg with no C
   text, and needs no region converted.

## struck

- **the `lvm(..)` declarator, `c0`'s `Cata`/`Ana` signatures, the VM loop.** C's macros do
  those jobs well; the ~1000 macro sites there are call-shaped and would be transcription.
- **the α cluster, the GC, the heap-image codec.** no repetition to generate; the parse
  serves any model of them.
- **dtoa.** the printer moved into `src/love/boot/post.l`.
- **whole-file capture of love's C**, and with it `love.c.l` as a source.

## the gates

- **G1 faithfulness** (`make test_clay`): `(cparse (clay-show c)) == c` structurally over
  `test/cc/`. it measures cparse's lossiness on the way in, so emit-only nodes must leave
  its reading unmoved.
- **G2 conversion equivalence** (`src/tools/clay-g2.l`): parse the old and new translation
  unit whole and compare named definitions as trees. run once, at a conversion.
- **G3 differential**: the generated C built by the system cc and by mooncc, and across
  a64/rv64, answering byte-identically (the `test/gate/ulp.sh` / `ccarch.sh` shape).
- **drift**: generated files are checked in; `test_clay` re-lays every `mx_gen` member and
  `cmp`s it. regeneration is a gate, not a build step, so a fresh tree builds from the
  committed files. `make mx` re-lays them.
- **`test_fixpoint`**: generated C must rebuild to the byte under mooncc.
