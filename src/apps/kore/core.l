; src/apps/kore/core.l -- the line tools, the coreutils batch of kore: cat, tac, echo,
; head, tail, wc, sort, uniq, tee, seq, yes, true, false, basename, dirname -- the
; field tools cut, tr, nl, rev -- the column tools fold, expand, unexpand -- and the
; encodings base64 and base32 beside tsort and factor. every tool is a
; <name>-main (the args after its name -> conversation on the ports -> the exit status,
; answered as a charm; a leave from deep inside rides udie, and urun is the door both
; come back through), dispatched by the multi-call `kore` (kore.l holds the registry). this
; file is a toolbox, not a tool: no seat of its own, kore is its door. it rides text.l's
; lines/unlines and loads right after text.l in the cat, so the capture law folds the
; real bridge here before cook.l's later `lines` leak can shadow it. a body-less
; top-level `:` -- the mains leak; everything else stays local to its define. the u-floor it
; stands on is src/apps/kore/u.l, which loads immediately before it (and which the mooncc cat takes
; alone -- see the note there). the GNU faces we keep exact
; (the smokes in `make test_kore` hold them to the byte): wc pads every field to the
; digit width of the byte total, uniq -c wears width 7, head/tail banner many files
; with ==> name <== and a blank line between.
(module 'kore
(:
   ; -- cat: files (or -) onto out, verbatim --
   (cat-main as) (uchunks "cat" puts as)

   ; -- tac: the lines back to front, a file at a time. the newline rides the line it
   ; followed, so a last line arriving without one comes back first without one --
   (utac t)                            ; text -> its records, last first
    (: n (tally t)
       (go k st acc) (? (n <= k) (? (st < k) (snip t st k >< acc) acc)
                        (t k = 10) (go (k + 1) (k + 1) (snip t st (k + 1) >< acc))
                        (go (k + 1) st acc))
       (go 0 0 ()))
   ; tac is the one line tool that must hold its input -- nothing can be said until
   ; the end is known. Reading it a line at a time still drops the whole-text copy and
   ; the `lines` list over it, and prepending is the reversal, so there is no rev.
   ; utac stays as the pure face law.l holds.
   (tac-main as)
    (ureach "tac"
            (\ f first rd
               (: (go acc) (: l (urd-line rd)
                              (? !(two? l) acc (go ((<l + (? <>l "\n" "")) >< acc))))
                  (out1 m) (? (two? m) (: _ (say out <m) (out1 >m)) 1)
                  (out1 (go ()))))
            as)

   ; -- echo: the args back; -n holds the newline --
   (echo-main as)
    (? (two? as && (<as = "-n"))
       (: _ (say out (ujoin >as)) _ (flush out) 0)
       (: _ (say out (ujoin as)) _ (put out 10) _ (flush out) 0))

   ; -- head and tail: one driver, two clips; -n N (10 the default) --
   ; `-5` is the obsolescent spelling and every script still writes it, so it is not
   ; optional: a bare -digits is the count. `-` alone stays the stdin name, and a flag
   ; that is neither reaches uread as a filename, exactly as it did before.
   (digits? w) (: n (tally w)
                  (go k) (? (n <= k) (1 < n)
                            (47 < (w k) < 58) (go (k + 1))
                            0)
                  (go 1))
   (uclip-args who as)                      ; -> (n files many?)
    (: nr (? (two? as && (<as = "-n"))
             (? (two? >as) [(uatoi <>as) >>as]
                (udie 2 (who + ": -n wants a count")))
             (two? as && ((<as 0) = 45) && (digits? <as))
             [(uatoi (snip <as 1 (tally <as))) >as]
             [10 as])
       n <nr fs <>nr
       [n fs (? (two? fs && two? >fs) 1 0)])
   (uclip-hdr many first f)
    (? many (say out (uhdr first (? (f = "-") "standard input" f))) 0)
   ; head stops -- it used to `lines` the whole input and take n off the front, so
   ; one line of a 100 MB file cost 7.2 GB. uhead is still the spec for where the
   ; last newline goes (law.l holds it); this answers the same text, a line at a time.
   (head-main as)
    (: p (uclip-args "head" as) n <p fs <>p many <>>p
       (body f first rd)
        (: _ (uclip-hdr many first f)
           (go k) (? (n <= k) 1
                     (: l (urd-line rd)
                        (? (! (two? l)) 1
                           (: _ (say out <l) _ (? <>l (put out 10) 0) (go (k + 1))))))
           (go 0))
       (ureach "head" body fs))
   ; tail cannot stop reading but need not hold: a ring of the last n lines is the
   ; whole answer. trimmed at 2n, so the trim costs n every n lines, not n a line.
   (tail-main as)
    (: p (uclip-args "tail" as) n <p fs <>p many <>>p
       (body f first rd)
        (: _ (uclip-hdr many first f)
           (go acc k) (: l (urd-line rd)
                         (? (! (two? l)) acc
                            (: a2 (l >< acc)
                               (? ((* 2 n) <= (k + 1)) (go (take n a2) n) (go a2 (k + 1))))))
           (out1 m) (? (two? m) (: _ (say out (<(<m))) _ (? (<>(<m)) (put out 10) 0) (out1 >m)) 1)
           (out1 (rev (take n (go () 0)))))
       (ureach "tail" body fs))

   ; -- wc: lines, words, bytes (flags pick; bare wc reads all three) --
   (wc-main as)
    ; the flags cluster, as GNU's do: -lw is the two of them and not a filename
    (: (fl a l w c)
        (? !(two? a) [l w c a]
           (: g <a n (tally g)
              (? (!(2 <= n) || !(g 0 = 45)) [l w c a]
                 (: (cl k L W C)
                     (? (n <= k) (fl >a L W C)
                        (: ch (g k)
                           (? (ch = 108) (cl (k + 1) 1 W C)
                              (ch = 119) (cl (k + 1) L 1 C)
                              (ch = 99) (cl (k + 1) L W 1)
                              [l w c a])))     ; an unknown charm: the word is not ours
                    (cl 1 l w c)))))
       p (fl as 0 0 0)
       none !(<p || <>p || <>>p)
       l? (? none 1 <p) w? (? none 1 <>p) c? (? none 1 <>>p)
       fs <>>>p
       (c3 x) <>>x
       ; a row is (name (l w b)), name () for stdin. counted a gulp at a time --
       ; nothing here needs the text, only the three numbers off it
       cnt (ucount-for l? w?)
       st (tablet 0) _ (pin st 'rows ()) _ (pin st 'ok 1)
       _ (ureachm (\ f (: _ (say err ("wc: cannot open " + f)) _ (put err 10)
                          _ (pin st 'ok 0) 0))
                  (\ f first rd
                     (: (go acc) (: h (urd-gulp rd) (? (tally h) (go (cnt acc h)) acc))
                        c (ucount-say (go ucount0))
                        _ (pin st 'rows ([(? (two? fs) f ()) c] >< (peep st 'rows ())))
                        1))
                  fs)
       rows (rev (peep st 'rows ())) ok (peep st 'ok 0)
       (sum sel a acc) (? (two? a) (sum sel >a (acc + sel <><a)) acc)
       tl (sum cap rows 0) tw (sum caup rows 0) tb (sum c3 rows 0)
       ; the GNU face: pad every column to the byte total's width, even where the
       ; bytes are not printed (`wc -lw` of a 3001-byte file wears width 4).
       ; one count over one input wears none -- `wc -l f` is "1 f", never "   1 f".
       ; a one-digit byte count hides this, which is every fixture until .gs1.
       wdt (? (((? l? 1 0) + (? w? 1 0) + (? c? 1 0) = 1) && !(two? >rows))
              1 (tally (show tb)))
       (fmt cnt) (: a (? c? [(upad wdt (show (c3 cnt)))] ())
                    a (? w? (upad wdt (show <>cnt) >< a) a)
                    a (? l? (upad wdt (show <cnt) >< a) a)
                    (ujoin a))
       (emit rs) (? !(two? rs) ()
                    (: row <rs
                       _ (say out (fmt <>row))
                       _ (? !<row () (say out (" " + <row)))
                       _ (put out 10)
                       (emit >rs)))
       _ (emit rows)
       _ (? (two? rows && two? >rows)
            (: _ (say out (fmt [tl tw tb])) _ (say out " total") (put out 10)) ())
       _ (flush out) (? ok 0 1))

   ; -- sort ----------------------------------------------------------------------
   ; the prel sort is byte order (the LC_ALL=C face) and `sortby` under it is a stable
   ; merge, which is what lets -s mean anything. flags: -b -f -n -r -s -u, -t SEP, and
   ; -k F[,M][bfnr] as often as wanted. a key carrying any ordering letter of its own
   ; uses those INSTEAD of the global ones, which is GNU's rule and not an addition to
   ; them. equal keys fall to the last-resort compare -- the whole line, bytewise --
   ; unless -s or -u, neither of which wants it.
   ; absent, and said so rather than half-done: -k's .CHAR offsets, -c/-C, -o, -z,
   ; and the -M -h -V -R orderings.
   (usort-blank? c) ((c = 32) || (c = 9))
   ; a line's fields as [start end] pairs. under the DEFAULT separator the blanks
   ; BEFORE a run belong to the run -- GNU's rule, and the whole reason -b exists;
   ; trailing blanks close no field. under -t the separator is one charm and belongs
   ; to neither side, so an empty field is a real one.
   (usort-flds ln sep)
    (: n #ln
       (run j) (? ((n <= j) || (usort-blank? (ln j))) j (run (j + 1)))
       (bl st i) (? (n <= i) ()
                    (usort-blank? (ln i)) (bl st (i + 1))
                    (: e (run i) ([st e] . bl e e)))
       (tt st i) (? (n <= i) [[st n]]
                    (ln i = sep) ([st i] . tt (i + 1) (i + 1))
                    (tt st (i + 1)))
       (? (charm? sep) (tt 0 0) (bl 0 0)))
   ; the text a key names: the start of field f through the end of field m, or the
   ; line's end when m is absent. b? drops the leading blanks of the first field.
   (usort-key ln flds f m b?)
    (: nf #flds
       (? ((f < 1) || (nf < f)) ""
          (: st <(flds (f - 1))
             en (? ((m < 1) || (nf < m)) #ln <>(flds (m - 1)))
             (sk i) (? ((en <= i) || !(usort-blank? (ln i))) i (sk (i + 1)))
             s2 (? b? (sk st) st)
             (? (en <= s2) "" (snip ln s2 en)))))
   (usort-up s) (: n #s o (jug 0)
                   (go k) (? (n <= k) (slurp o)
                             (: c (s k) _ (put o (? (97 <= c <= 122) (c - 32) c)) (go (k + 1))))
                   (go 0))
   ; -n reads a VALUE, and reads it exactly: 10000000000000000001 sorts above ...0
   ; and no double can say so. the reading is the digits -- sign, then the integer
   ; part's length, then its digits, then the fractions padded against each other.
   (usort-num s)                               ; -> [neg int frac], both parts trimmed
    (: n #s
       (sk i) (? ((n <= i) || !(usort-blank? (s i))) i (sk (i + 1)))
       i0 (sk 0)
       neg ((i0 < n) && (s i0 = 45))
       i1 (? neg (i0 + 1) i0)
       (dig j) (? ((n <= j) || !(48 <= (s j) <= 57)) j (dig (j + 1)))
       i2 (dig i1)
       ip (snip s i1 i2)
       dot ((i2 < n) && (s i2 = 46))
       i3 (? dot (dig (i2 + 1)) i2)
       fp (? dot (snip s (i2 + 1) i3) "")
       (lead k) (? ((#ip <= k) || !(ip k = 48)) k (lead (k + 1)))
       (trail k) (? ((k < 1) || !(fp (k - 1) = 48)) k (trail (k - 1)))
       [neg (snip ip (lead 0) #ip) (snip fp 0 (trail #fp))])
   (usort-cmpnum pa pb)                        ; two usort-num readings -> -1 | 0 | 1
    (: ia <>pa fa <>>pa ib <>pb fb <>>pb
       sa (? (!#ia && !#fa) 0 (<pa ? -1 1))
       sb (? (!#ib && !#fb) 0 (<pb ? -1 1))
       (lex k) (? (#ia <= k) 0 (ia k < ib k) -1 (ib k < ia k) 1 (lex (k + 1)))
       (frc k) (? ((#fa <= k) && (#fb <= k)) 0
                  (: ca (? (k < #fa) (fa k) 48) cb (? (k < #fb) (fb k) 48)
                     (? (ca < cb) -1 (cb < ca) 1 (frc (k + 1)))))
       ; ⚠ never `(? r r ..)` on a comparison: -1 is FALSY here (a predicate is the sign
       ; of the net), so a "less than" would fall through to the next test as if equal.
       m (? (#ia < #ib) -1 (#ib < #ia) 1 (: r (lex 0) (? (= r 0) (frc 0) r)))
       (? (sa < sb) -1 (sb < sa) 1 (sa < 0) (0 - m) m))
   (usort-cmpstr a b) (? (a < b) -1 (b < a) 1 0)
   ; one key's reading of a line, taken ONCE per line and not per comparison: the
   ; text, folded, or the numeric reading, per the key's own letters
   (usort-keyof ln k sep)
    (: f <k m <>k b? (k 2) f? (k 3) n? (k 4)
       t (? f (usort-key ln (usort-flds ln sep) f m b?)
            b? (: n #ln
                  (sk i) (? ((n <= i) || !(usort-blank? (ln i))) i (sk (i + 1)))
                  (snip ln (sk 0) n))
            ln)
       (? n? (usort-num t) f? (usort-up t) t))
   (usort-cmp1 ka kb k)                        ; two readings under key k -> -1 | 0 | 1
    (: c (? (k 4) (usort-cmpnum ka kb) (usort-cmpstr ka kb))
       (? (k 5) (0 - c) c))
   (sort-main as)
    (: (sdie m) (udie 2 ("sort: " + m))
       ; the flag walk is sort's own: -k takes a value AND stacks, -t takes a charm
       ; that may be glued or not, and uopts stacks only -e.
       ; ⚠ every arm below sits inside the ONE `?`. a `(:` here reads `(w = "--")` as a
       ; BINDING -- a define whose head is a call pattern -- and silently shadows w with
       ; a two-parameter function, which is how the first draft of this walk answered a
       ; closure where the file list belonged.
       (fl a b? f? n? r? s? u? sep ks fs)
        (? !(two? a) [b? f? n? r? s? u? sep (rev ks) (rev fs)]
           (: w <a
              (val g) (: v (snip w 2 #w)
                         (? #v [v >a]
                            (two? >a) [<>a >>a]
                            (sdie (g + " wants a value"))))
              ; the letters glue: -nr is two of them
              (ltr j B F N R S U)
               (? (#w <= j) (fl >a B F N R S U sep ks fs)
                  ((w j) @
                   98  (ltr (j + 1) 1 F N R S U)
                   102 (ltr (j + 1) B 1 N R S U)
                   110 (ltr (j + 1) B F 1 R S U)
                   114 (ltr (j + 1) B F N 1 S U)
                   115 (ltr (j + 1) B F N R 1 U)
                   117 (ltr (j + 1) B F N R S 1)
                   c   (sdie ("unknown option -- " + (string c)))))
              (? (w = "--") [b? f? n? r? s? u? sep (rev ks) ((rev fs) + >a)]
                 ((#w < 2) || !(w 0 = 45)) (fl >a b? f? n? r? s? u? sep ks (w . fs))
                 (w = "-k") (: pv (val "-k") (fl <>pv b? f? n? r? s? u? sep (<pv . ks) fs))
                 ((#w > 2) && (w 1 = 107))
                    (fl >a b? f? n? r? s? u? sep ((snip w 2 #w) . ks) fs)
                 (w = "-t") (: pv (val "-t")
                               v <pv
                               _ (? #v () (sdie "-t wants a separator"))
                               (fl <>pv b? f? n? r? s? u? (v 0) ks fs))
                 ((#w > 2) && (w 1 = 116)) (fl >a b? f? n? r? s? u? (w 2) ks fs)
                 (ltr 1 b? f? n? r? s? u?))))
       p (fl as 0 0 0 0 0 0 () () ())
       b? <p f? <>p n? <>>p r? (p 3) s? (p 4) u? (p 5) sep (p 6) kt (p 7) fs (p 8)
       ; a key spec: F[,M] with the ordering letters glued to either number
       (kspec s)
        (: n #s
           (num i) (: (go j) (? ((n <= j) || !(48 <= (s j) <= 57)) j (go (j + 1))) (go i))
           (opt i B F N R)                     ; the letters trailing a number
            (? ((n <= i) || (s i = 44)) [i B F N R]
               ((s i) @
                98  (opt (i + 1) 1 F N R)
                102 (opt (i + 1) B 1 N R)
                110 (opt (i + 1) B F 1 R)
                114 (opt (i + 1) B F N 1)
                c   (sdie ("unknown key letter -- " + (string c)))))
           e1 (num 0)
           _ (? (e1 < 1) (sdie ("bad key -- " + s)) ())
           f (uatoi (snip s 0 e1))
           o1 (opt e1 0 0 0 0)
           (? (#s <= <o1) [f 0 (o1 1) (o1 2) (o1 3) (o1 4)]
              (: rest (snip s (<o1 + 1) n)
                 nr #rest
                 (num2 j) (? ((nr <= j) || !(48 <= (rest j) <= 57)) j (num2 (j + 1)))
                 e2 (num2 0)
                 _ (? (e2 < 1) (sdie ("bad key -- " + s)) ())
                 m (uatoi (snip rest 0 e2))
                 ; the second half's letters count for the whole key too, GNU-style
                 (opt2 i B F N R)
                  (? (nr <= i) [B F N R]
                     ((rest i) @
                      98  (opt2 (i + 1) 1 F N R)
                      102 (opt2 (i + 1) B 1 N R)
                      110 (opt2 (i + 1) B F 1 R)
                      114 (opt2 (i + 1) B F N 1)
                      c   (sdie ("unknown key letter -- " + (string c)))))
                 ; ⚠ the two halves do NOT carry the same letters. n/r/f on either
                 ; half order the whole key, but `b` names a POSITION: on the start
                 ; spec it skips the field's leading blanks, on the end spec it is
                 ; about where the key stops. so -k1b,1 strips and -k1,1b does not,
                 ; and folding them together silently sorted `-k1,1b` on the wrong key.
                 ; the end spec's b is read and dropped -- trailing blanks are not
                 ; modelled here, and inventing a meaning for it would be worse.
                 o2 (opt2 e2 0 (o1 2) (o1 3) (o1 4))
                 [f m (o1 1) (o2 1) (o2 2) (o2 3)])))
       ; a key with no letters of its own takes the global ones; one with any letter
       ; takes only its own. that is GNU's rule, and it is why -k2,2 -n is not -k2,2n.
       (glob k) (: own ((k 2) || (k 3) || (k 4) || (k 5))
                   (? own k [<k <>k b? f? n? r?]))
       keys (? (two? kt) (map (\ s (glob (kspec s))) kt) [[0 0 b? f? n? r?]])
       ; the lines off the reading floor: prel's `lines` walks a charm at a time and
       ; costs more than the sort does. a miss has said its piece; sort still leaves
       (rd fs) (: box (tablet 0)
                  (dot ln term?) (: _ (pin box 'l (ln . (peep box 'l ()))) 1)
                  st (ulines "sort" dot fs)
                  _ (? (= st 0) 0 (uleave 2))
                  (rev (peep box 'l ())))
       ; the comparison: every key in turn, then the last-resort whole-line compare.
       ; ⚠ -r is already inside each key (glob hands it down), so it must NOT also
       ; reverse the output -- doing both is the identity, and the first draft of this
       ; sorted correctly and then undid it. the last resort is the one place -r still
       ; has to be applied by hand.
       ; ⚠ -s and -u BOTH drop the last resort -- -s because that is what stable means
       ; here, and -u because a dedupe reading the whole line would keep two lines that
       ; the keys call equal, which is the opposite of what was asked.
       (last a b) (: c (usort-cmpstr a b) (? r? (0 - c) c))
       ; a line rides decorated: [index line readings], one reading per key, taken once.
       ; ⚠ the same falsy trap as usort-cmpnum's: `(? c c (go >ks))` sends every
       ; less-than on to the next key, and `!(cmp ..)` calls it equal. both readings
       ; have to ask `= 0` out loud.
       (cmp da db) (: (go ks xa xb) (? !(two? ks) (? (s? || u?) 0 (last (da 1) (db 1)))
                                       (: c (usort-cmp1 <xa <xb <ks) (? (= c 0) (go >ks >xa >xb) c)))
                      (go keys (da 2) (db 2)))
       ; ⚠ an equal pair drops the SECOND, never the first: `(ded >a)` walks off the
       ; head and leaves the run's LAST line standing, where GNU keeps its first.
       (same? da db) (? plain? (= (da 1) (db 1)) (= 0 (cmp da db)))
       (ded a) (? !(two? a) ()
                  !(two? >a) a
                  (same? <a <>a) (ded (<a . >>a))
                  (<a >< ded >a))
       ls (rd fs)
       ; no key and no letter is byte order, and that is prel's `sort` -- the C lane,
       ; stable, and the whole line is the key so -r is the reverse; -u still dedupes
       plain? (!(two? kt) && !b? && !f? && !n?)
       ; the keyed C lane: prel's sort orders lists lexicographically, exactly (bigs)
       ; and stably, so a line decorated [reading.. tiebreak] sorts under every key at
       ; once. one direction has to serve the lot -- a numeric reading reverses by
       ; negation, a text cannot -- so the text keys and the last resort pick it, and a
       ; text key against the grain takes the merge lane below instead.
       tkeys (filter (\ k !(k 4)) keys)
       dir (? (two? tkeys) (<tkeys 5) (!(s? || u?)) r? 0)
       clane? (&& (foldl (\ a k (a && (= (k 5) dir))) 1 tkeys)
                  ((s? || u?) || (= r? dir)))
       ; a numeric reading as a sortable triple: the sign class, the integer (negated
       ; when negative), and the fraction's digits -- complemented when negative, so
       ; the byte order of the trimmed digits is the numeric one either way
       (ncomp s) (: n #s o (jug 0)
                    (go k) (? (n <= k) (slurp o) (: _ (put o (105 - (s k))) (go (k + 1))))
                    (go 0))
       (ntrip p flip) (: neg <p ip <>p fp <>>p
                         sc (? (!#ip && !#fp) 0 neg -1 1)
                         iv (? #ip <(sound ip) 0)
                         v (? neg (0 - iv) iv)
                         fr (? neg (ncomp fp) fp)
                         (? flip [(0 - sc) (0 - v) (ncomp fr)] [sc v fr]))
       (creading ln k) (: r (usort-keyof ln k sep)
                          (? (k 4) (ntrip r !(= (k 5) dir)) r))
       (cdeco l) (: (go l i acc)
                     (? !(two? l) (rev acc)
                        (go >l (i + 1)
                            (((map (\ k (creading <l k)) keys)
                              + [(? (s? || u?) (? dir (0 - i) i) <l) <l]) . acc)))
                    (go l 0 ()))
       (clast p) (? (two? >p) (clast >p) <p)
       ; ⚠ prel's `sortby` is NOT a stable sort: `sortsplit` DEALS the list into two,
       ; so element 1 lands right of element 2 and a merge preferring the left hands
       ; them back swapped. every equal run therefore comes out in an order of its own,
       ; which -u then picks a representative from -- and GNU picks the input's first.
       ; the index rides along as the last tiebreak, which is stability stated outright
       ; rather than hoped for from the sort underneath.
       (deco l) (: (go l k acc)
                    (? !(two? l) (rev acc)
                       (go >l (k + 1) ([k <l (map (\ key (usort-keyof <l key sep)) keys)] . acc)))
                   (go l 0 ()))
       s1 (? plain? (: s0 (sort ls) (? r? (rev s0) s0))
             clane? (: s0 (map clast (sort (cdeco ls))) (? dir (rev s0) s0))
             (map (\ p (p 1))
                  (sortby (\ x y (: c (cmp x y) (? (= c 0) (<x <= <y) (c < 0)))) (deco ls))))
       _ (say out (unlines (? u? (map (\ p (p 1)) (ded (deco s1))) s1)))
       _ (flush out) 0)

   ; -- uniq: adjacent runs to their firsts; -c wears the run count, width 7 --
   (uniq-main as)
    (: c? (two? as && (<as = "-c"))
       fs (? c? >as as)
       (emit line cnt) (: _ (? c? (say out (upad 7 (show cnt) + " ")) ())
                          _ (say out line) (put out 10))
       ; adjacent runs, so one line of memory is the whole state -- the run's first
       ; and how many have matched it
       _ (ureachm (\ f (udie 2 ("uniq: cannot open " + f)))
                  (\ f first rd
                     (: (go prev cnt)
                         (: l (urd-line rd)
                            (? !(two? l) (: _ (? (0 < cnt) (emit prev cnt) ()) 1)
                               (: x <l
                                  (? (cnt = 0) (go x 1)
                                     (x = prev) (go prev (cnt + 1))
                                     (: _ (emit prev cnt) (go x 1))))))
                        (go () 0)))
                  (? (two? fs) [<fs] ()))
       _ (flush out) 0)

   ; -- tee: stdin onto out and every file (-a appends) --
   (tee-main as)
    (: a? (two? as && (<as = "-a"))
       fs (? a? >as as)
       ; every destination opens up front. tee is a pipe, and a pipe cannot wait
       ; for the end of its input to start writing -- it used to slurp stdin whole.
       (opn l acc ok)
        (? !(two? l) [(rev acc) ok]
           (: q (open <l (? a? "a" "w"))
              (? (hot? q) (opn >l (q >< acc) ok)
                 (: _ (say err ("tee: cannot open " + <l)) _ (put err 10)
                    (opn >l acc 0)))))
       r (opn fs () 1)
       qs <r ok <>r
       (each1 l h) (? (two? l) (: _ (say <l h) (each1 >l h)) 0)
       _ (uchunks "tee" (\ h (: _ (each1 qs h) _ (puts h) 1)) ())
       (clo l) (? (two? l) (: _ (close <l) (clo >l)) 0)
       _ (clo qs)
       _ (flush out) (? ok 0 1))

   ; -- seq: first incr last, one a line (one and two args fill in the 1s) --
   (seq-main as)
    (: n (tally as)
       trip (? (n = 1) [1 1 (uatoi <as)]
               (n = 2) [(uatoi <as) 1 (uatoi <>as)]
               (n = 3) [(uatoi <as) (uatoi <>as) (uatoi <>>as)]
               (udie 2 "usage: seq [FIRST [INCR]] LAST"))
       a <trip d <>trip z <>>trip
       _ (? (d = 0) (udie 2 "seq: increment must not be 0") ())
       (go i) (? (? (0 < d) (i <= z) (z <= i))
                 (: _ (say out (show i)) _ (put out 10) (go (i + d)))
                 ())
       _ (go a) _ (flush out) 0)

   ; -- yes: the affirmative, forever (args override the y) --
   (yes-main as)
    (: w (? (two? as) (ujoin as) "y")
       (go _) (: _ (say out w) _ (put out 10) _ (flush out) (go ()))
       (go ()))

   ; -- true and false: the two exit codes, nothing else --
   (true-main _) 0
   (false-main _) 1

   ; -- test / [ : the POSIX condition. it must exist as a program. cook's in-image
   ; lane execs a recipe's words directly, so `test` is no shell builtin there: a
   ; `.. > $t && test -s $t && mv $t $@` recipe looks it up on PATH, and a missing one
   ; fails the link with the tmp file already swept -- which is exactly how a 0-byte
   ; lcat header reads as a broken bootstrap. 0 true, 1 false, 2 a bad expression.
   t-fops '("-e" "-f" "-d" "-s" "-r" "-w" "-x")
   t-nops '("-eq" "-ne" "-lt" "-le" "-gt" "-ge")
   (t-int s)                                   ; "-12" -> (1 -12); anything else -> ()
    (: n (tally s)
       neg (? (0 < n) (s 0 = 45) 0)
       st (? neg 1 0)
       (go k acc) (? (n <= k) [1 acc]
                     (: c (s k) (? ((c < 48) || (57 < c)) ()
                                   (go (k + 1) (acc * 10 + c - 48)))))
       (? (n <= st) () (: r (go st 0)
                          (? (two? r) [1 (? neg (0 - <>r) <>r)] ()))))
   ; the stat tuple is (size mtime mode ..); 61440 masks the kind, 32768 a file, 16384 a dir
   (t-file op p)                               ; a file test, or 'no if op is not one
    (: s (stat p) m (? (two? s) <>>s 0)
       (? !(member? op t-fops) 'no
          !(two? s) 0
          (op = "-e") 1
          (op = "-f") (32768 = (& m 61440))
          (op = "-d") (16384 = (& m 61440))
          (op = "-s") (0 < <s)
          (op = "-r") (0 < (& m 292))
          (op = "-w") (0 < (& m 146))
          (0 < (& m 73))))
   (t-not v) (? (= v 'no) 'no !v)
   (t-eval as)                                 ; a bit, or 'no for a malformed expression
    (: n (tally as)
       (? (0 = n) 0
          ((1 < n) && (<as = "!")) (t-not (t-eval >as))
          (1 = n) (0 < tally <as)
          (2 = n) (: op <as p <>as r (t-file op p)
                     (? !(= r 'no) r
                        (op = "-z") (0 = tally p)
                        (op = "-n") (0 < tally p)
                        'no))
          (3 = n) (: a <as op <>as b <>>as
                     (? (op = "=") (a = b)
                        (op = "!=") !(a = b)
                        !(member? op t-nops) 'no
                        (: x (t-int a) y (t-int b)
                           (? (!(two? x) || !(two? y)) 'no
                              (: p <>x q <>y
                                 (? (op = "-eq") (p = q) (op = "-ne") !(p = q)
                                    (op = "-lt") (p < q)  (op = "-le") (p <= q)
                                    (op = "-gt") (q < p)  (q <= p)))))))
          'no))
   (test-main as) (: v (t-eval as)
                     (? (= v 'no) (udie 2 "test: bad expression") (? v 0 1)))
   (t-clip l) (? !(two? >l) () (<l >< t-clip >l))    ; every element but the last
   (bracket-main as)                           ; `[` is test that insists on its bracket
    (: n (tally as)
       (? ((0 = n) || !(as (n - 1) = "]")) (udie 2 "[: missing ]")
          (test-main (t-clip as))))

   ; -- uname: -s -n -r -m, or -a for all four. the machine is love-arch respelled --
   ; holo says x64 where uname says x86_64, and a build naming an artifact off the wrong
   ; one names it for an arch nothing else calls. The other three come off /proc, so a
   ; seat without one answers "unknown" rather than a guess.
   (u-1line p d)                               ; a proc file's first line, or the default
    (: r (uread p)
       (? !(two? r) d
          (: t <>r n (tally t)
             (go k) (? (n <= k) k (t k < 33) k (go (k + 1)))
             e (go 0)
             (? (0 = e) d (snip t 0 e)))))
   ; the machine is love-arch respelled, and the prel owns the respelling (arch-uname):
   ; uname says the world's word for this ISA where love-arch says ours.
   (u-mach _) (: m (arch-mach love-arch) (? (string? m) m (string love-arch)))
   ; the kernel the same way, and it CANNOT be a file: /proc/sys is linux's spelling of
   ; sysctl and the other three kernels have no such path, so the read below answered
   ; "Linux" on freebsd, netbsd and inle alike. main.c pins `love-os` per run off
   ; __ai_osv, which is the only thing that knows. read as data, not as a bare ref: a
   ; baked ref would fold the bake session's own answer in forever (moon's host-os
   ; reads it the same way). nothing pinned falls to the file, then to a refusal --
   ; uname owes a name it was told, never one it guessed.
   (u-os _)
    (: n (? (member? 'love-os (names ())) (ev 'love-os) ())
       s (? (nom? n) (peep os-uname n ()) ())
       (? (string? s) s (u-1line "/proc/sys/kernel/ostype" "unknown")))
   (u-join ws) (? !(two? ws) "" !(two? >ws) <ws (<ws + " " + u-join >ws))
   (uname-main as)
    (: fl (? (two? as) as '("-s"))
       (want f) (? (member? "-a" fl) 1 (member? f fl))
       ws ((? (want "-s") [(u-os ())] ())
           + (? (want "-n") [(u-1line "/proc/sys/kernel/hostname" "unknown")] ())
           + (? (want "-r") [(u-1line "/proc/sys/kernel/osrelease" "unknown")] ())
           + (? (want "-m") [(u-mach ())] ()))
       (? !(two? ws) (udie 2 "usage: uname [-snrma]")
          (: _ (say out (u-join ws)) _ (put out 10) _ (flush out) 0)))

   ; -- arch: uname -m, and nothing else --
   (arch-main _) (: _ (say out (u-mach ())) _ (put out 10) _ (flush out) 0)

   ; -- nproc: the processors /proc/cpuinfo names. GNU counts the ones this process
   ; may run on; nothing here reads an affinity mask, so this is GNU's --all --
   (nproc-main _)
    (: r (uread "/proc/cpuinfo")
       w "processor"
       (go ls n) (? !(two? ls) n
                    (go >ls (? ((tally w <= tally <ls) && (snip <ls 0 (tally w) = w))
                               (n + 1) n)))
       n (? (two? r) (go (lines <>r) 0) 0)
       _ (say out (show (? (0 < n) n 1))) _ (put out 10) _ (flush out) 0)

   ; -- printf: the escapes, then %s %d %c %%. The format is reused while args remain
   ; (POSIX), and an exhausted %s is "" / %d is 0 rather than a stop. No field widths:
   ; nothing in this tree spends one, and a half-implemented %-5.2f would be a lie.
   ; (1 charm) or (), never a bare charm: `\0` is 0, so a charm answer cannot say
   ; "not an escape" -- presence has to ride out of band or \0 reads as an unknown.
   (pf-esc d) (? (d = 110) '(1 10) (d = 116) '(1 9) (d = 114) '(1 13) (d = 92) '(1 92)
                 (d = 97) '(1 7) (d = 98) '(1 8) (d = 102) '(1 12) (d = 118) '(1 11)
                 (d = 48) '(1 0) ())
   ; the escape is resolved here, in the format walk, and not per character: `\` and
   ; `n` are two charms, so a helper handed one at a time can never see a pair -- which
   ; is exactly how `printf '%s\n'` printed a literal backslash-n.
   (pf-one f as)                               ; one pass of the format -> the args left
    (: n (tally f)
       (go k l) (? (n <= k) l
                   (: c (f k)
                      (? ((c = 92) && (k + 1 < n))
                         (: e (pf-esc (f (k + 1)))
                            (? (two? e) (: _ (put out <>e) (go (k + 2) l))
                               (: _ (put out 92) (go (k + 1) l))))
                         !((c = 37) && (k + 1 < n)) (: _ (put out c) (go (k + 1) l))
                         (: d (f (k + 1))
                            (? (d = 37) (: _ (put out 37) (go (k + 2) l))
                               (d = 115) (: _ (say out (? (two? l) <l "")) (go (k + 2) >l))
                               ((d = 100) || (d = 105))
                                (: v (? (two? l) (t-int <l) ())
                                   _ (say out (show (? (two? v) <>v 0)))
                                   (go (k + 2) >l))
                               (d = 99) (: w (? (two? l) <l "")
                                            _ (? (0 < tally w) (put out (w 0)) 0)
                                            (go (k + 2) >l))
                               (: _ (put out 37) (go (k + 1) l)))))))
       (go 0 as))
   (printf-main as)
    (? !(two? as) (udie 2 "usage: printf FORMAT [ARG..]")
       (: f <as
          (go l) (: r (pf-one f l)                 ; POSIX: repeat while the args advance
                    (? ((two? r) && !(r = l)) (go r) 0))
          _ (go >as)
          _ (flush out) 0))


   ; -- basename and dirname: the two path clips --
   (basename-main as)
    (? !(two? as) (udie 2 "usage: basename NAME [SUFFIX]")
       (: _ (say out (ubase <as (? (two? >as) <>as "")))
          _ (put out 10) _ (flush out) 0))
   (dirname-main as)
    (? !(two? as) (udie 2 "usage: dirname NAME")
       (: _ (say out (udir <as)) _ (put out 10) _ (flush out) 0))

   ; -- cut: -f list [-d C] [-s] over fields, -c list over charms (flags glue or not) --
   (cut-main as)
    (: (fl a d f c s?)
        (? !(two? a) [d f c s? a]
           (: h <a
              (? (h = "-s") (fl >a d f c 1)
                 (h = "-d") (? (two? >a) (fl >>a (<>a 0) f c s?)
                               (udie 2 "cut: -d wants a delimiter"))
                 (h = "-f") (? (two? >a) (fl >>a d <>a c s?)
                               (udie 2 "cut: -f wants a list"))
                 (h = "-c") (? (two? >a) (fl >>a d f <>a s?)
                               (udie 2 "cut: -c wants a list"))
                 ((2 < tally h) && (snip h 0 2 = "-d")) (fl >a (h 2) f c s?)
                 ((2 < tally h) && (snip h 0 2 = "-f")) (fl >a d (snip h 2 (tally h)) c s?)
                 ((2 < tally h) && (snip h 0 2 = "-c")) (fl >a d f (snip h 2 (tally h)) s?)
                 [d f c s? a])))
       p (fl as 9 () () 0)
       d <p fspec <>p cspec <>>p s? <>>>p
       fs <>>>>p
       _ (? (fspec || cspec) () (udie 2 "usage: cut -f LIST [-d C] [-s] | cut -c LIST"))
       spec (uspec (? fspec fspec cspec))
       (fieldline ln)
        (: ps (usplit d ln)
           (? !(two? >ps) (? s? () (: _ (say out ln) (put out 10)))
              (: (go m k acc) (? !(two? m) (rev acc)
                                 (go >m (k + 1) (? (upick spec k) (<m >< acc) acc)))
                 _ (say out (ujoinc d (go ps 1 ())))
                 (put out 10))))
       (charline ln)
        (: n (tally ln) o (jug 0)
           (go k) (? (n < k) () (: _ (? (upick spec k) (put o (ln (k - 1))) ()) (go (k + 1))))
           _ (go 1)
           _ (say out (slurp o)) (put out 10))
       ; cut terminates every line it writes, so the source's own end says nothing
       (dot ln term?) (: _ ((? fspec fieldline charline) ln) 1)
       (ulines "cut" dot fs))

   ; ---- the byte loops, natively -------------------------------------------------
   ; the interpreter's byte loop is ~700 instructions a byte (src/core/boot/scan.l
   ; prices it), and tr and base64 are nothing but that loop. tr's is the `xlat` nif:
   ; any byte map through a 512-byte table, one C body on every target, with the
   ; love walk below as the oracle law.l holds it to. base64's group coder is its
   ; own shape and used by nothing in the core, so it stays out of the roster: a holo
   ; kernel, one IR for x64 and a64, with a twin that is the oracle and the engine
   ; wherever the install declines (inle, wasm, rv64). the shape is scan.l's -- the
   ; register roles, the deopt tail, the kind guards off g's jk table so the blob
   ; names no C address.
   ;                            g   ip  sp  scratch
   (kabi tgt) (? (= tgt 'a64) '(r0 r1 r3 r4) '(r6 r5 r1 r0))
   ; Sp[k] is a heap object of jk kind `kind` (1 a string, 6 a cask), or the twin's;
   ; r7 and r8 are the scratch pair, and SC is left holding the object
   (kguard SP G SC k kind)
     [['ld SC SP (* 8 k)] ['test SC 1] '(br ne deopt)
      ['ld 'r7 SC 0] ['ld 'r8 G ((jkoff 0) + (* 8 kind))] '(cmp r7 r8) '(br ne deopt)]
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
              (? (m = 0) (go (k + 1) prev cnt)
                 (: v (tbl c)
                    (? ((m = 2) && (v = prev)) (go (k + 1) prev cnt)
                       (: _ (put o v) (go (k + 1) v (cnt + 1))))))))
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
       ((kguard SP G SC 0 1)
        + (kguard SP G SC 1 1) + [['ld 'r7 SC 8] '(cmp r7 64) '(br lt deopt)]
        + (kguard SP G SC 2 6) + [['ld SC SC 8] ['ld 'r7 SC 8] '(mov r8 r7) '(shl r8 1) '(add r7 r7 r8)
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
        + (one 18 0) + (one 12 1) + (one 6 2) + (one 0 3)
        + ['(add r8 r8 3) '(add r13 r13 4) '(jmp lp)]
        + ['(label fin) ['mov SC 'r13] '(pop r13) '(pop r12) '(pop r11)]
        + (kanswer SP IP SC)
        + (kdeopt IP)))
   (kb64-walk s set dst)
    (: n #s w (* 3 (// n 3)) o (jug 0)
       (go k) (? (w <= k) 0
                 (: v ((* 65536 (s k)) + ((* 256 (s (k + 1))) + (s (k + 2))))
                    _ (put o (set (& (// v 262144) 63)))
                    _ (put o (set (& (// v 4096) 63)))
                    _ (put o (set (& (// v 64) 63)))
                    _ (put o (set (& v 63)))
                    (go (k + 3))))
       _ (go 0)
       cnt (// (* w 4) 3)
       _ (pour dst 0 (slurp o) 0 cnt)
       cnt)
   ; build a kernel, or answer its twin. `nif` hands the twin back itself where the
   ; install declines (inle's NX heap, wasm), so no fallback is arranged here; built
   ; on first use and kept for the process, scan.l's shape and reason
   (kmake ir twin arity)
    (: h (from 'holo) g (from 'glaze)
       (? (nil? h || nil? g || !(member? love-arch '(x64 a64))) twin
          (: bs (peep ((h 'assemble) love-arch (ir love-arch)) 'bytes 0)
             ((g 'nif) (cask bs) twin '(\ q (q)) arity))))
   kbox (tablet 0)
   (kernel nm ir twin arity)
    (: k (peep kbox nm 'none)
       (? !(= k 'none) k (: k2 (kmake ir twin arity) _ (pin kbox nm k2) k2)))
   (kb64 _) (kernel 'b64 kb64-ir kb64-walk 3)
   ; kxlat's table from tr's reading: (image mode) per charm, 512 bytes
   (ktable f)
    (: (go c acc) (? (c < 0) acc (go (c - 1) (<(f c) . acc)))
       (mode c acc) (? (c < 0) acc (mode (c - 1) (<>(f c) . acc)))
       (string (cask (go 255 (mode 255 ())))))

   ; -- tr: set1 set2 translates (SET2 pads with its last charm), -d deletes, -s
   ; squeezes same-charm runs; stdin only, like the real one --
   (tr-main as)
    (: d? (two? as && (<as = "-d"))
       s? (two? as && (<as = "-s"))
       rest (? (d? || s?) >as as)
       _ (? (two? rest) () (udie 2 "usage: tr SET1 SET2 | tr -d SET1 | tr -s SET1"))
       one (uset <rest)
       two (? (two? >rest) (uset <>rest) ())
       (mem ls) (: t (tablet 0)
                   (go m) (? (two? m) (: _ (pin t <m 1) (go >m)) t)
                   (go ls))
       (tmap a b) (: t (tablet 0)
                     (go m w last) (? !(two? m) t
                                      (: v (? (two? w) <w last)
                                         _ (pin t <m v)
                                         (go >m (? (two? w) >w ()) v)))
                     (go a b 0))
       src (slurp in)
       n (tally src)
       ; the reading as kxlat's table: -d drops the set, -s squeezes it, else the map
       tbl (? d? (: dt (mem one) (ktable (\ c [c (? (peep dt c 0) 0 1)])))
              s? (: st (mem one) (ktable (\ c [c (? (peep st c 0) 2 1)])))
              !two (udie 2 "tr: SET2 wanted")
              (: mt (tmap one two) (ktable (\ c [(peep mt c c) 1]))))
       _ (? (0 < n)
            (: dst (cask n) k (xlat src tbl dst) (say out (snip dst 0 k)))
            0)
       _ (flush out) 0)

   ; -- nl: number the lines that hold ink (pad 6, a tab after); a blank line wears
   ; seven spaces and no number, and the count carries across inputs --
   (nl-main as)
    (: t {'i 1}
       ; nl terminates every line it writes, so term? says nothing here either
       (dot ln term?)
        (: _ (? !ln (: _ (say out "       ") (put out 10))
                (: i (peep t 'i 1)
                   _ (say out (upad 6 (show i))) _ (put out 9)
                   _ (say out ln) _ (put out 10)
                   (pin t 'i (i + 1))))
           1)
       (ulines "nl" dot as))

   ; -- rev: every line back to front --
   (rev-main as)
    ; the last line keeps the source's end, which is exactly what term? carries
    (: (dot ln term?) (: _ (say out (urev ln)) _ (? term? (put out 10) 0) 1)
       (ulines "rev" dot as))

   ; ---- the column tools: fold, expand, unexpand --------------------------------
   ; all three count columns and not bytes -- a tab steps to the next stop, \b steps
   ; back one, \r starts the line over -- which is the whole reason they are one
   ; section: `ucol` is the only thing they share and the only thing they disagree
   ; with a byte count about. fold -b asks for the bytes instead.
   (ucol col c stop)                   ; the column charm c leaves the cursor on
    (? (c = 9) (* stop ((// col stop) + 1))
       (c = 8) (? (0 < col) (col - 1) 0)
       (c = 13) 0
       (col + 1))
   (ublank? c) ((c = 32) || (c = 9))
   (uspaces o k) (? (0 < k) (: _ (put o 32) (uspaces o (k - 1))) 0)

   ; -- fold: one line -> the pieces it breaks into at width w. the break lands
   ; before the charm that would overflow, so a charm wider than the whole width
   ; still gets a line of its own; -s backs the break up to the last blank --
   (ufold w s? b? s)
    (: n (tally s)
       (go k st col lb acc)            ; lb: seat after the last blank, -1 for none
        (? (n <= k) (rev (snip s st n >< acc))
           (: c (s k)
              nc (? b? (col + 1) (ucol col c 8))
              (? ((w < nc) && (st < k))
                 (: cut (? ((s? && (st < lb)) && (lb <= k)) lb k)
                    (go cut cut 0 -1 (snip s st cut >< acc)))
                 (go (k + 1) st nc (? (ublank? c) (k + 1) lb) acc))))
       (go 0 0 0 -1 ()))
   (fold-main as)
    (: t (tablet 0)
       (pre a wid acc)                 ; the obsolescent -N width, as head takes its own
        (? !(two? a) [wid (rev acc)]
           ((1 < tally <a) && (<a 0 = 45) && (digits? <a))
            (pre >a (uatoi (snip <a 1 (tally <a))) acc)
           (pre >a wid (<a >< acc)))
       p (pre as () ())
       o (uopts <>p t '(119) ())
       _ (? (two? o) () (udie 2 "fold: -w wants a width"))
       v (uoptv t 119)
       w (? (string? v) (uatoi v) (? (charm? <p) <p 80))
       _ (? (0 < w) () (udie 2 "fold: width must be positive"))
       s? (peep t 115 0) b? (peep t 98 0)
       ; the pieces are said as they are cut. The flatten this replaced was
       ; `(foldl (\ a l (a + ..)) () ..)`, which copies the whole answer per line.
       (dot ln term?)
        (: (go m) (? !(two? m) 1
                     (: _ (say out <m)
                        _ (? ((two? >m) || term?) (put out 10) 0)
                        (go >m)))
           (go (ufold w s? b? ln)))
       (ulines "fold" dot <>>o))

   ; -- expand: tabs to spaces, a stop every n (8 unsaid); -i converts only the
   ; blanks a line opens with --
   (uexpand n i? s)
    (: m (tally s) o (jug 0)
       (go k col lead)
        (? (m <= k) (slurp o)
           (: c (s k)
              (? ((c = 9) && (lead || !i?))
                 (: to (* n ((// col n) + 1)) _ (uspaces o (to - col)) (go (k + 1) to lead))
                 (: _ (put o c)
                    (go (k + 1) (ucol col c n) (? (ublank? c) lead 0))))))
       (go 0 0 1))
   (expand-main as)
    (: t (tablet 0)
       o (uopts as t '(116) ())
       _ (? (two? o) () (udie 2 "expand: -t wants a tab size"))
       v (uoptv t 116)
       n (? (string? v) (uatoi v) 8)
       _ (? (0 < n) () (udie 2 "expand: tab size must be positive"))
       i? (peep t 105 0)
       (dot ln term?) (: _ (say out (uexpand n i? ln)) _ (? term? (put out 10) 0) 1)
       (ulines "expand" dot <>>o))

   ; -- unexpand: blanks back to tabs -- only the ones a line opens with unless -a
   ; takes every run (-t says a size and means -a too). a tab lands only where it
   ; saves at least two columns, which is why a lone space on a stop stays a space --
   (uunexpand n a? s)
    (: m (tally s) o (jug 0)
       (spill st end)                  ; a blank run from column st to column end
        (: (go cur) (: to (* n ((// cur n) + 1))
                      (? ((to <= end) && ((cur + 2) <= to)) (: _ (put o 9) (go to))
                         (uspaces o (end - cur))))
           (go st))
       (go k col rst lead)             ; rst: the run's first column, -1 for none
        (? (m <= k) (: _ (? (rst < 0) 0 (spill rst col)) (slurp o))
           (: c (s k)
              cv (ucol col c n)
              (? ((ublank? c) && (lead || a?))
                 (go (k + 1) cv (? (rst < 0) col rst) lead)
                 (: _ (? (rst < 0) 0 (spill rst col))
                    _ (put o c)
                    (go (k + 1) cv -1 (? (ublank? c) lead 0))))))
       (go 0 0 -1 1))
   (unexpand-main as)
    (: t (tablet 0)
       o (uopts as t '(116) ())
       _ (? (two? o) () (udie 2 "unexpand: -t wants a tab size"))
       v (uoptv t 116)
       n (? (string? v) (uatoi v) 8)
       _ (? (0 < n) () (udie 2 "unexpand: tab size must be positive"))
       a? (? (string? v) 1 (peep t 97 0))
       (dot ln term?) (: _ (say out (uunexpand n a? ln)) _ (? term? (put out 10) 0) 1)
       (ulines "unexpand" dot <>>o))

   ; ---- the calendar floor (stat's %y and date both read it) --------------------
   ; Howard Hinnant's exact integer civil-from-days and its inverse, shifted to a March
   ; year so the leap day lands at the end and no month table is needed. love's // is
   ; a floor division, which is what these want -- the sign dance the C originals carry
   ; is only there because C truncates. lawed in law.l over the round trip.
   ; there is no time zone here and there will not be one without a tz database: every
   ; face over these is utc, exactly as nolibc's localtime is its gmtime.
   (ucivil z0)                         ; days since 1970-01-01 -> (year month day)
    (: z (z0 + 719468)
       era (// z 146097)
       doe (z - (* era 146097))
       yoe (// (((doe - (// doe 1460)) + (// doe 36524)) - (// doe 146096)) 365)
       y ((* era 400) + yoe)
       doy (doe - (((* 365 yoe) + (// yoe 4)) - (// yoe 100)))
       mp (// ((* 5 doy) + 2) 153)
       d ((doy - (// ((* 153 mp) + 2) 5)) + 1)
       m (mp + (? (mp < 10) 3 -9))
       [(? (m <= 2) (y + 1) y) m d])
   (udays y0 m d)                      ; (year month day) -> days since 1970-01-01
    (: y (? (m <= 2) (y0 - 1) y0)
       era (// y 400)
       yoe (y - (* era 400))
       doy ((// ((* 153 (m + (? (2 < m) -3 9))) + 2) 5) + (d - 1))
       doe ((((* yoe 365) + (// yoe 4)) - (// yoe 100)) + doy)
       (((* era 146097) + doe) - 719468))


   ; ---- the encodings: base64 and base32 (RFC 4648, GNU's two faces) ------------
   ; one coder, two alphabets: the group is 3 bytes -> 4 charms at 6 bits and 5 -> 8
   ; at 5, the short tail padded with = to a whole group either way. -d reads it back
   ; (a newline is ignored, anything else outside the alphabet is refused), -w wraps
   ; the output at 76 unless told another width, 0 for one long line.
   ub64set "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
   ub32set "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
   ; ⚠ val and go are lifted OUT of grp on purpose. Written inside it -- which is the
   ; obvious shape, and was this coder's for a long time -- they are two closures minted
   ; per THREE INPUT BYTES, and love has no pass that hoists a loop lambda out of
   ; another loop's body. That alone was 3.5x of this function (539 ms -> 155 ms over
   ; 512 KB, byte-identical), and it is why `base64` used to read ~600x busybox on
   ; bench/korebench.sh where `tr`, the same kind of per-byte transform, reads ~48x.
   ; ⚠ and it was not the two things it looked like: the tower computing 2^shift is
   ; 5 ms per 3M, and the jug is 145 ms per 1.4M puts. Both were measured and neither
   ; is the cost. `shf` below is still worth having -- one table beats gc towers a
   ; group -- but it is the smaller half by far. doc/misc/kore-gauge.md carries the
   ; numbers and the two dead ends.
   ; base64 rides the kb64 kernel over the whole groups and the coder below over the
   ; tail; base32 (5 bits) is the coder's alone
   (ubenc set bits s)
    (: n (tally s) w (* 3 (// n 3))
       (? ((bits = 6) && (2 < n))
          (: dst (cask (* 4 (// (n + 2) 3)))
             k ((kb64 0) s set dst)
             ((snip dst 0 k) + (ubenc0 set bits (snip s w n))))
          (ubenc0 set bits s)))
   (ubenc0 set bits s)
    (: n (tally s) o (jug 0)
       gb (? (bits = 6) 3 5)                    ; bytes in a whole group
       gc (// (* gb 8) bits)                    ; charms in a whole group
       msk ((bits 2) - 1)
       shf ((: (mk j a) (? (j < 0) a (mk (j - 1) (((* bits ((gc - 1) - j)) 2) . a))))
            (gc - 1) ())                        ; the divisor per output charm, once
       (val k have i acc) (? (gb <= i) acc
                             (val k have (i + 1) ((* acc 256) + (? (i < have) (s (k + i)) 0))))
       (go k v full j) (? (gc <= j) (grp (k + gb))
                          (: _ (? (j < full)
                                  (put o (set (& (// v (shf j)) msk)))
                                  (put o 61))
                             (go k v full (j + 1))))
       (grp k)
        (? (n <= k) (slurp o)
           (: have (? ((k + gb) <= n) gb (n - k))
              v (val k have 0 0)
              full (// (((* have 8) + bits) - 1) bits)   ; the charms carrying data
              (go k v full 0)))
       (grp 0))
   ; -w 0 closes nothing: GNU wraps at a width and ends the last line, but one long
   ; line arrives with no newline at all -- so a `base64 -w 0` piped into a compare is
   ; a byte shorter than the obvious implementation makes it
   (ubwrap w s)                                 ; the coded text, wrapped and closed
    (: n (tally s) o (jug 0)
       (go k) (? (n <= k) (slurp o)
                 (: e (? ((k + w) < n) (k + w) n)
                    _ (say o (snip s k e)) _ (put o 10) (go e)))
       (? (0 < w) (go 0) s))
   (ubdec set bits s)                           ; (1 text), or () when it will not read
    (: ns (tally set) n (tally s) o (jug 0)
       (ix c) (: (go k) (? (ns <= k) () (set k = c) [1 k] (go (k + 1))) (go 0))
       (go k acc nb)
        (? (n <= k) [1 (slurp o)]
           (: c (s k)
              (? ((c = 10) || (c = 13)) (go (k + 1) acc nb)
                 (c = 61) (: (tail j)               ; past the pad, only pad and newline
                              (? (n <= j) [1 (slurp o)]
                                 (: d (s j)
                                    (? (((d = 61) || (d = 10)) || (d = 13)) (tail (j + 1))
                                       ())))
                            (tail (k + 1)))
                 (: r (ix c)
                    (? !(two? r) ()
                       (: a2 ((* acc (bits 2)) + <>r)
                          n2 (nb + bits)
                          (? (8 <= n2)
                             (: _ (put o (& (// a2 ((n2 - 8) 2)) 255))
                                (go (k + 1) (& a2 (((n2 - 8) 2) - 1)) (n2 - 8)))
                             (go (k + 1) a2 n2))))))))
       (go 0 0 0))
   (ubmain who set bits as)
    (: t (tablet 0)
       o (uopts as t '(119) ())
       _ (? (two? o) () (udie 1 (who + ": -w wants a width")))
       v (uoptv t 119)
       w (? (string? v) (uatoi v) 76)
       d? (peep t 100 0)
       fs <>>o
       _ (? (two? >fs) (udie 1 (who + ": extra operand")) ())
       txt (? (two? fs) (: r (? (<fs = "-") [1 (slurp in)] (uread <fs))
                           (? (two? r) <>r (udie 1 (who + ": cannot open " + <fs))))
              (slurp in))
       _ (? d? (: r (ubdec set bits txt)
                  (? (two? r) (say out <>r) (udie 1 (who + ": invalid input"))))
            (say out (ubwrap w (ubenc set bits txt))))
       _ (flush out) 0)
   (base64-main as) (ubmain "base64" ub64set 6 as)
   (base32-main as) (ubmain "base32" ub32set 5 as)

   ; ---- the two little computations: tsort and factor ---------------------------

   ; -- tsort: the pairs' partial order made total. the answer is a topological
   ; order, not GNU's: where the input pins one they agree, and where it does not both
   ; are right -- so the gate asks only about inputs that pin one. a loop is named on
   ; err, broken at the first node still standing, and leaves 1, as GNU's does --
   (tsort-main as)
    (: _ (? (two? >as) (udie 1 "usage: tsort [FILE]") ())
       t (? (two? as) (: r (? (<as = "-") [1 (slurp in)] (uread <as))
                         (? (two? r) <>r (udie 1 ("tsort: cannot open " + <as))))
              (slurp in))
       ws (uwords t)
       _ (? (% (tally ws) 2) (udie 1 "tsort: odd number of input words") ())
       deg (tablet 0) succ (tablet 0)       ; the graph, keyed by the interned words
       (rd l order)
        (? !(two? l) (rev order)
           (: a (name <l) b (name <>l)
              o1 (? (= (peep deg a ()) ()) (: _ (pin deg a 0) (a >< order)) order)
              o2 (? (= (peep deg b ()) ()) (: _ (pin deg b 0) (b >< o1)) o1)
              _ (? (= a b) 0                       ; a pair of one is a node, not an edge
                   (: _ (pin succ a (b >< (peep succ a ())))
                      (pin deg b ((peep deg b 0) + 1))))
              (rd >>l o2)))
       order (rd ws ())
       (loose l) (? !(two? l) () ((peep deg <l 0) = 0) [1 <l] (loose >l))
       (ts-drop x l) (? !(two? l) () (= <l x) >l (<l >< ts-drop x >l))
       (emit k) (: _ (say out (string k)) _ (put out 10)
                   (foldl (\ _ b (pin deg b ((peep deg b 0) - 1))) 0 (peep succ k ())))
       (go l bad)
        (? !(two? l) (: _ (flush out) bad)
           (: r (loose l)
              (? (two? r) (: _ (emit <>r) (go (ts-drop <>r l) bad))
                 (: _ (say err "tsort: input contains a loop:") _ (put err 10)
                    _ (foldl (\ _ k (: _ (say err ("tsort: " + (string k))) (put err 10)))
                             0 l)
                    _ (emit <l)
                    (go >l 1)))))
       (go order 0))

   ; -- factor: every number's primes, GNU's `N: p q r`. trial division by 2 and the
   ; odd numbers -- exact for anything this tree spends, and a twenty-digit semiprime
   ; will simply sit here (that is what GNU keeps a Pollard rho for) --
   (ufactor n0)
    (: (go n d acc)
        (? (n < 2) (rev acc)
           (0 = (% n d)) (go (// n d) d (d >< acc))
           (n < (* d d)) (rev (n >< acc))
           (go n (? (d = 2) 3 (d + 2)) acc))
       (? (n0 < 2) () (go n0 2 ())))
   (factor-main as)
    (: (dig? s) (: n (tally s)
                   (go k) (? (n <= k) (0 < n)
                             ((48 <= (s k)) && ((s k) <= 57)) (go (k + 1))
                             0)
                   (go 0))
       (one w ok)
        (? !(dig? w)
           (: _ (say err ("factor: '" + w + "' is not a valid positive integer"))
              _ (put err 10) 0)
           (: _ (say out (w + ":"))
              _ (foldl (\ _ p (: _ (put out 32) (say out (show p)))) 0 (ufactor (uatoi w)))
              _ (put out 10) ok))
       (go a ok) (? (two? a) (go >a (one <a ok)) ok)
       ok (go (? (two? as) as (uwords (slurp in))) 1)
       _ (flush out) (? ok 0 1))

   ; ---- the record tools: paste, comm, join, split, od -------------------------

   ; -d's list -> the delimiter texts. texts and not charms because POSIX's \0 is the
   ; empty delimiter, and no charm can say "nothing here"
   (udels s)
    (: n (tally s)
       (esc c) (? (c = 110) "\n" (c = 116) "\t" (c = 114) "\r" (c = 48) ""
                  (c = 92) "\\" (string c))
       (go k acc) (? (n <= k) (rev acc)
                     ((s k = 92) && ((k + 1) < n)) (go (k + 2) (esc (s (k + 1)) >< acc))
                     (go (k + 1) (string (s k) >< acc)))
       r (go 0 ())
       (? (two? r) r '("")))
   ; an input's lines, or a leave naming the file (the record tools read whole files:
   ; they walk several at once, so ureach's one-at-a-time walk is not their shape)
   (urows who f)
    (: r (? (f = "-") [1 (slurp in)] (uread f))
       (? (two? r) (lines <>r) (udie 1 (who + ": cannot open " + f))))

   ; -- paste: the files' lines side by side, a row at a time; the delimiters cycle
   ; between the columns and start over each row (a tab when unsaid). -s lays a whole
   ; file along one row instead, which is the transpose and not a variant --
   (paste-main as)
    (: (fl a d s?)
        (? !(two? a) [d s? a]
           (<a = "-s") (fl >a d 1)
           (<a = "-d") (? (two? >a) (fl >>a (udels <>a) s?)
                          (udie 2 "paste: -d wants a list"))
           ((2 < tally <a) && (snip <a 0 2 = "-d"))
            (fl >a (udels (snip <a 2 (tally <a))) s?)
           [d s? a])
       p (fl as '("\t") 0)
       ds <p s? <>p
       fs (? (two? <>>p) <>>p '("-"))
       (jn cells)
        (: o (jug 0)
           ; the list advances with the separator it spends, never with the cell:
           ; the first cell spends none, so an early advance shifts the whole cycle
           (go m left first)
            (? !(two? m) (slurp o)
               first (: _ (say o <m) (go >m left 0))
               (: _ (say o <left) _ (say o <m)
                  (go >m (? (two? >left) >left ds) 0)))
           (go cells ds 1))
       (emit t) (: _ (say out t) (put out 10))
       (some lss) (foldl (\ a l (? (two? l) 1 a)) 0 lss)
       (rows lss) (? (some lss)
                     (: _ (emit (jn (map (\ l (? (two? l) <l "")) lss)))
                        (rows (map (\ l (? (two? l) >l ())) lss)))
                     ())
       lss (map (\ f (urows "paste" f)) fs)
       _ (? s? (foldl (\ _ l (emit (jn l))) 0 lss) (rows lss))
       _ (flush out) 0)

   ; -- comm: two sorted files merged into three columns -- only in the first, only in
   ; the second, in both -- each column behind a tab per column standing before it.
   ; -1/-2/-3 drop a column and the tabs close up behind it, GNU's own arithmetic --
   (comm-main as)
    (: (fl a s1 s2 s3)
        (? !(two? a) [s1 s2 s3 a]
           ((tally <a < 2) || !(<a 0 = 45)) [s1 s2 s3 a]
           (: w <a
              (cl k b1 b2 b3)
               (? (tally w <= k) (fl >a b1 b2 b3)
                  (: c (w k)
                     (? (c = 49) (cl (k + 1) 1 b2 b3)
                        (c = 50) (cl (k + 1) b1 1 b3)
                        (c = 51) (cl (k + 1) b1 b2 1)
                        (udie 2 ("comm: unknown option -" + string c)))))
              (cl 1 s1 s2 s3)))
       p (fl as 0 0 0)
       s1 <p s2 <>p s3 <>>p fs (p 3)
       _ (? (two? >fs) () (udie 2 "usage: comm [-123] FILE1 FILE2"))
       (pre k) ((? (!s1 && (1 < k)) "\t" "") + (? (!s2 && (2 < k)) "\t" ""))
       (emit k ln) (? (? (k = 1) s1 (k = 2) s2 s3) ()
                      (: _ (say out (pre k)) _ (say out ln) (put out 10)))
       (go a b) (? (!(two? a) && !(two? b)) ()
                   !(two? a) (: _ (emit 2 <b) (go a >b))
                   !(two? b) (: _ (emit 1 <a) (go >a b))
                   (<a = <b) (: _ (emit 3 <a) (go >a >b))
                   (<a < <b) (: _ (emit 1 <a) (go >a b))
                   (: _ (emit 2 <b) (go a >b)))
       _ (go (urows "comm" <fs) (urows "comm" <>fs))
       _ (flush out) 0)

   ; -- split: a file cut into pieces named prefix + a rolling suffix. -l N lines (1000
   ; unsaid), -b N bytes (a K/M/G suffix multiplies), -a N the suffix width, -d digits
   ; for letters. an empty input writes no file, like GNU --
   (usfx n w d?)                       ; the n'th suffix, w wide: aa ab .. or 00 01 ..
    (: b (? d? 10 26)
       (go k v acc) (? (k < 1) acc
                       (go (k - 1) (v // b) (string ((? d? 48 97) + (v % b)) + acc)))
       (go w n ""))
   (usize s)                           ; a byte count, an optional K/M/G multiplying
    (: n (tally s)
       c (? (0 < n) (s (n - 1)) 0)
       m (? ((c = 107) || (c = 75)) 1024 ((c = 109) || (c = 77)) 1048576
            ((c = 103) || (c = 71)) 1073741824 0)
       (? m (* m (uatoi (snip s 0 (n - 1)))) (uatoi s)))
   (split-main as)
    (: (fl a ln by sw d? fs)
        (: (val w) (snip w 2 (tally w))
           (long? w) ((2 < tally w) && (snip w 0 2 = "-l"))
           (? !(two? a) [ln by sw d? (rev fs)]
              (<a = "-l") (? (two? >a) (fl >>a (uatoi <>a) () sw d? fs)
                             (udie 2 "split: -l wants a count"))
              (<a = "-b") (? (two? >a) (fl >>a () (usize <>a) sw d? fs)
                             (udie 2 "split: -b wants a size"))
              (<a = "-a") (? (two? >a) (fl >>a ln by (uatoi <>a) d? fs)
                             (udie 2 "split: -a wants a width"))
              (<a = "-d") (fl >a ln by sw 1 fs)
              (long? <a) (fl >a (uatoi (val <a)) () sw d? fs)
              ((2 < tally <a) && (snip <a 0 2 = "-b")) (fl >a () (usize (val <a)) sw d? fs)
              ((2 < tally <a) && (snip <a 0 2 = "-a")) (fl >a ln by (uatoi (val <a)) d? fs)
              (fl >a ln by sw d? (<a >< fs))))
       p (fl as () () 2 0 ())
       ln <p by <>p sw <>>p d? (p 3) fs (p 4)
       nl (? (charm? ln) ln 1000)
       src (? (two? fs) <fs "-")
       pre (? ((two? fs) && two? >fs) <>fs "x")
       t (? (src = "-") (slurp in)
            (: r (uread src) (? (two? r) <>r (udie 1 ("split: cannot open " + src)))))
       end? (nl-end? t)
       (wr i txt) (: nm (pre + usfx i sw d?)
                     (? (uwrite nm txt) () (udie 1 ("split: cannot write " + nm))))
       (bygo i k) (? (tally t <= k) 0
                     (: e (? ((k + by) < tally t) (k + by) (tally t))
                        _ (wr i (snip t k e))
                        (bygo (i + 1) e)))
       ; unlines terminates every line, so the last piece of a source that did not
       ; end in a newline has to give the newline back -- the piece is where the
       ; source's own end lands, and GNU keeps it there
       (lngo i ls) (? !(two? ls) 0
                      (: rest (drop nl ls)
                         txt (unlines (take nl ls))
                         _ (wr i (? ((two? rest) || end?) txt (chomp txt)))
                         (lngo (i + 1) rest)))
       _ (? (charm? by) (bygo 0 0) (lngo 0 (lines t)))
       0)

   ; the shape every option walk past this point rides: a word is -X and the value is
   ; either glued to it or the next word. asked by tally: a text is no link, so a
   ; `two?` here reads every glued value as absent (the bug that ate `grep -m2`).
   (uopt w)                            ; "-tx1" -> ("t" "x1"), a bare word -> ()
    (: n (tally w)
       (? ((1 < n) && (w 0 = 45)) [(snip w 1 2) (snip w 2 n)] ()))

   ; -- join: two files sorted on their join field, merged into one. a row is the key,
   ; then the first file's other fields, then the second's; a key repeated on either
   ; side makes the whole cross product, which is what a relational join owes. -1/-2
   ; pick the field, -t the separator (runs of blanks when unsaid, and then the output
   ; rides one space), -a keeps a side's unpairable rows in their sorted place, -v keeps
   ; only those (and drops the paired rows entirely). out of dialect, deliberately: -o
   ; (an output template is its own little language), -e, -i.
   (ujfs sep ln)                       ; a row's fields: -t's charm, or runs of blanks
    (? (charm? sep) (usplit sep ln)
       (: n (tally ln)
          (bl? c) ((c = 32) || (c = 9))
          (go i st acc)
           (? (n <= i) (rev (? (st < 0) acc (snip ln st i >< acc)))
              (bl? (ln i)) (go (i + 1) -1 (? (st < 0) acc (snip ln st i >< acc)))
              (go (i + 1) (? (st < 0) i st) acc))
          (go 0 -1 ())))
   (unth l k) (k < 1 ? () (l (k - 1)))
   (join-main as)
    (: t {'f1 1 'f2 1 'sep () 'a1 0 'a2 0 'v1 0 'v2 0}
       (fl a fs)
        (? !(two? a) (rev fs)
           (: w <a
              o (uopt w)
              takes (? o (member? <o '("1" "2" "t" "a" "v")) 0)
              glue (? o <>o "")
              got (? (0 < tally glue) glue (? (two? >a) <>a ()))
              rest (? (0 < tally glue) >a (? (two? >a) >>a >a))
              (? !takes (fl >a (w >< fs))
                 !(string? got) (udie 2 ("join: " + w + " wants a value"))
                 (: k <o
                    _ (? (k = "1") (pin t 'f1 (uatoi got))
                         (k = "2") (pin t 'f2 (uatoi got))
                         (k = "t") (pin t 'sep (got 0))
                         (k = "a") (pin t (? (got = "2") 'a2 'a1) 1)
                         (pin t (? (got = "2") 'v2 'v1) 1))
                    (fl rest fs)))))
       fs (fl as ())
       _ (? (two? >fs) ()
            (udie 2 "usage: join [-1 F] [-2 F] [-t C] [-a 1|2] [-v 1|2] FILE1 FILE2"))
       sep (peep t 'sep ())
       jsep (? (charm? sep) sep 32)
       n1 (peep t 'f1 1) n2 (peep t 'f2 1)
       pair? !((peep t 'v1 0) || (peep t 'v2 0))
       un1 ((peep t 'a1 0) || (peep t 'v1 0))
       un2 ((peep t 'a2 0) || (peep t 'v2 0))
       ; a side is its rows grouped by key: ((key (fields..)..)..), the run of one key
       (grp sel lns)
        (: rows (map (\ ln (: f (ujfs sep ln) k (unth f sel)
                              [(? (string? k) k "") f]))
                     lns)
           (go rs) (? !(two? rs) ()
                      (: k <<rs
                         (span m acc) (? ((two? m) && (<<m = k)) (span >m (<><m >< acc))
                                         [(rev acc) m])
                         r (span rs ())
                         ([k <r] >< go <>r)))
           (go rows))
       (drop1 sel f) (: (go l i acc) (? !(two? l) (rev acc)
                                        (go >l (i + 1) (? (i = sel) acc (<l >< acc))))
                        (go f 1 ()))
       (row ps) (: _ (say out (ujoinc jsep ps)) (put out 10))
       (one k sel g) (foldl (\ _ f (row (k >< drop1 sel f))) 0 <>g)
       (cross g1 g2)
        (foldl (\ _ f1 (foldl (\ _ f2 (row ((<g1 >< drop1 n1 f1) + drop1 n2 f2)))
                              0 <>g2))
               0 <>g1)
       (go g1 g2)
        (? (!(two? g1) && !(two? g2)) ()
           !(two? g1) (: _ (? un2 (one <<g2 n2 <g2) ()) (go g1 >g2))
           !(two? g2) (: _ (? un1 (one <<g1 n1 <g1) ()) (go >g1 g2))
           (<<g1 = <<g2) (: _ (? pair? (cross <g1 <g2) ()) (go >g1 >g2))
           (<<g1 < <<g2) (: _ (? un1 (one <<g1 n1 <g1) ()) (go >g1 g2))
           (: _ (? un2 (one <<g2 n2 <g2) ()) (go g1 >g2)))
       _ (go (grp n1 (urows "join" <fs)) (grp n2 (urows "join" <>fs)))
       _ (flush out) 0)

   ; -- od: the byte dump, GNU's columns to the space. -A d|o|x|n picks the address
   ; radix (octal, 7 wide, unsaid; -An drops the column AND the closing offset), -t
   ; type the reading, -N a limit, -j a skip, -v every line even where it repeats
   ; (a repeat is one `*` otherwise). the short spellings -a -b -c -d -o -x -s -i are
   ; the -t's GNU gives them. one -t per run, the last given winning: GNU's
   ; several-at-once lane re-widens every column to the widest type in the set, which
   ; is a whole layout of its own and not another row.
   (uzpad w s) (? (tally s < w) (uzpad w ("0" + s)) s)
   (uradix n b) (: o (jug 0) _ (putbn o n b) (slurp o))
   uodnames '("nul" "soh" "stx" "etx" "eot" "enq" "ack" "bel" "bs" "ht" "nl" "vt"
              "ff" "cr" "so" "si" "dle" "dc1" "dc2" "dc3" "dc4" "nak" "syn" "etb"
              "can" "em" "sub" "esc" "fs" "gs" "rs" "us" "sp")
   (uodname c)                         ; -ta's name, the high bit masked off like GNU's
    (: b (& c 127) (? (b < 33) (uodnames b) (b = 127) "del" (string b)))
   (uodesc c)                          ; -tc's escape; anything else is three octal
    (? (c = 0) "\\0" (c = 7) "\\a" (c = 8) "\\b" (c = 9) "\\t" (c = 10) "\\n"
       (c = 11) "\\v" (c = 12) "\\f" (c = 13) "\\r"
       ((31 < c) && (c < 127)) (string c)
       (uzpad 3 (uradix c 8)))
   (uodtype s)                         ; a -t word -> (kind size width) | ()
    (: k (? (0 < tally s) (s 0) 0)
       z (? (1 < tally s) (uatoi (snip s 1 (tally s))) 0)
       (? (k = 99) '(c 1 3)
          (k = 97) '(a 1 3)
          (k = 120) (? (z = 1) '(x 1 2) (z = 4) '(x 4 8) (z = 2) '(x 2 4) (z = 0) '(x 2 4) ())
          (k = 111) (? (z = 1) '(o 1 3) (z = 4) '(o 4 11) (z = 2) '(o 2 6) (z = 0) '(o 2 6) ())
          (k = 100) (? (z = 1) '(d 1 4) (z = 4) '(d 4 11) (z = 2) '(d 2 6) (z = 0) '(d 2 6) ())
          (k = 117) (? (z = 1) '(u 1 3) (z = 4) '(u 4 10) (z = 2) '(u 2 5) (z = 0) '(u 2 5) ())
          ()))
   (od-main as)
    (: t {'ad 111 'ty '(o 2 6) 'lim () 'skip 0 'v 0}
       (fl a fs)
        (? !(two? a) (rev fs)
           (: w <a
              o (uopt w)
              k (? o <o ())
              glue (? o <>o "")
              takes (? o (member? k '("A" "t" "N" "j")) 0)
              got (? (0 < tally glue) glue (? (two? >a) <>a ()))
              rest (? (0 < tally glue) >a (? (two? >a) >>a >a))
              short (? o (? (k = "c") (uodtype "c") (k = "a") (uodtype "a")
                            (k = "b") (uodtype "o1") (k = "x") (uodtype "x2")
                            (k = "o") (uodtype "o2") (k = "d") (uodtype "u2")
                            (k = "s") (uodtype "d2") (k = "i") (uodtype "d4") ())
                       ())
              (? takes
                 (? !(string? got) (udie 2 ("od: " + w + " wants a value"))
                    (: _ (? (k = "A") (pin t 'ad (got 0))
                            (k = "N") (pin t 'lim (usize got))
                            (k = "j") (pin t 'skip (usize got))
                            (: y (uodtype got)
                               (? y (pin t 'ty y) (udie 2 ("od: unknown type " + got)))))
                       (fl rest fs)))
                 !o (fl >a (w >< fs))
                 short (: _ (pin t 'ty short) (fl >a fs))
                 (k = "v") (: _ (pin t 'v 1) (fl >a fs))
                 (udie 2 ("od: unknown option " + w)))))
       fs (fl as ())
       ad (peep t 'ad 111) ty (peep t 'ty '(o 2 6))
       lim (peep t 'lim ()) skip (peep t 'skip 0) v? (peep t 'v 0)
       kd <ty sz <>ty wd <>>ty
       byte? ((= kd 'c) || (= kd 'a))
       step (? byte? 1 sz)
       ; the named operands are one stream, which is what makes the offsets run
       ; through -- and a row at a time off it, never the stream itself. every
       ; reading below indexes the row now, not a whole-file `src`: od held every
       ; operand at once to dump 16 bytes of them.
       rd (urdb (\ f (udie 1 ("od: cannot open " + f))) fs)
       ; the skip is read past, not indexed: a joined stream has no length to take
       ; it off, and running out mid-skip is the diagnostic GNU gives.
       (drop k) (? (k <= 0) 1
                   (: g (urdj-take rd (? (65536 < k) 65536 k))
                      n (tally g)
                      (? n (drop (k - n)) 0)))
       _ (? (drop skip) 0 (udie 1 "od: cannot skip past end of combined input"))
       (adr k) (? (ad = 110) ""
                  (ad = 100) (uzpad 7 (show k))
                  (ad = 120) (uzpad 6 (uradix k 16))
                  (uzpad 7 (uradix k 8)))
       (val blk k)                      ; the little-endian item at k, short reads zeroed
        (: n (tally blk)
           (go i acc) (? (sz <= i) acc
                         (go (i + 1) (acc + (* (? ((k + i) < n) (blk (k + i)) 0)
                                               ((* 8 i) 2)))))
           (go 0 0))
       (cell blk k)
        (? (= kd 'c) (upad 3 (uodesc (blk k)))
           (= kd 'a) (upad 3 (uodname (blk k)))
           (: raw (val blk k)
              v (? ((= kd 'd) && !(raw < (((* 8 sz) - 1) 2))) (raw - ((* 8 sz) 2)) raw)
              (? (= kd 'x) (uzpad wd (uradix v 16))
                 (= kd 'o) (uzpad wd (uradix v 8))
                 (upad wd (show v)))))
       (rowof blk cnt)
        (: items (? byte? cnt (// ((cnt + sz) - 1) sz))
           o (jug 0)
           (go i) (? (items <= i) (slurp o)
                     (: _ (put o 32) _ (say o (cell blk (* i step))) (go (i + 1))))
           (go 0))
       ; left is -1 for no -N; the walk answers the byte count, for the closing offset
       (walk k left prev star)
        (? (left = 0) k
           (: blk (urdj-take rd (? (left < 0) 16 (? (16 < left) 16 left)))
              cnt (tally blk)
              left2 (? (left < 0) -1 (left - cnt))
              (? (0 = cnt) k
                 ((!v? && (cnt = 16)) && (blk = prev))
                  (: _ (? star () (: _ (say out "*") (put out 10)))
                     (walk (k + cnt) left2 blk 1))
                 (: _ (say out (adr (skip + k))) _ (say out (rowof blk cnt)) _ (put out 10)
                    (walk (k + cnt) left2 blk 0)))))
       nb (walk 0 (? (charm? lim) lim -1) () 0)
       _ (? (ad = 110) () (: _ (say out (adr (skip + nb))) (put out 10)))
       _ (flush out) 0))
) ; module 'kore
