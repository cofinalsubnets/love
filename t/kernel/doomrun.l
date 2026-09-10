; t/kernel/doomrun.l -- boot straight into doom: `-append t/kernel/doomrun.l` on a
; DOOM=1 kernel. headless it proves the start-up (the sound module says whether the
; horn opened); on a framebuffer it is the game.
(puts "doomrun: starting\n", flush out, doom ())
