#!/bin/sh
# test/gate/hearts.sh -- hearts builds the arm64 defconfig kernel Image byte-identical to
# kbuild's. from the pinned tarball: kbuild+clang makes defconfig and Image, then hearts
# (src/apps/hearts/build.l) makes defconfig, syncconfig and Image from an empty output dir,
# and the two Images must be the same bytes. both build at one canonical path, since the
# vdso's build-id hashes debug info that names the source and output dirs and the vdso is
# in the image; the build's identity is pinned. kbuild's half borrows the host's toolchain
# (llvm, flex, bison, perl) and a clang+lld we build (src/tools/hearts-llvm.sh: a distro's clang
# of the same version gives other code, so other images per host). hearts' half borrows only clang/lld/llvm for the kernel's
# own units: the host programs build with mooncc, certs/extract-cert is ours (xcert.l, no
# openssl), flex and bison are ours (src/tools/moon-flex.sh, moon-bison.sh), perl's scripts are ported,
# and the commands run through lush with kore's verbs. where a tool's bytes reach the Image
# (config_data.gz), kbuild's half borrows OUR tool too: KGZIP is love's gzip on both sides.
# heavy (two kernel builds, and our flex/bison once when absent); opt-in by name.
# usage: hearts.sh LOVE
. test/gate/skip.sh
set -u

love=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
R=$(pwd)
V=6.19.14
QSHA=76633100dd2a091118ae52885de3e483b910818f1acfa42852af04f77d0869fe
SHA=cde8bf6739be4a0777fedbbba5330b8188c55680c45a922a4dfa289cbec6f185
C=${HEARTS_CACHE:-$HOME/.cache/hearts}
B=/var/tmp/hearts
K=$B/linux-$V
O=$B/o
J=${HEARTS_GATE_JOBS:-8}
L=${HEARTS_CLANG:-$C/llvm-22.1.8}
fail() { echo "FAIL hearts: $*" >&2; exit 1; }

# that clang, first on PATH for both halves: its version, and its code for a probe that tells a
# distro's build of the same version apart
[ -x "$L/bin/clang" ] || fail "no clang at $L -- build it with src/tools/hearts-llvm.sh"
PATH=$L/bin:$PATH; export PATH
[ "$(clang --version | head -1)" = "clang version 22.1.8" ] || fail "$L/bin/clang is not clang 22.1.8"
case $(ld.lld --version) in "LLD 22.1.8 "*) ;; *) fail "$L/bin/ld.lld is not lld 22.1.8" ;; esac
[ "$(clang -print-target-triple)" = aarch64-unknown-linux-gnu ] || fail "$L/bin/clang does not default to arm64"
q=$(mktemp -d) || fail "no temp dir"
cat > "$q/q.c" <<'EOF'
typedef unsigned char u8;
typedef unsigned int u32;
struct desc { void *p; u32 len; u8 flags; };
extern struct desc tabs[];
extern void unmap(void *p, u32 n);
extern int cmp(const void *a, const void *b, unsigned long n);
extern int acquire(struct desc *d, void **t, u32 *n, u8 *f);
void release(void *t, u32 n, u8 f)
{
	switch (f & 7) {
	case 1: unmap(t, n); break;
	default: break;
	}
}
static u8 same(struct desc *d, u32 i)
{
	void *t; u32 n; u8 f, r;
	if (acquire(&tabs[i], &t, &n, &f))
		return 0;
	r = (u8)((d->len != n || cmp(d->p, t, n)) ? 0 : 1);
	release(t, n, f);
	return r;
}
int probe(struct desc *d, u32 i) { return same(d, i) + same(d, i + 1); }
EOF
(cd "$q" && clang --target=aarch64-linux-gnu -O2 -g -fno-var-tracking -funsigned-char \
  -fno-omit-frame-pointer -fdebug-prefix-map="$q"=. -c -o q.o q.c) || fail "clang cannot compile the probe"
qs=$(sha256sum < "$q/q.o" | cut -d' ' -f1); rm -rf "$q"
[ "$qs" = "$QSHA" ] || fail "$L/bin/clang is not the pinned build: the probe compiles to $qs"

for t in make cc c++ clang ld.lld llvm-ar llvm-objcopy flex bison perl curl; do
  command -v $t >/dev/null 2>&1 || gate_skip "hearts: no $t, skipped"
done
mkdir -p "$B" "$C/src" || fail "cannot make $B"
mkdir "$B/.lock" 2>/dev/null || fail "$B is in use ($B/.lock)"
# a red run keeps both builds to read (the next run clears them); a green one leaves nothing
trap 'rm -rf "$B/.lock"' EXIT

tgz=$C/src/linux-$V.tar.xz
[ -f "$tgz" ] || curl -sSfL -o "$tgz" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$V.tar.xz" \
  || gate_skip "hearts: cannot fetch linux-$V, skipped"
