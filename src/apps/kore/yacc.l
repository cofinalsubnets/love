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
; a spec: declarations (%token %left %right %nonassoc %start %expect %param, %{ text %}), %%,
; rules (name : symbols {action} | .. ;), and an optional %% before text laid after the tables.
; not yet: the error token, mid-rule actions, $$ and $<tag>, string-literal tokens.
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
                                (j < n && s j = 62 ? (go (j + 1) ln m acc) (yacc-die ("an open <tag>" + yacc-at ln))))
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
    (: G {} tn {} pr {} asc {}
       _ (pin G 'tl ["$end"], pin tn "$end" 0, pin G 'prec pr, pin G 'assoc asc)
       (tname w) (<w = 'ch ? (32 < <>w < 127 ? (string [39 <>w 39]) ("'\\" + show <>w + "'")) <>w)
       (term w) (: nm (tname w)
                   (peep tn nm -1 @ k (k >= 0 ? k (: k2 #(G 'tl) (pin G 'tl (G 'tl + [nm]), pin tn nm k2, k2)))))
       (syms ws f) (? (two? ws && elem <<ws '(id ch tag num))
                       (: _ (elem <<ws '(id ch) ? (f <ws) ()) (syms >ws f))
                      ws)
       (one ws k what) (two? >ws && <<>ws = k ? <><>ws (yacc-die (what + yacc-at (<ws 2))))
       (decl ws lv)
        (? !(two? ws) (yacc-die "no %% before the rules")
           (<ws @ w
              (? (<w = 'mark) >ws
                 (<w = 'text) (: _ (pin G 'head (peep G 'head () + [<>w])) (decl >ws lv))
                 (<w != 'dir) (yacc-die ("a stray " + yacc-wshow w + yacc-at (w 2)))
                 (<>w @ d
                    (? (d = "token") (decl (syms >ws term) lv)
                       (elem d '("left" "right" "nonassoc"))
                        (: l2 (lv + 1)
                           _ (pin asc l2 (d = "left" ? 'left (d = "right" ? 'right 'nonassoc)))
                           (decl (syms >ws (x \ pin pr (term x) l2)) l2))
                       (d = "start") (: _ (pin G 'start (one ws 'id "%start wants a name")) (decl >>ws lv))
                       (d = "expect") (: _ (pin G 'expect (one ws 'num "%expect wants a number")) (decl >>ws lv))
                       (d = "param") (: _ (pin G 'param (one ws 'id "%param wants a name")) (decl >>ws lv))
                       (d = "type") (decl (syms >ws (_ \ ())) lv)
                       (d = "union") (decl (two? >ws && <<>ws = 'act ? >>ws >ws) lv)
                       (yacc-die ("not yet: %" + d)))))))
       ; the rules as written: (name (word..) action precword line)
       (rule? ws) (two? ws && <<ws = 'id && two? >ws && <<>ws = 'colon)
       (midact ln) (yacc-die ("not yet: an action mid-rule" + yacc-at ln))
       (alt ws lhs sy act pw ln acc)
        (: done ([lhs (rev sy) act pw ln] . acc)
           (? (!(two? ws) || rule? ws || <<ws = 'mark) [ws done]
              (<ws @ w
                 (? (<w = 'bar) (alt >ws lhs () () () (w 2) done)
                    (<w = 'semi) [>ws done]
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
       _ (map (r \ map (w \ (<w = 'ch ? (term w) ())) <>r) rl)
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
           best (foldl (b \ r \ (b < 0 || cn r > cn b || cn r = cn b && r < b ? r b)) -1 (keys cn))
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
       [tab (cf 'sr) (cf 'rr) (rev (cf 'l)) S])
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
                                 _ (pin G 'sr (L 1), pin G 'rr (L 2), pin G 'clashes (L 3), pin G 'S (L 4))
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
     join "" (map (h \ h + "\n") (peep G 'head ())) +
     "   " + nm + " \"" + yacc-hex tab + "\"\n" +
     "   " + nm + "-terms '(" + join " " (map show (G 'terms)) + ")\n" +
     (G 'tail ? (G 'tail + "\n") "") +
     "   " + nm + "-acts {\n" + join "\n" (yacc-acts G) + "}\n))\n")
   (yacc-main as)
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
       0)
))
