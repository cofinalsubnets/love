#!/bin/sh
# test/gate/moon.sh -- mooncc's gate. Two halves: the LAWS (test/law/moon.l, which
# runs anywhere) and, on x86-64 only, an END-TO-END battery against gcc as the oracle
# -- mooncc compiles a program, gcc compiles the same program, and the two exit codes
# must agree. gcc is never trusted to be right, only to be a second opinion; where a
# check wants an exact value it says so (42, mostly).
#
# make owns the dependency graph; this owns the procedure.
# NOT set -e: nearly every check captures $? to report it in its own message.
#
# usage: moon.sh OUTDIR LOVE LOVE0
. test/gate/skip.sh
set -u

ho=$1
m=$2
love0=$3

fail() { echo "FAIL $*" >&2; exit 1; }
# the compiler under test: love's own mooncc verb (the crew layer, woken per invocation)
moonrun() { LOVE_NO_IMAGE= "$m" mooncc "$@"; }
# ..and the BOOTSTRAP one, the lane that compiles src/love/love.c: love0 waking mooncc0.image
moon0() { "$love0" wake out/mooncc0.image mooncc "$@"; }

# ---------------------------------------------------------------- the laws
echo "CC src/apps/moon/{lex,cpp,parse,gen,val}.l test/law/moon.l"
out=$ho/.test_moon.out
{ echo "(borrow 'holo)"
  cat test/00-init.l src/apps/kore/text.l src/apps/kore/u.l   # the kore floors register module 'kore
  echo "(borrow 'kore)"                    # ..ambient: holo/text.l and law.l read `lines` bare
  cat src/apps/moon/floor.l src/apps/moon/lex.l src/apps/moon/cpp.l src/apps/moon/parse.l \
      src/love/holo/text.l src/love/holo/dialect.l src/love/holo/gas.l src/apps/moon/val.l src/apps/moon/gen.l
  echo "(borrow 'moon)"                    # the cat re-laid module 'moon; law.l reads it bare
  cat test/law/moon.l
} | "$m" > "$out" 2>&1
r=$?
cat "$out"
[ $r -eq 0 ] && grep -q "test/law/moon:" "$out" || fail "cc laws (exit $r)"

# ----------------------------------------------- the template parser, under love0
# holo/text.l reaches the combinators through the bare name `post`, which each
# frontend's boot binds to that module's accessor. a lane that leaves something else
# there curries every combinator into a silent partial: no scare, no wrong answer,
# just every template failing to parse. love0's build-tool lane is the one that
# compiles src/love/love.c, and it is the only lane the laws above never walk.
echo "CC src/love/holo/text.l (love0 lane)"
"$love0" -l src/love/holo/text.l -e '(? (two? ((cite (name "holo") (name "asm-text")) "li r0, 60")) (quit 0) (quit 1))' </dev/null \
  || fail "asm-text under love0 -- is bare \`post\` the module accessor there?"

# ---------------------------------------------- the pipeline's stage types
# gen.l read as DATA and typed against src/apps/moon/stage.l's sig table (the
# overlay leg): the post-choice chain composes in exactly one order, and a
# clash names its innermost seam. nothing from stage.l rides any image.
"$m" src/apps/moon/stage.l || fail "moon-stage (the ;; moon-stage line names the seam)"

arch=$(uname -m)
if [ "$arch" != x64 ] && [ "$arch" != x86_64 ]; then
  gate_skip "mooncc: cc (laws only -- x64 e2e skipped on $arch) ok"
fi

cc_g=$(command -v gcc || command -v cc)

# ------------------------------------------------- return 42, and agree with gcc
printf 'int main() { return 42; }\n' > "$ho/.cc1.c"
moonrun "$ho/.cc1.c" "$ho/.cc1" > /dev/null 2>&1 || fail "mooncc compile"
"$ho/.cc1"; a=$?
$cc_g -O0 -o "$ho/.cc1g" "$ho/.cc1.c" && "$ho/.cc1g"; b=$?
[ $a -eq 42 ] && [ $a -eq $b ] || fail "mooncc vs gcc (ours $a gcc $b)"

cat > "$ho/.cc2.c" <<'EOF'
// c
int f() { return 1; }
int main() { return 7; }
EOF
moonrun "$ho/.cc2.c" "$ho/.cc2" > /dev/null 2>&1 && "$ho/.cc2"; a=$?
$cc_g -O0 -o "$ho/.cc2g" "$ho/.cc2.c" && "$ho/.cc2g"; b=$?
[ $a -eq $b ] || fail "mooncc two-fn vs gcc (ours $a gcc $b)"

