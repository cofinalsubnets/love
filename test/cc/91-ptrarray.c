/* pointer to array -- a parenthesized declarator (*p) with a trailing array
   suffix: int (*p)[3] is a pointer to array[3] of int, distinct from int *p[3]
   (an array of pointers). (*p)[i] derefs to the array then indexes; p+1 strides
   by the whole array; &a of an array yields the pointer-to-array. also the
   array-of-pointer-to-array form int (*q[2])[3]. exit agrees with gcc only if
   the declarator types, the deref, and the pointer stride all match. */
int g2[2][3] = { {1,2,3}, {4,5,6} };

int firstrow(int (*p)[3]) { return (*p)[0] + (*p)[1] + (*p)[2]; }   /* param ptr-to-array */

int main(void)
{
  int a[3] = { 10, 20, 30 };
  int (*p)[3] = &a;                 /* pointer to array[3] */
  int s = (*p)[0] + (*p)[2];        /* 40 */

  int (*w)[3] = g2;                 /* walk a 2D array by rows */
  int rows = (*w)[1] + (*(w + 1))[2];   /* 2 + 6 = 8 -> stride is 3 ints */

  int b[3] = { 1, 1, 1 }, c[3] = { 2, 2, 2 };
  int (*q[2])[3] = { &b, &c };      /* array[2] of pointer-to-array */
  int qs = (*q[0])[0] + (*q[1])[2]; /* 1 + 2 = 3 */

  (*p)[1] = 5;                      /* write through the pointer-to-array */

  /* 40 + 8 + firstrow(&a)=(10+5+30=45) + 3 = 96 */
  return s + rows + firstrow(&a) + qs;
}
