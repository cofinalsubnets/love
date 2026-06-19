# Note: the crew as faces of `top`

A categorical reading of how the apps relate to the core (user's framing, 2026-06-19).
Specification / lore organizing principle — not an internal change.

**`top` = the language itself.** It is the top of its own lattice: everything applies,
every value has a kind, and "is-it-top" is vacuous (you may as well ask `0`). So the core is
a single universal object, and the crew are **faces** of it — each a way the core meets a
boundary. The *outward* faces come in **dual pairs**, glued each by *its own* universal shape
(there is no uniform functor — "they associate by their own preferences"); the *inward* face,
at ai's own limit, stands alone.

**Source faces — `read` / `feel` — COMPOSE.** The two legs of `charms → top`:
- `read : charms → forms` (the reader — already the surface primitive; parse the chars).
- `feel : forms → top` (the weaver / the `wev` source pre-pass — sense what is static, fold it).
- The charm face reaches `top` by **composing through** the feel face: `feel ∘ read`. (The stream
  shell `zev` is exactly this — its body is `read` then `ev`, and `ev` is `opfix · feel · ana · cata`.)
  So **the charm face composes through the lisp face** — the paper's "two input lanes, data and
  characters, meet at one core": `charms ─read→ forms ─feel→ top`, the cospan `charms → top ← forms`
  converging on the core.

**World faces — `bao` / `aineko` — COPRODUCT.** They do not compose; one shared i/o trunk
**forks**: `bao` (the local face — the console, the shell/bridge) and `aineko` (the net face —
the wire). `local ⊔ aineko` — either/or off the trunk, not a pipeline.

**Help face — `gwen` — the third boundary, INWARD.** source and world are *outward* — how ai meets
what's outside it. `gwen` faces ai's own **help**: the boundary where the core *raises* because it
cannot answer, and calls out. It is the **dual of the honest face** ([[honest-face]]): when help is
missing the honest face shows the bare condition; **gwen is help PRESENT** — the answer that absence
was missing. The runtime `help` handles conditions in a *program*; gwen handles them in the *language*
— probes the binary, finds the drift, keeps the words matched to the work. (That is why it is the
**author's** face: when the language itself has no answer, the human is the help of last resort.)

**Around the faces:** `tele` the **mind** (the `decide`, the telescope reading the constellations);
`kship` the **body/substrate** it sails; `cook` and `mow` the **keepers** (build the ship; tend the
heap green — the two-space gardener).

So: one object (`top` = ai, the language), three boundaries — **source** (read/feel, *compose*),
**world** (bao/aineko, *coproduct*), **help** (gwen, the inward dual of the honest face). Two gluings
for the outward pairs, one inward face for the limit. Reflected in `content/lore.md` (lore voice)
and `blue.md §12` (formal aside). Relates: [[serialize]] (the limit/colimit note over the mint-NNO).

## Rocq demo (proposed — "a great demo," user 2026-06-19)

Axiom-free, ~25 lines, a new `Section Faces` in `rocq/spec.v` (gated by `test_proof`/coqc).
Honest register: the **composition** half is *definitional* (`source := feel ∘ read` → `reflexivity`);
the **coproduct** half is the one real (standard) universal-property proof; uniqueness stated
**pointwise** to stay axiom-free (no funext). The value is pinning the faces structure formally —
the note machine-checked, the two gluings shown side by side.

```coq
Section Faces.
  Variables Top Charm Form : Type.
  (* SOURCE faces compose: the charm face runs THROUGH the feel face *)
  Variable read : Charm -> Form.            (* the read face: charms -> forms *)
  Variable feel : Form  -> Top.             (* the feel face: forms -> top (the weaver) *)
  Definition source (c : Charm) : Top := feel (read c).
  Theorem source_factors : forall c, source c = feel (read c).
  Proof. reflexivity. Qed.                  (* charms → forms → top, converging on the core *)

  (* WORLD faces coproduct: one trunk forks, local ⊔ net; the UP, pointwise-unique *)
  Variables Local Net Out : Type.
  Variable bao    : Local -> Out.
  Variable aineko : Net   -> Out.
  Definition fork (x : Local + Net) : Out :=
    match x with inl l => bao l | inr n => aineko n end.
  Theorem world_inl : forall l, fork (inl l) = bao l.    Proof. reflexivity. Qed.
  Theorem world_inr : forall n, fork (inr n) = aineko n. Proof. reflexivity. Qed.
  Theorem world_unique :                                  (* any mediating h agrees with fork *)
    forall h : Local + Net -> Out,
      (forall l, h (inl l) = bao l) -> (forall n, h (inr n) = aineko n) ->
      forall x, h x = fork x.
  Proof. intros h Hl Hr x. destruct x; [apply Hl | apply Hr]. Qed.
End Faces.
```

Optional flourish: `top_vacuous` — "everything is top." (Gotcha when landing: `I` is shadowed in
spec.v by the imaginary unit `I : Zi`, so prove `True` via `constructor`, not the `I` ctor.)

**LANDED 2026-06-19** — `Section Faces` in `rocq/spec.v`, axiom-free, gated by coqc: `source_factors`
(reflexivity), `world_inl`/`world_inr`, `world_unique` (coproduct UP, pointwise), `top_vacuous`. The
axiom audit runs `Print Assumptions world_unique` / `source_factors` → both "Closed under the global
context." `blue.md §12` points here for the fuller reading.

## The hourglass reading (what the proof says)

Read the three theorems together and `top` is the **waist of an hourglass**:

1. **One center, nothing escapes it.** `top_vacuous`: *everything is top* — the language is the
   universal object; the faces are faces *of everything*.
2. **The world funnels IN by composition.** `source_factors`: `source = feel ∘ read`, proved by
   **`reflexivity`** — the convergence is not a discovered fact but *how the thing is built*. The
   charm face is a stage bolted in front of the lisp face; text → forms → top, many representations
   collapsing inward toward one core, by construction.
3. **The core fans OUT by coproduct.** `world_unique`: the fork off the i/o trunk is the **unique**
   mediating map — the local/net split is not arbitrary but *forced*; output branches, and the
   branching is determined.

So: source pours *in* through composed faces (a cone converging on the core — definitional); the
core pours *out* through co-producted faces (a cocone diverging from it — proven unique). **Input is
a limit (convergence, composition); output is a colimit (divergence, coproduct).** And it is the
*same duality* as [[serialize]]'s note — the numeric tower a **limit** (completion, converging), the
string monoid a **colimit** (free, diverging), meeting at the mint-NNO. The architecture and the type
theory rhyme: things converge inward by limits and composition, diverge outward by colimits and
coproducts, with a center between. The reader-into-weaver and the bao/aineko fork are that one shape,
wearing work clothes.
