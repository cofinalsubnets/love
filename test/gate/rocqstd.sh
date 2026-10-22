#!/bin/sh
# test/gate/rocqstd.sh COQC DIR SRC.. -- the slice of rocq's Stdlib the proofs import, built
# from the .v the stdlib ships into DIR/Stdlib by this coqc, so each .vo carries its stamp.
# the imports are read off SRC (the proofs and the tools that write proofs); the slice is
# their closure, compiled in dependency order. never writes beside the shipped stdlib.
# a slice whose coqc and module list match is kept as it is
set -u
coqc=$1 d=$2
shift 2
dep=$(dirname "$coqc")/coqdep
[ -x "$dep" ] || dep=coqdep
std=$("$coqc" -where)/user-contrib/Stdlib
[ -d "$std" ] || { echo "rocqstd: no stdlib at $std" >&2; exit 1; }
ver=$("$coqc" --version 2>&1)
t=$d.tmp
rm -rf "$t"
mkdir -p "$t/Stdlib" || exit 1
(cd "$std" && find . -name '*.v') | while read -r f; do
  mkdir -p "$t/Stdlib/${f%/*}" && cp "$std/$f" "$t/Stdlib/$f" || exit 1
done || exit 1
# a root per imported name the stdlib holds; a local module (spec) is no root
for m in $(sed -n 's/.*Require Import \([^.]*\)\..*/\1/p' "$@" | tr ' ' '\n' | sort -u); do
  [ -n "$(find "$t/Stdlib" -name "$m.v")" ] && echo "From Stdlib Require Import $m."
done > "$t/roots.v"
(cd "$t" && "$dep" -R Stdlib Stdlib roots.v $(find Stdlib -name '*.v')) 2> "$t/dep.err" > "$t/deps" \
  || { cat "$t/dep.err" >&2; exit 1; }
# the closure of roots.vo, each .vo after what it needs
awk '{ i = index($0, ": "); split(substr($0, 1, i - 1), a, " "); n = split(substr($0, i + 2), b, " ")
       s = ""; for (k = 2; k <= n; k++) if (b[k] ~ /\.vo$/) s = s " " b[k]; need[a[1]] = s }
     function visit(v,  k, n, x) { if (v in seen) return; seen[v] = 1
       n = split(need[v], x, " "); for (k = 1; k <= n; k++) visit(x[k]); if (v != "roots.vo") print v }
     END { visit("roots.vo") }' "$t/deps" > "$t/order"
[ -s "$t/order" ] || { echo "rocqstd: no stdlib module imported" >&2; exit 1; }
if [ -f "$d/order" ] && [ "$ver" = "$(cat "$d/version" 2>/dev/null)" ] && cmp -s "$t/order" "$d/order"; then
  rm -rf "$t"
  touch "$d/.built"
  exit 0
fi
echo "ROCQ	$d/Stdlib ($(wc -l < "$t/order" | tr -d ' ') modules)"
for v in $(cat "$t/order"); do
  (cd "$t" && "$coqc" -q -w -deprecated -R Stdlib Stdlib "${v%o}") > "$t/build.log" 2>&1 \
    || { cat "$t/build.log" >&2; echo "rocqstd: ${v%o} failed" >&2; exit 1; }
done
echo "$ver" > "$t/version"
rm -rf "$d"
mv "$t" "$d" && touch "$d/.built"
