# release — the aicc + reef + precedence cut

Status: **checklist / in progress.** Started 2026-07-14. The living checklist for the next
public cut. Prior release state (Juneteenth 2026-06-19) is archived at
[`doc/archive/release-state.md`](archive/release-state.md).

## the headline

Three features carry this release:

1. **aicc — the self-hosting toolchain.** ai builds itself from source with no external
   toolchain: `aicc` (the C compiler) + [`crew/holo/link.l`](../crew/holo/link.l) (our linker)
   + nolibc. `make test_raw` is gcc/glibc/ld-free.
2. **reef — the vcs.** New this cut. A patch-DAG version control folded together with the
   installer (hatch). Model in [`doc/hatch.md`](hatch.md), verb set in [`doc/reef.md`](reef.md);
   needs to get practically working.
3. **precedence — infix that binds like schoolbook math.** `*` tighter than `+` tighter than
   `=`. prel-only, no C. Design in [`doc/precedence.md`](precedence.md).

Riding along: the long-deferred **namespaces** cleanup closes its phase-3 tail — the module
books (`holo`/`glaze`/`kanren`/`uu`/`overlay`/`parse`) stop handing out their raw backing
tablet, so a stray `(pin holo …)` can no longer poison a baked service. See [[namespace-modules]].

## where each stands

| feature | state | gap to release |
|---|---|---|
| aicc (x64) | landed — gcc-free ai boots + passes the corpus | polish + docs; command becomes `mooncc` (rename deferred, see below) |
| aicc (arm64) | rungs A–C landed (static exes + .o + our-linker, varargs + sibcalls, 88/88 battery 3 ways) | rung D (nolibc/mksys, the gcc-free arm64 path) about to land — **best-effort in, does NOT block** |
| reef/vcs | design (hatch.md model + reef.md verbs) | the whole implementation — biggest lift |
| precedence | design only (precedence.md) | implement in prel.l opfix + re-validate the corpus |
| namespaces | phases 1+3 landed — `(names ())` 820 → 327 | make the module books non-pinnable (lookup closure over a private tablet — the phase-3 tail); the abyss/scoped-layers arc stays deferred |

---

## checklist

### A. features

**aicc**
- [x] decide arm64 scope — **does NOT block the release.** Rungs A–C landed; rung D (nolibc/mksys, currently
      dirty in `crew/cc/lib/`) is about to land and we'll try to fold it in, but the cut ships either way (see [[aicc-arm64]])
- [ ] `doc/cc.md` reads as a release doc, not a build log — a user can compile a hello-world and know the flags
- [ ] a headline one-liner ("a self-hosting C toolchain in ~N lines of ai; no gcc, no glibc, no ld")

**as** — a real assembler, the front tooth of the gcc-free chain (pairs with link.l's `ld`)
- Reads standard GNU AT&T `.s` → obj.l-shaped relocatable `.o` → link.l. New front over holo:
  parse (post.l combinators) → physical-register encoder (the bulk) → per-section (bytes·relocs·labels).
- Reuse: link.l unchanged; obj.l's ELF back half (factor `objelf-raw` at the o-walk seam so cc + as
  share it); x64.l as the encoding reference + its rex/modrm/sib/le* primitives.
- Home: `crew/holo/as.l`, swept into the `holo` book like link.l. **kore-as-`as` execs the holo
  assembler binary** — same execvp pattern as kore-as-`cc`→mooncc (binary name is a small open item).
- Scope: **x64 this cut** (arm64 assembler folds into the arm64 parity arc, not now).
- Bar (gwen 2026-07-14): **THIS cut = battery + link-and-run** — hand-written `.s` snippets byte-identical
  to `/usr/bin/as`, then linked via link.l into binaries that run; the instruction tail grows one snippet
  at a time. **NEXT cut = `aicc -S` round-trip** (teach aicc an asm-text emitter, prove `aicc -S | as` ==
  `aicc -c` byte-for-byte). North star (later): assemble real `gcc -S ai.c` → boot (needs link.l foreign-obj
  features — .eh_frame/.bss/comdat it skips today).
- Milestones: M1 ~15 core instrs → `.o` → link → runs (`.text` byte-diffed vs system as) · M2 width
  variants + memory operands + `.data`/relocs + **branch relaxation** (short/near) · M3 SSE + the long
  tail · M4 arm64 (deferred).
