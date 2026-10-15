/* __attribute__((alias("target"))): another name for a defined function, a static
 * function, and a data object. weak vs strong binding is a link property this
 * program cannot see. */

#define weak_alias(old, new) \
	extern __typeof(old) new __attribute__((__weak__, __alias__(#old)))

static int impl(int x) { return x * 3; }
int __base(int x) { return impl(x) + 1; }
weak_alias(__base, base_alias);
int base_alias(int);

static void dummy(void) { }
weak_alias(dummy, hook_alias);
void hook_alias(void);

static long counter = 40;
weak_alias(counter, counter_alias);
extern long counter_alias;

int main(void)
{
	hook_alias();                                  /* the static-target alias runs */
	return __base(5) + base_alias(2)               /* 16 + 7 */
	     + (int)counter_alias                      /* 40, the same object */
	     + (&counter_alias == &counter ? 3 : 0);   /* ..at the same address */
}
