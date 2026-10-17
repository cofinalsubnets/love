; src/apps/kore/re.l -- grep, over the regex door in src/love/boot/post.l. this half reads
; files (u's uread/udie, text.l's lines). a toolbox file, no seat -- kore.l is its door.
(borrow 're)

(module 'kore
(borrow 'cli)
(borrow 'text)
(borrow 'glob) ; --include and --exclude
(borrow 'posix) ; readdir, for -r
(: rebre (cite 're 'rebre) reere (cite 're 'reere)      ; the four engine names grep reads
   refold (cite 're 'refold) refind (cite 're 'refind)

   ; -- grep --------------------------------------------------------------------
   ; flags ride a tablet keyed by the option charm (cli's uopt fills it), so a
   ; new one is a row here and not another leg on a tuple every caller re-spells
   (gflag t c) (peep t c 0)
   ; a pattern text -> its matchers, by the dialect and the -F/-i flags. a
   ; newline splits: GNU reads one pattern per line, which is also how -e stacks.
   ; -F is a BRE with every sigil behind a backslash
   (gnodes t txt)
    (: (lit s) (foldl (\ a c (a + (elem c (chars "\\.[*^$") ? "\\" "") + string c)) "" (chars s))
       (one s) (? (gflag t 70) (rebre (lit s)) (gflag t 69) (reere s) (rebre s))
       (go ls acc)
        (ls @ (l . more)
           (one l @ [_ m _] (go more ((gflag t 105 ? (refold m) m) . acc)) ())
           [1 (rev acc)])
       ; `lines ""` is (), but `grep ''` is one empty pattern that matches every line
       ls (lines txt)
       (go (two? ls ? ls [""]) ()))
   ; -w: the span must not sit inside a word. a word character, 'text's: ascii
   ; by the byte, past it by the character
   (gword? c) (48 <= c <= 57 || 65 <= c <= 90 || 97 <= c <= 122 || c = 95)
   (gwat ln j) (ln j @ b (b < 128 ? (gword? b) (cpword? (cpat ln j))))
   (gwbefore ln j) (ln (j - 1) @ b (b < 128 ? (gword? b) (cpword? (cpat ln (cpback ln j)))))
   ; the leftmost match of any of ms in ln at or after i, the whole line under -x and
   ; word-bounded under -w -> (1 st en) | ()
   (gfind t ms ln i)
    (: n #ln
       (bnd st en) ((st = 0 || !(gwbefore ln st)) && (en = n || !(gwat ln en)))
       ; gnu's -w walk: a span inside a word tries the longest shorter one at its start,
       ; the text cut there and no $ at the cut, then the next start
       (cut m st en) (st < en && refind [<m (m 1 | 512) (m 2)] (snip ln 0 (en - 1)) st @ [_ a b _] (a = st && a < b ? b))
       (word m st en)
        (? (bnd st en) [1 st en]
           (cut m st en @ b (b ? (word m st b)
                               (st < n && refind m ln (st + 1) @ [_ a b _] (word m a b)))))
       (hit m) (refind m ln i @ [_ a b _]
                 (? (gflag t 120) (a = 0 && b = n ? [1 a b]) (gflag t 119) (word m a b) [1 a b]))
       (best acc m)
        (hit m @ [_ st en] (? (atom? acc) [1 st en] (st < <>acc) [1 st en] acc)
          acc)
       (foldl best () ms))
   ; -e pattern (stacks), -f file, -m count, -A -B -C lines; --include and --exclude
   ; one glob each, keyed past the letters
   (grep-opt as t) (uopt as t '(101 102 109 65 66 67 1001 1002) '(101) {"include" 1001 "exclude" 1002})
   ; with -e or -f the whole tail is files; without them the first word is the pattern
   (grep-fs t o) (: eps <>o rest <>>o (two? eps || t 102 ? rest >rest))
   ; -r: the files under each operand, a directory's entries in order. a link met on
   ; the way is skipped, and followed under -R; an operand is followed either way.
   ; with no operand it is ., its names said without the ./
   (grep-tree fs R? inc exc)
    (: (want p) (ubase p "" @ b (inc && !(match inc b) || exc && match exc b ? 0 1))
       (under d pre) (foldl (\ l nm (l + walk (pre + nm) 0)) () (sort (readdir d)))
       (walk p top)
        (ukind p @ k
           (? (k = 'link && !top && !R?) ()
              (udirp p) (under p (ends? p "/" ? p (p + "/")))
              (top || want p ? [p])))
       (two? fs ? (foldl (\ l f (l + walk f 1)) () fs) (under "." "")))
   (grep-main as)
    (: t {}
       o (grep-opt as t)
       _ (two? o ? () (udie 2 "grep: bad option"))
       ; -a is accepted and read nowhere: everything here is text
       _ (uoptbad as t (chars "nvclqhaixwFEoemfrRHLsABC" + [1001 1002]) @ c
            (!c ? () (udie 2 ("grep: unknown option -" + string c))))
       eps <>o rest <>>o
       ; -f's patterns, a line each; an empty file is no pattern, which matches nothing
       fps (uoptv t 102 @ f
              (!f ? ()
                 (uread f @ r (two? r ? (lines <>r) (udie 2 ("grep: " + f + ": No such file or directory"))))))
       pats (eps + fps)
       ; with -e or -f the whole tail is files; without them the first word is the pattern
       _ (two? eps || gflag t 102 || two? rest ? ()
          (udie 2 "usage: grep [-cEFhHiLlnoqrRsvwx] [-e PAT] [-f FILE] [-m N] [-A N] [-B N] [-C N] [--include=GLOB] [--exclude=GLOB] PATTERN [FILE..]"))
       pt (? (two? pats) (ujoinc 10 pats) (gflag t 102) () <rest)
       r? (gflag t 114 || gflag t 82)
       fs0 (grep-fs t o)
       fs (r? ? (grep-tree fs0 (gflag t 82) (uoptv t 1001) (uoptv t 1002)) fs0)
       nss (string? pt ? (gnodes t pt) [1 ()])
       _ (two? nss ? () (udie 2 ("grep: invalid pattern: " + pt)))
       ast <>nss
       n? (gflag t 110) v? (gflag t 118) c? (gflag t 99) l? (gflag t 108)
       q? (gflag t 113) h? (gflag t 104) o? (gflag t 111)
       L? (gflag t 76) s? (gflag t 115)
       (count c d) (: v (uoptv t c) n (v ? (unum v) d)
                      (charm? n && 0 <= n ? n (udie 2 ("grep: invalid context length: " + v))))
       mx (uoptv t 109 @ v (v ? (uatoi v)))
       B (count 66 (count 67 0)) A (count 65 (count 67 0))
       ctx? (gflag t 65 || gflag t 66 || gflag t 67)   ; -C0 still marks the gaps
       many (? (gflag t 72) 1 h? 0 (r? || two? fs && two? >fs))
       (sel ln) ((two? (gfind t ast ln 0) ? 1 0) @ m (v? ? (m ? 0 1) m))
       (pfx label) (many ? (say out label, put out 58))
       ; one line out, c the separator (: a match, - context); with context a gap since
       ; the last line said, or a new file, is a -- row
       (line label no x c)
        (ctx? && peep st 'any 0 && (peep st 'lastf "" != label || peep st 'lastn 0 + 1 < no) ? (say out "--\n") 0,
         ctx? ? (pins st 'any 1 'lastf label 'lastn no) 0,
         many ? (say out label, put out c) 0,
         n? ? (say out (show no), put out c) 0,
         say out x, put out 10)
       ; -o: every match on the line, each on its own row. -v has nothing to show
       (emit1 label no ln)
        (: (go i)
            (gfind t ast ln i @ [_ st en]
              ; a zero-length match prints nothing (GNU's rule, and `-o '[a-z]*'`
              ; is how you meet it) -- but it still advances, or the walk sits still
              (st < en ? (pfx label, n? ? (say out (show no), put out 58), say out (snip ln st en), put out 10),
               en < #ln ? (go (en = st ? (en + 1) en)))
              ())
           (go 0))
       ; one input through the chosen face; answers the hit flag onward. a line at a
       ; time, never `lines` of the whole input; -q and -l stop at the first hit
       (dof label rd hit)
        (: (anym _) (urd-line rd @ l (atom? l ? 0 (sel <l ? 1 (anym 0))))
           (? q? (anym 0 ? 1 hit)
              l? (anym 0 ? (say out label, put out 10, 1) hit)
              L? (anym 0 ? 1 (say out label, put out 10, hit))   ; the status is still by lines
              c? (: (cnt k) (mx && mx <= k ? k
                             (urd-line rd @ l
                                (atom? l ? k (cnt (sel <l ? (k + 1) k)))))
                    k (cnt 0)
                    (pfx label,
                     say out (show k), put out 10,
                     0 < k ? 1 hit))
              ; ring: the last B lines not said, newest first, for a match to lead
              ; with; aft: how many after a match are still owed
              (: (lp no h seen ring aft)
                  (mx && mx <= seen ?
                     (: (owed k) (k <= 0 ? 0 (urd-line rd @ l (atom? l ? 0 (line label no <l 45, owed (k - 1)))))
                        (owed aft, h))
                     (urd-line rd @ l
                        (atom? l ? h
                         (: x <l
                            m (sel x)
                            ((? (m && o? && !v?) (emit1 label no x)
                                m (each (rev ring) (p \ line label <p <>p 45), line label no x 58)
                                (0 < aft) (line label no x 45)
                                ()),
                             lp (no + 1) (m ? 1 h) (m ? (seen + 1) seen)
                                (m || 0 < aft ? () (take B ([no x] . ring)))
                                (? m A (0 < aft) (aft - 1) 0))))))
                 (lp 1 hit 0 () 0))))
       ; `bad`, not `err`: err is the port, and a shadow here would say into a charm
       st {}
       (pin st 'hit 0, pin st 'bad 0,
        ureachm (f \ ((s? ? 0 (say err ("grep: " + f + (udirp f ? ": Is a directory"
                                                      ": No such file or directory")), put err 10)), pin st 'bad 1, 0))
                (\ f first rd
                   (pin st 'hit (dof (f = "-" ? "(standard input)" f) rd
                                     (peep st 'hit 0)), 1))
                fs,
        flush out, flush err,
        (? (peep st 'bad 0) 2 (peep st 'hit 0) 0 1))))
) ; module 'kore
