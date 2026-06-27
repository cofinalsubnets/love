; the glaze's toast/eat substrate, arch-neutral half: guards and OPACITY only, never an actual run
; (executing bytes is machine-specific). The executing tests are test/glaze-x86.l; the real kernel
; round-trip, ai/glaze/probe.l; the mechanism, ai/glaze/README.md.
(assert
 (lit? eat) (lit? toast)      ; the runner + loader nifs are present and applicable (lit?: fns are top-region)
 !(eat 1 5 0) (0 = (eat 1 'sym 0)) !(eat 1 "text" 0) !(eat 1 () 0)   ; a non-toast -> nothing (no jump)
 !(eat 1 (cask 8) 0)          ; a plain cask is NOT callable -- only a toast runs
 (0 = (toast 5)) (0 = (toast 'x)) (0 = (toast ())) (0 = (toast ""))   ; non-bytes / empty -> 0
 (hot? (toast "AB")) !!(toast "AB")        ; a toast is an opaque hot, and present
 (0 = (tally (toast "AB")))                ; OPAQUE: not a cask, so no length to read
 (-1 = (peep (toast "AB") 0 -1))           ; OPAQUE: its code bytes are not readable
 (: b (cask 3) _ (pin b 0 144) _ (pin b 1 195) t (toast b) (&& (hot? t) (0 = (tally t))))  ; toast of a cask too
 ; `nif` -- the codegen-backend install seam (ai.c): (nif code interp src ..) wraps
 ; emitted bytes in a TRANSPARENT applicable native closure. NEUTRAL here (no
 ; install/run -- the bytes are x86-64; the real round-trip lives in ai/glaze/emit.l):
 ; non-byte / empty code installs nothing.
 (lit? nif)
 !(nif 5 0 0 1) !(nif 'x 0 0 1) !(nif () 0 0 1) !(nif "" 0 0 1))
