; jit -- the (call buf x) trampoline jumps into the machine code in a buf and
; runs it natively (SysV/AArch64 ABI: the arg in the first register, the result
; in the return register, wrapped as a fixnum). (forge src) is the loader: it
; returns an EXECUTABLE buf holding a copy of src's bytes -- on the host a W^X
; mmap arena (the malloc heap is NX, so a raw (call <heap buf> ..) would fault),
; on the freestanding kernel a plain heap buf (the HHDM is already executable).
; The portable idiom is (call (forge bytes) x); see jit/README.md + jit/forge.l.
;
; These asserts are ARCHITECTURE-NEUTRAL on purpose: actually executing bytes is
; machine-specific (x86_64 opcodes crash an aarch64 or wasm host), so the real
; round-trip lives in the standalone jit/forge.l (host x86_64) and jit/probe.l
; (kernel). Here we cover only what holds on every target: the guards and that
; forge round-trips bytes into a buf without running them.
(assert
 (lamp call) (lamp forge)     ; both nifs present and applicable
 !(call 5 0)                  ; not a buf -> nothing (no jump)
 (0 = (call 'sym 0))          ; a symbol is not a buf
 !(call "text" 0)             ; a string is not a buf (bufp is false for strp)
 !(call () 0)                 ; nothing in -> nothing out
 (0 = (forge 5)) (0 = (forge 'x)) (0 = (forge ())) (0 = (forge ""))   ; non-bytes / empty -> 0
 (bufp (forge "AB"))          ; forge of bytes is a buf (executable, but a buf)
 (2 = (tally (forge "AB"))) (65 = (peep (forge "AB") 0 0)) (66 = (peep (forge "AB") 1 0))   ; bytes copied verbatim
 (: b (buf 3) _ (pin b 0 144) _ (pin b 1 195) f (forge b) (&& (bufp f) (144 = (peep f 0 0)))))  ; forge of a buf too
