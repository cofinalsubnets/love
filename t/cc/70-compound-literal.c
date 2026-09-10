/* compound literals: an unnamed object from (type){ init }. its address is an
   lvalue -- the love.c `&(struct ai_r){..}` shape -- and it reads as a value. */
struct P { int a; int b; };
int psum(struct P *p) { return p->a + p->b; }
struct P *idp(struct P *p) { return p; }
int main() {
  int r = psum(&(struct P){10, 15});         /* pass a compound literal's address: 25 */
  int *q = &(int){12};                        /* a scalar compound literal, address taken */
  r = r + *q;                                 /* 37 */
  struct P *p = idp(&(struct P){3, 2});       /* stored through a call, then read */
  r = r + p->a + p->b;                        /* 42 */
  return r;
}
