#!/bin/sh
# differ.sh -- the rung-0 differential: src/apps/moon/val.l against the python
# oracle over the whole corpus, row for row (C census, D dead, H chains).
# needs a CURRENT bake (val.l rides the image). usage: sh differ.sh [outdir]
set -e
S=$1
[ -n "$S" ] || S=out/ssagap
mkdir -p "$S"
: > "$S/ir.txt"
for f in src/*.c src/apps/moon/lib/math/am.c src/apps/moon/lib/nolibc/string/*.c \
         src/apps/moon/lib/nolibc/stdio/*.c src/apps/moon/lib/nolibc/fmt/*.c \
         src/apps/moon/lib/nolibc/os.c src/apps/moon/lib/nolibc/env/*.c src/apps/moon/lib/nolibc/proc/*.c; do
  sed "s|@FILE@|$f|" doc/misc/proto/ssagap/valdiff.tpl.l > "$S/v1.l"
  out/love "$S/v1.l" >> "$S/ir.txt" || echo "!! $f"
done
grep -E '^\((C|D|H) ' "$S/ir.txt" > "$S/rows.love.txt"
python3 doc/misc/proto/ssagap/ssagap.py "$S/ir.txt" --rows > "$S/rows.py.txt"
diff -u "$S/rows.py.txt" "$S/rows.love.txt" && echo "DIFFERENTIAL OK: $(wc -l < "$S/rows.love.txt") rows"
