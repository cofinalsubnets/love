; test/kernel/six.l -- a sixel picture on the paper, left for the seat outside to count.
; the word `full` draws a 16x16 white square, two tiles side by side; any other draws the
; same square black, which is the console's ground. the cursor goes first, as in ink.l.
(: (fin l) (? (two? >l) (fin >l) <l)
   c (? (fin argv = "full") "100;100;100" "0;0;0")
   _ (puts $ (string 27) + "[?25l"
           + (string 27) + "Pq#0;2;" + c + "!16~-!16~-!16N" + (string 27) + "\\")
   (rest 2000))
