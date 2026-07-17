; the crew/holo/ assembler -- a CORE language service, baked into the post-egg layer of both
; the host `ai` and the bootstrap `ai0` (host/main.c), so the corpus exercises it under
; BOTH compilers, like prel/ev. Its whole surface is ONE public name: `holo`, a book --
; and a book is a lookup function, so (holo 'assemble) is the call; the internals live
; in the book too (crew/holo/export.l sweeps the whole load span: namespacing, not hiding).
; NOT in the kernel/wasm frontends (a host-only bake, like the parser combinators), so
; guard on its presence: (peep book 'holo 0) is the whole service in one read -- no
; helpless-read warning where it isn't baked. The full encoder gate (every backend
; golden, objdump-checked, + the text/elf frontends) stays in crew/holo/holotest.l (`make
; test_asm`, its own cat-stream of the sources, untouched by the module sweep); this is
; the SMOKE that the MODULE reaches the runtime and assembles bit-identically.
; reg map: r0=rax, r7=x86-r8 .. r10=x86-r11; goldens copied from asmtest.l (objdump-verified).
(? (lit? (peep book 'holo 0))                              ; presence check via the book -- no helpless-read warning when holo isn't baked (wasm/kernel)
   (: A (peep book 'holo 0)                                ; the module book; bindings LOCAL (a body-having :)
      holo-hex (A 'holo-hex)  assemble (A 'assemble)  label-at (A 'label-at)
    (assert
      ; -- x86-64 backend: the SIB + rotate + bignum-movabs forms the glaze's map probe leans on --
      (= "488d4c0001"  (holo-hex 'x64 '((leax r1 r0 r0 1 1))))         ; lea rcx,[rax+rax*1+1]  (the tagged-key lea)
      (= "4b8b44d808"  (holo-hex 'x64 '((ldx r0 r7 r10 8 8))))        ; mov rax,[r8+r11*8+8]   (slot value load)
      (= "48890c98"    (holo-hex 'x64 '((stx r0 r3 4 0 r1))))         ; mov [rax+rbx*4],rcx
      (= "48c1c020"    (holo-hex 'x64 '((rol r0 32))))                ; rol rax,32             (the hash rotate)
      (= "48b8157c4a7fb979379e" (holo-hex 'x64 '((li r0 11400714819323198485))))   ; movabs rax,0x9e3779b97f4a7c15 -- the bignum-safe le64 (a movk-or-//% bug would drop the high limb)
      ; -- label fixups resolve to rel32: a whole loop assembles, and its addresses are exposed
      ; (plain assemble lays branches long-form; the relaxing layout is the object writer's
      ; entry, gated byte-exact in crew/holo/holotest.l) --
      (= "4839c80f840800000048ffc8e9efffffffc3"
         (holo-hex 'x64 '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret))))
      (= 17 (label-at (assemble 'x64 '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret))) 'done))
      ; -- the aarch64 backend rides the SAME neutral IR (a second target, byte-checked as data) --
      (= "2000028b" (holo-hex 'arm64 '((add r0 r1 r2))))
      (= "207c029b" (holo-hex 'arm64 '((imul r0 r1 r2))))))
   0)