# ------------------------------------------------------------- the battery
for f in test/cc/*.c; do
  moonrun "$f" "$ho/.ccb" > /dev/null 2>&1 || fail "mooncc compile $f"
  "$ho/.ccb"; a=$?
  $cc_g -O0 -o "$ho/.ccbg" "$f" && "$ho/.ccbg"; b=$?
  [ $a -eq $b ] || fail "mooncc battery $f (ours $a gcc $b)"
done

# an asm's other-section words leave with its home: a BUG_ON a late fold proves false loses its brk
# and label, and its __bug_table row must go too, or the object names a label it never lays
bug='asm volatile (".pushsection __bug_table,\"aw\"; .align 2; 14470: .long 14471f - .; .popsection; 14471: brk 0x800");'
printf 'int f(void){ const int len = 0; if (0 < len) { %s } return 1; }\n' "$bug" > "$ho/.bugd.c"
printf 'int f(int n){ if (n) { %s } return 1; }\n' "$bug" > "$ho/.bugl.c"
moonrun -t a64 -c "$ho/.bugd.c" -o "$ho/.bugd.o" || fail "mooncc -t a64 a dead BUG asm"
moonrun -t a64 -c "$ho/.bugl.c" -o "$ho/.bugl.o" || fail "mooncc -t a64 a live BUG asm"
! grep -q 'l14471' "$ho/.bugd.o" || fail "a dead BUG asm's __bug_table row names its removed label"
grep -q '__bug_table' "$ho/.bugl.o" || fail "a live BUG asm lost its __bug_table row"

# a jump label: its "i" operand a local derived from params (arch_static_branch's
# `char *k = &((char *)key)[branch]`), constant once the call is spliced, so the body compiles
# only spliced; its asm goto target is named only by the __jump_table words, never by a jump,
# and must stay laid. the program walks its own table. held to gcc -O2 (gcc -O0 refuses the "i")
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

# ------------------------------------------- -std=: the dialect rail (struct labels)
# THE ORACLE IS THE LABEL-FREE TWIN. A struct label is not C -- gcc cannot compile the
# labelled source at all -- so the differential is against the SAME struct with the labels
# deleted: identical size, identical offsets, and the label answering its member's own
# address. That is the whole claim (a virtual member, holding nothing, taking no space),
# and gen.l never learned a thing about it: a label is one more row in the stag table.
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
# NO FLAG: `moon` is the DEFAULT dialect, so the extension is what a bare mooncc reads.
moonrun -o "$ho/.lbl" "$ho/.lbl.c" > /dev/null 2>&1 || fail "struct labels did not compile by default"
a=$("$ho/.lbl"); ra=$?
$cc_g -O0 -o "$ho/.lblg" "$ho/.lblg.c" > /dev/null 2>&1 && b=$("$ho/.lblg")
[ $ra -eq 0 ] || fail "struct labels: the labelled program refused itself (exit $ra)"
[ "$a" = "$b" ] || fail "struct labels changed the layout (ours [$a] gcc [$b])"
moonrun -std=moon -c -o /dev/null "$ho/.lbl.c" > /dev/null 2>&1 || fail "-std=moon refused its own extension"
# ..and `c` is the FENCE: strict C takes no extension, which is the whole reason to ask for
# it. an unknown -std= refuses the compile rather than riding through ignored as it used to.
moonrun -std=c -c -o /dev/null "$ho/.lbl.c" > /dev/null 2>&1 && fail "a struct label was accepted under -std=c"
moonrun -std=c11 -c -o /dev/null "$ho/.lbl.c" > /dev/null 2>&1 && fail "a struct label was accepted under -std=c11"
moonrun -std=nosuchlang -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 && fail "an unknown -std= was tolerated"
moonrun -std=holyc -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 && fail "-std=holyc was accepted -- it names a dialect we do not read"
moonrun -std=c -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 || fail "-std=c refused a plain C file"
moonrun -std=gnu11 -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 || fail "-std=gnu11 refused a plain C file"
echo "mooncc: -std= is a rail (moon is the default and lays gcc's own layout; c fences the extensions out; an unknown one refuses)"

# ------------------------- bool, and the GNU C a __GNUC__ 8 claim owes (test/cc/230 holds the rest)
# bool/true/false are bare in moon and C23 and plain names in an older iso dialect, which
# linux/stddef.h declares for itself; <stdbool.h> lays them there
printf 'enum { false = 0, true = 1 };\ntypedef _Bool bool;\nint f(bool b) { return b ? true : false; }\n' > "$ho/.bool.c"
moonrun -std=gnu11 -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "-std=gnu11 kept true/false predefined"
moonrun -std=c11 -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "-std=c11 kept true/false predefined"
printf 'bool f(void) { return true; }\n' > "$ho/.bool.c"
moonrun -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "the moon dialect lost bare bool"
moonrun -std=c23 -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "-std=c23 lost bare bool"
printf '#include <stdbool.h>\nbool f(void) { return true; }\n' > "$ho/.bool.c"
moonrun -std=c11 -c -o /dev/null "$ho/.bool.c" > /dev/null 2>&1 || fail "<stdbool.h> did not lay bool under -std=c11"
# an attribute whose skip changes the code refuses by name; a #pragma pack likewise
for a in constructor 'vector_size(16)' 'mode(DI)' naked 'ifunc("r")'; do
  printf 'int f(void) __attribute__((%s));\n' "$a" > "$ho/.attr.c"
  moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "is not carried out" || fail "__attribute__(($a)) was skipped"
done
# #pragma pack is carried (test/cc/231); an operand it does not read, and a bit-field it would
# let straddle, refuse
printf '#pragma pack(3)\nstruct s { char c; int i; };\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "is not one mooncc reads" || fail "#pragma pack(3) was taken"
printf '#pragma pack(1)\nstruct s { char c; int i : 20; int j : 20; };\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "a bit-field under #pragma pack" || fail "a packed bit-field was laid"
printf 'typedef union { char *p; short s; } u __attribute__((transparent_union));\n' > "$ho/.attr.c"
moonrun -c -o /dev/null "$ho/.attr.c" 2>&1 | grep -q "a transparent union wants" || fail "a mixed transparent union was taken"
# #pragma once reads a header once
mkdir -p "$ho/.once"
printf '#pragma once\nstruct once { int a; };\n' > "$ho/.once/h.h"
printf '#include "h.h"\n#include "h.h"\nint main(void) { return sizeof (struct once); }\n' > "$ho/.once/m.c"
[ "$(moonrun -E "$ho/.once/m.c" | grep -c 'struct once {')" = 1 ] || fail "#pragma once read the header twice"
# `used` keeps a static nothing calls; gnu_inline's plain inline lays the external definition
moonrun -c -o "$ho/.used.o" test/cc/230-gnuc.c > /dev/null 2>&1 || fail "230-gnuc did not compile"
nm "$ho/.used.o" | grep -q " t kept$" || fail "a used static function was swept"
nm "$ho/.used.o" | grep -q " T thrice$" || fail "gnu_inline's plain inline laid no external definition"
echo "mooncc: GNU C 8 -- bool by dialect, refused attributes named, #pragma pack's refusals, #pragma once, used, gnu_inline"

# ------------------------------------------- the flags that change the code
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
# -fmacro-prefix-map / -ffile-prefix-map: __FILE__ loses the build path, as gcc's does
mkdir -p "$ho/.mpm/sub"
printf 'const char *fl(void) { return __FILE__; }\n' > "$ho/.mpm/sub/f.c"
dir=$(cd "$ho/.mpm" && pwd)
for fl in -fmacro-prefix-map -ffile-prefix-map; do
  moonrun -c $fl="$dir/=" -o "$ho/.mpm/f.o" "$dir/sub/f.c" > /dev/null 2>&1 || fail "$fl compile"
  strings "$ho/.mpm/f.o" | grep -qx "sub/f.c" || fail "$fl: __FILE__ is not sub/f.c"
  strings "$ho/.mpm/f.o" | grep -q "$dir" && fail "$fl: the build path reached the object"
done
# -ffixed-x18: a64's platform register is never allocated, the flag says so, and elsewhere it refuses
moonrun -t a64 -ffixed-x18 -c -o "$ho/.x18.o" test/cc/111-int128.c > /dev/null 2>&1 || fail "-ffixed-x18 refused on a64"
if command -v llvm-objdump > /dev/null; then
  llvm-objdump -d --no-show-raw-insn "$ho/.x18.o" | grep -E '^ *[0-9a-f]+:' | grep -qwE '[xw]18' \
    && fail "-ffixed-x18: x18 allocated"
else
  gate_partly "  (-ffixed-x18: the allocation check skipped, no llvm-objdump)"
fi
moonrun -ffixed-x18 -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 && fail "-ffixed-x18 taken on x64"
moonrun -t a64 -ffixed-x20 -c -o /dev/null "$ho/.cc1.c" > /dev/null 2>&1 && fail "-ffixed-x20 was ignored"
echo "mooncc: -fshort-wchar, -fmacro-prefix-map and -ffixed-x18 do what they say, held to gcc"

# -------------------------------- C11 conditional features (6.10.8.3), per target
# gcc cannot be the oracle here -- it HAS atomics -- so these are ours alone, and
# each row must track the parity table: a claimed absence we do not have sends a
# portable source down a fallback for nothing.
c11feat() {                        # TGT MACRO want(1 present | 0 absent)
  if [ "$3" = 1 ]; then b="#ifndef $2"; else b="#ifdef $2"; fi
  printf '%s\n#error no\n#endif\nint m(void){return 0;}\n' "$b" > "$ho/.feat.c"
  moonrun -c -t "$1" -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
    || fail "C11 feature macro $2 on $1 (want present=$3)"
}
for t in x64 a64 rv64 thumb2 thumb2sp thumb1; do
  for mac in __STDC_NO_ATOMICS__ __STDC_NO_THREADS__ __STDC_UTF_16__ __STDC_UTF_32__; do
    c11feat "$t" "$mac" 1
  done
  case $t in x64|a64) c11feat "$t" __STDC_NO_VLA__ 0 ;; *) c11feat "$t" __STDC_NO_VLA__ 1 ;; esac
  case $t in x64)       c11feat "$t" __STDC_NO_COMPLEX__ 0 ;; *) c11feat "$t" __STDC_NO_COMPLEX__ 1 ;; esac
done
# a TU that is ONLY a _Static_assert -- want answers the remainder, which is () at
# EOF, and that read as "no `;` found". a failing assert must still refuse.
printf '_Static_assert(1, "ok");' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 || fail "a TU of one _Static_assert"
printf '_Static_assert(0, "boom");' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 && fail "a FAILING lone _Static_assert passed"

# C11 6.5.16.1: an integer reaches a pointer only as a NULL POINTER CONSTANT, so
# `return 1` from a T* is a constraint violation -- src/love/main.c carried one for years,
# clang named it, and we took it in silence and handed back address 1
printf 'struct s;\nstatic struct s *f(int x){ if (x) return 1; return 0; }\nint m(void){return 0;}\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
  && fail "an int returned where a pointer is owed was accepted"
printf 'struct s;\nstatic struct s *f(int x){ if (x) return (struct s*)1; return 0; }\nint m(void){return 0;}\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
  || fail "a CAST to the pointer type must still pass"

# a bound that does not fold at file scope is refused and named, never laid as a pointer's
# worth of storage -- a runtime __builtin_offsetof reaching one must not pass in silence
printf 'int n = 3;\nstatic int x[n];\nstruct S { int a[4]; };\nint i;\nchar y[__builtin_offsetof(struct S, a[i])];\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" 2>&1 | grep -q "variably modified 'x' at file scope" \
  || fail "a variably modified object at file scope was not refused by name"
printf 'struct S { int a[4]; };\nint i;\nchar y[__builtin_offsetof(struct S, a[i])];\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
  && fail "a runtime offsetof as a file-scope bound was accepted"

# cleanup (test/cc/176 holds the well-formed side): what it cannot carry refuses by name,
# never a skipped attribute -- a dropped call is linux's guard() never unlocking
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

# a file-scope asm (test/cc/178 holds the well-formed side): a directive gas-top does not
# read, label arithmetic across sections, a `- .` word on arm32 and the wasm lane refuse by
# name -- a dropped directive is a section the linker never sees
taref() {
  printf "$1" > "$ho/.feat.c"
  moonrun -c -t "$2" -o /dev/null "$ho/.feat.c" 2>&1 | grep -q "$3" || fail "file-scope asm: $4"
}
taref 'asm(".uleb128 5");\n' x64 "gas-directive" "an unread directive was not refused"
taref 'asm(".data\\na: .long a - b\\n.text\\nb:");\n' x64 "gas-data" "a label difference across sections was not refused"
taref 'int f(void){return 0;}\nasm(".data\\n.long f - .");\n' thumb2 "gas-data-pcrel" "a pc-relative word on arm32 was not refused"
taref 'asm(".data\\n.byte 1");\n' wasm "no wasm lane" "the wasm lane took a file-scope asm"
# an "i" operand (test/cc/181 holds the well-formed side): a local, or a global a local
# shadows, is no constant; an .org behind its own section refuses
taref 'int f(int b){asm("# %%0" : : "i"(b)); return 0;}\n' x64 "not a constant" "a local as an \"i\" operand was not refused"
taref 'int g;\nint f(void){int g = 1; g++; asm("# %%c0" : : "i"(&g)); return g;}\n' x64 "not a constant" "a shadowed global as an \"i\" operand was not refused"
taref 'asm(".data\\n2: .quad 0\\n.org 2b + 4");\n' x64 "gas-org" "an .org behind its section was not refused"
# gas's .error, reached through the macro language's .if, refuses by name (test/cc/191 holds the rest)
taref 'asm(".set .Lx, 2\\n.if (.Lx != 1)\\n.error \\"bad\\"\\n.endif");\n' x64 "gas-error" "a reached .error was not refused"
# a flag output has an x64 lane only (test/cc/184); elsewhere it names its cause
taref 'int f(long x){int z; asm("cmp %%1, #0" : "=@cceq"(z) : "r"(x)); return z;}\n' a64 "an asm flag output" "an a64 flag output was not refused by name"
# a %gs: store to an absolute address has no register to reach it through (test/cc/182)
taref 'void f(long x){asm volatile("movq %%0, %%%%gs:40" : : "r"(x));}\n' x64 "gas-x64-seg" "a gs store to an absolute address was not refused"
# what the 64-bit opcode map dropped refuses by name: a far call to an immediate, pusha
taref 'void f(void){asm volatile("lcallw $0xc000,$3");}\n' x64 "\"lcallw\", which 64-bit mode has no encoding for" "a direct far call was not refused by name"
taref 'void f(void){asm volatile("pusha");}\n' x64 "\"pusha\", which 64-bit mode" "pusha was not refused by name"

# an assembly source: a .s is its own file-scope asm, encoded exactly by as.l; a .S reads the
# preprocessor first -- an include, a macro as an immediate and as a label, #if, numeric labels
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

# the attribute skip on a local/parameter/member takes __attribute__ ALONE: an asm NAME
# would rename the object, and dropping it renames it in silence. test/cc/145 holds the
# well-formed side; only the refusals live here.
printf 'int m(void){ int x __asm__("y"); return x; }\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
  && fail "an asm NAME on a local was skipped as decoration"
printf 'int m(void){ register long sp asm("rsp"); asm("" : "+r"(sp)); return (int)sp; }\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
  && fail "a register variable pinned to the stack pointer was accepted"
# a FILE-SCOPE `register T nm asm("rsp")` is GNU's global register variable -- x86's
# current_stack_pointer, which every kernel TU reaches through asm/asm.h. reads answer
# the register and lay no storage; a WRITE refuses (gcc reserves the register for the
# whole unit and we cannot), and so does any register but the stack pointer
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

printf 'int m(void){ register long v asm("rcx") = 5; asm("" : "+r"(v)); return (int)v; }\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
  || fail "a register variable pinned by asm() to a nameable register refused"
# C11 6.8.1p3: a label is unique to its FUNCTION. two of a name laid one mangled label
# twice and every goto took the first -- so they refuse. gcc's __label__ makes two blocks'
# L two labels, and those compile.
printf 'int m(void){ { L: ; } { L: ; } return 0; }\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
  && fail "a duplicate label was accepted"
printf 'int m(void){ { __label__ L; L: ; } { __label__ L; L: ; } return 0; }\n' > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
  || fail "two blocks' __label__ L refused"

# a UCN takes EXACTLY 4 (or 8) hex digits -- a short run must REFUSE, not take what
# it found. test/cc/138 holds the well-formed side; only the refusals live here.
# \134 is the backslash, written in octal so the sequence survives this file.
# ..and C11 6.4.3p2 bars a UCN from naming a BASIC-SET character (under 00A0, bar
# $ @ `), a surrogate, or anything past the last code point -- so A for 'A' is a
# constraint violation, not a long spelling. gcc 13 refuses it; newer ones take C23's
# relaxation, which is why the cross gcc caught this and the host one did not.
for bad in '\134u00E' '\134U0001F60' '\134u' '\134uZZZZ' \
           '\134u0041' '\134u0000' '\134u009F' '\134uD800' '\134uDFFF' '\134U00110000'; do
  printf "char *s = \"$bad\";\nint m(void){return 0;}\n" > "$ho/.feat.c"
  moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
    && fail "a malformed universal character name was accepted: $bad"
done
# ..and in an IDENTIFIER, the other position a UCN takes (test/cc/138 holds the well-formed side)
for bad in '\134u0041' '\134u00E' '\134uD800'; do
  printf "int $bad;\nint m(void){return 0;}\n" > "$ho/.feat.c"
  moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
    && fail "a malformed universal character name was accepted in an identifier: $bad"
done
for ok in '\134u0024' '\134u0040' '\134u0060' '\134u00A0' '\134U0010FFFF'; do
  printf "char *s = \"$ok\";\nint m(void){return 0;}\n" > "$ho/.feat.c"
  moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 \
    || fail "a legal universal character name was refused: $ok"
done

# the freestanding header set is C11 4p6: these two were the ones we did not ship
printf '#include <iso646.h>\n#include <stdalign.h>\nint m(void){return (1 and 2) + alignof(int);}\n' \
  > "$ho/.feat.c"
moonrun -c -t x64 -o /dev/null "$ho/.feat.c" > /dev/null 2>&1 || fail "iso646.h + stdalign.h"
echo "mooncc: C11 conditional features track the parity table on all six targets"

# --------------------------------------------- -fno-inline: real, and neutral
# TWO halves, and both are the point: the flag must BITE (more functions reach
# the object, always_inline included -- the driver's word outranks the source's)
# and it must not CHANGE THE ANSWER. 112 is the inline law's own program, so the
# splice-off run walks the same checks the splice-on run does.
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

# ------------------------------------------------------- the failure exits
moonrun "$ho/.cc-none.c" "$ho/.ccx" > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "mooncc missing input exit (rc $r)"
printf 'int main() { return 42 }\n' > "$ho/.cc3.c"
moonrun "$ho/.cc3.c" "$ho/.ccx" > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "mooncc parse-error exit (rc $r)"
# a refusal must NAME ITS CAUSE. an undeclared identifier in a static
# initializer used to print the initializer's whole IR ("CGDATA-BAD .."), which
# reads as a codegen gap rather than as a typo -- and was read as one.
cat > "$ho/.cc4.c" <<'EOF'
void *r[] = { (void *) nosuchthing, 0 };
int main(void) { return 0; }
EOF
moonrun "$ho/.cc4.c" "$ho/.ccx" > "$ho/.cc4.out" 2>&1; r=$?
[ $r -eq 1 ] || fail "mooncc undeclared-in-initializer exit (rc $r)"
grep -q "undeclared 'nosuchthing'" "$ho/.cc4.out" \
  || fail "mooncc undeclared-in-initializer must name it: $(head -1 "$ho/.cc4.out")"
# a member the struct lacks, or of a struct never completed, is named too
printf 'struct s { int y; };\nint f(struct s *p) { return p->x; }\nint main(void) { return 0; }\n' > "$ho/.cc6.c"
moonrun "$ho/.cc6.c" "$ho/.ccx" > "$ho/.cc6.out" 2>&1
grep -q "no member 'x' in 's'" "$ho/.cc6.out" || fail "mooncc missing member must name it: $(head -1 "$ho/.cc6.out")"
printf 'struct t;\nint f(struct t *p) { return p->x; }\nint main(void) { return 0; }\n' > "$ho/.cc7.c"
moonrun "$ho/.cc7.c" "$ho/.ccx" > "$ho/.cc7.out" 2>&1
grep -q "incomplete type 't'" "$ho/.cc7.out" || fail "mooncc incomplete member must name it: $(head -1 "$ho/.cc7.out")"
# sizeof a struct never completed is not a size (autoconf's type probes ask exactly this)
printf 'struct u;\nint main(void) { return sizeof (struct u); }\n' > "$ho/.cc8.c"
moonrun "$ho/.cc8.c" "$ho/.ccx" > "$ho/.cc8.out" 2>&1
grep -q "sizeof an incomplete type" "$ho/.cc8.out" || fail "mooncc sizeof incomplete must refuse: $(head -1 "$ho/.cc8.out")"
# C11 6.7p4: an object redeclared at file scope keeps its type -- autoconf finds a type's
# literal suffix by redeclaring one (`extern ptrdiff_t foo; extern int foo;` must refuse)
printf 'extern long foo;\nextern int foo;\nint main(void) { return 0; }\n' > "$ho/.cc9.c"
moonrun "$ho/.cc9.c" "$ho/.ccx" > "$ho/.cc9.out" 2>&1
grep -q "conflicting types for 'foo'" "$ho/.cc9.out" || fail "mooncc redeclared type must refuse: $(head -1 "$ho/.cc9.out")"
printf 'extern int a[];\nint a[4];\nint x;\nint x = 3;\nint main(void) { return x - 3; }\n' > "$ho/.cc10.c"
moonrun "$ho/.cc10.c" "$ho/.cc10" > /dev/null 2>&1 && "$ho/.cc10" || fail "mooncc compatible redeclarations"
# C11 6.7.4p7: a plain `inline` definition in a header lays no external symbol, so two TUs
# including it link; the one saying `extern inline` lays it (gnulib's _GL_INLINE)
printf 'inline int twice(int x) { return 2 * x; }\n' > "$ho/.inl.h"
printf '#include "%s"\nint a(int x) { return twice(x); }\n' "$ho/.inl.h" > "$ho/.inla.c"
printf '#include "%s"\nint b(int x) { return twice(x); }\n' "$ho/.inl.h" > "$ho/.inlb.c"
printf '#include "%s"\nextern inline int twice(int);\nint a(int), b(int);\nint main(void) { int (*p)(int) = twice; return a(1) + b(2) + p(3) != 12; }\n' "$ho/.inl.h" > "$ho/.inlm.c"
moonrun -o "$ho/.inlx" "$ho/.inla.c" "$ho/.inlb.c" "$ho/.inlm.c" > "$ho/.inl.out" 2>&1 && "$ho/.inlx" \
  || fail "mooncc c99 inline across TUs: $(head -1 "$ho/.inl.out")"
# ..and the shape it must NOT refuse: a function's address IS a constant
cat > "$ho/.cc5.c" <<'EOF'
int puts(char const*);
void *const r[] = { (void *) puts, 0 };
int main(void) { return r[0] == 0; }
EOF
moonrun "$ho/.cc5.c" "$ho/.cc5" > /dev/null 2>&1 || fail "mooncc fn address in a static initializer"
"$ho/.cc5"; r=$?
[ $r -eq 0 ] || fail "mooncc fn address in a static initializer ran wrong (rc $r)"

# -------------------------------------------- -c objects, linked by the system ld
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

# --------------------------------------------------------------- -I / -D / -o
cat > "$ho/.flg.c" <<'EOF'
#include <ans.h>
int main() { return ANS + BONUS; }
EOF
mkdir -p "$ho/.flginc" && printf '#define ANS 30\n' > "$ho/.flginc/ans.h"
moonrun -I "$ho/.flginc" -D BONUS=12 -o "$ho/.flg" "$ho/.flg.c" > /dev/null 2>&1 \
  || fail "mooncc -I/-D/-o"
"$ho/.flg"; a=$?
[ $a -eq 42 ] || fail "mooncc -I/-D/-o run (got $a want 42)"

# ------------------------------------------------------------------ inline asm
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

# the GNU forms clang would also take: a tied input ("0"), a register variable, a 32-bit
# operand spelled at its width, a callee-saved clobber (saved around the body)
printf 'int main() { unsigned a = 40, b; asm("addl $2, %%0" : "=r"(b) : "0"(a)); return b; }\n' > "$ho/.casm4.c"
moonrun "$ho/.casm4.c" "$ho/.casm4" > /dev/null 2>&1 || fail "mooncc asm tied-operand compile"
"$ho/.casm4"; a=$?
[ $a -eq 42 ] || fail "mooncc asm tied operand (got $a want 42)"
printf 'long f(long x) { register long v asm("rdx") = x; asm("addq $2, %%%%rdx\\n addq $1, %%%%r12" : "+r"(v) :: "r12"); return v; }\nint main() { return f(40); }\n' > "$ho/.casm5.c"
moonrun "$ho/.casm5.c" "$ho/.casm5" > /dev/null 2>&1 || fail "mooncc asm register-variable compile"
"$ho/.casm5"; a=$?
[ $a -eq 42 ] || fail "mooncc asm register variable + saved clobber (got $a want 42)"

# named operands: `%[x]` numbers off the operand lists (outputs first, then inputs),
# so a template may mix a name with a number, and `asm inline` is a hint we drop
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

# the same template through the BOOTSTRAP compiler. every check above rides the
# default love, and inline asm is the one feature whose front end (the combinators
# text.l parses templates with) is reached by a bare name each lane binds itself --
# so mooncc0 losing it while mooncc keeps it is a live shape, not a hypothetical.
moon0 -o "$ho/.casm0" "$ho/.casm1.c" > /dev/null 2>&1 || fail "mooncc0 asm compile"
"$ho/.casm0"; a=$?
[ $a -eq 42 ] || fail "mooncc0 inline asm (got $a want 42)"

# ------------------------------------------------------------- multi-input -c
cat > "$ho/.mi1.c" <<'EOF'
int f();
int main() { return f() + 2; }
EOF
printf 'int f() { return 40; }\n' > "$ho/.mi2.c"
# -c with several inputs writes each .o beside its source, so it runs IN $ho
mabs="$PWD/$ho"
( cd "$ho" && LOVE_NO_IMAGE= "$mabs/love" mooncc -c .mi1.c .mi2.c ) > /dev/null 2>&1 \
  || fail "mooncc multi-input -c"
$cc_g -no-pie -o "$ho/.mi" "$ho/.mi1.o" "$ho/.mi2.o" > /dev/null 2>&1 \
  || fail "ld multi-input objects"
"$ho/.mi"; a=$?
[ $a -eq 42 ] || fail "mooncc multi-input run (got $a want 42)"

# ------------------------------------- SysV varargs, called ACROSS toolchains
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

# ------------------------------------------------------------- weak overriding
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

# ------------------------------------------- callee-saved rbx across a cc call
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

# ------------------------------------------------------- guaranteed sibcalls
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

# --------------------------------------------------- 16-byte stack alignment
printf 'long fork(void);long waitpid(long,int*,long);void _exit(long);long g;long id(long a){return a;}int main(void){g=id(fork());if(g==0)_exit(42);int st;waitpid(-1,&st,0);return ((st&127)==0&&((st>>8)&255)==42)?42:1;}\n' > "$ho/.aln.c"
moonrun -c "$ho/.aln.c" "$ho/.aln.o" > /dev/null 2>&1 || fail "mooncc -c stack-align"
$cc_g -no-pie -o "$ho/.alnx" "$ho/.aln.o" > /dev/null 2>&1 || fail "ld stack-align"
"$ho/.alnx"; a=$?
[ $a -eq 42 ] \
  || fail "16-byte stack alignment ('g=id(fork())' holds a temp across the call; a bare-push spill leaves rsp at 8 mod 16 and glibc fork's child movaps #GPs -- got $a want 42)"

# ------------------------------------------------------- OUR OWN static linker
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

# a COMPILER-NAMED section -- one the linker has no word for. it becomes its own
# lane and stays WHOLE: the two TUs' entries land adjacent, in the order given.
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

# ..and which known lane it travels with is its FLAGS. a gcc TU says all three at
# once -- the code home has no mooncc twin below, since a section a FUNCTION names
# is executable by construction and never had a flag to get wrong.
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

# ..and mooncc says the read-only one ITSELF: a named section whose every global is
# const and reloc-free comes out ALLOC-only. one holding an ADDRESS stays writable --
# the .rodata rule, and gcc's answer too (.data.rel.ro is the lane gcc renames it to,
# and a section the programmer NAMED cannot be renamed).
# r2's const leads the SPECIFIER run: a declarator-side `void *const r2[]` is no
# const object here at all (parse.l's cobj?) and never reaches the relocation guard.
# mixtab holds one of each in BOTH orders -- gcc refuses the mix outright ("section
# type conflict"), we take the writable reading, and a walk that stops at the first
# member it likes reads as unanimous from whichever end it starts.
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
# read the home off nm, not off an address comparison: these order by declaration
# and so agree with the claim whether or not the flags do.
nm "$ho/.lnk8" > "$ho/.hm3.nm" 2>&1 || fail "nm on the named-flags exe"
for s in "R c2" "D r2" "D w2" "D m1" "D m2" "D m3" "D m4"; do
  grep -q " $s\$" "$ho/.hm3.nm" \
    || fail "mooncc named-section flags: '$s' is not where it belongs ($(grep " ${s#* }\$" "$ho/.hm3.nm")) -- R c2 = const and reloc-free goes ALLOC-only, D r2 = one holding an address keeps its write bit, D m1 = one writable member decides for the whole section"
done

# ------------------------------------------------- a FOREIGN gcc .o, linked whole
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

# ------------------------------------------------------- .comment, the producer
# what wrote the file, in the section every toolchain writes it in -- read back
# with our own ELF walk, so this holds on any machine and needs no readelf.
# the UNION is the point: .fgnx is our link over a gcc object, and it must credit
# gcc for the code gcc compiled rather than claiming the whole binary.
# ours is the BASE half of love-version and never the whole id, and that is a law:
# the VCS suffix names the commit that built the COMPILER, so it would make love1 and
# love2 differ and name a broken fixpoint (src/love/holo/link.l says it at the door).
# read ./VERSION rather than writing 0.1 down -- a release bump must not fail here.
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

# ..and our own binaries carry a symbol table nm and gdb can read
nm "$ho/.fgnx" > "$ho/.fgn.nm" 2>&1 || fail "nm on our exe (no symbol table)"
for s in "T main" "T fill" "B bigbuf" "B zed" "R tbl"; do
  grep -q " $s\$" "$ho/.fgn.nm" \
    || fail "symtab missing '$s' (nm must classify by the section the symbol lives in)"
done

# ------------------------------------------------- const globals reach .rodata
# a `const` in the SPECIFIER run names the object, and an object no relocation
# touches may ride the read-only lane. the two exclusions are the whole rule:
# a const POINTEE leaves the pointer writable, and a const array of ADDRESSES is
# a lane the linker writes (gcc spells that one .data.rel.ro).
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

echo "mooncc: cc (laws + return-42 + a $(ls test/cc/*.c | wc -l)-program gcc battery + .o link/interop + -I/-D/-o + multi-input -c + inline asm on both compiler lanes + SysV varargs cross-toolchain + weak override + callee-saved rbx + guaranteed sibcalls + 16-byte stack alignment + our own static linker: multi-.o/.c link, weak strong-over, love_nifs brackets, named-section lanes + their const/writable flag homes, const globals to .rodata, a FOREIGN gcc .o whole, a symbol table nm/gdb read, a .comment naming every producer) ok"


# ------------------------------------------------ the warm compiler
# moon-run ANSWERS its status (moon-main is the same compile, quitting), so one
# image compiles again after a compile that failed -- the cat is read once and
# every cc after it is free. four compiles in one process: good, a hard error, a
# usage error, then good again; the process must reach the last say, the statuses
# must be 0 1 2 0, and the object laid AFTER the two failures must be byte-identical
# to the same compile run cold. a regression to `quit` inside moon-run passes
# every check above this line.
printf 'int wa(int x){return x+1;}\n' > "$ho/.wa.c"
printf 'int wb(void){ return nope; }\n' > "$ho/.wb.c"
# AND THE FLAGS MUST NOT BLEED. The flag walk accumulates into ONE TABLET now, and a
# tablet is mutated in place -- so a second compile in the same process would inherit the
# first's flags if `fnew` ever stopped building a fresh one. The four compiles below all
# carry the same flags and would not notice; this pair does: a flag-bearing compile, then
# a bare one, whose object must equal the bare compile run cold.
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


# ------------------------------------------------ the carried runtime is KERNEL-NEUTRAL
# one archive per ISA, all three cut under -os linux -- and that pin does not reach the
# bytes, because impl.h parts the kernels at RUN time on __love_osv. so every hosted kernel
# must take the CARRIED archive.
# A CLOCK ALONE CANNOT SAY IT WAS TAKEN: out/cache/moon's .a entries make the
# member-compile lane fast too, so a warm cache passes this leg whether the archive was
# read or refused, and a refusal can sit here green for as long as the cache lives. So ask
# the BINARY what it carries -- src/love/src.c matches the arch word and its width, and a
# miss there is silent -- then take the cache away and let the clock mean something.
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
# ..and where the arch has NO translation tables the refusal must stand: riscv's os.c
# reads -os and only linux has an answer, so a BSD there owes a compile that #errors.
# handing it the carried (linux-built) archive would link linux's numbers in silence.
moonrun -t rv64 "$ho/.os.c" -o "$ho/.os.rv" > /dev/null 2>&1 \
  || fail "carried runtime: -t rv64 did not link"
moonrun -t riscv64 -os netbsd "$ho/.os.c" -o "$ho/.os.rvnb" > /dev/null 2>&1 \
  && fail "carried runtime: -t riscv64 -os netbsd linked -- it took linux's archive for a BSD"
echo "mooncc: the carried runtime is kernel-neutral (linux/freebsd/netbsd all take it; riscv's BSDs still refuse) ok"