- **M1 ENCODER LANDED 2026-07-14** (`crew/holo/as.l`, committed `a717609a` + style pass `7ad6c4e6`):
  the AT&T parser +
  x86-64 encoder (64/32-bit GPR core) is **byte-identical to `/usr/bin/as`** across a 24-instruction
  straight-line battery — reg/imm ALU (incl. the `83 /ext` imm8 short form + `81 /ext` id), mov
  (`b8`/`c7`/movabs by width+range), test, unary, push/pop, `lea foo(%rip)` + `call foo` (internal,
  resolve in place), ret/nop/syscall/leave/cq[dt]o. Branches (`jmp`/`jcc`) emit **correct near forms**
  with right rel32 displacements; GAS relaxes to short — that byte-diff on branches is the **M2
  relaxation** item, code runs identically. Traps hit while building: `cat` is DYADIC (`(cat a b c)`
  church-applies the list → apcap; use `catall (L ..)`); table rows need `(link k v)` not `` `(k v) ``
  (the `(cap p)/(cup p)` idiom wants a cons, else the value nests one deep → `add` emitted `cmp`'s /7);
  a lone extra `)` closed the top-level `:` early → tail ran with unbound `src` at load.
- **Integration (deferred — same arm64-collision reason as moon):** there's already a `kore as` applet
  (`crew/kore/kore.l` `as-main`) that assembles holo's OWN IR → ELF via `elf64`; the real-AT&T `as`
  UPGRADES that path to read `.s` → `.o`. Wiring needs: obj.l `objelf-raw` (factor at the `o-walk` seam
  so it takes pre-laid `(items·labels)` sections, not IR forms) + as.l migrated bare→`holo`-book refs
  (to live in the kore cat beside obj.l/link.l, cf. `asbook.l`) + `as-main` reading AT&T + emit `.o`
  through obj.l + link via link.l. All touches `crew/holo/` + the kore cat — hold until the arm64 work
  in crew/holo/{obj,arm64,link}.l + crew/cc/ commits, to avoid the collision.
- **kore-as-`as` dispatch (gwen 2026-07-14):** kore invoked as `as` execs the holo assembler binary —
  same execvp pattern as kore-as-`cc`→mooncc (binary name a small open item, cf. mooncc).
- [ ] wire the M1 slice into the kore/holo cat + `test_as` gate (byte-diff vs `/usr/bin/as` + link-and-run), test_all

**reef (vcs)** — the design decisions to make first
- [x] pick the minimum viable verb set — `record` · `sync` · `log` · `diff` + `hatch` (per reef.md; `sync` in over `apply` — the near-term job is multi-machine tip-union)
- [ ] patch/commit object shape + the DAG (pijul-style patches, no privileged trunk — per hatch.md)
- [ ] where it lives: `crew/reef/` + a book, following holo's all-the-way-down precedent
- [ ] a real end-to-end run: record a change, sync it, log it, apply it to a fresh checkout
- [ ] decide how much of hatch (install = clone + hatch) rides in this cut vs. lands later
- [x] `doc/reef.md` — first draft (verb set + composition story + MVP)

**precedence (grip)**
- [ ] implement grips in the reader-operators block of `ai/prel.l` (op-ent / op-fr / the steal-point)
- [ ] assign the grip bands (multiplicative 60 / additive 50 / comparison 40 / logical 30 — see precedence.md)
- [ ] `make test` ×3 green — audit every infix regroup across the corpus; touch up any spec.l asserts that shift
- [ ] settle the `grip` working name (per precedence.md §Naming)
- [ ] promote `doc/precedence.md` from design to shipped

**namespaces** — close the phase-3 tail (phases 1 + 3 landed: `(names ())` 820 → 327; see [[namespace-modules]])
- **NO "sealed tablet" language feature** (decided 2026-07-14). The same way users can't reassign the
  top-level `book` — it's *mopped* out of the image, so `pin`/`pull` on it no-op — the module books just
  stop exposing their raw backing tablet. Regular tablets throughout; only the *access* is limited.
- [ ] make each module book a **lookup-only closure over a private tablet**: the export trailers
      (`crew/holo/export.l`, `ai/glaze/export.l`, + the kanren/uu/overlay/parse equivalents) today `(pin book
      'holo m)` the raw tablet `m` — so `(pin holo (\ x) 42)` reaches it (probed 2026-07-14: returns the
      garbage). Bind `(\ k (peep m k 0))` instead: `(holo 'assemble)` still looks up, `m` stays closure-private
      and unreachable, `pin` has no tablet to grab.
