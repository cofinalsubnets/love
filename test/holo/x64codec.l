; the x86-64 table both ways: @PAIRS@ lists .text images, each instruction decoded by its row in
; x64-tab and laid again by x64-enc from the same name, width and operands, which must decode to
; the same item; an immediate is judged by its bytes, as b8 and c7 read the same value apart
(borrow 'holo)
(borrow 'posix)
(: (slurpf f) (open f "r" @ q (slurp q))
   tally {}
   (count k) (pin tally k (peep tally k 0 + 1))
   (miss why x) (count 'miss, peep tally 'miss 0 <= 4 ? (puts ("  " + why + " " + x + "\n")) 0)
   (bytes o) (o @ ('im v z) ['im (v % ((8 * z) 2) @ u (u < 0 ? (u + (8 * z) 2) u)) z] o)
   (norm it) ['op (it 1) (it 2) (map bytes (it 3))]
   (one s i it)
    (: ops (map (o \ (o @ ('lbl t) ['lbl (t - i)] o)) (it 3))
       (trap (_ \ x64-enc (it 1) (it 2) ops 0) 0 (a \ b \ ()) @ e
        (count 'n, x64-decode e 0 @ (k . back)
         (? (e = () || k != #e || back != [(norm ['op (it 1) (it 2) ops])] && map norm back != [(norm ['op (it 1) (it 2) ops])])
             (miss (show (it 1)) (show it + " -> " + (e = () ? "refused" (show e))))
            (e = map (j \ s (i + j)) ^k) (count 'same)
            0))))
   (walk s i) (? (i < #s) (x64-decode s i @ (k . items)
                             ((#items = 1 && (<<items = 'op) ? (one s i <items) 0), walk s (i + k))))
   (file l) (slurpf <(xa-split l 32) @ s (walk s 0))
   ((each (filter (l \ #l > 0) (xa-lines (slurpf "@PAIRS@"))) file),
    puts ("test/holo/x64codec: " + show (peep tally 'n 0) + " instructions, " + show (peep tally 'same 0)
          + " in the same bytes, " + show (peep tally 'miss 0) + " missed\n"),
    flush out,
    (peep tally 'miss 0 = 0 ? 0 (quit 1))))
