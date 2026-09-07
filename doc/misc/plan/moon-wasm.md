# plan: a wasm backend for mooncc

Drop emcc — the last foreign tool in a product path. What emcc actually supplies
today is small and known: clang→wasm codegen, a libc (malloc, memcpy, clock,
exit-as-throw), and the JS glue (`Module`, ccall/cwrap, heap views). The build is
the core's TU roster (`love_tu` in mk/common.mk) plus `am.c` and `src/port/wasm/host.c`,
which carries quay by unity include — no FS, no asyncify, no threads, twelve exported
verbs plus malloc/free (the five of the repl, and the console arc's mirror, palette,
unfold, key, runnable, alive), and `-Dai_tco=0` — a lane that already exists and is
already gated (`test_wasm`, node over the emcc build). The 32-bit port ledger
(`src/port/wasm/32bit-findings.md`) is paid. The core already declines the JIT on
`__wasm__`. So the *runtime* is ready; what does not exist is the compiler half.

## why this is not a sixth `defbackend`

Every holo backend is a `{lower, patch}` pair — a byte emitter under a two-pass
address-assigning driver. Wasm breaks each assumption that driver rests on:

- **no addresses.** No fixups, no branch relaxation; a module of index spaces
  and LEB128 varints. obj.l/link.l/elf.l (~2,100 lines) generalize to none of
  it. (rung 0 confirmed the shape: the writer reopens `(module 'holo` for the byte
  leaves and `hexs`, and touches neither lay nor resolve.)
- **no jumps.** The IR is flags-and-jumps and gen.l emits unrestricted labels
  (C `goto`, case labels at depth); wasm demands structured control flow. A
  relooper — or a dispatch-loop fallback — has no analogue anywhere in the tree.
- **no registers.** Wasm has typed locals; the accumulator protocol and the whole
  residency layer (the one build's seats -- upar/ulloc off alive -- the pool,
  and the cs grants) model a 16-register
  file with a callee-saved contract that stops meaning anything. And locals are
  not addressable, so the r4 frame decision inverts into an escape analysis
  (love.c takes addresses of locals via alloca 42 times). ⚠ the residency half of
  this bullet is the cheapest of the four and is now PRICED: rung -1 ran the layer
  out on x64 and the compiler still reproduces itself byte for byte. What stands is
  the rest — the frame, the convention, the pins.
- **mandatory validation, typed instructions.** holo's IR deliberately forgets
  width past the op name; a module must know i32 from i64 per value.

Scale anchor: riscv — a fifth register-machine ELF target riding a64's lanes —
cost ~1,160 lines. Wasm shares neither property; budget a low multiple of that.

## the ladder

- **rung -1 — the empty pool, on hardware that debugs. ✅ RUN.** gen.l's shuttle
  (`tor0` + `spush2` + `tor0` + `spop2`) IS a stack machine spelled through memory,
  and `ralloc` answering `()` — dry, the caller keeps the shuttle — is a
  configuration every `cgbin` path already handles, because callish/shift/constant
  sides force it today. t32 goes further and ships with no operand pool at all
  (`tpool`, gen.l — AAPCS32 leaves nothing caller-saved to pool), gated by
  test_thumb1/2. Two ablations on x64, one binding each:
  - **A, the accumulator protocol** — `ralloc` dry always: `.text` 896,896 →
    921,472 (**+2.7%**), +4.2% corpus cycles, 80 of 866 laws fail.
  - **B, the pool and the locals homes** — `tpool ()`, and `pools` filters from it
    so the homes go with the pool: `.text` → 937,856 (**+4.6%**), +4.9% cycles,
    106 laws fail.

  ⚠ B is NOT the whole residency layer — `cspool` is a separate file and survives
  it. Ablating that too (`cspool ()`, and both together) costs +6.6% and **+12.5%**
  corpus cycles; the full split and its economics are doc/misc/moon-gauge.md. What
  matters here is that **wasm pays neither half**: a wasm local is unbounded and
  engine-allocated (so the pool and the homes have nothing to buy) and it survives
  a call by construction (so the cs seats have nothing to buy). The 12.5% is the
  price of the ablation on x64, not the price of the wasm lane.

  Every configuration holds `test_cts` at 207/220 with the same 12 clean refusals
  and the same 1 wrong answer, and every one holds the fixpoint: the ablated mooncc
  compiles every TU, links love1, and love1 bakes its own image and rebuilds itself
  byte-identically.
  ⚠ every failing law is a register identity or a residency count
  (`(member? '(add r9 r1 r14) epwf)`, `(= 0 (stc lp1f))`, wraps/splds/movs/ldc9);
  not one is a value, a type, or a control shape. The laws pin the LAYER, not the
  meaning — a lane change churns them, and that is not breakage.

  So the residency layer is removable — the compiler still reproduces itself exactly
  without it — and the wasm lane's register story is the empty arm of a binding that
  already has one. Untouched and still rung 4's: the pinned lanes, the SysV
  convention wasm replaces outright, and the r4 frame's address-taken escape
  analysis.
