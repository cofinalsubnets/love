int classify(int n) { int r = 0; switch (n) { case 1: r += 1; case 2: r += 2; break; case 3: r = 30; break; default: r = 9; } return r; }
int main() { return classify(1)*100 + classify(2)*10 + classify(5) - 9; }
