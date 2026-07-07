# The browser terminal as a third cb renderer

The web REPL (`index.html`) is the odd frontend out: it bypasses the **console
buffer** (`port/quay/quay.c`) entirely and lets the browser's font paint `<div>`s
(`index.html:66-83`, a bespoke JS line-reader). This study plans the move to a
`<canvas>` rendered from a `struct cb` — so the page draws the same bitmap fonts,
through the same ANSI parser, as the freestanding kernel — and, on top of that,
runs the **real bao shell** in the browser instead of the JS imitation.

**Design study — not yet built.** The reasoning is below; the work is staged so
each step leaves `make test` green and the page usable.

Touches `wasm/` + `index.html` only, plus adding `port/quay/quay.c` and `bao.h` to one
link. No edit to `ai/bao.l` or the core — see "What it does not touch".

## Why

`cb` was built to be rendered by something other than itself. `quay.h:11-13` says
it outright — "cb only stores [colour/font indices]; the renderer maps colour
indices to pixels and font indices to glyph sets." There are already **two**
renderers over one cb:

- the kernel's `fbdraw` (`kmain.c:379`) — blits each cell into the linear
  framebuffer, palette + glyph table + cursor invert;
- the playdate port (`port/playdate/main.c:44`) — reads `K.cb.cb[pos]` and
  `cga_8x8` straight.

A browser canvas is a natural **third**. The index terminal is the only frontend
that doesn't share the console, and that costs it three things it could have for
free, because they all already live in cb and bao:

- **the retro bitmap fonts** (`cga_8x8` 8×8, `moderndos_8x16` 8×16, `quay.h:43`);
- **ANSI colour + cursor motion** — cb's `cb_putc` parses the VT subset bao's
  editor emits (CR, BS, LF+scroll, ESC 7/8, CSI K/J/A/C/D, SGR 256-colour;
  `quay.c:52-98`), so bao's coloured prompt (the cyan helm, `bao.l:264`) just
  renders;
- **the actual line editor** — cb's *read* side (`cb_getc`/`cb_ungetc`/`cb_eof`,
  `quay.c:100-116`) is exactly what feeds bao's `edln` on the kernel. Canvas+cb is
  the doorway to running bao's history, recall, and helpful prompt on the
  identical code path as native and inle, retiring the JS REPL.

## The crux: how bao reads

This one finding decides the whole shape. bao's shell reads input **two
different ways**:

- the **line editor** (`edln`/`edraw`/`edev`/`edesc`, `bao.l:219-233`) **blocks**
  on `getc 0` — it expects a byte to be there;
- **evaluation** (`do_eval`, `bao.l:345-353`) **polls** — `cue? 0` for
  readiness, `getc 0` to read, `rest 0` to yield, with `twirl ev` running the work
  as a task so a scare can't kill the repl.

The kernel satisfies the blocking `getc 0` by busy-waiting on a hardware halt
(`kmain.c:156`: `while ((b = kqpop()) < 0) fbdraw(), kwait();`). **A browser can't
busy-wait** — inside one synchronous `ai_eval` call there is no way to obtain the
*next* keystroke; control must return to the event loop first. So the central
question is exactly: **how does `getc` suspend back to the event loop and resume
on a keypress?** Everything else (cb, canvas, copy/paste) is mechanical; this is
the only real design choice.

## The decision: a park-based scheduler (preferred), or Asyncify (standalone)

> **The better path is the scheduler redesign — see [`doc/sched.md`](sched.md).**
> bao already parks correctly via `see`/`lvm_fgetc`; the blocking is really in the
> *core scheduler's* host-wait (`ai_wait_fds`), which on wasm is a no-op twirl. If
> that wait is made **declinable** — native blocks, wasm returns the yield status
> up the existing trampoline (`ai.c:1823-1827`) and an `ai_resume(g)` re-enters —
> then this page just runs `(shell 0)` and loops "resume; on a park, wait on the
> surfaced fd/timer via the event loop." **No Asyncify, no `_getc` magic.** That is
> the recommended Stage 2 once the scheduler work lands. The Asyncify route below
> stands as the way to ship the browser shell *without* a core change.

**Asyncify (standalone).** Run the real `(shell 0)` once; it never returns. Build
the wasm with `-sASYNCIFY` so the host's `_getc`, when the JS input queue is empty,
`await`s a promise that a keydown resolves — the C stack suspends and resumes
transparently. This reuses the **actual** bao line editor + history + helpful
prompt **unchanged**: the blocking `getc 0` becomes a suspend, the polling
`do_eval` loop's `cue?`/`rest` map onto the same queue + a yield. `ai_eval` becomes
async (returns a promise); the page calls it once for `(shell 0)` and otherwise
just pushes bytes and reads cb.

### The alternative: Web Worker + SharedArrayBuffer

Run the wasm in a worker; `_getc` does a real `Atomics.wait` on a SAB ring the
main thread fills from keystrokes. Architecturally the cleanest — genuine
blocking that mirrors `kwait`, a lean wasm with no Asyncify bloat — but it needs
COOP/COEP cross-origin-isolation headers on the host, a non-starter for a plain
static/Pages deploy. Kept as the correct-but-needs-headers fallback; if the page
ever moves behind isolation headers, this is the better engine.

## What's already done for us

- cb is renderer-agnostic by construction (`quay.h:11-13`) — no change to its
  parser; we only *link* it.
