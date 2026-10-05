// src/love/lib/vorbis.c -- vorbis i audio (xiph's spec), decoded.
// (vorbis-size id setup)  -> the bytes a decoder's state needs for these headers (the
//                            identification and setup packets), a charm | -why
// (vorbis-init b id setup) -> 0, b (a cask that size) laid as the decoder | why
// (vorbis-packet b p f)   -> one audio packet's samples, interleaved in wav's channel order,
//                            s16le (f 0) or f32le (f 1): "" for the first packet, which only
//                            primes the overlap | why
// why: 1 not this kind of packet, 2 cut short, 3 a kind this can't read (floor 0), 4 a bad
// stream. the setup's codebooks, floors and the rest are laid in the cask by offsets, so it may
// move between calls. doubles throughout and no libm: the cosines are a series, so every
// build decodes the same samples. the floor's inverse-db table is the spec's.
#include "love.h"
#include <stdint.h>
#include <string.h>

static float const vb_idb[256] = {
 1.0649863e-07, 1.1341951e-07, 1.2079015e-07, 1.2863978e-07, 1.3699951e-07, 1.4590251e-07,
 1.5538408e-07, 1.6548181e-07, 1.7623575e-07, 1.8768855e-07, 1.9988561e-07, 2.1287530e-07,
 2.2670913e-07, 2.4144197e-07, 2.5713223e-07, 2.7384213e-07, 2.9163793e-07, 3.1059021e-07,
 3.3077411e-07, 3.5226968e-07, 3.7516214e-07, 3.9954229e-07, 4.2550680e-07, 4.5315863e-07,
 4.8260743e-07, 5.1396998e-07, 5.4737065e-07, 5.8294187e-07, 6.2082472e-07, 6.6116941e-07,
 7.0413592e-07, 7.4989464e-07, 7.9862701e-07, 8.5052630e-07, 9.0579828e-07, 9.6466216e-07,
 1.0273513e-06, 1.0941144e-06, 1.1652161e-06, 1.2409384e-06, 1.3215816e-06, 1.4074654e-06,
 1.4989305e-06, 1.5963394e-06, 1.7000785e-06, 1.8105592e-06, 1.9282195e-06, 2.0535261e-06,
 2.1869758e-06, 2.3290978e-06, 2.4804557e-06, 2.6416497e-06, 2.8133190e-06, 2.9961443e-06,
 3.1908506e-06, 3.3982101e-06, 3.6190449e-06, 3.8542308e-06, 4.1047004e-06, 4.3714470e-06,
 4.6555282e-06, 4.9580707e-06, 5.2802740e-06, 5.6234160e-06, 5.9888572e-06, 6.3780469e-06,
 6.7925283e-06, 7.2339451e-06, 7.7040476e-06, 8.2047000e-06, 8.7378876e-06, 9.3057248e-06,
 9.9104632e-06, 1.0554501e-05, 1.1240392e-05, 1.1970856e-05, 1.2748789e-05, 1.3577278e-05,
 1.4459606e-05, 1.5399272e-05, 1.6400004e-05, 1.7465768e-05, 1.8600792e-05, 1.9809576e-05,
 2.1096914e-05, 2.2467911e-05, 2.3928002e-05, 2.5482978e-05, 2.7139006e-05, 2.8902651e-05,
 3.0780908e-05, 3.2781225e-05, 3.4911534e-05, 3.7180282e-05, 3.9596466e-05, 4.2169667e-05,
 4.4910090e-05, 4.7828601e-05, 5.0936773e-05, 5.4246931e-05, 5.7772202e-05, 6.1526565e-05,
 6.5524908e-05, 6.9783085e-05, 7.4317983e-05, 7.9147585e-05, 8.4291040e-05, 8.9768747e-05,
 9.5602426e-05, 0.00010181521, 0.00010843174, 0.00011547824, 0.00012298267, 0.00013097477,
 0.00013948625, 0.00014855085, 0.00015820453, 0.00016848555, 0.00017943469, 0.00019109536,
 0.00020351382, 0.00021673929, 0.00023082423, 0.00024582449, 0.00026179955, 0.00027881276,
 0.00029693158, 0.00031622787, 0.00033677814, 0.00035866388, 0.00038197188, 0.00040679456,
 0.00043323036, 0.00046138411, 0.00049136745, 0.00052329927, 0.00055730621, 0.00059352311,
 0.00063209358, 0.00067317058, 0.00071691700, 0.00076350630, 0.00081312324, 0.00086596457,
 0.00092223983, 0.00098217216, 0.0010459992, 0.0011139742, 0.0011863665, 0.0012634633,
 0.0013455702, 0.0014330129, 0.0015261382, 0.0016253153, 0.0017309374, 0.0018434235,
 0.0019632195, 0.0020908006, 0.0022266726, 0.0023713743, 0.0025254795, 0.0026895994,
 0.0028643847, 0.0030505286, 0.0032487691, 0.0034598925, 0.0036847358, 0.0039241906,
 0.0041792066, 0.0044507950, 0.0047400328, 0.0050480668, 0.0053761186, 0.0057254891,
 0.0060975636, 0.0064938176, 0.0069158225, 0.0073652516, 0.0078438871, 0.0083536271,
 0.0088964928, 0.009474637, 0.010090352, 0.010746080, 0.011444421, 0.012188144,
 0.012980198, 0.013823725, 0.014722068, 0.015678791, 0.016697687, 0.017782797,
 0.018938423, 0.020169149, 0.021479854, 0.022875735, 0.024362330, 0.025945531,
 0.027631618, 0.029427276, 0.031339626, 0.033376252, 0.035545228, 0.037855157,
 0.040315199, 0.042935108, 0.045725273, 0.048696758, 0.051861348, 0.055231591,
 0.058820850, 0.062643361, 0.066714279, 0.071049749, 0.075666962, 0.080584227,
 0.085821044, 0.091398179, 0.097337747, 0.10366330, 0.11039993, 0.11757434,
 0.12521498, 0.13335215, 0.14201813, 0.15124727, 0.16107617, 0.17154380,
 0.18269168, 0.19456402, 0.20720788, 0.22067342, 0.23501402, 0.25028656,
 0.26655159, 0.28387361, 0.30232132, 0.32196786, 0.34289114, 0.36517414,
 0.38890521, 0.41417847, 0.44109412, 0.46975890, 0.50028648, 0.53279791,
 0.56742212, 0.60429640, 0.64356699, 0.68538959, 0.72993007, 0.77736504,
 0.82788260, 0.88168307, 0.9389798, 1.0};

