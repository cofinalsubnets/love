// src/love/audio/rdec.c -- opus's range decoder (rfc 6716 4.1): 32-bit code, 8-bit symbols,
// the raw bits read backwards from the frame's end
#include "opus.h"

#define RD_TOP (1u << 31)
#define RD_BOT (RD_TOP >> 8)
#define RD_EXTRA 7                                  // (32 - 2) % 8 + 1

static int rd_front(struct rdec *d) { return d->off < d->len ? d->buf[d->off++] : 0; }
static int rd_back(struct rdec *d) { return d->eoff < d->len ? d->buf[d->len - ++d->eoff] : 0; }

static void rd_norm(struct rdec *d) {
 while (d->rng <= RD_BOT) {
  int s = d->rem;
  d->bits += 8, d->rng <<= 8;
  d->rem = rd_front(d);
  s = (s << 8 | d->rem) >> (8 - RD_EXTRA);
  d->val = ((d->val << 8) + (255 & ~s)) & (RD_TOP - 1); } }

void rd_init(struct rdec *d, const uint8_t *buf, uint32_t len) {
 d->buf = buf, d->len = len, d->off = d->eoff = 0, d->ew = 0, d->en = 0, d->err = 0, d->ext = 0;
 d->bits = 33 - ((32 - RD_EXTRA) / 8) * 8;
 d->rng = 1u << RD_EXTRA;
 d->rem = rd_front(d);
 d->val = d->rng - 1 - (uint32_t) (d->rem >> (8 - RD_EXTRA));
 rd_norm(d); }

unsigned rd_freq(struct rdec *d, unsigned ft) {
 d->ext = d->rng / ft;
 unsigned s = d->val / d->ext + 1;
 return ft - (s < ft ? s : ft); }

unsigned rd_freqb(struct rdec *d, unsigned bits) {
 d->ext = d->rng >> bits;
 unsigned s = d->val / d->ext + 1, ft = 1u << bits;
 return ft - (s < ft ? s : ft); }

void rd_take(struct rdec *d, unsigned fl, unsigned fh, unsigned ft) {
 uint32_t s = d->ext * (ft - fh);
 d->val -= s;
 d->rng = fl > 0 ? d->ext * (fh - fl) : d->rng - s;
 rd_norm(d); }

int rd_logp(struct rdec *d, unsigned logp) {
 uint32_t s = d->rng >> logp;
 int one = d->val < s;
 if (!one) d->val -= s;
 d->rng = one ? s : d->rng - s;
 rd_norm(d);
 return one; }

int rd_icdf(struct rdec *d, const uint8_t *icdf, unsigned ftb) {
 uint32_t r = d->rng >> ftb, s = d->rng, t;
 int k = -1;
 do t = s, s = r * icdf[++k]; while (d->val < s);
 d->val -= s, d->rng = t - s;
 rd_norm(d);
 return k; }

uint32_t rd_raw(struct rdec *d, unsigned bits) {
 uint32_t w = d->ew;
 int n = d->en;
 if ((unsigned) n < bits)
  do w |= (uint32_t) rd_back(d) << n, n += 8; while (n <= 24);
 uint32_t v = w & ((1u << bits) - 1);
 d->ew = w >> bits, d->en = n - (int) bits, d->bits += (int) bits;
 return v; }

uint32_t rd_uint(struct rdec *d, uint32_t ft) {
 uint32_t top = ft - 1;
 int b = rd_ilog(top);
 if (b <= 8) {
  unsigned s = rd_freq(d, ft);
  rd_take(d, s, s + 1, ft);
  return s; }
 b -= 8;
 unsigned hi = (unsigned) (top >> b) + 1, s = rd_freq(d, hi);
 rd_take(d, s, s + 1, hi);
 uint32_t v = (uint32_t) s << b | rd_raw(d, (unsigned) b);
 if (v <= top) return v;
 d->err = 1;
 return top; }

int rd_ilog(uint32_t v) { int n = 0; while (v) n++, v >>= 1; return n; }

int rd_tell(const struct rdec *d) { return d->bits - rd_ilog(d->rng); }

// the range's log2 to three fractional bits, by squaring
uint32_t rd_tellf(const struct rdec *d) {
 int l = rd_ilog(d->rng);
 uint32_t r = d->rng >> (l - 16);
 for (int i = 0; i < 3; i++) {
  r = r * r >> 15;
  int b = (int) (r >> 16);
  l = l << 1 | b, r >>= b; }
 return ((uint32_t) d->bits << 3) - (uint32_t) l; }
