; test/kernel/six.l -- a sixel picture on the paper, left for the seat outside to count.
; the word `full` draws a 16x16 white square, two tiles side by side; any other draws the
; same square black, which is the console's ground. the cursor goes first, as in ink.l. a
; digit ending the word re-makes the grid at that scale under the picture (/proc/vt/scale),
; which the store carries across.
(: (fin l) (? (two? >l) (fin >l) <l)
   w (fin argv)
   c (? (4 <= #w && snip w 0 4 = "full") "100;100;100" "0;0;0")
   d (? (0 < #w && 48 < (w (#w - 1)) && (w (#w - 1)) < 58) (string (w (#w - 1))) ())
   _ (puts $ (string 27) + "[?25l"
           + (string 27) + "Pq#0;2;" + c + "!16~-!16~-!16N" + (string 27) + "\\")
   _ (? d
        (: q (open "/proc/vt/scale" "w")
           (? (hot? q) (say q d, close q) (puts "six: no /proc/vt/scale\n")))
        ())
   (rest 2000))
