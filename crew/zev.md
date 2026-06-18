# zev — the parser combinator

`parse/zev.l` is a **parser-combinator library written in ai**: a small, tested,
reusable vocabulary for turning a string into a tree, built the way cook's Makefile
importer is built — out of tiny functions that compose. cook PROVED the idea works
(its `(\ s y n)` CPS parsers read real GNU Makefiles); but cook's combinators are
**locked inside one body-having `:`**, private and unreusable, reimplemented from
scratch the next time anyone needs to parse a wire header or a command line. zev
lifts that block out, generalizes it, and gives the whole crew **one shared
combinator vocabulary** instead of N hand-rolled `(: (g i ...) ...)` char loops.

(Ze'ev is the wolf; a wolf hunts in a pack. A combinator is nothing alone and
everything composed — which is the whole of the idea, and the rest is bookkeeping.)

## Agent brief — you are the zev thread

You build zev, in parallel with the aineko / bao / cook / kship threads. Like cook
you are **pure ai over the core** — no host nif, no entry change, no core change —
so you have the lightest possible coupling and can move without waiting on anyone.
Your one hard constraint is the corpus: zev must coexist in the **global concatenated
scope** `make test` runs, so it cannot leak a name that collides (that is the whole
design problem — see below).

- **Your territory (you own these):** `parse/zev.l` (the library), `test/zev.l` (the
  test — see *Gate*), `doc/zev.3` (a man page; section **3**, it's a library, not a
  CLI). The `parse/` dir is yours, new, mirroring `cook/`.
- **Read-only for you:** `cook/cook.l` (the reference combinators — `cook/cook.l:233`
  is the block you are lifting), `ai.h`, this doc, and the prel names zev leans on
  (`snip` `tally` `cat`/`+` `link` `foldr` `rev` `two?` …). Probe them at the binary;
  a vocab rename in the corpus surfaces as zev going mass-red (cook learned this the
  hard way — `link`/`nom?` drift turned 30 tests red at once).
- **DO NOT EDIT `ai.c` / `ai.h` / `main.c`** or other threads' files (`host/*.c`,
  `cook/cook.l`, `tools/aineko.l`, `ai/bao.l`, `port/kship/`). zev needs **no core
  change** — if you think you do, you've reinvented something the prel already has;
  ask the core thread (the main session) before reaching in.
- **Coordinate before adopting.** Refactoring cook's importer onto zev (Phase 3) edits
  `cook/cook.l` — that is the **cook thread's** territory. Propose it, hand over the
  diff, or pair; never land it from this session. Same for aineko/bao command parsing.

## The model — a parser is `(\ s y n)` (lifted from cook)

The heart, verbatim from `cook/cook.l:233-253`, is the right design and zev keeps it:
a **parser is a function `(\ s y n)`** over the unconsumed string `s`, with two
continuations —

- `y` = **success**, called `(y rest payload)`: the still-unparsed tail and the list
  of what was matched;
- `n` = **failure**, called `(n s)`: backtracks, handing the input back untouched.

The payload is a list that `seq` concatenates with `cat`; `alt` is ordered choice
(try `a`, on failure try `b` at the same point), so backtracking is **free and pure**
— no mutation, no position cursor, no regex (ai has none, by design). The leaves
(`lit` a literal prefix, `one` a char by predicate, `span` a maximal run) plus
`alt`/`seq`/`seqs`/`opt`/`skip`/`pmap`/`many` and the `(parse p s)` driver are the
whole base. Read that block before writing a line of zev — you are generalizing it,
not redesigning it.

## ★ The central design decision — one global, zero collisions

cook hides its combinators in a body-having `:` **specifically because `parse`,
`span`, and `sat`/`$` collide with egg globals** (cook.md, the importer note). A
*library* wants its vocabulary reachable — but zev's test rides the global corpus, so
a leaked `parse`/`span` would break `make test` for everyone. The collision is not an
annoyance; it is the spec. zev must expose **exactly one** global.

**Recommended (ratify with the user):** zev is a single global `zev`, a constructor
that **injects** its combinator vocabulary into the scope of a grammar you hand it —
the "with-combinators" form, every internal closure-private (the same trick bao used
to keep its editor off the bag):

```
(zev (\ eps lit one span alt seq seqs opt many pmap parse   ; ... fixed, documented order
   <your grammar, written against those names>))
```

One bag key (`zev`), no collisions by construction, no per-use tablet lookups. The
alternative — `(zev)` returns a **tablet** of combinators you `peep` out — is simpler
to extend but verbose at every use site. **Decide this first**; everything downstream
(the test, the man page, every adopter) depends on the shape. Until ratified, develop
`test/zev.l` self-contained (library + asserts in one file, helpers local).

## Roadmap

1. **Lift (parity).** Move cook's combinator block into `parse/zev.l` behind the
   chosen single-global shape. Prove parity by **re-deriving cook's own line grammar**
   (`assignP`/`ruleP`, cook.l:324-328) on top of zev and asserting it classifies the
   same lines the same way. Resolve the collision shape (above). No new behavior yet.
2. **Generalize.** Add what a real library needs and a flat make-line parser never did:
   `sepby`/`endby`, `between`, `eof`, `peek`/`notp` (lookahead), `oneof`/`noneof`,
   `lexeme`/`token` (whitespace-skipping), `number`/`int`/`float`, and `label` for a
   named-expectation error instead of cook's bare `(n s)`. Generalize the payload from
   "a flat list `cat` concatenates" to **`pmap`-built trees** so grammars fold matches
   into an AST, not just a token list. Give failure a **position + expected-set** so a
   parse error can say *where* and *what was wanted*.
3. **Adopt (the proof of reuse).** Offer zev to one crew tool and show no regression.
   The strongest demo: refactor cook's importer onto zev — but that's cook's file, so
   **coordinate** (Phase-3 rule above); `test_cook` staying green IS the proof. Lighter
   alternatives that stay in friendly territory: aineko protocol/argument parsing, or
   bao's repl/debugger command line.
4. **Prototype the infix reader (post-v1).** `chainl1`/`chainr1` (left/right-assoc
   operator parsing) make zev the natural sandbox for the **frozen infix-surface design
   queue** (the two-tier `lassoc`-above-`rassoc` reader). Prototype it in zev *before*
   anyone touches the C reader — design before building.

## Gate

zev is pure ai with no host nif, so it gets a **normal corpus test**: drop the asserts
in `test/zev.l` and `make test` covers it (host + ai0×2) with **no Makefile edit** —
the corpus globs `test/*.l` and runs them concatenated in one global scope. That scope
is exactly why the single-global design is non-negotiable: if zev leaks a colliding
name, the gate goes red and tells you immediately. Keep every helper local; the only
name `test/zev.l` may add to the global bag is `zev` itself. `make valg` and the order
law are unaffected by a pure-library addition, but run host + ai0 before every handoff.
