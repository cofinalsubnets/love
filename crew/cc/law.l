; crew/cc/law.l -- the compiler's laws (stage 0), held by assertion over the
; pure pipeline: lexer goldens (kinds, values, lines, maximal munch), parser
; AST goldens, and the WHOLE IR for return-42 compared form by form. the cat
; (`make test_cc`):
;
;   cat test/00-init.l crew/cc/lex.l crew/cc/parse.l crew/cc/gen.l crew/cc/law.l | out/host/ai
;
; the end-to-end (elf64, the run, the gcc differential) lives in the Makefile
; smoke through the real `aicc`.

; --- the lexer: kinds, values, lines, comments, maximal munch ---
(: (tn ts k) (? (< k 1) (cap ts) (tn (cup ts) (- k 1)))   ; lists don't index by application
   r (clex "int main() { return 42; }")
   ts (caup r)
   (assert
      (two? r) (= (tally ts) 9)
      (= (tn ts 0) (L 'kw 'int 1))
      (= (tn ts 1) (L 'id "main" 1))
      (= (tn ts 2) (L 'p "(" 1 1))              ; a '(' GLUED to `main` carries the 4th field (function-macro paren marker)
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
      (= (tn (caup (clex "'a' '\\n' '\\''")) 0) (L 'num 97 1))   ; char literals are numbers
      (= (tn (caup (clex "'a' '\\n' '\\''")) 1) (L 'num 10 1))
      (= (tn (caup (clex "'a' '\\n' '\\''")) 2) (L 'num 39 1))
      (! (clex "'ab'")) (! (clex "'"))                       ; malformed literals refuse
      (= (tn (caup (clex "\"hi\"")) 0) (L 'str "hi" 1))
      (= (tn (caup (clex "\"a\\nb\"")) 0) (L 'str "a\nb" 1))
      (! (clex "\"open"))                                    ; unterminated string refuses
      (! (clex "int @"))                                     ; not C: the lex error rides up
      (! (clex "a /* open"))                                 ; unterminated comment refused
      (= (tn (caup (clex "0x1F")) 0) (L 'num 31 1))         ; 7c-ii: hex literals
      (= (tn (caup (clex "0xFF & 1")) 0) (L 'num 255 1))
      (= (tn (caup (clex "255L")) 0) (L 'num 255 1))        ; an integer suffix is consumed
      (= (tn (caup (clex "100UL")) 0) (L 'num 100 1))
      (= (tn (caup (clex "'\\f'")) 0) (L 'num 12 1))        ; \f form feed, \a bell, \v vtab
      (= (tn (caup (clex "'\\a'")) 0) (L 'num 7 1))
      (= (tn (caup (clex "'\\v'")) 0) (L 'num 11 1))
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
         '(prog ((fn "add" (("a" int) ("b" int)) (blk ((ret (bin + (var "a") (var "b")))))))))
      (= (cast "long f(char c, short s) { return c; }")
         '(prog ((fn "f" (("c" char) ("s" short)) (blk ((ret (var "c"))))))))
      (= (cast "int f(void); int main() { return 0; }")
         '(prog ((proto "f") (fn "main" () (blk ((ret (num 0))))))))
      ; a call's HEAD is an expression now (function pointers) -- (call headexpr args)
      (= (cexp "f(1, 2+3)") '(call (var "f") ((num 1) (bin + (num 2) (num 3)))))
      (= (cexp "f()") '(call (var "f") ()))
      (= (cexp "f(g(1))") '(call (var "f") ((call (var "g") ((num 1))))))
      ; a call through a dereferenced function pointer
      (= (cexp "(*fp)(7)") '(call (deref (var "fp")) ((num 7))))
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
      (= (cexp "*p") '(deref (var "p")))
      (= (cexp "&x") '(addr (var "x")))
      (= (cexp "a[2]") '(deref (bin + (var "a") (num 2))))
      (= (cexp "*p++") '(deref (post (var "p") 1)))
      (= (cexp "sizeof(int*)") '(num 8))
      (= (cexp "(char*)x") '(cast (ptr char) (var "x")))
      (= (cast "int main() { int *p; int a[4]; return 0; }")
         '(prog ((fn "main" () (blk ((decl (("p" (ptr int) ())))
                                     (decl (("a" (arr int 4) ())))
                                     (ret (num 0))))))))
      (= (cast "long g = 5; int main() { return 0; }")
         '(prog ((gdecl (("g" long (num 5))))
                 (fn "main" () (blk ((ret (num 0))))))))
      (two? (cparse (caup (clex "int main() { int *a[3]; return 0; }"))))   ; an array of pointers parses (4d)
      (= (cast "int main() { int x=1; if (x) return 2; return 3; }")
         '(prog ((fn "main" () (blk ((decl (("x" int (num 1))))
                                     (if (var "x") (ret (num 2)) ())
                                     (ret (num 3))))))))
      (= (cast "int main() { char c; long a=1, b; return 0; }")
         '(prog ((fn "main" () (blk ((decl (("c" char ())))
                                     (decl (("a" long (num 1)) ("b" long ())))
                                     (ret (num 0))))))))
      (= (cexp "(char)300") '(cast char (num 300)))
      (= (cexp "(long)(int)x") '(cast long (cast int (var "x"))))
      (= (cexp "sizeof(int)") '(num 4))
      (= (cexp "sizeof(char)+sizeof(short)+sizeof(long)") '(bin + (bin + (num 1) (num 2)) (num 8)))
      (= (cast "int main() { while (1) break; return 0; }")
         '(prog ((fn "main" () (blk ((while (num 1) (brk)) (ret (num 0))))))))
      (! (cparse (caup (clex "int main() { return (1+2; }"))))       ; the lost )
      (! (cparse (caup (clex "int main() { if 1 return 2; }"))))     ; if wants parens
      (! (cparse (caup (clex "int main() { return 42 }"))))
      (! (cparse ()))))

; --- the generator: one full golden, and the refusals that guard the seams ---
(: (cast src) (caup (cparse (caup (clex src))))
   (cgn src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen (caup r) (cauup r) (caup (cuup r))) ()))
   ir (caup (cgn "int main() { return 42; }"))
   (assert
      (= ir '((call main) (mov r6 r0) (li r0 60) (sys)
              (label main) (push r4) (mov r4 sp) (sub sp sp 0)
              (li r0 42) (mov sp r4) (pop r4) (ret)
              (li r0 0) (mov sp r4) (pop r4) (ret)))
      (two? (cgn "int main() { int x=1; while (x<5) x++; return x; }"))
      (! (cgn "int f() { return 1; }"))                      ; no main, no program
      (! (cgn "int main() { return y; }"))                   ; undeclared name
      (! (cgn "int main() { return 5=3; }"))                 ; not an lvalue
      (! (cgn "int main() { break; }"))                      ; no loop to leave
      (two? (cgn "int main() { int a=1; int b=2; return a<<b; }"))  ; variable shifts ride shlv now
      (two? (cgn "int f(int a) { return a; } int main() { return f(1); }"))
      (! (cgn "int main() { return f(1,2,3,4,5,6,7); }"))          ; an unknown callee still refuses (f undeclared) ...
      (two? (cgn "int f(int a,int b,int c,int d,int e,int x,int y) { return y; } int main() { return f(1,2,3,4,5,6,7); }"))   ; ... but args 7+ ride the caller stack now, both sides
      (two? (cgn "int g; int main() { int *p = &g; *p = 3; return g; }"))
      (! (cgn "int main() { int *p; int *q; return (long)(p+q); }"))   ; ptr+ptr refused
      (! (cgn "int main() { int x; return *x; }"))                     ; deref wants a pointer
      (! (cgn "int main() { int a[3]; int b[3]; a = b; return 0; }"))  ; arrays are not assignable
      (two? (cgn "int g = 1+2; int main() { return g; }"))             ; a global init FOLDS to its constant
      (! (cgn "int x; int g = x; int main() { return g; }"))           ; ... but stays refused when genuinely non-constant
      (two? (cgn "char *s = \"hi\"; int main() { return 0; }"))       ; a label-valued global: abs64 (4d)
      (! (cgn "int main() { int a[2] = 5; return 0; }"))))          ; a scalar cannot initialize an array

; --- stage 4a: aggregates -- layout to the C rules, members, the new statements ---
(: (cast src) (caup (cparse (caup (clex src))))
   (cgn src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen (caup r) (cauup r) (caup (cuup r))) ()))
   (cexpp pre e) (: ast (cast (+ pre (+ " int main() { return " (+ e "; }"))))
                    (last l) (? (two? (cup l)) (last (cup l)) (cap l))
                    fn (last (caup ast))
                    items (caup (caup (cuup fn)))
                    (caup (cap items)))
   (assert
      (= (cexpp "struct S { char c; int i; char d; };" "sizeof(struct S)") '(num 12))
      (= (cexpp "struct T { char c; long l; };" "sizeof(struct T)") '(num 16))
      (= (cexpp "struct P { int a; }; struct Q { struct P p; char c; };" "sizeof(struct Q)") '(num 8))
      (= (cexpp "union U { char c; long l; int i; };" "sizeof(union U)") '(num 8))
      (= (cexpp "enum { X=3, Y };" "Y") '(num 4))
      (= (cexpp "enum { X=3, Y };" "X") '(num 3))
      (= (cexpp "typedef long word;" "sizeof(word)") '(num 8))
      (= (cexpp "typedef long word;" "sizeof(word*)") '(num 8))
      (= (cexpp "" "s.v") '(dot (var "s") "v"))
      (= (cexpp "" "p->v") '(dot (deref (var "p")) "v"))
      (= (cexpp "" "p->a.b") '(dot (dot (deref (var "p")) "a") "b"))
      (two? (cgn "struct N { long v; struct N *n; }; int main() { struct N a; a.v = 7; a.n = &a; return a.n->v; }"))
      (two? (cgn "int main() { int x = 2; switch (x) { case 1: return 9; default: return 7; } }"))
      (two? (cgn "int main() { int i = 0; do i++; while (i < 3); return i; }"))
      (two? (cgn "int main() { int i = 0; top: i++; if (i < 3) goto top; return i; }"))
      (! (cgn "struct S { int x; }; int main() { struct S s; return s; }"))                       ; no struct VALUES
      (! (cgn "struct S { int x; }; int main() { struct S s; return s.y; }"))                      ; no such member
      ; --- stage 4b: whole-struct assignment (a block copy) and function pointers ---
      (two? (cgn "struct S { int x; int y; }; int main() { struct S a; struct S b; a.x = 3; a.y = 4; b = a; return b.x + b.y; }"))
      (two? (cgn "struct S { long a; long b; }; int f(struct S *p, struct S *q) { *p = *q; return p->a; } int main() { return 0; }"))
      (two? (cgn "int inc(int x) { return x + 1; } int main() { int (*fp)(int); fp = inc; return fp(41); }"))
      (two? (cgn "int inc(int x) { return x+1; } int main() { int (*fp)(int) = 0; fp = inc; return (*fp)(41); }"))
      ; a dispatch table -- an array of function pointers, THE ai.c pattern
      (two? (cgn "int a(int x){return x+1;} int b(int x){return x*2;} int main(){ int (*t[2])(int); t[0]=a; t[1]=b; return t[0](10)+t[1](10); }"))
      ; --- stage 4c: brace/designated initializers, string inits, [] inference, flexible arrays ---
      (= (cast "int main() { int a[3] = {1,2,3}; return a[0]; }")
         '(prog ((fn "main" () (blk ((decl (("a" (arr int 3) (init ((num 1) (num 2) (num 3)))))) (ret (deref (bin + (var "a") (num 0))))))))))
      (= (cast "struct S { int x; int y; }; int main() { struct S s = {.y=5,.x=2}; return s.x; }")
         '(prog ((tdef) (fn "main" () (blk ((decl (("s" (struct "S") (init ((dfield "y" (num 5)) (dfield "x" (num 2))))))) (ret (dot (var "s") "x"))))))))
      (= (cast "int g[] = {10,20,30}; int main() { return 0; }")   ; [] size inferred from the brace list
         '(prog ((gdecl (("g" (arr int 3) (init ((num 10) (num 20) (num 30)))))) (fn "main" () (blk ((ret (num 0))))))))
      (two? (cparse (caup (clex "struct T { int n; char d[]; }; int main() { return sizeof(struct T); }"))))   ; a flexible array member parses
      (two? (cgn "int main() { int a[4] = {5}; return a[0] + a[3]; }"))            ; partial init zero-fills the rest
      (two? (cgn "struct P { int a; int b; }; int main() { struct P t[2] = {{1,2},{3,4}}; return t[1].a; }"))  ; nested array-of-struct
      (two? (cgn "char b[8] = \"hi\"; int main() { return b[0]; }"))               ; a global char array from a string
      (two? (cgn "int t[3] = {1,2,3}; int main() { return t[2]; }"))               ; a global array constant image
      (two? (cgn "int main() { char s[4] = \"ab\"; return s[0]; }"))               ; a local char array from a string
      ; --- stage 4d: label-valued global images through the abs64 data relocation ---
      (two? (cgn "char *s = \"hi\"; int main() { return 0; }"))                    ; char* -> a rodata string's address
      (two? (cgn "int q = 5; int *p = &q; int main() { return *p; }"))             ; &global
      (two? (cgn "int a[2] = {1,2}; int *p = a; int main() { return p[1]; }"))     ; an array decays to its address
      (two? (cgn "char *m[3] = {\"a\",\"bb\",\"ccc\"}; int main() { return m[0][0]; }"))   ; an array of string pointers
      (two? (cgn "char *m[] = {\"x\",\"y\"}; int main() { return 0; }"))           ; ... with [] size inference
      ; THE ai.c pattern: a static table of (name, function-pointer) records
      (two? (cgn "struct N { char *nm; int (*fn)(int); }; int f(int x){return x;} struct N t[1] = {{\"f\", f}}; int main() { return t[0].fn(9); }"))
      ; a bare TOP-LEVEL function-pointer array still refuses (ptop lays its own declarators; 4e)
      (! (cgn "int a(int x){return x;} int (*t[1])(int) = {a}; int main() { return t[0](3); }"))))

; --- the double lane (stage 6a, the gem): float literals lex, `double` types,
; the xmm value path, int<->double conversions, and the calling convention. ---
(: (cast src) (caup (cparse (caup (clex src))))
   (cgn src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen (caup r) (cauup r) (caup (cuup r))) ()))
   (tn ts k) (? (< k 1) (cap ts) (tn (cup ts) (- k 1)))
   irbits (caup (cgn "int main() { double d = 1.0; return (int)d; }"))
   (has op forms) (: (go l) (? (! (two? l)) () (&& (two? (cap l)) (= (cap (cap l)) op)) 1 (go (cup l))) (go forms))
   (assert
      ; the lexer: a float literal is a 'flo token carrying a gem
      (= (tn (caup (clex "3.5")) 0) (L 'flo 3.5 1))
      (= (tn (caup (clex ".25")) 0) (L 'flo 0.25 1))
      (= (tn (caup (clex "1e3")) 0) (L 'flo 1000.0 1))
      (= (tn (caup (clex "2.")) 0) (L 'flo 2.0 1))
      (= (tn (caup (clex "42")) 0) (L 'num 42 1))          ; an integer stays 'num
      ; the parser: a double type and a 'flo primary
      (= (cast "int main() { double d = 1.5; return 0; }")
         '(prog ((fn "main" () (blk ((decl (("d" double (flo 1.5)))) (ret (num 0))))))))
      ; the 1.0 constant loads its IEEE-754 bits then movqxr into f0
      (has 'movqxr irbits)
      (has 'li irbits)
      ; the value path compiles: locals, arithmetic, mixed int/double, compare, cast
      (two? (cgn "int main() { double a = 1.5; double b = 2.5; return (int)(a + b); }"))
      (two? (cgn "int main() { double a = 3.0; int n = 2; return (int)(a * n); }"))     ; mixed -> double
      (two? (cgn "int main() { double a = 1.0; double b = 2.0; return a < b; }"))       ; compare -> int
      (two? (cgn "int main() { double a = 5.5; return (int)(-a); }"))                   ; unary minus
      (two? (cgn "int main() { double a = 0.0; return !a; }"))                          ; logical not on a double
      (two? (cgn "double g = 2.5; int main() { return (int)g; }"))                      ; a double global image
      (two? (cgn "int main() { double a[2] = {1.5, 2.5}; return (int)(a[0] + a[1]); }")); a double array + element load
      (two? (cgn "struct P { double x; int n; }; int main() { struct P p = {1.5, 2}; return (int)p.x + p.n; }"))
      ; the xmm CALLING convention (6b): double params/returns/args ride f0..f7
      (two? (cgn "int f(double x) { return (int)x; } int main() { return 0; }"))       ; a double parameter
      (two? (cgn "double f() { return 1.5; } int main() { return (int)f(); }"))        ; a double return + read
      (two? (cgn "double add(double a, double b) { return a + b; } int main() { return (int)add(1.5, 2.5); }"))
      (two? (cgn "int f(int x) { return x; } int main() { return f(2.5); }"))          ; a double arg -> an int param converts
      (two? (cgn "int main() { double d = 3.5; return d; }"))                          ; a double value, an int return truncates
      (two? (cgn "int mix(int a, double b, int c) { return a + (int)b + c; } int main() { return mix(1, 2.5, 3); }"))
      (two? (cgn "double add(double a, double b) { return a + b; } int main() { int i = add(2, 3); return i; }"))  ; a double result into an int slot truncates
      (two? (cgn "int main() { int i = 3.5; return i; }"))                             ; a double literal into an int local
      (two? (cgn "int main() { double d = 3.0; int n = 0; while (d) { d = d - 1.0; n++; } return n; }"))  ; a bare double condition (d != 0.0)
      (two? (cgn "int main() { double d = 2.5; return d ? 9 : 4; }"))                  ; a double ternary condition
      (! (cgn "int main() { double a = 1.0; return ~a; }"))))                          ; ~ on a double is still invalid

; --- variadic functions + _Static_assert (stage 6c). the `...` is recorded as
; the signature's variadic flag (cc's simplified all-stack call ABI -- doc/cc.md);
; the three __builtin_va_* forms parse to (vastart|vaend v) / (vaarg v type);
; _Static_assert folds its constant at parse and vanishes to a (tdef) no-op,
; refusing the whole compile when the constant is false. ---
(: (cast src) (caup (cparse (caup (clex src))))
   (csig src name) (: r (cparse (caup (clex src))) (peep (caup (cuup r)) name 'none))
   (cgn src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen (caup r) (cauup r) (caup (cuup r))) ()))
   (assert
      ; the `...` leaves the fn node clean; the variadic bit lives in the signature
      (= (cast "int f(int n, ...) { return n; }")
         '(prog ((fn "f" (("n" int)) (blk ((ret (var "n"))))))))
      (= (csig "int f(int n, ...) { return n; }" "f") '(int (int) 1))    ; rettype, params, variadic=1
      (= (csig "int g(int a, int b) { return a; }" "g") '(int (int int) ()))  ; a fixed fn, variadic=()
      (= (csig "int p(int n, ...);" "p") '(int (int) 1))                 ; a variadic prototype records too
      ; the three va builtins parse to their marker forms
      (= (cast "int f(int n, ...) { char *ap; __builtin_va_start(ap, n); int x = __builtin_va_arg(ap, int); __builtin_va_end(ap); return x; }")
         '(prog ((fn "f" (("n" int)) (blk ((decl (("ap" (ptr char) ())))
                                           (expr (vastart (var "ap")))
                                           (decl (("x" int (vaarg (var "ap") int))))
                                           (expr (vaend (var "ap")))
                                           (ret (var "x"))))))))
      ; _Static_assert folds and vanishes to a (tdef) no-op, at file and block scope
      (= (cast "int main() { _Static_assert(1, \"ok\"); return 0; }")
         '(prog ((fn "main" () (blk ((tdef) (ret (num 0))))))))
      (= (cast "_Static_assert(sizeof(int) == 4, \"w\"); int main() { return 0; }")
         '(prog ((tdef) (fn "main" () (blk ((ret (num 0))))))))
      ; the generator: a variadic fn and a variadic call both compile
      (two? (cgn "int f(int n, ...) { return n; } int main() { return f(1); }"))
      (two? (cgn "int s(int n, ...) { char *ap; __builtin_va_start(ap,n); int t=0; int i=0; while(i<n){ t=t+__builtin_va_arg(ap,int); i++; } __builtin_va_end(ap); return t; } int main() { return s(2, 3, 4); }"))
      ; a parameter of ARRAY type decays to a pointer (the C rule -- so a va_list,
      ; which is an array typedef, rides as a pointer and can be handed on)
      (= (cast "int f(int a[], int n) { return n; }")
         '(prog ((fn "f" (("a" (ptr int)) ("n" int)) (blk ((ret (var "n"))))))))
      (two? (cgn "int sum(int a[], int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i]; return s; } int main() { int x[2]; x[0] = 40; x[1] = 2; return sum(x, 2); }"))
      ; a true _Static_assert compiles; a false one refuses the whole program
      (two? (cgn "int main() { _Static_assert(sizeof(int) == 4, \"w\"); return 0; }"))
      (two? (cgn "_Static_assert(1 + 2 * 3 == 7, \"folds\"); int main() { return 0; }"))
      (! (cgn "int main() { _Static_assert(sizeof(int) == 5, \"bad\"); return 0; }"))
      (! (cgn "_Static_assert(0, \"nope\"); int main() { return 0; }"))))

; --- the `float` scalar + the compound literal (stage 6d). float is 4 bytes in
; memory but shares the double register lane (a load widens, a store narrows);
; sizeof(float) is 4. a compound literal (type){init} parses to ('clit ty init),
; an unnamed object whose ADDRESS is an lvalue. ---
(: (cast src) (caup (cparse (caup (clex src))))
   (cgn src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen (caup r) (cauup r) (caup (cuup r))) ()))
   (cexp src) (: ast (cast (+ "int main() { return " (+ src "; }")))
                 fn (cap (caup ast))
                 items (caup (caup (cuup fn)))
                 (caup (cap items)))
   (assert
      ; float parses as a scalar type; sizeof(float) is 4
      (= (cast "int main() { float f = 1.5; return 0; }")
         '(prog ((fn "main" () (blk ((decl (("f" float (flo 1.5)))) (ret (num 0))))))))
      (= (cexp "sizeof(float)") '(num 4))
      (= (cexp "sizeof(float*)") '(num 8))
      ; a compound literal parses to ('clit ty init), address-takeable
      (= (cexp "(int){7}") '(clit int (init ((num 7)))))
      (= (cexp "&(int){7}") '(addr (clit int (init ((num 7))))))
      ; the generator: the float value path -- locals, arithmetic, compare, the
      ; calling convention, arrays, struct members, and a single-precision global
      (two? (cgn "int main() { float a = 1.5; float b = 2.25; return (int)(a + b); }"))
      (two? (cgn "int main() { float a = 3.0; return a < 5.0; }"))
      (two? (cgn "float sc(float x, float k) { return x * k; } int main() { return (int)sc(2.5, 3.0); }"))
      (two? (cgn "int main() { float a[2] = {1.5, 2.5}; return (int)(a[0] + a[1]); }"))
      (two? (cgn "struct V { float x; int n; }; int main() { struct V v; v.x = 4.5; v.n = 2; return (int)v.x + v.n; }"))
      (two? (cgn "float g = 6.25; int main() { return (int)g; }"))                 ; a float global -> a 4-byte single image
      (! (cgn "int main() { float a = 1.0; return ~a; }"))                          ; ~ on a float is still invalid
      ; the compound literal: a struct one address-taken and read, a scalar one
      (two? (cgn "struct P { int a; int b; }; int f(struct P *p) { return p->a + p->b; } int main() { return f(&(struct P){10, 32}); }"))
      (two? (cgn "int main() { int *p = &(int){42}; return *p; }"))
      (two? (cgn "struct P { int a; int b; }; int main() { return (&(struct P){3, 4})->a; }"))))

; --- the object view (stage 7a): cgen-obj splits the program into TEXT (functions,
; no _start) and DATA (globals + strings), and names the DEFINED functions and
; global variables for the symbol table. crew/holo/obj.l turns that into a
; relocatable .o (the ELF bytes are gated end-to-end by the make .o link/interop
; smoke, which needs the holo book + the system linker). ---
(: (cob src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen-obj (caup r) (cauup r) (caup (cuup r))) ()))
   (el l i) (? (< i 1) (cap l) (el (cup l) (- i 1)))
   ob (cob "int f(int x) { return x; } int g = 5; int main() { return f(g); }")
   (assert
      (two? ob)                                             ; (1 text data funcnames globnames)
      (= (el ob 3) '("f" "main"))                           ; the defined functions -> global FUNC symbols
      (= (el ob 4) '("g"))                                  ; the global variables -> global OBJECT symbols
      (member? '(label f) (el ob 1))                        ; a function label lives in TEXT
      (member? '(label g) (el ob 2))                        ; a global label lives in DATA
      (! (member? '(call main) (el ob 1)))                  ; NO _start/crt0 in an object (the linker's crt calls main)
      (two? (cob "int only(int x) { return x + 1; }"))      ; a LIBRARY TU (no main) still emits an object
      (! (cob "int main() { return nope; }"))))             ; a codegen error still refuses

; --- the preprocessor (stage 5): object/function macros, rescan, hidesets,
; # stringize, ## paste, variadics, and #if/#ifdef conditional const-expr eval.
; pps runs cpp (no includes) and joins the output tokens' spellings to a string. --
(: (spell1 t) (: k (cap t)
                 (? (= k 'str) (+ "\"" (+ (caup t) "\""))
                    (|| (= k 'num) (= k 'kw)) (show (caup t))
                    (caup t)))
   (pps src) (: r (cpp (caup (clex src)) ())
                (? (! (two? r)) 'FAIL
                   (: (go l) (? (! (two? l)) "" (+ (spell1 (cap l)) (+ (? (two? (cup l)) " " "") (go (cup l)))))
                      (go (caup r)))))
   (assert
      (= (pps "#define N 42\nN + 1") "42 + 1")                         ; object macro
      (= (pps "#define A B\n#define B 7\nA") "7")                      ; rescan to fixpoint
      (= (pps "#define ADD(a,b) a+b\nADD(1,2)") "1 + 2")               ; function macro
      (= (pps "#define EOF (-1)\nEOF") "( - 1 )")                      ; 7c-iii: a SPACE before ( = an object macro whose body is parenthesized
      (= (pps "#define M(x, ...) f(x, ##__VA_ARGS__)\nM(a)") "f ( a )")        ; GNU `, ##__VA_ARGS__` elides the comma at zero args
      (= (pps "#define M(x, ...) f(x, ##__VA_ARGS__)\nM(a, b, c)") "f ( a , b , c )")
      (= (pps "#define SQ(x) ((x)*(x))\nSQ(SQ(2))")                    ; nested / re-expansion
         "( ( ( ( 2 ) * ( 2 ) ) ) * ( ( ( 2 ) * ( 2 ) ) ) )")
      (= (pps "#define S(x) #x\nS(a b)") "\"a b\"")                    ; # stringize
      (= (pps "#define C(a,b) a##b\nC(foo,bar)") "foobar")             ; ## paste
      (= (pps "#define P(...) f(__VA_ARGS__)\nP(1,2,3)") "f ( 1 , 2 , 3 )")   ; variadic
      (= (pps "#define F F\nF") "F")                                   ; blue paint: self-ref stops
      (= (pps "#define X\n#ifdef X\ny\n#endif") "y")                   ; #ifdef taken
      (= (pps "#ifndef Z\nn\n#endif") "n")                             ; #ifndef taken
      (= (pps "#if 2+3*4 == 14\nok\n#endif") "ok")                     ; const-expr precedence
      (= (pps "#if 0\na\n#elif 1\nb\n#else\nc\n#endif") "b")           ; #elif chain
      (= (pps "#if (1 << 4) > 10 && !0\ny\n#endif") "y")               ; shift / logical / unary
      (= (pps "#define G 1\n#if defined(G)\nd\n#endif") "d")           ; defined() operator
      (= (pps "#define M(x) x\nno M here") "no M here")                ; a fn macro name not called stays literal
      (! (cpp (caup (clex "#if 1\nx")) ()))                            ; unterminated #if refuses
      (= (pps "#define E\nE + E") "+")))                               ; empty macro body vanishes

; -- 7c-i: freestanding-header surface. cc keeps no linkage/qualifier state, so
; storage/qualifier keywords (static const volatile restrict register inline) and
; __attribute__((..)) are SKIPPED wherever a type may begin or a declarator carry
; them -- the AST equals the unqualified source. an unnamed prototype parameter
; parses as an abstract declarator (the form the system headers' protos use).
(: (cast src) (caup (cparse (caup (clex src))))
   (assert
      (= (cast "static const int x = 5;")  (cast "int x = 5;"))
      (= (cast "int f(int const a, volatile int b){return a;}")
         (cast "int f(int a, int b){return a;}"))
      (= (cast "int g(char * restrict p){return *p;}")
         (cast "int g(char *p){return *p;}"))
      (= (cast "__attribute__((unused)) static int h(void){return 1;}")
         (cast "int h(void){return 1;}"))
      (= (cast "int main(void){register int a=3; const int b=4; return a+b;}")
         (cast "int main(void){int a=3; int b=4; return a+b;}"))
      (= (cast "int f(void const *p){return 0;}")             ; a qual between type and star keeps the pointer
         (cast "int f(void *p){return 0;}"))
      (= (cast "int f(int, long); int main(void){return 0;}") ; unnamed proto params -> abstract declarators
         '(prog ((proto "f") (fn "main" () (blk ((ret (num 0))))))))))

; -- 7c-ii: a type-specifier RUN canonicalizes to one type symbol. the unsigned
; scalars are 'uchar 'ushort 'uint 'ulong (gen: zero-extend loads, logical >>,
; unsigned compare/divide); `signed` folds away, `long long` is 'long.
(: (cast src) (caup (cparse (caup (clex src))))
   (ty1 src)  (cap (caup (cap (caup (cap (caup (cast (+ src " int main(void){return 0;}"))))))))
   (assert
      (= (ty1 "unsigned long g;") 'ulong)
      (= (ty1 "unsigned char b;") 'uchar)
      (= (ty1 "unsigned short h;") 'ushort)
      (= (ty1 "unsigned u;")      'uint)
      (= (ty1 "signed char c;")   'char)     ; signed folds away
      (= (ty1 "long long q;")     'long)     ; long long -> long
      (= (ty1 "int i;")           'int)))

; -- 7c-iii: the C-feature tail cc needs to read ai.c -- function-type typedefs,
; multi-declarator typedefs, sizeof EXPR (a node gen sizes from the type), a bare
; void return, a folded case label, the function-pointer cast type, an incomplete
; array. the object-vs-function macro distinction rides in the cpp section above.
(: (cast src) (caup (cparse (caup (clex src))))
   (cexp src) (: ast (cast (+ "int main() { return " (+ src "; }")))
                 fn (cap (caup ast))
                 items (caup (caup (cuup fn)))
                 (caup (cap items)))
   (assert
      (= (cast "void f(void){return;}") '(prog ((fn "f" () (blk ((ret ())))))))   ; bare void return
      (= (cexp "sizeof x") '(szof (var "x")))                                       ; sizeof EXPR -> a node (not folded)
      (= (cexp "(int (*)(int)) p") '(cast (ptr (fn int)) (var "p")))                ; a function-pointer cast type (return rides)
      (= (cexp "sizeof(int)") '(num 4))                                             ; sizeof TYPE folds to a num literal
      (= (cast "typedef long a, b; int main(void){ b x; return x; }")                ; a multi-declarator typedef binds BOTH names as `long`
         '(prog ((tdef) (fn "main" () (blk ((decl (("x" long ()))) (ret (var "x"))))))))
      (= (cast "typedef int F(int); int main(void){return 0;}") '(prog ((tdef) (fn "main" () (blk ((ret (num 0))))))))
      (= (cast "extern int v[]; int main(void){return 0;}")                         ; an incomplete array: extern DECLARES, no storage
         '(prog ((xdecl (("v" (arr int 0) ()))) (fn "main" () (blk ((ret (num 0))))))))))

; -- 7c-iii part 2: multidimensional arrays. [3][4] of T reads as a RUN of bracket
; suffixes folded outer..inner into (arr (arr T 4) 3); a[i][j] desugars to the plain
; *(*(a+i)+j) -- gen does the type-directed work (the stride on a+i is the ROW size,
; and a deref whose type is still an array keeps the address). a global 2D table takes
; a nested-brace initializer. only the OUTERMOST dim may be [] (size from init).
(: (cast src) (caup (cparse (caup (clex src))))
   (dty src)  (: ast (cast (+ src " int main(void){return 0;}"))    ; the first global decl's type
                 (caup (cap (caup (cap (caup ast))))))
   (assert
      (= (dty "int a[3][4];") '(arr (arr int 4) 3))                 ; row-major nesting, outer dim first
      (= (dty "char m[2][3][4];") '(arr (arr (arr char 4) 3) 2))    ; three dims fold right
      (= (dty "int a[5];") '(arr int 5))                            ; a lone dim is unchanged
      (= (dty "int g[][3] = {{1,2,3},{4,5,6}};") '(arr (arr int 3) 2))   ; outer [] inferred from the init count
      (= (cast "enum q { A, B, KN }; int m[KN][KN]; int main(void){return 0;}")   ; an ENUM CONSTANT dim folds (KN = 2)
         '(prog ((tdef) (gdecl (("m" (arr (arr int 2) 2) ()))) (fn "main" () (blk ((ret (num 0))))))))))

; -- 7c-iii part 3: the last of ai.c's parse tail. a hex FLOAT literal (0x1.0p-53,
; a base-2 exponent after `p`). an array dimension is any integer CONSTANT EXPRESSION
; (2*3, 64/limb_bits) parsed by pexpr + cfold -- subsuming the enum-constant dim. a
; DESIGNATED array initializer `[i]=v` takes a const-expr (enum) index. and BLOCK-SCOPED
; typedef shadowing: a local variable whose name is a typedef (ai.h makes `num`/`word`
; typedefs) hides it for the rest of the block, so `num + num` reads as an expression
; (not a cast) -- restored at block exit so a sibling function still sees the type.
(: (cast src) (caup (cparse (caup (clex src))))
   (cexp src) (: ast (cast (+ "int main() { return " (+ src "; }")))
                 fn (cap (caup ast)) items (caup (caup (cuup fn))) (caup (cap items)))
   (dty src)  (: ast (cast (+ src " int main(void){return 0;}")) (caup (cap (caup (cap (caup ast))))))
   (assert
      (= (cexp "0x1p4") '(flo 16.0))                               ; 0x1p4 = 1 * 2^4
      (= (cexp "0xff") '(num 255))                                 ; a plain hex integer is unchanged
      (= (dty "int m[2 * 3];") '(arr int 6))                       ; a const-EXPRESSION dimension folds
      (= (cast "enum e { A, B, C }; int t[3] = { [A]=10, [C]=30 }; int main(void){return 0;}")   ; designated init, enum index
         '(prog ((tdef) (gdecl (("t" (arr int 3) (init ((didx 0 (num 10)) (didx 2 (num 30))))))) (fn "main" () (blk ((ret (num 0))))))))
      (= (cast "typedef long num; int main(void){ long num = 1; return (int)(num + num); }")   ; a local shadows the `num` typedef
         '(prog ((tdef) (fn "main" () (blk ((decl (("num" long (num 1)))) (ret (cast int (bin + (var "num") (var "num"))))))))))))

; -- block-scoped ENUM-CONSTANT shadowing, the typedef shadow's sibling: a local
; named after an enum constant is a VARIABLE for the rest of the block (not a
; folded number -- which read wrong and refused as an lvalue), and the constant
; comes back at block exit.
(: (cast src) (caup (cparse (caup (clex src))))
   (assert
      (= (cast "enum { K = 5 }; int main(void){ int K = 1; K *= 2; return K; }")
         '(prog ((tdef) (fn "main" () (blk ((decl (("K" int (num 1))))
                                            (expr (asn (var "K") (bin * (var "K") (num 2))))
                                            (ret (var "K"))))))))
      (= (cast "enum { K = 5 }; int f(void){ { int K = 1; } return K; }")   ; restored at `}`
         '(prog ((tdef) (fn "f" () (blk ((blk ((decl (("K" int (num 1))))))
                                         (ret (num 5))))))))))

; -- struct layout: a multi-declarator member line lays its names IN ORDER
; (`double re, im;` is re at 0, im at 8 -- a double rev once flipped it, an ABI
; break against gcc that only bit multi-declarator lines). and the by-value
; struct rep: a two-double struct (SysV: two SSE eightbytes) rides calls as an
; xmm pair -- returned, passed, copied; any OTHER by-value struct still refuses.
(: (cgn src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen (caup r) (cauup r) (caup (cuup r))) ()))
   (stg src) (: r (cparse (caup (clex src))) (peep (cauup r) "S" ()))
   (assert
      (= (stg "struct S { double re, im; }; int main(){return 0;}")
         '((("re" 0 double) ("im" 8 double)) 16 8))
      (= (stg "struct S { char a, b; int c, d; }; int main(){return 0;}")
         '((("a" 0 char) ("b" 1 char) ("c" 4 int) ("d" 8 int)) 12 4))
      (two? (cgn "struct S { double re, im; }; static struct S mk(double a, double b){ struct S z = {a,b}; return z; } static double re(struct S z){ return z.re; } int main(){ return (int)re(mk(41.0, 1.0)) + 1; }"))
      (! (cgn "struct T { int x, y, z; } t; struct T id(struct T a); int main(){ return id(t).x; }"))))   ; a non-sse2 by-value struct still refuses

; -- the gen tail: every name a comma-list prototype registers is callable (the
; sig sweep pins mproto siblings, which have no proto form of their own), and &f
; is a function's address exactly like the bare use -- as a value in code and as
; a label in a global image. an undeclared &name still refuses.
(: (cgn src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen (caup r) (cauup r) (caup (cuup r))) ()))
   (assert
      (two? (cgn "int one(int), two(int); int one(int x){return x+1;} int two(int x){return x+2;} int main(){return one(1)+two(2);}"))
      (two? (cgn "int one(int), two(int); int one(int x){return x+1;} int main(){ int (*p)(int) = two; return p != 0; }"))
      (two? (cgn "int f(int x){return x;} int main(){ int (*p)(int) = &f; return p(1); }"))
      (two? (cgn "int f(int x){return x;} typedef int (*fp)(int); fp t[1] = { &f }; int main(){ return t[0](1); }"))
      (! (cgn "int main(){ return (long)&nope; }"))))

(say err "crew/cc/law: lexer (kinds/lines/munch) + parser (precedence/desugar/shapes + refusals) + gen (golden + seams) + aggregates (layout/members/switch) + cpp (macros/rescan/hidesets/stringize/paste/variadic/conditionals) + doubles (float literals/xmm value path/conversions/the calling convention) + varargs & _Static_assert (the ... signature bit / va builtins / SysV register save area / array-param decay / const-fold-or-refuse) + float (4-byte scalar, widen/narrow, single-precision globals) & compound literals + objects (text/data split, symbols, no crt0) + freestanding headers (ignored quals/attributes, unnamed proto params) + unsigned & hex (hex/suffix/escape lexing, the specifier-soup canonicalizer, logical >>/unsigned compare/divide) + the C tail (object-vs-function macros, GNU `,##__VA_ARGS__`, function-type/multi-declarator typedefs, sizeof EXPR vs TYPE, bare void return, folded case labels, function-pointer cast types, incomplete arrays, multidimensional arrays with const-expr/enum dims, hex float literals, designated array initializers, block-scoped typedef shadowing) + the gen tail (mproto siblings pinned, &f a function's address in code and images) ok")
(put err 10)
