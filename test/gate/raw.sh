#!/bin/sh
# test/gate/raw.sh -- the gcc-free love for one target: the source lanes, moonlibc by need,
# the lm math, mksys's sys.o, bound by our own linker, then the corpus over the fresh egg.
# x64 native, rv64 under qemu-user, a64 on an a64 host or qemu-user. the source lanes come
# in the environment; gate_seat_c answers the kernel's doors and the carried archives.
# usage: gate_love_c=.. gate_host_c=.. raw.sh TARGET OUTDIR LOVE CORPUS.l ..
. test/gate/skip.sh
. test/gate/a64run.sh
set -u
gate_sentinel=${gate_sentinel-}

target=$1
ho=$2
m=$3
shift 3

case $target in
  x64)     name=test_raw        ; tflag=""           ; sub=raw     ; bin=love-raw
           out=.test_raw.out    ; mksys=mksys-x64    ; backend=""
           run=""               ; need=""            ; pretty=x64 ;;
  rv64) name=test_raw_rv64  ; tflag="-t rv64" ; sub=raw-rv64; bin=love-raw-rv64
           out=.test_raw_rv.out ; mksys=mksys-rv64  ; backend=src/love/holo/rv64.l
           run=qemu-riscv64     ; need=qemu-riscv64  ; pretty=rv64 ;;
  a64)   name=test_raw_a64  ; tflag="-t a64"   ; sub=raw-a64 ; bin=love-raw-a64
           out=.test_raw_a64.out; mksys=mksys-a64  ; backend=src/love/holo/a64.l
           run=qemu-aarch64     ; need=qemu-aarch64  ; pretty=a64 ;;
  *) echo "raw.sh: unknown target $target" >&2; exit 1 ;;
esac

fail() { echo "FAIL $name: $*" >&2; exit 1; }

# x64 wants an x64 host; gate_hosta is the isa word, which `uname -m` is not
if [ -z "$need" ]; then
  if [ "$gate_hosta" != x64 ]; then
    gate_skip "$name: x86-64 only, skipped on ${gate_hosta:-unknown}"
  fi
elif [ "$target" = a64 ]; then
  a64_how "$m"
  [ -n "$a64_via" ] || gate_skip "$name: no $need and no a64 host, skipped"
elif ! command -v "$need" > /dev/null 2>&1; then
  gate_skip "$name: no $need, skipped"
fi

echo "RAW $ho/$bin"
d=$ho/$sub
mkdir -p "$d"
rm -f "$d"/*.o

# shellcheck disable=SC2086  # $tflag is a word pair or empty, deliberately unquoted
moonc() { LOVE_NO_IMAGE= "$m" mooncc $tflag "$@"; }

for f in $gate_love_c $gate_host_c $gate_seat_c; do
  b=$(basename "$f" .c)
  moonc -D tco=1 -I"$ho" -I. -Isrc/love -Isrc/inle -Iout/lib -c "$f" "$d/$b.o" || fail "mooncc $tflag -c $f"
done

# moonlibc is not compiled here: the driver supplies its members by need at the link
for f in src/apps/moon/lib/moonlibc/math/*.c; do
  b=$(basename "$f" .c)
  moonc -Isrc/apps/moon/lib/moonlibc/math -Isrc/apps/moon/include -c "$f" "$d/m_$b.o" || fail "mooncc $tflag -c $f"
done

# sys.o (the syscall trampoline, sigsetjmp/longjmp) is laid by mksys.l. a cross target
# loads its holo backend first: the host bake carries only the native one
{ if [ -n "$backend" ]; then
    echo "(borrow 'holo)"
    cat "$backend"
  fi
  cat src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l \
      src/love/holo/elf.l src/love/holo/obj.l src/apps/moon/lib/mksys.l
  echo "((cite 'moon '$mksys) \"$d/sys.o\")"
} | "$m" || fail "$mksys sys.o"

moonc "$d"/*.o -o "$ho/$bin" || fail "our-linker bind $bin"

# the fresh-egg boot under a 420 s ceiling. the corpus is a file, stdin closed: it tests stdin
cat "$@" > "$ho/.corpus-$target.l"
if [ "$target" = a64 ]; then
  # the corpus reads the tree beside it, so the carried source goes over too
  a64_jobs "$ho/raw-a64-run"
  cp "$ho/$bin" "$ho/.corpus-$target.l" "$ho/raw-a64-run/"
  a64_tree || fail "$m would not lay its carried tree"
  a64_job corpus "cd tree && LOVE_NO_IMAGE=1 timeout 420 \$RUN ../$bin ../.corpus-$target.l"
  a64_run "$ho/raw-a64-run" || fail "the a64 run did not come back"
  cp "$ho/raw-a64-run/res/corpus.out" "$ho/$out"
  s=$(cat "$ho/raw-a64-run/res/corpus.rc")
else
  LOVE_NO_IMAGE=1 timeout 420 $run "$ho/$bin" "$ho/.corpus-$target.l" </dev/null > "$ho/$out" 2>&1
  s=$?
fi
tail -1 "$ho/$out"
[ $s -eq 0 ] && grep -q "tests pass" "$ho/$out" || fail "corpus (exit $s)"
# the sentinel file proves the corpus was read to its end
[ -z "$gate_sentinel" ] || grep -q "$gate_sentinel" "$ho/$out" \
  || fail "no sentinel /$gate_sentinel/ -- a file was skipped or read past"

case $target in
  x64) echo "test_raw: the src/*.c lanes + moonlibc + lm math + sys.o, our linker, no gcc/glibc/ld -- corpus passes" ;;
  a64) echo "$name: the gcc-free $pretty love -- mooncc objects, $mksys, our linker, corpus $([ "$a64_via" = host ] && echo "on an a64 host" || echo "under qemu")" ;;
  *)   echo "$name: the gcc-free $pretty love -- mooncc objects, $mksys, our linker, corpus under qemu" ;;
esac
