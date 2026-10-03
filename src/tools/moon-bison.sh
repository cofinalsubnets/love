#!/bin/sh
# moon-bison.sh -- GNU bison 3.8.2 on GNU m4 1.4.21, each configured with CC=mooncc and built
# by mooncc + moonlibc + holo from a pinned tarball: no gcc anywhere, configure's probes
# included. then bison, running on that m4, lays bison's own grammar and its eight example
# grammars -- parser and header, `-t -l` as kbuild asks -- and each is held byte-identical to
# what the host's bison 3.8.2 lays from the same file. a bulk compile (two autoconf trees):
# take the heavy lock. opt-in by name. the build lives in out/moonbison.
# usage: moon-bison.sh
. test/gate/skip.sh
set -u
lane=moon-bison
d=$(pwd)/out/moonbison
. src/tools/moon-conf.sh

command -v bison >/dev/null 2>&1 || gate_skip "$lane: no host bison to hold it to, skipped"
bison --version | head -1 | grep -q ' 3\.8\.2$' || gate_skip "$lane: the host bison is not 3.8.2, skipped"

conf_seat
conf_m4
conf_pkg bison-3.8.2.tar.xz 9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2 \
  https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz
conf_build bison-3.8.2 --disable-nls
by=$d/bison-3.8.2/src/bison

# the grammars, laid twice from one relative layout (the names reach the output's #line
# directives and header guard): once by ours, on our m4, and once by the host's
gs="src/parse-gram.y $(cd "$d/bison-3.8.2" && echo examples/c/*/*.y)"
for side in ours host; do
  for g in $gs; do
    mkdir -p "$d/$side/$(dirname "$g")"; cp "$d/bison-3.8.2/$g" "$d/$side/$g"
  done
done
n=0
for g in $gs; do
  b=${g%.y}
  (cd "$d/ours" && M4=$m4 BISON_PKGDATADIR=$d/bison-3.8.2/data "$by" -o "$b.tab.c" --defines="$b.tab.h" -t -l "$g") \
    || fail "our bison on $g"
  (cd "$d/host" && bison -o "$b.tab.c" --defines="$b.tab.h" -t -l "$g") || fail "the host's bison on $g"
  for x in c h; do cmp -s "$d/ours/$b.tab.$x" "$d/host/$b.tab.$x" || fail "$b.tab.$x differs from the host's"; done
  n=$((n + 1))
done
echo "$lane: bison 3.8.2 + m4 1.4.21 configured and built by mooncc, $n grammars laid byte-identical to the host's bison -- ok"
