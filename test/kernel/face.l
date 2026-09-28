; test/kernel/face.l -- a loaded face on the paper, left for the seat outside to count.
; the word `full` lays a face whose 世 is a solid 16x16 and whose Ā a solid 8x16; any other
; lays the same two glyphs empty. /proc/vt/face takes it (kmain's k_vt_face), and the
; two code points, which the built-in cp437 face lacks, draw from it. the cursor goes
; first, as in ink.l: a blinking cell would make the count a coin flip.
(borrow 'face)
(: (fin l) (? (two? >l) (fin >l) <l)
   full (fin argv = "full")
   (row d) (cats (map (\ _ (? full "F" "0")) (jot d)))
   (line cp d) (cp + ":" + cats (map (\ r (row d)) (jot 16)))
   f (face-hex ((line "4E16" 4) + "\n" + (line "0100" 2) + "\n"))
   q (open "/proc/vt/face" "w")
   _ (? (hot? q) (say q f, close q) (puts "face: no /proc/vt/face\n"))
   _ (puts $ (string 27) + "[?25l" + "\u{4e16}\u{100}\n")
   (rest 2000))
