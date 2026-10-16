#!/bin/sh
# test/gate/xfixpoint.sh -- the cross-machine fixpoint: this machine's mooncc -t XTGT links
# love1; love1 under qemu-user bakes its own mooncc, rebuilds every TU natively (no -t) and
# links love2, which must equal love1 to the byte. the TU flags mirror the Makefile's x-lane;
# the rosters come in the environment, and the object list is the artifact's, kernel included.
# usage: gate_love_c=.. gate_host_c=.. gate_arch_c=.. gate_kern_c=.. gate_seat_c=..
#        xfixpoint.sh OUTDIR LOVE0 QEMU XTGT MKSYS TCO XOD XA OBJ...
# XOD is the x-lane's object root, where make lays mkvec.l and the objects it passes
. test/gate/skip.sh
set -u

ho=$1
love0=$2
qemu=$3
xtgt=$4
mks=$5
tco=$6
xod=$7
xa=$8
shift 8
d=$xod/fix
cat=$ho/.mooncc-cat.l

command -v "$qemu" >/dev/null 2>&1 || gate_skip "test_xfixpoint: skipped (needs $qemu)"

fail() { echo "FAIL test_xfixpoint: $*" >&2; exit 1; }

rm -rf "$d"
mkdir -p "$d"

# a source's object is its path under $d, as make lays it; moonlibc drops its lib stem
mkobj() {                    # $1 = source -> $o
  o=${1#./}; o=${o#src/}
  case $o in apps/moon/lib/*) o=${o#apps/moon/lib/} ;; esac
  o=$d/${o%.c}.o
  mkdir -p "${o%/*}"
}

# love1: the dist link of the twin, before any bake
moon0() { "$love0" wake "$ho/mooncc0.image" mooncc "$@"; }
moon0 -t "$xtgt" -pie "$@" -o "$d/love1" || fail "love1 cross link"

echo "XFIX $d/love1 rebuilds itself under $qemu"

# under qemu, love1 bakes its own compiler image..
LOVE_NO_IMAGE=1 "$qemu" "$d/love1" -l "$cat" -e "(? ((bake \"$d/mooncc1.image\") = 1) (quit 0) (quit 1))" \
  || fail "love1 bakes mooncc1.image under $qemu"

# ...and rebuilds every TU with it, natively, in the order make links them
moon1() { "$qemu" "$d/love1" wake "$d/mooncc1.image" mooncc "$@"; }
for f in $gate_love_c; do
  mkobj "$f"
  moon1 -D tco="$tco" -D LvHaveVersionH -I"$ho" -I. -Isrc/love -Isrc/inle -Iout/lib -c "$f" "$o" \
    || fail "love1 mooncc -c $f"
done
for f in $gate_host_c $gate_seat_c; do
  mkobj "$f"
  moon1 -D tco="$tco" -I"$ho" -I. -Isrc/love -Isrc/inle -Iout/lib -c "$f" "$o" || fail "love1 mooncc -c $f"
done
for f in src/apps/moon/lib/moonlibc/math/*.c; do
  mkobj "$f"
  moon1 -Isrc/apps/moon/include -c "$f" "$o" || fail "love1 mooncc -c $f"
done
LOVE_NO_IMAGE=1 "$qemu" "$d/love1" -l "$ho/.mksys-cat.l" -q -e "((cite 'moon '$mks) \"$d/sys.o\")" >/dev/null || fail "love1 mksys"
test -s "$d/sys.o" || fail "love1 mksys laid an empty sys.o"

# the kernel the artifact carries; an arch with none has an empty $gate_arch_c
if [ -n "$gate_arch_c" ]; then
  kinc="-I$ho -I. -Isrc/love -Isrc/inle -Iout/lib -Isrc/love/quay -Isrc/apps/moon/include"
  for f in $gate_kern_c $gate_arch_c; do
    mkobj "$f"
    moon1 $kinc -c "$f" "$o" || fail "love1 mooncc -c $f"
  done
  LOVE_NO_IMAGE=1 "$qemu" "$d/love1" -l "$xod/mkvec.l" -q -e "(lay-vec \"$d/kvec.o\" \"$xa\")" \
    || fail "love1 lay-vec"
  test -s "$d/kvec.o" || fail "love1 lay-vec laid an empty kvec.o"
fi

o2=; for o in "$@"; do o2="$o2 $d/${o#$xod/}"; done
moon1 -pie $o2 -o "$d/love2" || fail "love2 link"

cmp "$d/love1" "$d/love2" || fail "love2 differs from love1 -- machine B does not reproduce machine A's bytes"

echo "test_xfixpoint: bee's mooncc -t $xtgt -> love1; love1 under $qemu -> love2; byte-identical -- the twin machine reproduces this machine's bytes"
