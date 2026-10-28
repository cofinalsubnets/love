#!/bin/sh
# test/gate/moon.sh -- mooncc's gate: the laws (test/law/moon.l) anywhere, and on x86-64
# an end-to-end battery with gcc as a second opinion, not an oracle of truth.
# not set -e: the checks capture $? for their own messages.
# usage: moon.sh OUTDIR LOVE LOVE0
. test/gate/skip.sh
. test/gate/cclib.sh
set -u

ho=$1
m=$2
love0=$3

name=test_moon
# the bootstrap compiler: love0 waking mooncc0.image
moon0() { "$love0" wake out/mooncc0.image mooncc "$@"; }

# ctab.l is c.lex through our lex: laid again, it must not move
echo "LEX src/apps/moon/c.lex"
"$m" lex -m moon -n clex-tab src/apps/moon/c.lex | cmp -s - src/apps/moon/ctab.l \
  || fail "ctab.l is not c.lex's: love lex -m moon -n clex-tab src/apps/moon/c.lex > src/apps/moon/ctab.l"
# cgram.l is c.y through our yacc, likewise
echo "YACC src/apps/moon/c.y"
"$m" yacc -m moon -n cx-tab src/apps/moon/c.y | cmp -s - src/apps/moon/cgram.l \
  || fail "cgram.l is not c.y's: love yacc -m moon -n cx-tab src/apps/moon/c.y > src/apps/moon/cgram.l"

# -- the laws
echo "CC src/apps/moon/{lex,cpp,parse,cgram,gen,val}.l test/law/moon.l"
out=$ho/.test_moon.out
{ echo "(borrow 'holo)"
  cat test/00-init.l src/apps/kore/text.l src/apps/kore/u.l   # the kore floors register module 'kore
  echo "(borrow 'kore)"                    # ..ambient: holo/text.l and law.l read `lines` bare
  cat src/apps/moon/floor.l src/apps/moon/ctab.l src/apps/moon/lex.l src/apps/moon/cpp.l src/apps/moon/parse.l \
      src/apps/moon/cgram.l src/love/holo/text.l src/love/holo/dialect.l src/love/holo/gas.l src/apps/moon/val.l src/apps/moon/gen.l
  echo "(borrow 'moon)"                    # the cat re-laid module 'moon; law.l reads it bare
  cat test/law/moon.l
} | "$m" > "$out" 2>&1
r=$?
cat "$out"
[ $r -eq 0 ] && grep -q "test/law/moon:" "$out" || fail "cc laws (exit $r)"

# -- the template parser, under love0
# text.l reaches its combinators through a bare `post` each lane binds; a wrong binding
# fails every template in silence, and the laws never walk love0's lane
echo "CC src/love/holo/text.l (love0 lane)"
"$love0" -l src/love/holo/text.l -e '(? (two? ((cite (name "holo") (name "asm-text")) "li r0, 60")) (quit 0) (quit 1))' </dev/null \
  || fail "asm-text under love0 -- is bare \`post\` the module accessor there?"

# -- the pipeline's stage types
# gen.l typed against stage.l's sig table: one composition order, a clash names its seam
"$m" src/apps/moon/stage.l || fail "moon-stage (the ;; moon-stage line names the seam)"

arch=$(uname -m)
if [ "$arch" != x64 ] && [ "$arch" != x86_64 ]; then
  gate_skip "mooncc: cc (laws only -- x64 e2e skipped on $arch) ok"
fi

cc_g=$(command -v gcc || command -v cc)

