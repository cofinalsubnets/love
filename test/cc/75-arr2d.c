/* stage 7c-iii part 2: multidimensional arrays -- nested (arr (arr T n) m)
   types, row-major layout, [i][j] indexing scaled by the element stride, and
   nested-brace initializers for a global 2D table. exit = a mix that only
   agrees with gcc if the layout and the pointer arithmetic both match. */
int g[3][4] = { {1,2,3,4}, {10,20,30,40}, {100,101,102,103} };
int gi[][2] = { {1,1}, {2,2}, {3,3} };   /* outer dim inferred from the init: 3 */

int rowsum(int i)
{
  int s = 0;
  int j = 0;
  while (j < 4) { s = s + g[i][j]; j = j + 1; }
  return s;
}

int main(void)
{
  int a[3][4];
  int i = 0;
  while (i < 3) {
    int j = 0;
    while (j < 4) { a[i][j] = i * 4 + j; j = j + 1; }
    i = i + 1;
  }
  /* a[2][3] = 11, a[1][0] = 4; g row 1 sums to 100, g[2][3] = 103; gi[2][1] = 3 */
  return a[2][3] + a[1][0] + (rowsum(1) - 100) + (g[2][3] - 100) + (gi[2][1] - 3);
}
