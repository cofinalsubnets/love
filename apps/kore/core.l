; apps/kore/core.l -- the line tools, the coreutils batch of kore: cat, tac, shuf, echo,
; head, tail, wc, sort, uniq, tee, seq, yes, true, false, basename, dirname -- the
; field tools cut, tr, nl, rev -- the column tools fold, expand, unexpand, column -- and the
; encodings base64 and base32 beside tsort and factor. every tool is a
; <name>-main (the args after its name -> conversation on the ports -> the exit status,
; answered as a charm; a leave from deep inside rides udie, and urun is the door both
; come back through), dispatched by the multi-call `kore` (kore.l holds the registry). this
; file is a toolbox, not a tool: no seat of its own, kore is its door. it rides text.l's
; lines/unlines and loads right after text.l in the cat, so the capture law folds the
; real bridge here before cook.l's later `lines` leak can shadow it. a body-less
; top-level `:` -- the mains leak; everything else stays local to its define. the u-floor it
; stands on is apps/kore/u.l, which loads immediately before it (and which the mooncc cat takes
; alone -- see the note there). the GNU faces we keep exact
; (the smokes in `make test_kore` hold them to the byte): wc pads every field to the
; digit width of the byte total, uniq -c wears width 7, head/tail banner many files
; with ==> name <== and a blank line between.
(module 'kore
(borrow 'cli)
(borrow 'posix)
(borrow 'text)

(:
   ; -- cat: files (or -) onto out, verbatim -- and a DIRECTORY lists, the way ls does.
   ; POSIX cat refuses one; this cat used to open it, read nothing, and exit 0, which is
   ; the one answer of the three worth nobody's while.
   (cat-dir? f) (: st (stat f) (two? st && 16384 = 61440 & <>>st))
   ; -n numbers every line and -b those with ink, the count running across files; -s
   ; squeezes blank runs to one; -E ends a line with $, -T shows a tab as ^I, -v a control
   ; as ^X, del as ^? and a high byte as M-; -A is -vET, -e -vE, -t -vT; -u is taken. any
   ; of them reads by the line, and without them the bytes pour through untouched
   (cat-main as)
    (: fo (uflags "cat" as () "AbeEnstTuv")
       t <fo fs (fo 1)
       v? (t 118 || t 65 || t 101 || t 116)
       E? (t 69 || t 65 || t 101)
       T? (t 84 || t 65 || t 116)
       b? (t 98)
       n? (t 110 || b?)
       s? (t 115)
       st {'i 1 'blank 0 'mid 0}   ; 'mid: a file ended inside a line, which the next goes on
       (vc c) (? (c = 9) (? T? "^I" "\t")
                 !v? (string c)
                 (c < 32) ("^" + string (c + 64))
                 (c = 127) "^?"
                 (c < 128) (string c)
                 (c - 128 = 9) "M-^I"
                 ("M-" + vc (c - 128)))
       (vis l) (? (v? || T?) (cats (map vc (chars l))) l)
       (line l term?)
        (: mid (st 'mid)
           blank (#l = 0 && !mid)
           again (blank && 0 < st 'blank)
           _ (pin st 'blank (? blank 1 0))
           _ (pin st 'mid (? term? 0 1))
           (? (s? && again) 1
              (: _ (? (n? && !mid && !(b? && blank && term?)) (: i (st 'i) (say out (upad 6 (show i) + "\t"), pin st 'i (i + 1))) 0)
                 _ (say out (vis l))
                 _ (? term? (say out (? E? "$\n" "\n")) 0)
                 1)))
       (? (v? || E? || T? || n? || s?) (ulines "cat" line fs)
          (uwalk (\ f ok (? (f != "-" && cat-dir? f)
                             (each (sort (readdir f)) (n \ (puts n, putc 10)), ok)
                             (uchunks "cat" puts [f] @ 0 ok 0)))
                 fs)))

   ; -- tac: the lines back to front, a file at a time. the newline rides the line it
   ; followed, so a last line arriving without one comes back first without one --
   (utac t)                            ; text -> its records, last first
    (: n #t
       (go k st acc) (? (n <= k) (st < k ? (snip t st k . acc) acc)
                        (t k = 10) (go (k + 1) (k + 1) (snip t st (k + 1) . acc))
                        (go (k + 1) st acc))
       (go 0 0 ()))
   ; tac is the one line tool that must hold its input -- nothing can be said until
   ; the end is known. Reading it a line at a time still drops the whole-text copy and
   ; the `lines` list over it, and prepending is the reversal, so there is no rev.
   ; utac stays as the pure face test/law/kore.l holds.
   ; -- tac: each operand's records, last first. a record ends with its separator -- a
   ; newline unsaid, -s SEP, a basic regex under -r -- or opens with it under -b; the
   ; last keeps what it has, a separator or none, as GNU's does --
   (tac-cuts s sep rx)                 ; each separator's (start . end), left to right
    ; GNU's looks from the end back, each separator ending at or before the start of the
    ; last one found -- so a regex's run is cut shorter than a forward walk would cut it
    (: n #s m #sep
       RF (cite 're 'refind)
       (lit p acc) (? (p < 0) acc
                      (snip s p (p + m) = sep) (lit (p - m) ((p . p + m) . acc))
                      (lit (p - 1) acc))
       ; every place a match can start, rightmost first; then from the end back, the
       ; longest match at each that ends by the bound
       (starts i acc) (? (n <= i) acc (RF rx s i @ [_ a _ _] (starts (a + 1) (a . acc)) acc))
       (back bound cs acc)
        (? (atom? cs) acc
           (bound <= <cs) (back bound >cs acc)
           (: q <cs
              (RF rx (snip s q bound) 0 @ [_ a e _] (? (a = 0 && 0 < e) (back q >cs ((q . q + e) . acc))
                                                       (back bound >cs acc))
                                         (back bound >cs acc))))
       (? rx (back n (starts 0 ()) ()) (lit (n - m) ())))
   ; GNU's tac reads its regex in Emacs's syntax: \( \) \| are the operators and a bare
   ; ( ) | { } is itself, where ERE has it the other way; + ? are bare in both
   (tac-emacs p)
    (: n #p
       (close i) (: j0 (i + 1) j1 (? (j0 < n && p j0 = 94) (j0 + 1) j0)
                    j2 (? (j1 < n && p j1 = 93) (j1 + 1) j1)
                    (go j) (? (n <= j) n (p j = 93) (j + 1) (go (j + 1)))
                    (go j2))
       (go i acc) (? (n <= i) acc
                     (: c (p i)
                        (? (c = 91) (close i @ e (go e (acc + snip p i e)))
                           (c = 92 && i + 1 < n)
                            (: d (p (i + 1))
                               (? (elem d [40 41 124]) (go (i + 2) (acc + string d))
                                  (go (i + 2) (acc + snip p i (i + 2)))))
                           (elem c [40 41 124 123 125]) (go (i + 1) (acc + "\\" + string c))
                           (go (i + 1) (acc + string c)))))
       (go 0 ""))
   (tac-recs s ks) (:- (go 0 ks ()) ; s cut at each of ks, empty pieces dropped
    (go from ks acc) (atom? ks ? (rev (from < #s ? (snip s from #s . acc) acc))
                      (go <ks >ks (from < <ks ? (snip s from <ks . acc) acc))))
   (tac-noarg _) (udie 1 "tac: option requires an argument -- 's'")
   (tac-opts t l)                      ; -> the operands; -b -r -s take clusters and long names
    (? (atom? l) ()
       (<l = "--") >l
       (<l = "--before") (pin t 'b 1, tac-opts t >l)
       (<l = "--regex") (pin t 'r 1, tac-opts t >l)
       (<l = "--separator") (two? >l ? (pin t 's <>l, tac-opts t >>l) (tac-noarg ()))
       (12 < #<l && snip <l 0 12 = "--separator=") (pin t 's (snip <l 12 #<l), tac-opts t >l)
       (1 < #<l && <l 0 = 45 && <l 1 = 45) (udie 1 ("tac: unrecognized option '" + <l + "'"))
       (1 < #<l && <l 0 = 45)
        (:- (go 1) w <l (go k)
         (?- (udie 1 ("tac: invalid option -- '" + string (w k) + "'"))
          (#w <= k) (tac-opts t >l)
          (w k = 98) (pin t 'b 1, go (k + 1))
          (w k = 114) (pin t 'r 1, go (k + 1))
          (w k = 115) (? (k + 1 < #w) (pin t 's (snip w (k + 1) #w), tac-opts t >l)
                         (two? >l) (pin t 's <>l, tac-opts t >>l)
                         (tac-noarg ()))))
       (<l . tac-opts t >l))
   (tac-main as)
    (: t {'s "\n"}
       fs (tac-opts t as)
       sep (t 's @ v (#v ? v (string 0)))   ; an empty separator is the NUL, as GNU's
       rc (t 'r && cite 're 'reere (tac-emacs sep))
       _ (? (peep t 'r 0) (? (two? rc) 0 (udie 1 ("tac: invalid regular expression: " + sep))) 0)
       rx (two? rc ? (rc 1))
       mm (t 'b ? cap cup)
       (ureach "tac"
               (\ f first rd
                  (: j (jug 0)
                     (gulp _) (: h (urd-gulp rd) (? #h (say j h, gulp 0) 0))
                     _ (gulp 0)
                     s (slurp j)
                     ks (map mm (tac-cuts s sep rx))
                     _ (each (rev (tac-recs s ks)) (say out))
                     1))
               fs))

   ; -- shuf: the records in a random order; -e takes the operands as the records, -i
   ; LO-HI the numbers, -n caps the count, -r draws with replacement, -z splits on NUL.
   ; a partial Fisher-Yates over a tablet of swapped seats, a miss reading the seat's own
   ; record, so -i never lays its range out and -n k costs k draws.
   (ushuf n k seat dot)                ; the first k of a shuffle of seats 0..n-1, each to dot
    (: t (tablet 0)
       (at i) (peep t i (seat i))
       (go i) (? (i < k)
                 (: j (i + rand (n - i)) a (at i) b (at j)
                    _ (pin t j a) _ (pin t i b) _ (dot b)
                    (go (i + 1)))
                 0)
       (go 0))
   (shuf-main as)
    (: t (tablet 0)
       (sdie m) (udie 1 ("shuf: " + m))
       o (uopt as t '(105 110 111) ()
               {"echo" 101 "input-range" 105 "head-count" 110 "output" 111
                "repeat" 114 "zero-terminated" 122})
       _ (? (two? o) () (sdie "an option wants a value"))
       _ (: c (uoptbad as t "einorz") (? !c () (sdie ("unknown option -" + string c))))
       rest <>>o e? (peep t 101 0) r? (peep t 114 0)
       d (? (peep t 122 0) 0 10)
       ir (uoptv t 105) nv (uoptv t 110) of (uoptv t 111)
       _ (? (e? && string? ir) (sdie "cannot combine -e and -i options") ())
       _ (? (!e? && two? rest && (string? ir || two? >rest)) (sdie ("extra operand " + (string? ir ? <rest <>rest))) ())
       cap (? (string? nv) (: v (unum nv) (? (charm? v) v (sdie ("invalid line count: " + nv)))) ())
       ; the records as [count seat]: -i reads each seat off the range, the rest pin a tablet
       (laid ls) (: lt (tablet 0)
                    (go l i) (? (two? l) (pin lt i <l, go >l (i + 1)) [i (i \ (lt i))])
                    (go ls 0))
       (range s) (: n #s
                    m ((: (go i) (? (n <= i) -1 (s i = 45) i (go (i + 1)))) 0)
                    lo (0 < m ? (unum (snip s 0 m)))
                    hi (0 < m ? (unum (snip s (m + 1) n)))
                    (? (charm? lo && charm? hi && lo <= hi + 1) [(hi - lo + 1) (+ lo)]
                       (sdie ("invalid input range: " + s))))
       (input _) (: j (jug 0)
                    f (? (two? rest) <rest "-")
                    _ (uchunks "shuf" (say j) [f] @ 0 0 (uleave 1))
                    s (slurp j)
                    rs (usplit d s)
                    (? (#s && s (#s - 1) != d) rs (rev >(rev rs))))
       src (? (string? ir) (range ir) e? (laid rest) (laid (input 0)))
       n <src seat <>src
       q (? (string? of) (: h (open of "w") (? (hot? h) h (sdie ("cannot write " + of)))) out)
       (dot x) (say q (string? x ? x (show x)), put q d)
       ; with replacement: a draw a record, the count capped or forever, as yes is
       (draws k) (k @ 0 0 (dot (seat (rand n)), draws (? k (k - 1) k)))
       _ (? !r? (ushuf n (? (charm? cap) (min n cap) n) seat dot)
            (cap = 0) 0
            (n = 0) (sdie "no lines to repeat")
            (draws (? (charm? cap) cap ())))
       _ (flush q) _ (? (string? of) (close q) 0)
       0)

   ; -- echo: the args back; -n holds the newline, -e lays the escapes (u.l's, printf's
   ; %b's: \c ends it all), -E leaves them, the later winning; the letters cluster, and
   ; the first word that is not all of them is text, as GNU's reads it --
   (echo-main as)
    (: (flag? w) (1 < #w && w 0 = 45 && all (c \ elem c "neE") >(chars w))
       (go a n e) (? (two? a && flag? <a)
                     (: w <a (go >a (n || has? w "n") (: k (max (findsub w "e") -1) K (max (findsub w "E") -1) (? (k < 0 && K < 0) e (K < k) 1 0))))
                     [n e a])
       r (go as 0 0)
       n? <r e? <>r ws <>>r
       t (ujoin ws)
       x (? e? (ubexp t "echo") [t 0])
       _ (say out <x)
       _ (? (n? || <>x) 0 (put out 10))
       _ (flush out) 0)

   ; -- head and tail: one driver, two clips; -n N (10 the default) --
   ; `-5` is the obsolescent spelling and every script still writes it, so it is not
   ; optional: a bare -digits is the count. `-` alone stays the stdin name, and a flag
   ; that is neither reaches uread as a filename, exactly as it did before.
   (digits? w) (:- (go 1) n #w (go k) (? (n <= k) (1 < n) (47 < w k < 58) (go (k + 1)) 0))
   ; a count word -> [n sign], sign 1 for a written +, -1 for a written -, 0 for neither.
   ; the sign is the clip's other reading: head -n -N drops the last N, tail -n +N opens
   ; at line N. the digits may wear GNU's multipliers (b 512, k K KiB 1024, kB KB 1000,
   ; M G T the same two ways); anything else is refused by name, not read as a number.
   uclip-sfx '(("b" 512) ("k" 1024) ("K" 1024) ("KiB" 1024) ("kB" 1000) ("KB" 1000)
               ("M" 1048576) ("MiB" 1048576) ("MB" 1000000)
               ("G" 1073741824) ("GiB" 1073741824) ("GB" 1000000000)
               ("T" 1099511627776) ("TiB" 1099511627776) ("TB" 1000000000000))
   (uclip-n who what w)
    (: n #w c (? (0 < n) (w 0) 0)
       sign (? (c = 43) 1 (c = 45) -1 0)
       st (? (sign = 0) 0 1)                   ; -1 is falsy: ask, do not test
       (dend k) (? (k < n && 47 < w k < 58) (dend (k + 1)) k)
       e (dend st)
       v (? (st < e) (unum (snip w st e)) ())
       sf (snip w e n)
       m (sf @ "" 1 (filter (p \ <p = sf) uclip-sfx @ r (two? r ? <><r)))
       (charm? v && charm? m ? [(v * m) sign]
        (udie 1 (who + ": invalid number of " + what + ": '" + w + "'"))))
   ; the leading words: -n N / -nN / --lines=N, -c N / -cN / --bytes=N (the last given
   ; wins, as GNU's), the obsolescent -N, -q or -v for never or always a header, and --
   ; to end them; tail's -f, -F and -s SECS ride the header tablet. a word after them
   ; that still looks like a flag refuses
   (uclip-args who as)                      ; -> (n files many? sign bytes? hd)
    (: (val w a k) (? (k < #w) [(snip w k #w) >a]
                      (two? >a) [<>a >>a]
                      (udie 1 (who + ": option requires an argument -- '" + string (w 1) + "'")))
       hd (tablet 0)                        ; 'h: 1 for -v, 0 for -q, the later winning
       (go a n sign b?)
        (? (atom? a) [n a sign b?]
           (: w <a nw #w
              (? (w = "--") [n >a sign b?]
                 (w = "-q" || w = "--quiet" || w = "--silent") (pin hd 'h 0, go >a n sign b?)
                 (w = "-v" || w = "--verbose") (pin hd 'h 1, go >a n sign b?)
                 (who = "tail" && (w = "-f" || w = "--follow" || w = "--follow=descriptor")) (pin hd 'f 1, go >a n sign b?)
                 (who = "tail" && (w = "-F" || w = "--follow=name")) (pin hd 'f 2, go >a n sign b?)
                 (who = "tail" && w = "-s")
                  (: r (val w a 2) v (udur <r)
                     (? (charm? v) (pin hd 's v, go <>r n sign b?) (udie 1 ("tail: invalid number of seconds: '" + <r + "'"))))
                 (2 <= nw && w 0 = 45 && (w 1 = 110 || w 1 = 99))
                  (: r (val w a 2) b (w 1 = 99) q (uclip-n who (? b "bytes" "lines") <r)
                     (go <>r <q <>q b))
                 (8 < nw && snip w 0 8 = "--lines=")
                  (: q (uclip-n who "lines" (snip w 8 nw)) (go >a <q <>q 0))
                 (8 < nw && snip w 0 8 = "--bytes=")
                  (: q (uclip-n who "bytes" (snip w 8 nw)) (go >a <q <>q 1))
                 (w 0 = 45 && digits? w) (go >a (unum (snip w 1 nw)) 0 0)
                 [n a sign b?])))
       r (go as 10 0 0)
       fs (ustray who as <>r)
       [<r fs (peep hd 'h (? (two? fs && two? >fs) 1 0)) <>>r <>>>r hd])
   (uclip-hdr many first f)
    (? many (say out (uhdr first (f @ "-" "standard input" f))) 0)
   (uclip-say l) (say out <l, (? <>l (put out 10) 0))   ; a read line, its own ending
   ; head stops -- it used to `lines` the whole input and take n off the front, so
   ; one line of a 100 MB file cost 7.2 GB. uhead is still the spec for where the
   ; last newline goes (test/law/kore.l holds it); this answers the same text, a line at a time.
   (head-main as)
    (: p (uclip-args "head" as) n <p fs <>p many <>>p sign <>>>p bytes? <>>>>p
       ; -n -N is the other clip: hold a queue of N, and a line leaves only once N
       ; newer ones have come in. two stacks, so the hold costs N and not N a line.
       (drop-last rd)
        (: (go fr bk k)
            (: l (urd-line rd)
               (? (atom? l) 1
                  (: bk2 (l . bk) k2 (k + 1)
                     (k2 <= n ? (go fr bk2 k2)
                      (: f2 (two? fr ? fr (rev bk2))
                         b2 (two? fr ? bk2)
                         _ (uclip-say <f2)
                         (go >f2 b2 (k2 - 1)))))))
           (go () () 0))
       (first-n rd) (:- (go 0) (go k) (n <= k ? 1
        (urd-line rd @ l (atom? l ? 1 (uclip-say l, go (k + 1))))))
       ; -c: the first n bytes, gulp by gulp, stopping once they are out, the rest of the
       ; last gulp handed back -- or with -c -N everything but the last n, the held tail
       ; never longer than n and a gulp
       (first-b rd)
        (: (go k) (? (n <= k) 1
                     (: h (urd-gulp rd)
                        (? !#h 1
                           (: m (min #h (n - k)) _ (say out (snip h 0 m)) _ (urd-back rd (#h - m)) (go (k + m))))))
           (go 0))
       (drop-last-b rd)
        (: (go hold) (: h (urd-gulp rd)
                        (? !#h 1
                           (: t (hold + h) cut (#t - n)
                              (? (0 < cut) (say out (snip t 0 cut), go (snip t cut #t))
                                 (go t)))))
           (go ""))
       (body f first rd)
        (uclip-hdr many first f,
         (? bytes? (? (sign = -1) (drop-last-b rd) (first-b rd))
            (sign = -1) (drop-last rd) (first-n rd)))
       (ureach "head" body fs))
   ; tail cannot stop reading but need not hold: a ring of the last n lines is the
   ; whole answer. trimmed at 2n, so the trim costs n every n lines, not n a line.
   (tail-main as)
    (: p (uclip-args "tail" as) n <p fs <>p many <>>p sign <>>>p bytes? <>>>>p
       fw (peep (p 5) 'f 0) iv (peep (p 5) 's 1000)
       ; -n +N opens at line N instead, counted from 1; +0 reads as +1, as GNU has it
       (from-n rd)
        (: st (? (n < 1) 1 n)
           (go k) (: l (urd-line rd)
                     (? (! (two? l)) 1
                        ((? (st <= k) (uclip-say l) 0), go (k + 1))))
           (go 1))
       (last-n rd)
        (: (go acc k) (: l (urd-line rd)
                         (? (atom? l) acc
                          (: a2 (l . acc)
                             (2 * n <= k + 1 ? (go (take n a2) n) (go a2 (k + 1))))))
           (out1 m) (? (two? m) (uclip-say <m, out1 >m) 1)
           (out1 (rev (take n (go () 0)))))
       ; -c: the bytes the same two ways. +N skips N-1 and pours the rest; N holds the
       ; last N, the held tail never longer than N and a gulp
       (from-b rd)
        (: (go skip) (: h (urd-gulp rd)
                        (? !#h 1
                           (skip < #h) (say out (snip h skip #h), go 0)
                           (go (skip - #h))))
           (go (n < 1 ? 0 (n - 1))))
       (last-b rd)
        (: (go hold) (: h (urd-gulp rd)
                        (? !#h hold
                           (hold + h @ t (go (snip t (max 0 (#t - n)) #t)))))
           (say out (go "")))
       (body f first rd)
        (uclip-hdr many first f,
         (? bytes? (? (sign = 1) (from-b rd) (last-b rd, 1))
            (sign = 1) (from-n rd) (last-n rd)))
       ; -f: every file stays open past its tail, and what is added comes out as it
       ; lands, polled every -s. a file cut shorter reads again from its start; under -F
       ; the name is watched too, so a file replaced, or one not there yet, is opened anew.
       ; stdin is read to its end and not followed
       st {'ok 1 'last ()}
       (note m) (say err ("tail: " + m + "\n"), flush err)
       (size f) (: s (stat f) (? (two? s) [<s (s 8)] ()))
       (lay w) (: q (open (w 'f) "r") s (size (w 'f))
                  (? (hot? q) (pins w 'q q 'pos 0 'ino (? s (s 1) ())) (pin w 'q ())))
       (drain w got)
        (: q (w 'q) c (? q (see q) -1)
           (? (c < 0) got
              (: b (unsee q c, chug q)
                 _ (? (many && !(st 'last = w 'f)) (say out ((? (st 'last) "\n" "") + "==> " + w 'f + " <==\n")) 0)
                 _ (pins st 'last (w 'f)) _ (say out b) _ (flush out)
                 _ (pin w 'pos (w 'pos + #b))
                 (drain w 1))))
       (check w)
        (: f (w 'f) s (size f)
           (? (!(w 'q) && s) (: _ (note ("'" + f + "' has appeared;  following new file")) (lay w))
              !s (? (w 'q && fw = 2) (: _ (note ("'" + f + "' has become inaccessible")) _ (close (w 'q)) (pin w 'q ())) 0)
              (<s < w 'pos) (: _ (note (f + ": file truncated")) _ (close (w 'q)) (lay w))
              (fw = 2 && !(s 1 = w 'ino)) (: _ (note ("'" + f + "' has been replaced;  following new file")) _ (close (w 'q)) (lay w))
              0))
       (follow ws) (: got (foldl (\ a w (? (drain w 0) 1 a)) 0 ws)
                      _ (each ws check)
                      _ (? got 0 (rest iv))
                      (follow ws))
       (open1 f first)
        (: p (? (f = "-") [in 0] (uin (umiss "tail") f))
           (? !p (: _ (pin st 'ok 0) (? (fw = 2 && !(f = "-")) {'f f 'q () 'pos 0 'ino ()} ()))
              (: _ (body f first (urd <p))
                 _ (pins st 'last f)
                 s (size f)
                 (? (f = "-") () {'f f 'q <p 'pos (? s <s 0) 'ino (? s (s 1) ())}))))
       (ws0 l first acc) (? (atom? l) (rev acc) (: w (open1 <l first) (ws0 >l 0 (? w (w . acc) acc))))
       (? fw (: ws (ws0 (? (two? fs) fs ["-"]) 1 ()) _ (flush out) (? (two? ws) (follow ws) (? (st 'ok) 0 1)))
          ; a count of 0 is GNU's early leave: nothing said, no file opened, 0
          (n = 0 && !(sign = 1)) 0
          (ureach "tail" body fs)))

   ; -- wc: lines, words, characters, bytes (flags pick; bare wc reads lines words bytes) --
   (wc-main as)
    ; the flags cluster, as GNU's do: -lw is the two of them and not a filename
    (: (fl a l w m c x)
        (atom? a ? [l w m c x a]
         (: g <a n #g
          (2 > n || g 0 != 45 ? [l w m c x a]
           (:- (cl 1 l w m c x) (cl k L W M C X)
            (n <= k ? (fl >a L W M C X)
             (g k @ 108 (cl (k + 1) 1 W M C X)
                    119 (cl (k + 1) L 1 M C X)
                    109 (cl (k + 1) L W 1 C X)
                    99 (cl (k + 1) L W M 1 X)
                    76 (cl (k + 1) L W M C 1)
                    [l w m c x a])))))) ; an unknown charm: the word is not ours
       p (fl as 0 0 0 0 0)
       none !(<p || <>p || <>>p || <>>>p || p 4)
       l? (? none 1 <p) w? (? none 1 <>p) m? <>>p c? (? none 1 <>>>p) x? (p 4)
       fs (ustray "wc" as (p 5))
       ; -L: the widest line in columns, GNU's way -- a tab to the next stop of 8, a
       ; newline, return or form feed ends one, a character its display width. the
       ; state [col widest] runs across gulps
       (xcnt st h) (? !x? st
                      (: n #h
                         (go i col top) (? (n <= i) [col top]
                                           (: b (h i)
                                              (? (b = 10 || b = 13 || b = 12) (go (i + 1) 0 (max top col))
                                                 (b = 9) (go (i + 1) (col + 8 - col % 8) top)
                                                 (b < 32 || b = 127) (go (i + 1) col top)
                                                 (b < 128) (go (i + 1) (col + 1) top)
                                                 (: j (cpnext h i) (go j (col + swidth (snip h i j)) top)))))
                         (go 0 <st <>st)))
       (c3 x) <>>x (c4 x) <>>>x
       ; a row is (name (l w b m)), name () for stdin. counted a gulp at a time --
       ; nothing here needs the text, only the numbers off it
       cnt (ucount-for l? w?)
       (mcnt st h) (? m? (ucharc-go st h) st)
       st (tablet 0) _ (pin st 'rows ()) _ (pin st 'ok 1)
       _ (ureachm (f \ (say err ("wc: cannot open " + f), put err 10,
                          pin st 'ok 0, 0))
                  (\ f first rd
                     (: (go acc ma xa) (: h (urd-gulp rd) (? #h (go (cnt acc h) (mcnt ma h) (xcnt xa h)) [acc ma xa]))
                        r (go ucount0 ucharc0 [0 0])
                        c (ucount-say <r + [<<>r (max (<(r 2)) (<>(r 2)))])
                        _ (pin st 'rows ([(? (two? fs) f ()) c] . st 'rows))
                        1))
                  fs)
       rows (rev (st 'rows)) ok (peep st 'ok 0)
       (sum sel a acc) (? (two? a) (sum sel >a (acc + sel <><a)) acc)
       tl (sum cap rows 0) tw (sum caup rows 0) tb (sum c3 rows 0) tm (sum c4 rows 0)
       tx (foldl (\ m r (max m (<>r 4))) 0 rows)                    ; -L's total is the widest
       ; the GNU face: pad every column to the byte total's width, even where the
       ; bytes are not printed (`wc -lw` of a 3001-byte file wears width 4).
       ; one count over one input wears none -- `wc -l f` is "1 f", never "   1 f".
       ; a one-digit byte count hides this, which is every fixture until .gs1.
       wdt (? (!!l? + !!w? + !!m? + !!c? + !!x? = 1 && atom? >rows)
              1 #(show tb))
       ; GNU's column order: lines words characters bytes, the widest line
       (fmt cnt) (: a (? x? [(upad wdt (show (cnt 4)))] ())
                    a (? c? (upad wdt (show (c3 cnt)) . a) a)
                    a (? m? (upad wdt (show (c4 cnt)) . a) a)
                    a (? w? (upad wdt (show <>cnt) . a) a)
                    a (? l? (upad wdt (show <cnt) . a) a)
                    (ujoin a))
       (emit rs) (two? rs ?
                    (: row <rs
                     (say out (fmt <>row),
                      <row && say out (" " + <row),
                      put out 10,
                      emit >rs)))
       _ (emit rows)
       _ (two? rows && two? >rows ?
          (say out (fmt [tl tw tb tm tx]), say out " total", put out 10))
       _ (flush out) (? ok 0 1))

   ; -- sort ----------------------------------------------------------------------
   ; the prel sort is byte order (the LC_ALL=C face) and `sortby` under it is a stable
   ; merge, which is what lets -s mean anything. flags: -b -f -n -r -s -u, -t SEP, and
   ; -k F[,M][bfnr] as often as wanted. a key carrying any ordering letter of its own
   ; uses those INSTEAD of the global ones, which is GNU's rule and not an addition to
   ; them. equal keys fall to the last-resort compare -- the whole line, bytewise --
   ; unless -s or -u, neither of which wants it.
   ; absent, and said so rather than half-done: -k's .CHAR offsets and the -M -g -R
   ; orderings. a key is [F M b f n r h V], its letters' flags after its fields.
   (usort-blank? c) (c = 32 || c = 9)
   ; a line's fields as [start end] pairs. under the DEFAULT separator the blanks
   ; BEFORE a run belong to the run -- GNU's rule, and the whole reason -b exists;
   ; trailing blanks close no field. under -t the separator is one charm and belongs
   ; to neither side, so an empty field is a real one.
   (usort-flds ln sep)
    (: n #ln
       (run j) (n <= j || usort-blank? (ln j) ? j (run (j + 1)))
       (bl st i) (? (n <= i) ()
                    (usort-blank? (ln i)) (bl st (i + 1))
                    (: e (run i) ([st e] . bl e e)))
       (tt st i) (? (n <= i) [[st n]]
                    (ln i = sep) ([st i] . tt (i + 1) (i + 1))
                    (tt st (i + 1)))
       (charm? sep ? (tt 0 0) (bl 0 0)))
   ; the text a key names: the start of field f through the end of field m, or the
   ; line's end when m is absent. b? drops the leading blanks of the first field.
   (usort-key ln flds f m b?)
    (: nf #flds
       (? (f < 1 || nf < f) ""
          (: st <(flds (f - 1))
             en (m < 1 || nf < m ? #ln <>(flds (m - 1)))
             (sk i) (en <= i || !(usort-blank? (ln i)) ? i (sk (i + 1)))
             s2 (? b? (sk st) st)
             (en <= s2 ? "" (snip ln s2 en)))))
   (usort-up s) (: n #s o (jug 0)
                   (go k) (n <= k ? (slurp o)
                             (: c (s k) (put o (97 <= c <= 122 ? (c - 32) c), go (k + 1))))
                   (go 0))
   ; -n reads a VALUE, and reads it exactly: 10000000000000000001 sorts above ...0
   ; and no double can say so. the reading is the digits -- sign, then the integer
   ; part's length, then its digits, then the fractions padded against each other.
   (usort-num s)                               ; -> [neg int frac], both parts trimmed
    (: n #s
       (sk i) (n <= i || !(usort-blank? (s i)) ? i (sk (i + 1)))
       i0 (sk 0)
       neg (i0 < n && s i0 = 45)
       i1 (? neg (i0 + 1) i0)
       (dig j) (? (n <= j || !(48 <= s j <= 57)) j (dig (j + 1)))
       i2 (dig i1)
       ip (snip s i1 i2)
       dot (i2 < n && s i2 = 46)
       i3 (? dot (dig (i2 + 1)) i2)
       fp (? dot (snip s (i2 + 1) i3) "")
       (lead k) (#ip <= k || ip k != 48 ? k (lead (k + 1)))
       (trail k) (k < 1 || fp (k - 1) != 48 ? k (trail (k - 1)))
       [neg (snip ip (lead 0) #ip) (snip fp 0 (trail #fp))])
   (usort-cmpnum pa pb)                        ; two usort-num readings -> -1 | 0 | 1
    (: ia <>pa fa <>>pa ib <>pb fb <>>pb
       sa (? (!#ia && !#fa) 0 (<pa ? -1 1))
       sb (? (!#ib && !#fb) 0 (<pb ? -1 1))
       (lex k) (? (#ia <= k) 0 (ia k < ib k) -1 (ib k < ia k) 1 (lex (k + 1)))
       (frc k) (? (#fa <= k && #fb <= k) 0
                  (: ca (? (k < #fa) (fa k) 48) cb (? (k < #fb) (fb k) 48)
                     (? (ca < cb) -1 (cb < ca) 1 (frc (k + 1)))))
       ; never `(? r r ..)` on a comparison: -1 is FALSY here (a predicate is the sign
       ; of the net), so a "less than" would fall through to the next test as if equal.
       m (? (#ia < #ib) -1 (#ib < #ia) 1 (: r (lex 0) (r @ 0 (frc 0) r)))
       (? (sa < sb) -1 (sb < sa) 1 (sa < 0) (0 - m) m))
   (usort-cmpstr a b) (? (a < b) -1 (b < a) 1 0)
   ; one key's reading of a line, taken ONCE per line and not per comparison: the
   ; text, folded, or the numeric reading, per the key's own letters
   (usort-keyof ln k sep)
    (: f <k m <>k b? (k 2) f? (k 3) n? (k 4)
       t (? f (usort-key ln (usort-flds ln sep) f m b?)
            b? (: n #ln
                  (sk i) (? (n <= i || !(usort-blank? (ln i))) i (sk (i + 1)))
                  (snip ln (sk 0) n))
            ln)
       (? n? (usort-num t) (k 6) (usort-hnum t) (k 7) (usort-ver t) f? (usort-up t) t))
   ; -h reads a number with its unit, and orders by the unit first, as GNU's: 1M above
   ; 1500K. the reading is -n's, of the rank before the digits
   (usort-hnum s)
    (: p (usort-num s) n #s
       (sk i) (? (n <= i || !(usort-blank? (s i) || s i = 45 || s i = 46 || 48 <= s i <= 57)) i (sk (i + 1)))
       u (: i (sk 0) (? (i < n) (findsub "KMGTPEZY" (string (? (s i = 107) 75 (s i)))) -1))
       (? (!#(p 1) && !#(p 2)) p [(p 0) (show (u + 1) + zpad 40 (p 1)) (p 2)]))
   ; -V reads runs: text, number, text, number.. so 1.10 comes after 1.9
   (usort-ver s)
    (: n #s
       (dig? i) (48 <= s i <= 57)
       (run i d) (? (n <= i || !(dig? i = d)) i (run (i + 1) d))
       (go i d acc) (? (n <= i) (rev acc)
                       (: j (run i d) v (snip s i j) (go j !d ((? d (unum v) v) . acc))))
       (go 0 0 ()))
   (usort-numk? k) (k 4 || k 6)
   (usort-cmp1 ka kb k)                        ; two readings under key k -> -1 | 0 | 1
    (: c (usort-numk? k ? (usort-cmpnum ka kb) (usort-cmpstr ka kb)) (k 5 ? -c c))
   (sort-main as)
    (: (sdie m) (udie 2 ("sort: " + m))
       ; the flags in gnu order, a flag free to follow a file: -k takes a value and
       ; stacks, -t a separator glued or not, -o a file; the long names ride the same keys
       t (tablet 0)
       o (uoptp as t '(107 116 111) '(107)
                {"reverse" 114 "numeric-sort" 110 "human-numeric-sort" 104 "version-sort" 86
                 "unique" 117 "stable" 115 "ignore-case" 102 "ignore-leading-blanks" 98 "check" 99
                 "zero-terminated" 122 "merge" 109 "output" 111 "key" 107 "field-separator" 116})
       _ (? (two? o) () (sdie "an option wants a value"))
       _ (: c (uoptbad as t "bcCfhkmnorstuVz") (? !c () (sdie ("unknown option -- " + string c))))
       _ (: w (o 3) (? !w () (sdie ("unknown option " + w))))
       (fl c) (peep t c 0)
       b? (fl 98) f? (fl 102) n? (fl 110) r? (fl 114) s? (fl 115) u? (fl 117) h? (fl 104) V? (fl 86)
       c? (fl 99) C? (fl 67) z? (fl 122)
       sep (: v (uoptv t 116) (? !v () !#v (sdie "-t wants a separator") (v 0)))
       kt (o 1) fs (o 2)
       of (uoptv t 111)
       ; a key spec: F[,M] with the ordering letters glued to either number
       (kspec s)
        (: n #s
           (num i) (: (go j) (? (n <= j || !(48 <= (s j) <= 57)) j (go (j + 1))) (go i))
           (opt i B F N R H V)                 ; the letters trailing a number
            (? (n <= i || (s i = 44)) [i B F N R H V]
               ((s i) @
                98  (opt (i + 1) 1 F N R H V)
                102 (opt (i + 1) B 1 N R H V)
                110 (opt (i + 1) B F 1 R H V)
                114 (opt (i + 1) B F N 1 H V)
                104 (opt (i + 1) B F N R 1 V)
                86  (opt (i + 1) B F N R H 1)
                c   (sdie ("unknown key letter -- " + string c))))
           e1 (num 0)
           _ (? (e1 < 1) (sdie ("bad key -- " + s)) ())
           f (uatoi (snip s 0 e1))
           o1 (opt e1 0 0 0 0 0 0)
           (? (#s <= <o1) [f 0 (o1 1) (o1 2) (o1 3) (o1 4) (o1 5) (o1 6)]
              (: rest (snip s (<o1 + 1) n)
                 nr #rest
                 (num2 j) (? (nr <= j || !(48 <= rest j <= 57)) j (num2 (j + 1)))
                 e2 (num2 0)
                 _ (e2 < 1 && sdie ("bad key -- " + s))
                 m (uatoi (snip rest 0 e2))
                 ; the second half's letters count for the whole key too, GNU-style
                 (opt2 i B F N R H V)
                  (nr <= i ? [B F N R H V]
                     (rest i @
                      98  (opt2 (i + 1) 1 F N R H V)
                      102 (opt2 (i + 1) B 1 N R H V)
                      110 (opt2 (i + 1) B F 1 R H V)
                      114 (opt2 (i + 1) B F N 1 H V)
                      104 (opt2 (i + 1) B F N R 1 V)
                      86  (opt2 (i + 1) B F N R H 1)
                      c   (sdie ("unknown key letter -- " + string c))))
                 ; the two halves do NOT carry the same letters. n/r/f on either
                 ; half order the whole key, but `b` names a POSITION: on the start
                 ; spec it skips the field's leading blanks, on the end spec it is
                 ; about where the key stops. so -k1b,1 strips and -k1,1b does not,
                 ; and folding them together silently sorted `-k1,1b` on the wrong key.
                 ; the end spec's b is read and dropped -- trailing blanks are not
                 ; modelled here, and inventing a meaning for it would be worse.
                 o2 (opt2 e2 0 (o1 2) (o1 3) (o1 4) (o1 5) (o1 6))
                 [f m (o1 1) (o2 1) (o2 2) (o2 3) (o2 4) (o2 5)])))
       ; a key with no letters of its own takes the global ones; one with any letter
       ; takes only its own. that is GNU's rule, and it is why -k2,2 -n is not -k2,2n.
       (glob k) (k 2 || k 3 || k 4 || k 5 || k 6 || k 7 ? k [<k <>k b? f? n? r? h? V?])
       keys (? (two? kt) (map (glob * kspec) kt) [[0 0 b? f? n? r? h? V?]])
       ; the lines off the reading floor: prel's `lines` walks a charm at a time and
       ; costs more than the sort does. a miss has said its piece; sort still leaves
       ; -z's records end with a NUL, read whole and cut
       (rd fs) (? z? (: t (cats (map (f \ (? (f = "-") (slurp in) (: r (uread f) (? (two? r) <>r (sdie ("cannot read: " + f)))))) (? (two? fs) fs ["-"])))
                        ps (usplit 0 t)
                        (? (two? ps && <(rev ps) = "") (rev >(rev ps)) ps))
                  (: box (tablet 0)
                     (dot ln term?) (pin box 'l (ln . box 'l), 1)
                     st (ulines "sort" dot fs)
                     _ (st @ 0 0 (uleave 2))
                     (rev (box 'l))))
       ; the comparison: every key in turn, then the last-resort whole-line compare.
       ; -r is already inside each key (glob hands it down), so it must NOT also
       ; reverse the output -- doing both is the identity, and the first draft of this
       ; sorted correctly and then undid it. the last resort is the one place -r still
       ; has to be applied by hand.
       ; -s and -u BOTH drop the last resort -- -s because that is what stable means
       ; here, and -u because a dedupe reading the whole line would keep two lines that
       ; the keys call equal, which is the opposite of what was asked.
       (last a b) (usort-cmpstr a b @ c (? r? -c c))
       ; a line rides decorated: [index line readings], one reading per key, taken once.
       ; the same falsy trap as usort-cmpnum's: `(? c c (go >ks))` sends every
       ; less-than on to the next key, and `!(cmp ..)` calls it equal. both readings
       ; have to ask `= 0` out loud.
       (cmp da db) (: (go ks xa xb) (? (atom? ks) (? (s? || u?) 0 (last (da 1) (db 1)))
                                       (: c (usort-cmp1 <xa <xb <ks) (c @ 0 (go >ks >xa >xb) c)))
                      (go keys (da 2) (db 2)))
       ; an equal pair drops the SECOND, never the first: `(ded >a)` walks off the
       ; head and leaves the run's LAST line standing, where GNU keeps its first.
       (same? da db) (? plain? (da 1 = db 1) (0 = cmp da db))
       (ded a) (? (atom? a) ()
                  (atom? >a) a
                  (same? <a <>a) (ded (<a . >>a))
                  (<a . ded >a))
       ls (rd fs)
       ; no key and no letter is byte order, and that is prel's `sort` -- the C lane,
       ; stable, and the whole line is the key so -r is the reverse; -u still dedupes
       plain? ((atom? kt) && !b? && !f? && !n? && !h? && !V?)
       ; the keyed C lane: prel's sort orders lists lexicographically, exactly (bigs)
       ; and stably, so a line decorated [reading.. tiebreak] sorts under every key at
       ; once. one direction has to serve the lot -- a numeric reading reverses by
       ; negation, a text cannot -- so the text keys and the last resort pick it, and a
       ; text key against the grain takes the merge lane below instead.
       tkeys (filter (\ k !(usort-numk? k)) keys)
       dir (? (two? tkeys) (<tkeys 5) (!(s? || u?)) r? 0)
       clane? (foldl (\ a k (a && (k 5 = dir))) 1 tkeys &&
               ((s? || u?) || r? = dir))
       ; a numeric reading as a sortable triple: the sign class, the integer (negated
       ; when negative), and the fraction's digits -- complemented when negative, so
       ; the byte order of the trimmed digits is the numeric one either way
       (ncomp s) (: n #s o (jug 0)
                    (go k) (? (n <= k) (slurp o) (put o (105 - (s k)), go (k + 1)))
                    (go 0))
       (ntrip p flip) (: neg <p ip <>p fp <>>p
                         sc (? (!#ip && !#fp) 0 neg -1 1)
                         iv (? #ip <(sound ip) 0)
                         v (? neg (0 - iv) iv)
                         fr (? neg (ncomp fp) fp)
                         (? flip [(0 - sc) (0 - v) (ncomp fr)] [sc v fr]))
       (creading ln k) (: r (usort-keyof ln k sep)
                          (? (usort-numk? k) (ntrip r (k 5 != dir)) r))
       (cdeco l) (: (go l i acc)
                     (atom? l ? (rev acc)
                      (go >l (i + 1)
                       (map (creading <l) keys + [(s? || u? ? (dir ? -i i) <l) <l] . acc)))
                    (go l 0 ()))
       (clast p) (? (two? >p) (clast >p) <p)
       ; -u picks a representative of each equal run, and GNU picks the input's first:
       ; the index rides along as the last tiebreak, which is stability stated outright
       ; rather than hoped for from the sort underneath.
       (deco l) (: (go l k acc)
                    (? (atom? l) (rev acc)
                       (go >l (k + 1) ([k <l (map (key \ usort-keyof <l key sep) keys)] . acc)))
                   (go l 0 ()))
       ; -c and -C: is it sorted already -- the first line out of order said (-c) and 1,
       ; under -u a line equal to the one before it out of order too
       (check _) (: (go l k) (? (atom? l || atom? >l) 0
                                (: c (cmp <l <>l)
                                   (? (0 < c || (u? && c = 0))
                                      (: _ (? c? (say err ("sort: " + (? (two? fs) <fs "-") + ":" + show (k + 1) + ": disorder: " + (<>l 1) + "\n")) 0)
                                         _ (flush err) 1)
                                      (go >l (k + 1)))))
                    (go (deco ls) 1))
       ; -o's file opens after the reading, so it may be one of the inputs, as GNU allows
       (emit s1) (: q (? of (: q (open of "w") (? (hot? q) q (sdie ("cannot create " + of)))) out)
                    _ (say q (? z? (cats (map (l \ l + string 0) s1)) (unlines s1)))
                    _ (flush q) _ (? of (close q) 0) 0)
       (? (c? || C?) (check 0)
          (: s1 (? plain? (: s0 (sort ls) (? r? (rev s0) s0))
                   clane? (: s0 (map clast (sort (cdeco ls))) (? dir (rev s0) s0))
                   (map (p \ p 1)
                        (sortby (x \ y \ cmp x y @ 0 (<x <= <y) c (c < 0)) (deco ls))))
             (emit (? u? (map (p \ p 1) (ded (deco s1))) s1)))))

   ; -- uniq: adjacent runs to their firsts; -c wears the run count, width 7; -d says only
   ; the runs of two or more, -u only the lone lines; -i, -f N and -s N compare past N
   ; fields and then N characters, case aside. INPUT and OUTPUT --
   (uniq-main as)
    (: fo (uflags "uniq" as '(102 115) "cdfisu")
       t <fo fs (fo 1)
       c? (t 99) d? (t 100) u? (t 117) i? (t 105)
       (count c) (: v (uoptv t c) n (? v (unum v) 0)
                    (? (charm? n && 0 <= n) n (udie 1 ("uniq: invalid number: '" + v + "'"))))
       nf (count 102) ns (count 115)
       _ (? (atom? >>fs) () (udie 2 "usage: uniq [-cdiu] [-f N] [-s N] [INPUT [OUTPUT]]"))
       o (? (two? >fs) (: q (open <>fs "w") (? (hot? q) q (udie 1 ("uniq: cannot write " + <>fs)))) out)
       (blank? c) (c = 32 || c = 9)
       (field l i) (: n #l
                      (sp i) (? (i < n && blank? (l i)) (sp (i + 1)) i)
                      (ink i) (? (i < n && !(blank? (l i))) (ink (i + 1)) i)
                      (ink (sp i)))
       (skipf l k i) (? (k = 0) i (skipf l (k - 1) (field l i)))
       (key l) (: i (min #l (skipf l nf 0 + ns)) s (snip l i #l)
                  (? i? (lower s) s))
       plain? !(i? || 0 < nf || 0 < ns)
       (emit line cnt) (? ((d? && cnt < 2) || (u? && 1 < cnt)) ()
                          ((? c? (say o (upad 7 (show cnt) + " ")) ()),
                           say o line, put o 10))
       ; adjacent runs, so one line of memory is the whole state -- the run's first,
       ; its key, and how many have matched it
       _ (ureachm (f \ (udie 2 ("uniq: cannot open " + f)))
                  (\ f first rd
                     (:- (go () () 0) (go prev pk cnt)
                      (: l (urd-line rd)
                       (? (atom? l) (0 < cnt ? (emit prev cnt) (), 1)
                        (: x <l k (? plain? x (key x))
                         (? (cnt = 0) (go x k 1)
                            (k = pk) (go prev pk (cnt + 1))
                            (emit prev cnt, go x k 1)))))))
                  (two? fs ? [<fs]))
       _ (flush o) _ (? (two? >fs) (close o) 0) 0)

   ; -- tee: stdin onto out and every file (-a appends) --
   ; -i ignores an interrupt, as GNU's; -p is taken -- love ignores SIGPIPE from the
   ; start, so a pipe that closes never ends tee and the rest still take what comes
   (tee-main as)
    (: fo (uflagsl "tee" as () "aip" {"append" 97 "ignore-interrupts" 105 "output-error" 112})
       t <fo a? (peep t 97 0) fs (fo 1)
       _ (? (t 105) (signal 2 1) 0)
       ; every destination opens up front. tee is a pipe, and a pipe cannot wait
       ; for the end of its input to start writing -- it used to slurp stdin whole.
       (opn l acc ok)
        (? (atom? l) [(rev acc) ok]
           (: q (open <l (? a? "a" "w"))
              (? (hot? q) (opn >l (q . acc) ok)
                 (say err ("tee: cannot open " + <l), put err 10,
                  opn >l acc 0))))
       r (opn fs () 1)
       qs <r ok <>r
       (each1 l h) (two? l ? (say <l h, each1 >l h) 0)
       _ (uchunks "tee" (h \ (each1 qs h, puts h, 1)) ())
       (clo l) (two? l ? (close <l, clo >l) 0)
       _ (clo qs)
       _ (flush out) (? ok 0 1))

   ; -- seq: FIRST INCR LAST, exact: each is an integer and its decimals, the walk runs
   ; scaled by the most decimals any has, and each line wears as many as FIRST and INCR
   ; do (GNU's rule: seq 0 0.5 1 is 0.0 0.5 1.0). -w pads to the widest with zeros, -s
   ; puts SEP between, -f formats each through printf. a leading word that reads as a
   ; number (-5, -.5) ends the flags, so a negative FIRST is not one --
   (useqd w)                                   ; -> [int scale] | ()
    (: neg (0 < #w && w 0 = 45) b (? (0 < #w && (w 0 = 45 || w 0 = 43)) (snip w 1 #w) w)
       k (findsub b ".") ip (? (k < 0) b (snip b 0 k)) fp (? (k < 0) "" (snip b (k + 1) #b))
       ds (ip + fp)
       (? (0 < #ds && all digit? (chars ds)) [(? neg (0 - unum ds) (unum ds)) #fp] ()))
   (seq-main as)
    (: (numw? w) (1 < #w && (w 0 = 45 || w 0 = 43) && (digit? (w 1) || w 1 = 46))
       ; -s and -f with their value in the next word take it along
       (val? w) (1 < #w && !(w 1 = 45) && (w (#w - 1) = 115 || w (#w - 1) = 102))
       k ((: (g i) (? (#as <= i) i (: w (as i) (? (w = "--" || !(0 < #w && w 0 = 45) || numw? w) i (val? w) (g (i + 2)) (g (i + 1)))))) 0)
       fo (uflagsl "seq" (take k as) '(115 102) "wsf" {"separator" 115 "format" 102 "equal-width" 119})
       t <fo
       ops (: r (drop k as) (? (two? r && <r = "--") >r r))
       n #ops
       ns (map useqd ops)
       _ (? (0 < n && n <= 3 && all two? ns) () (udie 2 "usage: seq [-w] [-s SEP] [-f FMT] [FIRST [INCR]] LAST"))
       trip (n @ 1 [[1 0] [1 0] (ns 0)]
                 2 [(ns 0) [1 0] (ns 1)]
                 [(ns 0) (ns 1) (ns 2)])
       P (max (<>(trip 0)) (max (<>(trip 1)) (<>(trip 2))))
       p (max (<>(trip 0)) (<>(trip 1)))
       (up x) (<x * ((P - <>x) 10))                ; a reading at scale P (n x is x ** n)
       a (up (trip 0)) d (up (trip 1)) z (up (trip 2))
       _ (d @ 0 (udie 2 "seq: increment must not be 0"))
       q ((P - p) 10)
       (txt v) (: u (v // q) m (? (u < 0) (0 - u) u) b (p 10)
                  ((? (u < 0) "-" "") + show (m // b) + (? (0 < p) ("." + zpad p (show (m % b))) "")))
       last (? (0 < d) (? (z < a) a (a + ((z - a) // d) * d)) (? (a < z) a (a - ((a - z) // (0 - d)) * (0 - d))))
       wd (max #(txt a) #(txt last))
       (padw s) (? (#s < wd) (? (s 0 = 45) ("-" + zpad (wd - 1) (snip s 1 #s)) (zpad wd s)) s)
       sep (? (t 115) (uoptv t 115) "\n")
       ff (uoptv t 102)
       pf (? ff (cite 'kore 'printf-main) ())
       (one v) (: s (txt v) (? ff (pf [ff s]) (say out (? (t 119) (padw s) s))))
       (go i first) (? (0 < d ? (i <= z) (z <= i))
                       (: _ (? first 0 (say out sep)) _ (one i) (go (i + d) 0))
                       (? first 0 (say out "\n")))
       _ (go a 1) _ (flush out) 0)

   ; -- yes: the affirmative, forever (args override the y) --
   (yes-main as0)
    (: as ((uflags "yes" as0 () "") 1)
       w (two? as ? (ujoin as) "y")
       (go _) (say out w, put out 10, flush out, go ())
       (go ()))

   ; -- true and false: the two exit codes, nothing else --
   (true-main _) 0
   (false-main _) 1

   ; -- test / [ : the POSIX condition. it must exist as a program. cook's in-image
   ; lane execs a recipe's words directly, so `test` is no shell builtin there: a
   ; `.. > $t && test -s $t && mv $t $@` recipe looks it up on PATH, and a missing one
   ; fails the link with the tmp file already swept -- which is exactly how a 0-byte
   ; lcat header reads as a broken bootstrap. 0 true, 1 false, 2 a bad expression.
   t-fops '("-e" "-f" "-d" "-s" "-r" "-w" "-x" "-b" "-c" "-p" "-S" "-h" "-L" "-u" "-g" "-k")
   t-nops '("-eq" "-ne" "-lt" "-le" "-gt" "-ge")
   (t-int s)                                   ; "-12" -> (1 -12); anything else -> ()
    (: n #s
       neg (0 < n ? (s 0 = 45) 0)
       st (? neg 1 0)
       (go k acc) (? (n <= k) [1 acc]
                     (: c (s k) (? (c < 48 || 57 < c) ()
                                   (go (k + 1) (acc * 10 + c - 48)))))
       (n > st ? (go st 0 @ r (two? r ? [1 (? neg -<>r <>r)]))))
   ; the stat tuple is (size mtime mode ..); 61440 masks the kind, 32768 a file, 16384 a dir
   (t-file op p)                               ; a file test, or 'no if op is not one
    (: s (op @ ("-h" || "-L") (lstat p) (stat p)) m (two? s ? <>>s 0)
       k (m & 61440)
       (? (nelem op t-fops) 'no
          (atom? s) 0
          (op @
          "-e" 1
          "-f" (32768 = k)
          "-d" (16384 = k)
          "-b" (24576 = k)
          "-c" (8192 = k)
          "-p" (4096 = k)
          "-S" (49152 = k)
          ("-h" || "-L") (40960 = k)
          "-u" (0 < m & 2048)
          "-g" (0 < m & 1024)
          "-k" (0 < m & 512)
          "-s" (0 < <s)
          "-r" (0 < m & 292)
          "-w" (0 < m & 146)
          (0 < m & 73))))
   ; -ef is one file (dev and ino, stat following links); -nt/-ot compare the mtime to the
   ; nanosecond, and a file that is not there is older than one that is. a stat tail too
   ; short to carry dev and ino (the kernel's) makes -ef a bad expression, not a guess
   (t-rel a op b)                              ; a bit, or 'no if op is not one
    (: x (stat a) y (stat b)
       (at s) [(s 1) (s 3)]
       (? (op = "-ef") (? (atom? x || atom? y) 0
                          (#x < 12 || #y < 12) 'no
                          (x 8 = y 8 && x 11 = y 11))
          (op = "-nt") (? (atom? x) 0 (atom? y) 1 (at y < at x))
          (op = "-ot") (? (atom? y) 0 (atom? x) 1 (at x < at y))
          'no))
   (t-not v) (v @ 'no 'no !v)
   t-uops (["-z" "-n" "-t" "-O" "-G"] + t-fops)
   t-bops (["=" "!=" "==" "<" ">" "-a" "-o" "-ef" "-nt" "-ot"] + t-nops)
   (t-un op p)                                 ; a unary primary: a bit, or 'no
    (t-file op p @ 'no (op @- 'no
     "-z" (0 = #p)
     "-n" (0 < #p)
     "-t" (t-int p @ k (two? k ? (two? (tty <>k)) 'no))
     ("-O" || "-G") (stat p @ s (? (atom? s) 0
                                   (op = "-O") (s 4 = getuid 0)
                                   (s 5 = getgid 0))))
     r r)
   (t-bin a op b) (op @ ; a binary primary: a bit, or 'no
    ("=" || "==") (a = b)
    "!=" (a != b)
    "<" (a < b)
    ">" (b < a)
    "-a" (0 < #a && 0 < #b)
    "-o" (0 < #a || 0 < #b)
    ("-ef" || "-nt" || "-ot") (t-rel a op b)
    (nelem op t-nops ? 'no
     (: x (t-int a) y (t-int b)
       (atom? x || atom? y ? 'no
        (: p <>x q <>y
         (op @ "-eq" (p = q) "-ne" (p != q)
               "-lt" (p < q)  "-le" (p <= q)
               "-gt" (q < p)  (q <= p)))))))
   ; past four words, the grammar: -o over -a over ! and ( ), each answering
   ; (bit . the words left) or 'no
   (t-prim l)
    (? (atom? l) 'no
       (<l = "!") (t-prim >l @ 'no 'no r (!<r . >r))
       (<l = "(") (t-or >l @ 'no 'no r (two? >r && <>r = ")" ? (<r . >>r) 'no))
       (two? >>l && elem <>l t-bops && !(<>l = "-a" || <>l = "-o"))
        (t-bin <l <>l <>>l @ 'no 'no v (v . >>>l))
       (two? >l && elem <l t-uops) (t-un <l <>l @ 'no 'no v (v . >>l))
       (0 < #<l . >l))
   (t-andr r) (? (r = 'no) 'no
                 (two? >r && <>r = "-a")
                  (t-prim >>r @ 'no 'no s (t-andr ((? <r <s 0) . >s)))
                 r)
   (t-orr r) (? (r = 'no) 'no
                (two? >r && <>r = "-o")
                 (t-andr (t-prim >>r) @ 'no 'no s (t-orr ((? <r 1 <s) . >s)))
                r)
   (t-or l) (t-orr (t-andr (t-prim l)))
   (t-eval as)                                 ; a bit, or 'no for a malformed expression
    (: n #as
       ; POSIX decides up to four words by their count, then the grammar takes over
       (? (0 = n) 0
          (1 = n) (0 < #<as)
          (2 = n) (? (<as = "!") (0 = #<>as) (t-un <as <>as))
          (3 = n) (? (elem <>as t-bops) (t-bin <as <>as <>>as)
                     (<as = "!") (t-not (t-eval >as))
                     (<as = "(" && <>>as = ")") (0 < #<>as)
                     'no)
          (4 = n && <as = "!") (t-not (t-eval >as))
          (4 = n && <as = "(" && as 3 = ")") (t-eval [<>as <>>as])
          (: r (t-or as) (? (r = 'no) 'no (two? >r) 'no <r))))
   (test-main as) (t-eval as @ 'no (udie 2 "test: bad expression") v !v)
   (t-clip l) (two? >l ? (<l . t-clip >l))    ; every element but the last
   (bracket-main as)                           ; `[` is test that insists on its bracket
    (: n #as
       (? (0 = n || as (n - 1) != "]") (udie 2 "[: missing ]")
          (test-main (t-clip as))))

   ; -- uname: -s -n -r -m, or -a for all four. the machine is love-arch respelled --
   ; holo says x64 where uname says x86_64, and a build naming an artifact off the wrong
   ; one names it for an arch nothing else calls. The other three come off /proc, so a
   ; seat without one answers "unknown" rather than a guess.
   (u-1line p d)                               ; a proc file's first line, or the default
    (: r (uread p)
       (? (atom? r) d
          (: t <>r n #t
             (go k) (? (n <= k) k (t k < 33) k (go (k + 1)))
             e (go 0)
             (e @ 0 d (snip t 0 e)))))
   ; the machine is love-arch respelled, and the prel owns the respelling (arch-uname):
   ; uname says the world's word for this ISA where love-arch says ours.
   (u-mach _) (: m (arch-mach love-arch) (string? m ? m (string love-arch)))
   ; the kernel the same way, and it CANNOT be a file: /proc/sys is linux's spelling of
   ; sysctl and the other three kernels have no such path, so the read below answered
   ; "Linux" on freebsd, netbsd and inle alike. main.c pins `love-os` per run off
   ; __ai_osv, which is the only thing that knows. read as data, not as a bare ref: a
   ; baked ref would fold the bake session's own answer in forever (moon's host-os
   ; reads it the same way). nothing pinned falls to the file, then to a refusal --
   ; uname owes a name it was told, never one it guessed.
   (u-os _)
    (: n (? (elem 'love-os (names ())) (ev 'love-os) ())
       s (? (nom? n) (os-uname n) ())
       (? (string? s) s (u-1line "/proc/sys/kernel/ostype" "unknown")))
   (u-join ws) (? (atom? ws) "" (atom? >ws) <ws (<ws + " " + u-join >ws))
   (uname-main as)
    (: fl (? (two? as) as '("-s"))
       (want f) (? (elem "-a" fl) 1 (elem f fl))
       ws ((? (want "-s") [(u-os ())] ())
           + (? (want "-n") [(u-1line "/proc/sys/kernel/hostname" "unknown")] ())
           + (? (want "-r") [(u-1line "/proc/sys/kernel/osrelease" "unknown")] ())
           + (? (want "-m") [(u-mach ())] ()))
       (? (atom? ws) (udie 2 "usage: uname [-snrma]")
          (say out (u-join ws), put out 10, flush out, 0)))

   ; -- arch: uname -m, and nothing else --
   (arch-main _) (say out (u-mach ()), put out 10, flush out, 0)

   ; -- nproc: the processors /proc/cpuinfo names. GNU counts the ones this process
   ; may run on; nothing here reads an affinity mask, so this is GNU's --all --
   (nproc-main _)
    (: r (uread "/proc/cpuinfo")
       w "processor"
       (go ls n) (atom? ls ? n
                  (go >ls (#w <= #<ls && snip <ls 0 #w = w ? (n + 1) n)))
       n (two? r ? (go (lines <>r) 0) 0)
       (say out (show (? (0 < n) n 1)), put out 10, flush out, 0))

   ; -- basename and dirname: the two path clips --
   ; GNU's forms: -a many names, -s SUF (which means -a), -z NUL-ended, -- ends the options
   (ubn-opts as t)                             ; -> the operands
    (? (atom? as) ()
       (<as = "--") >as
       (<as = "-a" || <as = "--multiple") (pin t 'a 1, ubn-opts >as t)
       (<as = "-z" || <as = "--zero") (pin t 'z 1, ubn-opts >as t)
       (<as = "-s" && two? >as) (pins t 's <>as 'a 1, ubn-opts >>as t)
       (2 < #<as && snip <as 0 2 = "-s") (pins t 's (snip <as 2 #<as) 'a 1, ubn-opts >as t)
       (9 < #<as && snip <as 0 9 = "--suffix=") (pins t 's (snip <as 9 #<as) 'a 1, ubn-opts >as t)
       as)
   (ubn-say t ns f) (: end (? (peep t 'z 0) 0 10)
                     (each ns (n \ (say out (f n), put out end)),
                      flush out, 0))
   (basename-main as)
    (: t (tablet 0) ops (ustray "basename" as (ubn-opts as t)) a? (peep t 'a 0)
       (? (atom? ops) (udie 1 "usage: basename NAME [SUFFIX] | basename -a [-s SUF] NAME..")
          (!a? && two? >>ops) (udie 1 ("basename: extra operand '" + <>>ops + "'"))
          a? (ubn-say t ops (n \ ubase n (peep t 's "")))
          (ubn-say t [<ops] (n \ ubase n (? (two? >ops) <>ops "")))))
   (dirname-main as)
    (: t (tablet 0) ops (ustray "dirname" as (ubn-opts as t))
       (atom? ops ? (udie 1 "usage: dirname NAME..")
        (ubn-say t ops udir)))

   ; -- cut: -f list [-d C] [-s] over fields, -c list over characters, -b list over
   ; bytes (flags glue or not, and GNU's long names); --complement the seats not listed,
   ; --output-delimiter=S between fields, or between the runs of -c and -b; -z records
   ; end with a NUL; -n is taken, the characters being whole already --
   (cut-args as)                       ; -> (delim fields chars b? s? files comp od z)
    (: st {'comp 0 'od () 'z 0}
       (long? h p) (: n #p (n < #h && snip h 0 n = p))
       (fl a d f c b? s?)
        (? (atom? a) [d f c b? s? a]
           (: h <a
              (? (h = "--") [d f c b? s? >a]
                 (h = "-s" || h = "--only-delimited") (fl >a d f c b? 1)
                 (h = "--complement") (: _ (pin st 'comp 1) (fl >a d f c b? s?))
                 (h = "-z" || h = "--zero-terminated") (: _ (pin st 'z 1) (fl >a d f c b? s?))
                 (h = "-n") (fl >a d f c b? s?)
                 (long? h "--output-delimiter=") (: _ (pin st 'od (snip h 19 #h)) (fl >a d f c b? s?))
                 (long? h "--delimiter=") (fl >a (h 12) f c b? s?)
                 (long? h "--fields=") (fl >a d (snip h 9 #h) c b? s?)
                 (long? h "--characters=") (fl >a d f (snip h 13 #h) 0 s?)
                 (long? h "--bytes=") (fl >a d f (snip h 8 #h) 1 s?)
                 (h = "-d") (? (two? >a) (fl >>a (<>a 0) f c b? s?)
                               (udie 2 "cut: -d wants a delimiter"))
                 (h = "-f") (? (two? >a) (fl >>a d <>a c b? s?)
                               (udie 2 "cut: -f wants a list"))
                 (h = "-c") (? (two? >a) (fl >>a d f <>a 0 s?)
                               (udie 2 "cut: -c wants a list"))
                 (h = "-b") (? (two? >a) (fl >>a d f <>a 1 s?)
                               (udie 2 "cut: -b wants a list"))
                 (2 < #h && snip h 0 2 = "-d") (fl >a (h 2) f c b? s?)
                 (2 < #h && snip h 0 2 = "-f") (fl >a d (snip h 2 #h) c b? s?)
                 (2 < #h && snip h 0 2 = "-c") (fl >a d f (snip h 2 #h) 0 s?)
                 (2 < #h && snip h 0 2 = "-b") (fl >a d f (snip h 2 #h) 1 s?)
                 [d f c b? s? a])))
       r (fl as 9 () () 0 0)
       (r + [(st 'comp) (st 'od) (st 'z)]))
   (cut-main as)
    (: p (cut-args as)
       d <p fspec <>p cspec <>>p b? <>>>p s? <>>>>p
       fs (ustray "cut" as (p 5))
       comp (p 6) od (p 7) z? (p 8)
       end (? z? 0 10)
       _ (? (fspec || cspec) () (udie 2 "usage: cut -f LIST [-d C] [-s] | cut -c LIST | cut -b LIST"))
       spec (uspec (? fspec fspec cspec))
       (pick? k) (? comp !(upick spec k) (upick spec k))
       (fieldline ln)
        (: ps (usplit d ln)
           (? (atom? >ps) (? s? () (say out ln, put out end))
              (: (go m k acc) (? (atom? m) (rev acc)
                                 (go >m (k + 1) (? (pick? k) (<m . acc) acc)))
                 sel (go ps 1 ())
                 _ (say out (? od (join od sel) (ujoinc d sel)))
                 (put out end))))
       ; seat k is the k-th character from byte i on, or the k-th byte under -b; a
       ; byte that begins no valid character is a character of its own. --output-
       ; delimiter goes between two runs of seats, not between two seats
       (charline ln)
        (: n #ln o (jug 0)
           (step i) (? (b? || ln i < 128) (i + 1) (cpnext ln i))
           (go i k prev any) (? (n <= i) ()
                                (: j (step i) on (pick? k)
                                   _ (? (on && od && any && !prev) (say o od) ())
                                   _ (? on (say o (snip ln i j)) ())
                                   (go j (k + 1) on (any || on))))
           _ (go 0 1 0 0)
           _ (say out (slurp o)) (put out end))
       ; cut terminates every line it writes, so the source's own end says nothing
       (dot ln term?) (((? fspec fieldline charline) ln), 1)
       (? z? (: t (cats (map (f \ (? (f = "-") (slurp in) (: r (uread f) (? (two? r) <>r (udie 1 ("cut: " + f + ": No such file or directory")))))) (? (two? fs) fs ["-"])))
                ps (usplit 0 t)
                (: _ (each (? (two? ps && <(rev ps) = "") (rev >(rev ps)) ps) (r \ dot r 1)) _ (flush out) 0))
          (ulines "cut" dot fs)))

   ; ---- the byte loops, natively -------------------------------------------------
   ; the interpreter's byte loop is ~700 instructions a byte (love/boot/scan.l
   ; prices it), and tr and base64 are nothing but that loop. tr's is the `xlat` nif:
   ; any byte map through a 512-byte table, one C body on every target, with the
   ; love walk below as the oracle test/law/kore.l holds it to. base64's group coder is its
   ; own shape and used by nothing in the core, so it stays out of the roster: a holo
   ; kernel, one IR for x64 and a64, with a twin that is the oracle and the engine
   ; wherever the install declines (inle, wasm, rv64). the shape is scan.l's -- the
   ; register roles, the deopt tail, the kind guards off g's reach so the blob
   ; names no C address.
   ;                            g   ip  sp  scratch
   (kabi tgt) (tgt @ 'a64 '(r0 r1 r3 r4) '(r6 r5 r1 r0))
   ; Sp[k] is a heap object of reach kind `kind` (1 a string, 6 a cask), or the twin's;
   ; r7 and r8 are the scratch pair, and SC is left holding the object
   (kguard SP G SC k kind)
     [['ld SC SP (8 * k)] ['test SC 1] '(br ne deopt)
      ['ld 'r7 SC 0] ['ld 'r8 G (reach-offset 0 + 8 * kind)] '(cmp r7 r8) '(br ne deopt)]
   ; the deopt: arity >= 2, so Ip <- the twin, as scan.l lands it
   (kdeopt IP) ['(label deopt) ['ld 'r7 IP 8] ['lea IP 'r7 16] ['ld 'r7 IP 0] '(jmpr r7)]
   ; the answer: SC tagged as a charm onto Sp[0], then the cell's ret
   (kanswer SP IP SC) [['shl SC 1] ['or SC SC 1] ['st SP 0 SC] ['add IP IP 16] ['ld 'r7 IP 0] '(jmpr r7)]
   ; the xlat nif's contract, walked in love: (kxlat-walk s tbl dst) -> the count
   ; written into dst. tbl is 512 bytes: c's image at c, its mode at 256 + c -- 0
   ; dropped, 1 written, 2 written unless it repeats the byte written last. dst is a
   ; cask of #s bytes at least.
   (kxlat-walk s tbl dst)
    (: n #s o (jug 0)
       (go k prev cnt)
        (? (n <= k) cnt
           (: c (s k) m (tbl (256 + c))
              (m @ 0 (go (k + 1) prev cnt)
               (: v (tbl c)
                  (? (m = 2 && v = prev) (go (k + 1) prev cnt)
                     (put o v, go (k + 1) v (cnt + 1)))))))
       cnt (go 0 -1 0)
       _ (pour dst 0 (slurp o) 0 cnt)
       cnt)
   ; (kb64 s set dst) -> the count written: every whole 3-byte group of s as 4 charms
   ; of set (64 charms at least); the short tail is the caller's. dst holds 4 bytes a
   ; group, checked as 3 * #dst >= 4 * n. r9 = s, r10 = n, r11 = set, r12 = dst,
   ; r8 = the cursor, r13 = the count, r7 = the group's 24 bits
   (kb64-ir tgt)
    (: rg (kabi tgt) G <rg IP <>rg SP <>>rg SC <>>>rg
       (one sh d) [['mov SC 'r7] ['sar SC sh] ['and SC SC 63]   ; one sextet, as its charm
                   ['ldxb SC 'r11 SC 1 0] ['stxb 'r12 'r13 1 d SC]]
       (kguard SP G SC 0 1
        + kguard SP G SC 1 1 + [['ld 'r7 SC 8] '(cmp r7 64) '(br lt deopt)]
        + kguard SP G SC 2 6 + [['ld SC SC 8] ['ld 'r7 SC 8] '(mov r8 r7) '(shl r8 1) '(add r7 r7 r8)
                                ['ld 'r8 SP 0] '(ld r8 r8 8) '(shl r8 2) '(cmp r7 r8) '(br lt deopt)]
        + '((push r11) (push r12) (push r13))
        + [['ld 'r9 SP 0] '(ld r10 r9 8) '(lea r9 r9 16)
           ['ld 'r11 SP 8] '(lea r11 r11 16)
           ['ld 'r12 SP 16] '(ld r12 r12 8) '(lea r12 r12 16)
           '(li r8 0) '(li r13 0)]
        + ['(label lp) ['mov SC 'r8] ['add SC SC 3] ['cmp SC 'r10] '(br gt fin)
           ['ldxb 'r7 'r9 'r8 1 0] '(shl r7 16)
           ['ldxb SC 'r9 'r8 1 1] ['shl SC 8] ['or 'r7 'r7 SC]
           ['ldxb SC 'r9 'r8 1 2] ['or 'r7 'r7 SC]]
        + one 18 0 + one 12 1 + one 6 2 + one 0 3
        + ['(add r8 r8 3) '(add r13 r13 4) '(jmp lp)]
        + ['(label fin) ['mov SC 'r13] '(pop r13) '(pop r12) '(pop r11)]
        + kanswer SP IP SC
        + kdeopt IP))
   (kb64-walk s set dst)
    (: n #s w (3 * (n // 3)) o (jug 0)
       (go k) (? (w <= k) 0
                 (: v ((65536 * s k) + ((256 * s (k + 1)) + (s (k + 2))))
                    _ (put o (set ((v // 262144) & 63)))
                    _ (put o (set ((v // 4096) & 63)))
                    _ (put o (set ((v // 64) & 63)))
                    _ (put o (set (v & 63)))
                    (go (k + 3))))
       _ (go 0)
       cnt ((w * 4) // 3)
       _ (pour dst 0 (slurp o) 0 cnt)
       cnt)
   ; build a kernel, or answer its twin. `nif` hands the twin back itself where the
   ; install declines (inle's NX heap, wasm), so no fallback is arranged here; built
   ; on first use and kept for the process, scan.l's shape and reason
   (kmake ir twin arity)
    (: h (cite 'holo) g (cite 'glaze)
       (? (!h || !g || nelem love-arch '(x64 a64)) twin
          (: bs (peep ((h 'assemble) love-arch (ir love-arch)) 'bytes 0)
             ((g 'nif) (cask bs) twin arity))))
   kbox (tablet 0)
   (kernel nm ir twin arity)
    (: k (peep kbox nm 'none)
       (? (k != 'none) k (: k2 (kmake ir twin arity) _ (pin kbox nm k2) k2)))
   (kb64 _) (kernel 'b64 kb64-ir kb64-walk 3)
   ; kxlat's table from tr's reading: (image mode) per charm, 512 bytes
   (ktable f)
    (: (go c acc) (? (c < 0) acc (go (c - 1) (<(f c) . acc)))
       (mode c acc) (? (c < 0) acc (mode (c - 1) (<>(f c) . acc)))
       (string (cask (go 255 (mode 255 ())))))

   ; -- tr: set1 set2 translates (SET2 pads with its last charm), -d deletes, -s
   ; squeezes same-charm runs; stdin only, like the real one --
   ; the flags cluster: -c (or -C) reads SET1 as its complement, -d deletes, -s
   ; squeezes. a dash word that is none of them is refused and not read as a set --
   ; `tr -c a-z .` used to translate the literal set "-c". `--` ends the walk.
   ; -> [c? d? s? rest t?]; -t cuts SET1 to SET2's length, where it pads SET2
   (tr-flags a c? d? s? t?)
    (? (atom? a) [c? d? s? a t?]
       (<a = "--") [c? d? s? >a t?]
       (: w <a n #w
          (? (2 > n || w 0 != 45) [c? d? s? a t?]
             (: (cl k C D S T)
                 (n <= k ? (tr-flags >a C D S T)
                  (w k @ (99 || 67) (cl (k + 1) 1 D S T)
                         100 (cl (k + 1) C 1 S T)
                         115 (cl (k + 1) C D 1 T)
                         116 (cl (k + 1) C D S 1)
                         (udie 2 ("tr: unknown option " + w))))
                (cl 1 c? d? s? t?)))))
   (tr-main as)
    (: fp (tr-flags as 0 0 0 0)
       c? <fp d? <>fp s? <>>fp rest <>>>fp t? (fp 4)
       _ (? (two? rest) () (udie 2 "usage: tr [-cdst] SET1 [SET2]"))
       two (? (two? >rest) (uset <>rest) ())
       one (: o (uset <rest) (? (t? && two? two) (take #two o) o))
       (mem ls) (: t {}
                   (go m) (two? m ? (pin t <m 1, go >m) t)
                   (go ls))
       (tmap a b) (: t {}
                     (go m w last) (? (atom? m) t
                                    (: v (two? w ? <w last)
                                     (pin t <m v, go >m (two? w ? >w) v)))
                     (go a b 0))
       st (mem one)
       (in? c) (: v (? (peep st c 0) 1 0) (? c? (1 - v) v))
       twot (mem two)
       ; a charm's image. under -c a translation has no pair to walk, so everything
       ; outside SET1 goes to SET2's last -- what the padding means once SET1 is infinite
       mt (two? two ? (tmap one two))
       last2 (two? two ? <(rev two) 0)
       (image c) (? (atom? two) c  c? (? (in? c) last2 c)  (peep mt c c))
       src (slurp in)
       n #src
       ; the reading as kxlat's table: image, then mode -- 0 dropped, 1 written, 2
       ; written unless it repeats. -s squeezes what SET1 names when it stands alone
       ; and what SET2 names beside a translation, which is how GNU reads the pair.
       ; -ds deletes SET1 and squeezes SET2, so -d takes a SET2 only beside -s
       _ (? !d? ()
            (s? && (atom? two)) (udie 1 "tr: -ds wants SET2, the charms to squeeze")
            (!s? && two? two) (udie 1 ("tr: extra operand " + <>rest))
            ())
       rule (? d? (c \ [c (? (in? c) 0 (s? && peep twot c 0) 2 1)])
               (atom? two && !s?) (udie 2 "tr: SET2 wanted")
               (atom? two) (c \ [c (? (in? c) 2 1)])
               (c \ (: v (image c) [v (? (s? && peep twot v 0) 2 1)])))
       ; the sets are code points. when both are ascii a multibyte character never meets
       ; them and kxlat's byte table is the reading -- unless -c, where every character
       ; outside SET1 is one, so a byte walk would see its bytes as many
       (hi? c) (127 < c)
       (ahi? src) (: t (ktable (c \ [c (? (hi? c) 1 0)])) (0 < xlat src t (cask #src)))
       bytes? (!(any hi? one) && !(any hi? two) && !(c? && ahi? src))
       ; the character walk: rule's reading per code point, kept as [bytes image mode]. a
       ; byte that begins no valid character reads as its own negation, which no set
       ; names and only a complement takes in, and is written back as that byte
       (walk o)
        (: memo (tablet 0)
           (look c) (: r (memo c)
                       (? (two? r) r
                          (: q (rule c) v <q
                             r2 [(? (v < 0) (string (0 - v)) (utf8 v)) v <>q]
                             _ (pin memo c r2) r2)))
           (go i prev) (n > i ?
                        (: b (src i) w (? (b < 128) 1 (cpn src i))
                           r (look (w @ 1 b 0 -b (cpat src i))) v <>r m <>>r
                         (m = 0 || m = 2 && v = prev ?
                          (go (i + max 1 w) prev)
                          (say o <r, go (i + max 1 w) v))))
           (go 0 -1))
       _ (? (n = 0) 0
            bytes? (: dst (cask n) k (xlat src (ktable rule) dst) (say out (snip dst 0 k)))
            (walk out))
       _ (flush out) 0)

   ; -- nl: number the lines -- -b t those with ink (the default), a all, n none; -n ln rn
   ; rz the number left, right or zero-padded; -w its width (6), -s what follows it (a
   ; tab), -v the first (1), -i the step (1). a line left unnumbered wears the width and
   ; the separator's length in spaces, and the count carries across inputs --
   (nl-main as)
    (: fo (uflags "nl" as '(98 110 119 115 118 105) "bnwsvi")
       t <fo
       (num c d) (: v (uoptv t c) (? !v d (: n (uint v) (? (charm? n) n (udie 1 ("nl: invalid number: '" + v + "'"))))))
       sty (: v (uoptv t 98) (? (!v || v = "t") 't (v = "a") 'a (v = "n") 'n (udie 1 ("nl: invalid body numbering style: '" + v + "'"))))
       fmt (: v (uoptv t 110) (? (!v || v = "rn") 'rn (v = "ln") 'ln (v = "rz") 'rz (udie 1 ("nl: invalid line numbering format: '" + v + "'"))))
       w (num 119 6) sep (? (t 115) (uoptv t 115) "\t") inc (num 105 1)
       st {'i (num 118 1)}
       (numstr i) (: n (show i) (? (fmt = 'ln) (urpad w n) (fmt = 'rz) (zpad w n) (upad w n)))
       (on? ln) (? (sty = 'a) 1 (sty = 'n) 0 (? ln 1 0))
       ; nl terminates every line it writes, so term? says nothing here either
       (dot ln term?)
        ((? (on? ln)
            (: i (st 'i) _ (say out (numstr i + sep + ln + "\n")) (pin st 'i (i + inc)))
            (say out (cats (map (_ \ " ") (jot (w + #sep))) + ln + "\n"))),
         1)
       (ulines "nl" dot (fo 1)))

   ; -- rev: every line back to front --
   (rev-main as)
    ; the last line keeps the source's end, which is exactly what term? carries
    (: (dot ln term?) (say out (cprev ln), term? && put out 10, 1)
       (ulines "rev" dot ((uflags "rev" as () "") 1)))

   ; ---- the column tools: fold, expand, unexpand --------------------------------
   ; all three count columns and not bytes -- a tab steps to the next stop, \b steps
   ; back one, \r starts the line over, a character takes its wcwidth -- which is the
   ; whole reason they are one section: `ucol` is the only thing they share and the only
   ; thing they disagree with a byte count about. fold -b asks for the bytes instead.
   (ucol col c stop)                   ; the column code point c leaves the cursor on
    (? (c = 9) (stop * (col // stop + 1))
       (c = 8) (0 < col ? (col - 1) 0)
       (c = 13) 0
       (c < 128) (col + 1)
       (col + max 0 (wcwidth c)))
   (ublank? c) (c = 32 || c = 9)
   (uspaces o k) (0 < k ? (put o 32, uspaces o (k - 1)) 0)

   ; -- fold: one line -> the pieces it breaks into at width w. the break lands
   ; before the character that would overflow, so one wider than the whole width
   ; still gets a line of its own; -s backs the break up to the last blank --
   (ufold w s? b? s)
    (: n #s
       (go k st col lb acc)            ; lb: seat after the last blank, -1 for none
        (? (n <= k) (rev (snip s st n . acc))
           (: c (b? ? (s k) (cpat s k))
              k2 (b? ? (k + 1) (cpnext s k))
              nc (? b? (col + 1) (ucol col c 8))
              (? (w < nc && st < k)
                 (: cut (? (s? && st < lb && lb <= k) lb k)
                    (go cut cut 0 -1 (snip s st cut . acc)))
                 (go k2 st nc (? (ublank? c) k2 lb) acc))))
       (go 0 0 0 -1 ()))
   (fold-main as)
    (: t (tablet 0)
       (pre a wid acc)                 ; the obsolescent -N width, as head takes its own
        (? (atom? a) [wid (rev acc)]
           ((1 < #<a) && <a 0 = 45 && digits? <a)
            (pre >a (uatoi (snip <a 1 #<a)) acc)
           (pre >a wid (<a . acc)))
       p (pre as () ())
       o (uopt <>p t '(119) '(101) ())
       _ (? (two? o) () (udie 2 "fold: -w wants a width"))
       _ (: c (uoptbad as t "wsb") (? !c () (udie 2 ("fold: unknown option -" + string c))))
       v (uoptv t 119)
       w (? (string? v) (uatoi v) (? (charm? <p) <p 80))
       _ (? (0 < w) () (udie 2 "fold: width must be positive"))
       s? (peep t 115 0) b? (peep t 98 0)
       ; the pieces are said as they are cut. The flatten this replaced was
       ; `(foldl (\ a l (a + ..)) () ..)`, which copies the whole answer per line.
       (dot ln term?)
        (: (go m) (? (atom? m) 1
                     (say out <m,
                      (? (two? >m || term?) (put out 10) 0),
                      go >m))
           (go (ufold w s? b? ln)))
       (ulines "fold" dot <>>o))

   ; -- column: lines laid in columns, util-linux's and the BSDs' byte for byte. filling,
   ; every column is one width, the widest entry's taken past the next tab stop, and the pad
   ; is tabs; down the columns unless -x, across -c's width (the screen's, else 80), a name
   ; a line when even two will not fit. -t makes a table: fields split on whitespace (a run
   ; as one, the ends dropped) or on each of -s's characters (so an empty field stays), each
   ; column as wide as its widest cell, -o between (two spaces), a short row padded to the
   ; last column. blank lines are skipped; widths are screen columns, a wide character two
   (col-sp n) (? (n < 1) "" (" " + col-sp (n - 1)))
   (col-vec l) (: t {} (go l j) (atom? l ? t (pin t j <l, go >l (j + 1))) (go l 0))
   ; tabs from screen column c up to the stop end, util-linux's loop
   (col-stop c) ((c // 8 + 1) * 8)
   (col-tabs c end) (: n (col-stop c) (end < n ? "" ("\t" + col-tabs n end)))
   (col-fill ls w across?)
    (: n #ls v (col-vec ls)
       ws (col-vec (map swidth ls))
       mx (col-stop (foldl max 0 (map swidth ls)))
       (? (n < 1) 0
          (w <= mx) (map (l \ say out (l + "\n")) ls)
          (: cols (: k (w // mx) (k < 1 ? 1 k))
             rows (((n + cols) - 1) // cols)
             ; one line's entries, the tabs between them: past an entry the position is the
             ; column's stop when a tab reached it, else where the entry ended
             (line js c end acc)
              (? (atom? js) acc
                 (: j <js c2 (c + ws j)
                    (? (two? >js)
                       (line >js (? (col-stop c2 <= end) end c2) (end + mx) (acc + v j + col-tabs c2 end))
                       (acc + v j))))
             (idx r) (filter (j \ j < n) (map (k \ ? across? (r * cols + k) (r + k * rows)) ^cols))
             (map (r \ say out (line (idx r) 0 mx "" + "\n")) ^rows))))
   (col-split ln sep)
    (? (string? sep)
       (: cs (map sep ^#sep)
          (go i j acc) (? (#ln <= i) (rev (snip ln j i . acc))
                          (elem (ln i) cs) (go (i + 1) (i + 1) (snip ln j i . acc))
                          (go (i + 1) j acc))
          (go 0 0 ()))
       (: (go i j acc) (? (#ln <= i) (rev (j < i ? (snip ln j i . acc) acc))
                          (ln i = 32 || ln i = 9)
                           (go (i + 1) (i + 1) (? (j < i) (snip ln j i . acc) acc))
                          (go (i + 1) j acc))
          (go 0 0 ())))
   (col-table ls sep osep)
    (: rows (map (l \ col-split l sep) ls)
       nc (foldl max 0 (map tally rows))
       wd (col-vec (map (c \ foldl max 0 (map (r \ ? (c < #r) (swidth (r c)) 0) rows)) (jot nc)))
       (cell r c) (c < #r ? (r c) "")
       (lay r c) (nc <= c + 1 ? (cell r c)
                  (: s (cell r c) (s + col-sp (wd c - swidth s) + osep + lay r (c + 1))))
       (map (r \ say out (lay r 0 + "\n")) rows))
   (column-main as)
    (: t (tablet 0)
       o (uopt as t '(99 115 111) () ())
       _ (? (two? o) 0 (udie 1 "usage: column [-tx] [-c COLUMNS] [-s SEP] [-o SEP] [FILE..]"))
       _ (: c (uoptbad as t "csotx") (? !c 0 (udie 1 ("column: unknown option -" + string c))))
       wv (uoptv t 99)
       w (? (string? wv)
            (: n (unum wv) (? (charm? n && 0 < n) n (udie 1 ("column: invalid columns argument: '" + wv + "'"))))
            ((cite 'grid 'screen) 1))
       osep (: v (uoptv t 111) (? (string? v) v "  "))
       box (tablet 1) _ (pin box 'l ())
       st (ulines "column" (\ ln _ ((? (0 < #ln) (pin box 'l (ln . box 'l)) 0), 1)) (o 2))
       ls (rev (box 'l))
       _ (? (peep t 116 0) (col-table ls (uoptv t 115) osep) (col-fill ls w (peep t 120 0)))
       _ (flush out)
       st)

   ; -- expand: tabs to spaces, a stop every n (8 unsaid); -i converts only the
   ; blanks a line opens with --
   (uexpand n i? s)
    (: m #s o (jug 0)
       (go k col lead)
        (? (m <= k) (slurp o)
           (: c (cpat s k) k2 (cpnext s k)
              (? (c = 9 && (lead || !i?))
                 (: to (n * (col // n + 1)) _ (uspaces o (to - col)) (go k2 to lead))
                 ((? (c < 128) (put o c) (say o (snip s k k2))),
                  go k2 (ucol col c n) (ublank? c ? lead 0)))))
       (go 0 0 1))
   (expand-main as)
    (: t (tablet 0)
       o (uopt as t '(116) '(101) ())
       _ (? (two? o) () (udie 2 "expand: -t wants a tab size"))
       _ (: c (uoptbad as t "ti") (? !c () (udie 2 ("expand: unknown option -" + string c))))
       v (uoptv t 116)
       n (? (string? v) (uatoi v) 8)
       _ (? (0 < n) () (udie 2 "expand: tab size must be positive"))
       i? (peep t 105 0)
       (dot ln term?) (say out (uexpand n i? ln), (? term? (put out 10) 0), 1)
       (ulines "expand" dot <>>o))

   ; -- unexpand: blanks back to tabs -- only the ones a line opens with unless -a
   ; takes every run (-t says a size and means -a too). a tab lands only where it
   ; saves at least two columns, which is why a lone space on a stop stays a space --
   (uunexpand n a? s)
    (: m #s o (jug 0)
       (spill st end)                  ; a blank run from column st to column end
        (: (go cur) (: to (n * ((cur // n) + 1))
                      (? (to <= end && (cur + 2) <= to) (put o 9, go to)
                         (uspaces o (end - cur))))
           (go st))
       (go k col rst lead)             ; rst: the run's first column, -1 for none
        (? (m <= k) ((? (rst < 0) 0 (spill rst col)), slurp o)
           (: c (cpat s k) k2 (cpnext s k)
              cv (ucol col c n)
              (? (ublank? c && (lead || a?))
                 (go k2 cv (? (rst < 0) col rst) lead)
                 ((? (rst < 0) 0 (spill rst col)),
                  (? (c < 128) (put o c) (say o (snip s k k2))),
                  go k2 cv -1 (? (ublank? c) lead 0)))))
       (go 0 0 -1 1))
   (unexpand-main as)
    (: t (tablet 0)
       o (uopt as t '(116) '(101) ())
       _ (? (two? o) () (udie 2 "unexpand: -t wants a tab size"))
       _ (: c (uoptbad as t "ta") (? !c () (udie 2 ("unexpand: unknown option -" + string c))))
       v (uoptv t 116)
       n (? (string? v) (uatoi v) 8)
       _ (? (0 < n) () (udie 2 "unexpand: tab size must be positive"))
       a? (? (string? v) 1 (peep t 97 0))
       (dot ln term?) (say out (uunexpand n a? ln), (? term? (put out 10) 0), 1)
       (ulines "unexpand" dot <>>o))

   ; ---- the line endings: dos2unix, unix2dos, mac2unix -------------------------
   ; three names and one walk; what separates them is which break goes in and which comes
   ; out. the transform is the easy half -- `tr -d '\r'` is most of dos2unix -- and it is
   ; not why this is a tool. the other half is: it converts IN PLACE, which is what every
   ; caller of dos2unix means, and in place means keeping the mode, leaving a binary file
   ; alone, and not rewriting a file that already reads the way it was asked to.
   (ucrlf s)                                  ; crlf -> lf
    (: n #s o (jug 0)
       (go i) (? (n <= i) (slurp o)
                 (s i = 13 && i + 1 < n && s (i + 1) = 10) (put o 10, go (i + 2))
                 (put o (s i), go (i + 1)))
       (go 0))
   (ulfcr s)                                  ; lf -> crlf, and one already there stays one
    (: n #s o (jug 0)
       (go i) (? (n <= i) (slurp o)
                 (s i = 13 && i + 1 < n && s (i + 1) = 10) (say o "\r\n", go (i + 2))
                 (s i = 10) (say o "\r\n", go (i + 1))
                 (put o (s i), go (i + 1)))
       (go 0))
   (ucrlone s)                                ; a LONE cr -> lf; a crlf is dos2unix's to do
    (: n #s o (jug 0)
       (go i) (? (n <= i) (slurp o)
                 (s i = 13 && !(i + 1 < n && s (i + 1) = 10)) (put o 10, go (i + 1))
                 (put o (s i), go (i + 1)))
       (go 0))
   ; a NUL says binary, and a binary file is left alone unless -f: an .exe walked into by
   ; a `dos2unix *` over a mixed directory is the accident this is here to refuse
   (ubin? s) (: n #s (go i) (? (n <= i) 0 (s i = 0) 1 (go (i + 1))) (go 0))
   d2u-usage "usage: dos2unix [-fkqn] [FILE..]   (unix2dos and mac2unix are the same door)"
   (ud2u nm fn as)
    (: t {}
       o (uopt as t () '(101) ())
       _ (? (two? o) () (udie 2 d2u-usage))
       _ (uoptbad as t '(102 107 113 110) @ c
          (c ? (udie 2 (nm + ": unknown option -" + string c))))
       fs <>>o
       q? (peep t 113 0) f? (peep t 102 0) k? (peep t 107 0) n? (peep t 110 0)
       (note m) (? q? 0 (say err (nm + ": " + m), put err 10, 0))
       (one src dst)
        (: r (uread src)
           (? (atom? r) (note ("cannot read " + src), 1)
              (: s <>r
                 (? (!f? && ubin? s) (note ("skipping binary file " + src), 0)
                    (: c (fn s) st (stat src)
                       (? (src = dst && c = s) 0     ; already so: in place writes nothing
                          !(uwrite dst c) (note ("cannot write " + dst), 1)
                          ((two? st ? (chmod dst (4095 & <>>st)) 0),
                           (? (k? && two? st) (utime dst <>st) 0),
                           0)))))))
       ; -n is dos2unix's "new file" pair, so the operands read IN OUT, IN OUT
       (go l) (? (atom? l) 0
                 n? (? (atom? >l) (udie 2 d2u-usage)
                       (: r (one <l <>l) (r || go >>l ? 1 0)))
                 (: r (one <l <l) (r || go >l ? 1 0)))
       (? (two? fs) (go fs)
          (: s (slurp in) (puts (fn s), 0))))   ; no operands: the plain filter
   (dos2unix-main as) (ud2u "dos2unix" ucrlf as)
   (unix2dos-main as) (ud2u "unix2dos" ulfcr as)
   (mac2unix-main as) (ud2u "mac2unix" ucrlone as)



   ; ---- the encodings: base64 and base32 (RFC 4648, GNU's two faces) ------------
   ; one coder, two alphabets: the group is 3 bytes -> 4 charms at 6 bits and 5 -> 8
   ; at 5, the short tail padded with = to a whole group either way. -d reads it back
   ; (a newline is ignored, anything else outside the alphabet is refused), -w wraps
   ; the output at 76 unless told another width, 0 for one long line.
   ub64set "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
   ub32set "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
   ; val and go are lifted OUT of grp on purpose. Written inside it -- which is the
   ; obvious shape, and was this coder's for a long time -- they are two closures minted
   ; per THREE INPUT BYTES, and love has no pass that hoists a loop lambda out of
   ; another loop's body. That alone was 3.5x of this function (539 ms -> 155 ms over
   ; 512 KB, byte-identical), and it is why `base64` used to read ~600x busybox on
   ; bench/korebench.sh where `tr`, the same kind of per-byte transform, reads ~48x.
   ; and it was not the two things it looked like: the tower computing 2^shift is
   ; 5 ms per 3M, and the jug is 145 ms per 1.4M puts. Both were measured and neither
   ; is the cost. `shf` below is still worth having -- one table beats gc towers a
   ; group -- but it is the smaller half by far. the kore gauge carries the
   ; numbers and the two dead ends.
   ; base64 rides the kb64 kernel over the whole groups and the coder below over the
   ; tail; base32 (5 bits) is the coder's alone
   (ubenc set bits s)
    (: n #s w (3 * (n // 3))
       (? (bits = 6 && (2 < n))
          (: dst (cask (4 * ((n + 2) // 3)))
             k (kb64 0 s set dst)
             (snip dst 0 k + ubenc0 set bits (snip s w n)))
          (ubenc0 set bits s)))
   (ubenc0 set bits s)
    (: n #s o (jug 0)
       gb (bits @ 6 3 5)                    ; bytes in a whole group
       gc (gb * 8 // bits)                    ; charms in a whole group
       msk (bits 2 - 1)
       shf ((: (mk j a) (? (j < 0) a (mk (j - 1) ((bits * (gc - 1 - j)) 2 . a))))
            (gc - 1) ())                        ; the divisor per output charm, once
       (val k have i acc) (? (gb <= i) acc
                             (val k have (i + 1) (acc * 256 + (i < have ? (s (k + i)) 0))))
       (go k v full j) (? (gc <= j) (grp (k + gb))
                          ((? (j < full)
                              (put o (set ((v // shf j) & msk)))
                              (put o 61)),
                           go k v full (j + 1)))
       (grp k)
        (? (n <= k) (slurp o)
           (: have (? (k + gb <= n) gb (n - k))
              v (val k have 0 0)
              full ((have * 8 + bits - 1) // bits)   ; the charms carrying data
              (go k v full 0)))
       (grp 0))
   ; -w 0 closes nothing: GNU wraps at a width and ends the last line, but one long
   ; line arrives with no newline at all -- so a `base64 -w 0` piped into a compare is
   ; a byte shorter than the obvious implementation makes it
   (ubwrap w s)                                 ; the coded text, wrapped and closed
    (: n #s o (jug 0)
       (go k) (? (n <= k) (slurp o)
                 (: e (? (k + w < n) (k + w) n)
                    (say o (snip s k e), put o 10, go e)))
       (0 < w ? (go 0) s))
   (ubdec set bits s)                           ; (1 text), or () when it will not read
    (: ns #set n #s o (jug 0)
       (ix c) (: (go k) (? (ns <= k) () (set k = c) [1 k] (go (k + 1))) (go 0))
       (go k acc nb)
        (? (n <= k) [1 (slurp o)]
           (: c (s k)
              (? (c = 10 || c = 13) (go (k + 1) acc nb)
                 (c = 61) (: (tail j)               ; past the pad, only pad and newline
                              (? (n <= j) [1 (slurp o)]
                                 (: d (s j)
                                    (? (d = 61 || d = 10 || d = 13) (tail (j + 1))
                                       ())))
                            (tail (k + 1)))
                 (: r (ix c)
                    (two? r ?
                       (: a2 ((acc * bits 2) + <>r)
                          n2 (nb + bits)
                          (? (8 <= n2)
                             (put o ((a2 // (n2 - 8) 2) & 255),
                              go (k + 1) (a2 & ((n2 - 8) 2 - 1)) (n2 - 8))
                             (go (k + 1) a2 n2))))))))
       (go 0 0 0))
   (ubmain who set bits as)
    (: t {}
       o (uopt as t '(119) '(101) ())
       _ (atom? o ? (udie 1 (who + ": -w wants a width")))
       _ (: c (uoptbad as t "wd") (? !c () (udie 1 (who + ": unknown option -" + string c))))
       v (uoptv t 119)
       w (string? v ? (uatoi v) 76)
       d? (peep t 100 0)
       fs <>>o
       _ (two? >fs ? (udie 1 (who + ": extra operand")))
       txt (? (two? fs) (: r (<fs @ "-" [1 (slurp in)] (uread <fs))
                           (two? r ? <>r (udie 1 (who + ": cannot open " + <fs))))
              (slurp in))
       _ (? d? (: r (ubdec set bits txt)
                  (? (two? r) (say out <>r) (udie 1 (who + ": invalid input"))))
            (say out (ubwrap w (ubenc set bits txt))))
       _ (flush out) 0)
   (base64-main as) (ubmain "base64" ub64set 6 as)
   (base32-main as) (ubmain "base32" ub32set 5 as)

   ; -- basenc: GNU's many encodings over one front. base64 and base32 (and their url
   ; and hex alphabets) ride the coder above; base16, the two bit orders of base2 and
   ; z85 are each a short walk of their own. -d reads back, -i drops what is not in
   ; the alphabet first, -w wraps (76) --
   ub64url "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
   ub32hex "0123456789ABCDEFGHIJKLMNOPQRSTUV"
   ubz85 "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#"
   (ubeach s f) (: o (jug 0) n #s (go k) (n <= k ? (slurp o) (f o (s k), go (k + 1))) (go 0))
   (ub16enc s) (ubeach s (\ o c (put o ("0123456789ABCDEF" (c >> 4)), put o ("0123456789ABCDEF" (c & 15)))))
   (ub2enc s msb) (ubeach s (\ o c (map (i \ (put o (48 + ((c >> (? msb (7 - i) i)) & 1)))) ^8)))
   (ubz85enc s)
    (: o (jug 0) n #s
       (dig v k) (? (k < 1) () (dig (v // 85) (k - 1), put o (ubz85 (v % 85))))
       (go k) (? (n <= k) (slurp o)
                 (dig ((s k << 24) + (s (k + 1) << 16) + (s (k + 2) << 8) + s (k + 3)) 5, go (k + 4)))
       (go 0))
   (ubhexv c) (? (47 < c < 58) (c - 48) (64 < c < 71) (c - 55) (96 < c < 103) (c - 87) ())
   ; the decoders answer [ok text]: GNU says what read before it complains
   (ub16dec s)
    (: o (jug 0) n #s
       (go k hi) (? (n <= k) [!(charm? hi) (slurp o)]
                    (s k = 10) (go (k + 1) hi)
                    (: v (ubhexv (s k))
                       (? !(charm? v) [0 (slurp o)]
                          (charm? hi) (put o (hi * 16 + v), go (k + 1) ())
                          (go (k + 1) v))))
       (go 0 ()))
   (ub2dec s msb)
    (: o (jug 0) n #s
       (go k acc nb) (? (n <= k) [(? (nb = 0) 1 0) (slurp o)]
                        (s k = 10) (go (k + 1) acc nb)
                        !(s k = 48 || s k = 49) [0 (slurp o)]
                        (: b (s k - 48)
                           a2 (? msb (acc * 2 + b) (acc + (b << nb)))
                           (? (nb = 7) (put o a2, go (k + 1) 0 0) (go (k + 1) a2 (nb + 1)))))
       (go 0 0 0))
   (ubz85dec s)
    (: t (filter (!= 10) (map s ^#s))
       o (jug 0)
       (ix c) (findsub ubz85 (string c))
       (go l) (? (atom? l) [1 (slurp o)]
                 (: g (take 5 l)
                    vs (map ix g)
                    (? (#g < 5 || any (v \ v < 0) vs) [0 (slurp o)]
                       (: v (foldl (a \ d \ a * 85 + d) 0 vs)
                          (? (4294967295 < v) [0 (slurp o)]
                             (map (i \ (put o ((v >> (24 - 8 * i)) & 255))) ^4, go (drop 5 l)))))))
       (go t))
   (basenc-main as)
    (: (usage m) (udie 1 ("basenc: " + m + "\nTry 'basenc --help' for more information."))
       encs ["--base64" "--base64url" "--base32" "--base32hex" "--base16" "--base2msbf" "--base2lsbf" "--z85"]
       (go a o)
        (? (atom? a) o
           (: w <a n #w
              (? (w = "--") (pin o 'fs (o 'fs + >a), o)
                 (elem w encs) (pin o 'e w, go >a o)
                 (w = "-d" || w = "--decode") (pin o 'd 1, go >a o)
                 (w = "-i" || w = "--ignore-garbage") (pin o 'i 1, go >a o)
                 (w = "-w" || w = "--wrap") (? (two? >a) (pin o 'w <>a, go >>a o) (usage "option requires an argument -- 'w'"))
                 (7 < n && snip w 0 7 = "--wrap=") (pin o 'w (snip w 7 n), go >a o)
                 (2 < n && snip w 0 2 = "-w") (pin o 'w (snip w 2 n), go >a o)
                 (2 < n && snip w 0 2 = "--") (usage ("unrecognized option '" + w + "'"))
                 (1 < n && w 0 = 45 && elem (w 1) "di")
                  (map (c \ (? (elem c "di") (pin o (c @ 100 'd 'i) 1) (usage ("invalid option -- '" + string c + "'")))) (map w (drop 1 ^n)),
                   go >a o)
                 (1 < n && w 0 = 45) (usage ("invalid option -- '" + string (w 1) + "'"))
                 (pin o 'fs (o 'fs + [w]), go >a o))))
       o (go as {'fs ()})
       e (o 'e)
       _ (? e 0 (usage "missing encoding type"))
       fs (o 'fs)
       _ (? (two? fs && two? >fs) (usage ("extra operand '" + <>fs + "'")) 0)
       ww (? (o 'w) (unum (o 'w)) 76)
       _ (? (charm? ww && 0 <= ww) 0 (udie 1 ("basenc: invalid wrap size: '" + o 'w + "'")))
       txt (? (two? fs && !(<fs = "-")) (: r (uread <fs) (? (two? r) <>r (udie 1 ("basenc: " + <fs + ": No such file or directory"))))
              (slurp in))
       set (e @ "--base64" ub64set "--base64url" ub64url "--base32" ub32set "--base32hex" ub32hex
                "--base16" "0123456789ABCDEFabcdef" "--z85" ubz85 "01")
       t2 (? (o 'i && o 'd) (: keep (? (e = "--base64" || e = "--base64url" || e = "--base32" || e = "--base32hex") (set + "=") set)
                               (ubeach txt (\ o c (? (elem c keep) (put o c) 0))))
             txt)
       (? (o 'd)
          ; a group left short reads when what its last character carries past the
          ; last whole byte is zero bits, and a pad fills its group, as GNU reads it
          (: (rfc set bits gc)
              (: r (ubdec set bits t2)
                 cs (filter (c \ (elem c set)) (map t2 ^#t2))
                 lb (((#cs % gc) * bits) % 8)
                 v (? (two? cs) (findsub set (string (cs (#cs - 1)))) 0)
                 pads #(filter (c \ (c = 61)) (map t2 ^#t2))
                 (? (atom? r)                ; what read before the stranger, then the complaint
                    (: (bad j) (? (#t2 <= j) j (elem (t2 j) (set + "=\n\r")) (bad (j + 1)) j)
                       r2 (ubdec set bits (snip t2 0 (bad 0)))
                       [0 (? (two? r2) <>r2 "")])
                    [(? (lb < bits && (v & ((1 << lb) - 1)) = 0 && (pads = 0 || ((#cs + pads) % gc) = 0)) 1 0) <>r]))
             r (e @ "--base64" (rfc ub64set 6 4) "--base64url" (rfc ub64url 6 4)
                    "--base32" (rfc ub32set 5 8) "--base32hex" (rfc ub32hex 5 8)
                    "--base16" (ub16dec t2) "--base2msbf" (ub2dec t2 1) "--base2lsbf" (ub2dec t2 0)
                    (ubz85dec t2))
             ; a padded base32 group reads whole or not at all
             t (? (<r || !(e = "--base32" || e = "--base32hex") || nelem 61 t2) <>r
                  (: g #(filter (c \ (elem c "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=0123456789")) (map t2 ^#t2))
                     (snip <>r 0 (min #<>r (5 * (g // 8))))))
             _ (say out t) _ (flush out)
             (? <r 0 (udie 1 "basenc: invalid input")))
          (: _ (? (e = "--z85" && #txt % 4) (udie 1 "basenc: invalid input (length must be multiple of 4 characters)") 0)
             c (e @ "--base64" (ubenc ub64set 6 txt) "--base64url" (ubenc ub64url 6 txt)
                    "--base32" (ubenc ub32set 5 txt) "--base32hex" (ubenc ub32hex 5 txt)
                    "--base16" (ub16enc txt) "--base2msbf" (ub2enc txt 1) "--base2lsbf" (ub2enc txt 0)
                    (ubz85enc txt))
             _ (say out (ubwrap ww c)) _ (flush out) 0)))

   ; -- uuencode and uudecode: the old mail armour, busybox's faces. a 45-byte line
   ; wears its length as a character, then its groups of three bytes as four printable
   ; ones (` for 0); -m is base64 in 60-column lines between begin-base64 and ==== --
   (uu-ch v) (? (v = 0) 96 (v + 32))
   (uu-line s)
    (: n #s p (s + string (cask 2))
       o (jug 0)
       _ (put o (uu-ch n))
       (go k) (? (n <= k) (put o 10, slurp o)
                 (: v ((p k << 16) + (p (k + 1) << 8) + p (k + 2))
                    _ (map (i \ (put o (uu-ch ((v >> (18 - 6 * i)) & 63)))) ^4)
                    (go (k + 3))))
       (go 0))
   (uuencode-main as)
    (: m? (two? as && <as = "-m")
       ops (? m? >as as)
       _ (? (two? ops && #ops <= 2) 0 (udie 1 "usage: uuencode [-m] [INFILE] STORED_FILENAME"))
       fin (? (two? >ops) <ops "-")
       nm (? (two? >ops) <>ops <ops)
       st (? (fin = "-") () (stat fin))
       _ (? (fin = "-" || two? st) 0 (udie 1 ("uuencode: " + fin + ": " + uerrno st)))
       mode (? (two? st) (st 2 & 511) (438 & (511 ^ umask-now 0)))
       txt (? (fin = "-") (slurp in) (: r (uread fin) (? (two? r) <>r "")))
       (show3 v) (string (48 + ((v >> 6) & 7)) + string (48 + ((v >> 3) & 7)) + string (48 + (v & 7)))
       _ (say out ((? m? "begin-base64 " "begin ") + show3 mode + " " + nm + "\n"))
       n #txt
       (go k) (? (n <= k) 0
                 (: e (min n (k + 45)) c (snip txt k e)
                    _ (say out (? m? (ubenc ub64set 6 c + "\n") (uu-line c)))
                    (go e)))
       _ (go 0)
       _ (say out (? m? "====\n" "`\nend\n"))
       _ (flush out) 0)
   (uudecode-main as)
    (: (go a o) (? (atom? a) o
                   (<a = "-o") (? (two? >a) (pin o 'o <>a, go >>a o) (udie 1 "uudecode: option requires an argument -- 'o'"))
                   (pin o 'f <a, go >a o))
       o (go as {})
       f (o 'f)
       txt (? (!f || f = "-") (slurp in) (: r (uread f) (? (two? r) <>r (udie 1 ("uudecode: " + f + ": No such file or directory")))))
       ls (lines txt)
       (begin l) (? (atom? l) (udie 1 "uudecode: no 'begin' line")
                    (: ws (usplit 32 <l)
                       (? (3 <= #ws && (<ws = "begin" || <ws = "begin-base64")) l (begin >l))))
       bl (begin ls)
       hw (usplit 32 <bl)
       b64 (<hw = "begin-base64")
       mode (foldl (a \ c \ a * 8 + c - 48) 0 (map (hw 1) ^#(hw 1)))
       nm (ujoin (drop 2 hw))
       (body l acc) (? (atom? l) (udie 1 "uudecode: short file")
                       b64 (? (<l = "====") (rev acc) (body >l (<l . acc)))
                       (<l = "end") (rev acc)
                       (body >l (<l . acc)))
       bls (body >bl ())
       (uu1 l) (: n (((l 0) - 32) & 63) o (jug 0)
                  (v k) (((l k) - 32) & 63)
                  (go k left) (? (left <= 0 || #l <= k) (slurp o)
                                 (: x ((v k << 18) + (v (k + 1) << 12) + (v (k + 2) << 6) + v (k + 3))
                                    _ (map (i \ (? (i < left) (put o ((x >> (16 - 8 * i)) & 255)) 0)) ^3)
                                    (go (k + 4) (left - 3))))
                  (? (#l = 0) "" (go 1 n)))
       data (? b64 (: r (ubdec ub64set 6 (ujoinc 10 bls)) (? (two? r) <>r (udie 1 "uudecode: invalid input")))
               (foldl (\ a l (a + uu1 l)) "" bls))
       dst (? (o 'o) (o 'o) nm)
       (? (dst = "-" || dst = "/dev/stdout") (say out data, flush out, 0)
          ((? (uwrite dst data) (chmod dst mode) (udie 1 ("uudecode: " + dst + ": cannot write"))), 0)))

   ; -- ascii: toybox's table, eight columns of dec, hex and the character --
   ascii-low "NULSOHSTXETXEOTENQACKBELBS HT LF VT FF CR SO SI DLEDC1DC2DC3DC4NAKSYNETBCANEM SUBESCFS GS RS US "
   (ascii-main _)
    (: o (jug 0)
       (cell x y) (: i (x * 16 + y)
                     _ (say o (upad (3 + (5 < x)) (show i) + " " + zpad 2 (uhex2 i) + " "))
                     (? (i < 32) (say o (snip ascii-low (3 * i) (3 * i + 3))) (i = 127) (say o "DEL") (put o i)))
       (uhex2 i) (string ("0123456789ABCDEF" (i >> 4)) + string ("0123456789ABCDEF" (i & 15)))
       _ (map (x \ (say o ("Dec Hex" + upad (1 + (x < 2 ? 2 0) + (? (4 < x) 1 0)) " "), put o (? (6 < x) 10 32))) ^8)
       _ (map (y \ (map (x \ (cell x y, put o (6 < x ? 10 32))) ^8)) ^16)
       _ (say out (slurp o)) _ (flush out) 0)

   ; ---- the two little computations: tsort and factor ---------------------------

   ; -- tsort: the pairs' partial order made total. the answer is a topological
   ; order, not GNU's: where the input pins one they agree, and where it does not both
   ; are right -- so the gate asks only about inputs that pin one. a loop is named on
   ; err, broken at the first node still standing, and leaves 1, as GNU's does --
   (tsort-main as0)
    (: as ((uflags "tsort" as0 () "") 1)
       _ (? (two? >as) (udie 1 "usage: tsort [FILE]") ())
       t (? (two? as) (: r (<as @ "-" [1 (slurp in)] (uread <as))
                         (? (two? r) <>r (udie 1 ("tsort: cannot open " + <as))))
              (slurp in))
       ws (words t)
       _ (? (tally ws % 2) (udie 1 "tsort: odd number of input words") ())
       deg (tablet 0) succ (tablet 0)       ; the graph, keyed by the interned words
       (rd l order)
        (? (atom? l) (rev order)
           (: a (name <l) b (name <>l)
              o1 (deg a @ () (pin deg a 0, a . order) order)
              o2 (deg b @ () (pin deg b 0, b . o1) o1)
              _ (a = b ? 0                       ; a pair of one is a node, not an edge
                 (pin succ a (b . (succ a)),
                  pin deg b ((peep deg b 0) + 1)))
              (rd >>l o2)))
       order (rd ws ())
       (loose l) (? (atom? l) () (peep deg <l 0 = 0) [1 <l] (loose >l))
       (ts-drop x l) (? (atom? l) () (<l = x) >l (<l . ts-drop x >l))
       (emit k) (say out (string k), put out 10,
                 foldl (\ _ b (pin deg b ((peep deg b 0) - 1))) 0 (succ k))
       (go l bad)
        (? (atom? l) (flush out, bad)
           (: r (loose l)
              (? (two? r) (emit <>r, go (ts-drop <>r l) bad)
                 (say err "tsort: input contains a loop:", put err 10,
                  foldl (\ _ k (say err ("tsort: " + string k), put err 10))
                        0 l,
                  emit <l,
                  go >l 1))))
       (go order 0))

   ; -- factor: every number's primes, GNU's `N: p q r`. trial division by 2 and the
   ; odd numbers -- exact for anything this tree spends, and a twenty-digit semiprime
   ; will simply sit here (that is what GNU keeps a Pollard rho for) --
   (ufactor n0)
    (: (go n d acc)
        (? (n < 2) (rev acc)
           (0 = n % d) (go (n // d) d (d . acc))
           (n < 2 d) (rev (n . acc))
           (go n (? (d = 2) 3 (d + 2)) acc))
       (? (n0 < 2) () (go n0 2 ())))
   (factor-main as)
    (: (dig? s) (: n #s
                   (go k) (? (n <= k) (0 < n)
                             (48 <= s k <= 57) (go (k + 1))
                             0)
                   (go 0))
       (one w ok)
        (? !(dig? w)
           (say err ("factor: '" + w + "' is not a valid positive integer"),
            put err 10, 0)
           (say out (w + ":"),
            foldl (\ _ p (put out 32, say out (show p))) 0 (ufactor (uatoi w)),
            put out 10, ok))
       (go a ok) (two? a ? (go >a (one <a ok)) ok)
       ok (go (two? as ? as (words (slurp in))) 1)
       _ (flush out) (? ok 0 1))

   ; ---- the record tools: paste, comm, join, split, od -------------------------

   ; -d's list -> the delimiter texts. texts and not charms because POSIX's \0 is the
   ; empty delimiter, and no charm can say "nothing here"
   (udels s)
    (: n #s
       (esc c) (c @ 110 "\n" 116 "\t" 114 "\r" 48 "" 92 "\\" (string c))
       (go k acc) (? (n <= k) (rev acc)
                     (s k = 92 && k + 1 < n) (go (k + 2) (esc (s (k + 1)) . acc))
                     (go (k + 1) (string (s k) . acc)))
       r (go 0 ())
       (two? r ? r '("")))
   ; an input's lines, or a leave naming the file (the record tools read whole files:
   ; they walk several at once, so ureach's one-at-a-time walk is not their shape)
   (urows who f)
    (: r (f @ "-" [1 (slurp in)] (uread f))
     (two? r ? (lines <>r) (udie 1 (who + ": cannot open " + f))))

   ; -- paste: the files' lines side by side, a row at a time; the delimiters cycle
   ; between the columns and start over each row (a tab when unsaid). -s lays a whole
   ; file along one row instead, which is the transpose and not a variant --
   (paste-main as)
    (: (fl a d s?)
        (? (atom? a) [d s? a]
           (<a = "-s") (fl >a d 1)
           (<a = "-d") (? (two? >a) (fl >>a (udels <>a) s?)
                          (udie 2 "paste: -d wants a list"))
           ((2 < tally <a) && (snip <a 0 2 = "-d"))
            (fl >a (udels (snip <a 2 #<a)) s?)
           [d s? a])
       p (fl as '("\t") 0)
       ds <p s? <>p
       fs (: r (ustray "paste" as <>>p) (? (two? r) r '("-")))
       (jn cells)
        (: o (jug 0)
           ; the list advances with the separator it spends, never with the cell:
           ; the first cell spends none, so an early advance shifts the whole cycle
           (go m left first)
            (? (atom? m) (slurp o)
               first (say o <m, go >m left 0)
               (say o <left, say o <m,
                go >m (? (two? >left) >left ds) 0))
           (go cells ds 1))
       (emit t) (say out t, put out 10)
       (some lss) (foldl (\ a l (? (two? l) 1 a)) 0 lss)
       (rows lss) (? (some lss)
                     (emit (jn (map (l \ (? (two? l) <l "")) lss)),
                      rows (map (l \ (? (two? l) >l ())) lss))
                     ())
       lss (map (f \ (urows "paste" f)) fs)
       _ (? s? (foldl (\ _ l (emit (jn l))) 0 lss) (rows lss))
       _ (flush out) 0)

   ; -- comm: two sorted files merged into three columns -- only in the first, only in
   ; the second, in both -- each column behind a tab per column standing before it.
   ; -1/-2/-3 drop a column and the tabs close up behind it, GNU's own arithmetic --
   (comm-main as)
    (: (fl a s1 s2 s3)
        (? (atom? a) [s1 s2 s3 a]
           (#<a < 2 || <a 0 != 45) [s1 s2 s3 a]
           (<a = "--") [s1 s2 s3 >a]
           (<a 1 = 45) (udie 2 ("comm: unknown option " + <a))
           (: w <a
              (cl k b1 b2 b3)
               (#w <= k ? (fl >a b1 b2 b3)
                  (w k @ 49 (cl (k + 1) 1 b2 b3)
                         50 (cl (k + 1) b1 1 b3)
                         51 (cl (k + 1) b1 b2 1)
                         c (udie 2 ("comm: unknown option -" + string c))))
              (cl 1 s1 s2 s3)))
       p (fl as 0 0 0)
       s1 <p s2 <>p s3 <>>p fs (p 3)
       _ (? (two? >fs) () (udie 2 "usage: comm [-123] FILE1 FILE2"))
       (pre k) ((!s1 && 1 < k ? "\t" "") + (!s2 && 2 < k ? "\t" ""))
       (emit k ln) (? (? (k = 1) s1 (k = 2) s2 s3) ()
                      (say out (pre k), say out ln, put out 10))
       (go a b) (? ((atom? a) && (atom? b)) ()
                   (atom? a) (emit 2 <b, go a >b)
                   (atom? b) (emit 1 <a, go >a b)
                   (<a = <b) (emit 3 <a, go >a >b)
                   (<a < <b) (emit 1 <a, go >a b)
                   (emit 2 <b, go a >b))
       _ (go (urows "comm" <fs) (urows "comm" <>fs))
       _ (flush out) 0)

   ; -- split: a file cut into pieces named prefix + a rolling suffix. -l N lines (1000
   ; unsaid), -b N bytes (a K/M/G suffix multiplies), -a N the suffix width, -d digits
   ; for letters. an empty input writes no file, like GNU --
   (usfx n w d?)                       ; the n'th suffix, w wide: aa ab .. or 00 01 ..
    (: b (? d? 10 26)
       (go k v acc) (k < 1 ? acc
                       (go (k - 1) (v // b) (string ((? d? 48 97) + (v % b)) + acc)))
       (go w n ""))
   (usize s)                           ; a byte count, an optional K/M/G multiplying
    (: n #s
       c (0 < n ? (s (n - 1)) 0)
       m (? (c = 107 || c = 75) 1024 (c = 109 || c = 77) 1048576
            (c = 103 || c = 71) 1073741824 0)
       (? m (m * uatoi (snip s 0 (n - 1))) (uatoi s)))
   (split-main as)
    (: (fl a ln by sw d? fs)
        (: (val w) (snip w 2 #w)
           (long? w) (2 < #w && snip w 0 2 = "-l")
           (? (atom? a) [ln by sw d? (rev fs)]
              (<a = "-l") (? (two? >a) (fl >>a (uatoi <>a) () sw d? fs)
                             (udie 2 "split: -l wants a count"))
              (<a = "-b") (? (two? >a) (fl >>a () (usize <>a) sw d? fs)
                             (udie 2 "split: -b wants a size"))
              (<a = "-a") (? (two? >a) (fl >>a ln by (uatoi <>a) d? fs)
                             (udie 2 "split: -a wants a width"))
              (<a = "-d") (fl >a ln by sw 1 fs)
              (long? <a) (fl >a (uatoi (val <a)) () sw d? fs)
              (2 < #<a && snip <a 0 2 = "-b") (fl >a () (usize (val <a)) sw d? fs)
              (2 < #<a && snip <a 0 2 = "-a") (fl >a ln by (uatoi (val <a)) d? fs)
              (fl >a ln by sw d? (<a . fs))))
       p (fl as () () 2 0 ())
       ln <p by <>p sw <>>p d? (p 3) fs (ustray "split" as (p 4))
       nl (charm? ln ? ln 1000)
       src (two? fs ? <fs "-")
       pre (two? fs && two? >fs ? <>fs "x")
       t (src @ "-" (slurp in)
          (: r (uread src) (? (two? r) <>r (udie 1 ("split: cannot open " + src)))))
       end? (nl-end? t)
       (wr i txt) (: nm (pre + usfx i sw d?)
                     (? (uwrite nm txt) () (udie 1 ("split: cannot write " + nm))))
       (bygo i k) (? (#t <= k) 0
                     (: e (? (k + by < #t) (k + by) #t)
                        _ (wr i (snip t k e))
                        (bygo (i + 1) e)))
       ; unlines terminates every line, so the last piece of a source that did not
       ; end in a newline has to give the newline back -- the piece is where the
       ; source's own end lands, and GNU keeps it there
       (lngo i ls) (? (atom? ls) 0
                      (: rest (drop nl ls)
                         txt (unlines (take nl ls))
                         _ (wr i (? (two? rest || end?) txt (chomp txt)))
                         (lngo (i + 1) rest)))
       _ (? (charm? by) (bygo 0 0) (lngo 0 (lines t)))
       0)

   ; the shape every option walk past this point rides: a word is -X and the value is
   ; either glued to it or the next word. asked by tally: a text is no link, so a
   ; `two?` here reads every glued value as absent (the bug that ate `grep -m2`).
   (uflag w)                            ; "-tx1" -> ("t" "x1"), a bare word -> ()
    (: n #w (1 < n && w 0 = 45 ? [(snip w 1 2) (snip w 2 n)]))

   ; -- join: two files sorted on their join field, merged into one. a row is the key,
   ; then the first file's other fields, then the second's; a key repeated on either
   ; side makes the whole cross product, which is what a relational join owes. -1/-2
   ; pick the field, -t the separator (runs of blanks when unsaid, and then the output
   ; rides one space), -a keeps a side's unpairable rows in their sorted place, -v keeps
   ; only those (and drops the paired rows entirely). out of dialect, deliberately: -o
   ; (an output template is its own little language), -e, -i.
   (ujfs sep ln)                       ; a row's fields: -t's charm, or runs of blanks
    (? (charm? sep) (usplit sep ln)
       (: n #ln
          (bl? c) (c = 32 || c = 9)
          (go i st acc)
           (? (n <= i) (rev (st < 0 ? acc (snip ln st i . acc)))
              (bl? (ln i)) (go (i + 1) -1 (? (st < 0) acc (snip ln st i . acc)))
              (go (i + 1) (? (st < 0) i st) acc))
          (go 0 -1 ())))
   (unth l k) (k < 1 ? () (l (k - 1)))
   (join-main as)
    (: t {'f1 1 'f2 1 'sep () 'a1 0 'a2 0 'v1 0 'v2 0}
       (fl a fs)
        (atom? a ? (rev fs)
           (: w <a
              o (uflag w)
              takes (? o (elem <o '("1" "2" "t" "a" "v")) 0)
              glue (? o <>o "")
              got (? (0 < tally glue) glue (? (two? >a) <>a ()))
              rest (? (0 < tally glue) >a (? (two? >a) >>a >a))
              (? !takes (fl >a (w . fs))
                 !(string? got) (udie 2 ("join: " + w + " wants a value"))
               (<o @ "1" (pin t 'f1 (uatoi got))
                     "2" (pin t 'f2 (uatoi got))
                     "t" (pin t 'sep (got 0))
                     "a" (pin t (got @ "2" 'a2 'a1) 1)
                         (pin t (got @ "2" 'v2 'v1) 1),
                fl rest fs))))
       fs (ustray "join" as (fl as ()))
       _ (atom? >fs ?
          (udie 2 "usage: join [-1 F] [-2 F] [-t C] [-a 1|2] [-v 1|2] FILE1 FILE2"))
       sep (t 'sep)
       jsep (? (charm? sep) sep 32)
       n1 (peep t 'f1 1) n2 (peep t 'f2 1)
       pair? !(peep t 'v1 0 || peep t 'v2 0)
       un1 (peep t 'a1 0 || peep t 'v1 0)
       un2 (peep t 'a2 0 || peep t 'v2 0)
       ; a side is its rows grouped by key: ((key (fields..)..)..), the run of one key
       (grp sel lns)
        (: rows (map (ln \ (: f (ujfs sep ln) k (unth f sel)
                              [(? (string? k) k "") f]))
                     lns)
           (go rs) (two? rs ?
                      (: k <<rs
                         (span m acc) (? (two? m && <<m = k) (span >m (<><m . acc))
                                         [(rev acc) m])
                         r (span rs ())
                         ([k <r] . go <>r)))
           (go rows))
       (drop1 sel f) (: (go l i acc) (? (atom? l) (rev acc)
                                        (go >l (i + 1) (? (i = sel) acc (<l . acc))))
                        (go f 1 ()))
       (row ps) (say out (ujoinc jsep ps), put out 10)
       (one k sel g) (foldl (\ _ f (row (k . drop1 sel f))) 0 <>g)
       (cross g1 g2)
        (foldl (\ _ f1 (foldl (\ _ f2 (row ((<g1 . drop1 n1 f1) + drop1 n2 f2)))
                              0 <>g2))
               0 <>g1)
       (go g1 g2)
        (? ((atom? g1) && (atom? g2)) ()
           (atom? g1) ((? un2 (one <<g2 n2 <g2) ()), go g1 >g2)
           (atom? g2) ((? un1 (one <<g1 n1 <g1) ()), go >g1 g2)
           (<<g1 = <<g2) ((? pair? (cross <g1 <g2) ()), go >g1 >g2)
           (<<g1 < <<g2) ((? un1 (one <<g1 n1 <g1) ()), go >g1 g2)
           ((? un2 (one <<g2 n2 <g2) ()), go g1 >g2))
       _ (go (grp n1 (urows "join" <fs)) (grp n2 (urows "join" <>fs)))
       _ (flush out) 0)

   ; -- od: the byte dump, GNU's columns to the space. -A d|o|x|n picks the address
   ; radix (octal, 7 wide, unsaid; -An drops the column AND the closing offset), -t
   ; type the reading, -N a limit, -j a skip, -v every line even where it repeats
   ; (a repeat is one `*` otherwise). the short spellings -a -b -c -d -o -x -s -i are
   ; the -t's GNU gives them. one -t per run, the last given winning: GNU's
   ; several-at-once lane re-widens every column to the widest type in the set, which
   ; is a whole layout of its own and not another row.
   uodnames '("nul" "soh" "stx" "etx" "eot" "enq" "ack" "bel" "bs" "ht" "nl" "vt"
              "ff" "cr" "so" "si" "dle" "dc1" "dc2" "dc3" "dc4" "nak" "syn" "etb"
              "can" "em" "sub" "esc" "fs" "gs" "rs" "us" "sp")
   (uodname c)                         ; -ta's name, the high bit masked off like GNU's
    (: b (c & 127) (? (b < 33) (uodnames b) (b = 127) "del" (string b)))
   (uodesc c)                          ; -tc's escape; anything else is three octal
    (c @ 0 "\\0" 7 "\\a" 8 "\\b" 9 "\\t" 10 "\\n" 11 "\\v" 12 "\\f" 13 "\\r"
     (31 < c < 127 ? (string c) (zpad 3 (radix c 8))))
   (uodtype s)                         ; a -t word -> (kind size width) | ()
    (: k (? (0 < #s) (s 0) 0)
       z (? (1 < #s) (uatoi (snip s 1 #s)) 0)
       (k @ 99 '(c 1 3)
            97 '(a 1 3)
          120 (z @ 1 '(x 1 2) 4 '(x 4 8) 2 '(x 2 4) 0 '(x 2 4))
          111 (z @ 1 '(o 1 3) 4 '(o 4 11) 2 '(o 2 6) 0 '(o 2 6))
          100 (z @ 1 '(d 1 4) 4 '(d 4 11) 2 '(d 2 6) 0 '(d 2 6))
          117 (z @ 1 '(u 1 3) 4 '(u 4 10) 2 '(u 2 5) 0 '(u 2 5))))
   (od-main as)
    (: t {'ad 111 'ty '(o 2 6) 'lim () 'skip 0 'v 0}
       (fl a fs)
        (? (atom? a) (rev fs)
           (: w <a
              o (uflag w)
              k (? o <o ())
              glue (? o <>o "")
              takes (? o (elem k '("A" "t" "N" "j")) 0)
              got (? (0 < tally glue) glue (? (two? >a) <>a ()))
              rest (? (0 < tally glue) >a (? (two? >a) >>a >a))
              short (? o (k @ "c" (uodtype "c") "a" (uodtype "a")
                            "b" (uodtype "o1") "x" (uodtype "x2")
                            "o" (uodtype "o2") "d" (uodtype "u2")
                            "s" (uodtype "d2") "i" (uodtype "d4")))
              (? takes
                 (? !(string? got) (udie 2 ("od: " + w + " wants a value"))
                    ((? (k = "A") (pin t 'ad (got 0))
                        (k = "N") (pin t 'lim (usize got))
                        (k = "j") (pin t 'skip (usize got))
                        (: y (uodtype got)
                           (? y (pin t 'ty y) (udie 2 ("od: unknown type " + got))))),
                     fl rest fs))
                 !o (fl >a (w . fs))
                 short (pin t 'ty short, fl >a fs)
                 (k = "v") (pin t 'v 1, fl >a fs)
                 (udie 2 ("od: unknown option " + w)))))
       fs (fl as ())
       ad (peep t 'ad 111) ty (peep t 'ty '(o 2 6))
       lim (t 'lim) skip (peep t 'skip 0) v? (peep t 'v 0)
       kd <ty sz <>ty wd <>>ty
       byte? (kd = 'c || kd = 'a)
       step (? byte? 1 sz)
       ; the named operands are one stream, which is what makes the offsets run
       ; through -- and a row at a time off it, never the stream itself. every
       ; reading below indexes the row now, not a whole-file `src`: od held every
       ; operand at once to dump 16 bytes of them.
       rd (urdb (f \ udie 1 ("od: cannot open " + f)) fs)
       ; the skip is read past, not indexed: a joined stream has no length to take
       ; it off, and running out mid-skip is the diagnostic GNU gives.
       (drop k) (k <= 0 ? 1
                   (: g (urdj-take rd (? (65536 < k) 65536 k))
                      n #g
                      (? n (drop (k - n)) 0)))
       _ (? (drop skip) 0 (udie 1 "od: cannot skip past end of combined input"))
       (adr k) (ad @ 110 ""
                     100 (zpad 7 (show k))
                     120 (zpad 6 (radix k 16))
                     (zpad 7 (radix k 8)))
       (val blk k)                      ; the little-endian item at k, short reads zeroed
        (: n #blk
           (go i acc) (? (sz <= i) acc
                         (go (i + 1) (acc + (k + i < n ? (blk (k + i)) 0) * (8 * i) 2)))
           (go 0 0))
       (cell blk k)
        (kd @ 'c (upad 3 (uodesc (blk k)))
              'a (upad 3 (uodname (blk k)))
         (: raw (val blk k)
            v (kd = 'd && raw >= (8 * sz - 1) 2 ? (raw - ((8 * sz) 2)) raw)
            (kd @ 'x (zpad wd (radix v 16))
                  'o (zpad wd (radix v 8))
                  (upad wd (show v)))))
       (rowof blk cnt)
        (: items (? byte? cnt (((cnt + sz) - 1) // sz))
           o (jug 0)
           (go i) (? (items <= i) (slurp o)
                     (put o 32, say o (cell blk (i * step)), go (i + 1)))
           (go 0))
       ; left is -1 for no -N; the walk answers the byte count, for the closing offset
       (walk k left prev star)
        (? (left = 0) k
           (: blk (urdj-take rd (? (left < 0) 16 (? (16 < left) 16 left)))
              cnt #blk
              left2 (? (left < 0) -1 (left - cnt))
              (? (0 = cnt) k
                 ((!v? && cnt = 16) && blk = prev)
                  ((? star () (say out "*", put out 10)),
                   walk (k + cnt) left2 blk 1)
                 (say out (adr (skip + k)), say out (rowof blk cnt), put out 10,
                  walk (k + cnt) left2 blk 0))))
       nb (walk 0 (? (charm? lim) lim -1) () 0)
       _ (? (ad = 110) () (say out (adr (skip + nb)), put out 10))
       _ (flush out) 0)

   ; ---- the byte tools: xxd, strings, dd ---------------------------------------
   ; od above can say all three things and nobody remembers how to ask it. these are
   ; the spellings people actually type, and they share od's joined byte reader.

   ; -- xxd: the canonical dump, and -r to read one back. 16 bytes a row, the offset
   ; in 8 hex digits, the bytes in pairs of two, then the ascii gutter --
   (uxx-esc c) (? (32 <= c && c < 127) c 46)     ; a dot for anything unprintable
   (uxx-row off blk) (uxx-rowf off blk 16 2 0)
   ; c bytes a row in groups of g, upper? the hex in capitals
   (uxx-rowf off blk c g upper?)
    (: n #blk o (jug 0)
       (hx v w) (: h (zpad w (radix v 16)) (? upper? (upper h) h))
       _ (say o (hx off 8)) _ (say o ": ")
       (hex i) (? (c <= i) 0
                  ((i < n ? (say o (hx (blk i) 2)) (say o "  ")),
                   (0 = (i + 1) % g ? (put o 32) 0),
                   hex (i + 1)))
       _ (hex 0) _ (? (0 = c % g) 0 (put o 32)) _ (put o 32)
       (asc i) (c <= i || n <= i ? 0 (put o (uxx-esc (blk i)), asc (i + 1)))
       _ (asc 0)
       (slurp o))
   ; -r reads the dump back: the offset up to the colon is skipped, the gutter past
   ; two spaces is not hex and stops the row. a line with no colon is all hex
   (uxx-unrow ln)
    (: n #ln
       (col k) (? (n <= k) 0 (ln k = 58) (k + 1) (col (k + 1)))
       s (col 0)
       (go k acc hi)
        (? (n <= k) (rev acc)
           (: c (ln k) v (hexv c)
              ; two spaces in a row IS the gutter, and the gutter is text: `ab.hello` past
           ; it reads as hex to anything that only skips single spaces
           (? (v < 0) (? (32 = c && !(charm? hi))
                         (? (k + 1 < n && ln (k + 1) = 32) (rev acc)
                            (go (k + 1) acc hi))
                         (rev acc))
                 (charm? hi) (go (k + 1) (((16 * hi) + v) . acc) ())
                 (go (k + 1) acc v))))
       (go s () ()))
   ; -p the plain hex, 30 bytes a line; -i a C array named for the file; -c the bytes a
   ; row, -g a group, -u capitals; -l stops after so many bytes and -s starts past so
   ; many, the offsets counting from there. a count may be 0x hex
   (xxd-main as)
    (: fo (uflags "xxd" as '(99 103 108 115) "cgilprsu")
       t <fo fs (fo 1)
       (num c d) (: v (uoptv t c)
                    (? !v d
                       (: h (starts? v "0x") w (? h (snip v 2 #v) v)
                          n (? h (foldl (\ a ch (a * 16 + hexv ch)) 0 (chars w)) (unum w))
                          (? (charm? n && (!h || all (ch \ 0 <= hexv ch) (chars w))) n (udie 1 ("xxd: invalid number: " + v))))))
       p? (t 112) i? (t 105)
       c (num 99 (? p? 30 i? 12 16)) g (num 103 2) lim (num 108 ()) sk (num 115 0)
       _ (? (0 < c) 0 (udie 1 "xxd: invalid number of columns"))
       (? (t 114)
          (: (dot ln term?) (map (put out) (uxx-unrow ln), 1)
             _ (ulines "xxd" dot fs) _ (flush out) 0)
          (: rd (urdb (f \ (udie 1 ("xxd: cannot open " + f))) fs)
             (drop k) (? (k <= 0) 0 (: b (urdj-take rd (min k 4096)) (? #b (drop (k - #b)) 0)))
             _ (drop sk)
             nm (? (two? fs) (string (map (ch \ (? (48 <= ch <= 57 || 65 <= ch <= 90 || 97 <= ch <= 122) ch 95)) (chars <fs))) ())
             _ (? (i? && nm) (say out ("unsigned char " + nm + "[] = {\n")) 0)
             (go off first)
              (: want (? (charm? lim) (min c (lim - (off - sk))) c)
                 blk (? (0 < want) (urdj-take rd want) "")
                 (? !#blk off
                    (: _ (? p? (say out (cats (map (b \ zpad 2 (radix b 16)) (chars blk)) + "\n"))
                            i? (say out ((? first "" ",\n") + "  " + join ", " (map (b \ "0x" + zpad 2 (radix b 16)) (chars blk))))
                            (say out (uxx-rowf off blk c g (t 117) + "\n")))
                       (go (off + #blk) 0))))
             end (go sk 1)
             _ (? i? (say out ((? (end = sk) "" "\n") + (? nm ("};\nunsigned int " + nm + "_len = " + show (end - sk) + ";\n") ""))) 0)
             _ (flush out) 0)))

   ; -- hexdump: the BSD dump, two faces. bare: a 7-digit hex offset and eight
   ; little-endian 16-bit words a row; -C (and hd): an 8-digit offset, sixteen bytes
   ; split eight and eight, the ascii gutter. a row equal to the one before is a `*`
   ; until -v; -s skips, -n caps; the last line is the offset reached. the -e format
   ; language and the one-letter faces past -C are not here --
   (uhd-row C? off blk)
    (: n #blk o (jug 0)
       (hx v w) (say o (zpad w (radix v 16)))
       _ (? C?
            (hx off 8, say o "  ",
             each ^16 (i \ ((? (i < n) (hx (blk i) 2, put o 32) (say o "   ")),
                            (? (i = 7) (put o 32) 0))),
             say o " |",
             each ^n (i \ (put o (uxx-esc (blk i)))),
             put o 124)
            (hx off 7,
             each ^8 (i \ (? (2 * i < n)
                             (put o 32,
                              hx (blk (2 * i) + (? (2 * i + 1 < n) (256 * blk (2 * i + 1)) 0)) 4)
                             (say o "     ")))))
       (slurp o))
   (uhexdump who as)
    (: t {}
       o (uopt as t '(110 115) () ())
       _ (? (two? o) () (udie 1 (who + ": option requires an argument")))
       _ (: c (uoptbad as t "Cvns") (? !c () (udie 1 (who + ": unknown option -" + string c))))
       (num k) (: v (uoptv t k)
                  (? !(string? v) ()
                     (: x (unum v) (? (charm? x) x (udie 1 (who + ": bad number " + v))))))
       C? (peep t 67 0) v? (peep t 118 0) lim (num 110) skip (? (charm? (num 115)) (num 115) 0)
       rd (urdb (f \ (udie 1 (who + ": " + f + ": No such file or directory"))) <>>o)
       left {'n lim}
       (take k) (: m (left 'n)
                   k2 (? (charm? m) (min k m) k)
                   b (? (0 < k2) (urdj-take rd k2) "")
                   _ (? (charm? m) (pin left 'n (m - #b)) 0)
                   b)
       ; the offset starts where the skip landed, which is short of -s on a short input
       (drop k got) (? (k <= 0) got (: b (urdj-take rd (min k 65536)) (? #b (drop (k - #b) (got + #b)) got)))
       at (drop skip 0)
       (go off prev star)
        (: blk (take 16) n #blk
           (? !n off
              (!v? && n = 16 && blk = prev)
               ((? star 0 (say out "*", put out 10)), go (off + 16) prev 1)
              (say out (uhd-row C? off blk), put out 10, go (off + n) blk 0)))
       end (go at () 0)
       _ (? (0 < end) (say out (zpad (? C? 8 7) (radix end 16)), put out 10) 0)
       _ (flush out) 0)
   (hexdump-main as) (uhexdump "hexdump" as)
   (hd-main as) (uhexdump "hd" ("-C" . as))

   ; -- getopt: util-linux's. -o SHORTS -l LONGS.. [--] PARAMS answers the options
   ; parsed and quoted for `eval set --`, then --, then the operands; a first word
   ; with no dash is the old face, `getopt SHORTS PARAMS`, answered unquoted.
   ; operands are gathered behind -- unless SHORTS opens with + (stop at the first)
   ; or - (answer them in place). a long may be abbreviated where unambiguous, and
   ; under -a wear one dash. 1 a parse error (the rest still answered), 2 getopt's
   ; own misuse, 4 for -T --
   (getopt-main as)
    (: old? (two? as && !(0 < #<as && <as 0 = 45))
       t {}
       o (? old? [t () >as]
            (uopt as t '(111 108 110 115) '(108)
                  {"options" 111 "longoptions" 108 "long" 108 "name" 110 "quiet" 113
                   "quiet-output" 81 "alternative" 97 "shell" 115 "test" 84 "unquoted" 117}))
       _ (? (two? o) () (udie 2 "getopt: option requires an argument"))
       _ (: c (uoptbad as t "olnqQasTu") (? !c () (udie 2 ("getopt: invalid option -- '" + string c + "'"))))
       _ (? (peep t 84 0) (uleave 4) 0)
       _ (: s (uoptv t 115) (? (!(string? s) || elem s '("sh" "bash")) 0
                               (udie 2 "getopt: unknown shell after -s or --shell argument")))
       nm (: v (uoptv t 110) (? (string? v) v "getopt"))
       q? (peep t 113 0) Q? (peep t 81 0) alt? (peep t 97 0)
       quote? (!old? && !(peep t 117 0))
       ps0 <>>o
       so (? old? <as (string? (uoptv t 111)) (uoptv t 111) (two? ps0) <ps0
             (udie 2 "getopt: missing optstring argument"))
       ps (? (old? || string? (uoptv t 111)) ps0 >ps0)
       m0 (? (0 < #so) (so 0) 0)
       mode (? (m0 = 43) 'stop (m0 = 45) 'here (string? (getenv "POSIXLY_CORRECT")) 'stop 'gather)
       ; SHORTS -> {charm kind}: 0 bare, 1 wants a value, 2 takes one glued or none
       sp (: tb {} n #so
             (go k) (? (n <= k) tb
                       (: c (so k)
                          (? (k = 0 && (c = 43 || c = 45)) (go 1)
                             (: k1 (k + 1)
                                c1 (? (k1 < n && so k1 = 58) 1 0)
                                c2 (? (c1 && (k1 + 1) < n && so (k1 + 1) = 58) 1 0)
                                _ (pin tb c (c1 + c2))
                                (go (k1 + c1 + c2))))))
             (go 0))
       ; LONGS -> ((name kind)..), comma lists stacked across -l
       lo (: (one w) (: n #w (tr k) (? (0 < k && w (k - 1) = 58) (tr (k - 1)) k)
                        e (tr n) [(snip w 0 e) (? (2 <= n - e) 2 (n - e))])
             (map one (filter (w \ (0 < #w)) (foldl (\ acc s (acc + usplit 44 s)) () <>o))))
       bad {'b 0}
       (gerr msg) (pin bad 'b 1, (? q? 0 (say err (nm + ": " + msg), put err 10)))
       ; a ' inside is closed, escaped and reopened: it's -> 'it'\''s'
       (qj ps) (atom? >ps ? <ps (<ps + "'\\''" + qj >ps))
       (qt s) (? quote? ("'" + qj (usplit 39 s) + "'") s)
       (lmatch body)                         ; -> (name kind) | 'none | ('many names)
        (: ex (filter (l \ <l = body) lo)
           pre (filter (l \ #body <= #<l && snip <l 0 #body = body) lo)
           (? (two? ex) <ex (atom? pre) 'none (atom? >pre) <pre ['many (map cap pre)]))
       (long w dash rest opts)               ; -> (rest opts)
        (: body (snip w #dash #w)
           e ((: (go i) (? (#body <= i) -1 (body i = 61) i (go (i + 1)))) 0)
           key (? (e < 0) body (snip body 0 e))
           val (? (e < 0) () (snip body (e + 1) #body))
           r (lmatch key)
           (? (r = 'none) (gerr ("unrecognized option '" + w + "'"), [rest opts])
              (two? r && <r = 'many)
               (gerr ("option '" + dash + key + "' is ambiguous; possibilities:"
                     + foldl (\ acc x (acc + " '" + dash + x + "'")) "" <>r),
                [rest opts])
              (: ln <r k <>r tok ("--" + ln)
                 (? (k = 0) (? (string? val) (gerr ("option '" + dash + ln + "' doesn't allow an argument"), [rest opts])
                               [rest (tok . opts)])
                    (k = 2) [rest ((qt (? (string? val) val "")) . tok . opts)]
                    (string? val) [rest ((qt val) . tok . opts)]
                    (two? rest) [>rest ((qt <rest) . tok . opts)]
                    (gerr ("option '" + dash + ln + "' requires an argument"), [rest opts])))))
       (short w rest opts)                   ; one cluster -> (rest opts)
        (: n #w
           (go k rest opts)
            (? (n <= k) [rest opts]
               (: c (w k) kd (peep sp c -1) tok ("-" + string c)
                  (? (kd < 0) (gerr ("invalid option -- '" + string c + "'"), go (k + 1) rest opts)
                     (kd = 0) (go (k + 1) rest (tok . opts))
                     (kd = 2) [rest ((qt (snip w (k + 1) n)) . tok . opts)]
                     ((k + 1) < n) [rest ((qt (snip w (k + 1) n)) . tok . opts)]
                     (two? rest) [>rest ((qt <rest) . tok . opts)]
                     (gerr ("option requires an argument -- '" + string c + "'"), [rest opts]))))
           (go 1 rest opts))
       ; under -a a one-dash word is a long when one matches -- but `-f`, f a short of
       ; SHORTS, is never an abbreviation, only an exact long beats it (glibc's rule)
       (alt1? w) (: e ((: (go i) (? (#w <= i) #w (w i = 61) i (go (i + 1)))) 1)
                    b (snip w 1 e) r (lmatch b)
                    (? (r = 'none) 0
                       (#w = 2 && 0 <= peep sp (w 1) -1) (two? r && <r = b)
                       1))
       (walk a opts nons)                    ; -> (opts nons), both reversed
        (? (atom? a) [opts nons]
           (: w <a n #w
              (? (w = "--") [opts (foldl (\ acc x (x . acc)) nons >a)]
                 (2 < n && w 0 = 45 && w 1 = 45)
                  (: r (long w "--" >a opts) (walk <r <>r nons))
                 (alt? && 1 < n && w 0 = 45 && alt1? w)
                  (: r (long w "-" >a opts) (walk <r <>r nons))
                 (1 < n && w 0 = 45)
                  (: r (short w >a opts) (walk <r <>r nons))
                 (mode = 'stop) [opts (foldl (\ acc x (x . acc)) nons a)]
                 (mode = 'here) (walk >a ((qt w) . opts) nons)
                 (walk >a opts (w . nons)))))
       r (walk ps () ())
       _ (? Q? 0
            (: toks ((rev <r) + ["--"] + map qt (rev <>r))
               _ (each toks (x \ (put out 32, say out x)))
               (put out 10)))
       _ (flush out)
       (? (peep bad 'b 0) 1 0))

   ; -- strings: the printable runs of 4 or more (-n changes the floor). a run ends
   ; at the first byte outside print-or-tab, which is what makes it useful on an
   ; object file: the noms come out and the code does not --
   (ustr-ink? c) ((32 <= c && c < 127) || c = 9)
   (strings-main as)
    (: (fl a n fs) (? (atom? a) [n (rev fs)]
                      (<a = "-n") (? (two? >a) (fl >>a (uatoi <>a) fs)
                                     (udie 2 "strings: -n wants a length"))
                      (2 < #<a && (snip <a 0 2 = "-n"))
                       (fl >a (uatoi (snip <a 2 #<a)) fs)
                      ; -a is GNU's default here: there are no sections to choose between
                      (<a = "-a") (fl >a n fs)
                      (1 < #<a && (<a 0) = 45) (udie 2 ("strings: unknown option " + <a))
                      (fl >a n (<a . fs)))
       p (fl as 4 ())
       lo <p fs <>p
       rd (urdb (f \ (udie 1 ("strings: cannot open " + f))) fs)
       ; the run is held in a jug and only spoken once it is long enough, so a 200 MB
       ; input costs the longest run and not the file
       (go run)
        (: blk (urdj-take rd 65536)
           n #blk
           (walk k acc)
            (? (n <= k) acc
               (: c (blk k)
                  (? (ustr-ink? c) (walk (k + 1) (c . acc))
                     ((? (lo <= #acc)
                         (say out (string (cask (rev acc))), put out 10) 0),
                      walk (k + 1) ()))))
           (? !n (? (lo <= #run)
                    (say out (string (cask (rev run))), put out 10, 0) 0)
              (go (walk 0 run))))
       _ (go ())
       _ (flush out) 0)

   ; -- dd: blocks in, blocks out. if=/of= default to the streams; bs= sizes both
   ; blocks, ibs= and obs= each (512 unsaid); count= stops, skip= reads past that many
   ; input blocks first, seek= puts the output that many blocks in; iflag=skip_bytes
   ; count_bytes fullblock and oflag=seek_bytes append; conv= ucase lcase swab sync
   ; notrunc excl nocreat fsync fdatasync noerror sparse -- one this dd does not do is
   ; refused, never dropped. skip is read past, not sought, so it works on a pipe; a
   ; seek, notrunc or append onto a file is laid by reading the file and writing it
   ; back with the data in place (lseek here takes a raw fd, and a port's buffer
   ; desyncs under one). the record report goes to err, GNU's shape; status=none
   ; holds it, status=noxfer the byte line --
   (udd-eq w)                          ; "bs=512" -> ("bs" "512"), () for a bare word
    (: n #w
       (go k) (? (n <= k) () (w k = 61) [(snip w 0 k) (snip w (k + 1) n)] (go (k + 1)))
       (go 0))
   (dd-main as)
    (: t {'ibs 512 'obs 512 'count () 'skip 0 'seek 0 'if () 'of () 'quiet 0 'conv () 'iflag () 'oflag ()}
       (words1 v) (filter (w \ 0 < #w) (usplit 44 v))
       (known k ok v) (: ws (words1 v) _ (each ws (w \ (? (elem w ok) 0 (udie 1 ("dd: invalid " + k + ": '" + w + "'"))))) ws)
       (fl a) (? (atom? a) 0
                 (: kv (udd-eq <a)
                    _ (? (atom? kv) (udie 1 ("dd: unknown operand " + <a))
                         (: k <kv v <>kv
                            (k @ "bs" (pins t 'ibs (usize v) 'obs (usize v))
                                 "ibs" (pin t 'ibs (usize v))
                                 "obs" (pin t 'obs (usize v))
                                 "count" (pin t 'count (usize v))
                                 "skip" (pin t 'skip (usize v))
                                 "seek" (pin t 'seek (usize v))
                                 "if" (pin t 'if v)
                                 "of" (pin t 'of v)
                                 "status" (v @ "none" (pin t 'quiet 1) "noxfer" (pin t 'quiet 2) "progress" 0
                                             (udie 1 ("dd: invalid status level: '" + v + "'")))
                                 "conv" (pin t 'conv (t 'conv + known "conversion" '("ucase" "lcase" "swab" "sync" "notrunc" "excl" "nocreat" "fsync" "fdatasync" "noerror" "sparse") v))
                                 "iflag" (pin t 'iflag (t 'iflag + known "input flag" '("skip_bytes" "count_bytes" "fullblock") v))
                                 "oflag" (pin t 'oflag (t 'oflag + known "output flag" '("seek_bytes" "append") v))
                                 (udie 1 ("dd: unknown operand " + k)))))
                    (fl >a)))
       _ (fl as)
       (cv? w) (elem w (t 'conv)) (if? w) (elem w (t 'iflag)) (of? w) (elem w (t 'oflag))
       ibs (: b (t 'ibs) (0 < b ? b (udie 1 "dd: invalid block size")))
       obs (: b (t 'obs) (0 < b ? b (udie 1 "dd: invalid block size")))
       cnt (t 'count) skip (t 'skip)
       inf (t 'if) outf (t 'of)
       _ (? (cv? "ucase" && cv? "lcase") (udie 1 "dd: cannot combine lcase and ucase") 0)
       _ (? (string? outf && cv? "excl" && two? (stat outf)) (udie 1 ("dd: failed to open '" + outf + "': File exists")) 0)
       _ (? (string? outf && cv? "nocreat" && atom? (stat outf)) (udie 1 ("dd: failed to open '" + outf + "': No such file or directory")) 0)
       rd (urdb (f \ (udie 1 ("dd: cannot open " + f))) (? (string? inf) [inf] ()))
       ; skip is READ past, not sought: it works the same on a pipe, which a seek
       ; would not. a short input mid-skip is GNU's own diagnostic
       sk (? (if? "skip_bytes") skip (skip * ibs))
       (drop k) (? (k <= 0) 1 (: g (urdj-take rd (min k ibs)) (? #g (drop (k - #g)) 0)))
       _ (? (drop sk) 0 (udie 1 "dd: cannot skip past end of input"))
       ; one input block as it goes out: the case, the byte pairs, sync's pad to ibs
       (conv b) (: b1 (? (cv? "ucase") (upper b) (cv? "lcase") (lower b) b)
                   b2 (? (cv? "swab") (: n #b1 (cats (map (i \ (? (i + 1 < n) (string (b1 (i + 1)) + string (b1 i)) (string (b1 i)))) (filter (i \ i % 2 = 0) (jot n))))) b1)
                   (? (cv? "sync" && #b2 < ibs) (b2 + cats (map (_ \ string 0) (jot (ibs - #b2)))) b2))
       ; the sink: blocks stream out as they come, save where a file is spliced, when
       ; they gather to be laid into it at the end
       sd (? (of? "seek_bytes") (t 'seek) (t 'seek * obs))
       splice? (string? outf && (0 < sd || cv? "notrunc" || of? "append"))
       q (? splice? (jug 0)
            (string? outf) (: h (open outf "w") (? (hot? h) h (udie 1 ("dd: cannot write " + outf))))
            out)
       ; full and part are GNU's two record columns: a short block is a partial one
       limit (? (if? "count_bytes") cnt ())
       (go n full part got put)
        (? (!limit && charm? cnt && n >= cnt) [full part got put]
           (limit && limit <= got) [full part got put]
           (: blk (urdj-take rd (? limit (min ibs (limit - got)) ibs))
              c #blk
              (? !c [full part got put]
                 (: ob (conv blk) _ (say q ob)
                    (go (n + 1) (? (c = ibs) (full + 1) full) (? (c = ibs) part (part + 1)) (got + c) (put + #ob))))))
       r (go 0 0 0 0 0)
       ; onto a file: at the seek, the old bytes before it kept (zeros past its end), the
       ; old bytes after it kept only under notrunc; append after all of it -- and after
       ; nothing without notrunc, the file cut first as GNU's cuts it
       _ (? splice?
            (: data (slurp q)
               old (: r (uread outf) (? (two? r) <>r ""))
               new (? (of? "append") ((? (cv? "notrunc") old "") + data)
                      (: pre (? (sd <= #old) (snip old 0 sd) (old + cats (map (_ \ string 0) (jot (sd - #old)))))
                         post (? (cv? "notrunc" && sd + #data < #old) (snip old (sd + #data) #old) "")
                         (pre + data + post)))
               (? (uwrite outf new) 0 (udie 1 ("dd: cannot write " + outf))))
            (: _ (flush q) (? (string? outf) (close q) 0)))
       _ (? (string? outf && (cv? "fsync" || cv? "fdatasync")) (fsync outf (cv? "fdatasync")) 0)
       n (r 3)
       ; the two record lines and the byte count. GNU adds a duration and a rate; no
       ; two runs agree on those, so no gate could hold them and they are not spoken
       _ (? (t 'quiet = 1) 0
            (: _ (say err (show <r + "+" + show (r 1) + " records in\n"))
               _ (say err (show (n // obs) + "+" + show (? (0 < n % obs) 1 0) + " records out\n"))
               _ (? (t 'quiet = 2) 0 (say err (show n + " bytes copied\n")))
               (flush err)))
       0))
) ; module 'kore
