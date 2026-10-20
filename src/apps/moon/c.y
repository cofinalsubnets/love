/* src/apps/moon/c.y -- C's expressions, through our yacc to cgram.l. parse.l's pexpr, pasn and
   pcond answer through cx-parse; a type-name, a statement expression and the builtins that
   take types are parse.l's own, said to this grammar as one token each */
%{
   ; the binary operators' node symbols
   cx-ops (foldl (t \ p \ pin t <p <>p) {}
                 '(("*" *) ("/" /) ("%" %) ("+" +) ("-" -) ("<<" shl) (">>" shr) ("<" lt) ("<=" le)
                   (">" gt) (">=" ge) ("==" eq) ("!=" ne) ("&" &) ("^" ^) ("|" |)))
   ; -- the actions' helpers, parse.l's ladder arms as they stand --
   (cx-bad ps) (pin ps 'cxbad 1, ())
   (cx-bin ps t l r) (mkbin ps (cx-ops (tkv t)) l r)
   (cx-asn ps t lv r)
    (: op <>(assoc (tkv t) asnops)
       greg (two? lv && <lv = 'var && two? (peep (ps 'gregs) <>lv ()))
       (? greg (cx-bad ps)
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
   (cx-szn ps n) (charm? n ? ['cast (szty ps) ['num n]] (cx-bad ps))
   (cx-szty ps ty) (varr? ty ? ['bin '* <>>ty ['num (tsz ps <>ty)]] (cx-szn ps (tsz ps ty)))
   (cx-szof ps e) (ptype ps e @ ty (!ty || varr? ty ? ['szof e] (cx-szn ps (tsz ps ty))))
   (cx-alty ps ty) (cx-szn ps (talign ps ty))
   (cx-alof ps t e)
    (tkv t != "__alignof__" ? (cx-bad ps)
       (ptype ps e @ ty (ty ? (cx-szn ps (talign ps ty)) (cx-bad ps))))
   (cx-addr ps e) (nulloff ps e @ n (charm? n ? ['num n] ['addr e]))
   (cx-pos ps e) (ptype ps e @ ty (ty && pprom ty != ty ? ['cast (pprom ty) e] e))
   (cx-call ps e as) (bicall e (tuargs ps e as))
   (cx-id ps t)
    (: nm (tkv t)
       (? (elem nm '("__func__" "__FUNCTION__" "__PRETTY_FUNCTION__") && string? (ps 'fnname)) ['str (ps 'fnname)]
          (: ev (peep (ps 'declaring) nm () ? () (peep (ps 'enums) nm ()))
             (cint? ev ? ['num ev] ['var nm]))))
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
%}
%token XEXPR XASN XCOND
%token ID NUM STR WSTR PRIM TYPEP STYPEP CLIT SIZEOF ALIGNOF EXT ASNOP
%token OROR ANDAND EQEQ NE LE GE SHL SHR ARROW INC DEC
%param ps
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
top : XEXPR expr { $2 } | XASN asn { $2 } | XCOND cond { $2 } ;
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
   | ALIGNOF un { (cx-alof ps $1 $2) }
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
   cx-ks (foldl (t \ p \ pin t <p (cx-k <>p)) {}
                '((num "NUM") (unum "NUM") (lnum "NUM") (ulnum "NUM") (llnum "NUM")
                  (ullnum "NUM") (flo "NUM") (flof "NUM") (iflo "NUM")
                  (str "STR") (wstr "WSTR") (str16 "WSTR") (str32 "WSTR")))
   cx-ps (foldl (t \ p \ pin t <p (cx-k <>p)) {}
                [["(" "'('"] [")" "')'"] ["[" "'['"] ["]" "']'"] ["." "'.'"] ["->" "ARROW"]
                 ["++" "INC"] ["--" "DEC"] ["&" "'&'"] ["*" "'*'"] ["+" "'+'"] ["-" "'-'"]
                 ["~" "'~'"] ["!" "'!'"] ["/" "'/'"] ["%" "'%'"] ["<<" "SHL"] [">>" "SHR"]
                 ["<" "'<'"] [">" "'>'"] ["<=" "LE"] [">=" "GE"] ["==" "EQEQ"] ["!=" "NE"]
                 ["^" "'^'"] ["|" "'|'"] ["&&" "ANDAND"] ["||" "OROR"] ["?" "'?'"] [":" "':'"]
                 ["," "','"] ["=" "ASNOP"] ["+=" "ASNOP"] ["-=" "ASNOP"] ["*=" "ASNOP"]
                 ["/=" "ASNOP"] ["%=" "ASNOP"] ["&=" "ASNOP"] ["|=" "ASNOP"] ["^=" "ASNOP"]
                 ["<<=" "ASNOP"] [">>=" "ASNOP"]])
   ; the names pprim reads itself: the builtins over types, and those its bib? gate admits
   cx-prims (foldl (t \ s \ pin t s 1) {}
                   (["_Generic" "__builtin_va_arg" "__builtin_va_start" "__builtin_va_end" "__builtin_va_copy"] +
                    filter bib? (libbin + ["__builtin_strcmp" "__builtin_offsetof" "__builtin_types_compatible_p"
                                           "__builtin_constant_p" "__builtin_object_size" "__builtin_dynamic_object_size"
                                           "__builtin_assume_aligned" "__builtin_extract_return_addr" "__builtin_parity"
                                           "__builtin_parityl" "__builtin_parityll" "__builtin_choose_expr"])))
   cx-kid (cx-k "ID") cx-kprim (cx-k "PRIM") cx-ktyp (cx-k "TYPEP") cx-kstyp (cx-k "STYPEP")
   cx-kclit (cx-k "CLIT") cx-ksz (cx-k "SIZEOF") cx-kal (cx-k "ALIGNOF") cx-kext (cx-k "EXT")
   cx-klp (cx-k "'('") cx-krp (cx-k "')'") cx-klb (cx-k "'['") cx-krb (cx-k "']'")
   cx-kdot (cx-k "'.'") cx-karr (cx-k "ARROW") cx-kinc (cx-k "INC") cx-kdec (cx-k "DEC")
   cx-kcom (cx-k "','") cx-kq (cx-k "'?'") cx-kcol (cx-k "':'")
   cx-sels {'expr (cx-k "XEXPR") 'asn (cx-k "XASN") 'cond (cx-k "XCOND")}
   cx-run (cite 'lr 'run)
   ; a rule of one symbol and no action leaves the values as they stand: 1, else 0
   cx-unit (: R (cx-tab 6 + 256 * cx-tab 7)
              (string (map (r \ (: o (12 + 2 * R + 2 * r)
                                    (cx-tab o + 256 * cx-tab (o + 1) = 1 && !(peep cx-tab-acts r ()) ? 1 0))) ^R)))
   cx-c0 (string [0 0 0 0 1 0 0 0 0 0])
   ; one segment of kinds from ts, to an end, a token parse.l reads itself, or a chunk's
   ; worth. m is (sel op depth q pk): op when the last token ends an operand, q the open ?s
   ; at depth 0, pk the last kind. -> (kinds vals stop m), each reversed; vals a token's tail
   ; or ('cxv value rest) for a said one; stop ('end) | ('esc kind tail) | ('more tail), the
   ; last kind 0xffff then, said when the parse reaches it
   (cx-map ps ts m ks vs n)
    (: sel <m
       (go l ks vs n op d q pk)
        (: (fin st) [ks vs st [sel op d q pk]]
           (one k op2 d2 q2) (go >l (k . ks) (l . vs) (n + 1) op2 d2 q2 k)
           (stop st) [(65535 . ks) (l . vs) st [sel op d q pk]]
           (? (atom? l) (fin ['end])
              (400 < n) (stop ['more l])
              (: t <l tk (tkk t) v (tkv t)
                 (? (tk = 'p)
                     (peep cx-ps v () @ k
                        (? !k (fin ['end])
                           (k = cx-klp)
                            (? op (one k 0 (d + 1) q)
                               (peekp >l "{") (stop ['esc cx-kprim l])
                               (tyat? ps >l) (stop ['esc (pk = cx-ksz || pk = cx-kal ? cx-kstyp cx-ktyp) l])
                               (one k 0 (d + 1) q))
                           (k = cx-klb) (one k 0 (d + 1) q)
                           (k = cx-krp || k = cx-krb) (d = 0 ? (fin ['end]) (one k 1 (d - 1) q))
                           (k = cx-kinc || k = cx-kdec) (one k op d q)
                           (d != 0) (one k 0 d q)
                           (k = cx-kcom) (q = 0 && sel != 'expr ? (fin ['end]) (one k 0 d q))
                           (k = cx-kq) (one k 0 d (q + 1))
                           (k = cx-kcol) (q = 0 ? (fin ['end]) (one k 0 d (q - 1)))
                           (one k 0 d q)))
                    (tk = 'id)
                     (? (pk = cx-kdot || pk = cx-karr) (one cx-kid 1 d q)
                        (peep cx-prims v ()) (stop ['esc cx-kprim l])
                        (v = "_Alignof" || v = "__alignof__") (one cx-kal 0 d q)
                        (v = "__extension__") (one cx-kext 0 d q)
                        (one cx-kid 1 d q))
                    (tk = 'kw) (v = 'sizeof ? (one cx-ksz 0 d q) (fin ['end]))
                    (peep cx-ks tk () @ k (k ? (one k 1 d q) (fin ['end])))))))
       (go ts ks vs n (m 1) (m 2) (m 3) (m 4)))
   ; a said token: (kind value rest) | ()
   (cx-esc ps k ts)
    (? (k = cx-kprim) (pprim ps ts @ r (two? r ? [k <r <>r]))
       (thenw (pcty ps >ts) ")" @ tr
          (? (atom? tr) ()
             (k = cx-kstyp) [k <tr <>tr]
             (peekp <>tr "{") (pinit ps <>tr @ iv (two? iv ? [cx-kclit ['clit (fillarr ps <tr <iv) <iv] <>iv]))
             [k <tr <>tr])))
   ; kinds, last first -> their u16s in order
   (cx-u16s ks) (: (go l acc) (atom? l ? acc (go >l (<l & 255 . <l >> 8 . acc))) (string (go ks ())))
   (cx-u32 s o) (s o + 256 * s (o + 1) + 65536 * s (o + 2) + 16777216 * s (o + 3))
   (cx-val e) (<e = 'cxv ? <>e <e)
   (cx-rest e) (<e = 'cxv ? <>>e >e)
   ; -> (value rest) | (): sel 'expr, 'asn or 'cond. a token stamped for a refusal's re-parse,
   ; and a parse this grammar refuses, go to parse.l's ladder, which marks and blames
   (cx-parse ps ts sel)
    (? (two? ts && charm? (seqof <ts)) (cx-rd ps ts sel)
       (: b0 (peep ps 'cxbad 0) _ (pin ps 'cxbad 0)
          r (cx-go ps ts sel)
          bad (ps 'cxbad)
          _ (pin ps 'cxbad b0)
          (two? r && !bad ? r (cx-rd ps ts sel))))
   (cx-rd ps ts sel) (sel @ 'expr (rpexpr ps ts) 'asn (rpasn ps ts) (rpcond ps ts))
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
                       (play c (o + 6) (k - 1) vl2 p ((peep cx-tab-acts r () @ f (f ? (f ps args) <args)) . st3)))))))
       ; sg: (kinds vals stop m start), kinds and vals in order; ks the kinds' string
       (go c look ks sg vl i st)
        (cx-run cx-tab ks c look @ c2
           (? !(string? c2) ()
              (: o (8 + 2 * cx-u32 c2 4) z (c2 o) pos (cx-u32 c2 0)
                 (play c2 (o + 5) (cx-u32 c2 (o + 1)) vl i st @ [vl2 i2 st2]
                    (? (z = 0) (go c2 65535 ks sg vl2 i2 st2)
                       (z = 1) [<st2 (pos = 0 ? (sg 4) (cx-rest ((sg 1) (pos - 1))))]
                       (z = 2) (pos * 2 < #ks ? (go c2 65535 (snip ks 0 (2 * pos)) sg vl2 i2 st2))
                       (: st3 <>(feed vl2 i2 pos st2)
                          stop (sg 2) m (sg 3)
                          c3 ((string [0 0 0 0]) + snip c2 4 (8 + 2 * cx-u32 c2 4))
                          (? (<stop = 'more) (next c3 () () 0 <>stop m st3)
                             (cx-esc ps <>stop <>>stop @ e
                                (? (atom? e) ()
                                   (: k <e op (k = cx-kprim || k = cx-kclit ? 1 0)
                                      (next c3 [k] [['cxv <>e <>>e]] 1 <>>e [<m op (m 2) (m 3) k] st3)))))))))))
       (next c ks vs n l m st)
        (cx-map ps l m ks vs n @ s
           (: sg [(rev <s) (rev <>s) <>>s <>>>s l]
              (go c 65535 (cx-u16s <s) sg <>sg 0 st)))
       (next cx-c0 [(cx-sels sel)] [['cxv () ts]] 1 ts [sel 0 0 0 -1] ()))
   _ (pin cx-door 'parse cx-parse)
