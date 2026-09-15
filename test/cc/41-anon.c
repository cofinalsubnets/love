struct v { int kind; union { long n; char c; }; };
int main() { struct v a; a.kind = 1; a.n = 300; struct v b; b.kind = 2; b.c = 7;
  return a.kind + b.kind + (a.n == 300) + b.c + sizeof(struct v); }
