struct Hdr { int len; int cap; char data[]; };
int main() {
  struct Hdr h;
  h.len = 3; h.cap = 8;
  return sizeof(struct Hdr) + h.len + h.cap;
}
