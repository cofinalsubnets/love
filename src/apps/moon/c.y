/* src/apps/moon/c.y -- C's expressions and statements, through our yacc to cgram.l. parse.l's
   pexpr, pasn, pcond and pblock answer through cx-parse; a type-name, a statement expression,
   the builtins that take types, a block's declarations and the statements led by asm, an
   attribute or a for's declaration are parse.l's own, said to this grammar as one token each */
%{
   ; the binary operators' node symbols
   cx-ops (foldl (t \ p \ pin t <p <>p) {}
                 '(("*" *) ("/" /) ("%" %) ("+" +) ("-" -) ("<<" shl) (">>" shr) ("<" lt) ("<=" le)
                   (">" gt) (">=" ge) ("==" eq) ("!=" ne) ("&" &) ("^" ^) ("|" |)))
   ; -- the actions' helpers --
   ; a refusal: its sentence and the token it names, () for the lookahead; 0 stops the parse
   (cx-no ps msg t) (pin ps 'cxwhy [msg t], 0)
   (cx-bad ps) (cx-no ps () ())
   (cx-bin ps t l r) (mkbin ps (cx-ops (tkv t)) l r)
   (cx-asn ps t lv r)
    (: op <>(assoc (tkv t) asnops)
       greg (two? lv && <lv = 'var && two? (peep (ps 'gregs) <>lv ()))
       (? greg (cx-no ps "a write to a global register variable" ())
          !op ['asn lv r]
          (calm? lv) ['asn lv (mkbin ps op lv r)]
          ['rmw op lv r]))
   (cx-elvis ps a b) (pelvis ps a b @ e (two? e ? e (cx-bad ps)))
   (cx-cast ps cty e)
    (ptype ps e @ sty
       (? (cplxty? cty)
           (? (cplxty? sty && <>sty = <>cty) e
              (cplxty? sty) ['clit cty ['init [['dot e "re"] ['dot e "im"]]]]
              ['clit cty ['init [e '(flo 0.0)]]])
          (cplxty? sty && !(stru? cty)) ['cast cty ['dot e "re"]]
          ['cast cty e]))
   (cx-szn ps n w) (charm? n ? ['cast (szty ps) ['num n]] (cx-no ps "\(w) an incomplete type" ()))
   (cx-szty ps ty) (varr? ty ? ['bin '* <>>ty ['num (tsz ps <>ty)]] (cx-szn ps (tsz ps ty) "sizeof"))
   (cx-szof ps e) (ptype ps e @ ty (!ty || varr? ty ? ['szof e] (cx-szn ps (tsz ps ty) "sizeof")))
   (cx-alty ps ty) (cx-szn ps (talign ps ty) "alignof")
   (cx-alof ps e) (ptype ps e @ ty (ty ? (cx-szn ps (talign ps ty) "alignof") (cx-bad ps)))
   (cx-addr ps e) (nulloff ps e @ n (charm? n ? ['num n] ['addr e]))
   (cx-pos ps e) (ptype ps e @ ty (ty && pprom ty != ty ? ['cast (pprom ty) e] e))
   (cx-call ps e as) (bicall e (tuargs ps e as))
   (cx-id ps t)
    (: nm (tkv t)
       (? (elem nm '("__func__" "__FUNCTION__" "__PRETTY_FUNCTION__") && string? (ps 'fnname)) ['str (ps 'fnname)]
          (: ev (peep (ps 'declaring) nm () ? () (peep (ps 'enums) nm ()))
             (cint? ev ? (enumnum ps ev) ['var nm]))))
   (cx-num ps t)
    (: k (tkk t) v (tkv t)
       (? (k = 'num && pchar ps = 'char && chq? t && 127 < v && v < 256) ['num (v - 256)]
          (k = 'num) (pst32? ps && 2147483647 < v ? ['cast 'llong ['num v]] ['num v])
          (k = 'unum) ['cast 'uint ['num v]]
          (k = 'ulnum) ['cast (pst32? ps && (v < 0 || 4294967295 < v) ? 'ullong 'ulong) ['num v]]
          (k = 'ullnum) ['cast (pst32? ps ? 'ullong 'ulong) ['num v]]
          (k = 'llnum) ['cast (pst32? ps ? 'llong 'long) ['num v]]
          (k = 'lnum)
           (: sp (t 4)
              dec !(sp 0 = 48 && 1 < #sp && !(elem (sp 1) '(108 76 117 85)))
              ty (? !(pst32? ps && 2147483647 < v) 'long
                    (!dec && v <= 4294967295) 'ulong
                    'llong)
              ['cast ty ['num v]])
          (k = 'flo) ['flo (cflo v)]
          (k = 'flof) ['cast 'float ['flo (cflo32 v)]]
          ['clit '(struct "__cplx_double") ['init ['(flo 0.0) ['flo (cflo v)]]]]))
   (cx-wstr ps t)
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
       ['clit ['arr ety (#cps + 1)] ['init (nums cps)]])
   ; -- the statements' --
   ; a block's frame, innermost first on ps 'cxfr: the scoped run it drains from, the depth to
   ; restore and its shadow list
   (cx-benter ps)
    (: d0 (peep ps 'blkd 0)
       (pin ps 'cxfr ({'epre (ps 'scopacc) 'd0 d0 'sh ()} . peep ps 'cxfr ()),
        pin ps 'blkd (d0 + 1),
        ()))
   (cx-bclose ps f) (pin ps 'blkd (f 'd0), unshadow ps (f 'sh))
   ; the last expression typed while the block's names stand (a sexpr's value), then its scope off
   (cx-bend ps acc)
    (: f <(ps 'cxfr) lv (two? acc ? <acc)
       (pin ps 'blkval (two? lv && <lv = 'expr ? (ptype ps <>lv)),
        cx-bclose ps f,
        pin ps 'cxfr >(ps 'cxfr),
        ['blk (rev acc)]))
   (cx-app l acc) (atom? l ? acc (cx-app >l (<l . acc)))
   (cx-it ps s) (clpop ps @ cm (cm ? [s cm] [s]))       ; a cleanup's marker rides after
   (cx-ret ps e t) (intptr? ps e ? (cx-no ps "an integer where a pointer is owed" t) ['ret e])
   ; if (__builtin_expect(e, k)): the test is e, and a (nop cold|hot) heads the then-arm
   (cx-if ps rc th el)
    (: xa (rc @ ('call ('var "__builtin_expect") (e ('num k)) && elem k '(0 1)) [e k] ())
       c9 (? (atom? xa) rc
             (elem (ptype ps <xa) '(float double ldouble)) ['cast 'long <xa]
             <xa)
       (arm s) (atom? xa ? s
                  (['nop (<>xa = 0 ? 'cold 'hot)] @ m
                     (s @ ('blk items) ['blk (m . items)] ['blk [m s]])))
       ['if c9 (arm th) el])
   (cx-lbl ps t c)
    (lname ps (tkv t) @ nm
       (peep (ps 'labs) nm () ? (cx-no ps "duplicate label '\(nm)'" c)
          (pin (ps 'labs) nm 1, pin ps 'cxlab (nm . peep ps 'cxlab ()), ['lbl nm])))
   ; `case A ... B:` lays a label per value when narrow, else ('case A B)
   (cx-case ps e h c)
    (: v (cfold (pw64 ps) e)
       hi (two? h ? (cfold (pw64 ps) h))
       (crange lo hi acc) (hi < lo ? (rev acc) (crange (lo + 1) hi (['case lo] . acc)))
       (? !(cint? v) (cx-no ps () c)
          (atom? h) ['case v]
          !(cint? hi) (cx-no ps () c)
          (hi < v) (cx-no ps "an empty case range" c)
          (16 < hi - v) ['case v hi]
          ['blk (crange v hi ())]))
   (cx-arm ms s) ['blk (rev (s . ms))]                  ; an arm's labels, then its statement
%}
%token XEXPR XASN XCOND XBLOCK
%token IF ELSE WHILE DO FOR SWITCH GOTO BREAK CONTINUE CASE DEFAULT RETURN ELLIP DECL STMT MARK
%token ID NUM STR WSTR PRIM TYPEP STYPEP CLIT SIZEOF ALIGNOF ALIGNTY EXT ASNOP
%token OROR ANDAND EQEQ NE LE GE SHL SHR ARROW INC DEC
%param ps
%nonassoc LOWELSE
%nonassoc ELSE
%left OROR
%left ANDAND
%left '|'
%left '^'
%left '&'
%left EQEQ NE
%left '<' '>' LE GE
%left SHL SHR
%left '+' '-'
%left '*' '/' '%'
%%
top : XEXPR expr { $2 } | XASN asn { $2 } | XCOND cond { $2 } | XBLOCK block { $2 } ;
block : lb items '}' { (cx-bend ps $2) } ;
lb : '{' { (cx-benter ps) } ;
items : { () } | items item { (cx-app $2 $1) } ;
item : DECL | stmt { (cx-it ps $1) } | mark { (cx-it ps $1) } ;
stmt : block | sstmt ;
sstmt : ';' { ['nop] }
      | expr ';' { ['expr $1] }
      | RETURN ';' { ['ret ()] }
      | RETURN expr ';' { (cx-ret ps $2 $3) }
      | IF '(' expr ')' arm %prec LOWELSE { (cx-if ps $3 $5 ()) }
      | IF '(' expr ')' arm ELSE arm { (cx-if ps $3 $5 $7) }
      | WHILE '(' expr ')' arm { ['while $3 $5] }
      | DO arm WHILE '(' expr ')' ';' { ['do $2 $5] }
      | FOR '(' fopt ';' fopt ';' fopt ')' arm { ['for (two? $3 ? ['expr $3]) $5 $7 $9] }
      | SWITCH '(' expr ')' block { ['switch $3 <>$5] }
      | SWITCH '(' expr ')' sarm { ['switch $3 [$5]] }
      | GOTO ID ';' { ['goto (lname ps (tkv $2))] }
      | GOTO '*' expr ';' { ['igoto $3] }
      | BREAK ';' { ['brk] }
      | CONTINUE ';' { ['cont] }
      | STMT ;
fopt : { () } | expr ;
mark : ID ':' { (cx-lbl ps $1 $2) }
     | CASE expr ':' { (cx-case ps $2 () $3) }
     | CASE expr ELLIP expr ':' { (cx-case ps $2 $4 $5) }
     | DEFAULT ':' { ['dflt] }
     | MARK ;
marks : mark { [$1] } | marks mark { ($2 . $1) } ;
arm : stmt | marks stmt { (cx-arm $1 $2) } ;
sarm : sstmt | marks stmt { (cx-arm $1 $2) } ;
expr : asn | expr ',' asn { ['comma $1 $3] } ;
asn : cond | cond ASNOP asn { (cx-asn ps $2 $1 $3) } ;
cond : bin
     | bin '?' expr ':' cond { ['cond $1 $3 $5] }
     | bin '?' ':' cond { (cx-elvis ps $1 $4) } ;
bin : un
    | bin OROR bin { ['lor $1 $3] }
    | bin ANDAND bin { ['land $1 $3] }
    | bin '|' bin { (cx-bin ps $2 $1 $3) }
    | bin '^' bin { (cx-bin ps $2 $1 $3) }
    | bin '&' bin { (cx-bin ps $2 $1 $3) }
    | bin EQEQ bin { (cx-bin ps $2 $1 $3) }
    | bin NE bin { (cx-bin ps $2 $1 $3) }
    | bin '<' bin { (cx-bin ps $2 $1 $3) }
    | bin '>' bin { (cx-bin ps $2 $1 $3) }
    | bin LE bin { (cx-bin ps $2 $1 $3) }
    | bin GE bin { (cx-bin ps $2 $1 $3) }
    | bin SHL bin { (cx-bin ps $2 $1 $3) }
    | bin SHR bin { (cx-bin ps $2 $1 $3) }
    | bin '+' bin { (cx-bin ps $2 $1 $3) }
    | bin '-' bin { (cx-bin ps $2 $1 $3) }
    | bin '*' bin { (cx-bin ps $2 $1 $3) }
    | bin '/' bin { (cx-bin ps $2 $1 $3) }
    | bin '%' bin { (cx-bin ps $2 $1 $3) } ;
un : post
   | TYPEP un { (cx-cast ps $1 $2) }
   | SIZEOF un { (cx-szof ps $2) }
   | SIZEOF STYPEP { (cx-szty ps $2) }
   | ALIGNOF STYPEP { (cx-alty ps $2) }
   | ALIGNTY STYPEP { (cx-alty ps $2) }
   | ALIGNOF un { (cx-alof ps $2) }
   | EXT un { $2 }
   | '*' un { ['deref $2] }
   | ANDAND ID { ['laddr (lname ps (tkv $2))] }
   | '&' un { (cx-addr ps $2) }
   | '+' un { (cx-pos ps $2) }
   | '-' un { ['un 'neg $2] }
   | '!' un { ['un 'not $2] }
   | '~' un { ['un 'bnot $2] }
   | INC un { (preop $2 1) }
   | DEC un { (preop $2 -1) } ;
post : prim
     | CLIT
     | post '(' ')' { (cx-call ps $1 ()) }
     | post '(' args ')' { (cx-call ps $1 (rev $3)) }
     | post '[' expr ']' { ['deref ['bin '+ $1 $3]] }
     | post '.' ID { ['dot $1 (tkv $3)] }
     | post ARROW ID { ['dot ['deref $1] (tkv $3)] }
     | post INC { ['post $1 1] }
     | post DEC { ['post $1 -1] } ;
args : asn { [$1] } | args ',' asn { ($3 . $1) } ;
prim : ID { (cx-id ps $1) }
     | NUM { (cx-num ps $1) }
     | STR { ['str (tkv $1)] }
     | WSTR { (cx-wstr ps $1) }
     | PRIM
     | '(' expr ')' { $2 } ;
%%
   ; -- the kinds: mooncc's tokens said in this grammar's terminals --
   (cx-k nm) (: (go l i) (? (atom? l) (scare 'cx-k nm) (<l = nm) i (go >l (i + 1))) (go cx-tab-terms 0))
   ; the mapper's word for a token, by a punctuator's text, a name, a keyword's symbol or a
   ; literal's kind: its kind * 64 + a class. classes: 0 an operator, 1 (, 2 [, 3 ), 4 ], 5 ++ --,
   ; 6 a comma, 7 ?, 8 :, 9 . ->, 10 {, 11 }, 12 ;, 13 a statement head, 14 goto, 15 sizeof
   ; alignof, 16 a block's other, 17 pprim's, 18 __extension__, 19 a statement parse.l reads, 20
   ; __label__, 21 a literal, 24 a type's or its qualifier's word, and to say 22 a cast's type,
   ; 23 sizeof's. 10 and up are a block's, but 15 17 18 21 24
   (cx-w p) (cx-k <>p * 64 + p 2)
   (cx-pins t l) (foldl (t \ p \ pin t <p (cx-w p)) t l)
   cx-tw (cx-pins {}
            ([["(" "'('" 1] [")" "')'" 3] ["[" "'['" 2] ["]" "']'" 4] ["." "'.'" 9] ["->" "ARROW" 9] ["=" "ASNOP" 0]
              ["++" "INC" 5] ["--" "DEC" 5] ["?" "'?'" 7] [":" "':'" 8] ["," "','" 6]
              ["{" "'{'" 10] ["}" "'}'" 11] [";" "';'" 12] ["..." "ELLIP" 16]] +
             map (o \ [o (#o = 1 ? "'\(o)'" (assoc o '(("<<" "SHL") (">>" "SHR") ("<=" "LE") (">=" "GE") ("==" "EQEQ")
                                                        ("!=" "NE") ("&&" "ANDAND") ("||" "OROR")) @ (_ n) n "ASNOP")) 0])
                 ["&" "*" "+" "-" "~" "!" "/" "%" "<" ">" "^" "|" "<<" ">>" "<=" ">=" "==" "!=" "&&" "||"
                  "+=" "-=" "*=" "/=" "%=" "&=" "|=" "^=" "<<=" ">>="] +
             map (k \ [k "NUM" 21]) '(num unum lnum ulnum llnum ullnum flo flof iflo) +
             '((str "STR" 21) (wstr "WSTR" 21) (str16 "WSTR" 21) (str32 "WSTR" 21)) +
             '((sizeof "SIZEOF" 15) (if "IF" 13) (else "ELSE" 16) (while "WHILE" 13) (do "DO" 16)
               (for "FOR" 13) (switch "SWITCH" 13) (goto "GOTO" 14) (break "BREAK" 16)
               (continue "CONTINUE" 16) (case "CASE" 16) (default "DEFAULT" 16) (return "RETURN" 16)) +
             ; pprim's names (the builtins over types, and those its bib? gate admits), alignof,
             ; __extension__, and a block's statements led by an attribute, an assertion or asm
             map (s \ [s "PRIM" 17])
                 (["_Generic" "__builtin_va_arg" "__builtin_va_start" "__builtin_va_end" "__builtin_va_copy"] +
                  filter bib? (libbin + ["__builtin_strcmp" "__builtin_offsetof" "__builtin_types_compatible_p"
                                         "__builtin_constant_p" "__builtin_object_size" "__builtin_dynamic_object_size"
                                         "__builtin_assume_aligned" "__builtin_extract_return_addr" "__builtin_parity"
                                         "__builtin_parityl" "__builtin_parityll" "__builtin_choose_expr"])) +
             ; _Alignof takes a type-name alone; gcc's __alignof__ an expression too
             [["_Alignof" "ALIGNTY" 15] ["__alignof__" "ALIGNOF" 15] ["__extension__" "EXT" 18]
              ["__attribute__" "STMT" 19] ["_Static_assert" "STMT" 19] ["asm" "STMT" 19]
              ["__asm__" "STMT" 19] ["__asm" "STMT" 19] ["__label__" "DECL" 20]] +
             ; the words a type may begin with, past its qualifiers: the rest are typedef names
             map (w \ [w "ID" 24]) (tyspec + '(struct union enum) + qualkw +
                                    filter (s \ !(elem s ["__attribute__" "__extension__"])) qualid +
                                    tyofid + [autoid])))
   cx-kid (cx-k "ID") cx-kprim (cx-k "PRIM") cx-ktyp (cx-k "TYPEP") cx-kstyp (cx-k "STYPEP")
   cx-kclit (cx-k "CLIT") cx-kdecl (cx-k "DECL") cx-kstmt (cx-k "STMT") cx-kmark (cx-k "MARK")
   cx-sels {'expr (cx-k "XEXPR") 'asn (cx-k "XASN") 'cond (cx-k "XCOND") 'blk (cx-k "XBLOCK")}
   cx-run (cite 'lr 'run)
   ; a rule of one symbol and no action leaves the values as they stand: 1, else 0
   cx-unit (: R (cx-tab 6 + 256 * cx-tab 7)
              (string (map (r \ (: o (12 + 2 * R + 2 * r)
                                    (cx-tab o + 256 * cx-tab (o + 1) = 1 && !(peep cx-tab-acts r ()) ? 1 0))) ^R)))
   cx-c0 (string [0 0 0 0 1 0 0 0 0 0])
   ; may a type begin at x, now or once a block's shadows come off? a name ty holds at all; the
   ; escape asks parse.l's tyat? again
   (cx-mt? ty x)
    (two? x && (: t <x tw (<t = 'id || <t = 'kw ? <>t ()) cw ((peep cx-tw tw 0) % 64)
                  (cw = 24 || cw = 19 || (<t = 'id && !(peep ty tw 'none = 'none)))))
   (cx-seg ks vs st sel op d q pc ss bd hd) [ks vs st [sel op d q pc ss bd hd]]
   ; one segment of kinds from ts, to an end, a token parse.l reads itself, or a chunk's
   ; worth. m is (sel op depth q pc ss bd hd): op when the last token ends an operand, q the
   ; open ?s at depth 0, pc the last class, ss at a block's item, bd the braces open, hd the
   ; depths of the statement heads' open parens. nx reads the first token as no escape.
   ; -> (kinds vals stop m), each reversed; vals a token's tail or ('cxv value rest) for a said
   ; one; stop ('end) | ('esc class tail) | ('more tail), the last kind 0xffff then, said when
   ; the parse reaches it. a said type or declaration is asked again then: a block's end may
   ; have taken a shadow off since
   (cx-map ps ts m ks vs n nx)
    (: sel <m blk (sel = 'blk) ex (sel = 'expr) ty (ps 'types)
       ; the loop's tests are sums and products of 0s and 1s: an && or || would take a slot
       (go l ks vs n op d q pc ss bd hd nx)
        (? (atom? l) (cx-seg ks vs ['end] sel op d q pc ss bd hd)
           (400 < n) (cx-seg (65535 . ks) (l . vs) ['more l] sel op d q pc ss bd hd)
           (: tk <<l v <><l
              id (tk = 'id) kw (tk = 'kw)
              w (peep cx-tw (id + kw + (tk = 'p) ? v tk) 0)
              k (w // 64) c (w % 64)
              mem ((pc = 9) + (pc = 14))                 ; a member's name or a label's
              ; what the token does: a class to say it by, -1 to end before it, -2 to end past
              ; it, -3 to skip it, else 0 to lay it
              x (? id (? mem 0
                         (blk * ss * (nx = 0) * (c != 19) ? (cx-mt? ty l)) 20
                         (c = 17) 17
                         (blk * ss * (c = 18)) -3
                         (blk = 0) 0
                         (c = 19) 19
                         (ss * (nx = 0) * (c = 20)) 20
                         0)
                   kw (? (c = 15) 0
                         (blk = 0) -1
                         (ss * (nx = 0) * ((v = 'typedef) + (c = 24))) 20
                         ((w = 0) + (c = 24)) -1
                         (v = 'for ? (cx-mt? ty >>l)) 19
                         0)
                   ((w = 0) + (blk = 0) * (9 < c) * (c != 21)) -1
                   ((c = 1) * (pc != 13) * (op = 0) * (nx = 0))
                    (? (two? >l ? (<<>l = 'p ? (<><>l = "{"))) 17
                       (cx-mt? ty >l) (pc = 15 ? 23 22)
                       0)
                   (((c = 3) + (c = 4)) * (d = 0) * (blk = 0)) -1
                   ((c = 11) * (bd < 2)) -2
                   ((d = 0) * ((c = 6) * (ex = 0) + (c = 8)) * (q = 0) * (blk = 0)) -1
                   0)
              cl ((c = 3) + (c = 4))
              hc ((c = 3) * (0 < d) ? (two? hd ? (<hd = d - 1)))   ; a head's closing paren
              (? (x = -1) (cx-seg ks vs ['end] sel op d q pc ss bd hd)
                 (x = -2) (cx-seg (k . ks) (l . vs) ['end] sel op d q pc ss bd hd)
                 (x = -3) (go >l ks vs n op d q pc ss bd hd 0)
                 (0 < x) (cx-seg (65535 . ks) (l . vs) ['esc x l] sel op d q pc ss bd hd)
                 (go >l ((? (id = 0) k mem cx-kid ((c = 15) + (c = 18)) k cx-kid) . ks) (l . vs) (n + 1)
                     (? id (mem + ((c = 15) + (c = 18) = 0))
                        (c = 21) 1
                        cl (hc = 0)
                        (c = 5) op
                        0)
                     (? ((c = 1) + (c = 2)) (d + 1)
                        (cl * (0 < d)) (d - 1)
                        d)
                     (? (0 < d) q
                        (c = 7) (q + 1)
                        ((c = 8) * (q != 0)) (q - 1)
                        q)
                     (? id (c = 15 ? 15 0) (c = 21) 0 c)
                     (? ((c = 10) + (c = 11)) 1
                        (c = 12) (d = 0)
                        ((c = 8) * (d = 0) * (q = 0)) 1
                        0)
                     (? (c = 10) (bd + 1) (c = 11) (bd - 1) bd)
                     (? ((c = 1) * (pc = 13)) (d . hd) hc >hd hd)
                     0))))
       (go ts ks vs n (m 1) (m 2) (m 3) (m 4) (m 5) (m 6) (m 7) nx))
   ; a block's declaration at ts, as parse.l's pblock takes one: its scope into the frame
   (cx-decl ps ts)
    (: f (peep ps 'cxfr ())
       (? (atom? f) ()
          (: fr <f epre (fr 'epre) sh (fr 'sh)
             (? (idv? <ts "__label__") (plabs ps >ts sh @ r (pin fr 'sh <>r, [cx-kdecl () <r]))
                (tkw? <ts 'typedef)
                 (: br (pbty ps >ts)
                    r (two? br ? (btdefs ps <br <>br (sdrain ps epre sh) (qspec ps >ts <br)))
                    (atom? r ? () (pin fr 'sh <>r, [cx-kdecl () <r])))
                !(tyat? ps ts) 'remap
                (: r (pdecl ps ts)
                   cm (clpop ps)
                   (atom? r ? ()
                      (pin fr 'sh (bindlocs ps (loctypes <r) (shadowdecl ps (declnames <r) (sdrain ps epre sh))),
                       [cx-kdecl (cm ? [<r cm] [<r]) <>r])))))))
   ; a said token, by its class: (kind value rest) | () | 'remap, the token no longer what it
   ; was said as
   (cx-esc ps c ts)
    (? (c = 17) (pprim ps ts @ r (two? r ? [cx-kprim <r <>r]))
       (c = 20) (cx-decl ps ts)
       (c = 19) (? (tyat? ps ts) (cx-decl ps ts)
                   (pstmt ps ts @ r (two? r ? [(markerp <r ? cx-kmark cx-kstmt) <r <>r])))
       !(tyat? ps >ts) 'remap
       (thenw (pcty ps >ts) ")" @ tr
          (? (atom? tr) ()
             (c = 23) [cx-kstyp <tr <>tr]
             (peekp <>tr "{") (pinit ps <>tr @ iv (two? iv ? [cx-kclit ['clit (fillarr ps <tr <iv) <iv] <>iv]))
             [cx-ktyp <tr <>tr])))
   ; kinds, last first -> their u16s in order
   (cx-u16s ks) (: (go l acc) (atom? l ? acc (go >l (<l & 255 . <l >> 8 . acc))) (string (go ks ())))
   (cx-u32 s o) (s o + 256 * s (o + 1) + 65536 * s (o + 2) + 16777216 * s (o + 3))
   (cx-val e) (<e = 'cxv ? <>e <e)
   (cx-rest e) (<e = 'cxv ? <>>e >e)
   ; a refused parse leaves the frames and labels it laid as it found them
   (cx-undo ps f0 l0)
    (: (fr l) (? (#l <= #f0) () (cx-bclose ps <l, pin ps 'scopacc (<l 'epre), fr >l))
       (lb l) (? (#l <= #l0) () (pull (ps 'labs) <l 0, lb >l))
       (fr (peep ps 'cxfr ()), pin ps 'cxfr f0, lb (peep ps 'cxlab ()), pin ps 'cxlab l0))
   ; -> (value rest) | (): sel 'expr, 'asn, 'cond or 'blk
   (cx-parse ps ts sel)
    (: f0 (peep ps 'cxfr ()) l0 (peep ps 'cxlab ())
       r (cx-go ps ts sel)
       (two? r ? r (cx-undo ps f0 l0, ())))
   ; a val's first token: a said one carries the tail it was said from
   (cx-vtok e) (<e = 'cxv ? <>>>e e)
   ; the token at kind i of a segment's vals, past the last one the token after it, or at the
   ; input's end the last
   (cx-at vs i)
    (? (atom? >vs) (? (i = 0) (cx-vtok <vs) (two? (cx-rest <vs)) (cx-rest <vs) (cx-vtok <vs))
       (i = 0) (cx-vtok <vs)
       (cx-at >vs (i - 1)))
   ; a refusal on a failing form's re-parse marks where it stood, as parse.l's lookaheads do,
   ; and an action's refusal files its sentence there
   (cx-fail ps sg pos)
    (: l (sg 4)
       ((two? l && stamped? <l ? (mark (atom? (sg 1) ? l (cx-at (sg 1) pos)))), ()))
   (cx-why ps vl sg)
    (: w (ps 'cxwhy) t (? (two? <>w) [<>w] (two? vl) (cx-vtok <vl) (two? (sg 1)) (cx-at (sg 1) #(sg 1)) (sg 4))
       ((<w ? (blame t <w) (mark t)), ()))
   (cx-go ps ts sel)
    (: R (cx-tab 6 + 256 * cx-tab 7)
       (rlen r) (: o (12 + 2 * R + 2 * r) (cx-tab o + 256 * cx-tab (o + 1)))
       (feed vl i p st) (? (i < p) (feed >vl (i + 1) p (cx-val <vl . st)) [vl st])
       (pop st n acc) (n ? (pop >st (n - 1) (<st . acc)) [st acc])
       (play c o k vl i st)
        (? (k = 0) [vl i st]
           (: r (c o + 256 * c (o + 1)) p (cx-u32 c (o + 2))
              (feed vl i p st @ [vl2 st2]
                 (cx-unit r = 1 ? (play c (o + 6) (k - 1) vl2 p st2)
                    (pop st2 (rlen r) () @ [st3 args]
                       ; an action answering a number refused: the lookahead rides out
                       (: v (peep cx-tab-acts r () @ f (f ? (f ps args) <args))
                          (charm? v ? [vl2 -1 st3] (play c (o + 6) (k - 1) vl2 p (v . st3)))))))))
       ; sg: (kinds vals stop m start), kinds and vals in order; ks the kinds' string
       (go c look ks sg vl i st)
        (cx-run cx-tab ks c look @ c2
           (? !(string? c2) ()
              (: o (8 + 2 * cx-u32 c2 4) z (c2 o) pos (cx-u32 c2 0)
                 (play c2 (o + 5) (cx-u32 c2 (o + 1)) vl i st @ [vl2 i2 st2]
                    (? (i2 < 0) (cx-why ps vl2 sg)
                       (z = 0) (go c2 65535 ks sg vl2 i2 st2)
                       ; the vals bound first: the glaze takes no ((f a) b)
                       (z = 1) [<st2 (pos = 0 ? (sg 4) (: vs (sg 1) (cx-rest (vs (pos - 1)))))]
                       (z = 2) (cx-fail ps sg pos, (sel != 'blk && pos * 2 < #ks ? (go c2 65535 (snip ks 0 (2 * pos)) sg vl2 i2 st2)))
                       (: st3 <>(feed vl2 i2 pos st2)
                          stop (sg 2) m (sg 3)
                          c3 ((string [0 0 0 0]) + snip c2 4 (8 + 2 * cx-u32 c2 4))
                          (? (<stop = 'more) (next c3 () () 0 <>stop m 0 st3)
                             (cx-esc ps <>stop <>>stop @ e
                                (? (e = 'remap) (next c3 () () 0 <>>stop m 1 st3)
                                   (atom? e) ()
                                   (: k <e op (k = cx-kprim || k = cx-kclit ? 1 0)
                                      ss (k = cx-kdecl || k = cx-kstmt || k = cx-kmark ? 1 0)
                                      (next c3 [k] [['cxv <>e <>>e <>>stop]] 1 <>>e [<m op (m 2) (m 3) 0 ss (m 6) (m 7)] 0 st3)))))))))))
       (next c ks vs n l m nx st)
        (cx-map ps l m ks vs n nx @ s
           (: sg [(rev <s) (rev <>s) <>>s <>>>s l]
              (go c 65535 (cx-u16s <s) sg <>sg 0 st)))
       (next cx-c0 [(cx-sels sel)] [['cxv () ts ts]] 1 ts [sel 0 0 0 -1 0 0 ()] 0 ()))
   _ (pin cx-door 'parse cx-parse)
