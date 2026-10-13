/* a64 asm operands that take an immediate or a register ("Kr", "Lr", "Ir", "Jr", the kernel's
 * ll/sc cmpxchg spelling): a constant the letter cannot encode (0 as a logical immediate, 4097 as
 * an add) rides a register, one it can is laid in the word. a target with no template here
 * computes the same in C. */
typedef unsigned long long u64;

#if defined(__aarch64__)
#define EORK(a, b) ({ unsigned r_; __asm__("eor %w0, %w1, %w2" : "=r"(r_) : "r"(a), "Kr"((unsigned)(b))); r_; })
#define EORL(a, b) ({ u64 r_; __asm__("eor %0, %1, %2" : "=r"(r_) : "r"(a), "Lr"((u64)(b))); r_; })
#define ADDI(a, b) ({ u64 r_; __asm__("add %0, %1, %2" : "=r"(r_) : "r"(a), "Ir"((u64)(b))); r_; })
#define SUBJ(a, b) ({ u64 r_; __asm__("sub %0, %1, %2" : "=r"(r_) : "r"(a), "Jr"((long long)(b))); r_; })
static inline unsigned eor_old(unsigned v, unsigned old) { return EORK(v, old); }
#else
#define EORK(a, b) ((unsigned)(a) ^ (unsigned)(b))
#define EORL(a, b) ((u64)(a) ^ (u64)(b))
#define ADDI(a, b) ((u64)(a) + (u64)(b))
#define SUBJ(a, b) ((u64)(a) - (u64)(b))
static inline unsigned eor_old(unsigned v, unsigned old) { return v ^ old; }
#endif

int main(void) {
    volatile unsigned w = 0x0f0f1234u;
    volatile u64 x = 0x0123456789abcdefull;
    u64 h = 0;
    h = h * 31 + EORK(w, 0);
    h = h * 31 + EORK(w, 0xff);
    h = h * 31 + EORK(w, 0x12345);
    h = h * 31 + EORK(w, 0xffffffffu);
    h = h * 31 + EORL(x, 0);
    h = h * 31 + EORL(x, 0x5555555555555555ull);
    h = h * 31 + EORL(x, 0x1234);
    h = h * 31 + EORL(x, ~0ull);
    h = h * 31 + EORL(x, 0x8000000000000000ull);
    h = h * 31 + ADDI(x, ~0ull);
    h = h * 31 + ADDI(x, 4095);
    h = h * 31 + ADDI(x, 4096);
    h = h * 31 + ADDI(x, 4097);
    h = h * 31 + SUBJ(x, -5);
    h = h * 31 + SUBJ(x, 77);
    h = h * 31 + eor_old(w, 0);
    return h == 0xd7640622d59d3387ull ? 0 : 1;
}
