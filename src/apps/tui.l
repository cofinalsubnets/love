; src/apps/tui.l -- the parts every full-screen app repeats. cli's `stage` already brackets
; raw mode and the alternate screen, decodes keys and re-reads the tty; what it does not
; carry is the two pieces each app was writing again: where the window sits, and how to
; put a frame on the screen without repainting all of it.
;
;   (tui-settle cur top rows)              -> the new top
;   (tui-fresh box h geo key rows stat cr cc) -> the escapes for this frame
;   (tui-vis l cr)                         -> l with its control bytes shown
;
; both are pure but for tui-fresh's one pin, so an app stays testable headless.
(module '(tui tui-settle tui-fresh tui-vis)
(:
   ; the window follows the cursor only far enough to hold it, which is what makes a
   ; page read as a page and not as a jump. rows is the body's height; for a view with
   ; a stride (lupa's sixteen bytes a row) settle the row index and scale the answer
   (tui-settle cur top rows)
    (? (cur < top) cur (top + rows <= cur) (cur - rows + 1) top)

   ; a tab to the next stop of 8, the other control bytes as ^X, a return dropped unless cr:
   ; no escape a file or a sender wrote reaches the terminal
   (tui-vis l cr)
    (: j (jug 0) n #l
       (go i col)
        (n <= i ? (slurp j)
           (l i @ c
              (? (c = 9) (8 - col % 8 @ k (say j (edfit "" k " "), go (i + 1) (col + k)))
                 (c = 13 && !cr) (go (i + 1) col)
                 (c < 32 || c = 127) (say j ("^" + string (c = 127 ? 63 (c + 64))), go (i + 1) (col + 2))
                 (put j c, go (i + 1) (col + (128 <= c < 192 ? 0 1))))))
       (go 0 0))

   ; a full redraw a keystroke is the flicker: the screen is cleared line by line and
   ; rewritten while the terminal draws it. so keep the rows the last frame put there,
   ; place only the ones that differ, and bracket the lot in synchronised-output mode
   ; (DEC 2026) so a scroll lands in one piece -- a terminal that does not know 2026
   ; ignores it, as does quay.
   ;
   ; box is the app's own state tablet; 'lastr on it is this function's business alone.
   ; geo is whatever the app calls "the view has not moved" -- when it differs the rows
   ; are placed from the top instead of diffed, since they no longer line up. key is an
   ; optional content key: when the app can say the body is a pure function of it, an
   ; equal key means nothing in the body can have changed and the rows are not walked at
   ; all. () means no such key, and then the rows are always compared -- so the presence
   ; test is against (), not truth: a key of 0 or (0 0) is a key like any other.
   (tui-fresh box h geo key rows stat cr cc)
    (: e (string 27)
       old (box 'lastr)                           ; [geo key rows status]
       same? (two? old && key != () && <>old = key)
       at? (two? old && <old = geo)
       (place i ln) "\(e)[\(i + 1);1H\(ln)\(e)[K"
       (dif a b i acc)
        (atom? b ? acc
           (dif (two? a ? >a ()) >b (i + 1)
                (two? a && <a = <b ? acc (acc + place i <b))))
       body (? same? ""
                at? (dif <>>old rows 0 "")
                (: (go l acc) (atom? l ? acc (go >l (acc + <l + e + "[K" + "\r\n")))
                   (e + "[H" + go rows "")))
       stat2 (at? && <>>>old = stat ? "" (place (h - 1) stat))
       (pin box 'lastr [geo key rows stat],
        "\(e)[?2026h\(body)\(stat2)\(e)[\(cr);\(cc)H\(e)[?2026l")))
) ; module tui