- **rung 0 — the module writer. ✅ LANDED** (`src/core/holo/wasm.l`, ~150 lines).
  LEB128 over `//` and `%` (a u64 pattern past the fixnum stays exact), names, vectors,
  the twelve sections, an opcode table where each row names its immediate shape, and
  `wasm-emit` over one tablet — types, imports, funcs, table, memory, globals, exports,
  elem, data, start. An instruction is a form, `(i64.const 5)` `(br_table (1 0) 2)`
  `(i64.load 3 8)`, the same data shape as holo's IR; an f64 constant arrives as its
  bit pattern (gen.l's `fbits`), so the writer encodes no float. Memory64 is the
  default (`'mem64 0` asks the wasm32 shape). Proven against two foreign readers:
  every instruction golden in test/holo/golden.l is the byte string binaryen's wasm-as
  lays for the same text, and `test_holowasm` lays test/holo/wasm.l's module, validates
  it under wasm-opt, and runs it under node — an import called from `start`, an i64 ALU,
  a data segment, a store and load at a 64-bit address, a `call_indirect` through the
  table, and a function laid as rung 1's dispatch loop (a label local, one `loop`, one
  `br_table`, every body branching back), which summed 0..100 on the first run. Node's
  own word that the memory is 64-bit: `grow` speaks BigInt.
- **rung 1 — control flow by dispatch loop. ✅ LANDED** (`wasm-fn` in wasm.l, ~110
  lines): a holo IR function → `(locals . body)`, one `loop` + `br_table` over a label
  local, trivially correct for arbitrary labels, no reducibility analysis. The shape:
  every `(label l)` opens a segment, the entry is segment 0; the loop wraps k+1 nested
  blocks, so falling out of block j runs segment j and j's tail falls into j+1 as the
  IR does; `jmp` sets the local and branches to the loop at depth k−j, `br` does the
  same under an `if`, one deeper; after the loop stands `unreachable`. The convention
  the lane now owes (revisable at rung 4): r_k is local k, r0..r(n−1) the params and r0
  the answer — the a8 shape — then lab (i32) and A, B (i64), the last `cmp`/`test`'s
  operands, which is what the flags become; a `br`/`set` recomputes its condition off
  them, so `(br lt x) (br eq y)` after one `cmp` reads as it does on x64. A `call`
  clobbers only r0: a callee's locals are its own, the doc's "cs seats have nothing to
  buy" made literal. Covered: li/mov, the ALU and shifts (register or immediate), the
  extends, cmp/test/set with every condition but vs/vc, the sized loads and stores with
  a negative displacement folded into the address and the scaled `ldx`/`stx`, lea, call
  through an environment {name (funcidx nparams)}, ret, trap. Owed to later rungs and
  refused by name: sp and the frame, la, callr, jmpr, sys, the double and 128-bit lanes.
  Proven under node in test/holo/wasm.l: a counted loop, fib through `call`, labels that
  fall through, the memory ops, the flags — 14 checks, wasm-opt valid; two form-level
  goldens pin the skeleton. A real relooper is a later optimisation rung, not a
  prerequisite. ⚠ a multi-line `@` arm body must be ONE form: a bare `a + b` at the arm
  level reads as further pattern/body pairs and silently shifts every arm after it.
