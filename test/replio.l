; repl I/O: the read -> parse -> eval -> print pipeline that the repl runs per
; submitted line, exercised hermetically on synthetic ports (no real terminal).
; ri-eval feeds a source string through the repl's own `parseall` (its C-reader
; integration: a charlist -> a strin port -> fread one datum at a time), evaluates
; each datum with `ev`, and prints the results to a strout capture port via the
; same fputx the repl prints with -- so the whole text-in/text-out contract is a
; pure value. (The interactive multi-line line editor is covered in test/repl.l;
; its getc/putc are wired to the real in/out ports and can't be redirected here.)

(: (ri-cl s) ((: (g i) (? (< i (hash s)) (X (peek s i 0) (g (+ 1 i))))) 0)   ; string -> charlist
   (ri-eval s)
     (: cap (strout 0)
        _ (each (parseall (ri-cl s)) (\ v (: _ (fputx cap (ev v)) (fputc cap 10))))
        (outstr cap)))

(assert
  ; --- one datum: read, eval, print the result + newline ---
  (= "3\n" (ri-eval "(+ 1 2)"))
  (= "9\n" (ri-eval "(* 3 3)"))
  ; --- several datums on one line: each prints in source order ---
  (= "3\n12\n" (ri-eval "(+ 1 2) (* 3 4)"))
  (= "1\n2\n3\n" (ri-eval "1 2 3"))
  ; --- result types print in their canonical read-back form ---
  (= "(1 2 3)\n" (ri-eval "(list 1 2 3)"))      ; a list
  (= "\"hi\"\n" (ri-eval "\"hi\""))             ; a string -> quoted
  (= "~(1.0 2.0)\n" (ri-eval "~(1 2)"))       ; a complex scalar
  ; --- a whole body-ful form: a local define then a use, one result ---
  (= "9\n" (ri-eval "(: sq (\\ x (* x x)) (sq 3))"))
  ; --- the reader skips whitespace and ;-comments between datums ---
  (= "1\n" (ri-eval "  ; a comment\n  1  "))
  ; --- empty / all-whitespace input yields no output ---
  (nilp (ri-eval ""))
  (nilp (ri-eval "   "))
  ; --- the read side: parseall signals an incomplete form (not a datum list),
  ;     which is how the repl decides "keep editing" rather than submit ---
  (nilp (twop (parseall (ri-cl "(+ 1"))))       ; unclosed list -> the more-sentinel
  (twop (parseall (ri-cl "(+ 1 2)")))           ; closed -> a one-element datum list
  ; --- closed loop: the printed output re-reads + re-evals to the same result ---
  (= "3\n" (ri-eval (ri-eval "(+ 1 2)"))))
