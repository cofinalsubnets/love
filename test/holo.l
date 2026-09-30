; the src/love/holo/ assembler, baked into both love and love0, so the corpus runs it under
; both compilers. its surface is the module: (cite 'holo) answers the accessor, () where it
; was never baked (kernel/wasm), so the whole file guards on it. the host bakes only its
; native backend, so each backend's goldens gate on (A 'backends). the full encoder gate is
; test/holo/golden.l (test_holo) and the at&t front test/holo/as.l (test_as); this is the
; smoke that the module assembles bit-identically at runtime.
; reg map: r0=rax, r7=x86-r8 .. r10=x86-r11; goldens copied from golden.l (objdump-verified).
(? (lit? (cite 'holo))                                     ; presence check via the registry -- () when holo isn't baked (wasm/kernel)
   (: A (cite 'holo)                                       ; the module accessor; bindings local (a body-having :)
      holo-hex (A 'holo-hex)  assemble (A 'assemble)  label-at (A 'label-at)
      ((? (peep (A 'backends) 'x64 0)
        (test
         ; -- x86-64 backend: the SIB + rotate + bignum-movabs forms the glaze's map probe leans on --
         ("488d4c0001" = holo-hex 'x64 '((leax r1 r0 r0 1 1)))                 ; lea rcx,[rax+rax*1+1]  (the tagged-key lea)
         ("4b8b44d808" = holo-hex 'x64 '((ldx r0 r7 r10 8 8)))                 ; mov rax,[r8+r11*8+8]   (slot value load)
         ("48890c98" = holo-hex 'x64 '((stx r0 r3 4 0 r1)))                    ; mov [rax+rbx*4],rcx
         ("48c1c020" = holo-hex 'x64 '((rol r0 32)))                           ; rol rax,32             (the hash rotate)
         ("48b8157c4a7fb979379e" = holo-hex 'x64 '((li r0 0x9e3779b97f4a7c15))) ; movabs rax -- the bignum-safe le64 (a movk-or-//% bug would drop the high limb)
         ; -- label fixups resolve to rel32: a whole loop assembles, and its addresses are exposed
         ; (plain assemble lays branches long-form; the relaxing layout is the object writer's
         ; entry, gated byte-exact in test/holo/golden.l) --
         ("4839c80f840800000048ffc8e9efffffffc3"
            = holo-hex 'x64 '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret)))
         (17 = label-at (assemble 'x64 '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret))) 'done))
        0),
       ; -- the a64 backend rides the same neutral IR (a second target, byte-checked as data) --
       (? (peep (A 'backends) 'a64 0)
        (test
         ("2000028b" = holo-hex 'a64 '((add r0 r1 r2)))
         ("207c029b" = holo-hex 'a64 '((imul r0 r1 r2))))
        0)))
   0)
