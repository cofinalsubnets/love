; repl I/O: the read -> parse -> eval -> print pipeline that the repl runs per
; submitted line, exercised hermetically on synthetic ports (no real terminal).
; ri-eval feeds a source string through the repl's own `parseall` (the line is
; implicitly parenthesized and read as ONE expression, so reader infix works at
; the prompt), evaluates it with `ev`, and prints the result to a pad capture
; port via the same fputx the repl prints with -- so the whole text-in/text-out
; contract is a pure value. (The interactive multi-line line editor is covered in
; test/repl.l; its getc/putc are wired to the real in/out ports.)

(: (ri-cl s) ((: (g i) (? (< i (sat s)) (cons (peep s i 0) (g (+ 1 i))))) 0)   ; string -> charlist
   (ri-eval s)
     (: cap (pad 0)
        _ (each (parseall (ri-cl s)) (\ v (: _ (fputx cap (ev v)) (fputc cap 10))))
        (page cap)))

(assert
  ; --- one value: read, eval, print the result + newline ---
  (= "3\n" (ri-eval "(+ 1 2)"))
  (= "9\n" (ri-eval "(* 3 3)"))
  ; --- a line of values is ONE expression: `x y z` evaluates as (x y z) ---
  (= "1728\n" (ri-eval "(+ 1 2) (* 3 4)"))      ; (3 12) = 12**3
  (= "9\n" (ri-eval "1 2 3"))                   ; the tower: 3**(2**1)... via (1 2)=2, (2 3)=9
  (= "2\n" (ri-eval "inc 1"))                   ; bare application
  ; --- infix at the prompt ---
  (= "1\n" (ri-eval "1 = 1"))
  (= "0\n" (ri-eval "0 = 1"))
  (= "3\n" (ri-eval "1 + 2"))
  (= "7\n" (ri-eval "1 + 2 * 3"))
  (= "1\n" (ri-eval "5 % 2"))
  (= "big\n" (ri-eval "(1 < 2) ? 'big 'small"))
  ; --- result types print in their canonical read-back form ---
  (= "(1 2 3)\n" (ri-eval "(list 1 2 3)"))      ; a list
  (= "\"hi\"\n" (ri-eval "\"hi\""))             ; a string -> quoted
  (= "~(1.0 2.0)\n" (ri-eval "~(1 2)"))       ; a complex scalar
  ; --- a whole body-ful form: a local define then a use, one result ---
  (= "9\n" (ri-eval "(: sq (\\ x (* x x)) (sq 3))"))
  ; --- the reader skips whitespace and ;-comments ---
  (= "1\n" (ri-eval "  ; a comment\n  1  "))
  ; --- empty / all-whitespace input yields no output ---
  (nilp (ri-eval ""))
  (nilp (ri-eval "   "))
  ; --- the read side: parseall signals an incomplete form (not a datum list),
  ;     which is how the repl decides "keep editing" rather than submit.
  ;     reading is STRUCTURAL: only an unclosed shape pends -- a trailing
  ;     operator is a complete datum whose factor folds to a partial (curry
  ;     law) at compile time, so those lines submit ---
  (nilp (twop (parseall (ri-cl "(+ 1"))))       ; unclosed list -> the more-sentinel
  (twop (parseall (ri-cl "1 +")))               ; complete: evals to the partial (+ 1)
  (twop (parseall (ri-cl "1 ? 'a")))            ; complete: (? 1 'a), the curried cond
  ("a\n" = (ri-eval "1 ? 'a"))                  ; ... which selects 'a
  (twop (parseall (ri-cl "(+ 1 2)")))           ; closed -> a one-form list
  (twop (parseall (ri-cl "1 = 1")))
  ; --- closed loop: the printed output re-reads + re-evals to the same result ---
  (= "3\n" (ri-eval (ri-eval "(+ 1 2)"))))
