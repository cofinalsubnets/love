; the riscv table both ways: @PAIRS@ lists .text images, each word decoded by its row in rv-tab
; or rvc-tab and laid back by the same row, which must give the word again
(borrow 'holo)
(borrow 'posix)
(: (slurpf f) (open f "r" @ q (slurp q))
   (word s i n) (foldl (\ w k (w | dc-at s (i + k) << (8 * k))) 0 ^n)
   tally {}
   (count k) (pin tally k (peep tally k 0 + 1))
   (miss why x) (count 'miss, peep tally 'miss 0 <= 4 ? (puts ("  " + why + " " + x + "\n")) 0)
   (one s r)
    (: i <r n (r 1) it (r 2) w (word s i n)
       (? (<it != 'op || it 1 = 'unimp) 0
          (n = 4)
           (rv-enc (it 1) (it 2) i @ e
            (count 'n32, e = w ? 0 (miss (show (it 1)) (show (it 2) + " " + od-hex w + " -> " + od-hex e))))
          (rvd-first (r \ w & r 2 = r 1) rvc-tab @ c
           (: e (rvc-enc c (map (k \ rvd-cop k w i) (c 3)) i)
              (count 'n16, e = w ? 0 (miss <c (od-hex w + " -> " + od-hex e)))))))
   (file l) (slurpf l @ s (each (rv-disasm s 0 0 #s) (r \ one s r)))
   ((each (filter (l \ #l > 0) (xa-lines (slurpf "@PAIRS@"))) file),
    puts ("test/holo/rvcodec: " + show (peep tally 'n32 0) + " words, " + show (peep tally 'n16 0)
          + " halfwords, " + show (peep tally 'miss 0) + " missed\n"),
    flush out,
    (peep tally 'miss 0 = 0 ? 0 (quit 1))))