- **rung 2 — the type law. ✅ LANDED.** Chosen (revisable): target memory64 and keep
  holo's own law — the ALU stays 64-bit (every value an i64), widths bite only at
  memory and the casts. This keeps the fixnum width and skips the thumb-shaped 32-bit
  gap column whole — the f32 reals and ~30-bit fixnums in 32bit-findings.md are
  platform facts of the emcc lane, not of this one, and the `wint`-gated asserts run.
  The engine risk is gone: node 26 and binaryen 132 on this box accept an i64 memory;
  Chrome 133 and Firefox 134 shipped it unflagged in early 2025 and it is in the Wasm
  3.0 standard, Safari trails — the page gets tried there before rung 3 lands. What
  memory64 does NOT change: a function pointer is still a table index, and
  `ai_data_section` stays 0 (byname) — a module lays no tiled sentinel section. If
  memory64 disappoints somewhere, the fallback is the writer's wasm32 shape + i64 ALU
  with address wrapping.
  What the law became in code, where typing actually bites:
  - **the function type is the arity.** `wasm-program` lays one type per arity in use,
    `(i64 × n) → i64`, imports first in the index space and every function in the
    table at its own index, so a function's address is its index and a call through
    the table needs only the count. A void function answers a dead r0.
  - **the double lane is f64 locals** f0..f15 (locals 19..34), FA FB the last
    `ucomisd`'s operands (35, 36). The float conditions are rv64's, the flagless target
    gen.l already accepts: gt/ge unordered-false, lt/le their complements (so be/below
    fire on NaN), p/np both-ordered. A branch reads which compare came last the way
    rv64's flag memory does: in emission order, the lowering's one mutable cell.
  - **the narrow keeps x64's law.** gen.l builds a float image as `cvtsd2ss` then
    `movqrx`, so a narrowed f-register holds the single's bits in its low word (demote,
    reinterpret, extend, reinterpret back); `stss` stores that word, `ldss` and
    `cvtss2sd` read it back. An unpromoted register is never an operand, as on x64.
  - **the conversions saturate** (`i64.trunc_sat_f64_s/u`): riscv's law; x64's
    indefinite value differs, and gen.l relies on neither.
  - **the overflow flags exist.** `adds`/`subs` leave V, rv64's `(d^a)&(d^b)` sign, and
    the flags then read d against 0 as rv64's do; `vs`/`vc` read V. `mulo` has no wide
    multiply to lean on, so it is the quotient check, guarded where the division would
    trap (−1 against the minimum).
  Proven under node: a double loop, `a*b − a/b` exact, the eight float conditions
  packed as bits for ordered, equal and NaN operands, a float branch, saturating
  conversions of a negative taken unsigned, the float image narrowed, stored, its bits
  read off `movqrx` and widened back to `Math.fround`, and both overflow shapes — 8
  checks on a second module laid whole by `wasm-program`, wasm-opt valid.
  ⚠ `nil?` is the falsy test, a net over the WHOLE value: a function list carrying the
  minimum i64 nets negative and a `(? (nil? items) ..)` presence check dropped the
  function section in silence. The writer asks `two?` or `(= x ())`, never `nil?`.
