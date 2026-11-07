// bz_gen.h -- laid by src/love/compress/bz.l, `make mx`. edit that file.
#define BZ_TN 900000
#define BZ_MAXSEL 18002
#define BZ_LIM 30
struct bz_w { uint8_t *p; uintptr_t on, oc; uint64_t acc; unsigned k; int bad, big, fix; };   // fix: p is the caller's, never grown
struct bz_r { const uint8_t *p; uintptr_t i, n; uint64_t acc; unsigned k; };
struct bz_tab {
 uint16_t fast[1024];                            // sym << 5 | len, or 0 past the root
 uint32_t limit[22], base[22]; uint16_t perm[258]; unsigned maxl; };
struct bz_d {
 uint32_t tt[BZ_TN]; struct bz_tab tab[6]; uint8_t sel[BZ_MAXSEL]; uint32_t crct[256];
 uint32_t cnt[256], cf[256], alpha, ns, nb, bc, want, p, u, crc, same; int last;
 uint8_t seq[256], yy[256], len[258], pos[6]; };static inline int bw_byte(struct bz_w *r, uint8_t b) {
 unsigned int lim = BZ_LIM;
 uintptr_t c;
 uint8_t *q;
 if (r->oc <= r->on) {
  if (r->fix != 0) {
   r->bad = 1;
   return 0;
  }
  if (1u << lim <= r->on) {
   r->bad = 1;
   r->big = 1;
   return 0;
  }
  if (r->bad != 0)
   return 0;
  if (!r->oc) {
   c = 4096;
  } else {
   c = r->oc << 1;
  }
  q = alloc(0, c);
  if (!q) {
   r->bad = 1;
   return 0;
  }
  if (r->on) {
   memcpy(q + 0, r->p + 0, r->on);
  }
  if (r->p != 0) {
   alloc(r->p, 0);
  }
  r->p = q;
  r->oc = c;
 }
 r->p[r->on] = b;
 r->on++;
 return 0;
}
static inline void br_fill(struct bz_r *r) {
 unsigned int x;
 while (r->k <= 56) {
  if (r->i < r->n) {
   x = r->p[r->i];
  } else {
   x = 0;
  }
  r->acc = r->acc << 8 | x;
  if (r->i < r->n + 9) {
   r->i++;
  }
  r->k += 8;
 }
}
static inline unsigned int br_get(struct bz_r *r, unsigned int K) {
 unsigned int v;
 if (r->k < K) {
  br_fill(r);
 }
 v = (uint32_t) ((r->acc >> (r->k - K)) & (((uint64_t) 1 << K) - 1));
 r->k = r->k - K;
 return v;
}
static inline int br_past(struct bz_r const *r) {
 if (r->n < r->i)
  if (r->k >> 3 < r->i - r->n)
   return 1;
 return 0;
}
static int bz_tbuild(struct bz_tab *s, uint8_t const *len, unsigned int n) {
 unsigned int code, t, l, u, lo, hi, j;
 memset(s->fast, 0, sizeof(s->fast));
 s->maxl = 0;
 for (u = 0; u < n; u++)
  if (s->maxl < len[u])
   s->maxl = len[u];
 code = 0;
 t = 0;
 for (l = 1; l < 21; l++) {
  s->base[l] = code - t;
  for (u = 0; u < n; u++)
   if (len[u] == l) {
    if (258 <= t)
     return 0;
    s->perm[t] = u;
    t++;
    if (l <= 10) {
     lo = code << (10 - l);
     if (1024 < lo)
      return 0;
     hi = lo + (1u << (10 - l));
     if (1024 < hi)
      return 0;
     for (j = lo; j < hi; j++)
      s->fast[j] = u << 5 | l;
    }
    code++;
   }
  if (1u << l < code)
   return 0;
  s->limit[l] = code;
  code <<= 1;
 }
 return 1;
}
static inline unsigned int bz_sym(struct bz_r *r, struct bz_tab const *s) {
 unsigned int v, f, l, c, t, m;
 if (r->k < 32) {
  br_fill(r);
 }
 v = (uint32_t) (r->acc >> (r->k - 10));
 f = s->fast[v & 1023];
 if (f != 0) {
  r->k = r->k - (f & 31);
  return f >> 5;
 }
 m = s->maxl;
 if (20 < m)
  return 999;
 for (l = 11; l < m + 1; l++) {
  c = (uint32_t) ((r->acc >> (r->k - l)) & (((uint64_t) 1 << l) - 1));
  if (c < s->limit[l]) {
   t = c - s->base[l];
   if (258 <= t)
    return 999;
   r->k = r->k - l;
   return s->perm[t];
  }
 }
 return 999;
}
static int bz_dhead(struct bz_r *r, struct bz_d *d) {
 unsigned int u, j, t, v, b, nuse, m0, m1, c, x, alpha, ng, ns, ms = BZ_MAXSEL;
 uintptr_t cap, m;
 struct bz_tab *tp;
 nuse = 0;
 m0 = br_get(r, 16);
 for (u = 0; u < 16; u++)
  if ((m0 >> (15 - u)) & 1) {
   m1 = br_get(r, 16);
   for (j = 0; j < 16; j++)
    if ((m1 >> (15 - j)) & 1) {
     if (256 <= nuse)
      return 2;
     d->seq[nuse] = (u << 4) + j;
     nuse++;
    }
  }
 if (!nuse)
  return 2;
 alpha = nuse + 2;
 if (258 < alpha)
  return 2;
 ng = br_get(r, 3);
 ns = br_get(r, 15);
 if (ng < 2)
  return 2;
 if (6 < ng)
  return 2;
 if (!ns)
  return 2;
 for (t = 0; t < ng; t++)
  d->pos[t] = t;
 for (u = 0; u < ns; u++) {
  j = 0;
  while (1) {
   b = br_get(r, 1);
   if (!b)
    break;
   j++;
   if (ng <= j)
    return 2;
  }
  v = d->pos[j];
  memmove(d->pos + 1, d->pos + 0, j);
  d->pos[0] = v;
  if (u < ms)
   d->sel[u] = v;
 }
 if (ms < ns) {
  ns = ms;
 }
 d->ns = ns;
 d->alpha = alpha;
 m = 0;
 cap = (r->n + 9) << 4;
 for (t = 0; t < ng; t++) {
  c = br_get(r, 5);
  for (v = 0; v < alpha; v++) {
   while (1) {
    if (cap <= m)
     return 3;
    m++;
    if (c < 1)
     return 2;
    if (20 < c)
     return 2;
    b = br_get(r, 1);
    if (!b)
     break;
    x = br_get(r, 1);
    if (x) {
     c = c - 1;
    } else {
     c++;
    }
   }
   d->len[v] = c;
  }
  tp = d->tab + t;
  x = bz_tbuild(tp, d->len, alpha);
  if (!x)
   return 2;
  x = br_past(r);
  if (x)
   return 3;
 }
 return 0;
}
static int bz_dsyms(struct bz_r *r, struct bz_d *d, unsigned int level) {
 unsigned int g, left, s, x, run, rw, mx, c, v, q, y, nb, alpha, ns, ms = BZ_MAXSEL, tn = BZ_TN;
 struct bz_tab *tp;
 alpha = d->alpha;
 ns = d->ns;
 if (258 < alpha)
  return 2;
 if (alpha < 2)
  return 2;
 if (ms < ns)
  return 2;
 memset(d->cnt, 0, sizeof(d->cnt));
 mx = level * 100000;
 if (tn < mx)
  return 2;
 nb = 0;
 run = 0;
 rw = 1;
 for (y = 0; y < 256; y++)
  d->yy[y] = y;
 for (g = 0; g < ns; g++) {
  x = br_past(r);
  if (x)
   return 3;
  x = d->sel[g];
  if (5 < x)
   return 2;
  tp = d->tab + x;
  for (left = 0; left < 50; left++) {
   s = bz_sym(r, tp);
   if (alpha <= s)
    return 2;
   if (s < 2) {
    if (mx < rw)
     return 2;
    run = run + (rw << s);
    rw = rw << 1;
    if (mx < run)
     return 2;
   } else {
    if (run) {
     y = d->yy[0];
     c = d->seq[y & 255];
     if (mx - nb < run)
      return 2;
     d->cnt[c & 255] = d->cnt[c & 255] + run;
     for (q = 0; q < run; q++)
      d->tt[nb + q] = c;
     nb += run;
     run = 0;
     rw = 1;
    }
    if (alpha - 1 <= s) {
     d->nb = nb;
     return 0;
    }
    if (mx <= nb)
     return 2;
    v = s - 1;
    if (256 <= v)
     return 2;
    y = d->yy[v];
    memmove(d->yy + 1, d->yy + 0, v);
    d->yy[0] = y;
    c = d->seq[y & 255];
    d->cnt[c & 255] = d->cnt[c & 255] + 1;
    d->tt[nb] = c;
    nb++;
   }
  }
 }
 return 2;
}
static int bz_dlink(struct bz_d *d, unsigned int nb, unsigned int orig) {
 unsigned int c, s, u, j, x, tn = BZ_TN;
 if (tn < nb)
  return 2;
 if (nb <= orig)
  return 2;
 s = 0;
 for (c = 0; c < 256; c++) {
  d->cf[c] = s;
  s = s + d->cnt[c];
 }
 for (u = 0; u < nb; u++) {
  x = d->tt[u];
  j = d->cf[x & 255];
  if (nb <= j)
   return 2;
  d->tt[j] = d->tt[j] | u << 8;
  d->cf[x & 255] = j + 1;
 }
 d->p = d->tt[orig] >> 8;
 d->crc = 4294967295;
 d->last = -1;
 d->same = 0;
 d->u = 0;
 return 0;
}
static int bz_dblock(struct bz_d *d, struct bz_r *r, unsigned int level) {
 unsigned int want, orig, x, nb;
 if ((uintptr_t) -1 - 9 < r->n)
  return 2;
 if ((uintptr_t) -1 >> 4 < r->n + 9)
  return 2;
 if (r->n + 9 < r->i)
  return 2;
 if (64 < r->k)
  return 2;
 want = br_get(r, 32);
 x = br_get(r, 1);
 if (x)
  return 2;
 orig = br_get(r, 24);
 x = bz_dhead(r, d);
 if (x)
  return x;
 x = bz_dsyms(r, d, level);
 if (x)
  return x;
 x = br_past(r);
 if (x)
  return 3;
 nb = d->nb;
 x = bz_dlink(d, nb, orig);
 if (x)
  return x;
 d->want = want;
 return 0;
}
static int bz_dwalk(struct bz_d *d, struct bz_w *w, uintptr_t room) {
 unsigned int c, u, u0, j, x, p, nb, crc, y, same, want, tn = BZ_TN;
 int last;
 if (w->oc < w->on)
  return 2;
 nb = d->nb;
 if (tn < nb)
  return 2;
 p = d->p;
 crc = d->crc;
 last = d->last;
 same = d->same;
 u0 = d->u;
 for (u = u0; u < nb; u++) {
  if (room <= w->on) {
   d->u = u;
   d->p = p;
   d->crc = crc;
   d->last = last;
   d->same = same;
   return 1;
  }
  if (nb <= p)
   return 2;
  x = d->tt[p];
  c = x & 255;
  p = x >> 8;
  if (same == 4) {
   for (j = 0; j < c; j++) {
    y = (crc >> 24) ^ last;
    crc = (crc << 8) ^ d->crct[y & 255];
    bw_byte(w, (uint8_t) last);
   }
   same = 0;
   last = -1;
  } else {
   y = (crc >> 24) ^ c;
   crc = (crc << 8) ^ d->crct[y & 255];
   bw_byte(w, (uint8_t) c);
   if (c == (uint32_t) last) {
    same = same + 1;
   } else {
    same = 1;
   }
   last = c;
  }
 }
 d->u = nb;
 if (w->bad != 0)
  return -1;
 want = d->want;
 if (~crc != want)
  return 4;
 d->bc = want;
 return 0;
}
