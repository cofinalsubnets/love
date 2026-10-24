; src/apps/moon/parse.l -- the C parser: tokens -> (1 ast stbl) | (). recursive descent, with
; expressions and blocks through c.y's grammar (cgram.l); the cursor is a token list threaded
; as (value rest), () the error riding up.
; ps holds what C cannot be parsed without: typedef names 'types, enum constants 'enums, and
; 'stag (tag -> (fields size align)), which rides out with the AST. unions flatten into 'struct
; entries at offset zero; an anonymous member splices into its parent.
; nodes beyond the obvious: ('dot e name), ('switch e items) with ('case v)/('dflt) inline,
; ('do body cond), ('goto name) ('lbl name), ('tdef), ('call headexpr args), ('clit ty init),
; ('init (item..)) with item plain | ('dfield name val) | ('didx n val).
; a new node is also clay's, which re-says this output: an arity row, a precedence, a rendering.
(module 'moon
(borrow 'kore)
(:
   ; token readers: t = (kind val line)
   (tkk t) <t (tkv t) <>t
   ; a nom in a pattern is a fresh binder, so the value is checked by guard
   (tp? ('p . v . _) s) (v = s)
   (tkw? ('kw . v . _) k) (v = k)
   (idv? ('id . v . _) s) (v = s)
   (idat? ts) (two? ts && tkk <ts = 'id)         ; an identifier heads ts
   (strat? ts) (two? ts && tkk <ts = 'str)
   cx-door {}                                       ; cgram.l's parse, laid after this file
   ; -- where a refusal stood --
   ; cpp's spans ((index file)..) ride a marker token at the head; raw lexer output reads ().
   ; the file is carried since an #include splices the header's own line numbering in
   (fspans ts) (two? ts && tkk <ts = 'fspans ? (tkv <ts))
   (fsbody ts) (two? ts && tkk <ts = 'fspans ? >ts ts)
   (filat spans i)                                  ; the file in force at stream index i
    (: (go l cur) (? (atom? l) cur (i < <<l) cur (go >l <><l))
       (go spans ()))
   ; a token the failing form's re-parse stamped: (kind val line seq file)
   (stampf ts i spans)
    (atom? ts ? ()
       (<ts @ t
          ([(tkk t) (tkv t) <>>t i (filat spans i)] . stampf >ts (i + 1) spans)))
   (stamped? t) (two? >>>>t)                       ; a 5th cell
   (seqof t) (stamped? t ? <>>>t)
   (filof t) (stamped? t ? <>>>>t)
   ; the watermark: a refusal unwinds with no position, so the deepest token any lookahead
   ; stood on is remembered. only a failing form's re-parse runs on stamped tokens.
   far {}
   (mark ts)                                        ; seqof, spelled out: it runs on every lookahead
    ((two? ts ?
        (: t <ts
           (two? >>>>t ? (<>>>t @ s (charm? s && peep far 'seq -1 < s ? (pin far 'seq s, pin far 'tok t)))))),
     ts)
   (want ts s) (mark ts, (two? ts && tp? <ts s ? >ts))
   (peekp ts s) (mark ts, two? ts && tp? <ts s)
   ; a (v rest) | () answer carried past one required token s -> (v rest') | ()
   (thenw r s) (atom? r ? () (want <>r s @ rest (two? rest ? [<r rest])))
   ; a refusal that knows its cause files its sentence; pfail reports it while still deepest
   (blame ts msg)
    (: _ (mark ts)
       s (two? ts ? (seqof <ts))
       (charm? s && peep far 'seq -1 = s ?
          (pin far 'why msg, pin far 'wseq s),
        ()))
   asnops [["=" ()] '("+=" +) '("-=" -) '("*=" *) '("/=" /) '("%=" %)
             '("&=" &) '("|=" |) '("^=" ^) '("<<=" shl) '(">>=" shr)]
   scalars '(char short int long void double float)
   ; a type-specifier run canonicalizes to one type symbol: `unsigned long` -> 'ulong.
   ; `long long` is 'long on 64-bit targets, 'llong/'ullong (a register pair) on 32-bit ones
   tyspec '(char short int long void double float signed unsigned _Bool _Complex __int128)
   (canon ps specs)
    (? (elem '_Complex specs)                   ; C99 complex: a seeded two-member struct
        (elem 'float specs ? '(struct "__cplx_float") '(struct "__cplx_double"))
       (elem 'void specs) 'void
       (elem '_Bool specs) 'bool                  ; one byte, stores normalize to 0/1 (C11 6.3.1.2)
       (elem 'double specs) 'double
       (elem 'float specs) 'float
       (elem '__int128 specs) (elem 'unsigned specs ? 'u128 'i128)
       (: uns (elem 'unsigned specs)
          ll (pst32? ps && (: (n2 l k) (atom? l ? k (n2 >l (<l = 'long ? (k + 1) k)))
                             (1 < n2 specs 0)))                             ; two longs on t32
          base (? (elem 'char specs) 'char (elem 'short specs) 'short
                  ll 'llong (elem 'long specs) 'long 'int)
          (? (base = 'char && !uns) (elem 'signed specs ? 'schar (pchar ps))   ; signed char, or plain: the target's own
             !uns base
             (base = 'char) 'uchar (base = 'short) 'ushort
             (base = 'llong) 'ullong (base = 'long) 'ulong 'uint)))
   ; ignorable specifiers, skipped wherever a type or a declarator may carry them;
   ; __attribute__((..)) / _Alignas(..) balance-skip their parens
   qualkw '(const volatile restrict register auto inline extern static)
   ; _Alignof is an operator: a skip would eat its operand. _Thread_local skips:
   ; no threads, so a thread-local is the one static object
   qualid '("__attribute__" "__inline" "__inline__" "__restrict" "__restrict__"
            "__volatile__" "__volatile" "__const" "__const__" "_Noreturn" "_Alignas"
            "__extension__" "_Thread_local" "__thread")
   ; typeof, and C23's typeof_unqual as the same operator: no type carries a qualifier.
   ; `typeof` is not reserved in C11, so an object of that name reads as a declaration
   tyofid '("__typeof" "__typeof__" "typeof" "__typeof_unqual__" "typeof_unqual")
   ; gcc's __auto_type: the declared type is the initializer's
   autoid "__auto_type"
   ; gcc's library builtins: the prefix names the plain function, which libsig declares.
   ; kept with the rosters: further down the block, love0's lane answers `;; missing libbin`.
   ; __builtin_alloca keeps its name: gen lays it on the stack, and no symbol carries it
   libbin '("__builtin_memcpy" "__builtin_memmove" "__builtin_memset"
            "__builtin_memcmp" "__builtin_strlen" "__builtin_strcpy" "__builtin_alloca")
   ; the shape gate the builtin arms hide their string compares behind: the shortest is 16
   (bib? s) (#s @ n (n < 16 ? () (s 2 = 98)))     ; `__b..`, 16+
   (libsig ps nm)
    (: vp '(ptr void) cp ['ptr (pchar ps)] sz (szty ps)
       (? (nm = "memset") [vp [vp 'int sz] ()]
          (nm = "memcmp") ['int [vp vp sz] ()]
          (nm = "strlen") [sz [cp] ()]
          (nm = "strcpy") [cp [cp cp] ()]
          (nm = "strcmp") ['int [cp cp] ()]
          (nm = "alloca") [vp [sz] ()]
          [vp [vp vp sz] ()]))                     ; memcpy and memmove
   ; one qualifier token, and the cursor past it (an attribute id carries its parens)
   (qual? t) (? (tkk t = 'kw) (elem (tkv t) qualkw) (tkk t = 'id) (elem (tkv t) qualid) ())
   (qskip ts) (>ts @ r
                 (tkk <ts = 'id && peekp r "(" ?
                     (skipbal >r 1 @ e (idv? <ts "__attribute__" && cleanup? ts e ? (nocleanup e) e))
                    r))
   (pquals ts) (two? ts && qual? <ts ? (pquals (qskip ts)) ts)
   ; skip a trailing run of __attribute__((..)) / __asm__(..) off a declarator's tail. a bare
   ; name with no `(` is not decoration
   (patt ts)
    (? (atom? ts) ts
       ((tkk <ts = 'id && elem (tkv <ts) '("__attribute__" "__asm__" "__asm")) &&
        peekp >ts "(")
        (skipbal >>ts 1 @ e (cleanup? ts e ? (nocleanup e) (patt e)))
       ts)
   ; the statement-position skip: __attribute__ only, a leading __asm__(..) is inline asm
   (pattr ts)
    (? (atom? ts) ts
       (idv? <ts "__attribute__" && peekp >ts "(")
        (skipbal >>ts 1 @ e (cleanup? ts e ? (nocleanup e) (pattr e)))
       ts)
   ; cleanup is not decoration: it runs code at every scope exit
   (cleanup? a b) (a = b ? () (idv? <a "cleanup" || idv? <a "__cleanup__" || cleanup? >a b))
   (nocleanup ts) (blame ts "__attribute__((cleanup)) is not carried out")
   ; gcc's mode(M): the type laid at M's width, keeping its signedness. scans from the head to
   ; the first depth-0 `;`/`{`, or the `)`/type-led `,` ending a parameter.
   ; -> M | 'many (several declarators) | 'deriv (a derived declarator) | ()
   (modeat ps ts)
    (: (inatt s d) (atom? s ? ()
                     (? (peekp s "(") (inatt >s (d + 1))
                        (peekp s ")") (d < 2 ? () (inatt >s (d - 1)))
                        ((idv? <s "mode" || idv? <s "__mode__") && peekp >s "(" && idat? >>s)
                         (tkv <>>s @ nm (nm @ ("__" + m + "__") m nm))
                        (inatt >s d)))
       ; m: the mode met so far; c: a declarator-list `,` passed; v: a derived declarator
       (go s d m c v)
        (: fv (? !m () c 'many v 'deriv m)
           (atom? s ? fv
              (<s @ t
                 (? (d < 1 && (tp? t ";" || tp? t "{" || tp? t ")")) fv
                    (d < 1 && tp? t "," && (tyat? ps >s || peekp >s "...")) fv
                    (d < 1 && tp? t ",") (go >s d m 1 v)
                    (d < 1 && tp? t "=") (go (pinit >s) d m c v)
                    (d < 1 && (idv? t "__attribute__" || idv? t "__attribute") && peekp >s "(")
                     (inatt >s 0 @ m2 (go (skipbal >>s 1) d (string? m2 ? m2 m) c v))
                    (tp? t "(" || tp? t "[") (go >s (d + 1) m c (d < 1 || v))
                    (tp? t ")" || tp? t "]") (go >s (d - 1) m c v)
                    (go >s d m c (d < 1 && tp? t "*" || v))))))
       ; an initializer's tokens, to the depth-0 `,` or `;` that ends it
       (pinit s) (: (sk s d) (? (atom? s) s
                                (d < 1 && (peekp s "," || peekp s ";" || peekp s ")")) s
                                (peekp s "(" || peekp s "[" || peekp s "{") (sk >s (d + 1))
                                (peekp s ")" || peekp s "]" || peekp s "}") (sk >s (d - 1))
                                (sk >s d))
                    (sk s 0))
       (ps 'nomode ? () (go ts 0 () () ())))      ; cparse-o's: the unit never names mode
   ; the type mode M lays ty at -> a type, or a refusal's sentence
   (modety ps m ty)
    (: uns (elem ty '(uchar cchar ushort uint ulong ullong u128))
       w (m @ ("QI" || "byte") 1 "HI" 2 "SI" 4 "DI" 8 "TI" 16 ("word" || "pointer") (psword ps) 0)
       (? (m = "SF" && elem ty '(float double)) 'float
          (m = "DF" && elem ty '(float double)) 'double
          (w < 1) "__attribute__((mode(\(m)))) is not carried out"
          !(elem ty '(char schar cchar uchar short ushort int uint long ulong llong ullong i128 u128))
           "__attribute__((mode(\(m)))) on a non-integer type is not carried out"
          (w = 16 && pst32? ps) "__attribute__((mode(\(m)))) is not carried out on a 32-bit target"
          (w @ 1 (uns ? 'uchar 'schar) 2 (uns ? 'ushort 'short) 4 (uns ? 'uint 'int)
             8 (? (pst32? ps) (uns ? 'ullong 'llong) uns 'ulong 'long)
             (uns ? 'u128 'i128))))
   ; gcc's `__label__ a, b;`: each name takes a fresh spelling for the rest of its block
   ; (restored with the block's shadows). -> (rest shadows)
   (plabs ps ts sh)
    (? (atom? ts) [ts sh]
       (peekp ts ";") [>ts sh]
       (idat? ts)
        (: nm (tkv <ts) k (ps 'lrn)
           _ (pin ps 'lrn (k + 1))
           old (peep (ps 'lren) nm 'none)
           (pin (ps 'lren) nm "\(nm)__L\(k)",   ; C-legal, so clay reads it back
            plabs ps >ts (['lren nm old] . sh)))
       (plabs ps >ts sh))
   (lname ps nm) (peep (ps 'lren) nm nm)
   ; does the run pquals drops carry `restrict`? the fact rides out of band (ps 'rstrs)
   (rstrq? ts)
    (atom? ts ? ()
       (<ts @ t
          (? (tkw? t 'restrict) 1
             (tkk t = 'id && elem (tkv t) '("__restrict" "__restrict__")) 1
             (qual? t) (rstrq? (qskip ts))
             ())))
   (leadkw? ps ts k)
    (atom? ts ? ()
       (<ts @ t
          (? (tkw? t k) 1
             (tkk t = 'kw && elem (tkv t) tyspec) (leadkw? ps >ts k)
             (qual? t) (leadkw? ps (qskip ts) k)
             ; a typedef name is a specifier: `uint32_t const x`. a tag head is not walked
             (tkk t = 'id && tkbty? ps t) (leadkw? ps >ts k)
             ())))
   ; a block-scope `static` local is laid in .bss, not a stack slot
   (leadstatic? ps ts) (leadkw? ps ts 'static)
   (leadextern? ps ts) (leadkw? ps ts 'extern)
   (leadregister? ps ts) (leadkw? ps ts 'register)
   ; a file-scope `register T nm asm("R")`, GNU's global register variable: no storage laid.
   ; caught before patt, which would skip the asm name and rename the object in silence
   (pgreg ps ts nm regv)
    (? (!regv || atom? ts) ts
       (!(asmid? <ts) || !(peekp >ts "(") || !(strat? >>ts) || !(peekp >>>ts ")")) ts
       (tkv <>>ts @ s
          ; only the stack pointer: gcc reserves the register TU-wide and we cannot
          (!(elem s '("rsp" "sp" "esp" "%rsp" "%esp")) ?
             (blame >>>>ts "a global register variable is taken on the stack pointer only, not '\(s)'")
             (pin (ps 'gregs) nm [s 'long], >>>>ts))))
   ; a file-scope asm label, `void f(void) asm("g")`: the symbol is g, the C name stays.
   ; adjacent strings join; any other shape refuses rather than rename in silence
   (plabel ps ts nm)
    (? (atom? ts || !(asmid? <ts) || !(peekp >ts "(")) ts
       !(strat? >>ts) (blame >ts "an asm label is a string")
       (: (strs l acc) (strat? l ? (strs >l (acc + tkv <l)) [acc l])
          (strs >>ts "" @ [lb r]
             (!(peekp r ")") ? (blame r "an asm label is a string")
                (pin (ps 'anames) nm lb, >r)))))
   ; `const` in the specifier run; cobj? decides per declarator whether it names the object
   (leadconst? ps ts) (leadkw? ps ts 'const)
   ; arrays are transparent to it, a pointer is not: `const char *p` qualifies the pointee
   (cobj? ty) (? (atom? ty) 1 (<ty = 'arr) (cobj? <>ty) (<ty != 'ptr))
   ; `alias("TARGET")` to the first depth-0 `;` or `{`, with any `weak` in the same run.
   ; -> (TARGET weak?) | ()
   (aliasat? ts)
    (: (go s d tgt wk)
        (atom? s ? (tgt ? [tgt wk])
           (<s @ t
              (? (d < 1 && (tp? t ";" || tp? t "{")) (tgt ? [tgt wk])
                 (tp? t "(") (go >s (d + 1) tgt wk)
                 (tp? t ")") (go >s (d - 1) tgt wk)
                 (idv? t "weak" || idv? t "__weak__") (go >s d tgt 1)
                 (idv? t "alias" || idv? t "__alias__")
                  (>s @ r
                     (!(peekp r "(") ? (go >s d tgt wk)
                        (>r @ r2
                           (strat? r2 ?
                              (go >s d (tkv <r2) wk) (go >s d tgt wk)))))
                 (go >s d tgt wk))))
       (go ts 0 () ()))
   ; an attribute anywhere in the declaration (musl's `weak` follows the storage class).
   ; always_inline admits the name to gen's inline table unbounded, noinline bars it
   (attrany? ts a b)
    (: (go s d) (atom? s ? ()
                   (<s @ t
                      (? (d < 1 && (tp? t ";" || tp? t "{")) ()
                         (tp? t "(") (go >s (d + 1))
                         (tp? t ")") (go >s (d - 1))
                         (idv? t a || idv? t b) 1
                         (go >s d))))
       (go ts 0))
   ; `section("NAME")` to the first depth-0 `;` or `{`. -> NAME | ()
   (secat? ts)
    (: (go s d) (atom? s ? ()
                   (<s @ t
                      (? (d < 1 && (tp? t ";" || tp? t "{")) ()
                         (tp? t "(") (go >s (d + 1))
                         (tp? t ")") (go >s (d - 1))
                         (idv? t "section" || idv? t "__section__")
                          (peekp >s "(" && strat? >>s ?
                             (tkv <>>s)
                             (go >s d))
                         (go >s d))))
       (go ts 0))
   ; `patchable_function_entry(N)` or `(N, M)`, to the first depth-0 `;` or `{` -> (N M) | ()
   (pfeat? ts)
    (: (num t) (tkk t = 'num ? (tkv t))
       (go s d) (atom? s ? ()
                   (<s @ t
                      (? (d < 1 && (tp? t ";" || tp? t "{")) ()
                         (tp? t "(") (go >s (d + 1))
                         (tp? t ")") (go >s (d - 1))
                         (0 < d && (idv? t "patchable_function_entry" || idv? t "__patchable_function_entry__") &&
                          peekp >s "(" && two? >>s && charm? (num <>>s))
                          (: n (num <>>s) r >>>s
                             (? (peekp r ")") [n 0]
                                (peekp r "," && two? >r && charm? (num <>r)) [n (num <>r)]
                                (go >s d)))
                         (go >s d))))
       (go ts 0))
   ; the attribute groups right after a struct/union/enum body are the type's (gcc): past them
   ; the declaration's own begin
   (tyattr s)
    (: (parn s n) (? (atom? s || n < 1) s
                     (tp? <s "(") (parn >s (n + 1))
                     (tp? <s ")") (parn >s (n - 1))
                     (parn >s n))
       (two? s && (idv? <s "__attribute__" || idv? <s "__attribute") && peekp >s "(" ? (tyattr (parn >>s 1)) s))
   ; one `aligned` ask, the tokens after the word -> (N rest): bare is the target's widest,
   ; a constant expression folds, one that will not fold asks nothing
   (palask ps ts)
    (!(peekp ts "(") ? [(elem (ps 'tgt) '(thumb2 thumb2sp arm thumb1) ? 8 16) ts]   ; AAPCS32's 8; i386's SSE asks 16
       (thenw (pexpr ps >ts) ")" @ er
          (atom? er ? [0 ts]
             (cfold (pw64 ps) <er @ v [(charm? v ? v 0) <>er]))))
   ; gcc's `aligned(N)` and C11's `_Alignas(N|type)` at one door, to the first depth-0 `;`
   ; or `{`. `aligned` counts only inside parens. -> N | ()
   (alignat? ps ts)
    (: (go s d) (atom? s ? ()
                   (<s @ t
                      (? (d < 1 && (tp? t ";" || tp? t "{")) ()
                         (tp? t "(") (go >s (d + 1))
                         (tp? t ")") (go >s (d - 1))
                         (0 < d && (idv? t "aligned" || idv? t "__aligned__"))
                          (palask ps >s @ a (0 < <a ? <a (go >s d)))
                         ; `_Alignas(T)` is `_Alignof(T)`
                         (idv? t "_Alignas" && peekp >s "(")
                          (two? >>s && tkk <>>s = 'num ? (tkv <>>s)
                             (pcty ps >>s @ tr
                                (two? tr ? (talign ps <tr) (go >s d))))
                         (go >s d))))
       (go ts 0))
   ; the words the scans above answer to, read in one walk by their bounds: a scan whose
   ; words are absent answers () having looked at nothing else, so ptop runs only the rest
   hdword {"section" 1 "__section__" 1 "alias" 1 "__alias__" 1 "weak" 1 "__weak__" 1
           "always_inline" 1 "__always_inline__" 1 "noinline" 1 "__noinline__" 1 "used" 1
           "__used__" 1 "gnu_inline" 1 "__gnu_inline__" 1 "aligned" 1 "__aligned__" 1 "_Alignas" 1
           "patchable_function_entry" 1 "__patchable_function_entry__" 1
           "no_stack_protector" 1 "__no_stack_protector__" 1 "stack_protect" 1 "__stack_protect__" 1}
   (hdhits ts)
    (: (go s d acc) (atom? s ? acc
                       (<s @ t
                          (? (d < 1 && (tp? t ";" || tp? t "{")) acc
                             (tp? t "(") (go >s (d + 1) acc)
                             (tp? t ")") (go >s (d - 1) acc)
                             (tkk t = 'id && peep hdword (tkv t) ()) (go >s d (tkv t . acc))
                             (go >s d acc))))
       (go ts 0 ()))
   (hwin hw a b) (elem a hw || elem b hw)

   ; -- the parse state --
   (psnew tgt) (psnew-d tgt 'moon)                ; the default language
   ; a new door, not a wider one: a shifted call would hand back a closure in silence
   (psnew-d tgt dia) ({} @ t
                (pin t 'dia dia,                  ; the dialect: moon | c | c23
                 pin t 'tgt tgt,                  ; the codegen target
                 pin t 'types {},         ; typedef name -> ty
                 pin t 'weaks (),                 ; __attribute__((weak)) function names
                 pin t 'ainl (),                  ; always_inline function names
                 pin t 'noinl (),                 ; noinline function names
                 pin t 'enums {},         ; enum constant -> value
                 pin t 'declaring {},     ; the names being declared now (C11 6.2.1p7)
                 pin t 'labs {},          ; the function's labels (C11 6.8.1p3)
                 pin t 'lren {},          ; a __label__ name -> its spelling in the current block
                 pin t 'lrn 0,
                 pin t 'etag {},          ; enum tag -> its lowered type
                 pin t 'efwd {},          ; an enum tag named before its definition
                 pin t 'stag {},          ; tag -> (fields size align)
                 pin t 'tags {},          ; a block tag's spelling -> its stag key
                 pin t 'utag {},          ; the union tags
                 pin t 'tunion {},        ; ..and the transparent_union ones
                 pin t 'sigs {},          ; fn/proto name -> (rettype (paramty..))
                 pin t 'anon 0,                   ; the anonymous-tag counter
                 pin t 'sfns {},          ; top-level `static` fn names
                 pin t 'c99inl {},        ; fn name -> 'inl while every declaration says plain `inline`
                 pin t 'svars {},         ; top-level `static` globals
                 pin t 'sects {},         ; global name -> its section
                 pin t 'consts {},        ; global name -> 1: a const object with an initializer
                 pin t 'rstrs {},         ; fn name -> its restrict param names
                 pin t 'gregs {},         ; a file-scope register variable: nm -> (R ty)
                 pin t 'anames {},        ; a file-scope asm label: nm -> its symbol
                 pin t 'currstr (),               ; ..accumulating for the current declaration
                 pin t 'aligns {},        ; global name -> its aligned(N)
                 pin t 'pfes {},          ; fn name -> its patchable_function_entry (N M)
                 pin t 'locals {},        ; local/param name -> its declared type
                 pin t 'globals {},       ; file-scope name -> ty
                 pin t 'hoist (),                 ; block-scope `extern` decls, hoisted as ('xdecl ..)
                 pin t 'qtys {},          ; ..-> the qualifier-marked type, _Generic's alone
                 pin t 'qstage {},        ; ..staged by a declarator, consumed by its bind
                 pin t 'qtdef {},         ; typedef name -> its leaf's const/volatile mask
                 pin t 'qmem {},          ; "tag.member" -> the same mask
                ; gcc's builtin va_list: gen bakes the offsets, only size/align/decay ride here
                 pin (t 'stag) "__va_list_tag"
                     (? (pst32? t) '((("__ap" 0 (ptr void))) 4 4)
                        (tgt = 'rv64) '((("__ap" 0 (ptr void))) 8 8)   ; LP64: one walking pointer, 8-byte slots
                        (tgt = 'a64)
                         '((("__stack" 0 (ptr void)) ("__gr_top" 8 (ptr void)) ("__vr_top" 16 (ptr void))
                            ("__gr_offs" 24 int) ("__vr_offs" 28 int)) 32 8)
                        '((("gp_offset" 0 int) ("fp_offset" 4 int) ("overflow_arg_area" 8 (ptr void))
                           ("reg_save_area" 16 (ptr void))) 24 8)),
                 pin (t 'types) "__builtin_va_list" '(arr (struct "__va_list_tag") 1),
                ; gcc's typedef names for the wide pair
                 pin (t 'types) "__int128_t" 'i128,
                 pin (t 'types) "__uint128_t" 'u128,
                ; the bswap trio types unsigned: compare/divide/sizeof read the width
                 pin (t 'sigs) "__builtin_bswap16" '(ushort (ushort) ()),
                 pin (t 'sigs) "__builtin_bswap32" '(uint (uint) ()),
                 pin (t 'sigs) "__builtin_bswap64" (pst32? t ? '(ullong (ullong) ()) '(ulong (ulong) ())),   ; long long on 32-bit
                ; the popcount trio: an unsigned operand, a plain int result
                 pin (t 'sigs) "__builtin_popcount" '(int (uint) ()),
                 pin (t 'sigs) "__builtin_popcountl" '(int (ulong) ()),
                 pin (t 'sigs) "__builtin_popcountll" '(int (ulong) ()),
                ; clz/ctz likewise, so an __auto_type or a typeof over one types
                 pin (t 'sigs) "__builtin_clz" '(int (uint) ()),
                 pin (t 'sigs) "__builtin_clzl" '(int (ulong) ()),
                 pin (t 'sigs) "__builtin_clzll" '(int (ulong) ()),
                 pin (t 'sigs) "__builtin_ctz" '(int (uint) ()),
                 pin (t 'sigs) "__builtin_ctzl" '(int (ulong) ()),
                 pin (t 'sigs) "__builtin_ctzll" '(int (ulong) ()),
                ; ffs: signed operands, int answer (0 for 0, else the lowest set bit's 1-based index)
                 pin (t 'sigs) "__builtin_ffs" '(int (int) ()),
                 pin (t 'sigs) "__builtin_ffsl" '(int (long) ()),
                 pin (t 'sigs) "__builtin_ffsll" '(int (llong) ()),
                ; C99 _Complex as two-member structs, the tags canon maps onto
                 pin (t 'stag) "__cplx_double" '((("re" 0 double) ("im" 8 double)) 16 8),
                 pin (t 'stag) "__cplx_float" '((("re" 0 float) ("im" 4 float)) 8 4),
                 pin t 'vlan 0,                   ; the VLA decl-site counter
                 pin t 'alias {},         ; alias("t"): name -> its target
                 t))
   ; does a type begin here?
   (tkbty? ps t)
    (? (atom? t) ()
       (tkk t = 'kw) (elem (tkv t) tyspec || elem (tkv t) '(struct union enum))
       (tkk t = 'id) (? (elem (tkv t) tyofid) 1
                          (tkv t = autoid) 1
                          (peep (ps 'types) (tkv t) 0) 1 ())
       ())

   (tyat? ps ts) (tkbty? ps <(pquals ts))              ; a type begins at ts, past its qualifiers
   (ptyat? ps ts) (peekp ts "(" && tyat? ps >ts)       ; ..inside a `(`: a cast, a type-name operand
   ; -- the type floor (floor.l, shared with gen) takes the word and the tag table from ps --
   (pst32? ps) (elem (ps 'tgt) '(thumb2 thumb2sp arm thumb1 i386 i386m16))   ; long 4 bytes, long long the pair
   ; char is three types (C11 6.2.5p15): 'schar, 'uchar, and plain char -- 'char where the ABI
   ; makes it signed, 'cchar where unsigned. each symbol's sign is its own
   (paapcs? ps) (elem (ps 'tgt) '(a64 thumb1 thumb2 thumb2sp arm))   ; bit-fields laid by AAPCS
   (pchar ps) (ps 'uch @ 1 'cchar 0 'char (elem (ps 'tgt) '(a64 rv64 thumb1 thumb2 thumb2sp arm) ? 'cchar 'char))   ; -f[un]signed-char's, else the ABI's
   (pw64 ps) !(pst32? ps)                          ; is long 8 bytes?
   (psword ps) (pst32? ps ? 4 8)
   (szty ps) (pst32? ps ? 'uint 'ulong)          ; size_t
   (tsz ps ty) (tysz (psword ps) (ps 'stag) ty)
   (talign ps ty) (tyalign (psword ps) (psacap ps) (ps 'stag) ty)
   (psacap ps) (? (elem (ps 'tgt) '(i386 i386m16)) 4 (pst32? ps) 8 16)   ; the widest scalar alignment

   ; -- parse-time expr typer (for sizeof folding): the undecayed type of an expr, () when
   ; unknown (gen sizes a deferred 'szof then). sizeof of an array is its span.
   (fldty ps sty nm) (peep (ps 'stag) <>sty () @ e     ; the type of member nm off a struct type
                        (atom? e ? ()
                           (assoc nm <e @ f (two? f ? <>>f))))
   (fmof ps sty nm) (!(stru? sty) ? ()                  ; a member's (byte-offset ty) off a struct type
                       (peep (ps 'stag) <>sty () @ e
                          (atom? e ? ()
                             (assoc nm <e @ f (two? f ? [<>f <>>f])))))
   ; &((T*)0)->fld (and a.b chains over it) folds to the member's byte offset, offsetof's idiom;
   ; one not grounded in a null pointer cast stays an address
   (nulloff ps e)
    (: (ground b)                                    ; -> (byte-offset struct-ty) | ()
        (? (atom? b) ()
           (<b = 'deref)
            (<>b @ c
               (two? c && <c = 'cast ?
                   (: ty <>c v (cfold (pw64 ps) <>>c)
                      (ptr? ty && charm? v && v = 0 ? [0 <>ty]))
                  ; a constant index off a null-grounded array or pointer: in[1].b
                  (: pv (zbase? c ? (pval c))
                     t (two? pv ? (ptype ps c))
                     (ptr? t || arr? t ? [<pv <>t]))))
           (<b = 'dot)
            (ground <>b @ gr
               (atom? gr ? ()
                  (fmof ps <>gr <>>b @ f
                     (two? f ? [(<gr + <f) <>f]))))
           ())
       ; the pointer under an index grounds at null itself, never at another constant
       (zbase? x)
        (? (atom? x) ()
           (<x = 'cast) (cfold (pw64 ps) <>>x @ v (charm? v && v = 0))
           (<x = 'bin) (zbase? <>>x || zbase? <>>>x)
           (<x = 'dot) (two? (ground x))
           ())
       ; a null-grounded pointer value -> (byte-address stride) | (): ((T*)K) and + over it
       (pval x)
        (? (atom? x) ()
           (<x = 'cast && ptr? <>x)
            (: ty <>x
               v (cfold (pw64 ps) <>>x)
               (charm? v ? [v (tsz ps <>ty)]))
           (<x = 'bin && <>x = '+)
            (pval <>>x @ pa
               (two? pa ?
                  (cfold (pw64 ps) <>>>x @ n (charm? n ? [(<pa + n * <>pa) <>pa]))
                  (pval <>>>x @ pb
                     (atom? pb ? ()
                        (cfold (pw64 ps) <>>x @ n (charm? n ? [(<pb + n * <>pb) <>pb]))))))
           ; a null-grounded array member decays to its constant address, element stride
           (<x = 'dot)
            (ground x @ gr
               (atom? gr ? ()
                  (<>gr @ ty
                     (arr? ty ? [<gr (tsz ps <>ty)]))))
           ())
       (? (two? e && <e = 'deref)                  ; &*(ptr-expr): the pointer's own value
           (pval <>e @ pv (two? pv ? <pv))
          !(two? e && <e = 'dot) ()
          (ground <>e @ gr
             (atom? gr ? ()
                (fmof ps <>gr <>>e @ f
                   (two? f ? (<gr + <f)))))))
   (ptrarg ps e) (!(two? e && <e = 'bin) ? ()          ; the ptr/arr operand of a `bin +` (a[i] desugars so)
                    (: a (ptype ps <>>e) b (ptype ps <>>>e)
                       (? (ptr? a || arr? a) a (ptr? b || arr? b) b ())))
   ; a null pointer constant (C11 6.3.2.3p3): an integer constant expression folding to 0,
   ; cast or not (cfold folds through a pointer cast)
   (npc? e) (cfold 1 e @ v (cint? v && v = 0 ? 1))
   (ptype ps e)
    (atom? e ? ()
       (<e @ k
          (? (k = 'sexpr) <>>>e                            ; a statement expression carries its own
             (k = 'var) (peep (ps 'locals) <>e () @ lt   ; locals shadow; a file-scope name falls through
                           (lt ? lt
                              (peep (ps 'globals) <>e () @ gt
                                 (gt ? gt
                                    ; a bare function name: its 'sigs row as ('fn rty ptys)
                                    (peep (ps 'sigs) <>e () @ sg
                                       (two? sg ? ['fn <sg <>sg]))))))
             (k = 'dot) (ptype ps <>e @ bt (stru? bt ? (fldty ps bt <>>e)))
             (k = 'deref) (ptype ps <>e @ it
                             (? (ptr? it) <>it (arr? it) <>it
                                (ptrarg ps <>e @ pt (? (ptr? pt) <>pt (arr? pt) <>pt ()))))
             (k = 'cast) <>e
             (k = 'clit) <>e
             ; &x only when x's type is known, so a wrong stride never folds
             (k = 'addr) (ptype ps <>e @ it (it ? ['ptr it]))
             (k = 'laddr) '(ptr void)
             ; a call through a named function: its 'sigs return type
             (k = 'call) (: sg (two? <>e && <<>e = 'var ? (peep (ps 'sigs) <><>e ()))
                            (two? sg ? <sg
                               ; else through the callee's own type: a function, or a pointer to one
                               (ptype ps <>e @ ft
                                  (? (two? ft && <ft = 'fn) <>ft
                                     (two? ft && <ft = 'ptr && two? <>ft && <<>ft = 'fn) <><>ft
                                     ()))))
             (k = 'str) ['arr (pchar ps) (#<>e + 1)]     ; a literal is its array: sizeof("ab") is 3
             ; sizeof('T') is sizeof(int); a plain decimal past int32 is a long
             (k = 'num) (-2147483648 <= <>e && <>e <= 2147483647 ? 'int 'long)
             (k = 'bcp) 'int
             (k = 'flo) 'double
             (k = 'flof) 'float
             ; arithmetic: ptr - ptr is ptrdiff_t, ptr +- int the decayed pointer, both
             ; arithmetic their puac, so sizeof(c + x) folds to 4. unknown defers to gen
             (k = 'bin && elem <>e '(+ - * / % & ^ |))
              (: a (ptype ps <>>e) b (ptype ps <>>>e)
                 (? ((ptr? a || arr? a) && (ptr? b || arr? b)) (<>e = '- ? 'long)
                    (ptr? a || arr? a) (elem <>e '(+ -) ? (tdecay a))
                    (ptr? b || arr? b) (<>e = '+ ? (tdecay b))
                    (parith? a && parith? b) (puac !(pst32? ps) a b)
                    (elem <>e '(+ - * /) && (cplxty? a || cplxty? b) && a && b) (cxuac a b)
                    ()))
             ; a shift is the promoted left operand alone (C11 6.5.7)
             (k = 'bin && elem <>e '(shl shr))
              (ptype ps <>>e @ a (parith? a ? (pprom a)))
             (k = 'un && elem <>e '(neg bnot))
              (ptype ps <>>e @ a (? (parith? a) (pprom a) (cplxty? a && <>e = 'neg) a))
             ; ?: arms meet by puac (6.5.15); one non-arithmetic type rides through
             (k = 'cond)
              (: a (tdecay (ptype ps <>>e)) b (tdecay (ptype ps <>>>e))   ; an array arm decays
                 (? (parith? a && parith? b) (puac !(pst32? ps) a b)
                    (two? a && a = b) a
                    ; 6.5.15p6: beside a null pointer constant, the other's type. a cast is
                    ; one only when its operand folds, which the kernel's __is_constexpr reads
                    (npc? <>>e && ptr? b) b
                    (npc? <>>>e && ptr? a) a
                    ; both pointers, one to void: pointer to void
                    (ptr? a && ptr? b && a = '(ptr void)) a
                    (ptr? a && ptr? b && b = '(ptr void)) b
                    ()))
             ; a truth value is an int (C11 6.5.3.3, 6.5.8, 6.5.13), whatever the operand
             (k = 'un && <>e = 'not) 'int
             (k = 'bin && elem <>e '(eq ne lt le gt ge)) 'int
             (elem k '(land lor)) 'int
             ; an assignment or increment answers the lvalue's type, a comma its right side
             (elem k '(asn post)) (ptype ps <>e)
             (elem k '(rmw comma)) (ptype ps <>>e)
             ())))

   ; -- declarators. a function pointer is ('ptr ('fn ret ptys)): ptys classifies its
   ; arguments by the prototype, the only thing that tells a float from its widened double.
   (skipbal s d) (? (d < 1) s
                    (atom? s) ()
                    (peekp s "(") (skipbal >s (d + 1))
                    (peekp s ")") (skipbal >s (d - 1))
                    (skipbal >s d))
   ; a run of [const-expr] / [] suffixes -> (dims rest) | (). only the outer dim may be []
   ; (0); a parameter's [static n] drops its quals. a dim that will not fold is a VLA dim,
   ; ('vdim expr): a local allocates, a pointee scales, sizeof multiplies, else varr refuses.
   (adims ps ts2 acc) (!(peekp ts2 "[") ? [(rev acc) ts2]
                         (pquals >ts2 @ t2
                            (? (peekp t2 "]") (adims ps >t2 (0 . acc))
                               ; `[*]`: a prototype's unspecified VLA bound (C11 6.7.6.2p4)
                               (peekp t2 "*" && peekp >t2 "]") (adims ps >>t2 (0 . acc))
                               (thenw (pexpr ps t2) "]" @ er
                                  (atom? er ? ()
                                     (cfold (pw64 ps) <er @ dv
                                        (charm? dv ? (adims ps <>er (dv . acc))
                                           (adims ps <>er (['vdim <er] . acc)))))))))
   ; fold dims (outer..inner) into a nested arr: [3][4] of T -> (arr (arr T 4) 3);
   ; a 'vdim dim lays ('varr elt expr) instead
   (mkarr ety dims) (atom? dims ? ety
                       (<dims @ d
                          (two? d && <d = 'vdim ? ['varr (mkarr ety >dims) <>d]
                             ['arr (mkarr ety >dims) d])))
   (varr? ('varr . _)) 1
   (vmod? ty) (varr? ty ? 1 ((ptr? ty || arr? ty) && vmod? <>ty))   ; a VLA anywhere in the derivation
   ; the (params)/[dims] suffixes on a direct declarator -> ((name w dat bare) rest). w maps
   ; the eventual pointee to the declared type, so the type grows inside-out; dat is the
   ; name's own (params), which a fn def binds; bare: still a (paren-wrapped) name.
   (psufs ps ts name w dat bare)
    (? (peekp ts "(")
        (: rp (pparams ps >ts ())
           ; the parameter types, names dropped. a variadic prototype parks () like an
           ; unprototyped one: no `...` rides the type, and AAPCS-VFP places variadics apart
           pt9 (two? rp && !(rp 2) ? (map caup <rp))
           (atom? rp ? () (psufs ps <>rp name (t \ w ['fn t pt9]) (bare ? rp dat) ())))
       (peekp ts "[")
        (adims ps ts () @ ar
           (atom? ar ? () (psufs ps <>ar name (t \ w (mkarr t <ar)) dat ())))
       [[name w dat bare] ts])
   ; direct declarator, recursive: name | ( *.. dtor ), then suffixes, so `void (*(*x)(a))(b)`.
   ; the head may be empty (abstract `(*)(params)`). -> ((name w dat bare) rest) | ()
   (pdirect ps ts)
    (: (nstars s k) (pquals s @ s2 (peekp s2 "*" ? (nstars >s2 (k + 1)) [k s2]))
       (ptrk k t) (k < 1 ? t (ptrk (k - 1) ['ptr t]))
       (? (idat? ts) (psufs ps >ts (tkv <ts) (t \ t) () 1)
          !(peekp ts "(") (psufs ps ts () (t \ t) () ())
          ; a `(` with a type inside opens a parameter list (C11 6.7.7): `int f(int (int), int)`
          (tyat? ps >ts) (psufs ps ts () (t \ t) () ())
          (: sr (nstars >ts 0)
             k <sr t2 <>sr
             dr (pdirect ps t2)
             (atom? dr ? ()
                (: e <dr
                   r (want <>dr ")")
                   (atom? r ? ()
                      (psufs ps r <e (t \ <>e (ptrk k t)) <>>e (<>>>e && k = 0))))))))
   ; a leading `*..` run (quals interleaved) over ty -> (ty rest)
   (pstars ts ty) (pquals ts @ s (peekp s "*" ? (pstars >s ['ptr ty]) [ty s]))
   (pdtor ps ts base)                               ; -> ((name ty) rest) | ()
    ; k: the run follows a star, where alone restrict qualifies the pointer (pparams files it)
    (: (stars ts2 ty k)
        (pquals ts2 @ s
           (k && rstrq? ts2 ? (pin ps 'sawrstr 1) 0,
            peekp s "*" ? (stars >s ['ptr ty] 1) [ty s]))
       sr (stars ts base 0)
       ty <sr ts2 (pquals <>sr)           ; attrs may sit before the name
       (? (peekp ts2 "(")                            ; a parenthesized declarator: pdirect recurses;
           ; dat (the name's own params) rides out third when it is a fn
           (pdirect ps ts2 @ dr
              (atom? dr ? ()
                 (: e <dr ty2 (<>e ty) dat <>>e
                    [(two? dat ? [<e ty2 dat] [<e ty2]) <>dr])))
          !(idat? ts2)           ; an abstract declarator
           (? (peekp ts2 "[")                          ; `struct timespec const[2]`
               (adims ps ts2 () @ dr                 ; pparams decays it to a pointer
                  (atom? dr ? () [[() (mkarr ty <dr)] <>dr]))
              ; ":" is _Generic's association (pmembers takes a bitfield's first)
              (peekp ts2 ")" || peekp ts2 "," || peekp ts2 ":") [[() ty] ts2]
              ())
          (: name (tkv <ts2)
             ts3 >ts2
             (? (peekp ts3 "(")                       ; name(params): ('fn ty), the params balance-skipped
                 (skipbal >ts3 1 @ t2
                    (two? t2 ? [[name ['fn ty]] t2]))
                !(peekp ts3 "[") [[name ty] ts3]
                (adims ps ts3 () @ dr
                   (atom? dr ? ()
                      [[name (mkarr ty <dr)] <>dr]))))))

   ; -- base types: scalars, struct/union (bodies register into ps 'stag), enum, typedef names --
   ; ": const-expr" bitfield width (ts AT the ":") -> (width rest) | ()
   (pbits ps ts) (!(peekp ts ":") ? ()
                    (pasn ps >ts @ er
                       (atom? er ? ()
                          (cfold (pw64 ps) <er @ cv (charm? cv ? [cv <>er])))))
   ; the extensions ride the `moon` dialect, the default; `-std=c` fences them
   (moon? ps) (peep ps 'dia 'moon = 'moon)
   ; a label: an identifier then `:`
   (plabel? ts) (<ts @ t
                   (? (atom? ts) 0
                      (tkk t != 'id) 0
                      (peekp >ts ":")))
   (pmembers ps ts acc)                             ; member pairs ((name ty)..); () name = anonymous splice; (name ty width) = a bitfield
    (? (atom? ts) ()
       (peekp ts "}") [(rev acc) >ts]
       ; a bare `;` declares nothing; gcc takes one (C23 spells it)
       (peekp ts ";") (pmembers ps >ts acc)
       ; a static_assert is a struct-declaration declaring no member (C11 6.7.2.1)
       (sassert? ts)
        (pstatic ps ts @ r
           (two? r ? (pmembers ps <>r acc)))
       ; a struct label `name:` (moon dialect only): a virtual member naming an offset, no
       ; space. a type name is not one: `s32:32` is an anonymous bitfield
       (moon? ps && plabel? ts && !(tkbty? ps <ts))
        (tkv <ts @ nm
           (two? (want >ts ":") ? (pmembers ps >>ts ([nm 'label] . acc))))
       (pbty ps ts @ br
          (atom? br ? ()
             (: bty <br ts2 <>br
                (peekp ts2 ";" ?                   ; an anonymous struct/union member
                   (stru? bty ? (pmembers ps >ts2 ([() bty] . acc)))
                   (: mq (qspec ps ts bty)   ; _Generic's mask for this run
                      lal (specask ps ts)   ; an ask among the specifiers, every declarator's
                      (asked m a) (max lal a @ n (0 < n ? (m + [() n]) m))
                      (dfin mem2 toks acc2)          ; after a declarator (+ optional bitfield): , or ;
                       ((<mem2 && mq ? (pin ps 'qmemacc ([<mem2 mq] . peep ps 'qmemacc ())) 0),
                        (peekp toks "," ? (dts >toks (mem2 . acc2))
                           (want toks ";" @ rest
                              (two? rest ? [(mem2 . acc2) rest]))))
                      (dts ts3 acc2)                 ; dtor [: width] (, dtor [: width])* ;
                       ; an anonymous bitfield is a declarator of the list: `u32 : 31, invalid : 1;`
                       (peekp ts3 ":" ?
                          (pbits ps ts3 @ bw
                             (atom? bw ? () (dfin [() bty <bw] (pattr <>bw) acc2)))
                       (pdtor ps ts3 bty @ dr
                          (? (atom? dr) ()
                             (peekp <>dr ":")        ; a bitfield: append the width
                              (pbits ps <>dr @ bw
                                 (atom? bw ? () (dfin (<dr + [<bw]) (pattr <>bw) acc2)))
                             ; a trailing __attribute__((..)): its own ask
                             (dfin (asked <dr (pattpk ps <>dr 2)) (pattr <>dr) acc2))))
                      r (dts ts2 ())
                      ; <r and acc are both reversed (pmembers revs at "}"): prepend as is
                      (two? r ? (pmembers ps <>r (<r + acc)))))))))
   ; layout: a union flattens every offset to 0. a bitfield sits at the bit cursor, bumped to
   ; the next declared-type unit only to avoid straddling (SysV/gcc)
   (bfmem? m) (two? >>m && charm? (m 2))            ; a member carrying a width: (name ty width); (name ty () N) asks N
   ; a struct body's __attribute__((..)) run, before the tag or after the body
   ; -> (packed rest aligned): `packed` inside, and the widest `aligned` ask (0 for none)
   (pattpk ps ts)
    (!(two? ts && idv? <ts "__attribute__") ? [0 ts 0]
       (>ts @ r
          (!(peekp r "(") ? [0 ts 0]
             (: (scan s d pk al)
                 (? (atom? s || d < 1) [pk s al]
                    (peekp s "(") (scan >s (d + 1) pk al)
                    (peekp s ")") (scan >s (d - 1) pk al)
                    (tkk <s = 'id && elem (tkv <s) '("packed" "__packed__")) (scan >s d 1 al)
                    (tkk <s = 'id && elem (tkv <s) '("aligned" "__aligned__"))
                     (palask ps >s @ a (scan <>a d pk (max al <a)))
                    (scan >s d pk al))
                r2 (scan >r 1 0 0)
                nx (pattpk ps <>r2)
                [(<r2 | <nx) <>nx (max (r2 2) (nx 2))]))))
   ; an aligned ask raises a laid struct's alignment, and its size rounds up to it
   (alask lay a) (a > lay 2 ? [<lay (a * ((lay 1 + a - 1) // a)) a] lay)
   ; a member type with no size yet (C11 6.7.2.1p3): a struct not laid out, or an array of one
   (incty? ps ty) (? (arr? ty) (incty? ps <>ty) (stru? ty) (atom? (peep (ps 'stag) <>ty 0)) ())
   (playout ps ms uni pk)                           ; -> (fields size align); pk: packed, every member aligns 1
    (: cap (peep ps 'pack 0)                         ; #pragma pack's cap on a member's alignment
       (capa x) (0 < cap && cap < x ? cap x)
       (go l bit mx acc)
        (atom? l ?
           (: a2 (mx < 1 ? 1 mx)
              [(rev acc) (aup (>> (bit + 7) 3) a2) a2])
           (: m <l name <m ty <>m
              (? (ty = 'label)
                 ; a zero-length char array, so `s.hdr` decays and stays an lvalue. it aligns
                 ; as the next member, or at the end as the struct, so it then equals sizeof
                 (: (nxt r) (atom? r ? () (<>(<r) @ t2 (t2 = 'label ? (nxt >r) t2)))
                    nt (nxt >l)
                    la (? pk 1 nt (capa (talign ps nt)) (mx < 1 ? 1 mx))
                    at (uni ? 0 (aup bit (la * 8) >> 3))   ; a union flattens every offset
                    (go >l bit mx ([name at ['arr 'char 0]] . acc)))
                 (bfmem? m)                          ; a bitfield member: (name ty width)
                 (: w <>>m
                    usz (tsz ps ty) ubits (usz * 8) a (talign ps ty)
                    _ (0 < cap && cap < a && pin ps 'packbf 1)    ; gcc lets these straddle units; refused
                    _ (w > ubits && pin ps 'widebf 1)             ; wider than its type: C's constraint
                    nmx (pk || a <= mx ? mx a)                    ; packed: the unit asks no alignment
                    ; packed: the bits run on from the cursor; the unit is the n bytes they touch
                    pn (((& bit 7) + w + 7) >> 3)
                    _ (pk && pn > 8 && pin ps 'pkwidebf 1)
                    ; `:0` aligns the cursor off a union; AAPCS also raises the struct's alignment
                    za (paapcs? ps && mx < a ? a mx)
                    (? (w = 0) (go >l (uni ? bit (aup bit (a * 8))) za acc)
                       (uni && pk) (: fld (name ? [name 0 ['bitfield ty 0 w ((w + 7) >> 3)]])
                                      (go >l (bit < w ? w bit) nmx (name ? (fld . acc) acc)))
                       uni (: fld (name ? [name 0 ['bitfield ty 0 w]])
                              (go >l (bit < ubits ? ubits bit) nmx (name ? (fld . acc) acc)))
                       pk (: fld (name ? [name (bit >> 3) ['bitfield ty (& bit 7) w pn]])
                             (go >l (bit + w) nmx (name ? (fld . acc) acc)))
                       (: bit2 ((& bit (ubits - 1)) + w > ubits ? (aup bit ubits) bit)   ; bump to avoid straddling the unit
                          uoff (& (bit2 >> 3) (0 - usz))              ; the aligned unit holding the bits
                          bitoff (bit2 - uoff * 8)
                          fld (name ? [name uoff ['bitfield ty bitoff w]])   ; anonymous -> reserve bits, no field
                          (go >l (bit2 + w) nmx (name ? (fld . acc) acc)))))
                 !name                               ; the anonymous struct/union splice
                 (: inner (peep (ps 'stag) <>ty 0)
                    ia (pk ? 1 (capa <>>inner))
                    isz <>inner
                    sbit (uni ? 0 (aup bit (ia * 8)))
                    at (sbit >> 3)
                    (spl fs acc2) (atom? fs ? acc2
                                     (<fs @ f
                                        (spl >fs ([<f (at + <>f) <>>f] . acc2))))
                    nmx (mx < ia ? ia mx)
                    nbit (uni ? (bit < isz * 8 ? (isz * 8) bit) (sbit + isz * 8))
                    (go >l nbit nmx (spl <inner acc)))
                 (incty? ps ty) (: _ (peep ps 'incmem () || pin ps 'incmem name)
                                   (go >l bit mx acc))
                 (: a (max (pk ? 1 (capa (talign ps ty))) (two? >>>m ? (m 3) 0))   ; an ask outranks packed, as gcc has it
                    sz (tsz ps ty)
                    abit (uni ? 0 (aup bit (a * 8)))
                    at (abit >> 3)
                    nmx (mx < a ? a mx)
                    nbit (uni ? (bit < sz * 8 ? (sz * 8) bit) (abit + sz * 8))
                    (go >l nbit nmx ([name at ty] . acc))))))
       (go ms 0 0 ()))
   (panon ps) (peep ps 'anon 0 @ k (pin ps 'anon (k + 1), ".anon\(k)"))
   ; a block's tag (C11 6.7.2.3) cannot be scoped like an enum constant: gen lays by the key
   ; long after the brace. so a key is minted, `.`-led so clay calls the block inexpressible.
   ; spin: a scoped binding into tbl, the old value a shadow entry in ps 'scopacc
   (spin ps tbl nm v)
    (peep (ps tbl) nm 'none @ old
       (pin ps 'scopacc ([tbl nm old] . peep ps 'scopacc ()),
        pin (ps tbl) nm v))
   (ptagkey ps nm)
    (peep ps 'blkd 0 < 1 ? nm
       (: k (peep ps 'anon 0)
          _ (pin ps 'anon (k + 1))
          key ".\(nm).\(k)"
          (spin ps 'tags nm key,
           key)))
   ; ..and a bare `struct T` reads the innermost block tag, else the bare name -- never a
   ; fresh incomplete tag as C says: accepts more, never less
   (tagref ps nm) (peep (ps 'tags) nm nm)
   ; ps 'lmode: a leading attribute run's mode, taken by the first base type after it
   (pbty ps ts0)
    (peep ps 'lmode () @ lm
     (lm != () ? (pin ps 'lmode ()) 0,
      pbty0 ps ts0 @ r
       (atom? r ? r
          (modeat ps ts0 @ m0 (m0 = () ? lm m0) @ m
             (? (m = ()) r
                (m = 'many) (clblame "__attribute__((mode)) on a declaration of several declarators is not carried out")
                (m = 'deriv) (clblame "__attribute__((mode)) on a pointer, array or function declarator is not carried out")
                (modety ps m <r @ ty (string? ty ? (clblame ty) (ty . >r))))))))
   (pbty0 ps ts0)
    (pquals ts0 @ ts
     (atom? ts ? ()
       (<ts @ t
          (? (tkk t = 'kw && elem (tkv t) tyspec)         ; a run of type specifiers -> one canonical type
              (: (grab l acc) (two? l && tkk <l = 'kw && elem (tkv <l) tyspec ?
                                 (grab >l (tkv <l . acc))
                                 ; a qualifier inside the run (`unsigned const char`) is skipped
                                 (pquals l @ l2
                                    (two? l2 && tkk <l2 = 'kw && elem (tkv <l2) tyspec ?
                                       (grab l2 acc)
                                       [(rev acc) l])))
                 r (grab ts ())
                 [(canon ps <r) <>r])
             (tkw? t 'struct || tkw? t 'union)
              (: uni (tkw? t 'union)
                 ; an attribute run may precede the tag; unread, it would be the tag name
                 pb (pattpk ps >ts)
                 ts2 <>pb
                 tag (idat? ts2 ? (tkv <ts2))
                 ts3 (tag ? >ts2 ts2)
                 (peekp ts3 "{" ?
                    ; the key binds before the body: `struct T { struct T *n; }` means itself
                    (: tag2 (tag ? (ptagkey ps tag) (panon ps))
                       qpre (ps 'qmemacc)    ; _Generic's member marks stack with the bodies
                       mr (pmembers ps >ts3 ())
                       (atom? mr ? ()
                          (: pa (pattpk ps <>mr)       ; a trailing packed lays align-1
                             lay (alask (playout ps <mr uni (<pb | <pa)) (max (pb 2) (pa 2)))
                             tu (uni && attrany? <>mr "transparent_union" "__transparent_union__")
                             (? (peep ps 'packbf ()) (pin ps 'packbf (), clblame "a bit-field under #pragma pack is not carried out")
                                (peep ps 'widebf ()) (pin ps 'widebf (), clblame "the width of a bit-field exceeds its type")
                                (peep ps 'pkwidebf ()) (pin ps 'pkwidebf (), clblame "a packed bit-field spanning more than 8 bytes is not carried out")
                                (peep ps 'incmem ()) (ps 'incmem @ n (pin ps 'incmem (), clblame "field '\(n)' has incomplete type"))
                                (tu && !(tuok? ps lay)) (clblame "a transparent union wants members of one word-sized scalar type")
                             (pin (ps 'stag) tag2 lay,
                              uni ? (pin (ps 'utag) tag2 1) 0,
                              tu ? (pin (ps 'tunion) tag2 1) 0,
                              qmempin ps tag2 qpre,
                              [['struct tag2] <>pa])))))
                    (tag ? [['struct (tagref ps tag)] ts3])))
             (tkw? t 'enum)
              ; unsigned when no enumerator is negative (gcc), seen in a bit-field: `enum c
              ; code : 8` holding 148 loads 148. an attribute run may precede the tag
              (: hp (pattpk ps >ts) lpk <hp
                 ts2 <>hp
                 tag (idat? ts2 ? (tkv <ts2))
                 ts3 (tag ? >ts2 ts2)
                 ; an enum tag scopes by restoring, not renaming: the type is a plain integer.
                 ; AAPCS32 or a packed enum takes the smallest type holding every enumerator,
                 ; others int; past 32 bits both widen
                 (ety pos lo hi pk m)
                  (: wide (? (pos && 4294967295 < hi) 'ulong
                             (!pos && (hi > 2147483647 || lo < -2147483648)) 'long ())
                     narrow (? pos (? (hi <= 255) 'uchar (hi <= 65535) 'ushort 'uint)
                               (-128 <= lo && hi <= 127) 'char
                               (-32768 <= lo && hi <= 32767) 'short
                               'int)
                     ty0 (? wide wide
                            (pst32? ps && !(elem (ps 'tgt) '(i386 i386m16)) || pk) narrow   ; AAPCS32's short enums; SysV i386 says int
                            pos 'uint 'int)
                     ; mode(M): M's width, signedness kept; refused if an enumerator won't fit
                     ty (? (m = ()) ty0
                           (m = 'many) (clblame "__attribute__((mode)) on a declaration of several declarators is not carried out")
                           (m = 'deriv) (clblame "__attribute__((mode)) on a pointer, array or function declarator is not carried out")
                           (modety ps m (pos ? 'uint 'int) @ mt
                              (? (string? mt) (clblame mt)
                                 (tsz ps mt @ n (8 * n - (pos ? 0 1) @ b
                                    (lo < -(2 ** b) || (2 ** b) <= hi)))
                                  (clblame "an enumerator does not fit the enum's __attribute__((mode))")
                                 mt)))
                     (? (ty = ()) ()
                        ; a name typed ahead as uint cannot become another width
                        (tag && peep (ps 'efwd) tag 0 && ty != 'uint)
                         (clblame "an enum named before its definition lays other than unsigned int here")
                        (tag ? (spin ps 'etag tag ty) 0,
                         ty)))
                 (peekp ts3 "{" ?
                    (: (consts ts4 v pos lo hi)
                        (? (peekp ts4 "}")                         ; a trailing comma, or an empty body
                            (pattpk ps >ts4 @ pa (ety pos lo hi (max <pa lpk) (modeat ps >ts4) @ ty (ty = () ? () [ty <>pa])))
                           !(idat? ts4) ()
                           (: name (tkv <ts4)
                              ts5 >ts4
                              vr (peekp ts5 "=" ?
                                    (pasn ps >ts5 @ er              ; = const-expr, folded
                                       (atom? er ? ()
                                          (cfold (pw64 ps) <er @ cv
                                             ; a wide enumerator widens the type, as gcc's
                                             (cint? cv ? [cv <>er]))))
                                    [v ts5])
                              (atom? vr ? ()
                                 (: _ (spin ps 'enums name <vr)
                                    ts6 <>vr
                                    pos2 (pos && !(<vr < 0))
                                    lo2 (<vr < lo ? <vr lo)   hi2 (hi < <vr ? <vr hi)
                                    (peekp ts6 "," ? (consts >ts6 (<vr + 1) pos2 lo2 hi2)
                                       (: rest (want ts6 "}")
                                          pa (two? rest ? (pattpk ps rest) [0 rest])
                                          (two? rest ? (ety pos2 lo2 hi2 (max <pa lpk) (modeat ps rest) @ ty (ty = () ? () [ty <>pa])))))))))
                       (consts >ts3 0 1 0 0))
                    ; a tag not yet defined reads uint, gcc's non-negative enum; its definition must agree
                    (tag && !(peep (ps 'etag) tag ()) ? (spin ps 'efwd tag 1) 0,
                     [(peep (ps 'etag) tag 'uint) ts3])))
             (tkk t = 'id && (peep (ps 'types) (tkv t) 0 ? 1))
              [(peep (ps 'types) (tkv t) 0) >ts]
             ; __auto_type NAME = init: the initializer's type, the cursor left at the name.
             ; attributes may stand before the = (linux's scoped guards)
             (tkk t = 'id && tkv t = autoid)
              (>ts @ r1
                 (: (atts l) (? (two? l && idv? <l "__attribute__" && peekp >l "(") (skipbal >>l 1 @ e (atts e)) l)
                    r2 (two? r1 ? (atts >r1) r1)
                 (? !(idat? r1) ()
                    !(peekp r2 "=") ()
                    (pasn ps >r2 @ er
                       (atom? er ? ()
                          (ptype ps <er @ ty
                             (ty ? [ty r1])))))))
             ; __typeof(expr | type-name): pcty for a type-name, ptype for an expression
             (tkk t = 'id && elem (tkv t) tyofid)
              (want >ts "(" @ r1
                 (? (atom? r1) ()
                    (tyat? ps r1) (thenw (pcty ps r1) ")")
                    (thenw (pasn ps r1) ")" @ er
                       (atom? er ? ()
                          (ptype ps <er @ ty
                             (ty ? [ty <>er]))))))
             ()))))
   ; a type-name (casts, sizeof): base + an abstract declarator, `T (*)(params)` included
   (pcty ps ts)
    (pbty ps ts @ br
       (atom? br ? ()
          (pdtor ps <>br <br @ dr
             (two? dr ? [<><dr <>dr]))))

   (pdecay ty) (? (arr? ty) ['ptr <>ty] (fn? ty) ['ptr ty] ty)   ; _Generic's lvalue conversion
   ; -- the qualifiers _Generic needs (6.5.1.1). types here carry no const/volatile, so its
   ; marked copy lives in ps 'qtys, shadowed with 'locals: ('cq q t) over the leaf, q a mask
   ; of 1=const 2=volatile. only the specifier run's are seen: matches more, never less.
   (cq? ('cq . _)) 1
   (qmark q ty) (? !q ty
                   (ptr? ty) ['ptr (qmark q <>ty)]
                   (arr? ty) ['arr (qmark q <>ty) <>>ty]
                   ['cq q ty])
   (qstrip ty) (? (cq? ty) (qstrip <>>ty)
                  (ptr? ty) ['ptr (qstrip <>ty)]
                  (arr? ty) ['arr (qstrip <>ty) <>>ty]
                  ty)
   (qbare ty) (cq? ty ? <>>ty ty)         ; lvalue conversion drops the top-level qualifier
   ; one token's const/volatile bit; restrict rides (ps 'rstrs) instead
   (cvq t) (? (tkk t = 'kw && tkv t = 'const) 1
              (idv? t "__const") 1
              (tkk t = 'kw && tkv t = 'volatile) 2
              (tkk t = 'id && elem (tkv t) '("__volatile__" "__volatile")) 2
              0)
   ; the specifier run read twice: its own const/volatile, and its typedef name's
   ; (`typedef const char *ccp`). -> (own typedef's). sawty stops at the declarator's name
   (qrun ps ts)
    (: (go l sawty)
        (atom? l ? [0 0]
           (<l @ t
              (? (tkk t = 'kw && (elem (tkv t) qualkw || elem (tkv t) tyspec))
                  (go >l (sawty || elem (tkv t) tyspec) @ r [(<r | cvq t) <>r])
                 (tkk t != 'id) [0 0]
                 sawty [0 0]
                 (elem (tkv t) qualid) (go (qskip l) sawty)
                 (: q (peep (ps 'qtdef) (tkv t) 0)
                    r (go >l 1)
                    [<r (<>r | q)]))))
       (go ts ()))
   ; the widest alignment ask in a specifier run, walked as qrun walks it; 0 for none
   (specask ps ts)
    (: (go l sawty a)
        (atom? l ? a
           (<l @ t
              (? (tkk t = 'kw && (elem (tkv t) qualkw || elem (tkv t) tyspec)) (go >l (sawty || elem (tkv t) tyspec) a)
                 (tkk t != 'id) a
                 (tkv t = "__attribute__") (pattpk ps l @ r (go <>r sawty (max a (r 2))))
                 (tkv t = "_Alignas") (go (qskip l) sawty (max a (alignat? ps l @ n (n ? n 0))))
                 (elem (tkv t) qualid) (go (qskip l) sawty a)
                 sawty a
                 (go >l 1 a))))
       (go ts () 0))
   ; a qualifier after the last star qualifies the pointer (`int * const`): a row no
   ; lvalue-converted expression matches
   (qtop? ts)
    (: (go l q) (? (atom? l) q
                   (tp? <l "*") (go >l ())
                   (0 < cvq <l) (go >l 1)
                   (qual? <l) (go >l q)
                   q)
       (go ts ()))
   ; the mask a run lays on its type's leaf: its own plus its typedef's, but over a pointer
   ; typedef only the typedef's: `typedef char *cp; const cp x` is a const pointer
   (qspec ps ts base) (qrun ps ts @ r (ptr? base ? <>r (<r | <>r)))
   ; drain the marks pmembers staged since qpre onto tag, restoring the stage
   (qmempin ps tag qpre)
    (: now (ps 'qmemacc)
       (go l k) (k < 1 ? 0
                   (pin (ps 'qmem) (tag + "." + <<l) <><l, go >l (k - 1)))
       (go now (#now - #qpre),
        pin ps 'qmemacc qpre))
   ; a type-name for an association: pcty's answer marked, plus that top-level bit.
   ; -> (ty topq rest) | ()
   (pcqty ps ts)
    (pbty ps ts @ br
       (atom? br ? ()
          (: dts <>br
             bq (qspec ps ts <br)
             dr (pdtor ps dts <br)
             (atom? dr ? ()
                (<><dr @ ty
                   [(qmark bq ty) (qtop? dts) <>dr])))))
   ; the controlling expression's marked type, else ptype's unqualified one
   (qtype ps e)
    (ptype ps e @ p
       (atom? e ? p
          (<e @ k
             (? (k = 'var) (peep (ps 'qtys) <>e 'none @ q (q = 'none ? p q))
                (k = 'deref) (qtype ps <>e @ it (ptr? it || arr? it ? <>it p))
                (k = 'addr) (qtype ps <>e @ it (it ? ['ptr it] p))
                (k = 'dot) (qtype ps <>e @ bt
                              (!(stru? (qstrip bt)) ? p
                                 (qmark (peep (ps 'qmem) (<>(qstrip bt) + "." + <>>e) 0) p)))
                p))))
   ; ..and a cast's mark is on file nowhere: re-read its type-name off the tokens, taken
   ; only when it strips back to the type the node kept
   (qctl ps ts e)
    (qtype ps e @ p
       (? !(two? e && <e = 'cast) p
          !(ptyat? ps ts) p
          (pcqty ps >ts @ cr
             (two? cr && qstrip <cr = p ? <cr p))))
   ; _Generic's associations: `type-name : expr` rows, `default` wearing 'dflt.
   ; a row is (ty topq expr). -> (rows rest) | ()
   (pgarms ps ts)
    (: tr (tkw? <ts 'default ? ['dflt () >ts] (pcqty ps ts))
       rk (two? tr ? (want <>>tr ":"))
       er (two? rk ? (pasn ps rk))
       (atom? er ? ()
          (: r <>er row [<tr <>tr <er]
             (!(peekp r ",") ? [[row] r]
                (pgarms ps >r @ more
                   (two? more ? [(row . <more) <>more]))))))
   ; the selected expression, presence-wrapped. equality is structural over the marked type,
   ; so `const int *` and `int *` are two rows; a top-level-qualified row matches nothing.
   (gpick rows ty)
    (: (go l w) (atom? l ? w                       ; w: the default so far
                   (: r <l t <r q <>r e <>>r
                      (!q && t = ty ? [1 e] (go >l (t = 'dflt ? [1 e] w)))))
       (go rows ()))

   ; complex usual arithmetic conversion (C99 6.3.1.8): a real side rises to {x, 0}, a
   ; single-eval clit, so gen's complex lane only meets complex operands
   (cxwrap ty x) ['clit ty ['init [x '(flo 0.0)]]]
   ; the complex type two operands meet at: double if either side is, else float
   (cxuac ta tb) (elem '(struct "__cplx_double") [ta tb] || elem 'double [ta tb] ?
                    '(struct "__cplx_double") '(struct "__cplx_float"))
   ; a real divisor divides each part in gen; a complex one calls __divsc3/__divdc3 on
   ; the four parts, an impure operand parked first
   (cxdiv ps l r ta tb)
    (: w (cxuac ta tb) b (w = '(struct "__cplx_float") ? 'float 'double)
       nm (b = 'float ? "__divsc3" "__divdc3")
       _ (peep (ps 'sigs) nm () ? 0 (pin (ps 'sigs) nm [w [b b b b] ()]))
       (side x t) (elvpure? x ? [x ()]
                     (: n (1 + peep ps 'cxdn 0) _ (pin ps 'cxdn n) v "__cxdiv_\(n)"
                        [['var v] [['decl [[v t x]]]]]))
       (part x t f) (t = w ? ['dot x f] ['cast b ['dot x f]])     ; a float side widens per part
       sl (side l ta) sr (side r tb)
       call ['call ['var nm] [(part <sl ta "re") (part <sl ta "im") (part <sr tb "re") (part <sr tb "im")]]
       (two? (<>sl + <>sr) ? ['sexpr (<>sl + <>sr) call w] call))
   (mkbin ps op l r)
    (: tl (ptype ps l) tr (ptype ps r)
       cl (cplxty? tl) cr (cplxty? tr)
       (? (cl && !cr && tr && !(ptr? tr || arr? tr || stru? tr))
           (op = '/ ? ['bin op l r] ['bin op l (cxwrap (cxuac tl tr) r)])
          (cr && !cl && tl && !(ptr? tl || arr? tl || stru? tl))
           (cxuac tl tr @ w (op = '/ ? (cxdiv ps (cxwrap w l) r w tr) ['bin op (cxwrap w l) r]))
          (cl && cr && op = '/) (cxdiv ps l r tl tr)
          ['bin op l r]))

   ; primary := num | str | id (an enum constant folds here) | ( expr )
   (pprim ps ts)
    (atom? (mark ts) ? ()         ; a bad operand reports itself
       (<ts @ t
          (? (tkk t = 'num && pchar ps = 'char && chq? t && 127 < tkv t && tkv t < 256)   ; 'c' is (int) (char) c
              [['num (tkv t - 256)] >ts]
             (tkk t = 'num)                           ; past int on t32: long long
              [(pst32? ps && 2147483647 < tkv t ? ['cast 'llong ['num (tkv t)]] ['num (tkv t)]) >ts]
             (tkk t = 'unum)                          ; u: unsigned int (neg/div/shift go unsigned)
              [['cast 'uint ['num (tkv t)]] >ts]
             (tkk t = 'ulnum)                                   ; ul: ulong; on t32 past the word, ullong
              (: v (tkv t)
                 uty (pst32? ps && (v < 0 || 4294967295 < v) ? 'ullong 'ulong)     ; C99 6.4.4.1
                 [['cast uty ['num v]] >ts])
             (tkk t = 'ullnum)                                  ; ull: 64 bits on t32
              [['cast (pst32? ps ? 'ullong 'ulong) ['num (tkv t)]] >ts]
             (tkk t = 'llnum)                                   ; 1ll: llong on t32, long elsewhere
              [['cast (pst32? ps ? 'llong 'long) ['num (tkv t)]] >ts]
             ; l/L makes a long (C11 6.4.4.1); on t32 past the word, hex/octal ulong, else llong
             (tkk t = 'lnum)
              (: v (tkv t) sp (t 4)
                 dec !(sp 0 = 48 && 1 < #sp && !(elem (sp 1) '(108 76 117 85)))
                 ty (? !(pst32? ps && 2147483647 < v) 'long
                       (!dec && v <= 4294967295) 'ulong
                       'llong)
                 [['cast ty ['num v]] >ts])
             (tkk t = 'flo) [['flo (cflo (tkv t))] >ts]
             ; an f suffix (C11 6.4.4.2): cflo32 rounds to binary32 once and the cast keeps float
             (tkk t = 'flof) [['cast 'float ['flo (cflo32 (tkv t))]] >ts]
             ; an imaginary literal is {0, v}, complex-double (complex floats compute as doubles)
             (tkk t = 'iflo)
              [['clit '(struct "__cplx_double") ['init ['(flo 0.0) ['flo (cflo (tkv t))]]]] >ts]
             (tkk t = 'str) [['str (tkv t)] >ts]
             ; a wide literal is a bounded compound literal of its element type. L -> wchar
             ; (int, uint on arm), u -> char16 (ushort, surrogate pairs), U -> char32 (uint)
             (elem (tkk t) '(wstr str16 str32))
              (: ety (? (tkk t = 'str16 || ps 'swch) 'ushort
                        (tkk t = 'str32) 'uint
                        (elem (ps 'tgt) '(a64 thumb2 thumb2sp arm thumb1)) 'uint
                        'int)
                 (s16 l) (? (atom? l) ()
                            (65536 <= <l) (<l - 65536 @ v
                                             (55296 + (v >> 10) . 56320 + (v & 1023) . s16 >l))
                            (<l . s16 >l))
                 cps (utf8dec (tkv t) @ raw (ety = 'ushort ? (s16 raw) raw))
                 (nums l) (atom? l ? [['num 0]] (['num <l] . nums >l))
                 [['clit ['arr ety (#cps + 1)] ['init (nums cps)]] >ts])
             ; _Generic (C11 6.5.1.1): the controlling expression is typed, never evaluated
             (idv? t "_Generic")
              (: r1 (want >ts "(")
                 rc (two? r1 ? (pasn ps r1))
                 r2 (two? rc ? (want <>rc ","))
                 ga (two? r2 ? (pgarms ps r2))
                 rest (two? ga ? (want <>ga ")"))
                 hit (two? rest ? (gpick <ga (qbare (pdecay (qctl ps r1 <rc)))))
                 (two? hit ? [<>hit rest]))
             ; va_arg's second operand is a type, so the va builtins skip the call path
             (idv? t "__builtin_va_arg")
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 r2 (two? ra ? (want <>ra ","))
                 tr (two? r2 ? (pcty ps r2))
                 rest (two? tr ? (want <>tr ")"))
                 (two? rest ? [['vaarg <ra <tr] rest]))
             (idv? t "__builtin_va_start")
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 r2 (two? ra ? (want <>ra ","))
                 rb (two? r2 ? (pasn ps r2))         ; the last named param (unused)
                 rest (two? rb ? (want <>rb ")"))
                 (two? rest ? [['vastart <ra] rest]))
             (idv? t "__builtin_va_end")
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 rest (two? ra ? (want <>ra ")"))
                 (two? rest ? [['vaend <ra] rest]))
             ; va_copy: a va_list is an array of one tag, so the copy is `*dst = *src`
             (idv? t "__builtin_va_copy")
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 r2 (two? ra ? (want <>ra ","))
                 rb (two? r2 ? (pasn ps r2))
                 rest (two? rb ? (want <>rb ")"))
                 (two? rest ? [['asn ['deref <ra] ['deref <rb]] rest]))
             ; __builtin_strcmp over two literals answers at parse; else strcmp's call
             (tkk t = 'id && bib? (tkv t) && tkv t = "__builtin_strcmp")
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 r2 (two? ra ? (want <>ra ","))
                 rb (two? r2 ? (pasn ps r2))
                 rest (two? rb ? (want <>rb ")"))
                 a <ra b <rb
                 (? (atom? rest) ()
                    (<a = 'str && <b = 'str) [['num (<>a @ x (<>b @ y (? (x = y) 0 (x < y) -1 1)))] rest]
                    (peep (ps 'sigs) "strcmp" () ? 0 (pin (ps 'sigs) "strcmp" (libsig ps "strcmp")),
                     [['call ['var "strcmp"] [a b]] rest])))
             ; a library builtin is its plain name, declared if nothing else has
             (tkk t = 'id && tkv t = "__builtin_alloca")
              (peep (ps 'sigs) (tkv t) () ? 0 (pin (ps 'sigs) (tkv t) (libsig ps "alloca")),
               [['var (tkv t)] >ts])
             (tkk t = 'id && bib? (tkv t) && elem (tkv t) libbin)
              (snip (tkv t) 10 #(tkv t) @ nm
                 (peep (ps 'sigs) nm () ? 0 (pin (ps 'sigs) nm (libsig ps nm)),
                  [['var nm] >ts]))
             ; the type-level builtins answer a constant at parse: their operands are types or
             ; never evaluated. offsetof seeds &((T*)0)->NAME, takes the postfix tail and folds
             ; through nulloff; a runtime index folds nowhere and the address is the answer
             (tkk t = 'id && bib? (tkv t) && tkv t = "__builtin_offsetof")
              (: r1 (want >ts "(")
                 tr (two? r1 ? (pcty ps r1))
                 r2 (two? tr ? (want <>tr ","))
                 nm (idat? r2 ? (tkv <r2))
                 dr (nm ? (ppostfrom ps ['dot ['deref ['cast ['ptr <tr] '(num 0)]] nm] >r2))
                 rest (two? dr ? (want <>dr ")"))
                 off (two? rest ? (nulloff ps <dr))
                 (? (charm? off) [['cast (szty ps) ['num off]] rest]
                    (two? rest) [['cast (szty ps) ['addr <dr]] rest]
                    ()))
             ; __builtin_types_compatible_p: structural equality, no decay (__must_be_array)
             (tkk t = 'id && bib? (tkv t) && tkv t = "__builtin_types_compatible_p")
              (: r1 (want >ts "(")
                 ta (two? r1 ? (pcqty ps r1))
                 r2 (two? ta ? (want <>>ta ","))
                 tb (two? r2 ? (pcqty ps r2))
                 rest (two? tb ? (want <>>tb ")"))
                 ; marked types, so `const char *` is not `char *`; the top-level one drops
                 (two? rest ? [['num (qbare <ta = qbare <tb ? 1 0)] rest]))
             ; __builtin_constant_p: 1 when the operand folds now, else ('bcp e) for gen to settle
             ; after inlining, a constant context reading 0 (the safe end). never evaluated.
             (tkk t = 'id && bib? (tkv t) && tkv t = "__builtin_constant_p")
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 rest (two? ra ? (want <>ra ")"))
                 (two? rest ? [(charm? (cfold (pw64 ps) <ra) ? ['num 1] ['bcp <ra]) rest]))
             ; __builtin_object_size and its dynamic spelling: gcc's unseen-object answer,
             ; (size_t)-1 for types 0/1, 0 for 2/3, where fortify checks stand down
             (tkk t = 'id && bib? (tkv t) &&
              elem (tkv t) '("__builtin_object_size" "__builtin_dynamic_object_size"))
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 r2 (two? ra ? (want <>ra ","))
                 rb (two? r2 ? (pasn ps r2))
                 rest (two? rb ? (want <>rb ")"))
                 tv (two? rb ? (cfold (pw64 ps) <rb))
                 (atom? rest ? ()
                    [['cast (szty ps) ['num (charm? tv && 1 < tv ? 0 -1)]] rest]))
             ; __builtin_assume_aligned(p, a[, off]) is p, the promise dropped;
             ; __builtin_extract_return_addr(a) is a (no signed return addresses)
             (tkk t = 'id && bib? (tkv t) &&
              elem (tkv t) '("__builtin_assume_aligned" "__builtin_extract_return_addr"))
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 (tail l) (? (atom? l) () (peekp l ")") >l
                             (peekp l ",") (pasn ps >l @ r (two? r ? (tail <>r)))
                             ())
                 rest (two? ra ? (tail <>ra))
                 (two? rest ? [['cast '(ptr void) <ra] rest]))
             ; __builtin_parity{,l,ll}(x): the popcount's low bit
             (tkk t = 'id && bib? (tkv t) &&
              elem (tkv t) '("__builtin_parity" "__builtin_parityl" "__builtin_parityll"))
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 rest (two? ra ? (want <>ra ")"))
                 pc "__builtin_popcount\(snip (tkv t) 16 #(tkv t))"
                 (two? rest ? [(mkbin ps '& ['call ['var pc] [<ra]] ['num 1]) rest]))
             ; __builtin_choose_expr(c,a,b): c must fold; the unchosen arm is parsed and dropped
             (tkk t = 'id && bib? (tkv t) && tkv t = "__builtin_choose_expr")
              (: r1 (want >ts "(")
                 rc (two? r1 ? (pasn ps r1))
                 r2 (two? rc ? (want <>rc ","))
                 ra (two? r2 ? (pasn ps r2))
                 r3 (two? ra ? (want <>ra ","))
                 rb (two? r3 ? (pasn ps r3))
                 rest (two? rb ? (want <>rb ")"))
                 cv (two? rc ? (cfold (pw64 ps) <rc))
                 (? (atom? rest) ()
                    !(charm? cv) (blame r1 "__builtin_choose_expr wants a constant condition")
                    [(cv = 0 ? <rb <ra) rest]))
             ; __func__ (C99 6.4.2.2) and gcc's spellings: the enclosing function's name, pinned
             ; by the two body-parsing sites; outside a body an undeclared identifier
             (tkk t = 'id && elem (tkv t) '("__func__" "__FUNCTION__" "__PRETTY_FUNCTION__") && string? (ps 'fnname))
              [['str (ps 'fnname)] >ts]
             ; a name being declared right now is not an enum constant (C11 6.2.1p7): in
             ; `int N = g(), n = N * 2;` N is the local
             (tkk t = 'id)
              (: nm (tkv t)
                 ev (peep (ps 'declaring) nm () ? () (peep (ps 'enums) nm ()))
                 (cint? ev ? [['num ev] >ts]
                    [['var nm] >ts]))
             ; ({ .. }): gcc's statement expression -- the leading statements, and the last as
             ; its value when it is an expression, else void
             (tp? t "(" && peekp >ts "{")
              (pblock ps >ts @ br
                 (atom? br ? ()
                    (: rest (want <>br ")")
                       items (two? <br && <<br = 'blk ? <><br [<br])
                       (lst l) (? (atom? l) () (atom? >l) <l (lst >l))
                       (butl l) (? (atom? l) () (atom? >l) () (<l . butl >l))
                       lv (lst items)
                       val? (two? lv && <lv = 'expr)
                       ty0 (val? ? (ps 'blkval))         ; pblock typed it in scope
                       (? (atom? rest) ()
                          val? [['sexpr (butl items) <>lv (ty0 ? ty0 'long)] rest]
                          [['sexpr items () 'void] rest]))))
             (tp? t "(") (thenw (pexpr ps >ts) ")")
             ())))
   ; postfix: calls, indexing, members, ++/--
   (pargs ps ts acc)
    (peekp ts ")" ? [(rev acc) >ts]
       (pasn ps ts @ r
          (? (atom? r) ()
             (peekp <>r ",") (pargs ps ><>r (<r . acc))
             (want <>r ")" @ rest
                (two? rest ? [(rev (<r . acc)) rest])))))
   ; tuargs: a transparent union parameter takes any member's type, the argument laid as the
   ; union through its first member. bicall: __builtin_isdigit(c) is (unsigned)(c - '0') < 10.
   ; ppostfrom: the suffix run from a seed, a primary or a compound literal
   (tuok? ps lay) (: w (pw64 ps ? 8 4)
                     (<>lay = w && all (f \ (f 2 @ t (ptr? t || elem t '(long ulong int uint))) && tsz ps (f 2) = w) <lay))
   (tuargs ps e as)
    (: sg (e @ ('var nm) (peep (ps 'sigs) nm ()) ())
       (wrap a pt) (pt @ (('struct tag) && peep (ps 'tunion) tag ())
                      (ptype ps a @ at (stru? at ? a
                         ['clit pt ['init [['cast (<<(peep (ps 'stag) tag ()) 2) a]]]]))
                      a)
       (go l ps9) (? (atom? l) () (atom? ps9) l (wrap <l <ps9 . go >l >ps9))
       (two? sg ? (go as (sg 1)) as))
   (bicall e as)
    (e = ['var "__builtin_isdigit"] && two? as && atom? >as ?
        ['bin 'lt ['cast 'uint ['bin '- <as '(num 48)]] '(num 10)]
       ['call e as])
   (ppostfrom ps e0 ts0)
    (: (more e ts2)
              (? (peekp ts2 "(")                     ; the head is any postfix expr
                  (pargs ps >ts2 () @ ra
                     (two? ra ? (more (bicall e (tuargs ps e <ra)) <>ra) [() ()]))
                 (peekp ts2 "[")
                  (thenw (pexpr ps >ts2) "]" @ ri
                     (two? ri ? (more ['deref ['bin '+ e <ri]] <>ri) [() ()]))
                 (peekp ts2 ".")
                  (>ts2 @ t2
                     (idat? t2 ?
                        (more ['dot e (tkv <t2)] >t2)
                        [() ()]))
                 (peekp ts2 "->")
                  (>ts2 @ t2
                     (idat? t2 ?
                        (more ['dot ['deref e] (tkv <t2)] >t2)
                        [() ()]))
                 (peekp ts2 "++") (more ['post e 1] >ts2)
                 (peekp ts2 "--") (more ['post e -1] >ts2)
                 [e ts2])
       m (more e0 ts0)
       (two? <m ? m))
   ; ++x desugars by duplicating x, evaluating the lvalue twice: fine for a calm one, which
   ; keeps gen's lanes (bitfield, pair, wide, all of which `post` refuses); else `post` takes
   ; the address once. `op=` goes the same way, to pasn's ('rmw ..).
   (calm? e)
    (atom? e ? 1
       (<e @ k
          (? (elem k '(var num flo str szof)) 1
             (elem k '(deref addr dot)) (calm? <>e)
             (elem k '(un cast)) (calm? <>>e)
             (k = 'bin) (calm? <>>e && calm? <>>>e)
             ())))
   (preop lv step)
    (: op (step < 0 ? '- '+)
       (calm? lv ? ['asn lv ['bin op lv '(num 1)]]
          ['bin op ['post lv step] '(num 1)]))
   ; gcc's `a ?: b` reads a once: a pure a repeats, anything else takes a temp in a sexpr
   (elvpure? e)
    (e @ (('num || 'flo || 'str || 'var || 'szof || 'bcp) . _) 1
         (('un || 'cast) _ x) (elvpure? x)
         (('deref || 'addr) x) (elvpure? x)
         ('dot x _) (elvpure? x)
         ('bin _ a b) (elvpure? a && elvpure? b)
         (('land || 'lor) a b) (elvpure? a && elvpure? b)
         ('cond c a b) (elvpure? c && elvpure? a && elvpure? b)
         ())
   (pelvis ps a b)
    (elvpure? a ? ['cond a a b]
       (: ty (ptype ps a)
          ty2 (ptype ps ['cond a a b])
          n (1 + peep ps 'elvn 0)
          _ (pin ps 'elvn n)
          t "__elvis_\(n)"
          (!ty || !ty2 ? ()
             ['sexpr [['decl [[t (pdecay ty) a]]]] ['cond ['var t] ['var t] b] ty2])))
   ; the doors: c.y's grammar, laid in cx-door by cgram.l
   (pexpr ps ts) ((cx-door 'parse) ps ts 'expr)
   (pasn ps ts) ((cx-door 'parse) ps ts 'asn)
   (pcond ps ts) ((cx-door 'parse) ps ts 'cond)
   (pblock ps ts) ((cx-door 'parse) ps ts 'blk)

   ; an initializer: an assignment-expr or ('init (item..)), an item plain | ('dfield name
   ; init) | ('didx n init). dbuild nests a designator chain (.a.b = v, C99 6.7.9), coalescing
   ; a run that shares its head into one sub-init, else the member would image twice.
   (pinit ps ts)
    (peekp ts "{" ?
        (: (items ts2 acc)
            (peekp ts2 "}" ? [['init (dbuild (rev acc))] >ts2]
               (: it (pinititem ps ts2)
                  (rcat l a) (atom? l ? a (rcat >l (<l . a)))
                  (atom? it ? ()
                     (: es <it ts3 <>it
                        (? (peekp ts3 ",") (items >ts3 (rcat es acc))
                           (peekp ts3 "}") [['init (dbuild (rev (rcat es acc)))] >ts3]
                           ())))))
           (items >ts ()))
       ; a scalar initializer that folds is its number (globals demand it)
       (pasn ps ts @ r
          (atom? r ? ()
             (: e <r v (cfold (pw64 ps) e)
                (? (cint? v) [['num v] <>r]            ; a sun-sized fold is still a number
                   (<e = 'un &&
                    <>e = 'neg && <<>>e = 'flo)
                    [['flo (-1.0 * <><>>e)] <>r]           ; the neg folds into the literal, -0.0 keeping its sign
                   r)))))
   ; scini: a scalar's initializer may stand in braces, `int x = {0};` (C11 6.7.9p11).
   ; fillarr: a `[]` bound completes from the initializer (6.7.9p22), else the type stands
   (scini ty ini)
    (? (arr? ty || stru? ty || varr? ty) ini
       (ini @ ('init (x)) (two? x && elem <x '(dfield didx init) ? ini x)   ; one level: {{0}} is not a scalar's
              ini))
   (fillarr ps ty ini)
    (arr? ty && <>>ty = 0 && charm? (initcount ps <>ty ini) ?
       ['arr <>ty (initcount ps <>ty ini)] ty)
   ; fills: the plain items one `ty` takes with its braces elided (6.7.9p20), answering the
   ; rest: a scalar one, an aggregate its members, a union its first, a char array a string.
   ; an incomplete tag or a [0] bound takes nothing, which stops the caller's walk
   (uni? ps ty) (stru? ty && peep (ps 'utag) <>ty 0)
   (chart? ty) (elem ty '(char schar cchar uchar))
   (fills ps ty items)
    (? (atom? items) items
       (arr? ty)
        (chart? <>ty && two? <items && <<items = 'str ||
         !(ptr? <>ty) && two? <items && <<items = 'clit && arr? <><items ? >items   ; a string / wide literal is the array
           (: (go n l) (!(0 < n) || atom? l ? l (go (n - 1) (fills ps <>ty l)))
              (go <>>ty items)))
       (stru? ty)
        (: e (peep (ps 'stag) <>ty 0)
           fs (two? e ? <e)
           (uni? ps ty ? (two? fs ? (fills ps <>><fs items) items)
              (foldl (l \ f \ fills ps <>>f l) items fs)))
       >items)
   ; initcount: the elements an initializer implies for a [] bound: a string its bytes + NUL,
   ; a brace list the highest index reached, () if nothing; an elided run counts fills' walks
   ; (int a[][2] = {1,2,3,4} is 2 rows)
   (allplain? items) (foldl (ok \ it \ ok && !(elem <it '(init didx dfield))) 1 items)
   (initcount ps elt ini)
    (? (two? ini && <ini = 'str) (#<>ini + 1)
       ; a wide literal (a bounded clit-of-array after the desugar): its own bound
       (two? ini && <ini = 'clit && arr? <>ini && !(ptr? elt)) <>><>ini
       (two? ini && <ini = 'init)
        (<>ini @ items
           ; { "s" } sizing a char array (6.7.9p14) counts the string, unless elt is a pointer
           (? (two? items &&
               atom? >items &&
               two? <items && <<items = 'str && !(ptr? elt))
               (#<><items + 1)
              (two? items &&                            ; { L"s" }: p14's wide twin
               atom? >items &&
               two? <items && <<items = 'clit && arr? <><items && !(ptr? elt))
               <>><><items
              ((arr? elt || stru? elt) && two? items && allplain? items)
               (: (rows l n) (atom? l ? n
                                 (fills ps elt l @ r (r = l ? n (rows r (n + 1)))))
                  (rows items 0))
               (: (go l i mx)
                   (atom? l ? mx
                      (: it <l
                         ci (<it = 'didx ? <>it i)
                         (go >l (ci + 1) (mx < ci + 1 ? (ci + 1) mx))))
                  (go items 0 0))))
       ())
   ; a designator path: (.name | [const-expr])+ then `=` -> ((('f name)|('i n)..) rest) | ()
   (pdesigs ps ts acc)
    (? (peekp ts ".")
        (>ts @ t2
           (!(idat? t2) ? ()
              (pdesigs ps >t2 (['f (tkv <t2)] . acc))))
       (peekp ts "[")
        (pexpr ps >ts @ er                         ; any const-expr
           (? (atom? er) ()
              (peekp <>er "...")                     ; gcc's range designator: one item per index
               (: e2 (thenw (pexpr ps ><>er) "]")
                  n (cfold (pw64 ps) <er)
                  m (two? e2 ? (cfold (pw64 ps) <e2))
                  (? (atom? e2) ()
                     !(charm? n && charm? m) ()
                     (pdesigs ps <>e2 (['r n m] . acc))))
              (: r2 (want <>er "]")
                 n (cfold (pw64 ps) <er)
                 (? (atom? r2) () (charm? n) (pdesigs ps r2 (['i n] . acc)) ()))))
       (atom? acc) ()
       (want ts "=" @ r
          (two? r ? [(rev acc) r])))
   ; dbuild folds (path value) pairs (path () plain) into 'dfield/'didx items, one nested
   ; init per consecutive same-head run
   (dbuild prs)
    (atom? prs ? ()
       (: pv <prs path <pv v <>pv
          (atom? path ? (v . dbuild >prs)
             (: h <path
                (grab l acc)                         ; consecutive pairs whose head = h, stripped
                 (atom? l ? [(rev acc) ()]
                    (<<l @ p2
                       (two? p2 && <p2 = h ?
                          (grab >l ([>p2 <><l] . acc))
                          [(rev acc) l])))
                gr (grab >prs [[>path v]])
                ; a whole value for the head overrides all the run laid before it (6.7.9p19)
                (fromleaf l k) (atom? l ? k (fromleaf >l (atom? <<l ? l k)))
                subs (fromleaf <gr <gr)
                sub (dbuild subs)
                node (atom? >subs && atom? <<subs ? <sub ['init sub])
                ([(<h = 'f ? 'dfield 'didx) <>h node] . dbuild <>gr)))))
   ; -> (((path value)..) rest) | (): a range designator is one item per index, taken alone
   ; and on an array only, as gcc does, capped at 64k items so a runaway bound refuses
   (rng1? p) (two? p && atom? >p && two? <p && <<p = 'r)
   (rexp lo hi v acc) (hi < lo ? (rev acc) (rexp (lo + 1) hi v ([[['i lo]] v] . acc)))
   (pinititem ps ts)
    (peekp ts "." || peekp ts "[" ?
        (pdesigs ps ts () @ dr
           (atom? dr ? ()
              (: v (pinit ps <>dr)
                 pth <dr
                 (? (atom? v) ()
                    (rng1? pth)
                     (: lo <><pth hi <>><pth
                        (? (hi < lo) (blame ts "an empty range designator")
                           (65536 < hi - lo) (blame ts "range designator too wide")
                           [(rexp lo hi <v ()) <>v]))
                    [[[pth <v]] <>v]))))
       (pinit ps ts @ v
          (two? v ? [[[() <v]] <>v])))

   ; a constant-expression folder: an integer | () when not constant. it folds C's way: each
   ; value in its type, operands meeting by puac (-1 < 1u is 0), results wrapping to their
   ; width, an unsigned answer never negative. w64: long is 8 bytes.
   (cint? x) (charm? x || sun? x)
   (ity? ty) (elem ty '(bool char schar cchar uchar short ushort int uint long ulong llong ullong i128 u128))
   (tbits w64 ty) (ty @ 'bool 1 ('char || 'schar || 'cchar || 'uchar) 8 ('short || 'ushort) 16 ('int || 'uint) 32
                        ('long || 'ulong) (w64 ? 64 32) ('i128 || 'u128) 128 64)
   ; v as a value of ty (C11 6.3.1.3): an unsigned type is v modulo its width, a signed one
   ; that residue re-signed, _Bool a compare with 0
   (wrapt w64 ty v)
    (ty = 'bool ? (v = 0 ? 0 1)
       (: n (tbits w64 ty) m (v & ((2 ** n) - 1))
          (tusg? ty || m < (2 ** (n - 1)) ? m (m - (2 ** n)))))
   ; a bit builtin's name -> (op operand-type) | ()
   (bltab w64 nm)
    (nm @ "__builtin_bswap16" '(bswap ushort) "__builtin_bswap32" '(bswap uint)
          "__builtin_bswap64" ['bswap (w64 ? 'ulong 'ullong)]
          "__builtin_clz" '(clz uint) "__builtin_clzl" '(clz ulong) "__builtin_clzll" '(clz ullong)
          "__builtin_ctz" '(ctz uint) "__builtin_ctzl" '(ctz ulong) "__builtin_ctzll" '(ctz ullong)
          "__builtin_popcount" '(pop uint) "__builtin_popcountl" '(pop ulong)
          "__builtin_popcountll" '(pop ullong)
          "__builtin_ffs" '(ffs uint) "__builtin_ffsl" '(ffs ulong) "__builtin_ffsll" '(ffs ullong)
          ())
   (bctz v) (v & 1 = 1 ? 0 (1 + bctz (v >> 1)))
   (bpop v) (v = 0 ? 0 ((v & 1) + bpop (v >> 1)))
   (bswp v n) (n = 0 ? 0 ((v & 255) * (2 ** (8 * (n - 1))) + bswp (v >> 8) (n - 1)))
   ; v already in ty, unsigned -> (value type) | (); clz and ctz of 0 are undefined, no fold
   (bfold w64 op ty v)
    (op @ 'bswap [(bswp v (tbits w64 ty // 8)) ty]
          'clz (v = 0 ? () [(tbits w64 ty - bitlen v) 'int])
          'ctz (v = 0 ? () [(bctz v) 'int])
          'pop [(bpop v) 'int]
          'ffs [(v = 0 ? 0 (bctz v + 1)) 'int]
          ())
   ; an int where it fits, else the long that holds it (llong on ilp32)
   (numt w64 n) (? (-2147483648 <= n && n <= 2147483647) 'int
                   w64 (n < (2 ** 63) ? 'long 'ulong)
                   (n < (2 ** 63) ? 'llong 'ullong))
   ; a const float expression -> its gem | 'bad; gen.l's ffold is the image-time twin
   (fcfold w64 e)
    (atom? e ? 'bad
       (cfold w64 e @ iv
          (? (cint? iv) (0.0 + iv)
             (<e = 'flo) (0.0 + <>e)
             (<e = 'cast) (elem <>e '(double float) ? (fcfold w64 <>>e) 'bad)
             (<e = 'un) (fcfold w64 <>>e @ v
                           (? (v = 'bad) 'bad (<>e = 'neg) (0.0 - v) 'bad))
             (<e = 'bin)
              (: op <>e a (fcfold w64 <>>e) b (fcfold w64 <>>>e)
                 (? (a = 'bad || b = 'bad) 'bad
                    (op = '+) (a + b) (op = '-) (a - b) (op = '*) (a * b)
                    (op = '/) (b = 0.0 ? 'bad (a / b))
                    'bad))
             'bad)))
   (cfold w64 e) (cfty w64 e @ r (two? r ? <r))
   ; e -> (value type) | (), the value canonical in its type
   (cfty w64 e)
    (: (wr ty v) [(wrapt w64 ty v) ty]
       (? (atom? e) ()
          (<e = 'num) (cint? <>e ? [<>e (numt w64 <>e)])
          (<e = 'bin)
           (: op <>e ra (cfty w64 <>>e) rb (cfty w64 <>>>e)
              (? (atom? ra || atom? rb) ()
                 (elem op '(shl shr))                   ; the left operand's promoted type
                  (: ty (pprom <>ra) a (wrapt w64 ty <ra) b <rb
                     (? !(0 <= b && b <= 256) ()
                        (op = 'shl) (wr ty (a * (2 ** b)))
                        (wr ty (a >> b))))
                 (: ty (puac w64 <>ra <>rb)
                    a (wrapt w64 ty <ra) b (wrapt w64 ty <rb)
                    (op @ '+ (wr ty (a + b)) '- (wr ty (a - b)) '* (wr ty (a * b))
                          '/ (b = 0 ? () (wr ty (a // b)))
                          '% (b = 0 ? () (wr ty (a - (a // b) * b)))
                          '& (wr ty (a & b)) '| (wr ty (a | b)) '^ (wr ty (a ^ b))
                          'eq [(a = b ? 1 0) 'int] 'ne [(a = b ? 0 1) 'int]
                          'lt [(a < b ? 1 0) 'int] 'le [(a <= b ? 1 0) 'int]
                          'gt [(b < a ? 1 0) 'int] 'ge [(b <= a ? 1 0) 'int]
                          ()))))
          (<e = 'un)
           (cfty w64 <>>e @ r
              (atom? r ? ()
                 (: ty (pprom <>r) v (wrapt w64 ty <r)
                    (<>e @ 'neg (wr ty (0 - v)) 'bnot (wr ty (0 - v - 1))
                           'not [(v = 0 ? 1 0) 'int] ()))))
          (<e = 'cast)
           (: ty <>e r (cfty w64 <>>e)
              ; C11 6.6p6: an integer cast may take a float constant -- an unfoldable array
              ; dim would read as a VLA in silence
              (? (two? r) (? (ity? ty) (wr ty <r)
                             (ptr? ty) (wr (w64 ? 'ulong 'uint) <r)
                             r)                       ; a type this fold does not know: the value rides
                 !(ity? ty) ()
                 (fcfold w64 <>>e @ f
                    (? (f = 'bad) ()
                       (ty = 'bool) [(f = 0.0 ? 0 1) 'bool]   ; to _Bool is a compare, never a truncation
                       (wr ty (ceil (f // 1)))))))           ; and every other one truncates toward zero
          ; a deferred __builtin_constant_p in a constant context: 1 if its operand folds, else 0
          (<e = 'bcp) (cfty w64 <>e @ r (two? r ? [1 'int] [0 'int]))
          ; the bit builtins over a constant fold, so one can label a case or size a bit-field
          (<e = 'call)
           (: h <>e as <>>e
              k (two? h && <h = 'var ? (bltab w64 <>h))
              r (two? k && two? as && atom? >as ? (cfty w64 <as))
              (atom? r ? () (bfold w64 <k <>k (wrapt w64 <>k <r))))
          ; land/lor are 3-element ('land l r); truthiness is != 0 (-1 && 1 == 1)
          (elem <e '(land lor))
           (: a (cfty w64 <>e) b (cfty w64 <>>e)
              (? (atom? a || atom? b) ()
                 (<e = 'land) [(<a != 0 && <b != 0 ? 1 0) 'int]
                 [(<a != 0 || <b != 0 ? 1 0) 'int]))
          ; ('cond c a b): only the selected arm need be constant (C11 6.6). unless the other
          ; folds too its type is unknown, so only a value no conversion moves stands
          (<e = 'cond)
           (cfty w64 <>e @ c
              (atom? c ? ()
                 (: r (<c = 0 ? (cfty w64 <>>>e) (cfty w64 <>>e))
                    o (<c = 0 ? (cfty w64 <>>e) (cfty w64 <>>>e))
                    (? (atom? r) () (atom? o) (0 <= <r && <r < 2147483648 ? r ()) (wr (puac w64 <>r <>o) <r)))))
          ()))
   ; _Static_assert ( const-expr [, "message"] ) ; -> (('tdef) rest) | (). false fails the
   ; compile, non-constant passes; the message is optional (C23)
   (pstatic ps ts)
    (: r1 (want >ts "(")
       re (two? r1 ? (pcond ps r1))
       r2 (two? re ? (want <>re ","))
       r3 (strat? r2 ? >r2)
       r4 (? (two? r3) (want r3 ")")                ; the long form: expr, "message"
             (two? re) (want <>re ")") ())          ; ..and the short one: expr alone
       ; peek the `;` first: want answers () when it matched the last token
       (!(two? r4 && peekp r4 ";") ? ()
          (cfold (pw64 ps) <re @ v
             (charm? v && v <= 0 ? () ['(tdef) >r4]))))
   (sassert? ts) (two? ts && idv? <ts "_Static_assert")

   ; decl := type [dtor [= asn] (, dtor [= asn])*] ;
   ; a local's __attribute__((cleanup(f))) comes off its tokens first, and the block gets
   ; ('cln name f id) after it; pcln lays the calls
   (pdecl ps ts) (clsplit ps ts @ sp (sp ? (pdecl ps sp) (pdecl1 ps ts)))
   ; ..one declaration as written: a for's init, which may hold only one
   (pdecl1 ps ts)
     (clstrip ts @ cs
       (? !<cs (pdecl0 ps ts)
          (<cs = 'many) (blame ts "more than one cleanup in one declaration")
          (: r (pdecl0 ps <>cs)
             d (two? r ? <r)
             es (two? d ? <>d)
             (? (atom? d) r
                ; the attribute trails the first declarator's name; in the specifiers it would clean all
                !(<d = 'decl && two? es && (atom? >es || <>>cs = <<es))
                 (blame <>r "a cleanup wants one automatic variable")
                (1 + peep ps 'clid 0 @ n
                   (pins ps 'clid n 'clfn 1 'clpend ['cln <<(<>d) <cs n],
                    r))))))
   ; several declarators with a cleanup read as one declaration each, specifiers respelled.
   ; -> the rewritten tokens | ()
   (clsplit ps ts)
    (: (cl? l) (? (atom? l) () (tp? <l ";") () (clgrp? l) 1 (cl? >l))
       ; up to the first depth-0 `,` -> (the tokens before it  the tail past it  the comma) | ()
       (cut l d acc)
        (? (atom? l) ()
           (d = 0 && tp? <l ";") ()
           (d = 0 && tp? <l ",") [(rev acc) >l <l]
           (tp? <l "(" || tp? <l "[" || tp? <l "{") (cut >l (d + 1) (<l . acc))
           (tp? <l ")" || tp? <l "]" || tp? <l "}") (cut >l (d - 1) (<l . acc))
           (cut >l d (<l . acc)))
       (? !(cl? ts) ()
          (cut ts 0 () @ c
             (? (atom? c) ()
                (pbty ps ts @ br
                   (? (atom? br) ()
                      (take (#ts - #(<>br)) ts @ sp
                         ; a cleanup in the specifiers would clean every declarator: pdecl1 refuses it
                         (any (t \ tp? t "{") sp || cl? sp || clgrp? (clat <c #sp) ? ()
                            (<c + [(<(c 2) . ";" . >>(c 2))] + sp + <>c)))))))))
   (clat l i) (? (atom? l) () (i = 0) l (clat >l (i - 1)))   ; the tail at token i
   (clp? l i s) (clat l i @ t (two? t && tp? <t s))
   (cli? l i s) (clat l i @ t (two? t && idv? <t s))
   (clgrp? l) (two? (clpick l))
   ; an __attribute__((..)) holding cleanup(f) among its items -> (f  the attribute without
   ; that item, () when it was the only one  the tokens past the attribute) | ()
   (clpick l)
    (: (cl1? it) (#it = 4 && (idv? <it "cleanup" || idv? <it "__cleanup__") && tp? (it 1) "("
                  && idat? (clat it 2) && tp? (it 3) ")")
       ; the items at depth 0 of the list, each its tokens, up to the closing `))`
       (items s d cur acc cm)
        (? (atom? s) ()
           (d = 0 && tp? <s ")") (two? >s && tp? <>s ")" ? [(rev (rev cur . acc)) cm s] ())
           (d = 0 && tp? <s ",") (items >s 0 () (rev cur . acc) <s)
           (tp? <s "(") (items >s (d + 1) (<s . cur) acc cm)
           (tp? <s ")") (items >s (d - 1) (<s . cur) acc cm)
           (items >s d (<s . cur) acc cm))
       (? !(cli? l 0 "__attribute__" && clp? l 1 "(" && clp? l 2 "(") ()
          (items (clat l 3) 0 () () () @ r
             (? (atom? r) ()
                (: its <r cm <>r cl <>>r ks (filter (it \ !(cl1? it)) its)
                   (#ks = #its - 1 ?
                      [(tkv (<(filter cl1? its) 2))
                       (#ks = 0 ? () (take 3 l + foldl (\ a it (a = () ? it (a + [cm] + it))) () ks + take 2 cl))
                       >>cl]
                      ()))))))
   ; over the first declarator, up to its `=` `,` or `;` -> (f-name | () | 'many  tokens
   ; the-word-before-the-attribute)
   (clstrip ts)
    (: (go l d acc f pv)
        (? (atom? l) [() ts]
           (d = 0 && (tp? <l ";" || tp? <l "=" || tp? <l ",")) (f ? [f (rev acc + l) pv] [() ts])
           (clpick l @ k
              (? (two? k) (go <>>k d (rev <>k + acc) (f ? 'many <k) (two? acc ? (tkv <acc)))
                 (tp? <l "(" || tp? <l "[" || tp? <l "{") (go >l (d + 1) (<l . acc) f pv)
                 (tp? <l ")" || tp? <l "]" || tp? <l "}") (go >l (d - 1) (<l . acc) f pv)
                 (go >l d (<l . acc) f pv))))
       (go ts 0 () () ()))
   (pdecl0 ps ts)
    (: br (pbty ps ts)
       stat (leadstatic? ps ts)                          ; block-scope `static` -> ('sdecl ..), laid in .bss
       ; block-scope `extern` declares the file-scope object: no slot, no local name
       ext (leadextern? ps ts)
       regv (leadregister? ps ts)
       (atom? br ? ()
          (: base <br ts0 <>br
             bq (qspec ps ts base)   ; _Generic's, staged below
             lal (specask ps ts)   ; an ask among the specifiers, every declarator's
             sct (stat ? (secat? ts @ sc (string? sc ? sc (secat? (tyattr ts0)))))   ; a block static's section, past a tag body too
             (peekp ts0 ";" ? [['decl ()] >ts0]   ; a bare definition (struct S {..};)
                (: (one ts2)
                    (pdtor ps ts2 base @ dr
                       (atom? dr ? ()
                          (: name <<dr ty0 <><dr
                             ; a VLA local: the decl site's slot index stamps the type (gen's
                             ; prescan keys by it); an initializer or a `static` refuses
                             ty (!(varr? ty0) ? ty0
                                   (peep ps 'vlan 0 @ ix
                                      (pin ps 'vlan (ix + 1),
                                       ty0 + [ix])))
                             ts30 (pattr <>dr)                 ; a trailing attribute
                             ; `register T v asm("x0")`: the register rides fourth, for gen's inline asm
                             ap (regv && two? ts30 && asmid? <ts30 && peekp >ts30 "(" &&
                                 strat? >>ts30 && peekp >>>ts30 ")" ?
                                   [(tkv <>>ts30) >>>>ts30])
                             pinl0 (two? ap ? [<ap])
                             ; the ask past the type's own rides a fifth slot, the fourth () unless pinned
                             ask (max lal (pattpk ps <>dr 2))
                             pinl1 (talign ps ty < ask ? ((two? pinl0 ? pinl0 [()]) + [ask]) pinl0)
                             ; ..and a static's section a sixth, the slots before it padded
                             pinl (sct ? (take 2 (pinl1 + [() 0]) + [sct]) pinl1)
                             ts3 (two? ap ? <>ap ts30)
                             ; stage the marked type; bindloc consumes it, so it cannot outlive the declaration
                             (bq ? (pin (ps 'qstage) name (qmark bq ty)) 0,
                             ; a block-scope function declaration: no storage, no slot; its sig
                             ; joins the table unless one is already on file
                              !(fn? ty) || peep (ps 'sigs) name () ? 0
                                (pin (ps 'sigs) name [<>ty () ()]),
                             ; the name is in scope for every initializer after its declarator
                              pin (ps 'declaring) name 1,
                              (? (varr? ty && (stat || peekp ts3 "=")) ()
                                 (peekp ts3 "=")
                                 ; the name types in its own initializer (typeof(p), sizeof *p)
                                 (: old (peep (ps 'locals) name 'none)
                                    _ (pin (ps 'locals) name ty)
                                    r (pinit ps >ts3)
                                    (old = 'none ? (pull (ps 'locals) name 0) (pin (ps 'locals) name old),
                                     atom? r ? ()
                                       (<r @ ini
                                          [([name (fillarr ps ty ini) (scini ty ini)] + pinl) <>r])))   ; [] local: infer size
                                 [([name ty ()] + pinl) ts3])))))
                   (more ts2 acc)
                    (one ts2 @ r
                       (? (atom? r) ()
                          ; a finished declarator is in scope for the ones after it, typeof
                          ; and sizeof included
                          (peekp <>r ",")
                           (: e <r nm <e old (peep (ps 'locals) nm 'none)
                              _ (fn? (e 1) ? 0 (pin (ps 'locals) nm (e 1)))
                              res (more ><>r (<r . acc))
                              (fn? (e 1) ? 0 (old = 'none ? (pull (ps 'locals) nm 0) (pin (ps 'locals) nm old)),
                               res))
                          (: rest (want <>r ";")
                             es (filter (e \ !(fn? <>e)) (rev (<r . acc)))
                             ; extern entries hoist to the TU's top, for gen's global pass
                             (ext && two? es ?
                                (: (gox l) (atom? l ? 1
                                              (pin (ps 'globals) <<l <><l, gox >l))
                                   (pin ps 'hoist (['xdecl es] . ps 'hoist),
                                    gox es)),
                              two? rest ? [[(stat ? 'sdecl 'decl) (ext ? () es)] rest]))))
                   ; saved and put back: a declaration nests (a `for` init, a compound literal)
                   olddecl (ps 'declaring)
                   _ (pin ps 'declaring {})
                   res (more ts0 ())
                   (pin ps 'declaring olddecl,
                    res))))))

   ; asm [volatile] [goto] ( "template" [: outputs [: inputs [: clobbers [: labels]]]] ) ;
   ; the template in holo's neutral text, adjacent strings joined; operands ((constraint
   ; expr)..), clobbers (string..), labels (name..). -> (('asm tmpl outs ins clobs labs) rest) | ()
   (asmid? t) (two? t && tkk t = 'id &&
               elem (tkv t) '("asm" "__asm__" "__asm"))
   ; `volatile`, `inline` and `goto` in any order; inline means nothing here
   (asmqual? t) (? (tkk t = 'kw) (elem (tkv t) '(volatile inline goto))
                   (tkk t = 'id) (elem (tkv t) '("__volatile__" "__inline__" "__inline"))
                   ())
   ; `%[name]` -> the operand's number, in gcc's order: outputs, inputs, labels. a modifier
   ; keeps its place (`%l[name]`); an unmatched name is left for gen
   (anynm? l) (? (atom? l) () (string? <l) 1 (anynm? >l))
   (asmnm tmpl nms)
    (: n #tmpl
       (idx nm l k) (? (atom? l) () (<l = nm) k (idx nm >l (k + 1)))
       (rbr j) (? (n <= j) -1 (tmpl j = 93) j (rbr (j + 1)))
       (go i acc)
        (: md (i + 2 < n && alpha? (tmpl (i + 1)))     ; %c[ reads past the letter
           b (md ? (i + 2) (i + 1))
           (? (n <= i) acc
              (tmpl i = 37 && i + 1 < n && tmpl (i + 1) = 37) (go (i + 2) "\(acc)%%")
              (tmpl i = 37 && b < n && tmpl b = 91)
               (: e (rbr (b + 1))
                  nm (e < 0 ? () (snip tmpl (b + 1) e))
                  k (string? nm ? (idx nm nms 0))
                  (charm? k ? (go (e + 1) (acc + snip tmpl i b + show k))
                     (go (i + 1) (acc + string (tmpl i)))))
              (go (i + 1) (acc + string (tmpl i)))))
       (go 0 ""))
   (pasm ps ts st)
    (: r >ts
       (t1 l) (two? l && asmqual? <l ? (t1 >l) l)
       r0 (want (t1 r) "(")
       (!(strat? r0) ? ()
          (: (tmpl ts2 acc) (strat? ts2 ?
                               (tmpl >ts2 (acc + tkv <ts2))
                               [acc ts2])
             ; an operand run: [name] "constraint" ( expr ) , .. -- empty before : or ). the
             ; name rides third, taken off again below
             (ops ts2 acc)
              (? (peekp ts2 "[")
                  (: nm (idat? >ts2 ? (tkv <>ts2))
                     r0 (nm ? (want >>ts2 "]"))
                     (two? r0 ? (op1 r0 nm acc)))
                 !(strat? ts2) [(rev acc) ts2]
                 (op1 ts2 () acc))
             (op1 ts2 nm acc)
              (!(strat? ts2) ? ()
                 (: c (tkv <ts2)
                    r1 (want >ts2 "(")
                    re (two? r1 ? (thenw (pexpr ps r1) ")"))
                    (? (atom? re) ()
                       (peekp <>re ",") (ops ><>re ([c <re nm] . acc))
                       [(rev ([c <re nm] . acc)) <>re])))
             (opbare e) [<e <>e]                        ; the (constraint expr) pair gen takes
             ; an input tied to an output by its name ("[sum]") is tied by its number
             (optie outs e)
              (: c <e n #c
                 (idx l k) (? (atom? l) () (<l = snip c 1 (n - 1)) k (idx >l (k + 1)))
                 (1 < n && c 0 = 91 && c (n - 1) = 93 ? (idx (map opnm outs) 0 @ k (charm? k ? [(show k) <>e] e)) e))
             (opnm e) <>>e
             (clobs ts2 acc)
              (!(strat? ts2) ? [(rev acc) ts2]
                 (tkv <ts2 @ c
                    (peekp >ts2 "," ? (clobs >>ts2 (c . acc))
                       [(rev (c . acc)) >ts2])))
             (golabs ts2 acc)
              (!(idat? ts2) ? [(rev acc) ts2]
                 (lname ps (tkv <ts2) @ c
                    (peekp >ts2 "," ? (golabs >>ts2 (c . acc))
                       [(rev (c . acc)) >ts2])))
             tr (tmpl r0 "")
             s1 (peekp <>tr ":" ? (ops ><>tr ()) [() <>tr])
             (atom? s1 ? ()
                (: s2 (peekp <>s1 ":" ? (ops ><>s1 ()) [() <>s1])
                   (atom? s2 ? ()
                      (: s3 (peekp <>s2 ":" ? (clobs ><>s2 ()) [() <>s2])
                         (atom? s3 ? ()
                            (: s4 (peekp <>s3 ":" ? (golabs ><>s3 ()) [() <>s3])
                               r9 (want <>s4 ")")
                               semi (two? r9 && peekp r9 ";")      ; the rest may be empty at EOF
                               nms (map opnm <s1 + map opnm <s2 + <s4)
                               ; a statement's basic asm (no `:`) spells its registers bare: every % is literal
                               tm (? (anynm? nms) (asmnm <tr nms)
                                     (st && !(peekp <>tr ":")) (join "%%" (split "%" <tr))
                                     <tr)
                               (semi ?
                                  [['asm tm (map opbare <s1) (map (e \ opbare (optie <s1 e)) <s2) <s3 <s4] >r9]))))))))))

   ; a file-scope asm("..") is gcc's basic form, gas's whole language for holo's gas-top;
   ; no operands out here. -> (('tasm tmpl) rest) | ()
   (ptasm ps ts)
    (pasm ps ts () @ r
       (atom? r ? ()
          (<r @ ('asm t () () () ()) [['tasm t] <>r]
                (blame >ts "a file-scope asm takes no operands"))))

   ; a statement-position __attribute__((..)) run skips but for musttail, which lands in the
   ; ret's pre slot for gen's sibcall pass, and holo, which marks an asm template as holo's
   ; neutral text. on any other statement either refuses.
   (attrin a b nm) (a = b ? ()                  ; a `nm` token before the b spine?
                      (idv? <a nm || attrin >a b nm))
   ; a bare non-zero integer literal returned where the sig says pointer; a cast means it
   (intptr? ps e)
    (: fn (ps 'fnname)
       sg (fn ? (peep (ps 'sigs) fn ()))
       rt (two? sg ? <sg)
       (? !(ptr? rt) ()
          (two? e && <e = 'num && charm? <>e && <>e != 0) 1
          ()))
   (pstmt ps ts0)
    (atom? ts0 ? ()
       (pattr ts0 @ ts
          (atom? ts ? ()
             (: r (? (sassert? ts) (pstatic ps ts)
                     (ts0 = ts) (pstmt2 ps ts)
                     (pin ps 'lmode (modeat ps ts0), pstmt2 ps ts @ r2 (pin ps 'lmode (), r2)))
                mt (attrin ts0 ts "musttail")
                ho (attrin ts0 ts "holo")
                (? (!mt && !ho) r
                   (atom? r) ()
                   (<r @ st
                      (? (mt && <st = 'ret && two? <>st) [(st + '("__attribute__((musttail))")) <>r]
                         (ho && !mt && <st = 'asm) [(st + '(holo)) <>r]
                         ())))))))
   ; a label is a flat marker a block splices beside its statement. an arm has no list, so it
   ; takes the marker run with the statement under it as one block.
   (markerp s) (two? s && elem <s '(lbl case dflt))
   (parm ps ts)
    ((: (go ts acc)
        (pstmt ps ts @ r
           (? (atom? r) ()
              (markerp <r) (go <>r (<r . acc))
              (atom? acc) r
              [['blk (rev (<r . acc))] <>r])))
     ts ())
   ; the `( expr )` after a statement keyword at ts -> (expr rest) | ()
   (pparen ps ts) (want >ts "(" @ r1 (two? r1 ? (thenw (pexpr ps r1) ")")))
   (pstmt2 ps ts)
    (atom? ts ? ()
       (<ts @ t
          (? (tkw? t 'return)
              (peekp >ts ";" ? [['ret ()] >>ts]    ; bare `return;` -- a void return
                 (pexpr ps >ts @ r
                    (? (atom? r) ()
                       ; C11 6.8.6.4, 6.5.16.1: an integer for a pointer only as a null pointer constant
                       (intptr? ps <r) (blame <>r "an integer where a pointer is owed")
                       (want <>r ";" @ rest
                          (two? rest ? [['ret <r] rest])))))
             (tkw? t 'if)
              (: rc (pparen ps ts)
                 rt (two? rc ? (parm ps <>rc))
                 ; if (__builtin_expect(e, k)): the test is e, and a (nop cold|hot) heads the then-arm
                 xa (two? rc ? (<rc @ ('call ('var "__builtin_expect") (e ('num k)) && elem k '(0 1)) [e k] ()))
                 c9 (? (atom? xa) (two? rc ? <rc)
                       (elem (ptype ps <xa) '(float double ldouble)) ['cast 'long <xa]   ; expect's long, where it differs
                       <xa)
                 (arm s) (atom? xa ? s
                            (['nop (<>xa = 0 ? 'cold 'hot)] @ m
                               (s @ ('blk items) ['blk (m . items)] ['blk [m s]])))
                 (atom? rt ? ()
                    (two? <>rt && tkw? <<>rt 'else ?
                       (parm ps ><>rt @ re
                          (two? re ?
                             [['if c9 (arm <rt) <re] <>re]))
                       [['if c9 (arm <rt) ()] <>rt])))
             (tkw? t 'while)
              (: rc (pparen ps ts)
                 rb (two? rc ? (parm ps <>rc))
                 (two? rb ? [['while <rc <rb] <>rb]))
             (tkw? t 'do)
              (parm ps >ts @ rb
                 (? (atom? rb) ()
                    !(two? <>rb && tkw? <<>rb 'while) ()
                    (: rc (pparen ps <>rb)
                       rest (two? rc ? (want <>rc ";"))
                       (two? rest ? [['do <rb <rc] rest]))))
             (tkw? t 'for)
              (want >ts "(" @ r1
                 (atom? r1 ? ()
                    (: ri (? (tyat? ps r1) (pdecl1 ps r1)        ; quals skip: `for (const char *x; ..`
                             (peekp r1 ";") [() >r1]
                             (thenw (pexpr ps r1) ";" @ r
                                (two? r ? [['expr <r] <>r])))
                       ; a cleanup in the init moves into a block around the for: break leaves it
                       cm (clpop ps)
                       ; the init's names type the rest of the for, as a block's declarations do
                       fsh (two? ri && two? <ri && <<ri = 'decl ?
                              (bindlocs ps (loctypes <ri) (shadowdecl ps (declnames <ri) ())))
                       res (? (atom? ri) ()
                              cm (pfor ps [() <>ri] @ r (two? r ? [['blk [<ri cm <r]] <>r]))
                              (pfor ps ri))
                       (unshadow ps fsh,
                        res))))
             (tkw? t 'switch)
              (: rc (pparen ps ts)
                 r2 (two? rc ? <>rc)
                 ; a braced body is a block and the switch keeps its flat items; a brace-less
                 ; body is one labeled statement, which parm takes with its label run
                 (? (atom? r2) ()
                    (peekp r2 "{")
                     (pblock ps r2 @ rb
                        (two? rb ? [['switch <rc <><rb] <>rb]))
                    (parm ps r2 @ rb
                       (two? rb ? [['switch <rc [<rb]] <>rb]))))
             (tkw? t 'goto)
              (>ts @ t2
                 (? (peekp t2 "*")                  ; gcc's computed goto, through a label's address
                     (thenw (pexpr ps >t2) ";" @ r (two? r ? [['igoto <r] <>r]))
                    !(idat? t2) ()
                    (want >t2 ";" @ rest
                       (two? rest ? [['goto (lname ps (tkv <t2))] rest]))))
             (tkw? t 'break)
              (want >ts ";" @ rest (two? rest ? ['(brk) rest]))
             (tkw? t 'continue)
              (want >ts ";" @ rest (two? rest ? ['(cont) rest]))
             ; case/default are labels at any depth (Duff's device); gen ties each to its
             ; nearest switch. `case A ... B:` lays a label per value when narrow, else ('case A B)
             (tkw? t 'case)
              (pexpr ps >ts @ rv
                 (atom? rv ? ()
                    (: v (cfold (pw64 ps) <rv)
                       (crange lo hi acc) (hi < lo ? (rev acc) (crange (lo + 1) hi (['case lo] . acc)))
                       (? !(cint? v) ()
                          (peekp <>rv "...")
                           (pexpr ps ><>rv @ r2
                              (atom? r2 ? ()
                                 (: hi (cfold (pw64 ps) <r2)
                                    rest (want <>r2 ":")
                                    (? !(cint? hi) ()
                                       (atom? rest) ()
                                       (hi < v) (blame <>rv "an empty case range")
                                       (16 < hi - v) [['case v hi] rest]
                                       [['blk (crange v hi ())] rest]))))
                          (want <>rv ":" @ rest
                             (two? rest ? [['case v] rest]))))))
             (tkw? t 'default)
              (want >ts ":" @ rest (two? rest ? ['(dflt) rest]))
             (asmid? t) (pasm ps ts 1)     ; before the call/label fallthroughs: asm( is a statement
             (tp? t "{") (pblock ps ts)
             (tp? t ";") ['(nop) >ts]
             ; a label: id ':'
             (plabel? ts)
              ; C11 6.8.1p3: a label's scope is its whole function; a duplicate would take every goto
              (lname ps (tkv t) @ nm
                 (peep (ps 'labs) nm () ? (blame ts "duplicate label '\(nm)'")
                    (pin (ps 'labs) nm 1, [['lbl nm] >>ts])))
             (thenw (pexpr ps ts) ";" @ r
                (two? r ? [['expr <r] <>r])))))
   ; block-scoped shadowing: a local named like a typedef or enum constant hides it for the
   ; rest of the block. record (table name old); a typedef pins to 0, an enum constant is
   ; pulled (the fold tests charm?, and 0 is one); restored on exit.
   (declnames form) (two? form && <form = 'decl ? (map cap <>form))
   (shadow1 ps nm shadows)
    (: s1 (peep (ps 'types) nm 'none @ old
             (old = 'none ? shadows
                (pin (ps 'types) nm 0, ['types nm old] . shadows)))
       olde (peep (ps 'enums) nm 'none)
       (olde = 'none ? s1
          (pull (ps 'enums) nm 0, ['enums nm olde] . s1)))
   (shadowdecl ps names shadows) (atom? names ? shadows
                                     (shadowdecl ps >names (shadow1 ps <names shadows)))
   ; a type specifier binds names where written (enum constants, an enum tag's type, a block
   ; tag), at block scope the block's: move the run staged since epre onto its shadow list,
   ; newest first. file scope drains nowhere -- `note` clears the run per form.
   (sdrain ps epre shadows)
    (: now (ps 'scopacc)
       (go l k) (k < 1 ? shadows (<l . go >l (k - 1)))
       (pin ps 'scopacc epre,
        go now (#now - #epre)))
   (unshadow ps shadows) (atom? shadows ? ()
                            (<shadows @ e
                               (<>>e = 'none ? (pull (ps <e) <>e 0) (pin (ps <e) <>e <>>e),   ; 'none: the name was absent, so remove it
                                unshadow ps >shadows)))
   ; qtake consumes the mark staged for nm, kept only when it strips back to the type filed.
   ; bindloc records a local or param (name ty ..) into 'locals and 'qtys, the old bindings
   ; ('none if fresh) on the block's shadow list for unshadow
   (qtake ps nm ty)
    (: nq (peep (ps 'qstage) nm 'none)
       st (nq != 'none)          ; a comparison, not the datum's truth
       ((? (st && qstrip nq = ty) (pin (ps 'qtys) nm nq)
           (peep (ps 'qtys) nm 'none != 'none) (pull (ps 'qtys) nm 0)
           0),
        st ? (pull (ps 'qstage) nm 0) 0))
   (bindloc ps ent shadows) (: nm <ent
                                old (peep (ps 'locals) nm 'none)
                                oq (peep (ps 'qtys) nm 'none)
                                (pin (ps 'locals) nm <>ent,
                                 qtake ps nm <>ent,
                                 ['locals nm old] . ['qtys nm oq] . shadows))
   (bindlocs ps ents shadows) (atom? ents ? shadows (bindlocs ps >ents (bindloc ps <ents shadows)))
   (loctypes form) (two? form && elem <form '(decl sdecl) ? <>form)       ; a block decl's entries, () otherwise
   ; a block-scope typedef: each declarator into ps 'types, the old binding on the shadow
   ; list; file scope hands () and drops it. -> (rest sh2) | (); the remainder may be empty
   (btdefs ps base ts sh bq)
    (pdtor ps ts base @ dr
       (atom? dr ? ()
          (: nm <<dr
             old (peep (ps 'types) nm 'none)
             _ (pin (ps 'types) nm <><dr)
             _ (bq ? (pin (ps 'qtdef) nm bq) 0)
             sh2 (['types nm old] . sh)
             af (patt <>dr)                ; glibc's trailing __attribute__
             (? (peekp af ",") (btdefs ps base >af sh2 bq)
                (peekp af ";") [>af sh2]
                ()))))

   ; a for past its init: ri is (init rest-after-;) -> (('for ..) rest) | ()
   (pfor ps ri)
    (: rc (peekp <>ri ";" ? [() ><>ri] (thenw (pexpr ps <>ri) ";"))
       (atom? rc ? ()
          (: rs (peekp <>rc ")" ? [() ><>rc] (thenw (pexpr ps <>rc) ")"))
             (atom? rs ? ()
                (parm ps <>rs @ rb
                   (two? rb ? [['for <ri <rc <rs <rb] <>rb]))))))

   ; params := void | type '*'* id (, ..)* [, ...]   -> (entries rest variadic?)
   (pparams ps ts acc)
    (? (peekp ts ")") [(rev acc) >ts ()]
       (two? ts && tkw? <ts 'void && peekp >ts ")") [() >>ts ()]
       !(tyat? ps ts) ()
       (pbty ps ts @ br
          (atom? br ? ()
             (: _ (pin ps 'sawrstr ())          ; cleared per param
                dr (pdtor ps <>br <br)
                (atom? dr ? ()
                   ; an array or function parameter decays to a pointer (a va_list is an array)
                   (: e0 <dr ty0 <>e0
                      ; a declarator's (fn ret) has no params; the pointer wears (fn ret ptys)
                      entry (? (arr? ty0) [<e0 (tdecay ty0)] (fn? ty0) [<e0 ['ptr (two? >>ty0 ? ty0 [<ty0 <>ty0 ()])]] e0)
                      _ (peep ps 'sawrstr () && <e0 ?   ; a named restrict param: file it for note
                           (pin ps 'currstr (<e0 . peep ps 'currstr ())) 0)
                      _ (!<e0 ? 0                         ; a named param stages its mark like a local's
                           (qspec ps ts <br @ bq
                              (bq ? (pin (ps 'qstage) <e0 (qmark bq <>entry)) 0)))
                      ts3 (pattr <>dr)                     ; ..and on a parameter
                      (peekp ts3 "," ?
                          (peekp >ts3 "..." ?              ; ... after this param -> variadic
                              (want >>ts3 ")" @ rest
                                 (two? rest ? [(rev (entry . acc)) rest 1]))
                             (pparams ps >ts3 (entry . acc)))
                         (want ts3 ")" @ rest
                            (two? rest ? [(rev (entry . acc)) rest ()])))))))))

   ; -- K&R definitions: `f(a, b) int a; char *b; { .. }`, an undeclared id int. answers
   ; pparams' (entries rest variadic?), rest at the `{`. a bare non-type id after `(` is the
   ; tell; a qualifier spelled as an id (`__const`) opens a prototype.
   (krhead? ps ts) (idat? ts && !(tkbty? ps <ts) && !(qual? <ts))
   (kids ts acc)                                     ; the identifier list -> (names rest-after-`)`)
    (idat? ts ?
        (: nm (tkv <ts) r >ts
           (? (peekp r ",") (kids >r (nm . acc))
              (peekp r ")") [(rev (nm . acc)) >r]
              ())))
   (klook nm l) (? (atom? l) 'int (<<l = nm) <><l (klook nm >l))
   (kdtors ps ts base acc)                           ; `dtor (, dtor)* ;` -> (name ty) pairs, K&R arrays decay to ptr
    (pdtor ps ts base @ dr
       (atom? dr ? ()
          (: nm <<dr ty0 <><dr rest (patt <>dr)       ; `char *s __attribute__ ((unused));`
             ty (tdecay ty0)
             acc2 ([nm ty] . acc)
             (? (peekp rest ",") (kdtors ps >rest base acc2)
                (peekp rest ";") (kdecls ps >rest acc2)
                ()))))
   (kdecls ps ts acc)                                ; the run of parameter declarations up to `{` -> (tmap rest)
    (peekp ts "{" ? [acc ts]
       (pbty ps ts @ br
          (atom? br ? () (kdtors ps <>br <br acc))))
   (pkr ps ts)                                       ; ts after `(` -> (entries rest-at-`{` ()) | ()
    (kids ts () @ kr
       (atom? kr ? ()
          (: names <kr afterp <>kr
             dr (kdecls ps afterp ())
             (atom? dr ? ()
                (: tmap <dr rest <>dr
                   [(map (nm \ [nm (klook nm tmap)]) names) rest ()])))))

   (addweak ps nm) (pin ps 'weaks (nm . ps 'weaks))   ; the .o binds nm's symbol weak
   ; a 'sigs row off pparams' answer: (rettype (paramty..) variadic?)
   (mksig rty rp) [rty (map caup <rp) <>>rp]
   ; a function definition from its `{`: params, __func__ and the label table per function,
   ; undone on the way out. -> (('fn name params body) rest) | ()
   (pfbody ps name prms ts)
    (: psh (bindlocs ps prms ())
       _ (pin ps 'fnname name)
       _ (pins ps 'labs {} 'clfn ())
       b0 (pblock ps ts)
       b (two? b0 ? [(ahoist ps <b0) <>b0] b0)
       _ (pin ps 'fnname ())
       _ (unshadow ps psh)
       sig (peep (ps 'sigs) name ())
       b2 (two? b && peep ps 'clfn () ?
              (pcln ps <b (two? sig ? <sig 'int) @ r
                 (r = 'bad ? (clblame "a jump into the scope of a cleanup variable") [r <>b]))
              b)
       b3 (two? b2 && sspfn? ps prms <b2 ? [(sspw ps <b2 (two? sig ? <sig 'int)) <>b2] b2)
       (two? b3 ? [['fn name prms <b3] <>b3]))

   ; an alloca where gen would find an operand parked on the stack (an argument, a store through
   ; a pointer) moves ahead of its statement into a temp. under && || ?:, a comma's right, a loop
   ; condition or a declaration of several it stays, and gen refuses it
   (ahoist ps body)
    (: (ab? e) (e @ ('call ('var n) _) (n = "__builtin_alloca") ())
       (fresh _) (1 + peep ps 'aloc 0 @ n (pin ps 'aloc n, "__alloca." + show n))
       (in? e) (? !(two? e) () (ab? e) 1 (in? <e || in? >e))
       (mp f l) (two? l ? (f <l . mp f >l) l)          ; a node's dotted tail rides along
       (hx sf e)
        (? !(in? e) e
           (ab? e) (: e2 ['call <>e (map (hx 1) <>>e)]
                      (sf ? e2 (: t (fresh 0) (pin ps 'apre ([t '(ptr void) e2] . peep ps 'apre ()), ['var t]))))
           (elem <e '(land lor szof bcp sexpr)) e
           (e @ ('cast ty x) ['cast ty (hx sf x)]
                ('comma a b) ['comma (hx sf a) b]
                ('cond c a b) ['cond (hx sf c) a b]
                ('asn ('var v) r) ['asn ['var v] (hx sf r)]
                (mp (hx ()) e)))
       ; a root expression -> [decls e']
       (root e) (: _ (pin ps 'apre ()) e2 (hx 1 e)
                   [(map (d \ ['decl [d]]) (rev (peep ps 'apre ()))) e2])
       ; a statement -> the statements it becomes
       (hi s) (? !(in? s) [s]
                 (s @ ('blk items) [['blk (catmap hi items)]]
                      ('expr pe) (root pe @ (ds e2) (ds + [['expr e2]]))
                      ('ret . e . pre) (two? e ? (root e @ (ds e2) (ds + [(['ret e2] + pre)])) [s])
                      ('decl ds) (#ds = 1 && two? >><ds ?
                                   (<ds @ p (root <>>p @ (d2 e2) (d2 + [['decl [([<p <>p e2] + >>>p)]]])))
                                   [s])
                      ('if . c . t . er) (root c @ (ds c2) (ds + [(['if c2 (hw t)] + map hw er)]))
                      ('while c b) [['while c (hw b)]]
                      ('do b c) [['do (hw b) c]]
                      ('for i c st b) [['for i c st (hw b)]]
                      ('switch ce items) (root ce @ (ds c2) (ds + [['switch c2 (catmap hi items)]]))
                      [s]))
       (hw s) (hi s @ l (#l = 1 ? <l ['blk l]))
       (in? body ? (hi body @ l (#l = 1 ? <l ['blk l])) body))

   ; -- the stack protector: a canary set at entry, checked on every way out (gen lays both).
   ; 'ssp is 1|2 (strong; -fstack-protector protects that superset), 3 all, 4 the attribute alone
   (sspfn? ps prms body)
    (ps 'ssp @ lv
       (? (!lv || ps 'curssp = 'no) ()
          (lv = 3 || ps 'curssp) 1
          (lv < 4) (sspstrong? prms body)
          ()))
   ; an array or aggregate local, a VLA, alloca, or the address of a local or param
   (sspstrong? prms body)
    (: (dnames x acc) (? (atom? x) acc
                         (<x = 'decl && two? >x) (foldl (a \ d \ (two? d ? (<d . a) a)) acc <>x)
                         (dnames >x (dnames <x acc)))
       ns (dnames body (map cap prms))
       (lroot e) (? (atom? e) () (<e = 'var) <>e (<e = 'dot) (lroot <>e) ())
       (hit? x) (? (atom? x) ()
                   (<x = 'decl && two? >x)
                    (any (d \ two? d && two? <>d && elem <<>d '(arr varr struct union)) <>x)
                   (<x = 'addr && two? >x && elem (lroot <>x) ns) 1
                   (<x = 'call && two? >x) (<>x @ ('var n) (elem n '("alloca" "__builtin_alloca") || any hit? x) (any hit? x))
                   (any hit? x))
       (hit? body))
   (sspw ps body rty)
    (: (fresh s) (1 + peep ps 'sspid 0 @ n (pin ps 'sspid n, s + show n))
       chk '(ssp chk)
       (w s) (? (atom? s) s
                (<s = 'ret)
                 (? (two? >>s || atom? <>s) ['blk [chk s]]        ; a musttail's check runs before its call
                    (rty = 'void) ['blk [['expr (w <>s)] chk '(ret ())]]
                    (fresh "__ssp_ret_" @ t ['blk [['decl [[t rty (w <>s)]]] chk ['ret ['var t]]]]))
                (map w s))
       ['blk ['(ssp set) (w body) chk]])

   ; -- cleanup: the pending marker a declaration left, taken once by the block that holds it
   (clpop ps) (ps 'clpend @ m (pin ps 'clpend (), m))
   ; a refusal found past the tokens: the sentence files at the deepest point read
   (clblame msg) (pins far 'why msg 'wseq (peep far 'seq -1), ())
   ; pcln lays f(&v) on every way out of a cleanup's scope: block end, return (value held
   ; first), break/continue, a goto out, an asm goto through a pad. a jump into one is 'bad
   (clcalls cs) (map (c \ ['expr ['call ['var (c 2)] [['addr ['var (c 1)]]]]]) cs)
   (clup st stops) (? (atom? st) ()                  ; the live cleanups inside the nearest stop
                      (two? <st) (<st . clup >st stops)
                      (elem <st stops) ()
                      (clup >st stops))
   (clids st) (map (c \ c 3) (clup st ()))
   (clbad? x) (x = 'bad)
   (clmap f l) (atom? l ? l                      ; map, 'bad if any element answered it
                  (: h (f <l) t (clmap f >l)
                     (clbad? h || clbad? t ? 'bad (h . t))))
   (cllabs x st t)                                  ; every label -> the cleanup ids live at it
    (? (atom? x) t
       (<x = 'lbl) (pin t <>x (clids st))
       (: (go l st2) (atom? l ? t
                        (<l @ e
                           (two? e && <e = 'cln ? (go >l (['c (e 1) (e 2) (e 3)] . st2))
                              (cllabs e st2 t, go >l st2))))
          (go x st)))
   (pcln ps body rty)
    (: labt (cllabs body () {})
       (fresh s) (1 + peep ps 'clid 0 @ n (pin ps 'clid n, s + show n))
       (wrap cs s) (two? cs ? ['blk (clcalls cs + [s])] s)
       ; the cleanups a jump from st to label nm runs, 'bad into a scope, () for no such label
       (leave st nm)
        (peep labt nm 'none @ lt
           (lt = 'none ? ()
              (clids st @ here
                 (any (i \ nelem i here) lt ? 'bad
                    (filter (c \ nelem (c 3) lt) (clup st ()))))))
       ; a block's items -> (items' live-cleanups stack) | 'bad
       (wi items st)
        (: (go l st2 loc acc)
            (atom? l ? [(rev acc) loc st2]
               (<l @ e
                  (? (two? e && <e = 'cln)
                      (: c ['c (e 1) (e 2) (e 3)] (go >l (c . st2) (c . loc) acc))
                     (two? e && elem <e '(case dflt))
                      (two? (clup st2 '(S)) ? 'bad (go >l st2 loc (e . acc)))
                     (ws e st2 @ e2 (clbad? e2 ? 'bad (go >l st2 loc (e2 . acc)))))))
           (go items st () ()))
       (xw e st)                                    ; an expression: its statement expressions
        (? (atom? e) e
           (<e = 'sexpr)
            (wi (e 1) st @ r
               (clbad? r ? 'bad
                  (: loc <>r v (xw (e 2) <>>r)
                     (? (clbad? v) 'bad
                        (atom? loc) ['sexpr <r v (e 3)]
                        (atom? v) ['sexpr (<r + clcalls loc) v (e 3)]
                        (fresh "__cln_val_" @ t
                           ['sexpr (<r + [['decl [[t (e 3) v]]]] + clcalls loc) ['var t] (e 3)])))))
           (clmap (x \ xw x st) e))
       (ws s st)
        (atom? s ? s
           (<s @ k
              (? (k = 'blk)
                  (wi (s 1) st @ r (clbad? r ? 'bad ['blk (<r + clcalls <>r)]))
                 (k = 'if)
                  (: c (xw (s 1) st) a (ws (s 2) st) b (two? >>>s ? (ws (s 3) st))
                     (? (clbad? c || clbad? a || clbad? b) 'bad
                        (two? >>>s) ['if c a b] ['if c a]))
                 (k = 'while)
                  (: c (xw (s 1) st) b (ws (s 2) ('L . st))
                     (clbad? c || clbad? b ? 'bad ['while c b]))
                 (k = 'do)
                  (: b (ws (s 1) ('L . st)) c (xw (s 2) st)
                     (clbad? c || clbad? b ? 'bad ['do b c]))
                 (k = 'for)
                  (: i (xw (s 1) st) c (xw (s 2) st) n (xw (s 3) st) b (ws (s 4) ('L . st))
                     (clbad? i || clbad? c || clbad? n || clbad? b ? 'bad ['for i c n b]))
                 (k = 'switch)
                  (: c (xw (s 1) st) r (wi (s 2) ('S . st))
                     (clbad? c || clbad? r ? 'bad ['switch c (<r + clcalls <>r)]))
                 (k = 'ret)
                  (: cs (clup st ())
                     x (xw (s 1) st)
                     (? (clbad? x) 'bad
                        (atom? cs) (['ret x] + >>s)
                        (two? >>s) 'bad                ; a musttail cannot run code after its call
                        (atom? x) (wrap cs ['ret ()])
                        (rty = 'void) ['blk ([['expr x]] + clcalls cs + ['(ret ())])]
                        (fresh "__cln_ret_" @ t
                           ['blk ([['decl [[t rty x]]]] + clcalls cs + [['ret ['var t]]])])))
                 (k = 'brk) (wrap (clup st '(L S)) s)
                 (k = 'cont) (wrap (clup st '(L)) s)
                 (k = 'goto) (leave st (s 1) @ cs (clbad? cs ? 'bad (wrap cs s)))
                 ; an asm goto's edge to a label outside lands on a pad that runs the cleanups
                 (k = 'asm && two? (s 5))
                  (: (go ls nl pads)
                      (atom? ls ? [(rev nl) pads]
                         (: l9 <ls cs (leave st l9)
                            (? (clbad? cs) 'bad
                               (atom? cs) (go >ls (l9 . nl) pads)
                               (fresh "__cln_pad_" @ p9
                                  (go >ls (p9 . nl) (pads + [['lbl p9]] + clcalls cs + [['goto l9]]))))))
                     r (go (s 5) () ())
                     (? (clbad? r) 'bad
                        (atom? <>r) s
                        (: sk (fresh "__cln_pad_")
                           a2 ([(s 0) (s 1) (s 2) (s 3) (s 4) <r] + >>>>>>s)
                           ['blk ([a2 ['goto sk]] + <>r + [['lbl sk]])])))
                 ; a computed goto's target is unknown here, so it may leave no cleanup behind
                 (k = 'igoto) (atom? (clup st ()) ? s 'bad)
                 (elem k '(lbl case dflt nop goto asm tdef)) s
                 (xw s st))))
       (ws body ()))
   ; a comma-list of `*.. name (params)` prototypes sharing a base type, each sig registered.
   ; -> [rest-after-`;`] | (). each sibling's own stars ride into its sig's return slot.
   (mproto ps base ts)
    (: sr (pstars ts base)
       rty <sr s0 <>sr
       (!(idat? s0) ? ()
          (: nm (tkv <s0) s1 >s0
             (!(peekp s1 "(") ? ()
                (pparams ps >s1 () @ rp
                   (atom? rp ? ()
                      (: _ (pin (ps 'sigs) nm (mksig rty rp))
                         af <>rp
                         (? (peekp af ",") (mproto ps base >af)
                            ; wrapped [rest]: a bare rest would conflate EOF with refusal
                            (peekp af ";") [>af]
                            ()))))))))

   ; `typedef T a, b;`: btdefs' walk with nothing to shadow, bq the run's mask
   (tdeflist ps base ts bq) (btdefs ps base ts () bq @ r (two? r ? ['(tdef) <r]))

   ; the top level. staticness, section and the other attributes are noted at entry (the
   ; outermost sighting wins) and pinned per name by note.
   (ptop ps ts)
    (hdhits ts @ hw
     ((peep ps 'curstat () ? () (leadstatic? ps ts ? (pin ps 'curstat 1))),
      pinat ps ts hw,
      ; C99 inline: plain `inline` lays no external definition, `extern inline` does;
      ; gnu_inline (gnu89's) the other way about
      (peep ps 'curlink () ? ()
         (pin ps 'curlink (leadkw? ps ts 'inline && !!(leadextern? ps ts) = !!(hwin hw "gnu_inline" "__gnu_inline__") ? 'inl 'ext))),
      ptop9 ps ts))
   ; the attributes a declaration names, hw its head words. ptop reads them at entry, where the
   ; scans stop at the first `{`, and ptop9 again past a struct/union/enum body
   (pinat ps ts hw)
    ((peep ps 'cursect () ? () (hwin hw "section" "__section__" && secat? ts @ sc (sc ? (pin ps 'cursect sc)))),
     (peep ps 'curalias () ? () (hwin hw "alias" "__alias__" && aliasat? ts @ al (al ? (pin ps 'curalias al)))),
     (peep ps 'curweak () ? () (hwin hw "weak" "__weak__" ? (pin ps 'curweak 1))),
     (peep ps 'curinl () ? () (hwin hw "always_inline" "__always_inline__" ? (pin ps 'curinl 1))),
     (peep ps 'curnoinl () ? () (hwin hw "noinline" "__noinline__" ? (pin ps 'curnoinl 1))),
     (peep ps 'curused () ? () (hwin hw "used" "__used__" ? (pin ps 'curused 1))),
     (peep ps 'curalign () ? ()
        (hwin hw "aligned" "__aligned__" || elem "_Alignas" hw ? (alignat? ps ts @ an (an ? (pin ps 'curalign an))))),
     (two? (peep ps 'curpfe ()) ? ()
        (hwin hw "patchable_function_entry" "__patchable_function_entry__" ? (pfeat? ts @ pf (two? pf ? (pin ps 'curpfe pf))))),
     (hwin hw "no_stack_protector" "__no_stack_protector__" ? (pin ps 'curssp 'no)),
     (peep ps 'curssp () ? () (hwin hw "stack_protect" "__stack_protect__" ? (pin ps 'curssp 1))))
   (ptop9 ps ts)
    (? (peekp ts ";") ['(tdef) >ts]           ; a stray top-level `;` -- an empty declaration
       ; a leading __extension__ strips before the keyword checks (`__extension__ typedef`)
       (two? ts && idv? <ts "__extension__") (ptop9 ps >ts)
       (sassert? ts) (pstatic ps ts)
       (asmid? <ts) (ptasm ps ts)
       ; a leading __attribute__((..)): ptop's entry scans read the whole form, so skip it
       (pattr ts != ts) (pin ps 'lmode (modeat ps ts), ptop ps (pattr ts) @ r (pin ps 'lmode (), r))
       ; an init-less gdecl under a leading `extern` becomes ('xdecl pairs): no storage laid
       (tkw? <ts 'extern)
        (ptop ps >ts @ r
           (? (atom? r) ()
              (<<r != 'gdecl) r
              (: (initless? prs) (? (atom? prs) 1
                                    (two? <>><prs) ()
                                    (initless? >prs))
                 (initless? <><r ? [['xdecl <><r] <>r] r))))
       (tkw? <ts 'typedef)
        (pbty ps >ts @ br
           (atom? br ? () (tdeflist ps <br <>br (qspec ps >ts <br))))
       (pbty ps ts @ br
          (atom? br ? ()
             (: base <br ts0 <>br
                gbq (qspec ps ts base)  ; the run's mask, _Generic's
                (peekp ts0 ";" ? ['(tdef) >ts0]     ; a bare struct/enum definition
                   (: _ (tyattr ts0 @ ta (pinat ps ta (hdhits ta)))   ; what a tag body hid from ptop
                      sr (pstars ts0 base)
                      rty <sr ts1 (pquals <>sr)
                      ; the first declarator: a plain name, or a paren declarator through pdtor,
                      ; the leading stars already in rty. -> (name rest ty prms), ty () if plain
                      fdr (? (idat? ts1) [(tkv <ts1) >ts1 () ()]
                             (peekp ts1 "(")
                              (pdtor ps ts1 rty @ dr
                                 (? (atom? dr) ()
                                    !<<dr ()                          ; abstract at top level: refuse
                                    [<<dr <>dr <><dr <>><dr]))                                 ; 4th = a fn declarator's parsed params
                             ())
                      (atom? fdr ? ()
                         (: name <fdr
                            ts2 <>fdr
                            fpty <>>fdr
                            fprm <>>>fdr                              ; the inner params of a fn declarator
                            ; the object lanes, also reached from a function-first mixed list
                            ; (`int f(int), a;`). the marked type stages here; note's gogl takes it
                            (one ts3 nm t2) (one0 ts3 nm t2 @ r
                                               (gbq && two? r ? (pin (ps 'qstage) <<r (qmark gbq <><r)) 0,
                                                r))
                            (one0 ts3 nm t2)                ; t2 is the element type (stars included)
                             (? (peekp ts3 "[")
                                (adims ps ts3 () @ dr  ; one or more [n]/[] dims
                                   (atom? dr ? ()
                                      (: dims <dr rest0 (patt (plabel ps <>dr nm))   ; trailing attributes too
                                         (atom? >dims && <dims = 0 ?      ; a lone []: size from init, or 0
                                             (!(peekp rest0 "=") ? [[nm ['arr t2 0] ()] rest0]      ; incomplete, size 0
                                                (pinit ps >rest0 @ ir
                                                   (atom? ir ? ()
                                                      (initcount ps t2 <ir @ n
                                                         (charm? n ?
                                                            [[nm ['arr t2 n] <ir] <>ir])))))
                                            ; nested arr, optional init; an outer [] counts the init's top level
                                            (mkarr t2 dims @ aty0
                                               (peekp rest0 "=" ?     ; T a[n].. = init
                                                   (pinit ps >rest0 @ ir
                                                      (atom? ir ? ()
                                                         [[nm (fillarr ps aty0 <ir) <ir] <>ir]))
                                                  [[nm aty0 ()] rest0]))))))
                                (peekp ts3 "=")
                                 (pinit ps >ts3 @ r
                                    (atom? r ? ()
                                       ; a later declarator arrives with its dims parsed (t2 the
                                       ; whole array type), so a lone [] bound fills in here too
                                       [[nm (fillarr ps t2 <r) (scini t2 <r)] <>r]))
                                ; a global register variable's row was pinned before its type was known
                                (peep (ps 'gregs) nm () @ gv
                                   (two? gv ? (pin (ps 'gregs) nm [<gv t2]),
                                    [[nm t2 ()] ts3])))
                            (more ts3 acc)
                                (peekp ts3 "," ?
                                   (pdtor ps >ts3 base @ dr
                                      (atom? dr ? ()
                                         (one (patt (plabel ps (pgreg ps <>dr <<dr (leadregister? ps ts)) <<dr)) <<dr <><dr @ r
                                            (two? r ? (more <>r (<r . acc))))))
                                   ; a declarator of function type (a function typedef) declares
                                   ; a function: its sig, no storage. the remainder may be empty
                                   (!(peekp ts3 ";") ? ()
                                      (: rest >ts3
                                         (fnp? pr) (fn? <>pr)
                                         _ (: (regs l) (atom? l ? ()
                                                          (<l @ p2
                                                             ; never clobber a filed sig: this door carries no params
                                                             (fnp? p2 && !(peep (ps 'sigs) <p2 ()) ?
                                                                (pin (ps 'sigs) <p2
                                                                     [(two? ><>p2 ? <><>p2 'long) () ()]),
                                                             ; an alias through a function type answers a nameless 'tdef
                                                              (peep ps 'curalias () @ al
                                                                 (atom? al ? ()
                                                                    (pin (ps 'alias) <p2 <al,
                                                                     (<>al ? (addweak ps <p2))))),
                                                              regs >l)))
                                              (regs acc))
                                         vps (: (go2 l a2) (atom? l ? a2
                                                              (go2 >l (fnp? <l || two? (peep (ps 'gregs) <<l ()) ?
                                                                         a2 (<l . a2))))
                                                (go2 acc ()))
                                         ; a const object with an initializer is a .rodata candidate,
                                         ; per declarator (only some carry a star); init-less rides .bss
                                         _ (!(leadconst? ps ts) ? ()
                                              (: (goc l) (atom? l ? 1
                                                            (<l @ p
                                                               (cobj? <>p && two? <>>p ?
                                                                  (pin (ps 'consts) <p 1),
                                                                goc >l)))
                                                 (goc vps)))
                                         ; C11 6.7.6.2p2: no variably modified object at file scope
                                         vm (filter (p \ vmod? <>p) vps)
                                         (? (two? vm) (blame rest "variably modified '\(<<vm)' at file scope")
                                            (two? vps) [['gdecl vps] rest]
                                            ['(tdef) rest]))))
                            (? (atom? fpty && peekp ts2 "(")        ; a function
                               (: rp (krhead? ps >ts2 ? (pkr ps >ts2) (pparams ps >ts2 ()))
                                  (atom? rp ? ()
                                     (: _ (pin (ps 'sigs) name (mksig rty rp))
                                        aft (patt (plabel ps <>rp name))    ; a trailing attribute
                                        (? (peekp aft ";") [['proto name] >aft]
                                           ; more `* nm (params)` prototypes sharing base, to `;`. a
                                           ; mixed list (`int f(int), a;`) takes the object lane
                                           (peekp aft ",")
                                            (mproto ps base >aft @ rest
                                               (two? rest ? [['proto name] <rest]
                                                  ((peep ps 'curstat () ? (pin (ps 'sfns) name 1)),
                                                   more aft ())))
                                           (pfbody ps name <rp aft)))))
                               (fn? fpty)                                ; returns a fn-ptr: <>fpty, params in fprm
                                (: _ (pin (ps 'sigs) name (mksig <>fpty fprm))
                                   aft (patt (plabel ps ts2 name))
                                   (peekp aft ";" ? [['proto name] >aft]
                                      (pfbody ps name <fprm aft)))
                               ; a global declaration; the first declarator's stars came off `sr`
                               (one (patt (plabel ps (pgreg ps ts2 name (leadregister? ps ts)) name)) name (two? fpty ? fpty rty) @ first
                                  (two? first ? (more <>first [<first]))))))))))))
   ; a parse refusal names where it stood: stamp just this form and re-run ptop, marking. the
   ; furthest token reached is the site; the form's first token is the fallback, for a form
   ; dying before any mark or a re-parse that succeeds (ps keeps half-registered typedefs)
   (pfail ps ts2 spans toks)
    (: i0 (#toks - #ts2)       ; the failing form's index, O(n) on the dying path
       ft (two? ts2 ? <ts2)
       _ (pin far 'seq -1)
       _ (pin far 'tok ())
       _ (pin far 'why ())
       _ (pin far 'wseq ())
       _ (pin ps 'nomode ())                     ; its lookaheads move the watermark
       r (ptop ps (stampf ts2 i0 spans))
       dt (two? r ? () (far 'tok))
       t (two? dt ? dt ft)
       ; a cause filed at the deepest token names the fault; shallower, an abandoned branch's
       why (peep far 'wseq () = peep far 'seq () ? (far 'why))
       (atom? t ? (gripe () () () "parse error at end of input")
          (gripe (two? dt ? (filof t) (filat spans i0)) <>>t ()
                 (why ? why "parse error near \(spell t)"))))
   ; C11 6.7p4: a redeclared file-scope object keeps a compatible type, compared by shape:
   ; scalar, pointer, struct, and two different arithmetic types
   (tyshape t) (? (atom? t) t (ptr? t) 'ptr (arr? t) 'arr (stru? t) t (fn? t) 'fn 'other)
   (tyclash? a b) (? (fn? a || fn? b) () (atom? a && atom? b) (a != b) (tyshape a != tyshape b))
   (redecl ps f)
    (? !(elem <f '(gdecl xdecl)) ()
       (: (go prs) (atom? prs ? ()
                     (<prs @ pr
                        (peep (ps 'globals) <pr () @ old
                           (two? pr && old && <>pr && tyclash? old <>pr ?
                              "conflicting types for '\(<pr)'" (go >prs)))))
          (go <>f)))
   (cparse ts) (cparse-t ts 'x64)          ; law tests and bare callers: 64-bit widths
   (cparse-t ts tgt) (cparse-d ts tgt 'moon)  ; ..and the default dialect
   (cparse-d ts tgt dia) (cparse-o ts tgt dia {})
   ; opts: the driver's language flags beyond the dialect ('swch, -fshort-wchar)
   (cparse-o ts tgt dia opts)
    (: ps (pins (psnew-d tgt dia) 'swch (opts 'swch) 'uch (opts 'uch) 'ssp (opts 'ssp))
       toks (fsbody ts) spans (fspans ts)
       ; a unit with no `mode(M)` or `__mode__(M)` has no mode attribute, so modeat's walk
       ; of every declaration is skipped; pfail's re-parse walks it again
       (mdw? l) (? (atom? l) ()
                   ((idv? <l "mode" || idv? <l "__mode__") && two? >l && tp? <>l "(" && idat? >>l) 1
                   (mdw? >l))
       _ (mdw? toks ? () (pin ps 'nomode 1))
       ; does the unit name volatile anywhere? types carry no qualifier, so gen then keeps
       ; every load and store where the source put it
       vol (foldl (a \ t \ a || tkk t = 'kw && tkv t = 'volatile ||
                           tkk t = 'id && elem (tkv t) '("__volatile__" "__volatile")) () toks)
       ; note the completed form's attributes per declared name, then clear the stashes
       (note f)
        (: _ (elem <f '(gdecl xdecl) ?         ; register file-scope names -> types (ptype's global fallback)
                ; ..and take the mark ptop staged, on bindloc's terms
                (: (gogl prs) (atom? prs ? 1
                                 (<<prs @ nm
                                    (pin (ps 'globals) nm <><prs,
                                     qtake ps nm <><prs,
                                     gogl >prs)))
                   (gogl <>f)))
           st (ps 'curstat) sc (ps 'cursect) an (ps 'curalign)
           fnp (elem <f '(fn proto))
           ; a `used` static is kept though nothing here calls it (gen's dead-static sweep)
           (st && fnp ? (pin (ps 'sfns) <>f (ps 'curused || peep (ps 'sfns) <>f () = 'used ? 'used 1)),
           ; a function may name its section and alignment too (where code lands, its spacing)
            sc && fnp ? (pin (ps 'sects) <>f sc),
            an && fnp ? (pin (ps 'aligns) <>f an),
            (ps 'curpfe @ pf (two? pf && fnp ? (pin (ps 'pfes) <>f pf))),
            <f = 'gdecl && (st || sc || an) ?
              (: (go2 prs) (atom? prs ? 1
                              (<<prs @ nm
                                 (st ? (pin (ps 'svars) nm 1),
                                  sc ? (pin (ps 'sects) nm sc),
                                  an ? (pin (ps 'aligns) nm an),
                                  go2 >prs)))
                 (go2 <>f)),
           ; an alias names no storage: another name for a symbol in this TU; cgen lays the label
            (ps 'curalias @ al
               (atom? al ? ()
                  (: nms (? (<f = 'gdecl) (map cap <>f) fnp [<>f] ())
                     (go3 l) (atom? l ? 1
                                (pin (ps 'alias) <l <al,
                                 <>al ? (addweak ps <l),
                                 go3 >l))
                     (go3 nms)))),
            (ps 'curweak @ wk
               (!wk ? ()
                  (: nms (? (elem <f '(gdecl xdecl)) (map cap <>f)
                            fnp [<>f] ())
                     (go4 l) (atom? l ? 1 (addweak ps <l, go4 >l))
                     (go4 nms)))),
            peep ps 'curinl () && fnp ?
              (pin ps 'ainl (<>f . ps 'ainl)),
            peep ps 'curnoinl () && fnp ?
              (pin ps 'noinl (<>f . ps 'noinl)),
            ; C11 6.7.4p7: a function every file-scope declaration of which says plain `inline`
            ; has no external definition here
            fnp ? (pin (ps 'c99inl) <>f (peep (ps 'c99inl) <>f 'inl = 'inl && ps 'curlink = 'inl ? 'inl 'ext)),
            pin ps 'curlink (),
           ; restrict params, filed per function: `p` may be restrict in one and plain in the next
            (ps 'currstr @ rs
               (rs && fnp ? (pin (ps 'rstrs) <>f (rev rs)))),
            pin ps 'currstr (),
            pin ps 'curstat (),
            pin ps 'curalias (),
            pin ps 'curweak (),
            pin ps 'curinl (),
            pin ps 'curnoinl (),
            pin ps 'curused (),
            pin ps 'curalign (),
            pin ps 'curpfe (),
            pin ps 'curssp (),
            pin ps 'scopacc (),        ; what a file-scope specifier bound is nobody's to take back
            pin ps 'cursect ()))
       (tops ts2 acc)
        ; the hoisted block-scope externs lead the program; a later real definition takes the
        ; entry back (C's tentative rule)
        (? (two? ts2 && tkk <ts2 = 'pack) (pin ps 'pack (tkv <ts2), tops >ts2 acc)   ; cpp's #pragma pack mark
           (atom? ts2) ((map (nm \ (peep (ps 'c99inl) nm () = 'inl ? (pin (ps 'sfns) nm 1))) (keys (ps 'c99inl))),
                      [1 ['prog (ps 'hoist + rev acc)] (ps 'stag) (ps 'sigs) (ps 'weaks)  ; an empty TU is valid
                            (ps 'sfns) (ps 'svars) (ps 'sects) (ps 'alias) (ps 'aligns) (ps 'ainl) (ps 'noinl)
                            (ps 'consts) (ps 'rstrs) (ps 'gregs) vol (ps 'anames) (ps 'pfes)])
           (ptop ps ts2 @ r
              (? !(two? r) (pfail ps ts2 spans toks)
                 (redecl ps <r @ why
                    (why ? (gripe (filat spans (#toks - #ts2)) (<>><ts2) () why)
                       (note <r, tops <>r (<r . acc)))))))
       (attrbad toks spans @ ab (gripe? ab ? ab (tops toks ()))))
   ; an __attribute__ whose skip would change the code (cpp.l's gnuattrs 'no) refuses where
   ; written, each item read by its first word. -> a gripe | ()
   (attrbad toks spans)
    (: ; inside __attribute__((, at paren depth d; w: the next word names an item
       ; (the opening or a `,` at its depth), so an argument never passes for one
       (item l i d w)
        (? (atom? l) ()
           (<l @ t
              (? (tp? t "(") (item >l (i + 1) (d + 1) ())
                 (tp? t ")") (d = 2 ? (scan >>l (i + 2)) (item >l (i + 1) (d - 1) ()))
                 (d = 2 && tp? t ",") (item >l (i + 1) d 1)
                 (w && elem (tkk t) '(id kw))
                  (: nm (tkk t = 'kw ? show (tkv t) (tkv t))
                     (attrdoes nm = 'no ?
                        (gripe (filat spans i) (<>>t) () "__attribute__((\(attrname nm))) is not carried out")
                        (item >l (i + 1) d ())))
                 (item >l (i + 1) d ()))))
       (scan l i)
        (? (atom? l) ()
           (: t <l
              (? (tkk t = 'id && elem (tkv t) '("__attribute__" "__attribute") && two? >l && tp? <>l "("
                  && two? >>l && tp? <>>l "(")
                  (item >>>l (i + 3) 2 1)
                 (scan >l (i + 1)))))
       (scan toks 0)))
) ; module 'moon
