; t/kernel/doomrun.l -- boot straight into doom: `-append t/kernel/doomrun.l` on a
; DOOM=1 kernel. headless it proves the start-up (the sound module says whether the
; horn opened); on a framebuffer it is the game, and quitting it from the menu is the
; reset, which ends a gate the way all.l's does.
(puts "doomrun: starting\n", flush out, doom (), puts "doomrun: doom quit\n", flush out, reset ())
