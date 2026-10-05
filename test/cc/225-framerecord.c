/* the frame record: [fp] the caller's fp, [fp+8] the return address, walked two deep */
static void *mid_ra;

__attribute__((noinline)) static int leaf(void) {
#if defined(__aarch64__) || defined(__x86_64__)
    void **fp = __builtin_frame_address(0);
    void **up = fp[0];
    return fp[1] == __builtin_return_address(0) && up[1] == mid_ra;
#else
    return 1;
#endif
}

__attribute__((noinline)) static int mid(void) {
#if defined(__aarch64__) || defined(__x86_64__)
    mid_ra = __builtin_return_address(0);
#endif
    return leaf() + 1;
}

int main(void) {
    return mid() == 2 ? 0 : 1;
}
