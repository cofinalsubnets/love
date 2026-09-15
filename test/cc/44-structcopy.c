struct P { int x; int y; long z; };
int main() {
  struct P a; a.x = 3; a.y = 4; a.z = 5;
  struct P b;
  b = a;
  b.x = 10;
  return a.x + b.x + b.y + b.z;
}
