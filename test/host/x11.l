; --- test/host/x11.l: the X11 colour names (apps/x11.l) --------------------------------
;   cat test/00-init.l test/host/x11.l | out/love
(borrow 'x11)
(test ("#f0fff0" = x11 "honeydew")
      ("#e6e6fa" = x11 "Lavender")
      ("#000080" = x11 "Navy Blue")                   ; case and spaces do not count
      ("#bebebe" = x11 "gray") ("#808080" = x11 "webgray")   ; X11's gray, and the web's
      (() = x11 "mauve-ish") (() = x11 42)
      ([230 230 250] = x11-rgb "lavender")
      ("\e[38;2;240;255;240m" = x11-fg "honeydew")
      ("\e[48;2;0;0;0m" = x11-bg "black")
      ("" = x11-fg "nope")
      (189 = x11-256 "lavender") (231 = x11-256 "honeydew")   ; the cube cells quay lands on
      (16 = x11-256 "black") (231 = x11-256 "white") (196 = x11-256 "red")
      (140 < tally (x11-names 0))
      (string? (peep (x11-names 0) 0 ())))
(puts "x11: ok\n")
