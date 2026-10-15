/* attributes where gcc reads them and mooncc had not: a packed run between enum and its tag
 * lays the enum at its smallest width, as a trailing one does; cleanup(f) inside a list of
 * several attributes still runs at every way out of the scope; __FUNCTION__ is __func__. */
enum __attribute__((packed)) small { S0, S1, S2 = 200 };
enum __attribute__((packed)) { A0, A1 };
enum wide { W0, W1 };

static int ran;
static void done(int *p) { ran += *p; }

static int scope(int early)
{
    int a __attribute__((cleanup(done), unused)) = 1;
    {
        int b __attribute__((unused, cleanup(done))) = 10;
        if (early) return 3;
    }
    return 4;
}

static int same(const char *a, const char *b)
{
    while (*a && *a == *b) a++, b++;
    return *a == *b;
}

static int named(void) { return same(__FUNCTION__, "named") && same(__PRETTY_FUNCTION__, __func__); }

int main(void)
{
    enum small s = S2;
    int r = 0;
    r += sizeof s == 1;                  /* 1 */
    r += sizeof(enum small) == 1;        /* 1 */
    r += sizeof A1 == sizeof(int);       /* an enumerator is an int either way: 1 */
    r += sizeof(enum wide) == 4;         /* 1 */
    r += s == 200;                       /* 1 */
    r += scope(1);                       /* 3, both cleanups ran: ran = 11 */
    r += scope(0);                       /* 4, ran = 22 */
    r += ran;                            /* 22 */
    r += named();                        /* 1 */
    return r;                            /* 35 */
}
