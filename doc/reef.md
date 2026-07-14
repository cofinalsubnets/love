# reef — the vcs and the distro, one verb set

Status: **the local half is live** (2026-07-14, `ad95e3c4`): `record` · `log` ·
`diff` over the content-addressed store — [`crew/reef/reef.l`](../crew/reef/reef.l),
gated by `make test_reef`; a hunk is test/patch.l's proven `chg` at file grain
(slot = path, context = old content hash). `sync` / `hatch` / `cut` / `undo` are
still design. The rest of this doc is the design brief from the 2026-07-14
session. The **interface** layer over the model in [`doc/hatch.md`](hatch.md)
(the patch DAG, the hatch derivation, the nest, refs) and the machinery in
[`port/inle/{serve,drive,patch}.l`](../port/inle/patch.l) (the dock — adopt +
two-generation re-exec). hatch.md says *what the objects are*; this says *what
you type*. `reef` is the crew name (🪸 coral); the command name is provisional —
see §Naming.

## the one principle

reef is a version control system **and** a distribution/install system, and the
thesis of hatch.md is that these are the *same act*: **installing is
cloning-and-hatching a local checkout.** So the design rule is:

> Do not design a vcs verb set and a distro verb set. Design the **vcs
> primitives** plus one derivation verb (`hatch`), and let the distro
> front-doors be *named compositions* of those.

If "install" or "upgrade" turns out to be an irreducible verb of its own, the
collapse has leaked — that's the smell to watch. install and upgrade must fall
out of `sync` + `hatch`, or the two systems have quietly come apart again.

## the primitives

| verb | does | vcs hat | distro hat |
|---|---|---|---|
| **`record`** | working changes → a patch in the DAG | commit | — |
| **`sync`** | union patch sets with another nest (peer *or* URL) | the divergent-tips → set-union payoff | clone / pull / fetch-a-release are all this |
| **`apply`** | pull a specific patch/ref out of the local store into the working tree | checkout / cherry-pick (any dep-consistent subset is valid) | select which release a nest realizes |
| **`hatch`** | `(patch set, arch)` → native binary in the nest | — | the derivation; cached-default, local-rebuild fallback |
| **`cut`** | freeze the current single-tip head → a named, immutable release | tag | the unit you propagate/clone |
| **`log`** | view the DAG + tips + refs | inspect | inspect |
| **`diff`** | working tree vs a ref, or ref vs ref | inspect | inspect |
| **`undo`** | add the *inverse* patch — revert as growth, never deletion | revert | rollback-by-superset |

`sync` is the star. Making it the single verb for clone / pull / push /
multi-machine-union is what literally realizes "distribution == cloning" at the
CLI: whether the other end is a peer machine or a release CDN, the operation is
the same — *exchange patch sets*. `apply` stays separate because it is *local*
DAG surgery (materialize a subset into the working tree), which the network
exchange isn't.

## the front-doors (sugar, not primitives)

- **install** = `sync <url>` + `hatch` into a fresh nest
- **upgrade** = `sync` (a newer release) + `hatch`
- **clone** = `sync` from empty

These are named compositions for humans, deliberately *not* new verbs. That they
compose is the proof the collapse held.

## MVP — what rides this cut

hatch.md is explicit that the near-term job is a **population of one**: move
development between gwen's own machines cheaply, union the tips when they
diverge (§"this is a personal multi-machine sync tool"). So the cut needs exactly:

> **`record` · `sync` · `log` · `diff`** + **`hatch`**

That is the difference from the first sketch (`record` / `log` / `apply` /
`diff`): it swaps in **`sync`**, because the actual payoff is peer union between
laptop and desktop, which local `apply` never reaches. `cut` / `undo` and the
install/upgrade front-doors are **reserve-the-names, land-later** — enough to
prove the model, not the whole distro story.

## why reef (the metaphor earns the invariants)

`reef` is not decoration; it names two properties of the model more accurately
than "tree" did.

- **No root, no trunk.** hatch.md kills the privileged trunk — `main` dissolves,
  no linear canonical history, any dep-consistent subset is a valid source, and
  divergent tips with no order between them are *normal*, not a merge chore. A
  *tree* implies exactly the root-and-trunk hierarchy the design rejects (it's
  git's mental model). A **reef** is a rootless colony that accretes in every
  direction with many growth tips — the DAG, not a chain.
- **Accretion is the inverse-patch law.** The core discipline is "removal is an
  inverse patch, never a deletion; the patch set only ever grows," which is what
  makes the default channel R₀ ⊆ R₁ ⊆ R₂ … well-defined (⊆ total). A reef only
  builds up — even a rollback is a *new layer* of growth, never erosion. The
  metaphor carries the single most important invariant for free.

And it deepens the 🪸 coral persona instead of sitting beside it: a reef is a
coral colony, so the verbs get a coherent flavor rather than a stranded one —
patches **bud**, you **graft** one in, a release is a **cutting** you propagate
(install = grow a frag of the reef elsewhere = clone-and-hatch). Coral is
literally propagated by cuttings and grafts, so `cut` (freeze a release) *is* the
unit you clone — one word, both meanings.

The one thing traded: `tree` read as "version control" on sight; `reef` leans on
the persona to carry that. Since the model isn't a tree and the persona does the
work anyway, that's the right trade.

## naming

- **`reef`** — the crew name / system (🪸 coral; colony = the whole patch DAG).
  No `tree(1)` collision (the reason to move off `tree`). The *command* name is
  still open: `reef <verb>` reads fine; whether the bare install command is
  `reef <url>` or a friendlier alias is a small later call.
- **verb flavor.** Plain (`record` / `apply` / `cut`) is primary for
  discoverability. A coral-flavored set is available if wanted: `bud` (a patch
  buds off) / `graft` (bring one in) / `cut` (the cutting = release = clone
  unit) / tips (already the doc's word for the growth ends). gwen picks the
  flavor — naming's her call under the freeze.
- **the local home.** hatch.md floats `nest` / `roost` / `seed`, leaning on the
  egg/hatch/born bootstrap cluster. The reef metaphor offers `frag` (aquarist
  term for a propagated coral piece) or a local `head` if metaphor-unity is
  wanted; the two clusters meet cleanly at the install seam, so either works.

## open forks

1. **`sync` unified, or split `push`/`pull`?** Lean unified (it *is* the thesis),
   but a directional pair reads clearer when a remote is authoritative
   (fetching a release ≠ pushing to a peer).
2. **Does a nest need an explicit `pick`/`use` to switch its live ref, or is that
   just `apply <ref>`?** Lean fold-into-`apply`, skip the verb.
3. **the command surface** — bare `reef <url>` as install, or a front-of-house
   alias. Deferred with the toolchain-multiplexer question in hatch.md.

## where it lives

`crew/reef/` + a book (the holo/kore all-the-way-down precedent). The dock
cluster ([`port/inle/`](../port/inle/), memory `the-dock`) already does the hard
half — apply a patch, gate it (rebuild + `make test`, red reverts), adopt it
(re-exec onto the new generation). `hatch` is that machinery pointed at a
*remote* patch source instead of the local model proposer; `sync`/`record` are
the DAG surface over the same store. See hatch.md §"What we already have."
