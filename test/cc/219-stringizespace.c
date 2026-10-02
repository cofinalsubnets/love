/* # spells an argument with the source's own spacing (C11 6.10.3.2): one space where
 * the argument had any whitespace between two tokens, none where it had none, and
 * none at either end. the kernel's __stringify of asm text leans on it -- ".pushsection"
 * spelled ". pushsection" is no directive. */

#include <string.h>

#define S_(x) #x
#define S(x) S_(x)
#define SV_(...) #__VA_ARGS__
#define SV(...) SV_(__VA_ARGS__)
#define SEC .pushsection .rodata.str,"aMS",%progbits,1; 1: .long 1b - .;

static int same(const char *a, const char *b) { return strcmp(a, b) == 0; }

int main(void)
{
    if (!same(S_(a.b c . d), "a.b c . d")) return 1;
    if (!same(S_(  x+1  ), "x+1")) return 2;
    if (!same(S_(f(x,y)), "f(x,y)")) return 3;
    if (!same(S_(p -> q), "p -> q")) return 4;
    if (!same(S_(a/* a comment */b), "a b")) return 5;
    if (!same(S_(a
                 b), "a b")) return 6;
    if (!same(S_(.pushsection x), ".pushsection x")) return 7;
    if (!same(SV(SEC), ".pushsection .rodata.str,\"aMS\",%progbits,1; 1: .long 1b - .;")) return 8;
    if (!same(SV_(a,b, c), "a,b, c")) return 9;
    return 0;
}