# -- the battery
printf 'int main() { return 42; }\n' > "$ho/.cc1.c"
# the guard and the fail -fstack-protector-all's runs link (moonlibc lays neither)
printf 'unsigned long __stack_chk_guard = 0x5a5aa5a5deadbeefUL;\nvoid __stack_chk_fail(void) { __builtin_trap(); }\n' > "$ho/.sspg.c"
moonrun -c -o "$ho/.sspg.o" "$ho/.sspg.c" > /dev/null 2>&1 || fail "mooncc: the stack guard object"
for f in test/cc/*.c; do
  moonrun "$f" "$ho/.ccb" > /dev/null 2>&1 || fail "mooncc compile $f"
  "$ho/.ccb"; a=$?
  $cc_g -O0 -o "$ho/.ccbg" "$f" && "$ho/.ccbg"; b=$?
  [ $a -eq $b ] || fail "mooncc battery $f (ours $a gcc $b)"
  # ..and again with the hardening flags, which change no answer
  moonrun -fcf-protection=full -ftrivial-auto-var-init=zero -fstack-protector-all -o "$ho/.ccb" "$f" "$ho/.sspg.o" > /dev/null 2>&1 ||
    fail "mooncc -fcf-protection -ftrivial-auto-var-init -fstack-protector-all compile $f"
  "$ho/.ccb"; c=$?
  [ $a -eq $c ] || fail "mooncc battery $f hardened (ours $c, unhardened $a)"
done

# kernel objects: -mno-sse keeps a variadic's prologue off the xmm file, a data symbol
# carries its size, a file-scope static is a local one, a block static keeps its section
printf '#include <stdarg.h>\nint f(int n, ...){ va_list a; va_start(a, n); int r = va_arg(a, int); va_end(a); return r + n; }\n' > "$ho/.vns.c"
moonrun -mno-sse -c "$ho/.vns.c" -o "$ho/.vns.o" || fail "mooncc -mno-sse refused a variadic function"
# a name spelled like a float register is no float code
printf 'int f815x(int a){ return a + 1; }\nint g(int a){ return f815x(a); }\n' > "$ho/.fnm.c"
moonrun -mno-sse -c "$ho/.fnm.c" -o "$ho/.fnm.o" || fail "mooncc -mno-sse took a function named f815x for float code"
printf 'struct t { int a, b, c; };\nstatic const struct t tab[] = {{1,2,3},{4,5,6},{7,8,9}};\nextern __typeof__(tab) tab_alias __attribute__((alias("tab")));\nint big[7] = {1};\nvoid push(void){ static int q __attribute__((section(".init.data"))) = 3; q++; }\n' > "$ho/.dsz.c"
moonrun -c "$ho/.dsz.c" -o "$ho/.dsz.o" || fail "mooncc: a sized data object"
[ "$(readelf -sW "$ho/.dsz.o" | awk '$8 == "tab_alias" {print $3}')" = 36 ] || fail "a data alias's symbol does not carry its table's 36 bytes"
[ "$(readelf -sW "$ho/.dsz.o" | awk '$8 == "big" {print $3}')" = 28 ] || fail "int big[7]'s symbol does not carry its 28 bytes"
[ "$(readelf -sW "$ho/.dsz.o" | awk '$8 == "tab" {print $3, $4, $5}')" = "36 OBJECT LOCAL" ] || fail "a file-scope static is not a local object symbol of its 36 bytes (modpost reads a table's name)"
readelf -SW "$ho/.dsz.o" | grep -q '\.init\.data' || fail "a block static lost its section"
# a function's symbol carries its code's bytes, its next one's pad excluded (objtool walks a
# function by them); gas's .size f, .-f the same, and the end label stays out of the symtab
printf 'static int s(int a){ return a * 3 + 1; }\nint f(int a){ return s(a) + s(a + 1); }\n__attribute__((aligned(64))) int g(void){ return 2; }\n' > "$ho/.fsz.c"
moonrun -fno-inline -c "$ho/.fsz.c" -o "$ho/.fsz.o" || fail "mooncc: sized functions"
[ "$(readelf -sW "$ho/.fsz.o" | awk '$4 == "FUNC" && $3 > 0' | wc -l)" = 3 ] || fail "a function's symbol does not carry its code's size"
set -- $(readelf -sW "$ho/.fsz.o" | awk '$8 == "f" || $8 == "g" {print $2, $3}' | sort)
[ $((0x$1 + $2)) -lt $((0x$3)) ] || fail "a function's size runs into the next one's pad"
printf '.text\n.globl h\n.type h, @function\nh:\n nop\n ret\n.size h, .-h\n.p2align 4\nk:\n ret\n.size k, . - k\n.globl m\nm:\n pause\n ret\n.type m STT_FUNC ; .set .L__sym_size_m, .-m ; .size m, .L__sym_size_m\n' > "$ho/.fsz.S"
moonrun -c "$ho/.fsz.S" -o "$ho/.fszs.o" || fail "mooncc: an asm .size"
[ "$(readelf -sW "$ho/.fszs.o" | awk '$8 == "h" || $8 == "k" || $8 == "m" {print $8, $3, $4}' | sort | tr '\n' ' ')" = "h 2 FUNC k 1 NOTYPE m 3 FUNC " ] || fail "gas's .size f, .-f (or the kernel's SYM_END) does not size f, or .type is not its type"
# an alias is its function's type and size
printf 'int f(int a){ return a + 1; }\nextern int fa(int) __attribute__((alias("f")));\n' > "$ho/.fal.c"
moonrun -c "$ho/.fal.c" -o "$ho/.fal.o" || fail "mooncc: a function alias"
[ "$(readelf -sW "$ho/.fal.o" | awk '$8 == "f" || $8 == "fa" {print $3, $4}' | sort -u | wc -l)" = 1 ] || fail "an alias does not carry its function's type and size"
readelf -sW "$ho/.fszs.o" | grep -q ' end$' && fail "a function's end label reached the symtab"
# a global in a named section is its object's bytes, no word's pad: the kernel's percpu hot
# data must fit one cache line
printf '_Bool b __attribute__((section(".data..h1")));\nint n __attribute__((section(".data..h2"))) = 3;\nchar c[3] __attribute__((section(".data..h3")));\n' > "$ho/.nps.c"
moonrun -c "$ho/.nps.c" -o "$ho/.nps.o" || fail "mooncc: globals in named sections"
[ "$(readelf -SW "$ho/.nps.o" | sed -E 's/.*\] +//' | awk '$1 ~ /^\.data\.\.h/ {print $1, $5}' | sort | tr '\n' ' ')" = ".data..h1 000001 .data..h2 000004 .data..h3 000003 " ] || fail "a named section's global carries a word's pad"
# a .rela only where a section has relocations: objtool's loop walks an empty one's first entry
[ "$(readelf -SW "$ho/.fsz.o" | sed -E 's/.*\] +//' | awk '$1 ~ /^\.rela/ && $5 == "000000"' | wc -l)" = 0 ] || fail "an object carries an empty .rela section"
# a displacement is a constant expression (opt.c's 18*8(%rsp)), %gs: may stand apart from its
# operand, and a symbol displacement sign-extends: the kernel lives at the top of the space
printf '.text\nf:\n cmpq %%gs: 8(%%rsi), %%rdx\n movq 18*8(%%rsp), %%rdx\n movq (2+3)*8(%%rsp), %%rdx\n movq sym+8(%%rax), %%rdx\n ret\n' > "$ho/.dsp.S"
moonrun -c "$ho/.dsp.S" -o "$ho/.dsp.o" || fail "mooncc: expression displacements"
[ "$(readelf -rW "$ho/.dsp.o" | awk '/R_X86/ {print $3, $5}' | tr '\n' ' ')" = "R_X86_64_32S sym " ] || fail "a constant displacement became a symbol, or a symbol one is not R_X86_64_32S"
[ "$(objdump -d "$ho/.dsp.o" | grep -c '%gs:0x8(%rsi)\|0x90(%rsp)\|0x28(%rsp)')" = 3 ] || fail "a displacement expression encodes the wrong value"
# what clang leaves out, a call to a function that only returns 0 below the inliner's depth and a
# static table nothing names (and the static functions only it names), is not laid; a `used`,
# sectioned or reached static is
printf 'void ext(int);\nstatic inline _Bool no(int b){ return 0; }\nstatic inline void c1(int b){ if (no(b)) ext(b); }\nvoid c2(int b){ c1(b); }\nstatic inline void c3(int b){ if (b) return; c2(b); }\nstatic inline void c4(int b){ c3(b + 1); }\nvoid c5(int b){ c4(b); }\nstruct ops { long (*f)(void *); };\nvoid *priv(void *);\nstatic long direct(void *d){ return (long)priv(d); }\nstatic const struct ops my_ops = { .f = direct };\nstatic inline void *alloc(void *p, const struct ops *o){ return 0; }\nvoid *mk(void *p){ return alloc(p, &my_ops); }\nstatic int ku __attribute__((used)) = 3;\nstatic int ks __attribute__((section(".mysec"))) = 4;\nstatic int dropme = 5;\nstatic int vp = 6;\nstatic int *const tab[] = { &vp };\nint use(int i){ return *tab[i]; }\nstatic int bo = 7;\nint *blk(int i){ static int *const bs[] = { &bo }; return bs[i]; }\n' > "$ho/.ded.c"
moonrun -c "$ho/.ded.c" -o "$ho/.ded.o" || fail "mooncc: dead calls and statics"
[ "$(readelf -sW "$ho/.ded.o" | awk '$8 ~ /^(ext|priv|direct|my_ops|dropme|ku|ks|vp|tab|bo)$/ {print $8}' | sort | tr '\n' ' ')" = "bo ks ku tab vp " ] || fail "a dead call or an unreferenced static was laid, or a used one was not"
# an "m" operand at a global's address is sym+k(%rip), no register: the kernel's alternatives
# patch paravirt's `call *%[op]` only as the six-byte ff 15
printf 'struct ops { void (*a)(void); void (*b)(void); } pv;\nvoid f(void){ asm volatile("call *%%[op]" :: [op] "m" (pv.b)); }\n' > "$ho/.pv.c"
moonrun -c "$ho/.pv.c" -o "$ho/.pv.o" || fail "mooncc: an m operand at a global"
[ "$(objdump -d "$ho/.pv.o" | grep -c 'ff 15 00 00 00 00')" = 1 ] || fail "an m operand at a global is not rip-relative"
# an int already within 32 signed bits takes no movsxd (a short plus a byte, then halved); a
# long narrowed to int still does
printf 'int f(short a, unsigned char b){ int x = a + b; int y = x >> 1; return y * 3; }\n' > "$ho/.sxw.c"
moonrun -c "$ho/.sxw.c" -o "$ho/.sxw.o" || fail "mooncc: a narrow int's arithmetic"
[ "$(objdump -d "$ho/.sxw.o" | grep -c movslq)" = 0 ] || fail "an int within 32 bits was sign-extended again"
printf 'int g(long a){ return (int)a; }\n' > "$ho/.sxn.c"
moonrun -c "$ho/.sxn.c" -o "$ho/.sxn.o" || fail "mooncc: a long narrowed to int"
[ "$(objdump -d "$ho/.sxn.o" | grep -c movslq)" = 1 ] || fail "a long narrowed to int lost its sign extension"
# a file-scope asm's own label is a local symbol, as gas lays it (modpost reads the kernel's
# __export_symbol_ labels); its numbered labels are not
printf 'int x;\nasm(".section \\".export_symbol\\",\\"a\\"\\n__export_symbol_x:\\n.asciz \\"\\"\\n.balign 8\\n.quad x\\n1: .quad 1b\\n.previous");\n' > "$ho/.esy.c"
moonrun -c "$ho/.esy.c" -o "$ho/.esy.o" || fail "mooncc: a file-scope asm with an export label"
[ "$(readelf -sW "$ho/.esy.o" | awk '$8 == "__export_symbol_x" {print $5}')" = LOCAL ] || fail "a file-scope asm's label is no local symbol"
[ "$(readelf -sW "$ho/.esy.o" | awk '$8 ~ /^l1\./' | wc -l)" = 0 ] || fail "a file-scope asm's numbered label reached the symtab"
[ "$(readelf -rW "$ho/.esy.o" | sed -n '/rela.export_symbol/,/^$/p' | awk 'NR == 3 {print $5}')" = x ] || fail "a relocation to a global binds a section symbol, not the global"
# a64: an absent weak's address is a literal word (abs64), never a page reach a pie link refuses
printf 'extern __attribute__((weak)) const int t[];\nconst int *g(void) { return t; }\n' > "$ho/.wkla.c"
moonrun -t a64 -c "$ho/.wkla.c" -o "$ho/.wkla.o" || fail "mooncc -t a64: an absent weak's address"
[ "$(readelf -rW "$ho/.wkla.o" | awk '$5 == "t" {print $3}' | sort -u)" = R_AARCH64_ABS64 ] || fail "an absent weak's address reaches by page on a64"
# alloca lays its block on the stack: no symbol names it on any ISA (the kernel links no alloca).
# one where an operand is parked on the stack refuses by name
printf '#include <alloca.h>\nint g(char *);\nint f(int n) { char *p = alloca(n); int r = g(alloca(n)); return r + g(p); }\n' > "$ho/.alc.c"
for t in x64 a64 rv64 arm i386; do
  moonrun -t $t -c "$ho/.alc.c" -o "$ho/.alc.o" || fail "mooncc -t $t: alloca"
  readelf -sW "$ho/.alc.o" | awk '$8 ~ /alloca/' | grep -q . && fail "alloca reached the symtab on $t"
done
printf 'int g(void *);\nint f(int c, int n) { return g(c ? __builtin_alloca(n) : 0); }\n' > "$ho/.alr.c"
moonrun -c "$ho/.alr.c" -o "$ho/.alr.o" 2> "$ho/.alr.log" && fail "an alloca under a parked operand compiled"
grep -q 'no lane for alloca where an operand is parked' "$ho/.alr.log" || fail "an alloca under a parked operand refused without naming it"
# -ftrivial-auto-var-init=zero clears an alloca block, as clang does
printf '#include <string.h>\nstatic void __attribute__((noinline)) dirty(void) { volatile char b[1024]; memset((char *) b, 255, sizeof b); }\nstatic int __attribute__((noinline)) sum(int n) { unsigned char *p = __builtin_alloca(n); int s = 0; for (int i = 0; i < n; i++) s += p[i]; return s; }\nint main(void) { dirty(); return sum(512) != 0; }\n' > "$ho/.alz.c"
moonrun -ftrivial-auto-var-init=zero -o "$ho/.alz" "$ho/.alz.c" || fail "mooncc -ftrivial-auto-var-init=zero: alloca"
"$ho/.alz" || fail "-ftrivial-auto-var-init=zero left an alloca block uncleared"
# an asm's subsection is its function's section's tail (arm64's ALTERNATIVE in an __init fn), laid
# where the same code without the subsection lands; its numbered labels stay out of the symtab
printf '__attribute__((section(".init.text"))) int f(int x)\n{ asm volatile("661: nop\\n662:\\n.subsection 1\\n663: nop\\n664:\\n.previous" ::: "memory"); return x + 1; }\nint g(int x) { return x * 2; }\n' > "$ho/.asb.c"
sed 's/\\n\.subsection 1//; s/\\n\.previous//' "$ho/.asb.c" > "$ho/.asp.c"
secsz() { readelf -SW "$1" | sed -E 's/.*\] +//' | awk '$1 == ".text" || $1 == ".init.text" {print $1, $5}' | tr '\n' ' '; }
for t in x64 a64 rv64; do
  moonrun -t $t -c "$ho/.asb.c" -o "$ho/.asb.o" && moonrun -t $t -c "$ho/.asp.c" -o "$ho/.asp.o" || fail "mooncc -t $t: an asm subsection"
  [ "$(secsz "$ho/.asb.o")" = "$(secsz "$ho/.asp.o")" ] || fail "an asm subsection left its function's section on $t: $(secsz "$ho/.asb.o")"
  nm "$ho/.asb.o" | grep -q 'l66[34]' && fail "an asm's numbered labels reached the symtab on $t"
done
# a `static` alias is a local symbol (MODULE_DEVICE_TABLE's), an object sized as its target or a
# func; where clang is, each alias's size, type and binding are clang's
printf 'struct t { int a, b, c; };\nstatic const struct t tab[] = {{1,2,3},{4,5,6},{7,8,9}};\nstatic __typeof__(tab) tab_mod __attribute__((used, alias("tab")));\nint glob[3] = {1};\nstatic __typeof__(glob) glob_mod __attribute__((used, alias("glob")));\nint f(int x) { return x + tab[x].b; }\nstatic int f_mod(int) __attribute__((used, alias("f")));\n' > "$ho/.sal.c"
moonrun -c "$ho/.sal.c" -o "$ho/.sal.o" || fail "mooncc: a static alias"
sal() { readelf -sW "$1" | awk '$8 == "tab_mod" || $8 == "glob_mod" {print $8, $3, $4, $5} $8 == "f_mod" {print $8, $4, $5}' | sort; }
[ "$(sal "$ho/.sal.o" | tr '\n' ' ')" = "f_mod FUNC LOCAL glob_mod 12 OBJECT LOCAL tab_mod 36 OBJECT LOCAL " ] \
  || fail "a static alias is not a local symbol sized as its target: $(sal "$ho/.sal.o" | tr '\n' ' ')"
if command -v clang > /dev/null 2>&1 && clang -c -o "$ho/.sal-c.o" "$ho/.sal.c" 2> /dev/null; then
  [ "$(sal "$ho/.sal.o")" = "$(sal "$ho/.sal-c.o")" ] || fail "a static alias's symbol is not clang's: $(sal "$ho/.sal-c.o" | tr '\n' ' ')"
fi
# a const that holds an address rides .rodata under -fno-pie, as clang lays it (modpost reads a
# .data table reaching .init as a mismatch), and .data without; a -pie link refuses the first by
# name, since its startup cannot write the base into .rodata
printf 'struct ops { int (*f)(int); const char *n; };\nstatic int one(int x) { return x + 1; }\nstatic const struct ops tab[] = { { one, "one" } };\nint main(void) { const struct ops *volatile p = tab; return p->f(54) == 55 && p->n[0] == 111 ? 55 : 1; }\n' > "$ho/.ror.c"
datsz() { readelf -SW "$1" | sed -E 's/.*\] +//' | awk '$1 == ".data" {print $5}'; }
for t in x64 a64 rv64; do
  moonrun -t $t -fno-PIE -c "$ho/.ror.c" -o "$ho/.ror.o" && [ "$(datsz "$ho/.ror.o")" = 000000 ] || fail "a -fno-PIE const holding an address left .rodata on $t"
  moonrun -t $t -c "$ho/.ror.c" -o "$ho/.ror.o" && [ "$(datsz "$ho/.ror.o")" = 000010 ] || fail "a const holding an address left .data on $t"
  moonrun -t $t -fno-PIE -pie -o "$ho/.ror" "$ho/.ror.c" 2> "$ho/.ror.log" && fail "a -pie link laid an address into .rodata on $t"
  grep -q link-rodata-pie "$ho/.ror.log" || fail "a -pie link over a .rodata address refused without naming it on $t"
done
moonrun -fno-PIE -o "$ho/.ror" "$ho/.ror.c" || fail "mooncc -fno-PIE: a const holding an address"
"$ho/.ror"; [ $? = 55 ] || fail "a -fno-PIE const holding an address reads wrong"
echo "mooncc: -mno-sse variadics, sized data symbols, a block static's section and static aliases ok"
# what only dead code calls must not be named at all: an unread stub, a test absorbing
# its unknown part, __builtin_expect, a flag cleared by `&= 0`, a constant switch, a fixed param
cat > "$ho/.dead.c" <<'DEAD'
struct inode { unsigned i_flags; }; struct as { struct inode *host; };
typedef struct { unsigned long pmd; } pmd_t;
extern void dax_del(void); extern void huge(void); extern void zdev(void); extern void ia32(void);
extern void conv(void); extern void reclaim(void); extern void invalid(void); extern int fault(void);
extern int sites[], sites_end[];
void __attribute__((noinline)) apply(int *s, int *e) { }
static int __attribute__((noinline)) rs(int *b, _Bool i32, int n) { if (!i32) return b[0]; conv(); return n; }
enum st { S_DONE, S_LOCK };
static inline __attribute__((always_inline)) void next(int *s, enum st t) { switch (t) { case S_DONE: invalid(); return; case S_LOCK: *s = 1; return; } }
static inline int dax_mapping(struct as *m) { return m->host && (m->host->i_flags & 0); }
static inline int pmd_is_huge(pmd_t p) { return 0; }
static inline int zone_device(const struct as *f) { return 0; }
int f(struct as *m, pmd_t *p, char *a, char *b) {
  int r = 0;
  _Bool ia = (a != b);
  ia &= (0 || 0);
  if (ia) ia32();
  if (dax_mapping(m)) { dax_del(); goto out; }
  if (pmd_is_huge(*p)) huge();
  if (__builtin_expect(!!(zone_device(m)), 0)) { zdev(); return 1; }
  r = 2;
out:
  return r;
}
int g(int *b, int *c, int n) {
  _Bool ia = (b != c), can = 0;
  ia &= 0;
  apply(sites, sites_end);
retry:
  if (fault()) goto retry;
  if (ia) ia32();
  do { if (n & 1) can = 0; } while (--n > 0);
  if (can) reclaim();
  next(b, S_LOCK);
  return rs(b, ia, 1) + rs(c, ia, 2);
}
DEAD
moonrun -c "$ho/.dead.c" -o "$ho/.dead.o" || fail "mooncc: the dead-call program"
! grep -qa 'dax_del\|huge\|zdev\|ia32\|conv\|reclaim\|invalid\|sites' "$ho/.dead.o" || fail "a call only dead code makes is still named in the object"
echo "mooncc: dead stubs, absorbed tests and a cleared flag name nothing ok"
# scoped_seqlock_read: its step splices (a typecheck() in it does nothing), and the loop's test
# `s.state != ss_done` holds at the step's switch, so its ss_done arm names no canary. a twin that
# writes the member first keeps the call
cat > "$ho/.sqlk.c" <<'SQLK'
enum ss_state { ss_done = 0, ss_lock, ss_lock_irqsave, ss_lockless };
struct ss_tmp { enum ss_state state; unsigned long data; int *lock; };
extern void __scoped_seqlock_bug(void); extern void kept(void);
extern unsigned long rbegin(void); extern int rretry(unsigned long); extern unsigned long lk(int *);
extern void ulk(int *); extern void work(long *); extern int pick(void);
#define typecheck(t, x) ({ t __d; __typeof__(x) __d2; (void) (&__d == &__d2); 1; })
static inline __attribute__((always_inline)) void cln(struct ss_tmp *s) { if (s->lock) ulk(s->lock); }
static inline __attribute__((always_inline)) void nxt(struct ss_tmp *s, int *l, enum ss_state t) {
  switch (s->state) {
  case ss_done: __scoped_seqlock_bug(); return;
  case ss_lock: case ss_lock_irqsave: s->state = ss_done; return;
  case ss_lockless: if (!rretry(s->data)) { s->state = ss_done; return; } break;
  }
  switch (t) {
  case ss_done: return;
  case ss_lock: case ss_lock_irqsave: s->lock = l; typecheck(unsigned long, s->data); s->data = lk(l); s->state = t; return;
  case ss_lockless: s->data = rbegin(); return;
  }
}
void f(int *l, long *out) {
  for (struct ss_tmp s __attribute__((cleanup(cln))) = { .state = ss_lockless, .data = rbegin() };
       s.state != ss_done; nxt(&s, l, ss_lock_irqsave))
    work(out);
}
int g(int *l) {
  struct ss_tmp s = { .state = ss_lock };
  if (s.state != ss_done) {
    s.state = pick();
    switch (s.state) { case ss_done: kept(); return 1; default: return 2; }
  }
  return 0;
}
SQLK
moonrun -c "$ho/.sqlk.c" -o "$ho/.sqlk.o" || fail "mooncc: the scoped seqlock program"
! grep -qa '__scoped_seqlock_bug' "$ho/.sqlk.o" || fail "a switch arm the loop's test excludes still names its call"
grep -qa 'kept' "$ho/.sqlk.o" || fail "a switch arm reached after the member's write lost its call"
echo "mooncc: a test's not-equal fact prunes the step's switch, a write ends it ok"
# pushq $sym: a sign-extended dword relocates as R_X86_64_32S
cat > "$ho/.p32s.c" <<'P32S'
void f(void) { unsigned long t; asm volatile("pushq $1f\n\tpopq %0\n1:" : "=r"(t)); }
P32S
moonrun -c "$ho/.p32s.c" -o "$ho/.p32s.o" || fail "mooncc: pushq \$1f"
readelf -rW "$ho/.p32s.o" | grep -q R_X86_64_32S || fail "pushq \$sym does not relocate as R_X86_64_32S"

# __int128 across compilers: SysV register pairs and rdx:rax answers, each side calling the other
$cc_g -O2 -ffreestanding -fno-stack-protector -fno-pie -c -o "$ho/.peer128.o" test/cc/abi128/peer.c \
  || fail "abi128: gcc could not build peer.c"
moonrun -o "$ho/.abi128" test/cc/abi128/host.c "$ho/.peer128.o" > "$ho/.abi128.log" 2>&1 \
  || { cat "$ho/.abi128.log" >&2; fail "abi128: mooncc could not build or link host.c"; }
"$ho/.abi128" > "$ho/.abi128.out" || { cat "$ho/.abi128.out" >&2; fail "abi128: mooncc and gcc disagree on SysV's __int128"; }

# ms_abi across compilers: gcc's definitions and calls against mooncc's trampolines and shuffles
$cc_g -O2 -ffreestanding -fno-stack-protector -fno-pie -c -o "$ho/.peerms.o" test/cc/msabi/peer.c \
  || fail "msabi: gcc could not build peer.c"
moonrun -o "$ho/.msabi" test/cc/msabi/host.c "$ho/.peerms.o" > "$ho/.msabi.log" 2>&1 \
  || { cat "$ho/.msabi.log" >&2; fail "msabi: mooncc could not build or link host.c"; }
"$ho/.msabi"; b=$?
[ $b -eq 0 ] || fail "msabi: mooncc and gcc disagree on ms_abi (bits $b)"

# the float fuzz at -Os too: its exit folds every result's bits
$cc_g -O0 -o "$ho/.f32g" test/cc/278-f32-fuzz.c && { "$ho/.f32g"; b=$?; } || fail "gcc on the float fuzz"
moonrun -Os -o "$ho/.f32" test/cc/278-f32-fuzz.c > /dev/null 2>&1 || fail "mooncc -Os the float fuzz"
"$ho/.f32"; a=$?
[ $a -eq $b ] || fail "float arithmetic -Os: ours $a gcc $b"

# a BUG_ON folded false loses its brk and label, so its __bug_table row must go too,
# or the object names a label it never lays
bug='asm volatile (".pushsection __bug_table,\"aw\"; .align 2; 14470: .long 14471f - .; .popsection; 14471: brk 0x800");'
printf 'int f(void){ const int len = 0; if (0 < len) { %s } return 1; }\n' "$bug" > "$ho/.bugd.c"
printf 'int f(int n){ if (n) { %s } return 1; }\n' "$bug" > "$ho/.bugl.c"
moonrun -t a64 -c "$ho/.bugd.c" -o "$ho/.bugd.o" || fail "mooncc -t a64 a dead BUG asm"
moonrun -t a64 -c "$ho/.bugl.c" -o "$ho/.bugl.o" || fail "mooncc -t a64 a live BUG asm"
! grep -q 'l14471' "$ho/.bugd.o" || fail "a dead BUG asm's __bug_table row names its removed label"
grep -q '__bug_table' "$ho/.bugl.o" || fail "a live BUG asm lost its __bug_table row"

# an inline helper whose local's address goes only to an overflow builtin is spliced and
# leaves no body; one passing that address to a call stays a call
printf 'extern void *big(unsigned long);\nstatic inline void *karr(unsigned long n, unsigned long s) { unsigned long b; if (__builtin_mul_overflow(n, s, &b)) return 0; return big(b); }\nvoid *f(void) { return karr(4, 8); }\n' > "$ho/.ovf.c"
printf 'extern void sink(long *);\nstatic inline long kesc(long x) { long b = x; sink(&b); return b; }\nlong g(void) { return kesc(3); }\n' > "$ho/.esc.c"
moonrun -c "$ho/.ovf.c" -o "$ho/.ovf.o" || fail "mooncc an overflow builtin's &local"
moonrun -c "$ho/.esc.c" -o "$ho/.esc.o" || fail "mooncc an escaping &local"
! grep -q 'karr' "$ho/.ovf.o" || fail "an inline helper whose &local goes only to __builtin_mul_overflow was not spliced"
grep -q 'kesc' "$ho/.esc.o" || fail "an inline helper handing its &local to a call was spliced"

# the size gate weighs structure: long names and __builtin_expect(!!(..)) do not bar a splice
printf 'extern void *slow_path_allocator(unsigned long, unsigned);\nstatic inline _Bool must_check_overflow_of_the_product(_Bool o) { return __builtin_expect(!!(o), 0); }\nstatic inline void *kmalloc_array_noprof_like_helper(unsigned long number_of_elements, unsigned long size_of_each, unsigned allocation_flags) { unsigned long total_bytes_requested; if (__builtin_expect(!!(must_check_overflow_of_the_product(__builtin_mul_overflow(number_of_elements, size_of_each, &total_bytes_requested))), 0)) return ((void *)0); return slow_path_allocator(total_bytes_requested, allocation_flags); }\nvoid *f(void) { return kmalloc_array_noprof_like_helper(4, 8, 1); }\n' > "$ho/.wgt.c"
moonrun -c "$ho/.wgt.c" -o "$ho/.wgt.o" || fail "mooncc a long-named inline helper"
! grep -q 'kmalloc_array_noprof_like_helper' "$ho/.wgt.o" || fail "a small inline helper with long names was not spliced"
# a constant size through the overflow builtin reaches __builtin_constant_p spliced: only the constant path is laid
printf 'typedef unsigned long size_t;\nextern void *slow(size_t); extern void *fast(size_t);\nstatic inline __attribute__((always_inline)) void *km(size_t size) { if (__builtin_constant_p(size) && size) return fast(size); return slow(size); }\nstatic inline void *ka(size_t n, size_t s) { size_t b; if (__builtin_mul_overflow(n, s, &b)) return 0; return km(b); }\nlong *gp;\nvoid *f(void) { return ka(3, sizeof(*gp)); }\n' > "$ho/.kca.c"
moonrun -c "$ho/.kca.c" -o "$ho/.kca.o" || fail "mooncc kcalloc's constant size"
grep -q 'fast' "$ho/.kca.o" && ! grep -q 'slow' "$ho/.kca.o" || fail "a constant size through an overflow builtin did not reach __builtin_constant_p"
# FIELD_PREP's shape: a constant mask four always_inline calls deep folds its check away, no copy laid
cat > "$ho/.bfm.c" <<'CEOF'
typedef unsigned long long u64;
extern void __bad_mask(void);
static inline __attribute__((always_inline)) u64 fmul(u64 f) { if ((f | (f - 1)) & ((f | (f - 1)) + 1)) __bad_mask(); return f & -f; }
static inline __attribute__((always_inline)) u64 fmask(u64 f) { return f / fmul(f); }
static inline __attribute__((always_inline)) u64 enc(u64 v, u64 f) { return (v & fmask(f)) * fmul(f); }
static inline __attribute__((always_inline)) u64 repl(u64 o, u64 v, u64 f) { return (o & ~f) | enc(v, f); }
u64 rd(u64 p, u64 n) { return repl(p, n, 0xf800); }
CEOF
moonrun -c "$ho/.bfm.c" -o "$ho/.bfm.o" || fail "mooncc FIELD_PREP's shape"
! grep -q '__bad_mask' "$ho/.bfm.o" || fail "a constant mask four always_inline calls deep kept its __bad_mask"
# btf_parse_base's shape: a static whose constant test returns early is judged as it splices, the
# goto tail past the return cut, and the section bounds it never reads go with it
cat > "$ho/.btf.c" <<'CEOF'
extern char __start_BTF[], __stop_BTF[];
extern void *kz(unsigned long);
extern int hdr(void *);
static void *base(const char *name, void *data, unsigned size)
{
  void *b = 0;
  int err;
  if (!0)
    return (void *)-2L;
  b = kz(size);
  if (!b) { err = -12; goto out; }
  err = hdr(data);
  if (err) goto out;
  return b;
out:
  return (void *)(long)err;
}
void *vml(void) { return base("vmlinux", __start_BTF, __stop_BTF - __start_BTF); }
void *oth(void *d, unsigned n) { return base(".BTF.base", d, n); }
CEOF
moonrun -c "$ho/.btf.c" -o "$ho/.btf.o" || fail "mooncc btf_parse_base's shape"
! grep -q '_BTF' "$ho/.btf.o" || fail "a call whose callee returns early on a constant kept the section bounds it never reads"

# a jump label: its "i" operand is constant only once spliced, and its asm goto target,
# named only by __jump_table, stays laid. held to gcc -O2 (-O0 refuses the "i")
cat > "$ho/.jl.c" <<'CEOF'
struct static_key { int enabled; };
struct static_key key_a;
struct jent { int code, target; long key; };
extern struct jent __start___jump_table[], __stop___jump_table[];
static inline __attribute__((__always_inline__)) int sb(struct static_key *const key, const _Bool branch)
{
  char *k = &((char *)key)[branch];
  asm goto("1: nop\n\t.pushsection __jump_table, \"aw\"\n\t.align 8\n\t"
           ".long 1b - ., %l[yes] - .\n\t.quad %c0 - .\n\t.popsection\n\t"
           : : "i"(k) : : yes);
  return 0;
yes:
  return 1;
}
int main(void)
{
  struct jent *e = __start___jump_table;
  if (sb(&key_a, 1)) return 9;                      /* the nop falls through */
  if (__stop___jump_table - e != 1) return 1;
  if ((char *)&e->key + e->key != (char *)&key_a + 1) return 2;
  return 0;
}
CEOF
moonrun "$ho/.jl.c" -o "$ho/.jl" || fail "mooncc a spliced jump label"
"$ho/.jl" || fail "a spliced jump label's table or target is wrong (exit $?)"
$cc_g -O2 -o "$ho/.jlg" "$ho/.jl.c" && { "$ho/.jlg" || fail "gcc -O2 disagrees on the jump-label law (exit $?)"; }

