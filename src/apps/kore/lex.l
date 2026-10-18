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
   ; a bracket at the char past '[' -> (bytes negated? next)
   (lex-br s i0)
    (: neg (i0 < #s && s i0 = 94)
       (one i) (s i = 92 ? (lex-esc s (i + 1)) [(s i) (i + 1)])
       (go i acc first)
        (? (#s <= i) (lex-die "an open bracket")
           (s i = 93 && !first) [acc neg (i + 1)]
           (one i @ [lo j]
              (? (j + 1 < #s && s j = 45 && s (j + 1) != 93)
                  (one (j + 1) @ [hi k]
                     (hi < lo ? (lex-die "a backward range") (go k (acc + map (+ lo) (jot (hi - lo + 1))) ())))
                 (go j (lo . acc) ()))))
       (go (neg ? (i0 + 1) i0) () 1))
   ; bytes -> a canonical bracket: ']' first, '^' not first, '-' last, no nul
   (lex-brtext bs neg)
    (: has {} _ (map (b \ pin has b 1) bs)
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
                 (go (i + 1) (string [c] . acc)))))
       (go 0 ()))
   ; each definition translates seeing the ones before it
   (lex-defs ds) (foldl (acc \ d \ acc + [[<d (lex-ere acc <>d)]]) () ds)
   ; -- regcomp's program, read back: (op x y bytes) by pc. the block is a header, np instructions
   ; (op x y, and a pointer's room), then the sets' byte maps; byte mode keeps no ranges --
   (lex-i32 b o) (: v (b o + 256 * b (o + 1) + 65536 * b (o + 2) + 16777216 * b (o + 3))
                    (v < 2147483648 ? v (v - 4294967296)))
   (lex-prog e)
    (: b <(regcomp e 1)
       _ (string? b ? () (lex-die ("regcomp refuses " + e)))
       np (lex-i32 b 0) ns (lex-i32 b 4)
       _ (#b = 40 + 24 * np + 56 * ns ? () (lex-die "regcomp's program is not the block this reads"))
       (set k) (: o (40 + 24 * np + 56 * k) (filter (c \ ((b (o + (c >> 3)) >> (c & 7)) & 1)) (jot 256)))
       sets (map set (jot ns))
       (map (pc \ (: o (40 + 24 * pc) op (lex-i32 b o) x (lex-i32 b (o + 4)) y (lex-i32 b (o + 8))
                    [op x y (op = 2 ? (sets x) ())]))
            (jot np)))
   ; -- the DFA: (classes S K trans accept rules); states 0 (dead) to S - 1, 1 the start; trans by
   ; state * K + class; accept the rule's number from 1, 0 for none --
   ; the ops: 0 char, 1 any, 2 set, 6 split, 7 jmp, 8 save, 10 mark, 11 check, 12 match
   (lex-dfa spec)
    (: ds (lex-defs <spec)
       rs <>spec
       _ (two? rs ? () (lex-die "no rules"))
       progs (map (r \ lex-prog (lex-ere ds <r)) rs)
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
       (bytes i) (nd i @ f (<f @ 0 [<>f] 1 (map (+ 1) (jot 255)) 2 (f 3) ()))
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
       start (intern (clo bases))
       tr {}
       (step l c) (clo (foldl (a \ i \ (elem c (bytes i) ? ((i + 1) . a) a)) () (filter (i \ <(nd i) != 12) l)))
       (walk q) (? !(two? q) 0
                   (: s <q l (sts s)
                      new (foldl (a \ k \ (: t (intern (step l (reps k)))
                                             (pin tr [s k] t,
                                              (t && !(peep tr [t 'v] ()) ? (pin tr [t 'v] 1, (t . a)) a))))
                                 () (jot K))
                      (walk (>q + rev new))))
       _ (pin tr [start 'v] 1)
       _ (walk [start])
       S #(keys sid)
       _ (acpt (sts 1) ? (lex-die "a rule matches the empty text") ())
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
       [cls (M + 1) K (map (k \ 0) (jot K) + trans) accept (map (r \ <>r) rs)])
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
   ; -- love lex: the tables as love text --
   (lex-hex v) ("0123456789abcdef" @ h (string [92 120 (h (v >> 4)) (h (v & 15))]))
   (lex-text mod nm spec r)
    (: _ (all (w \ 0 < #w && all lex-name? (map w (jot #w))) <>r ? () (lex-die "an action that is no word"))
     ("; generated by `love lex " + spec + "`; edit the spec, not this\n(module '" + mod + "\n(:\n" +
     "   " + nm + " \"" + join "" (map lex-hex (map <r (jot #<r))) + "\"\n" +
     "   " + nm + "-rules '(" + join " " <>r + ")\n))\n"))
   (lex-main as)
    (: (opts a m n) (? (two? a && two? >a && <a = "-m") (opts >>a <>a n)
                       (two? a && two? >a && <a = "-n") (opts >>a m <>a)
                       [a m n])
       o (opts as "moon" "lex-tab")
       f <<o
       _ (two? <o && !(two? ><o) ? () (udie 2 "usage: lex [-m MODULE] [-n NAME] SPEC"))
       r (lex-scan (uread f @ x (two? x ? <>x (udie 1 ("lex: can't read " + f)))))
       (string? r ? (udie 1 ("lex: " + f + ": " + r))
          (: _ (say out (lex-text <>o <>>o f r)) 0)))
))
