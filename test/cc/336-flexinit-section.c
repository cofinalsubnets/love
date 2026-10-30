/* an initialized flexible array lays its elements past the struct, in a named section as in
 * .rodata (the kernel's idreg-override tables), and the next object keeps its alignment */
struct d { char name[20]; long ov; struct { char n[10]; unsigned char s, w; } f[]; };
static const struct d a __attribute__((section(".init.rodata"))) = { "first", 1, { { "x", 1, 2 }, { "yy", 3, 4 }, {} } };
static const struct d b __attribute__((section(".init.rodata"))) = { "second", 2, { { "z", 5, 6 }, {} } };
static const struct d c = { "third", 3, { { "q", 7, 8 }, {} } };
static const struct d e = { "fourth", 4, { {} } };
const struct d *pa = &a, *pb = &b, *pc = &c, *pe = &e;

int main(void)
{
	int r = 0;
	if (pa->f[1].s != 3 || pa->f[1].n[1] != 'y' || pa->f[2].n[0]) r |= 1;
	if (pb->f[0].s != 5 || pb->ov != 2) r |= 2;
	if (pc->f[0].w != 8 || pe->ov != 4) r |= 4;
	if (((unsigned long) pb | (unsigned long) pe) & (_Alignof(struct d) - 1)) r |= 8;
	return r + 40;
}
