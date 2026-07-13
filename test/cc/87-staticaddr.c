/* a static initializer may be any CONSTANT ADDRESS EXPRESSION -- a label plus a
 * compile-time byte offset. exercises: &arr[i], the decayed array + const
 * (pointer arithmetic scaled by the element), a const-expr subscript, &struct
 * .member, &arr[i].member (nested), and the bare decay. every pointer is laid
 * as an abs64 relocation with the offset as its addend; gen folds the offset,
 * holo/obj/link carry the addend, so *p reads the right cell. gcc agrees. */
struct pt { int x, y, z; };
static int a[5] = {0, 10, 20, 30, 40};
static struct pt s = {7, 8, 9};
static struct pt arr[3] = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
enum { K = 2 };

static int *p_idx    = &a[3];         /* label + 12  -> 30 */
static int *p_arith  = a + 2;         /* decay + 2*4 -> 20 */
static int *p_kexpr  = &a[K + 1];     /* const-expr index = 3 -> 30 */
static int *p_member = &s.y;          /* &member     -> 8  */
static int *p_nested = &arr[1].z;     /* &arr[i].fld -> 6  */
static int *p_decay  = a;             /* offset 0    -> 0  */
static char *p_str   = "ok" + 1;      /* string label + 1 -> 'k' */

int main(void) {
  int r = 0;
  r += (*p_idx    == 30) * 1;
  r += (*p_arith  == 20) * 2;
  r += (*p_kexpr  == 30) * 4;
  r += (*p_member ==  8) * 8;
  r += (*p_nested ==  6) * 16;
  r += (*p_decay  ==  0) * 32;
  r += (*p_str    == 'k') * 64;
  return r;                            /* 1+2+4+8+16+32+64 = 127 */
}