[ "$(sha256sum < "$tgz" | cut -d' ' -f1)" = "$SHA" ] || fail "$tgz is not the pinned linux-$V"
rm -rf "$K" "$O" "$B/ref"
(cd "$B" && tar xf "$tgz") || fail "cannot unpack $tgz"
# the tree's patches over the pinned source, in order, for both halves (src/apps/hearts/patches)
for p in "$R"/src/apps/hearts/patches/*.patch; do
  [ -f "$p" ] || continue
  patch -d "$K" -p1 -s < "$p" || fail "cannot apply $p"
done

# each half compiles for itself: a compile cache would hand hearts kbuild's objects
export CCACHE_DISABLE=1
export KBUILD_BUILD_USER=hearts KBUILD_BUILD_HOST=hearts KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP='Thu Jan  1 00:00:00 UTC 2026'

# our extract-cert against the kernel's own, built here on openssl: each case byte for byte,
# the same exit, and nothing written where it refuses
x=$B/xcert; rm -rf "$x"; mkdir -p "$x"
cc -O2 -I"$K/scripts" -o "$x/ref" "$K/certs/extract-cert.c" -lcrypto 2> "$x/cc.log" || { tail -3 "$x/cc.log"; fail "the openssl extract-cert did not build"; }
awk '/BEGIN CERT/{n++} n==1' "$R/src/apps/tls/roots.pem" | sed '/END CERT/q' > "$x/one.pem"
printf -- '-----BEGIN PRIVATE KEY-----\nMC4CAQAwBQYDK2VwBCIEIDj9\n-----END PRIVATE KEY-----\n' > "$x/key.pem"
cat "$x/one.pem" "$x/key.pem" > "$x/trail.pem"; cat "$x/key.pem" "$x/one.pem" > "$x/lead.pem"
sed 's/BEGIN CERTIFICATE/BEGIN X509 CERTIFICATE/; s/END CERTIFICATE/END X509 CERTIFICATE/' "$x/one.pem" > "$x/old.pem"
for f in "$R/src/apps/tls/roots.pem" "$x/one.pem" "$x/trail.pem" "$x/lead.pem" "$x/old.pem" "$x/key.pem" ""; do
  rm -f "$x/r" "$x/o"
  "$x/ref" "$f" "$x/r" > /dev/null 2>&1; a=$?
  "$love" "$R/src/apps/hearts/xcert.l" "$f" "$x/o" > /dev/null 2>&1; b=$?
  [ $a -eq $b ] || fail "extract-cert '$f': openssl's exits $a, ours $b"
  if [ -f "$x/r" ] || [ -f "$x/o" ]; then cmp -s "$x/r" "$x/o" || fail "extract-cert '$f' differs from openssl's"; fi
done

# our flex and bison, each on our m4, built by their lanes when absent
fx=$R/out/moonflex/flex-2.6.4/src/flex
by=$R/out/moonbison/bison-3.8.2/src/bison
[ -x "$fx" ] || sh src/tools/moon-flex.sh > "$B/moon-flex.log" 2>&1 || { tail -5 "$B/moon-flex.log"; fail "our flex did not build"; }
[ -x "$by" ] || sh src/tools/moon-bison.sh > "$B/moon-bison.log" 2>&1 || { tail -5 "$B/moon-bison.log"; fail "our bison did not build"; }
mkdir -p "$B/tools"
printf '#!/bin/sh\nM4=%s BISON_PKGDATADIR=%s exec %s "$@"\n' \
  "$R/out/moonbison/m4-1.4.21/src/m4" "$R/out/moonbison/bison-3.8.2/data" "$by" > "$B/tools/bison"
chmod +x "$B/tools/bison"
gz="$love gzip"
# and neither half sees the host's rust or pahole, nor its libc: their versions, and whether the
# compiler can link a user program (CC_CAN_LINK), reach .config, so the image. an empty sysroot
# makes that probe fail on every host; defconfig builds no user program for it to touch
mkdir -p "$B/no-sysroot"
mk="LLVM=1 ARCH=arm64 RUSTC=false HOSTRUSTC=false BINDGEN=false PAHOLE=false USERCFLAGS=--sysroot=$B/no-sysroot"

mkdir -p "$O"
# kbuild's host programs build with the host's cc: our clang targets arm only, and their bytes
# never reach the image
# shellcheck disable=SC2086
(cd "$K" && make O="$O" $mk HOSTCC=cc HOSTCXX=c++ KGZIP="$gz" defconfig \
  && make O="$O" $mk HOSTCC=cc HOSTCXX=c++ KGZIP="$gz" -j"$J" Image) \
  > "$B/ref.log" 2>&1 || { tail -20 "$B/ref.log"; fail "kbuild's own build failed"; }
mv "$O" "$B/ref" || fail "cannot set kbuild's build aside"

mkdir -p "$O"
(cd "$O" && HEARTS_SRC="$K" HEARTS_JOBS="$J" LOVE_BUDGET_MB=${LOVE_BUDGET_MB:-1500} \
  HEARTS_LEX="$fx" HEARTS_YACC="$B/tools/bison" HEARTS_KGZIP="$gz" \
  "$love" "$R/src/apps/hearts/build.l") > "$B/hearts.log" 2>&1 \
  || { tail -20 "$B/hearts.log"; fail "hearts' build failed"; }

for f in .config kernel/config_data.gz arch/arm64/boot/Image; do
  [ -f "$O/$f" ] || fail "hearts made no $f"
  cmp -s "$B/ref/$f" "$O/$f" || fail "$f differs from kbuild's"
done
sha=$(sha256sum < "$O/arch/arm64/boot/Image" | cut -c1-16)
# the Image a green run certifies is the one rung 0 boots (test/gate/hearts-boot.sh)
cp "$O/arch/arm64/boot/Image" "$C/Image-$V.new" && mv "$C/Image-$V.new" "$C/Image-$V" || fail "cannot keep the Image in $C"
rm -rf "$O" "$B/ref"
echo "hearts: Image $sha = kbuild+clang's, from linux-$V and the tree's patches, defconfig, host programs by mooncc"
