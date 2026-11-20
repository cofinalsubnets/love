// src/love/audio/tones.c -- the tones doors: voices as small graphs of operators (tones.h, run
// by tonerun.c) for harp's timbres, doom's FM instruments, the gamelan's chimes. love lays each
// voice's operators and decides their envelopes (src/apps/harp/ops.l); this hands them the frames.
// (tones ops st n f0 rate) -> a float tray: n frames of left, n of right, then each operator's
//   last two outputs (for its feedback, handed back next time as st; any other st, () say, is
//   all at rest), then scratch; with ws a workspace of (tones-ws k), k >= the operators times n,
//   the scratch is laid there and left out of the answer. ops is a float tray of rows of tn_row
//   numbers, as tones.h lays them. | () for a bad argument
#include "love.h"
#include "tones.h"

_Static_assert(sizeof(tn_flo) == sizeof(flo_t), "tones.h's float is love's");

// a workspace: a state holding its magic and k, then k floats a run lays its scratch in, kept
// from one run to the next so the scratch is not made again. a str's bytes are word aligned,
// all a flo_t needs, wherever the gc lays it
#define TW_MAGIC ((uintptr_t) 0x746f6e65)
struct tw_head { uintptr_t magic, k; };
static uintptr_t tw_floats(word x) {
 struct str const *s = state_str(x);
 struct tw_head const *h = s ? (struct tw_head const *) s->bytes : 0;
 return h && s->len >= sizeof *h && h->magic == TW_MAGIC && (s->len - sizeof *h) / sizeof(flo_t) >= h->k ? h->k : 0; }
static flo_t *tw_data(word x) { return (flo_t *) (state_str(x)->bytes + sizeof(struct tw_head)); }

// (tones-ws k): a workspace for k floats of scratch
love_noinline static struct g *host_tones_ws(struct g *g) {
 word *a = g->sp;
 if (!(a[0] & 1) || getcharm(a[0]) < 0 || getcharm(a[0]) > 1 << 24) { a[0] = ZeroPoint; return g; }
 uintptr_t const k = (uintptr_t) getcharm(a[0]), n = sizeof(struct tw_head) + k * sizeof(flo_t);
 union u *s = new_state(&g, n, sizeof(struct tw_head));
 if (!s) return g;
 struct tw_head *h = (struct tw_head *) ((struct state *) s)->str->bytes;
 h->magic = TW_MAGIC, h->k = k;
 g->sp[0] = word(s);
 return g; }
static lvm(lvm_tones_ws) { LvmCallp(g, 0, host_tones_ws) }

love_noinline static struct g *host_tones_(struct g *g) {
 word *a = g->sp;
 // (tones ops st n f0 rate ws)
 if (!galaxyp(a[0]) || tray(a[0])->type != love_R || !(a[2] & 1) || !isnum(a[3]) || !isnum(a[4])) { a[0] = ZeroPoint; return g; }
 intptr_t const n = getcharm(a[2]);
 uintptr_t const no = tray_nelem(tray(a[0])) / tn_row;
 if (n < 0 || n > 1 << 22 || no > 4096 || tray_nelem(tray(a[0])) % tn_row) { a[0] = ZeroPoint; return g; }
 int const inws = tw_floats(a[5]) >= no * (uintptr_t) n;
 uintptr_t const len = 2 * (uintptr_t) n + 2 * no + (inws ? 0 : no * (uintptr_t) n), w = b2w(tray_bytes(love_R, 1, len));
 if (!ok(g = have(g, w))) return g;
 a = g->sp;
 struct tray *out = ini_tray(bump(g, w), love_R, 1);
 out->shape[0] = len;
 // the workspace read after the allocation, which may move it
 flo_t *d = tray_data(out), *L = d, *R = d + n, *st = d + 2 * n, *sc = inws ? tw_data(a[5]) : st + 2 * no;
 for (uintptr_t i = 0; i < 2 * (uintptr_t) n; i++) d[i] = 0;
 flo_t const *ops = tray_data(tray(a[0])), rate = toflo(a[4]);
 int64_t const f0 = (int64_t) toflo(a[3]);
 if (rate <= 0) { a[0] = ZeroPoint; return g; }
 // the outputs carried in, read after the allocation, which may move them
 word const s0 = a[1];
 int const carried = galaxyp(s0) && tray(s0)->type == love_R && tray_nelem(tray(s0)) == 2 * no;
 for (uintptr_t j = 0; j < 2 * no; j++) st[j] = carried ? tray_get_flo(tray(s0), j) : 0;
 tones_run(ops, no, st, n, f0, rate, L, R, sc);
 a[0] = word(out);
 return g; }
