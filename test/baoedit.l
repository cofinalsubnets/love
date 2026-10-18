; the raw-line editor edraw, fed keys from a (tap ..) port, never stdin
; keys: 13 enter, 4 ^D, 127 backspace, ESC [ D/C/H/F left/right/home/end.
; eof is edraw's private sentinel, read back off an empty port; output muted
(: edraw (k \ p \ test-mute (_ \ cite 'cli 'edraw k p))
   edln (k \ p \ h \ test-mute (_ \ cite 'cli 'edln k p h))
   edlay (cite 'cli 'edlay)
   (ed-keys l) (tap l)
   abc [97 98 99]
   eof (edraw (ed-keys 0) ""))

; submit, edit, and eof: raw bytes, prompt ""
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

; --- edln: edraw plus history, answering (line . nhist) or 'eof; up/down recall
(: _ (test
   ; the editing primitives carry over; the line is (cap r)
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

; --- edlnc's ^R: the history searched back from the newest; a key of the line takes the match
(: ed-lnc (k \ p \ h \ c \ cite 'cli 'edlnc k p h c)
   (ed-bs s) (map s ^#s)
   (ed-ln k h) (string <(test-mute (_ \ ed-lnc (ed-keys (ed-bs k)) "" (map ed-bs h) ())))
   ; (f 0)'s stdout, caught in a pipe: a few lines, so it never fills
   (ed-said f) (: _ (flush out) pp (pipe 0) s (dup 1)
                  _ (dup2 >pp 1, close >pp)
                  _ (mind f () (_ \ (flush out, dup2 s 1, close s)))
                  q (fdopen <pp) r (slurp q)
                  (close q, r))
   ed-hist ["make test" "ls -l" "echo hi"])
(: _ (test
   ("ls -l" = ed-ln "\x12ls\r" ed-hist)
   ("make test" = ed-ln "\x12e\r" ed-hist)              ; the newest holding it
   ("echo hi" = ed-ln "\x12e\x12\r" ed-hist)            ; ^R again: the next older
   ("make test" = ed-ln "\x12e\x12\x7f\r" ed-hist)      ; a backspace goes back a step
   ("x" = ed-ln "x\x12m\x07\r" ed-hist)                 ; ^G: the line as it was
   ("make test" = ed-ln "\x12ez\r" ed-hist)             ; a failing search keeps the last match
   ("" = ed-ln "\x12q\r" ed-hist)                       ; none at all: the draft
   ("echo hi!" = ed-ln "\x12ech\x05!\r" ed-hist)        ; ^E takes it, then edits it
   ("echo hi" = ed-ln "\x12ls\e[A\r" ed-hist)           ; up from the match: the one older
   ("x" = ed-ln "x\x12mak\e[B\r" ed-hist)))             ; down from the newest: the draft

; the search shows its query; a tab's candidate list is followed by the prompt, so the line
; it redraws is not indented by a prompt that is not there
(: _ (hosted ? (test
   (has? (ed-said (_ \ ed-lnc (ed-keys (ed-bs "\x12ls\r")) "P> " (map ed-bs ed-hist) ())) "(reverse-i-search)`ls': ")
   (has? (ed-said (_ \ ed-lnc (ed-keys (ed-bs "\x12lz\r")) "P> " (map ed-bs ed-hist) ())) "(failed reverse-i-search)`lz': ")
   (: s (ed-said (_ \ ed-lnc (ed-keys (ed-bs "f\t\r")) "P> " () (_ \ [[111] "foo" "fob"])))
      (has? (snip s (findsub s "foo  fob\n") #s) "P> ")))))

; a bracketed paste is text: a break (crlf one) splits the line, submits nothing; a tab stays
(: _ (test
   ("ab\nc" = string (edraw (ed-keys [97 27 91 50 48 48 126 98 10 99 27 91 50 48 49 126 13]) ""))
   ("x\ny\n\tz" = string (edraw (ed-keys [27 91 50 48 48 126 120 13 10 121 10 27 1 9 122 27 91 50 48 49 126 13]) ""))
   ("ls" = string <(edln (ed-keys [27 91 50 48 48 126 108 115 27 91 50 48 49 126 13]) "" ()))
   (0 = (cite 'cli 'edkey (ed-keys [27 91 50 48 49 126])))))     ; a stray close is a miss

; a terminal answering DECRQM ?2027 set makes the editor work by grapheme cluster
(: edkey (cite 'cli 'edkey) edgc (cite 'cli 'edgc)
   (bs s) (map (i \ s i) (jot #s))
   fam "\u{1f468}\u{200d}\u{1f469}\u{200d}\u{1f467}"         ; 👨‍👩‍👧: 18 bytes, three wide chars
   ((test (0 = edkey (ed-keys (bs "\e[?2027;2$y"))) (0 = edgc 'on)
          (0 = edkey (ed-keys (bs "\e[?2027;1$y"))) (1 = edgc 'on)),
    (test ([0 4 0] = edlay 80 2 () (rev (bs fam)) () ())                       ; "> " then two columns
          (("x" + fam) = string (edraw (ed-keys (bs (fam + "\e[Dx\r"))) ""))    ; left over the whole of it
          ("a" = string (edraw (ed-keys (bs ("a" + fam + "\x7f\r"))) ""))      ; backspace takes it all
          ((fam + "y") = string (edraw (ed-keys (bs (fam + "\e[H\e[Cy\r"))) ""))
          ("" = string (edraw (ed-keys (bs (fam + "\e[H\e[3~\r"))) ""))),
    pin edgc 'on 0,
    (test ([0 8 0] = edlay 80 2 () (rev (bs fam)) () ()))))                   ; off: wcwidth's six


; edlay: the cursor's [row col endrow] on a screen w wide; a line ending on the margin
; takes no extra row, but the cursor sits past it
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
