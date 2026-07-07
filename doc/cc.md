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
  today, LANDED), shifts by REGISTER count (LANDED), an indirect CALL
  (callr -- function pointers are the lvm dispatch; LANDED 2026-07-06, x64
  FF /2 + arm64 BLR, holotest 177), and-address-of-label (la; LANDED).
  still open: double->int cvt, unsigned div/compare lanes,
  rip-relative/global addressing for the .o world, and the arm64 float lane
  for parity. each lands with holotest.l's objdump goldens.
* **elf.l**: today it lays runnable ELFs, now assembling at ORG = the load
  vaddr so an abs64 data pointer resolves (cc stage 4d -- static char*/fn-ptr
  tables). the STILL-open .o world needs RELOCATABLE output -- symbol table,
  .text/.data/.rodata/.bss, RELA relocations (PC32/PLT32/64/GOTPCREL minimum);
  a well-fenced extension with its own laws (readelf as oracle).
* **ai.h**: an `__aicc__` branch making ai_inline/ai_noinline/attributes
  plain no-ops. a core edit -- small, coordinated.
* **headers**: our own include/ for the freestanding subset (stdint stddef
  stdbool stdarg + declarations for the libc calls ai.c/host make: math,
  mman, unistd, signal, setjmp, stdio slice). dodges parsing glibc entirely;
  stage 7 decides header-by-header what the host files still miss.

## the basement, and the go borrowings (gwen's direction, 2026-07-06)

two ideas to keep warm as the stages climb, neither committed yet:

* **a basement language under C, in the spirit of historical B.** the
  observation that seeds it: this compiler's core IS B-shaped already --
  one word type, typeless 64-bit registers, C's types a checking-and-
  conversion layer the stage-2b work laid ON TOP of the word core (sized
  memory ops at the edges, words in the middle). ai itself is B-kin the
  same way (the word is the one basic type). so the basement may want to
  become a real, nameable layer: the typeless word language cc's gen
  already speaks internally, possibly with its own thin surface syntax --
  useful for runtime shims, the crt0, compiler self-tests, and as the
  honest semantic floor the C dialect desugars onto.
* **aicc-specific syntactic refinements borrowed from go.** C is almost
  perfect; a few go conveniences might make the dialect nicer to live in
  without leaving C's semantics. candidates to weigh when the grammar is
  fuller (gwen picks): unparenthesized conditions with mandatory braces,
  := style short declarations, cleaner declarator spellings for the
  gnarly cases (function-pointer types especially). the fence stands:
  extensions, opt-in, never needed to compile plain C -- ai.c stays the
  gate and it is written in C.

## the ladder (each stage lands green and useful on its own)

0. **the spike** -- LANDED 2026-07-06: `int main(){return 42;}` -> tokens ->
   AST -> holo -> elf64 -> runs, exit 42, matching gcc's exit. one true-up
   against the draft: stage 0 lays a RUNNABLE static ELF straight through
   the existing elf64 (the crt0 stub -- call main, r0 to the exit syscall --
   emitted inline), no .o and no system ld touched; the relocatable-.o seam
   moves wholly into stage 3 where globals make it real. the lexer landed
   fuller than the stage needs (all keywords, maximal-munch punctuators,
   both comments, line numbers): stage 1 eats it as-is.