// --- the arena: everything the setup header asks for, laid in one block by offsets so the
// block may move between calls. a first pass with no block only counts
struct va { uint8_t *b; uint32_t used, cap; int bad; };
static uint32_t va_get(struct va *a, uint32_t n) {
 uint32_t o = (a->used + 7u) & ~7u;
 if (n > 0x7fffffffu - o) { a->bad = 1; return 0; }
 a->used = o + n;
 if (a->b && a->used > a->cap) { a->bad = 1; return 0; }
 if (a->b) memset(a->b + o, 0, n);
 return o; }
#define AT(T, o) ((T*) (base + (o)))

// lsb-first bits over a packet; past its end every read is 0 and eop is set
struct vbit { const uint8_t *s; uint32_t n, p; int eop; };
static uint32_t vb_get(struct vbit *b, int w) {
 uint32_t v = 0;
 for (int i = 0; i < w; i++, b->p++) {
  if (b->p >= 8 * b->n) { b->eop = 1; continue; }
  v |= (uint32_t) (b->s[b->p >> 3] >> (b->p & 7) & 1) << i; }
 return v; }
static int vb_ilog(uint32_t v) { int n = 0; while (v) n++, v >>= 1; return n; }

// 2^e laid as bits; the series below for sin and cos, so no libm and every build agrees
static double vb_p2(int e) {
 union { double d; uint64_t u; } x;
 if (e < -1022) return 0;
 if (e > 1023) e = 1023;
 x.u = (uint64_t) (e + 1023) << 52;
 return x.d; }
static double vb_sinr(double x) {             // |x| <= pi/4
 double t = x, s = x, x2 = x * x;
 for (int k = 1; k < 12; k++) t *= -x2 / ((2 * k) * (2 * k + 1)), s += t;
 return s; }
static double vb_cosr(double x) {
 double t = 1, s = 1, x2 = x * x;
 for (int k = 1; k < 12; k++) t *= -x2 / ((2 * k - 1) * (2 * k)), s += t;
 return s; }
#define VB_PI 3.14159265358979323846
// sin and cos of 2 pi num / den, reduced by octants exactly
static void vb_sc(long long num, long long den, double *s, double *c) {
 long long q = ((num % den) + den) % den;     // 0 .. den-1 of a turn
 long long o = q * 8 / den;                   // the octant
 double r = (double) (q * 8 - o * den) / (double) den * (VB_PI / 4);  // within it
 double a = vb_sinr(r), b = vb_cosr(r), ra = vb_sinr(VB_PI / 4 - r), rb = vb_cosr(VB_PI / 4 - r), sv, cv;
 switch (o) {
  case 0: sv = a, cv = b; break;
  case 1: sv = rb, cv = ra; break;
  case 2: sv = b, cv = -a; break;
  case 3: sv = ra, cv = -rb; break;
  case 4: sv = -a, cv = -b; break;
  case 5: sv = -rb, cv = -ra; break;
  case 6: sv = -b, cv = a; break;
  default: sv = -ra, cv = rb; }
 *s = sv, *c = cv; }

// vorbis's float32: 21 bits of mantissa, a 10-bit exponent biased by 788
static double vb_f32(uint32_t x) {
 double m = (double) (x & 0x1fffff) * vb_p2((int) ((x & 0x7fe00000) >> 21) - 788);
 return x & 0x80000000u ? -m : m; }

struct vcb {                  // a codebook
 uint32_t dims, entries, tree, vq;   // tree: int32 pairs, >= 0 a node, < 0 ~entry; vq: dims doubles an entry
 int lookup; };
struct vfl {                  // a floor 1
 int parts, mult, values, cls[31], cdim[16], csub[16], cbook[16], sbook[16][8];
 int x[65], ord[65], lo[65], hi[65]; };
struct vres { int type, nclass, classbook; uint32_t begin, end, psize; int books[64][8]; };
struct vmap { int submaps, steps, mag[256], ang[256], mux[256], fl[16], res[16]; };
struct vmode { int block, map; };
struct vh {                   // the head of the arena
 int ch, rate, bs[2], ncb, nfl, nres, nmap, nmode;
 uint32_t cb, fl, res, map, mode;
 uint32_t win[2], pre[2], post[2], tw[2], rev[2];   // per block size: window, dct-iv and fft tables
 uint32_t prev, cur, fbuf, cls, zr, out;            // decode room
 int pn, primed; };

