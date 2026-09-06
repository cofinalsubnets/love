; test/kernel/doomrun.l -- boot straight into doom: `-append test/kernel/doomrun.l` on a
; DOOM=1 kernel. headless it proves the start-up (the sound module says whether the
; horn opened); on a framebuffer it is the game.
(: _ (puts "doomrun: starting") _ (putc 10) _ (flush out) (doom ()))
