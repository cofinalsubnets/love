; src/apps/moon/clay.l -- clay: C as love data, with a validator and a shower, so C can be
; generated from a love table. standalone: (borrow "src/apps/moon/clay.l"), then clay-show /
; clay-ok? / clay-tags. a superset of cparse's AST: slots for what cparse drops, always appended,
; so clay stays acceptable to cgen-obj:
;   (fn name params body RET ATTRS)    return type (absent = int), attribute spellings
;   (proto name PARAMS RET ATTRS)      the same on a forward declaration
;   (ret e PRE)                        a prefix spelling: `love_musttail return ..`
;   (gdecl decls STOR)                 (static) / (extern) / ()
;   (restrict t) (named "lvm_t") (const t)   type forms
;   (sassert e "msg") (tdef NAME TY) (sdef TAG FIELDS)   what cparse reduces to (tdef)
;   (arr t EXPR) (didx EXPR val)       symbolic bounds and indices
;   (chr 92) (note "text")             a char literal, a comment
;   (cpp-def NAME [BODY])              NAME may carry its params ("countof(_)"); no body: bare #define
;   (cpp-undef NAME) (cpp-if ARMS [ELSE])   arms ((cond items)..), first `#if`, rest `#elif`
; a lossy cparse form shows as the best C it justifies; a bare (tdef) refuses.
; a #define body that is a clay expression parenthesizes itself.
; `#ifdef X` is (call (var "defined") ((var "X"))).
(:
   ; --- the small vocabulary, here so clay loads without moon ---
   join (foldl (+) "")
   (sepby s l) (l @ (a . u) (foldl (a \ x \ a + s + x) a u) "")
   nl (string 10)
   (gripe msg) ['gripe () () () msg]
   (gripe? ('gripe . _)) 1
   ; look answers a row's first value; lookr the whole tail, for an arity range
   (look tbl k d) (: (go l) (atom? l ? d (<l @ e (<e == k ? <>e (go >l)))) (go tbl))
   (lookr tbl k) (: (go l) (two? l ? (<l @ e (<e == k ? >e (go >l)))) (go tbl))

   ; --- the node grammar: (tag lo hi), the operand counts clay-ok? admits, hi -1 any.
   clay-tags
    ; fn is both a definition and (fn ret [ptys]), a function type, so its range is loose.
    ; sdef's fields are ((name ty)..), its 3rd slot 'union; a union refers as ('struct tag)
    '((prog 1 1) (fn 1 5) (proto 1 4) (gdecl 1 2) (xdecl 1 2) (tdef 0 2) (note 1 1) (tasm 1 1)
      (edef 2 2) (sdef 2 3) (sassert 2 2) (cpp-def 1 2) (cpp-undef 1 1) (cpp-if 1 2)
      (blk 1 1) (decl 1 1) (sdecl 1 1) (ret 1 2) (if 2 3) (while 2 2) (for 4 4)
      (do 2 2) (switch 2 2) (case 1 2) (dflt 0 0) (brk 0 0) (cont 0 0) (goto 1 1) (igoto 1 1)
      (lbl 1 1) (expr 1 1) (nop 0 0) (asm 5 6)
      (num 1 1) (flo 1 1) (str 1 1) (chr 1 1) (var 1 1) (bin 3 3) (un 2 2) (asn 2 2)
      ; ('rmw op lv rhs): `lv op= rhs` kept whole, so lv evaluates once
      (rmw 3 3)
      (post 2 2) (cond 3 3) (comma 2 2) (call 2 2) (deref 1 1) (addr 1 1) (laddr 1 1)
      (dot 2 2) (cast 2 2) (szof 1 1) (bcp 1 1) (init 1 1) (dfield 2 2) (didx 2 2)
      (clit 2 2) (land 2 2) (lor 2 2) (vastart 1 2) (vaarg 2 2) (vaend 1 1)
      ; ('sexpr items value ty): gcc's ({ .. })
      (sexpr 3 3)
      ; type forms. ('varr elt dim [idx]): idx is gen's VLA slot, unshown
      (ptr 1 1) (arr 2 2) (varr 2 3) (struct 1 1) (named 1 1) (const 1 1) (restrict 1 1))

   ; --- clay-ok?: 1 or a gripe naming the first offender. a shape check, not a type check
   (clay-ok? c)
    (:- (go c || 1)
     (bad m) (gripe "clay: \(m)")
     (go x)
      (? (atom? x) ()                             ; a leaf: a name, a number, a string
         !(name? <x) (bad "a form whose head is not a tag")
         (: h <x n #>x r (lookr clay-tags h)
            (? (atom? r) (bad "unknown tag \(h)")
               (n < <r) (bad "\(h) wants at least \(<r) operands")
               (-1 < <>r < n) (bad "\(h) takes at most \(<>r) operands")
               ; skip slots of keywords or spellings, whose heads would read as tags
               (: (kids (e . l))
                   (two? e ? ((name? <e ? (go e) (kids e)) || kids l)
                             (kids l))
                  (kids (h @ ('gdecl || 'xdecl) [<>x]
                             'edef ()
                             ; ('fn ret ptys), a type: a definition has a name at slot 1
                             ('fn && !(string? (x 1))) (. (x 1) (x 2))
                             ('fn && 4 < n) [(x 2) (x 3) (x 4)]
                             ('proto && 3 < n) [(x 2) (x 3)]
                             >x)))))))

   ; --- types: cty-base peels to the innermost specifier, cty-dtor grows the declarator
   ; around the name; p = built so far is a pointer, so a suffix parenthesizes (`int (*fp)()`)
   spelling '((uchar "unsigned char") (schar "signed char") (cchar "char") (ushort "unsigned short") (uint "unsigned int")
              (ulong "unsigned long") (ullong "unsigned long long") (llong "long long")
              (i128 "__int128") (u128 "unsigned __int128") (bool "_Bool"))
   (cptr? ('ptr . _)) 1
   ; cident? checks the first char only: parse's synthetic tags all lead with a dot
   ctag string
   (cident? a) (: c (ctag a @ "" 0 s (s 0)) (96 < c < 123 || 64 < c < 91 || c = 95))
   (cty-base t)
    (name? t ? (look spelling t (string t))
     (t @ (h . a . _)
      (h @ 'ptr (cty-base a)
           'arr (cty-base a)
           'fn (cty-base a)
           'named a
           'struct "struct \(ctag a)"
           ; const on a pointer goes in the declarator (`*const`), else on the base
           'const (cptr? a ? (cty-base a) "\(cty-base a) const")
           'restrict (cty-base a)
           "int")
      "int"))
   (cty-dtor t s p)
    (t @- s (h . a . u)
     (h @- s 'ptr (cty-dtor a "*\(s)" 1)
          'const (cptr? a ? (cty-dtor <>a "*const \(s)" 1) (cty-dtor a s p))
          'restrict (cptr? a ? (cty-dtor <>a "*restrict \(s)" 1) (cty-dtor a s p))
          'arr (cty-dtor a "\(p ? "(\(s))" s)[\(cdim <u)]" 0)
          'varr (cty-dtor a "\(p ? "(\(s))" s)[\(ce <u 0)]" 0)
          'fn (cty-dtor a "\(p ? "(\(s))" s)\(cptys <u)" 0)))
   ; an array bound: a charm, 0 for `[]`, else a clay expression
   (cdim n) (charm? n ? (n @ 0 "" (show n)) (ce n 0))
   ; a function type's param types; none is C's unspecified `()`
   (cptys l) (two? l ? "(\(sepby ", " (map (t \ cty t "") l)))" "()")
   ; a full declaration around s; s empty is a cast's abstract declarator
   (cty t s) (: d (cty-dtor t s 0) b (cty-base t) (d @ "" b "\(b) \(d)"))

   ; --- literals. a negative (num n) has no C spelling: `-1` is unary minus on 1
   (cnum n) (show n)                            ; a function, for cnested?'s reason below
   ; a float must look like one to C: `7` owes `.0`, `1e308` doesn't. no literal for infinity
   (cfinite? x) (show x @ s
                   !(any (i \ !(elem (s i) '(46 69 101 43 45 48 49 50 51 52 53 54 55 56 57)))
                         ^#s))
   (cflo x) (: s (show x) b (map s ^#s)
             (elem 46 b || elem 101 b || elem 69 b ? s "\(s).0"))
   (oct3 b) "\(string (48 + b // 64 % 8))\(string (48 + b // 8 % 8))\(string (48 + b % 8))"
   (cesc b) (b @ 34 "\\\"" 92 "\\\\" 10 "\\n" 9 "\\t" 13 "\\r"
             (31 < b < 127 ? (string b) "\\\(oct3 b)"))
   (cstrlit s) "\"\(join (map (cesc * s) ^#s))\""
   ; a character literal, emit-only
   (cchr b) "'\(b @ 39 "\\'"  34 "\"" (cesc b))'"

   ; --- expressions, precedence-aware rather than fully parenthesized
   binprec '((* 80) (/ 80) (% 80) (+ 75) (- 75) (shl 70) (shr 70)
             (lt 65) (gt 65) (le 65) (ge 65) (eq 60) (ne 60)
             (& 55) (^ 50) (| 45))
   binop '((* "*") (/ "/") (% "%") (+ "+") (- "-") (shl "<<") (shr ">>")
           (lt "<") (gt ">") (le "<=") (ge ">=") (eq "==") (ne "!=")
           (& "&") (^ "^") (| "|"))
   unop '((neg "-") (not "!") (bnot "~"))
   ; `a[i]` is (deref (bin + a i)) and binds as a postfix
   (cidx? ('deref . ('bin . '+ . _) . _)) 1
              
   (cprec e)
    (atom? e ? 100
     (<e @ 'bin (look binprec <>e 100)
           'land 40 'lor 35 'cond 30
           'asn 25 'rmw 25 'comma 20
           'un 90 'deref (cidx? e ? 100 90) 'addr 90
           'cast 90 'clit 90 100))
   ; ce: render e, parenthesized when it binds looser than p
   (ce e p) (: q (cprec e) t (craw e) (q < p ? "(\(t))" t))
   ; a node too short to bind falls to /*?*/, which clay-ok? refuses first
   (craw e)
    (atom? e ? (string? e ? e (show e))
       (e @
        ('num v) (cnum v)
        ('flo v) (cflo v)
        ('str v) (cstrlit v)
        ('chr v) (cchr v)
        ('var v) v
        ('bin op l r) (look binprec op 100 @ p
                       "\(ce l p) \(look binop op "?") \(ce r (p + 1))")
        ('land l r) "\(ce l 40) && \(ce r 41)"
        ('lor l r) "\(ce l 35) || \(ce r 36)"
        ; ?: and = are right-associative, so the tight side flips
        ('cond c t f) "\(ce c 31) ? \(ce t 31) : \(ce f 30)"
        ('asn lv r) "\(ce lv 90) = \(ce r 25)"
        ('rmw op lv r) "\(ce lv 90) \(look binop op "?")= \(ce r 25)"
        ('comma l r) "\(ce l 21), \(ce r 20)"
        ; `- -x`, never `--x`
        ('un u x) (: o (look unop u "?") r (ce x 90)
                   "\(o)\(#r && r 0 = o 0 ? " " "")\(r)")
        ('deref ('bin '+ b i)) "\(ce b 100)[\(ce i 0)]"
        ('deref x) "*\(ce x 90)"
        ('addr x) "&\(ce x 90)"
        ('laddr l) "&&\(l)"
        ('post x d) "\(ce x 95)\(0 < d ? "++" "--")"
        ; a uint/ulong cast of a bare literal prints as the suffix, so a reparse keeps its type
        ('cast ty x)
         ("(\(cty ty "")) \(ce x 90)" @ dflt
            (x @ ('num v && 0 <= v)
                 (: sfx (? (ty = 'uint && v <= 4294967295) "u" (ty = 'ulong) "ul")
                    (sfx ? "\(cnum v)\(sfx)" dflt))
                 dflt))
        ('szof x) "sizeof(\(ctype? x ? (cty x "") (ce x 0)))"
        ('bcp x) "__builtin_constant_p(\(ce x 0))"
        ; a call's arguments sit above the comma operator, hence 21
        ('call f as) "\(ce f 100)(\(sepby ", " (map (x \ ce x 21) as)))"
        ; (dot (deref x) "f") prints as `x->f`, unless the deref is an index
        ('dot t f) (two? t && <t = 'deref && !(cidx? t) ? "\(ce <>t 100)->\(f)"
                      "\(ce t 100).\(f)")
        ('init _) (cinit e 0)
        ('clit ty x) "(\(cty ty "")) \(craw x)"
        ('vastart ap l) "__builtin_va_start(\(ce ap 21), \(ce l 21))"
        ('vaarg ap ty) "__builtin_va_arg(\(ce ap 21), \(cty ty ""))"
        ('vaend ap) "__builtin_va_end(\(ce ap 21))"
        ('sexpr items v _) "({\n\(join (map (x \ cstmt x 1) items))\(two? v ? (line 1 "\(ce v 0);") "")})"
        "/*?*/"))
   ; sizeof's operand: a type or an expression, by the head
   (ctype? t) (name? t ? (elem t '(char short int long uint void double float))
                 (two? t && elem <t '(ptr arr struct named const restrict fn)))
   ; a nested initializer breaks the line, a flat one does not
   (cinitv x) (two? x && elem <x '(dfield didx) ? <>>x x)
   ; a function, not a point-free value: the recursive group compiles before a value
   ; this far down is built. a designated one-field group (`{ .k = x }`) stays inline
   (cnested? l) (any (x \ cinitv x @ ['init [(['dfield _ _] || ['didx _ _])]] 0
                                      ('init . _) 1) l)
   (cinit x ind)
    (x @ ['dfield a b] ".\(a) = \(cinit b ind)"
         ['didx a b] "[\(charm? a ? (show a) (ce a 0))] = \(cinit b ind)"
         ['init l]
          (cnested? l ?
           "{\n\(join (map (i \ "\(pad (ind + 1))\(cinit i (ind + 1)),\n") l))\(pad ind)}"
           "{ \(sepby ", " (map (i \ cinit i ind) l)) }")
         (ce x 21))

   ; --- declarations: one decl may carry several declarators sharing a base
   (cstor st) (atom? st ? "" "\(sepby " " (map string st)) ")
   ; a 4th element is a register variable's asm("reg") pin; a 5th the alignment ask
   (pin? d) (two? >>>d && <>>>d)
   (cdtor1 d) (: nm <d t <>d v <>>d
                 (cty-dtor t nm 0 + (pin? d ? " asm(\(cstrlit <>>>d))" "")
                  + (4 < #d ? " __attribute__((aligned(\(d 4))))" "")
                  + (atom? v ? "" " = \(cinit v 0)")))
   (cdecls ds) (cty-base <><ds @ b
                  "\(foldl (a \ d \ a || pin? d) () ds ? "register " "")\(b) \(sepby ", " (map cdtor1 ds))")

   ; --- statements: one space per level
   (pad n) (n < 1 ? "" " \(pad (n - 1))")
   (line n s) "\(pad n)\(s)\n"
   ; one `//` per line
   (cnote n txt)
    (: (one1 s) (#s ? "// \(s)" "//")     ; no trailing space on a blank line
       (go acc cur l)
        (atom? l ? "\(acc)\(line n (one1 cur))"
           (<l @ c (c = 10 ? (go "\(acc)\(line n (one1 cur))" "" >l)
                      (go acc "\(cur)\(string c)" >l))))
       (go "" "" (map txt (jot #txt))))
   ; --- K&R braces: copen lays header and body; cclose the closer, with a tail
   ; (` while (c);`) that falls to its own line under a non-block body
   (blk? s) (two? s && <s = 'blk)
   (copen n pre hdr s)
    (blk? s ? (line n "\(pre)\(hdr) {" + join (map (x \ cstmt x (n + 1)) <>s))
       (line n "\(pre)\(hdr)" + cstmt s (n + 1)))
   (cclose n s tail)
    (? (blk? s) (line n "}\(tail)") #tail (line n tail) "")

   ; a label or case outdents by one against the statements it labels
   (cstmt s n)
    (atom? s ? ""
       (s @
        ['blk items] (line n "{" + join (map (x \ cstmt x (n + 1)) items) + line n "}")
        ['note x] (cnote n x)
        ['decl d] (line n "\(cdecls d);")
        ['sdecl d] (line n "static \(cdecls d);")
        ['ret x tag] (line n "\(ctag tag) \(two? x ? "return \(ce x 0);" "return;")")
        ['ret x] (line n (two? x ? "return \(ce x 0);" "return;"))
        ['expr x] (line n "\(ce x 0);")
        ['nop] (line n ";")
        ['brk] (line n "break;")
        ['cont] (line n "continue;")
        ['goto l] (line n "goto \(l);")
        ['igoto x] (line n "goto *\(ce x 90);")
        ['lbl l] (line (n < 1 ? 0 (n - 1)) "\(l):")
        ['case v] (line (n < 1 ? 0 (n - 1)) "case \(charm? v ? (show v) (ce v 0)):")
        ['case v w] (line (n < 1 ? 0 (n - 1)) "case \(v) ... \(w):")
        ['dflt] (line (n < 1 ? 0 (n - 1)) "default:")
        ('if . _ . _ . _) (cif s n "")     ; lax: `if 2 3`, and cif reads the else itself
        ['while c b] (copen n "" "while (\(ce c 0))" b + cclose n b "")
        ['do b c] (copen n "" "do" b + cclose n b " while (\(ce c 0));")
        ['for i0 c0 p0 b]
         (: i (cfor i0) c (two? c0 ? (ce c0 0) "") p (two? p0 ? (ce p0 0) "")
            hdr (!#(i + c + p) ? "for (;;)"
                   "for (\(i); \(c); \(p))")
            (copen n "" hdr b + cclose n b ""))
        ['switch c items] (line n "switch (\(ce c 0)) {"
                           + join (map (x \ cstmt x (n + 1)) items) + line n "}")
        ['asm t o1 o2 cl lb _] (casm n "__attribute__((holo)) " t o1 o2 cl lb)   ; the holo mark
        ['asm t o1 o2 cl lb] (casm n "" t o1 o2 cl lb)
        (line n "\(ce s 0);")))
   ; the else-if chain kept flat
   (cif s n pre)
    (: c <>s th <>>s e <>>>s hdr "\(pre)if (\(ce c 0))"
       (? (atom? e) (copen n "" hdr th + cclose n th "")
          (<e == 'if) (copen n "" hdr th + cif e n (blk? th ? "} else " "else "))
          (copen n "" hdr th + copen n (blk? th ? "} " "") "else" e + cclose n e "")))
   ; a for's first clause, (decl ..) or (expr ..) unwrapped; () empty
   (cfor a) (? (atom? a) ""
               (<a = 'decl) (cdecls <>a)
               (<a = 'expr) (ce <>a 0)
               (ce a 0))
   (casm n pre t o1 o2 cl lb)
    (line n ("\(pre)__asm__ \(two? lb ? "goto " "")(\(cstrlit t)\(casmop o1)\(casmop o2)"
             + (two? cl ? " : \(sepby ", " (map cstrlit cl))" (two? lb ? " :" ""))
             + (two? lb ? " : \(sepby ", " lb)" "") + ");"))
   (casmop l) (atom? l ? " :"
                 " : \(sepby ", " (map (o \ "\(cstrlit <o)(\(ce <>o 0))") l))")

   ; --- top level ----------------------------------------------------------------
   (cparam p) (cty-dtor <>p <p 0)
   (cparams ps) (map (p \ "\(cty-base <>p) \(cparam p)") ps @ b
                   (two? ps ? (sepby ", " b) "void"))
   ; a signature, shared by cfn and proto so they cannot drift
   (csig nm at r ps)
    (join (map (a \ "\(ctag a) ") at) + cty r "\(nm)(\(cparams ps))")
   ; one enum constant: a bare name, or (nom expr) with its value
   (cconst k) (two? k ? "\(string <k) = \(ce <>k 21)" (string k))
   ; a struct or union definition, one member per line
   (csdef nm fs kw)
    (line 0 "\(kw) \(ctag nm) {"
     + join (map (\ [fnm ty] (line 1 "\(cty ty fnm);")) fs)
     + line 0 "};")
   ; ranged rows of clay-tags are arms here, longest first
   (ctop t) (t @- ""
    ('note x) (cnote 0 x)
    ('gdecl d st) (line 0 "\(cstor st)\(cdecls d);")
    ('gdecl d) (line 0 "\(cstor ())\(cdecls d);")
    ('xdecl d) (line 0 "extern \(cdecls d);")
    ('tasm t) (line 0 "__asm__ (\(cstrlit t));")
    ('proto nm ps r at) (line 0 "\(csig (ctag nm) at r ps);")
    ('proto nm ps r) (line 0 "\(csig (ctag nm) () r ps);")
    ('proto nm ps) (line 0 "\(csig (ctag nm) () 'int ps);")
    ('proto nm) (line 0 "int \(ctag nm)();")
    ('tdef nm ty) (line 0 "typedef \(cty ty nm);")
    ['tdef] (gripe "(tdef) carries nothing -- a typedef cparse could not keep")
    ; an enum definition, one line
    ('edef nm ks)
     (line 0 "enum \(string? nm || name? nm ? "\(ctag nm) " ""){ \(sepby ", " (map cconst ks)) };")
    ('sdef nm fs u) (csdef nm fs (u = 'union ? "union" "struct"))
    ('sdef nm fs) (csdef nm fs "struct")
    ('sassert e msg)
     (line 0 "_Static_assert(\(ce e 21), \(cstrlit (ctag msg)));")
    ; a directive owns its line and starts at column 0, nested or not
    ('cpp-def nm v) (line 0 "#define \(ctag nm) \(ce v 100)")
    ('cpp-def nm) (line 0 "#define \(ctag nm)")
    ('cpp-undef nm) (line 0 "#undef \(ctag nm)")
    ('cpp-if arms els) (ccpp arms els 1)
    ('cpp-if arms) (ccpp arms () 0)
    (x . _) (gripe "cannot show top-level \(string x)"))
   ; #if / #elif / #else / #endif over top-level items
   (ccpp arms els has)
    (: (go l first)
        (atom? l ? (has ? (cseq (line 0 "#else") (citems els)) "")
           (<l @ r
              (cseq (cseq (line 0 "\(first ? "#if " "#elif ")\(ce <r 0)") (citems <>r))
                    (go >l 0))))
       (cseq (go arms 1) (line 0 "#endif")))
   ; a nested gripe comes out, never concatenated into the text
   (cseq a b) (? (gripe? a) a (gripe? b) b (a + b))
   (citems l) (:- (go l) (go m) (m @ (a . u) (cseq (ctop1 a) (go u)) ""))
   ; the top-level dispatch, shared by clay-show and by a cpp arm's body
   (ctop1 x) (two? x && <x = 'fn && 2 < tally >x ? (cfn x) (ctop x))

   ; --- what cannot be said: forms carrying less than C needs, refused in one pass up
   ; front so the renderers just return text
   (clay-unsaid c)
    (:- (go c) (go x)
        (? (atom? x) ()
           (<x = 'tdef && atom? >x)
            (gripe "(tdef) carries nothing -- a typedef, struct or _Static_assert cparse could not keep")
           (elem <x '(decl sdecl) && atom? <>x)
            (gripe "(\(<x) ()) declared no object -- the tag or the function name is not in the node")
           (<x = 'vastart && atom? >>x)
            (gripe "(vastart ap) lost va_start's last named parameter at parse")
           (<x = 'struct && !(cident? <>x))
            (gripe "(struct \(show <>x)) -- an anonymous tag is not a C identifier")
           (<x = 'flo && !(cfinite? <>x))
            (gripe "(flo \(<>x)) -- C has no literal for an infinity or a nan")
           (<x = 'edef && atom? <>>x)
            (gripe "(edef \(show <>x) ()) has no constants -- C has no empty enum")
           (<x = 'sdef && atom? <>>x)
            (gripe "(sdef \(show <>x) ()) has no members -- C has no empty struct")
           (<x = 'sdef && !(cident? <>x))
            (gripe "(sdef \(show <>x)) -- an anonymous tag is not a C identifier")
           (elem <x '(cpp-def cpp-undef) && !(cident? <>x))
            (gripe "(\(<x) \(show <>x)) -- a macro name is an identifier")
           (<x = 'cpp-if && atom? <>x)
            (gripe "(cpp-if ()) has no arms -- C has no #if without a condition")
           (<x = 'restrict && !(cptr? <>x))
            (gripe "(restrict t) -- C restricts only a pointer")
           (:- (kids >x) (kids (e . u))
            (: v (two? e ? (name? <e ? (go e) (kids e))) (v || kids u)))))

   ; --- (clay-show c) -> C text or a gripe; `prog` is a whole TU, anything else shows alone
   (clay-show c)
    (clay-unsaid c @ u
       (? u u
          (atom? c) (gripe "clay-show wants a form")
          (<c = 'prog) (citems <>c)
          (ctop1 c)))
   ; (fn name params body [ret [attrs]]); an absent ret prints `int`
   (cfnl nm ps b r at) (copen 0 "" (csig (ctag nm) at r ps) b + cclose 0 b "")
   (cfn t)
    (t @ ['fn nm ps b r at] (cfnl nm ps b r at)
         ['fn nm ps b r] (cfnl nm ps b r ())
         ['fn nm ps b] (cfnl nm ps b 'int ())
         ""))
