#!/bin/sh
# test/kore/toolchain.sh -- as, ar, ld, objcopy, nm, size, strip, ranlib -- the object tools,
# x86-64 only
. "$(dirname "$0")/common.sh"

if [ "$(uname -m)" = x86_64 ]; then
  printf '(li r0 60) (li r6 7) (sys)\n' > "$ho/.kore-as.l"
  korerun as x64 "$ho/.kore-as.l" "$ho/.kore-as.elf" > /dev/null 2>&1 || fail "kore as"
  chmod +x "$ho/.kore-as.elf"; "$ho/.kore-as.elf"; r=$?
  [ $r -eq 7 ] || fail "kore as run (exit $r)"
fi
# ar + ld, over mooncc objects (x64; both ride the mooncc verb of $m).
# ar: GNU-shape TO THE BYTE -- same members through binutils ar (D = deterministic,
# our only mode) and ours, whole archives cmp'd; `ar t` lists alike. ld: lay the
# same crt0 object mooncc's own link lane synthesizes (crt0/objelf leak from the
# mooncc cat), then our applet must bind crt0+main+f BYTE-IDENTICAL to mooncc's
# whole-program link, and the exe must run: 35 + 7 = exit 42.
if [ "$(uname -m)" = x86_64 ]; then
  printf 'int f(void){return 35;}\n' > "$ho/.kore-arf.c"
  printf 'int f(void);\nint main(void){return f()+7;}\n' > "$ho/.kore-arm.c"
  moonc -c "$ho/.kore-arf.c" "$ho/.kore-arf.o" >/dev/null 2>&1 || fail "kore ar: mooncc -c f.c"
  moonc -c "$ho/.kore-arm.c" "$ho/.kore-arm.o" >/dev/null 2>&1 || fail "kore ar: mooncc -c main.c"
  if command -v ar >/dev/null 2>&1; then
    rm -f "$ho/.kore-gnu.a" "$ho/.kore-our.a"
    ar rcsD "$ho/.kore-gnu.a" "$ho/.kore-arf.o" "$ho/.kore-arm.o"
    korerun ar rcs "$ho/.kore-our.a" "$ho/.kore-arf.o" "$ho/.kore-arm.o" || fail "kore ar rcs"
    cmp -s "$ho/.kore-gnu.a" "$ho/.kore-our.a" || fail "kore ar vs GNU (archive bytes)"
    ar t "$ho/.kore-gnu.a" > "$g"; korerun ar t "$ho/.kore-our.a" > "$o"; same "ar t"
  fi
  "$m" -l "$ho/.mooncc-cat.l" -e '(: _ (borrow (name "holo")) _ (borrow (name "moon")) (write-bytes "'"$ho"'/.kore-crt0.o" (objelf (intern "x64") crt0 () (quote ("__ai_start")) () (quote ("__ai_start")) () () () () ())))' >/dev/null 2>&1
  [ -s "$ho/.kore-crt0.o" ] || fail "kore ld: crt0 lay"
  moonc "$ho/.kore-arm.o" "$ho/.kore-arf.o" -o "$ho/.kore-mc.elf" >/dev/null 2>&1 || fail "kore ld: mooncc link"
  korerun ld "$ho/.kore-crt0.o" "$ho/.kore-arm.o" "$ho/.kore-arf.o" -o "$ho/.kore-ld.elf" || fail "kore ld"
  # BYTE-IDENTICAL, and it is `.comment` that lets it be: both doors drive the SAME linker,
  # so the file they write is the same file, producer record included. It briefly was not --
  # mooncc stamped "mooncc" and kore ld stamped "holo", which shifted every header after it and
  # cost this check ten lines of objcopy to look past. The distinction carried nothing: one
  # linker, and the only caller of the holo door was this test.
  cmp -s "$ho/.kore-mc.elf" "$ho/.kore-ld.elf" || fail "kore ld vs mooncc link (bytes)"
  "$ho/.kore-ld.elf"; r=$?
  [ $r -eq 42 ] || fail "kore ld run (exit $r)"
  # and the archive as a LINK INPUT: `mooncc main.o libf.a` must bind the exe the
  # .o link binds, byte for byte -- which is the proof that members come in BY NEED
  # through the ranlib index, since the library also carries one nothing calls. our
  # ar writes it, our linker reads it (src/love/holo/link.l's ld-arsyms).
  printf 'int unused(void){return 99;}\n' > "$ho/.kore-arz.c"
  moonc -c "$ho/.kore-arz.c" "$ho/.kore-arz.o" >/dev/null 2>&1 || fail "kore ar: mooncc -c unused.c"
  rm -f "$ho/.kore-arl.a"
  korerun ar rcs "$ho/.kore-arl.a" "$ho/.kore-arf.o" "$ho/.kore-arz.o" || fail "kore ar rcs (library)"
  moonc "$ho/.kore-arm.o" "$ho/.kore-arl.a" -o "$ho/.kore-ara.elf" >/dev/null 2>&1 || fail "kore ld: archive input"
  cmp -s "$ho/.kore-mc.elf" "$ho/.kore-ara.elf" || fail "kore ld archive vs .o link (bytes -- an unneeded member rode in?)"
  "$ho/.kore-ara.elf"; r=$?
  [ $r -eq 42 ] || fail "kore ld archive run (exit $r)"
  # objcopy over the exe we just linked. byte-equality with the real objcopy is
  # test_objcopy's job; what this row is for is the DISPATCH -- that the applet is
  # reachable off the registry and takes the arguments it advertises.
  korerun objcopy -O binary "$ho/.kore-ld.elf" "$ho/.kore-oc.bin" || fail "kore objcopy -O binary"
  korerun objcopy -O ihex "$ho/.kore-ld.elf" "$ho/.kore-oc.hex" || fail "kore objcopy -O ihex"
  [ -s "$ho/.kore-oc.bin" ] && [ -s "$ho/.kore-oc.hex" ] || fail "kore objcopy wrote nothing"
  grep -q '^:00000001' "$ho/.kore-oc.hex" || fail "kore objcopy: no ihex end record"
  korerun objcopy -O srec "$ho/.kore-ld.elf" "$ho/.kore-oc.x" 2>/dev/null \
    && fail "kore objcopy took an unknown format"
  # nm over holo's own ELF reader. the differential is against LC_ALL=C nm: the
  # BYTE order is ours, and a desk with a locale set gets a collated one from GNU,
  # so an uncollated `nm` here would fail on the machine and not in the tree.
  # the executable is in the roster on purpose -- ld-read is ET_REL by contract
  # and ld-syms is the door that is not, so a regression that hands nm to ld-read
  # shows up here rather than the day someone reads a linked file.
  if command -v nm >/dev/null 2>&1; then
    for f in .kore-arm.o .kore-arf.o .kore-ld.elf; do
      LC_ALL=C nm "$ho/$f" > "$g" 2>/dev/null
      korerun nm "$ho/$f" > "$o" || fail "kore nm $f"
      same "nm $f"
    done
  fi
  korerun nm -u "$ho/.kore-arm.o" > "$o" || fail "kore nm -u"
  [ "$(cat "$o")" = "                 U f" ] || fail "kore nm -u (want the one undefined nom)"
  korerun nm -g "$ho/.kore-arf.o" > "$o" || fail "kore nm -g"
  grep -q ' T f$' "$o" || fail "kore nm -g (want T f)"
  korerun nm "$ho/.kore-arf.o" "$ho/.kore-arm.o" > "$o" || fail "kore nm (two files)"
  grep -q '\.kore-arm\.o:$' "$o" || fail "kore nm: no per-file header past one file"
  korerun nm "$ho/.kore-arf.c" >/dev/null 2>&1 && fail "kore nm read a non-ELF"
  # size: binutils' berkeley sums to the byte, over objects, an exe and an archive, and
  # its status (3 a file that is no object). strip: the exe still runs, loses its symbol
  # table, and keeps the sections binutils' strip keeps. ranlib: an archive laid with no
  # index (binutils' ar S) gains one, which is what mooncc's link reads it by
  if command -v size >/dev/null 2>&1; then
    size "$ho/.kore-arm.o" "$ho/.kore-ld.elf" "$ho/.kore-our.a" > "$g" 2>&1
    korerun size "$ho/.kore-arm.o" "$ho/.kore-ld.elf" "$ho/.kore-our.a" > "$o" 2>&1; same "size"
    size -t "$ho/.kore-arm.o" "$ho/.kore-arf.o" > "$g"; korerun size -t "$ho/.kore-arm.o" "$ho/.kore-arf.o" > "$o"; same "size -t"
  fi
  korerun size "$ho/.kore-arf.c" 2>/dev/null; r=$?; [ $r -eq 3 ] || fail "kore size of a non-object is 3 (got $r)"
  cp "$ho/.kore-ld.elf" "$ho/.kore-st.elf"
  korerun strip "$ho/.kore-st.elf" || fail "kore strip"
  "$ho/.kore-st.elf"; r=$?; [ $r -eq 42 ] || fail "kore strip: the stripped exe runs (exit $r)"
  korerun nm "$ho/.kore-st.elf" 2>&1 | grep -q 'no symbols' || fail "kore strip: no symbol table left"
  if command -v strip >/dev/null 2>&1 && command -v readelf >/dev/null 2>&1; then
    cp "$ho/.kore-ld.elf" "$ho/.kore-gst.elf"; strip "$ho/.kore-gst.elf"
    readelf -SW "$ho/.kore-gst.elf" | sed -n 's/^ *\[ *[0-9]*\] *\([^ ]*\).*/\1/p' | LC_ALL=C sort > "$g"
    readelf -SW "$ho/.kore-st.elf" | sed -n 's/^ *\[ *[0-9]*\] *\([^ ]*\).*/\1/p' | LC_ALL=C sort > "$o"; same "strip (the sections kept)"
  fi
  if command -v ar >/dev/null 2>&1; then
    rm -f "$ho/.kore-rl.a"; ar rcS "$ho/.kore-rl.a" "$ho/.kore-arf.o"
    korerun ranlib "$ho/.kore-rl.a" || fail "kore ranlib"
    moonc "$ho/.kore-arm.o" "$ho/.kore-rl.a" -o "$ho/.kore-rl.elf" >/dev/null 2>&1 || fail "kore ranlib: mooncc links through the index"
    "$ho/.kore-rl.elf"; r=$?; [ $r -eq 42 ] || fail "kore ranlib: the linked exe (exit $r)"
  fi
