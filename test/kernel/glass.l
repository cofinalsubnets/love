; test/kernel/glass.l -- the framebuffer console's grid, read back off the machine: the door's
; pixels, the scale (the door's, or kmain's fbscale), and cbinit's rows and columns. the gate does
; the arithmetic on its own side, so the law is read twice. headless there is no grid, and tty
; answers the nom a host gives for an fd that is no terminal.
(tty 1 @ ws
   (two? ws ? (puts $ "glass " + show <ws + " " + show <>ws + "\n")
    (puts $ "glass none " + show ws + "\n")))