// --- the setup -----------------------------------------------------------
// codewords as the spec assigns them: each entry takes the leftmost free leaf at its length.
// avail[d] is the free leaf at depth d, msb-aligned; the tree is int32 pairs, a child >= 0 a
// node, < 0 ~entry, 0x7fffffff none
static int vb_tree(int32_t *t, const uint8_t *len, uint32_t n, uint32_t room) {
 uint32_t avail[33] = {0}, nodes = 1;
 int first = 1;
 t[0] = t[1] = 0x7fffffff;
 for (uint32_t e = 0; e < n; e++) {
  int z = len[e], i;
  uint32_t code;
  if (!z) continue;
  if (first) {
   code = 0, first = 0;
   for (i = 1; i <= z; i++) avail[i] = 1u << (32 - i); }
  else {
   for (i = z; i > 0 && !avail[i]; i--) ;
   if (!i) return -1;                          // overspecified
   code = avail[i], avail[i] = 0;
   for (int y = z; y > i; y--) avail[y] = code + (1u << (32 - y)); }
  uint32_t node = 0;
  for (int d = 0; d < z; d++) {
   int k = (int) (code >> (31 - d) & 1);
   int32_t *c = &t[2 * node + k];
   if (d == z - 1) { if (*c != 0x7fffffff) return -1; *c = ~(int32_t) e; break; }
   if (*c == 0x7fffffff) {
    if (nodes >= room) return -1;
    *c = (int32_t) nodes, t[2 * nodes] = t[2 * nodes + 1] = 0x7fffffff, nodes++; }
   else if (*c < 0) return -1;
   node = (uint32_t) *c; } }
 return 0; }

// the largest r with r^dims <= entries
static uint32_t vb_l1(uint32_t entries, uint32_t dims) {
 uint32_t r = 0;
 for (;;) {
  uint64_t p = 1;
  for (uint32_t i = 0; i < dims && p <= entries; i++) p *= r + 1;
  if (p > entries) return r;
  r++; } }

static int vb_codebook(struct va *a, struct vbit *b, struct vcb *c, uint8_t *lenroom) {
 if (vb_get(b, 24) != 0x564342) return 4;
 c->dims = vb_get(b, 16), c->entries = vb_get(b, 24);
 if (!c->dims || !c->entries || c->entries > (1u << 20)) return 3;
 uint8_t *len = lenroom;                       // the lengths, laid on the arena's spare room
 uint32_t lo = va_get(a, c->entries);
 if (a->b) len = a->b + lo;
 if (!vb_get(b, 1)) {
  int sparse = (int) vb_get(b, 1);
  for (uint32_t e = 0; e < c->entries; e++) {
   uint8_t l = !sparse || vb_get(b, 1) ? (uint8_t) (vb_get(b, 5) + 1) : 0;
   if (a->b) len[e] = l; } }
 else {
  uint32_t e = 0, cur = vb_get(b, 5) + 1;
  while (e < c->entries) {
   uint32_t k = vb_get(b, vb_ilog(c->entries - e));
   if (cur > 32 || k > c->entries - e) return 4;
   if (a->b) for (uint32_t i = 0; i < k; i++) len[e + i] = (uint8_t) cur;
   e += k, cur++; } }
 c->tree = va_get(a, 8 * (c->entries + 1));
 if (a->b && !a->bad && vb_tree((int32_t*) (a->b + c->tree), len, c->entries, c->entries + 1) < 0) return 4;
 c->lookup = (int) vb_get(b, 4);
 if (c->lookup == 1 || c->lookup == 2) {
  double mn = vb_f32(vb_get(b, 32)), dl = vb_f32(vb_get(b, 32));
  int vbits = (int) vb_get(b, 4) + 1, seq = (int) vb_get(b, 1);
  uint32_t nv = c->lookup == 1 ? vb_l1(c->entries, c->dims) : c->entries * c->dims;
  if ((uint64_t) c->entries * c->dims > (1u << 22)) return 3;
  uint32_t mo = va_get(a, 4 * nv);
  for (uint32_t i = 0; i < nv; i++) { uint32_t v = vb_get(b, vbits); if (a->b) ((uint32_t*) (a->b + mo))[i] = v; }
  c->vq = va_get(a, 8 * c->entries * c->dims);
  if (a->b && !a->bad) {
   const uint32_t *mu = (const uint32_t*) (a->b + mo);
   double *vq = (double*) (a->b + c->vq);
   for (uint32_t e = 0; e < c->entries; e++) {
    double last = 0; uint32_t div = 1;
    for (uint32_t i = 0; i < c->dims; i++) {
     uint32_t off = c->lookup == 1 ? e / div % nv : e * c->dims + i;
     double v = mu[off] * dl + mn + last;
     vq[e * c->dims + i] = v;
     if (seq) last = v;
     div *= nv; } } } }
 else if (c->lookup) return 3;
 return b->eop ? 2 : 0; }

