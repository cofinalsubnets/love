/* a frame address handed to one call may be kept by the callee: the fn's later call must not
 * jump out of the frame under it (lua's block: enterblock(fs, &bl) .. leaveblock(fs)) */
struct st { int *bl; };
static int seen;
__attribute__((noinline)) void enter(struct st *s, int *x) { s->bl = x; *x = 7; }
__attribute__((noinline)) void scrub(int n) { volatile char junk[512]; for (int i = 0; i < 512; i++) junk[i] = (char) (n + i); }
__attribute__((noinline)) void leave(struct st *s) { scrub(3); seen = *s->bl; }
__attribute__((noinline)) void f(struct st *s) { int x; enter(s, &x); leave(s); }
__attribute__((noinline)) void g(struct st *s) { int x[2]; enter(s, x); leave(s); }
int main(void) {
	struct st s;
	int r = 0;
	f(&s); r += seen == 7;
	seen = 0;
	g(&s); r += seen == 7;
	return r;
}
