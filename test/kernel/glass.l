; test/kernel/glass.l -- the framebuffer console's grid, read back off the machine.
; a boot line names this file with a framebuffer under it, so what it prints is what the
; whole chain settled: real pixels from the door (inle/wasm/arch.c's k_start), a scale --
; the door's, or the largest glyph that still leaves a screen worth reading (kmain's
; fbscale) -- and rows and columns out of the two (cbinit). the gate does the arithmetic
; on its own side, which is the point: two readings of the same law, not one.
; headless there is no grid at all, and tty answers the nom a host gives for an
; fd that is no terminal.
(: ws (tty 1)
   (? (two? ws) (puts $ "glass " + (show <ws) + " " + (show <>ws) + "\n")
      (puts $ "glass none " + (show ws) + "\n")))
