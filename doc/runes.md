# Rune cells: the terminal grows past the byte

Today a cb cell holds **one CP437 byte** (`quay.h:6-25`: char 8 | fg 8 | bg 8 |
font 4 | face 4, packed in a uint32), and `cb_putc` folds every incoming UTF-8
codepoint onto that page at **write time** (`quay.c:438-452` decode,
`quay.c:379-416` the ~230-entry fold table). The fold is lossy: anything off the
page is `■` forever, berth's re-emit is a reconstruction through `cb_unfold`, and
CJK is architecturally out — a cell can't even *name* a kanji, let alone occupy
two columns.

This study plans the move to **rune cells**: the codepoint itself lives in the
cell, the fold moves to paint time, and the wide-char metrics land on top. End
state: CJK displays in berth and pier, and typing it arrives through fcitx5 —
today in berth, and natively via haven's input-method rung.

**Design study — not yet built.** Staged so each rung leaves `make test` green
(the gates: `boot/cb.l` the vttest-lite, `boot/berth.l`, `boot/pier.l`,
`boot/font.l`).

## The packing

A rune is 21 bits; cb's whole pen is 24 (fg 8 + bg 8 + font 4 + face 4). So a
cell stays **one word**:

    rune 21 | fg 8 | bg 8 | font 4 | face 4 | wide 1 | dummy 1 | wrap 1  = 48 bits

- The grid stays a flat array, GC-transparent, `blitrow` stays one C loop per
  row. Memory doubles (uint32 → uint64) — a 80×24 grid is 15KB, nothing.
- Three new flag bits ride the spare space, *not* the face nibble: `wide` marks
  a double-width glyph, `dummy` its right-half placeholder, `wrap` marks a soft
  line break (st's ATTR_WRAP idea — selection snap and copy-with-correct-newlines
  all fall out of this one bit later, see the st appendix).
- The controls-never-stamp law holds: a cell holds 0 or a rune ≥ 32.
- **32-bit ports check**: a charm on a 32-bit target can't hold the packed cell.
  `glass` there either answers a full or splits rune/pen into two reads — decide
  when the playdate port is in hand, the C struct doesn't care.

## The fold moves to paint time

Storage becomes exact; lossiness becomes the *renderer's* honest boundary — the
model knows the truth, the font draws what it can.