static int vb_floor(struct vbit *b, struct vfl *f) {
 if (vb_get(b, 16) != 1) return 3;            // floor 0 is not read here
 int maxc = -1;
 memset(f, 0, sizeof *f);
 for (int c = 0; c < 16; c++) f->cbook[c] = -1;
 f->parts = (int) vb_get(b, 5);
 for (int i = 0; i < f->parts; i++) { f->cls[i] = (int) vb_get(b, 4); if (f->cls[i] > maxc) maxc = f->cls[i]; }
 for (int c = 0; c <= maxc; c++) {
  f->cdim[c] = (int) vb_get(b, 3) + 1, f->csub[c] = (int) vb_get(b, 2);
  f->cbook[c] = f->csub[c] ? (int) vb_get(b, 8) : -1;
  for (int k = 0; k < (1 << f->csub[c]); k++) f->sbook[c][k] = (int) vb_get(b, 8) - 1; }
 f->mult = (int) vb_get(b, 2) + 1;
 int rb = (int) vb_get(b, 4);
 f->x[0] = 0, f->x[1] = 1 << rb, f->values = 2;
 for (int i = 0; i < f->parts; i++)
  for (int j = 0; j < f->cdim[f->cls[i]]; j++) {
   if (f->values >= 65) return 4;
   f->x[f->values++] = (int) vb_get(b, rb); }
 // the order by x, and each point's neighbours among the ones before it
 for (int i = 0; i < f->values; i++) f->ord[i] = i;
 for (int i = 1; i < f->values; i++)
  for (int j = i; j > 0 && f->x[f->ord[j - 1]] > f->x[f->ord[j]]; j--) { int t = f->ord[j]; f->ord[j] = f->ord[j - 1], f->ord[j - 1] = t; }
 for (int i = 2; i < f->values; i++) {
  int lo = 0, hi = 1;
  for (int j = 0; j < i; j++) {
   if (f->x[j] < f->x[i] && f->x[j] > f->x[lo]) lo = j;
   if (f->x[j] > f->x[i] && f->x[j] < f->x[hi]) hi = j; }
  f->lo[i] = lo, f->hi[i] = hi; }
 return b->eop ? 2 : 0; }

static int vb_residue(struct vbit *b, struct vres *r, int ncb) {
 r->type = (int) vb_get(b, 16);
 if (r->type > 2) return 3;
 r->begin = vb_get(b, 24), r->end = vb_get(b, 24), r->psize = vb_get(b, 24) + 1;
 r->nclass = (int) vb_get(b, 6) + 1, r->classbook = (int) vb_get(b, 8);
 if (r->classbook >= ncb) return 4;
 int casc[64];
 for (int i = 0; i < r->nclass; i++) {
  int lo = (int) vb_get(b, 3), hi = vb_get(b, 1) ? (int) vb_get(b, 5) : 0;
  casc[i] = hi * 8 + lo; }
 for (int i = 0; i < r->nclass; i++)
  for (int j = 0; j < 8; j++) {
   r->books[i][j] = casc[i] >> j & 1 ? (int) vb_get(b, 8) : -1;
   if (r->books[i][j] >= ncb) return 4; }
 return b->eop ? 2 : 0; }

// the dct-iv tables for an imdct of n: pre and post twiddles, the fft's, its bit reversal,
// and the window's rising half
static void vb_tables(struct va *a, struct vh *h, int k) {
 int n = h->bs[k], m = n / 2, q = m / 2;
 h->win[k] = va_get(a, 8 * (uint32_t) m);
 h->pre[k] = va_get(a, 16 * (uint32_t) q), h->post[k] = va_get(a, 16 * (uint32_t) q);
 h->tw[k] = va_get(a, 16 * (uint32_t) q), h->rev[k] = va_get(a, 4 * (uint32_t) q);
 if (!a->b || a->bad) return;
 uint8_t *base = a->b;
 double *w = AT(double, h->win[k]), *pr = AT(double, h->pre[k]), *po = AT(double, h->post[k]), *tw = AT(double, h->tw[k]);
 uint32_t *rv = AT(uint32_t, h->rev[k]);
 for (int i = 0; i < m; i++) {                 // sin(pi/2 sin^2((i + 1/2)/m pi/2))
  double s, c, s2, c2;
  vb_sc(2 * i + 1, 8 * m, &s, &c);
  double t = s * s;                            // sin^2 in [0, 1]: pi/2 t as a fraction of a turn
  // sin(pi/2 t) by the series directly, |pi/2 t| <= pi/2: split at pi/4
  double r = VB_PI / 2 * t;
  if (r <= VB_PI / 4) s2 = vb_sinr(r); else s2 = vb_cosr(VB_PI / 2 - r);
  (void) c2;
  w[i] = s2; }
 for (int i = 0; i < q; i++) {                 // exp(-i pi (i + 1/4) / m) and exp(-i pi i / m)
  double s, c;
  vb_sc(-(4 * i + 1), 8 * m, &s, &c), pr[2 * i] = c, pr[2 * i + 1] = s;
  vb_sc(-i, 2 * m, &s, &c), po[2 * i] = c, po[2 * i + 1] = s;
  vb_sc(-i, q, &s, &c), tw[2 * i] = c, tw[2 * i + 1] = s; }
 int bits = vb_ilog((uint32_t) q) - 1;
 for (int i = 0; i < q; i++) {
  uint32_t r = 0;
  for (int j = 0; j < bits; j++) r |= (uint32_t) (i >> j & 1) << (bits - 1 - j);
  rv[i] = r; } }

