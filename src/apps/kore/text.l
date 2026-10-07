; src/apps/kore/text.l -- the shared text layer: lines (unlines is post's), the list<->text
; bridge every line tool rides. a line is a string without its newline, and `unlines` terminates
; every line, so a missing final newline is data: a tool asks `nl-end?` and `chomp`s to keep it.
;
; loads before diff.l in the gate: udiff captures `lines` at its define.
(module 'kore
(:
   ; text -> the list of its lines, split at charm 10
   (lines s)
    (: n #s
       (go cite k acc) (? (n <= k) (cite < k ? (rev (snip s cite k . acc)) (rev acc))
                          (s k = 10) (go (k + 1) (k + 1) (snip s cite k . acc))
                          (go cite (k + 1) acc))
       (go 0 0 ()))
   ; the two that put back what `unlines` cannot know: did this text end in a newline,
   ; and drop one if it is there. an empty text ends in nothing, so it answers 0 and
   ; chomps to itself -- neither is a special case anywhere above.
   (nl-end? s) (#s @ n (0 < n && s (n - 1) = 10))
   (chomp t) (#t @ n (nl-end? t ? (snip t 0 (n - 1)) t)))
) ; module 'kore
