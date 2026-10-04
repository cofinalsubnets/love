#!/bin/sh
# moon-flex.sh -- flex 2.6.4 on GNU m4 1.4.21, each configured with CC=mooncc and built by
# mooncc + moonlibc + holo from a pinned tarball: no gcc anywhere, configure's probes
# included, and flex's own skeleton laid through our m4. then flex lays its own scanner and
# its example scanners, each held byte-identical to what upstream flex 2.6.4 lays from the
# same file -- the same pinned tarball built by the host's cc, on the host's m4, never the
# distro's flex (a patched one writes other #lines). a bulk compile (three autoconf trees):
# take the heavy lock. opt-in by name. the build lives in out/moonflex.
# usage: moon-flex.sh
. test/gate/skip.sh
set -u
lane=moon-flex
d=$(pwd)/out/moonflex
. src/tools/moon-conf.sh

command -v cc >/dev/null 2>&1 || gate_skip "$lane: no host cc to build the oracle flex with, skipped"
command -v m4 >/dev/null 2>&1 || gate_skip "$lane: no host m4 for the oracle flex, skipped"

conf_seat
conf_m4
conf_pkg flex-2.6.4.tar.gz e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995 \
  https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz
export M4=$m4
conf_build flex-2.6.4 --disable-nls --disable-shared   # mooncc lays no shared objects
fx=$d/flex-2.6.4/src/flex

# the oracle: the same tarball, configured and built by the host's cc
echo "$lane  flex-2.6.4  (the oracle: CC=cc)"
rm -rf "$d/oracle"; mkdir -p "$d/oracle"
(cd "$d/oracle" && tar xf "$src/flex-2.6.4.tar.gz") || fail "cannot unpack the oracle's flex"
(cd "$d/oracle/flex-2.6.4" && CC=cc ./configure --disable-nls --disable-shared > ../conf.log 2>&1 && make -j"$J" > ../make.log 2>&1) \
  || { tail -5 "$d/oracle/make.log" "$d/oracle/conf.log" 2>/dev/null; fail "the oracle flex did not build"; }
ofx=$d/oracle/flex-2.6.4/src/flex

# the scanners, laid twice from one relative layout (the names reach the output's #line
# directives): once by ours, which runs our m4, and once by the oracle on the host's. two of the manual's
# examples are fragments that no flex accepts alone (eof_rules, pas_include)
ls=$(cd "$d/flex-2.6.4" && echo src/scan.l examples/fastwc/*.l examples/manual/*.lex)
n=0
for s in $ls; do
  case $s in */eof_rules.lex|*/pas_include.lex) continue ;; esac
  for side in ours host; do mkdir -p "$d/$side/$(dirname "$s")"; cp "$d/flex-2.6.4/$s" "$d/$side/$s"; done
  (cd "$d/ours" && "$fx" -o "$s.c" "$s") || fail "our flex on $s"
  (cd "$d/host" && M4=$(command -v m4) "$ofx" -o "$s.c" "$s") || fail "the oracle flex on $s"
  cmp -s "$d/ours/$s.c" "$d/host/$s.c" || fail "$s.c differs from upstream flex's"
  n=$((n + 1))
done
echo "$lane: flex 2.6.4 + m4 1.4.21 configured and built by mooncc, $n scanners laid byte-identical to upstream flex built by the host's cc -- ok"
