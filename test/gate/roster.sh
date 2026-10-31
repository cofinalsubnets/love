#!/bin/sh
# test/gate/roster.sh -- a bake by roster: units left out of the image stay verbs, raised off
# /love at their first call, and a carried unit bakes in; a configured binary reseeds to its
# own bytes and bakes them back. takes the love binary.
set -u
love=${1:-out/love}
[ -x "$love" ] || { echo "roster: no $love"; exit 1; }
case $love in /*) ;; *) love=$PWD/$love ;; esac
w=$(mktemp -d) || exit 1
trap 'rm -rf "$w"' EXIT
fail() { echo "FAIL roster: $*"; exit 1; }

"$love" bake --list > "$w/units" 2>&1 || fail "love bake --list: $(cat "$w/units")"
grep -q '^torrent  *baked torrent torrent-show$' "$w/units" || fail "torrent is not listed baked: $(cat "$w/units")"
grep -q '^harp .*(needs .*lore' "$w/units" || fail "harp's needs miss lore"
grep -q '^helm  *carry $' "$w/units" || fail "helm is not listed carried"
# a carried unit answers its name off /love
(cd "$w" && "$love" helm --help) > "$w/h0" 2>&1
grep -q '^usage: helm' "$w/h0" || fail "helm did not raise: $(head -5 "$w/h0")"
# lux bakes its wire and carries the rest
grep -q '^lux  *part ' "$w/units" || fail "lux is not listed part: $(grep '^lux ' "$w/units")"
(cd "$w" && "$love" lux --help) > "$w/x0" 2>&1
grep -q '^usage: love lux' "$w/x0" || fail "lux did not raise: $(head -5 "$w/x0")"
# the picker's model: a flip writes the bake's flags, off takes along what needs the unit,
# on what it needs (harp and lore need each other), and enter leaves to bake
cat > "$w/pick.l" <<'EOF'
(borrow 'roster)
(: pk (pick-new ())
   (at u) (pin pk 'cur (<(filter (k \ (pk 'us k) = u) ^#(pk 'us))))
   (fl u) (: _ (at u) _ (pick-step pk 32) (join " " (pick-args (pick-flags pk))))
   a (fl "torrent") b (fl "helm") _ (fl "lore") h0 (pk 'on "harp") _ (fl "lore") h1 (pk 'on "harp")
   f (pick-frame pk 120 40)
   _ (pick-step pk 13)
   (each [a b (show [h0 h1 (1 < #(split "love bake --with helm" f)) (pk 'go)])]
         (s \ say out (s + "\n"))))
EOF
"$love" "$w/pick.l" > "$w/pick" 2>&1
[ "$(cat "$w/pick")" = "--without torrent
--with helm --without torrent
(0 1 1 1)" ] || fail "the picker: $(cat "$w/pick")"
# a plain bake's own flags stay the C bake's
"$love" bake --nosuch > "$w/u0" 2>&1 && fail "bake took an unknown flag"
grep -q -- '--list' "$w/u0" || fail "bake's usage: $(cat "$w/u0")"

# a kept unit's needs stay
"$love" bake --without lore -o "$w/no" > "$w/refuse" 2>&1 && fail "a bake left out lore under harp"
grep -q 'harp needs lore' "$w/refuse" || fail "the refusal: $(cat "$w/refuse")"
"$love" bake --without nosuch -o "$w/no" > "$w/refuse" 2>&1 && fail "a bake took an unknown unit"
[ -e "$w/no" ] && fail "a refused bake wrote its binary"

"$love" bake --with helm,lux --without torrent,hexedit,bee -o "$w/l1" > "$w/b1" 2>&1 || fail "the bake: $(tail -5 "$w/b1")"
"$w/l1" bake --list > "$w/u1" 2>&1 || fail "love bake --list on the configured binary"
grep -q '^helm  *baked helm$' "$w/u1" || fail "helm is not baked in: $(cat "$w/u1")"
[ "$("$w/l1" -e "#(cite 'helm)")" != 0 ] || fail "helm's module is not baked"
grep -q '^lux  *baked lux ' "$w/u1" || fail "lux is not baked in: $(grep '^lux ' "$w/u1")"
[ "$("$w/l1" -e "#(cite 'lux)")" != 0 ] || fail "lux's module is not baked"
grep -q '^torrent  *left  torrent torrent-show$' "$w/u1" || fail "torrent is not left out: $(cat "$w/u1")"
grep -q '^hexedit  *left ' "$w/u1" || fail "hexedit is not left out"
"$w/l1" verbs | grep -qw torrent-show || fail "the left-out verbs are not listed"
[ "$("$w/l1" -e "#(cite 'benc)")" = 0 ] || fail "torrent's modules were baked"
"$w/l1" torrent-show > "$w/r1" 2>&1
grep -q '^usage: love torrent-show' "$w/r1" || fail "torrent-show did not raise: $(cat "$w/r1")"
"$w/l1" hexedit < /dev/null > "$w/r2" 2>&1
grep -q '^usage: hexedit' "$w/r2" || fail "hexedit did not raise: $(head -5 "$w/r2")"
# raising bee keeps the verbs of the kept units it needs (mitty)
[ "$("$w/l1" -e "(: V (cite 'verbs) _ ((V 'get 'bee) [\"--help\"]) [(lit? (V 'tab 'mitty)) (lit? (V 'tab 'bee))])" 2>/dev/null | tail -1)" = "(1 1)" ] \
  || fail "raising bee lost a kept unit's verb"

# the roster rides the image, so a configured binary reseeds to its own bytes
"$w/l1" seed -g "$w/s" > "$w/seed" 2>&1 || fail "the seed: $(tail -20 "$w/seed")"
grep -q 'baking the roster: --with helm,lux --without hexedit,torrent,bee' "$w/seed" || fail "the seed baked no roster: $(tail -5 "$w/seed")"
grep -q '^;; fixpoint ok' "$w/seed" || fail "no fixpoint: $(tail -5 "$w/seed")"
rm -rf "$w/s"

# back in, from the configured binary's own roster
"$w/l1" bake --with torrent -o "$w/l2" > "$w/b2" 2>&1 || fail "the bake back: $(tail -5 "$w/b2")"
"$w/l2" bake --list > "$w/u2" 2>&1
grep -q '^torrent  *baked ' "$w/u2" || fail "torrent did not come back: $(cat "$w/u2")"
grep -q '^hexedit  *left ' "$w/u2" || fail "hexedit came back unasked"
grep -q '^helm  *baked ' "$w/u2" || fail "helm left unasked"
[ "$("$w/l2" -e "#(cite 'benc)")" != 0 ] || fail "torrent's modules are not baked"
echo "roster: a unit left out, raised, and baked back; a carried one baked in; a configured binary reseeded"