// the headers: identification, then setup -> 0 | why; a first pass with no block counts
static int vb_setup(struct va *a, const uint8_t *id, uint32_t idn, const uint8_t *su, uint32_t sun) {
 uint32_t ho = va_get(a, sizeof(struct vh));
 struct vh hc, *h = a->b ? (struct vh*) (a->b + ho) : &hc;
 memset(&hc, 0, sizeof hc);
 if (idn < 30 || id[0] != 1 || memcmp(id + 1, "vorbis", 6)) return 1;
 h->ch = id[11], h->rate = (int) (id[12] | id[13] << 8 | id[14] << 16 | (uint32_t) id[15] << 24);
 h->bs[0] = 1 << (id[28] & 15), h->bs[1] = 1 << (id[28] >> 4);
 if (id[7] | id[8] | id[9] | id[10] || !h->ch || !h->rate || h->bs[0] < 64 || h->bs[1] > 8192 || h->bs[0] > h->bs[1]) return 3;
 if (sun < 7 || su[0] != 5 || memcmp(su + 1, "vorbis", 6)) return 1;
 struct vbit b = {su + 7, sun - 7, 0, 0};
 h->ncb = (int) vb_get(&b, 8) + 1;
 h->cb = va_get(a, sizeof(struct vcb) * (uint32_t) h->ncb);
 for (int i = 0; i < h->ncb; i++) {
  struct vcb cc, *c = a->b ? (struct vcb*) (a->b + h->cb) + i : &cc;
  int r = vb_codebook(a, &b, c, NULL);
  if (r) return r;
  if (a->bad) return 3;
  if (a->b) h = (struct vh*) (a->b + ho); }
 int nt = (int) vb_get(&b, 6) + 1;
 for (int i = 0; i < nt; i++) if (vb_get(&b, 16)) return 4;
 h->nfl = (int) vb_get(&b, 6) + 1, h->fl = va_get(a, sizeof(struct vfl) * (uint32_t) h->nfl);
 for (int i = 0; i < h->nfl; i++) {
  struct vfl fc, *f = a->b ? (struct vfl*) (a->b + h->fl) + i : &fc;
  int r = vb_floor(&b, f);
  if (r) return r;
  for (int c = 0; c < 16; c++) if (f->cbook[c] >= h->ncb) return 4; }
 h->nres = (int) vb_get(&b, 6) + 1, h->res = va_get(a, sizeof(struct vres) * (uint32_t) h->nres);
 for (int i = 0; i < h->nres; i++) {
  struct vres rc, *r = a->b ? (struct vres*) (a->b + h->res) + i : &rc;
  int e = vb_residue(&b, r, h->ncb);
  if (e) return e; }
 h->nmap = (int) vb_get(&b, 6) + 1, h->map = va_get(a, sizeof(struct vmap) * (uint32_t) h->nmap);
 for (int i = 0; i < h->nmap; i++) {
  struct vmap mc, *m = a->b ? (struct vmap*) (a->b + h->map) + i : &mc;
  if (vb_get(&b, 16)) return 3;
  m->submaps = vb_get(&b, 1) ? (int) vb_get(&b, 4) + 1 : 1;
  m->steps = vb_get(&b, 1) ? (int) vb_get(&b, 8) + 1 : 0;
  int cb = vb_ilog((uint32_t) h->ch - 1);
  for (int s = 0; s < m->steps; s++) {
   m->mag[s] = (int) vb_get(&b, cb), m->ang[s] = (int) vb_get(&b, cb);
   if (m->mag[s] == m->ang[s] || m->mag[s] >= h->ch || m->ang[s] >= h->ch) return 4; }
  if (vb_get(&b, 2)) return 4;
  for (int c = 0; c < h->ch; c++) {
   m->mux[c] = m->submaps > 1 ? (int) vb_get(&b, 4) : 0;
   if (m->mux[c] >= m->submaps) return 4; }
  for (int s = 0; s < m->submaps; s++) {
   vb_get(&b, 8);
   m->fl[s] = (int) vb_get(&b, 8), m->res[s] = (int) vb_get(&b, 8);
   if (m->fl[s] >= h->nfl || m->res[s] >= h->nres) return 4; } }
 h->nmode = (int) vb_get(&b, 6) + 1, h->mode = va_get(a, sizeof(struct vmode) * (uint32_t) h->nmode);
 for (int i = 0; i < h->nmode; i++) {
  struct vmode mc, *m = a->b ? (struct vmode*) (a->b + h->mode) + i : &mc;
  m->block = (int) vb_get(&b, 1);
  if (vb_get(&b, 16) || vb_get(&b, 16)) return 4;
  m->map = (int) vb_get(&b, 8);
  if (m->map >= h->nmap) return 4; }
 if (!vb_get(&b, 1) || b.eop) return 4;
 vb_tables(a, h, 0), vb_tables(a, h, 1);
 if (a->b) h = (struct vh*) (a->b + ho);
 uint32_t hn = (uint32_t) h->bs[1] / 2, ch = (uint32_t) h->ch;
 h->prev = va_get(a, 8 * ch * hn);            // the last block's windowed second half
 h->cur = va_get(a, 8 * ch * hn * 2);         // this block: spectrum, then time
 h->fbuf = va_get(a, 4 * ch * hn);            // each channel's floor curve
 h->cls = va_get(a, 4 * ch * hn);             // residue classifications
 h->zr = va_get(a, 8 * (ch < 2 ? 2 : ch) * hn); // type 2's interleave, and the fft's room
 h->out = va_get(a, 4 * ch * hn * 2);
 return a->bad ? 3 : 0; }

// --- the audio -----------------------------------------------------------
static int vb_entry(const uint8_t *base, struct vbit *b, const struct vcb *c) {
 const int32_t *t = AT(const int32_t, c->tree);
 int32_t n = 0;
 for (int d = 0; d < 33; d++) {
  int32_t x = t[2 * n + (int) vb_get(b, 1)];
  if (b->eop || x == 0x7fffffff) return -1;
  if (x < 0) return ~x;
  n = x; }
 return -1; }

static int vb_rpoint(int x0, int y0, int x1, int y1, int x) {
 int dy = y1 - y0, adx = x1 - x0, ady = dy < 0 ? -dy : dy, off = ady * (x - x0) / adx;
 return dy < 0 ? y0 - off : y0 + off; }
static void vb_rline(int x0, int y0, int x1, int y1, int32_t *v, int n) {
 int dy = y1 - y0, adx = x1 - x0, ady = dy < 0 ? -dy : dy, base = dy / adx, sy = dy < 0 ? base - 1 : base + 1;
 int x = x0, y = y0, err = 0;
 ady -= (base < 0 ? -base : base) * adx;
 if (x < n) v[x] = y;
 for (x = x0 + 1; x < x1; x++) {
  err += ady;
  if (err >= adx) err -= adx, y += sy; else y += base;
  if (x < n) v[x] = y; } }

