/* libgcc's soft-float and pair names over rt.c's aeabi ones, for test_ccrv32's clang builds:
 * no compiler-rt for riscv32 here. bit patterns in core registers, as rt.c takes them */
typedef unsigned long long u64; typedef long long i64; typedef unsigned u32;
u64 __aeabi_dadd(u64, u64); u64 __aeabi_dsub(u64, u64); u64 __aeabi_dmul(u64, u64); u64 __aeabi_ddiv(u64, u64);
u32 __aeabi_fadd(u32, u32); u32 __aeabi_fsub(u32, u32); u32 __aeabi_fmul(u32, u32); u32 __aeabi_fdiv(u32, u32);
u64 __aeabi_f2d(u32); u32 __aeabi_d2f(u64);
int __aeabi_d2iz(u64); u32 __aeabi_d2uiz(u64); i64 __aeabi_d2lz(u64); u64 __aeabi_d2ulz(u64);
int __aeabi_f2iz(u32); u32 __aeabi_f2uiz(u32);
u64 __aeabi_i2d(int); u64 __aeabi_ui2d(u32); u64 __aeabi_l2d(i64); u64 __aeabi_ul2d(u64);
u32 __aeabi_i2f(int); u32 __aeabi_ui2f(u32); u32 __aeabi_l2f(i64); u32 __aeabi_ul2f(u64);
i64 __aeabi_llsl(i64, int); i64 __aeabi_llsr(i64, int); i64 __aeabi_lasr(i64, int); i64 __aeabi_lmul(i64, i64);
int __aeabi_dcmplt(u64, u64); int __aeabi_dcmpgt(u64, u64); int __aeabi_dcmpun(u64, u64);
int __aeabi_fcmplt(u32, u32); int __aeabi_fcmpgt(u32, u32); int __aeabi_fcmpun(u32, u32);
u64 __adddf3(u64 a, u64 b) { return __aeabi_dadd(a, b); }
u64 __subdf3(u64 a, u64 b) { return __aeabi_dsub(a, b); }
u64 __muldf3(u64 a, u64 b) { return __aeabi_dmul(a, b); }
u64 __divdf3(u64 a, u64 b) { return __aeabi_ddiv(a, b); }
u64 __negdf2(u64 a) { return a ^ 0x8000000000000000ull; }
u32 __addsf3(u32 a, u32 b) { return __aeabi_fadd(a, b); }
u32 __subsf3(u32 a, u32 b) { return __aeabi_fsub(a, b); }
u32 __mulsf3(u32 a, u32 b) { return __aeabi_fmul(a, b); }
u32 __divsf3(u32 a, u32 b) { return __aeabi_fdiv(a, b); }
u32 __negsf2(u32 a) { return a ^ 0x80000000u; }
u64 __extendsfdf2(u32 a) { return __aeabi_f2d(a); }
u32 __truncdfsf2(u64 a) { return __aeabi_d2f(a); }
int __fixdfsi(u64 a) { return __aeabi_d2iz(a); }
u32 __fixunsdfsi(u64 a) { return __aeabi_d2uiz(a); }
i64 __fixdfdi(u64 a) { return __aeabi_d2lz(a); }
u64 __fixunsdfdi(u64 a) { return __aeabi_d2ulz(a); }
int __fixsfsi(u32 a) { return __aeabi_f2iz(a); }
u32 __fixunssfsi(u32 a) { return __aeabi_f2uiz(a); }
i64 __fixsfdi(u32 a) { return __aeabi_d2lz(__aeabi_f2d(a)); }
u64 __fixunssfdi(u32 a) { return __aeabi_d2ulz(__aeabi_f2d(a)); }
u64 __floatsidf(int a) { return __aeabi_i2d(a); }
u64 __floatunsidf(u32 a) { return __aeabi_ui2d(a); }
u64 __floatdidf(i64 a) { return __aeabi_l2d(a); }
u64 __floatundidf(u64 a) { return __aeabi_ul2d(a); }
u32 __floatsisf(int a) { return __aeabi_i2f(a); }
u32 __floatunsisf(u32 a) { return __aeabi_ui2f(a); }
u32 __floatdisf(i64 a) { return __aeabi_l2f(a); }
u32 __floatundisf(u64 a) { return __aeabi_ul2f(a); }
i64 __ashldi3(i64 a, int n) { return __aeabi_llsl(a, n); }
i64 __lshrdi3(i64 a, int n) { return __aeabi_llsr(a, n); }
i64 __ashrdi3(i64 a, int n) { return __aeabi_lasr(a, n); }
i64 __muldi3(i64 a, i64 b) { return __aeabi_lmul(a, b); }
/* the three-way compares: unordered answers un, the side each test reads as false */
static int d3(u64 a, u64 b, int un) { return __aeabi_dcmpun(a, b) ? un : __aeabi_dcmplt(a, b) ? -1 : __aeabi_dcmpgt(a, b); }
static int f3(u32 a, u32 b, int un) { return __aeabi_fcmpun(a, b) ? un : __aeabi_fcmplt(a, b) ? -1 : __aeabi_fcmpgt(a, b); }
int __eqdf2(u64 a, u64 b) { return d3(a, b, 1); }
int __nedf2(u64 a, u64 b) { return d3(a, b, 1); }
int __ltdf2(u64 a, u64 b) { return d3(a, b, 1); }
int __ledf2(u64 a, u64 b) { return d3(a, b, 1); }
int __gtdf2(u64 a, u64 b) { return d3(a, b, -1); }
int __gedf2(u64 a, u64 b) { return d3(a, b, -1); }
int __unorddf2(u64 a, u64 b) { return __aeabi_dcmpun(a, b); }
int __eqsf2(u32 a, u32 b) { return f3(a, b, 1); }
int __nesf2(u32 a, u32 b) { return f3(a, b, 1); }
int __ltsf2(u32 a, u32 b) { return f3(a, b, 1); }
int __lesf2(u32 a, u32 b) { return f3(a, b, 1); }
int __gtsf2(u32 a, u32 b) { return f3(a, b, -1); }
int __gesf2(u32 a, u32 b) { return f3(a, b, -1); }
int __unordsf2(u32 a, u32 b) { return __aeabi_fcmpun(a, b); }