#if TARGET_PLAYDATE
// the playdate trial's meter: microseconds in the kernel and the mix
extern unsigned pdg_us(void), love_m_tn, love_m_mx;
love_noinline static struct g *host_tones(struct g *g) { unsigned t = pdg_us(); g = host_tones_(g); love_m_tn += pdg_us() - t; return g; }
#else
#define host_tones host_tones_
#endif
static lvm(lvm_tones) { LvmCallp(g, 5, host_tones) }

// (mixall ps n): 2n frames, left then right, the sum of each piece [y gl gr o] of the list ps in
// order: y's frame o + i at i where it falls in y's first n, at gl and gr. a side whose gain
// is 0 is not touched; a piece that is not one is skipped
love_noinline static struct g *host_mixall_(struct g *g) {
 word *a = g->sp;
 if (!(a[1] & 1)) { a[0] = ZeroPoint; return g; }
 intptr_t const n = getcharm(a[1]);
 if (n < 0 || n > 1 << 22) { a[0] = ZeroPoint; return g; }
 uintptr_t const w = b2w(tray_bytes(love_R, 1, 2 * (uintptr_t) n));
 if (!ok(g = have(g, w))) return g;
 a = g->sp;
 struct tray *out = ini_tray(bump(g, w), love_R, 1);
 out->shape[0] = 2 * (uintptr_t) n;
 flo_t *L = tray_data(out), *R = L + n;
 for (intptr_t i = 0; i < 2 * n; i++) L[i] = 0;
 for (word p = a[0]; chainp(p); p = B(p)) {
  word q = A(p), y, gl, gr, o;
  if (!chainp(q) || !chainp(B(q)) || !chainp(BB(q)) || !chainp(B(BB(q)))) continue;
  y = A(q), gl = AB(q), gr = A(BB(q)), o = A(B(BB(q)));
  if (!galaxyp(y) || tray(y)->type != love_R || !isnum(gl) || !isnum(gr) || !(o & 1)) continue;
  intptr_t const off = getcharm(o);
  if (tray_nelem(tray(y)) < (uintptr_t) n || off <= -n || off >= n) continue;
  // the frames i whose off + i falls in y's first n
  intptr_t const i0 = off < 0 ? -off : 0, i1 = off > 0 ? n - off : n;
  flo_t const *ys = (flo_t const *) tray_data(tray(y)) + off, fl = toflo(gl), fr = toflo(gr);
  if (fl != 0) for (intptr_t i = i0; i < i1; i++) L[i] += ys[i] * fl;
  if (fr != 0) for (intptr_t i = i0; i < i1; i++) R[i] += ys[i] * fr; }
 a[0] = word(out);
 return g; }
#if TARGET_PLAYDATE
love_noinline static struct g *host_mixall(struct g *g) { unsigned t = pdg_us(); g = host_mixall_(g); love_m_mx += pdg_us() - t; return g; }
#else
#define host_mixall host_mixall_
#endif
static lvm(lvm_mixall) { LvmCallp(g, 1, host_mixall) }

LvDef("tones", tones, 6, "dsp");
LvDef("tones-ws", tones_ws, 1, "dsp");
LvDef("mixall", mixall, 2, "dsp");