# -- setjmp: a volatile local changed after it keeps its value
# a fn calling setjmp keeps nothing in callee-saved registers (C11 7.13.2.1); exit counts the checks held
cat > "$ho/.sj.c" <<'CEOF'
#include <setjmp.h>

static jmp_buf jb;
static jmp_buf jb2;

static void bounce(int v) { longjmp(jb, v); }
static void bounce2(int v) { longjmp(jb2, v); }

static int here(void) {
  volatile int hops = 0;
  if (setjmp(jb) == 0) { hops++; longjmp(jb, 1); }
  return hops == 1;
}

static int callee(void) {
  volatile int n = 10;
  volatile unsigned long acc = 0;
  int r = setjmp(jb);
  acc += (unsigned long)r;
  if (r < 3) { n++; bounce(r + 1); }
  return n == 13 && acc == 6;
}

static int other(void) {
  volatile int hops = 0;
  volatile long big = 1;
  if (setjmp(jb2) == 0) { hops = 7; big <<= 20; bounce2(2); }
  return hops == 7 && big == 1L << 20;
}

/* many live names around the call: more than the registers that survive it */
static int crowd(int k) {
  volatile int a = k, b = k + 1, c = k + 2, d = k + 3, e = k + 4, f = k + 5, g = k + 6;
  if (setjmp(jb) == 0) { a += 10; b += 10; c += 10; d += 10; e += 10; f += 10; g += 10; bounce(1); }
  return a + b + c + d + e + f + g == 7 * k + 21 + 70;
}

/* a store just ahead of the longjmp, read only after the second return */
static int __attribute__((noinline)) direct(void) {
  volatile int x = 1;
  if (setjmp(jb)) return x;
  x = 2;
  longjmp(jb, 1);
}

int main(void) {
  return here() + callee() + other() + crowd(5) + (direct() == 2);
}
CEOF
moonrun "$ho/.sj.c" -o "$ho/.sj" || fail "mooncc the setjmp law"
"$ho/.sj"; st=$?
[ $st -eq 5 ] || fail "a volatile local across setjmp lost its value ($st of 5 held)"
$cc_g -O2 -o "$ho/.sjg" "$ho/.sj.c" && { "$ho/.sjg"; [ $? -eq 5 ] || fail "gcc -O2 disagrees on the setjmp law"; }

# -- -std=: the dialect rail (struct labels)
# gcc cannot read a struct label, so the oracle is the label-free twin: same size and offsets
cat > "$ho/.lbl.c" <<'EOF'
#include <stdio.h>
#include <stddef.h>
struct S { int a; hdr: long b; int c; tail: };
union  U { top: int x; long y; };
int main(void) {
  struct S s;
  if ((void*)s.hdr != (void*)&s.b) return 1;     /* the label IS the address -- no & to write */
  if (offsetof(struct S,tail) != (int)sizeof(struct S)) return 2;  /* trailing: one past the OBJECT */
  printf("%d %d %d %d %d\n", (int)sizeof(struct S), (int)offsetof(struct S,a),
         (int)offsetof(struct S,b), (int)offsetof(struct S,c), (int)sizeof(union U));
  return 0; }
EOF
cat > "$ho/.lblg.c" <<'EOF'
#include <stdio.h>
#include <stddef.h>
struct S { int a; long b; int c; };
union  U { int x; long y; };
int main(void) {
  printf("%d %d %d %d %d\n", (int)sizeof(struct S), (int)offsetof(struct S,a),
         (int)offsetof(struct S,b), (int)offsetof(struct S,c), (int)sizeof(union U));
  return 0; }
EOF
# no flag: moon is the default dialect
moonrun -o "$ho/.lbl" "$ho/.lbl.c" > /dev/null 2>&1 || fail "struct labels did not compile by default"
a=$("$ho/.lbl"); ra=$?
$cc_g -O0 -o "$ho/.lblg" "$ho/.lblg.c" > /dev/null 2>&1 && b=$("$ho/.lblg")
[ $ra -eq 0 ] || fail "struct labels: the labelled program refused itself (exit $ra)"
[ "$a" = "$b" ] || fail "struct labels changed the layout (ours [$a] gcc [$b])"
moonrun -std=moon -c -o /dev/null "$ho/.lbl.c" > /dev/null 2>&1 || fail "-std=moon refused its own extension"
# c is the fence: strict C takes no extension, and an unknown -std= refuses
moonrun -std=c -c -o /dev/null "$ho/.lbl.c" > /dev/null 2>&1 && fail "a struct label was accepted under -std=c"
moonrun -std=c11 -c -o /dev/null "$ho/.lbl.c" > /dev/null 2>&1 && fail "a struct label was accepted under -std=c11"
moonrun -std=nosuchlang -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 && fail "an unknown -std= was tolerated"
moonrun -std=holyc -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 && fail "-std=holyc was accepted -- it names a dialect we do not read"
moonrun -std=c -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 || fail "-std=c refused a plain C file"
# no function returns a function or an array (C11 6.7.6.3p1); a function pointer, a pointer to a
# typedef'd function type and an array of function pointers still declare
printf 'int inc(int x){ return x + 1; }\nint (pick(int w))(int) { return inc; }\n' > "$ho/.frf.c"
printf 'int (f2(void))[3];\n' > "$ho/.fra.c"
printf 'typedef int F(int);\nF *g(void);\nint (*h(void))(int);\nint (*a[3])(void);\n' > "$ho/.frp.c"
moonrun -c -o /dev/null "$ho/.frf.c" > /dev/null 2>&1 && fail "a function returning a function was accepted"
moonrun -c -o /dev/null "$ho/.fra.c" > /dev/null 2>&1 && fail "a function returning an array was accepted"
moonrun -c -o /dev/null "$ho/.frp.c" > /dev/null 2>&1 || fail "function pointers in a declarator were refused"
moonrun -std=gnu11 -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 || fail "-std=gnu11 refused a plain C file"
echo "mooncc: -std= is a rail (moon is the default and lays gcc's own layout; c fences the extensions out; an unknown one refuses)"

# -- bool, and the GNU C a __GNUC__ 8 claim owes
# bool/true/false are bare in moon and C23, plain names in older iso dialects
printf 'enum { false = 0, true = 1 };\ntypedef _Bool bool;\nint f(bool b) { return b ? true : false; }\n' > "$ho/.bool.c"
moonrun -std=gnu11 -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "-std=gnu11 kept true/false predefined"
moonrun -std=c11 -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "-std=c11 kept true/false predefined"
printf 'bool f(void) { return true; }\n' > "$ho/.bool.c"
moonrun -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "the moon dialect lost bare bool"
moonrun -std=c23 -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "-std=c23 lost bare bool"
printf '#include <stdbool.h>\nbool f(void) { return true; }\n' > "$ho/.bool.c"
moonrun -std=c11 -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "<stdbool.h> did not lay bool under -std=c11"
# an attribute whose skip changes the code refuses by name
for a in constructor 'vector_size(16)' 'mode(DI)' naked 'ifunc("r")'; do
  printf 'int f(void) __attribute__((%s));\n' "$a" > "$ho/.attr.c"
  moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "is not carried out" || fail "__attribute__(($a)) was skipped"
done
# #pragma pack refuses an operand it does not read and a bit-field it would let straddle
printf '#pragma pack(3)\nstruct s { char c; int i; };\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "is not one mooncc reads" || fail "#pragma pack(3) was taken"
printf '#pragma pack(1)\nstruct s { char c; int i : 20; int j : 20; };\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "a bit-field under #pragma pack" || fail "a packed bit-field was laid"
printf 'typedef union { char *p; short s; } u __attribute__((transparent_union));\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "a transparent union wants" || fail "a mixed transparent union was taken"
# atomics refuse by name: a generic form, a width past the exclusives, armv6-m's read-modify-write
printf 'int f(int *p, int *r) { __atomic_load(p, r, 5); return *r; }\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "__atomic_load is not carried out" || fail "a generic __atomic_load was taken"
printf 'int f(char *p) { return __atomic_fetch_add(p, 1, 5); }\n' > "$ho/.attr.c"
moonrun -t rv64 -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "on a 1-byte object on rv64" || fail "a byte atomic add was laid on rv64"
printf 'int f(int *p) { return __sync_fetch_and_add(p, 1); }\n' > "$ho/.attr.c"
moonrun -t thumb1 -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "on a 4-byte object on thumb1" || fail "an atomic add was laid on thumb1"
# a mode it cannot lay, or cannot place, refuses
printf 'typedef float tf __attribute__((mode(TF)));\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "mode(TF))) is not carried out" || fail "mode(TF) was taken"
printf 'typedef int *pi __attribute__((mode(SI)));\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "on a pointer, array or function declarator" || fail "a mode on a pointer was taken"
printf 'int a __attribute__((mode(DI))), b;\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "on a declaration of several declarators" || fail "a mode on one of two declarators was taken"
printf 'enum e { A = 300 } __attribute__((mode(byte)));\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "does not fit the enum" || fail "an enum too wide for its mode was taken"
# -E spaces as gcc does: where the source did, or where two tokens would paste
cat > "$ho/.esp.c" <<'EOF'
#define P +
#define X Wno
#define CAT(a, b) a ## b
#define NEG(x) -x
-Wno-cast-qual
-X-cast-qual
a+ +b P+ P P x->y a-- -1 1.e+5 0x1p-3 L"wide" 'c'
CAT(-, -) NEG(-1) NEG(x)
f(a,b) [i] {x;} a/ /b  a/ *b
EOF
cat > "$ho/.esp.want" <<'EOF'
-Wno-cast-qual
-Wno-cast-qual
a+ +b + + + + x->y a-- -1 1.e+5 0x1p-3 L"wide" 'c'
-- - -1 -x
f(a,b) [i] {x;} a/ /b a/ *b
EOF
moonrun -E "$ho/.esp.c" | grep -v '^#' | grep -v '^$' | cmp -s - "$ho/.esp.want" || fail "-E spaced tokens gcc keeps joined"
mkdir -p "$ho/.once"
printf '#pragma once\nstruct once { int a; };\n' > "$ho/.once/h.h"
printf '#include "h.h"\n#include "h.h"\nint main(void) { return sizeof (struct once); }\n' > "$ho/.once/m.c"
[ "$(moonrun -E "$ho/.once/m.c" | grep -c 'struct once {')" = 1 ] || fail "#pragma once read the header twice"
mkdir -p "$ho/.once/b"
printf '#include "h.h"\n#include "b/../h.h"\n#include "./h.h"\nint main(void) { return sizeof (struct once); }\n' > "$ho/.once/m2.c"
[ "$(moonrun -E "$ho/.once/m2.c" | grep -c 'struct once {')" = 1 ] || fail "#pragma once read a header twice by two spellings"
moonrun -c -o "$ho/.used.o" test/cc/230-gnuc.c > /dev/null 2>&1 || fail "230-gnuc did not compile"
nm "$ho/.used.o" | grep -q " t kept$" || fail "a used static function was swept"
nm "$ho/.used.o" | grep -q " T thrice$" || fail "gnu_inline's plain inline laid no external definition"
echo "mooncc: GNU C 8 -- bool by dialect, refused attributes named, -E's spacing, the atomics' refusals, mode's refusals, #pragma pack's refusals, #pragma once, used, gnu_inline"

# -- the flags that change the code
# -fshort-wchar: wchar_t and L"" are 16-bit, held to gcc's
cat > "$ho/.sw.c" <<'EOF'
#include <stddef.h>
int main(void) {
  const unsigned short *w = (const unsigned short *) L"h\U0001F600";
  return (int) sizeof (wchar_t) * 10 + (int) (sizeof L"ab" / sizeof (wchar_t)) + (w[1] == 0xd83d && w[2] == 0xde00 && w[3] == 0) * 100; }
EOF
moonrun -fshort-wchar -o "$ho/.sw" "$ho/.sw.c" > /dev/null 2>&1 || fail "-fshort-wchar compile"
"$ho/.sw"; a=$?
$cc_g -O0 -fshort-wchar -o "$ho/.swg" "$ho/.sw.c" > /dev/null 2>&1 && "$ho/.swg"; b=$?
[ $a -eq 123 ] && [ $a -eq $b ] || fail "-fshort-wchar (ours $a gcc $b, want 123)"
# the prefix maps strip the build path from __FILE__
mkdir -p "$ho/.mpm/sub"
printf 'const char *fl(void) { return __FILE__; }\n' > "$ho/.mpm/sub/f.c"
dir=$(cd "$ho/.mpm" && pwd)
for fl in -fmacro-prefix-map -ffile-prefix-map; do
  moonrun -c $fl="$dir/=" -o "$ho/.mpm/f.o" "$dir/sub/f.c" > /dev/null 2>&1 || fail "$fl compile"
  strings "$ho/.mpm/f.o" | grep -qx "sub/f.c" || fail "$fl: __FILE__ is not sub/f.c"
  strings "$ho/.mpm/f.o" | grep -q "$dir" && fail "$fl: the build path reached the object"
done
# -ffixed-x18: never allocated on a64, refused elsewhere
moonrun -t a64 -ffixed-x18 -c -o "$ho/.x18.o" test/cc/111-int128.c > /dev/null 2>&1 || fail "-ffixed-x18 refused on a64"
if command -v llvm-objdump > /dev/null; then
  llvm-objdump -d --no-show-raw-insn "$ho/.x18.o" | grep -E '^ *[0-9a-f]+:' | grep -qwE '[xw]18' \
    && fail "-ffixed-x18: x18 allocated"
else
  gate_partly "  (-ffixed-x18: the allocation check skipped, no llvm-objdump)"
fi
moonrun -ffixed-x18 -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 && fail "-ffixed-x18 taken on x64"
# -mgeneral-regs-only (a64's -mno-sse): a variadic prologue saves no q register, which a kernel traps on
printf '#include <stdarg.h>\nint vs(int n, ...) { va_list a; int s = 0; va_start(a, n); while (n--) s += va_arg(a, int); va_end(a); return s; }\n' > "$ho/.gro.c"
moonrun -t a64 -mgeneral-regs-only -c -o "$ho/.gro.o" "$ho/.gro.c" || fail "-mgeneral-regs-only refused on a64"
if command -v llvm-objdump > /dev/null; then
  llvm-objdump -d --no-show-raw-insn "$ho/.gro.o" | sed -n 's/^ *[0-9a-f]*://p' | grep -qwE '[bhsdqv][0-9]+' \
    && fail "-mgeneral-regs-only: a variadic prologue touched a float register"
else
  gate_partly "  (-mgeneral-regs-only: the register check skipped, no llvm-objdump)"
