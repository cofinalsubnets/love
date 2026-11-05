/* an element's field past an indexed address: a displacement no one load or store can encode */
struct __attribute__((packed)) rec {
  char pad[1164];
  unsigned long long u;
  double d;
  float f;
  char tail[5007];
  unsigned char b;
};

__attribute__((noinline)) void put(struct rec *p, long i, unsigned long long u, double d, float f) {
  p[i].u = u;
  p[i].d = d;
  p[i].f = f;
  p[i].b = (unsigned char)u;
}

__attribute__((noinline)) double get(struct rec *p, long i) {
  return p[i].d + p[i].f;
}

static struct rec r[2] __attribute__((aligned(8)));

int main(void) {
  put(r, 1, 0x1122334455667788ULL, 1.5, 2.25f);
  if (r[1].u != 0x1122334455667788ULL) return 1;
  if (get(r, 1) != 3.75) return 2;
  if (r[1].b != 0x88 || r[0].b != 0) return 3;
  return 0;
}
