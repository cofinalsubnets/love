; the aarch64 table both ways: @PAIRS@ lists .text images, each word decoded by its row in
; a64-tab and laid again by a64-enc from the same name and operands, which must give the word
(borrow 'holo)
(borrow 'posix)
(: (slurpf f) (open f "r" @ q (slurp q))
   tally {}
   (count k) (pin tally k (peep tally k 0 + 1))
   (miss why x) (count 'miss, peep tally 'miss 0 <= 4 ? (puts ("  " + why + " " + x + "\n")) 0)
   (one s r)
    (: it (r 2) w (dc-le s <r 4)
       (<it != 'op ? 0
          (trap (_ \ a64-enc (it 1) (it 2) <r) 0 (a \ b \ -1) @ e
           (count 'n, e = w ? 0
            (miss (show (it 1)) (show (it 2) + " " + od-hex w + " -> " + (e < 0 ? "refused" (od-hex e))))))))
   (file l) (slurpf l @ s (each (a64-disasm s 0 0 #s) (r \ one s r)))
   ((each (filter (l \ #l > 0) (xa-lines (slurpf "@PAIRS@"))) file),
    puts ("test/holo/a64codec: " + show (peep tally 'n 0) + " words, " + show (peep tally 'miss 0)
          + " missed\n"),
    flush out,
    (peep tally 'miss 0 = 0 ? 0 (quit 1))))
