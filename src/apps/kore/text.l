; src/apps/kore/text.l -- the shared text layer: lines and the list<->text bridge.
; a line has no newline and `unlines` ends every line, so a missing final newline is data:
; a tool asks `nl-end?` and `chomp`s to keep it. loads before diff.l, whose udiff reads `lines`.
(module 'kore
(:
   ; text -> the list of its lines, split at charm 10
   (lines s)
    (: n #s
       (go cite k acc) (? (n <= k) (cite < k ? (rev (snip s cite k . acc)) (rev acc))
                          (s k = 10) (go (k + 1) (k + 1) (snip s cite k . acc))
                          (go cite (k + 1) acc))
       (go 0 0 ()))
   ; what `unlines` cannot know: did the text end in a newline, and drop it. "" answers 0
   (nl-end? s) (#s @ n (0 < n && s (n - 1) = 10))
   (chomp t) (#t @ n (nl-end? t ? (snip t 0 (n - 1)) t)))
) ; module 'kore
