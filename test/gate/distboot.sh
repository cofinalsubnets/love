#!/bin/sh
# test/gate/distboot.sh -- the source the artifact carries, built with `make`, gives the same
# binary by either road. LEAN bootstraps it through the machine's C compiler; SEED builds it
# with its own toolchain and touches no ambient compiler. the two are compared to each other.
#
# this holds because the local cc builds only love0, and every object in the product is
# mooncc's -- test_fixpoint's property, stated across the artifacts.
# the seed lane shadows cc/gcc/clang with scripts that fail, so a build that succeeds
# was done by the bundled love. the seed lays its carried source (src/tools/mksrc.l,
# src/love/src.c) and `love seed` builds it, then rebuilds itself from it byte for byte.
# the seed is the tree's own out/love, and each laid tree re-cuts its container from itself
# (selfpack); the claim compare runs before the circle leg, whose `make dist` bakes the
# compared binary in place.
#
# minutes, not seconds; opt-in by name.
# usage: distboot.sh SEED_EXE
. test/gate/skip.sh
set -u

seed=$1

[ -x "$seed" ] || { echo "distboot: no $seed -- run 'make dist'"; exit 1; }
command -v make >/dev/null 2>&1 || gate_skip "distboot: no make, skipped"

R=$(pwd)
case $seed in /*) ;; *) seed=$R/$seed ;; esac
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL distboot: $*" >&2; exit 1; }

echo "distboot: two bootstraps and a self-rebuild, this takes a few minutes"

# ---- 1. LEAN, through the machine's own compiler -----------------------------
# LOVE_NO_IMAGE= (empty = UNSET) leads, as on every run of the artifact below
mkdir -p "$w/lean"
( cd "$w/lean" && LOVE_NO_IMAGE= "$seed" source ) > "$w/leanlay.log" 2>&1 \
  || { tail -20 "$w/leanlay.log"; fail "the seed could not lay its source"; }
lean=$(echo "$w"/lean/love-*/)
[ -d "$lean" ] || fail "'love source' laid no love-<ver>/ directory"
[ -f "$lean/VERSION" ] || fail "the carried source has no VERSION (the binary would stamp 'unknown')"
[ ! -e "$lean/.git" ] || fail "the carried source shipped a .git"
( cd "$lean" && make -j"$(nproc 2>/dev/null || echo 4)" out/love ) > "$w/lean.log" 2>&1 \
  || { tail -20 "$w/lean.log"; fail "the source artifact does not build"; }
[ -x "$lean/out/love" ] || fail "the source build produced no love"
echo "  OK lean: builds through the ambient cc"

# ---- 2. SEED, which needs no compiler ----------------------------------------
mkdir -p "$w/nocc"
for c in cc gcc clang c99 tcc; do
  printf '#!/bin/sh\necho "distboot: the ambient %s was called -- the bundled love should have been the compiler" >&2\nexit 1\n' "$c" > "$w/nocc/$c"
  chmod +x "$w/nocc/$c"
done
# run it from a COPY in the scratch dir. `love source` lays its tree beside the
# binary's cwd, and the tree we are testing must not land in the repo.
mkdir -p "$w/self"
cp "$seed" "$w/self/love" || fail "cannot copy $seed"
# LOVE_NO_IMAGE= (empty = UNSET) leads. The root Makefile EXPORTS it for the corpus,
# and an egg-booted love has no verb table at all -- `source` then reads as a FILENAME
# and the artifact answers "cannot open source", which looks like a missing verb
# rather than a missing image. The build lanes lead with the same thing for `mooncc`.
( cd "$w/self" && LOVE_NO_IMAGE= ./love source ) > "$w/self.log" 2>&1 \
  || { tail -20 "$w/self.log"; fail "the seed could not lay its source"; }
selfd=$(echo "$w"/self/love-*/)
[ -d "$selfd" ] || fail "'love source' unpacked no love-<ver>/ directory"
[ -f "$selfd/VERSION" ] || fail "the embedded source carries no VERSION"
# NO BINARY IS LAID BESIDE THE SOURCE, and a tree that carried one would be the weaker
# claim anyway -- the toolchain chosen by a file existing rather than by anyone deciding.
[ ! -e "$selfd/bin" ] || fail "'love source' laid a bin/ -- the tree is source, nothing else"
# THE BARE LINK, not `love seed`: the verb runs `make dist`, which BAKES, and leg 3
# compares this against leg 1's unbaked out/love. So the target is named here and CC
# with it -- which is the seed verb's own fallback spelled by hand (src/apps/source.l names
# `<selfpath> mooncc` where its probe finds no cc that works), and the same claim: this
# tree builds with no ambient compiler anywhere.
( cd "$selfd" && PATH="$w/nocc:$PATH" LOVE_NO_IMAGE= \
    make -j"$(nproc 2>/dev/null || echo 4)" CC="$w/self/love mooncc" out/love ) \
  > "$w/selfb.log" 2>&1 \
  || { tail -20 "$w/selfb.log"; fail "the seed-laid tree does not build without an ambient compiler"; }