fi
moonrun -t a64 -ffixed-x20 -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 && fail "-ffixed-x20 was ignored"
echo "mooncc: -fshort-wchar, -fmacro-prefix-map and -ffixed-x18 do what they say, held to gcc"

# -funsigned-char / -fsigned-char: plain char's sign in code, in #if and in the predefines
cat > "$ho/.uch.c" <<'EOF'
#include <limits.h>
#if '\xc8' > 0
#define PP 1
#else
#define PP 0
#endif
#ifdef __CHAR_UNSIGNED__
#define PU 1
#else
#define PU 0
#endif
int main(void) {
  char c = (char) 200, m = -1;
  return (c == 200) + 2 * (CHAR_MIN == 0) + 4 * PU + 8 * (m > 0) + 16 * ('\xc8' == 200) + 32 * PP; }
EOF
for fl in -funsigned-char -fsigned-char; do
  moonrun $fl -o "$ho/.uch" "$ho/.uch.c" > /dev/null 2>&1 || fail "$fl compile"
  "$ho/.uch"; a=$?
  $cc_g -O0 $fl -o "$ho/.uchg" "$ho/.uch.c" > /dev/null 2>&1 && "$ho/.uchg"; b=$?
  [ $a -eq $b ] || fail "$fl: ours $a gcc $b"
done
[ $a -eq 0 ] || fail "-fsigned-char on x64 answered $a, want 0"
cat > "$ho/.sch.c" <<'EOF'
_Static_assert((char) -1 < 0, "signed");
_Static_assert('\xc8' < 0, "a one-char constant");
EOF
moonrun -t a64 -fsigned-char -c -o /dev/null "$ho/.sch.c" > /dev/null 2>&1 || fail "-fsigned-char on a64: char stays unsigned"

# -fno-jump-tables, -fno-builtin, -fno-optimize-sibling-calls, -falign-functions: each changes the object
cat > "$ho/.fl.c" <<'EOF'
int g(int);
int sw(int x) { switch (x) { case 0: return g(3); case 1: return g(9); case 2: return g(1); case 3: return g(7);
  case 4: return g(5); case 5: return g(4); case 6: return g(8); case 7: return g(2); } return 0; }
void *memset(void *, int, unsigned long);
void clr(char *p) { memset(p, 0, 16); }
int tail(int x) { return g(x + 1); }
int al(int x) { return x * 3; }
EOF
fdis() { moonrun -O2 "$@" -c -o "$ho/.fl.o" "$ho/.fl.c" > /dev/null 2>&1 || fail "$* compile"
         objdump -d --no-show-raw-insn "$ho/.fl.o"; }
fdis | grep -q 'jmp *\*' || fail "the switch laid no jump table to begin with"
fdis -fno-jump-tables | grep -q 'jmp *\*' && fail "-fno-jump-tables laid a jump table"
fnm() { fdis "$@" > /dev/null; nm "$ho/.fl.o" | grep -c ' U memset$'; }
[ "$(fnm)" = 0 ] || fail "memset was a call to begin with"
[ "$(fnm -fno-builtin)" = 1 ] || fail "-fno-builtin spliced memset"
[ "$(fnm -fno-builtin-memset)" = 1 ] || fail "-fno-builtin-memset spliced memset"
fdis | grep -A12 '<tail>:' | grep -q 'call' && fail "tail laid a call to begin with"
fdis -fno-optimize-sibling-calls | grep -A12 '<tail>:' | grep -q 'call' || fail "-fno-optimize-sibling-calls jumped to g"
moonrun -falign-functions=64 -c -o "$ho/.fl.o" "$ho/.fl.c" > /dev/null 2>&1 || fail "-falign-functions compile"
for a in $(nm "$ho/.fl.o" | awk '$2 == "T" { print $1 }'); do
  [ $((0x$a % 64)) -eq 0 ] || fail "-falign-functions=64 left a fn at 0x$a"
done
# -mno-red-zone is taken as it stands: no store below sp anywhere in a leaf with locals
printf 'int lf(int a, int b) { int t[4] = { a, b, a + b, a - b }; return t[a & 3] * t[b & 3]; }\n' > "$ho/.rz.c"
moonrun -O2 -mno-red-zone -c -o "$ho/.rz.o" "$ho/.rz.c" > /dev/null 2>&1 || fail "-mno-red-zone compile"
objdump -d "$ho/.rz.o" | grep -q -- '-0x[0-9a-f]*(%rsp)' && fail "-mno-red-zone: a store below sp"
# what mooncc does not honour refuses by name, exit 2
for fl in -mcmodel=large -fno-such-flag -mno-such-flag; do
  moonrun $fl -c -o /dev/null "$ho/.fl.c" > "$ho/.fl.err" 2>&1; r=$?
  [ $r -eq 2 ] && grep -q -- "$fl" "$ho/.fl.err" || fail "$fl: exit $r, not refused by name"
done
moonrun -fno-strict-aliasing -fno-common -fno-pie -fno-asynchronous-unwind-tables -ffunction-sections -mtune=generic \
  -c -o /dev/null "$ho/.fl.c" > /dev/null 2>&1 || fail "a flag taken as it stands was refused"
echo "mooncc: -f[un]signed-char held to gcc, the -f flags that change the object do, the rest refuse by name"

# -ftrivial-auto-var-init=zero: every automatic without an initializer reads zero, over a dirty stack
cat > "$ho/.avz.c" <<'EOF'
struct s { int a[3]; char c; long l; };
__attribute__((noinline)) static void dirty(void) { volatile char b[256]; for (int i = 0; i < 256; i++) b[i] = (char) 0xa5; }
__attribute__((noinline)) static int probe(void) {
  int x; long y; char z[40]; struct s w; double d; int *p;
  int n = x + (int) y + d + (p != 0) + w.c + (int) w.l;
  for (int i = 0; i < 40; i++) n += z[i];
  for (int i = 0; i < 3; i++) n += w.a[i];
  return n; }
int main(void) { dirty(); return probe(); }
EOF
moonrun -ftrivial-auto-var-init=zero -o "$ho/.avz" "$ho/.avz.c" > /dev/null 2>&1 || fail "-ftrivial-auto-var-init=zero compile"
"$ho/.avz" || fail "-ftrivial-auto-var-init=zero left a local unzeroed ($?)"
# ..a VLA's block too, every time its declaration runs
cat > "$ho/.avzv.c" <<'EOF'
__attribute__((noinline)) static void dirty(void) { volatile char b[512]; for (int i = 0; i < 512; i++) b[i] = (char) 0xa5; }
__attribute__((noinline)) static int vla(int n) { char v[n]; int s = 0; for (int i = 0; i < n; i++) s += v[i]; return s; }
int main(void) { int s = 0; for (int k = 1; k < 90; k += 7) { dirty(); s += vla(k); } return s != 0; }
EOF
moonrun -ftrivial-auto-var-init=zero -o "$ho/.avzv" "$ho/.avzv.c" > /dev/null 2>&1 || fail "-ftrivial-auto-var-init=zero compile (a VLA)"
"$ho/.avzv" || fail "-ftrivial-auto-var-init=zero left a VLA unzeroed"
# -fcf-protection=branch: endbr where an indirect branch lands -- an entry another unit or a
# pointer reaches, a table's case, a label whose address is taken, a returns-twice call's return
cat > "$ho/.ibt.c" <<'EOF'
#include <setjmp.h>
int g(int);
static int hid(int x) { return g(x) + 1; }
static int taken(int x) { return x * 2; }
int (*fp)(int) = taken;
int ext(int x) { return hid(x) + hid(x + 1); }
int sw(int x) { switch (x) { case 0: return g(3); case 1: return g(9); case 2: return g(1); case 3: return g(7);
  case 4: return g(5); case 5: return g(4); case 6: return g(8); case 7: return g(2); } return 0; }
int cg(int i) { static void *t[] = { &&a, &&b }; goto *t[i & 1]; a: return 1; b: return 2; }
jmp_buf jb;
int sj(void) { if (setjmp(jb)) return 1; return g(0); }
EOF
moonrun -fno-inline -fcf-protection=branch -c -o "$ho/.ibt.o" "$ho/.ibt.c" > /dev/null 2>&1 || fail "-fcf-protection=branch compile"
objdump -d --no-show-raw-insn "$ho/.ibt.o" > "$ho/.ibt.d"
ibt() { awk -v f="<$1>:" '$2 == f { on = 1; next } /^[0-9a-f]+ </ { on = 0 } on && /endbr64/ { n++ } END { print n + 0 }' "$ho/.ibt.d"; }
[ "$(ibt hid)" = 0 ] || fail "-fcf-protection: a static fn no pointer reaches landed an endbr"
for f in taken ext; do [ "$(ibt $f)" = 1 ] || fail "-fcf-protection: $f has no endbr at its entry"; done
[ "$(ibt sw)" -ge 9 ] || fail "-fcf-protection: a jump table's cases land without endbr ($(ibt sw))"
[ "$(ibt cg)" = 3 ] || fail "-fcf-protection: a computed goto's labels land without endbr ($(ibt cg))"
[ "$(ibt sj)" = 2 ] || fail "-fcf-protection: setjmp's return lands without endbr"
readelf -n "$ho/.ibt.o" | grep -q 'x86 feature: IBT$' || fail "-fcf-protection=branch: no IBT mark"
moonrun -fcf-protection=full -c -o "$ho/.ibt.o" "$ho/.ibt.c" > /dev/null 2>&1 || fail "-fcf-protection=full compile"
readelf -n "$ho/.ibt.o" | grep -q 'x86 feature: IBT, SHSTK' || fail "-fcf-protection=full: no IBT, SHSTK mark"
moonrun -t i386 -fcf-protection=branch -c -o "$ho/.ibt.o" "$ho/.ibt.c" > /dev/null 2>&1 || fail "-fcf-protection=branch on i386"
objdump -d "$ho/.ibt.o" | grep -q endbr32 || fail "-fcf-protection on i386 laid no endbr32"
[ "$(printf '__CET__\n' | moonrun -fcf-protection -E - | tail -1 | tr -d ' ')" = 3 ] || fail "-fcf-protection: __CET__ is not 3"
moonrun -t a64 -fcf-protection=branch -c -o /dev/null "$ho/.ibt.c" > /dev/null 2>&1 && fail "-fcf-protection taken on a64"
echo "mooncc: -ftrivial-auto-var-init=zero zeroes every automatic, -fcf-protection lands every indirect branch on endbr"

# -fwrapv and -fno-strict-overflow: an int's + - * << and - wrap at 32 bits in every lane (an
# immediate, a register pair, the shuttle, a shift, a fold, a loop's counter), held to gcc's
cat > "$ho/.wv.c" <<'EOF'
#include <stdio.h>
#include <limits.h>
#define N __attribute__((noinline))
N long add1(int x) { return (long) (x + 1); }
N long addv(int x, int y) { return (long) (x + y); }
N long subv(int x, int y) { return (long) (x - y); }
N long mulv(int x, int y) { return (long) (x * y); }
N int  half(int x) { return (x * 2) / 2; }
N int  gt(int x) { return x + 1 > x; }
N long mul3(int x) { return (long) (x * 3); }
N long mul8(int x) { return (long) (x * 8); }
N long mul10(int x) { return (long) (x * 10); }
N long shl1(int x) { return (long) (x << 1); }
N long neg(int x) { return (long) -x; }
N long preinc(int x) { long l = ++x; return l; }
N long pluseq(int x) { return (long) (x += 1); }
N long sum(int *a, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i]; return (long) s; }
N long idx(int x) { static char b[16]; char *p = b + 8; return (long) ((p + (x + 1)) - b); }
N long tern(int x, int c) { return (long) (c ? x + 1 : x - 1); }
N long kfold(void) { int m = INT_MAX; return (long) (m + 1); }
N unsigned long sh(int x) { return (unsigned long) (x + x) >> 1; }
int main(void) {
  int a[3] = { INT_MAX, 1, 1 };
  long r[] = { add1(INT_MAX), addv(INT_MAX, 1), subv(INT_MIN, 1), mulv(65536, 65536), half(INT_MAX), gt(INT_MAX),
               mul3(INT_MAX), mul8(INT_MAX), mul10(INT_MAX), shl1(INT_MAX), neg(INT_MIN), preinc(INT_MAX), pluseq(INT_MAX),
               sum(a, 3), tern(INT_MAX, 1), tern(INT_MIN, 0), kfold(), (long) sh(INT_MAX) };
  unsigned h = 0;
  for (unsigned i = 0; i < sizeof r / sizeof *r; i++) { printf("%u %ld\n", i, r[i]); h = h * 31 + (unsigned) r[i] + (unsigned) (r[i] >> 32); }
  return h & 255; }
EOF
cat > "$ho/.wvl.c" <<'EOF'
#define N __attribute__((noinline))
N int iv(int s) { int c = 0; for (int i = s; i > 0 && c < 10; i++) c++; return c; }
N int iv2(int s) { int c = 0; for (int i = s; i > 0; i += 1000000000) c++; return c; }
N long ar(int s) { int a[4] = { 0 }; long t = 0; for (int i = s; i >= s - 3 && i < s + 9; i--) t += (long) i; return t; }
int main(void) { return iv(2147483645) * 10 + iv2(1) + (ar(-2147483647) == 2 ? 100 : 0); }
EOF
$cc_g -O2 -fwrapv -o "$ho/.wvg" "$ho/.wv.c" > /dev/null 2>&1 && "$ho/.wvg" > "$ho/.wvg.txt"
for fl in -fwrapv -fno-strict-overflow; do
  moonrun $fl -o "$ho/.wv" "$ho/.wv.c" > /dev/null 2>&1 || fail "$fl compile"
  "$ho/.wv" | cmp -s - "$ho/.wvg.txt" || fail "$fl: an int's arithmetic answers other than gcc -fwrapv's"
done
moonrun -fwrapv -o "$ho/.wvl" "$ho/.wvl.c" > /dev/null 2>&1 || fail "-fwrapv compile (a loop)"
"$ho/.wvl"; a=$?
$cc_g -O2 -fwrapv -o "$ho/.wvlg" "$ho/.wvl.c" > /dev/null 2>&1 && "$ho/.wvlg"; b=$?
[ $a -eq 33 ] && [ $a -eq $b ] || fail "-fwrapv: a counter past INT_MAX (ours $a gcc $b, want 33)"
echo "mooncc: -fwrapv wraps an int's arithmetic at 32 bits in every lane, held to gcc"

# -fpatchable-function-entry=N,M: N nops, M ahead of the entry, a word to each pad's start in
# __patchable_function_entries; the attribute overrides per fn, (0,0) being the kernel's notrace
cat > "$ho/.pfe.c" <<'EOF'
int g(int);
int f(int x) { return g(x) + 1; }
__attribute__((patchable_function_entry(0, 0))) int nt(int x) { return g(x) * 2; }
__attribute__((patchable_function_entry(3, 1))) int own(int x) { return g(x) - 3; }
EOF
pfe() { awk -v f="<$1>:" '$2 == f { on = 1; next } /^[0-9a-f]+ </ { on = 0 } on { print $2 }' "$ho/.pfe.d" | head -"$2" | tr '\n' ' '; }
moonrun -fpatchable-function-entry=4,2 -c -o "$ho/.pfe.o" "$ho/.pfe.c" > /dev/null 2>&1 || fail "-fpatchable-function-entry compile"
objdump -d --no-show-raw-insn "$ho/.pfe.o" > "$ho/.pfe.d"
[ "$(pfe f 2)" = "nop nop " ] || fail "-fpatchable-function-entry=4,2: f does not open on 2 nops ($(pfe f 2))"
[ "$(pfe nt 1)" != "nop " ] || fail "patchable_function_entry(0,0) still padded nt"
[ "$(pfe own 2)" = "nop nop " ] || fail "patchable_function_entry(3,1): own does not open on 2 nops"
# a word per padded fn, each at its fn's entry less its pre-nops: f at -2, own at -1
readelf -rW "$ho/.pfe.o" | awk '/__patchable_function_entries/ { on = 1; next } /^Relocation section/ { on = 0 } on && /R_X86_64_64/ { print $NF }' > "$ho/.pfe.r"
[ "$(wc -l < "$ho/.pfe.r")" = 2 ] || fail "-fpatchable-function-entry: $(wc -l < "$ho/.pfe.r") entries, want 2 (nt has none)"
for fn in f:2 own:1; do
  a=$(nm "$ho/.pfe.o" | awk -v n="${fn%:*}" '$3 == n { print $1 }')
  grep -qx "$(printf %x $((0x$a - ${fn#*:})))" "$ho/.pfe.r" || fail "-fpatchable-function-entry: no entry at ${fn%:*}'s pad"
done
moonrun -t a64 -mbranch-protection=bti -fpatchable-function-entry=2 -c -o "$ho/.pfe.o" "$ho/.pfe.c" > /dev/null 2>&1 || fail "-fpatchable-function-entry on a64"
if command -v llvm-objdump > /dev/null; then
  llvm-objdump -d --no-show-raw-insn "$ho/.pfe.o" > "$ho/.pfe.d"
  [ "$(pfe f 3)" = "bti nop nop " ] || fail "-fpatchable-function-entry=2 on a64: f opens on $(pfe f 3), not bti nop nop"
fi
moonrun -t rv64 -fpatchable-function-entry=2 -c -o /dev/null "$ho/.pfe.c" > /dev/null 2>&1 || fail "-fpatchable-function-entry on rv64"
moonrun -t thumb2 -fpatchable-function-entry=2 -c -o /dev/null "$ho/.pfe.c" > /dev/null 2>&1 && fail "-fpatchable-function-entry taken on thumb2"
moonrun -fpatchable-function-entry=1,2 -c -o /dev/null "$ho/.pfe.c" > /dev/null 2>&1 && fail "-fpatchable-function-entry=1,2 taken"
echo "mooncc: -fpatchable-function-entry lays each fn's nop pad and its word, the attribute per fn"

