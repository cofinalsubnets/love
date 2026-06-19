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
to keep its editor off the book):

```
(zev (\ eps lit one span alt seq seqs opt many pmap parse   ; ... fixed, documented order
   <your grammar, written against those names>))
```

One book key (`zev`), no collisions by construction, no per-use tablet lookups. The
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

zev is a **library**, not corpus: `make test` globs `test/*.l`, and `parse/zev.l`
isn't there — so the test must *load the library first*. It gets its own target,
exactly like cook's `test_cook`:

```
test_zev:  cat test/00-init.l parse/zev.l parse/zevtest.l | out/host/ai
```

(`test/00-init.l` installs the assert harness; this is the same standalone-verify
pattern the host-nif crew use.) Wiring `test_zev` into the build is a one-line
Makefile edit — **build territory, hand it to the core/build thread**; until then
run the `cat`-pipe by hand. The single-global discipline still bites here, but the
reason is sharper than "corpus collision": when a tool does `ai -l parse/zev.l …`,
any global zev defines **shadows the egg's own `parse`/`span`/`$`** for that session.
The tablet design (below) makes that impossible — those names never become globals.
`make valg` and the order law are unaffected by a pure-ai library.

---

# Spec — `parse/zev.l` (v1, implementation-ready)

> Status: **specified, not built** (kship is flying — no binary run this session).
> The ai source below is faithful to cook's proven block but the prel names it leans
> on (`cat` `L` `link` `snip` `tally` `foldr` `rev` `two?` `hash`/`tablet`) are mid
> vocab-sweep — **probe each at the binary before landing** (a rename surfaces as zev
> going mass-red, cook's lesson). This is the hand-off artifact for the build session.

## §1 API shape — RESOLVED: `zev` is a tablet (supersedes the tentative "injection" rec above)

`zev` is **one global**, bound to a **tablet** (map) from a combinator's name-symbol
to the combinator. A map is a lookup function, so `(zev 'seq)` *is* the `seq`
combinator; `(keys zev)` introspects the whole vocabulary. A grammar binds the few it
needs to locals once, then reads cleanly:

```
(: alt (zev 'alt)  seq (zev 'seq)  lit (zev 'lit)  span (zev 'span)
   skip (zev 'skip)  pmap (zev 'pmap)  parse (zev 'parse)
   chws (zev 'chws)  namech (zev 'namech)
   ; ... the grammar now uses bare alt/seq/lit/span/... :
   opP (alt (lit "::=") (alt (lit ":=") (alt (lit "?=") (alt (lit "+=") (lit "=")))))
   (parse opP "::="))
```

**Why the tablet, not the pfile's earlier "injection" `(zev (\ eps lit … body))`:**
injection binds the vocabulary *positionally*, so every call site must list the
combinators in one fixed order — and Phase 2 grows the set from ~12 to ~25 (the
char-class predicates alone are 6). One added combinator shifts every adopter's
parameter list. The tablet is insertion-order-free and grows without touching a single
call site. Cost: `(zev 'seq)` at the binding preamble instead of a bare param. Cheap.
**Confirm this and I'll lock it; the flip back to injection is mechanical if you'd
rather.**

## §2 The combinators — exact source

### Base (lifted VERBATIM from `cook/cook.l:234-253` — do not redesign)

```
eps (\ s y n (y s 0))
(lit l) (\ s y n
   (? (&& (<= (tally l) (tally s)) (= l (snip s 0 (tally l))))
      (y (snip s (tally l) (tally s)) (L l)) (n s)))
(one p) (\ s y n
   (? (&& (< 0 (tally s)) (p (s 0)))
      (y (snip s 1 (tally s)) (L (s 0))) (n s)))
(span p) (\ s y n                        ; ALWAYS succeeds; payload may be the empty run
   (: i ((: (g j) (? (&& (< j (tally s)) (p (s j))) (g (+ 1 j)) j)) 0)
      (y (snip s i (tally s)) (L (snip s 0 i)))))
(alt a b)  (\ s y n (a s y (\ _ (b s y n))))
(seq a b)  (\ s y n (a s (\ s1 p1 (b s1 (\ s2 p2 (y s2 (cat p1 p2))) n)) n))
(seqs l)   (foldr seq eps l)
(opt a)    (\ s y n (a s y (\ _ (y s 0))))
(skip a)   (\ s y n (a s (\ s1 _ (y s1 0)) n))
(pmap f a) (\ s y n (a s (\ s1 x (y s1 (f x))) n))
(many a)   (\ s y n
   (a s (\ s1 p1 (many a s1 (\ s2 p2 (y s2 (cat p1 p2))) (\ _ (y s1 p1))))
        (\ _ (y s 0))))
```

### Generalizations (v1 — each DEFINED IN TERMS OF the base, so low risk)

```
(many1 a)      (seq a (many a))                          ; one or more
(sepby1 p sep) (seq p (many (seq (skip sep) p)))         ; p (sep p)*
(sepby p sep)  (alt (sepby1 p sep) eps)                  ; the above, or empty
(between l r p)(seqs (L (skip l) p (skip r)))            ; payload of p only
(as v a)       (pmap (\ _ (L v)) a)                      ; replace payload with constant v
eof            (\ s y n (? (= 0 (tally s)) (y s 0) (n s)))
(peek a)       (\ s y n (a s (\ _ p (y s p)) n))         ; succeed w/ payload, consume nothing
(notp a)       (\ s y n (a s (\ _ _ (n s)) (\ _ (y s 0))))  ; negative lookahead
(in-set c set) ((: (g i) (? (>= i (tally set)) 0 (? (= c (set i)) 1 (g (+ 1 i))))) 0)
(oneof set)    (one (\ c (in-set c set)))
(noneof set)   (one (\ c (! (in-set c set))))
ws             (skip (span chws))                        ; eat optional whitespace
(tok a)        (seqs (L a ws))                           ; lexeme: a, then trailing ws
```

### Char classes (lifted; `?`-renamed for the predicate sweep)

```
(chws c)     (|| (= c 32) (= c 9))
(digit? c)   (&& (<= 48 c) (<= c 57))
(alpha? c)   (|| (&& (<= 65 c) (<= c 90)) (&& (<= 97 c) (<= c 122)))
(namech c)   (|| (alpha? c) (|| (digit? c) (|| (= c 95) (= c 46))))
(notcolon c) (&& (! (chws c)) (! (= c 58)))
(anyc c)     1
```

### Drivers

```
(parse p s) (p s (\ r x (? (= 0 (tally r)) x ())) (\ _ ()))  ; FULL consume or () ; cook's
(run p s)   (p s (\ r x (link x r)) (\ _ ()))                ; PREFIX: (payload . rest), () on fail
```

`run` is the new one — for wire/stream framing where the input isn't fully consumed
(aineko headers, kship packets). `parse` stays cook's all-or-nothing driver.

## §3 Payload & failure model (v1)

- **Payload** is a list; the empty payload is `0` (the zero point). `cat` concatenates
  and MUST satisfy `(cat 0 x) = x` (cook relies on this — verify `cat` survives the
  sweep; fallback is a 3-line `(append a b)` local, NOT `+`, which *adjoins*).
- **Build trees with `pmap`**: `(pmap (\ xs (L (link 'assign xs))) assignP)` folds a
  flat match list into one tagged node — the generalization over cook's flat token list.
- **Failure** is cook's: `n` takes only the input to backtrack to; `parse` returns `()`
  (nothing/false — test with `two?`, not net) on *any* failure, with no position or
  reason. v1 keeps this. **Phase 2** (NOT in this spec) enriches `n` to `(n s exp)`
  carrying a furthest-position + expected-set and adds `(label name a)`; that's the only
  base-combinator change deferred, and it's additive.

## §4 File layout

```
parse/zev.l                       ; ONE top-level form: (: zev (: <all defs local> (hash 'eps eps ...)))
parse/zevtest.l                   ; the asserts (parity + unit); run via test_zev
doc/zev.3                         ; man page, section 3 — API ref of the §2 table
```

`parse/zev.l` skeleton (the whole file is one body-having `:` whose body is the tablet,
so every helper stays local and the ONLY global is `zev`):

```
; parse/zev.l -- the zev parser-combinator library. ONE global: `zev`, a tablet.
(: zev
   (: eps (\ s y n (y s 0))
      (lit l) (\ s y n ...)          ; ... all of §2 here, as locals ...
      (run p s) (p s (\ r x (link x r)) (\ _ ()))
      ; collect the surface into the one tablet:
      (hash 'eps eps  'lit lit  'one one  'span span  'alt alt  'seq seq  'seqs seqs
            'opt opt  'skip skip  'pmap pmap  'many many  'many1 many1
            'sepby sepby  'sepby1 sepby1  'between between  'as as  'eof eof
            'peek peek  'notp notp  'oneof oneof  'noneof noneof  'ws ws  'tok tok
            'parse parse  'run run
            'chws chws  'digit? digit?  'alpha? alpha?  'namech namech
            'notcolon notcolon  'anyc anyc  'in-set in-set)))
```

(`(: zev <expr>)` at top level is a body-less binding → it defglobs `zev`; the inner
`:` HAS a body — the `hash` — so its bindings stay local. Confirm the ctor is `hash`
vs `tablet` at the binary.)

## §5 The parity test (`parse/zevtest.l`)

Phase-1 acceptance = **zev re-derives cook's line grammar and classifies identically.**
Bind the combinators from `zev`, rebuild cook's three parsers verbatim, assert:

```
opP     ; (alt (lit "::=") (alt (lit ":=") ... (lit "=")))
assignP ; (seqs (L (skip (span chws)) (span namech) (skip (span chws))
        ;             (pmap (\ x (L (cap x))) opP) (skip (span chws)) (span anyc)))
ruleP   ; (seqs (L (skip (span chws)) (span notcolon) (skip (lit ":")) (span anyc)))

(assert (= (parse assignP "CC := clang")    (L "CC" ":=" " clang")))   ; name op val
(assert (= (parse ruleP   "all: a b c")     (L "all" " a b c")))       ; tgt prereqs
(assert (= (parse assignP "all: x")         ()))                        ; not an assign
(assert (= (parse opP "+=") (L "+=")))
```

Plus unit asserts for the v1 generalizations (`many1`/`sepby`/`between`/`oneof`/`run`/
`eof`/`notp`) and the empty-edge cases (`(parse (span digit?) "")` → the empty run;
`(run (lit "ab") "abcd")` → `("ab" . "cd")`). Exact expected values get pinned during
the build run (some depend on `cat`'s empty behavior — confirm at the binary).

## §6 Open items / cook coordination

- **`cat` / `hash` / `L` survive the sweep?** Probe before landing (§ status note).
- **API shape (§1)** — confirm tablet, or say the word for injection.
- **cook parity sign-off** — this spec rebuilds cook's grammar from the *outside*; have
  the **cook thread review §5** against the live `assignP`/`ruleP` to confirm the
  expected payloads are exactly what cook's `classify` consumes. (Read-only review — no
  cook.l edit; adoption is Phase 3, and lands in cook's session, not zev's.)
- **`test_zev` Makefile wiring** — build territory; hand to the core/build thread.