grep -q "was called" "$w/selfb.log" && { grep "was called" "$w/selfb.log" | head -3; fail "the seed-laid build reached for an ambient compiler"; }
echo "  OK seed: one binary lays its own source and builds it, no ambient cc"

# ---- 3. THE CLAIM ------------------------------------------------------------
# Both binaries here are the bare LINKS (the explicit out/love target, no
# .baked asked) -- and each embeds its container, so this one cmp also proves the
# two trees' selfpack re-cut the same bytes.
if cmp -s "$lean/out/love" "$selfd/out/love"; then
  echo "  OK both artifacts answer the SAME binary ($(wc -c < "$lean/out/love") bytes)"
else
  ls -l "$lean/out/love" "$selfd/out/love"
  fail "lean and seed built DIFFERENT binaries -- the release claim is false"
fi

# ---- 4. THE CIRCLE CLOSES: the artifact rebuilds ITSELF, to the byte ---------
# The chain whole: cut the container, bootstrap it, build the artifact, extract the source
# back OUT of the artifact, and rebuild -- and the second artifact is the first one's
# bytes. That is a stronger claim than "it builds": it says the artifact carries
# everything it was made from and nothing about the machine it was made on leaked in.
# AND THE DECISION RIDES HERE TOO. This leg is a real `love seed`, not an open-coded
# `make dist` -- the verb's own -wait half IS this leg (build dist in the laid tree, then
# compare selfpath against out/love), so running it whole costs a lay more and buys
# the one thing legs 2 and 3 cannot say: that the seed PICKS its own mooncc when no
# ambient compiler works. Legs 2 and 3 name CC by hand and so supply the answer.
# PATH IS THE POISON DIR ALONE, not $w/nocc:$PATH. src-cc walks every PATH entry for
# each of cc/gcc/clang, so a prepended poison leaves the machine's real /usr/bin/cc
# reachable and the probe rightly takes it -- the fallback would never fire. The farm
# (src/apps/source.l) supplies make/sh/sed and the rest out of the binary itself.
# it seeds a FRESH tree rather than rebuilding $selfd, which leg 3 compared: nothing
# here disturbs that artifact, and this leg no longer has to run after it.
#
# IT NEEDS A REPRODUCIBLE BAKE, and that is the only reason this leg can exist. An
# image used to carry the baker's ASLR base (raw kept absolutes, the header's address
# pair, a dead JIT husk's W^X pointer) and `born`, the hatch duration -- so two bakes of
# one tree differed by 180012 bytes and no artifact could ever equal another.
# and a re-cut (selfpack, the one cutter) of the laid tree answers the bytes the binary
# carried -- the cmp below is what holds that to the byte. Same tree in, same binary out.
mkdir -p "$w/circle"
( cd "$w/self" && env PATH="$w/nocc" LOVE_NO_IMAGE= ./love seed "$w/circle" ) \
  > "$w/selfd.log" 2>&1 \
  || { tail -20 "$w/selfd.log"; fail "the seed-laid tree cannot rebuild the artifact"; }
grep -q "was called" "$w/selfd.log" && { grep "was called" "$w/selfd.log" | head -3; fail "the artifact rebuild reached for an ambient compiler"; }
grep -q "the compiler is this binary" "$w/selfd.log" \
  || { grep -a '^;; seeding' "$w/selfd.log"; fail "no ambient cc works here, and the seed did not fall back to its own mooncc"; }
grep -q "fixpoint ok" "$w/selfd.log" || fail "the seed did not answer its own fixpoint"
circled=$(echo "$w"/circle/love-*/)
again=$circled/out/love
[ -f "$again" ] || fail "the artifact rebuild produced no $again"
if cmp -s "$seed" "$again"; then
  echo "  OK circle: no cc here works, so the seed took its own mooncc -- and rebuilt ITSELF byte-for-byte ($(sha256sum < "$again" | cut -c1-16)..)"
else
  ls -l "$seed" "$again"
  fail "the rebuilt artifact differs from the one that laid its source ($(cmp -l "$seed" "$again" 2>/dev/null | wc -l) bytes)"
fi

echo "distboot: two artifacts, one love -- and the seed rebuilds itself to the byte -- ok"
