// inf_gen.h -- laid by src/love/compress/inf.l, `make mx`. edit that file.
static inline int inf_walk(struct inf_code const *c, uint64_t bb) {
 int code = 0, first = 0, index = 0, cnt;
 unsigned int l;
 for (l = 1; l < 16; l++) {
  code |= (int) ((bb >> (l - 1)) & 1);
  cnt = c->cnt[l];
  if (code - cnt < first)
   return (int) c->sym[index + (code - first)] << 4 | (int) l;
  index += cnt;
  first = (first + cnt) << 1;
  code <<= 1;
 }
 return -1;
}
static inline void inf_build(struct inf_code *c, uint8_t const *lens, unsigned int nsym, uint16_t *sym, uint16_t *tab, unsigned int root) {
 unsigned int ofs[16];
 unsigned int l, i, code = 0, idx = 0;
 unsigned int size = 1u << root;
 memset(c->cnt, 0, sizeof(c->cnt));
 memset(ofs, 0, sizeof(ofs));
 memset(sym, 0, (size_t) nsym * sizeof(*sym));
 memset(tab, 0, (size_t) size * sizeof(*tab));
 for (i = 0; i < nsym; i++)
  c->cnt[lens[i]]++;
 c->cnt[0] = 0;
 for (l = 1; l < 15; l++)
  ofs[l + 1] = ofs[l] + c->cnt[l];
 for (i = 0; i < nsym; i++)
  if (lens[i]) {
   sym[ofs[lens[i]]] = (uint16_t) i;
   ofs[lens[i]]++;
  }
 c->sym = sym;
 c->tab = tab;
 c->root = root;
 for (l = 1; l < 16; l++) {
  for (i = 0; i < c->cnt[l]; i++) {
   unsigned int s = sym[idx], rev = 0, b, j;
   idx++;
   if (l <= root) {
    for (b = 0; b < l; b++)
     rev = rev << 1 | ((code >> b) & 1);
    for (j = rev; j < size; j += 1u << l)
     if (!tab[j])
      tab[j] = (uint16_t) (s << 4 | l);
   }
   code++;
  }
  code <<= 1;
 }
}