// a floor 1 into the curve v of n points -> 1, or 0 for a channel that is silent
static int vb_floor1(const uint8_t *base, const struct vh *h, const struct vfl *f, struct vbit *b, int32_t *v, int n) {
 static int const ranges[4] = {256, 128, 86, 64};
 int y[65], fin[65], step[65];
 if (!vb_get(b, 1)) return 0;
 int range = ranges[f->mult - 1], w = vb_ilog((uint32_t) range - 1), off = 2;
 y[0] = (int) vb_get(b, w), y[1] = (int) vb_get(b, w);
 for (int i = 0; i < f->parts; i++) {
  int c = f->cls[i], cd = f->cdim[c], cb = f->csub[c], cs = (1 << cb) - 1, cv = 0;
  if (cb) { cv = vb_entry(base, b, AT(const struct vcb, h->cb) + f->cbook[c]); if (cv < 0) return 0; }
  for (int j = 0; j < cd; j++) {
   int bk = f->sbook[c][cv & cs];
   cv >>= cb;
   y[off + j] = bk >= 0 ? vb_entry(base, b, AT(const struct vcb, h->cb) + bk) : 0;
   if (y[off + j] < 0) return 0; }
  off += cd; }
 if (b->eop) return 0;
 step[0] = step[1] = 1, fin[0] = y[0], fin[1] = y[1];
 for (int i = 2; i < f->values; i++) {
  int lo = f->lo[i], hi = f->hi[i];
  int pr = vb_rpoint(f->x[lo], fin[lo], f->x[hi], fin[hi], f->x[i]);
  int val = y[i], hr = range - pr, lr = pr, room = (hr < lr ? hr : lr) * 2;
  if (val) {
   step[lo] = step[hi] = step[i] = 1;
   if (val >= room) fin[i] = hr > lr ? val - lr + pr : pr - val + hr - 1;
   else fin[i] = val & 1 ? pr - (val + 1) / 2 : pr + val / 2; }
  else step[i] = 0, fin[i] = pr; }
 int lx = 0, ly = fin[f->ord[0]] * f->mult, hx = 0, hy = ly;
 for (int k = 1; k < f->values; k++) {
  int i = f->ord[k];
  if (!step[i]) continue;
  hy = fin[i] * f->mult, hx = f->x[i];
  vb_rline(lx, ly, hx, hy, v, n);
  lx = hx, ly = hy; }
 if (hx < n) vb_rline(hx, hy, n, hy, v, n);
 return 1; }

// a residue's partitions into the vectors v (n each) of the channels not left out
static void vb_resid(uint8_t *base, struct vh *h, struct vres *r, struct vbit *b, double **v, int nv, const int *dnd, int n) {
 int type = r->type, ch = nv, n0 = n;
 double *one[1], **v0 = v;
 int dnd1 = 0;
 if (type == 2) {
  int any = 0;
  for (int c = 0; c < nv; c++) any |= !dnd[c];
  if (!any) return;
  one[0] = AT(double, h->zr);
  for (int i = 0; i < n * nv; i++) one[0][i] = 0;
  v = one, dnd = &dnd1, n *= nv, ch = 1; }
 uint32_t beg = r->begin < (uint32_t) n ? r->begin : (uint32_t) n, end = r->end < (uint32_t) n ? r->end : (uint32_t) n;
 if (end <= beg) goto out;
 {
 const struct vcb *cb = AT(const struct vcb, h->cb) + r->classbook;
 int cw = (int) cb->dims, parts = (int) ((end - beg) / r->psize);
 int32_t *cls = AT(int32_t, h->cls);
 for (int pass = 0; pass < 8; pass++) {
  int pc = 0;
  while (pc < parts) {
   if (!pass)
    for (int c = 0; c < ch; c++) {
     if (dnd[c]) continue;
     int t = vb_entry(base, b, cb);
     if (t < 0) goto out;
     for (int i = cw - 1; i >= 0; i--) { if (pc + i < parts) cls[c * parts + pc + i] = t % r->nclass; t /= r->nclass; } }
   for (int i = 0; i < cw && pc < parts; i++, pc++)
    for (int c = 0; c < ch; c++) {
     if (dnd[c]) continue;
     int bk = r->books[cls[c * parts + pc]][pass];
     if (bk < 0) continue;
     const struct vcb *vb = AT(const struct vcb, h->cb) + bk;
     if (!vb->vq) goto out;
     const double *vq = AT(const double, vb->vq);
     uint32_t off = beg + (uint32_t) pc * r->psize, dim = vb->dims;
     if (type == 0) {
      uint32_t stp = r->psize / dim;
      for (uint32_t k = 0; k < stp; k++) {
       int e = vb_entry(base, b, vb);
       if (e < 0) goto out;
       for (uint32_t j = 0; j < dim; j++) v[c][off + k + j * stp] += vq[(uint32_t) e * dim + j]; } }
     else
      for (uint32_t k = 0; k < r->psize; ) {
       int e = vb_entry(base, b, vb);
       if (e < 0) goto out;
       for (uint32_t j = 0; j < dim && k < r->psize; j++, k++) v[c][off + k] += vq[(uint32_t) e * dim + j]; } } } }
 }
 out:
 if (type == 2)                                 // type 2 codes the channels interleaved
  for (int i = 0; i < n0; i++)
   for (int c = 0; c < nv; c++) v0[c][i] = one[0][i * nv + c]; }

