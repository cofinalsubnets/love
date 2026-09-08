#!/bin/sh
# test/gate/fixpoint.sh -- the SELF-REGENERATION fixpoint (self-host rung 2).
# The default out/love is mooncc-built already (love0 waking mooncc0.image
# compiles every TU, holo links -pie). This gate closes the loop: relink that
# generation as love1, let love1 bake its OWN mooncc image and rebuild every TU
# with itself, link love2 the same way, and assert love1 == love2 TO THE BYTE.
# One diff = the fixpoint + the determinism differential + the trusting-trust
# half in a single compare (the DDC leg proper adds a foreign-compiled love0;
# the 2026-07-27 audit ran that lane green).
#
# make owns the dependency graph (the moon_o objects + mooncc0.image exist) AND the
# source lanes; this owns the procedure. NOT set -e: the compile loop reports its own
# file. ⚠ the lanes arrive in the environment because the object list already has the
# variadic tail -- gate_love_c / gate_host_c / gate_arch_c / gate_kern_c, the Makefile's own.
#
# usage: gate_love_c=.. gate_host_c=.. gate_arch_c=.. gate_kern_c=..
#        fixpoint.sh OUTDIR LOVE0 HOSTA ODIR OBJ...
set -u

ho=$1
love0=$2
ha=$3
md=$4          # $(moon_d) -- the odir make laid the objects in, stripped off below
shift 4
d=$ho/fix
cat=$ho/.mooncc-cat.l

# any arch a seed can be laid for owes this invariant (doc/misc/plan/seed-universal.md
# U0); an arch off the roster skips, it does not fail. the mksys leaf is the
# host's own (the twin roster, the Makefile).
# ⚠ the spelling arrives as $(hosta), never from `uname -m` here: on the BSDs those two
# disagree (amd64, evbarm), and a gate that spells the arch itself is a second authority.
case "$ha" in
  x64)  mks=mksys-x64 ;;
  a64) mks=mksys-a64 ;;
  rv64) mks=mksys-rv64 ;;
  *) echo "test_fixpoint: no seed for $ha, skipped"; exit 0
esac

fail() { echo "FAIL test_fixpoint: $*" >&2; exit 1; }

rm -rf "$d"
mkdir -p "$d"

# the object of a source is its PATH under $d, exactly as make lays it under the odir --
# derived, never spelled, so a renamed, moved or newly-added TU cannot leave a stale name
# here. moonlibc drops its apps/moon/lib/ stem, the one place make does too.
mkobj() {                    # $1 = source -> $o
  o=${1#./}
  case $o in apps/moon/lib/*) o=${o#apps/moon/lib/} ;; esac
  o=$d/${o%.c}.o
  mkdir -p "${o%/*}"
}

# love1: relink the generation make already compiled (love0's lane, byte-cheap).
# ⚠ the list arrives FROM make ($(moon_o) $(kart_o), source-derived) and is never globbed out of
# the odir: a deleted src/*.c leaves its .o sitting there, and a glob relinks the ghost --
# love1 carrying a TU love2 never compiles, which reads as a broken fixpoint.
moon0() { "$love0" wake "$ho/mooncc0.image" mooncc "$@"; }
moon0 -pie "$@" -o "$d/love1" || fail "love1 relink"

echo "FIX  $d/love1 rebuilds itself"

# love1 bakes its own compiler image (anchor-checked to love1)...
LOVE_NO_IMAGE=1 "$d/love1" -l "$cat" -e "(? ((bake \"$d/mooncc1.image\") = 1) (quit 0) (quit 1))" \
  || fail "love1 bakes mooncc1.image"

# ...and rebuilds every TU with it, in the exact order make links them
moon1() { "$d/love1" wake "$d/mooncc1.image" mooncc "$@"; }
# ⚠ l/love.c's flags must MIRROR make's ($(moon_d)/love.o in the Makefile), not just its
# order: -D AiHaveVersionH is what puts the version id in this TU, and love1 was linked
# from make's object. Drop it here and love2 carries "unknown" -- the compare fails at the
# string, naming a broken fixpoint where the only difference is a build flag.
for f in $gate_love_c; do
  mkobj "$f"
  moon1 -D ai_tco=1 -D AiHaveVersionH -I"$ho" -I. -Il -Iinle -Iout/lib -c "$f" "$o" \
    || fail "love1 mooncc -c $f"
done
for f in $gate_host_c; do
  mkobj "$f"
  moon1 -D ai_tco=1 -I"$ho" -I. -Il -Iinle -Iout/lib -c "$f" "$o" || fail "love1 mooncc -c $f"
done
# moonlibc rides the implicit runtime, as in raw.sh -- pulled member by need.
for f in apps/moon/lib/moonlibc/math/*.c; do
  mkobj "$f"
  moon1 -Iapps/moon/include -c "$f" "$o" || fail "love1 mooncc -c $f"
done
LOVE_NO_IMAGE=1 "$d/love1" -l "$ho/.mksys-cat.l" -e "((from 'moon '$mks) \"$d/sys.o\")" >/dev/null || fail "love1 mksys"
test -s "$d/sys.o" || fail "love1 mksys laid an empty sys.o"

# the kernel the artifact carries (the Makefile's $(kart_o)): the link takes it,
# so the rebuild owes it. ⚠ a gate that links what make links and compiles less
# still answers love1 == love2 -- it just answers it about a shorter binary than
# anyone ships. an arch with no seat carries none, and $gate_arch_c is empty there.
if [ -n "$gate_arch_c" ]; then
  kinc="-I$ho -I. -Il -Iinle -Iout/lib -Il/quay -Iapps/moon/include"
  for f in $gate_kern_c $gate_arch_c l/quay/paint.c \
           l/quay/cga_8x8.c l/quay/moderndos_8x16.c; do
    mkobj "$f"
    moon1 $kinc -c "$f" "$o" || fail "love1 mooncc -c $f"
  done
  LOVE_NO_IMAGE=1 "$d/love1" -l "out/$ha/mkvec.l" -q -e "(lay-vec \"$d/kvec.o\" \"$ha\")" \
    || fail "love1 lay-vec"
  test -s "$d/kvec.o" || fail "love1 lay-vec laid an empty kvec.o"
fi

# love2 takes the SAME list in the SAME order, one directory over -- link order is layout,
# so two globs agreeing by luck is not one list. A name love1 linked and the loops above
# never compiled dies here, at the linker, by name.
o2=; for o in "$@"; do o2="$o2 $d/${o#$md/}"; done
moon1 -pie $o2 -o "$d/love2" || fail "love2 link"

cmp "$d/love1" "$d/love2" || fail "love2 differs from love1 -- the fixpoint broke"

echo "test_fixpoint: love0+mooncc -> love1; love1+mooncc -> love2; byte-identical -- the compiler rebuilds itself exactly"
