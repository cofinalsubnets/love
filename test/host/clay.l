; test/host/clay.l -- clay authoring C: the forms a generator writes and cparse never emits,
; held to the text a human meant (test/gate/clay.l covers the round trip). run: cat test/00-init.l test/host/clay.l | out/love

(borrow "src/apps/moon/clay.l")

(: cs (cite 'clay 'clay-show)
   cok (cite 'clay 'clay-ok?)
   (one c) (cs c)                      ; a single top-level item, no (prog ..) wrapper
   (gripe? x) (two? x && <x = 'gripe))

; --- types: base and declarator apart, as a C declaration brackets its own name
(test
 (one '(gdecl (("x" int (num 5)))) = "int x = 5;\n")
 (one '(gdecl (("p" (ptr char) ()))) = "char *p;\n")
 (one '(gdecl (("t" (arr (ptr char) 2) ()))) = "char *t[2];\n")
 (one '(gdecl (("m" (arr (arr int 2) 3) ()))) = "int m[3][2];\n")
 ; a pointer to an array and an array of pointers differ by exactly the parens
 (one '(gdecl (("q" (ptr (arr int 3)) ()))) = "int (*q)[3];\n")
 (one '(gdecl (("f" (ptr (fn int)) ()))) = "int (*f)();\n")
 ; an unsigned scalar is one symbol at parse; the spelling comes back
 (one '(gdecl (("u" ulong ()))) = "unsigned long u;\n")
 ; an unsized bound is the flexible member
 (one '(gdecl (("v" (arr char 0) ()))) = "char v[];\n"))

; --- const binds to the declarator over a pointer and to the base otherwise
(test
 (one '(gdecl (("a" (const int) (num 1)))) = "int const a = 1;\n")
 (one '(gdecl (("b" (const (ptr char)) ()))) = "char *const b;\n")
 (one '(gdecl (("t" (const (named "size_t")) ()))) = "size_t const t;\n")
 (one '(gdecl (("mx" (arr (arr (const (ptr (named "lvm_t"))) KN) KN) ())) (static))
  = "static lvm_t *const mx[KN][KN];\n"))

; --- a symbolic bound and designated index, which cparse folds to numbers
(: cl-di '(gdecl (("v" (arr int 2) (init ((didx KMint (var "lvm_0")) (didx KNom (var "lvm_1")))))))
   cl-df '(gdecl (("s" (named "S") (init ((dfield "x" (num 1)) (num 2))))))
   (test
    (one '(gdecl (("v" (arr int KN) ()))) = "int v[KN];\n")
    (one cl-di = "int v[2] = { [KMint] = lvm_0, [KNom] = lvm_1 };\n")
    (one cl-df = "S s = { .x = 1, 2 };\n")))

; --- the return type is `fn`'s 4th slot; cparse never fills it, so it prints `int`
(test
 (one '(fn "f" (("a" int)) (blk ((ret (var "a"))))) = "int f(int a) {\n return a; }\n")
 (one '(fn "g" () (blk ((ret ()))) void) = "void g(void) {\n return; }\n"))

; --- a note is emit-only: one `//` per line
(test
 (one '(note "the lane table") = "// the lane table\n")
 ((one '(note "two lines
here")) = "// two lines\n// here\n"))

; --- a real typedef, the form cparse cannot emit
(: cl-vas '(prog ((fn "f" () (blk ((expr (vastart (var "ap"))))))))
   cl-inf ['gdecl [["d" 'double ['flo (1.0 / 0.0)]]]]
   (test
    (one '(tdef "lvm_t" (fn void)) = "typedef void lvm_t();\n")
    ; ...while cparse's empty marker refuses, as does va_start's lost parameter
    (gripe? (one '(tdef)))
    (gripe? (one cl-vas))
    ; C has no literal for an infinity, so it is not sayable
    (gripe? (one cl-inf))))

; --- a struct or union definition, the other form cparse cannot emit
; fields are ((name ty)..); a 3rd slot 'union changes only the keyword; a union is still ('struct tag)
(: cl-sd '(sdef "P" (("x" int) ("next" (ptr (struct "P"))) ("row" (arr (named "lvm_t") KN))))
   cl-un '(sdef "pun" (("d" double) ("u" ullong)) union)
   (test
    (one cl-sd = "struct P {\n int x;\n struct P *next;\n lvm_t row[KN];\n};\n")
    (one cl-un = "union pun {\n double d;\n unsigned long long u;\n};\n")))

; --- define the shape, name it, use it; a named tag is sayable without its definition
(: cl-tds '(prog ((sdef "P" (("x" int))) (tdef "P" (struct "P")) (gdecl (("v" (struct "P") ())))))
   (test
    (one cl-tds = "struct P {\n int x;\n};\ntypedef struct P P;\nstruct P v;\n")
    (one '(gdecl (("p" (ptr (struct "S")) ()))) = "struct S *p;\n")
    ; an anonymous tag is unsayable: parse mints it as ".anon0"
    (gripe? (one '(sdef ".anon0" (("x" int)))))
    (gripe? (one '(gdecl (("v" (ptr (struct ".anon0")) ())))))
    ; C has no empty struct, the same way it has no empty enum
    (gripe? (one '(sdef "E" ())))))

; --- attributes ride fn's 5th slot as spellings ("love_noinline", not its expansion);
; emit-only, as parse.l skips a trailing attribute run
(test
 ((one '(fn "love_sleep" (("ticks" (named "uintptr_t"))) (blk ((ret ()))) void
            ("__attribute__((weak))" "love_noinline")))
  = "__attribute__((weak)) love_noinline void love_sleep(uintptr_t ticks) {\n return; }\n")
 ; restrict binds to the declarator, the shape every lvm_ parameter wears
 (one '(gdecl (("g" (restrict (ptr (struct "g"))) ()))) = "struct g *restrict g;\n")
 ; ...and qualifies only a pointer
 (gripe? (one '(gdecl (("x" (restrict int) ())))))
 ; the ret prefix, for love.h's tail calls
 (one '(fn "f" () (blk ((ret (call (var "Continue") ()) love_musttail))))
  = "int f(void) {\n love_musttail return Continue(); }\n")
 ; _Static_assert, which cparse reduces to the bare (tdef) marker
 (one '(sassert (bin eq (bin shr (un neg (num 1)) (num 1)) (un neg (num 1))) "sign extended shift")
  = "_Static_assert(-1 >> 1 == -1, \"sign extended shift\");\n")
 ; (arr t 0) is the flexible member inside an sdef too
 (one '(sdef "blob" (("n" (named "uintptr_t")) ("bytes" (arr char 0))))
  = "struct blob {\n uintptr_t n;\n char bytes[];\n};\n")
 ; the wide scalar needs no node: (named ..) says it
 (one '(gdecl (("w" (named "unsigned __int128") ()))) = "unsigned __int128 w;\n"))

; --- all of them at once: an lvm_ definition, whole
(: cl-lvm '(fn "lvm_add"
            (("g" (restrict (ptr (struct "g")))) ("Ip" (ptr (named "union u")))
             ("Hp" (ptr (named "word"))) ("Sp" (restrict (ptr (named "word")))))
            (blk ((ret (call (var "Continue") ()) "love_musttail")))
            (ptr (struct "g"))
            ("love_noinline" "noicf"))
   (test
    (one cl-lvm
     = "love_noinline noicf struct g *lvm_add(struct g *restrict g, union u *Ip, word *Hp, word *restrict Sp) {\n love_musttail return Continue(); }\n")))

; --- the preprocessor, emit-only; an expression body renders at the tightest context,
; so it parenthesizes itself
(test
 (one '(cpp-def "data_n" 9) = "#define data_n 9\n")
 (one '(cpp-def "countof(_)" (bin / (szof (var "_")) (szof (deref (var "_")))))
  = "#define countof(_) (sizeof(_) / sizeof(*_))\n")
 ; ...and a spelling body rides through as is
 (one '(cpp-def "noicf" "__attribute__((noipa))") = "#define noicf __attribute__((noipa))\n")
 ; no body slot is a bare #define
 (one '(cpp-def "FLAG") = "#define FLAG\n")
 (one '(cpp-undef "FLAG") = "#undef FLAG\n")
 ; a macro name must be an identifier
 (gripe? (one '(cpp-def "9bad" 1)))
 (gripe? (one '(cpp-undef "(x)"))))

; --- #if / #elif / #else, over top-level items
; arms are ((cond items)..), the else its own slot; `defined` is a plain call
(: cl-def (n \ ['call ['var "defined"] [['var n]]])
   cl-if ['cpp-if [[['lor (cl-def "__x86_64__") (cl-def "__aarch64__")]
                     [['cpp-def "data_stride" 16]]]]
                  [['cpp-def "data_stride" 128]]]
   ; a guard with a conditional nested inside it, every directive at column 0
   cl-nest ['cpp-if [[['un 'not (cl-def "data_stride")]
                       [cl-if]]]]
   (test
    (one cl-if = "#if defined(__x86_64__) || defined(__aarch64__)\n#define data_stride 16\n#else\n#define data_stride 128\n#endif\n")
    (one cl-nest = "#if !defined(data_stride)\n#if defined(__x86_64__) || defined(__aarch64__)\n#define data_stride 16\n#else\n#define data_stride 128\n#endif\n#endif\n")
    ; an #elif arm, and an arm's body carrying more than a directive
    (one '(cpp-if (((var "A") ((note "a"))) ((var "B") ((note "b")))) ((note "c")))
     = "#if A\n// a\n#elif B\n// b\n#else\n// c\n#endif\n")
    ; no arms is a syntax error
    (gripe? (one '(cpp-if ())))
    ; a refusal inside an arm comes out as a gripe, not concatenated into the text
    (gripe? (one '(cpp-if ((1 ((tdef)))))))
    (gripe? (one '(cpp-if ((1 ((blk ())))))))))

; --- a prototype with a real signature: its slots mirror `fn`'s, one `csig` lays both
(test
 (one '(proto "shash") = "int shash();\n")
 ((one '(proto "shash" (("g" (ptr (struct "g"))) ("x" (named "word"))
                        ("env" (ptr (struct "arib")))) (named "uintptr_t") ("static")))
  = "static uintptr_t shash(struct g *g, word x, struct arib *env);\n")
 ; the appended slots are independent: params alone, then params and a return type
 (one '(proto "f" (("a" int))) = "int f(int a);\n")
 (one '(proto "g" () void) = "void g(void);\n"))

; --- an enum constant may name its own value, and the enum may carry no tag
(test
 (one '(edef "q" (KMint KNom KChain)) = "enum q { KMint, KNom, KChain };\n")
 (one '(edef () ((nf_maxcap (num 64)))) = "enum { nf_maxcap = 64 };\n")
 (one '(edef "e" (a (b (num 8)) c)) = "enum e { a, b = 8, c };\n")
 ; C has no empty enum, tagged or not
 (gripe? (one '(edef "e" ())))
 (gripe? (one '(edef () ()))))

; --- a member of an indexed thing
; `k[0].ap` and `(k + 0)->ap` are one tree; clay spells the first
(: (ex x) (cs ['gdecl [["r" 'int x]]])
   (test
    (ex '(dot (deref (bin + (var "k") (num 0))) "ap") = "int r = k[0].ap;\n")
    (ex '(dot (deref (bin + (var "u") (num 2))) "m") = "int r = u[2].m;\n")
    ; an index is an expression context, so a negative literal spells there
    (ex '(dot (deref (bin + (var "k") (un neg (num 1)))) "x") = "int r = k[-1].x;\n")
    ; ...while a plain deref keeps its arrow, and the two compose in either order
    (ex '(dot (deref (var "p")) "f") = "int r = p->f;\n")
    (ex '(deref (bin + (dot (deref (var "p")) "row") (var "i"))) = "int r = p->row[i];\n")
    (ex '(addr (dot (deref (bin + (var "k") (num 1))) "x")) = "int r = &k[1].x;\n")))

; --- `for (;;)`, C's own spelling of forever
(test
 (one '(fn "f" () (blk ((for () () () (blk ((brk)))))) void) = "void f(void) {\n for (;;) {\n  break; } }\n")
 (one '(fn "g" () (blk ((for () (var "c") () (brk)))) void) = "void g(void) {\n for (; c; ) break; }\n"))

; --- the tree's braces: a closer ends its block's last line, an else starts its own, and a bare body
;     joins its header's line. a block keeps its braces, so the text parses back to the same tree
(: (f b) (one ['fn "f" () ['blk b] 'void])
 (test
  (f '((if (var "c") (blk ((expr (var "p")) (expr (var "q")))) (expr (var "r")))))
   = "void f(void) {\n if (c) {\n  p;\n  q; }\n else r; }\n"
  (f '((if (var "c") (blk ((expr (var "p")))) (if (var "d") (expr (var "q")) (blk ())))))
   = "void f(void) {\n if (c) {\n  p; }\n else if (d) q;\n else { } }\n"
  ; a bare if before an else would take it, so it is braced
  (f '((if (var "a") (if (var "b") (expr (var "x"))) (expr (var "y")))))
   = "void f(void) {\n if (a) {\n  if (b) x; }\n else y; }\n"
  ; a closer never ends a note or a label
  (f '((while (var "c") (blk ((note "n") (expr (var "x")) (note "m"))))))
   = "void f(void) {\n while (c) {\n  // n\n  x;\n  // m\n } }\n"
  (f '((expr (var "x")) (lbl "out")))
   = "void f(void) {\n x;\nout:\n}\n"
  (f '((do (blk ((expr (var "x")))) (var "c"))))
   = "void f(void) {\n do {\n  x; } while (c); }\n"))

; --- clay-ok? is a shape check, because gen.l trusts its input
(test
 (1 = cok '(bin + (num 1) (num 2)))
 (gripe? (cok '(bin + (num 1))))                  ; bin takes three
 (gripe? (cok '(nosuchtag 1)))
 (gripe? (cok '(blk ((ret (num 1) x y)))))        ; ret takes at most two: value + prefix
 ; the check reaches inside a declarator list
 (gripe? (cok '(gdecl (("x" int (bin + (num 1)))))))
 ; the ATTRS slot holds spellings, not nodes
 (1 = cok '(fn "f" () (blk ((ret (num 1) love_musttail))) void (love_noinline noicf)))
 (1 = cok '(sassert (bin eq (num 1) (num 1)) "m"))
 (gripe? (cok '(sassert (num 1))))                 ; wants the message
 ; a proto's ATTRS slot holds spellings too, and its params and return type are walked
 (1 = cok '(proto "f" (("a" int)) void (static)))
 (gripe? (cok '(proto "f" (("a" (bin + (num 1)))))))
 (gripe? (cok '(proto)))                           ; wants a name
 ; a cpp arm's condition and its body are both walked, three list levels down
 (1 = cok '(cpp-if (((var "A") ((cpp-def "X" 1))))))
 (gripe? (cok '(cpp-if (((var "A") ((bin + (num 1))))))))
 (gripe? (cok '(cpp-def))))                        ; wants a name

; --- precedence: the shower parenthesizes only where the table says
(: (e x) (cs ['gdecl [["r" 'int x]]])
   (test
    (e '(bin * (bin + (var "a") (var "b")) (var "c")) = "int r = (a + b) * c;\n")
    (e '(bin + (bin * (var "a") (var "b")) (var "c")) = "int r = a * b + c;\n")
    ; - is left associative: a - (b - c) needs the parens back
    (e '(bin - (var "a") (bin - (var "b") (var "c"))) = "int r = a - (b - c);\n")
    (e '(bin - (bin - (var "a") (var "b")) (var "c")) = "int r = a - b - c;\n")
    ; shifts bind tighter than the comparisons; arithmetic under a shift keeps its parens, as cc asks
    (e '(bin shl (bin + (var "a") (var "b")) (num 1)) = "int r = (a + b) << 1;\n")
    (e '(bin eq (bin shr (var "a") (num 3)) (num 0)) = "int r = a >> 3 == 0;\n")
    ; ?: is right-associative and binds looser than ||
    (e '(cond (lor (var "a") (var "b")) (num 1) (cond (var "c") (num 2) (num 3)))
     = "int r = a || b ? 1 : c ? 2 : 3;\n")
    ; - applied to a negation needs a space, or the lexer reads a predecrement
    (e '(un neg (un neg (var "a"))) = "int r = - -a;\n")
    ; a[i] is (deref (bin + a i)), and the sugar comes back
    (e '(deref (bin + (var "a") (num 2))) = "int r = a[2];\n")
    ; x->f is (dot (deref x) f)
    (e '(dot (deref (var "p")) "f") = "int r = p->f;\n")))

; --- strings: the escapes C needs, and an octal fallback for the rest
(['gdecl [["s" '(ptr char) ['str ("a" + string 10 + "\"b\\" + string 1)]]]] @ cl-str
   (test
    (one cl-str = "char *s = \"a\\n\\\"b\\\\\\001\";\n")))

; --- a character literal, emit-only (cparse folds it to a number); the quotes swap roles
(: (ec x) (cs ['gdecl [["r" 'int x]]])
   (test
    (ec '(chr 92) = "int r = '\\\\';\n")
    (ec '(chr 39) = "int r = '\\'';\n")
    (ec '(chr 34) = "int r = '\"';\n")
    (ec '(chr 10) = "int r = '\\n';\n")
    (ec '(chr 65) = "int r = 'A';\n")
    (ec '(chr 1) = "int r = '\\001';\n")
    (ec '(bin eq (deref (bin + (dot (deref (var "n")) "bytes") (num 0))) (chr 92))
     = "int r = n->bytes[0] == '\\\\';\n")))

(test_fin ())
(puts "clay: ok")
(putc 10)
