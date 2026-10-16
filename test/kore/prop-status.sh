#!/bin/sh
# test/kore/prop-status.sh -- the status charm: mains answer, the image lives on
. "$(dirname "$0")/common.sh"

# every main answers its status rather than quitting, so a caller in the image survives a
# failing tool. one image, four tools answering 1, 2 (a deep udie), 0, 0: the run reaches the
# last say with exactly those charms
LOVE_NO_IMAGE= "$m" -e '(: _ (borrow (name "kore")) a (kore-main (list "kore" "false"))
                                    b (kore-main (list "kore" "test" "(" "x"))
                                    c (kore-main (list "kore" "true"))
                                    d (kore-main (list "kore" "echo" "alive"))
                                    _ (say out (show a + " " + show b + " " + show c + " " + show d + "\n"))
                                    (quit 0))' > "$o" 2>/dev/null
r=$?
[ $r -eq 0 ] || fail "kore in-image: the process did not survive four tools (exit $r)"
[ "$(tail -1 "$o")" = "1 2 0 0" ] || fail "kore in-image statuses: $(tail -1 "$o")"
# ..and an unknown tool answers usage's 2 and ends nothing
LOVE_NO_IMAGE= "$m" -e '(: _ (borrow (name "kore")) r (kore-main (list "kore" "nosuchtool"))
                                    _ (say out ("after " + show r + "\n")) (quit 0))' > "$o" 2>/dev/null
[ "$(tail -1 "$o")" = "after 2" ] || fail "kore in-image unknown tool: $(tail -1 "$o")"
echo "kore: the status charm (mains answer, the image survives, the seat quits) ok"
