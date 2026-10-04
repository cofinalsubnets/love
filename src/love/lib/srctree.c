// srctree.c -- see srctree.h. what it lays comes from the caller's grab and is never given
// back: the tree stays for the life of the process, or of the machine.
#include "love.h"
#include "srctree.h"
#include "ustar.h"
#include <string.h>

static uint32_t st_le(unsigned char const *p, int k) {
  uint32_t v = 0;
  while (k--) v = v << 8 | p[k];
  return v; }

intptr_t tree_decode(uint32_t codec, unsigned char const *z, uintptr_t zn,
                        unsigned char *out, uintptr_t cap) {
  switch (codec) {
  case tree_stored: return zn == cap ? (memcpy(out, z, cap), (intptr_t) cap) : -1;
  case tree_deflate: return inflate_raw(z, zn, out, cap) == (intptr_t) cap ? (intptr_t) cap : -1;
  case tree_bzip2: return bz2_into(z, zn, out, cap);
  case tree_lzma2: return lzma2_into(z, zn, out, cap);
  default: return -1; } }

// a section that will not decode is marked past every codec, so a second ask grabs nothing
unsigned char const *tree_sec(struct tree *t, uint32_t i) {
  if (i >= t->ns) return NULL;
  struct tree_sec *s = t->s + i;
  if (s->bytes || s->codec > tree_lzma2) return s->bytes;
  unsigned char *b = t->grab(s->raw ? s->raw : 1);
  if (!b || tree_decode(s->codec, s->z, s->packed, b, s->raw) < 0 || crc32(b, s->raw) != s->crc)
    return s->codec = ~(uint32_t) 0, NULL;
  return s->bytes = b; }

unsigned char const *tree_bytes(struct tree *t, struct tree_row const *r) {
  unsigned char const *b = tree_sec(t, r->sec);
  return b ? b + r->off : NULL; }

intptr_t tree_named(struct tree const *t, char const *name) {
  uintptr_t n = strlen(name);
  for (uint32_t i = 0; i < t->ns; i++)
    if (strlen(t->s[i].name) == n && !memcmp(t->s[i].name, name, n)) return (intptr_t) i;
  return -1; }

intptr_t tree_find(struct tree const *t, char const *p, uintptr_t n) {
  for (uintptr_t i = 0; i < t->n; i++)
    if (strlen(t->rows[i].path) == n && !memcmp(t->rows[i].path, p, n)) return (intptr_t) i;
  return -1; }

// the index record at o -> the offset past it, or 0 where it runs off the end
static uintptr_t st_next(unsigned char const *x, uintptr_t n, uintptr_t o) {
  uintptr_t p = o + 16;
  if (p >= n) return 0;
  while (p < n && x[p]) p++;
  if (++p >= n) return 0;
  while (p < n && x[p]) p++;
  return p < n ? p + 1 : 0; }

bool tree_open(struct tree *t, unsigned char const *z, uintptr_t zn, void *(*grab)(uintptr_t)) {
  memset(t, 0, sizeof *t);
  t->grab = grab;
  if (zn < 12 || memcmp(z, "lovetree", 8)) return false;
  uint32_t ns = st_le(z + 8, 4);
  uintptr_t at = 12 + 24 * (uintptr_t) ns;
  if (!ns || ns > TREE_SECS || zn < at) return false;
  for (uint32_t i = 0; i < ns; i++) {
    unsigned char const *h = z + 12 + 24 * i;
    struct tree_sec *s = t->s + i;
    memcpy(s->name, h, 8), s->name[8] = 0;
    s->codec = st_le(h + 8, 4), s->raw = st_le(h + 12, 4);
    s->packed = st_le(h + 16, 4), s->crc = st_le(h + 20, 4);
    if (zn - at < s->packed) return false;
    s->z = z + at, at += s->packed; }
  t->ns = ns;
  unsigned char const *x = tree_sec(t, 0);
  if (!x) return false;
  uintptr_t xn = t->s[0].raw, n = 0;
  for (uintptr_t o = 0; o < xn; n++)
    if (!(o = st_next(x, xn, o))) return false;
  struct tree_row *r = grab(n ? n * sizeof *r : 1);
  if (!r) return false;
  // a file row's bytes must sit inside a tar section; a link's are its target's, below
  uintptr_t k = 0;
  for (uintptr_t o = 0; o < xn; o = st_next(x, xn, o)) {
    unsigned char const *h = x + o;
    char const *p = (char const*) h + 16;
    uint32_t sec = h[0];
    r[k] = (struct tree_row) { .path = p, .to = h[1] == '2' ? p + strlen(p) + 1 : NULL,
                                  .sec = sec, .off = st_le(h + 4, 4), .len = st_le(h + 8, 4),
                                  .mtime = st_le(h + 12, 4), .mode = st_le(h + 2, 2) };
    if (r[k].to || (sec && sec < ns && r[k].off <= t->s[sec].raw
                    && r[k].len <= t->s[sec].raw - r[k].off)) k++; }
  // two passes cover a link to a link; what never resolves (dangling, or a directory) drops
  for (int pass = 0; pass < 2; pass++)
    for (uintptr_t i = 0; i < k; i++)
      if (r[i].to) {
        char cn[256];
        uintptr_t cl = lnk_canon(r[i].path, r[i].to, cn, sizeof cn - 1);
        for (uintptr_t j = 0; cl && j < k; j++)
          if (!r[j].to && strlen(r[j].path) == cl && !memcmp(r[j].path, cn, cl)) {
            r[i].sec = r[j].sec, r[i].off = r[j].off, r[i].len = r[j].len;
            r[i].mtime = r[j].mtime, r[i].to = NULL;
            break; } }
  uintptr_t w = 0;
  for (uintptr_t i = 0; i < k; i++)
    if (!r[i].to) r[w++] = r[i];
  return t->rows = r, t->n = w, true; }
