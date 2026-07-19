#!/bin/sh
# apps/sat/dratcheck.sh -- the external eye on flat.l's DRAT emission: solve pigeonhole
# instances with fdrat0 pinned to a jug, dump each ORIGINAL formula (DIMACS) and its
# refutation, and have drat-trim -- Heule's independent checker, fetched + built into
# out/drat on first use -- verify every proof (`s VERIFIED`). the BVA lines are RAT
# additions on fresh variables, the learnts RUP, the last line the empty clause; the
# php5raw row pins fbva0 off to check the pure-RUP lane too. the in-gate twin of this
# check (fd-check, no external dependency) runs inside `make test_sat`.
# usage: ./dratcheck.sh   (from apps/sat/; `make test_drat` from the root)
# exits 1 on any non-verified proof; exits 0 with a note when drat-trim is absent
# and cannot be fetched (offline). NB no `set -e`: drat-trim's exit codes are
# conventional, the verdict is the `s VERIFIED` line.
R=..
GL=$R/out/host/love
export LOVE_NO_IMAGE=1   # the native kernels ride the `nif` seam the glazed image mops
OUT=$R/out/drat
mkdir -p "$OUT"
DT=$OUT/drat-trim
if [ ! -x "$DT" ]; then
  curl -fsL --connect-timeout 10 \
    https://raw.githubusercontent.com/marijnheule/drat-trim/master/drat-trim.c \
    -o "$OUT/drat-trim.c" 2>/dev/null && cc -O2 -o "$DT" "$OUT/drat-trim.c"
  [ -x "$DT" ] || { echo "dratcheck: no drat-trim and cannot fetch -- skipped"; exit 0; }
fi

# the driver: dump the instance as DIMACS, then the proof after a `c ==proof` line.
# the formula and the proof come from the SAME in-process value, so the pair drat-trim
# sees is exactly what the solver saw. @H@/@PIN@ substituted per row.
DRV='(: f (php @H@) nv (php-vars @H@)@PIN@
 _ (say out (+ "p cnf " (+ (show nv) (+ " " (+ (show (tally f)) "\n")))))
 _ (foldl (\ _ c (: _ (foldl (\ _ l (: _ (say out (show l)) (say out " "))) 0 c) _ (say out "0\n") 0)) 0 f)
 j (jug 0) _ (pin fdrat0 () j) r (fcdcl f nv)
 _ (say out "c ==proof\n") _ (say out (slurp j))
 (? (id? r (\ unsat)) 0 (say err "dratcheck: not unsat?!\n")))'

fail=0
check() { # $1 = row name, $2 = h, $3 = the extra pin form (or empty)
  printf '%s\n' "$DRV" | sed "s/@H@/$2/g; s/@PIN@/$3/" \
    | { cat "$R/apps/sat/sat.l" "$R/apps/sat/flat.l" -; } | "$GL" 2>/dev/null > "$OUT/$1.tmp"
  awk -v c="$OUT/$1.cnf" -v p="$OUT/$1.drat" \
    '/^c ==proof/ { m=1; next } m { print > p; next } { print > c }' "$OUT/$1.tmp"
  rm -f "$OUT/$1.tmp"
  # no ^ anchor: drat-trim's \r progress writes share the physical line when piped
  if "$DT" "$OUT/$1.cnf" "$OUT/$1.drat" 2>/dev/null | grep -q 's VERIFIED'; then
    echo "$1 VERIFIED"
  else echo "$1 NOT VERIFIED"; fail=1; fi
}
for h in 5 6 7 8; do check "php$h" "$h" ""; done
check php5raw 5 " _ (pin fbva0 () 0)"
exit $fail
