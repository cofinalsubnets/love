int main() { char buf[8]; char *src = "cat"; int i = 0; while (src[i]) { buf[i] = src[i]; i++; } buf[i] = 0; return buf[0] + buf[2] - 100 + i; }
