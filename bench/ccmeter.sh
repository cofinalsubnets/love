#!/bin/sh
# ccmeter.sh -- mooncc's codegen meter: the same C under mooncc and under gcc -O2, and what
# mooncc's passes do to love's own C. a development instrument, not a gate; a/b two compilers
# by running it once in each tree. wants `make out/love` (love0 is gcc's build of the same C)
#   ./ccmeter.sh [raster] [zstd] [census]     all three when none is named
# raster   instructions a frame inside rz_*: a run of 22 frames less one of 2, over 20. out/love
#          against out/love0 on bench/raster.l; the apartment (bench/rzapt.l) under out/love alone
# zstd     src/love/compress/zstd.c built outside love by mooncc and by cc -O2, decoding one
#          stream (src/love/*.c packed at 19 by the cc build): instructions, bytes checked
# census   src/love/*.c through mooncc: the compile's instructions, then with MOON_CENSUS the
#          forms each pass run drops and makes (copyprop#2 is the second copyprop a fn meets)
set -u
R=$(cd "$(dirname "$0")/.." && pwd)
W=$R/out/ccmeter
mkdir -p "$W"
cd "$R"
command -v perf >/dev/null || { echo "ccmeter: perf not on PATH" >&2; exit 1; }
[ $# -gt 0 ] || set -- raster zstd census
cflags="-Iout -I. -Isrc/love -Isrc/inle -Iout/lib -D tco=1"

# instructions in rz_* a frame: a 22-frame run less a 2-frame run, sampled every million
rzf() { # binary script var -> M a frame
 for n in 2 22; do
  env "$3=$n" LOVE_THREADS=1 perf record -q -e instructions:u -c 1000000 -o "$W/rz.data" "$1" "$2" > /dev/null 2>&1
  perf report -i "$W/rz.data" --stdio --sort sym -q -n 2>/dev/null | awk '$NF ~ /^rz_/ {s += $2} END {print s + 0}' > "$W/rz-$n"
 done
 echo $(( ($(cat "$W/rz-22") - $(cat "$W/rz-2")) / 20 )); }

raster() {
 m=$(rzf out/love bench/raster.l RASTER_REPS); g=$(rzf out/love0 bench/raster.l RASTER_REPS)
 echo "raster bench  mooncc ${m}M  gcc ${g}M  ratio $(awk "BEGIN {printf \"%.3f\", $m / $g}")"
 echo "raster apartment  mooncc $(rzf out/love bench/rzapt.l NF)M  (love0 has no lore to draw it)"; }

zstd() {
 printf '#include <stdio.h>\n#include <stdlib.h>\n#include <stdint.h>\n#include <stddef.h>\n' > "$W/zm.c"
 cat >> "$W/zm.c" <<'EOF'
void *alloc(void *p, size_t n) { if (!n) { free(p); return 0; } return realloc(p, n); }
#define ZS_STANDALONE
#include "src/love/compress/zstd.c"
static uint8_t s[1 << 24];
int main(int argc, char **argv) {
 uintptr_t n = fread(s, 1, sizeof s, stdin), on;
 if (argv[1][0] == 'c') {
  uintptr_t cap = ze_cap(n); uint8_t *o = malloc(cap);
  uintptr_t k = ze_frame(s, n, 19, o, cap);
  if (!k) return 2;
  fwrite(o, 1, k, stdout); return 0; }
 uint8_t *u = zs_whole(s, n, &on);
 if (!u) return 3;
 fwrite(u, 1, on, stdout); return 0; }
EOF
 out/love mooncc -I. -o "$W/zm" "$W/zm.c" || { echo "zstd: mooncc build failed"; return; }
 cc -O2 -I. -o "$W/zg" "$W/zm.c" || { echo "zstd: cc build failed"; return; }
 cat src/love/*.c > "$W/z.raw"
 "$W/zg" c < "$W/z.raw" > "$W/z.zst" || { echo "zstd: pack failed"; return; }
 for b in zm zg; do
  "$W/$b" d < "$W/z.zst" | cmp -s - "$W/z.raw" || { echo "zstd: $b decodes wrong bytes"; return; }
  perf stat -x, -e instructions:u -o "$W/$b.st" "$W/$b" d < "$W/z.zst" > /dev/null
 done
 m=$(awk -F, '/instructions/{print $1}' "$W/zm.st"); g=$(awk -F, '/instructions/{print $1}' "$W/zg.st")
 echo "zstd decode $(wc -c < "$W/z.raw" | tr -d ' ') bytes  mooncc $((m / 1000))K  gcc $((g / 1000))K  ratio $(awk "BEGIN {printf \"%.3f\", $m / $g}")"; }

census() {
 : > "$W/census.txt"; t=0
 for f in src/love/*.c; do   # the compile's cost with the census off, then its census
  perf stat -x, -e instructions:u -o "$W/cc.st" out/love mooncc -c "$f" -o "$W/x.o" $cflags 2>/dev/null || echo "census: $f failed"
  t=$((t + $(awk -F, '/instructions/{print $1}' "$W/cc.st")))
  MOON_CENSUS=1 out/love mooncc -c "$f" -o "$W/x.o" $cflags >> "$W/census.txt" 2>/dev/null
 done
 echo "census src/love/*.c  compile $((t / 1000000))M instructions"
 # a pass's runs in one fn are numbered in order: copyprop#1 is the first a fn meets
 awk '$1 == "census" {if ($2 != fn) {fn = $2; split("", o)}; k = $3 "#" (++o[$3])
                      n[k]++; d[k] += $4; m[k] += $5; if ($4 + $5 > 0) h[k]++}
      END {for (k in n) printf "  %-10s runs %6d  touched %5.1f%%  dropped %7d  made %7d\n", k, n[k], 100 * h[k] / n[k], d[k], m[k]}' \
  "$W/census.txt" | sort -k7 -rn; }

for a in "$@"; do "$a"; done
