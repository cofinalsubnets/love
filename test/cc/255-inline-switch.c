/* an always_inline body spliced where it is called: a switch holding returns with more after it
 * (linux's cpucap_is_possible), a break at the switch's level that must still meet that tail,
 * a case that falls out of the switch into it, and a value no case names. 256 shows the splice
 * itself. freestanding, exit-code only. */

static inline __attribute__((__always_inline__)) int pick(int x, int other)
{
	switch (x) {
	case 1: return 10;
	case 2: return other;
	default: break;
	}
	return 0;
}

static inline __attribute__((__always_inline__)) int tail(int x, int *seen)
{
	int r = 1;
	switch (x) {
	case 1: r = 5; break;
	case 2: return 7;
	case 3: r = 2;   /* falls out */
	}
	r *= 3;
	*seen += 1;
	return r;
}

static inline __attribute__((__always_inline__)) int caps(const unsigned cap)
{
	switch (cap) {
	case 46: return 1;
	case 21: return 1;
	default: break;
	}
	return 0;
}

int main(void)
{
	volatile int v = 9;
	int bad = 0, seen = 0;
	if (pick(1, 0) != 10 || pick(2, 4) != 4 || pick(v, 3) != 0) bad |= 1;
	if (tail(1, &seen) != 15 || seen != 1) bad |= 2;
	if (tail(2, &seen) != 7 || seen != 1) bad |= 4;
	if (tail(3, &seen) != 6 || tail(v, &seen) != 3 || seen != 3) bad |= 8;
	if (!caps(46) || !caps(21) || caps(7) || caps(v)) bad |= 16;
	return bad;
}
