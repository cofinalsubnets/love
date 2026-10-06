/* gcc's __atomic and __sync builtins (sqlite's AtomicLoad/AtomicStore, under GCC_VERSION):
 * loads, stores, fences, every read-modify-write in both spellings, exchange, compare-and-swap
 * with its expected value written back, test_and_set/clear. one thread, so the law is the
 * answers; each width runs where the target says it lays it (__GCC_HAVE_SYNC_COMPARE_AND_SWAP_N),
 * a negative operand and a high bit where the exclusive loads widen. exit-code only. */
static int bad;
#define CHECK(b, c) (bad |= !(c) << (b))
#define SEQ __ATOMIC_SEQ_CST
#define RLX __ATOMIC_RELAXED

int main(void)
{
	int i = 5;
	unsigned char c = 200;

	CHECK(0, __atomic_load_n(&i, RLX) == 5);
	__atomic_store_n(&i, 9, SEQ);
	CHECK(0, i == 9 && __atomic_load_n(&i, __ATOMIC_ACQUIRE) == 9);
	__atomic_store_n(&c, 7, __ATOMIC_RELEASE);
	CHECK(0, __atomic_load_n(&c, SEQ) == 7);
	__atomic_thread_fence(SEQ);
	__atomic_signal_fence(SEQ);
	CHECK(0, __ATOMIC_RELAXED == 0 && __ATOMIC_SEQ_CST == 5);
#if __GCC_HAVE_SYNC_COMPARE_AND_SWAP_4
	{
		int e = 41, n = -1, ne = -5, x = -5;
		unsigned u = 0xffffffffu;

		CHECK(1, __atomic_fetch_add(&i, 3, SEQ) == 9 && i == 12);
		CHECK(1, __atomic_sub_fetch(&i, 2, RLX) == 10);
		CHECK(1, __atomic_fetch_and(&i, 6, SEQ) == 10 && i == 2);
		CHECK(1, __atomic_or_fetch(&i, 9, SEQ) == 11);
		CHECK(1, __atomic_xor_fetch(&i, 3, SEQ) == 8);
		CHECK(1, __atomic_nand_fetch(&i, 12, SEQ) == ~(8 & 12) && i == -9);
		CHECK(2, __atomic_exchange_n(&i, 40, SEQ) == -9 && i == 40);
		CHECK(2, !__atomic_compare_exchange_n(&i, &e, 50, 0, SEQ, SEQ) && e == 40 && i == 40);
		CHECK(2, __atomic_compare_exchange_n(&i, &e, 50, 1, SEQ, RLX) && i == 50 && e == 40);
		CHECK(3, __sync_fetch_and_add(&i, 1) == 50 && __sync_add_and_fetch(&i, 1) == 52);
		CHECK(3, __sync_fetch_and_or(&i, 1) == 52 && __sync_and_and_fetch(&i, ~1) == 52);
		CHECK(3, __sync_val_compare_and_swap(&i, 52, 60) == 52 && __sync_bool_compare_and_swap(&i, 60, 61)
			 && !__sync_bool_compare_and_swap(&i, 60, 62) && i == 61);
		__sync_synchronize();
		CHECK(4, __atomic_fetch_add(&n, 1, SEQ) == -1 && n == 0);
		CHECK(4, __sync_val_compare_and_swap(&u, 0xffffffffu, 1u) == 0xffffffffu && u == 1);
		CHECK(4, __atomic_compare_exchange_n(&ne, &x, -6, 0, SEQ, SEQ) && ne == -6 && x == -5);
		CHECK(4, __atomic_always_lock_free(sizeof(int), 0) && __atomic_is_lock_free(sizeof(int), &i));
	}
#endif
#if __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8
	{
		long long ll = -1, le = -1;
		void *p = 0, *q = &i, *pe = 0;

		CHECK(5, __atomic_exchange_n(&p, q, SEQ) == 0 && p == q);
		CHECK(5, __atomic_compare_exchange_n(&p, &pe, (void *)0, 0, SEQ, SEQ) == 0 && pe == q);
		CHECK(5, __atomic_add_fetch(&ll, 1LL << 40, SEQ) == (1LL << 40) - 1);
		CHECK(5, __sync_fetch_and_sub(&ll, (1LL << 40) - 1) == (1LL << 40) - 1 && ll == 0);
		ll = -1;
		CHECK(5, __atomic_compare_exchange_n(&ll, &le, -2, 0, SEQ, SEQ) && ll == -2);
	}
#endif
#if __GCC_HAVE_SYNC_COMPARE_AND_SWAP_1
	{
		unsigned char flag = 0;
		signed char sc = -2;
		char cc = (char)0xff;

		CHECK(6, __atomic_fetch_add(&c, 100, SEQ) == 7 && c == 107);
		CHECK(6, __atomic_fetch_sub(&sc, 1, SEQ) == -2 && sc == -3);
		CHECK(6, !__atomic_test_and_set(&flag, SEQ) && __atomic_test_and_set(&flag, SEQ));
		__atomic_clear(&flag, SEQ);
		CHECK(6, flag == 0);
		CHECK(6, __sync_val_compare_and_swap(&cc, (char)0xff, 1) == (char)0xff && cc == 1);
	}
#endif
#if __GCC_HAVE_SYNC_COMPARE_AND_SWAP_2
	{
		short s = -3, se = -3;
		unsigned short us = 0xffff;

		CHECK(7, __atomic_fetch_add(&s, -1, SEQ) == -3 && s == -4);
		CHECK(7, !__atomic_compare_exchange_n(&s, &se, 9, 0, SEQ, SEQ) && se == -4);
		CHECK(7, __atomic_compare_exchange_n(&s, &se, 9, 0, SEQ, SEQ) && s == 9);
		CHECK(7, __sync_nand_and_fetch(&us, 0xff) == (unsigned short)~0xff);
	}
#endif
	return bad;
}
