#!/bin/sh
# test/gate/distboot.sh -- the source the artifact carries builds the same binary by either
# road: lean through the machine's cc, seed with its own toolchain (cc/gcc/clang shadowed by
# failing scripts). then `love seed` rebuilds the artifact itself, byte for byte. minutes.
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

# 1. lean, through the machine's cc. LOVE_NO_IMAGE= (empty: unset) leads every run
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

# 2. seed, no ambient compiler
mkdir -p "$w/nocc"
for c in cc gcc clang c99 tcc; do
  printf '#!/bin/sh\necho "distboot: the ambient %s was called -- the bundled love should have been the compiler" >&2\nexit 1\n' "$c" > "$w/nocc/$c"
  chmod +x "$w/nocc/$c"
done
# a copy in the scratch dir: `love source` lays its tree in the cwd
mkdir -p "$w/self"
cp "$seed" "$w/self/love" || fail "cannot copy $seed"
# the Makefile exports LOVE_NO_IMAGE, and an egg-booted love has no verbs
( cd "$w/self" && LOVE_NO_IMAGE= ./love source ) > "$w/self.log" 2>&1 \
  || { tail -20 "$w/self.log"; fail "the seed could not lay its source"; }
selfd=$(echo "$w"/self/love-*/)
[ -d "$selfd" ] || fail "'love source' unpacked no love-<ver>/ directory"
[ -f "$selfd/VERSION" ] || fail "the embedded source carries no VERSION"
# the laid tree is source only
[ ! -e "$selfd/bin" ] || fail "'love source' laid a bin/ -- the tree is source, nothing else"
# the bare link, not `love seed` (whose `make dist` bakes): leg 3 compares it to leg 1's
( cd "$selfd" && PATH="$w/nocc:$PATH" LOVE_NO_IMAGE= \
    make -j"$(nproc 2>/dev/null || echo 4)" CC="$w/self/love mooncc" out/love ) \
  > "$w/selfb.log" 2>&1 \
  || { tail -20 "$w/selfb.log"; fail "the seed-laid tree does not build without an ambient compiler"; }
grep -q "was called" "$w/selfb.log" && { grep "was called" "$w/selfb.log" | head -3; fail "the seed-laid build reached for an ambient compiler"; }
echo "  OK seed: one binary lays its own source and builds it, no ambient cc"

# 3. both bare links are one binary; each embeds its container, so the re-cuts agree too
if cmp -s "$lean/out/love" "$selfd/out/love"; then
  echo "  OK both artifacts answer the SAME binary ($(wc -c < "$lean/out/love") bytes)"
else
  ls -l "$lean/out/love" "$selfd/out/love"
  fail "lean and seed built DIFFERENT binaries -- the release claim is false"
fi

# 4. a real `love seed` into a fresh tree rebuilds the artifact to the byte, and must pick
# its own mooncc: PATH is the poison dir alone, so no real cc is reachable (the binary
# supplies make, sh and the rest). this leans on a reproducible bake
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
