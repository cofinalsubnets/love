int main() { long a[8]; long *p = &a[6]; long *q = &a[2]; return (p - q)*10 + (q < p); }
