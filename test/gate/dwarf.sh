#!/bin/sh
# test/gate/dwarf.sh -- mooncc -g through the link: each unit's debug sections laid past the
# image and relocated, judged by llvm-dwarfdump --verify on x64, a64 and rv64, and by gdb on
# this box breaking by line in each unit and unwinding by .debug_frame. a link of objects
# without -g lays none; strip takes them.
# skips a leg whose oracle is missing.
# usage: dwarf.sh OUTDIR
. test/gate/skip.sh
set -u

ho=$1
name=test_dwarf
dd=`command -v llvm-dwarfdump 2>/dev/null || true`
gdb=`command -v gdb 2>/dev/null || true`
[ -n "$dd" ] || [ -n "$gdb" ] || gate_skip "$name: no llvm-dwarfdump or gdb, skipped"

d=$ho/dwarf
rm -rf "$d"; mkdir -p "$d"
echo "DWARF $d"
cat > "$d/t.c" <<'EOF'
struct pt { int x, y; };
int twice(int);
static int sq(int v) { return v * v; }
int dist(struct pt *p, int k) {
  int s = 0;
  for (int i = 0; i < k; i++) s += sq(p[i].x) + sq(p[i].y);
  return s;
}
int main(void) { struct pt a[2] = {{1,2},{3,4}}; return dist(a, 2) + twice(1); }
EOF
cat > "$d/u.c" <<'EOF'
int twice(int v) {
  return v + v;
}
EOF

mc() { "$ho/love" mooncc "$@" || { echo "FAIL $name: mooncc $*"; exit 1; }; }
for t in x64 a64 rv64; do
  mc -t $t -g -c "$d/t.c" -o "$d/t.$t.o"
  mc -t $t -g -c "$d/u.c" -o "$d/u.$t.o"
  mc -t $t -os linux "$d/t.$t.o" "$d/u.$t.o" -o "$d/two.$t"
  if [ -n "$dd" ]; then
    "$dd" --verify "$d/two.$t" > "$d/v.$t" 2>&1 || { cat "$d/v.$t"; echo "FAIL $name: $t --verify"; exit 1; }
    n=`"$dd" --debug-info "$d/two.$t" | grep -c DW_TAG_compile_unit`
    [ "$n" = 2 ] || { echo "FAIL $name: $t has $n units, not 2"; exit 1; }
    # a subprogram for each function laid, named, at its body's line
    "$dd" --debug-info "$d/two.$t" > "$d/i.$t"
    for f in dist:4 main:9 twice:1; do
      grep -A1 "DW_AT_name.*\"${f%:*}\")" "$d/i.$t" | grep -q "DW_AT_low_pc" \
        && grep -A4 "DW_AT_name.*\"${f%:*}\")" "$d/i.$t" | grep -q "DW_AT_decl_line.*(${f#*:})" \
        || { echo "FAIL $name: $t's subprogram ${f%:*} at line ${f#*:}"; exit 1; }
    done
  fi
done
[ -n "$dd" ] || gate_partly "$name: no llvm-dwarfdump, --verify skipped"
# .debug_frame under -g, an fde for each function: raster.c's, past jump tables, restores and d29
for t in x64 a64 rv64; do
  [ -z "$dd" ] || "$dd" --debug-frame "$d/two.$t" | grep -q ' FDE ' || { echo "FAIL $name: $t has no fde"; exit 1; }
  mc -t $t -os linux -g -Isrc/love -Isrc/inle -Iout -Iout/lib -I. -c src/love/raster.c -o "$d/raster.o"
  if [ -n "$dd" ]; then
    "$dd" --debug-info "$d/raster.o" | awk '/DW_TAG/ {f = /subprogram/} f && /low_pc/ {gsub(/[^0-9a-fx]/, "", $2); print substr($2, 3)}' | sed 's/^0*//' | sort -u > "$d/r.fns"
    "$dd" --debug-frame "$d/raster.o" | sed -n 's/.* FDE .*pc=0*\([0-9a-f]*\)\.\.\..*/\1/p' | sort -u > "$d/r.fdes"
    n=`comm -23 "$d/r.fns" "$d/r.fdes" | wc -l`
    [ -s "$d/r.fns" ] && [ "$n" = 0 ] || { echo "FAIL $name: $t raster.c: $n of `wc -l < "$d/r.fns"` functions without an fde"; exit 1; }
  fi
