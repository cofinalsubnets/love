; test/kernel/kit.l -- a kitty picture on the paper, left for the seat outside to count.
; the word `full` sends a 16x16 white square (f=24, direct), placed at the cursor; any
; other sends it black, the console's ground. the cursor goes first, as in ink.l.
(: (fin l) (two? >l ? (fin >l) <l)
   q (fin argv = "full" ? "////" "AAAA")                  ; three bytes, one pixel
   ((puts $ (string 27) + "[?25l"
          + string 27 + "_Ga=T,f=24,s=16,v=16;" + cats (map (_ \ q) (jot 256)) + string 27 + "\\"),
    rest 2000))
