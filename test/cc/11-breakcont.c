int main() { int s=0; for (int i=0;i<10;i++){ if (i==7) break; if (i%2) continue; s+=i; } return s; }