done

# types and globals: a struct that points at itself and a pair that point at each other, each
# compile held to 1 GB and a minute, so a walk that never ends fails here and takes no more
cat > "$d/y.c" <<'EOF'
struct node { int v; struct node *nx; };
struct a;
struct b { struct a *pa; int k; };
struct a { struct b *pb; short s; };
union u { float f; char c[4]; };
struct node head = {7, 0};
struct a aa;
struct b bb = {&aa, 4};
union u uu;
long (*fp)(int);
static unsigned long cnt = 3;
int y(struct node *n, unsigned long k) { return n->v + k + cnt + bb.k; }
int main(void) { return y(&head, 1) - 15; }
EOF
tmo=`command -v timeout 2>/dev/null || true`
for t in x64 a64 rv64; do
  ( ulimit -v 1048576; LOVE_BUDGET_MB=512 $tmo ${tmo:+60} "$ho/love" mooncc -t $t -os linux -g "$d/y.c" -o "$d/y.$t" ) \
    || { echo "FAIL $name: $t types under 1 GB and a minute"; exit 1; }
  if [ -n "$dd" ]; then
    "$dd" --verify "$d/y.$t" > "$d/vy.$t" 2>&1 || { cat "$d/vy.$t"; echo "FAIL $name: $t types --verify"; exit 1; }
  fi
done

# locals and params in memory and registers, each block its own scope: a shadowed name, a static, a vla, a
# struct by value, a copy the optimizer takes in, a param at the entry, under callee-saved registers
cat > "$d/l.c" <<'EOF'
struct s { long a, b, c; };
static long sum;
static void use(void *p) { sum += *(char *)p; }
static void (*volatile go)(void *) = use;
long loc(int n, struct s by, long k) {
  int x = n; go(&x);
  { long x = k * 2; go(&x);
    for (int i = 0; i < by.a; i++) { char z[4] = "abc"; go(z);
      sum += n + k; } }
  { short x = 9; static int cnt = 40; cnt++; go(&x);
    sum += x + cnt; }
  int v[n]; v[0] = 77; go(v);
  sum += v[0];
  return x + by.b + n + k;
}
__attribute__((noinline)) long al(long a, long b) {
  long p = a * b;
  go(&sum); go(&sum);
  return p + a; }
int main(void) { struct s s = {1, 22, 3}; long r = loc(5, s, 100); r += al(6, 7); return r - 180; }
EOF
for t in x64 a64 rv64; do
  mc -t $t -os linux -g "$d/l.c" -o "$d/l.$t"
  if [ -n "$dd" ]; then
    "$dd" --verify "$d/l.$t" > "$d/vl.$t" 2>&1 || { cat "$d/vl.$t"; echo "FAIL $name: $t locals --verify"; exit 1; }
    n=`"$dd" --debug-info "$d/l.$t" | grep -c DW_TAG_lexical_block`
    [ "$n" = 4 ] || { echo "FAIL $name: $t has $n blocks, not 4"; exit 1; }
  fi
done

# a call spliced as statements is an inlined copy, one inside another too, one in an arm laid out of line: its callee, its call's place, its names
cat > "$d/i.c" <<'EOF'
static long sum;
__attribute__((noinline)) long opq(long v) {
  sum += v;
  return sum; }
static inline __attribute__((always_inline)) void add(long v, int n) {
  long t = v * n;
  opq(t);
  sum += t; }
static inline __attribute__((always_inline)) void both(long q) {
  long u = q + 1;
  opq(u);
  add(u, 2); }
int main(int c, char **v) {
  add(c + 4, c + 2);
  both(c + 9);
  opq(c);
  return 0; }
int sq(int x) {
  int y = x * x;
  return y + 1; }
int q(int a) { if (a)
    return sq(a);
  return 7; }
EOF
for t in x64 a64 rv64; do
  mc -t $t -os linux -g "$d/i.c" -o "$d/i.$t"
  if [ -n "$dd" ]; then
    "$dd" --verify "$d/i.$t" > "$d/vi.$t" 2>&1 || { cat "$d/vi.$t"; echo "FAIL $name: $t inlined --verify"; exit 1; }
    n=`"$dd" --debug-info "$d/i.$t" | grep -c DW_TAG_inlined_subroutine`
    [ "$n" = 4 ] || { echo "FAIL $name: $t has $n inlined copies, not 4"; exit 1; }
  fi
