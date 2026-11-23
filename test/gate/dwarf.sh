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
# x64 and a64 lay .debug_frame under -g; a function whose rows refuse lays none, never failing
# the compile: raster.c's rz_row is one on a64
for t in x64 a64; do
  [ -z "$dd" ] || "$dd" --debug-frame "$d/two.$t" | grep -q ' FDE ' || { echo "FAIL $name: $t has no fde"; exit 1; }
done
mc -t a64 -os linux -g -Isrc/love -Isrc/inle -Iout -Iout/lib -I. -c src/love/raster.c -o "$d/raster.o"
# the hole kept in sight: raster.c's a64 functions that lay no fde
holes=-
if [ -n "$dd" ]; then
  nf=`"$ho/love" nm "$d/raster.o" | awk '$2 ~ /^[Tt]$/' | wc -l`
  ne=`"$dd" --debug-frame "$d/raster.o" | grep -c ' FDE '`
  holes=`expr $nf - $ne`
fi

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
  ( cd "$d" && "$gdb" -q -batch -nx -ex 'ptype head' -ex 'ptype struct a' -ex 'ptype uu' -ex 'ptype y' \
      -ex 'print head' -ex 'print cnt' -ex 'print bb.k' ./y.x64 ) > "$d/gdby.out" 2>&1
  for w in 'struct node \*nx;' 'struct b \*pb;' 'char c\[4\];' 'type = int (struct node \*, unsigned long)' \
           '= {v = 7, nx = 0x0}' '= 3$' '= 4$'; do
    grep -q "$w" "$d/gdby.out" || { cat "$d/gdby.out"; echo "FAIL $name: gdb's types: $w"; exit 1; }
  done
else
  gate_partly "$name: no gdb on x64 here, its session skipped"
fi
echo "dwarf: two units on x64 a64 rv64 verified, gdb breaks by line in each and unwinds, and reads types and globals; a64 raster.c: $holes function(s) without an fde"