# -fstack-protector-strong: a canary under the frame link, set from the guard at entry and
# checked on every way out; an overflow reaches __stack_chk_fail, a fair run answers as without
cat > "$ho/.ssp.c" <<'EOF'
#include <string.h>
#include <unistd.h>
unsigned long __stack_chk_guard = 0x5a5aa5a5deadbeefUL;
void __stack_chk_fail(void) { _exit(42); }
__attribute__((noinline)) int sum(const char *s) { char b[16]; strcpy(b, s); int t = 0; for (int i = 0; b[i]; i++) t += b[i]; return t; }
__attribute__((noinline)) int vla(int n) { int a[n]; for (int i = 0; i < n; i++) a[i] = i; int t = 0; for (int i = 0; i < n; i++) t += a[i]; return t; }
__attribute__((noinline)) void adr(int *p) { *p += 1; }
__attribute__((noinline)) int tk(int x) { adr(&x); return x; }
int main(int argc, char **argv) { return (sum(argc > 1 ? argv[1] : "hello") + vla(10) + tk(4)) & 127; }
EOF
moonrun -fstack-protector-strong -o "$ho/.ssp" "$ho/.ssp.c" > /dev/null 2>&1 || fail "-fstack-protector-strong compile"
"$ho/.ssp"; a=$?
$cc_g -O2 -fno-stack-protector -o "$ho/.sspgc" "$ho/.ssp.c" > /dev/null 2>&1 && "$ho/.sspgc"; b=$?
[ $a -eq $b ] || fail "-fstack-protector-strong: a fair run answers $a, gcc $b"
"$ho/.ssp" AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA; a=$?
[ $a -eq 42 ] || fail "-fstack-protector-strong: an overflow exits $a, not through __stack_chk_fail"
# which fns: -strong takes an array, a VLA, an address taken; -all every fn; the attributes per fn
cat > "$ho/.sspw.c" <<'EOF'
int g(int *);
int plain(int x) { return x * 3; }
int arr(int x) { int a[2] = { x, x }; return g(a); }
int adr(int x) { return g(&x); }
__attribute__((no_stack_protector)) int nsp(int x) { int a[2] = { x, x }; return g(a); }
__attribute__((stack_protect)) int sp(int x) { return x + 1; }
EOF
sspw() {        # FLAGS.. -> the fns that read the guard
  moonrun "$@" -c -o "$ho/.sspw.o" "$ho/.sspw.c" > /dev/null 2>&1 || { echo compile; return; }
  objdump -dr "$ho/.sspw.o" | awk '/^[0-9a-f]+ </ { f = $2 } /__stack_chk_guard/ { print f }' | sort -u | tr -d '<>:' | tr '\n' ' '
}
[ "$(sspw -fstack-protector-strong)" = "adr arr sp " ] || fail "-fstack-protector-strong guards $(sspw -fstack-protector-strong), not adr arr sp"
[ "$(sspw -fstack-protector-all)" = "adr arr plain sp " ] || fail "-fstack-protector-all guards $(sspw -fstack-protector-all)"
[ "$(sspw -fstack-protector-explicit)" = "sp " ] || fail "-fstack-protector-explicit guards $(sspw -fstack-protector-explicit)"
[ "$(sspw)" = "" ] || fail "no -fstack-protector, and $(sspw) read the guard"
# the guard's modes: x86 off a segment (the kernel's gs and a symbol), a64 off a system register
moonrun -fstack-protector-all -mstack-protector-guard-reg=gs -mstack-protector-guard-symbol=__ref_stack_chk_guard \
  -c -o "$ho/.sspw.o" "$ho/.sspw.c" > /dev/null 2>&1 || fail "-mstack-protector-guard-reg=gs compile"
objdump -dr "$ho/.sspw.o" | grep -q '%gs:' && objdump -dr "$ho/.sspw.o" | grep -q '__ref_stack_chk_guard' ||
  fail "-mstack-protector-guard-reg=gs -symbol=: no %gs: load of the symbol"
moonrun -fstack-protector-all -mstack-protector-guard=tls -c -o "$ho/.sspw.o" "$ho/.sspw.c" > /dev/null 2>&1 || fail "-mstack-protector-guard=tls compile"
objdump -d "$ho/.sspw.o" | grep -q '%fs:' && objdump -d "$ho/.sspw.o" | grep -q '\$0x28,' || fail "-mstack-protector-guard=tls: not off %fs:0x28"
moonrun -t i386 -fstack-protector-all -mstack-protector-guard-reg=fs -mstack-protector-guard-symbol=__stack_chk_guard \
  -c -o /dev/null "$ho/.sspw.c" > /dev/null 2>&1 || fail "-fstack-protector on i386"
moonrun -t a64 -fstack-protector-all -mstack-protector-guard=sysreg -mstack-protector-guard-reg=sp_el0 \
  -mstack-protector-guard-offset=1024 -c -o "$ho/.sspw.o" "$ho/.sspw.c" > /dev/null 2>&1 || fail "-mstack-protector-guard=sysreg on a64"
if command -v llvm-objdump > /dev/null; then
  llvm-objdump -d "$ho/.sspw.o" | grep -qi 'mrs.*sp_el0' && llvm-objdump -d "$ho/.sspw.o" | grep -q '#0x400\]' ||
    fail "-mstack-protector-guard=sysreg: no sp_el0 load at 1024"
fi
for fl in "-t rv64" "-mstack-protector-guard-reg=es" "-t a64 -mstack-protector-guard=tls" "-t a64 -mstack-protector-guard=sysreg -mstack-protector-guard-reg=sp_el0 -mstack-protector-guard-offset=4"; do
  moonrun $fl -fstack-protector-strong -c -o /dev/null "$ho/.sspw.c" > /dev/null 2>&1; r=$?
  [ $r -eq 2 ] || fail "-fstack-protector-strong $fl: exit $r, not refused"
done
echo "mooncc: -fstack-protector guards the fns its level names, an overflow reaches __stack_chk_fail, the guard's modes"

# the x86-64 kernel's -m set: -mcmodel=kernel and -mno-fp-ret-in-387 ask nothing of x64's code
# (rip-relative, abs64 words, long double in xmm0); -mskip-rax-setup leaves al unset at a
# varargs call; -mstack-alignment=8 realigns a 16-aligned local; the thunk asks send every
# indirect branch through __x86_indirect_thunk_REG and every return through __x86_return_thunk
cat > "$ho/.r3.c" <<'EOF'
int pf(const char *, ...);
int h(int);
extern int (*fp)(int);
__attribute__((noinline)) void va(long x) { pf("", x); }
__attribute__((noinline)) int sum16(int n) { int a[4] __attribute__((aligned(16))) = { n, n + 1, n + 2, n + 3 }; int *p = a; return ((unsigned long)p & 15) ? -1 : p[0] + p[1] + p[2] + p[3]; }
__attribute__((noinline)) int cl(int x) { return fp(x) + 1; }
__attribute__((noinline)) int tl(int x) { return fp(x); }
__attribute__((noinline)) int pr(int (*q)(int), int x) { return q(x) * 2; }
__attribute__((noinline)) int sw(int x) { switch (x) { case 0: return h(3); case 1: return 7; case 2: return h(9); case 3: return 11; case 4: return 2; case 5: return h(1); case 6: return 5; } return 0; }
EOF
moonrun -c -o "$ho/.r3a.o" "$ho/.r3.c" > /dev/null 2>&1 || fail "r3: plain compile"
moonrun -mcmodel=kernel -mno-fp-ret-in-387 -mno-red-zone -mcmodel=small -mindirect-branch=keep -mfunction-return=keep \
  -c -o "$ho/.r3b.o" "$ho/.r3.c" > /dev/null 2>&1 || fail "r3: -mcmodel=kernel -mno-fp-ret-in-387 compile"
cmp -s "$ho/.r3a.o" "$ho/.r3b.o" || fail "r3: -mcmodel=kernel -mno-fp-ret-in-387 changed x64's code"
r3fn() {        # OBJ FN -> FN's disassembly, one insn a line
  objdump -dr --no-show-raw-insn "$1" | awk -v f="<$2>:" '$2 == f { on = 1; next } /^[0-9a-f]+ </ { on = 0 } on'
}
r3fn "$ho/.r3a.o" va | grep -q '%eax' || fail "r3: a varargs call sets no al"
moonrun -mskip-rax-setup -c -o "$ho/.r3b.o" "$ho/.r3.c" > /dev/null 2>&1 || fail "r3: -mskip-rax-setup compile"
r3fn "$ho/.r3b.o" va | grep -q '%eax' && fail "-mskip-rax-setup: va still sets al"
moonrun -mstack-alignment=8 -c -o "$ho/.r3b.o" "$ho/.r3.c" > /dev/null 2>&1 || fail "r3: -mstack-alignment=8 compile"
r3fn "$ho/.r3a.o" sum16 | grep -q 'and .*0xfffffffffffffff0' && fail "r3: a 16-aligned local realigned on a 16-aligned stack"
r3fn "$ho/.r3b.o" sum16 | grep -q 'and .*0xfffffffffffffff0' || fail "-mstack-alignment=8: sum16's aligned local is not realigned"
cmp -s "$ho/.r3a.o" "$ho/.r3b.o" && fail "-mstack-alignment=8 changed nothing"
printf 'int f(int n) { __int128 a[n]; a[0] = n; return (int)a[0]; }\n' > "$ho/.r3v.c"
moonrun -mstack-alignment=8 -c -o /dev/null "$ho/.r3v.c" > /dev/null 2>&1 && fail "-mstack-alignment=8 took a VLA of 16-aligned elements"
th="-mindirect-branch=thunk-extern -mfunction-return=thunk-extern -mindirect-branch-register -mindirect-branch-cs-prefix"
moonrun $th -c -o "$ho/.r3b.o" "$ho/.r3.c" > /dev/null 2>&1 || fail "r3: the thunk asks compile"
objdump -d --no-show-raw-insn "$ho/.r3b.o" > "$ho/.r3b.d"
grep -Eq '(call|jmp) +\*|[[:space:]]ret$' "$ho/.r3b.d" && fail "r3: an indirect branch or a ret outside the thunks: $(grep -E '(call|jmp) +\*|[[:space:]]ret$' "$ho/.r3b.d" | head -1)"
objdump -r "$ho/.r3b.o" | grep -q '__x86_indirect_thunk_' || fail "r3: no __x86_indirect_thunk_ call"
objdump -r "$ho/.r3b.o" | grep -q '__x86_return_thunk' || fail "r3: no __x86_return_thunk jump"
# ..and a run: thunks that branch plainly answer as the unthunked build
cat > "$ho/.r3m.c" <<'EOF'
int pf(const char *s, ...) { return s[0]; }
int h(int x) { return x * 5; }
int (*fp)(int) = h;
void va(long);
int sum16(int), cl(int), tl(int), pr(int (*)(int), int), sw(int);
__asm__(".globl __x86_return_thunk\n__x86_return_thunk: ret\n"
        ".irp r,rax,rcx,rdx,rbx,rbp,rsi,rdi,r8,r9,r10,r11,r12,r13,r14,r15\n"
        ".globl __x86_indirect_thunk_\\r\n__x86_indirect_thunk_\\r: jmp *%\\r\n.endr\n");
int main(void) { int t = 0; va(3); for (int i = 0; i < 8; i++) t += sw(i); return (t + sum16(4) + cl(2) + tl(3) + pr(h, 1)) & 127; }
EOF
$cc_g -O2 -o "$ho/.r3g" "$ho/.r3m.c" "$ho/.r3.c" > /dev/null 2>&1 && "$ho/.r3g"; b=$?
moonrun $th -mstack-alignment=8 -mskip-rax-setup -o "$ho/.r3" "$ho/.r3m.c" "$ho/.r3.c" > /dev/null 2>&1 || fail "r3: the thunked link"
"$ho/.r3"; a=$?
[ $a -eq $b ] || fail "r3: the thunked run answers $a, gcc $b"
for fl in "-mcmodel=large" "-mcmodel=medium" "-mstack-alignment=4" "-mindirect-branch=thunk" "-mfunction-return=thunk-inline" \
          "-t a64 -mskip-rax-setup" "-t i386 -mno-fp-ret-in-387" "-t i386 -mindirect-branch=thunk-extern"; do
  moonrun $fl -c -o /dev/null "$ho/.r3.c" > /dev/null 2>&1; r=$?
  [ $r -eq 2 ] || fail "r3: $fl: exit $r, not refused"
done
echo "mooncc: the x86-64 kernel's -m set: the code model, al, the 8-aligned stack, the retpoline and return thunks"

# -- C11 conditional features (6.10.8.3), per target
# ours alone (gcc has atomics): a claimed absence sends portable code down a fallback
# cok/cno TGT SRC MSG: mooncc -t TGT builds (cok) or refuses (cno) the printf format SRC
cok() { printf "$2" > "$ho/.feat.c"; moonrun -c -t "$1" -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 || fail "$3"; }
cno() { printf "$2" > "$ho/.feat.c"; moonrun -c -t "$1" -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 && fail "$3"; }
c11feat() {                        # TGT MACRO want(1 present | 0 absent)
  if [ "$3" = 1 ]; then b="#ifndef $2"; else b="#ifdef $2"; fi
  cok "$1" "$b\n#error no\n#endif\nint m(void){return 0;}\n" "C11 feature macro $2 on $1 (want present=$3)"
}
for t in x64 a64 rv64 thumb2 thumb2sp thumb1 arm; do
  for mac in __STDC_NO_ATOMICS__ __STDC_NO_THREADS__ __STDC_UTF_16__ __STDC_UTF_32__; do
    c11feat "$t" "$mac" 1
  done
  case $t in x64|a64|thumb2|thumb2sp|arm) c11feat "$t" __STDC_NO_VLA__ 0 ;; *) c11feat "$t" __STDC_NO_VLA__ 1 ;; esac
  case $t in x64|a64|thumb2|arm)          c11feat "$t" __STDC_NO_COMPLEX__ 0 ;; *) c11feat "$t" __STDC_NO_COMPLEX__ 1 ;; esac
done
# a TU of only a _Static_assert compiles; a failing one refuses
cok x64 '_Static_assert(1, "ok");' "a TU of one _Static_assert"
cno x64 '_Static_assert(0, "boom");' "a FAILING lone _Static_assert passed"

# C11 6.5.16.1: an int reaches a pointer only as a null pointer constant
cno x64 'struct s;\nstatic struct s *f(int x){ if (x) return 1; return 0; }\nint m(void){return 0;}\n' "an int returned where a pointer is owed was accepted"
cok x64 'struct s;\nstatic struct s *f(int x){ if (x) return (struct s*)1; return 0; }\nint m(void){return 0;}\n' "a CAST to the pointer type must still pass"

# a file-scope bound that does not fold refuses by name, never laid as a pointer's worth
printf 'int n = 3;\nstatic int x[n];\nstruct S { int a[4]; };\nint i;\nchar y[__builtin_offsetof(struct S, a[i])];\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" 2>&1 | grep -q "variably modified 'x' at file scope" \
  || fail "a variably modified object at file scope was not refused by name"
cno x64 'struct S { int a[4]; };\nint i;\nchar y[__builtin_offsetof(struct S, a[i])];\n' "a runtime offsetof as a file-scope bound was accepted"

# cleanup refuses what it cannot carry: a dropped call is a lock never released
clref() {
  printf "$1" > "$ho/.feat.c"
  moonrun -c -t x64 -o /dev/null "$ho/.feat.c" 2>&1 | grep -q "$2" || fail "cleanup: $3"
}
clref 'static void d(int *p){ (void)p; }\nint m(int x){ if (x) goto in; { int k __attribute__((cleanup(d))) = 1; in: return k; } }\n' \
  "a jump into the scope of a cleanup variable" "a goto into the scope was not refused"
clref 'static void d(int *p){ (void)p; }\nint m(int x){ switch (x) { int k __attribute__((cleanup(d))) = 1; case 1: return k; } return 0; }\n' \
  "a jump into the scope of a cleanup variable" "a case into the scope was not refused"
clref 'static void d(int *p){ (void)p; }\nint m(void){ int __attribute__((cleanup(d))) a = 1, b = 2; return a + b; }\n' \
  "a cleanup wants one automatic variable" "the specifiers of two declarators were not refused"
clref 'static void d(int *p){ (void)p; }\nint m(void){ static int k __attribute__((cleanup(d))) = 1; return k; }\n' \
  "a cleanup wants one automatic variable" "a static was not refused"
clref 'static void d(int *p){ (void)p; }\nint g __attribute__((cleanup(d)));\nint m(void){ return g; }\n' \
  "cleanup)) is not carried out" "file scope was skipped"

