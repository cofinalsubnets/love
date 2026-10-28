; smoke for the holo assembler module; () where it isn't baked, and each backend gates on (A 'backends)
; reg map: r0=rax, r7=x86-r8 .. r10=x86-r11; goldens from test/holo/golden.l
(? (lit? (cite 'holo))                                     ; () when holo isn't baked
   (: A (cite 'holo)
      holo-hex (A 'holo-hex)  assemble (A 'assemble)  label-at (A 'label-at)
      ((? (peep (A 'backends) 'x64 0)
        (test
         ; -- x64: sib, rotate, bignum movabs --
         ("488d4c0001" = holo-hex 'x64 '((leax r1 r0 r0 1 1)))                 ; lea rcx,[rax+rax*1+1]  (the tagged-key lea)
         ("4b8b44d808" = holo-hex 'x64 '((ldx r0 r7 r10 8 8)))                 ; mov rax,[r8+r11*8+8]   (slot value load)
         ("48890c98" = holo-hex 'x64 '((stx r0 r3 4 0 r1)))                    ; mov [rax+rbx*4],rcx
         ("48c1c020" = holo-hex 'x64 '((rol r0 32)))                           ; rol rax,32             (the hash rotate)
         ("48b8157c4a7fb979379e" = holo-hex 'x64 '((li r0 0x9e3779b97f4a7c15))) ; movabs rax, both limbs
         ("486bc108" = holo-hex 'x64 '((imul r0 r1 8)))                        ; imul rax,rcx,8: the byte form
         ("4869c1e8030000" = holo-hex 'x64 '((imul r0 r1 1000)))               ; ..and the dword
         ("0f28c1" = holo-hex 'x64 '((movapd f0 f1)))                          ; movaps xmm0,xmm1
         ; -- li 0 is xor where a jump lands ahead on a flag writer, not on a reader --
         (holo-hex 'x64 '((xor r0 r0 r0) (jmp l) (label l) (cmp r0 r1) (ret))
            = holo-hex 'x64 '((li r0 0) (jmp l) (label l) (cmp r0 r1) (ret)))
         (holo-hex 'x64 '((xor r0 r0 r0) (jmp l) (label l) (br eq l) (ret))
            != holo-hex 'x64 '((li r0 0) (jmp l) (label l) (br eq l) (ret)))
         ; -- label fixups resolve to rel32; plain assemble lays branches long-form --
         ("4839c80f840800000048ffc8e9efffffffc3"
            = holo-hex 'x64 '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret)))
         (17 = label-at (assemble 'x64 '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret))) 'done))
        0),
       ; -- a64, the same neutral ir --
       (? (peep (A 'backends) 'a64 0)
        (test
         ("2000028b" = holo-hex 'a64 '((add r0 r1 r2)))
         ("207c029b" = holo-hex 'a64 '((imul r0 r1 r2))))
        0)))
   0)
