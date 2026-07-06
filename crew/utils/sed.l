; crew/utils/sed.l -- sed-lite over the re.l engine: the stream editor's useful
; core. a toolbox file, no seat -- au is its door; loads after re.l in the cat.
;
;   sed [-n] SCRIPT [FILE..]
;
; the dialect: commands separated by ; or newlines, each [ADDR[,ADDR]] VERB.
; addresses: a line number, $ (the last line), /re/ (the BRE dialect of re.l,
; \/ for a literal /); a range ADDR,ADDR opens at the first, closes at the
; first LATER line matching the second (a numeric end at-or-before the start
; keeps just the one line, like GNU). verbs: p (print), d (delete), q (quit
; after this line's print; one address only), and s/RE/REPL/[g][p] with any
; delimiter after the s. the replacement knows & (the whole match), \1..\9
; (group spans off refind, a repeated group reading as its last iteration),
; and \x for a literal x. -n holds the auto-print; p and the s p-flag still
; speak. input is the concatenation of the files (line numbers run through,
; $ is the last line of the whole stream); - or no files reads in. an
; unreadable file complains, the rest still flow, and the exit remembers 2.
; out of dialect (documented, unsmoked): GNU's empty-s-pattern reuse (an empty
; pattern here just matches the empty text), \n in replacements, hold space.
;
; the pure floor (lawed in crew/utils/law.l): (sparse sc) -> (1 cmds) | (),
; and (usub nodes repl ln g?) -> (changed text), the one substitution walk.
(:
   ; -- the substitution: replace matches of nodes in ln by repl (g? = all) --
   (usub nodes repl ln g?)
    (: n (tally ln)
       ; the replacement text for one match at (ms me) with group spans sp
       (expand ms me sp)
        (: rn (tally repl)
           (xgo i acc)
            (? (<= rn i) acc
               (: c (repl i)
                  (? (= c 38) (xgo (+ i 1) (+ acc (snip ln ms me)))
                     (&& (= c 92) (< (+ i 1) rn))
                      (: d (repl (+ i 1))
                         (? (&& (<= 49 d) (<= d 57))
                             (: e (assoc (- d 48) sp)
                                (xgo (+ i 2)
                                     (? (two? e) (+ acc (snip ln (caup e) (cauup e))) acc)))
                            (xgo (+ i 2) (+ acc (string d)))))
                     (xgo (+ i 1) (+ acc (string c))))))
           (xgo 0 ""))
       ; ate marks "a match ended exactly here": an empty match at that point is
       ; DISCARDED (the POSIX rule -- s/x*/-/g on "xbz" is "-b-z-", one dash)
       (walk i acc ate hit)
        (: r (refind nodes ln i)
           (? (! (two? r)) (L hit (+ acc (snip ln i n)))
              (: q2 (cup r) ms (cap q2) me (caup q2) sp (cauup q2)
                 (? (&& ate (= me ms) (= ms i))
                    (? (< i n) (walk (+ i 1) (+ acc (snip ln i (+ i 1))) () hit)
                       (L hit acc))
                    (: acc2 (+ acc (+ (snip ln i ms) (expand ms me sp)))
                       (? (! g?) (L 1 (+ acc2 (snip ln me n)))
                          ; g at an empty match: keep one charm and step past it
                          (= me ms) (? (< me n)
                                       (walk (+ me 1) (+ acc2 (snip ln me (+ me 1))) () 1)
                                       (L 1 acc2))
                          (walk me acc2 1 1)))))))
       (walk 0 "" () ()))

   ; -- the script parser: text -> (1 cmds) | (). a command is
   ; (a1 a2 verb payload); an address is () | ('ln N) | ('last) | ('re nodes);
   ; an s payload is (nodes repl g? p?) --
   (sparse sc)
    (: n (tally sc)
       (sep? c) (|| (= c 32) (|| (= c 9) (|| (= c 10) (= c 59))))
       (skip i) (? (&& (< i n) (sep? (sc i))) (skip (+ i 1)) i)
       (spc i) (? (&& (< i n) (|| (= (sc i) 32) (= (sc i) 9))) (spc (+ i 1)) i)
       (dig? c) (&& (<= 48 c) (<= c 57))
       (num i v) (? (&& (< i n) (dig? (sc i))) (num (+ i 1) (+ (* 10 v) (- (sc i) 48))) (L v i))
       ; to the unescaped delimiter d: \d -> d, all else verbatim -> (text j) | ()
       (until i d acc)
        (? (<= n i) ()
           (: c (sc i)
              (? (= c d) (L acc (+ i 1))
                 (&& (= c 92) (< (+ i 1) n) (= (sc (+ i 1)) d))
                  (until (+ i 2) d (+ acc (string d)))
                 (&& (= c 92) (< (+ i 1) n))
                  (until (+ i 2) d (+ acc (+ (string 92) (string (sc (+ i 1))))))
                 (until (+ i 1) d (+ acc (string c))))))
       ; one address or none: (addr j) | () malformed
       (raddr i)
        (? (<= n i) (L () i)
           (: c (sc i)
              (? (dig? c) (: r (num i 0) (L (L 'ln (cap r)) (caup r)))
                 (= c 36) (L (L 'last) (+ i 1))
                 (= c 47) (: r (until (+ i 1) 47 "")
                             (? (! (two? r)) ()
                                (: b (rebre (cap r))
                                   (? (two? b) (L (L 're (caup b)) (caup r)) ()))))
                 (L () i))))
       (sepend? j) (|| (<= n j) (sep? (sc j)))
       ; the s command's tail past the verb: delimiter, regex, replacement,
       ; flags -> (payload j) | ()
       (rsub j3)
        (? (<= n (+ j3 1)) ()
           (: dl (sc (+ j3 1))
              (? (|| (= dl 92) (= dl 10)) ()
                 (: rr (until (+ j3 2) dl "")
                    (? (! (two? rr)) ()
                       (: b (rebre (cap rr))
                          (? (! (two? b)) ()
                             (: rp (until (caup rr) dl "")
                                (? (! (two? rp)) ()
                                   (: (fgo k g? p?)
                                       (? (sepend? k) (L k g? p?)
                                          (= (sc k) 103) (fgo (+ k 1) 1 p?)
                                          (= (sc k) 112) (fgo (+ k 1) g? 1)
                                          ())
                                      fr (fgo (caup rp) () ())
                                      (? (! (two? fr)) ()
                                         (L (L (caup b) (cap rp) (caup fr) (cauup fr))
                                            (cap fr)))))))))))))
       (rcmd i acc)
        (: j (skip i)
           (? (<= n j) (L 1 (rev acc))
              (: r1 (raddr j)
                 (? (! (two? r1)) ()
                    (: a1 (cap r1) j2 (caup r1)
                       comma (&& (< j2 n) (= (sc j2) 44))
                       (? (&& comma (! (two? a1))) ()               ; a , with no left leg
                          (: r2 (? comma (raddr (+ j2 1)) (L () j2))
                             (? (|| (! (two? r2)) (&& comma (! (two? (cap r2))))) ()
                                (: a2 (cap r2) j3 (spc (caup r2))
                                   (? (<= n j3) ()
                                      (: v (sc j3)
                                         (? (= v 112) (? (sepend? (+ j3 1)) (rcmd (+ j3 1) (link (L a1 a2 'p ()) acc)) ())
                                            (= v 100) (? (sepend? (+ j3 1)) (rcmd (+ j3 1) (link (L a1 a2 'd ()) acc)) ())
                                            (= v 113) (? (&& (sepend? (+ j3 1)) (! (two? a2)))
                                                         (rcmd (+ j3 1) (link (L a1 a2 'q ()) acc))
                                                         ())
                                            (= v 115) (: sr (rsub j3)
                                                         (? (two? sr)
                                                            (rcmd (caup sr) (link (L a1 a2 's (cap sr)) acc))
                                                            ()))
                                            ()))))))))))))
       (rcmd 0 ()))

   ; -- sed: the cycle over the concatenated stream --
   (sed-main as)
    (: n? (&& (two? as) (= (cap as) "-n"))
       rest (? n? (cup as) as)
       _ (? (two? rest) () (udie 2 "usage: sed [-n] SCRIPT [FILE..]"))
       pc (sparse (cap rest))
       _ (? (two? pc) () (udie 1 (+ "sed: invalid script: " (cap rest))))
       cmds (caup pc)
       fs (cup rest)
       (rdall a acc bad)
        (? (! (two? a)) (L (rev acc) bad)
           (: f (cap a)
              r (? (= f "-") (L 1 (slurp in)) (uread f))
              (? (two? r) (rdall (cup a) (link (caup r) acc) bad)
                 (: _ (say err (+ "sed: can't read " (+ f ": No such file or directory")))
                    _ (put err 10)
                    (rdall (cup a) acc 1)))))
       rd (? (two? fs) (rdall fs () ()) (L (L (slurp in)) ()))
       all (catmap lines (cap rd))
       rc (? (caup rd) 2 0)
       nl (tally all)
       t (tablet 0)                                  ; the range toggles, keyed by command index
       (amatch a no ln)
        (? (! (two? a)) 1
           (= (cap a) 'ln) (= no (caup a))
           (= (cap a) 'last) (= no nl)
           (rehas (caup a) ln))
       ; is command c (at index idx) selected on line no with pattern space ln?
       ; a range opens on its first address and closes on a LATER line's second
       (sel? c idx no ln)
        (: a1 (cap c) a2 (caup c)
           (? (! (two? a2)) (amatch a1 no ln)
              (peep t idx 0)
               (: fin (? (= (cap a2) 'ln) (<= (caup a2) no) (amatch a2 no ln))
                  _ (? fin (pin t idx 0) ())
                  1)
              (amatch a1 no ln)
               (: one (? (= (cap a2) 'ln) (<= (caup a2) no) ())
                  _ (? one () (pin t idx 1))
                  1)
              ()))
       ; one line through the commands -> (kind ps): 0 flows, 1 deleted, 2 quits
       (rline cs idx ps no)
        (? (! (two? cs)) (L 0 ps)
           (: c (cap cs)
              (? (! (sel? c idx no ps)) (rline (cup cs) (+ idx 1) ps no)
                 (: v (cauup c)
                    (? (= v 'd) (L 1 ps)
                       (= v 'q) (L 2 ps)
                       (= v 'p) (: _ (say out ps) _ (put out 10)
                                   (rline (cup cs) (+ idx 1) ps no))
                       (: pay (cap (cuup (cup c)))
                          pr (cuup pay)
                          r (usub (cap pay) (caup pay) ps (cap pr))
                          ps2 (caup r)
                          _ (? (&& (cap r) (caup pr))
                               (: _ (say out ps2) (put out 10)) ())
                          (rline (cup cs) (+ idx 1) ps2 no)))))))
       (mline ls no)
        (? (! (two? ls)) (: _ (flush out) _ (flush err) (nap rc))
           (: r (rline cmds 0 (cap ls) no)
              kind (cap r) ps (caup r)
              _ (? (= kind 1) () (? n? () (: _ (say out ps) (put out 10))))
              (? (= kind 2) (: _ (flush out) _ (flush err) (nap rc))
                 (mline (cup ls) (+ no 1)))))
       (mline all 1)))
