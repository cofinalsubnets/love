struct node { long v; struct node *next; };
int main() { struct node c; struct node b; struct node a;
  a.v = 1; b.v = 2; c.v = 4;
  a.next = &b; b.next = &c; c.next = (struct node*)0;
  long s = 0; struct node *p = &a;
  while (p) { s += p->v; p = p->next; }
  return s*10 + sizeof(struct node)/8; }
