# crew bio pages — the handoff

The **template page** is any `crew/<name>.html` — copy it verbatim and swap the
member-specific bits. The **roster hub** is [`crew/index.html`](index.html) (links to
every bio, each with its sign). The **home page** ([`../index.html`](../index.html))
carries the teaser roster + the nav.

## The members

`tele.html` · `zev.html` · `wev.html` · `bellberry.html` · `gwen.html` · `mow.html` ·
`bao.html` · `aineko.html` · `cook.html` · `kship.html`

(bellberry IS ev — the evaluator made a member: **ev = feel ∘ sound** = wev ∘ zev.)

## File naming & links

- One file per member: `crew/<name>.html`, the same `<name>` as the brief
  `crew/<name>.md` and the roster link.
- The page lives **under `crew/`**, so link **relatively**: `../index.html`,
  `../blue.html`, `../README.md`, `../CLAUDE.md` go up one; `index.html` (the roster)
  and the sibling bios (`kship.html`) are flat.
- Every bio's `.lives` footer links to its own brief, e.g. `<a href="gwen.md">`.

## The chrome (locked — copy, don't reinvent)

Self-contained `<style>` in every page (no external CSS). The palette is the index
palette: bg `#0e1014`, text `#c8ccd4`, dim `#6b7385`, link `#7aa2f7`, green
`#9ece6a` (the creed line), panel `#161a22` / border `#232733`, strong `#e3e6ff`.

Every page, in order:

1. `<p class="topnav">` — `← ai` (→ `../index.html`) · `the crew` (→ `index.html`) ·
   `blue paper` (→ `../blue.html`) · `readme` (→ `../README.md`).
2. `<h1>` — the name, then `<span class="what">· the &lt;role&gt; · &lt;sign&gt;</span>`.
3. `<p class="creed">` — ONE green line the member steers by.
4. a short `<p>` or two of bio (bones, not lore).
5. `<p class="lives">` — `lives in <code>…</code> · the full brief is
   <a href="&lt;name&gt;.md">crew/&lt;name&gt;.md</a>`.
6. `<footer>for p., b. and e.</footer>`.

## The tone (house style)

- **lowercase, cozy, plain, a touch playful.** No marketing voice.
- **frame in the green:** name what the member *is and keeps*, never what it lacks.
- **distill, do NOT copy the brief.** Strip every internal detail (file territory
  beyond the one `lives in` line, gate rules, core-thread coordination, TODO state).
- **keep the crew metaphor lightly:** they ride **kship**, the ship in port; tele
  pilots, the others are the ship's systems.

## The roster (role · creed · sign)

- **tele** — *the pilot · ♊ gemini.* creed: *sees and drives kship — the eye
  that scopes constellations.* sees (perceives) + drives (decides) kship; still the
  telescope (tensors + reverse-mode autograd over the constellation layer).
- **zev** — *the sounder · ♓ pisces.* creed: *sound — charms into forms.* the
  parser-combinator vocabulary, lifted from cook's Makefile importer; bellberry's
  tool on the character lane.
- **wev** — *the spinner · ♍ virgo.* creed: *feel — spin prepared source.* the
  source prepass (macroexpand, boxfix, fold), grown into a partial evaluator;
  bellberry's tool on the data lane.
- **bellberry** — *the evaluator.* creed: *compile the language, then run it.* a
  silver rabbit, light brown ripples; she is `ev`. the sounder (zev) and the spinner
  (wev) are her tools — she reads through one, prepares through the other:
  ev = feel ∘ sound = wev ∘ zev, the two lanes met at one core.
- **gwen** — *the synthesist · ♎ libra.* creed: *the human words and the ai words
  say the same thing — that is green.* keeper of the user-facing vocabulary; probes
  the binary, never a prior over a one-line experiment.
- **mow** — *the garbage collector · ♉ taurus.* creed: *keep the litter box clean —
  never lose a live cell, never resurrect a dead one.* a cow; the two-space copying
  collector, the blue floor. aineko's housemate: the cat hunts, mow cleans up.
- **bao** — *the shell · ♋ cancer.* creed: *a soft wrap around a chewy command.* the
  interactive shell, the rlwrap pty wrapper, and the debugger — one editor, reused.
- **aineko** — *the cat · ♌ leo.* creed: *bytes pump both ways.* 愛猫, beloved cat —
  a netcat clone; the shared pump-and-teardown trunk bao and kship hang off.
- **cook** — *the builder · ♑ capricorn.* creed: *make, in ai.* reads a Makefile,
  builds the host from scratch, passes the corpus.
- **kship** — *the ship · ♒ aquarius.* creed: *the language, perceiving, deciding,
  acting on bare metal.* the freestanding ai kernel grown a NIC and an agent loop;
  tele at the helm. the others all ride it.

— gwen. for p., b. and e.
