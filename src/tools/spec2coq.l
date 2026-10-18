; spec2coq: generate Coq from test/spec.l, the generated half beside test/proof/rocq/spec.v's
; hand-written laws. each (test ..) operand is opfix-factored and translated to a theorem
; closed by vm_compute, over models covering every exact, computable domain in the corpus:
;   * Z / list Z / assoc lists for value equalities: integer algebra, lists, strings, arrays,
;     hashes, list functions with their function arguments as Coq funs; predicates as 1|0
;   * the unit lane: () is the unit of + alone, absorbed by every other numeric op (option Z)
;   * text as spelling: strings are byte lists under + and *; a symbol never = a string
;   * a kind lattice for the type predicates and the band order symbol<string<number<chain<map
;   * gaussian twins over Z as (re,im): order and sign lex, truth and $ read the real part
;   * lambdas as de Bruijn terms: function = is alpha + structural, never eta/beta
;   * == on literals: interned noms and charms by value, fresh allocations never, () is not 0
; floats, transcendental complex and quantified laws are left to spec.v; untranslatable
; asserts are counted as UNMODELED, never silently dropped. Z not nat: (3 3 3) = 3^27.
;   out/love src/tools/spec2coq.l > test/proof/rocq/gen.v

(borrow 'posix)
(: join (foldl (+) "")                           ; join a list of strings
   ; the interning tables lead the chain: bound beside their readers, a capturing closure
   ; resolves them as a global import (";; missing vtab")
   vtab {} vc {}      ; lambda params in flight: nom -> coq var; vc the freshness counter
   ltab {} lc {}      ; free noms/operator heads -> lo index; lc the counter


   ; exactly three elements? (structural chainp, never `!`: '(0) nets zero)
   (len3? [_ _ _]) 1
   ; opfix wraps an operator form one layer ((f) == f); unwrap a 1-element list
   (unwrap r) (two? r && atom? >r ? <r r)
   (fix1 x) (unwrap (unglue (opfix x)))          ; unglue: this file matches words, not glued values

   ; an integer binary operator symbol -> its Coq function (prefix), else 0
   (binop h) (h @ '+ "Z.add"   '- "Z.sub"  '* "Z.mul"
                  '// "Z.quot" '% "Z.rem"  'gcd "Z.gcd"
                  '& "Z.land"  '| "Z.lor"  '^ "Z.lxor"  0)
   (shiftf h) (h @ '<< "shlz" '>> "shrz" 0)  ; shifts: no width, and a negative count reverses
   ; a word-lane operand: a charm, a nested bitwise tree of them, or a numeral
   ; spine that lands back in a charm
   (wz? o) (? (charm? o) 1
              (len3? o && elem <o '(& | ^)) (wz? <>o && wz? <>>o)
              (two? o && charm? <o && allv? o) (charm? (ev o))
              0)
   bs '\                                                ; the quote symbol \ (for '(..) z-list data)
   (zel? e) (charm? e || e = ())                      ; a charm element, or the unit (reads 0)
   (zlist? l) (two? l ? (zel? <l && zlist? >l) (l = ()))  ; proper list of them (ends in (), not any atom)
   ; a quoted list that may hold noms (each nets its spelling): the measure lanes only, since
   ; extraction or elementwise = would conflate a nom with its net
   (znlist? l) (two? l ? ((zel? <l || nom? <l) && znlist? >l) (l = ()))
   (qnlist? x) (two? x && <x = bs && un2? x && znlist? <>x)
   (qlist? x) (two? x && <x = bs && un2? x && zlist? <>x)  ; '(1 2 3) (a lambda is 3+)
   (arrv? x)  (two? x && <x = 'tuple && zlist? >x)      ; @(1 2 3) = (tuple 1 2 3): a z-array
   (iotav? x) (two? x && <x = 'iota && un2? x && intv? <>x)  ; (iota n): the z-array 0..n-1
   (un2? x) (two? >x && atom? >>x)                      ; a 2-element (op arg) form

   ; -- lambdas as Coq funs (single param, exact body), sections, escaped operators --
   (lamform? x) (two? x && <x = bs && two? >x && two? >>x)  ; (\ p .. b): 3+ elements (2 is quote)
   (lam1? x) (lamform? x && atom? >>>x && nom? <>x)           ; exactly (\ p b), p a nom
   (inlam f k) (: v ("v" + show (peep vc 0 0)) _ (pin vc 0 (1 + peep vc 0 0))
                  _ (pin vtab <>f v) r (k v) _ (pull vtab <>f 0) r)
   ; a function term (map/fold/compose argument, or a beta head) -> its Coq fun, else 0
   (tfn f) (? (atom? f) 0
              (atom? >f && binop <f) (binop <f)                   ; (+) -- the escaped operator
              (un2? f && binop <f && intv? <>f)
                ("(" + binop <f + " " + tv <>f + ")")             ; (+ 1) -- the left section
              (lam1? f) (inlam f (v \ intv? <>>f ? ("(fun " + v + " : Z => " + tv <>>f + ")") 0))
              0)
   ; a predicate term (filter/all/any): a bool body rides bare, an integer body is true iff positive
   (tfb f) (lam1? f ? (inlam f (v \ (tp <>>f @ p
                                        (? p ("(fun " + v + " : Z => " + p + ")")
                                           (intv? <>>f) ("(fun " + v + " : Z => Z.ltb 0 " + tv <>>f + ")")
                                           0))))
              0)
   (tfn2 f) (two? f && atom? >f ? (binop <f) 0)                   ; (+) (*) as a fold's dyadic
   (cmpb f) (two? f && atom? >f ?                                 ; sortby's goes-before test
             (<f @ '< "Z.leb" '> "(fun a b : Z => Z.leb b a)" 0) 0)

   ; -- the unit lane: () (and a fresh mint) rides + and absorbs every numeric op --
   (mintv? ('mint . _)) 1
   (unit? x)  (x = () || mintv? x)
   ; a unit among the elements (never a proper list's own terminal ())
   (hasu? x)  (? (unit? x) 1 (two? x) (hasu? <x || (two? >x ? (hasu? >x) 0)) 0)
   (uzf h) (binop h || shiftf h || (h = '/ ? "Z.div" 0))  ; / only ever meets its unit
   ; scalar u-tree: + - * recurse; the narrower ops take their unit directly
   (uz? x) (? (unit? x) 1  (intv? x) 1
              (x @ [h i j] (? (elem h '(+ - *)) (uz? i && uz? j)
                              (uzf h)              ((unit? i && uz? j) || (uz? i && unit? j))
                              0)
                   0))
   (tuz x) (? (unit? x) "None"  (intv? x) ("(Some " + tv x + ")")
              (<x = '*) ("(umul " + tuz <>x + " " + tuz <>>x + ")")   ; * : the unit annihilates
              (<x = '+) ("(uop " + uzf <x + " " + tuz <>x + " " + tuz <>>x + ")")   ; + : it rides
              ("(uabs " + uzf <x + " " + tuz <>x + " " + tuz <>>x + ")"))            ; the numeric lanes absorb
   ; list u-tree: a unit on either side of + answers the list side; under * it annihilates
   (ul? x) (? (lst? x) 1
              !(len3? x && (<x = '+ || <x = '*)) 0
              ((unit? <>x && ul? <>>x) || (ul? <>x && unit? <>>x)))
   (tul x) (? (unit? x) "None"  (lst? x) ("(Some " + tl x + ")")
              (<x = '*) ("(ulmul " + tul <>x + " " + tul <>>x + ")")
              ("(ulop " + tul <>x + " " + tul <>>x + ")"))

   ; -- text as spelling: strings are byte lists under + (concat) and * (repeat); a symbol
   ;    stays out of this lane, and a symbol never = a string
   (qnom? x) (two? x && <x = bs && un2? x && nom? <>x)     ; 'ef
   (txt? x) (? (string? x) 1
               (atom? x) 0
               (<x @ ('+ && len3? x) (txt? <>x && txt? <>>x)
                     ('* && len3? x) (txt? <>x && charm? <>>x)
                     ('string && un2? x) (txt? <>x)
                     0))
   (tband x) (string? x ? 1
                (<x @ '+ (tband <>x = 0 ? (tband <>>x) 1)   ; a string wins
                      '* (tband <>x)
                      1))
   (ttl x) (string? x ? ("[" + joinb x 0 + "]")
              (<x @ '+ ("(" + ttl <>x + " ++ " + ttl <>>x + ")")
                    '* ("(srep (Z.abs_nat " + tv <>>x + ") " + ttl <>x + ")")
                    (ttl <>x)))                             ; string: the spelling itself

   ; -- gaussian twins: exact complex over Z as (re im) pairs; the unit rides + and -, the
   ;    sign and order are lex on (re, im)
   (twinv? x) (len3? x && <x = 'twin && charm? <>x && charm? <>>x)
   ; a twin/conj/i anywhere: the gate into the gaussian lane (a charm or unit joins only then)
   (hasg? x) (? (nom? x) (elem x '(i twin conj)) (two? x) (hasg? <x || hasg? >x) 0)
   (gneg? x) (two? x && un2? x && two? <x &&
              (<x @ s (un2? s && <s = '- && <>s = 0)))        ; ((- 0) g): negation
   (gz? x) (? (twinv? x) 1  (x = 'i) 1  (charm? x) 1  (unit? x) 1
              (atom? x) 0
              (gneg? x) (gz? <>x)
              (<x @ ('conj && un2? x) (gz? <>x)
                    ; a unit under * or - leaves the band, so only + lets it ride
                    ((('* || '-)) && len3? x) (gz? <>x && gz? <>>x && !(hasu? <>x) && !(hasu? <>>x))
                    ('+ && len3? x) (gz? <>x && gz? <>>x)
                    0))
   (tg x) (? (twinv? x) ("(" + tv <>x + ", " + tv <>>x + ")")
             (x = 'i) "(0, 1)"
             (charm? x) ("(" + tv x + ", 0)")
             (gneg? x) ("(gsub (0, 0) " + tg <>x + ")")
             (<x @ h
                (? (h = 'conj) ("(gconj " + tg <>x + ")")
                   (unit? <>x) (tg <>>x)                     ; the unit rides + : the twin side is the answer
                   (unit? <>>x) (tg <>x)
                   (h = '+) ("(gadd " + tg <>x + " " + tg <>>x + ")")
                   (h = '-) ("(gsub " + tg <>x + " " + tg <>>x + ")")
                   ("(gmul " + tg <>x + " " + tg <>>x + ")"))))
   ; a (list ..) / (array n ..) of gaussian elements: its net is the gadd fold
   (gels x) (<x = 'array ? >>x >x)
   (allg? l) (two? l ? (gz? <l && allg? >l) 1)
   (glist? x) (two? x && (<x = 'list || <x = 'array && charm? <>x)
               && two? (gels x) && allg? (gels x))
   (tgsum l) (two? >l ? ("(gadd " + tg <l + " " + tgsum >l + ")") (tg <l))

   ; -- lambdas as data: a lambda literal translates to a de Bruijn term and = is lteqb. a
   ;    bound param is LV depth, a free nom or head interns to LO (ltab), a literal is LN;
   ;    quote data and special forms in a body stay out
   (lidx nm) (peep ltab nm 0 ||
              (: n (1 + peep lc 0 0) _ (pin lc 0 n) _ (pin ltab nm n) n))
   (idxof nm l k) (? (atom? l) -1 (<l = nm) k (idxof nm >l (k + 1)))
   colon ': qm '?
   (lt x env) (? (charm? x) ("(LN " + tv x + ")")
                 (nom? x) (idxof x env 0 @ p
                             (p >= 0 ? ("(LV " + show p + ")") ("(LO " + show (lidx x) + ")")))
                 (lamform? x) (ltlam >x () env)
                 (atom? x) 0
                 (elem <x [bs colon qm]) 0
                 (lt <x env @ r (r ? (ltap r >x env) 0)))
   (ltap acc args env) (atom? args ? acc
                          (lt <args env @ r
                             (r ? (ltap ("(LAp " + acc + " " + r + ")") >args env) 0)))
   ; params then body: the last param is the innermost binder (LV 0 in the body)
   (ltlam rest ps env) (two? >rest ?
                          (nom? <rest ? (ltlam >rest (<rest . ps) env) 0)
                          (lt <rest (ps + env) @ r
                             (r ? (llwrap r #ps) 0)))
   (llwrap s n) (0 < n ? (llwrap ("(LLam " + s + ")") (n - 1)) s)

   ; -- forms that read the unit: (:) (?) (\) '(), a cond with all literal tests failing and
   ;    no else, a map over (), && / || landing on nothing
   (qempty? x) (two? x && <x = bs && un2? x && <>x = ())   ; '()
   (nothing? x) (x = 0 || x = ())
   (condu? l) (? (atom? l) 1                                    ; pairs exhausted, no else: the unit
                 (atom? >l) 0                                   ; a lone else would answer
                 (nothing? <l && condu? >>l))
   (andu? l) (? (atom? l) 0
                (nothing? <l) 1
                (charm? <l) (andu? >l)
                0)
   (allnothing? l) (two? l ? (nothing? <l && allnothing? >l) 1)
   (unitv? x) (? (x = ()) 1  (qempty? x) 1
                 (atom? x) 0
                 (atom? >x) (elem <x [colon qm bs])   ; (:) (?) (\): an empty form reads its head
                 (<x @ '? (condu? >x)  '&& (andu? >x)  '|| (allnothing? >x)
                       ('map && len3? x) (<>>x = ())
                       0))
   ; == on literals: noms intern, a charm is its word, every unit-reading form is the one
   ; unit; a quoted nonempty list or a lambda is fresh, never ==; the unit is not == 0
   (qplist? x) (two? x && <x = bs && un2? x && two? <>x)
   (idv a b) (? (qnom? a && qnom? b) (<>a = <>b ? "true" "false")
                (unitv? a && unitv? b) "true"
                (charm? a && charm? b) (a = b ? "true" "false")
                ((unitv? a && charm? b)  || (charm? a && unitv? b) ||
                 (unitv? a && qnom? b)   || (qnom? a && unitv? b) ||
                 (qplist? a && qplist? b) || (lamform? a && lamform? b) ||
                 (lamform? a && charm? b) || (charm? a && lamform? b)) "false"
                0)

   ; the kind of a collection value -- arrays broadcast elementwise, lists append
   (arr? x) (arrv? x || iotav? x ||
             (len3? x && (<x @ '+ (arr? <>x && arr? <>>x)
                               ('* || '//) (arr? <>x && intv? <>>x)
                               0)))
   (lst? x) (? (qlist? x) 1  (string? x) 1
               (atom? x) 0
               ; + is append, or degenerate when a number meets a list (the associativity law)
               (x @ ['+ a b] ((intv? a && lst? b) || (lst? a && (lst? b || intv? b)))
                    ['* a b] (lst? a && intv? b)                          ; repeat
                    ['map a b]    (tfn a && lst? b)
                    ['filter a b] (tfb a && lst? b)
                    ['sortby a b] (cmpb a && lst? b)
                    ['cat a b]    (lst? a && lst? b)
                    [('take || 'drop) a b] (intv? a && lst? b)
                    ['link a b]   (intv? a && (lst? b || b = ()))
                    [('rev || 'sort || 'init || 'cup) a] (lst? a)
                    ['jot a]      (intv? a)
                    0))
   (listv? x) (arr? x || lst? x)                     ; any collection value
   (lop? h) (elem h '(net prod tally max min))
   ; the saturate head in each spelling it arrives in: opfix makes glued $x `sat`, ($ x) keeps `$`
   (satf h) (elem h '(sat saturate $))
   ; a hash literal {k v ..} = (hash k v ..): an assoc list of fixnum chains (even count)
   (even? l) (two? l ? !(even? >l) 1)
   (hashv? x) (two? x && <x = 'hash && zlist? >x && even? >x)
   (len4? [_ _ _ _]) 1
   (chains l) (atom? l || atom? >l ? ""
               ("(" + tv <l + ", " + tv <>l + ")" + (two? >>l ? ";" "") + chains >>l))
   (th x) ("[" + chains >x + "]")             ; {1 10 2 20} -> [(1, 10);(2, 20)]
   ; translate a collection value to a Coq `list Z` -- a unit element reads 0, a nom its spelling
   (zv e) (? (charm? e) (tv e) (nom? e) (show (net e)) "0")
   (joinl l) (two? l ? (zv <l + (two? >l ? ";" "") + joinl >l) "")
   (joinb s i) (i < tally s ? (show (s i) + (i + 1 < tally s ? ";" "") + joinb s (i + 1)) "")
   (tl x) (? (qnlist? x) ("[" + joinl <>x + "]")     ; noms only via the measure lanes
             (arrv? x)   ("[" + joinl >x + "]")
             (iotav? x)  ("(iotaZ " + tv <>x + ")")
             (string? x) ("[" + joinb x 0 + "]")
             (<x @ h                                          ; the broadcast / append / repeat ops
                (? (h = '+)  (? (arr? x)    ("(vaddt " + tl <>x + " " + tl <>>x + ")")
                                  (intv? <>x)  (tl <>>x)   ; a number against a list is the unit
                                  (intv? <>>x) (tl <>x)
                                  ("(" + tl <>x + " ++ " + tl <>>x + ")"))              ; list append
                   (h = '*)  (arr? x ? ("(vscale " + tv <>>x + " " + tl <>x + ")")   ; array scale
                                  ("(srep (Z.abs_nat " + tv <>>x + ") " + tl <>x + ")")) ; list repeat
                   (h = '//) ("(vquot " + tv <>>x + " " + tl <>x + ")")
                   (h @ 'map    ("(map " + tfn <>x + " " + tl <>>x + ")")
                        'filter ("(filter " + tfb <>x + " " + tl <>>x + ")")
                        'sortby ("(insortby " + cmpb <>x + " " + tl <>>x + ")")
                        'cat    ("(" + tl <>x + " ++ " + tl <>>x + ")")
                        'take   ("(firstn (Z.to_nat " + tv <>x + ") " + tl <>>x + ")")
                        'drop   ("(skipn (Z.to_nat " + tv <>x + ") " + tl <>>x + ")")
                        'link   ("(" + tv <>x + " :: " + (<>>x = () ? "[]" (tl <>>x)) + ")")
                        'rev    ("(rev " + tl <>x + ")")
                        'sort   ("(insort " + tl <>x + ")")
                        'init   ("(removelast " + tl <>x + ")")
                        'cup    ("(skipn (Z.to_nat 1) " + tl <>x + ")")
                        'jot    ("(iotaZ " + tv <>x + ")")
                        "[]"))))

   ; integer-valued term? a fixnum, a bound param, an operator tree, a reducer or indexer,
   ; a fold, a beta/compose, a numeral spine, or a predicate (its 1|0 charm)
   (intv? x) (? (charm? x) 1
                (nom? x) (peep vtab x 0 ? 1 0)
                (two? x) (<x @ h
                            (? (binop h)     (len3? x &&
                                              (elem h '(& | ^)             ; bitwise is the word lane:
                                               ? (wz? <>x && wz? <>>x)        ; a big operand leaves Z
                                                 (intv? <>x && intv? <>>x)))
                               (shiftf h)    (len3? x && charm? <>x && charm? <>>x)
                               (satf h)        (un2? x && (intv? <>x || listv? <>x || hashv? <>x ||
                                                             qnlist? <>x || lamform? <>x ||
                                                             (hasg? <>x && glist? <>x)))
                               (h = 'peep)  (len4? x && (hashv? <>x || listv? <>x) && intv? <>>x && intv? <>>>x)
                               (lop? h)       (un2? x && (listv? <>x || qnlist? <>x))
                               (h = 'abs)   (un2? x && intv? <>x)
                               (elem h '(cap caup last)) (un2? x && lst? <>x)
                               (elem h '(foldl foldr))
                                              (len4? x && tfn2 <>x && intv? <>>x && lst? <>>>x)
                               (hashv? h)     (un2? x && intv? <>x)          ; ({..} k) map lookup
                               (two? h && un2? x) (tfn h && intv? <>x)       ; direct beta / an applied section
                               (charm? h)     (allv? x ||
                                               (len3? x && tfn <>x && intv? <>>x))  ; n-fold compose
                               (tp x @ p (p ? 1 0))))                      ; a predicate, as its 1|0 charm
                0)
   (allv? l) (two? l ? (intv? <l && allv? >l) (atom? l))
   ; a closed tree of numeric literals under a modelled op, so its value can be checked: the
   ; model has no big kind, and a narrow op widens on a zero divisor ((% 7 0) is 0.0), which
   ; the syntactic kind lattice cannot see (tk)
   (concrete-int? x) (two? x ? (len3? x && binop <x &&
                                  concrete-int? <>x && concrete-int? <>>x)
                          (!(nom? x) && atom? x))

   ; translate an integer-valued term to a Coq Z expression
   (tv x) (? (charm? x) (x < 0 ? ("(" + show x + ")") (show x))  ; `Z.eqb -2` would parse as subtraction
             (nom? x) (peep vtab x "?")                          ; a lambda param in flight
             (: h <x b (binop h)
                (? b ("(" + b + " " + tv <>x + " " + tv <>>x + ")")
                   (shiftf h) ("(" + shiftf h + " " + tv <>x + " " + tv <>>x + ")")
                   (satf h)        (? (lamform? <>x || hashv? <>x) "1"          ; a closure nets 1, and a tablet is one
                                        (hasg? <>x && glist? <>x) ("(gsat " + tgsum (gels <>x) + ")")
                                        (listv? <>x || qnlist? <>x) ("(satZ (asum " + tl <>x + "))")
                                        ("(satZ " + tv <>x + ")"))  ; spec.v's clamp
                   (h = 'net)   ("(asum " + tl <>x + ")")
                   (h = 'tally) ("(Z.of_nat (length " + tl <>x + "))")
                   (h = 'max)  ("(amax " + tl <>x + ")")
                   (h = 'min)  ("(amin " + tl <>x + ")")
                   (h = 'prod) ("(aprod " + tl <>x + ")")
                   (h = 'abs)   ("(Z.abs " + tv <>x + ")")
                   (h = 'cap)   ("(hd 0 " + tl <>x + ")")
                   (h = 'caup)  ("(nth (Z.to_nat 1) " + tl <>x + " 0)")
                   (h = 'last)  ("(last " + tl <>x + " 0)")
                   (h = 'foldl) ("(fold_left " + tfn2 <>x + " " + tl <>>>x + " " + tv <>>x + ")")
                   (h = 'foldr) ("(fold_right " + tfn2 <>x + " " + tv <>>x + " " + tl <>>>x + ")")
                   (h = 'peep)  (hashv? <>x ? ("(hget " + th <>x + " " + tv <>>x + " " + tv <>>>x + ")")
                                     ("(nth (Z.to_nat " + tv <>>x + ") " + tl <>x + " " + tv <>>>x + ")"))
                   (hashv? h)     ("(hget " + th h + " " + tv <>x + " 0)")  ; ({..} k) -- lookup, default 0
                   (two? h && tfn h) ("(" + tfn h + " " + tv <>x + ")")  ; beta / applied section
                   (charm? h && allv? x) (spine (tv h) >x)               ; (app .. ..) power spine
                   (charm? h) ("(Nat.iter (Z.to_nat " + tv h + ") " + tfn <>x + " " + tv <>>x + ")")  ; n-fold compose
                   (tp x @ p ("(Z.b2z " + p + ")")))))                 ; the predicate's charm
   (spine acc rest) (two? rest ? (spine ("(appZ " + acc + " " + tv <rest + ")") >rest) acc)

   ; the kind tag of a literal for the type predicates, "Vbot" if untaggable; a closed int
   ; expression answers by its value's kind (a zero divisor widens, a big skips)
   (tk x) (? (unitv? x) "Vunit"                                        ; () and every form that reads it
             (intv? x) (? !(concrete-int? x) "Vz"
                          (ev x @ v (? (charm? v) "Vz" (gem? v) "Vflo" "Vbot")))
             (gem? x) "Vflo"  (string? x) "Vstr"  (x = 'i) "Vcx"
             (two? x) (<x @ h
                        (? (h = bs) (tkq <>x)                        ; '(..) or 'x
                           (elem h '(twin conj)) "Vcx"              ; (re ~ im); conj always answers a twin
                           (h = 'hash) "Vmap"                        ; {..}
                           (elem h '(tuple iota)) "Varr"            ; @(..) / (iota n)
                           "Vbot"))
             "Vbot")
   (tkq q) (? (nom? q) "Vsym" (two? q) "Vpair" (charm? q) "Vz" "Vbot")   ; the quoted datum's kind
   (kpred h) (h @ 'charm? "fixp"   'gem? "flop"   'twin? "comp"
                  'string? "strp"  'nom? "nomp"   'name? "namep"  'two? "chainp"
                  'tablet? "tabp"  'set? "setp"   'constellation? "nump"
                  'whole? "whole"  'atom? "atomp" 'packp "packp"
                  'lit? "lamp" 0)
   ; cross-band order: symbol<string<number<chain<map; same band stays value/lex
   (ordop? h) (elem h '(< <= > >=))
   (litband x) (tk x @ t
                 (? (t = "Vbot") -1  (t = "Vunit") -1                 ; the unit stays out of the band order
                    (t = "Vsym") 0 (t = "Vstr") 1
                    (t = "Vz" || t = "Vflo" || t = "Vcx" || t = "Varr") 2
                    (t = "Vpair") 3 (t = "Vmap") 4  9))
   (xband? f) (len3? f && ordop? <f && litband <>f >= 0 && litband <>>f >= 0 &&
               litband <>f != litband <>>f)                  ; both tagged, different bands
   (xband f) (: h <f a ("(vband " + tk <>f + ")") b ("(vband " + tk <>>f + ")")
               (h @ '<  ("(Z.ltb " + a + " " + b + ")")  '<= ("(Z.leb " + a + " " + b + ")")
                    '>  ("(Z.ltb " + b + " " + a + ")")  ("(Z.leb " + b + " " + a + ")")))

   ; translate a top-level predicate to a Coq bool, or 0 if not translatable.
   ; `!` factors to nil?: the bit "x is nothing" (x <= 0 for integers)
   (tp f) (atom? f ? 0
             (<f @ h
                (? (h = 'nil?) (<>f @ a
                                   (? (intv? a)  ("(Z.leb " + tv a + " 0)")
                                      (listv? a) ("(Z.leb (asum " + tl a + ") 0)")
                                      (unitv? a) "true"                              ; the unit is nothing
                                      (lamform? a || hashv? a) "false"                ; a closure or tablet nets 1
                                      (hasg? a && gz? a) ("(negb (gpos " + tg a + "))")  ; a twin is true iff lex-positive
                                      (hasg? a && glist? a) ("(negb (gpos " + tgsum (gels a) + "))")
                                      (tp a @ p (p ? ("(negb " + p + ")") 0))))
                   (kpred h)  (tk <>f @ t (t = "Vbot" ? 0 ("(" + kpred h + " " + t + ")")))
                   (h = 'elem) (len3? f && intv? <>f && lst? <>>f ?
                                     ("(existsb (Z.eqb " + tv <>f + ") " + tl <>>f + ")") 0)
                   (h = 'all) (len3? f && lst? <>>f && tfb <>f ?
                                 ("(forallb " + tfb <>f + " " + tl <>>f + ")") 0)
                   (h = 'any) (len3? f && lst? <>>f && tfb <>f ?
                                 ("(existsb " + tfb <>f + " " + tl <>>f + ")") 0)
                   !(len3? f) 0
                   (h = '==) (idv <>f <>>f)                        ; the verdict, or 0 (skip)
                   (h = '=) (? (intv? <>f && intv? <>>f)   ("(Z.eqb " + tv <>f + " " + tv <>>f + ")")
                                 (listv? <>f && listv? <>>f) ("(leqb " + tl <>f + " " + tl <>>f + ")")
                                 ; gaussian =: numeric within the band, a zero-im twin = its charm
                                 ((hasg? <>f || hasg? <>>f) && gz? <>f && gz? <>>f)
                                   ("(geqb " + tg <>f + " " + tg <>>f + ")")
                                 (lamform? <>f && lamform? <>>f)
                                   (: a (lt <>f ()) b (lt <>>f ())
                                      (a && b ? ("(lteqb " + a + " " + b + ")") 0))
                                 ; no eta: a closure never = a plain nom
                                 ((lamform? <>f && nom? <>>f) || (nom? <>f && lamform? <>>f)) "false"
                                 ; a mint rides an op like a unit but never stands as an = side
                                 (!(mintv? <>f) && !(mintv? <>>f) &&
                                  (hasu? <>f || hasu? <>>f) && uz? <>f && uz? <>>f)
                                   ("(ueq " + tuz <>f + " " + tuz <>>f + ")")
                                 (!(mintv? <>f) && !(mintv? <>>f) &&
                                  (hasu? <>f || hasu? <>>f) && ul? <>f && ul? <>>f)
                                   ("(uleq " + tul <>f + " " + tul <>>f + ")")
                                 (txt? <>f && txt? <>>f)
                                   (tband <>f = tband <>>f ?
                                    ("(leqb " + ttl <>f + " " + ttl <>>f + ")") 0)     ; same band, same spelling
                                 (litband <>f >= 0 && litband <>>f >= 0 &&
                                  litband <>f != litband <>>f) "false"
                                 0)
                   (ordop? h && (hasg? <>f || hasg? <>>f) && gz? <>f && gz? <>>f)
                     (: a (tg <>f) b (tg <>>f)
                        (h @ '<  ("(gltb " + a + " " + b + ")")
                             '>  ("(gltb " + b + " " + a + ")")
                             '<= ("(negb (gltb " + b + " " + a + "))")
                                 ("(negb (gltb " + a + " " + b + "))")))
                   ; functions carry no strict order: < and > answer nothing
                   ((h = '< || h = '>) && lamform? <>f && lamform? <>>f) "false"
                   (xband? f) (xband f)
                   (ordop? h && lst? <>f && lst? <>>f)                ; same-band order is lex
                     (: a (tl <>f) b (tl <>>f)
                        (h @ '<  ("(lexltb " + a + " " + b + ")")
                             '>  ("(lexltb " + b + " " + a + ")")
                             '<= ("(negb (lexltb " + b + " " + a + "))")
                                 ("(negb (lexltb " + a + " " + b + "))")))
                   (ordop? h && (<>f = () || <>>f = ()) && uz? <>f && uz? <>>f)
                     (: a ("(unet " + tuz <>f + ")") b ("(unet " + tuz <>>f + ")")
                        (h @ '<  ("(Z.ltb " + a + " " + b + ")")
                             '>  ("(Z.ltb " + b + " " + a + ")")
                             '<= ("(Z.leb " + a + " " + b + ")")
                                 ("(Z.leb " + b + " " + a + ")")))
                   !(intv? <>f && intv? <>>f) 0
                   (h @ '<  ("(Z.ltb " + tv <>f + " " + tv <>>f + ")")
                        '<= ("(Z.leb " + tv <>f + " " + tv <>>f + ")")
                        '>  ("(Z.ltb " + tv <>>f + " " + tv <>f + ")")
                        '>= ("(Z.leb " + tv <>>f + " " + tv <>f + ")")
                        0))))

   ; the assert shown above each theorem; Coq comments nest, so a shown `(*)` or `*)` pair
   ; is padded apart
   (esc s) (#s @ n
              ((: (go i acc)
                 (i < n ?
                    (: c (s i) d (i + 1 < n ? (s (i + 1)) -1)
                       ((c = 40 && d = 42) || (c = 42 && d = 41) ?
                          (go (i + 1) (acc + c + 32))
                          (go (i + 1) (acc + c))))
                    acc)) 0 ""))
   (thm n f s) ("(* " + esc (show f) + " *)\nTheorem gen_" + show n + " : " + s
                + " = true.  Proof. vm_compute. reflexivity. Qed.\n")

   nt {} ns {}                                          ; translated / seen
   (bump b) (pin b 0 (1 + peep b 0 0))
   (walkops ops) (!ops ? 0
                 (: f <ops _ (bump ns) s (tp (fix1 f))
                    _ (s ? (bump nt, dot (thm (peep nt 0 0) f s))
                           (say err ("  UNMODELED: " + show f + "\n")))
                    (walkops >ops)))
   (walk fs) (!fs ? 0
                (: f <fs
                   _ (two? f && <f = 'test ? (walkops >f) 0)
                   (walk >fs)))

   _ (dot (join [
     "(* test/proof/rocq/gen.v -- GENERATED from test/spec.l by src/tools/spec2coq.l. Do not edit;\n"
     "   regenerate with `make test_gen`. Each integer-comparison corpus assert is\n"
     "   translated to Coq, with its source assert shown in the comment above it.\n"
     "   The proofs are `vm_compute. reflexivity.`: every goal is a CLOSED computation,\n"
     "   so vm_compute RUNS both sides (Coq's bytecode VM -- fast even on bignums like\n"
     "   2^64) to a normal form, and reflexivity checks the two results are identical.\n"
     "   A church numeral n applied to x is x ** n (`appZ`); a list/string nets the\n"
     "   sum of its elements/bytes (`asum`). The MODEL IS SHARED: this file imports\n"
     "   test/proof/rocq/spec.v and checks against ITS definitions -- appZ/asum/aprod/amax/vscale/srep\n"
     "   verbatim, iotaZ the Z-arg face, app_appZ proving appZ IS the nat `app` -- so the\n"
     "   generated instances and the hand-written LAWS speak one model. The defs below are\n"
     "   gen-only (no spec.v twin): amin, leqb, the TOTAL vaddt (spec.v's vadd is option-\n"
     "   valued for its shape-mismatch law), vquot, hget, the syntactic kind lattice,\n"
     "   the word shifts (count mod 64), the option-lifted UNIT lane (None rides uop/ulop,\n"
     "   () being the unit of + alone, and is ABSORBED by uabs/umul/ulmul -- every numeric\n"
     "   lane), insertion sort, lex order, the\n"
     "   gaussian twins (exact complex over Z; sign and order LEX on (re, im)), and the\n"
     "   de Bruijn lambda terms (function = is alpha + structural: lteqb). *)\n"
     "From Stdlib Require Import ZArith List.\n"
     "Require Import spec.\n"
     "Import ListNotations.\n"
     "Open Scope Z_scope.\n"
     "Definition amin (l:list Z):Z := match l with nil=>0 | x::xs=>fold_right Z.min x xs end.\n"
     "Fixpoint leqb (a b:list Z):bool := match a,b with nil,nil=>true | x::a',y::b'=>andb (Z.eqb x y) (leqb a' b') | _,_=>false end.\n"
     "Fixpoint vaddz (a b:list Z):list Z := match a,b with x::a',y::b'=>(x+y)::vaddz a' b' | _,_=>nil end.\n"
     ; love adds elementwise only at equal length; a mismatch answers () (net 0)
     "Definition vaddt (a b:list Z):list Z := if Nat.eqb (length a) (length b) then vaddz a b else nil.\n"
     "Definition vquot (c:Z):list Z->list Z := map (fun e=>Z.quot e c).\n"
     "Fixpoint hget (m:list (Z*Z)) (k d:Z):Z := match m with nil=>d | p::m' => if Z.eqb k (fst p) then snd p else hget m' k d end.\n"
     ; >> is arithmetic (Z.shiftr on negatives)
     "Definition shlz (a b:Z):Z := Z.shiftl a b.  Definition shrz (a b:Z):Z := Z.shiftr a b.\n"
     ; None is (): it rides every lifted dyadic, except * where it annihilates
     "Definition uop (f:Z->Z->Z) (a b:option Z) : option Z := match a,b with None,x=>x | x,None=>x | Some x, Some y => Some (f x y) end.\n"
     "Definition uabs (f:Z->Z->Z) (a b:option Z) : option Z := match a,b with Some x, Some y => Some (f x y) | _,_ => None end.\n"
     "Definition umul (a b:option Z) : option Z := match a,b with Some x, Some y => Some (x*y) | _,_ => None end.\n"
     "Definition ulmul (a b:option (list Z)) : option (list Z) := None.\n"
     "Definition ueq (a b:option Z) : bool := match a,b with None,None=>true | Some x, Some y => Z.eqb x y | _,_=>false end.\n"
     "Definition unet (a:option Z) : Z := match a with None => 0 | Some z => z end.\n"
     "Definition ulop (a b:option (list Z)) : option (list Z) := match a,b with None,x=>x | x,None=>x | Some x, Some y => Some (x++y) end.\n"
     "Definition uleq (a b:option (list Z)) : bool := match a,b with None,None=>true | Some x, Some y => leqb x y | _,_=>false end.\n"
     "Fixpoint insZ (le:Z->Z->bool) (x:Z) (l:list Z) : list Z := match l with nil => x::nil | y::t => if le x y then x::y::t else y::insZ le x t end.\n"
     "Fixpoint insortby (le:Z->Z->bool) (l:list Z) : list Z := match l with nil => nil | x::t => insZ le x (insortby le t) end.\n"
     "Definition insort := insortby Z.leb.\n"
     ; lexicographic, a proper prefix first
     "Fixpoint lexltb (a b:list Z) : bool := match a,b with nil,nil=>false | nil,_=>true | _,nil=>false | x::a',y::b' => orb (Z.ltb x y) (andb (Z.eqb x y) (lexltb a' b')) end.\n"
     "Definition gadd (a b:Z*Z):Z*Z := (fst a + fst b, snd a + snd b).\n"
     "Definition gsub (a b:Z*Z):Z*Z := (fst a - fst b, snd a - snd b).\n"
     "Definition gmul (a b:Z*Z):Z*Z := (fst a * fst b - snd a * snd b, fst a * snd b + snd a * fst b).\n"
     "Definition gconj (a:Z*Z):Z*Z := (fst a, - snd a).\n"
     "Definition geqb (a b:Z*Z):bool := andb (Z.eqb (fst a) (fst b)) (Z.eqb (snd a) (snd b)).\n"
     "Definition gltb (a b:Z*Z):bool := orb (Z.ltb (fst a) (fst b)) (andb (Z.eqb (fst a) (fst b)) (Z.ltb (snd a) (snd b))).\n"
     ; truth is the real part, not the lex order: it cannot depend on which root of x^2+1 is `i`
     "Definition gpos (a:Z*Z):bool := Z.ltb 0 (fst a).\n"
     ; $ of a twin: its real part once the gate passes, else 0, so clamp and gate agree
     "Definition gsat (a:Z*Z):Z := if gpos a then satZ (fst a) else 0.\n"
     "Inductive ltm := LV (n:nat) | LO (o:Z) | LN (z:Z) | LAp (f a:ltm) | LLam (b:ltm).\n"
     "Fixpoint lteqb (a b:ltm):bool := match a,b with LV n,LV m=>Nat.eqb n m | LO n,LO m=>Z.eqb n m | LN n,LN m=>Z.eqb n m | LAp f x,LAp g y=>andb (lteqb f g) (lteqb x y) | LLam s,LLam t=>lteqb s t | _,_=>false end.\n"
     ; the kind lattice (vkind/vband avoid spec.v's value/band)
     "Inductive vkind := Vz | Vflo | Vcx | Vstr | Vsym | Vpair | Vmap | Varr | Vunit | Vbot.\n"
     "Definition fixp  v := match v with Vz   => true | _ => false end.\n"
     "Definition flop  v := match v with Vflo => true | _ => false end.\n"
     "Definition comp  v := match v with Vcx  => true | _ => false end.\n"
     "Definition strp  v := match v with Vstr => true | _ => false end.\n"
     "Definition nomp  v := match v with Vsym => true | _ => false end.\n"
     "Definition namep v := match v with Vsym => true | _ => false end.\n"
     "Definition chainp  v := match v with Vpair=> true | _ => false end.\n"
     "Definition tabp  v := match v with Vmap => true | _ => false end.\n"
     "Definition setp  v := match v with Varr => true | _ => false end.\n"
     "Definition whole   v := match v with Vz   => true | _ => false end.\n"
     "Definition nump  v := match v with Vz|Vflo|Vcx|Varr => true | _ => false end.\n"
     "Definition packp v := match v with Vflo|Vcx|Varr => true | _ => false end.\n"
     "Definition atomp v := match v with Vpair => false | _ => true end.\n"
     "Definition lamp  v := match v with Vmap => true | _ => false end.\n"   ; among modeled kinds only Vmap is lit?
     "Definition vband v : Z := match v with Vsym => 0 | Vstr => 1 | Vz|Vflo|Vcx|Varr => 2 | Vpair => 3 | Vmap => 4 | Vunit|Vbot => 9 end.\n\n"]))
   _ (say err "spec2coq: UNMODELED asserts (seen but never proved) --\n")
   _ (walk (forms (open "test/spec.l" "r")))
   _ (dot ("\n(* " + show (peep nt 0 0) + " theorems generated from " + show (peep ns 0 0) + " asserts seen *)\n"))
   _ (say err $ "spec2coq: " + show (peep nt 0 0) + " translated, "
                + show (peep ns 0 0 - peep nt 0 0) + " UNMODELED, of "
                + show (peep ns 0 0) + " asserts seen\n")
   (quit 0))
