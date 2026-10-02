#!/bin/sh
# test/gate/selfhost.sh -- the rung-2 self-host gate: every C file of the love and host
# lanes compiled by mooncc, the libc too, and the SYSTEM linker binding them. test_raw
# is the gcc-free twin, our own linker doing the bind; this holds mooncc's objects to a
# linker it did not write. x86-64 only.
#
# the objects are moonlibc's all through (mooncc predefines __moonlibc__, and posix.c
# takes kqueue, sysctl and __ai_birth from it), so moonlibc is what they link against --
# compiled member by member into an archive, so ld takes a member only where a symbol
# asks. crt0 is mooncc's own, laid with a _start the ld can name, and sys.o is mksys's,
# as test_raw lays it. the load table rides love_data.ld; the -pie reloc table is empty.
#
# usage: gate_love_c=.. gate_host_c=.. gate_seat_c=.. selfhost.sh OUTDIR LOVE CORPUS.l ..
. test/gate/skip.sh
set -u
ho=$1
m=$2
shift 2
fail() { echo "FAIL selfhost: $*" >&2; exit 1; }

if [ "`uname -m`" != x86_64 ]; then gate_skip "test_selfhost: x86-64 only, skipped on `uname -m`"; fi
d=$ho/selfhost
mkdir -p "$d/obj" "$d/libc"
rm -f "$d/obj/"*.o "$d/libc/"*.o "$d/libmoon.a"

for f in $gate_love_c $gate_host_c $gate_seat_c; do
  "$m" mooncc -D ai_tco=1 -I"$ho" -I. -Isrc/love -Isrc/inle -Iout/lib -c "$f" "$d/obj/`basename $f .c`.o" \
    || fail "mooncc -c $f"
done
"$m" mooncc -Isrc/apps/moon/include -c src/apps/moon/lib/moonlibc/math/lm.c "$d/obj/lm.o" || fail "mooncc -c lm.c"

for f in `find src/apps/moon/lib/moonlibc -name '*.c' | LC_ALL=C sort`; do
  b=`echo "$f" | sed 's#src/apps/moon/lib/moonlibc/##; s#/#_#g; s#\.c$##'`
  "$m" mooncc -Isrc/apps/moon/lib/moonlibc -Isrc/apps/moon/include -c "$f" "$d/libc/$b.o" || fail "mooncc -c $f"
done
ar rcs "$d/libmoon.a" "$d/libc/"*.o || fail "ar the libc"

{ echo "(borrow 'posix) (borrow 'holo)"
  echo "(: b (string (objelf 'x64 (['label '_start] . (cite 'moon 'crt0)) () '(\"_start\" \"__ai_start\") () '(\"__ai_start\") () () () () ()))"
  echo "   q (open \"$d/crt0.o\" \"w\") (: _ (say q b) (close q)))"
} | "$m" || fail "lay crt0.o"
{ cat src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l src/love/holo/elf.l src/love/holo/obj.l src/apps/moon/lib/mksys.l
  echo "((cite 'moon 'mksys-x64) \"$d/sys.o\")"
} | "$m" || fail "lay sys.o"

${CC:-cc} -static -nostdlib -Wl,-T,src/love/love_data.ld \
    -Wl,--defsym=__start_love_rela=0 -Wl,--defsym=__stop_love_rela=0 \
    -o "$ho/love-selfhost" "$d/crt0.o" "$d/obj/"*.o "$d/sys.o" "$d/libmoon.a" \
  || fail "link the all-mooncc binary"

cat "$@" > "$ho/.selfhost-corpus.l"
LOVE_NO_IMAGE=1 "$ho/love-selfhost" "$ho/.selfhost-corpus.l" </dev/null > "$ho/.test_selfhost.out" 2>&1
s=$?
tail -1 "$ho/.test_selfhost.out"
{ [ $s -eq 0 ] && grep -q "tests pass" "$ho/.test_selfhost.out"; } || fail "all-mooncc corpus (exit $s)"
echo "test_selfhost: every love C file and moonlibc built by mooncc, the system linker binds them, corpus passes"
