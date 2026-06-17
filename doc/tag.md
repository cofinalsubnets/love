# Pointer-tagging: `ap` is `cap`

A design study (NOT built) for a heap-object representation that drops the
`ap`/header word by encoding a value's *kind* in the low bits of every
reference to it. A documented alternative to the data-sentinel recovery scheme
(see `data.c` / `data.h`); the refined form of the "representation change" the
sorted-table backlog item flagged as rejected-by-default.

A runnable ai model lives in [`boot/tag.l`](../boot/tag.l) — fixnum bit-ops *are*
the word, a toy `heap` map stands in for raw memory.

## The idea

Today every heap object's word0 is its `ap` (the hot you tail-jump to), and its
address-as-laid-out (the `ai_data` section) or its sentinel encodes the kind.

Instead, encode the **kind in the low bits of every reference** that points at
the object. Then dispatch is a mask on the reference — no memory read — and the
object needs **no `ap`/header word**: a chain becomes `{cap, cup}` (2 words, was
3), and `word0` *is* `cap`. Recovery moves from "read a word / layout
arithmetic" to "mask the pointer."

## The low-bit budget

Three consumers compete for the low bits of a word:

- **immediate discriminator** — 1 bit (bit 0; `1` = fixnum with value in bits
  63:1, `0` = pointer). "A fixnum is a tagged odd word" already.
- **thread-GC tag** — +1 bit (bit 1). The GC owns bits[1:0] as a value tag:
  `00` = pointer, `01` = fixnum, `10` = threaded-link, `11` = spare.
- **data-kind tag** — N bits (8 data kinds want 3). It **must sit above the GC
  bits** — a kinded pointer must still read `00` in bits[1:0] or the collector
  misclassifies it. That single constraint sets the alignment.

## Alignment models (kind above the 2 GC bits)

| model | low bits | layout | kinds inline | verdict |
|---|---|---|---|---|
| 8-byte | 3 | `[1:0]`=GC, `[2]`=1 kind bit | 2 | can't fit 8 |
| **16-byte** | 4 | `[1:0]`=GC, `[3:2]`=2 kind bits | **4** + "other" escape | the one that pays on 64-bit |
| 32-byte | 5 | `[1:0]`=GC, `[4:2]`=3 kind bits | **8** (all data kinds) | bloats small objects → net loss |

The full 3-bit map (the 32-byte layout), with chain = 0 so a chain reference is
the raw aligned pointer:

```
000 KChain  {cap,cup}  2w   ← raw pointer, the hot path
001 KVec    header (type+shape+data)
010 KString header (len+bytes)
011 KMint   {name,serial} 2w
100 KBig    header (len+limbs)
101 KFlo    {bits}  1w
110 KWide   {bits}  1w
111 KCplx   {re,im} 2w
```

Dispatch is `(ref >> 2) & 7` → apply-matrix row. But this needs bit 4 → 32-byte
alignment, and a 2-word chain (16 B) rounded to 32 B wastes more than the 8 B
`ap` word it removed. For the hottest, smallest object the full scheme is a net
loss.

## Who actually benefits from `ap` = `cap`

Objects whose payload is exactly **2 words** fill a 16-byte slot with zero
padding while shedding the `ap`:

- **chain** `{cap, cup}` → tag `00`, raw pointer, 16 B exact.
- **complex** `{re, im}` → 16 B exact.

1-word payloads (**flo / wide** `{bits}`) do **not** win at 16-byte alignment —
the padding eats the word you saved — so they stay as lean 2-word boxes.

So the practical scheme is 16-byte alignment with a 2-bit kind:

```
bits[1:0]  GC/value tag : 00 ptr · 01 fixnum · 10 threaded · 11 spare
bits[3:2]  kind (ptr only): 00 chain · 01 complex · 10 reserved · 11 OTHER → read a header word
```

Chain and complex go header-less; everything else is `11` = OTHER and keeps a
dispatch word, recovered the way it is today.

## Thread-GC compatibility

Jonkers threading needs a slot to root the reversal chain — that was the `ap`
word. With `ap` = `cap` it **borrows** `word0` = `cap` as the thread head and
restores it to the forwarding address on the update walk (standard for threaded
compaction). The collector reads size/kind from the reference's tag, not from a
header — so header-less objects remain collectable.

## 32-bit / wasm

The key realization: **free low bits come from alignment, not word width.** A
16-aligned address has the same 4 low bits whether the pointer is 32 or 64 bits,
so the tag *ports to 32-bit unchanged.*

What breaks is **zero-waste**: a 2-word object is 16 B on 64-bit (fills the
slot) but 8 B on 32-bit — it rounds up to 16, a 100% pad, and the win inverts.

Two ways to keep 32-bit (and wasm32) presence:

1. **Gate the recovery only** (easy, localized). `ai_typ` is already a swappable
   `data.h` variant (section / table / mach-o / wasm); add a
   `#if __SIZEOF_POINTER__ == 8` tag-dispatch path, else the sorted-table
   fallback. This gates *only* kind-recovery — if you also adopt `ap` = `cap`,
   that's a uniform representation change, not gated. Gating alone keeps the
   `ap` word everywhere → keeps 32-bit presence trivially but forgoes the space
   win.

2. **Seamless** (better, costs a GC change). Cut the in-band GC tag to **one**
   bit (just `fixnum`) by moving forward/thread detection out of band — a
   to-space range test (`is word0 a pointer into to-space?`) or a side mark
   bitmap. Then put the kind in **bits[2:1] at 8-byte alignment**. A 2-word
   object is then a multiple of 8 on *both* targets → zero waste either way, the
   math identical (only `sizeof(word)` varies). Bonus: this retires the wasm
   code-address special case entirely — with `ap` = `cap` there are no sentinel
   *function* pointers to dispatch on, so "wasm has no flat code address space"
   stops mattering; the kind rides the data reference in linear memory.

**Rule: the representation is uniform — never `#ifdef` the object layout by word
size** (that forks every accessor and the GC into two models). Parametrize the
few constants (wordsize, alignment mask, kind shift) by `sizeof(void *)`; the
seamless 8-byte / 1-GC-bit design is exactly what makes one layout serve both.

## Verdict

The 16-byte / 2-bit / chain+complex scheme pays on 64-bit without touching the
GC's bit contract. The full 3-bit/8-kind version *and* the 32-bit-seamless
version both want the same prize: drop the second GC bit (range-based
forwarding).
