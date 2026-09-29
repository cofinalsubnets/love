; src/apps/kore/u.l -- the u-floor: the shared helpers every kore tool stands on, and the only
; part of kore that anything outside kore uses: text and argument plumbing. the door under
; it (uread uwrite udie uleave urun) is post.l's, so a tool outside kore reaches it too.
;
; it is its own file because of the compiler. mooncc's cat needs exactly two of these
; (ubase usplit) and nothing else in kore -- but core.l held all 53 names, so
; the whole toolbox sat in `moonfiles`, and editing the `ls` applet re-baked mooncc0.image and
; recompiled love.c and every src/love/*.c behind it. ~95 s to move a printf. The floor moved out;
; the applets are no longer the compiler's business.
;
; a body-less top-level `:` -- these names leak on purpose, which is what makes them a floor.
(module 'kore
(borrow 'posix)
; lastslash, for the two path clips below (src/love/boot/post.l)
(borrow 'path)
; cpat/cpnext/cpn, for tr's sets and wc -m (src/love/boot/post.l)
(borrow 'text)

(:
   ; -- the u-floor --
   ; decimal text -> a charm (a leading - reads negative)
   (uatoi s)
    (: n #s
       (go i acc) (i >= n ? acc (go (i + 1) ((10 * acc) + (s i - 48))))
       (? (0 < n && s 0 = 45) (0 - go 1 0) (go 0 0)))
   ; text with its sgr runs taken out, every other byte where it was. the shape a tool
   ; wants when its own output is going somewhere that is not a terminal -- a colour is
   ; for a reader, and a pipe is not one. lapiz's tty shower is what puts them in.
   (usgr s)
    (: n #s o (jug 0)
       (go i) (? (n <= i) (slurp o)
                 (i + 1 < n && s i = 27 && s (i + 1) = 91)
                  ((: (g k) (? (n <= k) (slurp o) (s k = 109) (go (k + 1)) (g (k + 1)))) (i + 2))
                 (put o (s i), go (i + 1)))
       (go 0))
   ; left-pad with spaces to width w (a wider count never shrinks), and its mirror --
   ; the columns that count from the left (ps's TTY, free's label) want the other one
   (upad w s) (#s < w ? (upad w (" " + s)) s)
   (urpad w s) (#s < w ? (urpad w (s + " ")) s)
   ; join texts with single spaces
   (ujoin a) (? (atom? a) ""
                (atom? >a) <a
                (<a + " " + ujoin >a))
   ; the many-file banner head and tail share: none before the first, a blank between
   (uhdr first f) (? first ("==> " + f + " <==\n") ("\n==> " + f + " <==\n"))
   ; the two pure line clips (lawed in test/law/kore.l). each chomps only when the source's last
   ; line actually rode through: head that cut before it ends on a line the text itself
   ; terminated, so it keeps its newline whatever the far end of the input looked like.
   (uhead n t) (: ls (lines t) k #ls cut (n < k)
                  o (unlines (? cut (take n ls) ls))
                  (cut || nl-end? t ? o (chomp o)))
   (utail n t) (: ls (lines t) k #ls
                  o (unlines (? (n < k) (drop (k - n) ls) ls))
                  (? (nl-end? t) o (chomp o)))
   ; the wc counter as a fold, so a gulp can be counted and dropped: st is
   ; [inw lines words bytes]. `inw` has to ride between gulps -- a word is a
   ; maximal ink run and one straddling the boundary counts twice without it.
   (ucount-go st s)
    (: n #s
       (ws? c) (c = 32 || 8 < c < 14)
       (go k inw l w) (n <= k ? [inw l w]
                       (s k @ c
                        (ws? c ? (go (k + 1) 0 (? (c = 10) (l + 1) l) w)
                                 (go (k + 1) 1 l (? inw w (w + 1))))))
       r (go 0 <st <>st <>>st)
       [<r <>r <>>r (<>>>st + n)])
   ; the word state is a per-byte machine; a wc that was not asked for words has no
   ; reason to run it, and one that wants only bytes has none to look at them at all
   (ucount-b st s) [<st <>st <>>st (<>>>st + #s)]
   (ucount-l sc st s)
    (: n #s
       (go k l) (: i (sc s 10 k) (i < 0 ? l (go (i + 1) (l + 1))))
       [<st (go 0 <>st) <>>st (<>>>st + n)])
   (ucount-for l? w?)
    (? w? ucount-go (? l? (ucount-l (cite 'scan 'scanner ())) ucount-b))
   ucount0 [0 0 0 0]
   ; wc -m as its own fold: st is [chars held], held the torn sequence a gulp ended in,
   ; so a character straddling the boundary counts once. a byte that begins no valid
   ; character counts nothing, and a torn one at the very end is left in held
   (ucharc-go st s)
    (: t (<>st + s) n #t
       (need b) (? (b < 194) 0 (b < 224) 2 (b < 240) 3 (b < 245) 4 0)
       (tails? k) (? (n <= k) 1 ((t k & 192) = 128) (tails? (k + 1)) 0)
       (go i m) (? (n <= i) [m ""]
                   (: w (cpn t i)
                      (? (0 < w) (go (i + w) (m + 1))
                         (n < i + need (t i) && tails? (i + 1)) [m (snip t i n)]
                         (go (i + 1) m))))
       (go 0 <st))
   ucharc0 [0 ""]
   (ucount-say st) [<>st <>>st <>>>st]      ; the state's (lines words bytes) face
   ; text -> (lines words bytes), a word a maximal ink run (lawed in test/law/kore.l)
   (ucount t) (ucount-say (ucount-go ucount0 t))
   ; the two pure path clips (basename NAME [SUFFIX] / dirname NAME; lawed in test/law/kore.l).
   ; posix's faces, not make's: trailing slashes are stripped first, and a bare name's
   ; directory is "." where make's $(dir) says "./". `chop` is that strip, and what is
   ; left is one 'glob lastslash -- the scan itself lives there.
   (uchop p) (: (e k) (? (0 < k && (p (k - 1) = 47)) (e (k - 1)) k) (e #p))
   (ubase p sfx)
    (: e0 (uchop p)
       (? (e0 = 0) (? (0 < #p) "/" "")
          (: s (snip p (lastslash (snip p 0 e0)) e0)
             m #sfx n #s
             (? (0 < m && m < n && (snip s (n - m) n = sfx))
                (snip s 0 (n - m)) s))))
   ; the process umask, read and put back
   (umask-now _) (: o (umask 18) _ (umask o) o)
   ; a tool's flags off the head of as: [t operands], every letter in `ok` and a value
   ; letter in `vals`. a stranger letter, a flag after an operand or a value flag with
   ; none refuses before anything is done; the file really called -x is `-- -x`
   (uflags who as vals ok)
    (: t (tablet 0)
       o (uopt as t vals () ())
       _ (? (two? o) () (udie 2 (who + ": an option wants a value")))
       _ (: c (uoptun t ok) (? !c () (udie 2 (who + ": unknown option -" + string c))))
       _ (: w (uoptstray as <>>o) (? !w () (udie 2 (who + ": unknown option " + w))))
       [t <>>o])
   ; a hand-walked tool's operands, refused with 2 when one still looks like a flag: its
   ; walk stops at the first word it does not know, so that word is a stranger or a flag
   ; after an operand
   (ustray who as rest) (: w (uoptstray as rest) (? !w rest (udie 2 (who + ": unknown option " + w))))
   ; octal text -> a charm ("755" is 493), chmod's one argument shape
   (uoct s) (:- (go 0 0) n #s (go i acc)
    (i >= n ? acc (go (i + 1) ((8 * acc) + (s i - 48))))
       )
   ; a mode word onto the mode cur: octal whole, or chmod's symbolic clauses, `who` of
   ; ugoa then +-= runs of rwxXst or one of ugo to copy (u+x,go-w,a=rX). no who is all
   ; three less the umask um. a directory keeps its setuid and setgid bits through = and
   ; octal, as GNU's does. () for a word that is neither
   (umode m cur dir? um)
    (: n #m
       (oct? i) (? (n <= i) 1 (48 <= m i <= 55) (oct? (i + 1)) 0)
       (base c) (? (c = 117) 64 (c = 103) 8 1)
       (over ws f) (foldl (\ a w (a | f w)) 0 ws)
       (perm ws cur c)
        (? (c = 114) (over ws (w \ 4 * base w))
           (c = 119) (over ws (w \ 2 * base w))
           (c = 120) (over ws base)
           (c = 88) (? (dir? || 0 < (cur & 73)) (over ws base) 0)
           (c = 115) ((? (elem 117 ws) 2048 0) | (? (elem 103 ws) 1024 0))
           (c = 116) (? (elem 111 ws) 512 0)
           (: v ((cur // base c) & 7) (over ws (w \ v * base w))))
       (class ws) ((over ws (w \ 7 * base w)) | (? dir? 0 (perm ws 0 115)) | perm ws 0 116)
       (who i ws) (? (i < n && elem (m i) "ugoa")
                     (who (i + 1) (m i = 97 ? (117 . 103 . 111 . ws) (m i . ws)))
                     [i ws])
       ; one clause's op runs from i to its comma or the end: [i cur], or () on a stranger
       (ops i ws mask cur)
        (? (n <= i || m i = 44) [i cur]
           !(elem (m i) "+-=") ()
           (: op (m i)
              (run j p) (? (j < n && elem (m j) "rwxXst") (run (j + 1) (p | perm ws cur (m j)))
                           (j < n && elem (m j) "ugo") [(j + 1) (p | perm ws cur (m j))]
                           [j p])
              r (run (i + 1) 0)
              b ((r 1) & mask)
              (ops (r 0) ws mask (? (op = 43) (cur | b) (op = 45) (cur - (cur & b)) ((cur - (cur & class ws)) | b)))))
       (clauses i cur)
        (: w (who i ())
           ws (? (two? (w 1)) (w 1) '(117 103 111))
           mask (? (two? (w 1)) 4095 (4095 - (4095 & um)))
           r (? (w 0 < n && elem (m (w 0)) "+-=") (ops (w 0) ws mask cur) ())
           (? !(two? r) ()
              (n <= r 0) (r 1)
              (clauses (r 0 + 1) (r 1))))
       (? (0 < n && n <= 4 && oct? 0) (uoct m | (? dir? (cur & 3072) 0)) (0 < n) (clauses 0 cur) ()))
   (udir p)
    (uchop p @
     0 (0 < #p ? "/" ".")
     e0 (lastslash (snip p 0 e0) @ 0 "."
         b0 (uchop (snip p 0 b0) @ 0 "/" z (snip p 0 z))))
   ; split at charm c, every piece kept -- "a:" is ("a" ""), "" is ("") (cut's face,
   ; where lines would drop the empty tail)
   ; the scan floor finds each separator natively; the charm walk stands in where
   ; the floor is not aboard
   (usplit c s)
    (: n #s
       sc (cite 'scan 'scanner)
       (go cite k acc) (? (n <= k) (rev (snip s cite k . acc))
                          (s k = c) (go (k + 1) (k + 1) (snip s cite k . acc))
                          (go cite (k + 1) acc))
       (fast f cite acc) (: k (f s c cite)
                            (k < 0 ? (rev (snip s cite n . acc))
                               (fast f (k + 1) (snip s cite k . acc))))
       (lit? sc ? (fast (sc ()) 0 ()) (go 0 0 ())))
   ; join with charm c between
   (ujoinc c ls)
    (: o (jug 0)
       (go m first) (? (atom? m) (slurp o)
                       ((? first () (put o c)), say o <m, go >m 0))
       (go ls 1))
   ; cut's list -> ((lo hi)..): N, N-M, N- (open above), -M (from 1)
   (uspec s)
    (: (one p)
        (: n #p
           (dash k) (k >= n ? -1 (p k @ 45 k (dash (k + 1))))
           i (dash 0)
           (i < 0 ? (uatoi p @ v [v v])
            (: lo (i @ 0 1 (uatoi (snip p 0 i)))
               hi (i + 1 = n ? 536870911 (uatoi (snip p (i + 1) n)))
             [lo hi])))
       (map one (usplit 44 s)))
   ; does 1-based seat k sit in the spec
   (upick spec k)
    (? (atom? spec) 0
     (: r <spec (k >= <r && <>r >= k || upick >spec k)))
   ; tr's set -> the code point list: a-z ranges expand, \n \t \r \0 \\ escape, a dash at
   ; either end stays literal
   (uset s)
    (: n #s
       (esc c) (c @ 110 10 116 9 114 13 48 0 c)
       (span a b acc) (b < a ? acc (span a (b - 1) (b . acc)))
       ; the POSIX classes as their C-locale spans; an unknown [:x:] stays literal
       clstab {"alpha" '((65 90) (97 122))  "alnum" '((48 57) (65 90) (97 122))
               "digit" '((48 57))           "lower" '((97 122))
               "upper" '((65 90))           "space" '((9 13) (32 32))
               "blank" '((9 9) (32 32))     "punct" '((33 47) (58 64) (91 96) (123 126))
               "print" '((32 126))          "graph" '((33 126))
               "cntrl" '((0 31) (127 127))  "xdigit" '((48 57) (65 70) (97 102))}
       (spans rs acc) (? (atom? rs) acc
                         (spans >rs (rev (span <<rs <><rs ()) + acc)))
       ; a [:name:] opening at k -> (spans past-the-]); () when it is not one
       (cls k)
        (k + 3 < n && s k = 91 && s (k + 1) = 58 ?
         (: (fin j) (? (n <= j + 1) -1
                       (s j = 58 && s (j + 1) = 93) j
                       (fin (j + 1)))
            e (fin (k + 2))
          (e >= 0 ?  (clstab (snip s (k + 2) e) @ () () rs [rs (e + 2)]))))
       (go k acc)
        (n <= k ? (rev acc)
           (: c (cpat s k) j (cpnext s k) hit (cls k)
              (? (two? hit) (go <>hit (spans <hit acc))
                 (c = 92 && j < n) (go (cpnext s j) (esc (cpat s j) . acc))
                 (j + 1 < n && s j = 45 && cpat s (j + 1) >= c)
                  (go (cpnext s (j + 1)) (rev (span c (cpat s (j + 1)) ()) + acc))
                 (go j (c . acc)))))
       (go 0 ()))
   ; --- reading an input without holding it ----------------------------------
   ; uread + `lines` keeps four whole copies of the input alive at once -- `rev` of
   ; 50 MB wanted 1.09 GB of live set. These hand it over a gulp or a line at a time.
   ; see/unsee/chug and not `swig`: kore runs in two worlds (see ucopy-bytes), and
   ; the gulp door is core's, so no probe.
   ; 'p is the unread cursor into the held bytes, 'm how far the newline scan has
   ; looked. the read-through prefix is dropped when a fill wants the room and not
   ; per line, so a line costs its own length instead of the tail behind it
   (urd q) {'q q 'h "" 'p 0 'm 0 'e 0 'sc (cite 'scan 'scanner ())}
   (urd-drop t)                                  ; let the read-through bytes go
    (peep t 'p 0 @ 0 0 p 
     (peep t 'h "" @ h (pins t 'h (snip h p #h) 'm (peep t 'm 0 - p) 'p 0)))
   ; one gulp onto the held bytes; 1 when something arrived, 0 at the end. the
   ; see/unsee pair is what terminates it -- `see` touches the device (chug never
   ; does) and the byte it answers is one chug must count, so a gulp is never empty.
   (urd-fill t)
    (: q (t 'q)
       c (see q)
       (c @ -1 (pin t 'e 1, 0)
          (unsee q c, urd-drop t, pin t 'h ((peep t 'h "") + (chug q)), 1)))
   ; the next line -> [line term?], () when spent. term? is whether the source ended
   ; it with a newline -- what `nl-end?` answers on the whole-text road.
   ; the scan mark is not an optimisation: without it the held bytes are rescanned
   ; from the front every gulp, so an input with no newline costs its length squared.
   (urd-line t)
    (: h (peep t 'h "") n #h p (peep t 'p 0) m (peep t 'm 0)
       i (t 'sc h 10 (m < p ? p m))          ; the newline, natively where it can be
       (0 <= i ? (pins t 'p (i + 1) 'm (i + 1), [(snip h p i) 1])
          (peep t 'e 0)
           (p < n ? (pins t 'h "" 'p 0 'm 0, [(snip h p n) 0]))
          (pin t 'm n, urd-fill t, urd-line t)))
   ; the gulp just read, handed over and let go; "" when the input is spent
   (urd-gulp t)
    (? (urd-fill t)
       (: h (peep t 'h "") p (peep t 'p 0)
          _ (pins t 'h "" 'p 0 'm 0)
          (p @ 0 h (snip h p #h)))
       "")
   ; a tool that stops short hands the held tail back to the port, so the next reader of
   ; stdin -- the shell's own `read`, or a child through the fd -- starts where the tool
   ; did. a gulp is one run of the port and a fill comes only when the held bytes hold no
   ; line, so what is unread at a stop lies inside the run the port still holds, which is
   ; as far as unchug reaches
   (urd-back t k) (0 < k ? (unchug (t 'q) k) 0)   ; the last k bytes of the latest gulp, back to the port
   (urd-give t)
    (: h (peep t 'h "") p (peep t 'p 0)
       _ (urd-back t (#h - p))
       (pins t 'h "" 'p 0 'm 0))

   ; --- the operand walk -----------------------------------------------------
   ; each name in turn, a miss complains and costs the status without stopping the
   ; run. no operands at all is one operand, and it is stdin.
   (uwalk one as)
    (: (go a ok) (two? a ? (go >a (one <a ok)) (flush out, !ok))
     (two? as ? (go as 1) (one "-" 1, flush out, 0)))
   ; an operand open for reading -> [port close?] | (). "-" is stdin and is not
   ; closed after: a later operand may be it again. `miss` says the complaint, because
   ; grep and sed each owe GNU a different sentence for the same failure.
   ; is the path a directory (stat follows links, like the tools want)
   (udirp q) (: st (stat q) (two? st && 16384 = 61440 & <>>st))
   ; a path's own kind, a link not followed: 'dir, 'link or 'file, () when there is none
   (ukind q) (: st (lstat q) (? (atom? st) () (: m (61440 & <>>st) (? (m = 16384) 'dir (m = 40960) 'link 'file))))
   (uin miss f)
    (? (f = "-") [in 0]
       ; a directory opens, and reading it hands back the raw getdents bytes: `cat DIR`
       ; printed them and `wc DIR` counted none, both leaving 0. it is a miss like any
       ; other -- the complaint is the caller's sentence and the status follows
       (udirp f) (miss f, ())
       (: q (open f "r") (? (hot? q) [q 1] (miss f, ()))))
   (umiss who) (f \ (say err (who + ": cannot open " + f), put err 10, 0))
   ; the driver the rest ride: body gets (name first? reader) per operand and answers
   ; truth to keep the status. first? is 1 on the leading one, all `uhdr` needs.
   (ureachm miss body as)
    (: t {'f 1}
     (uwalk (\ f ok
              (: p (uin miss f)
                 (? !p 0
                    (: fst (peep t 'f 1)
                       _ (pin t 'f 0)
                       rd (urd <p)
                       v (body f fst rd)
                       _ (? <>p (close <p) (urd-give rd))
                       (? v ok 0)))))
            as))
   (ureach who body as) (ureachm (umiss who) body as)
   ; dot gets the bytes a bufferful at a time -- for tools that do not care where
   ; the lines fall (cat)
   (uchunks who dot as)
    (ureach who
            (\ f fst rd (: (go _) (: h (urd-gulp rd) (? #h (dot h, go 0) 1))
                           (go 0)))
            as)
   ; --- the operands as one stream -------------------------------------------
   ; sed's joined lane: the line numbers and `$` run through the files, so the read
   ; has to cross them. one line of lookahead, which is the whole reason this is
   ; not `ureach` -- `$` is "no further line anywhere", and nothing shorter answers it.
   ; 'bad is read off the box after the walk: a miss cannot stop a joined stream,
   ; it only costs the status, and by then the reader has passed it.
   (urdj-box miss fs)
    {'m miss 'fs (two? fs ? fs '("-")) 'rd () 'cl () 'bad 0 'h "" 'hp 0}
   ; open the next operand; 1 when one did, 0 when the list is spent
   (urdj-step t)
    (: _ (t 'cl ? (close (t 'cl), pin t 'cl ()) 0)
       fs (t 'fs)
       (? (atom? fs) 0
        (: _ (pin t 'fs >fs)
           p (uin (t 'm) <fs)
           (? !p (pin t 'bad 1, urdj-step t)
              (pin t 'rd (urd <p), (? <>p (pin t 'cl <p) 0), 1)))))
   ; the next line ignoring the lookahead, crossing operands as it runs out of them
   (urdj-raw t)
    (: rd (t 'rd)
       l (? rd (urd-line rd))
       (? (two? l) l (urdj-step t) (urdj-raw t)))
   (urdj-line t)                            ; -> [line term? last?] | ()
    (: pk (t 'pk)
       (two? pk ?
        (: nx (urdj-raw t)
           _ (pin t 'pk nx)
           [<pk <>pk (atom? nx)])))
   ; the line face: primed, so `last?` is answerable from the first line on
   (urdj miss fs) (urdj-box miss fs @ t (pin t 'pk (urdj-raw t)))
   ; the byte face: unprimed, because priming would eat a line. od dumps rows and its
   ; offsets run through the operands, which is the same join and not the same unit.
   (urdb miss fs) (urdj-box miss fs)
   ; up to k bytes off the joined stream, "" when it is spent. 'hp is the unread
   ; cursor: od takes its rows in small bites, and re-copying the held tail behind
   ; each one costs the gulp squared
   (urdj-drop t)
    (peep t 'hp 0 @ 0 0 p
     (peep t 'h "" @ h (pins t 'h (snip h p #h) 'hp 0)))
   (urdj-take t k)
    (: (fill _) (? (k <= #(peep t 'h "") - peep t 'hp 0)  1
                   (: _ (urdj-drop t)
                      rd (t 'rd)
                      g (? rd (urd-gulp rd) "")
                      (? #g (pin t 'h (peep t 'h "" + g), fill 0)
                         (urdj-step t) (fill 0)
                         0)))
       _ (fill 0)
       h (peep t 'h "")
       p (peep t 'hp 0)
       a (#h - p)
       m (a < k ? a k)
       _ (pin t 'hp (p + m))
       (snip h p (p + m)))

   ; dot gets (line term?), one line at a time -- every tool whose whole-text body was
   ; `(go (lines t))`. dot answering 0 stops this operand, so a tool can read no
   ; further than it has to.
   (ulines who dot as)
    (ureach who
            (\ f fst rd (: (go _) (urd-line rd @ l (? (atom? l) 1 (dot <l <>l) (go 0) 1))
                           (go 0)))
            as))
) ; module 'kore
