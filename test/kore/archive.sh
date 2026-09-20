#!/bin/sh
# test/kore/archive.sh -- gzip, gunzip, zcat, tar, cpio under kore's door
. "$(dirname "$0")/common.sh"

# gz.l, tar.l and the two cpio files are kore members now, not crew ones: the distro's
# /bin IS the kore cat, so a userland that cannot open a tarball wants them here. all
# three cmd modules leak their mains off a BODYLESS letrec (the trailing `_ (pins ..)`),
# which is the whole of how the registry's cite reaches them -- drop the `_` and the
# verb falls through to kore's usage screen, silently and with a 2.
printf 'alpha\nbeta\ngamma\n' > "$ho/.arc1"
korerun gzip -c < "$ho/.arc1" > "$ho/.arc1.gz" || fail "kore gzip"
korerun gunzip < "$ho/.arc1.gz" > "$o" || fail "kore gunzip"
cmp -s "$ho/.arc1" "$o" || fail "kore gzip | gunzip round trip"
korerun zcat "$ho/.arc1.gz" > "$o" 2>/dev/null || fail "kore zcat"
cmp -s "$ho/.arc1" "$o" || fail "kore zcat"
# -v is gzip's own: the shared door answers --help and --version in their long spelling
# alone, so -v reports the ratio on err and the file it replaced, and compresses
cp "$ho/.arc1" "$ho/.arcv"
korerun gzip -v "$ho/.arcv" 2> "$ho/.arcv.say" || fail "kore gzip -v"
grep -q 'replaced with' "$ho/.arcv.say" || fail "gzip -v was answered as --version"
korerun gunzip "$ho/.arcv.gz" || fail "kore gunzip of gzip -v"
cmp -s "$ho/.arc1" "$ho/.arcv" || fail "gzip -v did not compress"
hv "gzip --version" '^gzip (love' korerun gzip --version
hv "gzip --help"    '^gzip -- the' korerun gzip --help
hv "cpio --help"    '^usage: cpio {' korerun cpio --help
hv "tar --help"     '^usage: tar '   korerun tar --help
if command -v gzip >/dev/null 2>&1; then
  gzip -c "$ho/.arc1" > "$ho/.arc1.ggz"
  korerun gunzip < "$ho/.arc1.ggz" > "$o" || fail "kore gunzip of GNU's gzip"
  cmp -s "$ho/.arc1" "$o" || fail "kore gunzip of GNU's gzip"
  gunzip -c "$ho/.arc1.gz" > "$o" 2>/dev/null || fail "GNU gunzip of kore's gzip"
  cmp -s "$ho/.arc1" "$o" || fail "GNU gunzip of kore's gzip"
fi
# tar and cpio: that the verb RESOLVES is the thing this file can go wrong about --
# each has its own gate for the format. a missing row prints kore's usage, so the
# check is that the answer is the listing and not the screen.
rm -rf "$ho/.arcd"; mkdir -p "$ho/.arcd/sub"
printf 'x\n' > "$ho/.arcd/one.txt"; printf 'y\n' > "$ho/.arcd/sub/two.txt"
# the cd'd subshells want $K, the ABSOLUTE love: korerun's $m is relative to $PWD
( cd "$ho" && "$K" kore tar czf .arc.tgz .arcd ) || fail "kore tar czf"
korerun tar tzf "$ho/.arc.tgz" > "$o" 2>&1 || fail "kore tar tzf"
grep -q 'one\.txt' "$o" || fail "kore tar: the verb fell through to the usage screen"
( cd "$ho" && "$K" kore find .arcd | "$K" kore cpio -o --quiet > .arc.cpio ) || fail "kore cpio -o"
korerun cpio -t < "$ho/.arc.cpio" > "$o" 2>/dev/null || fail "kore cpio -t"
grep -q 'one\.txt' "$o" || fail "kore cpio: the verb fell through to the usage screen"
echo "kore: gzip/gunzip/zcat/tar/cpio under kore's door ok"
