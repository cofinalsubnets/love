// inf_st_gen.h -- laid by src/love/compress/inf.l, `make mx`. edit that file.
// what a stop keeps of a block in the reading: the mode and where in it
struct inf_ms {
 unsigned mode, last, rem, hlit, hdist, hclen, i, prev, stage, sy, len, dist;
 uint8_t lens[320], cl[19];
 uintptr_t hlen;                  // hist's bytes, of which the last 32 KiB are the window
 uint8_t hist[1 << 16]; };
// a stream between feeds. its pointers go stale when the state moves: a feed lays them again
struct inf_st {
 uint64_t magic;
 struct inf_rd r;
 struct inf_tabs t;
 struct inf_ms m; };
static inline int inf_sy1(struct inf_rd *r, struct inf_code const *c, uint16_t const *t, unsigned int root) {
 int x;
 inf_fill(r);
 if (r->bc < 15) {
  if (r->n)
   return -1;
 }
 x = inf_sym(r, c, t, root);
 if (x < 0)
  return -3;
 return x;
}
static inline int inf_sthead(struct inf_rd *r, struct inf_ms *s) {
 int x;
 unsigned int typ, dr;
 x = inf_take(r, 3);
 if (x < 0)
  return x;
 s->last = x & 1;
 typ = x >> 1;
 if (!typ) {
  dr = r->bc & 7;
  r->bb >>= dr;
  r->bc = r->bc - dr;
  s->mode = 1;
 } else {
  if (3 <= typ)
   return -3;
  if (typ <= 1) {
   inf_fixed(r);
   s->mode = 6;
   s->stage = 0;
  } else {
   s->mode = 3;
  }
 }
 return 0;
}
static inline int inf_stlen(struct inf_rd *r, struct inf_ms *s) {
 unsigned int ln, nl;
 uint64_t y;
 inf_fill(r);
 if (r->bc < 32)
  return -1;
 ln = r->bb & ((1u << 16) - 1);
 y = r->bb >> 16;
 nl = y & ((1u << 16) - 1);
 if (((ln ^ 65535) & 65535) != nl)
  return -3;
 r->bb >>= 32;
 r->bc = r->bc - 32;
 s->rem = ln;
 s->mode = 2;
 return 0;
}
static inline int inf_ststo(struct inf_rd *r, struct inf_ms *s) {
 uintptr_t k;
 if (s->rem) {
  while (s->rem) {
   if (r->bc < 8)
    break;
   if (r->cap <= r->op)
    return -2;
   r->out[r->op] = (uint8_t) (r->bb & 255);
   r->op++;
   r->bb >>= 8;
   r->bc = r->bc - 8;
   s->rem = s->rem - 1;
  }
 }
 if (s->rem) {
  r->bb = 0;
  k = r->n - r->ip;
  if (s->rem < k) {
   k = s->rem;
  }
  if (r->cap - r->op < k) {
   k = r->cap - r->op;
  }
  memcpy(r->out + r->op, r->in + r->ip, k);
  r->op += k;
  r->ip += k;
  s->rem = s->rem - k;
  if (s->rem) {
   if (r->ip < r->n)
    return -2;
   return -1;
  }
 }
 if (s->last) {
  s->mode = 7;
 } else {
  s->mode = 0;
 }
 return 0;
}
static inline int inf_sttab(struct inf_rd *r, struct inf_ms *s) {
 uint64_t y;
 inf_fill(r);
 if (r->bc < 14)
  return -1;
 s->hlit = (r->bb & ((1u << 5) - 1)) + 257;
 y = r->bb >> 5;
 s->hdist = (y & ((1u << 5) - 1)) + 1;
 y = r->bb >> 10;
 s->hclen = (y & ((1u << 4) - 1)) + 4;
 r->bb >>= 14;
 r->bc = r->bc - 14;
 memset(s->cl, 0, sizeof(s->cl));
 s->i = 0;
 s->mode = 4;
 return 0;
}
static inline int inf_stcl(struct inf_rd *r, struct inf_ms *s) {
 int x;
 if (19 < s->hclen)
  return -3;
 while (s->i < s->hclen) {
  x = inf_take(r, 3);
  if (x < 0)
   return x;
  s->cl[gz_clord[s->i]] = x;
  s->i++;
 }
 inf_build(&r->t->cl, s->cl, 19, r->t->csym, r->t->ctab, CROOT);
 memset(s->lens, 0, sizeof(s->lens));
 s->i = 0;
 s->prev = 0;
 s->stage = 0;
 s->mode = 5;
 return 0;
}
static inline int inf_stln(struct inf_rd *r, struct inf_ms *s) {
 int x;
 unsigned int tot, rr, v, k;
 if (288 < s->hlit)
  return -3;
 if (32 < s->hdist)
  return -3;
 tot = s->hlit + s->hdist;
 while (s->i < tot) {
  if (!s->stage) {
   x = inf_sy1(r, &r->t->cl, r->t->ctab, CROOT);
   if (x < 0)
    return x;
   s->sy = x;
   s->stage = 1;
  }
  if (s->sy < 16) {
   rr = 1;
   v = s->sy;
  } else {
   if (18 < s->sy)
    return -3;
   if (s->sy <= 16) {
    x = inf_take(r, 2);
    if (x < 0)
     return x;
    rr = x + 3;
    v = s->prev;
   } else {
    if (s->sy <= 17) {
     x = inf_take(r, 3);
     if (x < 0)
      return x;
     rr = x + 3;
    } else {
     x = inf_take(r, 7);
     if (x < 0)
      return x;
     rr = x + 11;
    }
    v = 0;
   }
  }
  for (k = 0; k < rr; k++)
   if (s->i + k < 320)
    s->lens[s->i + k] = v;
  s->i += rr;
  s->prev = v;
  s->stage = 0;
 }
 inf_build(&r->t->lit, s->lens, s->hlit, r->t->lsym, r->t->ltab, LROOT);
 inf_build(&r->t->dst, s->lens + s->hlit, s->hdist, r->t->dsym, r->t->dtab, DROOT);
 s->mode = 6;
 s->stage = 0;
 return 0;
}
static inline int inf_stsy(struct inf_rd *r, struct inf_ms *s) {
 int x, y;
 uintptr_t l, d;
 while (1) {
  if (!s->stage) {
   if (r->ip + 8 <= r->n) {
    if (r->op + 266 <= r->cap) {
     x = inf_fast_run(r);
     if (x < 0)
      return -3;
     if (x) {
      if (s->last) {
       s->mode = 7;
      } else {
       s->mode = 0;
      }
      return 0;
     }
    }
   }
   x = inf_sy1(r, &r->t->lit, r->t->ltab, LROOT);
   if (x < 0)
    return x;
   s->sy = x;
   if (x < 256) {
    s->stage = 4;
   } else {
    if (x <= 256) {
     if (s->last) {
      s->mode = 7;
     } else {
      s->mode = 0;
     }
     return 0;
    }
    s->stage = 1;
   }
  }
  if (s->stage == 4) {
   if (r->cap <= r->op)
    return -2;
   if (255 < s->sy)
    return -3;
   r->out[r->op] = (uint8_t) s->sy;
   r->op++;
   s->stage = 0;
  } else {
   if (s->stage == 1) {
    if (s->sy < 257)
     return -3;
    if (285 < s->sy)
     return -3;
    l = gz_lbase[s->sy - 257];
    y = inf_take(r, gz_lext[s->sy - 257]);
    if (y < 0)
     return y;
    s->len = l + y;
    s->stage = 2;
   }
   if (s->stage == 2) {
    x = inf_sy1(r, &r->t->dst, r->t->dtab, DROOT);
    if (x < 0)
     return x;
    s->sy = x;
    s->stage = 3;
   }
   if (s->stage == 3) {
    if (29 < s->sy)
     return -3;
    d = gz_dbase[s->sy];
    y = inf_take(r, gz_dext[s->sy]);
    if (y < 0)
     return y;
    s->dist = d + y;
    s->stage = 5;
   }
   if (1u << 15 < s->dist)
    return -3;
   if (r->op + r->nd < s->dist)
    return -3;
   if (!s->len)
    return -3;
   if (r->cap - r->op < s->len)
    return -2;
   inf_copy(r, s->len, s->dist);
   r->op += s->len;
   s->stage = 0;
  }
 }
}
static inline int inf_strest(struct inf_rd *r, struct inf_ms *s) {
 int x;
 if (s->mode == 1) {
  x = inf_stlen(r, s);
  if (x < 0)
   return x;
 }
 if (s->mode == 2) {
  x = inf_ststo(r, s);
  if (x < 0)
   return x;
 }
 if (s->mode == 3) {
  x = inf_sttab(r, s);
  if (x < 0)
   return x;
 }
 if (s->mode == 4) {
  x = inf_stcl(r, s);
  if (x < 0)
   return x;
 }
 if (s->mode == 5) {
  x = inf_stln(r, s);
  if (x < 0)
   return x;
 }
 if (s->mode == 6) {
  x = inf_stsy(r, s);
  if (x < 0)
   return x;
 }
 return 0;
}
static int inf_ststep(struct inf_rd *r, struct inf_ms *s) {
 int x;
 x = inf_strest(r, s);
 if (x < 0)
  return x;
 while (!s->mode) {
  x = inf_sthead(r, s);
  if (x < 0)
   return x;
  x = inf_strest(r, s);
  if (x < 0)
   return x;
 }
 return 1;
}
static void inf_stkeep(struct inf_rd *r, struct inf_ms *s) {
 unsigned int lw = 15, lim = 16;
 uintptr_t k;
 if (1u << lw <= r->op) {
  memcpy(s->hist + 0, r->out + (r->op - (1u << lw)), 1u << lw);
  s->hlen = 1u << lw;
 } else {
  if (1u << lim < s->hlen + r->op) {
   if (s->hlen < 1u << lw) {
    k = s->hlen;
   } else {
    k = 1u << lw;
   }
   memmove(s->hist + 0, s->hist + (s->hlen - k), k);
   s->hlen = k;
  }
  memcpy(s->hist + s->hlen, r->out + 0, r->op);
  s->hlen += r->op;
 }
}
static int inf_stfeed(struct inf_rd *r, struct inf_ms *s, uint8_t const *in, uintptr_t nin) {
 unsigned int lim = 30, lw = 15, lh = 16;
 int x;
 uintptr_t ncap;
 uint8_t *nb;
 r->out = 0;
 r->ip = 0;
 r->op = 0;
 r->cap = 0;
 if ((uintptr_t) -1 - 8 < nin)
  return -3;
 if (1u << lh < s->hlen)
  return -3;
 if (s->hlen < 1u << lw) {
  r->nd = s->hlen;
 } else {
  r->nd = 1u << lw;
 }
 r->dic = s->hist + (s->hlen - r->nd);
 r->in = in;
 r->n = nin;
 if (nin <= 1u << lh) {
  r->cap = (nin << 1 << 1) + (1u << 12);
 } else {
  r->cap = 1u << lh;
 }
 r->out = alloc(0, r->cap);
 if (!r->out)
  return -2;
 while (1) {
  x = inf_ststep(r, s);
  if (x != -2)
   break;
  if (1u << lim <= r->cap)
   break;
  if (r->cap < (1u << lim) - r->cap) {
   ncap = r->cap << 1;
  } else {
   ncap = 1u << lim;
  }
  nb = alloc(0, ncap);
  if (!nb)
   break;
  memcpy(nb + 0, r->out + 0, r->op);
  alloc(r->out, 0);
  r->out = nb;
  r->cap = ncap;
 }
 inf_stkeep(r, s);
 return x;
}
