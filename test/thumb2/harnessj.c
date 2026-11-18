/* the gcc side: the integer jump first, before any fp instruction runs, then the
   registers' round trip, then s16-s31 (d8-d15) held here across jfp's setjmp and written
   by clob before it jumps; 100+n names what went wrong, 108 the fp registers lost */
int jint(void); int jregs(int); int jfp(void); void jump(void);
volatile int junk_seen;
void clob(void) {
 static const float junk[16] = {-1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12, -13, -14, -15, -16};
 __asm__ volatile ("vldmia %0, {s16-s31}" :: "r"(junk) : "memory", "s16", "s17", "s18", "s19", "s20", "s21",
                   "s22", "s23", "s24", "s25", "s26", "s27", "s28", "s29", "s30", "s31");
 jump();
 junk_seen = 1;   /* no tail call: the jump leaves from inside this frame, s16-s31 still junk */
}
int run(void){
 int r = jint();
 if (r != 1) return r;
 r = jregs(5);
 if (r != 1) return r;
 static const float in[16] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
 float out[16];
 __asm__ volatile ("vldmia %1, {s16-s31}\n\tbl jfp\n\tmov %0, r0\n\tvstmia %2, {s16-s31}"
                   : "=r"(r) : "r"(in), "r"(out)
                   : "memory", "r0", "r1", "r2", "r3", "r12", "lr", "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
                     "s8", "s9", "s10", "s11", "s12", "s13", "s14", "s15", "s16", "s17", "s18", "s19", "s20", "s21",
                     "s22", "s23", "s24", "s25", "s26", "s27", "s28", "s29", "s30", "s31");
 if (r != 1) return r;
 for (int i = 0; i < 16; i++) if (out[i] != in[i]) return 108;
 return 2;
}
