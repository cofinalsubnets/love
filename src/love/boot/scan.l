; scan -- find one byte in a text, natively where possible. love's own walk costs
; ~684 instructions a byte, the kernel below ~1.9; the glaze's lanes leave string
; work to the interpreter, so a hand-written kernel is the only way in.
;
; eight bytes a step: (w - ones) & ~w & highs is nonzero exactly when some byte of w
; is zero, so xor'ing the text with the needle in all eight lanes turns "is this byte
; the needle" into "is this byte zero". a hit inside a word falls to the byte loop.
;
; built on first use, not at a module binding: this text runs inside the boot's module
; registry, before (borrow 'holo), and assembling there takes the registry down.
; one holo run and one arena blob per process.
;
; the blob names no address of the binary, so it survives a bake woken under another
; base: the string-kind guard loads its sentinel from g's reach (glaze.l's `reach` law).
(module 'scan
(:
   ; the twin: the oracle the laws hold the kernel to, and the engine wherever it can't be built
   (walk s c i) (: n #s (go k) (n <= k ? -1 (s k = c ? k (go (k + 1)))) (go (i < 0 ? 0 i)))

   ones 72340172838076673                        ; 0x0101010101010101
   ; highs is ones << 7, shifted rather than written: as a literal it is a bignum,
   ; which `li` does not take
   ;
   ; lvm ops are C functions of (g, Ip, Hp, Sp), so the roles sit in each target's
   ; argument registers and differ between x64 and a64: never spell them below
   ;                            g   ip  sp  scratch
   (abi tgt) (tgt @ 'a64 '(r0 r1 r3 r4) '(r6 r5 r1 r0))
   ; r7 = the charm, r8 = the cursor, r9 = the bytes, r10 = n, r11 = the charm in all
   ; eight lanes, r12 = ones, r13 = highs, r14 = ~w. r11..r14 are callee-saved on x64,
   ; so pushed; the guards deopt before any push, so sp balances on every way out
   (scan-ir tgt)
    (: rg (abi tgt) G <rg IP <>rg SP <>>rg SC <>>>rg
       ([['ld SC SP 0] ['test SC 1] '(br ne deopt)               ; Sp[0] a pointer ...
          ['ld 'r7 SC 0]
          ; the string kind off g's reach (slot 1), never an li of (apof "")
          ['ld 'r8 G (reach-offset 0 + 8)]
          '(cmp r7 r8) '(br ne deopt)]                            ; ... of string kind
        + [['ld SC SP 8] ['test SC 1] '(br eq deopt)]             ; Sp[1] a charm
        + [['ld SC SP 16] ['test SC 1] '(br eq deopt)]            ; Sp[2] a charm
        + [['ld 'r9 SP 0] '(ld r10 r9 8) '(lea r9 r9 16)          ; the bytes, and n
           ['ld 'r7 SP 8] '(sar r7 1)                             ; c, untagged
           ['ld 'r8 SP 16] '(sar r8 1)                            ; the start, untagged
           '(cmp r8 0) '(br lt deopt)                             ; a negative start is the twin's
           '(cmp r7 0) '(br lt deopt)
           '(cmp r7 255) '(br gt deopt)]                          ; a charm past a byte: the twin's
        + '((push r11) (push r12) (push r13) (push r14))
        + [['li 'r12 ones]] + '((mov r13 r12) (shl r13 7))
        + [['mov 'r11 'r7]                                        ; the needle into all eight lanes,
           ['mov SC 'r11] ['shl SC 8] ['or 'r11 'r11 SC]          ; by doubling: 1 -> 2 -> 4 -> 8
           ['mov SC 'r11] ['shl SC 16] ['or 'r11 'r11 SC]
           ['mov SC 'r11] ['shl SC 32] ['or 'r11 'r11 SC]]
        + ['(label al)                                            ; up to the first 8-boundary
           '(cmp r8 r10) '(br ge nf)
           ['mov SC 'r8] ['and SC SC 7] ['cmp SC 0] '(br eq wl)
           ['ldxb SC 'r9 'r8 1 0] ['cmp SC 'r7] '(br eq hit)
           '(add r8 r8 1) '(jmp al)]
        + ['(label wl)                                            ; eight at a time
           ['mov SC 'r8] ['add SC SC 8] ['cmp SC 'r10] '(br gt tl)
           ['ldx SC 'r9 'r8 1 0] ['xor SC SC 'r11]
           ['mov 'r14 SC] '(not r14) ['sub SC SC 'r12]
           ['and SC SC 'r14] ['and SC SC 'r13]
           ['cmp SC 0] '(br ne tl)                                ; the needle is in this word
           '(add r8 r8 8) '(jmp wl)]
        + ['(label tl)                                            ; the tail, and the word that hit
           '(cmp r8 r10) '(br ge nf)
           ['ldxb SC 'r9 'r8 1 0] ['cmp SC 'r7] '(br eq hit)
           '(add r8 r8 1) '(jmp tl)]
        + ['(label hit) ['mov SC 'r8] '(jmp fin)
           '(label nf) ['li SC -1]
           '(label fin) '(pop r14) '(pop r13) '(pop r12) '(pop r11)]
        + [['shl SC 1] ['or SC SC 1] ['st SP 0 SC]                ; tag, land on Sp[0], step Ip
           ['add IP IP 16] ['ld 'r7 IP 0] '(jmpr r7)]
        + ['(label deopt) ['ld 'r7 IP 8] ['lea IP 'r7 16]         ; arity >= 2: Ip <- the twin
           ['ld 'r7 IP 0] '(jmpr r7)]))

   ; build it, or answer the twin. `nif` hands the twin back when it declines (inle, wasm)
   (mk _) (: h (cite 'holo) g (cite 'glaze)
             (!h || !g || !(elem love-arch '(x64 a64)) ? walk
                (: bs (peep (h 'assemble love-arch (scan-ir love-arch)) 'bytes 0)
                   (g 'nif (cask bs) walk 3))))
   box {}                                ; one install for the process
   ; (scanner ()) -> (f s c i), the index of charm c at-or-after i, or -1.
   ; ask once and hold f: this is a tablet read, outside any loop
   (scanner _) (peep box 'k 'none @ k (k @- k 'none (mk () @ k2 (pin box 'k k2, k2))))
)

) ; module 'scan
