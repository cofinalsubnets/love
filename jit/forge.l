; jit/forge.l -- the HOST counterpart to jit/probe.l. Proves that (forge ...)
; lifts the host's NX-heap limitation: bytes copied into the W^X code arena run
; natively under (call ...), no qemu, no kernel.
;
; x86_64 ONLY (raw machine code). Run on a hosted x86_64 build:
;
;     make host
;     out/host/love jit/forge.l        # expect: 42 / 12345 / 7
;
; On a non-x86_64 host these opcodes are garbage -- this file would crash, which
; is exactly why the gate corpus (test/jit.l) stays architecture-neutral and the
; real execution lives here, run by hand on the matching machine.

; mov eax, 42 ; ret   (B8 2A 00 00 00  C3)
(: b (buf 6) _ (pin b 0 184) _ (pin b 1 42) _ (pin b 5 195)
   _ (dot (call (forge b) 0)) _ (dot "\n"))

; mov eax, 12345 ; ret   (B8 39 30 00 00  C3) -- a second immediate, not a fluke
(: b (buf 6) _ (pin b 0 184) _ (pin b 1 57) _ (pin b 2 48) _ (pin b 5 195)
   _ (dot (call (forge b) 0)) _ (dot "\n"))

; ECHO THE ARGUMENT, cleanly. (call ...) passes the love arg as its RAW tagged
; word (putfix A = 2A+1) and re-tags the result, so a body that just returns
; %rdi double-tags. Shifting right by one inside cancels the incoming tag, so
; the love result equals the love argument -- a clean proof %rdi reaches the
; code:  mov rax, rdi ; shr rax, 1 ; ret   (48 89 F8  48 D1 E8  C3).
(: b (buf 7) _ (pin b 0 72) _ (pin b 1 137) _ (pin b 2 248)
   _ (pin b 3 72) _ (pin b 4 209) _ (pin b 5 232) _ (pin b 6 195)
   f (forge b)
   _ (dot (call f 7)) _ (dot " ") _ (dot (call f 12345)) _ (dot "\n"))   ; echoes 7 then 12345
