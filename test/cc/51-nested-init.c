struct Rec { int k; int v; };
struct Rec recs[3] = {{1, 100}, {2, 200}, {.v = 44, .k = 3}};
int main() {
  int s = 0; int i = 0;
  while (i < 3) { s = s + recs[i].k + recs[i].v; i = i + 1; }
  return s - 300;
}
