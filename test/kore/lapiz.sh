#!/bin/sh
# test/kore/lapiz.sh -- markdown and html2text -- the lapiz doors, cited not borrowed
. "$(dirname "$0")/common.sh"

# These reach lapiz through `cite` with no `borrow` ahead of it, and that lane is the whole
# reason this section exists: a lapiz name bound as a VALUE, reading a sibling defined after
# it, resolves under a spliced module and does NOT resolve under a cited one. The hole is
# invisible until a document uses the block that carries it -- a blockquote, which is why
# one is in every input below. The laws cannot see this; they run with lapiz borrowed.
md=$ho/.kore-md
printf '# T\n\npara *em*.\n\n> quoted\n\n- one\n- two\n' > "$md"
korerun markdown "$md" > "$o" 2>&1 || fail "kore markdown"
grep -q '<h1>T</h1>' "$o" || { cat "$o"; fail "kore markdown: no head"; }
grep -q '<blockquote>' "$o" || { cat "$o"; fail "kore markdown: the quote did not read"; }
grep -q '<li>one</li>' "$o" || { cat "$o"; fail "kore markdown: no bullets"; }
korerun markdown -t roff "$md" > "$o" 2>&1 || fail "kore markdown -t roff"
grep -q '^\.SH T' "$o" || { cat "$o"; fail "kore markdown -t roff: no .SH"; }
korerun markdown -t text -w 40 "$md" > "$o" 2>&1 || fail "kore markdown -t text"
grep -q 'quoted' "$o" || { cat "$o"; fail "kore markdown -t text: the quote did not read"; }
awk 'length > 40 { exit 1 }' "$o" || fail "kore markdown -t text -w 40: a line overran"
# -t cells: the same words as -t text, each paragraph broken by caja, so a long one breaks
# elsewhere -- and still no line past the width
printf '\nthe inventory below names tools, never their flag coverage, and the two are not the same reach. a tool listed here answers to its name; which options it answers to is stated at the head of its own source, absences included.\n' >> "$md"
korerun markdown -t text -w 40 "$md" > "$g" 2>&1 || fail "kore markdown -t text (long)"
korerun markdown -t cells -w 40 "$md" > "$o" 2>&1 || fail "kore markdown -t cells"
grep -q 'quoted' "$o" || { cat "$o"; fail "kore markdown -t cells: the quote did not read"; }
awk 'length > 40 { exit 1 }' "$o" || fail "kore markdown -t cells -w 40: a line overran"
[ "$(tr -s ' \n' '\n\n' < "$g")" = "$(tr -s ' \n' '\n\n' < "$o")" ] || fail "kore markdown -t cells: the words differ from -t text"
cmp -s "$g" "$o" && fail "kore markdown -t cells: broke every line as -t text does"
# the default is html, and stdin is a filter
korerun markdown < "$md" > "$g" 2>&1
korerun markdown -t html "$md" > "$o" 2>&1
cmp -s "$g" "$o" || fail "kore markdown: stdin and -t html disagree with the default"
korerun markdown -t bogus "$md" > /dev/null 2>&1
[ $? -eq 2 ] || fail "kore markdown -t bogus: not usage's 2"
# ..and back the other way, through the same middle
korerun markdown "$md" | korerun html2text -w 60 > "$o" 2>&1 || fail "kore html2text"
grep -q 'quoted' "$o" || { cat "$o"; fail "kore html2text: the quote did not read"; }
grep -q 'para em' "$o" || { cat "$o"; fail "kore html2text: the paragraph did not read"; }
echo "kore: markdown / html2text (the lapiz doors, cited not borrowed) ok"
