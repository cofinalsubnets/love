/* a value loaded into a callee-saved home and copied straight out as a call's argument is still
 * there after the call: on arm a call kills none of r4-r11, so the load may not skip the home */
struct node { struct node *next; int key; int val; };

__attribute__((noinline)) int pick(int a, int b, int c, int d) { return a * 3 + b - c + d; }
__attribute__((noinline)) int bump(int x) { return x + 1; }

__attribute__((noinline)) int walk(struct node **pp, int k)
{
  struct node *p = *pp, *q = p->next;
  int a = p->key, b = p->val, c = q->key, d = q->val;
  int e = q->next->key;
  int r = pick(e, a, b, k);
  r += bump(c);
  r += pick(d, e, a, b);
  return r + a + b + c + d + e;
}

int main(void)
{
  struct node n3 = { 0, 7, 70 }, n2 = { &n3, 5, 50 }, n1 = { &n2, 3, 30 }, *h = &n1;
  int r = walk(&h, 2);
  /* pick(7,3,30,2) = 21+3-30+2 = -4; bump(5) = 6; pick(50,7,3,30) = 150+7-3+30 = 184; 3+30+5+50+7 = 95 */
  return r == -4 + 6 + 184 + 95 ? 55 : 1;
}
