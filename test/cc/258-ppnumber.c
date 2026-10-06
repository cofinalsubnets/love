/* a pp-number runs through identifier characters (C11 6.4.8): `9p_fid_ref` is one token, so a
 * paste onto it makes one name -- linux's DECLARE_TRACEPOINT(9p_fid_ref) pastes
 * __tracepoint_##tp. hex and exponent spellings ride the same way, and ordinary numbers beside
 * them still read as numbers. freestanding, exit-code only. */

#define TP(tp) static int __tracepoint_##tp
#define CAT(a, b) a##b
TP(9p_fid_ref) = 7;
TP(0x1f_ok) = 8;
static int CAT(v, 1e5x) = 9;
#define STR2(x) #x
#define STR(x) STR2(x)

int main(void)
{
	int bad = 0;
	if (__tracepoint_9p_fid_ref != 7 || __tracepoint_0x1f_ok != 8 || v1e5x != 9) bad |= 1;
	if (0x1f + 10 - 2 != 39 || 1.5e3f != 1500.0f) bad |= 2;
	const char *s = STR(9p_fid_ref);
	if (s[0] != '9' || s[1] != 'p' || s[9] != 'f' || s[10] != 0) bad |= 4;
	return bad;
}
