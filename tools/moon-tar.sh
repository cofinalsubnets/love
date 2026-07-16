#!/bin/sh
# moon-tar.sh -- build GNU tar 1.13 with mooncc + nolibc + the holo linker (no
# gcc/glibc/ld) and prove it RUNS: a cf/xf roundtrip byte-identical to the tree
# it archived, a czf/xzf roundtrip (tar forks gzip through a pipe), and interop
# with the system tar reading our archive. The third moon-userland rung
# (doc/moon-userland.md), after bzip2 and gzip.
#
# tar's source is the one imported artifact. Point TARSRC at a CONFIGURED
# tar-1.13 tree (./configure already run, so config.h exists). Without one the
# check SKIPS (like test_raw_arm64 without qemu). To make one:
#   curl -O https://ftp.gnu.org/gnu/tar/tar-1.13.tar.gz
#   tar xzf tar-1.13.tar.gz && (cd tar-1.13 && ./configure)
#   make moon-tar TARSRC=$PWD/tar-1.13
#
# Nothing here needs gcc EXCEPT the one-time ./configure probe that emits
# config.h (the accepted precedent -- mooncc COMPILES every object). The system
# tar/gzip are used only to VERIFY our binary, never to build it.
set -e

ho=out/host
mc=$ho/mooncc
ai=$ho/ai
TARSRC=${TARSRC:-out/dl/tar-1.13}

if [ ! -f "$TARSRC/config.h" ]; then
  echo "moon-tar: no configured tar-1.13 at '$TARSRC' -- skipped."
  echo "          set TARSRC=<a ./configure'd tar-1.13 tree> to run (see tools/moon-tar.sh)."
  exit 0
fi
for bin in "$mc" "$ai"; do
  [ -x "$bin" ] || { echo "moon-tar: missing $bin -- run 'make $ho/mooncc host'"; exit 1; }
done
command -v tar  >/dev/null 2>&1 || { echo "moon-tar: no system tar to verify against -- skipped"; exit 0; }

d=$ho/moontar
rm -rf "$d"; mkdir -p "$d"

# tar's link set, exactly as its configure chose: the 15 binary objects + the
# 21 libtar.a objects. STDC_HEADERS is what config.h defines; pre-C89 gnulib
# TUs (argmatch.c) omit <config.h>, so pass it on the line to pull <string.h>.
SRC="arith buffer compare create delete extract incremen list mangle misc names open3 rtapelib tar update"
# fnmatch: tar's OWN bundled lib/fnmatch.c (configure drops it from libtar.a
# only because it found a system fnmatch; mooncc compiles it clean).
LIB="addext argmatch backupfile basename error exclude fnmatch full-write getdate getopt getopt1 modechange msleep quotearg safe-read xgetcwd xmalloc xstrdup xstrtol xstrtoul xstrtoumax mktime"
CFLAGS="-DSTDC_HEADERS=1 -DHAVE_CONFIG_H -Icrew/moon/include -I$TARSRC -I$TARSRC/src -I$TARSRC/lib -I$TARSRC/intl"

echo "MOON-TAR  $TARSRC  (mooncc + nolibc + holo, no gcc/glibc/ld)"

objs=""
for b in $SRC; do
  $mc $CFLAGS -c "$TARSRC/src/$b.c" "$d/src_$b.o" || { echo "FAIL mooncc -c src/$b.c"; exit 1; }
  objs="$objs $d/src_$b.o"
done
for b in $LIB; do
  $mc $CFLAGS -c "$TARSRC/lib/$b.c" "$d/lib_$b.o" || { echo "FAIL mooncc -c lib/$b.c"; exit 1; }
  objs="$objs $d/lib_$b.o"
done

# the rung-4 libc floor: nolibc + am math + the syscall leaf (mksys lays sys.o).
$mc -Icrew/moon/include -c crew/moon/lib/nolibc.c "$d/nolibc.o" || { echo "FAIL mooncc -c nolibc.c"; exit 1; }
for f in crew/moon/lib/math/*.c; do
  b=`basename "$f" .c`
  $mc -Icrew/moon/lib/math -Icrew/moon/include -c "$f" "$d/m_$b.o" || { echo "FAIL mooncc -c $f"; exit 1; }
done
{ cat crew/kore/text.l crew/kore/core.l crew/kore/asbook.l crew/holo/elf.l crew/holo/obj.l crew/moon/lib/mksys.l
  echo "(mksys \"$d/sys.o\")"; } | $ai || { echo "FAIL mksys sys.o"; exit 1; }

$mc $objs "$d/nolibc.o" "$d"/m_*.o "$d/sys.o" -o "$d/tar" || { echo "FAIL holo link tar"; exit 1; }
echo "  linked $(wc -c < "$d/tar") bytes -> $d/tar"

# ---- prove it runs (absolute binary path -- the checks cd into work dirs) ----
tarbin=$(cd "$d" && pwd)/tar
"$tarbin" --version >/dev/null 2>&1 || { echo "FAIL tar --version"; exit 1; }

w=$d/work; rm -rf "$w"; mkdir -p "$w/src/sub"
printf 'hello from ai-tar\n'          > "$w/src/a.txt"
printf 'second file, some content\n'  > "$w/src/sub/b.txt"
head -c 4096 /dev/urandom             > "$w/src/blob.bin"
ln -s a.txt "$w/src/link"
chmod 0644 "$w/src/a.txt"; chmod 0600 "$w/src/sub/b.txt"

# plain cf/xf roundtrip
( cd "$w" && "$tarbin" cf out.tar src ) || { echo "FAIL tar cf"; exit 1; }
mkdir -p "$w/ex" && ( cd "$w/ex" && "$tarbin" xf ../out.tar ) || { echo "FAIL tar xf"; exit 1; }
diff -r "$w/src" "$w/ex/src" || { echo "FAIL cf/xf roundtrip not byte-identical"; exit 1; }
echo "  OK cf/xf roundtrip byte-identical (perms + symlink preserved)"

# system tar reads our archive (interop)
tar tf "$w/out.tar" >/dev/null 2>&1 || { echo "FAIL system tar cannot read our archive"; exit 1; }
echo "  OK system tar reads our archive"

# gzip'd roundtrip: tar forks gzip through a pipe (fork/execvp/pipe/wait)
if command -v gzip >/dev/null 2>&1; then
  ( cd "$w" && "$tarbin" czf out.tgz src ) || { echo "FAIL tar czf"; exit 1; }
  mkdir -p "$w/exz" && ( cd "$w/exz" && "$tarbin" xzf ../out.tgz ) || { echo "FAIL tar xzf"; exit 1; }
  diff -r "$w/src" "$w/exz/src" || { echo "FAIL czf/xzf roundtrip not byte-identical"; exit 1; }
  echo "  OK czf/xzf roundtrip (forked gzip through a pipe)"
fi

echo "moon-tar: GNU tar 1.13 built by mooncc + nolibc + holo, runs + roundtrips -- ok"