- the glyph tables are `extern const` (`quay.h:43`) — export their addresses or
  embed the ~4-6 KB byte tables in JS.
- the canvas rasterizer **is** `fbdraw` transliterated: the inner blit
  (`kmain.c:391-396`) and `palette_init` (the 16 ANSI + 6×6×6 cube + grey ramp,
  `kmain.c:46-60`) are ~25 lines of JS over `HEAPU32`.
- bao is meant to be the baked shell core for **all three** frontends already
  (`bao.l:3`) — wasm just hasn't been the third yet.

## Staging (each stage keeps the page working)

**Stage 1 — cb in wasm, canvas renders output.** Add `port/quay/quay.c` to the wasm
link (`core_o` is `ai.c` alone today, `wasm/Makefile`). Give `wasm/host.c` a
static `struct cb term` + `rows*cols` backing store, set the default pen
(`cb_attr`) and `show_cursor`. Route `_putc` through `cb_putc(&term, c)` (keep
`out_buf` as a debug mirror if handy). Export `cb_ptr/cb_rows/cb_cols/cb_wpos`
and the glyph addresses. In `index.html`, swap `#out` for a `<canvas>`
(`cols*8 × rows*16`, CSS-scaled, `image-rendering: pixelated`); a
`requestAnimationFrame` loop reads the cells from `HEAPU32` and blits glyphs into
one `ImageData` (fbdraw, JS). Cursor block = invert the cell at `cb_wpos`, blink
on a rAF tick (the `kticks & 64` of `kmain.c:390`). **Input still JS** at this
stage — the existing thin `ev` REPL drives, output just renders through cb. This
stage is independently shippable and proves the renderer.

**Stage 2 — the real bao shell.** Either path bakes bao into the image first: add
`bao.h` to `host.c`'s `boot_ai` (the kernel does this at `kmain.c:587`; the wasm
boot string is egg+prel+ev today, no bao) and to the Makefile deps. The page then
calls `ai_eval("(shell 0)")` once and deletes the JS REPL (`balanced`/`run`/`hist`
and the textarea, `index.html:51-99`) — bao owns line editing now. keydown →
byte(s) → a JS input queue; arrows and Ctrl-C map to the escape bytes `edesc`
already reads. The two paths differ only in how the queue feeds back in:

- **park-based (preferred, [`doc/sched.md`](sched.md)):** `_getc` reports
  not-ready and the scheduler parks; the wasm `ai_wait_fds` declines, so `ai_eval`
  returns; the page waits on the surfaced fd and calls `ai_resume(g)`. No build
  flags. Depends on the scheduler redesign landing first.
- **Asyncify (standalone):** build `-sASYNCIFY`; `_getc` `await`s on empty and the
  C stack suspends/resumes. Ships without a core change; `ai_eval` goes async.

**Stage 3 — copy/paste over the canvas.** Paste reuses the existing `paste`
handler (`index.html:104-109`), feeding bytes into the same queue. Copy is the
standard terminal trick, and cb makes it easy because it stores the char per cell
(`cb_ch`): mouse-drag → cell range; highlight by inverting those cells in the
rAF blit; on copy, read `cb_ch` across the range, join rows trimming trailing
blanks, `clipboard.writeText`.

## What it does not touch

On the **Asyncify** path, `ai/bao.l` and the core stay **untouched** — Asyncify
lets the real shell run as-is, and the change lives entirely in `wasm/host.c`,
`wasm/Makefile`, and `index.html` plus adding `port/quay/quay.c` and `bao.h` to one link:
a single frontend lane, no coordination with the inle or core threads (the
app-boundary rule in CLAUDE.md). On the **park-based** path the renderer + bake
stay in this lane, but the suspend itself is the core scheduler change in
[`doc/sched.md`](sched.md) — that part is the core thread's, and is shared with
bao and the native frontends rather than being browser-specific.

Single-sourcing `fbdraw` — factoring the blit out of `kmain.c` so the kernel and
the browser share one rasterizer in C — is the tidy end state but edits inle's
file, so it is explicitly a **later** follow-up needing that thread, not part of
this work. Until then the browser carries its own ~25-line JS blit.

## Risks to spike first

- **Asyncify × the VM (Asyncify path only).** The wasm build sets `-Dai_tco=0`
  (`wasm/Makefile`) — TCO off, so the VM recurses in C and the stack can be deep.
  Asyncify captures the whole C stack on suspend; prove the cost/correctness with a
  tiny spike (suspend a `_getc` inside a deep `ev` call, confirm clean resume +
  tolerable size bloat) **before** committing to it. The park-based path sidesteps
  this entirely: `-Dai_tco=0` makes the driver a trampoline (`ai.c:1823-1827`) that
  *returns* on the yield status, so no deep-stack capture is needed.
- **CPU-bound freeze.** A tight eval (`(fib 32)`) still blocks the tab until a
  yield point, and Ctrl-C only lands at `rest 0` yields — same as native. State
  it; don't try to fix it.
- **cb sizing.** cb dims are `uint8_t` (≤255). Start fixed at 80×24; live
  resize-on-reflow (re-`cb`-allocate, repaint) is a later nicety.

## Not yet / open

- Single-source `fbdraw` across kernel + browser (needs the inle thread).
- Live terminal resize on viewport reflow.
- Whether to keep `out_buf` at all once cb is the sink (debug-only mirror, or
  drop it).
- Touch input / mobile selection for copy (desktop drag is stage 3; touch is its
  own gesture story).
