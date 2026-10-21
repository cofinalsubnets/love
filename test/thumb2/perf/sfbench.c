/* instructions per soft f64 op on qemu M4: dm, da and ds stepped entry to return by perf.sh count */
double lm_sin(double);
volatile double va = 1.2345678901, vb = 2.7182818284, vr;
__attribute__((noinline)) double dm(double a, double b){ return a * b; }
__attribute__((noinline)) double da(double a, double b){ return a + b; }
__attribute__((noinline)) double ds(double a){ return lm_sin(a); }
volatile int vk;
__attribute__((noinline)) void mark(int k){ vk = k; }
int run(void){ mark(0); vr = dm(va, vb); mark(1); vr = da(va, vb); mark(2); vr = ds(va); mark(3); return 0; }
