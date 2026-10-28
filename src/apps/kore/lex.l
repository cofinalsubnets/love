; src/apps/kore/lex.l -- lex: a flex-shaped scanner spec -> a minimal DFA over byte classes, as one
; table string dfa.c's (run t s i) walks. each rule's NFA is the one regex engine's own program
; (moonlibc's regcomp, byte mode, extended syntax), read back off the block it lays.
;   (lex-scan spec)        -> (tables rules) | a string saying why not
;   (lex-next t src i)     -> (rule end), the longest match at i (the earliest rule on a tie) | ()
;   love lex [-m MODULE] [-n NAME] SPEC   the tables as love text, NAME bound in MODULE's block
; a spec: definitions (NAME pattern), %%, rules (a pattern, then its action to the line's end),
; and an optional %% after. a rule's action here is a word: the rules list answers them in order.
; patterns read as flex's: "quoted", {NAME}, [classes] with \n-style escapes, . short of a newline.
; not yet: start conditions, ^ and $ anchors, r/s trailing context.
(module 'kore
(borrow 'cli)
(borrow 'posix)
(:
   lex-meta ".[]()*+?{}|^$\\"
   (lex-die m) (scare 'lex-err m)
   (lex-sp? c) (c = 32 || c = 9)
   (lex-name? c) (97 <= c <= 122 || 65 <= c <= 90 || c = 95 || 48 <= c <= 57 || c = 45)
   (lex-trim s)
    (: n #s
       (a i) (i < n && lex-sp? (s i) ? (a (i + 1)) i)
       (b j) (j > a 0 && lex-sp? (s (j - 1)) ? (b (j - 1)) j)
       (snip s (a 0) (b n)))
   ; -- the spec --
   ; a pattern's end: the first blank outside quotes and brackets. b is () outside a bracket, 2
   ; just inside it (a ']' or '^' there is a member), 1 further in
   (lex-pend s)
    (: n #s
       (go i q b) (? (n <= i) i
                     (s i @ c
                        (? (c = 92) (go (i + 2) q (b && 1))
                           q (go (i + 1) (c != 34) b)
                           (b = 2) (go (i + 1) q (c = 94 ? 2 1))
                           (b && c = 93) (go (i + 1) q ())
                           b (go (i + 1) q b)
                           (c = 34) (go (i + 1) 1 b)
                           (c = 91) (go (i + 1) q 2)
                           (lex-sp? c) i
                           (go (i + 1) q b))))
       (go 0 () ()))
   ; -> (defs rules): defs ((name pattern) ..), rules ((pattern action) ..). a blank-led line, a
   ; %-line and a ;-line are no definition; a blank-led line is no rule
   (lex-spec txt)
    (: (sect l) (? !(two? l) [() ()]
                   (<l = "%%") [() >l]
                   (sect >l @ r [(<l . <r) <>r]))
       s1 (sect (split "\n" txt))
       s2 (sect <>s1)
       (defs l acc) (? !(two? l) (rev acc)
                       (<l @ x
                          (? (#x = 0 || lex-sp? (x 0) || x 0 = 37 || x 0 = 59) (defs >l acc)
                             (: (nm i) (i < #x && lex-name? (x i) ? (nm (i + 1)) i)
                                k (nm 0)
                                (defs >l ([(snip x 0 k) (lex-trim (snip x k #x))] . acc))))))
       (rules l acc) (? !(two? l) (rev acc)
                        (<l @ x
                           (? (#x = 0 || lex-sp? (x 0)) (rules >l acc)
                              (lex-pend x @ e (rules >l ([(snip x 0 e) (lex-trim (snip x e #x))] . acc))))))
       (two? <>s1 ? [(defs <s1 ()) (rules <s2 ())] (lex-die "no %% before the rules")))
   ; -- a flex pattern -> the ERE text regcomp reads, byte for byte --
   (lex-lit c) (? (c = 0) (lex-die "a nul byte in a pattern")
                  (elem c (map lex-meta (jot #lex-meta))) (string [92 c])
                  (string [c]))
   (lex-hexd? d) (48 <= d <= 57 || 97 <= d <= 102 || 65 <= d <= 70)
   (lex-hexv d) (d <= 57 ? (d - 48) (d <= 70 ? (d - 55) (d - 87)))
   ; at the char past a backslash -> (byte next)
   (lex-esc s i)
    (? (#s <= i) (lex-die "a pattern ends in a backslash")
       (s i @ c
          (? (c = 110) [10 (i + 1)] (c = 116) [9 (i + 1)] (c = 114) [13 (i + 1)]
             (c = 102) [12 (i + 1)] (c = 118) [11 (i + 1)] (c = 97) [7 (i + 1)] (c = 98) [8 (i + 1)]
             (c = 120) (: (hx k v m) (m < 2 && k < #s && lex-hexd? (s k) ? (hx (k + 1) (16 * v + lex-hexv (s k)) (m + 1)) [v k])
                          (hx (i + 1) 0 0))
             (48 <= c <= 55) (: (oc k v m) (m < 3 && k < #s && 48 <= s k <= 55 ? (oc (k + 1) (8 * v + s k - 48) (m + 1)) [v k])
                                (oc i 0 0))
             [c (i + 1)])))
   ; [:name:]'s bytes, by the C locale
   (lex-posix nm)
    (: r (jot 256)
       (in a b) (filter (c \ a <= c <= b) r)
       al (in 97 122 + in 65 90) dg (in 48 57)
       pu (filter (c \ 33 <= c <= 126 && !(elem c al || elem c dg)) r)
       (? (nm = "alpha") al (nm = "digit") dg (nm = "alnum") (al + dg) (nm = "upper") (in 65 90)
          (nm = "lower") (in 97 122) (nm = "space") [9 10 11 12 13 32] (nm = "blank") [9 32]
          (nm = "punct") pu (nm = "xdigit") (dg + in 97 102 + in 65 70) (nm = "cntrl") (in 0 31 + [127])
          (nm = "print") (in 32 126) (nm = "graph") (in 33 126)
          (lex-die ("no class [:" + nm + ":]"))))
   ; a bracket at the char past '[' -> (bytes negated? next)
   (lex-br s i0)
    (: neg (i0 < #s && s i0 = 94)
       (one i) (s i = 92 ? (lex-esc s (i + 1)) [(s i) (i + 1)])
       (go i acc first)
        (? (#s <= i) (lex-die "an open bracket")
           (s i = 93 && !first) [acc neg (i + 1)]
           (s i = 91 && i + 1 < #s && s (i + 1) = 58)
            (: k (findsub (snip s i #s) ":]")
               (k < 0 ? (lex-die "an open [:") (go (i + k + 2) (acc + lex-posix (snip s (i + 2) (i + k))) ())))
           (one i @ [lo j]
              (? (j + 1 < #s && s j = 45 && s (j + 1) != 93)
                  (one (j + 1) @ [hi k]
                     (hi < lo ? (lex-die "a backward range") (go k (acc + map (+ lo) (jot (hi - lo + 1))) ())))
                 (go j (lo . acc) ()))))
       (go (neg ? (i0 + 1) i0) () 1))
   ; bytes -> a canonical bracket: ']' first, '^' not first, '-' last, no nul
   (lex-brtext bs neg)
    (: has {} _ (map (b \ pin has b 1) bs)
       _ (has 0 ? (lex-die "a nul byte in a pattern") ())
       mid (filter (b \ has b && b != 93 && b != 45 && b != 94) (map (+ 1) (jot 255)))
       _ (two? mid || has 93 || has 45 || has 94 ? () (lex-die "an empty bracket"))
       ("[" + (neg ? "^" "") + (has 93 ? "]" "") + string mid + (has 94 ? "^" "") + (has 45 ? "-" "") + "]"))
   (lex-ere defs p)
    (: n #p
       (go i acc)
        (? (n <= i) (join "" (rev acc))
           (p i @ c
              (? (c = 34) (: (q j a) (? (n <= j) (lex-die "an open quote")
                                        (p j = 34) (go (j + 1) a)
                                        (p j = 92) (lex-esc p (j + 1) @ [b k] (q k (lex-lit b . a)))
                                        (q (j + 1) (lex-lit (p j) . a)))
                             (q (i + 1) acc))
                 (c = 92) (lex-esc p (i + 1) @ [b k] (go k (lex-lit b . acc)))
                 (c = 46) (go (i + 1) ("[^\n]" . acc))
                 (c = 91) (lex-br p (i + 1) @ [bs neg j] (go j (lex-brtext bs neg . acc)))
                 (c = 123 && i + 1 < n && lex-name? (p (i + 1)) && !(48 <= p (i + 1) <= 57))
                  (: (nm j) (j < n && p j != 125 ? (nm (j + 1)) j)
                     j (nm (i + 1))
                     d (assoc (snip p (i + 1) j) defs)
                     (two? d ? (go (j + 1) (")" . <>d . "(" . acc)) (lex-die ("no definition {" + snip p (i + 1) j + "}"))))
                 (c = 47 || i = 0 && (c = 94 || c = 60) || c = 36 && i = n - 1)
                  (lex-die ("not yet: " + string [c] + " in " + p))
                 (c = 36 || c = 94) (go (i + 1) (string [92 c] . acc))      ; within, a $ or ^ is itself
                 (go (i + 1) (string [c] . acc)))))
       (go 0 ()))
   ; each definition translates seeing the ones before it
   (lex-defs ds) (foldl (acc \ d \ acc + [[<d (lex-ere acc <>d)]]) () ds)
   ; -- regcomp's program, read back: (op x y bytes) by pc. the block is a header, np instructions
   ; (op x y, and a pointer's room), then the sets: a byte map, then neg; byte mode keeps no ranges.
   ; regcomp leaves nul out of every set, its text never holding one; a scanner's does, and a
   ; negated set takes it, as flex's [^\n] does --
   (lex-i32 b o) (: v (b o + 256 * b (o + 1) + 65536 * b (o + 2) + 16777216 * b (o + 3))
                    (v < 2147483648 ? v (v - 4294967296)))
   (lex-prog e)
    (: b <(regcomp e 1)
       _ (string? b ? () (lex-die ("regcomp refuses " + e)))
       np (lex-i32 b 0) ns (lex-i32 b 4)
       _ (#b = 40 + 24 * np + 56 * ns ? () (lex-die "regcomp's program is not the block this reads"))
       (set k) (: o (40 + 24 * np + 56 * k)
                  (filter (c \ (c = 0 ? (lex-i32 b (o + 32) != 0) ((b (o + (c >> 3)) >> (c & 7)) & 1))) (jot 256)))
       sets (map set (jot ns))
       (map (pc \ (: o (40 + 24 * pc) op (lex-i32 b o) x (lex-i32 b (o + 4)) y (lex-i32 b (o + 8))
                    [op x y (op = 2 ? (sets x) ())]))
            (jot np)))
   ; -- the DFA: (classes S K trans accept rules); states 0 (dead) to S - 1, 1 the start; trans by
   ; state * K + class; accept the rule's number from 1, 0 for none --
   (lex-dfa spec)
    (: ds (lex-defs <spec)
       rs <>spec
       _ (two? rs ? () (lex-die "no rules"))
       a (lex-auto (map (r \ lex-ere ds <r) rs) [(jot #rs)])
       _ ((a 4) <(a 5) ? (lex-die "a rule matches the empty text") ())
       [<a (a 1) (a 2) (a 3) (a 4) (map (r \ <>r) rs)])
   ; EREs and start sets (lists of rule indices) -> (classes S K trans accept starts), a start
   ; per set, the first the lowest state
   ; the ops: 0 char, 1 any, 2 set, 6 split, 7 jmp, 8 save, 10 mark, 11 check, 12 match
   (lex-auto eres starts)
    (: progs (map lex-prog eres)
       bases (: (go l b acc) (two? l ? (go >l (b + #<l) (b . acc)) (rev acc)) (go progs 0 ()))
       nd {} rule {}
       _ (map (k \ map (pc \ (pin nd ((bases k) + pc) ((progs k) pc), pin rule ((bases k) + pc) (k + 1))) (jot #(progs k)))
              (jot #progs))
       N #(keys nd)
       (base i) (bases (rule i - 1))
       ; a node list's closure: the consuming nodes and the matches it reaches, sorted
       (clo l)
        (: seen {}
           (go l acc) (? !(two? l) acc
                         (seen <l) (go >l acc)
                         (: i <l f (nd i) op <f b (base i)
                            _ (pin seen i 1)
                            (? (op = 6) (go ((b + <>f) . (b + <>>f) . >l) acc)
                               (op = 7) (go ((b + <>f) . >l) acc)
                               (elem op [8 10 11]) (go ((i + 1) . >l) acc)
                               (elem op [0 1 2 12]) (go >l (i . acc))
                               (lex-die "an anchor, an assertion or a back-reference in a rule"))))
           (sort (go l ())))
       (bytes i) (nd i @ f (<f @ 0 [<>f] 1 (jot 256) 2 (f 3) ()))
       ; byte classes: the bytes no consuming node tells apart share one
       sig (: t {} _ (map (i \ (elem <(nd i) [0 1 2] ? (map (c \ pin t c (i . peep t c ())) (bytes i)) 0)) (jot N)) t)
       cid {} reps {}
       cls (map (c \ (peep sig c () @ s
                        (peep cid s -1 @ k
                           (k >= 0 ? k
                              (: k2 #(keys cid) (pin cid s k2, pin reps k2 c, k2))))))
                (jot 256))
       K #(keys cid)
       (acpt l) (foldl (a \ i \ (<(nd i) = 12 && (a = 0 || rule i < a) ? (rule i) a)) 0 l)
       ; subsets: a state is its sorted closure, numbered from 1 as reached
       sid {} sts {}
       (intern l) (? !(two? l) 0
                     (peep sid l 0 @ k (k ? k (: k2 (#(keys sid) + 1) (pin sid l k2, pin sts k2 l, k2)))))
       st0 (map (l \ intern (clo (map bases l))) starts)
       tr {}
       (step l c) (clo (foldl (a \ i \ (elem c (bytes i) ? ((i + 1) . a) a)) () (filter (i \ <(nd i) != 12) l)))
       (walk q) (? !(two? q) 0
                   (: s <q l (sts s)
                      new (foldl (a \ k \ (: t (intern (step l (reps k)))
                                             (pin tr [s k] t,
                                              (t && !(peep tr [t 'v] ()) ? (pin tr [t 'v] 1, (t . a)) a))))
                                 () (jot K))
                      (walk (>q + rev new))))
       sq (filter (s \ s && !(peep tr [s 'v] ()) && (pin tr [s 'v] 1, 1)) st0)
       _ (walk sq)
       S #(keys sid)
       ss (map (+ 1) (jot S))
       ; Moore's refinement: blocks by accept, split by the blocks each class leads to, to a fixpoint
       (number l) (: ids {} (map (k9 \ peep ids k9 0 @ v (v ? v (: v2 (#(keys ids) + 1) (pin ids k9 v2, v2)))) l))
       (blk p) (: t {} (map (s \ pin t s (p (s - 1))) ss, t))
       (refine b nb)
        (: key (map (s \ [(b s) (map (k \ (peep tr [s k] 0 @ t (t ? (b t) 0))) (jot K))]) ss)
           b2 (blk (number key))
           n2 #(keys (foldl (t \ s \ pin t (b2 s) 1) {} ss))
           (n2 = nb ? b (refine b2 n2)))
       b0 (blk (number (map (s \ acpt (sts s)) ss)))
       bf (refine b0 #(keys (foldl (t \ s \ pin t (b0 s) 1) {} ss)))
       ; renumbered in state order, so the start's block is 1
       ren {} rep {}
       _ (map (s \ (peep ren (bf s) 0 ? () (: m (#(keys ren) + 1) (pin ren (bf s) m, pin rep m s)))) ss)
       M #(keys ren)
       ms (map (+ 1) (jot M))
       trans (foldl (a \ m \ a + map (k \ (peep tr [(rep m) k] 0 @ t (t ? (ren (bf t)) 0))) (jot K)) () ms)
       accept (0 . map (m \ acpt (sts (rep m))) ms)
       [cls (M + 1) K (map (k \ 0) (jot K) + trans) accept (map (s \ s ? (ren (bf s)) 0) st0)])
   ; -- the tables as dfa.c reads them: w (1, or 2 once states or rules pass 255), K and S in two
   ; bytes each, the class map, the rule by state, the next state by (state, class) --
   (lex-tab d)
    (: S (d 1) K (d 2) w (S < 256 && #(d 5) < 256 ? 1 2)
       (wd v) (w = 1 ? [v] [(v & 255) (v >> 8)])
       _ (S < 65536 && K < 65536 ? () (lex-die "past 65535 states"))
       (string ([w (K & 255) (K >> 8) (S & 255) (S >> 8)] + <d + foldl (a \ v \ a + wd v) () (d 4 + d 3))))
   (lex-scan txt) (trap (_ \ (lex-dfa (lex-spec txt) @ d [(lex-tab d) (d 5)]))
                        () (\ a b (a @ 'lex-err b (scare a b))))
   (lex-next t src i) ((cite 'dfa 'run) t src i @ m (m ? [(m & 65535) (m >> 16)]))
   ; -- a flex spec whole, for the C scanner: {'defs 'code 'opts 'scs 'rules 'pre 'post}. code the
   ; definitions' C (%{ %}, indented lines, comments), scs ((name exclusive?) ..) past INITIAL, pre
   ; the C opening the rules, post the C after the second %%. a rule [scs bol pattern tail action]:
   ; scs () for none or "*", pattern "<<EOF>>" for an end rule, tail the trailing context or (),
   ; action C text or "|" --
   (lex-pendi s i0)
    (: n #s
       (go i q b) (? (n <= i) i
                     (s i @ c
                        (? (c = 92) (go (i + 2) q (b && 1))
                           q (go (i + 1) (c != 34) b)
                           (b && c = 91 && i + 1 < n && s (i + 1) = 58)
                            (: k (findsub (snip s i n) ":]") (go (k < 0 ? (i + 1) (i + k + 2)) q 1))
                           (b = 2) (go (i + 1) q (c = 94 ? 2 1))
                           (b && c = 93) (go (i + 1) q ())
                           b (go (i + 1) q b)
                           (c = 34) (go (i + 1) 1 b)
                           (c = 91) (go (i + 1) q 2)
                           (lex-sp? c) i
                           (go (i + 1) q b))))
       (go i0 () ()))
   (lex-lead s) (: (go i) (i < #s && lex-sp? (s i) ? (go (i + 1)) i) (go 0))
   (lex-pre? s t) (#t <= #s && snip s 0 #t = t)
   ; C from i: the braces opened less those closed, and whether a /* */ is left open
   (lex-qskip t i q) (: n #t (go j) (? (n <= j) n (t j = 92) (go (j + 2)) (t j = q) (j + 1) (go (j + 1))) (go i))
   (lex-cdepth t d cm)
    (: n #t
       (go i d cm)
        (? (n <= i) [d cm]
           cm (i + 1 < n && t i = 42 && t (i + 1) = 47 ? (go (i + 2) d ()) (go (i + 1) d 1))
           (i + 1 < n && t i = 47 && t (i + 1) = 42) (go (i + 2) d 1)
           (i + 1 < n && t i = 47 && t (i + 1) = 47) [d ()]
           (t i = 34 || t i = 39) (go (lex-qskip t (i + 1) (t i)) d ())
           (t i = 123) (go (i + 1) (d + 1) ())
           (t i = 125) (go (i + 1) (d - 1) ())
           (go (i + 1) d ()))
       (go 0 d cm))
   ; an action begun with a on its rule's line, l the lines after -> [C l']: %{ to %}, or on to
   ; its braces' close
   (lex-act a l)
    (? (lex-pre? a "%{")
        (: (go l acc) (? !(two? l) (lex-die "an open %{")
                         (lex-trim <l = "%}") [(join "\n" (rev acc)) >l]
                         (go >l (<l . acc)))
           (go l [(snip a 2 #a)]))
       (: (go l acc d cm) (? (d <= 0 && !cm) [(join "\n" (rev acc)) l]
                             !(two? l) (lex-die "an action's braces never close")
                             (lex-cdepth <l d cm @ [d2 cm2] (go >l (<l . acc) d2 cm2)))
          (lex-cdepth a 0 () @ [d cm] (go l [a] d cm))))
   ; a pattern's top-level / (trailing context) and a final $ (a newline after): [head tail]
   (lex-ptail p)
    (: n #p
       (go i q b) (? (n <= i) [p ()]
                     (p i @ c
                        (? (c = 92) (go (i + 2) q b)
                           q (go (i + 1) (c != 34) b)
                           b (go (i + 1) q (c != 93))
                           (c = 34) (go (i + 1) 1 b)
                           (c = 91) (go (i + 2) q 1)
                           (c = 47) [(snip p 0 i) (snip p (i + 1) n)]
                           (c = 36 && i = n - 1) [(snip p 0 i) "\\n"]
                           (go (i + 1) q b))))
       (go 0 () ()))
   (lex-fspec txt)
    (: t {'defs () 'code () 'opts () 'scs () 'rules () 'pre () 'post ()}
       (add k v) (pin t k (peep t k () + [v]))
       (block l) (: (go l acc) (? !(two? l) (lex-die "an open %{")
                                  (lex-trim <l = "%}") [(join "\n" (rev acc)) >l]
                                  (go >l (<l . acc)))
                    (go >l ()))
       (comment l) (: (go l acc) (? !(two? l) [(join "\n" (rev acc)) l]
                                    (0 <= findsub <l "*/") [(join "\n" (rev (<l . acc))) >l]
                                    (go >l (<l . acc)))
                      (go l ()))
       (defs l)
        (? !(two? l) (lex-die "no %% before the rules")
           (<l @ x
              (? (x = "%%") >l
                 (lex-pre? x "%{") (block l @ [c r] (add 'code c, defs r))
                 (lex-pre? x "/*") (comment l @ [c r] (add 'code c, defs r))
                 (#(lex-trim x) = 0) (defs >l)
                 (lex-sp? (x 0)) (add 'code x, defs >l)
                 (lex-pre? x "%option") (map (w \ add 'opts w) (words (snip x 7 #x)), defs >l)
                 (lex-pre? x "%x") (map (w \ add 'scs [w 1]) (words (snip x 2 #x)), defs >l)
                 (lex-pre? x "%s") (map (w \ add 'scs [w ()]) (words (snip x 2 #x)), defs >l)
                 (x 0 = 37) (defs >l)
                 (: (nm i) (i < #x && lex-name? (x i) ? (nm (i + 1)) i)
                    k (nm 0)
                    (add 'defs [(snip x 0 k) (lex-trim (snip x k #x))], defs >l)))))
       (rules l scope seen)
        (? !(two? l) ()
           (<l @ x
              (: ld (lex-lead x) tx (lex-trim x)
                 (? (x = "%%") (pin t 'post (join "\n" >l))
                    (#tx = 0) (rules >l scope seen)
                    (two? scope && tx = "}") (rules >l () seen)
                    (!seen && !(two? scope) && lex-pre? x "%{") (block l @ [c r] (add 'pre c, rules r scope seen))
                    (!seen && !(two? scope) && 0 < ld) (add 'pre x, rules >l scope seen)
                    (: i0 (two? scope ? ld 0)
                       sc? (x i0 = 60 && !(lex-pre? (snip x i0 #x) "<<EOF>>"))
                       k (sc? ? (findsub (snip x i0 #x) ">" + i0) i0)
                       scs (sc? ? (snip x (i0 + 1) k @ v (v = "*" ? "*" (split "," v))) ())
                       i (sc? ? (k + 1) i0)
                       (? (sc? && i < #x && x i = 123 && #(lex-trim (snip x (i + 1) #x)) = 0) (rules >l scs seen)
                          (: eof (lex-pre? (snip x i #x) "<<EOF>>")
                             e (eof ? (i + 7) (lex-pendi x i))
                             p (snip x i e)
                             bol (!eof && 0 < #p && p 0 = 94)
                             pt (eof ? [p ()] (lex-ptail (bol ? (snip p 1 #p) p)))
                             (lex-act (lex-trim (snip x e #x)) >l @ [a r]
                                (add 'rules [(two? scs || string? scs ? scs scope) bol <pt <>pt a],
                                 rules r scope 1)))))))))
       (rules (defs (split "\n" txt)) () (), t))
   ; a pattern's length when every match has one, else (): literals, escapes, classes and {NAME}s
   (lex-flen defs p)
    (: n #p
       (go i m)
        (? (n <= i) m
           (p i @ c
              (? (c = 34) (: (q j m) (? (n <= j) () (p j = 34) (go (j + 1) m)
                                        (p j = 92) (lex-esc p (j + 1) @ [_ k] (q k (m + 1)))
                                        (q (j + 1) (m + 1)))
                             (q (i + 1) m))
                 (c = 92) (lex-esc p (i + 1) @ [_ k] (go k (m + 1)))
                 (c = 46) (go (i + 1) (m + 1))
                 (c = 91) (lex-br p (i + 1) @ [_ _ j] (go j (m + 1)))
                 (c = 123 && i + 1 < n && !(48 <= p (i + 1) <= 57))
                  (: j (i + findsub (snip p i n) "}") d (assoc (snip p (i + 1) j) defs)
                     (two? d ? (lex-flen defs <>d @ dm (charm? dm ? (go (j + 1) (m + dm)) ())) ()))
                 (elem c "*+?|(){}") ()
                 (go (i + 1) (m + 1)))))
       (go 0 0))

   ; -- the C scanner: flex's api over the tables, the spec's C in its places --
   lex-cpre """
      #include <stdio.h>
      #include <stdlib.h>
      #include <string.h>
      #define FLEX_SCANNER
      #define YY_FLEX_MAJOR_VERSION 2
      #define YY_FLEX_MINOR_VERSION 6
      #define YY_FLEX_SUBMINOR_VERSION 4
      #define YY_NULL 0
      #define YY_BUF_SIZE 16384
      #define INITIAL 0
      #define BEGIN yy_start =
      #define YY_START yy_start
      #define YYSTATE YY_START
      #define ECHO do { if (fwrite(yytext, (size_t) yyleng, 1, yyout)) {} } while (0)
      #define yyterminate() return YY_NULL
      #define YY_FATAL_ERROR(msg) yy_fatal_error(msg)
      #define YY_CURRENT_BUFFER (yy_ntop ? yy_stack[yy_ntop - 1] : (YY_BUFFER_STATE) 0)
      #define yyless(n) yy_less(n)
      #define unput(c) yyunput(c, yytext)
      typedef struct yy_buffer_state *YY_BUFFER_STATE;
      extern FILE *yyin, *yyout;
      extern char *yytext;
      extern int yyleng;
      extern int yylineno;
      int yylex(void);
      YY_BUFFER_STATE yy_create_buffer(FILE *f, int size);
      void yy_switch_to_buffer(YY_BUFFER_STATE b);
      void yy_delete_buffer(YY_BUFFER_STATE b);
      void yypush_buffer_state(YY_BUFFER_STATE b);
      void yypop_buffer_state(void);
      void yyrestart(FILE *f);
      static int yy_start;
      static YY_BUFFER_STATE *yy_stack;
      static long yy_ntop;
      static void yy_fatal_error(const char *msg);
      static void yy_less(int n) __attribute__((unused));

      """
   lex-cmid """
      #ifndef YY_DECL
      #define YY_DECL int yylex(void)
      #endif
      #ifndef YY_USER_ACTION
      #define YY_USER_ACTION
      #endif
      #ifndef YY_BREAK
      #define YY_BREAK break;
      #endif
      #define YY_RULE_SETUP YY_USER_ACTION
      /* a buffer reads its file whole at first use; pos is the next byte, bol whether a line begins there */
      struct yy_buffer_state { FILE *f; char *buf; long len, cap, pos; int filled, bol; };
      FILE *yyin, *yyout;
      char *yytext;
      int yyleng;
      int yylineno = 1;
      static long yy_ncap;
      /* the byte held off behind yytext's nul, and whose */
      static YY_BUFFER_STATE yy_hbuf;
      static long yy_hpos;
      static char yy_hold;

      """
   lex-crun """
      static void yy_fatal_error(const char *msg) { fprintf(stderr, "%s\n", msg); exit(2); }
      static void yy_unhold(void) { if (yy_hbuf) { yy_hbuf->buf[yy_hpos] = yy_hold; yy_hbuf = 0; } }
      static void yy_holdat(YY_BUFFER_STATE b, long p) { yy_hbuf = b; yy_hpos = p; yy_hold = b->buf[p]; b->buf[p] = 0; }
      static void yy_lines(const char *s, long n, int d) { long i; for (i = 0; i < n; i++) if (s[i] == '\n') yylineno += d; }
      static void yy_grow(void) {
        if (yy_ntop < yy_ncap) return;
        yy_ncap = yy_ncap ? 2 * yy_ncap : 8;
        yy_stack = realloc(yy_stack, (size_t) yy_ncap * sizeof *yy_stack);
        if (!yy_stack) YY_FATAL_ERROR("out of memory"); }
      static void yy_fill(YY_BUFFER_STATE b) {
        size_t n;
        if (b->filled) return;
        b->filled = 1; b->cap = 16384; b->len = 0; b->pos = 0;
        b->buf = malloc((size_t) b->cap + 2);
        if (!b->buf) YY_FATAL_ERROR("out of memory");
        while (b->f && (n = fread(b->buf + b->len, 1, (size_t) (b->cap - b->len), b->f)) > 0) {
          b->len += (long) n;
          if (b->len == b->cap) {
            b->cap *= 2;
            b->buf = realloc(b->buf, (size_t) b->cap + 2);
            if (!b->buf) YY_FATAL_ERROR("out of memory"); } }
        b->buf[b->len] = 0; b->buf[b->len + 1] = 0; }
      YY_BUFFER_STATE yy_create_buffer(FILE *f, int size) {
        YY_BUFFER_STATE b = calloc(1, sizeof *b);
        (void) size;
        if (!b) YY_FATAL_ERROR("out of memory");
        b->f = f; b->bol = 1;
        return b; }
      void yy_switch_to_buffer(YY_BUFFER_STATE b) {
        yy_unhold();
        if (!yy_ntop) { yy_grow(); yy_ntop = 1; }
        yy_stack[yy_ntop - 1] = b;
        if (b) yyin = b->f; }
      void yy_delete_buffer(YY_BUFFER_STATE b) {
        if (!b) return;
        if (yy_hbuf == b) yy_hbuf = 0;
        if (b == YY_CURRENT_BUFFER) yy_stack[yy_ntop - 1] = 0;
        free(b->buf); free(b); }
      void yypush_buffer_state(YY_BUFFER_STATE b) {
        yy_unhold();
        if (!b) return;
        if (!yy_ntop || YY_CURRENT_BUFFER) { yy_grow(); yy_ntop++; }
        yy_stack[yy_ntop - 1] = b;
        yyin = b->f; }
      void yypop_buffer_state(void) {
        yy_unhold();
        if (!YY_CURRENT_BUFFER) return;
        yy_delete_buffer(YY_CURRENT_BUFFER);
        if (yy_ntop > 1) yy_ntop--;
        if (YY_CURRENT_BUFFER) yyin = YY_CURRENT_BUFFER->f; }
      void yyrestart(FILE *f) {
        YY_BUFFER_STATE b = YY_CURRENT_BUFFER;
        yy_unhold();
        if (!b) { yy_switch_to_buffer(yy_create_buffer(f, YY_BUF_SIZE)); return; }
        if (yy_hbuf == b) yy_hbuf = 0;
        free(b->buf); b->buf = 0; b->filled = 0; b->len = b->pos = 0; b->bol = 1; b->f = f; yyin = f; }
      static YY_BUFFER_STATE yy_cur(void) {
        if (!yyin) yyin = stdin;
        if (!yyout) yyout = stdout;
        if (!YY_CURRENT_BUFFER) yy_switch_to_buffer(yy_create_buffer(yyin, YY_BUF_SIZE));
        yy_fill(YY_CURRENT_BUFFER);
        return YY_CURRENT_BUFFER; }
      /* the longest match at pos, the earliest rule on a tie: its number, 0 at the end, -1 for none */
      static int yy_scan(void) {
        YY_BUFFER_STATE b;
        long p, last = 0;
        int st, r = 0;
        yy_unhold();
        b = yy_cur();
        yytext = b->buf + b->pos; yyleng = 0;
        if (b->pos >= b->len) return 0;
        st = yy_starts[2 * yy_start + b->bol];
        for (p = b->pos; st && p < b->len; ) {
          st = yy_trans[st * YY_NCLS + yy_cls[(unsigned char) b->buf[p]]];
          p++;
          if (st && yy_acc[st]) { r = yy_acc[st]; last = p; } }
        if (!r) yyleng = 1;
        else {
          yyleng = (int) (last - b->pos);
          if (yy_tck[r] == 1) yyleng -= yy_tcn[r];
          else if (yy_tck[r] == 2) yyleng = yy_tcn[r]; }
        b->pos += yyleng;
        yy_lines(yytext, yyleng, 1);
        b->bol = yytext[yyleng - 1] == '\n';
        yy_holdat(b, b->pos);
        return r ? r : -1; }
      static void yy_less(int n) {
        YY_BUFFER_STATE b = YY_CURRENT_BUFFER;
        yy_unhold();
        yy_lines(yytext + n, yyleng - n, -1);
        b->pos = (long) (yytext - b->buf) + n;
        yyleng = n;
        yy_holdat(b, b->pos); }

      """
   lex-cinput """
      static int input(void) {
        YY_BUFFER_STATE b;
        int c;
        yy_unhold();
        b = yy_cur();
        if (b->pos >= b->len) return 0;
        c = (unsigned char) b->buf[b->pos++];
        if (c == '\n') yylineno++;
        b->bol = c == '\n';
        yy_holdat(b, b->pos);
        return c; }

      """
   lex-cunput """
      static void yyunput(int c, char *bp) {
        YY_BUFFER_STATE b;
        (void) bp;
        yy_unhold();
        b = yy_cur();
        if (!b->pos) {
          char *nb = malloc((size_t) b->len + 66);
          if (!nb) YY_FATAL_ERROR("out of memory");
          memcpy(nb + 64, b->buf, (size_t) b->len + 2);
          free(b->buf);
          b->buf = nb; b->pos = 64; b->len += 64; b->cap = b->len; }
        b->buf[--b->pos] = (char) c;
        if (c == '\n') yylineno--; }

      """
   (lex-carr ty nm vs)
    (: (rows l acc) (? !(two? l) (rev acc) (rows (drop 16 l) (join ", " (map show (take 16 l)) . acc)))
       ("static const " + ty + " " + nm + "[" + show (max 1 #vs) + "] = {\n  "
        + join ",\n  " (rows (two? vs ? vs [0]) ()) + " };\n"))
   (lex-cout f txt)
    (: t (lex-fspec txt)
       opt (t 'opts) (has o) (elem o opt)
       defs (lex-defs (t 'defs))
       scs (["INITIAL" ()] . t 'scs)
       nsc #scs
       rl (t 'rules)
       rs (filter (r \ r 2 != "<<EOF>>") rl)
       es (filter (r \ r 2 = "<<EOF>>") rl)
       _ (two? rs ? () (lex-die "no rules"))
       _ (map (r \ (!(two? <r) || all (n \ any (s \ <s = n) scs) <r) ? () (lex-die ("no start condition in " + show <r))) rl)
       (in? r j) (: s <r (? (string? s) 1 (two? s) (elem (<(scs j)) s) !(<>(scs j))))
       starts (foldl (a \ j \ a + map (b \ filter (k \ in? (rs k) j && (b || !((rs k) 1))) (jot #rs)) [0 1]) () (jot nsc))
       eres (map (r \ (r 3 @ tl (two? tl || string? tl ? ("(" + lex-ere defs (r 2) + ")(" + lex-ere defs tl + ")") (lex-ere defs (r 2))))) rs)
       tcs (map (r \ (string? (r 3) ? (lex-flen defs (r 3) @ m
                                         (charm? m ? [1 m] (lex-flen defs (r 2) @ h (charm? h ? [2 h] (lex-die ("variable trailing context in " + r 2))))))
                       [0 0]))
                rs)
       a (lex-auto eres starts)
       S (a 1) K (a 2)
       (eof j) (: own (filter (r \ two? <r && elem (<(scs j)) <r || string? <r) es) un (filter (r \ !(two? <r || string? <r)) es)
                  (two? own ? (<own 4) (two? un ? (<un 4) ())))
       acts (map (k \ (rs k) @ r
                    (r 4 = "|" ? ("case " + show (k + 1) + ":\n")
                       ("case " + show (k + 1) + ":\nYY_RULE_SETUP\n" + r 4 + "\nYY_BREAK\n")))
                 (jot #rs))
       ("/* generated by `love lex " + f + "`; edit the spec, not this */\n"
        + lex-cpre
        + (has "noyywrap" ? "#define yywrap() 1\n" "int yywrap(void);\n")
        + (has "noinput" ? "" "static int input(void);\n")
        + (has "nounput" ? "" "static void yyunput(int c, char *bp) __attribute__((unused));\n")
        + join "" (map (j \ "#define " + <(scs j) + " " + show j + "\n") (drop 1 (jot nsc)))
        + join "\n" (t 'code) + "\n"
        + lex-cmid
        + "#define YY_NCLS " + show K + "\n"
        + lex-carr "unsigned short" "yy_cls" <a
        + lex-carr "unsigned short" "yy_acc" (a 4)
        + lex-carr "unsigned short" "yy_trans" (a 3)
        + lex-carr "unsigned short" "yy_starts" (a 5)
        + lex-carr "unsigned char" "yy_tck" (0 . map (c \ <c) tcs)
        + lex-carr "int" "yy_tcn" (0 . map (c \ c 1) tcs)
        + "\n" + lex-crun
        + (has "noinput" ? "" lex-cinput)
        + (has "nounput" ? "" lex-cunput)
        + "YY_DECL\n{\n" + join "\n" (t 'pre) + "\n  for (;;) {\n    int yy_r = yy_scan();\n"
        + "    if (!yy_r) {\n      YY_BUFFER_STATE yy_eb = YY_CURRENT_BUFFER;\n"
        + "      if (!yywrap()) { yyrestart(yyin); continue; }\n      switch (YY_START) {\n"
        + join "" (map (j \ eof j @ e (string? e ? ("      case " + show j + ":\n" + e + "\n      break;\n") "")) (jot nsc))
        + "      default: yyterminate();\n      }\n      if (YY_CURRENT_BUFFER == yy_eb) yyterminate();\n      continue;\n    }\n"
        + "    switch (yy_r) {\n    case -1:\n"
        + (has "nodefault" ? "      YY_FATAL_ERROR(\"flex scanner jammed\");\n" "      ECHO;\n") + "      break;\n"
        + join "" acts
        + "    }\n  }\n}\n"
        + (string? (t 'post) ? (t 'post) "")))

   ; -- love lex: the tables as love text --
   (lex-hex v) ("0123456789abcdef" @ h (string [92 120 (h (v >> 4)) (h (v & 15))]))
   (lex-text mod nm spec r)
    (: _ (all (w \ 0 < #w && all lex-name? (map w (jot #w))) <>r ? () (lex-die "an action that is no word"))
     ("; generated by `love lex " + spec + "`; edit the spec, not this\n(module '" + mod + "\n(:\n" +
     "   " + nm + " \"" + join "" (map lex-hex (map <r (jot #<r))) + "\"\n" +
     "   " + nm + "-rules '(" + join " " <>r + ")\n))\n"))
   ; love lex -o FILE [-L] [-t] SPEC: the C scanner, as flex lays one (-t to stdout)
   (lex-cmain as)
    (: (go a o) (? !(two? a) (udie 2 "usage: lex -o FILE [-L] SPEC")
                   (<a = "-L") (go >a o)
                   (<a = "-t") (go >a "-")
                   (<a = "-o" && two? >a) (go >>a <>a)
                   (lex-pre? <a "-o") (go >a (snip <a 2 #<a))
                   (two? >a) (udie 2 ("lex: unknown option " + <a))
                   [<a o])
       fo (go as "lex.yy.c")
       f <fo
       txt (uread f @ x (two? x ? <>x (udie 1 ("lex: can't read " + f))))
       r (trap (_ \ lex-cout f txt) () (\ a b (a @ 'lex-err b (scare a b))))
       (string? r && lex-pre? r "/* generated" ?
           (<>fo = "-" ? (say out r, 0)
              (open <>fo "w" @ q (hot? q ? (say q r, close q, 0) (udie 1 ("lex: can't write " + <>fo)))))
          (udie 1 ("lex: " + f + ": " + show r))))
   (lex-main as)
    (? (any (a \ a = "-L" || a = "-t" || lex-pre? a "-o") as) (lex-cmain as)
    (: (opts a m n) (? (two? a && two? >a && <a = "-m") (opts >>a <>a n)
                       (two? a && two? >a && <a = "-n") (opts >>a m <>a)
                       [a m n])
       o (opts as "moon" "lex-tab")
       f <<o
       _ (two? <o && !(two? ><o) ? () (udie 2 "usage: lex [-m MODULE] [-n NAME] SPEC"))
       r (lex-scan (uread f @ x (two? x ? <>x (udie 1 ("lex: can't read " + f)))))
       (string? r ? (udie 1 ("lex: " + f + ": " + r))
          (: _ (say out (lex-text <>o <>>o f r)) 0))))
))
