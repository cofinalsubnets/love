// a call through a parameter from a frame past the short offsets, a value live across it: on
// thumb2 the park (r12) is also a far store's address, so no store may sit between the two
#include <stdio.h>
#include <string.h>

struct sec { char name[9]; unsigned codec, raw, packed, crc; unsigned char const *z, *bytes; };
struct row { char const *path, *to; unsigned sec, off, len, mtime, mode; };
struct tree { struct sec s[8]; unsigned ns; struct row *rows; unsigned n; void *(*grab)(unsigned); };

static unsigned char heap[4096];
static unsigned used;
static void *bump(unsigned n) { void *p = heap + used; used += (n + 7) & ~7u; return used <= sizeof heap ? p : 0; }

static unsigned le(unsigned char const *p, int k) { unsigned v = 0; while (k--) v = v << 8 | p[k]; return v; }

static unsigned next(unsigned char const *x, unsigned n, unsigned o) {
  unsigned p = o + 16;
  if (p >= n) return 0;
  while (p < n && x[p]) p++;
  if (++p >= n) return 0;
  while (p < n && x[p]) p++;
  return p < n ? p + 1 : 0; }

static int open_tree(struct tree *t, unsigned char const *z, unsigned zn, void *(*grab)(unsigned)) {
  memset(t, 0, sizeof *t);
  t->grab = grab;
  if (zn < 12 || memcmp(z, "lovetree", 8)) return 0;
  unsigned ns = le(z + 8, 4), at = 12 + 24 * ns;
  if (!ns || ns > 8 || zn < at) return 0;
  for (unsigned i = 0; i < ns; i++) {
    unsigned char const *h = z + 12 + 24 * i;
    struct sec *s = t->s + i;
    memcpy(s->name, h, 8), s->name[8] = 0;
    s->codec = le(h + 8, 4), s->raw = le(h + 12, 4), s->packed = le(h + 16, 4), s->crc = le(h + 20, 4);
    if (zn - at < s->packed) return 0;
    s->z = z + at, at += s->packed; }
  t->ns = ns;
  unsigned char const *x = t->s[0].z;
  unsigned xn = t->s[0].raw, n = 0;
  for (unsigned o = 0; o < xn; n++)
    if (!(o = next(x, xn, o))) return 0;
  struct row *r = grab(n ? n * sizeof *r : 1);
  if (!r) return 0;
  unsigned k = 0;
  for (unsigned o = 0; o < xn; o = next(x, xn, o)) {
    unsigned char const *h = x + o;
    char const *p = (char const *) h + 16;
    r[k] = (struct row) { .path = p, .to = h[1] == '2' ? p + strlen(p) + 1 : 0, .sec = h[0],
                          .off = le(h + 4, 4), .len = le(h + 8, 4), .mtime = le(h + 12, 4), .mode = le(h + 2, 2) };
    if (r[k].to || r[k].sec < ns) k++; }
  for (int pass = 0; pass < 2; pass++)
    for (unsigned i = 0; i < k; i++)
      if (r[i].to) {
        char cn[256];
        unsigned cl = (unsigned) strlen(r[i].to);
        if (cl >= sizeof cn) continue;
        memcpy(cn, r[i].to, cl);
        for (unsigned j = 0; j < k; j++)
          if (!r[j].to && strlen(r[j].path) == cl && !memcmp(r[j].path, cn, cl)) {
            r[i].sec = r[j].sec, r[i].off = r[j].off, r[i].len = r[j].len, r[i].to = 0;
            break; } }
  unsigned w = 0;
  for (unsigned i = 0; i < k; i++)
    if (!r[i].to) r[w++] = r[i];
  return t->rows = r, t->n = w, 1; }

// one section, its index three rows: two files and a link to the first
static unsigned char img[512];
static unsigned put(unsigned o, unsigned char sec, char kind, unsigned off, unsigned len, char const *p, char const *to) {
  memset(img + o, 0, 16);
  img[o] = sec, img[o + 1] = (unsigned char) kind;
  img[o + 4] = (unsigned char) off, img[o + 8] = (unsigned char) len;
  o += 16;
  strcpy((char *) img + o, p), o += (unsigned) strlen(p) + 1;
  strcpy((char *) img + o, to), o += (unsigned) strlen(to) + 1;
  return o; }

int main(void) {
  unsigned x = 36, o = x;
  o = put(o, 0, '0', 1, 5, "a.l", "");
  o = put(o, 0, '0', 6, 7, "b.l", "");
  o = put(o, 0, '2', 0, 0, "c.l", "a.l");
  memcpy(img, "lovetree", 8), img[8] = 1;
  memcpy(img + 12, "index\0\0\0", 8);
  img[24] = (unsigned char) (o - x), img[28] = (unsigned char) (o - x);
  struct tree t;
  int ok = open_tree(&t, img, o, bump);
  printf("%d %u\n", ok, ok ? t.n : 0);
  for (unsigned i = 0; ok && i < t.n; i++) printf("%s %u %u\n", t.rows[i].path, t.rows[i].off, t.rows[i].len);
  return 0; }