- [ ] verify main.c's image-dump reach-through still works (it queries *through* the glaze book — a lookup,
      which the closure supports) + that no consumer leans on a book being a tablet (map ops / key iteration)
- [ ] (optional, gwen's word) a curation pass to trim the ~327 back toward 323 — new crew apps drip a few leaks
      each (post.l combinators, kanren internals, overlay `ov-*`, tele's `cuda-*`); or accept the drift
- [ ] **NOT this cut:** phase 2 "the abyss" (descending scope layers, the chain in `g->book`, per-layer macro
      tables) — designed with gwen 2026-07-07, a dual-compiler-parity architectural lift, its own arc

**housekeeping** — not a feature, but lands with the cut
- [ ] **break up the 1635-line root `Makefile`** — non-recursive `include` fragments, host/kernel builds
      split out next to their source (`host/build.mk`, `port/inle/build.mk`) + the crew test bulk to
      `mk/apps.mk`. Pure motion, `make -pqn` byte-identical at each step. Plan in [`doc/makefile-split.md`](makefile-split.md)

### B. naming & persona (gwen christens — offers only)

- [x] **aicc → moon** (crew name) / **mooncc** (the binary) — DECIDED. Creature = the glowing mycelium 🍄 on holo's cave walls; moon is a sibling to inle (the kernel). `mooncc` slots into the cc/gcc/tcc tradition and clears the `moon`(MoonBit)/`moonc`(MoonScript) collision
- [ ] **kore-as-`cc`** — moon left the au/kore cat, so kore invoked as `cc` execs `mooncc`. No new PATH-walker needed: the `exec` nif IS `execvp` (host/main.c:334), which searches $PATH itself. kore's `cc` case builds argv `("mooncc" . args)` and `(exec …)`; on success it never returns, on absence it returns an errno fixnum (ENOENT) → fall back to `cc: mooncc not found` + quit 127
- [x] decide the command name — **`aicc` → `mooncc`** (with `kore` invoked as `cc` execing `mooncc`). The
      rename-all-the-way-down + the kore-as-`cc` dispatch are **DEFERRED with the arm64 work**: arm64 parity
      still churns the `crew/cc/` + `crew/holo/{obj,arm64,link}.l` seams, so the token sweep waits to avoid the
      same collision that holds the `as` integration. Land it in the arm64 batch, not this cut.
- [x] **reef** = 🪸 coral — the vcs/distro persona (the coral colony = the patch DAG). Chosen 2026-07-14 (was `tree`; dropped for the `tree(1)` collision + reef fits the rootless, accretion-only model better — see reef.md §why-reef). Command name still open, and like everything, revisable.
- [ ] **pulchritude** persona coral → 🦂 giant centipede (brightly-colored *Scolopendra*); keep the name (it carries its own layers). One-line change in `index.html`
- [x] **au → kore** 🦨 (skunk) — LANDED (`15f46d45`), all-the-way-down: crew/kore/, kore.l, bin/kore, test_kore, doc/kore.md. Follow-ups: a kore roster line in index.html; kore-as-`cc` execs mooncc (needs moon)
- [x] **phos → lux** — DECIDED. The WM; mantis shrimp stays as the creature. Own pass — plan in §appendix
- [ ] name sweep for any rename — grep `.l` `.c` `.h` `.md` `.html` `Makefile` `.mk` + `index.html` crew list + C-embedded lisp (the naming-lore rule)

### C. docs & the public face

- [ ] `index.html` crew list: add aicc + reef, move pulchritude's creature (probe examples against `out/host/ai`, don't write from memory)
- [ ] `crew/README.md` roster updated (currently empty/stale — regenerate)
- [ ] blue paper (`tools/blue.l` → blue.md/html) — mention the toolchain + vcs if in scope
- [ ] `README.md` one-liners for the new crew members
- [ ] **bench.html** — restyle to match the rest of the site (style.css / index.html look-and-feel)
- [ ] **regen the bench tables** — re-run the benches, refresh the numbers baked into bench.html
- [ ] **regen wasm** — rebuild `wasm/ai.js` against the release binary (currently dirty in the tree)

### D. the gate

- [ ] `make test` green ×3 (host + ai0 ×2, + test_proof + test_gen)
- [ ] `make test_all` (proofs, gc/glaze/sat/holo/phos, tool diffs, arm64 + qemu kernel + wasm)
- [ ] `make valg` clean, `make vmret` green
- [ ] version stamp (`ai_version.h` / `force_version`) — currently `9b45d8d2-dirty`

### E. the cut

- [ ] commit the working tree (currently dirty: prel/gen/index + the two new docs + uu promotion)
- [ ] `post` → `main` → `tau` (`git push tau post` per house habit)
- [ ] github + codeberg mirrors
- [ ] `index.html` on Pages

---

## appendix — the phos → lux rename plan

A pure token swap (`phos`→`lux`) plus file moves. Verified tree-wide: no false-positive
substrings (only compounds are `phosui`→`luxui`, `phosfiles`→`luxfiles`, both correct). The
C nif is `connectu` (not `phos`), so C idents are untouched. The uu **model** names stay
`uuwm`/`wm2uu` (generic "wm") — only phos *source references* inside them swap.

**1. move the files (git mv):**
- `crew/phos/` → `crew/lux/` (core/layout/wire/ewmh/manage/keys/config/law/sigs + `phos.l`→`lux.l`)
- `host/phos.c` → `host/lux.c`
- `test/host/phos.l`→`lux.l`, `phosui.l`→`luxui.l`, `phosui-probe.l`→`luxui-probe.l`
- `doc/phos-port.md` → `doc/lux-port.md`, `doc/proto/phos.l` → `doc/proto/lux.l`

**2. swap `phos`→`lux` in content** (the noms phos-cell/st/!/sock/session/moor/display/auth/
tags/keymap/startup/border/colors/dispnum, all in the same sweep so sibling cross-refs stay
consistent): `crew/lux/*.l`, `Makefile` (target `test_phos`→`test_lux` in .PHONY + test_all +
the rule + its `crew/phos/law`→`crew/lux/law` grep string; `hostnif_tests` paths;
`phosfiles`→`luxfiles`; `bin/phos`→`bin/lux` rule + install list; the uuwm-rule comment path),
`host/lux.c` (2 comment lines only), `test/host/{lux,luxui,luxui-probe,haven,pier,drm,overlay}.l`,
`crew/haven/{haven,metal}.l`, `crew/quay/pier.l`, `CLAUDE.md`, `index.html` (roster line),
`doc/{cc,lux-port,proto/lux}`. Runtime socket path string `/phos-<n>.sock` → `/lux-` (surface).

**3. the delicate one — the uu proof bridge:** in `tools/uuwmgen.l` + `tools/wm2uu.l` swap the
input paths `crew/phos/{core,sigs}.l`→`crew/lux/` and the `phos-sigs` binding→`lux-sigs`; KEEP
`uuwm`/`wm2uu`. Then **`make uuwm`** to regenerate the committed `test/uuwm.l` (else `test_uuwm`
goes red — drift gate). Confirm `tools/uu2coq.l`/`uu2lean.l` gather-lists don't name the path.

**4. build + gate, in order:** `make out/host/ai` (phos/lux is baked into no core, but `bin/lux`
+ tests rebuild) → `make uuwm` → `make test_lux` → `make test` ×3 → `make test_all` (test_lux,
test_uuwm, test_uukind, wasm, kernel, arm64) → `make valg` + `make vmret`. The X UI layer
(`luxui`) needs a display — run under Xephyr/Xvfb per [[x11-wm-spike]], not the portable gate.
Live smoke: run `bin/lux` under Xephyr (gwen's daily WM). Land as ONE rename commit; `push tau`.

**5. after landing:** update the memory files that name phos ([[x11-wm-spike]], [[pluggable-types]],
[[naming-lore]] already done) + the index.html roster line (name lux, keep 🦐 mantis shrimp,
one-line `<dd>` — creature + role, no prose).

## open decisions (need gwen)

1. **arm64 scope** — DECIDED: does NOT block. Rung D (nolibc/mksys) best-effort into this cut, ships either way
2. **reef's minimum viable surface** — TENTATIVE: the `record · sync · log · diff + hatch` verb set (gwen
   2026-07-14); to be CONFIRMED with the patch thread once it finishes its current heavy proof work
3. **the names** — aicc's persona (open), reef/coral chosen (was tree), pulchritude→centipede, kore for au, phos→lux — all standing, none frozen.
4. **precedence in-scope** — DECIDED: YES (gwen 2026-07-14; prel-only, conservative extension, no C)
5. **namespaces scope** — DECIDED: no sealed-tablet feature; module books become lookup-only closures over
   private tablets (closes phase 3's named tail), abyss/scoped-layers held. names() curation trim optional