// the dct-iv of m points, x into c, through an m/4-point complex fft in z
static void vb_dct4(const uint8_t *base, const struct vh *h, int k, const double *x, double *c, double *z) {
 int m = h->bs[k] / 2, q = m / 2;
 const double *pr = AT(const double, h->pre[k]), *po = AT(const double, h->post[k]), *tw = AT(const double, h->tw[k]);
 const uint32_t *rv = AT(const uint32_t, h->rev[k]);
 for (int i = 0; i < q; i++) {
  double a = x[2 * i], b = x[m - 1 - 2 * i];
  uint32_t j = rv[i];
  z[2 * j] = a * pr[2 * i] - b * pr[2 * i + 1], z[2 * j + 1] = a * pr[2 * i + 1] + b * pr[2 * i]; }
 for (int len = 2; len <= q; len *= 2)
  for (int s = 0; s < q; s += len)
   for (int j = 0; j < len / 2; j++) {
    double wr = tw[2 * (j * (q / len))], wi = tw[2 * (j * (q / len)) + 1];
    double *u = z + 2 * (s + j), *v = z + 2 * (s + j + len / 2);
    double tr = v[0] * wr - v[1] * wi, ti = v[0] * wi + v[1] * wr;
    v[0] = u[0] - tr, v[1] = u[1] - ti, u[0] += tr, u[1] += ti; }
 for (int i = 0; i < q; i++) {
  double ur = z[2 * i] * po[2 * i] - z[2 * i + 1] * po[2 * i + 1], ui = z[2 * i] * po[2 * i + 1] + z[2 * i + 1] * po[2 * i];
  c[2 * i] = ur, c[m - 1 - 2 * i] = -ui; } }

// one audio packet -> the samples a channel it lays in out (0 for the first), | -why
static int vb_audio(uint8_t *base, struct vh *h, const uint8_t *p, uint32_t len) {
 struct vbit b = {p, len, 0, 0};
 if (!len) return 0;
 if (vb_get(&b, 1)) return -1;
 const struct vmode *md = AT(const struct vmode, h->mode) + vb_get(&b, vb_ilog((uint32_t) h->nmode - 1));
 if (b.eop || md - AT(const struct vmode, h->mode) >= h->nmode) return -4;
 int blk = md->block, n = h->bs[blk], half = n / 2, pl = 0, nl = 0, ch = h->ch, hn = h->bs[1] / 2;
 if (blk) pl = (int) vb_get(&b, 1), nl = (int) vb_get(&b, 1);
 const struct vmap *mp = AT(const struct vmap, h->map) + md->map;
 int fz[256], dnd[256];
 int32_t *fb = AT(int32_t, h->fbuf);
 double *cur = AT(double, h->cur);
 for (int c = 0; c < ch; c++) {
  const struct vfl *f = AT(const struct vfl, h->fl) + mp->fl[mp->mux[c]];
  fz[c] = vb_floor1(base, h, f, &b, fb + (size_t) c * (size_t) hn, half);
  dnd[c] = !fz[c];
  for (int i = 0; i < half; i++) cur[(size_t) c * 2 * (size_t) hn + (size_t) i] = 0; }
 for (int s = 0; s < mp->steps; s++)
  if (!dnd[mp->mag[s]] || !dnd[mp->ang[s]]) dnd[mp->mag[s]] = dnd[mp->ang[s]] = 0;
 for (int s = 0; s < mp->submaps; s++) {
  double *v[256]; int d[256], nv = 0;
  for (int c = 0; c < ch; c++)
   if (mp->mux[c] == s) v[nv] = cur + (size_t) c * 2 * (size_t) hn, d[nv++] = dnd[c];
  vb_resid(base, h, AT(struct vres, h->res) + mp->res[s], &b, v, nv, d, half); }
 for (int s = mp->steps - 1; s >= 0; s--) {
  double *mg = cur + (size_t) mp->mag[s] * 2 * (size_t) hn, *an = cur + (size_t) mp->ang[s] * 2 * (size_t) hn;
  for (int i = 0; i < half; i++) {
   double m = mg[i], a = an[i];
   if (m > 0) { if (a > 0) an[i] = m - a; else an[i] = m, mg[i] = m + a; }
   else { if (a > 0) an[i] = m + a; else an[i] = m, mg[i] = m - a; } } }
 double *z = AT(double, h->zr), *cc = z + half, *pv = AT(double, h->prev);
 const double *wk = AT(const double, h->win[blk]), *w0 = AT(const double, h->win[0]);
 int out = h->primed ? h->pn / 4 + n / 4 : 0;
 float *o = AT(float, h->out);
 // vorbis's channel order to wav's (front left, right, centre, lfe, back, side)
 static uint8_t const ord[9][8] = {{0}, {0}, {0, 1}, {0, 2, 1}, {0, 1, 2, 3}, {0, 2, 1, 3, 4},
  {0, 2, 1, 4, 5, 3}, {0, 2, 1, 5, 6, 4, 3}, {0, 2, 1, 6, 7, 4, 5, 3}};
 for (int c = 0; c < ch; c++) {
  int oc = ch <= 8 ? ord[ch][c] : c;
  double *x = cur + (size_t) c * 2 * (size_t) hn, *pc = pv + (size_t) c * (size_t) hn;
  const int32_t *fc = fb + (size_t) c * (size_t) hn;
  for (int i = 0; i < half; i++) {
   int k = fc[i];
   x[i] = fz[c] ? x[i] * vb_idb[k < 0 ? 0 : k > 255 ? 255 : k] : 0; }
  vb_dct4(base, h, blk, x, cc, z);
  for (int i = 0; i < n; i++) {                // the imdct off the dct-iv's symmetries
   int mm = i + half / 2;
   x[i] = mm < half ? cc[mm] : mm < 2 * half ? -cc[2 * half - 1 - mm] : -cc[mm - 2 * half]; }
  // the window: a long block next to a short one takes the short slope, centred
  int s0 = h->bs[0] / 2;
  for (int i = 0; i < half; i++) {
   double wl, wr;
   if (blk && !pl) { int ls = n / 4 - s0 / 2; wl = i < ls ? 0 : i < ls + s0 ? w0[i - ls] : 1; }
   else wl = wk[i];
   if (blk && !nl) { int rs = n / 4 - s0 / 2, j = half - 1 - i; wr = j < rs ? 0 : j < rs + s0 ? w0[j - rs] : 1; }
   else wr = wk[half - 1 - i];
   x[i] *= wl, x[half + i] *= wr; }
  for (int j = 0; j < out; j++) {
   double sm = 0;
   int ci = j - h->pn / 4 + n / 4;
   if (j < h->pn / 2) sm += pc[j];
   if (ci >= 0) sm += x[ci];
   o[j * ch + oc] = (float) sm; }
  for (int i = 0; i < half; i++) pc[i] = x[half + i]; }
 h->pn = n, h->primed = 1;
 return out; }

