; the avr table both ways. without AVR_BIN: 24 words for each row of avr-tab a family has, its free
; bits at random, as .short lines for llvm-mc. with AVR_BIN, the raw text llvm laid of them: each as
; llvm-objdump writes it, on stdout, and laid back from its operands, which must give the bytes again.
; AVR_FAM names the family
(borrow 'holo)
(borrow '(posix bytes))
(: fam (name (getenv "AVR_FAM"))
   seed {0 777}
   (rnd u) (pin seed 0 ((seed 0 * 1103515245 + 12345) & 2147483647), seed 0)
   (rnd16 u) (rnd 0 >> 8 & 0xffff)
   ; a row's word: one register twice where the kind says so
   (one r)
    (: m (av-long? r ? 0xffffffff 0xffff)
       w (r 1 | (rnd16 0 << 16 | rnd16 0) & (m ^ r 2))
       (elem 'rr (r 3) ? (r 1 | av-get 0x1f0 w @ n (r 1 | av-put 0x1f0 n | av-put 0x20f n)) w))
   (put r) (: w (one r) (av-long? r ? (puts (".short 0x" + radix (w >> 16) 16 + ", 0x" + radix (w & 65535) 16 + "\n"))
                                   (puts (".short 0x" + radix w 16 + "\n"))))
   (gen u) (each (filter (av-has? fam) avr-tab) (r \ each ^24 (k \ put r)))
   misses {0 0}
   (back s r)
    (: it (r 2) got (<it = 'op ? (avr-bytes fam (it 1) (it 2)) ())
       (<it = 'op && got != map (i \ s (<r + i)) ^(r 1)
        ? (pin misses 0 (misses 0 + 1), misses 0 <= 4 ? (say err ("  " + show it + " " + show got + "\n")) 0) 0))
   (dec f)
    (: s (open f "r" @ q (slurp q)) rows (avr-disasm fam s 0 0 #s)
       (each rows (r \ (r 2 0 = 'skip ? (puts "...\n")
                        (back s r, puts (radix <r 16 + ":\t" + <(avr-od r <r (a \ "")) + "\n")))),
        say err ("test/holo/avrcodec: " + show #rows + " rows, " + show (misses 0) + " laid back wrong\n"),
        misses 0 = 0 ? 0 (quit 1)))
   (getenv "AVR_BIN" @ f (f = () || f = "" ? (gen 0) (dec f))))
