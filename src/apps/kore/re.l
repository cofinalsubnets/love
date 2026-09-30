; src/apps/kore/re.l -- grep, over the regex engine in src/love/boot/post.l. the engine moved out
; (it is pure and had no kore couplings); this half is the one that reads files,
; so it keeps the u-floor (uread, udie) and text.l's lines. smoked byte-identical
; against GNU in `make test_kore`. a toolbox file, no seat -- kore.l is its door.
(borrow 're)

(module 'kore
(borrow 'cli)
(borrow 'text)
(borrow 'glob) ; --include and --exclude
(borrow 'posix) ; readdir, for -r
(: rebre (cite 're 'rebre) reere (cite 're 'reere)      ; the four engine names grep reads
   refold (cite 're 'refold) refindp (cite 're 'refindp)
   recomp (cite 're 'recomp) refindpm (cite 're 'refindpm)

   ; -- grep --------------------------------------------------------------------
   ; flags ride a tablet keyed by the option charm (cli's uopt fills it), so a
   ; new one is a row here and not another leg on a tuple every caller re-spells
   (gflag t c) (peep t c 0)
   ; a pattern text -> its node list, by the dialect and the -F/-i flags. a
   ; newline splits: GNU reads one pattern per line, which is also how -e stacks
   (gnodes t txt)
    ; the parser's shape is (1 nodes ngroups), so -F answers the same three.
    ; and -F walks by index: `two?` is false for a string, so (map f s) is () --
    ; which reads as the empty pattern and matches every line
    (: (one s) (? (gflag t 70) [1 (map (\ i ['chr (s i)]) (jot #s)) 0]
                  ((? (gflag t 69) reere rebre) s))
       (wrap nds) (: a (? (gflag t 120) (cat ('(bol) . nds) '((eol))) nds)
                     (? (gflag t 105) (refold a) a))
       (go ls acc)
        (ls @ (l . more)
           (one l @ [_ nds _] (go more ((wrap nds) . acc)) ())
           [1 (rev acc)])
       ; the empty pattern is one empty pattern, not none: `lines ""` is (), and
       ; a walk over () would answer no patterns at all -- so `grep ''`, which
       ; matches every line in GNU, would match nothing here
       ls (lines txt)
       (go (? (two? ls) ls [""]) ()))
   ; -w: the span must not sit inside a word. checked at the span, not the
   ; pattern, because a word boundary is not a node this engine can hold
   ; a word character, 'text's: ascii by the byte, past it by the character
   (gword? c) ((48 <= c <= 57) || (65 <= c <= 90) || (97 <= c <= 122) || (c = 95))
   (gwat ln j) (: b (ln j) (? (b < 128) (gword? b) (cpword? (cpat ln j))))
   (gwbefore ln j) (: b (ln (j - 1)) (? (b < 128) (gword? b) (cpword? (cpat ln (cpback ln j)))))
   ; the leftmost match of any of ms (compiled) in ln, word-bounded if w? -> (1 st en) | ()
   (gfind ms ln w? i)
    (: n #ln
       (bnd st en) (? !w? 1
                      ((st = 0 || !(gwbefore ln st)) && (en = n || !(gwat ln en))))
       (best acc m)
        (refindpm m ln i bnd @ [_ st en _]
          (? (atom? acc) [1 st en] (st < <>acc) [1 st en] acc)
          acc)
       (foldl best () ms))
   ; -e pattern (stacks), -f file, -m count, -A -B -C lines; --include and --exclude
   ; one glob each, keyed past the letters
   (grep-opt as t) (uopt as t '(101 102 109 65 66 67 1001 1002) '(101) {"include" 1001 "exclude" 1002})
   ; with -e or -f the whole tail is files; without them the first word is the pattern
   (grep-fs t o) (: eps <>o rest <>>o (? (two? eps || t 102) rest >rest))
   ; -r: the files under each operand, a directory's entries in order. a link met on
   ; the way is skipped, and followed under -R; an operand is followed either way.
   ; with no operand it is ., its names said without the ./
   (grep-tree fs R? inc exc)
    (: (want p) (: b (ubase p "") (? ((inc && !(match inc b)) || (exc && match exc b)) 0 1))
       (under d pre) (foldl (\ l nm (l + walk (pre + nm) 0)) () (sort (readdir d)))
       (walk p top)
        (: k (ukind p)
           (? (k = 'link && !top && !R?) ()
              (udirp p) (under p (? (ends? p "/") p (p + "/")))
              (? (top || want p) [p] ())))
       (? (two? fs) (foldl (\ l f (l + walk f 1)) () fs) (under "." "")))
   (grep-main as)
    (: t (tablet 0)
       o (grep-opt as t)
       _ (? (two? o) () (udie 2 "grep: bad option"))
       ; -a is in the usage and read nowhere: everything here is text, so it is a
       ; no-op and not an unknown
       _ (: c (uoptbad as t (chars "nvclqhaixwFEoemfrRHLsABC" + [1001 1002]))
            (? !c () (udie 2 ("grep: unknown option -" + string c))))
       eps <>o rest <>>o
       ; -f's patterns, a line each; an empty file is no pattern, which matches nothing
       fps (: f (uoptv t 102)
              (? !f ()
                 (: r (uread f) (? (two? r) (lines <>r) (udie 2 ("grep: " + f + ": No such file or directory"))))))
       pats (eps + fps)
       ; with -e or -f the whole tail is files; without them the first word is the pattern
       _ (? (two? eps || gflag t 102 || two? rest) ()
            (udie 2 "usage: grep [-cEFhHiLlnoqrRsvwx] [-e PAT] [-f FILE] [-m N] [-A N] [-B N] [-C N] [--include=GLOB] [--exclude=GLOB] PATTERN [FILE..]"))
       pt (? (two? pats) (ujoinc 10 pats) (gflag t 102) () <rest)
       r? (gflag t 114 || gflag t 82)
       fs0 (grep-fs t o)
       fs (? r? (grep-tree fs0 (gflag t 82) (uoptv t 1001) (uoptv t 1002)) fs0)
       nss (? (string? pt) (gnodes t pt) [1 ()])
       _ (? (two? nss) () (udie 2 ("grep: invalid pattern: " + pt)))
       ast (map recomp <>nss)                     ; compiled once, not per line
       n? (gflag t 110) v? (gflag t 118) c? (gflag t 99) l? (gflag t 108)
       q? (gflag t 113) h? (gflag t 104) o? (gflag t 111) w? (gflag t 119)
       L? (gflag t 76) s? (gflag t 115)
       (count c d) (: v (uoptv t c) n (? v (unum v) d)
                      (? (charm? n && 0 <= n) n (udie 2 ("grep: invalid context length: " + v))))
       mx (: v (uoptv t 109) (? v (uatoi v) ()))
       B (count 66 (count 67 0)) A (count 65 (count 67 0))
       ctx? (gflag t 65 || gflag t 66 || gflag t 67)   ; -C0 still marks the gaps
       many (? (gflag t 72) 1 h? 0 (r? || (two? fs && two? >fs)))
       (sel ln) (: m (? (two? (gfind ast ln w? 0)) 1 0) (? v? (? m 0 1) m))
       (pfx label) (? many (say out label, put out 58) ())
       ; one line out, c the separator (: a match, - context); with context a gap since
       ; the last line said, or a new file, is a -- row
       (line label no x c)
        (: _ (? (ctx? && peep st 'any 0 && (peep st 'lastf "" != label || peep st 'lastn 0 + 1 < no)) (say out "--\n") 0)
           _ (? ctx? (pins st 'any 1 'lastf label 'lastn no) 0)
           _ (? many (say out label, put out c) 0)
           _ (? n? (say out (show no), put out c) 0)
           (say out x, put out 10))
       ; -o: every match on the line, each on its own row. -v has nothing to show
       (emit1 label no ln)
        (: (go i)
            (gfind ast ln w? i @ [_ st en]
              ; a zero-length match prints nothing (GNU's rule, and `-o '[a-z]*'`
              ; is how you meet it) -- but it still advances, or the walk sits still
              ((? (st < en)
                      (pfx label, (? n? (say out (show no), put out 58) ()), say out (snip ln st en), put out 10)
                      ()), (? (en < tally ln) (go (? (en = st) (en + 1) en)) ()))
              ())
           (go 0))
       ; one input through the chosen face; answers the hit flag onward. it reads a
       ; line at a time -- grep of 50 MB used to hold 8.2 GB, because `lines` made a
       ; string and a cell for every line before the first one was matched. -q and -l
       ; stop at the first hit, which is now a stop and not just a shortcut.
       (dof label rd hit)
        (: (anym _) (: l (urd-line rd) (? (atom? l) 0 (? (sel <l) 1 (anym 0))))
           (? q? (? (anym 0) 1 hit)
              l? (? (anym 0) (say out label, put out 10, 1) hit)
              L? (? (anym 0) 1 (say out label, put out 10, hit))   ; the status is still by lines
              c? (: (cnt k) (? (mx && (mx <= k)) k
                               (: l (urd-line rd)
                                  (? (atom? l) k (cnt (? (sel <l) (k + 1) k)))))
                    k (cnt 0)
                    _ (pfx label)
                    _ (say out (show k)) _ (put out 10)
                    (? (0 < k) 1 hit))
              ; ring: the last B lines not said, newest first, for a match to lead
              ; with; aft: how many after a match are still owed
              (: (lp no h seen ring aft)
                  (? (mx && (mx <= seen))
                     (: (owed k) (? (k <= 0) 0 (: l (urd-line rd) (? (atom? l) 0 (line label no <l 45, owed (k - 1)))))
                        (owed aft, h))
                     (: l (urd-line rd)
                        (? (atom? l) h
                           (: x <l
                              m (sel x)
                              _ (? (m && o? && !v?) (emit1 label no x)
                                   m (each (rev ring) (p \ line label <p <>p 45), line label no x 58)
                                   (0 < aft) (line label no x 45)
                                   ())
                              (lp (no + 1) (? m 1 h) (? m (seen + 1) seen)
                                  (? (m || 0 < aft) () (take B ([no x] . ring)))
                                  (? m A (0 < aft) (aft - 1) 0))))))
                 (lp 1 hit 0 () 0))))
       ; `bad`, not `err`: err is the port, and a shadow here would say into a charm
       st (tablet 0) _ (pin st 'hit 0) _ (pin st 'bad 0)
       ; ONE trap for the whole run, not one per line. the engine is a greedy
       ; backtracker (src/love/boot/post.l), so a repeat whose atom can match a span two
       ; ways -- (a|aa)+ -- is exponential in the run's length; the engine spends a
       ; step budget on exactly those and scares when it runs out. this is where the
       ; scare becomes a sentence and a status instead of a stack. any other scare is
       ; re-raised: swallowing it here would turn a real fault into "too costly".
       _ (trap (\ _ (ureachm (\ f ((? s? 0 (say err ("grep: " + f + (udirp f ? ": Is a directory"
                                                                      ": No such file or directory")), put err 10)), pin st 'bad 1, 0))
                             (\ f first rd
                                (pin st 'hit (dof (? (f = "-") "(standard input)" f) rd
                                                       (peep st 'hit 0)), 1))
                             fs))
               ()
               (\ a b (? (a == 'regex-too-costly)
                         (flush out, say err ("grep: the pattern needs more than " + (show b)
                                        + " backtracking steps on one line -- it is the"), put err 10, say err "grep: kind an automaton walks in one pass and this engine does not (a repeat over an alternation)", put err 10, flush err, uleave 2)
                         (scare a b))))
       _ (flush out) _ (flush err)
       (? (peep st 'bad 0) 2 (peep st 'hit 0) 0 1)))
) ; module 'kore
