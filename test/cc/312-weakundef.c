/* a weak symbol no object defines: its address is 0, in code and in a named section, and a
 * present one beside it still reads */
typedef struct { long g; void *p; } tab;
extern __attribute__((weak)) const tab tabs[];
extern __attribute__((weak)) int absent;
extern __attribute__((weak)) int absentfn(int);
__attribute__((weak)) int present = 7;

static const tab *gettabs(void) { return tabs; }
__attribute__((section(".text.weakprobe"))) static int readabsent(void) { return &absent ? absent : -1; }

int main(void)
{
  int ok = (gettabs() == 0) + 2 * (readabsent() == -1) + 4 * (absentfn == 0) + 8 * (present == 7);
  return 40 + ok;   /* 55 */
}
