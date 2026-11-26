/* names what moved: built by the side that links, never by the pair under test */
#include <stdio.h>
typedef unsigned long ul;
typedef union { ul u; float f; double d; } cell;
#include "report.h"
static int nbad, nck;
void keep(void *p) { (void)p; }
/* side 0 the callee, its arguments. 1 the caller, its arguments again and the answer. 2 the answer */
void ck(int q, int side, int n) {
  nck++;
  for (int i = side == 2 ? at[q].na : 0; i < n; i++) {
    ul want = V[at[q].at + i].u, got = G[i].u;
    const short *w = wh[at[q].at + i];
    if (got == want) continue;
    nbad++;
    printf("sig %d ", q);
    if (w[0] == 99) printf("answer");
    else printf(side ? "arg %d, the caller's after the call," : "arg %d", w[0]);
    printf(" word %d got %016lx want %016lx: %s\n", w[1], got, want, sigs[q]);
  }
  for (int i = 0; i < n; i++) G[i].u = 0;
}
/* the linker names the group and its count, so one object serves every group */
#ifdef RUN
extern void RUN(void);
#else
extern void run(void);
extern char ncalls[];
#define RUN run
#define NCK (long)ncalls
#endif
int main(void) { RUN(); return nbad != 0 || nck != NCK; }
