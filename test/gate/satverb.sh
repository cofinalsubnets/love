#!/bin/sh
# test/gate/satverb.sh -- `love sat`, the carried unit raised off /love: a sat cnf answers its
# model and 10, an unsat one 20 and a refutation, a bad word 2. takes the love binary.
set -u
love=${1:-out/love}
case $love in /*) ;; *) love=$PWD/$love ;; esac   # the checks run in a scratch dir
w=$(mktemp -d) || exit 1
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL satverb: $*"; exit 1; }

printf 'c three clauses\np cnf 3 3\n1 2 0\n-1 3 0\n-2 -3 0\n' > "$w/s.cnf"
printf 'p cnf 2 4\n1 2 0\n1 -2 0\n-1 2 0\n-1 -2 0\n' > "$w/u.cnf"
cd "$w" || exit 1
"$love" sat s.cnf > s.out 2>&1; rc=$?
[ $rc = 10 ] || fail "sat answered $rc: $(head -5 s.out)"
[ "$(cat s.out)" = "s SATISFIABLE
v -1 2 -3 0" ] || fail "the model: $(cat s.out)"
"$love" sat -p u.drat < u.cnf > u.out 2>&1; rc=$?
[ $rc = 20 ] || fail "unsat answered $rc: $(head -5 u.out)"
[ "$(cat u.out)" = "s UNSATISFIABLE" ] || fail "the unsat line: $(cat u.out)"
[ "$(tail -1 u.drat)" = 0 ] || fail "the refutation ends without the empty clause: $(cat u.drat)"
"$love" sat -x s.cnf > x.out 2>&1; rc=$?
[ $rc = 2 ] || fail "a bad option answered $rc"
echo "satverb: love sat raised off /love, sat and unsat answered"
