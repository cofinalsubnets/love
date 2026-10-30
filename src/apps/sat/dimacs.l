; dimacs -- a dimacs cnf reader for the sat solver, built from the parser combinators in src/love/boot/post.l
; (a parser is (\ s y n): a state s = (text . i), a success continuation y = (rest payload),
; a failure continuation n = rest; payloads are lists that `seq` concatenates).
(module 'sat
(borrow 'peg)

(:
   ; -- character classes + the signed-integer leaf --
   (ws? c)   (c @ (32 || 9 || 13 || 10) 1 0)     ; space/tab/cr/lf -- a ?-name owes a bit
   (dig? c)  (47 < c < 58)                 ; '0'..'9'
   (notnl? c) (c != 10)
   (str->nat ds) (foldl (\ a i (a * 10 + ds i - 48)) 0 ^#ds)
   (pint s y n)                                            ; an optional '-' then >=1 digits -> (the int); fail otherwise
    (: t <s i0 >s m #t neg (i0 < m && t i0 = 45) j0 (i0 + ?neg)
       j (: (g i) (i < m && dig? (t i) ? (g (i + 1)) i) (g j0))
     (j = j0 ? (n s) (str->nat (snip t j0 j) @ v (y (t . j) [(neg ? -v v)]))))
   ; -- the dimacs grammar --
   ws        (skip (span ws?))                              ; a (possibly empty) whitespace run
   cline     (seq (lit "c") (span notnl?))                  ; a 'c' comment: 'c' + rest of line (the newline is ws)
   pre       (skip (many (seq ws cline)))                   ; leading comment lines
   header    (seqs [ws (lit "p") ws (lit "cnf") ws pint ws pint])     ; -> ("p" "cnf" nvars nclauses)
   body      (many (seq ws pint))                           ; -> all body integers (lits + 0 terminators)
   cnf       (seqs [pre header body])                       ; -> ("p" "cnf" nvars nclauses . ints)
   (split0 ints)                                            ; split an int stream into clauses, dropping the 0 terminators
    ((: (g ls cur acc)
        (? (atom? ls) (atom? cur ? (rev acc) (rev (rev cur . acc)))         ; flush a final un-terminated clause
           (<ls = 0) (g >ls () (rev cur . acc))
           (g >ls (<ls . cur) acc))) ints () ())
   (dimacs text) (runp cnf text @ p (split0 (drop 4 p) . p 2)))          ; (formula . nvars)
) ; module sat
