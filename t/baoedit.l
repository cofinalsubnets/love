; --- t/baoedit.l: a smoke test for cli's raw-line editor (l/boot/post.l `edraw`) ---
; edraw lives in l/boot/post.l, now the baked shell core (in the host egg), so edraw is
; a book global. it reads love forms, being the editor, so the thing to know is WHERE
; from: a port arg (here a (tap ..), never stdin). that is what keeps it clear of the
; corpus stream love0 reads, and why it can ride t/*.l at all.
; the piped forms read-eval off stdin (a pipe is the bare filter) while each edraw
; consumes its own sip. Run (test comes from t/00-init.l):
;
;   cat t/00-init.l t/baoedit.l | out/love
;
; green dots = pass; the shell's banner/prompts + edraw's ansi redraws are noise
; around them. Full interactive editing (real keystrokes, real tty) stays manual.

; (ed-keys l) = a sip over the byte list l -> an input port edraw reads keystroke by
; keystroke. event bytes: 13 = Enter; 4 = ^D; 127 = backspace; ESC [ D/C/H/F =
; left/right/home/end. abc = the charlist "abc", the target of every edit.
; eof = the sentinel edraw returns at ^D / port EOF: captured by reading it back
; off an empty port (the sentinel is bao-private now -- the editor no longer leaks
; its `eofsym` global, so we name it by what edraw produces, not by its binding).
(: edraw (cite 'cli 'edraw)              ; the editor primitives ride the bao module now
   edln (cite 'cli 'edln)
   (ed-keys l) (tap l)
   abc [97 98 99]
   eof (edraw (ed-keys 0) ""))

; submit, edit, and EOF -- all returning the raw bytes (no parseall), prompt "".
(: _ (test
   ; plain: a b c Enter -> "abc"
   (= abc (edraw (ed-keys [97 98 99 13]) ""))
   ; insert mid-line: a c, left, b, Enter -> "abc"
   (= abc (edraw (ed-keys [97 99 27 91 68 98 13]) ""))
   ; backspace: a b x <bsp> c Enter -> "abc"
   (= abc (edraw (ed-keys [97 98 120 127 99 13]) ""))
   ; HOME then insert: b c, HOME, a, Enter -> "abc"
   (= abc (edraw (ed-keys [98 99 27 91 72 97 13]) ""))
   ; end after HOME: a, HOME, end, b c, Enter -> "abc" (END returns to line tail)
   (= abc (edraw (ed-keys [97 27 91 72 27 91 70 98 99 13]) ""))
   ; ^D -> the EOF sentinel (bao-private), never a stray line
   (= eof (edraw (ed-keys [4]) ""))
   ; port EOF (empty input) -> the same sentinel
   (= eof (edraw (ed-keys 0) ""))))

; --- edln: edraw plus command history. returns (line . nhist), or 'eof at EOF
; (a public symbol, not edraw's private sentinel). same editing primitives; up/
; down (ESC [ A / ESC [ B) recall through hist (past lines, most-recent first).
(: _ (test
   ; the editing primitives carry over -- the line is now (cap r):
   (= abc (cap (edln (ed-keys [97 98 99 13]) "" ())))               ; a b c -> "abc"
   (= abc (cap (edln (ed-keys [97 99 27 91 68 98 13]) "" ())))      ; a c, left, b -> "abc"
   (= abc (cap (edln (ed-keys [97 98 120 127 99 13]) "" ())))       ; a b x <bsp> c -> "abc"
   ('eof = (edln (ed-keys [4]) "" ()))                            ; ^D -> the 'eof sentinel
   ('eof = (edln (ed-keys 0) "" ()))                              ; port EOF -> the same
   ; a submitted line is pushed onto history (most-recent first); blanks dropped:
   (= [abc] (cup (edln (ed-keys [97 98 99 13]) "" ())))             ; nhist on empty -> (abc)
   (= [abc abc] (cup (edln (ed-keys [97 98 99 13]) "" [abc])))      ; ... pushed on front
   (nil? (cap (edln (ed-keys [13]) "" [abc])))                      ; blank line -> ()
   (= [abc] (cup (edln (ed-keys [13]) "" [abc])))                   ; ... not recorded
   ; up recalls the most-recent entry; down past the draft is the empty draft:
   (= abc (cap (edln (ed-keys [27 91 65 13]) "" [abc])))            ; up, enter -> "abc"
   (nil? (cap (edln (ed-keys [27 91 66 13]) "" [abc])))             ; down (no newer) -> ""
   ; the live draft survives an up/down round-trip:
   (= [120] (cap (edln (ed-keys [120 27 91 65 27 91 66 13]) "" [abc])))))      ; x, up, down -> "x"

(test_fin ())
(puts "baoedit: ok") (putc 10)
