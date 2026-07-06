# cc -- rung 3 of the distro, the C compiler: THE PLAN

the plan of record for the chibicc-class C compiler, written in ai, emitting
through the holo books. drafted 2026-07-06; stage 0 LANDED the same day
(crew/cc/{lex,parse,gen,cc}.l + law.l, `au cc`, `make test_cc` -- the gcc
differential is born). trued up as stages land.

## the goal, and the fence

`cc` compiles **ai.c** -- and eventually the whole out/host build (ai.h's
inline world, host/*.c) -- into objects the system linker accepts, on x86-64
first, arm64 by parity. the closure it buys: ai-in-ai compiles the compiler
that compiles ai.c, so userland is fully self-hosting and the KERNEL is the
one imported artifact.

the fence, firmly: NOT the Linux kernel (GNU extensions, gcc stays), NOT an
optimizer (chibicc-class means correct and plain; the glaze is where this
repo optimizes), NOT a C library (glibc/musl linked, plus our own tiny
freestanding headers), NOT C++ ever.

## what ai.c actually demands (the census, 2026-07-06)

the subset is not "C11-ish" by taste -- it is measured off the target:

* the whole statement/expression core; switch (138 cases), goto (plain
  labels only -- NO computed goto), do/while/for, the comma operator.
* typedefs, structs, unions, enums (30+/12 uses), nested aggregates,
  a flexible array member (`struct env { ... word end[]; }`), designated
  initializers (`{.x = putcharm(2)}` -- the nif tables), ANONYMOUS unions
  and structs (ai.h:152,204 -- confirmed in), one compound literal.
* function pointers as first-class citizens -- the lvm dispatch tables ARE
  the program. pointer arithmetic throughout.
* varargs: va_list x4, variadic prototypes x24 (ai_push, the printers).
* the preprocessor in anger: object + function-like macros, variadic macros,
  ## token paste (17 uses -- the _(nif_x, "name", ...) tables), #if/#ifdef
  trees (AI_STAT, ai_tco, arch selection), #include.
* doubles (the gems: math.h's sin/cos/log/atan2/fmod...), NO long double.
* _Static_assert x4; __attribute__ x10 but ALL behind ai_ macros (ai_inline,
  ai_noinline) -- ai.h grows a plain-C branch under `__aicc__` and the
  attributes vanish. NO bitfields, NO VLAs, NO statement expressions.
* setjmp/sigsetjmp + signal handlers: LIBC's problem, not the compiler's --
  cc only needs the calls and the volatile discipline around them.
* the tail-threaded VM: `return Continue()` everywhere. gcc keeps the stack
  flat via sibling-call optimization (ai_tco=1). BUT ai0 already builds and
  passes the whole corpus with -Dai_tco=0 -- the return-based mode -- so
  guaranteed sibcalls are a PERFORMANCE stage, not a correctness gate. the
  first cc-built ai runs ai_tco=0; a later stage adds guaranteed tail calls
  (direct + indirect, the lvm shape) and flips ai_tco=1.

## the architecture (crew/cc/, every piece pure and lawed)

the aiutils/vi discipline: pure engines with law files, thin drivers, one
gate per stage. the pipeline, each its own file:

* **lex.l** -- text -> token list (pure). tokens carry file/line for
  diagnostics. lawed directly.
* **cpp.l** -- token list -> token list (pure!). macro tables as tablets,
  expansion + ## + #if evaluation + #include (the reader hands in file
  texts through a hook, so the laws feed includes as data). the census says
  this is a QUARTER of the work; it gets its own fuzz (macro expansion vs
  gcc -E, token-for-token).
* **parse.l** -- tokens -> AST + the type layer (one file to start; split
  types out if it swells). C's declarator grammar is the dragon; chibicc's
  incremental grammar is the map. AST as tagged lists, house-style.
* **gen.l** -- AST -> holo IR forms (pure). stack-machine codegen, chibicc
  style: every expression computes into r0, locals at frame offsets off
  holo's sp idiom. correct and dumb; the glaze is the fast path.
* **cc.l** -- the driver: files -> cpp -> parse -> gen -> holo assemble ->
  elf .o; then the system linker (`cc -c` first; `cc` calling ld is a
  convenience wrapper). registered in au (`au cc`).

### the seams to grow (owned by their threads)

* **holo**: inventoried 2026-07-06 -- it already carries div/rem,
  immediate shifts, setcc (`set cond d`), call/ret/sys, indirect jmp,
  scaled-index addressing, and an SSE2 double lane (x64). C still needs:
  SIZED loads/stores (ld1/ld2/ld4 + sign/zero extends; ld/st are 64-bit
  today), shifts by REGISTER count, an indirect CALL (callr -- function
  pointers are the lvm dispatch), double->int cvt, unsigned div/compare
  lanes, rip-relative/global addressing for the .o world, and the arm64
  float lane for parity. each lands with holotest.l's objdump goldens.
* **elf.l**: today it lays runnable ELFs; cc needs RELOCATABLE .o -- symbol
  table, .text/.data/.rodata/.bss, RELA relocations (PC32/PLT32/64/GOTPCREL
  minimum). a well-fenced extension with its own laws (readelf as oracle).
* **ai.h**: an `__aicc__` branch making ai_inline/ai_noinline/attributes
  plain no-ops. a core edit -- small, coordinated.
* **headers**: our own include/ for the freestanding subset (stdint stddef
  stdbool stdarg + declarations for the libc calls ai.c/host make: math,
  mman, unistd, signal, setjmp, stdio slice). dodges parsing glibc entirely;
  stage 7 decides header-by-header what the host files still miss.

## the ladder (each stage lands green and useful on its own)

0. **the spike** -- LANDED 2026-07-06: `int main(){return 42;}` -> tokens ->
   AST -> holo -> elf64 -> runs, exit 42, matching gcc's exit. one true-up
   against the draft: stage 0 lays a RUNNABLE static ELF straight through
   the existing elf64 (the crt0 stub -- call main, r0 to the exit syscall --
   emitted inline), no .o and no system ld touched; the relocatable-.o seam
   moves wholly into stage 3 where globals make it real. the lexer landed
   fuller than the stage needs (all keywords, maximal-munch punctuators,
   both comments, line numbers): stage 1 eats it as-is.
1. **integer expressions + statements**: all arithmetic/logic/compare ops,
   locals, if/while/for/blocks, int only. differential gate vs gcc -O0 is
   born here: same .c, both compilers, same stdout+exit, a battery that
   only ever grows.
2. **functions**: calls/prototypes/recursion, the SysV ABI (6 int regs +
   stack), then char/short/long + casts + sign extension. fibonacci runs.
3. **pointers, arrays, strings, globals**: &/* /[], pointer arithmetic,
   string literals in .rodata, initializers, sizeof. relocations get real.
4. **aggregates**: struct/union/enum/typedef, member access, nested layout
   + alignment, the full declarator grammar (function pointers!),
   designated initializers, flexible arrays, switch/goto/do. by here the
   torture set (a c-testsuite slice, vendored) joins the differential gate.
5. **the preprocessor**: cpp.l complete (##, variadics, #if trees,
   includes). gate: gcc -E vs cc -E token streams on the torture set AND on
   ai.c itself (the real headers, our include/).
6. **the long tail ai.c names**: varargs (the SysV register-save dance --
   the hairiest single item in the plan), doubles through the xmm ABI,
   _Static_assert, anonymous members, the one compound literal. gate:
   every host/*.c compiles; ai.c compiles.
7. **THE GATE**: cc-built ai.c (+ host/*.c, system ld, ai_tco=0) boots the
   egg and runs `make test` green -- the corpus under a cc-built binary.
   this is the rung's aiutils-feature-complete moment.
8. **the fixpoint + the flat stack**: (a) determinism -- cc(cc(ai)) builds
   byte-identical objects to cc(ai); (b) guaranteed sibcalls for the lvm
   shape, ai_tco=1, `make vmret` honest, benches vs gcc recorded.
9. **stretch, as appetite allows**: arm64 parity through the same holo
   seam (the IR is neutral; gen.l shouldn't care), our own static linker
   (elf.l already lays executables -- close the last binutils door), -g
   line tables.

## testing (the house discipline, restated for C)

* every pure piece lawed in crew/cc/law.l from day 0 (lexer goldens, cpp
  expansions, parser ASTs printed and compared, layout/alignment tables).
* the differential oracle is gcc -O0: same source, run both, compare
  stdout + exit code -- the GNU-byte-identical spirit, one binary deeper.
  the battery starts at stage 1 and ONLY grows; every bug fixed adds its
  regression.
* a seeded expression fuzz vs gcc (the Brzozowski precedent): generate
  random well-typed int expressions/statements, both compilers, compare.
  csmith-class whole-program fuzz is a stretch goal.
* `make test_cc` gates laws + differential battery; stage 7 adds the
  corpus-under-cc-ai run to test_all.

## size and pacing

chibicc is ~8k lines of C with tests; in ai, with the assembler/ELF layers
already standing in holo, the compiler proper should land around 4-6k lines
(cpp ~1k, parse+types ~2k, gen ~1k, lex+driver ~500). the memory's estimate
stands: a year of evenings at full scope -- but stage 7 is reachable well
before that, and every stage before it is independently alive (stage 1 is
already a lawed calculator-to-ELF; stage 4 compiles real single-file C).

## naming

crew/cc/ and `au cc` as working names; the crossing-layers name is gwen's
call when the thing first compiles something real (the naming-lore memory
holds the sources).