static uint8_t *vb_cask(word x, uintptr_t *n) {
 if (charmp(x) || ((union u*) x)->ap != lvm_cask) return NULL;
 struct str *s = ((struct cask*) x)->str;
 if (!s || ((uintptr_t) s->bytes & 7)) return NULL;
 return *n = s->len, (uint8_t*) s->bytes; }

static love_inline struct g *host_vorbis_size(struct g *g) {
 word r = putcharm(-3);
 if (strp(g->sp[0]) && strp(g->sp[1])) {
  struct str *i = str(g->sp[0]), *s = str(g->sp[1]);
  struct va a = {NULL, 0, 0, 0};
  int e = vb_setup(&a, (const uint8_t*) i->bytes, (uint32_t) i->len, (const uint8_t*) s->bytes, (uint32_t) s->len);
  r = putcharm(e ? -e : a.bad || a.used > (64u << 20) ? -3 : (intptr_t) a.used + 8); }
 return g->sp[1] = r, g->sp += 1, g; }
static lvm(lvm_vorbis_size) LvmCall(g, host_vorbis_size)

static love_inline struct g *host_vorbis_init(struct g *g) {
 uintptr_t n = 0;
 uint8_t *b = vb_cask(g->sp[0], &n);
 word r = putcharm(3);
 if (b && strp(g->sp[1]) && strp(g->sp[2]) && n < 0x7fffffffu) {
  struct str *i = str(g->sp[1]), *s = str(g->sp[2]);
  struct va a = {b, 0, (uint32_t) n, 0};
  int e = vb_setup(&a, (const uint8_t*) i->bytes, (uint32_t) i->len, (const uint8_t*) s->bytes, (uint32_t) s->len);
  r = putcharm(e ? e : a.bad ? 3 : 0); }
 return g->sp[2] = r, g->sp += 2, g; }
static lvm(lvm_vorbis_init) LvmCall(g, host_vorbis_init)

love_noinline static struct g *host_vorbis_packet(struct g *g) {
 uintptr_t n = 0;
 uint8_t *b = vb_cask(g->sp[0], &n);
 if (!b || n < sizeof(struct vh) || !strp(g->sp[1]) || !oddp(g->sp[2])) return g->sp[2] = putcharm(3), g->sp += 2, g;
 struct vh *h = (struct vh*) b;
 if (!h->ch || !h->mode) return g->sp[2] = putcharm(3), g->sp += 2, g;
 struct str *p = str(g->sp[1]);
 intptr_t f = getcharm(g->sp[2]);
 int ns = vb_audio(b, h, (const uint8_t*) p->bytes, (uint32_t) p->len);
 if (ns < 0) return g->sp[2] = putcharm(-ns), g->sp += 2, g;
 uintptr_t k = (uintptr_t) ns * (uintptr_t) h->ch, on = k * (f ? 4u : 2u);
 if (!ok(g = have(g, str_width(on)))) return g;
 struct str *out = ini_str(bump(g, str_width(on)), on);
 b = vb_cask(g->sp[0], &n);                     // re-read: have may move it
 const float *o = (const float*) (b + ((struct vh*) b)->out);
 uint8_t *q = (uint8_t*) out->bytes;
 for (uintptr_t i = 0; i < k; i++) {
  float x = o[i];
  if (f) { union { float f; uint32_t u; } c = {x}; for (int j = 0; j < 4; j++) *q++ = (uint8_t) (c.u >> (8 * j)); }
  else {
   double y = (double) x * 32768;
   y = y > 32767 ? 32767 : y < -32768 ? -32768 : y;
   int v = y >= 0 ? (int) (y + 0.5) : -(int) (-y + 0.5);
   *q++ = (uint8_t) v, *q++ = (uint8_t) (v >> 8); } }
 return g->sp[2] = word(out), g->sp += 2, g; }
static lvm(lvm_vorbis_packet) LvmCall(g, host_vorbis_packet)

static union u const
  nif_vorbis_size[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_vorbis_size}, {lvm_ret0}},
  nif_vorbis_init[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_vorbis_init}, {lvm_ret0}},
  nif_vorbis_packet[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_vorbis_packet}, {lvm_ret0}};
LvNif("vorbis-size", nif_vorbis_size, NULL);
LvNif("vorbis-init", nif_vorbis_init, NULL);
LvNif("vorbis-packet", nif_vorbis_packet, NULL);
