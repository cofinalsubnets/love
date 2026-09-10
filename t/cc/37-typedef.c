typedef long word;
typedef struct pt { word x; word y; } pt;
int main() { pt p; p.x = 20; p.y = 22; word s = p.x + p.y; return s; }
