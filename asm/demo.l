; demo -- build two RUNNABLE binaries from the assembler, the proof that the bytes are real machine
; code and not just plausible hex. writes to /tmp and prints how to run each:
;
;   /tmp/ai-x64.elf    a Linux x86-64 static executable -- write(1,msg,n); exit(7). run it directly:
;                        chmod +x /tmp/ai-x64.elf && /tmp/ai-x64.elf ; echo $?
;
;   /tmp/ai-arm64.elf  a bare-metal aarch64 image for the qemu `virt` board -- it writes a line to
;                      the PL011 UART at 0x09000000, then spins. run it on an emulated ARM cpu:
;                        qemu-system-aarch64 -M virt -cpu cortex-a57 -nographic -kernel /tmp/ai-arm64.elf
;                      (ctrl-a x to quit qemu.)
;
; run: out/host/ai -l asm/asm.l -l asm/x64.l -l asm/arm64.l -l asm/elf.l asm/demo.l

(: say (\ s (: _ (puts s) (flush out)))

   ;; -- the x86-64 userland program: write the message via the Linux syscall ABI, then exit(7).
   ;; r0=rax(syscall#), r6=rdi(fd/arg0), r5=rsi(arg1), r2=rdx(arg2). --
   xmsg "hi from ai-asm (x86-64 linux)\n"
   (x64-prog a) (L (L 'li 'r0 1) (L 'li 'r6 1) (L 'li 'r5 a) (L 'li 'r2 (tally xmsg)) (L 'sys)
                   (L 'li 'r0 60) (L 'li 'r6 7) (L 'sys))
   xe (elf64 'x64 x64-prog (map xmsg (jot (tally xmsg))))
   _ (write-bytes "/tmp/ai-x64.elf" (peep xe 'bytes 0))

   ;; -- the aarch64 bare-metal program: no syscalls (there's no OS), just store each byte to the
   ;; UART data register, then loop. li the UART base once into r1; per char li r2,c ; st r1,0,r2. --
   amsg "hi from ai-asm running on emulated aarch64!\n"
   (a-char c) (L (L 'li 'r2 c) (L 'st 'r1 0 'r2))
   a-prog (cat (L (L 'li 'r1 0x09000000))
               (cat (foldr (\ c acc (cat (a-char c) acc)) () (map amsg (jot (tally amsg))))
                    (L (L 'label 'hang) (L 'jmp 'hang))))
   ae (elf64-at 0x40000000 'arm64 (\ a a-prog) ())          ; 0x40000000 = qemu-virt RAM base
   _ (write-bytes "/tmp/ai-arm64.elf" (peep ae 'bytes 0))

   _ (say "wrote /tmp/ai-x64.elf and /tmp/ai-arm64.elf\n")
   _ (say "  x64:   chmod +x /tmp/ai-x64.elf && /tmp/ai-x64.elf ; echo $?\n")
   _ (say "  arm64: qemu-system-aarch64 -M virt -cpu cortex-a57 -nographic -kernel /tmp/ai-arm64.elf\n"))