# file-scope asm refuses by name what it cannot lay: an unread directive, cross-section
# label arithmetic, a `- .` word on arm32, any on wasm
taref() {
  printf "$1" > "$ho/.feat.c"
  moonrun -c -t "$2" -o /dev/null "$ho/.feat.c" 2>&1 | grep -q "$3" || fail "file-scope asm: $4"
}
taref 'asm(".uleb128 5");\n' x64 "gas-directive" "an unread directive was not refused"
taref 'asm(".data\\na: .long a - b\\n.text\\nb:");\n' x64 "gas-data" "a label difference across sections was not refused"
taref 'int f(void){return 0;}\nasm(".data\\n.long f - .");\n' thumb2 "gas-data-pcrel" "a pc-relative word on arm32 was not refused"
taref 'asm(".data\\n.byte 1");\n' wasm "no wasm lane" "the wasm lane took a file-scope asm"
# an "i" operand must be constant: not a local, nor a global a local shadows
taref 'int f(int b){asm("# %%0" : : "i"(b)); return 0;}\n' x64 "not a constant" "a local as an \"i\" operand was not refused"
taref 'int g;\nint f(void){int g = 1; g++; asm("# %%c0" : : "i"(&g)); return g;}\n' x64 "not a constant" "a shadowed global as an \"i\" operand was not refused"
taref 'asm(".data\\n2: .quad 0\\n.org 2b + 4");\n' x64 "gas-org" "an .org behind its section was not refused"
# a reached .error refuses by name
taref 'asm(".set .Lx, 2\\n.if (.Lx != 1)\\n.error \\"bad\\"\\n.endif");\n' x64 "gas-error" "a reached .error was not refused"
# a flag output has an x64 lane only
taref 'int f(long x){int z; asm("cmp %%1, #0" : "=@cceq"(z) : "r"(x)); return z;}\n' a64 "an asm flag output" "an a64 flag output was not refused by name"
# a %gs: store to an absolute address has no register to reach it through
taref 'void f(long x){asm volatile("movq %%0, %%%%gs:40" : : "r"(x));}\n' x64 "gas-x64-seg" "a gs store to an absolute address was not refused"
# opcodes 64-bit mode dropped refuse by name
taref 'void f(void){asm volatile("lcallw $0xc000,$3");}\n' x64 "\"lcallw\", which 64-bit mode has no encoding for" "a direct far call was not refused by name"
taref 'void f(void){asm volatile("pusha");}\n' x64 "\"pusha\", which 64-bit mode" "pusha was not refused by name"

# a .s is its own file-scope asm; a .S is preprocessed first (include, macros, #if,
# numeric labels)
if [ "$(uname -m)" = x86_64 ]; then
cat > "$ho/.as1.s" <<'EOF'
	.text
	.globl	ans
ans:	movl	$40, %eax
	addl	two(%rip), %eax
	ret
	.data
two:	.long	2
EOF
cat > "$ho/.as2.h" <<'EOF'
#define TWO 2
#define GLOBAL(n) .globl n ; n:
EOF
cat > "$ho/.as2.S" <<'EOF'
#include ".as2.h"
	.text
GLOBAL(sum)		// 1..n doubled, n in %rdi
	xorl	%eax, %eax
1:	testq	%rdi, %rdi	# a gas comment
	je	2f
	addq	%rdi, %rax
	decq	%rdi
	jmp	1b
2:
#if TWO > 1
	imulq	$TWO, %rax, %rax
#endif
	ret
EOF
printf 'int ans(void); long sum(long);\nint main(void){ return ans() == 42 && sum(5) == 30 ? 0 : 1; }\n' > "$ho/.asm.c"
moonrun -o "$ho/.asm" "$ho/.asm.c" "$ho/.as1.s" "$ho/.as2.S" > /dev/null 2>&1 || fail "a .s and a .S did not build"
"$ho/.asm" || fail "a .s and a .S built, and answered wrong"
fi

# a .S's header is assembly too: lines keep their breaks, `\name` is a macro argument,
# `wx\n` is one word; on arm a `#` past code is an immediate, not a comment
cat > "$ho/.as3.h" <<'EOF'
	.irp	num,0,1,2
	.equ	.L__gpr_num_x\num, \num
	.endr
	.macro	ext, insn, fixup, uaccess_is_write
	.pushsection __ex_table, "a"; .long ((\insn) - .); .long ((\fixup) - .); .short (\uaccess_is_write); .popsection
	.endm
	.irp	n,0,1,2
wx\n	.req	w\n
	.endr
	.macro	lsz, reg, tmp
	ubfm	\tmp, \tmp, #16, #19
	mov	\reg, #4
	add	\reg, \reg, #3
	.endm
EOF
cat > "$ho/.as3.S" <<'EOF'
#include ".as3.h"
	.text
g:	lsz	x0, x1
	lsl	x0, x0, #2
	.globl	f
f:	mov	wx1, wx2
1:	ret
	ext	f, 1b, .L__gpr_num_x2
EOF
moonrun -c -t a64 -o "$ho/.as3.o" "$ho/.as3.S" > /dev/null 2>&1 || fail "a .S whose header holds gas macros did not assemble"
readelf -SW "$ho/.as3.o" 2>/dev/null | grep -q __ex_table || fail "a .S's header macro laid no __ex_table"
readelf -x .text "$ho/.as3.o" 2>/dev/null | grep -q "214c50d3 800080d2 000c0091 00f47ed3" \
  || fail "a .S's arm immediates were not laid as written"
# tbz's 14-bit field: a label past it refuses; an outside target is a TSTBR14
printf '1:\n\t.rept 8193\n\tnop\n\t.endr\n\ttbz x0, #1, 1b\n' > "$ho/.tbz.s"
moonrun -c -t a64 -o "$ho/.tbz.o" "$ho/.tbz.s" > /dev/null 2>&1 && fail "a tbz past its 14-bit field was laid"
printf '\t.globl f\nf:\ttbz x0, #3, ext\n\tret\n' > "$ho/.tbz.s"
moonrun -c -t a64 -o "$ho/.tbz.o" "$ho/.tbz.s" > /dev/null 2>&1 || fail "a tbz to an outside label did not assemble"
readelf -rW "$ho/.tbz.o" 2>/dev/null | grep -q "R_AARCH64_TSTBR14.*ext" || fail "a tbz to an outside label laid no TSTBR14"
# a branch in a section without x resolves in place, no relocation
printf '\t.pushsection .idmap.text, "a"\n1:\tnop\n\tcbnz w1, 1b\n\tb.ne 1b\n\ttbz w1, #1, 1b\n\tb 1b\n\t.popsection\n' > "$ho/.dbr.s"
moonrun -c -t a64 -o "$ho/.dbr.o" "$ho/.dbr.s" > /dev/null 2>&1 || fail "branches in a data section did not assemble"
readelf -rW "$ho/.dbr.o" 2>/dev/null | grep -q R_AARCH64 && fail "a branch inside a data section laid a relocation"
readelf -x .idmap.text "$ho/.dbr.o" 2>/dev/null | grep -q "1f2003d5 e1ffff35 c1ffff54 a1ff0f36" \
  || fail "branches inside a data section were not resolved in place"
# .incbin, whole or skip/count, found through -I; a `//` in a string is no comment
mkdir -p "$ho/.incd" && printf 'ABCDEFGHIJ' > "$ho/.incd/.inc.bin"
printf '\t.section .rodata\n\t.incbin ".inc.bin"\n\t.incbin ".inc.bin", 2, 3\n\t.ascii "a//b"\n' > "$ho/.inc.S"
moonrun -c -t a64 -I "$ho/.incd" -o "$ho/.inc.o" "$ho/.inc.S" > /dev/null 2>&1 || fail "an .incbin did not assemble"
readelf -x .rodata "$ho/.inc.o" 2>/dev/null | grep -q "41424344 45464748 494a4344 45612f2f" \
  || fail "an .incbin's bytes were not laid as llvm-mc lays them"
moonrun -c -t a64 -o "$ho/.inc.o" "$ho/.inc.S" > /dev/null 2>&1 && fail "an .incbin of a file nowhere on the path was laid"
# ..and in a C file's file-scope asm (kernel/configs.c)
printf 'asm(".pushsection .rodata, \\"a\\"\\n.globl blob\\nblob:\\n.incbin \\".inc.bin\\", 2, 4\\n.globl blob_end\\nblob_end:\\n.popsection\\n");\nextern const char blob[], blob_end[];\nint main(void){ return (int)(blob_end - blob) * 10 + blob[3] - 70; }\n' > "$ho/.incc.c"
moonrun -I "$ho/.incd" -o "$ho/.incc" "$ho/.incc.c" > /dev/null 2>&1 || fail "a C file's asm .incbin did not compile"
"$ho/.incc"; a=$?
[ $a -eq 40 ] || fail "a C file's asm .incbin laid other bytes (got $a want 40)"
# a .S spells v0.16b back as one word: a macro argument keeps its arrangement (ghash-ce-core)
printf '\t.macro vadd, rq, ad\n\tadd \\rq\\().16b, \\ad, v1.16b\n\t.endm\n\tvadd v10, v0.16b\n' > "$ho/.asp.S"
moonrun -c -t a64 -o "$ho/.asp.o" "$ho/.asp.S" > /dev/null 2>&1 || fail "a .S macro argument v0.16b did not assemble"
readelf -x .text "$ho/.asp.o" 2>/dev/null | grep -q "0a84214e" || fail "a .S macro argument v0.16b was not laid as llvm-mc lays it"

# an asm .weak through an alias chain: a strong definition wins the link, alone the weak one is taken
printf '__asm__(".text\\n.weak pick\\n.weak __pick\\n.set pick, __pick\\n.globl __pick\\n.set __pick, opick\\nopick: mov $1, %%eax\\n ret\\n");\nint pick(void);\nint main(void){ return pick(); }\n' > "$ho/.wka.c"
printf 'int pick(void){ return 2; }\n' > "$ho/.wkb.c"
moonrun -c -o "$ho/.wka.o" "$ho/.wka.c" > /dev/null 2>&1 && moonrun -c -o "$ho/.wkb.o" "$ho/.wkb.c" > /dev/null 2>&1 \
  || fail "an asm .weak alias chain did not compile"
moonrun -o "$ho/.wk" "$ho/.wka.o" "$ho/.wkb.o" > /dev/null 2>&1 || fail "a strong definition beside an asm .weak did not link"
"$ho/.wk"; a=$?
[ $a -eq 2 ] || fail "an asm .weak beat a strong definition (got $a want 2)"
moonrun -o "$ho/.wk" "$ho/.wka.o" > /dev/null 2>&1 || fail "an asm .weak alone did not link"
"$ho/.wk"; a=$?
[ $a -eq 1 ] || fail "an asm .weak alone was not taken (got $a want 1)"

# an asm name on a local would rename it: refuse rather than drop it
cno x64 'int m(void){ int x __asm__("y"); return x; }\n' "an asm NAME on a local was skipped as decoration"
cno x64 'int m(void){ register long sp asm("rsp"); asm("" : "+r"(sp)); return (int)sp; }\n' "a register variable pinned to the stack pointer was accepted"
# a file-scope `register T sp asm("rsp")` reads the stack pointer and lays no storage;
# a write refuses, and so does any other register
printf 'register unsigned long sp asm("rsp");\nint main(void){ int l; unsigned long s = sp; return (unsigned long)&l > s - 8192; }\n' > "$ho/.greg.c"
moonrun "$ho/.greg.c" "$ho/.greg" > /dev/null 2>&1 || fail "a global register variable refused"
"$ho/.greg"; a=$?
[ $a -eq 1 ] || fail "a global register variable did not read the stack pointer (got $a want 1)"
nm "$ho/.greg" 2>/dev/null | grep -q " [BbDd] sp$" && fail "a global register variable laid storage"
printf 'register unsigned long sp asm("rsp");\nvoid m(void){ sp = 0; }\n' > "$ho/.greg2.c"
moonrun -c -o /dev/null "$ho/.greg2.c" 2>&1 | grep -q "write to a global register variable" \
  || fail "a write to a global register variable was taken"
printf 'register unsigned long v asm("rcx");\nunsigned long m(void){ return v; }\n' > "$ho/.greg3.c"
moonrun -c -o /dev/null "$ho/.greg3.c" 2>&1 | grep -q "stack pointer only" \
  || fail "a global register variable on an allocatable register was taken"

cok x64 'int m(void){ register long v asm("rcx") = 5; asm("" : "+r"(v)); return (int)v; }\n' "a register variable pinned by asm() to a nameable register refused"
# C11 6.8.1p3: a label is unique to its function; __label__ makes two
cno x64 'int m(void){ { L: ; } { L: ; } return 0; }\n' "a duplicate label was accepted"
cok x64 'int m(void){ { __label__ L; L: ; } { __label__ L; L: ; } return 0; }\n' "two blocks' __label__ L refused"
# C11 6.9p3: one definition per function; gnu89's extern inline may precede the real one
cno x64 'static int f(void){ return 1; }\nstatic int f(void){ return 2; }\nint m(void){ return f(); }\n' "a static function defined twice was accepted"
cno x64 'int f(void){ return 1; }\nint f(void){ return 2; }\n' "a function defined twice was accepted"
cok x64 'extern inline __attribute__((gnu_inline)) int f(void){ return 1; }\nint f(void){ return 2; }\n' "a gnu extern inline followed by its definition refused"

# a UCN takes exactly 4 or 8 hex digits, and names no basic-set character, surrogate or
# code point past the last (C11 6.4.3p2). \134 is the backslash in octal
for bad in '\134u00E' '\134U0001F60' '\134u' '\134uZZZZ' \
           '\134u0041' '\134u0000' '\134u009F' '\134uD800' '\134uDFFF' '\134U00110000'; do
  cno x64 "char *s = \"$bad\";\nint m(void){return 0;}\n" "a malformed universal character name was accepted: $bad"
done
# ..and in an identifier
for bad in '\134u0041' '\134u00E' '\134uD800'; do
  cno x64 "int $bad;\nint m(void){return 0;}\n" "a malformed universal character name was accepted in an identifier: $bad"
done
for ok in '\134u0024' '\134u0040' '\134u0060' '\134u00A0' '\134U0010FFFF'; do
  cok x64 "char *s = \"$ok\";\nint m(void){return 0;}\n" "a legal universal character name was refused: $ok"
done

# the freestanding headers C11 4p6 owes
cok x64 '#include <iso646.h>\n#include <stdalign.h>\nint m(void){return (1 and 2) + alignof(int);}\n' "iso646.h + stdalign.h"
echo "mooncc: C11 conditional features track the parity table on all six targets"

# -- -fno-inline: real, and neutral
# the flag must bar every splice, always_inline included, and keep the answer
moonrun            test/cc/112-alwaysinline.c "$ho/.ni-on"  > /dev/null 2>&1 || fail "-fno-inline: splice-on compile"
moonrun -fno-inline test/cc/112-alwaysinline.c "$ho/.ni-off" > /dev/null 2>&1 || fail "-fno-inline: splice-off compile"
"$ho/.ni-on";  a=$?
"$ho/.ni-off"; b=$?
[ $a -eq $b ] || fail "-fno-inline changed the answer (on $a, off $b)"
moonrun -c            test/cc/112-alwaysinline.c "$ho/.ni-on.o"  > /dev/null 2>&1 || fail "-fno-inline: -c splice-on"
moonrun -c -fno-inline test/cc/112-alwaysinline.c "$ho/.ni-off.o" > /dev/null 2>&1 || fail "-fno-inline: -c splice-off"
non=$(nm "$ho/.ni-on.o"  | grep -c ' [tT] ')
nof=$(nm "$ho/.ni-off.o" | grep -c ' [tT] ')
[ "$nof" -gt "$non" ] || fail "-fno-inline barred no splice ($non text syms either way)"
echo "mooncc: -fno-inline bars every splice ($non functions emitted, $nof with it) and answers the same"

# -- the failure exits
moonrun "$ho/.cc-none.c" "$ho/.ccx" > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "mooncc missing input exit (rc $r)"
printf 'int main() { return 42 }\n' > "$ho/.cc3.c"
moonrun "$ho/.cc3.c" "$ho/.ccx" > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "mooncc parse-error exit (rc $r)"
# a refusal names its cause: an undeclared identifier in a static initializer
cat > "$ho/.cc4.c" <<'EOF'
void *r[] = { (void *) nosuchthing, 0 };
int main(void) { return 0; }
EOF
moonrun "$ho/.cc4.c" "$ho/.ccx" > "$ho/.cc4.out" 2>&1; r=$?
[ $r -eq 1 ] || fail "mooncc undeclared-in-initializer exit (rc $r)"
grep -q "undeclared 'nosuchthing'" "$ho/.cc4.out" \
  || fail "mooncc undeclared-in-initializer must name it: $(head -1 "$ho/.cc4.out")"
