/* __sync_lock_test_and_set (sized and signed by the pointee), __sync_lock_release,
 * 32-bit __builtin_clz/ctz. each check adds 1: the exit code is the pass count. */

extern int printf(const char *, ...);

int lock = 0;
long wide = 0;
long *plk = 0;
unsigned bits = 0x00010000u;

int main(void)
{
	int r = 0;
	r += __sync_lock_test_and_set(&lock, 1) == 0 && lock == 1;
	r += __sync_lock_test_and_set(&lock, 5) == 1 && lock == 5;
	__sync_lock_release(&lock);
	r += lock == 0;
	r += __sync_lock_test_and_set(&lock, -1) == 0;
	r += __sync_lock_test_and_set(&lock, 0) == -1;   /* the sign rides out */
	r += __sync_lock_test_and_set(&wide, -7L) == 0 && wide == -7L;
	r += __sync_lock_test_and_set(&plk, &wide) == 0 && *plk == -7L;
	__sync_lock_release(&wide);
	r += wide == 0;
	r += __builtin_clz(bits) == 15 && __builtin_ctz(bits) == 16;
	r += __builtin_clz(1u) == 31 && __builtin_ctz(0x80000000u) == 31;
	r += __builtin_clz(0xffffffffu) == 0 && __builtin_ctz(1u) == 0;
	return r;
}
