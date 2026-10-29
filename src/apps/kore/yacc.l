; src/apps/kore/yacc.l -- yacc: a grammar with precedences -> LALR(1) tables (DeRemer and
; Pennello's lookaheads), comb-packed in one table string lr.c's (run t k c look) walks. an action
; is a love form over its operands _1 .. _n (yacc's $1 .. $n) and the %param name, played back
; off lr.c's log of reductions by yacc-run.
;   (yacc-scan spec)                 -> (tables gram) | a string saying why not
;   (yacc-run t acts ks vs ps need)  -> ('ok value) | ('err i): ks a u16 kind per token, vs their
;      values; a kind 0xffff is (need ps i)'s to say once the actions before it have run, a kind
;      or lr.c's pair a + 65536 * (b + 1), a where it can shift and else b
;   (yacc-runv t acts ks vs ps need tv)  the same, a token's value (tv its tail of vs)
;   love yacc [-m MODULE] [-n NAME] SPEC   the tables and actions as love text
;   love yacc -o X.c [--defines=X.h | -d] [-t] [-l] SPEC   a C parser and its header, as bison's:
;      C actions over $$ $n $<t>n @$ @n, %union and <tag>s, %locations, error, %destructor
; a spec: declarations (%token %left %right %nonassoc %start %expect %param %type %union %locations
; %destructor, %{ text %}), %%, rules (name : symbols {action} | .. ;), and an optional %% before
; text laid last, after the actions.
; not yet: mid-rule actions, string-literal tokens; in love text, error, $$ and $<tag>.
(module 'kore
(borrow 'cli)
(borrow 'posix)
(:
   (yacc-die m) (scare 'yacc-err m)
   (yacc-idc? c) (97 <= c <= 122 || 65 <= c <= 90 || c = 95 || c = 46 || 48 <= c <= 57)
   (yacc-dig? c) (48 <= c <= 57)
   (yacc-at ln) (" on line " + show ln)
   ; -- the spec's words: (kind val line), kind id ch num dir tag colon bar semi act text mark,
   ; and the text after a second %% as one tail --
   (yacc-words s)
    (: n #s
       (nls i j) (count (k \ s k = 10) (map (+ i) (jot (j - i))))
       ; past the first a b at or after i
       (past i a b ln) (? (n <= i + 1) (yacc-die ("an open " + string [a b] + yacc-at ln))
                          (s i = a && s (i + 1) = b) (i + 2)
                          (past (i + 1) a b ln))
       (eol i) (i < n && s i != 10 ? (eol (i + 1)) i)
       (idend i) (i < n && yacc-idc? (s i) ? (idend (i + 1)) i)
       ; an action's closing brace, from past its opening one; a string's braces are text
       (brace i d q ln)
        (? (n <= i) (yacc-die ("an open action" + yacc-at ln))
           (s i @ c
              (? q (? (c = 92) (brace (i + 2) d q ln) (c = 34) (brace (i + 1) d () ln) (brace (i + 1) d q ln))
                 (c = 34) (brace (i + 1) d 1 ln)
                 (c = 123) (brace (i + 1) (d + 1) q ln)
                 (c = 125) (d = 0 ? i (brace (i + 1) (d - 1) q ln))
                 (brace (i + 1) d q ln))))
       (go i ln m acc)
        (: (word k v j) (go j (ln + nls i j) m ([k v ln] . acc))
           (? (n <= i) (rev acc)
              (: c (s i) d (i + 1 < n ? (s (i + 1)) 0)
                 (? (c = 10) (go (i + 1) (ln + 1) m acc)
                    (c = 32 || c = 9 || c = 13 || c = 12) (go (i + 1) ln m acc)
                    (c = 47 && d = 42) (: j (past (i + 2) 42 47 ln) (go j (ln + nls i j) m acc))
                    (c = 47 && d = 47) (go (eol i) ln m acc)
                    (c = 37 && d = 37) (? m (rev (['tail (snip s (i + 2) n) ln] . ['mark () ln] . acc))
                                          (go (i + 2) ln 1 (['mark () ln] . acc)))
                    (c = 37 && d = 123) (: j (past (i + 2) 37 125 ln) (word 'text (snip s (i + 2) (j - 2)) j))
                    (c = 37 && yacc-idc? d) (: j (idend (i + 1)) (word 'dir (snip s (i + 1) j) j))
                    (c = 39) (: bj (d = 92 ? (lex-esc s (i + 2)) [d (i + 2)])
                                (<>bj < n && s <>bj = 39 ? (word 'ch <bj (<>bj + 1))
                                   (yacc-die ("an open character" + yacc-at ln))))
                    (c = 60) (: (gt j) (j < n && s j != 62 && s j != 10 ? (gt (j + 1)) j)
                                j (gt (i + 1))
                                (j < n && s j = 62 ? (word 'tag (snip s (i + 1) j) (j + 1)) (yacc-die ("an open <tag>" + yacc-at ln))))
                    (c = 123) (: j (brace (i + 1) 0 () ln) (word 'act (snip s (i + 1) j) (j + 1)))
                    (c = 58) (word 'colon () (i + 1))
                    (c = 124) (word 'bar () (i + 1))
                    (c = 59) (word 'semi () (i + 1))
                    (yacc-dig? c) (: (de j) (j < n && yacc-dig? (s j) ? (de (j + 1)) j)
                                     j (de i)
                                     (word 'num (foldl (v \ k \ 10 * v + s k - 48) 0 (map (+ i) (jot (j - i)))) j))
                    (yacc-idc? c) (: j (idend i) (word 'id (snip s i j) j))
                    (yacc-die ("a stray " + string [c] + yacc-at ln))))))
       (go 0 1 () ()))
   (yacc-wshow w) (<w @ 'id <>w 'dir ("%" + <>w) 'ch (string [39 <>w 39]) 'num (show <>w) (show <w))
   ; -- the grammar: symbols are numbers, the terminals 0 ($end) to T - 1, the rules' names T
   ; ($accept) on; a rule is (lhs rhs action prec line) with lhs a symbol, prec a level or () --
   (yacc-gram ws)
    (: G {} tn {} pr {} asc {} tgs {} ext {}
       _ (pin G 'tl ["$end"], pin tn "$end" 0, pin G 'prec pr, pin G 'assoc asc, pin G 'tags tgs, pin G 'ext ext, pin ext 'n 258)
       (tname w) (<w = 'ch ? (32 < <>w < 127 ? (string [39 <>w 39]) ("'\\" + show <>w + "'")) <>w)
       ; a token's number for C: a character its own, error 256, a name the next from 258
       (term w) (: nm (tname w)
                   (peep tn nm -1 @ k
                      (k >= 0 ? k
                         (: k2 #(G 'tl)
                            _ (pin ext k2 (<w = 'ch ? <>w (nm = "error" ? 256 (: e (ext 'n) (pin ext 'n (e + 1), e)))))
                            (pin G 'tl (G 'tl + [nm]), pin tn nm k2, k2)))))
       ; the symbols after a declaration, each with the <tag> before it
       (syms ws f tg) (? (two? ws && elem <<ws '(id ch tag num))
                          (? (<<ws = 'tag) (syms >ws f <><ws)
                             (: _ (elem <<ws '(id ch) ? (f <ws tg) ()) (syms >ws f tg)))
                         ws)
       (tagit w tg) (tg ? (pin tgs (tname w) tg) ())
       (one ws k what) (two? >ws && <<>ws = k ? <><>ws (yacc-die (what + yacc-at (<ws 2))))
       (decl ws lv)
        (? !(two? ws) (yacc-die "no %% before the rules")
           (<ws @ w
              (? (<w = 'mark) >ws
                 (<w = 'text) (: k (peep G 'union () ? 'post 'head) _ (pin G k (peep G k () + [<>w])) (decl >ws lv))
                 (<w != 'dir) (yacc-die ("a stray " + yacc-wshow w + yacc-at (w 2)))
                 (<>w @ d
                    (? (d = "token") (decl (syms >ws (x \ tg \ (: _ (term x) (tagit x tg))) ()) lv)
                       (elem d '("left" "right" "nonassoc"))
                        (: l2 (lv + 1)
                           _ (pin asc l2 (d = "left" ? 'left (d = "right" ? 'right 'nonassoc)))
                           (decl (syms >ws (x \ tg \ (: _ (tagit x tg) (pin pr (term x) l2))) ()) l2))
                       (d = "start") (: _ (pin G 'start (one ws 'id "%start wants a name")) (decl >>ws lv))
                       (d = "expect") (: _ (pin G 'expect (one ws 'num "%expect wants a number")) (decl >>ws lv))
                       (d = "param") (: _ (pin G 'param (one ws 'id "%param wants a name")) (decl >>ws lv))
                       (d = "type") (decl (syms >ws tagit ()) lv)
                       (d = "union") (decl (two? >ws && <<>ws = 'act ? (: _ (pin G 'union <>(<>ws)) >>ws) >ws) lv)
                       (d = "locations") (: _ (pin G 'locs 1) (decl >ws lv))
                       ; %destructor {code} then the names and <tag>s it is for
                       (d = "destructor")
                        (? (two? >ws && <<>ws = 'act)
                            (: (tgt l acc) (two? l && elem <<l '(id ch tag) ? (tgt >l (<l . acc)) [l acc])
                               (tgt >>ws () @ [w2 ts] (: _ (pin G 'dtors (peep G 'dtors () + [[<>(<>ws) ts]])) (decl w2 lv))))
                           (yacc-die ("%destructor wants an action" + yacc-at (w 2))))
                       (yacc-die ("not yet: %" + d)))))))
       ; the rules as written: (name (word..) action precword line)
       (rule? ws) (two? ws && <<ws = 'id && two? >ws && <<>ws = 'colon)
       (midact ln) (yacc-die ("not yet: an action mid-rule" + yacc-at ln))
       (alt ws lhs sy act pw ln acc)
        (: done ([lhs (rev sy) act pw ln] . acc)
           (? (!(two? ws) || rule? ws || <<ws = 'mark) [ws done]
              (<ws @ w
                 (? (<w = 'bar) (alt >ws lhs () () () (w 2) done)
                    (<w = 'semi) (two? >ws && <<>ws = 'bar ? (alt >ws lhs sy act pw ln acc) [>ws done])
                    (elem <w '(id ch)) (act ? (midact (w 2)) (alt >ws lhs (w . sy) act pw ln acc))
                    (<w = 'act) (act ? (midact (w 2)) (alt >ws lhs sy <>w pw ln acc))
                    (<w = 'dir && <>w = "prec")
                     (two? >ws && elem <<>ws '(id ch) ? (alt >>ws lhs sy act <>ws ln acc)
                        (yacc-die ("%prec wants a token" + yacc-at (w 2))))
                    (yacc-die ("a stray " + yacc-wshow w + yacc-at (w 2)))))))
       (rules ws acc)
        (? !(two? ws) [() (rev acc)]
           (<<ws = 'mark) [(two? >ws ? <>(<>ws)) (rev acc)]
           (<<ws = 'semi) (rules >ws acc)
           (rule? ws) (alt >>ws <><ws () () () (<ws 2) acc @ [w2 a2] (rules w2 a2))
           (yacc-die ("a rule wants a name and a colon" + yacc-at (<ws 2))))
       tr (rules (decl ws 0) ())
       rl <>tr
       _ (two? rl ? () (yacc-die "no rules"))
       nn {} _ (pin nn "$accept" 0)
       nts (foldl (a \ r \ (: nm <r
                             (? (peep nn nm -1 >= 0) a
                                (peep tn nm -1 >= 0) (yacc-die (nm + " is a token and a rule" + yacc-at (r 4)))
                                (: _ (pin nn nm #a) (a + [nm])))))
                  ["$accept"] rl)
       ; a character is a token where it first stands
       _ (map (r \ map (w \ (<w = 'ch || <w = 'id && <>w = "error" && peep nn "error" -1 < 0 ? (term w) ())) <>r) rl)
       T #(G 'tl)
       (sym w ln) (? (<w = 'ch) (term w)
                     (peep nn <>w -1 @ j
                        (j >= 0 ? (T + j)
                           (peep tn <>w -1 @ t
                              (t >= 0 ? t (yacc-die (<>w + " is neither a token nor a rule" + yacc-at ln)))))))
       st (peep G 'start (nts 1))
       _ (peep nn st -1 > 0 ? () (yacc-die (st + " is no rule's name")))
       (rprec rhs pw ln)
        (? pw (peep pr (sym pw ln) () @ l (l ? l (yacc-die (yacc-wshow pw + " has no precedence" + yacc-at ln))))
           (foldl (a \ x \ (x < T && peep pr x () ? (pr x) a)) () rhs))
       rs ([T [(T + nn st) 0] () () 0] .
           map (r \ (: ln (r 4) rhs (map (w \ sym w ln) <>r)
                      [(T + nn <r) rhs (r 2) (rprec rhs (r 3) ln) ln]))
               rl)
       _ (pin G 'errtok (peep tn "error" -1))
       _ (pin G 'T T, pin G 'N #nts, pin G 'terms (G 'tl), pin G 'nts nts, pin G 'rules rs, pin G 'tail <tr)
       G)
   ; -- the LR(0) states, an item r * 128 + dot --
   (yacc-lalr G)
    (: T (G 'T) N (G 'N) rs (G 'rules) R #rs pre (G 'prec) asc (G 'assoc)
       lhs {} rhs {} rpr {} af {} byl {}
       _ (foldl (r \ x \ (: _ (pin lhs r <x, pin rhs r <>x, pin rpr r (x 3))
                            _ (127 < #<>x ? (yacc-die ("a rule longer than 127" + yacc-at (x 4))) ())
                            _ (pin byl <x ((r * 128) . peep byl <x ()))
                            _ (map (d \ pin af (r * 128 + d) (d < #<>x ? (<>x d) -1)) (jot (#<>x + 1)))
                            (r + 1)))
                0 rs)
       ; the rules' first items a name's closure reaches, by first symbol
       ntc {}
       (ntclo X)
        (peep ntc X () @ m
           (m ? m
              (: seen {}
                 (go l acc) (? !(two? l) acc
                               (seen <l) (go >l acc)
                               (: _ (pin seen <l 1)
                                  is (peep byl <l ())
                                  (go (filter (y \ y >= T) (map af is) + >l) (is + acc))))
                 r (go [X] ())
                 (pin ntc X r, r))))
       (clos k) (: s {} _ (map (i \ pin s i 1) k)
                   _ (map (i \ af i @ x (x >= T ? (map (j \ pin s j 1) (ntclo x)) ())) k)
                   (sort (keys s)))
       sid {} kn {} cl {} tr {} sy {} cnt {} _ (pin cnt 'n 0)
       (intern k) (peep sid k -1 @ v (v >= 0 ? v (: v2 (cnt 'n) (pin cnt 'n (v2 + 1), pin sid k v2, pin kn v2 k, v2))))
       _ (intern [0])
       (walk q)
        (? (two? q)
            (: s <q its (clos (kn s)) _ (pin cl s its)
               by {} _ (map (i \ af i @ x (x >= 0 ? (pin by x ((i + 1) . peep by x ())) ())) its)
               xs (sort (keys by)) _ (pin sy s xs)
               new (foldl (a \ x \ (: n0 (cnt 'n) t (intern (sort (by x)))
                                      (pin tr [s x] t, (t >= n0 ? (t . a) a))))
                          () xs)
               (walk (>q + rev new))))
       _ (walk [0])
       S (cnt 'n)
       ; a state's accessing symbol
       stos {} _ (map (k \ pin stos (tr k) (k 1)) (keys tr))
       ss (jot S)
       _ (S < 32768 && R < 32768 ? () (yacc-die "past 32767 states or rules"))
       ; -- the lookaheads: DeRemer and Pennello over the transitions on names, terminal sets as bits --
       nul {}
       (nulfix _) (: ch (foldl (a \ r \ (!(peep nul (lhs r) ()) && all (x \ peep nul x ()) (rhs r) ?
                                         (pin nul (lhs r) 1, 1) a))
                               () (jot R))
                     (ch ? (nulfix 0) ()))
       _ (nulfix 0)
       xid {} xp {} xa {} xn {} _ (pin xn 'n 0)
       _ (map (p \ map (A \ (A >= T ? (: k (xn 'n) (pin xn 'n (k + 1), pin xid [p A] k, pin xp k p, pin xa k A)) ())) (sy p)) ss)
       X (xn 'n)
       xs (jot X)
       (dr k) (foldl (a \ t \ (t < T ? (a | (1 << t)) a)) 0 (sy (tr [(xp k) (xa k)])))
       (rd k) (: r (tr [(xp k) (xa k)])
                 (map (C \ xid [r C]) (filter (C \ C >= T && peep nul C ()) (sy r))))
       inc {} lb {}
       _ (map (k \ (: p (xp k) B (xa k)
                      (map (it \ (: r (it >> 7)
                                   (walk2 q l acc) (? (two? l) (walk2 (tr [q <l]) >l ([q <l] . acc)) [q acc])
                                   qa (walk2 p (rhs r) ())
                                   (back l ok) (? (two? l)
                                                  (: q <<l x <><l
                                                     _ (ok && x >= T ? (xid [q x] @ y (pin inc y (k . peep inc y ()))) ())
                                                     (back >l (ok && x >= T && peep nul x ()))))
                                   _ (back <>qa 1)
                                   (pin lb [<qa r] (k . peep lb [<qa r] ()))))
                           (peep byl B ()))))
              xs)
       (digraph rel f0)
        (: Nn {} F {} st {} _ (pin st 'l (), pin st 'd 0)
           inf 1073741824
           (trav x)
            (: d (st 'd + 1) _ (pin st 'd d, pin st 'l (x . st 'l), pin Nn x d, pin F x (f0 x))
               _ (map (y \ (: _ (peep Nn y 0 = 0 ? (trav y) ())
                              (pin Nn x (min (Nn x) (Nn y)), pin F x (F x | F y))))
                      (rel x))
               (Nn x = d ?
                  (: (pop _) (: z <(st 'l)
                                _ (pin st 'l >(st 'l), pin st 'd (st 'd - 1), pin Nn z inf, pin F z (F x))
                                (z = x ? () (pop 0)))
                     (pop 0))
                  ()))
           _ (map (x \ (peep Nn x 0 = 0 ? (trav x) ())) xs)
           F)
       Rd (digraph rd dr)
       Fo (digraph (k \ peep inc k ()) Rd)
       (la q r) (foldl (a \ k \ a | Fo k) 0 (peep lb [q r] ()))
       ; -- the actions, conflicts settled as yacc settles them --
       cf {} _ (pin cf 'sr 0, pin cf 'rr 0, pin cf 'l ())
       (clash s t k) (pin cf k (cf k + 1), pin cf 'l ([s t k] . cf 'l))
       (row s)
        (: e {}
           _ (map (t \ (t < T ? (pin e t ['s (tr [s t])]) ())) (sy s))
           (red r t)
            (peep e t () @
               () (pin e t ['r r])
               ('s _) (: rp (rpr r) tp (peep pre t ())
                         (? (rp && tp) (? (rp > tp) (pin e t ['r r]) (rp < tp) ()
                                          (asc rp = 'left) (pin e t ['r r])
                                          (asc rp = 'nonassoc) (pin e t ['x])
                                          ())
                            (clash s t 'sr)))
               ('r r2) (: _ (clash s t 'rr) (r < r2 ? (pin e t ['r r]) ()))
               ())
           _ (map (i \ (: r (i >> 7)
                          (af i < 0 && r > 0 ? (la s r @ m (map (t \ ((m >> t) & 1 ? (red r t) ())) (jot T))) ())))
                  (cl s))
           ts (sort (keys e))
           reds (filter (t \ <(e t) = 'r) ts)
           cn {} _ (map (t \ (<>(e t) @ r (pin cn r (1 + peep cn r 0)))) reds)
           ; a state that shifts error reduces by no default, so an error is seen where it stands
           et (peep G 'errtok -1)
           best (et >= 0 && (peep e et () @ ('s _) 1 ()) ? -1
                   (foldl (b \ r \ (b < 0 || cn r > cn b || cn r = cn b && r < b ? r b)) -1 (keys cn)))
           [(best < 0 ? 0 (best + 1))
            (catmap (t \ (e t @ ('s q) [[t q]] ('r r) (r = best ? () [[t (32768 + r)]]) ('x) [[t 0]] ())) ts)])
       rows (map row ss)
       ; the gotos by name: the commonest target is the default
       gts (map (j \ (: A (T + j)
                        es (catmap (s \ (peep tr [s A] -1 @ q (q >= 0 ? [[s q]] ()))) ss)
                        cn {} _ (map (e \ pin cn <>e (1 + peep cn <>e 0)) es)
                        best (foldl (b \ q \ (b < 0 || cn q > cn b || cn q = cn b && q < b ? q b)) -1 (keys cn))
                        [(best < 0 ? 0 best) (filter (e \ <>e != best) es)]))
                (jot N))
       ac (yacc-comb (map (s \ [s <>(rows s)]) ss))
       gc (yacc-comb (map (j \ [j <>(gts j)]) (jot N)))
       (w16 l) (catmap (v \ [(v & 255) (v >> 8)]) l)
       tab (string (w16 ([T N S R #<>ac #<>gc] + map (r \ lhs r - T) (jot R) + map (r \ #(rhs r)) (jot R) +
                        map (r \ <r) rows + <ac + map (g \ <g) gts + <gc + <>ac + ac 2 + <>gc + gc 2)))
       [tab (cf 'sr) (cf 'rr) (rev (cf 'l)) S (map (s \ peep stos s 0) ss)])
   ; rows ((id ((col val)..))..) -> (bases vals checks): row id's col at bases[id] + col where
   ; checks holds id; a row with nothing is based at 65535
   (yacc-comb rows)
    (: occ {} val {} base {} m {} _ (pin m 'lo 0, pin m 'n 0)
       order (sort (map (r \ [(0 - #<>r) <r <>r]) rows))
       (fits b es) (all (e \ !(peep occ (b + <e) ())) es)
       _ (map (o \ (: id <>o es <>>o
                      (? !(two? es) (pin base id 65535)
                         (: (try b) (fits b es ? b (try (b + 1)))
                            b (try (max 0 (m 'lo - <<es)))
                            _ (map (e \ (pin occ (b + <e) (id + 1), pin val (b + <e) <>e)) es)
                            (lo k) (peep occ k () ? (lo (k + 1)) k)
                            _ (pin m 'lo (lo (m 'lo)), pin m 'n (max (m 'n) (b + <<(rev es) + 1)))
                            (pin base id b)))))
              order)
       n (m 'n)
       [(map (r \ base <r) rows) (map (k \ peep val k 0) (jot n)) (map (k \ peep occ k 0 @ c (c ? (c - 1) 65535)) (jot n))])
   ; -> (tables gram) | why; gram carries 'sr 'rr and 'clashes ((state terminal kind)..)
   (yacc-scan txt) (trap (_ \ (: G (yacc-gram (yacc-words txt)) L (yacc-lalr G)
                                 _ (pin G 'sr (L 1), pin G 'rr (L 2), pin G 'clashes (L 3), pin G 'S (L 4), pin G 'stos (L 5))
                                 [<L G]))
                         () (\ a b (a @ 'yacc-err b (scare a b))))
   ; -- the run: lr.c's walk, its log of reductions played back through the actions --
   yacc-c0 (string [0 0 0 0 1 0 0 0 0 0])
   (yacc-u32 s o) (s o + 256 * s (o + 1) + 65536 * s (o + 2) + 16777216 * s (o + 3))
   (yacc-run t acts ks vs ps need) (yacc-runv t acts ks vs ps need cap)
   ; ..each shifted token's value tv of its tail of vs: a parser whose actions read tokens on
   (yacc-runv t acts ks vs ps need tv)
    (: run (cite 'lr 'run)
       R (t 6 + 256 * t 7)
       (rlen r) (: o (12 + 2 * R + 2 * r) (t o + 256 * t (o + 1)))
       (feed vl i p st) (? (i < p) (feed >vl (i + 1) p (tv vl . st)) [vl st])
       (pop st n acc) (n ? (pop >st (n - 1) (<st . acc)) [st acc])
       (play c o k vl i st)
        (? (k = 0) [vl i st]
           (: r (c o + 256 * c (o + 1)) p (yacc-u32 c (o + 2))
              (feed vl i p st @ [vl2 st2]
                 (pop st2 (rlen r) () @ [st3 args]
                    (play c (o + 6) (k - 1) vl2 p ((peep acts r () @ f (f ? (f ps args) <args)) . st3))))))
       (go c look vl i st)
        (run t ks c look @ c2
           (? !(string? c2) ['err -1]
              (: o (8 + 2 * yacc-u32 c2 4) z (c2 o) pos (yacc-u32 c2 0)
                 (play c2 (o + 5) (yacc-u32 c2 (o + 1)) vl i st @ [vl2 i2 st2]
                    (? (z = 0) (go c2 65535 vl2 i2 st2)
                       (z = 1) ['ok <st2]
                       (z = 3) (go c2 (need ps pos) vl2 i2 st2)
                       ['err pos])))))
       (go yacc-c0 65535 vs 0 ()))
   ; -- love yacc: the tables and actions as love text --
   (yacc-acts G)
    (: p (peep G 'param "yy")
       (dollars s n)
        (: k #s
           (go i acc) (? (k <= i) (join "" (rev acc))
                         (s i = 36 && i + 1 < k && yacc-dig? (s (i + 1)))
                          (: (de j) (j < k && yacc-dig? (s j) ? (de (j + 1)) j)
                             j (de (i + 1)) v (foldl (a \ q \ 10 * a + s q - 48) 0 (map (+ (i + 1)) (jot (j - i - 1))))
                             (0 < v <= n ? (go j (("_" + show v) . acc)) (yacc-die ("$" + show v + " past the rule's " + show n))))
                         (s i = 36) (yacc-die "not yet: $$ or $<tag>")
                         (go (i + 1) ((string [(s i)]) . acc)))
           (go 0 ()))
       rs (G 'rules)
       (foldl (a \ k \ (rs k @ r
                          (r 2 ? (a + [("      " + show k + " (\\ " + p + " [" + join " " (map (v \ "_" + show v) (map (+ 1) (jot #<>r))) +
                                        "] (" + yacc-trim (dollars (r 2) #<>r) + "))")])
                             a)))
              () (jot #rs)))
   (yacc-trim s) (lex-trim s)
   (yacc-hex s) (join "" (map (i \ lex-hex (s i)) (jot #s)))
   (yacc-text mod nm spec G tab)
    ("; generated by `love yacc " + spec + "`; edit the spec, not this\n(module '" + mod + "\n(:\n" +
     join "" (map (h \ h + "\n") (peep G 'head () + peep G 'post ())) +
     "   " + nm + " \"" + yacc-hex tab + "\"\n" +
     "   " + nm + "-terms '(" + join " " (map show (G 'terms)) + ")\n" +
     "   " + nm + "-acts {\n" + join "\n" (yacc-acts G) + "}\n" +
     (G 'tail ? (G 'tail + "\n") "") + "))\n")
   ; -- yacc -o X.c --defines=X.h: the C parser, as bison lays one --
   (yacc-ctag G x) (: T (G 'T) (peep (G 'tags) (x < T ? ((G 'terms) x) ((G 'nts) (x - T))) ()))
   ; an action's $$ $n $<t>n @$ @n as C: dd and ll stand for $$ and @$, lt is $$'s tag
   (yacc-csub G s rhs lt dd ll)
    (: k #s n #rhs un (peep G 'union ())
       (fld tg) (un && tg ? ("." + tg) "")
       (dnum i) (: neg (i < k && s i = 45) j0 (neg ? (i + 1) i)
                   (de j) (j < k && yacc-dig? (s j) ? (de (j + 1)) j)
                   j (de j0)
                   (j > j0 ? [((neg ? -1 1) * foldl (a \ q \ 10 * a + s q - 48) 0 (map (+ j0) (jot (j - j0)))) j] ()))
       (at v) ("[(" + show v + ") - (" + show n + ")]")
       (lit i q) (? (k <= i) i (s i = 92) (lit (i + 2) q) (s i = q) (i + 1) (lit (i + 1) q))
       (upto i a b) (? (k <= i + 1) k (s i = a && s (i + 1) = b) (i + 2) (upto (i + 1) a b))
       (eol i) (i < k && s i != 10 ? (eol (i + 1)) i)
       (go i j acc)
        (: (cut2 e x) (go e e (x . snip s j i . acc))
           (? (k <= i) (join "" (rev (snip s j k . acc)))
              (: c (s i) d (i + 1 < k ? (s (i + 1)) 0)
                 (? (c = 34 || c = 39) (: e (lit (i + 1) c) (go e j acc))
                    (c = 47 && d = 42) (go (upto (i + 2) 42 47) j acc)
                    (c = 47 && d = 47) (go (eol i) j acc)
                    (c = 36 && d = 36) (cut2 (i + 2) ("(" + dd + fld lt + ")"))
                    (c = 36 && d = 60)
                     (: (gt q) (q < k && s q != 62 ? (gt (q + 1)) q)
                        e (gt (i + 2)) tg (snip s (i + 2) e)
                        (e + 1 < k && s (e + 1) = 36 ? (cut2 (e + 2) ("(" + dd + "." + tg + ")"))
                           (dnum (e + 1) @ [v q] (cut2 q ("(yyvsp" + at v + "." + tg + ")"))
                              (yacc-die ("a $<" + tg + "> wants $ or a number")))))
                    (c = 36) (dnum (i + 1) @
                               [v q] (0 < v <= n ? (cut2 q ("(yyvsp" + at v + fld (yacc-ctag G (rhs (v - 1))) + ")"))
                                        (un ? (yacc-die ("$" + show v + " wants a <tag>")) (cut2 q ("(yyvsp" + at v + ")"))))
                               (go (i + 1) j acc))
                    (c = 64 && d = 36) (cut2 (i + 2) ("(" + ll + ")"))
                    (c = 64) (dnum (i + 1) @ [v q] (cut2 q ("(yylsp" + at v + ")")) (go (i + 1) j acc))
                    (go (i + 1) j acc)))))
       (go 0 0 ()))
   (yacc-cguard f) ("YY_YY_" + string (map (c \ (97 <= c <= 122 ? (c - 32) (yacc-idc? c && c != 46 ? c 95))) (f @ x (map x (jot #x)))) + "_INCLUDED")
   (yacc-chead G hf dbg)
    (: T (G 'T) ext (G 'ext) un (peep G 'union ()) g (yacc-cguard hf)
       named (filter (t \ ext t >= 258) (jot T))
       ("#ifndef " + g + "\n# define " + g + "\n#ifndef YYDEBUG\n# define YYDEBUG " + (dbg ? "1" "0") + "\n#endif\n"
        + "#if YYDEBUG\nextern int yydebug;\n#endif\n#ifndef YYTOKENTYPE\n# define YYTOKENTYPE\n  enum yytokentype\n  {\n"
        + "    YYEMPTY = -2,\n    YYEOF = 0,\n    YYerror = 256,\n    YYUNDEF = 257"
        + join "" (map (t \ ",\n    " + (G 'terms) t + " = " + show (ext t)) named)
        + "\n  };\n  typedef enum yytokentype yytoken_kind_t;\n#endif\n"
        + "#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED\n"
        + (un ? ("union YYSTYPE\n{" + un + "};\ntypedef union YYSTYPE YYSTYPE;\n# define YYSTYPE_IS_TRIVIAL 1\n")
              "typedef int YYSTYPE;\n")
        + "# define YYSTYPE_IS_DECLARED 1\n#endif\nextern YYSTYPE yylval;\n"
        + (peep G 'locs () ?
            ("#if ! defined YYLTYPE && ! defined YYLTYPE_IS_DECLARED\ntypedef struct YYLTYPE YYLTYPE;\n"
             + "struct YYLTYPE\n{\n  int first_line;\n  int first_column;\n  int last_line;\n  int last_column;\n};\n"
             + "# define YYLTYPE_IS_DECLARED 1\n# define YYLTYPE_IS_TRIVIAL 1\n#endif\nextern YYLTYPE yylloc;\n")
            "")
        + "int yyparse (void);\n#endif /* !" + g + " */\n"))
   yacc-cdrv """
      #define YYACCEPT goto yyacceptlab
      #define YYABORT goto yyabortlab
      #define YYERROR goto yyerrorlab
      #define YYNOMEM goto yyexhaustedlab
      #define yyerrok (yyerrstatus = 0)
      #define yyclearin (yychar = YYEMPTY)
      #define YYRECOVERING() (!!yyerrstatus)
      #define YYRHSLOC(Rhs, K) ((Rhs)[K])
      #ifndef YYLLOC_DEFAULT
      # define YYLLOC_DEFAULT(Current, Rhs, N) do if (N) { \
          (Current).first_line = YYRHSLOC(Rhs, 1).first_line; (Current).first_column = YYRHSLOC(Rhs, 1).first_column; \
          (Current).last_line = YYRHSLOC(Rhs, N).last_line; (Current).last_column = YYRHSLOC(Rhs, N).last_column; \
        } else { \
          (Current).first_line = (Current).last_line = YYRHSLOC(Rhs, 0).last_line; \
          (Current).first_column = (Current).last_column = YYRHSLOC(Rhs, 0).last_column; \
        } while (0)
      #endif
      int yychar;
      int yynerrs;
      YYSTYPE yylval;
      #if YYDEBUG
      int yydebug;
      #endif
      """
   ; the walk lr.c takes, with bison's value and location stacks, error recovery and destructors
   yacc-crun """
      int yyparse(void)
      {
        long yycap = 200;
        short *yyss = malloc(yycap * sizeof *yyss), *yyssp;
        YYSTYPE *yyvs = malloc(yycap * sizeof *yyvs), *yyvsp;
        YY_LOC *yyls = malloc(yycap * sizeof *yyls), *yylsp;
        int yyerrstatus = 0, yytoken = 0, yylen = 0, yyresult, yya, yyn;
        YYSTYPE yyval;
        YY_LOC yyloc, yyerr_range[3];
        yychar = YYEMPTY;
        yynerrs = 0;
        if (!yyss || !yyvs || !yyls) {
          yyerror("memory exhausted");
          free(yyss), free(yyvs), free(yyls);
          return 2;
        }
        yyssp = yyss, yyvsp = yyvs, yylsp = yyls;
        *yyssp = 0;
        memset(yyvsp, 0, sizeof *yyvsp);
        *yylsp = YY_LLOC;
      yynewstate:
        if (yyssp - yyss + 2 >= yycap) {
          long yyd = yyssp - yyss;
          short *yys2;
          YYSTYPE *yyv2 = 0;
          YY_LOC *yyl2 = 0;
          yycap *= 2;
          if ((yys2 = realloc(yyss, yycap * sizeof *yyss))) yyss = yys2;
          if (yys2 && (yyv2 = realloc(yyvs, yycap * sizeof *yyvs))) yyvs = yyv2;
          if (yyv2 && (yyl2 = realloc(yyls, yycap * sizeof *yyls))) yyls = yyl2;
          yyssp = yyss + yyd, yyvsp = yyvs + yyd, yylsp = yyls + yyd;
          if (!yyl2) goto yyexhaustedlab;
        }
        {
          int yys = *yyssp, yyi;
          yya = yy_dflt[yys] ? 0x8000 + yy_dflt[yys] - 1 : 0;
          if (yy_abase[yys] != 0xffff) {
            if (yychar == YYEMPTY) yychar = yylex();
            if (yychar <= YYEOF) yychar = YYEOF, yytoken = 0;
            else yytoken = yychar < YY_NTRANS ? yy_trans[yychar] : YY_NTOKENS;
            yyi = yy_abase[yys] + yytoken;
            if (yytoken < YY_NTOKENS && yyi < YY_AN && yy_achk[yyi] == yys) yya = yy_atab[yyi];
          }
        }
        if (!yya) goto yyerrlab;
        if (yya < 0x8000) {
          if (!yytoken) YYACCEPT;
          if (yyerrstatus) yyerrstatus--;
          *++yyssp = yya, *++yyvsp = yylval, *++yylsp = YY_LLOC;
          yychar = YYEMPTY;
          goto yynewstate;
        }
        yyn = yya - 0x8000;
        yylen = yy_rlen[yyn];
        if (yylen) yyval = yyvsp[1 - yylen];
        else memset(&yyval, 0, sizeof yyval);
        YYLLOC_DEFAULT(yyloc, (yylsp - yylen), yylen);
        switch (yyn) {
      """
   yacc-cend """
        default: break;
        }
        yyssp -= yylen, yyvsp -= yylen, yylsp -= yylen, yylen = 0;
        *++yyvsp = yyval, *++yylsp = yyloc;
        {
          int yyA = yy_rlhs[yyn], yyi = yy_gbase[yyA] + *yyssp;
          yyssp[1] = yyi < YY_GN && yy_gchk[yyi] == yyA ? yy_gtab[yyi] : yy_gdef[yyA];
          yyssp++;
        }
        goto yynewstate;
      yyerrlab:
        if (!yyerrstatus) {
          ++yynerrs;
          yyerror("syntax error");
        }
        yyerr_range[1] = YY_LLOC;
        if (yyerrstatus == 3) {
          if (yychar <= YYEOF) {
            if (yychar == YYEOF) YYABORT;
          } else {
            yydestruct(yytoken, &yylval, &YY_LLOC);
            yychar = YYEMPTY;
          }
        }
        goto yyerrlab1;
        if (0) YYERROR;
      yyerrorlab:
        ++yynerrs;
        yyerr_range[1] = yylsp[1 - yylen];
        yyssp -= yylen, yyvsp -= yylen, yylsp -= yylen, yylen = 0;
      yyerrlab1:
        yyerrstatus = 3;
        for (;;) {
          int yys = *yyssp, yyi;
          if (YY_ERRTOK >= 0 && yy_abase[yys] != 0xffff) {
            yyi = yy_abase[yys] + YY_ERRTOK;
            if (yyi < YY_AN && yy_achk[yyi] == yys && yy_atab[yyi] && yy_atab[yyi] < 0x8000) {
              yya = yy_atab[yyi];
              break;
            }
          }
          if (yyssp == yyss) YYABORT;
          yyerr_range[1] = *yylsp;
          yydestruct(yy_stos[yys], yyvsp, yylsp);
          yyssp--, yyvsp--, yylsp--;
        }
        yyerr_range[2] = YY_LLOC;
        YYLLOC_DEFAULT(yyloc, yyerr_range, 2);
        *++yyssp = yya, *++yyvsp = yylval, *++yylsp = yyloc;
        goto yynewstate;
      yyacceptlab:
        yyresult = 0;
        goto yyreturnlab;
      yyabortlab:
        yyresult = 1;
        goto yyreturnlab;
      yyexhaustedlab:
        yyerror("memory exhausted");
        yyresult = 2;
      yyreturnlab:
        if (yychar != YYEMPTY) yydestruct(yytoken, &yylval, &YY_LLOC);
        yyssp -= yylen, yyvsp -= yylen, yylsp -= yylen;
        while (yyssp != yyss) {
          yydestruct(yy_stos[*yyssp], yyvsp, yylsp);
          yyssp--, yyvsp--, yylsp--;
        }
        free(yyss), free(yyvs), free(yyls);
        return yyresult;
      }
      """
   (yacc-cout f G tab hf dbg)
    (: T (G 'T) N (G 'N) rs (G 'rules) ext (G 'ext) locs (peep G 'locs ())
       u (map (i \ tab (2 * i) + 256 * tab (2 * i + 1)) (jot (#tab // 2)))
       R (u 3) S (u 2) AN (u 4) GN (u 5)
       (part o m) (take m (drop o u))
       o1 (6 + 2 * R) o2 (o1 + 2 * S) o3 (o2 + 2 * N) o4 (o3 + 2 * AN)
       ; a token's number back to its symbol; an unknown one is past the terminals
       inv {} _ (pin inv 0 0, map (t \ pin inv (ext t) t) (drop 1 (jot T)))
       mx (foldl (a \ t \ max a (ext t)) 256 (drop 1 (jot T)))
       tr (map (c \ peep inv c T) (jot (mx + 1)))
       hd (yacc-chead G hf dbg)
       (sub r a lt dd ll) (yacc-csub G a (r 1) lt dd ll)
       acts (catmap (k \ (rs k @ r
                          (r 2 ? [("  case " + show k + ":\n    {" + sub r (r 2) (yacc-ctag G <r) "yyval" "yyloc" + "}\n    break;\n")] ())))
                    (drop 1 (jot #rs)))
       ; a %destructor's symbols: names, <tag>s, <*> any tagged, <> the untagged
       syms (jot (T + N))
       (dsyms ts) (catmap (w \ (? (<w = 'tag) (filter (x \ yacc-ctag G x @ tg (<>w = "*" ? tg (<>w = "" ? !tg (tg = <>w)))) syms)
                                  (<w = 'ch) (filter (x \ x < T && (G 'terms) x = (string [39 <>w 39])) syms)
                                  (filter (x \ (x < T ? ((G 'terms) x) ((G 'nts) (x - T))) = <>w) syms)))
                         ts)
       dcase (catmap (d \ map (x \ "    case " + show x + ":\n      {" + yacc-csub G <d () (yacc-ctag G x) "(*yyvaluep)" "(*yylocationp)" + "}\n      break;\n")
                              (dsyms <>d))
                     (peep G 'dtors ()))
       ("/* generated by `love yacc " + f + "`; edit the spec, not this */\n"
        + join "\n" (peep G 'head ()) + "\n" + hd + join "\n" (peep G 'post ()) + "\n"
        + "#include <stdlib.h>\n#include <string.h>\n"
        + "#define YY_NTOKENS " + show T + "\n#define YY_NTRANS " + show (mx + 1) + "\n#define YY_AN " + show AN
        + "\n#define YY_GN " + show GN + "\n#define YY_ERRTOK " + show (peep inv 256 -1) + "\n"
        + lex-carr "unsigned short" "yy_trans" tr
        + lex-carr "unsigned short" "yy_rlhs" (part 6 R)
        + lex-carr "unsigned short" "yy_rlen" (part (6 + R) R)
        + lex-carr "unsigned short" "yy_dflt" (part o1 S)
        + lex-carr "unsigned short" "yy_abase" (part (o1 + S) S)
        + lex-carr "unsigned short" "yy_gdef" (part o2 N)
        + lex-carr "unsigned short" "yy_gbase" (part (o2 + N) N)
        + lex-carr "unsigned short" "yy_atab" (part o3 AN)
        + lex-carr "unsigned short" "yy_achk" (part (o3 + AN) AN)
        + lex-carr "unsigned short" "yy_gtab" (part o4 GN)
        + lex-carr "unsigned short" "yy_gchk" (part (o4 + GN) GN)
        + lex-carr "unsigned short" "yy_stos" (G 'stos)
        + (locs ? "#define YY_LOC YYLTYPE\n#define YY_LLOC yylloc\nYYLTYPE yylloc\n# if defined YYLTYPE_IS_TRIVIAL && YYLTYPE_IS_TRIVIAL\n  = { 1, 1, 1, 1 }\n# endif\n;\n"
                 "typedef struct { int first_line, first_column, last_line, last_column; } yy_loc_t;\n#define YY_LOC yy_loc_t\nstatic yy_loc_t yy_noloc;\n#define YY_LLOC yy_noloc\n")
        + yacc-cdrv + "\n"
        + "static void yydestruct(int yysym, YYSTYPE *yyvaluep, YY_LOC *yylocationp)\n{\n  (void) yyvaluep, (void) yylocationp;\n  switch (yysym) {\n"
        + join "" dcase + "    default: break;\n  }\n}\n"
        + yacc-crun + "\n" + join "" acts + yacc-cend + "\n"
        + (G 'tail ? (G 'tail + "\n") "")))
   ; love yacc -o X.c [--defines=X.h | -d] [-t] [-l] SPEC: the C parser and its header
   (yacc-cmain as)
    (: (go a o h d) (? !(two? a) (udie 2 "usage: yacc -o FILE [--defines=FILE] [-t] [-l] SPEC")
                       (<a = "-l" || <a = "-v" || <a = "-y") (go >a o h d)
                       (<a = "-t") (go >a o h 1)
                       (<a = "-d") (go >a o (h || 1) d)
                       (<a = "-o" && two? >a) (go >>a <>a h d)
                       (lex-pre? <a "--defines=") (go >a o (snip <a 10 #<a) d)
                       (lex-pre? <a "--header=") (go >a o (snip <a 9 #<a) d)
                       (lex-pre? <a "-o") (go >a (snip <a 2 #<a) h d)
                       (two? >a) (udie 2 ("yacc: unknown option " + <a))
                       [<a o h d])
       r0 (go as () () ())
       f <r0
       (cut x t) (#t <= #x && snip x (#x - #t) #x = t ? snip x 0 (#x - #t) x)
       oc (r0 1 || cut f ".y" + ".tab.c")
       hf (r0 2 @ h (charm? h ? (cut oc ".c" + ".h") h))
       r (yacc-scan (uread f @ x (two? x ? <>x (udie 1 ("yacc: can't read " + f)))))
       _ (string? r ? (udie 1 ("yacc: " + f + ": " + r)) ())
       G <>r
       _ (G 'rr || G 'sr != peep G 'expect 0 ?
            (say err ("yacc: " + f + ": " + show (G 'sr) + " shift/reduce, " + show (G 'rr) + " reduce/reduce conflicts\n")) ())
       c (trap (_ \ yacc-cout f G <r (hf || "") (r0 3)) () (\ a b (a @ 'yacc-err b (scare a b))))
       _ (string? c && lex-pre? c "/* generated" ? () (udie 1 ("yacc: " + f + ": " + show c)))
       (put fo t) (open fo "w" @ q (hot? q ? (say q t, close q) (udie 1 ("yacc: can't write " + fo))))
       _ (put oc c)
       _ (hf ? (put hf ("/* generated by `love yacc " + f + "`; edit the spec, not this */\n" + yacc-chead G hf (r0 3))) ())
       0)
   (yacc-main as)
    (? (any (a \ a = "-t" || a = "-d" || a = "-l" || lex-pre? a "-o" || lex-pre? a "--defines" || lex-pre? a "--header") as) (yacc-cmain as)
    (: (opts a m n) (? (two? a && two? >a && <a = "-m") (opts >>a <>a n)
                       (two? a && two? >a && <a = "-n") (opts >>a m <>a)
                       [a m n])
       o (opts as "moon" "yacc-tab")
       f <<o
       _ (two? <o && !(two? ><o) ? () (udie 2 "usage: yacc [-m MODULE] [-n NAME] SPEC"))
       r (yacc-scan (uread f @ x (two? x ? <>x (udie 1 ("yacc: can't read " + f)))))
       _ (string? r ? (udie 1 ("yacc: " + f + ": " + r)) ())
       G <>r
       _ (G 'rr || G 'sr != peep G 'expect 0 ?
            (say err ("yacc: " + f + ": " + show (G 'sr) + " shift/reduce, " + show (G 'rr) + " reduce/reduce conflicts\n")) ())
       _ (say out (yacc-text <>o <>>o f G <r))
       0))
))
