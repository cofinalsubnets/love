/* stage 7c-iii part 3: the last of love.c's parse tail, end to end vs gcc.
   hex float literals, const-expr array dims, designated initializers with
   enum indices, and a local variable shadowing a typedef name. */
#define NB 64
enum kind { KA, KB, KC, KN };

int mx[KN][KN] = { [KA]={ [KA]=1, [KC]=2 }, [KC]={ [KB]=3 } };  /* designated, nested, enum idx */
int limb[NB / 32];                                             /* const-expr dim = 2 */

typedef long num;               /* love.h's habit: `num` a typedef... */

static int shadowed(void)
{
  num x = 3;                    /* ...used here AS A TYPE */
  long num = 4;                 /* ...and HERE as a local variable that shadows it */
  return (int)(num + num) + (int)x;   /* 8 + 3 = 11 -- num is the variable, not a cast */
}

num typed_still(num a) { return a + 1; }   /* the typedef survives for a sibling: 6 -> 7 */

int main(void)
{
  double h = 0x1.8p1;          /* 1.5 * 2 = 3.0 */
  limb[0] = 5; limb[1] = 9;
  /* mx[0][0]=1, mx[0][2]=2, mx[2][1]=3; shadowed()=11; typed_still(6)=7; (int)h=3 */
  return mx[0][0] + mx[0][2] + mx[2][1] + limb[0] + limb[1] + shadowed() + (int)typed_still(6) + (int)h;
}
