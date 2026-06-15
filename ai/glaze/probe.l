; ai/glaze/probe.l -- the RWX probe. Decides one fact: is love's data memory
; executable? i.e. can the bytes of a `toast` (on the kernel, a plain heap copy)
; be jumped into and run?
;
; It builds a buf holding six AMD64 bytes --
;
;     B8 2A 00 00 00   mov eax, 42      ; imm32 little-endian = 42 (0x2A)
;     C3               ret              ; return; eax/rax = 42
;
; -- then calls it via the (call ...) trampoline and taps the result to `out`.
;
; READING THE OUTCOME (run on the KERNEL target under qemu, NOT the host: the
; Linux malloc heap is NX, so a host run faults no matter what and tells you
; nothing about how Limine mapped the HHDM that backs the kernel's bufs):
;
;   * prints 42  => data memory is ALREADY executable. The trampoline IS the
;                   whole substrate; a love glaze is an afternoon away.
;   * faults     => HHDM is mapped no-execute. The substrate also needs a
;     (hang /     clear-the-NX-bit step in the kernel's page tables before a buf
;      reset)     can be run. Bounded work, but a real step up.
;
; REQUIRES the call + toast nifs wired into ai.c first. Until then `call`/`toast`
; are missing names that read the zero point -- the probe is inert.
;
; KEEP THIS OUT OF THE GATE CORPUS: if memory is NX, (call ...) faults the whole
; kernel (the kernel has no signal barrier), which would take `make test` down with
; it. Run it standalone.

(: b (buf 6)
   _ (pin b 0 184)              ; B8   mov eax, imm32
   _ (pin b 1 42)               ; 2A   imm32 = 42   (bytes 2..4 stay 0 from the zeroed buf)
   _ (pin b 5 195)              ; C3   ret
   r (call (toast b) 0)         ; bake the bytes into a toast, jump in; arg ignored
   _ (dot r))                   ; 42 on success