- `cb_putc` keeps the UTF-8 decoder, drops the fold: the rune goes in the cell.
- **pier** folds in `blitrow`: rune → atlas glyph (the CP437 fold table survives
  here, as the render-side fallback for atlases that can't draw the rune → `■`).
- **berth** re-emits the stored rune as UTF-8 directly — **`cb_unfold` and the
  per-glyph cache die** (`berth.l:32-42`), and the round trip is lossless by
  construction. tmux borders stop being a fold trick and become the trivial case.
- kernel/playdate paint paths take the same fold-at-paint change; their grids
  are small enough that the wider cell is free.

## The ladder

**Rung 1 — rune cells + fold-at-paint.** The two sections above, one commit.
Gate: boot/cb.l feeds multi-byte UTF-8 and asserts the *rune* comes back from
`glass`; berth round-trips it byte-identical.

**Rung 2 — width metrics.** Two small pieces in quay.c:

- our own `wcwidth` — **not** st's (it leans on libc; cb is kernel-shared).
  The canonical zero-dep source is Markus Kuhn's `mk_wcwidth`: public domain,
  ~100 lines, a bsearch over ~50 double-width intervals plus the combining-char
  (width 0) table.
- the WIDE/WDUMMY dance, straight from st: a width-2 glyph wraps early if it
  won't fit the last column (st.c:2518), stamps `wide` + a `dummy` partner;
  st's `tsetchar` (st.c:1208) is the whole cleanup for overwriting half a glyph
  (killing either half clears the other's flag). Width-0 (combining) runes are
  swallowed for now — a bitmap grid has nowhere to put them.

**Rung 3 — berth speaks CJK. Done.** berth only needs to *skip dummy cells*
when emitting so columns align — the outer terminal draws the glyphs and, since
berth inherits the outer terminal's IME, **typing CJK already works here**
(fcitx5 section below). Probe: Japanese text in tmux inside berth. Rungs 1–3
are one sitting.

**Rung 4 — pier grows glyphs.** The 256-glyph CP437 atlas can't carry CJK; the
one right font is **GNU Unifont**: whole-BMP coverage, 8×16 halfwidth / 16×16
fullwidth — a wide glyph is *exactly two cells* of the existing geometry, so the
blit math barely changes. Unifont ships `.hex`, a text format whose loader is a
toy: `codepoint:rowbits` per line.

- `apps/quay/hex.l` beside psf.l — parse `.hex` into a sparse atlas: sorted
  rune table + glyph blob, bsearch at paint (the current atlas cask grows a
  variant with a rune index; the 256-glyph PSF page stays the fast lane 0).
- `blitrow`: a `wide` cell paints 16px across its own cell and the dummy's;
  `dummy` skips.
- All of BMP unifont is ~2MB in memory — nothing on host; the kernel keeps its
  256-glyph page and `■`s the rest.
- Gate: boot/font.l synthesizes a tiny `.hex` (no system fonts assumed, same
  discipline as the PSF gate); boot/pier.l GetImage-asserts a wide glyph painted
  across two cells.

## fcitx5: how typing CJK arrives

fcitx5 reaches applications through three doors, and each maps to one of our
frontends:

- **berth — works at rung 3, zero code.** berth runs inside an existing
  terminal; *that* terminal is fcitx5's client (via its toolkit IM module). The
  outer terminal draws the preedit, and the committed string arrives on berth's
  stdin as plain UTF-8 bytes, which flow down the pty like any other keys. This
  is the ASAP lane.
- **pier on X — XIM, and we decline.** A raw X client's only door is the XIM
  protocol (`XMODIFIERS=@im=fcitx`), a notoriously gnarly wire protocol over
  client messages + property transport. A minimal client (root-window preedit
  style: fcitx5 draws its own preedit window, we only receive commit strings)
  is *bounded* and would ride our existing X wire zero-dep — but it's a lot of
  protocol for one legacy frontend. **Parked unless pier-native input becomes
  the daily driver before haven does.**
- **haven — the real answer.** fcitx5 has first-class wayland support: the
  compositor implements `zwp_input_method_v2` (fcitx5 connects as the input
  method) and `zwp_text_input_v3` (surfaces declare focus + receive
  preedit/commit), and routes between them. That routing is exactly the wl_seat
  keyboard-focus rung already on haven's ladder — IME is the rung *after*
  wl_seat, not a separate project. Terminal surfaces then get commits as UTF-8
  down the pty; preedit paints as a frontend overlay at the cursor (never sent
  to the guest — terminals only forward commits).

So the sequence: rung 3 gives CJK typing in berth immediately; haven's
wl_seat → input-method-v2 rungs give it natively; pier-on-X never learns XIM
unless something forces it.

## Appendix: the st borrow list (beyond CJK)

st at `/home/gwen/src/st` (MIT/X license, st.c ~2700 lines) surveyed against cb
2026-07-05. cb already matches or beats it on: deferred autowrap, DECSTBM +
origin mode, BCE, the erase/edit/scroll CSI set, DSR/DA replies, per-row damage.
The gaps, ranked; the first group is one sitting, all gate-able in boot/cb.l:

- **`?1` DECCKM app cursor keys** — cb parses it away; pier always sends
  `\e[A` where full-screen apps expect `\eOA`. One flag bit + frontend key
  encoding (st's `kmap`, x.c:1804). The closest thing to a live bug.
- **`?2004` bracketed paste** — one mode bit; paste wraps in
  `\e[200~`…`\e[201~` (x.c:590).
- **real tab stops** — a `tabs` bitmap with HTS/TBC (`g`) and CHT/CBT
  (`I`/`Z`); cb hard-codes every-8.
- **REP (`b`)** — repeat last printable via a `lastc`. A few lines.
- **OSC 0/2 title** — pier applies it as the X window name.
- **content-preserving resize** — st's `tresize` (st.c:2568) slides rows to
  keep the cursor, rebuilds tabs, clears exposed cells; cb discards the grid
  and blank-flashes.
- **the anti-flood write dance** — `ttywriteraw` (st.c:871) writes ≤256 bytes
  per iteration and *services reads while writing* so the pty can't deadlock
  both directions; `gush` is one blocking full write today.
- **real alternate screen** — st pointer-swaps two line arrays
  (`tswapscreen`, st.c:1047) with per-screen saved cursors; cb's `?47/1047/1049`
  all alias one save-clear grid and `?1049` skips the cursor save.
- **mouse reporting `?1000/1002/1003/1006`** — `mousereport()` (x.c:365) is
  the compact encoding reference (SGR `\e[<c;x;yM/m`, wheel +64, modifiers
  +4/8/16, motion coalesced by cell). Mode bits in cb, encoder in pier; this is
  what makes tmux/vim mouse work.
- **OSC 52 clipboard** — st's table-driven `base64dec` (st.c:361) is 35 lines.
  Prerequisite: cb captures only ~5 OSC head bytes today; it needs an st-style
  growing string buffer (STREscape, st.c:146) — which also unlocks title and
  OSC 4 palette.
- **selection machinery** (when pier wants it) — `selsnap`/`selnormalize`/
  `selscroll` (st.c:511/467/1097) port nearly verbatim once the `wrap` bit from
  rung 1 exists.

Deliberately **not** borrowed: st's truecolor storage (our cell quantizes
38;2 to the 6×6×6 cube — keeping 24-bit would burn 27 more bits per cell for
little); st's Xft/fontconfig rendering (pier's blit + PSF/hex atlases beat it
for zero deps); scrollback (st doesn't have it either).
