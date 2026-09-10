struct P { int x; int y; };
struct R { struct P a; struct P b; char tag; };
int main() { struct R r; r.a.x = 1; r.a.y = 2; r.b.x = 30; r.b.y = 4; r.tag = 5;
  return r.a.x + r.a.y + r.b.x + r.b.y + r.tag + sizeof(struct R) - 20; }