done

# a copy whose arm moved covers no code moved from elsewhere: no line row in one is a line of no callee's
cat > "$d/o.c" <<'EOF'
long opq(long);
struct g { long a, b, n; char *p; };
static inline __attribute__((always_inline)) long torn(struct g *g, long k) {
  g->n = k;
  g->b = 0;
  return -1; }
static inline __attribute__((always_inline)) long same(long v) {
  if (v < 0)
    return -1;
  return opq(v); }
long read1(struct g *g, long c) {
  for (;;) {
    c = opq(c);
    if (c == 1) return torn(g, 4);
    if (c == 2) { g->a += c; continue; }
    if (c == 3) {
      g->b = opq(g->a);
      if (g->b < 0) return torn(g, 5);
      break; }
    if (c > 90) return torn(g, c);
    g->n++; }
  for (long i = 0; i < g->a; i++) {
    g->p[i] = i;
    if (opq(i) < 0) return same(i); }
  return same(g->a); }
EOF
for t in x64 a64 rv64; do
  mc -t $t -os linux -g -c "$d/o.c" -o "$d/o.$t"
  if [ -n "$dd" ]; then
    "$dd" --debug-line "$d/o.$t" | awk '/^0x/ && !/end_sequence/ {print "x" substr($1, 3), $2}' > "$d/o.rows"
    "$dd" --debug-info "$d/o.$t" | awk '/DW_TAG/ {i = /inlined_subroutine/} i && /low_pc/ {gsub(/[^0-9a-fx]/, "", $2); lo = "x" substr($2, 3)}
      i && /high_pc/ {gsub(/[^0-9a-fx]/, "", $2); print lo, "x" substr($2, 3)}' > "$d/o.copies"
    b=`awk 'NR == FNR {lo[NR] = $1; hi[NR] = $2; n = NR; next} $2 > 11 {for (i = 1; i <= n; i++) if (lo[i] <= $1 && $1 < hi[i]) print $1, $2}' "$d/o.copies" "$d/o.rows"`
    n=`wc -l < "$d/o.copies"`
    [ -z "$b" ] && [ "$n" -ge 5 ] || { cat "$d/o.copies"; echo "FAIL $name: $t: $n copies, rows of another's code in them: $b"; exit 1; }
  fi
done

