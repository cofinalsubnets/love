; crew/cc/law.l -- the compiler's laws (stage 0), held by assertion over the
; pure pipeline: lexer goldens (kinds, values, lines, maximal munch), parser
; AST goldens, and the WHOLE IR for return-42 compared form by form. the cat
; (`make test_cc`):
;
;   cat test/00-init.l crew/cc/lex.l crew/cc/parse.l crew/cc/gen.l crew/cc/law.l | out/host/ai
;
; the end-to-end (elf64, the run, the gcc differential) lives in the Makefile
; smoke through the real `au cc`.

; --- the lexer: kinds, values, lines, comments, maximal munch ---
(: (tn ts k) (? (< k 1) (cap ts) (tn (cup ts) (- k 1)))   ; lists don't index by application
   r (clex "int main() { return 42; }")
   ts (caup r)
   (assert
      (two? r) (= (tally ts) 9)
      (= (tn ts 0) (L 'kw 'int 1))
      (= (tn ts 1) (L 'id "main" 1))
      (= (tn ts 2) (L 'p "(" 1))
      (= (tn ts 3) (L 'p ")" 1))
      (= (tn ts 4) (L 'p "{" 1))
      (= (tn ts 5) (L 'kw 'return 1))
      (= (tn ts 6) (L 'num 42 1))
      (= (tn ts 7) (L 'p ";" 1))
      (= (tn ts 8) (L 'p "}" 1))))
(: (tn ts k) (? (< k 1) (cap ts) (tn (cup ts) (- k 1)))
   c1 (caup (clex "a // x\nb"))
   c2 (caup (clex "a /* x\ny */ b"))
   c3 (caup (clex "a+++b"))
   c4 (caup (clex "x <<= 1; y >>= 2;"))
   (assert
      (= (tally c1) 2) (= (tn c1 1) (L 'id "b" 2))          ; // eats the line, lines count
      (= (tally c2) 2) (= (tn c2 1) (L 'id "b" 2))          ; /* */ spans, lines count
      (= (tally c3) 4)                                       ; maximal munch: a ++ + b
      (= (tn c3 1) (L 'p "++" 1)) (= (tn c3 2) (L 'p "+" 1))
      (= (tn c4 1) (L 'p "<<=" 1)) (= (tn c4 5) (L 'p ">>=" 1))
      (! (clex "int @"))                                     ; not C: the lex error rides up
      (! (clex "a /* open"))                                 ; unterminated comment refused
      (= (caup (clex "")) ())))                              ; empty text, empty tokens

; --- the parser: the stage-0 grammar's AST, and its refusals ---
(: ast (caup (cparse (caup (clex "int main() { return 42; }"))))
   two (caup (cparse (caup (clex "int f() { return 1; } int main() { return 7; }"))))
   (assert
      (= ast (L 'prog (L (L 'fn "main" (L (L 'ret (L 'num 42)))))))
      (= (tally (caup two)) 2)
      (= (cap (caup two)) (L 'fn "f" (L (L 'ret (L 'num 1)))))
      (! (cparse (caup (clex "int main() { return 42 }"))))  ; the ; is not optional
      (! (cparse (caup (clex "int main() { return; }"))))    ; stage 0 wants a value
      (! (cparse (caup (clex "main() { return 1; }"))))      ; ... and the int
      (! (cparse ()))))                                      ; nothing is not a program

; --- the generator: the whole IR, golden ---
(: ir (caup (cgen (caup (cparse (caup (clex "int main() { return 42; }"))))))
   (assert
      (= ir '((call main) (mov r6 r0) (li r0 60) (sys)
              (label main) (li r0 42) (ret)))
      ; no main, no program
      (! (cgen (caup (cparse (caup (clex "int f() { return 1; }"))))))))

(say err "crew/cc/law: lexer (kinds/lines/munch) + parser (AST + refusals) + gen (the whole IR, golden) ok")
(put err 10)
