; test/host/x11.l -- the x11 colour names (src/apps/x11.l)
;   cat test/00-init.l test/host/x11.l | out/love
(borrow 'x11)
(test ("#f0fff0" = x11 "honeydew")
      ("#e6e6fa" = x11 "Lavender")
      ("#000080" = x11 "Navy Blue")                   ; case and spaces do not count
      ("#bebebe" = x11 "gray") ("#808080" = x11 "webgray")   ; x11's gray, and the web's
      (() = x11 "mauve-ish") (() = x11 42)
      ([230 230 250] = x11-rgb "lavender")
      ("\e[38;2;240;255;240m" = x11-fg "honeydew")
      ("\e[48;2;0;0;0m" = x11-bg "black")
      ("" = x11-fg "nope")
      (189 = x11-256 "lavender") (231 = x11-256 "honeydew")   ; the cube cells quay lands on
      ([135 0 0] = x11-pen 88) ("#870000" = x11-pen-hex 88)   ; ..and back: the cube
      ([8 8 8] = x11-pen 232) ([238 238 238] = x11-pen 255)   ; ..and the grey ramp
      (() = x11-pen 7) (() = x11-pen "88") (() = x11-pen-hex 300)
      ("black" = x11-near 16) ("white" = x11-near 231)
      (all (c \ string? (x11-near c)) (map (+ 16) ^240))       ; every pen has a nearest name
      (16 = x11-256 "black") (231 = x11-256 "white") (196 = x11-256 "red")
      (140 < #(x11-names 0))
      (string? (peep (x11-names 0) 0 ())))
(puts "x11: ok\n")
