; test/kernel/font.l -- a loaded font on the paper, left for the seat outside to count.
; the word `full` lays a font whose 世 is a solid 16x16 and whose Ā a solid 8x16; any other
; lays the same two glyphs empty. /proc/vt/font takes it (kmain's k_vt_font), and the
; two code points, which the built-in cp437 font lacks, draw from it. the cursor goes
; first, as in ink.l: a blinking cell would make the count a coin flip.
(borrow 'font)
(: (fin l) (two? >l ? (fin >l) <l)
   full (fin argv = "full")
   (row d) (cats (map (_ \ (full ? "F" "0")) (jot d)))
   (line cp d) (cp + ":" + cats (map (r \ (row d)) (jot 16)))
   f (font-hex (line "4E16" 4 + "\n" + line "0100" 2 + "\n"))
   q (open "/proc/vt/font" "w")
   ((hot? q ? (say q f, close q) (puts "font: no /proc/vt/font\n")),
    (puts $ (string 27) + "[?25l" + "\u{4e16}\u{100}\n"),
    rest 2000))