1. **integer expressions + statements** -- LANDED 2026-07-06: the whole C
   int expression ladder (precedence climbing; && || short-circuit
   normalizing to 0/1; ternary, comma; compound assigns and ++/-- desugared
   at parse, only ('post ..) surviving), decls with initializers and block
   scoping, if/else, while, for (all clauses optional, C99 decl-init),
   break/continue. codegen chibicc-plain: r0 the value, binaries push-left/
   pop-r1/compute-into-r1/mov (holo's two-address lowering allows d = a,
   never d = b uncommuted -- the alias-dst scare taught this), locals off
   the r5 frame, the frame sized after the body and rounded to 16. ints are
   8 BYTES until stage 2's types; shifts take CONSTANT counts (holo's
   register-count shift is stage-2 seam work) -- both guarded by gen
   refusals in the laws. the battery lives in test/cc/*.c -- 15 programs,
   compile-run-compare vs gcc -O0 in test_cc, growing every stage. one core
   wrinkle found and dodged: a value binding woven after a lambda that
   transitively forward-references its consumer draws a load-time book read
   (a benign ;; missing scare) -- op tables sit above the lambdas now.
2. **functions** -- the call half LANDED 2026-07-06: definitions with
   parameters (spilled off the SysV registers rdi rsi rdx rcx r8 r9 = holo
   r6 r5 r2 r1 r7 r8 into frame slots), calls with args evaluated left to
   right / pushed / popped reversed into the registers, recursion and
   mutual recursion through prototypes (parsed, recorded, skipped by gen --
   holo's two-pass labels do the real linking), the frame register moved to
   r4/rbp (r5 is rsi, ARG 2 -- the map bites the unwary). fenced and lawed:
   at most six arguments AND six parameters (the stack tail is later seam
   work); stack alignment at calls is ours alone until libc (stage 6).
   fibonacci runs -- fib(10) through real recursion, in the battery. the
   battery lesson worth keeping: differential programs must be UB-FREE --
   pick(++i,++i,++i) is unsequenced, and gcc legitimately disagrees.
   the types half LANDED the same day: char/short/long/int with real
   memory widths -- holo grew the whole sized family first (ld1/ld2/ld4
   sign-extending, st1/st2/st4 truncating, sx1/sx2/sx4 in-register, and
   shlv/shrv/sarv register-count shifts with the count PINNED to r1, x86's
   CL making the contract for every backend), all 24 encodings verified
   against objdump/llvm-objdump on BOTH arches and frozen as holotest
   goldens (172 pass). in cc: types ride declarations and params, casts
   and sizeof(TYPE) fold through parse, char literals lex with escapes,
   variable shifts unfenced. the ALU stays 64-bit -- sound because signed
   overflow is UB and the battery is UB-free; the OBSERVABLE width effects
   (stores truncate, loads extend, casts convert, and an assignment's
   VALUE is the converted one) all ride the sized ops. sizeof(expr) stays
   out until expressions carry types. locals still take 8-byte slots --
   width matters at the memory op, not the offset.
3. **pointers, arrays, strings, globals** -- LANDED 2026-07-06, and with a
   smaller footprint than the draft planned: instead of opening the .o/ld
   seam, holo grew ONE op -- (la d label), pc-relative address-of-label
   riding the EXISTING rel32 fixup on x64 (lea rip-relative) and a new
   byte-granular adr21 kind on arm64 (adr), objdump-verified both arches
   (holotest 174) -- and elf64's one load segment went RWX, so globals and
   string literals live as LABELED RAW DATA after the code, no binutils
   touched. the relocatable-.o seam moves to where libc forces it (stage
   6/7). in cc: cgexpr got TYPED -- every expression answers (type forms),
   so pointer arithmetic scales by pointee size (ptr-ptr differences
   divide back), dereferences load by pointee width, arrays decay to
   addresses, and lvalues have one door (clval: address in r0 + pointee
   type) through which x, *p, and a[i] all assign. string literals lex
   with escapes and land NUL-terminated in the data tail; globals are
   collected in a first pass so use may precede declaration order within
   the file. fenced and refused with laws: ptr+ptr, deref of a non-
   pointer, assigning arrays, star-array mixed declarators, array-local
   and non-constant/string global initializers. the battery reaches 33:
   double indirection, *(a+i) loops, string char reads, global mutation
   across calls, swap through pointers, pointer difference and compare,
   a strcpy-shaped buffer walk.
4. **aggregates** -- the semantic half (4a) LANDED 2026-07-06: struct and
   union with the real C layout rules (members aligned to their own
   alignment, the whole rounded to the widest; unions flatten offsets to
   zero), nested aggregates, arrays of structs and struct members that are
   arrays, ANONYMOUS struct/union members splicing their fields into the
   parent (ai.h's habit), self-referential struct pointers (linked lists
   walk), enum with values (constants FOLD AT PARSE), typedef (top-level),
   `.` and `->` (arrow desugars to (dot (deref ..)) and one lvalue door
   handles both), sizeof over every aggregate, switch with fallthrough as
   a flat marker list + compare-chain dispatch, do-while, goto/labels
   (function-scoped name mangling). the deep change: the PARSER CARRIES
   STATE now -- typedef names, enum constants, and the struct tag table,
   which rides out with the AST for gen's sizing (C cannot be parsed
   stateless; the lexer-hack wrinkle, met on schedule).
   the trap that cost the debugging hour: (two? x) tests PAIRHOOD -- both
   () and a text fail it; presence wants truthiness (texts net positive).
   the DECLARATOR DRAGON (4b) LANDED 2026-07-06: function pointers as a
   real type ('ptr ('fn)), the dispatch-table declarator T (*t[n])(..)
   (parameters BALANCE-SKIPPED -- gen calls untyped), a bare function name
   decaying to its address (holo (la)), a generalized call whose HEAD is any
   postfix expression ('call headexpr args) reaching the callee through the
   NEW holo (callr) -- indirect call, x64 FF /2, arm64 BLR, both objdump/
   llvm-mc frozen (holotest 177) -- after parking the pointer in callee-saved
   r3; and WHOLE-STRUCT ASSIGNMENT as a word-then-byte block copy (bcopy),
   so a = b and *p = *q copy structs. THE ai.c dispatch tables now compile.
   battery at 46 (fn-pointer call, dispatch table, struct copy by value and
   through pointers, fn-pointer parameter).
   INITIALIZERS (4c) LANDED 2026-07-06: brace and designated initializers
   ('init (item..), item plain | ('dfield name val) | ('didx n val)),
   nesting for arrays of structs; a LOCAL zeroes the slot then fills (cgfill,
   runtime values allowed), a GLOBAL bakes a constant byte image (cgimage +
   imgbytes, string-into-char-array and the flexible-array member []); [] size
   is inferred from the initializer (string bytes+NUL, or the highest brace
   index). battery at 52.
   LABEL-VALUED GLOBALS (4d) LANDED 2026-07-06: a global initializer whose
   value is a LABEL bakes an abs64 fixup ('fix 8 abs64 label 0) -- the label's
   ABSOLUTE load address -- so char *s = "hi" (a rodata string), &global, a
   decayed array, and THE ai.c PATTERN, a static (name, fn-ptr) table like
   struct Nif tab[] = {{"inc", inc}, ..}, all bake correctly. the mechanism:
   holo gained an abs64 relocation kind (x64 + arm64, both le64 of the target),
   and elf64 now assembles at ORG = the load vaddr (base + header) so labels
   carry absolute addresses -- pc-relative fixups are unchanged (the org
   cancels in target-site), so as/kernel/arm64 output is byte-identical; only
   abs64 reads the absolute address. gen's imgbytes emits the fixup for a
   pointer global (imlabel resolves the string/function/global/&global label),
   and the byte image mixes bytes and fixups so lengths go through imbytelen +
   a placement-flatten (imflat/imsort) instead of byte-indexed splice. the
   star-array fence lifted too: char *m[n] is now an array of pointers, so a
   string table char *m[] = {..} parses and bakes. holotest 179. still fenced
   for 4e: struct params/returns BY VALUE (assignment walks); local typedefs;
   case-label expressions; sizeof of an EXPRESSION (only sizeof(TYPE) today);
   a bare TOP-LEVEL fn-pointer array int (*t[n])(..) = {..} (ptop lays its own
   declarators, doesn't route through pdtor -- the struct-wrapped table works,
   which is what ai.c uses). battery at 56.
   ENV TRAP paid: `au` is `#!/usr/bin/env -S ai` + the cat, so bare `au cc`
   runs on the PATH `ai` -- a STALE install mis-runs current au (missing baked
   core like holo callr) and the heap grows unboundedly; the make gate is safe
   (m defaults to ./out/host/ai). probe cc with `./out/host/ai <au-cat> cc`,
   never a bare `au`, until `make install` refreshes the PATH binary.
5. **the preprocessor** LANDED 2026-07-06: crew/cc/cpp.l, TOKEN-BASED (it sits
   between clex and cparse, so an identifier inside a string/char literal --
   already one opaque token -- is never mistaken for a macro). object +
   function-like macros; rescan to a fixpoint under Prosser's HIDESETS (the
   blue-paint 4th token element, so FOO->FOO stops); # stringize; ## paste
   (fold + relex); ... variadics with __VA_ARGS__; #define/#undef;
   #if/#ifdef/#ifndef/#elif/#else/#endif over a precedence-climbing integer
   const-expr evaluator (defined X resolved first, undefined ids -> 0);
   #include through an incf hook (cc.l's incload searches the source dir for
   "quoted", crew/cc/include + /usr/include for <sys>; guards work because the
   included file shares the macro tablet); adjacent-string concatenation;
   __LINE__/__STDC__. #error fails the compile; #pragma/#line ignored. fenced:
   _Pragma, __COUNTER__, the GNU ,##__VA_ARGS__ comma elision. cc.l now rides
   lex -> CPP -> parse -> gen. battery 56->59 (macros, conditionals, a guarded
   #include header). laws: 18 pps/token goldens in law.l.
   TRAP PAID (the whole stage's hard bug): a lambda PARAMETER named after a
   sibling :-local gets shadowed by boxfix's "capture by location" shared cell
   (immune to shadowing -- the :-local owns the pin, the param reads the stale
   cell), so subst's macro-body arg silently read cppgo's whole define line.
   also the function NAME `adj##` (a `##` in a nom) fed the confusion. fix:
   give the param a nom bound NOWHERE else (`mb`) and inline the sibling helper
   as a closure-local. the tell was `;; missing <nom>` weave-scares at LOAD.
   NEXT gate to add (stage 6+): gcc -E vs cc -E token streams on ai.c's real
   headers + our include/.
6. **the long tail ai.c names**: varargs (the SysV register-save dance --
   the hairiest single item in the plan), doubles through the xmm ABI,
   _Static_assert, anonymous members (LANDED 4a), the one compound literal.
   gate: every host/*.c compiles; ai.c compiles.
   THE GEM LANE (6a) LANDED 2026-07-06: the `double` type as a first-class
   scalar riding the xmm register file. float literals lex (12.5, .5, 2., 1e9,
   3.14e-2, an f/F/l/L suffix consumed) into a 'flo token carrying an ai gem;
   the value lives in f0 (its TYPE is the flag -- 'double vs the integer lane's
   r0), materialized by fbits, the compile-time IEEE-754 encoder ported from the
   glaze (the 52-bit mantissa makes frac*2^52 exact). the whole value path:
   double locals + globals (an 8-byte image via fbits), + - * / (f1=left/f0=
   right through the gp stack, the scalar-double ops), the six comparisons
   (ucomisd + the UNSIGNED setcc -- lt->below, gt->above, le->be, ge->ae),
   unary minus (0.0 - d) and !d (d == 0.0), int<->double conversion (explicit
   casts AND implicit in mixed arithmetic / assignment / init -- asflo/asint
   bridge the lanes), doubles in arrays and structs (ldsd/stsd at the element),
   ternary and pointer walks. holo grew ONE op -- cvttsd2si (x64 F2 REX.W 0F 2C,
   arm64 fcvtzs toward zero), both llvm-mc-verified (holotest 181). fenced for
   6b (they need the xmm CALLING convention): a double PARAMETER, a double
   RETURN (a bare `return <double>` refuses -- write `return (int)d`), a double
   CALL ARGUMENT; also `float` (4-byte, needs movss/cvtss) and ~ on a double.
   battery 59->63 (arithmetic, the six compares, a loop accumulator + negate +
   ternary, doubles in arrays/structs/globals with pointer walks); law.l gains
   the float-literal/type/value-path/fence goldens. all match gcc -O0.
   THE CALLING CONVENTION (6b) LANDED 2026-07-06: the xmm ABI, so double params,
   returns, and arguments compile -- what 6a fenced. the parser now threads a
   SIGNATURE table (ps 'sigs: name -> (rettype (paramty..)) from every fn
   definition and prototype), returned as a 4th value from cparse and handed to
   cgen; the AST shape is unchanged (no golden churn), and a function's own
   return type is read back through the name already in `g 'fn`. cgfn spills each
   parameter from its SysV register by type -- integers from r6 r5 r2 r1 r7 r8
   (<=6), doubles from f0..f7 (<=8), SEPARATE counters. a call places each
   argument by the callee's PARAM type (converting the arg to it -- an int into a
   double slot cvtsi2sd's, a double into an int slot cvttsd2si's), or by the
   arg's own type when the callee is unknown (an indirect call); the result rides
   f0 for a double-returning callee, r0 otherwise. a `return <double>` in a
   double function leaves f0; in an int function it truncates. the conversion
   fixes rippled to every scalar-store site (a double value into an int local /
   assignment / call arg goes through asint), and to every CONDITION site
   (if/while/for/do/ternary/&&/|| fold a double to `d != 0.0` via ctest, since a
   bare double left its bits in f0 where `cmp r0 0` reads garbage). the classify
   bug paid: a scalar param type is an ATOM, so `(two? pty)` is false -- test
   presence with `pty` itself (a type is truthy, () absent). battery 63->65
   (double add/scale/poly with int->double and double->int arg conversion, a
   double-returning recursion + a 6-double fan). still deferred to 6c: DEFINING
   variadic functions (va_list/va_start/va_arg -- the register save area),
   calling variadic functions (al = the vector-register count), _Static_assert,
   the one compound literal, and `float` (4-byte).
   VARARGS + _Static_assert (6c) LANDED 2026-07-07: variadic functions define,
   call, and walk their extra arguments, and _Static_assert folds at parse.
   the `...` becomes the signature's third slot -- a variadic BIT (ps 'sigs is
   now name -> (rettype (paramty..) variadic?)); pparams returns `(params rest
   1)` when it meets `...` after a named param. cc uses a SIMPLIFIED all-stack
   variadic ABI, doc'd AS SUCH (not SysV interop -- that waits for linking in the
   gate): a variadic CALL pushes every argument as an 8-byte stack slot (arg0 at
   the lowest address, a pad word when the count is odd so the callee sees a
   16-aligned frame), and pops them after; the variadic CALLEE reads its named
   params straight from positive frame offsets ([rbp+16+i*8], via `place`, no
   register spill and no save area), and va_arg walks a plain char* cursor 8
   bytes at a step. so <stdarg.h> (crew/cc/include/, ours -- gcc uses its own in
   the differential, both self-consistent) is three one-line macros over the
   builtins: va_start -> (vastart v) seeds the cursor at the first vararg slot,
   va_arg -> (vaarg v type) reads the slot and steps, va_end -> (vaend v) is a
   no-op. _Static_assert(const, "msg") folds its constant through `cfold` at
   parse: a true one vanishes to a (tdef) no-op marker (block scope handled by a
   (= k 'tdef) () arm in cgstmt), a false one REFUSES the whole compile. the va
   builtins are recognized in pprim (__builtin_va_start/_arg/_end); va_arg parses
   its type argument through pcty. battery 65->68 (int & pointer varargs with the
   align-pad path, double varargs behind a named double param, a tag-selected
   int/double mix, file- and block-scope _Static_assert with sizeof folds); law.l
   gains the signature-bit / va-form / const-fold-or-refuse goldens. STILL
   deferred (6d, small): the one compound literal and `float` (4-byte). the
   simplified ABI is a KNOWN gap: it does not interoperate with libc's printf
   until the gate wires real SysV varargs -- that's stage 7's linking moment.
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