- **rung 3 — the environment. ✅ LANDED** (`src/port/wasm/loader.js`, ~110 lines).
  `Love({wasm, print, printErr})` instantiates love.wasm and answers the Module the page
  already drives: `ccall`/`cwrap`, `UTF8ToString`/`stringToUTF8`/`lengthBytesUTF8`,
  `_malloc`/`_free`, the `HEAPU8`/`HEAPU32` views (getters, so a grown memory is never
  a stale view), every export as `_name`, and `ExitStatus` thrown on exit with its code
  — test.mjs's contract. It is also the global `Love`, so the page loads it as a module
  script and repl.js drives it unchanged. The module imports ONE function, `env.__ai_sys`
  — nolibc's one OS door, so the C runtime compiles as it is — and the loader is the
  kernel under it, speaking linux's numbers: `write` to print/printErr, `mmap` as a
  page-aligned bump over `memory.grow` (nolibc's malloc takes 1 MB arenas and never gives
  them back, so munmap is a no-op), `clock_gettime` laying a timespec, `exit`/`exit_group`
  throwing, `writev(-1)` answering -EBADF (nolibc's kernel probe, which must say linux),
  and ENOSYS for the rest. The type law crosses the boundary here: every param is an
  i64, so a Number becomes a BigInt on the way in and a Number on the way out; a pointer
  handed to wasm is a BigInt and a view's offset a Number. host.c's `emscripten.h` need
  was the one macro, now guarded. No WASI: the browser frontend already lives without
  FS, env, subprocess, signals. Proven on a mock of the artifact's face (test/holo/wasm.l's
  third module: malloc over a bump, ai_init asking the clock and the probe, ai_eval
  copying a heap string into the out buffer and write(1)-ing it, ai_grow mmapping a page
  and landing a word on it, ai_exit) driven by test/holo/loader.mjs exactly as test.mjs
  drives the real one — 13 checks. What the page changes when the artifact ships: the
  `<script>` for love.js becomes `type="module"`, and love.wasm sits beside it.
