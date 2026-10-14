/* a loop no path reaches (behind a return, a guard that folds false) holds itself up by its own
 * back edge: it goes, or its calls write a callee-saved register the prologue never saved. a
 * block reached only by a jump that comes later in the function stays. */
static long seen;
__attribute__((noinline)) long sink(long v) { seen += v; return v * 3; }
static inline int enabled(void) { return 0; }

void after_ret(long n)
{
    long i;
    return;
    for (i = 0; i < n; i++) sink(i);
}

long guarded(long n)
{
    long i, s = 0;
    if (!enabled()) return 7;
    for (i = 0; i < n; i++) s += sink(i);
    return s;
}

long jumped_in(long n)       /* body follows a goto: reached only from the test below it */
{
    long s = 0, i = 0;
    goto top;
body:
    s += sink(i);
    i++;
top:
    if (i < n) goto body;
    return s;
}

int main(void)
{
    after_ret(5);
    long a = guarded(4), b = jumped_in(5);
    return (int)(a * 100 + b + seen);   /* 7*100 + 30 + 10 */
}
