#!/bin/sh
# a cross seed's egg on its own machine: the first run bakes it in place and goes on
# (src/love/main.c, self_bake), the second wakes the image the first one laid.
# $1 the egg, run twice with -v
egg=$1; log=$egg.run1; log2=$egg.run2
"$egg" -v > "$log" 2>&1 || { cat "$log"; echo "FAIL seedegg: the first run"; exit 1; }
grep -q "a fresh egg: baking" "$log" || { cat "$log"; echo "FAIL seedegg: the first run did not bake"; exit 1; }
"$egg" -v > "$log2" 2>&1 || { cat "$log2"; echo "FAIL seedegg: the second run"; exit 1; }
if grep -q "baking" "$log2"; then cat "$log2"; echo "FAIL seedegg: the second run baked again"; exit 1; fi
cat "$log2"
