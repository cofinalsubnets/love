/* an enumerator past int has its enum's type, as gcc's: -1U is unsigned int, so an int -1 meets
 * it as unsigned and equals it. bits name the failing check, 55 passes */
enum { NO = -1U, MIN = 1, MAX = NO - 1 };
enum big { BA = 0x100000000L, BB };
enum neg { NA = -1, NB = 0x7fffffff };
enum uns { UA = 0x80000000, UB };
int main(void)
{
	volatile int t = -1;
	int bad = 0;
	bad |= (t != NO) << 0;
	bad |= (sizeof NO != 4) << 1;
	bad |= ((NO + 0) < 0) << 2;
	bad |= (MAX != 0xfffffffeU) << 3;
	bad |= (sizeof BA != 8 || BB != 0x100000001L) << 4;
	bad |= (sizeof NA != 4 || (NA + 0) >= 0) << 5;
	bad |= (sizeof UA != 4 || t == UA || (UA + 0) < 0) << 6;
	return bad ? bad : 55;
}
