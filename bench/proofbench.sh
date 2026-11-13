#!/bin/sh
# proofbench.sh -- uu's kernel beside rocqchk and leanchecker, checking the same terms.
# a development instrument, not a gate: it prints readings, not a verdict.
#
#   terms  uu2coq and uu2lean export the corpus; proofbench.l cuts each workload's
#          declarations out of both exports and writes the same set as uu kernel calls
#   ms     the median wall time to check a workload's artifact, less the base row's (the
#          preamble alone), so process start and library loading drop out. uu reads its
#          calls as text, rocqchk a .vo, leanchecker an .olean; compiling them is not timed.
#          rocqchk -norec admits the stdlib, leanchecker replays the module over its imports
#   mb     each checker's peak resident set on the workload, start included
#   ok     every side present accepted; a side with no artifact shows `-`
#
#   base    the preamble, no declarations
#   corpus  every declaration all three take
#   tower   uu-app-tower: a unary-nat power tower computed in conversion
#   ring    the ledger's proofs by ring reflection: rex-norm runs on both sides of a conv
#   ledger  the bignum ledger, test/uumagvc.l, and what it cites
#   ua      what univalence's axiom sits under
#
# usage: ./proofbench.sh [samples]   (default 5)
# env:
#   LOVE=path     the love under test (default ../out/love)
#   ROCQSTD=dir   the stdlib built by this coqc (default ../out/rocq, laid by make test_uugen)
#   TIMEOUT=n     per-run cutoff, seconds (default 900)
#   RAW=path      also write "<workload> <side> <ms> <kb>" lines
set -u

R=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SAMPLES=${1:-5}
TO=${TIMEOUT:-900}
RAW=${RAW:-}
m=${LOVE:-$R/out/love}
std=${ROCQSTD:-$R/out/rocq}
W=$R/out/bench/proof
WLS="base corpus tower ring ledger ua"

export LC_ALL=C

[ -x "$m" ] || { echo "proofbench: no $m -- run \`make host\` first" >&2; exit 1; }
[ -d "$std/Stdlib" ] || { echo "proofbench: no $std/Stdlib -- run \`make test_uugen\` first" >&2; exit 1; }
for t in coqc rocqchk lean leanchecker; do
  command -v $t > /dev/null 2>&1 || { echo "proofbench: no $t on PATH" >&2; exit 1; }
done

rm -rf "$W"; mkdir -p "$W"
[ -n "$RAW" ] && : > "$RAW"
cd "$R"

echo "exporting the corpus" >&2
"$m" src/tools/uu2coq.l > "$W/all.v" || { echo "proofbench: uu2coq failed" >&2; exit 1; }
"$m" src/tools/uu2lean.l > "$W/all.lean" || { echo "proofbench: uu2lean failed" >&2; exit 1; }
"$m" bench/proofbench.l dump "$W" >&2 || { echo "proofbench: dump failed" >&2; exit 1; }

# the compile is the elaborator's, not the kernel's: done once, untimed
llib=$(lean --print-libdir)
for w in $WLS; do
  if [ -f "$W/$w.v" ]; then
    echo "  coqc $w" >&2
    (cd "$W" && coqc -q -R "$std/Stdlib" Stdlib -R . Pb "$w.v" > "$w.coqc" 2>&1) || rm -f "$W/$w.v"
  fi
  if [ -f "$W/$w.lean" ]; then
    echo "  lean $w" >&2
    (cd "$W" && LEAN_PATH="$llib:$W" lean -o "$w.olean" "$w.lean" > "$w.leanc" 2>&1) || rm -f "$W/$w.lean"
  fi
done

side() {   # side SIDE WORKLOAD: the command line that checks it
  case $1 in
    uu)   echo "$m bench/proofbench.l run $W/$2.uu" ;;
    rocq) echo "rocqchk -silent -R $std/Stdlib Stdlib -R $W Pb -norec Pb.$2" ;;
    lean) echo "leanchecker $2" ;;
  esac
}
have() {   # have SIDE WORKLOAD
  case $1 in
    uu)   [ -f "$W/$2.uu" ] ;;
    rocq) [ -f "$W/$2.vo" ] && [ -f "$W/$2.v" ] ;;
    lean) [ -f "$W/$2.olean" ] && [ -f "$W/$2.lean" ] ;;
  esac
}
once() {   # once SIDE WORKLOAD: "ms kb", or to/no
  s=$(date +%s%N)
  LEAN_PATH="$llib:$W" timeout "$TO" /usr/bin/time -f %M -o "$W/rss" $(side "$1" "$2") > "$W/out" 2>&1; rc=$?
  e=$(date +%s%N)
  [ "$rc" = 124 ] && { echo to; return; }
  [ "$rc" != 0 ] && { echo no; return; }
  echo "$(( (e - s) / 1000000 )) $(tail -1 "$W/rss")"
}
cell() {   # cell SIDE WORKLOAD: the median "ms kb" of SAMPLES, or to/no
  i=0
  while [ $i -lt "$SAMPLES" ]; do
    v=$(once "$1" "$2")
    echo "$v"
    case $v in to|no) break ;; esac
    i=$((i + 1))
  done | awk '/^(to|no)$/ { bad = $1 }
              !/^(to|no)$/ { t[++n] = $1 + 0; k[n] = $2 + 0 }
              END { if (bad) { print bad; exit }
                    for (i = 1; i < n; i++) for (j = i + 1; j <= n; j++)
                      if (t[j] < t[i]) { x = t[i]; t[i] = t[j]; t[j] = x; x = k[i]; k[i] = k[j]; k[j] = x }
                    print t[int((n + 1) / 2)], k[int((n + 1) / 2)] }'
}

: > "$W/cells"
for w in $WLS; do
  for s in uu rocq lean; do
    if have $s $w; then
      echo "  $s $w" >&2
      v=$(cell $s $w)
    else
      v=-
    fi
    echo "$w $s $v" >> "$W/cells"
    [ -n "$RAW" ] && echo "$w $s $v" >> "$RAW"
  done
done

n_of() { [ -f "$W/$1.uu" ] && wc -l < "$W/$1.uu" | tr -d ' ' || echo 0; }

echo
printf '%-8s %6s  %9s %9s %9s  %7s %7s %7s  %s\n' workload decls "uu ms" "rocq ms" "lean ms" "uu mb" "rocq mb" "lean mb" ok
for w in $WLS; do
  awk -v w="$w" -v n="$(n_of $w)" '
    $1 == "base" && NF == 4 { b[$2] = $3 }
    $1 == w { v[$2] = $3; k[$2] = $4; st[$2] = NF == 4 ? "ms" : $3 }
    END {
      ok = "yes"; line = sprintf("%-8s %6d ", w, n)
      split("uu rocq lean", S, " ")
      for (i = 1; i <= 3; i++) { s = S[i]
        if (st[s] == "ms") line = line sprintf(" %9d", w == "base" ? v[s] : v[s] - b[s])
        else { line = line sprintf(" %9s", st[s]); if (st[s] != "-") ok = "no" } }
      line = line " "
      for (i = 1; i <= 3; i++) { s = S[i]
        line = line (st[s] == "ms" ? sprintf(" %7d", k[s] / 1024) : sprintf(" %7s", "-")) }
      print line "  " ok }' "$W/cells"
done
