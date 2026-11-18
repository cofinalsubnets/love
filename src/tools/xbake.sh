# src/tools/xbake.sh LOVE ARCH QEMU RAW CAT OUT -- bake a cross lane's raw love off the cat where
# it runs: on a host of its arch (`love bee --on ARCH-exec`, doc/bee.md HOSTS), else under qemu here
love=$1 arch=$2 qemu=$3 raw=$4 cat=$5 out=$6
d=$out.d
rm -rf "$d" && mkdir -p "$d" && cp "$raw" "$d/love" && cp "$cat" "$d/cat.l" || exit 1
if "$love" bee --on "$arch-exec" --probe 2>/dev/null; then
  "$love" bee --on "$arch-exec" --ship "$d" -- sh -c 'LOVE_NO_IMAGE=1 ./love bake -o love.baked -l cat.l >&2 && cat love.baked' > "$out.tmp"
else
  (cd "$d" && LOVE_NO_IMAGE=1 "$qemu" ./love bake -o love.baked -l cat.l) && cp "$d/love.baked" "$out.tmp"
fi
s=$?
rm -rf "$d"
[ $s -eq 0 ] && [ -s "$out.tmp" ] || { rm -f "$out.tmp"; exit 1; }
chmod 755 "$out.tmp" && mv "$out.tmp" "$out"
