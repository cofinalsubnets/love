; comment syntax: `;` to end of line, `;;;`-at-line-start block comments, `#!` shebang.
; a plain `;` line comment (this line) is skipped.
;;;
this is a ;;; block comment. none of these lines are read:
(putx "if you see this the block comment leaked") (putc 10)
weird tokens ) ) ) ( ( " unterminated
;;;
; the block above is closed by the line starting with ;;;
(: cmt-after 7) ;;; a trailing ;;; is just a normal line comment, not a block
(assert
 (= 7 cmt-after)                                ; survived the trailing ;;; line comment
 (= 1 1))
