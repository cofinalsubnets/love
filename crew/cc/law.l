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
      (= (tn (caup (clex "'a' '\\n' '\\''")) 0) (L 'num 97 1))   ; char literals are numbers
      (= (tn (caup (clex "'a' '\\n' '\\''")) 1) (L 'num 10 1))
      (= (tn (caup (clex "'a' '\\n' '\\''")) 2) (L 'num 39 1))
      (! (clex "'ab'")) (! (clex "'"))                       ; malformed literals refuse
      (= (tn (caup (clex "\"hi\"")) 0) (L 'str "hi" 1))
      (= (tn (caup (clex "\"a\\nb\"")) 0) (L 'str "a\nb" 1))
      (! (clex "\"open"))                                    ; unterminated string refuses
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
                (? (two? r) (cgen (caup r) (cauup r)) ()))
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
      (! (cgn "int main() { return f(1,2,3,4,5,6,7); }"))          ; the six-register fence ...
      (! (cgn "int f(int a,int b,int c,int d,int e,int x,int y) { return 1; } int main() { return 1; }"))   ; ... both sides of it
      (two? (cgn "int g; int main() { int *p = &g; *p = 3; return g; }"))
      (! (cgn "int main() { int *p; int *q; return (long)(p+q); }"))   ; ptr+ptr refused
      (! (cgn "int main() { int x; return *x; }"))                     ; deref wants a pointer
      (! (cgn "int main() { int a[3]; int b[3]; a = b; return 0; }"))  ; arrays are not assignable
      (! (cgn "int g = 1+2; int main() { return g; }"))                ; a global init is a folded constant, not an expression
      (two? (cgn "char *s = \"hi\"; int main() { return 0; }"))       ; a label-valued global: abs64 (4d)
      (! (cgn "int main() { int a[2] = 5; return 0; }"))))          ; a scalar cannot initialize an array

; --- stage 4a: aggregates -- layout to the C rules, members, the new statements ---
(: (cast src) (caup (cparse (caup (clex src))))
   (cgn src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen (caup r) (cauup r)) ()))
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
; the xmm value path, int<->double conversions, and the 6b fences refuse. ---
(: (cast src) (caup (cparse (caup (clex src))))
   (cgn src) (: r (cparse (caup (clex src)))
                (? (two? r) (cgen (caup r) (cauup r)) ()))
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
      ; the 6b fences refuse (double params/returns/args need the xmm ABI)
      (! (cgn "int f(double x) { return 1; } int main() { return 0; }"))               ; a double parameter
      (! (cgn "double f() { return 1.5; } int main() { return 0; }"))                  ; a double return
      (! (cgn "int f(int x) { return x; } int main() { return f(2.5); }"))             ; a double call argument
      (! (cgn "int main() { double d = 3.5; return d; }"))                             ; a bare double return (needs (int))
      (! (cgn "int main() { double a = 1.0; return ~a; }"))))                          ; ~ on a double is invalid

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

(say err "crew/cc/law: lexer (kinds/lines/munch) + parser (precedence/desugar/shapes + refusals) + gen (golden + seams) + aggregates (layout/members/switch) + cpp (macros/rescan/hidesets/stringize/paste/variadic/conditionals) + doubles (float literals/xmm value path/conversions/6b fences) ok")
(put err 10)
