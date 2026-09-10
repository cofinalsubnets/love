/* the data tail, love.c-shaped: arrays of unions/structs holding function
   pointers, labels under integer casts ((word)f -- the nif/def tables), NULL
   members, and macro-computed constants ((Bits>>3), putcharm) folding into
   images. */
#define NULL ((void*)0)
#define Bits 64
#define Bytes (Bits>>3)
#define putcharm(_) ((unsigned long)(((unsigned long)(_)<<1)|1))
typedef unsigned long word;
typedef int (*op)(int);

static int inc(int x) { return x + 1; }
static int dbl(int x) { return x * 2; }

union u { op f; word x; };
static union u const tab[] = { {inc}, {.x=putcharm(2)}, {dbl}, {NULL} };

struct def { char const *n; word x; };
static struct def const defs[] = { { "inc", (word)inc }, { "dbl", (word)dbl } };

static unsigned long T[] = { [0]=Bytes, [2]=2*Bytes };

int main(void)
{
  int s = (int)tab[1].x;                    /* 5 */
  s += tab[0].f(10);                        /* + 11 = 16 */
  s += ((op)defs[1].x)(3);                  /* + 6 = 22 */
  s += defs[0].n[0] == 'i' ? 4 : 0;         /* + 4 = 26 */
  s += tab[3].f == NULL ? 0 : 100;
  s += (int)(T[0] + T[1] + T[2]);           /* + 8 + 0 + 16 = 50 */
  return s - 8;                             /* 42 */
}
