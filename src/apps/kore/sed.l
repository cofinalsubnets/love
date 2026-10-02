; src/apps/kore/sed.l -- sed-lite over the re.l engine: the stream editor's useful
; core. a toolbox file, no seat -- kore is its door; loads after re.l in the cat.
;
;   sed [-n] [-E] [-i] [-e script].. script [file..]
;
; commands split by ; or newlines, each [addr[,addr]] verb. addresses: N, $, /re/ (BRE, or
; ERE under -E). verbs: p d q, and s/re/repl/[g][p] with any delimiter; the replacement
; knows &, \1..\9 and \x. -e stacks scripts; once any -e is given every word is a file.
; -i makes each file its own stream (numbers restart, $ per file); `srun` takes its output
; port, which is the whole of how -i captures. not here: empty-pattern reuse, \n in a
; replacement, the hold space.
;
; the pure floor (lawed in test/law/kore.l): (sparse sc ere?) -> (1 cmds) | (),
; and (usub nodes repl ln g?) -> (changed text), the one substitution walk.
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   ; -- the substitution: replace matches of nodes in ln by repl (g? = all) --
   (usub nodes repl ln g?) (usubn nodes repl ln g? 1)
   ; ..from the nth match on: the ones before it ride through as they were (ed's s///N)
   (usubn nodes repl ln g? nth)
    (: n #ln
       ; the replacement text for one match at (ms me) with group spans sp
       (expand ms me sp)
        (: rn #repl
           (xgo i acc)
            (rn <= i ? acc
             (repl i @ c
                (? (c = 38) (xgo (i + 1) (acc + snip ln ms me))
                   (c = 92 && i + 1 < rn)
                    (repl (i + 1) @ d
                       (49 <= d && d <= 57 ?
                           (assoc (d - 48) sp @ e
                              (xgo (i + 2)
                                   (two? e ? (acc + snip ln <>e <>>e) acc)))
                          (xgo (i + 2) (acc + string d))))
                   (xgo (i + 1) (acc + string c)))))
           (xgo 0 ""))
       ; ate marks "a match ended exactly here": an empty match at that point is
       ; discarded (the POSIX rule -- s/x*/-/g on "xbz" is "-b-z-", one dash)
       ; k counts the matches met, so the ones before nth keep their own text
       (walk i acc ate hit k)
        (refindm nodes ln i @ [_ ms me sp]
          (ate && me = ms && ms = i ?
             (i < n ? (walk (i + 1) (acc + snip ln i (i + 1)) () hit k)
              [hit acc])
             (: rep? (nth <= k)
                acc2 (acc + snip ln i ms + (rep? ? (expand ms me sp) (snip ln ms me)))
                hit2 (rep? ? 1 hit)
                (? (rep? && !g?) [1 (acc2 + snip ln me n)]
                   ; g at an empty match: keep one charm and step past it
                   (me = ms) (me < n ?
                                (walk (me + 1) (acc2 + snip ln me (me + 1)) () hit2 (k + 1))
                                [hit2 acc2])
                   (walk me acc2 1 hit2 (k + 1)))))
          [hit (acc + snip ln i n)])
       (walk 0 "" () () 1))

   ; -- the script parser: text -> (1 cmds) | (). a command is
   ; (a1 a2 verb payload); an address is () | ('ln N) | ('last) | ('re nodes);
   ; an s payload is (nodes repl g? p?). ere? picks the regex dialect --
   (sparse sc ere?)
    (: n #sc
       (rx p) ((ere? ? reere rebre) p)
       (sep? c) (c = 32 || c = 9 || c = 10 || c = 59)
       (skip i) (i < n && sep? (sc i) ? (skip (i + 1)) i)
       (spc i) (i < n && (sc i = 32 || sc i = 9) ? (spc (i + 1)) i)
       (dig? c) (48 <= c && c <= 57)
       (num i v) (i < n && dig? (sc i) ? (num (i + 1) (10 * v + (sc i - 48))) [v i])
       ; to the unescaped delimiter d: \d -> d, all else verbatim -> (text j) | ()
       (until i d acc)
        (n <= i ? ()
         (sc i @ c
            (? (c = d) [acc (i + 1)]
               (c = 92 && i + 1 < n && sc (i + 1) = d)
                (until (i + 2) d (acc + string d))
               (c = 92 && i + 1 < n)
                (until (i + 2) d (acc + string 92 + string (sc (i + 1))))
               (until (i + 1) d (acc + string c)))))
       ; one address or none: (addr j) | () malformed
       (raddr i)
        (n <= i ? [() i]
         (sc i @ c
            (? (dig? c) (num i 0 @ [v j] [['ln v] j])
               (c = 36) ['(last) (i + 1)]
               (c = 47) (until (i + 1) 47 "" @ [txt j]
                          (rx txt @ [_ nds _] [['re (recomp nds)] j] ())
                          ())
               [() i])))
       (sepend? j) (n <= j || sep? (sc j))
       ; the s command's tail past the verb: delimiter, regex, replacement,
       ; flags -> (payload j) | ()
       (rsub j3)
        (n <= j3 + 1 ? ()
         (sc (j3 + 1) @ dl
            (dl = 92 || dl = 10 ? ()
             (until (j3 + 2) dl "" @ [re j4]
               (rx re @ [_ nds _]
                 (until j4 dl "" @ [rp j5]
                   (: (fgo k g? p?)
                       (? (sepend? k) [k g? p?]
                          (sc k = 103) (fgo (k + 1) 1 p?)
                          (sc k = 112) (fgo (k + 1) g? 1)
                          ())
                      (fgo j5 () () @ [j6 g? p?] [[(recomp nds) rp g? p?] j6] ()))
                   ())
                 ())
               ()))))
       (rcmd i acc)
        (skip i @ j
           (n <= j ? [1 (rev acc)]
            (raddr j @ [a1 j2]
              (j2 < n && sc j2 = 44 @ comma
                 (comma && atom? a1 ? ()               ; a , with no left leg
                  ((comma ? (raddr (j2 + 1)) [() j2]) @ r2
                     (atom? r2 || comma && atom? <r2 ? ()
                      (: a2 <r2 j0 (spc <>r2)
                         ; `addr!verb`: the verb runs on the lines the address does not select
                         bang (j0 < n && sc j0 = 33)
                         j3 (bang ? (spc (j0 + 1)) j0)
                         (n <= j3 ? ()
                          (: v (sc j3)
                             plain (verb \ (sepend? (j3 + 1) ?
                                              (rcmd (j3 + 1) ([a1 a2 verb () bang] . acc))))
                             (? (v = 112) (plain 'p)
                                (v = 100) (plain 'd)
                                (v = 113) (two? a2 ? () (plain 'q))
                                (v = 115) (rsub j3 @ [pay j4]
                                            (rcmd j4 ([a1 a2 's pay bang] . acc))
                                            ())
                                ()))))))))
              ())))
       (rcmd 0 ()))

   ; -- the cycle. op is the output port, which is how -i captures a file's own
   ; edit instead of saying it into out --
   ; (srun cmds rd n? op) -> the exit remembered, 0. rd is a `urdj`, and its
   ; [line term? last?] is all the cycle ever needed of the whole text: `$` is last?,
   ; and the missing final newline is term?. the read is a line at a time now -- sed
   ; of 50 MB held 8.1 GB when the cycle was handed `(lines txt)`.
   (srun cmds rd n? op)
    (: t {}                                  ; the range toggles, keyed by command index
       (amatch a no ln last?)
        (? (atom? a) 1
           (<a = 'ln) (no = <>a)
           (<a = 'last) last?
           (rehasm <>a ln))
       ; is command c (at index idx) selected on line no with pattern space ln?
       ; a range opens on its first address and closes on a later line's second
       (sel? c idx no ln last?)
        (: a1 <c a2 <>c
           (? (atom? a2) (amatch a1 no ln last?)
              (peep t idx 0)
               ((<a2 = 'ln ? (<>a2 <= no) (amatch a2 no ln last?)) @ fin
                  (fin ? (pin t idx 0),
                   1))
              (amatch a1 no ln last?)
               ((<a2 = 'ln ? (<>a2 <= no)) @ one
                  (one ? () (pin t idx 1),
                   1))
              ()))
       ; one line through the commands -> (kind ps): 0 flows, 1 deleted, 2 quits
       (rline cs idx ps no q last?)
        (cs @ (c . more)
           (!(sel? c idx no ps last? @ s (c 4 ? !s s)) ? (rline more (idx + 1) ps no q last?)
              (<>>c @ v
                 (? (v = 'd) [1 ps]
                    (v = 'q) [2 ps]
                    (v = 'p) (say q ps, put q 10, rline more (idx + 1) ps no q last?)
                    (: pay <>>>c
                       pr >>pay
                       r (usub <pay <>pay ps <pr)
                       ps2 <>r
                       (<r && <>pr ? (say q ps2, put q 10),
                        rline more (idx + 1) ps2 no q last?)))))
           [0 ps])
       ; the last line of an unterminated source rides a jug. the newline goes missing
       ; after the last write and not after every one -- `sed -n 'p;p'` keeps the inner
       ; one -- so the line is rendered whole and chomped once, whatever the commands did.
       ; and only the last line of the whole stream can lose it: an unterminated file
       ; in the middle of the join is followed by more output, so it keeps its newline.
       (mline no)
        (urdj-line rd @ [x term? last?]
           (: hold ((last? ? term? 1) ? () (jug 0))
              q (hold ? hold op)
              (rline cmds 0 x no q last? @ [kind ps]
                (kind = 1 ? () (n? ? () (say q ps, put q 10)), hold ? (say op (chomp (slurp hold))) 0, kind = 2 ? 0 (mline (no + 1)))
                0))
           0)
       (mline 1))

   ; -- sed: the flags, then one of the two stream models --
   ; before uopt reads the words, two of GNU's shapes it has no way to say: -i's suffix
   ; rides glued or not at all (-i.bak, --in-place=.bak; -in is -i with suffix n, as
   ; GNU's), and -f FILE is its script in place, so -e and -f keep their order. a
   ; cluster ending in f (-nf FILE) keeps its other letters. -> [words suffix]
   (sed-pre as)
    (: box {'sfx ()}
       (script f) (uread f @ r (two? r ? (chomp <>r) (udie 4 ("sed: couldn't open file " + f + ": No such file or directory"))))   ; 4, GNU's i/o status
       (go a acc)
        (atom? a ? (rev acc)
         (: w <a n #w
            (? (w = "--") (rev acc + a)
               (w = "--in-place") (go >a ("-i" . acc))
               (starts? w "--in-place=") (pin box 'sfx (snip w 11 n), go >a ("-i" . acc))
               (starts? w "--file=") (go >a ((script (snip w 7 n)) . "-e" . acc))
               (starts? w "-i" && 2 < n) (pin box 'sfx (snip w 2 n), go >a ("-i" . acc))
               (1 < n && w 0 = 45 && !(w 1 = 45) && has? w "f")
                (: k (findsub w "f") pre (snip w 0 k) glued (snip w (k + 1) n)
                   f (? (0 < #glued) glued (two? >a) <>a (udie 1 "sed: option requires an argument -- 'f'"))
                   more (0 < #glued ? >a >>a)
                   (go more ((script f) . "-e" . (1 < #pre ? (pre . acc) acc))))
               (go >a (w . acc)))))
       ws (go as ())
       [ws (box 'sfx)])
   (sed-main as0)
    (: pre (sed-pre as0) as <pre sfx <>pre
       t {}
       o (uopt as t '(101) '(101) ())                      ; -e script, stacking
       _ (two? o ? () (udie 1 "sed: bad option"))
       _ (uoptbad as t "nEeirs" @ c (!c ? () (udie 1 ("sed: unknown option -" + string c))))
       eps <>o rest <>>o
       _ (two? eps || two? rest ? ()
          (udie 1 "usage: sed [-nErs] [-i[SUFFIX]] [-e SCRIPT].. [-f FILE].. SCRIPT [FILE..]"))
       n? (peep t 110 0) i? (peep t 105 0) s? (peep t 115 0)
       _ (peep t 114 0 ? (pin t 69 1) 0)                 ; -r is -E, as GNU's
       sc (two? eps ? (ujoinc 10 eps) <rest)
       fs (ustray "sed" as (two? eps ? rest >rest))
       pc (sparse sc (peep t 69 0))
       _ (two? pc ? () (udie 1 ("sed: invalid script: " + sc)))
       cmds <>pc
       ; GNU's own sentence for an unreadable operand, and the one the gate pins
       (sed-miss f) (say err ("sed: can't read " + f + ": No such file or directory"), put err 10, 0)
       ; -i: each file its own stream, edited and written back. a file that will
       ; not open complains and the rest still flow, exactly as the joined lane.
       ; the answer is still held whole, and must be: it overwrites its own input.
       ; with a suffix the file as it was is kept beside it first. -s is the same
       ; walk with each file's stream said on out
       (inplace a bad)
        (a @ (f . more)
           (: rd (urdj sed-miss [f])
              j (i? ? (jug 0) out)
              _ (i? && sfx ? (uread f @ r (two? r ? (uwrite (f + sfx) <>r) 0)) 0)
              _ (srun cmds rd n? j)
              b (peep rd 'bad 0)
              ((b || !i? ? () (uwrite f (slurp j) ? ()
                               (say err ("sed: couldn't open " + f), put err 10))),
               inplace more (b ? 1 bad)))
           (flush out, flush err, bad ? 2 0))
       ((i? || s?) && two? fs ? (inplace fs ())
        ; the joined lane: every file one stream, so the numbers and $ run through
        (urdj sed-miss fs @ rd
           (srun cmds rd n? out,
            flush out, flush err,
            peep rd 'bad 0 ? 2 0)))))
) ; module 'kore
