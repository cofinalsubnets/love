/* constant float exprs in a global image, the indexed null-ground &((T*)0)->ts[i],
 * sizeof('T') is an int, and __attribute__((packed)) laying align-1. */

typedef unsigned uint32_t;
typedef unsigned long uint64_t;

#define TBITS 7
static const double invln2N = 1.4426950408889634 * (1 << TBITS);
static const double scaled[2] = { 0.5 * (double)(1 << 3), -0.25 * (double)(1 << 2) };
static const double eps = 1.0 / (1 << 10);

struct ev { unsigned type; unsigned pad; unsigned long ts[2]; };
static const unsigned long offs[2] = {
	(unsigned long)((char *)&((struct ev *)0)->ts[0] - (char *)0),
	(unsigned long)((char *)&((struct ev *)0)->ts[1] - (char *)0),
};

static const unsigned codes[3] = { sizeof('T') << 16, sizeof(1.5) << 8, sizeof(4294967296) };

typedef union epoll_data { void *ptr; int fd; uint32_t u32; uint64_t u64; } epoll_data_t;
struct epoll_event { uint32_t events; epoll_data_t data; }
__attribute__ ((__packed__))
;

int main(void)
{
	struct epoll_event e; e.events = 3; e.data.u64 = 77;
	int f = (int)invln2N + (int)scaled[0] + (int)scaled[1] + (int)(eps * 4096.0);  /* 191 */
	int o = (int)offs[0] * 2 + (int)offs[1];                                       /* 56 */
	int c = (codes[0] >> 16) + (codes[1] >> 8) + codes[2];                         /* 20 */
	int p = (int)sizeof(struct epoll_event)                                        /* 12 */
	      + (int)((char *)&e.data - (char *)&e)                                    /* 4 */
	      + (int)e.data.u64 - 77 + (int)e.events - 3;
	return f - 191 + o + c + p + 10;                                               /* 102 */
}
