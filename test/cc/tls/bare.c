/* no libc call reaches the startup, yet the template owes it: the first thread's copy */
int tls_sum(void);

int main(void) { return tls_sum() == 6107 ? 0 : 1; }
