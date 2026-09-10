/* brace elision (C 6.7.9): a flat initializer run fills nested subaggregates
   whose braces were omitted -- int a[2][2] = {1,2,3,4} means {{1,2},{3,4}}.
   global + local, arrays + structs, deep nesting, [] row inference, and a
   partial run (the tail zero-fills). exit agrees with gcc only if every
   elided layout matches the reference. */
int ga[2][2] = { 1, 2, 3, 4 };                 /* {{1,2},{3,4}} */
int gd[][2] = { 1, 2, 3, 4, 5, 6 };            /* 3 rows inferred */
int gt[2][2][2] = { 1, 2, 3, 4, 5, 6, 7, 8 };  /* deep nesting */
struct P { int x, y; };
struct P gp[2] = { 10, 20, 30, 40 };           /* struct-array elision */

int main(void)
{
  int la[2][2] = { 5, 6, 7, 8 };               /* local elided */
  int part[2][2] = { 1, 2, 3 };                /* partial: part[1][1] == 0 */

  int rows = (int)(sizeof(gd) / sizeof(gd[0])); /* 3 */

  /* ga: 1+2+3+4 = 10 ; gt[1][0][1]=6, gt[1][1][1]=8 ; gp[1].x=30, gp[1].y=40
     la[1][1]=8, part[1][0]=3, part[1][1]=0 */
  return (ga[0][0] + ga[0][1] + ga[1][0] + ga[1][1])   /* 10 */
       + rows                                          /* 3  -> 13 */
       + (gt[1][0][1] + gt[1][1][1])                   /* 14 -> 27 */
       + (gp[1].x + gp[1].y)                           /* 70 -> 97 */
       + la[1][1]                                      /* 8  -> 105 */
       + part[1][0] + part[1][1];                      /* 3+0 -> 108 */
}