- **rung 4 — gen.l's wasm lane. ✅ LANDED, and gen.l has no lane.** The probe that
  decided it: gen.l's rv64 output for a small TU is a compare chain for `switch`, the
  `sp`/`fp`/`lr` frame with every parameter spilled (rv64 homes none), `la` for every
  address, `raw` only under inline asm and two sync builtins — everything the wasm
  machine wants and nothing it cannot carry. So `-t wasm` runs gen as rv64 under
  `__wasm__` predefines, and `src/core/holo/wasmfn.l` is the machine under that lane
  (the lowering of rungs 1–2, now over r0..r26, `fp`, `lr`, and `sp` as global 0 — the
  shadow stack, where `push`/`pop` move 16 as the arm family's do and gen.l's frame
  offsets count on it) plus `wasm-link`, the whole program off gen's objects. The one
  convention change is the point of the rung: **one function type for the whole
  program**, `(i64 × 8, f64 × 8) → (i64 i64 f64 f64)`, r0..r7 and f0..f7 in, r0 r1 f0 f1
  out — a 16-byte aggregate rides a pair, and the battery's 85-aggval is what said so.
  A `callr` carries no arity and C lets a call disagree with its callee, so every
  function wears the one type, sits in the table at its own index, and a function's
  address IS its index: `callr` is `call_indirect`, gen.l's tail call (`la` then
  `jmpr`) is `return_call_indirect`, a `jmp` to a function `return_call`. Rung 2's
  per-arity types survive only for the hand lane. The link: every tu-local label
  wears its tu's number (two statics never meet); a weak definition with a strong twin
  keeps its body under a private name; a second function label on unlaid code is an
  alias; the data is laid section-major across the tus (rodata, data, love_nifs,
  .love.image, the named sections, then bss) with the pointers in it resolved to
  addresses or indices, and the linker's own names synthesized — the
  `__start_`/`__stop_` brackets of love_nifs, love_rela (empty: nothing relocates) and
  every named section, the data and bss bounds. Undefined names must be in the
  import list, one today: `__ai_sys`. The driver: `mooncc -t wasm` (the roster in
  post.l knows the word), an object is the gen tuple as text, the runtime is nolibc's
  members compiled for wasm, cached whole under the archive's key law and pulled by
  need off a (defs . refs) ledger; crt0 hands nolibc's `__ai_start` a stack laid in
  data (argc 1, an argv, empty envp and auxv) and exits with its answer through the
  import. nolibc's BSD translate lane stays off under `__wasm__`. `src/port/wasm/run.mjs`
  runs such a module the way a shell runs an executable.
  **The gate is `test_ccwasm`**: ccarch.sh's procedure with node as the machine, the
  158 programs of test/cc — 153 answering exactly as x86-64 does, stdout and exit
  status, and the five 128-bit-and-friends refusals asserted (rv64's own list, since
  the lane is rv64's). Four faults it found, all in the machine and none in gen: the
  16-byte push, the alias label, the sync builtins' raw idioms — which the machine now
  recognises by their bytes (a fence is nothing on one thread, the atomic swap an
  exchange) — and the pair return, which widened the universal type.
  ⚠ `distfiles` in the Makefile is the image's roster, a second list beside
  `moonfiles`: a holo file in one and not the other is a compiler that works from the
  cat and a `love mooncc` that says `missing`.
- **rung 5 — the gate. ✅ LANDED (2026-09-06).** `test_wasm` now rides moon's own
  module: `make wasm` lays `out/wasm/love.wasm` (love's TUs plus the horn and the seat's
  host.c through `mooncc -t wasm`, `-Dai_tco=0`), and the gate runs the whole love corpus
  (**4765 laws**), the console apps (`screen.mjs`), and the horn's PCM into WebAudio
  (`horn.mjs`) over it under node — no emcc anywhere in the gate. The three failure
  classes the survey named are all closed:
  - **the OS/word-width tangle.** The wasm64 module is a **64-bit** word build
    (`max-charm` = 2^62−1, reals f64, bignums, RNG full-width), so `word` is *true* here
    and stops being the "not-wasm" proxy the 32-bit emcc lane made it. Two new predicates
    in `test/00-init.l` say what each law actually needs: `hosted` (an OS underneath —
    processes, an environ; false on inle and wasm) gates `run.l`'s `hark`/`getenv`;
    `files` (a filesystem — true on native *and* inle's ramfs, false only on wasm) gates
    `io.l`'s file roundtrips. `word` keeps only the numeric/real laws, which now *run and
    pass* on the module (it is native's equal). The seat pins `love-os` to `wasm` in
    host.c, as main.c pins the kernel's.
  - **the horn.** The port runs on the wasm seat: `horn.c`'s doorless seats open the sink
    (the ring that keeps time), so `(horn ..)`/`horn-lag`/`close` answer their laws with
    no device. And it makes *sound*: a weak `ai_horn_tap` lets the sink hand its accepted
    PCM to host.c's ring, three exports (`ai_horn_rate`/`chans`/`drain`) let the loader
    read it, and `loader.js` schedules it through WebAudio (node has none, so it is a
    no-op there and `horn.mjs` proves the path with a stub AudioContext).
    `src/port/wasm/horn.html` is a demo: love writes a square-wave tone, the browser plays it.
  - **the uu "typechecker" reds were a file-order artifact, not a miscompile.** The gate
    evals the corpus in one string in byte order; a helper listed the files under a locale
    sort, which put `uuval.l` before its band files. In byte order (`LC_ALL=C`, as the
    Makefile's `$t` uses) the uu corpus is green. No machine difference remained.
  The screen gate's one flake (`:q` after an escape) was a real ESC-vs-escape-sequence
  timing race in the test, fixed by resolving the parked escape before the next key.
  The mixed-kind `=` fault (a `test` after `ucomisd`) and the two link laws (a weak
  undefined ref is null; crt0 only when an input defines `main`) stand as before. The
  emcc build survives as `make wasm-emcc` (its love.js still drives the committed site),
  now with horn.c in its roster so it builds and carries the horn exports too.
- **rung 5b — the outside oracles. ✅ LANDED (2026-09-06).** Rung 5's `test_ccwasm`
  held wasm to x64 — two of our targets over one front end, which the differentials
  ledger says cannot see a shared fault. Two lanes fix that, both opt-in by name like the
  other cross gates: `test_cts_wasm` runs c-testsuite's 220 programs through `mooncc -t
  wasm` under node against the corpus's own answers (210 answer, the rv64 lane's 9
  refusals, and one rostered wrong: 00187 writes a file and reads it back, and the
  loader's kernel has no filesystem — a seat law, kept loud so the day the seat grows
  files the gate says so); and `test_ccwasm` now cross-checks every test/cc program
  against **emcc's wasm64** build (`-sMEMORY64`: clang and musl, nothing shared with us,
  on the same node) in ccarch.sh's cross-gcc seat — 153 of 153 agree. The first run found
  one seat bug, not a codegen one: the loader printed a write on ANY fd but 2 to stdout,
  so a NULL `FILE` (which does not trap on wasm — address 0 is memory) wrote the file's
  bytes to the page. `write` now answers EBADF off fds 1 and 2.
  And the seat has its GAUGE now: `make -C bench ccwasm` (doc/misc/moon-gauge.md) — the nif
  floors through `mooncc -t wasm` against emcc's wasm64 under one node. sha256 5.15× and
  deflate 2.88× against emcc -O2 (1.05–1.54× against its -O0), the corpus 2.39×: the
  array-heavy shapes lose twice over on wasm locals. Rung 5a is measured against that table.
- **the page rides the module. ✅ LANDED (2026-09-07).** index.html (web/index.l) and
  papel's `-r` island link cells.js and then repl.js as a module over loader.js, which
  fetches `src/port/wasm/love.wasm` beside it — the tracked copy of `make wasm`'s module,
  refreshed by hand with `make site-wasm` as love.js was. love.js is gone from the tree;
  `make wasm-emcc` lays emcc's build under out/ only, the differential. Verified in a real
  browser (Firefox 154 headless over WebDriver BiDi, the page served by http): the image
  boots in ~6 s, a form evaluates, the app chips fetch, and rove runs. The two flaws that
  run found: the loader's `node && process.env.LOVE_WASM` is `false` in a browser and `??`
  keeps false, so the page fetched `/false` and validated a 404 as wasm; and the banner's
  `(. love-version)` printed nothing — `.` stopped being a printer, `puts` says it. ⚠ the
  page needs http (a module fetch fails on file://) and an engine with memory64 (Chrome
  133, Firefox 134, Safari 26); repl.js says which is missing instead of failing quietly.
- **rung 5a — `return_call`. ✅ LANDED (2026-09-07).** The lowering was already in the
  lane (a `jmp` to a function under the universal type is `return_call`, a `jmpr`
  `return_call_indirect`), so the rung was the flip: `make wasm` builds at `ai_tco=1`
  and every VM tail is a real tail call. The corpus under node: **42.2 s → 32.1 s
  (1.31×)**, the module 3% bigger (1,343,565 bytes); screen, horn and the whole 4765-law
  corpus green, and the page boots and runs rove in Firefox on it. Against emcc's tco=0
  build the corpus row is 1.81× now (was 2.39×). The native bound below predicted it.
  **The bound, natively (2026-09-07):** the host built `tco=0` (test_tco0's flavour,
  out/tco0/love) against the default, the ccbench corpus (1.23 MB) through each, medians
  of 5 on a quiet box:

  | x86-64 host | tco=1 | tco=0 | tco=0 / tco=1 |
  |---|---:|---:|---:|
  | corpus, egg-booted (full − boot) | 7,425 ms | 11,035 ms | 1.49× |
  | corpus on the baked image | 8,281 ms | 10,975 ms | 1.33× |

  So the trampoline is a third to a half of the VM's corpus time natively, and the
  module runs on it: of the 2.39× against emcc on the corpus, return_call can reach
  for up to that much. Worth the rung; measure it on ccwasm and test_wasm's corpus
  time when it lands, since wasm's call cost is its own.
- **rung 5b — the relooper. ✅ LANDED (2026-09-07).** `w-reloop` in wasmfn.l: the function
  as basic blocks (split at every label and terminator, lowered in the IR's own order so the
  flags mode reads what it always read) and their graph; reverse postorder, dominators
  (Cooper–Harvey–Kennedy), back edges, merge nodes; then Ramsey's shape (*Beyond
  Relooper*, 2022) — a node's merge children wear `block`s (the last in order outermost), a
  loop header a `loop`, a branch to either is a `br`/`br_if`, any other branch inlines its
  target, which only that branch reaches. An irreducible graph keeps the dispatch loop for
  that function (none in love.wasm: 839 of 839 reduce, 292 of 292 in the nif drivers), and
  `MOON_ABLATE=reloop` is the old world whole. The gates: the hand lane's 23, `test_ccwasm`
  153 + emcc, `test_cts_wasm` 210/9/1, `test_wasm`'s 4765 + screen + horn, and the page in
  Firefox. **What it bought** (ccwasm, medians of 5):

  | row | dispatch | relooped | vs emcc -O2 before → after | vs emcc -O0 now |
  |---|---:|---:|---:|---:|
  | sha256 | 819 ms | 461 ms | 5.15× → 3.22× | 0.93× |
  | md5 | 249 | 159 | 1.73× → 1.12× | 0.81× |
  | crc32 | 67 | 57 | 1.29× → 1.27× | 0.95× |
  | cksum | 68 | 58 | 1.42× → 1.21× | 0.91× |
  | deflate | 628 | 310 | 2.88× → 1.52× | 0.77× |
  | inflate | 107 | 87 | 1.57× → 1.34× | 0.98× |

  mooncc beats emcc -O0 on every row now, and the module is 9% smaller (1,343,565 →
  1,217,518 bytes; the nif drivers 8–15% smaller). **The love corpus did not move** (32.1 →
  32.7 s, noise): the VM's hot functions are small tail-threaded ops with little control
  flow of their own, so their cost is the calls and the memory, not the dispatch. The
  corpus's remaining 1.8× against emcc is the next question, and it is not this one.
- **the locals-roster lever: MEASURED, DOES NOT PAY (2026-09-07).** The reading after
  ccwasm's first fill was that the array-heavy rows lose on wasm locals because the lane
  inherits rv64's 27-register roster where wasm has unlimited locals. Ablated before
  building: over the 839 functions of love.wasm, **none uses all 19 of r8..r26** (the most
  is 16, in two functions; the median is 3), and sha_block uses 21 distinct locals of the
  47 the convention lays — nothing spills for want of a register, so a wider roster has
  nothing to buy. And binaryen's `-O3` over our module (locals, masks, redundant traffic
  optimised, the control shape kept) runs sha256 **828 → 887 ms** and deflate 604 → 682:
  the local-level code is not the gap either. What every one of the 839 functions carries
  is rung 1's **dispatch loop** — one `loop`, a `br_table` over its blocks, and every
  branch a `local.set` of the label, a `br` to the head and a 20-way table — so a 64-round
  inner loop never reads as a loop to the engine. **That is the lever: a relooper**, real
  `block`/`loop`/`br_if` nesting from gen's CFG where it is reducible, the dispatch kept
  only where it is not. Priced on ccwasm's sha256 and deflate rows and the corpus.
- **rung 6 — a splicer in the browser.** Off the AOT path, after the artifact
  ships. Wasm forbids the native JIT by construction (`src/core/love.c` declines on
  `__wasm__`: a jump to a data address traps), so the browser love has no tier at
  all. A template splicer is the shape that works with no writable-executable page,
  because it builds a MODULE instead of patching code: read a thread back, take each
  row's own IR, strip the dispatch, lay the bodies end to end. ⚠ the tree had exactly
  this for native (`lib/splice.l`, over a `mooncc -fir` record) and it was **cut** —
  `doc/misc/moon-gauge.md`'s census is why: 95% of closures carry a call, which no amount
  of branch or operand work reaches. Whoever revives the idea here inherits that
  ceiling and must say what changes it. Three substitutions the native one wanted:
  holo becomes rung 0's module writer, `nif` becomes a table index reached by
  `call_indirect` (rung 4 builds it for `callr` anyway), and the symtab + load-bias +
  movabs apparatus deletes whole, since a module's external references are imports
  resolved by name — which also drops the in-process-only constraint. Open: the
  per-splice Module+Instance cost, and synchronous instantiation being size-capped on
  the main thread. Prior art for the skeleton: Mono's jiterpreter.
- **rung 7 — the image rides the module.** Open, off the path. The wasm seat boots the
  egg from source at every `ai_init` (host.c's `ai_egg_` over the four texts) while
  every native seat wakes a baked image. The writer's data section can carry
  `.love_image` the way the ELF does; what has to be said first is how an image whose
  aps are table indices survives a relink (image_extra_aps carries an ap as its index
  already). Worth a measurement of the page's boot before it is worth a rung.

## choices (revisable)

- whole-program module, no wasm `.o`/linker — one consumer (the love build)
  doesn't pay for a relocatable story.
- dispatch loop before relooper — correctness first, shape later; the tree's own
  rule (ablate before you optimise).
- `-Dai_tco=1` since rung 5a: the module's tails are `return_call`; tco=0 was rung 5's.
- the writer's instruction is a form and the module a tablet — love data the way
  holo's IR is, so a lane hands it lists and a gate quotes them.
- `src/port/wasm/love.js` (313 KB committed) gets rebuilt by our emitter behind the same
  `make wasm` door, and the emcc Makefile stays until the module passes the same
  gate — pays somewhere, regresses nowhere.

## difficulty

High. Two genuinely new pieces remain (control-flow reconstruction, and the lane
through gen.l that bypasses the register story); the container was the third and is
done. The verification instrument the other backends leaned on — differential
fuzzing against llvm-mc — has an analogue after all: node runs the emcc build and
ours over the same corpus, so the differential exists from the first function
compiled, and binaryen reads every module a second time. Bounded, though: the
runtime side is done, the API is twelve verbs, and every decision stays inside our
own toolchain.

## re-read 2026-09-06

What moved since the ladder was written, and what it changes:

- the console arc (rungs 0-2) put quay in the wasm seat: host.c unity-includes the
  engine and exports seven more verbs. rung 3's shim grows by those names, nothing else.
- the one-syscall door landed in nolibc (`__ai_sys`), so rung 3 is an import of one
  function plus malloc over `memory.grow`, not a libc.
- asmops made every inline asm GNU-dialect under `__mooncc__`; the wasm lane refuses
  `asm` and the C faces stand — num.c's divq already did this for mooncc.
- memory64 and tail calls stopped being "recent": probed on this box (node 26,
  binaryen 132), shipped unflagged in Chrome and Firefox, standardised in Wasm 3.0;
  Safari is the one to try. rung 2's cost column mostly empties; rung 5a exists.
- rungs 0 to 4 landed here, in that order: the writer with rung 1's control shape
  pre-proved by hand inside it, the walk from holo's IR over the same test module, the
  type law as code — the double lane, the flags, and `wasm-program` — on a second, the
  loader over a mock of the artifact's face on a third, and then the whole toolchain:
  `mooncc -t wasm` over gen's rv64 lane, the link, the runtime by need, and the C
  battery green under node. What remains before the module replaces love.js is rung
  5: love's own TUs through `mooncc -t wasm`, the corpus through test.mjs over the
  loader, and the `make wasm` door.
