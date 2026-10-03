# moon-conf.sh -- sourced by the lanes that build an autoconf package with CC=mooncc
# (moon-bison.sh, moon-flex.sh). the caller sets lane (its name, for messages) and d (its
# build dir under out/), and has sourced test/gate/skip.sh.
#   conf_seat              lay $d/seat and set cc to its mooncc
#   conf_pkg TARBALL SHA URL   unpack a pinned tarball (from $MOONSRC, ~/src when unset) into $d
#   conf_build TREE ARGS.. configure with CC=$cc, then make
R=$(pwd)
love=$R/out/love
src=${MOONSRC:-$HOME/src}
J=${MOON_PKG_JOBS:-3}
fail() { echo "FAIL $lane: $*" >&2; exit 1; }
[ -x "$love" ] || fail "missing $love -- run 'make host'"

# mooncc finds its headers and runtime at <its binary>/../lib/love/moon, so a configure run
# from inside a package tree reaches this checkout's. a hard link keeps the binary's
# identity, and with it the runtime it carries
conf_seat() {
  rm -rf "$d"; mkdir -p "$d/seat/bin" "$d/seat/lib/love"
  ln "$love" "$d/seat/bin/love" 2>/dev/null || cp "$love" "$d/seat/bin/love"
  ln -s "$R/src/apps/moon" "$d/seat/lib/love/moon"
  printf '#!/bin/sh\nexec %s mooncc "$@"\n' "$d/seat/bin/love" > "$d/seat/bin/mooncc"
  chmod +x "$d/seat/bin/mooncc"
  cc=$d/seat/bin/mooncc
}

conf_pkg() {
  t=$src/$1
  [ -f "$t" ] || { mkdir -p "$src" && curl -sSfL -o "$t" "$3"; } || gate_skip "$lane: cannot fetch $1, skipped"
  [ "$(sha256sum < "$t" | cut -d' ' -f1)" = "$2" ] || fail "$t is not the pinned $1"
  (cd "$d" && tar xf "$t") || fail "cannot unpack $t"
}

conf_build() {
  n=$1; shift
  echo "$lane  $n  (CC=mooncc: configure, make)"
  (cd "$d/$n" && CC=$cc ./configure "$@" > ../$n.conf.log 2>&1) || { tail -5 "$d/$n.conf.log"; fail "$n: configure"; }
  (cd "$d/$n" && make -j"$J" > ../$n.make.log 2>&1) || { grep 'cc: ' "$d/$n.make.log" | head -5; fail "$n: make"; }
}

# GNU m4 1.4.21, which bison and flex both run as their macro processor
conf_m4() {
  conf_pkg m4-1.4.21.tar.xz f25c6ab51548a73a75558742fb031e0625d6485fe5f9155949d6486a2408ab66 \
    https://ftp.gnu.org/gnu/m4/m4-1.4.21.tar.xz
  conf_build m4-1.4.21 --disable-nls
  m4=$d/m4-1.4.21/src/m4
  t=$(printf "define(\`x', \`ok')x eval(6*7)\n" | "$m4")
  [ "$t" = "ok 42" ] || fail "m4 define/eval: '$t'"
  # m4's own suite: the manual's examples, stdout, stderr and status each
  (cd "$d/m4-1.4.21/checks" && make check > ../../m4-checks.log 2>&1) \
    && grep -q 'All checks successful' "$d/m4-checks.log" \
    || { grep -A2 'Failed checks' "$d/m4-checks.log"; fail "m4's own check suite"; }
}
