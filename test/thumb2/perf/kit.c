/* pooled values against a kit that spells r2, r3 (pair ops, soft doubles, divides); run() 0 = all held */
typedef unsigned long long u64;
struct s { int a, b; };
int pw(struct s *p, u64 x, u64 y){ return p->a + (int)(x * y); }
int pd(struct s *p, double x, double y){ return p->a + (int)(x * y); }
int pv(struct s *p, int x, int y){ return p->a + x / y; }
int pm(struct s *p, unsigned x, unsigned y){ return p->b - (int)(x % y); }
void st(int *q, u64 x, u64 y){ *q = (int)(x + y); }
void sd(int *q, double x, double y){ q[1] = (int)(x / y); }
long long sh(struct s *p, u64 x, int n){ return p->a + (long long)(x << n); }
int cm(struct s *p, u64 x, u64 y){ return p->a < 3 && x < y; }
int run(void){ struct s v = {5, 9}; int q[2];
  if (pw(&v, 3, 7) != 26) return 1;
  if (pd(&v, 1.5, 4.0) != 11) return 2;
  if (pv(&v, 20, 3) != 11) return 3;
  if (pm(&v, 20, 7) != 3) return 4;
  st(q, 1ull<<33 | 4, 5); if (q[0] != 9) return 5;
  sd(q, 9.0, 2.0); if (q[1] != 4) return 6;
  if (sh(&v, 3, 4) != 53) return 7;
  if (cm(&v, 1, 2) != 0) return 8;
  return 0; }