fi
# readelf: binutils' own headers, sections, segments and symbols, at 80 columns and
# wide, over objects and executables of every target mooncc lays, and the one this runs
if command -v readelf >/dev/null 2>&1; then
  printf 'int x = 3;\nstatic int y;\nint f(void) { return x + y; }\nint main(void) { return f(); }\n' > "$ho/.kore-re.c"
  fs="$m"
  for t in x64 a64 rv64 thumb2; do
    moonc -t $t -c "$ho/.kore-re.c" -o "$ho/.kore-re-$t.o" >/dev/null 2>&1 && fs="$fs $ho/.kore-re-$t.o"
    [ $t = thumb2 ] || { moonc -t $t "$ho/.kore-re.c" -o "$ho/.kore-re-$t.elf" >/dev/null 2>&1 && fs="$fs $ho/.kore-re-$t.elf"; }
  done
  for f in $fs; do
    for op in -h -S "-S -W" -l "-l -W" -s "-s -W" -e; do
      # shellcheck disable=SC2086
      LC_ALL=C readelf $op "$f" > "$g" 2>&1; korerun readelf $op "$f" > "$o" 2>&1; same "readelf $op $f"
    done
  done
  LC_ALL=C readelf -h "$ho/.kore-re-x64.o" "$ho/.kore-re-a64.o" > "$g" 2>&1
  korerun readelf -h "$ho/.kore-re-x64.o" "$ho/.kore-re-a64.o" > "$o" 2>&1; same "readelf over two files"
fi
# a compile with no nest and no tree takes moon's toolchain off the source the binary carries:
# the slice leads that archive (src/tools/selfpack.l), so the read stops past it. from a scratch
# dir outside the tree, a stdio hello compiles, links and runs; and the slice is what leads
if [ "$(uname -m)" = x86_64 ]; then
  N=$ho/.kore-nonest; rm -rf "$N"; mkdir -p "$N"
  printf '#include <stdio.h>\nint main(void){printf("carried\\n");return 0;}\n' > "$N/h.c"
  ( cd "$N" && "$K" cc h.c -o h ) > "$o" 2>&1 || { cat "$o"; fail "love cc off the carried source"; }
  [ "$("$N/h")" = carried ] || fail "love cc off the carried source: the program"
  src=$(ls "$ho"/dist/love-*.tar.gz 2>/dev/null | head -1)
  if [ -n "$src" ]; then
    gzip -dc "$src" | tar tf - 2>/dev/null | sed -n 4p | grep -q '/apps/moon/include' \
      || fail "the carried archive does not lead with moon's slice"
  fi
fi
echo "kore: diff (GNU-identical) + argv0 symlink + usage + as + ar + ld + objcopy + nm + size + strip + ranlib + readelf ok"
