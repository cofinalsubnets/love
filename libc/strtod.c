double strtod(char const *restrict s, char **restrict end) {
 char const *p = s;
 int sign = 1;
 if (*p == '-') sign = -1, p++;
 else if (*p == '+') p++;
 int any = 0;
 double v = 0;
 while ('0' <= *p && *p <= '9') v = v * 10 + (*p++ - '0'), any = 1;
 if (*p == '.') {
  p++;
  double scale = 0.1;
  while ('0' <= *p && *p <= '9') v += (*p++ - '0') * scale, scale *= 0.1, any = 1; }
 if (!any) { if (end) *end = (char*) s; return 0; }
 if (*p == 'e' || *p == 'E') {
  char const *q = p++;
  int esign = 1;
  if (*p == '-') esign = -1, p++;
  else if (*p == '+') p++;
  if (!('0' <= *p && *p <= '9')) p = q; // not a real exponent
  else {
   int e = 0;
   while ('0' <= *p && *p <= '9') e = e * 10 + (*p++ - '0');
   double scale = 1;
   while (e--) scale *= 10;
   v = esign > 0 ? v * scale : v / scale; } }
 if (end) *end = (char*) p;
 return sign * v; }
