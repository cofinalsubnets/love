; --- test/baoedit.l: a smoke test for cli's raw-line editor (src/love/boot/post.l `edraw`) ---
; edraw lives in src/love/boot/post.l, now the baked shell core (in the host egg), so edraw is
; a book global. it reads love forms, being the editor, so the thing to know is WHERE
; from: a port arg (here a (tap ..), never stdin). that is what keeps it clear of the
; corpus stream love0 reads, and why it can ride test/*.l at all.
; the piped forms read-eval off stdin (a pipe is the bare filter) while each edraw
; consumes its own sip. Run (test comes from test/00-init.l):
;
;   cat test/00-init.l test/baoedit.l | out/love
;
; green dots = pass. Full interactive editing (real keystrokes, real tty) stays manual.

; (ed-keys l) = a sip over the byte list l -> an input port edraw reads keystroke by
; keystroke. event bytes: 13 = Enter; 4 = ^D; 127 = backspace; ESC [ D/C/H/F =
; left/right/home/end. abc = the charlist "abc", the target of every edit.
; eof = the sentinel edraw returns at ^D / port EOF: captured by reading it back
; off an empty port (the sentinel is bao-private now -- the editor no longer leaks
; its `eofsym` global, so we name it by what edraw produces, not by its binding).
; the editor paints stdout and asks the terminal questions: muted, so neither reaches it
(: edraw (\ k p (test-mute (_ \ cite 'cli 'edraw k p)))
   edln (\ k p h (test-mute (_ \ cite 'cli 'edln k p h)))
   edlay (cite 'cli 'edlay)
   (ed-keys l) (tap l)
   abc [97 98 99]
   eof (edraw (ed-keys 0) ""))

; submit, edit, and EOF -- all returning the raw bytes (no parseall), prompt "".
(: _ (test
   ; plain: a b c Enter -> "abc"
   (abc = edraw (ed-keys [97 98 99 13]) "")
   ; insert mid-line: a c, left, b, Enter -> "abc"
   (abc = edraw (ed-keys [97 99 27 91 68 98 13]) "")
   ; backspace: a b x <bsp> c Enter -> "abc"
   (abc = edraw (ed-keys [97 98 120 127 99 13]) "")
   ; HOME then insert: b c, HOME, a, Enter -> "abc"
   (abc = edraw (ed-keys [98 99 27 91 72 97 13]) "")
   ; end after HOME: a, HOME, end, b c, Enter -> "abc" (END returns to line tail)
   (abc = edraw (ed-keys [97 27 91 72 27 91 70 98 99 13]) "")
   ; ^D -> the EOF sentinel (bao-private), never a stray line
   (eof = edraw (ed-keys [4]) "")
   ; port EOF (empty input) -> the same sentinel
   (eof = edraw (ed-keys 0) "")))

; --- edln: edraw plus command history. returns (line . nhist), or 'eof at EOF
; (a public symbol, not edraw's private sentinel). same editing primitives; up/
; down (ESC [ A / ESC [ B) recall through hist (past lines, most-recent first).
(: _ (test
   ; the editing primitives carry over -- the line is now (cap r):
   (abc = <(edln (ed-keys [97 98 99 13]) "" ()))          ; a b c -> "abc"
   (abc = <(edln (ed-keys [97 99 27 91 68 98 13]) "" ())) ; a c, left, b -> "abc"
   (abc = <(edln (ed-keys [97 98 120 127 99 13]) "" ()))  ; a b x <bsp> c -> "abc"
   ('eof = edln (ed-keys [4]) "" ())                       ; ^D -> the 'eof sentinel
   ('eof = edln (ed-keys 0) "" ())                         ; port EOF -> the same
   ; a submitted line is pushed onto history (most-recent first); blanks dropped:
   ([abc] = >(edln (ed-keys [97 98 99 13]) "" ()))        ; nhist on empty -> (abc)
   ([abc abc] = >(edln (ed-keys [97 98 99 13]) "" [abc])) ; ... pushed on front
   !<(edln (ed-keys [13]) "" [abc])                          ; blank line -> ()
   ([abc] = >(edln (ed-keys [13]) "" [abc]))              ; ... not recorded
   ; up recalls the most-recent entry; down past the draft is the empty draft:
   (abc = <(edln (ed-keys [27 91 65 13]) "" [abc])) ; up, enter -> "abc"
   !<(edln (ed-keys [27 91 66 13]) "" [abc])           ; down (no newer) -> ""
   ; the live draft survives an up/down round-trip:
   ([120] = <(edln (ed-keys [120 27 91 65 27 91 66 13]) "" [abc]))))      ; x, up, down -> "x"

; a bracketed paste is text: a line break in it breaks the buffer's line and submits nothing,
; a crlf is one break, a tab stays and every other control goes; the whole buffer is the line
(: _ (test
   ("ab\nc" = string (edraw (ed-keys [97 27 91 50 48 48 126 98 10 99 27 91 50 48 49 126 13]) ""))
   ("x\ny\n\tz" = string (edraw (ed-keys [27 91 50 48 48 126 120 13 10 121 10 27 1 9 122 27 91 50 48 49 126 13]) ""))
   ("ls" = string <(edln (ed-keys [27 91 50 48 48 126 108 115 27 91 50 48 49 126 13]) "" ()))
   (0 = (cite 'cli 'edkey (ed-keys [27 91 50 48 49 126])))))     ; a stray close is a miss

; a terminal that answers DECRQM with ?2027 set measures by grapheme cluster, and the editor
; then measures, steps and deletes by cluster too; reset, or unknown, it stays off
(: edkey (cite 'cli 'edkey) edgc (cite 'cli 'edgc)
   (bs s) (map (i \ s i) (jot #s))
   fam "\u{1f468}\u{200d}\u{1f469}\u{200d}\u{1f467}"         ; 👨‍👩‍👧: 18 bytes, three wide chars
   _ (test (0 = edkey (ed-keys (bs "\e[?2027;2$y"))) (0 = edgc 'on)
           (0 = edkey (ed-keys (bs "\e[?2027;1$y"))) (1 = edgc 'on))
   _ (test ([0 4 0] = edlay 80 2 () (rev (bs fam)) () ())                      ; "> " then two columns
           (("x" + fam) = string (edraw (ed-keys (bs (fam + "\e[Dx\r"))) ""))   ; left over the whole of it
           ("a" = string (edraw (ed-keys (bs ("a" + fam + "\x7f\r"))) ""))     ; backspace takes it all
           ((fam + "y") = string (edraw (ed-keys (bs (fam + "\e[H\e[Cy\r"))) ""))
           ("" = string (edraw (ed-keys (bs (fam + "\e[H\e[3~\r"))) "")))
   _ (pin edgc 'on 0)
   (test ([0 8 0] = edlay 80 2 () (rev (bs fam)) () ())))                     ; off: wcwidth's six


; the layout under the redraw: [row col endrow] of the cursor on a screen w wide, rows
; from the buffer's first. a line wraps at w; one ending on the margin leaves the
; cursor pending, so it covers no extra row -- but the cursor itself is placed past it
(: _ (test
   ([0 3 0] = edlay 80 2 () ^1 () ())             ; "> a": row 0, column 3
   ([1 0 0] = edlay 10 2 () ^8 () ())             ; the cursor on the margin: the row below, col 0
   ([1 1 1] = edlay 10 2 () ^9 () ())             ; one past it: a second row
   ([0 5 1] = edlay 10 2 () ^3 ^9 ())             ; the tail wraps behind the cursor
   ([2 3 2] = edlay 10 2 [^15] ^3 () ())          ; a wrapped line above counts two rows
   ([1 0 1] = edlay 10 0 [()] () () ())           ; an empty line above is one row
   ([0 0 1] = edlay 10 0 () () () [^10])          ; a line below that fills its row
   ([0 0 2] = edlay 10 0 () () () [^11])))        ; ..and one that wraps

(test_fin ())
