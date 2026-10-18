; src/apps/tui.l -- what cli's `stage` does not carry for a full-screen app: where the window
; sits, and putting a frame on the screen without repainting all of it.
;
;   (tui-settle cur top rows)              -> the new top
;   (tui-fresh box h geo key rows stat cr cc) -> the escapes for this frame
;
; both are pure but for tui-fresh's one pin, so an app stays testable headless.
(module '(tui tui-settle tui-fresh)
(:
   ; the window follows the cursor only far enough to hold it. rows is the body's height; for a
   ; strided view settle the row index and scale the answer
   (tui-settle cur top rows)
    (? (cur < top) cur (top + rows <= cur) (cur - rows + 1) top)

   ; a full redraw per key flickers, so place only the rows that differ from the last frame,
   ; bracketed in synchronised output (DEC 2026, ignored where unknown). 'lastr on box is this
   ; function's alone. a changed geo places rows from the top. key, when not (), says the body
   ; is a pure function of it, so an equal key skips the walk; 0 is a key like any other.
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
