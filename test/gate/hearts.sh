#!/bin/sh
# test/gate/hearts.sh -- hearts builds the arm64 defconfig kernel Image with mooncc, and it boots.
# from the pinned tarball and the tree's patches, hearts (src/apps/hearts/build.l) makes defconfig,
# syncconfig and Image in an empty output dir: every unit by mooncc (its asm by holo) through kcc.l,
# the link by love's ld, the host programs by mooncc, flex and bison as love's lex and yacc, perl's
# scripts ported, the commands through lush with kore's verbs. clang keeps what mooncc refuses, one
# unit at a time, each named in .hearts/kcc.log and listed here; lld links the arm32 compat vdso.
# the Image then boots under qemu virt to an init of ours (mooncc, love's cpio), which says so and
# powers off. a green run keeps the Image for test_hearts_boot, named in $C/Image-$V.green.
# heavy (a kernel build, hours); opt-in by name.
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

# that clang, first on PATH for the units mooncc refuses and the compat vdso: its version, and its code for a probe that tells a
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

for t in cc clang ld.lld curl qemu-system-aarch64; do
  command -v $t >/dev/null 2>&1 || gate_skip "hearts: no $t, skipped"
done
# $B is one dir for every session, so a second run waits its turn: the script runs again under
# bee's exclusive lock named by $B, which a dead holder's pid gives up (src/apps/locks.l)
[ -n "${HEARTS_HELD:-}" ] || { export HEARTS_HELD=1; exec "$love" bee --lock --out "$B" -- "$love" lush -g "$0" "$1"; }
mkdir -p "$B" "$C/src" || fail "cannot make $B"
# a red run keeps its build and boot log to read (the next run clears them); a green one leaves nothing

tgz=$C/src/linux-$V.tar.xz
[ -f "$tgz" ] || curl -sSfL -o "$tgz" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$V.tar.xz" \
  || gate_skip "hearts: cannot fetch linux-$V, skipped"
[ "$(sha256sum < "$tgz" | cut -d' ' -f1)" = "$SHA" ] || fail "$tgz is not the pinned linux-$V"
rm -rf "$K" "$O" "$B/boot"
(cd "$B" && tar xf "$tgz") || fail "cannot unpack $tgz"
# the tree's patches over the pinned source, in order (src/apps/hearts/patches)
for p in "$R"/src/apps/hearts/patches/*.patch; do
  [ -f "$p" ] || continue
  patch -d "$K" -p1 -s < "$p" || fail "cannot apply $p"
done

# the build's identity, so no clock or host name reaches the image
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

mkdir -p "$O"
(cd "$O" && HEARTS_SRC="$K" HEARTS_JOBS="$J" HEARTS_KGZIP="$love gzip" \
  "$love" "$R/src/apps/hearts/build.l") > "$B/hearts.log" 2>&1 \
  || { tail -20 "$B/hearts.log"; fail "hearts' build failed"; }
I=$O/arch/arm64/boot/Image
[ -f "$I" ] || fail "hearts made no Image"
n=0; [ -f "$O/.hearts/kcc.log" ] && n=$(wc -l < "$O/.hearts/kcc.log")
[ "$n" -eq 0 ] || { echo "hearts: $n units are clang's:"; sed 's/^/  /' "$O/.hearts/kcc.log"; }

# pid 1: say so, then power off
d=$B/boot; mkdir -p "$d"
cat > "$d/init.c" <<'EOF'
#include <unistd.h>
#include <sys/reboot.h>
int main(void) {
  static char const m[] = "hearts: init ran\n";
  write(1, m, sizeof m - 1);
  sync();
  reboot(0x4321fedc);
  for (;;) sleep(60); }
EOF
"$love" mooncc -t a64 -O2 -o "$d/init" "$d/init.c" || fail "mooncc on init.c"
(cd "$d" && echo init | "$love" cpio -o -H newc > init.cpio 2> /dev/null) || fail "cpio on init"
timeout "${HEARTS_BOOT_SECS:-600}" qemu-system-aarch64 -M virt -cpu cortex-a57 -m 1G -display none -no-reboot \
  -serial file:"$d/serial.log" -kernel "$I" -initrd "$d/init.cpio" \
  -append "console=ttyAMA0 panic=-1 rdinit=/init" > "$d/qemu.log" 2>&1
grep -a -q '^hearts: init ran' "$d/serial.log" || { tail -20 "$d/serial.log"; fail "the Image did not boot to init"; }
grep -a -q 'reboot: Power down' "$d/serial.log" || { tail -20 "$d/serial.log"; fail "init ran, but no power off"; }
e='WARNING|BUG|Oops|Kernel panic|Internal error'
w=$(grep -a -c -E "$e" "$d/serial.log")
[ "$w" -eq 0 ] || { grep -a -E "$e" "$d/serial.log" | head; fail "the boot logged $w faults"; }

# the Image a green run certifies is the one rung 0 boots (test/gate/hearts-boot.sh), kept under
# its own hash and named in Image-$V.green
sha=$(sha256sum < "$I" | cut -d' ' -f1)
s16=$(echo "$sha" | cut -c1-16)
cp "$I" "$C/Image-$V-$s16.new" && mv "$C/Image-$V-$s16.new" "$C/Image-$V-$s16" \
  && echo "$sha" > "$C/Image-$V.green.new" && mv "$C/Image-$V.green.new" "$C/Image-$V.green" \
  || fail "cannot keep the Image in $C"
rm -rf "$O" "$d"
echo "hearts: Image $s16 by mooncc ($n units clang's) from linux-$V and the tree's patches, defconfig; boots to init"
