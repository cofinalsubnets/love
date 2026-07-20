; the glaze's install seam, arch-neutral half: guards only, never an actual run (executing bytes
; is machine-specific). The executing tests are test/glaze-x86.l; the mechanism, love/glaze/README.md.
(assert
 ; `nif` -- the codegen-backend install seam (love.c): (nif code interp src ..) wraps
 ; emitted bytes in a TRANSPARENT applicable native closure. NEUTRAL here (no
 ; install/run -- the bytes are x86-64; the real round-trip lives in love/glaze/emit.l):
 ; non-byte / empty code installs nothing.
 (lit? nif)
 !(nif 5 0 0 1) !(nif 'x 0 0 1) !(nif () 0 0 1) !(nif "" 0 0 1))
