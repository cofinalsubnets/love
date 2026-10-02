# a lane that cannot run here says so through these, never a bare exit 0. a box marked
# strict (~/.love/etc/gate-strict, or LOVE_GATE_STRICT=1) has all a lane needs, so a skip
# there is red. sourced: `. test/gate/skip.sh`; from make: `sh test/gate/skip.sh gate-skip MSG`
gate_strict() { [ -n "$LOVE_GATE_STRICT" ] || [ -e "$HOME/.love/etc/gate-strict" ]; }
# the whole lane: say why and leave
gate_skip() {
  if gate_strict; then echo "$1 -- REFUSED: a strict box runs every lane"; exit 1; fi
  echo "$1"; exit 0
}
# one leg of a lane: say why and carry on
gate_partly() {
  if gate_strict; then echo "$1 -- REFUSED: a strict box runs every leg"; exit 1; fi
  echo "$1"
}
if [ "$1" = gate-skip ]; then shift; gate_skip "$*"; fi
