; --- boot/baoedit.l: a smoke test for bao's raw-line editor (ai/bao.l `edraw`) ---
; edraw lives in ai/bao.l, now the BAKED shell core (in the host egg), so edraw is
; a bag global -- but it reads ai forms (it's the editor), so it can't be a corpus
; test (ai0 bakes the corpus and would run edraw on the test stream). edraw reads
; from a PORT ARG (here a (sip ..), not stdin), so the bare stdin runner drives it:
; the piped forms read-eval off stdin (a pipe is the bare filter) while each edraw
; consumes its own sip. Run (assert comes from test/00-init.l):
;
;   cat test/00-init.l boot/baoedit.l | out/host/ai
;
; green dots = pass; the shell's banner/prompts + edraw's ANSI redraws are noise
; around them. Full interactive editing (real keystrokes, real tty) stays manual.

; (keys l) = a sip over the byte list l -> an input port edraw reads keystroke by
; keystroke. event bytes: 13 = Enter; 4 = ^D; 127 = backspace; ESC [ D/C/H/F =
; left/right/home/end. abc = the charlist "abc", the target of every edit.
; eof = the sentinel edraw returns at ^D / port EOF: captured by READING it back
; off an empty port (the sentinel is bao-private now -- the editor no longer leaks
; its `eofsym` global, so we name it by what edraw produces, not by its binding).
(: (keys l) (sip l)
   abc (L 97 98 99)
   eof (edraw (keys 0) ""))

; submit, edit, and EOF -- all returning the RAW bytes (no parseall), prompt "".
(: _ (assert
   ; plain: a b c Enter -> "abc"
   (= abc (edraw (keys (L 97 98 99 13)) ""))
   ; insert mid-line: a c, LEFT, b, Enter -> "abc"
   (= abc (edraw (keys (L 97 99 27 91 68 98 13)) ""))
   ; backspace: a b x <bsp> c Enter -> "abc"
   (= abc (edraw (keys (L 97 98 120 127 99 13)) ""))
   ; HOME then insert: b c, HOME, a, Enter -> "abc"
   (= abc (edraw (keys (L 98 99 27 91 72 97 13)) ""))
   ; END after HOME: a, HOME, END, b c, Enter -> "abc" (END returns to line tail)
   (= abc (edraw (keys (L 97 27 91 72 27 91 70 98 99 13)) ""))
   ; ^D -> the EOF sentinel (bao-private), never a stray line
   (id? eof (edraw (keys (L 4)) ""))
   ; port EOF (empty input) -> the same sentinel
   (id? eof (edraw (keys 0) ""))))

(puts "baoedit: ok") (putc 10)
