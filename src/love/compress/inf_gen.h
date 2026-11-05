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