# the 32-bit targets, linked: addresses of 4 bytes in the target's order, a unit whose range is its code,
# and no thumb bit in either
for t in rv32 mips arm i386; do
  mc -t $t -os linux -g "$d/y.c" -o "$d/y.$t"
  mc -t $t -os linux -g "$d/l.c" -o "$d/l.$t"
  if [ -n "$dd" ]; then
    for f in y l; do
      "$dd" --verify "$d/$f.$t" > "$d/v$f.$t" 2>&1 || { cat "$d/v$f.$t"; echo "FAIL $name: $t $f --verify"; exit 1; }
      "$dd" --debug-info "$d/$f.$t" > "$d/i$f.$t" 2>&1
      grep -q 'addr_size = 0x04' "$d/i$f.$t" || { echo "FAIL $name: $t's addresses are not 4 bytes"; exit 1; }
      m=`"$ho/love" nm "$d/$f.$t" | awk '$3 == "main" {print $1}' | sed 's/^0*//'`
      [ $t = arm ] && m=`printf %x $(( 0x$m / 2 * 2 ))`
      r=`sed -n '/DW_AT_ranges/,/)$/ s/.*\[0x0*\([0-9a-f]*\), 0x0*\([0-9a-f]*\)).*/\1 \2/p' "$d/i$f.$t" | head -1`
      lo=${r% *} hi=${r#* }
      [ -n "$m" ] && [ -n "$lo" ] && [ `printf %d 0x$lo` -le `printf %d 0x$m` ] && [ `printf %d 0x$m` -lt `printf %d 0x$hi` ] \
        || { cat "$d/i$f.$t" | head -30; echo "FAIL $name: $t's unit does not cover main ($m in $r)"; exit 1; }
      "$dd" --debug-line "$d/$f.$t" | grep -q "^0x0*$m " || { echo "FAIL $name: $t has no line row at main"; exit 1; }
    done
  fi
done

# without -g no debug section; strip -g takes them
mc -c "$d/u.c" -o "$d/u0.o"
mc -t x64 -os linux -c "$d/t.c" -o "$d/t0.o"
mc -os linux "$d/t0.o" "$d/u0.o" -o "$d/two0"
"$ho/love" readelf -S "$d/two0" | grep -q debug && { echo "FAIL $name: a link without -g lays debug"; exit 1; }
"$ho/love" strip -g -o "$d/two.s" "$d/two.x64" || { echo "FAIL $name: strip -g"; exit 1; }
"$ho/love" readelf -S "$d/two.s" | grep -q debug && { echo "FAIL $name: strip -g leaves debug"; exit 1; }

if [ -n "$gdb" ] && [ "`uname -m`" = x86_64 ]; then
  ( cd "$d" && "$gdb" -q -batch -nx -ex 'break u.c:2' -ex 'break t.c:6' -ex 'info scope twice' -ex run -ex continue -ex bt -ex finish ./two.x64 ) > "$d/gdb.out" 2>&1
  grep -q 'Breakpoint 2, dist (p=.*, k=.*) at .*t.c:6' "$d/gdb.out" && grep -q 'Breakpoint 1, twice (v=.*) at .*u.c:2' "$d/gdb.out" \
    || { cat "$d/gdb.out"; echo "FAIL $name: gdb by line"; exit 1; }
  grep -q 'Symbol v is' "$d/gdb.out" || grep -q 'No locals' "$d/gdb.out" || grep -q 'contains no locals' "$d/gdb.out" \
    || { cat "$d/gdb.out"; echo "FAIL $name: gdb finds no scope for twice"; exit 1; }
  grep -q '^#1  0x[0-9a-f]* in main () at .*t.c:' "$d/gdb.out" && grep -q '^0x[0-9a-f]* in main () at .*t.c:' "$d/gdb.out" \
    || { cat "$d/gdb.out"; echo "FAIL $name: gdb's bt and finish by .debug_frame"; exit 1; }
  ( cd "$d" && "$gdb" -q -batch -nx -ex 'ptype head' -ex 'ptype struct a' -ex 'ptype uu' -ex 'ptype y' -ex 'ptype fp' \
      -ex 'print head' -ex 'print cnt' -ex 'print bb.k' ./y.x64 ) > "$d/gdby.out" 2>&1
  for w in 'struct node \*nx;' 'struct b \*pb;' 'char c\[4\];' 'type = int (struct node \*, unsigned long)' \
           'type = long (\*)(' '= {v = 7, nx = 0x0}' '= 3$' '= 4$'; do
    grep -q "$w" "$d/gdby.out" || { cat "$d/gdby.out"; echo "FAIL $name: gdb's types: $w"; exit 1; }
  done
  ( cd "$d" && "$gdb" -q -batch -nx -ex 'break l.c:9' -ex 'break l.c:11' -ex 'break l.c:14' -ex run \
      -ex 'echo A\n' -ex 'print x' -ex 'print z' -ex 'print by.b' -ex 'print n' -ex 'print k' -ex 'print i' -ex continue -ex 'echo B\n' -ex 'print x' -ex 'print cnt' -ex 'print n' \
      -ex continue -ex 'echo C\n' -ex 'print x' -ex 'print v[0]' -ex 'up' -ex 'print s.b' \
      -ex 'break *al' -ex 'break l.c:19' -ex continue -ex 'echo D\n' -ex 'print b' -ex continue -ex 'echo E\n' -ex 'print p' ./l.x64 ) > "$d/gdbl.out" 2>&1
  l=`sed -n 's/^\([A-E]\)$/\1/p; s/^\$[0-9]* = //p' "$d/gdbl.out" | tr '\n' ' '`
  [ "$l" = 'A 200 "abc" 22 5 100 0 B 9 41 5 C 5 77 22 D 7 E 42 ' ] || { cat "$d/gdbl.out"; echo "FAIL $name: gdb's locals: $l"; exit 1; }
  ( cd "$d" && "$gdb" -q -batch -nx -ex 'break opq' -ex run -ex bt -ex 'up' -ex 'print t' -ex continue -ex continue -ex bt -ex up -ex up -ex 'print u' \
      -ex continue -ex bt ./i.x64 ) > "$d/gdbi.out" 2>&1
  l=`sed -n 's/^#\([0-9]\)  *\(0x[0-9a-f]* in \)\{0,1\}\([a-z]*\) (.*i\.c:\([0-9]*\)$/\1\3:\4/p; s/^\$[0-9]* = //p' "$d/gdbi.out" | tr '\n' ' '`
  [ "$l" = '0opq:3 1add:5 2main:14 1add:5 15 0opq:3 1add:5 2both:9 3main:15 1add:5 2both:9 <optimized out> 0opq:3 1main:16 ' ] \
    || { cat "$d/gdbi.out"; echo "FAIL $name: gdb's inlined copies: $l"; exit 1; }
else
  gate_partly "$name: no gdb on x64 here, its session skipped"
fi
# the same on a64 and rv64, under qemu's user stub
for t in a64 rv64; do
  case $t in a64) q=qemu-aarch64;; *) q=qemu-riscv64;; esac
  if [ -z "$gdb" ] || ! command -v $q > /dev/null 2>&1 || ! "$gdb" -q -batch -nx -ex "file $d/two.$t" -ex 'info line main' 2>/dev/null | grep -q 'Line 9'; then
    gate_partly "$name: no gdb or $q for $t, its session skipped"; continue
  fi
  # ses PROGRAM OUT gdb-args..
  ses() {
    sp=$1; so=$2; shift 2
    ( cd "$d" && rm -f q.sock && { $q -g q.sock ./$sp > /dev/null 2>&1 & }
      n=0; while [ ! -S q.sock ] && [ $n -lt 50 ]; do sleep 0.1; n=`expr $n + 1`; done
      $tmo ${tmo:+60} "$gdb" -q -batch -nx -ex "file $sp" -ex 'target remote q.sock' "$@" ) > "$d/$so" 2>&1 < /dev/null
  }
  ses two.$t gdbt.$t -ex 'break *twice' -ex 'break t.c:6' -ex continue -ex bt -ex continue -ex bt -ex finish -ex 'print $pc' -ex kill
  grep -q 'Breakpoint 2, dist (p=.*, k=.*) at .*t.c:6' "$d/gdbt.$t" && grep -q 'Breakpoint 1, twice (v=1) at .*u.c:[12]' "$d/gdbt.$t" \
    && grep -q '^#1  0x[0-9a-f]* in main () at .*t.c:' "$d/gdbt.$t" && grep -q '^0x[0-9a-f]* in main () at .*t.c:' "$d/gdbt.$t" \
    || { cat "$d/gdbt.$t"; echo "FAIL $name: $t's gdb, by line, bt and finish"; exit 1; }
  ses l.$t gdbl.$t -ex 'break l.c:9' -ex 'break l.c:11' -ex 'break l.c:14' -ex continue \
      -ex 'echo A\n' -ex 'print x' -ex 'print z' -ex 'print by.b' -ex 'print n' -ex 'print k' -ex 'print i' -ex continue -ex 'echo B\n' -ex 'print x' -ex 'print cnt' -ex 'print n' \
      -ex continue -ex 'echo C\n' -ex 'print x' -ex 'print v[0]' -ex 'up' -ex 'print s.b' \
      -ex 'break *al' -ex 'break l.c:19' -ex continue -ex 'echo D\n' -ex 'print b' -ex continue -ex 'echo E\n' -ex 'print p' -ex kill
  l=`sed -n 's/^\([A-E]\)$/\1/p; s/^\$[0-9]* = //p' "$d/gdbl.$t" | tr '\n' ' '`
  [ "$l" = 'A 200 "abc" 22 5 100 0 B 9 41 5 C 5 77 22 D 7 E 42 ' ] || { cat "$d/gdbl.$t"; echo "FAIL $name: $t's gdb's locals: $l"; exit 1; }
done
echo "dwarf: two units on x64 a64 rv64 verified, gdb breaks by line in each and unwinds, reads types, globals, locals and inlined copies; every function of raster.c has an fde"
