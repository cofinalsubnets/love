#!/bin/sh
# t/gate/xfixpoint.sh -- the CROSS-MACHINE fixpoint, in effigy. the x-lane's
# twin objects -- this machine's mooncc,
# -t the other arch -- link love1: machine A's bytes for machine B. Then love1
# itself, under qemu-user standing in for machine B, bakes its own mooncc
# image, rebuilds every TU natively (mooncc's default target is the ground it
# stands on -- no -t below, an a64 machine would pass none), links love2,
# and love1 must equal love2 TO THE BYTE. One cmp says two things at once:
# the twin machine reproduces this machine's bytes (what "same fixpoint
# everywhere" asks for), and mooncc's output does not depend on the arch
# mooncc runs on.
#
# the TU flags MIRROR the Makefile's x-lane (LvHaveVersionH on love.o), the
# fixpoint.sh drift trap wearing its cross face. this gate's first run caught the
# version flag MISSING from the x-lane: the twin named itself "unknown".
# AND THE LIST IS THE ARTIFACT'S, kernel objects included: a gate that links a
# shorter binary than `make` does still answers love1 == love2, and answers it
# about a binary nobody ships.
#
# only the FLAGS are spelled here. the object names are derived from the source paths
# (mkobj below) and the rosters arrive in the environment -- gate_love_c / gate_host_c /
# gate_arch_c / gate_kern_c -- so a rename in the Makefile cannot leave this behind.
#
# gate_seat_c is i/noblob.c: this pair lays no b/src.o, so it answers the carried
# archives itself -- and rides the OBJ list, or the twin link cannot find the body.
# usage: gate_love_c=.. gate_host_c=.. gate_arch_c=.. gate_kern_c=.. gate_seat_c=..
#        xfixpoint.sh OUTDIR LOVE0 QEMU XTGT MKSYS TCO XD XA OBJ...
set -u

ho=$1
love0=$2
qemu=$3
xtgt=$4
mks=$5
tco=$6
xd=$7
xa=$8
shift 8
d=$xd/fix
cat=$ho/.mooncc-cat.l

command -v "$qemu" >/dev/null 2>&1 || { echo "test_xfixpoint: skipped (needs $qemu)"; exit 0; }

fail() { echo "FAIL test_xfixpoint: $*" >&2; exit 1; }

rm -rf "$d"
mkdir -p "$d"

# the object of a source is its PATH under $d, exactly as make lays it under the odir --
# derived, never spelled, so a renamed, moved or newly-added TU cannot leave a stale name
# here. moonlibc drops its a/moon/lib/ stem, the one place make does too.
mkobj() {                    # $1 = source -> $o
  o=${1#./}
  case $o in a/moon/lib/*) o=${o#a/moon/lib/} ;; esac
  o=$d/${o%.c}.o
  mkdir -p "${o%/*}"
}

# love1: machine A's link of the twin -- exactly the dist link, before the bake
# mutates it (the object list arrives FROM make, $(xobjs), never globbed).
moon0() { "$love0" wake "$ho/mooncc0.image" mooncc "$@"; }
moon0 -t "$xtgt" -pie "$@" -o "$d/love1" || fail "love1 cross link"

echo "XFIX $d/love1 rebuilds itself under $qemu"

# machine B: love1 bakes its own compiler image...
LOVE_NO_IMAGE=1 "$qemu" "$d/love1" -l "$cat" -e "(? ((bake \"$d/mooncc1.image\") = 1) (quit 0) (quit 1))" \
  || fail "love1 bakes mooncc1.image under $qemu"

# ...and rebuilds every TU with it, natively, in the order make links them
moon1() { "$qemu" "$d/love1" wake "$d/mooncc1.image" mooncc "$@"; }
for f in $gate_love_c; do
  mkobj "$f"
  moon1 -D ai_tco="$tco" -D LvHaveVersionH -I"$ho" -I. -Il -Ii -Ib/lib -c "$f" "$o" \
    || fail "love1 mooncc -c $f"
done
for f in $gate_host_c $gate_seat_c; do
  mkobj "$f"
  moon1 -D ai_tco="$tco" -I"$ho" -I. -Il -Ii -Ib/lib -c "$f" "$o" || fail "love1 mooncc -c $f"
done
for f in a/moon/lib/moonlibc/math/*.c; do
  mkobj "$f"
  moon1 -Ia/moon/include -c "$f" "$o" || fail "love1 mooncc -c $f"
done
LOVE_NO_IMAGE=1 "$qemu" "$d/love1" -l "$ho/.mksys-cat.l" -q -e "((cite 'moon '$mks) \"$d/sys.o\")" >/dev/null || fail "love1 mksys"
test -s "$d/sys.o" || fail "love1 mksys laid an empty sys.o"

# the kernel the artifact carries (the Makefile's $(xkart_o)), rebuilt native
# and laid the same way. an arch with no seat carries none, and $gate_arch_c is
# empty there -- the makefile draws that line with its own wildcard.
if [ -n "$gate_arch_c" ]; then
  kinc="-I$ho -I. -Il -Ii -Ib/lib -Il/quay -Ia/moon/include"
  for f in $gate_kern_c $gate_arch_c l/quay/paint.c \
           l/quay/cga_8x8.c l/quay/moderndos_8x16.c; do
    mkobj "$f"
    moon1 $kinc -c "$f" "$o" || fail "love1 mooncc -c $f"
  done
  LOVE_NO_IMAGE=1 "$qemu" "$d/love1" -l "$xd/mkvec.l" -q -e "(lay-vec \"$d/kvec.o\" \"$xa\")" \
    || fail "love1 lay-vec"
  test -s "$d/kvec.o" || fail "love1 lay-vec laid an empty kvec.o"
fi

o2=; for o in "$@"; do o2="$o2 $d/${o#$xd/}"; done
moon1 -pie $o2 -o "$d/love2" || fail "love2 link"

cmp "$d/love1" "$d/love2" || fail "love2 differs from love1 -- machine B does not reproduce machine A's bytes"

echo "test_xfixpoint: bee's mooncc -t $xtgt -> love1; love1 under $qemu -> love2; byte-identical -- the twin machine reproduces this machine's bytes"