# a member the struct lacks, or of an incomplete struct, is named too
printf 'struct s { int y; };\nint f(struct s *p) { return p->x; }\nint main(void) { return 0; }\n' > "$ho/.cc6.c"
moonrun "$ho/.cc6.c" "$ho/.ccx" > "$ho/.cc6.out" 2>&1
grep -q "no member 'x' in 's'" "$ho/.cc6.out" || fail "mooncc missing member must name it: $(head -1 "$ho/.cc6.out")"
printf 'struct t;\nint f(struct t *p) { return p->x; }\nint main(void) { return 0; }\n' > "$ho/.cc7.c"
moonrun "$ho/.cc7.c" "$ho/.ccx" > "$ho/.cc7.out" 2>&1
grep -q "incomplete type 't'" "$ho/.cc7.out" || fail "mooncc incomplete member must name it: $(head -1 "$ho/.cc7.out")"
# sizeof an incomplete struct is no size
printf 'struct u;\nint main(void) { return sizeof (struct u); }\n' > "$ho/.cc8.c"
moonrun "$ho/.cc8.c" "$ho/.ccx" > "$ho/.cc8.out" 2>&1
grep -q "sizeof an incomplete type" "$ho/.cc8.out" || fail "mooncc sizeof incomplete must refuse: $(head -1 "$ho/.cc8.out")"
# nor its alignment, by type or by expression
printf 'struct u;\nint main(void) { return _Alignof (struct u); }\n' > "$ho/.cc8a.c"
moonrun "$ho/.cc8a.c" "$ho/.ccx" > "$ho/.cc8a.out" 2>&1
grep -q "alignof an incomplete type" "$ho/.cc8a.out" || fail "mooncc _Alignof incomplete must refuse: $(head -1 "$ho/.cc8a.out")"
printf 'struct u;\nint f(struct u *p) { return __alignof__ (*p); }\nint main(void) { return 0; }\n' > "$ho/.cc8b.c"
moonrun "$ho/.cc8b.c" "$ho/.ccx" > "$ho/.cc8b.out" 2>&1
grep -q "alignof an incomplete type" "$ho/.cc8b.out" || fail "mooncc __alignof__ incomplete must refuse: $(head -1 "$ho/.cc8b.out")"
# C11 6.7p4: an object redeclared at file scope keeps its type
printf 'extern long foo;\nextern int foo;\nint main(void) { return 0; }\n' > "$ho/.cc9.c"
moonrun "$ho/.cc9.c" "$ho/.ccx" > "$ho/.cc9.out" 2>&1
grep -q "conflicting types for 'foo'" "$ho/.cc9.out" || fail "mooncc redeclared type must refuse: $(head -1 "$ho/.cc9.out")"
printf 'extern int a[];\nint a[4];\nint x;\nint x = 3;\nint main(void) { return x - 3; }\n' > "$ho/.cc10.c"
moonrun "$ho/.cc10.c" "$ho/.cc10" > /dev/null 2>&1 && "$ho/.cc10" || fail "mooncc compatible redeclarations"
# C11 6.7.4p7: plain inline lays no external symbol; extern inline lays it
printf 'inline int twice(int x) { return 2 * x; }\n' > "$ho/.inl.h"
printf '#include "%s"\nint a(int x) { return twice(x); }\n' "$ho/.inl.h" > "$ho/.inla.c"
printf '#include "%s"\nint b(int x) { return twice(x); }\n' "$ho/.inl.h" > "$ho/.inlb.c"
printf '#include "%s"\nextern inline int twice(int);\nint a(int), b(int);\nint main(void) { int (*p)(int) = twice; return a(1) + b(2) + p(3) != 12; }\n' "$ho/.inl.h" > "$ho/.inlm.c"
moonrun -o "$ho/.inlx" "$ho/.inla.c" "$ho/.inlb.c" "$ho/.inlm.c" > "$ho/.inl.out" 2>&1 && "$ho/.inlx" \
  || fail "mooncc c99 inline across TUs: $(head -1 "$ho/.inl.out")"
# a function's address is a constant
cat > "$ho/.cc5.c" <<'EOF'
int puts(char const*);
void *const r[] = { (void *) puts, 0 };
int main(void) { return r[0] == 0; }
EOF
moonrun "$ho/.cc5.c" "$ho/.cc5" > /dev/null 2>&1 || fail "mooncc fn address in a static initializer"
"$ho/.cc5"; r=$?
[ $r -eq 0 ] || fail "mooncc fn address in a static initializer ran wrong (rc $r)"

# -- -c objects, linked by the system ld
cat > "$ho/.olib.c" <<'EOF'
int vals[3] = {10,20,12};
char *tag = "x";
int pick(int i){return vals[i];}
EOF
cat > "$ho/.omain.c" <<'EOF'
extern int vals[];
int pick(int i);
int ext_add(int a,int b);
int main(){return pick(0)+vals[2]+ext_add(15,5);}
EOF
printf 'int ext_add(int a,int b){return a+b;}\n' > "$ho/.oext.c"
moonrun -c "$ho/.olib.c"  "$ho/.olib.o"  > /dev/null 2>&1 || fail "mooncc -c lib"
moonrun -c "$ho/.omain.c" "$ho/.omain.o" > /dev/null 2>&1 || fail "mooncc -c main"
$cc_g -O0 -c -o "$ho/.oext.o" "$ho/.oext.c"
$cc_g -no-pie -o "$ho/.oexe" "$ho/.omain.o" "$ho/.olib.o" "$ho/.oext.o" > /dev/null 2>&1 \
  || fail "ld cc objects"
"$ho/.oexe"; a=$?
$cc_g -O0 -o "$ho/.oexeg" "$ho/.omain.c" "$ho/.olib.c" "$ho/.oext.c" && "$ho/.oexeg"; b=$?
[ $a -eq 42 ] && [ $a -eq $b ] || fail "mooncc -c link+run (ours $a gcc $b)"

# -- -I / -D / -o
cat > "$ho/.flg.c" <<'EOF'
#include <ans.h>
int main() { return ANS + BONUS; }
EOF
mkdir -p "$ho/.flginc" && printf '#define ANS 30\n' > "$ho/.flginc/ans.h"
moonrun -I "$ho/.flginc" -D BONUS=12 -o "$ho/.flg" "$ho/.flg.c" > /dev/null 2>&1 \
  || fail "mooncc -I/-D/-o"
"$ho/.flg"; a=$?
[ $a -eq 42 ] || fail "mooncc -I/-D/-o run (got $a want 42)"

# -- inline asm
printf 'int main() { long v; asm("mov $40, %%0" : "=r"(v)); return v + 2; }\n' > "$ho/.casm1.c"
moonrun "$ho/.casm1.c" "$ho/.casm1" > /dev/null 2>&1 || fail "mooncc asm compile"
"$ho/.casm1"; a=$?
[ $a -eq 42 ] || fail "mooncc asm output operand (got $a want 42)"

printf 'int main() { asm volatile("syscall" : : "a"(60), "D"(42)); return 0; }\n' > "$ho/.casm2.c"
moonrun "$ho/.casm2.c" "$ho/.casm2" > /dev/null 2>&1 || fail "mooncc asm syscall compile"
"$ho/.casm2"; a=$?
[ $a -eq 42 ] || fail "mooncc asm pinned-reg syscall (got $a want 42)"

printf 'int main() { long x = 30; asm("add %%1, %%0" : "+r"(x) : "r"(12L)); return x; }\n' > "$ho/.casm3.c"
moonrun "$ho/.casm3.c" "$ho/.casm3" > /dev/null 2>&1 || fail "mooncc asm in-out compile"
"$ho/.casm3"; a=$?
[ $a -eq 42 ] || fail "mooncc asm in-out (got $a want 42)"

# the GNU forms: a tied input, a register variable, a 32-bit operand, a callee-saved clobber
printf 'int main() { unsigned a = 40, b; asm("addl $2, %%0" : "=r"(b) : "0"(a)); return b; }\n' > "$ho/.casm4.c"
moonrun "$ho/.casm4.c" "$ho/.casm4" > /dev/null 2>&1 || fail "mooncc asm tied-operand compile"
"$ho/.casm4"; a=$?
[ $a -eq 42 ] || fail "mooncc asm tied operand (got $a want 42)"
printf 'long f(long x) { register long v asm("rdx") = x; asm("addq $2, %%%%rdx\\n addq $1, %%%%r12" : "+r"(v) :: "r12"); return v; }\nint main() { return f(40); }\n' > "$ho/.casm5.c"
moonrun "$ho/.casm5.c" "$ho/.casm5" > /dev/null 2>&1 || fail "mooncc asm register-variable compile"
"$ho/.casm5"; a=$?
[ $a -eq 42 ] || fail "mooncc asm register variable + saved clobber (got $a want 42)"

# named operands number off outputs then inputs, so a template may mix them; `asm inline` is a hint
printf 'int main() { int r; asm ("movl %%[i], %%[o]" : [o] "=r" (r) : [i] "r" (42)); return r; }\n' > "$ho/.casmn1.c"
moonrun "$ho/.casmn1.c" "$ho/.casmn1" > /dev/null 2>&1 || fail "mooncc named asm operand compile"
"$ho/.casmn1"; a=$?
[ $a -eq 42 ] || fail "mooncc named asm operand (got $a want 42)"
printf 'int main() { int r; asm inline ("movl %%1, %%0\\n\\taddl %%[b], %%0" : "=&r" (r) : "r" (40), [b] "r" (2)); return r; }\n' > "$ho/.casmn2.c"
moonrun "$ho/.casmn2.c" "$ho/.casmn2" > /dev/null 2>&1 || fail "mooncc named+numbered asm operand compile"
"$ho/.casmn2"; a=$?
[ $a -eq 42 ] || fail "mooncc named beside numbered asm operand (got $a want 42)"
printf 'int main() { int l, h; asm ("movl %%[x], %%[l]\\n\\tmovl %%[x], %%[h]\\n\\taddl $2, %%[h]" : [l] "=&r" (l), [h] "=&r" (h) : [x] "r" (40)); return l + h - 40; }\n' > "$ho/.casmn3.c"
moonrun "$ho/.casmn3.c" "$ho/.casmn3" > /dev/null 2>&1 || fail "mooncc two named outputs compile"
"$ho/.casmn3"; a=$?
[ $a -eq 42 ] || fail "mooncc two named asm outputs (got $a want 42)"

# holo's neutral text, under the attribute that names it
printf 'int main() { long v; __attribute__((holo)) asm("li %%0, 40" : "=r"(v)); return v + 2; }\n' > "$ho/.casm6.c"
moonrun "$ho/.casm6.c" "$ho/.casm6" > /dev/null 2>&1 || fail "mooncc holo asm compile"
"$ho/.casm6"; a=$?
[ $a -eq 42 ] || fail "mooncc holo asm output operand (got $a want 42)"

moonrun -t a64 -o "$ho/.casm1a" "$ho/.casm6.c" > /dev/null 2>&1 || fail "mooncc asm a64 compile"
printf 'int main() { long v; asm("mov %%0, #40" : "=r"(v)); return v + 2; }\n' > "$ho/.casm7.c"
moonrun -t a64 -o "$ho/.casm7a" "$ho/.casm7.c" > /dev/null 2>&1 || fail "mooncc asm a64 GNU compile"
printf 'int main() { long v; asm("li %%0, 40" : "=r"(v)); return v + 2; }\n' > "$ho/.casm8.c"
moonrun -t rv64 -o "$ho/.casm8r" "$ho/.casm8.c" > /dev/null 2>&1 || fail "mooncc asm rv64 GNU compile"

# the same template through mooncc0, whose template parser is bound per lane
moon0 -o "$ho/.casm0" "$ho/.casm1.c" > /dev/null 2>&1 || fail "mooncc0 asm compile"
"$ho/.casm0"; a=$?
[ $a -eq 42 ] || fail "mooncc0 inline asm (got $a want 42)"

# -- multi-input -c
cat > "$ho/.mi1.c" <<'EOF'
int f();
int main() { return f() + 2; }
EOF
printf 'int f() { return 40; }\n' > "$ho/.mi2.c"
# -c with several inputs writes each .o beside its source, so it runs in $ho
mabs="$PWD/$ho"
( cd "$ho" && LOVE_NO_IMAGE= "$mabs/love" mooncc -c .mi1.c .mi2.c ) > /dev/null 2>&1 \
  || fail "mooncc multi-input -c"
$cc_g -no-pie -o "$ho/.mi" "$ho/.mi1.o" "$ho/.mi2.o" > /dev/null 2>&1 \
  || fail "ld multi-input objects"
"$ho/.mi"; a=$?
[ $a -eq 42 ] || fail "mooncc multi-input run (got $a want 42)"

# -- SysV varargs, called across toolchains
cat > "$ho/.valib.c" <<'EOF'
#include <stdarg.h>
int isum(int n,...){va_list ap;va_start(ap,n);long s=0;for(int i=0;i<n;i++)s+=va_arg(ap,int);va_end(ap);return s;}
EOF
cat > "$ho/.vamain.c" <<'EOF'
int isum(int n,...);
int main(){return isum(4,10,11,12,9);}
EOF
moonrun -c "$ho/.valib.c" "$ho/.valib.o" > /dev/null 2>&1 || fail "mooncc -c variadic"
$cc_g -O0 -c -o "$ho/.vamain.o" "$ho/.vamain.c"
$cc_g -no-pie -o "$ho/.vaexe" "$ho/.vamain.o" "$ho/.valib.o" > /dev/null 2>&1 \
  || fail "ld cc-variadic + gmoon-main"
"$ho/.vaexe"; a=$?
[ $a -eq 42 ] || fail "cc-variadic <- gcc-caller (SysV va ABI, got $a want 42)"

# -- a float crosses a call as binary32, either way
cat > "$ho/.flib.c" <<'EOF'
float fhalf(float f) { return f / 2; }
double ftwice(float f, double d) { return f * 2 + d; }
float ften(float a, float b, float c, float d, float e, float f, float g, float h, float i, float j) { return a + b + c + d + e + f + g + h + i + 10 * j; }
EOF
cat > "$ho/.fmain.c" <<'EOF'
float fhalf(float); double ftwice(float, double);
float ften(float, float, float, float, float, float, float, float, float, float);
int main() { return (fhalf(3.0f) == 1.5f) + 2 * (ftwice(1.5f, 0.25) == 3.25) + 4 * (ften(1, 1, 1, 1, 1, 1, 1, 1, 1, 3.5f) == 44.0f) + 35; }
EOF
$cc_g -O1 -c -o "$ho/.flibg.o" "$ho/.flib.c"
moonrun -c "$ho/.fmain.c" "$ho/.fmainm.o" > /dev/null 2>&1 || fail "mooncc -c float caller"
$cc_g -no-pie -o "$ho/.fexe" "$ho/.fmainm.o" "$ho/.flibg.o" > /dev/null 2>&1 && "$ho/.fexe"; a=$?
[ $a -eq 42 ] || fail "float args and results, mooncc calling gcc (got $a want 42)"
moonrun -c "$ho/.flib.c" "$ho/.flibm.o" > /dev/null 2>&1 || fail "mooncc -c float callee"
$cc_g -O1 -c -o "$ho/.fmaing.o" "$ho/.fmain.c"
$cc_g -no-pie -o "$ho/.fexe2" "$ho/.fmaing.o" "$ho/.flibm.o" > /dev/null 2>&1 && "$ho/.fexe2"; a=$?
[ $a -eq 42 ] || fail "float args and results, gcc calling mooncc (got $a want 42)"

# -- -shared: a .so glibc's loader takes, importing from its exe
cat > "$ho/.so.c" <<'EOF'
int hook(int);
int twice(int x) { return hook(x) * 2; }
static int (*tab[2])(int) = {hook, twice};
int via(int x) { return tab[1](tab[0](x)); }
EOF
cat > "$ho/.somain.c" <<'EOF'
int twice(int), via(int);
int hook(int x) { return x + 1; }
int main() { return twice(4) + via(4) + 20; }
EOF
moonrun -shared -o "$ho/libmso.so" "$ho/.so.c" > /dev/null 2>&1 || fail "mooncc -shared"
$cc_g -o "$ho/.soexe" "$ho/.somain.c" -L"$ho" -lmso -rdynamic -Wl,-rpath,"$PWD/$ho" > /dev/null 2>&1 \
  && "$ho/.soexe"; a=$?
[ $a -eq 42 ] || fail "a -shared object under ld.so: plt import, abs64 import, relative (got $a want 42)"

# -- weak overriding
cat > "$ho/.wklib.c" <<'EOF'
__attribute__((weak)) int wpick(void){return 7;}
int main(){return wpick() + 30;}
EOF
printf 'int wpick(void){return 12;}\n' > "$ho/.wkstr.c"
moonrun -c "$ho/.wklib.c" "$ho/.wklib.o" > /dev/null 2>&1 || fail "mooncc -c weak"
$cc_g -no-pie -o "$ho/.wkdef" "$ho/.wklib.o" > /dev/null 2>&1 && "$ho/.wkdef"; a=$?
[ $a -eq 37 ] || fail "weak default (got $a want 37)"
$cc_g -O0 -c -o "$ho/.wkstr.o" "$ho/.wkstr.c"
$cc_g -no-pie -o "$ho/.wkovr" "$ho/.wklib.o" "$ho/.wkstr.o" > /dev/null 2>&1 && "$ho/.wkovr"; a=$?
[ $a -eq 42 ] || fail "weak override (got $a want 42)"

# -- callee-saved rbx across a cc call
printf 'long bump(long x){long r;__builtin_add_overflow(x,1,&r);return r;}\n' > "$ho/.rblib.c"
cat > "$ho/.rbmain.c" <<'EOF'
long bump(long);
int main(void){volatile long a=0;long s=a;for(int i=42;i--;)s=bump(s);return (int)s;}
EOF
moonrun -c "$ho/.rblib.c" "$ho/.rblib.o" > /dev/null 2>&1 || fail "mooncc -c rbx-callee"
$cc_g -O2 -c -o "$ho/.rbmain.o" "$ho/.rbmain.c"
$cc_g -no-pie -o "$ho/.rbexe" "$ho/.rbmain.o" "$ho/.rblib.o" > /dev/null 2>&1 || fail "ld rbx interop"
"$ho/.rbexe"; a=$?
[ $a -eq 42 ] || fail "callee-saved rbx across cc call (-O2 caller loop bound, got $a want 42)"

# -- guaranteed sibcalls
cat > "$ho/.sib.c" <<'EOF'
static long cd(long n,long a){if(n==0)return a;return cd(n-1,a+1);}
static long tb(long n);
static long ta(long n){if(n==0)return 21;return tb(n-1);}
static long tb(long n){if(n==0)return 22;return ta(n-1);}
static long dp(long(*f)(long,long),long n){return f(n,0);}
int main(void){long a=cd(50000000,0)/2500000;long b=ta(30000000);long c=dp(cd,1000000)/1000000;return (int)(a+b+c);}
EOF
moonrun "$ho/.sib.c" "$ho/.sibx" > /dev/null 2>&1 || fail "mooncc sibcall"
"$ho/.sibx"; a=$?
[ $a -eq 42 ] \
  || fail "sibcall flat recursion (50M-deep self + mutual + fn-ptr, got $a want 42 -- a non-tail call would stack-overflow to 139)"

