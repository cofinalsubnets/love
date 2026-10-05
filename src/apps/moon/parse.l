; src/apps/moon/parse.l -- the C parser: tokens -> (1 ast stbl) | (). recursive descent plus a
; precedence ladder; the cursor is a token list threaded as (value rest), () the error riding up.
; ps (a tablet) holds what C cannot be parsed without: typedef names 'types, enum constants
; 'enums, and the tag table 'stag (tag -> (fields size align)), which rides out with the AST.
; unions flatten into 'struct entries at offset zero; an anonymous member splices into its parent.
; nodes beyond the obvious: ('dot e name) (e->x is (dot (deref e) x)), ('switch e items) with
; ('case v)/('dflt) markers inline, ('do body cond), ('goto name) ('lbl name), ('tdef) (gen skips
; it), ('call headexpr args), ('clit ty init), ('init (item..)) with item plain | ('dfield name
; val) | ('didx n val).
; a new node here is also clay's: clay.l validates and re-says this file's output, so it wants
; an arity row, a precedence and a rendering (doc/misc/clay.md).
(module 'moon
(borrow 'kore)
(:
   ; token readers: t = (kind val line)
   (tkk t) <t (tkv t) <>t
   ; the value is a guard: a nom in a pattern is a fresh binder, so a second
   ; `s` there would shadow the parameter rather than demand the two agree.
   (tp? ('p . v . _) s) ?(v = s)
   (tkw? ('kw . v . _) k) ?(v = k)
   (idv? ('id . v . _) s) ?(v = s)
   (idat? ts) (two? ts && tkk <ts = 'id)         ; an identifier heads ts
   (strat? ts) (two? ts && tkk <ts = 'str)
   ; -- where a refusal stood --
   ; cpp hands the spans -- ((index file)..), which file each stretch of the flat stream
   ; came from -- on a marker token at the head; a caller feeding raw lexer output reads ().
   ; the file is carried because an #include splices the header's own line numbering in:
   ; a line number alone cannot say which file it means, and lines run backwards at a splice.
   (fspans ts) (two? ts && tkk <ts = 'fspans ? (tkv <ts))
   (fsbody ts) (two? ts && tkk <ts = 'fspans ? >ts ts)
   (filat spans i)                                  ; the file in force at stream index i
    (: (go l cur) (? (atom? l) cur (i < <<l) cur (go >l <><l))
       (go spans ()))
   ; a token the failing form's re-parse stamped: (kind val line seq file). slots 4 and 5
   ; are free -- the cpp hideset and the lexer's glued-paren flag die once parse holds the
   ; stream, which reads kind and val and nothing else.
   (stampf ts i spans)
    (atom? ts ? ()
       (<ts @ t
          ([(tkk t) (tkv t) <>>t i (filat spans i)] . stampf >ts (i + 1) spans)))
   (stamped? t) (two? >>>>t)                       ; a 5th cell -- probed on every lookahead, never counted
   (seqof t) (stamped? t ? <>>>t)
   (filof t) (stamped? t ? <>>>>t)
   ; the watermark: a refusal answers a bare () and unwinds carrying no position, so the
   ; deepest token any lookahead stood on is remembered and the position read off that.
   ; only the re-parse of an already-failing form runs on stamped tokens -- an unstamped
   ; one costs mark a length test and nothing else (a peep+pin per lookahead was +25%).
   far {}
   (mark ts)
    ((atom? ts ? ()
        (: t <ts s (seqof t)
           (charm? s && peep far 'seq -1 < s ? (pin far 'seq s, pin far 'tok t)))),
     ts)
   (want ts s) (mark ts, (two? ts && tp? <ts s ? >ts))
   (peekp ts s) (mark ts, two? ts && tp? <ts s)
   ; a (v rest) | () answer carried past one required token s -> (v rest') | ()
   (thenw r s) (atom? r ? () (want <>r s @ rest (two? rest ? [<r rest])))
   ; a refusal that knows its cause files the sentence beside the watermark; pfail
   ; reports it in place of the generic near-token line when it is still the deepest
   (blame ts msg)
    (: _ (mark ts)
       s (two? ts ? (seqof <ts))
       (charm? s && peep far 'seq -1 = s ?
          (pin far 'why msg, pin far 'wseq s),
        ()))
   asnops [["=" ()] '("+=" +) '("-=" -) '("*=" *) '("/=" /) '("%=" %)
             '("&=" &) '("|=" |) '("^=" ^) '("<<=" shl) '(">>=" shr)]
   scalars '(char short int long void double float)
   ; a type-specifier run canonicalizes to one type symbol -- `unsigned long` -> 'ulong.
   ; `long long` folds to 'long on the 64-bit targets (same width); on the 32-bit thumb
   ; ABI it is its own 8-byte type, 'llong/'ullong -- the register pair.
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
   ; ignorable specifiers: storage/qualifier keywords + gcc attribute ids, skipped wherever
   ; a type may begin or a declarator may carry them -- __attribute__((..)) / _Alignas(..)
   ; balance-skip their parens, _Noreturn / __inline stand alone.
   qualkw '(const volatile restrict register auto inline extern static)
   ; _Alignof/__alignof__ are not here: they are operators (punary), and a skip would eat the
   ; parenthesized operand whole. _Thread_local/__thread skip: no threads, so a thread-local is
   ; the one static object -- and would be shared, silently, the day threads land
   qualid '("__attribute__" "__inline" "__inline__" "__restrict" "__restrict__"
            "__volatile__" "__volatile" "__const" "__const__" "_Noreturn" "_Alignas"
            "__extension__" "_Thread_local" "__thread")
   ; typeof's spellings, plus C23's typeof_unqual -- the same operator here, since a type
   ; has never carried a qualifier to strip. `typeof` is not reserved in C11, so an object
   ; of that name reads as a declaration (the typedef table wins first)
   tyofid '("__typeof" "__typeof__" "typeof" "__typeof_unqual__" "typeof_unqual")
   ; gcc's __auto_type: the declared type is the initializer's, so it stands where a type
   ; begins and is read by looking past the one name it allows
   autoid "__auto_type"
   ; gcc's library builtins: the prefix names the plain function, and libsig declares it on
   ; the way past (a program spelling the prefix never included the header). it sits up here
   ; with the other rosters: further down the block, love0's lane answers `;; missing libbin`.
   libbin '("__builtin_memcpy" "__builtin_memmove" "__builtin_memset"
            "__builtin_memcmp" "__builtin_strlen" "__builtin_strcpy")
   ; ..and the shape test the builtin arms hide their string compares behind: pprim sees
   ; every identifier in the TU, and the shortest name any of them answers to is 16 long
   (bib? s) (#s @ n (n < 16 ? () (s 2 = 98)))     ; `__b..`, 16+
   (libsig ps nm)
    (: vp '(ptr void) cp ['ptr (pchar ps)] sz (szty ps)
       (? (nm = "memset") [vp [vp 'int sz] ()]
          (nm = "memcmp") ['int [vp vp sz] ()]
          (nm = "strlen") [sz [cp] ()]
          (nm = "strcpy") [cp [cp cp] ()]
          [vp [vp vp sz] ()]))                     ; memcpy and memmove
   ; one qualifier token, and the cursor past it (an attribute id carries its parens)
   (qual? t) (? (tkk t = 'kw) (elem (tkv t) qualkw) (tkk t = 'id) (elem (tkv t) qualid) ())
   (qskip ts) (>ts @ r
                 (tkk <ts = 'id && peekp r "(" ?
                     (skipbal >r 1 @ e (idv? <ts "__attribute__" && cleanup? ts e ? (nocleanup e) e))
                    r))
   (pquals ts) (two? ts && qual? <ts ? (pquals (qskip ts)) ts)
   ; skip a trailing run of __attribute__((..)) / __asm__(..) -- the decoration glibc hangs
   ; off a declarator's tail. the `(` is required to skip: a bare one of these names is not
   ; decoration, and eating it strands whatever followed.
   (patt ts)
    (? (atom? ts) ts
       ((tkk <ts = 'id && elem (tkv <ts) '("__attribute__" "__asm__" "__asm")) &&
        peekp >ts "(")
        (skipbal >>ts 1 @ e (cleanup? ts e ? (nocleanup e) (patt e)))
       ts)
   ; the statement-position skip: __attribute__ only -- a leading __asm__(..) there is the
   ; inline-asm statement, and patt would balance-skip it as decoration.
   (pattr ts)
    (? (atom? ts) ts
       (idv? <ts "__attribute__" && peekp >ts "(")
        (skipbal >>ts 1 @ e (cleanup? ts e ? (nocleanup e) (pattr e)))
       ts)
   ; cleanup is not decoration: it runs code at every exit from the scope, which a skip drops
   (cleanup? a b) (attrin a b "cleanup" || attrin a b "__cleanup__")
   (nocleanup ts) (blame ts "__attribute__((cleanup)) is not carried out")
   ; gcc's `__label__ a, b;` declares local labels: each name takes a fresh spelling for the
   ; rest of its block (ps 'lren, restored with the block's shadows), so a macro that lays
   ; one twice in a function lays two labels. -> (rest shadows)
   (plabs ps ts sh)
    (? (atom? ts) [ts sh]
       (peekp ts ";") [>ts sh]
       (idat? ts)
        (: nm (tkv <ts) k (ps 'lrn)
           _ (pin ps 'lrn (k + 1))
           old (peep (ps 'lren) nm 'none)
           (pin (ps 'lren) nm (nm + "__L" + show k),   ; C-legal, so clay reads it back
            plabs ps >ts (['lren nm old] . sh)))
       (plabs ps >ts sh))
   (lname ps nm) (peep (ps 'lren) nm nm)
   ; does the leading declaration-specifier run carry keyword k? the run is order-free, so
   ; `static char const` and `const static char` answer alike, which is what C says.
   ; ..and does the run pquals is about to drop carry `restrict`? read-only: pquals still
   ; drops it, and the fact rides out of band (ps 'rstrs) rather than in the type.
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
             ; a typedef name is a type specifier like any other, and C lets a qualifier
             ; follow the type: `uint32_t const x` is `const uint32_t x`. a struct/union/
             ; enum head is not walked -- its tag, and a body, sit between it and the run.
             (tkk t = 'id && tkbty? ps t) (leadkw? ps >ts k)
             ())))
   ; the `static` storage class -- a block-scope `static` local is laid in .bss (a real
   ; global), not a stack slot
   (leadstatic? ps ts) (leadkw? ps ts 'static)
   (leadextern? ps ts) (leadkw? ps ts 'extern)
   (leadregister? ps ts) (leadkw? ps ts 'register)
   ; a file-scope `register T nm asm("R")` is GNU's global register variable: the name is
   ; that machine register, so no storage is laid. it must be caught before patt, which
   ; would skip the asm name as decoration and rename the object in silence
   (pgreg ps ts nm regv)
    (? (!regv || atom? ts) ts
       (!(asmid? <ts) || !(peekp >ts "(") || !(strat? >>ts) || !(peekp >>>ts ")")) ts
       (tkv <>>ts @ s
          ; only the stack pointer: gcc reserves the register for the whole TU and we
          ; cannot, so any register the allocator uses would answer whatever it last held
          (!(elem s '("rsp" "sp" "esp" "%rsp" "%esp")) ?
             (blame >>>>ts ("a global register variable is taken on the stack pointer only, not '" + s + "'"))
             (pin (ps 'gregs) nm [s 'long], >>>>ts))))
   ; `const` in the specifier run; it names the object only when the declarator adds no
   ; pointer of its own, which cobj? decides per declarator.
   (leadconst? ps ts) (leadkw? ps ts 'const)
   ; does a specifier-run `const` reach the object? arrays are transparent (`const char
   ; a[3]` is three const chars), a pointer is not: `const char *p` qualifies the pointee.
   ; a declarator-side `char * const p` reads unqualified here and keeps its .data home.
   (cobj? ty) (? (atom? ty) 1 (<ty = 'arr) (cobj? <>ty) (<ty != 'ptr))
   ; the declaration's alias attribute: `alias("TARGET")` inside an __attribute__ run anywhere
   ; in the form (musl's weak_alias), to the first depth-0 `;` or `{` like secat?, noting a
   ; `weak` in the same run -- binding decides which definition wins. -> (TARGET weak?) | ()
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
   ; an attribute anywhere in the declaration, not just leading -- musl's `weak` macro sits
   ; after the storage class. weak matters even where nothing is defined: a weak undefined
   ; symbol resolves to zero at static link. always_inline admits the name to gen's inline
   ; table size-unbounded, noinline bars it.
   (attrany? ts a b)
    (: (go s d) (atom? s ? ()
                   (<s @ t
                      (? (d < 1 && (tp? t ";" || tp? t "{")) ()
                         (tp? t "(") (go >s (d + 1))
                         (tp? t ")") (go >s (d - 1))
                         (idv? t a || idv? t b) 1
                         (go >s d))))
       (go ts 0))
   (inlany? ts) (attrany? ts "always_inline" "__always_inline__")
   (wkany? ts) (attrany? ts "weak" "__weak__")
   (noinlany? ts) (attrany? ts "noinline" "__noinline__")
   (usedany? ts) (attrany? ts "used" "__used__")
   (gnuinlany? ts) (attrany? ts "gnu_inline" "__gnu_inline__")
   ; the declaration's section attribute: `section("NAME")`, either spelling, to the first
   ; depth-0 `;` or `{` -- inside a declaration that shape only occurs in an __attribute__.
   ; -> NAME | ()
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
   ; one `aligned` ask, the tokens after the word -> (N rest): bare is the target's widest, a
   ; parenthesised constant expression folds (the kernel's `2 * sizeof(unsigned long)`), and one
   ; that will not fold asks nothing
   (palask ps ts)
    (!(peekp ts "(") ? [(pst32? ps ? 8 16) ts]
       (thenw (pexpr ps >ts) ")" @ er
          (atom? er ? [0 ts]
             (cfold (pw64 ps) <er @ v [(charm? v ? v 0) <>er]))))
   ; the alignment ask, both spellings at one door: gcc's `aligned(N)` (bare is the target's
   ; widest -- 8 under AAPCS32, 16 elsewhere) and C11's `_Alignas(N|type-name)`, to the first
   ; depth-0 `;` or `{` like secat?. `aligned` counts only inside parens, since at depth 0 it
   ; is an ordinary identifier. -> N | ()
   (alignat? ps ts)
    (: (go s d) (atom? s ? ()
                   (<s @ t
                      (? (d < 1 && (tp? t ";" || tp? t "{")) ()
                         (tp? t "(") (go >s (d + 1))
                         (tp? t ")") (go >s (d - 1))
                         (0 < d && (idv? t "aligned" || idv? t "__aligned__"))
                          (palask ps >s @ a (0 < <a ? <a (go >s d)))
                         ; C11 6.7.5: `_Alignas(T)` is `_Alignof(T)`, so the type lane
                         ; answers through talign like the operator does
                         (idv? t "_Alignas" && peekp >s "(")
                          (two? >>s && tkk <>>s = 'num ? (tkv <>>s)
                             (pcty ps >>s @ tr
                                (two? tr ? (talign ps <tr) (go >s d))))
                         (go >s d))))
       (go ts 0))

   ; -- the parse state --
   (psnew tgt) (psnew-d tgt 'moon)                ; the short spelling: the default language
   ; a new door rather than a wider one: under (f) == f a shifted call hands back a closure
   ; without a word, so psnew/cparse-t keep the arity every caller already spells
   (psnew-d tgt dia) ({} @ t
                (pin t 'dia dia,                  ; the dialect: what grammar the front reads (moon | c | c23)
                 pin t 'tgt tgt,                  ; the codegen target: 32-bit widths (thumb1/thumb2) vs 64-bit
                 pin t 'types {},         ; typedef name -> ty
                 pin t 'weaks (),                 ; __attribute__((weak)) function names
                 pin t 'ainl (),                  ; always_inline function names (love.h's love_inline)
                 pin t 'noinl (),                 ; noinline function names (love.h's love_noinline)
                 pin t 'enums {},         ; enum constant -> value
                 pin t 'declaring {},     ; the names of the declaration being parsed right now (C11 6.2.1p7)
                 pin t 'labs {},          ; the labels defined in the function being parsed (C11 6.8.1p3)
                 pin t 'lren {},          ; a __label__ name -> its spelling in the current block
                 pin t 'lrn 0,
                 pin t 'etag {},          ; enum tag -> the type its enumerators lowered to (see ety)
                 pin t 'stag {},          ; tag -> (fields size align)
                 pin t 'tags {},          ; a block tag's spelling -> the key it took in stag (C11 6.7.2.3)
                 pin t 'utag {},          ; the tags of that table that are unions (the layout flattens them alike)
                 pin t 'tunion {},        ; ..and those __attribute__((transparent_union)) marked (tuargs)
                 pin t 'sigs {},          ; fn/proto name -> (rettype (paramty..)) for the call ABI
                 pin t 'anon 0,                   ; the anonymous-tag counter
                 pin t 'sfns {},          ; top-level `static` fn names: local symbols in the .o
                 pin t 'c99inl {},        ; fn name -> 'inl while every file-scope declaration says plain `inline`
                 pin t 'svars {},         ; top-level `static` globals: internal linkage, never exported
                 pin t 'sects {},         ; global name -> its __attribute__((section "..")) string
                 pin t 'consts {},        ; global name -> 1 when `const` names the object and it has an initializer
                 pin t 'rstrs {},         ; fn name -> its `T *restrict` param names (the alias promise, out of band)
                 pin t 'gregs {},         ; a file-scope `register T nm asm("R")`: nm -> (R ty), no storage laid
                 pin t 'currstr (),               ; ...accumulating for the declaration being parsed, like curweak
                 pin t 'aligns {},        ; global name -> its __attribute__((aligned(N))) boundary
                 pin t 'locals {},        ; local/param name -> its declared type (for parse-time sizeof folding)
                 pin t 'globals {},       ; file-scope name -> ty, so sizeof over a global settles at parse too
                 pin t 'hoist (),                 ; block-scope `extern` decls, lifted to the TU's top as ('xdecl ..)
                 pin t 'qtys {},          ; the same names -> the qualifier-marked type, _Generic's alone (see qmark)
                 pin t 'qstage {},        ; ..staged by the declarator parse, consumed by the bind that follows
                 pin t 'qtdef {},         ; typedef name -> the const/volatile mask its own leaf wears
                 pin t 'qmem {},          ; "tag.member" -> the same mask, which playout has no slot for
                ; gcc's builtin va_list, seeded so `typedef __builtin_va_list va_list;` parses --
                ; gen bakes the va offsets, so only size/align/decay ride the type here
                 pin (t 'stag) "__va_list_tag"
                     (? (pst32? t) '((("__ap" 0 (ptr void))) 4 4)
                        (tgt = 'rv64) '((("__ap" 0 (ptr void))) 8 8)   ; LP64: one walking pointer, 8-byte slots
                        (tgt = 'a64)
                         '((("__stack" 0 (ptr void)) ("__gr_top" 8 (ptr void)) ("__vr_top" 16 (ptr void))
                            ("__gr_offs" 24 int) ("__vr_offs" 28 int)) 32 8)
                        '((("gp_offset" 0 int) ("fp_offset" 4 int) ("overflow_arg_area" 8 (ptr void))
                           ("reg_save_area" 16 (ptr void))) 24 8)),
                 pin (t 'types) "__builtin_va_list" '(arr (struct "__va_list_tag") 1),
                ; gcc's predefined typedef names for the wide pair, wherever __int128 itself reads
                 pin (t 'types) "__int128_t" 'i128,
                 pin (t 'types) "__uint128_t" 'u128,
                ; the bswap trio's sigs, seeded so the results type unsigned (a
                ; swapped high bit is real: compare/divide/sizeof read the width)
                 pin (t 'sigs) "__builtin_bswap16" '(ushort (ushort) ()),
                 pin (t 'sigs) "__builtin_bswap32" '(uint (uint) ()),
                 pin (t 'sigs) "__builtin_bswap64" '(ulong (ulong) ()),
                ; the popcount trio. the operand is unsigned (a set high bit is a bit
                ; like any other); the result is a plain int, gcc's own signature
                 pin (t 'sigs) "__builtin_popcount" '(int (uint) ()),
                 pin (t 'sigs) "__builtin_popcountl" '(int (ulong) ()),
                 pin (t 'sigs) "__builtin_popcountll" '(int (ulong) ()),
                ; ffs: gcc's signed operands, a plain int answer (0 for 0, else the lowest set bit's 1-based index)
                 pin (t 'sigs) "__builtin_ffs" '(int (int) ()),
                 pin (t 'sigs) "__builtin_ffsl" '(int (long) ()),
                 pin (t 'sigs) "__builtin_ffsll" '(int (llong) ()),
                ; C99 _Complex, seeded as two-member structs (canon maps the specifier run onto
                ; these tags), so layout, copy, union membership and the ABI ride the struct lanes
                 pin (t 'stag) "__cplx_double" '((("re" 0 double) ("im" 8 double)) 16 8),
                 pin (t 'stag) "__cplx_float" '((("re" 0 float) ("im" 4 float)) 8 4),
                 pin t 'vlan 0,                   ; the VLA decl-site counter (stamps each site's slot index)
                 pin t 'alias {},         ; __attribute__((alias("t"))) : name -> its target (musl's weak_alias)
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
   ; -- the type floor rides src/apps/moon/floor.l (shapes, sizes, the typing door), read from
   ; gen too. ps carries the two things it takes as parameters: the word and the tag table --
   (pst32? ps) (elem (ps 'tgt) '(thumb2 thumb2sp thumb1))
   ; char is three types (C11 6.2.5p15): 'schar and 'uchar, and plain char -- 'char where the ABI makes it
   ; signed (x86-64, wasm's C conventions), 'cchar where unsigned (AAPCS64, AAPCS32, RISC-V). each
   ; symbol's sign is its own, so nothing past here asks the target
   (pchar ps) (elem (ps 'tgt) '(a64 rv64 thumb1 thumb2 thumb2sp) ? 'cchar 'char)
   (pw64 ps) !(pst32? ps)                          ; is long 8 bytes? the const folder's one question
   (psword ps) (pst32? ps ? 4 8)
   (szty ps) (pst32? ps ? 'uint 'ulong)          ; size_t: sizeof folds wear this coat
   (tsz ps ty) (tysz (psword ps) (ps 'stag) ty)
   (talign ps ty) (tyalign (psword ps) (ps 'stag) ty)

   ; -- parse-time expr typer (for sizeof folding): the undecayed type of an lvalue/pointer
   ; expr, () when unknown (the caller keeps a deferred 'szof then, and gen sizes it). arrays
   ; stay undecayed -- sizeof of an array is its span, and gen's szof reads the same via clval.
   (fldty ps sty nm) (peep (ps 'stag) <>sty () @ e     ; the type of member nm off a struct type
                        (atom? e ? ()
                           (assoc nm <e @ f (two? f ? <>>f))))
   (fmof ps sty nm) (!(stru? sty) ? ()                  ; a member's (byte-offset ty) off a struct type
                       (peep (ps 'stag) <>sty () @ e
                          (atom? e ? ()
                             (assoc nm <e @ f (two? f ? [<>f <>>f])))))
   ; &((T*)0)->fld (and a.b chains over it) folds to the member's byte offset -- the offsetof
   ; idiom. the chain must ground in a deref of a null pointer cast, else it stays an address.
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
       ; a null-grounded pointer value -> (byte-address stride) | (): the cast ((T*)K), and
       ; + arithmetic over it scaled by the pointee. not so grounded stays an address.
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
           ; a null-grounded array member decays to its (constant) address with
           ; the element stride -- &((T*)0)->ts[i] (musl's ioctl compat table)
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
   (ptrarg ps e) (!(two? e && <e = 'bin) ? ()          ; the ptr/arr operand of a `bin + ptr idx` (a[i] desugars so)
                    (: a (ptype ps <>>e) b (ptype ps <>>>e)
                       (? (ptr? a || arr? a) a (ptr? b || arr? b) b ())))
   ; a null pointer constant (C11 6.3.2.3p3): an integer constant expression folding to 0,
   ; with or without a cast to a pointer type -- cfold folds through a cast whose target is
   ; not an integer type, so both spellings arrive here as 0
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
                                    ; (__typeof(open) -- musl's weak_alias declares through it)
                                    (peep (ps 'sigs) <>e () @ sg
                                       (two? sg ? ['fn <sg <>sg]))))))
             (k = 'dot) (ptype ps <>e @ bt (stru? bt ? (fldty ps bt <>>e)))
             (k = 'deref) (ptype ps <>e @ it
                             (? (ptr? it) <>it (arr? it) <>it
                                (ptrarg ps <>e @ pt (? (ptr? pt) <>pt (arr? pt) <>pt ()))))
             (k = 'cast) <>e
             (k = 'clit) <>e
             ; &x is a pointer to x's type -- only when that type is known, so a
             ; wrong element type never reaches a stride fold.
             (k = 'addr) (ptype ps <>e @ it (it ? ['ptr it]))
             (k = 'laddr) '(ptr void)
             ; a call through a named function: its 'sigs return type (the
             ; complex promotion below needs clog's answer to type complex)
             (k = 'call) (: sg (two? <>e && <<>e = 'var ? (peep (ps 'sigs) <><>e ()))
                            (two? sg ? <sg
                               ; else through the callee's own type: a function, or a pointer to one
                               (ptype ps <>e @ ft
                                  (? (two? ft && <ft = 'fn) <>ft
                                     (two? ft && <ft = 'ptr && two? <>ft && <<>ft = 'fn) <><>ft
                                     ()))))
             (k = 'str) ['arr (pchar ps) (#<>e + 1)]     ; a literal is its array (cpp pasted phase 6; the lexer decoded escapes) -- sizeof("ab") folds to 3, an array bound
             ; a literal: sizeof('T') is sizeof(int) (musl's _IOW ioctl codes);
             ; a plain decimal past int32 is a long (suffixed forms arrive cast)
             (k = 'num) (-2147483648 <= <>e && <>e <= 2147483647 ? 'int 'long)
             (k = 'flo) 'double
             (k = 'flof) 'float
             ; arithmetic rides the typing door: ptr - ptr is ptrdiff_t, ptr +- int the
             ; decayed pointer, both-arithmetic puac of the operands -- so sizeof(c + x)
             ; folds to 4, not the register's 8. either side unknown defers to gen's szof.
             (k = 'bin && elem <>e '(+ - * / % & ^ |))
              (: a (ptype ps <>>e) b (ptype ps <>>>e)
                 (? ((ptr? a || arr? a) && (ptr? b || arr? b)) (<>e = '- ? 'long)
                    (ptr? a || arr? a) (elem <>e '(+ -) ? (tdecay a))
                    (ptr? b || arr? b) (<>e = '+ ? (tdecay b))
                    (parith? a && parith? b) (puac !(pst32? ps) a b)
                    ()))
             ; a shift's type is the promoted left operand alone (C11 6.5.7) --
             ; the right side never converts into it
             (k = 'bin && elem <>e '(shl shr))
              (ptype ps <>>e @ a (parith? a ? (pprom a)))
             (k = 'un && elem <>e '(neg bnot))
              (ptype ps <>>e @ a (parith? a ? (pprom a)))
             ; ?: arms meet by puac (6.5.15); same non-arithmetic type rides
             ; through whole (sizeof(c ? s1 : s2) over one struct type)
             (k = 'cond)
              (: a (tdecay (ptype ps <>>e)) b (tdecay (ptype ps <>>>e))   ; an array arm decays (6.5.15)
                 (? (parith? a && parith? b) (puac !(pst32? ps) a b)
                    (two? a && a = b) a
                    ; C11 6.5.15p6: with one operand a null pointer constant the result
                    ; takes the other's type -- the cast is a null pointer constant only
                    ; when its operand folds, which is what the kernel's __is_constexpr reads
                    (npc? <>>e && ptr? b) b
                    (npc? <>>>e && ptr? a) a
                    ; both pointers, one of them to void: pointer to void, same paragraph
                    (ptr? a && ptr? b && a = '(ptr void)) a
                    (ptr? a && ptr? b && b = '(ptr void)) b
                    ()))
             ; a truth value is an int (C11 6.5.3.3, 6.5.8, 6.5.13): !, the six relations,
             ; && and || -- whatever the operand, so no operand typing here
             (k = 'un && <>e = 'not) 'int
             (k = 'bin && elem <>e '(eq ne lt le gt ge)) 'int
             (elem k '(land lor)) 'int
             ; an assignment and an increment answer the lvalue's type, a comma its right side
             (elem k '(asn post)) (ptype ps <>e)
             (elem k '(rmw comma)) (ptype ps <>>e)
             ())))

   ; -- declarators: stars xor one array suffix, plus T (*name)(..) and the dispatch table
   ; T (*name[n])(..). a function pointer is ('ptr ('fn ret ptys)): ret so an indirect call
   ; knows a double result, ptys so it classifies its arguments by the prototype -- the only
   ; thing that tells a float argument from the double it widened to.
   (skipbal s d) (? (d < 1) s
                    (atom? s) ()
                    (peekp s "(") (skipbal >s (d + 1))
                    (peekp s ")") (skipbal >s (d - 1))
                    (skipbal >s d))
   ; a run of [const-expr] / [] suffixes -> (dims rest) | (). the dimension is any integer
   ; constant expression; only the first (outer) dim may be [] (size 0), and a parameter's
   ; [static n] / [const n] (C99 6.7.6.3) drops its quals. a dim that will not fold is a
   ; runtime dim (C99 VLA), carried as ('vdim expr) -- a local decl allocates, a pointee
   ; scales at runtime, sizeof multiplies, anywhere else varr refuses downstream.
   (adims ps ts2 acc) (!(peekp ts2 "[") ? [(rev acc) ts2]
                         (pquals >ts2 @ t2
                            (? (peekp t2 "]") (adims ps >t2 (0 . acc))
                               ; C11 6.7.6.2p4: `[*]` is a prototype's unspecified VLA
                               ; bound, and a parameter decays to a pointer either way
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
   ; the (params)/[dims] suffix run on a direct declarator -> ((name w dat bare) rest).
   ; each suffix wraps inside w (the wrap-so-far: eventual-pointee -> declared type), so
   ; the type grows inside-out; dat is the name's own (params), which a fn def binds;
   ; bare = still just a (paren-wrapped) name, cleared by any suffix.
   (psufs ps ts name w dat bare)
    (? (peekp ts "(")
        (: rp (pparams ps >ts ())
           ; the parameter types, names dropped. a variadic prototype parks () like an
           ; unprototyped one: AAPCS-VFP keeps a variadic argument out of the co-processor
           ; registers, and no `...` rides the type, so the list would place them wrong.
           pt9 (two? rp && !(rp 2) ? (map caup <rp))
           (atom? rp ? () (psufs ps <>rp name (t \ w ['fn t pt9]) (bare ? rp dat) ())))
       (peekp ts "[")
        (adims ps ts () @ ar
           (atom? ar ? () (psufs ps <>ar name (t \ w (mkarr t <ar)) dat ())))
       [[name w dat bare] ts])
   ; direct declarator, recursive: name | ( *.. dtor ), then suffixes -- covers (*name)(params),
   ; the redundant (name), (*const p), and nested forms like `void (*(*x)(a))(b)`. a paren
   ; declarator's pointee is what trails its `)`; the head may be empty (abstract `(*)(params)`).
   ; -> ((name w dat bare) rest) | ()
   (pdirect ps ts)
    (: (nstars s k) (pquals s @ s2 (peekp s2 "*" ? (nstars >s2 (k + 1)) [k s2]))
       (ptrk k t) (k < 1 ? t (ptrk (k - 1) ['ptr t]))
       (? (idat? ts) (psufs ps >ts (tkv <ts) (t \ t) () 1)
          !(peekp ts "(") (psufs ps ts () (t \ t) () ())
          ; a `(` with a type inside opens a parameter list, not a nested declarator (C11
          ; 6.7.7): `int f(int (int), int)`. the star branch below would die on the `)`.
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
   (pdtor ps ts base)                               ; ps threads to adims for const-expr array dims; -> ((name ty) rest) | ()
    ; k marks a run that follows a star: only there does restrict qualify the pointer.
    ; the flag is the declarator's report; the caller decides what it means (pparams files it)
    (: (stars ts2 ty k)
        (pquals ts2 @ s
           (k && rstrq? ts2 ? (pin ps 'sawrstr 1) 0,
            peekp s "*" ? (stars >s ['ptr ty] 1) [ty s]))
       sr (stars ts base 0)
       ty <sr ts2 (pquals <>sr)           ; attrs may sit before the name
       (? (peekp ts2 "(")                            ; a parenthesized declarator -- pdirect recurses,
           ; its wrap lays the declared type over ty; dat (the name's own params)
           ; rides out as the third result element when the declarator is a fn
           (pdirect ps ts2 @ dr
              (atom? dr ? ()
                 (: e <dr ty2 (<>e ty) dat <>>e
                    [(two? dat ? [<e ty2 dat] [<e ty2]) <>dr])))
          !(idat? ts2)           ; no name: an abstract declarator (unnamed proto param)
           (? (peekp ts2 "[")                          ; abstract array `T [n]..` (e.g. `struct timespec const[2]`)
               (adims ps ts2 () @ dr                 ; -> nested arr of ty; pparams decays it to a pointer
                  (atom? dr ? () [[() (mkarr ty <dr)] <>dr]))
              ; ":" is _Generic's association -- an anonymous bitfield never reaches
              ; here (pmembers takes its own ":" arm first), so the widening costs it nothing
              (peekp ts2 ")" || peekp ts2 "," || peekp ts2 ":") [[() ty] ts2]
              ())
          (: name (tkv <ts2)
             ts3 >ts2
             (? (peekp ts3 "(")                       ; name(params) -- a function declarator; type ('fn), the params balance-skipped (cc calls untyped)
                 (skipbal >ts3 1 @ t2
                    (two? t2 ? [[name ['fn ty]] t2]))
                !(peekp ts3 "[") [[name ty] ts3]
                (adims ps ts3 () @ dr               ; one or more [n]/[] suffixes -> a nested arr of ty
                   (atom? dr ? ()
                      [[name (mkarr ty <dr)] <>dr]))))))

   ; -- base types: scalars, struct/union (with bodies), enum, typedef names --
   ; struct bodies register into ps 'stag; answers (ty rest) | ()
   ; ": const-expr" bitfield width (ts starts AT the ":") -> (width rest) | ()
   (pbits ps ts) (!(peekp ts ":") ? ()
                    (pasn ps >ts @ er
                       (atom? er ? ()
                          (cfold (pw64 ps) <er @ cv (charm? cv ? [cv <>er])))))
   ; the extensions ride the `moon` dialect -- ours, and the default. `-std=c` is the fence.
   (moon? ps) (peep ps 'dia 'moon = 'moon)
   ; a label is an identifier then `:` -- and not `::`, which nothing here spells but a
   ; reader might, so the test is on the pair rather than the first token alone.
   (plabel? ts) (<ts @ t
                   (? (atom? ts) 0
                      (tkk t != 'id) 0
                      (peekp >ts ":")))
   (pmembers ps ts acc)                             ; member pairs ((name ty)..); () name = anonymous splice; (name ty width) = a bitfield
    (? (atom? ts) ()
       (peekp ts "}") [(rev acc) >ts]
       ; a bare `;` in a struct body declares nothing. C11 has no such struct-declaration and
       ; gcc takes one anyway (C23 spells it); a macro that cannot know whether it is empty lays one
       (peekp ts ";") (pmembers ps >ts acc)
       ; C11 6.7.2.1: a static_assert-declaration is a struct-declaration and declares no
       ; member -- a whole struct body can be nothing but one (the kernel's BUILD_BUG_ON_ZERO)
       (sassert? ts)
        (pstatic ps ts @ r
           (two? r ? (pmembers ps <>r acc)))
       ; a struct label: `name:` where a member declaration would start -- a virtual member
       ; naming an offset, holding nothing and taking no space. read before the type parse
       ; (a label has no type to parse), and only under the `moon` dialect, since -std=c makes
       ; it a syntax error. it must not be a type name: `s32:32` is an anonymous bitfield
       (moon? ps && plabel? ts && !(tkbty? ps <ts))
        (tkv <ts @ nm
           (two? (want >ts ":") ? (pmembers ps >>ts ([nm 'label] . acc))))
       (pbty ps ts @ br
          (atom? br ? ()
             (: bty <br ts2 <>br
                (peekp ts2 ";" ?                   ; an anonymous struct/union member
                   (stru? bty ? (pmembers ps >ts2 ([() bty] . acc)))
                   (: mq (qspec ps ts bty)   ; _Generic's mask for this run; playout has no slot for it
                      lal (specask ps ts)   ; an ask among the specifiers, every declarator's
                      (asked m a) (max lal a @ n (0 < n ? (m + [() n]) m))
                      (dfin mem2 toks acc2)          ; after a declarator (+ optional bitfield): , or ;
                       ((<mem2 && mq ? (pin ps 'qmemacc ([<mem2 mq] . peep ps 'qmemacc ())) 0),
                        (peekp toks "," ? (dts >toks (mem2 . acc2))
                           (want toks ";" @ rest
                              (two? rest ? [(mem2 . acc2) rest]))))
                      (dts ts3 acc2)                 ; dtor [: width] (, dtor [: width])* ;
                       ; an anonymous bitfield (padding, or a `:0` aligner) is a declarator of
                       ; the list like any other -- `u32 : 31, invalid : 1;` names only the second
                       (peekp ts3 ":" ?
                          (pbits ps ts3 @ bw
                             (atom? bw ? () (dfin [() bty <bw] (pattr <>bw) acc2)))
                       (pdtor ps ts3 bty @ dr
                          (? (atom? dr) ()
                             (peekp <>dr ":")        ; a bitfield: append the width to (name ty)
                              (pbits ps <>dr @ bw
                                 (atom? bw ? () (dfin (<dr + [<bw]) (pattr <>bw) acc2)))
                             ; a trailing __attribute__((..)) on a member declarator: its own ask
                             (dfin (asked <dr (pattpk ps <>dr 2)) (pattr <>dr) acc2))))
                      r (dts ts2 ())
                      ; <r is reversed (dts links) and acc accumulates reversed too
                      ; (pmembers revs at "}"), so prepend as is -- a second rev flips members
                      (two? r ? (pmembers ps <>r (<r + acc)))))))))
   ; lay a member list out; a union flattens every offset to 0. the cursor is a bit position
   ; from the struct start: a bitfield sits at it, bumped to the next declared-type unit only
   ; to avoid straddling (the SysV/gcc packing); its (unit-byte-offset bitoff) is gen's load.
   (bfmem? m) (two? >>m && charm? (m 2))            ; a member carrying a width: (name ty width); (name ty () N) asks N
   ; a __attribute__((..)) run on a struct body, before the tag or after the body: consume
   ; it -> (packed rest aligned), reading whether `packed` rides inside (x64 epoll_event's
   ; kernel ABI needs it, or `data` mislays at 8) and the widest `aligned` ask (0 for none)
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
   (playout ps ms uni pk)                           ; -> (fields size align); pk: packed, every member aligns 1
    (: cap (peep ps 'pack 0)                         ; #pragma pack's: a member's natural alignment at most this
       (capa x) (0 < cap && cap < x ? cap x)
       (go l bit mx acc)
        (atom? l ?
           (: a2 (mx < 1 ? 1 mx)
              [(rev acc) (aup (>> (bit + 7) 3) a2) a2])
           (: m <l name <m ty <>m
              (? (ty = 'label)
                 ; a struct label is a zero-width marker, typed as a zero-length char array so
                 ; `s.hdr` decays to the address and stays an lvalue (offsetof still answers).
                 ; it aligns as what follows it: before a member, that member's own alignment,
                 ; or the label names the padding and &s.hdr != &s.b; at the end, the struct's
                 ; alignment, so a trailing label equals sizeof and mx is already final.
                 (: (nxt r) (atom? r ? () (<>(<r) @ t2 (t2 = 'label ? (nxt >r) t2)))
                    nt (nxt >l)
                    la (? pk 1 nt (capa (talign ps nt)) (mx < 1 ? 1 mx))
                    at (uni ? 0 (aup bit (la * 8) >> 3))   ; a union flattens every offset
                    (go >l bit mx ([name at ['arr 'char 0]] . acc)))
                 (bfmem? m)                          ; a bitfield member (named or anonymous): (name ty width)
                 (: w <>>m
                    usz (tsz ps ty) ubits (usz * 8) a (talign ps ty)
                    _ (0 < cap && cap < a && pin ps 'packbf 1)    ; gcc lets these straddle units; refused
                    nmx (mx < a ? a mx)
                    (? (w = 0) (go >l (aup bit ubits) nmx acc)        ; `:0` -- align the cursor to the unit, no field
                       uni (: fld (name ? [name 0 ['bitfield ty 0 w]])
                              (go >l (bit < ubits ? ubits bit) nmx (name ? (fld . acc) acc)))
                       (: bit2 ((& bit (ubits - 1)) + w > ubits ? (aup bit ubits) bit)   ; bump to avoid straddling the unit
                          uoff (& (bit2 >> 3) (0 - usz))              ; the declared-type-aligned word holding these bits
                          bitoff (bit2 - uoff * 8)
                          fld (name ? [name uoff ['bitfield ty bitoff w]])   ; anonymous -> reserve bits, no field
                          (go >l (bit2 + w) nmx (name ? (fld . acc) acc)))))
                 !name                               ; the anonymous struct/union splice (name absent, no width)
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
                 (: a (max (pk ? 1 (capa (talign ps ty))) (two? >>>m ? (m 3) 0))   ; an ask outranks packed, as gcc has it
                    sz (tsz ps ty)
                    abit (uni ? 0 (aup bit (a * 8)))
                    at (abit >> 3)
                    nmx (mx < a ? a mx)
                    nbit (uni ? (bit < sz * 8 ? (sz * 8) bit) (abit + sz * 8))
                    (go >l nbit nmx ([name at ty] . acc))))))
       (go ms 0 0 ()))
   (panon ps) (peep ps 'anon 0 @ k (pin ps 'anon (k + 1), ".anon" + show k))
   ; a tag defined inside a block is that block's (C11 6.7.2.3), and cannot be scoped the way
   ; an enum constant is: the key is what gen sizes and lays members by, long after the brace
   ; closed. so mint a key and bind the spelling to it for the rest of the block. the key leads
   ; with `.`, so it is not a C identifier and clay says the block is inexpressible.
   ; a scoped binding into table tbl: the old value rides ps 'scopacc, a shadow entry
   ; whoever owns the scope drains (sdrain / note)
   (spin ps tbl nm v)
    (peep (ps tbl) nm 'none @ old
       (pin ps 'scopacc ([tbl nm old] . peep ps 'scopacc ()),
        pin (ps tbl) nm v))
   (ptagkey ps nm)
    (peep ps 'blkd 0 < 1 ? nm
       (: k (peep ps 'anon 0)
          _ (pin ps 'anon (k + 1))
          key ("." + nm + "." + show k)
          (spin ps 'tags nm key,
           key)))
   ; ..and a bare `struct T` reads the innermost block tag of that spelling. with none in
   ; scope it answers the bare name rather than declaring a fresh incomplete tag as C says,
   ; so `struct Node *p;` in a body still means the file-scope Node. accepts more, never less.
   (tagref ps nm) (peep (ps 'tags) nm nm)
   (pbty ps ts0)
    (pquals ts0 @ ts
     (atom? ts ? ()
       (<ts @ t
          (? (tkk t = 'kw && elem (tkv t) tyspec)         ; a run of type specifiers -> one canonical type
              (: (grab l acc) (two? l && tkk <l = 'kw && elem (tkv <l) tyspec ?
                                 (grab >l (tkv <l . acc))
                                 ; a qualifier interleaved in the run (`unsigned const char`):
                                 ; C's declaration specifiers are order-free -- skip and continue
                                 (pquals l @ l2
                                    (two? l2 && tkk <l2 = 'kw && elem (tkv <l2) tyspec ?
                                       (grab l2 acc)
                                       [(rev acc) l])))
                 r (grab ts ())
                 [(canon ps <r) <>r])
             (tkw? t 'struct || tkw? t 'union)
              (: uni (tkw? t 'union)
                 ; an attribute run sits before the tag as well as after the body; unread,
                 ; its own `__attribute__` is taken for the tag name
                 pb (pattpk ps >ts)
                 ts2 <>pb
                 tag (idat? ts2 ? (tkv <ts2))
                 ts3 (tag ? >ts2 ts2)
                 (peekp ts3 "{" ?
                    ; the key is bound before the body parses, so `struct T { struct T *n; }`
                    ; resolves its own name to the tag being defined and not to an outer one
                    (: tag2 (tag ? (ptagkey ps tag) (panon ps))
                       qpre (ps 'qmemacc)    ; _Generic's member marks stack with the bodies
                       mr (pmembers ps >ts3 ())
                       (atom? mr ? ()
                          (: pa (pattpk ps <>mr)       ; a trailing __attribute__((packed)) lays align-1
                             lay (alask (playout ps <mr uni (<pb | <pa)) (max (pb 2) (pa 2)))
                             tu (uni && attrany? <>mr "transparent_union" "__transparent_union__")
                             (? (peep ps 'packbf ()) (pin ps 'packbf (), clblame "a bit-field under #pragma pack is not carried out")
                                (tu && !(tuok? ps lay)) (clblame "a transparent union wants members of one word-sized scalar type")
                             (pin (ps 'stag) tag2 lay,
                              uni ? (pin (ps 'utag) tag2 1) 0,
                              tu ? (pin (ps 'tunion) tag2 1) 0,
                              qmempin ps tag2 qpre,
                              [['struct tag2] <>pa])))))
                    (tag ? [['struct (tagref ps tag)] ts3])))
             (tkw? t 'enum)
              ; the underlying type is unsigned when no enumerator is negative (gcc's choice),
              ; which shows in an enum bit-field: `enum c code : 8` holding 148 must load 148
              ; back, not -108. the tag remembers, so a later `enum c` reads the same signedness.
              (: ts2 >ts
                 tag (idat? ts2 ? (tkv <ts2))
                 ts3 (tag ? >ts2 ts2)
                 ; an enum tag scopes by restoring, not by renaming: the type is a plain integer
                 ; one from here on, so no tag key reaches gen to be resolved late. the width forks
                 ; by ABI -- AAPCS32 wants the smallest type holding every enumerator (gcc's
                 ; -fshort-enums), every other target says int, and pk (a trailing packed) asks the
                 ; same. past the 32-bit word both widen, or a load would truncate the enumerator.
                 (ety pos lo hi pk)
                  (: wide (? (pos && 4294967295 < hi) 'ulong
                             (!pos && (hi > 2147483647 || lo < -2147483648)) 'long ())
                     narrow (? pos (? (hi <= 255) 'uchar (hi <= 65535) 'ushort 'uint)
                               (-128 <= lo && hi <= 127) 'char
                               (-32768 <= lo && hi <= 32767) 'short
                               'int)
                     ty (? wide wide
                           (pst32? ps || pk) narrow
                           pos 'uint 'int)
                     (tag ? (spin ps 'etag tag ty) 0,
                      ty))
                 (peekp ts3 "{" ?
                    (: (consts ts4 v pos lo hi)
                        (? (peekp ts4 "}")                         ; a trailing comma (or empty body): the enum ends
                            (pattpk ps >ts4 @ pa [(ety pos lo hi <pa) <>pa])
                           !(idat? ts4) ()
                           (: name (tkv <ts4)
                              ts5 >ts4
                              vr (peekp ts5 "=" ?
                                    (pasn ps >ts5 @ er              ; = const-expr: fold it (enum consts, 1<<n, A+1) -- not just a literal
                                       (atom? er ? ()
                                          (cfold (pw64 ps) <er @ cv
                                             ; a sun-sized enumerator is still a number, and gcc
                                             ; widens the underlying type rather than refusing
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
                                          (two? rest ? [(ety pos2 lo2 hi2 <pa) <>pa])))))))
                       (consts >ts3 0 1 0 0))
                    [(peep (ps 'etag) tag 'int) ts3]))
             (tkk t = 'id && (peep (ps 'types) (tkv t) 0 ? 1))
              [(peep (ps 'types) (tkv t) 0) >ts]
             ; __auto_type NAME = init: the initializer's own type, parsed here with the cursor
             ; left at the name so the ordinary declarator path runs. gcc allows no other declarator
             (tkk t = 'id && tkv t = autoid)
              (>ts @ r1
                 (? !(idat? r1) ()
                    !(peekp >r1 "=") ()
                    (pasn ps >>r1 @ er
                       (atom? er ? ()
                          (ptype ps <er @ ty
                             (ty ? [ty r1]))))))
             ; __typeof(expr) / __typeof__(type-name) (gcc): the operand's parse-time type --
             ; a type-name reads pcty, an expression ptype (whose 'sigs lane carries weak_alias)
             (tkk t = 'id && elem (tkv t) tyofid)
              (want >ts "(" @ r1
                 (? (atom? r1) ()
                    (tyat? ps r1) (thenw (pcty ps r1) ")")
                    (thenw (pasn ps r1) ")" @ er
                       (atom? er ? ()
                          (ptype ps <er @ ty
                             (ty ? [ty <>er]))))))
             ()))))
   ; a type-name (casts, sizeof): base + an abstract declarator -- pdtor covers stars,
   ; arrays, and the function-pointer form `T (*)(params)` (name = ()).
   (pcty ps ts)
    (pbty ps ts @ br
       (atom? br ? ()
          (pdtor ps <>br <br @ dr
             (two? dr ? [<><dr <>dr]))))

   (pdecay ty) (? (arr? ty) ['ptr <>ty] (fn? ty) ['ptr ty] ty)   ; _Generic's lvalue conversion
   ; -- the qualifiers _Generic needs. 6.5.1.1 matches on compatible types, where `const char
   ; *` and `char *` are two, and a type here has never carried const/volatile (a qualifier node
   ; would reach all 56 of gen's ptr dispatch sites). so the one consumer that must tell them
   ; apart keeps a marked copy in ps 'qtys, shadowed with 'locals: ('cq q t) over the leaf, q a
   ; mask of 1=const 2=volatile. nothing else reads a marked type.
   ; only the specifier run's qualifier is seen: a mid-declarator `char * const *p` reads
   ; unqualified, which matches more than C does, never less.
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
   ; one token's const/volatile bit. restrict is not in it -- that qualifies aliasing, not
   ; the type's identity, and rides (ps 'rstrs) out of band.
   (cvq t) (? (tkk t = 'kw && tkv t = 'const) 1
              (idv? t "__const") 1
              (tkk t = 'kw && tkv t = 'volatile) 2
              (tkk t = 'id && elem (tkv t) '("__volatile__" "__volatile")) 2
              0)
   ; the specifier run read twice over: its own const/volatile, and what a typedef name in
   ; it brought (`typedef const char *ccp`). -> (own typedef's). sawty ends the walk at the
   ; declarator's name -- past a type specifier the next id is the name, and reading it costs
   ; a string scan plus a hash lookup per declaration in the TU for an answer that is always 0.
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
   ; the widest alignment ask in a specifier run -- `_Alignas(..)` or an `aligned` inside an
   ; attribute -- walked as qrun walks it, to the declarator's name; 0 for none
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
   ; a qualifier after the last star qualifies the pointer -- `int * const`, which no
   ; lvalue-converted controlling expression is compatible with, so the row is unreachable.
   ; stops at anything that is not a star or a qualifier.
   (qtop? ts)
    (: (go l q) (? (atom? l) q
                   (tp? <l "*") (go >l ())
                   (0 < cvq <l) (go >l 1)
                   (qual? <l) (go >l q)
                   q)
       (go ts ()))
   ; the mask a specifier run lays on the leaf of the type it names -- its own const/volatile
   ; plus whatever its typedef carried. over a pointer typedef the run's own does not reach
   ; the leaf: `typedef char *cp; const cp x` is a const pointer; over an array, the elements.
   (qspec ps ts base) (qrun ps ts @ r (ptr? base ? <>r (<r | <>r)))
   ; drain the marks pmembers staged for one body -- the run since qpre -- onto its
   ; tag, and restore the stage for whatever body encloses it.
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
   ; the controlling expression's marked type; everything not on file falls back to ptype,
   ; an unqualified answer.
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
   ; ..and a cast is the one shape whose mark is on file nowhere: the ('cast ty ..) node
   ; keeps the bare type and gen reads that slot, so re-read the type-name off the tokens,
   ; taking the answer only when it strips back to what the node kept.
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
    (: (go l w) (atom? l ? w                       ; w carries the default: one pass settles it
                   (: r <l t <r q <>r e <>>r
                      (!q && t = ty ? [1 e] (go >l (t = 'dflt ? [1 e] w)))))
       (go rows ()))

   ; complex usual-arithmetic conversion (C99 6.3.1.8): one side complex, the other
   ; arithmetic-real -> the real side rises to {x, 0} (a clit, single-eval), so gen's
   ; complex lane only meets complex operands
   (cxwrap ty x) ['clit ty ['init [x '(flo 0.0)]]]
   (mkbin ps op l r)
    (: tl (ptype ps l) tr (ptype ps r)
       cl (cplxty? tl) cr (cplxty? tr)
       (? (cl && !cr && tr && !(ptr? tr || arr? tr || stru? tr))
           ['bin op l (cxwrap tl r)]
          (cr && !cl && tl && !(ptr? tl || arr? tl || stru? tl))
           ['bin op (cxwrap tr l) r]
          ['bin op l r]))
   ; one left-associative binary level
   (plevel ps sub ops ts)
    (sub ps ts @ r
       (atom? r ? ()
          (: (more l ts2)
              (: t (two? ts2 ? <ts2)
                 hit (two? t && tkk t = 'p ? (assoc (tkv t) ops))
                 (atom? hit ? [l ts2]
                    (sub ps >ts2 @ r2
                       (two? r2 ?
                          (more (mkbin ps <>hit l <r2) <>r2)))))
             (more <r <>r))))

   ; primary := num | str | id (an enum constant folds here) | ( expr )
   (pprim ps ts)
    (atom? (mark ts) ? ()         ; the bottom of the expression ladder: mark here and a bad operand reports itself, not the operator before it
       (<ts @ t
          (? (tkk t = 'num)                           ; past int on t32, long is too narrow: long long
              [(pst32? ps && 2147483647 < tkv t ? ['cast 'llong ['num (tkv t)]] ['num (tkv t)]) >ts]
             (tkk t = 'unum)                          ; a u-suffixed literal wears its unsignedness (neg/div/shift go unsigned):
              [['cast 'uint ['num (tkv t)]] >ts]     ; 1u an unsigned INT (-1u wraps at 32 bits),
             (tkk t = 'ulnum)                                   ; 1ul an unsigned long -- and on t32, a
              (: v (tkv t)                                      ; value past the 32-bit word promotes to
                 uty (pst32? ps && (v < 0 || 4294967295 < v) ? 'ullong 'ulong)     ; ullong (C99 6.4.4.1)
                 [['cast uty ['num v]] >ts])
             (tkk t = 'ullnum)                                  ; 1ull: the suffix forces 64 bits on t32
              [['cast (pst32? ps ? 'ullong 'ulong) ['num (tkv t)]] >ts]
             (tkk t = 'llnum)                                   ; 1ll: llong on t32, long elsewhere
              [['cast (pst32? ps ? 'llong 'long) ['num (tkv t)]] >ts]
             ; C11 6.4.4.1: an l/L suffix makes the constant a long -- untyped, `i + 2L` is int.
             ; on t32 one past the 32-bit long climbs: hex/octal to ulong first, then long long
             (tkk t = 'lnum)
              (: v (tkv t) sp (t 4)
                 dec !(sp 0 = 48 && 1 < #sp && !(elem (sp 1) '(108 76 117 85)))
                 ty (? !(pst32? ps && 2147483647 < v) 'long
                       (!dec && v <= 4294967295) 'ulong
                       'llong)
                 [['cast ty ['num v]] >ts])
             (tkk t = 'flo) [['flo (cflo (tkv t))] >ts]
             ; an f suffix makes a float constant (C11 6.4.4.2) -- the cast is what
             ; narrows it, so `0.1f == 0.1` is false and sizeof(1.5f) is 4
             (tkk t = 'flof) [['cast 'float ['flo (cflo (tkv t))]] >ts]
             ; an imaginary literal (1.0fi, _Complex_I's spelling) is the complex constant
             ; {0, v}, complex-double -- complex floats compute as doubles too
             (tkk t = 'iflo)
              [['clit '(struct "__cplx_double") ['init ['(flo 0.0) ['flo (cflo (tkv t))]]]] >ts]
             (tkk t = 'str) [['str (tkv t)] >ts]
             ; a wide literal desugars to a bounded compound literal of its element type, so
             ; the init/layout machinery lays elements, never bytes. L -> wchar (int; unsigned
             ; on the arm targets), u -> char16 (ushort, a supplementary code point as its
             ; surrogate pair), U -> char32 (uint). the token's value is canonical UTF-8.
             (elem (tkk t) '(wstr str16 str32))
              (: ety (? (tkk t = 'str16 || ps 'swch) 'ushort
                        (tkk t = 'str32) 'uint
                        (elem (ps 'tgt) '(a64 thumb2 thumb2sp thumb1)) 'uint
                        'int)
                 (s16 l) (? (atom? l) ()
                            (65536 <= <l) (<l - 65536 @ v
                                             (55296 + (v >> 10) . 56320 + (v & 1023) . s16 >l))
                            (<l . s16 >l))
                 cps (utf8dec (tkv t) @ raw (ety = 'ushort ? (s16 raw) raw))
                 (nums l) (atom? l ? [['num 0]] (['num <l] . nums >l))
                 [['clit ['arr ety (#cps + 1)] ['init (nums cps)]] >ts])
             ; _Generic (C11 6.5.1.1): the controlling expression is typed, never
             ; evaluated -- only the selected arm reaches gen. no match, no default: refuse.
             (idv? t "_Generic")
              (: r1 (want >ts "(")
                 rc (two? r1 ? (pasn ps r1))
                 r2 (two? rc ? (want <>rc ","))
                 ga (two? r2 ? (pgarms ps r2))
                 rest (two? ga ? (want <>ga ")"))
                 hit (two? rest ? (gpick <ga (qbare (pdecay (qctl ps r1 <rc)))))
                 (two? hit ? [<>hit rest]))
             ; the varargs builtins (my stdarg.h maps va_* onto these): va_arg's
             ; second operand is a type, so they can't ride the ordinary call path
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
             ; a library builtin is its plain name: rewrite it, and declare the name if
             ; nothing else has, so the call binds and the link pulls the member by need
             (tkk t = 'id && bib? (tkv t) && elem (tkv t) libbin)
              (snip (tkv t) 10 #(tkv t) @ nm
                 (peep (ps 'sigs) nm () ? 0 (pin (ps 'sigs) nm (libsig ps nm)),
                  [['var nm] >ts]))
             ; the type-level builtins each answer a constant at parse: their operands are
             ; types, or an expression never evaluated, so none can ride the call path.
             ; __builtin_offsetof seeds &((T*)0)->NAME, lets the postfix ladder take the
             ; `.b` / `[i]` tail, then folds the address through nulloff like the hand idiom.
             ; a runtime index (`[i]`) folds nowhere: the address itself is the answer, as gcc's
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
             ; __builtin_types_compatible_p: structural equality over the two bare types and
             ; no decay -- an array is not its element pointer (the kernel's __must_be_array)
             (tkk t = 'id && bib? (tkv t) && tkv t = "__builtin_types_compatible_p")
              (: r1 (want >ts "(")
                 ta (two? r1 ? (pcqty ps r1))
                 r2 (two? ta ? (want <>>ta ","))
                 tb (two? r2 ? (pcqty ps r2))
                 rest (two? tb ? (want <>>tb ")"))
                 ; _Generic's marked types, so an inner const tells `const char *` from `char
                 ; *`; the top-level one is dropped, C11's own reading and gcc's for this builtin
                 (two? rest ? [['num (qbare <ta = qbare <tb ? 1 0)] rest]))
             ; __builtin_constant_p: 1 when the parse-time fold settles the operand, 0 when
             ; it does not -- a miss sends the consumer down its runtime lane, the safe end.
             ; the operand is not evaluated, so its side effects are gone.
             (tkk t = 'id && bib? (tkv t) && tkv t = "__builtin_constant_p")
              (: r1 (want >ts "(")
                 ra (two? r1 ? (pasn ps r1))
                 rest (two? ra ? (want <>ra ")"))
                 (two? rest ? [['num (charm? (cfold (pw64 ps) <ra) ? 1 0)] rest]))
             ; __builtin_object_size(p,t) and the dynamic spelling: the answer gcc gives when
             ; it cannot see the object -- (size_t)-1 for types 0/1, 0 for 2/3, the conservative
             ; end both ways, which is what the kernel's fortify checks read to stand down
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
             ; __builtin_assume_aligned(p, a[, off]) is p, the promise dropped (its operands are
             ; constants); __builtin_extract_return_addr(a) is a, no return address being signed
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
                 pc ("__builtin_popcount" + snip (tkv t) 16 #(tkv t))
                 (two? rest ? [(mkbin ps '& ['call ['var pc] [<ra]] ['num 1]) rest]))
             ; __builtin_choose_expr(c,a,b): c must fold, the unchosen arm is parsed and
             ; dropped, so a call to an undefined function in it links clean. arms need not type alike
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
             ; __func__ (C99 6.4.2.2): the enclosing function's name as a string, pinned by the
             ; two body-parsing sites; outside a body it stays an undeclared identifier.
             (idv? t "__func__" && string? (ps 'fnname))
              [['str (ps 'fnname)] >ts]
             ; a name being declared right now is not an enum constant. C11 6.2.1p7: a
             ; declarator's scope begins at the end of its declarator, so `uintptr_t M = f(),
             ; N = g(), n = M * N;` reads the local N -- folding it reads the enum in silence.
             (tkk t = 'id)
              (: nm (tkv t)
                 ev (peep (ps 'declaring) nm () ? () (peep (ps 'enums) nm ()))
                 (cint? ev ? [['num ev] >ts]
                    [['var nm] >ts]))
             ; ({ .. }) -- gcc's statement expression. its value is the last statement when that
             ; is an expression, void otherwise, so the node splits into the leading statements
             ; and that value expression, which gen compiles against the env the decls built
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
   ; the suffix run from a given seed -- ppost seeds with a primary, punary's compound
   ; literal with the clit ((struct kstat){0}.st_atime_sec, (size_t [3]){..}[i])
   ; a call, or a builtin gcc lowers to plain C: isdigit(c) is (unsigned)(c - '0') < 10,
   ; which folds over a constant like any comparison
   ; a transparent union parameter takes any of its members' types: the argument becomes the
   ; union, laid through its first member, which the attribute's word-sized members share
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
              (? (peekp ts2 "(")                     ; a call: the head is any postfix expr (fn pointers)
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
   (ppost ps ts)
    (pprim ps ts @ r
       (atom? r ? () (ppostfrom ps <r <>r)))
   ; ++x desugars by duplicating x, and (asn x (bin + x 1)) evaluates the lvalue twice -- so a
   ; side-effecting one runs its effect twice and the store lands where the load did not. a calm
   ; lvalue duplicates harmlessly and keeps the lanes gen has for it (a bitfield, a pair, a wide
   ; -- `post` refuses all three); anything else rides `post`, which takes the address once and
   ; adds the step back. `op=` has the same wound and goes one door over, to pasn's ('rmw ..).
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
   ; unary (casts and sizeof(TYPE) fold here)
   (punary ps ts)
    (atom? ts ? ()
       (<ts @ t
          (? (ptyat? ps ts)             ; skip quals: (const T*)x is a cast, like the decl sites
              (thenw (pcty ps >ts) ")" @ tr
                 (atom? tr ? ()
                    (: cty <tr rest <>tr
                       (peekp rest "{" ?               ; a compound literal (type){ init } -- an unnamed object,
                                                           ; and a postfix head (member/index ride ppostfrom)
                        (pinit ps rest @ iv
                           (two? iv ? (ppostfrom ps ['clit (fillarr ps cty <iv) <iv] <>iv)))
                       (punary ps rest @ r
                          (atom? r ? ()
                             ; the complex cast lanes (C99 6.3.1.7): same complex passes
                             ; through, a width flip converts componentwise, real -> complex
                             ; is {x, 0}, complex -> real reads .re. a non-lvalue operand
                             ; evaluates once per component read.
                             (ptype ps <r @ sty
                                (? (cplxty? cty)
                                    (? (cplxty? sty && <>sty = <>cty) [<r <>r]
                                       (cplxty? sty)
                                        [['clit cty ['init [['dot <r "re"] ['dot <r "im"]]]] <>r]
                                       [['clit cty ['init [<r '(flo 0.0)]]] <>r])
                                   (cplxty? sty && !(stru? cty))
                                    [['cast cty ['dot <r "re"]] <>r]
                                   [['cast cty <r] <>r]))))))))
             (tkw? t 'sizeof)
              (>ts @ r1
                 (ptyat? ps r1 ?             ; sizeof(const T) too
                     (thenw (pcty ps >r1) ")" @ tr      ; sizeof ( type-name ) -- folds to a constant now
                        (? (atom? tr) ()
                           ; sizeof of a VLA type (struct T[n+1], if_nameindex's malloc):
                           ; the runtime multiply dim * sizeof(elt)
                           (varr? <tr) [['bin '* <>><tr ['num (tsz ps <><tr)]] <>tr]
                           (tsz ps <tr @ n
                              (charm? n ? [['cast (szty ps) ['num n]] <>tr]
                                 (blame <>tr "sizeof an incomplete type")))))
                    (punary ps r1 @ r                 ; sizeof unary-expr | sizeof(expr) -- gen sizes from the type
                       (two? r ? (ptype ps <r @ ty
                                    (? (!ty || varr? ty) [['szof <r] <>r]      ; a VLA's size is runtime: defer to gen's szof
                                       (tsz ps ty @ n
                                          (charm? n ? [['cast (szty ps) ['num n]] <>r]
                                             (blame <>r "sizeof an incomplete type")))))))))
             ; _Alignof (C11 6.5.3.4) through talign, the door playout lays members with, so it
             ; cannot drift. the expression operand is gcc's __alignof__ alone, C11's a type-name.
             (tkk t = 'id && elem (tkv t) '("_Alignof" "__alignof__"))
              (>ts @ r1
                 (? (ptyat? ps r1)
                     (thenw (pcty ps >r1) ")" @ tr
                        (two? tr ? [['cast (szty ps) ['num (talign ps <tr)]] <>tr]))
                    (tkv t != "__alignof__") ()
                    (punary ps r1 @ r
                       (atom? r ? ()
                          (ptype ps <r @ ty
                             (ty ? [['cast (szty ps) ['num (talign ps ty)]] <>r]))))))
             ; __extension__ (gcc) prefixes a cast-expression as a no-op
             (idv? t "__extension__") (punary ps >ts)
             (tp? t "*") (punary ps >ts @ r
                            (two? r ? [['deref <r] <>r]))
             ; gcc's &&L: the address of a label in this function
             (tp? t "&&" && idat? >ts) [['laddr (lname ps (tkv <>ts))] >>ts]
             (tp? t "&") (punary ps >ts @ r
                            (atom? r ? ()
                               (nulloff ps <r @ n   ; the offsetof idiom folds to a constant
                                  (charm? n ? [['num n] <>r] [['addr <r] <>r]))))
             (tp? t "+") (punary ps >ts @ r          ; +x is x promoted (_Generic reads the difference)
                            (atom? r ? ()
                               (ptype ps <r @ ty
                                  (ty && pprom ty != ty ? [['cast (pprom ty) <r] <>r] r))))
             (tp? t "-") (punary ps >ts @ r
                            (two? r ? [['un 'neg <r] <>r]))
             (tp? t "!") (punary ps >ts @ r
                            (two? r ? [['un 'not <r] <>r]))
             (tp? t "~") (punary ps >ts @ r
                            (two? r ? [['un 'bnot <r] <>r]))
             (tp? t "++") (punary ps >ts @ r
                             (two? r ? [(preop <r 1) <>r]))
             (tp? t "--") (punary ps >ts @ r
                             (two? r ? [(preop <r -1) <>r]))
             (ppost ps ts))))
   ; the ladder
   (pmul ps ts) (plevel ps punary '(("*" *) ("/" /) ("%" %)) ts)
   (padd ps ts) (plevel ps pmul '(("+" +) ("-" -)) ts)
   (pshift ps ts) (plevel ps padd '(("<<" shl) (">>" shr)) ts)
   (prel ps ts) (plevel ps pshift '(("<" lt) ("<=" le) (">" gt) (">=" ge)) ts)
   (peq ps ts) (plevel ps prel '(("==" eq) ("!=" ne)) ts)
   (pband ps ts) (plevel ps peq '(("&" &)) ts)
   (pbxor ps ts) (plevel ps pband '(("^" ^)) ts)
   (pbor ps ts) (plevel ps pbxor '(("|" |)) ts)
   ; one left-associative level over the single token s, laying nodes of kind k
   (pone ps sub s k ts)
    (sub ps ts @ r
       (atom? r ? ()
          (: (more l ts2) (peekp ts2 s ?
                             (sub ps >ts2 @ r2
                                (two? r2 ? (more [k l <r2] <>r2)))
                             [l ts2])
             (more <r <>r))))
   (pland ps ts) (pone ps pbor "&&" 'land ts)
   (plor ps ts) (pone ps pland "||" 'lor ts)
   ; gcc's `a ?: b` is `a ? a : b` with a read once: a side-effect-free a is simply repeated
   ; (so a constant stays one), anything else lands in a temp inside a statement expression
   (elvpure? e)
    (e @ (('num || 'flo || 'str || 'var || 'szof) . _) 1
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
          t ("__elvis_" + show n)
          (!ty || !ty2 ? ()
             ['sexpr [['decl [[t (pdecay ty) a]]]] ['cond ['var t] ['var t] b] ty2])))
   (pcond ps ts)
    (plor ps ts @ r
       (? (atom? r) ()
          (peekp <>r "?" && peekp ><>r ":")
           (: re (pcond ps >><>r)
              e (two? re ? (pelvis ps <r <re))
              (two? e ? [e <>re]))
          (peekp <>r "?")
           (thenw (pexpr ps ><>r) ":" @ rt
              (atom? rt ? ()
                 (pcond ps <>rt @ re
                    (two? re ? [['cond <r <rt <re] <>re]))))
          r))
   (pasn ps ts)
    (pcond ps ts @ r
       (atom? r ? ()
          (: t (two? <>r ? <<>r)
             hit (two? t && tkk t = 'p ? (assoc (tkv t) asnops))
             (atom? hit ? r
                (pasn ps ><>r @ r2
                   (atom? r2 ? ()
                      (: lv <r op <>hit
                         ; a global register variable is read-only here: writing the stack
                         ; pointer through a plain assignment is a program losing its frame
                         greg (two? lv && <lv = 'var && two? (peep (ps 'gregs) <>lv ()))
                         (greg ? (blame <>r2 "a write to a global register variable")
                            [(? !op ['asn lv <r2]                      ; plain =: no duplicate to make
                                 (calm? lv) ['asn lv ['bin op lv <r2]] ; the desugar, exact here
                                 ['rmw op lv <r2])                     ; evaluate the lvalue once
                               <>r2]))))))))
   (pexpr ps ts) (pone ps pasn "," 'comma ts)

   ; an initializer is an assignment-expr or a brace list ('init (item..)); an item is plain,
   ; ('dfield name init) or ('didx n init). a designator chain (.a.b = v, .a[i] = v, C99 6.7.9)
   ; parses as a path and dbuild nests it, coalescing a consecutive run that shares its head
   ; into one sub-init -- split items would image the member twice, each zero-padding over the
   ; other. initializers nest, and a trailing comma is ok.
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
       ; a scalar initializer that folds is its number -- `(Bits>>3)`-style macro values
       ; image as constants (globals demand it, a local loses nothing)
       (pasn ps ts @ r
          (atom? r ? ()
             (: e <r v (cfold (pw64 ps) e)
                (? (cint? v) [['num v] <>r]            ; cint?: a sun-sized fold (max-charm's image) is still a number
                   (<e = 'un &&
                    <>e = 'neg && <<>>e = 'flo)
                    [['flo (-1.0 * <><>>e)] <>r]           ; -1.0 in a global image: fold the neg into the literal (times -1, so -0.0 keeps its sign)
                   r)))))
   ; a `[]` bound completes from the initializer (C11 6.7.9p22, 6.5.2.5p22 for a
   ; compound literal); one that implies no count leaves the type as it stands
   ; C11 6.7.9p11: a scalar's initializer may stand in braces, `int x = {0};` (PTHREAD_ONCE_INIT's)
   (scini ty ini)
    (? (arr? ty || stru? ty || varr? ty) ini
       (ini @ ('init (x)) (two? x && elem <x '(dfield didx init) ? ini x)   ; one level: {{0}} is not a scalar's
              ini))
   (fillarr ps ty ini)
    (arr? ty && <>>ty = 0 && charm? (initcount ps <>ty ini) ?
       ['arr <>ty (initcount ps <>ty ini)] ty)
   ; the plain items one object of `ty` takes when its braces are elided (C 6.7.9p20),
   ; answering what is left over: a scalar one, an aggregate its members in order, a union
   ; its first, a char array one when that item is a string. an incomplete tag or a [0]
   ; bound takes nothing, which is how the caller's walk learns to stop.
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
   ; how many array elements an initializer implies (for [] size inference): a string is its
   ; bytes + NUL, a brace list the highest index reached (designated [k] sets the cursor), ()
   ; if it implies nothing. for a plain elided run over element type `elt` the count is how
   ; many times `fills` walks one -- int a[][2] = {1,2,3,4} is 2 rows.
   (allplain? items) (foldl (ok \ it \ ok && !(elem <it '(init didx dfield))) 1 items)
   (initcount ps elt ini)
    (? (two? ini && <ini = 'str) (#<>ini + 1)
       ; a wide literal (a bounded clit-of-array after the desugar): its own bound
       (two? ini && <ini = 'clit && arr? <>ini && !(ptr? elt)) <>><>ini
       (two? ini && <ini = 'init)
        (<>ini @ items
           ; { "s" } sizing a char array (6.7.9p14): the string's own count,
           ; not one item (a lone str on a POINTER elt stays one: char *p[])
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
        (pexpr ps >ts @ er                         ; a designator index: any const-expr ([KMint]=.., [2]=..)
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
   ; the item stream carries (path value) pairs (path () = a plain item); dbuild folds them
   ; into 'dfield/'didx items, one nested init per consecutive same-head run
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
                subs <gr
                sub (dbuild subs)
                node (atom? >subs && atom? <<subs ? <sub ['init sub])
                ([(<h = 'f ? 'dfield 'didx) <>h node] . dbuild <>gr)))))
   ; -> (((path value)..) rest) | () -- a list, because a range designator is one item per
   ; index. gcc takes a range as an array designator only and only alone; capped at 64k
   ; items (a hash table's 1 << 14 heads, NR_CPUS) so a runaway bound refuses
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

   ; a constant-expression folder: an integer | () when the expression is not a compile-time
   ; constant (sizeof/enum already folded to num). it folds C's way, each value in its type
   ; (cfty): operands meet at the usual arithmetic conversions (puac), so -1 < 1u is 0 and
   ; -6 / 3u divides unsigned, and every result wraps to its type's width. w64: long is 8
   ; bytes. the answer is the value in its type: an unsigned one never negative.
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
   (blen v) (v = 0 ? 0 (1 + blen (v >> 1)))
   (bctz v) (v & 1 = 1 ? 0 (1 + bctz (v >> 1)))
   (bpop v) (v = 0 ? 0 ((v & 1) + bpop (v >> 1)))
   (bswp v n) (n = 0 ? 0 ((v & 255) * (2 ** (8 * (n - 1))) + bswp (v >> 8) (n - 1)))
   ; v already in ty, unsigned -> (value type) | (); clz and ctz of 0 are undefined, no fold
   (bfold w64 op ty v)
    (op @ 'bswap [(bswp v (tbits w64 ty // 8)) ty]
          'clz (v = 0 ? () [(tbits w64 ty - blen v) 'int])
          'ctz (v = 0 ? () [(bctz v) 'int])
          'pop [(bpop v) 'int]
          'ffs [(v = 0 ? 0 (bctz v + 1)) 'int]
          ())
   ; a literal is an int where it fits, else the long that holds it (ilp32 spells one past int llong)
   (numt w64 n) (? (-2147483648 <= n && n <= 2147483647) 'int
                   w64 (n < (2 ** 63) ? 'long 'ulong)
                   (n < (2 ** 63) ? 'llong 'ullong))
   ; a const float expression -> its gem | 'bad, for the one place cfold needs one. gen.l's
   ; ffold is the image-time twin; both stand on love's own doubles, which are the target's.
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
                 (elem op '(shl shr))                   ; the left operand's promoted type; the count is a count
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
              ; C11 6.6p6: a cast to an integer type may take a float constant -- an array dim is
              ; where it matters, since an unfoldable one reads as a VLA in silence. a cast to
              ; `double` takes the same fold and keeps its fraction
              (? (two? r) (? (ity? ty) (wr ty <r)
                             (ptr? ty) (wr (w64 ? 'ulong 'uint) <r)
                             r)                       ; a type this fold does not know: the value rides
                 !(ity? ty) ()
                 (fcfold w64 <>>e @ f
                    (? (f = 'bad) ()
                       (ty = 'bool) [(f = 0.0 ? 0 1) 'bool]   ; to _Bool is a compare, never a truncation
                       (wr ty (ceil (f // 1)))))))           ; and every other one truncates toward zero
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
          ; ('cond c a b): only the selected arm need be constant (C11 6.6: 1 ? 0 : 1/0 is one);
          ; when the other folds too, the arms meet at their common type
          (<e = 'cond)
           (cfty w64 <>e @ c
              (atom? c ? ()
                 (: r (<c = 0 ? (cfty w64 <>>>e) (cfty w64 <>>e))
                    o (<c = 0 ? (cfty w64 <>>e) (cfty w64 <>>>e))
                    (? (atom? r) () (atom? o) r (wr (puac w64 <>r <>o) <r)))))
          ()))
   ; _Static_assert ( const-expr [, "message"] ) ; -> (('tdef) rest) | () -- an assertion that
   ; folds to false fails the compile, a non-constant one is let by. the message is optional
   ; (C23), so a `)` where the comma would be is the short form, not a refusal.
   (pstatic ps ts)
    (: r1 (want >ts "(")
       re (two? r1 ? (pcond ps r1))
       r2 (two? re ? (want <>re ","))
       r3 (strat? r2 ? >r2)
       r4 (? (two? r3) (want r3 ")")                ; the long form: expr, "message"
             (two? re) (want <>re ")") ())          ; ..and the short one: expr alone
       ; peek for the `;`, then take the tail: want answers the remainder, () when the matched
       ; token was the last one -- a TU that is only an assert would read as no `;` found
       (!(two? r4 && peekp r4 ";") ? ()
          (cfold (pw64 ps) <re @ v
             (charm? v && v <= 0 ? () ['(tdef) >r4]))))
   (sassert? ts) (two? ts && idv? <ts "_Static_assert")

   ; decl := type [dtor [= asn] (, dtor [= asn])*] ;
   ; a local's __attribute__((cleanup(f))) comes off its tokens before the declaration reads,
   ; and the block gets ('cln name f id) after it; pcln lays the calls. one declarator only
   (pdecl ps ts)
    (clstrip ts @ cs
       (? !<cs (pdecl0 ps ts)
          (<cs = 'many) (blame ts "more than one cleanup in one declaration")
          (: r (pdecl0 ps <>cs)
             d (two? r ? <r)
             es (two? d ? <>d)
             (? (atom? d) r
                ; the attribute trails the first declarator's name; in the specifiers of a
                ; many-declarator declaration it would clean them all
                !(<d = 'decl && two? es && (atom? >es || <>>cs = <<es))
                 (blame <>r "a cleanup wants one automatic variable")
                (1 + peep ps 'clid 0 @ n
                   (pins ps 'clid n 'clfn 1 'clpend ['cln <<(<>d) <cs n],
                    r))))))
   (clat l i) (? (atom? l) () (i = 0) l (clat >l (i - 1)))   ; the tail at token i
   (clp? l i s) (clat l i @ t (two? t && tp? <t s))
   (cli? l i s) (clat l i @ t (two? t && idv? <t s))
   (clgrp? l) (cli? l 0 "__attribute__" && clp? l 1 "(" && clp? l 2 "(" &&
               (cli? l 3 "cleanup" || cli? l 3 "__cleanup__") &&
               clp? l 4 "(" && idat? (clat l 5) && clp? l 6 ")" && clp? l 7 ")" && clp? l 8 ")")
   ; over the first declarator, up to its `=` `,` or `;` -> (f-name | () | 'many  tokens
   ; the-word-before-the-attribute)
   (clstrip ts)
    (: (go l d acc f pv)
        (? (atom? l) [() ts]
           (d = 0 && (tp? <l ";" || tp? <l "=" || tp? <l ",")) (f ? [f (rev acc + l) pv] [() ts])
           (clgrp? l) (go (clat l 9) d acc (f ? 'many (tkv <(clat l 5))) (two? acc ? (tkv <acc)))
           (tp? <l "(" || tp? <l "[" || tp? <l "{") (go >l (d + 1) (<l . acc) f pv)
           (tp? <l ")" || tp? <l "]" || tp? <l "}") (go >l (d - 1) (<l . acc) f pv)
           (go >l d (<l . acc) f pv))
       (go ts 0 () () ()))
   (pdecl0 ps ts)
    (: br (pbty ps ts)
       stat (leadstatic? ps ts)                          ; block-scope `static` -> ('sdecl ..), laid in .bss
       ; block-scope `extern` declares the file-scope object -- no slot laid, no local name,
       ; exactly as the function declaration below already reads
       ext (leadextern? ps ts)
       regv (leadregister? ps ts)
       (atom? br ? ()
          (: base <br ts0 <>br
             bq (qspec ps ts base)   ; the run's const/volatile -- _Generic's, staged below
             lal (specask ps ts)   ; an ask among the specifiers, every declarator's
             (peekp ts0 ";" ? [['decl ()] >ts0]   ; a bare definition (struct S {..};)
                (: (one ts2)
                    (pdtor ps ts2 base @ dr
                       (atom? dr ? ()
                          (: name <<dr ty0 <><dr
                             ; a VLA local: stamp the decl site's slot index onto the type
                             ; (gen's prescan keys its ptr/size slots by it); an initializer
                             ; or a `static` VLA refuses
                             ty (!(varr? ty0) ? ty0
                                   (peep ps 'vlan 0 @ ix
                                      (pin ps 'vlan (ix + 1),
                                       ty0 + [ix])))
                             ts30 (pattr <>dr)                 ; a trailing __attribute__((..)) on a local declarator
                             ; `register T v asm("x0")`: GNU's register variable. the name rides
                             ; the declarator as a fourth element, the pin gen's inline asm reads
                             ap (regv && two? ts30 && asmid? <ts30 && peekp >ts30 "(" &&
                                 strat? >>ts30 && peekp >>>ts30 ")" ?
                                   [(tkv <>>ts30) >>>>ts30])
                             pinl0 (two? ap ? [<ap])
                             ; the ask past the type's own rides a fifth slot, the fourth () unless pinned
                             ask (max lal (pattpk ps <>dr 2))
                             pinl (talign ps ty < ask ? ((two? pinl0 ? pinl0 [()]) + [ask]) pinl0)
                             ts3 (two? ap ? <>ap ts30)
                             ; stage the marked type for the bind that follows; bindloc
                             ; consumes it, so a mark cannot outlive its declaration
                             (bq ? (pin (ps 'qstage) name (qmark bq ty)) 0,
                             ; a block-scope function declaration declares an extern function --
                             ; no storage, no local slot. its sig joins the table unless a
                             ; file-scope prototype already said more; the entry drops out below.
                              !(fn? ty) || peep (ps 'sigs) name () ? 0
                                (pin (ps 'sigs) name [<>ty () ()]),
                             ; the declarator is finished, so the name is in scope for every
                             ; initializer after it; the block's shadowdecl does the durable hiding
                              pin (ps 'declaring) name 1,
                              (? (varr? ty && (stat || peekp ts3 "=")) ()
                                 (peekp ts3 "=")
                                 ; the name types in its own initializer (typeof(p), sizeof *p),
                                 ; bound for the initializer's parse and put back after
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
                          (peekp <>r ",") (more ><>r (<r . acc))
                          (: rest (want <>r ";")
                             es (filter (e \ !(fn? <>e)) (rev (<r . acc)))
                             ; the extern entries hoist to the TU's top, where gen's global
                             ; pass reads them, and the block keeps none of them
                             (ext && two? es ?
                                (: (gox l) (atom? l ? 1
                                              (pin (ps 'globals) <<l <><l, gox >l))
                                   (pin ps 'hoist (['xdecl es] . ps 'hoist),
                                    gox es)),
                              two? rest ? [[(stat ? 'sdecl 'decl) (ext ? () es)] rest]))))
                   ; the marks live for this declaration only -- saved and put back, because a
                   ; declaration nests (a `for` init, an initializer carrying a compound literal)
                   olddecl (ps 'declaring)
                   _ (pin ps 'declaring {})
                   res (more ts0 ())
                   (pin ps 'declaring olddecl,
                    res))))))

   ; asm [volatile] [goto] ( "template" [: outputs [: inputs [: clobbers [: labels]]]] ) ; -- the GNU
   ; statement form, the template in holo's neutral text (src/love/holo/text.l; gen assembles it). adjacent
   ; template strings concatenate. operands ride as ((constraint expr)..), clobbers as
   ; (string..), labels as (name..) -- the constraint grammar is gen's.
   ; -> (('asm tmpl outs ins clobs labs) rest) | ()
   (asmid? t) (two? t && tkk t = 'id &&
               elem (tkv t) '("asm" "__asm__" "__asm"))
   ; `volatile` and `inline` may both stand between the keyword and the paren, in
   ; either order; inline is a size hint to gcc's inliner and means nothing here
   (asmqual? t) (? (tkk t = 'kw) (elem (tkv t) '(volatile inline goto))
                   (tkk t = 'id) (elem (tkv t) '("__volatile__" "__inline__" "__inline"))
                   ())
   ; `%[name]` -> the operand's number, so no name reaches gen's asmsub. gcc numbers outputs
   ; first, inputs after and labels last, the order nms arrives in; a modifier letter keeps its
   ; place (`%l[name]` a label, `%c[name]` a bare constant). an unmatched name is left for gen
   (anynm? l) (? (atom? l) () (string? <l) 1 (anynm? >l))
   (asmnm tmpl nms)
    (: n #tmpl
       (idx nm l k) (? (atom? l) () (<l = nm) k (idx nm >l (k + 1)))
       (rbr j) (? (n <= j) -1 (tmpl j = 93) j (rbr (j + 1)))
       (go i acc)
        (: md (i + 2 < n && alpha? (tmpl (i + 1)))     ; %c[ reads past the letter
           b (md ? (i + 2) (i + 1))
           (? (n <= i) acc
              (tmpl i = 37 && i + 1 < n && tmpl (i + 1) = 37) (go (i + 2) (acc + "%%"))
              (tmpl i = 37 && b < n && tmpl b = 91)
               (: e (rbr (b + 1))
                  nm (e < 0 ? () (snip tmpl (b + 1) e))
                  k (string? nm ? (idx nm nms 0))
                  (charm? k ? (go (e + 1) (acc + snip tmpl i b + show k))
                     (go (i + 1) (acc + string (tmpl i)))))
              (go (i + 1) (acc + string (tmpl i)))))
       (go 0 ""))
   (pasm ps ts)
    (: r >ts
       (t1 l) (two? l && asmqual? <l ? (t1 >l) l)
       r0 (want (t1 r) "(")
       (!(strat? r0) ? ()
          (: (tmpl ts2 acc) (strat? ts2 ?
                               (tmpl >ts2 (acc + tkv <ts2))
                               [acc ts2])
             ; an operand run: [name] "constraint" ( expr ) , .. -- empty before : or ). each
             ; entry carries its symbolic name (or ()) third; the names come off again below
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
                               semi (two? r9 && peekp r9 ";")      ; the rest may be empty: a file can end here
                               nms (map opnm <s1 + map opnm <s2 + <s4)
                               tm (anynm? nms ? (asmnm <tr nms) <tr)
                               (semi ?
                                  [['asm tm (map opbare <s1) (map opbare <s2) <s3 <s4] >r9]))))))))))

   ; a file-scope asm("..") is gcc's basic form: gas's whole language, sections and data
   ; included, which gen hands to holo's gas-top. operands have nothing to bind to out here
   ; -> (('tasm tmpl) rest) | ()
   (ptasm ps ts)
    (pasm ps ts @ r
       (atom? r ? ()
          (<r @ ('asm t () () () ()) [['tasm t] <>r]
                (blame >ts "a file-scope asm takes no operands"))))

   ; a statement-position __attribute__((..)) run skips, except two: musttail lands in the
   ; ret's pre slot (clay's (ret e PRE)) and gen's sibcall pass spells the tail jump or refuses;
   ; holo marks an asm template as holo's neutral text. on any other statement either refuses.
   (attrin a b nm) (a = b ? ()                  ; a `nm` token before the b spine?
                      (idv? <a nm || attrin >a b nm))
   ; a bare non-zero integer constant returned where the enclosing sig says pointer.
   ; the literal alone: a cast (or any expression) says the program means it
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
             (: r (sassert? ts ? (pstatic ps ts) (pstmt2 ps ts))
                mt (attrin ts0 ts "musttail")
                ho (attrin ts0 ts "holo")
                (? (!mt && !ho) r
                   (atom? r) ()
                   (<r @ st
                      (? (mt && <st = 'ret && two? <>st) [(st + '("__attribute__((musttail))")) <>r]
                         (ho && !mt && <st = 'asm) [(st + '(holo)) <>r]
                         ())))))))
   ; a label is a flat marker so a block can splice it beside the statement it labels. an arm --
   ; a brace-less if/while/do/for body -- has no list to splice into, and the marker alone would
   ; be the arm, so an arm takes the marker run with the statement under it, as one block.
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
                       ; C11 6.8.6.4 hands `return` to the assignment constraints, and 6.5.16.1
                       ; takes an integer for a pointer only as a null pointer constant
                       (intptr? ps <r) (blame <>r "an integer where a pointer is owed")
                       (want <>r ";" @ rest
                          (two? rest ? [['ret <r] rest])))))
             (tkw? t 'if)
              (: rc (pparen ps ts)
                 rt (two? rc ? (parm ps <>rc))
                 ; if (__builtin_expect(e, k)): the test is e, and a (nop cold) or (nop hot) heads
                 ; the then-arm for the layout -- no call reaches the analyses
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
                    (: ri (? (tyat? ps r1) (pdecl ps r1)        ; the decl gate skips quals, like a block's (`for (const char *x; ..`)
                             (peekp r1 ";") [() >r1]
                             (thenw (pexpr ps r1) ";" @ r
                                (two? r ? [['expr <r] <>r])))
                       ; a cleanup variable in the init lives across the whole loop: it moves
                       ; into a block around the for, so a break leaves its scope and a continue does not
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
                 ; a braced body is a block (its declarations scope to it, case and default
                 ; are statements pstmt reads) and the switch keeps its flat items. a brace-less
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
             ; case/default are labels, legal at any statement depth and not just as a direct
             ; child of the switch body (Duff's-device style); gen ties each back to its nearest
             ; enclosing switch by case value (g 'cases). gcc's `case A ... B:` expands to one
             ; label per value -- sound because a switch dispatches by a compare chain, not a
             ; table -- and is capped, so a wide range refuses rather than laying thousands.
             (tkw? t 'case)
              (pexpr ps >ts @ rv
                 (atom? rv ? ()
                    (: v (cfold (pw64 ps) <rv)
                       (crange lo hi acc) (hi < lo ? (rev acc) (crange (lo + 1) hi (['case lo] . acc)))
                       (? !(charm? v) ()
                          (peekp <>rv "...")
                           (pexpr ps ><>rv @ r2
                              (atom? r2 ? ()
                                 (: hi (cfold (pw64 ps) <r2)
                                    rest (want <>r2 ":")
                                    (? !(charm? hi) ()
                                       (atom? rest) ()
                                       (hi < v) (blame <>rv "an empty case range")
                                       (1024 < hi - v) (blame <>rv "case range too wide")
                                       [['blk (crange v hi ())] rest]))))
                          (want <>rv ":" @ rest
                             (two? rest ? [['case v] rest]))))))
             (tkw? t 'default)
              (want >ts ":" @ rest (two? rest ? ['(dflt) rest]))
             (asmid? t) (pasm ps ts)     ; before the call/label fallthroughs: asm( is a statement
             (tp? t "{") (pblock ps ts)
             (tp? t ";") ['(nop) >ts]
             ; a label: id ':' (a ternary's id is followed by '?', never ':')
             (plabel? ts)
              ; C11 6.8.1p3: a label's scope is its whole function, so two of a name are one
              ; label emitted twice and every goto to it takes the first -- silently.
              (lname ps (tkv t) @ nm
                 (peep (ps 'labs) nm () ? (blame ts ("duplicate label '" + nm + "'"))
                    (pin (ps 'labs) nm 1, [['lbl nm] >>ts])))
             (thenw (pexpr ps ts) ";" @ r
                (two? r ? [['expr <r] <>r])))))
   ; block-scoped shadowing (C scope): a local whose name is a typedef or an enum constant
   ; hides it for the rest of the block, so `name op name` reads as an expression and a read
   ; of the local stays a var. record (table name old); a typedef pins to 0 (not-a-type), an
   ; enum constant is pulled (the fold site tests charm?, and 0 is a charm); restore on exit.
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
   ; a type specifier binds names wherever it is written (an enum body's constants and its
   ; tag's signedness, a block tag's spelling) and at block scope C11 gives every one of them
   ; that block. so move the run pbty staged since epre onto the block's shadow list, newest
   ; first as unshadow wants, and hand the stage back to whatever encloses it. file scope
   ; drains nowhere -- `note` clears the run per top-level form instead.
   (sdrain ps epre shadows)
    (: now (ps 'scopacc)
       (go l k) (k < 1 ? shadows (<l . go >l (k - 1)))
       (pin ps 'scopacc epre,
        go now (#now - #epre)))
   (unshadow ps shadows) (atom? shadows ? ()
                            (<shadows @ e
                               (<>>e = 'none ? (pull (ps <e) <>e 0) (pin (ps <e) <>e <>>e),   ; 'none = the name was absent (a fresh local): remove it, don't pin the sentinel
                                unshadow ps >shadows)))
   ; record a local/param name -> type into ps 'locals, saving the old binding ('none if
   ; fresh) on the block's shadow list so unshadow restores C scope; 'qtys shadows alongside.
   ; ent is (name ty ..) -- a decl entry (name ty ini) or a param (name ty).
   ; consume the mark a declarator parse staged for nm: it binds only when it strips back to
   ; the type actually filed, else the name's old mark goes too
   (qtake ps nm ty)
    (: nq (peep (ps 'qstage) nm 'none)
       st (nq != 'none)          ; a stage is there -- a comparison, not the datum's own truth
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
   ; a block-scope typedef: pin each declarator into ps 'types, saving the old binding on the
   ; block's shadow list ('none = fresh); file scope (tdeflist) hands an empty list and drops
   ; the answer. -> (rest sh2) | (); peek for the `;`, the remainder may be empty (EOF).
   (btdefs ps base ts sh bq)
    (pdtor ps ts base @ dr
       (atom? dr ? ()
          (: nm <<dr
             old (peep (ps 'types) nm 'none)
             _ (pin (ps 'types) nm <><dr)
             _ (bq ? (pin (ps 'qtdef) nm bq) 0)
             sh2 (['types nm old] . sh)
             af (patt <>dr)                ; glibc trails __attribute__ on a typedef's declarator
             (? (peekp af ",") (btdefs ps base >af sh2 bq)
                (peekp af ";") [>af sh2]
                ()))))
   (pblock ps ts)
    (: ts0 (want ts "{")
       epre (ps 'scopacc)
       ; the depth a tag definition reads to know it is not at file scope; bend restores it
       ; alongside the shadow list on every way out of the block
       d0 (peep ps 'blkd 0)
       _ (pin ps 'blkd (d0 + 1))
       (bend sh) (pin ps 'blkd d0, unshadow ps sh)
       (atom? ts0 ? (bend ())
          (: (items ts2 acc sh)
              (? (atom? ts2) (bend sh, ())
                 ; the last expression's type, read while the block's names still stand (a
                 ; statement expression's value is typed off it)
                 (tp? <ts2 "}") (: lv (two? acc ? <acc)
                                   (pin ps 'blkval (two? lv && <lv = 'expr ? (ptype ps <>lv)),
                                    bend sh,
                                    [['blk (rev acc)] >ts2]))
                 (idv? <ts2 "__extension__") (items >ts2 acc sh)
                 (idv? <ts2 "__label__") (plabs ps >ts2 sh @ r (items <r acc <>r))
                 (tkw? <ts2 'typedef)
                  (: br (pbty ps >ts2)
                     r (two? br ? (btdefs ps <br <>br (sdrain ps epre sh) (qspec ps >ts2 <br)))
                     (atom? r ? (bend sh, ())
                        (items <r acc <>r)))
                 (: r (tyat? ps ts2 ? (pdecl ps ts2) (pstmt ps ts2))
                    cm (clpop ps)                   ; a cleanup's marker rides after its decl
                    (atom? r ? (bend sh, ())
                       ; the enum body parses before the declarators bind, so its entries go
                       ; under theirs -- unshadow walks newest first and the oldest wins
                       (items <>r ((cm ? [cm <r] [<r]) + acc) (bindlocs ps (loctypes <r) (shadowdecl ps (declnames <r) (sdrain ps epre sh)))))))
             (items ts0 () ()))))

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
             (: _ (pin ps 'sawrstr ())          ; clear before the report, so it cannot leak between params
                dr (pdtor ps <>br <br)
                (atom? dr ? ()
                   ; a parameter of array type decays to a pointer, so `int a[]` and a
                   ; va_list (an array typedef) both ride as pointers; one of function type likewise
                   (: e0 <dr ty0 <>e0
                      ; (fn ret) here carries no parameter list; the pointer wears the declarator's (fn ret ptys) shape
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

   ; -- K&R definitions: `f(a, b) int a; char *b; { .. }`. the parens hold a bare identifier
   ; list, the parameter types follow as declarations before the `{` (an undeclared id defaults
   ; to int). answers pparams' (entries rest variadic?) with rest at the `{`. a bare non-type id
   ; after `(` is the sole K&R tell -- and a qualifier spelled as an identifier (`__const`,
   ; `__restrict`) is a name a K&R list cannot hold, so it opens a prototype.
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
          (: nm <<dr ty0 <><dr rest <>dr
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
   ; a function definition from its `{`: params bound for the body's parse, __func__ and the
   ; label table per function, all undone on the way out. -> (('fn name params body) rest) | ()
   (pfbody ps name prms ts)
    (: psh (bindlocs ps prms ())
       _ (pin ps 'fnname name)
       _ (pins ps 'labs {} 'clfn ())
       b (pblock ps ts)
       _ (pin ps 'fnname ())
       _ (unshadow ps psh)
       sig (peep (ps 'sigs) name ())
       b2 (two? b && peep ps 'clfn () ?
              (pcln ps <b (two? sig ? <sig 'int) @ r
                 (r = 'bad ? (clblame "a jump into the scope of a cleanup variable") [r <>b]))
              b)
       (two? b2 ? [['fn name prms <b2] <>b2]))

   ; -- cleanup: the pending marker a declaration left, taken once by the block that holds it
   (clpop ps) (ps 'clpend @ m (pin ps 'clpend (), m))
   ; a refusal found past the tokens: the sentence files at the deepest point read
   (clblame msg) (pins far 'why msg 'wseq (peep far 'seq -1), ())
   ; lays f(&v) on every way out of a cleanup variable's scope: a block's end, return (its
   ; value first held), break and continue to their loop or switch, a goto to a label
   ; outside, an asm goto through a landing pad. a jump into a scope answers 'bad
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
       ; the cleanups a jump from st to label nm runs, 'bad into a scope, 'none for no such label
       (leave st nm)
        (peep labt nm 'none @ lt
           (lt = 'none ? ()
              (clids st @ here
                 (any (i \ nelem i here) lt ? 'bad
                    (filter (c \ nelem (c 3) lt) (clup st ()))))))
       ; a block's items -> (items' live-cleanups) | 'bad
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
   ; a comma-list of `*.. name (params)` prototypes sharing one base type; registers each sig,
   ; answers [rest-after-`;`] | (). each sibling's own stars ride into its sig's return slot --
   ; dropped, `struct g *strof(..)` reads as a struct-by-value return.
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
                            ; answer wrapped [rest]: a bare rest conflates the empty
                            ; remainder (a proto list at EOF) with refusal
                            (peekp af ";") [>af]
                            ()))))))))

   ; a comma-list of typedef declarators sharing one base type (`typedef T a, b;`), pinning
   ; each name -> its declared type; btdefs' walk with nothing to shadow, bq the run's mask
   (tdeflist ps base ts bq) (btdefs ps base ts () bq @ r (two? r ? ['(tdef) <r]))

   ; the top level: typedefs, functions, globals, bare type definitions. staticness + the
   ; section attribute are noted at entry (the attribute-skip lanes recurse, so the outermost
   ; sighting wins) and pinned per name by tops.
   (ptop ps ts)
    ((peep ps 'curstat () ? () (leadstatic? ps ts ? (pin ps 'curstat 1))),
     (peep ps 'cursect () ? () (secat? ts @ sc (sc ? (pin ps 'cursect sc)))),
     (peep ps 'curalias () ? () (aliasat? ts @ al (al ? (pin ps 'curalias al)))),
     (peep ps 'curweak () ? () (wkany? ts ? (pin ps 'curweak 1))),
     (peep ps 'curinl () ? () (inlany? ts ? (pin ps 'curinl 1))),
     (peep ps 'curnoinl () ? () (noinlany? ts ? (pin ps 'curnoinl 1))),
     (peep ps 'curused () ? () (usedany? ts ? (pin ps 'curused 1))),
     ; C99 inline: plain `inline` lays no external definition and `extern inline` does; gnu_inline
     ; (the kernel's every `inline`) is gnu89's, the other way about
     (peep ps 'curlink () ? ()
        (pin ps 'curlink (leadkw? ps ts 'inline && !!(leadextern? ps ts) = !!(gnuinlany? ts) ? 'inl 'ext))),
     (peep ps 'curalign () ? () (alignat? ps ts @ an (an ? (pin ps 'curalign an)))),
     ptop9 ps ts)
   (ptop9 ps ts)
    (? (peekp ts ";") ['(tdef) >ts]           ; a stray top-level `;` -- an empty declaration
       ; a leading __extension__ (gcc, a no-op) strips before the keyword checks --
       ; glibc opens `__extension__ typedef` and the typedef lane reads the raw head
       (two? ts && idv? <ts "__extension__") (ptop9 ps >ts)
       (sassert? ts) (pstatic ps ts)
       (asmid? <ts) (ptasm ps ts)
       ; a leading __attribute__((..)): the scans at ptop's entry read the whole form, so
       ; skip it and parse the declaration proper
       (pattr ts != ts) (ptop ps (pattr ts))
       ; `extern` data declares, never defines: an init-less gdecl under a leading extern
       ; becomes ('xdecl pairs) -- addressable, no storage laid. protos/typedefs pass through.
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
                gbq (qspec ps ts base)  ; the run's mask, _Generic's; one stages it
                (peekp ts0 ";" ? ['(tdef) >ts0]     ; a bare struct/enum definition
                   (: sr (pstars ts0 base)
                      rty <sr ts1 (pquals <>sr)
                      ; the first declarator: a plain name, or a paren fn-pointer
                      ; `(*name)(params)` routed through pdtor like the comma declarators
                      ; below; the leading stars already rode into rty. -> (name rest ty),
                      ; ty () on the plain path, where the declarator's type is rty
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
                            fprm <>>>fdr                              ; the inner params when the declarator is a function
                            ; the object lanes sit here, not in the third arm: a function-first
                            ; mixed list (`int f(int), a;`) reaches them from the lane above too.
                            ; the marked type stages here, where the entry is final; note's gogl
                            ; consumes it, the way bindloc does for a local
                            (one ts3 nm t2) (one0 ts3 nm t2 @ r
                                               (gbq && two? r ? (pin (ps 'qstage) <<r (qmark gbq <><r)) 0,
                                                r))
                            (one0 ts3 nm t2)                ; t2 is the element type (stars included)
                             (? (peekp ts3 "[")
                                (adims ps ts3 () @ dr  ; one or more [n]/[] dims (enum consts fold)
                                   (atom? dr ? ()
                                      (: dims <dr rest0 (patt <>dr)   ; an array declarator carries trailing attributes too
                                         (atom? >dims && <dims = 0 ?      ; a lone [] -- size from init, or 0 (extern)
                                             (!(peekp rest0 "=") ? [[nm ['arr t2 0] ()] rest0]      ; no init: incomplete, size 0
                                                (pinit ps >rest0 @ ir
                                                   (atom? ir ? ()
                                                      (initcount ps t2 <ir @ n
                                                         (charm? n ?
                                                            [[nm ['arr t2 n] <ir] <>ir])))))
                                            ; multi-dim (or a single sized dim): nested arr, optional init.
                                            ; an outer [] ([][3]) infers its count from the init's top level.
                                            (mkarr t2 dims @ aty0
                                               (peekp rest0 "=" ?     ; T a[n].. = init
                                                   (pinit ps >rest0 @ ir
                                                      (atom? ir ? ()
                                                         [[nm (fillarr ps aty0 <ir) <ir] <>ir]))
                                                  [[nm aty0 ()] rest0]))))))
                                (peekp ts3 "=")
                                 (pinit ps >ts3 @ r
                                    (atom? r ? ()
                                       ; a later declarator arrives with its dims already parsed
                                       ; (`more` runs pdtor first, so t2 is the whole array type and
                                       ; ts3 sits on the `=`), where the first still has its `[`
                                       ; ahead of it -- so a lone [] bound is filled in here too
                                       [[nm (fillarr ps t2 <r) (scini t2 <r)] <>r]))
                                ; a global register variable's row was pinned before its type was
                                ; in hand; fill it in here, where the declarator is done
                                (peep (ps 'gregs) nm () @ gv
                                   (two? gv ? (pin (ps 'gregs) nm [<gv t2]),
                                    [[nm t2 ()] ts3])))
                            (more ts3 acc)
                                (peekp ts3 "," ?
                                   (pdtor ps >ts3 base @ dr
                                      (atom? dr ? ()
                                         (one (patt (pgreg ps <>dr <<dr (leadregister? ps ts))) <<dr <><dr @ r
                                            (two? r ? (more <>r (<r . acc))))))
                                   ; a declarator whose type is a function type (a function-type
                                   ; typedef) declares a function -- register its sig, lay no
                                   ; storage. `;` ends the declaration: peek, since the remainder
                                   ; may be empty (a global at EOF), which want's () conflates
                                   (!(peekp ts3 ";") ? ()
                                      (: rest >ts3
                                         (fnp? pr) (fn? <>pr)
                                         _ (: (regs l) (atom? l ? ()
                                                          (<l @ p2
                                                             ; never clobber a filed sig: this door carries no params, and
                                                             ; over a real prototype it drops the types the call ABI reads
                                                             (fnp? p2 && !(peep (ps 'sigs) <p2 ()) ?
                                                                (pin (ps 'sigs) <p2
                                                                     [(two? ><>p2 ? <><>p2 'long) () ()]),
                                                             ; an alias declared through a function type
                                                             ; (musl's weak_alias) answers a nameless 'tdef,
                                                             ; so the name is recorded here, still in hand
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
                                         ; a const object with an initializer is a candidate for
                                         ; .rodata -- per declarator, since one specifier run serves
                                         ; them all and only some carry a star. an init-less one
                                         ; rides .bss, where it costs no file bytes.
                                         _ (!(leadconst? ps ts) ? ()
                                              (: (goc l) (atom? l ? 1
                                                            (<l @ p
                                                               (cobj? <>p && two? <>>p ?
                                                                  (pin (ps 'consts) <p 1),
                                                                goc >l)))
                                                 (goc vps)))
                                         ; C11 6.7.6.2p2: no variably modified object at file scope
                                         vm (filter (p \ vmod? <>p) vps)
                                         (? (two? vm) (blame rest ("variably modified '" + <<vm + "' at file scope"))
                                            (two? vps) [['gdecl vps] rest]
                                            ['(tdef) rest]))))
                            (? (atom? fpty && peekp ts2 "(")        ; a function (the return type rides the sig table)
                               (: rp (krhead? ps >ts2 ? (pkr ps >ts2) (pparams ps >ts2 ()))
                                  (atom? rp ? ()
                                     (: _ (pin (ps 'sigs) name (mksig rty rp))
                                        aft (patt <>rp)                     ; a trailing __attribute__((..)) after the proto/fn declarator
                                        (? (peekp aft ";") [['proto name] >aft]
                                           ; more comma-separated declarators sharing base -- each
                                           ; `* nm (params)` is another prototype, ending at `;`. a
                                           ; mixed list (`int f(int), a;`) is not mproto's shape: the
                                           ; object lane takes it, so a static f is filed here
                                           (peekp aft ",")
                                            (mproto ps base >aft @ rest
                                               (two? rest ? [['proto name] <rest]
                                                  ((peep ps 'curstat () ? (pin (ps 'sfns) name 1)),
                                                   more aft ())))
                                           (pfbody ps name <rp aft)))))
                               (fn? fpty)                                ; the declarator is a function (returns a fn-ptr):
                                                                         ; the return type is <>fpty, the params rode fprm out of pdtor
                                (: _ (pin (ps 'sigs) name (mksig <>fpty fprm))
                                   aft (patt ts2)
                                   (peekp aft ";" ? [['proto name] >aft]
                                      (pfbody ps name <fprm aft)))
                               ; a global declaration; the first declarator's stars came off `sr`
                               (one (patt (pgreg ps ts2 name (leadregister? ps ts))) name (two? fpty ? fpty rty) @ first
                                  (two? first ? (more <>first [<first]))))))))))))
   ; a parse refusal names where it stood. the first pass ran unstamped and left no trail, so
   ; stamp just this form and run it through ptop again, marking as it goes. the furthest token
   ; the re-parse reaches is the report site; the form's own first token is the fallback, both
   ; for a form that dies before any lookahead marks and for a re-parse that unexpectedly
   ; succeeds (ps carries the first attempt's half-registered typedefs). no line number in the
   ; message text -- the stamped line is what the driver reports.
   (pfail ps ts2 spans toks)
    (: i0 (#toks - #ts2)       ; the failing form's index -- an O(n) walk, on the path that is already dying
       ft (two? ts2 ? <ts2)
       _ (pin far 'seq -1)
       _ (pin far 'tok ())
       _ (pin far 'why ())
       _ (pin far 'wseq ())
       r (ptop ps (stampf ts2 i0 spans))
       dt (two? r ? () (far 'tok))
       t (two? dt ? dt ft)
       ; a cause filed at the deepest token names the program's fault; anywhere shallower it
       ; belongs to a branch that was abandoned, and does not
       why (peep far 'wseq () = peep far 'seq () ? (far 'why))
       (atom? t ? (gripe () () () "parse error at end of input")
          (gripe (two? dt ? (filof t) (filat spans i0)) <>>t ()
                 (why ? why ("parse error near " + spell t)))))
   ; C11 6.7p4: a redeclared file-scope object keeps a compatible type. what is compared is the
   ; shape -- scalar against pointer against struct, and two different arithmetic types --
   ; which is what autoconf's suffix probes ask (`extern ptrdiff_t foo; extern int foo;`)
   (tyshape t) (? (atom? t) t (ptr? t) 'ptr (arr? t) 'arr (stru? t) t (fn? t) 'fn 'other)
   (tyclash? a b) (? (fn? a || fn? b) () (atom? a && atom? b) (a != b) (tyshape a != tyshape b))
   (redecl ps f)
    (? !(elem <f '(gdecl xdecl)) ()
       (: (go prs) (atom? prs ? ()
                     (<prs @ pr
                        (peep (ps 'globals) <pr () @ old
                           (two? pr && old && <>pr && tyclash? old <>pr ?
                              ("conflicting types for '" + <pr + "'") (go >prs)))))
          (go <>f)))
   (cparse ts) (cparse-t ts 'x64)          ; the law tests + any bare caller: 64-bit widths (unchanged behavior)
   (cparse-t ts tgt) (cparse-d ts tgt 'moon)  ; ..and the default dialect, which is what a bare caller means
   (cparse-d ts tgt dia) (cparse-o ts tgt dia {})
   ; opts: what the driver's flags say about the language beyond the dialect ('swch, -fshort-wchar)
   (cparse-o ts tgt dia opts)
    (: ps (pin (psnew-d tgt dia) 'swch (opts 'swch))
       toks (fsbody ts) spans (fspans ts)
       ; does the unit name volatile anywhere? mooncc's types carry no qualifier, so a unit that
       ; does keeps every load and store where the source put it (gen's memfw stands down)
       vol (foldl (a \ t \ a || tkk t = 'kw && tkv t = 'volatile ||
                           tkk t = 'id && elem (tkv t) '("__volatile__" "__volatile")) () toks)
       ; note the completed form's staticness/section per declared name, then
       ; clear the stashes for the next form
       (note f)
        (: _ (elem <f '(gdecl xdecl) ?         ; register file-scope names -> types (ptype's global fallback)
                ; ..and consume the mark ptop staged for each, on bindloc's terms: only
                ; when it strips back to the type actually filed
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
           ; a function may name its section and its alignment too (love.c's data sentinels):
           ; where the code lands is the point, and the align is what pins the spacing
            sc && fnp ? (pin (ps 'sects) <>f sc),
            an && fnp ? (pin (ps 'aligns) <>f an),
            <f = 'gdecl && (st || sc || an) ?
              (: (go2 prs) (atom? prs ? 1
                              (<<prs @ nm
                                 (st ? (pin (ps 'svars) nm 1),
                                  sc ? (pin (ps 'sects) nm sc),
                                  an ? (pin (ps 'aligns) nm an),
                                  go2 >prs)))
                 (go2 <>f)),
           ; an alias declaration names no storage of its own: it is another name for a symbol
           ; defined in this TU (musl's weak_alias). record name -> target; cgen lays the label.
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
            ; C11 6.7.4p7: a function every file-scope declaration of which is plain `inline` has
            ; an inline definition here and no external one -- the TU saying `extern` lays that
            fnp ? (pin (ps 'c99inl) <>f (peep (ps 'c99inl) <>f 'inl = 'inl && ps 'curlink = 'inl ? 'inl 'ext)),
            pin ps 'curlink (),
           ; the restrict params, filed under this function and never a bare name set: `p` may
           ; be restrict in one function and plain in the next
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
            pin ps 'scopacc (),        ; what a file-scope specifier bound is nobody's to take back
            pin ps 'cursect ()))
       (tops ts2 acc)
        ; the hoisted block-scope externs lead the program: gen's global pass reads them, and
        ; C's tentative rule lets a real definition later in the TU take the entry back
        (? (two? ts2 && tkk <ts2 = 'pack) (pin ps 'pack (tkv <ts2), tops >ts2 acc)   ; cpp's #pragma pack mark
           (atom? ts2) ((map (nm \ (peep (ps 'c99inl) nm () = 'inl ? (pin (ps 'sfns) nm 1))) (keys (ps 'c99inl))),
                      [1 ['prog (ps 'hoist + rev acc)] (ps 'stag) (ps 'sigs) (ps 'weaks)  ; empty acc = a valid empty TU (crypt.c), not a parse failure
                            (ps 'sfns) (ps 'svars) (ps 'sects) (ps 'alias) (ps 'aligns) (ps 'ainl) (ps 'noinl)
                            (ps 'consts) (ps 'rstrs) (ps 'gregs) vol])
           (ptop ps ts2 @ r
              (? !(two? r) (pfail ps ts2 spans toks)
                 (redecl ps <r @ why
                    (why ? (gripe (filat spans (#toks - #ts2)) (<>><ts2) () why)
                       (note <r, tops <>r (<r . acc)))))))
       (attrbad toks spans @ ab (gripe? ab ? ab (tops toks ()))))
   ; an __attribute__ whose skip would change the code (cpp.l's gnuattrs 'no) refuses where it
   ; is written: each item at the group's top depth is read by its first word. -> a gripe | ()
   (attrbad toks spans)
    (: ; inside __attribute__((, at depth d of parens; w: the next word names an item (the
       ; group's opening or a `,` at its depth), so an argument never passes for one
       (item l i d w)
        (? (atom? l) ()
           (<l @ t
              (? (tp? t "(") (item >l (i + 1) (d + 1) ())
                 (tp? t ")") (d = 2 ? (scan >>l (i + 2)) (item >l (i + 1) (d - 1) ()))
                 (d = 2 && tp? t ",") (item >l (i + 1) d 1)
                 (w && elem (tkk t) '(id kw))
                  (: nm (tkk t = 'kw ? show (tkv t) (tkv t))
                     (attrdoes nm = 'no ?
                        (gripe (filat spans i) (<>>t) () ("__attribute__((" + attrname nm + ")) is not carried out"))
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
