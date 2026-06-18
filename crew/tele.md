# tele — a PyTorch clone in ai

A design sketch (recon done, ready to build). **tele** (telescope) is a tensor +
reverse-mode autograd library written in ai, with a small `nn`/`optim` layer on
top — PyTorch's spine in a few hundred lines. **tele scopes constellations.**

The pitch: **ai already ships the tensor — it calls it a constellation.** A
**constellation** is any numeric; it comes in two shapes:

- a **star** — a self-netting scalar (a charm/wide/big/float/complex; ai's `gem?`);
- a **galaxy** — a tray of stars, i.e. a typed, n-dimensional, numpy-broadcasting
  numeric array (ai's `crest?`, a numeric `tray`).

A constellation already has reductions (`asum`/`aprod`/`amax`/`amin`), contractions
(`inner`/`outer`), and elementwise transcendentals (`sine`/`cosine`/`log`/`pow`).
That is `torch.Tensor` minus one thing: the **gradient**. tele adds exactly that —
autograd — and reimplements nothing a constellation already does. A telescope
points at a constellation, focuses it through a **glass**, and traces the light
back home.

We skip what PyTorch carries that a clone doesn't need to prove the idea: CUDA, a
dispatcher, TorchScript, the 2000-op ATen surface, dynamic-shape JIT. The thesis is
**autograd over the existing constellation algebra**, plus enough `nn` to train a
real net (an MLP on XOR, then MNIST-shaped digits if the kernel demo wants it).

## Agent brief — you are the tele thread

You build tele, in parallel with the aineko / bao / cook / kship / siri threads.
Like cook, you have **light coupling**: tele is pure ai over the constellation
layer, so it runs on *every* frontend (host, kernel, wasm) and needs **no entry
change** to make progress. Unlike cook, you have a short list of **core asks**
(below) — galaxy moves autograd wants that the array surface doesn't expose yet.

- **Your territory (you own these, edit freely):** `tele/tele.l` (the library),
  `tele/teletest.l` (the gradient-check gate), `tele/xor.l` (the demo),
  `doc/tele.1`, a new `test_tele` target (run by `make -C tools`, the way cook
  gates `test_cook`).
- **Read-only for you:** `ai.h`, this doc, `ai/prel.l` (the constellation vocab —
  star/galaxy ops — is your whole substrate; read it, lean on it, don't edit it),
  `CLAUDE.md` (the array section is your spec).
- **DO NOT EDIT `ai.c` / `ai.h` / `main.c`** or other threads' files (`host/*.c`,
  `tools/aineko.l`, `ai/bao.l`, `cook/cook.l`, `kmain.c`). tele is pure ai; it
  needs no core edit to be CORRECT. When you want a core edit it is for SPEED (a
  baked galaxy kernel) — **stop and ask the core thread** (the main session), who
  owns `ai.c`/`ai.h`. Never reach in.
- **Keep `ai/prel.l` constellation-only.** tele leans hard on the star/galaxy
  surface but adds NOTHING to the corpus — your code lives entirely under `tele/`,
  loaded with `-l tele/tele.l` exactly as a user `-l`s `prel`. So `make test` (host
  + ai0 ×2 + rocq) is untouched by construction; your gate is `test_tele`.
- **First task:** the autograd core — the `glass` node + the four lens ops
  (`add`/`mul`/`mm`/`sum`) + `back` + numeric grad-check — gated by `test_tele`.
  Everything else (`relu`, `nn`, `optim`, the demo) hangs off a correct `back`.
- **Gate:** `make -C tools test_tele` green (the gradient check IS the oracle — see
  below); `make test` stays green (you never touch the corpus).

## Why a PyTorch clone is the right demo

aineko proves ai does host I/O. cook proves ai builds itself. tele proves the
**numeric tower and the constellation algebra were the point all along** — that
ai's generic, broadcasting, complex-capable galaxy is a real tensor, and that one
missing ingredient (the adjoint) turns it into a deep-learning framework. It is the
demo that says *this is a language you'd compute in*, not just a clever core.

And it rides the whole crew: pure ai means tele runs on **kship**, the freestanding
kernel. "Train a neural net on bare metal, no OS, no libc" is the flagship kship
story — a telescope on the ship.

## The thesis — autograd is a lens, backward is the adjoint

The mechanism is one idea, and it is native to ai's currying. **Reverse-mode AD is
the category of lenses** (Elliott, *The Simple Essence of Automatic
Differentiation*): a differentiable op is not a function `a → b`, it is a pair

```
forward :  a → (b , (b̄ → ā))
```

the value `b` *and* the linear backward map from the output cotangent `b̄` to the
input cotangent `ā`. That second component is a closure — and ai is closures all
the way down, so it falls out for free. Composing ops composes lenses; a whole
network is one big lens; `.backward()` is the **put** of that composite, seeded
with the cotangent `1`.

The optics name is not decoration: a telescope traces light forward to an image,
and **reverse-mode AD is the adjoint ray-trace** — the same rays walked backward
through the same lenses. Forward = the image you see; backward = the light going
home. Each op is a lens; the network is the telescope; `back` is the adjoint.

### The representation

A telescope **glass** is a node — a small chain (or tablet) carrying (you look
*through* a glass to the constellation, and the light traces back through it):

- `val` — a constellation (a galaxy, or a star for a scalar; the forward value). A
  bare constellation with no glass around it is a **constant**, exactly
  `requires_grad=False`;
- `grad` — a constellation accumulator (the cotangent landing here);
- `bwd` — the lens's backward closure: given this node's upstream cotangent, it
  pushes contributions into each parent's `grad`;
- `kids` — the parent nodes (the Wengert list edges).

`(glass v)` wraps a constellation as a **leaf** that requires grad; `(const v)`
wraps one that doesn't. `back` does a reverse topological walk — seed the output
grad with `1`, then in reverse creation order call each node's `bwd` to scatter
cotangents to its parents, **accumulating** (a node fanning out to two consumers
sums its gradients, the multivariate chain rule). `(grad t)` reads a leaf's
accumulated cotangent after `back`.

**Grad accumulation keys on node identity** — and ai just handed us the perfect
key: a fresh `mint` per node gives a GC-stable, structurally-distinct map key for
free (the nom-fixpoint work). The tape is a `tablet` keyed by each node's mint;
no identity-comparison hazard, no aliasing bug.

## The vocab map (PyTorch → tele)

| PyTorch | tele | notes |
|---|---|---|
| `torch.tensor(x, requires_grad=True)` | `(glass v)` | wraps a constellation as a leaf glass |
| a constant tensor | `(const v)` or a bare constellation | no grad; `requires_grad=False` |
| `a + b`, `a * b` | `(add a b)`, `(mul a b)` | broadcasting lifts straight from the galaxy's `+`/`*` |
| `a @ b` | `(mm a b)` | rides `inner` (the galaxy's `+.x` contraction) |
| `x.sum()`, `x.mean()` | `(sum x)`, `(mean x)` | `asum` + the count law (`tally`) |
| `relu`, `sigmoid`, `tanh` | `(relu x)`, `(sig x)`, `(tanh x)` | elementwise; relu IS the color law (below) |
| `loss.backward()` | `(back loss)` | the adjoint pass; fills every leaf's grad |
| `x.grad` | `(grad x)` | the accumulated cotangent |
| `nn.Linear(i,o)` | `(linear i o)` | a closure carrying weight+bias glasses |
| `nn.Sequential(..)` | `(seq f..)` | lens composition (it's just `<=<` over layers) |
| `optim.SGD(p, lr)` | `(sgd params lr)` | a stepper: `p ← p − lr·grad`, then zero grads |
| `optim.Adam` | `(adam params lr)` | later — moment tablets keyed by param mint |

The surface stays PyTorch-legible on purpose — the whole point is "a PyTorch
clone." The optics metaphor lives in the *mechanism* (lens / adjoint), not the API.

## Native tie-ins — tele is not bolted on

- **relu IS the color law.** ai's net wears a color: green nets positive, red nets
  negative, **blue is the floor at net exactly 0**. `relu(x) = max(0, x)` passes the
  green and clamps the red to the blue floor — it is `$`'s saturating clamp made
  smooth (`$` = `max(0, ceil(net))`; relu drops the ceil and goes elementwise). The
  kink is the blue floor; that is exactly where relu's subgradient switches. So
  tele's first activation is the net's own clamp, differentiated.
- **The performant op is a baked kernel, by the project's own law.** The perf law
  (`jit-trampoline-hhdm-rwx`): a fixed-code win ships as baked C unlocked by an
  algebraic law, and the galaxy reductions already live baked in
  `asum`/`aprod`/`amax`/`amin`. tele's hot transpose / reshape / axis-sum are the
  *next* baked kernels — but they are CORE asks, so the pure-ai loop version ships
  first (correct, slow) and the bake is a later, separate request.
- **Grad-check is the oracle, and it's self-validating** (the differential-oracle
  pattern). For any op, the analytic gradient must match the central finite
  difference `(f(x+ε) − f(x−ε)) / 2ε` within tolerance. No hand-written expected
  values — the math checks itself. That IS `test_tele`.

## The core asks — the fork in the road

Autograd needs a few galaxy moves the array surface doesn't expose yet. Each has a
**pure-ai fallback** (a `peep`/`pin`/`iota` loop — correct, O(n) interpreted) and a
**baked form** (a nif, the perf win). **Ship on the fallbacks; ask the core thread
for the bakes once correctness is proven** — exactly aineko's "(A) now, (B) later".

1. **sum-to-shape** `(sumto v shape)` — the un-broadcast primitive. Broadcasting
   backward must sum the cotangent over the axes that were stretched. This is THE
   one autograd can't cleanly fake; the pure-ai loop is the gnarliest. First bake ask.
2. **transpose / axis-permute** `(transp v perm)` — `mm` backward needs `Aᵀ`.
   `inner` only contracts last-axis-vs-first, so the backward grads need a permute
   to line axes up.
3. **reshape** `(reshape v shape)` — flatten/unflatten between layers. `arr` can
   build a shape from a flat list, so the fallback is cheap; a view-style nif is the bake.
4. **gather / slice** — for embedding/index ops. LATER (post-MLP); not on the
   critical path for the XOR/MLP demo.

Until those land as nifs, tele implements 1–3 as ai loops in `tele.l` and the demo
trains correctly, just slowly. **Do not block the build on a core ask** — land the
loop, prove the grad-check, then file the bake.

## Staged plan

- **Stage 1 — the autograd core.** `glass`/`const`, the lens ops
  `add`/`mul`/`mm`/`sum`, the reverse-topo `back`, `grad`. Gate: `test_tele`
  grad-checks every op (analytic vs central difference). ~1–2 sessions, pure ai.
  This is the keystone; everything else is leaves on it.
- **Stage 2 — activations + loss.** `relu` (the color-law clamp), `sig`, `tanh`,
  `mse`, `softmax`/`logsoftmax` + cross-entropy. Each grad-checked. The `sumto`
  fallback lands here (softmax needs axis ops). ~1 session.
- **Stage 3 — nn + optim.** `linear`, `seq`, parameter collection (walk the lens
  for leaves with grad), `sgd`/`adam` steppers, `zero` (clear grads). ~1 session.
- **Stage 4 — the demo.** `tele/xor.l`: a 2-layer MLP learns XOR, prints loss
  decreasing to ~0 and the four correct outputs. The "a neural net in ai" line for
  the README/paper. Then the **kship demo** — the same `.l` trained on bare metal
  (pure ai, no host nifs, so it Just Runs on the kernel image): the flagship
  "deep learning with no OS" story.
- **Stage 5 (post-release / with the core thread) — the bakes.** `sumto`/`transp`/
  `reshape` as nifs (the perf form), so a real-sized net trains at C speed, not
  interpreted-loop speed. Mirrors the galaxy-kernel wins already baked in `asum` et al.

## Risks

- **Broadcasting backward is the whole game.** Get `sumto` right (sum the cotangent
  back to the input's shape over every stretched axis, including size-1 axes) or
  every gradient through a broadcast is silently wrong. The grad-check catches it —
  trust the oracle, write the check first.
- **Accumulation, not assignment.** A node consumed twice must SUM its incoming
  cotangents (fan-out = chain-rule sum). The mint-keyed tape makes this a `+=` into
  the grad tablet; an `=` is the classic autograd bug.
- **Reverse topological order.** `back` must visit a node only after all its
  consumers. Record nodes in creation order (each op appends), walk that list in
  reverse — define-by-run gives a valid reverse-topo for free since a parent is
  always created before its child.
- **Float tolerance in grad-check.** The freestanding math lib is coarser than
  glibc (CLAUDE.md's note on transcendentals). Use a relative tolerance and central
  differences; don't pit a baked transcendental against a literal. Keep the check
  green on host AND kernel.
- **Keep it constellation-only / frontend-clean.** No host nif in `tele.l` (that
  would break the kship demo, the best story). If a core ask lands as a nif, it
  lands in the CORE, behind the galaxy surface — tele keeps calling `sumto`/`transp`
  the same whether they're ai loops or baked C.
</content>