# -- 16-byte stack alignment
printf 'long fork(void);long waitpid(long,int*,long);void _exit(long);long g;long id(long a){return a;}int main(void){g=id(fork());if(g==0)_exit(42);int st;waitpid(-1,&st,0);return ((st&127)==0&&((st>>8)&255)==42)?42:1;}\n' > "$ho/.aln.c"
moonrun -c "$ho/.aln.c" "$ho/.aln.o" > /dev/null 2>&1 || fail "mooncc -c stack-align"
$cc_g -no-pie -o "$ho/.alnx" "$ho/.aln.o" > /dev/null 2>&1 || fail "ld stack-align"
"$ho/.alnx"; a=$?
[ $a -eq 42 ] \
  || fail "16-byte stack alignment ('g=id(fork())' holds a temp across the call; a bare-push spill leaves rsp at 8 mod 16 and glibc fork's child movaps #GPs -- got $a want 42)"

# -- our own static linker
moonrun -c "$ho/.oext.c" "$ho/.oext2.o" > /dev/null 2>&1 || fail "mooncc -c ext"
moonrun "$ho/.omain.o" "$ho/.olib.o" "$ho/.oext2.o" -o "$ho/.lnk1" > /dev/null 2>&1 \
  || fail "mooncc link .o"
"$ho/.lnk1"; a=$?
[ $a -eq 42 ] || fail "mooncc-linked exe (own static linker, got $a want 42)"

moonrun "$ho/.mi1.c" "$ho/.mi2.c" -o "$ho/.lnk2" > /dev/null 2>&1 || fail "mooncc link multi-.c"
"$ho/.lnk2"; a=$?
[ $a -eq 42 ] || fail "mooncc multi-.c link (got $a want 42)"

moonrun -c "$ho/.wkstr.c" "$ho/.wkstr2.o" > /dev/null 2>&1 || fail "mooncc -c weak-strong"
moonrun "$ho/.wklib.o" -o "$ho/.lnk3" > /dev/null 2>&1 && "$ho/.lnk3"; a=$?
[ $a -eq 37 ] || fail "mooncc-link weak default (got $a want 37)"
moonrun "$ho/.wklib.o" "$ho/.wkstr2.o" -o "$ho/.lnk4" > /dev/null 2>&1 && "$ho/.lnk4"; a=$?
[ $a -eq 42 ] || fail "mooncc-link weak override (got $a want 42)"

# always_inline splices a body with a statement expression, a compound literal and struct and
# array locals (the kernel's per_cpu, an __init caller's own helpers): no out-of-line copy left
for t in x64 a64 rv64; do
  moonrun -t $t -c test/cc/317-always-inline-body.c -o "$ho/.awi.o" || fail "mooncc -t $t: 317-always-inline-body"
  nm "$ho/.awi.o" | grep -q ' t ii$' && fail "an always_inline body stayed out of line on $t"
done
# ..however deep the chain: ten calls down, seven of them always_inline
for t in x64 a64 rv64; do
  moonrun -t $t -c test/cc/323-always-inline-deep.c -o "$ho/.awd.o" || fail "mooncc -t $t: 323-always-inline-deep"
  nm "$ho/.awd.o" | grep -q ' t \(cap\|a[1-7]\)$' && fail "a deep always_inline body stayed out of line on $t"
done
# the love_nifs bracket: two TUs packed into one section, __start_/__stop_ synthesized
cat > "$ho/.nf1.c" <<'EOF'
typedef struct { char *n; long v; } ent;
__attribute__((section("love_nifs"))) ent e1 = { "a", 30 };
EOF
cat > "$ho/.nf2.c" <<'EOF'
typedef struct { char *n; long v; } ent;
__attribute__((section("love_nifs"))) ent e2 = { "b", 12 };
extern ent __start_love_nifs[];
extern ent __stop_love_nifs[];
int main(){ long s=0; for (ent *p=__start_love_nifs; p<__stop_love_nifs; p++) s+=p->v; return (int)s; }
EOF
moonrun "$ho/.nf2.c" "$ho/.nf1.c" -o "$ho/.lnk5" > /dev/null 2>&1 || fail "mooncc link love_nifs"
"$ho/.lnk5"; a=$?
[ $a -eq 42 ] || fail "love_nifs bracket walk (two TUs packed + __start_/__stop_ synthesized, got $a want 42)"

# a section the linker has no word for stays whole: the entries adjacent, in order
cat > "$ho/.mt1.c" <<'EOF'
typedef struct { char *n; long v; } ent;
__attribute__((section("mytab"))) ent e1 = { "a", 30 };
EOF
cat > "$ho/.mt2.c" <<'EOF'
typedef struct { char *n; long v; } ent;
__attribute__((section("mytab"))) ent e2 = { "b", 12 };
extern ent e1;
int main(){ long d=(char*)&e2-(char*)&e1; if (d!=(long)sizeof(ent) && d!=-(long)sizeof(ent)) return 1; return (int)(e1.v+e2.v); }
EOF
moonrun "$ho/.mt2.c" "$ho/.mt1.c" -o "$ho/.lnk6" > /dev/null 2>&1 || fail "mooncc link a named section"
"$ho/.lnk6"; a=$?
[ $a -eq 42 ] || fail "named-section lane (two TUs, contiguous, got $a want 42; 1 = the entries were not adjacent)"

# its flags pick the lane it travels with
cat > "$ho/.hm1.c" <<'EOF'
const long __attribute__((section("rotab"))) c1 = 30;
__attribute__((section("mycode"),noinline)) int f12(int x){ return x + 10; }
EOF
cat > "$ho/.hm2.c" <<'EOF'
extern const long c1;
int f12(int);
__attribute__((section("mytab"))) long w1 = 12;
int main(){ if ((unsigned long)&c1 >= (unsigned long)&w1) return 1; return (int)(c1 + f12(2)); }
EOF
$cc_g -O2 -c -o "$ho/.hm1.o" "$ho/.hm1.c" || fail "gcc -c named sections"
moonrun "$ho/.hm2.c" "$ho/.hm1.o" -o "$ho/.lnk7" > /dev/null 2>&1 || fail "mooncc link named-section homes"
"$ho/.lnk7"; a=$?
[ $a -eq 42 ] || fail "named-section homes (AX->text, A->rodata below data, WA->data; got $a want 42; 1 = rodata did not land below data)"

# a named section of const reloc-free globals comes out alloc-only; one holding an address
# stays writable. mixtab mixes both in both orders: the writable reading wins
cat > "$ho/.hm3.c" <<'EOF'
int f13(int);
struct ent { void *p; long v; };
const long __attribute__((section("rotab2"))) c2 = 30;
const struct ent __attribute__((section("reltab"), used)) r2[] = { { (void *) f13, 2 } };
__attribute__((section("mytab2"))) long w2 = 12;
const long __attribute__((section("mixtab"), used)) m1 = 5;
long __attribute__((section("mixtab"), used)) m2 = 6;
long __attribute__((section("mixtab2"), used)) m3 = 7;
const long __attribute__((section("mixtab2"), used)) m4 = 8;
__attribute__((noinline)) int f13(int x){ return x + 10; }
int main(){ if (r2[0].p != (void *) f13) return 1;
            return (int)(c2 + w2 + m1 + m2 + m3 + m4 + f13(-36)); }
EOF
moonrun "$ho/.hm3.c" -o "$ho/.lnk8" > /dev/null 2>&1 || fail "mooncc link its own const named section"
"$ho/.lnk8"; a=$?
[ $a -eq 42 ] || fail "mooncc const named section (got $a want 42; 1 = the relocated entry is wrong)"
# read the home off nm: addresses order by declaration whatever the flags
nm "$ho/.lnk8" > "$ho/.hm3.nm" 2>&1 || fail "nm on the named-flags exe"
for s in "R c2" "D r2" "D w2" "D m1" "D m2" "D m3" "D m4"; do
  grep -q " $s\$" "$ho/.hm3.nm" \
    || fail "mooncc named-section flags: '$s' is not where it belongs ($(grep " ${s#* }\$" "$ho/.hm3.nm")) -- R c2 = const and reloc-free goes ALLOC-only, D r2 = one holding an address keeps its write bit, D m1 = one writable member decides for the whole section"
done

# -- a foreign gcc .o, linked whole
cat > "$ho/.fgn.c" <<'EOF'
long bigbuf[4096];
int zed;
static const char *const nms[]={"zero","one","two"};
const long tbl[4]={3,5,7,9};
long fill(long n){long i;for(i=0;i<n;i++)bigbuf[i]=i+1;zed=(int)bigbuf[n-1];return bigbuf[0]+bigbuf[n-1];}
const char *nm(int i){return nms[i];}
long tb(int i){return tbl[i];}
EOF
cat > "$ho/.fgnm.c" <<'EOF'
extern long bigbuf[];extern int zed;long fill(long);const char*nm(int);long tb(int);
static int eq(const char*a,const char*b){while(*a&&*a==*b){a++;b++;}return *a==*b;}
int main(void){if(zed||bigbuf[5]||bigbuf[4095])return 1;if(!eq(nm(1),"one"))return 2;if(tb(3)!=9)return 3;long s=fill(9);return (int)(s+zed+23);}
EOF
for mode in -fno-pie -fPIE; do
  $cc_g -O0 $mode -c -o "$ho/.fgn.o" "$ho/.fgn.c"
  moonrun "$ho/.fgnm.c" "$ho/.fgn.o" -o "$ho/.fgnx" > /dev/null 2>&1 \
    || fail "mooncc link foreign .o ($mode)"
  "$ho/.fgnx"; a=$?
  [ $a -eq 42 ] \
    || fail "foreign gcc .o link $mode (.bss arrives zeroed + .rodata/.data.rel.ro + abs32 relocs, got $a want 42)"
done

# -- .comment, the producer
# read by our own ELF walk: a link over a gcc object credits gcc too, and ours is the
# base of love-version only, the vcs suffix would break the fixpoint
cmt() { "$m" -l src/love/holo/elfsec.l \
          -e "(: r (elfsec \"$1\" \".comment\") _ (? (two? r) (puts <r) 0) _ (flush out) (quit 0))"; }
c=$(cmt "$ho/.fgnx" | tr '\0' ' ')
case "$c" in
  *GCC*love*) ;;
  *) fail "our link over a gcc .o must credit both in .comment, got '$c'" ;;
esac
c=$(cmt "$ho/.sibx" | tr '\0' ' ')
[ "$c" = "love $(cat VERSION) " ] \
  || fail "an all-ours link says 'love <base>' in .comment (base only -- the fixpoint law), got '$c'"

# our binaries carry a symbol table
nm "$ho/.fgnx" > "$ho/.fgn.nm" 2>&1 || fail "nm on our exe (no symbol table)"
for s in "T main" "T fill" "B bigbuf" "B zed" "R tbl"; do
  grep -q " $s\$" "$ho/.fgn.nm" \
    || fail "symtab missing '$s' (nm must classify by the section the symbol lives in)"
done

# -- const globals reach .rodata
# except a const pointee's pointer and a const array of addresses (the linker writes it)
cat > "$ho/.ro.c" <<'EOF'
const long rotbl[4] = {3,5,7,9};
const char romsg[] = "const bytes";
const char *mutp = 0;
static void h(void){}
void (*const fnp[1])(void) = { h };
long wtbl[2] = {1,2};
const long rozero[2];
int main(){ return (int)(rotbl[3] + romsg[0] + wtbl[0] + rozero[0]
                         + (mutp!=0) + (fnp[0]!=0)); }
EOF
moonrun "$ho/.ro.c" -o "$ho/.rox" > /dev/null 2>&1 || fail "mooncc const-lane compile"
"$ho/.rox"; a=$?
[ $a -eq 110 ] || fail "const lane semantics (got $a want 110 = 9 + 'c' + 1 + 0 + 0 + 1)"
nm "$ho/.rox" > "$ho/.ro.nm" 2>&1 || fail "nm on the const-lane exe"
for s in "R rotbl" "R romsg" "D mutp" "D fnp" "D wtbl" "B rozero"; do
  grep -q " $s\$" "$ho/.ro.nm" \
    || fail "const lane: '$s' is not where it belongs ($(grep " ${s#* }\$" "$ho/.ro.nm"))"
done

echo "mooncc: cc (laws + a $(ls test/cc/*.c | wc -l)-program gcc battery + interop + our own linker) ok"


# -- the warm compiler
# one process compiles good, hard error, usage error, good: statuses 0 1 2 0, and the
# last object byte-identical to a cold compile
printf 'int wa(int x){return x+1;}\n' > "$ho/.wa.c"
printf 'int wb(void){ return nope; }\n' > "$ho/.wb.c"
# flags must not bleed between compiles in one process: a flagged compile, then a bare
# one equal to the bare compile run cold
moonrun -c "$ho/.wa.c" -o "$ho/.wa-bare.o" > /dev/null 2>&1 || fail "warm: the bare reference compile"
LOVE_NO_IMAGE= "$m" -e "(: mr (cite 'moon 'moon-run)
     a (mr (list \"-c\" \"-fno-inline\" \"-DLEAK=1\" \"-nostdinc\" \"$ho/.wa.c\" \"-o\" \"$ho/.wl1.o\"))
     b (mr (list \"-c\" \"$ho/.wa.c\" \"-o\" \"$ho/.wl2.o\")) (a + b))" </dev/null > /dev/null 2>&1 \
  || fail "warm: the flag-leak pair did not compile"
cmp -s "$ho/.wa-bare.o" "$ho/.wl2.o" || fail "warm: FLAGS BLED between compiles in one process"
moonrun -c "$ho/.wa.c" -o "$ho/.wa-cold.o" > /dev/null 2>&1 || fail "warm: the cold reference compile"
warm=$(printf '(: mr (cite (name "moon") (name "moon-run"))
                  a (mr (list "-c" "%s" "-o" "%s"))
                  b (mr (list "-c" "%s" "-o" "/dev/null"))
                  c (mr (list "-zzz"))
                  d (mr (list "-c" "%s" "-o" "%s"))
                  _ (say out (show a + " " + show b + " " + show c + " " + show d + "\n"))
                  (quit 0))' \
             "$ho/.wa.c" "$ho/.wa-warm.o" "$ho/.wb.c" "$ho/.wa.c" "$ho/.wa-warm.o")
LOVE_NO_IMAGE= "$m" -e "$warm" > "$ho/.warm.out" 2>/dev/null
r=$?
[ $r -eq 0 ] || fail "warm mooncc: the image did not survive a failed compile (exit $r)"
[ "$(tail -1 "$ho/.warm.out")" = "0 1 2 0" ] || fail "warm mooncc statuses: $(tail -1 "$ho/.warm.out")"
cmp -s "$ho/.wa-cold.o" "$ho/.wa-warm.o" \
  || fail "warm mooncc: the object after two failures differs from the cold one"
echo "mooncc: the warm compiler (moon-run answers, the image compiles on past a failure) ok"


# -- the carried runtime is kernel-neutral
# every hosted kernel takes the carried archive; a warm cache hides a refusal, so ask
# the binary what it carries, then drop the cache so the clock means something
for a in x64 a64 rv64; do
  n=$(LOVE_NO_IMAGE= "$m" -q -e "(: _ (puts (show (tally (\"\" + runtime-gz \"$a\")))) 0)" | head -1)
  case $n in ''|*[!0-9]*) n=0;; esac
  [ "$n" -gt 1000 ] \
    || fail "carried runtime: this binary carries no $a archive (runtime-gz answered $n bytes)"
done
rm -f out/cache/moon/*.a                      # the clock below must measure the carried read
printf '#include <stdio.h>\nint main(void){ printf("os lane\\n"); return 0; }\n' > "$ho/.os.c"
for os in linux freebsd netbsd; do
  s0=$(date +%s)
  moonrun -os $os "$ho/.os.c" -o "$ho/.os.$os" > /dev/null 2>&1 \
    || fail "carried runtime: -os $os did not link"
  [ $(( $(date +%s) - s0 )) -lt 5 ] \
    || fail "carried runtime: -os $os took the member-compile lane (it refused the carried archive)"
done
for os in linux freebsd netbsd; do
  s0=$(date +%s)
  moonrun -t rv64 -os $os "$ho/.os.c" -o "$ho/.os.rv$os" > /dev/null 2>&1 \
    || fail "carried runtime: -t rv64 -os $os did not link"
  [ $(( $(date +%s) - s0 )) -lt 5 ] \
    || fail "carried runtime: -t rv64 -os $os took the member-compile lane (it refused the carried archive)"
done
# ..and where the arch has NO translation tables the refusal must stand: i386's os.c
# reads -os and only linux has an answer, so a BSD there owes a compile that #errors.
# handing it the carried (linux-built) archive would link linux's numbers in silence.
moonrun -t i386 "$ho/.os.c" -o "$ho/.os.i386" > /dev/null 2>&1 \
  || fail "carried runtime: -t i386 did not link"
moonrun -t i386 -os netbsd "$ho/.os.c" -o "$ho/.os.i386nb" > /dev/null 2>&1 \
  && fail "carried runtime: -t i386 -os netbsd linked -- it took linux's archive for a BSD"
echo "mooncc: the carried runtime is kernel-neutral (linux/freebsd/netbsd all take it on x64, a64 and rv64; i386's BSDs still refuse) ok"
