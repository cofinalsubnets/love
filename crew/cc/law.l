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

; --- the parser: precedence, associativity, desugarings, statement shapes ---
(: (cast src) (caup (cparse (caup (clex src))))
   (cexp src) (: ast (cast (+ "int main() { return " (+ src "; }")))
                 fn (cap (caup ast))
                 items (caup (caup (cuup fn)))
                 (caup (cap items)))
   (assert
      (= (cast "int main() { return 42; }")
         '(prog ((fn "main" () (blk ((ret (num 42))))))))
      (= (cast "int add(int a, int b) { return a+b; }")
         '(prog ((fn "add" ("a" "b") (blk ((ret (bin + (var "a") (var "b")))))))))
      (= (cast "int f(void); int main() { return 0; }")
         '(prog ((proto "f") (fn "main" () (blk ((ret (num 0))))))))
      (= (cexp "f(1, 2+3)") '(call "f" ((num 1) (bin + (num 2) (num 3)))))
      (= (cexp "f()") '(call "f" ()))
      (= (cexp "f(g(1))") '(call "f" ((call "g" ((num 1))))))
      (= (cexp "2+3*4") '(bin + (num 2) (bin * (num 3) (num 4))))
      (= (cexp "10-3-2") '(bin - (bin - (num 10) (num 3)) (num 2)))
      (= (cexp "(2+3)*4") '(bin * (bin + (num 2) (num 3)) (num 4)))
      (= (cexp "1<<3") '(bin shl (num 1) (num 3)))
      (= (cexp "a<b==c") '(bin eq (bin lt (var "a") (var "b")) (var "c")))
      (= (cexp "-x") '(un neg (var "x")))
      (= (cexp "!~x") '(un not (un bnot (var "x"))))
      (= (cexp "x=y=1") '(asn (var "x") (asn (var "y") (num 1))))    ; right assoc
      (= (cexp "x+=2") '(asn (var "x") (bin + (var "x") (num 2))))   ; the desugar
      (= (cexp "++x") '(asn (var "x") (bin + (var "x") (num 1))))
      (= (cexp "x--") '(post (var "x") -1))
      (= (cexp "a?1:2") '(cond (var "a") (num 1) (num 2)))
      (= (cexp "1,2") '(comma (num 1) (num 2)))
      (= (cexp "a&&b||c") '(lor (land (var "a") (var "b")) (var "c")))
      (= (cast "int main() { int x=1; if (x) return 2; return 3; }")
         '(prog ((fn "main" () (blk ((decl (("x" (num 1))))
                                     (if (var "x") (ret (num 2)) ())
                                     (ret (num 3))))))))
      (= (cast "int main() { while (1) break; return 0; }")
         '(prog ((fn "main" () (blk ((while (num 1) (brk)) (ret (num 0))))))))
      (! (cparse (caup (clex "int main() { return (1+2; }"))))       ; the lost )
      (! (cparse (caup (clex "int main() { if 1 return 2; }"))))     ; if wants parens
      (! (cparse (caup (clex "int main() { return 42 }"))))
      (! (cparse ()))))

; --- the generator: one full golden, and the refusals that guard the seams ---
(: (cast src) (caup (cparse (caup (clex src))))
   ir (caup (cgen (cast "int main() { return 42; }")))
   (assert
      (= ir '((call main) (mov r6 r0) (li r0 60) (sys)
              (label main) (push r4) (mov r4 sp) (sub sp sp 0)
              (li r0 42) (mov sp r4) (pop r4) (ret)
              (li r0 0) (mov sp r4) (pop r4) (ret)))
      (two? (cgen (cast "int main() { int x=1; while (x<5) x++; return x; }")))
      (! (cgen (cast "int f() { return 1; }")))                      ; no main, no program
      (! (cgen (cast "int main() { return y; }")))                   ; undeclared name
      (! (cgen (cast "int main() { return 5=3; }")))                 ; not an lvalue
      (! (cgen (cast "int main() { break; }")))                      ; no loop to leave
      (! (cgen (cast "int main() { int a=1; int b=2; return a<<b; }")))   ; variable shift: the holo seam
      (two? (cgen (cast "int f(int a) { return a; } int main() { return f(1); }")))
      (! (cgen (cast "int main() { return f(1,2,3,4,5,6,7); }")))          ; the six-register fence ...
      (! (cgen (cast "int f(int a,int b,int c,int d,int e,int x,int y) { return 1; } int main() { return 1; }")))))  ; ... both sides of it

(say err "crew/cc/law: lexer (kinds/lines/munch) + parser (precedence/desugar/shapes + refusals) + gen (golden + the guarded seams) ok")
(put err 10)
