; --- t/host/lupa.l: the magnifier, headless ---
; the tool is a pure step and a pure frame (a/lupa.l); this drives both over a
; small raw program and over b/love itself -- an ELF with a .text and a symbol table -- and
; reads the frames back. run: cat t/00-init.l t/host/lupa.l | b/love
(borrow 'lupa)

(: (has? h n) (0 <= findsub h n)
   ;; the frame less its escapes: a CSI ends at its final byte, any of @ through ~
   (plain s) ((: (g i acc esc) (? (i < #s)
                                  (: c (s i)
                                     (? esc (g (i + 1) acc (? (c = 91) 1 (64 <= c <= 126) 0 1))
                                        (c = 27) (g (i + 1) acc 1)
                                        (g (i + 1) (acc + string c) 0)))
                                  acc)) 0 "" 0)
   (keys! d s) (each (map (i \ s i) ^#s) (c \ lupa-key d c))
   (cmd! d s) (: _ (lupa-key d 58) _ (keys! d s) (lupa-key d 13))
   (frame d) (plain (lupa-frame d 80 12))
   ;; -- a raw program: push rbp; mov rbp, rsp; mov eax, 42; pop rbp; ret; and a jump back --
   prog (string '(85 72 137 229 184 42 0 0 0 93 195 235 244))
   d (lupa-new prog "t.bin")
   _ (test (d 'mode = 'hex) (d 'cur = 0) (d 'n = 13))
   f (frame d)
   _ (test (has? f "lupa: t.bin") (has? f "hex att") (has? f "00000000  55 48 89 e5 b8 2a 00 00  00 5d c3 eb f4") (has? f "(raw bytes)"))
   ;; the cursor moves by bytes, and never leaves the file
   _ (keys! d "lll")  _ (test (d 'cur = 3))
   _ (keys! d "j")    _ (test (d 'cur = 3))          ; no second row to land on
   _ (lupa-key d 71)  _ (test (d 'cur = 12))        ; G: the last byte
   _ (lupa-key d 103) _ (test (d 'cur = 0))         ; g: the first
   ;; the asm view: instructions, the cursor an instruction, both spellings
   _ (keys! d "d")
   f (frame d)
   _ (test (d 'mode = 'asm) (has? f "asm att") (has? f "push\t%rbp") (has? f "mov\t%rsp, %rbp")
             (has? f "mov\t$42, %eax") (has? f "pop\t%rbp") (has? f "ret") (has? f "jmp\t0x1"))   ; eb f4: back 12 from 13
   _ (keys! d "jj")   _ (test (d 'cur = 4))         ; past push (1) and mov (3)
   _ (keys! d "k")    _ (test (d 'cur = 1))
   ;; a cursor that is no instruction boundary: the walk from the anchor steps PAST it and
   ;; never lands on it, so k takes the shortest real decode ENDING there instead -- 00 00
   ;; at 6 is two bytes and ends at 8. where nothing decodes to end there, one byte back.
   _ (cmd! d "g 8")   _ (test (d 'cur = 8))
   _ (keys! d "k")    _ (test (d 'cur = 6))
   _ (cmd! d "g 6")   _ (keys! d "k")    _ (test (d 'cur = 5))
   _ (cmd! d "g 4")   _ (keys! d "k")    _ (test (d 'cur = 1))   ; a boundary is unaffected
   _ (keys! d "s")    _ (test (has? (frame d) "mov\teax, 42") (has? (frame d) "asm intel"))
   _ (keys! d "s")
   ;; :g takes an address, and the mode toggles back
   _ (cmd! d "g 9")   _ (test (d 'cur = 9) (has? (frame d) "pop\t%rbp"))
   _ (cmd! d "g zz")  _ (test (d 'cur = 9) (has? (d 'msg) "no such place"))
   _ (keys! d "d")    _ (test (d 'mode = 'hex))
   ;; find: hex bytes from past the cursor, wrapping, and n again
   _ (cmd! d "/ 48 89")  _ (test (d 'cur = 1) (has? (d 'msg) "found at 0x1"))
   _ (cmd! d "/ \"*\"")  _ (test (d 'cur = 5))      ; 42 is '*'
   _ (keys! d "n")       _ (test (d 'cur = 5) (has? (d 'msg) "found at 0x5"))
   _ (cmd! d "/ ff")     _ (test (d 'cur = 5) (has? (d 'msg) "not found"))
   ;; editing: two nibbles overwrite a byte and step on; the file string itself is untouched
   _ (cmd! d "g 5")
   _ (keys! d "7f")
   _ (test (d 'dirty) (lupa-byte d 5 = 127) (d 'cur = 6) (prog 5 = 42) (has? (frame d) "[+]"))
   _ (keys! d "d") _ (cmd! d "g 4") _ (test (has? (frame d) "mov\t$127, %eax")) _ (keys! d "d")
   ;; a clean quit is refused while dirty; q! leaves
   _ (keys! d "q")    _ (test !(d 'over) (has? (d 'msg) "unsaved"))
   _ (cmd! d "q!")    _ (test (d 'over))
   ;; no line of a frame is wider than its screen, in either view, on a narrow screen too
   (narrow? d w) (foldl (\ a l (a && #l <= w + 1)) 1 (split "\n" (plain (lupa-frame d w 10))))
   _ (test (narrow? d 60) (narrow? d 40))
   _ (keys! d "d") _ (test (narrow? d 60) (narrow? d 40))

   ;; -- b/love: an ELF, its .text, its symbols -------------------------------------------
   (slurpf f) (: q (open f "r") (slurp q))
   love (slurpf "b/love")
   e (lupa-new love "b/love")
   _ (test (e 'mode = 'asm) (tablet? (e 'elf)) (0 < ((e 'elf) 'tsize)) (e 'cur = ((e 'elf) 'toff)))
   f (frame e)
   _ (test (has? f "lupa: b/love") (has? f ".text 0x"))
   ;; :g by symbol lands on it, and the row names it
   _ (cmd! e "g main")
   _ (test (e 'cur = ((e 'elf) 'toff) + (((e 'elf) 'names) "main") - ((e 'elf) 'taddr)) (has? (frame e) "main:"))
   _ (keys! e "jjj")  _ (test (has? (frame e) "main+0x"))
   0)

(test_fin ())
(puts "a/lupa: ok -- hex and asm views, the cursor in both, find, the nibble edit, an ELF's .text and symbols\n")
