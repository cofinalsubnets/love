/* __builtin_frame_address and __builtin_return_address above level 0 walk the frame chain,
 * as gcc's do: a callee's level 1 is its caller's level 0, and two frames up is level 2.
 * (the kernel's kunwind_init_from_caller reads frame_address(1).) */
static int hits;
__attribute__((noinline)) void *fa1(void) { return __builtin_frame_address(1); }
__attribute__((noinline)) void *ra1(void) { return __builtin_return_address(1); }
__attribute__((noinline)) void *fa2(void) { return __builtin_frame_address(2); }
/* a frame of its own between mid and fa2; the work after the call keeps it from being a tail call */
__attribute__((noinline)) void *h(void)
{
    void *r = fa2();
    hits += __builtin_frame_address(0) != 0;
    return r;
}

__attribute__((noinline)) int mid(void)
{
    void *mine = __builtin_frame_address(0), *back = __builtin_return_address(0);
    int ok = fa1() == mine;
    ok = ok * 2 + (ra1() == back);
    ok = ok * 2 + (h() == mine);
    return ok * 10 + hits;
}

int main(void) { return mid(); }   /* 71: all three, and h ran once */
