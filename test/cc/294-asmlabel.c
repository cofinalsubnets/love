/* an asm label names the symbol a file-scope declaration is laid as: two C names under one
 * label are one object, in any spelling (asm, __asm__, __asm, adjacent strings), and a label
 * that repeats the name (the kernel's ret_from_fork) changes nothing. */
int impl(int x) __asm__("lab_impl");
int impl(int x) { return x * 3; }
extern int other(int) __asm__("lab_impl");

int counter __asm__("lab_ctr") = 7;
extern int ctr2 __asm__("lab_ctr");

int twice(int) asm("lab_twice");
int twice(int x) { return 2 * x; }
extern int twice2(int) __asm("lab_twice");

int add1(int) __asm__("" "lab_add1");
int add1(int x) { return x + 1; }
extern int add1b(int) __asm__("lab_" "add1");

void same(void) asm("same");
void same(void) { counter++; }

int main(void)
{
    same();
    ctr2 += 2;
    return other(5) + counter + twice2(4) + add1b(1);   /* 15 + 10 + 8 + 2 */
}
