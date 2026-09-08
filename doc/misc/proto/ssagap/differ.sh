#!/bin/sh
# differ.sh -- the rung-0 differential: apps/moon/val.l against the python
# oracle over the whole corpus, row for row (C census, D dead, H chains).
# needs a CURRENT bake (val.l rides the image). usage: sh differ.sh [outdir]
set -e
S=$1
[ -n "$S" ] || S=out/ssagap
mkdir -p "$S"
: > "$S/ir.txt"
for f in src/*.c apps/moon/lib/moonlibc/math/am.c apps/moon/lib/moonlibc/string/*.c \
         apps/moon/lib/moonlibc/stdio/*.c apps/moon/lib/moonlibc/fmt/*.c \
         apps/moon/lib/moonlibc/os.c apps/moon/lib/moonlibc/env/*.c apps/moon/lib/moonlibc/proc/*.c; do
  sed "s|@FILE@|$f|" doc/misc/proto/ssagap/valdiff.tpl.l > "$S/v1.l"
  out/love "$S/v1.l" >> "$S/ir.txt" || echo "!! $f"
done
grep -E '^\((C|D|H) ' "$S/ir.txt" > "$S/rows.love.txt"
python3 doc/misc/proto/ssagap/ssagap.py "$S/ir.txt" --rows > "$S/rows.py.txt"
diff -u "$S/rows.py.txt" "$S/rows.love.txt" && echo "DIFFERENTIAL OK: $(wc -l < "$S/rows.love.txt") rows"
