struct Pt { int x; int y; int z; };
int main() {
  struct Pt a = {1, 2, 3};
  struct Pt b = {.z = 9, .x = 4};
  return a.x + a.y + a.z + b.x + b.z + b.y;
}
