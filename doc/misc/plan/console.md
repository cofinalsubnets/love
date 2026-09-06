# plan: the console, the library, and the circle

**THE CLAIM: one cell buffer, three seats, and the last foreign tool falls out at the
end.** quay's console is core C: a cell buffer the tty apps draw into, a painter
(src/core/quay/paint.c) that turns a cell into pixels off the xterm-256 table, and a
font that is a C array. inle runs that on a framebuffer. a real terminal runs the same
apps through their own ANSI. the page runs neither: src/port/wasm/repl.js takes the
ANSI frame an app would write to a terminal and re-lays it into spans, ignoring cursor
motion. that is fine for rove, which repaints whole, and wrong for vi, which paints
cells and moves a cursor. put the console itself in the wasm build and the page
becomes a blitter of cells into the quay face -- which, since `make fonts`, is the
very glyph rows paint.c draws. then a tty app is one program on three seats, rove can
hand the console to vi and get it back, and the library level is a room with the crew's
own documents on its shelves. the wasm backend (doc/misc/plan/moon-wasm.md) is the last
rung, not the first: every rung before it is usable on its own, and it is the only one
that is a compiler.

## what stands already

- **rove is a pure engine.** deck, fov and the painter run headless; frames gate; the
  helm decodes keys; one key per turn, state in, state out (src/apps/rove/rove.l). an
  interactive-fiction engine minus the fiction, and minus the crawl's rats.
- **libra lifts a document off a file** (`libra doc`), and the site's tool pages are
  exactly that -- the library's books exist, they have no room yet.
- **the console is core**, not host: quay's cb, painter and palette (src/core/quay/) are
  in every seat's link, the wasm one included; only the blit is missing there.
- **the door has half its implementations.** on a terminal a tty app is a spawn, which
  lush's fork lane does on the warm heap; on inle it is a task (twirl). nothing yet says
  "run this app on THIS console and come back".
- **the page sits on the 16px cell.** assets/fonts is laid from the quay bitmaps, the
  palettes are config.l's hue-page, the repl driver is loveRepl(root) over a .repl
  island. the console rung finishes the site as a side effect.

## the ladder

- **rung 0 -- the console in the page.** ✅ LANDED. the wasm seat carries quay's
  engine and its love door (host.c unity-includes quay.c + nif.c, as src/host/cb.c does)
  plus one nif of its own, `(mirror scr)`, which copies a screen's head and cells to a
  buffer the page reads through `ai_mirror`; `ai_palette` hands out the xterm256 table
  paint.c spends and `ai_unfold` the cp437 fold, so the page owns no second recipe.
  src/port/wasm/web.l is the page's love side: each app boots on a screen of the box's
  size and scribes its frames into it; cells.js lays the mirror as text, one span per
  run of like-penned cells, paint.c's reading of bold/reverse/underline; repl.js pumps
  the steps and blits. ansiToHtml, pal256 and the JS cp437 table are gone. gate:
  src/port/wasm/screen.mjs under test_wasm -- a hand frame's cells and its lay, and rove
  and ink booted on a page screen. what it found on the way: the wasm function-table
  trap in c0's peephole (src/port/wasm/32bit-findings.md).
- **rung 1 -- the console door.** ✅ LANDED. `(door f)`, module 'console (src/apps/console/console.l, a crew file: the core spells no host word):
  one verb, two bodies. a seat that can fork (a terminal) forks -- the app owns the
  tty, the parent waits, its own state untouched -- and a seat that cannot (inle, the
  page) twirls the app as a task and catches it. fork, wait and quit are read late, so
  it compiles on every seat. the page's half (host.c): stdin is a ring of key bytes the
  page pushes, a dry read parks the reading task (and answers the end on the session's
  own task, so a typed `rove ()` can never park the page); a key arms the parked sweep;
  ai_runnable/ai_alive let the page yield until the app parks, sleeps or lands. rove and
  ink run on the page UNCHANGED through web.l -- their tty runners, keys as the bytes a
  terminal sends. gates: test/host/door.l (both lanes, forked here), screen.mjs (both
  apps as tasks). rove's library level calls the door and nothing else to open a file.
- **rung 2 -- rove as the fiction engine.** levels as data with a designer; rooms,
  exits, things, text -- the zork half over the rogue half. no combat, mobs or procgen
  at first: the crawl becomes one level among others or goes. the library level:
  a room per crew module, a book per file, reading = libra's document, and "read the
  source" = rung 1 into vi. frames keep gating headless on every seat.
- **rung 3 -- the wasm backend**, doc/misc/plan/moon-wasm.md rungs 0-5: the module
  writer, control flow by dispatch loop, the type law, the environment (a nolibc face
  where the handful of system calls are imports the page supplies, and a loader of a
  few dozen lines in place of emscripten's runtime -- repl.js's `Love()`, `cwrap`
  and the heap views are the API to keep), gen.l's lane, the gate. its oracle is the
  one the other backends never had: node runs the emcc build and the moon build of
  the same core, so both corpora are a differential from day one.
- **rung 4 -- emcc goes.** `make wasm` rides our emitter, src/port/wasm/Makefile's
  emcc lane is deleted once the module passes the same gate. pays somewhere,
  regresses nowhere.

## choices (revisable)

- the console before rove: the fiction engine's "read the source in vi" is rung 1 on
  rung 0, and both are worth having with rove untouched.
- cells, not a canvas: the browser keeps rendering text, so the console stays
  selectable and copyable and the font is the webfont, not a second copy.
- the door is one verb with two bodies, never two verbs: rove must not know which
  seat it is on.
- the backend last: it is the only rung that is a compiler, and its two real costs --
  structured control flow, and the libc-and-loader emcc quietly supplies -- are
  priced in moon-wasm.md, not here.

## difficulty

rungs 0-2 are medium and mostly love: the console and the painter exist, the fork lane
exists, rove's engine exists. rung 3 is high and is moon-wasm.md's own estimate. the
risk that is this plan's rather than that one's: the page's grid fit and inle's
framebuffer disagreeing on a cell -- which is why rung 0's gate is glyph-for-glyph
over one cask, and why it comes first.
