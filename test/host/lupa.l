; lupa (src/apps/lupa.l) headless: its step and frame over a raw program and over out/love's ELF
; run: cat test/00-init.l test/host/lupa.l | out/love
(borrow 'lupa)

   ; a csi ends at its final byte, @ through ~
(: (plain s) ((: (g i acc esc) (i < #s ? (s i @ c
                                     (? esc (g (i + 1) acc (? (c = 91) 1 (64 <= c <= 126) 0 1))
                                        (c = 27) (g (i + 1) acc 1)
                                        (g (i + 1) (acc + string c) 0))) acc)) 0 "" 0)
   (keys! d s) (each (map (i \ s i) ^#s) (c \ lupa-key d c))
   (cmd! d s) (lupa-key d 58, keys! d s, lupa-key d 13)
   (frame d) (plain (lupa-frame d 80 12))
   ; push rbp; mov rbp, rsp; mov eax, 42; pop rbp; ret; jmp back
   prog (string '(85 72 137 229 184 42 0 0 0 93 195 235 244))
   d (lupa-new prog "t.bin")
   _ (test (d 'mode = 'hex) (d 'cur = 0) (d 'n = 13))
   f (frame d)
   _ (test (has? f "lupa: t.bin") (has? f "hex att") (has? f "00000000  55 48 89 e5 b8 2a 00 00  00 5d c3 eb f4") (has? f "(raw bytes)"))
   _ (keys! d "lll", test (d 'cur = 3))
   _ (keys! d "j", test (d 'cur = 3))                ; no second row to land on
   _ (lupa-key d 71, test (d 'cur = 12))            ; G: the last byte
   _ (lupa-key d 103, test (d 'cur = 0))            ; g: the first
   _ (keys! d "d")
   f (frame d)
   _ (test (d 'mode = 'asm) (has? f "asm att") (has? f "push\t%rbp") (has? f "mov\t%rsp, %rbp")
             (has? f "mov\t$42, %eax") (has? f "pop\t%rbp") (has? f "ret") (has? f "jmp\t0x1"))   ; eb f4: back 12 from 13
   _ (keys! d "jj", test (d 'cur = 4))              ; past push (1) and mov (3)
   _ (keys! d "k", test (d 'cur = 1))
   ; off a boundary k takes the shortest decode ending there (00 00 at 6), else one byte back
   _ (cmd! d "g 8", test (d 'cur = 8))
   _ (keys! d "k", test (d 'cur = 6))
   _ (cmd! d "g 6", keys! d "k", test (d 'cur = 5))
   _ (cmd! d "g 4", keys! d "k", test (d 'cur = 1))              ; a boundary is unaffected
   _ (keys! d "s", test (has? (frame d) "mov\teax, 42") (has? (frame d) "asm intel"))
   _ (keys! d "s")
   _ (cmd! d "g 9", test (d 'cur = 9) (has? (frame d) "pop\t%rbp"))
   _ (cmd! d "g zz", test (d 'cur = 9) (has? (d 'msg) "no such place"))
   _ (keys! d "d", test (d 'mode = 'hex))
   ; find wraps
   _ (cmd! d "/ 48 89", test (d 'cur = 1) (has? (d 'msg) "found at 0x1"))
   _ (cmd! d "/ \"*\"", test (d 'cur = 5))          ; 42 is '*'
   _ (keys! d "n", test (d 'cur = 5) (has? (d 'msg) "found at 0x5"))
   _ (cmd! d "/ ff", test (d 'cur = 5) (has? (d 'msg) "not found"))
   ; the file string itself stays untouched
   _ (cmd! d "g 5")
   _ (keys! d "7f")
   _ (test (d 'dirty) (lupa-byte d 5 = 127) (d 'cur = 6) (prog 5 = 42) (has? (frame d) "[+]"))
   _ (keys! d "d", cmd! d "g 4", test (has? (frame d) "mov\t$127, %eax"), keys! d "d")
   _ (keys! d "q", test !(d 'over) (has? (d 'msg) "unsaved"))
   _ (cmd! d "q!", test (d 'over))
   (narrow? d w) (foldl (a \ l \ (a && #l <= w + 1)) 1 (split "\n" (plain (lupa-frame d w 10))))
   _ (test (narrow? d 60) (narrow? d 40))
   _ (keys! d "d", test (narrow? d 60) (narrow? d 40))

   ; out/love: an ELF, its .text and symbols
   (slurpf f) (open f "r" @ q (slurp q))
   love (slurpf "out/love")
   e (lupa-new love "out/love")
   _ (test (e 'mode = 'asm) (tablet? (e 'elf)) (0 < e 'elf 'tsize) (e 'cur = e 'elf 'toff))
   f (frame e)
   (test (has? f "lupa: out/love") (has? f ".text 0x"),
    cmd! e "g main",
    test (e 'cur = e 'elf 'toff + e 'elf 'names "main" - e 'elf 'taddr) (has? (frame e) "main:"),
    keys! e "jjj", test (has? (frame e) "main+0x"),
    0))

(test_fin ())
(puts "src/apps/lupa: ok -- hex and asm views, the cursor in both, find, the nibble edit, an ELF's .text and symbols\n")
