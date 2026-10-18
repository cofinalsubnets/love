#!/bin/sh
# test/gate/refuzz.sh -- kore's grep and sed against GNU's over seeded random patterns and
# subjects, stdout and exit. the oracle is an absolute path checked to be GNU (a dev box's
# grep may be ugrep), else the lane skips. grep and sed differ on ERE's `)` and `{`, so the
# atom sets are per tool. the draw is a pure function of the seed; REFUZZ_ROUNDS for more.
# usage: refuzz.sh LOVE
set -u

m=$1

seed=${REFUZZ_SEED:-20260815}
rounds=${REFUZZ_ROUNDS:-150}

GREP=/usr/bin/grep
SED=/usr/bin/sed
[ -x "$GREP" ] || GREP=$(command -v grep 2>/dev/null || true)
[ -x "$SED" ]  || SED=$(command -v sed  2>/dev/null || true)
if [ ! -x "${GREP:-}" ] || [ ! -x "${SED:-}" ]; then
  echo "refuzz: no grep/sed on this box -- SKIPPED (no oracle to ask)"; exit 0
fi
case $("$GREP" --version 2>&1 | head -1) in *GNU*) ;;
  *) echo "refuzz: $GREP is not GNU grep -- SKIPPED (wrong oracle)"; exit 0 ;; esac
case $("$SED" --version 2>&1 | head -1) in *GNU*) ;;
  *) echo "refuzz: $SED is not GNU sed -- SKIPPED (wrong oracle)"; exit 0 ;; esac

w=${TMPDIR:-/tmp}/refuzz.$$
mkdir -p "$w" || exit 1
trap 'rm -rf "$w"' EXIT INT TERM
korerun() { LOVE_NO_IMAGE= "$m" kore "$@"; }

# the draw is made once in awk (a shell rng in $(..) never advances).
# fields: BRE \t ERE(grep) \t ERE(sed) \t six subject lines joined by |
awk -v seed="$seed" -v n="$rounds" '
BEGIN {
  srand(seed)
  # the separator `;` may not appear in an atom
  nb = split("a;b;c;.;a*;.*;[ab];[^a];[a-c];b\\+;c\\?;\\(ab\\)*;\\(a\\|b\\);a\\|b;" \
             "b\\{2\\};a\\{1,2\\};[[:alpha:]];[[:digit:]];^;$;\\{2\\};\\+;*", B, ";")
  # grep-ERE adds ) and { as ink. no apostrophes in this block: it is single-quoted shell
  ng = split("a;b;c;.;a*;.*;[ab];[^a];[a-c];b+;c?;(ab)*;(a|b);a|b;b{2};a{1,2};" \
             "[[:alpha:]];[[:digit:]];^;$;);{", G, ";")
  # at most one loose repeat, first: * or +. GNU is inconsistent on a leading {2}
  nl = split("+;*", L, ";")
  # sed-ERE drops ) { and the bare repeats, which GNU sed refuses
  ns = split("a;b;c;.;a*;.*;[ab];[^a];[a-c];b+;c?;(ab)*;(a|b);a|b;b{2};a{1,2};" \
             "[[:alpha:]];[[:digit:]];^;$", S, ";")
  nc = split("a b c 1 _ . * ", C, " "); C[nc] = " "
  for (r = 0; r < n; r++) {
    printf "%s\t%s\t%s\t", pat(B, nb), mkere(), pat(S, ns)
    for (i = 0; i < 6; i++) printf "%s%s", (i ? "|" : ""), subj()
    printf "\n"
  }
}
function mkere(   o) { o = pat(G, ng)
  return (rand() < 0.2) ? L[1 + int(rand() * nl)] o : o }   # one loose repeat, up front
function pat(A, k,   j, m, o) { m = 1 + int(rand() * 4); o = ""
  for (j = 0; j < m; j++) o = o A[1 + int(rand() * k)]; return o }
function subj(   j, m, o) { m = int(rand() * 7); o = ""
  for (j = 0; j < m; j++) o = o C[1 + int(rand() * nc)]; return o }
' > "$w/draws"

bad=0
r=0
cmp1() { # LABEL TOOL argv..  -- oracle then ours; stdout AND exit must agree
  nm=$1; shift; tool=$1; shift
  case $tool in grep) or=$GREP ;; sed) or=$SED ;; esac
  "$or" "$@" "$w/in" > "$w/g" 2>/dev/null; a=$?
  korerun "$tool" "$@" "$w/in" > "$w/o" 2>/dev/null; b=$?
  if ! cmp -s "$w/g" "$w/o" || [ "$a" -ne "$b" ]; then
    bad=$((bad + 1))
    echo "REFUZZ DIFF ($nm) seed=$seed round=$r: $tool $* (gnu $a ours $b)" >&2
    echo "-- subject:" >&2; cat -A "$w/in" >&2
    diff "$w/g" "$w/o" >&2 | head -6
  fi
}

while IFS='	' read -r bp gp sp subj; do
  r=$((r + 1))
  printf '%s\n' "$subj" | tr '|' '\n' > "$w/in"
  cmp1 bre grep -c  "$bp";  cmp1 bre grep     "$bp";  cmp1 bre grep -n "$bp"
  cmp1 bre grep -v  "$bp";  cmp1 bre grep -o  "$bp";  cmp1 bre grep -w "$bp"
  cmp1 bre grep -x  "$bp";  cmp1 bre grep -i  "$bp"
  cmp1 ere grep -Ec "$gp";  cmp1 ere grep -E  "$gp";  cmp1 ere grep -oE "$gp"
  cmp1 ere grep -nE "$gp";  cmp1 ere grep -vE "$gp"
  cmp1 sub sed "s/$bp/</";  cmp1 sub sed "s/$bp/</g";  cmp1 sub sed "s/$bp/[&]/g"
  cmp1 adr sed -n "/$bp/p"; cmp1 sub sed -E "s/$sp/</g"; cmp1 adr sed -nE "/$sp/p"
done < "$w/draws"

if [ "$bad" -gt 0 ]; then
  echo "refuzz: $bad divergence(s) over $r rounds (seed $seed) -- FAILED" >&2
  exit 1
fi
echo "refuzz: grep + sed vs GNU over $r seeded rounds (seed $seed), byte-identical ok"
