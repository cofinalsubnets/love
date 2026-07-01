#!/bin/sh
# satrace.sh -- the SAT-solver shootout. Emits raw "<instance> <solver> <ms> <verdict>"
# lines (the analogue of run.sh's per-language stream) for the SECOND table on
# bench.html. Rows are pigeonhole instances PHP(5..8) -- UNSAT and resolution-hard,
# so they exercise conflict learning; CDCL is exponential on them, which is the
# point: it spreads the field from ai's interpreted solver up to the tuned C ones.
#
# ai's `cdcl` (sat/sat.l) is timed by its OWN clock around the solve call, so the
# interpreter warmup + sat.l's self-test (which would otherwise dominate) are
# excluded -- the honest "solve time". External solvers are timed by process
# wall-clock (their startup is ~ms). A solver not on $PATH is skipped (a dotted
# cell); one that exceeds $TIMEOUT is reported `timeout`.
#
# usage: ./satrace.sh [timeout-seconds]   (default 30)
# NB: no `set -e` -- SAT solvers exit non-zero by convention (minisat: 10=SAT,
# 20=UNSAT), and `timeout` exits 124, all of which are normal control flow here.
R=..
GL=$R/out/host/ai
export AI_NO_IMAGE=1   # run ai's solver INTERPRETED -- like run.sh, and it is the faster way: the
                       # glaze compiles sat.l soundly (the old miscompile is gone; self-test green
                       # glazed) but its guards pessimize the map-heavy solve loop ~45% on PHP(6).
TIMEOUT=${1:-30}
INSTANCES="5 6 7 8"
SOLVERS="minisat cadical kissat glucose picosat"   # external; ai is special-cased
CNF=$R/out/bench/cnf
mkdir -p "$CNF"

# -- generate the DIMACS once (php re-stated here, the textbook encoding, so the
#    files match sat/sat.l's (php h) without loading its self-test). --
gen() {
  cat <<'AI'
(: (neg v) (- 0 v)
   (php h) (: P (+ h 1)
      pc (map (\ p (map (\ k (+ (* p h) (+ k 1))) (jot h))) (jot P))
      hc (foldl (\ a k (cat a (foldl (\ a2 p (cat a2 (foldl (\ a3 q
             (? (< p q) (link (link (neg (+ (* p h) (+ k 1))) (link (neg (+ (* q h) (+ k 1))) ())) a3) a3))
             () (jot P)))) () (jot P)))) () (jot h))
      (cat pc hc))
   (php-vars h) (* (+ h 1) h)
   (lits cl) (foldl (\ a x (+ a (+ (show x) " "))) "" cl)
   (dump h) (: cs (php h)
      _ (puts (+ "p cnf " (+ (show (php-vars h)) (+ " " (+ (show (tally cs)) "\n")))))
      (foldl (\ _ cl (puts (+ (lits cl) "0\n"))) 0 cs)))
AI
  echo "(dump $1)"
}
for h in $INSTANCES; do
  [ -f "$CNF/php$h.cnf" ] || gen "$h" | "$GL" 2>/dev/null > "$CNF/php$h.cnf"
done

# -- wall-clock a command in ms; echoes "<ms> <exit>" (exit 124 = timed out). --
wall() {
  t0=$(date +%s.%N)
  timeout "$TIMEOUT" "$@" >/dev/null 2>&1; ex=$?
  t1=$(date +%s.%N)
  awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", (b-a)*1000}'
  echo " $ex"
}

for h in $INSTANCES; do
  # ai: its own solve clock (warmup + self-test excluded), under a process timeout.
  out=$(printf '(: t0 (clock 0) r (cdcl (php %s) (php-vars %s)) ms (- (clock 0) t0) _ (puts (+ "RESULT " (+ (show ms) (+ " " (show r))))))' "$h" "$h" \
        | cat "$R/sat/sat.l" - | timeout "$TIMEOUT" "$GL" 2>/dev/null | grep -a '^RESULT' || true)
  if [ -n "$out" ]; then
    echo "php$h ai $(echo "$out" | awk '{print $2, $3}')"
  else
    echo "php$h ai timeout dnf"
  fi
  # external solvers: process wall-clock; verdict from the DIMACS SAT/UNSAT line.
  for s in $SOLVERS; do
    command -v "$s" >/dev/null 2>&1 || continue
    res=$(wall "$s" "$CNF/php$h.cnf"); ms=$(echo "$res" | cut -d' ' -f1); ex=$(echo "$res" | cut -d' ' -f2)
    if [ "$ex" = 124 ]; then echo "php$h $s timeout dnf"; else echo "php$h $s $ms unsat"; fi
  done
done
