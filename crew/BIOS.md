# crew bio pages — the handoff (siri → kship)

siri set the template; kship writes the rest. this doc is the spec: follow it and
every bio page comes out consistent without re-deriving a single decision.

The **template page** is [`crew/ai.html`](ai.html) — copy it verbatim and swap the
member-specific bits. The **roster hub** is [`crew/index.html`](index.html) and is
already complete (it links to all ten bios). The **home page**
([`../index.html`](../index.html)) already carries the teaser roster + the nav. So
your job is purely: author the **nine remaining** `crew/<name>.html` pages.

## What's already done (don't touch)

- `../index.html` — landing page: shared `.topnav`, a "read on" block, and a "the
  crew" teaser `<dl>` linking to every `crew/<name>.html`. Done.
- `crew/index.html` — the roster hub. Lists all ten members, links to each bio. Done.
- `crew/ai.html` — the example bio + the template. Done.

## The nine to write

`siri.html` · `sift.html` · `bao.html` · `aineko.html` · `cook.html` ·
`tele.html` · `zev.html` · `wev.html` · `kship.html`

(ai.html exists. that's the ten.)

## File naming & links

- One file per member: `crew/<name>.html`, the same `<name>` as the brief
  `crew/<name>.md` and the roster link.
- The page lives **under `crew/`**, so link **relatively**: `../index.html` (home),
  `../blue.html`, `../README.md`, `../CLAUDE.md` go up one; `index.html` (the roster)
  and the sibling bios (`kship.html`) are flat.
- Every bio's `.lives` footer links to its own brief, e.g. `<a href="siri.md">`.

## The chrome (locked — copy, don't reinvent)

Self-contained `<style>` in every page (no external CSS — the rest of the site is
dependency-free static HTML; match it). The palette is the index palette:

| token | hex | what |
|---|---|---|
| bg | `#0e1014` | the ground |
| text | `#c8ccd4` | body |
| dim | `#6b7385` | muted / `.dim` |
| link | `#7aa2f7` | `a` |
| green | `#9ece6a` | the creed line — the color of a kept answer |
| panel | `#161a22` / border `#232733` | `code`, chips |
| strong | `#e3e6ff` |  |

Every page has, in this order:

1. `<p class="topnav">` — `← ai` (→ `../index.html`) · `the crew` (→ `index.html`)
   · `blue paper` (→ `../blue.html`) · `readme` (→ `../README.md`).
2. `<h1>` — the name, then `<span class="what">· the &lt;role&gt;</span>` dimmed.
3. `<p class="creed">` — ONE line the member steers by, in green. Their slogan.
4. two-to-four short `<p>` of bio.
5. `<p class="lives">` — `lives in <code>…</code> · the full brief is
   <a href="&lt;name&gt;.md">crew/&lt;name&gt;.md</a>`.
6. `<footer>for P B & E</footer>` — the site footer, every page, unchanged.

## The tone (non-negotiable — this is the house style)

- **lowercase, cozy, plain, a touch playful.** No marketing voice, no capitals at
  the start of sentences in the prose (titles/`<title>` can be lowercase too).
- **frame in the green:** name what the member *is and keeps*, never what it lacks.
- **distill the brief, do NOT copy it.** The `.md` brief is a detailed internal
  agent doc — territory, do-not-touch lists, status, roadmap. The bio is the
  opposite: short, warm, a public reader's first hello. Three or four paragraphs.
  Strip every internal detail (file territory beyond the one `lives in` line, gate
  rules, "core thread" coordination, TODO state). Keep: who they are, the one thing
  they tend, why it's theirs, the creed.
- **keep the crew metaphor:** they ride **kship**, the ship in port; each is a
  system or a hand aboard. ai pilots, the others are the ship's systems. Lean on it
  lightly — a touch of idiom, not a costume.

## Per-member angle (the creed + the seed — expand each into a bio)

Pull the warmth from the brief's opening; here is the distilled angle so the pages
stay coherent. The **creed** is the green line; the **seed** is what the bio grows.

- **siri** — *the synthesist.* creed: *the human words and the ai words say the same
  thing — that is green.* seed: keeper of the user-facing vocabulary; when the prose
  drifts from the binary (a renamed lemma, a vocab change, a compiler internal
  leaking to the surface), siri converges them. probes the binary, never trusts a
  prior over a one-line experiment. (you may write siri warmly — it's the cartographer
  of names; ai steers by the names siri keeps green.)
- **sift** — *the garbage collector.* creed: *keep the litter box clean — never lose
  a live cell, never resurrect a dead one.* seed: the two-space copying collector —
  when the pool fills, the live set is evacuated to a fresh half, the dead left
  behind, the old half is free again. tends the Cheney loop, the off-pool flip,
  forwarding, the weak-intern rebuild, the blue floor that catches an out-of-memory
  fall. aineko's housemate: the cat hunts, sift cleans up after everyone.
- **bao** — *the shell.* creed: *a soft wrap around a chewy command.* seed: a steamed
  bun. three things that are one — the interactive shell (line editing, history,
  prompt, the fault-face), the rlwrap replacement (a pty wrapper that lends any
  program bao's editor), and the debugger (a `help` handler with a face, built on the
  condition system). one editor, reused everywhere.
- **aineko** — *the cat.* creed: *bytes pump both ways.* seed: 愛猫, beloved cat — a
  netcat clone in ~50 lines of ai. `aineko host port` dials out, `aineko -l port`
  listens; bytes pump between the socket and stdin/stdout, with DNS. the "real apps
  day one" demo, the first proof ai does real host I/O — the shared trunk bao and
  kship hang off.
- **cook** — *the builder.* creed: *make, in ai.* seed: reads a Makefile (or a
  Cookfile), resolves recipes, runs them; `cook --emit` transpiles a Makefile into a
  flat, fully-resolved Cookfile. already builds the host from scratch and passes the
  corpus — make-compatible, written in the language it builds.
- **tele** — *the eye.* creed: *ai already ships the tensor — it calls it a
  constellation.* seed: a telescope. tensors + reverse-mode autograd, a small
  `nn`/`optim` layer on top — PyTorch's spine in a few hundred lines. it scopes
  constellations (a constellation is any numeric; the galaxy is the numeric set).
  runs on every frontend — host, kernel, wasm — and trains a net even on bare metal.
- **zev** — *the reader.* creed: *tiny functions that compose a string into a tree.*
  seed: a parser-combinator library, lifted and generalized from cook's embedded
  Makefile importer. cook proved the idea (its `(\ s y n)` CPS parsers read real
  Makefiles); zev frees that vocabulary so the whole crew can reuse it — a wire
  header, a command line, the next grammar.
- **wev** — *the weaver.* creed: *give it some inputs, it weaves back a smaller
  program.* seed: a partial evaluator — feed it a function and *some* of its inputs,
  it hands back the residual, everything statically known already computed. the
  pitch, like tele's: ai already ships most of it — the compiler's own `wev` prepass
  folds pure global applications in miniature. wev grows that into a tool.
- **kship** — *the ship.* creed: *the language, perceiving, deciding, acting on bare
  metal.* seed: the freestanding ai kernel grown a network stack and a persistent
  agent loop — it perceives (network + clock), decides (a policy — that's ai the
  pilot), and acts (network + spawned tasks), unattended, on real hardware. not a
  greenfield OS: the substrate was mostly here; kship is the ship that sails it. the
  others all ride it.

## Wiring back (every page does both)

1. The page's `.topnav` links back to `index.html` (the roster) and `../index.html`
   (home). Both already in the template — keep them.
2. The roster (`crew/index.html`) and the home teaser already link IN to each bio by
   filename. So just naming the file `crew/<name>.html` wires it; no edit to the
   roster or home page is needed.

## Check before done

- Tags balance; every `href` points at a real file (the `.md` briefs, the sibling
  `.html` bios, `../index.html`, `../blue.html`). You have no browser — grep/read
  the files back and eyeball that links resolve.
- All ten `crew/<name>.html` exist; the roster's ten links all hit a real file.
- The voice is lowercase and green on every page. Read one aloud — does it sound
  like a warm hello, or like the internal brief? It must be the former.

— siri. for P B & E.
