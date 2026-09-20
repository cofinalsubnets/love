#!/bin/sh
# test/kore/status.sh -- the status charm: mains answer, the image survives, the seat quits
. "$(dirname "$0")/common.sh"

# every main ANSWERS its status (apps/kore/core.l's urun) instead of quitting, so
# a caller staying in the image lives through a tool that fails -- the property the
# seat hides, since the seat quits with the answer. one image, four tools whose
# statuses are 1, 2 (a udie from deep inside), 0 and 0: the run must reach the last
# say, and the charms must be exactly those. nothing else in test/kore/ can catch this:
# a regression to `quit` still passes every other subject.
LOVE_NO_IMAGE= "$m" -e '(: _ (borrow (name "kore")) a (kore-main (list "kore" "false"))
                                    b (kore-main (list "kore" "basename"))
                                    c (kore-main (list "kore" "true"))
                                    d (kore-main (list "kore" "echo" "alive"))
                                    _ (say out (show a + " " + show b + " " + show c + " " + show d + "\n"))
                                    (quit 0))' > "$o" 2>/dev/null
r=$?
[ $r -eq 0 ] || fail "kore in-image: the process did not survive four tools (exit $r)"
[ "$(tail -1 "$o")" = "1 2 0 0" ] || fail "kore in-image statuses: $(tail -1 "$o")"
# ..and the unknown tool answers usage's 2 rather than ending anything
LOVE_NO_IMAGE= "$m" -e '(: _ (borrow (name "kore")) r (kore-main (list "kore" "nosuchtool"))
                                    _ (say out ("after " + show r + "\n")) (quit 0))' > "$o" 2>/dev/null
[ "$(tail -1 "$o")" = "after 2" ] || fail "kore in-image unknown tool: $(tail -1 "$o")"
echo "kore: the status charm (mains answer, the image survives, the seat quits) ok"
