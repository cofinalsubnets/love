union U { long l; int i; char c; };
int main() { union U u; u.l = 0; u.i = 258; return u.c + sizeof(union U); }
