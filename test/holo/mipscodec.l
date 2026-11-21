; the mips table both ways. without MIPS_BIN: 24 words for each row of mips-tab, its free bits at
; random (clz's rt its rd, as the isa asks), as .word lines for llvm-mc. with MIPS_BIN, the raw
; text section llvm laid of them: each word as llvm-objdump writes it, on stdout, and laid back
; by the row that decoded it, which must give the word again
(borrow 'holo)
(borrow '(posix bytes))
(: seed {0 777}
   (rnd u) (pin seed 0 ((seed 0 * 1103515245 + 12345) & 2147483647), seed 0)
   (one r)
    (: hi (rnd 0) lo (rnd 0) w (r 1 | (hi << 16 ^ lo) & (4294967295 ^ r 2) & 4294967295)
       (elem 'rdt (r 3) ? (w & 0xffe0ffff | (w >> 11 & 31) << 16) w))
   (gen u) (each mips-tab (r \ each ^24 (k \ puts (".word 0x" + radix (one r) 16 + "\n"))))
   misses {0 0}
   (back s r)
    (: w (rdbe s <r 4) row (rvd-first (r \ w & r 2 = r 1) mips-tab) it (r 2)
       (two? row && me-word row (mips-vals row (it 2) <r) != w
        ? (pin misses 0 (misses 0 + 1), misses 0 <= 4 ? (say err ("  " + show <it + " " + od-hex w + "\n")) 0) 0))
   (dec f)
    (: s (open f "r" @ q (slurp q)) rows (mips-disasm s 0 0 #s)
       (each rows (r \ (r 2 0 = 'skip ? (puts "...\n")
                        (back s r, puts (radix <r 16 + ":\t" + <(mips-od r <r (a \ "")) + "\n")))),
        say err ("test/holo/mipscodec: " + show #rows + " rows, " + show (misses 0) + " laid back wrong\n"),
        misses 0 = 0 ? 0 (quit 1)))
   (getenv "MIPS_BIN" @ f (f = () || f = "" ? (gen 0) (dec f))))
