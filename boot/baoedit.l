; --- boot/baoedit.l: a smoke test for bao's raw-line editor (ai/bao.l `edraw`) ---
; edraw lives in ai/bao.l (a host-only loadable lib), so this can't run in the
; corpus OR the plain-`ai` hostnif lane -- it needs bao loaded. But edraw reads
; from a PORT ARG (here a (sip ..), not stdin), so the bao shell can drive it:
; load bao, and the auto-launched shell read-evals these forms off stdin while
; each edraw consumes its own sip. Run (assert comes from test/00-init.l):
;
;   cat test/00-init.l boot/baoedit.l | out/host/ai -l ai/bao.l
;
; green dots = pass; the shell's banner/prompts + edraw's ANSI redraws are noise
; around them. Full interactive editing (real keystrokes, real tty) stays manual.

; (keys l) = a sip over the byte list l -> an input port edraw reads keystroke by
; keystroke. event bytes: 13 = Enter; 4 = ^D; 127 = backspace; ESC [ D/C/H/F =
; left/right/home/end. abc = the charlist "abc", the target of every edit.
(: (keys l) (sip l)
   abc (L 97 98 99))

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
   ; ^D -> eofsym (the repl.l sentinel, a leaked global), never a stray line
   (idp eofsym (edraw (keys (L 4)) ""))
   ; port EOF (empty input) -> eofsym too
   (idp eofsym (edraw (keys 0) ""))))

(puts "baoedit: ok") (putc 10)
