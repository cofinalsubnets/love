/* the landing law's units (test/gate/ccarch.sh): built by clang and by mooncc under
   -mbranch-protection=pac-ret+bti -mstrict-align, each fn's landing, its exits and every
   packed access held to clang's */
struct __attribute__((packed)) pk { char c; int i; long l; short s; };
extern int ext(int);

int leaf(int a) { return a * 3 + 1; }                                    /* bti c */
int caller(int a) { return ext(a) + ext(a + 1); }                        /* paciasp */
__attribute__((noinline)) static int hidden(int a) { return a ^ 0x55; } /* no address taken: neither */
__attribute__((noinline)) static int taken(int a) { return a - 7; }     /* its address escapes: bti c */
int (*tp)(int) = taken;
int usehidden(int a) { return hidden(a) + hidden(a + 2); }               /* paciasp */
int sib(int a) { int t = ext(a); return ext(t + 1); }                    /* autiasp before the tail b */
int pick(int k, int x) {                                                 /* a table: bti j at each arm */
    switch (k) { case 0: return x + 11; case 1: return x * 7; case 2: return x - 5;
                 case 3: return x ^ 9; case 4: return x << 2; case 5: return x / 3; default: return -1; }
}

int pk_rd(struct pk *p) { return p->i; }
long pk_rdl(struct pk *p) { return p->l; }
void pk_wr(struct pk *p, int v) { p->i = v; }
void pk_wrl(struct pk *p, long v) { p->l = v; }
void pk_step(struct pk *p) { p->s++; p->i += 3; }
