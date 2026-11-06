// inf_run_gen.h -- laid by src/love/compress/inf.l, `make mx`. edit that file.
static const uint16_t gz_lbase[29] = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 };
static const uint8_t gz_lext[29] = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
static const uint16_t gz_dbase[30] = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
static const uint8_t gz_dext[30] = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };
static const uint8_t gz_clord[19] = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
// table roots: a longer code walks bits, so these trade 2^root fill writes against walks
#define LROOT 12
#define DROOT 9
#define CROOT 7
// one block's decode tables, 10 KB on inf_run's frame (see inf_rund): the kernel's 64 KiB boot
// stack inflates with it
struct inf_tabs {
 uint16_t ltab[1 << LROOT], dtab[1 << DROOT], ctab[1 << CROOT], lsym[288], dsym[32], csym[19];
 struct inf_code lit, dst, cl; };
// a stream being read, and where its bytes go: bc bits of bb buffered, ip read so far;
// dic the preset dictionary behind the output, nd 0 for none
struct inf_rd {
 const uint8_t *in, *dic;
 uint8_t *out;
 struct inf_tabs *t;
 uintptr_t n, ip, op, cap, nd;
 uint64_t bb;
 unsigned bc; };
static inline void inf_fill(struct inf_rd *r) {
 if (r->ip + 8 <= r->n) {
  r->bb |= LD64(r->in + r->ip) << r->bc;
  r->ip += 7 - (r->bc >> 3);
  r->bc |= 56;
 } else {
  while (r->ip < r->n) {
   if (55 < r->bc)
    break;
   r->bb |= (uint64_t) r->in[r->ip] << r->bc;
   r->ip++;
   r->bc += 8;
  }
 }
}
static inline int inf_take(struct inf_rd *r, unsigned int k) {
 int v;
 inf_fill(r);
 if (r->bc < k)
  return -1;
 v = r->bb & ((1u << k) - 1);
 r->bb >>= k;
 r->bc = r->bc - k;
 return v;
}
static inline int inf_sym(struct inf_rd *r, struct inf_code const *c, uint16_t const *t, unsigned int root) {
 int e, x, sy;
 unsigned int u;
 inf_fill(r);
 e = t[r->bb & ((1u << root) - 1)];
 if (!e) {
  x = inf_walk(c, r->bb);
  if (x < 0)
   return x;
  e = x;
 }
 sy = e >> 4;
 u = e & 15;
 if (r->bc < u)
  return -1;
 r->bb >>= u;
 r->bc = r->bc - u;
 return sy;
}
static inline int inf_stored(struct inf_rd *r) {
 unsigned int dr, ln, x16, nl;
 uintptr_t pos;
 dr = r->bc & 7;
 r->bb >>= dr;
 r->bc = r->bc - dr;
 pos = r->ip - (r->bc >> 3);
 if (r->n < pos + 4)
  return -1;
 x16 = r->in[pos] | (unsigned int) r->in[pos + 1] << 8;
 ln = x16 & 65535;
 nl = r->in[pos + 2] | (unsigned int) r->in[pos + 2 + 1] << 8;
 if (((ln ^ 65535) & 65535) != nl)
  return -1;
 if (r->n - (pos + 4) < ln)
  return -1;
 if (r->cap - r->op < ln)
  return -2;
 if (r->out) {
  memcpy(r->out + r->op, r->in + (pos + 4), ln);
 }
 r->op += ln;
 r->ip = pos + 4 + ln;
 r->bb = 0;
 r->bc = 0;
 return 0;
}
static inline void inf_fixed(struct inf_rd *r) {
 uint8_t lens[320];
 unsigned int i, v;
 memset(lens, 0, sizeof(lens));
 for (i = 0; i < 288; i++) {
  v = 8;
  if (144 <= i) {
   v = 9;
  }
  if (256 <= i) {
   v = 7;
  }
  if (280 <= i) {
   v = 8;
  }
  lens[i] = v;
 }
 inf_build(&r->t->lit, lens, 288, r->t->lsym, r->t->ltab, LROOT);
 for (i = 0; i < 30; i++)
  lens[i] = 5;
 inf_build(&r->t->dst, lens, 30, r->t->dsym, r->t->dtab, DROOT);
}
static inline int inf_dyn(struct inf_rd *r) {
 uint8_t lens[320];
 uint8_t cl[19];
 unsigned int hlit, hdist, hclen, tot, prev = 0, i, k, rr, v;
 int x, sy;
 x = inf_take(r, 5);
 if (x < 0)
  return x;
 hlit = x + 257;
 x = inf_take(r, 5);
 if (x < 0)
  return x;
 hdist = x + 1;
 x = inf_take(r, 4);
 if (x < 0)
  return x;
 hclen = x + 4;
 memset(cl, 0, sizeof(cl));
 for (i = 0; i < hclen; i++) {
  x = inf_take(r, 3);
  if (x < 0)
   return x;
  cl[gz_clord[i]] = x;
 }
 inf_build(&r->t->cl, cl, 19, r->t->csym, r->t->ctab, CROOT);
 memset(lens, 0, sizeof(lens));
 tot = hlit + hdist;
 i = 0;
 while (i < tot) {
  sy = inf_sym(r, &r->t->cl, r->t->ctab, CROOT);
  if (sy < 0)
   return sy;
  if (sy < 16) {
   rr = 1;
   v = sy;
  } else {
   if (18 < sy)
    return -1;
   if (sy <= 16) {
    x = inf_take(r, 2);
    if (x < 0)
     return x;
    rr = x + 3;
    v = prev;
   } else {
    if (sy <= 17) {
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
   if (i + k < 320)
    lens[i + k] = v;
  i += rr;
  prev = v;
 }
 inf_build(&r->t->lit, lens, hlit, r->t->lsym, r->t->ltab, LROOT);
 inf_build(&r->t->dst, lens + hlit, hdist, r->t->dsym, r->t->dtab, DROOT);
 return 0;
}
static inline void inf_copy(struct inf_rd *r, uintptr_t l, uintptr_t d) {
 uintptr_t k = 0, m;
 if (r->op < d) {
  m = l;
  if (d - r->op < l) {
   m = d - r->op;
  }
  memcpy(r->out + r->op, r->dic + (r->nd - (d - r->op)), m);
  for (k = m; k < l; k++)
   r->out[r->op + k] = r->out[r->op + k - d];
 } else {
  if (wideld && 8 <= d) {
   while (k + 8 <= l) {
    ST64(r->out + (r->op + k), LD64(r->out + (r->op + k - d)));
    k += 8;
   }
  }
  while (k < l) {
   r->out[r->op + k] = r->out[r->op + k - d];
   k++;
  }
 }
}
static int inf_fast_run(struct inf_rd *r) {
 uint8_t const *in = r->in, *dic = r->dic;
 uint8_t *out = r->out;
 uint16_t const *lt = r->t->ltab, *dt = r->t->dtab;
 uint64_t bb = r->bb;
 uintptr_t ip = r->ip, op = r->op, bc = r->bc, e, f, sy, x, l, d, k, dd, y;
 int ans = 0;
 while (op + 266 <= r->cap) {
  if (bc < 15) {
   if (r->n < ip + 8)
    break;
   bb |= LD64(in + ip) << bc;
   ip += 7 - (bc >> 3);
   bc |= 56;
  }
  e = lt[bb & ((1u << LROOT) - 1)];
  if (!e)
   break;
  sy = e >> 4;
  if (sy < 256) {
   bb >>= e & 15;
   bc = bc - (e & 15);
   out[op] = (uint8_t) sy;
   op++;
  } else {
   if (sy <= 256) {
    bb >>= e & 15;
    bc = bc - (e & 15);
    ans = 1;
    break;
   }
   if (285 < sy)
    return -1;
   if (bc < 48) {
    if (r->n < ip + 8)
     break;
    bb |= LD64(in + ip) << bc;
    ip += 7 - (bc >> 3);
    bc |= 56;
   }
   x = gz_lext[sy - 257];
   y = bb >> ((e & 15) + x);
   f = dt[y & ((1u << DROOT) - 1)];
   if (!f)
    break;
   bb >>= e & 15;
   bc = bc - (e & 15);
   l = gz_lbase[sy - 257] + (bb & ((1u << x) - 1));
   bb >>= x;
   bc = bc - x;
   bb >>= f & 15;
   bc = bc - (f & 15);
   sy = f >> 4;
   if (29 < sy)
    return -1;
   x = gz_dext[sy];
   d = gz_dbase[sy] + (bb & ((1u << x) - 1));
   bb >>= x;
   bc = bc - x;
   if (op < d) {
    if (op + r->nd < d)
     return -1;
    dd = l;
    if (d - op < l) {
     dd = d - op;
    }
    memcpy(out + op, dic + (r->nd - (d - op)), dd);
    for (k = dd; k < l; k++)
     out[op + k] = out[op + k - d];
   } else {
    k = 0;
    if (wideld && 8 <= d) {
     while (k < l) {
      ST64(out + (op + k), LD64(out + (op + k - d)));
      k += 8;
     }
    } else {
     if (wideld && d == 1) {
      while (k < l) {
       ST64(out + (op + k), (uint64_t) 72340172838076673 * (uint64_t) out[op - d]);
       k += 8;
      }
     } else {
      while (k < l) {
       out[op + k] = out[op + k - d];
       k++;
      }
     }
    }
   }
   op += l;
  }
 }
 r->ip = ip;
 r->op = op;
 r->bb = bb;
 r->bc = bc;
 return ans;
}
static inline int inf_block(struct inf_rd *r) {
 int x, y, sy, sd;
 uintptr_t l, d;
 while (1) {
  if (r->out) {
   if (r->ip + 8 <= r->n)
    if (r->op + 266 <= r->cap) {
     x = inf_fast_run(r);
     if (x < 0)
      return x;
     if (x)
      break;
    }
  }
  sy = inf_sym(r, &r->t->lit, r->t->ltab, LROOT);
  if (sy < 0)
   return sy;
  if (sy < 256) {
   if (r->cap <= r->op)
    return -2;
   if (r->out) {
    r->out[r->op] = (uint8_t) sy;
   }
   r->op++;
  } else {
   if (sy <= 256)
    break;
   if (285 < sy)
    return -1;
   l = gz_lbase[sy - 257];
   x = inf_take(r, gz_lext[sy - 257]);
   if (x < 0)
    return x;
   l += x;
   sd = inf_sym(r, &r->t->dst, r->t->dtab, DROOT);
   if (sd < 0)
    return sd;
   if (29 < sd)
    return -1;
   d = gz_dbase[sd];
   y = inf_take(r, gz_dext[sd]);
   if (y < 0)
    return y;
   d += y;
   if (r->op + r->nd < d)
    return -1;
   if (r->cap - r->op < l)
    return -2;
   if (r->out) {
    inf_copy(r, l, d);
   }
   r->op += l;
  }
 }
 return 0;
}
static int64_t inf_go(struct inf_rd *r) {
 int x, last = 0, typ;
 while (!last) {
  last = inf_take(r, 1);
  if (last < 0)
   return last;
  typ = inf_take(r, 2);
  if (typ < 0)
   return typ;
  if (!typ) {
   x = inf_stored(r);
   if (x < 0)
    return x;
  } else {
   if (3 <= typ)
    return -1;
   if (typ <= 1) {
    inf_fixed(r);
   } else {
    x = inf_dyn(r);
    if (x < 0)
     return x;
   }
   x = inf_block(r);
   if (x < 0)
    return x;
  }
 }
 return r->op;
}
static int64_t inf_start(struct inf_rd *r) {
 int64_t x;
 if ((uintptr_t) -1 - 8 < r->n)
  return -1;
 if ((uintptr_t) -1 - 266 < r->cap)
  return -1;
 if ((uintptr_t) -1 - r->nd < r->cap)
  return -1;
 r->ip = 0;
 r->bc = 0;
 r->bb = 0;
 r->op = 0;
 x = inf_go(r);
 if (x < 0)
  return x;
 return x;
}
