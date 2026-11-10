/* a bit-field's value: an int when an int holds it, unsigned at unsigned's full width, and an
   assignment answers the field as it now stands, a signed one's top bit its sign. no libc */
struct a { unsigned u32:32; unsigned u31:31; unsigned u3:3; int s3:3; int s32:32; unsigned char uc:3; _Bool b:1; };
struct l { unsigned long long u3:3; long long s3:3; };

#define INT(e) _Generic((e), int: 1, default: 0)
#define UINT(e) _Generic((e), unsigned: 1, default: 0)

int main(void)
{
	struct a v = {0};
	struct l w = {0};
	int r;
	v.s3 = -1; v.u3 = 7; w.u3 = 7; w.s3 = -1;
	if (!UINT(v.u32 - 1) || !INT(v.u31 - 1) || !INT(v.u3 - 8) || !INT(v.s3 + 0) || !INT(v.s32 - 1)) return 1;
	if (!INT(v.uc - 8) || !INT(v.b - 1) || !INT(w.u3 - 8) || !INT(w.s3 + 0)) return 2;
	if (sizeof(v.u32 - 1) != 4 || sizeof(w.u3 - 8) != 4) return 3;
	if (v.s3 < 0u) return 4;		/* -1 converts to unsigned */
	if (v.u32 - 1 < 0) return 5;
	if (!(v.u3 > -1) || !(v.s3 < 0)) return 6;
	if (v.u3 - 8 >= 0 || w.u3 - 8 >= 0 || v.u31 - 1 >= 0) return 7;
	if ((v.u32 - 1) / 2 != 2147483647u) return 8;
	r = (v.s3 = -1); if (r != -1) return 10;
	r = (v.u3 = -1); if (r != 7) return 11;
	r = (v.s3 = 9); if (r != 1) return 12;
	r = (v.s3 = 7); if (r != -1) return 13;
	r = (v.s3 += 3); if (r != 2) return 14;
	r = (v.s3 += 3); if (r != -3 || v.s3 != -3) return 15;
	r = (v.s32 = -5); if (r != -5) return 16;
	r = (v.b = 4); if (r != 1) return 17;
	r = (v.uc = 300); if (r != 4) return 18;
	r = (w.s3 = 5); if (r != -3) return 19;
	r = v.s3++; if (r != -3 || v.s3 != -2) return 20;
	r = ++v.u3; if (r != 0) return 21;
	return 0;
}
