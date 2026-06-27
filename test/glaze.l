; jit -- the (eat 1 <toast> x) trampoline jumps into the machine code held by a
; TOAST (an opaque executable handle) and runs it natively (SysV/AArch64 ABI: the
; arg in the first register, the result in the return register, wrapped as a fixnum).
; (toast src) is the loader: it bakes src's bytes into an opaque toast -- on the host
; a W^X mmap arena (the malloc heap is NX), on the freestanding kernel a plain heap
; copy (the HHDM is already executable). The idiom is (eat 1 (toast bytes) x); see
; ai/glaze/README.md + ai/glaze/probe.l.
;
; A toast is OPAQUE: hot?, but NOT a cask -- its code can't be peep/pin/tally'd as
; data, only (eat ..) runs it. These asserts are ARCHITECTURE-NEUTRAL on purpose:
; actually executing bytes is machine-specific (x86_64 opcodes crash an aarch64 or
; wasm host), so the real round-trip lives in the standalone ai/glaze/probe.l (kernel).
; Here we cover what holds on every target: the guards and the opacity, no run.
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
